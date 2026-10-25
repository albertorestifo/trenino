from pathlib import Path
import json,zipfile,hashlib
R=Path('docs/mechanical/fusion-controller')
h=json.loads((R/'native-health.json').read_text());assert not h['modified'] and not h['nonhealthy_features'] and h['features']==342
with (R/'VALIDATION.md').open('a') as f:f.write('\nFinal native save: **AIDesignedLever v3**,342 healthy features,3 revolute joints,2 rigid groups; no unsaved changes. Twelve redundant no-target cut operations were removed. Exact BRep intersection checks showed zero symmetric difference for all three affected solids, so the prior print/sweep evidence remains applicable (timeline-cleanup.json).\n')
(R/'SOURCE-NOTES.md').write_text('''# Native model and source notes\n\nOpen Fusion-Train-Controller.f3d in Autodesk Fusion. The live cloud document was saved as AIDesignedLever v3. The geometry is native sketch/extrude/revolve feature history, with342 healthy features and separately named components. Grounded exact-frame mesh reference is not a printed part.\n\nThe supplied Python scripts document construction and checks through the installed Fusion MCP. They use absolute paths from the development workspace; adjust ROOTDIR and exec(open(...)) paths before regeneration. They are not intended to be rerun on the completed document. Regeneration starts from a new empty Hybrid Design and uses this order:01,02,03,04,05,06,07,09,10,11,13,14,19,20,22,17,24. Scripts08,12,15,21,23 inspect geometry;16,18,25 export/capture. common.py supplies geometry helpers. The source contains deliberate incremental corrections; the final native archive is the easiest editable starting point.\n\nPrint the oriented STL files in the order in ASSEMBLY-AND-PRINT-GUIDE.md.27 files include3 cam alternatives and2 coupling-disc fits; select one of each. Do not print the entire assembly or metal frame. No generated printer G-code is included.\n''')
files=[R/'Fusion-Train-Controller.f3d',R/'fixed-frame-reference.3mf',*R.glob('*.md'),R/'fusion-overview.png',R/'fusion-closeup.png',*sorted((R/'stl').glob('*.stl'))]
for n in ['export-manifest','print-orientation','mesh-check','slice-report','neutral-validation','motion-3','motion-5','motion-7','final-targeted-checks','service-path','cam-contact-check','native-health','timeline-cleanup']:files.append(R/(n+'.json'))
files += [R/'common.py',*sorted(R.glob('[0-9][0-9]_*.py')),R/'orient_meshes.py',R/'check_meshes.py',R/'check_contact.py',R/'rail_depth.py']
records={str(p.relative_to(R)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(R/'SHA256.json').write_text(json.dumps(records,indent=2));files.append(R/'SHA256.json')
out=R/'Fusion-Controller-Prototype-Package.zip'
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
 for p in files:z.write(p,str(p.relative_to(R)))
with zipfile.ZipFile(out) as z:
 assert z.testzip() is None
 assert len([n for n in z.namelist() if n.endswith('.stl')])==27
 assert not any('gcode' in n.lower() for n in z.namelist())
p=Path('docs/superpowers/plans/2026-10-24-fusion-controller.md');p.write_text(p.read_text().replace('- [ ]','- [x]'))
print(json.dumps({'package':str(out.resolve()),'files':len(files),'size_mb':round(out.stat().st_size/1e6,2),'document':h['document'],'features_healthy':h['features']}))
