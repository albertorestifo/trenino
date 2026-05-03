# Display UI Improvements Design

**Date:** 2026-05-03

## Overview

Three targeted UI improvements to the I2C display configuration:

1. Brightness slider (0–100%) instead of a raw 0–15 number input
2. Fix button alignment in the I2C modules table
3. Add a timed display test sequence

---

## 1. Brightness Slider

### Problem
The brightness field currently shows a number input capped at 0–15, which has no user-legible meaning.

### Solution
- Change `I2cModuleFormComponent` brightness input to `type="range"` with min=0, max=100, displaying the percentage value next to the slider.
- `coerce_params/1` receives `brightness_pct` (0–100 integer) and converts: `wire = round(pct * 15 / 100)` before passing to the changeset.
- On load, convert the stored value (0–15) to display percentage: `pct = round(wire * 100 / 15)`.
- The I2C modules table in `configuration_edit_live.ex` shows "X%" instead of the raw wire value.
- No DB migration required — the schema continues to store 0–15.

### Files
- `lib/trenino_web/live/components/i2c_module_form_component.ex`
- `lib/trenino_web/live/configuration_edit_live.ex` (table display only)

---

## 2. Button Alignment Fix

### Problem
The `i2c_modules_section` action column uses `<td class="text-right">` with buttons placed directly inside, unlike every other table in the page which wraps buttons in `<div class="flex gap-1">`.

### Solution
Remove `text-right` from the `<td>`, wrap the edit and delete buttons in `<div class="flex gap-1">` — matching the pattern used in `inputs_table`, `matrices_table`, `outputs_table`, and the display bindings table.

### Files
- `lib/trenino_web/live/configuration_edit_live.ex`

---

## 3. Display Test (Timed Sequence)

### Problem
There is no way to verify a display is wired and working without having a full train binding active.

### Solution
Add a "Test" column to the I2C modules table, only visible when `active_port != nil` (same pattern as the Outputs Test column). Each row shows a test button.

**Sequence (1 second per step):**
- t=0s: all-8s string (e.g. "8888" / "88888888") — lights all segments
- t+1s: "1234" or "12345678"
- t+2s: "ABCD" or "ABCDEFGH"
- t+3s: blank (clear)

**Implementation:**
- `i2c_modules_section` gets an `active_port` attr (currently only has `new_mode`).
- Event handler `"test_display"` encodes the first string with `HT16K33.encode_string/2` and calls `Hardware.write_segments/3` immediately, then schedules `{:display_test_step, mod_id, step}` messages via `Process.send_after`.
- `handle_info({:display_test_step, mod_id, step}, socket)` looks up the module, encodes the text for that step, writes to the port, and schedules the next step if any remain.
- String selection is digit-count–aware: 4-digit vs 8-digit modules get appropriately-sized strings.

### Files
- `lib/trenino_web/live/configuration_edit_live.ex`
