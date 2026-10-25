import pathlib,json,sys,hashlib,zipfile,xml.etree.ElementTree as E
r=pathlib.Path('docs/mechanical/fusion-controller/gear-comparison');sys.path.insert(0,str(r.parent/'inventory-support-free-revision/.validation-libs'))
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
ns={'m':'http://schemas.microsoft.com/3dmanufacturing/core/2015/02'};layout=[]
for p in sorted((r/'plates').glob('*.3mf')):
 with zipfile.ZipFile(p) as z:
  assert z.testzip() is None;tree=E.fromstring(z.read('3D/3dmodel.model'))
 boxes=[]
 for ob in tree.findall('.//m:object',ns):
  vv=np.array([[float(v.get(k)) for k in ['x','y','z']] for v in ob.findall('.//m:vertex',ns)]);mn=vv.min(axis=0);mx=vv.max(axis=0)
  assert min(mn)>=-1e-6 and max(mx[:2])<246 and mx[2]<250
  for a,b in boxes:assert any(mx[i]+7.99<=a[i] or b[i]+7.99<=mn[i] for i in [0,1]),p.name
  boxes.append((mn,mx))
 layout.append(dict(file=p.name,objects=len(boxes),bounds_and_spacing_pass=True))
assert sum(x['objects'] for x in layout)==28
(r/'plate-layout-check.json').write_text(json.dumps(layout,indent=2))
clear=json.loads((r/'clearance-check.json').read_text());assert clear['document'].endswith('v3') and not clear['neutral_and_motion_clashes']
files=list((r/'stl').glob('*.stl'))+list((r/'plates').glob('*.3mf'))
for n in ['PRINT-README.md','VALIDATION.md','COMPARISON-PLAN.md','COMPARISON-RESULTS.csv','PINION-INDEX.svg','Geared-Lever-Print.f3d','geared-v3-overview.png','mesh-check.json','connectivity-check.json','native-health.json','clearance-check.json','gear-profile-check.json','plate-manifest.json','plate-layout-check.json','layer-check.json','plate-layer-check.json']:
 files.append(r/n)
hashes={p.relative_to(r).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(r/'delivery-hashes.json').write_text(json.dumps(hashes,indent=2));files.append(r/'delivery-hashes.json')
out=r/'Geared-Lever-v3-Print-Geometry.zip'
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
 for p in files:z.write(p,p.relative_to(r))
with zipfile.ZipFile(out) as z:
 assert z.testzip() is None
 for name,h in hashes.items():assert hashlib.sha256(z.read(name)).hexdigest()==h
print(json.dumps({'archive':str(out),'bytes':out.stat().st_size,'stl_count':len(rows),'plates':layout,'zip_and_hash_check':'passed'}))

