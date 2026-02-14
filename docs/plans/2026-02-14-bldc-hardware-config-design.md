# BLDC Lever Hardware Configuration Design

**Date:** 2026-02-14
**Status:** Approved

## Goal

Update the Elixir application to match the firmware's new BLDC lever Configure message format. The firmware now sends 10 explicit hardware parameter bytes instead of a single `board_profile` byte. The application needs to store, validate, and send these parameters.

## Protocol Change

The Configure message (type 0x02) with `input_type=3` (BLDC Lever) payload changes from:

```
[board_profile: u8]
```

To:

```
[motor_pin_a: u8] [motor_pin_b: u8] [motor_pin_c: u8]
[motor_enable_a: u8] [motor_enable_b: u8]
[encoder_cs: u8] [pole_pairs: u8]
[voltage: u8] [current_limit: u8] [encoder_bits: u8]
```

See firmware `docs/PROTOCOL.md` for full specification.

## Changes

### 1. Protocol: Configure message

Add `:bldc_lever` input_type (0x03) to `Trenino.Serial.Protocol.Configure`:
- New struct fields for all 10 BLDC parameters
- Encode clause: builds 8-byte header + 10-byte payload
- Decode clause: pattern matches input_type 0x03 and extracts 10 bytes

### 2. Protocol: Message decoder

Register missing message types in `Message.decode/1`:
- 0x08 → RetryCalibration
- 0x09 → CalibrationError
- 0x0A → EncoderError
- 0x0B → LoadBLDCProfile
- 0x0C → DeactivateBLDCProfile

These modules already exist but aren't wired into the decoder.

### 3. Data: Input schema

Add `:bldc_lever` to `Input.input_type` enum. New nullable fields on `device_inputs`:
- `motor_pin_a`, `motor_pin_b`, `motor_pin_c` (u8)
- `motor_enable_a`, `motor_enable_b` (u8)
- `encoder_cs` (u8)
- `pole_pairs` (u8)
- `voltage` (u8, 0.1V units)
- `current_limit` (u8, 0.1A units, 0 = no limit)
- `encoder_bits` (u8)

Validation:
- All BLDC fields required when `input_type == :bldc_lever`
- All values 0-255
- `pole_pairs > 0`, `voltage > 0`, `encoder_bits > 0`
- One BLDC lever per device (unique constraint)

Pin field for BLDC inputs stores `encoder_cs` (the identifying pin, matching firmware convention).

### 4. Data: Migration

Add columns to `device_inputs` table. Add partial unique index: one `:bldc_lever` input per device.

### 5. Hardware context

Add `create_bldc_input/2` in `Hardware` module with BLDC-specific validation.

### 6. ConfigurationManager

Add `build_configure_message/4` clause for `{:input, %Input{input_type: :bldc_lever}}` that maps Input fields to the Configure struct.

### 7. Device Settings UI

In `ConfigurationEditLive`:
- Add "BLDC Lever" option in the "Add Input" modal's input type dropdown
- When selected, show 10 hardware parameter fields (grouped: Motor Pins, Enable Pins, Encoder, Electrical)
- Hide pin/sensitivity/debounce fields for BLDC
- Show BLDC inputs in the inputs table with appropriate display
- Enforce one-per-device in UI (disable "Add BLDC" if one exists)

### 8. Setup Wizard adjustment

In `LeverSetupWizard`:
- When BLDC lever type is selected, show "Select Input" step (don't skip it)
- Filter available inputs to `:bldc_lever` type instead of `:analog`

## Constraints

- One BLDC lever per device (firmware limitation)
- All parameter values fit in u8 (0-255)
- Voltage in 0.1V units (e.g., 120 = 12.0V)
- Current limit in 0.1A units (0 = no limit)
