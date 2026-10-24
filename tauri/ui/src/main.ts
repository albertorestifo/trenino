import { mount } from 'svelte';
import App from './app/App.svelte';
import './styles/app.css';

function applyTheme(preference: string) {
  if (preference === 'light' || preference === 'dark') {
    document.documentElement.dataset.theme = preference;
    return;
  }
  const systemTheme = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  document.documentElement.dataset.theme = systemTheme;
}

applyTheme(localStorage.getItem('phx:theme') || 'system');
window.addEventListener('storage', (event) => {
  if (event.key === 'phx:theme') applyTheme(event.newValue || 'system');
});
window.addEventListener('phx:set-theme', (event) => {
  const source = event.target;
  if (source instanceof HTMLElement) {
    const theme = source.dataset.phxTheme || 'system';
    if (theme === 'system') localStorage.removeItem('phx:theme');
    else localStorage.setItem('phx:theme', theme);
    applyTheme(theme);
  }
});

mount(App, { target: document.getElementById('app')! });
