exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])
def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);r=d.rootComponent
 assert app.activeDocument.dataFile.id=='urn:adsk.wipprod:dm.lineage:8phaaOK2S5SnbORU7BqJyQ'
 c=next(o.component for o in r.occurrences if o.component.name.startswith('P02R'))
 names=('Potentiometer body and lead clearance','Lower sensor screw clearance','Lower sensor M3 insert','Lower sensor support')
 for f in reversed(list(c.features.extrudeFeatures)):
  if f.name.startswith(names):f.deleteMe()
 for sg in [-1,1]:
  a,b=(49,62) if sg>0 else (-62,-49)
  box(c,(24,a,4),(34,b,35),JOIN,'Outer lower sensor support clear of cam')
  circle(c,'x',24,sg*55,19.85,2,6.8,CUT,'Outer lower M3 insert')
  circle(c,'x',30.7,sg*55,19.85,1.7,3.4,CUT,'Outer lower screw clearance')
 box(c,(23.9,-8,8.5),(34.1,8,31.2),CUT,'Potentiometer body and lead clearance')
 for o in list(r.occurrences):
  if o.component.name.startswith(('G03 ','HARDWARE Geared panel')):o.deleteMe()
 c=comp(r,'G03R Lower removable potentiometer panel')
 b=box(c,(34,-62,4),(37,62,34),name='Flat lower sensor panel');b.name=c.name
 circle(c,'x',33.9,0,19.85,3.6,3.2,CUT,'Sensor bushing clearance')
 for yy in [-55,55]:
  box(c,(33.9,yy-1.7,16.95),(37.1,yy+1.7,22.75),CUT,'Radial mesh adjustment slot')
  bolt(r,'Lower panel M3x12 '+str(yy),'x',37,25,yy,19.85,1.5,2.75,3,1)
 for o in r.occurrences:
  if o.component.name.startswith(('G03R','HARDWARE Lower panel')):
   m=C.Matrix3D.create();m.translation=C.Vector3D.create(0,0,-4.7);o.transform2=m
 if d.snapshots.hasPendingSnapshot:d.snapshots.add()
 panel=comp(r,'REFERENCE Flush infill panel 3 mm - mounting not designed')
 box(panel,(-300,-75,52),(300,75,55),name='Flush panel inside fixed frame')
 box(panel,(-20,-64,51.9),(10,64,55.1),CUT,'30 by 128 mm lever sweep opening')
 color(panel,140,155,165)
 for o in r.occurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
  if o.component==panel:o.isLightBulbOn=False;o.isGrounded=True
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in r.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 assert not bad,str(bad)
 print(json.dumps({'panel_top_mm':55,'panel_thickness_assumed_mm':3,'opening_mm':[30,128],'native_unhealthy':bad}))
