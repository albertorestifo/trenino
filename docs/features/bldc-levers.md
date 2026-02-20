# BLDC Haptic Levers

BLDC (Brushless DC) motor-based haptic levers provide programmable force feedback with virtual detents, enabling realistic haptic simulation of train controls.

## Features

- **Configurable Detents**: Define gate positions and linear ranges with precise positioning
- **Haptic Parameters**: Control engagement, hold, and exit forces for each detent
- **Spring-Back Behavior**: Configure detents to return to specific positions (e.g., deadman's switch)
- **Smooth Linear Ranges**: Add damping between detents for realistic throttle feel
- **Profile Switching**: Automatically load different haptic profiles when switching trains

## Hardware Requirements

- **Arduino Mega 2560** - Required for BLDC motor control
- **SimpleFOCShield v2** - Motor driver board
- **BLDC Motor** - 7 pole pairs typical
- **AS5047D Encoder** - 14-bit magnetic encoder in SPI mode

## Configuration Flow

### 1. Add BLDC Lever to Train

In the train configuration UI:

1. Click "Add Lever"
2. Select "BLDC Haptic Lever"
3. System configures hardware and runs calibration
4. Select simulator endpoint (e.g., "CurrentDrivableActor/Throttle")
5. Run auto-detect to find notches
6. Review and save

### 2. Auto-Generated Haptic Parameters

The system automatically generates haptic parameters based on detected notch types:

**Gate Notches** (discrete positions):
- Detent Strength: 200 (strong snap into and hold at position)
- Damping: 0 (no damping between detents)

**Linear Ranges** (smooth zones):
- Detent Strength: 30 (light engagement at boundary)
- Damping: 100 (medium damping for smooth feel)

### 3. Profile Loading

Profiles are loaded automatically:

- **Train Activated**: BLDC profile loads, haptic feedback activates
- **Train Deactivated**: Profile unloads, motor enters freewheel mode
- **Train Switched**: Old profile unloads, new profile loads

## Technical Details

### Two-Level Configuration

**Level 1: Hardware Configuration** (EEPROM-persisted)
- Board profile selection (SimpleFOCShield v2 on Mega 2560)
- Automatic calibration to find physical endstops
- Stored permanently in firmware
- Sent via `Configure` message with `input_type: :bldc_lever`

**Level 2: Detent Profile** (Runtime, volatile)
- Detent positions (0-100% of calibrated range)
- Engagement, hold, and exit strengths (0-255)
- Spring-back targets (which detent to return to)
- Linear ranges with damping between detents
- Loaded when train activates via `LoadBLDCProfile` message

### Position Calculation

Detent positions are calculated from the lever's `input_min` value (0.0-1.0 range) and converted to firmware position (0-100):

```elixir
position = round(input_min * 100)
```

For example:
- `input_min: 0.0` → position 0 (fully left)
- `input_min: 0.5` → position 50 (center)
- `input_min: 1.0` → position 100 (fully right)

### Linear Ranges

Linear ranges are automatically generated for `:linear` type notches. Each linear notch creates a range connecting the previous detent (gate) to the current detent with the specified damping.

Example:
```
Detent 0 (Gate) at position 0
  ↓ Linear Range (damping: 100)
Detent 1 (Linear) at position 20-80
  ↓ Linear Range (damping: 100)
Detent 2 (Gate) at position 100
```

### Protocol Messages

**LoadBLDCProfile (0x0B)**
```
[type][pin][num_detents][num_ranges][snap_point][endstop_strength]
[detent_data: 2 bytes × num_detents]
[range_data: 3 bytes × num_ranges]
```

Detent structure (2 bytes):
- `position`: u8 (0–100, percentage of calibrated range)
- `detent_strength`: u8 (0–255)

Range structure (3 bytes):
- `start_detent`: u8 (index of starting detent)
- `end_detent`: u8 (index of ending detent)
- `damping`: u8 (0–255)

**DeactivateBLDCProfile (0x0C)**
```
[type][pin]
```

**RetryCalibration (0x08)**
```
[type][pin]
```

## Error Handling

### Calibration Errors

If calibration fails during initial setup:

**Timeout Error**: Motor didn't reach endstops in time
- Check motor is connected and can move freely
- Verify power supply is adequate
- Retry calibration

**Range Too Small**: Physical travel too limited
- Check for mechanical obstructions
- Ensure encoder is properly mounted
- Verify lever has adequate range of motion

**Encoder Error**: Encoder communication failed
- Check SPI connections to AS5047D
- Verify encoder power supply
- Check for loose connections

**Recovery**: Click "Retry Calibration" after fixing the issue.

### Runtime Encoder Errors

If encoder fails during operation:

**Firmware Behavior**:
- Immediately enters safe freewheel mode
- Stops sending input values
- Awaits reconnection or recalibration

**Trenino Response**:
- Logs error with device/train context
- Displays notification: "BLDC lever encoder fault - check connections"
- Stops processing input from this lever
- Other controls continue working normally

**Recovery**:
- Fix hardware issue (check connections, power)
- Trigger recalibration via device management UI
- Profile reloads automatically if train still active

### Profile Loading Failures

When `LoadBLDCProfile` validation fails:

**Common Causes**:
- Invalid position values (> 100)
- Invalid strength values (> 255)
- Invalid spring-back index (references non-existent detent)
- Invalid range indices

**Prevention**: Profile validation occurs before sending:
- All positions are 0-100
- All strength values are 0-255
- Spring-back indices reference existing notches
- Linear ranges reference valid detent pairs

**Response**:
- Error displayed: "Invalid BLDC profile for [lever name]"
- Train activation continues (other controls work)
- This lever marked as inactive

### Connection Loss

When serial connection drops during operation:

**On Disconnect**:
- Firmware detects connection loss (heartbeat timeout)
- Firmware enters freewheel mode automatically
- No manual intervention needed

**On Reconnect**:
- Device goes through normal reconnection flow
- If same train still active, reload profile automatically
- If train changed or inactive, stay in freewheel

## Implementation Architecture

### Database Schema

**LeverConfig**: Added `:bldc` to `lever_type` enum, plus two BLDC-specific fields:
- `bldc_snap_point` (integer, 50–150) – snap-point sensitivity for all detents on this lever
- `bldc_endstop_strength` (integer, 0–255) – strength of the virtual endstop at the physical travel limits

**Notch**: Added optional BLDC fields (NULL for non-BLDC levers):
- `bldc_detent_strength` (0–255) – combined snap-in / hold force for this detent
- `bldc_damping` (0–255) – damping applied in the range approaching this notch

Fields are validated to ensure values are within valid ranges.

### Modules

**BLDCProfileBuilder** (`lib/trenino/hardware/bldc_profile_builder.ex`)
- Converts `LeverConfig` with notches to `LoadBLDCProfile` message
- Validates BLDC parameters are present
- Calculates detent positions from `input_min`
- Builds linear ranges from consecutive notches

**LeverController** (`lib/trenino/train/lever_controller.ex`)
- Loads BLDC profiles on train activation
- Unloads BLDC profiles on train deactivation
- Handles profile switching between trains
- Reports errors to UI

**LeverAnalyzer** (`lib/trenino/simulator/lever_analyzer.ex`)
- Enhanced to accept `lever_type: :bldc` option
- Generates default BLDC parameters based on zone type
- Gate zones get strong haptics, linear zones get smooth damping

## Limitations

### Current Limitations

- **One BLDC Lever Per Device**: Each device can only have one SimpleFOCShield
- **Manual Parameter Tuning Not Available**: Haptic parameters use sensible defaults
- **No Spring-Back Detection**: Spring-back indices default to self (no spring-back)
- **Single Board Profile**: Only SimpleFOCShield v2 on Mega 2560 supported

### Future Enhancements

1. **Haptic Tuning UI**
   - Sliders for engagement/hold/exit per notch
   - Spring-back target selection dropdown
   - Damping adjustment for linear ranges
   - Live preview by loading temporary profile

2. **Spring-Back Detection**
   - Implement real-time analysis during train operation
   - Detect spring-back strength (how hard it pulls back)
   - Auto-configure spring-back indices

3. **Multiple Board Profiles**
   - Support different BLDC hardware configurations
   - Allow users to select board profile in UI
   - Add profile templates for common setups

4. **Profile Templates**
   - Save/load BLDC profiles as templates
   - Share profiles between trains
   - Community profile library

5. **Advanced Haptics**
   - Vibration patterns for specific events
   - Dynamic strength adjustment based on train speed
   - Resistance curves for throttle/brake

## Troubleshooting

### Motor Doesn't Calibrate

1. Check motor is connected to SimpleFOCShield
2. Verify power supply is connected (12V recommended)
3. Ensure motor can move freely without obstruction
4. Check encoder connections (SPI: MISO, MOSI, SCK, CS)

### Haptic Feedback Feels Wrong

Current implementation uses fixed default values. Manual tuning UI is planned for future release.

**Workaround**: Edit notch BLDC parameters in database:
```sql
UPDATE train_lever_notches
SET bldc_detent_strength = 220,
    bldc_damping = 0
WHERE id = <notch_id>;
```

Then deactivate and reactivate train to reload profile.

### Profile Doesn't Load

1. Check device is connected
2. Verify lever configuration has notches with BLDC parameters
3. Check logs for validation errors
4. Ensure all BLDC parameter values are 0-255

### Lever Position Incorrect

BLDC levers report detent indices, not raw positions. If the wrong notch is active:
1. Check notch `input_min` values are correct
2. Verify notches are ordered by `index`
3. Re-run calibration to reset firmware endstops

## See Also

- [Design Document](../plans/2026-02-13-bldc-lever-design.md)
- [Implementation Plan](../plans/2026-02-13-bldc-lever-implementation.md)
- [Hardware Setup Guide](../hardware-setup.md)
- [Firmware BLDC Documentation](https://github.com/albertorestifo/trenino_firmware/blob/main/docs/BLDC_LEVER.md)
- [Protocol Specification](https://github.com/albertorestifo/trenino_firmware/blob/main/docs/PROTOCOL.md)
