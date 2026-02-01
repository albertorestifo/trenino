# Lua Scripting for Trenino

Skill for authoring and managing Lua scripts in Trenino train configurations.

## Overview

Trenino supports Lua scripts attached to train configurations. Scripts react to simulator API value changes and can control hardware outputs. Each script has an `on_change(event)` callback that fires when trigger endpoint values change.

## Lua API Reference

### Callback

```lua
function on_change(event)
  -- Called when a trigger endpoint value changes, on schedule, or manually
end
```

### Event Object

| Field | Type | Description |
|-------|------|-------------|
| `event.source` | string | Trigger endpoint path, `"scheduled"`, or `"manual"` |
| `event.value` | number/string/nil | Current value of the trigger endpoint |
| `event.data` | table/nil | Full data table from the subscription response |

### Functions

| Function | Description |
|----------|-------------|
| `api.get(path)` | Read a simulator API endpoint. Returns `value, err`. |
| `api.set(path, value)` | Write a value to a simulator API endpoint. Returns `ok, err`. |
| `output.set(id, on)` | Set a hardware output. `id` is the database output ID (integer), `on` is boolean. |
| `schedule(ms)` | Schedule `on_change` to fire again after `ms` milliseconds with source `"scheduled"`. |
| `print(...)` | Log a message to the script console. Multiple args are tab-separated. |

### State

```lua
state.my_variable = 42  -- Persists across invocations within the same session
```

The `state` table persists in memory across `on_change` calls. It resets when the script is reloaded (edited, toggled, or app restarts).

## Constraints

- **Execution timeout**: 200ms per invocation. Scripts that exceed this are killed.
- **Sandboxed**: No file I/O, no `os` module, no `require`. Only the Trenino API is available.
- **Side-effect based**: `api.get` and `api.set` collect side effects. `api.get` returns nil during script execution; use `event.value` for the trigger value instead.

## Event Sources

| Source | When |
|--------|------|
| Endpoint path (e.g., `"CurrentDrivableActor/Throttle.InputValue"`) | Trigger endpoint value changed |
| `"scheduled"` | Fired by a previous `schedule(ms)` call |
| `"manual"` | User clicked "Run" in the editor UI |

## Common Patterns

### Simple threshold alert
```lua
function on_change(event)
  if event.value and event.value > 100 then
    output.set(3, true)  -- Turn on warning LED
  else
    output.set(3, false)
  end
end
```

### Debounced action
```lua
function on_change(event)
  state.last_value = event.value
  schedule(500)  -- Wait 500ms before acting
end

-- When source is "scheduled", the value has been stable
function on_change(event)
  if event.source == "scheduled" and state.last_value then
    api.set("SomeEndpoint", state.last_value)
  elseif event.source ~= "scheduled" then
    state.last_value = event.value
    schedule(500)
  end
end
```

### LED blink pattern
```lua
function on_change(event)
  if event.source == "manual" or event.source == "scheduled" then
    if state.blink_on then
      output.set(5, false)
      state.blink_on = false
    else
      output.set(5, true)
      state.blink_on = true
    end
    schedule(500)  -- Toggle every 500ms
  end
end
```

### State machine
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

## Workflow

When creating or modifying scripts:

1. **Discover available outputs**: Use `GET /api/outputs` to list hardware outputs with their IDs, names, pins, and devices.
2. **Browse simulator endpoints**: Use `GET /api/simulator/endpoints?path=<path>` to explore the simulator API tree. Use `GET /api/simulator/value?path=<path>` to read current values.
3. **List existing scripts**: Use `GET /api/trains/:train_id/scripts` to see what scripts already exist for the train.
4. **Create/update scripts**: Use `POST /api/trains/:train_id/scripts` or `PUT /api/scripts/:id` with `name`, `code`, `triggers`, and `enabled` fields.
5. **Test**: Use the "Run" button in the script editor UI or rely on trigger endpoints to fire `on_change`.

## REST API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/trains` | List all trains |
| GET | `/api/trains/:id` | Get train details with elements and output bindings |
| GET | `/api/trains/:id/scripts` | List scripts for a train |
| POST | `/api/trains/:id/scripts` | Create a new script |
| GET | `/api/scripts/:id` | Get a single script |
| PUT | `/api/scripts/:id` | Update a script |
| DELETE | `/api/scripts/:id` | Delete a script |
| GET | `/api/outputs` | List all hardware outputs |
| GET | `/api/simulator/endpoints?path=<path>` | Browse simulator API tree |
| GET | `/api/simulator/value?path=<path>` | Get current value of an endpoint |

## Script Schema

```json
{
  "id": 1,
  "train_id": 1,
  "name": "Speed Warning",
  "enabled": true,
  "code": "function on_change(event) ... end",
  "triggers": ["CurrentDrivableActor.Function.HUD_GetSpeed"],
  "inserted_at": "2026-02-01T12:00:00Z",
  "updated_at": "2026-02-01T12:00:00Z"
}
```

## File Locations

- Script schema: `lib/trenino/train/script.ex`
- Script CRUD: `lib/trenino/train.ex` (Script functions section)
- Lua engine: `lib/trenino/train/script_engine.ex`
- Script runner: `lib/trenino/train/script_runner.ex`
- REST API: `lib/trenino_web/controllers/api/script_controller.ex`
- Editor UI: `lib/trenino_web/live/script_edit_live.ex`
- Train page scripts section: `lib/trenino_web/live/train_edit_live.ex`
