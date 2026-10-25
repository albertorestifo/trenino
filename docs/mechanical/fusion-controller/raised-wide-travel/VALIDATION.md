# Validation and print status

Final saved model: AIDesignedLever Raised Wide Travel v3. Native archive and oriented millimeter STLs are supplied. This is prototype print geometry, not printer-ready G-code or a physical performance certification.

## CAD and motion

- Native feature health: no unhealthy features at final export; all exported bodies valid solids.
- Full neutral assembly and 8-gate operating sweep: zero clashes above 0.01 mm3. Sampled at 5-degree increments with extra samples at +/-58, +/-59 and +/-60 degrees. Frame checked using conservative rectangular envelopes; intended rail screw/slot engagement excluded.
- Alternative 3-, 5- and 7-gate cams: zero clashes at gate bottoms, crests and mechanical endpoints; cam extraction checked at 5 mm increments over 40 mm with the follower held down 5 degrees. Remove the large gear and the lower panel/pot/pinion assembly before extracting a cam. The remaining moving assembly is covered by the full 8-gate sweep.
- Final reinforcement extension: right sideplate checked against installed parts; added material checked against rotating parts at 2-degree increments. Zero clashes. Added bridge material lies inside Y +/-66 mm, clear of the rails' inner Y +/-75 mm edges. Follower and cam remain axially inboard of the bridge material.
- Stop verification: no overlap at +/-59.9 or +/-60 degrees; 0.2623 mm3 overlap at +/-60.1 and 8.0945 mm3 at +/-61. This establishes nominal structural stop contact at +/-60 degrees geometrically, not impact strength.
- Involute gear polygons: 481 poses at 0.25-degree increments over +/-60 degrees, no interference. At nominal center distance 45.15 mm, theoretical contact ratio 1.557. Keep adjustment within 45.0..45.5 mm; 46 mm reduces theoretical contact ratio below one and is unsuitable.
- Clamp slit and full-depth pinion tool channel: no additional nearest-tooth gap at the same 481 poses. This does not eliminate normal gear backlash.
- Cam contact: four profiles each checked at 481 poses. Maximum numerical roller penetration 0.000326 mm; no separation beyond numerical precision. Physical printed surface quality and spring force are untested.

The initial failed clearance report is retained in the working directory only; it is not the release certificate. It identified placements reset during Fusion feature creation, a refilled sensor rebate and an interrupted bearing load path. Final reports follow corrections. The later mesh check identified edge-only reinforcement joins; positive-volume overlaps were added and separately checked.

## Print preparation

There are 31 STL files, including four alternative cams; print only one cam for each assembly. Choose the seven-gate cam for a centered neutral notch, or eight gates when an even number of positions is intended. The native assembly displays the seven-gate cam.

All meshes have millimeter scale, positive volume, consistent winding, closed edges and a deliberate bed face. Individual part envelopes fit below 250 mm. Final connectivity checks require one shell and no degenerate triangles per file. Exported parts retain their individual assembly coordinates only in raw-stl; the supplied stl folder contains print-oriented copies centered on the bed at Z0.

New P01R/P02R sideplates and all four P08 cams print with their X-minimum faces down. Six changed meshes were sliced and layer previews inspected with unmodified flattened defaults: Bambu Lab P2S 0.4 nozzle, 0.20mm Standard @BBL P2S, Bambu PLA Basic @BBL P2S, Supertack Plate. All generated layers; support setting off and zero support extrusion segments. No floating-part or ZFiller warning was reported for these six changed parts. Long reported bridge paths include solid layers bridging internal infill and are not measurements of unsupported air spans.

Unchanged parts retain earlier geometry and orientations; this revision did not re-slice all of them or resolve the earlier lower-shaft ZFiller warning. Do not interpret the changed-part result as new proof that every unchanged part prints successfully without supports.

Bambu CLI still logs nozzle_volume_type not found and Invalid T command (T65535). Diagnostic G-code files are intentionally excluded from the ZIP. Re-slice the oriented STLs in the installed printer profile and inspect the preview before printing.

## Physical checks still required

Potentiometer usable rotation and internal mechanical limits are unmeasured. Full lever travel requires 240 degrees of pot rotation with additional mechanical safety margin. Verify the range before attaching the pinion. Terminal protrusion, thread pitch, shaft texture and supplied nut/washer dimensions remain unverified. Body width/height orientation is assumed.

Spring solid height/rate, printed shaft and bush fit, insert retention, gate force, end float, tooth backlash, strength and wear require physical testing. Keep spring preload conservative. An eight-gate cam places a crest at the centered lever pose, so the follower moves downward there; do not expect a central neutral detent. No top panel or cosmetic local housing is included.
