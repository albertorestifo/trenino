"""Apply once to v5. Inventory revision; reference envelopes are not measured hardware."""
exec(open('C:/Users/Alberto/Documents/tsw_io/docs/mechanical/fusion-controller/07_hardware.py').read().split('def run(_context:str):')[0])

def run(_context: str):
 app=C.Application.get();d=F.Design.cast(app.activeProduct);root=d.rootComponent
 assert app.activeDocument.name.startswith('AIDesignedLever')
 assert not any(o.component.name.startswith('P25 Captured') for o in root.allOccurrences),'Revision already applied'
 def co(pre):return next(o.component for o in root.allOccurrences if o.component.name.startswith(pre+' '))
 for j in list(root.asBuiltJoints):j.deleteMe()
 for g in list(root.rigidGroups):g.deleteMe()
 obsolete=('HARDWARE Rail vertical','HARDWARE Rail M5 metal','HARDWARE Follower pivot','HARDWARE H01','HARDWARE H02','HARDWARE Guide tube','HARDWARE Cup guide','HARDWARE Preload adjuster','HARDWARE Retained preload','HARDWARE Grip fastener','HARDWARE Stop steel','HARDWARE Stop retained','HARDWARE Stop M3 washer','REFERENCE spring','P12 ','P14 ','P15 ','P25 ','P26 ')
 for o in list(root.allOccurrences):
  if o.component.name.startswith(obsolete):o.deleteMe()
 # Stock M5x14, no unidentified washer stack. Same nominal tip Z50.
 for pre,x in [('P01',-36),('P02',24)]:
  c=co(pre)
  for sg in [-1,1]:
   ya,yb=(-95,-70) if sg<0 else (70,95)
   box(c,(x,ya,63),(x+12,yb,64),JOIN,'Stock M5x14 mounting seat Z64')
   circle(c,'z',62.9,x+6,sg*85,2.7,1.2,CUT,'Continue rail clearance through new seat')
   bolt(root,'Rail M5x14 DIN912 '+str((x+6,sg)),'z',64,50,x+6,sg*85,2.5,4.25,5,1)
  circle(c,'x',x,-35,12,1.71,12,JOIN,'Close obsolete long pivot screw hole')
  circle(c,'x',-26 if pre=='P01' else 23.9,-35,12,4.15,2.1,CUT,'Blind captive printed pivot seat')
 # Captured axle halves have full flat print faces; no cut metal or long bolt.
 for name,upper in [('P25 Captured printed pivot lower half',False),('P26 Captured printed pivot upper half',True)]:
  c=comp(root,name);b=circle(c,'x',-25.85,-35,12,4,51.7,name='Captured axle 0.3 mm total end clearance');b.name=name
  box(c,(-26,-35 if not upper else -40,7),(26,-30 if not upper else -35,17),CUT,'Longitudinal flat print face')
  color(c,225,220,200)
 # Shorten grip screws while retaining the original insert position.
 c=co('P10')
 for zz in [180,190]:
  circle(c,'x',9,0,zz,3.1,3.6,CUT,'Recess for stocked M3x20 grip screw')
  bolt(root,'Grip M3x20 cap head '+str(zz),'x',9,-11,0,zz,1.5,2.75,3,1)
 # Counterbored stop screw: M3x20 preserves original tip and steel-core extent.
 left=co('P01');angle=math.radians(52)+math.acos((30**2+37**2-11**2)/(2*30*37))
 for sg in [-1,1]:
  yy=sg*37*math.sin(angle);zz=65+37*math.cos(angle)
  circle(left,'x',-36.1,yy,zz,3.1,4.6,CUT,'Stock M3x20 stop recessed cap head')
  bolt(root,'Stop M3x20 cap head '+str(sg),'x',-31.5,-11.5,yy,zz,1.5,2.75,3,-1)
  nut(root,'Stop M3 plain captive nut '+str(sg),'x',-17.5,yy,zz,5.5,2.4,1.5)
 # Stock 623ZZ bearings replace unavailable roller sleeve; pads touch inner races only.
 fork=co('P11')
 for xx in [7,16]:
  circle(fork,'x',xx,0,12,2.4,1,JOIN,'Bearing inner race support pad')
  circle(fork,'x',xx-.1,0,12,1.7,1.2,CUT,'Preserve roller screw clearance')
 for xx in [8,12]:
  c=comp(root,'HARDWARE 623ZZ roller bearing at '+str(xx));b=circle(c,'x',xx,0,12,5,4,name='Stock 623ZZ envelope 3x10x4');b.name=c.name
  circle(c,'x',xx-.1,0,12,1.5,4.2,CUT,'Bearing inner race bore')
 # Rework spring block to M3 preload screw and short insert-retained guides.
 c=co('P13')
 for xx in [5,19]:circle(c,'z',38,xx,-55,1.71,21,JOIN,'Close former long guide bore')
 rr=7.4/math.sqrt(3)
 poly(c,'z',38,[(12+rr*math.cos(i*math.pi/3),-55+rr*math.sin(i*math.pi/3)) for i in range(6)],3.5,JOIN,'Close obsolete M4 nut pocket')
 circle(c,'z',38,12,-55,2.21,21,JOIN,'Close obsolete M4 adjuster passage')
 circle(c,'z',37.9,12,-55,1.7,21.2,CUT,'M3 preload adjuster passage')
 circle(c,'z',37.9,12,-55,2,6.9,CUT,'M3 preload insert from spring side')
 circle(c,'z',55,12,-55,3.4,4.1,CUT,'Recessed preload head and limiter access')
 for xx in [4,20]:
  circle(c,'z',37.9,xx,-55,2,6.9,CUT,'Short guide M3 insert from underside')
  cc=comp(root,'P27 Printed guide sleeve '+str(xx));b=circle(cc,'z',32,xx,-55,2.5,6,name='Short compression sleeve');b.name=cc.name
  circle(cc,'z',31.9,xx,-55,1.65,6.2,CUT,'Guide screw bore')
  bolt(root,'Cup guide M3x12 '+str(xx),'z',32,44,xx,-55,1.5,2.75,3,-1)
 c=comp(root,'P14 Captive spring cup for 9 mm spring');b=box(c,(0.2,-61,35),(23.8,-49,37),name='Wide stock spring seat');b.name=c.name
 circle(c,'z',29,12,-55,3,6,JOIN,'Provisional 6 mm spring pilot')
 for xx in [4,20]:circle(c,'z',34.9,xx,-55,2.7,2.2,CUT,'Printed guide running clearance')
 c=comp(root,'P15 Recessed preload limit collar 2 mm');b=circle(c,'z',55,12,-55,3.2,2,name='Preserve one mm additional compression limit');b.name=c.name
 circle(c,'z',54.9,12,-55,1.7,2.2,CUT,'M3 adjuster clearance')
 bolt(root,'Preload M3x20 cap head','z',57,37,12,-55,1.5,2.75,3,1)
 c=comp(root,'REFERENCE Stock spring OD9 wire1 free20 - rate and solid height assumed');b=circle(c,'z',18,12,-55,4.5,17,name='Provisional stock spring installed envelope');b.name=c.name
 circle(c,'z',17.9,12,-55,3.5,17.2,CUT,'Stock spring nominal ID7')
 for o in root.allOccurrences:
  o.component.isOriginFolderLightBulbOn=False
  for s in o.component.sketches:s.isLightBulbOn=False
 bad=[(o.component.name,f.name,f.errorOrWarningMessage) for o in root.allOccurrences for f in o.component.features if f.healthState!=F.FeatureHealthStates.HealthyFeatureHealthState]
 assert not bad,str(bad)
 print('Inventory interfaces applied; native features healthy. Spring assumptions still require physical verification.')

