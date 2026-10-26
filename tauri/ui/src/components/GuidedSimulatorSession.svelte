<script lang="ts">
  import { onDestroy } from 'svelte';
  import type { DetectedControlChange, GuidedSessionSnapshot, LeverEndpointSet, UiBridge } from '../bridge/client';

  let { bridge, mode, controlPath = '', endpoints = null, onUse, onClose }: {
    bridge: UiBridge;
    mode: 'detection' | 'analysis' | 'calibration';
    controlPath?: string;
    endpoints?: LeverEndpointSet | null;
    onUse: (result: GuidedSessionSnapshot, selected: DetectedControlChange | null) => void;
    onClose: () => void;
  } = $props();

  let snapshot = $state<GuidedSessionSnapshot | null>(null);
  let sessionId = $state<string | null>(null);
  let starting = $state(false);
  let cancelling = $state(false);
  let error = $state('');
  let selectedIndex = $state<number | null>(null);
  let timer: ReturnType<typeof setTimeout> | null = null;
  let startTask: Promise<void> | null = null;
  let closeTask: Promise<boolean> | null = null;
  let alive = true;
  let epoch = 0;
  let closeRequested = false;
  let cancelAcknowledged = false;

  function terminal(state: GuidedSessionSnapshot['state'] | undefined): boolean {
    return state === 'detected' || state === 'timed_out' || state === 'complete' || state === 'failed' || state === 'cancelled';
  }

  function clearPoll() {
    if (timer) clearTimeout(timer);
    timer = null;
  }

  function cancelBackend(id: string) {
    if (mode === 'detection') return bridge.cancelControlDetection(id);
    if (mode === 'analysis') return bridge.cancelLeverAnalysis(id);
    return bridge.cancelLeverCalibration(id);
  }

  function statusBackend(id: string) {
    if (mode === 'detection') return bridge.controlDetectionStatus(id);
    if (mode === 'analysis') return bridge.leverAnalysisStatus(id);
    return bridge.leverCalibrationStatus(id);
  }

  async function poll(id: string, current: number) {
    const result = await statusBackend(id);
    if (!alive || current !== epoch || id !== sessionId || closeRequested) return;
    if (result.ok) {
      snapshot = result.value;
      if (error.startsWith('Status unavailable:')) error = '';
      if (result.value.state === 'detected' && !result.value.ambiguous && result.value.changes.length === 1) selectedIndex = 0;
    } else {
      error = `Status unavailable: ${result.error.message}. Retrying…`;
    }
    if (!result.ok || !terminal(result.value.state)) timer = setTimeout(() => void poll(id, current), 500);
  }

  async function start() {
    if (starting || cancelling) return;
    clearPoll();
    const current = ++epoch;
    starting = true;
    error = '';
    if (sessionId && snapshot?.cleanup_pending) {
      cancelling = true;
      const oldId = sessionId;
      const cleared = await cancelBackend(oldId);
      cancelling = false;
      if (!alive || current !== epoch) { starting = false; return; }
      if (!cleared.ok) {
        starting = false;
        closeRequested = false;
        error = cleared.error.message;
        return;
      }
      sessionId = null;
      cancelAcknowledged = true;
      if (closeRequested) {
        starting = false;
        onClose();
        return;
      }
    }
    snapshot = null;
    sessionId = null;
    selectedIndex = null;
    cancelAcknowledged = false;
    const result = mode === 'detection' ? await bridge.startControlDetection()
      : mode === 'analysis' ? await bridge.startLeverAnalysis(controlPath)
      : await bridge.startLeverCalibration(controlPath, endpoints);
    starting = false;
    if (!alive || current !== epoch) {
      if (result.ok) await cancelBackend(result.value.session_id);
      return;
    }
    if (closeRequested) {
      if (result.ok) {
        sessionId = result.value.session_id;
        const cancelled = await cancelBackend(result.value.session_id);
        if (!alive) return;
        cancelling = false;
        if (!cancelled.ok) {
          closeRequested = false;
          error = cancelled.error.message;
          void poll(result.value.session_id, current);
          return;
        }
        sessionId = null;
        cancelAcknowledged = true;
      }
      onClose();
      return;
    }
    if (!result.ok) { error = result.error.message; return; }
    sessionId = result.value.session_id;
    void poll(result.value.session_id, current);
  }

  function beginStart() {
    startTask = start().finally(() => { startTask = null; });
  }

  export function requestClose(): Promise<boolean> {
    if (closeTask && (cancelling || closeRequested)) return closeTask;
    closeTask = close().finally(() => { closeTask = null; });
    return closeTask;
  }

  async function close(): Promise<boolean> {
    closeRequested = true;
    clearPoll();
    if (starting) {
      cancelling = true;
      await startTask;
      return closeRequested && sessionId === null;
    }
    if (sessionId && (!terminal(snapshot?.state) || snapshot?.cleanup_pending)) {
      cancelling = true;
      const result = await cancelBackend(sessionId);
      if (!alive) return false;
      cancelling = false;
      if (!result.ok) {
        closeRequested = false;
        error = result.error.message;
        void poll(sessionId, epoch);
        return false;
      }
      sessionId = null;
      cancelAcknowledged = true;
    }
    onClose();
    return true;
  }

  onDestroy(() => {
    alive = false;
    epoch += 1;
    clearPoll();
    if (sessionId && !cancelAcknowledged && (!terminal(snapshot?.state) || snapshot?.cleanup_pending)) void cancelBackend(sessionId);
  });
</script>

<section class="mt-3 rounded-lg border border-base-300 bg-base-100 p-4 text-sm" aria-label="Guided simulator session" data-testid="guided-session">
  <div class="flex items-center justify-between gap-3">
    <h4 class="font-medium">{mode === 'detection' ? 'Detect simulator control' : mode === 'analysis' ? 'Analyze lever' : 'Automatic notch sweep'}</h4>
    <button type="button" class="btn btn-ghost btn-xs" disabled={cancelling} onclick={() => void requestClose()} data-testid="close-guided-session">{cancelling ? 'Cancelling…' : 'Close'}</button>
  </div>

  {#if error}<p role="alert" class="mt-3 text-error">{error}</p>{/if}

  {#if starting || cancelling}
    <p role="status" class="mt-3">{cancelling ? 'Cancelling session…' : 'Starting session…'}</p>
  {:else if sessionId && !snapshot}
    <p role="status" class="mt-3">Waiting for simulator status…</p>
  {:else if !snapshot || snapshot.state === 'timed_out' || snapshot.state === 'failed' || snapshot.state === 'cancelled'}
    {#if snapshot?.state === 'timed_out'}<p class="mt-3">No control changed before the detection timeout.</p>{/if}
    {#if snapshot?.state === 'failed'}
      <p class="mt-3 text-error">{snapshot.message ?? 'The simulator session failed.'}</p>
      {#if snapshot.cleanup_pending}<p class="mt-1 text-muted">Cleanup is pending. Try again will release this session before starting another.</p>{/if}
    {/if}
    <button type="button" class="btn btn-primary btn-sm mt-3" onclick={beginStart} data-testid="start-guided-session">
      {snapshot ? 'Try again' : mode === 'detection' ? 'Start detection' : mode === 'analysis' ? 'Start analysis' : 'Start sweep'}
    </button>
  {:else if snapshot.state === 'listening'}
    <p role="status" class="mt-3">Move the control in the simulator. {snapshot.remaining_ms === null ? '' : `${Math.ceil(snapshot.remaining_ms / 1000)}s remaining.`}</p>
  {:else if snapshot.state === 'running' || snapshot.state === 'cancelling'}
    <p role="status" class="mt-3">
      {#if mode === 'analysis' && snapshot.analysis_progress}
        Analyzing position {snapshot.analysis_progress.sampled} of {snapshot.analysis_progress.total}…
      {:else if mode === 'calibration' && snapshot.progress}
        Sweeping notches: {Math.round(snapshot.progress.progress * 100)}%…
      {:else}Reading simulator values…{/if}
    </p>
  {:else if snapshot.state === 'detected'}
    <p class="mt-3">{snapshot.ambiguous ? 'Several controls changed. Choose the one you moved.' : 'Control detected.'}</p>
    <div class="mt-2 space-y-1">
      {#each snapshot.changes as change, index (change.endpoint)}
        <label class="flex items-center gap-2 rounded border border-base-300 p-2">
          <input type="radio" name="detected-control" checked={selectedIndex === index} onchange={() => (selectedIndex = index)} />
          <span class="min-w-0"><span class="font-medium">{change.control_name}</span><span class="block break-all font-mono text-xs text-muted">{change.endpoint}</span></span>
        </label>
      {/each}
    </div>
    <button type="button" class="btn btn-primary btn-sm mt-3" disabled={selectedIndex === null} onclick={() => onUse(snapshot!, selectedIndex === null ? null : snapshot!.changes[selectedIndex] ?? null)} data-testid="use-guided-result">Use control</button>
  {:else if snapshot.state === 'complete'}
    {#if mode === 'analysis' && snapshot.analysis}
      <p class="mt-3">Rust detected a {snapshot.analysis.lever_type} lever with {snapshot.analysis.suggested_notches.length} suggested notches.</p>
      {#if snapshot.analysis.suggested_notches.length === 0}<p class="mt-1 text-muted">Define notches manually to continue.</p>{/if}
    {:else if mode === 'calibration' && snapshot.calibration}
      <p class="mt-3">Rust found {snapshot.calibration.notches.length} notches. Review them before saving.</p>
      {#if snapshot.calibration.notches.length === 0}<p class="mt-1 text-muted">Define notches manually to continue.</p>{/if}
    {/if}
    <button type="button" class="btn btn-primary btn-sm mt-3" disabled={mode === 'analysis' ? !snapshot.analysis?.suggested_notches.length : !snapshot.calibration?.notches.length} onclick={() => onUse(snapshot!, null)} data-testid="use-guided-result">Use suggested notches</button>
  {/if}
</section>
