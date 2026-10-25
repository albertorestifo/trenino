<script lang="ts">
  import { onMount } from 'svelte';
  import Navigation from './Navigation.svelte';
  import EmptyState from '../components/EmptyState.svelte';
  import Unavailable from '../components/Unavailable.svelte';
  import { bridge as productionBridge, type Result, type UiBridge } from '../bridge/client';
  import ConfigurationEdit from './pages/configuration/ConfigurationEdit.svelte';
  import SettingsEdit from './pages/settings/SettingsEdit.svelte';
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


  let hardwareSummaries = $state<ConfigurationSummaryView[] | null>(null);
  let hardwareInputValues = $state<Record<number, number>>({});
  let liveConfigId = $state<number | null>(null);
  let unsubscribeHardware: (() => void) | null = null;

  const activeBridge = $derived(injectedBridge ?? productionBridge);

  onMount(() => {
    void api()
      .subscribe<ConfigurationSummaryView[]>('hardware', (snapshot) => {
        hardwareSummaries = snapshot.value;
      }, () => {
        hardwareSummaries = null;
      })
      .then((stop) => {
        unsubscribeHardware = stop;
      });
    void api().onHardwareInput?.((event) => {
      if (event.config_id !== liveConfigId) hardwareInputValues = {};
      liveConfigId = event.config_id;
      hardwareInputValues = { ...hardwareInputValues, [event.pin]: event.value };
    });
  });

  $effect(() => {
    return () => {
      unsubscribeHardware?.();
      unsubscribeHardware = null;
    };
  });

  const activeConfigurationCount = $derived(hardwareSummaries?.filter((summary) => summary.active).length ?? 0);
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
    if (page === 'firmware') return 'Firmware';
    if (page === 'joystick') return 'Virtual Joystick';
    return 'Unavailable';
  }

  function unavailableMessage(current: Route): string {
    if (current.page === 'train-new') return 'Train creation is not integrated with the Rust service yet.';
    if (current.page === 'train') return 'This screen will appear when its Rust service is integrated.';
    if (current.page === 'firmware') return 'Firmware release and upload services are not integrated in this UI slice.';
    if (current.page === 'joystick') return 'Joystick service capabilities are not integrated in this UI slice.';
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
        <p class="text-sm text-base-content/70">Share anonymous error reports so bugs can be found and fixed faster. No personal data, no usage tracking — only crash reports.</p>
        {#if consentError}<p role="alert" class="mt-3 text-sm text-error">{consentError}</p>{/if}
        <div class="mt-4 flex w-full flex-col gap-2">
          <button class="btn btn-primary w-full" disabled={consentPending} onclick={() => void setConsent('enabled')}>Share error reports</button>
          <button class="btn btn-ghost w-full" disabled={consentPending} onclick={() => void setConsent('disabled')}>No thanks</button>
        </div>
        <a class="mt-3 text-sm text-base-content/60 underline" href="#/settings">Back to Settings</a>
      </div>
    </section>
  </main>
{:else if gateStatus === 'checking'}
  <main class="consent-layout" role="status"><section class="card w-full max-w-md bg-base-100 shadow-xl"><div class="card-body items-center text-center"><h1 class="card-title text-lg">Checking consent preference</h1><p class="text-sm text-base-content/70">Trenino is checking your saved privacy choice before opening the app.</p></div></section></main>
{:else if gateStatus === 'unavailable'}
  <main class="consent-layout">
    <section class="card w-full max-w-md bg-base-100 shadow-xl"><div class="card-body items-center text-center"><h1 class="card-title text-lg">Consent status unavailable</h1><p class="text-sm text-base-content/70">Trenino cannot verify your saved privacy choice, so the rest of the app is paused.</p><p role="alert" class="text-sm text-error">{gateError}</p><button class="btn btn-primary w-full" onclick={() => void updateRoute()}>Retry consent check</button><a class="text-sm text-base-content/60 underline" href="#/consent">Open consent choices</a></div></section>
  </main>
{:else if gateStatus === 'needs-consent'}
  <main class="consent-layout" role="status"><section class="card w-full max-w-md bg-base-100 shadow-xl"><div class="card-body items-center text-center"><h1 class="card-title text-lg">Opening consent choices</h1><p class="text-sm text-base-content/70">Choose whether Trenino may share anonymous error reports.</p></div></section></main>
{:else}
  <div class="min-h-screen bg-base-200 text-base-content">
    <Navigation {route} connectedCount={activeConfigurationCount} />
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
            <div><h1 class="text-2xl font-semibold">Configurations</h1><p class="mt-1 text-sm text-base-content/70">Manage device configurations</p></div>
            <a class="btn btn-primary" href="#/configurations/new">＋ New Configuration</a>
          </header>
          {#if configurationError}<Unavailable message={configurationError} />
          {:else if configurations}
            {#if configurations.value.length === 0}<EmptyState heading="No Configurations" description="Create a configuration to set up inputs for your TSW devices." />
            {:else}<div class="space-y-4">{#each configurations.value as config (config.config_id)}<a class:active-card={config.active} class="list-card" href={routeHref(`/configurations/${config.config_id}`)}><div><h2 class="font-medium">{config.name}</h2>{#if config.description}<p class="mt-1 text-sm text-base-content/70">{config.description}</p>{/if}<p class="mt-2 text-xs text-base-content/60"><span class="font-mono">ID: {config.config_id}</span> · {config.input_count} inputs</p></div><span>{config.active ? 'Active' : '›'}</span></a>{/each}</div>{/if}
          {:else}<Unavailable message="Loading saved configurations…" />{/if}
        </div>
      {:else if route.page === 'trains'}
        <div class="mx-auto max-w-2xl">
          <header class="mb-8 flex items-center justify-between gap-4"><div><h1 class="text-2xl font-semibold">Trains</h1><p class="mt-1 text-sm text-base-content/70">Manage train configurations</p></div><a class="btn btn-primary" href="#/trains/new">＋ New Train</a></header>
          {#if trainsError}<Unavailable message={trainsError} />
          {:else if trains}
            {#if trains.value.length === 0}<EmptyState heading="No Train Configurations" description="Create a train configuration to set up controls for your simulator trains." />
            {:else}<div class="space-y-4">{#each trains.value as train (train.id)}<a class:active-card={train.active} class="list-card" href={routeHref(`/trains/${train.id}`)}><div><h2 class="font-medium">{train.name}</h2>{#if train.description}<p class="mt-1 text-sm text-base-content/70">{train.description}</p>{/if}<p class="mt-2 text-xs text-base-content/60">{train.identifiers.join(', ')} · {train.element_count} elements</p></div><span>{train.active ? 'Active' : '›'}</span></a>{/each}</div>{/if}
          {:else}<Unavailable message="Loading saved train configurations…" />{/if}
        </div>
      {:else if route.page === 'configuration' || route.page === 'configuration-new'}
        <ConfigurationEdit
          bridge={activeBridge}
          mode={route.page === 'configuration-new' ? 'new' : 'existing'}
          routeId={route.page === 'configuration' ? route.configId : null}
          inputValues={route.page === 'configuration' && liveConfigId === Number(route.configId) ? hardwareInputValues : {}}
          activePort={route.page === 'configuration' && liveConfigId === Number(route.configId) ? 'live' : null}
          created={(summaryRouteId) => (location.hash = `#/configurations/${summaryRouteId}`)}
          deleted={() => (location.hash = '#/')}
        />
      {:else}
        <div class="mx-auto max-w-2xl"><header class="mb-8"><h1 class="text-2xl font-semibold">{title(route.page)}</h1></header><Unavailable message={unavailableMessage(route)} /></div>
      {/if}
    </main>
  </div>
{/if}

