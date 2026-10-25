import { fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { describe, expect, it, vi } from 'vitest';
import App from '../src/app/App.svelte';
import EndpointBrowser from '../src/components/EndpointBrowser.svelte';
import Firmware from '../src/app/pages/firmware/Firmware.svelte';
import { createFakeBridge, snapshot } from './helpers';

const board = { device_id: '7', config_id: 42, name: 'Panel', description: null, input_count: 1, active: false };
const connected = { port: '/dev/ttyUSB0', generation: 0, config_id: null, device_id: null, status: 'connected' as const };

describe('live hardware workflow', () => {
  it('shows the real simulator status and retries without claiming connection early', async () => {
    let connectedNow = false;
    const retrySimulator = vi.fn(async () => { connectedNow = true; return { ok: true as const, value: true }; });
    const bridge = createFakeBridge({
      getSimulatorStatus: vi.fn(async () => ({ ok: true as const, value: connectedNow
        ? { status: 'connected', last_error: null, active_train_id: '10', detected_identifier: 'ICE' }
        : { status: 'needs_config', last_error: null, active_train_id: null, detected_identifier: null } })),
      retrySimulator,
    });
    location.hash = '#/';
    render(App, { props: { bridge } });
    await waitFor(() => expect(screen.getByTestId('simulator-status')).toHaveTextContent('Configure simulator in Settings.'));
    await fireEvent.click(screen.getByTestId('retry-simulator'));
    await waitFor(() => expect(retrySimulator).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(screen.getByTestId('simulator-status')).toHaveTextContent('Simulator connected · ICE'));
    expect(screen.queryByTestId('retry-simulator')).not.toBeInTheDocument();
  });

  it('scans, applies a configuration to generation zero, and waits for terminal status', async () => {
    const scanDevices = vi.fn(async () => ({ ok: true as const, value: true }));
    const beginApplyConfiguration = vi.fn(async () => ({ ok: true as const, value: { operation_id: '9', config_id: 42 } }));
    const configurationStatus = vi.fn(async () => ({ ok: true as const, value: { state: 'complete' as const, message: null } }));
    const bridge = createFakeBridge({
      getConfigurations: vi.fn(async () => ({ ok: true as const, value: snapshot('hardware', [board]) })),
      serialPorts: vi.fn(async () => ({ ok: true as const, value: [connected] })),
      scanDevices,
      beginApplyConfiguration,
      configurationStatus,
    });
    location.hash = '#/';
    render(App, { props: { bridge } });
    await screen.findByText('Panel');
    await screen.findByTestId('serial-port');
    await fireEvent.click(screen.getByTestId('scan-devices'));
    await waitFor(() => expect(scanDevices).toHaveBeenCalledTimes(1));
    await fireEvent.change(screen.getByTestId('apply-port'), { target: { value: '/dev/ttyUSB0' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Apply' }));
    await waitFor(() => expect(beginApplyConfiguration).toHaveBeenCalledWith('7', '/dev/ttyUSB0', 0));
    expect(screen.getByText('Applying configuration…')).toBeInTheDocument();
    expect(screen.queryByText('Configuration applied.')).not.toBeInTheDocument();
    await waitFor(() => expect(configurationStatus).toHaveBeenCalledWith('9'), { timeout: 1800 });
    expect(await screen.findByText('Configuration applied.')).toBeInTheDocument();
  });

  it('keeps polling the same apply operation after a transient status-read error', async () => {
    const configurationStatus = vi.fn()
      .mockResolvedValueOnce({ ok: false, error: { code: 'unavailable', message: 'Snapshot read failed.', field_errors: {}, retryable: true } })
      .mockResolvedValueOnce({ ok: true, value: { state: 'complete', message: null } });
    const bridge = createFakeBridge({
      getConfigurations: vi.fn(async () => ({ ok: true as const, value: snapshot('hardware', [board]) })),
      serialPorts: vi.fn(async () => ({ ok: true as const, value: [connected] })),
      beginApplyConfiguration: vi.fn(async () => ({ ok: true as const, value: { operation_id: '12', config_id: 42 } })),
      configurationStatus,
    });
    location.hash = '#/';
    render(App, { props: { bridge } });
    await screen.findByTestId('serial-port');
    await fireEvent.change(screen.getByTestId('apply-port'), { target: { value: '/dev/ttyUSB0' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Apply' }));
    expect(await screen.findByText(/Status unavailable: Snapshot read failed/ , {}, { timeout: 1800 })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Apply' })).toBeDisabled();
    expect(await screen.findByText('Configuration applied.', {}, { timeout: 1800 })).toBeInTheDocument();
    expect(configurationStatus).toHaveBeenNthCalledWith(2, '12');
  });

  it('shows failed apply status and disconnects using the inventoried generation', async () => {
    const disconnectDevice = vi.fn(async () => ({ ok: true as const, value: true }));
    const bridge = createFakeBridge({
      getConfigurations: vi.fn(async () => ({ ok: true as const, value: snapshot('hardware', [board]) })),
      serialPorts: vi.fn(async () => ({ ok: true as const, value: [connected] })),
      beginApplyConfiguration: vi.fn(async () => ({ ok: true as const, value: { operation_id: '10', config_id: 42 } })),
      configurationStatus: vi.fn(async () => ({ ok: true as const, value: { state: 'failed' as const, message: 'Board rejected configuration.' } })),
      disconnectDevice,
    });
    location.hash = '#/';
    render(App, { props: { bridge } });
    await screen.findByText('Panel');
    await screen.findByTestId('serial-port');
    await fireEvent.change(screen.getByTestId('apply-port'), { target: { value: '/dev/ttyUSB0' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Apply' }));
    expect(await screen.findByText('Board rejected configuration.', {}, { timeout: 1800 })).toBeInTheDocument();
    expect(screen.queryByText('Configuration applied.')).not.toBeInTheDocument();
    await fireEvent.click(screen.getByRole('button', { name: 'Disconnect' }));
    await waitFor(() => expect(disconnectDevice).toHaveBeenCalledWith('/dev/ttyUSB0', 0));
  });

  it('revokes active device UI as soon as the authoritative inventory loses its port', async () => {
    let ports = [{ ...connected, config_id: 42 }];
    const bridge = createFakeBridge({
      getConfigurations: vi.fn(async () => ({ ok: true as const, value: snapshot('hardware', [board]) })),
      serialPorts: vi.fn(async () => ({ ok: true as const, value: ports })),
      scanDevices: vi.fn(async () => { ports = []; return { ok: true as const, value: true }; }),
    });
    location.hash = '#/';
    render(App, { props: { bridge } });
    expect(await screen.findByText('1 device active')).toBeInTheDocument();
    await fireEvent.click(screen.getByTestId('scan-devices'));
    expect(await screen.findByText('No device connected')).toBeInTheDocument();
    expect(screen.getByText('No serial ports found. Connect a device, then scan again.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Apply' })).toBeDisabled();
  });

  it('requires port reselection when the same path gets a new generation', async () => {
    let generation = 4;
    const beginApplyConfiguration = vi.fn();
    const bridge = createFakeBridge({
      getConfigurations: vi.fn(async () => ({ ok: true as const, value: snapshot('hardware', [board]) })),
      serialPorts: vi.fn(async () => ({ ok: true as const, value: [{ ...connected, generation }] })),
      scanDevices: vi.fn(async () => { generation = 5; return { ok: true as const, value: true }; }),
      beginApplyConfiguration,
    });
    location.hash = '#/';
    render(App, { props: { bridge } });
    await screen.findByTestId('serial-port');
    await fireEvent.change(screen.getByTestId('apply-port'), { target: { value: '/dev/ttyUSB0' } });
    expect(screen.getByRole('button', { name: 'Apply' })).toBeEnabled();
    await fireEvent.click(screen.getByTestId('scan-devices'));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Apply' })).toBeDisabled());
    expect(beginApplyConfiguration).not.toHaveBeenCalled();
  });
});

describe('simulator endpoint browser', () => {
  it('uses the persistent simulator bridge for navigation, value preview and selection', async () => {
    const onSelect = vi.fn();
    const listSimulatorEndpoints = vi.fn(async (path: string | null) => ({ ok: true as const, value: path === null
      ? [{ name: 'CurrentDrivableActor', path: 'CurrentDrivableActor', kind: 'node' as const, writable: false }]
      : [{ name: 'InputValue', path: 'CurrentDrivableActor.InputValue', kind: 'endpoint' as const, writable: true }] }));
    const getSimulatorValue = vi.fn(async () => ({ ok: true as const, value: { Value: 0.5 } }));
    const bridge = createFakeBridge({ listSimulatorEndpoints, getSimulatorValue });
    render(EndpointBrowser, { props: { bridge, onSelect } });
    await fireEvent.click(screen.getByTestId('browse-simulator'));
    await fireEvent.click(await screen.findByRole('button', { name: /CurrentDrivableActor Open/ }));
    await fireEvent.click(await screen.findByRole('button', { name: /InputValue Value/ }));
    expect(await screen.findByTestId('simulator-value')).toHaveTextContent('0.5');
    await fireEvent.click(screen.getByTestId('use-simulator-endpoint'));
    expect(onSelect).toHaveBeenCalledWith('CurrentDrivableActor.InputValue');
    expect(listSimulatorEndpoints).toHaveBeenCalledWith('CurrentDrivableActor');
    expect(getSimulatorValue).toHaveBeenCalledWith('CurrentDrivableActor.InputValue');
  });

  it('discards stale replies after close and reports a simulator read failure', async () => {
    let resolveOld!: (value: { ok: true; value: [] }) => void;
    const old = new Promise<{ ok: true; value: [] }>((resolve) => (resolveOld = resolve));
    const onSelect = vi.fn();
    const bridge = createFakeBridge({
      listSimulatorEndpoints: vi.fn().mockReturnValueOnce(old).mockResolvedValue({ ok: true, value: [{ name: 'Speed', path: 'Speed', kind: 'endpoint', writable: false }] }),
      getSimulatorValue: vi.fn(async () => ({ ok: false as const, error: { code: 'unavailable' as const, message: 'Simulator read failed.', field_errors: {}, retryable: true } })),
    });
    render(EndpointBrowser, { props: { bridge, onSelect } });
    await fireEvent.click(screen.getByTestId('browse-simulator'));
    await fireEvent.click(screen.getByTestId('browse-simulator'));
    await fireEvent.click(screen.getByTestId('browse-simulator'));
    await fireEvent.click(await screen.findByRole('button', { name: /Speed Value/ }));
    resolveOld({ ok: true, value: [] });
    expect(await screen.findByText('Simulator read failed.')).toBeInTheDocument();
    expect(screen.getByTestId('use-simulator-endpoint')).toBeDisabled();
    expect(onSelect).not.toHaveBeenCalled();
  });
});

describe('firmware port ownership', () => {
  const firmware = {
    releases: [{ id: '30', version: '1.2', tag_name: 'v1.2', release_url: null, release_notes: null, published_at: null,
      files: [{ id: '40', release_id: '30', board_type: 'controller', environment: 'mega', download_url: 'https://example.test/file.hex', file_size: 100, checksum_sha256: null }] }],
    update_checks: [], upload_history: [],
  };
  it('requires an explicit choice among multiple ports and rejects a changed generation after download', async () => {
    let finishDownload!: (value: { ok: true; value: ReturnType<typeof snapshot<typeof firmware>> }) => void;
    const downloadFirmware = vi.fn(() => new Promise<{ ok: true; value: ReturnType<typeof snapshot<typeof firmware>> }>((resolve) => (finishDownload = resolve)));
    const startFirmwareUpload = vi.fn(async () => ({ ok: true as const, value: 'upload-1' }));
    const bridge = createFakeBridge({
      getFirmware: vi.fn(async () => ({ ok: true as const, value: snapshot('firmware', firmware) })),
      downloadFirmware,
      serialPorts: vi.fn(async () => ({ ok: true as const, value: [{ ...connected, generation: 8 }] })),
      startFirmwareUpload,
    });
    render(Firmware, { props: { bridge, ports: [{ ...connected, generation: 7 }, { ...connected, port: '/dev/ttyUSB1', generation: 3 }] } });
    await fireEvent.click(await screen.findByTestId('upload-to-device'));
    await fireEvent.change(screen.getByTestId('upload-environment'), { target: { value: 'mega' } });
    expect(screen.getByTestId('start-upload')).toBeDisabled();
    await fireEvent.change(screen.getByTestId('upload-port'), { target: { value: '/dev/ttyUSB0' } });
    await fireEvent.click(screen.getByTestId('start-upload'));
    await waitFor(() => expect(downloadFirmware).toHaveBeenCalled());
    finishDownload({ ok: true, value: snapshot('firmware', firmware) });
    expect(await screen.findByText(/serial port changed during download/i)).toBeInTheDocument();
    expect(startFirmwareUpload).not.toHaveBeenCalled();
  });
});
