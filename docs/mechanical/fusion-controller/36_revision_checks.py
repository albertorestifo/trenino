import adsk.core as C, adsk.fusion as F, math, json, os
ROOTDIR='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller'
OUT=ROOTDIR+'/inventory-support-free-revision'

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
 clashes=[]
 def check(a,b,label):
  if not overlap(a[2],b[2]):return
  q=tm.copy(a[2]);assert tm.booleanOperation(q,b[2],F.BooleanTypes.IntersectionBooleanType)
  v=q.volume*1000 if q.isValid and q.faces.count else 0
  if v>.01:clashes.append({'pose':label,'a':a[1],'b':b[1],'overlap_mm3':v})
 current=[v for v in items if not v[0].startswith(('P08 Cam 3','P08 Cam 5','REFERENCE Stock spring'))]
 for i,a in enumerate(current):
  for b in current[i+1:]:check(a,b,'neutral')
 mainpre=('P05','P06','P07','P09','P10','P18','P19','P28','HARDWARE Main shaft','HARDWARE Grip M3','HARDWARE Cam M3','HARDWARE Compact sensor clamp','HARDWARE Rotor clamp','HARDWARE Shaft joining')
 forkpre=('P11','HARDWARE 623ZZ','HARDWARE Roller axle')
 fixed=[v for v in items if not v[0].startswith(mainpre+forkpre+('P08','REFERENCE Stock spring'))]
 main=[v for v in items if v[0].startswith(mainpre)];fork=[v for v in items if v[0].startswith(forkpre)]
 angles=[-52]+list(range(-50,51,5))+[52]
 for n in [3,5,7]:
  cam=next(v for v in items if v[0].startswith('P08 Cam '+str(n)))
  for deg in angles:
   beta=math.degrees(-.5*1.4*(1-math.cos(2*math.pi*(math.radians(deg)+math.radians(50))/math.radians(100/(n-1))))/35)
   moved=[];fm=[]
   for source,target,m in [(main+[cam],moved,rotation(deg,(0,0,6.5))),(fork,fm,rotation(beta,(0,-3.5,1.2)))]:
    for name,bn,body in source:
     q=tm.copy(body);tm.transform(q,m);target.append((name,bn,q))
   for a in moved:
    for b in fixed+fm:check(a,b,'cam%d angle%d'%(n,deg))
   for a in fm:
    for b in fixed:check(a,b,'cam%d follower%d'%(n,deg))
 # Nominal cam extraction with follower held five degrees down.
 servicefixed=[v for v in items if not v[0].startswith(('P08','REFERENCE Stock spring','HARDWARE Cam M3')+forkpre)]
 for v in fork:
  q=tm.copy(v[2]);tm.transform(q,rotation(-5,(0,-3.5,1.2)));servicefixed.append((v[0],v[1],q))
 for n in [3,5,7]:
  cam=next(v for v in items if v[0].startswith('P08 Cam '+str(n)))
  for dx in [0,5,10,15,20,25,30,35,40]:
   q=tm.copy(cam[2]);m=C.Matrix3D.create();m.translation=C.Vector3D.create(dx/10,0,0);tm.transform(q,m)
   for b in servicefixed:check((cam[0],cam[1],q),b,'service cam%d shift%d'%(n,dx))
 report={'document':app.activeDocument.name,'unhealthy_features':health,'solid_count':len(items),'sampled_angles':angles,'cam_profiles':[3,5,7],'neutral_and_motion_clashes':clashes,'tolerance_mm3':.01,'scope':'Solid interference; spring deformation, actual sensor dimensions, fastener torque, physical strength and fixed mesh frame are separate checks.'}
 with open(OUT+'/clearance-check.json','w') as f:json.dump(report,f,indent=2)
 print(json.dumps({'unhealthy':health,'clash_count':len(clashes),'clashes':clashes[:30],'report':OUT+'/clearance-check.json'}))
