<script lang="ts">
  import { onMount } from 'svelte';
  import type {
    BindingsView,
    ButtonBindingView,
    ElementView,
    DisplayBindingView,
    OutputBindingView,
    ScriptsView,
    TrainDetailView,
  } from '../../../bridge/generated';
  import type { SimulatorRuntimeStatus, UiBridge } from '../../../bridge/client';
  import type { Route } from '../../../bridge/route';
  import { collectHardware, EMPTY_HARDWARE_CATALOG, type HardwareCatalog } from '../../hardware';
  import LeverSetupWizard from '../../../components/wizards/LeverSetupWizard.svelte';
  import ButtonBindingWizard from '../../../components/wizards/ButtonBindingWizard.svelte';
  import DisplayBindingWizard from '../../../components/wizards/DisplayBindingWizard.svelte';
  import OutputBindingWizard from '../../../components/wizards/OutputBindingWizard.svelte';
  import SequenceManager from './SequenceManager.svelte';

  let { bridge, route, simulatorStatus = null, simulatorError = '' }: { bridge: UiBridge; route: Route; simulatorStatus?: SimulatorRuntimeStatus | null; simulatorError?: string } = $props();

  const newMode = $derived(route.page === 'train-new');
  const trainId = $derived(route.page === 'train' ? route.trainId : null);
  const initialIdentifier = $derived(route.page === 'train-new' ? route.query.get('identifier') ?? '' : '');

  let loading = $state(true);
  let notFound = $state(false);
  let flash = $state('');
  let flashError = $state('');
  let activatePending = $state(false);

  async function activateTrain() {
    if (!trainId || isActive || activatePending) return;
    activatePending = true;
    flashError = '';
    const result = await bridge.activateTrain(trainId);
    activatePending = false;
    if (!result.ok) flashError = result.error ?? 'Failed to activate the train.';
  }
  let hardwareError = $state('');

  let train = $state<TrainDetailView | null>(null);
  let bindings = $state<BindingsView>({ lever: [], button: [], output: [], display: [] });
  let scripts = $state<ScriptsView['scripts']>([]);
  let hardware = $state<HardwareCatalog>(EMPTY_HARDWARE_CATALOG);

  let name = $state('');
  let description = $state('');
  let identifiers = $state<string[]>([]);
  let seededRoute: string | undefined;
  $effect(() => {
    const key = `${route.path}:${initialIdentifier}`;
    if (seededRoute === key) return;
    seededRoute = key;
    identifiers = [initialIdentifier];
  });
  let fieldErrors = $state<Record<string, string>>({});
  let savePending = $state(false);

  let addElementOpen = $state(false);
  let elementName = $state('');
  let elementKind = $state<'lever' | 'button'>('lever');
  let elementErrors = $state<Record<string, string>>({});
  let elementPending = $state(false);

  let deleteOpen = $state(false);
  let deletePending = $state(false);

  let leverWizardElement = $state<ElementView | null>(null);
  let buttonWizardElement = $state<ElementView | null>(null);
  let displayWizardBinding = $state<'new' | DisplayBindingView | null>(null);
  let outputWizardBinding = $state<'new' | OutputBindingView | null>(null);

  const isActive = $derived(trainId !== null && simulatorStatus?.active_train_id === trainId);
  const activityKnown = $derived(simulatorStatus !== null && simulatorError === '');
  const deleteBlocked = $derived(!activityKnown || isActive);
  const currentIdentifier = $derived(simulatorStatus?.detected_identifier ?? null);

  const trainScripts = $derived(scripts.filter((script) => train?.id != null && script.train_id === train.id));
  const trainOutputBindings = $derived(bindings.output.filter((binding) => train?.id != null && binding.train_id === train.id));
  const trainDisplayBindings = $derived(bindings.display.filter((binding) => train?.id != null && binding.train_id === train.id));

  onMount(() => {
    const unsubscribers: (() => void)[] = [];
    let disposed = false;
    const keep = (unsubscribe: () => void) => { if (disposed) unsubscribe(); else unsubscribers.push(unsubscribe); };
    void (async () => {
      if (newMode) {
        loading = false;
      } else if (trainId) {
        await reloadTrain();
        const bound = await bridge.getBindings();
        if (bound.ok) bindings = bound.value.value;
        const loadedScripts = await bridge.getScripts();
        if (loadedScripts.ok) scripts = loadedScripts.value.value.scripts;
        const collected = await collectHardware(bridge);
        hardware = collected.catalog;
        hardwareError = collected.error ?? '';
      }
      if (!newMode && trainId) {
        const unsubscribeBindings = await bridge.subscribe<BindingsView>(
          'bindings',
          (snapshot) => {
            bindings = snapshot.value;
          },
          () => {},
        );
        keep(unsubscribeBindings);
        const unsubscribeScripts = await bridge.subscribe<ScriptsView>(
          'scripts',
          (snapshot) => {
            scripts = snapshot.value.scripts;
          },
          () => {},
        );
        keep(unsubscribeScripts);
      }
    })();
    return () => { disposed = true; unsubscribers.forEach((unsubscribe) => unsubscribe()); };
  });

  async function reloadTrain(preserveHeaderDraft = false) {
    if (!trainId) return;
    const detail = await bridge.getTrainDetail(trainId);
    if (!detail.ok) {
      if (detail.error.code === 'not_found') notFound = true;
      else flashError = detail.error.message;
      loading = false;
      return;
    }
    train = detail.value.value;
    if (!preserveHeaderDraft) {
      name = train.name;
      description = train.description ?? '';
      identifiers = train.identifiers.length > 0 ? [...train.identifiers] : [''];
    }
    loading = false;
  }

  async function saveTrain() {
    fieldErrors = {};
    flashError = '';
    savePending = true;
    try {
      const payload = {
        name: name.trim(),
        description: description.trim() === '' ? null : description.trim(),
        identifiers: identifiers.map((identifier) => identifier.trim()).filter((identifier) => identifier !== ''),
      };
      const result = newMode
        ? await bridge.createTrain(payload)
        : trainId
          ? await bridge.updateTrain(trainId, payload)
          : null;
      if (!result) return;
      if (!result.ok) {
        fieldErrors = result.error.field_errors;
        flashError = result.error.message;
        return;
      }
      if (newMode) {
        flash = 'Train created';
        location.hash = `#/trains/${result.value.value.id}`;
      } else {
        train = result.value.value;
        flash = 'Train saved';
      }
    } finally {
      savePending = false;
    }
  }

  function addIdentifier() {
    identifiers.push('');
  }

  function removeIdentifier(index: number) {
    if (identifiers.length <= 1) return;
    identifiers.splice(index, 1);
  }

  function useCurrentTrainId() {
    if (!currentIdentifier) return;
    if (identifiers.includes(currentIdentifier)) return;
    if (identifiers.length === 1 && identifiers[0] === '') identifiers = [currentIdentifier];
    else identifiers.push(currentIdentifier);
  }

  async function addElement() {
    if (!train) return;
    elementErrors = {};
    if (elementName.trim() === '') {
      elementErrors = { name: 'Enter a name for the element.' };
      return;
    }
    elementPending = true;
    try {
      const previousIds = new Set(train.elements.map((candidate) => candidate.id));
      const created = await bridge.createElement(train.id, elementKind, elementName.trim());
      if (!created.ok) {
        elementErrors = created.error.field_errors;
        flashError = created.error.message;
        return;
      }
      train = created.value.value;
      const element = train.elements.find((candidate) => !previousIds.has(candidate.id));
      addElementOpen = false;
      elementName = '';
      elementKind = 'lever';
      if (element?.kind === 'lever') leverWizardElement = element;
    } finally {
      elementPending = false;
    }
  }

  async function deleteElement(id: string) {
    if (!train) return;
    const removed = await bridge.deleteElement(id);
    if (!removed.ok) {
      flashError = removed.error.message;
      return;
    }
    train = removed.value.value;
  }

  async function deleteTrain() {
    if (!trainId || !train || deleteBlocked) return;
    deletePending = true;
    try {
      const removed = await bridge.deleteTrain(trainId);
      if (!removed.ok) {
        flashError = removed.error.message;
        deleteOpen = false;
        return;
      }
      flash = `Train "${train.name}" deleted`;
      location.hash = '/trains';
    } finally {
      deletePending = false;
    }
  }

  function openLeverWizard(element: ElementView) {
    leverWizardElement = element;
  }

  function openButtonWizard(element: ElementView) {
    buttonWizardElement = element;
  }

  function buttonBindingFor(elementId: string): ButtonBindingView | null {
    return bindings.button.find((binding) => binding.element_id === elementId) ?? null;
  }

  function leverBound(leverConfigId: string | null): boolean {
    if (!leverConfigId) return false;
    return bindings.lever.some((binding) => binding.lever_config_id === leverConfigId);
  }

  function leverStatus(element: ElementView): { variant: string; label: string } {
    const config = element.lever_config;
    if (!config) return { variant: 'badge-ghost', label: 'Not configured' };
    if (config.notches.some((notch) => notch.input_min !== null && notch.input_max !== null)) {
      return { variant: 'badge-success', label: 'Ready' };
    }
    if (leverBound(config.id)) return { variant: 'badge-info', label: 'Needs mapping' };
    return { variant: 'badge-warning', label: 'Needs input' };
  }

  function buttonStatus(element: ElementView): { variant: string; label: string } {
    const binding = buttonBindingFor(element.id);
    if (!binding) return { variant: 'badge-ghost', label: 'Not configured' };
    const complete =
      binding.mode === 'sequence'
        ? Boolean(binding.on_sequence_id) || Boolean(binding.off_sequence_id)
        : binding.mode === 'keystroke'
          ? Boolean(binding.keystroke)
          : binding.endpoint !== null;
    return complete ? { variant: 'badge-success', label: 'Ready' } : { variant: 'badge-info', label: 'Partial' };
  }

  function elementStatus(element: ElementView): { variant: string; label: string } {
    if (element.kind === 'lever') return leverStatus(element);
    if (element.kind === 'button') return buttonStatus(element);
    return { variant: 'badge-ghost', label: 'Unknown' };
  }

  function conditionText(binding: OutputBindingView): string {
    switch (binding.operator) {
      case 'eq_true':
        return '= true';
      case 'eq_false':
        return '= false';
      case 'gt':
        return `> ${binding.value_a ?? '—'}`;
      case 'gte':
        return `≥ ${binding.value_a ?? '—'}`;
      case 'lt':
        return `< ${binding.value_a ?? '—'}`;
      case 'lte':
        return `≤ ${binding.value_a ?? '—'}`;
      case 'between':
        return `${binding.value_a ?? '—'} - ${binding.value_b ?? '—'}`;
    }
    return binding.operator;
  }
  function outputLabel(binding: OutputBindingView): string {
    const output = hardware.outputs.find((candidate) => candidate.id === binding.output_id);
    return output ? `${output.device_name} · ${output.name || `Pin ${output.pin}`}` : `Output ${binding.output_id}`;
  }
  function displayLabel(_bindingId: string, moduleId: string): string {
    const display = hardware.displays.find((candidate) => candidate.id === moduleId);
    return display ? `${display.device_name} · ${display.name || `0x${display.i2c_address.toString(16)}`}` : `Display ${moduleId}`;
  }
  function wizardComplete(message: string) {
    leverWizardElement = null;
    buttonWizardElement = null;
    displayWizardBinding = null;
    outputWizardBinding = null;
    flash = message;
    void reloadTrain(true);
    void (async () => {
      const bound = await bridge.getBindings();
      if (bound.ok) bindings = bound.value.value;
    })();
  }

  async function deleteOutputBinding(id: string) {
    const removed = await bridge.deleteOutputBinding(id);
    if (!removed.ok) {
      flashError = removed.error.message;
      return;
    }
    bindings = removed.value.value;
  }

  async function deleteDisplayBinding(id: string) {
    const removed = await bridge.deleteDisplayBinding(id);
    if (!removed.ok) {
      flashError = removed.error.message;
      return;
    }
    bindings = removed.value.value;
  }

  async function toggleScriptEnabled(id: string, enabled: boolean) {
    const updated = await bridge.updateScript(id, { enabled });
    if (!updated.ok) {
      flashError = updated.error.message;
      return;
    }
    scripts = updated.value.value.scripts;
  }

  async function deleteScript(id: string) {
    const removed = await bridge.deleteScript(id);
    if (!removed.ok) {
      flashError = removed.error.message;
      return;
    }
    scripts = removed.value.value.scripts;
  }

  async function refreshAfterSequenceChange() {
    await reloadTrain(true);
  }

  function scrollToSection(event: MouseEvent, id: string) {
    event.preventDefault();
    document.getElementById(id)?.scrollIntoView?.({ behavior: 'smooth', block: 'start' });
  }
</script>

<div class="max-w-2xl mx-auto">
  <nav class="breadcrumbs text-sm" aria-label="Breadcrumb">
    <ul>
      <li><a href="#/trains">Trains</a></li>
      <li>{newMode ? 'New train' : train?.name ?? 'Train'}</li>
    </ul>
  </nav>

  {#if loading}
    <div class="py-16 flex items-center justify-center" role="status">
      <span class="loading loading-spinner loading-lg text-primary"></span>
    </div>
  {:else if notFound}
    <div class="py-16 text-center">
      <h1 class="text-xl font-semibold">Train not found</h1>
      <a href="#/trains" class="link">Back to trains</a>
    </div>
  {:else}
    {#if flash}
      <div role="status" class="alert alert-info mt-6">{flash}</div>
    {/if}
    {#if flashError}
      <div role="alert" class="alert alert-error mt-6">{flashError}</div>
    {/if}

    <header>
      <h1 class="text-2xl font-semibold mb-4">{newMode ? 'New train' : 'Edit train'}</h1>
      <form id="train-form" onsubmit={(event) => { event.preventDefault(); void saveTrain(); }}>
        <div>
          <label class="label" for="train-name"><span class="label-text">Train Name</span></label>
          <input
            id="train-name"
            type="text"
            class="input input-bordered w-full text-lg font-semibold {fieldErrors.name ? 'input-error' : ''}"
            bind:value={name}
            placeholder="e.g., BR Class 66"
            aria-invalid={fieldErrors.name ? 'true' : undefined}
          />
          {#if fieldErrors.name}<p class="text-xs text-error mt-1" role="alert">{fieldErrors.name}</p>{/if}
        </div>
        <div class="mt-3">
          <label class="label" for="train-description"><span class="label-text">Description</span></label>
          <textarea
            id="train-description"
            class="textarea textarea-bordered w-full resize-none"
            bind:value={description}
            placeholder="Add a description (optional)"
            rows="2"
          ></textarea>
        </div>
        <div class="mt-3">
          <h2 class="text-sm font-medium mb-2">Train Identifiers</h2>
          <p id="train-identifiers-hint" class="text-xs text-muted mb-3">
            Use the simulator train ID shown on the Trains page, or connect to use it here. Each entry matches any train ID that starts with that text. Keep the full ID for one variant, or shorten the end to match several variants.
          </p>
          {#if currentIdentifier}
            <div class="mb-3 space-y-2">
              <p class="text-xs text-muted">
                {activityKnown ? 'Current' : 'Last known'} simulator train ID:
                <span class="font-mono break-all">{currentIdentifier}</span>
              </p>
              <button type="button" id="use-current-train-id" class="btn btn-outline btn-sm" disabled={!activityKnown} onclick={useCurrentTrainId}>
                Use current train ID
              </button>
            </div>
          {/if}
          <div class="space-y-2">
            {#each identifiers as identifier, index (index)}
              <div class="flex items-start gap-2">
                <div class="flex-1 min-w-0">
                  <label class="sr-only" for="train-identifier-{index}">Identifier {index + 1}</label>
                  <input
                    id="train-identifier-{index}"
                    type="text"
                    class="input input-bordered w-full font-mono"
                    bind:value={identifiers[index]}
                    aria-describedby="train-identifiers-hint"
                    placeholder="e.g., BR_Class_66"
                    data-testid="train-identifier"
                  />
                </div>
                <button
                  type="button"
                  class="btn btn-ghost btn-sm text-error mt-1 shrink-0"
                  disabled={identifiers.length <= 1}
                  title={identifiers.length <= 1 ? 'Keep at least one identifier' : 'Remove identifier'}
                  aria-label="Remove identifier {index + 1}"
                  onclick={() => removeIdentifier(index)}
                  data-testid="remove-identifier"
                >
                  🗑
                </button>
              </div>
            {/each}
            <button type="button" class="btn btn-ghost btn-sm" onclick={addIdentifier} data-testid="add-identifier">
              + Add identifier
            </button>
            {#if fieldErrors.identifiers}
              <p class="text-sm text-error" role="alert">{fieldErrors.identifiers}</p>
            {/if}
          </div>
        </div>
        <div class="flex items-center gap-3 mt-4">
          {#if isActive}
            <span class="badge badge-success badge-sm gap-1">
              <span class="w-1.5 h-1.5 rounded-full bg-success-content animate-pulse"></span> Active
            </span>
          {:else if !newMode && trainId}
            <button type="button" class="btn btn-outline btn-sm" disabled={activatePending} onclick={() => void activateTrain()} data-testid="set-active-train">
              {activatePending ? 'Activating…' : 'Set Active'}
            </button>
          {/if}
          <button type="submit" class="btn btn-primary btn-sm ml-auto" disabled={savePending} data-testid="save-train">
            {newMode ? 'Create Train' : 'Save'}
          </button>
        </div>
      </form>
    </header>

    {#if !newMode && train}
      <nav aria-label="Train configuration sections" class="flex flex-wrap gap-2 mt-6 border-b border-base-300 pb-3 text-sm">
        <a href="#controls" class="btn btn-ghost btn-sm" onclick={(event) => scrollToSection(event, 'controls')}>Controls</a>
        <a href="#displays-lights" class="btn btn-ghost btn-sm" onclick={(event) => scrollToSection(event, 'displays-lights')}>Displays &amp; lights</a>
        <a href="#automation" class="btn btn-ghost btn-sm" onclick={(event) => scrollToSection(event, 'automation')}>Automation</a>
      </nav>

      <section id="controls" class="scroll-mt-36 mt-6" aria-labelledby="controls-title">
        <h2 id="controls-title" class="text-lg font-semibold mb-3">Controls</h2>
        <div class="bg-base-200/50 rounded-xl p-4 sm:p-6">
          <div class="flex flex-wrap items-center justify-between gap-3 mb-3">
            <h3 class="text-base font-semibold">Elements</h3>
            <button type="button" class="btn btn-outline btn-sm" onclick={() => (addElementOpen = true)} data-testid="add-element">
              + Add Element
            </button>
          </div>

          {#if train.elements.length === 0}
            <div class="py-3 text-sm text-muted">
              <p>No elements configured</p>
              <p class="text-xs mt-1">Add elements to control train functions</p>
            </div>
          {:else}
            <div class="overflow-x-auto">
              <table class="table table-sm bg-base-100 rounded-lg" data-testid="elements-table">
                <thead>
                  <tr class="bg-base-200">
                    <th>Name</th>
                    <th>Type</th>
                    <th>Status</th>
                    <th class="w-24"></th>
                  </tr>
                </thead>
                <tbody>
                  {#each train.elements as element (element.id)}
                    {@const status = elementStatus(element)}
                    <tr class="hover:bg-base-200/50">
                      <td class="font-medium">{element.name}</td>
                      <td><span class="badge badge-ghost badge-sm capitalize">{element.kind}</span></td>
                      <td><span class="badge badge-sm {status.variant}">{status.label}</span></td>
                      <td>
                        <div class="flex gap-1">
                          <button
                            type="button"
                            class="btn btn-ghost btn-xs"
                            title="Configure"
                            aria-label="Configure {element.name}"
                            onclick={() => (element.kind === 'lever' ? openLeverWizard(element) : openButtonWizard(element))}
                            data-testid="configure-element"
                          >
                            ⚙
                          </button>
                          <button
                            type="button"
                            class="btn btn-ghost btn-xs text-error"
                            title="Delete"
                            aria-label="Delete {element.name}"
                            onclick={() => void deleteElement(element.id)}
                            data-testid="delete-element"
                          >
                            🗑
                          </button>
                        </div>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        </div>
      </section>

      <section id="displays-lights" class="scroll-mt-36 mt-8" aria-labelledby="displays-lights-title">
        <h2 id="displays-lights-title" class="text-lg font-semibold mb-3">Displays &amp; lights</h2>
        <div class="bg-base-200/50 rounded-xl p-4 sm:p-6 space-y-6">
          <div>
            <div class="flex flex-wrap items-center justify-between gap-3 mb-3">
              <h3 class="text-base font-semibold">Displays</h3>
              <button
                type="button"
                id="add-display-binding"
                class="btn btn-outline btn-sm"
                disabled={hardware.displays.length === 0}
                aria-describedby="display-prerequisites"
                onclick={() => (displayWizardBinding = 'new')}
              >
                + Add display binding
              </button>
            </div>
            <div id="display-prerequisites" class="text-sm text-muted space-y-2">
              {#if hardwareError}
                <p role="alert">{hardwareError}</p>
              {/if}
              {#if hardware.displays.length === 0}
                <p><a href="#/" class="link">Add a display to a hardware configuration</a> before creating a binding.</p>
              {/if}
            </div>
            {#if trainDisplayBindings.length === 0}
              <p class="text-sm text-muted py-3">
                No display bindings configured. Show simulator values on your hardware displays.
              </p>
            {:else}
              <ul class="divide-y divide-base-300" data-testid="display-bindings-list">
                {#each trainDisplayBindings as binding (binding.id)}
                  <li class="py-4 space-y-3">
                    <div class="min-w-0">
                      <p class="font-medium break-words">{binding.name || 'Display binding'}</p>
                      <p class="text-xs text-muted mt-1 break-words">{displayLabel(binding.id, binding.i2c_module_id)}</p>
                      <p class="font-mono text-xs break-all mt-2">{binding.endpoint}</p>
                      <p class="font-mono text-xs text-muted mt-1">{binding.format_string}</p>
                    </div>
                    <div class="flex flex-wrap gap-2">
                      <button
                        type="button"
                        class="btn btn-ghost btn-sm"
                        aria-label="Edit display binding {binding.name}"
                        onclick={() => (displayWizardBinding = binding)}
                        data-testid="edit-display-binding"
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        class="btn btn-ghost btn-sm text-error"
                        aria-label="Delete display binding {binding.name}"
                        onclick={() => void deleteDisplayBinding(binding.id)}
                        data-testid="delete-display-binding"
                      >
                        Delete
                      </button>
                    </div>
                  </li>
                {/each}
              </ul>
            {/if}
          </div>

          <div class="border-t border-base-300 pt-6">
            <div class="flex flex-wrap items-center justify-between gap-3 mb-3">
              <h3 class="text-base font-semibold">Outputs</h3>
              <button
                type="button"
                class="btn btn-outline btn-sm"
                disabled={hardware.outputs.length === 0}
                onclick={() => (outputWizardBinding = 'new')}
                data-testid="add-output-binding"
              >
                + Add Output Binding
              </button>
            </div>
            {#if hardware.outputs.length === 0}
              <p class="text-sm text-muted">No outputs configured. Add outputs to a device first.</p>
            {/if}
            {#if trainOutputBindings.length === 0}
              <div class="py-3 text-sm text-muted">
                <p>No output bindings configured</p>
                <p class="text-xs mt-1">Bind outputs to API values to control LEDs based on simulator data</p>
              </div>
            {:else}
              <div class="overflow-x-auto">
                <table class="table table-sm bg-base-100 rounded-lg" data-testid="output-bindings-table">
                  <thead>
                    <tr class="bg-base-200">
                      <th>Name</th>
                      <th>Endpoint</th>
                      <th>Condition</th>
                      <th>Output</th>
                      <th class="w-24"></th>
                    </tr>
                  </thead>
                  <tbody>
                    {#each trainOutputBindings as binding (binding.id)}
                      <tr class="hover:bg-base-200/50">
                        <td class="font-medium">{binding.name}</td>
                        <td class="font-mono text-xs max-w-[200px] truncate" title={binding.endpoint}>{binding.endpoint}</td>
                        <td class="text-sm"><span class="font-mono">{conditionText(binding)}</span></td>
                        <td class="text-sm">
                          <span class="badge badge-info badge-sm">{binding.output_type}</span>
                          <span class="text-muted ml-1">{outputLabel(binding)}</span>
                        </td>
                        <td>
                          <div class="flex gap-1">
                            <button
                              type="button"
                              class="btn btn-ghost btn-xs"
                              title="Configure"
                              aria-label="Configure output binding {binding.name}"
                              onclick={() => (outputWizardBinding = binding)}
                              data-testid="edit-output-binding"
                            >
                              ⚙
                            </button>
                            <button
                              type="button"
                              class="btn btn-ghost btn-xs text-error"
                              title="Delete"
                              aria-label="Delete output binding {binding.name}"
                              onclick={() => void deleteOutputBinding(binding.id)}
                              data-testid="delete-output-binding"
                            >
                              🗑
                            </button>
                          </div>
                        </td>
                      </tr>
                    {/each}
                  </tbody>
                </table>
              </div>
            {/if}
          </div>
        </div>
      </section>

      <section id="automation" class="scroll-mt-36 mt-8" aria-labelledby="automation-title">
        <h2 id="automation-title" class="text-lg font-semibold mb-3">Automation</h2>
        <details open={train.sequences.length > 0} class="py-3">
          <summary class="cursor-pointer text-base font-semibold" data-testid="sequences-summary">
            Sequences ({train.sequences.length})
          </summary>
          <SequenceManager bridge={bridge} trainId={train.id} sequences={train.sequences} onChanged={() => void refreshAfterSequenceChange()} />
        </details>
        <div class="bg-base-200/50 rounded-xl p-4 sm:p-6 mt-4">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-base font-semibold">Scripts</h3>
            <a href="#/trains/{train.id}/scripts/new" class="btn btn-outline btn-sm" data-testid="add-script">+ Add Script</a>
          </div>

          {#if trainScripts.length === 0}
            <div class="py-3 text-sm text-muted">
              <p>No scripts configured</p>
              <p class="text-xs mt-1">Add Lua scripts to automate actions based on simulator data</p>
            </div>
          {:else}
            <div class="overflow-x-auto">
              <table class="table table-sm bg-base-100 rounded-lg" data-testid="scripts-table">
                <thead>
                  <tr class="bg-base-200">
                    <th>Name</th>
                    <th>Triggers</th>
                    <th>Enabled</th>
                    <th class="w-24"></th>
                  </tr>
                </thead>
                <tbody>
                  {#each trainScripts as script (script.id)}
                    <tr class="hover:bg-base-200/50">
                      <td class="font-medium">{script.name}</td>
                      <td class="text-sm text-muted">
                        {script.triggers.length} trigger{script.triggers.length !== 1 ? 's' : ''}
                      </td>
                      <td>
                        <input
                          type="checkbox"
                          class="toggle toggle-sm toggle-success"
                          checked={script.enabled}
                          aria-label="Toggle script {script.name}"
                          onchange={() => void toggleScriptEnabled(script.id, !script.enabled)}
                          data-testid="toggle-script-enabled"
                        />
                      </td>
                      <td>
                        <div class="flex gap-1">
                          <a
                            href="#/trains/{train.id}/scripts/{script.id}"
                            class="btn btn-ghost btn-xs"
                            title="Edit"
                            aria-label="Edit script {script.name}"
                            data-testid="edit-script"
                          >
                            ✎
                          </a>
                          <button
                            type="button"
                            class="btn btn-ghost btn-xs text-error"
                            title="Delete"
                            aria-label="Delete script {script.name}"
                            onclick={() => void deleteScript(script.id)}
                            data-testid="delete-script"
                          >
                            🗑
                          </button>
                        </div>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        </div>
      </section>

      <div class="border border-error/30 bg-error/5 rounded-xl p-4 sm:p-6 mt-8">
        <h2 class="text-base font-semibold text-error">Danger zone</h2>
        <p class="text-sm text-muted mt-1">
          Permanently remove this train and all associated elements and calibration data
        </p>
        <button
          type="button"
          class="btn btn-error btn-sm mt-4"
          disabled={deleteBlocked}
          title={isActive ? 'Cannot delete while train is currently active' : !activityKnown ? 'Cannot confirm simulator train activity' : 'Delete Train'}
          onclick={() => (deleteOpen = true)}
          data-testid="delete-train"
        >
          Delete Train
        </button>
        {#if isActive}
          <p class="text-xs text-warning mt-2">Cannot delete while train is currently active</p>
        {:else if !activityKnown}
          <p class="text-xs text-warning mt-2">Cannot delete until simulator train activity is known.</p>
        {/if}
      </div>
    {/if}
  {/if}
</div>

{#if addElementOpen}
  <div class="fixed inset-0 z-50 flex items-center justify-center" role="dialog" aria-modal="true" aria-labelledby="add-element-title">
    <div class="absolute inset-0 bg-black/50" onclick={() => (addElementOpen = false)} aria-hidden="true"></div>
    <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-md mx-4 p-6">
      <h2 id="add-element-title" class="text-xl font-semibold mb-4">Add Element</h2>
      <form
        id="add-element-form"
        onsubmit={(event) => {
          event.preventDefault();
          void addElement();
        }}
      >
        <div class="space-y-4">
          <div>
            <label class="label" for="element-name"><span class="label-text">Element Name</span></label>
            <input
              id="element-name"
              type="text"
              class="input input-bordered w-full {elementErrors.name ? 'input-error' : ''}"
              bind:value={elementName}
              placeholder="e.g., Throttle, Reverser"
              data-testid="element-name"
            />
            {#if elementErrors.name}<p class="text-xs text-error mt-1" role="alert">{elementErrors.name}</p>{/if}
          </div>
          <div>
            <label class="label" for="element-kind"><span class="label-text">Type</span></label>
            <select id="element-kind" class="select select-bordered w-full" bind:value={elementKind} data-testid="element-kind">
              <option value="lever">Lever</option>
              <option value="button">Button</option>
            </select>
            <p class="text-xs text-muted mt-1">Lever for analog inputs, Button for digital inputs</p>
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button type="button" class="btn btn-ghost" onclick={() => (addElementOpen = false)}>Cancel</button>
          <button type="submit" class="btn btn-primary" disabled={elementPending} data-testid="confirm-add-element">
            {elementPending ? 'Adding…' : 'Add Element'}
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}

{#if deleteOpen && train}
  <div class="fixed inset-0 z-50 grid place-items-center bg-black/50 px-4" role="dialog" aria-modal="true" aria-labelledby="delete-train-title">
    <div class="w-full max-w-md rounded-xl bg-base-100 p-6 shadow-xl">
      <h2 id="delete-train-title" class="text-lg font-semibold">Delete Train</h2>
      <p class="mt-3 text-sm">This will permanently delete "{train.name}" and all its elements and calibration data.</p>
        {#if isActive}
        <p class="mt-2 text-sm text-warning">This train is currently active in the simulator.</p>
        {:else if !activityKnown}
          <p class="mt-2 text-sm text-warning">Simulator train activity is unavailable. Deletion is paused.</p>
      {/if}
      <div class="mt-6 flex justify-end gap-2">
        <button type="button" class="btn btn-ghost" onclick={() => (deleteOpen = false)} data-testid="cancel-delete-train">Cancel</button>
        <button
          type="button"
          class="btn btn-error"
          disabled={deletePending || deleteBlocked}
          onclick={() => void deleteTrain()}
          data-testid="confirm-delete-train"
        >
          {deletePending ? 'Deleting…' : 'Delete'}
        </button>
      </div>
    </div>
  </div>
{/if}

{#if leverWizardElement && train}
  <LeverSetupWizard
    bridge={bridge}
    element={leverWizardElement}
    hardware={hardware}
    initialInputId={bindings.lever.find((binding) => binding.lever_config_id === leverWizardElement?.lever_config?.id)?.input_id ?? null}
    onClose={() => (leverWizardElement = null)}
    onComplete={wizardComplete}
  />
{/if}

{#if buttonWizardElement}
  <ButtonBindingWizard
    bridge={bridge}
    element={buttonWizardElement}
    hardware={hardware}
    sequences={train?.sequences ?? []}
    existingBinding={buttonBindingFor(buttonWizardElement.id)}
    onClose={() => (buttonWizardElement = null)}
    onComplete={wizardComplete}
  />
{/if}

{#if displayWizardBinding && train}
  <DisplayBindingWizard
    bridge={bridge}
    trainId={train.id}
    hardware={hardware}
    existingBinding={displayWizardBinding === 'new' ? null : displayWizardBinding}
    onClose={() => (displayWizardBinding = null)}
    onComplete={wizardComplete}
  />
{/if}

{#if outputWizardBinding && train}
  <OutputBindingWizard
    bridge={bridge}
    trainId={train.id}
    hardware={hardware}
    existingBinding={outputWizardBinding === 'new' ? null : outputWizardBinding}
    onClose={() => (outputWizardBinding = null)}
    onComplete={wizardComplete}
  />
{/if}
