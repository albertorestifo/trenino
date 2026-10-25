# Final FDM specialist review

**Reviewed revision:** `integrated_controller.fs`, SHA-256 `55BBD86D6E83CB2951BB7B343A7EB9D457634D090BFEE3F14FED64A4AAB279BD`.

I reviewed the final source, the 22 exported mesh results, slicer reports, print/assembly guide, and `reviewed-assembly.png` / `reviewed-internals.png`. This review checks design for FDM and assembly access; it is not a physical print, a strength certification, or a claim that a successful slicer exit guarantees usable parts.

## Disposition

The revision is suitable for a **supported PLA fit-and-function prototype**, with the support-setting correction below now completed and the explicit physical fit checks in the guide. I found no new mandatory CAD redesign for this prototype. The base is now a set of independently printable plates attached to the 2020 rails, the lever belongs to the main gear, and the grip consists of two printable rounded halves. The printed shaft remains a prototype wear/load component.

**Closed print-setting correction:** Supports have now been enabled for **M07 carrier/stop lug**. The lug's rectangular column reaches y=34, while its R4 rounded tip reaches y=38 and begins at z=42. With the carrier bottom at z=27 on the bed, the forward semicircle has a flat 4 mm overhang beginning 15 mm above the bed. The initial final-pass report marked M07 `Supports=false`; the corrected re-slice uses `enable_support=1`, exits successfully, and produces a 705,066-byte validation output. It is accessible for support removal; enabling support is sufficient without changing CAD. Support should touch this ledge, not obstruct the insert pockets. Verify the generated support under this ledge in the final Bambu Studio slice before printing.

## Initial findings resolved

| Earlier finding | Final revision |
|---|---|
| Fork long bars were 1 mm above the bed because a larger round nose set the bottom | The fork now has a common y=-55 flat side with broad bed contact. Its nose remains a short accessible overhang; supports are enabled. |
| Only 1.35 mm ligaments beside the fork pivot | Pivot region is 14 mm wide around Ø7.3, leaving 3.35 mm nominal ligaments. The bar tapers toward the roller to preserve clearance. |
| Axle screw counterbore left only 1.2 mm seat | Upper cheek is 4 mm thick; the head seat now has 2.2 mm beneath it. |
| Pivot tightening could squeeze the printed fork | The metal 7 OD × 5.2 ID × 20 mm sleeve carries the bolt clamp between stationary plates, with clearance to fork outer faces. |
| Shaft journals sit above the D-flat-down bed plane | Shaft remains horizontal and has support enabled. The journal surfaces still need careful cleanup and fit testing. |
| Thin spring-block edge at the insert | Column grew from 10×24 to 12×26 mm. At the closest y=-26 pocket the nominal material to the y=-21 edge is 2.7 mm around the installed Ø4.6 insert. |
| Thin standalone stop and many spacer stacks | The arch now mounts to 2020 rails, uses steel-core stop bolts, and the ten spacer stacks were removed. The carrier lug is thicker, though its new rounded ledge needs support as noted above. |
| Separate shaft-mounted handle | The large gear and lever stem are one print. Two grip halves clamp around the keyed stem. |
| All slicer commands failed due to missing process-profile path | All 22 final report entries have success=true and nonzero output. This corrects the execution failure; it does not certify actual print quality. |

## Final part assessment

| Part | Orientation, supports and remaining prototype checks |
|---|---|
| M01 D-shaft | Horizontal D-flat-down is appropriate for longitudinal material continuity. Supports are enabled for journals and hole roofs. Do not auto-orient upright. Remove support without making flats on the journal surface. Heat-setting the two inserts can distort the Ø9.2 journals; install with a holding jig, allow cooling, then check rotation in both bushings. Sharp shoulder transitions remain a fatigue/wear caveat, not a blocker for modest-load fit tests. |
| M02 bushings, two | End-face-down gives circular XY bores. Ø9.6 bore on Ø9.2 shaft is nominal 0.4 mm diametral clearance, and Ø15.9 outside in Ø16.1 seats is nominal 0.2 mm diametral clearance. These are CAD allowances, not measured printed fits. Print with shaft first, clean/ream as needed, and verify axial capture on the real frame. |
| M03 end caps, two | Flat 1.6 mm washers print readily. They retain the shaft; they are not intended for high tightening torque. Inspect for dishing and avoid clamping the rotating stack solid. |
| M04 integral main gear and lever | Broad face down is appropriate. The original lever socket is filled by the continuous stem/root union. The reinforced root tapers from 28 mm width to an 18 mm intermediate section and then a 12 mm stem, all 12 mm thick. The gear and root are continuous rather than joined by a small printed thread. The stem's two Ø3.4 grip holes leave 4.3 mm nominal side ligaments. Check stress whitening/flex at root and grip holes in initial use. Keep supports off gear teeth; none are required by the supplied orientation. |
| M05 13 mm spacer | Upright annular tube is printable without support. Its Ø16/Ø12.6 section has 1.7 mm nominal wall, suitable as an axial spacer, not a radial bearing. Clean both end faces and avoid overtightening the stack. |
| M06 cam sector | Flat orientation preserves the roller track in XY. Supports are enabled beneath accessible underside boss reliefs; remove them through the inner-edge openings. Keep the track free of support scars. Screw seats above relief roofs remain approximately 2.2 mm thick. Check the seam and elephant foot without sanding away the designed profile. |
| M07 carrier/stop lug | Broad base down and vertical insert pockets are appropriate. Ø9 insert bosses around Ø4.6 inserts leave 2.2 mm nominal radial plastic with 1.8 mm pocket floor. Enable support under the raised rounded tip as specified above. The tall lug remains an impact-sensitive printed feature; begin with slow stop contact, not slamming. |
| M08 fork | Shared flat side and supported nose are appropriate. Upper cheek and pivot region are strengthened. Ø7.3 printed pivot bore on Ø7 metal sleeve is nominal 0.3 mm diametral clearance; clean/ream rather than force the tube. Ensure no residual support in the head pocket and free rotation after tightening. |
| M09 roller | End-face-down, no supports. Ø4.3 on Ø4 tube gives nominal 0.3 mm diametral clearance. Smooth any seam protrusion; verify rotation with axle fully secured and 9.5 mm roller inside the 11 mm tube span. Surface finish and wear remain functional prototype checks. |
| M10 lower rounded grip half | Split-face-down with supports is appropriate. The long stem recess opens toward the split face and grip mouth, so support is accessible. Insert holes enter from the recessed stem seat; install the two inserts before assembling grip around the stem. There is substantial body thickness beneath the pockets at y=115/125. Clean the socket so the keyed stem seats rather than forcing the halves apart. |
| M11 upper rounded grip half | Split-face-down with supports. The curved exterior rises continuously from the broad split face; support is chiefly for internal socket/roof details. Screw counterbores leave about 6.3 mm between the socket roof at z23.7 and the head seat at z30. Round crown is suitable for a palm grip; the split seam and recessed screw mouths need deburring for comfort. It is an ergonomic prototype, not a validated hand-size fit. |
| S01 lower follower plate | Broad plate face down; the 12 mm rail feet rise from that face. The lower pivot head pocket has a 3.5 mm remaining seat. Small horizontal M5 mounting holes can bridge and be cleaned. Printed feet must sit flat against rail faces before tightening. |
| S02 upper follower plate | Flipped to place its broad top face down, including rail foot. The captured nut leaves 2 mm seat thickness. The nut/head recess roofs involve short bridges; check the actual layer preview for clean hole openings. No long floating plate or inaccessible enclosed support volume remains. |
| S03 spring block | Side-down with supports is reasonable for the guide boss and nut-pocket features. Four blind insert bores are horizontal; prevent unremovable support inside them and clean the small roof before heat-setting. The expanded column provides better wall margins. Do not tighten the block while inserts are warm. |
| Spring cup | Broad back face down, guide peg upward; no supports needed. The 2 mm plate and small edge ligaments around guide holes locate the cup, while the adjuster directly backs the spring load. Confirm sliding without binding after support-free printing. The pilot is slender, so remove from bed by the plate rather than levering on the peg. |
| Preload limiter | Upright annular end, no support. Ø8/Ø4.5 gives 1.75 mm nominal wall. This is a compression limiter; ensure its ends are flat and it does not split from forced screw insertion. |
| S04 steel-core stop arch | Broad 6 mm arch face down; rail feet rise to 12 mm, and stop regions are coplanar with arch. No unsupported tall stop posts remain. Steel bolts reinforce the stop regions but the polymer still takes contact. Inspect bolt-hole and arch-root damage after first stop tests. |
| Two original frame plates | Broad faces down with bearing seats upward. The 190×93 mm footprints fit the P2S. The large flat prints can warp; clean plate and brim if needed. Existing compatible plates can be reused. Check axle alignment after bolting to the real rails. |
| Original potentiometer gear | Flat face down; no support on teeth. Preserve the bore and mesh, but confirm the actual pot shaft engagement. It is the only gear in the frame group; the main gear is integral with the lever in moving parts. |

## Evidence and limits

The mesh report records all 22 parts as single connected, consistently oriented closed meshes, with no nonmanifold edges, Z≈0 and bounds within the 256 mm printer envelope. I verified the 22 slicer records and support choices against the geometry, including the M07 exception above. The CLI logs also contain preset/tool-command diagnostics (`nozzle_volume_type`, `T65535`) and some geometry-processing diagnostics despite exit zero. Therefore these generated G-code packages are **not printer-ready releases**. Use the geometry package, open in Bambu Studio with the user's installed P2S/filament profile, inspect layers/supports, and slice there.

Print the shaft, bushings and roller/insert fit coupon before committing to all large parts. Supports should be removable without changing functional faces. For the first bench test use low preload and gentle hand force; the final spring candidate can exert substantial load, and printed compliance, stop impact, wear and insert retention have not been measured. Recheck fits if switching from PLA to PETG. No additional CAD changes are required by this final FDM review for that limited prototype purpose.

## Implementation closeout

The main agent closed the M07 support condition by re-slicing it with support enabled (exit 0; 705,066-byte output); this does not change the CAD geometry. The later mechanical correction changed only S03's nut capture: the M4 pocket now opens toward the spring side (y=-28.1 to -24.7), leaving a 2.7 mm front wall, with the modeled nut at y=-27.9 to -24.7. The final source SHA-256 is `8E0F76D93B1EF02D5618B50AD2BF37C296640A0BEEAB5AC801CBEB40222B2606`. This limited change does not alter the S03 print orientation; its already-enabled removable supports remain appropriate. Export/re-slice of that revised S03 is the main agent's release check. No further FDM CAD change is requested by this review.
