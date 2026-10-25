exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/opposite-sides/helpers.py').read())

def run(_context:str):
 app,d,r=setup();assert not any(o.component.name.startswith('P01S') for o in r.occurrences)
 for o in list(r.occurrences):
  if o.component.name.startswith(('P01R','P02R','HARDWARE Stop','HARDWARE Crossblock','HARDWARE Top hanging rail')):o.deleteMe()
 for side,x in [(-1,-24),(1,12)]:
  c=comp(r,'P01S Continuous left structural plate' if side<0 else 'P02S Continuous right sensor plate')
  roundrect(c,x,-74.5,-37,74.5,55,4,12,name='Continuous load-bearing web')
  for sy in [-1,1]:
   ya,yb=(-95,-60) if sy<0 else (60,95)
   box(c,(x,ya,51),(x+12,yb,64),JOIN,'Broad rail tab root')
   # Rail starts at |Y|75: seat must remain Z55, not51.
   box(c,(x-.1,-96 if sy<0 else 75,50.9),(x+12.1,-75 if sy<0 else 96,55),CUT,'Rail seat underside')
   circle(c,'z',54.9,x+6,sy*85,2.7,9.2,CUT,'M5 rail bore')
   q=2.7/math.sqrt(2);sg=-1 if side<0 else 1
   poly(c,'z',54.9,[(x+6+sg*q,sy*85-q),(x+6+sg*q,sy*85+q),(x+6+sg*2.7*math.sqrt(2),sy*85)],9.2,CUT,'Rail bore print-up roof')
   bolt(r,'Top rail M5x14 '+str((side,sy)),'z',64,50,x+6,sy*85,2.5,4.25,5,1)
  circle(c,'x',x-.1,0,30,10.15,12.2,CUT,'Main bearing seat')
  for yy in [-60,60]:
   for zz in [35,45]:circle(c,'x',x-.1,yy,zz,1.7,12.2,CUT,'Brace mounting clearance')
  if side<0:
   circle(c,'x',-24.1,-35,-23,4.15,2.1,CUT,'Captured follower axle blind seat')
   for yy in [-55,-15]:
    circle(c,'x',-33.5,yy,-35,8,9.5,JOIN,'Broad cassette mounting boss')
    circle(c,'x',-33.6,yy,-35,2,6.9,CUT,'Cassette insert pocket')
   for yy in [-62,-48]:circle(c,'x',-24.1,yy,14,1.7,12.2,CUT,'Spring block mounting clearance')
   for sg in [-1,1]:
    yy,zz=stopcenter(sg)
    circle(c,'x',-17.3,yy,zz,6.15,5.4,CUT,'Stop shear spigot socket')
    circle(c,'x',-24.1,yy,zz,1.7,7,CUT,'Stop retaining screw passage')
  else:
   roundrect(c,11.9,-8,-27,8,-3,3,10.3,CUT,'Local measured pot and wire opening')
   roundrect(c,22,-24,-30,24,0,3,2.1,CUT,'Pot panel rebate')
   for yy in [-16,16]:
    circle(c,'x',12.5,yy,-15.15,2,9.6,CUT,'Sensor panel insert and screw relief')
  color(c,85,105,120)
 for yy in [-60,60]:
  c=comp(r,'P30 Crossbrace '+str(yy));box(c,(-12,yy-8,30),(12,yy+8,50),name='Rigid plate spacing block')
  for sg in [-1,1]:
   for zz in [35,45]:
    circle(c,'x',-12.1 if sg<0 else 3.5,yy,zz,2,8.6,CUT,'Brace M3 insert relief')
    bolt(r,'Brace M3x20 '+str((yy,sg,zz)),'x',sg*24,sg*4,yy,zz,1.5,2.75,3,sg)
  color(c,85,105,120)
 for sg in [-1,1]:
  yy,zz=stopcenter(sg);c=comp(r,'P31 Positively located stop '+str(sg))
  lathe(c,yy,zz,[(-17,0),(-17,6),(-12,6),(-12,10),(-8,8),(0,8),(0,0)],'Supported stop with shear spigot')
  circle(c,'x',-17.1,yy,zz,2,13.6,CUT,'Stop insert and deep screw-tip relief')
  bolt(r,'Stop M3x20 '+str(sg),'x',-24,-4,yy,zz,1.5,2.75,3,-1)
  color(c,185,110,65)
 done(d,'01-structure')

