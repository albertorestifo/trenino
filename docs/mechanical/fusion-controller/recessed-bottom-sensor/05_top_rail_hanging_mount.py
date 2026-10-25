exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])
def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);r=d.rootComponent
 assert app.activeDocument.dataFile.id=='urn:adsk.wipprod:dm.lineage:8phaaOK2S5SnbORU7BqJyQ'
 for o in list(r.occurrences):
  if o.component.name.startswith(('HARDWARE Recessed rail','REFERENCE Flush infill')):o.deleteMe()
 for pre,x in [('P01R',-36),('P02R',24)]:
  c=next(o.component for o in r.occurrences if o.component.name.startswith(pre))
  for f in reversed(list(c.features.extrudeFeatures)):
   if f.name.startswith(('Underside M5 clearance','Underside rail suspension arm')):f.deleteMe()
  for sg in [-1,1]:
   pts=[(55,33),(74.5,33),(74.5,102),(95,102),(95,111),(65,111),(55,57)]
   poly(c,'x',x,[(sg*y,z) for y,z in pts],12,JOIN,'Top rail hanging suspension arm')
   circle(c,'z',101.9,x+6,sg*85,2.7,9.2,CUT,'Top-access M5 mounting clearance')
   bolt(r,'Top hanging rail M5x14 '+str((x+6,sg)),'z',111,97,x+6,sg*85,2.5,4.25,5,1)
  c.name=pre+' Top-rail hanging '+('left' if pre=='P01R' else 'right sensor')+' sideplate'
  if pre=='P02R':box(c,(34,-62.2,3.8),(36.1,62.2,34.2),CUT,'Recess seat for removable lower sensor panel')
  c.bRepBodies.item(0).name=c.name
 for o in r.occurrences:
  if o.component.name.startswith('HARDWARE Top hanging rail'):
   m=C.Matrix3D.create();m.translation=C.Vector3D.create(0,0,-4.7);o.transform2=m
 if d.snapshots.hasPendingSnapshot:d.snapshots.add()
 c=comp(r,'REFERENCE Locomotive-style panel face 3 mm - concept only')
 box(c,(-320,-95,55),(320,95,58),name='Panel resting on frame top')
 box(c,(-10,-68,54.9),(10,68,58.1),CUT,'20 by 136 mm lever sweep opening')
 for x in [-30,30]:
  for sg in [-1,1]:
   ya,yb=(61.5,96) if sg>0 else (-96,-61.5)
   box(c,(x-6.5,ya,54.9),(x+6.5,yb,58.1),CUT,'Local raised mounting-tab clearance')
 color(c,105,115,125)
 for o in r.occurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
  if o.component==c:o.isLightBulbOn=False;o.isGrounded=True
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in r.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 assert not bad,str(bad)
 print(json.dumps({'top_mount_seat_z_mm':64,'rail_top_z_mm':55,'pivot_z_mm':18,'sensor_z_mm':-27.15,'native_unhealthy':bad}))

