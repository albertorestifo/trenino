"""Apply once only to the separate Gear Comparison copy. Dimensions in mm."""
exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])
OUT=ROOTDIR+'/gear-comparison'

def gear_points(teeth,m,cy,cz,phase=0,thin=.08):
 rp=m*teeth/2;rb=rp*math.cos(math.radians(20));rr=rp-1.25*m;ra=rp+m
 inv=lambda r: math.sqrt((r/rb)**2-1)-math.acos(rb/r) if r>rb else 0
 half=math.pi/(2*teeth)-thin/(2*rp);out=[]
 def pt(r,a):return (cy+r*math.cos(a),cz+r*math.sin(a))
 for i in range(teeth):
  a=phase+i*2*math.pi/teeth
  rootang=half+inv(rp)-inv(max(rb,rr))
  out.append(pt(rr,a-rootang))
  for j in range(9):
   r=max(rr,rb)+(ra-max(rr,rb))*j/8;out.append(pt(r,a-half-inv(rp)+inv(r)))
  for j in range(8,-1,-1):
   r=max(rr,rb)+(ra-max(rr,rb))*j/8;out.append(pt(r,a+half+inv(rp)-inv(r)))
  out.append(pt(rr,a+rootang))
  nxt=phase+(i+1)*2*math.pi/teeth-rootang
  for j in [1,2,3]:out.append(pt(rr,(a+rootang)+(nxt-a-rootang)*j/4))
 clean=[]
 for q in out:
  if not clean or math.dist(q,clean[-1])>1e-8:clean.append(q)
 if math.dist(clean[0],clean[-1])<1e-8:clean.pop()
 return clean

def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 assert app.activeDocument.dataFile.id=='urn:adsk.wipprod:dm.lineage:HlxCOdQOSdGZfMtoCnyuyw','Never modify baseline'
 assert not any(o.component.name.startswith('G01') for o in root.allOccurrences),'Already applied'
 for j in list(root.asBuiltJoints):j.deleteMe()
 for g in list(root.rigidGroups):g.deleteMe()
 for o in list(root.allOccurrences):
  if o.component.name.startswith(('P05 ','P16 ','P18 ','P19 ','HARDWARE Compact','REFERENCE RK097','HARDWARE RK097 supplied')):o.deleteMe()
 right=next(o.component for o in root.allOccurrences if o.component.name.startswith('P02 '))
 box(right,(36,-34,46),(66.3,34,84),CUT,'Remove Oldham carriage extensions')
 # Uprights stay inboard of gear plane and attach to existing plate near its top.
 for sg in [-1,1]:
  lo,hi=(10,23) if sg>0 else (-23,-10)
  box(right,(24,lo,78),(34,hi,126),JOIN,'Upper geared sensor support')
  circle(right,'x',24,sg*16,110.15,2,6.8,CUT,'Geared mount M3 insert from inboard face')
  circle(right,'x',30.7,sg*16,110.15,1.7,3.4,CUT,'Geared mount screw clearance')
 right.name='P02G Right plate with upper sensor supports'
 for b in right.bRepBodies:b.name=right.name
 # Rebuild only the split shaft, preserving all hand-load interfaces.
 shaft=comp(root,'P05G Split shaft with D gear drive')
 circle(shaft,'x',-37.35,0,65,6,74.7,name='Continuous 12 mm journals')
 circle(shaft,'x',-23.8,0,65,8,47.6,JOIN,'Structural shaft')
 box(shaft,(-23.9,6.5,56),(23.9,9,74),CUT,'Rotor D flat')
 circle(shaft,'x',37.35,0,65,10,3,JOIN,'Retain axial shoulder')
 circle(shaft,'x',40.35,0,65,4,8,JOIN,'Short D drive stub')
 box(shaft,(40.35,3.2,60),(48.5,5,70),CUT,'Drive stub D flat')
 circle(shaft,'x',-37.45,0,65,2,6.8,CUT,'End retention insert')
 for xx in [-15,15]:
  circle(shaft,'y',-6.8,xx,65,2,6.9,CUT,'Joining insert')
  circle(shaft,'y',-.1,xx,65,1.7,6.7,CUT,'Joining screw clearance')
  circle(shaft,'y',3.5,xx,65,3.1,3.1,CUT,'Recessed cap head')
 for xx in [-5,5]:box(shaft,(xx-1.6,-1.6,61),(xx+1.6,1.6,69),CUT,'Retain alignment key pocket')
 shaft.features.splitBodyFeatures.add(shaft.features.splitBodyFeatures.createInput(shaft.bRepBodies.item(0),shaft.xZConstructionPlane,True))
 for b in shaft.bRepBodies:b.name='P05G Shaft lower half' if b.boundingBox.maxPoint.y<.001 else 'P05G Shaft upper half'
 assert shaft.bRepBodies.count==2
 # 48/24 pair, m1.25, 20-degree involutes, eight-mm face width.
 for name,n,cy,cz,phase,bore,side in [('G01 48T lever gear',48,0,65,0,4.1,-1),('G02 24T sensor pinion',24,0,110.15,math.pi/24,3.1,1)]:
  c=comp(root,name);b=poly(c,'x',40.5,gear_points(n,1.25,cy,cz,phase),8,name='Involute gear polygon m1.25 pressure20');b.name=name
  circle(c,'x',40.4,cy,cz,bore,8.2,CUT,'Shaft bore')
  if n==48:
   box(c,(40.5,3.35,62),(48.5,4.3,68),JOIN,'D key flat')
   box(c,(40.4,-.2,32),(48.6,.2,65),CUT,'Clamp slit outside operating mesh sector')
  else:
   circle(c,'x',40.4,0,cz,3.6,.9,CUT,'Sensor bushing end relief')
   box(c,(40.4,-.2,cz),(48.6,.2,127),CUT,'Clamp slit outside operating mesh sector')
  zz=cz+side*8
  circle(c,'y',-8,44.5,zz,2,6.8,CUT,'Clamp heat-set insert pocket')
  circle(c,'y',-1.3,44.5,zz,1.7,6.4,CUT,'Clamp through screw')
  circle(c,'y',5,44.5,zz,3.1,30,CUT,'Recessed clamp screw head and tool path')
  bolt(root,name+' clamp M3x12','y',5,-7,44.5,zz,1.5,2.75,3,1)
  color(c,55,130,185) if n==48 else color(c,225,165,60)
 # Slotted sensor panel: adjust center distance, not tooth thickness.
 c=comp(root,'G03 Radially adjustable potentiometer panel');b=box(c,(34,-23,96),(37,23,126),name='Geared sensor panel');b.name=c.name
 circle(c,'x',33.9,0,110.15,3.6,3.2,CUT,'Provisional M7 bushing')
 for yy in [-16,16]:
  poly(c,'x',33.9,[(yy-1.7,108.95),(yy+1.7,108.95),(yy+1.7,111.35),(yy-1.7,111.35)],3.2,CUT,'Vertical mesh adjustment slot')
  bolt(root,'Geared panel M3x12 '+str(yy),'x',37,25,yy,110.15,1.5,2.75,3,1)
 color(c,95,155,100)
 c=comp(root,'REFERENCE Geared RK097 provisional envelope');b=box(c,(20,-4.75,105.4),(34,4.75,114.9),name='Provisional sensor body');b.name=c.name
 circle(c,'x',34,0,110.15,3.5,7,JOIN,'Provisional bushing')
 circle(c,'x',41,0,110.15,3,12,JOIN,'Provisional 12 mm exposed shaft')
 washer(root,'Geared RK097 supplied washer ASSUMED','x',37,0,110.15,6,3.6,.5)
 nut(root,'Geared RK097 supplied nut ASSUMED','x',37.5,0,110.15,11,2,3.5)
 for o in root.allOccurrences:
  o.component.isOriginFolderLightBulbOn=False
  for s in o.component.sketches:s.isLightBulbOn=False
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in root.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 assert not bad,str(bad)
 print(json.dumps({'built':'geared comparison','ratio':-2,'center_distance_mm':45.15,'nominal_center_mm':45,'native_unhealthy':bad}))
