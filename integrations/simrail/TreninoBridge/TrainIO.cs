using System;
using System.Collections.Generic;
using System.Text.Json;
using Il2Cpp;
using Il2CppAssets.Scripts.Cabin.InputSystemControllers;

namespace TreninoBridge;

/// <summary>
/// Access to the player vehicle's physics IO.
///
/// SimRail models every vehicle's controls and indicators as IO groups
/// (<see cref="IOClassBase"/> components such as Physics_Input_General and
/// Physics_Output_General). Each group is a float array (<c>data</c>) with a
/// parallel array of names (<c>GetNames()</c>). Booleans are 0/1 floats.
///
/// Must only be called on the Unity main thread.
/// </summary>
internal static class TrainIO
{
    public static object Status()
    {
        var vehicle = RailStock.PlayerVehicle;
        if (vehicle == null) return new { ok = true, inTrain = false };

        var groups = new List<object>();
        foreach (var storage in Storages(vehicle))
            groups.Add(new { name = GroupName(storage), fields = storage.GetNames().Length });

        return new { ok = true, inTrain = true, vehicle = vehicle.name, groups };
    }

    public static object ReadAll()
    {
        var result = new Dictionary<string, Dictionary<string, float>>();
        foreach (var storage in Storages(RequireVehicle()))
            result[GroupName(storage)] = ReadStorage(storage);
        return result;
    }

    public static object ReadGroup(string group) => ReadStorage(RequireStorage(group));

    public static object ReadField(string group, string field)
    {
        var storage = RequireStorage(group);
        var index = RequireIndex(storage, field);
        return new { group, field, value = Round(storage.data[index]) };
    }

    public static object WriteField(string group, string field, JsonElement json)
    {
        var storage = RequireStorage(group);
        var index = RequireIndex(storage, field);
        var value = json.ValueKind switch
        {
            JsonValueKind.Number => json.GetSingle(),
            JsonValueKind.True => 1f,
            JsonValueKind.False => 0f,
            _ => throw new BridgeException(400, "value must be a number or boolean"),
        };

        storage.data[index] = value;
        var synced = SyncCabControls(storage, storage.GetNames()[index], value);
        return new { group, field, value = Round(storage.data[index]), syncedControls = synced };
    }

    /// <summary>
    /// Cab controls (levers, switches, buttons) keep their own position state and
    /// only write to physics IO when operated. After writing IO directly we push the
    /// value back into every control bound to that field, using the same
    /// SetStateFromPhysics path the game uses when the player takes over from the AI.
    /// Otherwise the next keyboard/mouse input would continue from a stale position.
    /// </summary>
    private static int SyncCabControls(IOClassBase storage, string field, float value)
    {
        // Controls name their field "<Group>@<field>", e.g. "Physics_Input_EN57@maincontroller_a".
        var qualified = GroupName(storage) + "@" + field;
        var synced = 0;
        foreach (var control in CabControls(RequireVehicle()))
        {
            var name = control.ioFieldName;
            if (!string.Equals(name, qualified, StringComparison.Ordinal) &&
                !string.Equals(name, field, StringComparison.Ordinal)) continue;
            var bound = control.ioField?.storage;
            if (bound != null && bound.Pointer != storage.Pointer) continue;

            control.SetStateFromPhysics(value);
            synced++;
        }
        return synced;
    }

    /// <summary>Cab controls with their bound IO field and their own position state.</summary>
    public static object ListControls()
    {
        var result = new List<object>();
        foreach (var c in CabControls(RequireVehicle()))
        {
            result.Add(new
            {
                control = c.gameObject.name,
                type = c.GetIl2CppType().Name,
                group = c.ioField?.storage != null ? GroupName(c.ioField.storage) : null,
                field = c.ioFieldName,
                position = c.ActualPosition,
                physicsValue = Round(c.CurrentPhysicsValue),
            });
        }
        return result;
    }

    private static IntPtr _controlsVehicle;
    private static PhysicsInteractionInput_Base[] _controls = Array.Empty<PhysicsInteractionInput_Base>();

    private static PhysicsInteractionInput_Base[] CabControls(Vehicle vehicle)
    {
        if (_controlsVehicle != vehicle.Pointer)
        {
            _controls = vehicle.GetComponentsInChildren<PhysicsInteractionInput_Base>(true);
            _controlsVehicle = vehicle.Pointer;
        }
        return _controls;
    }

    // --- helpers ---------------------------------------------------------

    private static Vehicle RequireVehicle() =>
        RailStock.PlayerVehicle ?? throw new BridgeException(409, "not in a train");

    private static IEnumerable<IOClassBase> Storages(Vehicle vehicle)
    {
        var list = vehicle.IOStorageList;
        if (list == null || list.storages == null) yield break;
        foreach (var storage in list.storages)
            if (storage != null) yield return storage;
    }

    private static IOClassBase RequireStorage(string group)
    {
        foreach (var storage in Storages(RequireVehicle()))
            if (string.Equals(GroupName(storage), group, StringComparison.OrdinalIgnoreCase))
                return storage;
        throw new BridgeException(404, $"unknown IO group '{group}'");
    }

    private static int RequireIndex(IOClassBase storage, string field)
    {
        var names = storage.GetNames();
        for (var i = 0; i < names.Length; i++)
            if (string.Equals(names[i], field, StringComparison.OrdinalIgnoreCase))
                return i;
        throw new BridgeException(404, $"unknown field '{field}' in {GroupName(storage)}");
    }

    private static Dictionary<string, float> ReadStorage(IOClassBase storage)
    {
        var names = storage.GetNames();
        var data = storage.data;
        var values = new Dictionary<string, float>(names.Length);
        var count = Math.Min(names.Length, data.Length);
        for (var i = 0; i < count; i++)
            values[names[i]] = Round(data[i]);
        return values;
    }

    private static string GroupName(IOClassBase storage) => storage.GetIl2CppType().Name;

    private static float Round(float v) => MathF.Round(v, 4);
}
