import pathlib,sys,math,json
R=pathlib.Path(__file__).parent
sys.path.insert(0,str(R.parent/'inventory-support-free-revision/.validation-libs'))
from shapely.geometry import Polygon,Point
from cam_profile import *
p=Polygon(outline());assert p.is_valid
samples=[]
for i in range(1041):
 deg=-52+i*.1;t=math.radians(deg);h,_=lift(t);b=-h/35
 y=-35+35*math.cos(b);z=-53+35*math.sin(b)
 q=Point(y*math.cos(t)+z*math.sin(t),65-y*math.sin(t)+z*math.cos(t))
 samples.append(p.exterior.distance(q)-5)
report={'valid_polygon':p.is_valid,'min_gap_mm':min(samples),'max_gap_mm':max(samples),'poses':len(samples),'gate_angles_deg':[-50+i*12.5 for i in range(9)],'interval_lifts_mm':HEIGHTS,'max_lift_mm':max(HEIGHTS)}
assert min(samples)>-.01 and max(samples)<.01,report
(R/'cam-profile-check.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
