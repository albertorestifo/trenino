<script lang="ts">
  let { message }: { message: string } = $props();
</script>
<div class="alert alert-info" role="status"><span>{message}</span></div>
