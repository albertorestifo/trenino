exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/12_motion.py').read().split('def run(_context:str):')[0])
def run(_context:str):
 root=F.Design.cast(C.Application.get().activeProduct).rootComponent;tm=F.TemporaryBRepManager.get();items=[]
 for o in root.allOccurrences:
  if not o.isLightBulbOn or o.component.name.startswith('REFERENCE spring'):continue
  for b in o.component.bRepBodies:items.append((o.component.name,tm.copy(b.createForAssemblyContext(o))))
 allmain=('P05','P06','P07','P08','P09','P10','P17','P18','P19','P20','HARDWARE Main shaft cap','HARDWARE Grip fastener','HARDWARE Cam fastener','HARDWARE Coupler clamp','HARDWARE Rotor clamp')
 ffpre=('P11','P12','HARDWARE H02','HARDWARE Roller axle')
 changed=[v for v in items if v[0].startswith(('P07','P18','HARDWARE Rotor clamp'))]
 fixed=[v for v in items if not v[0].startswith(allmain+ffpre)]
 followers=[v for v in items if v[0].startswith(ffpre)];clashes=[]
 def check(a,b,label):
  if not overlap(a[1],b[1]):return
  q=tm.copy(a[1])
  if not tm.booleanOperation(q,b[1],F.BooleanTypes.IntersectionBooleanType):raise RuntimeError('Boolean failed')
  vol=q.volume*1000 if q.isValid and q.faces.count else 0
  if vol>.01:clashes.append({'case':label,'a':a[0],'b':b[0],'mm3':vol})
 def moved(item,m):
  q=tm.copy(item[1]);tm.transform(q,m);return(item[0],q)
 for deg in range(-52,53,4):
  t=math.radians(deg);beta=-.5*1.4*(1-math.cos(2*math.pi*(t+math.radians(50))/math.radians(100/6)))/35
  ff=[moved(v,trans(beta,(0,-3.5,1.2))) for v in followers]
  for a in changed:
   for b in fixed+ff:check(moved(a,trans(t,(0,0,6.5))),b,'revised rotor/coupling '+str(deg))
 for beta in [0,-.04,math.radians(-5)]:
  for a in followers:
   for b in fixed:check(moved(a,trans(beta,(0,-3.5,1.2))),b,'follower operation/service '+str(beta))
 cup=[v for v in items if v[0].startswith(('P14','HARDWARE Preload adjuster'))]
 other=[v for v in items if not v[0].startswith(('P14','HARDWARE Preload adjuster'))]
 for dz in [-1,0,1]:
  m=C.Matrix3D.create();m.translation=C.Vector3D.create(0,0,dz/10)
  for a in cup:
   for b in other:check(moved(a,m),b,'preload shift mm '+str(dz))
 alt=next(o for o in root.allOccurrences if o.component.name.startswith('P18 Tight'))
 a=(alt.component.name,tm.copy(alt.component.bRepBodies.item(0).createForAssemblyContext(alt)))
 for b in items:
  if not b[0].startswith('P18'):check(a,b,'optional 4.1 disc assembled fit')
 r={'rotor_poses':27,'follower_radians':[0,-.04,math.radians(-5)],'preload_offsets_mm':[-1,0,1],'threshold_mm3':.01,'clashes':clashes,'insert_min_wall_mm':min(74-70-2.3,math.hypot(62,65-53.5)-51-2.3),'rail_counterbore_web_mm':53.5-1.7-(45+5.3),'rail_tip_to_web_mm':81.2-80}
 open(ROOTDIR+'/final-targeted-checks.json','w').write(json.dumps(r,indent=2));print(json.dumps(r))


