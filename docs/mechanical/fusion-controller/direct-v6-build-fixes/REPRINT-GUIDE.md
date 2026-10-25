# Direct-pot v6: build corrections and reprints

This revision updates the direct-drive design you built. It retains the original shaft/coupling system and 104-degree mechanical travel, with its pivot lowered 35 mm to match the geared design's Z30 height. Rail mounting seats remain unchanged. The top panel is outside this revision.

## Required replacements

| Part | Prints | Reason |
|---|---:|---|
| P01 left plate | 1 | Recessed mounting towers and support-free stepped stop counterbores |
| P02 right plate | 1 | Recessed towers, shorter pot supports and captive carriage nuts |
| P04 right bush | 2 halves | Fits radially around the existing shaft; no need to force it over the shoulder |
| P13 spring reaction block | 1 | Bottom preload reaction nut, accessible guide/mount nuts, stepped pocket bridges |
| P19 sensor clamp | 1 | Accessible captive nut replaces the insert; coupling faces retained |

Six required prints. Use the supplied orientations: both P04 halves stand on their flange faces, with the journal bore vertical. Existing P16 mount and P18 floating disc are reused: move P16 inward 3.2 mm, fully against the shortened support ends. The shorter support positions the measured 8 mm moving pot shaft for 7.7 mm nominal engagement, leaving 0.3 mm between the hub and stationary M7 bushing. Confirm these gaps physically and allow the floating disc to slide freely.

## Optional replacements

If existing inserts hold securely, reuse your shaft, rotor and grip. The optional folder provides two P05 shaft halves and one P07 rotor with nut fasteners, plus one P09 grip half with tighter 3.8 mm insert bores and 0.2 mm lead-in chamfers. Reprint an optional part if its insert retention is inadequate or you want the nut conversion. Do not mix one revised shaft half with one original half: use the optional pair together.

The P09 insert dimensions are a fit trial responding to insufficient melt engagement, not a measured printer correction. Test a small pocket coupon in the same material before committing to the grip. P09 retains inserts because a nut behind its socket with the existing screws would leave a thin loaded wall.

## Hardware changes

Required replacements use ten additional standard M3 hex nuts: two carriage, four crossblock mounts, two guide screws, one preload and one sensor clamp. Optional shaft and rotor add seven more: shaft joining 2, shaft cap 1, cam 3 and rotor clamp 1. Reuse the existing screw lengths, bearings, spring, pot, M5 rail screws and T-nuts. Nominal nut model 5.5 mm across flats x 2.4 mm thick; check actual stock. Maker Inventory records 160 M3 nuts in the existing kit, but current remaining count is estimated and the build has not been checked out.

## Assembly changes

1. Back off preload and restrain/remove the spring before disassembly. Keep the unchanged printed parts and hardware labeled.
2. Install P13 mount nuts from the top, guide nuts through the rear slots, and preload nut from the bottom. The preload nut bears on its upper pocket shoulder; guide nuts bear on their lower shoulders. Do not reverse these load paths.
3. If using optional P05, place the shaft-cap nut between the halves before closing them. Load joining nuts through their underside slots, refit alignment keys and join with the existing M3x 8 screws. Tighten gently against the printed seats.
4. Strip the shaft of its cap, rotor and thrust spacers first. Slide empty P02 onto the shaft from the LEFT end, across the central D section; hold it 40 mm left of its final position so its sensor arms end before the right journal. Place both P04 halves radially on the right journal, then slide P02 RIGHT onto their cylindrical bodies until its outer face meets their flange. Fit the right thrust spacer, rotor, left spacer, preassembled P03-in-P01 pair and retaining cap from the left. The bush flange prevents approaching it with P02 from the right; follow this order. Do not enlarge the running bore to pass the shoulder.
5. Secure P13 and complete the retained follower/cup/guide assembly. Nut pockets must contain their nuts before access is closed. Check the guide cup slides freely and the preload screw actually bears on the cup.
6. Fit the two P02 carriage nuts from the shortened support ends before installing P16. Refit P16 inward 3.2 mm; align its existing slots with the new carriage bolt centers. Install P19's nut from the top before mounting the clamp. Center the pot electrically/mechanically before tightening its shaft clamp.
7. Mount on the original top rails. Check the lowered mechanism and wiring clear the frame. Turn through the full travel gently and verify stops act before the pot's own limits.

Optional P07 cam nuts load from the rotor's rear. They resist rotation but can slide out axially when screws are removed; retain them with a finger during cam changes. The rotor clamp nut loads from its side pocket before assembly.

## Print and commissioning notes

The stepped counterbore/nut-pocket reliefs are intentional bridge geometry. Do not add support automatically or remove the small steps from CAD. Default printer/material/process profiles remain unchanged; inspect the slicer preview and clear only any sag or burr that impedes screw seating.

Check actual spring solid height, free guide motion, nut retention, low-force lever travel, pot clearance and reversal play. The narrow wall beside P13's outer guide nut is a lightly loaded guide restraint; avoid overtightening. Digital checks do not establish strength or a torque rating.

Final validation results and exact file lists are provided separately. No printer-ready G-code is supplied while the existing CLI reports invalid tool configuration.
