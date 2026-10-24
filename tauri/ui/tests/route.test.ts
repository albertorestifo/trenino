import { describe, expect, it } from 'vitest';
import { parseRoute, routeHref } from '../src/bridge/route';

describe('route adapter', () => {
  it('keeps configuration ids as text and gives new precedence', () => {
    expect(parseRoute('#/configurations/2147483647')).toMatchObject({ page: 'configuration', configId: '2147483647' });
    expect(parseRoute('#/configurations/new')).toMatchObject({ page: 'configuration-new' });
    expect(parseRoute('#/trains/new?identifier=ICE%201')).toMatchObject({ page: 'train-new', query: new URLSearchParams('identifier=ICE+1') });
  });

  it('preserves train identifier query values and maps the simulator alias', () => {
    const train = parseRoute('#/trains?identifier=ICE%201');
    expect(train.page).toBe('trains');
    if (train.page === 'trains') expect(train.query.get('identifier')).toBe('ICE 1');
    expect(parseRoute('#/simulator/config')).toMatchObject({ page: 'settings', path: '/settings' });
  });

  it('uses hash hrefs for static reload-safe navigation', () => {
    expect(routeHref('/settings')).toBe('#/settings');
  });
});
