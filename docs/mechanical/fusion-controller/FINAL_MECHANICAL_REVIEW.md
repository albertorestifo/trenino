# Final mechanical expert review — Fusion controller

This review concerns the **new Fusion controller only**, under `docs/mechanical/fusion-controller`. It does not reuse an approval of the earlier Onshape design. Reviewed: DESIGN.md; ASSEMBLY-AND-PRINT-GUIDE.md; native build scripts01–14, with the hardware corrections in10 superseding the earlier placements; export manifest; neutral and sampled-motion evidence; print mesh/slicer reports; and fusion-overview.png. Native joint code was read as supporting context, not as a force or contact simulation.

## Findings to implement from this review

### 1. Remove the backlash-free claim and positively locate the rotor on the shaft

The direct drive removes the gear mesh, but the original Oldham arrangement had4.0mm tongues in4.4mm grooves. At8mm tongue half-length, a simple geometric estimate permits about2.9° peak-to-peak angular clearance per interface, potentially about5.7° combined. The D-socket can add reversal play. Actual spring/sensor torque and printed fits determine observed lost motion.

Agreed scoped changes: replace the default groove width with4.2mm; offer a4.1mm fit alternative; add an M3 screw that bears gently on the printed shaft D-flat so rotor-to-shaft motion cannot rattle through the clearance. Use a flat seating pad for the screw washer—an unmodified radius22 rotor only touches a washer plane at its tangent. The proposed pad X±5, Z60…70, Y20…22 and M3 insert/pilot is a reasonable starting arrangement. A standard screw nominally touching the flat still requires actual length and print-fit checking; use a flat tip and tighten only enough for the low sensor torque.

Verify the pad, screw and washer through the full lever sweep. Keep both Oldham interfaces freely sliding; do not eliminate clearance by force or by binding the floating disc. Update the guide to say that gear-mesh backlash is removed, not that the coupling is backlash-free. Test sensor readings when approaching each gate from both directions before firmware endpoint/gate calibration.

### 2. Treat rail screw engagement as an actual hardware fit check

The original M5×25 placement, from seatY±54 to tipY±79 against inner rail facesY±75, gives only4mm total penetration past the extrusion face. Some of that can be consumed by the slot lip or distance to the T-nut's first thread. It does not establish4mm of effective thread engagement.

Measure the actual selected T-nut, slot depth and washer stack. Choose the bolt length/seat depth to obtain at least roughly4mm effective M5 engagement as a practical prototype target, or the T-nut supplier's required engagement, without bottoming. A longer bolt must be checked against the real slot depth rather than substituted blindly. Keep the four rail mount screws and the two M5 stop-core screws separately identified if their final lengths differ.

### 3. Correct cam service procedure for the follower cheek

The neutral axial cam-removal path catches the outer follower cheek; the static arrangement and lever sweep do not prove service clearance. The agreed solution is to remove/back off the preload adjuster and depress the follower by approximately5° before sliding the cam out; increase the independent follower's available service motion accordingly and test that path against all stationary parts.

Removing the adjuster does **not** fully unload the spring. The cup can rise only about1mm to the crossblock underside. With the calculation-candidate21mm free length and10N/mm spring, it retains roughly30N preload at that limit. Depressing the follower5° adds about1.7mm compression at the short tail, requiring roughly27N holding force at the roller end. These are first-order estimates, not measured forces. The guide should describe a suitable temporary holding tool/fixture, or offer cup/guide removal first for an unloaded service operation; it must not claim the spring is unloaded merely because the adjuster was removed. Check spring solid-height margin in the service pose as well as in operating travel.

### 4. Implement the FDM specialist's crossblock insert relocation

The independently reported insert-wall breakthrough next to the radius51 cam relief is also mechanically significant: the guide's four crossblock fasteners cannot be credited as sound load paths if a heat-set pocket opens into that relief. Moving the mounting hole rows fromY−59/−51 toY−62/−54 atZ52, in the crossblock, plates and fastener locations together, is a reasonable correction. Refill old holes, preserve the cam relief, check insert outside-diameter containment and re-run targeted clearance/mesh/slice checks.

## Mechanical features that are coherent in the new architecture

- **Hand-load separation:** the integral lever/rotor and cam react through the two sideplates and rail mounts. The RK097 shaft is driven through the low-load floating coupling. End-stop loads close through the dedicated rotor lug, steel-cored left-side stops and structural plate, rather than through the potentiometer.
- **Main shaft and bushes:** the printed shaft has12mm journals, a16mm D working section, an integral right shoulder and an M3-retained left cap. The two flanged bushes provide deliberate retention. Nominal12.3mm bush bores give0.3mm diametral running clearance. Shoulder/cap faces provide approximately0.3mm shaft end float; P23/P24 provide approximately0.3mm rotor end float. Actual printing and insert installation still govern fit; do not tighten the cap to remove these clearances.
- **Follower bearing:** the OD8/ID5.2×48 metal sleeve spans the sideplates and carries pivot-bolt clamp compression. Printed axial spacers locate the fork around the sleeve with small deliberate gaps. This is a valid improvement over running directly on a threaded bolt.
- **Roller:** OD4/ID3.2×10 sleeve between fork cheeks bypasses the9.5mm roller during bolt tightening. The Ø4.3 roller bore is a prototype sliding fit. Verify rotation after installing the axle nut; nominal CAD clearance does not guarantee a free-running printed bearing.
- **Spring reaction and retention:** the M4 nut is loaded from the spring side into the lower pocket, leaving material above it to react the spring force. The screw presses the guided cup. The two metal guide tubes carry guide-bolt clamp compression instead of clamping the cup. The final4mm collar atZ57…61 allows approximately1mm extra screw advance from the nominal head seatZ62. The neutral cup-to-block gap permits approximately1mm of effective back-off—unlike the earlier Onshape arrangement.
- **Cam fixing and gate layout:** the three cam screws have about5mm nominal insert engagement. Stable gate positions include−50°,0°,50° for three gates, and appropriate intermediate gates for five/seven. Independent hard stops at±52° lie beyond the end gates. The extra travel must be included when verifying the real sensor's mechanical stop margin.
- **Grip:** the split palm grip has a positive rectangular stem socket and two insert fasteners. Check seam closure, rocking and actual screw length; do not crush the shells to remove fit error.
- **Replaceable sensor interfaces:** the slotted carriage, replaceable panel and split output clamp accommodate an unverified RK097 variant. The model's6mm shaft/M7 bushing assumption is explicitly not a measurement. Measure shaft diameter/profile, exposed length, threaded bushing, body and terminal clearance; center both lever and potentiometer before coupling them. Set axial spacing so both Oldham tongues engage without bottoming. Check cable strain relief and electrical endpoint calibration on the real assembly.

## Hardware and prototype qualifications

The main shaft cap, three cam screws, two grip screws, crossblock bolts, pivot and roller sleeves, and clamp insert placements have coherent nominal engagement/retention concepts. Real head styles, nut thicknesses, insert seating, washers and screw tip tolerances remain assembly checks. In particular, heat-setting an insert must not distort the printed shaft journal or split a coupling clamp boss.

The sensor directly follows approximately100° between stable end gates,104° between hard stops. This reduces use of the potentiometer's electrical range but can be calibrated; do not imply full sensor resolution or exact AliExpress compatibility without measurement. The complete RK097 body/shaft envelope is an assumption. Its real internal stops must remain beyond the controller stops with allowance for coupling play and mounting error.

The candidate spring specification implies roughly40N nominal force. With the20:35 tail/roller arm ratio, roller load is roughly23N before contact-angle variation. The three-gate cam has shallower slopes than the seven-gate cam, so one spring does not produce identical hand force for all profiles. Start with a softer spring and inspect shaft deflection, plate motion, stop marks, bush wear and clamp loosening before increasing preload. No fatigue, abuse-load or locomotive-feel certification follows from CAD clearance.

## Evidence inspected and release conditions

At review time the last neutral report contained only approximately0.000634mm³ cam/roller overlap, consistent with the faceted-profile/contact tolerance used in the checks. The seven- and five-gate reports each contained53 sampled poses with no interference above the0.01mm³ threshold. The three-gate run and revised depressed-follower service check were still in progress. The mesh manifest/report contained26 printable meshes, including cam alternatives; the original slice report recorded26 successful slices, with a subsequent11-part reslice report. Vendor/profile warnings mean the generated G-code remains validation output, not a printer-ready release.

These are sampled geometric checks. They do not prove uninterrupted contact, continuous-path clearance, real printed friction, real T-nut fit, force behavior or strength. Ideal native revolute joints can aid inspection, but a rigid coaxial coupling group does not simulate Oldham misalignment and an independent follower joint does not solve nonlinear spring/cam contact.

**Disposition:** the architecture is suitable for a low-load fit-and-function prototype after the scoped findings above are implemented and targeted checks pass. Close the three-gate, revised service-path, crossblock insert-wall and changed coupling/rotor/rail-hardware checks; regenerate exports and re-slice changed parts. Keep the fixed original frame unchanged and the unknown sensor interfaces replaceable. No further wholesale redesign is indicated by this review.

## Implementation updates supplied during review

The implementer measured the actual imported extrusion slot mesh: at X30/Z45 the first solid web is at Y81.2, against inner faceY75. A bare M5×30 would bottom. The agreed replacement is an M5×30 with **5mm total metal spacer/washer stack**, moving its seat toY50 and tip toY80:5mm penetration and1.2mm nominal clearance to that web. The5mm total includes the washer, not5mm plus an extra washer. Measure the selected actual T-nut and require at least3mm full effective thread engagement for this low-load prototype, or the supplier's greater requirement. This supersedes the nominal M5×25 suggestion and the earlier4mm target where actual selected nut geometry determines engagement.

The crossblock correction was refined to hole rowsY−62/−54 atZ53.5, keeping1.5mm material above the rail counterbore. The crossblock top moves toZ59; a2mm collar preserves its top atZ61 and the same1mm additional preload allowance. Guide bolts becomeM3×35 with washers/nuts aboveZ59. The M4 adjuster uses aØ7 socket head for clearance between the guide nuts. These dimensions are coherent as proposed; include guide screw tips and adjustment-tool access in the targeted checks and update the BOM. They are implementation updates, not a separate review round.

## Implementation closure (same review round)

The reviewed findings were implemented in scripts19,20 and22. Final crossblock rows are Y=-70/-62 at Z53.5, with the block extended toY=-74 (1mm inside the rail); this supersedes the intermediate -62/-54 proposal, which crossed a cup guide. Installed-insert outer wall is at least1.7mm for an assumed4.6mm OD, with ample cam-side wall. The guide bores remain separate. Rotor clamp with flat washer pad, default4.2mm and optional4.1mm coupling grooves, M5x30/5mm-total metal rail spacers, 2mm preload collar, M3x35 guides and M4 socket head are present.

Final neutral CAD check finds only0.000634mm� numerical cam-contact overlap. The three cam profiles each passed53 sampled poses. After corrections,27 additional rotor/coupling poses, operating/service follower positions, +/-1mm preload movement and optional tight-disc assembly fit passed the0.01mm� threshold. Revised cam withdrawal at5mm increments through40mm with the follower depressed5deg passes. Exported cam profiles track the intended roller center within0.0013mm over the159 sampled positions (mesh/facet approximation). These checks do not replace physical force or fatigue tests.

All27 final print meshes are single connected, closed, consistently wound solids, bed-oriented and inside the256mm P2S envelope. All27 final slices succeeded;12 use conventional supports. The largest part is171mm long. Vendor CLI preset/tool-command warnings are retained in logs; only geometry is released, not that G-code. Guide/BOM explicitly retain actual RK097, T-nut engagement, spring choice, free-sliding coupling and reversal-hysteresis checks. No additional review round was commissioned.
