# Final independent mechanical review

Reviewed the revision identified as SHA-256 `55BBD86D6E83CB2951BB7B343A7EB9D457634D090BFEE3F14FED64A4AAB279BD`, together with `INTEGRATED_PRINT_GUIDE.md`, `integrated-validation.json`, the assembled/internal screenshots, and `reviewed-print/mesh-check.json` and `slice-report.json`. This is a geometry, mechanism, assembly and load-path review for a low-load physical prototype. It is not a strength certification or physical test.

## Release blocker found and corrected

**The M4 preload nut was retained on the wrong side for its axial load.** In the reviewed source the hex pocket opens outward at y=−22. Spring reaction pushes the adjuster screw and nut toward +Y, out of that opening. The loose preload collar does not positively retain the nut.

The minimum correction agreed with the implementing agent is:

- Keep the current bracket and Ø4.4 through bore.
- Place the 3.2 mm nut at y=−27.9…−24.7.
- Open the 3.4 mm-deep hex pocket from the spring side, y=−28.1…−24.7. With the existing +90° X rotation of the hex extrusion, this means translating both pocket and nut to y=−24.7.
- This leaves a 2.7 mm solid retaining wall at y=−24.7…−22 against the spring reaction. The nut is recessed 0.1 mm from the spring-cup face at nominal adjustment.
- Install the nut before installing the cup and its guide bolts. The 13 mm external limiter collar can stay unchanged.
- Verify neutral and +1 mm screw-advance positions, then regenerate/re-export/re-slice the changed spring block. Update the source hash and validation record.

Implementation closure: the correction is present in source SHA-256 `8E0F76D93B1EF02D5618B50AD2BF37C296640A0BEEAB5AC801CBEB40222B2606`. I read back the changed nut/pocket dimensions and `final-retention-validation.json`: no notices, 84 solids with zero intersections, 53 sampled motion poses with zero clashes/contact gap, 41 clear service poses, and zero clashes at +1 mm preload advance. The 22-part mesh/slice report initially reviewed predates this local block change; the implementer is refreshing the S03 export and its mesh/slice check before release.

**Adjustment behavior, now corrected in the guide:** at nominal adjustment, the cup front face y=−28 already contacts the bracket rear face y=−28. Backing the screw away does not lower preload; it merely separates the tip from the cup. The prototype therefore offers nominal preload plus approximately 1 mm additional compression. Use a softer spring or smaller free length to reduce force below nominal, rather than claiming that screw back-off does so.

## Resolution of the earlier review

| Earlier issue | Current assessment |
|---|---|
| Lever attached to a separate shaft hub instead of Main Gear | Resolved: lever/stem and original 48T gear form one printed part. The two grip halves enclose the keyed stem. |
| Torque relying on a loose D fit and radial set screw | Improved: three M3×10 screws at radius 15 mm directly connect the gear to the carrier. The shaft fit is no longer the only detent-torque path. |
| Lost axial capture after removing the hub | Resolved geometrically by the 13 mm spacer at z40.5…53.5; verify actual end float during assembly. |
| Unsupported detent structure | Resolved architecturally: the follower support and stop arch mount to the existing 2020 rails. The imported extrusion geometry is visible in the complete stack. |
| Lever or mounting ears crossing the rails | Addressed by narrower tapered stem, ±65° travel, revised feet and clearance testing. The supplied audit reports no sampled clashes. |
| Threaded screw used as a follower bearing | Resolved: a 7 OD ×5.2 ID ×20 mm metal sleeve supports the fork and carries pivot clamping compression. |
| Undefined spring thrust hardware | Substantially resolved: specified M4×20 adjuster, captive guide cup, two guide screws, tail/cup pilots and limiter collar; nut-retention correction above is now implemented and targeted CAD checks passed. |
| Thin unsupported end stops | Improved: 6 mm arch on the rails, larger carrier lug and steel-cored printed stop posts. Impact strength remains a physical prototype question. |
| Missing full controller context | Improved: screenshots show the handle, gear/cam stack, two frame plates and actual 2020 extrusion geometry. It remains an assembled Part Studio, not the original native mated Assembly. |

## Remaining prototype qualifications

- **Spring force and terminology:** 18 mm free length and 10–12 N/mm rate at 14 mm installed length imply 40–48 N **spring** load. The 18:36 mm lever-arm ratio makes roller/follower contact load roughly 20–24 N, subject to contact angle. The guide's approximately 2.2–2.6 N hand-force estimate already includes that ratio; change the phrase “40–48 N follower load” to “40–48 N spring load.” The spring has not been selected or physically tested. Check the specified solid height against nominal preload, full permitted adjustment and full cam lift.
- **Gate positions and endpoint behavior:** with `pitch=130°/count`, the stable gates are 0,±43.333° for three; 0,±26°,±52° for five; and 0,±18.571°,±37.143°,±55.714° for seven. The ±65° stops are cam crests, half a step past the outer gates. Released at a stop, the lever tends back toward the nearest outer gate. This is valid push-through detent behavior but must be stated; do not describe the stops as stable end gates. Change the profile only if stable full-travel endpoints are required.
- **Axial float:** the gear face starts 1 mm above the first bushing's inner face and the spacer ends 0.5 mm before the second bushing. The rotating stack therefore has approximately 1.5 mm available axial travel. The modeled roller/cam overlap tolerates that nominal range, but clunk and gear alignment need checking. Fit thin shims as required while preserving free running. Do not preload the printed bushes by overtightening the shaft-end screws.
- **Bushings and shaft:** the Ø15.9 bushes are slip fits in nominal Ø16.1 seats. Their frame shoulders and the surrounding stack provide geometric capture rather than flanges. Inspect migration, rocking and journal wear. Ø9.6 bush bores on Ø9.2 journals give 0.4 mm diametral clearance; this may be perceptible at the hand grip. Use a fit coupon and tune actual printed dimensions. Abrupt shaft transitions and the printed stop-lug root require low-load inspection; the model does not establish fatigue or impact strength.
- **Stop load path:** stop reaction runs from gear through the three carrier bolts, the carrier lug and printed stop contact, through the steel-cored post/arch and rail mounts. The potentiometer is not intended to absorb stop force. M3 reinforcement does not make the plastic arch or tall lug impact-proof. Start with gentle contact, inspect damage, and do not infer an abuse-load rating from the collision checks.
- **Grip:** the approximately 40 mm, two-half palm grip has positive stem capture and two screw locations. Its clearance socket allows manufacturing tolerance, so test for rocking and seam movement. Avoid overtightening the two insert fasteners into printed grip shells.
- **Hardware and mounting:** the five M5 rail fasteners in the new BOM mount the added follower/stop structure. Existing frame-plate-to-2020 mounting hardware is additional and should be explicitly listed as reused/original hardware. Actual T-nuts are not modeled, so confirm slot type, nut thickness, screw engagement, tool access and absence of bottoming on the real rail. The model's revised 64.5 mm plate span must be set on the physical frame.
- **Potentiometer:** the reference shaft does not establish real body clearance, shaft engagement, permissible torque, or travel. At ±65° lever travel the gear ratio requires approximately 260° potentiometer travel. Verify the actual part and calibration before coupling it to the full range.
- **Service:** the recorded 41-pose sector-removal path is useful geometric evidence. Check hex-key access and the actual fastening order with the real frame and hardware installed. The native original Assembly has not been updated with this mechanism or its mates.

## Evidence and conclusion

The supplied CAD audit records 84 solids without modeled pairwise intersections, 53 sampled positions for each of the three cam profiles at maximum lift without detected interference or contact gap, and a 41-position cam-removal path without reported clashes. I read the validation records and inspected both assembly screenshots. The mesh report contains 22 printable objects with closed, consistently wound, connected geometry and print-bed bounds; all 22 entries in the slice report return success. The slicer logs also contain vendor/profile warnings, including the invalid T65535 command warning, so those files establish slicing feasibility and are not approved machine-ready G-code.

**Disposition:** the identified M4 nut-retention blocker is closed in the source and targeted CAD evidence. The guide corrections have been applied. No additional mandatory architecture or geometry blocker was identified. Complete the updated S03 mesh/slice check, then the design is reasonable to release as a low-load fit-and-function prototype. Physical spring feel, mount fit, potentiometer compatibility, backlash, wear and stop/shaft strength remain bench validation. Do not describe it as production-qualified or as a native mated Assembly.
