<script lang="ts">
  import { onMount } from 'svelte';
  import type { ScriptsView, TrainDetailView } from '../../../bridge/generated';
  import type { UiBridge } from '../../../bridge/client';
  import type { Route } from '../../../bridge/route';
  import { collectHardware, EMPTY_HARDWARE_CATALOG, type HardwareCatalog } from '../../hardware';
  import EndpointBrowser from '../../../components/EndpointBrowser.svelte';

  let { bridge, route }: { bridge: UiBridge; route: Route } = $props();

  const newMode = $derived(route.page === 'script-new');
  const trainId = $derived(route.page === 'script' || route.page === 'script-new' ? route.trainId : '');
  const scriptId = $derived(route.page === 'script' ? route.scriptId : null);

  const DEFAULT_CODE = `function on_change(event)
  -- event.source: trigger endpoint path, "scheduled", or "manual"
  -- event.value: current value of the trigger
  -- event.data: full data table from subscription
  print("triggered by: " .. tostring(event.source))
end`;

  let loading = $state(true);
  let notFound = $state(false);
  let flash = $state('');
  let flashError = $state('');

  let train = $state<TrainDetailView | null>(null);
  let scriptName = $state('');
  let code = $state(DEFAULT_CODE);
  let triggers = $state<string[]>([]);
  let newTrigger = $state('');
  let enabled = $state(false);
  let fieldErrors = $state<Record<string, string>>({});
  let savePending = $state(false);
  let showOutputs = $state(false);
  let hardware = $state<HardwareCatalog>(EMPTY_HARDWARE_CATALOG);
  let consoleLines = $state<string[]>([]);
  let runPending = $state(false);
  let logPending = $state(false);
  let logTimer: ReturnType<typeof setTimeout> | undefined;

  onMount(() => {
    void (async () => {
      const detail = await bridge.getTrainDetail(trainId);
      if (!detail.ok) {
        notFound = true;
        loading = false;
        return;
      }
      train = detail.value.value;
      if (scriptId) {
        const scripts = await bridge.getScripts();
        if (!scripts.ok) {
          flashError = scripts.error.message;
          loading = false;
          return;
        }
        const script = scripts.value.value.scripts.find((candidate) => candidate.id === scriptId);
        if (!script || script.train_id !== trainId) {
          notFound = true;
          loading = false;
          return;
        }
        scriptName = script.name;
        code = script.code;
        triggers = [...script.triggers];
        enabled = script.enabled;
        await refreshLog();
      }
      const collected = await collectHardware(bridge);
      hardware = collected.catalog;
      loading = false;
    })();
    return () => { if (logTimer) clearTimeout(logTimer); };
  });

  async function refreshLog() {
    if (!scriptId || logPending) return;
    logPending = true;
    const result = await bridge.getScriptLog(scriptId);
    logPending = false;
    if (result.ok) consoleLines = result.value.slice(-200).map((line) => line.slice(0, 500));
    else flashError = result.error.message;
  }

  async function runSavedScript() {
    if (!scriptId || runPending) return;
    runPending = true;
    flash = '';
    flashError = '';
    const result = await bridge.runScript(scriptId);
    runPending = false;
    if (!result.ok) {
      flashError = result.error.message;
      return;
    }
    if (!result.value) {
      flashError = 'Saved script is unavailable. Enable it and check its code, then try again.';
      return;
    }
    flash = 'Saved script triggered';
    if (logTimer) clearTimeout(logTimer);
    logTimer = setTimeout(() => void refreshLog(), 300);
  }

  function addTrigger() {
    const trigger = newTrigger.trim();
    newTrigger = '';
    if (trigger === '' || triggers.includes(trigger)) return;
    triggers.push(trigger);
  }

  function removeTrigger(index: number) {
    triggers.splice(index, 1);
  }

  async function toggleEnabled() {
    if (newMode || !scriptId) return;
    const updated = await bridge.updateScript(scriptId, { enabled: !enabled });
    if (!updated.ok) {
      flashError = updated.error.message;
      return;
    }
    enabled = !enabled;
    flash = enabled ? 'Script enabled' : 'Script disabled';
    const reloaded = await bridge.reloadScripts();
    if (!reloaded.ok) flashError = reloaded.error.message;
  }

  async function save() {
    fieldErrors = {};
    flashError = '';
    if (scriptName.trim() === '') {
      fieldErrors = { name: 'Enter a script name.' };
      return;
    }
    savePending = true;
    try {
      if (newMode) {
        const created = await bridge.createScript(trainId, scriptName.trim(), code, triggers);
        if (!created.ok) {
          fieldErrors = created.error.field_errors;
          flashError = created.error.message;
          return;
        }
        const reloaded = await bridge.reloadScripts();
        if (!reloaded.ok) {
          flashError = reloaded.error.message;
          return;
        }
        flash = 'Script created';
        const createdScript = created.value.value.scripts.find((script) => script.train_id === trainId && script.name === scriptName.trim());
        location.hash = `#/trains/${trainId}/scripts/${createdScript?.id ?? ''}`;
      } else if (scriptId) {
        const updated = await bridge.updateScript(scriptId, {
          name: scriptName.trim(),
          code,
          triggers,
          enabled,
        });
        if (!updated.ok) {
          fieldErrors = updated.error.field_errors;
          flashError = updated.error.message;
          return;
        }
        const reloaded = await bridge.reloadScripts();
        if (!reloaded.ok) {
          flashError = reloaded.error.message;
          return;
        }
        flash = 'Script saved';
      }
    } finally {
      savePending = false;
    }
  }
</script>

<div class="max-w-4xl mx-auto">
  <nav class="breadcrumbs text-sm" aria-label="Breadcrumb">
    <ul>
      <li><a href="#/trains">Trains</a></li>
      <li><a href="#/trains/{trainId}">{train?.name ?? 'Train'}</a></li>
      <li>{newMode ? 'New Script' : scriptName || 'Script'}</li>
    </ul>
  </nav>

  {#if loading}
    <div class="py-16 flex items-center justify-center" role="status">
      <span class="loading loading-spinner loading-lg text-primary"></span>
    </div>
  {:else if notFound}
    <div class="py-16 text-center">
      <h1 class="text-xl font-semibold">Not found</h1>
      <a href="#/trains" class="link">Back to trains</a>
    </div>
  {:else}
    {#if flash}
      <div role="status" class="alert alert-info mt-6">{flash}</div>
    {/if}
    {#if flashError}
      <div role="alert" class="alert alert-error mt-6">{flashError}</div>
    {/if}

    <form class="mt-6" onsubmit={(event) => { event.preventDefault(); void save(); }}>
      <div class="flex items-center gap-3 mb-6">
        <div class="flex-1">
          <label class="sr-only" for="script-name">Script name</label>
          <input
            id="script-name"
            type="text"
            class="input input-bordered w-full text-lg font-semibold {fieldErrors.name ? 'input-error' : ''}"
            bind:value={scriptName}
            placeholder="Script name"
            data-testid="script-name"
          />
          {#if fieldErrors.name}<p class="text-xs text-error mt-1" role="alert">{fieldErrors.name}</p>{/if}
        </div>

        {#if !newMode}
          <label class="label cursor-pointer gap-2">
            <span class="text-sm font-medium {enabled ? 'text-success' : 'text-muted'}">
              {enabled ? 'Enabled' : 'Disabled'}
            </span>
            <input
              type="checkbox"
              class="toggle toggle-sm toggle-success"
              checked={enabled}
              onchange={() => void toggleEnabled()}
              data-testid="script-enabled-toggle"
            />
          </label>
        {/if}

        {#if !newMode}
          <button type="button" class="btn btn-outline btn-sm" disabled={runPending} onclick={() => void runSavedScript()} data-testid="run-script">{runPending ? 'Running…' : 'Run Now'}</button>
        {/if}
        <button type="submit" class="btn btn-primary btn-sm" disabled={savePending} data-testid="save-script">
          {newMode ? 'Create' : 'Save'}
        </button>

        <a href="#/trains/{trainId}" class="btn btn-ghost btn-sm">Back</a>
      </div>

      <div class="bg-base-200/50 rounded-xl p-4 mb-4">
        <h3 class="text-sm font-semibold text-muted mb-2">Lua Code</h3>
        <label class="sr-only" for="script-code">Lua code</label>
        <textarea
          id="script-code"
          rows="18"
          spellcheck="false"
          class="w-full font-mono text-sm leading-relaxed p-4 rounded-lg bg-base-300 text-base-content border border-base-content/10 focus:border-primary/50 focus:outline-none resize-y min-h-[200px]"
          bind:value={code}
          data-testid="script-code"
        ></textarea>
      </div>
    </form>

    <div class="bg-base-200/50 rounded-xl p-4 mb-4">
      <h3 class="text-sm font-semibold text-muted mb-3">
        Triggers
        <span class="text-xs font-normal text-base-content/40 ml-1">
          Simulator endpoints that fire on_change when their value changes
        </span>
      </h3>

      <div class="flex flex-wrap gap-2 mb-3">
        {#each triggers as trigger, index (trigger)}
          <div class="flex items-center gap-1 bg-base-300 rounded-lg px-3 py-1.5">
            <span class="font-mono text-xs">{trigger}</span>
            <button
              type="button"
              class="text-base-content/40 hover:text-error ml-1"
              title="Remove trigger"
              aria-label="Remove trigger {trigger}"
              onclick={() => removeTrigger(index)}
              data-testid="remove-trigger"
            >
              ✕
            </button>
          </div>
        {/each}

        {#if triggers.length === 0}
          <div class="text-sm text-base-content/40 py-1">
            No triggers added. Script will only run when triggered manually.
          </div>
        {/if}
      </div>

      <form
        id="add-trigger-form"
        class="flex gap-2"
        onsubmit={(event) => {
          event.preventDefault();
          addTrigger();
        }}
      >
        <label class="sr-only" for="new-trigger">New trigger</label>
        <input
          id="new-trigger"
          type="text"
          class="flex-1 input input-bordered input-sm font-mono text-xs bg-base-100"
          bind:value={newTrigger}
          placeholder="e.g. CurrentDrivableActor/Throttle.InputValue"
          data-testid="new-trigger"
        />
        <button type="submit" class="btn btn-outline btn-sm" data-testid="add-trigger">+ Add</button>
      </form>
      <EndpointBrowser {bridge} onSelect={(path) => (newTrigger = path)} />
    </div>

    {#if !newMode}
      <div class="bg-base-200/50 rounded-xl p-4 mb-4">
        <div class="flex items-center justify-between mb-2">
          <h3 class="text-sm font-semibold text-muted">Console</h3>
          <button type="button" class="btn btn-ghost btn-xs" disabled={logPending} onclick={() => void refreshLog()} data-testid="refresh-script-log">Refresh</button>
        </div>
        <div id="script-console" class="font-mono text-xs leading-relaxed p-3 rounded-lg bg-base-300 text-base-content/80 h-40 overflow-y-auto">
          {#if consoleLines.length === 0}
            <span class="text-base-content/30">No log output yet. Run the script to see output.</span>
          {:else}
            {#each consoleLines as line}<div class="whitespace-pre-wrap break-words">{line}</div>{/each}
          {/if}
        </div>
      </div>
    {/if}

    <div class="bg-base-200/50 rounded-xl p-4 mb-4">
      <button type="button" class="flex items-center justify-between w-full" onclick={() => (showOutputs = !showOutputs)} aria-expanded={showOutputs} data-testid="toggle-outputs">
        <h3 class="text-sm font-semibold text-muted">
          Hardware Outputs Reference
          <span class="text-xs font-normal text-base-content/40 ml-1">Use output.set(id, true/false) in your script</span>
        </h3>
        <span class="text-base-content/40">{showOutputs ? '▲' : '▼'}</span>
      </button>

      {#if showOutputs}
        <div class="mt-3">
          {#if hardware.outputs.length === 0}
            <p class="text-sm text-base-content/40">No hardware outputs configured.</p>
          {:else}
            <div class="overflow-x-auto">
              <table class="table table-xs bg-base-100 rounded-lg" data-testid="outputs-reference">
                <thead>
                  <tr class="bg-base-200 text-xs">
                    <th>ID</th>
                    <th>Name</th>
                    <th>Pin</th>
                    <th>Device</th>
                  </tr>
                </thead>
                <tbody>
                  {#each hardware.outputs as output (output.id)}
                    <tr class="text-xs">
                      <td class="font-mono">{output.id}</td>
                      <td>{output.name || '-'}</td>
                      <td class="font-mono">{output.pin}</td>
                      <td class="text-muted">{output.device_name}</td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        </div>
      {/if}
    </div>
  {/if}
</div>
