<script lang="ts">
  import type { UiBridge } from '../../../bridge/client';
  import type { SettingsView } from '../../../bridge/generated';
  import { setThemePreference, THEME_STORAGE_KEY, normalizeThemePreference, type ThemePreference } from '../../theme';

  let {
    bridge,
    settings,
    consentPending = false,
    onConsent,
  }: {
    bridge: UiBridge;
    settings: SettingsView | undefined;
    consentPending?: boolean;
    onConsent: (value: 'enabled' | 'disabled') => Promise<string | null>;
  } = $props();

  let url = $state('');
  let apiKey = $state('');
  let keySavedLocally = $state(false);
  // Mirrors the `phx:set-theme` window event: same store key, same data-theme attribute.
  let themePreference = $state<ThemePreference>(normalizeThemePreference(
    typeof localStorage === 'undefined' ? null : localStorage.getItem(THEME_STORAGE_KEY),
  ));

  const keyConfigured = $derived(settings?.simulator.api_key_configured === true || keySavedLocally);
  let urlError = $state('');
  let saving = $state(false);
  let connectionResult = $state('');
  let consentError = $state('');
  let initialized = $state(false);

  $effect(() => {
    if (settings && !initialized) {
      url = settings.simulator.url;
      initialized = true;
    }
  });

  function validateUrl(value: string): string {
    if (value.trim() === '') return 'URL is required';
    if (!/^https?:\/\//.test(value.trim())) return 'URL must start with http:// or https://';
    return '';
  }

  function onUrlChange() {
    urlError = validateUrl(url);
  }

  async function save(event: SubmitEvent) {
    event.preventDefault();
    connectionResult = '';
    urlError = validateUrl(url);
    if (urlError) return;

    saving = true;
    const trimmedKey = apiKey.trim();
    if (trimmedKey !== '') {
      const keyResult = await bridge.setApiKey?.(trimmedKey);
      if (!keyResult) {
        saving = false;
        connectionResult = 'API key saving is not available in this build.';
        return;
      }
      if (!keyResult.ok) {
        saving = false;
        connectionResult = keyResult.error.message;
        return;
      }
      keySavedLocally = keyResult.value.value.simulator.api_key_configured;
      apiKey = '';
    }
    const urlResult = await bridge.setSimulatorUrl?.(url.trim());
    if (!urlResult) {
      saving = false;
      connectionResult = 'Simulator settings are not available in this build.';
      return;
    }
    if (!urlResult.ok) {
      saving = false;
      urlError = urlResult.error.field_errors['simulator_url'] ?? urlResult.error.field_errors['url'] ?? '';
      if (!urlError) connectionResult = urlResult.error.message;
      return;
    }
    connectionResult = 'Settings saved. Testing connection…';
    const probe = await bridge.testSimulator?.();
    saving = false;
    if (!probe) {
      connectionResult = 'Settings saved.';
      return;
    }
    if (!probe.ok) {
      connectionResult = probe.error.message;
      return;
    }
    connectionResult = probe.value ? 'Connected to Train Sim World.' : 'Could not connect to Train Sim World. Check the URL, start the game with its API enabled, and try again.';
  }

  async function toggleErrorReporting() {
    if (!settings || consentPending) return;
    consentError = '';
    const next = settings.error_reporting === 'enabled' ? 'disabled' : 'enabled';
    const error = await onConsent(next);
    if (error) consentError = error;
  }
</script>

<header class="mb-10"><h1 class="text-2xl font-semibold">Settings</h1></header>

<section aria-labelledby="theme-title">
  <h2 id="theme-title" class="mb-5 text-base font-semibold">Theme</h2>
  <div class="flex flex-wrap gap-6">
    {#each [{ value: 'system', label: 'System' }, { value: 'light', label: 'Light' }, { value: 'dark', label: 'Dark' }] as option (option.value)}
      <label class="flex cursor-pointer items-center gap-2 text-sm">
        <input
          type="radio"
          name="theme-preference"
          class="radio radio-primary radio-sm"
          value={option.value}
          data-testid={`theme-${option.value}`}
          checked={themePreference === option.value}
          onchange={() => (themePreference = setThemePreference(option.value, localStorage, document.documentElement))}
        />
        <span>{option.label}</span>
      </label>
    {/each}
  </div>
</section>

<div class="my-10 border-t border-base-300"></div>

<section aria-labelledby="reporting-title">
  <h2 id="reporting-title" class="mb-5 text-base font-semibold">Error Reporting</h2>
  <label class="flex cursor-pointer items-start justify-between gap-6">
    <div>
      <div class="font-medium">Share anonymous error reports</div>
      <p class="mt-1 text-sm text-muted">Crash reports are sent to help fix bugs. No personal data is included.</p>
      <a class="mt-3 inline-block text-sm text-muted underline underline-offset-2" href="#/consent">Review consent details</a>
      {#if consentError}<p role="alert" class="mt-2 text-sm text-error">{consentError}</p>{/if}
    </div>
    <input
      type="checkbox"
      class="toggle toggle-primary mt-0.5 shrink-0"
      data-testid="error-reporting-toggle"
      checked={settings?.error_reporting === 'enabled'}
      disabled={consentPending || !settings}
      onchange={() => void toggleErrorReporting()}
    />
  </label>
</section>

<div class="my-10 border-t border-base-300"></div>

<section aria-labelledby="simulator-title">
  <h2 id="simulator-title" class="mb-5 text-base font-semibold">Simulator Connection</h2>
  <form id="simulator-form" data-testid="simulator-form" onsubmit={(event) => void save(event)} novalidate>
    <div class="mb-5">
      <label class="label pb-1.5" for="simulator_url"><span class="label-text">URL</span></label>
      <input
        id="simulator_url"
        type="text"
        bind:value={url}
        onchange={onUrlChange}
        placeholder="http://192.168.1.x:31270"
        class="input input-bordered w-full font-mono"
        class:input-error={!!urlError}
      />
      {#if urlError}<div role="alert" class="mt-1.5 flex items-center gap-1.5 text-xs text-error">{urlError}</div>{/if}
    </div>

    <div class="mb-6">
      <label class="label pb-1.5" for="simulator_api_key"><span class="label-text">API Key</span></label>
      {#if keyConfigured}
        <div class="mb-3 flex items-center gap-2 rounded border border-base-300 bg-base-200 px-3 py-2 text-sm">
          <span aria-hidden="true">✓</span>
          <span class="text-muted">A key is saved. Enter a new key below to replace it.</span>
        </div>
      {:else}
        <div class="alert alert-warning mb-3 px-3 py-2 text-sm">
          <span>No API key is configured yet. Enter a key below.</span>
        </div>
      {/if}
      <input id="simulator_api_key" type="password" bind:value={apiKey} placeholder="Leave blank to keep current value" class="input input-bordered w-full font-mono" />
      <div class="mt-1.5 text-xs text-muted">
        Copy the key from
        <span class="break-all font-mono">Documents\My Games\TrainSimWorld7\Saved\Config\CommAPIKey.txt</span>
        (or <span class="font-mono">TrainSimWorld6</span>) on the PC running Train Sim World and paste it here.
      </div>
    </div>

    {#if connectionResult}
      <p id="simulator-connection-result" role="status" aria-live="polite" class="mb-4 text-sm text-base-content/80">{connectionResult}</p>
    {/if}
    <div class="flex justify-end">
      <button type="submit" class="btn btn-primary" disabled={saving}>{saving ? 'Saving and testing…' : 'Save and test connection'}</button>
    </div>
  </form>
</section>
