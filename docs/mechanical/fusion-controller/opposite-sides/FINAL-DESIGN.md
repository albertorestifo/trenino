# Opposite-side lever: implemented specification

25 October 2026. The complete design was written and reviewed by independent AI mechanical and FDM specialists before Fusion edits. Their reviews, the original input and dispositions accompany this specification. They are not licensed certification or physical testing.

The existing geared document was revised directly: **AIDesignedLever Opposite-Side Detent**, lineage `peR4meb5QLiO5tE5ANITQg`. The pre-gear **AIDesignedLever v6**, lineage `2iFF2PJAQnO13x73oN2c-w`, remains unchanged. No new comparison document was created.

## Layout and operating limits

The removable cam and follower are outside the left structural plate; the gears and potentiometer are outside the right, with the pot below the main pivot. Both plates have continuous load-bearing webs without the former extraction window or narrow bearing bridges. No top panel or cosmetic housing is included. The existing 640 x 190 x 110 mm 2020 frame is unchanged.

All dimensions below are millimeters. X follows the shaft, Y crosses the rails, Z is up. Rail top Z55; pivot Y0/Z30; pot axis Y0/Z-15.15. Mechanical travel is +/-60 degrees. The 3/5/7/8-gate cams span116 degrees, leaving2 degrees beyond each terminal gate. The pot rotates twice the lever angle in the opposite direction; usable travel exceeding240 degrees plus margin remains unmeasured.

Measured operating width is **87.2 mm**, X-50.2..37, versus approximately95.35 previously. This includes modeled heads and the measured pot body/shaft, but unmeasured terminals need physical clearance confirmation. The service screw is removed during operation. Allow20 mm additional cam-side service movement, or remove a tightly packed module from the rails before changing its cam.

| Final axial stack | X extent |
|---|---|
| P01 / P02 structural plates | -24..-12 /12..24 |
| Rotor / thrust spacers | -7..7 /-11.8..-7 and7..11.8 |
| Plain bush bodies | -24..-12 /12..24 |
| Left / right outer flanges | -25..-24 /24..25.2 |
| Central shaft D section | -11.8..11.8, diameter16, flatY6.5 |
| Left D drive / right D drive | -38..-25.35, diameter12, flatY4.8 /25.35..36.35, diameter8, flatY3.2 |
| Cam carrier hub / fan | -38..-25.5 /-33..-25.5 |
| Cam / retaining cap | -41..-33 /-40..-38 |
| Follower / two623ZZ rollers | -45..-29 /-41..-33 |
| Outer cassette plate / integral posts | -49.2..-45.2 /-45.2..-33.5 |
| P01 cassette bosses | -33.5..-24 |
| Captured follower pivot / inner spacer | -47.05..-22.15 /-29..-24.2 |
| Gear faces | 28.5..36.5 |
| Pot front / bushing / moving shaft | 22 /22..29 /29..37 |
| Pot panel | 22..25 |

Bush OD20.1 fits20.3 plate seats; bores12.3 run on12 mm journals. Nominal central-stack axial freedom is0.4 mm. The carrier-to-left-flange gap is0.5 mm nominal and0.3 mm at the nominal positive end of shaft travel. These are print-fit hypotheses. Both bushes slide onto their respective shaft ends; the trapped integral right shoulder was removed.

## Structure and load path

Plates are12 thick, approximatelyY+/-74.5. P01 extends toZ-45; P02 toZ-37. Top tabs reachY+/-95 andZ64, with broad roots. Four M5x14 screws atX+/-18,Y+/-85 seat atZ64 and end atZ50, above the retained rail web at48.8. Two24 mm crossbraces atY+/-60, Z25..45 use eight M3x20 screws, atZ30/40. They were lowered5 mm after the original sweep found stem contact at the travel limits.

The planar14 mm rotor retains a radius22 hub and grip interface. Its downward radius5 stop nose is30 below the pivot. The root ends atY+/-5,Z0, widening into the hub without preempting the round contact. A radial M3x16 clamp acts on the central D flat. Its head-seat footprint reaches the bed face, avoiding an unsupported starting lip.

Two stop pads on P01 have radius8 contact cylinders X-8..0, supported conical bases growing to radius10 atX-12, and diameter12 locating spigots X-17..-12. Plate sockets are12.3 diameter and5.3 deep. Recessed M3x16 screws seatX-21 and endX-5; their heads are flush with the outer plate. Deep insert relief endsX-3.5. The spigot carries transverse load by bearing; the screw retains the pad. Centers areY+/-36.3109,Z22.8923. Actual geometry is clear at+/-60 degrees and contacts immediately beyond that. The sensor is never the mechanical stop.

The main shaft is split longitudinally for horizontal printing, joined by two M3x8 screws atX+/-7.5 with one loose alignment key atX0. Installed4.6 mm inserts have2.0 mm nominal axial wall within the central raised section. A cap and M3x8 screw retain the left carrier. The main gear is one split-clamp part, not two separate gear halves.

## Detent and service cassette

The carrier has a12.3 D bore with flatY4.95. Its M3x10 radial clamp seatsY14.8 and endsY4.8 on the shaft flat. Both carrier and clamp boss have direct bed support. The shallow underside hub recess was removed; a1.0 mm left bush flange provides the required gap instead.

The radius41 fan supports three cam screws at radius36 and angles-45/0/+45. M3x10 heads recess3 mm into the outward cam face and engage approximately5 mm of thread. Carrier insert pilots are4 diameter and6.8 deep in7.5 thickness, leaving a0.7 mm floor. Inspect those layers. Installed inserts end before the floor.

Cam mounting faces are mirrored only in X, preserving the original slightly asymmetric YZ roller-compensated profile. Native outer vertices match the generating profiles. Four cam variants are supplied; choose one for a single build.

Follower pivot isY-35/Z-23; roller centerY0/Z-23. Two623ZZ bearings provide8 mm contact width, with printed pads contacting their inner races and a stocked M3x20 axle/plain nut. The diameter8 printed pivot is captured at both ends, not cantilevered on an M3 screw. Nominal outer fork clearance is0.2 mm; the inner spacer leaves another0.2 mm to P01.

P33 integrates its two compression posts, eliminating two loose spacers without changing the combined envelope. Posts are atY-55/-15,Z-39, diameter12. Recessed M3x20 screws seatX-47.2 and endX-27.2 in P01 bosses. The outer plate is shaped below the cam withdrawal path and extends toZ-46.

## Spring and positive release

Reaction block: X-49..-24,Y-66..-50,Z3..24. Two M3x20 mounts enter from P01's inner face atY-62/-54,Z14. The front edge stays outside the cam sweep. Cup and guide assembly move49 mm left. Preload center isX-37,Y-55; two M3x12 guide screws retain the cup through printed sleeves.

Stock spring is wire1, OD9, free20. Rate and solid height remain unrecorded. Nominal installed length17, additional preload1, minimum normal operating length approximately15.2. The prior assumed solid height no greater than14 is not a measurement and cannot certify coil-bind clearance.

For cam service, back preload fully off and retain the follower at absolute-4 degrees using a temporary M3x12 screw through P33 into its dedicated tail insert. Plate passage isY-54.9513,Z-21.6049; screw seatX-49.2, tipX-37.2. Roller withdrawal is approximately2.441; conservative spring length approximately15.605 with preload backed off. Remove this screw before operation.

Cam changes remove only the three outward cam screws and the cam itself. Shaft, carrier, plates, gears and pot remain fitted. The8-gate cam has a central crest, not a central notch. Dense neighboring modules still require service clearance or removal from the rail mounts.

## Pot and gear interfaces

Retain48/24 involute gears, module1.25,20-degree pressure angle,8 mm face width. Center distance is45.15 nominal, adjustable45.0..45.5. The panel's trimmed top/bottom edges clear both limits. P02 has a local body/wire window approximatelyY+/-8,Z-27..-3 and a rounded mount rebate, well below the main bearing.

User measurements: moving shaft diameter6 and length8; body-face-to-tip15; body11.2 x9.5 x6.6 excluding contacts. Bushing length7 is inferred. Pinion relief reachesX29.3, giving7.2 shaft grip and0.5 tip projection. Nut/washer envelopes, terminal size, body orientation, taper and usable rotation remain unverified. A10K is not treated as proof of a linear electrical response.

## Hardware, printing and qualification

Per geared build: sixteen M3x20; three M3x16; seven M3x12 including the service screw; four M3x10; three M3x8; one plain M3 nut;32 CNC Kitchen M3 inserts; four M5x14; four2020 T-nuts; two623ZZ; one spring; one pot. No cut metal stock or purchased axle is required. The combined v6/new-build inventory draft is stock-sufficient on recorded counts, using six separately stocked M3x20 Torx screws at open brace positions. Counts and physical compatibility still need confirmation; no checkout occurred.

Review load assumption:50 N at160 mm reach, or8 Nm. Stop force is approximately289 N with a27.692 mm effective arm. A12 x5 spigot gives approximately4.8 MPa average projected bearing pressure. These calculations establish neither a printed-material allowable nor a safety factor. Strength, fatigue, wear and insert retention require physical commissioning.

Print orientations and bounds are in mesh-check.json. Plates print on inner faces; cams/carrier on inner faces; rotor on its broad X-min face; shaft/pivot halves on split faces; stops on contact faces; cassette on its outer face with posts growing upward. Defined pocket bridges include P01's12.3 mm stop sockets, P33's6.2 mm head recesses and4 mm insert-pocket closures. Test these before relying on fit.

The selected P2S0.4 /0.20 Standard /PLA Basic defaults remain unchanged, including2 walls and15% infill. Digital slicing is distinct from structural qualification. VALIDATION.md records final evidence and limits. Diagnostic CLI toolpaths with configuration errors are not included in the geometry package.
