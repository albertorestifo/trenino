import adsk.core as C,adsk.fusion as F,json
ROOTDIR='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller'
def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);bad=[];n=0
 for o in d.rootComponent.allOccurrences:
  for f in o.component.features:
   n+=1
   if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState:bad.append({'component':o.component.name,'feature':f.name,'message':f.errorOrWarningMessage})
 r={'document':app.activeDocument.name,'modified':app.activeDocument.isModified,'features':n,'nonhealthy_features':bad,'joints':d.rootComponent.asBuiltJoints.count,'rigid_groups':d.rootComponent.rigidGroups.count}
 open(ROOTDIR+'/native-health.json','w').write(json.dumps(r,indent=2));print(json.dumps(r))
