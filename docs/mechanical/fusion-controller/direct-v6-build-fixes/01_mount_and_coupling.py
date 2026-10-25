exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/direct-v6-build-fixes/helpers.py').read())
def run(_context: str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent
 assert C.Application.get().activeDocument.dataFile.id.endswith('2iFF2PJAQnO13x73oN2c-w')
 for j in list(root.asBuiltJoints):j.deleteMe()
 for g in list(root.rigidGroups):g.deleteMe()
 for o in root.occurrences:o.isGrounded=False
 # Preserve shaft and turn impossible axial bush insertion into radial placement.
 c=co(root,'P04')
 f=c.features.splitBodyFeatures.add(c.features.splitBodyFeatures.createInput(c.bRepBodies.item(0),c.xZConstructionPlane,True));f.name='Radial half bushes install around retained shaft'
 for b in c.bRepBodies:b.name='P04 Right bush lower half' if b.boundingBox.maxPoint.y<.001 else 'P04 Right bush upper half'
 # Existing rail tabs are replaced with hanging towers at the original fixed rail seat.
 for pre,x in [('P01',-36),('P02',24)]:
  c=co(root,pre)
  for sg in [-1,1]:
   box(c,(x-.1,-96 if sg<0 else 74.5,54.9),(x+12.1,-74.5 if sg<0 else 96,64.2),CUT,'Remove former rail tab before recess')
   box(c,(x,-74.5 if sg<0 else 63,55),(x+12,-63 if sg<0 else 74.5,99),JOIN,'Continuous recessed hanging tower')
   box(c,(x,-95 if sg<0 else 63,90),(x+12,-63 if sg<0 else 95,99),JOIN,'Top rail seat unchanged after 35 mm drop')
   circle(c,'z',89.9,x+6,sg*85,2.7,9.2,CUT,'Rail clearance at retained world seat')
   q=2.7/math.sqrt(2);sx=1 # both existing plates print X-min down
   poly(c,'z',89.9,[(x+6+q,sg*85-q),(x+6+q,sg*85+q),(x+6+2.7*math.sqrt(2),sg*85)],9.2,CUT,'Rail bore 45 degree print roof')
 # Counterbore bridge layers above P01 stop head seats. X-min down.
 c=co(root,'P01');angle=math.radians(52)+math.acos((30**2+37**2-11**2)/(2*30*37))
 for sg in [-1,1]:
  yy=sg*37*math.sin(angle);zz=65+37*math.cos(angle)
  box(c,(-31.5,yy-3.1,zz-1.7),(-31.3,yy+3.1,zz+1.7),CUT,'Counterbore first anchored bridge relief')
  box(c,(-31.3,yy-1.7,zz-1.7),(-31.1,yy+1.7,zz+1.7),CUT,'Counterbore crossed bridge relief')
 # Adjust sensor supports to measured short shaft and accessible stock nuts.
 c=co(root,'P02')
 for sg in [-1,1]:
  circle(c,'y',21.3 if sg>0 else -28.1,60.15,65,2.01,6.8,JOIN,'Close old insert pocket')
  box(c,(62.95,18 if sg>0 else -28,55.9),(66.3,28 if sg>0 else -18,81.1),CUT,'Measured pot panel inward clearance')
  yy=22.4 if sg>0 else -25
  hexhole(c,'y',yy,58.15,65,5.8,2.6,'Side-loaded carriage nut')
  box(c,(58.15,yy,62.1),(63.05,yy+2.6,67.9),CUT,'Nut insertion from panel end')
  circle(c,'y',20.8 if sg>0 else -28.1,58.15,65,1.7,7.3,CUT,'Carriage screw to captive nut')
 for o in root.occurrences:
  n=o.component.name
  if n.startswith('P16 '):
   m=o.transform2;m.translation=C.Vector3D.create(-.32,0,0);o.transform2=m
  elif n.startswith('HARDWARE Compact carriage'):
   m=o.transform2;m.translation=C.Vector3D.create(-.2,0,0);o.transform2=m
 # Replace old assumed pot envelope with measured body, bushing and shaft.
 for o in list(root.occurrences):
  if o.component.name.startswith(('REFERENCE RK097','HARDWARE RK097 supplied')):o.deleteMe()
 c=comp(root,'REFERENCE Measured potentiometer - terminals unmeasured')
 box(c,(65.95,-5.6,60.25),(72.55,5.6,69.75),name='Measured body 11.2 x 9.5 x 6.6')
 circle(c,'x',58.95,0,65,3.5,7,JOIN,'Inferred 7 mm M7 bushing')
 circle(c,'x',50.95,0,65,3,8,JOIN,'Measured 8 mm rotating shaft')
 washer(root,'Pot supplied washer assumed','x',62.45,0,65,6,3.6,.5)
 nut(root,'Pot supplied M7 nut assumed','x',60.45,0,65,11,2,3.5)
 for sg in [-1,1]:nut(root,'Carriage captured M3 '+str(sg),'y',22.5 if sg>0 else -24.9,58.15,65,5.5,2.4,1.5)
 finishstage(d,'01-mount-and-coupling')
