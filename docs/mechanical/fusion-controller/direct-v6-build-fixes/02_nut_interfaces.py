exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/direct-v6-build-fixes/helpers.py').read())
def run(_context: str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent;c=co(root,'P13')
 # Replace insert bores with clearance passages and accessible load-bearing nut seats.
 for xx in [4,12,20]:
  circle(c,'z',38,xx,-55,2.01,6.8,JOIN,'Close insert pilot for captive nut conversion')
  circle(c,'z',37.9,xx,-55,1.7,21.2 if xx==12 else 7,CUT,'M3 clearance through nut interface')
 hexhole(c,'z',37.9,12,-55,5.8,2.7,'Bottom loaded preload reaction nut')
 nut(root,'Preload bottom reaction M3 nut','z',38.1,12,-55,5.5,2.4,1.5)
 for xx in [4,20]:
  # Flats in X reduce the installed envelope beside the right plate.
  hexhole(c,'z',40.8,xx,-55,5.8,2.6,'Guide captive nut with lower reaction shoulder',math.pi/6)
  box(c,(xx-2.9,-74.1,40.8),(xx+2.9,-55,43.4),CUT,'Guide nut rear installation slot')
  box(c,(xx-2.9,-56.7,40.6),(xx+2.9,-53.3,40.8),CUT,'Guide nut first bridge relief')
  box(c,(xx-1.7,-56.7,40.4),(xx+1.7,-53.3,40.6),CUT,'Guide nut crossed bridge relief')
  # Hardware uses the matching 30-degree hex orientation.
  n=comp(root,'HARDWARE Guide captive M3 nut '+str(xx));rr=5.5/math.sqrt(3)
  poly(n,'z',40.9,[(xx+rr*math.cos(i*math.pi/3+math.pi/6),-55+rr*math.sin(i*math.pi/3+math.pi/6)) for i in range(6)],2.4,name='Guide nut envelope')
  circle(n,'z',40.8,xx,-55,1.5,2.6,CUT,'Guide nut thread')
 for yy in [-62,-70]:
  for sg in [-1,1]:
   x=-24 if sg<0 else 15.3
   circle(c,'x',x,yy,53.5,2.01,8.7,JOIN,'Close mounting insert pilot')
   circle(c,'x',x-.1,yy,53.5,1.7,8.9,CUT,'Block mount screw passage')
   start=-20 if sg<0 else 17.4
   hexhole(c,'x',start,yy,53.5,5.8,2.6,'Crossblock captive hex nut')
   box(c,(start,yy-3.35,53.5),(start+2.6,yy+3.35,59.1),CUT,'Top installation slot for block nut')
   nut(root,'Crossblock captive M3 '+str((yy,sg)),'x',start+.1,yy,53.5,5.5,2.4,1.5)
 # P13 prints Z-max down: relief progresses downward from the unchanged head seat at55.
 box(c,(8.6,-56.7,54.8),(15.4,-53.3,55),CUT,'Preload head first bridge relief')
 box(c,(10.3,-56.7,54.6),(13.7,-53.3,54.8),CUT,'Preload head crossed bridge relief')
 # P19: retain all coupling faces and replace insert by a top-loaded nut.
 c=co(root,'P19')
 circle(c,'y',-9,54.15,73,2.01,8.9,JOIN,'Close sensor clamp insert pilot')
 circle(c,'y',-9.1,54.15,73,1.7,9.1,CUT,'Sensor clamp M3 clearance')
 hexhole(c,'y',-6.9,54.15,73,5.8,2.6,'Sensor clamp captive hex nut')
 box(c,(50.8,-6.9,73),(57.5,-4.3,78.1),CUT,'Clamp nut top installation slot')
 nut(root,'Sensor clamp captive M3 nut','y',-6.8,54.15,73,5.5,2.4,1.5)
 finishstage(d,'02-nut-interfaces')
