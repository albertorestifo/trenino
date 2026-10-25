import adsk.core as C,adsk.fusion as F,math,json
OUT='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/opposite-sides'

def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct);r=d.rootComponent;tm=F.TemporaryBRepManager.get()
 rotor=next(o for o in r.occurrences if o.component.name.startswith('P07S'))
 rb=tm.copy(rotor.component.bRepBodies.item(0).createForAssemblyContext(rotor));rows=[]
 stops=[tm.copy(o.component.bRepBodies.item(0).createForAssemblyContext(o)) for o in r.occurrences if o.component.name.startswith('P31 ')]
 for angle in [-61,-60.1,-60,-59.9,0,59.9,60,60.1,61]:
  m=C.Matrix3D.create();m.setToRotation(math.radians(angle),C.Vector3D.create(1,0,0),C.Point3D.create(0,0,3))
  b=tm.copy(rb);tm.transform(b,m);vs=[]
  for st in stops:
   q=tm.copy(b);assert tm.booleanOperation(q,st,F.BooleanTypes.IntersectionBooleanType)
   vs.append(q.volume*1000 if q.isValid and q.faces.count else 0)
  rows.append({'angle':angle,'overlap_mm3':sum(vs)})
 open(OUT+'/stop-check.json','w').write(json.dumps(rows,indent=2))
 assert all(row['overlap_mm3']<.01 for row in rows if abs(row['angle'])<=60),rows
 assert all(row['overlap_mm3']>.01 for row in rows if abs(row['angle'])>60),rows
 print(json.dumps(rows))
