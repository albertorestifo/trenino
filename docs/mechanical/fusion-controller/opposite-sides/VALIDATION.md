# Final validation — 25 October 2026

The geared Fusion document is saved as AIDesignedLever Opposite-Side Detent v6, with 342 healthy features and no unsaved changes. The separate pre-gear AIDesignedLever v6 remains unchanged.

## Geometry and motion

The original full native sweep covered 29 poses for each of four cams (116 poses), including modeled hardware and frame. It found eight rotor/crossbrace clashes at travel endpoints. The original findings remain in pre-fix-clearance-check.json. Lowering the braces 5 mm resolved them; the final affected-motion regression covers 121 positions at 1 degree increments, both sensor adjustment extremes (45.0/45.5 mm), service retention and driver approaches, with zero clashes. The final neutral check also reports zero clashes.

All four cam removal paths pass at six sampled extraction positions. Native cam profiles match their generating geometry to numerical precision. Separate profile checks cover 481 angles per cam; maximum numerical penetration is 0.000326 mm. Conservative annular-envelope checks supplement sampled motion. Stops remain clear through +/-60 degrees and contact at +/-60.1 degrees. See the accompanying JSON reports for scope and tolerances. Finite sampling is not a proof against every possible interference.

## Print geometry and slicing

All 35 oriented millimeter STLs pass single connected shell, watertightness, positive volume, nondegenerate face and bed-contact checks. Print 32 pieces for one build by selecting one of the four cams. The supplied orientations are intentional.

All 35 parts sliced with unchanged Bambu Lab P2S 0.4, 0.20 mm Standard, Bambu PLA Basic and Supertack Plate defaults (two walls, 15% infill), supports disabled. All slice processes returned zero, and all layer reports contain zero support segments. Final logs contain no floating-region or ZFiller warnings. Critical layer previews were inspected, including blind-pocket closures, clamp bosses, shaft pockets and cassette posts.

Designed bridges still require a physical print check: P01 stop sockets are 12.3 mm, cassette counterbores 6.2 mm and insert closures about 4 mm. Long bridge-toolpath metrics across sparse infill are not unsupported span measurements. Zero generated supports is not proof of perfect bridging or adequate strength.

The slicer CLI logs contain nozzle_volume_type and invalid T65535 errors. Diagnostic G-code/3MF files are deliberately excluded from delivery. Import the STLs into the slicer GUI and generate printer output there after inspecting its preview.

## Hardware and physical commissioning

Maker Inventory reports sufficient stock for both baseline and geared builds, with no recorded shortages and no stock consumed. Five physical requirements remain unresolved, so the inventory draft is not checkout-ready. Estimated counts require recounting.

Confirm spring solid height/rate, pot travel beyond 240 degrees plus margin, nut/washer and contact clearance, printed fits and insert retention. Back spring preload off before cam service, remove the temporary service screw before operation, and verify no coil bind. The 50 N / 8 Nm load case is a design assumption, not a tested rating; no material allowable or durability claim is established. Compare backlash, notch force, assembly time and wear against pre-gear v6 experimentally.
