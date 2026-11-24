using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace TreninoBridge;

/// <summary>
/// SimRail's game types, found by name at runtime.
///
/// The bridge does not compile against the assemblies MelonLoader generates from the game
/// (Assembly-CSharp, UnityEngine.CoreModule, Il2Cppmscorlib): those are derived from SimRail
/// and exist only on a player's PC, so CI could not build against them. Instead the bridge
/// looks the few types it needs up in the loaded assemblies and talks to them through
/// <c>dynamic</c> and reflection. A SimRail update that renames one of them shows up as a
/// <see cref="BridgeException"/> naming what is missing, logged and returned by the API.
/// </summary>
internal static class Game
{
    private static Type? _railStock;
    private static Type? _controlBase;
    private static MethodInfo? _componentsInChildren;
    private static PropertyInfo? _playerVehicle;

    /// <summary>The player's vehicle wrapper, or null when not in a train (Unity null included).</summary>
    public static dynamic? PlayerVehicle()
    {
        _railStock ??= FindType("Assembly-CSharp", "RailStock");
        _playerVehicle ??= _railStock.GetProperty("PlayerVehicle", BindingFlags.Public | BindingFlags.Static)
            ?? throw Missing("RailStock.PlayerVehicle");
        dynamic? vehicle = _playerVehicle.GetValue(null);
        return IsAlive(vehicle) ? vehicle : null;
    }

    /// <summary>PhysicsInteractionInput_Base: the base wrapper of every cab control.</summary>
    public static Type ControlBase => _controlBase ??= FindType("Assembly-CSharp", "PhysicsInteractionInput_Base");

    /// <summary>
    /// Every cab control under the vehicle, including inactive ones
    /// (Component.GetComponentsInChildren&lt;PhysicsInteractionInput_Base&gt;(true)).
    /// </summary>
    public static IEnumerable<object> Controls(object vehicle)
    {
        _componentsInChildren ??= vehicle.GetType()
            .GetMethods(BindingFlags.Public | BindingFlags.Instance)
            .FirstOrDefault(m => m.Name == "GetComponentsInChildren" && m.IsGenericMethodDefinition &&
                                 m.GetParameters() is { Length: 1 } ps && ps[0].ParameterType == typeof(bool))
            ?.MakeGenericMethod(ControlBase)
            ?? throw Missing("Component.GetComponentsInChildren<T>(bool)");
        return Enumerate(_componentsInChildren.Invoke(vehicle, new object[] { true }));
    }

    /// <summary>
    /// Unity's null check: a destroyed object keeps its wrapper, and UnityEngine.Object's ==
    /// reports it as null. The runtime binder applies that operator for a dynamic comparison.
    /// </summary>
    public static bool IsAlive(dynamic? obj)
    {
        if (obj is null) return false;
        try { return !(obj == null); }
        catch { return true; }
    }

    /// <summary>
    /// Items of an IL2CPP collection wrapper. Arrays implement IEnumerable; Il2CppSystem
    /// collections only have a GetEnumerator() with MoveNext/Current, which a static foreach
    /// would have bound by pattern.
    /// </summary>
    public static IEnumerable<object> Enumerate(object? collection)
    {
        switch (collection)
        {
            case null:
                yield break;
            case IEnumerable items:
                foreach (var item in items) if (item != null) yield return item;
                yield break;
        }

        var getEnumerator = collection.GetType().GetMethod("GetEnumerator", BindingFlags.Public | BindingFlags.Instance, Type.EmptyTypes)
            ?? throw new BridgeException(500, $"cannot enumerate {collection.GetType().Name}");
        var enumerator = getEnumerator.Invoke(collection, null)!;
        var moveNext = enumerator.GetType().GetMethod("MoveNext", Type.EmptyTypes)!;
        var current = enumerator.GetType().GetProperty("Current")!;
        while ((bool)moveNext.Invoke(enumerator, null)!)
        {
            var item = current.GetValue(enumerator);
            if (item != null) yield return item;
        }
    }

    /// <summary>The components of a UnityEngine Vector2/Vector3 value, else null.</summary>
    public static float[]? VectorComponents(object value)
    {
        var type = value.GetType();
        if (!type.IsValueType || (type.Name != "Vector2" && type.Name != "Vector3")) return null;
        var names = type.Name == "Vector2" ? new[] { "x", "y" } : new[] { "x", "y", "z" };
        var result = new float[names.Length];
        for (var i = 0; i < names.Length; i++)
        {
            if (type.GetField(names[i], BindingFlags.Public | BindingFlags.Instance)?.GetValue(value) is not float f) return null;
            result[i] = f;
        }
        return result;
    }

    private static readonly Dictionary<string, Type> Types = new(StringComparer.Ordinal);

    /// <summary>A type by simple name in one of the loaded game assemblies.</summary>
    public static Type FindType(string assembly, string name)
    {
        var key = assembly + "/" + name;
        if (Types.TryGetValue(key, out var cached)) return cached;
        var asm = AppDomain.CurrentDomain.GetAssemblies().FirstOrDefault(a => a.GetName().Name == assembly)
            ?? throw Missing($"assembly {assembly}");
        Type[] all;
        try { all = asm.GetTypes(); }
        catch (ReflectionTypeLoadException e) { all = e.Types.Where(t => t != null).ToArray()!; }
        var matches = all.Where(t => t.Name == name).ToArray();
        var type = matches.Length switch
        {
            0 => throw Missing($"type {name} in {assembly}"),
            1 => matches[0],
            // Prefer the generated top-level game type over nested or same-named helpers.
            _ => matches.FirstOrDefault(t => !t.IsNested && t.Namespace is "Il2Cpp" or null) ?? matches[0],
        };
        Types[key] = type;
        return type;
    }

    private static BridgeException Missing(string what) =>
        new(500, $"SimRail changed: {what} not found. TreninoBridge needs an update for this game version.");
}
