# Cam detent FDM slice validation

## Setup

- Slicer: Bambu Studio 02.04.00.70, local hidden CLI process.
- Printer profile: Bambu Lab P2S, 0.4 mm nozzle.
- Material/profile: Bambu PLA Basic @BBL P2S.
- Process: 0.20 mm layers, 5 wall loops, 5 top and bottom shell layers, 35% gyroid infill.
- Auto tree supports enabled for bracket, fork, hub, and cam; disabled for roller. Cam supports were enabled for the underside insert-boss relief roofs.
- Brim: 5 mm bracket, 3 mm roller; none on hub, cam, fork.
- Bed profile: Textured PEI Plate.
- STLs were sliced separately with CAD orientations preserved. `--orient` and `--arrange` were omitted.
- CLI settings profiles were resolved from installed Bambu preset inheritance chains and stored under `profiles/`. `process-cam.json` retains support enabled for future reruns through `slice_parts.ps1`.

## Results

All five refreshed Onshape export meshes passed mesh checks: each is one connected, closed mesh with zero nonmanifold edges and consistent winding, sits at Z=0, and fits inside the P2S build envelope. Only the hub and cam were re-sliced for this insert revision. Earlier results remain valid for the unchanged roller, fork, and bracket meshes.

| Part | Mesh used | Slice result | Layers / supports | Filament | Estimated total time | Sliced 3MF |
|---|---|---:|---|---:|---:|---|
| Roller | Latest export; unchanged geometry | Success, return code 0 | 50 layers, supports off | 0.84 g | 11m 52s | `sliced/roller.gcode.3mf` |
| Hub | Refreshed insert revision | Success, return code 0 | 105 layers, tree supports; 4 overhang layers detected | 16.70 g | 39m 43s | `sliced/hub-insert-revision.gcode.3mf` |
| Cam | Refreshed insert revision | Success, return code 0 | 40 layers, tree supports; 1 overhang layer detected | 12.23 g | 31m 25s | `sliced/cam-insert-revision.gcode.3mf` |
| Fork | Latest export; unchanged geometry | Success, return code 0 | 40 layers, tree supports enabled; 0 overhang layers detected | 4.02 g | 14m 32s | `sliced/fork.gcode.3mf` |
| Bracket | Earlier validated STL; bracket geometry unchanged, but the latest export mesh was not re-sliced | Success, return code 0 (retained prior result) | 400 layers, tree supports; 6 overhang layers detected | 31.45 g | 1h 16m 49s | `sliced/bracket-final.gcode.3mf` |

Total estimated separate-job time is about 2h 54m 22s and total filament is about 65.23 g. These are slicer estimates for the local profile, not guaranteed print times or material use.

Each output 3MF contains nonempty `Metadata/plate_1.gcode`; Bambu Studio logged successful export for every job. The two refreshed hub/cam jobs were completed on 24 October 2026 at about 12:47 local time. The three unchanged-part results are retained from the earlier validation run.

## Warnings and limits

- Every CLI run logged `nozzle_volume_type not found` for the P2S profile and `no filament colors found in projects`. Slicing still completed with return code 0.
- The vendor P2S end-G-code contains the literal `T65535`; Bambu Studio logged `Invalid T command (T65535)`. The vendor end-G-code was left unchanged. Treat these outputs as validation-only, **not print-ready packages**.
- Tree supports emitted `tree support default to organic support`. The refreshed hub generated supports on 4 overhang layers and the cam on 1; inspect that the supports under the cam relief roofs are removable without damaging the contact track or boss seats.
- These results validate local STL loading, orientation, support generation, and slicing only. They do not confirm physical fit, strength, material suitability, support removability, or a successful printer run. Use the geometry STLs/3MF with the user's P2S profile in Bambu Studio for final review and slicing before printing.
