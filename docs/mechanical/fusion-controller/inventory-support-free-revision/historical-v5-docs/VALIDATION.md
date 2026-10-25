# Current support-reduction revision - 2026-10-25

Saved native document: AIDesignedLever v5, 396 healthy features, 3 revolute joints, 2 rigid groups, no unsaved changes. Fusion-Train-Controller.f3d is refreshed.

- Geometry changed only in P09/P10 (45-degree socket roofs) and P17 (45-degree flange ramp, preserved clamp holes/split, washer relief). Existing mount parts P01/P02/P25/P26 and their print project are unchanged.
- P19/P20 now print axial end down. Both P18 disc variants retain geometry and bridge their grooves without supports.
- 53 poses from -52 to +52 degrees: no changed-part overlap above 0.01 mm3 against static assembly; changed-part neutral checks against the full solid assembly also pass. See support-revision/clearance-check.json. This is a targeted check, not a new full cam/contact validation.
- All 29 final STL files pass the mesh checks: one connected closed manifold, consistent winding, positive volume, bed at zero, correct P2S bounds. See mesh-check.json.
- Seven objects sliced in Bambu Studio 2.4.0.70 without support toolpaths. GUI layer preview checked first-layer contact/brims, short-width groove bridges at layer14 and grip roof progression at layer169. P2S 0.4 standard flow, SuperTack, Bambu PLA Basic, 0.2 layers, 5 walls, 35% gyroid, 5 mm outer brim, 25 mm/s bridges. Final estimate 1h57m37s, 55.39g. Both P18 alternatives included; assemble only one. See support-revision/print-check.json.
- No printer command was sent. Files are prepared locally only. The separate sliced archive is a prototype print, not evidence of physical fit, bridge sag, insert retention, strength or fatigue.
- P05 and P11 retain local supports; P13 retains supports around insert bores rather than thinning the surrounding walls. P07 guidance now calls for local support inspection at its lug/insert features. Those parts are not included on the seven-part plate.

The native-change-check.json records the first modeling stage before the small P17 washer-relief correction. The final clearance report, native archive, STL manifest and print-check hashes reflect the correction. Earlier evidence below is historical and applies only where its geometry and scope remain unchanged.

# Fusion controller validation and release evidence

The exact original 640 x190 x110mm frame was retained as grounded mesh reference. Native printed components and hardware envelopes are separately named. Three revolute joints and two rigid groups assist inspection; they do not solve spring/contact dynamics.

| Check | Result | Evidence |
|---|---|---|
| Neutral assembly | No unintended overlap above0.01mm�; intended cam/roller numerical contact0.000634mm� | neutral-validation.json |
| 3/5/7 cam travel | 53 poses each over +/-52deg, no overlap above0.01mm� against components and conservative frame envelopes | motion-3/5/7.json |
| Revised rotor/coupling and spring fixtures | 27 rotor poses, follower operating/service positions, +/-1mm preload, tight-disc neutral fit: pass | final-targeted-checks.json |
| Cam service | Depressed follower, sideways cam extraction0..40mm in5mm steps: pass | service-path.json |
| Profile/roller contact |159 poses, maximum absolute gap/penetration below0.0013mm | cam-contact-check.json |
| Printing meshes |27 single connected manifold meshes, correct winding, bed atZ0, P2S fit | mesh-check.json |
| Slicing |27 successful layer generations,12 with normal supports | slice-report.json |
| Expert review |One final FDM and one final mechanical review; findings implemented and targeted checks completed | FINAL_FDM_REVIEW.md; FINAL_MECHANICAL_REVIEW.md |

The insert relocation, rotor clamp, reduced coupling clearance, rail spacer stack and spring-loaded service procedure are the principal review-driven changes. The guide contains the print and assembly sequence and complete hardware list.

The geometry package deliberately excludes generated G-code. Bambu Studio CLI2.4.0.70 reported preset metadata/nozzle-volume and invalid-tool-command diagnostics despite generating layers successfully. Re-slice supplied oriented STLs using the user's installed P2S printer profile; inspect supports before printing.

Physical fit, sensor range, coupling reversal play, T-nut engagement, spring force/solid height and fatigue life are prototype checks. RK097 dimensions remain assumptions until measured; the mount and shaft clamps are replaceable.

Final native save: **AIDesignedLever v3**,342 healthy features,3 revolute joints,2 rigid groups; no unsaved changes. Twelve redundant no-target cut operations were removed. Exact BRep intersection checks showed zero symmetric difference for all three affected solids, so the prior print/sweep evidence remains applicable (timeline-cleanup.json).

## Mount-access revision - final current geometry

Supersedes earlier mount and hardware evidence where affected. AIDesignedLever v4:389 healthy features, no unsaved changes. Printed changes are P01/P02 plus new P25/P26;29 exported printable files total. mount-access-check.json reports no clashes above0.01 mm3 over23 operating poses, rail screw/spacer insertion positions, driver envelopes and stop nut insertion positions. mount-neutral-validation.json retains only the previous numerical cam/roller contact overlap0.000634 mm3. All29 meshes pass closed-solid/winding/connectivity/build-envelope checks. Bambu Studio GUI sliced only the four changed parts successfully; changed-parts-print-check.json records the final project settings and hashes. Historical specialist reviews apply to their earlier revision; no new specialist review is claimed. Physical prototype fit, actual T-nut thread engagement and strength still require checking.
