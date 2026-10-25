# Fusion train controller — assembly and prototype guide



This is a new Fusion design around the original, unchanged 640 × 190 × 110 mm 2020 frame. Printed parts are named P01–P26, with three P08 cam alternatives and two P18 coupling-disc fits (29 print files total; print one of each alternative). The frame, spring, potentiometer and fasteners are reference/hardware, not print files. Native features are editable; the dimensioned Python build scripts are the authoritative regeneration source. Reference user parameters do not drive every feature.



## What changed and why



The lever and cam carrier are one printed rotor. A separate printed D-shaft turns in two replaceable flanged bushes. The hand load goes into both rail-mounted plates, not through the RK097 shaft. A floating Oldham coupling drives the sensor directly; this uses about 100 degrees of electrical travel and needs endpoint calibration in the controller firmware. It eliminates the gear mesh, but printed coupling clearances can still produce reversal play. The rotor has a radial M3 clamp onto the shaft flat. The default Oldham grooves are 4.2 mm for 4 mm tongues; an optional 4.1 mm disc is provided. Choose the closest fit that slides freely after cleanup, never a binding fit. Measure sensor readings when approaching every gate from both directions before final calibration. The replaceable, sliding sensor carriage accommodates changes to the unverified AliExpress RK097 body/shaft.



The cam is an 8 mm thick removable sector with three M3 screws. Select 3, 5 or 7 gates; do not fit more than one cam. Stable gates run from -50 to +50 degrees, with separate structural hard stops at +/-52 degrees. A forked follower runs on a metal sleeve, with a replaceable printed roller. The preload screw bears on a guided cup and reacts through a retained M4 nut. Its collar limits further compression. The grip is about 40 mm wide and 60 mm long, 160 mm pivot-to-crown, inspired by locomotive palm grips rather than an exact replica.



## Print sequence



Use the oriented STL files as supplied: do not auto-orient them. Each is an individual job or may be arranged with other parts while retaining orientation. All units are mm. Start with PLA for dimensional prototypes, 0.4 mm nozzle, 0.20 mm layers, 5 walls, 5 top/bottom layers and 35% gyroid. Use 6 walls for the shaft, lever, follower and stops. PETG is an option after fit/feel testing; re-check tolerances after changing material. Remove support contact carefully from bearing and coupling surfaces.



1. Print P03/P04 bushes, P05 shaft, P06 cap, P23/P24 thrust spacers and P25/P26 centering inserts. Use a small brim for the two 5 mm-diameter centering inserts and clean their bores carefully. Verify sliding fit before investing in the larger parts. The 12 mm journal has a nominal 12.3 mm bore; the D-socket has 0.2 mm diametral clearance. Do not force a tight shaft into the bushes.

2. Print P01/P02 plates and P13 reaction block. Use local supports for horizontal bores/counterbores. The plate's broad flat face is on the bed; protruding brackets grow upward. No whole assembled base is printed.

3. Print P07 rotor and one P08 cam (start with 5 gates). Rotor broad face down, stop lug upward; cam screw counterbores upward. P23/P24 are separate so a large unsupported hub is not under the lever.

4. Print P11/P12 follower/roller, P14 cup, P15 collar, P21/P22 pivot spacers. Support follower horizontal bores; remove supports without enlarging the bearing seats.

5. Print P16 sensor carriage and P17–P20 coupling. P17 needs supports below the flange overhang; support the small clamp semicircular bores if the slicer requests it. Keep the Oldham grooves free of support residue.

6. Print P09/P10 grip halves on their split faces, with supports in the stem socket. Deburr/sand grip seam and exterior edges. Print remaining cam alternatives after confirming the preferred spring force.



The printed shaft lies horizontally on its D-flat, with supports under raised round journals and the sensor stub. Do not print it standing on an end. The reaction block and spring cup print top face down, leaving nut loading recess and centering pilot accessible upward.



## Hardware



Use button-head screw envelopes unless noted; larger socket heads may not fit counterbores.



| Item | Quantity | Purpose |
|---|---:|---|
| CNC Kitchen M3 x 5.7 mm heat-set insert | 16 | Shaft 1, rotor 4, grip 2, crossblock 4, input clamp 1, output clamp 2, carriage rails 2 |
| M3 x 8 | 1 | Shaft retaining cap |
| M3 x 10 | 3 | Selected cam |
| M3 x 12 | 2 | Sensor carriage |
| M3 x 16 | 4 | Coupling clamps 3, rotor clamp 1 |
| M3 x 20 | 5 | Crossblock 4, roller axle 1 |
| M3 x 25 | 4 | Grip 2, stop reinforcement 2 |
| M3 x 35 | 2 | Spring cup guides |
| M3 x 80 | 1 | Follower pivot through the retained metal sleeve |
| M3 plain nuts | 3 | Roller axle and cup guides |
| M3 locknuts, nominal AF5.5 x 4 mm high | 3 | Stops 2, follower pivot 1 |
| M3 washers, OD7 / ID3.4 x 0.5 mm | 12 | Coupling 3, carriage 2, guides 2, rotor 1, stops 2, pivot 2 |
| M4 x 25 socket-head screw, head OD7 | 1 | Preload adjuster |
| M4 nut, nominal AF7 x 3.2 mm high | 1 | Retained preload reaction nut |
| M5 x 16 button-head screws | 4 | Accessible top-slot rail mounts |
| M5 metal spacer, OD10 / ID5.4 x 3 mm | 4 | A metal washer stack totaling 3 mm per bolt can substitute |
| Matching M5 roll-in/drop-in 2020 T-nuts | 4 | Top rail slots; use the user's compatible T-nuts |
| Metal sleeve OD8 / ID5.2 x 48 mm | 1 | Structural follower pivot sleeve; retain with M3 bolt and printed P25/P26 centering inserts |
| Metal sleeve OD4 / ID3.2 x 10 mm | 1 | Roller axle sleeve |
| Metal sleeve OD4 / ID3.2 x 6 mm | 2 | Cup guide sleeves |
| RK097 with supplied nut/washer | 1 | Unverified AliExpress variant; replaceable mount and clamp |
| Compression spring | 1 | See spring selection below |

Insert bores are nominal 4 mm and sized for the requested standard 5.7 mm insert length. Confirm fit on scrap using the insert manufacturer's instructions and your filament before installing all 16. Keep heat and axial load controlled, particularly on the printed shaft.



## Assembly order



1. Install inserts before mating parts. Insert the M4 nut into the underside of P13 and the two M3 locknuts into the recessed P01 stop pockets; install M3 x 25 stop bolts with 0.5 mm washers. Do not rely on plastic threads.

2. Seat printed bushes P03/P04 in printed plates P01/P02. Slide printed spacer P23 onto printed shaft P05, then printed rotor P07 and spacer P24; assemble through the bushes and fit printed retaining cap P06. Nominal rotor end float is 0.3 mm total. Verify free rotation without perceptible wobble. Do not tighten the cap to remove designed clearance. Snug the radial rotor screw against the shaft D-flat; use a flat-ended screw and do not crush the printed shaft. Its purpose is transmitting low sensor torque without rattling through socket clearance.

3. Fit printed P25/P26 centering inserts flush into the ends of the retained 48 mm METAL pivot sleeve. Install the follower between printed P21/P22 spacers on that sleeve. Use an M3 x 80 pivot bolt with a 0.5 mm washer at each plate and an M3 locknut. P25/P26 center the smaller bolt; they do not replace the structural metal sleeve. Install roller on its 10 mm sleeve and M3 axle. The bolts clamp sleeves, leaving the fork/roller free to rotate.

4. Install P13 using four M3 × 20 bolts. Assemble cup with its two 6 mm guide tubes, M3 x 35 bolts, washers and nuts. It must slide without binding. Add spring, collar and preload screw. Begin with low spring load.

5. Attach one cam with three M3 × 10 screws. For replacement, remove its screws, back off/remove the M4 adjuster and hold the follower about 5 degrees down (roughly 3 mm at the roller) with a suitable temporary holding tool, then slide the cam 40 mm sideways through the right-side opening. The outer cheek otherwise catches the cam. Removing the adjuster does NOT unload the spring: its cup can only rise about 1 mm. The calculated holding force is roughly 27 N with the candidate spring. For unloaded servicing instead, restrain the cup, release the guide hardware carefully and remove the spring before moving the cam. Do not let the spring eject.

6. Attach grip halves around the keyed stem using two M3 × 25 screws. Seat the revised P01/P02 flanges on top of the upper rails. Tighten four M5 x 16 screws from above, each with a 3 mm TOTAL metal spacer/washer stack, into compatible M5 T-nuts in the top slots. Use roll-in/drop-in T-nuts when rail ends are blocked. The rail top is Z55, head seat Z66 and screw tip Z50; the actual extrusion web is Z48.8, giving 1.2 mm nominal tip clearance. Do not add washers beyond the specified total. Verify actual T-nut engagement (at least 3 mm full threads or the supplier requirement) and no bottoming.
7. Set the lever and potentiometer to their midpoint. Assemble input hub, floating disc and output clamp; tighten shaft clamps before sliding the sensor carriage into place for tool access. Adjust carriage axially so coupling tongues engage without bottoming. The model uses a 12 mm exposed shaft starting at X64; the replaceable mount/clamp must be changed if your part differs.

8. Test the full lever travel slowly without power. Structural stops must engage before the potentiometer's own stop. Then calibrate electrical endpoints in firmware and test every gate. Recheck screws and insert seating after the first operating session.



## Spring and feel



Nominal spring space is 17 mm; follower motion and the permitted extra preload reduce it to about 15.2 mm. With the adjuster backed off and follower depressed 5 degrees for servicing, the spring space is about 16.3 mm. The preload-limit collar is 2 mm tall in the final design. Select a spring with solid height below 14 mm, OD at most 8 mm, ID clearing the 4 mm pilot, and suitable free length. A 21 mm free length and about 10 N/mm rate is a calculation candidate, not a validated purchased spring. It would produce roughly 40 N spring force at nominal position; the 20:35 arm ratio reduces roller force. Start softer and tune by hand. The adjuster allows about 1 mm either side of nominal; do not defeat the compression-limiting collar. The 3-gate profile has shallower slopes than the 7-gate profile, so identical springs do not give identical peak hand force.



## Scope of proof



Solid, mesh, fit-envelope, sampled motion and slicing checks are documented separately. They do not establish fatigue life, real filament strength, comfortable detent force or fit of an unmeasured AliExpress sensor. The full-size printed prototype is the next validation step. No claim is made that this reproduces the force curve of a particular locomotive.



## Fusion inspection



The native file includes three revolute joints (lever, follower and free roller) and rigid groups. The main lever has +/-52 degree limits. The follower includes service travel down to -6 degrees. These are inspection joints: they do not automatically solve cam contact, spring deformation or Oldham misalignment. The 7-gate cam is visible by default; alternative cams and the tight coupling disc are hidden. Do not enable overlapping alternatives together.



Slicer validation used normal supports on the listed supported parts. The supplied deliverable contains geometry, not printer G-code: re-slice in Bambu Studio using your installed P2S profile and inspect support access. CLI validation generated layers for all meshes but reported vendor preset metadata/tool-command warnings, so its printer files are not released.



The final crossblock uses mounting rows Y=-70/-62 mm at Z=53.5 mm. Its rear edge stops at Y=-74 mm, 1 mm inside the existing rail face. This separates the four mounting inserts from both the cam relief and the vertical cup guides. The narrowest nominal installed-insert outer wall is 1.7 mm (assuming 4.6 mm insert OD). The guide bores remain at X5/19, Y=-55.


## Mount-access revision

P01 and P02 now use accessible vertical mounting screws into the TOP rail slots. The old side-entry rail screws and buried pockets are obsolete. Both plates retain their broad-face print orientations and are190 mm across the new mounting flanges. Stop cores and follower pivot use M3 locknuts; the preload adjuster still needs its separate M4 nut. Confirm your actual M3 locknuts fit the4 mm-high modeled envelope.
