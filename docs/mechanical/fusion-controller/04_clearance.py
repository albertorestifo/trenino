exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/02_lever_cam.py').read().split('def run(_context:str):')[0])
def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent
 rotor=next(o.component for o in root.allOccurrences if o.component.name.startswith('P07'))
 dcut(rotor,-24,48,8.1,6.65,'Restore shaft socket through stop-lug root')
 bracket=next(o.component for o in root.allOccurrences if o.component.name.startswith('P13'))
 circle(bracket,'x',-24.1,0,65,51,48.2,CUT,'Cam sweep clearance through crossblock')
 entities=C.ObjectCollection.create()
 for o in root.allOccurrences:
  if not o.isLightBulbOn or o.component.name.startswith('REFERENCE'):continue
  for b in o.component.bRepBodies:entities.add(b.createForAssemblyContext(o))
 inp=d.createInterferenceInput(entities);inp.areCoincidentFacesIncluded=False
 result=d.analyzeInterference(inp)
 print('NEUTRAL CHECK',result.count)
 for r in result:print(r.entityOne.name,r.entityTwo.name,r.interferenceBody.volume)
