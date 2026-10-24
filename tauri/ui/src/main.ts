import { mount } from 'svelte';
import App from './app/App.svelte';
import { applySavedTheme, applyThemePreference, setThemePreference } from './app/theme';
import './styles/app.css';

applySavedTheme(localStorage, document.documentElement);
window.addEventListener('storage', (event) => {
  if (event.key === 'phx:theme') applyThemePreference(event.newValue, document.documentElement);
});
window.addEventListener('phx:set-theme', (event) => {
  const source = event.target;
  if (source instanceof HTMLElement) {
    setThemePreference(source.dataset.phxTheme, localStorage, document.documentElement);
  }
});

mount(App, { target: document.getElementById('app')! });
