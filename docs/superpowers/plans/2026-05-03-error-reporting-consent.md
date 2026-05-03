# Error Reporting Consent & Settings Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-run consent screen for Sentry error reporting plus a new Settings page that consolidates the existing simulator connection configuration.

**Architecture:** All preferences live in a new `app_settings` SQLite table accessed through the `Trenino.Settings` context. A LiveView `on_mount` hook gates the app on first launch by redirecting to `/consent` until a choice is recorded. Sentry honours the preference at runtime via a `before_send` callback. The simulator's `AutoConfig` module is removed in favour of direct calls to `Settings`, with a one-time data migration porting any user-entered simulator config into the new table.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto + SQLite, Sentry, Tailwind/DaisyUI.

**Spec:** `docs/superpowers/specs/2026-05-03-error-reporting-consent-design.md`

---

## File Structure

**Create:**
- `priv/repo/migrations/<NEW_TS>_create_app_settings.exs` — schema migration
- `priv/repo/migrations/<NEW_TS+1>_migrate_simulator_configs_to_app_settings.exs` — data migration + drops `simulator_configs`
- `lib/trenino/settings.ex` — public Settings context
- `lib/trenino/settings/setting.ex` — Ecto schema (raw key/value strings)
- `lib/trenino/settings/simulator.ex` — internal file-reading helper (replaces AutoConfig)
- `lib/trenino_web/live/consent_gate_hook.ex` — `on_mount` hook
- `lib/trenino_web/live/consent_live.ex` — first-run gate LiveView
- `lib/trenino_web/live/settings_live.ex` — Settings page LiveView
- `test/trenino/settings_test.exs`
- `test/trenino/settings/simulator_test.exs`
- `test/trenino_web/live/consent_gate_hook_test.exs`
- `test/trenino_web/live/consent_live_test.exs`
- `test/trenino_web/live/settings_live_test.exs`

**Modify:**
- `lib/trenino_web/router.ex` — add `:consent` live_session, attach gate hook to `:default`, add `/settings`, redirect `/simulator/config`
- `lib/trenino_web/components/nav_components.ex` — replace Simulator button with gear icon link
- `lib/trenino/simulator/connection.ex` — read settings via `Trenino.Settings` instead of `AutoConfig`
- `config/runtime.exs` — always configure Sentry when DSN present, add `before_send` callback
- `test/test_helper.exs` — remove `Trenino.Simulator.AutoConfig` from `Mimic.copy`

**Delete:**
- `lib/trenino/simulator/auto_config.ex`
- `lib/trenino/simulator/config.ex`
- `lib/trenino_web/live/simulator_config_live.ex`
- `test/trenino_web/live/simulator_config_live_test.exs`
- Any tests referencing `Trenino.Simulator.AutoConfig` directly

---

## Task 1: Create `app_settings` schema migration

**Files:**
- Create: `priv/repo/migrations/<TIMESTAMP>_create_app_settings.exs`

- [ ] **Step 1: Generate migration file**

Run: `mix ecto.gen.migration create_app_settings`
Expected: `* creating priv/repo/migrations/<TIMESTAMP>_create_app_settings.exs`

- [ ] **Step 2: Replace generated content**

Open the new file and replace its body with:

```elixir
defmodule Trenino.Repo.Migrations.CreateAppSettings do
  use Ecto.Migration

  def change do
    create table(:app_settings, primary_key: false) do
      add :key, :string, primary_key: true
      add :value, :string, null: false
    end
  end
end
```

- [ ] **Step 3: Run migration**

Run: `mix ecto.migrate`
Expected: `[info] create table app_settings`

- [ ] **Step 4: Verify the table exists**

Run: `mix ecto.migrate` again.
Expected: no output (already up).

- [ ] **Step 5: Commit**

```bash
git add priv/repo/migrations
git commit -m "feat(settings): add app_settings table"
```

---

## Task 2: `Settings.Setting` Ecto schema

**Files:**
- Create: `lib/trenino/settings/setting.ex`

- [ ] **Step 1: Write the schema module**

```elixir
defmodule Trenino.Settings.Setting do
  @moduledoc """
  Schema for the `app_settings` key/value store.

  Stores raw strings — atom-to-string conversion happens in
  `Trenino.Settings`, never here.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          key: String.t(),
          value: String.t()
        }

  @primary_key {:key, :string, autogenerate: false}
  schema "app_settings" do
    field :value, :string
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = setting, attrs) do
    setting
    |> cast(attrs, [:key, :value])
    |> validate_required([:key, :value])
  end
end
```

- [ ] **Step 2: Compile to verify**

Run: `mix compile --warnings-as-errors`
Expected: `Generated trenino app`

- [ ] **Step 3: Commit**

```bash
git add lib/trenino/settings/setting.ex
git commit -m "feat(settings): add Setting Ecto schema"
```

---

## Task 3: `Trenino.Settings` — error reporting functions (TDD)

**Files:**
- Create: `lib/trenino/settings.ex`
- Create: `test/trenino/settings_test.exs`

- [ ] **Step 1: Write failing test**

```elixir
defmodule Trenino.SettingsTest do
  use Trenino.DataCase, async: true

  alias Trenino.Settings

  describe "error_reporting?/0" do
    test "returns false when no preference is set" do
      refute Settings.error_reporting?()
    end

    test "returns true when set to :enabled" do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      assert Settings.error_reporting?()
    end

    test "returns false when set to :disabled" do
      {:ok, _} = Settings.set_error_reporting(:disabled)
      refute Settings.error_reporting?()
    end
  end

  describe "error_reporting_set?/0" do
    test "returns false when no preference is set" do
      refute Settings.error_reporting_set?()
    end

    test "returns true after a choice is made (enabled)" do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      assert Settings.error_reporting_set?()
    end

    test "returns true after a choice is made (disabled)" do
      {:ok, _} = Settings.set_error_reporting(:disabled)
      assert Settings.error_reporting_set?()
    end
  end

  describe "set_error_reporting/1" do
    test "rejects values other than :enabled or :disabled" do
      assert_raise FunctionClauseError, fn ->
        Settings.set_error_reporting(:maybe)
      end
    end

    test "upserts an existing preference" do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      {:ok, _} = Settings.set_error_reporting(:disabled)
      refute Settings.error_reporting?()
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/trenino/settings_test.exs`
Expected: FAIL with `module Trenino.Settings is not loaded`.

- [ ] **Step 3: Implement `Trenino.Settings`**

```elixir
defmodule Trenino.Settings do
  @moduledoc """
  Public interface for application-wide preferences.

  Callers use atoms; conversion to/from the underlying string
  storage happens internally. Never exposes the underlying schema.
  """

  import Ecto.Query

  alias Trenino.Repo
  alias Trenino.Settings.Setting

  @error_reporting_key "error_reporting"
  @error_reporting_values [:enabled, :disabled]

  @spec error_reporting?() :: boolean()
  def error_reporting?, do: get_atom(@error_reporting_key, @error_reporting_values) == :enabled

  @spec error_reporting_set?() :: boolean()
  def error_reporting_set?, do: not is_nil(get_raw(@error_reporting_key))

  @spec set_error_reporting(:enabled | :disabled) ::
          {:ok, Setting.t()} | {:error, Ecto.Changeset.t()}
  def set_error_reporting(value) when value in @error_reporting_values do
    put_raw(@error_reporting_key, Atom.to_string(value))
  end

  # Private helpers

  defp get_raw(key) do
    case Repo.get(Setting, key) do
      nil -> nil
      %Setting{value: value} -> value
    end
  end

  defp get_atom(key, allowed) do
    case get_raw(key) do
      nil -> nil
      raw -> safe_to_atom(raw, allowed)
    end
  end

  defp safe_to_atom(raw, allowed) do
    atom = String.to_existing_atom(raw)
    if atom in allowed, do: atom
  rescue
    ArgumentError -> nil
  end

  defp put_raw(key, value) do
    %Setting{}
    |> Setting.changeset(%{key: key, value: value})
    |> Repo.insert(
      on_conflict: [set: [value: value]],
      conflict_target: :key
    )
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/trenino/settings_test.exs`
Expected: `8 tests, 0 failures`

- [ ] **Step 5: Commit**

```bash
git add lib/trenino/settings.ex test/trenino/settings_test.exs
git commit -m "feat(settings): add error reporting preference"
```

---

## Task 4: Sentry `before_send` callback

**Files:**
- Modify: `lib/trenino/settings.ex`
- Modify: `test/trenino/settings_test.exs`
- Modify: `config/runtime.exs`

- [ ] **Step 1: Add a failing test for `sentry_before_send/1`**

Append to `test/trenino/settings_test.exs` inside the `Trenino.SettingsTest` module:

```elixir
  describe "sentry_before_send/1" do
    test "returns :ignore when error reporting is disabled (default)" do
      assert :ignore = Settings.sentry_before_send(%{event: :stub})
    end

    test "returns :ignore when explicitly disabled" do
      {:ok, _} = Settings.set_error_reporting(:disabled)
      assert :ignore = Settings.sentry_before_send(%{event: :stub})
    end

    test "returns the event unchanged when enabled" do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      event = %{message: "boom"}
      assert ^event = Settings.sentry_before_send(event)
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/trenino/settings_test.exs`
Expected: FAIL with `function Trenino.Settings.sentry_before_send/1 is undefined`.

- [ ] **Step 3: Add the function to `Trenino.Settings`**

Insert after `set_error_reporting/1`:

```elixir
  @doc """
  Sentry `before_send` callback. Drops events when the user has not
  opted in to error reporting.
  """
  @spec sentry_before_send(map()) :: map() | :ignore
  def sentry_before_send(event) do
    if error_reporting?(), do: event, else: :ignore
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/trenino/settings_test.exs`
Expected: `11 tests, 0 failures`

- [ ] **Step 5: Wire the callback into `config/runtime.exs`**

In `config/runtime.exs`, replace the existing Sentry block:

```elixir
if sentry_dsn = System.get_env("SENTRY_DSN") do
  config :sentry, dsn: sentry_dsn

  config :trenino, :logger, [
    {:handler, :sentry_handler, Sentry.LoggerHandler,
     %{
       config: %{
         metadata: [:file, :line, :request_id],
         capture_log_messages: true,
         level: :error
       }
     }}
  ]
end
```

with:

```elixir
if sentry_dsn = System.get_env("SENTRY_DSN") do
  config :sentry,
    dsn: sentry_dsn,
    before_send: {Trenino.Settings, :sentry_before_send}

  config :trenino, :logger, [
    {:handler, :sentry_handler, Sentry.LoggerHandler,
     %{
       config: %{
         metadata: [:file, :line, :request_id],
         capture_log_messages: true,
         level: :error
       }
     }}
  ]
end
```

- [ ] **Step 6: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: `Generated trenino app`

- [ ] **Step 7: Commit**

```bash
git add lib/trenino/settings.ex test/trenino/settings_test.exs config/runtime.exs
git commit -m "feat(settings): gate Sentry events on user consent"
```

---

## Task 5: `ConsentGateHook` (TDD)

**Files:**
- Create: `lib/trenino_web/live/consent_gate_hook.ex`
- Create: `test/trenino_web/live/consent_gate_hook_test.exs`

- [ ] **Step 1: Write failing test**

```elixir
defmodule TreninoWeb.ConsentGateHookTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Settings

  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})
    :ok
  end

  test "redirects to /consent when no preference is set", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/consent"}}} = live(conn, ~p"/")
  end

  test "allows the page to render once consent is given", %{conn: conn} do
    {:ok, _} = Settings.set_error_reporting(:enabled)

    assert {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Trenino"
  end

  test "allows the page to render even when consent is declined", %{conn: conn} do
    {:ok, _} = Settings.set_error_reporting(:disabled)

    assert {:ok, _view, _html} = live(conn, ~p"/")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/trenino_web/live/consent_gate_hook_test.exs`
Expected: FAIL — both redirect and render tests fail because the hook doesn't exist yet (every test will hit the existing default page).

- [ ] **Step 3: Implement the hook**

```elixir
defmodule TreninoWeb.ConsentGateHook do
  @moduledoc """
  LiveView `on_mount` hook that redirects to `/consent` until the
  user has explicitly chosen whether to share error reports.
  """

  import Phoenix.LiveView

  alias Trenino.Settings

  def on_mount(:default, _params, _session, socket) do
    if Settings.error_reporting_set?() do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/consent")}
    end
  end
end
```

- [ ] **Step 4: Attach hook in router**

In `lib/trenino_web/router.ex`, modify the `live_session :default` block to include the gate hook FIRST in `on_mount`:

```elixir
    live_session :default,
      on_mount: [
        TreninoWeb.ConsentGateHook,
        {TreninoWeb.NavHook, :default},
        {TreninoWeb.MCPDetectionHook, :default}
      ],
      layout: {TreninoWeb.Layouts, :app} do
      live "/", ConfigurationListLive
      live "/configurations/:config_id", ConfigurationEditLive
      live "/simulator/config", SimulatorConfigLive
      live "/trains", TrainListLive
      live "/trains/:train_id", TrainEditLive
      live "/trains/:train_id/scripts/new", ScriptEditLive
      live "/trains/:train_id/scripts/:script_id", ScriptEditLive
      live "/firmware", FirmwareLive
    end
```

- [ ] **Step 5: Run test to verify the redirect test now passes (the render tests still fail because `/consent` route doesn't exist yet — but the gate runs first so the redirect attempt succeeds)**

Run: `mix test test/trenino_web/live/consent_gate_hook_test.exs --only line:NUMBER` for the first test.
Expected: PASS for "redirects to /consent when no preference is set". The other two tests will also pass since they pre-set the preference.

If all three pass:

Run: `mix test test/trenino_web/live/consent_gate_hook_test.exs`
Expected: `3 tests, 0 failures`

- [ ] **Step 6: Commit**

```bash
git add lib/trenino_web/live/consent_gate_hook.ex test/trenino_web/live/consent_gate_hook_test.exs lib/trenino_web/router.ex
git commit -m "feat(consent): redirect to /consent until preference is set"
```

---

## Task 6: `ConsentLive` LiveView (TDD)

**Files:**
- Create: `lib/trenino_web/live/consent_live.ex`
- Create: `test/trenino_web/live/consent_live_test.exs`
- Modify: `lib/trenino_web/router.ex`

- [ ] **Step 1: Write failing test**

```elixir
defmodule TreninoWeb.ConsentLiveTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Settings

  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})
    :ok
  end

  describe "mount/3" do
    test "renders the consent card", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/consent")

      assert html =~ "Help improve Trenino"
      assert html =~ "Share error reports"
      assert html =~ "No thanks"
    end

    test "is reachable without redirecting", %{conn: conn} do
      assert {:ok, _view, _html} = live(conn, ~p"/consent")
    end
  end

  describe "events" do
    test "accept stores :enabled and redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/consent")

      assert {:error, {:redirect, %{to: "/"}}} =
               view |> element("button[phx-click=accept]") |> render_click()

      assert Settings.error_reporting?()
    end

    test "decline stores :disabled and redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/consent")

      assert {:error, {:redirect, %{to: "/"}}} =
               view |> element("button[phx-click=decline]") |> render_click()

      assert Settings.error_reporting_set?()
      refute Settings.error_reporting?()
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/trenino_web/live/consent_live_test.exs`
Expected: FAIL with `no route found for GET /consent`.

- [ ] **Step 3: Add `:consent` live_session in `lib/trenino_web/router.ex`**

Insert after the existing `live_session :default` block, inside the same `scope "/", TreninoWeb`:

```elixir
    live_session :consent, layout: {TreninoWeb.Layouts, :root} do
      live "/consent", ConsentLive
    end
```

The `:consent` session deliberately omits both `ConsentGateHook` (would loop) and `NavHook`/`MCPDetectionHook` (no nav UI on this page). Using the `:root` layout (not `:app`) avoids rendering the nav header.

- [ ] **Step 4: Implement `ConsentLive`**

```elixir
defmodule TreninoWeb.ConsentLive do
  @moduledoc """
  First-run gate that asks the user whether to share Sentry error
  reports. Reachable from `/consent` and required before any other
  route renders.
  """

  use TreninoWeb, :live_view

  alias Trenino.Settings

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket, layout: false}

  @impl true
  def handle_event("accept", _params, socket) do
    {:ok, _} = Settings.set_error_reporting(:enabled)
    {:noreply, push_navigate(socket, to: "/")}
  end

  @impl true
  def handle_event("decline", _params, socket) do
    {:ok, _} = Settings.set_error_reporting(:disabled)
    {:noreply, push_navigate(socket, to: "/")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-base-200 p-4">
      <div class="card max-w-md w-full bg-base-100 shadow-xl">
        <div class="card-body items-center text-center">
          <div class="rounded-full bg-primary/10 p-3 mb-2">
            <.icon name="hero-shield-check" class="w-8 h-8 text-primary" />
          </div>
          <h2 class="card-title text-lg">Help improve Trenino</h2>
          <p class="text-sm text-base-content/70">
            Share anonymous error reports so bugs can be found and fixed faster. No personal data, no usage tracking — only crash reports.
          </p>
          <div class="card-actions w-full flex flex-col gap-2 mt-4">
            <button phx-click="accept" class="btn btn-primary w-full">
              Share error reports
            </button>
            <button phx-click="decline" class="btn btn-ghost w-full">
              No thanks
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/trenino_web/live/consent_live_test.exs`
Expected: `4 tests, 0 failures`

- [ ] **Step 6: Re-run the gate hook test (it should still pass — the redirect target now exists)**

Run: `mix test test/trenino_web/live/consent_gate_hook_test.exs`
Expected: `3 tests, 0 failures`

- [ ] **Step 7: Commit**

```bash
git add lib/trenino_web/live/consent_live.ex test/trenino_web/live/consent_live_test.exs lib/trenino_web/router.ex
git commit -m "feat(consent): add ConsentLive first-run screen"
```

---

## Task 7: `SettingsLive` — error reporting toggle (TDD)

**Files:**
- Create: `lib/trenino_web/live/settings_live.ex`
- Create: `test/trenino_web/live/settings_live_test.exs`
- Modify: `lib/trenino_web/router.ex`

- [ ] **Step 1: Write failing test (error-reporting-only)**

```elixir
defmodule TreninoWeb.SettingsLiveTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Settings

  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})
    # Pass the consent gate
    {:ok, _} = Settings.set_error_reporting(:disabled)
    :ok
  end

  describe "mount/3" do
    test "renders the Settings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "Settings"
      assert html =~ "Error Reporting"
    end

    test "shows the toggle reflecting current preference (off)", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")
      refute html =~ ~s(data-testid="error-reporting-toggle" checked)
    end

    test "shows the toggle reflecting current preference (on)", %{conn: conn} do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      {:ok, _view, html} = live(conn, ~p"/settings")
      assert html =~ ~s(data-testid="error-reporting-toggle")
      assert html =~ "checked"
    end
  end

  describe "toggle_error_reporting" do
    test "enables when toggled on", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> element(~s([data-testid="error-reporting-toggle"]))
      |> render_click()

      assert Settings.error_reporting?()
    end

    test "disables when toggled off", %{conn: conn} do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> element(~s([data-testid="error-reporting-toggle"]))
      |> render_click()

      refute Settings.error_reporting?()
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/trenino_web/live/settings_live_test.exs`
Expected: FAIL with `no route found for GET /settings`.

- [ ] **Step 3: Add `/settings` route to `:default` live_session in `lib/trenino_web/router.ex`**

Inside the existing `live_session :default` block, add:

```elixir
      live "/settings", SettingsLive
```

- [ ] **Step 4: Implement `SettingsLive` (error reporting only — simulator section comes in Task 12)**

```elixir
defmodule TreninoWeb.SettingsLive do
  @moduledoc """
  Settings page. Currently exposes the error reporting preference.
  The simulator connection section is added in a later task.
  """

  use TreninoWeb, :live_view

  import TreninoWeb.NavComponents

  alias Trenino.Serial.Connection
  alias Trenino.Settings

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :error_reporting_enabled, Settings.error_reporting?())}
  end

  # Nav component events (mirror other LiveViews)
  @impl true
  def handle_event("nav_toggle_dropdown", _, socket) do
    {:noreply, assign(socket, :nav_dropdown_open, !socket.assigns.nav_dropdown_open)}
  end

  @impl true
  def handle_event("nav_close_dropdown", _, socket) do
    {:noreply, assign(socket, :nav_dropdown_open, false)}
  end

  @impl true
  def handle_event("nav_scan_devices", _, socket) do
    Connection.scan()
    {:noreply, assign(socket, :nav_scanning, true)}
  end

  @impl true
  def handle_event("nav_disconnect_device", %{"port" => port}, socket) do
    Connection.disconnect(port)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_error_reporting", _params, socket) do
    new_value = if socket.assigns.error_reporting_enabled, do: :disabled, else: :enabled
    {:ok, _} = Settings.set_error_reporting(new_value)
    {:noreply, assign(socket, :error_reporting_enabled, new_value == :enabled)}
  end

  # PubSub handlers (mirror other LiveViews)
  @impl true
  def handle_info({:devices_updated, devices}, socket) do
    {:noreply, assign(socket, :nav_devices, devices)}
  end

  @impl true
  def handle_info({:simulator_status_changed, status}, socket) do
    {:noreply, assign(socket, :nav_simulator_status, status)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}
      nav_devices={@nav_devices}
      nav_simulator_status={@nav_simulator_status}
      nav_firmware_update={@nav_firmware_update}
      nav_app_version_update={@nav_app_version_update}
      nav_firmware_checking={@nav_firmware_checking}
      nav_dropdown_open={@nav_dropdown_open}
      nav_scanning={@nav_scanning}
      nav_current_path={@nav_current_path}>

      <div class="max-w-2xl mx-auto px-4 sm:px-8 py-6">
        <h1 class="text-xl font-semibold mb-1">Settings</h1>
        <p class="text-sm text-base-content/70 mb-6">Configure your Trenino preferences</p>

        <section class="card bg-base-100 border border-base-300 mb-4">
          <div class="card-body">
            <div class="text-xs uppercase tracking-wider text-base-content/60 mb-2">Error Reporting</div>
            <div class="flex items-center justify-between gap-4">
              <div>
                <div class="font-medium">Share anonymous error reports</div>
                <div class="text-sm text-base-content/70">
                  Crash reports are sent to help fix bugs. No personal data is included.
                </div>
              </div>
              <input
                type="checkbox"
                class="toggle toggle-primary"
                data-testid="error-reporting-toggle"
                phx-click="toggle_error_reporting"
                checked={@error_reporting_enabled}
              />
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `mix test test/trenino_web/live/settings_live_test.exs`
Expected: `5 tests, 0 failures`

- [ ] **Step 6: Commit**

```bash
git add lib/trenino_web/live/settings_live.ex test/trenino_web/live/settings_live_test.exs lib/trenino_web/router.ex
git commit -m "feat(settings): add SettingsLive page with error reporting toggle"
```

---

## Task 8: Replace nav Simulator button with Settings gear icon

**Files:**
- Modify: `lib/trenino_web/components/nav_components.ex`

- [ ] **Step 1: Locate the existing Simulator link**

In `lib/trenino_web/components/nav_components.ex`, find this block inside `nav_header/1`:

```elixir
          <.link
            navigate={~p"/simulator/config"}
            class="flex items-center gap-2 px-3 py-2 rounded-lg bg-base-200 hover:bg-base-300 transition-colors duration-150"
            title="Simulator Connection"
          >
            <span class={["w-2 h-2 rounded-full", simulator_status_color(@simulator_status.status)]} />
            <span class="text-sm font-medium hidden sm:inline">Simulator</span>
          </.link>
```

- [ ] **Step 2: Replace with a gear icon link to `/settings`**

```elixir
          <.link
            navigate={~p"/settings"}
            class="flex items-center gap-2 px-3 py-2 rounded-lg bg-base-200 hover:bg-base-300 transition-colors duration-150"
            title="Settings"
            aria-label="Settings"
          >
            <span class={["w-2 h-2 rounded-full", simulator_status_color(@simulator_status.status)]} />
            <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
            <span class="text-sm font-medium hidden sm:inline">Settings</span>
          </.link>
```

The simulator status dot is preserved — it's still a useful at-a-glance indicator.

- [ ] **Step 3: Run the LiveView tests to make sure no template assertion broke**

Run: `mix test test/trenino_web/live/`
Expected: All passing. If any test asserts on the literal text `"Simulator"` in the nav, update it to `"Settings"`.

- [ ] **Step 4: Compile and run all tests**

Run: `mix test`
Expected: All passing (1336 tests + 12 new = 1348, allowing for the same flake-prone test).

- [ ] **Step 5: Commit**

```bash
git add lib/trenino_web/components/nav_components.ex test/trenino_web/live/
git commit -m "feat(nav): swap Simulator link for Settings gear icon"
```

---

## Task 9: `Settings.Simulator` file reader (TDD)

**Files:**
- Create: `lib/trenino/settings/simulator.ex`
- Create: `test/trenino/settings/simulator_test.exs`

- [ ] **Step 1: Write failing test**

```elixir
defmodule Trenino.Settings.SimulatorTest do
  use ExUnit.Case, async: true

  alias Trenino.Settings.Simulator

  describe "windows?/0" do
    test "returns a boolean" do
      assert is_boolean(Simulator.windows?())
    end
  end

  describe "read_from_file/0 (non-Windows)" do
    @tag :skip_on_windows
    test "returns :not_windows on non-Windows platforms" do
      unless Simulator.windows?() do
        assert {:error, :not_windows} = Simulator.read_from_file()
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/trenino/settings/simulator_test.exs`
Expected: FAIL — module does not exist.

- [ ] **Step 3: Implement the module**

```elixir
defmodule Trenino.Settings.Simulator do
  @moduledoc """
  Reads the Train Sim World API key from disk on Windows.

  Replaces `Trenino.Simulator.AutoConfig`. Pure read — never writes.
  """

  @doc """
  Reads `CommAPIKey.txt` from the TSW Saved/Config directory.

  Returns `{:ok, key}` on success.
  Returns `{:error, :not_windows | :userprofile_not_set | :file_not_found | :read_error}`.
  """
  @spec read_from_file() ::
          {:ok, String.t()}
          | {:error, :not_windows | :userprofile_not_set | :file_not_found | :read_error}
  def read_from_file do
    if windows?(), do: do_read(), else: {:error, :not_windows}
  end

  @doc "Whether the current OS is Windows."
  @spec windows?() :: boolean()
  def windows? do
    case :os.type() do
      {:win32, _} -> true
      _ -> false
    end
  end

  defp do_read do
    case System.get_env("USERPROFILE") do
      nil ->
        {:error, :userprofile_not_set}

      userprofile ->
        path = api_key_path(userprofile)

        case File.read(path) do
          {:ok, content} -> {:ok, String.trim(content)}
          {:error, :enoent} -> {:error, :file_not_found}
          {:error, _} -> {:error, :read_error}
        end
    end
  end

  defp api_key_path(userprofile) do
    Path.join([
      userprofile,
      "Documents",
      "My Games",
      "TrainSimWorld6",
      "Saved",
      "Config",
      "CommAPIKey.txt"
    ])
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `mix test test/trenino/settings/simulator_test.exs`
Expected: `2 tests, 0 failures` (1 may be skipped on non-Windows).

- [ ] **Step 5: Commit**

```bash
git add lib/trenino/settings/simulator.ex test/trenino/settings/simulator_test.exs
git commit -m "feat(settings): add Settings.Simulator file reader"
```

---

## Task 10: `Settings.simulator_url/0`, `set_simulator_url/1`, `api_key/0`, `set_api_key/1` (TDD)

**Files:**
- Modify: `lib/trenino/settings.ex`
- Modify: `test/trenino/settings_test.exs`

- [ ] **Step 1: Write failing tests**

Append to `test/trenino/settings_test.exs`:

```elixir
  describe "simulator_url/0" do
    test "returns the default URL when unset" do
      assert "http://localhost:31270" = Settings.simulator_url()
    end

    test "returns the stored URL when set" do
      {:ok, _} = Settings.set_simulator_url("http://192.168.1.10:31270")
      assert "http://192.168.1.10:31270" = Settings.simulator_url()
    end
  end

  describe "set_simulator_url/1" do
    test "stores a URL" do
      {:ok, _} = Settings.set_simulator_url("http://example.local:31270")
      assert "http://example.local:31270" = Settings.simulator_url()
    end
  end

  describe "api_key/0" do
    test "returns the stored key when set" do
      {:ok, _} = Settings.set_api_key("manual-key-123")
      assert {:ok, "manual-key-123"} = Settings.api_key()
    end

    test "delegates to Settings.Simulator on non-Windows when no key is stored" do
      # On non-Windows machines with no DB entry, file read returns :not_windows
      unless Trenino.Settings.Simulator.windows?() do
        assert {:error, :not_windows} = Settings.api_key()
      end
    end
  end

  describe "set_api_key/1" do
    test "persists the manual override" do
      {:ok, _} = Settings.set_api_key("override-abc")
      assert {:ok, "override-abc"} = Settings.api_key()
    end

    test "subsequent calls reflect the override" do
      {:ok, _} = Settings.set_api_key("first")
      {:ok, _} = Settings.set_api_key("second")
      assert {:ok, "second"} = Settings.api_key()
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/trenino/settings_test.exs`
Expected: FAIL — `simulator_url/0`, `set_simulator_url/1`, `api_key/0`, `set_api_key/1` undefined.

- [ ] **Step 3: Add functions to `Trenino.Settings`**

Inside `Trenino.Settings`, add:

```elixir
  @simulator_url_key "simulator_url"
  @simulator_api_key_key "simulator_api_key"
  @default_simulator_url "http://localhost:31270"

  @spec simulator_url() :: String.t()
  def simulator_url, do: get_raw(@simulator_url_key) || @default_simulator_url

  @spec set_simulator_url(String.t()) ::
          {:ok, Setting.t()} | {:error, Ecto.Changeset.t()}
  def set_simulator_url(url) when is_binary(url), do: put_raw(@simulator_url_key, url)

  @spec api_key() ::
          {:ok, String.t()}
          | {:error,
             :not_windows | :userprofile_not_set | :file_not_found | :read_error}
  def api_key do
    case get_raw(@simulator_api_key_key) do
      nil -> Trenino.Settings.Simulator.read_from_file()
      key when is_binary(key) -> {:ok, key}
    end
  end

  @spec set_api_key(String.t()) ::
          {:ok, Setting.t()} | {:error, Ecto.Changeset.t()}
  def set_api_key(key) when is_binary(key), do: put_raw(@simulator_api_key_key, key)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/trenino/settings_test.exs`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/trenino/settings.ex test/trenino/settings_test.exs
git commit -m "feat(settings): add simulator url and api key accessors"
```

---

## Task 11: `Connection` GenServer reads from `Settings`

**Files:**
- Modify: `lib/trenino/simulator/connection.ex`

- [ ] **Step 1: Read current `attempt_connection/1`**

Locate this function in `lib/trenino/simulator/connection.ex`:

```elixir
  defp attempt_connection(%ConnectionState{} = state) do
    case AutoConfig.ensure_config() do
      {:ok, %Config{url: url, api_key: api_key}} ->
        do_connect(state, url, api_key)

      {:error, _reason} ->
        ConnectionState.mark_needs_config(state)
    end
  end
```

- [ ] **Step 2: Replace with a `Settings`-based version**

```elixir
  defp attempt_connection(%ConnectionState{} = state) do
    case Settings.api_key() do
      {:ok, api_key} ->
        do_connect(state, Settings.simulator_url(), api_key)

      {:error, _reason} ->
        ConnectionState.mark_needs_config(state)
    end
  end
```

- [ ] **Step 3: Update aliases at the top of the module**

Replace:

```elixir
  alias Trenino.Simulator.AutoConfig
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.Config
  alias Trenino.Simulator.ConnectionState
```

with:

```elixir
  alias Trenino.Settings
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.ConnectionState
```

(Removes both `AutoConfig` and `Config`. `Settings` is the new dependency.)

- [ ] **Step 4: Compile**

Run: `mix compile --warnings-as-errors`
Expected: compiles cleanly. If a warning fires for an unused alias, remove it.

- [ ] **Step 5: Run tests touching Connection**

Run: `mix test test/trenino/simulator_test.exs test/trenino/integration/`
Expected: tests that previously stubbed `Trenino.Simulator.AutoConfig` will now fail. That's expected — fix in Task 13.

For now, only verify the project compiles. Do NOT commit yet — this commit comes at the end of Task 13 along with the related cleanup.

---

## Task 12: Add simulator section to `SettingsLive`

**Files:**
- Modify: `lib/trenino_web/live/settings_live.ex`
- Modify: `test/trenino_web/live/settings_live_test.exs`

- [ ] **Step 1: Add tests for the simulator section**

Append inside `TreninoWeb.SettingsLiveTest`:

```elixir
  describe "simulator section" do
    test "renders the URL field", %{conn: conn} do
      {:ok, _} = Settings.set_simulator_url("http://192.168.1.42:31270")
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "Simulator Connection"
      assert html =~ "http://192.168.1.42:31270"
    end

    test "saves a new URL on submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> form(~s([data-testid="simulator-form"]),
        simulator: %{url: "http://10.0.0.1:31270", api_key: ""}
      )
      |> render_submit()

      assert "http://10.0.0.1:31270" = Settings.simulator_url()
    end

    test "saves an api key override when provided", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> form(~s([data-testid="simulator-form"]),
        simulator: %{url: "http://localhost:31270", api_key: "my-override"}
      )
      |> render_submit()

      assert {:ok, "my-override"} = Settings.api_key()
    end

    test "leaves api key untouched when override field is blank", %{conn: conn} do
      {:ok, _} = Settings.set_api_key("existing")
      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> form(~s([data-testid="simulator-form"]),
        simulator: %{url: "http://localhost:31270", api_key: ""}
      )
      |> render_submit()

      assert {:ok, "existing"} = Settings.api_key()
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `mix test test/trenino_web/live/settings_live_test.exs`
Expected: FAIL — no simulator section yet.

- [ ] **Step 3: Update `SettingsLive` mount to load simulator state**

Replace the `mount/3` function body with:

```elixir
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:error_reporting_enabled, Settings.error_reporting?())
     |> assign(:simulator_url, Settings.simulator_url())
     |> assign(:api_key_status, api_key_status())}
  end

  defp api_key_status do
    case Trenino.Settings.Simulator.windows?() do
      true ->
        case Trenino.Settings.Simulator.read_from_file() do
          {:ok, _key} -> :found_in_file
          {:error, _} -> :missing
        end

      false ->
        :unsupported_platform
    end
  end
```

- [ ] **Step 4: Add a save handler**

Add to `SettingsLive`:

```elixir
  @impl true
  def handle_event("save_simulator", %{"simulator" => params}, socket) do
    %{"url" => url, "api_key" => api_key} = params

    {:ok, _} = Settings.set_simulator_url(url)

    if api_key != "" do
      {:ok, _} = Settings.set_api_key(api_key)
    end

    Trenino.Simulator.Connection.reconfigure()

    {:noreply,
     socket
     |> assign(:simulator_url, Settings.simulator_url())
     |> assign(:api_key_status, api_key_status())
     |> put_flash(:info, "Simulator configuration saved")}
  end
```

`Trenino.Simulator.Connection` is fully qualified to avoid clashing with the existing `Trenino.Serial.Connection` alias (used for nav events).

- [ ] **Step 5: Add the simulator section to `render/1`**

Append a second `<section>` after the error reporting section:

```elixir
        <section class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <div class="text-xs uppercase tracking-wider text-base-content/60 mb-2">Simulator Connection</div>
            <.form for={%{}} as={:simulator} phx-submit="save_simulator" data-testid="simulator-form">
              <label class="form-control w-full mb-3">
                <span class="label-text text-sm">URL</span>
                <input
                  type="text"
                  name="simulator[url]"
                  value={@simulator_url}
                  class="input input-bordered font-mono"
                />
              </label>

              <div class="mb-3">
                <span class="label-text text-sm">API Key</span>
                <%= case @api_key_status do %>
                  <% :found_in_file -> %>
                    <div class="alert alert-success p-2 mt-1 text-sm">
                      <.icon name="hero-check-circle" class="w-4 h-4" />
                      Found in TSW file — updated automatically
                    </div>
                  <% :missing -> %>
                    <div class="alert alert-warning p-2 mt-1 text-sm">
                      <.icon name="hero-exclamation-triangle" class="w-4 h-4" />
                      Not found in TSW file — enter a key below
                    </div>
                  <% :unsupported_platform -> %>
                    <div class="alert p-2 mt-1 text-sm">
                      <.icon name="hero-information-circle" class="w-4 h-4" />
                      Auto-detection only available on Windows — enter a key below
                    </div>
                <% end %>
              </div>

              <label class="form-control w-full mb-3">
                <span class="label-text text-sm text-base-content/60">Override API key manually</span>
                <input
                  type="password"
                  name="simulator[api_key]"
                  placeholder="Leave blank to keep current value"
                  class="input input-bordered font-mono"
                />
              </label>

              <div class="flex justify-end">
                <button type="submit" class="btn btn-primary">Save</button>
              </div>
            </.form>
          </div>
        </section>
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `mix test test/trenino_web/live/settings_live_test.exs`
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/trenino_web/live/settings_live.ex test/trenino_web/live/settings_live_test.exs
git commit -m "feat(settings): add simulator connection section"
```

---

## Task 13: Delete `AutoConfig`, `Simulator.Config`, and `SimulatorConfigLive`

**Files:**
- Delete: `lib/trenino/simulator/auto_config.ex`
- Delete: `lib/trenino/simulator/config.ex`
- Delete: `lib/trenino_web/live/simulator_config_live.ex`
- Delete: `test/trenino_web/live/simulator_config_live_test.exs`
- Modify: `lib/trenino_web/router.ex`
- Modify: `lib/trenino/simulator.ex` (remove now-orphaned config CRUD)
- Modify: `test/trenino/simulator_test.exs` (remove tests for deleted functions)
- Modify: `test/test_helper.exs`

- [ ] **Step 1: Find every reference to `Trenino.Simulator.AutoConfig`**

Run: `grep -rn "AutoConfig" lib test config | grep -v "auto_config.ex"`
Note all results; you'll need to update or delete each.

- [ ] **Step 2: Find every reference to `Trenino.Simulator.Config`**

Run: `grep -rn "Trenino.Simulator.Config\|alias.*Simulator.Config\|simulator_configs\|SimulatorConfig" lib test config | grep -v "_test.exs"`
Note all results.

- [ ] **Step 3: Delete the source files**

```bash
git rm lib/trenino/simulator/auto_config.ex
git rm lib/trenino/simulator/config.ex
git rm lib/trenino_web/live/simulator_config_live.ex
git rm test/trenino_web/live/simulator_config_live_test.exs
```

- [ ] **Step 4: Remove `AutoConfig` from `Mimic.copy` in `test/test_helper.exs`**

Delete the line:

```elixir
Mimic.copy(Trenino.Simulator.AutoConfig)
```

- [ ] **Step 5: Update `lib/trenino/simulator.ex`**

`Trenino.Simulator` currently exposes config CRUD (`get_config/0`, `create_config/1`, `save_config/1`, etc.) plus connection-status helpers. Remove every config-CRUD function (anything that touches `Config` schema), keeping only:
- `get_status/0`
- `subscribe/0`
- `windows?/0` (delegates to `Settings.Simulator.windows?/0`)
- Anything else NOT touching the `Config` schema

The `Config` alias and `import Ecto.Query` can be removed.

- [ ] **Step 6: Update `test/trenino/simulator_test.exs`**

Remove every test under `describe "get_config/0"`, `describe "create_config/1"`, `describe "save_config/1"`, and any other describe block that references the deleted CRUD functions. Keep tests for `get_status/0`, `subscribe/0`, and `windows?/0`. Remove the `alias Trenino.Simulator.Config` line.

- [ ] **Step 7: Remove the old route and add a redirect controller**

In `lib/trenino_web/router.ex`, inside the `:default` live_session, delete this line:

```elixir
      live "/simulator/config", SimulatorConfigLive
```

Create `lib/trenino_web/controllers/redirect_controller.ex`:

```elixir
defmodule TreninoWeb.RedirectController do
  use TreninoWeb, :controller

  def simulator_config(conn, _params) do
    redirect(conn, to: "/settings")
  end
end
```

In `lib/trenino_web/router.ex`, add a route for the redirect inside the existing `scope "/", TreninoWeb` block, BEFORE the `live_session :default` declaration:

```elixir
  scope "/", TreninoWeb do
    pipe_through :browser

    get "/simulator/config", RedirectController, :simulator_config

    live_session :consent, layout: {TreninoWeb.Layouts, :root} do
      live "/consent", ConsentLive
    end

    live_session :default,
      on_mount: [
        TreninoWeb.ConsentGateHook,
        {TreninoWeb.NavHook, :default},
        {TreninoWeb.MCPDetectionHook, :default}
      ],
      layout: {TreninoWeb.Layouts, :app} do
      live "/", ConfigurationListLive
      live "/configurations/:config_id", ConfigurationEditLive
      live "/trains", TrainListLive
      live "/trains/:train_id", TrainEditLive
      live "/trains/:train_id/scripts/new", ScriptEditLive
      live "/trains/:train_id/scripts/:script_id", ScriptEditLive
      live "/firmware", FirmwareLive
      live "/settings", SettingsLive
    end
  end
```

(Note: route precedence in Phoenix is declaration order — the `get` line declared first wins over a `live` line in another `live_session`.)

- [ ] **Step 8: Update any other references to deleted modules**

Run: `grep -rn "SimulatorConfig\|Trenino.Simulator.AutoConfig\|Trenino.Simulator.Config" lib test`
Replace any remaining references. Likely candidates:

- `test/trenino/integration/` may stub `AutoConfig` — replace with stubbing `Trenino.Settings.Simulator` (Mimic the new module instead) and add `Mimic.copy(Trenino.Settings.Simulator)` in `test/test_helper.exs`.
- LiveView tests that navigate to `/simulator/config` should navigate to `/settings`.

- [ ] **Step 9: Compile**

Run: `mix compile --warnings-as-errors`
Expected: compiles cleanly.

- [ ] **Step 10: Run the full test suite**

Run: `mix test`
Expected: all tests pass (allow for the same pre-existing flake from baseline).

- [ ] **Step 11: Commit**

```bash
git add -A lib/trenino lib/trenino_web test config
git commit -m "refactor(simulator): replace AutoConfig with Settings-based reads"
```

This is the bundled commit covering Tasks 11–13.

---

## Task 14: Data migration — port `simulator_configs` into `app_settings`, drop table

**Files:**
- Create: `priv/repo/migrations/<NEW_TS>_migrate_simulator_configs_to_app_settings.exs`

- [ ] **Step 1: Generate the migration**

Run: `mix ecto.gen.migration migrate_simulator_configs_to_app_settings`

- [ ] **Step 2: Replace contents**

```elixir
defmodule Trenino.Repo.Migrations.MigrateSimulatorConfigsToAppSettings do
  use Ecto.Migration

  import Ecto.Query

  def up do
    flush()

    repo = repo()

    rows =
      repo.all(
        from c in "simulator_configs",
          select: %{
            url: c.url,
            api_key: c.api_key,
            auto_detected: c.auto_detected
          }
      )

    Enum.each(rows, fn row ->
      if row.auto_detected == false do
        upsert(repo, "simulator_url", row.url)
        upsert(repo, "simulator_api_key", row.api_key)
      end
    end)

    drop table(:simulator_configs)
  end

  def down do
    create table(:simulator_configs) do
      add :url, :string, null: false
      add :api_key, :string, null: false
      add :auto_detected, :boolean, default: false, null: false
      timestamps(type: :utc_datetime)
    end
  end

  defp upsert(repo, key, value) when is_binary(value) and value != "" do
    repo.insert_all(
      "app_settings",
      [%{key: key, value: value}],
      on_conflict: {:replace, [:value]},
      conflict_target: :key
    )
  end

  defp upsert(_repo, _key, _value), do: :ok
end
```

`flush()` ensures any preceding migrations have committed before we start reading.

- [ ] **Step 3: Run the migration**

Run: `mix ecto.migrate`
Expected: `[info] drop table simulator_configs` plus a `change/0` info line.

- [ ] **Step 4: Sanity test the migration**

Run: `mix test`
Expected: all tests pass. The test database starts clean each run; no need for migration-specific tests.

- [ ] **Step 5: Commit**

```bash
git add priv/repo/migrations
git commit -m "feat(settings): migrate simulator_configs into app_settings and drop table"
```

---

## Task 15: Linking from Settings to `/consent` (revisit)

**Files:**
- Modify: `lib/trenino_web/live/settings_live.ex`
- Modify: `test/trenino_web/live/settings_live_test.exs`

- [ ] **Step 1: Write a failing test**

Append inside the existing `describe "mount/3"` block in `SettingsLiveTest`:

```elixir
    test "shows a link to revisit the consent screen", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")
      assert html =~ ~s(href="/consent")
    end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/trenino_web/live/settings_live_test.exs`
Expected: FAIL — no `/consent` link rendered yet.

- [ ] **Step 3: Add a link inside the Error Reporting section in `SettingsLive.render/1`**

Below the toggle row, inside the same `<div>`, add:

```elixir
              <div class="mt-3">
                <.link navigate={~p"/consent"} class="text-sm link link-primary">
                  Review consent details
                </.link>
              </div>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `mix test test/trenino_web/live/settings_live_test.exs`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/trenino_web/live/settings_live.ex test/trenino_web/live/settings_live_test.exs
git commit -m "feat(settings): link to consent screen for revisits"
```

---

## Task 16: Final verification & precommit

- [ ] **Step 1: Run full test suite**

Run: `mix test`
Expected: 0 failures (allow for the pre-existing flaky `ScriptRunnerTest` if it appears — re-run only that file in isolation to confirm it's the same flake).

- [ ] **Step 2: Run precommit alias**

Run: `mix precommit`
Expected: credo strict + tests both green.

- [ ] **Step 3: Manual smoke test**

Run: `mix phx.server` and walk through these flows in a browser:

1. Fresh start (delete `trenino_dev.db` if it has settings) → app redirects to `/consent`.
2. Click "No thanks" → redirected to `/`. Confirm `Settings.error_reporting?()` returns `false` via `iex -S mix phx.server`.
3. Navigate to `/settings`, toggle error reporting ON → `Settings.error_reporting?()` returns `true` immediately.
4. Click "Review consent details" → `/consent` loads with the same card.
5. Edit simulator URL, save → confirm value persists across reloads.

- [ ] **Step 4: Commit any precommit fixups**

If credo or formatter required changes:

```bash
git add -A
git commit -m "chore: precommit fixups"
```

---

## Self-Review Notes

This plan implements every section of the spec:

- **Section 1 (Data layer)** — Tasks 1, 2, 3, 9, 10
- **Section 2 (Consent gate)** — Tasks 5, 6
- **Section 3 (Sentry integration)** — Task 4
- **Section 4 (Settings page)** — Tasks 7, 8, 11, 12, 13
- **Section 5 (Data migration)** — Task 14
- **Section 6 (UI)** — Tasks 6, 7, 12 (covers both screens)
- **Out-of-scope items** are intentionally not implemented.

Type/name consistency checked: `Settings.error_reporting?/0`, `error_reporting_set?/0`, `set_error_reporting/1`, `simulator_url/0`, `set_simulator_url/1`, `api_key/0`, `set_api_key/1`, `sentry_before_send/1` — used consistently throughout.
