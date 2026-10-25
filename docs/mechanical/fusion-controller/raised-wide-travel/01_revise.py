exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])
OUT=ROOTDIR+'/raised-wide-travel'
ID='urn:adsk.wipprod:dm.lineage:peR4meb5QLiO5tE5ANITQg'

def campt(t,n):
 pitch=math.radians(116/(n-1));phase=2*math.pi*(t+math.radians(58))/pitch
 beta=-.5*1.4*(1-math.cos(phase))/35
 bp=-1.4*math.pi/(pitch*35)*math.sin(phase)
 y=-35+35*math.cos(beta);z=-53+35*math.sin(beta)
 yp=-35*bp*math.sin(beta);zp=35*bp*math.cos(beta)
 co=math.cos(t);si=math.sin(t);q=(co*y+si*z,-si*y+co*z)
 qp=(co*(yp+z)+si*(zp-y),-si*(yp+z)+co*(zp-y))
 normal=(qp[1],-qp[0]);nn=math.hypot(*normal);normal=tuple(v/nn for v in normal)
 if sum(a*b for a,b in zip(normal,q))<0:normal=tuple(-v for v in normal)
 return q[0]-5*normal[0],65+q[1]-5*normal[1]

def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);r=d.rootComponent
 assert app.activeDocument.dataFile.id==ID
 assert d.userParameters.itemByName('PivotHeight').expression=='18 mm'
 # Shorten hanging arms by 12 mm, keeping their seats on the original rail top.
 for pre,x in [('P01R',-36),('P02R',24)]:
  c=next(o.component for o in r.occurrences if o.component.name.startswith(pre))
  for f in reversed(list(c.features.extrudeFeatures)):
   if f.name.startswith(('Top rail hanging suspension arm','Top-access M5 mounting clearance','Preserve crossblock screw through suspension arm')):f.deleteMe()
  for sg in [-1,1]:
   poly(c,'x',x,[(sg*y,z) for y,z in [(55,33),(74.5,33),(74.5,90),(95,90),(95,99),(65,99),(55,57)]],12,JOIN,'Shorter top rail hanger')
   circle(c,'z',89.9,x+6,sg*85,2.7,9.2,CUT,'Rail M5 clearance')
  for yy in [-62,-70]:circle(c,'x',x-.1,yy,53.5,1.7,12.2,CUT,'Restore crossblock passage')
 # Remove the old stop features as a set, rebuilding around the wider travel.
 c=next(o.component for o in r.occurrences if o.component.name.startswith('P01R'))
 for f in reversed(list(c.features.extrudeFeatures)):
  if any(s in f.name.lower() for s in ['steel-core end stop','stop reinforcement','stop nut','stop bore','locknut stop','locknut to keep bolt inside stop','stop recessed cap head']):f.deleteMe()
 for o in list(r.occurrences):
  if o.component.name.startswith(('HARDWARE Stop','P08 Cam','REFERENCE Geared','REFERENCE Locomotive')):o.deleteMe()
 angle=math.radians(60)+math.acos((30**2+37**2-11**2)/(2*30*37))
 for sg in [-1,1]:
  yy=sg*37*math.sin(angle);zz=65+37*math.cos(angle)
  circle(c,'x',-24,yy,zz,6,15,JOIN,'120 degree steel core stop')
  circle(c,'x',-36.1,yy,zz,1.7,27.2,CUT,'M3 stop core bore')
  rr=5.7/math.sqrt(3)
  poly(c,'x',-17.5,[(yy+rr*math.cos(i*math.pi/3),zz+rr*math.sin(i*math.pi/3)) for i in range(6)],4.01,CUT,'M3 captive plain nut')
  circle(c,'x',-36.1,yy,zz,3.1,4.6,CUT,'M3x20 stop head recess')
  bolt(r,'Stop M3x20 cap head '+str(sg),'x',-31.5,-11.5,yy,zz,1.5,2.75,3,-1)
  nut(r,'Stop M3 plain captive nut '+str(sg),'x',-17.5,yy,zz,5.5,2.4,1.5)
  for o in list(r.occurrences)[-2:]:
   m=C.Matrix3D.create();m.translation=C.Vector3D.create(0,0,-4.7);o.transform2=m
 # New 116 degree gate span; two degrees of travel beyond each terminal gate.
 for n in [8,7,5,3]:
  c=comp(r,'P08 Cam '+str(n)+' gates - 116 degree span')
  outer=[campt(math.radians(-70+i*.25),n) for i in range(561)]
  inner=[(-29*math.sin(math.radians(t)),65-29*math.cos(math.radians(t))) for t in range(70,-71,-2)]
  b=poly(c,'x',7,outer+inner,8,name='Roller compensated wide travel cam');b.name=c.name
  for a in [-45,0,45]:
   y=-36*math.sin(math.radians(a));z=65-36*math.cos(math.radians(a))
   circle(c,'x',6.9,y,z,1.7,8.2,CUT,'Cam screw clearance');circle(c,'x',12,y,z,3.1,3.1,CUT,'Cam head recess')
  color(c,225,155,45)
  o=r.occurrences.item(r.occurrences.count-1);m=C.Matrix3D.create();m.translation=C.Vector3D.create(0,0,-4.7);o.transform2=m;o.isLightBulbOn=n==8
 # User measurements, in the existing sensor local coordinate system.
 c=comp(r,'REFERENCE Geared pot user measured 2026-10-25')
 b=box(c,(27.4,-5.6,105.4),(34,5.6,114.9),name='Measured body 11.2 x 9.5 x 6.6 excluding terminals');b.name=c.name
 circle(c,'x',34,0,110.15,3.5,7,JOIN,'M7 bushing length inferred 15 minus 8')
 circle(c,'x',41,0,110.15,3,8,JOIN,'Measured rotating shaft diameter6 length8')
 o=r.occurrences.item(r.occurrences.count-1);m=C.Matrix3D.create();m.setToRotation(math.pi,C.Vector3D.create(1,0,0),p(0,0,65));v=m.translation;v.z-=4.7;m.translation=v;o.transform2=m
 for o in r.occurrences:
  if o.component.name.startswith(('REFERENCE - fixed','HARDWARE Top hanging rail')):continue
  o.isGrounded=False;m=o.transform2;v=m.translation;v.z+=1.2;m.translation=v;o.transform2=m
  for s in o.component.sketches:s.isLightBulbOn=False
 if d.snapshots.hasPendingSnapshot:d.snapshots.add()
 d.userParameters.itemByName('PivotHeight').expression='30 mm'
 d.userParameters.itemByName('LeverTravel').expression='116 deg'
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in r.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 assert not bad,str(bad)
 app.activeViewport.fit()
 print(json.dumps({'pivot_mm':30,'gear_top_mm':61.25,'pot_center_mm':-15.15,'stops_deg':[-60,60],'gate_span_deg':116,'native_health':bad}))
