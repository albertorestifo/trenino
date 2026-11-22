using System;
using System.Buffers.Binary;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace TreninoBridge.Net;

/// <summary>Minimal RFC 6455 server side: text frames, ping/pong, close, fragmentation.</summary>
internal sealed class WebSocket
{
    private const int MaxMessage = 256 * 1024;
    private readonly Connection _conn;

    private WebSocket(Connection conn) => _conn = conn;

    public static async Task<WebSocket> AcceptAsync(Connection conn, HttpRequest req, CancellationToken ct)
    {
        var key = req.Header("sec-websocket-key") ?? throw new BridgeException(400, "missing Sec-WebSocket-Key");
        var accept = Convert.ToBase64String(SHA1.HashData(Encoding.ASCII.GetBytes(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")));
        var response =
            "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            $"Sec-WebSocket-Accept: {accept}\r\n\r\n";
        await conn.WriteAsync(Encoding.ASCII.GetBytes(response), ct);
        return new WebSocket(conn);
    }

    /// <summary>Next text message; null when the peer closed.</summary>
    public async Task<string?> ReceiveAsync(CancellationToken ct)
    {
        using var message = new MemoryStream();
        var header = new byte[2];
        while (true)
        {
            await _conn.ReadExactAsync(header, ct);
            var fin = (header[0] & 0x80) != 0;
            var opcode = header[0] & 0x0F;
            var masked = (header[1] & 0x80) != 0;
            long len = header[1] & 0x7F;
            if (len == 126) { var ext = new byte[2]; await _conn.ReadExactAsync(ext, ct); len = BinaryPrimitives.ReadUInt16BigEndian(ext); }
            else if (len == 127) { var ext = new byte[8]; await _conn.ReadExactAsync(ext, ct); len = (long)BinaryPrimitives.ReadUInt64BigEndian(ext); }
            if (len > MaxMessage || message.Length + len > MaxMessage) throw new IOException("message too large");

            var mask = new byte[4];
            if (masked) await _conn.ReadExactAsync(mask, ct);
            var payload = new byte[len];
            await _conn.ReadExactAsync(payload, ct);
            if (masked) for (var i = 0; i < payload.Length; i++) payload[i] ^= mask[i & 3];

            switch (opcode)
            {
                case 0x8: // close
                    await SendFrameAsync(0x8, payload, ct);
                    return null;
                case 0x9: // ping
                    await SendFrameAsync(0xA, payload, ct);
                    continue;
                case 0xA: // pong
                    continue;
                case 0x1: case 0x2: case 0x0:
                    message.Write(payload);
                    if (fin) return Encoding.UTF8.GetString(message.GetBuffer(), 0, (int)message.Length);
                    continue;
                default:
                    throw new IOException($"unsupported opcode {opcode}");
            }
        }
    }

    public Task SendTextAsync(string text, CancellationToken ct) => SendFrameAsync(0x1, Encoding.UTF8.GetBytes(text), ct);

    private async Task SendFrameAsync(int opcode, byte[] payload, CancellationToken ct)
    {
        var headerLen = payload.Length < 126 ? 2 : payload.Length <= ushort.MaxValue ? 4 : 10;
        var frame = new byte[headerLen + payload.Length];
        frame[0] = (byte)(0x80 | opcode);
        if (payload.Length < 126) frame[1] = (byte)payload.Length;
        else if (payload.Length <= ushort.MaxValue) { frame[1] = 126; BinaryPrimitives.WriteUInt16BigEndian(frame.AsSpan(2), (ushort)payload.Length); }
        else { frame[1] = 127; BinaryPrimitives.WriteUInt64BigEndian(frame.AsSpan(2), (ulong)payload.Length); }
        Buffer.BlockCopy(payload, 0, frame, headerLen, payload.Length);
        await _conn.WriteAsync(frame, ct);
    }
}
