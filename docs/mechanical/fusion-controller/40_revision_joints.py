import adsk.core as C,adsk.fusion as F,math,json

def run(_context: str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent
 for j in list(root.asBuiltJoints):j.deleteMe()
 for g in list(root.rigidGroups):g.deleteMe()
 def occ(pre):return next(o for o in root.allOccurrences if o.component.name.startswith(pre))
 moving=('P05','P06','P07','P08 Cam 7','P09','P10','P18','P19','P28','HARDWARE Main shaft','HARDWARE Grip M3','HARDWARE Cam M3','HARDWARE Compact sensor clamp','HARDWARE Rotor clamp','HARDWARE Shaft joining')
 fork=('P11','HARDWARE 623ZZ','HARDWARE Roller axle')
 main=C.ObjectCollection.create();follower=C.ObjectCollection.create()
 for o in root.allOccurrences:
  name=o.component.name
  if name.startswith(moving):o.isGrounded=False;main.add(o)
  elif name.startswith(fork):o.isGrounded=False;follower.add(o)
  else:o.isGrounded=True
 root.rigidGroups.add(main,False).name='Lever and ideal coaxial sensor drive - floating fit checked separately'
 root.rigidGroups.add(follower,False).name='Follower and bearing envelopes - inner race seating checked separately'
 def revolute(name,a,b,radius,limits):
  faces=[f for body in a.component.bRepBodies for f in body.faces if C.Cylinder.cast(f.geometry) and abs(C.Cylinder.cast(f.geometry).radius-radius)<.0001 and abs(C.Cylinder.cast(f.geometry).axis.x)>.99]
  assert faces,name
  face=faces[0].createForAssemblyContext(a);geom=F.JointGeometry.createByNonPlanarFace(face,F.JointKeyPointTypes.MiddleKeyPoint)
  inp=root.asBuiltJoints.createInput(a,b,geom);inp.setAsRevoluteJointMotion(F.JointDirections.CustomJointDirection,face)
  j=root.asBuiltJoints.add(inp);j.name=name
  lim=F.RevoluteJointMotion.cast(j.jointMotion).rotationLimits
  lim.minimumValue=math.radians(limits[0]);lim.maximumValue=math.radians(limits[1]);lim.isMinimumValueEnabled=True;lim.isMaximumValueEnabled=True
 revolute('Main lever structural limits +/-52 degrees',occ('P05'),occ('P01'),.6,(-52,52))
 revolute('Follower and service travel',occ('P11'),occ('P01'),.415,(-6,1))
 root.isJointsFolderLightBulbOn=False
 print(json.dumps({'joints':root.asBuiltJoints.count,'rigid_groups':root.rigidGroups.count,'bearing_note':'Roller replaced by bearing hardware envelopes; inner/outer ring rotation is not separately simulated.'}))
