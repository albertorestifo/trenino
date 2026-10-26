<script lang="ts">
  import type { MatrixView } from '../bridge/generated';

  let {
    matrix,
    inputValues = {},
    testedButtons = [],
    reset,
    close,
  }: {
    matrix: MatrixView;
    inputValues?: Record<number, number>;
    testedButtons?: number[];
    reset: () => void;
    close: () => void;
  } = $props();

  const rows = $derived([...matrix.row_pins].sort((a, b) => a.position - b.position));
  const cols = $derived([...matrix.col_pins].sort((a, b) => a.position - b.position));
  const numCols = $derived(cols.length);
  const totalButtons = $derived(rows.length * numCols);
  const tested = $derived(new Set(testedButtons));
  const pressed = $derived(new Set(Object.entries(inputValues).filter(([, value]) => value === 1).map(([pin]) => Number(pin)).filter((pin) => pin >= 128)));
  const testedCount = $derived([...tested].filter((pin) => pin < 128 + totalButtons).length);
  const progressPercent = $derived(totalButtons > 0 ? Math.round((testedCount / totalButtons) * 100) : 0);

  function virtualPin(rowIndex: number, colIndex: number): number {
    return 128 + rowIndex * numCols + colIndex;
  }
</script>

<div class="fixed inset-0 z-50 flex items-center justify-center" role="dialog" aria-modal="true" aria-labelledby="matrix-test-title">
  <div class="absolute inset-0 bg-black/50" onclick={close} aria-hidden="true"></div>
  <div class="relative max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-xl bg-base-100 p-6 shadow-xl mx-4">
    <div class="mb-4 flex items-center justify-between">
      <div>
        <h2 id="matrix-test-title" class="text-xl font-semibold">Test Matrix</h2>
        <p class="text-sm text-muted">{rows.length} rows x {numCols} columns</p>
      </div>
      <button type="button" class="btn btn-ghost btn-sm btn-circle" aria-label="Close" onclick={close}>✕</button>
    </div>

    <div class="mb-6">
      <div class="mb-2 flex items-center justify-between text-sm">
        <span class="text-muted">Progress</span>
        <span class="font-medium">
          {testedCount} / {totalButtons} buttons tested
          <span class="text-muted">({progressPercent}%)</span>
        </span>
      </div>
      <div class="h-2 w-full rounded-full bg-base-300">
        <div class="h-2 rounded-full bg-success transition-all duration-300" style="width: {progressPercent}%"></div>
      </div>
    </div>

    {#if rows.length > 0 && numCols > 0}
      <div class="overflow-x-auto rounded-lg bg-base-200 p-4">
        <table class="mx-auto">
          <thead>
            <tr>
              <th class="p-1"></th>
              {#each cols as col, colIndex}
                <th class="p-1 text-center text-xs font-mono text-muted">C{colIndex}<br /><span class="text-[10px]">({col.pin})</span></th>
              {/each}
            </tr>
          </thead>
          <tbody>
            {#each rows as row, rowIndex}
              <tr>
                <td class="p-1 pr-2 text-right text-xs font-mono text-muted">R{rowIndex} <span class="text-[10px]">({row.pin})</span></td>
                {#each cols as _, colIndex}
                  {@const pin = virtualPin(rowIndex, colIndex)}
                  {@const isPressed = pressed.has(pin)}
                  {@const isTested = tested.has(pin)}
                  <td class="p-1">
                    <div
                      class="flex h-10 w-12 flex-col items-center justify-center rounded-lg border-2 transition-all duration-150 ease-out {isPressed ? 'bg-success text-success-content border-success ring-4 ring-success/30 scale-105' : isTested ? 'bg-success/20 border-success text-success' : 'bg-base-300 border-base-300 text-base-content/30'}"
                      data-virtual-pin={pin}
                    >
                      <span class="text-[9px] font-mono opacity-60">{pin}</span>
                    </div>
                  </td>
                {/each}
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {:else}
      <div class="rounded-lg bg-base-200 p-8 text-center">
        <p class="text-sm text-muted">Matrix not configured</p>
        <p class="text-xs text-muted">Add row and column pins to use this feature</p>
      </div>
    {/if}

    <div class="mt-4 flex flex-wrap items-center gap-4 text-xs text-muted">
      <div class="flex items-center gap-2"><div class="h-4 w-4 rounded border border-base-300 bg-base-300"></div><span>Never pressed</span></div>
      <div class="flex items-center gap-2"><div class="h-4 w-4 rounded border border-primary bg-primary"></div><span>Currently pressed</span></div>
      <div class="flex items-center gap-2"><div class="h-4 w-4 rounded border border-success bg-success/20"></div><span>Tested</span></div>
    </div>

    <div class="mt-4 flex justify-between gap-4 border-t border-base-300 pt-4">
      <button type="button" class="btn btn-ghost btn-sm" onclick={reset}>Reset</button>
      <button type="button" class="btn btn-primary btn-sm" onclick={close}>Close</button>
    </div>
  </div>
</div>
