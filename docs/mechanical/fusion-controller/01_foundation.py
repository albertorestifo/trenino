import adsk.core as C, adsk.fusion as F, math, json
ROOTDIR='C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller'
NEW=F.FeatureOperations.NewBodyFeatureOperation
JOIN=F.FeatureOperations.JoinFeatureOperation
CUT=F.FeatureOperations.CutFeatureOperation

def p(x,y,z): return C.Point3D.create(x/10,y/10,z/10)
def val(mm):return C.ValueInput.createByString(str(mm)+' mm')
def comp(root,name):
 o=root.occurrences.addNewComponent(C.Matrix3D.create());o.component.name=name
 return o.component

def sk(c,axis,pos,name):
 base={'x':c.yZConstructionPlane,'y':c.xZConstructionPlane,'z':c.xYConstructionPlane}[axis]
 ci=c.constructionPlanes.createInput();ci.setByOffset(base,val(pos));plane=c.constructionPlanes.add(ci);plane.name=name+' plane';plane.isLightBulbOn=False
 s=c.sketches.add(plane);s.name=name;s.isComputeDeferred=True
 return s

def finish(c,s,axis,depth,op,name):
 s.isComputeDeferred=False
 assert s.profiles.count==1,(name,s.profiles.count)
 ei=c.features.extrudeFeatures.createInput(s.profiles.item(0),op)
 ei.setOneSideExtent(F.DistanceExtentDefinition.create(val(depth)),F.ExtentDirections.PositiveExtentDirection)
 if op==CUT:ei.participantBodies=[b for b in c.bRepBodies]
 e=c.features.extrudeFeatures.add(ei);e.name=name;s.isLightBulbOn=False
 return e.bodies.item(0)

def poly(c,axis,pos,points,depth,op=NEW,name='Profile'):
 s=sk(c,axis,pos,name)
 def coord(u,v):return p(pos,u,v) if axis=='x' else p(u,pos,v) if axis=='y' else p(u,v,pos)
 pts=[s.modelToSketchSpace(coord(*q)) for q in points]
 for i in range(len(pts)):s.sketchCurves.sketchLines.addByTwoPoints(pts[i],pts[(i+1)%len(pts)])
 return finish(c,s,axis,depth,op,name)

def circle(c,axis,pos,u,v,r,depth,op=NEW,name='Round'):
 s=sk(c,axis,pos,name)
 center=p(pos,u,v) if axis=='x' else p(u,pos,v) if axis=='y' else p(u,v,pos)
 s.sketchCurves.sketchCircles.addByCenterRadius(s.modelToSketchSpace(center),r/10)
 return finish(c,s,axis,depth,op,name)

def box(c,lo,hi,op=NEW,name='Block'):
 x,y,z=lo;X,Y,Z=hi
 return poly(c,'x',x,[(y,z),(Y,z),(Y,Z),(y,Z)],X-x,op,name)

def color(c,r,g,b):
 app=C.Application.get();lib=app.materialLibraries.itemByName('Fusion 360 Appearance Library')
 if not lib:return
 src=lib.appearances.itemByName('Plastic - Matte (White)')
 if not src:return
 a=app.activeProduct.appearances.addByCopy(src,c.name+' finish'); prop=a.appearanceProperties.itemById('generic_diffuse')
 if prop:prop.value=C.Color.create(r,g,b,255)
 for body in c.bRepBodies:body.appearance=a

def run(_context:str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 assert root.bRepBodies.count==0 and root.occurrences.count==0,'Foundation requires empty design'
 d.designIntent=F.DesignIntentTypes.HybridDesignIntentType
 d.designType=F.DesignTypes.ParametricDesignType
 for name,expr,unit,note in [('FrameLength','640 mm','mm','Fixed existing outer length'),('FrameWidth','190 mm','mm','Fixed existing outer width'),('FrameHeight','110 mm','mm','Fixed existing height'),('PivotHeight','65 mm','mm','Above frame center'),('LeverTravel','100 deg','deg','Stable endpoint to endpoint'),('PrintClearance','0.3 mm','mm','Prototype diametral running clearance')]:
  if not d.userParameters.itemByName(name):d.userParameters.add(name,C.ValueInput.createByString(expr),unit,note)
 ref=comp(root,'REFERENCE - fixed existing 2020 frame - DO NOT PRINT')
 meshes=ref.meshBodies.add(ROOTDIR+'/fixed-frame-reference.3mf',F.MeshUnits.MillimeterMeshUnit)
 print('Reference mesh count',meshes.count)
 ref.parentDesign.rootComponent.occurrences.item(0).isGrounded=True
 contour=[(-75,33),(-55,33),(-55,-2),(55,-2),(55,33),(75,33),(75,57),(32,57),(26,86),(-26,86),(-32,57),(-75,57)]
 for side in [-1,1]:
  x=-36 if side<0 else 24
  c=comp(root,('P01 Left' if side<0 else 'P02 Right')+' rail sideplate')
  b=poly(c,'x',x,contour,12,name='Flat load-bearing plate');b.name=c.name
  circle(c,'x',x-1,0,65,10.15,14,CUT,'Replaceable bushing seat')
  circle(c,'x',x-1,-35,12,2.7,14,CUT,'Follower pivot bolt')
  for sy in [-1,1]:
   circle(c,'y',54 if sy>0 else -76,x+6,45,2.7,22,CUT,'M5 rail mounting bore')
   circle(c,'y',43 if sy>0 else -55,x+6,45,5.3,12,CUT,'Rail screw tool and washer access')
  for yy in [-59,-51]:circle(c,'x',x-1,yy,44,1.7,14,CUT,'Spring crossblock attachment')
  color(c,85,105,120)
 for side in [-1,1]:
  c=comp(root,('P03 Left' if side<0 else 'P04 Right')+' flanged journal bush')
  x=-36 if side<0 else 24
  b=circle(c,'x',x,0,65,10.05,12,name='Replaceable journal body');b.name=c.name
  circle(c,'x',-37.2 if side<0 else 36,0,65,12.75,1.2,JOIN,'Axial thrust flange')
  circle(c,'x',-38 if side<0 else 23,0,65,6.15,15,CUT,'Running journal bore')
  color(c,225,220,200)
 c=comp(root,'P05 Printed main shaft - horizontal print')
 b=circle(c,'x',-37.35,0,65,6,74.7,name='Continuous 12 mm journals');b.name=c.name
 circle(c,'x',-23.8,0,65,8,47.6,JOIN,'16 mm structural shaft')
 box(c,(-23.9,6.5,56),(23.9,9,74),CUT,'D-flat torque key')
 circle(c,'x',37.35,0,65,10,3,JOIN,'Integral axial shoulder')
 circle(c,'x',40.35,0,65,4,10,JOIN,'Sensor drive stub')
 box(c,(40.25,3.2,60),(50.5,5,70),CUT,'Sensor drive flat')
 circle(c,'x',-37.45,0,65,2,6.8,CUT,'M3 heat-set end retention')
 color(c,55,130,185)
 c=comp(root,'P06 Shaft retaining cap')
 b=circle(c,'x',-39.35,0,65,10,2,name='Axial cap');b.name=c.name
 circle(c,'x',-39.5,0,65,1.7,2.4,CUT,'M3 cap screw')
 color(c,55,130,185)
 for c in root.allOccurrences:
  for s in c.component.sketches:s.isLightBulbOn=False
  c.component.isOriginFolderLightBulbOn=False
 app.activeViewport.fit()
 print('Foundation components',root.occurrences.count,'timeline',d.timeline.count)
 for o in root.allOccurrences:
  for b in o.component.bRepBodies:print(b.name,'valid',b.isValid,'solid',b.isSolid,'volume_cm3',b.volume)



