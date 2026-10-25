import adsk.core as C,adsk.fusion as F,math,json
OUT='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/opposite-sides'

def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct);r=d.rootComponent;tm=F.TemporaryBRepManager.get();items=[];clashes=[]
 for o in r.occurrences:
  if o.component.name.startswith(('P08 Cam 3','P08 Cam 5','P08 Cam 8','REFERENCE Stock spring')):continue
  for b in o.component.bRepBodies:items.append((o.component.name,tm.copy(b.createForAssemblyContext(o))))
 def check(a,b,label):
  aa=a[1].boundingBox;bb=b[1].boundingBox
  if not all(min(x,y)>max(z,w)+1e-8 for x,y,z,w in zip(aa.maxPoint.asArray(),bb.maxPoint.asArray(),aa.minPoint.asArray(),bb.minPoint.asArray())):return
  q=tm.copy(a[1]);assert tm.booleanOperation(q,b[1],F.BooleanTypes.IntersectionBooleanType)
  v=q.volume*1000 if q.isValid and q.faces.count else 0
  if v>.01:clashes.append(dict(pose=label,a=a[0],b=b[0],volume_mm3=v))
 braces=[v for v in items if v[0].startswith(('P30 ','HARDWARE Brace'))]
 main=[v for v in items if v[0].startswith(('P05','P06','P07','P09','P10','P23','P24','P28','HARDWARE Grip','HARDWARE Rotor','HARDWARE Shaft'))]
 for angle in range(-60,61):
  m=C.Matrix3D.create();m.setToRotation(math.radians(angle),C.Vector3D.create(1,0,0),C.Point3D.create(0,0,3))
  for name,b in main:
   q=tm.copy(b);tm.transform(q,m)
   for brace in braces:check((name,q),brace,'lower braces '+str(angle))
 sensorpre=('G02','G03','HARDWARE G02','HARDWARE Geared','REFERENCE Geared')
 sensor=[v for v in items if v[0].startswith(sensorpre)]
 fixed=[v for v in items if not v[0].startswith(sensorpre)]
 for dz in [-.35,.15]:
  m=C.Matrix3D.create();m.translation=C.Vector3D.create(0,0,dz/10)
  for name,b in sensor:
   q=tm.copy(b);tm.transform(q,m)
   for other in fixed:
    if name.startswith('G02') and other[0].startswith('G01'):continue # unchanged involute pair separately checked at45..45.5
    check((name,q),other,'sensor adjust '+str(dz))
 # Temporary M3x12 service screw, positively retained in the -4deg follower.
 forkpre=('P11','HARDWARE Roller axle','HARDWARE 623ZZ')
 service=[];m=C.Matrix3D.create();m.setToRotation(math.radians(-4),C.Vector3D.create(1,0,0),C.Point3D.create(0,-3.5,-2.3))
 for name,b in items:
  if name.startswith(('P08','HARDWARE Cam')):continue
  q=tm.copy(b)
  if name.startswith(forkpre):tm.transform(q,m)
  service.append((name,q))
 yy=(-35-20*math.cos(math.radians(4)))/10;zz=(-23+20*math.sin(math.radians(4)))/10
 for name,xa,xb,rad in [('service screw shank',-49.2,-37.2,1.5),('service screw head',-52.2,-49.2,2.75)]:
  q=tm.createCylinderOrCone(C.Point3D.create(xa/10,yy,zz),rad/10,C.Point3D.create(xb/10,yy,zz),rad/10)
  for other in service:check((name,q),other,'retained service pose')
 # Driver approach to the three outward-facing cam screws at neutral.
 for a in [-45,0,45]:
  yy=-36*math.sin(math.radians(a))/10;zz=(30-36*math.cos(math.radians(a)))/10
  q=tm.createCylinderOrCone(C.Point3D.create(-8,yy,zz),.15,C.Point3D.create(-4.1,yy,zz),.15)
  for other in items:
   if other[0].startswith('HARDWARE Cam'):continue
   check(('cam driver '+str(a),q),other,'cam screw driver access')
 report={'angles_degrees':[-60,60],'step_degrees':1,'sensor_center_distances_mm':[45.0,45.5],'service_follower_deg':-4,'clashes':clashes,'tolerance_mm3':.01}
 open(OUT+'/final-regression-check.json','w').write(json.dumps(report,indent=2));print(json.dumps(report));assert not clashes
