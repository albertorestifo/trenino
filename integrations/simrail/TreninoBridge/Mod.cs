using System;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Security.Cryptography;
using MelonLoader;

[assembly: MelonInfo(typeof(TreninoBridge.Mod), "TreninoBridge", TreninoBridge.Mod.BridgeVersion, "Trenino")]
[assembly: MelonGame("SimKol", "SimRail")]

namespace TreninoBridge;

public sealed class Mod : MelonMod
{
    public const string BridgeVersion = "0.3.0";
    private const int DefaultPort = 31275;
    private const int TswPort = 31270;

    private Server? _server;

    public override void OnInitializeMelon()
    {
        // Stored in <SimRail>\UserData\MelonPreferences.cfg under [TreninoBridge].
        var cat = MelonPreferences.CreateCategory("TreninoBridge");
        var port = cat.CreateEntry("Port", DefaultPort, description: "TCP port for the Trenino bridge API");
        var lan = cat.CreateEntry("ListenOnNetwork", true, description: "Accept connections from other computers (token required)");
        var token = cat.CreateEntry("Token", "", description: "Token LAN/browser clients must send (generated on first run)");

        // 31270 is Train Sim World's External Interface port (and the 0.1 prototype's
        // default): never share it, so Trenino can talk to both games unambiguously.
        if (port.Value == TswPort)
        {
            port.Value = DefaultPort;
            cat.SaveToFile(false);
        }

        if (string.IsNullOrWhiteSpace(token.Value))
        {
            token.Value = Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant();
            cat.SaveToFile(false);
        }

        var address = lan.Value ? IPAddress.Any : IPAddress.Loopback;
        _server = new Server(address, port.Value, token.Value, LoggerInstance);
        try
        {
            _server.Start();
        }
        catch (SocketException e)
        {
            LoggerInstance.Error($"Trenino bridge could not listen on port {port.Value}: {e.Message}");
            return;
        }

        LoggerInstance.Msg($"Trenino bridge API v{Server.Version} on port {port.Value}");
        LoggerInstance.Msg($"  local:   http://127.0.0.1:{port.Value}/api/v1/status");
        if (lan.Value)
        {
            foreach (var ip in LanAddresses())
                LoggerInstance.Msg($"  network: http://{ip}:{port.Value}/api/v1/status  (token required)");
            // Never log the token itself: MelonLoader logs end up in bug reports.
            LoggerInstance.Msg("  token:   see [TreninoBridge] Token in UserData\\MelonPreferences.cfg");
        }
    }

    public override void OnUpdate()
    {
        MainThread.Drain();
        try
        {
            TrainIO.ApplyHolds(StreamHub.HasSessions);
            StreamHub.Tick();
        }
        catch (Exception e)
        {
            // Never let the bridge break the game's update loop; log at most every 5 s.
            if (DateTime.UtcNow - _lastTickError > TimeSpan.FromSeconds(5))
            {
                _lastTickError = DateTime.UtcNow;
                LoggerInstance.Warning($"stream tick failed: {e.GetBaseException().Message}");
            }
        }
    }

    private DateTime _lastTickError = DateTime.MinValue;

    public override void OnDeinitializeMelon() => _server?.Dispose();

    private static IPAddress[] LanAddresses()
    {
        try
        {
            return NetworkInterface.GetAllNetworkInterfaces()
                .Where(n => n.OperationalStatus == OperationalStatus.Up && n.NetworkInterfaceType != NetworkInterfaceType.Loopback)
                .SelectMany(n => n.GetIPProperties().UnicastAddresses)
                .Select(a => a.Address)
                .Where(a => a.AddressFamily == AddressFamily.InterNetwork)
                .ToArray();
        }
        catch { return Array.Empty<IPAddress>(); }
    }
}
