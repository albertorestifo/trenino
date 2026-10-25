<script lang="ts">
  let {
    steps,
    current,
    completed = 0,
  }: {
    steps: string[];
    current: number;
    completed?: number;
  } = $props();
</script>

<div class="flex flex-wrap items-center gap-1 mt-4 overflow-x-auto" aria-label="Wizard steps">
  {#each steps as label, index (label)}
    <div class="flex items-center">
      <div
        class="flex items-center gap-1.5"
        aria-current={index === current ? 'step' : undefined}
      >
        <div
          class={[
            'w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium transition-colors',
            index === current && 'bg-primary text-primary-content',
            index !== current && index < completed && 'bg-success text-success-content',
            index !== current && index >= completed && 'bg-base-300 text-base-content/50',
          ]}
        >
          {#if index !== current && index < completed}
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-4 h-4"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd" /></svg>
          {:else}
            <span>{index + 1}</span>
          {/if}
        </div>
        <span
          class={[
            'text-xs whitespace-nowrap',
            index === current && 'font-medium',
            index !== current && index < completed && 'text-success',
            index !== current && index >= completed && 'text-base-content/50',
          ]}
        >
          {label}
        </span>
      </div>
      {#if index < steps.length - 1}<div class="w-4 h-px bg-base-300 mx-1"></div>{/if}
    </div>
  {/each}
</div>
