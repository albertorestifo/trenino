# Inventory-backed support-free lever revision

> Execution: parent agent performs Fusion changes; three requested agents investigate inventory, coupling and FDM. Use executing-plans with native CAD validation.

## Goal and design
Adapt the existing AIDesignedLever v5 to stocked hardware, reduce sensor-side width and printed part count, and remove generated support requirements through geometry and orientation. Preserve fixed frame, independent structural stops, cam profiles and shaft axis. Native v5 backup and baseline are in `docs/mechanical/fusion-controller/inventory-support-free-revision/`.

User authorized redesign and parent Fusion implementation. User ruled out cutting tube and authorized assumptions for unmeasured spring. No stock checkout or printer operation is authorized. Default slicer profiles remain unchanged. The mechanical model is a prototype, not physical validation.

## Decisions
- Use available M3 screw lengths (6/8/10/12/16/20), M3 plain nuts, CNC Kitchen standard M3 inserts, M5x14 and matching stocked 2020 nuts. Estimated stock and kit quantities remain qualified.
- Replace long pivot bolt and metal tube with a printed axle captured in blind plate pockets. Split axle lengthwise to print on broad flat faces. Assembly requires releasing a structural plate; preserve positive retention after rail/crossblock assembly.
- Replace unavailable roller sleeve with two stocked 623ZZ bearings retaining the original 10 mm contact diameter. Integral fork pads contact only inner races.
- Replace M4 preload hardware and long guide bolts with M3 hardware and shorter accessible insert-mounted guides. Use stocked OD9/free20/wire1 spring provisionally; limit compression and record assumed solid height/rate separately from inventory facts.
- Compact Oldham: integrate input tongue into P05, retain floating disc, replace two sensor clamp halves with one split clamp, shorten adjustable mount. This accommodates alignment error better than a rigid direct socket. Deep nested/flexural coupling could save more width but introduces less predictable polymer flexure and sensor-loading risks.
- Split main shaft lengthwise at Y=0, flat faces on bed, retain round bearing surfaces. Recess M3 joining screws inside the original shaft envelope. Preserve clamp/socket interfaces and verify seam alignment.
- Use roof reliefs on horizontal clearance holes, short bridges where suitable, and chamfers instead of unsupported ledges. Insert pockets retain nominal round 4 mm seating geometry; do not indiscriminately teardrop a precision insert seat.

## Work and acceptance checks
- [x] Inspect live document, save recoverable v5 native archive and measured baseline; no unhealthy features found.
- [ ] Reconcile inventory report into final hardware map with real UUIDs and explicit estimated/unresolved entries.
- [ ] Modify hardware interfaces and reference envelopes. Verify screw engagement, access, retained pivot, rail tip clearance and spring working/service travel.
- [ ] Modify coupling and shaft. Verify part count, axial width, face gaps, misalignment travel, sensor adjustment and structural stop independence.
- [ ] Apply per-part support-free geometry/orientation changes. Verify bed contact, closed solid/mesh topology, fit bounds, bridging and layer continuity.
- [ ] Audit all native features and affected neutral/motion/service clearances. Preserve original cam contact geometry; sample both operating extremes and service pose.
- [ ] Save native model/archive, regenerate affected STL exports into a revision-specific directory, update assembly/BOM/orientation/evidence documents. Clearly distinguish geometry checks from actual slicing and physical proof.

## File scope and execution ledger
New incremental scripts `33_inventory_interfaces.py`, `34_compact_coupling.py`, `35_support_free_geometry.py`, and validation/export scripts live under `docs/mechanical/fusion-controller/`. Existing v5 exports remain recoverable; new revision exports use a separate folder. No software code, Git cleanup or unrelated files are in scope.

Baseline failures are evidenced by v5 hardware names (M3x25/35/80, M4x25, unavailable sleeves), five sensor-drive printed parts, and documented support-required orientations. Native validation will check actual final geometry instead of mock API tests.

Ruling: Use the existing active CAD document and native archive checkpoint rather than a Git worktree; Fusion state is external to Git and user requested direct modification. No automatic commits.
