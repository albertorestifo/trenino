using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using MelonLoader;
using TreninoBridge.Net;

namespace TreninoBridge;

/// <summary>
/// Trenino bridge API v1 (HTTP/1.1 + WebSocket on one port).
///
/// Auth: requests from loopback WITHOUT an Origin header are trusted (local apps,
/// scripts). Everything else - LAN clients and anything a browser sends - must
/// present the token: "Authorization: Bearer &lt;token&gt;" or "?token=&lt;token&gt;".
///
/// HTTP
///   GET  /api/v1/status
///   GET  /api/v1/vehicle                 identity, IO groups, cab controls + notch tables
///   GET  /api/v1/values[?paths=a,b.*]    current values (path -> float)
///   PUT  /api/v1/values/{path}           {"value": 2}
///   PUT  /api/v1/controls/{id}           {"position": 3}  (game's notch value for that position)
///   GET  /api/v1/dump                    schema + values + raw control properties (research)
///
/// WebSocket  /api/v1/stream   (JSON text messages, optional "id" echoed in replies)
///   -> {"op":"subscribe","paths":["Physics_Input_EN57.*"],"maxHz":30}   <- {"id","ok":true,"values":{...}}
///   -> {"op":"unsubscribe","paths":[...]}
///   -> {"op":"get","paths":[...]}                                       <- {"id","ok":true,"values":{...}}
///   -> {"op":"set","path":"Group.field","value":1}                      <- {"id","ok":true,"result":{...}}
///   -> {"op":"setControl","control":"&lt;id&gt;","position":2}
///   -> {"op":"vehicle"}                                                 <- {"id","ok":true,"vehicle":{...}}
///   <- {"op":"values","t":unixMs,"values":{path:value}}   only changed subscribed values
///   <- {"op":"vehicle","vehicle":{...}|null}              player vehicle changed
/// </summary>
internal sealed class Server : IDisposable
{
    public const string Version = "1";

    private readonly TcpListener _listener;
    private readonly string _token;
    private readonly MelonLogger.Instance _log;
    private readonly CancellationTokenSource _cts = new();

    public Server(IPAddress address, int port, string token, MelonLogger.Instance log)
    {
        _listener = new TcpListener(address, port);
        _token = token;
        _log = log;
    }

    public void Start()
    {
        _listener.Start();
        _ = Task.Run(AcceptLoop);
    }

    private async Task AcceptLoop()
    {
        while (!_cts.IsCancellationRequested)
        {
            TcpClient client;
            try { client = await _listener.AcceptTcpClientAsync(_cts.Token); }
            catch when (_cts.IsCancellationRequested) { return; }
            catch (Exception e) { _log.Warning($"accept failed: {e.Message}"); continue; }

            // Loopback (the local Trenino app) is never capped, so LAN clients can't
            // starve it. Network clients share a global cap and a per-IP cap.
            var remote = (client.Client.RemoteEndPoint as IPEndPoint)?.Address ?? IPAddress.None;
            if (!IPAddress.IsLoopback(remote) && !TryReserve(remote))
            {
                client.Close(); // over capacity: drop before reading anything
                continue;
            }
            _ = Task.Run(async () =>
            {
                try { await HandleClient(client); }
                finally { if (!IPAddress.IsLoopback(remote)) Release(remote); }
            });
        }
    }

    private const int MaxNetworkConnections = 32;
    private const int MaxConnectionsPerIp = 8;
    private readonly Dictionary<IPAddress, int> _perIp = new();
    private int _networkConnections;

    private bool TryReserve(IPAddress ip)
    {
        lock (_perIp)
        {
            var current = _perIp.GetValueOrDefault(ip);
            if (_networkConnections >= MaxNetworkConnections || current >= MaxConnectionsPerIp) return false;
            _perIp[ip] = current + 1;
            _networkConnections++;
            return true;
        }
    }

    private void Release(IPAddress ip)
    {
        lock (_perIp)
        {
            _networkConnections--;
            if (--_perIp[ip] <= 0) _perIp.Remove(ip);
        }
    }

    private async Task HandleClient(TcpClient client)
    {
        var remote = (client.Client.RemoteEndPoint as IPEndPoint)?.Address ?? IPAddress.None;
        using var conn = new Connection(client);
        var ct = _cts.Token;
        try
        {
            var first = true;
            while (!ct.IsCancellationRequested)
            {
                HttpRequest? req;
                try { req = await HttpRequest.ReadAsync(conn, first, ct); first = false; }
                catch (BridgeException e) { await Respond(conn, e.Status, new { error = e.Message }, false, ct); return; }
                if (req == null) return;

                if (!Authorized(req, remote))
                {
                    await Respond(conn, 401, new { error = "token required (Authorization: Bearer <token> or ?token=)" }, false, ct);
                    return;
                }

                if (req.IsWebSocketUpgrade)
                {
                    if (req.Path != "/api/v1/stream") { await Respond(conn, 404, new { error = "not found" }, false, ct); return; }
                    var ws = await WebSocket.AcceptAsync(conn, req, ct);
                    await RunStream(ws, ct);
                    return;
                }

                int status;
                object body;
                try { (status, body) = (200, await Route(req)); }
                catch (BridgeException e) { (status, body) = (e.Status, new { error = e.Message }); }
                catch (Exception e) { (status, body) = (500, new { error = e.GetBaseException().Message }); }

                await Respond(conn, status, body, req.KeepAlive, ct);
                if (!req.KeepAlive) return;
            }
        }
        catch (Exception e) when (e is System.IO.IOException or SocketException or OperationCanceledException or System.IO.EndOfStreamException)
        {
            // client went away
        }
        catch (Exception e) { _log.Warning($"connection error: {e.GetBaseException().Message}"); }
    }

    private bool Authorized(HttpRequest req, IPAddress remote)
    {
        if (IPAddress.IsLoopback(remote) && IsTrustedLocalRequest(req)) return true;

        var presented = req.Query.TryGetValue("token", out var q) ? q : null;
        var auth = req.Header("authorization");
        if (presented == null && auth != null && auth.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            presented = auth[7..].Trim();
        return presented != null &&
               CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(presented), Encoding.UTF8.GetBytes(_token));
    }

    /// <summary>
    /// A loopback request is trusted without a token only if nothing suggests a browser:
    /// no Origin, no cross-site Sec-Fetch-Site, and a Host that is literally a loopback
    /// address. The Host check defeats DNS rebinding, where a malicious site's domain
    /// resolves to 127.0.0.1 and same-origin GETs carry no Origin header.
    /// </summary>
    private bool IsTrustedLocalRequest(HttpRequest req)
    {
        if (req.Header("origin") != null) return false;
        var fetchSite = req.Header("sec-fetch-site");
        if (fetchSite != null && !string.Equals(fetchSite, "none", StringComparison.OrdinalIgnoreCase)) return false;

        var host = req.Header("host");
        if (host == null) return false;
        var port = ((IPEndPoint)_listener.LocalEndpoint).Port;
        return host == $"127.0.0.1:{port}" || host == $"localhost:{port}" || host == $"[::1]:{port}";
    }

    private static Task Respond(Connection conn, int status, object body, bool keepAlive, CancellationToken ct) =>
        HttpResponse.WriteAsync(conn, status, Json.SerializeBytes(body), "application/json; charset=utf-8", keepAlive, ct);

    // --- HTTP routing -------------------------------------------------------

    private static async Task<object> Route(HttpRequest req)
    {
        const string prefix = "/api/v1/";
        if (!req.Path.StartsWith(prefix, StringComparison.Ordinal)) throw new BridgeException(404, "not found");
        var rest = req.Path[prefix.Length..];
        var slash = rest.IndexOf('/');
        var resource = slash >= 0 ? rest[..slash] : rest;
        var arg = slash >= 0 ? rest[(slash + 1)..] : null;

        return (req.Method, resource, arg) switch
        {
            ("GET", "status", null) => await MainThread.Run(Status),
            ("GET", "vehicle", null) => await MainThread.Run(TrainIO.Vehicle),
            ("GET", "values", null) => await MainThread.Run(() => (object)TrainIO.Read(SplitPaths(req.Query.GetValueOrDefault("paths")))),
            ("PUT", "values", { } path) => await SetValue(path, Body(req)),
            ("PUT", "controls", { } id) => await SetControl(id, Body(req)),
            ("GET", "dump", null) => await MainThread.Run(TrainIO.Dump),
            (_, "status" or "vehicle" or "values" or "controls" or "dump", _) => throw new BridgeException(405, "method not allowed"),
            _ => throw new BridgeException(404, "not found"),
        };
    }

    private static object Status()
    {
        var inTrain = TrainIO.Refresh();
        return new { ok = true, api = Version, bridge = Mod.BridgeVersion, inTrain, generation = TrainIO.Generation };
    }

    private static Task<object> SetValue(string path, JsonElement body) =>
        MainThread.Run(() => TrainIO.Write(path, ReadValue(body)));

    private static Task<object> SetControl(string id, JsonElement body)
    {
        if (!body.TryGetProperty("position", out var p) || !p.TryGetInt32(out var position))
            throw new BridgeException(400, "body must be {\"position\": n}");
        return MainThread.Run(() => TrainIO.SetControlPosition(id, position));
    }

    private static JsonElement Body(HttpRequest req)
    {
        try { return JsonDocument.Parse(req.Body).RootElement.Clone(); }
        catch { throw new BridgeException(400, "body must be JSON"); }
    }

    private static float ReadValue(JsonElement body)
    {
        if (body.ValueKind != JsonValueKind.Object || !body.TryGetProperty("value", out var v))
            throw new BridgeException(400, "body must be {\"value\": n}");
        return v.ValueKind switch
        {
            JsonValueKind.Number => v.GetSingle(),
            JsonValueKind.True => 1f,
            JsonValueKind.False => 0f,
            _ => throw new BridgeException(400, "value must be a number or boolean"),
        };
    }

    private static List<string>? SplitPaths(string? csv) =>
        string.IsNullOrWhiteSpace(csv) ? null : csv.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList();

    // --- WebSocket stream ---------------------------------------------------

    private async Task RunStream(WebSocket ws, CancellationToken ct)
    {
        var session = new StreamSession();
        // Ends the session when the server stops or the client fell too far behind.
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(ct, session.Closed.Token);
        var writer = Task.Run(async () =>
        {
            await foreach (var msg in session.Outbox.Reader.ReadAllAsync(linked.Token))
                await ws.SendTextAsync(msg, linked.Token);
        });

        // Queue hello before joining the hub, so it always precedes the first vehicle push.
        session.Send(Json.Serialize(new { op = "hello", api = Version, bridge = Mod.BridgeVersion }));
        StreamHub.Add(session);
        try
        {
            while (true)
            {
                var text = await ws.ReceiveAsync(linked.Token);
                if (text == null) break;
                var reply = await HandleMessage(session, text);
                if (reply != null) session.Send(Json.Serialize(reply));
            }
        }
        finally
        {
            StreamHub.Remove(session);
            session.Outbox.Writer.TryComplete();
            linked.Cancel();
            try { await writer; } catch { /* closing */ }
        }
    }

    private static async Task<Dictionary<string, object?>?> HandleMessage(StreamSession session, string text)
    {
        JsonElement msg;
        JsonElement? id = null;
        try
        {
            msg = JsonDocument.Parse(text).RootElement.Clone();
            if (msg.TryGetProperty("id", out var idEl)) id = idEl;
            var op = msg.TryGetProperty("op", out var opEl) ? opEl.GetString() : null;

            var reply = new Dictionary<string, object?> { ["id"] = id, ["ok"] = true };
            switch (op)
            {
                case "subscribe":
                {
                    var paths = Strings(msg, "paths");
                    double? hz = msg.TryGetProperty("maxHz", out var h) && h.TryGetDouble(out var d) ? d : null;
                    // Atomic on the main thread: the hub can't tick between subscribing and
                    // reading, the reply's values become the baseline for change pushes, and
                    // the reply is queued there too, so no newer push can overtake it.
                    await MainThread.Run(() =>
                    {
                        session.Subscribe(paths, hz);
                        var current = TrainIO.Refresh() ? TrainIO.Read(paths) : new Dictionary<string, float>();
                        session.Seed(current);
                        reply["values"] = current;
                        session.Send(Json.Serialize(reply));
                        return true;
                    });
                    return null;
                }
                case "unsubscribe":
                    session.Unsubscribe(Strings(msg, "paths"));
                    break;
                case "get":
                {
                    var paths = Strings(msg, "paths");
                    reply["values"] = await MainThread.Run(() => TrainIO.Read(paths));
                    break;
                }
                case "set":
                {
                    var path = msg.GetProperty("path").GetString() ?? throw new BridgeException(400, "path required");
                    var value = ReadValue(msg);
                    reply["result"] = await MainThread.Run(() => TrainIO.Write(path, value));
                    break;
                }
                case "setControl":
                {
                    var control = msg.GetProperty("control").GetString() ?? throw new BridgeException(400, "control required");
                    var position = msg.GetProperty("position").GetInt32();
                    reply["result"] = await MainThread.Run(() => TrainIO.SetControlPosition(control, position));
                    break;
                }
                case "vehicle":
                    reply["vehicle"] = await MainThread.Run(TrainIO.Vehicle);
                    break;
                default:
                    throw new BridgeException(400, $"unknown op '{op}'");
            }
            return reply;
        }
        catch (BridgeException e) { return Error(id, e.Status, e.Message); }
        catch (Exception e) when (e is JsonException or KeyNotFoundException or InvalidOperationException or FormatException)
        { return Error(id, 400, "malformed message: " + e.Message); }
        catch (Exception e) { return Error(id, 500, e.GetBaseException().Message); }
    }

    private static Dictionary<string, object?> Error(JsonElement? id, int status, string message) =>
        new() { ["id"] = id, ["ok"] = false, ["status"] = status, ["error"] = message };

    private static List<string> Strings(JsonElement msg, string prop) =>
        msg.TryGetProperty(prop, out var arr) && arr.ValueKind == JsonValueKind.Array
            ? arr.EnumerateArray().Select(e => e.GetString()).Where(s => !string.IsNullOrEmpty(s)).Select(s => s!).ToList()
            : new List<string>();

    public void Dispose()
    {
        _cts.Cancel();
        try { _listener.Stop(); } catch { /* shutting down */ }
    }
}
