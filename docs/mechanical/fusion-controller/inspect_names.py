import adsk.core as C, adsk.fusion as F
def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct)
 for o in d.rootComponent.allOccurrences:
  if o.component.name.startswith('P17'):
   for f in o.component.features.extrudeFeatures:print(repr(f.name))
