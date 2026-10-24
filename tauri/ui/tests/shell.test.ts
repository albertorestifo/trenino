import { fireEvent, render, screen, waitFor } from '@testing-library/svelte';
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
    subscribe: vi.fn(async () => () => {}),
  };
}

describe('shell', () => {
  it('renders the Rust-backed configuration empty state from the injected test bridge', async () => {
    location.hash = '#/';
    render(App, { props: { bridge: fakeBridge() } });
    expect(await screen.findByText('No Configurations')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /New Configuration/ })).toHaveAttribute('href', '#/configurations/new');
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

  it('shows settings values read-only', async () => {
    location.hash = '#/settings';
    render(App, { props: { bridge: fakeBridge() } });
    expect(await screen.findByText('Settings are shown read-only in this migration slice.')).toBeInTheDocument();
    expect(await screen.findByText('http://localhost:31270')).toBeInTheDocument();
  });
});
