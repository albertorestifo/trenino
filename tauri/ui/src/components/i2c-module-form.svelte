<script lang="ts">
  import type { I2cModuleView, UiFailure } from '../bridge/generated';
  import { parseI2cAddress } from './i2c-address';

  let {
    module = null,
    save,
    cancel,
  }: {
    module?: I2cModuleView | null;
    save: (fields: { name: string | null; module_chip: string; i2c_address: number }) => Promise<UiFailure | null>;
    cancel: () => void;
  } = $props();

  let name = $state(module?.name ?? '');
  let addressInput = $state(module?.i2c_address != null ? String(module.i2c_address) : '');
  let nameError = $state('');
  let addressError = $state('');
  let generalError = $state('');
  let saving = $state(false);

  const MODULE_CHIP = 'ht16k33';

  function brightnessPercent(view: I2cModuleView): number {
    return Math.round(((view.params?.brightness ?? 8) * 100) / 15);
  }

  async function submit(event: SubmitEvent) {
    event.preventDefault();
    nameError = '';
    addressError = '';
    generalError = '';
    const trimmedName = name.trim();
    if (trimmedName === '') nameError = 'Name is required';
    const address = parseI2cAddress(addressInput);
    if (address === null) addressError = 'Enter an address between 0 and 255, like 112 or 0x70.';
    if (trimmedName === '' || address === null) return;

    saving = true;
    const failure = await save({ name: trimmedName, module_chip: MODULE_CHIP, i2c_address: address });
    saving = false;
    if (failure) {
      nameError = failure.field_errors['name'] ?? '';
      addressError = failure.field_errors['i2c_address'] ?? '';
      generalError = nameError || addressError ? '' : failure.message;
    }
  }
</script>

<form id="i2c-module-form" onsubmit={submit} class="space-y-4">
  <div>
    <label class="label pb-1.5" for="display-name"><span class="label-text">Name</span></label>
    <input id="display-name" type="text" bind:value={name} placeholder="e.g. Speed display" class="input input-bordered w-full" />
    {#if nameError}<p role="alert" class="mt-1 text-xs text-error">{nameError}</p>{/if}
  </div>

  <p class="text-xs text-base-content/60">Uses an HT16K33 display driver.</p>

  <div>
    <label class="label pb-1.5" for="display-address"><span class="label-text">I2C address</span></label>
    <input
      id="display-address"
      type="text"
      bind:value={addressInput}
      placeholder="0x70"
      aria-describedby="display-address-hint"
      class="input input-bordered w-full font-mono"
      class:input-error={addressError !== ''}
    />
    {#if addressError}<p role="alert" class="mt-1 text-xs text-error">{addressError}</p>{/if}
    <p id="display-address-hint" class="mt-1 text-xs text-base-content/60">
      Find this on the display board or its wiring guide. Enter decimal (112) or hex (0x70).
    </p>
  </div>

  {#if module?.params}
    <div class="rounded-lg border-t border-base-300 pt-3 text-sm">
      <h4 class="mb-2 font-medium">Advanced display settings</h4>
      <dl class="grid gap-1 text-base-content/70">
        <div class="flex justify-between"><dt>Display type</dt><dd class="font-mono">{module.params.display_type}</dd></div>
        <div class="flex justify-between"><dt>Digits</dt><dd class="font-mono">{module.params.num_digits}</dd></div>
        <div class="flex justify-between"><dt>Brightness</dt><dd class="font-mono">{brightnessPercent(module)}%</dd></div>
        <div class="flex justify-between"><dt>Decimal point</dt><dd>{module.params.has_dot ? 'Yes' : 'No'}</dd></div>
        <div class="flex justify-between"><dt>Right-aligned</dt><dd>{module.params.align_right ? 'Yes' : 'No'}</dd></div>
        <div class="flex justify-between"><dt>Minimum value</dt><dd class="font-mono">{module.params.min_value ?? '—'}</dd></div>
      </dl>
    </div>
  {/if}

  {#if generalError}<p role="alert" class="text-sm text-error">{generalError}</p>{/if}

  <div class="mt-6 flex justify-end gap-2">
    <button type="button" class="btn btn-ghost" onclick={cancel}>Cancel</button>
    <button type="submit" class="btn btn-primary" disabled={saving}>{saving ? 'Saving…' : module ? 'Save display' : 'Add display'}</button>
  </div>
</form>
