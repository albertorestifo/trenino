import { describe, expect, it } from 'vitest';
import { applySavedTheme, applyThemePreference, setThemePreference } from '../src/app/theme';

describe('theme preference', () => {
  it('leaves system theme to CSS so OS changes remain live', () => {
    document.documentElement.dataset.theme = 'dark';
    applyThemePreference('system', document.documentElement);
    expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
  });

  it('keeps explicit light and dark preferences stable', () => {
    applyThemePreference('light', document.documentElement);
    expect(document.documentElement.dataset.theme).toBe('light');
    applyThemePreference('dark', document.documentElement);
    expect(document.documentElement.dataset.theme).toBe('dark');
  });

  it('falls back to system and clears invalid stored values', () => {
    const values = new Map<string, string>([['phx:theme', 'sepia']]);
    const storage = {
      getItem: (key: string) => values.get(key) ?? null,
      setItem: (key: string, value: string) => values.set(key, value),
      removeItem: (key: string) => values.delete(key),
    };
    document.documentElement.dataset.theme = 'light';
    expect(applySavedTheme(storage, document.documentElement)).toBe('system');
    expect(values.has('phx:theme')).toBe(false);
    expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
  });

  it('persists only valid explicit preferences', () => {
    const values = new Map<string, string>();
    const storage = {
      getItem: (key: string) => values.get(key) ?? null,
      setItem: (key: string, value: string) => values.set(key, value),
      removeItem: (key: string) => values.delete(key),
    };
    setThemePreference('dark', storage, document.documentElement);
    expect(values.get('phx:theme')).toBe('dark');
    setThemePreference('system', storage, document.documentElement);
    expect(values.has('phx:theme')).toBe(false);
    expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
  });
});
