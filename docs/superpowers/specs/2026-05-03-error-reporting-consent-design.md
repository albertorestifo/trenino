# Error Reporting Consent & Settings Page

**Date:** 2026-05-03
**Status:** Approved

## Overview

Add a first-run consent screen that asks the user whether to share anonymous error reports (Sentry). The preference must be explicitly set before the main app becomes usable, can be changed at any time from a new Settings page, and takes effect immediately without a restart. If opted out, no data leaves the machine.

The same Settings page consolidates the existing simulator connection configuration, and the `AutoConfig` module is removed in favour of simpler direct reads through the `Settings` context.

---

## 1. Data Layer

### `app_settings` table

A new Ecto migration adds an `app_settings` table with two string columns: `key` (primary key) and `value`. No timestamps, no associations.

### `Trenino.Settings` context

The sole public interface for all app preferences. Callers use atoms; string conversion happens internally at the DB boundary using `Atom.to_string/1` and `String.to_existing_atom/1` (never `String.to_atom/1`). Valid value atoms are declared as module attributes.

**Error reporting:**

| Function | Returns | Notes |
|---|---|---|
| `error_reporting?()` | `boolean` | `false` if key absent — opt-out by default |
| `set_error_reporting(:enabled \| :disabled)` | `{:ok, _} \| {:error, _}` | Upserts the row |
| `error_reporting_set?()` | `boolean` | `true` if key exists; used by the consent gate |

**Simulator:**

| Function | Returns | Notes |
|---|---|---|
| `simulator_url()` | `String.t()` | Defaults to `"http://localhost:31270"` if absent |
| `set_simulator_url(url)` | `{:ok, _} \| {:error, _}` | |
| `api_key()` | `{:ok, key} \| {:error, reason}` | Checks DB first; falls back to `Settings.Simulator.read_from_file/0` |
| `set_api_key(key)` | `{:ok, _} \| {:error, _}` | Stores a manual override; subsequent `api_key()` calls return it |

**Sentry:**

| Function | Returns | Notes |
|---|---|---|
| `sentry_before_send(event)` | `event \| :ignore` | Public — required by Sentry's MFA callback convention |

### `Trenino.Settings.Simulator` (internal)

Encapsulates all file I/O for the TSW API key. Called only by `Settings.api_key/0`.

- `read_from_file/0` — reads `CommAPIKey.txt` from `%USERPROFILE%/Documents/My Games/TrainSimWorld6/Saved/Config/`. Returns `{:ok, key}` | `{:error, :not_windows | :file_not_found | :read_error}`.
- `windows?/0` — platform check.

---

## 2. Consent Gate

### Routing

Two live sessions in the router:

- `:consent` — contains only `live "/consent", ConsentLive`. No gate hook. Always reachable.
- `:default` — all existing routes plus the new `/settings` route. The `ConsentGateHook` is added to `on_mount`.

### `ConsentGateHook`

On every LiveView mount in `:default`, calls `Settings.error_reporting_set?()`. If `false`, halts and redirects to `/consent`. If `true`, continues normally.

### `ConsentLive`

Full-page LiveView with no nav header. Renders a centered compact card (see UI section). Two events:

- `"accept"` — calls `Settings.set_error_reporting(:enabled)`, redirects to `/`.
- `"decline"` — calls `Settings.set_error_reporting(:disabled)`, redirects to `/`.

The `/consent` route is also linked from the Settings page so the user can revisit the choice. Navigating there from Settings renders the same LiveView — no special mode needed, saving overwrites the existing value.

---

## 3. Sentry Integration

The DSN is baked into the release at build time via the `SENTRY_DSN` environment variable (same as today). `config/runtime.exs` changes: when `SENTRY_DSN` is set, Sentry is always configured, but a `before_send` callback is added:

```elixir
config :sentry,
  dsn: sentry_dsn,
  before_send: {Trenino.Settings, :sentry_before_send}
```

`Settings.sentry_before_send/1` reads `error_reporting?()` on every call. If `false`, returns `:ignore` and the event is dropped immediately — nothing leaves the machine. If `true`, returns the event unchanged. The preference change takes effect on the very next error event, no restart required.

The `Sentry.LoggerHandler` setup is unchanged; captured log events also pass through `before_send`.

---

## 4. Settings Page

### `SettingsLive` at `/settings`

A new LiveView with the full app chrome (nav header). The existing Simulator button in the nav header is replaced by a gear icon linking to `/settings`. The old `/simulator/config` route redirects to `/settings`.

Two sections on the page:

**Error Reporting**
- A toggle switch reflecting `Settings.error_reporting?()`.
- Toggling calls `Settings.set_error_reporting/1` immediately — no Save button.
- Body copy: "When enabled, anonymous crash reports are sent to help fix bugs. No personal data is included."

**Simulator Connection**
- URL text input, pre-filled from `Settings.simulator_url()`. Saved on submit.
- API key status indicator (Windows only): green "Found in TSW file — updated automatically" if `Settings.api_key()` succeeds via file; red "Not found" if it fails.
- Optional manual API key override input (all platforms). If filled and saved, stored via `Settings.set_api_key/1` and used in preference to the file on all subsequent connections.
- Save button submits URL and optional key together.

### `SimulatorConfigLive` removal

`SimulatorConfigLive` is deleted. Its event handlers and assigns are merged into `SettingsLive`. The router entry for `/simulator/config` is changed to a redirect to `/settings`.

### `AutoConfig` removal

`Trenino.Simulator.AutoConfig` is deleted entirely. `Connection` calls `Settings.simulator_url/0` and `Settings.api_key/0` directly:

```elixir
defp attempt_connection(%ConnectionState{} = state) do
  case Settings.api_key() do
    {:ok, api_key} -> do_connect(state, Settings.simulator_url(), api_key)
    {:error, _} -> ConnectionState.mark_needs_config(state)
  end
end
```

The `:needs_config` state now only appears when the API key is absent from both DB and the TSW file (non-Windows users who haven't set a key manually).

---

## 5. Data Migration

An Ecto data migration runs as part of the release, after schema migrations.

**Rule:** If a `simulator_configs` record exists with `auto_detected: false`, copy its `url` and `api_key` into `app_settings` (the user entered them manually, so they remain valid). If `auto_detected: true`, discard the entire record — the URL is just the default and the key will be re-read from the TSW file.

After the copy, the `simulator_configs` table is dropped.

---

## 6. UI

### Consent screen

- Full-page view, no nav header.
- Centered card on a dark background.
- Shield icon, "Help improve Trenino" heading, one-sentence explanation.
- Primary button: "Share error reports" (blue, full width).
- Secondary button: "No thanks" (ghost/outline, full width).

### Settings page

- Full app chrome with existing nav header.
- Gear icon in nav header links to `/settings`; replaces the Simulator button.
- Two visually separated sections with uppercase section labels.
- Toggle for error reporting (immediate effect).
- URL input + API key status + optional manual key override for simulator connection.

---

## Out of Scope

- Details of what specific data Sentry captures (future "Learn more" link).
- Additional settings categories beyond error reporting and simulator connection.
- User accounts or multi-user preferences.
