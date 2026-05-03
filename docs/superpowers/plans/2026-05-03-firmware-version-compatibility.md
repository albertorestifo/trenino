# Firmware Version Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an app-side semver requirement so the Trenino app refuses to flash firmware releases outside the supported version range, surfacing incompatible releases as visibly-blocked entries in the UI.

**Architecture:** A single config key `:firmware_version_requirement` (a `Version.Requirement` string) is the source of truth. A new `Trenino.Firmware.Compatibility` module wraps `Version.match?/2` and provides `compatible?/1` plus a `latest_compatible_release/0` helper. `UpdateChecker` only notifies for compatible releases; the firmware LiveView shows incompatible releases with a badge and disabled install button.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto, Elixir's built-in `Version` module.

**Spec:** `docs/superpowers/specs/2026-05-03-firmware-version-compatibility-design.md`

---

## File Structure

**Create:**
- `lib/trenino/firmware/compatibility.ex` — pure functions: `requirement/0`, `compatible?/1`.
- `test/trenino/firmware/compatibility_test.exs` — unit tests for the new module.

**Modify:**
- `config/config.exs` — add `:firmware_version_requirement` key (set to `nil` by default; document the setting).
- `lib/trenino/firmware.ex` — add `get_latest_compatible_release/1`.
- `lib/trenino/firmware/update_checker.ex` — replace ad-hoc version comparison with `Compatibility` for the latest-compatible lookup; ensure incompatible versions never trigger notifications.
- `lib/trenino_web/live/firmware_live.ex` — render "Incompatible" badge and disable install button per release.
- `test/trenino/firmware/update_checker_test.exs` — extend with cases for incompatible-latest-release.

---

## Task 1: `Trenino.Firmware.Compatibility` module — TDD

**Files:**
- Create: `lib/trenino/firmware/compatibility.ex`
- Test: `test/trenino/firmware/compatibility_test.exs`

- [ ] **Step 1: Write the failing test file**

Create `test/trenino/firmware/compatibility_test.exs`:

```elixir
defmodule Trenino.Firmware.CompatibilityTest do
  use ExUnit.Case, async: false

  alias Trenino.Firmware.Compatibility
  alias Trenino.Firmware.FirmwareRelease

  setup do
    original = Application.get_env(:trenino, :firmware_version_requirement)

    on_exit(fn ->
      if is_nil(original) do
        Application.delete_env(:trenino, :firmware_version_requirement)
      else
        Application.put_env(:trenino, :firmware_version_requirement, original)
      end
    end)

    :ok
  end

  defp set_requirement(value) do
    if is_nil(value) do
      Application.delete_env(:trenino, :firmware_version_requirement)
    else
      Application.put_env(:trenino, :firmware_version_requirement, value)
    end
  end

  describe "requirement/0" do
    test "returns nil when unset" do
      set_requirement(nil)
      assert Compatibility.requirement() == nil
    end

    test "returns a parsed Version.Requirement when set" do
      set_requirement("~> 1.0")
      assert %Version.Requirement{} = Compatibility.requirement()
    end

    test "raises on invalid requirement string" do
      set_requirement("not a requirement")
      assert_raise Version.InvalidRequirementError, fn -> Compatibility.requirement() end
    end
  end

  describe "compatible?/1 with no requirement set" do
    setup do
      set_requirement(nil)
      :ok
    end

    test "returns true for any well-formed version" do
      assert Compatibility.compatible?("1.0.0")
      assert Compatibility.compatible?("99.0.0")
    end

    test "returns true for a release struct" do
      assert Compatibility.compatible?(%FirmwareRelease{version: "1.0.0"})
    end

    test "returns false for an unparseable version (still safer than installing junk)" do
      refute Compatibility.compatible?("not-a-version")
    end
  end

  describe "compatible?/1 with a range requirement" do
    setup do
      set_requirement(">= 1.0.0 and < 2.0.0")
      :ok
    end

    test "true for versions inside the range" do
      assert Compatibility.compatible?("1.0.0")
      assert Compatibility.compatible?("1.5.3")
      assert Compatibility.compatible?("1.99.99")
    end

    test "false for versions below the range" do
      refute Compatibility.compatible?("0.9.9")
    end

    test "false for versions at or above the upper bound" do
      refute Compatibility.compatible?("2.0.0")
      refute Compatibility.compatible?("3.1.0")
    end

    test "strips a leading 'v' from the version string" do
      assert Compatibility.compatible?("v1.2.3")
      refute Compatibility.compatible?("v2.0.0")
    end

    test "accepts a FirmwareRelease struct" do
      assert Compatibility.compatible?(%FirmwareRelease{version: "1.4.0"})
      refute Compatibility.compatible?(%FirmwareRelease{version: "2.0.0"})
    end

    test "false for unparseable version strings" do
      refute Compatibility.compatible?("garbage")
      refute Compatibility.compatible?("1.2")
      refute Compatibility.compatible?(nil)
    end

    test "false for a release whose version is nil" do
      refute Compatibility.compatible?(%FirmwareRelease{version: nil})
    end

    test "pre-releases do not match a plain range by default" do
      refute Compatibility.compatible?("1.5.0-rc1")
    end
  end

  describe "compatible?/1 with a tilde requirement" do
    setup do
      set_requirement("~> 1.2")
      :ok
    end

    test "matches versions in the same major" do
      assert Compatibility.compatible?("1.2.0")
      assert Compatibility.compatible?("1.99.0")
    end

    test "rejects versions in the next major" do
      refute Compatibility.compatible?("2.0.0")
    end
  end
end
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `mix test test/trenino/firmware/compatibility_test.exs`
Expected: FAIL with `Trenino.Firmware.Compatibility` undefined.

- [ ] **Step 3: Implement the module**

Create `lib/trenino/firmware/compatibility.ex`:

```elixir
defmodule Trenino.Firmware.Compatibility do
  @moduledoc """
  Decides whether a firmware release is compatible with the running app.

  Compatibility is determined by a single config key, parsed as an Elixir
  `Version.Requirement`:

      config :trenino, :firmware_version_requirement, "~> 1.0"

  When the key is unset (nil), all releases with a parseable semver
  version are considered compatible. Releases with malformed versions
  are always considered incompatible — we'd rather block a flash than
  silently install something we can't reason about.
  """

  alias Trenino.Firmware.FirmwareRelease

  @doc """
  Returns the parsed requirement, or `nil` if none is configured.

  Raises `Version.InvalidRequirementError` if the configured value is
  not a valid requirement string. Misconfiguration is a developer bug,
  not a user-facing error.
  """
  @spec requirement() :: Version.Requirement.t() | nil
  def requirement do
    case Application.get_env(:trenino, :firmware_version_requirement) do
      nil -> nil
      string when is_binary(string) -> Version.parse_requirement!(string)
    end
  end

  @doc """
  Returns true if the given release (or version string) satisfies the
  configured requirement.

  - `nil` requirement → compatible iff the version itself is parseable.
  - Unparseable version → false.
  - `nil` version → false.
  """
  @spec compatible?(FirmwareRelease.t() | String.t() | nil) :: boolean()
  def compatible?(%FirmwareRelease{version: version}), do: compatible?(version)
  def compatible?(nil), do: false

  def compatible?(version) when is_binary(version) do
    with {:ok, parsed} <- parse_version(version) do
      case requirement() do
        nil -> true
        req -> Version.match?(parsed, req)
      end
    else
      :error -> false
    end
  end

  defp parse_version("v" <> rest), do: parse_version(rest)
  defp parse_version(string), do: Version.parse(string)
end
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `mix test test/trenino/firmware/compatibility_test.exs`
Expected: PASS, all assertions green.

- [ ] **Step 5: Commit**

```bash
git add lib/trenino/firmware/compatibility.ex test/trenino/firmware/compatibility_test.exs
git commit -m "feat(firmware): add Compatibility module for version requirement checks"
```

---

## Task 2: Document the config key

**Files:**
- Modify: `config/config.exs`

- [ ] **Step 1: Add the config key with a documenting comment**

In `config/config.exs`, find the existing `config :trenino, ecto_repos: ...` block (top of the file, around line 10) and add a new block after it. Open the file, locate:

```elixir
config :trenino,
  ecto_repos: [Trenino.Repo],
  generators: [timestamp_type: :utc_datetime],
  enable_bldc_levers: false
```

Insert immediately after that block:

```elixir
# Semver requirement that incoming firmware releases must satisfy.
# Releases outside this range are shown but cannot be installed.
# nil = no restriction (any parseable version compatible). Set per
# release line, e.g. ">= 1.0.0 and < 2.0.0" before a breaking firmware
# version ships.
config :trenino, :firmware_version_requirement, nil
```

- [ ] **Step 2: Verify the app still boots**

Run: `mix compile --warnings-as-errors`
Expected: clean compile.

- [ ] **Step 3: Commit**

```bash
git add config/config.exs
git commit -m "feat(firmware): add :firmware_version_requirement config key"
```

---

## Task 3: `Firmware.get_latest_compatible_release/1` — TDD

**Files:**
- Modify: `lib/trenino/firmware.ex` (add new function, leave `get_latest_release/1` untouched)
- Test: `test/trenino/firmware_test.exs`

- [ ] **Step 1: Inspect the existing test file to follow its conventions**

Run: `head -40 test/trenino/firmware_test.exs`
Note the `use Trenino.DataCase` line and the `alias` block. New tests should follow the same setup.

- [ ] **Step 2: Write the failing test**

Append to `test/trenino/firmware_test.exs` (inside the top-level `describe`-using module, after existing describe blocks):

```elixir
  describe "get_latest_compatible_release/1" do
    setup do
      original = Application.get_env(:trenino, :firmware_version_requirement)

      on_exit(fn ->
        if is_nil(original) do
          Application.delete_env(:trenino, :firmware_version_requirement)
        else
          Application.put_env(:trenino, :firmware_version_requirement, original)
        end
      end)

      :ok
    end

    defp insert_release!(version, published_at) do
      {:ok, release} =
        Trenino.Firmware.create_release(%{
          version: version,
          tag_name: "v" <> version,
          published_at: published_at
        })

      release
    end

    test "returns the newest-published release matching the requirement" do
      Application.put_env(:trenino, :firmware_version_requirement, ">= 1.0.0 and < 2.0.0")

      _v0 = insert_release!("0.9.0", ~U[2025-01-01 00:00:00Z])
      v1 = insert_release!("1.5.0", ~U[2025-06-01 00:00:00Z])
      _v2 = insert_release!("2.0.0", ~U[2025-12-01 00:00:00Z])

      assert {:ok, found} = Trenino.Firmware.get_latest_compatible_release()
      assert found.id == v1.id
    end

    test "returns :not_found when no releases match" do
      Application.put_env(:trenino, :firmware_version_requirement, "~> 5.0")

      insert_release!("1.0.0", ~U[2025-01-01 00:00:00Z])
      insert_release!("2.0.0", ~U[2025-06-01 00:00:00Z])

      assert {:error, :not_found} = Trenino.Firmware.get_latest_compatible_release()
    end

    test "with no requirement set, returns the newest release" do
      Application.delete_env(:trenino, :firmware_version_requirement)

      _old = insert_release!("1.0.0", ~U[2025-01-01 00:00:00Z])
      newest = insert_release!("2.0.0", ~U[2025-06-01 00:00:00Z])

      assert {:ok, found} = Trenino.Firmware.get_latest_compatible_release()
      assert found.id == newest.id
    end

    test "skips a newer-but-incompatible release in favor of an older compatible one" do
      Application.put_env(:trenino, :firmware_version_requirement, "~> 1.0")

      compatible = insert_release!("1.5.0", ~U[2025-01-01 00:00:00Z])
      _incompatible = insert_release!("2.0.0", ~U[2025-06-01 00:00:00Z])

      assert {:ok, found} = Trenino.Firmware.get_latest_compatible_release()
      assert found.id == compatible.id
    end

    test "supports preload option" do
      Application.delete_env(:trenino, :firmware_version_requirement)

      insert_release!("1.0.0", ~U[2025-01-01 00:00:00Z])

      assert {:ok, release} =
               Trenino.Firmware.get_latest_compatible_release(preload: [:firmware_files])

      assert is_list(release.firmware_files)
    end
  end
```

- [ ] **Step 3: Run the test and confirm it fails**

Run: `mix test test/trenino/firmware_test.exs --only describe:"get_latest_compatible_release/1"`
Expected: FAIL with `function get_latest_compatible_release/0 undefined` (or `/1`).

- [ ] **Step 4: Implement the function**

In `lib/trenino/firmware.ex`, find the existing `get_latest_release/1` function (around line 113-124) and add this immediately after it:

```elixir
  @doc """
  Get the latest firmware release that satisfies the configured
  `:firmware_version_requirement`.

  Iterates from newest to oldest by `published_at` and returns the first
  release whose version matches. Returns `{:error, :not_found}` if no
  release matches (or none exist).
  """
  @spec get_latest_compatible_release(keyword()) ::
          {:ok, FirmwareRelease.t()} | {:error, :not_found}
  def get_latest_compatible_release(opts \\ []) do
    preloads = Keyword.get(opts, :preload, [])

    FirmwareRelease
    |> order_by([r], desc: r.published_at)
    |> Repo.all()
    |> Enum.find(&Trenino.Firmware.Compatibility.compatible?/1)
    |> case do
      nil -> {:error, :not_found}
      release -> {:ok, Repo.preload(release, preloads)}
    end
  end
```

- [ ] **Step 5: Run the new tests and confirm they pass**

Run: `mix test test/trenino/firmware_test.exs --only describe:"get_latest_compatible_release/1"`
Expected: PASS.

- [ ] **Step 6: Run the full firmware test file to make sure nothing regressed**

Run: `mix test test/trenino/firmware_test.exs`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/trenino/firmware.ex test/trenino/firmware_test.exs
git commit -m "feat(firmware): add get_latest_compatible_release/1"
```

---

## Task 4: `UpdateChecker` skips incompatible releases — TDD

The checker currently treats *the newest published release* as `latest_version`. We change it so the checker only ever broadcasts compatible versions. Incompatible releases are simply invisible to update notifications.

**Files:**
- Modify: `lib/trenino/firmware/update_checker.ex`
- Test: `test/trenino/firmware/update_checker_test.exs`

- [ ] **Step 1: Read the existing test setup to understand fixtures**

Run: `mix test test/trenino/firmware/update_checker_test.exs --only describe:"device-aware update notifications" --trace`
Expected: existing tests pass; note the test helpers (`start_update_checker`, fixture builders for connected devices). You will reuse them.

- [ ] **Step 2: Add a failing test for incompatible-newest behavior**

Open `test/trenino/firmware/update_checker_test.exs`. Locate the `describe "device-aware update notifications"` block and append this test inside it (after the existing tests in that block):

```elixir
    test "does not broadcast when newest release is incompatible with app" do
      original = Application.get_env(:trenino, :firmware_version_requirement)
      Application.put_env(:trenino, :firmware_version_requirement, "~> 1.0")

      on_exit(fn ->
        if is_nil(original) do
          Application.delete_env(:trenino, :firmware_version_requirement)
        else
          Application.put_env(:trenino, :firmware_version_requirement, original)
        end
      end)

      # Compatible older release + incompatible newest release
      {:ok, _old} =
        Firmware.create_release(%{
          version: "1.5.0",
          tag_name: "v1.5.0",
          published_at: ~U[2025-01-01 00:00:00Z]
        })

      {:ok, _new} =
        Firmware.create_release(%{
          version: "2.0.0",
          tag_name: "v2.0.0",
          published_at: ~U[2025-06-01 00:00:00Z]
        })

      :ok = UpdateChecker.subscribe()

      # Simulate a connected device on 1.0.0 — would otherwise trigger an update
      send_devices_updated([%{status: :connected, device_version: "1.0.0"}])

      # Trigger a check; the checker should pick "1.5.0" (compatible) as latest
      # rather than "2.0.0" (incompatible). Since 1.0.0 < 1.5.0, expect a
      # broadcast with version 1.5.0 — NOT 2.0.0.
      UpdateChecker.check_now()

      assert_receive {:firmware_update_available, "1.5.0"}, 1_000
      refute_receive {:firmware_update_available, "2.0.0"}, 200
    end
```

You'll also need a small `send_devices_updated/1` helper if it does not already exist in the test file. Check whether it does:

Run: `grep -n "send_devices_updated\|devices_updated" test/trenino/firmware/update_checker_test.exs`

If the helper does not exist, add it as a private function inside the test module (above the `describe` blocks, after the `start_update_checker/1` helper):

```elixir
  defp send_devices_updated(devices) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "device_updates",
      {:devices_updated, devices}
    )

    # Give the GenServer a tick to process the message
    Process.sleep(50)
  end
```

(If the existing tests already use a different mechanism to inject connected devices — e.g. by stubbing `Trenino.Serial.Connection` — follow that mechanism instead. Read the surrounding tests in the same describe block to match the convention.)

- [ ] **Step 3: Run the new test and confirm it fails**

Run: `mix test test/trenino/firmware/update_checker_test.exs:LINE` (replace `LINE` with the line number of the new test).
Expected: FAIL — checker currently broadcasts `2.0.0`, since it picks the absolute newest.

- [ ] **Step 4: Update `UpdateChecker` to use the compatible-latest lookup**

Open `lib/trenino/firmware/update_checker.ex`. Locate `handle_check_success/2` (around line 301):

```elixir
  defp handle_check_success(checked_at, new_releases) do
    # Get latest release to compare versions
    case Firmware.get_latest_release() do
      {:ok, latest_release} ->
        update_available = new_releases != []

        # Record check in database
        record_check(checked_at, update_available, latest_release.version, nil)

        {:ok, update_available, latest_release.version, checked_at}

      {:error, :not_found} ->
        # No releases in DB
        record_check(checked_at, false, nil, "No releases found")
        {:ok, false, nil, checked_at}
    end
  end
```

Replace it with:

```elixir
  defp handle_check_success(checked_at, new_releases) do
    # We only care about the latest *compatible* release — incompatible
    # releases are visible in the UI but never trigger update notifications.
    case Firmware.get_latest_compatible_release() do
      {:ok, latest_release} ->
        update_available = new_releases != []

        record_check(checked_at, update_available, latest_release.version, nil)

        {:ok, update_available, latest_release.version, checked_at}

      {:error, :not_found} ->
        record_check(checked_at, false, nil, "No compatible releases found")
        {:ok, false, nil, checked_at}
    end
  end
```

- [ ] **Step 5: Run the new test and confirm it passes**

Run: `mix test test/trenino/firmware/update_checker_test.exs:LINE`
Expected: PASS.

- [ ] **Step 6: Run the full update_checker test file to confirm no regressions**

Run: `mix test test/trenino/firmware/update_checker_test.exs`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/trenino/firmware/update_checker.ex test/trenino/firmware/update_checker_test.exs
git commit -m "feat(firmware): skip incompatible releases in update notifications"
```

---

## Task 5: UI — incompatible badge and disabled install button

**Files:**
- Modify: `lib/trenino_web/live/firmware_live.ex` — `release_card/1` component and `start_upload` handler.

This task is UI only and does not have a clean automated test (no `firmware_live_test.exs` exists in the project). We add a manual smoke verification step. The change is small and visual, with a defensive server-side guard to make the disabled button trustworthy.

- [ ] **Step 1: Add an `alias` for `Compatibility`**

In `lib/trenino_web/live/firmware_live.ex`, find the `alias Trenino.Firmware...` block near the top of the file. Add `Compatibility` to the existing aliases. For example, if you see:

```elixir
  alias Trenino.Firmware
  alias Trenino.Firmware.{DeviceRegistry, FirmwareFile}
```

Change to:

```elixir
  alias Trenino.Firmware
  alias Trenino.Firmware.{Compatibility, DeviceRegistry, FirmwareFile}
```

(If the existing alias style differs, match that style. Just ensure `Compatibility` is in scope.)

- [ ] **Step 2: Update `release_card/1` to compute and render compatibility**

Find `defp release_card(assigns) do` (around line 410). Replace the function body up through the `~H` opening with logic that computes compatibility:

```elixir
  defp release_card(assigns) do
    # Get device names for display
    device_names =
      assigns.release.firmware_files
      |> Enum.map(fn file ->
        case DeviceRegistry.get_device_config(file.environment) do
          {:ok, config} -> config.display_name
          {:error, :unknown_device} -> file.environment
        end
      end)
      |> Enum.sort()

    compatible? = Compatibility.compatible?(assigns.release)

    requirement_string =
      Application.get_env(:trenino, :firmware_version_requirement) || ""

    assigns =
      assigns
      |> assign(:board_names, device_names)
      |> assign(:compatible, compatible?)
      |> assign(:requirement_string, requirement_string)

    ~H"""
    <div class={[
      "border rounded-xl overflow-hidden",
      if(@is_latest,
        do: "border-2 border-primary/30 bg-base-200/80 shadow-lg shadow-primary/5 p-6",
        else: "border-base-300 bg-base-200/50 p-5"
      )
    ]}>
      <div class="flex items-start justify-between gap-4">
        <div>
          <div class="flex items-center gap-2 flex-wrap">
            <h3 class="font-medium">v{@release.version}</h3>
            <span class="badge badge-ghost badge-sm">{@release.tag_name}</span>
            <span :if={@is_latest} class="badge badge-success badge-sm">Latest</span>
            <span :if={not @compatible} class="badge badge-warning badge-sm">Incompatible</span>
          </div>
          <p :if={@release.published_at} class="text-xs text-base-content/60 mt-1">
            Released {Calendar.strftime(@release.published_at, "%B %d, %Y")}
          </p>
          <p class="text-xs text-base-content/50 mt-2">
            Supported boards: {Enum.join(@board_names, ", ")}
          </p>
          <p :if={not @compatible} class="text-xs text-warning mt-2">
            Requires app update — this firmware is outside the supported range
            <span :if={@requirement_string != ""}>({@requirement_string})</span>.
          </p>
        </div>
        <div class="flex gap-2 items-center shrink-0">
          <button
            phx-click="show_upload_modal"
            phx-value-release-id={@release.id}
            disabled={not @compatible}
            class={[
              "btn btn-sm",
              if(@is_latest, do: "btn-primary", else: "btn-outline"),
              if(not @compatible, do: "btn-disabled", else: "")
            ]}
          >
            <.icon name="hero-arrow-up-tray" class="w-4 h-4" /> Upload to Device
          </button>
          <a
            :if={@release.release_url}
            href={@release.release_url}
            target="_blank"
            class="btn btn-ghost btn-sm"
          >
            <.icon name="hero-arrow-top-right-on-square" class="w-3 h-3" />
          </a>
        </div>
      </div>
    </div>
    """
  end
```

- [ ] **Step 3: Server-side guard in `start_upload`**

Find the `handle_event("start_upload", _, socket)` clause (around line 208). Add a compatibility guard at the top of the `with` chain. Replace:

```elixir
  @impl true
  def handle_event("start_upload", _, socket) do
    port = socket.assigns.selected_port
    environment = socket.assigns.selected_environment
    release = socket.assigns.selected_release

    with {:ok, file} <- find_or_download_file(release, environment),
         {:ok, _upload_id} <- Firmware.start_upload(port, environment, file.id) do
      {:noreply, assign(socket, :upload_error, nil)}
    else
      {:error, :no_firmware_for_environment} ->
        {:noreply, assign(socket, :upload_error, "No firmware available for this device.")}

      {:error, reason} ->
        {:noreply, assign(socket, :upload_error, "Failed to start upload: #{inspect(reason)}")}
    end
  end
```

with:

```elixir
  @impl true
  def handle_event("start_upload", _, socket) do
    port = socket.assigns.selected_port
    environment = socket.assigns.selected_environment
    release = socket.assigns.selected_release

    with :ok <- check_compatible(release),
         {:ok, file} <- find_or_download_file(release, environment),
         {:ok, _upload_id} <- Firmware.start_upload(port, environment, file.id) do
      {:noreply, assign(socket, :upload_error, nil)}
    else
      {:error, :incompatible} ->
        {:noreply,
         assign(
           socket,
           :upload_error,
           "This firmware is not compatible with this version of the app."
         )}

      {:error, :no_firmware_for_environment} ->
        {:noreply, assign(socket, :upload_error, "No firmware available for this device.")}

      {:error, reason} ->
        {:noreply, assign(socket, :upload_error, "Failed to start upload: #{inspect(reason)}")}
    end
  end

  defp check_compatible(release) do
    if Compatibility.compatible?(release), do: :ok, else: {:error, :incompatible}
  end
```

- [ ] **Step 4: Compile clean**

Run: `mix compile --warnings-as-errors`
Expected: clean.

- [ ] **Step 5: Manual smoke test**

(LiveView tests for `firmware_live` do not exist in this project; they would require non-trivial fixture work outside the scope of this change. We verify visually instead.)

In one terminal:

```bash
MIX_ENV=dev mix phx.server
```

In another shell, set the requirement to something restrictive and seed two releases by running `iex -S mix`:

```elixir
Application.put_env(:trenino, :firmware_version_requirement, "~> 1.0")

Trenino.Firmware.create_release(%{
  version: "1.5.0",
  tag_name: "v1.5.0",
  published_at: ~U[2025-01-01 00:00:00Z]
})

Trenino.Firmware.create_release(%{
  version: "2.0.0",
  tag_name: "v2.0.0",
  published_at: ~U[2025-06-01 00:00:00Z]
})
```

Then visit `http://localhost:4000/firmware`. Expected:
- The 2.0.0 card shows an orange "Incompatible" badge and the explanation text.
- The 2.0.0 card's "Upload to Device" button is disabled.
- The 1.5.0 card has no badge and its button is enabled.

Stop the server when done. (No DB cleanup needed — the dev DB is fine to keep these rows.)

- [ ] **Step 6: Commit**

```bash
git add lib/trenino_web/live/firmware_live.ex
git commit -m "feat(firmware): badge incompatible releases and block install in UI"
```

---

## Task 6: Final verification

- [ ] **Step 1: Run the full test suite + credo**

Run: `mix precommit`
Expected: PASS. If credo flags any issue in the new module, fix it inline (e.g. adjust line length, alias ordering).

- [ ] **Step 2: Confirm the spec is fully satisfied**

Re-read `docs/superpowers/specs/2026-05-03-firmware-version-compatibility-design.md`. Tick off mentally:

- [x] Config key `:firmware_version_requirement` (Task 2)
- [x] `Compatibility` module with `compatible?/1` and `requirement/0` (Task 1)
- [x] `nil` requirement = everything compatible (Task 1 tests)
- [x] Malformed version → false (Task 1 tests)
- [x] `Firmware.get_latest_compatible_release/1` added; `get_latest_release/1` unchanged (Task 3)
- [x] `UpdateChecker` skips incompatible releases for notifications (Task 4)
- [x] UI: incompatible badge + disabled install button + explanation text (Task 5)
- [x] Server-side guard against installing incompatible firmware (Task 5)

If anything is missed, file a follow-up task here before declaring done.

- [ ] **Step 3: Final commit (if any cleanup happened)**

If `mix precommit` triggered any small fixes:

```bash
git add -u
git commit -m "chore(firmware): precommit fixes for compatibility feature"
```

Otherwise, nothing to commit.
