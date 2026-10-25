import { fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { describe, expect, it, vi } from 'vitest';
import ConfigurationEdit from '../src/app/pages/configuration/ConfigurationEdit.svelte';
import type { UiBridge } from '../src/bridge/client';
import type { DeviceDetailView } from '../src/bridge/generated';

export const seededDetail: DeviceDetailView = {
  id: '7',
  name: 'Mega Panel',
  description: null,
  config_id: 4242,
  inputs: [
    { id: '11', pin: 3, kind: 'analog', sensitivity: 5, debounce: null, name: 'Throttle', calibration: { min_value: 10, max_value: 1010, has_rollover: false, is_inverted: false } },
    { id: '12', pin: 4, kind: 'button', sensitivity: null, debounce: 20, name: null, calibration: null },
  ],
  outputs: [{ id: '21', pin: 9, name: 'LED' }],
  matrices: [
    {
      id: '31',
      name: 'Matrix',
      row_pins: [
        { id: 'r1', pin: 2, pin_type: 'row', position: 0 },
        { id: 'r2', pin: 3, pin_type: 'row', position: 1 },
      ],
      col_pins: [{ id: 'c1', pin: 8, pin_type: 'col', position: 0 }],
      buttons: [],
    },
  ],
  i2c_modules: [
    { id: '41', name: 'Speed', module_chip: 'ht16k33', i2c_address: 112, params: { brightness: 8, num_digits: 4, display_type: 'seven_segment', has_dot: false, align_right: false, min_value: null } },
  ],
};

type Overrides = { [K in keyof UiBridge]?: UiBridge[K] };

export function detailBridge(overrides: Overrides = {}): UiBridge {
  const bridge = {
    getHardwareDetailByConfig: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '1', value: seededDetail } })),
    createConfiguration: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '2', value: { ...seededDetail, id: '8', name: 'New Configuration', config_id: 99 } } })),
    updateConfiguration: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '3', value: [] } })),
    createInput: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '5', value: { ...seededDetail, inputs: [...seededDetail.inputs, { id: '13', pin: 5, kind: 'analog', sensitivity: 5, debounce: null, name: 'Brake', calibration: null }] } } })),
    deleteConfiguration: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '4', value: [] } })),
    updateInput: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '6', value: seededDetail } })),
    deleteInput: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '7', value: seededDetail } })),
    createOutput: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '8', value: { ...seededDetail, outputs: [...seededDetail.outputs, { id: '22', pin: 10, name: 'Horn LED' }] } } })),
    updateOutput: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '9', value: seededDetail } })),
    deleteOutput: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '10', value: seededDetail } })),
    createMatrix: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '11', value: seededDetail } })),
    deleteMatrix: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '12', value: seededDetail } })),
    createI2cModule: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '13', value: seededDetail } })),
    updateI2cModule: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '14', value: seededDetail } })),
    deleteI2cModule: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '15', value: seededDetail } })),
    startCalibration: vi.fn(async () => ({ ok: true as const, value: '5001' })),
    advanceCalibration: vi.fn(async () => ({ ok: true as const, value: null })),
    cancelCalibration: vi.fn(async () => ({ ok: true as const, value: true })),
    calibrationCeiling: vi.fn(async () => ({ ok: true as const, value: 1023 })),
    previewInput: vi.fn(async (_id: string, raw: number) => ({ ok: true as const, value: { calibrated: raw - 10, travel: 1000, axis_percent: Math.round((raw - 10) / 10), max_hardware_value: 1023, min_notch_samples: 10 } })),
    getConfigurations: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '1', value: [] } })),
  };
  return { ...bridge, ...overrides } as unknown as UiBridge;
}

const validationFailure = { code: 'validation' as const, message: 'Check the highlighted field.', field_errors: { pin: 'Pin must be an integer between 0 and 254' }, retryable: false };

describe('ConfigurationEdit page', () => {
  it('renders the seeded snapshot with inputs, matrices, outputs and formatted i2c address', async () => {
    render(ConfigurationEdit, { props: { bridge: detailBridge(), mode: 'existing', routeId: '4242' } });
    expect(await screen.findByDisplayValue('Mega Panel')).toBeInTheDocument();
    expect(screen.getAllByDisplayValue('Throttle').length).toBeGreaterThan(0);
    expect(screen.getByText('2x1')).toBeInTheDocument();
    expect(screen.getByText('0 buttons')).toBeInTheDocument();
    expect(screen.getByText('112 (0x70)')).toBeInTheDocument();
    expect(screen.getByText('53%')).toBeInTheDocument();
    expect(screen.getByText('ID: 4242')).toBeInTheDocument();
  });

  it('sends manual output levels and display text only for an active device, reporting backend failures', async () => {
    const setPhysicalOutput = vi.fn(async () => ({ ok: true as const, value: true }));
    const testDisplay = vi.fn(async () => ({ ok: false as const, error: { code: 'unavailable' as const, message: 'Display disconnected.', field_errors: {}, retryable: true } }));
    const bridge = detailBridge({ setPhysicalOutput, testDisplay });
    const view = render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242', activePort: null } });
    await screen.findByDisplayValue('Mega Panel');
    expect(screen.getByRole('button', { name: 'Turn output 9 on' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Test display Speed' })).toBeDisabled();
    await view.rerender({ bridge, mode: 'existing', routeId: '4242', activePort: '/dev/ttyUSB0', activeGeneration: 0 });
    await fireEvent.click(screen.getByRole('button', { name: 'Turn output 9 on' }));
    await waitFor(() => expect(setPhysicalOutput).toHaveBeenCalledWith('21', true, '/dev/ttyUSB0', 0));
    expect(await screen.findByText('Sent HIGH to output 9.')).toBeInTheDocument();
    await fireEvent.click(screen.getByRole('button', { name: 'Turn output 9 off' }));
    await waitFor(() => expect(setPhysicalOutput).toHaveBeenCalledWith('21', false, '/dev/ttyUSB0', 0));
    await fireEvent.input(screen.getByRole('textbox', { name: 'Test text for display Speed' }), { target: { value: '1234' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Test display Speed' }));
    await waitFor(() => expect(testDisplay).toHaveBeenCalledWith('41', '1234', '/dev/ttyUSB0', 0));
    expect(await screen.findByText('Display disconnected.')).toBeInTheDocument();
  });

  it('retains the clicked port generation when its configuration moves before hardware acknowledgement', async () => {
    const pending = Promise.withResolvers<Awaited<ReturnType<UiBridge['setPhysicalOutput']>>>();
    const setPhysicalOutput = vi.fn(() => pending.promise);
    const bridge = detailBridge({ setPhysicalOutput });
    const view = render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242', activePort: '/dev/ttyA', activeGeneration: 7 } });
    await screen.findByDisplayValue('Mega Panel');
    await fireEvent.click(screen.getByRole('button', { name: 'Turn output 9 on' }));
    await view.rerender({ bridge, mode: 'existing', routeId: '4242', activePort: '/dev/ttyB', activeGeneration: 8 });
    pending.resolve({ ok: false, error: { code: 'conflict', message: 'Original device connection changed.', field_errors: {}, retryable: true } });
    await waitFor(() => expect(setPhysicalOutput).toHaveBeenCalledWith('21', true, '/dev/ttyA', 7));
    expect(await screen.findByText('Original device connection changed.')).toBeInTheDocument();
    expect(screen.queryByText('Sent HIGH to output 9.')).not.toBeInTheDocument();
  });

  it('surfaces a failed detail load as an inline error with a way back', async () => {
    const bridge = detailBridge({
      getHardwareDetailByConfig: vi.fn(async () => ({ ok: false as const, error: { code: 'not_found' as const, message: 'The requested configuration was not found.', field_errors: {}, retryable: false } })),
    });
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '9999' } });
    expect(await screen.findByRole('alert')).toHaveTextContent('The requested configuration was not found.');
    expect(screen.getByRole('link', { name: 'Back to Configurations' })).toHaveAttribute('href', '#/');
  });

  it('autosaves device name edits through ui_update_configuration', async () => {
    const bridge = detailBridge();
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242' } });
    const name = await screen.findByLabelText('Configuration Name');
    await fireEvent.input(name, { target: { value: 'Mega Panel v2' } });
    await fireEvent.change(name);
    await waitFor(() => expect(bridge.updateConfiguration).toHaveBeenCalledWith('7', { name: 'Mega Panel v2', description: null }));
  });

  it('keeps device name validation inline when the name is blank', async () => {
    render(ConfigurationEdit, { props: { bridge: detailBridge(), mode: 'existing', routeId: '4242' } });
    const name = await screen.findByLabelText('Configuration Name');
    await fireEvent.input(name, { target: { value: '' } });
    await fireEvent.change(name);
    expect(await screen.findByRole('alert')).toHaveTextContent('Name is required');
  });

  it('adds an input on submit and refreshes the list from the detail snapshot', async () => {
    const bridge = detailBridge();
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: '＋ Add Input' }));
    await fireEvent.input(screen.getByLabelText('Name (optional)'), { target: { value: 'Brake' } });
    await fireEvent.input(screen.getByLabelText('Pin Number'), { target: { value: '5' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Add Input' }));
    await waitFor(() => expect(bridge.createInput).toHaveBeenCalledWith(expect.objectContaining({ device_id: '7', pin: 5, kind: 'analog', sensitivity: 5, debounce: null, name: 'Brake' })));
    expect(await screen.findByDisplayValue('Brake')).toBeInTheDocument();
  });

  it('renders client-side pin validation inline before any command', async () => {
    render(ConfigurationEdit, { props: { bridge: detailBridge(), mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: '＋ Add Input' }));
    await fireEvent.click(screen.getByRole('button', { name: 'Add Input' }));
    expect(await screen.findByText('Pin must be an integer between 0 and 254')).toBeInTheDocument();
  });

  it('renders UiFailure field_errors inline when the backend rejects an input', async () => {
    const rejecting = detailBridge({ createInput: vi.fn(async () => ({ ok: false as const, error: validationFailure })) });
    render(ConfigurationEdit, { props: { bridge: rejecting, mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: '＋ Add Input' }));
    await fireEvent.input(screen.getByLabelText('Pin Number'), { target: { value: '5' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Add Input' }));
    expect(await screen.findByText('Pin must be an integer between 0 and 254')).toBeInTheDocument();
    expect(rejecting.createInput).toHaveBeenCalled();
  });

  it('validates sensitivity for analog inputs and debounce for buttons inline', async () => {
    render(ConfigurationEdit, { props: { bridge: detailBridge(), mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: '＋ Add Input' }));
    await fireEvent.input(screen.getByLabelText('Pin Number'), { target: { value: '6' } });
    await fireEvent.input(screen.getByLabelText('Sensitivity (1-10)'), { target: { value: '42' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Add Input' }));
    expect(await screen.findByText('Sensitivity must be between 1 and 10')).toBeInTheDocument();

    await fireEvent.change(screen.getByLabelText('Input Type'), { target: { value: 'button' } });
    await fireEvent.input(screen.getByLabelText('Debounce (0-255 ms)'), { target: { value: '999' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Add Input' }));
    expect(await screen.findByText('Debounce must be between 0 and 255 ms')).toBeInTheDocument();
  });

  it('deletes inputs through ui_delete_input', async () => {
    const bridge = detailBridge();
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Delete input 3' }));
    await waitFor(() => expect(bridge.deleteInput).toHaveBeenCalledWith('11'));
  });

  it('previews and creates a matrix from comma-separated pins', async () => {
    const bridge = detailBridge();
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: '＋ Add Matrix' }));
    await fireEvent.input(screen.getByLabelText('Row Pins'), { target: { value: '2, 3' } });
    await fireEvent.input(screen.getByLabelText('Column Pins'), { target: { value: '8' } });
    expect(await screen.findByText('2x1 = 2 buttons')).toBeInTheDocument();
    expect(screen.getByText('129')).toBeInTheDocument();
    await fireEvent.click(screen.getByRole('button', { name: 'Add Matrix' }));
    await waitFor(() => expect(bridge.createMatrix).toHaveBeenCalledWith({ device_id: '7', name: 'Matrix', row_pins: [2, 3], col_pins: [8] }));
  });

  it('keeps matrix pin errors inline: required, duplicate and row/col overlap', async () => {
    render(ConfigurationEdit, { props: { bridge: detailBridge(), mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: '＋ Add Matrix' }));
    await fireEvent.click(screen.getByRole('button', { name: 'Add Matrix' }));
    expect(await screen.findByText('At least one row pin is required')).toBeInTheDocument();
    expect(screen.getByText('At least one column pin is required')).toBeInTheDocument();

    await fireEvent.input(screen.getByLabelText('Row Pins'), { target: { value: '2, 2' } });
    await fireEvent.input(screen.getByLabelText('Column Pins'), { target: { value: '2' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Add Matrix' }));
    expect(await screen.findByText('Duplicate pins are not allowed')).toBeInTheDocument();
    expect(screen.getByText('Row and column pins cannot overlap')).toBeInTheDocument();
  });

  it('adds and deletes outputs', async () => {
    const bridge = detailBridge();
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: '＋ Add Output' }));
    await fireEvent.input(screen.getByLabelText('Pin Number'), { target: { value: '10' } });
    await fireEvent.input(screen.getByLabelText('Name (optional)'), { target: { value: 'Horn LED' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Add Output' }));
    await waitFor(() => expect(bridge.createOutput).toHaveBeenCalledWith({ device_id: '7', pin: 10, name: 'Horn LED' }));
    expect(await screen.findByDisplayValue('Horn LED')).toBeInTheDocument();

    await fireEvent.click(screen.getByRole('button', { name: 'Delete output 9' }));
    await waitFor(() => expect(bridge.deleteOutput).toHaveBeenCalledWith('21'));
  });

  it('rejects output pins outside 0-255 inline', async () => {
    render(ConfigurationEdit, { props: { bridge: detailBridge(), mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: '＋ Add Output' }));
    await fireEvent.input(screen.getByLabelText('Pin Number'), { target: { value: '300' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Add Output' }));
    expect(await screen.findByText('Pin must be an integer between 0 and 255')).toBeInTheDocument();
  });

  it('creates a display from the i2c form, parsing hex addresses like the Elixir parser', async () => {
    const bridge = detailBridge();
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: '＋ Add display' }));
    await fireEvent.input(screen.getByLabelText('Name (optional)'), { target: { value: 'Speed 2' } });
    await fireEvent.input(screen.getByLabelText('I2C address'), { target: { value: '0x71' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Add display' }));
    await waitFor(() => expect(bridge.createI2cModule).toHaveBeenCalledWith({ device_id: '7', name: 'Speed 2', module_chip: 'ht16k33', i2c_address: 113,
      params: { brightness: 8, num_digits: 4, display_type: 'fourteen_segment', has_dot: false, align_right: true, min_value: 0 } }));
  });

  it('creates an unnamed display using the retained advanced defaults', async () => {
    const bridge = detailBridge();
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: '＋ Add display' }));
    expect(screen.getByLabelText('Display type')).toHaveValue('fourteen_segment');
    await fireEvent.click(screen.getByText('Advanced display settings'));
    expect(screen.getByLabelText('Right-align value')).toBeChecked();
    expect(screen.getByLabelText('Minimum value')).toHaveValue('0');
    await fireEvent.input(screen.getByLabelText('I2C address'), { target: { value: '0x72' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Add display' }));
    await waitFor(() => expect(bridge.createI2cModule).toHaveBeenCalledWith({ device_id: '7', name: null, module_chip: 'ht16k33', i2c_address: 114,
      params: { brightness: 8, num_digits: 4, display_type: 'fourteen_segment', has_dot: false, align_right: true, min_value: 0 } }));
  });

  it('clears an existing display name while preserving its persisted null minimum', async () => {
    const bridge = detailBridge();
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Edit display Speed' }));
    await fireEvent.input(screen.getByLabelText('Name (optional)'), { target: { value: '' } });
    await fireEvent.click(screen.getByText('Advanced display settings'));
    expect(screen.getByLabelText('Minimum value')).toHaveValue('');
    await fireEvent.click(screen.getByRole('button', { name: 'Save display' }));
    await waitFor(() => expect(bridge.updateI2cModule).toHaveBeenCalledWith({ id: '41', name: null, module_chip: 'ht16k33', i2c_address: 112,
      params: { brightness: 8, num_digits: 4, display_type: 'seven_segment', has_dot: false, align_right: false, min_value: null } }));
  });

  it('edits and deletes displays, preserving and changing advanced HT16K33 params', async () => {
    const bridge = detailBridge();
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Edit display Speed' }));
    expect(await screen.findByText('Advanced display settings')).toBeInTheDocument();
    expect(screen.getByLabelText('Display type')).toHaveValue('seven_segment');
    expect(screen.getByLabelText('Digits')).toHaveValue('4');
    await fireEvent.input(screen.getByLabelText('I2C address'), { target: { value: '300' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Save display' }));
    expect(await screen.findByText('Enter an address between 0 and 255, like 112 or 0x70.')).toBeInTheDocument();

    await fireEvent.click(screen.getByRole('button', { name: 'Cancel' }));
    await fireEvent.click(screen.getByRole('button', { name: 'Delete display Speed' }));
    await waitFor(() => expect(bridge.deleteI2cModule).toHaveBeenCalledWith('41'));
  });

  it('sends all edited display settings and can explicitly clear the minimum', async () => {
    const updateI2cModule = vi.fn(async (payload: Parameters<UiBridge['updateI2cModule']>[0]) => ({ ok: true as const, value: {
      epoch: '1', topic: 'hardware' as const, revision: '14', value: { ...seededDetail, i2c_modules: [{ ...seededDetail.i2c_modules[0], params: payload.params ?? null }] },
    } }));
    const bridge = detailBridge({ updateI2cModule });
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Edit display Speed' }));
    await fireEvent.change(screen.getByLabelText('Display type'), { target: { value: 'fourteen_segment' } });
    await fireEvent.change(screen.getByLabelText('Digits'), { target: { value: '8' } });
    await fireEvent.click(screen.getByText('Advanced display settings'));
    await fireEvent.input(screen.getByLabelText(/Brightness/), { target: { value: '13' } });
    await fireEvent.input(screen.getByLabelText('Minimum value'), { target: { value: '12.5' } });
    await fireEvent.click(screen.getByLabelText('Right-align value'));
    await fireEvent.click(screen.getByLabelText('Display has a decimal point'));
    await fireEvent.click(screen.getByRole('button', { name: 'Save display' }));
    await waitFor(() => expect(updateI2cModule).toHaveBeenCalledWith({ id: '41', name: 'Speed', module_chip: 'ht16k33', i2c_address: 112,
      params: { brightness: 13, num_digits: 8, display_type: 'fourteen_segment', has_dot: true, align_right: true, min_value: 12.5 } }));

    await fireEvent.click(await screen.findByRole('button', { name: 'Edit display Speed' }));
    await fireEvent.click(screen.getByText('Advanced display settings'));
    expect(screen.getByLabelText('Minimum value')).toHaveValue('12.5');
    await fireEvent.input(screen.getByLabelText('Minimum value'), { target: { value: '' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Save display' }));
    await waitFor(() => expect(updateI2cModule).toHaveBeenLastCalledWith(expect.objectContaining({ params: expect.objectContaining({ min_value: null }) })));
  });

  it('keeps advanced display edits available after Rust rejects their values', async () => {
    const bridge = detailBridge({ updateI2cModule: vi.fn(async () => ({ ok: false as const, error: {
      code: 'validation' as const, message: 'Display parameters are invalid.', field_errors: { params: 'Unsupported combination.' }, retryable: false,
    } })) });
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242' } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Edit display Speed' }));
    await fireEvent.change(screen.getByLabelText('Display type'), { target: { value: 'fourteen_segment' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Save display' }));
    expect(await screen.findByText('Display parameters are invalid.')).toBeInTheDocument();
    expect(screen.getByLabelText('Display type')).toHaveValue('fourteen_segment');
    expect(screen.getByRole('button', { name: 'Save display' })).toBeInTheDocument();
  });

  it('creates a configuration in new mode and reports the new public config id', async () => {
    const bridge = detailBridge();
    const created = vi.fn();
    render(ConfigurationEdit, { props: { bridge, mode: 'new', created } });
    const name = await screen.findByLabelText('Configuration Name');
    await fireEvent.input(name, { target: { value: 'Fresh Panel' } });
    await fireEvent.change(name);
    await waitFor(() => expect(bridge.createConfiguration).toHaveBeenCalledWith('Fresh Panel', null));
    await waitFor(() => expect(created).toHaveBeenCalledWith('99'));
  });

  it('deletes an existing configuration after confirmation and notifies the shell', async () => {
    const bridge = detailBridge();
    const deleted = vi.fn();
    render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242', deleted } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Delete Configuration' }));
    await fireEvent.click(await screen.findByRole('button', { name: 'Delete' }));
    await waitFor(() => expect(bridge.deleteConfiguration).toHaveBeenCalledWith('7'));
    await waitFor(() => expect(deleted).toHaveBeenCalled());
  });

  it('shows live values from the hardware input feed when a device is active', async () => {
    const { rerender } = render(ConfigurationEdit, {
      props: { bridge: detailBridge(), mode: 'existing', routeId: '4242', activePort: 'live', inputValues: { 3: 512, 4: 1 } },
    });
    expect(await screen.findByText('Pressed')).toBeInTheDocument();
    expect(screen.getByText('512')).toBeInTheDocument();
    expect(await screen.findByText('502')).toBeInTheDocument(); // calibrated travel units from Rust

    rerender({ bridge: detailBridge(), mode: 'existing', routeId: '4242', activePort: null, inputValues: {} });
    expect((await screen.findAllByText('N/A')).length).toBeGreaterThanOrEqual(2);
  });

  it('ignores a stale calibrated reading after the hardware sample changes', async () => {
    const slow = Promise.withResolvers<{ ok: true; value: { calibrated: number; travel: number; axis_percent: number; max_hardware_value: number; min_notch_samples: number } }>();
    const previewInput = vi.fn(async (_id: string, raw: number) => raw === 300 ? slow.promise : {
      ok: true as const, value: { calibrated: 901, travel: 1000, axis_percent: 90, max_hardware_value: 4095, min_notch_samples: 10 },
    });
    const bridge = detailBridge({ previewInput });
    const view = render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242', activePort: 'live', inputValues: {} } });
    await screen.findByDisplayValue('Mega Panel');
    await view.rerender({ bridge, mode: 'existing', routeId: '4242', activePort: 'live', inputValues: { 3: 300 } });
    await waitFor(() => expect(previewInput).toHaveBeenCalledWith('11', 300));
    await view.rerender({ bridge, mode: 'existing', routeId: '4242', activePort: 'live', inputValues: { 3: 700 } });
    expect(await screen.findByText('901')).toBeInTheDocument();
    slow.resolve({ ok: true, value: { calibrated: 301, travel: 1000, axis_percent: 30, max_hardware_value: 4095, min_notch_samples: 10 } });
    await waitFor(() => expect(screen.getByText('901')).toBeInTheDocument());
    expect(screen.queryByText('301')).not.toBeInTheDocument();
  });

  it('marks matrix buttons as tested from live virtual-pin presses and opens the test wizard', async () => {
    const bridge = detailBridge();
    const { rerender } = render(ConfigurationEdit, { props: { bridge, mode: 'existing', routeId: '4242', activePort: 'live', inputValues: {} } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Test' }));
    expect(await screen.findByRole('dialog', { name: 'Test Matrix' })).toBeInTheDocument();

    rerender({ bridge, mode: 'existing', routeId: '4242', activePort: 'live', inputValues: { 128: 1 } });
    await waitFor(() => expect(screen.getByText('1 / 2 buttons tested')).toBeInTheDocument());
    expect(screen.getByText(/\(50%\)/)).toBeInTheDocument();
  });

  it('gates calibration and matrix testing behind an active device like the LiveView flash', async () => {
    render(ConfigurationEdit, { props: { bridge: detailBridge(), mode: 'existing', routeId: '4242', activePort: null } });
    expect(screen.queryByRole('button', { name: 'Calibrate' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Test' })).not.toBeInTheDocument();
  });
});
