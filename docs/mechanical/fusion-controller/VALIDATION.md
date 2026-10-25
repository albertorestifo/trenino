# Validation — compact lever v6

25 October 2026. Final cloud state: AIDesignedLever v6, saved, unmodified. Native archive refreshed after save. Two revolute inspection joints and two rigid groups; these do not solve spring/contact physics.

| Check | Result and limit |
|---|---|
| Native history | Zero unhealthy features at final save/export (`saved-state.json`). |
| Motion | Prior final-geometry check: zero solid clashes >0.01 mm³ at 23 angles for each of 3/5/7 cams; service withdrawal sampled 0–40 mm. No CAD geometry was changed during final delivery. Sampling is not a continuous contact proof. |
| Mesh | 30 closed, consistently wound positive-volume meshes; scale matches native bounds within 0.05 mm; each has bed contact and fits within 250 mm per axis. Edge matching uses 0.0001 mm rounding for numerical STL vertices. |
| Connectivity | One connected component per file at the declared tolerance. Collapsed-at-tolerance triangles are reported, not repaired or silently deleted. |
| Slicing | 30/30 CLI jobs exit zero and produce extrusion layers; no generated support segments. Selected first/bridge/final layers plus critical roofs inspected in `layer-review/`. |
| Toolpaths | NOT released for printing: nozzle-volume metadata error and T65535 diagnostic persist. Re-slice geometry in GUI with selected defaults. |
| Print quality/strength | Unproven physically. No printer run, measured load or durability test. |
| Inventory | Recorded stock sufficient, zero shortages, but estimated counts and five physical requirements remain unresolved. |

Mesh hashes are in `mesh-check.json`; native and release hashes are in `delivery-hashes.json`. `layer-check.json` reports maximum individual bridge-designated path lengths, not unsupported spans: these include top skins over sparse infill. The disc's actual groove span is 4.2 mm; its closure at Z3.0 mm bridges between its two bed-supported halves.

Visual inspection confirmed assembled rail mounting and the compact sensor arrangement. The unchanged frame is reference geometry; the solid collision report excludes fixed mesh-frame intersection. Nominal rail-web clearance is derived from the retained frame dimensions, not measured installed hardware. Neighbor pitch must add operating/cable clearance to the 125.5 mm module envelope, and service needs lateral access.

The digital design is delivered as a prototype. Remaining physical requirements are documented in the assembly guide and Maker Inventory draft. Earlier validations and custom slicing settings are preserved under `historical-v5-docs/` and must not be substituted for this revision.
