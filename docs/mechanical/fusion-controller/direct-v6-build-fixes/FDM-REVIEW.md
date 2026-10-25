# Direct v6 build feedback: FDM design review

25 October 2026. Independent AI FDM review of construction scripts 01–40 and the released v6 oriented STL geometry. This is a design review, not physical qualification. No Fusion mutations were performed by this reviewer.

## Findings requiring correction

1. **P01 stop-head counterbores have unsupported annular ceilings.** With the released X-min-down orientation, the two 6.2 mm head pockets close to 3.4 mm screw bores at print height 4.5 mm. The combined downward-facing planar area is 42.04 mm². The earlier zero-support slice statement did not establish that these inner circular perimeters were anchored.
2. **P13 preload head/limiter recess has the same problem.** With Z-max-down printing, the 6.8 mm recess closes to the 3.4 mm passage at height 4.0 mm; annular area is 27.22 mm². Correct this roof as part of the new reaction-nut design.
3. **P04 insertion is a geometry/assembly failure, not an FDM tolerance problem.** The 12.3 mm bore cannot pass the 20 mm integral shaft shoulder. Enlarging the bush bore would destroy its journal function. Remove the integral obstruction and use a removable retaining feature, or supply a deliberately split bush. The mechanical reviewer should choose the complete stack; changing a clearance number alone is unacceptable.
4. **Retained heat-set pockets need a fit correction explicitly based on the user's print result.** v6's nominal main pockets are diameter 4.0 mm (not 4.2 mm). A proposed 3.8 mm straight pilot plus a small 0.2 mm × 45° entrance chamfer is a reasonable new coupon candidate, not a validated universal fit. Keep at least 6.7 mm blind depth for the 5.7 mm insert and inspect wall around its installed 4.6 mm diameter. Do not taper the entire bore. The requested small chamfer intentionally differs from the supplier's usual no-chamfer guidance.
5. **Prefer accessible captive nuts.** Convert accessible insert interfaces to hex or square nut pockets, subject to actual stocked dimensions. For known nominal M3 hex hardware (5.5 mm AF, 2.4 mm thickness), start with 5.8 mm AF / 2.7 mm depth and a 0.2 mm entry chamfer. These are CAD fit assumptions; confirm the stock nut and print. Orient a horizontal nut cavity with a vertex at its crown, or apply a bridge roof; do not create a new unsupported flat ceiling while replacing an insert. Nut installation access must remain real after assembly.

## Counterbore implementation detail

Use the sequential bridge relief described in Rahix, Design for 3D-Printing, rule R3.5: https://blog.rahix.de/design-for-3d-printing/#the-overhanging-counterbore-trick . This makes two orthogonal bridge stages before the smaller circular hole begins. The alternative single sacrificial membrane requires cutting/drilling and is less desirable for this revision.

At the existing counterbore floor h, preserve the actual screw-head bearing plane and full recess depth. In print coordinates cut a slot of small-hole width through the first 0.2 mm of the ceiling; its length must cross the whole large recess and its chord edges. Cut a small-hole-width square through the next 0.2 mm. Leave the normal circular small hole above. For P01 this means 3.4 mm width; P13's final width depends on the revised retained-nut passage. The slot is a relief cut into the old roof, not a shelf added inside the head cavity. Adding shelves below the old floor would shorten the counterbore and alter screw seating/engagement.

At the default 0.2 mm layers, inspect the actual transition slices. Offsets such as the original P01 h=4.5 mm do not land on even 0.2 mm heights; exact layer sampling can affect which stage is seen. Both stages must survive as distinct sliced layers. If required, adjust the local relief heights or explicitly align the floor/part orientation to the actual slicing grid, checking the screw stack after any floor shift. Do not silently change the user's process profile.

## Features that are not inverted counterbores

- P08 cam screw pockets face upward in their supplied X-min-down orientation. Their cavity widens upward; no counterbore fix or reprint is justified merely by the reported general issue.
- P05 upper-half screw pockets widen upward in its split-face-down orientation. Keep that orientation after any redesign. Lower-half 4 mm blind insert closures and both halves' alignment-key pockets are complete bridges; replacing the inserts with accessible nuts changes these details and requires new layer checks.
- P02's 8.3 mm blind captive pivot seat closes at print height 2 mm. It is a full bridge (53.92 mm²), not an annulus. Keep it if the physical print was acceptable; inspect the new plate's corresponding bridge after recessing.
- P18's lower groove closes at print height 2.8 mm. The 100.27 mm² downward-facing area is a long **4.2 mm-wide** bridge. Its area or long toolpath length is not the unsupported span. Retain the disc if coupling engagement can be corrected by mount/clamp position.
- P10 grip head-pocket crowns already use 45° roof cuts for upright printing. P11 axle/pivot bores already have roof relief and inner-race pad ramps. Reuse these successful printed parts unless a specific changed interface requires replacement.
- P07 has 4 mm blind insert closures facing down in X-max-down orientation. These are complete bridges. Replacing cam-fastener inserts with nut pockets is possible only after checking the fan's remaining ligament, screw reach and nut insertion path; do not enlarge pockets blindly near the cam relief.

## Minimum-reprint strategy

Recessing the mechanism should change its mounting plates, not force every translated solid to be reprinted. Compare final local part geometry against v6 under rigid translation/rotation: world coordinates, body names and STL hashes alone are not sufficient to decide reprint status.

Expect P01 and P02 for the lower pivot/mount layout; P13 for its retained bottom reaction nut and improved roof; P05 or P04 for assembly access; P16 and/or P19 for measured sensor engagement. Additional parts should enter the required list only when their geometry/interface actually changes, including deliberate nut conversion. Reuse unchanged P18, cams, grips, follower, cup, guide sleeves and spacers where the final mechanical audit permits. Separate optional nut-conversion replacements from mandatory fit repairs if already-installed inserts work satisfactorily.

## Final review gate

Before releasing reprints: export final geometry, verify expected solid count and manifold meshes, check deliberate bed contact, slice with unchanged selected profiles, and inspect the actual counterbore bridge-stage layers and new nut-pocket roofs. Verify physical assembly order over each shaft end, P18/P19 engagement at carriage limits, retained-nut access and clamp load paths. List which existing v6 parts and hardware remain reusable. Do not claim physical insert retention, bridge finish or strength from digital checks.


## Agreed implementation direction after discussion

The primary implementer selected a radial two-piece P04 bush to reuse the existing shaft. Splitting on Y=0 through its axis permits radial assembly. Print both halves with the original X-max flange face down, not the split face down; see the corrected orientation assessment below. Preserve its 20.1 mm body OD, 12.3 mm running bore and 25.5 mm flange OD. Check the assembled halves remain captured between shaft and plate, and that a seam cannot open or migrate into a loaded surface. No fit claim beyond the nominal geometry is implied.

Required replacements are expected for P01/P02 recessing, split P04, P13 reaction nut and P19 sensor/nut repair, with P16 subject to actual coupling stack. P02/P13/P19 should use accessible nuts while already being replaced. P05/P07/P09 insert corrections or nut conversions can be optional if the user's existing installed inserts are secure. This applies the preference to new/revised parts without needlessly discarding working parts. The retained insert candidate remains 3.8 mm bore with a 0.2 mm entrance chamfer, explicitly a print-fit trial based on the user's inadequate melt-engagement feedback.


## Source review of implementation scripts 01–04

The retained-insert mouths in script03 are correctly located relative to v6: P05 end at X=-37.35; P05 joining inserts at split Y=0; P07 cam inserts at X=7; P09 inserts open at the socket wall X=-7.2. Continuing the P07 radial bore through the added seat to Y=22.5 before applying its chamfer is necessary and correctly targeted.

One new FDM concern was identified in script02: the P13 guide nut slots close at Z=40.8 onto a circular 3.4 mm guide passage when printed Z-max down. This creates another inverted nut-pocket transition. Apply corresponding sequential relief at Z=40.8..40.4 or demonstrate anchored surrounding paths in the final slices. The bottom preload nut opens upward in the chosen print orientation and does not create this closure. P19's nut installation slot closes as a complete approximately 2.6 mm-wide bridge in X-max-down printing; inspect it but it does not need the annular treatment.


## Revised source03: captive-nut upgrade

The final source03 replaces P05 and P07 inserts with accessible nuts; P09 alone retains 3.8 mm heat-set bores and the small mouth chamfers. Earlier recommendations for P05/P07 insert bores are superseded. Optional replacement labels should distinguish this nut-conversion upgrade from mandatory fit repairs when the existing parts' inserts are secure.

The lower shaft's nut-pocket bridge stages progress correctly away from its split bed face, Y=-4.5 to -4.9. The rear-loaded cam nut cavities widen upward in P07's X-max-down orientation, so they introduce no inverted counterbore closure. The rotor clamp loading slot stays open at its back face. The new P13 guide stages address the prior review finding, and its rear extension removes the thin wall beside rear block nuts. Final layer inspection must still cover the transverse shaft-cap nut cavity, new guide roofs and the outer guide-nut wall; source geometry alone does not establish successful toolpaths.


## Correction: P04 print orientation

The earlier split-face-down suggestion overlooked the semicircular running-bore roof. That orientation rests on two strips and grows an unsupported arch over the journal bore, risking sag on its functional surface. This is explicitly superseded.

**Print both P04 halves X-max flange face down.** Each has a broad semi-annular flange footprint (25.5 mm OD / 12.3 mm ID), and its 20.1 mm OD body grows upward from that flange. The running bore is vertical and the split side remains open, eliminating the horizontal arch and improving bore surface quality. Use rigid rotations, never a mirror, and confirm positive bed contact and winding after export. Radial assembly around the existing shoulder remains the mechanical solution.


## Final exported geometry and layer review

Reviewed the final v7 export manifest, mesh report, ten reprint files, slice diagnostics and critical layer previews. SHA-256 values match all ten delivered reprint files; every listed file is watertight and a single shell. All ten diagnostic slices returned exit code zero with zero generated support segments. These results support an **oriented geometry release**, not certified printer-ready toolpaths.

The P01 two-stage counterbore relief survives slicing as separate anchored bridge stages at 4.8 and 5.0 mm. P13's preload roof stages survive at 4.2/4.4 mm, and guide-pocket stages at 18.4/18.6 mm. The outer guide wall remains represented by continuous perimeter paths in the reviewed layers. Both P04 halves print from broad semi-annular flange footprints, contain 66 extrusion layers and require no bridge segments. P19's new pocket closure is a short complete bridge in its chosen orientation. P07's widening nut cavities and P09's retained insert interfaces have no obvious disconnected slice islands in the inspected critical regions.

The optional P05 lower shaft produces `ZFiller: encounter idx from clip: 28`, logged as an **error**, not a warning. A focused review (fdm-review-shaft/critical-1.png) shows its nut-roof stages at 4.8/5.0 mm and shaft-cap cavity closure around 3.6 mm, with no obvious omitted perimeter or roof. All 50 consecutive 0.2 mm layers are present from 0.2 to 10.0 mm. This does not prove that every clipping/infill operation succeeded; the diagnostic remains unresolved. No particular CAD defect is established by this message alone, so further geometry changes are not justified solely to silence it. Re-slice this optional geometry in the GUI and inspect its preview before printing; reuse the original shaft when its existing inserts remain secure. A repeat diagnostic with the same bed face rotated in-plane could distinguish a numerical clipping sensitivity without altering the functional part.

All diagnostic toolpaths also retain the known CLI machine/configuration errors (`nozzle_volume_type` and invalid T65535), and therefore must remain excluded from printer-ready delivery. Long reported bridge toolpaths include bridges over sparse infill and are not unsupported-span measurements. Printed bridge finish, nut insertion/retention, insert melt engagement and material strength still need physical checks. Final evidence is summarized in FDM-FINAL-CHECK.json.


### Primary implementer follow-up: bed-plane rotation

Following the reviewer's suggested diagnostic, the optional lower shaft was rotated 45 degrees within the bed plane, retaining the same split face on the bed and unchanged functional geometry. Its repeated default-profile slice exited zero with no ZFiller or floating-feature message. The original diagnostic is retained in initial-slice-report.json; slice-report.json and the release hashes describe the final rotated file. All layer and mesh checks were regenerated for delivery. The machine-configuration/invalid-tool CLI errors remain, so no G-code is supplied.
