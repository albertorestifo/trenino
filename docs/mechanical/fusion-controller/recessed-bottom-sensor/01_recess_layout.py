exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])
OUT=ROOTDIR+'/recessed-bottom-sensor'
ID='urn:adsk.wipprod:dm.lineage:8phaaOK2S5SnbORU7BqJyQ'

def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);r=d.rootComponent
 assert app.activeDocument.dataFile.id==ID
 assert not any(o.component.name.startswith('P01R') for o in r.occurrences)
 for o in list(r.occurrences):
  if o.component.name.startswith(('HARDWARE Rail','HARDWARE G01')):o.deleteMe()
 for pre,x in [('P01',-36),('P02',24)]:
  c=next(o.component for o in r.occurrences if o.component.name.startswith(pre))
  for sg in [-1,1]:
   a,b=(75,96) if sg>0 else (-96,-75)
   box(c,(x-.1,a,50),(x+12.1,b,90),CUT,'Remove above-rail flange')
   pts=[(55,33),(75,33),(75,73),(95,73),(95,82),(65,82),(55,57)]
   poly(c,'x',x,[(sg*y,z) for y,z in pts],12,JOIN,'Underside rail suspension arm')
   circle(c,'z',72.9,x+6,sg*85,2.7,9.2,CUT,'Underside M5 clearance')
   bolt(r,'Recessed rail M5x14 '+str((x+6,sg)),'z',73,87,x+6,sg*85,2.5,4.25,5,-1)
  if pre=='P02':
   box(c,(23.9,-24,86.01),(34.1,24,127),CUT,'Remove upper sensor towers')
   for sg in [-1,1]:
    a,b=(10,23) if sg>0 else (-23,-10)
    box(c,(24,a,4),(34,b,35),JOIN,'Lower sensor support')
    circle(c,'x',24,sg*16,19.85,2,6.8,CUT,'Lower sensor M3 insert')
    circle(c,'x',30.7,sg*16,19.85,1.7,3.4,CUT,'Lower sensor screw clearance')
   box(c,(23.9,-8,8.5),(34.1,8,31.2),CUT,'Potentiometer body and lead clearance')
  c.name=pre+'R Recessed '+('left' if pre=='P01' else 'right sensor')+' sideplate'
  for b in c.bRepBodies:b.name=c.name
 # The mesh now engages underneath G01, so its split/clamp must move above.
 c=next(o.component for o in r.occurrences if o.component.name.startswith('G01 '))
 for name in ['Recessed clamp screw head and tool path','Clamp through screw','Clamp heat-set insert pocket','Clamp slit outside operating mesh sector']:
  next(f for f in c.features.extrudeFeatures if f.name.startswith(name)).deleteMe()
 box(c,(40.4,-.2,65),(48.6,.2,98),CUT,'Upper clamp split clear of lower mesh')
 circle(c,'y',-8,44.5,73,2,6.8,CUT,'Upper clamp insert')
 circle(c,'y',-1.3,44.5,73,1.7,6.4,CUT,'Upper clamp screw clearance')
 circle(c,'y',5,44.5,73,3.1,30,CUT,'Upper clamp head recess')
 bolt(r,'G01 upper clamp M3x12','y',5,-7,44.5,73,1.5,2.75,3,1)
 c.name='G01R 48T gear with upper clamp';c.bRepBodies.item(0).name=c.name
 # Move the mechanism down 47 mm. Sensor parts swing below the pivot.
 sensor=('G03 ','REFERENCE Geared','HARDWARE Geared')
 for o in r.occurrences:
  name=o.component.name
  if name.startswith('REFERENCE - fixed'):continue
  o.isGrounded=False
  if name.startswith(('G02 ','HARDWARE G02')):
   m=C.Matrix3D.create();m.setToRotation(math.radians(210),C.Vector3D.create(1,0,0),p(0,0,110.15))
   v=m.translation;v.z-=13.73;m.translation=v
  elif name.startswith(sensor):
   m=C.Matrix3D.create();m.setToRotation(math.pi,C.Vector3D.create(1,0,0),p(0,0,65))
   v=m.translation;v.z-=4.7;m.translation=v
  else:
   m=o.transform2;v=m.translation;v.z-=4.7;m.translation=v
  o.transform2=m
 if d.snapshots.hasPendingSnapshot:d.snapshots.add()
 d.userParameters.itemByName('PivotHeight').expression='18 mm'
 for o in r.occurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in r.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 assert not bad,str(bad)
 print(json.dumps({'pivot_z_mm':18,'panel_z_mm':55,'sensor_z_mm':-27.15,'unhealthy':bad}))
