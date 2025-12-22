# Control Auto-Suggestion Feature

## Overview

The Control Auto-Suggestion feature automatically detects and suggests Train Sim World 6 API controls that match train element names. This reduces manual configuration by intelligently matching user-created elements (like "Throttle" or "Horn") to the corresponding API controls in the currently loaded train.

## Architecture

### Component Overview

```
┌─────────────────────────────────────┐
│   TrainEditLive (Phoenix LiveView)  │
│  - Configures train elements        │
│  - Opens configuration modals       │
└─────────────┬───────────────────────┘
              │
              │ 1. User clicks "Configure"
              │    on element named "Throttle"
              ▼
┌─────────────────────────────────────┐
│   ControlDetector Module            │
│  - Fetches controls from TSW API    │
│  - Classifies as lever or button    │
│  - Matches using fuzzy logic        │
└─────────────┬───────────────────────┘
              │
              │ 2. Queries CurrentDrivableActor
              ▼
┌─────────────────────────────────────┐
│   TSW API (via Client)              │
│  - Returns available controls       │
│  - Provides endpoint information    │
└─────────────────────────────────────┘
```

### Key Modules

1. **TswIo.Simulator.ControlDetector** (`lib/tsw_io/simulator/control_detector.ex`)
   - Core detection and matching logic
   - Communicates with TSW API via Client
   - Implements fuzzy string matching

2. **TswIoWeb.TrainEditLive** (`lib/tsw_io_web/live/train_edit_live.ex`)
   - UI integration
   - Event handlers for applying suggestions
   - Modal components with suggestion UI

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
| Common word matches | 0.5-0.9 | "Train Brake" ~ "TrainBrake" |
| Jaro distance fallback | 0.0-1.0 | Fuzzy string similarity |

### Confidence Threshold

Suggestions are only shown if confidence > 0.3 (30% match).

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
2. User clicks "Configure" on the element
3. Modal opens with lever configuration form
4. If simulator is connected:
   - `ControlDetector.suggest_lever("Throttle")` is called
   - If match found, suggestion box appears at top of modal
   - Shows control name and confidence percentage
   - User can click "Apply Suggestion" to auto-fill all fields
5. User can still manually configure if they prefer

### Button Configuration

1. User creates an element named "Horn" (type: button)
2. User clicks "Configure" on the element
3. Modal opens with button configuration form
4. If simulator is connected:
   - `ControlDetector.suggest_button("Horn")` is called
   - If match found, suggestion box appears at top of modal
   - Shows control name and confidence percentage
   - User can click "Apply Suggestion" to auto-fill endpoint field
5. User can still manually configure if they prefer

## UI Components

### Suggestion Box (Lever)

```heex
<div class="p-4 bg-success/10 border border-success/30 rounded-lg">
  <div class="flex items-start justify-between gap-3">
    <div class="flex-1">
      <div class="flex items-center gap-2 mb-2">
        <.icon name="hero-light-bulb" class="w-5 h-5 text-success" />
        <h3 class="font-semibold text-success">Suggested Control Found</h3>
        <span class="badge badge-sm badge-success">85% match</span>
      </div>
      <p class="text-sm text-base-content/70 mb-2">
        Found control: <span class="font-mono text-sm">Throttle(Lever)</span>
      </p>
      <button type="button" phx-click="apply_lever_suggestion" class="btn btn-success btn-sm">
        <.icon name="hero-arrow-down-tray" class="w-4 h-4" />
        Apply Suggestion
      </button>
    </div>
  </div>
</div>
```

### Suggestion Box (Button)

Similar UI, but applies to button endpoint field only.

## API Reference

### `ControlDetector.suggest_lever/1`

Suggests a lever control matching the given element name.

```elixir
@spec suggest_lever(String.t()) :: {:ok, lever_suggestion()} | {:error, term()}

# Example
{:ok, %{
  control_name: "Throttle(Lever)",
  min_endpoint: "CurrentDrivableActor/Throttle(Lever).Function.GetMinimumInputValue",
  max_endpoint: "CurrentDrivableActor/Throttle(Lever).Function.GetMaximumInputValue",
  value_endpoint: "CurrentDrivableActor/Throttle(Lever).InputValue",
  notch_count_endpoint: "CurrentDrivableActor/Throttle(Lever).Function.GetNotchCount",
  notch_index_endpoint: "CurrentDrivableActor/Throttle(Lever).Function.GetCurrentNotchIndex",
  confidence: 0.85
}}
```

**Returns:**
- `{:ok, suggestion}` - Match found with confidence > 0.3
- `{:error, :not_connected}` - Simulator not connected
- `{:error, :no_match}` - No matching control found

### `ControlDetector.suggest_button/1`

Suggests a button control matching the given element name.

```elixir
@spec suggest_button(String.t()) :: {:ok, button_suggestion()} | {:error, term()}

# Example
{:ok, %{
  control_name: "Horn",
  endpoint: "CurrentDrivableActor/Horn.InputValue",
  confidence: 1.0
}}
```

**Returns:**
- `{:ok, suggestion}` - Match found with confidence > 0.3
- `{:error, :not_connected}` - Simulator not connected
- `{:error, :no_match}` - No matching control found

## Testing

### Unit Tests

Located in `test/tsw_io/simulator/control_detector_test.exs`

Run tests:
```bash
mix test test/tsw_io/simulator/control_detector_test.exs
```

### Integration Tests

Integration tests require a running TSW6 instance with API enabled. Tag with `@tag :integration`.

Run integration tests only:
```bash
mix test --only integration
```

Skip integration tests:
```bash
mix test --exclude integration
```

### Manual Testing

1. Start TSW6 with API enabled
2. Load a train (e.g., any locomotive)
3. In the app, create a new train configuration
4. Add elements with common names: "Throttle", "Reverser", "Horn", "Train Brake"
5. Click "Configure" on each element
6. Verify suggestions appear with appropriate confidence scores
7. Click "Apply Suggestion" and verify fields are populated correctly
8. Save configuration and test in simulator

## Performance Considerations

### API Calls

The detector makes the following API calls when suggesting:
1. `list(client, "CurrentDrivableActor")` - Lists all controls (~50-200 controls)
2. For each control: `list(client, path)` - Lists endpoints (~5-10 per control)

**Total calls:** O(n) where n = number of controls

**Optimization:** Results are computed on-demand only when opening configuration modals.

### Caching

Currently, no caching is implemented. Each modal open triggers fresh API calls. Future enhancements could:
- Cache control list for current train
- Invalidate cache when train changes
- Pre-fetch on train activation

## Error Handling

The system gracefully handles errors:

1. **Simulator not connected** - No suggestion shown, user can still manually configure
2. **API timeout** - Returns `{:error, :not_connected}`, no suggestion shown
3. **No matching control** - Returns `{:error, :no_match}`, no suggestion shown
4. **Invalid control structure** - Silently skipped during detection

## Future Enhancements

1. **Learning System** - Track which suggestions users accept/reject to improve confidence scoring
2. **Caching** - Cache control list for current train to reduce API calls
3. **Batch Suggestion** - Suggest all controls at once when creating a new train
4. **Control Templates** - Pre-built templates for common train types (diesel, electric, steam)
5. **Alias Support** - Allow users to define custom name mappings
6. **Multi-language Support** - Handle control names in different languages

## Implementation Notes

### Type Safety

Following project guidelines, the code uses proper struct matching:

```elixir
defp get_client do
  case Connection.get_status() do
    %{status: :connected, client: client} when not is_nil(client) ->
      {:ok, client}
    _ ->
      {:error, :not_connected}
  end
end
```

### Float Precision

Not applicable to this feature (handles strings/atoms only).

### Error Propagation

Uses `{:ok, result} | {:error, reason}` tuples consistently throughout.

## Troubleshooting

### Suggestion not appearing

**Possible causes:**
1. Simulator not connected - Check connection status in nav bar
2. No matching control in current train - Try different element name
3. Confidence too low (<30%) - Element name too generic or typo

**Solutions:**
- Verify simulator connection
- Check TSW6 API is enabled
- Try more specific element names ("Throttle" vs "Lever 1")

### Wrong control suggested

**Possible causes:**
1. Multiple similar controls in train
2. Fuzzy matching picked wrong one

**Solutions:**
- Ignore suggestion and manually configure
- Use more specific element names
- Check confidence score - low scores indicate uncertain match

### Apply button doesn't work

**Possible causes:**
1. JavaScript error in browser
2. Network issue

**Solutions:**
- Check browser console for errors
- Refresh page
- Manually copy/paste suggested control name

## Related Documentation

- [TSW6 API Documentation](../tsw_api.md)
- [Simulator Client Module](../lib/tsw_io/simulator/client.ex)
- [Train Configuration Guide](../train_configuration.md)
