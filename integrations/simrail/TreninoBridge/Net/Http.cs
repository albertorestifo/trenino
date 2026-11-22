using System;
using System.Collections.Generic;
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

    /// <summary>Reads one request; null when the client closed the connection.</summary>
    public static async Task<HttpRequest?> ReadAsync(Connection conn, CancellationToken ct)
    {
        var requestLine = await conn.ReadLineAsync(ct);
        if (requestLine == null) return null;
        if (requestLine.Length == 0) requestLine = await conn.ReadLineAsync(ct); // tolerate stray CRLF
        if (requestLine == null) return null;

        var parts = requestLine.Split(' ');
        if (parts.Length < 3) throw new BridgeException(400, "malformed request line");

        var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        while (true)
        {
            var line = await conn.ReadLineAsync(ct) ?? throw new BridgeException(400, "truncated headers");
            if (line.Length == 0) break;
            var colon = line.IndexOf(':');
            if (colon > 0) headers[line[..colon].Trim()] = line[(colon + 1)..].Trim();
        }

        var body = Array.Empty<byte>();
        if (headers.TryGetValue("content-length", out var lenText) && int.TryParse(lenText, out var len) && len > 0)
        {
            if (len > MaxBody) throw new BridgeException(413, "body too large");
            body = new byte[len];
            await conn.ReadExactAsync(body, ct);
        }

        var target = parts[1];
        var q = target.IndexOf('?');
        var path = WebUtility.UrlDecode(q >= 0 ? target[..q] : target);
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
        409 => "Conflict",
        413 => "Payload Too Large",
        _ => status >= 500 ? "Internal Server Error" : "Error",
    };
}

internal sealed class BridgeException(int status, string message) : Exception(message)
{
    public int Status { get; } = status;
}
