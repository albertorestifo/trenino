# Independent mechanical review — opposite-side design

25 October 2026. AI mechanical specialist review of DESIGN.md before CAD implementation; not a licensed engineering certification. Read-only review of the design and existing local construction scripts. No Fusion changes made by this reviewer.

## Verdict

The opposite-side arrangement is a sound direction: continuous bearing plates, a separately accessible detent cam, and a sensor below the main shaft. Proceed to implementation after the blocking dispositions below are incorporated. Dimensions and physical strength remain subject to the stated CAD and prototype tests; this review does not certify an 8 Nm rating.

## Blocking findings and agreed dispositions

### M1 — right bush cannot be installed by the drafted sequence

An unsplit 12.3 mm bore bush cannot pass the integral 20 mm right shoulder or the central 16 mm section. The statement that bushes slide from the left is therefore incorrect for the right bush. Assembling shaft halves inside the bush could work but complicates an avoidable problem.

**Accept proposed correction:** omit the right integral 20 mm shoulder. Extend the 8 mm D drive from X25.35 to36.35, retaining the gear at X28.5..36.5 using an assembly positioning gauge. Right bush then enters from the right; left bush from the left; rotor enters from the left before the left bush. The central 23.6 mm raised section against the 24 mm inner bush-face spacing controls nominal end float at0.4 mm. Include rotor/spacers in that stack, since either can become the limiting contact. Do not allow the left carrier to become a competing thrust clamp: original0.3 mm flange gap can fall to0.1 mm with nominal shaft movement, before tolerances. Increase or locally relieve that gap, targeting at least0.6 mm at nominal centered position, or document measured selective fitting. Check gear alignment at both axial limits.

### M2 — service release requires fixed position and preload backoff

The original5-degree release raises the spring tail by20 sin5°=1.743 mm. With17 mm initial spring length and1 mm additional preload, service length becomes14.257 mm, leaving just0.257 mm above the assumed14 mm solid height. An additional5 degrees from an operating crest can be worse. The unknown spring cannot be declared safe from coil bind.

**Accept proposed correction:** fixed absolute -4-degree service position, fully backed-off preload, retained by a removable printed4 mm pin through the outer support into the follower tail. From the nominal pose, tail lift=20 sin4°=1.395 mm, spring length=15.605 mm, roller withdrawal=35 sin4°=2.441 mm. Pin center approximately Y-54.9513,Z-21.6049; corresponding moving tail hole has nominal Y-55,Z-23. Minimum shank length is12.2 mm for4 mm support +0.2 mm gap +8 mm engagement. Provide a positive head/removal tab, tapered lead-in, and clearance appropriate to a printed removable pin. It is a service tool, removed before operation.

Confirm actual roller-to-cam gap at this fixed pose for all profiles; target at least0.5 mm. Document a tool-assisted way to rotate the follower and insert the pin, then remove the tool before extracting the cam. Document complete spring unloading separately; backoff of a1 mm preload adjustment alone does not remove the nominal3 mm initial spring compression. Verify spring pilots do not collide at release and that pin cannot be accidentally left in place unnoticed.

### M3 — single retained stop pad needs a positive load path

The original round stop pad attached only by an M3 insert relies on face friction, screw shear and insert prying. A flat face against a plate does not by itself transfer tangential force without slip.

For the specified circles: angular offset18.92464 degrees, pad centers Y±36.31089,Z22.89230. The contact-force moment arm about the main shaft is27.6923 mm, not30 mm. An8 Nm stop torque produces approximately288.9 N contact force;16 Nm produces577.8 N. Contact near the rotor's axial center can produce several Nm of pad-root bending.

**Accept proposed correction with qualification:** add a concentric12 mm locating spigot to each pad, engaging a12.3 mm pocket in P01; circular is adequate because force on the circular pad passes through its center. Shorten pad outer extent toX0 if full7 mm axial overlap with the rotor is retained. A3 mm spigot gives nominal projected bearing stress288.9/(12×3)=8.0 MPa; prefer5 mm depth where feasible, giving4.8 MPa and7 mm remaining plate thickness. These are average geometric stresses, not material allowables and not proof of durability. M3 retains the pad while the spigot transfers shear; it still participates in resisting prying.

Ensure blind screw clearance extends beyond tipX-4. If the insert enters at spigot tipX-15, pocket depth must be at least11.5 mm; if atX-17, at least13.5 mm. Do not reuse a6.8 mm blind hole that bottoms the M3x20. Include installed insert diameter in spigot wall checks. Test exact stop onset and the complete pad/socket envelope against the rotor before accepting the larger locating feature. Prove stop stiffness physically with gradual loading; do not describe hand-force assumptions as a certified rating.

## Additional implementation requirements

1. **Carrier clamp:** dimension its radial screw seat, insert and screw-tip relief explicitly. A10 mm screw reaching a flat nearY4.8 requires its head seat nearY14.8; a nominal radius14 hub alone may require a small local boss. Include at least supplier wall around the4.6 mm insert and check the cap insert/split-plane interaction. The keyed bore alone has clearance and cannot promise no perceptible reversal movement.
2. **Carrier clearance:** verify the hub, fan and cam together at full rotation. The fan must avoid follower cheeks and support posts; nominally moving the whole follower preserves its original contact geometry, but it does not prove the new carrier hub fits. Cam screws atR36 need the original cam hole pattern verified, including3 mm recessed head depth and driver access at the reference pose.
3. **Follower pivot:** the two captured ends are preferable to a cantilevered M3 pivot. The nominal blind seat-bottom spacing is25.2 mm while the24.9 mm axle leaves0.3 mm total end clearance, consistent with a captured but unclamped axle. Outer support/spacer fasteners must seat against rigid spacers, not clamp the moving fork. Verify the 4 mm outer plate around its2 mm blind pivot seat and screw counterbores is continuous.
4. **Spring block:** two screws at the same Z do not remove outboard bending; the broad block-to-plate bearing face is essential. Inspect full insert length and screw-tip clearance, plus pilot/cup motion. No guessed spring rate should be written into inventory as measured data.
5. **Sensor:**240 degrees of pot travel is required for120-degree lever movement, before a margin. Mechanical/electrical travel and terminal envelope are still unmeasured. Keep this explicit commissioning gate and center the pot before attaching its pinion. Test stops with sensor detached first. A10K marking is not evidence of linear taper.
6. **Service pitch:**87.2 mm is an operating-envelope estimate, not a service pitch. Side removal may require loosening/sliding neighboring modules on the rail or removing the entire module. The guide must state this instead of implying in-place access in a tightly packed bank.
7. **Hardware:**18 M3x20 screws per new assembly nearly exhaust the20-per-length kit before v6 is considered. Separate stock can cover demand only if head form and remaining counts are compatible. Count the final modeled fasteners and record estimated inventory status.

## Sensitivity checks and practical limits

For spring stiffness k=2/5/10 N/mm, nominal3 mm compression gives6/15/30 N spring force. The follower's35 mm roller arm and20 mm tail arm give approximate roller force(20/35)Fs=3.43/8.57/17.14 N near nominal. Pivot reaction is approximately(1+20/35)Fs=9.43/23.57/47.14 N because spring and cam push downward on opposite lever arms. At the proposed backed-off service position, compression4.395 mm gives8.79/21.98/43.95 N spring force; the service pin must carry that force locally without relying on friction. These are sensitivity examples only.

At nominal3 mm spring compression with k10, external cam radial load about17.1 N atX-37 versus left-bearing centerX-18 gives approximately326 Nmm outboard bending moment. At4.8 mm compression, roller load rises to27.4 N and moment to521 Nmm. Shaft bending and D-flat stress require actual-section assessment; gross circular section values overestimate the split, drilled shaft. End-stop torque should pass rotor-to-stop-to-plate, not through the external detent or sensor drive.

The narrowed bearing span reduces main-shaft bending deflection for centered transverse load, but creates no general strength guarantee: stop reactions, outboard follower loads, drilled shaft sections, FDM seams and layer adhesion dominate different cases. Do not substitute a successful interference check for load or wear testing.

## Required evidence after implementation

- Exact neutral and full-motion interference checks with complete hardware, all cam options, pin installed only in service pose, spring/cup motion and pot adjustment extremes.
- Stop clearance at±60 and contact immediately beyond it; no premature stem/hub/crossblock contact.
- Bearing insertion, rotor insertion, shaft joining screw access, carrier clamp access and cap insert installation sequence demonstrated.
- Cam screw driver cylinders and extraction through20 mm checked; include neighbor restriction explicitly.
- Axial end-float stack and gear-face overlap at both limits, plus final operating envelope including protruding heads and leads.
- Physical first-build checks for bushing fit, spring coil clearance, pot travel, stop deflection, clamp reversal play and repeated notch wear. Only then compare performance and ease of assembly with preserved v6.

Review status: **conditionally accepted for CAD implementation after M1–M3 and the explicit carrier clamp/service geometry are resolved in the design disposition.** No requirement for another review round for routine dimension refinement; escalate only a materially changed mechanism or unresolved blocking condition.
