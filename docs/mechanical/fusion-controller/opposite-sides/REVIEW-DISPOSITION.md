# Review disposition — implementation dimensions



Both independent AI reviews completed before any Fusion edit. This document supersedes conflicting initial draft dimensions. Conditional architecture acceptance is not physical certification.



- **M1 / F4, shaft assembly:** omit integral right shoulder. Ø8 D stub begins X25.35 and ends36.35. Both bushes can slide on from their respective shaft ends. Central raised D section remains X±11.8 inside the24mm bearing gap, giving nominal0.4mm axial travel. Gear installation uses its specified face X28.5; clamp after setting that position. Carrier flange-facing center is relieved to X-25.8 within R13, leaving0.6mm nominal flange clearance.

- **M2 / F1, service release:** use an M3x12 service screw, not an unretained loose prop. Back preload completely off, rotate follower to absolute -4°, and fit screw through outerplate at Y=-54.9513,Z=-21.6049. Seat X-49.2, tip-37.2. Dedicated follower-tail insert starts X-45 with8.5mm screw relief. Screw is removed before operation. Roller withdrawal2.441mm; spring length15.605mm at fully backed-off cup. Actual solid height remains unknown. Service screw is an extra stocked M3x12 and insert, and excluded from normal operating width.

- **M3 / F3, stops:** R8 contact cylinder X-8..0, supported conical base R8 at-8 toR10 at-12, Ø12 locating spigot X-17..-12. P01 socketØ12.3,5.3deep frominnerface. M3x20 headseat-24 tip-4; insert enters spigot at-17, pilot/tiprelief13.5deep. Spigot carries shear by bearing; screw retains pad. Nominal289N contact force at8Nm gives4.8MPa average spigot bearing pressure, without a material allowable. Physical proof testing remains required.

- **Carrier clamp:** add local boss with seatY14.8 for M3x10 tipY4.8, insert pocketY8..14.8 and shaft-tip clearance. Inspect the installed insert OD and axial cap envelope. Fan retains7.5mm thickness and6.8mm pocket, leaving0.7mm floor; explicitly inspect those layers rather than shortening supplier-required depth.

- **F2, print directions:** P01 innerXmaxdown with negativeX rail roofs; P02 innerXmindown with positiveX roofs. Outerplate innerfacedown accepts a defined8.3mm blindseat bridge, to be inspected. Crossblocks Xfacedown accept4mm closed-pocket bridges. Springblock Zmaxdown uses upward roof relief on horizontal mounting pilots. Rotor/carrier radial bores receive roofs in their respective printup direction. These are candidate support-free geometries pending actual slicing.

- **Plate bosses and tolerances:** use broad Ø16 cassette bosses, controlled0.2mm follower gaps and replaceable bushes/spacers. Clearances are fit hypotheses. Do not claim an untested strength rating or automatic fit.



Implementation is authorized by the user's request to proceed after these reviews. Primary agent implements in current geared document; v6 is untouched. Final checks must use actual final geometry and record any further corrections.



## Pre-verification geometric corrections



- Stop retaining screws become M3x16, recessed3mm into P01 (seat-21,tip-5); heads are flush with the outsideplate so the external carrier can sweep past. Pad tip relief remains deep enough.

- Cassette posts/spacers move toZ-39 and useØ12 bodies, clearing the underside of the follower in itsservicepose. P01 gains a continuous lowerweb toZ-45; outerplate bottomZ-46.

- Spring reaction block frontedge moves fromY-44 to-50 to stay outside the rotating cam envelope; second mounting screw moves fromY-48 to-54.

- Rotor lowerroot terminates atY±5,Z0 rather than±6, so its corners do not preempt the intendedR5 stop contact. Exact final BRep sweep remains the acceptance test.



- Shaft joining screw/insert centers move fromX±8 to±7.5, leaving2.0mm nominal axial wall beyond installed4.6mm inserts within the central shaft section.

- Dense adjacent modules still require extra left-side service space; operating pitch alone does not establish in-place cam extraction between neighbors. Allow20mm cam-side service movement or remove the module from its rail mounts.



- Final cassette refinement: merge the two compression spacers intoP33, preserving exactly the former combined solid volume/envelope. This removes two loose printed parts. PrintP33 outerXminface down: posts and blind pivot seat faceup; the two6.2mm head-pocket closures are the defined bridges toinspect, replacing the prior8.3mm blind-seat bridge.



## Final verification-driven refinements

The braces were lowered 5 mm to clear endpoint motion; the pot panel was trimmed at adjustment limits. Cam handedness now mirrors X only, preserving the asymmetric YZ profile. The carrier underside is flat (superseding its provisional 0.6 mm recess), its clamp boss reaches the print bed, and the left bush flange is 1.0 mm. The rotor clamp seat also extends to its bed face. These changes eliminate the floating-feature issue and preserve the verified assembly clearances. Final dimensions are in FINAL-DESIGN.md; completed verification and remaining physical checks are in VALIDATION.md.
