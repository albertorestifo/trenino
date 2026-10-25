<script lang="ts">
  import type { Route } from '../bridge/route';

  let { route, connectedCount = 0 }: { route: Route; connectedCount?: number } = $props();
  let open = $state(false);
  let menuButton: HTMLButtonElement;

  const tabs = [
    { href: '#/', label: 'Devices', active: (path: string) => path === '/' || path.startsWith('/configurations') },
    { href: '#/trains', label: 'Trains', active: (path: string) => path.startsWith('/trains') },
    { href: '#/virtual-joystick', label: 'Joystick', active: (path: string) => path.startsWith('/virtual-joystick') },
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
  <div class="mx-auto flex max-w-2xl flex-wrap items-center gap-y-3 px-4 py-3 sm:px-8">
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
          <span class="h-2 w-2 rounded-full {connectedCount > 0 ? 'bg-success animate-pulse' : 'bg-base-content/30'}" aria-hidden="true"></span>
          <span class="hidden text-sm font-medium sm:inline">{connectedCount > 0 ? `${connectedCount} device${connectedCount === 1 ? '' : 's'} active` : 'No device connected'}</span>
          <span aria-hidden="true">⌄</span>
        </button>
        {#if open}
          <div class="device-menu" role="menu" aria-label="Connected devices">
            <p class="text-sm text-base-content/70">{connectedCount > 0 ? `${connectedCount} active configuration${connectedCount === 1 ? '' : 's'} on connected devices.` : 'No configuration is active on a connected device.'}</p>
            <button class="btn btn-sm mt-3" role="menuitem" onclick={() => closeMenu(true)}>Close</button>
          </div>
        {/if}
      </div>
    </div>
  </div>
  {#if route.page !== 'joystick'}
    <div class="border-t border-base-300 bg-warning/10 px-4 py-1.5 text-center text-xs text-base-content/70" role="status" aria-live="polite">
      Simulator status unavailable until the Rust service is connected.
    </div>
  {/if}
</header>
