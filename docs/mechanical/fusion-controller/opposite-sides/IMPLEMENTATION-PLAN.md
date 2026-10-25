# Opposite-side lever implementation plan

> Execute directly in this session using the executing-plans workflow. Reviewers advise; the primary agent owns all Fusion edits.

**Goal:** Put serviceable detents outside the left plate and the geared pot outside the right, with continuous structural plates and a narrower internal stack.

**Architecture:** Retain unchanged grip, follower, gear profiles and fixed frame. Rebuild plates, shaft, rotor, cam carrier, stops and cassette as native components. Keep assembly transforms separate from print orientations.

**Tech stack:** Fusion Python API, existing local construction helpers, Python mesh/geometry checks, Bambu default-profile slicing.

**Spec:** DESIGN.md, with review dispositions taking precedence over the initial draft.

## Constraints and review focus

- Modify current geared lineage peR4meb5QLiO5tE5ANITQg; leave v6 lineage 2iFF2PJAQnO13x73oN2c-w untouched.

- No top panel, cut metal stock, changed slicer profiles or invented measured spring/pot specifications.

- Retain frame, pivot Z30, pot axis Z-15.15, ratio -2, ±60 stops and 3/5/7/8 cams.

- Verify shaft/bush insertion, positive stop load paths, service-pin/spring clearance, hardware tool access, and support-free layer continuity.

## Tasks

- [x] Write entire design before editing Fusion; dispatch independent mechanical and FDM reviews.

- [x] Resolve review blockers in REVIEW-DISPOSITION.md and update dimensional specification before first mutation.

- [x] `01_structure.py`: replace plates, crossbraces and positive-location stops. Preserve frame. Verify single solid per printed part, bearings/rail positions and health.

- [x] `02_rotating.py`: shortened split shaft, clean rotor and separate carrier; retain gear profiles, relocate gear hardware and rebuild cams for outward screw access. Verify assembly stack and keyed interfaces.

- [x] `03_detent_sensor.py`: captured follower cassette, spring reaction block, absolute-angle service pin, narrow pot panel, moved unchanged follower/cup/guide hardware. Verify placement after all modeling and save a snapshot.

- [x] `04_validate.py`: neutral hardware and full moving sweep, cam gates/crests, ±60 stop contacts/overtravel, cassette/service paths, sensor adjustment extremes, assembly/driver paths. Record limits of unmeasured hardware.

- [x] `05_export.py` plus mesh/orientation checks: native archive, actual CAD images, mm STLs, connected watertight meshes with appropriate bed contact. Slice changed geometry using existing defaults and inspect layers; do not release invalid G-code.

- [x] Update assembly/service/print guide, exact BOM and measured envelope comparison. Save and verify active document; deliver evidence and physical commissioning limits.

## Execution ledger

2026-10-25: Initial draft complete, two independent reviewers running, no CAD edits yet. User explicitly authorizes implementation after specialist review; no additional permission gate is needed. Existing project scripts and CAD document are the working location; no repository branch or new CAD comparison copy is needed.

2026-10-25: Structure and rotating stages completed with healthy native feature reports. Both exceeded the300s tool timeout but subsequently wrote completion evidence; no duplicate mutations were sent. Stage03 running. Shaft joining holes move from±8 to±7.5 for insert edge wall; source02 creates original positions and stage03 moves the six sketch circles and hardware. Rotor nose-root trimming in stage03 resolves early stop contact. Detailed actual clearance checks remain pending.


2026-10-25: Completed final geometry, independent review dispositions, motion regressions, native save/export, all 35 mesh and default-profile slice checks, illustrated guide and package. FINAL-DESIGN.md and VALIDATION.md supersede provisional dimensions and pending statements in this chronological ledger. No printer G-code is released.
