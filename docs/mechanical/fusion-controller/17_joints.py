import adsk.core as C,adsk.fusion as F,math,json

def run(_context:str):
 d=F.Design.cast(C.Application.get().activeProduct);root=d.rootComponent
 def occ(pre):return next(o for o in root.allOccurrences if o.component.name.startswith(pre))
 moving=('P05','P06','P07','P08 Cam 7','P09','P10','P17','P18','P19','P20','HARDWARE Main shaft cap','HARDWARE Grip fastener','HARDWARE Cam fastener','HARDWARE Coupler clamp','HARDWARE Rotor clamp')
 fork=('P11','HARDWARE H02','HARDWARE Roller axle')
 main=C.ObjectCollection.create();follower=C.ObjectCollection.create()
 for o in root.allOccurrences:
  n=o.component.name
  if n.startswith(moving):main.add(o)
  elif n.startswith(fork):follower.add(o)
  elif n.startswith('P12'):pass
  elif n.startswith(('P08','REFERENCE spring')):pass
  else:o.isGrounded=True
 root.rigidGroups.add(main,False).name='Lever shaft cam grip and coaxial sensor coupling'
 root.rigidGroups.add(follower,False).name='Follower fork and axle hardware'
 def revolute(name,a,b,radius,limits=None):
  face=None
  for body in a.component.bRepBodies:
   for f in body.faces:
    cy=C.Cylinder.cast(f.geometry)
    if cy and abs(cy.radius-radius)<.0001 and abs(cy.axis.x)>.99:
     face=f.createForAssemblyContext(a);break
   if face:break
  if not face:raise RuntimeError('No joint cylinder '+name)
  geom=F.JointGeometry.createByNonPlanarFace(face,F.JointKeyPointTypes.MiddleKeyPoint)
  inp=root.asBuiltJoints.createInput(a,b,geom)
  inp.setAsRevoluteJointMotion(F.JointDirections.CustomJointDirection,face)
  j=root.asBuiltJoints.add(inp);j.name=name
  if limits:
   motion=F.RevoluteJointMotion.cast(j.jointMotion);lim=motion.rotationLimits
   lim.minimumValue=math.radians(limits[0]);lim.maximumValue=math.radians(limits[1]);lim.isMinimumValueEnabled=True;lim.isMaximumValueEnabled=True
  return j
 revolute('Main lever +/-52 deg - cam contact checked separately',occ('P05'),occ('P01'),.6,(-52,52))
 revolute('Follower pivot - independent cam contact coordinate',occ('P11'),occ('P01'),.415,(-6,1))
 revolute('Free roller on sleeve',occ('P12'),occ('P11'),.215)
 root.isJointsFolderLightBulbOn=False
 print(json.dumps({'as_built_joints':root.asBuiltJoints.count,'rigid_groups':root.rigidGroups.count}))

