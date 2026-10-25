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
 mainpre=('P05','P06','P07','P09','P10','P18','P19','P28','HARDWARE Main shaft','HARDWARE Grip','HARDWARE Cam','HARDWARE Compact sensor clamp','HARDWARE Sensor clamp','HARDWARE Rotor clamp','HARDWARE Shaft')
 forkpre=('P11','HARDWARE 623ZZ','HARDWARE Roller axle')
 fixed=[v for v in items if not v[0].startswith(mainpre+forkpre+('P08','REFERENCE Stock spring'))]
 main=[v for v in items if v[0].startswith(mainpre)];fork=[v for v in items if v[0].startswith(forkpre)]
 angles=sorted(set([-52,-51,-50,50,51,52]+list(range(-45,46,5))))
 for n in [3,5,7]:
  cam=next(v for v in items if v[0].startswith('P08 Cam '+str(n)))
  for deg in angles:
   beta=math.degrees(-.5*1.4*(1-math.cos(2*math.pi*(math.radians(deg)+math.radians(50))/math.radians(100/(n-1))))/35)
   moved=[];fm=[]
   for source,target,m in [(main+[cam],moved,rotation(deg,(0,0,3))),(fork,fm,rotation(beta,(0,-3.5,-2.3)))]:
    for name,bn,body in source:
     q=tm.copy(body);tm.transform(q,m);target.append((name,bn,q))
   for a in moved:
    for b in fixed+fm:check(a,b,'cam%d angle%d'%(n,deg))
   for a in fm:
    for b in fixed:check(a,b,'follower cam%d angle%d'%(n,deg))
   open(OUT+'/motion-progress.json','w').write(json.dumps({'cam':n,'angle':deg,'clashes':len(clashes)}))
 # Existing direct-drive cam service removes the sensor carriage/coupling first.
 removed=('P08','P16','P18','P19','REFERENCE Measured','REFERENCE Stock spring','HARDWARE Pot','HARDWARE Compact carriage','HARDWARE Compact sensor clamp','HARDWARE Sensor clamp','HARDWARE Cam')
 servicefixed=[v for v in items if not v[0].startswith(removed+forkpre)]
 for v in fork:
  q=tm.copy(v[2]);tm.transform(q,rotation(-4,(0,-3.5,-2.3)));servicefixed.append((v[0],v[1],q))
 for n in [3,5,7]:
  cam=next(v for v in items if v[0].startswith('P08 Cam '+str(n)))
  for dx in [0,5,10,20,40,60]:
   q=tm.copy(cam[2]);m=C.Matrix3D.create();m.translation=C.Vector3D.create(dx/10,0,0);tm.transform(q,m)
   for b in servicefixed:check((cam[0],cam[1],q),b,'cam service%d shift%d'%(n,dx))
 report={'document':app.activeDocument.name,'unhealthy':health,'angles':angles,'cams':[3,5,7],'clashes':clashes,'tolerance_mm3':.01,'service':'Remove sensor carriage and floating coupling, retain follower at -4 degrees, remove cam screws, withdraw cam +X. Spring preload and holding method require care; no new service-pin device included.'}
 open(OUT+'/motion-check.json','w').write(json.dumps(report,indent=2));print(json.dumps({'clashes':len(clashes),'examples':clashes[:15]}))
