<script lang="ts">
  import type { Route } from '../bridge/route';
  import type { FirmwareUpdateStatus, SimulatorRuntimeStatus } from '../bridge/client';

  let { route, connectedCount = 0, simulatorStatus = null, simulatorError = '', retryPending = false, onRetry = () => {},
    firmwareUpdateStatus = null, firmwareStatusError = '', firmwareActionError = '', firmwareCheckPending = false, firmwareDismissPending = false,
    onFirmwareCheck = () => {}, onFirmwareDismiss = () => {} }: {
    route: Route; connectedCount?: number; simulatorStatus?: SimulatorRuntimeStatus | null; simulatorError?: string; retryPending?: boolean; onRetry?: () => void;
    firmwareUpdateStatus?: FirmwareUpdateStatus | null; firmwareStatusError?: string; firmwareActionError?: string;
    firmwareCheckPending?: boolean; firmwareDismissPending?: boolean; onFirmwareCheck?: () => void; onFirmwareDismiss?: () => void;
  } = $props();
  let open = $state(false);
  let menuButton: HTMLButtonElement;

  const tabs = [
    { href: '#/', label: 'Devices', active: (path: string) => path === '/' || path.startsWith('/configurations') },
    { href: '#/trains', label: 'Trains', active: (path: string) => path.startsWith('/trains') },
    { href: '#/virtual-joystick', label: 'Joystick', active: (path: string) => path.startsWith('/virtual-joystick') },
    { href: '#/firmware', label: 'Firmware', active: (path: string) => path.startsWith('/firmware') },
  ];

  function closeMenu(restoreFocus = false) {
    open = false;
    if (restoreFocus) queueMicrotask(() => menuButton?.focus());
  }

  function onKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape' && open) {
      event.stopPropagation();
      closeMenu(true);
    }
  }
</script>

<svelte:window onkeydown={onKeydown} />
<header class="sticky top-0 z-40 border-b border-base-300 bg-base-100">
  <div class="flex flex-wrap items-center gap-y-3 px-4 py-3 sm:px-8">
    <a href="#/" class="mr-6 flex-1 text-lg font-semibold sm:flex-none">Trenino</a>
    <nav aria-label="Primary navigation" class="order-last flex w-full items-center gap-1 sm:order-none sm:w-auto">
      {#each tabs as tab}
        <a href={tab.href} aria-current={tab.active(route.path) ? 'page' : undefined} class:active-tab={tab.active(route.path)} class="nav-tab">{tab.label}</a>
      {/each}
    </nav>
    <div class="ml-auto flex items-center gap-2">
      <a href="#/settings" class="nav-utility" aria-label="Settings" title="Settings"><span aria-hidden="true">⚙</span><span class="hidden text-sm font-medium sm:inline">Settings</span></a>
      <div class="relative">
        <button bind:this={menuButton} class="nav-utility" aria-label="Connected devices" aria-expanded={open} aria-haspopup="menu" onclick={() => (open = !open)}>
          <span class="h-2 w-2 rounded-full {connectedCount > 0 ? 'bg-success' : 'bg-base-content/20'}" aria-hidden="true"></span>
          <span class="hidden text-sm font-medium sm:inline">{connectedCount > 0 ? `${connectedCount} device${connectedCount === 1 ? '' : 's'} active` : 'No device connected'}</span>
          <span aria-hidden="true">⌄</span>
        </button>
        {#if open}
          <div class="device-menu" role="menu" aria-label="Connected devices">
            <p class="text-sm text-muted">{connectedCount > 0 ? `${connectedCount} active configuration${connectedCount === 1 ? '' : 's'} on connected devices.` : 'No configuration is active on a connected device.'}</p>
            <button type="button" class="btn btn-ghost btn-sm mt-3 w-full" role="menuitem" disabled={firmwareCheckPending || firmwareUpdateStatus?.checking} onclick={onFirmwareCheck} aria-label="Check for firmware updates">
              {firmwareCheckPending || firmwareUpdateStatus?.checking ? 'Checking firmware…' : 'Check for firmware updates'}
            </button>
            {#if firmwareStatusError}<p class="mt-2 text-xs text-error" role="status">Firmware status unavailable: {firmwareStatusError}</p>{/if}
            {#if firmwareUpdateStatus?.error_message}<p class="mt-2 text-xs text-error" role="status">Last firmware check failed: {firmwareUpdateStatus.error_message}</p>{/if}
            {#if firmwareActionError}<p class="mt-2 text-xs text-error" role="status">{firmwareActionError}</p>{/if}
            <button class="btn btn-sm mt-3" role="menuitem" onclick={() => closeMenu(true)}>Close</button>
          </div>
        {/if}
      </div>
    </div>
  </div>
  {#if firmwareUpdateStatus?.notice}
    <div class="bg-primary text-primary-content px-4 sm:px-8" role="alert" aria-label="Firmware update available">
      <div class="mx-auto flex max-w-2xl flex-wrap items-center justify-between gap-x-4 gap-y-1 py-2">
        <div class="flex min-w-0 items-center gap-3">
          <span aria-hidden="true">↓</span>
          <div class="min-w-0 break-words text-sm">
            <span class="font-medium">Firmware update available:</span> v{firmwareUpdateStatus.notice.version}
            {#if firmwareUpdateStatus.notice.outdated_devices.length || firmwareUpdateStatus.notice.outdated_ports.length}
              <span class="ml-1">for {[...firmwareUpdateStatus.notice.outdated_devices, ...firmwareUpdateStatus.notice.outdated_ports].join(', ')}</span>
            {/if}
            {#if firmwareActionError}<span class="block">{firmwareActionError}</span>{/if}
          </div>
        </div>
        <div class="flex items-center gap-2">
          <a href="#/firmware" class="btn btn-sm btn-ghost text-primary-content hover:bg-primary-content/10">View update</a>
          <button type="button" class="btn btn-sm btn-ghost text-primary-content hover:bg-primary-content/10" aria-label="Dismiss firmware update" disabled={firmwareDismissPending} onclick={onFirmwareDismiss}>{firmwareDismissPending ? 'Dismissing…' : 'Dismiss'}</button>
        </div>
      </div>
    </div>
  {/if}
  {#if route.page !== 'joystick'}
    <div class="flex flex-wrap items-center justify-center gap-x-3 border-t border-base-300 px-4 py-1.5 text-center text-xs text-muted {simulatorStatus?.status === 'connected' && !simulatorError ? 'bg-success/10' : 'bg-warning/10'}" role="status" aria-live="polite" data-testid="simulator-status">
      {#if simulatorError}{simulatorError}
      {:else if !simulatorStatus}Checking simulator status…
      {:else if simulatorStatus?.status === 'connected'}Simulator connected{simulatorStatus.detected_identifier ? ` · ${simulatorStatus.detected_identifier}` : ''}
      {:else if simulatorStatus?.status === 'connecting'}Connecting to simulator…
      {:else if simulatorStatus?.status === 'needs_config'}Configure simulator in Settings.
      {:else}Simulator disconnected{simulatorStatus?.last_error ? ` · ${simulatorStatus.last_error}` : ''}{/if}
      {#if simulatorError || (simulatorStatus && simulatorStatus.status !== 'connected')}<button type="button" class="underline hover:text-base-content" disabled={retryPending} onclick={onRetry} data-testid="retry-simulator">{retryPending ? 'Retrying…' : 'Retry'}</button>{/if}
    </div>
  {/if}
</header>
