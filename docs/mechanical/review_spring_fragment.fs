// Integration fragment: replace old schematic spring/adjust block and retain original M4 nut-pocket cut.
// Requires v/cyl/makeBlock/merge/cut/label/hexPrism and existing bracket, beta, id/context.
// Adds one printable springCup, two M3x20 guide bolts + two M3 nuts, one M4x20 screw + M4 nut.
// Guide bolts are static; cup only slides during preload adjustment. M4 screw tip presses cup.
// Cup is captured by guide-bolt heads even with screw backed off. Neutral spring installed length14mm.
// Print cup on its broad y-normal face, guide peg upward (rotateX -90degree then place).

bracket=merge(context,id+"springGuideBossUnion",[bracket,
 makeBlock(context,id+"springGuideBoss",v(-59,-28,25),v(-49,-22,47))]);
var springCup=merge(context,id+"springCupUnion",[
 makeBlock(context,id+"springCupBack",v(-59,-30,25),v(-49,-28,47)),
 cyl(context,id+"springCupPilot",v(-54,-39,36),v(-54,-29.5,36),2)]);
var springGuideHardware=[];
for(var gz in [28,44]) {
 cut(context,id+("springCupGuide"~gz),springCup,cyl(context,id+("springCupGuideTool"~gz),v(-54,-31,gz),v(-54,-27,gz),1.8));
 cut(context,id+("springBracketGuide"~gz),bracket,cyl(context,id+("springBracketGuideTool"~gz),v(-54,-29,gz),v(-54,-21,gz),1.7));
 var gb=merge(context,id+("springGuideBoltUnion"~gz),[
 cyl(context,id+("springGuideBoltShank"~gz),v(-54,-38,gz),v(-54,-18,gz),1.5),
 cyl(context,id+("springGuideBoltHead"~gz),v(-54,-39.65,gz),v(-54,-38,gz),2.85)]);
 label(context,gb,"HARDWARE M3 x20 spring cup guide bolt",color(0.65,0.67,0.7));
 var gn=hexPrism(context,id+("springGuideNut"~gz),0,0,0,5.5,2.4);
 cut(context,id+("springGuideNutBore"~gz),gn,cyl(context,id+("springGuideNutBoreTool"~gz),v(0,0,-1),v(0,0,3.4),1.5));
 opTransform(context,id+("springGuideNutPlace"~gz),{"bodies":gn,"transform":transform(v(-54,-19.6,gz))*rotationAround(line(v(0,0,0),vector(1,0,0)),90*degree)});
 label(context,gn,"HARDWARE M3 spring cup guide nut",color(0.65,0.67,0.7));
 springGuideHardware=append(springGuideHardware,gb); springGuideHardware=append(springGuideHardware,gn);
}
label(context,springCup,"PRINT Spring cup - captive on two M3 guide screws",color(0.35,0.42,0.46));
// Locate spring at the fork tail using a short pilot inside its5mm minimum ID.
// Seat oriented in neutral assembly; cut before rotating the arm by beta.
arm=merge(context,id+"tailSpringPilotUnion",[arm,cyl(context,id+"tailSpringPilot",v(-54,-44.2,36),v(-54,-41.5,36),1.8)]);
const seatY=-48-18*sin(beta)+4*cos(beta);
var spring=cyl(context,id+"spring",v(-54,seatY,36),v(-54,-30,36),4);
cut(context,id+"springHollow",spring,cyl(context,id+"springTool",v(-54,seatY-1,36),v(-54,-29,36),2.5));
label(context,spring,"SPRING ENVELOPE 8 OD, >=5 ID;14mm installed nominal; select rate by bench test",color(0.7,0.3,0.65,0.45));
var adjust=merge(context,id+"adjustUnion",[
 cyl(context,id+"adjustShank",v(-54,-28,36),v(-54,-8,36),2),
 cyl(context,id+"adjustHead",v(-54,-8,36),v(-54,-4.9,36),3.8)]);
label(context,adjust,"HARDWARE M4 x20 button-head adjuster; external tool access",color(0.6,0.62,0.65));
var adjustNut=hexPrism(context,id+"adjustNut",0,0,0,7,3.2);
cut(context,id+"adjustNutBore",adjustNut,cyl(context,id+"adjustNutTool",v(0,0,-1),v(0,0,4.2),2));
opTransform(context,id+"adjustNutPlace",{"bodies":adjustNut,"transform":transform(v(-54,-22,36))*rotationAround(line(v(0,0,0),vector(1,0,0)),90*degree)});
label(context,adjustNut,"HARDWARE M4 hex nut for preload adjuster",color(0.65,0.67,0.7));
// Start with ~10N preload for low-force fit testing only. No spring rate is certified here.
// Confirm spring free length/rate/solid height; at maxlift1.5 it compresses about0.75mm further.
// Keep preload-adjustment travel modest (+/-2mm nominal); verify collar clearance and never bottom spring.
