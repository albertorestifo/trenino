import { vi, type Mock } from 'vitest';
import type { UiBridge } from '../src/bridge/client';
import type { UiSnapshot } from '../src/bridge/generated';

/** The service error shape used when a command is "not integrated yet". */
export const serviceUnavailable = {
  code: 'unavailable' as const,
  message: 'The Rust desktop service is not integrated.',
  field_errors: {},
  retryable: true,
};

/** A UiBridge whose command methods are all vi mocks. */
export type FakeBridge = UiBridge & { [K in keyof UiBridge]: Mock };

/** Per-method mock overrides for {@link createFakeBridge}. */
export type BridgeOverrides = Partial<{ [K in keyof UiBridge]: Mock }>;

export function snapshot<T>(topic: UiSnapshot<T>['topic'], value: T, revision = '1'): UiSnapshot<T> {
  return { epoch: '1', topic, revision, value };
}

/**
 * A fully mocked UiBridge: every command resolves to a seeded value or a
 * service-unavailable failure, and individual tests override what they need.
 */
export function createFakeBridge(overrides: BridgeOverrides = {}): FakeBridge {
  const base: BridgeOverrides = {
    getSettings: vi.fn(async () => ({
      ok: true as const,
      value: snapshot('settings', {
        error_reporting: 'disabled' as const,
        simulator: { url: 'http://localhost:31270', api_key_configured: false },
      }),
    })),
    getConfigurations: vi.fn(async () => ({ ok: true as const, value: snapshot('hardware', []) })),
    getTrains: vi.fn(async () => ({ ok: true as const, value: snapshot('trains', []) })),
    setConsent: vi.fn(async () => ({ ok: false as const, error: serviceUnavailable })),
    serialPorts: vi.fn(async () => ({ ok: true as const, value: [] })),
    getSimulatorStatus: vi.fn(async () => ({ ok: true as const, value: { status: 'disconnected', last_error: null, active_train_id: null, detected_identifier: null } })),
    retrySimulator: vi.fn(async () => ({ ok: true as const, value: true })),
    firmwareUpdateStatus: vi.fn(async () => ({ ok: true as const, value: { checking: false, checked_at_ms: null, found_updates: false, latest_version: null, error_message: null, notice: null } })),
    dismissFirmwareUpdate: vi.fn(async () => ({ ok: true as const, value: { checking: false, checked_at_ms: null, found_updates: false, latest_version: null, error_message: null, notice: null } })),
    onHardwareInput: vi.fn(() => () => {}),
    onHardwareDetection: vi.fn(() => () => {}),
    activateTrain: vi.fn(async () => ({ ok: true })),
    suggestLever: vi.fn(async () => ({ match: null })),
    suggestButton: vi.fn(async () => ({ match: null })),
    getVjoyStatus: vi.fn(async () => ({ ok: true as const, value: { state: 'off' as const, reason: null } })),
    removeVjoyLeftover: vi.fn(async () => ({ ok: true as const, value: { ok: true } })),
    repairVjoy: vi.fn(async () => ({ ok: true as const, value: { ok: true } })),
    startControlDetection: vi.fn(async () => ({ ok: false as const, error: serviceUnavailable })),
    controlDetectionStatus: vi.fn(async () => ({ ok: false as const, error: serviceUnavailable })),
    cancelControlDetection: vi.fn(async () => ({ ok: true as const, value: true })),
    startLeverAnalysis: vi.fn(async () => ({ ok: false as const, error: serviceUnavailable })),
    leverAnalysisStatus: vi.fn(async () => ({ ok: false as const, error: serviceUnavailable })),
    cancelLeverAnalysis: vi.fn(async () => ({ ok: true as const, value: true })),
    startLeverCalibration: vi.fn(async () => ({ ok: false as const, error: serviceUnavailable })),
    leverCalibrationStatus: vi.fn(async () => ({ ok: false as const, error: serviceUnavailable })),
    cancelLeverCalibration: vi.fn(async () => ({ ok: true as const, value: true })),
    subscribe: vi.fn(async () => () => {}),
    previewInput: vi.fn(async (_id: string, raw: number) => ({ ok: true as const, value: { calibrated: raw, travel: 1023, axis_percent: Math.round(raw / 1023 * 100), max_hardware_value: 1023, min_notch_samples: 10 } })),
    previewNotchMapping: vi.fn(async () => ({ ok: true as const, value: { inverted: false, ranges: [], travel: 1023 } })),
    previewDisplay: vi.fn(async () => ({ ok: true as const, value: { valid: true, error: null, rendered: '42.5', overflow: false, missing_dot: false } })),
    previewOutputCondition: vi.fn(async (_operator: string, valueA: number | null) => ({ ok: true as const, value: { valid: true, error: null, explanation: `LED turns ON when value > ${valueA ?? '?'}`, example_on: false } })),
    ...Object.fromEntries(Object.entries(overrides).filter(([, value]) => value !== undefined)),
  };
  return base as unknown as FakeBridge;
}

/** Resolves after every pending microtask (bridge promises in tests). */
export async function flushPromises(depth = 12): Promise<void> {
  for (let index = 0; index < depth; index += 1) await Promise.resolve();
}
