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

/// <summary>
/// Against SimRail's real GameAssembly.dll (Unity 2023.1.8): skipped when the game is not installed.
/// Offsets move with every game update, so these tests check the structure the guard relies on
/// rather than fixed addresses. On the 2026-11-22 build (crash dumps, see FINDINGS.md) the first
/// "V Rising" hit was 0x289310 and the real function 0x54d580; on the 2026-11-27 build they are
/// 0x299a50 and 0x55cff0.
/// </summary>
public class SimRailGameAssemblyTests
{
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

    private static Signature VRising => Signatures.Single(s => s.Name.StartsWith("V Rising"));

    /// <summary>The hit Il2CppInterop hooks: the first match of its "V Rising" signature.</summary>
    private static uint Il2CppInteropPick(PeImage image) => Scan(image, VRising).First();

    /// <summary>The one signature hit that il2cpp_field_static_get_value actually calls.</summary>
    private static uint RealGetDefaultFieldValue(PeImage image)
    {
        var reachable = ReachableTargets(image, image.Export(AnchorExport)!.Value);
        return Assert.Single(Scan(image, VRising).Where(reachable.Contains));
    }

    [Fact]
    public void VRisingSignatureIsAmbiguousAndItsFirstHitIsNotTheRealFunction()
    {
        var image = RequireImage();
        var hits = Scan(image, VRising).ToList();
        Assert.True(hits.Count > 1, $"expected several hits, got {hits.Count}");
        Assert.NotEqual(RealGetDefaultFieldValue(image), hits[0]);
    }

    [Fact]
    public void ExactlyOneHitIsReachableFromTheExport()
    {
        RealGetDefaultFieldValue(RequireImage());
    }

    [Fact]
    public void CorrectsIl2CppInteropsWrongPick()
    {
        var image = RequireImage();
        var resolution = Resolve(image, Il2CppInteropPick(image));
        Assert.Equal(Verdict.Corrected, resolution.Verdict);
        Assert.Equal(RealGetDefaultFieldValue(image), resolution.Rva);
    }

    [Fact]
    public void ConfirmsTheRightPick()
    {
        var image = RequireImage();
        var real = RealGetDefaultFieldValue(image);
        var resolution = Resolve(image, real);
        Assert.Equal(Verdict.Confirmed, resolution.Verdict);
        Assert.Equal(real, resolution.Rva);
    }

    [Fact]
    public void FindsTheFunctionWhenIl2CppInteropFoundNothing()
    {
        var image = RequireImage();
        var resolution = Resolve(image, null);
        Assert.Equal(Verdict.Corrected, resolution.Verdict);
        Assert.Equal(RealGetDefaultFieldValue(image), resolution.Rva);
    }
}
