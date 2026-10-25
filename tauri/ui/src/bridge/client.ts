import { invoke } from '@tauri-apps/api/core';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';
import type { CalibrationView, ConfigurationSummaryView, DeviceDetailView, SettingsView, TrainSummaryView, UiChange, UiFailure, UiSnapshot } from './generated';
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

export interface UiBridge {
  getSettings(): Promise<Result<UiSnapshot<SettingsView>>>;
  getConfigurations(): Promise<Result<UiSnapshot<ConfigurationSummaryView[]>>>;
  getTrains(): Promise<Result<UiSnapshot<TrainSummaryView[]>>>;
  setConsent(value: 'enabled' | 'disabled'): Promise<Result<UiSnapshot<SettingsView>>>;
  // ---- Configuration detail + settings edit (UiGroupA track) ----
  // Optional so parallel UI tracks can extend this interface without merge conflicts.
  getHardwareDetail?(id: string): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  getHardwareDetailByConfig?(configId: string): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  createConfiguration?(name: string, description?: string | null): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  updateConfiguration?(id: string, patch: { name?: string; description?: string | null }): Promise<Result<UiSnapshot<ConfigurationSummaryView[]>>>;
  deleteConfiguration?(id: string): Promise<Result<UiSnapshot<ConfigurationSummaryView[]>>>;
  createInput?(params: { device_id: string; pin: number; kind: 'analog' | 'button'; sensitivity?: number | null; debounce?: number | null; name?: string | null; matrix_id?: string | null }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  updateInput?(params: { id: string; pin: number; kind: 'analog' | 'button'; sensitivity?: number | null; debounce?: number | null; name?: string | null }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  deleteInput?(id: string): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  createOutput?(params: { device_id: string; pin: number; name?: string | null }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  updateOutput?(params: { id: string; pin: number; name?: string | null }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  deleteOutput?(id: string): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  createMatrix?(params: { device_id: string; name: string; row_pins: number[]; col_pins: number[] }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  updateMatrix?(params: { id: string; row_pins: number[]; col_pins: number[] }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  deleteMatrix?(id: string): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  createI2cModule?(params: { device_id: string; name?: string | null; module_chip: string; i2c_address: number }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  updateI2cModule?(params: { id: string; name?: string | null; module_chip: string; i2c_address: number }): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  deleteI2cModule?(id: string): Promise<Result<UiSnapshot<DeviceDetailView>>>;
  startCalibration?(params: { port: string; generation: number; pin: number; input_id: string; max_hardware_value: number }): Promise<Result<string>>;
  advanceCalibration?(session_id: string): Promise<Result<CalibrationView | null>>;
  cancelCalibration?(session_id: string): Promise<Result<boolean>>;
  setSimulatorUrl?(value: string): Promise<Result<UiSnapshot<SettingsView>>>;
  setApiKey?(value: string): Promise<Result<UiSnapshot<SettingsView>>>;
  testSimulator?(): Promise<Result<boolean>>;
  onHardwareInput?(handler: (event: HardwareInputEvent) => void): Promise<Unsubscribe>;
  subscribe<T>(topic: Topic, onValue: (value: UiSnapshot<T>) => void, onUnavailable: (error: UiFailure) => void): Promise<Unsubscribe>;
}

/** Live hardware input sample emitted on `ui://hardware/input` (hand-written; not ts-rs generated). */
export interface HardwareInputEvent {
  device_id: string;
  input_id: string;
  pin: number;
  value: number;
  config_id: number;
  port_generation: number;
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
    // ---- Configuration detail + settings edit (UiGroupA track) ----
    getHardwareDetail: (id) => command('ui_get_hardware_detail', { id }),
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
    setSimulatorUrl: (value) => command('ui_set_simulator_url', { value }),
    setApiKey: (value) => command('ui_set_api_key', { value }),
    testSimulator: () => command('ui_test_simulator'),
    onHardwareInput: (handler) => {
      if (!ipc.isDesktop()) return Promise.resolve(() => {});
      return ipc.listen('ui://hardware/input', (payload) => handler(payload as HardwareInputEvent));
    },
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
