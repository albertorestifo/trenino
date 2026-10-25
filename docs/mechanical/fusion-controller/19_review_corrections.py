exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])
def run(_context:str):
 app=C.Application.get();root=F.Design.cast(app.activeProduct).rootComponent
 for j in list(root.asBuiltJoints):j.deleteMe()
 for g in list(root.rigidGroups):g.deleteMe()
 def co(pre):return next(o.component for o in root.allOccurrences if o.component.name.startswith(pre))
 c=co('P13');box(c,(-24,-66,57),(24,-44,59),JOIN,'Extra roof over relocated heat-set inserts')
 for yy in [-59,-51]:
  for xx in [-24,15.3]:circle(c,'x',xx,yy,52,2.01,8.7,JOIN,'Fill former insert location')
  for pre,xx in [('P01',-36),('P02',24)]:circle(co(pre),'x',xx,yy,52,1.71,12,JOIN,'Fill former plate mounting hole')
 for yy in [-62,-54]:
  for xx in [-24.1,15.3]:circle(c,'x',xx,yy,53.5,2,8.9,CUT,'Relocated insert with cam-side retaining wall')
  for pre,xx in [('P01',-36.1),('P02',23.9)]:circle(co(pre),'x',xx,yy,53.5,1.7,12.2,CUT,'Relocated mount above rail counterbore')
 circle(c,'z',51.9,12,-55,2.2,7.2,CUT,'Continue adjuster bore through roof')
 for xx in [5,19]:circle(c,'z',51.9,xx,-55,1.7,7.2,CUT,'Continue guide bore through roof')
 circle(c,'x',-24.1,0,65,51,48.2,CUT,'Restore cam envelope after pocket repair')
 for pre,xx in [('P01',-30),('P02',30)]:
  for yy in [-76,54]:circle(co(pre),'y',yy,xx,45,2.7,22,CUT,'Preserve rail shank passage')
  for yy in [-55,43]:circle(co(pre),'y',yy,xx,45,5.3,12,CUT,'Preserve rail head passage')
 for o in list(root.allOccurrences):
  if o.component.name.startswith(('P15','HARDWARE Cup guide M3','HARDWARE Cup guide washer','HARDWARE Spring block M3','HARDWARE Rail M5','HARDWARE Preload adjuster')):o.deleteMe()
 c=comp(root,'P15 Preload limit collar 2 mm');b=circle(c,'z',59,12,-55,3.3,2,name='One mm extra preload limit');b.name=c.name
 circle(c,'z',58.9,12,-55,2.25,2.2,CUT,'M4 clearance')
 for xx in [5,19]:
  bolt(root,'Cup guide M3x35 '+str(xx),'z',32,67,xx,-55,1.5,2.85,1.65,-1)
  washer(root,'Cup guide washer '+str(xx),'z',59,xx,-55,3.5,1.7,.5)
  nut(root,'Cup guide M3 nut '+str(xx),'z',59.5,xx,-55,5.5,2.4,1.5)
 for yy in [-62,-54]:
  for sx in [-1,1]:bolt(root,'Spring block M3x20 '+str((yy,sx)),'x',sx*36,sx*16,yy,53.5,1.5,2.85,1.65,sx)
 bolt(root,'Preload adjuster M4x25 SOCKET HEAD','z',62,37,12,-55,2,3.5,4,1)
 for xx in [-30,30]:
  for sy in [-1,1]:
   bolt(root,'Rail M5x30 '+str((xx,sy)),'y',sy*50,sy*80,xx,45,2.5,4.75,2.75,-sy)
   washer(root,'Rail M5 metal spacer 5mm '+str((xx,sy)),'y',50 if sy>0 else -55,xx,45,5,2.7,5)
 c=co('P07');box(c,(-5,20,60),(5,22,70),JOIN,'Flat washer seat for sensor-drive shaft clamp')
 circle(c,'y',6.4,0,65,1.7,15.7,CUT,'Radial screw onto printed shaft D flat')
 circle(c,'y',15.2,0,65,2,6.9,CUT,'M3 heatset pocket for rotor clamp')
 bolt(root,'Rotor clamp M3x16','y',22.5,6.5,0,65,1.5,2.85,1.65,1)
 washer(root,'Rotor clamp M3 washer','y',22,0,65,3.5,1.7,.5)
 c=co('P18')
 for f in list(c.features.extrudeFeatures):
  if f.name.startswith(('Input transverse sliding slot','Output perpendicular sliding slot')):f.deleteMe()
 box(c,(51.9,-13,62.9),(54.5,13,67.1),CUT,'Input slot 4.2 mm - tune running fit')
 box(c,(57.5,-2.1,52),(60.1,2.1,78),CUT,'Output slot 4.2 mm - tune running fit')
 for o in root.allOccurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
 print('Final specialist corrections applied: insert walls, bore webs, rail reach, rotor clamp, coupling fit')
