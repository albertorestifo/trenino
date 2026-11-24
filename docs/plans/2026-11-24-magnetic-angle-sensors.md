# Magnetic angle sensors over I2C: finishing the feature

Status: plan, 2026-11-24. Builds on trenino 99b9cbd and trenino_firmware 8712d58 (3.4.0, unreleased).

## Where it stands

Merged today: an analog input can have `sensor: :mt6701` with `i2c_address` 0x06 or 0x46; its `pin`
becomes a fixed report pin (240/241); Configure sends module type 8; apply needs firmware 3.4.0;
calibration passes `max_hardware_value` 16383.

Gaps found while reading the code:

1. **Calibration at rest stalls.** The firmware only sends when the angle moves more than 3 counts or
   every ~2 s. The min/max steps need 10 pushed samples with at least 3 distinct values. A steady
   14-bit sensor may never give 3 distinct values, and 10 keep-alives take 20 s.
2. **Wrap at the ends.** `Analyzer.calculate_min/max` take `Enum.min/max` of the held samples. If the
   lever's end sits near 0/16383, samples like `[16382, 16383, 0, 1]` give a wrong endpoint. Without
   rollover, a jitter from 2 to 16381 normalizes to full travel (the lever jumps from min to max).
   The magnet's zero is wherever it was glued, so this is a real case, not an edge case.
3. **Errors are silent.** `ModuleError` for a sensor address is only logged. A sensor that drops out
   at runtime keeps sending its last value every 2 s, so it looks alive with a frozen value.
4. **Wrong messages.** "firmware update required" says gauges; the calibration header says "Pin 240";
   the inputs table shows "I2C 6 (0x06)"; aria labels say "pin 240".
5. **Input detection** (MCP `detect_input`) uses a 50-count threshold: 0.3° on a 14-bit sensor, and
   a wrap jitter reads as a 16000-count jump.
6. **Addresses.** Nothing stops an HT16K33 display at 0x06/0x46, and `ModuleError` is keyed by
   address only.
7. **AS5600L** (12-bit, I2C, factory 0x40) is the fallback chip if the MT6701 variant doesn't work
   out. Today adding it would mean touching every `:mt6701` match.

## Plan

### A. One sensor table (app)

`Trenino.Hardware.AngleSensor`: a struct per chip, looked up by the `Input.sensor` atom.

| sensor | label | module type | max raw | addresses offered | firmware |
|---|---|---|---|---|---|
| `:mt6701` | MT6701 | 8 | 16383 | 0x06 (factory), 0x46 (set with setup sketch) | 3.4.0 |
| `:as5600l` | AS5600L | 9 | 4095 | 0x40 (factory), 0x41 (set by the user) | 3.4.0 |

`Input.sensor` becomes `[:adc, :mt6701, :as5600l]`. Every place that matched `:mt6701` asks
`AngleSensor.angle_sensor?/1` or reads the spec instead. `Input.max_raw_value/1` reads the spec.

**Report pins**: allocated, not derived from the address. `Hardware.create_input/2` gives an angle
sensor the lowest free pin in 240..247 on that device. The changeset keeps validating the address
against the chip's list. This frees the address list from the pin map and keeps ModuleError ->
input lookup by `{device, address}`.

**Address uniqueness per device bus**: a sensor address may not equal another sensor's or an
HT16K33's on the same device (checked in the context for both create paths, error on
`:i2c_address`). A partial unique index on `device_inputs(device_id, i2c_address)` backs it.

### B. Firmware (3.4.0, still unreleased, so the version stays)

- Generalize `MT6701Module` into `AngleSensorModule` with a chip parameter: MT6701 reads 0x03/0x04
  (14-bit), AS5600L reads RAW ANGLE 0x0C/0x0D (12-bit). Module type 9 = AS5600L, same 3-byte payload.
  Dead zone is per chip (3 counts at 14 bits, 1 at 12 bits) and measured across the wrap.
- **Runtime loss**: after 5 failed reads in a row (~50 ms), stop sending (no stale keep-alive) and
  queue one `ModuleError(addr, 1 = read_lost)`, sent from the main loop. The first good read after
  that sends at once. Init failure stays code 0.
- Tests on the native env; PROTOCOL.md and CHANGELOG updated.

### C. Calibration (app)

- `device_input_calibrations.circular` boolean (default false); set true for angle sensors.
- **Circular analysis** (Analyzer): direction = sign of the sum of shortest-way deltas over the
  sweep (not median of raw deltas). Endpoints: unwrap the held samples around their first value,
  take the outermost one in the travel direction, and wrap back into 0..max.
  `has_rollover` = the travel crosses 0 (kept for display and old code).
- **Circular normalize** (Calculator): with `circular: true`,
  `d = mod(dir * (raw - min), N)`, `T = mod(dir * (max - min), N)`; inside `0..T` gives `d`; outside
  clamps to the nearer end measured round the circle. ADC calibrations (`circular: false`) keep the
  current code exactly, so no existing lever changes behaviour.
- **Session**: for angle sensors the hold steps sample the latest reading every 100 ms, need 10
  samples and at least one fresh reading from the device during the step; the "unique values" rule
  is dropped for them. Rejects a travel under 5° (`:range_too_small`) or over 350°
  (`:range_too_large`: can't tell the ends apart).
- ADC keeps 10 pushed samples / 3 unique values.

### D. UX

- **Add input**: Sensor select under Type = Analog:
  "Potentiometer on an analog pin", "MT6701 magnetic sensor (I2C)", "AS5600L magnetic sensor (I2C)".
  For a magnetic sensor: address select, defaulting to the first address not used on this device;
  help text: "Connect to SDA/SCL. A second sensor on the same cable must be set to 0x46 first with
  the setup sketch." If the connected controller's firmware is older than 3.4.0, an inline warning
  names both versions.
- **Inputs table**: Pin column shows `I2C 0x06`; type badge "Analog · MT6701"; uncalibrated value
  shows raw and degrees (`8192 · 180.0°`); a "Not responding" badge while the device reports the
  sensor missing (set by ModuleError, cleared by the next reading from that pin, reset on apply).
- **After apply**: a flash naming the sensor: "The MT6701 at 0x46 did not answer. Check the cable to
  J2, and that the second board was set to 0x46 with the setup sketch, then apply again."
  Runtime loss: "The MT6701 at 0x06 stopped answering. Check its cable."
- **Calibration wizard**: header "MT6701 at 0x06" instead of "Pin 240"; a live readout (raw and
  degrees) on every step, so the user sees the magnet working; for magnetic sensors the counter shows
  samples only. Error texts for the two new range errors.
- **Firmware message**: names what needs which version (3.3.0 gauges, 3.4.0 magnetic sensors).
- **Detection**: analog threshold 5% of the sensor's range, measured the short way round for angle
  sensors.

### E. Docs and tests

- `docs/hardware-setup.md`: "Magnetic angle sensors" (wiring, addresses, chaining, calibration,
  troubleshooting). App CHANGELOG. Firmware PROTOCOL.md/CHANGELOG/ARCHITECTURE.
- Tests: AngleSensor spec, Input changeset per sensor, report-pin allocation and address clashes
  (inputs and displays), Configure encode/decode type 9, ConfigurationManager ModuleError -> fault
  broadcast and clear, circular Analyzer/Calculator (wrap at min, at max, in the middle, inverted,
  jitter across 0 at each end), Session timer sampling, wizard and edit-page LiveView tests, detection
  threshold. Firmware native tests for AS5600L decode and read-loss reporting.

## Out of scope

- Magnet field-strength status (AS5600 STATUS 0x0B / MT6701 field bits): MT6701 I2C register for it
  is unverified; worth adding after the board is on a bench.
- Bus scan / address programming from the app (the setup sketch does it).
- Releasing firmware 3.4.0 (Alberto's release step; the app's firmware updater needs the release).

## Review outcome (Fable, before implementation)

Changes to the plan above, as built:

- Calibration follows one unwrapped position from the min step to the max step; direction
  and travel come from the signed distance between the median held positions (robust to
  back-and-forth sweeps and to one glitch in a hold). `Calculator.total_travel/1` is
  circular too. Upper bound 330°, not 350°.
- Report pins stay fixed per address, from the `AngleSensor` table; the existing
  `(device_id, pin)` index keeps addresses unique. No allocator, no HT16K33 cross-check.
- AS5600L deferred: the table has one row. Firmware has no module type 9.
- Sensor loss: firmware goes quiet after 3 failed reads (no stale keep-alive) and retries
  every 50 scans; no new error code. The app marks a sensor "Not responding" from
  `ModuleError` or 5 s of silence, so it survives reconnects.
- Hold steps need one fresh reading (UI: "Reading sensor…" then a check), no timer.
- Detection threshold 3° the short way round.
- Changing an input's sensor or address clears its calibration.
