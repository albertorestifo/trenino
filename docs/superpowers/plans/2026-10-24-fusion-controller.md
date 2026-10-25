# Fusion controller implementation plan

Goal: build improved direct-drive train controller in native Fusion within fixed 2020 frame.
Architecture: rail-mounted flat plates, independently supported shaft/rotor, replaceable cam and roller follower, adjustable isolated RK097 adapter.
Tech stack: Fusion MCP Python API plus computer use, local mesh/slicer verification.
Spec: docs/mechanical/fusion-controller/DESIGN.md

- [x] Extract exact frame reference and build fixed cartridge supports, bushes and shaft. Verify frame dimensions and mount interfaces.
- [x] Build lever/rotor, removable endpoint-notched cams and grip. Verify print layers, retention and envelope.
- [x] Build double-supported follower, captured spring/preload and independent end stops. Check sampled motion and load paths.
- [x] Build replaceable RK097 mount and floating coupling, label assumed sensor dimensions.
- [x] Add assembly motion/clearance checks, export oriented parts and native Fusion archive; inspect UI.
- [x] Validate meshes/slices, complete final specialist reviews and implement findings; deliver BOM/print order.

Review focus: layer strength/overhangs, retained nuts and insertion access, spring preload/solid height, free bearing rotation/axial play, sensor compatibility/travel and assembly service access.
