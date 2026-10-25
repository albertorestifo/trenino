exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])
def run(_context:str):
 root=F.Design.cast(C.Application.get().activeProduct).rootComponent
 left=next(o.component for o in root.allOccurrences if o.component.name.startswith('P01 '))
 angle=math.radians(52)+math.acos((30**2+37**2-11**2)/(2*30*37))
 for o in list(root.allOccurrences):
  if o.component.name.startswith(('HARDWARE Stop steel core M3x30','HARDWARE Stop retained M3 locknut')):o.deleteMe()
 for sg in [-1,1]:
  yy=sg*37*math.sin(angle);zz=65+37*math.cos(angle);rr=5.8/math.sqrt(3)
  poly(left,'x',-17.5,[(yy+rr*math.cos(i*math.pi/3),zz+rr*math.sin(i*math.pi/3)) for i in range(6)],4.01,CUT,'Recess M3 locknut to keep bolt inside stop')
  bolt(root,'Stop steel core M3x25 '+str(sg),'x',-36.5,-11.5,yy,zz,1.5,2.85,1.65,-1)
  nut(root,'Stop retained M3 locknut '+str(sg),'x',-17.5,yy,zz,5.5,4,1.5)
 for o in root.allOccurrences:
  if o.component.name.startswith('HARDWARE Stop'):o.isGrounded=True
  for s in o.component.sketches:s.isLightBulbOn=False
 print('M3x25 stop bolts stay inside posts, with2 mm beyond locknuts')
