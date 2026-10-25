exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/opposite-sides/helpers.py').read())

def run(_context:str):
 app,d,r=setup();assert not any(o.component.name.startswith('P05S') for o in r.occurrences)
 for o in list(r.occurrences):
  if o.component.name.startswith(('P05G','P06 ','P07 ','P23 ','P24 ','P28 ','HARDWARE Shaft joining','HARDWARE Main shaft cap','HARDWARE Rotor clamp')):o.deleteMe()
 c=comp(r,'P05S Split structural shaft')
 circle(c,'x',-38,0,30,6,63.35,name='Left drive and round journals')
 box(c,(-38.1,4.8,23.9),(-25.35,6.1,36.1),CUT,'Left drive D flat')
 dprofile(c,-11.8,23.6,8,6.5,op=JOIN,name='Central structural D section')
 dprofile(c,25.35,11,4,3.2,op=JOIN,name='Pass-through right D drive')
 circle(c,'x',-38.1,0,30,2,6.9,CUT,'Axial retaining insert')
 for xx in [-8,8]:
  circle(c,'y',-6.8,xx,30,2,6.9,CUT,'Shaft half insert')
  circle(c,'y',-.1,xx,30,1.7,6.7,CUT,'Shaft half screw')
  circle(c,'y',3.5,xx,30,3.1,3.1,CUT,'Flush joining head')
  bolt(r,'Shaft joining M3x8 '+str(xx),'y',3.5,-4.5,xx,30,1.5,2.75,3,1)
 box(c,(-1.6,-1.6,26),(1.6,1.6,34),CUT,'Central loose key pocket')
 c.features.splitBodyFeatures.add(c.features.splitBodyFeatures.createInput(c.bRepBodies.item(0),c.xZConstructionPlane,True))
 assert c.bRepBodies.count==2
 for b in c.bRepBodies:b.name='P05S Shaft lower half' if b.boundingBox.maxPoint.y<.001 else 'P05S Shaft upper half'
 color(c,55,130,185)
 c=comp(r,'P28 Shaft alignment key');box(c,(-1.5,-1.5,26.1),(1.5,1.5,33.9),name='Loose printable key')
 c=comp(r,'P06 Shaft retaining cap');circle(c,'x',-40,0,30,10,2,name='Axial retaining cap');circle(c,'x',-40.1,0,30,1.7,2.2,CUT,'M3 passage')
 bolt(r,'Main shaft cap M3x8','x',-40,-32,0,30,1.5,2.75,3,-1)
 c=comp(r,'P07S Planar lever rotor with lower stop lug')
 circle(c,'x',-7,0,30,22,14,name='Main lever hub')
 poly(c,'x',-7,[(-14,25),(14,25),(11,60),(7,115),(7,160),(-7,160),(-7,115),(-11,60)],14,JOIN,'Continuous grip stem')
 poly(c,'x',-7,[(-11,15),(-6,0),(6,0),(11,15)],14,JOIN,'Broad lower stop root')
 circle(c,'x',-7,0,0,5,14,JOIN,'Round lower stop nose')
 dprofile(c,-7.1,14.2,8.1,6.65,name='Rotor keyed socket')
 for zz in [145,155]:circle(c,'x',-7.1,0,zz,1.7,14.2,CUT,'Grip screw clearance')
 box(c,(-5,21.4,25),(5,22.5,35),JOIN,'Rotor clamp head seat')
 circle(c,'y',15.7,0,30,2,6.8,CUT,'Rotor clamp insert')
 circle(c,'y',6.6,0,30,1.7,9.2,CUT,'Rotor clamp tip passage')
 # X-min face down: roof in +X for the radial bores.
 for ya,dep,rad in [(15.7,6.8,2),(6.6,9.2,1.7)]:
  q=rad/math.sqrt(2);poly(c,'y',ya,[(q,30-q),(q,30+q),(rad*math.sqrt(2),30)],dep,CUT,'Radial bore print roof')
 bolt(r,'Rotor clamp M3x16','y',22.5,6.5,0,30,1.5,2.75,3,1)
 color(c,45,115,170)
 for pre,xa in [('P23',-11.8),('P24',7)]:
  c=comp(r,pre+' Rotor thrust spacer');circle(c,'x',xa,0,30,10,4.8,name='Independent thrust spacer');dprofile(c,xa-.1,5,8.15,6.7,name='D clearance')
 c=comp(r,'P32 External keyed cam carrier')
 circle(c,'x',-38,0,30,14,12.5,name='Cam carrier hub')
 pts=[(0,30)]+[(-41*math.sin(math.radians(t)),30-41*math.cos(math.radians(t))) for t in range(-65,66)]
 poly(c,'x',-33,pts,7.5,JOIN,'Full cam support fan')
 dprofile(c,-38.1,12.7,6.15,4.95,name='Left shaft keyed socket')
 circle(c,'x',-25.8,0,30,13,.4,CUT,'Flange clearance and axial float relief')
 box(c,(-37,11.5,25),(-28,14.8,35),JOIN,'Carrier clamp accessible boss')
 circle(c,'y',8,-32.5,30,2,6.9,CUT,'Carrier clamp insert')
 circle(c,'y',4.9,-32.5,30,1.7,3.2,CUT,'Carrier clamp tip passage')
 for ya,dep,rad in [(8,6.9,2),(4.9,3.2,1.7)]:
  q=rad/math.sqrt(2);poly(c,'y',ya,[(-32.5-q,30-q),(-32.5-q,30+q),(-32.5-rad*math.sqrt(2),30)],dep,CUT,'Carrier radial bore negative X roof')
 bolt(r,'Carrier clamp M3x10','y',14.8,4.8,-32.5,30,1.5,2.75,3,1)
 for a in [-45,0,45]:
  yy=-36*math.sin(math.radians(a));zz=30-36*math.cos(math.radians(a))
  circle(c,'x',-33.1,yy,zz,2,6.9,CUT,'Face-access cam insert')
 color(c,45,115,170)
 # Apply all placements only after modeling is complete.
 for o in r.occurrences:
  name=o.component.name
  if name.startswith(('P03 ','P04 ')):
   m=o.transform2;v=m.translation;v.x+=1.2 if name.startswith('P03') else -1.2;m.translation=v;o.transform2=m
  elif name.startswith(('G01','G02','HARDWARE G01','HARDWARE G02','HARDWARE Geared','REFERENCE Geared')):
   m=o.transform2;v=m.translation;v.x-=1.2;m.translation=v;o.transform2=m
  elif name.startswith(('P08 ','HARDWARE Cam M3')):
   m=C.Matrix3D.create();m.setToRotation(math.pi,C.Vector3D.create(0,0,1),p(0,0,0));m.translation=C.Vector3D.create(-2.6,0,-3.5);o.transform2=m
 done(d,'02-rotating')

