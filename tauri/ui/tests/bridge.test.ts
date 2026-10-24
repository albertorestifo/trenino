import { afterEach, describe, expect, it, vi } from 'vitest';
import { createBridge, type IpcTransport } from '../src/bridge/client';
import type { UiChange, UiSnapshot } from '../src/bridge/generated';

function failure(code = 'validation', message = 'The URL is invalid.'): object {
  return { code, message, field_errors: { 'simulator.url': message }, retryable: false };
}

function transport(invoke: IpcTransport['invoke'] = vi.fn(async () => undefined), listen: IpcTransport['listen'] = vi.fn(async () => () => {})): IpcTransport {
  return { isDesktop: () => true, invoke, listen };
}

const snapshot: UiSnapshot<{ ok: boolean }> = { epoch: '1', topic: 'settings', revision: '1', value: { ok: true } };
const event = (revision: string): UiChange<{ ok: boolean }> => ({ epoch: '1', topic: 'settings', revision, value: { ok: true } });

async function flushMicrotasks() {
  for (let index = 0; index < 12; index += 1) await Promise.resolve();
}

afterEach(() => vi.useRealTimers());

describe('bridge failure handling', () => {
  it('preserves a structured Rust validation failure', async () => {
    const bridge = createBridge(transport(vi.fn().mockRejectedValue(failure())));
    const result = await bridge.getSettings();
    expect(result).toEqual({ ok: false, error: { ...failure(), code: 'validation' } });
  });

  it('redacts internal messages and field details while retaining retryability', async () => {
    const bridge = createBridge(transport(vi.fn().mockRejectedValue(failure('internal', 'API key is abc-secret'))));
    const result = await bridge.getSettings();
    expect(result).toEqual({ ok: false, error: { code: 'internal', message: 'The Rust service could not complete the request.', field_errors: {}, retryable: false } });
  });

  it('replaces malformed structured rejections with a generic unavailable failure', async () => {
    const bridge = createBridge(transport(vi.fn().mockRejectedValue({ code: 'bad', message: 'secret detail', field_errors: [], retryable: 'yes' })));
    const result = await bridge.getSettings();
    expect(result).toEqual({ ok: false, error: { code: 'unavailable', message: 'The Rust desktop service is not available yet.', field_errors: {}, retryable: true } });
  });

  it('keeps authoritative Rust errors from consent writes', async () => {
    const bridge = createBridge(transport(vi.fn().mockRejectedValue(failure('conflict', 'Consent changed in another window.'))));
    const result = await bridge.setConsent('enabled');
    expect(result).toEqual({ ok: false, error: { ...failure('conflict', 'Consent changed in another window.'), code: 'conflict' } });
  });
});

describe('bridge subscription recovery', () => {
  it('retries a failed first snapshot and applies the next authoritative snapshot', async () => {
    vi.useFakeTimers();
    let attempts = 0;
    const invoke = vi.fn(async (command: string, _args?: Record<string, unknown>) => {
      if (command === 'ui_get_snapshot') {
        attempts += 1;
        if (attempts === 1) throw failure('unavailable', 'snapshot not ready');
        return snapshot;
      }
      return undefined;
    });
    const bridge = createBridge(transport(invoke));
    const values: UiSnapshot<{ ok: boolean }>[] = [];
    const unavailable = vi.fn();
    const unsubscribe = await bridge.subscribe<{ ok: boolean }>('settings', (value) => values.push(value), unavailable);
    await flushMicrotasks();
    expect(unavailable).toHaveBeenCalledWith(failure('unavailable', 'snapshot not ready'));
    expect(values).toHaveLength(0);

    await vi.advanceTimersByTimeAsync(250);
    await flushMicrotasks();
    expect(values).toEqual([snapshot]);
    unsubscribe();
  });

  it('coalesces a burst behind one hung fetch and disposes pending work safely', async () => {
    vi.useFakeTimers();
    let resolveFetch!: (value: unknown) => void;
    const pendingFetch = new Promise<unknown>((resolve) => (resolveFetch = resolve));
    let onChange: ((change: unknown) => void) | undefined;
    const stop = vi.fn();
    const listen: IpcTransport['listen'] = vi.fn(async (_name, handler) => {
      onChange = handler;
      return stop;
    });
    const invoke = vi.fn(async (command: string, _args?: Record<string, unknown>) => command === 'ui_get_snapshot' ? pendingFetch : undefined);
    const bridge = createBridge(transport(invoke, listen));
    const onValue = vi.fn();
    const unsubscribe = await bridge.subscribe('settings', onValue, vi.fn());
    await flushMicrotasks();
    for (let revision = 2; revision <= 10_001; revision += 1) onChange?.(event(String(revision)));
    expect(invoke.mock.calls.filter(([command]) => command === 'ui_get_snapshot')).toHaveLength(1);

    unsubscribe();
    expect(stop).toHaveBeenCalledTimes(1);
    await flushMicrotasks();
    resolveFetch(snapshot);
    await flushMicrotasks();
    expect(onValue).not.toHaveBeenCalled();
    expect(invoke.mock.calls.filter(([command]) => command === 'ui_unsubscribe')).toHaveLength(1);
  });

  it('scopes same-topic unsubscription to its unique observer id', async () => {
    const callbacks = new Set<(payload: unknown) => void>();
    const listen: IpcTransport['listen'] = vi.fn(async (_name, handler) => {
      callbacks.add(handler);
      return () => callbacks.delete(handler);
    });
    const invoke = vi.fn(async (command: string, _args?: Record<string, unknown>) => command === 'ui_get_snapshot' ? snapshot : undefined);
    const bridge = createBridge(transport(invoke, listen));
    const firstValues = vi.fn();
    const secondValues = vi.fn();
    const stopFirst = await bridge.subscribe('settings', firstValues, vi.fn());
    const stopSecond = await bridge.subscribe('settings', secondValues, vi.fn());
    await flushMicrotasks();
    const registrations = invoke.mock.calls.filter(([command]) => command === 'ui_subscribe').map(([, args]) => args as Record<string, unknown>);
    expect(registrations).toHaveLength(2);
    expect(registrations[0].subscription_id).not.toBe(registrations[1].subscription_id);
    stopFirst();
    for (const callback of callbacks) callback(event('2'));
    expect(firstValues).toHaveBeenCalledTimes(1);
    expect(secondValues).toHaveBeenCalledTimes(2);
    const unsubscriptions = invoke.mock.calls.filter(([command]) => command === 'ui_unsubscribe').map(([, args]) => args as Record<string, unknown>);
    expect(unsubscriptions).toEqual([{ topic: 'settings', subscription_id: registrations[0].subscription_id }]);
    stopSecond();
  });

  it('releases an observer that is unmounted while registration is pending', async () => {
    let resolveRegistration!: (value: unknown) => void;
    const registration = new Promise<unknown>((resolve) => (resolveRegistration = resolve));
    const invoke = vi.fn(async (command: string, _args?: Record<string, unknown>) => command === 'ui_subscribe' ? registration : command === 'ui_get_snapshot' ? snapshot : undefined);
    const bridge = createBridge(transport(invoke));
    const onValue = vi.fn();
    const unsubscribe = await bridge.subscribe<{ ok: boolean }>('settings', onValue, vi.fn());
    await flushMicrotasks();
    unsubscribe();
    resolveRegistration(undefined);
    await flushMicrotasks();

    const registrations = invoke.mock.calls.filter(([command]) => command === 'ui_subscribe').map(([, args]) => args as Record<string, unknown>);
    const unsubscriptions = invoke.mock.calls.filter(([command]) => command === 'ui_unsubscribe').map(([, args]) => args as Record<string, unknown>);
    expect(unsubscriptions.length).toBeGreaterThan(0);
    expect(unsubscriptions.every((args) => args.subscription_id === registrations[0].subscription_id)).toBe(true);
    expect(invoke.mock.calls.some(([command]) => command === 'ui_get_snapshot')).toBe(false);
    expect(onValue).not.toHaveBeenCalled();
  });
});
