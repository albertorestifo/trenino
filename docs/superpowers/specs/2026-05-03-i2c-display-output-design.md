# I2C Display Output Support

**Date:** 2026-05-03  
**Status:** Approved

## Overview

Add support for i2c-attached display modules as a new output type. The first chip is the Holtek HT16K33, which drives 4- or 8-digit 14-segment LED displays. The architecture is designed to be extensible — adding future i2c chips (MCP23017, ADS1115, etc.) requires only a new chip module and a new enum value, with no changes to the binding schema or controller core loop.

Users configure an i2c module on a device, then create a display binding that maps a simulator endpoint value to what's shown on the display. For simple cases (e.g. speed as a number) a format string suffices. For advanced cases, Lua scripts can drive displays directly via `display.set()`.

This requires firmware ≥ 2.3.0 (the unreleased version introducing HT16K33 support, `WriteSegments (13)`, `SetModuleBrightness (14)`, `ModuleError (15)`, and the `module_type` rename).

---

## 1. Hardware Layer — `Hardware.I2cModule`

New schema and Ecto migration. Table: `device_i2c_modules`.

```
id            integer, PK
device_id     integer, FK → devices
name          string           # e.g. "Speed display"
module_chip   enum             # :ht16k33 (extensible for future chips)
i2c_address   integer          # 0–255; unique per device
brightness    integer          # 0–15 (HT16K33 brightness register)
num_digits    integer          # 4 or 8
inserted_at   utc_datetime
updated_at    utc_datetime
```

Constraints: `i2c_address` unique per device; `brightness` 0–15; `num_digits` must be 4 or 8 (exact values, not a range).

`Hardware.Device` gains `has_many :i2c_modules, I2cModule`.

### Inclusion in device configuration

When a device is configured (the existing `Configure` message sequence), each `I2cModule` is included as an additional `Configure` part with `module_type = 4` (HT16K33) and payload `[i2c_address, brightness, num_digits]`. The `total_parts` count includes both inputs and i2c modules.

### ModuleError handling

After `ConfigurationStored`, the firmware may emit one `ModuleError (15)` per i2c module whose `begin()` failed. The host's serial message handler logs these and the MCP configure tool response includes any module errors (e.g. `{:error, "HT16K33 at 0x70 failed to initialize"}`), surfacing them to the user.

---

## 2. Binding Layer — `Train.DisplayBinding`

New schema and Ecto migration. Table: `train_display_bindings`.

```
id              integer, PK
train_id        integer, FK → trains
i2c_module_id   integer, FK → device_i2c_modules
name            string           # e.g. "Train speed"
endpoint        string           # simulator endpoint path (NodePath.Endpoint format)
format_string   string           # e.g. "{value:.0f}" or "{value}" or "V:{value:.1f}"
enabled         boolean, default true
script_id       integer, FK → scripts, nullable  # reserved for future Lua path
inserted_at     utc_datetime
updated_at      utc_datetime
```

Constraints: `train_id`, `i2c_module_id`, `endpoint`, `format_string` required; unique constraint on `[train_id, i2c_module_id]`.

No condition operators — the value is always sent to the display on every change. The `script_id` field is nullable and reserved; it is not implemented in this iteration.

### Format string rules

- `{value}` — replaced with `to_string(value)` (works for any type: number, boolean, string)
- `{value:.Nf}` — replaced with the value formatted as a float with N decimal places (e.g. `{value:.0f}` → `"42"`)
- Any other text is passed through verbatim (e.g. `"V:{value:.1f}"` → `"V:42.5"`)
- The resulting string is truncated to `num_digits` characters before encoding

---

## 3. Chip Modules

Each i2c chip gets its own module under `Trenino.Hardware`. These modules are pure functions — no process state.

### `Trenino.Hardware.HT16K33`

Responsibilities:
- `encode_string(text, num_digits)` — converts a string into a list of segment byte pairs using a precomputed ASCII-to-14-segment lookup table. Characters not in the table are rendered as space. Result is always exactly `num_digits * 2` bytes (padded with spaces, truncated if too long).
- The ASCII lookup table follows the Adafruit `alphafonttable[]` mapping.

The `DisplayController` dispatches to the appropriate chip module based on `i2c_module.module_chip`. Adding a new chip = new module with the same interface.

---

## 4. Runtime — `DisplayController` GenServer

New GenServer in `Trenino.Train.DisplayController`. Mirrors the existing `OutputController` structure.

**Subscription ID range:** 2000–2999 (distinct from OutputController's 1000–1999).

**Lifecycle:**
1. On start: subscribe to `Train` events; if a train is already active, load bindings.
2. On `{:train_changed, train}`: clean up subscriptions, load bindings for new train.
3. On `{:train_changed, nil}`: clean up, blank all active displays (send zero bytes).
4. On `:poll_displays`: for each subscription, get value → format → encode → `WriteSegments`.

**Poll loop (200 ms):**
```
value      = SimulatorClient.get_subscription(client, sub_id)
text       = DisplayFormatter.format(format_string, value)
chip_mod   = chip_module(i2c_module.module_chip)  # e.g. HT16K33
bytes      = chip_mod.encode_string(text, num_digits)
Hardware.write_segments(port, i2c_address, bytes)
```

Only sends `WriteSegments` when the formatted text changes (debounced by caching last sent text per binding), avoiding unnecessary serial traffic.

**Cleanup on deactivation:** sends blank segment bytes (all zeros) to each display before unsubscribing.

### `Trenino.Train.DisplayFormatter`

Pure module. `format(format_string, value) :: String.t()` — implements the format string rules described in §2. Handles numeric precision specs and string passthrough.

---

## 5. Lua Scripting — `display.set()`

Three small additions to the existing script infrastructure:

1. **`ScriptEngine`** — add `setup_display/1`:
   ```lua
   display.set(i2c_address, text)  -- e.g. display.set(0x70, "42.5")
   ```
   Emits side effect `{:display_set, i2c_address, text}`.

2. **`@type side_effect`** — add `{:display_set, integer(), String.t()}`.

3. **`ScriptRunner`** — handle `{:display_set, i2c_address, text}`: resolve port from config_id, call `Hardware.write_segments(port, i2c_address, text)`.

The text is encoded to segment bytes using `HT16K33.encode_string/2`. The script must know the i2c address of the target display (it is listed in `list_i2c_modules`). Scripts are not chip-aware — `display.set` always uses `HT16K33` encoding (the only supported chip). If multi-chip support is needed in the future, a `display.set_raw(addr, bytes)` variant can be added.

---

## 6. MCP Tools

### Device tools (added to `DeviceTools`)

| Tool | Description |
|------|-------------|
| `list_i2c_modules` | List all i2c modules across all devices |
| `create_i2c_module` | Add an i2c module to a device |
| `update_i2c_module` | Update name, brightness, etc. |
| `delete_i2c_module` | Remove an i2c module |

`create_i2c_module` accepts: `device_id`, `name`, `module_chip` (`"ht16k33"`), `i2c_address` (integer, e.g. `112` for 0x70), `brightness` (0–15), `num_digits` (4 or 8).

### Train tools (new `DisplayBindingTools`)

| Tool | Description |
|------|-------------|
| `list_display_bindings` | List display bindings for a train |
| `create_display_binding` | Create a display binding |
| `update_display_binding` | Update name, endpoint, format_string, enabled |
| `delete_display_binding` | Delete a display binding |

`create_display_binding` accepts: `train_id`, `name`, `i2c_module_id`, `endpoint`, `format_string`, `enabled`.

Tool count in test files must be updated when tools are added. Current count is 29; adding 4 device tools + 4 display binding tools = **37 total**.

---

## 7. LiveView UI Changes

### Device configuration page — `configuration_edit_live.ex`

Add a new "I2C Modules" section to the device configuration page, alongside the existing Inputs and Outputs sections. It lists configured i2c modules (name, chip, address, num_digits, brightness) and provides add/edit/delete actions.

A new inline form component handles create/edit. It is a simple form (not a multi-step wizard — there is no auto-detection and the fields are short):

| Field | Input type | Notes |
|-------|-----------|-------|
| Name | text | e.g. "Speed display" |
| Chip | select | Only `HT16K33` for now |
| I2C address | number | 0–255; shown as decimal, documented as hex (e.g. 112 = 0x70) |
| Brightness | number / range | 0–15 |
| Num digits | select | 4 or 8 |

New LiveComponent: `TreninoWeb.I2cModuleFormComponent`.

### Train edit page — `train_edit_live.ex`

Add a "Display Bindings" section alongside the existing "Output Bindings" section. Lists configured display bindings (name, endpoint, i2c module name, format_string, enabled toggle) with edit/delete actions and an "Add display binding" button.

Opening the wizard requires a simulator connection and at least one i2c module configured on any device; appropriate empty-state messages are shown if either condition is not met.

### New display binding wizard — `display_binding_wizard.ex`

Multi-step wizard (3 steps) analogous to `OutputBindingWizard`:

1. **Select endpoint** — reuses the existing `ApiExplorerComponent`
2. **Select display** — lists configured i2c modules across all devices (chip, address, num_digits, device name)
3. **Configure format + name** — text input for `format_string` with inline syntax hint and a live preview showing what the current value would look like (format applied to a sample value), plus name input

The format string preview renders the string inside a monospace block styled to suggest a segmented display (character-limited to `num_digits`).

### Output binding wizard — `output_binding_wizard.ex`

The existing "Select Type" step has a placeholder: *"More output types (servo, display, etc.) coming soon."* Remove or update this note now that display outputs exist — though they are configured through a separate flow (display bindings), not through the output binding wizard.

---

## 8. Extensibility

Adding a future i2c chip (e.g. MCP23017 GPIO expander):
1. Add new value to `Hardware.I2cModule.module_chip` enum.
2. Add `Trenino.Hardware.MCP23017` module with the appropriate encode/decode interface.
3. `DisplayController` dispatches to the new module based on `module_chip`.
4. No changes to `Train.DisplayBinding`, `DisplayController` core loop, or MCP tool schemas.

---

## 9. Out of Scope

- `SetModuleBrightness (14)` at runtime — brightness is set once at configure time. Runtime brightness control can be added later as a separate MCP tool.
- Scrolling, blinking, or animation effects.
- Value maps (discrete value → display text) — Lua scripting covers this use case.
- Multi-chip `display.set` dispatch in Lua scripts.
