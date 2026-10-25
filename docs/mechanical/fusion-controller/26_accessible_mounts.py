exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])

def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 assert app.activeDocument.name.startswith('AIDesignedLever'),'Wrong active design'
 assert not any(o.component.name.startswith('P25') for o in root.allOccurrences),'Mount revision already present'
 if not d.exportManager.execute(d.exportManager.createFusionArchiveExportOptions(ROOTDIR+'/Before-mount-access-fix.f3d')):raise RuntimeError('Checkpoint export failed')
 def co(pre):return next(o.component for o in root.allOccurrences if o.component.name.startswith(pre+' '))
 for pre,x in [('P01',-36),('P02',24)]:
  c=co(pre)
  for yy in [-55,43]:circle(c,'y',yy,x+6,45,5.31,12,JOIN,'Close inaccessible rail head pocket')
  for yy in [-75,55]:circle(c,'y',yy,x+6,45,2.71,20,JOIN,'Close obsolete side rail bore')
  for sg in [-1,1]:
   ya,yb=(-95,-70) if sg<0 else (70,95)
   box(c,(x,ya,55),(x+12,yb,63),JOIN,'Top-access 2020 mounting flange')
   pts=[(63,56),(70,56),(70,63)] if sg>0 else [(-70,56),(-63,56),(-70,63)]
   poly(c,'x',x,pts,12,JOIN,'Mount root triangular reinforcement')
   circle(c,'z',54.9,x+6,sg*85,2.7,8.2,CUT,'Vertical M5 rail mounting bore')
  circle(c,'x',x,-35,12,2.71,12,JOIN,'Close old M5 pivot clearance')
  circle(c,'x',x-.1,-35,12,1.7,12.2,CUT,'M3 follower pivot clearance')
 right=co('P02')
 outer=[(-52*math.sin(math.radians(t)),65-52*math.cos(math.radians(t))) for t in range(-66,67,2)]
 inner=[(-26*math.sin(math.radians(t)),65-26*math.cos(math.radians(t))) for t in range(66,-67,-2)]
 poly(right,'x',23.9,outer+inner,12.2,CUT,'Restore cam service opening after obsolete bore closure')
 left=co('P01');angle=math.radians(52)+math.acos((30**2+37**2-11**2)/(2*30*37))
 for sg in [-1,1]:
  yy=sg*37*math.sin(angle);zz=65+37*math.cos(angle)
  circle(left,'x',-15.4,yy,zz,4.9,6.4,JOIN,'Fill former M5 stop nut pocket')
  circle(left,'x',-36,yy,zz,2.71,27,JOIN,'Fill former M5 stop bore')
  circle(left,'x',-36.1,yy,zz,1.7,27.2,CUT,'M3 stop reinforcement bore')
  rr=5.8/math.sqrt(3)
  poly(left,'x',-13.5,[(yy+rr*math.cos(i*math.pi/3),zz+rr*math.sin(i*math.pi/3)) for i in range(6)],4.6,CUT,'Captive M3 locknut stop pocket')
 old=('HARDWARE Rail M5','HARDWARE Follower pivot M5','HARDWARE Stop steel core M5','HARDWARE Stop retained M5')
 for o in list(root.allOccurrences):
  if o.component.name.startswith(old):o.deleteMe()
 for xx in [-30,30]:
  for sg in [-1,1]:
   bolt(root,'Rail vertical M5x16 '+str((xx,sg)),'z',66,50,xx,sg*85,2.5,4.75,2.75,1)
   washer(root,'Rail M5 metal spacer 3mm '+str((xx,sg)),'z',63,xx,sg*85,5,2.7,3)
 bolt(root,'Follower pivot M3x80','x',-36.5,43.5,-35,12,1.5,2.85,1.65,-1)
 for xx in [-36.5,36]:washer(root,'Follower pivot M3 washer '+str(xx),'x',xx,-35,12,3.5,1.7,.5)
 nut(root,'Follower pivot M3 locknut','x',36.5,-35,12,5.5,4,1.5)
 for sg in [-1,1]:
  yy=sg*37*math.sin(angle);zz=65+37*math.cos(angle)
  bolt(root,'Stop steel core M3x30 '+str(sg),'x',-36.5,-6.5,yy,zz,1.5,2.85,1.65,-1)
  washer(root,'Stop M3 washer '+str(sg),'x',-36.5,yy,zz,3.5,1.7,.5)
  nut(root,'Stop retained M3 locknut '+str(sg),'x',-13.5,yy,zz,5.5,4,1.5)
 for pre,xx in [('P25 Left pivot sleeve centering insert',-24),('P26 Right pivot sleeve centering insert',18)]:
  c=comp(root,pre);b=circle(c,'x',xx,-35,12,2.5,6,name='Center M3 bolt in retained metal pivot sleeve');b.name=c.name
  circle(c,'x',xx-.1,-35,12,1.7,6.2,CUT,'M3 running clearance')
 for o in root.allOccurrences:
  if o.component.name.startswith(('HARDWARE Rail','HARDWARE Follower pivot','HARDWARE Stop','P25','P26')):o.isGrounded=True
  for s in o.component.sketches:s.isLightBulbOn=False
  o.component.isOriginFolderLightBulbOn=False
 print('Accessible top-slot M5 mounts and M3 nut-retained stops/pivot built. Frame unchanged.')
