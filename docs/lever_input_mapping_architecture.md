# Lever Input Mapping Architecture

This document describes the complete architecture for mapping hardware input values to simulator lever values.

## Overview

The system handles the conversion from raw hardware sensor values (e.g., potentiometers) to simulator lever values through a multi-stage pipeline. This architecture supports:

- **Hardware independence**: Different potentiometers with varying ranges work with the same lever configurations
- **Negative simulator values**: Reversers, dynamic brakes, and other controls with negative ranges
- **Flexible notch configurations**: Both discrete gate positions and continuous linear ranges
- **Interactive calibration**: User-guided mapping of physical positions to simulator values

## Data Flow Pipelines

The system has two distinct input pipelines depending on the hardware input type.

### Analog Pipeline (potentiometers, standard levers)

```
1. Hardware (Raw ADC)
   └─> Raw integer value (e.g., 0-1023 from 10-bit ADC)

2. Calibration (Calculator.normalize/2)
   └─> Calibrated integer (0 to total_travel)
   └─> Handles inversion, rollover, dead zones

3. Normalization (LeverController)
   └─> Normalized float (0.0 to 1.0)
   └─> Represents percentage of physical lever travel

4. Mapping (LeverMapper.map_input/2)
   └─> Simulator value (any float, including negative)
   └─> Based on notch configuration

5. Simulator
   └─> Final value sent to train simulator
```

### BLDC Detent Pipeline (brushless DC haptic levers)

BLDC levers self-calibrate on the firmware side. Instead of streaming raw ADC values, the firmware detects physical detent positions and reports a discrete detent index.

```
1. Hardware (BLDC Motor + Magnetic Encoder)
   └─> Firmware self-calibrates and finds detent positions

2. Firmware reports detent index (integer: 0, 1, 2, ...)
   └─> Index N = Nth detent the user clicked into
   └─> No ADC value, no software calibration needed

3. Mapping (LeverMapper.map_detent/2)
   └─> Finds the Nth gate notch (sorted by index)
   └─> Returns center of that gate notch's sim_input range

4. Simulator
   └─> Final value sent to train simulator
```

The key difference: **BLDC levers skip the calibration and normalization stages entirely**. The firmware handles position detection; the application only needs to map the reported detent index to the correct simulator value via gate notches.

### Example: Potentiometer with 800 Units of Travel

```elixir
# 1. Raw ADC value from hardware
raw_value = 512

# 2. Calibration (stored: min=100, max=900)
calibrated = Calculator.normalize(512, calibration)
# Result: 512 - 100 = 412 (integer from 0 to 800)

total_travel = Calculator.total_travel(calibration)
# Result: 900 - 100 = 800

# 3. Normalization
normalized = calibrated / total_travel
# Result: 412 / 800 = 0.515 (51.5% of lever travel)

# 4. Mapping (reverser: -1.0 to 1.0)
# Notch config: min_value=-1.0, max_value=1.0, input_min=0.0, input_max=1.0
simulator_value = -1.0 + (0.515 * 2.0)
# Result: 0.03 (slightly forward)

# 5. Send to simulator
Client.set(client, "Reverser.Value", 0.03)
```

## Value Ranges at Each Stage

| Stage | Type | Range | Example | Notes |
|-------|------|-------|---------|-------|
| Raw ADC | Integer | 0-1023 (10-bit) | 512 | Hardware-dependent |
| Calibrated | Integer | 0 to total_travel | 412 out of 800 | After calibration normalization |
| Normalized | Float | 0.0 to 1.0 | 0.515 | Percentage of physical travel |
| Simulator | Float | Any range | -1.0 to 1.0 | Can be negative! |

## Why Use 0.0-1.0 Normalization?

### Advantages

1. **Hardware Independence**
   - A lever configuration works with any calibrated input
   - Different potentiometers (400, 800, 1023 units) use the same config
   - No need to reconfigure when swapping hardware

2. **User-Friendly Calibration**
   - Users think in percentages: "Gate 1 is at 33% of lever travel"
   - UI can show positions as 0%-100%
   - Intuitive for setting up dead zones

3. **Clean Abstraction**
   - Separation of concerns: calibration handles hardware, mapping handles logic
   - LeverMapper doesn't need to know about raw ADC values
   - Easier to test and reason about

4. **Configuration Portability**
   - Share lever configs between users with different hardware
   - Train definitions are hardware-agnostic
   - Backup/restore works across different setups

### Alternative Considered: Raw Integer Values

We could have stored raw calibrated integers (0 to total_travel) in notches, but this would:
- Tie configurations to specific hardware characteristics
- Make the UI more complex (showing 0-800 instead of 0%-100%)
- Complicate lever configuration sharing
- Break when hardware is swapped

## Notch Configuration

### Notch Schema Fields

```elixir
defmodule Trenino.Train.Notch do
  schema "train_lever_notches" do
    field :index, :integer           # Position in lever sequence
    field :type, Ecto.Enum          # :gate or :linear

    # Simulator values (can be negative!)
    field :value, :float            # For gate notches (fixed value)
    field :min_value, :float        # For linear notches (start of range)
    field :max_value, :float        # For linear notches (end of range)

    # Input range mapping (normalized 0.0-1.0)
    field :input_min, :float        # Start of physical position range
    field :input_max, :float        # End of physical position range
  end
end
```

### Input Range (input_min, input_max)

These fields define where in the physical lever travel this notch applies:

- **Type**: Float (0.0 to 1.0)
- **Meaning**: Normalized physical lever position
- **Example**: `input_min: 0.0, input_max: 0.33` means first third of lever travel

**Important**: These are NOT raw hardware values!

```elixir
# CORRECT: Normalized values
%Notch{
  input_min: 0.0,   # Physical lever at minimum position
  input_max: 0.33   # Physical lever at 33% of total travel
}

# WRONG: Raw calibrated values
%Notch{
  input_min: 0,     # Don't use raw integers!
  input_max: 267    # Don't use hardware-specific values!
}
```

### Simulator Values (value, min_value, max_value)

These fields define what value to send to the simulator:

- **Type**: Float (any range, including negative)
- **Meaning**: Actual simulator control value
- **Examples**:
  - Throttle: `0.0` to `1.0`
  - Reverser: `-1.0` to `1.0`
  - Dynamic brake: `-0.45` to `0.0`

## Notch Types

### Gate Notch

A discrete position with a fixed value. The simulator snaps to this value when the lever is in range.

```elixir
# Reverser gate positions
notches = [
  %Notch{
    type: :gate,
    value: -1.0,        # Full reverse
    input_min: 0.0,
    input_max: 0.33
  },
  %Notch{
    type: :gate,
    value: 0.0,         # Neutral
    input_min: 0.33,
    input_max: 0.67
  },
  %Notch{
    type: :gate,
    value: 1.0,         # Full forward
    input_min: 0.67,
    input_max: 1.0
  }
]
```

When the physical lever is anywhere in the 0.0-0.33 range, the simulator receives `-1.0`.

### Linear Notch

A continuous range where values are interpolated.

```elixir
# Throttle with idle and power notches
notches = [
  %Notch{
    type: :linear,
    min_value: 0.0,     # Idle start
    max_value: 0.3,     # Idle end
    input_min: 0.0,
    input_max: 0.25
  },
  %Notch{
    type: :linear,
    min_value: 0.3,     # Power start
    max_value: 1.0,     # Full power
    input_min: 0.25,
    input_max: 1.0
  }
]
```

When the physical lever is at 0.125 (halfway through first notch):
1. Position within notch: `(0.125 - 0.0) / (0.25 - 0.0) = 0.5`
2. Simulator value: `0.0 + (0.5 * 0.3) = 0.15`

## Handling Negative Simulator Values

The architecture fully supports negative simulator values at the mapping stage.

### Example: Reverser (-1.0 to 1.0)

```elixir
notch = %Notch{
  type: :linear,
  min_value: -1.0,    # Full reverse (negative!)
  max_value: 1.0,     # Full forward (positive)
  input_min: 0.0,
  input_max: 1.0
}

# Physical lever at 0% (all the way back)
LeverMapper.map_input(config, 0.0)
# => {:ok, -1.0}

# Physical lever at 25% (one quarter forward)
LeverMapper.map_input(config, 0.25)
# => {:ok, -0.5}

# Physical lever at 50% (neutral/centered)
LeverMapper.map_input(config, 0.5)
# => {:ok, 0.0}

# Physical lever at 100% (all the way forward)
LeverMapper.map_input(config, 1.0)
# => {:ok, 1.0}
```

### Example: Dynamic Brake (-0.45 to 0.0)

```elixir
notch = %Notch{
  type: :linear,
  min_value: -0.45,   # Full brake (negative!)
  max_value: 0.0,     # Brake off
  input_min: 0.0,
  input_max: 1.0
}

# Physical lever at 0% (brake off)
LeverMapper.map_input(config, 0.0)
# => {:ok, -0.45}

# Physical lever at 50% (half brake)
LeverMapper.map_input(config, 0.5)
# => {:ok, -0.22}

# Physical lever at 100% (brake released)
LeverMapper.map_input(config, 1.0)
# => {:ok, 0.0}
```

## Interactive Calibration Workflow

When a user binds a physical input to a lever, they need to map physical positions to notch boundaries.

### Proposed UI Flow

1. **Start Calibration Session**
   ```elixir
   # User selects: Lever Config + Hardware Input
   binding = %LeverInputBinding{
     lever_config_id: throttle.id,
     input_id: potentiometer.id
   }
   ```

2. **For Each Notch Boundary**
   ```
   UI: "Move the lever to the START of Notch 0 (Idle)"

   User: [Moves physical lever]

   System: Samples current input
     - Raw value: 156
     - Calibrated: 56
     - Normalized: 0.07 (7% of travel)

   UI: "Start position: 7%"
   User: [Confirms]

   System: Sets input_min = 0.07 for Notch 0
   ```

3. **Repeat for All Boundaries**
   - End of each notch becomes start of next notch
   - UI shows visual feedback of current lever position
   - Final notch should end at 1.0 (or earlier for dead zones)

4. **Validation**
   ```elixir
   # Check coverage
   - All notches have input_min and input_max set
   - No gaps or overlaps in ranges
   - Ranges are within 0.0-1.0
   - input_min < input_max for each notch
   ```

5. **Test**
   ```
   UI: "Test the calibration - move lever through all positions"

   System: Shows live feedback
     - Current position: 0.45 (45%)
     - Active notch: 1 (Power)
     - Simulator value: 0.63
   ```

### Sample Implementation Sketch

```elixir
defmodule Trenino.Train.InputCalibration do
  @moduledoc """
  Interactive calibration session for binding inputs to levers.
  """

  def sample_current_position(input_id) do
    # Get latest value for this input
    with {:ok, input} <- Hardware.get_input(input_id),
         {:ok, raw_value} <- get_latest_value(input),
         {:ok, normalized} <- normalize_value(raw_value, input.calibration) do
      {:ok, normalized}
    end
  end

  def set_notch_boundary(notch_id, boundary_type, normalized_value)
      when boundary_type in [:input_min, :input_max] do
    notch = Train.get_notch!(notch_id)

    Train.update_notch(notch, %{
      boundary_type => Float.round(normalized_value, 2)
    })
  end

  def validate_notch_coverage(lever_config_id) do
    notches = Train.list_notches(lever_config_id)

    with :ok <- check_all_mapped(notches),
         :ok <- check_no_gaps(notches),
         :ok <- check_no_overlaps(notches) do
      {:ok, :valid}
    end
  end
end
```

## BLDC Lever Configuration

Gate notches drive the BLDC detent mapping. Each gate notch in a `LeverConfig` corresponds to one physical detent position on the lever. The firmware counts detents from 0 and the application maps index N to the Nth gate notch (sorted by `index` field).

```elixir
# Example: Three-position reverser (Reverse / Neutral / Forward)
notches = [
  %Notch{index: 0, type: :gate, sim_input_min: 0.0,  sim_input_max: 0.04},  # Reverse
  %Notch{index: 1, type: :gate, sim_input_min: 0.48, sim_input_max: 0.52},  # Neutral
  %Notch{index: 2, type: :gate, sim_input_min: 0.96, sim_input_max: 1.0}    # Forward
]

# Firmware reports detent 0 → LeverMapper.map_detent(config, 0)
# => {:ok, 0.02}   # center of first gate notch

# Firmware reports detent 2 → LeverMapper.map_detent(config, 2)
# => {:ok, 0.98}   # center of third gate notch
```

Linear notches are ignored by the BLDC pipeline — they have no corresponding physical detent and are never reported by the firmware. They remain valid for use with analog inputs bound to the same `LeverConfig`.

### `motor_enable` Pin

The BLDC hardware configuration requires three motor phase pins (`motor_pin_a`, `motor_pin_b`, `motor_pin_c`) plus an optional `motor_enable` pin. When provided, the enable pin is used to engage/disengage the motor driver. Not all motor driver boards require this pin.

## Key Design Decisions

### ✅ Decision 1: Keep 0.0-1.0 Normalization

**Rationale**: Provides hardware independence and cleaner abstraction.

**Implementation**: Current `LeverController.normalize_value/2` is correct.

### ✅ Decision 2: Support Negative Simulator Values

**Rationale**: Many train controls have negative ranges (reverser, dynamic brake).

**Implementation**: Current `LeverMapper` already supports this - no changes needed.

### ✅ Decision 3: Store Normalized Values in Notch Schema

**Rationale**: Makes configurations portable across different hardware.

**Implementation**: Current `input_min/input_max` fields are correct - just needed better documentation.

### ✅ Decision 4: Separate Calibration from Mapping

**Rationale**: Single Responsibility Principle - calibration handles hardware quirks, mapping handles game logic.

**Implementation**:
- `Hardware.Calibration.Calculator` handles raw → calibrated integer
- `LeverController` handles calibrated integer → normalized float
- `LeverMapper` handles normalized float → simulator value

## Migration Path

The current implementation is **architecturally sound**. Only minor improvements needed:

1. ✅ **Documentation** - Added comprehensive docs to clarify the architecture
2. ✅ **Tests** - Added comprehensive tests for negative values and edge cases
3. ⏳ **UI Implementation** - Build interactive calibration interface (future work)

## Summary

### Analog Pipeline

| Component | Input | Output | Purpose |
|-----------|-------|--------|---------|
| `Calculator.normalize/2` | Raw ADC value | Calibrated integer (0 to total_travel) | Handle hardware quirks |
| `LeverController.normalize_value/2` | Calibrated integer | Normalized float (0.0-1.0) | Hardware independence |
| `LeverMapper.map_input/2` | Normalized float | Simulator value (any float) | Game logic mapping |

**The key insight**: The 0.0-1.0 normalization layer makes configurations portable across different hardware while still supporting the full range of simulator values (including negative).

### BLDC Pipeline

| Component | Input | Output | Purpose |
|-----------|-------|--------|---------|
| Firmware self-calibration | Motor + encoder signals | Detent index (integer) | Physical position detection |
| `LeverMapper.map_detent/2` | Detent index | Simulator value (float) | Map detent to gate notch center |

**The key insight**: BLDC levers offload position detection entirely to firmware. The application only needs to know which detent was clicked and translate that to a simulator value via gate notches.
