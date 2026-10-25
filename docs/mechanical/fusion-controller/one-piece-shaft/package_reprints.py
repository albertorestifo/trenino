from pathlib import Path
import sys,json,shutil,hashlib,zipfile
r=Path(__file__).parent;base=r.parent/'direct-v6-build-fixes'
sys.path.insert(0,str(r.parent/'inventory-support-free-revision/.validation-libs'))
import trimesh,numpy as np
files=[];rows=[]
for category,sources in [('required-stl',list((base/'required-stl').glob('*.stl'))+list((r/'stl').glob('*.stl'))),('optional-stl',[p for p in (base/'optional-stl').glob('*.stl') if p.name.startswith(('P07','P09'))])]:
 (r/category).mkdir(exist_ok=True)
 for p in sources:
  dest=r/category/p.name;shutil.copyfile(p,dest);m=trimesh.load_mesh(dest,process=False);m.vertices=np.round(m.vertices,4);m.merge_vertices()
  assert m.is_watertight and m.is_winding_consistent and m.volume>0,p.name
  assert np.min(m.area_faces)>1e-10,p.name
  parent=list(range(len(m.vertices)))
  def root(i):
   while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
   return i
  for a,b,c in m.faces:parent[root(b)]=root(a);parent[root(c)]=root(a)
  assert len(set(root(i) for i in range(len(parent))))==1,p.name
  rows.append({'file':dest.relative_to(r).as_posix(),'watertight':True,'single_shell':True,'size_mm':m.extents.tolist(),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()});files.append(dest)
assert len(rows)==10,len(rows)
(r/'reprint-manifest.json').write_text(json.dumps(rows,indent=2))
if '--check-only' in sys.argv:print('10 printable files checked');raise SystemExit
names=['Direct-Pot-One-Piece-Shaft.f3d','REPRINT-GUIDE.md','DESIGN.md','VALIDATION.md','MECHANICAL-REVIEW.md','FDM-REVIEW.md','FDM-FINAL-CHECK.json','reprint-manifest.json','native-health.json','neutral-check.json','motion-check.json','assembly-path-check.json','slice-report.json','layer-check.json','cam-profile-check.json','native-cam-contact-check.json','rail-mounted-layout.png','mechanism-detail.png','Class323-cam-diagram.svg']
files +=[r/n for n in names]
hashes={p.relative_to(r).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(r/'delivery-hashes.json').write_text(json.dumps(hashes,indent=2));files.append(r/'delivery-hashes.json')
zpath=r/'Direct-Pot-One-Piece-Class323-Upgrade.zip'
with zipfile.ZipFile(zpath,'w',zipfile.ZIP_DEFLATED) as z:
 for p in files:z.write(p,p.relative_to(r))
with zipfile.ZipFile(zpath) as z:
 assert z.testzip() is None
 for n,h in hashes.items():assert hashlib.sha256(z.read(n)).hexdigest()==h
print(json.dumps({'package':str(zpath),'required':8,'optional':2,'bytes':zpath.stat().st_size,'integrity':'passed'}))
