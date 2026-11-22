using System;
using System.IO;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace TreninoBridge.Net;

/// <summary>Buffered reader/writer over a TCP stream, shared by the HTTP and WebSocket layers.</summary>
internal sealed class Connection : IDisposable
{
    private readonly TcpClient _client;
    private readonly NetworkStream _stream;
    private readonly byte[] _buffer = new byte[16 * 1024];
    private int _start;
    private int _end;
    private readonly SemaphoreSlim _writeLock = new(1, 1);

    public Connection(TcpClient client)
    {
        _client = client;
        _client.NoDelay = true;
        _stream = client.GetStream();
    }

    private async Task<bool> FillAsync(CancellationToken ct)
    {
        if (_start > 0 && _start == _end) { _start = _end = 0; }
        if (_end == _buffer.Length)
        {
            if (_start == 0) throw new IOException("request too large");
            Buffer.BlockCopy(_buffer, _start, _buffer, 0, _end - _start);
            _end -= _start;
            _start = 0;
        }
        var n = await _stream.ReadAsync(_buffer.AsMemory(_end), ct);
        if (n == 0) return false;
        _end += n;
        return true;
    }

    /// <summary>Reads a CRLF-terminated line (without the CRLF); null on EOF.</summary>
    public async Task<string?> ReadLineAsync(CancellationToken ct)
    {
        while (true)
        {
            for (var i = _start; i < _end - 1; i++)
            {
                if (_buffer[i] == '\r' && _buffer[i + 1] == '\n')
                {
                    var line = Encoding.ASCII.GetString(_buffer, _start, i - _start);
                    _start = i + 2;
                    return line;
                }
            }
            if (!await FillAsync(ct)) return null;
        }
    }

    public async Task ReadExactAsync(Memory<byte> dest, CancellationToken ct)
    {
        var offset = 0;
        while (offset < dest.Length)
        {
            if (_start == _end && !await FillAsync(ct)) throw new EndOfStreamException();
            var n = Math.Min(dest.Length - offset, _end - _start);
            _buffer.AsMemory(_start, n).CopyTo(dest[offset..]);
            _start += n;
            offset += n;
        }
    }

    public async Task WriteAsync(ReadOnlyMemory<byte> data, CancellationToken ct)
    {
        await _writeLock.WaitAsync(ct);
        try { await _stream.WriteAsync(data, ct); }
        finally { _writeLock.Release(); }
    }

    public void Dispose()
    {
        try { _client.Close(); } catch { /* already closed */ }
        _writeLock.Dispose();
    }
}
