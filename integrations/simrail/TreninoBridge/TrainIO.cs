using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Il2CppInterop.Runtime.InteropTypes;
using Il2CppInterop.Runtime.InteropTypes.Arrays;
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
///
/// Game objects are <c>dynamic</c>: the game's types are found at runtime (see <see cref="Game"/>),
/// so the bridge builds without SimRail's generated assemblies.
/// </summary>
internal static class TrainIO
{
    /// <param name="Storage">An IOClassBase wrapper.</param>
    internal readonly record struct FieldRef(Il2CppObjectBase Storage, int Index, string Path);

    internal sealed class ControlRef
    {
        public string Id { get; init; } = null!;
        public dynamic Control { get; init; } = null!;              // PhysicsInteractionInput_Base wrapper
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
        var vehicle = Game.PlayerVehicle();
        IntPtr ptr = vehicle == null ? IntPtr.Zero : ((Il2CppObjectBase)vehicle).Pointer;
        if (ptr == _vehiclePtr) return ptr != IntPtr.Zero;

        if (vehicle == null)
        {
            Publish(IntPtr.Zero, new(StringComparer.OrdinalIgnoreCase), new(), new(), new(StringComparer.Ordinal));
            return false;
        }

        // Build into locals and publish only once complete: if the vehicle is half
        // spawned and something throws, the next Refresh tries again instead of
        // serving a partial index under this vehicle's pointer.
        var fields = new Dictionary<string, FieldRef>(StringComparer.OrdinalIgnoreCase);
        var fieldList = new List<FieldRef>();
        dynamic? list = vehicle.IOStorageList;
        if (Game.IsAlive(list))
        {
            foreach (var item in Game.Enumerate((object?)list.storages))
            {
                if (item is not Il2CppObjectBase storage || !Game.IsAlive(storage)) continue;
                var group = GroupName(storage);
                dynamic names = ((dynamic)storage).GetNames();
                int count = names.Length;
                for (var i = 0; i < count; i++)
                {
                    string name = names[i];
                    var f = new FieldRef(storage, i, group + "." + name);
                    fields[f.Path] = f;
                    fieldList.Add(f);
                }
            }
        }

        var controls = new List<ControlRef>();
        var controlsById = new Dictionary<string, ControlRef>(StringComparer.Ordinal);
        foreach (var item in Game.Controls((object)vehicle))
        {
            dynamic control = item;
            string id = UniqueId(controlsById, HierarchyPath(control.transform, vehicle.transform));
            string typeName = control.GetIl2CppType().Name;
            string? path = ControlPath(fields, (object)control);
            var c = new ControlRef { Id = id, Control = control, Typed = Wrap((object)control, typeName), Type = typeName, Path = path };
            controls.Add(c);
            controlsById[id] = c;
        }

        Publish(ptr, fields, fieldList, controls, controlsById);
        return true;
    }

    private static void Publish(IntPtr ptr, Dictionary<string, FieldRef> fields, List<FieldRef> fieldList,
        List<ControlRef> controls, Dictionary<string, ControlRef> controlsById)
    {
        _fields = fields;
        _fieldList = fieldList;
        _controls = controls;
        _controlsById = controlsById;
        _vehiclePtr = ptr;
        _generation++;
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
        Il2CppObjectBase? last = null;
        Il2CppStructArray<float>? data = null;
        foreach (var f in _fieldList)
        {
            if (!ReferenceEquals(f.Storage, last)) { data = Data(f.Storage); last = f.Storage; }
            // Non-finite floats would serialize as "NaN"/"Infinity" strings: leave them out.
            if (data != null && f.Index < data.Length && float.IsFinite(data[f.Index])) result[f.Path] = data[f.Index];
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
        var data = Data(f.Storage) ?? throw new BridgeException(500, $"no data for '{path}'");
        data[f.Index] = value;
        var synced = SyncControls(f.Path, value);
        return new { path = f.Path, value = data[f.Index], syncedControls = synced };
    }

    /// <summary>Moves a cab control to a position index, using the game's own notch value.</summary>
    public static object SetControlPosition(string id, int position)
    {
        Require();
        if (!_controlsById.TryGetValue(id, out var c)) throw new BridgeException(404, $"unknown control '{id}'");
        if (c.Path == null) throw new BridgeException(400, $"control '{id}' is not bound to an IO value");
        var positions = Positions(c);
        if (positions.Count == 0) throw new BridgeException(400, $"control '{id}' has no discrete positions");
        // Look up by the game's index: null entries are skipped, so list offsets can differ.
        var target = positions.FirstOrDefault(p => p.Index == position)
            ?? throw new BridgeException(400, $"position must be one of {string.Join(", ", positions.Select(p => p.Index))}");
        var value = target.Value
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
        object vehicle = (object?)Game.PlayerVehicle() ?? throw new BridgeException(409, "not in a train");
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
            position = Safe(() => (int?)c.Control.ActualPosition),
            positions = Positions(c),
            button = Button(c),
            actions = Actions(c),
        }).ToArray();

        return new
        {
            generation = _generation,
            vehicle = Identity(vehicle),
            groups,
            controls,
        };
    }

    private static object Identity(object vehicle)
    {
        dynamic v = vehicle;
        return new
        {
            name = Safe(() => (string?)v.VehicleName),
            type = Safe(() => (string?)v.type.ToString()),
            objectName = Safe(() => (string?)v.gameObject.name),
            vehicleNumber = Safe(() => (object?)v.vehicleNumber),
            numberInTrainset = Safe(() => (object?)v.numberInTrainset),
            isFrontInTrainset = Safe(() => (object?)v.IsFrontInTrainset),
        };
    }

    /// <param name="Stable">
    /// Position index the control springs back to when released. Equal to Index for
    /// positions that hold; different for momentary ("nudge") positions, e.g. the
    /// Traxx traction lever where 4 and 6 spring back to 5.
    /// </param>
    internal sealed record Position(int Index, float? Value, string? Label, int? Stable, float? Lower, float? Upper, bool? Smooth);

    /// <summary>Push buttons write Pressed while held and Released otherwise.</summary>
    internal sealed record ButtonValues(float? Pressed, float? Released, bool? Toggle);

    private static ButtonValues? Button(ControlRef c)
    {
        var pressed = AsFloat(Prop(c.Typed, "pressedPhysicsValue"));
        var released = AsFloat(Prop(c.Typed, "nonPressedPhysicsValue"));
        if (pressed == null && released == null) return null;
        return new ButtonValues(pressed, released, c.Type.Contains("Toggle") ? true : null);
    }

    /// <summary>Game input-action names bound to the control (keyboard/joystick bindings use these).</summary>
    private static string[]? Actions(ControlRef c)
    {
        var names = new[] { "pressedActionName", "ActionNameIncreases", "ActionNameDecrease", "ActionName", "ActionNameToggle" }
            .Select(n => Prop(c.Typed, n) as string)
            .Where(s => !string.IsNullOrEmpty(s))
            .Select(s => s!)
            .Distinct()
            .ToArray();
        return names.Length > 0 ? names : null;
    }

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
                NullIfEmpty(Prop(p, "RadialMenuText") as string ?? Prop(p, "Name") as string),
                Prop(p, "StablePosition") switch { int s => s, float f => (int)f, _ => null },
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
                ioFieldName = Safe(() => (string?)c.Control.ioFieldName),
                props = Primitives(c.Typed, includePositions: true),
            }).ToArray(),
        };
    }

    private static Dictionary<string, object?> Primitives(object obj, bool includePositions)
    {
        var result = new Dictionary<string, object?>();
        for (var t = obj.GetType(); t != null && t != typeof(Il2CppObjectBase) && t.Name != "MonoBehaviour"; t = t.BaseType)
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
                    case ValueType when Game.VectorComponents(value) is { } vector:
                        result[p.Name] = vector.Select(Finite).ToArray();
                        break;
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

    public static string GroupName(Il2CppObjectBase storage) => (string)((dynamic)storage).GetIl2CppType().Name;

    // IOClassBase.data: the group's values, parallel to GetNames().
    private static Il2CppStructArray<float>? Data(Il2CppObjectBase storage) =>
        (Il2CppStructArray<float>?)((dynamic)storage).data;

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

    private static string? ControlPath(Dictionary<string, FieldRef> fields, object controlObj)
    {
        dynamic control = controlObj;
        string? name = Safe(() => (string?)control.ioFieldName);
        if (string.IsNullOrEmpty(name)) return null;
        var at = name.IndexOf('@');
        var path = at >= 0 ? name[..at] + "." + name[(at + 1)..] : name;
        return fields.TryGetValue(path, out var f) ? f.Path : null;
    }

    private static string HierarchyPath(dynamic t, dynamic root)
    {
        var parts = new List<string>();
        IntPtr rootPtr = ((Il2CppObjectBase)root).Pointer;
        for (dynamic? cur = t; Game.IsAlive(cur) && ((Il2CppObjectBase)cur).Pointer != rootPtr; cur = cur.parent)
            parts.Add((string)cur.name);
        parts.Reverse();
        return string.Join("/", parts);
    }

    private static string UniqueId(Dictionary<string, ControlRef> taken, string id)
    {
        if (!taken.ContainsKey(id)) return id;
        for (var n = 2; ; n++) if (!taken.ContainsKey($"{id}#{n}")) return $"{id}#{n}";
    }

    private static readonly Dictionary<string, Type?> WrapperTypes = new(StringComparer.Ordinal);

    /// <summary>GetComponentsInChildren returns base wrappers; re-wrap as the concrete type to see its fields.</summary>
    private static object Wrap(object control, string il2CppTypeName)
    {
        var baseType = Game.ControlBase;
        if (!WrapperTypes.TryGetValue(il2CppTypeName, out var type))
        {
            Type[] all;
            try { all = baseType.Assembly.GetTypes(); }
            catch (ReflectionTypeLoadException e) { all = e.Types.Where(t => t != null).ToArray()!; }
            type = all.FirstOrDefault(t => t.Name == il2CppTypeName && baseType.IsAssignableFrom(t));
            WrapperTypes[il2CppTypeName] = type;
        }
        if (type == null) return control;
        try { return Activator.CreateInstance(type, ((Il2CppObjectBase)control).Pointer) ?? control; }
        catch { return control; }
    }

    private static object? Prop(object obj, string name)
    {
        try { return obj.GetType().GetProperty(name, BindingFlags.Public | BindingFlags.Instance)?.GetValue(obj); }
        catch { return null; }
    }

    private static float? AsFloat(object? v) => v switch { float f => Finite(f), int i => i, double d => Finite((float)d), _ => null };

    private static float? Finite(float f) => float.IsFinite(f) ? f : null;

    private static string? NullIfEmpty(string? s) => string.IsNullOrEmpty(s) ? null : s;

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
