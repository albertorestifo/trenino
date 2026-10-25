from pathlib import Path
import json,struct,math
import numpy as np
from PIL import Image,ImageDraw
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.platypus import Paragraph,Table,TableStyle
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.utils import ImageReader

R=Path(__file__).parent; O=R/'illustrated-guide';O.mkdir(exist_ok=True)
rows=json.loads((R/'export-manifest.json').read_text())
palette=['#2596a8','#e7a33d','#6577b7','#75a868','#d97963','#7e8a98']
def meshes(prefix):return [r for r in rows if r['file'].startswith(prefix)]
def render(name,items,view=(1,-1,.75)):
 # True exported v6 geometry, translated only for exploded illustrations.
 v=np.array(view,dtype=float);v/=np.linalg.norm(v);right=np.cross([0,0,1],v);right/=np.linalg.norm(right);up=np.cross(v,right)
 alltri=[];allcol=[]
 for prefix,offset,color in items:
  for row in meshes(prefix):
   raw=(R/'raw-stl'/row['file']).read_bytes();n=struct.unpack_from('<I',raw,80)[0]
   a=np.frombuffer(raw[84:],dtype=np.dtype([('normal','<f4',3),('v','<f4',(3,3)),('attr','<u2')]))['v'].astype(float)+offset
   alltri.append(a);allcol.extend([color]*len(a))
 a=np.concatenate(alltri);xy=np.stack([a@right,a@up],axis=-1);depth=(a@v).mean(axis=1)
 mn=xy.min(axis=(0,1));mx=xy.max(axis=(0,1));scale=min(1420/(mx[0]-mn[0]),740/(mx[1]-mn[1]));xy=(xy-(mn+mx)/2)*[scale,-scale]+[800,430]
 normal=np.cross(a[:,1]-a[:,0],a[:,2]-a[:,0]);normal/=np.maximum(np.linalg.norm(normal,axis=1)[:,None],1e-12)
 light=np.array([.2,-.4,.9]);shade=.50+.5*np.abs(normal@light)
 im=Image.new('RGB',(1600,860),'white');d=ImageDraw.Draw(im)
 for i in np.argsort(depth):
  col=colors.HexColor(allcol[i]);rgb=tuple(int(min(255,255*c*shade[i])) for c in (col.red,col.green,col.blue))
  d.polygon([tuple(p) for p in xy[i]],fill=rgb)
 im.save(O/(name+'.png'));return O/(name+'.png')

shaft=render('shaft', [('P05-Shaft-lower',[0,-12,0],palette[0]),('P05-Shaft-upper',[0,12,0],palette[1]),('P28',[0,0,0],palette[2])],(1,-2,2))
stack=render('rotor-stack',[('P06',[-45,0,0],palette[5]),('P03',[-30,0,0],palette[2]),('P23',[-15,0,0],palette[1]),('P07',[0,0,0],palette[0]),('P24',[20,0,0],palette[1]),('P04',[35,0,0],palette[2])],(1,-2,.8))
follower=render('follower',[('P11',[0,0,0],palette[0]),('P21',[-14,0,0],palette[1]),('P22',[14,0,0],palette[1]),('P25',[0,-9,-8],palette[2]),('P26',[0,9,-8],palette[3])],(1,-1,1.5))
spring=render('spring',[('P13',[0,0,12],palette[0]),('P14',[0,0,-8],palette[1]),('P15',[0,0,22],palette[4]),('P27-Printed-guide-sleeve-4',[-6,0,-12],palette[2]),('P27-Printed-guide-sleeve-20',[6,0,-12],palette[2])],(1,-1,.8))
cam=render('cam-grip',[('P07',[0,0,0],palette[0]),('P08-Cam-5',[27,0,0],palette[1]),('P09',[-25,0,15],palette[2]),('P10',[25,0,15],palette[3])],(1,-2,.6))
coupling=render('coupling',[('P05',[0,0,0],palette[0]),('P18',[15,0,0],palette[1]),('P19',[30,0,0],palette[2]),('P16',[55,0,0],palette[3])],(1,-2,1.1))
plates=render('plates',[('P01',[-20,0,0],palette[0]),('P02',[20,0,0],palette[1])],(1,-2,1))

PDF=O/'Compact-Lever-v6-Assembly-Guide.pdf';c=canvas.Canvas(str(PDF),pagesize=(595.28,841.89));W,H=595.28,841.89
c.setTitle('Compact Lever v6 Assembly Guide');c.setAuthor('Prepared for Alberto')
style=ParagraphStyle('body',fontName='Helvetica',fontSize=10.5,leading=15,textColor=colors.HexColor('#202b34'))
small=ParagraphStyle('small',parent=style,fontSize=9,leading=12)
page=0
def p(text,x,y,w=499,st=style):
 q=Paragraph(text,st);_,h=q.wrap(w,700);q.drawOn(c,x,y-h);return y-h-10
def begin(title,kicker):
 global page;page+=1
 c.setFillColor(colors.HexColor('#526473'));c.setFont('Helvetica',9);c.drawString(48,802,'COMPACT LEVER  /  FUSION v6')
 c.setFillColor(colors.black);c.setFont('Helvetica-Bold',23);c.drawString(48,763,title)
 p(kicker,48,745,499,small)
def end():
 c.setFillColor(colors.HexColor('#526473'));c.setFont('Helvetica',8);c.drawString(48,30,'Assembly guide  |  25 October 2026  |  Dimensions in mm');c.drawRightString(547,30,str(page));c.showPage()
def picture(path,y,h=260):c.drawImage(ImageReader(str(path)),48,y,499,h,preserveAspectRatio=True,anchor='c',mask='auto')
def step(n,title,text,y):
 c.setFillColor(colors.HexColor('#147f91'));c.setFont('Helvetica-Bold',15);c.drawString(48,y,str(n))
 c.setFillColor(colors.black);c.setFont('Helvetica-Bold',12);c.drawString(76,y,title)
 return p(text,76,y-12,471)-9
def legend(entries,y):
 x=48
 for col,txt in entries:
  c.setFillColor(colors.HexColor(col));c.circle(x+4,y-4,4,fill=1,stroke=0);p(txt,x+13,y+2,150,small);x+=168
def line(x1,y1,x2,y2,col='#526473'):
 c.setStrokeColor(colors.HexColor(col));c.setLineWidth(1);c.line(x1,y1,x2,y2)
def arrow(x1,y1,x2,y2):
 line(x1,y1,x2,y2,'#147f91');a=math.atan2(y2-y1,x2-x1)
 for sg in [-1,1]:line(x2,y2,x2-7*math.cos(a+sg*.45),y2-7*math.sin(a+sg*.45),'#147f91')
def box(x,y,w,h,label,color):
 c.setFillColor(colors.HexColor(color));c.setStrokeColor(colors.HexColor('#33434e'));c.rect(x,y,w,h,fill=1);c.setFillColor(colors.black);c.setFont('Helvetica-Bold',9);c.drawCentredString(x+w/2,y+h/2-3,label)
def table(data,y,widths):
 cells=[[Paragraph(str(v),small) for v in row] for row in data];t=Table(cells,colWidths=widths)
 t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e5edf1')),('GRID',(0,0),(-1,-1),.4,colors.HexColor('#d9d9d9')),('VALIGN',(0,0),(-1,-1),'MIDDLE'),('TOPPADDING',(0,0),(-1,-1),7),('BOTTOMPADDING',(0,0),(-1,-1),7)]))
 _,h=t.wrap(499,700);t.drawOn(c,48,y-h);return y-h-14

begin('Lever assembly guide','A practical build sequence for the compact stock-based prototype')
p('Build one complete lever from the v6 parts. Start with the small fits, assemble the moving mechanisms on the bench, then fit the unit to the rails. The pictures below use the saved model and its exported geometry.',48,704)
picture(R/'assembly-overview.png',300,350)
y=p('<b>Read the pictures</b>  Teal, amber and violet distinguish printed parts in the exploded views. Those views separate parts for clarity; they do not show working gaps. Diagrams are schematic and not to scale.',48,276)
y=p('<b>Use the right files</b>  Print from the v6 <b>stl</b> folder. There are 30 files with three alternative cams: choose one cam, for 28 printed pieces. P12, P17 and P20 are intentionally absent. Both P05 halves, both pivot halves, both guide sleeves and both alignment keys are needed.',48,y)
p('<b>Prototype checks</b>  Sensor dimensions and its supplied nut/washer are not confirmed. Spring rate and solid height are assumed. Printed shaft and pivot strength still need a low-load physical test. These checks appear at the relevant steps.',48,y-69)
end()

begin('Prepare the bench','Sort screws by length before assembly')
y=table([['Hardware','Qty','Used for'],['M3 x 8 cap screws','3','Shaft joint 2; retaining cap 1'],['M3 x 10 cap screws','3','One cam'],['M3 x 12 cap screws','4','Carriage 2; cup guides 2'],['M3 x 16 cap screws','2','Rotor clamp; sensor clamp'],['M3 x 20 cap screws','10','Crossblock 4; grip 2; stops 2; bearing axle; preload'],['M3 plain nuts','3','Stops 2; bearing axle 1'],['M3 x 5.7 heat-set inserts','19','CNC Kitchen standard inserts'],['M5 x 14 screws and M5 T-nuts','4 each','Rail mounts'],['623ZZ bearings','2','3 mm bore x 10 mm OD x 4 mm width'],['Compression spring','1','1 mm wire; 9 mm OD; 20 mm free length'],['RK097 A10K potentiometer','1','Mounting nut/washer assumed supplied'] ],710,[170,40,289])
y=p('<b>Tools</b>  Matching hex keys, a controlled-temperature insert tool, calipers, small deburring tools and a multimeter for sensor centering. A temporary holding tool helps retract the follower during cam changes.',48,y)
y=p('<b>Before fitting hardware</b>  Remove loose brim and strings. Keep bearing bores and coupling grooves smooth without enlarging them unnecessarily. Test a heat-set insert on scrap before installing the full set. Do not force a tight shaft through a bush.',48,y)
p('<b>Inventory status</b>  Records show enough of the seven BOM stock items, but most counts are estimates. Confirm the potentiometer mounting hardware and actual T-nut fit. No metal tube cutting is required.',48,y)
end()

begin('Join the printed shaft','Step 1  Install inserts before closing mating parts')
picture(shaft,435,260);legend([(palette[0],'P05 lower half'),(palette[1],'P05 upper half'),(palette[2],'Two P28 keys')],425)
y=step(1,'Seat the inserts', 'Install three inserts in P05: two for the joining screws and one for the retaining cap. Keep insert faces flush and preserve the shaft seam and bore geometry.',375)
y=step(2,'Fit the two alignment keys','Seat both P28 keys in their mating pockets. Bring the flat split faces together. The keys align the halves; the screws hold them together.',y)
y=step(3,'Fasten the halves','Use two M3 x 8 cap screws in the recessed joining holes. Tighten evenly until the seam closes. Stop if an insert moves or the shaft distorts.',y)
p('<b>Check</b>  The seam must be flush along the journals and coupling tongue. Test the shaft in P03/P04 by hand. It must turn freely without scraping or forcing. The split shaft is a prototype and has no validated load rating.',48,y-5)
end()

begin('Build the rotor stack','Step 2  Assemble the shaft bearings and rotor on the bench')
picture(stack,435,270);legend([(palette[0],'P07 rotor and lever'),(palette[1],'P23 and P24 spacers'),(palette[2],'P03 and P04 bushes')],420)
y=step(4,'Install the remaining inserts','Insert allocation: P07 rotor 4; P09 grip 2; P13 crossblock 7; P19 sensor clamp 1; carriage supports on P02 2. Together with the three shaft inserts, this is 19. Keep underside pockets accessible.',373)
y=step(5,'Arrange the stack','From the retaining-cap side toward the sensor: P06 cap, P03 left bush, P23 left spacer, P07 rotor, P24 right spacer, P04 right bush. The P05 shaft passes through this stack; it is omitted from the exploded picture for clarity.',y)
y=step(6,'Keep the rotor free','Fit the retaining cap with one M3 x 8 and the rotor clamp with one M3 x 16. Preserve about 0.3 mm total end float. Do not tighten the cap to eliminate the designed running clearance.',y)
p('<b>Check</b>  Bush flanges face outward at the plates. Tighten the rotor clamp only enough to remove drive play without crushing the printed shaft. Install this stack between the plates during Step 3.',48,y-3)
end()

begin('Fit the follower and pivot','Step 3  The pivot is trapped when the sideplates are closed')
picture(follower,470,230);legend([(palette[0],'P11 follower'),(palette[1],'P21 long / P22 short'),(palette[2],'P25 violet / P26 green')],458)
y=step(7,'Install the bearing pair','Fit the two 623ZZ bearings between the fork pads with one M3 x 20 axle screw and one plain nut. The pads contact the inner races. Both outer rings must turn freely after tightening.',411)
# bearing section across shaft axis
for x,w,lab,col in [(105,35,'pad',palette[0]),(140,90,'623ZZ',palette[1]),(230,90,'623ZZ',palette[1]),(320,35,'pad',palette[0])]:box(x,274,w,38,lab,col)
line(78,293,384,293);p('Schematic axle section  •  inner races carry clamp load',100,264,410,small)
y=step(8,'Capture the printed pivot','Mate P25 and P26 into one round pivot. Pass it through P21, the follower and P22. P21 is the long left spacer; P22 is the short sensor-side spacer. Seat both pivot ends in the blind sideplate pockets.',223)
y=step(9,'Bring the plates together','Install the rotor stack and pivot assembly between P01/P02. Attach P13 with four M3 x 20 screws. A sideplate must be released to remove the captive pivot later.',y)
p('<b>Check</b>  The follower pivots freely with slight axial clearance. Verify bearing pads do not rub shields. Do not assume the printed split pivot has the strength of a metal sleeve.',48,y)
end()

begin('Assemble the spring cup','Step 4  Start with the lowest preload')
picture(spring,475,220);legend([(palette[0],'P13 reaction block'),(palette[1],'P14 cup and pilot'),(palette[2],'Two P27 sleeves')],460)
y=step(10,'Fit the guides','The two printed 6 mm sleeves run through the cup guide holes. M3 x 12 screws enter from below into the underside crossblock inserts. The screws clamp the sleeves, while the cup can slide.',415)
y=step(11,'Fit the spring and adjuster','Place the spring between the follower spring seat and cup, around the cup pilot. Fit the 1 mm P15 collar in the top recess and the M3 x 20 preload screw. Its tip bears on the cup. Do not omit the collar.',y)
# vertical force diagram
box(385,160,115,23,'P13 block',palette[0]);box(418,197,49,13,'P15',palette[4]);line(443,222,443,136);arrow(443,136,443,122)
box(390,106,105,14,'P14 cup',palette[1]);line(443,105,443,94)
pts=[(443+(12 if i%2 else -12),92-i*5) for i in range(8)]
for a,b in zip(pts,pts[1:]):line(*a,*b)
line(385,53,500,53);p('Follower seat',390,48,120,small)
p('<b>Check the spring assumption</b><br/>Installed length is nominally 17 mm; estimated minimum during operation is 15.2 mm. Solid height is assumed no more than 14 mm. Confirm that it does not bind before applying meaningful hand force. Rate and actual detent force are unknown.',48,212,295)
p('Schematic side section',372,242,170,small)
end()

begin('Attach the cam and grip','Step 5  Fit one cam only')
picture(cam,429,270);legend([(palette[0],'P07 lever'),(palette[1],'P08 selected cam'),(palette[2],'P09 violet / P10 green')],415)
y=step(12,'Choose a cam','Fit the 3, 5 or 7 gate cam to the carrier with three M3 x 10 screws. Start with the 5 gate variant if you have no preference. The bearing pair follows its lower profile.',370)
y=step(13,'Fit stops and grip','Install the two plain stop nuts and recessed M3 x 20 stop screws in P01. Fit P09/P10 around the keyed stem with two M3 x 20 screws. Seat the grip seam before tightening.',y)
y=step(14,'Test motion before fitting the sensor','Sweep the lever gently through its range. Structural stops are at approximately -52 and +52 degrees; stable end gates are at -50 and +50 degrees. Watch the follower and spring for binding.',y)
p('<b>Check</b>  Keep fingers clear of the cam and spring while testing. Start with low preload and a light hand load. Any binding, whitening, cracked layers or shifting inserts must be resolved before further use.',48,y)
end()

begin('Connect the potentiometer','Step 6  Center the lever and sensor before tightening')
picture(coupling,465,235);legend([(palette[0],'P05 integrated tongue'),(palette[1],'P18 floating disc'),(palette[2],'P19 split clamp')],453)
p('Green part: P16 adjustable mount. Exploded translations show the sequence; actual gaps are much smaller.',48,429,499,small)
y=step(15,'Fit disc and clamp','Slide P18 onto the shaft tongue. Fit P19 to the sensor shaft with one M3 x 16 clamp screw. The disc grooves are perpendicular: one accepts the shaft tongue, the other the clamp tongue.',388)
y=step(16,'Attach and adjust the sensor mount','Secure the potentiometer in P16 using its assumed supplied nut/washer. Tighten accessible clamp hardware, then fix the carriage with two M3 x 12 screws. Adjust axially so the tongues engage without bottoming.',y)
# functional chain
for x,w,lab,col in [(57,114,'P05 tongue',palette[0]),(209,91,'P18 disc',palette[1]),(338,114,'P19 clamp',palette[2])]:box(x,155,w,36,lab,col)
arrow(174,173,204,173);arrow(304,173,333,173);arrow(456,173,524,173);p('Sensor',469,150,75,small)
p('<b>Nominal working clearances</b>  Face gaps 0.65 mm; tongue-to-groove-bottom gaps 0.45 mm. Preserve shaft end float. The disc must slide freely and must not transmit hand loads into the potentiometer.',48,126)
p('<b>Verify fit</b>  Model assumes a 6 mm shaft, M7 bushing and 12 mm exposed shaft. The seller’s 15 mm label does not confirm that datum. The pot and supplied mounting hardware remain unmeasured.',48,75,499,small)
end()

begin('Mount and commission','Step 7  Fit the complete mechanism to the upper rails')
picture(plates,474,220);legend([(palette[0],'P01 left plate'),(palette[1],'P02 sensor-side plate')],459)
y=step(17,'Fasten to the rails','Seat all four mounting flanges on the upper rails. Use four M5 x 14 screws with compatible M5 drop-in T-nuts. Do not add the old washer/spacer stacks. Verify thread engagement and that screw tips do not bottom out.',415)
y=step(18,'Check sensor travel and calibrate','Sweep slowly with power off. The structural stops must engage before the sensor reaches its own stops. Connect the sensor, calibrate electrical endpoints in firmware, and compare gate readings approached from both directions.',y)
y=p('<b>Leave space</b>  Overall module envelope is about 125.5 mm wide. Add clearance for fingers, wiring and tolerances. Cam servicing needs 40 mm of sideways withdrawal space; slide a neighboring module away when necessary.',48,y)
y=p('<b>Cam changes</b>  Remove the three cam screws, back off the preload adjuster, hold the follower about 5 degrees down and slide the cam sideways. Backing off the screw does not fully unload the captive spring. To unload it, restrain the cup and carefully release its guide hardware before removing the spring.',48,y)
p('<b>Final checks</b>  Free shaft rotation and follower movement; free bearing outer rings; seated inserts and nuts; no coil bind; coupling slides without bottoming; structural stops protect the sensor; no rail bolt bottoming. Recheck fasteners after the first light-load session.',48,y)
end()
c.save();print(PDF)

