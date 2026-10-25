# Reviewed integrated print validation

Source exports: 3 reviewed Onshape 3MFs; current FeatureScript source hash: `8E0F76D93B1EF02D5618B50AD2BF37C296640A0BEEAB5AC801CBEB40222B2606`.

## Mesh conversion and checks

- Converted 22 build objects from 3MF meters to binary STL millimeters; filenames include group, sanitized object name, and unique object ID.
- All 22 STLs passed checks: one connected component, zero nonmanifold edges, zero inconsistent edge winding, positive signed volume, Z minimum 0 mm within tolerance, and bounds within the 256 mm P2S envelope.
- The spring-block STL was regenerated from the corrected SUPPORT export; all 21 other STL byte hashes are unchanged from the preceding verified set.

## Slicer checks

- Bambu Studio CLI: P2S 0.4 mm nozzle, PLA Basic, 0.20 mm layers, 5 wall loops, 5 top/bottom layers, 35% gyroid.
- 22/22 parts produced a nonempty G-code 3MF with process return code 0. Support is enabled and verified in the saved project settings for M01 shaft, M06 cam, M07 carrier lug, M08 fork, M10/M11 grip halves, and S03 spring block; it is off for the other 15 objects.
- No floating-object warning was found in the captured CLI logs.
- Bambu Studio logged nonfatal diagnostics: `ZFiller` clip/subject messages on M01, M10, M11, S01, S03, and S04; `Not precalculated Placeable areas requested., critical: 0` on M01, M06, M07, M08, M10, M11, and S03; and `Invalid T command (T65535)` plus `nozzle_volume_type not found` across all outputs. Each affected slice nevertheless reports return code 0 and has an output file. The mesh topology checks found no corresponding mesh-integrity failure; treat these as slicer diagnostics for visual preview review, not as a confirmed geometry defect.

Support-enabled parts verified: 7 of 22.
Package: `reviewed-print-source-stl-guide.zip` (3 source 3MFs, 22 STLs, current guide, FeatureScript source; excludes G-code, logs, and reports).

Detailed mesh metrics: `mesh-check.json`. Per-part slicer outputs and logs are in `sliced/`; the complete CLI summary is `slice-report.json`.
