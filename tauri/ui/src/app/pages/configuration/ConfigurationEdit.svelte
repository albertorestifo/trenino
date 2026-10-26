<script lang="ts">
  import { untrack } from 'svelte';
  import type { UiBridge } from '../../../bridge/client';
  import type { DeviceDetailView, Ht16k33ParamsView, InputView, MatrixView, UiFailure } from '../../../bridge/generated';
  import { formatI2cAddress } from '../../../components/i2c-address';
  import CalibrationWizard from '../../../components/calibration-wizard.svelte';
  import I2cModuleForm from '../../../components/i2c-module-form.svelte';
  import MatrixTestWizard from '../../../components/matrix-test-wizard.svelte';

  let {
    bridge,
    mode,
    routeId = null,
    activePort = null,
    activeGeneration = null,
    inputValues = {},
    created,
    deleted,
  }: {
    bridge: UiBridge;
    mode: 'new' | 'existing';
    routeId?: string | null;
    activePort?: string | null;
    activeGeneration?: number | null;
    inputValues?: Record<number, number>;
    created?: (summaryRouteId: string) => void;
    deleted?: () => void;
  } = $props();

  type FieldErrors = Record<string, string>;

  let detail = $state<DeviceDetailView | null>(null);
  let loadError = $state('');
  let loading = $state(false);

  // Device header form (autosave on change, like the LiveView's phx-change).
  let draftName = $state('New Configuration');
  let draftDescription = $state('');
  let deviceErrors = $state<FieldErrors>({});
  let deviceFlash = $state('');
  let creating = $state(false);

  // Add input modal
  let inputModalOpen = $state(false);
  let inputForm = $state<{ name: string; kind: 'analog' | 'button'; pin: string; sensitivity: string; debounce: string }>({ name: '', kind: 'analog', pin: '', sensitivity: '5', debounce: '20' });
  let inputErrors = $state<FieldErrors>({});

  // Add matrix modal
  let matrixModalOpen = $state(false);
  let rowPinsInput = $state('');
  let colPinsInput = $state('');
  let matrixErrors = $state<FieldErrors>({});

  // Add output modal
  let outputModalOpen = $state(false);
  let outputForm = $state<{ pin: string; name: string }>({ pin: '', name: '' });
  let outputErrors = $state<FieldErrors>({});

  // I2C modal
  let i2cModalOpen = $state(false);
  let i2cEditing = $state<DeviceDetailView['i2c_modules'][number] | null>(null);

  // Delete modal
  let deleteModalOpen = $state(false);
  let deleteError = $state('');

  // Wizards
  let calibratingInput = $state<InputView | null>(null);
  let testingMatrix = $state<MatrixView | null>(null);
  let testedButtons = $state<number[]>([]);
  let notice = $state('');
  let calibratedValues = $state<Record<string, number>>({});
  let calibrationPreviewError = $state('');
  let hardwareTestPending = $state<string | null>(null);
  let displayTestText = $state<Record<string, string>>({});


  $effect(() => {
    if (mode === 'existing' && routeId) void load(routeId);
  });


  // Track tested matrix buttons from live input values (virtual pins >= 128).
  $effect(() => {
    if (!testingMatrix) return;
    const pressed = Object.entries(inputValues)
      .filter(([pin, value]) => Number(pin) >= 128 && value === 1)
      .map(([pin]) => Number(pin));
    if (pressed.length === 0) return;
    const current = untrack(() => testedButtons);
    const next = [...new Set([...current, ...pressed])];
    if (next.length !== current.length) testedButtons = next;
  });

  $effect(() => {
    const inputs = detail?.inputs ?? [];
    const readings = inputValues;
    let stale = false;
    const requests = inputs.filter((input) => input.kind === 'analog' && input.calibration && input.pin !== null && input.pin in readings);
    if (requests.length === 0) { calibratedValues = {}; calibrationPreviewError = ''; return; }
    void Promise.all(requests.map(async (input) => ({ input, result: await bridge.previewInput(input.id, readings[input.pin!]!) })))
      .then((results) => {
        if (stale) return;
        calibratedValues = Object.fromEntries(results.filter((entry) => entry.result.ok).map((entry) => [entry.input.id, entry.result.ok ? entry.result.value.calibrated : 0]));
        calibrationPreviewError = results.find((entry) => !entry.result.ok)?.result.ok === false
          ? 'Calibrated readings are temporarily unavailable.' : '';
      }).catch(() => { if (!stale) calibrationPreviewError = 'Calibrated readings are temporarily unavailable.'; });
    return () => { stale = true; };
  });

  async function load(id: string) {
    loading = true;
    loadError = '';
    const result = await bridge.getHardwareDetailByConfig?.(id);
    loading = false;
    if (!result) {
      loadError = 'Configuration editing is not available in this build.';
      return;
    }
    if (result.ok) {
      detail = result.value.value;
      draftName = result.value.value.name ?? '';
      draftDescription = result.value.value.description ?? '';
    } else {
      loadError = result.error.message;
    }
  }

  function applyDetail(snapshot: { value: DeviceDetailView }) {
    detail = snapshot.value;
  }

  function mutationFailure(error: UiFailure, fallback: string): string {
    return error.message || fallback;
  }

  async function saveDevice() {
    deviceErrors = {};
    deviceFlash = '';
    const name = draftName.trim();
    if (name === '') {
      deviceErrors = { name: 'Name is required' };
      return;
    }
    if (mode === 'new') {
      creating = true;
      const result = await bridge.createConfiguration?.(name, draftDescription.trim() || null);
      creating = false;
      if (!result) {
        deviceErrors = { name: 'Configuration creation is not available in this build.' };
        return;
      }
      if (result.ok) {
        created?.(String(result.value.value.config_id));
      } else {
        deviceErrors = result.error.field_errors;
        if (Object.keys(deviceErrors).length === 0) deviceFlash = mutationFailure(result.error, 'Failed to create configuration');
      }
      return;
    }
    if (!detail) return;
    const result = await bridge.updateConfiguration?.(detail.id, { name, description: draftDescription.trim() || null });
    if (!result) {
      deviceErrors = { name: 'Configuration saving is not available in this build.' };
      return;
    }
    if (result.ok) {
      detail = { ...detail, name, description: draftDescription.trim() || null };
    } else {
      deviceErrors = result.error.field_errors;
      if (Object.keys(deviceErrors).length === 0) deviceFlash = mutationFailure(result.error, 'Failed to save configuration');
    }
  }

  // ---- Inputs -------------------------------------------------------------

  function openInputModal() {
    inputForm = { name: '', kind: 'analog', pin: '', sensitivity: '5', debounce: '20' };
    inputErrors = {};
    inputModalOpen = true;
  }

  function validateInputForm(): { ok: true; pin: number; sensitivity: number | null; debounce: number | null } | { ok: false } {
    const errors: FieldErrors = {};
    const pin = Number(inputForm.pin);
    if (String(inputForm.pin ?? '').trim() === '' || !Number.isInteger(pin) || pin < 0 || pin > 254) errors.pin = 'Pin must be an integer between 0 and 254';
    let sensitivity: number | null = null;
    let debounce: number | null = null;
    if (inputForm.kind === 'analog') {
      sensitivity = Number(inputForm.sensitivity);
      if (!Number.isInteger(sensitivity) || sensitivity < 1 || sensitivity > 10) errors.sensitivity = 'Sensitivity must be between 1 and 10';
    } else {
      debounce = Number(inputForm.debounce);
      if (!Number.isInteger(debounce) || debounce < 0 || debounce > 255) errors.debounce = 'Debounce must be between 0 and 255 ms';
    }
    inputErrors = errors;
    if (Object.keys(errors).length > 0) return { ok: false };
    return { ok: true, pin, sensitivity, debounce };
  }

  async function addInput(event: SubmitEvent) {
    event.preventDefault();
    if (!detail) return;
    const checked = validateInputForm();
    if (!checked.ok) return;
    const result = await bridge.createInput?.({
      device_id: detail.id,
      pin: checked.pin,
      kind: inputForm.kind,
      sensitivity: checked.sensitivity,
      debounce: checked.debounce,
      name: inputForm.name.trim() || null,
    });
    if (!result) return;
    if (result.ok) {
      applyDetail(result.value);
      inputModalOpen = false;
    } else {
      inputErrors = result.error.field_errors;
    }
  }

  async function deleteInput(id: string) {
    if (!detail) return;
    const result = await bridge.deleteInput?.(id);
    if (result?.ok) applyDetail(result.value);
    else notice = 'Failed to delete input';
  }

  async function renameInput(input: InputView, name: string) {
    if (!detail || name === (input.name ?? '')) return;
    const result = await bridge.updateInput?.({
      id: input.id,
      pin: input.pin ?? 0,
      kind: (input.kind as 'analog' | 'button') ?? 'analog',
      sensitivity: input.sensitivity,
      debounce: input.debounce,
      name: name.trim() || null,
    });
    if (result?.ok) applyDetail(result.value);
    else notice = 'Failed to update input name';
  }

  // ---- Matrices -----------------------------------------------------------

  function parsePins(raw: string): number[] {
    return raw
      .split(',')
      .map((part) => part.trim())
      .filter((part) => part !== '')
      .flatMap((part) => (/^\d+$/.test(part) ? [Number.parseInt(part, 10)] : []));
  }

  function validateMatrixPins(): boolean {
    const rowPins = parsePins(rowPinsInput);
    const colPins = parsePins(colPinsInput);
    const errors: FieldErrors = {};
    if (rowPins.length === 0) errors.row_pins = 'At least one row pin is required';
    if (colPins.length === 0) errors.col_pins = 'At least one column pin is required';
    if (rowPins.some((pin) => pin < 0 || pin > 127)) errors.row_pins = 'Pins must be between 0 and 127';
    if (colPins.some((pin) => pin < 0 || pin > 127)) errors.col_pins = 'Pins must be between 0 and 127';
    if (new Set(rowPins).size !== rowPins.length) errors.row_pins = 'Duplicate pins are not allowed';
    if (new Set(colPins).size !== colPins.length) errors.col_pins = 'Duplicate pins are not allowed';
    if (rowPins.some((pin) => colPins.includes(pin))) errors.general = 'Row and column pins cannot overlap';
    matrixErrors = errors;
    return Object.keys(errors).length === 0;
  }

  async function addMatrix(event: SubmitEvent) {
    event.preventDefault();
    if (!detail || !validateMatrixPins()) return;
    const result = await bridge.createMatrix?.({
      device_id: detail.id,
      name: 'Matrix',
      row_pins: parsePins(rowPinsInput),
      col_pins: parsePins(colPinsInput),
    });
    if (!result) return;
    if (result.ok) {
      applyDetail(result.value);
      matrixModalOpen = false;
      rowPinsInput = '';
      colPinsInput = '';
      matrixErrors = {};
    } else {
      matrixErrors = { general: result.error.message };
    }
  }

  async function deleteMatrix(id: string) {
    if (!detail) return;
    const result = await bridge.deleteMatrix?.(id);
    if (result?.ok) applyDetail(result.value);
    else notice = 'Failed to delete matrix';
  }

  // ---- Outputs ------------------------------------------------------------

  async function addOutput(event: SubmitEvent) {
    event.preventDefault();
    if (!detail) return;
    const errors: FieldErrors = {};
    const pin = Number(outputForm.pin);
    if (String(outputForm.pin ?? '').trim() === '' || !Number.isInteger(pin) || pin < 0 || pin > 255) errors.pin = 'Pin must be an integer between 0 and 255';
    outputErrors = errors;
    if (Object.keys(errors).length > 0) return;
    const result = await bridge.createOutput?.({ device_id: detail.id, pin, name: outputForm.name.trim() || null });
    if (!result) return;
    if (result.ok) {
      applyDetail(result.value);
      outputModalOpen = false;
      outputForm = { pin: '', name: '' };
    } else {
      outputErrors = result.error.field_errors;
    }
  }

  async function deleteOutput(id: string) {
    if (!detail) return;
    const result = await bridge.deleteOutput?.(id);
    if (result?.ok) applyDetail(result.value);
    else notice = 'Failed to delete output';
  }

  async function renameOutput(output: DeviceDetailView['outputs'][number], name: string) {
    if (!detail || name === (output.name ?? '')) return;
    const result = await bridge.updateOutput?.({ id: output.id, pin: output.pin, name: name.trim() || null });
    if (result?.ok) applyDetail(result.value);
    else notice = 'Failed to update output name';
  }

  async function setOutput(output: DeviceDetailView['outputs'][number], high: boolean) {
    const targetPort = activePort;
    const targetGeneration = activeGeneration;
    if (targetPort === null || targetGeneration === null) { notice = 'Device connection changed. Reconnect before testing.'; return; }
    hardwareTestPending = output.id;
    notice = '';
    const result = await bridge.setPhysicalOutput(output.id, high, targetPort, targetGeneration);
    hardwareTestPending = null;
    notice = result.ok && result.value ? `Sent ${high ? 'HIGH' : 'LOW'} to output ${output.pin}.` : result.ok ? 'The output command was not accepted.' : result.error.message;
  }

  async function testDisplay(module: DeviceDetailView['i2c_modules'][number]) {
    const targetPort = activePort;
    const targetGeneration = activeGeneration;
    if (targetPort === null || targetGeneration === null) { notice = 'Device connection changed. Reconnect before testing.'; return; }
    hardwareTestPending = module.id;
    notice = '';
    const result = await bridge.testDisplay(module.id, displayTestText[module.id] ?? '', targetPort, targetGeneration);
    hardwareTestPending = null;
    notice = result.ok && result.value ? 'Display test sent.' : result.ok ? 'The display command was not accepted.' : result.error.message;
  }

  // ---- I2C modules --------------------------------------------------------

  async function saveI2cModule(fields: { name: string | null; module_chip: string; i2c_address: number; params: Ht16k33ParamsView }): Promise<UiFailure | null> {
    if (!detail) return { code: 'unavailable', message: 'The configuration is not loaded yet.', field_errors: {}, retryable: true };
    const result = i2cEditing
      ? await bridge.updateI2cModule?.({ id: i2cEditing.id, ...fields })
      : await bridge.createI2cModule?.({ device_id: detail.id, ...fields });
    if (!result) return { code: 'unavailable', message: 'Display saving is not available in this build.', field_errors: {}, retryable: true };
    if (result.ok) {
      applyDetail(result.value);
      i2cModalOpen = false;
      i2cEditing = null;
      return null;
    }
    return result.error;
  }

  async function deleteI2cModule(id: string) {
    if (!detail) return;
    const result = await bridge.deleteI2cModule?.(id);
    if (result?.ok) applyDetail(result.value);
    else notice = 'Failed to delete I2C module';
  }

  // ---- Delete configuration ----------------------------------------------

  async function confirmDelete() {
    if (!detail) return;
    const result = await bridge.deleteConfiguration?.(detail.id);
    if (!result) {
      deleteError = 'Configuration deletion is not available in this build.';
      return;
    }
    if (result.ok) {
      deleted?.();
    } else {
      deleteError = mutationFailure(result.error, 'Failed to delete configuration');
      deleteModalOpen = false;
    }
  }

  // ---- Wizards ------------------------------------------------------------

  function startCalibration(input: InputView) {
    if (!activePort) {
      notice = 'Apply configuration to a device before calibrating';
      return;
    }
    notice = '';
    calibratingInput = input;
  }

  function startMatrixTest(matrix: MatrixView) {
    if (!activePort) {
      notice = 'Apply configuration to a device before testing';
      return;
    }
    notice = '';
    testingMatrix = matrix;
    testedButtons = [];
  }

  const parsedRowPins = $derived(parsePins(rowPinsInput));
  const parsedColPins = $derived(parsePins(colPinsInput));
</script>

<div class="mx-auto max-w-2xl">
  <nav class="mb-4 text-sm text-muted" aria-label="Breadcrumb">
    <a href="#/" class="underline underline-offset-2">Configurations</a>
    <span aria-hidden="true"> / </span>
    <span>{mode === 'new' ? 'New Configuration' : draftName || 'Configuration'}</span>
  </nav>

  {#if loading}
    <p role="status" class="text-sm text-muted">Loading configuration…</p>
  {:else if loadError}
    <p role="alert" class="text-sm text-error">{loadError}</p>
    <a class="btn btn-ghost btn-sm mt-3" href="#/">Back to Configurations</a>
  {:else}
    {#if notice}<p role="status" class="mb-4 rounded-lg bg-warning/10 px-3 py-2 text-sm text-base-content/80">{notice}</p>{/if}

    <header>
      <form id="device-form" onsubmit={(event) => { event.preventDefault(); void saveDevice(); }}>
        <div>
          <label class="label" for="device-name"><span class="label-text">Configuration Name</span></label>
          <input
            id="device-name"
            type="text"
            bind:value={draftName}
            onchange={() => void saveDevice()}
            placeholder="e.g., Arduino Mega Controller"
            class="input input-bordered w-full text-lg font-semibold"
            class:input-error={!!deviceErrors.name}
          />
          {#if deviceErrors.name}<p role="alert" class="mt-1 text-xs text-error">{deviceErrors.name}</p>{/if}
        </div>
        <div class="mt-3">
          <label class="label" for="device-description"><span class="label-text">Description</span></label>
          <textarea
            id="device-description"
            bind:value={draftDescription}
            onchange={() => void saveDevice()}
            rows="2"
            placeholder="Add a description (optional)"
            class="textarea textarea-bordered w-full resize-none"
          ></textarea>
        </div>
        <div class="mt-4 flex items-center gap-3">
          {#if detail}<span class="font-mono text-xs text-muted">ID: {detail.config_id}</span>{/if}
          {#if activePort}<span class="badge badge-success badge-sm gap-1"><span class="h-1.5 w-1.5 animate-pulse rounded-full bg-success-content"></span> Active</span>{/if}
        </div>
      </form>
      {#if deviceFlash}<p role="alert" class="mt-2 text-sm text-error">{deviceFlash}</p>{/if}
    </header>

    {#if detail}
      <div class="mt-6 rounded-xl bg-base-200/50 p-6">
        <div class="mb-4 flex items-center justify-between">
          <h3 class="text-base font-semibold">Inputs</h3>
          <button type="button" class="btn btn-outline btn-sm" onclick={openInputModal}>＋ Add Input</button>
        </div>
        {#if detail.inputs.length === 0}
          <p class="text-sm text-muted">No inputs configured. Add your first input to get started.</p>
        {:else}
          <div class="overflow-x-auto">
            <table class="table table-sm bg-base-100 rounded-lg">
              <thead>
                <tr class="bg-base-200"><th class="text-center">Pin</th><th>Name</th><th>Type</th><th>Value</th><th class="w-32"></th></tr>
              </thead>
              <tbody>
                {#each detail.inputs as input (input.id)}
                  <tr class="hover:bg-base-200/50">
                    <td class="text-center font-mono">{input.pin ?? '—'}</td>
                    <td>
                      <input
                        type="text"
                        value={input.name ?? ''}
                        placeholder="Unnamed"
                        onchange={(event) => void renameInput(input, event.currentTarget.value)}
                        aria-label="Input name for pin {input.pin ?? ''}"
                        class="input input-ghost input-xs w-full max-w-32 placeholder:italic placeholder:text-muted"
                      />
                    </td>
                    <td><span class="badge badge-sm capitalize" class:badge-info={input.kind === 'analog'} class:badge-warning={input.kind === 'button'}>{input.kind}</span></td>
                    <td class="min-w-24">
                      {#if !activePort}
                        <span class="text-sm italic text-muted">N/A</span>
                      {:else if input.pin !== null && input.pin in inputValues}
                        {@const raw = inputValues[input.pin]}
                        {#if input.kind === 'button'}
                          {#if raw === 1}<span class="badge badge-success badge-xs">Pressed</span>{:else}<span class="badge badge-ghost badge-xs">Released</span>{/if}
                        {:else}
                          <span class="font-mono tabular-nums">
                            <span class="text-xs text-base-content/40">{raw}</span>
                            {#if input.calibration}<span class="text-xs text-base-content/40">/</span><span>{calibratedValues[input.id] ?? '—'}</span>{:else}<span class="ml-1 text-xs italic text-muted">(uncalibrated)</span>{/if}
                          </span>
                        {/if}
                      {:else}<span class="text-muted">—</span>{/if}
                    </td>
                    <td class="flex gap-1">
                      {#if activePort && input.kind === 'analog'}
                        <button type="button" class="btn btn-ghost btn-xs text-primary hover:bg-primary/10" onclick={() => startCalibration(input)}>Calibrate</button>
                      {/if}
                      <button type="button" class="btn btn-ghost btn-xs text-error hover:bg-error/10" aria-label="Delete input {input.pin ?? ''}" onclick={() => void deleteInput(input.id)}>🗑</button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
          {#if calibrationPreviewError}<p role="alert" class="mt-2 text-sm text-error">{calibrationPreviewError}</p>{/if}
        {/if}
      </div>

      <div class="mt-6 rounded-xl bg-base-200/50 p-6">
        <div class="mb-4 flex items-center justify-between">
          <h3 class="text-base font-semibold">Matrices</h3>
          <button
            type="button"
            class="btn btn-outline btn-sm"
            onclick={() => {
              rowPinsInput = '';
              colPinsInput = '';
              matrixErrors = {};
              matrixModalOpen = true;
            }}
          >＋ Add Matrix</button>
        </div>
        {#if detail.matrices.length === 0}
          <p class="text-sm text-muted">No matrices configured. Add a button matrix for multiple buttons using fewer pins.</p>
        {:else}
          <div class="overflow-x-auto">
            <table class="table table-sm bg-base-100 rounded-lg">
              <thead><tr class="bg-base-200"><th>Name</th><th>Size</th><th>Buttons</th><th class="w-32"></th></tr></thead>
              <tbody>
                {#each detail.matrices as matrix (matrix.id)}
                  <tr class="hover:bg-base-200/50">
                    <td class="font-medium">{matrix.name}</td>
                    <td class="font-mono text-sm">{matrix.row_pins.length}x{matrix.col_pins.length}</td>
                    <td class="font-mono text-sm">{matrix.buttons.length} buttons</td>
                    <td class="flex gap-1">
                      {#if activePort}
                        <button type="button" class="btn btn-ghost btn-xs text-primary hover:bg-primary/10" onclick={() => startMatrixTest(matrix)}>Test</button>
                      {/if}
                      <button type="button" class="btn btn-ghost btn-xs text-error hover:bg-error/10" aria-label="Delete matrix {matrix.name}" onclick={() => void deleteMatrix(matrix.id)}>🗑</button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>

      <div class="mt-6 rounded-xl bg-base-200/50 p-6">
        <div class="mb-4 flex items-center justify-between">
          <h3 class="text-base font-semibold">Outputs</h3>
          <button type="button" class="btn btn-outline btn-sm" onclick={() => { outputForm = { pin: '', name: '' }; outputErrors = {}; outputModalOpen = true; }}>＋ Add Output</button>
        </div>
        {#if detail.outputs.length === 0}
          <p class="text-sm text-muted">No outputs configured. Add LEDs or indicators to control.</p>
        {:else}
          <div class="overflow-x-auto">
            <table class="table table-sm bg-base-100 rounded-lg">
              <thead><tr class="bg-base-200"><th class="text-center">Pin</th><th>Name</th><th>Test</th><th class="w-16"></th></tr></thead>
              <tbody>
                {#each detail.outputs as output (output.id)}
                  <tr class="hover:bg-base-200/50">
                    <td class="text-center font-mono">{output.pin}</td>
                    <td>
                      <input
                        type="text"
                        value={output.name ?? ''}
                        placeholder="Unnamed"
                        onchange={(event) => void renameOutput(output, event.currentTarget.value)}
                        aria-label="Output name for pin {output.pin}"
                        class="input input-ghost input-xs w-full max-w-40 placeholder:italic placeholder:text-muted"
                      />
                    </td>
                    <td><div class="flex gap-1"><button type="button" class="btn btn-outline btn-xs" disabled={!activePort || activeGeneration === null || hardwareTestPending === output.id} onclick={() => void setOutput(output, true)} aria-label="Turn output {output.pin} on">On</button><button type="button" class="btn btn-outline btn-xs" disabled={!activePort || activeGeneration === null || hardwareTestPending === output.id} onclick={() => void setOutput(output, false)} aria-label="Turn output {output.pin} off">Off</button></div></td>
                    <td>
                      <button type="button" class="btn btn-ghost btn-xs text-error hover:bg-error/10" aria-label="Delete output {output.pin}" onclick={() => void deleteOutput(output.id)}>🗑</button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>

      <div class="mt-6 rounded-xl bg-base-200/50 p-6">
        <div class="mb-4 flex items-center justify-between">
          <h3 class="text-base font-semibold">Displays</h3>
          <button type="button" class="btn btn-outline btn-sm" onclick={() => { i2cEditing = null; i2cModalOpen = true; }}>＋ Add display</button>
        </div>
        {#if detail.i2c_modules.length === 0}
          <p class="text-sm text-muted">No displays configured. Add a display to show simulator values.</p>
        {:else}
          <div class="overflow-x-auto">
            <table class="table table-sm bg-base-100 rounded-lg">
              <thead><tr class="bg-base-200"><th>Name</th><th>Chip</th><th>Address</th><th>Digits</th><th>Brightness</th><th>Test</th><th class="w-20"></th></tr></thead>
              <tbody>
                {#each detail.i2c_modules as mod (mod.id)}
                  <tr class="hover:bg-base-200/50">
                    <td>{mod.name ?? '—'}</td>
                    <td class="text-xs uppercase">{mod.module_chip}</td>
                    <td class="font-mono">{formatI2cAddress(mod.i2c_address)}</td>
                    <td>{mod.params?.num_digits ?? '—'}</td>
                    <td>{mod.params ? `${Math.round((mod.params.brightness * 100) / 15)}%` : '—'}</td>
                    <td><div class="flex gap-1"><input type="text" class="input input-bordered input-xs w-20 font-mono" value={displayTestText[mod.id] ?? ''} oninput={(event) => (displayTestText = { ...displayTestText, [mod.id]: event.currentTarget.value })} aria-label="Test text for display {mod.name ?? formatI2cAddress(mod.i2c_address)}" /><button type="button" class="btn btn-outline btn-xs" disabled={!activePort || activeGeneration === null || hardwareTestPending === mod.id || !(displayTestText[mod.id] ?? '').trim()} onclick={() => void testDisplay(mod)} aria-label="Test display {mod.name ?? formatI2cAddress(mod.i2c_address)}">Test</button></div></td>
                    <td>
                      <div class="flex gap-1">
                        <button type="button" class="btn btn-ghost btn-xs" aria-label="Edit display {mod.name ?? formatI2cAddress(mod.i2c_address)}" onclick={() => { i2cEditing = mod; i2cModalOpen = true; }}>✎</button>
                        <button type="button" class="btn btn-ghost btn-xs text-error" aria-label="Delete display {mod.name ?? formatI2cAddress(mod.i2c_address)}" onclick={() => void deleteI2cModule(mod.id)}>🗑</button>
                      </div>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </div>

      {#if mode === 'existing'}
        <div class="mt-6 rounded-xl border border-error/30 bg-error/5 p-6">
          <h3 class="text-base font-semibold text-error">Danger Zone</h3>
          <p class="mt-1 text-sm text-muted">Permanently remove this configuration and all associated data</p>
          <button type="button" class="btn btn-error btn-sm mt-3" disabled={activePort !== null} title={activePort ? 'Cannot delete while configuration is active on a device' : undefined} onclick={() => { deleteError = ''; deleteModalOpen = true; }}>Delete Configuration</button>
        </div>
      {/if}
    {/if}
  {/if}
</div>

{#if inputModalOpen}
  <div class="fixed inset-0 z-50 flex items-center justify-center">
    <div class="absolute inset-0 bg-black/50" onclick={() => (inputModalOpen = false)} aria-hidden="true"></div>
    <div class="relative mx-4 max-h-[90vh] w-full max-w-md overflow-y-auto rounded-xl bg-base-100 p-6 shadow-xl">
      <h2 class="mb-4 text-xl font-semibold">Add Input</h2>
      <form id="add-input-form" onsubmit={(event) => void addInput(event)} class="space-y-4" novalidate>
        <div>
          <label class="label" for="input-name"><span class="label-text">Name (optional)</span></label>
          <input id="input-name" type="text" bind:value={inputForm.name} placeholder="e.g., Horn Button, Throttle" class="input input-bordered w-full" />
        </div>
        <div>
          <label class="label" for="input-kind"><span class="label-text">Input Type</span></label>
          <select id="input-kind" bind:value={inputForm.kind} class="select select-bordered w-full">
            <option value="analog">Analog</option>
            <option value="button">Button</option>
          </select>
        </div>
        <div>
          <label class="label" for="input-pin"><span class="label-text">Pin Number</span></label>
          <input id="input-pin" type="number" bind:value={inputForm.pin} placeholder="Enter pin number (0-254)" min="0" max="254" class="input input-bordered w-full" class:input-error={!!inputErrors.pin} />
          {#if inputErrors.pin}<p role="alert" class="mt-1 text-xs text-error">{inputErrors.pin}</p>{/if}
        </div>
        {#if inputForm.kind === 'analog'}
          <div>
            <label class="label" for="input-sensitivity"><span class="label-text">Sensitivity (1-10)</span></label>
            <input id="input-sensitivity" type="number" bind:value={inputForm.sensitivity} min="1" max="10" class="input input-bordered w-full" class:input-error={!!inputErrors.sensitivity} />
            {#if inputErrors.sensitivity}<p role="alert" class="mt-1 text-xs text-error">{inputErrors.sensitivity}</p>{/if}
          </div>
        {:else}
          <div>
            <label class="label" for="input-debounce"><span class="label-text">Debounce (0-255 ms)</span></label>
            <input id="input-debounce" type="number" bind:value={inputForm.debounce} min="0" max="255" placeholder="20" class="input input-bordered w-full" class:input-error={!!inputErrors.debounce} />
            {#if inputErrors.debounce}<p role="alert" class="mt-1 text-xs text-error">{inputErrors.debounce}</p>{/if}
          </div>
        {/if}
        <div class="mt-6 flex justify-end gap-2">
          <button type="button" class="btn btn-ghost" onclick={() => (inputModalOpen = false)}>Cancel</button>
          <button type="submit" class="btn btn-primary">Add Input</button>
        </div>
      </form>
    </div>
  </div>
{/if}

{#if matrixModalOpen}
  <div class="fixed inset-0 z-50 flex items-center justify-center">
    <div class="absolute inset-0 bg-black/50" onclick={() => (matrixModalOpen = false)} aria-hidden="true"></div>
    <div class="relative mx-4 max-h-[90vh] w-full max-w-md overflow-y-auto rounded-xl bg-base-100 p-6 shadow-xl">
      <h2 class="mb-4 text-xl font-semibold">Add Matrix</h2>
      <form id="add-matrix-form" onsubmit={(event) => void addMatrix(event)} class="space-y-4" novalidate>
        <div class="rounded-lg bg-base-200 p-4">
          <p class="mb-3 text-sm text-muted">Enter GPIO pin numbers for rows and columns, separated by commas.</p>
          <div class="space-y-3">
            <div>
              <label class="label py-1" for="matrix-row-pins"><span class="label-text text-sm">Row Pins</span></label>
              <input id="matrix-row-pins" type="text" bind:value={rowPinsInput} oninput={validateMatrixPins} placeholder="e.g., 2, 3, 4, 5" class="input input-bordered input-sm w-full" class:input-error={!!matrixErrors.row_pins} />
              {#if matrixErrors.row_pins}<p role="alert" class="mt-1 text-xs text-error">{matrixErrors.row_pins}</p>{/if}
            </div>
            <div>
              <label class="label py-1" for="matrix-col-pins"><span class="label-text text-sm">Column Pins</span></label>
              <input id="matrix-col-pins" type="text" bind:value={colPinsInput} oninput={validateMatrixPins} placeholder="e.g., 8, 9, 10" class="input input-bordered input-sm w-full" class:input-error={!!matrixErrors.col_pins} />
              {#if matrixErrors.col_pins}<p role="alert" class="mt-1 text-xs text-error">{matrixErrors.col_pins}</p>{/if}
            </div>
            {#if matrixErrors.general}<p role="alert" class="text-sm text-error">{matrixErrors.general}</p>{/if}
          </div>
        </div>
        {#if parsedRowPins.length > 0 && parsedColPins.length > 0}
          <div class="rounded-lg bg-base-200 p-4">
            <div class="mb-3 flex items-center justify-between">
              <span class="text-sm font-medium">Grid Preview</span>
              <span class="badge badge-secondary badge-sm">{parsedRowPins.length}x{parsedColPins.length} = {parsedRowPins.length * parsedColPins.length} buttons</span>
            </div>
            <div class="overflow-x-auto">
              <table class="text-xs">
                <thead>
                  <tr>
                    <th class="p-1"></th>
                    {#each parsedColPins as colPin, colIndex}<th class="p-1 text-center font-mono text-muted">C{colIndex}<br /><span class="text-[10px]">({colPin})</span></th>{/each}
                  </tr>
                </thead>
                <tbody>
                  {#each parsedRowPins as rowPin, rowIndex}
                    <tr>
                      <td class="p-1 font-mono text-muted">R{rowIndex} <span class="text-[10px]">({rowPin})</span></td>
                      {#each parsedColPins as _, colIndex}
                        <td class="p-1"><div class="flex h-6 w-8 items-center justify-center rounded bg-base-300 font-mono text-[10px]">{128 + rowIndex * parsedColPins.length + colIndex}</div></td>
                      {/each}
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
            <p class="mt-2 text-[10px] text-muted">Virtual pin = 128 + (row x cols + col)</p>
          </div>
        {/if}
        <div class="mt-6 flex justify-end gap-2">
          <button type="button" class="btn btn-ghost" onclick={() => (matrixModalOpen = false)}>Cancel</button>
          <button type="submit" class="btn btn-primary">Add Matrix</button>
        </div>
      </form>
    </div>
  </div>
{/if}

{#if outputModalOpen}
  <div class="fixed inset-0 z-50 flex items-center justify-center">
    <div class="absolute inset-0 bg-black/50" onclick={() => (outputModalOpen = false)} aria-hidden="true"></div>
    <div class="relative mx-4 w-full max-w-md rounded-xl bg-base-100 p-6 shadow-xl">
      <h2 class="mb-4 text-xl font-semibold">Add Output</h2>
      <form id="add-output-form" onsubmit={(event) => void addOutput(event)} class="space-y-4" novalidate>
        <div>
          <label class="label" for="output-pin"><span class="label-text">Pin Number</span></label>
          <input id="output-pin" type="number" bind:value={outputForm.pin} placeholder="Enter pin number (0-255)" min="0" max="255" class="input input-bordered w-full" class:input-error={!!outputErrors.pin} />
          {#if outputErrors.pin}<p role="alert" class="mt-1 text-xs text-error">{outputErrors.pin}</p>{/if}
        </div>
        <div>
          <label class="label" for="output-name"><span class="label-text">Name (optional)</span></label>
          <input id="output-name" type="text" bind:value={outputForm.name} placeholder="e.g., Brake Warning LED" class="input input-bordered w-full" />
        </div>
        <div class="mt-6 flex justify-end gap-2">
          <button type="button" class="btn btn-ghost" onclick={() => (outputModalOpen = false)}>Cancel</button>
          <button type="submit" class="btn btn-primary">Add Output</button>
        </div>
      </form>
    </div>
  </div>
{/if}

{#if i2cModalOpen}
  <div class="fixed inset-0 z-50 flex items-center justify-center" role="dialog" aria-modal="true" aria-labelledby="i2c-display-title">
    <div class="absolute inset-0 bg-black/50" onclick={() => { i2cModalOpen = false; i2cEditing = null; }} aria-hidden="true"></div>
    <div class="relative mx-4 max-h-[90vh] w-full max-w-md overflow-y-auto rounded-xl bg-base-100 p-6 shadow-xl">
      <h3 id="i2c-display-title" class="mb-4 text-lg font-bold">{i2cEditing ? 'Edit display' : 'Add display'}</h3>
      <I2cModuleForm module={i2cEditing} save={saveI2cModule} cancel={() => { i2cModalOpen = false; i2cEditing = null; }} />
    </div>
  </div>
{/if}

{#if deleteModalOpen}
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
    <div class="fixed inset-0 bg-black/50" onclick={() => (deleteModalOpen = false)} aria-hidden="true"></div>
    <div class="relative w-full max-w-md rounded-xl bg-base-100 p-6 shadow-xl">
      <h3 class="mb-4 text-lg font-semibold text-error">Delete Configuration</h3>
      {#if activePort}
        <div class="alert alert-warning mb-4"><span class="text-sm">This configuration is currently active on a connected device.</span></div>
      {/if}
      <p class="mb-6 text-sm text-muted">
        Are you sure you want to delete "<span class="font-medium">{draftName}</span>"? This will permanently delete the configuration and all its inputs and calibration data.
      </p>
      {#if deleteError}<p role="alert" class="mb-4 text-sm text-error">{deleteError}</p>{/if}
      <div class="flex justify-end gap-2">
        <button type="button" class="btn btn-ghost" onclick={() => (deleteModalOpen = false)}>Cancel</button>
        {#if !activePort}
          <button type="button" class="btn btn-error" onclick={() => void confirmDelete()}>Delete</button>
        {/if}
      </div>
    </div>
  </div>
{/if}

{#if calibratingInput && activePort && activeGeneration !== null}
  <CalibrationWizard input={calibratingInput} port={activePort} generation={activeGeneration} api={bridge} close={() => { calibratingInput = null; if (routeId) void load(routeId); }} />
{/if}

{#if testingMatrix}
  <MatrixTestWizard
    matrix={testingMatrix}
    {inputValues}
    testedButtons={testedButtons}
    reset={() => (testedButtons = [])}
    close={() => (testingMatrix = null)}
  />
{/if}
