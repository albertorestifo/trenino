# Controller Detent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add interchangeable push-through cam detents to the existing Onshape train controller.

**Architecture:** A permanent handle hub carries a removable cam sector between the two existing support plates. A new frame-mounted, spring-loaded roller arm engages its perimeter. Preserve the frame and potentiometer drive; do not reuse the failed follower prototype.

**Tech Stack:** Onshape parametric parts and assembly; physical prototype for force and wear validation.

**Spec:** User-approved proposal in this chat, 2026-10-24, including the requirement that the cam fit between the existing frames and permission to increase its diameter.

## Global Constraints

- Cam must fit between the two existing support plates.
- Preserve the existing frame and functioning potentiometer drive.
- Notches are push-through, with no release lock.
- Existing follower is a failed prototype, not a design constraint.
- Profile exchange must not require disturbing the pivot or gear calibration.
- No manufacturing dimensions are approved until measured against the source geometry.

## Observed Source Geometry

Document: https://cad.onshape.com/documents/b8296e54dd613316c44885e0/w/c3ae9023e20b2a467edaad8c/e/057930f0a7dfbdf60640e60e

The Holder Frame base sketch visibly dimensions a 146 mm span and a 90 mm span, with a 3 mm material-thickness parameter. These do not establish the axial clearance between the plates. The Gears studio lists module-1 48T and 24T gears. Variable Studio lists DegreesOfFreedom = 140 as a number; its meaning and actual assembly travel remain unverified.

## Review Focus

- Axial interference: check the entire cam, retainers, roller and arm against both plates.
- Sweep interference: check every permitted lever position against the frame, gears and handle.
- Contact geometry: check roller-radius compensation and contact through each valley and ridge.
- Spring travel: maintain preload at valleys without coil bind at ridges; avoid binding spring seats.
- Service and overload: cam removal must preserve calibration; independent stops take end loads.

## Task 1: Establish the measured envelope

- [x] Inspect the assembly and relevant part studios.
- [x] Read visible frame sketch dimensions.
- [ ] Measure inside plate spacing, bearing bosses, hub and gear axial stack, pivot diameter and grip moment arm.
- [ ] Confirm assembled lever limits and potentiometer electrical/mechanical travel at the 2:1 ratio.
- [ ] Record a coordinate system and reserved cam/follower envelope.

## Task 2: Create the hub and removable cam

- [ ] Create a new detent part studio, preserving existing parts.
- [ ] Model a permanent hub with concentric locating shoulder and asymmetric angular indexing.
- [ ] Model a radially removable sector retained by accessible captive screws; locate torque through positive features.
- [ ] Create a three-notch prototype profile with ordinary-neutral-ordinary positions.
- [ ] Generate the contact profile from the roller-centre motion using the chosen arm geometry.
- [ ] Verify axial clearance, full sweep, fastener access and removal path.

## Task 3: Create the follower assembly

- [ ] Model a rigid bracket attached to the existing extrusion or a bridge between supports.
- [ ] Model a new arm with pivot and roller axle supported on both sides.
- [ ] Select roller, pivot hardware and guided compression spring after sizing loads.
- [ ] Add a preload adjuster, locking feature and a roller-retraction service position.
- [ ] Check all travel for positive contact, spring-seat articulation and coil-bind clearance.

## Task 4: Integrate and validate

- [ ] Add independent hub-to-frame travel stops.
- [ ] Assemble and verify motion and interference throughout the permitted range.
- [ ] Produce dimensioned parts, hardware list and prototype instructions.
- [ ] Measure grip breakaway force in both directions, settling, overshoot and potentiometer repeatability on a physical prototype.
- [ ] Compare profile variants before selecting spring preload and releasing full train-specific profiles.

## Current Status

Implemented a working FeatureScript and dedicated Cam Detent — prototype Part Studio (element bbcf27a4742cd8b0e198ae72). The actual plate gap is 43.5 mm; the 8 mm sector lies at z32..40 mm. Source frame/gear/handle/assembly geometry remains unchanged. 3/5/7-notch layouts, forked roller follower, thrust-seat spring adjustment, indexed removable sector and independent stops are modeled. Sampled motion checks passed for all three layouts at 1 mm lift; a sampled neutral sector removal path also passed. See docs/mechanical/README.txt for exact checks and limits, source CAD and remaining hardware/full-assembly integration tasks. Do not mark Task 4 complete: complete drivetrain collision checks, hardware detailing and physical force/wear tests remain.
