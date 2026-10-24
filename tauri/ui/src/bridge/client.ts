import { invoke } from '@tauri-apps/api/core';
import { listen, type UnlistenFn } from '@tauri-apps/api/event';
import type { ConfigurationSummaryView, SettingsView, TrainSummaryView, UiChange, UiFailure, UiSnapshot } from './generated';
import { TopicStream } from './stream';

export type Result<T> = { ok: true; value: T } | { ok: false; error: UiFailure };
export type Unsubscribe = () => void;

type Topic = UiSnapshot<unknown>['topic'];

export interface UiBridge {
  getSettings(): Promise<Result<UiSnapshot<SettingsView>>>;
  getConfigurations(): Promise<Result<UiSnapshot<ConfigurationSummaryView[]>>>;
  getTrains(): Promise<Result<UiSnapshot<TrainSummaryView[]>>>;
  setConsent(value: 'enabled' | 'disabled'): Promise<Result<UiSnapshot<SettingsView>>>;
  subscribe<T>(topic: Topic, onValue: (value: UiSnapshot<T>) => void, onUnavailable: (error: UiFailure) => void): Promise<Unsubscribe>;
}

const unavailable = (message = 'The Rust desktop service is not available yet.'): UiFailure => ({
  code: 'unavailable', message, field_errors: {}, retryable: true,
});

function isDesktop(): boolean {
  return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
}

async function command<T>(name: string, args?: Record<string, unknown>): Promise<Result<T>> {
  if (!isDesktop()) return { ok: false, error: unavailable('Open Trenino from the desktop app to connect to Rust services.') };
  try {
    return { ok: true, value: await invoke<T>(name, args) };
  } catch {
    return { ok: false, error: unavailable() };
  }
}

export const bridge: UiBridge = {
  getSettings: () => command('ui_get_settings'),
  getConfigurations: () => command('ui_list_configurations'),
  getTrains: () => command('ui_list_trains'),
  setConsent: (value) => command('ui_set_consent', { value }),
  async subscribe<T>(topic: Topic, onValue: (value: UiSnapshot<T>) => void, onUnavailable: (error: UiFailure) => void) {
    if (!isDesktop()) {
      onUnavailable(unavailable('Desktop subscriptions are unavailable in this browser.'));
      return () => {};
    }

    let stopListening: UnlistenFn | undefined;
    let active = true;
    const stream = new TopicStream<T>();
    const eventName = `ui://change/${topic}`;
    try {
      stopListening = await listen<UiChange<T>>(eventName, ({ payload }) => {
        const result = stream.accept(payload);
        if (result.kind === 'applied') onValue(result.value);
        if (result.kind === 'resync') void refresh();
      });
      await invoke('ui_subscribe', { topic });
      await refresh();
    } catch {
      active = false;
      stopListening?.();
      onUnavailable(unavailable(`The ${topic} snapshot command is not integrated yet.`));
    }

    async function refresh() {
      try {
        const snapshot = await invoke<UiSnapshot<T>>('ui_get_snapshot', { topic });
        if (!active) return;
        const result = stream.installSnapshot(snapshot);
        if (result.kind === 'applied') onValue(result.value);
        if (result.kind === 'resync') queueMicrotask(() => void refresh());
      } catch {
        if (active) onUnavailable(unavailable(`The ${topic} snapshot command is not integrated yet.`));
      }
    }

    return () => {
      active = false;
      stopListening?.();
      // Observation ends here; service operation cancellation is a separate command.
      void invoke('ui_unsubscribe', { topic }).catch(() => undefined);
    };
  },
};
