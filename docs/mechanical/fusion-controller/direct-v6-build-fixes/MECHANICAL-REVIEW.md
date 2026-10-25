# Mechanical review — direct-drive v6 build corrections

25 October 2026. Independent AI mechanical review of the v6 construction scripts and documented geometry; this is not professional certification, material qualification or physical testing. No CAD was mutated by this reviewer. The user's built specimen provides stronger evidence of assembly problems than the earlier neutral/sampled collision checks.

## Required corrections and recommended implementation

### P04 cannot pass the shaft

This is a true assembly-order failure. P04 has a 12.3 mm running bore. The shaft has a 16 mm central section and a 20 mm integral shoulder at X37.35–40.35. Neither end permits the one-piece right bush to reach its 12 mm journal after shaft assembly.

The smallest replacement is **P04 as two radial half bushes**, preserving the 20.1 mm OD, 12.3 mm bore, 12 mm housing length and original 1.2 mm flange. Install the halves around the journal, then capture them in the P02 housing. The P02 bore is 20.3 mm and therefore nominally passes the 20 mm shaft shoulder; check its lead-in and printed fit explicitly. The plate housing must enclose the complete cylindrical part of both halves. Keep the split gap small and deliberate, not a large added running clearance. The captured housing, not glue or tiny screws, maintains their relationship.

This preserves both already printed shaft halves. A second valid approach is removing the integral shoulder and adding a removable collar, but that needlessly reprints the shaft for this particular field fix. If other shaft defects independently require a new shaft, reassess the choice and its axial retention as a whole.

Assembly proof must show P02's hole passing the shoulder, bush halves approaching radially, and the housing sliding over both bush halves. A neutral solid check alone is insufficient.

### Coupling engagement and measured pot stack

Existing dimensions, before the requested vertical recess:

- P18 disc X41–49; output groove X46.2–49.0.
- P19 output tongues X46.65–49.75; hub X49.65–58.65.
- Existing pot mounting face/body front X69.15.
- Old provisional pot shaft/bushing total projection was 19 mm (12 mm moving + 7 mm bushing).
- User measured 15 mm total, 8 mm moving, leaving approximately 7 mm threaded bushing.

With the measured pot at the old mounting face, the moving shaft is X54.15–62.15. Only 4.5 mm lies within the P19 hub. This 4 mm projection error explains why moving the clamp toward the shaft tip sacrifices the intended disc engagement.

**Recommended target:** move the pot mounting face to X65.65 (3.5 mm inward), retaining P18 and P19's nominal positions. The measured moving shaft then occupies X50.65–58.65, providing the full 8 mm overlap with the current hub, and the bushing starts at X58.65. Leave a small explicit axial bushing-to-hub clearance in the final dimensions, e.g. move the face another 0.2 mm outward if 7.8 mm grip is accepted. Avoid clamping any part of the threaded bushing. Keep the pot body's true front face as the datum, not the end of its nut.

P16's existing adjustment slot nominally permits 3.5 mm inward movement. However its panel is a physical stop: current P02 support ends are at X66.15 and its panel inner face is X66.15. Moving P16 inward without trimming the supports creates overlap. **Shorten the P02 supports by the chosen inward offset**, while checking carriage screw position against slot ends and preserved wall around the threaded receiver. P16 itself may then be reused. Its existing inner face is the body-front datum minus 3 mm. Verify the user's 11.2 x 9.5 x 6.6 mm body, washer/nut and prongs; prongs remain unmeasured.

At current coupling nominal positions the output tongue engages its groove by 2.35 mm (46.65–49.0); the input tongue engages by 2.35 mm (41.0–43.35). Groove bottoms retain 0.45 mm clearance at each interface. Do not remove all axial floating clearance merely to make the disc look tightly sandwiched. Check both groove clearances, face clearances and actual shaft gripping length simultaneously. A floating coupling accommodates misalignment and still has measurable reversal play.

### P13 preload reaction

Provide an actual **M3 captive hex nut at the spring-side bottom of P13**. The original bottom is Z38 before recess, becoming Z3 after the 35 mm recess. A bottom-access 5.7–5.8 mm AF pocket about 2.6 mm deep is a reasonable uncalibrated starting point for a nominal 5.5 mm AF x 2.4 mm nut. The pocket's upper shoulder must carry the upward spring reaction through the nut. Preserve a 3.4 mm clearance passage above it and fill the former oversized insert pocket above the nut so there is a genuine shoulder.

The existing M3x20 adjuster runs from head seat Z57 to tip Z37 at its initial position. It fully crosses a nut at Z38–40.4 and extends 1 mm below it. Moving the whole mechanism down 35 mm preserves this engagement. Check the collar's 1 mm adjustment and spring cup positions after conversion. Nut anti-rotation and assembly access are required; the cup must not be used as an improvised thread or friction restraint. Recess the nut so its underside cannot scrape the sliding cup.

P13 guide screws require a different pocket orientation: their tension pulls their reaction nuts downward. A simple bottom-open nut recess would not retain them. Use side-loaded pockets with a lower load-bearing shoulder, or a top-access through-fastener arrangement with an available screw long enough. For the present M3x12 guide screws, side-loaded nuts around Z41–44 (pre-recess) can preserve useful engagement. Verify these pockets against adjacent preload passage, cam relief and mounting pockets.

### Accessible nuts versus inserts

Prefer stocked standard M3 hex nuts if square nuts are not verified in inventory. For every conversion, model the nut's installation route, anti-rotation shape, load-bearing shoulder, screw engagement and retained material. A nut pocket accessible before the part is installed counts as accessible. Inserts are reasonable only when a nut cannot be inserted/retained without compromising the part.

For a field-update package, distinguish mechanically required reprints from optional nut conversions of otherwise good, already assembled parts. Do not imply that replacing all existing inserts is necessary for this specimen to function. Any retained insert fit change should use a small calibration coupon and preserve installed-envelope wall checks; the user's reported loose fit is a reason to reduce the pilot, not to increase clearance.

## Recess height and reuse strategy

Match the geared layout's pivot at world Z30, 25 mm below the rail top Z55. The direct-drive pivot was Z65, so translate its mechanism down 35 mm while keeping the fixed frame, mounting seats Z64, rail contact Z55 and M5x14 tip Z50 unchanged. Retain the direct-drive travel and cam profiles unless separately requested; matching height does not automatically authorize replacing them with 120-degree geared cams.

P01/P02 need revised rail-to-mechanism connections and are unavoidable reprints. Preserve their original mechanism-side holes, spacing and cam service path relative to the translated mechanism so good existing parts can be reused. Avoid tall thin mounting stalks: broad continuous webs should carry the lever moment into the rail tabs. Check frame clearance for the lowered cam, spring and pot as well as mounting tool access.

Likely minimum reprints before the FDM roof audit: P01, P02, P04 (two halves), P13. P18 and P19 can be reused if engagement is corrected by P02 support shortening and P16 repositioning. Counterbore fixes or justified nut conversions can add parts; publish the final list from actual shape comparison, excluding rigid translations and rotations.

## Required final checks

1. Compare each final printed part with the archived v6 local solid after undoing assembly transforms. Report changed geometry, not changed world coordinates.
2. Demonstrate right-bush insertion and coupling assembly with measured pot lengths.
3. Verify neutral and moving interference, hardware thread engagement, stop contact, spring adjustment and cam extraction at the recessed position.
4. Check every nut installation path and loaded shoulder, especially P13 guide nuts versus the opposite preload reaction direction.
5. Preserve the independent mechanical stops; pot travel/terminals and spring solid height still require physical confirmation.
6. Inspect final native feature health and actual slicer layers. Support-disabled settings alone do not establish printable counterbores.

Review status: the above approach is acceptable for implementation, conditional on final geometry and assembly verification. Final CAD has not yet been reviewed by this specialist.

## Implementation refinement agreed with primary agent

Use a 3.2 mm inward pot shift rather than the initial 3.5 mm target: body face X65.95, moving shaft X50.95–58.95, hub overlap 7.7 mm and 0.3 mm bushing-to-hub clearance. Trim P02 supports to X62.95; reuse P16 at X−3.2 relative to v6. This supersedes the initial 3.5 mm target above.

For P02 nut conversion, move screw axes from X60.15 to X58.15 so the installed nut does not break through the shortened support end. The translated P16 slot allows this. A candidate nut slot opens from the X62.95 end, with positive-side pocket Y22.5–25.1 (negative mirrored), Z62.1–67.9 and X54.8–63.05. Use the nut's flats parallel X so AF is measured along Z; the outer Y wall carries the clamping load. P16 covers the opening after assembly. Verify actual receiver/nut/tip clearance.

P13 candidate guide nut pockets are Z40.8–43.4, X4/20 +/-2.9, opening along Y from the front edge toward Y−58.3. Nuts are normal Z, with flats giving 5.5 mm AF across X. The X20 nut leaves only 1.25 mm to block side X24; this requires explicit FDM/strength review and may justify a local change. The block cannot simply widen through the plate at X24.

P13 mounting nut pockets can open from top Z59 to Z50.6, at X−20..−17.4 and X17.4..20, centered Y−62/−70 with 5.8 mm width. The outside 4 mm of material to X±24 is the loaded shoulder. P19 clamp candidate nut slot opens from Z78.1 to70.1, at Y−6.9..−4.3 and X54.15 +/-3.3; a nut at Y−6.8..−4.4 fully engages the M3x16 screw ending Y−7. Its positive-Y shoulder carries tension. Check the remaining ~1.2 mm axial walls and replace overly weak geometry if necessary.

All pocket dimensions here are pre-recess coordinates. Subtract 35 mm from Z only for the installed recessed mechanism. These are construction candidates, not a substitute for final geometric verification.

## Review of implementation scripts 01–04

Reviewed 01_mount_and_coupling.py, 02_nut_interfaces.py, 03_insert_fit.py and 04_recess.py before final motion verification. The measured coupling placement and captive-nut load directions match the mechanical recommendations. Rear-loaded guide slots avoid the front cam relief. Actual guide-nut material to the right block edge is approximately 1.25 mm (slot leaves 1.1 mm); the rear mounting nut at Y−70 leaves 0.825 mm to the rear edge (slot leaves 0.65 mm). These are side walls, not the principal axial loaded shoulders, but remain explicit FDM/robustness review points.

The preliminary grounding loop in script01 ungrounds every occurrence. Script04 excludes the fixed frame and rail bolts from translation, so it should also explicitly reground these skipped occurrences; otherwise their positions are numerically unchanged but their fixed assembly constraint is lost. The primary implementer was notified.

No additional mechanical blocker was found in these four scripts. Final motion, nut insertion, bush assembly and print verification remain required before completion.

## Optional nut conversions reviewed

P07: rear-open cam nut pockets are mechanically preferable to new inserts under the user's preference. Candidate pocket X−7..4.6 with nut X2.1..4.5 leaves a 2.4 mm forward loaded shoulder; at R36 mounting centers the installed M3 nut circumradius (~3.175 mm) leaves approximately 1.8 mm to R41. The rear-opening hex prevents rotation but does not independently prevent axial loss after its screw is removed; document nut handling during cam service. A side-loaded rotor clamp nut at Y15.2..17.8 loads the positive-Y shoulder through the cap seat Y22.5. Preserve clearance down to the shaft flat for the long clamp screw.

P05: a cap nut at X−33.9..−31.5 in a pocket X−34..−31.4 can be installed across the longitudinal split before the halves close. The 3.35 mm negative-X shoulder carries cap load; the existing M3x8 tip at X−31.35 crosses the full nut. Joining nuts at Y−4.4..−2.0 in pockets Y−4.5..−1.9 also receive the full screw thread. Their positive-Y shoulder to the split face is only 1.9 mm, so joining torque must remain modest; the shaft D geometry carries operational torque. Bottom-Z nut installation slots leave approximately 5 mm axial ligament to neighboring keys/end transitions, but introduce printable internal roofs that the FDM specialist must inspect explicitly.

P09: retaining a secure existing insert-equipped handle is justified. A conversion using the same M3x20 grip screws would leave at most approximately 1.4 mm loaded material behind the socket for the nut position needed for engagement. A tighter pilot and small lead-in can therefore remain an optional insert-interface revision, rather than weakening the socket merely to eliminate an insert. This is a geometry/load-path exception, not an assertion that the part is inaccessible before assembly.

## Corrected bush assembly sequence

The split bush alone does **not** make it possible to approach the preinstalled right bush with P02 from the right: the 25.5 mm outer flange blocks the 20.3 mm housing bore. The earlier recommendation must therefore be read with this corrected sequence:

1. Strip the main shaft of cap, rotor, thrust spacers, bushes and sensor coupling. Join the shaft halves first.
2. Slide empty P02 from the **left** shaft end over the bare 12 mm journal and 16 mm central shaft. Hold it 40 mm left of its final position, with its housing spanning X−16..−4 and its sensor support arms ending at X22.95. This clears the radial approach to the bush starting at X24.
3. Place the two P04 halves radially around the right journal at X24–36.
4. Slide P02 right 40 mm to capture the bush body. The flange remains outside at X36–37.2.
5. From the left, install P24 right thrust spacer, rotor and P23 left thrust spacer, in that order.
6. Preinstall P03 in P01, then slide the **left plate and bush together** onto the left journal. Sliding P01 onto an already seated left bush from the left would also encounter its flange.
7. Fit the cap and remaining mechanism parts.

This sequence preserves the printed shaft and avoids passing its 20 mm shoulder. A read-only numerical audit was supplied as 06_assembly_path_review.py, including every above approach with a declared 0.01 mm3 interference threshold; its result must be checked before this assembly sequence is released as verified.

The preliminary 12 mm P02 hold offset was superseded by 40 mm: its projecting sensor arms would otherwise obstruct the radial Y approach of the split bush. The updated numerical audit uses the 40 mm hold and capture distance.

## Final mechanical review — saved direct-drive v7

**Disposition: approved as prototype geometry for the documented field-update build. No outstanding mechanical CAD blocker was found in the reviewed evidence.** This is an AI engineering review, not a certified load rating or a substitute for the physical checks below.

Reviewed final construction scripts, `native-health.json`, `export-manifest.json`, `reuse-check.json`, `neutral-check.json`, `motion-check.json` and `assembly-path-check.json`. The native report identifies saved **AIDesignedLever v7**, unmodified, with 526 healthy features and 31 exported print files. The motion/neutral reports still say v6 because they ran before the save increment; the primary implementer reports that the only subsequent geometry correction removed a 0.1 mm old fill protrusion on P02. Material removal there cannot invalidate the previously clear assembly paths. The final native/export evidence identifies the delivered state.

- Final neutral evidence reports zero overlaps above the 0.01 mm3 threshold.
- Motion evidence covers 25 angles from −52 to +52 degrees for each of three cams (75 operating poses), with zero reported clashes. The service audit additionally checks six outward cam positions per cam after removal of the sensor carriage/coupling and holding the follower at −4 degrees. This is sampled clearance, not a full spring/contact simulation.
- The dedicated shaft/bush/plate assembly audit covers **295 sampled poses**, including the corrected 40 mm P02 hold offset and radial P04 insertion. Every stage reports zero overlap. P01 must still be installed together with its preinstalled P03 bush.
- Export transforms confirm the mechanism moves down 35 mm, including P02/P04/P05/P07/P13/P19. P16 is additionally shifted inward 3.2 mm, preserving the intended 7.7 mm moving-shaft engagement and 0.3 mm bushing-to-clamp gap. The rail seating geometry remains at its original installed height.
- The optional shaft and rotor nut conversions preserve the reviewed thread engagement and load directions. P13's added rear wall improves the previously noted rear mounting-nut ligament; the guide nut near X24 still has a comparatively thin side wall and should be assembled gently. The grip's retained inserts remain an explicit wall-strength exception.
- Reuse evidence excludes assembly translations. Unchanged P16/P18, cams, spacers, grip screw half and other unmodified parts should not be reprinted simply because the mechanism is lower.

### Physical commissioning conditions

Use light assembly torque, especially on printed nut shoulders and the split shaft. Confirm the split bush slides into its housing without force, all nut flats seat fully, the shaft rotates freely, and no screw bottoms before clamping. Check the actual pot bushing-to-hub clearance and shaft grip before tightening the clamp; the pot's terminals and usable angular travel remain physically unverified. Confirm no spring coil bind at detents, preload extremes or cam service, and restrain the spring-loaded follower deliberately during cam changes. The direct-drive version retains its existing stops and cam travel; no claim of increased travel, load capacity or durability is made. Treat the optional 3.8 mm grip insert bore and 0.2 mm lead-in as a fit candidate requiring a small test print.

FDM slice/bridge acceptance belongs to the separate FDM review. The prior physical build demonstrated why support-disabled slicer settings and neutral CAD checks alone are insufficient; the corrected assembly sequence and bridge details must be followed.
