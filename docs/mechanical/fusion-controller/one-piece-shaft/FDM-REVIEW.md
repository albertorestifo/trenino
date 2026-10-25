# One-piece shaft: independent AI FDM review

25 October 2026. Source review of DESIGN.md and 01_build.py. No CAD mutations were performed by this reviewer. This is not physical strength or fit certification.

## Source assessment

The continuous flat at Y=-4.2 mm is a viable bed face, while retaining the functional upper D flat at Y=6.5 mm. The 6 mm radius journals produce the greatest initial side overhang, 44.43 degrees from vertical; the larger-radius central section and shoulder are gentler at the same bed plane. The flat remains continuous through the shoulder and Oldham tongue, avoiding a floating shoulder. Both shaft joining interfaces, their screws/nuts and loose keys are removed.

The M3 axial passage crown is correctly relieved toward positive Y, which becomes the upward print direction. The cap-nut installation slot opens through the bed flat. Its final ceiling spans the approximately 2.6 mm axial pocket width and is a full bridge, rather than an annular counterbore closure. Its actual sliced roof and the transition into the teardrop screw passage still require inspection.

Retain the indicated print orientation: Y-min flat down. Confirm manifold single-solid geometry, broad nonzero bed contact, no first-layer islands, and complete toolpaths around the nut pocket and functional tongue. The removed lower circular arc reduces journal contact area and central shaft section; fit, wear and strength require physical assessment. The 44.43 degree limit alone does not establish print quality.

## Review status

No source-level FDM blocker identified. Final exported geometry, default-profile diagnostics and critical sliced layers remain pending.


## Final v8 geometry and slice assessment

**Accepted for a physical prototype as oriented STL geometry**, after re-slicing in the correctly configured printer GUI. This is not approval of diagnostic G-code or physical strength qualification.

Both final STLs independently pass one connected watertight shell, consistent winding, positive volume and no degenerate faces after 0.0001 mm vertex welding. Hashes are recorded in FDM-FINAL-CHECK.json. The shaft has 931.81 mm² bed contact; the cam has 1519.32 mm². Both fit the selected build volume. The shaft has 61 consecutive 0.2 mm extrusion layers to 12.2 mm; the cam has 40 to 8.0 mm. Both diagnostic slices return zero and contain zero support segments with unchanged selected defaults. The former split-shaft ZFiller error is absent.

Inspected first layers, shaft nut/passage transitions, journal/central-flat closing layers, final tongue layers, cam screw recesses, top skin and E engraving. Focused previews are in fdm-layer-review/critical-1.png. The axial screw passage crown closes around 6.8 mm and the nut cavity around 7.8 mm, with short anchored bridge paths and no observed floating closure or missing layer. The upper D flat has continuous top-skin paths around 10.6–10.8 mm; the tongue continues to 12.2 mm. Cam counterbores widen upward and the E engraving remains open at the top.

The cam's reported 44.31 mm bridge segment is part of broad top skin beginning over sparse infill at 7.2 mm, visible against the preceding 7.0 mm layer. It is not a 44 mm open unsupported span. The shaft's longest bridge toolpaths also include skin over sparse infill. Do not present these toolpath lengths as unsupported-hole widths.

Known CLI configuration errors (nozzle_volume_type and invalid T65535) remain. Exclude diagnostic G-code from delivery; import the oriented STLs into the configured slicer GUI, inspect its preview and generate fresh printer output. Preserve the shaft flat on the bed and the cam X-min face down.

Physically check first-layer burrs, journal/bush fit, axial freedom, cap-nut installation/retention, coupling engagement and cam feel before normal hand loads. Reduced journal contact area and shaft cross-section still require wear/strength assessment. The center/emergency feel is a geometric intent; actual spring rate and operating forces remain unmeasured.
