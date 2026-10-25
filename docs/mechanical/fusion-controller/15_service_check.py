exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/12_motion.py').read().split('def run(_context:str):')[0])
def run(_context:str):
 root=F.Design.cast(C.Application.get().activeProduct).rootComponent;tm=F.TemporaryBRepManager.get();fixed=[];cam=None
 for o in root.allOccurrences:
  name=o.component.name
  if name.startswith(('REFERENCE spring','HARDWARE Cam fastener')):continue
  if name.startswith('P08') and not name.startswith('P08 Cam 7'):continue
  for b in o.component.bRepBodies:
   q=tm.copy(b.createForAssemblyContext(o))
   if name.startswith(('P11','P12','HARDWARE H02','HARDWARE Roller axle')):tm.transform(q,trans(math.radians(-5),(0,-3.5,1.2)))
   item=(name,q)
   if name.startswith('P08'):cam=item
   else:fixed.append(item)
 rows=[]
 for dx in range(0,41,5):
  moving=tm.copy(cam[1]);m=C.Matrix3D.create();m.translation=C.Vector3D.create(dx/10,0,0);tm.transform(moving,m)
  for name,b in fixed:
   if not overlap(moving,b):continue
   q=tm.copy(moving)
   if not tm.booleanOperation(q,b,F.BooleanTypes.IntersectionBooleanType):raise RuntimeError('Boolean failed')
   v=q.volume*1000 if q.isValid and q.faces.count else 0
   if v>.01:rows.append({'translation_mm':dx,'part':name,'mm3':v})
 open(ROOTDIR+'/service-path.json','w').write(json.dumps({'sampled_translation_mm':list(range(0,41,5)),'clashes':rows},indent=2))
 print(json.dumps({'service_path_clashes':rows}))

