<script lang="ts">
  import { onMount } from 'svelte';
  import type { VjoyMappingView, VjoyView } from '../../../bridge/generated';
  import type { UiBridge, VjoyStatusView } from '../../../bridge/client';
  import type { HardwareCatalog, HardwareInputOption } from '../../hardware';
  import { collectHardware, EMPTY_HARDWARE_CATALOG } from '../../hardware';

  let { bridge }: { bridge: UiBridge } = $props();

  const AXES: { value: string; label: string }[] = [
    { value: 'x', label: 'X' },
    { value: 'y', label: 'Y' },
    { value: 'z', label: 'Z' },
    { value: 'rx', label: 'Rx' },
    { value: 'ry', label: 'Ry' },
    { value: 'rz', label: 'Rz' },
    { value: 'slider_1', label: 'Slider 1' },
    { value: 'slider_2', label: 'Slider 2' },
  ];
  const BUTTON_COUNT = 32;
  const DEVICE_COUNT = 16;

  type VjoyStatus = 'off' | 'enabling' | 'active' | 'disabling' | 'degraded' | 'error';

  let loading = $state(true);
  let vjoy = $state<VjoyView>({ enabled: false, device_index: 1, selected_devices: [], mappings: [] });
  let hardware = $state<HardwareCatalog>(EMPTY_HARDWARE_CATALOG);
  let hardwareError = $state('');
  let transitioning = $state<'enable' | 'disable' | null>(null);
  let statusError = $state('');
  let statusErrorCode = $state('');
  let confirmTransition = $state(false);

  let showMappingChoices = $state(false);
  let showUnusedTargets = $state(false);
  let mappingKind = $state<'axis' | 'button' | null>(null);
  let editingMapping = $state<VjoyMappingView | null>(null);
  let mappingError = $state('');
  let pendingReplacement = $state(false);
  let mappingPending = $state(false);

  let formInputId = $state('');
  let formDevice = $state('1');
  let formAxis = $state('x');
  let formButton = $state('1');
  let formInverted = $state(false);
  let preview = $state<string | null>(null);
  let vjoyState = $state<VjoyStatusView>({ state: 'off', reason: null });
  let recoveryPending = $state(false);
  let recoveryNotice = $state('');
  let recoveryError = $state('');

  let previewHint = $state('Choose a hardware input to preview it.');
  let previewRequest = 0;

  const status = $derived.by(() => {
    if (transitioning === 'enable') return 'enabling' as VjoyStatus;
    if (transitioning === 'disable') return 'disabling' as VjoyStatus;
    if (statusError !== '') return statusErrorCode === 'conflict' ? ('degraded' as VjoyStatus) : ('error' as VjoyStatus);
    return vjoy.enabled ? ('active' as VjoyStatus) : ('off' as VjoyStatus);
  });

  const statusUi = $derived.by(() => {
    switch (status) {
      case 'enabling':
        return { label: 'Turning on', help: 'You can cancel the Windows prompt. No change will be made.', toggle: null, recovery: null };
      case 'disabling':
        return { label: 'Turning off', help: 'Removing the virtual joystick device.', toggle: null, recovery: null };
      case 'active':
        return {
          label: 'On',
          help: `Mapped controls are being sent to joystick device ${vjoy.device_index}.`,
          toggle: 'Disable',
          recovery: null,
        };
      case 'degraded':
        return { label: 'Connection interrupted', help: statusError, toggle: null, recovery: 'Retry' };
      case 'error':
        return { label: 'Needs attention', help: statusError, toggle: null, recovery: 'Retry' };
      default:
        return { label: 'Off', help: 'No virtual joystick device is installed.', toggle: 'Enable', recovery: null };
    }
  });

  const axisMappings = $derived(vjoy.mappings.filter((mapping) => mapping.target.startsWith('axis/')));
  const buttonMappings = $derived(vjoy.mappings.filter((mapping) => mapping.target.startsWith('button/')));

  const compatibleInputs = $derived(
    mappingKind === 'axis'
      ? hardware.inputs.filter((input) => input.kind === 'analog')
      : hardware.inputs.filter((input) => input.kind === 'button'),
  );

  onMount(() => {
    const unsubscribers: (() => void)[] = [];
    let disposed = false;
    const keep = (unsubscribe: () => void) => { if (disposed) unsubscribe(); else unsubscribers.push(unsubscribe); };
    void (async () => {
      const loaded = await bridge.getVjoy();
      if (loaded.ok) vjoy = loaded.value.value;
      const collected = await collectHardware(bridge);
      hardware = collected.catalog;
      hardwareError = collected.error ?? '';
      loading = false;
      void refreshVjoyStatus();
      const unsubscribeVjoy = await bridge.subscribe<VjoyView>(
        'vjoy',
        (snapshot) => {
          vjoy = snapshot.value;
        },
        () => {},
      );
      keep(unsubscribeVjoy);
      // The hardware topic registration also routes `ui://hardware/input`
      // events to this window for the live preview.
      const unsubscribeHardware = await bridge.subscribe<unknown>(
        'hardware',
        () => {},
        () => {},
      );
      keep(unsubscribeHardware);
    })();
    const unlistenInputs = bridge.onHardwareInput(onHardwareSample);
    keep(unlistenInputs);
    return () => { disposed = true; unsubscribers.forEach((unsubscribe) => unsubscribe()); };
  });

  function onHardwareSample(event: { input_id: string; value: number }) {
    if (mappingKind === null || event.input_id !== formInputId) return;
    const input = hardware.inputs.find((candidate) => candidate.id === event.input_id);
    if (!input) return;
    if (input.kind === 'button') {
      preview = event.value === 0 ? 'Released' : 'Pressed';
      return;
    }
    if (!input.calibration) {
      preview = null;
      previewHint = 'Calibrate this input in its hardware configuration to preview the axis.';
      return;
    }
    const request = ++previewRequest;
    void bridge.previewInput(input.id, event.value).then((result) => {
      if (request !== previewRequest || formInputId !== input.id || mappingKind !== 'axis') return;
      if (result.ok) preview = `${result.value.axis_percent}%`;
      else { preview = null; previewHint = result.error.message; }
    }).catch(() => {
      if (request === previewRequest) { preview = null; previewHint = 'Live preview is unavailable.'; }
    });
  }

  function inputLabel(input: HardwareInputOption): string {
    return `${input.device_name} · ${input.name || `Pin ${input.pin}`}`;
  }

  async function requestTransition() {
    confirmTransition = false;
    const enabling = !vjoy.enabled;
    transitioning = enabling ? 'enable' : 'disable';
    statusError = '';
    statusErrorCode = '';
    try {
      const result = enabling ? await bridge.vjoyEnable() : await bridge.vjoyDisable();
      if (!result.ok) {
        statusError = result.error.message;
        statusErrorCode = result.error.code;
        return;
      }
      vjoy = result.value.value;
    } finally {
      transitioning = null;
      void refreshVjoyStatus();
    }
  }

  async function retryTransition() {
    statusError = '';
    statusErrorCode = '';
    const enabling = !vjoy.enabled;
    transitioning = enabling ? 'enable' : 'disable';
    try {
      const result = enabling ? await bridge.vjoyEnable() : await bridge.vjoyDisable();
      if (!result.ok) {
        statusError = result.error.message;
        statusErrorCode = result.error.code;
        return;
      }
      vjoy = result.value.value;
    } finally {
      transitioning = null;
      void refreshVjoyStatus();
    }
  }

  async function refreshVjoyStatus() {
    const result = await bridge.getVjoyStatus();
    if (result.ok) vjoyState = result.value;
    else vjoyState = { state: 'error', reason: result.error.message };
  }

  async function retryVjoyEnable() {
    recoveryPending = true;
    recoveryNotice = '';
    recoveryError = '';
    try {
      const result = await bridge.vjoyEnable();
      if (!result.ok) {
        recoveryError = result.error.message;
        return;
      }
      vjoy = result.value.value;
      recoveryNotice = 'vJoy mode enabled.';
    } finally {
      recoveryPending = false;
      void refreshVjoyStatus();
    }
  }

  async function removeLeftoverDevice() {
    recoveryPending = true;
    recoveryNotice = '';
    recoveryError = '';
    try {
      const result = await bridge.removeVjoyLeftover();
      if (!result.ok) {
        recoveryError = result.error.message;
        return;
      }
      if (!result.value.ok) {
        recoveryError = result.value.error ?? 'The leftover device could not be removed.';
        return;
      }
      recoveryNotice = 'Leftover device removed.';
    } finally {
      recoveryPending = false;
      void refreshVjoyStatus();
    }
  }

  async function repairInstallation() {
    recoveryPending = true;
    recoveryNotice = '';
    recoveryError = '';
    try {
      const result = await bridge.repairVjoy();
      if (!result.ok) {
        recoveryError = result.error.message;
        return;
      }
      if (!result.value.ok) {
        recoveryError = result.value.error ?? 'The vJoy installation could not be repaired.';
        return;
      }
      recoveryNotice = 'vJoy installation checked.';
    } finally {
      recoveryPending = false;
      void refreshVjoyStatus();
    }
  }

  async function toggleDevice(device: number, checked: boolean) {
    const next = new Set(vjoy.selected_devices);
    if (checked) next.add(device);
    else next.delete(device);
    const result = await bridge.setVjoySelection([...next].sort((a, b) => a - b));
    if (!result.ok) {
      hardwareError = result.error.message;
      return;
    }
    vjoy = result.value.value;
    void refreshVjoyStatus();
  }

  function openForm(kind: 'axis' | 'button', mapping: VjoyMappingView | null) {
    previewRequest += 1;
    showMappingChoices = false;
    mappingKind = kind;
    editingMapping = mapping;
    mappingError = '';
    preview = null;
    previewHint = 'Choose a hardware input to preview it.';
    if (mapping) {
      formInputId = mapping.input_id;
      formDevice = String(mapping.device_index);
      formInverted = mapping.inverted;
      if (kind === 'axis') formAxis = mapping.target.replace('axis/', '');
      else formButton = mapping.target.replace('button/', '');
    } else {
      const first = compatibleInputs[0];
      formInputId = first?.id ?? '';
      formDevice = String(vjoy.selected_devices[0] ?? vjoy.device_index ?? 1);
      formInverted = false;
    }
  }

  function closeForm() {
    previewRequest += 1;
    mappingKind = null;
    editingMapping = null;
    preview = null;
    previewHint = 'Choose a hardware input to preview it.';
  }

  function cancelDialogs() {
    confirmTransition = false;
    pendingReplacement = false;
    closeForm();
  }

  function selectedInput(): HardwareInputOption | null {
    return hardware.inputs.find((candidate) => candidate.id === formInputId) ?? null;
  }

  function onFormInputChange(event: Event) {
    previewRequest += 1;
    formInputId = (event.currentTarget as HTMLSelectElement).value;
    preview = null;
    const input = selectedInput();
    if (!input) previewHint = 'Choose a hardware input to preview it.';
    else if (input.kind === 'analog' && !input.calibration) {
      previewHint = 'Calibrate this input in its hardware configuration to preview the axis.';
    } else {
      previewHint = 'Move the control to preview it.';
    }
  }

  async function saveMapping(replace: boolean) {
    if (formInputId === '') {
      mappingError = 'Choose a hardware input.';
      return;
    }
    const target = mappingKind === 'axis' ? `axis/${formAxis}` : `button/${formButton}`;
    const draft = {
      device_index: Number.parseInt(formDevice, 10) || 1,
      target,
      inverted: mappingKind === 'axis' ? formInverted : false,
    };
    mappingError = '';
    mappingPending = true;
    try {
      const result = await bridge.putVjoyMapping(formInputId, draft, replace);
      if (!result.ok) {
        if (result.error.code === 'conflict' && !replace) {
          pendingReplacement = true;
          return;
        }
        mappingError = result.error.message;
        return;
      }
      vjoy = result.value.value;
      pendingReplacement = false;
      closeForm();
    } finally {
      mappingPending = false;
    }
  }

  async function deleteMapping(id: string) {
    mappingError = '';
    const result = await bridge.deleteVjoyMapping(id);
    if (!result.ok) {
      mappingError = result.error.message;
      return;
    }
    vjoy = result.value.value;
    closeForm();
  }

  function findAxis(axis: string): VjoyMappingView | null {
    return vjoy.mappings.find((mapping) => mapping.target === `axis/${axis}`) ?? null;
  }

  function findButton(button: number): VjoyMappingView | null {
    return vjoy.mappings.find((mapping) => mapping.target === `button/${button}`) ?? null;
  }

  function mappingInputName(mapping: VjoyMappingView): string {
    return mapping.input_name || `Pin ${mapping.input_pin ?? '—'}`;
  }
</script>

<svelte:window
  onkeydown={(event) => {
    if (event.key === 'Escape') cancelDialogs();
  }}
/>

<div class="mx-auto max-w-2xl">
  <header class="mb-8">
    <h1 class="text-2xl font-semibold">Virtual joystick</h1>
    <p class="mt-2 max-w-prose text-sm text-muted">
      Send selected hardware controls to games as one standard Windows joystick.
    </p>
  </header>

  {#if loading}
    <div class="py-16 flex items-center justify-center" role="status">
      <span class="loading loading-spinner loading-lg text-primary"></span>
    </div>
  {:else}
    <section class="rounded-xl border border-base-300 bg-base-200/50 p-5">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
          <p class="text-xs uppercase tracking-wide text-muted">Status</p>
          <p data-testid="virtual-joystick-status" aria-live="polite" class="mt-1 text-lg font-semibold">
            {statusUi.label}
          </p>
          <p class="mt-1 text-sm text-muted">{statusUi.help}</p>
        </div>
        <button
          type="button"
          data-testid="virtual-joystick-toggle"
          disabled={statusUi.toggle === null}
          class="btn btn-primary"
          onclick={() => (confirmTransition = true)}
        >
          {statusUi.toggle ?? statusUi.label}
        </button>
      </div>
      {#if statusUi.recovery}
        <button type="button" data-testid="virtual-joystick-recovery" class="btn btn-outline mt-4" onclick={() => void retryTransition()}>
          {statusUi.recovery}
        </button>
      {/if}
      {#if vjoyState.state === 'needs_setup' || vjoyState.state === 'needs_cleanup' || vjoyState.state === 'error'}
        <div class="mt-4 space-y-3 rounded-lg border border-base-300 bg-base-100 p-4" data-testid="vjoy-recovery">
          {#if vjoyState.state === 'needs_setup'}
            <p class="text-sm text-muted">
              vJoy device missing — the saved mode is enabled but the device is absent.
            </p>
            <button type="button" data-testid="vjoy-retry" class="btn btn-outline btn-sm" disabled={recoveryPending} onclick={() => void retryVjoyEnable()}>
              Retry
            </button>
          {:else if vjoyState.state === 'needs_cleanup'}
            <p class="text-sm text-muted">Leftover device</p>
            <button type="button" data-testid="vjoy-remove-leftover" class="btn btn-outline btn-sm" disabled={recoveryPending} onclick={() => void removeLeftoverDevice()}>
              Remove leftover device
            </button>
          {:else if vjoyState.state === 'error'}
            <p class="text-sm text-muted">{vjoyState.reason ?? 'vJoy is in an unexpected state.'}</p>
            <div class="flex flex-wrap gap-2">
              <button type="button" data-testid="vjoy-repair" class="btn btn-outline btn-sm" disabled={recoveryPending} onclick={() => void repairInstallation()}>
                Check installation
              </button>
              <button type="button" data-testid="vjoy-check-configuration" class="btn btn-outline btn-sm" disabled={recoveryPending} onclick={() => void refreshVjoyStatus()}>
                Check configuration
              </button>
            </div>
          {/if}
          {#if recoveryNotice}
            <p role="status" class="text-sm">{recoveryNotice}</p>
          {/if}
          {#if recoveryError}
            <p role="alert" class="text-sm text-error">{recoveryError}</p>
          {/if}
        </div>
      {/if}
    </section>

    <section class="mt-6 rounded-xl border border-base-300 bg-base-200/50 p-5" aria-labelledby="vjoy-devices-title">
      <h2 id="vjoy-devices-title" class="text-base font-semibold">Joystick devices</h2>
      <p class="mt-1 text-sm text-muted">
        Choose which vJoy devices the mappings below target.
      </p>
      <div class="mt-3 flex flex-wrap gap-3">
        {#each Array.from({ length: DEVICE_COUNT }, (_, index) => index + 1) as device (device)}
          <label class="flex items-center gap-1.5 text-sm">
            <input
              type="checkbox"
              class="checkbox checkbox-sm"
              checked={vjoy.selected_devices.includes(device)}
              onchange={(event) => void toggleDevice(device, (event.currentTarget as HTMLInputElement).checked)}
              data-testid="vjoy-device-{device}"
            />
            <span>{device}</span>
          </label>
        {/each}
      </div>
    </section>

    <p id="offline-mapping-help" class="mt-4 text-sm text-muted">
      You can configure mappings with hardware disconnected and the joystick off.
      Train Sim World is not needed for joystick mode.
    </p>

    {#if hardwareError}
      <p role="alert" class="alert alert-error mt-5">{hardwareError}</p>
    {/if}
    {#if mappingError}
      <p role="alert" class="alert alert-error mt-5">{mappingError}</p>
    {/if}

    <section class="mt-8" aria-labelledby="mappings-heading">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h2 id="mappings-heading" class="text-xl font-semibold">Mappings</h2>
        <button
          type="button"
          id="add-mapping"
          data-testid="add-mapping"
          aria-expanded={showMappingChoices}
          aria-controls="mapping-kind-choices"
          disabled={transitioning !== null}
          class="btn btn-primary btn-sm"
          onclick={() => (showMappingChoices = !showMappingChoices)}
        >
          Add mapping
        </button>
      </div>
      <p id="mapping-capacity" class="mt-2 text-sm text-muted">
        {axisMappings.length} of 8 axes · {buttonMappings.length} of 32 buttons assigned
      </p>
      {#if showMappingChoices}
        <div id="mapping-kind-choices" class="mt-4 flex flex-wrap items-center gap-2">
          <span class="mr-1 text-sm">Map a hardware input to:</span>
          <button type="button" data-testid="add-axis-mapping" disabled={transitioning !== null} class="btn btn-sm btn-outline" onclick={() => openForm('axis', null)}>
            Axis
          </button>
          <button type="button" data-testid="add-button-mapping" disabled={transitioning !== null} class="btn btn-sm btn-outline" onclick={() => openForm('button', null)}>
            Button
          </button>
        </div>
      {/if}
      {#if vjoy.mappings.length === 0 && !showUnusedTargets}
        <p class="mt-5 text-sm text-muted">No mappings yet. Add an axis for a lever or a button for a switch.</p>
      {/if}

      {#if showUnusedTargets || axisMappings.length > 0}
        <div class="mt-5">
          <h3 class="text-base font-semibold">Axes</h3>
          <div class="mt-2 divide-y divide-base-300 rounded-xl border border-base-300">
            {#each AXES as axis (axis.value)}
              {@const mapping = findAxis(axis.value)}
              {#if showUnusedTargets || mapping}
                <div data-testid="axis-mapping-{axis.value}" class="flex min-h-12 flex-wrap items-center justify-between gap-3 px-4 py-3">
                  <span class="font-medium">{axis.label}</span>
                  {#if mapping}
                    <span class="flex min-w-0 flex-wrap items-center gap-2 text-sm">
                      <span class="break-words">
                        {mappingInputName(mapping)}{mapping.inverted ? ' · Inverted' : ''} · device {mapping.device_index}
                      </span>
                      <button
                        type="button"
                        data-testid="edit-mapping-{mapping.id}"
                        disabled={transitioning !== null}
                        class="btn btn-ghost btn-xs"
                        onclick={() => openForm('axis', mapping)}
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        data-testid="delete-mapping-{mapping.id}"
                        disabled={transitioning !== null}
                        class="btn btn-ghost btn-xs"
                        onclick={() => void deleteMapping(mapping.id)}
                      >
                        Delete
                      </button>
                    </span>
                  {:else}
                    <span class="text-sm text-muted">Not assigned</span>
                  {/if}
                </div>
              {/if}
            {/each}
          </div>
        </div>
      {/if}

      {#if showUnusedTargets || buttonMappings.length > 0}
        <div class="mt-5">
          <h3 class="text-base font-semibold">Buttons</h3>
          <div class="mt-2 divide-y divide-base-300 rounded-xl border border-base-300">
            {#each Array.from({ length: BUTTON_COUNT }, (_, index) => index + 1) as button (button)}
              {@const mapping = findButton(button)}
              {#if showUnusedTargets || mapping}
                <div data-testid="button-target-option" class="flex min-h-11 flex-wrap items-center justify-between gap-3 px-4 py-3">
                  <span>Button {button}</span>
                  {#if mapping}
                    <span class="flex min-w-0 flex-wrap items-center gap-2 text-sm">
                      <span class="break-words">{mappingInputName(mapping)} · device {mapping.device_index}</span>
                      <button
                        type="button"
                        data-testid="edit-mapping-{mapping.id}"
                        disabled={transitioning !== null}
                        class="btn btn-ghost btn-xs"
                        onclick={() => openForm('button', mapping)}
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        data-testid="delete-mapping-{mapping.id}"
                        disabled={transitioning !== null}
                        class="btn btn-ghost btn-xs"
                        onclick={() => void deleteMapping(mapping.id)}
                      >
                        Delete
                      </button>
                    </span>
                  {:else}
                    <span class="text-sm text-muted">Not assigned</span>
                  {/if}
                </div>
              {/if}
            {/each}
          </div>
        </div>
      {/if}
      <button
        type="button"
        id="toggle-target-inventory"
        aria-expanded={showUnusedTargets}
        class="btn btn-ghost btn-sm mt-4"
        onclick={() => (showUnusedTargets = !showUnusedTargets)}
      >
        {showUnusedTargets ? 'Hide unused targets' : 'Show unused targets'}
      </button>
    </section>
  {/if}
</div>

{#if mappingKind}
  <div
    class="fixed inset-0 z-50 grid place-items-center bg-black/50 px-4"
    role="dialog"
    aria-modal="true"
    aria-labelledby="mapping-title"
  >
    <div class="max-h-[calc(100dvh-2rem)] overflow-y-auto w-full max-w-md rounded-xl border border-base-300 bg-base-100 p-6 shadow-xl">
      <h2 id="mapping-title" class="text-lg font-semibold">
        {editingMapping ? 'Edit mapping' : 'Add mapping'}
      </h2>
      <form
        id="virtual-joystick-mapping-form"
        data-testid="mapping-form"
        class="mt-5 space-y-4"
        onsubmit={(event) => {
          event.preventDefault();
          void saveMapping(false);
        }}
      >
        {#if compatibleInputs.length === 0}
          <p class="text-sm text-muted">
            {mappingKind === 'axis' ? 'No analog inputs are configured yet.' : 'No button inputs are configured yet.'}
            <a href="#/" class="underline underline-offset-2">Set up hardware inputs</a>
          </p>
        {:else}
          <label class="block">
            <span class="text-sm font-medium">Hardware input</span>
            <select
              name="input"
              class="select select-bordered mt-1 w-full"
              value={formInputId}
              onchange={onFormInputChange}
              disabled={editingMapping !== null || transitioning !== null}
              data-testid="mapping-input"
            >
              {#each compatibleInputs as input (input.id)}
                <option value={input.id}>{inputLabel(input)}</option>
              {/each}
            </select>
          </label>
        {/if}
        <label class="block">
          <span class="text-sm font-medium">Joystick device</span>
          <select class="select select-bordered mt-1 w-full" bind:value={formDevice} data-testid="mapping-device">
            {#each Array.from({ length: DEVICE_COUNT }, (_, index) => index + 1) as device (device)}
              <option value={String(device)}>Device {device}</option>
            {/each}
          </select>
        </label>
        {#if mappingKind === 'axis'}
          <label class="block">
            <span class="text-sm font-medium">Joystick axis</span>
            <select class="select select-bordered mt-1 w-full" bind:value={formAxis} data-testid="axis-target">
              {#each AXES as axis (axis.value)}
                <option value={axis.value}>{axis.label}</option>
              {/each}
            </select>
          </label>
          <label class="flex min-h-11 items-center gap-3">
            <input type="checkbox" class="checkbox" bind:checked={formInverted} data-testid="mapping-inverted" />
            <span>Invert direction</span>
          </label>
        {:else}
          <label class="block">
            <span class="text-sm font-medium">Joystick button</span>
            <select class="select select-bordered mt-1 w-full" bind:value={formButton} data-testid="button-target">
              {#each Array.from({ length: BUTTON_COUNT }, (_, index) => index + 1) as button (button)}
                <option value={String(button)}>Button {button}</option>
              {/each}
            </select>
          </label>
        {/if}
        <p data-testid="input-preview" class="text-sm text-muted">
          Live input: {preview ?? previewHint}
        </p>
        <div class="flex justify-end gap-2 pt-2">
          <button type="button" data-testid="cancel-mapping" class="btn btn-ghost" onclick={closeForm}>Cancel</button>
          <button type="submit" disabled={transitioning !== null || compatibleInputs.length === 0 || mappingPending} class="btn btn-primary">
            {mappingPending ? 'Saving…' : 'Save mapping'}
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}

{#if confirmTransition}
  <div
    class="fixed inset-0 z-50 grid place-items-center bg-black/50 px-4"
    role="dialog"
    aria-modal="true"
    aria-labelledby="transition-title"
  >
    <div class="w-full max-w-md rounded-xl bg-base-100 p-6 shadow-xl">
      <h2 id="transition-title" class="text-lg font-semibold">
        {vjoy.enabled ? 'Disable virtual joystick?' : 'Enable virtual joystick?'}
      </h2>
      <p class="mt-3 text-sm">
        Windows will request administrator permission to change the virtual joystick device.
      </p>
      <div class="mt-6 flex justify-end gap-2">
        <button type="button" data-testid="cancel-transition" class="btn btn-ghost" onclick={() => (confirmTransition = false)}>Cancel</button>
        <button type="button" data-testid="confirm-transition" class="btn btn-primary" onclick={() => void requestTransition()}>Continue</button>
      </div>
    </div>
  </div>
{/if}

{#if pendingReplacement}
  <div
    class="fixed inset-0 z-50 grid place-items-center bg-black/50 px-4"
    role="dialog"
    aria-modal="true"
    aria-labelledby="replacement-title"
  >
    <div class="w-full max-w-md rounded-xl bg-base-100 p-6 shadow-xl">
      <h2 id="replacement-title" class="text-lg font-semibold">Replace existing binding?</h2>
      <p class="mt-3 text-sm">
        This input already controls a simulator or API binding. Replacing it will move the input to the virtual joystick.
      </p>
      <div class="mt-6 flex justify-end gap-2">
        <button type="button" data-testid="cancel-replacement" class="btn btn-ghost" onclick={() => (pendingReplacement = false)}>Cancel</button>
        <button
          type="button"
          data-testid="confirm-replacement"
          disabled={mappingPending}
          class="btn btn-primary"
          onclick={() => void saveMapping(true)}
        >
          Replace binding
        </button>
      </div>
    </div>
  </div>
{/if}
