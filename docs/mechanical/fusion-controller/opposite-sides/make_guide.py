from pathlib import Path
import re
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,Image,PageBreak,KeepTogether
from reportlab.lib.styles import getSampleStyleSheet,ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.graphics.shapes import Drawing,Rect,Line,String
R=Path(__file__).parent
styles=getSampleStyleSheet()
styles.add(ParagraphStyle(name='TitleCustom',fontName='Helvetica-Bold',fontSize=26,leading=30,textColor=colors.HexColor('#17374a'),spaceAfter=14))
styles.add(ParagraphStyle(name='Lead',fontSize=11,leading=16,spaceAfter=12))
styles['BodyText'].leading=13.5;styles['BodyText'].spaceAfter=9
styles['Heading2'].textColor=colors.HexColor('#17374a');styles['Heading2'].spaceBefore=12
styles.add(ParagraphStyle(name='SmallNote',fontSize=8,leading=11,textColor=colors.HexColor('#465660')))
story=[]
def para(t,style='BodyText'):
 t=re.sub(r'(?<=\d)(?=[a-z])',' ',t)
 t=re.sub(r'(?<=[a-uw-z])(?=\d)',' ',t)
 return Paragraph(t,styles[style])
def text(t,style='BodyText'):story.append(para(t,style))
def title(n,t):text(f'{n} / {t}','TitleCustom')
def step(n,t):text(f'<b>{n}.</b> {t}')
def table(rows,widths):
 t=Table([[para(str(c),'SmallNote') for c in row] for row in rows],colWidths=widths,hAlign='LEFT')
 t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e4eef2')),('VALIGN',(0,0),(-1,-1),'TOP'),('LINEBELOW',(0,0),(-1,-1),.3,colors.HexColor('#c8d2d8')),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)]));story.append(t)
def page():story.append(PageBreak())
title('01','Opposite-side lever')
text('Assembly and cam-service guide','Lead')
text('Cam and follower on the left; geared potentiometer on the right. The mechanism hangs from the top rails. No top panel is included. Preserve the pre-gear v6 build for comparison.')
story.append(Image(str(R/'cam-service-side.png'),width=390,height=334))
text('Actual Fusion model: cam-service side. The large side plates carry the main pivot and rail loads; the outer cassette carries the follower.','SmallNote')
table([['Travel','Sensor drive','Cam options'],['120 degrees mechanical (+/-60)','48:24 gears, pot rotates twice lever angle','3, 5, 7 or 8 gates over116 degrees']],[163,163,163])
text('Prototype: pot travel, spring solid height, print fit, strength and wear still require physical checks. CAD interference checks do not establish a load rating. The review records and validation notes accompany the geometry.','SmallNote')
page();title('02','Parts and axial layout')
d=Drawing(489,150)
d.add(Line(20,65,470,65,strokeColor=colors.HexColor('#7294a5')))
blocks=[(25,35,45,55,'Cam'),(83,45,38,45,'Carrier'),(135,35,50,65,'P01'),(203,45,75,45,'Rotor'),(298,35,50,65,'P02'),(370,45,55,45,'Gears')]
for x,y,w,h,label in blocks:
 d.add(Rect(x,y,w,h,fillColor=colors.HexColor('#d9e9ef'),strokeColor=colors.HexColor('#386075')));d.add(String(x+w/2,y+h/2,label,fontSize=9,textAnchor='middle'))
d.add(String(20,125,'LEFT: service access',fontSize=10));d.add(String(345,125,'RIGHT: sensor drive',fontSize=10))
d.add(String(242,16,'Schematic axial order; not a dimensional drawing',fontSize=8,textAnchor='middle'))
story.append(d)
table([['Hardware for one geared build','Qty','Use'],['M3 x 20 cap screw','16','Braces8, springblock2, cassette2, grip2, roller1, preload1'],['M3 x 16 cap screw','3','Stops2, rotor clamp1'],['M3 x 12 cap screw','7','Gear clamps2, pot panel2, cup guides2, temporary service1'],['M3 x 10 / M3 x 8','4 / 3','Cam3 + carrierclamp1 / shaftjoin2 + cap1'],['M3 plain nut / CNC M3 inserts','1 / 32','Roller axle / all specified insert pockets'],['M5 x 14 / 2020 M5 T-nuts','4 / 4','Top rail attachment'],['623ZZ bearings','2','Follower roller, 3 x10 x4mm each'],['Spring / measured pot','1 / 1','Wire1, OD9, free20 / body11.2 x9.5 x6.6mm']],[178,40,271])
text('Stock basis: one known-content M3 kit plus separately stocked M3x20 Torx screws supports the two-build comparison on paper. Counts other than the100 CNC inserts are estimated. Recount before printing; use six Torx screws at accessible crossbrace positions and check their head fit. Inventory is not reserved or consumed.','SmallNote')
page();title('03','Shaft and structure')
step(1,'Test the shaft/bush and insert interfaces first. Fit the two shaft halves and loose alignment key; install the shaft inserts from the split face before joining the halves with two M3x8 screws. Keep every head flush.')
step(2,'Fit rotor and two thrust spacers on the central D section. Slide the bushes on from their respective shaft ends. The right end has no enlarged shoulder, so its bush is removable. Leave the rotor clamp light until the plates are assembled.')
step(3,'Place the shaft/rotor between P01 and P02. Install both crossbraces with four M3x20 screws each. Tighten evenly. Confirm smooth rotation and free axial movement; nominal total axial clearance is0.4mm, subject to actual printing.')
step(4,'Seat the two stop-pad spigots in P01. Retain each with a recessed M3x16 screw. The screw head is flush with the outside plate; the locating spigot transfers transverse stop load. Check both ends of travel gently.')
step(5,'Fit the left keyed cam carrier, retaining cap and M3x8 screw. Tighten its radial M3x10 clamp onto the shaft flat. Keep clearance to the bush flange. Fit a cam with three outward-facing M3x10 screws.')
step(6,'Attach the grip halves around the keyed stem with two M3x20 screws. Tighten the rotor clamp only after checking the full mechanism turns without bearing pinch.')
text('Insert installation','Heading2')
text('CNC Kitchen M3 inserts: installed OD4.6mm, length5.7mm; nominal pilot4.0mm with at least6.7mm blind depth. Deeper screw-tip pockets are intentional. Printed compensation must come from a coupon. Install with components separate and allow them to cool before tightening.')
text('Do not tighten a joint until a moving bush becomes a friction clamp. Inspect the actual shaft split, journal roundness and axial clearance. The printed shaft remains split so its long load path can print parallel to the bed.','SmallNote')
page();title('04','Follower and sensor')
step(7,'Fit two623ZZ bearings between the follower cheeks. The printed pads touch their inner races. Install the M3x20 axle and plain nut; the bearings must turn freely after tightening.')
step(8,'Fit the two captured follower-pivot halves and the inner axial spacer. Install P33 with its integral compression posts and two recessed M3x20 screws. Confirm free follower movement before fitting the spring.')
step(9,'Assemble cup, guide sleeves and M3x12 guide screws on the reaction block. Retain the spring between cup and follower tail. Attach the reaction block with two M3x20 screws. Start with preload fully backed off to its specified position.')
step(10,'Mount the pot in the removable panel using its supplied washer/nut. Set both lever and pot to their centers. Install the pinion on the moving6mm shaft, then the main gear. Set nominal center distance45.15mm; adjust only within45.0-45.5mm and verify free mesh.')
story.append(Image(str(R/'mechanism-detail.png'),width=285,height=244))
text('Actual Fusion model: gear/sensor side. Measured moving shaft length is8mm; the additional7mm is inferred M7 bushing length. Terminal dimensions and the supplied nut/washer envelope remain unverified.','SmallNote')
text('Mount the unit with four M5x14 screws and four2020 T-nuts. Verify engagement and clearance to the rail web, then route wires away from all moving parts. Never let the pot act as an end stop.','SmallNote')
page();title('05','Change cams and commission')
step(1,'Back spring preload fully off. Put the lever at its central reference. The eight-gate cam has a central crest; it does not have a central notch.')
step(2,'Move the follower to its absolute -4 degree service position. Install the temporary M3x12 service screw through the outer plate into the dedicated follower-tail insert. Confirm positive retention before removing the cam screws.')
step(3,'Remove the three outward-facing M3x10 screws. Withdraw the cam to the left. Leave shaft, carrier, bearing plates, gears and pot in place. Allow at least20mm temporary service space; tightly packed modules may need removal from the rails.')
step(4,'Fit the replacement cam, tighten its three screws, remove the service screw, then restore preload gradually. Never operate the lever with the service screw fitted.')
text('Physical checks before use','Heading2')
table([['Check','Acceptance to establish physically'],['Spring','Measure solid height and confirm clearance at every gate, crest and service position. Rate is unrecorded; do not assume the catalog envelope determines force.'],['Pot','Confirm usable travel exceeds240 degrees plus margin. Otherwise restrict lever travel before applying force. Verify electrical taper and calibration.'],['Fits and stops','Check bush rotation, insert retention, shaft/cam/gear clamp slip, stop-pad seating and gentle load response. No impact or rated abuse claim.'],['Compare with v6','Record assembly/cam-change time, breakaway force, notch-force spread, reversal dead travel, electrical noise and repeat-cycle wear under the same sampling/filtering.']],[95,394])
text('A2:1 gear ratio gives greater sensor rotation for the same lever motion. Effective resolution still depends on pot quality, noise, ADC behavior and backlash.','SmallNote')
page();title('06','Print order and orientation')
text('Use the supplied oriented millimeter STLs and your unchanged selected printer/material/process defaults. Print the critical fit interfaces before the large plates. Do not interpret zero generated supports as proof of strength or perfect bridging.')
table([['Parts','Bed face / check'],['P01 / P02','Inner broad faces down. Inspect rail-hole roofs and the 12.3 mm blind stop-socket bridges in P01.'],['P05 shaft / P25-P26 pivot','Longitudinal split faces down. Inspect insert/key-pocket closures and fit before joining.'],['P07 rotor','Broad X-min face down; inspect radial clamp roof and lower stop-root continuity.'],['P08 cams / P32 carrier','Inner X-max face down. Cam counterbores and carrier inserts face upward; inspect carrier pocket floors.'],['P31 stop pads','Contact X-max face down. Supported tapered base and locating spigot grow upward.'],['P33 cassette','Outer X-min face down; integral posts grow upward. Inspect6.2mm counterbore bridges.'],['P30 crossbraces','X face down; inspect4mm pocket bridges on the lower end.'],['P13 block / P14 cup','Z-max face down; inspect horizontal mounting roofs and cup pilot.'],['Other parts','Use the orientation recorded for that STL in mesh-check.json; do not rotate every part by its assembly pose.']],[148,341])
text('Release status','Heading2')
text('This package supplies prototype geometry, not printer-ready G-code. The existing diagnostic slicer CLI reports machine/tool configuration errors, so its toolpaths must not be sent to the printer. Re-slice the oriented STLs in Bambu Studio with the correct selected printer and filament.')
text('The accompanying VALIDATION.md distinguishes completed digital checks from physical commissioning. Specialist review reports, dispositions and model scripts are retained beside the export for traceability.','SmallNote')
def footer(c,doc):
 c.setStrokeColor(colors.HexColor('#b8cad3'));c.line(42,39,553,39);c.setFont('Helvetica',8);c.setFillColor(colors.HexColor('#465660'));c.drawString(42,26,'Opposite-side lever | Prototype assembly | 25 October 2026');c.drawRightString(553,26,str(doc.page))
SimpleDocTemplate(str(R/'Assembly-Guide.pdf'),pagesize=(595,842),rightMargin=53,leftMargin=53,topMargin=42,bottomMargin=52,title='Opposite-side lever assembly guide',author='Codex - AI assisted design').build(story,onFirstPage=footer,onLaterPages=footer)
print(R/'Assembly-Guide.pdf')
