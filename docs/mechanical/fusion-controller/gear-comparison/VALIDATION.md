# Print geometry validation — geared v3

Saved cloud design: AIDesignedLever Gear Comparison v3, independent of the unchanged coupling baseline v6. Native archive: Geared-Lever-Print.f3d. The final native audit found 404 features, no unhealthy features and 30 printable body exports. The model is saved without pending changes.

All STLs use millimetres, preserve native scale, have consistent winding, closed edges, positive volume and bed contact. The release contains 28 parts for a 7-gate build plus two alternative cams. Hardware and frame references are excluded. Print rotations are right-handed; assembly geometry stays assembled in Fusion. The plate files contain geometry only and retain the default-profile preference.

The final solid interference check found no overlaps above 0.01 mm³ at 23 lever angles spanning −52 to +52 degrees, for each of the three cams. The sensor pinion moves at −2 times the lever angle. Cam withdrawal was checked in 5 mm steps to 40 mm with the follower retracted and G01 plus its clamp removed. Removing G01 is a required service step. This is sampled clearance evidence, not a continuous contact/force simulation. The frame's reference meshes and spring deformation are outside this solid check.

Full involute profiles were separately sampled every 0.25 degrees without overlap at center distances 45.0, 45.15 and 45.5 mm. The pinion is indexed by two full teeth (30 degrees); this preserves mesh phase. Its revised clamp channel removes material only and lies in the unused tooth sector when correctly indexed. The final solid check excludes repeating the full complex gear-to-gear boolean and relies on that profile evidence. Remaining physical backlash, tooth strength and sensor accuracy require testing.

All 30 parts generated layers with supports disabled. First, bridge/top and final-layer previews were inspected, including revised pinion and panel. The pinion's initial floating-region warning was eliminated by opening its clamp tool channel. The final diagnostic logs have no floating-region warning. Three arranged geometry plates also load and generate layers.

**No printer-ready G-code is supplied.** Bambu Studio CLI 02.04.00.70 reports `nozzle_volume_type not found` and `Invalid T command (T65535)`. It also emits a `ZFiller: encounter idx from clip: 24` diagnostic for the lower shaft, including on its combined plate; layer generation completes, but that diagnostic remains unresolved. Slice the supplied geometry in the normal Bambu Studio UI and inspect the result before printing. If the lower shaft still reports a clipping issue in the UI, do not print that toolpath; the affected files are P05G-Shaft-lower-half.stl and Plate-03.3mf.

The checked default profiles are P2S standard-flow 0.4 mm, Bambu PLA Basic, 0.20mm Standard @BBL P2S and Supertack Plate, with no process or filament tuning. These checks establish prepared prototype geometry and support-free layer generation, not physical print success, material strength, insert retention or measured potentiometer fit.

Files are tied to delivery-hashes.json. Reports retain the earlier findings separately so the corrected mounting slots and service requirement are traceable. Original assembly joints were removed during the geared conversion; clearance uses explicit temporary transforms rather than a saved motion-link simulation.
