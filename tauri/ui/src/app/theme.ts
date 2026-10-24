export const THEME_STORAGE_KEY = 'phx:theme';
export type ThemePreference = 'system' | 'light' | 'dark';

type ThemeRoot = Pick<HTMLElement, 'dataset' | 'removeAttribute'>;
type ThemeStorage = Pick<Storage, 'getItem' | 'setItem' | 'removeItem'>;

export function normalizeThemePreference(value: string | null | undefined): ThemePreference {
  return value === 'light' || value === 'dark' ? value : 'system';
}

/** In system mode, leave the attribute absent for DaisyUI's prefersdark CSS rule. */
export function applyThemePreference(value: string | null | undefined, root: ThemeRoot): ThemePreference {
  const theme = normalizeThemePreference(value);
  if (theme === 'system') root.removeAttribute('data-theme');
  else root.dataset.theme = theme;
  return theme;
}

export function applySavedTheme(storage: ThemeStorage, root: ThemeRoot): ThemePreference {
  const stored = storage.getItem(THEME_STORAGE_KEY);
  const preference = normalizeThemePreference(stored);
  if (stored !== null && preference === 'system' && stored !== 'system') storage.removeItem(THEME_STORAGE_KEY);
  return applyThemePreference(preference, root);
}

export function setThemePreference(value: string | null | undefined, storage: ThemeStorage, root: ThemeRoot): ThemePreference {
  const theme = normalizeThemePreference(value);
  if (theme === 'system') storage.removeItem(THEME_STORAGE_KEY);
  else storage.setItem(THEME_STORAGE_KEY, theme);
  return applyThemePreference(theme, root);
}
