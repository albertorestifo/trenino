# Mechanical review — one-piece shaft increment

25 October 2026. Independent AI mechanical review of DESIGN.md and 01_build.py. This review covers only the one-piece P05 change; it does not repeat or replace the direct-drive v7 mechanism review. No CAD was edited by this reviewer.

## Preliminary disposition

The continuous-flat one-piece shaft is a reasonable prototype implementation of the approved concept. It removes the split joint, two joining fasteners and two alignment keys, while retaining the existing upper D drive face, shaft endpoints, bush axial locations and retaining shoulder face. A final clearance/native/slice check is still required before delivery. No tested load, fatigue or wear rating is established.

## Mechanical consequences to document

The underside plane at Y−4.2 removes circular journal material while leaving more than 268 degrees of the circumference. This does not produce the full 1.8 mm flat depth as radial free play: the remaining corner points still constrain the shaft inside the round bush. With ideal shaft R6, bore R6.15 and flat at Y−4.2, maximum translation toward the flat is approximately sqrt(6.15^2 − (6^2 − 4.2^2)) − 4.2 = 0.212 mm, versus 0.150 mm for a complete circular journal. The extra theoretical travel is about 0.062 mm. This assumes exact rigid geometry; printed seams, shrinkage, bed expansion and wear can dominate it.

Loads directed toward the flat are carried near the two remaining arc edges. Local bearing contact pressure and wear may therefore change even though nominal bore fit remains possible. Deburr only bed-edge flare, avoiding uncontrolled removal from the round running surfaces. Check rotation under gentle hand load at all lever angles and inspect for rocking, binding and edge wear.

The flat also shortens the Oldham input tongue's transverse span from Y−8..6.5 (14.5 mm) to Y−4.2..6.5 (10.7 mm), a 26.2% reduction. The axial groove engagement remains nominally 2.35 mm, but the torque-contact area and effective arm are reduced; reversal clearance may change. Do not describe the complete coupling engagement as unchanged. The output coupling and pot clamp are unchanged. Physical comparison should include readings reached from both directions.

The central-section area percentages are geometric descriptors only. The new continuous material replaces the old joining bores, nut slots and key pockets, so removed outer area alone does not determine whether the completed one-piece part is stronger or weaker than the old assembled shaft. The material, print paths, original split compliance and specific load case all matter.

## End-cap nut and assembly

The X−34..−31.4 cap-nut pocket keeps its original negative-X load-bearing shoulder and screw engagement. Bed-side access is appropriate, but the left bush covers it after assembly. Install the nut first with the loose shaft oriented so the bed flat/opening faces upward under gravity; then slide the preassembled P01/P03 pair onto the left journal and fit the cap and screw. Avoid using the cap as a permanent obstruction while trying to pass the left plate/bush.

The split P04 and the corrected right-plate sequence remain necessary: hold P02 40 mm left, place the bush halves radially, then slide the plate right to capture them. Retain the earlier ordering for the right spacer, rotor, left spacer and left plate/bush. The shaft's loss of material should not create new outer-envelope collisions, but removal of joining hardware and the new nut entry require actual final verification.

## Final acceptance evidence required

- One valid native shaft solid, healthy history and the intended saved document state.
- Re-run neutral fit, shaft motion and the established bush/plate/rotor assembly paths with the new P05.
- Verify the cap nut and screw fit the new pocket and that the passage crown leaves useful material.
- Mesh/orientation/slicer evidence for the continuous flat, journal side slopes, cap-nut closure and screw-passage crown; separate FDM review owns that acceptance.
- Update the assembly guide and BOM to remove shaft joining screws/nuts and P28 keys, and identify the one-piece shaft as the only replacement caused by this increment.

Status: acceptable for prototype implementation, subject to final evidence above and physical bearing/coupling checks. Final exported geometry has not yet been reviewed.

## Tongue refinement proposed during review

The primary implementer proposes extending the positive-Y input tongue tip to Y8 while retaining the central/shoulder D-flat at Y6.5. This is mechanically reasonable pending final interference checks. The new transverse span becomes 12.2 mm (Y−4.2..8), 15.9% shorter than the old 14.5 mm span, while restoring the maximum 8 mm contact arm and its nominal first-contact angular-clearance bound. Contact remains more asymmetric, so equal stiffness, wear and measured backlash must not be assumed. The upper addition connects through the lower tongue and prints upward in the selected bed orientation. At Z±2 the R12 disc boundary leaves roughly 3.8 mm radial-side clearance beyond the Y8 tip; the axial groove depth remains unchanged. This supersedes the 10.7 mm tongue-span assessment only if the extension is present in final CAD.

## Nine-notch cam increment — independent geometry review

The proposed nine gates are evenly spaced from −50 to +50 degrees in 12.5-degree steps. Proposed interval lifts, from the negative end to the positive Emergency end, are `[0.65, 0.65, 0.65, 0.90, 0.90, 0.65, 0.65, 1.00]` mm. Retain the existing roller-radius compensation using the 35 mm follower arm and 5 mm roller radius. This is an engineering detent proposal; it does not establish fidelity to a particular train's measured force curve.

An independent numerical reconstruction was evaluated with 0.025-degree outer-profile sampling and 1,041 roller positions over −52..52 degrees at 0.1-degree steps. The polygon is valid; maximum apparent roller penetration is 0.00000555 mm, consistent with polygon discretization, and the maximum profile radius is 48.999866 mm. Results are recorded in `nine-notch-envelope-review.json`. This check evaluates the proposed mathematical profile, not the final native cam, mounting hardware or service path; compare the final CAD outline and run the normal assembly checks before export.

The piecewise cosine construction has zero displacement slope at each gate and maintains continuous position and slope across interval boundaries. Different neighboring amplitudes change curvature at those boundaries; the result is not a geometric corner in the driving displacement. The narrower pitch increases slope/curvature relative to simply adding gates at the old lift, which is why the independent roller-envelope check matters.

The stronger center-adjacent intervals produce larger barriers around the center. The higher final interval produces a larger barrier before the Emergency position. These passive barriers are **bidirectional**: they also stiffen approach to the center and exit from Emergency. They do not provide a one-way interlock or prevent accidental Emergency selection. At equal spring force, peak displacement-slope ratios are approximately 1.385 for center intervals and 1.538 for the Emergency interval relative to ordinary intervals. Actual hand-force ratios depend on spring rate/preload, geometry, friction and printing and cannot be specified from these lift values alone.

With the original approximately 20 mm spring-tail arm, a 1.00 mm roller lift produces about 0.571 mm extra spring compression, less than the original 1.4 mm roller-lift cam's approximately 0.8 mm. This reduces the nominal compression demand but does not establish clearance to the unknown spring solid height. Confirm the higher barriers feel appropriate during the physical comparison, and retain independent structural stops beyond the terminal ±50-degree gates.

Disposition for this cam concept: acceptable for prototype implementation; no roller-envelope blocker found in the independent numeric check. Final native profile, mounting/service motion and print checks remain required.

## Final review of saved v8 — one-piece shaft and nine-notch cam

**Disposition: approved as prototype geometry for the documented reprint package. No outstanding mechanical CAD blocker was found in the final evidence reviewed.** This closes the earlier pending geometry-review status; physical load, tactile-force and durability validation remain open.

Inspected the actual `native-health.json`, `neutral-check.json`, `assembly-path-check.json`, `motion-check.json`, `native-cam-contact-check.json`, final cam construction script, reprint manifest and guide. The native state is **AIDesignedLever v8**, saved and unmodified, with 508 healthy features. The two new exported geometry files are the one-piece shaft and nine-notch cam; the complete field-update package also includes the six required prior correction prints.

The final tongue extension to Y8 is present in the construction script, and the shaft print envelope has 12.2 mm height from the Y−4.2 bed to Y8. This supersedes the preliminary unextended 10.7 mm tongue assessment. The upper central D drive face remains unchanged.

Verification reviewed:

- Final neutral report: no reported clashes or unhealthy features.
- Shaft/housing/bush/rotor assembly: 295 sampled poses, all zero overlap, including the 40 mm P02 hold offset and the preassembled P01/P03 approach.
- Nine-notch mechanism motion: 37 operating angles including every gate/crest neighborhood and the ±52-degree stops, plus six sampled outward removal positions; no reported clashes above the 0.01 mm3 threshold. The service configuration removes the sensor carriage/coupling and holds the follower at −4 degrees.
- Exported native-cam contact reconstruction: 1,041 positions, minimum gap −0.00137686 mm and maximum gap +0.00033417 mm. These small deviations are consistent with the exported polygon/tessellation approximation and lie within the check's declared ±0.01 mm criterion. This is not a claim of exact zero penetration in the exported polygon.
- The reprint manifest identifies eight required closed, single-shell prints from original v6: P01, P02, both P04 halves, P13, P19, one-piece P05 and nine-notch P08. P07 rotor and P09 grip half remain optional replacements. No reprint of the reused floating disc, pot panel or unchanged spacers is caused by this increment.

The clearance reports retain the document label v7 because they preceded the save increment; final native health identifies v8. The primary implementer reports no later geometry change affecting those checks. Native save state and exported files must be kept together with this evidence.

Before use, confirm nut seating, bush freedom under light load, actual pot travel/terminal clearance and absence of spring coil bind. For cam service, backing off preload alone may not completely unload the captured spring; restrain the follower deliberately or remove the spring before releasing the cam. Verify that the stronger center/Emergency transitions feel suitable in both directions. Watch the asymmetric input tongue and flattened journals for initial wear or rocking. Do not infer a working-load rating or train-authentic tactile force from these digital checks. FDM acceptance and slicer/toolpath limits are recorded separately.
