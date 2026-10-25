exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())
def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);r=d.rootComponent
 assert app.activeDocument.dataFile.id=='urn:adsk.wipprod:dm.lineage:HlxCOdQOSdGZfMtoCnyuyw'
 c=next(o.component for o in r.occurrences if o.component.name=='G02 24T sensor pinion')
 assert not any(f.name.startswith('Open support-free') for f in c.features)
 box(c,(40.4,5,114.55),(48.6,18,120.75),CUT,'Open support-free clamp tool channel')
 for s in c.sketches:s.isLightBulbOn=False
 assert c.bRepBodies.count==1
 m=C.Matrix3D.create();m.setToRotation(math.radians(30),C.Vector3D.create(1,0,0),p(0,0,110.15))
 for o in r.occurrences:
  if o.component.name in ['G02 24T sensor pinion','HARDWARE G02 24T sensor pinion clamp M3x12']:o.transform2=m
 if d.snapshots.hasPendingSnapshot:d.snapshots.add()
 c=next(o.component for o in r.occurrences if o.component.name.startswith('G03 '))
 for yy in [-16,16]:box(c,(33.9,yy-1.7,107.25),(37.1,yy+1.7,113.05),CUT,'Clearance and travel for M3 panel screw')
 for o in r.occurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
 print('Pinion channel opened, indexed 30 degrees; panel mounting slots corrected')
