# Geared lever — prototype print package

Open the three files in `plates/` individually in Bambu Studio, select your printer and filament, then slice. These are arranged **geometry 3MFs, not pre-sliced toolpaths**. They contain 28 parts for one lever with the 7-gate cam. All 30 individual oriented STLs are in `stl/`, including the optional 3- and 5-gate cams. Print only one cam per lever. Do not also print the STLs if you print the plates.

## Printer setup

Layer generation was checked with Bambu Lab P2S, standard-flow 0.4 mm nozzle, Bambu PLA Basic, 0.20mm Standard @BBL P2S and Supertack Plate. Select the plate physically installed on your printer. Keep the profile defaults: 2 walls, 15% infill and supports disabled. No process overrides are embedded in these 3MFs. Parts preserve their orientation and have at least 8 mm between bounding boxes. Use printing by layer, not sequential by object.

The command-line slicer generated layers but reported machine/tool-selection errors (`nozzle_volume_type` and `T65535`) and a clipping diagnostic for the lower shaft, so diagnostic G-code is deliberately excluded. Slice these geometry files in the normal Bambu Studio UI with the correct printer, nozzle and filament selected. Inspect the final preview before sending the print. If the lower shaft still reports a clipping issue, do not print that toolpath; see VALIDATION.md.

## Print order and fits

Print G01, G02, both P05G shaft halves and the two journal bushes first from the individual STLs. Check shaft rotation, D-stub fit and the actual potentiometer shaft fit before printing the larger plates. Inserts are CNC Kitchen standard M3 × 5.7 mm; the nominal pockets are 4 mm diameter. Verify the insert fit on your printer/material before installing all inserts.

Parts are already on their intended bed faces. Gears and sensor panel lie flat; shaft and pivot halves lie on their split faces. The pinion's side notch is an intentional open tool channel that removes an otherwise unsupported region. Small screw-hole ceilings bridge locally. Slicer bridge paths include bridges over infill, so their full lengths are not necessarily unsupported free spans.

## Assembly differences

Use the baseline illustrated guide for unchanged parts and COMPARISON-PLAN.md for geared changes. Do not use the old coupling, carriage or original shaft in this version.

At lever neutral, G01's split points down. G02's split points 30 degrees past straight up toward negative Y: 120 degrees measured from positive Y toward positive Z, viewed along the shaft. This indexes the pinion by two whole teeth and keeps its open channel away from the teeth used during travel. Center the potentiometer's usable travel before clamping it. The pinion rotates twice as far as the large gear, in the opposite direction.

Start with 45.15 mm shaft-to-sensor center distance; adjust only within 45.0–45.5 mm. The slots allow more movement than this operating recommendation. Do not use the potentiometer's internal stops as lever stops. The intended ±52 degree lever travel requires 208 degrees of usable potentiometer travel plus margin.

Remove G01 and its clamp before withdrawing or changing a cam. Refit and recalibrate afterward. Include this extra step when comparing service time with the coupling version.

## Physical prototype checks

The sensor's exact dimensions, taper, supplied nut/washer and usable travel remain unmeasured. Spring rate and solid height were assumed at your request; verify that the spring cannot bind before increasing preload. Printed clamp retention, force, fatigue and backlash require the actual build. The electronic resolution benefit is not yet measured.

The geared design remains separate from the unchanged coupling baseline v6. See VALIDATION.md for evidence and limitations. Record comparison results in COMPARISON-RESULTS.csv.
