using System;
using System.IO;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using MelonLoader;

namespace TreninoBridge;

/// <summary>
/// Minimal local HTTP API (loopback only).
///
///   GET  /status                      -> { ok, vehicle, groups: [...] }
///   GET  /controls                    -> cab controls: bound field + their own position state
///   GET  /io                          -> { group: { field: value, ... }, ... } for the player vehicle
///   GET  /io/{group}                  -> { field: value, ... }
///   GET  /io/{group}/{field}          -> { value }
///   POST /io/{group}/{field}  body: {"value": x}  -> { value }  (written on the main thread)
/// </summary>
internal sealed class HttpApi : IDisposable
{
    private static readonly JsonSerializerOptions Json = new() { WriteIndented = false };

    private readonly HttpListener _listener = new();
    private readonly CancellationTokenSource _cts = new();
    private readonly MelonLogger.Instance _log;

    public HttpApi(int port, MelonLogger.Instance log)
    {
        _log = log;
        _listener.Prefixes.Add($"http://127.0.0.1:{port}/");
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
            HttpListenerContext ctx;
            try { ctx = await _listener.GetContextAsync(); }
            catch when (_cts.IsCancellationRequested) { return; }
            catch (Exception e) { _log.Warning($"accept failed: {e.Message}"); continue; }

            _ = Task.Run(() => Handle(ctx));
        }
    }

    private async Task Handle(HttpListenerContext ctx)
    {
        int status = 200;
        object body;
        try
        {
            var parts = ctx.Request.Url!.AbsolutePath.Trim('/').Split('/', StringSplitOptions.RemoveEmptyEntries);
            var method = ctx.Request.HttpMethod;

            body = (method, parts) switch
            {
                ("GET", ["status"]) => await MainThread.Run(TrainIO.Status),
                ("GET", ["controls"]) => await MainThread.Run(TrainIO.ListControls),
                ("GET", ["io"]) => await MainThread.Run(TrainIO.ReadAll),
                ("GET", ["io", var g]) => await MainThread.Run(() => TrainIO.ReadGroup(g)),
                ("GET", ["io", var g, var f]) => await MainThread.Run(() => TrainIO.ReadField(g, f)),
                ("POST", ["io", var g, var f]) => await Write(ctx, g, f),
                _ => throw new BridgeException(404, "not found"),
            };
        }
        catch (BridgeException e) { status = e.Status; body = new { error = e.Message }; }
        catch (Exception e) { status = 500; body = new { error = e.GetBaseException().Message }; }

        try
        {
            var bytes = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(body, Json));
            ctx.Response.StatusCode = status;
            ctx.Response.ContentType = "application/json";
            ctx.Response.ContentLength64 = bytes.Length;
            await ctx.Response.OutputStream.WriteAsync(bytes);
            ctx.Response.Close();
        }
        catch (Exception e) { _log.Warning($"response failed: {e.Message}"); }
    }

    private static async Task<object> Write(HttpListenerContext ctx, string group, string field)
    {
        using var reader = new StreamReader(ctx.Request.InputStream, Encoding.UTF8);
        var raw = await reader.ReadToEndAsync();
        JsonElement value;
        try { value = JsonDocument.Parse(raw).RootElement.GetProperty("value").Clone(); }
        catch { throw new BridgeException(400, "body must be {\"value\": ...}"); }

        return await MainThread.Run(() => TrainIO.WriteField(group, field, value));
    }

    public void Dispose()
    {
        _cts.Cancel();
        try { _listener.Stop(); _listener.Close(); } catch { /* shutting down */ }
    }
}

internal sealed class BridgeException(int status, string message) : Exception(message)
{
    public int Status { get; } = status;
}
