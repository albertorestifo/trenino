using System;
using System.Collections.Concurrent;
using System.Threading.Tasks;

namespace TreninoBridge;

/// <summary>
/// Runs work on Unity's main thread. IL2CPP objects must only be touched there,
/// so the HTTP thread enqueues closures and awaits their result.
/// </summary>
internal static class MainThread
{
    private static readonly ConcurrentQueue<Action> Queue = new();

    public static Task<T> Run<T>(Func<T> work)
    {
        var tcs = new TaskCompletionSource<T>(TaskCreationOptions.RunContinuationsAsynchronously);
        Queue.Enqueue(() =>
        {
            try { tcs.SetResult(work()); }
            catch (Exception e) { tcs.SetException(e); }
        });
        return tcs.Task;
    }

    /// <summary>Called from MelonMod.OnUpdate.</summary>
    public static void Drain(int max = 256)
    {
        for (var i = 0; i < max && Queue.TryDequeue(out var action); i++)
            action();
    }
}
