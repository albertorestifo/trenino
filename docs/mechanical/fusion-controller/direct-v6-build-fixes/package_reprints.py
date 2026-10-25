from pathlib import Path
import json,sys,shutil,hashlib,zipfile
r=Path(__file__).parent
sys.path.insert(0,str(r.parent/'inventory-support-free-revision/.validation-libs'))
import trimesh,numpy as np
manifest=json.loads((r/'export-manifest.json').read_text())
required={'P01','P02','P04','P13','P19'};optional={'P05','P07','P09'}
rows=[];files=[]
for item in manifest:
 prefix=item['file'][:3]
 if prefix not in required|optional:continue
 category='required-stl' if prefix in required else 'optional-stl'
 src=r/'stl'/item['file'];folder=r/category;folder.mkdir(exist_ok=True);dest=folder/src.name;shutil.copyfile(src,dest)
 m=trimesh.load_mesh(dest,process=False);m.vertices=np.round(m.vertices,4);m.merge_vertices()
 assert m.is_watertight and m.is_winding_consistent and m.volume>0,src.name
 assert np.min(m.area_faces)>1e-10,src.name
 parent=list(range(len(m.vertices)))
 def root(i):
  while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
  return i
 for a,b,c in m.faces:parent[root(b)]=root(a);parent[root(c)]=root(a)
 assert len(set(root(i) for i in range(len(parent))))==1,src.name
 rows.append({'file':dest.relative_to(r).as_posix(),'category':category,'component':item['component'],'watertight':True,'single_shell':True,'size_mm':m.extents.tolist(),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()});files.append(dest)
assert sum(x['category']=='required-stl' for x in rows)==6
assert sum(x['category']=='optional-stl' for x in rows)==4
(r/'reprint-manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
baseline=json.loads((r/'baseline.json').read_text());reuse=[]
for c in baseline:
 if not c['name'].startswith('P') or c['name'][:3] in required|optional:continue
 final=[x for x in manifest if x['component']==c['name']]
 assert len(final)==len(c['bodies']),c['name']
 for b,f in zip(c['bodies'],final):
  assert abs(b['volume']*1000-f['volume_mm3'])<1e-5,c['name']
  assert max(abs(a-bb) for aa,bb0 in zip(b['bounds'],f['bounds_mm']) for a,bb in zip(aa,bb0))<1e-5,c['name']
 reuse.append({'component':c['name'],'reuse':True,'evidence':'No shape edits; matching native bounds and volume. Assembly translation is excluded.'})
(r/'reuse-check.json').write_text(json.dumps(reuse,indent=2),encoding='utf-8')
if '--check-only' in sys.argv:print(json.dumps({'required':6,'optional':4,'reused_components':len(reuse)}));raise SystemExit
names=['Direct-Pot-Recessed-Build-Fixes.f3d','REPRINT-GUIDE.md','DESIGN.md','VALIDATION.md','ONE-PIECE-SHAFT.md','MECHANICAL-REVIEW.md','FDM-REVIEW.md','reprint-manifest.json','reuse-check.json','native-health.json','neutral-check.json','motion-check.json','assembly-path-check.json','slice-report.json','layer-check.json','insert-fit-changes.json','rail-mounted-layout.png','mechanism-detail.png']
files +=[r/n for n in names]
hashes={p.relative_to(r).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(r/'delivery-hashes.json').write_text(json.dumps(hashes,indent=2));files.append(r/'delivery-hashes.json')
zpath=r/'Direct-Pot-v6-Reprint-Upgrade.zip'
with zipfile.ZipFile(zpath,'w',zipfile.ZIP_DEFLATED) as z:
 for p in files:z.write(p,p.relative_to(r))
with zipfile.ZipFile(zpath) as z:
 assert z.testzip() is None
 for n,h in hashes.items():assert hashlib.sha256(z.read(n)).hexdigest()==h
print(json.dumps({'package':str(zpath),'required':6,'optional':4,'bytes':zpath.stat().st_size,'integrity':'passed'}))
