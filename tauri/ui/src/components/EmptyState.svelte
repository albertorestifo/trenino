<script lang="ts">
  let { heading, description }: { heading: string; description: string } = $props();
</script>
<div class="flex flex-col items-center justify-center py-20 text-center">
  <div class="text-5xl text-base-content/20" aria-hidden="true">⚙</div>
  <h2 class="mt-6 text-xl font-semibold">{heading}</h2>
  <p class="mt-2 max-w-sm text-base-content/70">{description}</p>
</div>
