CAM DETENT PROTOTYPE — 24 October 2026

UPDATE: FDM changes have now been applied to the shared feature. See FDM-PRINT-GUIDE.txt, fdm-stl/ and Cam-Detent-FDM-P2S-layout.3mf for the current geometry, print orientations and hardware changes. The design-history notes below describe the earlier prototype where they differ. cam_detent.fs and cam_detent_fdm.fs both contain the current FDM source.

Onshape prototype:
https://cad.onshape.com/documents/b8296e54dd613316c44885e0/w/c3ae9023e20b2a467edaad8c/e/bbcf27a4742cd8b0e198ae72
Feature Studio:
https://cad.onshape.com/documents/b8296e54dd613316c44885e0/w/c3ae9023e20b2a467edaad8c/e/49901711a30f64ac872dc409
Local source: cam_detent.fs. The saved Onshape source was compared with this tested file and matched exactly.

STATUS
Working parametric engineering prototype in a dedicated Part Studio. Existing frame, gears, handle and assembly geometry were preserved. Eleven solids: two reference support plates and nine mechanism parts/envelopes. This is not a manufacturing release or a fully mated drivetrain assembly.

DESIGN
Permanent D-shaft hub carries a replaceable 8 mm thick cam sector, approximately 88 mm maximum effective diameter at 1 mm lift. Three M3 fixing holes with recessed head clearance, a concentric locating pilot, and an asymmetric indexing pin locate the sector. New forked arm supports a 10 mm diameter roller at a 36 mm pivot radius. Compression spring acts on an 18 mm tail through an M4 guide/thrust seat and captive-nut pocket. Independent hub-lug/bracket stops limit travel to +/-70 degrees.

Edit Cam Detent Mechanism 1 to select 3, 5 or 7 notches; change lever angle for analytical motion preview; change lift from 0.5 to 1.5 mm. Start with 1 mm. Three notches lie at -46.667, 0, +46.667 degrees; five at -56,-28,0,28,56; seven at -60,-40,-20,0,20,40,60. All layouts have a cam ridge at each +/-70-degree hard limit. The service preview is intended at zero lever angle.

MEASURED SOURCE INTERFACES
Coordinates are the Holder Frame Part Studio coordinates, not the transformed Full device assembly coordinates. Shaft axis is Z through (0,0). First plate occupies z0..10.5 mm, second z54..64.5 mm: 43.5 mm clear axial slab. Cam occupies z32..40; carrier z28..32; central hub z24..48; fork z27..45. Bracket reuses two lower-left flange holes, axes parallel Y at x=-85 mm, z=5.25 and 59.25 mm. Mounting block adds 7 mm to the screw grip length. Existing shaft source has a 5.2 mm D section; prototype bore is 5.5 mm with a 2.026 mm flat offset. Final angular orientation/fit must be verified against the assembled shaft.

VERIFICATION PERFORMED
Onshape test_feature generated the geometry without notices. Onshape evCollision sampled 29 poses, every 5 degrees over +/-70 degrees, for each 3/5/7-notch layout at 1 mm lift. No interference was returned between cam/carrier/arm/roller and the bracket/reference plates. Maximum reported cam-to-roller distance was zero. This is a sampled geometric check, not a continuous contact simulation or force test.
All body pairs at neutral were checked in the earlier geometry before the thrust-seat/nut-pocket additions: no volumetric interference was reported. Motion checks were repeated after those additions. Spring is a space envelope, not a modeled coil, and its tilted end contact is approximate.
The seven-notch sector removal path passed 41 sampled poses against every other modeled solid: at neutral, remove the three fixing screws, lift sector 13.5 mm along +Z, then translate diagonally toward +X/-Y. The modeled path reaches (100,-100,13.5) mm displacement. It clears the follower and leaves the hub/potentiometer calibration untouched. Tool access, loose screw handling, the surrounding extrusion frame, and external enclosures are not included in that check.
Independent numerical roller-offset check of seven-notch 20-degree/1 mm profile: maximum pressure angle ~11.30 degrees, minimum pitch-curve curvature radius ~11.38 mm vs 5 mm roller radius, no sampled self-intersections. For 20/30/40 N equivalent roller loading, approximate peak detent torque is 0.18/0.27/0.36 N m. Actual spring force is approximately twice roller loading because of the 18:36 mm arm ratio; these are sizing estimates, not measured feel.

PROTOTYPE HARDWARE / FOLLOW-UP
Three recessed M3 button-head screws: nominal 8 mm under-head length gives about 3 mm engagement through the 5 mm cam floor into the 4 mm carrier. Reassess thread strength/material, tolerance, and inserts before manufacture. Screws are removable, not captive in the current CAD.
M4 adjustment screw, thrust washer/seat, captive M4 nut and locking arrangement: schematic cylinder and seat are modeled; production threads, drive head and locknut/retention are not detailed.
10 mm OD x 10 mm roller: 3.2 mm bore on a 3 mm shoulder axle in this prototype. Select POM/appropriate bushing or redesign for a catalog bearing; add washers and positive axial retention. Pin/head/nut retention is not yet detailed.
5 mm follower pivot: select shoulder pin/bushings and retention; fit and assembly sequence need bench verification.
Spring envelope: 8 mm OD, 14 mm installed length at neutral; roughly 0.5 mm compression change at 1 mm roller lift. Select free length, wire, rate and preload to avoid coil bind at the largest lift, then verify force and fatigue. No catalog spring is selected. The adjuster has no parametric preload travel yet.
Two existing mounting screws need 7 mm additional grip length if retaining the modeled bracket mounting face; confirm extrusion engagement and head access.

REMAINING INTEGRATION CHECKS
Full device gear/handle/extrusion placements were inspected visually but not imported into the collision model. Do not infer that the complete drivetrain is collision-free. Main gear mate has a -1 mm offset and no enabled limits. Confirm its actual axial face datums, the central hub clearance, shaft length/flat orientation, handle sweep and rail clearance in the final assembly.
140 degrees of lever motion produces 280 degrees at the potentiometer with the existing 48:24 gear ratio. Confirm real potentiometer usable travel, reserve and electrical calibration before relying on the new stops. Keep end loads out of the potentiometer.
Provide fillets/ribs as required after load testing, verify stop/post strength, spring-seat articulation and fastener access, then produce drawings and print/export parts. The larger bracket is intentionally a rigid prototype envelope, not weight-optimized.
Bench test both directions: breakaway force, settling into valleys, overshoot, repeatability, hysteresis, wear and shock at stops. Select profile/lift/preload from measured behavior before making train-specific asymmetric gates.

PATENT / MECHANICAL PRECEDENTS
US2667247A Power and brake controller — shaft-mounted notched disc and spring-biased roller on pivoted lever; separate lock-out/stepping mechanisms. https://patents.google.com/patent/US2667247A/en
US2409762A Controller mechanism — notched star wheels with spring-biased roller detents for throttle/brake/reverser; distinct locking dog. https://patents.google.com/patent/US2409762A/en
US3842653A Reversing, throttle and brake controller with interlocks — spring detent rollers engage cam-plate recesses; separate rollers provide geometric interlocks. https://patents.google.com/patent/US3842653A/en
These sources support separating push-through tactile detents from positive interlocks. The proposed mechanism uses the former. No patent clearance analysis was performed.
