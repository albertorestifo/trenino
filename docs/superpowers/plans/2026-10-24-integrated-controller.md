# Integrated printed controller implementation plan

Goal: complete the controller mechanism around the original 48:24 gear pair and frame plates, supported by the existing 2020 extrusion rails. Integrate the lever stem with the main gear and provide a printed shaft and removable railway-style palm grip.

Final architecture: 12 mm D-shaft with 9.2 mm journals, replaceable printed bushings, direct three-screw main-gear/carrier connection, interchangeable cam sectors, sleeved double-cheek follower, captured spring cup with limited preload adjustment, and steel-reinforced end stops. Broad printable support plates attach directly to the 2020 rails. Original frame plates remain, repositioned to a 64.5 mm outer span. The original native Full device assembly is preserved.

- [x] Audit original frame seats, gear ratio, source and lever attachment.
- [x] Create separate integrated FeatureScript and assembled Part Studio.
- [x] Implement initial FDM and mechanical review feedback.
- [x] Resolve modeled clashes and verify three maximum-lift cam profiles at 53 sampled positions; check 41 cam-removal positions.
- [x] Add rounded split palm grip after resolving mechanics.
- [x] Export 22 oriented printable parts in three groups; verify closed connected meshes and build volume.
- [x] Generate slicer output for all 22 parts and document print order/BOM.
- [x] Complete final independent FDM and mechanical review; reverse preload nut entry to retain spring reaction and enable M07 supports. Targeted CAD checks pass; final S03 export/slice validation recorded in reviewed-print.

Limits: assembled Part Studio is not a native mated Assembly. Actual potentiometer body, actual T-nuts, physical spring properties, printed fit, strength and tactile feel require bench checks. Slicer CLI preset diagnostics prevent release of ready-to-run G-code; geometry only is distributed. No automatic printer jobs.
