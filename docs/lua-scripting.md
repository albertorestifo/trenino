# Lua Scripting Guide

Write custom Lua scripts to add smart behavior to your trains — flash warning LEDs, react to speed changes, automate startup sequences, and more.

## How It Works

Each script has an `on_change` function that Trenino calls when something happens: a simulator value changes, a timer fires, or you click **Run** in the editor. Your script reads the event, decides what to do, and calls functions to control hardware outputs or write values to the simulator.

Scripts are sandboxed — they can only interact with the simulator and your hardware through the Trenino API. There's no file access or network access.

## Creating a Script

1. Open your train configuration
2. Scroll to the **Scripts** section and click **New Script**
3. Give it a name, write your code, add triggers, and click **Create**

## Your First Script

Every script needs an `on_change` function. Here's a minimal example:

```lua
function on_change(event)
  print("triggered by: " .. tostring(event.source))
  print("value: " .. tostring(event.value))
end
```

This logs which trigger fired and what value it has. Check the **Console** panel in the editor to see the output.

## The Event Object

When `on_change` is called, it receives an `event` table with:

| Field | Type | Description |
|-------|------|-------------|
| `event.source` | string | What triggered the script (see below) |
| `event.value` | number/string/nil | Current value of the trigger endpoint |
| `event.data` | table/nil | Full data from the subscription response |

### Event Sources

| Source | When it fires |
|--------|---------------|
| An endpoint path (e.g. `"CurrentDrivableActor/Throttle.InputValue"`) | The trigger endpoint's value changed in the simulator |
| `"scheduled"` | A timer you set with `schedule()` has fired |
| `"manual"` | You clicked **Run** in the script editor |

## Triggers

Triggers tell Trenino which simulator endpoints your script cares about. When a trigger endpoint's value changes, your script's `on_change` function is called.

Add triggers in the script editor by typing the endpoint path and clicking **Add**. You can find endpoint paths using the simulator API explorer in the train configuration page.

A script with no triggers will only run when you click **Run** or when a `schedule()` timer fires.

## API Reference

### `api.set(path, value)`

Write a value to a simulator endpoint.

```lua
api.set("CurrentDrivableActor/Horn.InputValue", 1.0)
```

### `api.get(path)`

Request a read from a simulator endpoint. Note: during script execution this returns `nil` — use `event.value` to read the current trigger value instead.

```lua
local val, err = api.get("CurrentDrivableActor/Throttle.InputValue")
-- val is nil during execution; use event.value for trigger values
```

### `output.set(id, on)`

Turn a hardware output (LED, relay, etc.) on or off. The `id` is the output's database ID — expand **Hardware Outputs Reference** in the script editor to see available IDs.

```lua
output.set(3, true)   -- Turn on output #3
output.set(3, false)  -- Turn it off
```

### `display.set(i2c_address, text)`

Write text directly to an I2C display module. `i2c_address` is the integer I2C address of the module (e.g., `0x70` = `112`). The text is rendered as segment characters; unsupported characters are shown as blank.

```lua
display.set(0x70, "42")    -- Show "42" on display at address 0x70
display.set(0x71, "STOP")  -- Show "STOP" on display at address 0x71
```

Use this when you need dynamic or script-computed content on a display. For simple endpoint-to-display mirroring, [display bindings](train-configuration.md#display-bindings) are easier to configure and don't require a script.

### `schedule(ms)`

Schedule `on_change` to fire again after the given number of milliseconds. The event source will be `"scheduled"`. Only one timer per script can be active — calling `schedule` again replaces the previous timer.

```lua
schedule(1000)  -- Fire on_change again in 1 second
```

### `print(...)`

Log a message to the script's console. Multiple arguments are separated by tabs.

```lua
print("speed is", event.value)
```

### `state`

A global table that persists across `on_change` calls within the same session. Use it to remember values between invocations. State resets when the script is edited, toggled, or the app restarts.

```lua
state.counter = (state.counter or 0) + 1
print("called " .. state.counter .. " times")
```

## Examples

### Speed warning LED

Turn on a warning LED when the train exceeds 100 km/h.

**Trigger:** `CurrentDrivableActor.Function.HUD_GetSpeed`

```lua
function on_change(event)
  if event.value and event.value > 100 then
    output.set(3, true)
  else
    output.set(3, false)
  end
end
```

### Blinking LED

Blink an LED on and off every 500ms. Click **Run** to start the blink loop.

```lua
function on_change(event)
  if event.source == "manual" or event.source == "scheduled" then
    state.on = not state.on
    output.set(5, state.on)
    schedule(500)
  end
end
```

### Debounced action

Wait for a value to stabilize for 500ms before acting on it. Useful to avoid reacting to rapid intermediate changes.

```lua
function on_change(event)
  if event.source == "scheduled" then
    -- Value has been stable for 500ms, act on it
    api.set("SomeEndpoint", state.last_value)
  else
    -- Value changed, start/restart the timer
    state.last_value = event.value
    schedule(500)
  end
end
```

### State machine

Track modes like idle, active, and cooldown with different behaviors in each.

```lua
function on_change(event)
  if state.mode == nil then state.mode = "idle" end

  if state.mode == "idle" and event.value > 0 then
    state.mode = "active"
    output.set(1, true)
    print("Activated")
  elseif state.mode == "active" and event.value == 0 then
    state.mode = "cooldown"
    output.set(1, false)
    schedule(2000)
    print("Cooling down...")
  elseif state.mode == "cooldown" and event.source == "scheduled" then
    state.mode = "idle"
    print("Ready")
  end
end
```

## Tips and Limitations

- **200ms execution limit** — scripts that take longer are terminated. Keep your logic simple and avoid infinite loops.
- **Use `event.value`** for the trigger's current value. `api.get()` returns `nil` during execution.
- **One timer per script** — calling `schedule()` replaces any pending timer.
- **State is in-memory** — it survives across `on_change` calls but resets on script reload or app restart.
- **Console limit** — the console keeps the last 100 log entries.
- **Sandboxed environment** — `require`, `io`, `os`, `file`, and `package` are not available.
