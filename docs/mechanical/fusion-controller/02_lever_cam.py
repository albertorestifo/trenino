exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())

def dcut(c,x,length,r,flat,name):
 s=sk(c,'x',x,name);h=math.sqrt(r*r-flat*flat)
 a=s.modelToSketchSpace(p(x,flat,65+h));m=s.modelToSketchSpace(p(x,-r,65));b=s.modelToSketchSpace(p(x,flat,65-h))
 s.sketchCurves.sketchArcs.addByThreePoints(a,m,b);s.sketchCurves.sketchLines.addByTwoPoints(b,a)
 return finish(c,s,'x',length,CUT,name)

def campt(t,n,lift=1.4):
 pitch=math.radians(100/(n-1));phase=2*math.pi*(t+math.radians(50))/pitch
 beta=-.5*lift*(1-math.cos(phase))/35
 bp=-lift*math.pi/(pitch*35)*math.sin(phase)
 y=-35+35*math.cos(beta);z=-53+35*math.sin(beta)
 yp=-35*bp*math.sin(beta);zp=35*bp*math.cos(beta)
 co=math.cos(t);si=math.sin(t)
 q=(co*y+si*z,-si*y+co*z)
 dy=yp+z;dz=zp-y
 qp=(co*dy+si*dz,-si*dy+co*dz)
 normal=(qp[1],-qp[0]);nn=math.hypot(*normal);normal=tuple(v/nn for v in normal)
 if sum(a*b for a,b in zip(normal,q))<0:normal=tuple(-v for v in normal)
 return (q[0]-5*normal[0],65+q[1]-5*normal[1])

def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 c=comp(root,'P07 Integral lever rotor and cam carrier')
 b=circle(c,'x',-7,0,65,22,14,name='Main lever hub');b.name=c.name
 poly(c,'x',-7,[(-14,60),(14,60),(11,95),(7,150),(7,195),(-7,195),(-7,150),(-11,95)],14,JOIN,'Continuous reinforced lever stem')
 arc=[(0,65)]+[(-41*math.sin(math.radians(t)),65-41*math.cos(math.radians(t))) for t in range(-60,61,3)]
 poly(c,'x',-7,arc,14,JOIN,'Integrated cam carrier fan')
 circle(c,'x',-23.6,0,65,10,47.2,JOIN,'Integral axial locating hub')
 dcut(c,-24,48,8.1,6.65,'D shaft socket')
 for a in [-45,0,45]:
  y=-36*math.sin(math.radians(a));z=65-36*math.cos(math.radians(a))
  circle(c,'x',.3,y,z,2,6.8,CUT,'Cam M3 insert pocket')
 for z in [180,190]:circle(c,'x',-8,0,z,1.7,16,CUT,'Grip through bolt')
 color(c,45,115,170)
 for n in [7,5,3]:
  c=comp(root,'P08 Cam '+str(n)+' gates - stable endpoints')
  outer=[campt(math.radians(-60+i*.3),n) for i in range(401)]
  inner=[(-29*math.sin(math.radians(t)),65-29*math.cos(math.radians(t))) for t in range(60,-61,-3)]
  b=poly(c,'x',7,outer+inner,8,name='Roller compensated replaceable cam');b.name=c.name
  for a in [-45,0,45]:
   y=-36*math.sin(math.radians(a));z=65-36*math.cos(math.radians(a))
   circle(c,'x',6.9,y,z,1.7,8.2,CUT,'Cam screw clearance')
   circle(c,'x',12,y,z,3.1,3.1,CUT,'Cam head recess')
  color(c,225,155,45)
  if n!=7:root.occurrences.item(root.occurrences.count-1).isLightBulbOn=False
 for side in [-1,1]:
  c=comp(root,'P09 Grip insert half' if side<0 else 'P10 Grip screw half')
  s=sk(c,'x',0,'Palm grip smooth contour')
  pts=C.ObjectCollection.create()
  for y,z in [(12,165),(14,170),(18,185),(20,205),(18,217),(10,223),(0,225)]:pts.add(s.modelToSketchSpace(p(0,y,z)))
  s.sketchCurves.sketchFittedSplines.add(pts)
  origin=s.modelToSketchSpace(p(0,0,165));tip=s.modelToSketchSpace(p(0,0,225));base=s.modelToSketchSpace(p(0,12,165))
  axis=s.sketchCurves.sketchLines.addByTwoPoints(origin,tip)
  s.sketchCurves.sketchLines.addByTwoPoints(origin,base)
  s.isComputeDeferred=False
  ri=c.features.revolveFeatures.createInput(s.profiles.item(0),axis,NEW);ri.setAngleExtent(False,C.ValueInput.createByString('360 deg'))
  rev=c.features.revolveFeatures.add(ri);rev.name='Smooth railway palm grip';rev.bodies.item(0).name=c.name;s.isLightBulbOn=False
  if side<0:box(c,(0,-30,160),(30,30,230),CUT,'Split on print bed face')
  else:box(c,(-30,-30,160),(0,30,230),CUT,'Split on print bed face')
  box(c,(-7.2,-7.2,164),(7.2,7.2,196),CUT,'Keyed stem socket')
  for z in [180,190]:
   if side<0:circle(c,'x',-13.9,0,z,2,6.8,CUT,'M3 grip heat set')
   else:
    circle(c,'x',-.1,0,z,1.7,26,CUT,'Grip screw bore')
    circle(c,'x',12.5,0,z,3.1,14,CUT,'Recessed grip screw head')
  color(c,35,40,45)
 for o in root.allOccurrences:
  o.component.isOriginFolderLightBulbOn=False
  for s in o.component.sketches:s.isLightBulbOn=False
 app.activeViewport.fit()
 print('Lever and three interchangeable cam profiles created; components',root.occurrences.count,'timeline',d.timeline.count)
