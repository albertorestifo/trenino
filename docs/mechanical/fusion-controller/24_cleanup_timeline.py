import adsk.core as C,adsk.fusion as F,json
ROOTDIR='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller'
def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent;tm=F.TemporaryBRepManager.get();bad=[];before={}
 for o in root.allOccurrences:
  for f in o.component.features:
   if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState:
    if 'No target body!' not in f.errorOrWarningMessage:raise RuntimeError('Unexpected nonhealthy feature '+f.name)
    bad.append(f)
    if o.component.name not in before:before[o.component.name]=(o.component,tm.copy(o.component.bRepBodies.item(0)))
 names=[f.name for f in bad]
 for f in sorted(bad,key=lambda f:f.timelineObject.index,reverse=True):f.deleteMe()
 changes=[]
 for name,(c,old) in before.items():
  new=c.bRepBodies.item(0);a=old.volume;b=new.volume;q=tm.copy(old)
  if not tm.booleanOperation(q,tm.copy(new),F.BooleanTypes.IntersectionBooleanType):raise RuntimeError('Shape equivalence check failed '+name)
  diff=(a+b-2*q.volume)*1000
  if abs(diff)>1e-4:raise RuntimeError('Cleanup changed solid '+name+' '+str(diff))
  changes.append({'component':name,'symmetric_difference_mm3':diff})
 r={'removed_redundant_features':names,'shape_equivalence':changes}
 open(ROOTDIR+'/timeline-cleanup.json','w').write(json.dumps(r,indent=2));print(json.dumps(r))
