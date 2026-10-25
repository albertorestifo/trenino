import { fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { describe, expect, it, vi } from 'vitest';
import GuidedSimulatorSession from '../src/components/GuidedSimulatorSession.svelte';
import LeverSetupWizard from '../src/components/wizards/LeverSetupWizard.svelte';
import ButtonBindingWizard from '../src/components/wizards/ButtonBindingWizard.svelte';
import type { GuidedSessionSnapshot } from '../src/bridge/client';
import type { ElementView, TrainDetailView } from '../src/bridge/generated';
import { createFakeBridge, snapshot } from './helpers';

function session(partial: Partial<GuidedSessionSnapshot>): GuidedSessionSnapshot {
  return {
    session_id: '8', state: 'listening', cleanup_pending: false, changes: [], ambiguous: false, remaining_ms: 30000,
    analysis: null, analysis_progress: null, calibration: null, progress: null, message: null,
    ...partial,
  };
}

const lever: ElementView = { id: '80', name: 'Throttle', kind: 'lever', lever_config: null };
const leverHardware = { inputs: [{ id: '11', device_id: '7', device_name: 'Board', pin: 3, kind: 'analog' as const,
  name: 'Throttle', calibration: { min_value: 0, max_value: 1023, has_rollover: false, is_inverted: false } }], outputs: [], displays: [] };
const train: TrainDetailView = { id: '10', name: 'Train', description: null, identifiers: [], elements: [lever], sequences: [] };

describe('guided simulator sessions', () => {
  it('lets a user choose among ambiguous detections', async () => {
    const onUse = vi.fn();
    const bridge = createFakeBridge({
      startControlDetection: vi.fn(async () => ({ ok: true as const, value: { session_id: '8' } })),
      controlDetectionStatus: vi.fn(async () => ({ ok: true as const, value: session({ state: 'detected', ambiguous: true, changes: [
        { endpoint: 'Horn.InputValue', control_name: 'Horn', previous_value: 0, current_value: 1 },
        { endpoint: 'Bell.InputValue', control_name: 'Bell', previous_value: 0, current_value: 1 },
      ] }) })),
    });
    render(GuidedSimulatorSession, { props: { bridge, mode: 'detection', onUse, onClose: vi.fn() } });
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    expect(await screen.findByText('Several controls changed. Choose the one you moved.')).toBeInTheDocument();
    expect(screen.getByTestId('use-guided-result')).toBeDisabled();
    expect(screen.getAllByRole('radio')[0]).not.toBeChecked();
    await fireEvent.click(screen.getAllByRole('radio')[1]);
    await fireEvent.click(screen.getByTestId('use-guided-result'));
    expect(onUse).toHaveBeenCalledWith(expect.objectContaining({ ambiguous: true }), expect.objectContaining({ endpoint: 'Bell.InputValue' }));
  });

  it('shows detection timeout and allows a fresh Rust session', async () => {
    const startControlDetection = vi.fn()
      .mockResolvedValueOnce({ ok: true, value: { session_id: '8' } })
      .mockResolvedValueOnce({ ok: true, value: { session_id: '9' } });
    const bridge = createFakeBridge({
      startControlDetection,
      controlDetectionStatus: vi.fn()
        .mockResolvedValueOnce({ ok: true, value: session({ state: 'timed_out' }) })
        .mockResolvedValueOnce({ ok: true, value: session({ session_id: '9', state: 'listening', remaining_ms: 12000 }) }),
    });
    render(GuidedSimulatorSession, { props: { bridge, mode: 'detection', onUse: vi.fn(), onClose: vi.fn() } });
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    expect(await screen.findByText('No control changed before the detection timeout.')).toBeInTheDocument();
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    expect(await screen.findByText(/12s remaining/)).toBeInTheDocument();
    expect(bridge.controlDetectionStatus).toHaveBeenLastCalledWith('9');
  });

  it('keeps polling a guided session through one status transport error and shows Rust progress', async () => {
    const bridge = createFakeBridge({
      startLeverAnalysis: vi.fn(async () => ({ ok: true as const, value: { session_id: '14' } })),
      leverAnalysisStatus: vi.fn()
        .mockResolvedValueOnce({ ok: false, error: { code: 'unavailable', message: 'Temporary status failure.', field_errors: {}, retryable: true } })
        .mockResolvedValueOnce({ ok: true, value: session({ session_id: '14', state: 'running', analysis_progress: { sampled: 21, total: 51, current_value: 0.4 } }) })
        .mockResolvedValueOnce({ ok: true, value: session({ session_id: '14', state: 'complete', analysis: { lever_type: 'continuous', suggested_notches: [] } }) }),
    });
    render(GuidedSimulatorSession, { props: { bridge, mode: 'analysis', controlPath: 'Throttle.InputValue', onUse: vi.fn(), onClose: vi.fn() } });
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    expect(await screen.findByText(/Status unavailable: Temporary status failure/)).toBeInTheDocument();
    expect(await screen.findByText(/Analyzing position 21 of 51/, {}, { timeout: 1500 })).toBeInTheDocument();
    expect(await screen.findByText(/Rust detected a continuous lever/, {}, { timeout: 1500 })).toBeInTheDocument();
    expect(bridge.leverAnalysisStatus).toHaveBeenNthCalledWith(3, '14');
  });

  it('waits for cancellation acknowledgement and cancels a late start after unmount', async () => {
    const cancellation = Promise.withResolvers<{ ok: true; value: boolean }>();
    const onClose = vi.fn();
    const cancelControlDetection = vi.fn(() => cancellation.promise);
    const bridge = createFakeBridge({
      startControlDetection: vi.fn(async () => ({ ok: true as const, value: { session_id: '8' } })),
      controlDetectionStatus: vi.fn(() => new Promise(() => {})),
      cancelControlDetection,
    });
    const view = render(GuidedSimulatorSession, { props: { bridge, mode: 'detection', onUse: vi.fn(), onClose } });
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    await waitFor(() => expect(bridge.controlDetectionStatus).toHaveBeenCalledWith('8'));
    await fireEvent.click(screen.getByTestId('close-guided-session'));
    expect(cancelControlDetection).toHaveBeenCalledWith('8');
    expect(onClose).not.toHaveBeenCalled();
    cancellation.resolve({ ok: true, value: true });
    await waitFor(() => expect(onClose).toHaveBeenCalledTimes(1));
    view.unmount();

    const lateStart = Promise.withResolvers<{ ok: true; value: { session_id: string } }>();
    const cancelLate = vi.fn(async () => ({ ok: true as const, value: true }));
    const lateBridge = createFakeBridge({ startControlDetection: vi.fn(() => lateStart.promise), cancelControlDetection: cancelLate });
    const lateView = render(GuidedSimulatorSession, { props: { bridge: lateBridge, mode: 'detection', onUse: vi.fn(), onClose: vi.fn() } });
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    lateView.unmount();
    lateStart.resolve({ ok: true, value: { session_id: '9' } });
    await waitFor(() => expect(cancelLate).toHaveBeenCalledWith('9'));
  });

  it('keeps a late-start session open when cancellation is rejected, then retries close', async () => {
    const start = Promise.withResolvers<{ ok: true; value: { session_id: string } }>();
    const onClose = vi.fn();
    const cancelControlDetection = vi.fn()
      .mockResolvedValueOnce({ ok: false, error: { code: 'unavailable', message: 'Cleanup is busy.', field_errors: {}, retryable: true } })
      .mockResolvedValueOnce({ ok: true, value: true });
    const bridge = createFakeBridge({
      startControlDetection: vi.fn(() => start.promise),
      controlDetectionStatus: vi.fn(() => new Promise(() => {})),
      cancelControlDetection,
    });
    render(GuidedSimulatorSession, { props: { bridge, mode: 'detection', onUse: vi.fn(), onClose } });
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    await fireEvent.click(screen.getByTestId('close-guided-session'));
    start.resolve({ ok: true, value: { session_id: '37' } });
    expect(await screen.findByText('Cleanup is busy.')).toBeInTheDocument();
    expect(onClose).not.toHaveBeenCalled();
    await fireEvent.click(screen.getByTestId('close-guided-session'));
    await waitFor(() => expect(onClose).toHaveBeenCalledTimes(1));
    expect(cancelControlDetection).toHaveBeenCalledTimes(2);
  });

  it('acknowledges cleanup of a failed retained session before trying another start', async () => {
    const startControlDetection = vi.fn()
      .mockResolvedValueOnce({ ok: true, value: { session_id: '8' } })
      .mockResolvedValueOnce({ ok: true, value: { session_id: '9' } });
    const cancelControlDetection = vi.fn()
      .mockResolvedValueOnce({ ok: false, error: { code: 'unavailable', message: 'Unsubscribe still failed.', field_errors: {}, retryable: true } })
      .mockResolvedValueOnce({ ok: true, value: true });
    const bridge = createFakeBridge({
      startControlDetection,
      controlDetectionStatus: vi.fn()
        .mockResolvedValueOnce({ ok: true, value: session({ state: 'failed', cleanup_pending: true, message: 'Detection cleanup failed.' }) })
        .mockResolvedValueOnce({ ok: true, value: session({ session_id: '9', state: 'listening' }) }),
      cancelControlDetection,
    });
    render(GuidedSimulatorSession, { props: { bridge, mode: 'detection', onUse: vi.fn(), onClose: vi.fn() } });
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    expect(await screen.findByText('Detection cleanup failed.')).toBeInTheDocument();
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    expect(await screen.findByText('Unsubscribe still failed.')).toBeInTheDocument();
    expect(startControlDetection).toHaveBeenCalledTimes(1);
    expect(cancelControlDetection).toHaveBeenCalledWith('8');
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    expect(await screen.findByText(/Move the control in the simulator/)).toBeInTheDocument();
    expect(cancelControlDetection).toHaveBeenCalledTimes(2);
    expect(cancelControlDetection).toHaveBeenNthCalledWith(2, '8');
    expect(startControlDetection).toHaveBeenCalledTimes(2);
  });

  it('can retry or close a failed session after backend cleanup is already complete', async () => {
    const onClose = vi.fn();
    const startControlDetection = vi.fn()
      .mockResolvedValueOnce({ ok: true, value: { session_id: '8' } })
      .mockResolvedValueOnce({ ok: true, value: { session_id: '9' } });
    const cancelControlDetection = vi.fn();
    const bridge = createFakeBridge({
      startControlDetection,
      controlDetectionStatus: vi.fn()
        .mockResolvedValueOnce({ ok: true, value: session({ state: 'failed', cleanup_pending: false, message: 'Detection failed.' }) })
        .mockResolvedValueOnce({ ok: true, value: session({ session_id: '9', state: 'failed', cleanup_pending: false, message: 'Detection failed again.' }) }),
      cancelControlDetection,
    });
    render(GuidedSimulatorSession, { props: { bridge, mode: 'detection', onUse: vi.fn(), onClose } });
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    await screen.findByText('Detection failed.');
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    await screen.findByText('Detection failed again.');
    expect(startControlDetection).toHaveBeenCalledTimes(2);
    expect(cancelControlDetection).not.toHaveBeenCalled();
    await fireEvent.click(screen.getByTestId('close-guided-session'));
    expect(onClose).toHaveBeenCalledTimes(1);
    expect(cancelControlDetection).not.toHaveBeenCalled();
  });

  it('fills button endpoint from a detected simulator control', async () => {
    const button: ElementView = { id: '81', name: 'Bell', kind: 'button', lever_config: null };
    const bridge = createFakeBridge({
      startControlDetection: vi.fn(async () => ({ ok: true as const, value: { session_id: '8' } })),
      controlDetectionStatus: vi.fn(async () => ({ ok: true as const, value: session({ state: 'detected', changes: [
        { endpoint: 'Bell.InputValue', control_name: 'Bell', previous_value: 0, current_value: 1 },
      ] }) })),
    });
    render(ButtonBindingWizard, { props: { bridge, element: button, hardware: { inputs: [], outputs: [], displays: [] }, sequences: [], onClose: vi.fn(), onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('choose-simulator-binding'));
    await fireEvent.click(screen.getByTestId('detect-simulator-button'));
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    await fireEvent.click(await screen.findByTestId('use-guided-result'));
    expect(screen.getByTestId('button-endpoint')).toHaveValue('Bell.InputValue');
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    expect(screen.getByTestId('button-step-configure')).toBeInTheDocument();
  });

  it('resolves detected lever paths in Rust, reviews analysis, then saves through one atomic command', async () => {
    const commitLeverMapping = vi.fn(async () => ({ ok: true as const, value: { committed: true as const, lever_config_id: '90', inverted: false, train_detail: snapshot('trains', train), validation: snapshot('trains', { valid: true, gaps: [] }), refresh_required: false } }));
    const bridge = createFakeBridge({
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [], button: [], output: [], display: [] }) })),
      startControlDetection: vi.fn(async () => ({ ok: true as const, value: { session_id: '8' } })),
      controlDetectionStatus: vi.fn(async () => ({ ok: true as const, value: session({ state: 'detected', changes: [
        { endpoint: 'Actor/Throttle.InputValue', control_name: 'Throttle', previous_value: 0, current_value: 1 },
      ] }) })),
      resolveLeverEndpoints: vi.fn(async () => ({ ok: true as const, value: { name: 'Throttle', min_endpoint: 'Min', max_endpoint: 'Max', value_endpoint: 'Value', notch_count_endpoint: 'Count', notch_index_endpoint: 'Index' } })),
      startLeverAnalysis: vi.fn(async () => ({ ok: true as const, value: { session_id: '9' } })),
      leverAnalysisStatus: vi.fn(async () => ({ ok: true as const, value: session({ session_id: '9', state: 'complete', analysis: {
        lever_type: 'discrete', suggested_notches: [{ index: 0, kind: 'gate', value: 0.5, min_value: null, max_value: null,
          input_min: 0.4, input_max: 0.6, actual_input_min: 0.4, actual_input_max: 0.6, description: 'Neutral' }],
      } }) })),
      previewNotchMapping: vi.fn(async () => ({ ok: true as const, value: { inverted: false, ranges: [{ min: 0, max: 1 }], travel: 1023 } })),
      commitLeverMapping,
    });
    render(LeverSetupWizard, { props: { bridge, element: lever, hardware: leverHardware, onClose: vi.fn(), onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('lever-input-option'));
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.click(screen.getByTestId('detect-simulator-lever'));
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    await fireEvent.click(await screen.findByTestId('use-guided-result'));
    await waitFor(() => expect(screen.getByTestId('lever-value-endpoint')).toHaveValue('Value'));
    expect(bridge.resolveLeverEndpoints).toHaveBeenCalledWith('Actor/Throttle.InputValue');
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.click(screen.getByTestId('analyze-lever'));
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    await fireEvent.click(await screen.findByTestId('use-guided-result'));
    expect(screen.getByLabelText('Notch 1 description')).toHaveValue('Neutral');
    expect(commitLeverMapping).not.toHaveBeenCalled();
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await screen.findByTestId('lever-step-mapping');
    await fireEvent.click(screen.getByTestId('auto-distribute'));
    await screen.findByTestId('lever-step-preview');
    await fireEvent.click(screen.getByTestId('save-mapping'));
    await waitFor(() => expect(commitLeverMapping).toHaveBeenCalledWith(expect.objectContaining({
      element_id: '80', lever_config_id: null, input_id: '11', auto_distribute: true,
      calibration_completed: false,
      endpoints: expect.objectContaining({ min_endpoint: 'Min', max_endpoint: 'Max', value_endpoint: 'Value', lever_type: 'discrete' }),
      notches: [expect.objectContaining({ kind: 'gate', value: 0.5, sim_input_min: 0.4, sim_input_max: 0.6 })],
    })));
  });

  it('reviews Rust automatic sweep notches with the chosen five endpoint override', async () => {
    const commitLeverMapping = vi.fn(async () => ({ ok: true as const, value: { committed: true as const, lever_config_id: '90', inverted: false, train_detail: snapshot('trains', train), validation: snapshot('trains', { valid: true, gaps: [] }), refresh_required: false } }));
    const bridge = createFakeBridge({
      startLeverCalibration: vi.fn(async () => ({ ok: true as const, value: { session_id: '11' } })),
      leverCalibrationStatus: vi.fn(async () => ({ ok: true as const, value: session({ session_id: '11', state: 'complete', calibration: { lever_config_id: 0, notches: [
        { index: 0, kind: 'linear', value: null, min_value: 0.1, max_value: 0.9, description: 'Power' },
      ] } }) })),
      getBindings: vi.fn(async () => ({ ok: true as const, value: snapshot('bindings', { lever: [], button: [], output: [], display: [] }) })),
      previewNotchMapping: vi.fn(async () => ({ ok: true as const, value: { inverted: false, ranges: [{ min: 0, max: 1 }], travel: 1023 } })),
      commitLeverMapping,
    });
    render(LeverSetupWizard, { props: { bridge, element: lever, hardware: leverHardware, onClose: vi.fn(), onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('lever-input-option'));
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    for (const [field, value] of [['lever-min-endpoint', 'Min'], ['lever-max-endpoint', 'Max'], ['lever-value-endpoint', 'Value'], ['lever-notch-count-endpoint', 'Count'], ['lever-notch-index-endpoint', 'Index']]) {
      await fireEvent.input(screen.getByTestId(field), { target: { value } });
    }
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.click(screen.getByTestId('sweep-lever'));
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    await fireEvent.click(await screen.findByTestId('use-guided-result'));
    expect(bridge.startLeverCalibration).toHaveBeenCalledWith('Value', {
      min_endpoint: 'Min', max_endpoint: 'Max', value_endpoint: 'Value', notch_count_endpoint: 'Count', notch_index_endpoint: 'Index',
    });
    expect(screen.getByLabelText('Notch 1 description')).toHaveValue('Power');
    expect(screen.getByLabelText('Notch 1 simulator minimum')).toHaveValue(0.1);
    expect(screen.getByLabelText('Notch 1 simulator maximum')).toHaveValue(0.9);
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await screen.findByTestId('lever-step-mapping');
    await fireEvent.click(screen.getByTestId('auto-distribute'));
    await screen.findByTestId('lever-step-preview');
    await fireEvent.click(screen.getByTestId('save-mapping'));
    await waitFor(() => expect(commitLeverMapping).toHaveBeenCalledWith(expect.objectContaining({ calibration_completed: true })));
  });

  it('keeps the wizard open when its outer close cannot cancel an active sweep', async () => {
    const onClose = vi.fn();
    const cancelLeverCalibration = vi.fn()
      .mockResolvedValueOnce({ ok: false, error: { code: 'unavailable', message: 'Cleanup failed.', field_errors: {}, retryable: true } })
      .mockResolvedValueOnce({ ok: true, value: true });
    const bridge = createFakeBridge({
      startLeverCalibration: vi.fn(async () => ({ ok: true as const, value: { session_id: '42' } })),
      leverCalibrationStatus: vi.fn(async () => ({ ok: true as const, value: session({ session_id: '42', state: 'running' }) })),
      cancelLeverCalibration,
    });
    render(LeverSetupWizard, { props: { bridge, element: lever, hardware: leverHardware, onClose, onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('lever-input-option'));
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    for (const [field, value] of [['lever-min-endpoint', 'Min'], ['lever-max-endpoint', 'Max'], ['lever-value-endpoint', 'Value']]) {
      await fireEvent.input(screen.getByTestId(field), { target: { value } });
    }
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.click(screen.getByTestId('sweep-lever'));
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    await screen.findByText('Reading simulator values…');
    await fireEvent.click(screen.getByTestId('wizard-close'));
    await waitFor(() => expect(cancelLeverCalibration).toHaveBeenCalledWith('42'));
    expect(await screen.findByText('Cleanup failed.')).toBeInTheDocument();
    expect(onClose).not.toHaveBeenCalled();
    expect(cancelLeverCalibration).toHaveBeenCalledTimes(1);
    await waitFor(() => expect(screen.getByTestId('wizard-close')).toBeEnabled());
    await fireEvent.click(screen.getByTestId('wizard-backdrop'));
    expect(cancelLeverCalibration).toHaveBeenCalledTimes(2);
    await waitFor(() => expect(onClose).toHaveBeenCalledTimes(1));
    expect(cancelLeverCalibration).toHaveBeenCalledTimes(2);
  });

  it('also fences the button wizard backdrop while simulator detection is active', async () => {
    const onClose = vi.fn();
    const cancelControlDetection = vi.fn()
      .mockResolvedValueOnce({ ok: false, error: { code: 'unavailable', message: 'Subscription cleanup failed.', field_errors: {}, retryable: true } })
      .mockResolvedValueOnce({ ok: true, value: true });
    const bridge = createFakeBridge({
      startControlDetection: vi.fn(async () => ({ ok: true as const, value: { session_id: '52' } })),
      controlDetectionStatus: vi.fn(async () => ({ ok: true as const, value: session({ session_id: '52', state: 'listening' }) })),
      cancelControlDetection,
    });
    const button: ElementView = { id: '81', name: 'Bell', kind: 'button', lever_config: null };
    render(ButtonBindingWizard, { props: { bridge, element: button, hardware: { inputs: [], outputs: [], displays: [] }, sequences: [], onClose, onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('choose-simulator-binding'));
    await fireEvent.click(screen.getByTestId('detect-simulator-button'));
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    await screen.findByText(/Move the control in the simulator/);
    await fireEvent.click(screen.getByTestId('wizard-backdrop'));
    expect(await screen.findByText('Subscription cleanup failed.')).toBeInTheDocument();
    expect(onClose).not.toHaveBeenCalled();
    await waitFor(() => expect(screen.getByTestId('wizard-close')).toBeEnabled());
    await fireEvent.click(screen.getByTestId('wizard-close'));
    await waitFor(() => expect(cancelControlDetection).toHaveBeenCalledTimes(2));
    await waitFor(() => expect(onClose).toHaveBeenCalledTimes(1));
  });

  it('keeps the outer wizard visible when a failed status still owns cleanup', async () => {
    const onClose = vi.fn();
    const cancelControlDetection = vi.fn()
      .mockResolvedValueOnce({ ok: false, error: { code: 'unavailable', message: 'Cleanup retry failed.', field_errors: {}, retryable: true } })
      .mockResolvedValueOnce({ ok: true, value: true });
    const startControlDetection = vi.fn(async () => ({ ok: true as const, value: { session_id: '54' } }));
    const bridge = createFakeBridge({
      startControlDetection,
      controlDetectionStatus: vi.fn(async () => ({ ok: true as const, value: session({ session_id: '54', state: 'failed', cleanup_pending: true, message: 'Unsubscribe failed.' }) })),
      cancelControlDetection,
    });
    const button: ElementView = { id: '81', name: 'Bell', kind: 'button', lever_config: null };
    render(ButtonBindingWizard, { props: { bridge, element: button, hardware: { inputs: [], outputs: [], displays: [] }, sequences: [], onClose, onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('choose-simulator-binding'));
    await fireEvent.click(screen.getByTestId('detect-simulator-button'));
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    expect(await screen.findByText('Unsubscribe failed.')).toBeInTheDocument();
    await fireEvent.click(screen.getByTestId('wizard-close'));
    expect(await screen.findByText('Cleanup retry failed.')).toBeInTheDocument();
    expect(onClose).not.toHaveBeenCalled();
    expect(startControlDetection).toHaveBeenCalledTimes(1);
    await waitFor(() => expect(screen.getByTestId('wizard-close')).toBeEnabled());
    await fireEvent.click(screen.getByTestId('wizard-backdrop'));
    await waitFor(() => expect(onClose).toHaveBeenCalledTimes(1));
    expect(cancelControlDetection).toHaveBeenCalledTimes(2);
  });

  it('waits for a late guided start and its cancel acknowledgement before outer dismissal', async () => {
    const start = Promise.withResolvers<{ ok: true; value: { session_id: string } }>();
    const cancelled = Promise.withResolvers<{ ok: true; value: boolean }>();
    const onClose = vi.fn();
    const cancelControlDetection = vi.fn(() => cancelled.promise);
    const bridge = createFakeBridge({ startControlDetection: vi.fn(() => start.promise), cancelControlDetection });
    const button: ElementView = { id: '81', name: 'Bell', kind: 'button', lever_config: null };
    render(ButtonBindingWizard, { props: { bridge, element: button, hardware: { inputs: [], outputs: [], displays: [] }, sequences: [], onClose, onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('choose-simulator-binding'));
    await fireEvent.click(screen.getByTestId('detect-simulator-button'));
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    await fireEvent.click(screen.getByTestId('wizard-close'));
    expect(onClose).not.toHaveBeenCalled();
    start.resolve({ ok: true, value: { session_id: '53' } });
    await waitFor(() => expect(cancelControlDetection).toHaveBeenCalledWith('53'));
    expect(onClose).not.toHaveBeenCalled();
    cancelled.resolve({ ok: true, value: true });
    await waitFor(() => expect(onClose).toHaveBeenCalledTimes(1));
  });

  it('preserves manually edited endpoints while a detected lever is resolving', async () => {
    const resolution = Promise.withResolvers<{ ok: true; value: { name: string; min_endpoint: string; max_endpoint: string; value_endpoint: string; notch_count_endpoint: string; notch_index_endpoint: string } }>();
    const bridge = createFakeBridge({
      startControlDetection: vi.fn(async () => ({ ok: true as const, value: { session_id: '5' } })),
      controlDetectionStatus: vi.fn(async () => ({ ok: true as const, value: session({ session_id: '5', state: 'detected', changes: [
        { endpoint: 'Actor/Throttle.InputValue', control_name: 'Throttle', previous_value: 0, current_value: 1 },
      ] }) })),
      resolveLeverEndpoints: vi.fn(() => resolution.promise),
    });
    render(LeverSetupWizard, { props: { bridge, element: lever, hardware: leverHardware, onClose: vi.fn(), onComplete: vi.fn() } });
    await fireEvent.click(screen.getByTestId('lever-input-option'));
    await fireEvent.click(screen.getByTestId('wizard-continue'));
    await fireEvent.click(screen.getByTestId('detect-simulator-lever'));
    await fireEvent.click(screen.getByTestId('start-guided-session'));
    await fireEvent.click(await screen.findByTestId('use-guided-result'));
    await fireEvent.input(screen.getByTestId('lever-min-endpoint'), { target: { value: 'Manual.Minimum' } });
    resolution.resolve({ ok: true, value: { name: 'Throttle', min_endpoint: 'Detected.Minimum', max_endpoint: 'Detected.Maximum', value_endpoint: 'Detected.Value', notch_count_endpoint: 'Detected.Count', notch_index_endpoint: 'Detected.Index' } });
    expect(await screen.findByText(/Endpoints changed while detection was resolving/)).toBeInTheDocument();
    expect(screen.getByTestId('lever-min-endpoint')).toHaveValue('Manual.Minimum');
    expect(screen.getByTestId('lever-value-endpoint')).toHaveValue('');
  });
});
