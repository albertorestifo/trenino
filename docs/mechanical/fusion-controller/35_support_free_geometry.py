"""Support-free geometry candidates. Validate actual slices before release."""
exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])

def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 def co(pre):return next(o.component for o in root.allOccurrences if o.component.name.startswith(pre+' '))
 shaft=co('P05');assert shaft.bRepBodies.count==1,'Shaft already split'
 # Preserve service opening below the shortened sensor supports.
 for sg in [-1,1]:box(co('P02'),(36,18 if sg>0 else -28,48.9),(66.25,28 if sg>0 else -18,56),CUT,'Restore cam service path beneath compact rails')
 # Rails: tangent 45 degree roofs, with original circular bolt clearance retained.
 for pre,xx in [('P01',-30),('P02',30)]:
  for yy in [-85,85]:
   r=2.7;q=r/math.sqrt(2)
   poly(co(pre),'z',54.9,[(xx+q,yy-q),(xx+q,yy+q),(xx+r*math.sqrt(2),yy)],9.2,CUT,'Support-free horizontal rail hole roof')
 # Follower prints Z-min down. Add stable cheeks and room above pivot roof.
 c=co('P11')
 for xx in [4,17]:
  box(c,(xx,-41,17.9),(xx+3,-29,20),JOIN,'Reinforced roof over support-free pivot bore')
  box(c,(xx,-6,6),(xx+3,6,12),JOIN,'Flat print foot below roller cheek')
 for yy,r in [(-35,4.15),(0,1.7)]:
  q=r/math.sqrt(2)
  poly(c,'x',3.9,[(yy-q,12+q),(yy+q,12+q),(yy,12+r*math.sqrt(2))],16.2,CUT,'Follower horizontal bore 45 degree roof')
 # Sensor clamp prongs must start on supported material in X-max-down print.
 c=co('P19');box(c,(49.65,-2,57),(58.65,2,61),JOIN,'Continuous support beneath lower output prong')
 # Upright grip counterbores: eliminate the wide circular crown overhang.
 c=co('P10')
 for zz in [180,190]:
  r=3.1;q=r/math.sqrt(2)
  poly(c,'x',9,[(q,zz+q),(-q,zz+q),(0,zz+r*math.sqrt(2))],16,CUT,'Upright grip head pocket roof')
 # Split structural shaft lengthwise; all hardware remains within its original envelope.
 for xx in [-15,15]:
  circle(shaft,'y',-6.8,xx,65,2,6.9,CUT,'Shaft half joining insert pocket')
  circle(shaft,'y',-.1,xx,65,1.7,6.7,CUT,'Shaft half joining screw clearance')
  circle(shaft,'y',3.5,xx,65,3.1,3.1,CUT,'Flush shaft joining cap head')
  bolt(root,'Shaft joining M3x8 '+str(xx),'y',3.5,-4.5,xx,65,1.5,2.75,3,1)
 for xx in [-5,5]:
  box(shaft,(xx-1.6,-1.6,61),(xx+1.6,1.6,69),CUT,'Loose alignment key pocket')
  c=comp(root,'P28 Shaft alignment key '+str(xx));b=box(c,(xx-1.5,-1.5,61.1),(xx+1.5,1.5,68.9),name='Loose flat printable alignment key');b.name=c.name
 split=shaft.features.splitBodyFeatures.add(shaft.features.splitBodyFeatures.createInput(shaft.bRepBodies.item(0),shaft.xZConstructionPlane,True))
 split.name='Longitudinal shaft split for flat support-free printing'
 assert shaft.bRepBodies.count==2
 for b in shaft.bRepBodies:
  b.name='P05 Shaft lower half' if b.boundingBox.maxPoint.y<.001 else 'P05 Shaft upper half'
 # The remaining stock screws are cap heads; eliminate the unidentified rotor washer.
 c=co('P07');box(c,(-5,22,60),(5,22.5,70),JOIN,'Direct cap-head rotor clamp seat')
 circle(c,'y',21.9,0,65,1.7,.7,CUT,'Restore rotor screw through raised seat')
 remove=('HARDWARE Main shaft cap','HARDWARE Cam fastener','HARDWARE Roller axle M3x20','HARDWARE Spring block M3x20','HARDWARE Rotor clamp')
 for o in list(root.allOccurrences):
  if o.component.name.startswith(remove):o.deleteMe()
 bolt(root,'Main shaft cap M3x8 cap head','x',-39.35,-31.35,0,65,1.5,2.75,3,-1)
 for a in [-45,0,45]:
  yy=-36*math.sin(math.radians(a));zz=65-36*math.cos(math.radians(a))
  bolt(root,'Cam M3x10 cap head '+str(a),'x',12,2,yy,zz,1.5,2.75,3,1)
 bolt(root,'Roller axle M3x20 cap head','x',20,0,0,12,1.5,2.75,3,1)
 for yy in [-62,-70]:
  for sx in [-1,1]:bolt(root,'Crossblock M3x20 cap head '+str((yy,sx)),'x',sx*36,sx*16,yy,53.5,1.5,2.75,3,sx)
 bolt(root,'Rotor clamp M3x16 cap head','y',22.5,6.5,0,65,1.5,2.75,3,1)
 for o in root.allOccurrences:
  o.component.isOriginFolderLightBulbOn=False
  for s in o.component.sketches:s.isLightBulbOn=False
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in root.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 assert not bad,str(bad)
 print('Shaft split, print roofs and stable feet completed; native features healthy. Actual slice review still required.')
