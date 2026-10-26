<script lang="ts">
  import type { OutputBindingView } from '../../bridge/generated';
  import type { OutputBindingDraft, OutputConditionPreview, UiBridge } from '../../bridge/client';
  import type { HardwareCatalog } from '../../app/hardware';
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
    existingBinding?: OutputBindingView | null;
    onClose: () => void;
    onComplete: (message: string) => void;
  } = $props();

  type Operator = OutputBindingDraft['operator'];

  const STEPS = ['Endpoint', 'Output', 'Type', 'Condition'];
  const OPERATORS: { value: Operator; label: string; group: string }[] = [
    { value: 'eq_true', label: '= true', group: 'Boolean' },
    { value: 'eq_false', label: '= false', group: 'Boolean' },
    { value: 'gt', label: '> (greater than)', group: 'Numeric' },
    { value: 'gte', label: '≥ (greater or equal)', group: 'Numeric' },
    { value: 'lt', label: '< (less than)', group: 'Numeric' },
    { value: 'lte', label: '≤ (less or equal)', group: 'Numeric' },
    { value: 'between', label: 'between', group: 'Numeric' },
  ];

  let currentStep = $state(0);
  let error = $state('');
  let pending = $state(false);

  let endpoint = $state('');
  let selectedOutputId = $state<string | null>(null);
  let outputType = $state<'led'>('led');
  let operator = $state<Operator>('gt');
  let valueA = $state('0');
  let valueB = $state('');
  let name = $state('');
  let initializedBindingId: string | null | undefined;
  $effect(() => {
    const binding = existingBinding;
    const id = binding?.id ?? null;
    if (initializedBindingId === id) return;
    initializedBindingId = id;
    currentStep = binding ? 3 : 0;
    endpoint = binding?.endpoint ?? '';
    selectedOutputId = binding?.output_id ?? null;
    operator = (binding?.operator as Operator | undefined) ?? 'gt';
    valueA = binding?.value_a == null ? '0' : String(binding.value_a);
    valueB = binding?.value_b == null ? '' : String(binding.value_b);
    name = binding?.name ?? '';
  });

  const selectedOutput = $derived(hardware.outputs.find((output) => output.id === selectedOutputId) ?? null);
  const booleanOperator = $derived(operator === 'eq_true' || operator === 'eq_false');

  function parseNumber(value: string | number): number | null {
    if (String(value).trim() === '') return null;
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }

  let condition = $state<OutputConditionPreview | null>(null);
  let conditionPending = $state(false);
  let conditionError = $state('');
  $effect(() => {
    const currentOperator = operator;
    const a = booleanOperator ? null : parseNumber(valueA);
    const b = currentOperator === 'between' ? parseNumber(valueB) : null;
    let stale = false;
    condition = null;
    conditionError = '';
    conditionPending = true;
    void bridge.previewOutputCondition(currentOperator, a, b).then((result) => {
      if (stale) return;
      conditionPending = false;
      if (result.ok) condition = result.value;
      else conditionError = result.error.message;
    }).catch(() => { if (!stale) { conditionPending = false; conditionError = 'Condition preview is unavailable.'; } });
    return () => { stale = true; };
  });
  const conditionValid = $derived(condition?.valid === true && !conditionPending);

  const canSave = $derived(
    name.trim() !== '' && endpoint.trim() !== '' && selectedOutputId !== null && conditionValid,
  );

  const conditionPreview = $derived(condition?.explanation ?? (conditionPending ? 'Checking condition…' : conditionError || condition?.error || '—'));

  async function save() {
    if (!canSave) {
      error = 'Enter a name and endpoint, pick an output, and complete the condition.';
      return;
    }
    error = '';
    pending = true;
    try {
      const checked = await bridge.previewOutputCondition(operator, booleanOperator ? null : parseNumber(valueA), operator === 'between' ? parseNumber(valueB) : null);
      if (!checked.ok || !checked.value.valid) { error = checked.ok ? checked.value.error ?? 'Check the condition.' : checked.error.message; return; }
      const draft: OutputBindingDraft = {
        name: name.trim(),
        output_type: 'led',
        output_id: selectedOutputId!,
        endpoint: endpoint.trim(),
        operator,
        value_a: booleanOperator ? null : parseNumber(valueA),
        value_b: operator === 'between' ? parseNumber(valueB) : null,
        enabled: true,
      };
      const saved = existingBinding
        ? await bridge.updateOutputBinding(existingBinding.id, draft)
        : await bridge.createOutputBinding(trainId, draft);
      if (!saved.ok) {
        error = saved.error.message;
        return;
      }
      onComplete(existingBinding ? 'Output binding saved' : 'Output binding created');
    } finally {
      pending = false;
    }
  }

  function back() {
    error = '';
    if (currentStep > 0) currentStep -= 1;
  }

  function next() {
    error = '';
    if (currentStep === 0 && endpoint.trim() === '') {
      error = 'Enter the endpoint this output should watch.';
      return;
    }
    if (currentStep === 1 && selectedOutputId === null) {
      error = 'Select an output.';
      return;
    }
    currentStep += 1;
  }
</script>

<WizardModal title={existingBinding ? 'Edit Output Binding' : 'Add Output Binding'} subtitle="Configure an output to respond to API values" onClose={onClose}>
  <div class="px-4 pb-4 border-b border-base-300">
    <StepIndicator steps={STEPS} current={currentStep} completed={currentStep} />
  </div>

  {#if error}
    <p role="alert" class="px-4 pt-4 text-sm text-error">{error}</p>
  {/if}

  {#if currentStep === 0}
    <div class="p-6" data-testid="output-step-endpoint">
      <div class="max-w-lg mx-auto">
        <h3 class="text-lg font-semibold mb-2">Endpoint</h3>
        <p class="text-sm text-muted mb-4">
          Copy the endpoint this output should watch from the simulator API (for example
          <span class="font-mono">CurrentDrivableActor/Speedometer.Speed</span>).
        </p>
        <label class="block">
          <span class="text-sm font-medium">Endpoint</span>
          <input
            type="text"
            class="input input-bordered w-full font-mono text-sm mt-1"
            bind:value={endpoint}
            data-testid="output-endpoint"
            placeholder="…/Speedometer.Speed"
          />
        </label>
        <EndpointBrowser {bridge} onSelect={(path) => (endpoint = path)} />
      </div>
    </div>
  {:else if currentStep === 1}
    <div class="p-6" data-testid="output-step-output">
      <div class="text-center mb-6">
        <h3 class="text-xl font-semibold mb-2">Select Output</h3>
        <p class="text-muted">Choose which hardware output to control</p>
      </div>

      {#if hardware.outputs.length === 0}
        <div class="alert alert-warning">
          <span>No outputs configured. Add outputs to a device configuration first.</span>
        </div>
      {:else}
        <div class="space-y-2">
          {#each hardware.outputs as output (output.id)}
            <button
              type="button"
              class="w-full p-4 rounded-lg border-2 text-left transition-all {selectedOutputId === output.id
                ? 'border-primary bg-primary/10'
                : 'border-base-300 hover:border-primary/50 hover:bg-base-200/50'}"
              onclick={() => {
                selectedOutputId = output.id;
                error = '';
                currentStep = 2;
              }}
              data-testid="output-option"
            >
              <p class="font-medium">{output.name || `Output ${output.pin}`}</p>
              <p class="text-xs text-muted">{output.device_name} - Pin {output.pin}</p>
            </button>
          {/each}
        </div>
      {/if}
    </div>
  {:else if currentStep === 2}
    <div class="p-6" data-testid="output-step-type">
      <div class="text-center mb-6">
        <h3 class="text-xl font-semibold mb-2">Select Output Type</h3>
        <p class="text-muted">Choose how the output should behave</p>
      </div>
      <button
        type="button"
        class="w-full p-6 rounded-xl border-2 text-left transition-all {outputType === 'led'
          ? 'border-primary bg-primary/10'
          : 'border-base-300 hover:border-primary/50'}"
        onclick={() => {
          outputType = 'led';
          error = '';
          currentStep = 3;
        }}
        data-testid="output-type-led"
      >
        <h4 class="font-semibold text-lg">LED (On/Off)</h4>
        <p class="text-muted mt-1">
          Digital output that turns on when condition is met, off otherwise.
          Ideal for indicator lights, warning LEDs, and status displays.
        </p>
      </button>
      <div class="text-center text-sm text-muted mt-4">
        For I2C display outputs, use Display Bindings instead
      </div>
    </div>
  {:else if currentStep === 3}
    <div class="p-6 space-y-6" data-testid="output-step-condition">
      <div>
        <h3 class="font-semibold mb-2">Summary</h3>
        <div class="bg-base-200 rounded-lg p-4 space-y-2 text-sm">
          <div class="flex justify-between gap-3">
            <span class="text-muted">Endpoint:</span>
            <span class="font-mono break-all">{endpoint}</span>
          </div>
          {#if selectedOutput}
            <div class="flex justify-between gap-3">
              <span class="text-muted">Output:</span>
              <span>{selectedOutput.name || `Output ${selectedOutput.pin}`} ({selectedOutput.device_name})</span>
            </div>
          {/if}
        </div>
      </div>

      <form class="space-y-4" onsubmit={(event) => event.preventDefault()}>
        <div>
          <label class="label" for="output-binding-name"><span class="label-text font-medium">Binding Name</span></label>
          <input
            id="output-binding-name"
            type="text"
            class="input input-bordered w-full"
            bind:value={name}
            placeholder="e.g., Speed Warning LED"
            data-testid="output-binding-name"
          />
          <p class="text-xs text-muted mt-1">A descriptive name for this output binding</p>
        </div>

        <div>
          <label class="label" for="output-operator"><span class="label-text font-medium">Condition</span></label>
          <p class="text-sm text-muted mb-3">Output turns ON when the API value meets this condition</p>
          <div class="flex items-center gap-3">
            <span class="text-muted">Value</span>
            <select id="output-operator" class="select select-bordered" bind:value={operator} data-testid="output-operator">
              <optgroup label="Boolean">
                <option value="eq_true">= true</option>
                <option value="eq_false">= false</option>
              </optgroup>
              <optgroup label="Numeric">
                <option value="gt">&gt; (greater than)</option>
                <option value="gte">&ge; (greater or equal)</option>
                <option value="lt">&lt; (less than)</option>
                <option value="lte">&le; (less or equal)</option>
                <option value="between">between</option>
              </optgroup>
            </select>
          </div>

          {#if !booleanOperator}
            <div class="mt-3 {operator !== 'between' ? 'max-w-xs' : ''}">
              {#if operator === 'between'}
                <div class="flex items-center gap-2">
                  <input type="number" step="0.01" class="input input-bordered w-32" bind:value={valueA} placeholder="min" aria-label="Minimum threshold" data-testid="output-value-a" />
                  <span class="text-muted">and</span>
                  <input type="number" step="0.01" class="input input-bordered w-32" bind:value={valueB} placeholder="max" aria-label="Maximum threshold" data-testid="output-value-b" />
                </div>
              {:else}
                <div class="flex items-center gap-2">
                  <input type="number" step="0.01" class="input input-bordered w-32" bind:value={valueA} aria-label="Threshold" data-testid="output-value-a" />
                </div>
              {/if}
            </div>
          {/if}
        </div>

        <div class="bg-info/10 border border-info rounded-lg p-4 mt-4">
          <div class="flex items-start gap-2">
            <div class="text-sm">
              <p class="font-medium text-info">Preview</p>
              <p class="text-muted mt-1" data-testid="output-condition-preview">{conditionPreview}</p>
            </div>
          </div>
        </div>
      </form>
    </div>
  {/if}

  <div class="p-4 border-t border-base-300 flex justify-between">
    <button type="button" class="btn btn-ghost" onclick={back} disabled={currentStep === 0 || pending} data-testid="wizard-back">
      Back
    </button>
    {#if currentStep === 3}
      <button
        type="button"
        class="btn btn-primary"
        disabled={pending || !canSave}
        onclick={() => void save()}
        data-testid="save-output-binding"
      >
        {pending ? 'Saving…' : 'Save'}
      </button>
    {:else}
      <button
        type="button"
        class="btn btn-primary"
        disabled={pending || (currentStep === 0 && endpoint.trim() === '') || (currentStep === 1 && hardware.outputs.length === 0)}
        onclick={next}
        data-testid="wizard-continue"
      >
        Continue
      </button>
    {/if}
  </div>
</WizardModal>
