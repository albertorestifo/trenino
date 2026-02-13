# BLDC Haptic Lever Support Design

**Date:** 2026-02-13
**Status:** Approved

## Overview

This design adds support for BLDC (Brushless DC) motor-based haptic levers to Trenino. These levers provide programmable force feedback with virtual detents, enabling realistic haptic simulation of train controls.

BLDC levers represent the most advanced hardware Trenino will support, offering:
- Configurable detent positions and strengths
- Spring-back behavior (deadman's switch simulation)
- Smooth linear ranges with adjustable damping
- Runtime profile switching when changing trains

## Background

The firmware (trenino_firmware) implements a two-level BLDC configuration system:

**Level 1: Hardware Configuration** (EEPROM-persisted)
- Sent via `Configure` message with `input_type: 3` (BLDC_LEVER)
- Specifies board profile (SimpleFOCShield v2 on Mega 2560)
- Triggers automatic calibration to find physical endstops
- Stored in EEPROM, restored on boot

**Level 2: Detent Profile** (Runtime, volatile)
- Sent via `LoadBLDCProfile` message when train activates
- Specifies detent positions (0-100% of calibrated range)
- Engagement/hold/exit strengths per detent (0-255)
- Spring-back targets (which detent to return to on release)
- Linear ranges with damping between detents
- Profile can be changed instantly without recalibration

The firmware reports **detent indices** (not raw position) via `InputValue` messages. While moving through a linear range, the start detent is reported until the end detent is fully engaged.

## Goals

1. Enable users to configure BLDC levers through the existing train configuration UI
2. Auto-detect simulator notches and generate appropriate BLDC haptic parameters
3. Load/unload BLDC profiles automatically on train activation/deactivation
4. Support spring-back detection (implementation deferred to later)
5. Provide clear error handling for calibration and runtime failures

## Non-Goals

- Manual haptic parameter tuning (future enhancement)
- Multiple BLDC levers per device (hardware limitation)
- Spring-back strength detection (planned, not implemented initially)
- Real-time haptic preview during configuration

## Architecture

### Data Model Changes

#### LeverConfig Schema

Add `:bldc` to the existing `lever_type` enum:

```elixir
field :lever_type, Ecto.Enum, values: [:discrete, :continuous, :hybrid, :bldc]
```

When `lever_type: :bldc`:
- Auto-detect flow runs to find simulator notches (same as current flow)
- BLDC haptic parameters are stored in notches
- No manual notch mapping needed - it's automatic

#### Notch Schema

Add optional BLDC haptic fields (only used when `lever_config.lever_type == :bldc`):

```elixir
# BLDC haptic parameters (0-255, maps to firmware u8)
field :bldc_engagement, :integer    # Force to enter this detent
field :bldc_hold, :integer          # Force to hold in this detent
field :bldc_exit, :integer          # Force to exit this detent
field :bldc_spring_back, :integer   # Detent index to spring back to
field :bldc_damping, :integer       # Damping for linear ranges
```

These fields:
- Are `nil` for non-BLDC levers
- Get auto-populated during BLDC calibration with sensible defaults
- Can be manually tuned later (future enhancement)
- Validation ensures they're 0-255 when present

The Notch schema naturally extends to include BLDC data because it already bridges hardware and simulator:
- Hardware positions: `input_min/input_max` (physical lever 0.0-1.0)
- Simulator mappings: `sim_input_min/sim_input_max` (what to send)
- BLDC haptics: engagement/hold/exit (how it feels)

#### Device Schema

No changes needed. BLDC levers don't create `Input` records since they don't map to a single pin - they use multiple pins defined by the board profile.

### Hardware Configuration Flow (Level 1)

#### Initial BLDC Hardware Setup

When a user adds a BLDC lever to a device:

1. User selects "BLDC Haptic Lever" type in configuration wizard
2. System sends `Configure` message with `input_type: 3, board_profile: 0`
3. Firmware initializes BLDC motor and encoder
4. Firmware auto-calibrates to find physical endstops
5. Firmware stores configuration in EEPROM
6. Firmware enters freewheel mode (no haptics until profile loaded)

```elixir
Configure.encode(%Configure{
  config_id: device.config_id,
  total_parts: total_input_count,
  part_number: index,
  input_type: :bldc_lever,
  board_profile: 0  # SimpleFOCShield v2 on Mega 2560
})
```

#### Key Differences from Analog Inputs

BLDC levers differ from analog inputs:
- **No hardware pin** - use multiple pins defined by board profile
- **No Input records** - no pin to bind to
- **No hardware calibration** - firmware handles endstop detection
- **Start in freewheel** - no haptic feedback until train activates

#### Calibration Error Handling

If firmware sends `CalibrationError`:
- Display error with specific cause (timeout, range too small, encoder error)
- Show "Retry Calibration" button
- On retry, send `RetryCalibration` message
- Allow reconfiguration if hardware setup changed

### Profile Management (Level 2)

#### Train Activation/Deactivation Lifecycle

**Train Activated:**
1. Load all BLDC lever configs for this train
2. For each BLDC lever, build `LoadBLDCProfile` message from notches
3. Send to firmware via serial connection
4. Firmware activates haptic feedback
5. Firmware reports detent indices via `InputValue` messages

**Train Deactivated:**
1. Send `DeactivateBLDCProfile` message for each BLDC lever
2. Firmware enters freewheel mode (no haptics)
3. Stop processing input from BLDC levers

#### Profile Message Builder

New module: `Trenino.Hardware.BLDCProfileBuilder`

```elixir
@spec build_profile(LeverConfig.t()) :: {:ok, LoadBLDCProfile.t()} | {:error, term()}
def build_profile(%LeverConfig{lever_type: :bldc, notches: notches}) do
  # Validate profile data
  with :ok <- validate_positions(notches),
       :ok <- validate_haptic_values(notches),
       :ok <- validate_spring_back_indices(notches) do

    # Convert notches to firmware detent format
    detents = Enum.map(notches, fn notch ->
      %{
        position: calculate_position(notch),  # 0-100% of calibrated range
        engagement: notch.bldc_engagement,
        hold: notch.bldc_hold,
        exit: notch.bldc_exit,
        spring_back: notch.bldc_spring_back
      }
    end)

    # Build linear ranges between consecutive notches
    ranges = build_linear_ranges(notches)

    {:ok, %LoadBLDCProfile{
      pin: 0,  # BLDC uses board profile pins, not a single pin
      detents: detents,
      linear_ranges: ranges
    }}
  end
end

defp calculate_position(notch) do
  # Convert input_min (0.0-1.0) to firmware position (0-100)
  round(notch.input_min * 100)
end

defp build_linear_ranges(notches) do
  notches
  |> Enum.filter(&(&1.type == :linear))
  |> Enum.map(fn notch ->
    %{
      start_detent: notch.index - 1,  # Range starts after previous detent
      end_detent: notch.index,
      damping: notch.bldc_damping
    }
  end)
end
```

#### Integration with LeverController

Extend `LeverController` to handle BLDC profile loading:

```elixir
defp load_bindings_for_train(%State{} = state, train) do
  bindings = Train.list_bindings_for_train(train.id)

  # Load regular bindings (existing code)
  binding_lookup = build_binding_lookup(bindings)

  # Load BLDC profiles for this train
  load_bldc_profiles_for_train(train)

  %{state | active_train: train, binding_lookup: binding_lookup}
end

defp load_bldc_profiles_for_train(train) do
  train
  |> Train.list_lever_configs()
  |> Enum.filter(&(&1.lever_type == :bldc))
  |> Enum.each(&send_bldc_profile/1)
end

defp send_bldc_profile(%LeverConfig{} = config) do
  with {:ok, profile} <- BLDCProfileBuilder.build_profile(config),
       {:ok, port} <- find_device_port_for_lever(config),
       {:ok, _} <- Connection.send_message(port, profile) do
    Logger.info("[LeverController] Loaded BLDC profile for #{config.element.name}")
    :ok
  else
    {:error, reason} ->
      Logger.error("[LeverController] Failed to load BLDC profile: #{inspect(reason)}")
      broadcast_error({:bldc_profile_load_failed, config.id, reason})
      :error
  end
end
```

### Auto-Detection Enhancement

#### LeverAnalyzer Updates

Extend `LeverAnalyzer.AnalysisResult` to support BLDC:

```elixir
defmodule AnalysisResult do
  @type t :: %__MODULE__{
    lever_type: :discrete | :continuous | :hybrid | :bldc,
    # ... existing fields ...
    bldc_params: %{
      spring_back_detected: [integer()],  # Future: indices with spring-back
    } | nil
  }
end
```

#### Default BLDC Parameter Generation

Generate sensible defaults based on detected notch type:

```elixir
defp default_bldc_params(:gate) do
  %{
    engagement: 180,  # Strong snap into gates
    hold: 200,        # Hold firmly in gate
    exit: 150,        # Moderate force to exit
    damping: 0        # No damping for gates
  }
end

defp default_bldc_params(:linear) do
  %{
    engagement: 50,   # Light engagement for smooth zones
    hold: 30,         # Light hold in linear zones
    exit: 50,         # Easy to exit
    damping: 100      # Medium damping for smooth feel
  }
end
```

These values are starting points based on typical haptic design patterns. Users can tune them later through a future UI enhancement.

#### Enhanced Notch Suggestions

Update `build_notches_from_zones/1` to include BLDC parameters:

```elixir
defp build_notches_from_zones(zones, opts) do
  lever_type = Keyword.get(opts, :lever_type)

  zones
  |> Enum.sort_by(& &1.set_input_min)
  |> Enum.with_index()
  |> Enum.map(fn {zone, idx} ->
    base_notch = build_base_notch(zone, idx)

    if lever_type == :bldc do
      bldc_params = default_bldc_params(zone.type)

      Map.merge(base_notch, %{
        bldc_engagement: bldc_params.engagement,
        bldc_hold: bldc_params.hold,
        bldc_exit: bldc_params.exit,
        bldc_spring_back: idx,  # Default to self (no spring-back)
        bldc_damping: bldc_params.damping
      })
    else
      base_notch
    end
  end)
end
```

#### Spring-Back Detection (Planned)

During the sweep, detect when `actual_input` snaps back to a previous position:

```elixir
# Future implementation
defp detect_spring_back(samples) do
  # Look for patterns where:
  # 1. set_input advances to new position
  # 2. actual_input initially follows
  # 3. actual_input then snaps back to previous detent
  # Mark that detent as having spring-back behavior

  # For now, return empty list
  []
end
```

For the initial implementation, we'll stub this out and always set `spring_back: notch.index` (no spring-back). The architecture supports it, and we can implement detection later when loading a train and analyzing lever behavior in real-time.

### UI Flow

#### LeverSetupWizard Enhancements

**Step 1: Select Input Type**
- Add "BLDC Haptic Lever" option to lever type selection
- When selected, set `lever_type: :bldc`
- Show info: "Requires SimpleFOCShield v2 on Arduino Mega 2560"

**Step 2: Configure Hardware (BLDC-specific)**
- Skip pin selection (BLDC uses board profile pins)
- Send `Configure` message with `input_type: 3, board_profile: 0`
- Show calibration progress with live status updates
- Handle calibration errors with retry option
- On success, firmware is in freewheel mode

**Step 3: Select Simulator Endpoint**
- Same as current flow - user picks the control path
- Example: "CurrentDrivableActor/MasterController"

**Step 4: Auto-Detect Notches**
- Same as current flow - run LeverAnalyzer with `lever_type: :bldc`
- Generates BLDC parameters automatically
- Show detected notches with haptic preview:
  - "Gate at -1.0 (Strong snap)"
  - "Linear 0.0 to 1.0 (Smooth, damped)"

**Step 5: Review & Save**
- Show detected notches with simulator mappings
- Show BLDC haptic parameters (read-only for now)
- Save creates notches with all parameters
- No manual mapping step needed

#### Key UI Differences

**BLDC levers skip:**
- Hardware pin selection
- Hardware calibration (firmware handles it)
- Manual notch mapping (auto-generated)

**BLDC levers add:**
- Board profile selection (currently only one option)
- Calibration progress/error handling
- Haptic parameter preview (read-only initially)

### Error Handling

#### Calibration Errors (Initial Setup)

When firmware sends `CalibrationError`:

**Error Types:**
- `timeout` - Motor didn't reach endstops in time
- `range_too_small` - Physical travel too limited
- `encoder_error` - Encoder communication failed

**UI Response:**
- Display error message with specific cause
- Show "Retry Calibration" button
- On retry, send `RetryCalibration` message
- Allow user to reconfigure (change board profile, check wiring)

**State Management:**
- Device remains configured but lever is non-functional
- Mark device status as "calibration_failed"
- Clear status on successful retry

#### Runtime Encoder Errors

When firmware sends `EncoderError` during operation:

**Firmware Behavior:**
- Immediately enters safe freewheel mode
- Stops sending input values

**Trenino Response:**
- Log error with device/train context
- Broadcast error event to UI
- Show notification: "BLDC lever encoder fault - check connections"
- Stop processing input from this lever
- Don't block other controls

**Recovery:**
- User fixes hardware issue
- User triggers recalibration via device management UI
- On success, profile is reloaded automatically if train still active

#### Profile Loading Failures

When `LoadBLDCProfile` fails:

**Firmware Response:**
- Sends `ConfigurationError`
- Keeps previous profile active (or stays in freewheel)

**Trenino Response:**
- Log validation error with notch data
- Display error: "Invalid BLDC profile for [lever name]"
- Train activation continues (other controls work)
- Mark this lever as inactive

**Prevention:**
- Validate profile before sending:
  - All positions are 0-100
  - All strength values are 0-255
  - spring_back indices are valid (reference existing notches)
  - Linear ranges reference valid detent pairs

#### Connection Loss During Operation

When serial connection drops while BLDC profile is active:

**On Disconnect:**
- Firmware detects connection loss (heartbeat timeout)
- Firmware enters freewheel mode automatically
- No action needed from Trenino

**On Reconnect:**
- Device goes through normal reconnection flow
- If same train is still active, reload profile automatically
- If train changed or none active, stay in freewheel

#### Profile Management Edge Cases

**Switching trains rapidly:**
- Queue profile operations per device
- Ensure `DeactivateBLDCProfile` completes before `LoadBLDCProfile`
- Use config_id to track which profile is active

**Multiple BLDC levers (future):**
- Current design assumes one BLDC lever per device
- Each device can only have one SimpleFOCShield
- Document this limitation clearly in UI
- Future: Support multiple devices each with one BLDC

## Implementation Notes

### Protocol Message Handling

Add handlers in `Trenino.Serial.Protocol` for BLDC messages:

```elixir
# LoadBLDCProfile (11)
defmodule LoadBLDCProfile do
  defstruct [:pin, :num_detents, :num_linear_ranges, :detents, :linear_ranges]

  def encode(%__MODULE__{} = msg) do
    # Encode to binary format per protocol spec
  end
end

# DeactivateBLDCProfile (12)
defmodule DeactivateBLDCProfile do
  defstruct [:pin]

  def encode(%__MODULE__{pin: pin}) do
    {:ok, <<12, pin>>}
  end
end

# RetryCalibration (8)
defmodule RetryCalibration do
  defstruct [:pin]

  def encode(%__MODULE__{pin: pin}) do
    {:ok, <<8, pin>>}
  end
end
```

### Database Migrations

```elixir
# Add :bldc to lever_type enum
alter table(:train_lever_configs) do
  modify :lever_type, :string  # Recreate enum with :bldc
end

# Add BLDC fields to notches
alter table(:train_lever_notches) do
  add :bldc_engagement, :integer
  add :bldc_hold, :integer
  add :bldc_exit, :integer
  add :bldc_spring_back, :integer
  add :bldc_damping, :integer
end

# Add constraints
create constraint(:train_lever_notches, :bldc_engagement_range,
  check: "bldc_engagement IS NULL OR (bldc_engagement >= 0 AND bldc_engagement <= 255)")
create constraint(:train_lever_notches, :bldc_hold_range,
  check: "bldc_hold IS NULL OR (bldc_hold >= 0 AND bldc_hold <= 255)")
create constraint(:train_lever_notches, :bldc_exit_range,
  check: "bldc_exit IS NULL OR (bldc_exit >= 0 AND bldc_exit <= 255)")
create constraint(:train_lever_notches, :bldc_damping_range,
  check: "bldc_damping IS NULL OR (bldc_damping >= 0 AND bldc_damping <= 255)")
```

### Validation Rules

In `Trenino.Train.Notch.changeset/2`:

```elixir
defp validate_bldc_fields(changeset) do
  lever_type = get_lever_type_from_config(changeset)

  if lever_type == :bldc do
    changeset
    |> validate_required([
      :bldc_engagement, :bldc_hold, :bldc_exit,
      :bldc_spring_back, :bldc_damping
    ])
    |> validate_number(:bldc_engagement, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    |> validate_number(:bldc_hold, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    |> validate_number(:bldc_exit, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    |> validate_number(:bldc_damping, greater_than_or_equal_to: 0, less_than_or_equal_to: 255)
    |> validate_spring_back_index()
  else
    # Ensure BLDC fields are nil for non-BLDC levers
    changeset
    |> put_change(:bldc_engagement, nil)
    |> put_change(:bldc_hold, nil)
    |> put_change(:bldc_exit, nil)
    |> put_change(:bldc_spring_back, nil)
    |> put_change(:bldc_damping, nil)
  end
end

defp validate_spring_back_index(changeset) do
  spring_back = get_field(changeset, :bldc_spring_back)
  index = get_field(changeset, :index)
  lever_config_id = get_field(changeset, :lever_config_id)

  if spring_back != nil and lever_config_id != nil do
    # Ensure spring_back references a valid notch index
    max_index = get_max_notch_index(lever_config_id)

    if spring_back < 0 or spring_back > max_index do
      add_error(changeset, :bldc_spring_back, "must reference a valid notch index")
    else
      changeset
    end
  else
    changeset
  end
end
```

## Testing Strategy

### Unit Tests

1. **BLDCProfileBuilder**
   - Test profile generation from valid notches
   - Test validation of invalid positions, strengths, spring-back indices
   - Test linear range generation

2. **LeverAnalyzer**
   - Test BLDC parameter generation for gates vs linear zones
   - Test default values are within valid ranges
   - Stub out spring-back detection (returns empty list)

3. **Protocol Messages**
   - Test LoadBLDCProfile encoding
   - Test DeactivateBLDCProfile encoding
   - Test message parsing

### Integration Tests

1. **Train Activation Flow**
   - Configure BLDC lever with notches
   - Activate train
   - Verify LoadBLDCProfile sent to correct device
   - Deactivate train
   - Verify DeactivateBLDCProfile sent

2. **Error Handling**
   - Simulate CalibrationError response
   - Verify UI shows error and retry option
   - Simulate EncoderError during operation
   - Verify error handling and recovery

3. **Profile Switching**
   - Configure two trains with different BLDC profiles
   - Switch between trains
   - Verify correct profiles loaded/unloaded

### Manual Testing

1. **Hardware Setup**
   - Connect SimpleFOCShield v2 with BLDC motor
   - Configure BLDC lever through UI
   - Verify calibration completes successfully
   - Verify freewheel mode (motor spins freely)

2. **Profile Loading**
   - Configure lever for a train
   - Activate train
   - Verify haptic feedback activates
   - Feel detents and verify they match configuration

3. **Profile Switching**
   - Create multiple trains with different profiles
   - Switch between trains
   - Verify haptic feel changes appropriately

## Future Enhancements

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

## Summary

This design extends Trenino's lever system to support BLDC haptic feedback by:

1. **Extending existing schemas** - Add `:bldc` lever type and optional BLDC fields to Notch
2. **Two-level configuration** - Hardware setup (Level 1) via Configure, profile loading (Level 2) via LoadBLDCProfile
3. **Automatic profile generation** - LeverAnalyzer generates sensible BLDC defaults from detected zones
4. **Lifecycle management** - Load profiles on train activation, unload on deactivation
5. **Robust error handling** - Handle calibration failures, encoder errors, connection loss
6. **Future-proof architecture** - Support spring-back detection and manual tuning later

The design leverages existing infrastructure (LeverAnalyzer, LeverController, ConfigurationManager) while adding minimal new components (BLDCProfileBuilder, protocol messages). BLDC levers integrate seamlessly with the current train configuration flow, requiring no manual notch mapping.
