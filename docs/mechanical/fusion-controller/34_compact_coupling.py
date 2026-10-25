"""Compact adjustable Oldham drive; sensor dimensions remain provisional."""
exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])

def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 assert not any(o.component.name.startswith('P19 Compact') for o in root.allOccurrences)
 def co(pre):return next(o.component for o in root.allOccurrences if o.component.name.startswith(pre+' '))
 for o in list(root.allOccurrences):
  if o.component.name.startswith(('P16 ','P17 ','P18 ','P19 ','P20 ','REFERENCE RK097','HARDWARE Coupler clamp','HARDWARE RK097 carriage','HARDWARE RK097 assumed')):o.deleteMe()
 shaft=co('P05')
 box(shaft,(40.35,-12,53),(50.5,12,79),CUT,'Remove separate input hub drive stub')
 box(shaft,(40.35,-8,63),(43.35,6.5,67),JOIN,'Integrated compact Oldham input tongue')
 # Remove old rail extensions completely; build shorter supports.
 right=co('P02')
 box(right,(36,-34,46),(80.1,34,84),CUT,'Remove long sensor carriage supports')
 for sg in [-1,1]:
  box(right,(36,18 if sg>0 else -28,49),(66.15,28 if sg>0 else -18,81),JOIN,'Compact sensor support')
  circle(right,'y',21.3 if sg>0 else -28.1,60.15,65,2,6.8,CUT,'Compact carriage M3 insert')
 c=comp(root,'P16 Compact adjustable RK097 mount')
 b=box(c,(66.15,-33,46),(69.15,33,84),name='Replaceable compact sensor panel');b.name=c.name
 for sg in [-1,1]:
  box(c,(54.15,28 if sg>0 else -33,58),(66.25,33 if sg>0 else -28,72),JOIN,'Compact sliding ear')
  yy=27.9 if sg>0 else -33.1
  poly(c,'y',yy,[(55.15,63.3),(65.15,63.3),(65.15,66.7),(55.15,66.7)],5.2,CUT,'Axial adjustment slot')
  for xx in [55.15,65.15]:circle(c,'y',yy,xx,65,1.7,5.2,CUT,'Rounded slot end')
  bolt(root,'Compact carriage M3x12 '+str(sg),'y',sg*33,sg*21,60.15,65,1.5,2.75,3,sg)
 circle(c,'x',66.05,0,65,3.6,3.2,CUT,'Provisional M7 sensor bushing opening')
 for yy in [-8,8]:poly(c,'x',66.05,[(yy-1,59),(yy+1,59),(yy+1,71),(yy-1,71)],3.2,CUT,'Sensor body retention option')
 color(c,85,105,120)
 c=comp(root,'P18 Compact floating coupling disc')
 b=circle(c,'x',41,0,65,12,8,name='Compact Oldham disc');b.name=c.name
 box(c,(40.9,-13,62.9),(43.8,13,67.1),CUT,'Input groove 4.2 mm')
 box(c,(46.2,-2.1,52),(49.1,2.1,78),CUT,'Output groove 4.2 mm')
 color(c,235,235,220)
 c=comp(root,'P19 Compact one-piece sensor clamp')
 b=circle(c,'x',49.65,0,65,7,9,name='Single split output hub');b.name=c.name
 box(c,(49.65,-9,69),(58.65,9,78),JOIN,'One-screw clamp boss')
 box(c,(46.65,-2,57),(49.75,2,73),JOIN,'Output drive prongs')
 circle(c,'x',46.55,0,65,3.1,12.2,CUT,'Provisional 6 mm sensor through socket')
 box(c,(46.55,-.2,65),(58.75,.2,79),CUT,'Elastic clamp split')
 circle(c,'y',-9.1,54.15,73,2,9.0,CUT,'Accessible CNC Kitchen insert pocket')
 circle(c,'y',.1,54.15,73,1.7,9,CUT,'Clamp screw clearance')
 bolt(root,'Compact sensor clamp M3x16','y',9,-7,54.15,73,1.5,2.75,3,1)
 color(c,55,130,185)
 c=comp(root,'REFERENCE RK097 provisional compact envelope - measure before fit')
 b=box(c,(69.15,-4.75,60.25),(83.15,4.75,69.75),name='Unmeasured sensor body');b.name=c.name
 circle(c,'x',62.15,0,65,3.5,7,JOIN,'Provisional mounting bushing')
 circle(c,'x',50.15,0,65,3,12,JOIN,'Provisional exposed sensor shaft')
 washer(root,'RK097 supplied washer ASSUMED','x',65.65,0,65,6,3.6,.5)
 nut(root,'RK097 supplied nut ASSUMED','x',63.65,0,65,11,2,3.5)
 for o in root.allOccurrences:
  o.component.isOriginFolderLightBulbOn=False
  for s in o.component.sketches:s.isLightBulbOn=False
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in root.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 assert not bad,str(bad)
 print('Compact coupling: 3 printed drive/mount parts instead of5; provisional envelope shortened13.85mm.')
