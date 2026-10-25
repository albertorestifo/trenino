import { fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { describe, expect, it, vi } from 'vitest';
import CalibrationWizard from '../src/components/calibration-wizard.svelte';
import MatrixTestWizard from '../src/components/matrix-test-wizard.svelte';
import { detailBridge, seededDetail } from './configuration-edit.test';
import type { CalibrationView, InputView, MatrixView } from '../src/bridge/generated';

const analogInput: InputView = { id: '11', pin: 3, kind: 'analog', sensitivity: 5, debounce: null, name: 'Throttle', calibration: null };
const finished: CalibrationView = { min_value: 12, max_value: 980, has_rollover: false, is_inverted: true };

describe('calibration wizard', () => {
  it('starts a session, walks the step indicator and completes with the saved calibration', async () => {
    const bridge = detailBridge({
      advanceCalibration: vi.fn()
        .mockResolvedValueOnce({ ok: true as const, value: null })
        .mockResolvedValueOnce({ ok: true as const, value: null })
        .mockResolvedValueOnce({ ok: true as const, value: null })
        .mockResolvedValueOnce({ ok: true as const, value: finished }),
    });
    render(CalibrationWizard, { props: { input: analogInput, port: '/dev/ttyUSB0', generation: 7, api: bridge, close: vi.fn() } });
    expect(await screen.findByText('Set minimum')).toBeInTheDocument();
    expect(bridge.startCalibration).toHaveBeenCalledWith({ port: '/dev/ttyUSB0', generation: 7, pin: 3, input_id: '11', max_hardware_value: 1023 });

    await fireEvent.click(screen.getByRole('button', { name: 'Start' }));
    expect(await screen.findByText('Sweep range')).toBeInTheDocument();
    await fireEvent.click(screen.getByRole('button', { name: 'Next: Sweep' }));
    expect(await screen.findByText('Set maximum')).toBeInTheDocument();
    await fireEvent.click(screen.getByRole('button', { name: 'Next: Set Max' }));
    expect(await screen.findByText('Analyzing calibration data…')).toBeInTheDocument();
    await fireEvent.click(screen.getByRole('button', { name: 'Finish' }));
    expect(await screen.findByText('Calibration Complete!')).toBeInTheDocument();
    expect(screen.getByText('980')).toBeInTheDocument();
    expect(screen.getByText('Yes')).toBeInTheDocument(); // inverted
  });

  it('shows the loading state until the session id arrives', async () => {
    const start = Promise.withResolvers<{ ok: true; value: string }>();
    const bridge = detailBridge({ startCalibration: vi.fn(() => start.promise) });
    render(CalibrationWizard, { props: { input: analogInput, port: '/dev/ttyUSB0', generation: 7, api: bridge, close: vi.fn() } });
    expect(screen.getByText('Starting calibration session…')).toBeInTheDocument();
    start.resolve({ ok: true, value: '77' });
    expect(await screen.findByText('Set minimum')).toBeInTheDocument();
  });

  it('uses the Rust ceiling returned for the selected input', async () => {
    const bridge = detailBridge({ calibrationCeiling: vi.fn(async () => ({ ok: true as const, value: 4095 })) });
    render(CalibrationWizard, { props: { input: analogInput, port: '/dev/ttyUSB0', generation: 7, api: bridge, close: vi.fn() } });
    await waitFor(() => expect(bridge.startCalibration).toHaveBeenCalledWith(expect.objectContaining({ max_hardware_value: 4095 })));
  });

  it('cancels a session that starts after the wizard is removed', async () => {
    const start = Promise.withResolvers<{ ok: true; value: string }>();
    const bridge = detailBridge({ startCalibration: vi.fn(() => start.promise) });
    const view = render(CalibrationWizard, { props: { input: analogInput, port: '/dev/ttyUSB0', generation: 7, api: bridge, close: vi.fn() } });
    await waitFor(() => expect(bridge.startCalibration).toHaveBeenCalled());
    view.unmount();
    start.resolve({ ok: true, value: 'late-session' });
    await waitFor(() => expect(bridge.cancelCalibration).toHaveBeenCalledWith('late-session'));
  });

  it('surfaces a failed start as a UiFailure message', async () => {
    const bridge = detailBridge({
      startCalibration: vi.fn(async () => ({ ok: false as const, error: { code: 'conflict' as const, message: 'Calibration could not start: port closed.', field_errors: {}, retryable: true } })),
    });
    render(CalibrationWizard, { props: { input: analogInput, port: '/dev/ttyUSB0', generation: 7, api: bridge, close: vi.fn() } });
    expect(await screen.findByText('Calibration could not start: port closed.')).toBeInTheDocument();
  });

  it('keeps the wizard open with an inline error when advancing is rejected', async () => {
    const bridge = detailBridge({
      advanceCalibration: vi.fn(async () => ({ ok: false as const, error: { code: 'unavailable' as const, message: 'Calibration could not advance: insufficient samples.', field_errors: {}, retryable: true } })),
    });
    render(CalibrationWizard, { props: { input: analogInput, port: '/dev/ttyUSB0', generation: 7, api: bridge, close: vi.fn() } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Start' }));
    expect(await screen.findByText('Calibration could not advance: insufficient samples.')).toBeInTheDocument();
    expect(screen.getByText('Set minimum')).toBeInTheDocument();
  });

  it('cancels the session and closes', async () => {
    const close = vi.fn();
    const bridge = detailBridge();
    render(CalibrationWizard, { props: { input: analogInput, port: '/dev/ttyUSB0', generation: 7, api: bridge, close } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Cancel' }));
    await waitFor(() => expect(bridge.cancelCalibration).toHaveBeenCalledWith('5001'));
    expect(close).toHaveBeenCalled();
  });

  it('retains the session and modal when cancellation fails, then retries the same session', async () => {
    const close = vi.fn();
    const cancelCalibration = vi.fn()
      .mockResolvedValueOnce({ ok: false as const, error: { code: 'conflict' as const, message: 'Hardware cleanup is still pending.', field_errors: {}, retryable: true } })
      .mockResolvedValueOnce({ ok: true as const, value: false });
    const bridge = detailBridge({ cancelCalibration });
    render(CalibrationWizard, { props: { input: analogInput, port: '/dev/ttyUSB0', generation: 7, api: bridge, close } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Cancel' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Hardware cleanup is still pending.');
    expect(close).not.toHaveBeenCalled();
    expect(screen.getByRole('dialog')).toBeInTheDocument();
    await fireEvent.click(screen.getByRole('button', { name: 'Retry cancel' }));
    await waitFor(() => expect(close).toHaveBeenCalledOnce());
    expect(cancelCalibration).toHaveBeenNthCalledWith(1, '5001');
    expect(cancelCalibration).toHaveBeenNthCalledWith(2, '5001');
  });

  it('ignores duplicate close actions while cleanup ACK is pending', async () => {
    const pending = Promise.withResolvers<{ ok: true; value: boolean }>();
    const close = vi.fn();
    const cancelCalibration = vi.fn(() => pending.promise);
    const bridge = detailBridge({ cancelCalibration });
    render(CalibrationWizard, { props: { input: analogInput, port: '/dev/ttyUSB0', generation: 7, api: bridge, close } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Cancel' }));
    await fireEvent.click(screen.getByRole('button', { name: 'Close' }));
    await fireEvent.click(screen.getByRole('dialog').firstElementChild!);
    expect(cancelCalibration).toHaveBeenCalledTimes(1);
    expect(close).not.toHaveBeenCalled();
    pending.resolve({ ok: true, value: true });
    await waitFor(() => expect(close).toHaveBeenCalledOnce());
  });
});

describe('matrix test wizard', () => {
  const matrix = seededDetail.matrices[0] as MatrixView;

  it('renders the virtual pin grid and progress from tested buttons', async () => {
    render(MatrixTestWizard, { props: { matrix, inputValues: {}, testedButtons: [128], reset: vi.fn(), close: vi.fn() } });
    expect(await screen.findByText('2 rows x 1 columns')).toBeInTheDocument();
    expect(screen.getByText('1 / 2 buttons tested')).toBeInTheDocument();
    expect(screen.getByText(/\(50%\)/)).toBeInTheDocument();
    expect(document.querySelector('[data-virtual-pin="128"]')).toBeInTheDocument();
    expect(document.querySelector('[data-virtual-pin="129"]')).toBeInTheDocument();
  });

  it('marks currently pressed and tested virtual pins from live input events', async () => {
    const { rerender } = render(MatrixTestWizard, { props: { matrix, inputValues: {}, testedButtons: [], reset: vi.fn(), close: vi.fn() } });
    rerender({ matrix, inputValues: { 128: 1, 3: 1 }, testedButtons: [], reset: vi.fn(), close: vi.fn() });
    const pressed = document.querySelector('[data-virtual-pin="128"]');
    expect(pressed?.className).toContain('ring-4');
    const untouched = document.querySelector('[data-virtual-pin="129"]');
    expect(untouched?.className).toContain('bg-base-300');
  });

  it('resets progress and closes via the action buttons', async () => {
    const reset = vi.fn();
    const close = vi.fn();
    render(MatrixTestWizard, { props: { matrix, inputValues: {}, testedButtons: [128, 129], reset, close } });
    expect(screen.getByText('2 / 2 buttons tested')).toBeInTheDocument();
    await fireEvent.click(screen.getByRole('button', { name: 'Reset' }));
    expect(reset).toHaveBeenCalled();
    await fireEvent.click(screen.getAllByRole('button', { name: 'Close' }).at(-1)!);
    expect(close).toHaveBeenCalled();
  });
});
