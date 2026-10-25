import adsk.core as C,adsk.fusion as F,math,json,time
ROOTDIR='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller'
PROFILE=7
ANGLES=[-52+4*i for i in range(27)]
TOL_MM3=.01

def trans(angle,center):
 m=C.Matrix3D.create();m.setToRotation(angle,C.Vector3D.create(1,0,0),C.Point3D.create(*center));return m

def overlap(a,b):
 aa=a.boundingBox;bb=b.boundingBox
 return all(min(x,y)>max(z,w)+1e-8 for x,y,z,w in zip(aa.maxPoint.asArray(),bb.maxPoint.asArray(),aa.minPoint.asArray(),bb.minPoint.asArray()))

def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);tm=F.TemporaryBRepManager.get()
 fixed=[];main=[];follower=[];cams={};roller=None
 for o in d.rootComponent.allOccurrences:
  name=o.component.name
  if name.startswith(('REFERENCE spring','P18 Tight')):continue
  for body in o.component.bRepBodies:
   b=tm.copy(body.createForAssemblyContext(o));item=(name,b)
   if name.startswith('P08'):
    cams[int(name.split()[2])]=item;continue
   if name.startswith(('P05','P06','P07','P09','P10','P17','P18','P19','P20','HARDWARE Main shaft cap','HARDWARE Grip fastener','HARDWARE Cam fastener','HARDWARE Coupler clamp','HARDWARE Rotor clamp')):main.append(item)
   elif name.startswith(('P11','P12','HARDWARE H02','HARDWARE Roller axle')):follower.append(item)
   else:fixed.append(item)
 # Conservative solid extrusion envelopes, using actual imported mesh bounds.
 for o in d.rootComponent.allOccurrences:
  if o.component.name.startswith('REFERENCE - fixed'):
   for mesh in o.component.meshBodies:
    bb=mesh.boundingBox;lo=bb.minPoint.asArray();hi=bb.maxPoint.asArray()
    ob=C.OrientedBoundingBox3D.create(C.Point3D.create(*[(a+b)/2 for a,b in zip(lo,hi)]),C.Vector3D.create(1,0,0),C.Vector3D.create(0,1,0),hi[0]-lo[0],hi[1]-lo[1],hi[2]-lo[2])
    fixed.append(('FIXED FRAME envelope',tm.createBox(ob)))
 main.append(cams[PROFILE]);rows=[];tiny=[]
 def check(a,b,pose):
  if not overlap(a[1],b[1]):return
  cut=tm.copy(a[1]);ok=tm.booleanOperation(cut,b[1],F.BooleanTypes.IntersectionBooleanType)
  if not ok:raise RuntimeError('Kernel boolean failed '+a[0]+' / '+b[0])
  v=cut.volume*1000 if cut.isValid and cut.faces.count else 0
  if v>TOL_MM3:rows.append({'pose_deg':pose,'a':a[0],'b':b[0],'volume_mm3':v})
  elif v>1e-8:tiny.append({'pose_deg':pose,'a':a[0],'b':b[0],'volume_mm3':v})
 for deg in ANGLES:
  t=math.radians(deg);pitch=math.radians(100/(PROFILE-1));beta=-.5*1.4*(1-math.cos(2*math.pi*(t+math.radians(50))/pitch))/35
  mm=[];ff=[]
  for name,b in main:
   q=tm.copy(b);tm.transform(q,trans(t,(0,0,6.5)));mm.append((name,q))
  for name,b in follower:
   q=tm.copy(b);tm.transform(q,trans(beta,(0,-3.5,1.2)));ff.append((name,q))
  for a in mm:
   for b in fixed+ff:check(a,b,deg)
  for a in ff:
   for b in fixed:check(a,b,deg)
 report={'profile':PROFILE,'poses':ANGLES,'threshold_mm3':TOL_MM3,'clashes':rows,'subthreshold_contacts':tiny}
 open(ROOTDIR+'/motion-'+str(PROFILE)+'.json','w').write(json.dumps(report,indent=2))
 print(json.dumps({'profile':PROFILE,'poses':len(ANGLES),'clashes':rows,'max_subthreshold_mm3':max([r['volume_mm3'] for r in tiny],default=0)}))

