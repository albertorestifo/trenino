# Test Suite Cleanup — Design

**Date:** 2026-05-03
**Branch:** feature/firmware-flashing-robustness (or follow-up)
**Status:** Draft, awaiting user review

## Problem

The test suite has four interrelated quality issues:

1. **Fragile.** 12 tests in `test/trenino/mcp/tools/detection_tools_test.exs` fail intermittently in the full suite but pass in isolation. Cause: `Process.sleep(50)` followed by a PubSub broadcast that races the GenServer's subscription.
2. **Unsafe.** `Circuits.UART`, `Trenino.Serial.Discovery`, and `Trenino.Firmware.Avrdude{,Runner}` are `Mimic.copy`'d in `test_helper.exs`, but only intercepted in tests that explicitly stub them. A test that forgets to stub can call the real serial/avrdude subsystem.
3. **Slow.** `mix test` takes 218s end-to-end. Top 25 slowest tests = 91s out of 102s of clean-run time (89%). Five files dominate: `configuration_list_live_test.exs` (35s), `lever_controller_bldc_test.exs` (20s), `bldc_lever_flow_test.exs` (15s), `connection_port_timeout_test.exs` (12.6s), `upload_flow_test.exs` Windows scenario (0.78s).
4. **Verbose.** Successful runs emit `[error]` lines (e.g. `"No firmware release manifest available"`) and per-test `Logger.warning` calls, padding output with non-actionable noise.

## Goals

1. **Hard guarantee:** no test calls real `Circuits.UART`, `Trenino.Firmware.Avrdude`, `Trenino.Firmware.AvrdudeRunner`, or `Trenino.Serial.Discovery`. Accidental calls raise a clear, on-purpose error.
2. **Suite runtime under 60 seconds** on a developer laptop.
3. **Zero flakes** in the detection-tools file across 5 consecutive `mix test` runs.
4. **Clean output** — no `[error]` / `[warning]` log lines on success, no compile warnings.

## Non-goals

- No production-code adapter behaviour. Mimic-based safety net only.
- No suite-wide async audit. Convert sync→async only where it falls out for free.
- No deletion of tests; assertions stay.
- No CI infrastructure changes (partitioning, parallel jobs, etc.).

## Architecture

### 1. Global serial/avrdude safety net

Add a new test-support module that defines forbidden default stubs:

```elixir
# test/support/forbidden_serial.ex
defmodule Trenino.Test.ForbiddenUART do
  @moduledoc false
  def open(_, _, _),    do: forbid("Circuits.UART.open/3")
  def close(_),         do: forbid("Circuits.UART.close/1")
  def write(_, _),      do: forbid("Circuits.UART.write/2")
  def read(_, _),       do: forbid("Circuits.UART.read/2")
  def enumerate,        do: forbid("Circuits.UART.enumerate/0")
  def start_link,       do: forbid("Circuits.UART.start_link/0")
  def controlling_process(_, _), do: forbid("Circuits.UART.controlling_process/2")

  defp forbid(call) do
    raise """
    Real #{call} was called from a test.

    Stub it explicitly with Mimic, e.g.:
        expect(Circuits.UART, :open, fn _, _, _ -> {:ok, self()} end)

    Or use a Trenino.SerialTestHelpers builder for higher-level fakes.
    """
  end
end

defmodule Trenino.Test.ForbiddenAvrdude do
  @moduledoc false
  def upload(_, _),     do: forbid("Avrdude.upload/2")
  # … cover every public function on Avrdude / AvrdudeRunner
end

defmodule Trenino.Test.ForbiddenSerialDiscovery do
  @moduledoc false
  def discover(_, _),   do: forbid("Trenino.Serial.Discovery.discover/2")
end
```

Wire defaults in a shared setup block (`Trenino.DataCase`, `Trenino.ConnCase`, and a new `Trenino.SerialSafetyCase` for plain-`ExUnit.Case` files), invoked per-test:

```elixir
# in DataCase / ConnCase / SerialSafetyCase setup
setup :set_mimic_private
setup do
  Mimic.stub_with(Circuits.UART, Trenino.Test.ForbiddenUART)
  Mimic.stub_with(Trenino.Firmware.Avrdude, Trenino.Test.ForbiddenAvrdude)
  Mimic.stub_with(Trenino.Firmware.AvrdudeRunner, Trenino.Test.ForbiddenAvrdude)
  Mimic.stub_with(Trenino.Serial.Discovery, Trenino.Test.ForbiddenSerialDiscovery)
  :ok
end
```

Why per-test setup, not `test_helper.exs`: Mimic distinguishes `:private` (process-local, async-safe) from `:global` (BEAM-wide, requires `async: false`). Setting stubs in `test_helper.exs` would require `:global` mode, which conflicts with async tests. Per-test `:private` stubs apply to the test process and any process it spawns via `Mimic.allow/3`, and tests' own `expect/3` calls override the forbidden defaults transparently.

**Implementation note:** verify Mimic's exact behaviour for `stub_with` under `:private` mode against the installed version (`mix hex.info mimic`) before wiring. If `stub_with` cannot be re-applied per-test, fall back to a `Mimic.stub/3` per function.

Tests using bare `ExUnit.Case` (no Mimic) that exercise UART code paths will surface as failures when their owning module is moved onto `SerialSafetyCase`. For each such file we add `use Mimic` and a per-test `expect/3`. Audit list built during step 1 of implementation.

### 2. Detection-tools deterministic synchronization

Add a PubSub-aware wait helper:

```elixir
# test/support/pubsub_helpers.ex
defmodule Trenino.PubSubHelpers do
  @moduledoc false
  alias Phoenix.PubSub

  @pubsub Trenino.PubSub

  @doc """
  Block until at least one process has subscribed to `topic`, or timeout.
  Polls Phoenix.PubSub's local registry every 5ms.
  """
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
    # Phoenix.PubSub.PG2 registers subscribers in a Registry keyed by topic
    case Registry.lookup(Trenino.PubSub, topic) do
      [] -> false
      [_ | _] -> true
    end
  end
end
```

(Exact registry name will be verified during implementation against the running PubSub adapter.)

Refactor each affected detection-tools test:

```elixir
task = Task.async(fn -> DetectionTools.execute(...) end)
:ok = wait_for_subscriber("hardware:input_values:#{@test_port}")
broadcast_input(button.pin, 0)
broadcast_input(button.pin, 1)
assert {:ok, result} = Task.await(task, 1_000)  # tighter timeout, deterministic
```

### 3. Slow-test surgery (top 5 files)

| File | Current cost | Pattern | Fix |
|---|---|---|---|
| `test/trenino_web/live/configuration_list_live_test.exs` | 35s (7 tests) | `assert_receive {:simulator_status, _}, 5_000` after a `Process.sleep`-driven status loop. | Trigger status updates via direct `PubSub.broadcast` in test; tighten receive timeout to 200ms. |
| `test/trenino/train/lever_controller_bldc_test.exs` | 20s (4 tests) | `Process.sleep(5_000)` waiting on Task-loaded BLDC profile. | Await the actual Task, or subscribe to the `lever_profile_loaded` PubSub event. |
| `test/trenino/integration/bldc_lever_flow_test.exs` | 15s (3 tests) | Same pattern across an integration flow. | Same fix; helper for "wait for profile loaded". |
| `test/trenino/serial/connection_port_timeout_test.exs` | 12.6s (2 tests) | Test simulates slow GenServer with sleep matching production timeout. | `Application.put_env(:trenino, :connection_timeout_ms, 500)` in test setup; halve the simulated delay. |
| `test/trenino/firmware/upload_flow_test.exs` | 0.78s | Real polling loop. | Already mimicked. No action. |

Estimated impact: ~83s removed → suite runs in ~20–25s.

### 4. Broader sleep replacement (medium aggression)

Outside the top 5, replace `Process.sleep` only where:
- It gates an `assert_receive` that can collapse into the receive itself; OR
- The containing file appears in `mix test --slowest` above 100ms.

Skip cosmetic 10ms sleeps. No file-by-file audit beyond what `--slowest` surfaces.

### 5. Output hygiene

**a) Demote startup error log.** In `lib/trenino/firmware/device_registry.ex` (lines 212–218), change `Logger.warning` → `Logger.info` for the "no manifest, using fallback" path. It's an expected fallback in tests *and* in fresh production installs; not a warning.

**b) Capture intentional warnings.** Add helper to `Trenino.DataCase`:

```elixir
def silently(fun), do: ExUnit.CaptureLog.capture_log(fun)
```

Wrap calls in tests that intentionally exercise error/cleanup paths. Audit during implementation; apply only where logs leak.

**c) Compile warnings.** Run `mix compile --warnings-as-errors` once; fix anything surfaced. (Already part of `mix precommit` via `credo --strict` — verify.)

**d) Formatter.** Keep ExUnit's default dot formatter. Failures will be rare and informative once flakes are gone.

Target clean-run output:
```
Compiling N files (.ex)
....................................................................
Finished in 22.0 seconds
1346 tests, 0 failures
```

## Implementation order

Each step is independently committable and verifiable:

1. **Safety net.** Add `forbidden_serial.ex`, wire `Mimic.stub_with` in `test_helper.exs`, set up Mimic in `DataCase`/`ConnCase` setup blocks. Run full suite; fix every test that surfaces by adding `use Mimic` + per-test `expect/3`.
2. **Detection-tools fix.** Add `wait_for_subscriber/1`; refactor `detection_tools_test.exs`; run that file 20× in a row to confirm zero flakes.
3. **Top-5 slow-test surgery.** One file per commit, biggest win first. Re-run `mix test --slowest 25` after each to confirm impact.
4. **Output hygiene.** Demote manifest log, add `silently/1`, run `mix compile --warnings-as-errors`.
5. **Final verification.** `mix precommit` 3× back-to-back; confirm targets met.

## Verification gates (all must pass before done)

- `mix test` completes in < 60s on developer laptop.
- 5 consecutive `mix test` runs: zero failures.
- `grep -rE "Circuits\.UART\.|System\.cmd.*avrdude" lib/` returns the same set of call sites as today (no production refactor).
- Clean-run output has zero `[error]` and zero `[warning]` log lines.
- `mix compile --warnings-as-errors` succeeds.

## Files touched (estimate)

**New:**
- `test/support/forbidden_serial.ex`
- `test/support/pubsub_helpers.ex`
- `test/support/serial_safety_case.ex`

**Modified:**
- `test/support/data_case.ex` (Mimic per-test stubs, `silently/1`)
- `test/support/conn_case.ex` (Mimic per-test stubs)
- new `test/support/serial_safety_case.ex` for plain `ExUnit.Case` files that need the safety net
- `lib/trenino/firmware/device_registry.ex` (one log-level change)
- `test/trenino/mcp/tools/detection_tools_test.exs` (subscriber handshake)
- `test/trenino_web/live/configuration_list_live_test.exs` (timeout + sleep removal)
- `test/trenino/train/lever_controller_bldc_test.exs` (Task await)
- `test/trenino/integration/bldc_lever_flow_test.exs` (Task await)
- `test/trenino/serial/connection_port_timeout_test.exs` (config-driven timeout)

Total: ~10 files.

## Rollback

Each step is one commit. Reverting any later step leaves earlier wins intact. Safety net (step 1) and detection fix (step 2) stand independently and can ship even if surgery uncovers blockers.

## Open items resolved during implementation

- Exact `Phoenix.PubSub` registry name for `wait_for_subscriber/1` (verify against running adapter).
- Full surface of `Trenino.Firmware.Avrdude` / `AvrdudeRunner` public functions to stub.
- Whether any test legitimately needs the real `Trenino.Serial.Discovery` (audit during step 1).
