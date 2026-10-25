exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/opposite-sides/04_validate.py').read().split('def run(_context: str):')[0])
exec('def campt'+open(ROOTDIR+'/raised-wide-travel/01_revise.py').read().split('def campt',1)[1].split('def run',1)[0])

def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct);r=d.rootComponent;tm=F.TemporaryBRepManager.get();items=[];profiles=[];envelopes=[];clashes=[]
 for o in r.occurrences:
  for b in o.component.bRepBodies:items.append((o.component.name,tm.copy(b.createForAssemblyContext(o))))
 for n in [3,5,7,8]:
  name,b=next(v for v in items if v[0].startswith('P08 Cam '+str(n)))
  points=[(v.geometry.y*10,v.geometry.z*10) for v in b.vertices]
  expected=[(y,z-35) for y,z in [campt(math.radians(-70+i*.25),n) for i in range(561)]]
  err=max(min(math.hypot(y-u,z-v) for u,v in points) for y,z in expected)
  assert err<1e-5,(name,err)
  maxr=max(math.hypot(y,z-30) for y,z in points);assert maxr<49.5
  profiles.append(dict(gates=n,max_native_outer_vertex_error_mm=err,max_radius_mm=maxr))
 ob=C.OrientedBoundingBox3D.create(C.Point3D.create(-3.7,0,3),C.Vector3D.create(1,0,0),C.Vector3D.create(0,1,0),.79998,30,40)
 slab=tm.createBox(ob)
 for name,b in items:
  if name.startswith(('P08','HARDWARE Cam','HARDWARE 623ZZ','REFERENCE Stock spring')):continue
  if not overlap(b,slab):continue
  q=tm.copy(b);assert tm.booleanOperation(q,slab,F.BooleanTypes.IntersectionBooleanType)
  if not q.isValid or not q.faces.count or q.volume<1e-10:continue
  bb=q.boundingBox;y0,y1=bb.minPoint.y*10,bb.maxPoint.y*10;z0,z1=bb.minPoint.z*10-30,bb.maxPoint.z*10-30
  closest=lambda a,b:0 if a<=0<=b else min(abs(a),abs(b))
  mn=math.hypot(closest(y0,y1),closest(z0,z1));mx=max(math.hypot(y,z) for y in [y0,y1] for z in [z0,z1])
  if name.startswith('P11'):
   movement=max(math.hypot(v.geometry.y*10+35,v.geometry.z*10+23) for v in q.vertices)*math.radians(4)
   mn-=movement;mx+=movement
  elif name.startswith('HARDWARE Roller axle'):
   localr=max(math.hypot(v.geometry.y*10,v.geometry.z*10+23) for v in q.vertices)
   mn=53-localr # roller center moves only further from main pivot for beta in[-4,0]
  assert mx<28.9 or mn>49.5,(name,mn,mx)
  envelopes.append(dict(part=name,conservative_min_radius_mm=mn,conservative_max_radius_mm=mx))
 # Actual service withdrawal with cam handedness corrected.
 fixed=[];m=rotation(-4,(0,-3.5,-2.3))
 for name,b in items:
  if name.startswith(('P08','HARDWARE Cam','REFERENCE Stock spring')):continue
  q=tm.copy(b)
  if name.startswith(('P11','HARDWARE Roller axle','HARDWARE 623ZZ')):tm.transform(q,m)
  fixed.append((name,q))
 for n in [3,5,7,8]:
  name,b=next(v for v in items if v[0].startswith('P08 Cam '+str(n)))
  for dx in [0,2,5,10,15,20]:
   q=tm.copy(b);t=C.Matrix3D.create();t.translation=C.Vector3D.create(-dx/10,0,0);tm.transform(q,t)
   for other,body in fixed:
    if not overlap(q,body):continue
    inter=tm.copy(q);assert tm.booleanOperation(inter,body,F.BooleanTypes.IntersectionBooleanType)
    vol=inter.volume*1000 if inter.isValid and inter.faces.count else 0
    if vol>.01:clashes.append(dict(cam=n,shift_mm=dx,other=other,overlap_mm3=vol))
 report={'native_profile_matches':profiles,'annulus_mm':[28.9,49.5],'annulus_clearance_proof':envelopes,'service_clashes':clashes,'roller_contact':'check_cam_profiles.py checks actual matched profiles at481 poses per cam','frame':'unchanged frame was included in the full pre-fix BRep sweep; cam XYZ bounds remain inside the same rail-free radial envelope'}
 open(OUT+'/final-cam-proof.json','w').write(json.dumps(report,indent=2));print(json.dumps({'profile_matches':profiles,'envelope_parts':len(envelopes),'service_clashes':clashes}));assert not clashes
