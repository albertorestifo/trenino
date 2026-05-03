# Firmware Flashing Robustness & Regression Testing

**Date:** 2026-05-03  
**Issue:** [#76 — Arduino micro flash problems](https://github.com/albertorestifo/trenino/issues/76)  
**Status:** Approved

## Problem

Multiple users on Windows report that firmware upload fails for several board types (Micro, Nano clone with old bootloader, Uno copy) while manual flashing with Avrdudess succeeds. Root causes identified:

1. **Windows 1200bps touch / port redetection** — fixed 1500 ms wait then a single retry is not enough; bootloader COM port can take 3–5 s to enumerate on slower USB chipsets.
2. **No regression test coverage for upload retry paths** — `run_avrdude` is private and inlined; no way to drive the retry logic with fixture transcripts.
3. **Sentry receives no structured context on upload failures** — avrdude output is only in local `Logger.error` lines; Sentry gets a bare log message with no searchable context.
4. **ESP32 can appear in device dropdown** — avrdude cannot flash ESP32; manifest devices with unsupported programmers should be rejected at load time.

## Scope

- AVR board flashing robustness (Uno / Nano / Micro / Leonardo / Mega)
- Regression test infrastructure for the upload flow
- Sentry enrichment on upload failures
- ESP32 / esptool guard in `DeviceRegistry`

**Out of scope:** ESP32 flashing support (esptool), UI changes.

---

## Section 1 — AvrdudeRunner extraction

### What

Extract the `Port.open` + `collect_output` logic currently private in `Trenino.Firmware.Uploader` into a new public module `Trenino.Firmware.AvrdudeRunner`.

### Public API

```elixir
@spec run(String.t(), [String.t()], Uploader.progress_callback() | nil) ::
        {:ok, String.t()} | {:error, String.t()}
def run(avrdude_path, args, progress_callback)
```

Returns `{:ok, output}` on exit status 0, `{:error, output}` otherwise. The 2-minute collect timeout stays in this module.

### Change to Uploader

`attempt_upload/5` calls `AvrdudeRunner.run/3` instead of the inlined port logic. No other changes to `Uploader`.

### Test wiring

`Mimic.copy(Trenino.Firmware.AvrdudeRunner)` added to `test/test_helper.exs`. Tests stub with:

```elixir
Mimic.stub(AvrdudeRunner, :run, fn _path, _args, _cb -> {:error, fixture_output} end)
```

---

## Section 2 — Regression test fixtures

### What

A `test/support/avrdude_fixtures.ex` module with pre-recorded avrdude transcript strings, one function per failure scenario.

### Fixtures

| Function | Scenario |
|---|---|
| `old_bootloader_nano_57600_fail/0` | `"not in sync"` at 115200 baud |
| `old_bootloader_nano_57600_ok/0` | Clean success at 57600 baud |
| `micro_port_disappears/0` | `"can't open device"` after 1200bps touch |
| `micro_bootloader_ok/0` | Success after port reappears |
| `device_signature_mismatch/0` | `"device signature = 0x1e9514"` (wrong board) |
| `permission_denied/0` | `"ser_open(): permission denied"` |
| `verification_error/0` | `"verification error, first mismatch at byte"` |
| `successful_upload/0` | Clean success transcript |

### Test file

New `test/trenino/firmware/upload_flow_test.exs` drives `Uploader.upload/4` end-to-end with each scenario. Key assertions:

- **Old-bootloader Nano:** first call returns `old_bootloader_nano_57600_fail`, second call (at 57600) returns `old_bootloader_nano_57600_ok` → result is `{:ok, _}`
- **Micro port disappear:** `Circuits.UART` stubbed for 1200bps touch, `AvrdudeRunner.run/3` returns `micro_port_disappears` on first call then `micro_bootloader_ok` → result is `{:ok, _}`
- **Device signature mismatch:** single call returns `device_signature_mismatch` → result is `{:error, :wrong_board_type, _}` with no retry
- **Permission denied:** single call → `{:error, :permission_denied, _}`, no retry

Existing `uploader_test.exs` (`parse_error_output`, `retryable_baud_rates`, `error_message` tests) is unchanged.

---

## Section 3 — Windows bootloader port redetection

### What

Replace the two fixed sleeps (1500 ms + one 1000 ms retry) with a polling loop in `Uploader`.

### New function

```elixir
@bootloader_poll_interval_ms 300
@bootloader_poll_deadline_ms 5_000

defp poll_for_bootloader_port(original_port, ports_before, deadline_at)
```

Checks every 300 ms whether the original port has reappeared or a new port appeared. Returns as soon as one is found or `{:error, :bootloader_port_not_found}` if the 5 s deadline elapses.

### Port selection priority (unchanged)

1. Original port still present → use it (macOS / Linux common case)
2. Exactly one new port → use it
3. Multiple new ports → `Enum.max/1` (highest COM number)
4. No ports → keep polling

### Cleanup

- `detect_bootloader_port/2` and `retry_detect_bootloader_port/2` are deleted.
- Initial fixed sleep before detection drops from 1500 ms to 100 ms; the polling loop handles the wait.

### Test coverage

`Circuits.UART.enumerate/0` stubbed via Mimic to return a sequence of port maps simulating the Windows "port disappears then reappears on a new number" scenario, exercised in `upload_flow_test.exs`.

---

## Section 4 — Sentry enrichment

### What

Add explicit `Sentry.capture_message/2` calls in `UploadManager` so that avrdude output reaches Sentry as structured context, not just a plain log line.

### Changes

**On upload failure** (`handle_upload_result/2`, `{:error, reason, output}` clause):

```elixir
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
```

**On task crash** (`handle_upload_crash/2`):

```elixir
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
```

Existing `Logger.error` calls stay unchanged (they serve local log files).

No config changes needed — DSN is already set at runtime.

---

## Section 5 — ESP32 removal

### What

Guard `DeviceRegistry` against accepting manifest devices that avrdude cannot flash.

### Changes

**`normalize_mcu/1`** — remove the `"esp32" -> "esp32"` clause.

**`build_device_config/4`** — add a known-programmer allowlist check before building the config:

```elixir
@supported_programmers ~w[arduino avr109 wiring avrisp usbasp]

defp build_device_config(environment, display_name, firmware_file, upload_config) do
  protocol = upload_config["protocol"]

  if protocol not in @supported_programmers do
    Logger.warning("Skipping device #{environment}: protocol #{protocol} is not supported")
    nil
  else
    # existing map construction
  end
end
```

`parse_manifest_device/1` already calls `Enum.reject(&is_nil/1)` on the result, so returning `nil` here cleanly drops the device.

No UI changes needed — if a device is not in the registry, `select_options/0` won't include it.

---

## File changes summary

| File | Change |
|---|---|
| `lib/trenino/firmware/avrdude_runner.ex` | **New** — extracted `Port.open` + `collect_output` |
| `lib/trenino/firmware/uploader.ex` | Call `AvrdudeRunner.run/3`; replace fixed sleeps with `poll_for_bootloader_port/3` |
| `lib/trenino/firmware/upload_manager.ex` | Add `Sentry.capture_message/2` on failure and crash |
| `lib/trenino/firmware/device_registry.ex` | Programmer allowlist guard; remove `esp32` mcu passthrough |
| `test/test_helper.exs` | `Mimic.copy(Trenino.Firmware.AvrdudeRunner)` |
| `test/support/avrdude_fixtures.ex` | **New** — fixture transcripts |
| `test/trenino/firmware/upload_flow_test.exs` | **New** — end-to-end upload flow tests |

---

## Non-goals

- ESP32 / esptool flashing support
- User-facing "export log" button (Sentry will surface the transcript automatically)
- Changes to the firmware download or update-check flows
