exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/12_motion.py').read().split('def run(_context:str):')[0])

def run(_context:str):
 root=F.Design.cast(C.Application.get().activeProduct).rootComponent;tm=F.TemporaryBRepManager.get()
 items=[]
 for o in root.allOccurrences:
  if o.component.name.startswith(('REFERENCE spring','P18 Tight','P08 Cam 3','P08 Cam 5')):continue
  for b in o.component.bRepBodies:items.append((o.component.name,tm.copy(b.createForAssemblyContext(o))))
 mainpre=('P05','P06','P07','P08','P09','P10','P17','P18','P19','P20','HARDWARE Main shaft cap','HARDWARE Grip fastener','HARDWARE Cam fastener','HARDWARE Coupler clamp','HARDWARE Rotor clamp')
 changed=[v for v in items if v[0].startswith(('P09','P10','P17'))];cl=[]
 def check(a,b,label):
  if a[0]==b[0] or not overlap(a[1],b[1]):return
  q=tm.copy(a[1]);assert tm.booleanOperation(q,b[1],F.BooleanTypes.IntersectionBooleanType)
  vol=q.volume*1000 if q.isValid and q.faces.count else 0
  if vol>.01:cl.append({'pose':label,'a':a[0],'b':b[0],'overlap_mm3':vol})
 for a in changed:
  for b in items:check(a,b,'neutral')
 poses=[-52]+list(range(-50,51,2))+[52]
 for deg in poses:
  m=trans(math.radians(deg),(0,0,6.5))
  for name,b in changed:
   q=tm.copy(b);tm.transform(q,m)
   for fixed in items:
    if fixed[0].startswith(mainpre):continue
    check((name,q),fixed,deg)
 report={'changed':['P09','P10','P17'],'poses_deg':poses,'clashes':cl,'threshold_mm3':.01,'note':'Changed parts against static assembly and full neutral assembly. Grip changes are removal-only within existing exterior. P17 additions stay within its previous maximum radial envelope; coupling interfaces retained.'}
 open(ROOTDIR+'/support-revision/clearance-check.json','w').write(json.dumps(report,indent=2));print(json.dumps(report))
