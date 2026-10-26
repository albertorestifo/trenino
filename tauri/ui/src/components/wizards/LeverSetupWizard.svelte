<script lang="ts">
  import { onDestroy } from 'svelte';
  import type { ElementView, NotchRangesValidationView } from '../../bridge/generated';
  import type { CapturedRange, DetectedControlChange, GuidedSessionSnapshot, LeverEndpointSet, NotchDraft, UiBridge } from '../../bridge/client';
  import type { HardwareCatalog } from '../../app/hardware';
  import StepIndicator from './StepIndicator.svelte';
  import WizardModal from './WizardModal.svelte';
  import EndpointBrowser from '../EndpointBrowser.svelte';
  import GuidedSimulatorSession from '../GuidedSimulatorSession.svelte';

  let {
    bridge,
    element,
    hardware,
    initialInputId = null,
    onClose,
    onComplete,
  }: {
    bridge: UiBridge;
    element: ElementView;
    hardware: HardwareCatalog;
    initialInputId?: string | null;
    onClose: () => void;
    onComplete: (message: string) => void;
  } = $props();

  const STEPS = ['Select Input', 'Find in Simulator', 'Define Notches', 'Map Positions', 'Preview'];

  let currentStep = $state(0);
  let error = $state('');
  let pending = $state(false);

  const analogInputs = $derived(hardware.inputs.filter((input) => input.kind === 'analog' && input.calibration !== null));
  let selectedInputId = $state<string | null>(null);
  const selectedInput = $derived(analogInputs.find((input) => input.id === selectedInputId) ?? null);

  const existingConfig = $derived(element.lever_config);
  let endpoints = $state({ min: '', max: '', value: '', notchCount: '', notchIndex: '' });
  let guidedMode = $state<'detection' | 'analysis' | 'calibration' | null>(null);
  let guidedSession = $state<{ requestClose(): Promise<boolean> } | undefined>();
  let dismissing = $state(false);
  let suggestedLeverType = $state<'discrete' | 'continuous' | 'hybrid' | null>(null);
  let endpointEditRevision = 0;
  let endpointSuggestion = $state<{ controlPath: string; confidence: number } | null>(null);

  async function suggestEndpoints(initial: { min: string; max: string; value: string; notchCount: string; notchIndex: string }, revision: number) {
    const result = await bridge.suggestLever(element.name);
    if (!alive || endpointEditRevision !== revision) return;
    const match = result.match;
    if (!match) return;
    endpoints = {
      min: endpoints.min === initial.min ? match.endpoints.min : endpoints.min,
      max: endpoints.max === initial.max ? match.endpoints.max : endpoints.max,
      value: endpoints.value === initial.value ? match.endpoints.value : endpoints.value,
      notchCount: endpoints.notchCount === initial.notchCount ? match.endpoints.notchCount : endpoints.notchCount,
      notchIndex: endpoints.notchIndex === initial.notchIndex ? match.endpoints.notchIndex : endpoints.notchIndex,
    };
    endpointEditRevision += 1;
    endpointSuggestion = { controlPath: match.controlPath, confidence: match.confidence };
  }
  let sweepDraftSignature: string | null = null;
  let alive = true;
  onDestroy(() => { alive = false; });

  async function dismissWizard() {
    if (dismissing) return;
    dismissing = true;
    try {
      if (guidedMode !== null) {
        if (!guidedSession || !(await guidedSession.requestClose())) return;
      }
      onClose();
    } finally {
      dismissing = false;
    }
  }
  const endpointsValid = $derived(endpoints.min.trim() !== '' && endpoints.max.trim() !== '' && endpoints.value.trim() !== '');

  type NotchRow = {
    kind: 'gate' | 'linear';
    description: string;
    value: string;
    minValue: string;
    maxValue: string;
    simMin: string;
    simMax: string;
  };

  let leverConfigId = $state<string | null>(null);
  let notchRows = $state<NotchRow[]>([]);
  let notchCount = $state('4');
  let initializedElementKey: string | undefined;
  $effect(() => {
    const config = existingConfig;
    const key = `${element.id}:${config?.id ?? ''}:${initialInputId ?? ''}`;
    if (initializedElementKey === key) return;
    initializedElementKey = key;
    selectedInputId = initialInputId;
    endpoints = {
      min: config?.min_endpoint ?? '', max: config?.max_endpoint ?? '', value: config?.value_endpoint ?? '',
      notchCount: config?.notch_count_endpoint ?? '', notchIndex: config?.notch_index_endpoint ?? '',
    };
    suggestedLeverType = null;
    sweepDraftSignature = null;
    endpointEditRevision += 1;
    leverConfigId = config?.id ?? null;
    notchRows = (config?.notches ?? []).map((notch) => ({
      kind: notch.kind === 'gate' ? 'gate' : 'linear',
      description: notch.description ?? '', value: notch.value === null ? '' : String(notch.value),
      minValue: notch.min_value === null ? '' : String(notch.min_value),
      maxValue: notch.max_value === null ? '' : String(notch.max_value),
      simMin: notch.sim_input_min === null ? '' : String(notch.sim_input_min),
      simMax: notch.sim_input_max === null ? '' : String(notch.sim_input_max),
    }));
    notchCount = notchRows.length > 0 ? String(notchRows.length) : '4';
    endpointSuggestion = null;
    void suggestEndpoints({ ...endpoints }, endpointEditRevision);
  });
  const notchCountValid = $derived(/^\d+$/.test(notchCount.trim()) && Number.parseInt(notchCount.trim(), 10) > 0);

  let replaceBinding = $state(false);
  let allowReplaceBinding = $state(false);
  let autoDistributed = $state(false);

  let capturedRanges = $state<(CapturedRange | null)[]>([]);
  let previewRanges = $state<{ min: number; max: number }[] | null>(null);
  let mappingIndex = $state(0);
  let capturing = $state(false);
  let sampleCount = $state(0);
  let minSampleCount = $state<number | null>(null);
  let currentMin = $state<number | null>(null);
  let currentMax = $state<number | null>(null);
  let currentValue = $state<number | null>(null);
  let sampleRequest = 0;

  let gaps = $state<NotchRangesValidationView['gaps'] | null>(null);
  let savedWithGaps = $state(false);
  let savedDraftSignature = $state<string | null>(null);
  let savedInverted = $state(false);
  let refreshRequired = $state(false);

  function simulatorDraftSignature(): string {
    return JSON.stringify({ endpoints, notchRows });
  }

  function mappingDraftSignature(): string {
    return JSON.stringify({ selectedInputId, endpoints, notchRows, capturedRanges, autoDistributed, allowReplaceBinding, suggestedLeverType });
  }

  const canFinishWithGaps = $derived(savedWithGaps && savedDraftSignature === mappingDraftSignature());

  function completionMessage(withGaps: boolean): string {
    if (refreshRequired) return `Lever '${element.name}' saved${withGaps ? ' with gaps' : ''}. Refresh train details to see the latest changes.`;
    const status = withGaps ? 'configured with gaps' : 'configured successfully';
    return `Lever '${element.name}' ${status}`;
  }

  function applyNotchCount() {
    if (!notchCountValid) return;
    const count = Number.parseInt(notchCount.trim(), 10);
    notchRows = notchRows.slice(0, count);
    while (notchRows.length < count) {
      notchRows.push({ kind: 'linear', description: '', value: '', minValue: '', maxValue: '', simMin: '', simMax: '' });
    }
  }

  async function useGuidedResult(result: GuidedSessionSnapshot, selected: DetectedControlChange | null) {
    if (pending) return;
    if (guidedMode === 'detection' && selected) {
      pending = true;
      const editRevision = endpointEditRevision;
      const resolved = await bridge.resolveLeverEndpoints(selected.endpoint);
      if (!alive) return;
      pending = false;
      if (guidedMode !== 'detection') return;
      if (endpointEditRevision !== editRevision) {
        error = 'Endpoints changed while detection was resolving. Your edits were kept.';
        guidedMode = null;
        return;
      }
      if (!resolved.ok) { error = resolved.error.message; return; }
      endpoints = {
        min: resolved.value.min_endpoint,
        max: resolved.value.max_endpoint,
        value: resolved.value.value_endpoint,
        notchCount: resolved.value.notch_count_endpoint,
        notchIndex: resolved.value.notch_index_endpoint,
      };
      error = '';
      guidedMode = null;
      return;
    }
    if (guidedMode === 'analysis' && result.analysis) {
      notchRows = result.analysis.suggested_notches.map((notch) => ({
        kind: notch.kind,
        description: notch.description,
        value: notch.value === null ? '' : String(notch.value),
        minValue: notch.min_value === null ? '' : String(notch.min_value),
        maxValue: notch.max_value === null ? '' : String(notch.max_value),
        simMin: String(notch.input_min),
        simMax: String(notch.input_max),
      }));
      notchCount = String(notchRows.length);
      suggestedLeverType = result.analysis.lever_type;
      sweepDraftSignature = null;
      guidedMode = null;
      return;
    }
    if (guidedMode === 'calibration' && result.calibration) {
      notchRows = result.calibration.notches.map((notch) => ({
        kind: notch.kind,
        description: notch.description,
        value: notch.value === null ? '' : String(notch.value),
        minValue: notch.min_value === null ? '' : String(notch.min_value),
        maxValue: notch.max_value === null ? '' : String(notch.max_value),
        simMin: notch.kind === 'gate' ? String(notch.value ?? '') : String(notch.min_value ?? ''),
        simMax: notch.kind === 'gate' ? String(notch.value ?? '') : String(notch.max_value ?? ''),
      }));
      notchCount = String(notchRows.length);
      sweepDraftSignature = simulatorDraftSignature();
      guidedMode = null;
    }
  }

  function calibrationEndpoints(): LeverEndpointSet | null {
    if (!endpoints.min.trim() || !endpoints.max.trim() || !endpoints.value.trim() || !endpoints.notchCount.trim() || !endpoints.notchIndex.trim()) return null;
    return {
      min_endpoint: endpoints.min.trim(), max_endpoint: endpoints.max.trim(), value_endpoint: endpoints.value.trim(),
      notch_count_endpoint: endpoints.notchCount.trim(), notch_index_endpoint: endpoints.notchIndex.trim(),
    };
  }

  function onHardwareSample(event: { input_id: string; value: number }) {
    if (!selectedInput || event.input_id !== selectedInput.id || !selectedInput.calibration) return;
    const inputId = selectedInput.id;
    const request = sampleRequest;
    void bridge.previewInput(inputId, event.value).then((result) => {
      if (request !== sampleRequest || selectedInputId !== inputId || currentStep !== 3) return;
      if (!result.ok) { error = result.error.message; return; }
      const calibrated = result.value.calibrated;
      minSampleCount = result.value.min_notch_samples;
      currentValue = calibrated;
      if (!capturing) return;
      sampleCount += 1;
      currentMin = currentMin === null ? calibrated : Math.min(currentMin, calibrated);
      currentMax = currentMax === null ? calibrated : Math.max(currentMax, calibrated);
    }).catch(() => { if (request === sampleRequest) error = 'Hardware preview is unavailable.'; });
  }

  $effect(() => bridge.onHardwareInput(onHardwareSample));

  function startCapturing() {
    sampleRequest += 1;
    capturing = true;
    sampleCount = 0;
    currentMin = null;
    currentMax = null;
  }

  function stopCapturing() {
    sampleRequest += 1;
    capturing = false;
  }

  function resetSamples() {
    sampleRequest += 1;
    sampleCount = 0;
    currentMin = null;
    currentMax = null;
  }

  async function captureRange() {
    if (currentMin === null || currentMax === null) return;
    if (minSampleCount === null || sampleCount < minSampleCount) return;
    capturedRanges[mappingIndex] = { min: currentMin, max: currentMax, sample_count: sampleCount };
    capturing = false;
    const next = capturedRanges.findIndex((range, index) => index > mappingIndex && range === null);
    if (next !== -1) {
      mappingIndex = next;
      resetSamples();
    } else if (capturedRanges.every((range) => range !== null)) {
      await showMappingPreview();
    } else {
      resetSamples();
    }
  }

  async function showMappingPreview() {
    if (!selectedInputId || capturedRanges.some((range) => range === null)) return;
    pending = true;
    const result = await bridge.previewNotchMapping(selectedInputId,
      notchRows.map((row) => ({ sim_input_min: parseOptionalFloat(row.simMin), sim_input_max: parseOptionalFloat(row.simMax) })),
      capturedRanges as CapturedRange[], false);
    pending = false;
    if (!result.ok) { error = result.error.message; return; }
    enterPreview(result.value.ranges);
  }

  function parseOptionalFloat(value: string): number | null {
    const trimmed = value.trim();
    if (trimmed === '') return null;
    const parsed = Number.parseFloat(trimmed);
    return Number.isFinite(parsed) ? parsed : null;
  }

  function notchDrafts(): NotchDraft[] {
    return notchRows.map((row, index) => ({
      index,
      kind: row.kind,
      value: parseOptionalFloat(row.value),
      min_value: parseOptionalFloat(row.minValue),
      max_value: parseOptionalFloat(row.maxValue),
      input_min: null,
      input_max: null,
      sim_input_min: parseOptionalFloat(row.simMin),
      sim_input_max: parseOptionalFloat(row.simMax),
      description: row.description.trim() === '' ? null : row.description.trim(),
    }));
  }

  async function continueFromNotches() {
    if (!selectedInputId || !selectedInput) {
      error = 'Select a hardware input first.';
      currentStep = 0;
      return;
    }
    error = '';
    pending = true;
    try {
      const bound = await bridge.getBindings();
      if (!bound.ok) {
        error = bound.error.message;
        return;
      }
      if (!allowReplaceBinding && bound.value.value.lever.some((binding) =>
        binding.input_id === selectedInputId && binding.lever_config_id !== leverConfigId)) {
        replaceBinding = true;
        return;
      }
      startMapping();
    } finally {
      pending = false;
    }
  }

  function confirmReplaceBinding() {
    replaceBinding = false;
    allowReplaceBinding = true;
    error = '';
    if (currentStep === 4) void saveMapping();
    else startMapping();
  }

  function startMapping() {
    capturedRanges = notchRows.map(() => null);
    previewRanges = null;
    autoDistributed = false;
    mappingIndex = 0;
    gaps = null;
    savedWithGaps = false;
    savedDraftSignature = null;
    savedInverted = false;
    refreshRequired = false;
    capturing = false;
    currentValue = null;
    resetSamples();
    currentStep = 3;
  }

  function enterPreview(ranges: { min: number; max: number }[] | null) {
    previewRanges = ranges;
    currentStep = 4;
  }

  async function autoDistribute() {
    if (!selectedInputId) return;
    error = '';
    pending = true;
    try {
      const distributed = await bridge.previewNotchMapping(selectedInputId,
        notchRows.map((row) => ({ sim_input_min: parseOptionalFloat(row.simMin), sim_input_max: parseOptionalFloat(row.simMax) })),
        [], true);
      if (!distributed.ok) {
        error = distributed.error.message;
        return;
      }
      autoDistributed = true;
      enterPreview(distributed.value.ranges);
    } finally {
      pending = false;
    }
  }

  async function saveMapping() {
    if (!selectedInputId) return;
    if (canFinishWithGaps) {
      onComplete(completionMessage(true));
      return;
    }
    error = '';
    pending = true;
    try {
      const submittedSignature = mappingDraftSignature();
      const saved = await bridge.commitLeverMapping({
        element_id: element.id,
        lever_config_id: leverConfigId,
        input_id: selectedInputId,
        replace_binding: allowReplaceBinding,
        endpoints: {
          min_endpoint: endpoints.min.trim(), max_endpoint: endpoints.max.trim(), value_endpoint: endpoints.value.trim(),
          notch_count_endpoint: endpoints.notchCount.trim() || null,
          notch_index_endpoint: endpoints.notchIndex.trim() || null,
          lever_type: suggestedLeverType,
        },
        notches: notchDrafts(),
        captured_ranges: autoDistributed ? [] : capturedRanges as CapturedRange[],
        auto_distribute: autoDistributed,
        calibration_completed: sweepDraftSignature !== null && sweepDraftSignature === simulatorDraftSignature(),
      });
      if (!saved.ok) {
        if (saved.error.code === 'conflict' && !allowReplaceBinding) replaceBinding = true;
        else error = saved.error.message;
        return;
      }
      leverConfigId = saved.value.lever_config_id;
      savedInverted = saved.value.inverted;
      refreshRequired = saved.value.refresh_required;
      if (!saved.value.validation.value.valid) {
        gaps = saved.value.validation.value.gaps;
        savedWithGaps = true;
        savedDraftSignature = submittedSignature;
        return;
      }
      gaps = null;
      savedWithGaps = false;
      savedDraftSignature = null;
      if (mappingDraftSignature() !== submittedSignature) {
        error = 'Mapping saved, but the draft changed while saving. Review and save the current draft.';
        return;
      }
      onComplete(completionMessage(false));
    } finally {
      pending = false;
    }
  }

  function nextStep() {
    error = '';
    if (currentStep === 0) {
      if (!selectedInputId) {
        error = 'Select a calibrated hardware input.';
        return;
      }
      currentStep = 1;
    } else if (currentStep === 1) {
      if (!endpointsValid) {
        error = 'Enter the min, max and value endpoints.';
        return;
      }
      currentStep = 2;
    } else if (currentStep === 2) {
      if (!notchCountValid || notchRows.length === 0) {
        error = 'Enter how many notches the lever has.';
        return;
      }
      void continueFromNotches();
    }
  }

  function previousStep() {
    error = '';
    if (currentStep === 3) capturing = false;
    if (currentStep > 0) currentStep -= 1;
  }

  function formatRange(range: { min: number; max: number }): string {
    return `${range.min.toFixed(3)} – ${range.max.toFixed(3)}`;
  }
</script>

<WizardModal title="Configure Lever" subtitle={element.name} closing={dismissing} onClose={() => void dismissWizard()}>
  <div class="px-4 pb-4 border-b border-base-300">
    <StepIndicator steps={STEPS} current={currentStep} completed={currentStep} />
  </div>

  {#if error}
    <p role="alert" class="px-4 pt-4 text-sm text-error">{error}</p>
  {/if}

  {#if currentStep === 0}
    <div class="p-6" data-testid="lever-step-input">
      <div class="max-w-lg mx-auto">
        <h3 class="text-lg font-semibold mb-2">Select Hardware Input</h3>
        <p class="text-sm text-muted mb-4">
          Choose a calibrated lever to control this element. Only calibrated analog inputs are shown.
        </p>

        {#if analogInputs.length === 0}
          <div class="alert alert-warning">
            <div>
              <p class="font-medium">No calibrated levers available</p>
              <p class="text-sm">Calibrate a lever in Device Settings first.</p>
            </div>
          </div>
        {:else}
          <div class="space-y-2">
            {#each analogInputs as input (input.id)}
              <label
                class={[
                  'flex items-center gap-3 p-4 rounded-lg border cursor-pointer transition-colors',
                  selectedInputId === input.id ? 'border-primary bg-primary/10' : 'border-base-300 hover:border-base-content/30',
                ]}
              >
                <input
                  type="radio"
                  name="lever-input"
                  value={input.id}
                  checked={selectedInputId === input.id}
                  onchange={() => (selectedInputId = input.id)}
                  class="radio radio-primary"
                  data-testid="lever-input-option"
                />
                <div class="flex-1">
                  <div class="font-medium">{input.name || 'Unnamed Input'}</div>
                  <div class="text-sm text-muted">
                    {input.device_name} · Pin {input.pin ?? '—'}
                    {#if input.calibration}<span class="text-success">— Calibrated</span>{/if}
                  </div>
                </div>
              </label>
            {/each}
          </div>
        {/if}
      </div>
    </div>
  {:else if currentStep === 1}
    <div class="p-6" data-testid="lever-step-endpoints">
      <div class="max-w-lg mx-auto">
        <h3 class="text-lg font-semibold mb-2">Find in Simulator</h3>
        <p class="text-sm text-muted mb-4">
          Copy the lever's control endpoints from the simulator API (for example
          <span class="font-mono">CurrentDrivableActor/MasterController.InputValue</span>).
        </p>
        {#if guidedMode === 'detection'}
          <GuidedSimulatorSession bind:this={guidedSession} {bridge} mode="detection" onUse={useGuidedResult} onClose={() => (guidedMode = null)} />
        {:else}
          <button type="button" class="btn btn-outline btn-sm mb-4" onclick={() => (guidedMode = 'detection')} data-testid="detect-simulator-lever">Auto-detect lever control</button>
        {/if}
        {#if endpointSuggestion}
          <div class="alert alert-info mb-4" role="status" data-testid="lever-endpoint-suggestion">
            <p class="text-sm flex-1">Suggested “{endpointSuggestion.controlPath}” · {Math.round(endpointSuggestion.confidence * 100)}% confidence — review before saving</p>
            <button type="button" class="btn btn-ghost btn-xs" aria-label="Dismiss suggestion" onclick={() => (endpointSuggestion = null)}>Dismiss</button>
          </div>
        {/if}
        <div class="space-y-3">
          <label class="block">
            <span class="text-sm font-medium">Min endpoint</span>
            <input
              type="text"
              class="input input-bordered w-full font-mono text-sm mt-1"
              bind:value={endpoints.min}
              oninput={() => (endpointEditRevision += 1)}
              data-testid="lever-min-endpoint"
              placeholder="…/MasterController.MinValue"
            />
          </label>
          <EndpointBrowser {bridge} label="Browse minimum" onSelect={(path) => { endpoints.min = path; endpointEditRevision += 1; }} />
          <label class="block">
            <span class="text-sm font-medium">Max endpoint</span>
            <input
              type="text"
              class="input input-bordered w-full font-mono text-sm mt-1"
              bind:value={endpoints.max}
              oninput={() => (endpointEditRevision += 1)}
              data-testid="lever-max-endpoint"
              placeholder="…/MasterController.MaxValue"
            />
          </label>
          <EndpointBrowser {bridge} label="Browse maximum" onSelect={(path) => { endpoints.max = path; endpointEditRevision += 1; }} />
          <label class="block">
            <span class="text-sm font-medium">Value endpoint</span>
            <input
              type="text"
              class="input input-bordered w-full font-mono text-sm mt-1"
              bind:value={endpoints.value}
              oninput={() => (endpointEditRevision += 1)}
              data-testid="lever-value-endpoint"
              placeholder="…/MasterController.InputValue"
            />
          </label>
          <EndpointBrowser {bridge} label="Browse value" onSelect={(path) => { endpoints.value = path; endpointEditRevision += 1; }} />
          <label class="block">
            <span class="text-sm font-medium">Notch count endpoint <span class="font-normal text-muted">(optional)</span></span>
            <input
              type="text"
              class="input input-bordered w-full font-mono text-sm mt-1"
              bind:value={endpoints.notchCount}
              oninput={() => (endpointEditRevision += 1)}
              data-testid="lever-notch-count-endpoint"
            />
          </label>
          <EndpointBrowser {bridge} label="Browse notch count" onSelect={(path) => { endpoints.notchCount = path; endpointEditRevision += 1; }} />
          <label class="block">
            <span class="text-sm font-medium">Notch index endpoint <span class="font-normal text-muted">(optional)</span></span>
            <input
              type="text"
              class="input input-bordered w-full font-mono text-sm mt-1"
              bind:value={endpoints.notchIndex}
              oninput={() => (endpointEditRevision += 1)}
              data-testid="lever-notch-index-endpoint"
            />
          </label>
          <EndpointBrowser {bridge} label="Browse notch index" onSelect={(path) => { endpoints.notchIndex = path; endpointEditRevision += 1; }} />
        </div>
      </div>
    </div>
  {:else if currentStep === 2}
    <div class="p-6" data-testid="lever-step-notches">
      <div class="max-w-2xl mx-auto">
        <h3 class="text-lg font-semibold mb-2">Define Notches</h3>
        <p class="text-sm text-muted mb-4">
          Describe the lever's notches. Gate notches snap into place; linear notches cover a range.
          Simulator ranges are optional and power automatic inversion detection.
        </p>
        <div class="mb-4 flex flex-wrap gap-2">
          <button type="button" class="btn btn-outline btn-sm" disabled={guidedMode !== null} onclick={() => (guidedMode = 'analysis')} data-testid="analyze-lever">Analyze lever</button>
          <button type="button" class="btn btn-outline btn-sm" disabled={guidedMode !== null} onclick={() => (guidedMode = 'calibration')} data-testid="sweep-lever">Run automatic notch sweep</button>
        </div>
        {#if guidedMode === 'analysis' || guidedMode === 'calibration'}
          <GuidedSimulatorSession bind:this={guidedSession} {bridge} mode={guidedMode} controlPath={endpoints.value} endpoints={calibrationEndpoints()} onUse={useGuidedResult} onClose={() => (guidedMode = null)} />
        {/if}
        <label class="block max-w-xs mb-4">
          <span class="text-sm font-medium">Notch count</span>
          <input
            type="number"
            min="1"
            class="input input-bordered w-full mt-1"
            bind:value={notchCount}
            onchange={applyNotchCount}
            oninput={applyNotchCount}
            data-testid="lever-notch-count"
          />
        </label>
        <div class="overflow-x-auto">
          <table class="table table-sm bg-base-200/50">
            <thead>
              <tr>
                <th class="w-10">#</th>
                <th>Kind</th>
                <th>Description</th>
                <th>Simulator range</th>
              </tr>
            </thead>
            <tbody>
              {#each notchRows as row, index (index)}
                <tr>
                  <td class="text-muted">{index + 1}</td>
                  <td>
                    <select
                      class="select select-bordered select-sm"
                      bind:value={row.kind}
                      data-testid="lever-notch-kind"
                      aria-label="Notch {index + 1} kind"
                    >
                      <option value="gate">Gate</option>
                      <option value="linear">Linear</option>
                    </select>
                  </td>
                  <td>
                    <input
                      type="text"
                      class="input input-bordered input-sm w-full"
                      bind:value={row.description}
                      placeholder="e.g., Neutral"
                      aria-label="Notch {index + 1} description"
                    />
                  </td>
                  <td>
                    <div class="flex items-center gap-1">
                      <input
                        type="number"
                        step="0.01"
                        class="input input-bordered input-sm w-20 font-mono"
                        bind:value={row.simMin}
                        aria-label="Notch {index + 1} simulator minimum"
                      />
                      <span class="text-muted">–</span>
                      <input
                        type="number"
                        step="0.01"
                        class="input input-bordered input-sm w-20 font-mono"
                        bind:value={row.simMax}
                        aria-label="Notch {index + 1} simulator maximum"
                      />
                    </div>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  {:else if currentStep === 3}
    <div class="p-6" data-testid="lever-step-mapping">
      <div class="max-w-2xl mx-auto">
        <h3 class="text-lg font-semibold mb-2">Map Hardware Positions</h3>
        <p class="text-sm text-muted mb-4">
          Move your physical lever to capture the range for each notch.
          Lever direction will be automatically detected when you save.
        </p>

        {#if notchRows.length > 0}
          <div class="bg-base-200 rounded-lg p-4">
            <div class="flex items-center justify-between mb-4">
              <div>
                <h4 class="font-semibold">Notch {mappingIndex + 1} of {notchRows.length}</h4>
                <p class="text-sm text-muted">
                  {notchRows[mappingIndex]?.description || `Notch ${mappingIndex}`}
                  — {notchRows[mappingIndex]?.kind === 'gate'
                    ? 'Wiggle the lever within this position'
                    : 'Sweep through the full range'}
                </p>
              </div>
              <span class="badge {notchRows[mappingIndex]?.kind === 'gate' ? 'badge-warning' : 'badge-info'}">
                {notchRows[mappingIndex]?.kind === 'gate' ? 'Gate' : 'Linear'}
              </span>
            </div>

            {#if capturing}
              <div class="space-y-4">
                <div class="grid grid-cols-3 gap-4 text-center">
                  <div>
                    <div class="text-2xl font-mono font-bold text-info" data-testid="capture-min">{currentMin ?? '—'}</div>
                    <div class="text-xs text-muted">Min</div>
                  </div>
                  <div>
                    <div class="text-3xl font-mono font-bold text-primary" data-testid="capture-current">{currentValue ?? '—'}</div>
                    <div class="text-xs text-muted">Current</div>
                  </div>
                  <div>
                    <div class="text-2xl font-mono font-bold text-info" data-testid="capture-max">{currentMax ?? '—'}</div>
                    <div class="text-xs text-muted">Max</div>
                  </div>
                </div>
                <p class="text-center text-sm text-muted" data-testid="capture-sample-count">
                  {sampleCount} samples collected (at least {minSampleCount ?? '…'} needed)
                </p>
                <div class="flex justify-center gap-2">
                  <button type="button" class="btn btn-ghost btn-sm" onclick={resetSamples}>Reset</button>
                  <button type="button" class="btn btn-ghost btn-sm" onclick={stopCapturing}>Stop</button>
                  <button
                    type="button"
                    class="btn btn-primary btn-sm"
                    disabled={minSampleCount === null || sampleCount < minSampleCount}
                    onclick={captureRange}
                    data-testid="capture-range"
                  >
                    Capture
                  </button>
                </div>
              </div>
            {:else}
              <div class="text-center">
                <div class="text-3xl font-mono font-bold text-primary mb-4" data-testid="capture-current">{currentValue ?? '—'}</div>
                <button type="button" class="btn btn-primary" onclick={startCapturing} data-testid="start-capturing">
                  Start Capturing
                </button>
              </div>
            {/if}
          </div>
        {/if}

        <div class="mt-6 text-center">
          <button
            type="button"
            class="btn btn-outline btn-sm"
            onclick={() => void autoDistribute()}
            disabled={pending}
            data-testid="auto-distribute"
          >
            Auto-distribute ranges instead
          </button>
        </div>
      </div>
    </div>
  {:else if currentStep === 4}
    <div class="p-6" data-testid="lever-step-preview">
      <div class="max-w-2xl mx-auto">
        <h3 class="text-lg font-semibold mb-2">Preview</h3>
        <p class="text-sm text-muted mb-4">
          Review the captured ranges before saving them to the lever.
        </p>
        <div class="overflow-x-auto">
          <table class="table table-sm bg-base-200/50" data-testid="notch-preview-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Kind</th>
                <th>Description</th>
                <th>Hardware range</th>
              </tr>
            </thead>
            <tbody>
              {#each notchRows as row, index (index)}
                {@const range = previewRanges?.[index]}
                <tr>
                  <td class="text-muted">{index + 1}</td>
                  <td>
                    <span class="badge badge-sm {row.kind === 'gate' ? 'badge-warning' : 'badge-info'}">
                      {row.kind === 'gate' ? 'Gate' : 'Linear'}
                    </span>
                  </td>
                  <td>{row.description || `Notch ${index}`}</td>
                  <td class="font-mono text-sm">
                    {#if range}
                      {formatRange(range)}
                    {:else}
                      <span class="text-base-content/40">Not captured</span>
                    {/if}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

        {#if savedWithGaps && !canFinishWithGaps}
          <p class="mt-4 text-sm text-warning" role="status">The saved mapping has gaps. This draft has unsaved changes; save it before finishing.</p>
        {/if}
        {#if canFinishWithGaps}
          <div class="alert alert-warning mt-4" role="alert">
            <div>
              <p class="font-medium">Saved with gaps</p>
              <p class="text-sm">
                The saved ranges do not cover the full lever travel:
                {#each gaps ?? [] as gap, index (index)}
                  {gap.from.toFixed(3)} – {gap.to.toFixed(3)}{index < (gaps ?? []).length - 1 ? ', ' : ''}
                {/each}
              </p>
              {#if refreshRequired}<p class="text-sm">Saved; refresh train details to see the latest changes.</p>{/if}
            </div>
          </div>
        {/if}
        {#if savedInverted}
          <p class="text-sm text-muted mt-4">Lever direction detected as inverted and saved.</p>
        {/if}
      </div>
    </div>
  {/if}

  {#if replaceBinding}
    <div class="fixed inset-0 z-[60] grid place-items-center bg-black/50 px-4" role="dialog" aria-modal="true" aria-labelledby="lever-replace-title">
      <div class="w-full max-w-md rounded-xl bg-base-100 p-6 shadow-xl">
        <h2 id="lever-replace-title" class="text-lg font-semibold">Replace existing binding?</h2>
        <p class="mt-3 text-sm">
          This input already controls another lever. Replacing it will move the input to this lever.
        </p>
        <div class="mt-6 flex justify-end gap-2">
          <button type="button" class="btn btn-ghost" onclick={() => (replaceBinding = false)} data-testid="cancel-replace-binding">Cancel</button>
          <button type="button" class="btn btn-primary" disabled={pending} onclick={() => void confirmReplaceBinding()} data-testid="confirm-replace-binding">
            Replace binding
          </button>
        </div>
      </div>
    </div>
  {/if}

  <div class="p-4 border-t border-base-300 flex justify-between">
    <button type="button" class="btn btn-ghost" onclick={previousStep} disabled={currentStep === 0 || pending || guidedMode !== null} data-testid="wizard-back">
      Back
    </button>
    {#if currentStep === 4}
      <button
        type="button"
        class="btn btn-primary"
        disabled={pending}
        onclick={() => void saveMapping()}
        data-testid="save-mapping"
      >
        {canFinishWithGaps ? 'Finish anyway' : 'Save Mapping'}
      </button>
    {:else}
      <button
        type="button"
        class="btn btn-primary"
        disabled={pending || guidedMode !== null || (currentStep === 0 && analogInputs.length === 0)}
        onclick={nextStep}
        data-testid="wizard-continue"
      >
        {pending ? 'Working…' : 'Continue'}
      </button>
    {/if}
  </div>
</WizardModal>
