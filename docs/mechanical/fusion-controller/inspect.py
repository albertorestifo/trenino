import adsk.core as C,adsk.fusion as F
def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct)
 print('timeline',d.timeline.count)
 for o in d.rootComponent.allOccurrences:
  print(o.name)
  for b in o.component.bRepBodies:print(b.name,b.boundingBox.minPoint.asArray(),b.boundingBox.maxPoint.asArray())
  for s in o.component.sketches:print(s.name,s.transform.asArray())
