# Fusion controller redesign

User-authorized redesign of the train controller, retaining the exact existing 2020 frame and Bambu P2S printability. The user delegates mechanical choices and requests brainstorming followed by building. RK097 is an AliExpress family description; shaft/mount must be replaceable and adjustable, not claimed as measured.

## Lessons and selected approach
The earlier design accumulated interfaces, axial play, cantilevers and difficult service access. Printed strength depends on layer direction and local ligaments; a collision-free solid does not prove assembly access, nut retention or spring force. Separate hand-load bearings from the sensor. Design stable endpoints and hard stops independently.

Considered geared drive (more sensor travel but backlash/parts), belt drive (smooth but bought belt/tension loads), direct coaxial drive (fewer parts and no gear backlash, less sensor travel). Builder selects direct drive under user's design discretion. Support lever on independent printed shaft/bushings; low-load floating coupling to removable RK097 bracket. Metal fasteners, tubes and compression spring remain hardware.

## Fixed constraints
Frame copied from original export: X -320..320, Y -95..95, Z -55..55 mm, longitudinal extrusions X -300..300 with centers Y ±85 and Z ±45. Frame is reference metal, never printed. All printable parts must fit P2S 256 mm envelope with practical brim margin. PLA fit prototype, PETG optional later; 0.4 mm nozzle. M3 standard CNC Kitchen inserts 5.7 mm long. No changes to original Onshape model.

## Mechanism
Rail-mounted cartridge with flat side plates normal to X, supported shaft at Y0 Z65; mount to inner faces of fixed upper rails. Integral lever/rotor with removable cam sector; 3/5/7 stable gates spanning roughly ±50 degrees, independent stops just beyond end gates. Wide replaceable bushes and controlled axial end float, printed D-shaft. Spring-loaded double-cheek roller follower supported on a smooth metal sleeve; captive spring and accessible preload screw with mechanically retained nut and travel limit. Detent access from side without removing shaft. Rounded split palm grip around 40 mm wide, 60 mm long, 160 mm pivot-to-crown. Final force is prototype-tuned, not claimed to replicate a specific locomotive.

## Deliverables and checks
Native Fusion components, editable features and named parameters where practical; complete assembled view and print-oriented per-part exports; hardware/reference geometry labeled; BOM and assembly order. Verify solid validity, sampled travel/contact, hardware fit, nut/insert access, independent stops, service path and print envelopes. Mesh and slicer checks before declaring printable. Final FDM/mechanical review once build complete; implement feedback. Actual RK097 shaft fit, electrical calibration and spring feel remain physical checks.
