# Integrated controller prototype — print and assembly guide

This guide follows `integrated_controller.fs` at SHA-256 `8E0F76D93B1EF02D5618B50AD2BF37C296640A0BEEAB5AC801CBEB40222B2606`. It describes a fit-and-function prototype, not a production-qualified controller. This revision models 2020 T-slot rails as assembly references and uses two printed frame plates. Its plate/rail arrangement needs a 64.5 mm axial span and differs from the earlier assembly geometry; measure the actual frame and confirm the rail fit before printing or assembly. The real extrusion rails are not in any print group.

The CAD is an assembled **Part Studio**, not a native Onshape Assembly with mates. The real potentiometer body is not included: its 6 mm shaft is reference geometry, and the device remains in the original controller. Shaft engagement, device mounting, electrical calibration, usable travel, spring rate, and printed fits remain unvalidated on hardware.

## Print groups and orientations

Set `printLayout` to true and export each `PrintGroup` separately. These layouts contain printable solids only; buy the hardware in the BOM separately. Preserve the supplied orientations and Z=0 placement when importing. Translation-only arrangement is fine. The frame group contains two original printed frame plates and the original potentiometer gear. The model shows the 2020 rails only as references; source real rails and matching T-nuts separately.

| Group | Printed solids | Intended orientation |
|---|---|---|
| `MOVING` — 13 parts | One-piece lever/main-gear with integral gear stem; two palm-grip halves; cam sector; shaft carrier; D-shaft; fork; roller; one 13 mm drive spacer; two bushings; two retaining caps | Shaft is laid on its side with its D-flat down. Fork prints on its long flat side. Lever/gear, cam, carrier, bushings, caps, and spacer sit on flat faces. Grip halves print on their split faces. Check removable supports under the cam's boss-relief roofs and at fork bore/head-seat overhangs. |
| `SUPPORT` — 6 parts | Lower follower plate, upper follower plate, spring block, spring cup, preload limiter collar, stop arch | Plates and stop arch print flat on broad faces. Spring block is turned onto a side; spring cup is turned onto its broad face with the guide peg upward. The 13 mm collar prints upright on its annular end face as laid out. The supported annular stop arch replaces the former long cantilever beam. |
| `FRAME` — 3 parts | Two original printed frame plates and original 24T potentiometer gear | The plates are printable replacements for the original plates. Real 2020 extrusion rails are excluded; buy/source them separately. The potentiometer gear remains the original part. The modified 48T gear is integral with the printed lever in `MOVING`. |

There are 22 printable solids across the three groups (13 moving, 6 support, 3 frame). The source models the lower and upper plate levels at z=20–26 mm and z=46–52 mm. Confirm the 64.5 mm axial frame span, plate positions, and five M5 T-slot fastener locations against the actual extrusion; the imported frame geometry is not a measurement of the user's hardware.

## Fit and mechanism notes

- **Shaft and gear:** the printed shaft has a nominal 12 mm D section, 5 mm flat, and 9.2 mm end journals. Print with the flat down. The modified 48T gear bore is nominally 12.4 mm with a 5.2 mm flat. Its integral handle stem is keyed to the shaft and carries the two-piece grip. Three M3×10 screws connect the gear to the shaft carrier; two M3×8 screws retain the shaft end caps. There is no radial handle set screw in this revision.
- **Bushings:** two printed bushings are Ø15.9 × 6.5 mm with Ø9.6 mm bores and replace the modeled 625 bearing positions. They run on the Ø9.2 journals in nominal Ø16.1 frame seats. Axial retention uses the frame seat shoulders and the surrounding stack, with nominal 1 mm gear clearance and 0.5 mm spacer clearance; there is no flange on the bushing. Check running clearance, axial capture, and wear on the real frame before relying on them.
- **Stack spacer:** one Ø16 mm spacer with a Ø12.6 mm bore is 13 mm long. The bushing, gear, and spacer faces must remain clear and coaxial; do not assume the earlier two-spacer stack applies to this revision.
- **Cam:** the replaceable cam is 8 mm thick. Three M3×5.7 inserts and M3×8 screws secure it to the carrier; a separate 3×6 mm steel dowel indexes it. Remove supports from the reliefs without nicking the roller track.
- **Follower:** the fork runs on a 7 mm OD × 5.2 mm ID × 20 mm metal pivot sleeve. The Ø10 × 9.5 mm roller spins on a 4 mm OD × 3.2 mm ID × 11 mm metal spacer tube and the M3×20 axle. Retain the roller with the washer and nut while leaving it free to turn.
- **Stops and spring:** the 6 mm-thick annular stop arch bolts to the rails. The lever lug contacts the printed arch posts; the two M3×10 steel bolts reinforce those posts and are not the intended contact faces. The spring cup has a printed 13 mm M4 preload-limiter collar; it limits screw advance to about 1 mm beyond nominal preload. Adjustment increases preload from nominal by up to 1 mm. Backing off does not reduce spring preload: the cup rests against the bracket at nominal. Use a softer spring to reduce force. The current candidate starting specification is an 8 mm OD spring, ID ≥5 mm, 18 mm free length, 10–12 N/mm rate, and solid height ≤11.5 mm. At the nominal 14 mm installed length, that implies roughly 40–48 N; at maximum cam lift the length falls to about 13.25 mm, or about 12.25 mm with the full 1 mm extra adjuster advance. This is a geometry/rate estimate, not a selected or bench-verified spring.
- **Travel:** the CAD motion input is ±65°. With the 48:24 gear pair the potentiometer turns about twice the handle angle in the opposite direction, or 260° total across that range. Confirm the actual potentiometer's safe electrical/mechanical travel and keep stop loads out of its shaft.

Use light hand loads for first fit checks. Inspect the shaft flat and journals, integral gear stem, grip roots, carrier bosses, plate inserts, stop arch, and printed bushings for cracks, flex, binding, and wear. A simple quasi-static estimate for the seven-gate profile at 1.5 mm lift and 135 mm hand radius gives about 2.2–2.6 N peak hand force at 40–48 N spring load (approximately 20–24 N at the roller); spring compression can raise that to around 3 N. The three-gate profile is weaker with the same spring. These estimates omit friction, impact, compliance, and linkage variation. They do not establish authentic train-controller feel; tune by bench testing and user evaluation. PLA is suitable for an initial fit prototype; PETG is a later option, but recheck dimensions, stiffness, and support release. Neither material choice is validated by the CAD.

## Hardware bill of materials

Screw bodies in the FeatureScript are simplified envelopes. Button-head lengths below are nominal under-head lengths; verify the actual head, thread, washer stack, and tip clearance at assembly. Do not print the modeled hardware solids.

| Qty. | Hardware | Use |
|---:|---|---|
| 14 | CNC Kitchen standard M3×5.7 mm heat-set inserts | 3 carrier, 3 main-gear drive, 2 shaft ends, 4 spring block, 2 lower grip. Pockets are modeled Ø4 mm with a 6.8 mm cutter span; verify insert entry direction and seat each insert flush. The slight cutter overrun is not extra effective insert depth. [Manufacturer's M3×5.7 drawing](https://cnckitchen.store/products/heat-set-insert-m3-x-5-7-100-pieces). |
| 3 | M3×8 button-head screws | Cam sector to carrier. |
| 3 | M3×10 button-head screws | Main gear to carrier. |
| 2 | M3×8 button-head screws | Shaft end retaining caps. |
| 2 | M3×25 button-head screws | Join the two grip halves around the keyed gear stem; thread into inserts in the lower grip half. |
| 2 | M3×20 button-head screws and 2 M3 nuts | Spring-cup guide screws and retention. |
| 2 | M3×10 steel bolts, 2 M3 nuts, 2 M3 washers | Reinforce the printed stop posts. The printed posts, not the bolt ends, contact the lever lug. |
| 2 | M3×12 button-head screws with washers | Lower spring-block attachment. |
| 2 | M3×10 button-head screws with washers | Upper spring-block attachment. |
| 5 | M5×20 screws, 5 matching 2020 T-nuts, 5 M5 washers | Attach support plates and stop arch to the modeled T-slot rails. Confirm the actual slot/nut system. |
| 1 | M5×30 button-head pivot screw and 1 M5 nut | Follower pivot through the lower plate and sleeve into the upper captured nut. |
| 1 | M3×20 button-head roller axle, 1 M3 nut, 1 M3 washer | Roller axle retention. |
| 1 each | 7 OD × 5.2 ID × 20 mm tube; 4 OD × 3.2 ID × 11 mm tube | Metal pivot sleeve and roller spacer tube, respectively. |
| 1 | M4×20 adjuster screw and 1 M4 hex nut | Spring preload adjuster. Screw/head geometry is simplified; check the actual nut pocket and tool access. |
| 1 | 3×6 mm steel dowel | Cam index pin; fit or ream its socket to the pin. |
| 1 | Compression spring, Ø8 mm OD, ID ≥5 mm | Choose rate and working length by bench test. |

Modeled washers total 12: five M5 rail washers, four M3 spring-block washers, two M3 stop washers, and one M3 roller washer. Hardware counts above follow the source models; source screw solids are not a substitute for checking real engagement lengths.

## Assembly and print order

1. **Measure and fit the frame first.** Confirm the 2020 rail profile, 64.5 mm axial span, plate positions, T-nut access, potentiometer mount, gear centers, and original frame seats. This design's rail/plate layout differs from the prior assembly. Reuse compatible original plates or print the two plate solids from `FRAME` as replacements. The 2020 extrusion rails are not printed; obtain them and matching T-nuts separately. The third `FRAME` solid is the original potentiometer gear.
2. **Print support parts and verify mounting.** Print `SUPPORT`, install the four spring-block inserts and support plate screws, and loosely attach the plates/arch to the rails with the five M5 fasteners. Check clearances and plate spacing before adding the shaft stack.
3. **Print frame/gear parts as needed.** `FRAME` contains two original printed frame plates and the original 24T gear. Reuse existing compatible plates and potentiometer gear where possible. The modified 48T main gear is printed with the `MOVING` lever; the real 2020 rails are supplied separately.
4. **Print moving parts.** Install the 14 M3 inserts, checking each location against the BOM. Fit both bushings into their seats; confirm their shoulder/stack retention and journal rotation. Assemble shaft, gear/handle, carrier, cam, dowel, drive spacer, retaining caps, and grip halves with the corresponding screws.
5. **Assemble the follower and spring.** Install the sleeved pivot and captured M5 nut, then the fork, roller tube, roller, axle, washer, and nut. Fit the spring cup to its two guide bolts, install the limiter collar, and set the M4 adjuster at nominal preload. Install the M4 nut from the spring side before fitting the cup. A 2.7 mm front wall retains the nut against spring load. The collar permits about 1 mm additional advance; backing off below nominal does not reduce preload. Check that the real spring does not approach solid height through the operating range.
6. **Check by hand before connecting the potentiometer electrically.** Move slowly through ±65°. Verify gear mesh, free roller rotation/contact, detent seating, stop contact, no plate/handle/frame collisions, and no bushing or cam axial binding. Confirm the actual potentiometer's safe travel and calibration separately.

## Slicing and validation status

Use a 0.4 mm nozzle and start with PLA at 0.20 mm layers, five wall loops, five top/bottom layers, and 35% gyroid infill. Enable removable supports only where preview shows necessary—especially the carrier stop-lug overhang, cam underside relief roofs, fork bore/head-seat regions, shaft journals, grip cavities, and the turned spring block/cup. Inspect contact and removal before printing. Use a brim if the slicer preview shows marginal bed contact, especially for the long shaft or lever.

The latest recorded CAD checks are 84 solids with zero modeled pairwise intersections, 53 sampled motion poses per 3-, 5-, and 7-gate cam profile at maximum lift, and a 41-pose cam-removal path with zero reported clashes. The checked source microversions are recorded in `integrated-validation.json`; re-run validation after source edits. These are discrete Part Studio checks, not a mated native Assembly or proof of continuous clearance, actual-frame fit, spring force, strength, durability, or print success. Recheck exported meshes and slicer previews after any geometry change, then test fit and motion on the physical frame before connecting or loading the potentiometer.

## Grip dimensions and finish

The rounded, tapered grip is approximately 40 mm in maximum diameter and 60 mm long, with its crown 160 mm from the lever pivot. It is inspired by the palm-grip proportions of railway master controllers, including the manufacturer's [Gessmann TBC01 drawing](https://www.riacontrol.cz/wp-content/uploads/2019/11/Hlavni-obsluzna-jednotka-U1-technicky-list.pdf); it is not a replica of a particular locomotive. The two halves locate on the integral gear stem. Sand the split seam and support contact marks smooth before assessing hand comfort. Printed texture, spring selection and bearing friction determine the actual feel and need a physical prototype.

## Current export checks

The current exports are in `reviewed-print/`: 13 moving, 6 support and 3 frame/gear solids. All 22 exported meshes have one connected component, no nonmanifold edges or inconsistent winding, positive volume, Z=0 placement and bounds within 256 mm. All 22 generated slicer output using the installed Bambu Studio P2S 0.4 mm PLA profiles. The CLI emitted preset/tool diagnostics, so the distribution contains geometry, not ready-to-run G-code. Re-slice using your installed P2S profile and inspect supports in Preview. Detailed records are `reviewed-print/mesh-check.json` and `reviewed-print/slice-report.json`.

Final review corrections: spring-side M4 nut entry with a 2.7 mm retaining wall, and supports enabled for M07 carrier's rounded stop lug. The updated source passed neutral body-intersection, 41-pose removal, 53-pose seven-gate maximum-lift motion, and +1 mm preload checks; see final-retention-validation.json. Other notch profiles retain their earlier unchanged-profile checks.

Final mechanical review notes: gate centers are 0° and ±43.333° for three gates; 0°, ±26° and ±52° for five; and 0°, ±18.571°, ±37.143° and ±55.714° for seven. The ±65° hard stops are beyond the outer gates: releasing there returns the lever toward the outer gate. Original frame-plate-to-2020 fasteners are reused and additional to the five new M5 rail attachments in the BOM. The nominal rotating stack permits about 1.5 mm axial float (−1/+0.5 mm); check clunk and roller overlap and fit thin shims if needed, retaining free rotation.