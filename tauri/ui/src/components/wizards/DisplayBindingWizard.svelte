<script lang="ts">
  import type { DisplayBindingView } from '../../bridge/generated';
  import type { DisplayPreview, UiBridge } from '../../bridge/client';
  import type { HardwareCatalog } from '../../app/hardware';
  import { formatI2cAddress } from '../../app/hardware';
  import { decimalsFormat, formatDecimals } from './format';
  import StepIndicator from './StepIndicator.svelte';
  import WizardModal from './WizardModal.svelte';
  import EndpointBrowser from '../EndpointBrowser.svelte';

  let {
    bridge,
    trainId,
    hardware,
    existingBinding = null,
    onClose,
    onComplete,
  }: {
    bridge: UiBridge;
    trainId: string;
    hardware: HardwareCatalog;
    existingBinding?: DisplayBindingView | null;
    onClose: () => void;
    onComplete: (message: string) => void;
  } = $props();

  const STEPS = ['Display', 'Simulator value', 'Format'];

  let currentStep = $state(0);
  let error = $state('');
  let pending = $state(false);

  let selectedModuleId = $state<string | null>(null);
  let endpoint = $state('');
  let name = $state('');
  let formatMode = $state<'decimals' | 'custom'>('decimals');
  let decimals = $state('0');
  let customFormat = $state('{value:.0f}');

  let initializedBindingId: string | null | undefined;
  $effect(() => {
    const binding = existingBinding;
    const id = binding?.id ?? null;
    if (initializedBindingId === id) return;
    initializedBindingId = id;
    currentStep = binding ? 2 : 0;
    selectedModuleId = binding?.i2c_module_id ?? null;
    endpoint = binding?.endpoint ?? '';
    name = binding?.name ?? '';
    const existing = binding ? formatDecimals(binding.format_string) : null;
    formatMode = binding && existing === null ? 'custom' : 'decimals';
    decimals = existing === null ? '0' : String(existing);
    customFormat = binding?.format_string ?? '{value:.0f}';
  });

  const selectedModule = $derived(hardware.displays.find((module) => module.id === selectedModuleId) ?? null);
  const formatString = $derived(
    formatMode === 'custom' ? customFormat : decimalsFormat(Number.parseInt(decimals, 10) || 0),
  );
  let formatPreview = $state<DisplayPreview | null>(null);
  let previewPending = $state(false);
  let previewFailure = $state('');
  $effect(() => {
    const moduleId = selectedModuleId;
    const format = formatString;
    let stale = false;
    formatPreview = null;
    previewFailure = '';
    if (!moduleId) return;
    previewPending = true;
    void bridge.previewDisplay(moduleId, format, 42.5).then((result) => {
      if (stale) return;
      previewPending = false;
      if (result.ok) formatPreview = result.value;
      else previewFailure = result.error.message;
    }).catch(() => { if (!stale) { previewPending = false; previewFailure = 'Display preview is unavailable.'; } });
    return () => { stale = true; };
  });
  const formatError = $derived(formatPreview?.error ?? previewFailure);
  const preview = $derived(formatPreview?.valid ? formatPreview.rendered : '—');
  const previewOverflow = $derived(formatPreview?.overflow ?? false);
  const missingDot = $derived(formatPreview?.missing_dot ?? false);
  const canSave = $derived(
    endpoint.trim() !== '' &&
      selectedModule !== null &&
      name.trim() !== '' &&
      formatPreview?.valid === true && !previewPending,
  );

  function chooseModule(id: string) {
    selectedModuleId = id;
    error = '';
    currentStep = 1;
  }

  async function save() {
    if (!selectedModuleId) {
      error = 'Choose a display first.';
      currentStep = 0;
      return;
    }
    if (!canSave) {
      error = 'Choose a display and simulator value, enter a name, and check the format below.';
      return;
    }
    error = '';
    pending = true;
    try {
      const draft = {
        i2c_module_id: selectedModuleId,
        name: name.trim(),
        endpoint: endpoint.trim(),
        format_string: formatString,
        enabled: true,
      };
      const saved = existingBinding
        ? await bridge.updateDisplayBinding(existingBinding.id, draft)
        : await bridge.createDisplayBinding(trainId, draft);
      if (!saved.ok) {
        error = saved.error.message;
        return;
      }
      onComplete(existingBinding ? 'Display binding saved' : 'Display binding created');
    } finally {
      pending = false;
    }
  }

  function back() {
    error = '';
    if (currentStep === 2 && !existingBinding) currentStep = 1;
    else if (currentStep === 1) currentStep = 0;
    else if (currentStep === 2 && existingBinding) currentStep = 0;
  }
</script>

<WizardModal title={existingBinding ? 'Edit display binding' : 'Add display binding'} subtitle="Show a simulator value on a hardware display." onClose={onClose}>
  <div class="px-4 pb-4 border-b border-base-300">
    <StepIndicator steps={STEPS} current={currentStep} completed={currentStep} />
  </div>

  {#if error}
    <p role="alert" class="px-4 pt-4 text-sm text-error">{error}</p>
  {/if}

  {#if currentStep === 0}
    <div class="p-4 sm:p-6 space-y-4" data-testid="display-step-module">
      <h3 class="font-semibold">Choose a display</h3>
      {#if hardware.displays.length === 0}
        <p class="text-sm">
          Add a display to a hardware configuration first.
          <a href="#/" class="link">Open hardware configurations</a>
        </p>
      {/if}
      {#each hardware.displays as module (module.id)}
        <button
          type="button"
          class="w-full p-4 rounded-lg border text-left hover:bg-base-200 focus-visible:outline-2 focus-visible:outline-primary {selectedModuleId === module.id ? 'border-primary bg-primary/5' : 'border-base-300'}"
          onclick={() => chooseModule(module.id)}
          data-testid="display-module-option"
        >
          <span class="block font-medium break-words">{module.name || 'Display'}</span>
          <span class="block text-xs text-base-content/60 break-words">
            {module.device_name}
            {#if module.num_digits !== null}· {module.num_digits} digits{/if}
            · <span class="font-mono">{formatI2cAddress(module.i2c_address)}</span>
          </span>
        </button>
      {/each}
    </div>
  {:else if currentStep === 1}
    <div class="p-6" data-testid="display-step-endpoint">
      <div class="max-w-lg mx-auto">
        <h3 class="text-lg font-semibold mb-2">Simulator value</h3>
        <p class="text-sm text-base-content/60 mb-4">
          Copy the value endpoint from the simulator API (for example
          <span class="font-mono">CurrentDrivableActor/Speedometer.Speed</span>).
        </p>
        <label class="block">
          <span class="text-sm font-medium">Endpoint</span>
          <input
            type="text"
            class="input input-bordered w-full font-mono text-sm mt-1"
            bind:value={endpoint}
            data-testid="display-endpoint"
            placeholder="…/Speedometer.Speed"
          />
        </label>
        <EndpointBrowser {bridge} onSelect={(path) => (endpoint = path)} />
      </div>
    </div>
  {:else if currentStep === 2}
    <div class="p-4 sm:p-6 space-y-4" data-testid="display-step-configure">
      <dl class="text-sm space-y-2">
        {#if selectedModule}
          <div>
            <dt class="text-base-content/60">Display</dt>
            <dd class="break-words">{selectedModule.name || 'Display'} ({selectedModule.device_name})</dd>
          </div>
        {/if}
        <div>
          <dt class="text-base-content/60">Simulator value</dt>
          <dd class="font-mono text-xs break-all">{endpoint || '—'}</dd>
        </div>
      </dl>

      <form class="space-y-4" onsubmit={(event) => event.preventDefault()}>
        <label class="block">
          <span class="text-sm font-medium">Name</span>
          <input
            type="text"
            class="input input-bordered w-full mt-1"
            bind:value={name}
            placeholder="e.g. Train speed"
            data-testid="display-binding-name"
          />
        </label>
        <label class="block">
          <span class="text-sm font-medium">Decimal places</span>
          <select
            class="select select-bordered w-full mt-1"
            bind:value={decimals}
            disabled={formatMode === 'custom'}
            data-testid="display-decimals"
          >
            {#each Array.from({ length: 11 }, (_, index) => index) as option (option)}
              <option value={String(option)}>{option}</option>
            {/each}
          </select>
        </label>
        <details class="border-t border-base-300 pt-3" open={formatMode === 'custom'}>
          <summary class="cursor-pointer font-medium text-sm py-2">Advanced formatting</summary>
          <div class="pt-3 space-y-3">
            <label class="block">
              <span class="text-sm font-medium">Formatting</span>
              <select class="select select-bordered w-full mt-1" bind:value={formatMode} data-testid="display-format-mode">
                <option value="decimals">Decimal places</option>
                <option value="custom">Custom format</option>
              </select>
            </label>
            <label class="block">
              <span class="text-sm font-medium">Custom format</span>
              <input
                type="text"
                class="input w-full font-mono mt-1"
                bind:value={customFormat}
                disabled={formatMode !== 'custom'}
                aria-describedby="display-format-hint display-format-error"
                data-testid="display-custom-format"
              />
            </label>
            <p id="display-format-hint" class="text-xs text-base-content/60">
              Use {'{value}'} for the raw value or {'{value:.2f}'} for two decimals (0–10 supported).
            </p>
          </div>
        </details>
        {#if formatError}
          <p id="display-format-error" role="alert" class="text-sm text-error">{formatError}</p>
        {/if}
        <div class="bg-base-200 rounded-lg p-4" aria-live="polite">
          <p class="text-xs text-base-content/60 mb-2">Preview · sample value 42.5</p>
          <output id="display-format-preview" class="font-mono text-2xl break-all" data-testid="display-format-preview">{preview}</output>
          {#if previewOverflow}
            <p class="mt-2 text-sm">
              This sample is longer than your display's {selectedModule?.num_digits} digits. Use fewer decimal places or a shorter format.
            </p>
          {/if}
          {#if missingDot}
            <p class="mt-2 text-sm">
              Your display is configured without a decimal point. Use zero decimal places or update its hardware settings.
            </p>
          {/if}
        </div>
      </form>
    </div>
  {/if}

  <div class="p-4 border-t border-base-300 flex justify-between">
    <button type="button" class="btn btn-ghost" onclick={back} disabled={currentStep === 0 || pending} data-testid="wizard-back">
      Back
    </button>
    {#if currentStep === 2}
      <button
        type="button"
        class="btn btn-primary"
        disabled={pending || !canSave}
        onclick={() => void save()}
        data-testid="save-display-binding"
      >
        {pending ? 'Saving…' : 'Save binding'}
      </button>
    {:else}
      <button
        type="button"
        class="btn btn-primary"
        disabled={pending || (currentStep === 0 && hardware.displays.length === 0) || (currentStep === 1 && endpoint.trim() === '')}
        onclick={() => {
          error = '';
          currentStep += 1;
        }}
        data-testid="wizard-continue"
      >
        Continue
      </button>
    {/if}
  </div>
</WizardModal>
