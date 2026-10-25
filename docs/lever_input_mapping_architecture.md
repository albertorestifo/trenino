# Lever Input Mapping Architecture

This document describes the complete architecture for mapping hardware input values to simulator lever values.

## Overview

The system handles the conversion from raw hardware sensor values (e.g., potentiometers) to simulator lever values through a multi-stage pipeline. This architecture supports:

- **Hardware independence**: Different potentiometers with varying ranges work with the same lever configurations
- **Negative simulator values**: Reversers, dynamic brakes, and other controls with negative ranges
- **Flexible notch configurations**: Both discrete gate positions and continuous linear ranges
- **Interactive calibration**: User-guided mapping of physical positions to simulator values



## Data Flow Pipeline

```
1. Hardware (Raw ADC)
   └─> Raw integer value (e.g., 0-1023 from 10-bit ADC)

2. Calibration (trenino_core::hardware::calibration::normalize)
   └─> Calibrated integer (0 to total_travel)
   └─> Handles inversion, rollover, dead zones

3. Normalization (lever controller, crates/trenino-runtime/src/train/lever_controller.rs)
   └─> Normalized float (0.0 to 1.0)
   └─> Represents percentage of physical lever travel

4. Mapping (trenino_core::train::lever::map_input)
   └─> Simulator value (any float, including negative)
   └─> Based on notch configuration

5. Simulator
   └─> Final value sent to train simulator
```

### Example: Potentiometer with 800 Units of Travel

```rust
// 1. Raw ADC value from hardware
let raw_value: i32 = 512;

// 2. Calibration (stored: min=100, max=900)
use trenino_core::hardware::calibration::{normalize, total_travel};
let calibrated = normalize(raw_value, &calibration);
// Result: 512 - 100 = 412 (integer from 0 to 800)

let total = total_travel(&calibration);
// Result: 900 - 100 = 800

// 3. Normalization (rounded to 2 decimal places)
let normalized = round_elixir(calibrated as f64 / total as f64, 2)?;
// Result: 412 / 800 = 0.51 (51% of lever travel)

// 4. Mapping (reverser: -1.0 to 1.0)
// Notch: sim_input_min=-1.0, sim_input_max=1.0, input_min=0.0, input_max=1.0
let simulator_value = map_input(&config, normalized)?;
// Result: -1.0 + (0.51 * 2.0) ≈ 0.02 (slightly forward)

// 5. Send to simulator (writer coalesces updates while one is in flight)
writer.set("Reverser.InputValue", simulator_value).await?;
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
   - `map_input` doesn't need to know about raw ADC values
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

```rust
// crates/trenino-core/src/train/lever.rs
pub enum NotchType { Gate, Linear }

pub struct Notch {
    pub kind: NotchType,            // Gate or Linear

    // Simulator values (can be negative!)
    pub sim_input_min: Option<f64>, // Gate: the value is the midpoint of
    pub sim_input_max: Option<f64>, // (sim_input_min, sim_input_max); Linear: range start/end

    // Input range mapping (normalized 0.0-1.0)
    pub input_min: Option<f64>,     // Start of physical position range
    pub input_max: Option<f64>,     // End of physical position range
}

pub struct LeverConfig {
    pub inverted: bool,
    pub notches: Vec<Notch>,
}
```

### Input Range (input_min, input_max)

These fields define where in the physical lever travel this notch applies:

- **Type**: Float (0.0 to 1.0)
- **Meaning**: Normalized physical lever position
- **Example**: `input_min: 0.0, input_max: 0.33` means first third of lever travel

**Important**: These are NOT raw hardware values!

```rust
// CORRECT: Normalized values
Notch {
    input_min: Some(0.0),   // Physical lever at minimum position
    input_max: Some(0.33),  // Physical lever at 33% of total travel
    ..
}

// WRONG: Raw calibrated values
Notch {
    input_min: Some(0.0),   // Don't use raw integers!
    input_max: Some(267.0), // Don't use hardware-specific values!
    ..
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

```rust
// Reverser gate positions
let notches = vec![
    Notch {
        kind: NotchType::Gate,
        sim_input_min: Some(-1.0), // Full reverse (min == max → midpoint is the value)
        sim_input_max: Some(-1.0),
        input_min: Some(0.0),
        input_max: Some(0.33),
    },
    Notch {
        kind: NotchType::Gate,
        sim_input_min: Some(0.0),  // Neutral
        sim_input_max: Some(0.0),
        input_min: Some(0.33),
        input_max: Some(0.67),
    },
    Notch {
        kind: NotchType::Gate,
        sim_input_min: Some(1.0),  // Full forward
        sim_input_max: Some(1.0),
        input_min: Some(0.67),
        input_max: Some(1.0),
    },
];
```

When the physical lever is anywhere in the 0.0-0.33 range, the simulator receives `-1.0`.

### Linear Notch

A continuous range where values are interpolated.

```rust
// Throttle with idle and power notches
let notches = vec![
    Notch {
        kind: NotchType::Linear,
        sim_input_min: Some(0.0), // Idle start
        sim_input_max: Some(0.3), // Idle end
        input_min: Some(0.0),
        input_max: Some(0.25),
    },
    Notch {
        kind: NotchType::Linear,
        sim_input_min: Some(0.3), // Power start
        sim_input_max: Some(1.0), // Full power
        input_min: Some(0.25),
        input_max: Some(1.0),
    },
];
```

When the physical lever is at 0.125 (halfway through first notch):
1. Position within notch: `(0.125 - 0.0) / (0.25 - 0.0) = 0.5`
2. Simulator value: `0.0 + (0.5 * 0.3) = 0.15`

## Handling Negative Simulator Values

The architecture fully supports negative simulator values at the mapping stage.

### Example: Reverser (-1.0 to 1.0)

```rust
let config = LeverConfig {
    inverted: false,
    notches: vec![Notch {
        kind: NotchType::Linear,
        sim_input_min: Some(-1.0), // Full reverse (negative!)
        sim_input_max: Some(1.0),  // Full forward (positive)
        input_min: Some(0.0),
        input_max: Some(1.0),
    }],
};

// Physical lever at 0% (all the way back)
map_input(&config, 0.0)?;  // => -1.0

// Physical lever at 25% (one quarter forward)
map_input(&config, 0.25)?; // => -0.5

// Physical lever at 50% (neutral/centered)
map_input(&config, 0.5)?;  // => 0.0

// Physical lever at 100% (all the way forward)
map_input(&config, 1.0)?;  // => 1.0
```

### Example: Dynamic Brake (-0.45 to 0.0)

```rust
let config = LeverConfig {
    inverted: false,
    notches: vec![Notch {
        kind: NotchType::Linear,
        sim_input_min: Some(-0.45), // Full brake (negative!)
        sim_input_max: Some(0.0),   // Brake off
        input_min: Some(0.0),
        input_max: Some(1.0),
    }],
};

// Physical lever at 0% (brake off)
map_input(&config, 0.0)?;  // => -0.45

// Physical lever at 50% (half brake)
map_input(&config, 0.5)?;  // => -0.22

// Physical lever at 100% (brake released)
map_input(&config, 1.0)?;  // => 0.0
```

## Interactive Calibration Workflow

When a user binds a physical input to a lever, they need to map physical positions to notch boundaries.

### UI Flow

1. **Start Calibration Session**
   ```rust
   // User selects: Lever Config + Hardware Input
   let binding = LeverInputBinding {
       lever_config_id: throttle.id,
       input_id: potentiometer.id,
   };
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
   ```text
   Check coverage:
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

### Implementation

The interactive flow is implemented by the runtime's calibration sessions
(`crates/trenino-runtime/src/hardware/sessions.rs`) together with notch
analysis (`crates/trenino-core/src/calibration/analysis.rs`), which turns
captured stable zones into `SuggestedNotch` boundaries. The guided lever
setup wizard in the desktop UI drives it end to end: it samples the current
normalized position live, lets the user confirm notch boundaries, validates
coverage, and commits the resulting `LeverConfig` transactionally (with
rollback on failure).

## Key Design Decisions

### ✅ Decision 1: Keep 0.0-1.0 Normalization

**Rationale**: Provides hardware independence and cleaner abstraction.

**Implementation**: The lever controller's normalization (calibrated integer ÷ total travel, rounded to 2 decimals) is correct.

### ✅ Decision 2: Support Negative Simulator Values

**Rationale**: Many train controls have negative ranges (reverser, dynamic brake).

**Implementation**: `map_input` already supports this - no changes needed.

### ✅ Decision 3: Store Normalized Values in Notch Schema

**Rationale**: Makes configurations portable across different hardware.

**Implementation**: Current `input_min/input_max` fields are correct - just needed better documentation.

### ✅ Decision 4: Separate Calibration from Mapping

**Rationale**: Single Responsibility Principle - calibration handles hardware quirks, mapping handles game logic.

**Implementation**:
- `trenino_core::hardware::calibration::normalize` handles raw → calibrated integer
- The lever controller (`crates/trenino-runtime/src/train/lever_controller.rs`) handles calibrated integer → normalized float
- `trenino_core::train::lever::map_input` handles normalized float → simulator value

## Migration Path

The current implementation is **architecturally sound**. Only minor improvements needed:

1. ✅ **Documentation** - Added comprehensive docs to clarify the architecture
2. ✅ **Tests** - Added comprehensive tests for negative values and edge cases
3. ⏳ **UI Implementation** - Build interactive calibration interface (future work)

## Summary

| Component | Input | Output | Purpose |
|-----------|-------|--------|---------|
| `calibration::normalize` | Raw ADC value | Calibrated integer (0 to total_travel) | Handle hardware quirks |
| Lever controller normalization | Calibrated integer | Normalized float (0.0-1.0) | Hardware independence |
| `lever::map_input` | Normalized float | Simulator value (any float) | Game logic mapping |

**The key insight**: The 0.0-1.0 normalization layer makes configurations portable across different hardware while still supporting the full range of simulator values (including negative).
