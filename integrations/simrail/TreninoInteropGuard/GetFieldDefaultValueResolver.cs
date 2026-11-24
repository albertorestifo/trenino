using System;
using System.Collections.Generic;
using System.Linq;
using Iced.Intel;

namespace TreninoInteropGuard;

/// <summary>
/// Finds IL2CPP's <c>Class::GetDefaultFieldValue(FieldInfo*, Il2CppType**)</c> without trusting a bare byte pattern.
///
/// Il2CppInterop locates it with short prologue signatures and takes the first hit in the module. On Unity
/// 2023.1 (SimRail) the "V Rising" signature matches nine functions and the first is generated game code
/// with a different signature, so the hook garbles every call to it and the game dies
/// (BepInEx/Il2CppInterop#284).
///
/// A signature hit is accepted here only if it is also reachable through direct calls/jumps from the
/// <c>il2cpp_field_static_get_value</c> export, the same anchor Il2CppInterop's own fallback uses:
/// export -> Field::StaticGetValue -> (Field::StaticGetValueInternal | Field::GetDefaultFieldValue) -> target.
/// </summary>
internal static class GetFieldDefaultValueResolver
{
    public const string AnchorExport = "il2cpp_field_static_get_value";
    public const int MaxDepth = 4;
    private const int MaxFunctions = 256;
    private const int MaxFunctionBytes = 0x800;

    internal readonly record struct Signature(string Name, byte[] Pattern, string Mask);

    /// <summary>Il2CppInterop's x64 signatures, plus the imm32-frame variant from BepInEx/Il2CppInterop#284.</summary>
    public static readonly Signature[] Signatures =
    {
        Sig("Unity 2021.3.4", "48 89 5C 24 08 48 89 74 24 10 57 48 83 EC 20 48 8B 79 10 48 8B D9 48 8B F2 48 2B 9F", "xxxxxxxxxxxxxx?xxxxxxxxxxxxx"),
        Sig("Unity 2021.3.4, imm32 frame", "48 89 5C 24 08 48 89 74 24 10 57 48 81 EC 00 00 00 00 48 8B 79 10 48 8B D9 48 8B F2 48 2B 9F", "xxxxxxxxxxxxxx????xxxxxxxxxxxxx"),
        Sig("V Rising, Unity 2022.3.23", "48 89 5C 24 08 48 89 74 24 10 57 48 83 EC 40 48 8B 41 10", "xxxxxxxxxxxxxxxxxxx"),
        Sig("GTFO, Unity 2019.4.21", "48 89 5C 24 08 57 48 83 EC 20 48 8B 41 10 48 8B D9 48 8B", "xxxxxxxxx?xxxxxxxxx"),
        Sig("Idle Slayer, Unity 2021.3.17", "40 53 48 83 EC 20 48 8B DA E8 00 00 00 00 4C 8B C8 48 85 C0", "xxxxxxxxxx????xxxxxx"),
        Sig("Idle Slayer, Unity 2021.3.23", "40 53 48 83 EC 20 48 8B DA E8 CC CC CC CC 4C", "xxxxxxxxxx????x"),
    };

    private static Signature Sig(string name, string hex, string mask) =>
        new(name, hex.Split(' ').Select(h => Convert.ToByte(h, 16)).ToArray(), mask);

    internal enum Verdict { Confirmed, Corrected, Unresolved }

    internal readonly record struct Resolution(Verdict Verdict, uint? Rva, string Detail);

    /// <summary>Checks Il2CppInterop's pick (<paramref name="chosenRva"/>) and replaces it if it is not plausible.</summary>
    public static Resolution Resolve(PeImage image, uint? chosenRva)
    {
        var anchor = image.Export(AnchorExport);
        if (anchor == null) return new(Verdict.Unresolved, null, $"export {AnchorExport} not found");

        var reachable = ReachableTargets(image, anchor.Value);
        if (chosenRva is { } chosen && reachable.Contains(chosen))
            return new(Verdict.Confirmed, chosen, $"reachable from {AnchorExport}");

        foreach (var sig in Signatures)
        {
            var hits = Scan(image, sig).ToList();
            var hit = hits.FirstOrDefault(reachable.Contains);
            if (hit != 0)
                return new(Verdict.Corrected, hit,
                    $"signature '{sig.Name}' matched {hits.Count} function(s); the one reachable from {AnchorExport} is {hit:X}");
        }

        return new(Verdict.Unresolved, null,
            $"no signature hit is reachable from {AnchorExport} ({reachable.Count} reachable functions)");
    }

    /// <summary>
    /// Direct call/jump targets reachable from <paramref name="start"/> within <see cref="MaxDepth"/> hops.
    /// Mirrors Il2CppInterop's XrefScannerLowLevel.JumpTargets: decode until ret or int3, skip short jumps,
    /// and treat a function that starts with a jmp as a thunk.
    /// </summary>
    public static HashSet<uint> ReachableTargets(PeImage image, uint start)
    {
        var seen = new HashSet<uint> { start };
        var frontier = new List<uint> { start };
        for (var depth = 0; depth < MaxDepth && frontier.Count > 0 && seen.Count < MaxFunctions; depth++)
        {
            var next = new List<uint>();
            foreach (var function in frontier)
                foreach (var target in JumpTargets(image, function))
                    if (seen.Count < MaxFunctions && seen.Add(target)) next.Add(target);
            frontier = next;
        }
        seen.Remove(start);
        return seen;
    }

    public static IEnumerable<uint> JumpTargets(PeImage image, uint rva)
    {
        var code = image.Read(rva, MaxFunctionBytes);
        var decoder = Decoder.Create(64, new ByteArrayCodeReader(code));
        decoder.IP = rva;
        var end = rva + (ulong)code.Length;
        var firstFlowControl = true;
        while (decoder.IP < end)
        {
            decoder.Decode(out var instruction);
            if (instruction.IsInvalid || instruction.Mnemonic == Mnemonic.Int3) yield break;
            if (instruction.FlowControl == FlowControl.Return) yield break;

            var isBranch = instruction.FlowControl is FlowControl.UnconditionalBranch or FlowControl.Call;
            if (isBranch && !instruction.IsJmpShort && instruction.Op0Kind == OpKind.NearBranch64)
            {
                yield return (uint)instruction.NearBranchTarget;
                if (firstFlowControl && instruction.FlowControl == FlowControl.UnconditionalBranch) yield break;
            }
            if (instruction.FlowControl != FlowControl.Next) firstFlowControl = false;
        }
    }

    /// <summary>Every RVA in an executable section where <paramref name="sig"/> matches.</summary>
    public static IEnumerable<uint> Scan(PeImage image, Signature sig)
    {
        const int chunk = 4 << 20;
        var overlap = sig.Pattern.Length - 1;
        foreach (var section in image.Sections.Where(s => s.Executable))
        {
            var size = Math.Max(section.VirtualSize, section.RawSize);
            for (uint offset = 0; offset < size; offset += chunk)
            {
                var bytes = image.Read(section.Rva + offset, (int)Math.Min(chunk + overlap, size - offset));
                foreach (var i in Matches(bytes, sig))
                    if (i < chunk) yield return section.Rva + offset + (uint)i;
            }
        }
    }

    internal static IEnumerable<int> Matches(byte[] bytes, Signature sig)
    {
        var pattern = sig.Pattern;
        var first = pattern[0];
        for (var i = 0; i <= bytes.Length - pattern.Length; i++)
        {
            if (bytes[i] != first) continue;
            var ok = true;
            for (var j = 1; j < pattern.Length && ok; j++)
                ok = sig.Mask[j] == '?' || bytes[i + j] == pattern[j];
            if (ok) yield return i;
        }
    }
}
