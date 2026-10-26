import { fireEvent, render, screen, waitFor, within } from '@testing-library/svelte';
import { describe, expect, it, vi } from 'vitest';
import App from '../src/app/App.svelte';
import type { UiBridge } from '../src/bridge/client';

function fakeBridge(consent: 'unset' | 'disabled' = 'disabled'): UiBridge {
  const unavailable = { code: 'unavailable' as const, message: 'The Rust desktop service is not integrated.', field_errors: {}, retryable: true };
  return {
    getSettings: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'settings' as const, revision: '1', value: { error_reporting: consent, simulator: { url: 'http://localhost:31270', api_key_configured: false } } } })),
    getConfigurations: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '1', value: [] } })),
    getTrains: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'trains' as const, revision: '1', value: [] } })),
    setConsent: vi.fn(async () => ({ ok: false as const, error: unavailable })),
    serialPorts: vi.fn(async () => ({ ok: true as const, value: [] })),
    getSimulatorStatus: vi.fn(async () => ({ ok: true as const, value: { status: 'disconnected', last_error: null, active_train_id: null, detected_identifier: null } })),
    retrySimulator: vi.fn(async () => ({ ok: true as const, value: true })),
    firmwareUpdateStatus: vi.fn(async () => ({ ok: true as const, value: { checking: false, checked_at_ms: null, found_updates: false, latest_version: null, error_message: null, notice: null } })),
    onHardwareInput: vi.fn(() => () => {}),
    onHardwareDetection: vi.fn(() => () => {}),
    subscribe: vi.fn(async () => () => {}),
  } as unknown as UiBridge;
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

describe('shell', () => {
  it('renders the Rust-backed configuration empty state from the injected test bridge', async () => {
    location.hash = '#/';
    render(App, { props: { bridge: fakeBridge() } });
    expect(await screen.findByText('No Configurations')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /New Configuration/ })).toHaveAttribute('href', '#/configurations/new');
  });

  it('marks the active train from live simulator status rather than stored summary flags', async () => {
    const api = fakeBridge();
    let statusReadFails = false;
    api.getTrains = vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'trains' as const, revision: '1', value: [
      { id: '10', name: 'First train', description: null, identifiers: ['FIRST'], element_count: 0, active: true },
      { id: '20', name: 'Second train', description: null, identifiers: ['SECOND'], element_count: 0, active: false },
    ] } }));
    api.getSimulatorStatus = vi.fn(async () => statusReadFails
      ? { ok: false as const, error: { code: 'unavailable' as const, message: 'Simulator status temporarily unavailable.', field_errors: {}, retryable: true } }
      : { ok: true as const, value: { status: 'connected', last_error: null, active_train_id: '20', detected_identifier: 'UNKNOWN/Vehicle' } });
    location.hash = '#/trains';
    render(App, { props: { bridge: api } });
    const first = (await screen.findByRole('link', { name: /First train/ })).closest('.list-card') as HTMLElement;
    const second = (await screen.findByRole('link', { name: /Second train/ })).closest('.list-card') as HTMLElement;
    await waitFor(() => expect(second).toHaveClass('active-card'));
    expect(first).not.toHaveClass('active-card');
    expect(within(second).getByText('Active')).toBeInTheDocument();
    expect(within(first).queryByText('Active')).not.toBeInTheDocument();
    expect(screen.getByText('UNKNOWN/Vehicle')).toBeInTheDocument();
    statusReadFails = true;
    window.dispatchEvent(new Event('hashchange'));
    expect(await screen.findByText('Simulator status temporarily unavailable.')).toBeInTheDocument();
    expect(second).toHaveClass('active-card');
    expect(screen.getByText('UNKNOWN/Vehicle')).toBeInTheDocument();
  });

  it('keeps unavailable consent changes visible as service errors', async () => {
    location.hash = '#/consent';
    render(App, { props: { bridge: fakeBridge() } });
    await fireEvent.click(await screen.findByRole('button', { name: 'No thanks' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('The Rust desktop service is not integrated.');
  });

  it('routes first-run users to consent when Rust reports an unset choice', async () => {
    location.hash = '#/';
    render(App, { props: { bridge: fakeBridge('unset') } });
    expect(await screen.findByRole('heading', { name: 'Help improve Trenino' })).toBeInTheDocument();
    await waitFor(() => expect(location.hash).toBe('#/consent'));
  });

  it('shows the editable settings form seeded from the settings snapshot', async () => {
    location.hash = '#/settings';
    render(App, { props: { bridge: fakeBridge() } });
    expect(await screen.findByLabelText('URL')).toHaveValue('http://localhost:31270');
    expect(screen.getByRole('button', { name: 'Save and test connection' })).toBeInTheDocument();
    expect(screen.getByTestId('error-reporting-toggle')).toBeInTheDocument();
  });

  it('shows the API key as configured immediately after the Rust save acknowledgement', async () => {
    const api = fakeBridge();
    api.setApiKey = vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'settings' as const, revision: '2', value: {
      error_reporting: 'disabled' as const, simulator: { url: 'http://localhost:31270', api_key_configured: true },
    } } }));
    api.setSimulatorUrl = vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'settings' as const, revision: '3', value: {
      error_reporting: 'disabled' as const, simulator: { url: 'http://localhost:31270', api_key_configured: true },
    } } }));
    api.testSimulator = vi.fn(async () => ({ ok: true as const, value: true }));
    location.hash = '#/settings';
    render(App, { props: { bridge: api } });
    await fireEvent.input(await screen.findByLabelText('API Key'), { target: { value: 'temporary-secret' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Save and test connection' }));
    expect(await screen.findByText('A key is saved. Enter a new key below to replace it.')).toBeInTheDocument();
    expect(screen.getByLabelText('API Key')).toHaveValue('');
  });

  it('renders the configuration editor for #/configurations/:config_id', async () => {
    const api = fakeBridge();
    api.getHardwareDetailByConfig = vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '2', value: { id: '7', name: 'Mega Panel', description: null, config_id: 4242, inputs: [], outputs: [], matrices: [], i2c_modules: [] } } }));
    location.hash = '#/configurations/4242';
    render(App, { props: { bridge: api } });
    expect(await screen.findByDisplayValue('Mega Panel')).toBeInTheDocument();
    expect(api.getHardwareDetailByConfig).toHaveBeenCalledWith('4242');
    expect(screen.getByText('No inputs configured. Add your first input to get started.')).toBeInTheDocument();
  });

  it('opens new-configuration mode without a detail request', async () => {
    const api = fakeBridge();
    api.getHardwareDetailByConfig = vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'hardware' as const, revision: '1', value: { id: '7', name: 'New Configuration', description: null, config_id: 99, inputs: [], outputs: [], matrices: [], i2c_modules: [] } } }));
    location.hash = '#/configurations/new';
    render(App, { props: { bridge: api } });
    expect(await screen.findByLabelText('Configuration Name')).toHaveValue('New Configuration');
    expect(api.getHardwareDetailByConfig).not.toHaveBeenCalled();
  });

  it('shows the connected-device indicator from the hardware stream', async () => {
    location.hash = '#/';
    render(App, { props: { bridge: fakeBridge() } });
    expect(await screen.findByText('No device connected')).toBeInTheDocument();
  });

  it('keeps normal routes behind a delayed or failed consent bootstrap', async () => {
    const api = fakeBridge();
    const settingsRequest = deferred<Awaited<ReturnType<UiBridge['getSettings']>>>();
    api.getSettings = vi.fn().mockReturnValueOnce(settingsRequest.promise).mockResolvedValue({ ok: true, value: { epoch: '1', topic: 'settings', revision: '2', value: { error_reporting: 'disabled', simulator: { url: 'http://localhost:31270', api_key_configured: false } } } });
    location.hash = '#/';
    render(App, { props: { bridge: api } });
    expect(screen.getByText('Checking consent preference')).toBeInTheDocument();
    expect(screen.queryByText('No Configurations')).not.toBeInTheDocument();
    settingsRequest.resolve({ ok: false, error: { code: 'unavailable', message: 'Consent status could not be loaded.', field_errors: {}, retryable: true } });
    expect(await screen.findByRole('alert')).toHaveTextContent('Consent status could not be loaded.');
    expect(screen.getByRole('link', { name: 'Open consent choices' })).toHaveAttribute('href', '#/consent');
    expect(screen.queryByText('No Configurations')).not.toBeInTheDocument();
    await fireEvent.click(screen.getByRole('button', { name: 'Retry consent check' }));
    expect(await screen.findByText('No Configurations')).toBeInTheDocument();
  });

  it('does not let an old list failure replace the current train screen', async () => {
    const api = fakeBridge();
    const slowConfigurations = deferred<Awaited<ReturnType<UiBridge['getConfigurations']>>>();
    api.getConfigurations = vi.fn(() => slowConfigurations.promise);
    location.hash = '#/';
    render(App, { props: { bridge: api } });
    await waitFor(() => expect(api.getConfigurations).toHaveBeenCalledTimes(1));
    location.hash = '#/trains';
    expect(await screen.findByText('No Train Configurations')).toBeInTheDocument();
    slowConfigurations.resolve({ ok: false, error: { code: 'unavailable', message: 'Old configuration request failed.', field_errors: {}, retryable: true } });
    await flushPromises();
    expect(screen.getByText('No Train Configurations')).toBeInTheDocument();
    expect(screen.queryByText('Old configuration request failed.')).not.toBeInTheDocument();
  });

  it('keeps a revisited route from being overwritten by its older request', async () => {
    const api = fakeBridge();
    const oldRequest = deferred<Awaited<ReturnType<UiBridge['getConfigurations']>>>();
    const freshValue = { epoch: '1', topic: 'hardware' as const, revision: '2', value: [{ config_id: 4, name: 'Fresh panel', description: null, input_count: 3, active: false }] };
    api.getConfigurations = vi.fn().mockReturnValueOnce(oldRequest.promise).mockResolvedValueOnce({ ok: true, value: freshValue });
    location.hash = '#/';
    render(App, { props: { bridge: api } });
    await waitFor(() => expect(api.getConfigurations).toHaveBeenCalledTimes(1));
    location.hash = '#/trains';
    expect(await screen.findByText('No Train Configurations')).toBeInTheDocument();
    location.hash = '#/';
    expect(await screen.findByText('Fresh panel')).toBeInTheDocument();
    oldRequest.resolve({ ok: false, error: { code: 'unavailable', message: 'Old visit failed.', field_errors: {}, retryable: true } });
    await flushPromises();
    expect(screen.getByText('Fresh panel')).toBeInTheDocument();
    expect(screen.queryByText('Old visit failed.')).not.toBeInTheDocument();
  });

  it('ignores pending route completions after the shell unmounts', async () => {
    const api = fakeBridge();
    const pending = deferred<Awaited<ReturnType<UiBridge['getConfigurations']>>>();
    api.getConfigurations = vi.fn(() => pending.promise);
    location.hash = '#/';
    const rendered = render(App, { props: { bridge: api } });
    await waitFor(() => expect(api.getConfigurations).toHaveBeenCalledTimes(1));
    rendered.unmount();
    pending.resolve({ ok: true, value: { epoch: '1', topic: 'hardware', revision: '2', value: [] } });
    await flushPromises();
    expect(rendered.container).toBeEmptyDOMElement();
  });

  it('ignores late consent completion after navigation', async () => {
    const api = fakeBridge();
    const consentRequest = deferred<Awaited<ReturnType<UiBridge['setConsent']>>>();
    api.setConsent = vi.fn(() => consentRequest.promise);
    location.hash = '#/consent';
    render(App, { props: { bridge: api } });
    await fireEvent.click(await screen.findByRole('button', { name: 'No thanks' }));
    location.hash = '#/trains';
    expect(await screen.findByText('No Train Configurations')).toBeInTheDocument();
    consentRequest.resolve({ ok: true, value: { epoch: '1', topic: 'settings', revision: '2', value: { error_reporting: 'disabled', simulator: { url: 'http://localhost:31270', api_key_configured: false } } } });
    await flushPromises();
    expect(location.hash).toBe('#/trains');
    expect(screen.getByText('No Train Configurations')).toBeInTheDocument();
  });
});

async function flushPromises() {
  for (let index = 0; index < 12; index += 1) await Promise.resolve();
}
