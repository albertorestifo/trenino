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

