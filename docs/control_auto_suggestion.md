# Control Auto-Suggestion Feature

## Overview

The Control Auto-Suggestion feature automatically detects and suggests Train Sim World API controls that match train element names. This reduces manual configuration by intelligently matching user-created elements (like "Throttle" or "Horn") to the corresponding API controls in the currently loaded train.

## Architecture

### Component Overview

```
┌─────────────────────────────────────┐
│   Desktop UI (Svelte, tauri/ui)     │
│  - Configures train elements        │
│  - Guided setup flows               │
└─────────────┬───────────────────────┘
              │
              │ 1. User names an element
              │    "Throttle" while configuring
              ▼
┌─────────────────────────────────────┐
│   Explorer Service (Rust runtime)   │
│  - Fetches controls from TSW API    │
│  - Classifies as lever or button    │
│  - Matches using fuzzy logic        │
└─────────────┬───────────────────────┘
              │
              │ 2. Queries CurrentDrivableActor
              ▼
┌─────────────────────────────────────┐
│   TSW API (via SimulatorClient)     │
│  - Returns available controls       │
│  - Provides endpoint information    │
└─────────────────────────────────────┘
```

### Key Modules

1. **`simulator::services::explorer`** (`crates/trenino-runtime/src/simulator/services/explorer.rs`)
   - Core detection and matching logic
   - Communicates with the TSW API via `SimulatorClient`
   - Implements fuzzy string matching

2. **Desktop UI** (`tauri/ui/`)
   - Train editor pages and guided setup wizards
   - Apply suggestions through the typed bridge (`src/bridge/`)

## Detection Logic

### Lever Detection

A control is classified as a **lever** if it has the following endpoint:
- `Function.GetNotchCount` - Indicates discrete notch positions

Standard lever endpoints:
```
CurrentDrivableActor/ControlName.InputValue                      (write)
CurrentDrivableActor/ControlName.Function.GetMinimumInputValue   (read)
CurrentDrivableActor/ControlName.Function.GetMaximumInputValue   (read)
CurrentDrivableActor/ControlName.Function.GetNotchCount          (read)
CurrentDrivableActor/ControlName.Function.GetCurrentNotchIndex   (read)
```

### Button Detection

A control is classified as a **button** if it has the following property:
- `Property.bDefaultToPressed` - Indicates button behavior

Standard button endpoint:
```
CurrentDrivableActor/ControlName.InputValue (write)
```

## Matching Algorithm

The matching algorithm uses multiple heuristics to calculate confidence scores:

### Confidence Scoring

| Match Type | Confidence | Example |
|------------|-----------|---------|
| Exact match (case-insensitive) | 1.0 | "throttle" = "throttle" |
| Element name in control name | 0.85 | "throttle" in "Throttle(Lever)" |
| Control name in element name | 0.75 | "Horn" in "Horn Button" |
| Common word matches | `(min(0.5 + 0.2 × shared_words, 0.9) + Jaro) / 2` | "Train Brake" ~ "Train_Brake" (2 shared words: (0.9 + Jaro)/2) |
| Jaro distance fallback | 0.0-1.0 | Fuzzy string similarity |

Names are lowercased before tokenization, so the CamelCase splitting used
elsewhere does not apply here — "TrainBrake" stays a single token. "Train
Brake" vs "TrainBrake" therefore shares no words and resolves through the
Jaro-distance rung alone (≈ 0.97).

Ties keep the first candidate, like the original `Enum.max_by/2` behavior.

### Confidence Threshold

Suggestions are only returned if confidence > 0.3 (30% match); otherwise the
result is `SuggestError::NoMatch`.

### Name Pattern Examples

Based on analysis of 5 different trains:

**Throttle:**
- `Throttle`
- `MasterController`
- `Throttle_F`
- `Throttle(Lever)`

**Reverser:**
- `Reverser`
- `Reverser_F`
- `Reverser(Lever)`

**Train Brake:**
- `TrainBrake`
- `AutomaticBrake`
- `Westcode3StepBrake`

**Horn:**
- `Horn`
- `Horn_FL`
- `Horn_R(Lever)`

**Safety Systems:**
- `AWS_ResetButton`
- `PZB_Acknowledge`
- `AlerterReset`
- `Acknowledge`

**Vigilance:**
- `DSDPedal`
- `SifaPedal`
- `DeadmanFootSwitch`

## User Flow

### Lever Configuration

1. User creates an element named "Throttle" (type: lever)
2. If the simulator is connected, `suggest_lever` finds the best-matching
   control and its endpoints
3. The guided lever setup applies the endpoints (and, for notch layout, the
   suggested notches produced by lever analysis)
4. User can still manually configure if they prefer

### Button Configuration

1. User creates an element named "Horn" (type: button)
2. If the simulator is connected, `suggest_button` finds the best-matching
   control and its `InputValue` endpoint
3. User can still manually configure if they prefer

## API Reference

All functions live in `crates/trenino-runtime/src/simulator/services/explorer.rs`.

### `explorer::suggest_lever`

Suggests a lever control matching the given element name.

```rust
pub async fn suggest_lever(
    client: &SimulatorClient,
    element_name: &str,
) -> Result<LeverSuggestion, SuggestError>;

// Example result
LeverSuggestion {
    lever: LeverControl {
        name: "Throttle(Lever)".into(),
        min_endpoint: "CurrentDrivableActor/Throttle(Lever).Function.GetMinimumInputValue".into(),
        max_endpoint: "CurrentDrivableActor/Throttle(Lever).Function.GetMaximumInputValue".into(),
        value_endpoint: "CurrentDrivableActor/Throttle(Lever).InputValue".into(),
        notch_count_endpoint: "CurrentDrivableActor/Throttle(Lever).Function.GetNotchCount".into(),
        notch_index_endpoint: "CurrentDrivableActor/Throttle(Lever).Function.GetCurrentNotchIndex".into(),
    },
    confidence: 0.85,
}
```

**Returns:**
- `Ok(suggestion)` - Match found with confidence > 0.3
- `Err(SuggestError::Simulator(..))` - Simulator unreachable or API error
- `Err(SuggestError::NoMatch)` - No matching control found

### `explorer::suggest_button`

Suggests a button control matching the given element name.

```rust
pub async fn suggest_button(
    client: &SimulatorClient,
    element_name: &str,
) -> Result<ButtonSuggestion, SuggestError>;

// Example result
ButtonSuggestion {
    button: ButtonControl {
        name: "Horn".into(),
        endpoint: "CurrentDrivableActor/Horn.InputValue".into(),
    },
    confidence: 1.0,
}
```

**Returns:**
- `Ok(suggestion)` - Match found with confidence > 0.3
- `Err(SuggestError::Simulator(..))` - Simulator unreachable or API error
- `Err(SuggestError::NoMatch)` - No matching control found

### Related helpers

- `explorer::list_controls(client)` - Binary control names under `CurrentDrivableActor`
- `explorer::detect_levers(client)` / `detect_buttons(client)` - Full classified lists
- `explorer::resolve_lever_endpoints(client, path)` - Resolve one selected control
  (used by guided simulator sessions) using the same notch-count classification

## Testing

Integration tests live in `crates/trenino-runtime/tests/simulator_detection.rs`,
exercising `list_controls`, `detect_levers`, `detect_buttons` and both
`suggest_*` functions against a fake simulator:

```bash
cargo test -p trenino-runtime --test simulator_detection
```

### Manual Testing

1. Start TSW with API enabled
2. Load a train (e.g., any locomotive)
3. In the app, create a new train configuration
4. Add elements with common names: "Throttle", "Reverser", "Horn", "Train Brake"
5. Verify the guided flows resolve the expected endpoints
6. Save configuration and test in simulator

## Performance Considerations

### API Calls

The explorer makes the following API calls when suggesting:
1. `client.list(Some("CurrentDrivableActor"))` - Lists all controls (~50-200 controls)
2. For each control: `client.list(Some(path))` - Lists endpoints (~5-10 per control)

**Total calls:** O(n) where n = number of controls

**Optimization:** Results are computed on demand; `resolve_lever_endpoints`
avoids relisting every control when the user has already picked one.

### Caching

Currently, no caching is implemented. Each suggestion run triggers fresh API
calls. Future enhancements could:
- Cache control list for current train
- Invalidate cache when train changes
- Pre-fetch on train activation

## Error Handling

The system gracefully handles errors:

1. **Simulator not connected** - Caller gets `SuggestError::Simulator(..)`; the UI
   falls back to manual configuration
2. **API timeout** - Reported as `SuggestError::Simulator(..)`
3. **No matching control** - `SuggestError::NoMatch`
4. **Invalid control structure** - Silently skipped during detection

## Future Enhancements

1. **Learning System** - Track which suggestions users accept/reject to improve confidence scoring
2. **Caching** - Cache control list for current train to reduce API calls
3. **Batch Suggestion** - Suggest all controls at once when creating a new train
4. **Control Templates** - Pre-built templates for common train types (diesel, electric, steam)
5. **Alias Support** - Allow users to define custom name mappings
6. **Multi-language Support** - Handle control names in different languages

## Troubleshooting

### Suggestion not appearing

**Possible causes:**
1. Simulator not connected - Check connection status in the app
2. No matching control in current train - Try different element name
3. Confidence too low (<30%) - Element name too generic or typo

**Solutions:**
- Verify simulator connection
- Check the TSW API is enabled
- Try more specific element names ("Throttle" vs "Lever 1")

### Wrong control suggested

**Possible causes:**
1. Multiple similar controls in train
2. Fuzzy matching picked wrong one

**Solutions:**
- Ignore suggestion and manually configure
- Use more specific element names
- Check confidence score - low scores indicate uncertain match

## Related Documentation

- [TSW API Documentation](TSW_API_GUIDE.md)
- Simulator client (`crates/trenino-runtime/src/simulator/client.rs`)
- [Train Configuration Guide](train-configuration.md)
