exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/opposite-sides/helpers.py').read())

def run(_context:str):
 app,d,r=setup();cams=[o for o in r.occurrences if o.component.name.startswith('P08 ')]
 for o in cams:
  c=o.component;assert c.bRepBodies.count==1;original=c.bRepBodies.item(0)
  entities=C.ObjectCollection.create();entities.add(original)
  inp=c.features.mirrorFeatures.createInput(entities,c.yZConstructionPlane);inp.isCombine=False
  f=c.features.mirrorFeatures.add(inp);f.name='Reverse mounting face without changing roller profile'
  c.features.removeFeatures.add(original)
  assert c.bRepBodies.count==1
 for o in cams:
  m=C.Matrix3D.create();m.translation=C.Vector3D.create(-2.6,0,-3.5);o.transform2=m
 done(d,'03d-cam-handedness')
