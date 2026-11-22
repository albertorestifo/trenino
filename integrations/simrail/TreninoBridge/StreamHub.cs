using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Channels;

namespace TreninoBridge;

/// <summary>
/// One WebSocket client's subscription state. Mutated from the socket thread,
/// read from the main thread, so all access goes through the lock.
/// </summary>
internal sealed class StreamSession
{
    private readonly object _lock = new();
    private readonly HashSet<string> _patterns = new(StringComparer.OrdinalIgnoreCase);
    private PathMatcher _matcher = new(Array.Empty<string>());
    private readonly Dictionary<string, float> _lastSent = new(StringComparer.OrdinalIgnoreCase);
    private double _minInterval = 1.0 / 30;
    private double _lastSentAt = double.NegativeInfinity;

    /// <summary>Outgoing messages (JSON text), drained by the socket writer.</summary>
    public Channel<string> Outbox { get; } = Channel.CreateBounded<string>(
        new BoundedChannelOptions(256) { FullMode = BoundedChannelFullMode.DropOldest, SingleReader = true });

    public void Subscribe(IEnumerable<string> patterns, double? maxHz)
    {
        lock (_lock)
        {
            foreach (var p in patterns) _patterns.Add(p);
            _matcher = new PathMatcher(_patterns);
            if (maxHz is > 0) _minInterval = 1.0 / Math.Clamp(maxHz.Value, 1, 120);
        }
    }

    public void Unsubscribe(IEnumerable<string> patterns)
    {
        lock (_lock)
        {
            foreach (var p in patterns) _patterns.Remove(p);
            _matcher = new PathMatcher(_patterns);
            _lastSent.Clear();
        }
    }

    /// <summary>Forget what was sent, so the next tick re-sends every subscribed value.</summary>
    public void ResetBaseline() { lock (_lock) _lastSent.Clear(); }

    /// <summary>Record values the client already received (e.g. in a subscribe reply).</summary>
    public void Seed(Dictionary<string, float> values)
    {
        lock (_lock) foreach (var (path, value) in values) _lastSent[path] = value;
    }

    /// <summary>Vehicle generation last sent to this client (-1 = none yet). Main thread only.</summary>
    public int SentGeneration { get; set; } = -1;

    /// <summary>Main thread: returns changed subscribed values, or null if nothing is due.</summary>
    public Dictionary<string, float>? Diff(Dictionary<string, float> snapshot, double now)
    {
        lock (_lock)
        {
            if (_matcher.IsEmpty || now - _lastSentAt < _minInterval) return null;
            Dictionary<string, float>? changed = null;
            foreach (var (path, value) in snapshot)
            {
                if (!_matcher.Matches(path)) continue;
                if (_lastSent.TryGetValue(path, out var prev) && prev.Equals(value)) continue;
                _lastSent[path] = value;
                (changed ??= new(StringComparer.OrdinalIgnoreCase))[path] = value;
            }
            if (changed != null) _lastSentAt = now;
            return changed;
        }
    }
}

/// <summary>Main-thread pump: samples IO once per frame and fans out diffs to sessions.</summary>
internal static class StreamHub
{
    private static readonly object Lock = new();
    private static readonly List<StreamSession> Sessions = new();
    private static readonly Stopwatch Clock = Stopwatch.StartNew();

    public static void Add(StreamSession s) { lock (Lock) Sessions.Add(s); }
    public static void Remove(StreamSession s) { lock (Lock) Sessions.Remove(s); }

    public static void Tick()
    {
        StreamSession[] sessions;
        lock (Lock)
        {
            if (Sessions.Count == 0) return;
            sessions = Sessions.ToArray();
        }

        // Every session gets the current vehicle on connect and whenever it changes.
        var inTrain = TrainIO.Refresh();
        string? vehicleMsg = null;
        foreach (var s in sessions)
        {
            if (s.SentGeneration == TrainIO.Generation) continue;
            vehicleMsg ??= inTrain
                ? Json.Serialize(new { op = "vehicle", vehicle = TrainIO.Vehicle() })
                : Json.Serialize(new { op = "vehicle", vehicle = (object?)null });
            if (s.SentGeneration != -1) s.ResetBaseline(); // values of the old vehicle are meaningless now
            s.SentGeneration = TrainIO.Generation;
            s.Outbox.Writer.TryWrite(vehicleMsg);
        }
        if (!inTrain) return;

        var snapshot = TrainIO.Snapshot();
        var now = Clock.Elapsed.TotalSeconds;
        var t = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        foreach (var s in sessions)
        {
            var changed = s.Diff(snapshot, now);
            if (changed != null) s.Outbox.Writer.TryWrite(Json.Serialize(new { op = "values", t, values = changed }));
        }
    }
}
