# Lever Setup: Scripted Analysis, AI Tools and UI Handoff

Status: draft for review, 2026-11-08

## Goal

A user can set up a train lever in three ways, and they blend:

1. **Scripted, in the UI (preferred).** The wizard finds the right simulator lever and produces a
   correct, labelled notch table on its own. No AI needed.
2. **"Ask AI" from the wizard.** On the "Find in Simulator" step a button copies a short prompt.
   The AI picks the endpoint, calibrates, and hands the user back to the wizard at the mapping step.
3. **AI-first.** The user says "set lever A to throttle". The AI does everything it can on its own
   (find the control, set endpoints, calibrate, bind the input) and then opens the wizard at the
   only step that needs the user: mapping the physical lever's notches.

Rule of thumb from the user: if it can be reliably scripted, script it. The AI tools call the same
scripted code; they never reimplement it.

## What we learned on 6 live trains

Tested read-only metadata plus guarded sweeps on the Class 802 (UK), BR430 (DE), LIRR M9 (US EMU),
ÖBB 1116 (AT, twin cab), Class 323 (UK, existing sweep in DB) and GE AC4400CW (US diesel). Every
result was confirmed by the user against the real lever.

**Read-only metadata available on every lever node** (no movement):

- `Property.InputIdentifier` → `{"identifier": "Throttle" | "Reverser" | "AutomaticBrake" |
  "IndependentBrake" | "DynamicBrake" | ...}`. A reliable role for matching, unlike node names
  (`PowerHandle(IrregularLever)`, `MasterController`, `ThrottleAndBrake`, `Throttle_F`).
- `Function.GetNotchCount`, `GetMinimum/MaximumInputValue`, `GetMinimum/MaximumOutputValue`,
  `Property.DefaultInputValue`, current input/output/notch index.
- `Property.DisplayInfo.namedValues`: a list of `{valueSource: "Output" | "Input", valueRange:
  {min, max}, displayName, bDisplayNameIsFormatString}`. These are the in-game notch names
  ("Emergency", "Max Brake", "{BrakePercent} Brake", "N3", "Full Service"). Ranges can be
  zero-width points (`[3, 3]`) and can overlap or be sloppy (323 Reverser "Reverse" spans -1.5..0.5).
- `CalcTargetOutputValue` and similar ignore parameters, so there is no virtual sweep.

**What metadata alone cannot give:** sim input positions when labels are in output units, the
value of non-integer gates (BR430 Min Brake -0.91), and spring-loaded positions (1116 Release).
So a sweep stays, but it can be made correct and labelled.

**Sweep behaviour that the current `LeverAnalyzer` gets wrong or misses:**

1. *Gates need repeated sets.* A single set to -1.0 on the 802 stopped at Max Brake (-0.9);
   6 rapid sets reached Emergency. The analyzer only pushes once at initialisation.
2. *Interlocks hide part of the range.* With the 802 Reverser in Neutral, power notches were
   unreachable and the lever stayed at Off. The sweep silently produces a lever with no power.
   Metadata (`GetMaximumOutputValue` = 4, labels up to `{PowerNumber}`) tells us it is missing.
3. *Safety.* Sweeping power moves the train (802 reached 5 m/s). There is no speed guard and no
   reliable restore (restoring into a gate needs pushes too; the 802 restore landed on Min Brake).
4. *Merge rule.* The sim gives the ends of a linear range their own notch index and snaps nearby
   inputs onto them (802/BR430/M9 Max Brake, Min Brake, Min Power; 1116 Min/Max). Users feel these
   as the ends of the range, not gates. Rule confirmed on all 6 trains:
   - merge a snap point into the adjacent linear zone when the input gap between them is
     <= 0.03 and the output continues (the existing `has_snap_boundary?` check), **or** when its
     output equals the linear zone's end output (AC4400 Full Service, gap 0.05);
   - otherwise keep it a gate (Emergency -11 next to -10; Off 0 next to -0.91; AC4400 Set-up:
     0.1 unreachable gap and a different output).
5. *Sim input ranges.* Notches store `sim_input_min/max` from the *set* values that landed in a
   zone. For gates that is the catch area, not the gate; for linear zones it includes values that
   snap. The *actual* input reached is the true position (gate) or reachable range (linear).
6. *No names.* Notch descriptions are "Gate at output -4.0"; the labels are right there.
7. *Stepped zones.* 802 Power is one sim notch index whose output steps 1-4 while input moves
   freely. The analyzer groups by notch index, so it must split a zone whose output takes a few
   distinct integer values with flat runs into separate gates (one per output value).

## Design

### 1. `Trenino.Simulator.LeverMetadata` (new, read-only)

```elixir
defmodule Trenino.Simulator.LeverMetadata do
  defmodule Label do
    defstruct [:name, :source, :min, :max, :template?]  # source :: :input | :output
  end
  defstruct [:control_path, :role, :notch_count, :input_min, :input_max,
             :output_min, :output_max, :default_input, :current_input,
             :current_output, :current_notch_index, labels: []]

  @spec read(Client.t(), String.t()) :: {:ok, t()} | {:error, term()}
  @spec list_levers(Client.t()) :: {:ok, [t()]} | {:error, term()}
  @spec label_for(t(), :input | :output, float()) :: Label.t() | nil
end
```

- `list_levers/1`: list `CurrentDrivableActor` nodes, keep those where `GetNotchCount` succeeds
  (`Task.async_stream`, bounded concurrency ~8, short timeouts), then `read/2` each.
- `label_for/3`: narrowest label whose range contains the value (inclusive, epsilon 0.01),
  matching source. Template names keep the raw text minus `{...}` placeholders trimmed
  (`"{BrakePercent} Brake"` → `"Brake"`, `"{PowerNumber}"` → `"Power"` fallback by role).
- Twin-cab: group levers with the same role. Pick the one whose cab's Reverser is not at a label
  named Off/Key Out; fall back to `_F`. Expose `active?: boolean` and keep the others listed.

### 2. `LeverAnalyzer` improvements (scripted, used by UI and AI)

Keep the public `analyze/3` and `analyze_samples/2`, so the wizard's flow is unchanged.

- **Pushes per sample**: send the target `@push_attempts` times with `@push_delay_ms` between, then
  settle. Applies to init, every sample and restore.
- **Safety guard** (opts `:max_speed`, default 2.0 m/s; `:speed_endpoint` default
  `CurrentDrivableActor.Function.HUD_GetSpeed`, value read as the first value in `Values`):
  refuse to start if `|speed| > 0.5`; abort the sweep when `|speed| > max_speed`; always restore
  the starting input (with pushes) in an `after`/`try` block. Abort returns
  `{:error, :train_moving}`; refusing returns `{:error, :train_not_stopped}`.
- **Restore by default** to the input read before the sweep (`restore_position: :original`).
- **Merge v3** as above (input-adjacent and continuous, or equal end output).
- **Split stepped zones**: within one notch-index group, if outputs are integer-valued with
  <= 15 distinct values and each value covers a flat run of >= 2 samples, emit one gate per value.
- **Sim ranges from actual input**: `sim_input_min/max` = min/max `actual_input` of the zone
  (gates collapse to one position, which `LeverMapper` already handles: gate → centre).
- **Labels**: `analyze/3` reads `LeverMetadata` first (best effort; analysis still works without
  it) and `build_notches_from_zones` names each notch: gate by its value (output labels) or actual
  input (input labels); linear by the label covering its midpoint, falling back to the labels at
  its ends ("Max Brake → Min Brake" becomes "Brake"). Fallback remains "Gate at output X".
- **Coverage warnings** on `AnalysisResult.warnings :: [String.t()]`:
  - observed output range misses metadata `output_min/max` by > 0.5 → "Part of the lever range
    could not be reached (for example power is blocked while the reverser is in neutral)".
  - an input-source label range inside the input range that no sample reached → "'Release'
    could not be held; it may be spring-loaded".
- The wizard shows warnings on the calibration result; the AI tool returns them.

Analysis stays pure in `analyze_samples/2` (metadata passed via opts) so tests use fixtures built
from the six recorded trains (captured sweep tables in this session become test fixtures).

### 3. Scripted endpoint suggestion (no AI)

Replace the unused `ControlDetector.suggest_lever/1` fuzzy match with role-based matching:

- `ControlDetector.suggest_levers(client, element_name) :: [%{metadata, score}]`.
- Role synonyms: Throttle ← "throttle", "power", "master controller", "combined", "traction";
  AutomaticBrake ← "brake", "train brake", "automatic"; IndependentBrake ← "independent",
  "loco brake", "direct"; DynamicBrake ← "dynamic", "regen"; Reverser ← "reverser", "direction".
  Score = role match (1.0) > node-name fuzzy match (existing jaro) > nothing; active cab first.
- In the wizard's "Find in Simulator" step, show up to 3 suggestions above the API explorer as
  one-click cards: node name, role, notch count and the label list ("Emergency · Brake · Off ·
  Power 1-4"). Clicking sets the same `detected_endpoints` as the explorer's auto-configure.
  The existing auto-detect and explorer stay as fallbacks.

### 4. MCP tools: `Trenino.MCP.Tools.LeverTools` (new)

All tools call the context and the modules above. Tool count 66 → 72.

| Tool | Does | Notes |
|---|---|---|
| `list_simulator_levers` | `LeverMetadata.list_levers` | role, path, notches, labels, active cab. Read-only. |
| `get_lever` | config, endpoints, notches, binding, `next_step`, `ui_path` | `next_step` ∈ set_endpoint, calibrate, bind_input, map_notches, done |
| `set_lever_endpoint` | element_id + control_path → derive the 5 endpoints, create/update LeverConfig | validates the node is a lever; clears notches if the path changed |
| `calibrate_lever` | runs `LeverAnalyzer.analyze` with safety guard, saves via `create/update_lever_config_with_analysis` | Description says it moves the lever and may move the train; ask the user first. Returns notches + warnings. |
| `bind_lever_input` | element_id + input_id → `Train.bind_input` | analog inputs only; suggest `detect_hardware_input` |
| `open_lever_setup` | broadcast navigation to `/trains/:id?lever=:element_id&step=:step` | returns `ui_path` and whether a window received it |

Hardware notch mapping stays UI-only (the user must move the physical lever). Tools are not beta
gated (levers are a released feature).

### 5. UI handoff

- `TrainEditLive.handle_params/3`: `?lever=<element_id>&step=<step>` opens the lever wizard on that
  element at that step (falls back to the first unconfigured step). Steps are validated against
  the wizard's step list with `String.to_existing_atom` guarded by a whitelist.
- `LeverSetupWizard` accepts `initial_step`; when the step is `:map_notches` it starts the mapping
  session the same way `next_step` does. The live_component id includes the element id, and the
  parent re-renders it fresh on each deep link so a stale initialised wizard never shows.
- Navigation from MCP: `Trenino.UINavigation.request(path)` broadcasts `{:ui_navigate, path}` on
  `"ui:navigate"`; `MCPDetectionHook.on_mount` (already on every live_session) attaches a
  `handle_info` hook that `push_navigate`s. The broadcast reports subscriber count so the tool can
  say "open Trenino" when no window is listening.
- "Ask AI" button on the Find in Simulator step: copies a prompt built server-side with the train
  and element ids:

  > In Trenino, set up the lever "<element name>" (train "<train name>", train_id X, element_id Y).
  > Use list_simulator_levers to find the matching simulator lever, then set_lever_endpoint. Ask
  > me before calibrate_lever, because it moves the lever in the game. Then call open_lever_setup
  > so I can map my hardware notches.

  Copy uses a small `CopyToClipboard` JS hook with a "Copied" confirmation.

### 6. Docs and skill

- Update `.claude/skills/train-setup/SKILL.md`: levers are now configurable over MCP; order of
  work; ask before `calibrate_lever`; finish with `open_lever_setup`.
- `docs/TSW_API_GUIDE.md`: document `InputIdentifier`, `DisplayInfo.namedValues` and the sweep
  findings (pushes, interlocks, spring-loaded positions).
- CHANGELOG entry; README mention of AI lever setup.
- Update tool counts in the three tests and MEMORY.

## Tests

- `LeverAnalyzer` analysis: fixtures for 802 Throttle, BR430 MasterController, M9, 1116 Throttle
  and TrainBrake, AC4400 ThrottleAndBrake and AutomaticBrake, built from the recorded sweeps; assert
  the confirmed notch tables (types, values, ranges, names). Merge v3 and stepped split unit tests.
- `LeverAnalyzer.analyze/3` with Mimic on `Client`: pushes, speed refusal/abort, restore always
  runs, warnings.
- `LeverMetadata`: parsing DisplayInfo, label lookup, twin-cab selection (Mimic `Client`).
- `ControlDetector.suggest_levers`: role ranking.
- `LeverTools`: each tool, error paths, `next_step` logic (DataCase).
- `TrainEditLive`: deep link opens wizard at step; navigation broadcast navigates; Ask AI renders
  prompt with ids.

## Review changes (Fable, 2026-11-08)

Adopted:

- **Recalibration keeps hardware mapping.** `update_lever_config_with_analysis` carries
  `input_min/input_max` over by index when the new notches have the same count and types;
  otherwise they are cleared and `get_lever.next_step` reports `map_notches`.
- **Runtime reload.** `bind_lever_input`, `set_lever_endpoint` and `calibrate_lever` call
  `LeverController.reload_bindings/0`.
- **Restore default** applies at the wizard call site too (`run_lever_calibration` passes
  `restore_position: nil` today).
- **Stepped split guards:** only when every output in the group is an integer, there are >= 2
  distinct values, and each run of equal output has >= 2 samples. Split gates keep their actual
  input run as their sim range.
- **Merge v3 scope:** "equal end output" only merges a gate into a *linear* zone; two gates merge
  only when their outputs are equal and no snap separates them. Output continuity is checked
  against the linear side's slope, with a gap limit of `max(0.03, 1.5 × sweep step)`.
- **Conditional pushes:** set once; push only when the lever did not land on the target.
- **Speed guard:** if speed cannot be read, continue with a warning.
- **Per-lever lock:** `{:error, :calibration_running}` when a sweep of the same control path is
  already running (UI or MCP).
- **Deep link:** add `handle_params/3`; flash when the simulator is disconnected. The wizard id
  stays `"lever-setup-wizard"`; a deep link sends a `reinitialize` update so an open wizard reloads.
  An open wizard is not live-updated by AI changes otherwise; `open_lever_setup` is the refresh.
- **map_notches preconditions:** `bind_lever_input` requires an analog, calibrated input;
  `next_step` explains what is missing.
- **Navigation ack** instead of a subscriber count: the hook replies to the requesting pid.
- **Four count files:** include `test/trenino/beta_test.exs`.
- **Typespecs** for suggested notches; `AnalysisResult.warnings` defaults to `[]`.
- **Cut:** twin-cab detection via Reverser labels. `list_levers` lists all, ranks `_F` first.
  `ControlDetector` lever detection delegates to `LeverMetadata`.

## Out of scope / follow-ups

- Repeating sends for gates in `LeverController` at runtime (a single send may not enter a gate
  like Emergency). Needs its own change and testing on hardware.
- Releasing a spring-loaded position (hold-to-release) from hardware.
- Editing notch names/ranges over MCP.
- Reverser/brake-holding during calibration (speed guard + restore covers safety for now).
