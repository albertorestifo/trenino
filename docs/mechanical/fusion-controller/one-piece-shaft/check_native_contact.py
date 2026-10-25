import pathlib,struct,math,json
R=pathlib.Path(__file__).parent;rows=[]
from cam_profile import lift
for n in [9]:
 p=next((R/'raw-stl').glob(f'P08-Cam-{n}-*.stl'));raw=p.read_bytes();count=struct.unpack_from('<I',raw,80)[0];edges=set()
 for i in range(count):
  f=struct.unpack_from('<12fH',raw,84+50*i);v=[(round(f[j+1],5),round(f[j+2]-65,5)) for j in [3,6,9]]
  for a,b in zip(v,v[1:]+v[:1]):
   if a!=b:edges.add(tuple(sorted((a,b))))
 vals=[]
 for index in range(1041):
  deg=-52+index*.1
  t=math.radians(deg);beta=-lift(t)[0]/35
  y=-35+35*math.cos(beta);z=-53+35*math.sin(beta)
  y,z=y*math.cos(t)+z*math.sin(t),-y*math.sin(t)+z*math.cos(t)
  md=1e9
  for a,b in edges:
   dy=b[0]-a[0];dz=b[1]-a[1];u=max(0,min(1,((y-a[0])*dy+(z-a[1])*dz)/(dy*dy+dz*dz)))
   md=min(md,math.hypot(y-a[0]-u*dy,z-a[1]-u*dz))
  vals.append({'angle_deg':deg,'surface_to_roller_center_mm':md,'gap_mm':md-5})
 rows.append({'profile':n,'poses':len(vals),'min_gap_mm':min(v['gap_mm'] for v in vals),'max_gap_mm':max(v['gap_mm'] for v in vals),'samples':vals})
(R/'native-cam-contact-check.json').write_text(json.dumps(rows,indent=2))
print(json.dumps([{k:v for k,v in r.items() if k!='samples'} for r in rows],indent=2))

assert all(r['min_gap_mm']>-.01 and r['max_gap_mm']<.01 for r in rows),rows
