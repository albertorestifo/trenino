import { invoke } from '@tauri-apps/api/core';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';
import type { ConfigurationSummaryView, SettingsView, TrainSummaryView, UiChange, UiFailure, UiSnapshot } from './generated';
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
  subscribe<T>(topic: Topic, onValue: (value: UiSnapshot<T>) => void, onUnavailable: (error: UiFailure) => void): Promise<Unsubscribe>;
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
        let retryRequired = false;
        try {
          const input = await ipc.invoke('ui_get_snapshot', { topic });
          if (!active) return;
          const result = stream.installSnapshot(input);
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
