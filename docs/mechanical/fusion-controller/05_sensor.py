exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())

def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 right=next(o.component for o in root.allOccurrences if o.component.name.startswith('P02'))
 for sg in [-1,1]:
  box(right,(36,18 if sg>0 else -28,49),(80,28 if sg>0 else -18,81),JOIN,'Rigid sensor carriage support')
  circle(right,'y',21.3 if sg>0 else -28.1,74,65,2,6.8,CUT,'M3 sensor carriage heat set')
 c=comp(root,'P16 Sliding replaceable RK097 mount')
 b=box(c,(80,-33,46),(83,33,84),name='Replaceable sensor panel');b.name=c.name
 for sg in [-1,1]:
  box(c,(68,28 if sg>0 else -33,58),(80.1,33 if sg>0 else -28,72),JOIN,'Axially adjustable mounting ear')
  y=27.9 if sg>0 else -33.1
  poly(c,'y',y,[(69,63.3),(79,63.3),(79,66.7),(69,66.7)],5.2,CUT,'Ten mm axial adjustment slot')
  for xx in [69,79]:circle(c,'y',y,xx,65,1.7,5.2,CUT,'Rounded adjustment slot end')
 circle(c,'x',79.9,0,65,3.6,3.2,CUT,'Assumed RK097 M7 panel bushing')
 for yy in [-8,8]:poly(c,'x',79.9,[(yy-1,59),(yy+1,59),(yy+1,71),(yy-1,71)],3.2,CUT,'Optional sensor body tie slot')
 color(c,85,105,120)
 c=comp(root,'P17 Shaft side floating coupling hub')
 b=circle(c,'x',40.5,0,65,7,10,name='Drive stub clamp hub');b.name=c.name
 circle(c,'x',48,0,65,11,2.5,JOIN,'Oldham input flange')
 box(c,(50.5,-8,63),(54.2,8,67),JOIN,'Input sliding tongue')
 # D socket nominal8 mm, replaceable part; small radial screw clamps stub.
 circle(c,'x',40.4,0,65,4.1,10.2,CUT,'Drive stub socket')
 box(c,(40.5,3.35,61),(50.5,4.2,69),JOIN,'D socket key flat')
 circle(c,'y',-7.1,44.5,65,1.25,4.3,CUT,'M3 radial tapped plastic clamp pilot')
 color(c,55,130,185)
 c=comp(root,'P18 Floating cross-slot coupling disc')
 b=circle(c,'x',52,0,65,12,8,name='Floating misalignment disc');b.name=c.name
 box(c,(51.9,-13,62.8),(54.5,13,67.2),CUT,'Input transverse sliding slot')
 box(c,(57.5,-2.2,52),(60.1,2.2,78),CUT,'Output perpendicular sliding slot')
 color(c,235,235,220)
 for sg in [-1,1]:
  c=comp(root,'P19 RK097 clamp insert half' if sg<0 else 'P20 RK097 clamp screw half')
  b=box(c,(62,-9 if sg<0 else .2,54),(72,-.2 if sg<0 else 9,76),name='Replaceable sensor shaft clamp');b.name=c.name
  box(c,(57.8,-2 if sg<0 else .2,57),(62.1,-.2 if sg<0 else 2,73),JOIN,'Output Oldham tongue')
  circle(c,'x',57.7,0,65,3.1,14.4,CUT,'Assumed 6 mm sensor shaft bore')
  for zz in [58,72]:
   if sg<0:circle(c,'y',-7.2,67,zz,2,7.1,CUT,'M3 clamp heat set')
   else:circle(c,'y',.1,67,zz,1.7,9,CUT,'M3 clamp screw clearance')
  color(c,55,130,185)
 c=comp(root,'REFERENCE RK097 ASSUMED envelope - verify actual part')
 b=box(c,(83,-4.75,60.25),(97,4.75,69.75),name='Unmeasured RK097 body clearance');b.name=c.name
 circle(c,'x',76,0,65,3.5,7,JOIN,'Assumed M7 mounting bushing')
 circle(c,'x',64,0,65,3,12,JOIN,'Assumed 6 mm shaft')
 for o in root.allOccurrences:
  o.component.isOriginFolderLightBulbOn=False
  for s in o.component.sketches:s.isLightBulbOn=False
 app.activeViewport.fit();print('Replaceable RK097 carriage and floating coupling built',root.occurrences.count)
