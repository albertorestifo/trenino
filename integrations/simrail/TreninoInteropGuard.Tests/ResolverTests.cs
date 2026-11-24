using System;
using System.IO;
using System.Linq;
using System.Reflection;
using TreninoInteropGuard;
using Xunit;
using static TreninoInteropGuard.GetFieldDefaultValueResolver;

namespace TreninoInteropGuard.Tests;

[AttributeUsage(AttributeTargets.Assembly)]
public sealed class SimRailDirAttribute(string path) : Attribute
{
    public string Path { get; } = path;
}

public class MatcherTests
{
    private static readonly Signature Sig = new("test", new byte[] { 0x48, 0x89, 0x5C, 0x00, 0x08 }, "xxx?x");

    [Fact]
    public void FindsEveryMatchAndHonoursWildcards()
    {
        var bytes = new byte[] { 0x90, 0x48, 0x89, 0x5C, 0x24, 0x08, 0x48, 0x89, 0x5C, 0xFF, 0x08, 0x48, 0x89 };
        Assert.Equal(new[] { 1, 6 }, Matches(bytes, Sig).ToArray());
    }

    [Fact]
    public void IgnoresAPatternCutOffAtTheEnd()
    {
        var bytes = new byte[] { 0x48, 0x89, 0x5C, 0x24 };
        Assert.Empty(Matches(bytes, Sig));
    }
}

/// <summary>Against SimRail's real GameAssembly.dll (Unity 2023.1.8): skipped when the game is not installed.</summary>
public class SimRailGameAssemblyTests
{
    // Values established from the crash dumps of 2026-11-22 (see FINDINGS.md).
    private const uint CrashedHookTarget = 0x289310;   // first "V Rising" signature hit: generated game code
    private const uint RealGetDefaultFieldValue = 0x54d580; // called from Field::StaticGetValueInternal with &type

    private static readonly Lazy<PeImage?> Image = new(() =>
    {
        var dir = typeof(SimRailGameAssemblyTests).Assembly.GetCustomAttribute<SimRailDirAttribute>()?.Path;
        var path = dir == null ? null : System.IO.Path.Combine(dir, "GameAssembly.dll");
        return path != null && File.Exists(path) ? new FileImage(File.ReadAllBytes(path)) : null;
    });

    private static PeImage RequireImage()
    {
        Assert.SkipWhen(Image.Value == null, "SimRail GameAssembly.dll not found");
        return Image.Value!;
    }

    [Fact]
    public void VRisingSignatureIsAmbiguousAndItsFirstHitIsTheCrashedFunction()
    {
        var image = RequireImage();
        var vRising = Signatures.Single(s => s.Name.StartsWith("V Rising"));
        var hits = Scan(image, vRising).ToList();
        Assert.True(hits.Count > 1, $"expected several hits, got {hits.Count}");
        Assert.Equal(CrashedHookTarget, hits[0]);
        Assert.Contains(RealGetDefaultFieldValue, hits);
    }

    [Fact]
    public void OnlyTheRealFunctionAmongTheHitsIsReachableFromTheExport()
    {
        var image = RequireImage();
        var reachable = ReachableTargets(image, image.Export(AnchorExport)!.Value);
        var vRising = Signatures.Single(s => s.Name.StartsWith("V Rising"));
        var reachableHits = Scan(image, vRising).Where(reachable.Contains).ToList();
        Assert.Equal(new[] { RealGetDefaultFieldValue }, reachableHits);
    }

    [Fact]
    public void CorrectsIl2CppInteropsWrongPick()
    {
        var resolution = Resolve(RequireImage(), CrashedHookTarget);
        Assert.Equal(Verdict.Corrected, resolution.Verdict);
        Assert.Equal(RealGetDefaultFieldValue, resolution.Rva);
    }

    [Fact]
    public void ConfirmsTheRightPick()
    {
        var resolution = Resolve(RequireImage(), RealGetDefaultFieldValue);
        Assert.Equal(Verdict.Confirmed, resolution.Verdict);
        Assert.Equal(RealGetDefaultFieldValue, resolution.Rva);
    }

    [Fact]
    public void FindsTheFunctionWhenIl2CppInteropFoundNothing()
    {
        var resolution = Resolve(RequireImage(), null);
        Assert.Equal(Verdict.Corrected, resolution.Verdict);
        Assert.Equal(RealGetDefaultFieldValue, resolution.Rva);
    }
}
