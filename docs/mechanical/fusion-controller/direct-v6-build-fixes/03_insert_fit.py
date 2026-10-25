exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/direct-v6-build-fixes/helpers.py').read())
def cone(c,axis,a,b,u,v,ra,rb,name):
 # Radial half section revolved around the bore axis; dimensions in mm.
 s=sk(c,'z',v,name)
 def pt(t,r):return p(t,u+r,v) if axis=='x' else p(u+r,t,v)
 pts=[s.modelToSketchSpace(pt(a,0)),s.modelToSketchSpace(pt(a,ra)),s.modelToSketchSpace(pt(b,rb)),s.modelToSketchSpace(pt(b,0))]
 for i in range(4):s.sketchCurves.sketchLines.addByTwoPoints(pts[i],pts[(i+1)%4])
 ax=s.sketchCurves.sketchLines.addByTwoPoints(s.modelToSketchSpace(pt(a-1,0)),s.modelToSketchSpace(pt(b+1,0)));ax.isConstruction=True;s.isComputeDeferred=False
 assert s.profiles.count==1
 inp=c.features.revolveFeatures.createInput(s.profiles.item(0),ax,CUT);inp.setAngleExtent(False,C.ValueInput.createByString('360 deg'));inp.participantBodies=[b for b in c.bRepBodies]
 f=c.features.revolveFeatures.add(inp);f.name=name;s.isLightBulbOn=False

def run(_context: str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent
 c=co(root,'P13')
 box(c,(-24,-76,38),(24,-73.9,59),JOIN,'Rear wall around captive block nuts')
 for xx in [4,20]:box(c,(xx-2.9,-76.1,40.8),(xx+2.9,-73.8,43.4),CUT,'Extend guide nut loading access through rear wall')
 # Accessible shaft and rotor fasteners now use nuts; only the thin grip retains inserts.
 c=co(root,'P07')
 for f in list(c.features.extrudeFeatures):
  if f.name.startswith('M3 heatset pocket for rotor clamp'):f.deleteMe()
 targets={'P05':('M3 heat-set end retention','Shaft half joining insert pocket'),'P07':('Cam M3 insert pocket',),'P09':('M3 grip heat set',)}
 changed=[]
 for pre,prefixes in targets.items():
  c=co(root,pre)
  for s in c.sketches:
   if s.name.startswith(prefixes):
    for q in s.sketchCurves.sketchCircles:
     assert abs(q.radius-.2)<1e-6,(s.name,q.radius)
     q.radius=.19 if pre=='P09' else .17;changed.append((pre,s.name))
 c=co(root,'P05')
 hexhole(c,'x',-34,0,65,5.8,2.6,'Shaft cap nut captured by assembled halves')
 nut(root,'Shaft cap captured M3 nut','x',-33.9,0,65,5.5,2.4,1.5)
 for xx in [-15,15]:
  hexhole(c,'y',-4.5,xx,65,5.8,2.6,'Shaft joining captured nut')
  box(c,(xx-3.35,-4.5,56.9),(xx+3.35,-1.9,65),CUT,'Shaft nut loading slot from underside')
  box(c,(xx-3.35,-4.7,63.3),(xx+3.35,-4.5,66.7),CUT,'Shaft nut first anchored bridge relief')
  box(c,(xx-1.7,-4.9,63.3),(xx+1.7,-4.7,66.7),CUT,'Shaft nut crossed bridge relief')
  nut(root,'Shaft joining captured M3 nut '+str(xx),'y',-4.4,xx,65,5.5,2.4,1.5)
 c=co(root,'P07')
 for a in [-45,0,45]:
  yy=-36*math.sin(math.radians(a));zz=65-36*math.cos(math.radians(a))
  hexhole(c,'x',-7.1,yy,zz,5.8,11.7,'Rear-loaded cam hex nut')
  nut(root,'Cam captured M3 nut '+str(a),'x',2.1,yy,zz,5.5,2.4,1.5)
 hexhole(c,'y',15.2,0,65,5.8,2.6,'Rotor side-loaded clamp nut')
 box(c,(-7.1,15.2,62.1),(0,17.8,67.9),CUT,'Rotor clamp nut insertion from back face')
 nut(root,'Rotor clamp captured M3 nut','y',15.3,0,65,5.5,2.4,1.5)
 c=co(root,'P09')
 for zz in [180,190]:cone(c,'x',-7.4,-7.2,0,zz,1.9,2.1,'Small grip socket insert lead-in')
 open(OUT+'/insert-fit-changes.json','w').write(json.dumps({'retained_part':'P09','bore_mm':3.8,'mouth_chamfer_mm':.2,'status':'unvalidated fit candidate','shaft_rotor':'Converted to accessible captive nuts','sketches':changed},indent=2))
 finishstage(d,'03-insert-fit')
