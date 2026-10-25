import math
PITCH=math.radians(12.5)
HEIGHTS=[.65,.65,.65,.9,.9,.65,.65,1.0]
def lift(t):
 u=(t+math.radians(50))/PITCH
 i=max(0,min(7,math.floor(u)))
 s=u-i
 h=HEIGHTS[i]
 return .5*h*(1-math.cos(2*math.pi*s)),h*math.pi/PITCH*math.sin(2*math.pi*s)
def campt(t):
 h,hp=lift(t);beta=-h/35;bp=-hp/35
 y=-35+35*math.cos(beta);z=-53+35*math.sin(beta)
 yp=-35*bp*math.sin(beta);zp=35*bp*math.cos(beta)
 co=math.cos(t);si=math.sin(t);q=(co*y+si*z,-si*y+co*z)
 dy=yp+z;dz=zp-y;qp=(co*dy+si*dz,-si*dy+co*dz)
 normal=(qp[1],-qp[0]);nn=math.hypot(*normal);normal=tuple(v/nn for v in normal)
 if sum(a*b for a,b in zip(normal,q))<0:normal=tuple(-v for v in normal)
 return q[0]-5*normal[0],65+q[1]-5*normal[1]
def outline():
 return [campt(math.radians(-60+i*.25)) for i in range(481)]+[(-29*math.sin(math.radians(t)),65-29*math.cos(math.radians(t))) for t in range(60,-61,-3)]
