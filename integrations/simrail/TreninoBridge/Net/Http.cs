using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace TreninoBridge.Net;

internal sealed class HttpRequest
{
    public string Method { get; init; } = null!;
    public string Path { get; init; } = null!;
    public Dictionary<string, string> Query { get; init; } = null!;
    public Dictionary<string, string> Headers { get; init; } = null!;
    public byte[] Body { get; init; } = Array.Empty<byte>();

    public string? Header(string name) => Headers.TryGetValue(name, out var v) ? v : null;

    public bool KeepAlive =>
        !string.Equals(Header("connection"), "close", StringComparison.OrdinalIgnoreCase);

    public bool IsWebSocketUpgrade =>
        string.Equals(Header("upgrade"), "websocket", StringComparison.OrdinalIgnoreCase);

    private const int MaxBody = 64 * 1024;
    private const int MaxHeaders = 100;
    private const int MaxHeaderBytes = 16 * 1024;
    private static readonly TimeSpan FirstRequestTimeout = TimeSpan.FromSeconds(10); // new connection must start talking
    private static readonly TimeSpan IdleTimeout = TimeSpan.FromSeconds(60);         // keep-alive wait between requests
    private static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(10);      // headers + body once a request started

    /// <summary>Reads one request; null when the client closed or idled out.</summary>
    public static async Task<HttpRequest?> ReadAsync(Connection conn, bool firstOnConnection, CancellationToken ct)
    {
        string? requestLine;
        using (var idle = CancellationTokenSource.CreateLinkedTokenSource(ct))
        {
            idle.CancelAfter(firstOnConnection ? FirstRequestTimeout : IdleTimeout);
            try
            {
                requestLine = await conn.ReadLineAsync(idle.Token);
                if (requestLine is { Length: 0 }) requestLine = await conn.ReadLineAsync(idle.Token); // tolerate stray CRLF
            }
            catch (OperationCanceledException) when (!ct.IsCancellationRequested) { return null; }
        }
        if (requestLine == null) return null;

        var parts = requestLine.Split(' ');
        if (parts.Length < 3) throw new BridgeException(400, "malformed request line");

        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(ct);
        deadline.CancelAfter(RequestTimeout);
        var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var body = Array.Empty<byte>();
        try
        {
            var headerBytes = requestLine.Length;
            while (true)
            {
                var line = await conn.ReadLineAsync(deadline.Token) ?? throw new BridgeException(400, "truncated headers");
                if (line.Length == 0) break;
                headerBytes += line.Length + 2;
                if (headers.Count >= MaxHeaders || headerBytes > MaxHeaderBytes)
                    throw new BridgeException(431, "request headers too large");
                var colon = line.IndexOf(':');
                if (colon <= 0) continue;
                var name = line[..colon].Trim();
                // A second Content-Length could frame the body differently than a proxy did.
                if (headers.ContainsKey(name) && name.Equals("content-length", StringComparison.OrdinalIgnoreCase))
                    throw new BridgeException(400, "duplicate Content-Length");
                headers[name] = line[(colon + 1)..].Trim();
            }

            // Only plain Content-Length framing: anything else could desync request
            // boundaries on a kept-alive connection (request smuggling).
            if (headers.ContainsKey("transfer-encoding"))
                throw new BridgeException(400, "Transfer-Encoding is not supported");
            if (headers.TryGetValue("content-length", out var lenText))
            {
                if (lenText.Length == 0 || !lenText.All(c => c is >= '0' and <= '9') || !int.TryParse(lenText, out var len))
                    throw new BridgeException(400, "invalid Content-Length");
                if (len > MaxBody) throw new BridgeException(413, "body too large");
                if (len > 0)
                {
                    body = new byte[len];
                    await conn.ReadExactAsync(body, deadline.Token);
                }
            }
        }
        catch (OperationCanceledException) when (!ct.IsCancellationRequested)
        {
            throw new BridgeException(408, "request timed out");
        }

        var target = parts[1];
        var q = target.IndexOf('?');
        // Percent-decoding only: "+" is a literal plus in a path, not a space.
        var path = Uri.UnescapeDataString(q >= 0 ? target[..q] : target);
        var query = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (q >= 0)
        {
            foreach (var pair in target[(q + 1)..].Split('&', StringSplitOptions.RemoveEmptyEntries))
            {
                var eq = pair.IndexOf('=');
                var key = WebUtility.UrlDecode(eq >= 0 ? pair[..eq] : pair);
                query[key] = eq >= 0 ? WebUtility.UrlDecode(pair[(eq + 1)..]) : "";
            }
        }

        return new HttpRequest { Method = parts[0].ToUpperInvariant(), Path = path, Query = query, Headers = headers, Body = body };
    }
}

internal static class HttpResponse
{
    public static async Task WriteAsync(Connection conn, int status, byte[] body, string contentType, bool keepAlive, CancellationToken ct)
    {
        var head = new StringBuilder()
            .Append("HTTP/1.1 ").Append(status).Append(' ').Append(Reason(status)).Append("\r\n")
            .Append("Content-Type: ").Append(contentType).Append("\r\n")
            .Append("Content-Length: ").Append(body.Length).Append("\r\n")
            .Append("Cache-Control: no-store\r\n")
            .Append(keepAlive ? "Connection: keep-alive\r\n" : "Connection: close\r\n")
            .Append("\r\n");
        var headBytes = Encoding.ASCII.GetBytes(head.ToString());
        var all = new byte[headBytes.Length + body.Length];
        Buffer.BlockCopy(headBytes, 0, all, 0, headBytes.Length);
        Buffer.BlockCopy(body, 0, all, headBytes.Length, body.Length);
        await conn.WriteAsync(all, ct);
    }

    private static string Reason(int status) => status switch
    {
        101 => "Switching Protocols",
        200 => "OK",
        204 => "No Content",
        400 => "Bad Request",
        401 => "Unauthorized",
        404 => "Not Found",
        405 => "Method Not Allowed",
        408 => "Request Timeout",
        409 => "Conflict",
        413 => "Payload Too Large",
        431 => "Request Header Fields Too Large",
        503 => "Service Unavailable",
        _ => status >= 500 ? "Internal Server Error" : "Error",
    };
}

internal sealed class BridgeException(int status, string message) : Exception(message)
{
    public int Status { get; } = status;
}
