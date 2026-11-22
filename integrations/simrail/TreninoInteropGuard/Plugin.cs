using System;
using System.Diagnostics;
using System.Linq;
using HarmonyLib;
using MelonLoader;

[assembly: MelonInfo(typeof(TreninoInteropGuard.Plugin), "TreninoInteropGuard", TreninoInteropGuard.Plugin.GuardVersion, "Trenino")]
[assembly: MelonGame("SimKol", "SimRail")]
[assembly: System.Runtime.CompilerServices.InternalsVisibleTo("TreninoInteropGuard.Tests")]

namespace TreninoInteropGuard;

/// <summary>
/// Stops Il2CppInterop from hooking the wrong function as Class::GetDefaultFieldValue
/// (BepInEx/Il2CppInterop#284), which crashed SimRail on a game threadpool thread with an
/// ExecutionEngineException in Class_GetFieldDefaultValue_Hook.
///
/// Must be a plugin (Plugins\, loaded before Il2CppInterop starts), not a mod: by the time mods
/// initialize, the hook is already installed.
/// </summary>
public sealed class Plugin : MelonPlugin
{
    public const string GuardVersion = "1.0.0";
    private const string HookType = "Il2CppInterop.Runtime.Injection.Hooks.Class_GetFieldDefaultValue_Hook";

    internal static MelonLogger.Instance? Log;

    public override void OnPreInitialization()
    {
        Log = LoggerInstance;
        var target = AccessTools.TypeByName(HookType)?.GetMethod("FindTargetMethod");
        if (target == null)
        {
            LoggerInstance.Warning("Il2CppInterop hook type not found; nothing to guard");
            return;
        }
        HarmonyInstance.Patch(target, postfix: new HarmonyMethod(typeof(Plugin), nameof(FindTargetMethodPostfix)));
        LoggerInstance.Msg("Guarding Il2CppInterop's Class::GetDefaultFieldValue lookup");
    }

    private static void FindTargetMethodPostfix(ref IntPtr __result)
    {
        try
        {
            var module = Process.GetCurrentProcess().Modules.Cast<ProcessModule>()
                .FirstOrDefault(m => string.Equals(m.ModuleName, "GameAssembly.dll", StringComparison.OrdinalIgnoreCase));
            if (module == null)
            {
                Report("GameAssembly.dll not loaded; left Il2CppInterop's choice alone", warn: true);
                return;
            }

            var image = new LoadedImage(module.BaseAddress, module.ModuleMemorySize);
            var chosen = __result == IntPtr.Zero ? (uint?)null : (uint)(__result.ToInt64() - module.BaseAddress.ToInt64());
            var resolution = GetFieldDefaultValueResolver.Resolve(image, chosen);
            var was = chosen is { } c ? $"GameAssembly+0x{c:X}" : "nothing";

            switch (resolution.Verdict)
            {
                case GetFieldDefaultValueResolver.Verdict.Confirmed:
                    Report($"Class::GetDefaultFieldValue at {was} confirmed ({resolution.Detail})");
                    break;
                case GetFieldDefaultValueResolver.Verdict.Corrected:
                    __result = module.BaseAddress + (nint)resolution.Rva!.Value;
                    Report($"Il2CppInterop picked {was}, which is not Class::GetDefaultFieldValue; hooking GameAssembly+0x{resolution.Rva:X} instead ({resolution.Detail})", warn: true);
                    break;
                default:
                    // Without a verified alternative, keep Il2CppInterop's behaviour rather than break class injection.
                    Report($"could not verify Il2CppInterop's pick {was}: {resolution.Detail}. If SimRail crashes in Class_GetFieldDefaultValue_Hook, this is why", warn: true);
                    break;
            }
        }
        catch (Exception e)
        {
            Report($"guard failed, left Il2CppInterop's choice alone: {e}", warn: true);
        }
    }

    private static void Report(string message, bool warn = false)
    {
        if (warn) Log?.Warning(message);
        else Log?.Msg(message);
    }
}
