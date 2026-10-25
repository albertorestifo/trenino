# Geared comparison — current print geometry checkpoint

Updated 2026-10-25: geared cloud design is now saved as **v3**, unmodified; coupling baseline v6 is unchanged. Applied `05_printable_pinion.py`: support-free open pinion channel, 30-degree pinion indexing and corrected G03 screw slots. Final `06_final_clearance.py` found no clashes at 23 angles for all three cams; G01 must be removed for cam service. The tool request timed out, but the completed report was subsequently inspected.

Current deliverable: `Geared-Lever-v3-Print-Geometry.zip`, three arranged geometry plates and 30 oriented STLs, with checks and instructions. Mesh, scale, bed contact and plate-layout checks pass. Slices have no floating-region warning and no support extrusion. CLI machine/tool errors and a lower-shaft ZFiller diagnostic remain, so no toolpaths are released. See PRINT-README.md and VALIDATION.md; do not describe this package as certified printer-ready G-code. Native archive is Geared-Lever-Print.f3d. The historical development notes below are superseded by this paragraph.

2026-10-25. Separate cloud document **AIDesignedLever Gear Comparison v2**, ID `urn:adsk.wipprod:dm.lineage:HlxCOdQOSdGZfMtoCnyuyw`. Saved and unmodified after export. Baseline **AIDesignedLever v6**, ID `urn:adsk.wipprod:dm.lineage:2iFF2PJAQnO13x73oN2c-w`, remains saved and unmodified.

Native archive: `Geared-Lever-Development.f3d`. Visually inspected in Fusion. Native feature audit after clamp refinement returned no unhealthy features; pinion remains one body. The initial build timed out at the connector but completed in Fusion; do not rerun it. Applied scripts: `01_build_geared_variant.py`, then `02_refine_clamp.py`. The second script relocates the pinion clamp to Z117.65 mm, insert entry Y−7 mm. The initial script alone is not the final model.

Planar profile test: `gear-profile-check.json`. This is not an assembled clearance test. Original as-built joints and rigid groups were removed during rebuilding; new geared motion joints/link are still to be added. Do not mistake free assembly geometry for a constrained simulation.

Remaining before print release: full solid motion clearance checks including clamp hardware; verify gear phase and uninterrupted contact at extremes; constrain permissible mount adjustment; restore appropriate joints and motion ratio; export and inspect meshes; choose print orientations; slice and inspect support-free layers; create illustrated geared assembly guide. Potentiometer dimensions, travel and taper, spring behavior, and stock recount remain physical assumptions/checks.

Use `COMPARISON-PLAN.md` and `COMPARISON-RESULTS.csv` for A/B evaluation. No physical results have been collected. Combined inventory project was created successfully; subsequent project check had a transport error and must be retried. No inventory was consumed.
