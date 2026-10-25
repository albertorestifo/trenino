import math,json,sys
from pathlib import Path
R=Path(__file__).parent
sys.path.insert(0,str(R.parent/'inventory-support-free-revision/.validation-libs'))
from shapely.geometry import Polygon,box
from shapely.affinity import rotate,translate
source=(R.parent/'gear-comparison/01_build_geared_variant.py').read_text();exec('def gear_points'+source.split('def gear_points',1)[1].split('def run',1)[0])
main=Polygon(gear_points(48,1.25,0,0));small=Polygon(gear_points(24,1.25,0,0,math.pi/24))
cutmain=main.difference(box(-.2,0,.2,33))
cut=small.difference(box(-.2,0,.2,17)).difference(box(5,4.4,18,10.6))
results=[]
for i in range(-240,241):
 angle=i/4
 a=rotate(main,angle,origin=(0,0));ac=rotate(cutmain,angle,origin=(0,0))
 b=translate(rotate(small,210-2*angle,origin=(0,0)),yoff=-45.15)
 bc=translate(rotate(cut,210-2*angle,origin=(0,0)),yoff=-45.15)
 results.append((angle,ac.distance(bc)-a.distance(b),ac.intersection(bc).area))
report=dict(poses=481,angle_range=[-60,60],max_extra_nearest_tooth_gap_mm=max(x[1] for x in results),max_overlap_mm2=max(x[2] for x in results),scope='Full-depth clamp slit and open tool channel; nominal gear face projected to YZ. Transverse blind screw pockets require native assembly checks.')
(R/'clamp-sector-check.json').write_text(json.dumps(report,indent=2));print(json.dumps(report));assert report['max_extra_nearest_tooth_gap_mm']<.001 and report['max_overlap_mm2']<.001
