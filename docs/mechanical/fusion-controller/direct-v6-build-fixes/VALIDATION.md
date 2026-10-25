# Validation status

Final direct-drive revision saved as AIDesignedLever v7, with no unsaved changes and 526 healthy native features. Mechanical and FDM specialist reviews are complete for a prototype geometry release.

## Implemented changes and traceability

Original active AIDesignedLever v6 was archived before edits as Before-Build-Fixes-v6.f3d. The direct-drive lineage is 2iFF2PJAQnO13x73oN2c-w. The geared lineage is unchanged. baseline.json records original native parts, dimensions, volume and feature names.

The updated assembly is lowered 35 mm with unchanged frame and rail-fastener coordinates. Component position changes are captured in a Fusion position snapshot; early uncaptured moves had reset during recomputation, and were corrected before final verification. The historical neutral-before-position-capture.json records those intermediate findings, not the released state.

P02's former insert-hole fill left a small protrusion at its carriage face. It was trimmed flush, and the final neutral-check.json reports zero clashes and no unhealthy features.

The mechanical specialist's read-only assembly audit covers 295 sampled positions for the bare shaft, right housing, split bush halves, spacers, rotor and preassembled left housing/bush. It reports zero clashes. P02 must be held 40 mm left of its final position during radial bush placement so its sensor arms are clear.

## Physical limits

No physical strength, fatigue, insert-retention or bridge-finish rating is established. The P09 3.8 mm insert bore and 0.2 mm chamfer are a fit candidate responding to the user's insufficient melt engagement. The measured pot shaft is modeled; contacts, supplied nut/washer dimensions and total travel still need physical confirmation. Spring rate and solid height remain unmeasured.

The outer P13 guide nut leaves 1.25 mm nominal installed sidewall; it is a lightly loaded guide restraint. The optional shaft joining nuts have 1.9 mm loaded backing. Use gentle tightening and verify retention; no torque rating is supplied.

All supplied files are geometry for re-slicing, not printer-ready G-code. Existing CLI configuration errors must not be ignored when generating machine commands.


## Completed final checks

- Zero neutral interference findings across modeled solids and nominal frame envelopes.
- Three cam variants at 25 lever positions each (75 operating poses), plus 18 cam extraction positions: no reported interference.
- 295 sampled assembly positions: no reported interference.
- 31 whole-model oriented exports pass closed-edge, winding, positive-volume and bed-contact checks. Ten released reprints also pass one-connected-shell/nondegenerate-face checks: six required and four optional.
- 21 unchanged component definitions remain reusable; their native dimensions and volumes match the baseline. Assembly translation does not require reprinting them.
- Ten selected parts sliced using unchanged Bambu Lab P2S 0.4, 0.20 mm Standard, Bambu PLA Basic and Supertack defaults. All returned exit zero and generated no support segments. Critical counterbore/nut-pocket layers were inspected; both P04 halves have vertical bores and zero bridge paths.
- Rotating the optional lower shaft 45 degrees in the bed plane removed its initial ZFiller diagnostic without changing its geometry or bed face. Final logs contain no ZFiller or floating-feature messages. Known nozzle_volume_type and invalid T65535 configuration errors remain: diagnostic toolpaths are excluded.

Motion/assembly reports name v6 because checks ran immediately before the final v7 save. Subsequent operations added joints/view captures/export only; the final P02 trim removes material and cannot invalidate the already clear insertion paths. Physical printing and commissioning remain necessary.
