import { fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { describe, expect, it, vi } from 'vitest';
import App from '../src/app/App.svelte';
import Firmware from '../src/app/pages/firmware/Firmware.svelte';
import { createFakeBridge, flushPromises, serviceUnavailable, snapshot } from './helpers';
import { createBridge, type FirmwareUpdateStatus, type UiBridge } from '../src/bridge/client';

function status(notice: FirmwareUpdateStatus['notice'] = null, patch: Partial<FirmwareUpdateStatus> = {}): FirmwareUpdateStatus {
  return { checking: false, checked_at_ms: 1000, found_updates: notice !== null, latest_version: notice?.version ?? null, error_message: null, notice, ...patch };
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((yes) => { resolve = yes; });
  return { promise, resolve };
}

describe('firmware update notice', () => {
  it('shows the Rust notice for connected configured and unconfigured boards, then dismisses only on ACK', async () => {
    const initial = status({ version: '2.0.0', outdated_devices: ['panel-1'], outdated_ports: ['/dev/ttyUSB0'] });
    let current = initial;
    const bridge = createFakeBridge({
      firmwareUpdateStatus: vi.fn(async () => ({ ok: true as const, value: current })),
      dismissFirmwareUpdate: vi.fn(async () => { current = status(); return { ok: true as const, value: current }; }),
    });
    location.hash = '#/';
    const view = render(App, { props: { bridge } });
    const notice = await screen.findByRole('alert', { name: 'Firmware update available' });
    expect(notice).toHaveTextContent('v2.0.0');
    expect(notice).toHaveTextContent('panel-1');
    expect(notice).toHaveTextContent('/dev/ttyUSB0');
    expect(screen.getByRole('link', { name: 'View update' })).toHaveAttribute('href', '#/firmware');
    await fireEvent.click(screen.getByRole('button', { name: 'Dismiss firmware update' }));
    await waitFor(() => expect(screen.queryByRole('alert', { name: 'Firmware update available' })).not.toBeInTheDocument());
    expect(bridge.dismissFirmwareUpdate).toHaveBeenCalledOnce();
    view.unmount();
    render(App, { props: { bridge } });
    await waitFor(() => expect(bridge.firmwareUpdateStatus).toHaveBeenCalledTimes(2));
    expect(screen.queryByRole('alert', { name: 'Firmware update available' })).not.toBeInTheDocument();
    current = status({ version: '2.0.0', outdated_devices: ['panel-1', 'panel-2'], outdated_ports: ['/dev/ttyUSB0'] });
    window.dispatchEvent(new Event('hashchange'));
    await waitFor(() => expect(screen.getByRole('alert', { name: 'Firmware update available' })).toHaveTextContent('panel-2'));
  });

  it('keeps the notice and shows an error if persistent dismissal fails', async () => {
    const bridge = createFakeBridge({
      firmwareUpdateStatus: vi.fn(async () => ({ ok: true as const, value: status({ version: '2.0.0', outdated_devices: [], outdated_ports: ['/dev/ttyUSB0'] }) })),
      dismissFirmwareUpdate: vi.fn(async () => ({ ok: false as const, error: { ...serviceUnavailable, message: 'Could not save dismissal.' } })),
    });
    location.hash = '#/';
    render(App, { props: { bridge } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Dismiss firmware update' }));
    expect(await screen.findByText('Could not save dismissal.')).toBeInTheDocument();
    expect(screen.getByRole('alert', { name: 'Firmware update available' })).toBeInTheDocument();
  });

  it('reconciles an expired notice and a new device or version on fresh backend status', async () => {
    let current = status({ version: '2.0.0', outdated_devices: ['panel-1'], outdated_ports: [] });
    const bridge = createFakeBridge({ firmwareUpdateStatus: vi.fn(async () => ({ ok: true as const, value: current })) });
    location.hash = '#/';
    render(App, { props: { bridge } });
    expect(await screen.findByRole('alert', { name: 'Firmware update available' })).toHaveTextContent('panel-1');
    current = status();
    window.dispatchEvent(new Event('hashchange'));
    await waitFor(() => expect(screen.queryByRole('alert', { name: 'Firmware update available' })).not.toBeInTheDocument());
    current = status({ version: '2.1.0', outdated_devices: ['panel-2'], outdated_ports: ['/dev/ttyUSB1'] });
    window.dispatchEvent(new Event('hashchange'));
    await waitFor(() => expect(screen.getByRole('alert', { name: 'Firmware update available' })).toHaveTextContent('panel-2'));
    expect(screen.getByRole('alert', { name: 'Firmware update available' })).toHaveTextContent('v2.1.0');
  });

  it('keeps the newer status when an older poll resolves late, and ignores completions after unmount', async () => {
    const old = deferred<Awaited<ReturnType<UiBridge['firmwareUpdateStatus']>>>();
    const late = deferred<Awaited<ReturnType<UiBridge['firmwareUpdateStatus']>>>();
    const bridge = createFakeBridge({
      firmwareUpdateStatus: vi.fn()
        .mockReturnValueOnce(old.promise)
        .mockResolvedValueOnce({ ok: true, value: status({ version: '3.0.0', outdated_devices: [], outdated_ports: ['/dev/new'] }) })
        .mockReturnValueOnce(late.promise),
    });
    location.hash = '#/';
    const view = render(App, { props: { bridge } });
    await waitFor(() => expect(bridge.firmwareUpdateStatus).toHaveBeenCalledOnce());
    window.dispatchEvent(new Event('hashchange'));
    expect(await screen.findByRole('alert', { name: 'Firmware update available' })).toHaveTextContent('/dev/new');
    old.resolve({ ok: true, value: status() });
    await flushPromises();
    expect(screen.getByRole('alert', { name: 'Firmware update available' })).toHaveTextContent('/dev/new');
    window.dispatchEvent(new Event('hashchange'));
    await waitFor(() => expect(bridge.firmwareUpdateStatus).toHaveBeenCalledTimes(3));
    view.unmount();
    late.resolve({ ok: true, value: status({ version: '4.0.0', outdated_devices: [], outdated_ports: ['/dev/later'] }) });
    await flushPromises();
    expect(view.container).toBeEmptyDOMElement();
  });

  it('shows backend checking and surfaces a failed manual check without success feedback', async () => {
    let current = status(null, { checking: true });
    const bridge = createFakeBridge({
      firmwareUpdateStatus: vi.fn(async () => ({ ok: true as const, value: current })),
      checkFirmwareUpdates: vi.fn(async () => ({ ok: false as const, error: { ...serviceUnavailable, message: 'Check is rate limited.' } })),
    });
    location.hash = '#/';
    render(App, { props: { bridge } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Connected devices' }));
    const check = await screen.findByRole('menuitem', { name: 'Check for firmware updates' });
    expect(check).toBeDisabled();
    current = status();
    window.dispatchEvent(new Event('hashchange'));
    await waitFor(() => expect(bridge.firmwareUpdateStatus).toHaveBeenCalledTimes(2));
    await fireEvent.click(await screen.findByRole('button', { name: 'Connected devices' }));
    await waitFor(() => expect(screen.getByRole('menuitem', { name: 'Check for firmware updates' })).toBeEnabled());
    await fireEvent.click(screen.getByRole('menuitem', { name: 'Check for firmware updates' }));
    expect(await screen.findByText('Check is rate limited.')).toBeInTheDocument();
    expect(screen.queryByText(/firmware releases updated/i)).not.toBeInTheDocument();
  });

  it('allows a manual retry after a recent failed automatic check and clears the backend error', async () => {
    let current = status(null, { checked_at_ms: Date.now(), error_message: 'Automatic check failed.' });
    const bridge = createFakeBridge({
      firmwareUpdateStatus: vi.fn(async () => ({ ok: true as const, value: current })),
      checkFirmwareUpdates: vi.fn(async () => {
        current = status(null, { checked_at_ms: Date.now() + 1, error_message: null });
        return { ok: true as const, value: snapshot('firmware', { releases: [], update_checks: [], upload_history: [] }) };
      }),
    });
    location.hash = '#/';
    render(App, { props: { bridge } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Connected devices' }));
    expect(await screen.findByText('Last firmware check failed: Automatic check failed.')).toBeInTheDocument();
    await fireEvent.click(screen.getByRole('menuitem', { name: 'Check for firmware updates' }));
    await waitFor(() => expect(screen.queryByText('Last firmware check failed: Automatic check failed.')).not.toBeInTheDocument());
    expect(bridge.checkFirmwareUpdates).toHaveBeenCalledOnce();
  });

  it('refreshes the open catalog after an automatic check and acknowledges a completed manual check', async () => {
    const before = { releases: [], update_checks: [], upload_history: [] };
    const after = { releases: [{ id: '30', version: '2.1.0', tag_name: 'v2.1.0', release_url: null, release_notes: null, published_at: null, files: [] }], update_checks: [], upload_history: [] };
    const bridge = createFakeBridge({
      getFirmware: vi.fn()
        .mockResolvedValueOnce({ ok: true, value: snapshot('firmware', before) })
        .mockResolvedValue({ ok: true, value: snapshot('firmware', after) }),
      checkFirmwareUpdates: vi.fn(async () => ({ ok: true as const, value: snapshot('firmware', after) })),
    });
    const initial = status(null, { checking: true, checked_at_ms: 1000 });
    const view = render(Firmware, { props: { bridge, updateStatus: initial } });
    expect(await screen.findByRole('button', { name: 'Checking...' })).toBeDisabled();
    await view.rerender({ bridge, updateStatus: status(null, { checked_at_ms: 2000 }) });
    expect(await screen.findByRole('heading', { name: 'v2.1.0' })).toBeInTheDocument();
    await fireEvent.click(screen.getByTestId('check-updates'));
    expect(await screen.findByText('Firmware list refreshed')).toBeInTheDocument();
    expect(screen.queryByText('Firmware releases updated')).not.toBeInTheDocument();
    await view.rerender({ bridge, updateStatus: status(null, { checked_at_ms: 2000, error_message: 'Firmware service could not be reached.' }) });
    expect(screen.getByText('Last firmware check failed: Firmware service could not be reached.')).toBeInTheDocument();
  });

  it('sends the exact status and dismiss commands without fabricated arguments', async () => {
    const invoke = vi.fn(async () => status());
    const bridge = createBridge({ isDesktop: () => true, invoke, listen: vi.fn(async () => () => {}) });
    await bridge.firmwareUpdateStatus();
    await bridge.dismissFirmwareUpdate();
    expect(invoke).toHaveBeenNthCalledWith(1, 'ui_firmware_update_status', undefined);
    expect(invoke).toHaveBeenNthCalledWith(2, 'ui_dismiss_firmware_update', undefined);
  });
});
