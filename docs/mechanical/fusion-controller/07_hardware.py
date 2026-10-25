exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())

def bolt(root,name,axis,seat,tip,u,v,r,hr,hh,sign):
 c=comp(root,'HARDWARE '+name)
 b=circle(c,axis,min(seat,tip),u,v,r,abs(tip-seat),name=name);b.name=c.name
 circle(c,axis,seat if sign>0 else seat-hh,u,v,hr,hh,JOIN,'Button head')
 return c

def nut(root,name,axis,start,u,v,af,h,r):
 c=comp(root,'HARDWARE '+name);rr=af/math.sqrt(3)
 b=poly(c,axis,start,[(u+rr*math.cos(i*math.pi/3),v+rr*math.sin(i*math.pi/3)) for i in range(6)],h,name=name);b.name=c.name
 circle(c,axis,start-.1,u,v,r,h+.2,CUT,'Thread envelope')

def washer(root,name,axis,start,u,v,ro,ri,h):
 c=comp(root,'HARDWARE '+name);b=circle(c,axis,start,u,v,ro,h,name=name);b.name=c.name
 circle(c,axis,start-.1,u,v,ri,h+.2,CUT,'Washer clearance')

def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 bolt(root,'Main shaft cap M3x8','x',-39.35,-31.35,0,65,1.5,2.85,1.65,-1)
 for a in [-45,0,45]:
  y=-36*math.sin(math.radians(a));z=65-36*math.cos(math.radians(a))
  bolt(root,'Cam fastener M3x10 '+str(a),'x',12,2,y,z,1.5,2.85,1.65,1)
 for z in [180,190]:bolt(root,'Grip fastener M3x25 '+str(z),'x',12.5,-12.5,0,z,1.5,2.85,1.65,1)
 for xx in [-30,30]:
  for sy in [-1,1]:
   bolt(root,'Rail M5x25 '+str((xx,sy)),'y',sy*54,sy*79,xx,45,2.5,4.75,2.75,-sy)
   washer(root,'Rail M5 washer '+str((xx,sy)),'y',54 if sy>0 else -55,xx,45,5,2.7,1)
 bolt(root,'Follower pivot M5x80','x',-36,44,-35,12,2.5,4.75,2.75,-1)
 nut(root,'Follower pivot M5 nut','x',36,-35,12,8,4,2.5)
 bolt(root,'Roller axle M3x20','x',20,0,0,12,1.5,2.85,1.65,1)
 nut(root,'Roller axle M3 nut','x',3.1,0,12,5.5,2.4,1.5)
 for yy in [-59,-51]:
  for sx in [-1,1]:bolt(root,'Spring block M3x20 '+str((yy,sx)),'x',sx*36,sx*16,yy,44,1.5,2.85,1.65,sx)
 for xx in [5,19]:
  bolt(root,'Cup guide M3x25 '+str(xx),'z',32,57,xx,-55,1.5,2.85,1.65,-1)
  washer(root,'Cup guide washer '+str(xx),'z',52,xx,-55,3.5,1.7,.5)
  nut(root,'Cup guide M3 nut '+str(xx),'z',52.5,xx,-55,5.5,2.4,1.5)
 bolt(root,'Preload adjuster M4x25','z',62,37,12,-55,2,3.8,2.2,1)
 nut(root,'Retained preload M4 nut','z',38.2,12,-55,7,3.2,2)
 angle=math.radians(52)+math.acos((30**2+37**2-11**2)/(2*30*37))
 for sg in [-1,1]:
  yy=sg*37*math.sin(angle);zz=65+37*math.cos(angle)
  bolt(root,'Stop steel core M5x25 '+str(sg),'x',-36,-11,yy,zz,2.5,4.75,2.75,-1)
  nut(root,'Stop retained M5 nut '+str(sg),'x',-15.4,yy,zz,8,4,2.5)
 for xx,zz in [(45.5,73),(67,58),(67,72)]:
  bolt(root,'Coupler clamp M3x16 '+str((xx,zz)),'y',9.5,-6.5,xx,zz,1.5,2.85,1.65,1)
  washer(root,'Coupler clamp washer '+str((xx,zz)),'y',9,xx,zz,3.5,1.7,.5)
 for sg in [-1,1]:
  bolt(root,'RK097 carriage M3x12 '+str(sg),'y',sg*33.5,sg*21.5,74,65,1.5,2.85,1.65,sg)
  washer(root,'RK097 carriage washer '+str(sg),'y',33 if sg>0 else -33.5,74,65,3.5,1.7,.5)
 washer(root,'RK097 assumed M7 washer','x',79.5,0,65,6,3.6,.5)
 nut(root,'RK097 assumed M7 nut','x',77.5,0,65,11,2,3.5)
 for o in root.allOccurrences:
  o.component.isOriginFolderLightBulbOn=False
  for s in o.component.sketches:s.isLightBulbOn=False
 print('Hardware envelopes added. Components',root.occurrences.count)
