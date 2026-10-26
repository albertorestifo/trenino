<script lang="ts">
  import { onMount } from 'svelte';
  import Navigation from './Navigation.svelte';
  import EmptyState from '../components/EmptyState.svelte';
  import Unavailable from '../components/Unavailable.svelte';
  import { bridge as productionBridge, type FirmwareUpdateStatus, type Result, type SerialPortView, type SimulatorRuntimeStatus, type UiBridge } from '../bridge/client';
  import ConfigurationEdit from './pages/configuration/ConfigurationEdit.svelte';
  import SettingsEdit from './pages/settings/SettingsEdit.svelte';
  import TrainEdit from './pages/trains/TrainEdit.svelte';
  import ScriptEdit from './pages/scripts/ScriptEdit.svelte';
  import Firmware from './pages/firmware/Firmware.svelte';
  import VirtualJoystick from './pages/virtual-joystick/VirtualJoystick.svelte';
  import { parseRoute, routeHref, type Route } from '../bridge/route';
  import type { ConfigurationSummaryView, SettingsView, TrainSummaryView, UiSnapshot } from '../bridge/generated';

  let { bridge: injectedBridge }: { bridge?: UiBridge } = $props();
  const api = () => injectedBridge ?? productionBridge;

  let route = $state<Route>(parseRoute(location.hash));
  let gateStatus = $state<'checking' | 'ready' | 'unavailable' | 'needs-consent'>('checking');
  let gateError = $state('');
  let configurationError = $state('');
  let trainsError = $state('');
  let consentError = $state('');
  let settings = $state<UiSnapshot<SettingsView> | undefined>();
  let configurations = $state<UiSnapshot<ConfigurationSummaryView[]> | undefined>();
  let trains = $state<UiSnapshot<TrainSummaryView[]> | undefined>();
  let consentPending = $state(false);
  let mounted = false;
  let routeGeneration = 0;

  async function updateRoute() {
    route = parseRoute(location.hash);
    const requestedHash = location.hash;
    const generation = ++routeGeneration;
    consentPending = false;
    consentError = '';
    configurationError = '';
    trainsError = '';

    if (route.page === 'consent') return;

    gateStatus = 'checking';
    gateError = '';
    const bootstrap = await safeRequest(api().getSettings());
    if (!isCurrent(generation, requestedHash)) return;
    if (!bootstrap.ok) {
      gateStatus = 'unavailable';
      gateError = bootstrap.error.message;
      return;
    }

    settings = bootstrap.value;
    if (bootstrap.value.value.error_reporting === 'unset') {
      gateStatus = 'needs-consent';
      location.hash = '/consent';
      return;
    }
    gateStatus = 'ready';
    void refreshPorts();
    void refreshSimulator();
    void refreshFirmwareUpdate();

    if (route.page === 'configurations') {
      void loadForRoute(api().getConfigurations(), generation, requestedHash, (value) => (configurations = value), (message) => (configurationError = message));
    } else if (route.page === 'trains') {
      void loadForRoute(api().getTrains(), generation, requestedHash, (value) => (trains = value), (message) => (trainsError = message));
    }
  }

  function isCurrent(generation: number, requestedHash: string): boolean {
    return mounted && routeGeneration === generation && location.hash === requestedHash;
  }

  async function safeRequest<T>(request: Promise<Result<T>>): Promise<Result<T>> {
    try {
      return await request;
    } catch {
      return { ok: false, error: { code: 'unavailable', message: 'The Rust service is not available yet.', field_errors: {}, retryable: true } };
    }
  }

  async function loadForRoute<T>(request: Promise<Result<T>>, generation: number, requestedHash: string, accept: (value: T) => void, showError: (message: string) => void) {
    const result = await safeRequest(request);
    if (!isCurrent(generation, requestedHash)) return;
    if (result.ok) {
      accept(result.value);
    } else {
      showError(result.error.message);
    }
  }

  async function setConsent(value: 'enabled' | 'disabled') {
    const generation = routeGeneration;
    const requestedHash = location.hash;
    consentPending = true;
    consentError = '';
    const result = await safeRequest(api().setConsent(value));
    if (!isCurrent(generation, requestedHash) || route.page !== 'consent') return;
    consentPending = false;
    if (result.ok) {
      settings = result.value;
      location.hash = '/';
    } else {
      consentError = result.error.message;
    }
  }


  let serialPorts = $state<SerialPortView[]>([]);
  let serialError = $state('');
  let scanPending = $state(false);
  let selectedPorts = $state<Record<number, { port: string; generation: number }>>({});
  let hardwareInputValues = $state<Record<string, Record<number, number>>>({});
  let applyOperations = $state<Record<number, { id: string; state: 'pending' | 'complete' | 'failed'; message: string | null }>>({});
  let disconnectPending = $state<string | null>(null);
  let inventorySequence = 0;
  const statusInFlight = new Set<string>();
  let simulatorStatus = $state<SimulatorRuntimeStatus | null>(null);
  let simulatorError = $state('');
  let simulatorRetryPending = $state(false);
  let simulatorSequence = 0;
  let firmwareUpdateStatus = $state<FirmwareUpdateStatus | null>(null);
  let firmwareStatusError = $state('');
  let firmwareActionError = $state('');
  let firmwareCheckPending = $state(false);
  let firmwareDismissPending = $state(false);
  let firmwareSequence = 0;
  let hardwareDetectionPrompt = $state<string | null>(null);
  let activatingTrainId = $state<string | null>(null);
  let activateTrainError = $state('');

  async function activateTrain(trainId: string) {
    if (activatingTrainId !== null) return;
    activatingTrainId = trainId;
    activateTrainError = '';
    const result = await api().activateTrain(trainId);
    if (!mounted) return;
    activatingTrainId = null;
    if (!result.ok) {
      activateTrainError = result.error ?? 'Failed to activate the train.';
      return;
    }
    await refreshSimulator();
    if (route.page === 'trains') {
      const updated = await safeRequest(api().getTrains());
      if (mounted && updated.ok) trains = updated.value;
    }
  }

  async function refreshFirmwareUpdate() {
    if (firmwareDismissPending) return;
    const sequence = ++firmwareSequence;
    const result = await safeRequest(api().firmwareUpdateStatus());
    if (!mounted || sequence !== firmwareSequence) return;
    if (result.ok) {
      firmwareUpdateStatus = result.value;
      firmwareStatusError = '';
    } else firmwareStatusError = result.error.message;
  }

  async function checkFirmwareUpdates() {
    if (firmwareCheckPending || firmwareUpdateStatus?.checking) return;
    firmwareCheckPending = true;
    firmwareActionError = '';
    const result = await safeRequest(api().checkFirmwareUpdates());
    if (!mounted) return;
    if (!result.ok) firmwareActionError = result.error.message;
    await refreshFirmwareUpdate();
    if (mounted) firmwareCheckPending = false;
  }

  async function dismissFirmwareUpdate() {
    if (firmwareDismissPending || !firmwareUpdateStatus?.notice) return;
    firmwareDismissPending = true;
    firmwareActionError = '';
    firmwareSequence += 1;
    const result = await safeRequest(api().dismissFirmwareUpdate());
    if (!mounted) return;
    if (result.ok) firmwareUpdateStatus = result.value;
    else firmwareActionError = result.error.message;
    firmwareDismissPending = false;
  }

  async function refreshSimulator() {
    const sequence = ++simulatorSequence;
    const result = await safeRequest(api().getSimulatorStatus());
    if (!mounted || sequence !== simulatorSequence) return;
    if (result.ok) { simulatorStatus = result.value; simulatorError = ''; }
    else simulatorError = result.error.message;
  }

  async function retrySimulator() {
    simulatorRetryPending = true;
    simulatorError = 'Refreshing simulator status…';
    const result = await safeRequest(api().retrySimulator());
    if (!result.ok) simulatorError = result.error.message;
    await refreshSimulator();
    simulatorRetryPending = false;
  }

  function portKey(port: string, generation: number, configId: number): string {
    return `${port}\u0000${generation}\u0000${configId}`;
  }

  function connectedFor(configId: number): SerialPortView | undefined {
    return serialPorts.find((entry) => entry.status === 'connected' && entry.config_id === configId && entry.generation !== null);
  }

  function selectApplyPort(configId: number, portName: string) {
    const entry = serialPorts.find((port) => port.port === portName && port.status === 'connected' && port.generation !== null);
    if (entry) selectedPorts = { ...selectedPorts, [configId]: { port: entry.port, generation: entry.generation! } };
    else {
      const next = { ...selectedPorts };
      delete next[configId];
      selectedPorts = next;
    }
  }

  async function refreshPorts() {
    const sequence = ++inventorySequence;
    const result = await safeRequest(api().serialPorts());
    if (!mounted || sequence !== inventorySequence) return;
    if (!result.ok) { serialError = result.error.message; serialPorts = []; hardwareInputValues = {}; return; }
    serialError = '';
    serialPorts = result.value;
    selectedPorts = Object.fromEntries(Object.entries(selectedPorts).filter(([, selected]) =>
      result.value.some((entry) => entry.port === selected.port && entry.status === 'connected' && entry.generation === selected.generation)));
    const liveKeys = new Set(result.value.filter((entry) => entry.status === 'connected' && entry.config_id !== null && entry.generation !== null)
      .map((entry) => portKey(entry.port, entry.generation!, entry.config_id!)));
    hardwareInputValues = Object.fromEntries(Object.entries(hardwareInputValues).filter(([key]) => liveKeys.has(key)));
  }

  async function scanDevices() {
    scanPending = true;
    serialError = '';
    const result = await safeRequest(api().scanDevices());
    scanPending = false;
    if (!result.ok) serialError = result.error.message;
    else await refreshPorts();
  }

  async function applyConfiguration(config: ConfigurationSummaryView) {
    const selected = selectedPorts[config.config_id];
    const port = serialPorts.find((entry) => entry.port === selected?.port && entry.status === 'connected' && entry.generation === selected?.generation);
    if (!port || port.generation === null) { serialError = 'Select the current device connection before applying the configuration.'; return; }
    serialError = '';
    const begun = await safeRequest(api().beginApplyConfiguration(config.device_id, port.port, port.generation));
    if (!begun.ok) { serialError = begun.error.message; return; }
    applyOperations = { ...applyOperations, [config.config_id]: { id: begun.value.operation_id, state: 'pending', message: null } };
  }

  async function pollApplyOperations() {
    for (const [configIdText, operation] of Object.entries(applyOperations)) {
      if (operation.state !== 'pending' || statusInFlight.has(operation.id)) continue;
      statusInFlight.add(operation.id);
      const configId = Number(configIdText);
      const result = await safeRequest(api().configurationStatus(operation.id));
      statusInFlight.delete(operation.id);
      if (!mounted) return;
      if (applyOperations[configId]?.id !== operation.id) continue;
      if (!result.ok) {
        applyOperations = { ...applyOperations, [configId]: { ...operation, message: `Status unavailable: ${result.error.message}. Retrying…` } };
      } else {
        applyOperations = { ...applyOperations, [configId]: { ...operation, ...result.value } };
        if (result.value.state === 'complete') {
          const updated = await safeRequest(api().getConfigurations());
          if (updated.ok) configurations = updated.value;
          await refreshPorts();
        }
      }
    }
  }

  async function disconnectPort(entry: SerialPortView) {
    if (entry.generation === null) return;
    disconnectPending = entry.port;
    serialError = '';
    const result = await safeRequest(api().disconnectDevice(entry.port, entry.generation));
    disconnectPending = null;
    if (!result.ok) serialError = result.error.message;
    await refreshPorts();
  }

  const activeBridge = $derived(injectedBridge ?? productionBridge);

  onMount(() => {
    let disposed = false;
    void api()
      .subscribe<ConfigurationSummaryView[]>('hardware', (snapshot) => {
        if (route.page === 'configurations') configurations = snapshot;
      }, () => {})
      .then((stop) => {
        if (disposed) stop();
        else unsubscribeHardware = stop;
      });
    let unsubscribeHardware: (() => void) | null = null;
    const stopInput = api().onHardwareInput((event) => {
      if (!serialPorts.some((entry) => entry.status === 'connected' && entry.port === event.port && entry.generation === event.port_generation && entry.config_id === event.config_id)) return;
      const key = portKey(event.port, event.port_generation, event.config_id);
      hardwareInputValues = { ...hardwareInputValues, [key]: { ...hardwareInputValues[key], [event.pin]: event.value } };
    });
    const stopDetection = api().onHardwareDetection((event) => {
      hardwareDetectionPrompt = event.prompt;
    });
    const inventoryTimer = setInterval(() => { if (gateStatus === 'ready') void refreshPorts(); }, 2000);
    const simulatorTimer = setInterval(() => { if (gateStatus === 'ready') void refreshSimulator(); }, 2000);
    const firmwareTimer = setInterval(() => { if (gateStatus === 'ready') void refreshFirmwareUpdate(); }, 2000);
    const operationTimer = setInterval(() => { if (gateStatus === 'ready') void pollApplyOperations(); }, 1000);
    return () => {
      disposed = true;
      inventorySequence += 1;
      simulatorSequence += 1;
      firmwareSequence += 1;
      unsubscribeHardware?.();
      stopInput();
      stopDetection();
      clearInterval(inventoryTimer);
      clearInterval(simulatorTimer);
      clearInterval(firmwareTimer);
      clearInterval(operationTimer);
    };
  });

  const activeConfigurationCount = $derived(serialPorts.filter((entry) => entry.status === 'connected' && entry.config_id !== null).length);
  onMount(() => {
    mounted = true;
    window.addEventListener('hashchange', updateRoute);
    updateRoute();
    return () => {
      mounted = false;
      routeGeneration += 1;
      window.removeEventListener('hashchange', updateRoute);
    };
  });

  function title(page: Route['page']): string {
    if (page === 'configuration') return 'Configuration';
    if (page === 'configuration-new') return 'New Configuration';
    if (page === 'train') return 'Train';
    if (page === 'train-new') return 'New Train';
    if (page === 'script' || page === 'script-new') return 'Script';
    if (page === 'firmware') return 'Firmware';
    if (page === 'joystick') return 'Virtual Joystick';
    return 'Unavailable';
  }

  function unavailableMessage(current: Route): string {
    return `No screen is registered for ${current.path}.`;
  }

  async function settingsConsent(value: 'enabled' | 'disabled'): Promise<string | null> {
    const result = await safeRequest(api().setConsent(value));
    if (result.ok) {
      settings = result.value;
      return null;
    }
    return result.error.message;
  }
</script>

<svelte:head>
  <title>{route.page === 'settings' ? 'Settings' : route.page === 'consent' ? 'Consent' : route.page === 'trains' ? 'Trains' : 'Configurations'} · Trenino</title>
</svelte:head>

{#if route.page === 'consent'}
  <main class="consent-layout">
    <section class="card w-full max-w-md bg-base-100 shadow-xl" aria-labelledby="consent-title">
      <div class="card-body items-center text-center">
        <div class="mb-2 rounded-full bg-primary/10 p-3 text-3xl text-primary" aria-hidden="true">◈</div>
        <h1 id="consent-title" class="card-title text-lg">Help improve Trenino</h1>
        <p class="text-sm text-muted">Share anonymous error reports so bugs can be found and fixed faster. No personal data, no usage tracking — only crash reports.</p>
        {#if consentError}<p role="alert" class="mt-3 text-sm text-error">{consentError}</p>{/if}
        <div class="mt-4 flex w-full flex-col gap-2">
          <button class="btn btn-primary w-full" disabled={consentPending} onclick={() => void setConsent('enabled')}>Share error reports</button>
          <button class="btn btn-ghost w-full" disabled={consentPending} onclick={() => void setConsent('disabled')}>No thanks</button>
        </div>
        <a class="mt-3 text-sm text-muted underline" href="#/settings">Back to Settings</a>
      </div>
    </section>
  </main>
{:else if gateStatus === 'checking'}
  <main class="consent-layout" role="status"><section class="card w-full max-w-md bg-base-100 shadow-xl"><div class="card-body items-center text-center"><h1 class="card-title text-lg">Checking consent preference</h1><p class="text-sm text-muted">Trenino is checking your saved privacy choice before opening the app.</p></div></section></main>
{:else if gateStatus === 'unavailable'}
  <main class="consent-layout">
    <section class="card w-full max-w-md bg-base-100 shadow-xl"><div class="card-body items-center text-center"><h1 class="card-title text-lg">Consent status unavailable</h1><p class="text-sm text-muted">Trenino cannot verify your saved privacy choice, so the rest of the app is paused.</p><p role="alert" class="text-sm text-error">{gateError}</p><button class="btn btn-primary w-full" onclick={() => void updateRoute()}>Retry consent check</button><a class="text-sm text-muted underline" href="#/consent">Open consent choices</a></div></section>
  </main>
{:else if gateStatus === 'needs-consent'}
  <main class="consent-layout" role="status"><section class="card w-full max-w-md bg-base-100 shadow-xl"><div class="card-body items-center text-center"><h1 class="card-title text-lg">Opening consent choices</h1><p class="text-sm text-muted">Choose whether Trenino may share anonymous error reports.</p></div></section></main>
{:else}
  <div class="min-h-screen bg-base-200 text-base-content">
    <Navigation {route} connectedCount={activeConfigurationCount} simulatorStatus={simulatorStatus} simulatorError={simulatorError} retryPending={simulatorRetryPending} onRetry={() => void retrySimulator()}
      {firmwareUpdateStatus} {firmwareStatusError} {firmwareActionError} {firmwareCheckPending} {firmwareDismissPending}
      onFirmwareCheck={() => void checkFirmwareUpdates()} onFirmwareDismiss={() => void dismissFirmwareUpdate()} />
    <main class="flex-1 px-4 py-8 sm:px-8">
      {#if route.page === 'settings'}
        <div class="mx-auto max-w-2xl">
          {#if settings}
            <SettingsEdit bridge={activeBridge} settings={settings.value} onConsent={settingsConsent} />
          {:else}
            <header class="mb-10"><h1 class="text-2xl font-semibold">Settings</h1></header>
            <Unavailable message="Settings are unavailable until the Rust service is connected." />
          {/if}
        </div>
      {:else if route.page === 'configurations'}
        <div class="mx-auto max-w-2xl">
          <header class="mb-8 flex items-center justify-between gap-4">
            <div><h1 class="text-2xl font-semibold">Configurations</h1><p class="mt-1 text-sm text-muted">Manage device configurations</p></div>
            <a class="btn btn-primary" href="#/configurations/new">＋ New Configuration</a>
          </header>
          <section class="mb-6 rounded-xl border border-base-300 bg-base-100 p-4" aria-labelledby="device-connections-title">
            <div class="flex items-center justify-between gap-3">
              <h2 id="device-connections-title" class="font-medium">Connected devices</h2>
              <button type="button" class="btn btn-outline btn-sm" disabled={scanPending} onclick={() => void scanDevices()} data-testid="scan-devices">{scanPending ? 'Scanning…' : 'Scan devices'}</button>
            </div>
            {#if serialError}<p class="mt-3 text-sm text-error" role="alert">{serialError}</p>{/if}
            {#if serialPorts.length === 0}<p class="mt-2 text-sm text-muted">No serial ports found. Connect a device, then scan again.</p>{/if}
            {#each serialPorts as entry (entry.port)}
              <div class="mt-3 flex items-center justify-between gap-3 text-sm" data-testid="serial-port">
                <div><span class="font-mono">{entry.port}</span> <span class="text-muted">{entry.status === 'connected' ? `Connected${entry.config_id === null ? '' : ` · Config ${entry.config_id}`}` : 'Available'}</span></div>
                {#if entry.status === 'connected'}<button type="button" class="btn btn-ghost btn-xs" disabled={disconnectPending === entry.port} onclick={() => void disconnectPort(entry)}>Disconnect</button>{/if}
              </div>
            {/each}
          </section>
          {#if configurationError}<Unavailable message={configurationError} />
          {:else if configurations}
            {#if configurations.value.length === 0}<EmptyState heading="No Configurations" description="Create a configuration to set up inputs for your TSW devices." />
            {:else}<div class="space-y-4">{#each configurations.value as config (config.config_id)}
              <div class="list-card block" class:active-card={!!connectedFor(config.config_id)}>
                <div class="flex items-start justify-between gap-3"><div><a class="font-medium hover:underline" href={routeHref(`/configurations/${config.config_id}`)}>{config.name}</a>{#if config.description}<p class="mt-1 text-sm text-muted">{config.description}</p>{/if}<p class="mt-2 text-xs text-muted"><span class="font-mono">ID: {config.config_id}</span> · {config.input_count} inputs</p></div><span>{connectedFor(config.config_id) ? 'Active' : ''}</span></div>
                <div class="mt-3 flex flex-wrap items-center gap-2">
                  <label class="text-xs text-muted" for="apply-port-{config.config_id}">Device port</label>
                  <select id="apply-port-{config.config_id}" class="select select-bordered select-sm" value={selectedPorts[config.config_id]?.port ?? ''} onchange={(event) => selectApplyPort(config.config_id, event.currentTarget.value)} data-testid="apply-port">
                    <option value="">Select connected device</option>
                    {#each serialPorts.filter((entry) => entry.status === 'connected' && entry.generation !== null) as port (port.port)}<option value={port.port}>{port.port}</option>{/each}
                  </select>
                  <button type="button" class="btn btn-outline btn-sm" disabled={!serialPorts.some((entry) => entry.port === selectedPorts[config.config_id]?.port && entry.status === 'connected' && entry.generation === selectedPorts[config.config_id]?.generation) || applyOperations[config.config_id]?.state === 'pending'} onclick={() => void applyConfiguration(config)}>Apply</button>
                </div>
                {#if applyOperations[config.config_id]}
                  <p class="mt-2 text-sm" role="status">{applyOperations[config.config_id].state === 'pending' ? applyOperations[config.config_id].message ?? 'Applying configuration…' : applyOperations[config.config_id].state === 'complete' ? 'Configuration applied.' : applyOperations[config.config_id].message ?? 'Configuration failed.'}</p>
                {/if}
              </div>
            {/each}</div>{/if}
          {:else}<Unavailable message="Loading saved configurations…" />{/if}
        </div>
      {:else if route.page === 'trains'}
        <div class="mx-auto max-w-2xl">
          <header class="mb-8 flex items-center justify-between gap-4"><div><h1 class="text-2xl font-semibold">Trains</h1><p class="mt-1 text-sm text-muted">Manage train configurations</p></div><a class="btn btn-primary" href="#/trains/new">＋ New Train</a></header>
          {#if simulatorStatus?.detected_identifier}<p class="mb-5 text-sm text-muted">Simulator train ID: <span class="font-mono break-all">{simulatorStatus.detected_identifier}</span></p>{/if}
          {#if trainsError}<Unavailable message={trainsError} />
          {:else if trains}
            {#if trains.value.length === 0}<EmptyState heading="No Train Configurations" description="Create a train configuration to set up controls for your simulator trains." />
            {:else}<div class="space-y-4">{#each trains.value as train (train.id)}<div class:active-card={simulatorStatus?.active_train_id === train.id} class="list-card"><div class="flex items-start justify-between gap-3"><div><a class="font-medium hover:underline" href={routeHref(`/trains/${train.id}`)}>{train.name}</a>{#if train.description}<p class="mt-1 text-sm text-muted">{train.description}</p>{/if}<p class="mt-2 text-xs text-muted">{train.identifiers.join(', ')} · {train.element_count} elements</p></div><span>{simulatorStatus?.active_train_id === train.id ? 'Active' : ''}</span></div>
              {#if simulatorStatus?.active_train_id !== train.id}
                <div class="mt-3 flex flex-wrap items-center gap-2">
                  <button type="button" class="btn btn-outline btn-sm" disabled={activatingTrainId !== null} onclick={() => void activateTrain(train.id)} data-testid="set-active-train">{activatingTrainId === train.id ? 'Activating…' : 'Set Active'}</button>
                  {#if activateTrainError}<p class="text-sm text-error" role="alert">{activateTrainError}</p>{/if}
                </div>
              {/if}
            </div>{/each}</div>{/if}
          {:else}<Unavailable message="Loading saved train configurations…" />{/if}
        </div>
      {:else if route.page === 'configuration' || route.page === 'configuration-new'}
        <ConfigurationEdit
          bridge={activeBridge}
          mode={route.page === 'configuration-new' ? 'new' : 'existing'}
          routeId={route.page === 'configuration' ? route.configId : null}
          inputValues={route.page === 'configuration' && connectedFor(Number(route.configId)) ? hardwareInputValues[portKey(connectedFor(Number(route.configId))!.port, connectedFor(Number(route.configId))!.generation!, Number(route.configId))] ?? {} : {}}
          activePort={route.page === 'configuration' ? connectedFor(Number(route.configId))?.port ?? null : null}
          activeGeneration={route.page === 'configuration' ? connectedFor(Number(route.configId))?.generation ?? null : null}
          created={(summaryRouteId) => (location.hash = `#/configurations/${summaryRouteId}`)}
          deleted={() => (location.hash = '#/')}
        />
      {:else if route.page === 'train' || route.page === 'train-new'}
        {#key route.path}<TrainEdit bridge={activeBridge} {route} {simulatorStatus} {simulatorError} />{/key}
      {:else if route.page === 'script' || route.page === 'script-new'}
        {#key route.path}<ScriptEdit bridge={activeBridge} {route} />{/key}
      {:else if route.page === 'firmware'}
        <Firmware bridge={activeBridge} ports={serialPorts} refreshPorts={refreshPorts} updateStatus={firmwareUpdateStatus} refreshUpdateStatus={refreshFirmwareUpdate} />
      {:else if route.page === 'joystick'}
        <VirtualJoystick bridge={activeBridge} />
      {:else}
        <div class="mx-auto max-w-2xl"><header class="mb-8"><h1 class="text-2xl font-semibold">{title(route.page)}</h1></header><Unavailable message={unavailableMessage(route)} /></div>
      {/if}
    </main>
    {#if hardwareDetectionPrompt !== null}
      <div class="fixed inset-0 z-50 grid place-items-center bg-black/50 px-4" role="dialog" aria-modal="true" aria-labelledby="hardware-detection-title">
        <div class="w-full max-w-md rounded-xl bg-base-100 p-6 shadow-xl">
          <h2 id="hardware-detection-title" class="text-lg font-semibold">Hardware detection</h2>
          <p class="mt-3 text-sm">{hardwareDetectionPrompt}</p>
          <div class="mt-6 flex justify-end">
            <button type="button" class="btn btn-ghost btn-sm" onclick={() => (hardwareDetectionPrompt = null)} aria-label="Hide detection prompt">Hide</button>
          </div>
        </div>
      </div>
    {/if}
  </div>
{/if}

