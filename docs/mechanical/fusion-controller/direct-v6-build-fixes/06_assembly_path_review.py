"""Read-only numerical assembly path audit; execute after final recess geometry."""
import adsk.core as C, adsk.fusion as F, json
OUT='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/direct-v6-build-fixes'
def run(_context: str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent;tm=F.TemporaryBRepManager.get()
 def parts(prefix):
  return [(b.name,tm.copy(b.createForAssemblyContext(o))) for o in root.occurrences if o.component.name.startswith(prefix+' ') for b in o.component.bRepBodies]
 def shifted(items,dx=0,dy=0):
  m=C.Matrix3D.create();m.translation=C.Vector3D.create(dx/10,dy/10,0);result=[]
  for n,b in items:
   q=tm.copy(b);tm.transform(q,m);result.append((n,q))
  return result
 def volume(a,b):
  aa=a.boundingBox;bb=b.boundingBox
  if not all(min(x,y)>max(z,w)+1e-8 for x,y,z,w in zip(aa.maxPoint.asArray(),bb.maxPoint.asArray(),aa.minPoint.asArray(),bb.minPoint.asArray())):return 0
  q=tm.copy(a);assert tm.booleanOperation(q,b,F.BooleanTypes.IntersectionBooleanType)
  return q.volume*1000 if q.isValid and q.faces.count else 0
 findings=[];checks=[]
 def test(label,moving,fixed,axis,offsets):
  largest=0
  for offset in offsets:
   moved=shifted(moving,dx=offset if axis=='x' else 0,dy=offset if axis=='y' else 0)
   for an,a in moved:
    for bn,b in fixed:
     v=volume(a,b);largest=max(largest,v)
     if v>.01:findings.append({'stage':label,'offset_mm':offset,'a':an,'b':bn,'overlap_mm3':v})
  checks.append({'stage':label,'poses':len(offsets),'max_overlap_mm3':largest})
 shaft=parts('P05');right=parts('P02');bush=parts('P04');assert len(bush)==2
 test('Empty right plate from left to hold position',right,shaft,'x',list(range(-94,-39,2)))
 hold=shifted(right,dx=-40)
 for i,half in enumerate(bush):
  center=(half[1].boundingBox.minPoint.y+half[1].boundingBox.maxPoint.y)/2
  sign=1 if center>0 else -1
  test('Radial right bush half '+str(i),[half],shaft+hold+[bush[1-i]],'y',[sign*x for x in range(40,-1,-2)])
 test('Right plate captures bush from left',right,shaft+bush,'x',list(range(-40,1)))
 fixed=shaft+right+bush
 test('Right thrust spacer from left',parts('P24'),fixed,'x',list(range(-90,1,2)))
 fixed+=parts('P24')
 test('Rotor from left',parts('P07'),fixed,'x',list(range(-90,1,2)))
 fixed+=parts('P07')
 test('Left thrust spacer from left',parts('P23'),fixed,'x',list(range(-90,1,2)))
 fixed+=parts('P23')
 test('Left plate and preinstalled left bush from left',parts('P01')+parts('P03'),fixed,'x',list(range(-90,1,2)))
 report={'scope':'Sequential assembly of stripped main shaft, housing/bushes, thrust spacers and rotor; cap, cam, follower and sensor installed afterward. Sampling is not continuous proof. Left bush is preinstalled in left plate before approaching shaft.','tolerance_mm3':.01,'checks':checks,'clashes':findings}
 with open(OUT+'/assembly-path-check.json','w') as f:json.dump(report,f,indent=2)
 print(json.dumps(report))
