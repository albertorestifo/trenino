# Validation of direct-pot v8 upgrade

Saved Fusion document: AIDesignedLever v8, version 8, unmodified after save. The native archive and two new exported meshes match this revision. 508 native features are healthy.

- Neutral assembly: no detected solid intersections above 0.01 mm3, including nominal frame envelopes.
- Operating motion: 37 sampled angles through +/-52 degrees using the nine-notch cam; no detected interference. All nine gates and inter-gate crests are represented.
- Cam removal: six sampled withdrawal positions after removing the sensor carriage/coupling and clearing the follower; no detected interference.
- Shaft/bush assembly: 295 sampled positions, no detected interference using the documented assembly order.
- Exported cam contact: 1,041 positions at 0.1 degree increments; worst numerical penetration 0.00138 mm and maximum gap 0.00034 mm, within 0.01 mm allowance. Source profile is a valid polygon. Nine stable gates are prescribed; center at zero, Emergency at +50 degrees.
- All ten release meshes (eight required and two optional) are closed, consistently wound, positive-volume, single connected shells. Six required and two optional correction meshes are reused byte-for-byte from the previously checked package; new shaft and cam are newly exported.
- New shaft and cam are oriented on broad flat bed faces. Diagnostic slices retain the selected P2S 0.4 / Standard 0.20 mm / PLA Basic / Supertack defaults. Zero support extrusion segments. See FDM review for localized bridging review.

These are geometric and print-path checks, not proof of continuous collision freedom, material strength, wear life or detent force. The spring rate and solid height remain unmeasured. Retain the previous limited preload and verify spring clearance, free movement and pot stop margin physically. The positive tongue extension restores the 8 mm contact arm but does not restore symmetric contact.

The existing Bambu command-line profile still reports nozzle_volume_type and T65535 configuration errors despite writing diagnostic layers. No G-code or diagnostic machine project is included in the release. Import the supplied millimetre STLs into your normal Bambu Studio project and slice there.
