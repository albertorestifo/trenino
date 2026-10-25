exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())

def hexcut(c,axis,pos,u,v,af,depth,name):
 r=af/math.sqrt(3)
 return poly(c,axis,pos,[(u+r*math.cos(i*math.pi/3),v+r*math.sin(i*math.pi/3)) for i in range(6)],depth,CUT,name)

def get(root,prefix):return next(o.component for o in root.allOccurrences if o.component.name.startswith(prefix))

def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 c=comp(root,'P11 Forked roller follower')
 shape=[(-61,6),(-5,6),(0,7),(0,17),(-5,18),(-61,18)]
 b=poly(c,'x',4,shape,3,name='First strong flat cheek');b.name=c.name
 box(c,(4,-61,6),(20,-49,18),JOIN,'Spring tail bridge')
 poly(c,'x',17,shape,3,JOIN,'Second supporting cheek')
 for xx in [4,17]:circle(c,'x',xx,0,12,6,3,JOIN,'Rounded roller cheek')
 circle(c,'x',3.9,-35,12,4.15,16.2,CUT,'Smooth pivot sleeve bore')
 circle(c,'x',3.9,0,12,1.7,16.2,CUT,'Roller axle holes')
 # Axle head on right, nut on left; washers keep rotating roller free.
 hexcut(c,'x',3.9,0,12,5.8,1.6,'Roller M3 nut recess')
 circle(c,'z',18,12,-55,1.8,2,JOIN,'Spring tail locating pilot')
 color(c,55,155,140)
 c=comp(root,'P12 Replaceable plain roller')
 b=circle(c,'x',7.25,0,12,5,9.5,name='10 mm roller');b.name=c.name
 circle(c,'x',7.1,0,12,2.15,9.8,CUT,'Roller spacer tube bore');color(c,235,235,220)
 c=comp(root,'P13 Spring reaction crossblock')
 b=box(c,(-24,-66,38),(24,-44,52),name='Captured spring reaction block');b.name=c.name
 for yy in [-59,-51]:
  circle(c,'x',-24.1,yy,44,2,8.8,CUT,'Left M3 insert with screw tip relief')
  circle(c,'x',15.3,yy,44,2,8.8,CUT,'Right M3 insert with screw tip relief')
 circle(c,'z',37.9,12,-55,2.2,14.2,CUT,'M4 preload adjuster')
 hexcut(c,'z',37.9,12,-55,7.4,3.5,'Spring-side loaded retained M4 nut')
 for xx in [5,19]:circle(c,'z',37.9,xx,-55,1.7,14.2,CUT,'Spring cup guide bolts')
 color(c,85,105,120)
 c=comp(root,'P14 Captive spring cup')
 b=box(c,(1.5,-61,35),(22.5,-49,37),name='Spring seat');b.name=c.name
 circle(c,'z',27,12,-55,2,8,JOIN,'Spring centering pilot')
 for xx in [5,19]:circle(c,'z',34.9,xx,-55,1.8,2.2,CUT,'Sliding guide clearance')
 color(c,55,155,140)
 c=comp(root,'P15 Preload limit collar 9 mm')
 b=circle(c,'z',52,12,-55,4,9,name='Limit added preload to 1 mm');b.name=c.name
 circle(c,'z',51.9,12,-55,2.25,9.2,CUT,'M4 clearance');color(c,85,105,120)
 # A dedicated left-side lug keeps stops away from the cam and stem sweep.
 rotor=get(root,'P07')
 box(rotor,(-18,-5,72),(-6.5,5,95),JOIN,'Dedicated thick stop lug')
 circle(rotor,'x',-18,0,95,5,11.5,JOIN,'Rounded stop contact')
 left=get(root,'P01')
 angle=math.radians(52)+math.acos((30**2+37**2-11**2)/(2*30*37))
 for sign in [-1,1]:
  yy=sign*37*math.sin(angle);zz=65+37*math.cos(angle)
  box(left,(-36,20 if sign>0 else -44,60),(-24,44 if sign>0 else -20,90),JOIN,'Broad stop support ear')
  circle(left,'x',-24,yy,zz,6,15,JOIN,'Integrated steel-core end stop')
  circle(left,'x',-36.1,yy,zz,2.7,27.2,CUT,'M5 stop reinforcement bolt')
  hexcut(left,'x',-15.4,yy,zz,8.4,6.5,'M5 captive stop nut')
 print('Stop centers at',37*math.sin(angle),65+37*math.cos(angle),'limit degrees 52')
 # Reference tubes are hardware, not printed.
 for name,x,y,z,ro,ri,length in [('H01 Pivot sleeve 8OD 5.2ID x48',-24,-35,12,4,2.6,48),('H02 Roller spacer 4OD 3.2ID x10',7,0,12,2,1.6,10)]:
  c=comp(root,'HARDWARE '+name);b=circle(c,'x',x,y,z,ro,length,name=name);b.name=c.name
  circle(c,'x',x-.1,y,z,ri,length+.2,CUT,'Metal tube bore')
 c=comp(root,'REFERENCE spring 8OD 5ID - 17 mm installed')
 b=circle(c,'z',18,12,-55,4,17,name='Spring working envelope');b.name=c.name
 circle(c,'z',17.9,12,-55,2.5,17.2,CUT,'Spring internal clearance')
 for o in root.allOccurrences:
  o.component.isOriginFolderLightBulbOn=False
  for s in o.component.sketches:s.isLightBulbOn=False
 app.activeViewport.fit();print('Follower, retained preload and independent stops built',root.occurrences.count)
