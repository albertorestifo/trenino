<script lang="ts">
  import type { Ht16k33ParamsView, I2cModuleView, UiFailure } from '../bridge/generated';
  import { parseI2cAddress } from './i2c-address';

  let {
    module = null,
    save,
    cancel,
  }: {
    module?: I2cModuleView | null;
    save: (fields: { name: string | null; module_chip: string; i2c_address: number; params: Ht16k33ParamsView }) => Promise<UiFailure | null>;
    cancel: () => void;
  } = $props();

  let name = $state('');
  let addressInput = $state('');
  let displayType = $state<'seven_segment' | 'fourteen_segment'>('fourteen_segment');
  let numDigits = $state(4);
  let brightness = $state(8);
  let hasDot = $state(false);
  let alignRight = $state(true);
  let minimumInput = $state('0');
  let initializedModuleId: string | null | undefined;
  $effect(() => {
    const selected = module;
    const id = selected?.id ?? null;
    if (initializedModuleId === id) return;
    initializedModuleId = id;
    name = selected?.name ?? '';
    addressInput = selected?.i2c_address != null ? String(selected.i2c_address) : '';
    displayType = selected?.params?.display_type === 'seven_segment' ? 'seven_segment' : 'fourteen_segment';
    numDigits = selected?.params?.num_digits ?? 4;
    brightness = selected?.params?.brightness ?? 8;
    hasDot = selected?.params?.has_dot ?? false;
    alignRight = selected?.params?.align_right ?? true;
    minimumInput = selected === null ? '0' : selected.params?.min_value == null ? '' : String(selected.params.min_value);
  });
  let nameError = $state('');
  let addressError = $state('');
  let minimumError = $state('');
  let generalError = $state('');
  let saving = $state(false);

  const MODULE_CHIP = 'ht16k33';

  async function submit(event: SubmitEvent) {
    event.preventDefault();
    nameError = '';
    addressError = '';
    minimumError = '';
    generalError = '';
    const trimmedName = name.trim();
    const address = parseI2cAddress(addressInput);
    if (address === null) addressError = 'Enter an address between 0 and 255, like 112 or 0x70.';
    const minimum = minimumInput.trim() === '' ? null : Number(minimumInput.trim());
    if (minimum !== null && !Number.isFinite(minimum)) minimumError = 'Enter a number or leave blank for no limit.';
    if (address === null || minimumError) return;

    saving = true;
    const failure = await save({ name: trimmedName || null, module_chip: MODULE_CHIP, i2c_address: address, params: {
      display_type: displayType, num_digits: Number(numDigits), brightness: Number(brightness),
      has_dot: hasDot, align_right: alignRight, min_value: minimum,
    } });
    saving = false;
    if (failure) {
      nameError = failure.field_errors['name'] ?? '';
      addressError = failure.field_errors['i2c_address'] ?? '';
      generalError = failure.message;
    }
  }
</script>

<form id="i2c-module-form" onsubmit={submit} class="space-y-4">
  <div>
    <label class="label pb-1.5" for="display-name"><span class="label-text">Name (optional)</span></label>
    <input id="display-name" type="text" bind:value={name} placeholder="e.g. Speed display" class="input input-bordered w-full" />
    {#if nameError}<p role="alert" class="mt-1 text-xs text-error">{nameError}</p>{/if}
  </div>

  <p class="text-xs text-base-content/60">Uses an HT16K33 display driver.</p>

  <div>
    <label class="label pb-1.5" for="display-type"><span class="label-text">Display type</span></label>
    <select id="display-type" class="select select-bordered w-full" bind:value={displayType}>
      <option value="seven_segment">7-segment (numbers)</option>
      <option value="fourteen_segment">14-segment (letters and numbers)</option>
    </select>
  </div>

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

  <div>
    <label class="label pb-1.5" for="display-digits"><span class="label-text">Digits</span></label>
    <select id="display-digits" class="select select-bordered w-full" bind:value={numDigits}>
      <option value={4}>4 digits</option>
      <option value={8}>8 digits</option>
    </select>
  </div>

  <details class="border-t border-base-300 pt-3">
    <summary class="cursor-pointer font-medium text-sm py-2">Advanced display settings</summary>
    <div class="space-y-4 pt-3 text-sm">
      <div>
        <label for="display-brightness" class="block mb-2">Brightness ({brightness} of 15)</label>
        <input id="display-brightness" type="range" min="0" max="15" step="1" class="range range-sm w-full" bind:value={brightness} />
      </div>
      <div>
        <label class="label pb-1.5" for="display-minimum"><span class="label-text">Minimum value</span></label>
        <input id="display-minimum" type="text" inputmode="decimal" class="input input-bordered w-full" class:input-error={minimumError !== ''} bind:value={minimumInput} aria-describedby="display-minimum-hint" />
        {#if minimumError}<p role="alert" class="mt-1 text-xs text-error">{minimumError}</p>{/if}
        <p id="display-minimum-hint" class="mt-1 text-xs text-base-content/60">Values below this limit are shown at the limit. Leave blank for no limit.</p>
      </div>
      <label class="flex items-center gap-2"><input type="checkbox" class="checkbox checkbox-sm" bind:checked={alignRight} />Right-align value</label>
      <label class="flex items-center gap-2"><input type="checkbox" class="checkbox checkbox-sm" bind:checked={hasDot} />Display has a decimal point</label>
    </div>
  </details>

  {#if generalError}<p role="alert" class="text-sm text-error">{generalError}</p>{/if}

  <div class="mt-6 flex justify-end gap-2">
    <button type="button" class="btn btn-ghost" onclick={cancel}>Cancel</button>
    <button type="submit" class="btn btn-primary" disabled={saving}>{saving ? 'Saving…' : module ? 'Save display' : 'Add display'}</button>
  </div>
</form>
