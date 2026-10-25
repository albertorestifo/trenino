# FDM specialist review — opposite-side mechanism

25 October 2026. Independent AI specialist review of DESIGN.md before implementation; not a physical test or strength certification. No Fusion mutations performed. Basis: the design-for-fdm skill and its mechanical interface, geometry, print validation and CNC Kitchen insert references; existing 35_support_free_geometry.py and raised-wide-travel/orient_and_check.py. Dimensions below are proposed CAD decisions, not measured printer capability.

## Verdict

The opposite-side architecture is suitable to proceed after the specific items below are resolved in the design. Continuous side plates and a planar rotor are a substantial manufacturing improvement over the former extraction windows and thin bridges. The draft is not yet sufficient to call the whole assembly support-free or ready to print. Do not carry the old part-number orientation mapping forward unchanged.

## Findings requiring a design decision before implementation

### F1 — Service release is not designed yet

The prop has no defined seats, retention, print orientation or spring travel. At a five-degree follower rotation, the roller moves approximately 35 sin(5°) = 3.05 mm and the spring-tail end approximately 20 sin(5°) = 1.74 mm in the opposite direction. With a downward roller release the tail rises toward its spring cup. This can compress the spring more than the ordinary 1.4 mm roller lift, so the ordinary operating minimum cannot validate the service pose. Define a positive retained release, exact angular travel and spring-cup position. Prefer unloading the cup before engaging a geometrically captured prop. The prop should be a flat, broad part loaded in its print plane, with locating shoulders; avoid a thin snap finger taking continuous spring force. Verify it cannot slip into the cam extraction path. A captive screw release is acceptable if its entire adjustment and tip clearance are modeled.

### F2 — Several holes remain unassigned to a realizable print orientation

P01 should print inner X=-12 face down, outboard bosses upward. Its follower blind seat then opens upward and needs no roof. P02 should print X=12 down; its pot rebate opens upward. The rail bolt teardrop roofs must point in opposite assembly X directions for these two plates: toward negative X for P01 and positive X for P02. Copying the previous positive-X roof to both plates would produce an inverted roof on P01.

The outer follower plate has an inward-facing blind pivot seat and outward-facing fastener counterbores. Printing its inner X=-45.2 face down gives upward counterbores but an 8.3 mm-wide, 2 mm-deep pocket that closes above the bed. Explicitly choose and inspect that approximately 8.3 mm bridge, or change the pivot seat to a through hole with a separate flat external cap. The latter removes the bridge but requires retention and width accounting. Do not describe both opposite-face recesses as simply opening upward.

Crossblocks cannot have both end insert bores opening upward simultaneously. A practical orientation is Z-min down with X-axis holes horizontal. Specify a support-free crown while preserving the required insert contact, and validate heat-setting in an orientation-specific coupon. Alternatively print X-down and accept only the small defined bottom insert-pocket bridge after inspection. Make one choice in the manifest. The spring block likewise needs a stated Z-face orientation and roofs for its side mounting holes; inspect the spring-guide/cup recess, not only its exterior.

Rotor and carrier radial clamp bores are horizontal when their broad X faces are down. Provide a printable crown/accessible nut geometry rather than assuming a perfect circular horizontal hole. Any change to the nominal insert pilot is a local FDM accommodation requiring a coupon, not a new supplier recommendation. Preserve iron approach and the clamping flat.

### F3 — Stop load introduction needs a positive locating seat

The circular pads are 15 mm tall in an X-face-down print. Their working load is across the layer stack and acts outboard of the supporting plate. A flat pad with one insert/bolt should not be credited with a strong structural connection solely because it is solid in CAD. Add a shallow broad locating pocket or keyed shoulder in P01 so the pad transfers transverse load by bearing over a useful area, and include an end fillet/chamfer that does not lift its print bed face. Recalculate screw engagement if its seating face moves. Keep the nominal 8 N·m load case provisional pending the mechanical review and physical proof test; default slicing has no established allowable for this assembly.

### F4 — Split-shaft assembly features need fresh section and slice checks

Lengthwise split printing remains defensible: it gives a flat bed and longitudinal paths without flattening the running journals. A single upright shaft would change layer loading and is not an equivalent strength solution. However, moving the joining screws to X=±8 and leaving a key at X=0 creates a new pattern. Verify the installed 4.6 mm insert envelope, counterbore, key pocket and D socket overlap in full 3D. Do not rely on pilot-hole separation alone. The lower shaft half's old slicer warning was unresolved; its evidence cannot be inherited as a pass. Inspect the first layers that close insert pockets and every shoulder transition on both halves. Keep cap insert geometry accessible before shaft assembly, and ensure the split line cannot open during heat-setting or tightening.

## Changes recommended, without blocking the architecture

- Carrier fan: R41 with screw centers at R36 leaves 41-36-2.3 = 2.7 mm radial material beyond the installed insert, better than the stated 1.6 mm supplier minimum. At ±45 degrees inside a ±65 degree sector there is also useful angular margin. Check any actual trimmed contour, hub junction and counterbores separately. A 6.8 mm pocket in 7.5 mm thickness leaves only 0.7 mm floor; round the floor to a deliberate 0.8–1.0 mm if possible, by increasing fan thickness in the available stack or reducing pocket only within the supplier minimum and screw clearance. Do not blindly shorten the 6.8 mm pocket.
- Carrier radial-clamp installed insert wall should be calculated to the D bore and outside surface. Radius14 versus flat4.95 leaves 9.05 mm along the clamp axis, but this does not itself establish the walls on the sides of its 4.6 mm installed diameter. Use section measurements at its mouth, tip and slit if one is added.
- Add small nonfunctional bed-edge chamfers to prevent elephant-foot rubbing on spacers and cam faces; keep journal and mating datums intact. Treat nominal 0.2 mm fork/plate gaps and 0.15 mm shaft shoulder gaps as fit hypotheses, not guaranteed moving clearances. Include thin optional thrust shims or a controlled adjustment method rather than requesting arbitrary sanding of bearing faces.
- Flat cams printed with outer counterbores up are a good choice. Their working radial perimeter lies in the print plane. A 3 mm head recess leaves 5 mm cam thickness beneath the head. Check recesses against the actual cam inner boundary, not only the outer R41 carrier edge.
- Rotor X-face down is favorable for lever bending in YZ and avoids the old projecting side lug. Use generous in-plane transitions from the downward lug to the hub, but do not add bed-face fillets that introduce unsupported rounded undersides.
- Cassette integral bosses on P01 grow normal to the plate and take bolt axial load across layers. Blend the base with a supported 45-degree gusset or wide taper; a rounded underside fillet alone is not necessarily printable. Maintain the broad web, avoid necking the post to the insert's minimum wall, and include actual insert pull-out behavior in commissioning.
- The outer cassette plate is only 4 mm thick and has opposing recesses. Explicitly verify remaining material between the 2 mm pivot seat, mounting counterbores and outside edges. Four millimeters is a packaging choice, not evidence of adequate stiffness.

## Required orientation and validation record

| Part | Intended orientation | Remaining evidence |
|---|---|---|
| P01 | Inner X-max face down | Negative-X rail roofs; broad boss bases; bearing circularity |
| P02 | Inner X-min face down | Positive-X rail roofs; pot rebate and insert walls |
| Rotor | Broad X face down | Radial clamp crown and stop-root paths |
| Cam carrier | X-max face down | Clamp crown, hub/fan junction, insert pocket floor |
| Cam variants | Inner X-max face down, recesses upward | Every notch crest and counterbore slice |
| Outer cassette plate | Inner face down, unless seat changed | Explicit 8.3 mm blind-seat bridge or separate cap |
| Shaft and follower axle halves | Split face down | Both halves; old lower-shaft warning resolved |
| Follower | Existing Z-min feet down | Reuse only if geometry unchanged; inspect roof and fork paths |
| Stop pads | Plate-contact X face down | Locator, bearing shoulder, layer shear; physical proof |
| Crossblocks/spring block | Explicit choice still required | Horizontal bores or defined bottom bridges; insertion tools |
| Service prop | Broad face down | Positive retention and spring-travel proof |

Use unchanged selected P2S 0.4 / PLA / process defaults. A zero generated-support count does not prove every unsupported path is printable: inspect islands, bridge anchoring, thin walls and the exact layers closing pockets. Verify a single manifold printable body per intended part, scale, positive volume, connected paths, bed contact and final-file hashes. The plate's approximately 190 by 101 mm broad footprint fits the 256 mm envelope; plate arrangement must retain practical margins.

Print orientation-specific shaft/bush, insert and carrier-clamp coupons first. Check assembled end float and reversal behavior before structural printing. Release oriented geometry with any unresolved bridge limitations stated. Do not release the previous CLI's invalid T65535/nozzle-volume toolpaths. Actual strength, wear, spring solid height and pot travel require commissioning; successful CAD and slicing do not resolve these.

## Source for insert dimensions

CNC Kitchen standard M3 × 5.7 guidance, as verified in the local skill reference on 25 October 2026: [manufacturer dimension poster](https://www.cnckitchen.com/s/CNCKitchen_Heat-Set-Insert-Dimensions-and-Design-Guidelines.pdf). Nominal pilot 4.0 mm, installed OD 4.6 mm, minimum surrounding wall 1.6 mm, blind depth at least 6.7 mm. These are supplier geometry requirements, not printed strength ratings or a calibrated P2S fit.

## Follow-up on proposed corrections

The implementer proposed removing the right integral shaft shoulder, adding keyed stops and using a removable 4 mm service pin at an absolute follower angle of -4 degrees. Removing the shoulder resolves an assembly concern but requires the final shaft retention stack to be recalculated. The pin is a clearer service mechanism than the unspecified prop: the corresponding approximate roller drop is 2.44 mm and tail rise 1.40 mm. Backing off preload must actually increase cup space; verify the captured cup does not reach another stop first. Give the pin positive anti-escape retention and an unobstructed insertion route. Keep it out of normal operating travel.

A manufacturable stop candidate, subject to mechanical load review: R8 circular contact cylinder X=-7..0, 45-degree conical transition from R8 to R9 over X=-7..-8, R9 base X=-8..-12, then rounded 12×12×3 mm key X=-12..-15. A 12.3×12.3×3.3 mm plate pocket is a starting clearance. Print X=0 contact face down; the cylinder, short cone, base and key grow with no unsupported underside. The key corners fit within the R9 base. This is smaller than the implementer's proposed 14×18 key and therefore needs a fresh shear/bearing calculation; it is not a strength approval. An 18×24 base taper extending through X=-7..0 would overlap the rotor's working X envelope and alter the stop contact angle, so do not use that larger transition without recomputing the stop motion. An alternative is a separate captured key and a base-down pad, at the cost of another small printed part.
