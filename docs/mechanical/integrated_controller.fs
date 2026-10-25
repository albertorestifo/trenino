FeatureScript 3044;
import(path : "onshape/std/common.fs", version : "3044.0");
frame::import(path : "b8296e54dd613316c44885e0/83275c5dacc352f64f1e7296/92fd23eacc98e5842d51e77c", version : "afb002e101c03a20fd6824ed");

gears::import(path : "b8296e54dd613316c44885e0/83275c5dacc352f64f1e7296/5fc9fea51376968b414b4993", version : "08cdde71fa0b29e5b36a1299");

rails::import(path : "b8296e54dd613316c44885e0/83275c5dacc352f64f1e7296/a913723a95349ec8120d5f23", version : "ad22b377db81e57f8eb5235d");

// Dimensions in mm. Frame source is an immutable pre-detent version.
// This is an engineering prototype; spring rate and printed fits require bench testing.
function v(x, y, z) { return vector(x, y, z) * millimeter; }
function rot2(p, a) { return vector(cos(a)*p[0]-sin(a)*p[1], sin(a)*p[0]+cos(a)*p[1]); }
function camPoint(t, lift, pitch)
{
    const beta = -0.5 * lift * (1-cos(360*degree*t/pitch)) / 36 * radian;
    const bp = -lift * PI / ((pitch/radian)*36) * sin(360*degree*t/pitch);
    const c = vector(-36+36*cos(beta), -48+36*sin(beta));
    const cp = vector(-36*bp*sin(beta), 36*bp*cos(beta));
    const q = rot2(c, -t);
    const qp = rot2(cp-vector(-c[1],c[0]), -t);
    var n = normalize(vector(qp[1],-qp[0]));
    if (dot(n,q)<0) n=-n;
    return (q-5*n)*millimeter;
}
function makeBlock(context is Context, id is Id, a, b)
{
    fCuboid(context,id,{"corner1":a,"corner2":b});
    return qCreatedBy(id,EntityType.BODY);
}
function cyl(context is Context, id is Id, a, b, r)
{
    fCylinder(context,id,{"topCenter":b,"bottomCenter":a,"radius":r*millimeter});
    return qCreatedBy(id,EntityType.BODY);
}
function merge(context is Context, id is Id, qs is array)
{
    opBoolean(context,id,{"tools":qUnion(qs),"operationType":BooleanOperationType.UNION});
    return qUnion(qs);
}
function cut(context is Context, id is Id, target is Query, tool is Query)
{
    opBoolean(context,id,{"targets":target,"tools":tool,"operationType":BooleanOperationType.SUBTRACTION});
}
function label(context is Context, body is Query, name is string, c)
{
    setProperty(context,{"entities":body,"propertyType":PropertyType.NAME,"value":name});
    setProperty(context,{"entities":body,"propertyType":PropertyType.APPEARANCE,"value":c});
}


function hexPrism(context is Context,id is Id,x,y,z,af,h)
{
 var sk=newSketchOnPlane(context,id+"sk",{"sketchPlane":plane(v(x,y,z),vector(0,0,1))});
 var pts=[];for(var k=0;k<6;k+=1)pts=append(pts,vector(cos(k*60*degree),sin(k*60*degree))*af/sqrt(3)*millimeter);
 for(var k=0;k<6;k+=1)skLineSegment(sk,"e"~k,{"start":pts[k],"end":pts[(k+1)%6]});
 skSolve(sk);opExtrude(context,id+"ext",{"entities":qSketchRegion(id+"sk"),"direction":vector(0,0,1),"endBound":BoundingType.BLIND,"endDepth":h*millimeter});
 opDeleteBodies(context,id+"clean",{"entities":qCreatedBy(id+"sk",EntityType.BODY)});
 return qCreatedBy(id+"ext",EntityType.BODY);
}
function bolt3(context is Context,id is Id,x,y,seat,tip,headDir,washer)
{
 var bolt=merge(context,id+"merge",[cyl(context,id+"shank",v(x,y,seat),v(x,y,tip),1.5),cyl(context,id+"head",v(x,y,seat),v(x,y,seat+headDir*1.65),2.85)]);
 label(context,bolt,"HARDWARE M3 x "~abs(tip-seat)~" button-head - simplified",color(0.65,0.67,0.7));
 if(washer) {
 var w=cyl(context,id+"washer",v(x,y,seat),v(x,y,seat-headDir*0.5),3.5);
 cut(context,id+"washerHole",w,cyl(context,id+"washerTool",v(x,y,seat-headDir),v(x,y,seat+headDir),1.7));
 label(context,w,"HARDWARE M3 washer 0.5 mm",color(0.65,0.67,0.7));
 }
 return bolt;
}
function printPlace(context is Context,id is Id,body is Query, turn, x, y)
{
 opTransform(context,id+"turn",{"bodies":body,"transform":rotationAround(line(v(0,0,0),vector(1,0,0)),turn)});
 const bounds=evBox3d(context,{"topology":body,"tight":true});
 opTransform(context,id+"place",{"bodies":body,"transform":transform(v(x,y,0)-bounds.minCorner)});
}

function dShape(context is Context,id is Id,z0,z1,r,flatY)
{
 var b=cyl(context,id+"round",v(0,0,z0),v(0,0,z1),r);
 cut(context,id+"flat",b,makeBlock(context,id+"flatTool",v(-r-1,flatY,z0-1),v(r+1,r+1,z1+1)));
 return b;
}

function spacer(context is Context,id is Id,x,y,z0,z1,r)
{
 var b=cyl(context,id+"outer",v(x,y,z0),v(x,y,z1),r);
 cut(context,id+"bore",b,cyl(context,id+"tool",v(x,y,z0-1),v(x,y,z1+1),1.7));
 return b;
}
export enum PrintGroup { annotation {"Name":"Moving parts"} MOVING, annotation {"Name":"Flat support structure"} SUPPORT, annotation {"Name":"Frame and gears"} FRAME }
export enum DetentLayout { annotation {"Name":"3 notches"} THREE, annotation {"Name":"5 notches"} FIVE, annotation {"Name":"7 notches"} SEVEN }
annotation { "Feature Type Name" : "Integrated Printed Controller" }
export const integratedController = defineFeature(function(context is Context, id is Id, definition is map)
precondition
{
    annotation { "Name" : "FDM print layout (PLA / PETG, 0.4 mm nozzle)" }
    definition.printLayout is boolean;
    annotation { "Name" : "Print group" }
    definition.printGroup is PrintGroup;
    annotation { "Name" : "Show unchanged support plates" }
    definition.showFrame is boolean;
    annotation { "Name" : "Lever angle (motion preview)" }
    isAngle(definition.angle, { (degree) : [-65,0,65] } as AngleBoundSpec);
    annotation { "Name" : "Interchangeable profile" }
    definition.layout is DetentLayout;
    annotation { "Name" : "Follower lift" }
    isLength(definition.lift, { (millimeter) : [0.5,1,1.5] } as LengthBoundSpec);
}
{
    const lift = definition.lift/millimeter;
    const count=definition.layout==DetentLayout.THREE ? 3 : (definition.layout==DetentLayout.FIVE ? 5 : 7);
    const pitch=130*degree/count;
    const beta=-0.5*lift*(1-cos(360*degree*definition.angle/pitch))/36*radian;
    const zCam=32;
    if (true)
    {
        var inst=newInstantiator(id+"reference");
        addInstance(inst,frame::build,{});
        instantiate(context,inst);
    }

    var ri=newInstantiator(id+"railReference"); addInstance(ri,rails::build,{}); instantiate(context,ri);
    var railBodies=qBodyType(qCreatedBy(id+"railReference",EntityType.BODY),BodyType.SOLID);
    opTransform(context,id+"railPlacement",{"bodies":railBodies,"transform":transform(matrix([[0,1,0],[0,0,1],[1,0,0]]),v(0,-30,-304.75))});
    label(context,railBodies,"REFERENCE 2020 extrusion - existing frame",color(0.2,0.22,0.24));

    opDeleteBodies(context,id+"referenceSketchCleanup",{"entities":qSubtraction(qUnion([qCreatedBy(id+"reference",EntityType.BODY),qCreatedBy(id+"railReference",EntityType.BODY)]),qBodyType(qEverything(EntityType.BODY),BodyType.SOLID))});
    // Roller-compensated cam, extended 5 degrees past either hard travel stop.
    var points=[];
    for (var i=0;i<=560;i+=1)
        points=append(points,camPoint((-70+i*0.25)*degree,lift,pitch));
    const p0=points[0];
    const pn=points[size(points)-1];
    const inner0=normalize(p0)*20.35*millimeter;
    const innerN=normalize(pn)*20.35*millimeter;
    var s=newSketchOnPlane(context,id+"profile",{"sketchPlane":plane(v(0,0,zCam),vector(0,0,1))});
    skFitSpline(s,"track",{"points":points});
    skLineSegment(s,"end1",{"start":pn,"end":innerN});
    skArc(s,"inner",{"start":innerN,"mid":vector(0,-20.35)*millimeter,"end":inner0});
    skLineSegment(s,"end0",{"start":inner0,"end":p0});
    skSolve(s);
    opExtrude(context,id+"cam",{"entities":qSketchRegion(id+"profile"),"direction":vector(0,0,1),"endBound":BoundingType.BLIND,"endDepth":8*millimeter});
    var cam=qCreatedBy(id+"cam",EntityType.BODY);
    opDeleteBodies(context,id+"cleanSketch",{"entities":qCreatedBy(id+"profile",EntityType.BODY)});

    // Hub remains on shaft when the outer sector is exchanged.
    var carrier=cyl(context,id+"carrier",v(0,0,27),v(0,0,32),28);
    var hub=cyl(context,id+"hub",v(0,0,27),v(0,0,40.5),10);
    var pilot=cyl(context,id+"pilot",v(0,0,32),v(0,0,33.5),20);
    var lug=makeBlock(context,id+"lug",v(-4,22,27),v(4,34,48));
    var lugTip=cyl(context,id+"lugTip",v(0,34,42),v(0,34,48),4);
    carrier=merge(context,id+"hubUnion",[carrier,hub,pilot,lug,lugTip]);
    cut(context,id+"shaftBore",carrier,dShape(context,id+"hubD",26,42,6.2,5.2));
    var index=0;
    for (var a in [-145,-90,-35])
    {
        const x=25.5*cos(a*degree); const y=25.5*sin(a*degree);
        carrier=merge(context,id+("boltBossUnion"~index),[carrier,cyl(context,id+("boltBoss"~index),v(x,y,27),v(x,y,35.5),4.5)]);
        cut(context,id+("camBolt"~index),cam,cyl(context,id+("camBoltTool"~index),v(x,y,31),v(x,y,41),1.7));
        cut(context,id+("camHead"~index),cam,cyl(context,id+("camHeadTool"~index),v(x,y,38),v(x,y,41),3.1));
        // CNC Kitchen standard M3 x 5.7; 1 mm melt space and 1.8 mm bottom.
        cut(context,id+("carrierInsert"~index),carrier,cyl(context,id+("carrierInsertTool"~index),v(x,y,28.8),v(x,y,35.6),2));
        cut(context,id+("bossRelief"~index),cam,cyl(context,id+("bossReliefTool"~index),v(x,y,31),v(x,y,35.8),4.8));
        // Open lower relief to the inner edge, avoiding an unprintable thin crescent.
        var relief=makeBlock(context,id+("reliefSlotTool"~index),v(15,-4.8,31),v(25.5,4.8,35.8));
        opTransform(context,id+("reliefSlotTurn"~index),{"bodies":relief,"transform":rotationAround(line(v(0,0,0),vector(0,0,1)),a*degree)});
        cut(context,id+("reliefSlot"~index),cam,relief);
        index+=1;
    }
    // Separate positive index pin; asymmetric relative to the fixing screws.
    const ix=23*cos(-115*degree); const iy=23*sin(-115*degree);
    cut(context,id+"indexCam",cam,cyl(context,id+"indexCamTool",v(ix,iy,31),v(ix,iy,41),1.7));
    cut(context,id+"indexSocket",carrier,cyl(context,id+"indexSocketTool",v(ix,iy,29),v(ix,iy,33),1.55));
    var indexPin=cyl(context,id+"indexPin",v(ix,iy,29),v(ix,iy,35),1.5);
    label(context,indexPin,"HARDWARE — 3 x 6 mm steel index dowel",color(0.6,0.62,0.65));
    label(context,cam,"M06 Replaceable cam sector - 8 mm",color(0.95,0.57,0.12));
    label(context,carrier,"M07 Printed shaft carrier and stop lug",color(0.2,0.42,0.7));

    // Flat, double-supported plates; no long overhead cantilever.
    var cheeks=[];
    for(var z in [20,46])
    {
      var plate=merge(context,id+("cheekUnion"~z),[
        makeBlock(context,id+("rearRail"~z),v(-74,-65,z),v(z==20 ? 74 : -60,-53,z+6)),
        makeBlock(context,id+("pivotWeb"~z),v(-72,-60,z),v(-30,-42,z+6)),
        cyl(context,id+("pivotEnd"~z),v(-36,-48,z),v(-36,-48,z+6),6),
        makeBlock(context,id+("springWeb"~z),v(-72,-54,z),v(-60,-22,z+6))]);
      cut(context,id+("pivotHole"~z),plate,cyl(context,id+("pivotHoleTool"~z),v(-36,-48,z-1),v(-36,-48,z+7),2.6));
      for(var x in (z==20 ? [-85,85] : [-85])) {
        plate=merge(context,id+("railFootUnion"~z~"x"~x),[plate,makeBlock(context,id+("railFoot"~z~"x"~x),v(x-12,-65,z==20 ? 20 : 40),v(x+12,-51,z==20 ? 32 : 52))]);
        cut(context,id+("railBolt"~z~"x"~x),plate,cyl(context,id+("railBoltTool"~z~"x"~x),v(x,-66,z==20 ? 26 : 46),v(x,-50,z==20 ? 26 : 46),2.7));
      }
      for(var y in [-26,-40]) cut(context,id+("springBolt"~z~"y"~y),plate,cyl(context,id+("springBoltTool"~z~"y"~y),v(-65,y,z-1),v(-65,y,z+7),1.7));
      if(z==20)cut(context,id+"pivotHeadPocket",plate,cyl(context,id+"pivotHeadPocketTool",v(-36,-48,19),v(-36,-48,22.5),5));
      else cut(context,id+"pivotNutPocket",plate,hexPrism(context,id+"pivotNutPocketTool",-36,-48,48,8.4,5));
      if(z==46) for(var y in [-26,-40]) cut(context,id+("springHeadPocket"~y),plate,cyl(context,id+("springHeadPocketTool"~y),v(-65,y,50),v(-65,y,53),3.75));
      label(context,plate,z==20 ? "S01 Lower follower plate - flat" : "S02 Upper follower plate - flat",color(0.35,0.42,0.46));
      cheeks=append(cheeks,plate);
    }
    var bracket=merge(context,id+"springBlockUnion",[
      makeBlock(context,id+"springColumn",v(-71,-47,26),v(-59,-21,46)),
      makeBlock(context,id+"springNose",v(-65,-28,29),v(-47,-22,43))]);
    for(var y in [-26,-40])
    {
      cut(context,id+("springInsertBottom"~y),bracket,cyl(context,id+("springInsertBottomTool"~y),v(-65,y,25.9),v(-65,y,32.7),2));
      cut(context,id+("springInsertTop"~y),bracket,cyl(context,id+("springInsertTopTool"~y),v(-65,y,39.3),v(-65,y,46.1),2));
    }
    cut(context,id+"adjustBore",bracket,cyl(context,id+"adjustTool",v(-54,-30,36),v(-54,-20,36),2.2));
    label(context,bracket,"S03 Spring block - four M3 inserts",color(0.35,0.42,0.46));
    // Stops live above the cam; the moving lug stays inside a large-radius arch.
    var stopPlate=cyl(context,id+"stopDisc",v(0,0,42),v(0,0,48),50);
    cut(context,id+"stopInner",stopPlate,cyl(context,id+"stopInnerTool",v(0,0,41),v(0,0,49),41));
    cut(context,id+"stopLower",stopPlate,makeBlock(context,id+"stopLowerTool",v(-55,-55,41),v(55,0,49)));
    stopPlate=merge(context,id+"stopEarsUnion",[stopPlate,makeBlock(context,id+"stopLeftEar",v(-74,25,42),v(-37,39,48)),makeBlock(context,id+"stopRightEar",v(37,25,42),v(74,39,48))]);
    cut(context,id+"stopOpening",stopPlate,cyl(context,id+"stopOpeningTool",v(0,0,41),v(0,0,49),41));
    const stopAngle=65*degree+acos((34*34+40*40-7.5*7.5)/(2*34*40));
    const sx=40*sin(stopAngle);const sy=40*cos(stopAngle);
    for(var side in [-1,1]) {
      stopPlate=merge(context,id+("stopPostUnion"~side),[stopPlate,cyl(context,id+("stopPost"~side),v(side*sx,sy,42),v(side*sx,sy,48),3.5)]);
      cut(context,id+("stopSteelBore"~side),stopPlate,cyl(context,id+("stopSteelBoreTool"~side),v(side*sx,sy,41),v(side*sx,sy,49),1.7));
      var sb=bolt3(context,id+("stopSteelBolt"~side),side*sx,sy,42,52,-1,false);
      label(context,sb,"HARDWARE M3 x10 steel-core end stop",color(0.65,0.67,0.7));
      var nut=hexPrism(context,id+("stopNut"~side),side*sx,sy,48.5,5.5,2.4);
      cut(context,id+("stopNutBore"~side),nut,cyl(context,id+("stopNutBoreTool"~side),v(side*sx,sy,48),v(side*sx,sy,52),1.5));
      label(context,nut,"HARDWARE M3 stop nut",color(0.65,0.67,0.7));
      var sw=spacer(context,id+("stopWasher"~side),side*sx,sy,48,48.5,3.5);
      label(context,sw,"HARDWARE M3 stop washer 0.5 mm",color(0.65,0.67,0.7));
    }
    for(var x in [-85,85]) {
      stopPlate=merge(context,id+("stopFootUnion"~x),[stopPlate,makeBlock(context,id+("stopFoot"~x),v(x-12,25,42),v(x+12,39,54))]);
      cut(context,id+("stopMount"~x),stopPlate,cyl(context,id+("stopMountTool"~x),v(x,24,48),v(x,40,48),2.7));
    }
    label(context,stopPlate,"S04 Steel-core stop arch - bolts to upper 2020 rails",color(0.35,0.42,0.46));
    var supports=[];
    // FDM review replacement for fork/roller/pivot/axle block.
    // Flat print-side y=-55; 14 mm bars leave 3.35 mm beside the Ø7.3 pivot bore.
    // Pivot bolt clamps a metal tube, not the printed rotating fork cheeks.
    var arms=[];
    for (var bounds in [[27,30],[41,45]])
    {
        const z0=bounds[0]; const z1=bounds[1];
        var fk=newSketchOnPlane(context,id+("forkBarSketch"~z0),{"sketchPlane":plane(v(0,0,z0),vector(0,0,1))});
        var fp=[vector(-54,-55),vector(0,-55),vector(0,-44),vector(-12,-44),vector(-24,-41),vector(-54,-41)];
        for(var k=0;k<size(fp);k+=1)skLineSegment(fk,"e"~k,{"start":fp[k]*millimeter,"end":fp[(k+1)%size(fp)]*millimeter});
        skSolve(fk);opExtrude(context,id+("armBar"~z0),{"entities":qSketchRegion(id+("forkBarSketch"~z0)),"direction":vector(0,0,1),"endBound":BoundingType.BLIND,"endDepth":(z1-z0)*millimeter});
        arms=append(arms,qCreatedBy(id+("armBar"~z0),EntityType.BODY));
        opDeleteBodies(context,id+("forkBarClean"~z0),{"entities":qCreatedBy(id+("forkBarSketch"~z0),EntityType.BODY)});
        arms=append(arms,cyl(context,id+("armEnd"~z0),v(0,-48,z0),v(0,-48,z1),5));
        arms=append(arms,cyl(context,id+("armPivotBoss"~z0),v(-36,-48,z0),v(-36,-48,z1),7));
        arms=append(arms,cyl(context,id+("armTail"~z0),v(-54,-48,z0),v(-54,-48,z1),4));
    }
    arms=append(arms,makeBlock(context,id+"tailBridge",v(-58,-52,29),v(-50,-44,43)));
    var arm=merge(context,id+"armUnion",arms);
    cut(context,id+"armPivot",arm,cyl(context,id+"armPivotTool",v(-36,-48,26),v(-36,-48,46),3.65));
    cut(context,id+"armAxle",arm,cyl(context,id+"armAxleTool",v(0,-48,26),v(0,-48,46),1.7));
    cut(context,id+"rollerHeadPocket",arm,cyl(context,id+"rollerHeadPocketTool",v(0,-48,43.2),v(0,-48,46),3.1));
    label(context,arm,"M08 Forked roller arm - flat side, sleeved pivot",color(0.18,0.65,0.62));
    var roller=cyl(context,id+"roller",v(0,-48,31),v(0,-48,40.5),5);
    cut(context,id+"rollerBore",roller,cyl(context,id+"rollerTool",v(0,-48,30),v(0,-48,42),2.15));
    label(context,roller,"M09 Roller - 10 mm diameter x 9.5 mm",color(0.75,0.77,0.79));
    var axle=bolt3(context,id+"axle",0,-48,43.2,23.2,1,false);
    var pivot=merge(context,id+"pivotUnion",[cyl(context,id+"pivot",v(-36,-48,22.5),v(-36,-48,52.5),2.5),cyl(context,id+"pivotHead",v(-36,-48,19.75),v(-36,-48,22.5),4.75)]);
    var pivotNut=hexPrism(context,id+"pivotNut",-36,-48,48,8,4);
    cut(context,id+"pivotNutBore",pivotNut,cyl(context,id+"pivotNutBoreTool",v(-36,-48,47),v(-36,-48,53),2.5));
    label(context,pivotNut,"HARDWARE M5 nut - captive in upper plate",color(0.65,0.67,0.7));
    label(context,axle,"HARDWARE M3 x 20 roller axle - simplified",color(0.6,0.62,0.65));
    label(context,pivot,"HARDWARE M5 x 30 button-head pivot - simplified",color(0.6,0.62,0.65));
    var pivotTube=cyl(context,id+"pivotTube",v(-36,-48,26),v(-36,-48,46),3.5);
    cut(context,id+"pivotTubeBore",pivotTube,cyl(context,id+"pivotTubeTool",v(-36,-48,25),v(-36,-48,47),2.6));
    label(context,pivotTube,"HARDWARE 7 OD x 5.2 ID x 20 mm pivot sleeve",color(0.7,0.6,0.3));
    var rollerTube=cyl(context,id+"rollerTube",v(0,-48,30),v(0,-48,41),2);
    cut(context,id+"rollerTubeBore",rollerTube,cyl(context,id+"rollerTubeTool",v(0,-48,29),v(0,-48,42),1.6));
    label(context,rollerTube,"HARDWARE 4 OD x 3.2 ID x 11 mm spacer tube",color(0.7,0.6,0.3));
    var rollerNut=hexPrism(context,id+"rollerNut",0,-48,24.1,5.5,2.4);
    cut(context,id+"rollerNutBore",rollerNut,cyl(context,id+"rollerNutTool",v(0,-48,23),v(0,-48,28),1.5));
    label(context,rollerNut,"HARDWARE M3 roller axle nut",color(0.65,0.67,0.7));
    var rollerWasher=spacer(context,id+"rollerWasher",0,-48,26.5,27,3.5);
    label(context,rollerWasher,"HARDWARE M3 roller nut washer",color(0.65,0.67,0.7));
    var rollerHardware=qUnion([axle,rollerTube,rollerNut,rollerWasher]);
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
opTransform(context,id+"adjustNutPlace",{"bodies":adjustNut,"transform":transform(v(-54,-24.7,36))*rotationAround(line(v(0,0,0),vector(1,0,0)),90*degree)});
label(context,adjustNut,"HARDWARE M4 hex nut for preload adjuster",color(0.65,0.67,0.7));
// Captive travel limiter: head can advance only 1 mm from nominal preload.
var preloadLimiter=cyl(context,id+"preloadLimiter",v(-54,-22,36),v(-54,-9,36),4);
cut(context,id+"preloadLimiterBore",preloadLimiter,cyl(context,id+"preloadLimiterTool",v(-54,-23,36),v(-54,-8,36),2.25));
label(context,preloadLimiter,"PRINT M4 preload limit collar - 13 mm",color(0.35,0.42,0.46));
// Spring starting specification: OD8, ID>=5, free18, rate10-12N/mm, solid<=11.5mm.
// Nominal14mm installed gives40-48N; choose softer spring for initial fit testing. No spring rate is certified here.
// Confirm spring free length/rate/solid height; at maxlift1.5 it compresses about0.75mm further.
// Advance limited to +1 mm. Cup seats on bracket at nominal: backoff does not reduce preload.

    // Spring-side nut loading leaves a 2.7 mm front wall to react the spring load. Install nut before cup.
    cut(context,id+"adjustFinalBore",bracket,cyl(context,id+"adjustFinalBoreTool",v(-54,-29,36),v(-54,-20,36),2.2));
    var np=hexPrism(context,id+"nutPocketTool",0,0,0,7.4,3.4);
    opTransform(context,id+"nutPocketPlace",{"bodies":np,"transform":transform(v(-54,-24.7,36))*rotationAround(line(v(0,0,0),vector(1,0,0)),90*degree)});
    cut(context,id+"nutPocket",bracket,np);
    // Original exact gears, mirrored into the existing potentiometer center.
    var beforeGears=evaluateQuery(context,qBodyType(qEverything(EntityType.BODY),BodyType.SOLID)); var gi=newInstantiator(id+"gearReference"); addInstance(gi,gears::build,{}); instantiate(context,gi);
    var gearBodies=evaluateQuery(context,qSubtraction(qBodyType(qEverything(EntityType.BODY),BodyType.SOLID),qUnion(beforeGears))); var mainGear=qNothing(); var potGear=qNothing(); for(var gb in gearBodies) { var bb=evBox3d(context,{"topology":gb,"tight":true}); if(bb.maxCorner[0]-bb.minCorner[0]>40*millimeter) mainGear=gb; else potGear=gb; }
    opTransform(context,id+"gearPlacement",{"bodies":qUnion([mainGear,potGear]),"transform":transform(v(0,0,23.5))*rotationAround(line(v(0,0,0),vector(0,1,0)),180*degree)});
    cut(context,id+"mainGearD",mainGear,dShape(context,id+"mainGearDTool",10,25,6.2,5.2));
    label(context,mainGear,"F03 Original 48T gear - enlarged printed shaft bore",color(0.5,0.58,0.7));
    label(context,potGear,"F04 Original 24T potentiometer gear",color(0.5,0.58,0.7));
    var shaft=dShape(context,id+"printedShaft",11,53,6,5);
    shaft=merge(context,id+"shaftJournals",[shaft,cyl(context,id+"journalA",v(0,0,-0.3),v(0,0,11.1),4.6),cyl(context,id+"journalB",v(0,0,52.9),v(0,0,64.8),4.6)]);
    cut(context,id+"shaftInsertA",shaft,cyl(context,id+"shaftInsertATool",v(0,0,-0.4),v(0,0,6.4),2));
    cut(context,id+"shaftInsertB",shaft,cyl(context,id+"shaftInsertBTool",v(0,0,58.1),v(0,0,64.9),2));
    label(context,shaft,"M01 Printed shaft - 12 mm D, 9.2 mm journals",color(0.3,0.55,0.8));
    var bushes=[]; var caps=[];
    for(var z in [4,54])
    {
      var bush=cyl(context,id+("bush"~z),v(0,0,z),v(0,0,z+6.5),7.95);
      cut(context,id+("bushBore"~z),bush,cyl(context,id+("bushBoreTool"~z),v(0,0,z-1),v(0,0,z+7.5),4.8));
      label(context,bush,"M02 Printed bushing "~z~" - replaces 625 bearing",color(0.8,0.8,0.78));bushes=append(bushes,bush);
    }
    for(var z in [-1.9,64.8])
    {
      var cap=spacer(context,id+("cap"~z),0,0,z,z+1.6,7);
      label(context,cap,"M03 Shaft retaining washer "~z,color(0.5,0.6,0.7));caps=append(caps,cap);
    }
    mainGear=merge(context,id+"gearHandleUnion",[mainGear,makeBlock(context,id+"gearHandleStem",v(-6,10,11.5),v(6,129,23.5))]);
    var hs=newSketchOnPlane(context,id+"handleRootSketch",{"sketchPlane":plane(v(0,0,11.5),vector(0,0,1))});
    var hp=[vector(-14,14),vector(14,14),vector(9,40),vector(6,70),vector(-6,70),vector(-9,40)];
    for(var k=0;k<size(hp);k+=1)skLineSegment(hs,"h"~k,{"start":hp[k]*millimeter,"end":hp[(k+1)%size(hp)]*millimeter});
    skSolve(hs);opExtrude(context,id+"handleRootExtrude",{"entities":qSketchRegion(id+"handleRootSketch"),"direction":vector(0,0,1),"endBound":BoundingType.BLIND,"endDepth":12*millimeter});
    mainGear=merge(context,id+"handleRootUnion",[mainGear,qCreatedBy(id+"handleRootExtrude",EntityType.BODY)]);
    opDeleteBodies(context,id+"handleRootClean",{"entities":qCreatedBy(id+"handleRootSketch",EntityType.BODY)});
    label(context,mainGear,"M04 One-piece lever and original 48T main gear",color(0.22,0.58,0.85));
    // European railway-style tapered palm grip: ~40 mm maximum diameter,
    // 60 mm grasp length, 160 mm pivot-to-crown. Two printable halves retain a keyed stem.
    var gs=newSketchOnPlane(context,id+"gripSketch",{"sketchPlane":plane(v(0,0,17.5),vector(0,0,1))});
    var gp=[vector(12,100),vector(14,105),vector(18,120),vector(20,140),vector(19,150),vector(15,157),vector(0,160)];
    var gpm=[];for(var p in gp)gpm=append(gpm,p*millimeter);
    skFitSpline(gs,"palm",{"points":gpm,"endDerivative":vector(-1,0)*millimeter});
    skLineSegment(gs,"bottom",{"start":vector(0,100)*millimeter,"end":gpm[0]});
    skLineSegment(gs,"axis",{"start":gpm[size(gpm)-1],"end":vector(0,100)*millimeter});
    skSolve(gs);
    opRevolve(context,id+"gripRevolve",{"entities":qSketchRegion(id+"gripSketch"),"axis":line(v(0,0,17.5),vector(0,1,0)),"angleForward":360*degree});
    opDeleteBodies(context,id+"gripSketchClean",{"entities":qCreatedBy(id+"gripSketch",EntityType.BODY)});
    var gripLower=qCreatedBy(id+"gripRevolve",EntityType.BODY);
    opPattern(context,id+"gripCopy",{"entities":gripLower,"transforms":[identityTransform()],"instanceNames":["upper"]});
    var gripUpper=qCreatedBy(id+"gripCopy",EntityType.BODY);
    cut(context,id+"gripLowerSplit",gripLower,makeBlock(context,id+"gripLowerSplitTool",v(-30,90,17.5),v(30,170,50)));
    cut(context,id+"gripUpperSplit",gripUpper,makeBlock(context,id+"gripUpperSplitTool",v(-30,90,-15),v(30,170,17.5)));
    for(var gi=0;gi<2;gi+=1) {
      var gb=gi==0 ? gripLower : gripUpper;
      cut(context,id+("gripSocket"~gi),gb,makeBlock(context,id+("gripSocketTool"~gi),v(-6.2,99,11.3),v(6.2,130,23.7)));
    }
    for(var gy in [115,125]) {
      cut(context,id+("gripInsert"~gy),gripLower,cyl(context,id+("gripInsertTool"~gy),v(0,gy,4.6),v(0,gy,11.4),2));
      cut(context,id+("gripUpperHole"~gy),gripUpper,cyl(context,id+("gripUpperHoleTool"~gy),v(0,gy,17),v(0,gy,45),1.7));
      cut(context,id+("gripHead"~gy),gripUpper,cyl(context,id+("gripHeadTool"~gy),v(0,gy,30),v(0,gy,45),3.1));
      cut(context,id+("gripStemHole"~gy),mainGear,cyl(context,id+("gripStemHoleTool"~gy),v(0,gy,10),v(0,gy,25),1.7));
    }
    label(context,gripLower,"M10 Railway palm grip - lower insert half",color(0.18,0.19,0.21));
    label(context,gripUpper,"M11 Railway palm grip - upper screw half",color(0.18,0.19,0.21));
    var handle=qUnion([gripLower,gripUpper]);

    // Three bolts transmit detent torque directly from gear to carrier.
    for(var a in [90,210,330]) {
      const x=15*cos(a*degree);const y=15*sin(a*degree);
      mainGear=merge(context,id+("drivePostUnion"~a),[mainGear,cyl(context,id+("drivePost"~a),v(x,y,23),v(x,y,27),4.5)]);
      cut(context,id+("driveInsert"~a),mainGear,cyl(context,id+("driveInsertTool"~a),v(x,y,20.3),v(x,y,27.1),2));
      cut(context,id+("carrierBolt"~a),carrier,cyl(context,id+("carrierBoltTool"~a),v(x,y,26),v(x,y,35),1.7));
      cut(context,id+("carrierHead"~a),carrier,cyl(context,id+("carrierHeadTool"~a),v(x,y,32),v(x,y,35),3.1));
    }
    var driveSpacers=[];
    for(var bounds in [[40.5,53.5]])
    {
      var ds=cyl(context,id+("driveSpacer"~bounds[0]),v(0,0,bounds[0]),v(0,0,bounds[1]),8);
      cut(context,id+("driveSpacerBore"~bounds[0]),ds,cyl(context,id+("driveSpacerTool"~bounds[0]),v(0,0,bounds[0]-1),v(0,0,bounds[1]+1),6.3));
      label(context,ds,"M05 Drive spacer "~(bounds[1]-bounds[0])~" mm",color(0.5,0.6,0.7));driveSpacers=append(driveSpacers,ds);
    }
    // Potentiometer shaft is hardware; the actual original device stays in Full device.
    const pc=v(-31.17691453624,-18,0);
    var potShaft=cyl(context,id+"potShaft",pc+v(0,0,-3),pc+v(0,0,23),3);
    label(context,potShaft,"REFERENCE only - original 6 mm potentiometer shaft",color(0.65,0.65,0.65));
    var driveBolts=[];
    for(var a in [-145,-90,-35]) driveBolts=append(driveBolts,bolt3(context,id+("camScrew"~a),25.5*cos(a*degree),25.5*sin(a*degree),38,30,1,false));
    for(var gy in [115,125]) driveBolts=append(driveBolts,bolt3(context,id+("gripScrew"~gy),0,gy,30,5,1,false));
    driveBolts=append(driveBolts,bolt3(context,id+"shaftScrewA",0,0,-1.9,6.1,-1,false));
    driveBolts=append(driveBolts,bolt3(context,id+"shaftScrewB",0,0,66.4,58.4,1,false));
    for(var a in [90,210,330]) driveBolts=append(driveBolts,bolt3(context,id+("carrierDriveScrew"~a),15*cos(a*degree),15*sin(a*degree),32,22,1,false));
    // M5 rail fasteners use the existing T-slots; heads face the assembly opening.
    for(var mount in [[-85,-51,26],[85,-51,26],[-85,-51,46],[-85,39,48],[85,39,48]]) {
      const x=mount[0];const y=mount[1];const z=mount[2];
      var bolt=merge(context,id+("railScrewUnion"~x~y~z),[cyl(context,id+("railScrew"~x~y~z),v(x,y+1,z),v(x,y-19,z),2.5),cyl(context,id+("railHead"~x~y~z),v(x,y+1,z),v(x,y+3.75,z),4.75)]);
      label(context,bolt,"HARDWARE M5 x 20 rail screw - use matching 2020 T-nut",color(0.65,0.67,0.7));
      var rw=cyl(context,id+("railWasher"~x~y~z),v(x,y,z),v(x,y+1,z),5);
      cut(context,id+("railWasherBore"~x~y~z),rw,cyl(context,id+("railWasherTool"~x~y~z),v(x,y-1,z),v(x,y+2,z),2.7));
      label(context,rw,"HARDWARE M5 rail washer 1 mm",color(0.65,0.67,0.7));
    }
    for(var y in [-26,-40]) {
      bolt3(context,id+("springLowerScrew"~y),-65,y,19.5,31.5,-1,true);
      bolt3(context,id+("springUpperScrew"~y),-65,y,50.5,40.5,1,true);
    }
    var moving=qUnion([cam,carrier,indexPin,shaft,handle,mainGear,qUnion(caps),qUnion(driveSpacers),qUnion(driveBolts)]);
    if(!definition.printLayout)
    {
      opTransform(context,id+"rotateDrive",{"bodies":moving,"transform":rotationAround(line(v(0,0,0),vector(0,0,1)),definition.angle)});
      opTransform(context,id+"rotatePot",{"bodies":potGear,"transform":rotationAround(line(pc,vector(0,0,1)),-2*definition.angle)});
      opTransform(context,id+"rotateArm",{"bodies":qUnion([arm,roller,rollerHardware]),"transform":rotationAround(line(v(-36,-48,0),vector(0,0,1)),beta)});
      if(!definition.showFrame) opDeleteBodies(context,id+"hideFrames",{"entities":qUnion([qCreatedBy(id+"reference",EntityType.BODY),railBodies])});
    }
    else
    {
      var keep=[];
      if(definition.printGroup==PrintGroup.MOVING)
      {
        keep=[cam,carrier,shaft,mainGear,handle,arm,roller,qUnion(bushes),qUnion(caps),qUnion(driveSpacers)];
        printPlace(context,id+"pHandle",mainGear,0*degree,10,10);
        printPlace(context,id+"pGripUpper",gripUpper,0*degree,200,95);
        printPlace(context,id+"pGripLower",gripLower,180*degree,200,165);
        printPlace(context,id+"pCam",cam,0*degree,70,10);
        printPlace(context,id+"pCarrier",carrier,0*degree,70,60);
        printPlace(context,id+"pShaft",shaft,-90*degree,165,10);
        printPlace(context,id+"pFork",arm,90*degree,70,145);
        printPlace(context,id+"pRoller",roller,0*degree,145,145);
        printPlace(context,id+"pDriveSpacer",driveSpacers[0],0*degree,170,150);
        for(var i=0;i<2;i+=1) {
          printPlace(context,id+("pBush"~i),bushes[i],0*degree,145+i*25,100);
          printPlace(context,id+("pCap"~i),caps[i],0*degree,145+i*25,125);

        }
      }
      else if(definition.printGroup==PrintGroup.SUPPORT)
      {
        keep=[qUnion(cheeks),bracket,stopPlate,springCup,preloadLimiter,qUnion(supports)];
        printPlace(context,id+"pCheek0",cheeks[0],0*degree,10,10);
        printPlace(context,id+"pCheek1",cheeks[1],180*degree,10,75);
        printPlace(context,id+"pStop",stopPlate,0*degree,10,145);
        printPlace(context,id+"pSpringCup",springCup,-90*degree,210,60); printPlace(context,id+"pPreloadLimiter",preloadLimiter,90*degree,210,95);
        printPlace(context,id+"pSpring",bracket,90*degree,210,10);
        for(var i=0;i<size(supports);i+=1) printPlace(context,id+("pSupport"~i),supports[i],0*degree,190+20*(i%2),45+20*floor(i/2));
      }
      else
      {
        var frames=evaluateQuery(context,qBodyType(qCreatedBy(id+"reference",EntityType.BODY),BodyType.SOLID));
        keep=[qUnion(frames),potGear];
        for(var i=0;i<size(frames);i+=1) printPlace(context,id+("pFrame"~i),frames[i],i==0 ? 0*degree : 180*degree,5,5+110*i);

        printPlace(context,id+"pPotGear",potGear,0*degree,205,65);
      }
      opDeleteBodies(context,id+"printOnly",{"entities":qSubtraction(qAllModifiableSolidBodies(),qUnion(keep))});
    }
    // AUDIT_INSERT
    println("Integrated controller: printed shaft, handle, original gear tooth geometry and plate interfaces.");
    if(!definition.printLayout) opTransform(context,id+"installedView",{"bodies":qAllModifiableSolidBodies(),"transform":transform(matrix([[0,0,1],[1,0,0],[0,1,0]]),v(0,0,0))});
}, {"printLayout":false,"printGroup":PrintGroup.MOVING,"showFrame":true,"angle":0*degree,"layout":DetentLayout.SEVEN,"lift":1*millimeter});
