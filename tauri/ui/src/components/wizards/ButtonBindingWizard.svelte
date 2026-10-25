<script lang="ts">
  import type { ButtonBindingView, ElementView, SequenceView } from '../../bridge/generated';
  import type { ButtonBindingDraft, DetectedControlChange, UiBridge } from '../../bridge/client';
  import type { HardwareCatalog } from '../../app/hardware';
  import StepIndicator from './StepIndicator.svelte';
  import WizardModal from './WizardModal.svelte';
  import EndpointBrowser from '../EndpointBrowser.svelte';
  import GuidedSimulatorSession from '../GuidedSimulatorSession.svelte';

  let {
    bridge,
    element,
    hardware,
    sequences,
    existingBinding = null,
    onClose,
    onComplete,
  }: {
    bridge: UiBridge;
    element: ElementView;
    hardware: HardwareCatalog;
    sequences: SequenceView[];
    existingBinding?: ButtonBindingView | null;
    onClose: () => void;
    onComplete: (message: string) => void;
  } = $props();

  type BindingMode = 'simple' | 'momentary' | 'sequence' | 'keystroke';

  const STEPS = ['Choose Type', 'Find Control', 'Configure'];

  const buttonInputs = $derived(hardware.inputs.filter((input) => input.kind === 'button'));

  let currentStep = $state(0);
  let error = $state('');
  let pending = $state(false);

  let bindingMode = $state<BindingMode>('simple');
  let endpoint = $state('');
  let onValue = $state('1');
  let offValue = $state('0');
  let hardwareType = $state<'momentary' | 'latching'>('momentary');
  let repeatInterval = $state('100');
  let onSequenceId = $state('');
  let offSequenceId = $state('');
  let keystroke = $state('');
  let capturingKeystroke = $state(false);

  let selectedInputId = $state<string | null>(null);
  let detectingButton = $state(false);
  let detectingSimulator = $state(false);
  let guidedSession = $state<{ requestClose(): Promise<boolean> } | undefined>();
  let dismissing = $state(false);
  let replaceBinding = $state(false);
  let initializedBindingId: string | null | undefined;

  async function dismissWizard() {
    if (dismissing) return;
    dismissing = true;
    try {
      if (detectingSimulator) {
        if (!guidedSession || !(await guidedSession.requestClose())) return;
      }
      onClose();
    } finally {
      dismissing = false;
    }
  }
  $effect(() => {
    const binding = existingBinding;
    const id = binding?.id ?? null;
    if (initializedBindingId === id) return;
    initializedBindingId = id;
    currentStep = binding ? 2 : 0;
    bindingMode = (binding?.mode as BindingMode | undefined) ?? 'simple';
    endpoint = binding?.endpoint ?? '';
    onValue = binding ? String(binding.on_value) : '1';
    offValue = binding ? String(binding.off_value) : '0';
    hardwareType = binding?.hardware_type === 'latching' ? 'latching' : 'momentary';
    repeatInterval = binding ? String(binding.repeat_interval_ms) : '100';
    onSequenceId = binding?.on_sequence_id || '';
    offSequenceId = binding?.off_sequence_id || '';
    keystroke = binding?.keystroke ?? '';
    selectedInputId = binding?.input_id ?? null;
  });

  const selectedInput = $derived(buttonInputs.find((input) => input.id === selectedInputId) ?? null);

  function parseNumber(value: string, fallback: number): number {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }

  function onHardwareSample(event: { input_id: string; value: number }) {
    if (!detectingButton || event.value === 0) return;
    if (!buttonInputs.some((input) => input.id === event.input_id)) return;
    selectedInputId = event.input_id;
    detectingButton = false;
  }

  $effect(() => bridge.onHardwareInput(onHardwareSample));

  function chooseType(mode: BindingMode) {
    bindingMode = mode;
    error = '';
    if (mode === 'simple' || mode === 'momentary') {
      currentStep = 1;
    } else {
      currentStep = 2;
    }
  }

  function useDetectedSimulator(change: DetectedControlChange | null) {
    if (change) endpoint = change.endpoint;
    detectingSimulator = false;
  }

  function onKeydown(event: KeyboardEvent) {
    if (capturingKeystroke) {
      event.preventDefault();
      if (event.key === 'Escape') {
        capturingKeystroke = false;
        return;
      }
      const parts: string[] = [];
      if (event.ctrlKey) parts.push('Ctrl');
      if (event.altKey) parts.push('Alt');
      if (event.shiftKey) parts.push('Shift');
      if (event.metaKey) parts.push('Meta');
      const key = event.key.length === 1 ? event.key.toUpperCase() : event.key;
      parts.push(key);
      keystroke = parts.join('+');
      capturingKeystroke = false;
    }
  }

  const mappingComplete = $derived.by(() => {
    const hasInput = selectedInputId !== null;
    if (bindingMode === 'sequence') return hasInput && (onSequenceId !== '' || offSequenceId !== '');
    if (bindingMode === 'keystroke') return hasInput && keystroke.trim() !== '';
    return hasInput && endpoint.trim() !== '';
  });

  function bindingDraft(): ButtonBindingDraft {
    const sequenceMode = bindingMode === 'sequence' || bindingMode === 'keystroke';
    return {
      endpoint: sequenceMode ? null : endpoint.trim(),
      on_value: parseNumber(onValue, 1),
      off_value: parseNumber(offValue, 0),
      enabled: true,
      mode: bindingMode,
      hardware_type: hardwareType,
      repeat_interval_ms: Math.trunc(parseNumber(repeatInterval, 100)),
      keystroke: bindingMode === 'keystroke' ? keystroke.trim() : null,
      on_sequence_id: bindingMode === 'sequence' && onSequenceId !== '' ? onSequenceId : null,
      off_sequence_id: bindingMode === 'sequence' && offSequenceId !== '' ? offSequenceId : null,
    };
  }

  async function save(replace: boolean) {
    if (!selectedInputId) {
      error = 'Select a hardware input.';
      return;
    }
    if (!mappingComplete) {
      error = 'Complete the binding configuration before saving.';
      return;
    }
    error = '';
    pending = true;
    try {
      const saved = await bridge.putButtonBinding(element.id, selectedInputId, bindingDraft(), replace);
      if (!saved.ok) {
        if (saved.error.code === 'conflict' && !replace) {
          replaceBinding = true;
          return;
        }
        error = saved.error.message;
        return;
      }
      onComplete('Configuration saved');
    } finally {
      pending = false;
    }
  }

  async function confirmReplaceBinding() {
    replaceBinding = false;
    await save(true);
  }

  function back() {
    error = '';
    if (currentStep === 2 && (bindingMode === 'sequence' || bindingMode === 'keystroke')) {
      currentStep = 0;
    } else if (currentStep > 0) {
      currentStep -= 1;
    }
  }

  function continueFromEndpoint() {
    if (!endpoint.trim() || detectingSimulator) return;
    error = '';
    currentStep = 2;
  }
</script>

<svelte:window onkeydown={onKeydown} />

<WizardModal title="Configure Button" subtitle={element.name} closing={dismissing} onClose={() => void dismissWizard()}>
  <div class="px-4 pb-4 border-b border-base-300">
    <StepIndicator steps={STEPS} current={currentStep} completed={currentStep} />
  </div>

  {#if error}
    <p role="alert" class="px-4 pt-4 text-sm text-error">{error}</p>
  {/if}

  {#if currentStep === 0}
    <div class="p-6" data-testid="button-step-type">
      <div class="max-w-xl mx-auto">
        <h3 class="text-lg font-semibold mb-6 text-center">What should this button do?</h3>
        <div class="space-y-3">
          <button
            type="button"
            class="w-full p-4 rounded-lg border border-base-300 hover:border-primary hover:bg-primary/5 transition-all text-left"
            onclick={() => chooseType('simple')}
            data-testid="choose-simulator-binding"
          >
            <h4 class="font-medium">Simulator Control</h4>
            <p class="text-sm text-base-content/60">Control a function via the simulator API</p>
          </button>
          <button
            type="button"
            class="w-full p-4 rounded-lg border border-base-300 hover:border-accent hover:bg-accent/5 transition-all text-left"
            onclick={() => chooseType('sequence')}
            data-testid="choose-sequence-binding"
          >
            <h4 class="font-medium">Trigger Sequence</h4>
            <p class="text-sm text-base-content/60">Execute a sequence of commands</p>
          </button>
          <button
            type="button"
            class="w-full p-4 rounded-lg border border-base-300 hover:border-secondary hover:bg-secondary/5 transition-all text-left"
            onclick={() => chooseType('keystroke')}
            data-testid="choose-keystroke-binding"
          >
            <h4 class="font-medium">Keyboard Key</h4>
            <p class="text-sm text-base-content/60">Simulate a keyboard press</p>
          </button>
        </div>
      </div>
    </div>
  {:else if currentStep === 1}
    <div class="p-6" data-testid="button-step-endpoint">
      <div class="max-w-lg mx-auto">
        <h3 class="text-lg font-semibold mb-2">Find in Simulator</h3>
        <p class="text-sm text-base-content/60 mb-4">
          Copy the control endpoint from the simulator API (for example
          <span class="font-mono">CurrentDrivableActor/Horn.Active</span>).
        </p>
        <label class="block">
          <span class="text-sm font-medium">Endpoint</span>
          <input
            type="text"
            class="input input-bordered w-full font-mono text-sm mt-1"
            bind:value={endpoint}
            data-testid="button-endpoint"
            placeholder="…/Horn.Active"
          />
        </label>
        <EndpointBrowser {bridge} onSelect={(path) => (endpoint = path)} />
        {#if detectingSimulator}
          <GuidedSimulatorSession bind:this={guidedSession} {bridge} mode="detection" onUse={(_snapshot, change) => useDetectedSimulator(change)} onClose={() => (detectingSimulator = false)} />
        {:else}
          <button type="button" class="btn btn-outline btn-sm mt-2" onclick={() => (detectingSimulator = true)} data-testid="detect-simulator-button">Auto-detect control</button>
        {/if}
      </div>
    </div>
  {:else if currentStep === 2}
    <div class="p-6 space-y-6" data-testid="button-step-configure">
      {#if bindingMode !== 'sequence' && bindingMode !== 'keystroke'}
        <div>
          <h3 class="font-semibold mb-2">Selected Endpoint</h3>
          <div class="bg-base-200 rounded-lg p-3 font-mono text-sm break-all">{endpoint || '—'}</div>
        </div>
      {/if}

      <div>
        <h3 class="font-semibold mb-2">Hardware Input</h3>

        {#if buttonInputs.length === 0}
          <div class="bg-base-200 rounded-lg p-4">
            <p class="text-sm text-base-content/60 italic">
              No button inputs configured. Add button inputs in device settings first.
            </p>
          </div>
        {:else if detectingButton}
          <div class="bg-primary/10 border border-primary rounded-lg p-4">
            <div class="flex items-center gap-3">
              <span class="loading loading-dots loading-md text-primary"></span>
              <div>
                <p class="font-medium text-primary">Waiting for button press...</p>
                <p class="text-xs text-base-content/60">Press a button on your hardware device</p>
              </div>
            </div>
            <button type="button" class="btn btn-ghost btn-xs mt-2" onclick={() => (detectingButton = false)} data-testid="cancel-button-detection">
              Cancel
            </button>
          </div>
        {:else if !selectedInput}
          <div class="bg-base-200 rounded-lg p-4">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm text-base-content/70">No button selected</p>
                <p class="text-xs text-base-content/50">Press "Detect" and then press a button on your device</p>
              </div>
              <button type="button" class="btn btn-primary btn-sm" onclick={() => (detectingButton = true)} data-testid="start-button-detection">
                Detect
              </button>
            </div>
          </div>
        {:else}
          <div class="bg-success/10 border border-success rounded-lg p-4">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div>
                  <p class="font-medium">{selectedInput.name || `Button ${selectedInput.pin}`}</p>
                  <p class="text-xs text-base-content/60">{selectedInput.device_name} - Pin {selectedInput.pin ?? '—'}</p>
                </div>
              </div>
              <div class="flex gap-2">
                <button type="button" class="btn btn-ghost btn-sm" onclick={() => (detectingButton = true)} data-testid="change-button-detection">
                  Change
                </button>
              </div>
            </div>
          </div>
        {/if}

        {#if buttonInputs.length > 0}
          <label class="block mt-3">
            <span class="text-sm font-medium">Or pick manually</span>
            <select
              class="select select-bordered w-full mt-1"
              value={selectedInputId ?? ''}
              onchange={(event) => (selectedInputId = (event.currentTarget as HTMLSelectElement).value || null)}
              data-testid="button-input-select"
            >
              <option value="" disabled selected={selectedInputId === null}>Select a button input</option>
              {#each buttonInputs as input (input.id)}
                <option value={input.id}>{input.device_name} · {input.name || `Pin ${input.pin}`}</option>
              {/each}
            </select>
          </label>
        {/if}
      </div>

      <form class="space-y-4" onsubmit={(event) => event.preventDefault()}>
        {#if bindingMode === 'sequence'}
          <div>
            <label class="label" for="button-hardware-type"><span class="label-text font-medium">Hardware Type</span></label>
            <select id="button-hardware-type" class="select select-bordered w-full" bind:value={hardwareType} data-testid="button-hardware-type">
              <option value="momentary">Momentary (spring-loaded)</option>
              <option value="latching">Latching (toggle switch)</option>
            </select>
            <p class="text-xs text-base-content/50 mt-1">
              {hardwareType === 'momentary'
                ? 'Button returns when released (like a keyboard key or doorbell)'
                : 'Toggle switch that stays in position (like a light switch)'}
            </p>
          </div>

          {#if sequences.length === 0}
            <div class="alert alert-warning">
              <div>
                <span>No sequences defined.</span>
                <span class="ml-1">Create one in the Sequences section below first.</span>
              </div>
            </div>
          {:else}
            <div class="bg-base-200/50 rounded-lg p-4 space-y-4">
              <div>
                <label class="label" for="button-on-sequence"><span class="label-text font-medium">On Press</span></label>
                <select id="button-on-sequence" class="select select-bordered w-full" bind:value={onSequenceId} data-testid="button-on-sequence">
                  <option value="">None</option>
                  {#each sequences as sequence (sequence.id)}
                    <option value={sequence.id}>{sequence.name} ({sequence.commands.length} commands)</option>
                  {/each}
                </select>
                <p class="text-xs text-base-content/50 mt-1">Sequence to execute when button is pressed</p>
              </div>
              {#if hardwareType === 'latching'}
                <div>
                  <label class="label" for="button-off-sequence"><span class="label-text font-medium">On Release</span></label>
                  <select id="button-off-sequence" class="select select-bordered w-full" bind:value={offSequenceId} data-testid="button-off-sequence">
                    <option value="">None</option>
                    {#each sequences as sequence (sequence.id)}
                      <option value={sequence.id}>{sequence.name} ({sequence.commands.length} commands)</option>
                    {/each}
                  </select>
                  <p class="text-xs text-base-content/50 mt-1">Sequence to execute when toggle is turned off</p>
                </div>
              {/if}
              {#if onSequenceId === '' && offSequenceId === ''}
                <p class="text-xs text-warning">Select at least one sequence</p>
              {/if}
            </div>
          {/if}
        {:else}
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="label" for="button-mode"><span class="label-text font-medium">Button Mode</span></label>
              <select id="button-mode" class="select select-bordered w-full" bind:value={bindingMode} data-testid="button-mode">
                <option value="simple">Simple (send once)</option>
                <option value="momentary">Momentary (repeat while held)</option>
                <option value="sequence">Sequence (execute commands)</option>
                <option value="keystroke">Keystroke (keyboard key)</option>
              </select>
              <p class="text-xs text-base-content/50 mt-1">
                {#if bindingMode === 'simple'}
                  Sends ON when pressed, OFF when released. Use for: lights, doors, switches
                {:else if bindingMode === 'momentary'}
                  Repeats ON value while held. Use for: horn, bell, announcements
                {:else if bindingMode === 'keystroke'}
                  Simulates a keyboard key. Use for: controls that respond better to keyboard input
                {:else}
                  Execute a sequence of commands on press
                {/if}
              </p>
            </div>
            <div>
              <label class="label" for="button-hardware-type"><span class="label-text font-medium">Hardware Type</span></label>
              <select id="button-hardware-type" class="select select-bordered w-full" bind:value={hardwareType} data-testid="button-hardware-type">
                <option value="momentary">Momentary (spring-loaded)</option>
                <option value="latching">Latching (toggle switch)</option>
              </select>
              <p class="text-xs text-base-content/50 mt-1">
                {hardwareType === 'momentary'
                  ? 'Button returns when released (like a keyboard key or doorbell)'
                  : 'Toggle switch that stays in position (like a light switch)'}
              </p>
            </div>
          </div>

          {#if bindingMode === 'keystroke'}
            <div class="bg-base-200/50 rounded-lg p-4">
              <p class="label"><span class="label-text font-medium">Keystroke</span></p>
              {#if capturingKeystroke}
                <div
                  class="bg-primary/10 border-2 border-primary rounded-lg p-6 text-center cursor-pointer focus:ring-2 focus:ring-primary"
                  data-testid="keystroke-capture"
                >
                  <div class="flex flex-col items-center gap-2">
                    <p class="font-medium text-primary">Press any key combination...</p>
                    <p class="text-xs text-base-content/60">e.g., W, Ctrl+S, Shift+F1</p>
                  </div>
                  <button type="button" class="btn btn-ghost btn-xs mt-3" onclick={() => (capturingKeystroke = false)}>
                    Cancel
                  </button>
                </div>
              {:else if keystroke === ''}
                <div class="bg-base-200 rounded-lg p-4">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="text-sm text-base-content/70">No keystroke configured</p>
                      <p class="text-xs text-base-content/50">Click "Capture" and press the key combination</p>
                    </div>
                    <button type="button" class="btn btn-primary btn-sm" onclick={() => (capturingKeystroke = true)} data-testid="start-keystroke-capture">
                      Capture
                    </button>
                  </div>
                </div>
              {:else}
                <div class="bg-success/10 border border-success rounded-lg p-4">
                  <div class="flex items-center justify-between">
                    <div>
                      <p class="font-medium font-mono text-lg">{keystroke}</p>
                      <p class="text-xs text-base-content/60">Key will be held while button is pressed</p>
                    </div>
                    <div class="flex gap-2">
                      <button type="button" class="btn btn-ghost btn-sm" onclick={() => (capturingKeystroke = true)}>Change</button>
                      <button type="button" class="btn btn-ghost btn-sm text-error" onclick={() => (keystroke = '')}>Clear</button>
                    </div>
                  </div>
                </div>
              {/if}
            </div>
          {:else if bindingMode === 'simple' || bindingMode === 'momentary'}
            <div>
              <h3 class="font-semibold mb-3">ON/OFF Values</h3>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="label" for="button-on-value"><span class="label-text">ON Value</span></label>
                  <input id="button-on-value" type="number" step="0.1" class="input input-bordered w-full" bind:value={onValue} data-testid="button-on-value" />
                </div>
                <div>
                  <label class="label" for="button-off-value"><span class="label-text">OFF Value</span></label>
                  <input id="button-off-value" type="number" step="0.1" class="input input-bordered w-full" bind:value={offValue} data-testid="button-off-value" />
                </div>
              </div>
              {#if bindingMode === 'momentary'}
                <div class="mt-3">
                  <label class="label" for="button-repeat-interval"><span class="label-text">Repeat interval (ms)</span></label>
                  <input id="button-repeat-interval" type="number" min="0" step="10" class="input input-bordered w-full" bind:value={repeatInterval} data-testid="button-repeat-interval" />
                </div>
              {/if}
            </div>
          {/if}
        {/if}
      </form>
    </div>
  {/if}

  {#if replaceBinding}
    <div class="fixed inset-0 z-[60] grid place-items-center bg-black/50 px-4" role="dialog" aria-modal="true" aria-labelledby="button-replace-title">
      <div class="w-full max-w-md rounded-xl bg-base-100 p-6 shadow-xl">
        <h2 id="button-replace-title" class="text-lg font-semibold">Replace existing binding?</h2>
        <p class="mt-3 text-sm">
          This input already controls another control. Replacing it will move the input to this button.
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
    <button type="button" class="btn btn-ghost" onclick={back} disabled={currentStep === 0 || pending} data-testid="wizard-back">
      Back
    </button>
    {#if currentStep === 1}
      <button type="button" class="btn btn-primary" disabled={pending || detectingSimulator || endpoint.trim() === ''} onclick={continueFromEndpoint} data-testid="wizard-continue">Continue</button>
    {:else}
      <button
        type="button"
        class="btn btn-primary"
        disabled={pending || !mappingComplete}
        onclick={() => void save(false)}
        data-testid="save-button-binding"
      >
        {pending ? 'Saving…' : 'Save'}
      </button>
    {/if}
  </div>
</WizardModal>
