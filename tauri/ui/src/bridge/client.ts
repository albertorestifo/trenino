import { invoke } from '@tauri-apps/api/core';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';
import type {
  BindingsView,
  CalibrationView,
  ConfigurationSummaryView,
  DeviceDetailView,
  FirmwareView,
  Ht16k33ParamsView,
  NotchRangesValidationView,
  ScriptsView,
  SettingsView,
  TrainDetailView,
  TrainSummaryView,
  UiChange,
  UiFailure,
  UiSnapshot,
  VjoyView,
} from './generated';
import { TopicStream } from './stream';

export type Result<T> = { ok: true; value: T } | { ok: false; error: UiFailure };
export type Unsubscribe = () => void;
type Topic = UiSnapshot<unknown>['topic'];
type Unlisten = () => void;

export interface IpcTransport {
  isDesktop(): boolean;
  invoke(command: string, args?: Record<string, unknown>): Promise<unknown>;
  listen(event: string, handler: (payload: unknown) => void): Promise<Unlisten>;
}

// ---- Wave-2 UI track B: shared command payload types ------------------------

/** Payload of the `ui://hardware/input` event (rust_ui `HardwareInputEventView`). */
export type HardwareInputEvent = {
  port: string;
  device_id: string;
  input_id: string;
  pin: number;
  value: number;
  config_id: number;
  port_generation: number;
};

export type InputPreview = { calibrated: number; travel: number; axis_percent: number; max_hardware_value: number; min_notch_samples: number };
export type CapturedRange = { min: number; max: number; sample_count: number };
export type NormalizedRange = { min: number; max: number };
export type NotchSimulatorRange = { sim_input_min: number | null; sim_input_max: number | null };
export type NotchMappingPreview = { inverted: boolean; ranges: NormalizedRange[]; travel: number };
export type DisplayPreview = { valid: boolean; error: string | null; rendered: string; overflow: boolean; missing_dot: boolean };
export type OutputConditionPreview = { valid: boolean; error: string | null; explanation: string; example_on: boolean };
export type SerialPortView = { port: string; generation: number | null; config_id: number | null; device_id: string | null; status: 'connected' | 'available' };
export type ConfigurationOperation = { operation_id: string; config_id: number };
export type ConfigurationOperationStatus = { state: 'pending' | 'complete' | 'failed'; message: string | null };
export type SimulatorRuntimeStatus = { status: string; last_error: string | null; active_train_id: string | null; detected_identifier: string | null };
export type FirmwareUpdateStatus = {
  checking: boolean;
  checked_at_ms: number | null;
  found_updates: boolean;
  latest_version: string | null;
  error_message: string | null;
  notice: { version: string; outdated_devices: string[]; outdated_ports: string[] } | null;
};
export type SimulatorEndpoint = { name: string; path: string; kind: 'node' | 'endpoint'; writable: boolean };
export type LeverMappingDraft = {
  element_id: string;
  lever_config_id: string | null;
  input_id: string;
  replace_binding: boolean;
  endpoints: {
    min_endpoint: string;
    max_endpoint: string;
    value_endpoint: string;
    notch_count_endpoint: string | null;
    notch_index_endpoint: string | null;
    lever_type: 'continuous' | 'discrete' | 'hybrid' | null;
  };
  notches: NotchDraft[];
  captured_ranges: CapturedRange[];
  auto_distribute: boolean;
  calibration_completed: boolean;
};
export type LeverMappingCommit = {
  committed: true;
  lever_config_id: string;
  inverted: boolean;
  train_detail: UiSnapshot<TrainDetailView> | null;
  validation: UiSnapshot<NotchRangesValidationView>;
  refresh_required: boolean;
};
export type DetectedControlChange = { endpoint: string; control_name: string; previous_value: number; current_value: number };
export type SuggestedNotch = { kind: 'gate' | 'linear'; index: number; value: number | null; min_value: number | null; max_value: number | null; input_min: number; input_max: number; actual_input_min: number; actual_input_max: number; description: string };
export type LeverAnalysis = { lever_type: 'discrete' | 'continuous' | 'hybrid'; suggested_notches: SuggestedNotch[] };
export type SimulatorNotchDraft = { index: number; kind: 'gate' | 'linear'; value: number | null; min_value: number | null; max_value: number | null; description: string };
export type LeverCalibration = { lever_config_id: number; notches: SimulatorNotchDraft[] };
export type LeverEndpointSet = { min_endpoint: string; max_endpoint: string; value_endpoint: string; notch_count_endpoint: string; notch_index_endpoint: string };
export type ResolvedLeverEndpoints = LeverEndpointSet & { name: string };
export type GuidedSessionSnapshot = {
  session_id: string;
  state: 'listening' | 'running' | 'cancelling' | 'detected' | 'timed_out' | 'complete' | 'failed' | 'cancelled';
  cleanup_pending: boolean;
  changes: DetectedControlChange[];
  ambiguous: boolean;
  remaining_ms: number | null;
  analysis: LeverAnalysis | null;
  analysis_progress: { sampled: number; total: number; current_value: number } | null;
  calibration: LeverCalibration | null;
  progress: { lever_config_id: number; step: string; progress: number; current_value: number; notch_count: number } | null;
  message: string | null;
};
export type GuidedSessionStart = { session_id: string };

/** Wire shape of `NotchInput` for `ui_save_notches` / `ui_create_notch`. */
export type NotchDraft = {
  index: number;
  kind: 'gate' | 'linear';
  value?: number | null;
  min_value?: number | null;
  max_value?: number | null;
  input_min?: number | null;
  input_max?: number | null;
  sim_input_min?: number | null;
  sim_input_max?: number | null;
  description?: string | null;
};

/** Wire shape of `SequenceCommandInput`. */
export type SequenceCommandDraft = {
  endpoint: string;
  value: number;
  delay_ms: number;
};

/** Wire shape of the button binding draft (`ui_put_button_binding`). */
export type ButtonBindingDraft = {
  endpoint?: string | null;
  on_value?: number | null;
  off_value?: number | null;
  enabled?: boolean | null;
  mode?: 'simple' | 'momentary' | 'sequence' | 'keystroke' | null;
  hardware_type?: 'momentary' | 'latching' | null;
  repeat_interval_ms?: number | null;
  keystroke?: string | null;
  on_sequence_id?: string | null;
  off_sequence_id?: string | null;
};

/** Wire shape of the output binding draft (`ui_create_output_binding`). */
export type OutputBindingDraft = {
  name: string;
  output_type: 'led';
  output_id: string;
  endpoint: string;
  operator: 'gt' | 'gte' | 'lt' | 'lte' | 'between' | 'eq_true' | 'eq_false';
  value_a?: number | null;
  value_b?: number | null;
  enabled?: boolean | null;
};

/** Wire shape of the output binding patch (`ui_update_output_binding`). */
export type OutputBindingPatch = Partial<OutputBindingDraft>;

/** Wire shape of the display binding draft (`ui_create_display_binding`). */
export type DisplayBindingDraft = {
  i2c_module_id: string;
  name?: string | null;
  endpoint: string;
  format_string?: string | null;
  enabled?: boolean | null;
};

/** Wire shape of the display binding patch (`ui_update_display_binding`). */
export type DisplayBindingPatch = Partial<DisplayBindingDraft>;

/** Wire shape of the vJoy mapping draft (`ui_put_vjoy_mapping`). */
export type VjoyMappingDraft = {
  device_index: number;
  target: string;
  inverted: boolean;
};

export interface UiBridge {
  getSettings(): Promise<Result<UiSnapshot<SettingsView>>>;
  getConfigurations(): Promise<Result<UiSnapshot<ConfigurationSummaryView[]>>>;
  getTrains(): Promise<Result<UiSnapshot<TrainSummaryView[]>>>;
  setConsent(value: 'enabled' | 'disabled'): Promise<Result<UiSnapshot<SettingsView>>>;
  subscribe<T>(topic: Topic, onValue: (value: UiSnapshot<T>) => void, onUnavailable: (error: UiFailure) => void): Promise<Unsubscribe>;

  // ---- Wave-2 UI track B: trains page ---------------------------------------
  getTrainDetail(id: string): Promise<Result<UiSnapshot<TrainDetailView>>>;
  createTrain(input: { name: string; description?: string | null; identifiers: string[] }): Promise<Result<UiSnapshot<TrainDetailView>>>;
  updateTrain(id: string, patch: { name?: string; description?: string | null; identifiers?: string[] }): Promise<Result<UiSnapshot<TrainDetailView>>>;
  deleteTrain(id: string): Promise<Result<UiSnapshot<TrainSummaryView[]>>>;
  createElement(trainId: string, kind: 'lever' | 'button', name: string): Promise<Result<UiSnapshot<TrainDetailView>>>;
  deleteElement(id: string): Promise<Result<UiSnapshot<TrainDetailView>>>;
  createLever(
    elementId: string,
    lever: {
      min_endpoint: string;
      max_endpoint: string;
      value_endpoint: string;
      notch_count_endpoint?: string | null;
      notch_index_endpoint?: string | null;
      lever_type?: 'discrete' | 'continuous' | 'hybrid' | null;
      inverted: boolean;
    },
  ): Promise<Result<UiSnapshot<TrainDetailView>>>;
  updateLever(id: string, patch: { inverted?: boolean; lever_type?: 'discrete' | 'continuous' | 'hybrid' }): Promise<Result<UiSnapshot<TrainDetailView>>>;
  saveNotches(leverConfigId: string, notches: NotchDraft[]): Promise<Result<UiSnapshot<TrainDetailView>>>;
  autoDistributeNotches(leverConfigId: string): Promise<Result<UiSnapshot<TrainDetailView>>>;
  validateNotches(leverConfigId: string): Promise<Result<UiSnapshot<NotchRangesValidationView>>>;
  bindLever(leverConfigId: string, inputId: string, replace: boolean): Promise<Result<UiSnapshot<BindingsView>>>;
  putButtonBinding(elementId: string, inputId: string, draft: ButtonBindingDraft, replace: boolean): Promise<Result<UiSnapshot<BindingsView>>>;
  deleteButtonBinding(elementId: string): Promise<Result<UiSnapshot<BindingsView>>>;
  createOutputBinding(trainId: string, draft: OutputBindingDraft): Promise<Result<UiSnapshot<BindingsView>>>;
  updateOutputBinding(id: string, patch: OutputBindingPatch): Promise<Result<UiSnapshot<BindingsView>>>;
  deleteOutputBinding(id: string): Promise<Result<UiSnapshot<BindingsView>>>;
  createDisplayBinding(trainId: string, draft: DisplayBindingDraft): Promise<Result<UiSnapshot<BindingsView>>>;
  updateDisplayBinding(id: string, patch: DisplayBindingPatch): Promise<Result<UiSnapshot<BindingsView>>>;
  deleteDisplayBinding(id: string): Promise<Result<UiSnapshot<BindingsView>>>;
  getBindings(): Promise<Result<UiSnapshot<BindingsView>>>;
  getHardwareDetail(deviceId: string): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  getHardwareDetailByConfig(configId: string): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  createConfiguration(name: string, description?: string | null): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  updateConfiguration(id: string, patch: { name?: string; description?: string | null }): Promise<Result<UiSnapshot<ConfigurationSummaryView[]>>>;
  deleteConfiguration(id: string): Promise<Result<UiSnapshot<ConfigurationSummaryView[]>>>;
  createInput(params: { device_id: string; pin: number; kind: 'analog' | 'button'; sensitivity?: number | null; debounce?: number | null; name?: string | null; matrix_id?: string | null }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  updateInput(params: { id: string; pin: number; kind: 'analog' | 'button'; sensitivity?: number | null; debounce?: number | null; name?: string | null }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  deleteInput(id: string): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  createOutput(params: { device_id: string; pin: number; name?: string | null }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  updateOutput(params: { id: string; pin: number; name?: string | null }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  deleteOutput(id: string): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  createMatrix(params: { device_id: string; name: string; row_pins: number[]; col_pins: number[] }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  updateMatrix(params: { id: string; row_pins: number[]; col_pins: number[] }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  deleteMatrix(id: string): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  createI2cModule(params: { device_id: string; name?: string | null; module_chip: string; i2c_address: number; params?: Ht16k33ParamsView | null }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  updateI2cModule(params: { id: string; name?: string | null; module_chip: string; i2c_address: number; params?: Ht16k33ParamsView | null }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  deleteI2cModule(id: string): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  startCalibration(params: { port: string; generation: number; pin: number; input_id: string; max_hardware_value: number }): Promise<Result<string>>;
  advanceCalibration(sessionId: string): Promise<Result<CalibrationView | null>>;
  cancelCalibration(sessionId: string): Promise<Result<boolean>>;
  calibrationCeiling(inputId: string): Promise<Result<number>>;
  previewInput(inputId: string, raw: number): Promise<Result<InputPreview>>;
  previewNotchMapping(inputId: string, notches: NotchSimulatorRange[], captured: CapturedRange[], autoDistribute: boolean): Promise<Result<NotchMappingPreview>>;
  previewDisplay(moduleId: string, formatString: string, sampleValue: number): Promise<Result<DisplayPreview>>;
  previewOutputCondition(operator: OutputBindingDraft['operator'], valueA: number | null, valueB: number | null): Promise<Result<OutputConditionPreview>>;
  commitLeverMapping(mapping: LeverMappingDraft): Promise<Result<LeverMappingCommit>>;
  startControlDetection(): Promise<Result<GuidedSessionStart>>;
  controlDetectionStatus(sessionId: string): Promise<Result<GuidedSessionSnapshot>>;
  cancelControlDetection(sessionId: string): Promise<Result<boolean>>;
  startLeverAnalysis(controlPath: string, restorePosition?: number | null): Promise<Result<GuidedSessionStart>>;
  leverAnalysisStatus(sessionId: string): Promise<Result<GuidedSessionSnapshot>>;
  cancelLeverAnalysis(sessionId: string): Promise<Result<boolean>>;
  startLeverCalibration(controlPath: string, endpoints: LeverEndpointSet | null): Promise<Result<GuidedSessionStart>>;
  leverCalibrationStatus(sessionId: string): Promise<Result<GuidedSessionSnapshot>>;
  cancelLeverCalibration(sessionId: string): Promise<Result<boolean>>;
  resolveLeverEndpoints(controlPath: string): Promise<Result<ResolvedLeverEndpoints>>;
  setSimulatorUrl(value: string): Promise<Result<UiSnapshot<SettingsView>>>;
  setApiKey(value: string): Promise<Result<UiSnapshot<SettingsView>>>;
  testSimulator(): Promise<Result<boolean>>;
  onHardwareInput(handler: (event: HardwareInputEvent) => void): Unsubscribe;
  serialPorts(): Promise<Result<SerialPortView[]>>;
  scanDevices(): Promise<Result<boolean>>;
  beginApplyConfiguration(deviceId: string, port: string, generation: number): Promise<Result<ConfigurationOperation>>;
  configurationStatus(operationId: string): Promise<Result<ConfigurationOperationStatus>>;
  disconnectDevice(port: string, generation: number): Promise<Result<boolean>>;
  getSimulatorStatus(): Promise<Result<SimulatorRuntimeStatus>>;
  retrySimulator(): Promise<Result<boolean>>;
  listSimulatorEndpoints(path: string | null): Promise<Result<SimulatorEndpoint[]>>;
  getSimulatorValue(path: string): Promise<Result<unknown>>;
  setPhysicalOutput(outputId: string, high: boolean, port: string, generation: number): Promise<Result<boolean>>;
  testDisplay(moduleId: string, text: string, port: string, generation: number): Promise<Result<boolean>>;

  // ---- Wave-2 UI track B: sequences ------------------------------------------
  createSequence(trainId: string, name: string): Promise<Result<UiSnapshot<TrainDetailView>>>;
  updateSequence(id: string, name: string): Promise<Result<UiSnapshot<TrainDetailView>>>;
  deleteSequence(id: string): Promise<Result<UiSnapshot<TrainDetailView>>>;
  setSequenceCommands(sequenceId: string, commands: SequenceCommandDraft[]): Promise<Result<UiSnapshot<TrainDetailView>>>;
  testSequence(sequenceId: string): Promise<Result<boolean>>;

  // ---- Wave-2 UI track B: scripts page ---------------------------------------
  getScripts(): Promise<Result<UiSnapshot<ScriptsView>>>;
  createScript(trainId: string, name: string, code: string, triggers: string[]): Promise<Result<UiSnapshot<ScriptsView>>>;
  updateScript(id: string, patch: { name?: string; code?: string; triggers?: string[]; enabled?: boolean }): Promise<Result<UiSnapshot<ScriptsView>>>;
  deleteScript(id: string): Promise<Result<UiSnapshot<ScriptsView>>>;
  reloadScripts(): Promise<Result<UiSnapshot<ScriptsView>>>;
  runScript(id: string): Promise<Result<boolean>>;
  getScriptLog(id: string): Promise<Result<string[]>>;

  // ---- Wave-2 UI track B: virtual joystick page -------------------------------
  getVjoy(): Promise<Result<UiSnapshot<VjoyView>>>;
  vjoyEnable(): Promise<Result<UiSnapshot<VjoyView>>>;
  vjoyDisable(): Promise<Result<UiSnapshot<VjoyView>>>;
  setVjoySelection(devices: number[]): Promise<Result<UiSnapshot<VjoyView>>>;
  putVjoyMapping(inputId: string, draft: VjoyMappingDraft, replace: boolean): Promise<Result<UiSnapshot<VjoyView>>>;
  deleteVjoyMapping(id: string): Promise<Result<UiSnapshot<VjoyView>>>;

  // ---- Wave-2 UI track B: firmware page ---------------------------------------
  getFirmware(): Promise<Result<UiSnapshot<FirmwareView>>>;
  checkFirmwareUpdates(): Promise<Result<UiSnapshot<FirmwareView>>>;
  firmwareUpdateStatus(): Promise<Result<FirmwareUpdateStatus>>;
  dismissFirmwareUpdate(): Promise<Result<FirmwareUpdateStatus>>;
  downloadFirmware(releaseId: string, environment: string): Promise<Result<UiSnapshot<FirmwareView>>>;
  startFirmwareUpload(firmwareFileId: string, port: string, environment: string, generation: number): Promise<Result<string>>;
  cancelFirmwareUpload(uploadId: string): Promise<Result<boolean>>;
}

const ERROR_CODES = new Set<UiFailure['code']>(['validation', 'conflict', 'not_found', 'unavailable', 'cancelled', 'internal']);

function unavailable(message = 'The Rust desktop service is not available yet.'): UiFailure {
  return { code: 'unavailable', message, field_errors: {}, retryable: true };
}

function plainRecord(value: unknown): value is Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

/** Preserve only the Rust's known, display-safe error contract. */
export function normalizeIpcFailure(value: unknown, fallback = unavailable()): UiFailure {
  try {
    if (!plainRecord(value)) return fallback;
    const { code, message, field_errors: rawFieldErrors, retryable } = value;
    if (typeof code !== 'string' || !ERROR_CODES.has(code as UiFailure['code']) || typeof message !== 'string' || typeof retryable !== 'boolean' || !plainRecord(rawFieldErrors)) {
      return fallback;
    }
    const fieldErrors: Record<string, string> = Object.create(null);
    for (const [path, fieldMessage] of Object.entries(rawFieldErrors)) {
      if (typeof fieldMessage !== 'string') return fallback;
      fieldErrors[path] = fieldMessage;
    }
    if (code === 'internal') {
      return { code, message: 'The Rust service could not complete the request.', field_errors: {}, retryable };
    }
    return { code: code as UiFailure['code'], message, field_errors: fieldErrors, retryable };
  } catch {
    return fallback;
  }
}

function desktopAvailable(): boolean {
  return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
}

const tauriTransport: IpcTransport = {
  isDesktop: desktopAvailable,
  invoke: (command: string, args?: Record<string, unknown>) => invoke<unknown>(command, args),
  listen: (event: string, handler: (payload: unknown) => void) => listen<unknown>(event, ({ payload }) => handler(payload)),
};

let localSubscriptionNumber = 0;
function newSubscriptionId(): string {
  localSubscriptionNumber += 1;
  const randomId = globalThis.crypto?.randomUUID?.();
  return randomId ?? `ui-${Date.now().toString(36)}-${localSubscriptionNumber.toString(36)}`;
}

function isHardwareInputEvent(value: unknown): value is HardwareInputEvent {
  if (!plainRecord(value)) return false;
  return (
    typeof value.port === 'string' && value.port.length > 0 &&
    typeof value.device_id === 'string' &&
    typeof value.input_id === 'string' &&
    typeof value.pin === 'number' &&
    typeof value.value === 'number' &&
    typeof value.config_id === 'number' &&
    typeof value.port_generation === 'number'
  );
}

export function createBridge(ipc: IpcTransport): UiBridge {
  async function command<T>(name: string, args?: Record<string, unknown>): Promise<Result<T>> {
    if (!ipc.isDesktop()) return { ok: false, error: unavailable('Open Trenino from the desktop app to connect to Rust services.') };
    try {
      return { ok: true, value: (await ipc.invoke(name, args)) as T };
    } catch (error) {
      return { ok: false, error: normalizeIpcFailure(error) };
    }
  }

  return {
    getSettings: () => command('ui_get_settings'),
    getConfigurations: () => command('ui_list_configurations'),
    getTrains: () => command('ui_list_trains'),
    setConsent: (value) => command('ui_set_consent', { value }),

    // ---- Wave-2 UI track B: trains page ---------------------------------------
    getTrainDetail: (id) => command('ui_get_train_detail', { id }),
    createTrain: ({ name, description, identifiers }) => command('ui_create_train', { name, description, identifiers }),
    updateTrain: (id, patch) => command('ui_update_train', { id, ...patch }),
    deleteTrain: (id) => command('ui_delete_train', { id }),
    createElement: (trainId, kind, name) => command('ui_create_element', { train_id: trainId, kind, name }),
    deleteElement: (id) => command('ui_delete_element', { id }),
    createLever: (elementId, lever) => command('ui_create_lever', { element_id: elementId, ...lever }),
    updateLever: (id, patch) => command('ui_update_lever', { id, ...patch }),
    saveNotches: (leverConfigId, notches) => command('ui_save_notches', { lever_config_id: leverConfigId, notches }),
    autoDistributeNotches: (leverConfigId) => command('ui_auto_distribute_notches', { lever_config_id: leverConfigId }),
    validateNotches: (leverConfigId) => command('ui_validate_notches', { lever_config_id: leverConfigId }),
    bindLever: (leverConfigId, inputId, replace) => command('ui_bind_lever', { lever_config_id: leverConfigId, input_id: inputId, replace }),
    putButtonBinding: (elementId, inputId, draft, replace) => command('ui_put_button_binding', { element_id: elementId, input_id: inputId, ...draft, replace }),
    deleteButtonBinding: (elementId) => command('ui_delete_button_binding', { element_id: elementId }),
    createOutputBinding: (trainId, draft) => command('ui_create_output_binding', { train_id: trainId, ...draft }),
    updateOutputBinding: (id, patch) => command('ui_update_output_binding', { id, ...patch }),
    deleteOutputBinding: (id) => command('ui_delete_output_binding', { id }),
    createDisplayBinding: (trainId, draft) => command('ui_create_display_binding', { train_id: trainId, ...draft }),
    updateDisplayBinding: (id, patch) => command('ui_update_display_binding', { id, ...patch }),
    deleteDisplayBinding: (id) => command('ui_delete_display_binding', { id }),
    getBindings: () => command('ui_get_bindings'),
    getHardwareDetail: (deviceId) => command('ui_get_hardware_detail', { id: deviceId }),
    getHardwareDetailByConfig: (config_id) => command('ui_get_hardware_detail_by_config', { config_id }),
    createConfiguration: (name, description) => command('ui_create_configuration', { name, description }),
    updateConfiguration: (id, patch) => command('ui_update_configuration', { id, ...patch }),
    deleteConfiguration: (id) => command('ui_delete_configuration', { id }),
    createInput: (params) => command('ui_create_input', { ...params }),
    updateInput: (params) => command('ui_update_input', { ...params }),
    deleteInput: (id) => command('ui_delete_input', { id }),
    createOutput: (params) => command('ui_create_output', { ...params }),
    updateOutput: (params) => command('ui_update_output', { ...params }),
    deleteOutput: (id) => command('ui_delete_output', { id }),
    createMatrix: (params) => command('ui_create_matrix', { ...params }),
    updateMatrix: (params) => command('ui_update_matrix', { ...params }),
    deleteMatrix: (id) => command('ui_delete_matrix', { id }),
    createI2cModule: (params) => command('ui_create_i2c_module', { ...params }),
    updateI2cModule: (params) => command('ui_update_i2c_module', { ...params }),
    deleteI2cModule: (id) => command('ui_delete_i2c_module', { id }),
    startCalibration: (params) => command('ui_start_calibration', { ...params }),
    advanceCalibration: (session_id) => command('ui_advance_calibration', { session_id }),
    cancelCalibration: (session_id) => command('ui_cancel_calibration', { session_id }),
    calibrationCeiling: (input_id) => command('ui_calibration_ceiling', { input_id }),
    previewInput: (input_id, raw) => command('ui_preview_input', { input_id, raw }),
    previewNotchMapping: (input_id, notches, captured, auto_distribute) => command('ui_preview_notch_mapping', { input_id, notches, captured, auto_distribute }),
    previewDisplay: (module_id, format_string, sample_value) => command('ui_preview_display', { module_id, format_string, sample_value }),
    previewOutputCondition: (operator, value_a, value_b) => command('ui_preview_output_condition', { operator, value_a, value_b }),
    commitLeverMapping: (mapping) => command('ui_commit_lever_mapping', { mapping }),
    startControlDetection: () => command('ui_start_control_detection'),
    controlDetectionStatus: (session_id) => command('ui_control_detection_status', { session_id }),
    cancelControlDetection: (session_id) => command('ui_cancel_control_detection', { session_id }),
    startLeverAnalysis: (control_path, restore_position = null) => command('ui_start_lever_analysis', { control_path, restore_position }),
    leverAnalysisStatus: (session_id) => command('ui_lever_analysis_status', { session_id }),
    cancelLeverAnalysis: (session_id) => command('ui_cancel_lever_analysis', { session_id }),
    startLeverCalibration: (control_path, endpoints) => command('ui_start_lever_calibration', { control_path, lever_config_id: null, endpoints }),
    leverCalibrationStatus: (session_id) => command('ui_lever_calibration_status', { session_id }),
    cancelLeverCalibration: (session_id) => command('ui_cancel_lever_calibration', { session_id }),
    resolveLeverEndpoints: (control_path) => command('ui_resolve_lever_endpoints', { control_path }),
    setSimulatorUrl: (value) => command('ui_set_simulator_url', { value }),
    setApiKey: (value) => command('ui_set_api_key', { value }),
    testSimulator: () => command('ui_test_simulator'),
    serialPorts: () => command('ui_serial_ports'),
    scanDevices: () => command('ui_scan_devices'),
    beginApplyConfiguration: (device_id, port, generation) => command('ui_begin_apply_configuration', { device_id, port, generation }),
    configurationStatus: (operation_id) => command('ui_configuration_status', { operation_id }),
    disconnectDevice: (port, generation) => command('ui_disconnect_device', { port, generation }),
    getSimulatorStatus: () => command('ui_get_simulator_status'),
    retrySimulator: () => command('ui_retry_simulator'),
    listSimulatorEndpoints: (path) => command('ui_list_simulator_endpoints', { path }),
    getSimulatorValue: (path) => command('ui_get_simulator_value', { path }),
    setPhysicalOutput: (output_id, high, port, generation) => command('ui_set_physical_output', { output_id, high, port, generation }),
    testDisplay: (module_id, text, port, generation) => command('ui_test_display', { module_id, text, port, generation }),
    onHardwareInput(handler: (event: HardwareInputEvent) => void): Unsubscribe {
      if (!ipc.isDesktop()) return () => {};
      let stop: Unlisten | undefined;
      let active = true;
      void ipc
        .listen('ui://hardware/input', (payload) => {
          if (active && isHardwareInputEvent(payload)) handler(payload);
        })
        .then((unlisten) => {
          if (active) {
            stop = unlisten;
          } else {
            unlisten();
          }
        })
        .catch(() => undefined);
      return () => {
        active = false;
        stop?.();
        stop = undefined;
      };
    },

    // ---- Wave-2 UI track B: sequences ------------------------------------------
    createSequence: (trainId, name) => command('ui_create_sequence', { train_id: trainId, name }),
    updateSequence: (id, name) => command('ui_update_sequence', { id, name }),
    deleteSequence: (id) => command('ui_delete_sequence', { id }),
    setSequenceCommands: (sequenceId, commands) => command('ui_set_sequence_commands', { sequence_id: sequenceId, commands }),
    testSequence: (sequenceId) => command('ui_test_sequence', { sequence_id: sequenceId }),

    // ---- Wave-2 UI track B: scripts page ---------------------------------------
    getScripts: () => command('ui_get_scripts'),
    createScript: (trainId, name, code, triggers) => command('ui_create_script', { train_id: trainId, name, code, triggers }),
    updateScript: (id, patch) => command('ui_update_script', { id, ...patch }),
    deleteScript: (id) => command('ui_delete_script', { id }),
    reloadScripts: () => command('ui_reload_scripts'),
    runScript: (id) => command('ui_run_script', { id }),
    getScriptLog: (id) => command('ui_get_script_log', { id }),

    // ---- Wave-2 UI track B: virtual joystick page -------------------------------
    getVjoy: () => command('ui_get_vjoy'),
    vjoyEnable: () => command('ui_vjoy_enable'),
    vjoyDisable: () => command('ui_vjoy_disable'),
    setVjoySelection: (devices) => command('ui_set_vjoy_selection', { devices }),
    putVjoyMapping: (inputId, draft, replace) => command('ui_put_vjoy_mapping', { input_id: inputId, ...draft, replace }),
    deleteVjoyMapping: (id) => command('ui_delete_vjoy_mapping', { id }),

    // ---- Wave-2 UI track B: firmware page ---------------------------------------
    getFirmware: () => command('ui_get_firmware'),
    checkFirmwareUpdates: () => command('ui_check_firmware_updates'),
    firmwareUpdateStatus: () => command('ui_firmware_update_status'),
    dismissFirmwareUpdate: () => command('ui_dismiss_firmware_update'),
    downloadFirmware: (releaseId, environment) => command('ui_download_firmware', { release_id: releaseId, environment }),
    startFirmwareUpload: (firmwareFileId, port, environment, generation) =>
      command('ui_start_firmware_upload', { firmware_file_id: firmwareFileId, port, environment, generation }),
    cancelFirmwareUpload: (uploadId) => command('ui_cancel_firmware_upload', { upload_id: uploadId }),

    async subscribe<T>(topic: Topic, onValue: (value: UiSnapshot<T>) => void, onUnavailable: (error: UiFailure) => void) {
      if (!ipc.isDesktop()) {
        onUnavailable(unavailable('Desktop subscriptions are unavailable in this browser.'));
        return () => {};
      }

      const subscriptionId = newSubscriptionId();
      const stream = new TopicStream<T>(topic);
      const eventName = `ui://change/${topic}`;
      let active = true;
      let starting = false;
      let registered = false;
      let subscribeAttempted = false;
      let stopListening: Unlisten | undefined;
      let retryTimer: ReturnType<typeof setTimeout> | undefined;
      let retryAttempt = 0;
      let fetchingSnapshot = false;
      let snapshotQueued = false;

      const report = (error: unknown, message: string) => {
        if (active) onUnavailable(normalizeIpcFailure(error, unavailable(message)));
      };

      const schedule = (task: () => void) => {
        if (!active || retryTimer) return;
        const delay = Math.min(250 * 2 ** Math.min(retryAttempt, 4), 4_000);
        retryAttempt += 1;
        retryTimer = setTimeout(() => {
          retryTimer = undefined;
          if (active) task();
        }, delay);
      };

      const requestSnapshot = async () => {
        if (!active || !registered) return;
        if (fetchingSnapshot) {
          snapshotQueued = true;
          return;
        }

        fetchingSnapshot = true;
        const snapshotRequest = stream.beginSnapshot();
        let retryRequired = false;
        try {
          const input = await ipc.invoke('ui_get_snapshot', { topic });
          if (!active) return;
          const result = stream.installSnapshot(input, snapshotRequest);
          if (result.kind === 'invalid') {
            retryRequired = true;
            report(undefined, `The ${topic} service sent an invalid snapshot.`);
          } else if (result.kind === 'resync') {
            retryRequired = true;
            if (result.value) onValue(result.value);
          } else if (result.kind === 'applied') {
            onValue(result.value);
            retryAttempt = 0;
          } else if (stream.needsSnapshot()) {
            retryRequired = true;
          }
        } catch (error) {
          retryRequired = true;
          report(error, `The ${topic} snapshot command is not integrated yet.`);
        } finally {
          fetchingSnapshot = false;
          const queued = snapshotQueued;
          snapshotQueued = false;
          if (active && (retryRequired || queued || stream.needsSnapshot())) schedule(() => void requestSnapshot());
        }
      };

      const onChange = (payload: unknown) => {
        if (!active) return;
        const result = stream.accept(payload);
        if (result.kind === 'invalid') {
          report(undefined, `The ${topic} service sent an invalid change.`);
          void requestSnapshot();
        } else if (result.kind === 'applied') {
          onValue(result.value);
        } else if (result.kind === 'resync') {
          if (result.value) onValue(result.value);
          void requestSnapshot();
        }
      };

      const releaseRemote = () => {
        if (!registered && !subscribeAttempted) return;
        registered = false;
        subscribeAttempted = false;
        void ipc.invoke('ui_unsubscribe', { topic, subscription_id: subscriptionId }).catch(() => undefined);
      };

      const start = async () => {
        if (!active || starting || registered) return;
        starting = true;
        try {
          stopListening = await ipc.listen(eventName, onChange);
          if (!active) {
            stopListening();
            stopListening = undefined;
            return;
          }
          subscribeAttempted = true;
          await ipc.invoke('ui_subscribe', { topic, subscription_id: subscriptionId });
          registered = true;
          if (!active) {
            releaseRemote();
            stopListening?.();
            stopListening = undefined;
            return;
          }
          retryAttempt = 0;
          await requestSnapshot();
        } catch (error) {
          report(error, `The ${topic} subscription is not available yet.`);
          stopListening?.();
          stopListening = undefined;
          releaseRemote();
          schedule(() => void start());
        } finally {
          starting = false;
        }
      };

      void start();
      return () => {
        if (!active) return;
        active = false;
        if (retryTimer) clearTimeout(retryTimer);
        retryTimer = undefined;
        stopListening?.();
        stopListening = undefined;
        // Observation cleanup is scoped to this subscriber; it never cancels an operation.
        releaseRemote();
      };
    },
  };
}

export const bridge = createBridge(tauriTransport);
