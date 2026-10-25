<script lang="ts">
  let {
    title,
    subtitle = '',
    onClose,
    closing = false,
    width = 'max-w-4xl',
    children,
  }: {
    title: string;
    subtitle?: string;
    onClose: () => void;
    closing?: boolean;
    width?: string;
    children?: import('svelte').Snippet;
  } = $props();
</script>

<div class="fixed inset-0 z-50 flex items-center justify-center p-4">
  <div class="absolute inset-0 bg-black/50" onclick={() => { if (!closing) onClose(); }} aria-hidden="true" data-testid="wizard-backdrop"></div>
  <div
    class="relative bg-base-100 rounded-xl shadow-xl w-full {width} max-h-[90vh] flex flex-col min-h-0"
    role="dialog"
    aria-modal="true"
    aria-labelledby="wizard-modal-title"
  >
    <div class="p-4 border-b border-base-300 flex items-start justify-between gap-3">
      <div class="min-w-0">
        <h2 id="wizard-modal-title" class="text-lg font-semibold">{title}</h2>
        {#if subtitle}<p class="text-sm text-base-content/60">{subtitle}</p>{/if}
      </div>
      <button type="button" class="btn btn-ghost btn-sm btn-circle shrink-0" disabled={closing} onclick={onClose} aria-label="Close" data-testid="wizard-close">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-5 h-5"><path d="M6.28 5.22a.75.75 0 0 0-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 1 0 1.06 1.06L10 11.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L11.06 10l3.72-3.72a.75.75 0 0 0-1.06-1.06L10 8.94 6.28 5.22Z" /></svg>
      </button>
    </div>
    <div class="flex-1 overflow-y-auto min-h-0">
      {@render children?.()}
    </div>
  </div>
</div>
