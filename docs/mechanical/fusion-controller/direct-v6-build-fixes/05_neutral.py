import adsk.core as C, adsk.fusion as F, math, json, os
ROOTDIR='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller'
OUT=ROOTDIR+'/direct-v6-build-fixes'

def overlap(a,b):
 aa=a.boundingBox;bb=b.boundingBox
 return all(min(x,y)>max(z,w)+1e-8 for x,y,z,w in zip(aa.maxPoint.asArray(),bb.maxPoint.asArray(),aa.minPoint.asArray(),bb.minPoint.asArray()))

def rotation(deg,center):
 m=C.Matrix3D.create();m.setToRotation(math.radians(deg),C.Vector3D.create(1,0,0),C.Point3D.create(*center));return m

def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent;tm=F.TemporaryBRepManager.get();items=[];health=[]
 for o in root.allOccurrences:
  for f in o.component.features:
   if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState:health.append([o.component.name,f.name,f.errorOrWarningMessage])
  for b in o.component.bRepBodies:
   assert b.isSolid and b.isValid,b.name
   items.append((o.component.name,b.name,tm.copy(b.createForAssemblyContext(o))))
 # Nominal rail envelopes from each retained extrusion mesh; slot engagement excluded.
 for occ in root.occurrences:
  if not occ.component.name.startswith('REFERENCE - fixed'):continue
  for k,mesh in enumerate(occ.component.meshBodies):
   bb=mesh.boundingBox;lo=[round(v,2) for v in bb.minPoint.asArray()];hi=[round(v,2) for v in bb.maxPoint.asArray()]
   ob=C.OrientedBoundingBox3D.create(C.Point3D.create(*[(a+b)/2 for a,b in zip(lo,hi)]),C.Vector3D.create(1,0,0),C.Vector3D.create(0,1,0),hi[0]-lo[0],hi[1]-lo[1],hi[2]-lo[2])
   items.append(('FRAME ENVELOPE '+str(k),'FRAME ENVELOPE '+str(k),tm.createBox(ob)))
 clashes=[]
 def check(a,b,label):
  if a[0].startswith('FRAME') and b[0].startswith(('FRAME','HARDWARE Rail')):return
  if b[0].startswith('FRAME') and a[0].startswith('HARDWARE Rail'):return
  if not overlap(a[2],b[2]):return
  q=tm.copy(a[2]);assert tm.booleanOperation(q,b[2],F.BooleanTypes.IntersectionBooleanType)
  v=q.volume*1000 if q.isValid and q.faces.count else 0
  if v>.01:clashes.append({'pose':label,'a':a[1],'b':b[1],'overlap_mm3':v})
 current=[v for v in items if not v[0].startswith(('P08 Cam 3','P08 Cam 5','REFERENCE Stock spring'))]
 for i,a in enumerate(current):
  for b in current[i+1:]:check(a,b,'neutral')
 report={'document':app.activeDocument.name,'unhealthy':health,'clashes':clashes,'solid_count':len(items)}
 open(OUT+'/neutral-check.json','w').write(json.dumps(report,indent=2));print(json.dumps(report))
