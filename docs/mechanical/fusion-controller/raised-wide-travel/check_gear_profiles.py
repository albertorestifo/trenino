import math,json,pathlib,sys
R=pathlib.Path(__file__).parent
sys.path.insert(0,str(R.parent/'inventory-support-free-revision/.validation-libs'))
from shapely.geometry import Polygon
from shapely.affinity import rotate,translate
source=(R.parent/'gear-comparison/01_build_geared_variant.py').read_text();exec('def gear_points'+source.split('def gear_points',1)[1].split('def run',1)[0])
a=Polygon(gear_points(48,1.25,0,0));b=Polygon(gear_points(24,1.25,0,0,math.pi/24))
from shapely.validation import explain_validity
assert a.is_valid and b.is_valid,(explain_validity(a),explain_validity(b))
results=[]
for dist in [45,45.15,45.5,46]:
 areas=[]
 for i in range(-240,241):
  angle=i/4
  aa=rotate(a,angle,origin=(0,0));bb=translate(rotate(b,-2*angle,origin=(0,0)),yoff=dist)
  areas.append(aa.intersection(bb).area)
 rp1,rp2=30,15;rb1,rb2=[r*math.cos(math.radians(20)) for r in [rp1,rp2]]
 alpha=math.acos((rb1+rb2)/dist)
 ratio=(math.sqrt(31.25**2-rb1**2)+math.sqrt(16.25**2-rb2**2)-dist*math.sin(alpha))/(math.pi*1.25*math.cos(math.radians(20)))
 results.append({'center_distance_mm':dist,'max_polygon_intersection_mm2':max(areas),'poses':len(areas),'theoretical_contact_ratio':ratio})
(R/'gear-profile-check.json').write_text(json.dumps(results,indent=2));print(json.dumps(results))
assert max(r['max_polygon_intersection_mm2'] for r in results)<.001
