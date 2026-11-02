# I2C Input Modules Host Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users configure MCP23017 and ADS1115 chips in Trenino, with their inputs behaving like any other input.

**Architecture:** Each chip is an `I2cModule` that owns child `Input` rows on allocated virtual pins, so existing `{port, pin}` consumers keep working. Chip configuration reaches the device as one `Configure` part. Failed chips are tracked from `ModuleError` and shown in the UI.

**Tech Stack:** Elixir, Phoenix LiveView, Ecto with SQLite, PolymorphicEmbed.

**Spec:** `docs/superpowers/specs/2026-11-01-i2c-input-modules-design.md`

**Companion plan:** `trenino_firmware/docs/superpowers/plans/2026-11-01-i2c-input-modules.md`. The firmware defines the wire format below.

## Global Constraints

- Chip configuration requires firmware ≥ 3.2.0, returning `:firmware_update_required` otherwise.
- At most 8 modules per device, counting inputs, matrices and I2C modules.
- Virtual pins are 128–255, allocated first fit from 255 downward.
- GPA7 and GPB7 (mask `0x8080`) are never direct or column pins.
- MCP23017 addresses 0x20–0x27. ADS1115 addresses 0x48–0x4B.
- Existing devices must not show as "unapplied" after this ships, so the fingerprint term stays identical for configurations with no input chip.
- Run `mix test`, and `mix precommit` before the final commit of each task. Follow `CLAUDE.md`: pattern match structs, use `Trenino.DataCase` or `TreninoWeb.ConnCase`, and synchronize with `Trenino.PubSubHelpers.wait_for_subscriber/2`.
- Adding MCP tool parameters changes no tool count. Adding a tool does, per `CLAUDE.md`.

## Review Focus

1. Editing a matrix to a different shape keeps the bindings and calibration of cells that still exist.
2. Script `display.set` on an address that belongs to an input chip logs a warning and does not crash.
3. A device with no input chips keeps the same fingerprint, so it does not ask to be reapplied.
4. Creating a board-pin matrix whose pins overlap a chip's block returns a changeset error, not a crash.
5. A chip whose device's firmware version is unknown is refused, not sent.

## Wire format

```
MCP23017 (0x05): [addr][direct_base][matrix_base][debounce]
                 [direct_mask:u16le][row_mask:u16le][col_mask:u16le]
ADS1115  (0x06): [addr][pin_base][channel_mask][gain][ref_channel][sensitivity:u8*4]
```

`ref_channel` is `0xFF` for none. A base of 0 means the block is unused. Sensitivity of a disabled channel is sent as 0.

## Child input identity

`Input.i2c_channel` identifies a child across edits, whatever its pin becomes:

| Child | `i2c_channel` | `pin` |
|---|---|---|
| MCP direct | `bit` | `direct_base + bit` |
| MCP matrix cell | `16 + row_bit * 16 + col_bit` | `matrix_base + row_index * cols + col_index` |
| ADS channel | `channel` | `pin_base + channel` |

`row_bit` and `col_bit` are chip pin numbers. `row_index` and `col_index` are positions among the set bits, in ascending order.

## File Structure

| File | Responsibility |
|---|---|
| `lib/trenino/hardware/mcp23017/params.ex` (new) | MCP params and validation |
| `lib/trenino/hardware/ads1115/params.ex` (new) | ADS params and validation |
| `lib/trenino/hardware/i2c_inputs.ex` (new) | Pin allocation, expected child list, child sync |
| `lib/trenino/hardware/i2c_module.ex` | Chip enum, embed, `input_chip?/1` |
| `lib/trenino/hardware/input.ex` | `i2c_module_id`, `i2c_channel`, pin rule |
| `lib/trenino/hardware.ex` | Lifecycle, filters, fingerprint, calibration options |
| `lib/trenino/hardware/configuration_manager.ex` | Configure parts, gates, failure tracking |

---

### Task 1: Configure encoding

**Files:**
- Modify: `lib/trenino/serial/protocol/configure.ex`
- Test: `test/trenino/serial/protocol/configure_test.exs`

**Interfaces:**
- Produces: `Configure` fields `direct_base`, `matrix_base`, `direct_mask`, `row_mask`, `col_mask`, `pin_base`, `channel_mask`, `gain`, `ref_channel`, `sensitivities`, with existing `i2c_address` and `debounce`. `input_type` gains `:mcp23017 | :ads1115`. `ref_channel` is `nil` in the struct and `0xFF` on the wire. `sensitivities` is a 4-element list.

- [ ] **Step 1: Write failing tests:** `encodes mcp23017` and `encodes ads1115` asserting exact bytes, including little-endian masks, plus round trips, `nil ref_channel encodes as 0xFF`, and `rejects a truncated mcp23017 body`.
- [ ] **Step 2: Run** `mix test test/trenino/serial/protocol/configure_test.exs`. Expected: FAIL.
- [ ] **Step 3: Implement** encode and `decode_body` clauses, and update the moduledoc.
- [ ] **Step 4: Run** the test. Expected: PASS.
- [ ] **Step 5: Commit** `feat: encode MCP23017 and ADS1115 configure messages`.

### Task 2: Chip params and validation

**Files:**
- Create: `lib/trenino/hardware/mcp23017/params.ex`, `lib/trenino/hardware/ads1115/params.ex`
- Modify: `lib/trenino/hardware/i2c_module.ex`
- Test: `test/trenino/hardware/i2c_module_test.exs`

**Interfaces:**
- Produces:
  - `Trenino.Hardware.MCP23017.Params`: integer fields `direct_base`, `matrix_base`, `debounce`, `direct_mask`, `row_mask`, `col_mask`, with the masks defaulting to 0.
  - `Trenino.Hardware.ADS1115.Params`: `pin_base`, `channel_mask`, `gain` default 0, `ref_channel` nil.
  - `I2cModule.module_chip` adds `:mcp23017, :ads1115`. Embed types identify by `[:direct_mask, :row_mask, :col_mask]` and `[:channel_mask, :gain]`.
  - `I2cModule.input_chip?(%I2cModule{}) :: boolean()`.
  - `MCP23017.Params.default_debounce(row_mask) :: 3 | 2`: 3 with no matrix, otherwise 2.

- [ ] **Step 1: Write failing tests,** one for each spec rule: overlapping masks, bit 7 or 15 in direct or col, more than 8 rows or cols, rows without cols, gain other than 0 or 1, `ref_channel` inside `channel_mask`, `ref_channel` outside 0–3, an empty chip with no channels, `0x28` on an MCP, `0x20` on an ADS1115, `row_mask 0x8080 with col_mask 0x7F7F is valid`, `debounce defaults from layout`, `HT16K33 changesets unchanged`, and `module_chip cannot change on update`.
- [ ] **Step 2: Run** `mix test test/trenino/hardware/i2c_module_test.exs`. Expected: FAIL.
- [ ] **Step 3: Implement.** Address validation lives in `I2cModule.changeset`, per chip, and leaves HT16K33's existing range alone.
- [ ] **Step 4: Run** the test. Expected: PASS.
- [ ] **Step 5: Commit** `feat: add MCP23017 and ADS1115 params`.

### Task 3: Child inputs and filters

**Files:**
- Create: `priv/repo/migrations/20261101100000_add_i2c_module_to_device_inputs.exs`
- Modify: `lib/trenino/hardware/input.ex`, `lib/trenino/hardware.ex`, `lib/trenino/train/lever_controller.ex`, `lib/trenino_web/live/components/lever_setup_wizard.ex`
- Test: `test/trenino/hardware/input_test.exs`, a new `test/trenino/hardware/i2c_inputs_test.exs`

**Interfaces:**
- Produces:
  - `Input` fields `belongs_to :i2c_module, I2cModule` and `field :i2c_channel, :integer`.
  - `Input.virtual?/1` is true for matrix and chip inputs.
  - `Input.chip_input?(%Input{}) :: boolean()`.
  - `list_inputs` and `list_all_inputs` option `:include_chip_inputs`, default false. `include_virtual_buttons: true` implies it.

**Why the option:** `lever_controller.ex:260` and `lever_setup_wizard.ex:98` use the default lists, and must see ADS1115 inputs. The configure path at `configuration_manager.ex:315` must not. This is a correction to the spec's wording, and is the same intent.

- [ ] **Step 1: Write failing tests:**
  - An input with `i2c_module_id` needs a pin in 128–255, and needs an `i2c_channel`.
  - `list_inputs excludes chip inputs by default`.
  - `list_inputs includes them with include_chip_inputs`, and with `include_virtual_buttons`.
  - `list_all_inputs` filters the same way.
  - `lever setup offers a calibrated ADS1115 input`.
  - `LeverController` lookup contains a chip input's `{port, pin}`.
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Write the migration:** add `i2c_module_id` referencing `device_i2c_modules` with `on_delete: :nothing`, plus `i2c_channel`, an index on `i2c_module_id`, and a unique index on `[:i2c_module_id, :i2c_channel]`.
- [ ] **Step 4: Implement** the fields, the pin rule and the option, and pass `include_chip_inputs: true` from both lever call sites. Run `grep -rn "virtual?\|matrix_id" lib` and check that each match behaves correctly for a chip input.
- [ ] **Step 5: Run** the tests. Expected: PASS.
- [ ] **Step 6: Commit** `feat: add chip child inputs`.

### Task 4: Allocation and chip lifecycle

**Files:**
- Create: `lib/trenino/hardware/i2c_inputs.ex`
- Modify: `lib/trenino/hardware.ex`
- Test: `test/trenino/hardware/i2c_inputs_test.exs`

**Interfaces:**
- Consumes: Task 2 params and Task 3 fields.
- Produces:
  - `I2cInputs.allocate(used :: MapSet.t(integer()), size :: pos_integer()) :: {:ok, base} | :error`.
  - `I2cInputs.children(%I2cModule{}) :: [%{i2c_channel: integer(), pin: integer(), input_type: :analog | :button, name: String.t()}]`.
  - `Hardware.create_i2c_module/2` and `update_i2c_module/2` accept `:channels`, a map of `i2c_channel` to `%{name, sensitivity}`.
  - `Hardware.i2c_module_impact(%I2cModule{}, attrs \\ %{}) :: [%{input_id: integer(), name: String.t(), binding: String.t()}]`, listing bindings that a delete or edit would remove.

- [ ] **Step 1: Write failing tests:**
  - `allocate` picks the highest free block, skips used pins, and returns `:error` when full.
  - Creating an MCP with direct and matrix blocks stores both bases and creates one child per channel, in one transaction.
  - An MCP direct block reserves 16 pins. An ADS block reserves 4.
  - A chip that does not fit returns a changeset error on `:params`.
  - `editing adds and removes only changed channels`: a kept child keeps its `id`, calibration and bindings.
  - `reshaping a matrix keeps surviving cells` (Review Focus 1): a 2×2 to 2×3 edit updates `pin` in place on surviving rows, by `i2c_channel`.
  - `moving a block keeps the bases stable until it must grow`.
  - `button children copy debounce from params`.
  - `ADS children keep their sensitivity`.
  - `delete_i2c_module removes children, calibrations and bindings`.
  - `delete_device removes chips after their inputs`.
  - `i2c_module_impact names lever, button and joystick bindings`.
  - `matrix overlapping a chip block returns a changeset error` (Review Focus 4).
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement.** Use `Repo.transaction` around the module write and child sync.
  - The used-pin set is every `Input.pin` on the device from 128 up, plus each chip's reserved blocks.
  - Keep a base unless the block no longer fits.
  - Changing pins can briefly collide with the `[device_id, pin]` unique index. Move kept rows with `update_all` to `-pin - 1` first, then to their final pins.
  - Check what foreign keys the binding and mapping tables use, and delete bindings explicitly where they do not cascade. Follow `delete_matrix_children`, and also delete calibrations.
  - `delete_device_cascade` deletes I2C modules after inputs. Make `create_virtual_buttons` return the unique-constraint changeset error, not a match failure.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: manage chip inputs and virtual pin allocation`.

### Task 5: Configuration path

**Files:**
- Modify: `lib/trenino/hardware/configuration_manager.ex`, `lib/trenino/hardware.ex`, `lib/trenino_web/live/configuration_edit_live.ex`
- Test: `test/trenino/hardware/configuration_manager_test.exs`, `test/trenino/hardware/config_fingerprint_test.exs`

**Interfaces:**
- Consumes: `Configure` fields from Task 1 and `I2cModule.input_chip?/1`.
- Produces: `{:error, :too_many_modules}`. `Hardware.list_i2c_modules/1` preloads `:inputs`, used only for ADS sensitivity.

- [ ] **Step 1: Write failing tests:**
  - `sends one Configure part per chip, not per child`.
  - `ADS sensitivities come from child inputs, 0 for disabled channels`.
  - `chip config on 3.1.0 returns firmware_update_required`.
  - `chip config with unknown version is refused` (Review Focus 5).
  - `HT16K33 config still works on 3.1.0`.
  - `nine modules returns too_many_modules`.
  - `fingerprint of a config with no input chips is unchanged`, comparing against a hardcoded hash computed from the current code before changing it (Review Focus 3).
  - `changing masks, debounce, gain, reference or ADS sensitivity changes the fingerprint`.
  - `the applied LiveView shows both new errors`, with a firmware message that names 3.2.
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement** `build_configure_message` clauses and mirrored `i2c_wire_config` clauses. Split the firmware gate so that steppers still require 3.1.0 and chips require 3.2.0. Make the `:firmware_update_required` flash generic, or return the required version.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: send input chip configuration`.

### Task 6: Keep input chips out of display code

**Files:**
- Modify: `lib/trenino/hardware.ex`, `lib/trenino/train.ex`, `lib/trenino/train/script_runner.ex`, `lib/trenino_web/live/components/display_binding_wizard.ex`, `lib/trenino_web/live/train_edit_live.ex`, `lib/trenino/mcp/tools/display_binding_tools.ex`
- Test: the matching existing test files

**Interfaces:**
- Produces: `Hardware.list_all_display_modules() :: [I2cModule.t()]`, with `:device` preloaded.

- [ ] **Step 1: Write failing tests:** `list_all_display_modules excludes input chips`, `display wizard does not list an MCP23017`, `display_hardware_available is false with only an ADS1115`, `script display.set on an input chip address warns and does not crash` (Review Focus 2), and `display binding tool rejects an input chip`.
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement** by replacing `list_all_i2c_modules` at these call sites. Keep it for the MCP `list_i2c_modules` tool. Reject input chips in `Train`'s display binding creation, so `DisplayController` never receives one.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `fix: keep input chips out of display paths`.

### Task 7: Calibration options

**Files:**
- Modify: `lib/trenino/hardware/calibration/session.ex`, `lib/trenino/hardware.ex`, `lib/trenino_web/live/calibration_wizard.ex`
- Test: `test/trenino/hardware/calibration/session_test.exs`

**Interfaces:**
- Produces:
  - `Session` options `:min_unique_samples` (default 3) and `:allow_rollover` (default true).
  - `can_advance?` and `valid_samples?` use the `:min_unique_samples` value held in `State`.
  - Result `{:error, :rollover_needs_reference}`.
  - `Hardware.start_calibration_session/3` sets options by looking up the input's chip: ADS1115 inputs get `min_unique_samples: 1`, and `allow_rollover: false` when `ref_channel` is nil.

- [ ] **Step 1: Write failing tests:** `identical samples advance with min_unique_samples 1`, `identical samples still fail by default`, `rollover sweep fails when allow_rollover is false, and saves nothing`, `rollover sweep saves has_rollover with a reference`, `start_calibration_session sets options for ADS1115 with and without reference`, `board inputs get defaults`, and `the wizard shows the reference message`.
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement.** `analyze_and_save_calibration` checks `analysis.rollover` before saving. The wizard copy: "This sensor wraps around, which needs a supply reference on its ADS1115. Add one in the chip settings, then calibrate again."
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: support ADS1115 calibration`.

### Task 8: Failed chip tracking

**Files:**
- Modify: `lib/trenino/hardware/configuration_manager.ex`, `lib/trenino/serial/protocol/module_error.ex`, `lib/trenino/hardware.ex`
- Test: `test/trenino/hardware/configuration_manager_test.exs`

**Interfaces:**
- Produces:
  - `ConfigurationManager.failed_i2c_modules(port) :: %{integer() => :init_failed | :communication_lost | :reference_lost}`.
  - `ConfigurationManager.subscribe_i2c_status(port)` and message `{:i2c_module_status, port, failed_map}`.
  - `State.failed_i2c` field.
  - Train-facing `Hardware.failed_input_ids(port) :: MapSet.t(integer())`.

- [ ] **Step 1: Write failing tests:** `codes 0, 1 and 3 mark an input chip failed`, `code 2 clears it`, `an HT16K33 or stepper shield address is logged and not tracked`, `reconfiguring clears the port`, `disconnect clears the port`, `a broadcast is sent on each change`, and `failed_input_ids lists children of failed chips`.
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement.** Look up the address against the device on that port with `I2cModule.input_chip?/1`. Keep the existing log, and correct its wording, as it says "failed init" for all codes.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: track failed input chips`.

### Task 9: Chip forms

**Files:**
- Modify: `lib/trenino_web/live/components/i2c_module_form_component.ex`
- Test: `test/trenino_web/live/` matching test file, or a new `i2c_module_form_component_test.exs`

**Interfaces:**
- Consumes: `Hardware.create_i2c_module/2`, `update_i2c_module/2`, `i2c_module_impact/2`, Params from Task 2.

Follow `DESIGN.md`. The chip selector appears on create only, with HT16K33 default, and the existing display form stays as it is.

- [ ] **Step 1: Write failing LiveView tests:**
  - The MCP form renders 16 pins.
  - GPA7 and GPB7 offer only Unused and Row.
  - Assigning pins saves the matching masks.
  - It shows the matrix size and remaining virtual pins.
  - The ADS form saves `channel_mask`, gain, reference, names and sensitivity.
  - The reference choice excludes enabled channels.
  - The ADS form explains that wrapping sensors need a reference and that it uses a channel.
  - An edit that removes bound channels shows the impact and needs confirmation.
  - Validation errors appear in the form.
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement.** Split `coerce_params/1` by chip. Use small function components per chip, to keep this file readable.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: add input chip forms`.

### Task 10: Chip inputs in the device and train UI

**Files:**
- Create: `lib/trenino/hardware/input_label.ex`
- Modify: `lib/trenino_web/live/configuration_edit_live.ex`, `lib/trenino_web/live/matrix_test_wizard.ex`, `lib/trenino_web/live/calibration_wizard.ex`, `lib/trenino_web/live/virtual_joystick_live.ex`, `lib/trenino_web/live/train_edit_live.ex`
- Test: the matching test files under `test/trenino_web/live/`

**Interfaces:**
- Consumes: `ConfigurationManager.failed_i2c_modules/1`, `subscribe_i2c_status/1`, `Hardware.failed_input_ids/1`.
- Produces: `InputLabel.pin(%Input{}) :: String.t()`, for example `"Pin 3"`, `"MCP 0x20 GPA3"`, `"MCP 0x20 R0C1"`, `"ADS 0x48 AIN2"`. Requires `:i2c_module` preloaded on chip inputs.

- [ ] **Step 1: Write failing tests:** `InputLabel` for each child kind, `device page groups inputs under their chip`, `chip inputs can be calibrated and renamed from the device page`, `input detection finds a chip input`, `matrix test wizard runs for an MCP matrix`, `failed chip shows address and wiring hint`, `chip status updates live`, and `train view warns when a bound input is on a failed chip`.
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement.** Generalize `matrix_test_wizard.ex` to take rows and columns rather than a `Matrix`, and show chip pin names. Replace raw `Pin #{...}` text in the calibration wizard and joystick view with `InputLabel.pin/1`.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat: show chip inputs and failures in the UI`.

### Task 11: MCP tools and documentation

**Files:**
- Modify: `lib/trenino/mcp/tools/device_tools.ex`, `docs/hardware-setup.md`, `docs/architecture.md`, `CHANGELOG.md`
- Test: the matching MCP tool test file

**Interfaces:**
- Consumes: `Hardware.create_i2c_module/2`, `update_i2c_module/2`.

- [ ] **Step 1: Write failing tests:** `add_i2c_module creates an MCP23017 with masks`, `creates an ADS1115 with a reference`, `list_i2c_modules includes channels and pins`, `list_device_inputs includes chip inputs with labels`, and `the GPA7 rule returns a readable error`.
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement.** Extend the `module_chip` enum, `@i2c_param_keys` and descriptions. Do not add a new tool.
- [ ] **Step 4: Update docs.** `hardware-setup.md` covers wiring, I2C addresses, the GPA7/GPB7 rule, matrix diodes, analog supply and the supply reference, including that all sensors on a reference chip must share its supply, and that sensors must span the full supply to wrap.
- [ ] **Step 5: Run** `mix precommit`. Expected: passes.
- [ ] **Step 6: Commit** `feat: expose input chips through MCP tools`.

### Task 12: End-to-end acceptance

Needs the owner's hardware, and firmware 3.2.0 from the companion plan.

- [ ] **Step 1:** Work through every bench check in the spec's Acceptance section and record the results in the PR.
- [ ] **Step 2:** Confirm that a device already applied on an earlier release shows as applied after upgrading the app.
