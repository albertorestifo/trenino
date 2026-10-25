FeatureScript 3044;
import(path : "onshape/std/common.fs", version : "3044.0");
frame::import(path : "b8296e54dd613316c44885e0/83275c5dacc352f64f1e7296/92fd23eacc98e5842d51e77c", version : "afb002e101c03a20fd6824ed");

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


function printPlace(context is Context,id is Id,body is Query, turn, x, y)
{
 opTransform(context,id+"turn",{"bodies":body,"transform":rotationAround(line(v(0,0,0),vector(1,0,0)),turn)});
 const bounds=evBox3d(context,{"topology":body,"tight":true});
 opTransform(context,id+"place",{"bodies":body,"transform":transform(v(x,y,0)-bounds.minCorner)});
}

export enum DetentLayout { annotation {"Name":"3 notches"} THREE, annotation {"Name":"5 notches"} FIVE, annotation {"Name":"7 notches"} SEVEN }
annotation { "Feature Type Name" : "Cam Detent Mechanism" }
export const camDetent = defineFeature(function(context is Context, id is Id, definition is map)
precondition
{
    annotation { "Name" : "FDM print layout (PLA / PETG, 0.4 mm nozzle)" }
    definition.printLayout is boolean;
    annotation { "Name" : "Show unchanged support plates" }
    definition.showFrame is boolean;
    annotation { "Name" : "Lever angle (motion preview)" }
    isAngle(definition.angle, { (degree) : [-70,0,70] } as AngleBoundSpec);
    annotation { "Name" : "Interchangeable profile" }
    definition.layout is DetentLayout;
    annotation { "Name" : "Show sector removed (at neutral)" }
    definition.service is boolean;
    annotation { "Name" : "Follower lift" }
    isLength(definition.lift, { (millimeter) : [0.5,1,1.5] } as LengthBoundSpec);
}
{
    const lift = definition.lift/millimeter;
    const count=definition.layout==DetentLayout.THREE ? 3 : (definition.layout==DetentLayout.FIVE ? 5 : 7);
    const pitch=140*degree/count;
    const beta=-0.5*lift*(1-cos(360*degree*definition.angle/pitch))/36*radian;
    const zCam=32;
    if (definition.showFrame && !definition.printLayout)
    {
        var inst=newInstantiator(id+"reference");
        addInstance(inst,frame::build,{});
        instantiate(context,inst);
    }

    // Roller-compensated cam, extended 5 degrees past either hard travel stop.
    var points=[];
    for (var i=0;i<=600;i+=1)
        points=append(points,camPoint((-75+i*0.25)*degree,lift,pitch));
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
    var hub=cyl(context,id+"hub",v(0,0,27),v(0,0,48),9);
    var pilot=cyl(context,id+"pilot",v(0,0,32),v(0,0,33.5),20);
    var lug=makeBlock(context,id+"lug",v(-3,22,28),v(3,34,32));
    var lugTip=cyl(context,id+"lugTip",v(0,34,28),v(0,34,32),3);
    var insertBoss=cyl(context,id+"radialInsertBoss",v(-11,0,42),v(-6,0,42),4.5);
    carrier=merge(context,id+"hubUnion",[carrier,hub,pilot,lug,lugTip,insertBoss]);
    var bore=cyl(context,id+"shaftTool",v(0,0,23),v(0,0,49),2.75);
    var flat=makeBlock(context,id+"flatTool",v(-4,2.026,22),v(4,5,50));
    cut(context,id+"boreFlat",bore,flat);
    cut(context,id+"shaftBore",carrier,bore);
    cut(context,id+"setScrew",carrier,cyl(context,id+"setTool",v(-12,0,42),v(0,0,42),1.7));
    cut(context,id+"hubInsert",carrier,cyl(context,id+"hubInsertTool",v(-11.1,0,42),v(-4.3,0,42),2));
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
    label(context,cam,"Replaceable cam sector — 8 mm",color(0.95,0.57,0.12));
    label(context,carrier,"Permanent D-shaft hub and stop lug",color(0.2,0.42,0.7));

    // Bracket reuses the two LEFT lower flange holes: x=-85, z=5.25 / 59.25.
    // M5 screw length must be increased by the added 7 mm mounting thickness.
    var blocks=[];
    blocks=append(blocks,makeBlock(context,id+"mount",v(-91,-62,0),v(-79,-55,64.5)));
    blocks=append(blocks,makeBlock(context,id+"bridge",v(-85,-62,12),v(-30,-55,52)));
    blocks=append(blocks,makeBlock(context,id+"pivotLow",v(-42,-62,23),v(-30,-42,26)));
    blocks=append(blocks,makeBlock(context,id+"pivotHigh",v(-42,-62,46),v(-30,-42,49)));
    blocks=append(blocks,makeBlock(context,id+"springUpright",v(-64,-62,23.5),v(-60,-24,44)));
    blocks=append(blocks,makeBlock(context,id+"springTop",v(-61,-28,29),v(-47,-22,43)));
    blocks=append(blocks,makeBlock(context,id+"stopUpright",v(-66,-62,23.5),v(-56,18,26.5)));
    blocks=append(blocks,makeBlock(context,id+"stopBridge",v(-61,6,23.5),v(38,18,26.5)));
    const stopAngle=70*degree+asin(6.5/34);
    const sx=34*sin(stopAngle); const sy=34*cos(stopAngle);
    for (var side in [-1,1])
    {
        blocks=append(blocks,makeBlock(context,id+("stopFoot"~side),v(side*sx-6,sy-4,23.5),v(side*sx+6,15,26.5)));
        blocks=append(blocks,cyl(context,id+("stopPost"~side),v(side*sx,sy,26.5),v(side*sx,sy,32),3.5));
    }
    var bracket=merge(context,id+"bracketUnion",blocks);
    cut(context,id+"mountHoleA",bracket,cyl(context,id+"mountToolA",v(-85,-64,5.25),v(-85,-53,5.25),2.75));
    cut(context,id+"mountHoleB",bracket,cyl(context,id+"mountToolB",v(-85,-64,59.25),v(-85,-53,59.25),2.75));
    cut(context,id+"pivotBore",bracket,cyl(context,id+"pivotTool",v(-36,-48,22),v(-36,-48,50),2.6));
    cut(context,id+"adjustBore",bracket,cyl(context,id+"adjustTool",v(-54,-30,36),v(-54,-20,36),2.2));
    label(context,bracket,"Frame-mounted follower bracket and independent stops",color(0.35,0.42,0.46));

    // Forked arm, double-supported axle; no reuse of the failed prototype.
    var arms=[];
    for (var z in [27,42])
    {
        arms=append(arms,makeBlock(context,id+("armBar"~z),v(-54,-52,z),v(0,-44,z+3)));
        arms=append(arms,cyl(context,id+("armEnd"~z),v(0,-48,z),v(0,-48,z+3),4));
        arms=append(arms,cyl(context,id+("armTail"~z),v(-54,-48,z),v(-54,-48,z+3),4));
    }
    arms=append(arms,makeBlock(context,id+"tailBridge",v(-58,-52,29),v(-50,-44,43)));
    var arm=merge(context,id+"armUnion",arms);
    cut(context,id+"armPivot",arm,cyl(context,id+"armPivotTool",v(-36,-48,26),v(-36,-48,46),2.65));
    cut(context,id+"armAxle",arm,cyl(context,id+"armAxleTool",v(0,-48,26),v(0,-48,46),1.7));
    label(context,arm,"Forked roller arm — 36 mm pivot radius",color(0.18,0.65,0.62));
    var roller=cyl(context,id+"roller",v(0,-48,31),v(0,-48,41),5);
    cut(context,id+"rollerBore",roller,cyl(context,id+"rollerTool",v(0,-48,30),v(0,-48,42),1.7));
    label(context,roller,"10 mm OD roller — 10 mm contact width",color(0.75,0.77,0.79));
    var axle=cyl(context,id+"axle",v(0,-48,27),v(0,-48,45),1.5);
    var pivot=cyl(context,id+"pivot",v(-36,-48,23),v(-36,-48,49),2.5);
    label(context,axle,"M3 roller shoulder axle — schematic",color(0.6,0.62,0.65));
    label(context,pivot,"5 mm arm pivot pin — schematic",color(0.6,0.62,0.65));

    // Guided spring pushes on the short tail; required spring force is ~2x roller force.
    const seatY=-48-18*sin(beta)+4*cos(beta);
    var spring=cyl(context,id+"spring",v(-54,seatY,36),v(-54,-30,36),4);
    cut(context,id+"springHollow",spring,cyl(context,id+"springTool",v(-54,seatY-1,36),v(-54,-29,36),2.5));
    label(context,spring,"SPRING ENVELOPE — 8 OD x 14 installed at rest; bench-select rate",color(0.7,0.3,0.65,0.45));
    var adjust=cyl(context,id+"adjust",v(-54,-39,36),v(-54,-15,36),2);
    var thrust=cyl(context,id+"thrust",v(-54,-30,36),v(-54,-28,36),4.5);
    adjust=merge(context,id+"adjustUnion",[adjust,thrust]);
    label(context,adjust,"M4 screw and thrust seat — schematic threads",color(0.6,0.62,0.65));
    // M4 captive hex nut pocket, 7.2 mm across flats, opens outward from the bracket.
    var ns=newSketchOnPlane(context,id+"nutSketch",{"sketchPlane":plane(v(-54,-22,36),vector(0,1,0))});
    var hexPoints=[]; for(var k=0;k<6;k+=1) hexPoints=append(hexPoints,vector(cos(k*60*degree),sin(k*60*degree))*7.4/sqrt(3)*millimeter);
    for(var k=0;k<6;k+=1) skLineSegment(ns,"edge"~k,{"start":hexPoints[k],"end":hexPoints[(k+1)%6]});
    skSolve(ns);
    opExtrude(context,id+"nutPocketTool",{"entities":qSketchRegion(id+"nutSketch"),"direction":vector(0,-1,0),"endBound":BoundingType.BLIND,"endDepth":3.3*millimeter});
    cut(context,id+"nutPocket",bracket,qCreatedBy(id+"nutPocketTool",EntityType.BODY));
    opDeleteBodies(context,id+"nutSketchClean",{"entities":qCreatedBy(id+"nutSketch",EntityType.BODY)});

    // Preview motion is generated analytically; it is not a contact solver.
    if(!definition.printLayout)
    {
    opTransform(context,id+"rotateCam",{"bodies":qUnion([cam,carrier,indexPin]),"transform":rotationAround(line(v(0,0,0),vector(0,0,1)),definition.angle)});
    opTransform(context,id+"rotateArm",{"bodies":qUnion([arm,roller,axle]),"transform":rotationAround(line(v(-36,-48,0),vector(0,0,1)),beta)});
    if(definition.service) opTransform(context,id+"servicePreview",{"bodies":cam,"transform":transform(v(100,-100,13.5))});
    }
    else
    {
      opDeleteBodies(context,id+"omitHardware",{"entities":qUnion([indexPin,axle,pivot,spring,adjust])});
      printPlace(context,id+"printBracket",bracket,90*degree,10,10);
      printPlace(context,id+"printCam",cam,0*degree,10,100);
      printPlace(context,id+"printHub",carrier,0*degree,110,100);
      printPlace(context,id+"printArm",arm,90*degree,10,175);
      printPlace(context,id+"printRoller",roller,0*degree,90,175);
      label(context,roller,"01 — Roller — print end face down",color(0.75,0.77,0.79));
      label(context,carrier,"02 — Hub — flat carrier underside down",color(0.2,0.42,0.7));
      label(context,cam,"03 — Cam — flat underside down",color(0.95,0.57,0.12));
      label(context,arm,"04 — Fork — long flat side down — bore supports",color(0.18,0.65,0.62));
      label(context,bracket,"05 — Bracket — mounting face down — supports required",color(0.35,0.42,0.46));
    }
    println("Cam occupies z=32..40 mm inside measured frame free slab z=10.5..54 mm.");
    println(count~" detents, +/-70 degree hard stops; spring shown as envelope only.");
}, {"printLayout":false,"showFrame":true,"angle":0*degree,"layout":DetentLayout.SEVEN,"service":false,"lift":1*millimeter});
