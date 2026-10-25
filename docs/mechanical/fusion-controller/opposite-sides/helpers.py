exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])
OUT=ROOTDIR+'/opposite-sides'
ID='urn:adsk.wipprod:dm.lineage:peR4meb5QLiO5tE5ANITQg'

def setup():
 a=C.Application.get();d=F.Design.cast(a.activeProduct)
 assert a.activeDocument.dataFile.id==ID,'Never modify v6'
 return a,d,d.rootComponent

def done(d,stage):
 for o in d.rootComponent.occurrences:
  for s in o.component.sketches:s.isLightBulbOn=False
  o.component.isOriginFolderLightBulbOn=False
  for b in o.component.bRepBodies:
   assert b.isSolid and b.isValid,o.component.name
   if o.component.bRepBodies.count==1:b.name=o.component.name
 if d.snapshots.hasPendingSnapshot:d.snapshots.add()
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in d.rootComponent.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 assert not bad,str(bad)
 open(OUT+'/'+stage+'-done.json','w').write(json.dumps({'stage':stage,'healthy':True,'components':d.rootComponent.occurrences.count}))
 print(stage,'healthy components',d.rootComponent.occurrences.count)

def dprofile(c,x,depth,r,flat,z=30,op=CUT,name='D profile'):
 s=sk(c,'x',x,name);h=math.sqrt(r*r-flat*flat)
 a=s.modelToSketchSpace(p(x,flat,z+h));m=s.modelToSketchSpace(p(x,-r,z));b=s.modelToSketchSpace(p(x,flat,z-h))
 s.sketchCurves.sketchArcs.addByThreePoints(a,m,b);s.sketchCurves.sketchLines.addByTwoPoints(b,a)
 return finish(c,s,'x',depth,op,name)

def stopcenter(sg):
 a=math.radians(60)+math.acos((30**2+37**2-13**2)/(2*30*37))
 return sg*37*math.sin(a),30-37*math.cos(a)

def roundrect(c,x,y0,z0,y1,z1,r,dep,op=NEW,name='Rounded web'):
 pts=[]
 for cy,cz,start in [(y1-r,z1-r,0),(y0+r,z1-r,90),(y0+r,z0+r,180),(y1-r,z0+r,270)]:
  pts.extend([(cy+r*math.cos(math.radians(start+k*9)),cz+r*math.sin(math.radians(start+k*9))) for k in range(11)])
 return poly(c,'x',x,pts,dep,op,name)

def lathe(c,yy,zz,points,name):
 s=sk(c,'z',zz,name);q=[s.modelToSketchSpace(p(x,yy+r,zz)) for x,r in points]
 for i in range(len(q)):s.sketchCurves.sketchLines.addByTwoPoints(q[i],q[(i+1)%len(q)])
 s.isComputeDeferred=False;assert s.profiles.count==1
 axis=s.sketchCurves.sketchLines.addByTwoPoints(s.modelToSketchSpace(p(-30,yy,zz)),s.modelToSketchSpace(p(10,yy,zz)));axis.isConstruction=True
 ri=c.features.revolveFeatures.createInput(s.profiles.item(0),axis,NEW);ri.setAngleExtent(False,C.ValueInput.createByString('360 deg'))
 b=c.features.revolveFeatures.add(ri).bodies.item(0);s.isLightBulbOn=False;return b
