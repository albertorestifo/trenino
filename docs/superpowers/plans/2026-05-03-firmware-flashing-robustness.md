# Firmware Flashing Robustness & Regression Testing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract `AvrdudeRunner` as a Mimic-injectable seam, add regression tests for all known upload failure modes, replace fixed bootloader waits with a 5 s polling loop, enrich Sentry with full avrdude output on failure, and guard `DeviceRegistry` against unsupported upload protocols.

**Architecture:** `Trenino.Firmware.AvrdudeRunner` wraps the `Port.open` + `collect_output` logic currently private in `Uploader`. Tests stub it via Mimic to replay pre-recorded avrdude transcripts through the retry/error-classification paths without spawning real processes. Port polling replaces two fixed `Process.sleep` calls with a 300 ms poll/5 s deadline loop. `UploadManager` calls `Sentry.capture_message/2` explicitly on failure so the full avrdude transcript is indexed as structured context. `DeviceRegistry.build_device_config/4` checks a programmer allowlist and returns `nil` for unsupported protocols, which `parse_manifest_device/1` already drops via `Enum.reject(&is_nil/1)`.

**Tech Stack:** Elixir/OTP, Mimic 2.0, Sentry 13, Circuits.UART, Phoenix PubSub

---

## File Map

| File | Change | Responsibility |
|---|---|---|
| `lib/trenino/firmware/avrdude_runner.ex` | **Create** | `Port.open` subprocess execution + progress line parsing |
| `lib/trenino/firmware/uploader.ex` | **Modify** | Call `AvrdudeRunner.run/3`; replace fixed sleeps with `poll_for_bootloader_port/3` |
| `lib/trenino/firmware/upload_manager.ex` | **Modify** | Add `Sentry.capture_message/2` on upload failure and task crash |
| `lib/trenino/firmware/device_registry.ex` | **Modify** | Programmer allowlist guard in `build_device_config/4`; remove `esp32` mcu passthrough |
| `test/test_helper.exs` | **Modify** | `Mimic.copy` for `AvrdudeRunner` and `Avrdude` |
| `test/support/avrdude_fixtures.ex` | **Create** | Pre-recorded avrdude transcript strings |
| `test/support/data_case.ex` | **Modify** | Fix wrong key `"use1200bpsTouch"` → `"requires1200bpsTouch"` in `load_test_devices/0` |
| `test/trenino/firmware/upload_flow_test.exs` | **Create** | End-to-end upload flow tests via stubbed `AvrdudeRunner` |
| `test/trenino/firmware/device_registry_test.exs` | **Modify** | Update device counts and expectations for programmer allowlist |

---

### Task 1: Extract `AvrdudeRunner` module

**Files:**
- Create: `lib/trenino/firmware/avrdude_runner.ex`
- Modify: `lib/trenino/firmware/uploader.ex`
- Modify: `test/test_helper.exs`

- [ ] **Step 1: Create `lib/trenino/firmware/avrdude_runner.ex`**

```elixir
defmodule Trenino.Firmware.AvrdudeRunner do
  @moduledoc """
  Executes avrdude as a subprocess and collects its output.

  Isolated into its own module so tests can stub it via Mimic,
  allowing the retry logic in Uploader to be exercised without
  spawning real processes.
  """

  @type progress_callback :: (integer(), String.t() -> any())

  @collect_timeout_ms 120_000

  @doc """
  Runs avrdude with the given arguments and collects all output.

  Returns `{:ok, output}` on exit status 0 or `{:error, output}` on non-zero exit.
  Calls `progress_callback.(percent, message)` for each progress line detected.
  """
  @spec run(String.t(), [String.t()], progress_callback() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  def run(avrdude_path, args, progress_callback) do
    port =
      Port.open({:spawn_executable, avrdude_path}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: args
      ])

    collect_output(port, "", progress_callback)
  end

  defp collect_output(port, acc, progress_callback) do
    receive do
      {^port, {:data, data}} ->
        new_acc = acc <> data
        if progress_callback, do: parse_progress(data, progress_callback)
        collect_output(port, new_acc, progress_callback)

      {^port, {:exit_status, 0}} ->
        {:ok, acc}

      {^port, {:exit_status, _code}} ->
        {:error, acc}
    after
      @collect_timeout_ms ->
        Port.close(port)
        {:error, acc <> "\n[Timeout: avrdude did not respond within 2 minutes]"}
    end
  end

  defp parse_progress(data, callback) do
    lines = String.split(data, "\n")

    Enum.each(lines, fn line ->
      case Regex.run(~r/(Reading|Writing|Verifying)\s+\|.*?\|\s+(\d+)%/, line) do
        [_, operation, percent_str] ->
          percent = String.to_integer(percent_str)
          callback.(percent, format_operation(operation, percent))

        nil ->
          :ok
      end
    end)
  end

  defp format_operation("Reading", _percent), do: "Reading device..."
  defp format_operation("Writing", percent), do: "Writing flash (#{percent}%)"
  defp format_operation("Verifying", percent), do: "Verifying (#{percent}%)"
end
```

- [ ] **Step 2: Update `Uploader` to call `AvrdudeRunner.run/3`**

In `lib/trenino/firmware/uploader.ex`:

**2a.** Replace the alias line near the top:
```elixir
# old
alias Trenino.Firmware.{Avrdude, DeviceRegistry}

# new
alias Trenino.Firmware.{Avrdude, AvrdudeRunner, DeviceRegistry}
```

**2b.** Replace `attempt_upload/5` body (the `run_avrdude` call, ~line 115):
```elixir
defp attempt_upload(avrdude_path, config, port, hex_file_path, callback) do
  args = build_args(config, port, hex_file_path)
  Logger.info("Running avrdude: #{avrdude_path} #{Enum.join(args, " ")}")

  case AvrdudeRunner.run(avrdude_path, args, callback) do
    {:ok, output} ->
      {:ok, output}

    {:error, output} ->
      error_type = parse_error(output)
      Logger.error("Avrdude failed with error: #{error_type}")
      Logger.error("Avrdude output:\n#{output}")
      {:error, error_type, output}
  end
end
```

**2c.** Delete the four private functions that moved to `AvrdudeRunner`:
- `run_avrdude/3` (~line 351)
- `collect_output/3` (~line 363)
- `parse_progress/2` (~line 389)
- `format_operation/2` — all three clauses (~line 407)

- [ ] **Step 3: Add Mimic copies to `test/test_helper.exs`**

After the existing `Mimic.copy(Circuits.UART, type_check: true)` line, add:
```elixir
Mimic.copy(Trenino.Firmware.Avrdude)
Mimic.copy(Trenino.Firmware.AvrdudeRunner)
```

- [ ] **Step 4: Run existing uploader tests**

```bash
mix test test/trenino/firmware/uploader_test.exs
```
Expected: All tests pass (existing unit tests don't use `AvrdudeRunner` stubs).

- [ ] **Step 5: Run full suite**

```bash
mix precommit
```
Expected: All tests pass, Credo clean.

- [ ] **Step 6: Commit**

```bash
git add lib/trenino/firmware/avrdude_runner.ex \
        lib/trenino/firmware/uploader.ex \
        test/test_helper.exs
git commit -m "refactor: extract AvrdudeRunner module as injectable seam for testing"
```

---

### Task 2: Avrdude fixture transcripts

**Files:**
- Create: `test/support/avrdude_fixtures.ex`

- [ ] **Step 1: Create `test/support/avrdude_fixtures.ex`**

```elixir
defmodule Trenino.AvrdudeFixtures do
  @moduledoc """
  Pre-recorded avrdude transcript strings for use in upload flow tests.
  Each function returns the exact stdout+stderr output avrdude produces
  for that scenario, matching the patterns in Uploader.@error_patterns.
  """

  @doc "Clean successful upload — avrdude exits 0."
  def successful_upload do
    """
    avrdude: Version 7.1, compiled on Mar 10 2023 at 12:30:00

    avrdude: AVR device initialized and ready to accept instructions
    Reading | ################################################## | 100% 0.00s

    avrdude: device signature = 0x1e9514 (probably m32u4)
    avrdude: erasing chip
    avrdude: reading input file "firmware.hex"
    avrdude: writing flash (28672 bytes):

    Writing | ################################################## | 100% 6.05s

    avrdude: 28672 bytes of flash written
    avrdude: verifying flash memory against firmware.hex:

    Verifying | ################################################## | 100% 2.01s

    avrdude: 28672 bytes of flash verified

    avrdude done.  Thank you.
    """
  end

  @doc "Old-bootloader Nano fails at 115200 baud — triggers baud-rate retry path."
  def old_bootloader_nano_115200_fail do
    """
    avrdude: stk500_getsync() attempt 1 of 10: not in sync: resp=0x00
    avrdude: stk500_getsync() attempt 2 of 10: not in sync: resp=0x00
    avrdude: stk500_getsync() attempt 3 of 10: not in sync: resp=0x00
    avrdude: stk500_recv(): programmer is not responding
    avrdude: stk500_getsync(): not in sync: resp=0x00
    """
  end

  @doc "Port not found — device unplugged or wrong COM port."
  def port_not_found do
    """
    avrdude: ser_open(): can't open device "/dev/ttyUSB0": No such file or directory
    """
  end

  @doc "Permission denied accessing serial port."
  def permission_denied do
    """
    avrdude: ser_open(): permission denied accessing /dev/ttyUSB0
    """
  end

  @doc "Wrong board selected — device signature does not match expected MCU."
  def device_signature_mismatch do
    """
    avrdude: AVR device initialized and ready to accept instructions
    Reading | ################################################## | 100% 0.00s

    avrdude: device signature = 0x1e9514 (probably m32u4)
    avrdude: Expected signature for ATmega328P is 1E 95 0F
             Double check chip, or use -F to override this check.
    """
  end

  @doc "Flash written but verify failed — unstable USB connection."
  def verification_error do
    """
    avrdude: writing flash (28672 bytes):

    Writing | ################################################## | 100% 6.05s

    avrdude: verification error, first mismatch at byte 0x0100
             0x3c != 0x1c
    avrdude: verification error; content mismatch
    """
  end

  @doc "Bootloader not responding — avr109 programmer on Micro/Leonardo."
  def bootloader_not_responding do
    """
    avrdude: butterfly_recv(): programmer is not responding
    avrdude: error: programmer did not respond to command: get sync
    """
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add test/support/avrdude_fixtures.ex
git commit -m "test: add avrdude transcript fixtures for upload flow tests"
```

---

### Task 3: Upload flow tests — success and non-retrying errors

**Files:**
- Create: `test/trenino/firmware/upload_flow_test.exs`

- [ ] **Step 1: Create `test/trenino/firmware/upload_flow_test.exs`**

```elixir
defmodule Trenino.Firmware.UploadFlowTest do
  use Trenino.DataCase, async: false

  import Mimic

  alias Trenino.AvrdudeFixtures
  alias Trenino.Firmware.Avrdude
  alias Trenino.Firmware.AvrdudeRunner
  alias Trenino.Firmware.Uploader

  setup do
    load_test_devices()

    hex_file =
      Path.join(System.tmp_dir!(), "test_firmware_#{System.unique_integer([:positive])}.hex")

    File.write!(hex_file, ":00000001FF\n")
    on_exit(fn -> File.rm(hex_file) end)

    stub(Avrdude, :executable_path, fn -> {:ok, "/fake/avrdude"} end)

    {:ok, hex_file: hex_file}
  end

  describe "successful upload" do
    test "returns ok with duration and output", %{hex_file: hex_file} do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:ok, AvrdudeFixtures.successful_upload()}
      end)

      assert {:ok, %{duration_ms: duration, output: output}} =
               Uploader.upload("COM3", "uno", hex_file)

      assert is_integer(duration) and duration >= 0
      assert output =~ "avrdude done"
    end
  end

  describe "non-retrying errors" do
    test "returns :wrong_board_type immediately on device signature mismatch", %{
      hex_file: hex_file
    } do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:error, AvrdudeFixtures.device_signature_mismatch()}
      end)

      assert {:error, :wrong_board_type, output} = Uploader.upload("COM3", "uno", hex_file)
      assert output =~ "device signature"
    end

    test "returns :permission_denied immediately without retry", %{hex_file: hex_file} do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:error, AvrdudeFixtures.permission_denied()}
      end)

      assert {:error, :permission_denied, _output} = Uploader.upload("COM3", "uno", hex_file)
    end

    test "returns :verification_failed immediately without retry", %{hex_file: hex_file} do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:error, AvrdudeFixtures.verification_error()}
      end)

      assert {:error, :verification_failed, _output} = Uploader.upload("COM3", "uno", hex_file)
    end

    test "returns :hex_file_not_found when hex file does not exist" do
      assert {:error, :hex_file_not_found, message} =
               Uploader.upload("COM3", "uno", "/nonexistent/firmware.hex")

      assert message =~ "not found"
    end

    test "returns :unknown_device for unrecognised environment", %{hex_file: hex_file} do
      assert {:error, :unknown_device, message} =
               Uploader.upload("COM3", "totally_unknown_board", hex_file)

      assert message =~ "Unknown device environment"
    end
  end
end
```

- [ ] **Step 2: Run the new tests**

```bash
mix test test/trenino/firmware/upload_flow_test.exs
```
Expected: All 6 tests pass.

- [ ] **Step 3: Run full suite**

```bash
mix precommit
```
Expected: All tests pass, Credo clean.

- [ ] **Step 4: Commit**

```bash
git add test/trenino/firmware/upload_flow_test.exs
git commit -m "test: add upload flow regression tests for success and non-retry errors"
```

---

### Task 4: Upload flow tests — baud-rate retry (old-bootloader Nano)

**Files:**
- Modify: `test/trenino/firmware/upload_flow_test.exs`

- [ ] **Step 1: Add baud-retry describe block**

Append to `test/trenino/firmware/upload_flow_test.exs` before the final `end`:

```elixir
  describe "baud-rate retry (old-bootloader Nano)" do
    test "retries at 57600 when 115200 fails with not-in-sync", %{hex_file: hex_file} do
      stub(AvrdudeRunner, :run, fn _path, args, _cb ->
        baud = Enum.at(args, Enum.find_index(args, &(&1 == "-b")) + 1)

        if baud == "115200" do
          {:error, AvrdudeFixtures.old_bootloader_nano_115200_fail()}
        else
          {:ok, AvrdudeFixtures.successful_upload()}
        end
      end)

      assert {:ok, %{duration_ms: _, output: _}} =
               Uploader.upload("COM3", "nanoatmega328", hex_file)
    end

    test "returns :bootloader_not_responding when all baud rates fail", %{hex_file: hex_file} do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:error, AvrdudeFixtures.old_bootloader_nano_115200_fail()}
      end)

      assert {:error, :bootloader_not_responding, _} =
               Uploader.upload("COM3", "nanoatmega328", hex_file)
    end
  end
```

- [ ] **Step 2: Run the new tests**

```bash
mix test test/trenino/firmware/upload_flow_test.exs
```
Expected: All 8 tests pass.

- [ ] **Step 3: Run full suite**

```bash
mix precommit
```
Expected: All tests pass, Credo clean.

- [ ] **Step 4: Commit**

```bash
git add test/trenino/firmware/upload_flow_test.exs
git commit -m "test: add baud-rate retry regression tests for old-bootloader Nano"
```

---

### Task 5: Implement bootloader port polling (TDD)

**Files:**
- Modify: `test/support/data_case.ex` (fix wrong key first)
- Modify: `test/trenino/firmware/upload_flow_test.exs` (write failing test)
- Modify: `lib/trenino/firmware/uploader.ex` (implement polling)

- [ ] **Step 1: Fix wrong key in `load_test_devices/0`**

In `test/support/data_case.ex`, for the `"micro"`, `"leonardo"`, and `"sparkfun_promicro16"` devices in `load_test_devices/0`, replace `"use1200bpsTouch"` with `"requires1200bpsTouch"` in each `uploadConfig` map. There are three occurrences — all in the `load_test_devices` function body (~lines 88, 109, 121):

```elixir
# For leonardo (~line 88):
"uploadConfig" => %{
  "protocol" => "avr109",
  "mcu" => "atmega32u4",
  "speed" => 57_600,
  "requires1200bpsTouch" => true   # was "use1200bpsTouch"
}

# For micro (~line 109):
"uploadConfig" => %{
  "protocol" => "avr109",
  "mcu" => "atmega32u4",
  "speed" => 57_600,
  "requires1200bpsTouch" => true   # was "use1200bpsTouch"
}

# For sparkfun_promicro16 (~line 121):
"uploadConfig" => %{
  "protocol" => "avr109",
  "mcu" => "atmega32u4",
  "speed" => 57_600,
  "requires1200bpsTouch" => true   # was "use1200bpsTouch"
}
```

- [ ] **Step 2: Write failing test for Windows port redetection**

Append to `test/trenino/firmware/upload_flow_test.exs` before the final `end`:

```elixir
  describe "1200bps touch + bootloader port polling" do
    test "succeeds when bootloader COM port takes three polls to appear (Windows scenario)", %{
      hex_file: hex_file
    } do
      # Simulate Windows COM port enumeration sequence:
      # call 0 — before touch: COM5 present
      # call 1 — first poll after touch (100ms): port disappeared
      # call 2 — second poll (400ms): still gone
      # call 3+ — third poll (700ms): bootloader appeared on new port COM6
      # The old code (single retry at ~2500ms) fails at call 2 because the
      # port hasn't appeared yet; the polling loop succeeds at call 3.
      {:ok, mock_uart} = Agent.start_link(fn -> :ok end)
      {:ok, enum_agent} = Agent.start_link(fn -> 0 end)

      on_exit(fn ->
        if Process.alive?(mock_uart), do: Agent.stop(mock_uart)
        if Process.alive?(enum_agent), do: Agent.stop(enum_agent)
      end)

      stub(Circuits.UART, :start_link, fn -> {:ok, mock_uart} end)
      stub(Circuits.UART, :open, fn ^mock_uart, "COM5", [speed: 1200] -> :ok end)
      stub(Circuits.UART, :close, fn ^mock_uart -> :ok end)

      stub(Circuits.UART, :enumerate, fn ->
        call_n = Agent.get_and_update(enum_agent, fn n -> {n, n + 1} end)

        case call_n do
          0 -> %{"COM5" => %{}}
          1 -> %{}
          2 -> %{}
          _ -> %{"COM5" => %{}, "COM6" => %{}}
        end
      end)

      stub(AvrdudeRunner, :run, fn _path, args, _cb ->
        assert "COM6" in args
        {:ok, AvrdudeFixtures.successful_upload()}
      end)

      assert {:ok, %{duration_ms: _, output: _}} =
               Uploader.upload("COM5", "micro", hex_file)
    end
  end
```

- [ ] **Step 3: Run the test to confirm it fails with current code**

```bash
mix test test/trenino/firmware/upload_flow_test.exs \
  --only "takes three polls"
```
Expected: FAIL — old code does a single retry at ~2500ms total. With the agent returning `{}` on calls 1 and 2, `retry_detect_bootloader_port` returns `{:error, :bootloader_port_not_found}`.

- [ ] **Step 4: Implement `poll_for_bootloader_port/3` in `Uploader`**

In `lib/trenino/firmware/uploader.ex`:

**4a.** Add module attributes after `@alternate_baud_rates`:
```elixir
@bootloader_initial_wait_ms 100
@bootloader_poll_interval_ms 300
@bootloader_poll_deadline_ms 5_000
```

**4b.** Replace `maybe_trigger_bootloader/2` for the 1200bps-touch clause (currently ~lines 211-248):
```elixir
defp maybe_trigger_bootloader(port, %{use_1200bps_touch: true}) do
  Logger.info("Triggering bootloader with 1200bps touch on #{port}")
  ports_before = get_available_ports()

  case Circuits.UART.start_link() do
    {:ok, uart} ->
      result =
        case Circuits.UART.open(uart, port, speed: 1200) do
          :ok ->
            Process.sleep(@bootloader_initial_wait_ms)
            Circuits.UART.close(uart)
            Logger.info("Waiting for bootloader to start...")
            deadline = System.monotonic_time(:millisecond) + @bootloader_poll_deadline_ms
            poll_for_bootloader_port(port, ports_before, deadline)

          {:error, reason} ->
            Logger.warning("Could not open port for 1200bps touch: #{inspect(reason)}")
            {:ok, port}
        end

      GenServer.stop(uart)
      result

    {:error, reason} ->
      Logger.warning("Could not start UART for 1200bps touch: #{inspect(reason)}")
      {:ok, port}
  end
end
```

**4c.** Add `poll_for_bootloader_port/3` after `maybe_trigger_bootloader/2`:
```elixir
defp poll_for_bootloader_port(original_port, ports_before, deadline) do
  ports_after = get_available_ports()
  new_ports = ports_after -- ports_before

  cond do
    original_port in ports_after ->
      Logger.info("Original port #{original_port} still available, using it")
      {:ok, original_port}

    length(new_ports) == 1 ->
      [new_port] = new_ports
      Logger.info("Bootloader appeared on new port #{new_port} (was #{original_port})")
      {:ok, new_port}

    length(new_ports) > 1 ->
      new_port = Enum.max(new_ports)
      Logger.info("Multiple new ports appeared, using #{new_port}")
      {:ok, new_port}

    System.monotonic_time(:millisecond) >= deadline ->
      Logger.error("No ports available after bootloader trigger")
      {:error, :bootloader_port_not_found}

    true ->
      Process.sleep(@bootloader_poll_interval_ms)
      poll_for_bootloader_port(original_port, ports_before, deadline)
  end
end
```

**4d.** Delete `detect_bootloader_port/2` (currently ~lines 254-283) and `retry_detect_bootloader_port/2` (currently ~lines 285-308).

- [ ] **Step 5: Run the full test file**

```bash
mix test test/trenino/firmware/upload_flow_test.exs
```
Expected: All tests pass (including the previously failing Windows scenario).

- [ ] **Step 6: Run full suite**

```bash
mix precommit
```
Expected: All tests pass, Credo clean.

- [ ] **Step 7: Commit**

```bash
git add lib/trenino/firmware/uploader.ex \
        test/support/data_case.ex \
        test/trenino/firmware/upload_flow_test.exs
git commit -m "fix: replace fixed bootloader waits with 5s polling loop (Windows COM port redetection)"
```

---

### Task 6: Sentry enrichment in `UploadManager`

**Files:**
- Modify: `lib/trenino/firmware/upload_manager.ex`

- [ ] **Step 1: Add `Sentry.capture_message/2` on upload failure**

In `lib/trenino/firmware/upload_manager.ex`, replace `handle_upload_result/2` for the `{:error, reason, output}` clause (currently lines 270–284):

```elixir
defp handle_upload_result(upload, {:error, reason, output}) do
  Connection.release_upload_access(upload.port, upload.release_token)

  error_message = Uploader.error_message(reason)

  case Firmware.get_upload_history(upload.upload_id) do
    {:ok, history} -> Firmware.fail_upload(history, to_string(reason), output)
    _ -> :ok
  end

  Sentry.capture_message("firmware_upload_failed",
    level: :error,
    extra: %{
      upload_id: upload.upload_id,
      port: upload.port,
      environment: upload.environment,
      error_reason: reason,
      avrdude_output: output
    }
  )

  broadcast({:upload_failed, upload.upload_id, reason, error_message})
  Logger.error("Failed firmware upload #{upload.upload_id}: #{reason}")
end
```

- [ ] **Step 2: Add `Sentry.capture_message/2` on task crash**

Replace `handle_upload_crash/2` (currently lines 291–302):

```elixir
defp handle_upload_crash(upload, reason) do
  Connection.release_upload_access(upload.port, upload.release_token)

  case Firmware.get_upload_history(upload.upload_id) do
    {:ok, history} -> Firmware.fail_upload(history, "Task crashed: #{inspect(reason)}", nil)
    _ -> :ok
  end

  Sentry.capture_message("firmware_upload_crashed",
    level: :error,
    extra: %{
      upload_id: upload.upload_id,
      port: upload.port,
      environment: upload.environment,
      error_reason: :crash,
      crash_reason: inspect(reason)
    }
  )

  broadcast({:upload_failed, upload.upload_id, :crash, "Upload task crashed unexpectedly"})
  Logger.error("Upload task crashed: #{inspect(reason)}")
end
```

- [ ] **Step 3: Run the firmware tests**

```bash
mix test test/trenino/firmware/
```
Expected: All tests pass.

- [ ] **Step 4: Run full suite**

```bash
mix precommit
```
Expected: All tests pass, Credo clean.

- [ ] **Step 5: Commit**

```bash
git add lib/trenino/firmware/upload_manager.ex
git commit -m "feat: capture firmware upload failures in Sentry with full avrdude output"
```

---

### Task 7: ESP32 guard in `DeviceRegistry` + test updates

**Files:**
- Modify: `lib/trenino/firmware/device_registry.ex`
- Modify: `test/trenino/firmware/device_registry_test.exs`

- [ ] **Step 1: Write failing test for unsupported protocol rejection**

In `test/trenino/firmware/device_registry_test.exs`, add inside `describe "reload_from_manifest/2"` (after the last existing test in that block):

```elixir
    test "rejects devices whose upload protocol is not in the avrdude allowlist" do
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => [
          %{
            "environment" => "uno",
            "displayName" => "Arduino Uno",
            "firmwareFile" => "trenino-uno.hex",
            "uploadConfig" => %{
              "protocol" => "arduino",
              "mcu" => "atmega328p",
              "speed" => 115_200
            }
          },
          %{
            "environment" => "due",
            "displayName" => "Arduino Due",
            "firmwareFile" => "trenino-due.bin",
            "uploadConfig" => %{
              "protocol" => "sam-ba",
              "mcu" => "at91sam3x8e",
              "speed" => 115_200
            }
          },
          %{
            "environment" => "esp32_device",
            "displayName" => "ESP32",
            "firmwareFile" => "trenino-esp32.bin",
            "uploadConfig" => %{
              "protocol" => "esptool",
              "mcu" => "esp32",
              "speed" => 115_200
            }
          }
        ]
      }

      assert :ok = DeviceRegistry.reload_from_manifest(manifest, 1)

      assert {:ok, _} = DeviceRegistry.get_device_config("uno")
      assert {:error, :unknown_device} = DeviceRegistry.get_device_config("due")
      assert {:error, :unknown_device} = DeviceRegistry.get_device_config("esp32_device")

      assert length(DeviceRegistry.list_available_devices()) == 1
    end
```

- [ ] **Step 2: Run the new test to confirm it fails**

```bash
mix test test/trenino/firmware/device_registry_test.exs \
  --only "rejects devices whose upload protocol"
```
Expected: FAIL — currently `due` (sam-ba) and `esp32_device` (esptool) are accepted.

- [ ] **Step 3: Implement programmer allowlist in `DeviceRegistry`**

In `lib/trenino/firmware/device_registry.ex`:

**3a.** Add module attribute after `@table_name`:
```elixir
@supported_programmers ~w[arduino avr109 wiring avrisp usbasp]
```

**3b.** Replace `build_device_config/4` (currently ~lines 245–258):
```elixir
defp build_device_config(environment, display_name, firmware_file, upload_config) do
  protocol = upload_config["protocol"]

  if protocol not in @supported_programmers do
    Logger.warning(
      "Skipping device #{environment}: protocol #{inspect(protocol)} is not supported. " <>
        "Supported protocols: #{Enum.join(@supported_programmers, ", ")}"
    )

    nil
  else
    %{
      environment: environment,
      display_name: display_name,
      firmware_file: firmware_file,
      mcu: normalize_mcu(upload_config["mcu"]),
      programmer: protocol,
      baud_rate: upload_config["speed"],
      use_1200bps_touch: upload_config["requires1200bpsTouch"] || false
    }
  end
end
```

**3c.** In `normalize_mcu/1` (~lines 261–270), remove the `"esp32" -> "esp32"` clause:
```elixir
defp normalize_mcu(mcu) when is_binary(mcu) do
  case mcu do
    "atmega328p" -> "m328p"
    "atmega32u4" -> "m32u4"
    "atmega2560" -> "m2560"
    "at91sam3x8e" -> "at91sam3x8e"
    other -> other
  end
end
```

- [ ] **Step 4: Update existing device count assertions in `device_registry_test.exs`**

The `@test_manifest` in the test file includes `"due"` with `sam-ba` protocol (7 devices). After the allowlist, `due` is rejected, so setup loads 6 devices. Make these targeted changes:

**4a.** In `describe "list_available_devices/0"`, test `"returns all devices from loaded manifest"`:
- Change `assert length(devices) == 7` → `assert length(devices) == 6`
- Remove the line `assert "due" in environments`

**4b.** In `describe "select_options/0"`, test `"returns options suitable for form select"`:
- Change `assert length(options) == 7` → `assert length(options) == 6`

**4c.** In `describe "select_options/0"`, test `"options are sorted alphabetically by display name"`:
- No change needed.

**4d.** In `describe "reload_from_manifest/2"`, replace the test `"loads all devices with valid uploadConfig from manifest"` body with:
```elixir
    test "accepts devices with supported avrdude protocols" do
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => [
          %{
            "environment" => "uno",
            "displayName" => "Arduino Uno",
            "firmwareFile" => "trenino-uno.hex",
            "uploadConfig" => %{
              "protocol" => "arduino",
              "mcu" => "atmega328p",
              "speed" => 115_200
            }
          },
          %{
            "environment" => "custom_board",
            "displayName" => "Custom Board",
            "firmwareFile" => "trenino-custom.hex",
            "uploadConfig" => %{
              "protocol" => "custom_protocol",
              "mcu" => "custom_mcu",
              "speed" => 9600
            }
          }
        ]
      }

      assert :ok = DeviceRegistry.reload_from_manifest(manifest, 1)

      assert {:ok, uno_config} = DeviceRegistry.get_device_config("uno")
      assert uno_config.programmer == "arduino"

      assert {:error, :unknown_device} = DeviceRegistry.get_device_config("custom_board")

      assert length(DeviceRegistry.list_available_devices()) == 1
    end
```

**4e.** In `describe "initialization from database"`, test `"handles invalid manifest JSON gracefully"`:
- Change `assert length(devices) == 7` → `assert length(devices) == 6`

- [ ] **Step 5: Run all device registry tests**

```bash
mix test test/trenino/firmware/device_registry_test.exs
```
Expected: All tests pass.

- [ ] **Step 6: Run full suite**

```bash
mix precommit
```
Expected: All tests pass, Credo clean.

- [ ] **Step 7: Commit**

```bash
git add lib/trenino/firmware/device_registry.ex \
        test/trenino/firmware/device_registry_test.exs
git commit -m "feat: reject manifest devices with unsupported upload protocol (closes #76)"
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ Section 1 (AvrdudeRunner extraction) — Task 1
- ✅ Section 2 (Regression fixtures + upload flow tests) — Tasks 2, 3, 4, 5
- ✅ Section 3 (Bootloader port polling) — Task 5
- ✅ Section 4 (Sentry enrichment) — Task 6
- ✅ Section 5 (ESP32 guard) — Task 7

**Placeholder scan:** No TBDs, TODOs, or incomplete sections. All code blocks are complete.

**Type consistency:**
- `AvrdudeRunner.run/3` defined in Task 1, called in Task 1 (Uploader) and stubbed in Tasks 3–5.
- `poll_for_bootloader_port/3` defined and deleted functions named consistently throughout Task 5.
- `@bootloader_initial_wait_ms`, `@bootloader_poll_interval_ms`, `@bootloader_poll_deadline_ms` all introduced together in Task 5 Step 4a.
- `AvrdudeFixtures` module name used consistently in Tasks 3, 4, 5.
- `load_test_devices()` key fix in Task 5 Step 1 is required before the polling test in Step 2.
