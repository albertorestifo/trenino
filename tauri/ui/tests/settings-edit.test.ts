import { fireEvent, render, screen, waitFor } from '@testing-library/svelte';
import { describe, expect, it, vi } from 'vitest';
import SettingsEdit from '../src/app/pages/settings/SettingsEdit.svelte';
import type { UiBridge } from '../src/bridge/client';
import type { SettingsView } from '../src/bridge/generated';

function settingsView(overrides: Partial<SettingsView> = {}): SettingsView {
  return { error_reporting: 'disabled', simulator: { url: 'http://localhost:31270', api_key_configured: false }, ...overrides };
}

type Overrides = { [K in keyof UiBridge]?: UiBridge[K] };

function settingsBridge(overrides: Overrides = {}): UiBridge {
  const bridge = {
    setSimulatorUrl: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'settings' as const, revision: '2', value: settingsView() } })),
    setApiKey: vi.fn(async () => ({ ok: true as const, value: { epoch: '1', topic: 'settings' as const, revision: '3', value: settingsView() } })),
    testSimulator: vi.fn(async () => ({ ok: true as const, value: true })),
  };
  return { ...bridge, ...overrides } as unknown as UiBridge;
}

describe('settings edit page', () => {
  it('seeds the form from the settings snapshot and reports the api key status', async () => {
    render(SettingsEdit, { props: { bridge: settingsBridge(), settings: settingsView({ simulator: { url: 'http://192.168.1.20:31270', api_key_configured: true } }), onConsent: vi.fn() } });
    expect(await screen.findByLabelText('URL')).toHaveValue('http://192.168.1.20:31270');
    expect(screen.getByText('A key is saved. Enter a new key below to replace it.')).toBeInTheDocument();
  });

  it('saves the url, sets a fresh api key and reports the connection test result', async () => {
    const bridge = settingsBridge();
    render(SettingsEdit, { props: { bridge, settings: settingsView(), onConsent: vi.fn() } });
    const url = await screen.findByLabelText('URL');
    await fireEvent.input(url, { target: { value: 'http://192.168.1.20:31270' } });
    await fireEvent.input(screen.getByLabelText('API Key'), { target: { value: 'secret-key' } });
    await fireEvent.click(screen.getByRole('button', { name: 'Save and test connection' }));
    await waitFor(() => expect(bridge.setApiKey).toHaveBeenCalledWith('secret-key'));
    expect(bridge.setSimulatorUrl).toHaveBeenCalledWith('http://192.168.1.20:31270');
    expect(await screen.findByText('Connected to Train Sim World.')).toBeInTheDocument();
  });

  it('keeps a blank key untouched and reports a failed probe honestly', async () => {
    const bridge = settingsBridge({ testSimulator: vi.fn(async () => ({ ok: true as const, value: false })) });
    render(SettingsEdit, { props: { bridge, settings: settingsView(), onConsent: vi.fn() } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Save and test connection' }));
    expect(bridge.setApiKey).not.toHaveBeenCalled();
    expect(await screen.findByText('Could not connect to Train Sim World. Check the URL, start the game with its API enabled, and try again.')).toBeInTheDocument();
  });

  it('validates the url inline: required and scheme', async () => {
    const bridge = settingsBridge();
    render(SettingsEdit, { props: { bridge, settings: settingsView(), onConsent: vi.fn() } });
    const url = await screen.findByLabelText('URL');
    await fireEvent.input(url, { target: { value: '' } });
    await fireEvent.change(url);
    expect(await screen.findByRole('alert')).toHaveTextContent('URL is required');

    await fireEvent.input(url, { target: { value: '192.168.1.20:31270' } });
    await fireEvent.change(url);
    expect(screen.getByRole('alert')).toHaveTextContent('URL must start with http:// or https://');
    await fireEvent.click(screen.getByRole('button', { name: 'Save and test connection' }));
    expect(bridge.setSimulatorUrl).not.toHaveBeenCalled();
  });

  it('renders backend url validation field errors inline', async () => {
    const bridge = settingsBridge({
      setSimulatorUrl: vi.fn(async () => ({ ok: false as const, error: { code: 'validation' as const, message: 'Check the highlighted field.', field_errors: { simulator_url: 'Enter a valid HTTP or HTTPS URL.' }, retryable: false } })),
    });
    render(SettingsEdit, { props: { bridge, settings: settingsView(), onConsent: vi.fn() } });
    await fireEvent.click(await screen.findByRole('button', { name: 'Save and test connection' }));
    expect(await screen.findByText('Enter a valid HTTP or HTTPS URL.')).toBeInTheDocument();
    expect(bridge.testSimulator).not.toHaveBeenCalled();
  });

  it('toggles error reporting through the consent path and shows its failure', async () => {
    const onConsent = vi.fn(async () => null);
    const { rerender } = render(SettingsEdit, { props: { bridge: settingsBridge(), settings: settingsView(), onConsent } });
    const toggle = await screen.findByTestId('error-reporting-toggle');
    expect(toggle).not.toBeChecked();
    await fireEvent.click(toggle);
    await waitFor(() => expect(onConsent).toHaveBeenCalledWith('enabled'));

    const failing = vi.fn(async () => 'The Rust desktop service is not available.');
    rerender({ bridge: settingsBridge(), settings: settingsView({ error_reporting: 'enabled' }), onConsent: failing });
    expect(screen.getByTestId('error-reporting-toggle')).toBeChecked();
    await fireEvent.click(screen.getByTestId('error-reporting-toggle'));
    await waitFor(() => expect(failing).toHaveBeenCalledWith('disabled'));
    expect(await screen.findByText('The Rust desktop service is not available.')).toBeInTheDocument();
  });
});
