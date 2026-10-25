exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/opposite-sides/helpers.py').read())

def run(_context:str):
 app,d,r=setup();assert not any(o.component.name.startswith('P33 ') for o in r.occurrences)
 for o in list(r.occurrences):
  if o.component.name.startswith(('P13 ','P21 ','P22 ','P25 ','P26 ','G03R','HARDWARE Lower panel','HARDWARE Stop M3x20')):o.deleteMe()
 shaft=next(o.component for o in r.occurrences if o.component.name.startswith('P05S'))
 for sketch in shaft.sketches:
  if sketch.name.startswith(('Shaft half insert','Shaft half screw','Flush joining head')):
   point=sketch.sketchCurves.sketchCircles.item(0).centerSketchPoint
   old=point.geometry;target=sketch.sketchToModelSpace(old);target.x+=-.05 if target.x>0 else .05
   assert point.move(old.vectorTo(sketch.modelToSketchSpace(target)))
 rotor=next(o.component for o in r.occurrences if o.component.name.startswith('P07S'))
 for sg in [-1,1]:poly(rotor,'x',-7.1,[(sg*5,0),(sg*6,0),(sg*11,15)],14.2,CUT,'Restore exact stop nose contact')
 left=next(o.component for o in r.occurrences if o.component.name.startswith('P01S'))
 for f in reversed(list(left.features.extrudeFeatures)):
  if f.name.startswith(('Broad cassette mounting boss','Cassette insert pocket')):f.deleteMe()
 box(left,(-24,-74.5,-45),(-12,74.5,-33),JOIN,'Continuous lower cassette foundation')
 for yy in [-55,-15]:
  circle(left,'x',-33.5,yy,-39,6,9.5,JOIN,'Lowered cassette mounting boss')
  circle(left,'x',-33.6,yy,-39,2,6.9,CUT,'Cassette insert pocket')
 for sg in [-1,1]:
  yy,zz=stopcenter(sg)
  circle(left,'x',-24.1,yy,zz,3.1,3.1,CUT,'Flush stop head clears external cam sweep')
  bolt(r,'Stop M3x16 '+str(sg),'x',-21,-5,yy,zz,1.5,2.75,3,-1)
 circle(left,'x',-24,-48,14,1.71,12,JOIN,'Close superseded spring block hole')
 circle(left,'x',-24.1,-54,14,1.7,12.2,CUT,'Inboard spring block mounting clearance')
 c=comp(r,'P33 Outer follower support')
 poly(c,'x',-49.2,[(-65,-46),(-5,-46),(-5,-30),(-25,-15),(-65,-15)],4,name='Cam-clear follower support plate')
 circle(c,'x',-47.2,-35,-23,4.15,2.1,CUT,'Captured axle blind seat bridge')
 for yy in [-55,-15]:
  circle(c,'x',-49.3,yy,-39,1.7,4.2,CUT,'Support screw passage')
  circle(c,'x',-49.3,yy,-39,3.1,2.1,CUT,'Recessed cap head')
  bolt(r,'Cassette M3x20 '+str(yy),'x',-47.2,-27.2,yy,-39,1.5,2.75,3,-1)
  cc=comp(r,'P34 Cassette compression spacer '+str(yy));circle(cc,'x',-45.2,yy,-39,6,11.7,name='Compression spacer');circle(cc,'x',-45.3,yy,-39,1.7,11.9,CUT,'M3 clearance')
 yy=-35-20*math.cos(math.radians(4));zz=-23+20*math.sin(math.radians(4))
 circle(c,'x',-49.3,yy,zz,1.7,4.2,CUT,'Service screw absolute minus4 degrees')
 color(c,85,105,120)
 for name,upper in [('P25 Captured follower axle lower half',False),('P26 Captured follower axle upper half',True)]:
  c=comp(r,name);circle(c,'x',-47.05,-35,-23,4,24.9,name='Captured axle')
  box(c,(-47.1,-35 if not upper else -40,-28),(-22.1,-30 if not upper else -35,-18),CUT,'Flat split face')
 c=comp(r,'P21 Follower inner thrust spacer');circle(c,'x',-29,-35,-23,6,4.8,name='Follower axial spacer');circle(c,'x',-29.1,-35,-23,4.15,5,CUT,'Pivot clearance')
 c=comp(r,'P13 Outboard spring reaction block')
 box(c,(-49,-66,3),(-24,-50,24),name='Outboard spring reaction body')
 for xx in [-45,-29,-37]:circle(c,'z',2.9,xx,-55,2,6.9,CUT,'Underside M3 insert')
 circle(c,'z',9.7,-37,-55,1.7,14.4,CUT,'Preload screw passage')
 circle(c,'z',20,-37,-55,3.4,4.1,CUT,'Preload collar recess')
 for yy in [-62,-54]:
  circle(c,'x',-32.5,yy,14,2,8.6,CUT,'Spring mount insert and tip relief')
  # Print Zmax down: roof towards -Z.
  q=2/math.sqrt(2);poly(c,'x',-32.5,[(yy-q,14-q),(yy+q,14-q),(yy,14-2*math.sqrt(2))],8.6,CUT,'Mount bore print-down crown')
  bolt(r,'Spring block M3x20 '+str(yy),'x',-12,-32,yy,14,1.5,2.75,3,1)
 color(c,85,105,120)
 fork=next(o.component for o in r.occurrences if o.component.name.startswith('P11 '))
 # Native follower coordinates before its -49 X, -35 Z placement.
 circle(fork,'x',3.9,-55,12,2,8.6,CUT,'Retained service screw insert and tip relief')
 q=2/math.sqrt(2);poly(fork,'x',3.9,[(-55-q,12+q),(-55+q,12+q),(-55,12+2*math.sqrt(2))],8.6,CUT,'Service insert printable crown')
 c=comp(r,'G03S Compact adjustable pot panel')
 roundrect(c,22,-23.7,-29.7,23.7,-.3,3,3,name='Narrow lower sensor panel')
 circle(c,'x',21.9,0,-15.15,3.6,3.2,CUT,'Measured pot bushing clearance')
 # Allows center distance45.0..45.5, slot center offset accordingly.
 for yy in [-16,16]:
  poly(c,'x',21.9,[(yy-1.7,-17),(yy+1.7,-17),(yy+1.7,-13.1),(yy-1.7,-13.1)],3.2,CUT,'Controlled mesh adjustment slot')
  bolt(r,'Pot panel M3x12 '+str(yy),'x',25,13,yy,-15.15,1.5,2.75,3,1)
 color(c,95,155,100)
 for o in r.occurrences:
  if o.component.name.startswith('HARDWARE Shaft joining'):
   m=o.transform2;v=m.translation;v.x+=.05 if '-8' in o.component.name else -.05;m.translation=v;o.transform2=m
  if o.component.name.startswith(('P11 ','HARDWARE Roller axle','HARDWARE 623ZZ','P27 ','HARDWARE Cup guide','P14 ','P15 ','HARDWARE Preload','REFERENCE Stock spring')):
   m=o.transform2;v=m.translation;v.x-=4.9;m.translation=v;o.transform2=m
 done(d,'03-detent-sensor')
