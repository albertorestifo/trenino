# I2C Input Modules (MCP23017, ADS1115) — Design

**Status:** draft for review
**Date:** 2026-11-01
**Repositories:** `trenino` (host) and `trenino_firmware`
**Firmware target:** 3.2.0

Decisions in this document are the author's unless marked otherwise. The only
requirement stated by the owner is the goal below. Everything else is a
proposal to accept or change.

## Intent

Let a device read more controls than its own pins allow, by attaching chips to
the I2C bus already used for displays and stepper shields. The owner asked for
digital inputs, analog inputs and a button matrix.

The MCP23017 is digital only, so this needs two drivers:

- **MCP23017:** direct buttons and a button matrix.
- **ADS1115:** analog inputs such as levers and potentiometers.

To the rest of Trenino, an input on one of these chips must behave exactly like
an input on a board pin: bindable, calibratable, detectable and usable by the
virtual joystick.

## Goals

- One MCP23017 can provide direct buttons, a matrix of up to 8×8, or a mix.
- One ADS1115 can provide up to 4 single-ended analog inputs, or 3 plus a supply
  reference.
- Rollover (wrapping) sensors work on an ADS1115 that has a supply reference.
- Several chips can be used on one device, within the limits below.
- Chip inputs work with existing calibration, lever and button bindings, input
  detection and virtual joystick code. The only consumer changes are the
  two calibration options described under Analog value.
- Inputs do not disturb stepper timing or display updates on the shared bus.
- A chip that fails or resets is reported to the user and recovers by itself.
- Existing device configurations keep working after the firmware update.

## Non-goals

- Using MCP23017 pins as outputs.
- The chips' interrupt pins (INTA/INTB, ALERT/RDY).
- One matrix spanning several chips.
- Other chips, such as PCF8574 or ADS1015. The design should not prevent them.
- More than 10 bits of analog resolution on the wire.
- A second I2C bus.
- Fixing the existing collision between two board-pin matrices on one device.
- Resending latched switch states when the host reconnects. Existing buttons
  have the same limitation.
- Sensors whose output does not span the full supply, such as 10–90% outputs.
  Rollover on board pins has the same limitation.
- Runtime failure reporting for HT16K33 displays and the stepper shield. Their
  `ModuleError` messages stay log-only.

## Anti-goals

This work has failed, even if the feature works on a bench, if:

- a dropped I2C read produces a phantom press or release;
- a failed chip goes unnoticed by the user;
- stepper gauges visibly stutter because of input polling;
- applying firmware 3.2.0 wipes an existing device's configuration;
- editing a chip loses the bindings or calibration of inputs that did not change.

## Constraints from the existing code

- `InputValue` is `[pin:u8][value:i16]`. The host keys all consumers on
  `{port, pin}`, and `device_inputs` is unique on `[device_id, pin]`.
- Pins 0–127 are physical. Pins 128–255 are virtual, and a board-pin matrix
  always occupies `128 .. 128 + rows * cols - 1`.
- `MAX_MODULES` is 8, and each direct input on a board pin uses one module slot.
- `loop()` runs with no delay, so `scan()` runs as fast as the loop turns. The
  docs and comments that describe a 1 ms tick or ~10 ms scans are out of date.
- `Wire.setClock` is never called, so the bus runs at the default 100 kHz.
- `Wire` calls block. The stepper shield and displays share the same bus.
- `getReading()` returns one event per call, and the main loop drains it with
  `while`.
- Unknown module types fail `Configure` decoding in current firmware, and the
  message is dropped. The host would only see a 10 s timeout.
- `loadFromEEPROM` returns false on an unknown module type.
- Pro Micro build before this work: 21,700 of 28,672 bytes flash, 1,304 of 2,560
  bytes static RAM. Modules are allocated with `new` on top of that. After the
  firmware work: 27,018 bytes (94.2%) and 1,383 bytes.
- Uno and Nano have room for one matrix chip.
- `test/Wire.h` must be included by only one translation unit per test binary.
  Its read support is a stub.

## Hardware rules

### MCP23017

- Addresses 0x20–0x27.
- **GPA7 and GPB7 must never be inputs.** The current datasheet makes them
  output-only because SDA can be corrupted when they are used as inputs. A
  chip therefore has at most 14 inputs.
- GPA7 and GPB7 may be matrix rows, which are outputs.
- An 8×8 matrix is possible only with GPA7 and GPB7 as rows, and its columns
  then span both ports. The firmware always reads both ports.
- Inputs use the chip's internal pull-ups and read active low.
- Every matrix switch needs a diode. The firmware has no ghost detection, and
  unselected rows are driven high, matching the existing matrix.

### ADS1115

- Addresses 0x48–0x4B.
- Inputs must stay within the chip's supply rails.
- The chip measures against an internal reference, not its supply. Unlike the
  AVR ADC, supply movement therefore appears as signal noise, and the top of the
  range depends on the supply voltage.
- An optional **supply reference** fixes both. One channel is wired to the same
  supply as the sensors, and readings become a ratio of it, as on an AVR pin.
- All sensors on a chip with a reference must share the supply wired to it.
- Without a reference, the setup docs must tell users to power potentiometers
  from a clean rail, away from stepper and LED current paths.

## Virtual pins

Keep `InputValue` unchanged. The host allocates each chip a block of virtual
pins and sends the base in `Configure`.

| Block | Size | Pin of a channel |
|---|---|---|
| MCP direct | 16 | `direct_base + bit` |
| MCP matrix | `rows * cols` | `matrix_base + row * cols + col` |
| ADS analog | 4 | `pin_base + channel` |

- `row` and `col` are indexes into the set bits of `row_mask` and `col_mask`,
  in ascending bit order.
- A base of 0 means that block is unused.
- Allocation is first fit, **from 255 downward**, so that the low end stays free
  for board-pin matrices, which cannot move.
- Bases are stored in the module's `params` and never change once allocated,
  unless a block has to grow and the existing block has no room.
- If no block fits, creation fails with a changeset error.

## Wire protocol

Both types are additions to `Configure`. All other messages keep their format.

### MCP23017 (`module_type = 5`), 10-byte payload

```
[i2c_address:u8] [direct_base:u8] [matrix_base:u8] [debounce:u8]
[direct_mask:u16] [row_mask:u16] [col_mask:u16]
```

- Masks are little-endian. Bits 0–7 are GPA0–7 and bits 8–15 are GPB0–7.
- `debounce` is the number of consecutive matching samples needed to accept a
  change, from 1 to 255. It is one value for the whole chip, covering direct and
  matrix inputs.

The firmware rejects the part, with `ConfigurationError`, unless:

- the three masks are disjoint;
- `direct_mask` and `col_mask` have bits 7 and 15 clear;
- `row_mask` and `col_mask` each have at most 8 bits set;
- rows and columns are either both empty or both non-empty;
- each non-empty block has a non-zero base from 128 up, and fits below 256.

### ADS1115 (`module_type = 6`), 9-byte payload

```
[i2c_address:u8] [pin_base:u8] [channel_mask:u8] [gain:u8] [ref_channel:u8]
[sensitivity:u8[4]]
```

- `channel_mask` bits 0–3 are AIN0–AIN3, single-ended.
- `gain` is the chip's PGA code. Only 0 (±6.144 V) and 1 (±4.096 V) are accepted.
- `ref_channel` is 0–3 for the supply reference, or 0xFF for none. It must not
  be set in `channel_mask`.
- `sensitivity` is 1–10 per channel and is ignored for disabled channels.

### ModuleError

Format unchanged. `error_code` values become:

| Code | Meaning |
|---|---|
| 0 | Init failed (existing) |
| 1 | Communication lost at runtime |
| 2 | Recovered |
| 3 | Supply reference lost |

### Analog value

The host always receives 0–1023.

- **With a reference:** `value = min(1023, max(raw, 0) * 1023 / ref)`, where `ref`
  is the latest reference reading, lightly smoothed. Use 32-bit arithmetic. Full
  travel reads 0–1023 on any supply, so `max_hardware_value`, the rollover
  detection and the wrap arithmetic all work unchanged.
- **Without a reference:** `value = max(raw, 0) >> 5`. With gain 0 on a 5 V rail,
  full travel reads about 833. Non-rollover calibration works from measured
  minimum and maximum, so this needs no knowledge of the supply voltage.

A reference reading below 4000 counts, about 0.75 V at gain 0, means it is
disconnected. The chip then sends no values, reports code 3 once, and reports
code 2 when the reading returns. Values must not be derived from a bad reference.

Rollover needs the full range, because detection looks for a jump above
`0.8 * 1023` and wrapping assumes a top of 1023. `Calibration.Session` therefore
gains an `allow_rollover` option, default true.
`Hardware.start_calibration_session` passes false for ADS1115 inputs on a chip
with no reference. If the sweep then looks like rollover, calibration fails with
`:rollover_needs_reference`, and the wizard tells the user to add one.

A clean ADS1115 signal may hold a single 10-bit value while a lever is still,
but `Calibration.Session` requires 3 distinct values at the min and max steps.
`Session` also gains a `min_unique_samples` option, default 3, and
`Hardware.start_calibration_session` passes 1 for ADS1115 inputs. Board-pin
calibration does not change.

## Firmware

### Files

- `i2c_bus.h/cpp` (new): one `I2CBus::begin()` holding the lazy `Wire.begin()`
  and `setWireTimeout(25000, true)` logic, now duplicated in
  `ht16k33_module.cpp` and `stepper_driver.cpp`. The bus stays at 100 kHz.
- `mcp23017_module.h/cpp` (new).
- `ads1115_module.h/cpp` (new).
- `matrix_core` (new): debounce and event queue extracted from `MatrixSensor`,
  used by both matrix implementations. `MatrixSensor` must keep its behaviour.
- `protocol.h/cpp`, `config_manager.h/cpp`: the new types, in the `Configure`
  and `ModuleConfig` unions, EEPROM store and load.
- `sensor_manager.cpp`: instantiate the new modules.
- `device_info.h`: version 3.2.0. **`EEPROM_FORMAT_VERSION` stays 5**, because
  the new records are additive. A bump would wipe existing configurations.

### Polling

The new modules ignore the free-running loop rate and use `millis()`:

- **MCP23017 without a matrix:** one sample every 5 ms.
- **MCP23017 with a matrix:** one row every 2 ms, so a full 8-row scan takes
  16 ms. Blocking time is about 1 ms per row at 100 kHz.
- **Sampling:** every sample reads GPIOA, GPIOB, OLATA and OLATB (0x12–0x15) in
  one transaction. Direct pins are debounced once per full matrix cycle, or once
  per sample if there is no matrix.
- **Default debounce:** the host picks one value per chip: 3 samples with no
  matrix (15 ms), or 2 with a matrix (32 ms on an 8-row matrix, including any
  direct pins).
- **Matrix rows:** each tick reads the row selected on the previous tick, compares
  OLAT, then selects the next row by writing OLAT. Reading first matters, because
  a write just before the read would restore OLAT and hide a chip reset.
- **Periodic rewrite:** every 8th full matrix scan rewrites all registers, which
  catches a reset landing between a read and the next select. Worst case a reset
  goes unseen for 126 ms on an 8-row matrix.
- **Bus sharing:** steppers are serviced between module scans, and module timers
  start staggered.
- **MCP23017 registers:** IOCON.BANK stays 0, using the register map with GPIOA
  at 0x12 and sequential access enabled.
- **ADS1115:** a state machine with no blocking. Write the config register to
  start a single-shot conversion at 250 SPS on the next enabled channel, return,
  then read the result on the first `scan()` at least 5 ms later. Four channels,
  or three plus a reference, give about 50 Hz each. The reference takes its turn
  in the same rotation.

### Analog reporting

Keep `AnalogSensor`'s behaviour with per-channel state, counting conversions
rather than scans:

- send if the change exceeds `DEAD_ZONE` (2, in 10-bit units) and at least
  `11 - sensitivity` conversions have passed since the last send;
- send anyway if a channel has not sent for 100 ms, so that a still lever
  supplies the 10 samples calibration needs in about 1 s. This is time-based,
  unlike `AnalogSensor`'s `MAX_SEND_INTERVAL` of 200 scans.

### Failure handling

- `begin()` returns false on NACK, and the module stays registered, as HT16K33
  does.
- A failed transaction changes no input state and produces no events.
- After 3 consecutive failures the module reports code 1 once and retries
  initialization every 1000 ms, without polling in between.
- A brief supply dip can reset an MCP23017 with no failed transaction, leaving
  its pull-ups off and pins floating. To catch this on every sample, the driver
  sets a sentinel bit in OLAT on a pin that is not a row, where it has no
  electrical effect, because reset clears OLAT. If the OLAT bytes read back
  differ from the expected values, the sample is discarded and the chip is
  reinitialized immediately, with code 1 then 2.
- Reset detections count as failures, and only a good sample clears the count, so
  a chip that keeps mismatching ends failed.
- A failed row-select write skips the next sample and rewrites all registers,
  because a NACK there is a likely reset symptom.
- An ADS1115 reads the result, then the config register. A MUX, PGA or MODE
  mismatch discards the sample. A clear OS bit means the conversion is not done,
  so the read is retried up to 3 times, then treated as a mismatch.
- While a reference is unseen or lost, an ADS1115 converts only that channel.
- Recovery reads back OLAT or config before reporting code 2, so a wrong device
  that ACKs at the address stays failed.
- If the reference is still lost at recovery, code 3 follows code 2.
- On recovery the module reports code 2. Debouncing then runs as normal, so any
  state that changed during the outage produces ordinary events.
- Held inputs stay held during an outage. Releasing them would be a phantom
  event, which the anti-goals rule out.
- `IModule` gains a way to fetch pending runtime errors, and `MessageHandler`
  sends them from `update()`.
- A module still failed when `IdentityRequest` arrives reports code 1 again, so
  a host that connects later still learns about it.

### Native tests

- Extend `test/Wire.h` with scripted `requestFrom` responses.
- Exclude the new hardware `.cpp` files in the `native` filter, matching how
  `ht16k33_module.cpp` is handled, and include them from their test files.
- Cover at least: masks and validation, register setup, direct debounce, matrix
  row sequence and pin numbering, the ADS state machine, value conversion with
  and without a reference, reference loss,
  NACK during polling producing no events, failure threshold, reset detection,
  recovery, and EEPROM round trip including a config written by 3.1.0.
- Cover `MatrixSensor` before extracting `matrix_core`. Its existing tests must
  pass unchanged.

## Host

### Data model

- `I2cModule.module_chip` gains `:mcp23017` and `:ads1115`, with new `params`
  types in the polymorphic embed:
  - `MCP23017.Params`: `direct_base`, `matrix_base`, `debounce`, `direct_mask`,
    `row_mask`, `col_mask`.
  - `ADS1115.Params`: `pin_base`, `channel_mask`, `gain`, default 0, and
    `ref_channel`, nil for none.
- Migration: add nullable `i2c_module_id` and `i2c_channel` to `device_inputs`.
  `i2c_channel` identifies a child across edits, because its pin can change.
- A chip creates a child `Input` per channel, in the same transaction, with
  `pin` from the table above and a default name such as `A3`, `R0C1` or `AIN2`.
- Child `Input` rows hold the name, ADS sensitivity and calibration. The MCP
  `debounce` is held in `params` and copied to the required `Input.debounce`.

### Rules

- `validate_pin_range`: an input with `i2c_module_id` needs a pin in 128–255.
- `I2cModule` changeset: address range per chip, and all of the firmware
  validation above, so that errors appear in the form rather than as a rejected
  configuration.
- `list_inputs` and `list_all_inputs`: child inputs are excluded by default,
  because they must not become their own `Configure` parts. A new
  `include_chip_inputs` option includes them, and `include_virtual_buttons`
  implies it. The lever controller and lever setup wizard use the default lists
  today, so they must pass the new option.
- Editing a chip adds and deletes only the channels that changed.
- Deleting a chip, or a channel, deletes child inputs with their calibration
  and removes their bindings, with a confirmation that names the affected
  bindings. Follow the existing matrix delete behaviour for anything not stated.
- `delete_device_cascade` must also remove `i2c_modules`, and it must do so after
  the child inputs.

### Configuration

- `build_configure_message` and `Hardware.i2c_wire_config` each gain clauses for
  both chips, and must stay mirrored. ADS sensitivity comes from the child
  inputs, so these paths need them preloaded.
- `validate_configuration` requires firmware ≥ 3.2.0 when a device has either
  chip, returning `:firmware_update_required` as steppers do.
- `validate_configuration` also rejects more than 8 modules before sending,
  counting inputs, matrices and I2C modules, with a clear error. Today this
  relies on firmware rejection.

### Display code

These assume every I2C module is a display and must only see display chips:

- `DisplayController` and `ScriptRunner`, including `chip_module/1` and
  `apply_display_set`, which looks up by address alone.
- `display_binding_wizard.ex`.
- `:display_hardware_available` in `train_edit_live.ex`.
- MCP `display_binding_tools.ex`.

Add `Hardware.list_all_display_modules/0`, or equivalent, and use it there.

### Errors

- `ConfigurationManager` tracks failed addresses per port from `ModuleError`,
  clearing them on code 2, reconfiguration and disconnect, and broadcasts changes.
  It tracks only addresses that belong to an input chip, because displays and the
  stepper shield never send code 2 and would otherwise show as failed forever.
- The device page shows a chip as failed, with its address and a plain hint to
  check wiring and address jumpers.
- The train view shows a warning if a bound input belongs to a failed chip.

### UI

- `i2c_module_form_component.ex` gains a chip selector.
- **MCP23017:** a 16-pin grid where each pin is Unused, Button, Row or Column.
  GPA7 and GPB7 offer only Unused and Row. Show the resulting matrix size and
  remaining virtual pin count.
- **ADS1115:** enable each of the 4 channels, set its name and sensitivity, and
  choose the gain and an optional supply reference channel. Explain that wrapping
  sensors need the reference and that it uses up a channel.
- Chip inputs appear on the device page grouped under their chip.
- `matrix_test_wizard.ex` works with an MCP matrix.
- Calibration and input detection work with chip inputs. The pin shown in the UI
  is the virtual pin plus a chip label such as `MCP 0x20 GPA3`, in place of
  `Pin 201`. This covers `calibration_wizard.ex` and `virtual_joystick_live.ex`.

### MCP tools

`device_tools.ex` accepts the new chips in `module_chip` and their parameters,
and lists them with their channels.

## Delivery order

1. Firmware: `I2CBus` and `matrix_core` refactors, with no behaviour change.
2. Firmware: protocol, config and EEPROM.
3. Firmware: MCP23017, then ADS1115, then runtime errors. Release 3.2.0.
4. Host: schema, allocation and validation.
5. Host: configuration path, firmware gate and display filtering.
6. Host: UI, error reporting, MCP tools and docs.

The host can ship before devices update, because the firmware gate blocks
applying a chip configuration to older firmware.

## Documentation

- Firmware: `docs/PROTOCOL.md` and `docs/ARCHITECTURE.md`, including correcting
  the description of the main loop, and `CHANGELOG.md`.
- Host: `docs/hardware-setup.md`, covering wiring, the GPA7/GPB7 rule, matrix
  diodes, I2C addresses, analog supply and the supply reference, plus `docs/architecture.md`.

## Acceptance

Automated tests pass in both repositories, plus these bench checks on a Pro
Micro with one MCP23017, one ADS1115, an HT16K33 and a stepper shield:

- An 8×8 MCP matrix, 4 ADS channels, a display and a gauge in motion run
  together, with no visible gauge stutter.
- Pulling a chip's SDA or power causes no phantom events, shows an error in the
  UI within 2 s, and clears after reconnecting.
- A device with a 3.1.0 configuration keeps it after updating to 3.2.0.
- A lever on the ADS1115 calibrates and drives a binding, with and without a
  reference.
- A wrapping sensor on an ADS1115 with a reference calibrates as rollover, and
  travel stays continuous across the wrap.
- Without a reference, the same sensor gets the clear calibration error.
- Disconnecting the reference stops values and shows an error, with no jump in
  the lever position.
- `pio run` still succeeds for all firmware environments. On the Pro Micro,
  flash stays under 95%, and free RAM stays above 300 bytes with two MCP23017
  8×8 matrices configured.

The bus-time figures in this document are calculated, not measured. If the
first acceptance check fails, raise the bus to 400 kHz, as all four chips
support it, before changing the design. Check long panel wiring first.

## Left to the builder

- Class structure, and how `matrix_core` is shared.
- Exact packing of debounce and state, within the RAM limit above.
- The shape of the runtime-error API on `IModule`.
- Field names, form layout and copy, following `DESIGN.md`.

## References

- `trenino_firmware/docs/superpowers/specs/2026-05-03-i2c-modules-ht16k33-design.md`
- [MCP23017 datasheet (DS20001952)](https://cdn.shopify.com/s/files/1/0176/3274/files/MCP23017_Data_Sheet_DS20001952-2998473.pdf)
- [arduino-mcp23017 issue #33](https://github.com/blemasle/arduino-mcp23017/issues/33)
