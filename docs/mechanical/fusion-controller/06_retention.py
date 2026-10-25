exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/common.py').read())
def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 hub=next(o.component for o in root.allOccurrences if o.component.name.startswith('P17'))
 next(f for f in hub.features.extrudeFeatures if f.name.startswith('M3 radial tapped plastic clamp pilot')).deleteMe()
 box(hub,(40.5,-9,69),(50.5,9,78),JOIN,'Pinch clamp reinforcement')
 box(hub,(40.4,-.2,65),(50.6,.2,79),CUT,'Compliant clamp split')
 circle(hub,'y',-7.2,45.5,73,2,7.1,CUT,'M3 pinch clamp heat set')
 circle(hub,'y',.1,45.5,73,1.7,9,CUT,'M3 pinch clamp screw clearance')
 cup=next(o.component for o in root.allOccurrences if o.component.name.startswith('P14'))
 for xx in [5,19]:circle(cup,'z',34.9,xx,-55,2.2,2.2,CUT,'Smooth guide tube clearance')
 for name,x,length in [('P21 Follower left axial spacer',-24,27.8),('P22 Follower right axial spacer',20.2,3.8)]:
  c=comp(root,name);b=circle(c,'x',x,-35,12,6,length,name='Controlled follower end float');b.name=name
  circle(c,'x',x-.1,-35,12,4.2,length+.2,CUT,'Pivot sleeve running clearance')
 for xx in [5,19]:
  c=comp(root,'HARDWARE Guide tube 4OD 3.2ID x6 at '+str(xx))
  b=circle(c,'z',32,xx,-55,2,6,name='Guide bolt compression tube');b.name=c.name
  circle(c,'z',31.9,xx,-55,1.6,6.2,CUT,'M3 guide shank')
 for o in root.allOccurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
  o.component.isOriginFolderLightBulbOn=False
 entities=C.ObjectCollection.create()
 for o in root.allOccurrences:
  if not o.isLightBulbOn or o.component.name.startswith('REFERENCE'):continue
  for b in o.component.bRepBodies:entities.add(b.createForAssemblyContext(o))
 inp=d.createInterferenceInput(entities);inp.areCoincidentFacesIncluded=False
 result=d.analyzeInterference(inp);print('NEUTRAL',result.count)
 for r in result:print(r.entityOne.name,r.entityTwo.name,r.interferenceBody.volume)
 app.activeViewport.saveAsImageFile(ROOTDIR+'/fusion-overview.png',1600,1000)
