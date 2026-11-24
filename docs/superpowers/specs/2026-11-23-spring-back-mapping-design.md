# Spring-back positions in notch mapping

## Why

SimRail levers have positions the cab lever springs back from (Traxx traction: 1 and 3 return to 2,
5 and 7 to 6). The notch disk now gives each spring zone a wall to push past. Today the mapping step
treats a spring position like any other gate: "move your lever there and wiggle it". The lever won't
stay there, so the user can't tell where the spring area is or how big it should be, and the resting
position gets no buffer against drifting into it.

## Goal

- Resting positions are mapped first, each with a dead-zone buffer, so a lever resting slightly off
  centre still reads as the resting position.
- Then, for each spring position, the user pushes the lever up to the wall and holds it. That point
  is where springing back ends.
- Trenino works out the spring area itself: from the edge of the resting position's dead zone to the
  wall point. Spring areas never overlap a resting position or each other.
- The lever bar shows spring areas differently from ordinary positions throughout mapping and review.

Non-goals: no change for levers without spring positions; no change to the runtime mapping
(`LeverMapper`), the disk generator or the SimRail bridge.

## Approaches

1. **Two passes (chosen, as the user described).** Pass 1 maps every position that doesn't spring
   back, in lever order. Pass 2 maps each spring position by its wall point. The spring area is
   computed, not wiggled.
2. Keep one pass in lever order, changing only the instruction for spring positions ("push to the
   wall and hold"). Simpler, but the resting position next to it may not be mapped yet, so the
   spring area can't be computed or shown when the user captures it.
3. Capture only resting positions and derive spring areas from the disk design's angles. No physical
   wall capture, but the disk angles don't match the potentiometer reading exactly, and it ignores
   the user's ask to see where springing back stops.

## Design

- **Order.** `NotchMappingSession` builds its step order from `springs_back_to`: first the notches
  with `springs_back_to: nil` in index order, then the spring notches in index order. Levers without
  spring notches keep today's order. The step stays `{:mapping_notch, idx}`; only the sequence and
  `next_step_after_capture` change. `go_to_notch` still lets the user jump to any notch, but a spring
  notch can only be captured once its target is captured.
- **Resting positions.** Captured as today (wiggle; a linear notch is swept). When the lever has
  spring notches, a resting gate that a spring notch returns to gets a dead-zone buffer: its saved
  range is the wiggled range widened by 3% of the travel on each side that has a spring notch
  (my call: big enough for a lever that settles a little off centre, small next to a 7° band). The
  buffer never crosses another captured range.
- **Wall points.** For a spring notch the instruction becomes "Push the lever from <target> towards
  <name> until you feel the wall, hold it there, then release". While capturing, Trenino tracks the
  furthest reading from the target's range; Capture stores that as the wall point. Capture is refused
  when the wall point is inside the target's dead zone or on the wrong side of it (the instruction
  says which way).
- **Spring areas.** For each spring notch: from the target's buffered edge to its wall point. With
  two spring notches on one side (e.g. 3 and 4 both returning to 5), the inner one ends where the
  outer one begins: each is captured by its own wall point in order from the target outwards. Saved
  as the spring notch's `input_min`/`input_max` like any gate, so the runtime is unchanged. Between
  a wall point and the next position the existing nearest-edge rule applies.
- **UI.** In the wizard's mapping step, spring notches are labelled "Springs back to <target>" with
  a distinct badge. On the lever bar the spring areas are drawn hatched in the target's colour, with
  the dead zone as a lighter band around each resting range. The review step lists, for each spring
  notch, its area and the target. The steps show "Resting positions" then "Spring-back positions".
- **Errors.** A spring area under 1% of travel (wall point almost at the dead zone) is refused with
  "That's inside <target>'s dead zone. Push further, up to the wall".

## Left to the builder

Exact copy, colours and the hatch pattern (follow the phoenix-liveview skill); how preview probing
(`build_hardware_ranges`) handles buffered ranges; test layout (`SerialSafetyCase`/`DataCase` as
today). Everything stays behind the `:simrail` beta flag only where entry points already are, since
`springs_back_to` is only set for SimRail levers.
