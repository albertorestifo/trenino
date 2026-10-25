import math,json,sys
from pathlib import Path
R=Path(__file__).parent
sys.path.insert(0,str(R.parent/'inventory-support-free-revision/.validation-libs'))
from shapely.geometry import Polygon,Point
from shapely.affinity import rotate,translate
exec('def campt'+(R/'01_revise.py').read_text().split('def campt',1)[1].split('def run',1)[0])
results=[]
for n in [3,5,7,8]:
 outer=[campt(math.radians(-70+i*.25),n) for i in range(561)]
 inner=[(-29*math.sin(math.radians(t)),65-29*math.cos(math.radians(t))) for t in range(70,-71,-2)]
 cam=Polygon(outer+inner);assert cam.is_valid
 gaps=[]
 for i in range(-240,241):
  angle=i/4;t=math.radians(angle)
  beta=-.5*1.4*(1-math.cos(2*math.pi*(t+math.radians(58))/math.radians(116/(n-1))))/35
  center=Point(-35+35*math.cos(beta),12+35*math.sin(beta))
  posed=rotate(cam,angle,origin=(0,65))
  gaps.append(posed.distance(center)-5)
 results.append(dict(gates=n,gate_pitch_deg=116/(n-1),poses=481,min_roller_gap_mm=min(gaps),max_roller_gap_mm=max(gaps),polygon_valid=cam.is_valid))
 assert min(gaps)>-.02 and max(gaps)<.02,(n,min(gaps),max(gaps))
(R/'cam-profile-check.json').write_text(json.dumps(results,indent=2));print(json.dumps(results))
