# Spring-back mapping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Map spring-back notches by resting positions (with a dead zone) then wall points, and compute the spring areas.

**Architecture:** A pure module `Trenino.Train.Calibration.SpringZones` owns the step order, wall checks and the
effective (buffered/computed) ranges. `NotchMappingSession` keeps raw captures in `captured_ranges` and uses
`SpringZones.effective_ranges/3` wherever it turned captures into ranges (direction, preview, save). The wizard
shows the new instruction, badge, errors and the zones on the "Your lever" strip.

**Tech Stack:** Elixir, Phoenix LiveView, ExUnit.

**Spec:** `docs/superpowers/specs/2026-11-23-spring-back-mapping-design.md`

## Global Constraints

- Levers with no `springs_back_to` set behave exactly as today (order, ranges, UI).
- Dead zone: 3% of total travel on each side of a resting gate that has a spring notch on that side.
- Smallest spring area: 1% of total travel.
- Calibrated values are integers 0..total_travel; normalisation and rounding stay in the session.
- `springs_back_to` is a notch `index`; notches are mapped by `index`, not list position.

## Review Focus

- Spring captured before its target: refused with `:target_not_mapped`, never a crash.
- Wall point past the next resting position: refused with `:past_next_position`.
- Re-capturing a resting position after its spring notches: spring areas recompute from the new edge.
- Two spring notches on one side: outer area starts at the inner wall; outer captured before inner is refused.
- A target whose side can't be known yet (no other resting capture): wall side taken from the capture itself.

---

### Task 1: SpringZones

**Files:** Create `lib/trenino/train/calibration/spring_zones.ex`, test `test/trenino/train/calibration/spring_zones_test.exs`

**Interfaces (Produces):**
- `@type notch :: %{index: non_neg_integer(), springs_back_to: non_neg_integer() | nil}` (extra keys ignored)
- `@type range :: %{min: integer(), max: integer()} | nil`
- `step_order([notch]) :: [list_position]`: resting notches by index, then spring notches ordered by distance
  from their target, then index.
- `effective_ranges([notch], [range], total_travel) :: [range]`: resting targets widened by the dead zone on spring
  sides (never into another captured range); spring notches from the inner edge (target buffer edge or inner spring
  wall) to their wall point; nil while target or inner spring isn't captured.
- `check_wall([notch], [range], total_travel, list_position, capture :: range) :: :ok | {:error, reason}` with reasons
  `:target_not_mapped | :inner_not_mapped | :inside_dead_zone | :past_next_position`.
- `spring?/1`, `dead_zone(total_travel) :: integer()`.

Tests (Traxx traction shape: indices 0..7, springs `0→1, 2→1, 4→5, 6→5`, total 800, resting ranges captured at
100±5, 300±5, 500±5, 700±5): step order `[1,3,5,7,0,2,4,6]`; target 1 widened by 24 on both sides (springs both
ways); 3 not widened; spring 2 wall at 200 → area `95+24+... ` i.e. `%{min: 330? }` (computed from buffered edge);
wall at 310 refused `:inside_dead_zone`; wall at 495 refused `:past_next_position`; spring before target refused.

### Task 2: Session uses SpringZones

**Files:** Modify `lib/trenino/train/calibration/notch_mapping_session.ex`; test in
`test/trenino/train/calibration/notch_mapping_session_test.exs` (new describe "spring-back notches").

- `init/1` keeps `springs_back_to` on each notch map; `start_mapping` starts at the first of `step_order`.
- `next_step_after_capture` walks `step_order` (after the current position, wrapping).
- `capture_range` for a spring notch runs `check_wall/5` and stores the capture; errors returned unchanged.
- `direction_fields`, `build_captured_cache`, `build_hardware_ranges`, `save_notch_ranges` use effective ranges;
  a notch whose effective range is nil counts as uncaptured in the preview.
- `hardware_ranges` entries gain `springs_back_to` and `core_min_pct`/`core_max_pct` (the wiggled range of a
  buffered resting gate, else equal to min/max).

Tests: order on a Traxx-like lever; spring capture before target refused; saved spring notch range spans dead-zone
edge to wall; resting range saved widened; a lever without springs saves exactly its captures.

### Task 3: Wizard

**Files:** Modify `lib/trenino_web/live/components/lever_setup_wizard.ex`,
`lib/trenino_web/live/components/lever_visualization.ex`; test the wizard's existing LiveView test file.

- Spring notch instruction: "Push the lever from <target> towards <name> until you feel the wall, hold it there,
  then release. Capture when you're back." Badge "Springs back" instead of Gate.
- Flashes: `:target_not_mapped` "Map <target> first: this area starts at its edge."; `:inner_not_mapped` "Map the
  spring position nearer <target> first."; `:inside_dead_zone` "That's inside <target>'s dead zone. Push further,
  up to the wall."; `:past_next_position` "That reaches the next position. Stop at the wall."
- Strip: spring segments hatched (`bg-[repeating-linear-gradient(...)]`), resting segments show the dead zone as a
  lighter band around the core. Review table: notch cell adds "springs back to <target>".
- Overview header shows "Resting positions" / "Spring-back positions" for the current step when the lever has springs.
