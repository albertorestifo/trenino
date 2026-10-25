import adsk.core as C,adsk.fusion as F,math,json
OUT='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/recessed-bottom-sensor'
def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);r=d.rootComponent;tm=F.TemporaryBRepManager.get();items=[]
 assert app.activeDocument.dataFile.id=='urn:adsk.wipprod:dm.lineage:8phaaOK2S5SnbORU7BqJyQ'
 for o in r.allOccurrences:
  if o.component.name.startswith(('P08 Cam 3','P08 Cam 5','REFERENCE Stock spring')):continue
  for b in o.component.bRepBodies:items.append((o.component.name,tm.copy(b.createForAssemblyContext(o))))
 clashes=[];checks=0
 def check(a,b,pose):
  nonlocal checks
  if a[0]==b[0]:return
  aa=a[1].boundingBox;bb=b[1].boundingBox
  if not all(min(x,y)>max(z,w)+1e-8 for x,y,z,w in zip(aa.maxPoint.asArray(),bb.maxPoint.asArray(),aa.minPoint.asArray(),bb.minPoint.asArray())):return
  q=tm.copy(a[1]);assert tm.booleanOperation(q,b[1],F.BooleanTypes.IntersectionBooleanType);checks+=1
  v=q.volume*1000 if q.isValid and q.faces.count else 0
  if v>.01:clashes.append({'pose':pose,'a':a[0],'b':b[0],'volume_mm3':v})
 changed=[a for a in items if a[0].startswith(('P01R','P02R','G03R','REFERENCE Locomotive'))]
 for a in changed:
  for b in items:check(a,b,'neutral final mount')
 panel=next(a for a in items if a[0].startswith('REFERENCE Locomotive'))
 handle=[a for a in items if a[0].startswith(('P07','P09','P10','HARDWARE Grip'))]
 for deg in [-52,-45,-30,-15,0,15,30,45,52]:
  m=C.Matrix3D.create();m.setToRotation(math.radians(deg),C.Vector3D.create(1,0,0),C.Point3D.create(0,0,1.8))
  for a in handle:
   q=tm.copy(a[1]);tm.transform(q,m);check((a[0],q),panel,'panel sweep '+str(deg))
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in r.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 report={'document':app.activeDocument.name,'unhealthy':bad,'exact_intersections':checks,'clashes':clashes,'panel_pose_degrees':[-52,-45,-30,-15,0,15,30,45,52],'gear_top_z_mm':49.25,'panel_underside_z_mm':55,'scope':'Final changed mounts and panel: neutral exact intersections and sampled panel travel. Existing recessed mechanism report covers operating motion; frame rail-slot engagement is assessed dimensionally, not as solid interference.'}
 open(OUT+'/hanging-validation.json','w').write(json.dumps(report,indent=2));print(json.dumps(report))
