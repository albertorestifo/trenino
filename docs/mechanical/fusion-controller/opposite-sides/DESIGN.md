# Opposite-side detent and sensor mechanism — pre-implementation design

25 October 2026. This is the original pre-implementation review draft, retained as evidence of the design-before-review sequence. The implemented specification is FINAL-DESIGN.md; its dimensions and REVIEW-DISPOSITION.md supersede this draft. These are AI specialist reviews, not licensed engineering certification.

## Purpose and scope

Put replaceable notch cams and their follower outside the left structural plate, and the 48:24 gear/pot drive outside the right. Eliminate the large cam extraction window and thin bearing bridges. Improve assembly/service access and seek an operating width no greater than the current approximately 95.35 mm. Width targets are provisional until the complete hardware envelope is checked.

Modify the current geared Fusion document directly, lineage peR4meb5QLiO5tE5ANITQg; rename it descriptively. Preserve the coupling baseline AIDesignedLever v6, lineage 2iFF2PJAQnO13x73oN2c-w, untouched. No new comparison document requested. Existing intermediate files need not be preserved as active options, but do not delete unrelated user files or documents.

No top panel or cosmetic housing. Retain existing 640 x190 x110 mm 2020 frame, top rail Z55, pivot Z30, handle/grip reach, top mounting and underside pot. Keep 120 degree mechanical travel (+/-60), cam terminal gates +/-58, 3/5/7/8 replaceable notch options, and sensor ratio -2. Do not substitute purchased hardware or consume stock. User prohibits cutting metal stock. PLA prototype, PETG later; Bambu P2S 0.4 nozzle/default profiles remain unchanged.

## Datum and axial stack

All dimensions mm. X runs along the main shaft; Y is forward/back across the rails; Z is up. Pivot (Y0,Z30); roller nominal (Y0,Z-23); follower pivot (Y-35,Z-23). Frame rail inner edges Y+/-75, top55.

| Feature | Proposed X extent / location |
|---|---|
| Left structural plate P01 | -24..-12, 12 thick |
| Right structural plate P02 | 12..24, 12 thick |
| Main rotor/handle | -7..7, 14 thick |
| Rotor thrust spacers | -11.8..-7 and 7..11.8 (4.8 each) |
| Plain journal bushes | -24..-12 and 12..24; outward flanges to +/-25.2 |
| Shaft round journals | -25.35..25.35, diameter12 |
| Shaft central D section | -11.8..11.8, diameter16, flat Y6.5 |
| Left keyed drive extension | -38..-25.35, diameter12 with flat Y4.8 outside journal |
| Left cam carrier hub | -38..-25.5, D bore diameter12.3/flat4.95 |
| Left carrier fan | -33..-25.5, 7.5 thick; cam screw inserts accessible from -X |
| Interchangeable cam | -41..-33, 8 thick |
| Main shaft retaining cap | -40..-38; M3x8 head to -43 |
| Follower | old follower translated -49 in X: -45..-29 |
| Roller bearings | two 623ZZ, -41..-33; align with entire cam thickness |
| Follower outer support plate | -49.2..-45.2, 4 thick; only around pivot/tail, not cam withdrawal path |
| Follower pivot inner spacer | -29..-24.2, 4.8 thick, 0.2 clearance to P01 |
| Printed follower axle | -47.05..-22.15, diameter8, 24.9 long; captured in 2 mm blind seats on both supports |
| Cassette support posts | P01 integral bosses -33.5..-24; separate spacers -45.2..-33.5, length11.7 |
| Outer support fasteners | M3x20, recessed head seat -47.2, tip -27.2, heads to -50.2 |
| Right shaft shoulder | 25.35..28.35, diameter20 |
| Right gear drive stub | 28.35..36.35, diameter8, flat3.2 |
| Gear faces | 28.5..36.5, 8 thick |
| Pot body front / bushing / rotating shaft | X22 /22..29 /29..37 |
| Pot mount | 22..25, 3 thick, local rebate in P02 |

Estimated operating width -50.2..37 =87.2 mm, ~8 mm less than old95.35. Includes tentative cassette fasteners; verify every installed head/terminal and follower sweep. Leave clearance between adjacent modules; service requires additional space on the cam side. Do not advertise a final pitch from this estimate.

## Structural plates and frame attachment

Replace P01/P02 from clean geometry rather than accumulating plugs and windows. Each plate has a broad web approximately Y-74.5..74.5, Z-37..55, with top tabs extending to Y+/-95 at Z55..64. Tabs start inboard at |Y|60 for a 14.5 mm wide overlap on the web. Four M5x14 screws at X+/-18,Y+/-85 keep head seat64 and nominal tip50, retaining the previous 1.2 mm clearance above the rail's nominal web48.8. Confirm exact fixed frame mesh remains unchanged.

Use radiused outside corners and internal tab transitions where compatible with rail clearance. No decorative windows, narrow bearing bridges or former rail-access notches. Nominal bearing seat diameter20.3 at Z30 leaves approximately14.85 mm material above its top before the web top55. Front/back webs are broad. Main shaft loads enter both plates through replaceable bushes, then spread to both rail mounts. Two internal crossblocks at Y+/-60, Z30..50, X-12..12 brace the plates against spreading/twisting. Each has two M3x20 screws per end (Z35/45), eight screws total; through-plate length12 leaves8 mm insertion. Blind insert holes need clearance beyond screw tip, nominal8.5 mm depth, and must not meet opposing holes.

P02 has only a localized pot body/wire clearance (nominal Y+/-8, Z-27..-3) and local mount rebate (Y+/-24,Z-30..0,X22..24.1). Use rounded corners at least3 mm. This remains well below the main bearing and does not interrupt its upper web. Pot adjustment mounts at Y+/-16,Z-15.15; their insert holes stay outside the body window. No cam service opening.

## Rotor, shaft, axial retention and stops

Rebuild the rotor without its former internal cam fan and left projecting stop lug. Retain the proven grip/stem interface and width14. Main hub radius22, central keyed16 mm D socket with diameter16.2/flat6.65; retain radial M3x16 clamp, seated at Y22.5 with tip6.5, acting on the shaft flat. Counterbores and insert access must be explicit. Two existing grip M3x20 screws remain.

Add a downward stop lug in the same X-7..7 body, ending in a radius5 nose centered at (Y0,Z0), 30 mm below the pivot. Give it a broad 12 mm root with curved transitions into the hub. It is separated from the upward handle stem and from the external cam. Two separately printed fixed stop pads attach to the inner P01 face, X-12..3, radius8. Their centers are at radius37 from the pivot, at +/-[60deg + acos((30^2+37^2-13^2)/(2*30*37))] from downward vertical. This sets contact of radius5 lug against radius8 pads at +/-60. Exact CAD check must confirm no other hub/stem contact occurs first. Pads use M3x20 through the 12 mm plate into captive M3 insert, with tips at X-4 inside the pad. Root faces bear on the plate; stop loads bypass the sensor and external cam hub. These are fixed stops, not continuously adjustable.

Split main shaft longitudinally for horizontal print strength and round journals; do not flatten the running journal surfaces to create a one-piece bed face. Shorter shaft central section has two recessed M3x8 joining screws at X+/-8 and one loose alignment key at X0; inspect clashes with rotor and key. Left extension must pass through the left bush: D major diameter12, not a larger shoulder. Assemble shaft halves/keys, slide bushes from the left before fitting the cam carrier, close plates and fit right shoulder/gear. Cap M3x8 seat-40, tip-32 engages the shaft end insert from X-38 to approximately-31.2. The carrier hub butts against shaft end at-38 and is held by the cap; nominal outward flange clearances are0.3 left and0.15 right. Central raised shaft/spacer clearances can constrain actual end float; measure the combined stack and target0.15..0.4 mm free movement, not a clamped bearing.

Cam carrier has a keyed12 mm D bore and one radial M3x10 clamp acting on its flat, with an accessible insert and at least supplier-minimum surrounding wall. It must not depend on a loose D fit alone for reversal feel. Carrier fan radius41 over at least+/-65 degrees supports the cam's three bolt stations at radius36, angles-45/0/+45. Insert pockets diameter4, minimum6.8 deep within7.5 thickness, entry on the outward cam mating face. Cam screws M3x10: head recessed3 mm into cam outer face, seatX-38, tip-28; approximately5 mm thread engagement into carrier. Confirm head and driver paths avoid follower.

## Detent follower, spring and service

Keep the existing roller-compensated profiles and 1.4 mm nominal lift, same YZ geometry as the raised wide-travel version. Move the entire follower and roller pair49 mm left without changing its YZ lever arms (35 mm pivot-to-roller,20 mm pivot-to-spring-tail). Two 623ZZ bearings give full8 mm cam support and maintain the previous contact calculation. Use original fork after translation and preserve print feet/teardrop holes.

Replace the long cross-module printed pivot with a shorter24.9 mm split printed axle captured at both ends. No cantilevered M3-only follower pivot. Outer support plate has two mounting points at approximately(Y-55,Z-35) and(Y-15,Z-35), both below the cam's swept envelope. A broad plate surrounds pivot(Y-35,Z-23) with an8.3 mm blind axle seat. Inner P01 has matching blind seat and integral bosses for the two mounting screws. Spacers carry clamp load; screw engagement target6.3 mm into6.8 mm-deep insert pockets beginning atX-33.5. Outer screws seated-47.2 through4 mm plate and11.7 spacers, tips-27.2. Verify insertion of the plain axle and1 spacer before fitting outer support; retain0.2 mm fork-to-outer-support gap. Prove outer plate and posts do not obstruct cam withdrawal at the neutral position.

Move the spring/cup/guide arrangement49 mm left. Rebuild spring reaction block X-49..-24,Y-66..-44,Z3..24, carrying the existing cup, two short guide sleeves and preload adjuster at X-37,Y-55. Attach block to P01 using two M3x20 screws from its inner face (seat-12, tip-32), at Y-62/-48,Z14 with8.5 mm deep insert relief. Confirm the inner screw heads do not collide with the rotor/stops. Existing installed spring length17, nominal additional preload1, and minimum operating length15.2 are assumptions to recheck. Spring is stocked wire1/OD9/free20; rate/solid height unmeasured, previously assumed solid height<=14. Do not claim this assumption prevents actual coil bind.

Provide an accessible service latch/pin or explicit retained-hand tool position to hold follower down5 degrees while the cam is changed. Preferred printed service prop: flat part that locates on fixed cassette below the follower tail and positively holds it away from cam; geometry must be checked with spring remaining above assumed solid height. If the prop cannot be made reliable, use a captive screw-controlled release instead; do not specify fingers holding a loaded spring next to the extraction path. Spring unloading method must be documented separately.

Cam swap: place lever at central reference; restrain/unload or latch follower; remove three outward-facing M3x10 screws; slide cam approximately10 mm outward to clear its7.5 mm carrier engagement/obstructions (cam itself is flat face mounted, no central shaft bore); remove it without moving shaft, main bearing plate, gear, pot or their calibration; fit replacement and release follower. Check full extraction path up to20 mm. For an8-position cam, zero is a crest, not a central notch. Cam carrier remains on shaft and keeps angular registration. Three-hole pattern at -45/0/+45 plus asymmetric outer contour identifies correct orientation; add durable index marks if practical.

## Sensor and gearing

Retain48/24, module1.25,20 degree involute gears,8 mm faces and45.15 mm nominal center distance. Main gear axisZ30, pot axisZ-15.15. Move existing gear, pinion, clamping hardware and pot12 mm inboard in X, preserving phase and pinion clamp channel clearance. Main gear is a single printed split-clamp part, not two halves or an anti-backlash pair. Mount adjustment limited to45.0..45.5 mm center distance. Record mesh backlash as a physical test.

Pot dimensions user reported: diameter6 rotating shaft,8 mm rotating length,15 mm body-face-to-tip including M7 bushing; inferred bushing length7. Body11.2 x9.5 x6.6 excluding terminals; width/height orientation remains assumed. At body frontX22, rotating shaft spans29..37. Pinion28.5..36.5 has relief through29.3, giving7.2 mm grip and0.5 mm projecting shaft. Supplied washer0.5/nut2 are unverified envelopes. Preserve open access to terminals inboard; reserve at least5 mm additional depth as provisional routing space, not a measured terminal dimension.

Full lever travel requires240 degrees of sensor rotation plus internal mechanical margin. User cannot currently measure travel; retain this explicitly as an unverified commissioning limit. Do not claim electrical linearity from the A10K designation. Sensor never acts as a structural stop.

## Hardware and inventory basis

Use stocked M3 cap screws in5/6/8/10/12/16/20 lengths; the kit lists20 each and160 nuts, but remaining individual counts are estimated. CNC Kitchen standard M3 inserts4.6OD x5.7:100 known; use nominal4 mm straight bore,6.8 mm blind depth, >=1.6 mm wall around installed4.6OD (more at load-bearing mounts). Verify with fit coupons. Four M5x14 and four2020 T-nuts, two623ZZ rollers, one9x20 spring, one measured pot remain. No uncut aluminium tube or new purchased axle required. Eight608 bearings/metal axle upgrades are not part of this revision.

Provisional per-build M3x20 demand: crossblocks8, stop pads2, grip2, outer follower support2, spring block2, preload1 =17; roller axle1 =18 if unchanged M3x20. Other counts: M3x8 shaft2+cap1; M3x10 cam3+carrier clamp1; M3x12 gear clamps2+pot panel2+cup guides2=6; M3x16 rotor clamp1. Confirm exact assembly and count after modeling, including prop hardware if any. Shared v6 comparison consumption must consider available compatible separate M3 stock; do not count a whole kit as300 arbitrary screws. Do not alter stock quantities.

## Preliminary load reasoning and required tests

For review only: choose50 N hand force at160 mm grip radius as a conservative prototype load case (8 Nm at end stop); accidental100 N gives16 Nm. These are engineering assumptions, not measured operating force or a certified rating. Main shaft bearing span reduces from60 to36 mm, improving bending stiffness for the same section. Under50 N centered transverse load, each bearing reaction is about25 N absent stop/contact forces. Stops transmit torque into P01 directly; estimate stop contact force8Nm/30mm approximately267 N, then inspect plastic root stress, insert seating/shear and tab bending with the actual geometry. No material allowable is established for the user's printed PLA/PETG, so avoid claiming a safety factor from nominal bulk strengths.

Detent torque and follower loads depend on unmeasured spring rate. Check several assumed rates e.g.2/5/10 N/mm to expose sensitivity, not assign the spring a fictitious rate. Main external cam drive transmits detent torque, while end-stop abuse should bypass it. Outboard cam reaction causes bearing/shaft moment; estimate from actual offsets and reaction forces. Check printed axle/bush wear and split-shaft torsion; unchanged material is not proof of adequate life.

## FDM plan and acceptance gates

P01 print inner X-max face down so outboard cassette bosses grow from supported plate. P02 X-min face down. Main rotor X-min or max face down with no projecting side lug/fan; grip unchanged. Carrier X-max face down, hub grows upward. Cams face down with counterbores opening upward (outward X-min up). Outer follower support flat X face down, blind axle seat/counterbores must be oriented or bridged explicitly. Split shaft/pivot halves flat split faces down; crossblocks, spring block, cups and service prop get broad bed faces. No support assumption is accepted without layer inspection. Vertical M5 rail holes become horizontal in plate print orientation: retain circular clearance and add45-degree roofs in the print-up X direction. Do not silently change default slicer profiles.

1. Specialist reviews of this complete document before any CAD edits; record issues, disposition and revised dimensions.
2. Build in small native stages; place new components only after features are created and capture Fusion snapshots. Verify transform persistence, single solids and healthy history. Explicit cut participants only.
3. Neutral full hardware check, all cam gates/crests and +/-60 sweep, pot adjustment extremes, stops immediately outside travel, spring/cup motion, service prop and cam extraction, driver approach and pivot insertion. Include frame and neighbor operating/service envelopes.
4. Export mm STLs and native archive; check scale, winding, manifold edges, one connected shell, no degeneracy, bed contact and practical fit on256 mm bed. Reject edge-only joins even if native BRep reports one solid.
5. Slice changed parts using existing default P2S/PLA profiles, inspect layer continuity and bridges. CLI's existing nozzle_volume_type/T65535 errors prohibit G-code release until resolved. Report any remaining unsupported geometry honestly.
6. Deliver saved updated geared Fusion model, design/review/disposition documents, measured envelope comparison, print geometry, orientation/assembly/service instructions and actual CAD images. Physical fit, spring, pot travel, strength and wear remain commissioning tests.
