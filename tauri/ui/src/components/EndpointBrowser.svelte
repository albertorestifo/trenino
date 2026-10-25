<script lang="ts">
  import type { SimulatorEndpoint, UiBridge } from '../bridge/client';

  let { bridge, onSelect, label = 'Browse simulator' }: { bridge: UiBridge; onSelect: (path: string) => void; label?: string } = $props();
  let open = $state(false);
  let path = $state<string | null>(null);
  let entries = $state<SimulatorEndpoint[]>([]);
  let search = $state('');
  let selected = $state<SimulatorEndpoint | null>(null);
  let value = $state<unknown>(null);
  let loading = $state(false);
  let error = $state('');
  let request = 0;

  const filtered = $derived(entries.filter((entry) => entry.name.toLowerCase().includes(search.toLowerCase())));

  async function load(nextPath: string | null) {
    const current = ++request;
    path = nextPath;
    selected = null;
    value = null;
    search = '';
    error = '';
    loading = true;
    const result = await bridge.listSimulatorEndpoints(nextPath);
    if (current !== request || !open) return;
    loading = false;
    if (result.ok) entries = result.value;
    else { entries = []; error = result.error.message; }
  }

  async function choose(entry: SimulatorEndpoint) {
    if (entry.kind === 'node') { await load(entry.path); return; }
    const current = ++request;
    selected = entry;
    value = null;
    loading = true;
    error = '';
    const result = await bridge.getSimulatorValue(entry.path);
    if (current !== request || !open) return;
    loading = false;
    if (result.ok) value = result.value;
    else error = result.error.message;
  }

  function parentPath(): string | null {
    if (!path) return null;
    const index = path.lastIndexOf('/');
    return index < 0 ? null : path.slice(0, index);
  }

  function displayValue(value: unknown): string {
    return typeof value === 'string' ? value : JSON.stringify(value) ?? 'null';
  }

  function close() {
    open = false;
    request += 1;
  }
</script>

<button type="button" class="btn btn-ghost btn-xs" onclick={() => { open = !open; if (open) void load(null); else close(); }} data-testid="browse-simulator">{label}</button>
{#if open}
  <section class="mt-2 rounded-lg border border-base-300 bg-base-100 p-3 text-sm" aria-label="Simulator endpoints" data-testid="endpoint-browser">
    <div class="flex items-center justify-between gap-2">
      <div class="min-w-0 truncate font-mono text-xs" title={path ?? 'Root'}>{path ?? 'Root'}</div>
      <button type="button" class="btn btn-ghost btn-xs" onclick={() => void load(parentPath())} disabled={path === null || loading}>Back</button>
    </div>
    <input type="search" class="input input-bordered input-sm mt-2 w-full" placeholder="Filter this level" aria-label="Filter simulator endpoints" bind:value={search} />
    {#if loading}<p role="status" class="mt-2 text-base-content/60">Loading simulator values…</p>{/if}
    {#if error}<p role="alert" class="mt-2 text-error">{error}</p>{/if}
    {#if !loading && !error}
      {#if filtered.length === 0}<p class="mt-2 text-base-content/60">No endpoints at this level.</p>{/if}
      <div class="mt-2 max-h-48 overflow-y-auto">
        {#each filtered as entry (entry.path)}
          <button type="button" class="flex w-full items-center justify-between rounded px-2 py-1 text-left hover:bg-base-200" onclick={() => void choose(entry)}>
            <span class="truncate">{entry.name}</span><span class="ml-2 text-xs text-base-content/60">{entry.kind === 'node' ? 'Open' : 'Value'}</span>
          </button>
        {/each}
      </div>
    {/if}
    {#if selected}
      <div class="mt-3 border-t border-base-300 pt-3">
        <p class="break-all font-mono text-xs">{selected.path}</p>
        {#if !loading && !error}<p class="mt-1 break-all text-xs text-base-content/70" data-testid="simulator-value">Current value: {displayValue(value)}</p>{/if}
        <button type="button" class="btn btn-primary btn-sm mt-2" disabled={loading || !!error} onclick={() => { onSelect(selected!.path); close(); }} data-testid="use-simulator-endpoint">Use endpoint</button>
      </div>
    {/if}
  </section>
{/if}
