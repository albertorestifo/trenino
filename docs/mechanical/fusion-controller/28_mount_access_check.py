exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/12_motion.py').read().split('def run(_context:str):')[0])
def run(_context:str):
 root=F.Design.cast(C.Application.get().activeProduct).rootComponent;tm=F.TemporaryBRepManager.get();items=[];cl=[]
 for o in root.allOccurrences:
  if o.component.name.startswith(('REFERENCE spring','P18 Tight','P08 Cam 3','P08 Cam 5')):continue
  for b in o.component.bRepBodies:items.append((o.component.name,tm.copy(b.createForAssemblyContext(o))))
 def check(a,b,label):
  if not overlap(a[1],b[1]):return
  q=tm.copy(a[1])
  if not tm.booleanOperation(q,b[1],F.BooleanTypes.IntersectionBooleanType):raise RuntimeError('Boolean failed')
  vol=q.volume*1000 if q.isValid and q.faces.count else 0
  if vol>.01:cl.append({'case':label,'a':a[0],'b':b[0],'mm3':vol})
 def shift(v,dx=0,dz=0):
  q=tm.copy(v[1]);m=C.Matrix3D.create();m.translation=C.Vector3D.create(dx/10,0,dz/10);tm.transform(q,m);return (v[0],q)
 def box_temp(lo,hi):
  lo=[v/10 for v in lo];hi=[v/10 for v in hi]
  ob=C.OrientedBoundingBox3D.create(C.Point3D.create(*[(a+b)/2 for a,b in zip(lo,hi)]),C.Vector3D.create(1,0,0),C.Vector3D.create(0,1,0),hi[0]-lo[0],hi[1]-lo[1],hi[2]-lo[2]);return tm.createBox(ob)
 for xx in [-30,30]:
  for sg in [-1,1]:
   suffix=str((xx,sg));bolt=next(v for v in items if v[0]=='HARDWARE Rail vertical M5x16 '+suffix);washer=next(v for v in items if v[0]=='HARDWARE Rail M5 metal spacer 3mm '+suffix)
   rest=[v for v in items if v[0] not in [bolt[0],washer[0]]]
   for dz in [0,2,5,10,20,40]:
    for a in [bolt,washer]:
     for b in rest:check(shift(a,dz=dz),b,'rail screw and spacer insertion '+str(dz))
   tool=('6 mm driver shank above rail screw',box_temp((xx-3,sg*85-3,67),(xx+3,sg*85+3,160)))
   for b in rest:check(tool,b,'direct driver approach')
 # Stop locknuts can be introduced from the inside while lever is neutral.
 for a in [v for v in items if v[0].startswith('HARDWARE Stop retained M3 locknut')]:
  for dx in [0,4,8,12,20]:
   for b in items:
    if b[0]==a[0] or b[0].startswith('HARDWARE Stop steel core'):continue
    check(shift(a,dx=dx),b,'stop locknut insertion '+str(dx))
 mainpre=('P05','P06','P07','P08','P09','P10','P17','P18','P19','P20','HARDWARE Main shaft cap','HARDWARE Grip fastener','HARDWARE Cam fastener','HARDWARE Coupler clamp','HARDWARE Rotor clamp')
 followpre=('P11','P12','HARDWARE H02','HARDWARE Roller axle')
 moving=[v for v in items if v[0].startswith(mainpre)];follow=[v for v in items if v[0].startswith(followpre)]
 changed=[v for v in items if v[0].startswith(('P01','P02','P25','P26','HARDWARE Rail','HARDWARE Stop','HARDWARE Follower pivot'))]
 poses=[-52]+list(range(-50,51,5))+[52]
 for deg in poses:
  t=math.radians(deg);beta=-.5*1.4*(1-math.cos(2*math.pi*(t+math.radians(50))/math.radians(100/6)))/35
  for group,m in [(moving,trans(t,(0,0,6.5))),(follow,trans(beta,(0,-3.5,1.2)))]:
   for name,b in group:
    q=tm.copy(b);tm.transform(q,m)
    for fixed in changed:check((name,q),fixed,'changed mounts operating pose '+str(deg))
 report={'threshold_mm3':.01,'operating_poses':poses,'insertion_shifts_mm':[0,2,5,10,20,40],'driver_envelope_mm':'6 x6, Z67..160, rail screw axes X+/-30 Y+/-85','top_rail_web_mm':48.8,'rail_screw_tip_mm':50,'rail_tip_clearance_mm':1.2,'stop_bolt_tip_mm':-11.5,'stop_nut_end_mm':-13.5,'clashes':cl}
 open(ROOTDIR+'/mount-access-check.json','w').write(json.dumps(report,indent=2));print(json.dumps(report))
