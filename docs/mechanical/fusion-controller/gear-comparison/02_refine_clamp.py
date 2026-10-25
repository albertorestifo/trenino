exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])
def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 assert app.activeDocument.dataFile.id=='urn:adsk.wipprod:dm.lineage:HlxCOdQOSdGZfMtoCnyuyw'
 c=next(o.component for o in root.occurrences if o.component.name=='G02 24T sensor pinion')
 names=['Recessed clamp screw head and tool path','Clamp through screw','Clamp heat-set insert pocket']
 for name in names:
  f=next(f for f in c.features.extrudeFeatures if f.name.startswith(name));f.deleteMe()
 for o in list(root.occurrences):
  if o.component.name=='HARDWARE G02 24T sensor pinion clamp M3x12':o.deleteMe()
 zz=117.65
 circle(c,'y',-7,44.5,zz,2,6.8,CUT,'Revised clamp insert pocket')
 circle(c,'y',-.3,44.5,zz,1.7,5.4,CUT,'Revised clamp screw clearance')
 circle(c,'y',5,44.5,zz,3.1,30,CUT,'Revised recessed clamp head')
 bolt(root,'G02 24T sensor pinion clamp M3x12','y',5,-7,44.5,zz,1.5,2.75,3,1)
 for o in root.allOccurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in root.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 print(json.dumps({'bad_features':bad,'pinion_bodies':c.bRepBodies.count}))

