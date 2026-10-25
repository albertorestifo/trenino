import adsk.core as C,adsk.fusion as F,math,json
OUT='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/raised-wide-travel'
def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct);r=d.rootComponent;tm=F.TemporaryBRepManager.get()
 def body(pre):
  o=next(o for o in r.occurrences if o.component.name.startswith(pre));return tm.copy(o.component.bRepBodies.item(0).createForAssemblyContext(o))
 lever=body('P07');left=body('P01R');rows=[]
 for deg in [-61,-60.1,-60,-59.9,59.9,60,60.1,61]:
  q=tm.copy(lever);m=C.Matrix3D.create();m.setToRotation(math.radians(deg),C.Vector3D.create(1,0,0),C.Point3D.create(0,0,3));tm.transform(q,m)
  assert tm.booleanOperation(q,left,F.BooleanTypes.IntersectionBooleanType)
  vol=q.volume*1000 if q.isValid and q.faces.count else 0;rows.append(dict(angle_deg=deg,overlap_mm3=vol))
 assert all(x['overlap_mm3']<.01 for x in rows if abs(x['angle_deg'])<=60)
 assert all(x['overlap_mm3']>.01 for x in rows if abs(x['angle_deg'])>60)
 open(OUT+'/stop-check.json','w').write(json.dumps(rows,indent=2));print(json.dumps(rows))
