import pathlib,json,sys,hashlib,zipfile,xml.etree.ElementTree as E
r=pathlib.Path('docs/mechanical/fusion-controller/raised-wide-travel');sys.path.insert(0,str(r.parent/'inventory-support-free-revision/.validation-libs'))
import trimesh,numpy as np
rows=[]
for p in sorted((r/'stl').glob('*.stl')):
 m=trimesh.load_mesh(p,process=False);m.vertices=np.round(m.vertices,4);m.merge_vertices();parent=list(range(len(m.vertices)))
 def root(i):
  while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
  return i
 for a,b,c in m.faces:parent[root(b)]=root(a);parent[root(c)]=root(a)
 n=len(set(root(i) for i in range(len(parent))));deg=int(np.sum(m.area_faces<1e-10))
 assert n==1 and deg==0 and m.is_watertight,(p.name,n,deg)
 rows.append(dict(file=p.name,shells=n,degenerate_faces=deg,watertight=bool(m.is_watertight)))
(r/'connectivity-check.json').write_text(json.dumps(rows,indent=2))

files=list((r/'stl').glob('*.stl'))+[r/n for n in ['Raised-Wide-Travel.f3d','DESIGN-NOTES.md','VALIDATION.md','rail-mounted-layout.png','mechanism-detail.png','native-health.json','mesh-check.json','connectivity-check.json','clearance-check.json','alternative-cam-check.json','final-bridge-check.json','stop-check.json','cam-profile-check.json','gear-profile-check.json','clamp-sector-check.json','layer-check.json','selected-slice-report.json']]
hashes={p.relative_to(r).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(r/'delivery-hashes.json').write_text(json.dumps(hashes,indent=2));files.append(r/'delivery-hashes.json')
archive=r/'Raised-Wide-Travel-Geometry.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for p in files:z.write(p,p.relative_to(r))
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 for n,h in hashes.items():assert hashlib.sha256(z.read(n)).hexdigest()==h
print(json.dumps({'archive':str(archive),'meshes':len(rows),'bytes':archive.stat().st_size,'verification':'passed'}))
