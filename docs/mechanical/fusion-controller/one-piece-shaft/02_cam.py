exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/direct-v6-build-fixes/helpers.py').read())
OUT=ROOTDIR+'/one-piece-shaft'
exec(open(OUT+'/cam_profile.py').read())
def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);r=d.rootComponent
 c=co(r,'P05')
 box(c,(40.35,6.4,63),(43.35,8,67),JOIN,'Restore positive tongue contact radius')
 c=comp(r,'P08 Cam 9 gates Class 323 - strong center and Emergency')
 b=poly(c,'x',7,outline(),8,name='Nine gate roller compensated cam');b.name=c.name
 for a in [-45,0,45]:
  y=-36*math.sin(math.radians(a));z=65-36*math.cos(math.radians(a))
  circle(c,'x',6.9,y,z,1.7,8.2,CUT,'Cam screw clearance')
  circle(c,'x',12,y,z,3.1,3.1,CUT,'Cam head recess')
 # Recessed E marker near the forward endpoint, away from the rolling edge and mounting bore.
 y=-43*math.sin(math.radians(50));z=65-43*math.cos(math.radians(50))
 poly(c,'x',14.6,[(y-1.2,z-1.7),(y+1.2,z-1.7),(y+1.2,z-1.1),(y-.6,z-1.1),(y-.6,z-.3),(y+.9,z-.3),(y+.9,z+.3),(y-.6,z+.3),(y-.6,z+1.1),(y+1.2,z+1.1),(y+1.2,z+1.7),(y-1.2,z+1.7)],.5,CUT,'Emergency endpoint E marker')
 color(c,225,155,45)
 for o in r.occurrences:
  if o.component==c:
   m=C.Matrix3D.create();m.translation=C.Vector3D.create(0,0,-3.5);o.transform2=m
  if o.component.name.startswith('P08'):o.isLightBulbOn=o.component==c
 if d.snapshots.hasPendingSnapshot:d.snapshots.add()
 finishstage(d,'02-class323')
