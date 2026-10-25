import { fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { describe, expect, it, vi } from 'vitest';
import TrainEdit from '../src/app/pages/trains/TrainEdit.svelte';
import ScriptEdit from '../src/app/pages/scripts/ScriptEdit.svelte';
import Firmware from '../src/app/pages/firmware/Firmware.svelte';
import OutputBindingWizard from '../src/components/wizards/OutputBindingWizard.svelte';
import DisplayBindingWizard from '../src/components/wizards/DisplayBindingWizard.svelte';
import LeverSetupWizard from '../src/components/wizards/LeverSetupWizard.svelte';
import type { HardwareCatalog } from '../src/app/hardware';
import { createBridge, type IpcTransport } from '../src/bridge/client';
import { createFakeBridge, flushPromises, snapshot } from './helpers';
import type { ElementView, FirmwareView, ScriptsView, TrainDetailView } from '../src/bridge/generated';

const train: TrainDetailView = { id: '10', name: 'Saved train', description: null, identifiers: ['ICE'], elements: [], sequences: [] };
const hardware: HardwareCatalog = {
  inputs: [],
  outputs: [{ id: '60', device_name: 'Board', pin: 4, name: 'Lamp' }],
  displays: [{ id: '70', device_name: 'Board', name: 'Speed', module_chip: 'ht16k33', i2c_address: 112, num_digits: 4, has_dot: true }],
};
const mappedLever: ElementView = { id: '80', kind: 'lever', name: 'Throttle', lever_config: {
  id: '81', min_endpoint: 'Min', max_endpoint: 'Max', value_endpoint: 'Value',
  notch_count_endpoint: null, notch_index_endpoint: null, lever_type: 'discrete', inverted: false,
  calibrated_at: null, notches: [{ id: '82', index: 0, kind: 'linear', value: null, min_value: 0,
    max_value: 1, input_min: 0.25, input_max: 0.75, sim_input_min: 0, sim_input_max: 1, description: 'Drive' }],
} };
const leverHardware: HardwareCatalog = { ...hardware, inputs: [{ id: '11', device_id: '7', device_name: 'Panel', pin: 3,
  kind: 'analog', name: 'Throttle', calibration: { min_value: 0, max_value: 4095, has_rollover: false, is_inverted: false } }] };

function mappingAck(detail: TrainDetailView | null, valid: boolean, gaps: { from: number; to: number }[] = [], refresh_required = false) {
  return { committed: true as const, lever_config_id: '81', inverted: false,
    train_detail: detail === null ? null : snapshot('trains', detail),
    validation: snapshot('trains', { valid, gaps }), refresh_required };
}

describe('recovered workflows', () => {
  it('uses a live unknown simulator identifier and preserves header edits across status changes', async () => {
    const deleteTrain = vi.fn();
    const bridge = createFakeBridge({
      deleteTrain,
      getTrainDetail: vi.fn(async () => ({ ok: true as const, value: snapshot('trains', train) })),
      getTrains: vi.fn(async () => ({ ok: true as const, value: snapshot('trains', [{ id: '10', name: 'Saved train', description: null, identifiers: ['ICE'], element_count: 0, active: false }]) })),
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [], button: [], output: [], display: [] }) })),
      getScripts: vi.fn(async () => ({ ok: true as const, value: snapshot('scripts', { scripts: [] }) })),
    });
    const route = { page: 'train' as const, path: '/trains/10', trainId: '10', query: new URLSearchParams() };
    const firstStatus = { status: 'connected', last_error: null, active_train_id: '10', detected_identifier: 'UNKNOWN/Vehicle-A' };
    const view = render(TrainEdit, { props: { bridge, route, simulatorStatus: firstStatus } });
    await screen.findByDisplayValue('Saved train');
    await fireEvent.input(screen.getByLabelText('Train Name'), { target: { value: 'Unsaved header' } });
    expect(screen.getByText('UNKNOWN/Vehicle-A')).toBeInTheDocument();
    await fireEvent.click(screen.getByRole('button', { name: 'Use current train ID' }));
    expect(screen.getAllByTestId('train-identifier').map((input) => (input as HTMLInputElement).value)).toContain('UNKNOWN/Vehicle-A');
    expect(screen.getByTestId('delete-train')).toBeDisabled();
    expect(screen.getByText('Cannot delete while train is currently active')).toBeInTheDocument();
    await view.rerender({ bridge, route, simulatorStatus: firstStatus, simulatorError: 'Status read failed.' });
    expect(screen.getByTestId('delete-train')).toBeDisabled();
    expect(screen.getByText('UNKNOWN/Vehicle-A')).toBeInTheDocument();
    await view.rerender({ bridge, route, simulatorStatus: { ...firstStatus, active_train_id: null }, simulatorError: 'Status read failed.' });
    expect(screen.getByTestId('delete-train')).toBeDisabled();
    expect(screen.getByText('Cannot delete until simulator train activity is known.')).toBeInTheDocument();
    await fireEvent.click(screen.getByTestId('delete-train'));
    expect(deleteTrain).not.toHaveBeenCalled();
    await view.rerender({ bridge, route, simulatorStatus: { ...firstStatus, active_train_id: null, detected_identifier: 'UNKNOWN/Vehicle-B' }, simulatorError: '' });
    expect(screen.getByLabelText('Train Name')).toHaveValue('Unsaved header');
    expect(screen.getByText('UNKNOWN/Vehicle-B')).toBeInTheDocument();
    expect(screen.getByTestId('delete-train')).toBeEnabled();
    await fireEvent.click(screen.getByTestId('delete-train'));
    expect(screen.getByTestId('confirm-delete-train')).toBeEnabled();
    await view.rerender({ bridge, route, simulatorStatus: { ...firstStatus, active_train_id: null, detected_identifier: 'UNKNOWN/Vehicle-B' }, simulatorError: 'Status read failed.' });
    expect(screen.getByTestId('confirm-delete-train')).toBeDisabled();
    await fireEvent.click(screen.getByTestId('confirm-delete-train'));
    expect(deleteTrain).not.toHaveBeenCalled();
  });

  it('blocks train deletion before any authoritative simulator status arrives', async () => {
    const deleteTrain = vi.fn();
    const bridge = createFakeBridge({
      getTrainDetail: vi.fn(async () => ({ ok: true as const, value: snapshot('trains', train) })),
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [], button: [], output: [], display: [] }) })),
      getScripts: vi.fn(async () => ({ ok: true as const, value: snapshot('scripts', { scripts: [] }) })),
      deleteTrain,
    });
    render(TrainEdit, { props: { bridge, route: { page: 'train', path: '/trains/10', trainId: '10', query: new URLSearchParams() } } });
    await screen.findByDisplayValue('Saved train');
    expect(screen.getByTestId('delete-train')).toBeDisabled();
    expect(screen.getByText('Cannot delete until simulator train activity is known.')).toBeInTheDocument();
    await fireEvent.click(screen.getByTestId('delete-train'));
    expect(deleteTrain).not.toHaveBeenCalled();
  });

  it('scrolls to train sections without sending a section fragment to the hash router', async () => {
    const bridge = createFakeBridge({
      getTrainDetail: vi.fn(async () => ({ ok: true as const, value: snapshot('trains', train) })),
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [], button: [], output: [], display: [] }) })),
      getScripts: vi.fn(async () => ({ ok: true as const, value: snapshot('scripts', { scripts: [] }) })),
    });
    location.hash = '#/trains/10';
    render(TrainEdit, { props: { bridge, route: { page: 'train', path: '/trains/10', trainId: '10', query: new URLSearchParams() } } });
    const section = (await screen.findByRole('heading', { name: 'Automation', level: 2 })).closest('section');
    const scrollIntoView = vi.fn();
    if (section) section.scrollIntoView = scrollIntoView;
    await fireEvent.click(screen.getByRole('link', { name: 'Automation' }));
    expect(location.hash).toBe('#/trains/10');
    expect(scrollIntoView).toHaveBeenCalled();
    expect(screen.getByRole('heading', { name: 'Edit train' })).toBeInTheDocument();
  });
  it('creates a new train from the identifier deep link without writing on mount', async () => {
    const createTrain = vi.fn(async () => ({ ok: true as const, value: snapshot('trains', train) }));
    const bridge = createFakeBridge({ createTrain });
    location.hash = '#/trains/new?identifier=ICE';
    render(TrainEdit, { props: { bridge, route: { page: 'train-new', path: '/trains/new', query: new URLSearchParams('identifier=ICE') } } });
    expect(await screen.findByDisplayValue('ICE')).toBeInTheDocument();
    expect(createTrain).not.toHaveBeenCalled();
    await fireEvent.input(screen.getByLabelText('Train Name'), { target: { value: 'Saved train' } });
    await fireEvent.click(screen.getByTestId('save-train'));
    await waitFor(() => expect(createTrain).toHaveBeenCalledWith({ name: 'Saved train', description: null, identifiers: ['ICE'] }));
  });

  it('preserves dirty train header fields when a child binding wizard completes', async () => {
    const bindings = { lever: [], button: [], output: [], display: [] };
    const bridge = createFakeBridge({
      getTrainDetail: vi.fn(async () => ({ ok: true as const, value: snapshot('trains', train) })),
      getTrains: vi.fn(async () => ({ ok: true as const, value: snapshot('trains', []) })),
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', bindings) })),
      getScripts: vi.fn(async () => ({ ok: true as const, value: snapshot('scripts', { scripts: [] }) })),
      getConfigurations: vi.fn(async () => ({ ok: true as const, value: snapshot('hardware', [{ device_id: '7', config_id: 42, name: 'Board', description: null, input_count: 0, active: false }]) })),
      getHardwareDetail: vi.fn(async () => ({ ok: true as const, value: snapshot('hardware', { id: '7', name: 'Board', description: null, config_id: 42,
        inputs: [], outputs: [{ id: '60', pin: 4, name: 'Lamp' }], matrices: [], i2c_modules: [] }) })),
      createOutputBinding: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', bindings) })),
    });
    render(TrainEdit, { props: { bridge, route: { page: 'train', path: '/trains/10', trainId: '10', query: new URLSearchParams() } } });
    await screen.findByDisplayValue('Saved train');
    await fireEvent.input(screen.getByLabelText('Train Name'), { target: { value: 'Unsaved name' } });
    await fireEvent.input(screen.getByLabelText('Description'), { target: { value: 'Unsaved description' } });
    await fireEvent.input(screen.getByTestId('train-identifier'), { target: { value: 'UNSAVED' } });
    await fireEvent.click(await screen.findByTestId('add-output-binding'));
    await fireEvent.input(screen.getByTestId('output-endpoint'), { target: { value: 'Speed' } });
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.click(screen.getByTestId('output-option'));
    await fireEvent.click(screen.getByTestId('output-type-led'));
    await fireEvent.input(screen.getByTestId('output-binding-name'), { target: { value: 'Lamp warning' } });
    await waitFor(() => expect(screen.getByTestId('save-output-binding')).toBeEnabled());
    await fireEvent.click(screen.getByTestId('save-output-binding'));
    await waitFor(() => expect(screen.queryByTestId('save-output-binding')).not.toBeInTheDocument());
    expect(screen.getByLabelText('Train Name')).toHaveValue('Unsaved name');
    expect(screen.getByLabelText('Description')).toHaveValue('Unsaved description');
    expect(screen.getByTestId('train-identifier')).toHaveValue('UNSAVED');
  });

  it('runs the persisted script ID and keeps unsaved editor text out of execution', async () => {
    const scripts: ScriptsView = { scripts: [{ id: '20', train_id: '10', name: 'Saved script', enabled: false, code: 'print("saved")', triggers: [] }] };
    const runScript = vi.fn(async () => ({ ok: true as const, value: true }));
    const getScriptLog = vi.fn(async () => ({ ok: true as const, value: ['saved output'] }));
    const updateScript = vi.fn();
    const bridge = createFakeBridge({
      getTrainDetail: vi.fn(async () => ({ ok: true as const, value: snapshot('trains', train) })),
      getScripts: vi.fn(async () => ({ ok: true as const, value: snapshot('scripts', scripts) })),
      runScript,
      getScriptLog,
      updateScript,
    });
    render(ScriptEdit, { props: { bridge, route: { page: 'script', path: '/trains/10/scripts/20', trainId: '10', scriptId: '20' } } });
    const editor = await screen.findByTestId('script-code');
    await fireEvent.input(editor, { target: { value: 'print("unsaved")' } });
    await fireEvent.click(screen.getByTestId('run-script'));
    await waitFor(() => expect(runScript).toHaveBeenCalledWith('20'));
    expect(updateScript).not.toHaveBeenCalled();
    expect(await screen.findByText('saved output')).toBeInTheDocument();
  });

  it('reports a saved script as unavailable when Rust acknowledges no execution', async () => {
    const scripts: ScriptsView = { scripts: [{ id: '20', train_id: '10', name: 'Saved script', enabled: false, code: 'print("saved")', triggers: [] }] };
    const bridge = createFakeBridge({
      getTrainDetail: vi.fn(async () => ({ ok: true as const, value: snapshot('trains', train) })),
      getScripts: vi.fn(async () => ({ ok: true as const, value: snapshot('scripts', scripts) })),
      getScriptLog: vi.fn(async () => ({ ok: true as const, value: [] })),
      runScript: vi.fn(async () => ({ ok: true as const, value: false })),
    });
    render(ScriptEdit, { props: { bridge, route: { page: 'script', path: '/trains/10/scripts/20', trainId: '10', scriptId: '20' } } });
    await fireEvent.click(await screen.findByTestId('run-script'));
    expect(await screen.findByText(/script is unavailable/i)).toBeInTheDocument();
    expect(screen.queryByText('Saved script triggered')).not.toBeInTheDocument();
  });

  it('selects an inventoried firmware port with generation zero without needing an input sample', async () => {
    const firmware: FirmwareView = {
      releases: [{ id: '30', version: '1.2', tag_name: 'v1.2', release_url: null, release_notes: null, published_at: null,
        files: [{ id: '40', release_id: '30', board_type: 'controller', environment: 'mega', download_url: 'https://example.test/file.hex', file_size: null, checksum_sha256: null }] }],
      update_checks: [], upload_history: [],
    };
    const startFirmwareUpload = vi.fn(async () => ({ ok: true as const, value: 'upload-1' }));
    const bridge = createFakeBridge({
      getFirmware: vi.fn(async () => ({ ok: true as const, value: snapshot('firmware', firmware) })),
      downloadFirmware: vi.fn(async () => ({ ok: true as const, value: snapshot('firmware', firmware) })),
      serialPorts: vi.fn(async () => ({ ok: true as const, value: [{ port: '/dev/ttyUSB0', generation: 0, config_id: null, device_id: null, status: 'available' as const }] })),
      startFirmwareUpload,
    });
    const view = render(Firmware, { props: { bridge, ports: [] } });
    expect(await screen.findByText('Size unknown')).toBeInTheDocument();
    await fireEvent.click(await screen.findByTestId('upload-to-device'));
    await fireEvent.change(screen.getByTestId('upload-environment'), { target: { value: 'mega' } });
    expect(screen.getByTestId('start-upload')).toBeDisabled();
    expect(startFirmwareUpload).not.toHaveBeenCalled();
    await view.rerender({ bridge, ports: [{ port: '/dev/ttyUSB0', generation: 0, config_id: null, device_id: null, status: 'available' }] });
    await fireEvent.change(screen.getByTestId('upload-port'), { target: { value: '/dev/ttyUSB0' } });
    await fireEvent.click(screen.getByTestId('start-upload'));
    await waitFor(() => expect(startFirmwareUpload).toHaveBeenCalledWith('40', '/dev/ttyUSB0', 'mega', 0));
  });

  it('passes the train ID in update IPC and disposes filtered hardware input events', async () => {
    let hardwareEvent: ((payload: unknown) => void) | undefined;
    const stop = vi.fn();
    const invoke = vi.fn(async () => snapshot('trains', train));
    const transport: IpcTransport = {
      isDesktop: () => true,
      invoke,
      listen: vi.fn(async (event, handler) => {
        if (event === 'ui://hardware/input') hardwareEvent = handler;
        return stop;
      }),
    };
    const bridge = createBridge(transport);
    await bridge.updateTrain('10', { name: 'Renamed' });
    expect(invoke).toHaveBeenCalledWith('ui_update_train', { id: '10', name: 'Renamed' });
    await bridge.previewNotchMapping('11', [{ sim_input_min: 0, sim_input_max: 1 }], [], true);
    expect(invoke).toHaveBeenCalledWith('ui_preview_notch_mapping', { input_id: '11', notches: [{ sim_input_min: 0, sim_input_max: 1 }], captured: [], auto_distribute: true });
    await bridge.beginApplyConfiguration('7', '/dev/ttyUSB0', 0);
    expect(invoke).toHaveBeenCalledWith('ui_begin_apply_configuration', { device_id: '7', port: '/dev/ttyUSB0', generation: 0 });
    await bridge.setPhysicalOutput('21', true, '/dev/ttyUSB0', 0);
    expect(invoke).toHaveBeenCalledWith('ui_set_physical_output', { output_id: '21', high: true, port: '/dev/ttyUSB0', generation: 0 });
    await bridge.testDisplay('41', '1234', '/dev/ttyUSB0', 0);
    expect(invoke).toHaveBeenCalledWith('ui_test_display', { module_id: '41', text: '1234', port: '/dev/ttyUSB0', generation: 0 });
    await bridge.listSimulatorEndpoints('CurrentDrivableActor');
    expect(invoke).toHaveBeenCalledWith('ui_list_simulator_endpoints', { path: 'CurrentDrivableActor' });
    const handler = vi.fn();
    const unsubscribe = bridge.onHardwareInput(handler);
    await waitFor(() => expect(hardwareEvent).toBeDefined());
    hardwareEvent?.({ device_id: '1', input_id: '2', pin: 3, value: 4, config_id: 5, port_generation: 27 });
    expect(handler).not.toHaveBeenCalled();
    hardwareEvent?.({ device_id: '1', input_id: '2', pin: 3, value: 4, config_id: 5, port: '/dev/ttyUSB0', port_generation: 27 });
    expect(handler).toHaveBeenCalledTimes(1);
    unsubscribe();
    expect(stop).toHaveBeenCalledTimes(1);
  });

  it('keeps output condition fields after Rust rejects a save', async () => {
    const createOutputBinding = vi.fn(async () => ({ ok: false as const, error: { code: 'validation' as const, message: 'Minimum must not exceed maximum.', field_errors: { value_a: 'Invalid range' }, retryable: false } }));
    const bridge = createFakeBridge({ createOutputBinding });
    render(OutputBindingWizard, { props: { bridge, trainId: '10', hardware, onClose: vi.fn(), onComplete: vi.fn() } });
    await fireEvent.input(screen.getByTestId('output-endpoint'), { target: { value: 'CurrentDrivableActor.Speed' } });
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.click(screen.getByTestId('output-option'));
    await fireEvent.click(screen.getByTestId('output-type-led'));
    await fireEvent.input(screen.getByTestId('output-binding-name'), { target: { value: 'Speed warning' } });
    await fireEvent.change(screen.getByTestId('output-operator'), { target: { value: 'between' } });
    await fireEvent.input(screen.getByTestId('output-value-a'), { target: { value: '90' } });
    await fireEvent.input(screen.getByTestId('output-value-b'), { target: { value: '10' } });
    await waitFor(() => expect(screen.getByTestId('save-output-binding')).toBeEnabled());
    await fireEvent.click(screen.getByTestId('save-output-binding'));
    await waitFor(() => expect(createOutputBinding).toHaveBeenCalledWith('10', expect.objectContaining({ output_id: '60', operator: 'between', value_a: 90, value_b: 10 })));
    expect(await screen.findByText('Minimum must not exceed maximum.')).toBeInTheDocument();
    expect(screen.getByTestId('output-value-a')).toHaveValue(90);
    expect(screen.getByTestId('output-value-b')).toHaveValue(10);
  });

  it('keeps custom display text when Rust rejects the binding', async () => {
    const createDisplayBinding = vi.fn(async () => ({ ok: false as const, error: { code: 'validation' as const, message: 'Display is no longer available.', field_errors: {}, retryable: false } }));
    const bridge = createFakeBridge({ createDisplayBinding });
    render(DisplayBindingWizard, { props: { bridge, trainId: '10', hardware, onClose: vi.fn(), onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('display-module-option'));
    await fireEvent.input(screen.getByTestId('display-endpoint'), { target: { value: 'CurrentDrivableActor.Speed' } });
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.input(screen.getByTestId('display-binding-name'), { target: { value: 'Speed readout' } });
    await fireEvent.change(screen.getByTestId('display-format-mode'), { target: { value: 'custom' } });
    await fireEvent.input(screen.getByTestId('display-custom-format'), { target: { value: 'S:{value:.1f}' } });
    await waitFor(() => expect(screen.getByTestId('save-display-binding')).toBeEnabled());
    await fireEvent.click(screen.getByTestId('save-display-binding'));
    await waitFor(() => expect(createDisplayBinding).toHaveBeenCalledWith('10', expect.objectContaining({ i2c_module_id: '70', format_string: 'S:{value:.1f}' })));
    expect(await screen.findByText('Display is no longer available.')).toBeInTheDocument();
    expect(screen.getByTestId('display-custom-format')).toHaveValue('S:{value:.1f}');
  });

  it('keeps the newest Rust display preview when an older request finishes late', async () => {
    const slow = Promise.withResolvers<{ ok: true; value: { valid: boolean; error: null; rendered: string; overflow: boolean; missing_dot: boolean } }>();
    const previewDisplay = vi.fn(async (_moduleId: string, format: string) => {
      if (format === 'A:{value}') return slow.promise;
      return { ok: true as const, value: { valid: true, error: null, rendered: format === 'B:{value}' ? 'B:42.5' : '42.5', overflow: false, missing_dot: false } };
    });
    const bridge = createFakeBridge({ previewDisplay });
    render(DisplayBindingWizard, { props: { bridge, trainId: '10', hardware, onClose: vi.fn(), onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('display-module-option'));
    await fireEvent.input(screen.getByTestId('display-endpoint'), { target: { value: 'Speed' } });
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.change(screen.getByTestId('display-format-mode'), { target: { value: 'custom' } });
    await fireEvent.input(screen.getByTestId('display-custom-format'), { target: { value: 'A:{value}' } });
    await waitFor(() => expect(previewDisplay).toHaveBeenCalledWith('70', 'A:{value}', 42.5));
    await fireEvent.input(screen.getByTestId('display-custom-format'), { target: { value: 'B:{value}' } });
    expect(await screen.findByText('B:42.5')).toBeInTheDocument();
    slow.resolve({ ok: true, value: { valid: true, error: null, rendered: 'A:42.5', overflow: false, missing_dot: false } });
    await waitFor(() => expect(screen.getByTestId('display-format-preview')).toHaveTextContent('B:42.5'));
  });

  it('disables display save and shows a Rust preview error', async () => {
    const bridge = createFakeBridge({ previewDisplay: vi.fn(async () => ({ ok: false as const, error: { code: 'unavailable' as const, message: 'Preview service unavailable', field_errors: {}, retryable: true } })) });
    render(DisplayBindingWizard, { props: { bridge, trainId: '10', hardware, onClose: vi.fn(), onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('display-module-option'));
    await fireEvent.input(screen.getByTestId('display-endpoint'), { target: { value: 'Speed' } });
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.input(screen.getByTestId('display-binding-name'), { target: { value: 'Speed readout' } });
    expect(await screen.findByText('Preview service unavailable')).toBeInTheDocument();
    expect(screen.getByTestId('save-display-binding')).toBeDisabled();
  });

  it('commits captured samples once and leaves normalized mapping to Rust', async () => {
    const detail: TrainDetailView = { ...train, elements: [mappedLever] };
    let inputListener: ((event: { input_id: string; value: number }) => void) | undefined;
    const commitLeverMapping = vi.fn(async () => ({ ok: true as const, value: mappingAck(detail, true) }));
    const previewNotchMapping = vi.fn(async () => ({ ok: true as const, value: { inverted: true, ranges: [{ min: 0.4321, max: 0.5678 }], travel: 4095 } }));
    const bridge = createFakeBridge({
      commitLeverMapping,
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [], button: [], output: [], display: [] }) })),
      onHardwareInput: vi.fn((handler) => { inputListener = handler; return () => {}; }),
      previewInput: vi.fn(async () => ({ ok: true as const, value: { calibrated: 500, travel: 4095, axis_percent: 12, max_hardware_value: 4095, min_notch_samples: 10 } })),
      previewNotchMapping,
    });
    render(LeverSetupWizard, { props: { bridge, element: mappedLever, hardware: leverHardware,
      initialInputId: '11', onClose: vi.fn(), onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await screen.findByTestId('lever-step-mapping');
    await fireEvent.click(screen.getByTestId('start-capturing'));
    for (let index = 0; index < 10; index += 1) inputListener?.({ input_id: '11', value: 500 });
    await flushPromises();
    await waitFor(() => expect(screen.getByTestId('capture-range')).toBeEnabled());
    await fireEvent.click(screen.getByTestId('capture-range'));
    await screen.findByTestId('lever-step-preview');
    await fireEvent.click(screen.getByTestId('save-mapping'));
    await waitFor(() => expect(commitLeverMapping).toHaveBeenCalledWith(expect.objectContaining({
      element_id: '80', lever_config_id: '81', input_id: '11', replace_binding: false,
      captured_ranges: [{ min: 500, max: 500, sample_count: 10 }], auto_distribute: false,
      notches: [expect.objectContaining({ input_min: null, input_max: null })],
    })));
    expect(previewNotchMapping).toHaveBeenCalledWith('11', [{ sim_input_min: 0, sim_input_max: 1 }], [{ min: 500, max: 500, sample_count: 10 }], false);
  });

  it('does not overwrite an existing mapping when Continue is followed by Cancel', async () => {
    let persistedRanges = { input_min: 0.25, input_max: 0.75 };
    const saveNotches = vi.fn(async (_configId: string, notches: { input_min?: number | null; input_max?: number | null }[]) => {
      persistedRanges = { input_min: notches[0]?.input_min ?? -1, input_max: notches[0]?.input_max ?? -1 };
      return { ok: true as const, value: snapshot('trains', { ...train, elements: [mappedLever] }) };
    });
    const bindLever = vi.fn();
    const bridge = createFakeBridge({
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [], button: [], output: [], display: [] }) })),
      saveNotches, bindLever,
      onHardwareInput: vi.fn(() => () => {}),
    });
    const view = render(LeverSetupWizard, { props: { bridge, element: mappedLever, hardware: leverHardware,
      initialInputId: '11', onClose: vi.fn(), onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await screen.findByTestId('lever-step-mapping');
    view.unmount();
    expect(saveNotches).not.toHaveBeenCalled();
    expect(bindLever).not.toHaveBeenCalled();
    expect(persistedRanges).toEqual({ input_min: 0.25, input_max: 0.75 });
  });

  it('keeps saved notch ranges through a binding conflict before Save Mapping', async () => {
    const saveNotches = vi.fn();
    const bindLever = vi.fn();
    const bridge = createFakeBridge({
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [{ id: '90', lever_config_id: '99', input_id: '11', enabled: true }], button: [], output: [], display: [] }) })),
      saveNotches, bindLever,
      onHardwareInput: vi.fn(() => () => {}),
    });
    const view = render(LeverSetupWizard, { props: { bridge, element: mappedLever, hardware: leverHardware,
      initialInputId: '11', onClose: vi.fn(), onComplete: vi.fn() } });
    for (let step = 0; step < 3; step += 1) await fireEvent.click(screen.getByTestId('wizard-continue'));
    expect(await screen.findByText('Replace existing binding?')).toBeInTheDocument();
    view.unmount();
    expect(saveNotches).not.toHaveBeenCalled();
    expect(bindLever).not.toHaveBeenCalled();
    expect(mappedLever.lever_config?.notches[0]).toEqual(expect.objectContaining({ input_min: 0.25, input_max: 0.75 }));
  });

  it('previews automatic ranges without persisting them before Save Mapping', async () => {
    const saveNotches = vi.fn();
    const autoDistributeNotches = vi.fn();
    const previewNotchMapping = vi.fn(async () => ({ ok: true as const, value: { inverted: false, ranges: [{ min: 0, max: 1 }], travel: 4095 } }));
    const bridge = createFakeBridge({
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [], button: [], output: [], display: [] }) })),
      saveNotches, autoDistributeNotches, previewNotchMapping,
      onHardwareInput: vi.fn(() => () => {}),
    });
    const view = render(LeverSetupWizard, { props: { bridge, element: mappedLever, hardware: leverHardware,
      initialInputId: '11', onClose: vi.fn(), onComplete: vi.fn() } });
    for (let step = 0; step < 3; step += 1) await fireEvent.click(screen.getByTestId('wizard-continue'));
    await screen.findByTestId('lever-step-mapping');
    await fireEvent.click(screen.getByTestId('auto-distribute'));
    await screen.findByTestId('lever-step-preview');
    expect(previewNotchMapping).toHaveBeenCalledWith('11', [{ sim_input_min: 0, sim_input_max: 1 }], [], true);
    view.unmount();
    expect(saveNotches).not.toHaveBeenCalled();
    expect(autoDistributeNotches).not.toHaveBeenCalled();
  });

  it('retries an atomic mapping conflict only after explicit replacement consent', async () => {
    const detail: TrainDetailView = { ...train, elements: [mappedLever] };
    const commitLeverMapping = vi.fn()
      .mockResolvedValueOnce({ ok: false, error: { code: 'conflict', message: 'Input moved to another binding.', field_errors: {}, retryable: true } })
      .mockResolvedValueOnce({ ok: true, value: mappingAck(detail, true) });
    const bridge = createFakeBridge({
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [], button: [], output: [], display: [] }) })),
      previewNotchMapping: vi.fn(async () => ({ ok: true as const, value: { inverted: false, ranges: [{ min: 0, max: 1 }], travel: 4095 } })),
      commitLeverMapping,
      bindLever: vi.fn(), saveNotches: vi.fn(), updateLever: vi.fn(),
    });
    render(LeverSetupWizard, { props: { bridge, element: mappedLever, hardware: leverHardware, initialInputId: '11', onClose: vi.fn(), onComplete: vi.fn() } });
    for (let step = 0; step < 3; step += 1) await fireEvent.click(screen.getByTestId('wizard-continue'));
    await screen.findByTestId('lever-step-mapping');
    await fireEvent.click(screen.getByTestId('auto-distribute'));
    await screen.findByTestId('lever-step-preview');
    await fireEvent.click(screen.getByTestId('save-mapping'));
    expect(await screen.findByText('Replace existing binding?')).toBeInTheDocument();
    expect(commitLeverMapping).toHaveBeenNthCalledWith(1, expect.objectContaining({ replace_binding: false }));
    await fireEvent.click(screen.getByTestId('confirm-replace-binding'));
    await waitFor(() => expect(commitLeverMapping).toHaveBeenNthCalledWith(2, expect.objectContaining({ replace_binding: true })));
    expect(bridge.bindLever).not.toHaveBeenCalled();
    expect(bridge.saveNotches).not.toHaveBeenCalled();
    expect(bridge.updateLever).not.toHaveBeenCalled();
  });

  it('keeps the lever draft open on atomic save error, then handles committed gaps', async () => {
    const detail: TrainDetailView = { ...train, elements: [mappedLever] };
    let inputListener: ((event: { input_id: string; value: number }) => void) | undefined;
    const onComplete = vi.fn();
    const commitLeverMapping = vi.fn()
      .mockResolvedValueOnce({ ok: false as const, error: { code: 'unavailable' as const, message: 'Range check offline', field_errors: {}, retryable: true } })
      .mockResolvedValueOnce({ ok: true as const, value: mappingAck(detail, false, [{ from: 0.6, to: 0.8 }]) });
    const bridge = createFakeBridge({
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [], button: [], output: [], display: [] }) })),
      onHardwareInput: vi.fn((handler) => { inputListener = handler; return () => {}; }),
      previewInput: vi.fn(async () => ({ ok: true as const, value: { calibrated: 500, travel: 4095, axis_percent: 12, max_hardware_value: 4095, min_notch_samples: 10 } })),
      previewNotchMapping: vi.fn(async () => ({ ok: true as const, value: { inverted: false, ranges: [{ min: 0.4321, max: 0.5678 }], travel: 4095 } })),
      commitLeverMapping,
    });
    render(LeverSetupWizard, { props: { bridge, element: mappedLever, hardware: leverHardware,
      initialInputId: '11', onClose: vi.fn(), onComplete } });
    for (let step = 0; step < 3; step += 1) await fireEvent.click(screen.getByTestId('wizard-continue'));
    await screen.findByTestId('lever-step-mapping');
    await fireEvent.click(screen.getByTestId('start-capturing'));
    for (let index = 0; index < 10; index += 1) inputListener?.({ input_id: '11', value: 500 });
    await flushPromises();
    await fireEvent.click(await screen.findByTestId('capture-range'));
    await screen.findByTestId('lever-step-preview');
    await fireEvent.click(screen.getByTestId('save-mapping'));
    expect(await screen.findByText('Range check offline')).toBeInTheDocument();
    expect(screen.getByTestId('lever-step-preview')).toBeInTheDocument();
    expect(onComplete).not.toHaveBeenCalled();
    expect(commitLeverMapping).toHaveBeenCalledTimes(1);
    await fireEvent.click(screen.getByTestId('save-mapping'));
    expect(await screen.findByText('Saved with gaps')).toBeInTheDocument();
    expect(onComplete).not.toHaveBeenCalled();
    await fireEvent.click(screen.getByRole('button', { name: 'Finish anyway' }));
    expect(onComplete).toHaveBeenCalledWith("Lever 'Throttle' configured with gaps");
  });

  it('commits a revised mapping after a gapped save instead of finishing the old draft', async () => {
    const detail: TrainDetailView = { ...train, elements: [mappedLever] };
    let inputListener: ((event: { input_id: string; value: number }) => void) | undefined;
    const onComplete = vi.fn();
    const commitLeverMapping = vi.fn()
      .mockResolvedValueOnce({ ok: true, value: mappingAck(detail, false, [{ from: 0.6, to: 0.8 }]) })
      .mockResolvedValueOnce({ ok: true, value: mappingAck(detail, true) });
    const bridge = createFakeBridge({
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [], button: [], output: [], display: [] }) })),
      onHardwareInput: vi.fn((handler) => { inputListener = handler; return () => {}; }),
      previewInput: vi.fn(async () => ({ ok: true as const, value: { calibrated: 500, travel: 4095, axis_percent: 12, max_hardware_value: 4095, min_notch_samples: 10 } })),
      previewNotchMapping: vi.fn(async () => ({ ok: true as const, value: { inverted: false, ranges: [{ min: 0, max: 1 }], travel: 4095 } })),
      commitLeverMapping,
    });
    render(LeverSetupWizard, { props: { bridge, element: mappedLever, hardware: leverHardware,
      initialInputId: '11', onClose: vi.fn(), onComplete } });
    for (let step = 0; step < 3; step += 1) await fireEvent.click(screen.getByTestId('wizard-continue'));
    await screen.findByTestId('lever-step-mapping');
    await fireEvent.click(screen.getByTestId('start-capturing'));
    for (let index = 0; index < 10; index += 1) inputListener?.({ input_id: '11', value: 500 });
    await flushPromises();
    await fireEvent.click(await screen.findByTestId('capture-range'));
    await screen.findByTestId('lever-step-preview');
    await fireEvent.click(screen.getByTestId('save-mapping'));
    expect(await screen.findByText('Saved with gaps')).toBeInTheDocument();
    await fireEvent.click(screen.getByTestId('wizard-back'));
    await fireEvent.click(screen.getByTestId('auto-distribute'));
    await screen.findByTestId('lever-step-preview');
    expect(screen.getByTestId('save-mapping')).toHaveTextContent('Save Mapping');
    await fireEvent.click(screen.getByTestId('save-mapping'));
    await waitFor(() => expect(commitLeverMapping).toHaveBeenCalledTimes(2));
    expect(commitLeverMapping).toHaveBeenNthCalledWith(2, expect.objectContaining({ auto_distribute: true, lever_config_id: '81' }));
    expect(onComplete).toHaveBeenCalledWith("Lever 'Throttle' configured successfully");
  });

  it('treats a null post-commit train snapshot as saved and asks for a refresh', async () => {
    const onComplete = vi.fn();
    const commitLeverMapping = vi.fn(async () => ({ ok: true as const, value: { ...mappingAck(null, true, [], true), inverted: true } }));
    const bridge = createFakeBridge({
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [], button: [], output: [], display: [] }) })),
      previewNotchMapping: vi.fn(async () => ({ ok: true as const, value: { inverted: true, ranges: [{ min: 0, max: 1 }], travel: 4095 } })),
      commitLeverMapping,
    });
    render(LeverSetupWizard, { props: { bridge, element: mappedLever, hardware: leverHardware,
      initialInputId: '11', onClose: vi.fn(), onComplete } });
    for (let step = 0; step < 3; step += 1) await fireEvent.click(screen.getByTestId('wizard-continue'));
    await screen.findByTestId('lever-step-mapping');
    await fireEvent.click(screen.getByTestId('auto-distribute'));
    await screen.findByTestId('lever-step-preview');
    await fireEvent.click(screen.getByTestId('save-mapping'));
    await waitFor(() => expect(onComplete).toHaveBeenCalledWith("Lever 'Throttle' saved. Refresh train details to see the latest changes."));
    expect(screen.getByText('Lever direction detected as inverted and saved.')).toBeInTheDocument();
    expect(commitLeverMapping).toHaveBeenCalledTimes(1);
  });
});
