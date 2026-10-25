<script lang="ts">
  import { onDestroy } from 'svelte';
  import type { Result, UiBridge } from '../bridge/client';
  import type { CalibrationView, InputView, UiFailure } from '../bridge/generated';

  let {
    input,
    port,
    generation,
    api,
    close,
  }: {
    input: InputView;
    port: string;
    generation: number;
    api: UiBridge;
    close: () => void;
  } = $props();

  const STEPS = ['Set minimum', 'Sweep range', 'Set maximum', 'Analyzing'];
  const STEP_TITLES = [
    'Move the input to its minimum position and hold it steady.',
    'Slowly move the input from minimum to maximum position.',
    'Move the input to its maximum position and hold it steady.',
    'Analyzing calibration data…',
  ];
  const ADVANCE_LABELS = ['Start', 'Next: Sweep', 'Next: Set Max', 'Finish'];

  let starting = $state(true);
  let sessionId = $state<string | null>(null);
  let step = $state(0);
  let result = $state<CalibrationView | null>(null);
  let failed = $state(false);
  let error = $state('');
  let advancing = $state(false);
  let cancelling = $state(false);
  let cancelFailed = $state(false);
  let abandoned = false;

  onDestroy(() => {
    abandoned = true;
    if (sessionId && !result && !cancelling) void api.cancelCalibration(sessionId);
  });

  function failure(value: UiFailure | undefined, fallback: string) {
    failed = true;
    error = value?.message ?? fallback;
  }

  $effect(() => {
    void (async () => {
      const ceiling = await api.calibrationCeiling(input.id);
      if (abandoned) return;
      if (!ceiling.ok) {
        failure(ceiling.error, 'Calibration hardware range is unavailable.');
        starting = false;
        return;
      }
      const outcome: Result<string> = await api.startCalibration({ port, generation, pin: input.pin ?? 0, input_id: input.id, max_hardware_value: ceiling.value });
      if (abandoned) {
        if (outcome.ok) void api.cancelCalibration(outcome.value);
        return;
      }
      starting = false;
      if (outcome.ok) sessionId = outcome.value;
      else failure(outcome.error, 'Calibration could not start.');
    })().catch(() => {
      if (!abandoned) {
        starting = false;
        failure(undefined, 'Calibration could not start.');
      }
    });
  });

  async function advance() {
    if (!sessionId || advancing) return;
    advancing = true;
    error = '';
    const outcome = await api.advanceCalibration?.(sessionId);
    advancing = false;
    if (!outcome) {
      failure(undefined, 'Calibration is not available in this build.');
      return;
    }
    if (!outcome.ok) {
      error = outcome.error.message;
      return;
    }
    if (outcome.value !== null) {
      result = outcome.value;
      step = STEPS.length - 1;
    } else if (step < STEPS.length - 1) {
      step += 1;
    }
  }

  async function cancel() {
    if (cancelling) return;
    if (!sessionId) { close(); return; }
    cancelling = true;
    cancelFailed = false;
    error = '';
    try {
      const outcome = await api.cancelCalibration(sessionId);
      if (abandoned) return;
      if (!outcome.ok) {
        error = outcome.error.message;
        cancelFailed = true;
        return;
      }
      sessionId = null;
      close();
    } catch {
      if (!abandoned) {
        error = 'Calibration could not be cancelled. Try again.';
        cancelFailed = true;
      }
    } finally {
      if (!abandoned) cancelling = false;
    }
  }
</script>

<div class="fixed inset-0 z-50 flex items-center justify-center" role="dialog" aria-modal="true" aria-labelledby="calibration-title">
  <div class="absolute inset-0 bg-black/50" onclick={cancel} aria-hidden="true"></div>
  <div class="relative max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-xl bg-base-100 p-6 shadow-xl mx-4">
    <div class="mb-6 flex items-center justify-between">
      <div>
        <h2 id="calibration-title" class="text-xl font-semibold">Calibrate Input</h2>
        <p class="text-sm text-base-content/70">Pin {input.pin ?? '—'}{input.name ? ` · ${input.name}` : ''}</p>
      </div>
      <button type="button" class="btn btn-ghost btn-sm btn-circle" aria-label="Close" disabled={cancelling} onclick={cancel}>✕</button>
    </div>

    {#if starting}
      <div class="flex flex-col items-center justify-center py-12" role="status">
        <span class="loading loading-spinner loading-lg text-primary"></span>
        <p class="mt-4 text-base-content/70">Starting calibration session…</p>
      </div>
    {:else if result}
      <div class="space-y-4 text-center">
        <h3 class="text-lg font-semibold">Calibration Complete!</h3>
        <p class="text-base-content/70">The input has been calibrated successfully.</p>
        <dl class="rounded-lg bg-base-200 p-4 text-left text-sm">
          <div class="flex justify-between"><dt>Minimum</dt><dd class="font-mono">{result.min_value ?? '—'}</dd></div>
          <div class="flex justify-between"><dt>Maximum</dt><dd class="font-mono">{result.max_value ?? '—'}</dd></div>
          <div class="flex justify-between"><dt>Rollover</dt><dd>{result.has_rollover ? 'Detected' : 'No'}</dd></div>
          <div class="flex justify-between"><dt>Inverted</dt><dd>{result.is_inverted ? 'Yes' : 'No'}</dd></div>
        </dl>
        <button type="button" class="btn btn-primary" onclick={close}>Done</button>
      </div>
    {:else if failed}
      <div class="space-y-4 text-center">
        <h3 class="text-lg font-semibold text-error">Calibration Failed</h3>
        <p role="alert" class="text-sm text-base-content/70">{error}</p>
        <button type="button" class="btn" onclick={close}>Close</button>
      </div>
    {:else}
      <ol class="mb-8 flex items-center justify-center gap-2" aria-label="Calibration steps">
        {#each STEPS as label, index}
          <li class="flex items-center">
            <div
              class="flex h-8 w-8 items-center justify-center rounded-full text-sm font-medium transition-colors {index <= step ? 'bg-primary text-primary-content' : 'bg-base-300'} {index === step ? 'ring-4 ring-primary/30' : ''}"
              aria-current={index === step ? 'step' : undefined}
            >
              {#if index < step}<span aria-hidden="true">✓</span>{:else}{index + 1}{/if}
            </div>
            {#if index < STEPS.length - 1}<div class="mx-1 h-0.5 w-8 {index < step ? 'bg-primary' : 'bg-base-300'}"></div>{/if}
          </li>
        {/each}
      </ol>

      <div class="space-y-6">
        <div class="text-center">
          <h3 class="mb-2 text-lg font-semibold">{STEPS[step]}</h3>
          <p class="text-base-content/70">{STEP_TITLES[step]}</p>
          <p class="mt-2 text-xs text-base-content/50">Step {step + 1} of {STEPS.length}</p>
        </div>
        {#if error}<p role="alert" class="text-sm text-error">{error}</p>{/if}
        <div class="flex justify-between gap-4 border-t border-base-300 pt-4">
          <button type="button" class="btn btn-ghost" disabled={cancelling} onclick={cancel}>{cancelling ? 'Cancelling…' : cancelFailed ? 'Retry cancel' : 'Cancel'}</button>
          <button type="button" class="btn btn-primary" disabled={advancing || cancelling} onclick={() => void advance()}>
            {advancing ? 'Working…' : ADVANCE_LABELS[step]}
          </button>
        </div>
      </div>
    {/if}
  </div>
</div>
