import pathlib,json,hashlib,zipfile,shutil,struct,collections
R=pathlib.Path(__file__).parent;P=R.parent
old=R/'historical-v5-docs';old.mkdir(exist_ok=True)
for name in ['ASSEMBLY-AND-PRINT-GUIDE.md','VALIDATION.md','SESSION-HANDOFF.txt']:
 if (P/name).exists() and not (old/name).exists():shutil.copy2(P/name,old/name)
checks=[]
for p in sorted((R/'stl').glob('*.stl')):
 data=p.read_bytes();n=struct.unpack_from('<I',data,80)[0];parent={};degenerate=0
 def find(a):
  parent.setdefault(a,a)
  while parent[a]!=a:parent[a]=parent[parent[a]];a=parent[a]
  return a
 for i in range(n):
  v=struct.unpack_from('<12fH',data,84+50*i);ps=[tuple(round(x,4) for x in v[j:j+3]) for j in [3,6,9]]
  if len(set(ps))<3:degenerate+=1
  for q in ps[1:]:parent[find(q)]=find(ps[0])
 count=len({find(a) for a in parent});checks.append({'file':p.name,'connected_components_at_0_0001mm':count,'collapsed_faces_at_tolerance':degenerate})
 assert count==1,(p.name,count)
(R/'connectivity-check.json').write_text(json.dumps(checks,indent=2))
guide='''# Compact stock-based lever — Fusion v6

Saved 25 October 2026 as **AIDesignedLever v6** in Admin Project. Use `inventory-support-free-revision/Inventory-Compact-Lever.f3d` and that folder's `stl/`. Earlier STL folders and custom 3MF projects are historical and do not describe this revision.

## Changes

The fixed 640 × 190 × 110 mm 2020 frame is retained. The shaft incorporates the input coupling tongue; one floating disc and one split sensor clamp replace the former separate input hub and two-piece output clamp. Including the mount, sensor-drive printed parts fall from five to three. The sensor-side envelope shrinks 13.85 mm; allowing for the stocked cap-head hardware on the opposite side, overall width falls about 12.5 mm, to 125.5 mm. This is an envelope, not a guaranteed installation pitch: leave clearance for hands, wires and service access. Cam withdrawal requires 40 mm on the sensor side; slide a neighboring module away for servicing.

Stock M3 screws and inserts replace long bolts, M4 hardware and guide tubes. Two 623ZZ bearings replace the printed roller and sleeve. A captured two-piece printed pivot replaces the long metal pivot; no stock metal needs cutting. The main shaft is also split longitudinally for printing, joined with two screws and two loose keys.

## Hardware for one lever

| Item | Quantity | Use / inventory evidence |
|---|---:|---|
| M3 × 8 cap screw | 3 | Shaft halves 2, retaining cap 1 |
| M3 × 10 cap screw | 3 | One selected cam |
| M3 × 12 cap screw | 4 | Sensor carriage 2, spring cup guides 2 |
| M3 × 16 cap screw | 2 | Rotor clamp 1, sensor clamp 1 |
| M3 × 20 cap screw | 10 | Crossblock 4, grip 2, stops 2, bearing axle 1, preload 1 |
| M3 plain nut | 3 | Stops 2, bearing axle 1 |
| CNC Kitchen standard M3 × 5.7 mm insert | 19 | Stock count 100 known; nominal 4 mm pilot |
| M5 × 14 DIN912 screw | 4 | Rail mounts; no spacer/washer stack |
| M5 compatible drop-in 2020 T-nut | 4 | Fit/engagement needs physical confirmation |
| 623ZZ bearing, 3 × 10 × 4 mm | 2 | Follower roller pair |
| Spring, 1 mm wire × 9 mm OD × 20 mm free | 1 | Rate and solid height unmeasured |
| RK097 A10K potentiometer | 1 | Body/shaft envelope provisional |
| Potentiometer mounting nut/washer | supplied set assumed | Not confirmed in inventory; unresolved |

The M3 kit lists 20 of each required length and 160 plain nuts. Inventory records show sufficient quantities for all seven BOM lines; six stock counts are estimates. No stock was checked out. The [Maker Inventory draft](http://home-server.local:8765/projects/7446736d-7df8-4d5f-8011-98605b239ae4) retains unresolved requirements. Do not interpret recorded sufficiency as a physical recount or confirmation of the supplied potentiometer nut/washer.

## Printing

There are 30 oriented STL files, including three alternative cams. Print one cam, giving 28 printed pieces for one assembly. Print both P05 shaft halves, both P25/P26 pivot halves, both P27 sleeves and both P28 keys. Obsolete P12/P17/P20 are absent intentionally. Keep the supplied orientation and mm scale; see `PRINT-ORIENTATIONS.md` for each file.

Select Bambu Lab P2S 0.4 nozzle, standard flow; Bambu PLA Basic @BBL P2S; 0.20mm Standard @BBL P2S; SuperTack plate. Preserve those defaults: 2 walls, 15% infill, supports disabled, automatic brim behavior and default bridge speed. No process or filament tuning was applied. These are dimensional prototype settings, not a validated structural rating.

All 30 parts generated extrusion layers without support paths. Selected first, bridge and final layers and critical hole/roof layers were inspected. Flat split faces, teardrop roofs, ramped bearing pads and grip roofs avoid the original large unsupported features. The disc deliberately bridges its 4.2 mm lower groove. Short circular insert-hole roofs remain bridges to preserve insert retention. Print small fits first and inspect bridge sag, especially the disc, follower and insert seats.

The CLI logs contain `nozzle_volume_type not found` and `Invalid T command (T65535)` even though slicing exits zero. Therefore **no printer-ready G-code is released**. Import the oriented STLs into a fresh Bambu Studio project, select the profiles above and slice there; do not print the diagnostic files. No print was sent or started.

Print order: bushes, shaft halves/keys, cap and spacers; disc and clamp; pivot halves, follower and guide sleeves; structural plates, crossblock and rotor; one cam; cup/collar and grips. Test these mating groups before printing every large part.

## Assembly and service

1. Install the 19 inserts while their entry faces are accessible. Use controlled heat and test the nominal 4 mm bore in the actual filament. Insert locations include the two shaft joining screws and three underside crossblock pockets. Install the two plain stop nuts before closing inaccessible joints.
2. Fit the two P28 alignment keys and assemble P05 halves using two M3 × 8 screws. Check that the seam closes flush. Fit bushes, thrust spacers, rotor and retaining cap. Keep nominal 0.3 mm rotor end float; do not crush the shaft to remove clearance. Fit the rotor clamp.
3. Assemble the two 623ZZ bearings between the follower pads with the M3 × 20 axle and plain nut. Pads should bear only on inner races; confirm both outer rings spin freely after tightening. Assemble the two pivot halves through the follower and spacers; trap their ends in the blind plate seats as the plates and crossblock are brought together. A plate must be released to remove the captive pivot.
4. Fit the crossblock with four M3 × 20 screws. Fit the cup with the two printed 6 mm guide sleeves and M3 × 12 guide screws into the underside inserts. Confirm free sliding. Install spring, 1 mm collar and M3 × 20 preload adjuster. Begin with minimum preload.
5. Attach one cam with three M3 × 10 screws. Attach grip halves with two recessed M3 × 20 screws; install the M3 × 20 stop cores and nuts. Mount to the rails using four M5 × 14 screws and T-nuts, without the former washer stacks. Modeled head seat Z64 and tip Z50 leave 1.2 mm to the nominal extrusion web at Z48.8. Check actual T-nut engagement and absence of bottoming.
6. Center the lever and sensor electrically/mechanically. Fit disc onto the integrated tongue and clamp the sensor shaft using P19 and one M3 × 16 screw. Secure the pot to the replaceable sliding panel using its assumed supplied mounting hardware. Tighten accessible clamp hardware before fixing the carriage with two M3 × 12 screws. Adjust so tongues remain engaged without bottoming. Nominal face gaps are 0.65 mm and groove-end gaps 0.45 mm; preserve the shaft's end float. The provisional sensor is Ø6 mm shaft, M7 bushing, 12 mm exposed shaft; seller '15 mm shaft' is not a verified datum.
7. Move slowly through ±52° before powering. Structural stops must engage before sensor stops. Check all three gate profiles if printing them; calibrate firmware endpoints and reversal play after fitting the selected cam. Wiring and connector routing are not modeled.
8. For cam changes, remove its screws, back off the adjuster, hold the follower approximately 5° down and withdraw the cam 40 mm sideways. Backing off the adjuster does not fully unload the captive spring. For unloaded service, restrain the cup and release the guide hardware carefully before removing the spring.

## Assumptions to test physically

Spring solid height is assumed at most 14 mm. Nominal installed length is 17 mm and estimated shortest operating length 15.2 mm with the permitted extra preload. The 1 mm collar limits adjustment but cannot guarantee no coil bind for an unmeasured spring. Rate, hand force and service force are unknown; the previous candidate's force estimates do not apply.

The printed shaft and pivot have not been load- or fatigue-tested and are not claimed equivalent to metal. Verify their stiffness, seam retention, insert retention and creep at low preload first. Verify pot dimensions and supplied nut/washer, bearing-pad clearance, actual stock counts and rail hardware engagement before treating the assembly as complete. Physical proof of support-free print quality remains a prototype test.
'''
(P/'ASSEMBLY-AND-PRINT-GUIDE.md').write_text(guide,encoding='utf-8')
(R/'ASSEMBLY-AND-PRINT-GUIDE.md').write_text(guide,encoding='utf-8')
mesh=json.loads((R/'mesh-check.json').read_text())
orient='# Print orientations — v6\n\nKeep these orientations when arranging parts. All dimensions in mm. No generated supports; short bridges require fit inspection.\n\n| File | Bed face | Size X × Y × Z | Bed area mm² |\n|---|---|---|---:|\n'
for r in mesh:orient+=f"| {r['file']} | {r['orientation']} | {' × '.join(f'{x:.2f}' for x in r['size_mm'])} | {r['bed_area_mm2']:.2f} |\n"
(R/'PRINT-ORIENTATIONS.md').write_text(orient,encoding='utf-8')
validation='''# Validation — compact lever v6

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
'''
(P/'VALIDATION.md').write_text(validation,encoding='utf-8');(R/'VALIDATION.md').write_text(validation,encoding='utf-8')
handoff='''CURRENT: 25 October 2026 — AIDesignedLever v6, saved/unmodified in Fusion Admin Project.
Work completed here directly, without further agents.
Native: inventory-support-free-revision/Inventory-Compact-Lever.f3d
Geometry: inventory-support-free-revision/stl/ (30 files, 3 alternative cams; print one)
Read ASSEMBLY-AND-PRINT-GUIDE.md and VALIDATION.md for current instructions.
All meshes closed/consistent/on bed; all 30 diagnostic slices generated layers without supports.
No printer-ready G-code: CLI metadata/T65535 errors unresolved. Re-slice STLs in GUI using selected defaults.
No print started and no inventory checked out. Physical stock recount, sensor fit/supplied mounting hardware, spring solid height/rate and printed structural strength remain unresolved.
Previous handoff preserved under inventory-support-free-revision/historical-v5-docs/.
Do not rerun incremental Fusion mutation scripts 33–40. Final geometry already exists in v6.
'''
(P/'SESSION-HANDOFF.txt').write_text(handoff,encoding='utf-8')
(R/'FRESH-TASK-HANDOFF.md').write_text('# Current status\n\n'+handoff+'\n\nHistorical investigation detail: INVESTIGATIONS.md.\n',encoding='utf-8')
files=[R/'Inventory-Compact-Lever.f3d',R/'ASSEMBLY-AND-PRINT-GUIDE.md',R/'VALIDATION.md',R/'PRINT-ORIENTATIONS.md',R/'assembly-overview.png',*sorted((R/'stl').glob('*.stl'))]
with zipfile.ZipFile(R/'Compact-Lever-v6-Geometry.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in files:z.write(p,p.relative_to(R))
files.append(R/'Compact-Lever-v6-Geometry.zip')
(R/'delivery-hashes.json').write_text(json.dumps({str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2))
print(json.dumps({'single_component_meshes':len(checks),'collapsed_triangles_at_tolerance':sum(r['collapsed_faces_at_tolerance'] for r in checks),'release_files':len(files),'archive_bytes':(R/'Compact-Lever-v6-Geometry.zip').stat().st_size}))
