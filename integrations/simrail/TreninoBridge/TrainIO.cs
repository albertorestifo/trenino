using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Il2Cpp;
using Il2CppAssets.Scripts.Cabin.InputSystemControllers;
using Il2CppInterop.Runtime.InteropTypes;
using UnityEngine;
using TreninoBridge.Net;

namespace TreninoBridge;

/// <summary>
/// The player vehicle's physics IO and cab controls.
///
/// SimRail models each vehicle's controls and indicators as IO groups (IOClassBase
/// components, e.g. Physics_Input_EN57). Each group is a float array (data) with a
/// parallel names array (GetNames()). We address a value as "Group.field".
///
/// Cab controls (PhysicsInteractionInput_Base) are bound to one IO field via
/// ioFieldName "Group@field" and keep their own position state.
///
/// Everything here must run on the Unity main thread.
/// </summary>
internal static class TrainIO
{
    internal readonly record struct FieldRef(IOClassBase Storage, int Index, string Path);

    internal sealed class ControlRef
    {
        public string Id { get; init; } = null!;
        public PhysicsInteractionInput_Base Control { get; init; } = null!;
        public object Typed { get; init; } = null!;        // wrapper of the concrete Il2Cpp type
        public string Type { get; init; } = null!;
        public string? Path { get; init; }                  // bound IO path, if any
    }

    private static IntPtr _vehiclePtr;
    private static Dictionary<string, FieldRef> _fields = new(StringComparer.OrdinalIgnoreCase);
    private static List<FieldRef> _fieldList = new();
    private static List<ControlRef> _controls = new();
    private static Dictionary<string, ControlRef> _controlsById = new(StringComparer.Ordinal);
    private static int _generation;

    /// <summary>Incremented whenever the player vehicle changes (or leaves).</summary>
    public static int Generation => _generation;

    /// <summary>Re-indexes when the player vehicle changed. Returns false when not in a train.</summary>
    public static bool Refresh()
    {
        var vehicle = RailStock.PlayerVehicle;
        var ptr = vehicle == null ? IntPtr.Zero : vehicle.Pointer;
        if (ptr == _vehiclePtr) return ptr != IntPtr.Zero;

        _vehiclePtr = ptr;
        _generation++;
        _fields = new(StringComparer.OrdinalIgnoreCase);
        _fieldList = new();
        _controls = new();
        _controlsById = new(StringComparer.Ordinal);
        if (vehicle == null) return false;

        var list = vehicle.IOStorageList;
        if (list?.storages != null)
        {
            foreach (var storage in list.storages)
            {
                if (storage == null) continue;
                var group = GroupName(storage);
                var names = storage.GetNames();
                for (var i = 0; i < names.Length; i++)
                {
                    var f = new FieldRef(storage, i, group + "." + names[i]);
                    _fields[f.Path] = f;
                    _fieldList.Add(f);
                }
            }
        }

        foreach (var control in vehicle.GetComponentsInChildren<PhysicsInteractionInput_Base>(true))
        {
            var id = UniqueId(HierarchyPath(control.transform, vehicle.transform));
            var typeName = control.GetIl2CppType().Name;
            var path = ControlPath(control);
            var c = new ControlRef { Id = id, Control = control, Typed = Wrap(control, typeName), Type = typeName, Path = path };
            _controls.Add(c);
            _controlsById[id] = c;
        }
        return true;
    }

    private static void Require()
    {
        if (!Refresh()) throw new BridgeException(409, "not in a train");
    }

    // --- values -----------------------------------------------------------

    /// <summary>All current values keyed by path.</summary>
    public static Dictionary<string, float> Snapshot()
    {
        var result = new Dictionary<string, float>(_fieldList.Count, StringComparer.OrdinalIgnoreCase);
        if (!Refresh()) return result;
        IOClassBase? last = null;
        Il2CppInterop.Runtime.InteropTypes.Arrays.Il2CppStructArray<float>? data = null;
        foreach (var f in _fieldList)
        {
            if (!ReferenceEquals(f.Storage, last)) { data = f.Storage.data; last = f.Storage; }
            if (data != null && f.Index < data.Length) result[f.Path] = data[f.Index];
        }
        return result;
    }

    public static Dictionary<string, float> Read(IReadOnlyCollection<string>? patterns)
    {
        Require();
        var all = Snapshot();
        if (patterns == null || patterns.Count == 0) return all;
        var matcher = new PathMatcher(patterns);
        return all.Where(kv => matcher.Matches(kv.Key)).ToDictionary(kv => kv.Key, kv => kv.Value, StringComparer.OrdinalIgnoreCase);
    }

    public static object Write(string path, float value)
    {
        Require();
        if (!_fields.TryGetValue(path, out var f)) throw new BridgeException(404, $"unknown path '{path}'");
        if (float.IsNaN(value) || float.IsInfinity(value)) throw new BridgeException(400, "value must be finite");
        f.Storage.data[f.Index] = value;
        var synced = SyncControls(f.Path, value);
        return new { path = f.Path, value = f.Storage.data[f.Index], syncedControls = synced };
    }

    /// <summary>Moves a cab control to a position index, using the game's own notch value.</summary>
    public static object SetControlPosition(string id, int position)
    {
        Require();
        if (!_controlsById.TryGetValue(id, out var c)) throw new BridgeException(404, $"unknown control '{id}'");
        if (c.Path == null) throw new BridgeException(400, $"control '{id}' is not bound to an IO value");
        var positions = Positions(c);
        if (positions.Count == 0) throw new BridgeException(400, $"control '{id}' has no discrete positions");
        if (position < 0 || position >= positions.Count)
            throw new BridgeException(400, $"position must be 0..{positions.Count - 1}");
        var value = positions[position].Value
            ?? throw new BridgeException(400, $"position {position} of '{id}' has no physics value");
        return Write(c.Path, value);
    }

    /// <summary>
    /// After writing IO directly, push the value into every control bound to the
    /// field (the game's SetStateFromPhysics, used when taking over from the AI),
    /// so keyboard/mouse input continues from the written position.
    /// </summary>
    private static int SyncControls(string path, float value)
    {
        var synced = 0;
        foreach (var c in _controls)
        {
            if (!string.Equals(c.Path, path, StringComparison.OrdinalIgnoreCase)) continue;
            c.Control.SetStateFromPhysics(value);
            synced++;
        }
        return synced;
    }

    // --- schema -----------------------------------------------------------

    public static object Vehicle()
    {
        Require();
        var vehicle = RailStock.PlayerVehicle!;
        var groups = _fieldList
            .GroupBy(f => f.Path[..f.Path.IndexOf('.')])
            .Select(g => new { name = g.Key, kind = GroupKind(g.Key), fields = g.Select(f => f.Path[(f.Path.IndexOf('.') + 1)..]).ToArray() })
            .ToArray();

        var controls = _controls.Select(c => new
        {
            id = c.Id,
            type = c.Type,
            kind = ControlKind(c.Type),
            path = c.Path,
            position = c.Control.ActualPosition,
            positions = Positions(c),
        }).ToArray();

        return new
        {
            generation = _generation,
            vehicle = Identity(vehicle),
            groups,
            controls,
        };
    }

    private static object Identity(Vehicle v) => new
    {
        name = Safe(() => v.VehicleName),
        type = Safe(() => v.type.ToString()),
        objectName = Safe(() => v.gameObject.name),
        vehicleNumber = Safe(() => v.vehicleNumber),
        numberInTrainset = Safe(() => v.numberInTrainset),
        isFrontInTrainset = Safe(() => v.IsFrontInTrainset),
    };

    internal sealed record Position(int Index, float? Value, string? Label, float? Lower, float? Upper, bool? Smooth);

    private static List<Position> Positions(ControlRef c)
    {
        var result = new List<Position>();
        if (Prop(c.Typed, "Positions") is not IEnumerable items) return result;
        var i = 0;
        foreach (var p in items)
        {
            if (p == null) { i++; continue; }
            result.Add(new Position(
                i++,
                AsFloat(Prop(p, "PhysicsState")) ?? AsFloat(Prop(p, "PhysicsValue")) ?? AsFloat(Prop(p, "Value")),
                Prop(p, "RadialMenuText") as string ?? Prop(p, "Name") as string,
                AsFloat(Prop(p, "LowerBoundPhysics")),
                AsFloat(Prop(p, "UpperBoundPhysics")),
                Prop(p, "IsSmooth") as bool?));
        }
        return result;
    }

    // --- research dump ----------------------------------------------------

    /// <summary>Everything we can see about the vehicle, for building per-train profiles.</summary>
    public static object Dump()
    {
        Require();
        return new
        {
            schema = Vehicle(),
            values = Snapshot(),
            rawControls = _controls.Select(c => new
            {
                id = c.Id,
                type = c.Type,
                ioFieldName = Safe(() => c.Control.ioFieldName),
                props = Primitives(c.Typed, includePositions: true),
            }).ToArray(),
        };
    }

    private static Dictionary<string, object?> Primitives(object obj, bool includePositions)
    {
        var result = new Dictionary<string, object?>();
        for (var t = obj.GetType(); t != null && t != typeof(Il2CppObjectBase) && t != typeof(MonoBehaviour); t = t.BaseType)
        {
            foreach (var p in t.GetProperties(BindingFlags.Public | BindingFlags.Instance | BindingFlags.DeclaredOnly))
            {
                if (p.GetIndexParameters().Length > 0 || result.ContainsKey(p.Name)) continue;
                object? value;
                try { value = p.GetValue(obj); } catch { continue; }
                switch (value)
                {
                    case null: break;
                    case float f: result[p.Name] = Finite(f); break;
                    case double d: result[p.Name] = double.IsFinite(d) ? d : null; break;
                    case int or bool or string or long or short or byte: result[p.Name] = value; break;
                    case Enum e: result[p.Name] = e.ToString(); break;
                    case Vector2 v2: result[p.Name] = new[] { Finite(v2.x), Finite(v2.y) }; break;
                    case Vector3 v3: result[p.Name] = new[] { Finite(v3.x), Finite(v3.y), Finite(v3.z) }; break;
                    case IEnumerable items when includePositions && p.Name == "Positions":
                        var list = new List<object>();
                        foreach (var item in items) if (item != null) list.Add(Primitives(item, includePositions: false));
                        result[p.Name] = list;
                        break;
                }
            }
        }
        return result;
    }

    // --- helpers ----------------------------------------------------------

    public static string GroupName(IOClassBase storage) => storage.GetIl2CppType().Name;

    private static string GroupKind(string group) =>
        group.StartsWith("Physics_Input", StringComparison.Ordinal) ? "input" :
        group.StartsWith("Physics_Output", StringComparison.Ordinal) ? "output" : "other";

    private static string ControlKind(string type) => type switch
    {
        _ when type.Contains("Lever") => "lever",
        _ when type.Contains("Switch") => "switch",
        _ when type.Contains("Button") => "button",
        _ when type.Contains("Flap") => "flap",
        _ when type.Contains("Dummy") => "decor",
        _ => "other",
    };

    private static string? ControlPath(PhysicsInteractionInput_Base control)
    {
        var name = Safe(() => control.ioFieldName);
        if (string.IsNullOrEmpty(name)) return null;
        var at = name.IndexOf('@');
        var path = at >= 0 ? name[..at] + "." + name[(at + 1)..] : name;
        return _fields.ContainsKey(path) ? _fields[path].Path : null;
    }

    private static string HierarchyPath(Transform t, Transform root)
    {
        var parts = new List<string>();
        for (var cur = t; cur != null && cur.Pointer != root.Pointer; cur = cur.parent) parts.Add(cur.name);
        parts.Reverse();
        return string.Join("/", parts);
    }

    private static string UniqueId(string id)
    {
        if (!_controlsById.ContainsKey(id)) return id;
        for (var n = 2; ; n++) if (!_controlsById.ContainsKey($"{id}#{n}")) return $"{id}#{n}";
    }

    private static readonly Dictionary<string, Type?> WrapperTypes = new(StringComparer.Ordinal);

    /// <summary>GetComponentsInChildren returns base wrappers; re-wrap as the concrete type to see its fields.</summary>
    private static object Wrap(PhysicsInteractionInput_Base control, string il2CppTypeName)
    {
        if (!WrapperTypes.TryGetValue(il2CppTypeName, out var type))
        {
            type = typeof(PhysicsInteractionInput_Base).Assembly.GetTypes()
                .FirstOrDefault(t => t.Name == il2CppTypeName && typeof(PhysicsInteractionInput_Base).IsAssignableFrom(t));
            WrapperTypes[il2CppTypeName] = type;
        }
        if (type == null) return control;
        try { return Activator.CreateInstance(type, control.Pointer) ?? control; }
        catch { return control; }
    }

    private static object? Prop(object obj, string name)
    {
        try { return obj.GetType().GetProperty(name, BindingFlags.Public | BindingFlags.Instance)?.GetValue(obj); }
        catch { return null; }
    }

    private static float? AsFloat(object? v) => v switch { float f => Finite(f), int i => i, double d => (float)d, _ => null };

    private static float? Finite(float f) => float.IsFinite(f) ? f : null;

    private static T? Safe<T>(Func<T> f) { try { return f(); } catch { return default; } }
}

/// <summary>Matches "Group.field", "Group.*" and "*" (case-insensitive).</summary>
internal sealed class PathMatcher
{
    private readonly bool _all;
    private readonly HashSet<string> _exact = new(StringComparer.OrdinalIgnoreCase);
    private readonly List<string> _prefixes = new();

    public PathMatcher(IEnumerable<string> patterns)
    {
        foreach (var p in patterns)
        {
            if (p == "*") _all = true;
            else if (p.EndsWith(".*", StringComparison.Ordinal)) _prefixes.Add(p[..^1]);
            else _exact.Add(p);
        }
    }

    public bool IsEmpty => !_all && _exact.Count == 0 && _prefixes.Count == 0;

    public bool Matches(string path) =>
        _all || _exact.Contains(path) || _prefixes.Any(prefix => path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
}
