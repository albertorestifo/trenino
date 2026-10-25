import type { UiBridge } from '../bridge/client';
import type { CalibrationView, I2cModuleView, InputView, OutputView } from '../bridge/generated';

export type HardwareInputOption = {
  id: string;
  device_id: string;
  device_name: string;
  pin: number | null;
  kind: 'analog' | 'button';
  name: string | null;
  calibration: CalibrationView | null;
};

export type HardwareOutputOption = {
  id: string;
  device_name: string;
  pin: number;
  name: string | null;
};

export type HardwareDisplayOption = {
  id: string;
  device_name: string;
  name: string | null;
  module_chip: string;
  i2c_address: number;
  num_digits: number | null;
  has_dot: boolean | null;
};

export type HardwareCatalog = {
  inputs: HardwareInputOption[];
  outputs: HardwareOutputOption[];
  displays: HardwareDisplayOption[];
};

export const EMPTY_HARDWARE_CATALOG: HardwareCatalog = { inputs: [], outputs: [], displays: [] };

/**
 * Aggregates every configuration's inputs, outputs and I2C modules
 * (`ui_list_configurations` → `ui_get_hardware_detail` per device).
 */
export async function collectHardware(bridge: UiBridge): Promise<{ catalog: HardwareCatalog; error: string | null }> {
  const catalog: HardwareCatalog = { inputs: [], outputs: [], displays: [] };
  let previewError: string | null = null;
  const configurations = await bridge.getConfigurations();
  if (!configurations.ok) return { catalog, error: configurations.error.message };
  for (const summary of configurations.value.value) {
    const detail = await bridge.getHardwareDetail(summary.device_id);
    if (!detail.ok) return { catalog, error: detail.error.message };
    const device = detail.value.value;
    const deviceName = device.name ?? `Device ${device.id}`;
    const inputs = await Promise.all(device.inputs.map(async (input) => {
      const option = inputOption(input, device.id, deviceName);
      if (option.kind === 'analog' && option.calibration) {
        const preview = await bridge.previewInput(option.id, option.calibration.min_value ?? 0);
        if (!preview.ok) {
          option.calibration = null;
          previewError ??= `Calibration preview is unavailable for ${option.name || `Pin ${option.pin}`}: ${preview.error.message}`;
        }
      }
      return option;
    }));
    catalog.inputs.push(...inputs);
    catalog.outputs.push(...device.outputs.map((output) => outputOption(output, deviceName)));
    catalog.displays.push(...device.i2c_modules.map((module) => displayOption(module, deviceName)));
  }
  return { catalog, error: previewError };
}

function inputOption(input: InputView, deviceId: string, deviceName: string): HardwareInputOption {
  return {
    id: input.id,
    device_id: deviceId,
    device_name: deviceName,
    pin: input.pin,
    kind: input.kind === 'button' ? 'button' : 'analog',
    name: input.name,
    calibration: input.calibration,
  };
}

function outputOption(output: OutputView, deviceName: string): HardwareOutputOption {
  return { id: output.id, device_name: deviceName, pin: output.pin, name: output.name };
}

function displayOption(module: I2cModuleView, deviceName: string): HardwareDisplayOption {
  return {
    id: module.id,
    device_name: deviceName,
    name: module.name,
    module_chip: module.module_chip,
    i2c_address: module.i2c_address,
    num_digits: module.params?.num_digits ?? null,
    has_dot: module.params?.has_dot ?? null,
  };
}

export function formatI2cAddress(address: number): string {
  return `0x${address.toString(16).toUpperCase().padStart(2, '0')}`;
}
