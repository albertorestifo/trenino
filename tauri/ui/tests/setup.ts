import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/svelte';
import { afterEach } from 'vitest';

afterEach(cleanup);

// Node's built-in webstorage global (`localStorage`) exists but has no methods
// without a valid `--localstorage-file`, and it shadows jsdom's Storage in the
// vitest environment. Replace it with a working in-memory Storage.
if (typeof window !== 'undefined' && typeof window.localStorage?.getItem !== 'function') {
  class MemoryStorage implements Storage {
    #data = new Map<string, string>();
    get length() { return this.#data.size; }
    clear() { this.#data.clear(); }
    getItem(key: string) { return this.#data.get(key) ?? null; }
    key(index: number) { return [...this.#data.keys()][index] ?? null; }
    removeItem(key: string) { this.#data.delete(key); }
    setItem(key: string, value: string) { this.#data.set(key, String(value)); }
  }
  Object.defineProperty(window, 'localStorage', { value: new MemoryStorage(), configurable: true });
}
