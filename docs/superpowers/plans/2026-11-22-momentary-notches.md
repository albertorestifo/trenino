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

## Travel budget

116° of travel. Traxx `drive_handle` as an example: two valleys of ~30° (±12° flanks
plus crest room) and two gates leave ~40° for crests and gate spacing. That's comfortable,
while Standard spacing is ~14.5° per position. The layout is free for SimRail: notches are
discrete positions written by the bridge, not points on a continuous simulator input, so
the TSW-style "place each gate at its simulator input" scoring isn't needed.

## Changes

1. **Generator** (private CAD project): a *Spring* feel/recipe. A valley is given by its
   centre position and momentary positions on each side; the recipe emits linear
   flanks, a roller-limited rounded bottom and crests, and checks pressure angle,
   curvature, lift range and minimum flank slope (≥ the tested Standard flank). Link
   parameter, e.g. `spring=4:3-5` (centre 4, flank positions 3 and 5), alongside
   `deep=` / `smooth=`.
2. **Trenino notches:** today `SimRailLevers` drops spring-back positions with a
   warning. Keep them instead: a notch gets `momentary_to` (the index of its stable
   notch). `NotchDesign` groups each stable notch with the momentary notches pointing at
   it into a valley segment and emits `spring=`.
3. **Mapping wizard:** show the valley as one centre band plus flank bands, centre band
   wide enough for the dead band; capture the bands with the hardware as today.
4. **Runtime:** while the hardware sits in a flank band, the momentary value must stay
   applied. The game springs its own lever back on its own (`m_returnToStablePos`
   ≈ 0.15 s on the Traxx), so a single write is not enough: re-send at > ~10 Hz while
   held, or add a bridge `hold`/`release` op that re-asserts the value every frame. Some
   momentary positions are rates (Traxx traction set-point rises while held), which a
   continuous hold gives naturally.

## Validation

1. In the game, through the bridge: verify what holding a momentary position needs
   (repeated writes vs a hold op) on the Traxx `drive_handle` and ED250 `speed_ctrl`.
2. Print one test disk, Traxx `drive_handle`, at the default slope: measure return from
   each flank, the dead band at the bottom, and holding effort.
3. Tune the flank slope from that, then fix the recipe's defaults.

## Open questions

- The generator's source is a private CAD project: who implements the recipe there?
- The follower spring's force and preload (`assumed_extra_preload_mm`) set the dead band;
  is it known, or measured on the test print?
