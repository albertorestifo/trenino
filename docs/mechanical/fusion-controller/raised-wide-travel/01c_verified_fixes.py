exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())
def run(_context:str):
 a=C.Application.get();d=F.Design.cast(a.activeProduct);r=d.rootComponent
 assert a.activeDocument.dataFile.id=='urn:adsk.wipprod:dm.lineage:peR4meb5QLiO5tE5ANITQg'
 c=next(o.component for o in r.occurrences if o.component.name.startswith('P02R'))
 assert not any(f.name.startswith('Upper bearing load bridge') for f in c.features)
 for sg in [-1,1]:
  lo,hi=(20,60) if sg>0 else (-60,-20)
  box(c,(24,lo,78),(36,hi,86),JOIN,'Upper bearing load bridge')
 box(c,(34,-62.2,3.8),(36.1,62.2,34.2),CUT,'Restore sensor panel rebate after hanger rebuild')
 assert c.bRepBodies.count==1,c.bRepBodies.count
 c.bRepBodies.item(0).name=c.name
 # Set placements only after modeling, then capture them before later features.
 for o in r.occurrences:
  if o.component.name.startswith(('P08 Cam','HARDWARE Stop')):
   m=C.Matrix3D.create();m.translation=C.Vector3D.create(0,0,-3.5);o.transform2=m
   if o.component.name.startswith('P08'):o.isLightBulbOn=o.component.name.startswith('P08 Cam 7')
 if d.snapshots.hasPendingSnapshot:d.snapshots.add()
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in r.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 assert not bad,str(bad)
 print(json.dumps({'native_health':bad,'right_sideplate_bodies':c.bRepBodies.count,'cam_z_transform_mm':-35,'default_cam':7}))
