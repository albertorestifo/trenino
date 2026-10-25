export type Route =
  | { page: 'configurations'; path: '/'; query: URLSearchParams }
  | { page: 'configuration'; path: string; configId: string }
  | { page: 'configuration-new'; path: '/configurations/new' }
  | { page: 'trains'; path: '/trains'; query: URLSearchParams }
  | { page: 'train'; path: string; trainId: string; query: URLSearchParams }
  | { page: 'train-new'; path: '/trains/new'; query: URLSearchParams }
  | { page: 'script'; path: string; trainId: string; scriptId: string }
  | { page: 'script-new'; path: string; trainId: string }
  | { page: 'settings'; path: '/settings' }
  | { page: 'consent'; path: '/consent' }
  | { page: 'firmware' | 'joystick'; path: string }
  | { page: 'unavailable'; path: string };

export function parseRoute(hash: string): Route {
  const value = hash.startsWith('#') ? hash.slice(1) : hash;
  const parsed = new URL(value || '/', 'http://trenino.local');
  let path = parsed.pathname.replace(/\/+$/, '') || '/';
  if (path === '/simulator/config') path = '/settings';
  const query = parsed.searchParams;

  if (path === '/') return { page: 'configurations', path, query };
  if (path === '/trains') return { page: 'trains', path, query };
  if (path === '/configurations/new') return { page: 'configuration-new', path };
  if (path === '/trains/new') return { page: 'train-new', path, query };
  if (path === '/settings') return { page: 'settings', path };
  if (path === '/consent') return { page: 'consent', path };
  if (path === '/firmware') return { page: 'firmware', path };
  if (path === '/virtual-joystick') return { page: 'joystick', path };

  const scriptNewMatch = path.match(/^\/trains\/(\d+)\/scripts\/new$/);
  if (scriptNewMatch) return { page: 'script-new', path, trainId: scriptNewMatch[1] };
  const scriptMatch = path.match(/^\/trains\/(\d+)\/scripts\/(\d+)$/);
  if (scriptMatch) return { page: 'script', path, trainId: scriptMatch[1], scriptId: scriptMatch[2] };

  const configMatch = path.match(/^\/configurations\/([^/]+)$/);
  if (configMatch && configMatch[1] !== 'new' && /^\d+$/.test(configMatch[1])) {
    return { page: 'configuration', path, configId: configMatch[1] };
  }
  const trainMatch = path.match(/^\/trains\/([^/]+)$/);
  if (trainMatch && trainMatch[1] !== 'new' && /^\d+$/.test(trainMatch[1])) {
    return { page: 'train', path, trainId: trainMatch[1], query };
  }
  return { page: 'unavailable', path };
}

export function routeHref(path: string): string {
  return `#${path.startsWith('/') ? path : `/${path}`}`;
}
