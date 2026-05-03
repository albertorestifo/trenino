# Test Suite Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the test suite fast (< 60s), flake-free, quiet, and incapable of touching real serial/avrdude hardware.

**Architecture:** Add Mimic-based forbidden default stubs that raise on any unstubbed call to `Circuits.UART` / `Avrdude` / `AvrdudeRunner` / `Serial.Discovery`. Wire defaults in three case templates (`DataCase`, `ConnCase`, new `SerialSafetyCase`) using Mimic's `:private` mode so async tests stay safe. Replace `Process.sleep(N)` race patterns with deterministic synchronization (PubSub subscriber handshake, Task await, configurable timeouts). Demote one expected error log.

**Tech Stack:** Elixir 1.19, Phoenix 1.8, Mimic 2.3 (already in deps), `Circuits.UART`, `Phoenix.PubSub`.

---

## File Structure

**New files:**
- `test/support/forbidden_serial.ex` — three stub modules (`Trenino.Test.ForbiddenUART`, `Trenino.Test.ForbiddenAvrdude`, `Trenino.Test.ForbiddenSerialDiscovery`) that raise on call.
- `test/support/serial_safety_case.ex` — `Trenino.SerialSafetyCase` template for plain-`ExUnit.Case` files that need the safety net but no DB sandbox.
- `test/support/pubsub_helpers.ex` — `Trenino.PubSubHelpers.wait_for_subscriber/2` deterministic wait helper.

**Modified files:**
- `test/support/data_case.ex` — wire forbidden stubs into setup; add `silently/1` capture helper.
- `test/support/conn_case.ex` — wire forbidden stubs into setup.
- `lib/trenino/firmware/device_registry.ex` — demote one `Logger.warning` → `Logger.info`.
- `test/trenino/mcp/tools/detection_tools_test.exs` — replace `Process.sleep(50)` with `wait_for_subscriber/2`.
- `test/trenino_web/live/configuration_list_live_test.exs` — fix 7 slow tests by stubbing the LiveView mount-time GenServer.call that's timing out at 5000ms (see Task 6).
- `test/trenino/train/lever_controller_bldc_test.exs` — fix 4 slow tests by waiting on actual signal.
- `test/trenino/integration/bldc_lever_flow_test.exs` — fix 3 slow tests by waiting on actual signal.
- `test/trenino/serial/connection_port_timeout_test.exs` — drive timeout via app config to halve wall-clock cost.

**Per-task additions:** any plain-`ExUnit.Case` test file that surfaces in Task 2 audit gets `use Trenino.SerialSafetyCase` (or `use Mimic` + per-test `expect/3`).

---

## Task 1: Add forbidden default stubs

**Files:**
- Create: `test/support/forbidden_serial.ex`

- [ ] **Step 1: Create the stub modules**

Write `test/support/forbidden_serial.ex`:

```elixir
defmodule Trenino.Test.ForbiddenUART do
  @moduledoc """
  Default Mimic stub for Circuits.UART. Every function raises with a clear
  message so tests that forget to stub real serial access fail loudly instead
  of touching real hardware.
  """

  def open(_pid, _port, _opts), do: forbid("Circuits.UART.open/3")
  def close(_pid), do: forbid("Circuits.UART.close/1")
  def write(_pid, _data), do: forbid("Circuits.UART.write/2")
  def read(_pid, _timeout), do: forbid("Circuits.UART.read/2")
  def enumerate, do: forbid("Circuits.UART.enumerate/0")
  def start_link, do: forbid("Circuits.UART.start_link/0")
  def start_link(_opts), do: forbid("Circuits.UART.start_link/1")
  def controlling_process(_pid, _new_owner), do: forbid("Circuits.UART.controlling_process/2")
  def configure(_pid, _opts), do: forbid("Circuits.UART.configure/2")
  def flush(_pid), do: forbid("Circuits.UART.flush/1")
  def flush(_pid, _direction), do: forbid("Circuits.UART.flush/2")

  defp forbid(call) do
    raise """
    Real #{call} was called from a test.

    Tests must not touch real serial hardware. Stub explicitly with Mimic:

        expect(Circuits.UART, :open, fn _pid, _port, _opts -> {:ok, self()} end)

    Or use a higher-level helper from Trenino.SerialTestHelpers.
    """
  end
end

defmodule Trenino.Test.ForbiddenAvrdude do
  @moduledoc """
  Default Mimic stub for Trenino.Firmware.Avrdude and AvrdudeRunner.
  Raises on any call so tests that forget to stub avrdude fail loudly
  instead of spawning real subprocesses.
  """

  # Trenino.Firmware.Avrdude surface
  def executable_path, do: forbid("Avrdude.executable_path/0")
  def executable_path!, do: forbid("Avrdude.executable_path!/0")
  def available?, do: forbid("Avrdude.available?/0")
  def version, do: forbid("Avrdude.version/0")
  def conf_path, do: forbid("Avrdude.conf_path/0")

  # Trenino.Firmware.AvrdudeRunner surface
  def run(_avrdude_path, _args, _progress_callback),
    do: forbid("AvrdudeRunner.run/3")

  defp forbid(call) do
    raise """
    Real #{call} was called from a test.

    Tests must not spawn real avrdude subprocesses. Stub explicitly:

        expect(Trenino.Firmware.AvrdudeRunner, :run, fn _, _, _ -> {:ok, "ok"} end)
    """
  end
end

defmodule Trenino.Test.ForbiddenSerialDiscovery do
  @moduledoc """
  Default Mimic stub for Trenino.Serial.Discovery. Raises on any call.
  """

  def discover(_uart_pid, _opts), do: forbid("Trenino.Serial.Discovery.discover/2")

  defp forbid(call) do
    raise """
    Real #{call} was called from a test.

    Tests must not perform real device discovery. Stub explicitly:

        expect(Trenino.Serial.Discovery, :discover, fn _pid, _opts ->
          {:ok, %Trenino.Serial.Protocol.IdentityResponse{...}}
        end)
    """
  end
end
```

- [ ] **Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: clean compile.

- [ ] **Step 3: Verify the stub function arities match the real modules**

Run:
```bash
mix run -e '
  for {real, fake} <- [
    {Circuits.UART, Trenino.Test.ForbiddenUART},
    {Trenino.Firmware.Avrdude, Trenino.Test.ForbiddenAvrdude},
    {Trenino.Firmware.AvrdudeRunner, Trenino.Test.ForbiddenAvrdude},
    {Trenino.Serial.Discovery, Trenino.Test.ForbiddenSerialDiscovery}
  ] do
    real_funs = real.__info__(:functions) |> Enum.filter(fn {n, _} -> not String.starts_with?(Atom.to_string(n), "_") end) |> MapSet.new()
    fake_funs = fake.__info__(:functions) |> MapSet.new()
    missing = MapSet.difference(real_funs, fake_funs)
    if MapSet.size(missing) > 0 do
      IO.puts("MISSING in #{inspect(fake)}: #{inspect(MapSet.to_list(missing))}")
    end
  end
'
```
Expected: no `MISSING` lines for `Circuits.UART`, `Trenino.Firmware.AvrdudeRunner`, `Trenino.Serial.Discovery`. For `Trenino.Firmware.Avrdude`, only the public functions documented in the spec need to be stubbed; if `MISSING` lists any extra public functions, add them to `ForbiddenAvrdude`.

If anything is missing, add it to the appropriate stub module and re-run.

- [ ] **Step 4: Commit**

```bash
git add test/support/forbidden_serial.ex
git commit -m "test: add forbidden default Mimic stubs for serial/avrdude

Three modules — ForbiddenUART, ForbiddenAvrdude, ForbiddenSerialDiscovery —
that raise loudly on any call. Wired up in case templates in next commit;
this commit is the inert addition.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Wire forbidden stubs into DataCase and ConnCase

**Files:**
- Modify: `test/support/data_case.ex`
- Modify: `test/support/conn_case.ex`

- [ ] **Step 1: Update DataCase**

In `test/support/data_case.ex`, replace the existing `setup tags do` block with:

```elixir
  setup tags do
    Trenino.DataCase.setup_sandbox(tags)
    Trenino.DataCase.setup_forbidden_serial_stubs()
    :ok
  end

  @doc """
  Installs default Mimic stubs that forbid real serial / avrdude / discovery
  access. Tests that legitimately need to simulate one of these subsystems
  override the default with `Mimic.expect/3` or `Mimic.stub/3`.
  """
  def setup_forbidden_serial_stubs do
    Mimic.set_mimic_private(self())
    Mimic.stub_with(Circuits.UART, Trenino.Test.ForbiddenUART)
    Mimic.stub_with(Trenino.Firmware.Avrdude, Trenino.Test.ForbiddenAvrdude)
    Mimic.stub_with(Trenino.Firmware.AvrdudeRunner, Trenino.Test.ForbiddenAvrdude)
    Mimic.stub_with(Trenino.Serial.Discovery, Trenino.Test.ForbiddenSerialDiscovery)
    :ok
  end
```

Inside the `using do … quote do` block, add `use Mimic` so test modules importing `DataCase` get Mimic's helpers automatically:

```elixir
  using do
    quote do
      alias Trenino.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Trenino.DataCase

      use Mimic
    end
  end
```

- [ ] **Step 2: Update ConnCase**

In `test/support/conn_case.ex`, replace the `setup tags do` block with:

```elixir
  setup tags do
    Trenino.DataCase.setup_sandbox(tags)
    Trenino.DataCase.setup_forbidden_serial_stubs()
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
```

Inside the `using do` block, add `use Mimic`:

```elixir
  using do
    quote do
      @endpoint TreninoWeb.Endpoint

      use TreninoWeb, :verified_routes
      use Mimic

      import Plug.Conn
      import Phoenix.ConnTest
      import TreninoWeb.ConnCase
    end
  end
```

- [ ] **Step 3: Run a small sample to confirm wiring works**

Run: `mix test test/trenino/firmware/uploader_test.exs --max-failures 5`
Expected: passes (existing test already uses Mimic and should override the forbidden defaults).

- [ ] **Step 4: Run the full suite, capture failures from forbidden stubs firing**

Run: `mix test 2>&1 | tee /tmp/forbidden-audit.log`
Expected: many failures with `"Real Circuits.UART.* was called from a test"` or `"Real Avrdude.* was called from a test"`. **This is success** — every such failure is a real safety bug we are now catching.

Save the list of failing files for Task 3:
```bash
grep -B1 'Real Circuits\.UART\|Real Avrdude\|Real Trenino\.Serial\.Discovery' /tmp/forbidden-audit.log | grep -oE 'test/[^:]*\.exs' | sort -u > /tmp/forbidden-files.txt
cat /tmp/forbidden-files.txt
```

- [ ] **Step 5: Commit (red, on purpose)**

```bash
git add test/support/data_case.ex test/support/conn_case.ex
git commit -m "test: wire forbidden serial stubs into DataCase and ConnCase

Every DataCase / ConnCase test now starts with default Mimic stubs that
raise on any real Circuits.UART / Avrdude / Serial.Discovery call. Tests
that need real-looking behavior must stub explicitly. Failing tests
surface in the next commit's fix sweep.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Add SerialSafetyCase and fix surfaced failures

**Files:**
- Create: `test/support/serial_safety_case.ex`
- Modify: each file in `/tmp/forbidden-files.txt` from Task 2 Step 4

- [ ] **Step 1: Create SerialSafetyCase template**

Write `test/support/serial_safety_case.ex`:

```elixir
defmodule Trenino.SerialSafetyCase do
  @moduledoc """
  Test case template for plain ExUnit.Case files that exercise serial /
  avrdude / discovery code paths but do not need the database sandbox.

  Installs the same forbidden default Mimic stubs as DataCase so accidental
  hardware access raises loudly.
  """

  use ExUnit.CaseTemplate

  using opts do
    async = Keyword.get(opts, :async, true)

    quote do
      use ExUnit.Case, async: unquote(async)
      use Mimic
    end
  end

  setup do
    Trenino.DataCase.setup_forbidden_serial_stubs()
    :ok
  end
end
```

- [ ] **Step 2: For each file in `/tmp/forbidden-files.txt`, decide and apply**

For each file, the fix is one of:

**A. The test never legitimately needs UART** — convert `use ExUnit.Case` → `use Trenino.SerialSafetyCase`. The test now inherits the forbidden defaults. If the test was already correct, no further change.

**B. The test legitimately calls UART code** (e.g. exercises a function that internally calls `Circuits.UART.enumerate`) — add per-test `Mimic.expect/3` or `Mimic.stub/3` overrides. Example:

```elixir
test "scan returns empty list when no devices" do
  Mimic.expect(Circuits.UART, :enumerate, fn -> %{} end)

  assert [] = Trenino.Serial.Connection.scan()
end
```

**C. The test was already using DataCase/ConnCase but spawned a process** (e.g. `Task.async`) **that hit the forbidden stub** — use `Mimic.set_mimic_global` for that test (`@tag :async_false_required`) or use `Mimic.allow/3` to grant the spawned process access to the parent's stubs:

```elixir
test "task scenario" do
  parent = self()
  Mimic.expect(Circuits.UART, :enumerate, fn -> %{} end)

  task = Task.async(fn ->
    Mimic.allow(Circuits.UART, parent, self())
    Trenino.Serial.Connection.scan()
  end)

  assert [] = Task.await(task)
end
```

- [ ] **Step 3: Re-run the suite until green**

Run: `mix test`
Expected: all tests pass. If any forbidden-stub failures remain, repeat Step 2 for those files.

- [ ] **Step 4: Verify safety net still active**

Run a quick sanity check:
```bash
mix run -e '
  IO.inspect(Trenino.Test.ForbiddenUART.enumerate())
' 2>&1 | head -3
```
This should fail with the forbidden-call message (proving the stub module is loaded and ready, not that the suite uses it; the suite uses it via Mimic).

- [ ] **Step 5: Commit**

```bash
git add -A test/
git commit -m "test: add SerialSafetyCase and fix tests caught by forbidden stubs

Every test now passes through forbidden defaults; cases that exercised
real serial/avrdude paths now have explicit Mimic expectations or
inherit SerialSafetyCase.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: PubSub subscriber wait helper

**Files:**
- Create: `test/support/pubsub_helpers.ex`

- [ ] **Step 1: Verify how Phoenix.PubSub tracks subscribers**

Run:
```bash
mix run -e '
  Phoenix.PubSub.subscribe(Trenino.PubSub, "test:topic")
  IO.inspect(Registry.lookup(Trenino.PubSub, "test:topic"))
'
```

Expected: a non-empty list of `{pid, value}` tuples. If empty, the local registry has a different name. Inspect `Phoenix.PubSub` adapter config in `lib/trenino/application.ex:21` and find the actual registry name. Common alternatives: `Trenino.PubSub.Local`, `Trenino.PubSub.Adapter`. Adjust the helper in Step 2 accordingly.

- [ ] **Step 2: Write the helper**

Write `test/support/pubsub_helpers.ex`:

```elixir
defmodule Trenino.PubSubHelpers do
  @moduledoc """
  Test-only helpers for synchronizing on Phoenix.PubSub state.

  Replaces `Process.sleep/1`-based race patterns where a test broadcasts
  to a topic and assumes a freshly-spawned subscriber is ready in time.
  """

  @doc """
  Block until at least one process is subscribed to `topic`, or the timeout
  expires.

  Returns `:ok` on success or `{:error, :timeout}`.

  ## Example

      task = Task.async(fn -> SomeGenServer.subscribe_and_wait() end)
      :ok = wait_for_subscriber("hardware:input_values:test_port")
      Phoenix.PubSub.broadcast(Trenino.PubSub, "hardware:input_values:test_port", :event)
      assert {:ok, _} = Task.await(task, 1_000)
  """
  @spec wait_for_subscriber(String.t(), pos_integer()) :: :ok | {:error, :timeout}
  def wait_for_subscriber(topic, timeout_ms \\ 1_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait(topic, deadline)
  end

  defp do_wait(topic, deadline) do
    if has_subscriber?(topic) do
      :ok
    else
      if System.monotonic_time(:millisecond) > deadline do
        {:error, :timeout}
      else
        Process.sleep(5)
        do_wait(topic, deadline)
      end
    end
  end

  defp has_subscriber?(topic) do
    case Registry.lookup(Trenino.PubSub, topic) do
      [] -> false
      [_ | _] -> true
    end
  end
end
```

If Step 1 found a different registry name, replace `Trenino.PubSub` in the `Registry.lookup/2` call accordingly.

- [ ] **Step 3: Smoke test the helper**

Run:
```bash
mix run -e '
  spawn(fn ->
    Phoenix.PubSub.subscribe(Trenino.PubSub, "smoke:test")
    Process.sleep(:infinity)
  end)
  Process.sleep(20)
  IO.inspect(Trenino.PubSubHelpers.wait_for_subscriber("smoke:test", 500))
'
```
Expected: `:ok`.

Also verify timeout path:
```bash
mix run -e 'IO.inspect(Trenino.PubSubHelpers.wait_for_subscriber("nonexistent:topic", 100))'
```
Expected: `{:error, :timeout}`.

- [ ] **Step 4: Commit**

```bash
git add test/support/pubsub_helpers.ex
git commit -m "test: add wait_for_subscriber/2 PubSub sync helper

Replaces Process.sleep-based race patterns in tests that broadcast
to a topic and assume a freshly-spawned subscriber is ready.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Fix detection-tools flake

**Files:**
- Modify: `test/trenino/mcp/tools/detection_tools_test.exs`

- [ ] **Step 1: Reproduce the flake**

Run:
```bash
for i in 1 2 3 4 5; do mix test 2>&1 | tail -3; done
```
Expected: at least one of the 5 runs shows failures in `Trenino.MCP.Tools.DetectionToolsTest`. This confirms the flake before we fix it.

- [ ] **Step 2: Add helper import to the test file**

In `test/trenino/mcp/tools/detection_tools_test.exs`, add after the existing `alias` lines (around line 6):

```elixir
  import Trenino.PubSubHelpers, only: [wait_for_subscriber: 1]
```

- [ ] **Step 3: Replace the `Process.sleep(50)` calls**

`InputDetectionSession` subscribes to `"hardware:input_values:test_port"` (see `lib/trenino/hardware/input_detection_session.ex:237`). Find every `Process.sleep(50)` in `detection_tools_test.exs` (lines 57, 83, 157 per the audit) and replace with:

```elixir
      :ok = wait_for_subscriber("hardware:input_values:#{@test_port}")
```

For each affected test, also tighten the `Task.await` timeout from 2000–3000ms down to 1000ms — the wait is now deterministic and any timeout indicates a real bug, not a race.

- [ ] **Step 4: Run the test file 20× to confirm zero flakes**

Run:
```bash
for i in $(seq 1 20); do
  mix test test/trenino/mcp/tools/detection_tools_test.exs 2>&1 | tail -1
done
```
Expected: 20 lines, all `0 failures`.

- [ ] **Step 5: Run the full suite to confirm no regressions**

Run: `mix test`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add test/trenino/mcp/tools/detection_tools_test.exs
git commit -m "test: replace detection-tools sleep-races with deterministic sync

Test broadcast no longer assumes the GenServer subscribed within 50ms
of Task.async; instead waits for the subscriber to register on the
PubSub topic (typically ~5ms) before broadcasting.

Eliminates 12 flaky failures observed under full-suite load.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Speed up configuration_list_live tests

**Files:**
- Modify: `test/trenino_web/live/configuration_list_live_test.exs`

These 7 tests cost ~35s. Pattern: `live(conn, ~p"/")` mounts a LiveView whose nav-hook calls `Trenino.Serial.Connection.scan/0` (or related), which is a `GenServer.call` to the connection process. Without a Mimic stub on `Circuits.UART.enumerate`, the GenServer either times out (5s) or blocks until something completes.

- [ ] **Step 1: Reproduce and time the file**

Run:
```bash
mix test test/trenino_web/live/configuration_list_live_test.exs --slowest 10
```
Note the wall-clock time and the per-test timings.

- [ ] **Step 2: Identify the blocking call**

Inspect what the LiveView `mount/3` (and any `on_mount` hook in `lib/trenino_web/components/`) calls. Look for:
- `Trenino.Serial.Connection.scan/0` (GenServer.call with default 5000ms timeout)
- `Trenino.Serial.Connection.connected_devices/0` (similar)
- `Trenino.Simulator.Connection.get_status/0`

Run:
```bash
grep -rEn "Connection\.|Simulator\." lib/trenino_web/components/*.ex lib/trenino_web/live/configuration_list_live.ex | head -20
```

Whichever GenServer.call is blocking is the one to stub.

- [ ] **Step 3: Add an `on_mount`-level stub setup**

In `test/trenino_web/live/configuration_list_live_test.exs`, add a `setup` block (above `describe "basic rendering"`, after the existing `Sandbox.mode` setup) that stubs the relevant calls. Example for `Connection.scan`:

```elixir
  setup do
    # Stub serial enumeration so LiveView mount doesn't block on a 5s
    # GenServer.call timeout when no real devices are present.
    Mimic.stub(Circuits.UART, :enumerate, fn -> %{} end)

    # If the LiveView nav-hook calls Connection.scan via GenServer.call:
    Mimic.stub(Trenino.Serial.Connection, :scan, fn -> :ok end)
    Mimic.stub(Trenino.Serial.Connection, :connected_devices, fn -> [] end)

    :ok
  end
```

If `Trenino.Serial.Connection` is not yet in `Mimic.copy/1` (check `test/test_helper.exs`), add it. Verify by running the file again.

- [ ] **Step 4: Run and confirm speedup**

Run: `mix test test/trenino_web/live/configuration_list_live_test.exs --slowest 10`
Expected: total wall-clock drops from ~5s/test to <500ms/test. File should complete in under 5s total.

- [ ] **Step 5: Run full suite to verify no regressions**

Run: `mix test`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add test/trenino_web/live/configuration_list_live_test.exs
git commit -m "test: stub serial calls in configuration_list_live_test

Mount-time GenServer.call to Connection.scan was timing out at 5000ms
per test (no real devices present). Stubbing Connection at the test
boundary cuts ~30s off this file alone.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Speed up BLDC controller tests

**Files:**
- Modify: `test/trenino/train/lever_controller_bldc_test.exs`
- Modify: `test/trenino/integration/bldc_lever_flow_test.exs`

7 tests across these two files cost ~35s. Pattern: a `Process.sleep(5_000)` waits for "BLDC profile to load" (an async Task spawned by the lever controller).

- [ ] **Step 1: Identify the actual signal**

Run:
```bash
grep -nE "Process\.sleep\(5_?000|profile.*load|broadcast.*profile" test/trenino/train/lever_controller_bldc_test.exs test/trenino/integration/bldc_lever_flow_test.exs lib/trenino/train/lever_controller.ex 2>/dev/null
```

Find what topic / message the `LeverController` broadcasts when the profile finishes loading. Likely candidates:
- A `Phoenix.PubSub.broadcast` to `"train:lever_profile:#{train_id}"` with `{:profile_loaded, ...}`.
- A direct `send(parent_pid, ...)`.
- A state change observable via `:sys.get_state/1`.

- [ ] **Step 2: Replace each `Process.sleep(5_000)` with the actual wait**

If the controller broadcasts to a PubSub topic, in each test:

```elixir
# Before:
# Process.sleep(5_000)

# After (PubSub case):
Phoenix.PubSub.subscribe(Trenino.PubSub, "train:lever_profile:#{train_id}")
# … trigger the action that loads the profile …
assert_receive {:profile_loaded, _profile}, 1_000
```

Or, if the load is wrapped in a `Task` that the test can `await` directly, do that instead.

- [ ] **Step 3: Run each file independently**

```bash
mix test test/trenino/train/lever_controller_bldc_test.exs --slowest 10
mix test test/trenino/integration/bldc_lever_flow_test.exs --slowest 10
```
Expected: per-test cost drops from 5000ms to <500ms.

- [ ] **Step 4: Run full suite to verify no regressions**

Run: `mix test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add test/trenino/train/lever_controller_bldc_test.exs test/trenino/integration/bldc_lever_flow_test.exs
git commit -m "test: replace 5s sleeps with PubSub assertions in BLDC tests

Was waiting a fixed 5s for an async profile load; now subscribes to the
actual broadcast topic and asserts within 1s.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Speed up connection_port_timeout tests

**Files:**
- Modify: `test/trenino/serial/connection_port_timeout_test.exs`
- Possibly modify: `lib/trenino/serial/connection.ex` (only if the timeout is hard-coded; adding `Application.get_env` is fine)

2 tests cost 12.6s, intentionally simulating a slow GenServer. We can keep the test intent (cover the timeout path) while halving wall-clock time by making the timeout configurable.

- [ ] **Step 1: Read the test and identify the hard-coded timeout**

Run:
```bash
sed -n '1,200p' test/trenino/serial/connection_port_timeout_test.exs
```
Find where the test simulates a slow operation (likely `Process.sleep(5_500)` or similar) and what timeout it's asserting fires.

- [ ] **Step 2: Make the production timeout config-driven**

In `lib/trenino/serial/connection.ex`, find the relevant `GenServer.call` timeout (probably 5000ms). Replace with:

```elixir
@default_call_timeout_ms 5_000

defp call_timeout do
  Application.get_env(:trenino, :serial_connection_call_timeout_ms, @default_call_timeout_ms)
end
```

And use `call_timeout()` at the call site. Add `:serial_connection_call_timeout_ms` to `config/test.exs` set to `500`.

- [ ] **Step 3: Halve the simulated delay in the test**

Update the test's simulated sleep to match (e.g. `Process.sleep(600)` instead of `Process.sleep(5_500)`).

- [ ] **Step 4: Run the file**

Run: `mix test test/trenino/serial/connection_port_timeout_test.exs --slowest 5`
Expected: total under 2s.

- [ ] **Step 5: Run full suite**

Run: `mix test`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add test/trenino/serial/connection_port_timeout_test.exs lib/trenino/serial/connection.ex config/test.exs
git commit -m "test: make serial connection call timeout config-driven

Connection.call timeout is now Application-configurable; test env uses
500ms instead of 5000ms, halving the wall-clock cost of the timeout
regression tests without changing what they cover.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Output hygiene — demote startup error log

**Files:**
- Modify: `lib/trenino/firmware/device_registry.ex`

- [ ] **Step 1: Find and demote the manifest-fallback log**

In `lib/trenino/firmware/device_registry.ex`, find the line that emits `"No firmware release manifest available..."` (around lines 212–218). Confirm it's the one emitted on a fresh install / empty database (an expected fallback, not an error).

Change `Logger.warning(` → `Logger.info(` at that call site only. Do not touch other warnings in the same file unless they're similarly expected-fallback logs.

- [ ] **Step 2: Verify clean test output**

Run: `mix test 2>&1 | grep -E "^\\[(error|warning)\\]"`
Expected: zero matches. (If matches remain, the `silently/1` step in Task 10 will cover them.)

- [ ] **Step 3: Confirm tests still pass**

Run: `mix test`
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add lib/trenino/firmware/device_registry.ex
git commit -m "fix: demote 'no manifest' startup log from warning to info

The 'no firmware release manifest available' log fires on every fresh
install (and every test run) before a manifest is fetched. It's the
expected fallback path, not an error condition.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Output hygiene — silently/1 helper for intentional warning paths

**Files:**
- Modify: `test/support/data_case.ex`
- Possibly modify: any test file whose intentional-error paths still leak `Logger.warning` lines

- [ ] **Step 1: Add the helper**

In `test/support/data_case.ex`, add to the `using do` quote:

```elixir
      import Trenino.DataCase, only: [errors_on: 1, silently: 1]
```

(Or extend the existing import if there is one.)

And add the function definition next to `errors_on/1`:

```elixir
  @doc """
  Captures Logger output during the given function. Use to wrap calls
  in tests that intentionally exercise error/cleanup paths and would
  otherwise leak [warning]/[error] lines into the test output.

      silently(fn -> Connection.handle_decode_failure(garbage) end)
  """
  def silently(fun) when is_function(fun, 0) do
    ExUnit.CaptureLog.capture_log(fun)
  end
```

- [ ] **Step 2: Find remaining log leaks and wrap them**

Run: `mix test 2>&1 | grep -E "^\\[(error|warning)\\]" | sort -u`
For each unique log line, find the test that triggers it and wrap the offending call in `silently(fn -> ... end)`. Be conservative: only wrap calls that are *intentionally* exercising the error path.

- [ ] **Step 3: Verify clean output**

Run: `mix test 2>&1 | grep -E "^\\[(error|warning)\\]" | wc -l`
Expected: `0`.

- [ ] **Step 4: Commit**

```bash
git add -A test/
git commit -m "test: add silently/1 helper and wrap intentional warning paths

Tests that intentionally exercise error/cleanup paths now wrap their
Logger-emitting calls in silently/1, eliminating noise from clean runs.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: Compile-warning sweep

**Files:**
- Possibly modify: any source file with a compile warning

- [ ] **Step 1: Surface all compile warnings**

Run: `mix compile --warnings-as-errors --force 2>&1 | tee /tmp/compile-warnings.log`
Expected: clean compile, OR a list of warnings to address.

- [ ] **Step 2: Fix each warning**

For each warning, fix the underlying issue. Common categories:
- Unused variable → prefix with `_`.
- Unused alias / import → remove.
- Deprecated function → replace with current API.
- Pattern match never matches → restructure.

Do not silence with `@compile {:no_warn_undefined, ...}` unless the warning is genuinely unfixable (e.g., optional dependency).

- [ ] **Step 3: Verify clean compile**

Run: `mix compile --warnings-as-errors --force`
Expected: clean.

- [ ] **Step 4: Run full suite**

Run: `mix test`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "fix: resolve compile warnings surfaced by --warnings-as-errors

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

If no warnings existed (Step 1 was already clean), skip this commit.

---

## Task 12: Final verification

- [ ] **Step 1: Run `mix precommit` 3× back-to-back**

```bash
for i in 1 2 3; do
  echo "=== Run $i ==="
  mix precommit 2>&1 | tail -10
done
```
Expected: 3 clean runs, each with `0 failures`.

- [ ] **Step 2: Confirm runtime target**

Run: `mix test --slowest 10 2>&1 | tail -20`
Expected: `Finished in <60.0> seconds` and the slowest 10 tests should each be under 1 second.

- [ ] **Step 3: Confirm no real-serial regressions**

Run: `grep -rE "Circuits\.UART\.|System\.cmd.*avrdude" lib/ | wc -l`
Compare against the pre-change count (should be **identical** — we did no production refactor for serial calls; the only production change is the `device_registry.ex` log demotion and the optional `connection.ex` config read).

- [ ] **Step 4: Confirm clean output**

Run: `mix test 2>&1 | grep -E "^\\[(error|warning)\\]" | wc -l`
Expected: `0`.

- [ ] **Step 5: Confirm zero flakes**

Run: `for i in $(seq 1 5); do mix test 2>&1 | tail -1; done`
Expected: 5 lines, all `0 failures`.

- [ ] **Step 6: Final commit (if any cleanup needed) or close out**

If any small fixes were needed during verification, commit them. Otherwise, the plan is complete — the branch is ready to PR/merge.

---

## Summary of Verification Gates

All must pass before declaring done:

| Gate | Command | Expected |
|---|---|---|
| Runtime | `mix test` | < 60s |
| Flakes | `for i in $(seq 1 5); do mix test 2>&1 \| tail -1; done` | 5× `0 failures` |
| No production refactor | `grep -rE "Circuits\\.UART\\.\|System\\.cmd.*avrdude" lib/ \| wc -l` | unchanged |
| Clean output | `mix test 2>&1 \| grep -E "^\\[(error\|warning)\\]" \| wc -l` | `0` |
| Compile clean | `mix compile --warnings-as-errors --force` | clean |
| precommit | `mix precommit` 3× | all green |
