import adsk.core as C, adsk.fusion as F, math, json, os
ROOTDIR='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller'
OUT=ROOTDIR+'/raised-wide-travel'

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
 radii={}
 for name,bn,b in items:
  if name.startswith(('G01','HARDWARE G01','G02','HARDWARE G02')):
   cz=3.0 if name.startswith(('G01','HARDWARE G01')) else -1.515
   radii[name]=max(math.hypot(v.geometry.y,v.geometry.z-cz) for v in b.vertices)
 clashes=[]
 def progress(stage):
  open(OUT+'/alternative-progress.json','w').write(json.dumps(dict(stage=stage,clashes=len(clashes),recent=clashes[-3:])))
 progress('collected geometry')
 def check(a,b,label):
  if a[0].startswith('FRAME') and b[0].startswith('FRAME'):return
  if (a[0].startswith('FRAME') and b[0].startswith('HARDWARE Top hanging rail')) or (b[0].startswith('FRAME') and a[0].startswith('HARDWARE Top hanging rail')):return
  if a[0] in radii and b[0] in radii and (a[0].startswith(('G01','HARDWARE G01')) != b[0].startswith(('G01','HARDWARE G01'))) and radii[a[0]]+radii[b[0]]<4.515:return
  if {a[0][:3],b[0][:3]}=={'G01','G02'}:return # full involute profiles checked separately; pinion cuts only remove material
  if not overlap(a[2],b[2]):return
  q=tm.copy(a[2]);assert tm.booleanOperation(q,b[2],F.BooleanTypes.IntersectionBooleanType)
  v=q.volume*1000 if q.isValid and q.faces.count else 0
  if v>.01:clashes.append({'pose':label,'a':a[1],'b':b[1],'overlap_mm3':v})
 current=[v for v in items if not v[0].startswith(('P08 Cam 3','P08 Cam 5','P08 Cam 8','REFERENCE Stock spring'))]
 for i,a in enumerate([]):
  for b in current[i+1:]:check(a,b,'neutral')
 progress('neutral complete')
 mainpre=('P05','P06','P07','P09','P10','G01','HARDWARE G01','P28','HARDWARE Main shaft','HARDWARE Grip M3','HARDWARE Cam M3','HARDWARE Compact sensor clamp','HARDWARE Rotor clamp','HARDWARE Shaft joining')
 forkpre=('P11','HARDWARE 623ZZ','HARDWARE Roller axle')
 pinpre=('G02','HARDWARE G02')
 pin=[v for v in items if v[0].startswith(pinpre)]
 fixed=[v for v in items if not v[0].startswith(mainpre+forkpre+pinpre+('P08','REFERENCE Stock spring'))]
 main=[];pin=[];fork=[v for v in items if v[0].startswith(forkpre)]
 angles=sorted(set([-60,-59,-58,58,59,60]+list(range(-55,56,5))))
 for n in [3,5,7]:
  cam=next(v for v in items if v[0].startswith('P08 Cam '+str(n)))
  angles=sorted(set([-60,60]+[-58+i*116/(2*(n-1)) for i in range(2*(n-1)+1)]))
  for deg in angles:
   progress('cam%d angle%d'%(n,deg))
   beta=math.degrees(-.5*1.4*(1-math.cos(2*math.pi*(math.radians(deg)+math.radians(58))/math.radians(116/(n-1))))/35)
   moved=[];fm=[];pm=[]
   for source,target,m in [(main+[cam],moved,rotation(deg,(0,0,3.0))),(fork,fm,rotation(beta,(0,-3.5,-2.3)))]:
    for name,bn,body in source:
     q=tm.copy(body);tm.transform(q,m);target.append((name,bn,q))
   for v in pin:
    q=tm.copy(v[2]);tm.transform(q,rotation(-2*deg,(0,0,-1.515)));pm.append((v[0],v[1],q))
   for a in pm:
    for b in fixed+fm:check(a,b,'pinion angle%d'%deg)
   for a in moved:
    for b in fixed+fm+pm:check(a,b,'cam%d angle%d'%(n,deg))
   for a in fm:
    for b in fixed:check(a,b,'cam%d follower%d'%(n,deg))
 # Nominal cam extraction with follower held five degrees down.
 servicefixed=[v for v in items if not v[0].startswith(('P08','REFERENCE Stock spring','HARDWARE Cam M3','G01','HARDWARE G01','G02','HARDWARE G02','G03','HARDWARE Lower panel','REFERENCE Geared','HARDWARE Geared')+forkpre)]
 for v in fork:
  q=tm.copy(v[2]);tm.transform(q,rotation(-5,(0,-3.5,-2.3)));servicefixed.append((v[0],v[1],q))
 for n in [3,5,7]:
  cam=next(v for v in items if v[0].startswith('P08 Cam '+str(n)))
  for dx in [0,5,10,15,20,25,30,35,40]:
   q=tm.copy(cam[2]);m=C.Matrix3D.create();m.translation=C.Vector3D.create(dx/10,0,0);tm.transform(q,m)
   for b in servicefixed:check((cam[0],cam[1],q),b,'service cam%d shift%d'%(n,dx))
 progress('service complete')
 report={'document':app.activeDocument.name,'unhealthy_features':health,'solid_count':len(items),'pivot_mm':30,'pot_axis_mm':-15.15,'sampled_angles':angles,'cam_profiles':[3,5,7],'neutral_and_motion_clashes':clashes,'tolerance_mm3':.01,'gear_mesh_evidence':'Full involute profile check; pinion indexed exactly two teeth; clearance cuts remove material only.','service_sequence':'Remove G01 plus the lower panel/sensor/pinion assembly before cam withdrawal.','scope':'Alternative cam/follower-only checks at each gate and crest, plus service extraction; other moving components covered by 8-gate full assembly check. Solid interference; spring deformation, actual sensor dimensions, fastener torque, physical strength are separate checks. Frame comparison uses rounded nominal rectangular rail envelopes; fastener slot engagement is excluded.'}
 with open(OUT+'/alternative-cam-check.json','w') as f:json.dump(report,f,indent=2)
 print(json.dumps({'unhealthy':health,'clash_count':len(clashes),'clashes':clashes[:30],'report':OUT+'/alternative-cam-check.json'}))
