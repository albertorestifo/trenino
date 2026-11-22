using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace TreninoInteropGuard;

/// <summary>A PE image addressed by RVA: either loaded in this process or read from a file on disk.</summary>
internal abstract class PeImage
{
    /// <summary>Reads up to <paramref name="length"/> bytes at <paramref name="rva"/>; shorter at the end of a section.</summary>
    public abstract byte[] Read(uint rva, int length);

    public IReadOnlyList<Section> Sections => _sections ??= ReadSections();
    private IReadOnlyList<Section>? _sections;

    internal readonly record struct Section(string Name, uint Rva, uint VirtualSize, uint RawOffset, uint RawSize, bool Executable);

    private uint U32(uint rva) => BitConverter.ToUInt32(Read(rva, 4));
    private ushort U16(uint rva) => BitConverter.ToUInt16(Read(rva, 2));

    private uint NtHeaders => U32(0x3c);

    private List<Section> ReadSections()
    {
        var nt = NtHeaders;
        var count = U16(nt + 6);
        var optionalSize = U16(nt + 20);
        var first = nt + 24 + optionalSize;
        var result = new List<Section>(count);
        for (uint i = 0; i < count; i++)
        {
            var s = Read(first + i * 40, 40);
            var name = Encoding.ASCII.GetString(s, 0, 8).TrimEnd('\0');
            const uint memExecute = 0x20000000;
            result.Add(new Section(name,
                Rva: BitConverter.ToUInt32(s, 12),
                VirtualSize: BitConverter.ToUInt32(s, 8),
                RawOffset: BitConverter.ToUInt32(s, 20),
                RawSize: BitConverter.ToUInt32(s, 16),
                Executable: (BitConverter.ToUInt32(s, 36) & memExecute) != 0));
        }
        return result;
    }

    /// <summary>RVA of a named export, or null. Forwarded exports are not followed.</summary>
    public uint? Export(string name)
    {
        var nt = NtHeaders;
        var exportDir = U32(nt + 24 + 112); // PE32+ data directory 0
        if (exportDir == 0) return null;
        var names = U32(exportDir + 32);
        var ordinals = U32(exportDir + 36);
        var functions = U32(exportDir + 28);
        var count = U32(exportDir + 24);
        var wanted = Encoding.ASCII.GetBytes(name + "\0");
        for (uint i = 0; i < count; i++)
        {
            var nameRva = U32(names + i * 4);
            if (!Read(nameRva, wanted.Length).AsSpan().SequenceEqual(wanted)) continue;
            var ordinal = U16(ordinals + i * 2);
            return U32(functions + ordinal * 4u);
        }
        return null;
    }
}

/// <summary>The image as mapped in this process (RVA = offset from the module base).</summary>
internal sealed class LoadedImage : PeImage
{
    private readonly IntPtr _base;
    private readonly long _size;

    public LoadedImage(IntPtr moduleBase, long moduleSize)
    {
        _base = moduleBase;
        _size = moduleSize;
    }

    public override byte[] Read(uint rva, int length)
    {
        var n = (int)Math.Max(0, Math.Min(length, _size - rva));
        var buffer = new byte[n];
        if (n > 0) Marshal.Copy(_base + (nint)rva, buffer, 0, n);
        return buffer;
    }
}

/// <summary>The image as a file on disk, for tests: RVAs are mapped through the section table.</summary>
internal sealed class FileImage : PeImage
{
    private readonly byte[] _file;
    private readonly (uint Rva, uint Span, uint RawOffset, uint RawSize)[] _map;

    public FileImage(byte[] file)
    {
        _file = file;
        // Parse the section table straight from the file: headers sit at file offset == RVA.
        var nt = BitConverter.ToUInt32(file, 0x3c);
        var count = BitConverter.ToUInt16(file, (int)nt + 6);
        var first = (int)nt + 24 + BitConverter.ToUInt16(file, (int)nt + 20);
        _map = new (uint, uint, uint, uint)[count];
        for (var i = 0; i < count; i++)
        {
            var o = first + i * 40;
            var virtualSize = BitConverter.ToUInt32(file, o + 8);
            var rawSize = BitConverter.ToUInt32(file, o + 16);
            _map[i] = (BitConverter.ToUInt32(file, o + 12), Math.Max(virtualSize, rawSize), BitConverter.ToUInt32(file, o + 20), rawSize);
        }
    }

    public override byte[] Read(uint rva, int length)
    {
        long offset = rva, available = _file.Length - (long)rva;
        foreach (var s in _map)
        {
            if (rva < s.Rva || rva >= s.Rva + s.Span) continue;
            offset = s.RawOffset + (rva - s.Rva);
            available = Math.Max(0, (long)s.RawSize - (rva - s.Rva));
            break;
        }
        var n = (int)Math.Max(0, Math.Min(length, Math.Min(available, _file.Length - offset)));
        var buffer = new byte[n];
        if (n > 0) Array.Copy(_file, offset, buffer, 0, n);
        return buffer;
    }
}
