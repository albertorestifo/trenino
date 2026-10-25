    // FDM review replacement for fork/roller/pivot/axle block.
    // Flat print-side y=-55; 14 mm bars leave 3.35 mm beside the Ø7.3 pivot bore.
    // Pivot bolt clamps a metal tube, not the printed rotating fork cheeks.
    var arms=[];
    for (var bounds in [[27,30],[41,45]])
    {
        const z0=bounds[0]; const z1=bounds[1];
        arms=append(arms,makeBlock(context,id+("armBar"~z0),v(-54,-55,z0),v(0,-41,z1)));
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
