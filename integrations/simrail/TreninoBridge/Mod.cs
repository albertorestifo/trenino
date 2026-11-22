using MelonLoader;

[assembly: MelonInfo(typeof(TreninoBridge.Mod), "TreninoBridge", "0.1.0", "Trenino")]
[assembly: MelonGame("SimKol", "SimRail")]

namespace TreninoBridge;

public sealed class Mod : MelonMod
{
    private MelonPreferences_Entry<int>? _port;
    private HttpApi? _api;

    public override void OnInitializeMelon()
    {
        var category = MelonPreferences.CreateCategory("TreninoBridge");
        _port = category.CreateEntry("Port", 31270, description: "Loopback HTTP port for Trenino");

        _api = new HttpApi(_port.Value, LoggerInstance);
        _api.Start();
        LoggerInstance.Msg($"Trenino bridge listening on http://127.0.0.1:{_port.Value}/");
    }

    public override void OnUpdate() => MainThread.Drain();

    public override void OnDeinitializeMelon() => _api?.Dispose();
}
