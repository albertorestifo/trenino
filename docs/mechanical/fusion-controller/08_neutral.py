import adsk.core as C,adsk.fusion as F,json
ROOTDIR='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller'
def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);es=C.ObjectCollection.create();bodies=[]
 for o in d.rootComponent.allOccurrences:
  if not o.isLightBulbOn or o.component.name.startswith('REFERENCE spring'):continue
  for b in o.component.bRepBodies:
   es.add(b.createForAssemblyContext(o));bodies.append({'name':o.component.name,'solid':b.isSolid,'volume_cm3':b.volume,'bounds_mm':[[10*t for t in b.boundingBox.minPoint.asArray()],[10*t for t in b.boundingBox.maxPoint.asArray()]]})
 inp=d.createInterferenceInput(es);inp.areCoincidentFacesIncluded=False
 rr=d.analyzeInterference(inp);cl=[]
 for r in rr:cl.append({'a':r.entityOne.name,'b':r.entityTwo.name,'mm3':r.interferenceBody.volume*1000})
 print(json.dumps({'bodies':len(bodies),'clashes':cl}))
 open(ROOTDIR+'/neutral-validation.json','w').write(json.dumps({'bodies':bodies,'clashes':cl},indent=2))
