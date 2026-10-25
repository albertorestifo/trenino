from pathlib import Path
import math
from cam_profile import outline
r=Path(__file__).parent
pts=' '.join(f'{280+y*4:.2f},{310+(z-40)*4:.2f}' for y,z in outline())
s=f'''<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="620" viewBox="0 0 1000 620"><rect width="1000" height="620" fill="#f5f4ef"/><g font-family="Arial" fill="#1f3440"><text x="40" y="48" font-size="28">Class 323 · nine-position cam</text><text x="40" y="78" font-size="16">Direct-pot mechanism / schematic of the actual profile</text><polygon points="{pts}" fill="#e4ae4b" stroke="#1f3440" stroke-width="2"/>'''
for a in [-45,0,45]:
 y=-36*math.sin(math.radians(a));z=65-36*math.cos(math.radians(a));s+=f'<circle cx="{280+y*4}" cy="{310+(z-40)*4}" r="12.4" fill="#f5f4ef" stroke="#1f3440"/><circle cx="{280+y*4}" cy="{310+(z-40)*4}" r="6.8" fill="#1f3440"/>'
for i in range(9):
 a=math.radians(-50+i*12.5);x=280-54*math.sin(a)*4;y=310+(65-54*math.cos(a)-40)*4
 s+=f'<text x="{x}" y="{y}" font-size="18" text-anchor="middle">{("E" if i==8 else "C" if i==4 else str(i+1))}</text>'
s+='''<text x="550" y="155" font-size="22">9 gates / 100° usable span</text><text x="550" y="195" font-size="18">Center: higher barrier on both sides</text><text x="550" y="230" font-size="18">Emergency: higher final barrier</text><text x="550" y="265" font-size="18">Higher barriers resist both directions</text><text x="550" y="315" font-size="18">E engraving and screw recesses face out</text><text x="550" y="350" font-size="18">Print opposite flat face on the bed</text><text x="40" y="490" font-size="18">Interval lift (mm): 0.65 · 0.65 · 0.65 · 0.90 · 0.90 · 0.65 · 0.65 · 1.00</text><text x="40" y="525" font-size="16">Numbers identify positions only. No train-specific power/brake labels are inferred.</text><text x="40" y="555" font-size="16">Actual detent forces require testing with your spring and printed assembly.</text></g></svg>'''
(r/'Class323-cam-diagram.svg').write_text(s,encoding='utf-8')
