# Momentary (spring-back) notches on notch disks

Many SimRail levers have positions that spring back when released (`stable` in the
bridge schema: the position a control returns to). This note designs how notch disks
and Trenino handle them. Status: design, not started. Built on the generator constants
below (from `train-lever-generator`'s `engine.js` / `recipe.js`).

## Where they occur (from `integrations/simrail/profiles`)

| Pattern | Example (`stable` per position) |
|---|---|
| Symmetric valley, then a gate | Traxx `drive_handle` `[1,1,1,3,5,5,5,7]`: valley at 1, gate 3, valley at 5, gate 7 |
| Valley between two gates | Traxx `local_brake`, `speed_ctrl` `[0,2,2,2,4]` |
| One-sided flank at an end of travel | Traxx `main_brake` `[0,2,2,2,4,4]` (5 → 4); EN57 `mainbrake` `[1,1,2,…,7]` (0 → 1) |
| Two momentary bands on one flank | ED250 `speed_ctrl` `[2,2,2,2]`: 0 and 1 below the centre, 3 above |

Spring-return *switches* (pantograph, main switch, horn, battery, cab key …) are common
too, but those are momentary toggle hardware, not disks.

## Model: a valley

A stable position with its momentary neighbours becomes one **valley** on the disk:

```
 lift
   ▲   crest            crest
   │   ╱╲      flank     ╱╲   ← next gate's bump
   │  ╱  ╲  ╲        ╱  ╱  ╲
   │ ╱    ╲   ╲    ╱       ╲__ next gate
   │        ╲   ╲╱   ╱
   │          ╲ ‾‾ ╱   ← rounded bottom = stable position
   └──────────────────────────────▶ lever angle
        [m][   S   ][m]
```

- The **bottom** is the stable position: the follower's spring holds the lever there.
- The **flanks** carry the momentary positions as angle bands. Pushing the lever up a
  flank selects them; releasing lets the spring roll it back to the bottom, just as the
  game springs its own lever back.
- Past the **crest** at the end of a flank comes the next gate (or the end stop), so
  leaving the valley needs a deliberate push over the crest, like any other notch.
- A one-sided valley (momentary position at an end of travel) has its flank run into the
  end stop. Two momentary bands on one flank (ED250) are consecutive bands on the same
  slope: farther up means the outer position.

This needs no new geometry engine: the generator already builds the disk from profile
points (angle, roller lift) joined by ramp shapes. A valley is a new **recipe** (a new
feel next to Standard/Deep/Smooth) producing those points.

## Will it spring back? Numbers

Generator constants: roller radius 5 mm, lift −2 … +3 mm, travel ±58°, flank pressure
angle ≤ 35°, concave folds limited by roller curvature (K = 189 mm/rad²), Standard bump
1.2 mm.

- The follower spring pushes the roller with force F; on a slope dh/dθ the lever feels a
  restoring torque of about F · dh/dθ. It springs back wherever that beats the lever's
  friction torque.
- **The tested disk already proves the principle.** A Standard notch pulls the lever in
  from its bump: 1.2 mm over a ~6.5° half-gap ≈ **10.6 mm/rad**. A valley flank at least
  that steep springs back at least as reliably as today's notches capture the lever.
- Budget: the lift range gives at most 5 mm from valley floor (−2) to crest (+3), so a
  flank at 10.6 mm/rad can span up to ~27° — far more than needed. A typical valley:
  bottom −1.8 mm, crest +1.2 mm, half-width 12° → 14 mm/rad, pressure angle ≈ 20°
  (limit 35°).
- **Flank shape: linear, not cosine.** A cosine ramp flattens towards the bottom, so the
  restoring torque fades and the lever stops short of centre (a dead band). Linear flanks
  keep the torque up to a short rounded bottom, whose radius the roller curvature limit
  sets anyway. The remaining dead band is what the centre's sensor band must absorb.
- Effort: the push needed to hold a flank position equals the restoring torque, so a
  steeper flank returns more firmly and is heavier to hold. One flank slope for the
  whole disk keeps the feel consistent; it may need a "firm/soft" option later.
- Unknowns that only a print answers: the actual spring force and lever friction (hence
  the dead band), and how holding a flank feels over time. See validation.

## Principle

A spring-back position is a position of the lever. Whether the physical lever springs
back is a hardware choice (a spring, a valley on the disk, or nothing), so the software
never refuses such positions or treats them differently at runtime. Only the notch disk
designer and the mapping wizard know about it, through the notch's `springs_back_to`.

## Corrections from review (Fable, 2026-11-23)

- **Spring force is lowest at the valley floor**, where the return must finish. The
  Standard-notch comparison holds only at equal lift: keep the floor near the Standard
  notch's bottom lift, or make the flank steeper.
- **The rounded bottom is not short.** With the curvature limit K = 189 mm/rad²,
  reaching 10.6 mm/rad takes ~3.2° each side (4.3° for 14 mm/rad), a third of a 12°
  flank. The linear part must be steeper than the average.
- **Crests have zero slope**, so the lever can park on one between a momentary band and
  the next gate. Make crests sharp, and end the outer band before the crest blend.
- **Linear flanks give no cue at band boundaries** (centre/flank, or the ED250's two bands
  on one flank). Consider a small slope step at each boundary.
- **Even spacing breaks the recipe.** The ED250 `speed_ctrl` has 4 positions, so even
  spacing is 38.7° per position: two bands on one flank would span 77°, ~3.7 mm/rad over
  the 5 mm lift budget, far below the 10.6 mm/rad needed. Valleys need their own width
  (~5–6° per band), with `spring=` carrying per-side band counts; momentary bands don't
  count against the position limits.
- **Grouping:** a stable notch plus the contiguous neighbours whose `springs_back_to`
  points at it; fall back to plain gates with a warning when non-contiguous or chained.
  A valley overrides Deep.
- **SimRail anchors:** values are non-uniform and reversed (Traxx `main_brake` 5…0), so
  `NotchDesign`'s input-order assumptions, `travel/1` and `gate_anchor/2` give garbage
  anchors for catalog levers: pass `nil` anchors.
- **Mapping wizard:** flank bands don't hold, so don't ask "move to X and release".
  Capture the centre by releasing several times from each side (centre band = measured
  spread plus margin), and capture each flank's far extent, then split the bands.
- **Mapper hysteresis:** `LeverMapper` has none; ADC noise on a centre/flank boundary
  becomes repeated nudges, which matter on rate positions. Add hysteresis there.

## Travel budget

116° of travel. Traxx `drive_handle` as an example: two valleys of ~30° (±12° flanks
plus crest room) and two gates leave ~40° for crests and gate spacing. Valleys need their
own widths (see above), not the generator's even spacing. The layout is free for SimRail:
notches are discrete positions written by the bridge, not points on a continuous
simulator input, so the TSW-style "place each gate at its simulator input" scoring isn't
needed.

## Changes

1. **Generator** (private CAD project): a *Spring* feel/recipe. A valley is given by its
   centre position and band counts on each side; the recipe emits linear flanks, a
   roller-limited rounded bottom and sharp crests, gives the valley its own width, and
   checks pressure angle, curvature, lift range and minimum flank slope (≥ the tested
   Standard flank, at the floor's lift). Link parameter alongside `deep=` / `smooth=`.
2. **Trenino notches — done.** `SimRailLevers` keeps every position as a notch; each
   notch records `springs_back_to` (notch index). Equal-value neighbours merge only when
   they behave the same. Next: `NotchDesign` groups valleys and emits the recipe.
3. **Mapping wizard:** as in the corrections above.
4. **Runtime — done in the bridge (0.3.0), untested in game.** A write means "the lever is
   here until the next write". When a written value is a spring-back position of a
   control on that path, the bridge re-applies it every frame (and moves the cab lever
   back to it) until a different value is written. Holds last only while at least one
   client stream is connected, and clear on vehicle change. Trenino's SimRail backend
   keeps its stream open after a write. Trenino itself sends positions on change, as for
   any lever.

## Validation

1. In the game, through the bridge: verify the hold (no stable-value frames leaking
   through) on the Traxx `drive_handle` and ED250 `speed_ctrl`, and its release when
   Trenino disconnects.
2. Print one test disk, Traxx `drive_handle`, at the default slope: measure return from
   each flank, the dead band at the bottom, and holding effort.
3. Tune the flank slope from that, then fix the recipe's defaults.

## Open questions

- The generator's source is a private CAD project: who implements the recipe there?
- The follower spring's force and preload (`assumed_extra_preload_mm`) set the dead band;
  is it known, or measured on the test print?
