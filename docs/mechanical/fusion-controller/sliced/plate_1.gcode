; HEADER_BLOCK_START
; BambuStudio 02.04.00.70
; model printing time: 6m 23s; total estimated time: 14m 20s
; total layer number: 84
; total filament length [mm] : 685.29
; total filament volume [cm^3] : 1648.32
; total filament weight [g] : 2.08
; filament_density: 1.26
; filament_diameter: 1.75
; max_z_height: 16.80
; filament: 1
; HEADER_BLOCK_END

; CONFIG_BLOCK_START
; accel_to_decel_enable = 0
; accel_to_decel_factor = 50%
; activate_air_filtration = 0
; additional_cooling_fan_speed = 70
; apply_scarf_seam_on_circles = 1
; apply_top_surface_compensation = 0
; auto_disable_filter_on_overheat = 0
; auxiliary_fan = 1
; avoid_crossing_wall_includes_support = 0
; bed_custom_model = 
; bed_custom_texture = 
; bed_exclude_area = 
; bed_temperature_formula = by_first_filament
; before_layer_change_gcode = 
; best_object_pos = 0.5,0.5
; bottom_color_penetration_layers = 3
; bottom_shell_layers = 5
; bottom_shell_thickness = 0
; bottom_surface_pattern = monotonic
; bridge_angle = 0
; bridge_flow = 1
; bridge_no_support = 0
; bridge_speed = 50
; brim_object_gap = 0.1
; brim_type = auto_brim
; brim_width = 0
; chamber_temperatures = 0
; change_filament_gcode = ;======== P2S filament_change gcode ==========\n;===== 2025/11/04 =====\n\nM620 S[next_extruder]A\nM204 S9000\n{if toolchange_count > 1 && (z_hop_types[current_extruder] == 0 || z_hop_types[current_extruder] == 3)}\nG17\nG2 Z{z_after_toolchange + 0.4} I0.86 J0.86 P1 F10000 ; spiral lift a little from second lift\n{endif}\n\n;nozzle_change_gcode\n\nG1 Z{max_layer_z + 3.0} F1200\n\nM400\nM106 P1 S0\n\n{if toolchange_count == 2}\n; get travel path for change filament\n;M620.1 X[travel_point_1_x] Y[travel_point_1_y] F21000 P0\n;M620.1 X[travel_point_2_x] Y[travel_point_2_y] F21000 P1\n;M620.1 X[travel_point_3_x] Y[travel_point_3_y] F21000 P2\n{endif}\n\n{if ((filament_type[current_extruder] == "PLA") || (filament_type[current_extruder] == "PLA-CF") || (filament_type[current_extruder] == "PETG")) && (nozzle_diameter[current_extruder] == 0.2)}\nM620.10 A0 F74.8347 L[flush_length] H{nozzle_diameter[current_extruder]} T{flush_temperatures[current_extruder]} P{nozzle_temperature[current_extruder]} S1\n{else}\nM620.10 A0 F{flush_volumetric_speeds[current_extruder]/2.4053*60} L[flush_length] H{nozzle_diameter[current_extruder]} T{flush_temperatures[current_extruder]} P{nozzle_temperature[current_extruder]} S1\n{endif}\n\n{if ((filament_type[next_extruder] == "PLA") || (filament_type[next_extruder] == "PLA-CF") || (filament_type[next_extruder] == "PETG")) && (nozzle_diameter[next_extruder] == 0.2)}\nM620.10 A1 F74.8347 L[flush_length] H{nozzle_diameter[next_extruder]} T{flush_temperatures[next_extruder]} P{nozzle_temperature[next_extruder]} S1\n{else}\nM620.10 A1 F{flush_volumetric_speeds[next_extruder]/2.4053*60} L[flush_length] H{nozzle_diameter[next_extruder]} T{flush_temperatures[next_extruder]} P{nozzle_temperature[next_extruder]} S1\n{endif}\n\n{if long_retraction_when_cut}\nM620.11 P1 L0 I[current_extruder] E-{retraction_distance_when_cut} F{max((flush_volumetric_speeds[current_extruder]/2.4053*60), 200)}\n{else}\nM620.11 P0 L0 I[current_extruder] E0\n{endif}\n\nM620.11 K0 I[current_extruder] R0\n\n  \nT[next_extruder]\n\n;deretract\n{if filament_type[next_extruder] == "TPU"}\n{else}\n{if filament_type[next_extruder] == "PA"}\n;VG1 E1 F{max(new_filament_e_feedrate, 200)}\n;VG1 E1 F{max(new_filament_e_feedrate/2, 100)}\n{else}\n;VG1 E4 F{max(new_filament_e_feedrate, 200)}\n;VG1 E4 F{max(new_filament_e_feedrate/2, 100)}\n{endif}\n{endif}\n\n; VFLUSH_START\n{if flush_length>41.5}\n;VG1 E41.5 F{min(old_filament_e_feedrate,new_filament_e_feedrate)}\n;VG1 E{flush_length-41.5} F{new_filament_e_feedrate}\n{else}\n;VG1 E{flush_length} F{min(old_filament_e_feedrate,new_filament_e_feedrate)}\n{endif}\nSYNC T{ceil(flush_length / 80) * 5}\n; VFLUSH_END\n\nM1002 set_filament_type:{filament_type[next_extruder]}\n\nM400\nM83\n{if next_extruder < 255}\nM620.10 R{retract_length_toolchange[filament_map[next_extruder]-1]}\nM628 S0\n;VM109 S[new_filament_temp]\n\nM629\nM400\nM983.3 F{filament_max_volumetric_speed[next_extruder]/2.4} A0.4 R{retract_length_toolchange[filament_map[next_extruder]-1]}\nM400\n\nG1 Z{max_layer_z + 3.0} F3000\n{if layer_z <= (initial_layer_print_height + 0.001)}\nM204 S[initial_layer_acceleration]\n{else}\nM204 S[travel_acceleration]\n{endif}\n\n{else}\nG1 X[x_after_toolchange] Y[y_after_toolchange] Z[z_after_toolchange] F12000\n{endif}\n\nM621 S[next_extruder]A\n\n{if (filament_type[next_extruder] == "PLA") ||  (filament_type[next_extruder] == "PETG")\n ||  (filament_type[next_extruder] == "PLA-CF")  ||  (filament_type[next_extruder] == "PETG-CF")}\nM1015.4 S1 K1 H[nozzle_diameter] ;enable E air printing detect\n{else}\nM1015.4 S0 K0 H[nozzle_diameter] ;disable E air printing detect\n{endif}\n\nM620.6 I[next_extruder] W1 ;enable ams air printing detect\n\n\n{if (overall_chamber_temperature < 40)}\n{if (layer_num + 1 < close_fan_the_first_x_layers[next_extruder] + 1)}\n    {if (min_vitrification_temperature <= 50)}\n        M106 P2 S{first_x_layer_fan_speed[next_extruder]*255.0/100.0 };set first x_layer aux fan\n        M106 P10 S{first_x_layer_fan_speed[next_extruder]*255.0/100.0 };set first x_layer left aux fan \n    {endif}\n{else}\n    {if (min_vitrification_temperature <= 50)}\n        {if (nozzle_diameter == 0.2)}\n            M142 P1 R30 S40 U{max_additional_fan/100.0} V1.0 O45; set PLA/TPU ND0.2 chamber autocooling\n        {else}\n            M142 P1 R30 S40 U{max_additional_fan/100.0} V1.0 O45; set PLA/TPU ND0.4 chamber autocooling\n        {endif}\n    {endif}\n        M106 P10 S{additional_cooling_fan_speed[next_extruder]*255.0/100.0};set left aux fan \n{endif}\n{endif}\n;not set fan changing filament
; circle_compensation_manual_offset = 0
; circle_compensation_speed = 200
; close_fan_the_first_x_layers = 1
; compatible_printers_condition = 
; complete_print_exhaust_fan_speed = 70
; cool_plate_temp = 35
; cool_plate_temp_initial_layer = 35
; cooling_filter_enabled = 0
; counter_coef_1 = 0
; counter_coef_2 = 0.008
; counter_coef_3 = -0.041
; counter_limit_max = 0.033
; counter_limit_min = -0.035
; curr_bed_type = Textured PEI Plate
; default_acceleration = 10000
; default_filament_colour = ""
; default_filament_profile = "Bambu PLA Basic @BBL P2S"
; default_jerk = 0
; default_nozzle_volume_type = Standard
; default_print_profile = 0.20mm Standard @BBL P2S
; deretraction_speed = 30
; detect_floating_vertical_shell = 1
; detect_narrow_internal_solid_infill = 1
; detect_overhang_wall = 1
; detect_thin_wall = 0
; diameter_limit = 50
; different_settings_to_system = ;;
; draft_shield = disabled
; during_print_exhaust_fan_speed = 70
; elefant_foot_compensation = 0.15
; embedding_wall_into_infill = 0
; enable_arc_fitting = 1
; enable_circle_compensation = 0
; enable_height_slowdown = 0
; enable_long_retraction_when_cut = 2
; enable_overhang_bridge_fan = 1
; enable_overhang_speed = 1
; enable_pre_heating = 0
; enable_pressure_advance = 0
; enable_prime_tower = 1
; enable_support = 0
; enable_wrapping_detection = 0
; enforce_support_layers = 0
; eng_plate_temp = 55
; eng_plate_temp_initial_layer = 55
; ensure_vertical_shell_thickness = enabled
; exclude_object = 1
; extruder_ams_count = 
; extruder_clearance_dist_to_rod = 36.5
; extruder_clearance_height_to_lid = 141.5
; extruder_clearance_height_to_rod = 32.5
; extruder_clearance_max_radius = 72
; extruder_colour = #018001
; extruder_max_nozzle_count = 1
; extruder_nozzle_stats = 
; extruder_offset = 0x0
; extruder_printable_area = 
; extruder_type = Direct Drive
; extruder_variant_list = "Direct Drive Standard,Direct Drive High Flow"
; fan_cooling_layer_time = 100
; fan_direction = right
; fan_max_speed = 100
; fan_min_speed = 100
; filament_adaptive_volumetric_speed = 0
; filament_adhesiveness_category = 100
; filament_change_length = 5
; filament_change_length_nc = 10
; filament_colour = #00AE42
; filament_cooling_before_tower = 10
; filament_cost = 24.99
; filament_density = 1.26
; filament_diameter = 1.75
; filament_end_gcode = "; filament end gcode \n\n"
; filament_extruder_variant = "Direct Drive Standard"
; filament_flow_ratio = 0.98
; filament_flush_temp = 0
; filament_flush_volumetric_speed = 0
; filament_ids = GFA00
; filament_is_support = 0
; filament_map = 1
; filament_map_2 = 0
; filament_map_mode = Auto For Flush
; filament_max_volumetric_speed = 21
; filament_minimal_purge_on_wipe_tower = 15
; filament_notes = 
; filament_nozzle_map = 0
; filament_pre_cooling_temperature = 0
; filament_pre_cooling_temperature_nc = 0
; filament_prime_volume = 30
; filament_prime_volume_nc = 60
; filament_printable = 3
; filament_ramming_travel_time = 0
; filament_ramming_travel_time_nc = 0
; filament_ramming_volumetric_speed = -1
; filament_ramming_volumetric_speed_nc = -1
; filament_retract_length_nc = 14
; filament_retraction_distances_when_cut = 10
; filament_scarf_gap = 0%
; filament_scarf_height = 10%
; filament_scarf_length = 10
; filament_scarf_seam_type = none
; filament_self_index = 1,1
; filament_settings_id = "Bambu PLA Basic @BBL P2S"
; filament_shrink = 100%
; filament_soluble = 0
; filament_start_gcode = "; filament start gcode\n"
; filament_type = PLA
; filament_velocity_adaptation_factor = 1
; filament_vendor = "Bambu Lab"
; filament_volume_map = 0
; filename_format = {input_filename_base}_{filament_type[0]}_{print_time}.gcode
; fill_multiline = 1
; filter_out_gap_fill = 0
; first_layer_print_sequence = 0
; first_x_layer_fan_speed = 40
; flush_into_infill = 0
; flush_into_objects = 0
; flush_into_support = 1
; flush_multiplier = 1
; flush_volumes_matrix = 0,280,280,280,280,0,280,280,280,280,0,280,280,280,280,0
; flush_volumes_vector = 140,140,140,140,140,140,140,140
; full_fan_speed_layer = 0
; fuzzy_skin = none
; fuzzy_skin_point_distance = 0.8
; fuzzy_skin_thickness = 0.3
; gap_infill_speed = 250
; gcode_add_line_number = 0
; gcode_flavor = marlin
; grab_length = 0
; group_algo_with_time = 0
; has_scarf_joint_seam = 0
; head_wrap_detect_zone = 
; hole_coef_1 = 0
; hole_coef_2 = -0.008
; hole_coef_3 = 0.23415
; hole_limit_max = 0.22
; hole_limit_min = 0.088
; hot_plate_temp = 55
; hot_plate_temp_initial_layer = 55
; hotend_cooling_rate = 2
; hotend_heating_rate = 2
; impact_strength_z = 13.8
; independent_support_layer_height = 1
; infill_combination = 0
; infill_direction = 45
; infill_instead_top_bottom_surfaces = 0
; infill_jerk = 9
; infill_lock_depth = 1
; infill_rotate_step = 0
; infill_shift_step = 0.4
; infill_wall_overlap = 15%
; inherits_group = fdm_process_single_0.20;"Bambu PLA Basic @base";"Bambu Lab P2S 0.4 nozzle"
; initial_layer_acceleration = 500
; initial_layer_flow_ratio = 1
; initial_layer_infill_speed = 105
; initial_layer_jerk = 9
; initial_layer_line_width = 0.5
; initial_layer_print_height = 0.2
; initial_layer_speed = 50
; initial_layer_travel_acceleration = 6000
; inner_wall_acceleration = 0
; inner_wall_jerk = 9
; inner_wall_line_width = 0.45
; inner_wall_speed = 300
; interface_shells = 0
; interlocking_beam = 0
; interlocking_beam_layer_count = 2
; interlocking_beam_width = 0.8
; interlocking_boundary_avoidance = 2
; interlocking_depth = 2
; interlocking_orientation = 22.5
; internal_bridge_support_thickness = 0.8
; internal_solid_infill_line_width = 0.42
; internal_solid_infill_pattern = zig-zag
; internal_solid_infill_speed = 250
; ironing_direction = 45
; ironing_flow = 10%
; ironing_inset = 0.21
; ironing_pattern = zig-zag
; ironing_spacing = 0.15
; ironing_speed = 30
; ironing_type = no ironing
; is_infill_first = 0
; layer_change_gcode = ;======== P2S layer_change gcode ==========\n;===== 2025/11/04 ====\n\n{if (layer_num + 1 == 1)}\n{if (overall_chamber_temperature >= 40)}\n    ;not reset filter fan in first layer\n    ;not reset fan\n{else}\n{if (min_vitrification_temperature > 50)}\n    ;not reset filter fan in first layer\n    ;not reset fan\n{endif}        \n{endif}\n{endif}\n\n{if (layer_num + 1 == close_fan_the_first_x_layers[current_extruder]+1)}\n{if (overall_chamber_temperature < 40)}\n    ;updata chamber autocooling in Xth layer\n    {if (min_vitrification_temperature <= 50)}\n        {if (nozzle_diameter == 0.2)}\n            M142 P1 R30 S40 U{max_additional_fan/100.0} V1.0 O45; set PLA/TPU ND0.2 chamber autocooling\n        {else}\n            M142 P1 R30 S40 U{max_additional_fan/100.0} V1.0 O45; set PLA/TPU ND0.4 chamber autocooling\n        {endif}\n    {else}\n            ;not reset filter fan in Xth layer\n    {endif}\n    M106 P10 S{additional_cooling_fan_speed[current_extruder]*255.0/100.0}; set left aux fan \n{else}\n        ;not reset filter fan in Xth layer\n{endif}\n;not reset fan\n{endif}\n\n\n; update layer progress\nM73 L{layer_num+1}\nM991 S0 P{layer_num} ;notify layer change\n\n
; layer_height = 0.2
; line_width = 0.42
; locked_skeleton_infill_pattern = zigzag
; locked_skin_infill_pattern = crosszag
; long_retractions_when_cut = 0
; long_retractions_when_ec = 0
; machine_end_gcode = ;======== P2S end gcode ==========\n;===== 2025/11/03 =====\nM400 ; wait for buffer to clear\nG92 E0 ; zero the extruder\nG1 E-0.8 F1800 ; retract\nG0 Z{max_layer_z + 0.8} F900\n\n; pull back filament to AMS\nM620 S65535\nT65535\nG150.2\nM621 S65535\n\nG150.3\n\nM400 ; wait all motion done\nM991 S0 P-1 ;end smooth timelapse at safe pos\n\nM1002 judge_flag timelapse_record_flag\nM622 J1\n    M400 S5 ;wait for last picture to be taken\nM623  ;end of "timelapse_record_flag"\n\nM106 S0 ; turn off fan\nM106 P2 S0 ; turn off remote part cooling fan\nM106 P3 S0 ; turn off chamber cooling fan\nM106 P10 S0 ; turn off left aux fan\n\nM400 ; wait all motion done\nM17 S\nM17 Z0.4 ; lower z motor current to reduce impact if there is something in the bottom\n{if (80.0 - max_layer_z/2) > 0}\n    {if (max_layer_z + 80.0 - max_layer_z/2) < 256}\n        G1 Z{max_layer_z + 80.0 - max_layer_z/2} F600\n        G1 Z{max_layer_z + 78.0 - max_layer_z/2}\n    {else}\n        G1 Z256 F600\n        G1 Z256\n    {endif}\n{else}\n    {if (max_layer_z + 4.0) < 256}\n        G1 Z{max_layer_z + 4.0} F600\n        G1 Z{max_layer_z + 2.0}\n    {else}\n        G1 Z256 F600\n        G1 Z256\n    {endif}\n{endif}\nM400 P100\nM17 R ; restore z current\n\n\nM220 S100  ; Reset feedrate magnitude\nM201.2 K1.0 ; Reset acc magnitude\nM73.2 R1.0 ;Reset left time magnitude\nM1002 set_gcode_claim_speed_level : 0\n\nM1015.3 S0 ;disable clog detect\nM1015.4 S0 K0 ;disable air printing detect\n;=====printer finish  sound=========\nM17\nM400 S1\nM1006 S1\nM1006 A53 B10 L99 C53 D10 M99 E53 F10 N99 \nM1006 A57 B10 L99 C57 D10 M99 E57 F10 N99 \nM1006 A0 B15 L0 C0 D15 M0 E0 F15 N0 \nM1006 A53 B10 L99 C53 D10 M99 E53 F10 N99 \nM1006 A57 B10 L99 C57 D10 M99 E57 F10 N99 \nM1006 A0 B15 L0 C0 D15 M0 E0 F15 N0 \nM1006 A48 B10 L99 C48 D10 M99 E48 F10 N99 \nM1006 A0 B15 L0 C0 D15 M0 E0 F15 N0 \nM1006 A60 B10 L99 C60 D10 M99 E60 F10 N99 \nM1006 W\n;=====printer finish  sound=========\nM400\nM18\n\nM104 S0 ; turn off hotend\nM140 S0 ; turn off bed
; machine_hotend_change_time = 0
; machine_load_filament_time = 26
; machine_max_acceleration_e = 5000,5000
; machine_max_acceleration_extruding = 20000,20000
; machine_max_acceleration_retracting = 5000,5000
; machine_max_acceleration_travel = 10000,10000
; machine_max_acceleration_x = 20000,20000
; machine_max_acceleration_y = 20000,20000
; machine_max_acceleration_z = 500,200
; machine_max_jerk_e = 2.5,2.5
; machine_max_jerk_x = 9,9
; machine_max_jerk_y = 9,9
; machine_max_jerk_z = 3,3
; machine_max_speed_e = 30,30
; machine_max_speed_x = 600,600
; machine_max_speed_y = 600,600
; machine_max_speed_z = 20,20
; machine_min_extruding_rate = 0
; machine_min_travel_rate = 0
; machine_pause_gcode = M400 U1
; machine_prepare_compensation_time = 370
; machine_start_gcode = ;M1002 set_flag extrude_cali_flag=1\n;M1002 set_flag g29_before_print_flag=1\n;M1002 set_flag auto_cali_toolhead_offset_flag=1\n;M1002 set_flag build_plate_detect_flag=1\n\n;======== P2S start gcode==========\n;===== 2025/11/04 =====\n\n  M140 S[bed_temperature_initial_layer_single] ; heat heatbed first\n  M993 A0 B0 C0 ; nozzle cam detection not allowed.\n  M400\n\n;=====printer start sound ===================\nM17\nM400 S1\nM1006 S1\nM1006 A53 B9 L99 C53 D9 M99 E53 F9 N99 \nM1006 A56 B9 L99 C56 D9 M99 E56 F9 N99 \nM1006 A61 B9 L99 C61 D9 M99 E61 F9 N99 \nM1006 A53 B9 L99 C53 D9 M99 E53 F9 N99 \nM1006 A56 B9 L99 C56 D9 M99 E56 F9 N99 \nM1006 A61 B18 L99 C61 D18 M99 E61 F18 N99 \nM1006 W\n;=====printer start sound ===================\n\n  M620 M ;enable remap\n  G389\n\n;===== avoid end stop =================\n  G91\n  G380 S2 Z22 F1200\n  G380 S2 Z-12 F1200\n  G90\n;===== avoid end stop =================\n\n;===== reset machine status =================\n  M204 S10000\n  M630 S0 P1\n  G90\n  M17 D ; reset motor current to default\n  M960 S5 P1 ; turn on logo lamp\n  G90\n  M220 S100 ;Reset Feedrate\n  M1002 set_gcode_claim_speed_level: 5\n  M221 S100 ;Reset Flowrate\n  M73.2   R1.0 ;Reset left time magnitude\n  G29.1 Z{+0.0} ; clear z-trim value first\n  M983.1 M1\n  M982.2 S1 ; turn on cog noise reduction\n  M983.4 S0\n;===== reset machine status =================\n\n;==== set airduct mode ==== \n;==== if Chamber Cooling is necessary ====\n{if (overall_chamber_temperature >= 40)}\nM145 P1 ; set airduct mode to heating mode for heating\nM106 P2 S255 ; turn on filter fan\n{else}\n{if (min_vitrification_temperature <= 50)}\nM145 P0 ; set airduct mode to cooling mode for cooling\nM106 P2 S255 ; turn on auxiliary fan for cooling\nM1002 gcode_claim_action : 29\nM191 S0 ; wait for chamber temp\nM106 P2 S102 ; turn on chamber cooling fan\nM106 P10 S0 ; turn off left aux fan\n{else}\nM145 P1 ; set airduct mode to heating mode for heating\nM106 P2 S127 ; turn on 50% filter fan\n{endif}\n{endif}\n;==== set airduct mode ==== \n\n;===== start to heat heatbed & hotend==========\n  M1002 gcode_claim_action : 2\n  M1002 set_filament_type:{filament_type[initial_no_support_extruder]}\n  M104 S140 A        \n\n  G29.2 S0 ; avoid invalid abl data\n\n;===== first homing start =====\n  M1002 gcode_claim_action : 13\n  G28 X T300\n  G150.3\n  M972 S24 P0\n  M972 S26 P0 C0\n  M972 S42 P0 T5000\n  G150.1 F8000 ; wipe mouth to avoid filament stick to heatbed\n  G90\n  G1 X128 Y128 F30000\n  G28 Z P0 T400\n  M400\n;===== first homign end =====\n\n;===== detection start =====\n  M1002 gcode_claim_action : 11\n  M104 S{nozzle_temperature_initial_layer[initial_no_support_extruder]-80} A ; rise temp in advance\n  M972 S19 P0 T5000 ;plate type detection\n;===== detection end =====\n\n;===== prepare print temperature and material ==========\n  M400\n  M211 X0 Y0 Z0 ;turn off soft endstop\n  M975 S1 ; turn on input shaping\n\n  G29.2 S0 ; avoid invalid abl data\n  G150.3\n{if ((filament_type[initial_no_support_extruder] == "PLA") || (filament_type[initial_no_support_extruder] == "PLA-CF") || (filament_type[initial_no_support_extruder] == "PETG")) && (nozzle_diameter[initial_no_support_extruder] == 0.2)}\nM620.10 A0 F74.8347 H{nozzle_diameter[initial_no_support_extruder]} T{flush_temperatures[initial_no_support_extruder]} P{nozzle_temperature_initial_layer[initial_no_support_extruder]} S1\nM620.10 A1 F74.8347 H{nozzle_diameter[initial_no_support_extruder]} T{flush_temperatures[initial_no_support_extruder]} P{nozzle_temperature_initial_layer[initial_no_support_extruder]} S1\n{else}\nM620.10 A0 F{flush_volumetric_speeds[initial_no_support_extruder]/2.4053*60} H{nozzle_diameter[initial_no_support_extruder]} T{flush_temperatures[initial_no_support_extruder]} P{nozzle_temperature_initial_layer[initial_no_support_extruder]} S1\nM620.10 A1 F{flush_volumetric_speeds[initial_no_support_extruder]/2.4053*60} H{nozzle_diameter[initial_no_support_extruder]} T{flush_temperatures[initial_no_support_extruder]} P{nozzle_temperature_initial_layer[initial_no_support_extruder]} S1\n{endif}\n\n M620.11 P0 L0 I[initial_no_support_extruder] E0\n M620.11 K0 I[initial_no_support_extruder] R0\n\n  M620 S[initial_no_support_extruder]A   ; switch material if AMS exist\n  M1002 gcode_claim_action : 4\n  M1002 set_filament_type:UNKNOWN\n  M400\n  T[initial_no_support_extruder]\n  M400\n  M628 S0\n  M629\n  M400\n  M1002 set_filament_type:{filament_type[initial_no_support_extruder]}\n  M621 S[initial_no_support_extruder]A\n  M104 S{nozzle_temperature_initial_layer[initial_no_support_extruder]}\n  M400\n  M106 P1 S0\n  M400\n  G29.2 S1\n;===== prepare print temperature and material ==========\n\n\n;===== auto extrude cali start =========================\n  M975 S1\n  M1002 judge_flag extrude_cali_flag\n  M622 J0\n    M983.3 F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4} A0.4 ; cali dynamic extrusion compensation\n  M623\n\n  M622 J1\n    M1002 set_filament_type:{filament_type[initial_no_support_extruder]}\n    M1002 gcode_claim_action : 8\n    M109 S{nozzle_temperature[initial_no_support_extruder]}\n    G90\n    M83\n    M983.3 F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4} A0.4 ; cali dynamic extrusion compensation\n    M400\n    M106 P1 S255\n    M400 S5\n    M106 P1 S0\n    G150.3\n  M623\n\n  M622 J2\n    M1002 set_filament_type:{filament_type[initial_no_support_extruder]}\n    M1002 gcode_claim_action : 8\n    M109 S{nozzle_temperature[initial_no_support_extruder]}\n    G90\n    M83\n    M983.3 F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4} A0.4 ; cali dynamic extrusion compensation\n    M400\n    M106 P1 S255\n    M400 S5\n    M106 P1 S0\n    G150.3\n  M623\n;===== auto extrude cali end =========================\n\n  {if hold_chamber_temp_for_flat_print}\n    M1002 gcode_claim_action : 58\n    M104 S{first_layer_temperature[initial_no_support_extruder]}\n    {if bed_temperature_initial_layer_single > 89}\n        M1030 S1800      \n    {else}\n        M1030 S300\n    {endif}\n    M1030 C\n  {endif}\n\n  {if filament_type[current_extruder] == "TPU" || filament_type[current_extruder] == "PVA"}\n  {else}\n    M83\n    G1 E-3 F1800\n    M400 P500\n  {endif}\n  G150.2\n  G150.1 F8000\n  G0 Z10 F1200\n  G150.2\n  G150.1 F8000\n  G0 Z5 F1200\n  G150.1 F8000\n\n  G91\n  G1 Y-16 F12000 ; move away from the trash bin\n  G90\n  M400\n\n  M104 S{nozzle_temperature_initial_layer[initial_no_support_extruder]-80} A\n\n;===== wipe right nozzle start =====\n  M1002 gcode_claim_action : 14\n  G150 T{nozzle_temperature_initial_layer[initial_no_support_extruder]}\n  M400\n\n{if filament_type[current_extruder] == "PC"}\n  M109 S170 A\n{else}\n  M109 S140 A\n{endif}\n  G91\n  G1 Z5 F1200\n  G90\n  M400\n  G150.1\n;===== wipe left nozzle end =====\n\n\n;===== mech mode sweep start =====\n  M1002 gcode_claim_action : 3\n  G90\n  G1 X128 Y128 F20000\n  G1 Z5 F1200\n  M400 P200\n  M970.3 Q1 A10 K0 O1\n  M970.2 Q1 K1 W74 Z0.01\n  M974 Q1 S2 P0\n  M970.3 Q0 A10 K0 O1\n  M970.2 Q0 K1 W74 Z0.01\n  M974 Q0 S2 P0\n  M975 S1\n  M400\n;===== mech mode sweep end =====\n\n;===== bed leveling ==================================\n  M1002 gcode_claim_action : 54\n  M190 S[bed_temperature_initial_layer_single]; ensure bed temp\n  M109 S140 A\n  M106 S0 ; turn off fan , too noisy\n  M1002 judge_flag g29_before_print_flag\n  M622 J1\n    M1002 gcode_claim_action : 1\n    {if hold_chamber_temp_for_flat_print}\n      G29 H\n    {else}\n      G29 A1 X{first_layer_print_min[0]} Y{first_layer_print_min[1]} I{first_layer_print_size[0]} J{first_layer_print_size[1]}\n    {endif}\n    M400\n    M500 ; save cali data\n  M623\n\n  M622 J2\n    M1002 gcode_claim_action : 1\n    {if hold_chamber_temp_for_flat_print}\n      G29 H\n    {else}\n      G29 A2 X{first_layer_print_min[0]} Y{first_layer_print_min[1]} I{first_layer_print_size[0]} J{first_layer_print_size[1]}\n    {endif}\n    M400\n    M500 ; save cali data\n  M623\n\n  M622 J0\n    G28\n  M623\n  G29.2 S1\n\n;===== bed leveling end ================================\n\n  M985.1 U0 E2\n  M985.1 U1 E2\n\n  M104 S[nozzle_temperature_initial_layer] A\n  G150.3 ; move to garbage can to wait for temp\n\n;===== wait temperature reaching the reference value =======\n  M190 S[bed_temperature_initial_layer_single] \n\n  ;========turn off light and fans =============\n  M960 S1 P0 ; turn off laser\n  M960 S2 P0 ; turn off laser\n  M106 S0 ; turn off cooling fan\n\n;===== wait temperature reaching the reference value =======\n\n  M1002 gcode_claim_action : 255\n  M400\n  M975 S1 ; turn on mech mode supression\n\n;============switch again==================\n  M211 X0 Y0 Z0 ;turn off soft endstop\n  G91\n  G1 Z6 F1200\n  G90\n  M1002 set_filament_type:{filament_type[initial_no_support_extruder]}\n  M620 S[initial_no_support_extruder]A\n  M400\n  T[initial_no_support_extruder]\n  M400\n  M628 S0\n  M629\n  M400\n  M621 S[initial_no_support_extruder]A\n;============switch again==================\n\n;===== for Textured PEI Plate , lower the nozzle as the nozzle was touching topmost of the texture when homing ==\n  {if curr_bed_type=="Textured PEI Plate"}\n    G29.1 Z{0.01} ; for Textured PEI Plate\n  {else}\n    G29.1 Z{0.03}\n  {endif}\n\n;===== nozzle load line ===============================\nM1002 gcode_claim_action : 51\n  G29.2 S1 ; ensure z comp turn on\n  G90\n  M83\n  M109 S{nozzle_temperature_initial_layer[initial_no_support_extruder]}\n  G130 O0 X100 Y-0.4 Z0.8 F{filament_max_volumetric_speed[initial_no_support_extruder]/2/2.4053} L40 E20 D5\n  ;G130 O0 X100 Y-0.2 Z0.6 F{filament_max_volumetric_speed[initial_no_support_extruder]/2/2.4053} L40 E12 D4\n  G90\n  M83\n  G1 Z0.2\n  M400\n;===== noozle load line end ===========================\nM1002 gcode_claim_action : 0\n  G29.99\n\n{if (filament_type[initial_no_support_extruder] == "TPU") || \n(filament_type[initial_no_support_extruder] == "PLA") ||  (filament_type[initial_no_support_extruder] == "PETG")}\nM1015.3 S1 H[nozzle_diameter];enable tpu, pla and petg clog detect\n{else}\nM1015.3 S0;disable clog detect\n{endif}\n\n{if (filament_type[initial_no_support_extruder] == "PLA") ||  (filament_type[initial_no_support_extruder] == "PETG")\n ||  (filament_type[initial_no_support_extruder] == "PLA-CF")  ||  (filament_type[initial_no_support_extruder] == "PETG-CF")}\nM1015.4 S1 K1 H[nozzle_diameter] ;enable E air printing detect\n{else}\nM1015.4 S0 K0 H[nozzle_diameter] ;disable E air printing detect\n{endif}\n\nM620.6 I[initial_no_support_extruder] W1 ;enable ams air printing detect\n\nM1010 Q0 B0.023 S0.01\nM1010 Q1 B0.005 S0.01\nM1010.1 S1
; machine_switch_extruder_time = 0
; machine_unload_filament_time = 31
; master_extruder_id = 1
; max_bridge_length = 0
; max_layer_height = 0.28
; max_travel_detour_distance = 0
; min_bead_width = 85%
; min_feature_size = 25%
; min_layer_height = 0.08
; minimum_sparse_infill_area = 15
; mmu_segmented_region_interlocking_depth = 0
; mmu_segmented_region_max_width = 0
; no_slow_down_for_cooling_on_outwalls = 0
; nozzle_diameter = 0.4
; nozzle_flush_dataset = 0
; nozzle_height = 4.2
; nozzle_temperature = 220
; nozzle_temperature_initial_layer = 220
; nozzle_temperature_range_high = 240
; nozzle_temperature_range_low = 190
; nozzle_type = hardened_steel
; nozzle_volume = 110
; nozzle_volume_type = Standard
; only_one_wall_first_layer = 0
; ooze_prevention = 0
; other_layers_print_sequence = 0
; other_layers_print_sequence_nums = 0
; outer_wall_acceleration = 6000
; outer_wall_jerk = 9
; outer_wall_line_width = 0.42
; outer_wall_speed = 200
; overhang_1_4_speed = 0
; overhang_2_4_speed = 50
; overhang_3_4_speed = 30
; overhang_4_4_speed = 10
; overhang_fan_speed = 100
; overhang_fan_threshold = 50%
; overhang_threshold_participating_cooling = 95%
; overhang_totally_speed = 10
; override_filament_scarf_seam_setting = 0
; physical_extruder_map = 0
; post_process = 
; pre_start_fan_time = 0
; precise_outer_wall = 0
; precise_z_height = 0
; pressure_advance = 0.02
; prime_tower_brim_width = 3
; prime_tower_enable_framework = 0
; prime_tower_extra_rib_length = 0
; prime_tower_fillet_wall = 1
; prime_tower_flat_ironing = 0
; prime_tower_infill_gap = 150%
; prime_tower_lift_height = -1
; prime_tower_lift_speed = 90
; prime_tower_max_speed = 90
; prime_tower_rib_wall = 1
; prime_tower_rib_width = 8
; prime_tower_skip_points = 1
; prime_tower_width = 35
; prime_volume_mode = Default
; print_compatible_printers = "Bambu Lab P2S 0.4 nozzle"
; print_extruder_id = 1
; print_extruder_variant = "Direct Drive Standard"
; print_flow_ratio = 1
; print_sequence = by layer
; print_settings_id = 0.20mm Standard @BBL P2S — reviewed CLI check
; printable_area = 0x0,256x0,256x256,0x256
; printable_height = 256
; printer_extruder_id = 1
; printer_extruder_variant = "Direct Drive Standard"
; printer_model = Bambu Lab P2S
; printer_notes = 
; printer_settings_id = Bambu Lab P2S 0.4 nozzle
; printer_structure = corexy
; printer_technology = FFF
; printer_variant = 0.4
; printing_by_object_gcode = 
; process_notes = 
; raft_contact_distance = 0.1
; raft_expansion = 1.5
; raft_first_layer_density = 90%
; raft_first_layer_expansion = -1
; raft_layers = 0
; reduce_crossing_wall = 0
; reduce_fan_stop_start_freq = 1
; reduce_infill_retraction = 1
; required_nozzle_HRC = 3
; resolution = 0.012
; retract_before_wipe = 0%
; retract_length_toolchange = 2
; retract_lift_above = 0
; retract_lift_below = 249
; retract_restart_extra = 0
; retract_restart_extra_toolchange = 0
; retract_when_changing_layer = 1
; retraction_distances_when_cut = 18
; retraction_distances_when_ec = 0
; retraction_length = 0.8
; retraction_minimum_travel = 1
; retraction_speed = 30
; role_base_wipe_speed = 1
; scan_first_layer = 0
; scarf_angle_threshold = 155
; seam_gap = 15%
; seam_placement_away_from_overhangs = 0
; seam_position = aligned
; seam_slope_conditional = 1
; seam_slope_entire_loop = 0
; seam_slope_gap = 0
; seam_slope_inner_walls = 1
; seam_slope_min_length = 10
; seam_slope_start_height = 10%
; seam_slope_steps = 10
; seam_slope_type = none
; silent_mode = 0
; single_extruder_multi_material = 1
; skeleton_infill_density = 15%
; skeleton_infill_line_width = 0.45
; skin_infill_density = 15%
; skin_infill_depth = 2
; skin_infill_line_width = 0.45
; skirt_distance = 2
; skirt_height = 1
; skirt_loops = 0
; slice_closing_radius = 0.049
; slicing_mode = regular
; slow_down_for_layer_cooling = 1
; slow_down_layer_time = 4
; slow_down_min_speed = 20
; slowdown_end_acc = 100000
; slowdown_end_height = 400
; slowdown_end_speed = 1000
; slowdown_start_acc = 100000
; slowdown_start_height = 0
; slowdown_start_speed = 1000
; small_perimeter_speed = 50%
; small_perimeter_threshold = 0
; smooth_coefficient = 4
; smooth_speed_discontinuity_area = 1
; solid_infill_filament = 0
; sparse_infill_acceleration = 100%
; sparse_infill_anchor = 400%
; sparse_infill_anchor_max = 20
; sparse_infill_density = 35%
; sparse_infill_filament = 0
; sparse_infill_line_width = 0.45
; sparse_infill_pattern = gyroid
; sparse_infill_speed = 270
; spiral_mode = 0
; spiral_mode_max_xy_smoothing = 200%
; spiral_mode_smooth = 0
; standby_temperature_delta = -5
; start_end_points = 30x-3,54x245
; supertack_plate_temp = 45
; supertack_plate_temp_initial_layer = 45
; support_air_filtration = 0
; support_angle = 0
; support_base_pattern = default
; support_base_pattern_spacing = 2.5
; support_bottom_interface_spacing = 0.5
; support_bottom_z_distance = 0.2
; support_chamber_temp_control = 0
; support_cooling_filter = 0
; support_critical_regions_only = 0
; support_expansion = 0
; support_filament = 0
; support_interface_bottom_layers = 2
; support_interface_filament = 0
; support_interface_loop_pattern = 0
; support_interface_not_for_body = 1
; support_interface_pattern = auto
; support_interface_spacing = 0.5
; support_interface_speed = 80
; support_interface_top_layers = 2
; support_line_width = 0.42
; support_object_first_layer_gap = 0.2
; support_object_skip_flush = 1
; support_object_xy_distance = 0.35
; support_on_build_plate_only = 0
; support_remove_small_overhang = 1
; support_speed = 150
; support_style = default
; support_threshold_angle = 30
; support_top_z_distance = 0.2
; support_type = tree(auto)
; symmetric_infill_y_axis = 0
; temperature_vitrification = 45
; template_custom_gcode = 
; textured_plate_temp = 55
; textured_plate_temp_initial_layer = 55
; thick_bridges = 0
; thumbnail_size = 50x50
; time_lapse_gcode = ;======== P2S timeslape gcode ==========\n;===== 2025/06/16 ====\n; SKIPPABLE_START\n; SKIPTYPE: timelapse\nM622.1 S1 ; for prev firware, default turned on\n\nM1002 judge_flag timelapse_record_flag\nM622 J1\n{if timelapse_type == 0} ; timelapse without wipe tower\n  M971 S11 C10 O0\n  M1004 S5 P1  ; external shutter\n{elsif timelapse_type == 1} ; timelapse with wipe tower\n  G150.3 ; move to garbage can\n  M400\n  M1004 S5 P1  ; external shutter\n  M400 P300\n  M971 S11 C10 O0\n  M400 P350\n  \n  G90\n  G1 Z{max_layer_z + 3.0} F1200\n  G0 Y210 F18000\n{endif}\nM623\n; SKIPPABLE_END\n
; timelapse_type = 0
; top_area_threshold = 200%
; top_color_penetration_layers = 5
; top_one_wall_type = all top
; top_shell_layers = 5
; top_shell_thickness = 1
; top_solid_infill_flow_ratio = 1
; top_surface_acceleration = 2000
; top_surface_jerk = 9
; top_surface_line_width = 0.42
; top_surface_pattern = monotonicline
; top_surface_speed = 200
; top_z_overrides_xy_distance = 0
; travel_acceleration = 10000
; travel_jerk = 9
; travel_speed = 600
; travel_speed_z = 0
; tree_support_branch_angle = 45
; tree_support_branch_diameter = 2
; tree_support_branch_diameter_angle = 5
; tree_support_branch_distance = 5
; tree_support_wall_count = -1
; upward_compatible_machine = "Bambu Lab A1 0.4 nozzle";"Bambu Lab H2S 0.4 nozzle";"Bambu Lab H2D 0.4 nozzle";"Bambu Lab H2D Pro 0.4 nozzle";"Bambu Lab H2C 0.4 nozzle"
; use_firmware_retraction = 0
; use_relative_e_distances = 1
; vertical_shell_speed = 80%
; volumetric_speed_coefficients = "0 0 0 0 0 0"
; wall_distribution_count = 1
; wall_filament = 0
; wall_generator = classic
; wall_loops = 5
; wall_sequence = inner wall/outer wall
; wall_transition_angle = 10
; wall_transition_filter_deviation = 25%
; wall_transition_length = 100%
; wipe = 1
; wipe_distance = 2
; wipe_speed = 80%
; wipe_tower_no_sparse_layers = 0
; wipe_tower_rotation_angle = 0
; wipe_tower_x = 165
; wipe_tower_y = 238
; wrapping_detection_gcode = ;======== P2S 20250822 clumping ========\n{if !spiral_mode}\n    M622.1 S0 ; for previous firmware, default turn off\n    M1002 set_flag g39_forced_detection_flag=1\n    M1002 judge_flag g39_forced_detection_flag\n    M622 J1\n        {if layer_num == 3 || layer_num == 10 || layer_num == 19}\n            M993 A2 B2 C2 ; nozzle cam detection allow status save.\n            M993 A0 B0 C0 ; nozzle cam detection not allowed.\n\n            M400 P100\n\n            G39\n\n            G90\n            G1 Y240 F30000\n            G1 Y210 F15000\n            \n            M993 A3 B3 C3 ; nozzle cam detection allow status restore.\n        {endif}\n    M623\n{endif}
; wrapping_detection_layers = 20
; wrapping_exclude_area = 153x256,216x256,216x235,153x235
; xy_contour_compensation = 0
; xy_hole_compensation = 0
; z_direction_outwall_speed_continuous = 0
; z_hop = 0.4
; z_hop_types = Auto Lift
; CONFIG_BLOCK_END

; EXECUTABLE_BLOCK_START
M73 P0 R14
M201 X20000 Y20000 Z500 E5000
M203 X600 Y600 Z20 E30
M204 P20000 R5000 T20000
M205 X9.00 Y9.00 Z3.00 E2.50
M106 S0
M106 P2 S0
; FEATURE: Custom
;M1002 set_flag extrude_cali_flag=1
;M1002 set_flag g29_before_print_flag=1
;M1002 set_flag auto_cali_toolhead_offset_flag=1
;M1002 set_flag build_plate_detect_flag=1

;======== P2S start gcode==========
;===== 2025/11/04 =====

  M140 S55 ; heat heatbed first
  M993 A0 B0 C0 ; nozzle cam detection not allowed.
  M400

;=====printer start sound ===================
M17
M400 S1
M1006 S1
M1006 A53 B9 L99 C53 D9 M99 E53 F9 N99 
M1006 A56 B9 L99 C56 D9 M99 E56 F9 N99 
M1006 A61 B9 L99 C61 D9 M99 E61 F9 N99 
M1006 A53 B9 L99 C53 D9 M99 E53 F9 N99 
M1006 A56 B9 L99 C56 D9 M99 E56 F9 N99 
M1006 A61 B18 L99 C61 D18 M99 E61 F18 N99 
M1006 W
;=====printer start sound ===================

  M620 M ;enable remap
  G389

;===== avoid end stop =================
  G91
  G380 S2 Z22 F1200
  G380 S2 Z-12 F1200
  G90
;===== avoid end stop =================

;===== reset machine status =================
  M204 S10000
  M630 S0 P1
  G90
  M17 D ; reset motor current to default
  M960 S5 P1 ; turn on logo lamp
  G90
  M220 S100 ;Reset Feedrate
  M1002 set_gcode_claim_speed_level: 5
  M221 S100 ;Reset Flowrate
  M73.2   R1.0 ;Reset left time magnitude
  G29.1 Z0 ; clear z-trim value first
  M983.1 M1
  M982.2 S1 ; turn on cog noise reduction
  M983.4 S0
;===== reset machine status =================

;==== set airduct mode ==== 
;==== if Chamber Cooling is necessary ====


M145 P0 ; set airduct mode to cooling mode for cooling
M106 P2 S255 ; turn on auxiliary fan for cooling
M1002 gcode_claim_action : 29
M191 S0 ; wait for chamber temp
M106 P2 S102 ; turn on chamber cooling fan
M106 P10 S0 ; turn off left aux fan


;==== set airduct mode ==== 

;===== start to heat heatbed & hotend==========
  M1002 gcode_claim_action : 2
  M1002 set_filament_type:PLA
  M104 S140 A        

  G29.2 S0 ; avoid invalid abl data

;===== first homing start =====
  M1002 gcode_claim_action : 13
  G28 X T300
  G150.3
  M972 S24 P0
  M972 S26 P0 C0
  M972 S42 P0 T5000
  G150.1 F8000 ; wipe mouth to avoid filament stick to heatbed
  G90
  G1 X128 Y128 F30000
  G28 Z P0 T400
  M400
;===== first homign end =====

;===== detection start =====
  M1002 gcode_claim_action : 11
  M104 S140 A ; rise temp in advance
  M972 S19 P0 T5000 ;plate type detection
;===== detection end =====

;===== prepare print temperature and material ==========
  M400
  M211 X0 Y0 Z0 ;turn off soft endstop
  M975 S1 ; turn on input shaping

  G29.2 S0 ; avoid invalid abl data
  G150.3

M620.10 A0 F523.843 H0.4 T240 P220 S1
M620.10 A1 F523.843 H0.4 T240 P220 S1


 M620.11 P0 L0 I0 E0
 M620.11 K0 I0 R0

  M620 S0A   ; switch material if AMS exist
  M1002 gcode_claim_action : 4
  M1002 set_filament_type:UNKNOWN
  M400
  T0
  M400
  M628 S0
  M629
  M400
  M1002 set_filament_type:PLA
  M621 S0A
  M104 S220
  M400
  M106 P1 S0
  M400
  G29.2 S1
;===== prepare print temperature and material ==========


;===== auto extrude cali start =========================
  M975 S1
  M1002 judge_flag extrude_cali_flag
  M622 J0
    M983.3 F8.75 A0.4 ; cali dynamic extrusion compensation
  M623

  M622 J1
    M1002 set_filament_type:PLA
    M1002 gcode_claim_action : 8
    M109 S220
    G90
    M83
    M983.3 F8.75 A0.4 ; cali dynamic extrusion compensation
    M400
    M106 P1 S255
    M400 S5
    M106 P1 S0
    G150.3
  M623

  M622 J2
    M1002 set_filament_type:PLA
    M1002 gcode_claim_action : 8
    M109 S220
    G90
    M83
    M983.3 F8.75 A0.4 ; cali dynamic extrusion compensation
    M400
    M106 P1 S255
    M400 S5
    M106 P1 S0
    G150.3
  M623
;===== auto extrude cali end =========================

  

  
    M83
    G1 E-3 F1800
    M400 P500
  
  G150.2
  G150.1 F8000
  G0 Z10 F1200
  G150.2
  G150.1 F8000
  G0 Z5 F1200
  G150.1 F8000

  G91
  G1 Y-16 F12000 ; move away from the trash bin
  G90
  M400

  M104 S140 A

;===== wipe right nozzle start =====
  M1002 gcode_claim_action : 14
  G150 T220
  M400


  M109 S140 A

  G91
M73 P9 R12
  G1 Z5 F1200
  G90
  M400
  G150.1
;===== wipe left nozzle end =====


;===== mech mode sweep start =====
  M1002 gcode_claim_action : 3
  G90
M73 P11 R12
  G1 X128 Y128 F20000
  G1 Z5 F1200
  M400 P200
  M970.3 Q1 A10 K0 O1
  M970.2 Q1 K1 W74 Z0.01
  M974 Q1 S2 P0
  M970.3 Q0 A10 K0 O1
  M970.2 Q0 K1 W74 Z0.01
  M974 Q0 S2 P0
  M975 S1
  M400
;===== mech mode sweep end =====

;===== bed leveling ==================================
  M1002 gcode_claim_action : 54
  M190 S55; ensure bed temp
  M109 S140 A
  M106 S0 ; turn off fan , too noisy
  M1002 judge_flag g29_before_print_flag
  M622 J1
    M1002 gcode_claim_action : 1
    
      G29 A1 X118 Y118.001 I19.9992 J19.9984
    
    M400
    M500 ; save cali data
  M623

  M622 J2
    M1002 gcode_claim_action : 1
    
      G29 A2 X118 Y118.001 I19.9992 J19.9984
    
    M400
    M500 ; save cali data
  M623

  M622 J0
    G28
  M623
  G29.2 S1

;===== bed leveling end ================================

  M985.1 U0 E2
  M985.1 U1 E2

  M104 S220 A
  G150.3 ; move to garbage can to wait for temp

;===== wait temperature reaching the reference value =======
  M190 S55 

  ;========turn off light and fans =============
  M960 S1 P0 ; turn off laser
  M960 S2 P0 ; turn off laser
  M106 S0 ; turn off cooling fan

;===== wait temperature reaching the reference value =======

  M1002 gcode_claim_action : 255
  M400
  M975 S1 ; turn on mech mode supression

;============switch again==================
  M211 X0 Y0 Z0 ;turn off soft endstop
  G91
  G1 Z6 F1200
  G90
  M1002 set_filament_type:PLA
  M620 S0A
  M400
  T0
  M400
  M628 S0
  M629
  M400
  M621 S0A
;============switch again==================

;===== for Textured PEI Plate , lower the nozzle as the nozzle was touching topmost of the texture when homing ==
  
    G29.1 Z0.01 ; for Textured PEI Plate
  

;===== nozzle load line ===============================
M1002 gcode_claim_action : 51
  G29.2 S1 ; ensure z comp turn on
  G90
  M83
  M109 S220
  G130 O0 X100 Y-0.4 Z0.8 F4.36536 L40 E20 D5
  ;G130 O0 X100 Y-0.2 Z0.6 F4.36536 L40 E12 D4
  G90
  M83
  G1 Z0.2
  M400
;===== noozle load line end ===========================
M1002 gcode_claim_action : 0
  G29.99


M1015.3 S1 H0.4;enable tpu, pla and petg clog detect



M1015.4 S1 K1 H0.4 ;enable E air printing detect


M620.6 I0 W1 ;enable ams air printing detect

M1010 Q0 B0.023 S0.01
M1010 Q1 B0.005 S0.01
M1010.1 S1
; MACHINE_START_GCODE_END
; filament start gcode
;VT0
G90
G21
M83 ; use relative distances for extrusion
M981 S1 P20000 ;open spaghetti detector
; CHANGE_LAYER
; Z_HEIGHT: 0.2
; LAYER_HEIGHT: 0.2
G1 E-.8 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====



        






; update layer progress
M73 L1
M991 S0 P0 ;notify layer change


M106 S0
M106 P2 S102
M204 S6000
G1 Z.4 F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.877 Y135.541
M73 P55 R6
G1 Z.2
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.5
G1 F2921
M204 S500
G1 X123.733 Y135.459 E.00616
G3 X127.828 Y119.401 I4.267 J-7.463 E.8332
G1 X128.172 Y119.401 E.01282
G3 X124.338 Y135.773 I-.172 J8.595 E1.1404
G1 X123.93 Y135.568 E.017
; WIPE_START
G1 F3000
G1 X123.733 Y135.459 E-.08559
G1 X123.142 Y135.096 E-.26369
G1 X122.595 Y134.688 E-.2592
G1 X122.295 Y134.425 E-.15152
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X129.923 Y134.153 Z.6 F36000
G1 X135.53 Y133.953 Z.6
G1 Z.2
G1 E.8 F1800
G1 F2921
M204 S500
G1 X135.338 Y134.177 E.01099
G3 X127.826 Y118.401 I-7.341 J-6.181 E1.42789
G1 X128.181 Y118.401 E.01322
G3 X135.561 Y133.902 I-.184 J9.595 E.79155
G1 X135.561 Y133.902 E.00001
M204 S6000
G1 X135.163 Y133.596 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.585752
G1 F2921
M204 S500
G1 X134.96 Y133.859 E.01469
G3 X118.901 Y128.102 I-6.96 J-5.86 E.97822
G1 X118.901 Y128.091 E.00047
G1 X118.904 Y127.752 E.01501
G3 X135.459 Y133.209 I9.096 J.247 E1.49892
G1 X135.199 Y133.549 E.01891
; CHANGE_LAYER
; Z_HEIGHT: 0.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X134.96 Y133.859 E-.14898
G1 X134.538 Y134.328 E-.2396
G1 X134.287 Y134.578 E-.13469
G1 X133.819 Y134.989 E-.23673
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====





    ;updata chamber autocooling in Xth layer
    
        
            M142 P1 R30 S40 U0.7 V1.0 O45; set PLA/TPU ND0.4 chamber autocooling
        
    
    M106 P10 S178.5; set left aux fan 

;not reset fan



; update layer progress
M73 L2
M991 S0 P1 ;notify layer change


M106 S255
; open powerlost recovery
M1003 S1
M204 S10000
G17
G3 Z.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.611 Y135.629
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4510
G1 X123.031 Y135.257 E.02285
G3 X127.824 Y119.199 I4.969 J-7.261 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.666 Y135.653 I-.176 J8.797 E1.06143
G1 X123.95 Y135.368 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4510
M204 S6000
G1 X123.822 Y135.291 E.00459
G3 X127.832 Y119.591 I4.178 J-7.295 E.67201
G1 X128.168 Y119.591 E.01034
G3 X124.118 Y135.452 I-.168 J8.405 E.93035
G1 X124.004 Y135.395 E.00391
; WIPE_START
G1 F12000
M204 S10000
G1 X123.822 Y135.291 E-.07948
M73 P56 R6
G1 X123.249 Y134.939 E-.25565
G1 X122.724 Y134.548 E-.24898
G1 X122.375 Y134.243 E-.17589
; WIPE_END
G1 E-.04 F1800
G1 X130.004 Y133.997 Z.8 F36000
G1 X135.374 Y133.824 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4510
G1 X135.185 Y134.04 E.00954
G3 X127.829 Y118.603 I-7.192 J-6.044 E1.24536
G1 X128.189 Y118.604 E.01195
G3 X135.402 Y133.771 I-.197 J9.393 E.68929
G1 X135.679 Y134.071 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4510
M204 S6000
G1 X135.488 Y134.295 E.00906
G3 X127.822 Y118.211 I-7.496 J-6.296 E1.20215
G1 X128.197 Y118.212 E.0115
G3 X135.711 Y134.019 I-.205 J9.787 E.66542
G1 X135.711 Y134.02 E.00004
M204 S10000
G1 X135.155 Y133.607 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231595
G1 F4510
G1 X135.016 Y133.79 E.00354
G3 X118.901 Y128.111 I-7.017 J-5.793 E.34121
G1 X118.901 Y128.107 E.00006
G1 X118.901 Y128.082 E.00038
G3 X135.558 Y133.063 I9.099 J-.084 E.52337
G1 X135.191 Y133.558 E.00949
; CHANGE_LAYER
; Z_HEIGHT: 0.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.016 Y133.79 E-.11039
G1 X134.522 Y134.345 E-.28234
G1 X134.27 Y134.594 E-.13448
G1 X133.811 Y135 E-.23279
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L3
M991 S0 P2 ;notify layer change


G17
G3 Z.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.611 Y135.629
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4483
G1 X123.031 Y135.257 E.02285
G3 X127.824 Y119.199 I4.969 J-7.261 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.665 Y135.653 I-.176 J8.797 E1.06143
G1 X123.937 Y135.361 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4483
M204 S6000
G1 X123.822 Y135.291 E.00411
G3 X127.832 Y119.591 I4.178 J-7.295 E.672
G1 X128.168 Y119.591 E.01034
G3 X124.118 Y135.452 I-.168 J8.405 E.93035
G1 X123.99 Y135.388 E.00439
; WIPE_START
G1 F12000
M204 S10000
G1 X123.822 Y135.291 E-.0736
G1 X123.249 Y134.939 E-.25566
G1 X122.733 Y134.555 E-.24444
G1 X122.364 Y134.232 E-.1863
; WIPE_END
G1 E-.04 F1800
G1 X129.992 Y133.992 Z1 F36000
G1 X135.376 Y133.822 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4483
G1 X135.188 Y134.043 E.00963
G3 X127.488 Y118.615 I-7.195 J-6.044 E1.23435
G3 X128.202 Y118.604 I.5 J9.056 E.02369
G3 X135.408 Y133.771 I-.209 J9.395 E.68891
G1 X135.68 Y134.069 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4483
M204 S6000
G1 X135.488 Y134.295 E.00913
G3 X127.467 Y118.224 I-7.495 J-6.297 E1.19109
G3 X128.21 Y118.212 I.521 J9.428 E.02284
G3 X135.713 Y134.018 I-.216 J9.787 E.66503
M204 S10000
G1 X135.157 Y133.604 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231615
G1 F4483
G1 X135.018 Y133.793 E.0036
G3 X118.901 Y128.123 I-7.018 J-5.791 E.34116
G1 X118.901 Y128.119 E.00005
G1 X118.901 Y128.082 E.00057
G3 X135.561 Y133.063 I9.099 J-.08 E.52328
G1 X135.193 Y133.556 E.00947
; CHANGE_LAYER
; Z_HEIGHT: 0.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.018 Y133.793 E-.11167
G1 X134.523 Y134.345 E-.28181
G1 X134.265 Y134.599 E-.13771
G1 X133.814 Y134.998 E-.22881
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L4
M991 S0 P3 ;notify layer change


G17
G3 Z1 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4483
G1 X123.031 Y135.257 E.02288
G3 X127.824 Y119.199 I4.969 J-7.261 E.73593
G1 X128.176 Y119.199 E.01169
G3 X123.666 Y135.653 I-.176 J8.797 E1.0614
G1 X123.923 Y135.351 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4483
M204 S6000
G1 X123.823 Y135.291 E.00358
G3 X127.832 Y119.591 I4.177 J-7.295 E.67202
G1 X128.168 Y119.591 E.01034
G3 X124.419 Y135.601 I-.168 J8.405 E.92002
G1 X123.977 Y135.378 E.01523
; WIPE_START
G1 F12000
M204 S10000
G1 X123.823 Y135.291 E-.06709
M73 P57 R6
G1 X123.249 Y134.939 E-.25584
G1 X122.71 Y134.537 E-.25561
G1 X122.452 Y134.32 E-.12796
G1 X122.35 Y134.223 E-.05351
; WIPE_END
G1 E-.04 F1800
G1 X129.979 Y133.987 Z1.2 F36000
G1 X135.378 Y133.82 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4483
G1 X135.187 Y134.042 E.00972
G3 X127.488 Y118.615 I-7.196 J-6.043 E1.23448
G3 X128.215 Y118.605 I.497 J8.989 E.02411
G3 X135.408 Y133.768 I-.224 J9.394 E.68827
G1 X135.682 Y134.066 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4483
M204 S6000
G1 X135.487 Y134.294 E.00922
G3 X127.467 Y118.224 I-7.496 J-6.295 E1.19121
G3 X128.222 Y118.212 I.518 J9.35 E.02323
G3 X135.713 Y134.015 I-.232 J9.786 E.66443
M204 S10000
G1 X135.163 Y133.595 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231592
G1 F4483
G1 X134.967 Y133.857 E.00503
G3 X118.901 Y128.092 I-6.968 J-5.851 E.34044
G1 X118.9 Y128.088 E.00006
G3 X118.946 Y127.092 I10.311 J-.026 E.01534
G3 X135.482 Y133.182 I9.053 J.914 E.51004
G1 X135.2 Y133.548 E.00711
; CHANGE_LAYER
; Z_HEIGHT: 1
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.967 Y133.857 E-.14711
G1 X134.532 Y134.335 E-.24565
G1 X134.287 Y134.578 E-.13103
G1 X133.82 Y134.988 E-.23622
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L5
M991 S0 P4 ;notify layer change


G17
G3 Z1.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4483
G1 X123.031 Y135.257 E.02287
G3 X127.824 Y119.199 I4.969 J-7.261 E.73593
G1 X128.176 Y119.199 E.01169
G3 X123.666 Y135.653 I-.176 J8.797 E1.06142
G1 X123.908 Y135.343 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4483
M204 S6000
G1 X123.822 Y135.291 E.00308
G3 X127.832 Y119.591 I4.178 J-7.295 E.672
G1 X128.168 Y119.591 E.01034
G3 X124.419 Y135.602 I-.168 J8.405 E.92002
G1 X123.962 Y135.37 E.01574
; WIPE_START
G1 F12000
M204 S10000
G1 X123.822 Y135.291 E-.06089
G1 X123.249 Y134.939 E-.25567
G1 X122.71 Y134.537 E-.25566
G1 X122.452 Y134.32 E-.12796
G1 X122.338 Y134.211 E-.05982
; WIPE_END
G1 E-.04 F1800
G1 X129.967 Y133.981 Z1.4 F36000
G1 X135.379 Y133.817 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4483
G1 X135.185 Y134.04 E.00982
G3 X127.148 Y118.64 I-7.192 J-6.044 E1.22271
G3 X128.227 Y118.605 I.869 J10.108 E.03583
G3 X135.408 Y133.765 I-.235 J9.392 E.68775
G1 X135.684 Y134.064 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4483
M204 S6000
G1 X135.485 Y134.293 E.00931
G3 X127.112 Y118.25 I-7.492 J-6.296 E1.17985
G3 X128.235 Y118.213 I.906 J10.542 E.03454
G3 X135.712 Y134.011 I-.243 J9.784 E.66393
M204 S10000
G1 X135.16 Y133.6 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231596
G1 F4483
G1 X135.019 Y133.794 E.00368
G3 X118.901 Y128.092 I-7.02 J-5.789 E.34167
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.754 E.00515
G3 X135.562 Y133.064 I9.096 J.251 E.51813
G1 X135.196 Y133.552 E.00938
; CHANGE_LAYER
; Z_HEIGHT: 1.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.11375
G1 X134.523 Y134.344 E-.2815
G1 X134.246 Y134.616 E-.14747
G1 X133.817 Y134.994 E-.21727
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L6
M991 S0 P5 ;notify layer change


G17
G3 Z1.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.611 Y135.629
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4483
G1 X123.031 Y135.257 E.02286
G3 X127.824 Y119.199 I4.969 J-7.261 E.73593
G1 X128.176 Y119.199 E.01169
G3 X123.665 Y135.653 I-.176 J8.797 E1.06143
G1 X123.892 Y135.336 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4483
M204 S6000
G1 X123.822 Y135.291 E.00257
G3 X127.832 Y119.591 I4.178 J-7.295 E.672
G1 X128.168 Y119.591 E.01034
M73 P58 R6
G3 X124.118 Y135.453 I-.168 J8.405 E.93032
G1 X123.946 Y135.364 E.00596
; WIPE_START
G1 F12000
M204 S10000
G1 X123.822 Y135.291 E-.05446
G1 X123.249 Y134.939 E-.25567
G1 X122.71 Y134.537 E-.2556
G1 X122.452 Y134.32 E-.12796
G1 X122.326 Y134.2 E-.06632
; WIPE_END
G1 E-.04 F1800
G1 X129.955 Y133.975 Z1.6 F36000
G1 X135.381 Y133.815 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4483
G1 X135.187 Y134.042 E.00991
G3 X127.148 Y118.64 I-7.196 J-6.043 E1.22317
G3 X128.24 Y118.605 I.865 J10.052 E.03625
G3 X135.412 Y133.764 I-.248 J9.394 E.68727
G1 X135.686 Y134.062 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4483
M204 S6000
G1 X135.488 Y134.295 E.00939
G3 X127.112 Y118.25 I-7.496 J-6.295 E1.18032
G3 X128.248 Y118.213 I.902 J10.477 E.03493
G3 X135.717 Y134.011 I-.257 J9.786 E.66349
M204 S10000
G1 X135.162 Y133.598 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231586
G1 F4483
G1 X135.019 Y133.794 E.00373
M73 P58 R5
G3 X118.901 Y128.092 I-7.02 J-5.789 E.34165
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.754 E.00514
G3 X135.562 Y133.064 I9.096 J.251 E.51811
G1 X135.198 Y133.55 E.00933
; CHANGE_LAYER
; Z_HEIGHT: 1.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.115
G1 X134.523 Y134.344 E-.28134
G1 X134.237 Y134.624 E-.15231
G1 X133.82 Y134.992 E-.21135
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L7
M991 S0 P6 ;notify layer change


G17
G3 Z1.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.611 Y135.629
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4483
G1 X123.031 Y135.257 E.02286
G3 X127.824 Y119.199 I4.969 J-7.261 E.73593
G1 X128.176 Y119.199 E.01169
G3 X123.666 Y135.653 I-.176 J8.797 E1.06143
G1 X123.877 Y135.328 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4483
M204 S6000
G1 X123.822 Y135.291 E.00201
G3 X127.832 Y119.591 I4.178 J-7.295 E.67201
G1 X128.168 Y119.591 E.01034
G3 X124.118 Y135.453 I-.168 J8.405 E.93032
G1 X123.93 Y135.355 E.00652
; WIPE_START
G1 F12000
M204 S10000
G1 X123.822 Y135.291 E-.04762
G1 X123.249 Y134.939 E-.25571
G1 X122.71 Y134.537 E-.2556
G1 X122.452 Y134.32 E-.12796
G1 X122.313 Y134.187 E-.07311
; WIPE_END
G1 E-.04 F1800
G1 X129.942 Y133.967 Z1.8 F36000
G1 X135.384 Y133.811 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4483
G1 X135.133 Y134.104 E.01282
G3 X127.148 Y118.64 I-7.143 J-6.105 E1.22049
G3 X128.253 Y118.606 I.862 J9.999 E.03667
G3 X135.415 Y133.759 I-.262 J9.393 E.6866
G1 X135.687 Y134.06 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4483
M204 S6000
G1 X135.432 Y134.357 E.01205
G3 X127.112 Y118.25 I-7.442 J-6.359 E1.17774
G3 X128.261 Y118.214 I.898 J10.42 E.03533
G3 X135.717 Y134.008 I-.271 J9.785 E.66294
M204 S10000
G1 X135.17 Y133.583 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231582
G1 F4483
G1 X134.917 Y133.921 E.00649
G3 X118.901 Y128.092 I-6.917 J-5.913 E.33926
G1 X118.9 Y128.088 E.00006
G3 X118.923 Y127.368 I10.154 J-.047 E.01109
G3 X135.462 Y133.217 I9.077 J.64 E.5149
G1 X135.208 Y133.536 E.00628
; CHANGE_LAYER
; Z_HEIGHT: 1.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.917 Y133.921 E-.18327
G1 X134.287 Y134.578 E-.34586
G1 X133.83 Y134.979 E-.23087
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L8
M991 S0 P7 ;notify layer change


G17
G3 Z1.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.638 Y135.644
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4468
G1 X123.626 Y135.635 E.00049
G3 X127.824 Y119.199 I4.375 J-7.637 E.75946
G3 X135.461 Y132.666 I.165 J8.806 E.62736
G3 X124.25 Y135.96 I-7.461 J-4.668 E.42389
G1 X123.691 Y135.671 E.02087
G1 X123.861 Y135.318 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4468
M204 S6000
G1 X123.82 Y135.295 E.00143
G3 X127.832 Y119.591 I4.18 J-7.297 E.67217
M73 P59 R5
G3 X128.748 Y119.624 I.131 J9.11 E.0282
G1 X128.84 Y119.631 E.00282
G3 X124.417 Y135.606 I-.84 J8.367 E.89965
G1 X123.914 Y135.346 E.0174
; WIPE_START
G1 F12000
M204 S10000
G1 X123.82 Y135.295 E-.04054
G1 X123.249 Y134.939 E-.25572
G1 X122.71 Y134.537 E-.25571
G1 X122.452 Y134.32 E-.1279
G1 X122.299 Y134.175 E-.08013
; WIPE_END
G1 E-.04 F1800
G1 X129.929 Y133.962 Z2 F36000
G1 X135.385 Y133.811 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4468
G1 X135.186 Y134.042 E.01011
G3 X127.148 Y118.64 I-7.196 J-6.043 E1.22322
G3 X128.257 Y118.606 I.999 J14.494 E.0368
G3 X135.415 Y133.759 I-.267 J9.393 E.68645
G1 X135.69 Y134.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4468
M204 S6000
G1 X135.486 Y134.294 E.00958
G3 X127.112 Y118.25 I-7.497 J-6.295 E1.18035
G3 X128.271 Y118.214 I1.037 J15.006 E.03562
G3 X135.719 Y134.005 I-.281 J9.785 E.66252
M204 S10000
G1 X135.165 Y133.593 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231536
G1 F4468
G1 X135.019 Y133.794 E.00382
G3 X118.901 Y128.092 I-7.019 J-5.791 E.34155
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.562 Y133.065 I9.096 J.252 E.51801
G1 X135.201 Y133.545 E.00924
; CHANGE_LAYER
; Z_HEIGHT: 1.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.11715
G1 X134.522 Y134.345 E-.28216
G1 X134.27 Y134.594 E-.1344
G1 X133.824 Y134.989 E-.22629
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L9
M991 S0 P8 ;notify layer change


G17
G3 Z2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.628 Y135.631
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4457
G1 X123.323 Y135.454 E.01168
G3 X127.824 Y119.199 I4.678 J-7.455 E.74774
G3 X126.015 Y136.573 I.171 J8.799 E.98903
G3 X123.935 Y135.804 I1.986 J-8.575 E.07378
G1 X123.68 Y135.66 E.0097
G1 X123.844 Y135.31 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4457
M204 S6000
G1 X123.822 Y135.291 E.00088
G3 X127.832 Y119.591 I4.178 J-7.295 E.672
G1 X128.168 Y119.591 E.01034
G3 X124.118 Y135.452 I-.168 J8.405 E.93034
G1 X123.897 Y135.338 E.00763
; WIPE_START
G1 F12000
M204 S10000
G1 X123.822 Y135.291 E-.03353
G1 X123.249 Y134.939 E-.25571
G1 X122.71 Y134.537 E-.25566
G1 X122.452 Y134.32 E-.1279
G1 X122.286 Y134.162 E-.08721
; WIPE_END
G1 E-.04 F1800
G1 X129.916 Y133.956 Z2.2 F36000
G1 X135.387 Y133.808 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4457
G1 X135.186 Y134.041 E.0102
G3 X127.148 Y118.64 I-7.197 J-6.042 E1.22327
G3 X128.27 Y118.606 I.986 J14.188 E.03723
G3 X135.416 Y133.756 I-.28 J9.393 E.68589
G1 X135.687 Y134.051 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4457
M204 S6000
G1 X135.492 Y134.298 E.00967
G3 X118.238 Y127.272 I-7.492 J-6.299 E.757
G3 X128.284 Y118.215 I9.762 J.728 E.4588
G3 X135.929 Y133.738 I-.284 J9.784 E.65216
G1 X135.724 Y134.004 E.01033
M204 S10000
G1 X135.174 Y133.582 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4457
G1 X134.966 Y133.856 E.00529
G3 X118.901 Y128.092 I-6.967 J-5.853 E.3404
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.457 Y133.217 I9.096 J.252 E.52101
G1 X135.211 Y133.535 E.00618
; CHANGE_LAYER
; Z_HEIGHT: 2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.966 Y133.856 E-.15355
G1 X134.532 Y134.335 E-.24571
G1 X134.287 Y134.578 E-.13099
G1 X133.833 Y134.977 E-.22975
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L10
M991 S0 P9 ;notify layer change


G17
G3 Z2.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4468
G1 X123.03 Y135.259 E.02286
G3 X127.824 Y119.199 I4.977 J-7.26 E.73574
G3 X126.027 Y136.576 I.171 J8.799 E.98864
G3 X123.665 Y135.656 I1.981 J-8.577 E.08438
G1 X123.827 Y135.301 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4468
M204 S6000
G1 X123.822 Y135.291 E.00033
G3 X127.832 Y119.591 I4.178 J-7.295 E.67201
M73 P60 R5
G1 X128.168 Y119.591 E.01034
G3 X124.118 Y135.452 I-.168 J8.405 E.93035
G1 X123.88 Y135.329 E.00822
; WIPE_START
G1 F12000
M204 S10000
G1 X123.822 Y135.291 E-.02624
G1 X123.249 Y134.939 E-.25566
G1 X122.71 Y134.537 E-.25566
G1 X122.452 Y134.32 E-.12796
G1 X122.272 Y134.148 E-.09449
; WIPE_END
G1 E-.04 F1800
G1 X129.902 Y133.949 Z2.4 F36000
G1 X135.389 Y133.806 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4468
G1 X135.188 Y134.043 E.0103
G3 X126.808 Y118.677 I-7.196 J-6.043 E1.21187
G3 X128.282 Y118.607 I1.195 J9.582 E.049
G3 X135.42 Y133.755 I-.291 J9.393 E.68546
G1 X135.693 Y134.053 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4468
M204 S6000
G1 X135.488 Y134.295 E.00976
G3 X126.759 Y118.288 I-7.497 J-6.295 E1.1694
G3 X128.297 Y118.215 I1.245 J9.98 E.04736
G3 X135.724 Y134.001 I-.306 J9.784 E.66161
M204 S10000
G1 X135.175 Y133.58 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4468
G1 X134.966 Y133.856 E.00532
G3 X118.901 Y128.092 I-6.967 J-5.853 E.3404
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.459 Y133.213 I9.095 J.252 E.52093
G1 X135.212 Y133.533 E.00621
; CHANGE_LAYER
; Z_HEIGHT: 2.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.966 Y133.856 E-.15437
G1 X134.532 Y134.335 E-.2457
G1 X134.287 Y134.578 E-.13102
G1 X133.834 Y134.976 E-.22891
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L11
M991 S0 P10 ;notify layer change


G17
G3 Z2.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4463
G1 X123.03 Y135.259 E.02286
G3 X127.824 Y119.199 I4.977 J-7.26 E.73574
G3 X126.038 Y136.578 I.171 J8.799 E.98825
G3 X123.665 Y135.656 I1.969 J-8.579 E.08476
G1 X123.811 Y135.291 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4463
M204 S6000
G1 X123.253 Y134.934 E.02037
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G3 X128.714 Y119.621 I.132 J9.032 E.02712
G1 X128.84 Y119.631 E.00389
G3 X123.865 Y135.315 I-.84 J8.365 E.91852
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.27393
G1 X122.71 Y134.537 E-.25563
G1 X122.452 Y134.32 E-.1279
G1 X122.257 Y134.134 E-.10254
; WIPE_END
G1 E-.04 F1800
G1 X129.887 Y133.942 Z2.6 F36000
G1 X135.391 Y133.803 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4463
G1 X135.187 Y134.042 E.01041
G3 X126.808 Y118.677 I-7.196 J-6.043 E1.21182
G3 X128.295 Y118.607 I1.194 J9.565 E.04943
G3 X135.421 Y133.752 I-.304 J9.392 E.6849
G1 X135.691 Y134.046 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4463
M204 S6000
G1 X135.492 Y134.298 E.00986
G3 X118.434 Y130.073 I-7.492 J-6.299 E.6704
G3 X118.241 Y127.246 I9.913 J-2.098 E.08737
G3 X128.31 Y118.216 I9.76 J.754 E.45879
G3 X135.929 Y133.738 I-.31 J9.784 E.65136
G1 X135.728 Y133.999 E.01014
M204 S10000
G1 X135.171 Y133.585 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4463
G1 X135.02 Y133.794 E.00397
G3 X118.901 Y128.092 I-7.02 J-5.791 E.34169
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.563 Y133.065 I9.096 J.252 E.5182
G1 X135.207 Y133.537 E.00909
; CHANGE_LAYER
; Z_HEIGHT: 2.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.02 Y133.794 E-.12099
G1 X134.522 Y134.345 E-.28225
G1 X134.27 Y134.594 E-.13434
G1 X133.832 Y134.982 E-.22242
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L12
M991 S0 P11 ;notify layer change


G17
G3 Z2.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4463
G1 X123.03 Y135.259 E.02286
G3 X127.824 Y119.199 I4.977 J-7.26 E.73574
G3 X135.295 Y132.922 I.166 J8.805 E.63748
G3 X126.05 Y136.581 I-7.306 J-4.952 E.35035
G3 X123.665 Y135.656 I1.958 J-8.582 E.08515
G1 X123.794 Y135.281 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4463
M204 S6000
G1 X123.253 Y134.934 E.01976
G3 X127.832 Y119.591 I4.748 J-6.938 E.65132
M73 P61 R5
G3 X129.037 Y119.655 I-.01 J11.547 E.03709
G1 X129.174 Y119.672 E.00426
G3 X123.848 Y135.306 I-1.174 J8.324 E.90875
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.26686
G1 X122.71 Y134.537 E-.25552
G1 X122.452 Y134.32 E-.12802
G1 X122.243 Y134.121 E-.1096
; WIPE_END
G1 E-.04 F1800
G1 X129.873 Y133.935 Z2.8 F36000
G1 X135.393 Y133.801 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4463
G1 X135.187 Y134.042 E.01052
G3 X126.808 Y118.677 I-7.197 J-6.043 E1.21189
G3 X128.308 Y118.608 I1.193 J9.552 E.04986
G3 X135.423 Y133.75 I-.318 J9.392 E.68437
G1 X135.693 Y134.044 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4463
M204 S6000
G1 X135.489 Y134.296 E.00996
G3 X125.506 Y118.534 I-7.489 J-6.299 E1.12925
G3 X128.323 Y118.216 I2.494 J9.472 E.08739
G3 X135.926 Y133.736 I-.323 J9.781 E.65084
G1 X135.729 Y133.996 E.01004
M204 S10000
G1 X135.173 Y133.582 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4463
G1 X135.019 Y133.794 E.00402
G3 X118.901 Y128.092 I-7.019 J-5.791 E.34168
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.562 Y133.065 I9.096 J.252 E.5182
G1 X135.209 Y133.535 E.00904
; CHANGE_LAYER
; Z_HEIGHT: 2.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.12223
G1 X134.522 Y134.346 E-.2823
G1 X134.27 Y134.594 E-.13427
G1 X133.834 Y134.98 E-.22121
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L13
M991 S0 P12 ;notify layer change


G17
G3 Z2.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4464
G1 X123.03 Y135.259 E.02286
G3 X122.208 Y121.373 I4.979 J-7.262 E.53194
G3 X127.824 Y119.199 I5.8 J6.639 E.20386
G3 X126.061 Y136.583 I.175 J8.799 E.98784
G3 X123.665 Y135.655 I1.948 J-8.587 E.08554
G1 X123.777 Y135.27 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4464
M204 S6000
G1 X123.25 Y134.938 E.01914
G3 X127.832 Y119.591 I4.75 J-6.939 E.65149
G3 X128.69 Y119.619 I.132 J9.01 E.0264
G1 X128.84 Y119.631 E.00461
G3 X123.829 Y135.3 I-.84 J8.367 E.92003
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.938 E-.25943
G1 X122.71 Y134.537 E-.25564
G1 X122.452 Y134.32 E-.12796
G1 X122.229 Y134.108 E-.11698
; WIPE_END
G1 E-.04 F1800
G1 X129.86 Y133.928 Z3 F36000
G1 X135.395 Y133.798 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4464
G1 X135.187 Y134.042 E.01062
G3 X126.808 Y118.677 I-7.197 J-6.043 E1.2119
G3 X128.321 Y118.608 I1.192 J9.543 E.05029
G3 X135.425 Y133.747 I-.331 J9.391 E.68383
G1 X135.695 Y134.041 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4464
M204 S6000
G1 X135.492 Y134.298 E.01006
G3 X118.243 Y127.22 I-7.492 J-6.299 E.75858
G3 X118.752 Y124.791 I10.388 J.911 E.07644
G3 X125.519 Y118.53 I9.276 J3.239 E.29484
G3 X128.336 Y118.217 I2.481 J9.472 E.08739
G3 X135.929 Y133.738 I-.336 J9.783 E.65057
G1 X135.732 Y133.994 E.00994
M204 S10000
G1 X135.175 Y133.58 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4464
G1 X135.019 Y133.794 E.00407
G3 X118.901 Y128.092 I-7.019 J-5.791 E.34168
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.562 Y133.065 I9.096 J.252 E.5182
G1 X135.211 Y133.532 E.00899
; CHANGE_LAYER
; Z_HEIGHT: 2.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.12344
G1 X134.522 Y134.345 E-.28216
G1 X134.27 Y134.594 E-.13441
G1 X133.837 Y134.978 E-.21999
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L14
M991 S0 P13 ;notify layer change


G17
G3 Z3 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4458
G1 X123.029 Y135.261 E.02286
G3 X127.824 Y119.199 I4.972 J-7.262 E.73605
G3 X126.072 Y136.586 I.175 J8.799 E.98746
G3 X123.664 Y135.657 I1.929 J-8.587 E.08592
G1 X123.759 Y135.259 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4458
M204 S6000
G1 X123.253 Y134.934 E.01849
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
M73 P62 R5
G3 X129.013 Y119.652 I-.015 J11.711 E.03637
G1 X129.174 Y119.672 E.00498
G3 X123.822 Y135.291 I-1.174 J8.324 E.90967
G1 X123.813 Y135.286 E.00033
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.25141
G1 X122.71 Y134.537 E-.25569
G1 X122.452 Y134.32 E-.12796
G1 X122.214 Y134.093 E-.12494
; WIPE_END
G1 E-.04 F1800
G1 X129.844 Y133.919 Z3.2 F36000
G1 X135.4 Y133.792 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4458
G1 X135.081 Y134.167 E.01631
G3 X126.808 Y118.677 I-7.09 J-6.167 E1.20646
G3 X128.334 Y118.609 I1.192 J9.537 E.05072
G3 X135.429 Y133.742 I-.344 J9.391 E.68316
G1 X135.697 Y134.039 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4458
M204 S6000
G1 X135.488 Y134.295 E.01016
G3 X118.244 Y127.207 I-7.49 J-6.298 E.75875
G3 X128.348 Y118.217 I9.768 J.805 E.45864
G3 X135.926 Y133.735 I-.35 J9.78 E.64999
G1 X135.733 Y133.991 E.00983
M204 S10000
G1 X135.184 Y133.57 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4458
G1 X134.967 Y133.857 E.00553
G3 X118.901 Y128.092 I-6.967 J-5.854 E.34042
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.458 Y133.218 I9.096 J.252 E.52105
G1 X135.221 Y133.522 E.00593
; CHANGE_LAYER
; Z_HEIGHT: 3
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.967 Y133.857 E-.15959
G1 X134.532 Y134.335 E-.2457
G1 X134.287 Y134.578 E-.13106
G1 X133.845 Y134.966 E-.22365
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L15
M991 S0 P14 ;notify layer change


G17
G3 Z3.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4458
G1 X123.029 Y135.261 E.02287
G3 X127.824 Y119.199 I4.972 J-7.262 E.73605
G3 X126.084 Y136.588 I.176 J8.799 E.9871
G3 X123.664 Y135.657 I1.917 J-8.59 E.08631
G1 X123.742 Y135.248 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4458
M204 S6000
G1 X123.253 Y134.934 E.01787
G3 X127.832 Y119.591 I4.748 J-6.938 E.65132
G3 X129.002 Y119.651 I-.018 J11.811 E.03601
G1 X129.174 Y119.672 E.00534
G3 X123.822 Y135.291 I-1.174 J8.324 E.90967
G1 X123.795 Y135.276 E.00096
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.24368
G1 X122.71 Y134.537 E-.25557
G1 X122.452 Y134.32 E-.1279
G1 X122.199 Y134.079 E-.13285
; WIPE_END
G1 E-.04 F1800
G1 X129.83 Y133.914 Z3.4 F36000
G1 X135.399 Y133.793 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4458
G1 X135.187 Y134.042 E.01083
G3 X126.808 Y118.677 I-7.197 J-6.042 E1.2119
G3 X128.347 Y118.609 I1.192 J9.535 E.05115
G3 X135.429 Y133.743 I-.356 J9.39 E.68278
G1 X135.699 Y134.036 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4458
M204 S6000
G1 X135.492 Y134.299 E.01026
G3 X118.423 Y130.023 I-7.492 J-6.299 E.67199
G3 X128.361 Y118.217 I9.587 J-2.015 E.546
G3 X135.929 Y133.738 I-.361 J9.782 E.64978
G1 X135.736 Y133.989 E.00973
M204 S10000
G1 X135.179 Y133.575 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4458
G1 X135.02 Y133.794 E.00417
G3 X118.901 Y128.092 I-7.02 J-5.791 E.34168
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.563 Y133.064 I9.096 J.252 E.51819
G1 X135.215 Y133.527 E.00889
; CHANGE_LAYER
; Z_HEIGHT: 3.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.02 Y133.794 E-.12582
G1 X134.522 Y134.345 E-.28237
G1 X134.27 Y134.594 E-.13434
G1 X133.842 Y134.973 E-.21748
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L16
M991 S0 P15 ;notify layer change


G17
G3 Z3.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4458
G1 X123.03 Y135.259 E.02286
G3 X127.824 Y119.199 I4.977 J-7.26 E.73574
G3 X126.095 Y136.591 I.175 J8.799 E.98668
G3 X123.665 Y135.656 I1.912 J-8.592 E.08669
G1 X123.724 Y135.237 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4458
M204 S6000
G1 X123.253 Y134.934 E.01722
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
M73 P63 R5
G3 X128.655 Y119.616 I.132 J9.037 E.02533
G1 X128.84 Y119.631 E.00569
G3 X123.822 Y135.291 I-.84 J8.365 E.92002
G1 X123.777 Y135.266 E.0016
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.23569
G1 X122.71 Y134.537 E-.25557
G1 X122.452 Y134.32 E-.12796
G1 X122.184 Y134.065 E-.14078
; WIPE_END
G1 E-.04 F1800
G1 X129.815 Y133.906 Z3.6 F36000
G1 X135.401 Y133.791 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4458
G1 X135.188 Y134.042 E.01095
G3 X126.808 Y118.677 I-7.197 J-6.043 E1.21191
G3 X128.36 Y118.61 I1.192 J9.536 E.05158
G3 X135.431 Y133.74 I-.369 J9.39 E.68227
G1 X135.701 Y134.034 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4458
M204 S6000
G1 X135.49 Y134.297 E.01036
G3 X118.246 Y127.181 I-7.491 J-6.299 E.75963
G3 X128.374 Y118.218 I9.766 J.831 E.45864
G3 X135.927 Y133.736 I-.375 J9.78 E.64926
G1 X135.737 Y133.986 E.00963
M204 S10000
G1 X135.209 Y133.548 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231608
G1 F4458
G1 X134.743 Y134.1 E.01112
G3 X118.912 Y128.456 I-6.744 J-6.108 E.32941
G1 X118.901 Y128.088 E.00566
G3 X135.243 Y133.498 I9.098 J-.096 E.53192
; CHANGE_LAYER
; Z_HEIGHT: 3.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.743 Y134.1 E-.29742
G1 X134.521 Y134.346 E-.12559
G1 X134.044 Y134.802 E-.25107
G1 X133.868 Y134.945 E-.08592
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L17
M991 S0 P16 ;notify layer change


G17
G3 Z3.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.637 Y135.644
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4460
G1 X123.625 Y135.634 E.0005
G3 X119.204 Y128.292 I4.375 J-7.636 E.29694
G3 X127.824 Y119.199 I8.799 J-.291 E.46244
G3 X124.25 Y135.96 I.177 J8.799 E1.05155
G1 X123.691 Y135.671 E.02087
G1 X123.706 Y135.226 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4460
M204 S6000
G1 X123.253 Y134.934 E.01657
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G3 X128.979 Y119.648 I-.025 J12.059 E.0353
G1 X129.174 Y119.672 E.00606
G3 X123.822 Y135.291 I-1.174 J8.324 E.90967
G1 X123.759 Y135.255 E.00225
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.22771
G1 X122.71 Y134.537 E-.25564
G1 X122.452 Y134.32 E-.12796
G1 X122.169 Y134.05 E-.14869
; WIPE_END
G1 E-.04 F1800
G1 X129.8 Y133.899 Z3.8 F36000
G1 X135.403 Y133.788 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4460
G1 X135.188 Y134.042 E.01106
G3 X126.808 Y118.677 I-7.197 J-6.043 E1.21188
G3 X128.373 Y118.61 I1.192 J9.54 E.052
G3 X135.432 Y133.738 I-.382 J9.389 E.68176
G1 X135.703 Y134.031 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4460
M204 S6000
G1 X135.489 Y134.296 E.01047
G3 X122.955 Y119.611 I-7.489 J-6.299 E1.04387
G3 X125.569 Y118.517 I5.048 J8.393 E.08739
G3 X128.387 Y118.218 I2.432 J9.487 E.08739
G3 X135.926 Y133.736 I-.388 J9.778 E.64885
G1 X135.739 Y133.983 E.00952
M204 S10000
G1 X135.211 Y133.545 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4460
G1 X134.743 Y134.101 E.01117
G3 X118.912 Y128.456 I-6.744 J-6.109 E.32942
G1 X118.901 Y128.088 E.00566
G3 X135.245 Y133.496 I9.099 J-.096 E.53189
; CHANGE_LAYER
; Z_HEIGHT: 3.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.743 Y134.101 E-.29876
G1 X134.522 Y134.345 E-.12545
G1 X134.044 Y134.802 E-.25116
G1 X133.871 Y134.942 E-.08464
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L18
M991 S0 P17 ;notify layer change


G17
G3 Z3.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4471
G1 X123.029 Y135.261 E.02287
G3 X119.632 Y130.724 I4.972 J-7.262 E.19143
G3 X125.192 Y119.659 I8.366 J-2.725 E.45566
G3 X127.824 Y119.199 I2.829 J8.426 E.08896
G3 X126.118 Y136.596 I.171 J8.799 E.98553
G3 X123.665 Y135.658 I1.883 J-8.598 E.08746
G1 X123.688 Y135.214 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4471
M204 S6000
G1 X123.25 Y134.938 E.01592
G3 X127.832 Y119.591 I4.75 J-6.939 E.65149
M73 P64 R5
G3 X128.632 Y119.615 I.131 J9.114 E.02461
G1 X128.84 Y119.631 E.00641
G3 X123.82 Y135.295 I-.84 J8.367 E.92033
G1 X123.739 Y135.246 E.0029
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.938 E-.2197
G1 X122.71 Y134.537 E-.25569
G1 X122.452 Y134.32 E-.12796
G1 X122.154 Y134.036 E-.15665
; WIPE_END
G1 E-.04 F1800
G1 X129.785 Y133.886 Z4 F36000
G1 X135.401 Y133.776 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4471
G3 X127.148 Y118.64 I-7.412 J-5.777 E1.23464
G3 X128.386 Y118.611 I.922 J12.791 E.04109
G3 X135.437 Y133.729 I-.397 J9.389 E.68087
G1 X135.71 Y134.032 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4471
M204 S6000
G1 X135.343 Y134.463 E.01741
G3 X126.759 Y118.288 I-7.352 J-6.464 E1.16255
G3 X128.4 Y118.219 I1.242 J9.946 E.05054
G3 X135.739 Y133.982 I-.409 J9.781 E.65768
M204 S10000
G1 X135.191 Y133.561 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4471
G1 X134.968 Y133.858 E.00571
G3 X118.901 Y128.092 I-6.968 J-5.853 E.34046
G1 X118.901 Y128.088 E.00006
G3 X118.923 Y127.364 I9.125 J-.084 E.01114
G1 X118.946 Y127.092 E.0042
G3 X135.461 Y133.215 I9.054 J.913 E.5108
G1 X135.227 Y133.513 E.00583
; CHANGE_LAYER
; Z_HEIGHT: 3.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.968 Y133.858 E-.16386
G1 X134.532 Y134.335 E-.24564
G1 X134.273 Y134.591 E-.13844
G1 X134.001 Y134.839 E-.13981
G1 X133.854 Y134.96 E-.07225
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L19
M991 S0 P18 ;notify layer change


G17
G3 Z4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.329 Y135.46
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4468
G1 X123.324 Y135.454 E.00026
G3 X127.824 Y119.199 I4.677 J-7.456 E.74777
G3 X130.72 Y119.63 I.119 J9.153 E.09756
G3 X134.229 Y134.216 I-2.731 J8.372 E.5956
G3 X123.625 Y135.635 I-6.228 J-6.218 E.38142
G1 X123.381 Y135.49 E.00943
G1 X123.67 Y135.203 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4468
M204 S6000
G1 X123.532 Y135.122 E.00491
G3 X127.832 Y119.591 I4.468 J-7.124 E.66183
G3 X128.955 Y119.645 I-.035 J12.384 E.03458
G1 X129.174 Y119.672 E.00678
G3 X124.115 Y135.457 I-1.174 J8.327 E.89963
G1 X123.722 Y135.233 E.01392
; WIPE_START
G1 F12000
M204 S10000
G1 X123.532 Y135.122 E-.08357
G1 X123.249 Y134.939 E-.128
G1 X122.71 Y134.537 E-.2556
G1 X122.452 Y134.32 E-.12796
G1 X122.138 Y134.021 E-.16487
; WIPE_END
G1 E-.04 F1800
G1 X129.769 Y133.88 Z4.2 F36000
G1 X135.401 Y133.776 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4468
G3 X127.148 Y118.64 I-7.411 J-5.777 E1.23458
G3 X128.399 Y118.611 I.919 J12.724 E.04152
G3 X135.438 Y133.729 I-.409 J9.388 E.68047
G1 X135.712 Y134.029 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4468
M204 S6000
G1 X135.487 Y134.294 E.01068
G3 X127.112 Y118.25 I-7.498 J-6.294 E1.18044
G3 X128.413 Y118.219 I.958 J13.264 E.03999
G3 X135.74 Y133.98 I-.424 J9.78 E.65714
M204 S10000
G1 X135.185 Y133.567 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4468
G1 X135.02 Y133.794 E.00432
G3 X118.901 Y128.092 I-7.02 J-5.791 E.34168
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.562 Y133.065 I9.096 J.252 E.5182
G1 X135.221 Y133.519 E.00874
; CHANGE_LAYER
; Z_HEIGHT: 4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.02 Y133.794 E-.12953
G1 X134.521 Y134.346 E-.28245
G1 X134.27 Y134.594 E-.1342
G1 X133.849 Y134.967 E-.21383
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L20
M991 S0 P19 ;notify layer change


G17
G3 Z4.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.611 Y135.629
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4459
G1 X123.029 Y135.261 E.02285
G3 X127.824 Y119.199 I4.972 J-7.262 E.73606
G3 X126.141 Y136.601 I.175 J8.8 E.98514
G3 X123.664 Y135.657 I1.86 J-8.603 E.08826
G1 X123.652 Y135.192 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4459
M204 S6000
G1 X123.25 Y134.938 E.01462
M73 P65 R5
G3 X127.832 Y119.591 I4.75 J-6.939 E.65149
G1 X128.168 Y119.591 E.01034
G3 X123.82 Y135.295 I-.168 J8.408 E.94101
G1 X123.703 Y135.223 E.00421
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.938 E-.20361
G1 X122.71 Y134.537 E-.25569
G1 X122.452 Y134.32 E-.12796
G1 X122.123 Y134.006 E-.17273
; WIPE_END
G1 E-.04 F1800
G1 X129.754 Y133.875 Z4.4 F36000
G1 X135.401 Y133.777 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4459
G3 X127.148 Y118.64 I-7.411 J-5.778 E1.23455
G3 X128.412 Y118.612 I.917 J12.668 E.04194
G3 X135.438 Y133.729 I-.421 J9.388 E.68008
G1 X135.709 Y134.023 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4459
M204 S6000
G1 X135.488 Y134.295 E.01079
M73 P65 R4
G3 X118.25 Y127.13 I-7.49 J-6.298 E.76114
G3 X128.426 Y118.22 I9.751 J.87 E.4588
G3 X135.926 Y133.735 I-.428 J9.777 E.64762
G1 X135.746 Y133.975 E.0092
M204 S10000
G1 X135.189 Y133.561 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231605
G1 F4459
G1 X135.02 Y133.794 E.00444
G3 X118.901 Y128.092 I-7.02 J-5.791 E.34168
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.562 Y133.065 I9.096 J.252 E.5182
G1 X135.225 Y133.513 E.00862
; CHANGE_LAYER
; Z_HEIGHT: 4.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.02 Y133.794 E-.13244
G1 X134.522 Y134.345 E-.2823
G1 X134.27 Y134.594 E-.13427
G1 X133.855 Y134.962 E-.21099
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L21
M991 S0 P20 ;notify layer change


G17
G3 Z4.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.628 Y135.631
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4468
G1 X123.324 Y135.452 E.01167
G3 X125.159 Y119.67 I4.683 J-7.454 E.65731
G3 X127.824 Y119.199 I2.863 J8.423 E.09013
G3 X136.404 Y130.613 I.17 J8.804 E.55238
G3 X126.152 Y136.604 I-8.414 J-2.633 E.4321
G3 X123.935 Y135.803 I1.855 J-8.605 E.07844
G1 X123.68 Y135.66 E.00969
G1 X123.634 Y135.18 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4468
M204 S6000
G1 X123.253 Y134.934 E.01396
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94069
G1 X123.686 Y135.211 E.00486
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.19547
G1 X122.71 Y134.537 E-.25558
G1 X122.384 Y134.257 E-.16313
G1 X122.107 Y133.992 E-.14582
; WIPE_END
G1 E-.04 F1800
G1 X129.738 Y133.868 Z4.6 F36000
G1 X135.401 Y133.777 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4468
G3 X127.148 Y118.64 I-7.41 J-5.778 E1.23442
G3 X128.425 Y118.612 I.914 J12.622 E.04237
G3 X135.438 Y133.729 I-.433 J9.387 E.67968
G1 X135.717 Y134.024 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4468
M204 S6000
G1 X135.487 Y134.294 E.0109
G3 X127.112 Y118.25 I-7.496 J-6.295 E1.18025
G3 X128.439 Y118.22 I.953 J13.157 E.04079
G3 X135.741 Y133.978 I-.448 J9.778 E.65632
M204 S10000
G1 X135.186 Y133.565 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231597
G1 F4468
G1 X135.019 Y133.794 E.00436
G3 X118.901 Y128.092 I-7.019 J-5.791 E.34166
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.562 Y133.064 I9.096 J.252 E.51817
G1 X135.222 Y133.517 E.0087
; CHANGE_LAYER
; Z_HEIGHT: 4.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.13062
G1 X134.522 Y134.345 E-.28224
G1 X134.27 Y134.594 E-.13433
G1 X133.851 Y134.965 E-.21281
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L22
M991 S0 P21 ;notify layer change


G17
G3 Z4.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4474
G1 X123.032 Y135.257 E.02286
G3 X127.824 Y119.199 I4.968 J-7.262 E.73595
G1 X128.176 Y119.199 E.01169
G3 X123.666 Y135.653 I-.176 J8.797 E1.06141
G1 X123.616 Y135.169 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4474
M204 S6000
G1 X123.253 Y134.934 E.0133
M73 P66 R4
G3 X127.832 Y119.591 I4.747 J-6.938 E.65134
G1 X128.168 Y119.591 E.01034
G3 X123.823 Y135.291 I-.168 J8.405 E.94068
G1 X123.668 Y135.2 E.00552
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.18729
G1 X122.71 Y134.537 E-.25569
G1 X122.452 Y134.32 E-.1279
G1 X122.092 Y133.977 E-.18912
; WIPE_END
G1 E-.04 F1800
G1 X129.723 Y133.861 Z4.8 F36000
G1 X135.399 Y133.775 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4474
G3 X127.148 Y118.64 I-7.407 J-5.779 E1.23406
G3 X128.438 Y118.613 I.913 J12.584 E.0428
G3 X135.436 Y133.728 I-.445 J9.384 E.67922
G1 X135.719 Y134.021 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4474
M204 S6000
G1 X135.711 Y134.019 E.00025
G3 X127.112 Y118.25 I-7.719 J-6.02 E1.19118
G3 X128.452 Y118.221 I.951 J13.117 E.04118
G3 X136.174 Y133.373 I-.46 J9.778 E.63313
G1 X135.754 Y133.971 E.02248
M204 S10000
G1 X135.223 Y133.531 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231588
G1 F4474
G1 X134.75 Y134.107 E.01146
G3 X118.901 Y128.092 I-6.75 J-6.103 E.33532
G1 X118.901 Y128.088 E.00006
G3 X118.956 Y127.002 I9.627 J-.05 E.01674
G1 X118.986 Y126.761 E.00373
G3 X135.263 Y133.486 I9.014 J1.244 E.51078
; CHANGE_LAYER
; Z_HEIGHT: 4.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.75 Y134.107 E-.30597
G1 X134.522 Y134.345 E-.12525
G1 X134.043 Y134.802 E-.25134
G1 X133.885 Y134.931 E-.07744
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L23
M991 S0 P22 ;notify layer change


G17
G3 Z4.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.638 Y135.644
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4460
G1 X123.628 Y135.631 E.00054
G3 X127.824 Y119.199 I4.372 J-7.635 E.75929
G3 X128.879 Y119.241 I.093 J10.865 E.03505
G3 X124.252 Y135.956 I-.879 J8.755 E1.01617
G1 X123.691 Y135.671 E.02086
G1 X123.596 Y135.162 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4460
M204 S6000
G1 X123.534 Y135.118 E.00233
G3 X127.832 Y119.591 I4.466 J-7.122 E.66167
G3 X128.84 Y119.631 I.087 J10.428 E.03101
G3 X123.822 Y135.291 I-.84 J8.365 E.92002
G1 X123.648 Y135.192 E.00616
; WIPE_START
G1 F12000
M204 S10000
G1 X123.534 Y135.118 E-.05152
G1 X122.975 Y134.743 E-.25597
G1 X122.452 Y134.32 E-.25553
G1 X122.077 Y133.962 E-.19698
; WIPE_END
G1 E-.04 F1800
G1 X129.708 Y133.853 Z5 F36000
G1 X135.413 Y133.772 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4460
G1 X135.185 Y134.042 E.01175
G3 X127.488 Y118.615 I-7.195 J-6.044 E1.23444
G3 X128.441 Y118.613 I.504 J10.23 E.03164
G3 X135.444 Y133.72 I-.452 J9.386 E.6787
G1 X135.719 Y134.017 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4460
M204 S6000
G1 X135.486 Y134.294 E.01114
G3 X127.467 Y118.224 I-7.496 J-6.295 E1.1912
G3 X128.462 Y118.221 I.525 J10.663 E.03058
G3 X135.753 Y133.961 I-.472 J9.777 E.65495
G1 X135.75 Y133.965 E.00016
M204 S10000
G1 X135.196 Y133.552 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231625
G1 F4460
G1 X135.01 Y133.791 E.00465
G3 X118.909 Y128.388 I-7.011 J-5.799 E.33677
G1 X118.901 Y128.088 E.0046
G1 X118.904 Y127.751 E.00519
G3 X135.555 Y133.06 I9.096 J.24 E.51852
G1 X135.231 Y133.504 E.00845
; CHANGE_LAYER
; Z_HEIGHT: 4.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.01 Y133.791 E-.13769
G1 X134.481 Y134.386 E-.30248
G1 X133.861 Y134.954 E-.31983
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L24
M991 S0 P23 ;notify layer change


G17
G3 Z5 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4464
G1 X123.031 Y135.255 E.02292
G3 X127.824 Y119.199 I4.969 J-7.26 E.73583
G1 X128.176 Y119.199 E.01169
G3 X123.666 Y135.651 I-.176 J8.796 E1.06132
G1 X123.581 Y135.147 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4464
M204 S6000
G1 X123.253 Y134.932 E.01203
M73 P67 R4
G3 X127.832 Y119.591 I4.747 J-6.937 E.65127
G1 X128.168 Y119.591 E.01034
G3 X123.823 Y135.29 I-.168 J8.404 E.94058
G1 X123.632 Y135.177 E.00681
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.932 E-.17153
G1 X122.71 Y134.537 E-.25534
G1 X122.452 Y134.32 E-.12802
G1 X122.061 Y133.948 E-.20512
; WIPE_END
G1 E-.04 F1800
G1 X129.693 Y133.841 Z5.2 F36000
G1 X135.409 Y133.762 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4464
G1 X135.002 Y134.257 E.02126
G3 X127.488 Y118.615 I-7.01 J-6.258 E1.22505
G3 X128.454 Y118.613 I.505 J10.286 E.03205
G3 X135.607 Y133.504 I-.462 J9.386 E.66942
G1 X135.446 Y133.714 E.00877
G1 X135.723 Y134.015 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4464
M204 S6000
G1 X135.711 Y134.019 E.0004
G3 X127.467 Y118.224 I-7.719 J-6.02 E1.2021
G3 X128.474 Y118.222 I.527 J10.715 E.03097
G3 X136.127 Y133.443 I-.483 J9.777 E.63503
G1 X135.758 Y133.966 E.01966
M204 S10000
G1 X135.205 Y133.542 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.23159
G1 F4464
G1 X134.961 Y133.852 E.00607
G3 X118.91 Y128.4 I-6.96 J-5.862 E.33528
G1 X118.901 Y128.088 E.00479
G3 X118.904 Y127.728 I57.452 J.408 E.00554
G1 X118.919 Y127.421 E.00473
G3 X135.454 Y133.21 I9.082 J.569 E.51622
G1 X135.241 Y133.494 E.00545
; CHANGE_LAYER
; Z_HEIGHT: 5
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.961 Y133.852 E-.17284
G1 X134.286 Y134.579 E-.37673
G1 X133.87 Y134.944 E-.21043
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L25
M991 S0 P24 ;notify layer change


G17
G3 Z5.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.335 Y135.463
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4448
G1 X123.326 Y135.45 E.00055
G3 X127.472 Y119.213 I4.675 J-7.454 E.7359
G1 X127.825 Y119.199 E.01173
G3 X123.937 Y135.8 I.175 J8.797 E1.06286
G1 X123.388 Y135.492 E.02087
G1 X123.56 Y135.14 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4448
M204 S6000
G1 X123.534 Y135.118 E.00104
G3 X127.495 Y119.604 I4.466 J-7.122 E.65133
G1 X127.832 Y119.591 E.01036
G3 X124.118 Y135.452 I.168 J8.405 E.94067
G1 X123.612 Y135.169 E.0178
; WIPE_START
G1 F12000
M204 S10000
G1 X123.534 Y135.118 E-.03557
G1 X123.249 Y134.939 E-.12784
G1 X122.71 Y134.537 E-.25572
G1 X122.204 Y134.093 E-.25571
G1 X122.048 Y133.932 E-.08516
; WIPE_END
G1 E-.04 F1800
G1 X129.68 Y133.838 Z5.4 F36000
G1 X135.412 Y133.767 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4448
G1 X135.186 Y134.041 E.01178
G3 X127.83 Y118.603 I-7.196 J-6.043 E1.24587
G3 X128.467 Y118.614 I.17 J8.779 E.02115
G3 X135.604 Y133.504 I-.477 J9.385 E.66894
G1 X135.447 Y133.719 E.00882
G1 X135.721 Y134.008 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4448
M204 S6000
G1 X135.485 Y134.293 E.01135
G3 X127.467 Y118.224 I-7.492 J-6.297 E1.19072
G3 X128.487 Y118.222 I.528 J10.771 E.03137
G3 X135.922 Y133.733 I-.494 J9.774 E.64553
G1 X135.756 Y133.96 E.00863
M204 S10000
G1 X135.207 Y133.539 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231574
G1 F4448
G1 X134.962 Y133.853 E.00612
G3 X118.91 Y128.412 I-6.962 J-5.859 E.33515
G1 X118.901 Y128.088 E.00498
G3 X118.904 Y127.728 I56.905 J.404 E.00554
G1 X118.919 Y127.421 E.00473
G3 X135.453 Y133.214 I9.081 J.572 E.51611
G1 X135.243 Y133.491 E.00534
; CHANGE_LAYER
; Z_HEIGHT: 5.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.962 Y133.853 E-.17416
G1 X134.532 Y134.335 E-.24556
G1 X134.287 Y134.578 E-.13103
G1 X133.873 Y134.941 E-.20925
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L26
M991 S0 P25 ;notify layer change


G17
G3 Z5.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.637 Y135.644
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4468
G1 X123.627 Y135.631 E.00054
G3 X127.824 Y119.199 I4.373 J-7.635 E.75929
G1 X128.176 Y119.199 E.01169
G3 X124.252 Y135.956 I-.176 J8.797 E1.03953
G1 X123.691 Y135.671 E.02087
G1 X123.545 Y135.125 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4468
M204 S6000
M73 P68 R4
G1 X123.253 Y134.934 E.01073
G3 X127.832 Y119.591 I4.747 J-6.938 E.65134
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94068
G1 X123.597 Y135.155 E.00809
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.15553
G1 X122.975 Y134.743 E-.12786
G1 X122.452 Y134.32 E-.25573
G1 X122.031 Y133.919 E-.22088
; WIPE_END
G1 E-.04 F1800
G1 X129.663 Y133.83 Z5.6 F36000
G1 X135.422 Y133.763 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4468
G1 X135.187 Y134.043 E.01213
G3 X127.83 Y118.603 I-7.194 J-6.045 E1.24569
G3 X128.479 Y118.614 I.17 J8.96 E.02156
G3 X135.452 Y133.713 I-.487 J9.384 E.67726
G1 X135.727 Y134.009 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4468
M204 S6000
G1 X135.487 Y134.295 E.01147
G3 X127.823 Y118.211 I-7.495 J-6.297 E1.20205
G3 X128.5 Y118.223 I.177 J9.336 E.02083
G3 X135.758 Y133.958 I-.508 J9.776 E.65377
M204 S10000
G1 X135.231 Y133.522 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231598
G1 F4468
G1 X134.743 Y134.101 E.01164
G3 X118.911 Y128.424 I-6.744 J-6.108 E.32989
G1 X118.901 Y128.088 E.00517
G1 X118.904 Y127.751 E.00519
G3 X135.263 Y133.472 I9.096 J.241 E.52618
; CHANGE_LAYER
; Z_HEIGHT: 5.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.743 Y134.101 E-.31025
G1 X134.522 Y134.345 E-.1254
G1 X134.044 Y134.802 E-.25118
G1 X133.894 Y134.923 E-.07317
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L27
M991 S0 P26 ;notify layer change


G17
G3 Z5.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.638 Y135.644
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4450
G1 X123.628 Y135.631 E.00053
G3 X127.824 Y119.199 I4.372 J-7.635 E.7593
G1 X128.176 Y119.199 E.01169
G3 X124.252 Y135.956 I-.176 J8.797 E1.03952
G1 X123.691 Y135.671 E.02087
G1 X123.528 Y135.114 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4450
M204 S6000
G1 X123.253 Y134.934 E.0101
G3 X127.832 Y119.591 I4.747 J-6.938 E.65134
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94068
G1 X123.579 Y135.145 E.00872
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.14774
G1 X122.975 Y134.743 E-.12784
G1 X122.452 Y134.32 E-.25578
G1 X122.016 Y133.905 E-.22864
; WIPE_END
G1 E-.04 F1800
G1 X129.648 Y133.828 Z5.8 F36000
G1 X135.417 Y133.771 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4450
G1 X135.401 Y133.776 E.00056
G3 X128.17 Y118.603 I-7.411 J-5.778 E1.26851
G1 X128.492 Y118.615 E.01067
G3 X135.606 Y133.504 I-.502 J9.384 E.66813
G1 X135.451 Y133.722 E.00885
G1 X135.725 Y134.002 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4450
M204 S6000
G1 X135.487 Y134.294 E.01158
G3 X128.177 Y118.211 I-7.497 J-6.296 E1.21315
G1 X128.513 Y118.223 E.01031
G3 X135.923 Y133.734 I-.523 J9.776 E.64472
G1 X135.761 Y133.954 E.00841
M204 S10000
G1 X135.234 Y133.518 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4450
G1 X134.744 Y134.101 E.01172
G3 X118.911 Y128.436 I-6.744 J-6.109 E.32972
G1 X118.901 Y128.088 E.00535
G3 X135.267 Y133.468 I9.099 J-.097 E.53139
; CHANGE_LAYER
; Z_HEIGHT: 5.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.744 Y134.101 E-.31222
G1 X134.515 Y134.352 E-.1288
G1 X134.044 Y134.802 E-.24783
G1 X133.898 Y134.92 E-.07115
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L28
M991 S0 P27 ;notify layer change


G17
G3 Z5.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.612 Y135.629
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4466
G1 X123.031 Y135.257 E.02286
G3 X127.824 Y119.199 I4.969 J-7.261 E.73593
G1 X128.176 Y119.199 E.0117
G3 X123.666 Y135.653 I-.176 J8.797 E1.06142
G1 X123.511 Y135.103 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4466
M204 S6000
G1 X123.253 Y134.934 E.0095
M73 P69 R4
G3 X127.832 Y119.591 I4.748 J-6.938 E.65133
G1 X128.168 Y119.591 E.01035
G3 X123.823 Y135.291 I-.168 J8.405 E.94068
G1 X123.562 Y135.134 E.00933
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.14025
G1 X122.975 Y134.743 E-.12781
G1 X122.452 Y134.32 E-.25566
G1 X122.002 Y133.891 E-.23628
; WIPE_END
G1 E-.04 F1800
G1 X129.634 Y133.816 Z6 F36000
G1 X135.419 Y133.758 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4466
G1 X135.187 Y134.042 E.01214
G3 X128.17 Y118.603 I-7.191 J-6.046 E1.25646
G1 X128.505 Y118.615 E.01109
G3 X135.606 Y133.505 I-.508 J9.381 E.66794
G1 X135.454 Y133.71 E.00847
G1 X135.727 Y134 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4466
M204 S6000
G1 X135.487 Y134.294 E.01169
G3 X128.177 Y118.211 I-7.491 J-6.298 E1.21242
G1 X128.526 Y118.223 E.01071
G3 X135.924 Y133.735 I-.529 J9.772 E.64452
G1 X135.763 Y133.951 E.00829
M204 S10000
G1 X135.207 Y133.537 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231608
G1 F4466
G1 X135.018 Y133.793 E.00488
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34166
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.561 Y133.064 I9.096 J.252 E.51815
G1 X135.243 Y133.489 E.00818
; CHANGE_LAYER
; Z_HEIGHT: 5.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.018 Y133.793 E-.14352
G1 X134.521 Y134.346 E-.28243
G1 X134.27 Y134.594 E-.13421
G1 X133.876 Y134.942 E-.19985
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L29
M991 S0 P28 ;notify layer change


G17
G3 Z6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.326 Y135.45
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4453
G1 X123.031 Y135.257 E.01167
G3 X127.824 Y119.199 I4.969 J-7.262 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06287
G1 X123.377 Y135.48 E.00969
G1 X123.491 Y135.097 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4453
M204 S6000
G1 X123.253 Y134.934 E.00888
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G1 X128.168 Y119.591 E.01034
G3 X123.544 Y135.124 I-.168 J8.405 E.95065
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.13239
G1 X122.71 Y134.537 E-.25553
G1 X122.204 Y134.093 E-.25584
G1 X121.991 Y133.873 E-.11624
; WIPE_END
G1 E-.04 F1800
G1 X129.623 Y133.815 Z6.2 F36000
G1 X135.417 Y133.77 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4453
G1 X135.403 Y133.778 E.00054
G3 X127.829 Y118.603 I-7.405 J-5.782 E1.25639
G1 X128.176 Y118.603 E.01149
G3 X135.802 Y133.226 I-.178 J9.393 E.66759
G1 X135.451 Y133.721 E.02014
G1 X135.735 Y134 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4453
M204 S6000
G1 X135.711 Y134.019 E.00092
G3 X127.822 Y118.211 I-7.714 J-6.023 E1.21239
G1 X128.183 Y118.211 E.01108
G3 X135.925 Y133.735 I-.186 J9.785 E.65509
G1 X135.769 Y133.951 E.00819
M204 S10000
G1 X135.217 Y133.527 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231608
G1 F4453
G1 X134.964 Y133.855 E.00636
G3 X118.901 Y128.097 I-6.965 J-5.855 E.34024
G1 X118.901 Y128.093 E.00006
G1 X118.904 Y127.751 E.00527
G3 X135.455 Y133.216 I9.096 J.249 E.52109
G1 X135.253 Y133.479 E.00511
; CHANGE_LAYER
; Z_HEIGHT: 6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.964 Y133.855 E-.18007
G1 X134.535 Y134.331 E-.24362
G1 X134.287 Y134.578 E-.13299
G1 X133.885 Y134.931 E-.20332
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L30
M991 S0 P29 ;notify layer change


G17
G3 Z6.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.254
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4465
G1 X122.467 Y134.837 E.02286
G3 X127.824 Y119.199 I5.533 J-6.841 E.71259
G1 X128.176 Y119.199 E.01169
M73 P70 R4
G3 X123.068 Y135.282 I-.176 J8.797 E1.08476
G1 X123.477 Y135.082 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4465
M204 S6000
G1 X123.253 Y134.934 E.00826
G3 X127.832 Y119.591 I4.747 J-6.938 E.65134
G1 X128.168 Y119.591 E.01034
G3 X123.837 Y135.299 I-.168 J8.405 E.94017
G1 X123.529 Y135.113 E.01107
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.12495
G1 X122.71 Y134.537 E-.25563
G1 X122.204 Y134.093 E-.25582
G1 X121.977 Y133.859 E-.1236
; WIPE_END
G1 E-.04 F1800
G1 X129.609 Y133.807 Z6.4 F36000
G1 X135.419 Y133.767 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4465
G1 X135.4 Y133.775 E.00069
G3 X127.829 Y118.603 I-7.407 J-5.779 E1.25666
G1 X128.188 Y118.604 E.01191
G3 X135.799 Y133.223 I-.196 J9.393 E.66692
G1 X135.453 Y133.718 E.02001
G1 X135.736 Y133.997 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4465
M204 S6000
G1 X135.708 Y134.016 E.00105
G3 X127.822 Y118.211 I-7.716 J-6.02 E1.21265
G1 X128.196 Y118.211 E.01147
G3 X136.124 Y133.441 I-.204 J9.785 E.64353
G1 X135.771 Y133.947 E.01897
M204 S10000
G1 X135.208 Y133.549 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231596
G1 F4465
G1 X135.173 Y133.597 E.00092
G3 X118.901 Y128.11 I-7.174 J-5.597 E.34511
G1 X118.901 Y128.106 E.00006
G1 X118.901 Y128.082 E.00037
G3 X135.658 Y132.913 I9.099 J-.082 E.52054
G1 X135.243 Y133.5 E.01105
; CHANGE_LAYER
; Z_HEIGHT: 6.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.173 Y133.597 E-.04565
G1 X134.78 Y134.069 E-.2333
G1 X134.532 Y134.335 E-.13831
G1 X134.001 Y134.839 E-.2781
G1 X133.868 Y134.945 E-.06465
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L31
M991 S0 P30 ;notify layer change


G17
G3 Z6.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.261 E.73593
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06287
G1 X123.091 Y135.302 E.02088
G1 X123.461 Y135.072 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.253 Y134.934 E.00768
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94068
G1 X123.512 Y135.103 E.01115
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.11776
G1 X122.71 Y134.537 E-.25558
G1 X122.452 Y134.32 E-.1279
G1 X121.965 Y133.856 E-.25577
G1 X121.959 Y133.85 E-.00299
; WIPE_END
G1 E-.04 F1800
G1 X129.592 Y133.798 Z6.6 F36000
G1 X135.426 Y133.758 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.403 Y133.777 E.00097
G3 X127.488 Y118.615 I-7.41 J-5.779 E1.24569
G3 X128.201 Y118.604 I.5 J9.066 E.02366
G3 X135.608 Y133.505 I-.208 J9.395 E.67791
G1 X135.461 Y133.71 E.00836
G1 X135.739 Y133.994 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.712 Y134.019 E.00113
G3 X127.467 Y118.224 I-7.719 J-6.02 E1.20201
G3 X128.208 Y118.212 I.521 J9.444 E.0228
G3 X135.925 Y133.735 I-.215 J9.787 E.6542
G1 X135.774 Y133.945 E.00796
M204 S10000
G1 X135.222 Y133.519 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231611
G1 F4449
G1 X134.947 Y133.88 E.00697
G3 X118.901 Y128.092 I-6.948 J-5.876 E.33996
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.752 E.00517
G3 X135.457 Y133.217 I9.096 J.252 E.52101
G1 X135.258 Y133.472 E.00497
; CHANGE_LAYER
; Z_HEIGHT: 6.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.947 Y133.88 E-.19505
G1 X134.532 Y134.335 E-.23428
G1 X134.287 Y134.578 E-.13095
G1 X133.892 Y134.925 E-.19972
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L32
M991 S0 P31 ;notify layer change


G17
G3 Z6.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.041 Y135.27
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.031 Y135.257 E.00054
M73 P71 R4
G3 X127.824 Y119.199 I4.969 J-7.261 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06287
G1 X123.092 Y135.302 E.02086
G1 X123.445 Y135.062 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.253 Y134.934 E.0071
G3 X127.832 Y119.591 I4.747 J-6.938 E.65134
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94068
G1 X123.496 Y135.093 E.01173
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.11055
G1 X122.975 Y134.743 E-.12786
G1 X122.453 Y134.32 E-.25555
G1 X121.993 Y133.884 E-.24055
G1 X121.948 Y133.835 E-.02549
; WIPE_END
G1 E-.04 F1800
G1 X129.581 Y133.793 Z6.8 F36000
G1 X135.423 Y133.761 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.402 Y133.776 E.00086
G3 X127.488 Y118.615 I-7.411 J-5.777 E1.24583
G3 X128.214 Y118.604 I.497 J8.998 E.02408
G3 X135.801 Y133.224 I-.223 J9.394 E.66607
G1 X135.458 Y133.712 E.01976
G1 X135.741 Y133.99 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.711 Y134.018 E.00125
G3 X127.467 Y118.224 I-7.72 J-6.019 E1.20213
G3 X128.221 Y118.212 I.518 J9.357 E.0232
G3 X136.126 Y133.443 I-.23 J9.786 E.64278
G1 X135.775 Y133.941 E.01874
M204 S10000
G1 X135.224 Y133.516 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231594
G1 F4449
G1 X134.942 Y133.891 E.00722
G3 X118.901 Y128.092 I-6.943 J-5.881 E.33991
G1 X118.9 Y128.088 E.00006
G3 X118.904 Y127.728 I55.449 J.411 E.00554
G1 X118.921 Y127.402 E.00502
G3 X135.46 Y133.219 I9.079 J.608 E.51539
G1 X135.261 Y133.469 E.00491
; CHANGE_LAYER
; Z_HEIGHT: 6.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.942 Y133.891 E-.20135
G1 X134.56 Y134.305 E-.21394
G1 X134.275 Y134.59 E-.15309
G1 X133.896 Y134.922 E-.19162
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L33
M991 S0 P32 ;notify layer change


G17
G3 Z6.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4448
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.261 E.73593
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06287
G1 X123.091 Y135.302 E.02088
G1 X123.43 Y135.052 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4448
M204 S6000
G1 X123.253 Y134.934 E.00654
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94068
G1 X123.481 Y135.083 E.01229
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.10371
G1 X122.71 Y134.537 E-.25552
G1 X122.452 Y134.32 E-.12802
G1 X121.965 Y133.856 E-.25564
G1 X121.934 Y133.823 E-.01711
; WIPE_END
G1 E-.04 F1800
G1 X129.566 Y133.783 Z7 F36000
G1 X135.43 Y133.752 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4448
G1 X135.399 Y133.776 E.00128
G3 X127.148 Y118.64 I-7.407 J-5.779 E1.23402
G3 X128.226 Y118.605 I.869 J10.123 E.03579
G3 X135.604 Y133.503 I-.233 J9.392 E.67693
G1 X135.465 Y133.703 E.0081
G1 X135.743 Y133.987 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4448
M204 S6000
G1 X135.708 Y134.017 E.0014
G3 X127.112 Y118.25 I-7.716 J-6.02 E1.19076
G3 X128.234 Y118.213 I.906 J10.549 E.0345
G3 X136.124 Y133.441 I-.242 J9.784 E.64235
G1 X135.777 Y133.938 E.01862
M204 S10000
G1 X135.218 Y133.522 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231595
G1 F4448
G1 X135.019 Y133.794 E.00518
G3 X118.901 Y128.092 I-7.02 J-5.79 E.34166
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.754 E.00515
G3 X135.562 Y133.064 I9.096 J.251 E.51813
G1 X135.254 Y133.474 E.00788
; CHANGE_LAYER
; Z_HEIGHT: 6.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.15086
G1 X134.523 Y134.344 E-.28146
G1 X134.247 Y134.616 E-.14729
G1 X133.891 Y134.93 E-.18039
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L34
M991 S0 P33 ;notify layer change


G17
G3 Z7 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z6.8
M73 P72 R4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.031 Y135.257 E.00054
G3 X127.824 Y119.199 I4.969 J-7.261 E.73593
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06287
G1 X123.092 Y135.302 E.02087
G1 X123.414 Y135.042 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.253 Y134.934 E.00599
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94068
G1 X123.466 Y135.074 E.01283
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.09692
G1 X122.975 Y134.743 E-.1278
G1 X122.453 Y134.32 E-.25547
M73 P72 R3
G1 X121.965 Y133.856 E-.25597
G1 X121.922 Y133.81 E-.02384
; WIPE_END
G1 E-.04 F1800
G1 X129.554 Y133.779 Z7.2 F36000
G1 X135.428 Y133.755 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.403 Y133.776 E.00109
G3 X127.148 Y118.64 I-7.412 J-5.777 E1.23453
G3 X128.239 Y118.605 I.866 J10.056 E.03622
G3 X135.802 Y133.225 I-.247 J9.394 E.66525
G1 X135.463 Y133.705 E.01952
G1 X135.745 Y133.984 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.711 Y134.018 E.00148
G3 X127.112 Y118.25 I-7.72 J-6.019 E1.19124
G3 X128.247 Y118.213 I.902 J10.481 E.0349
G3 X136.127 Y133.443 I-.256 J9.786 E.642
G1 X135.78 Y133.935 E.01851
M204 S10000
G1 X135.229 Y133.508 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231561
G1 F4449
G1 X134.924 Y133.909 E.00774
G3 X118.901 Y128.092 I-6.925 J-5.902 E.33937
G1 X118.9 Y128.088 E.00006
G3 X118.946 Y127.092 I10.393 J-.022 E.01534
G3 X135.46 Y133.215 I9.053 J.915 E.51056
G1 X135.266 Y133.461 E.00481
; CHANGE_LAYER
; Z_HEIGHT: 7
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.924 Y133.909 E-.21414
G1 X134.287 Y134.578 E-.35101
G1 X133.902 Y134.916 E-.19485
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L35
M991 S0 P34 ;notify layer change


G17
G3 Z7.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.261 E.73593
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06287
G1 X123.091 Y135.302 E.02088
G1 X123.4 Y135.033 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.253 Y134.934 E.00547
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94068
G1 X123.451 Y135.065 E.01336
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.0904
G1 X122.71 Y134.537 E-.25552
G1 X122.452 Y134.32 E-.12796
G1 X121.965 Y133.856 E-.25571
G1 X121.91 Y133.798 E-.03041
; WIPE_END
G1 E-.04 F1800
G1 X129.543 Y133.772 Z7.4 F36000
G1 X135.43 Y133.751 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.401 Y133.777 E.00127
G3 X127.148 Y118.64 I-7.411 J-5.778 E1.23455
G3 X128.252 Y118.606 I.862 J10.002 E.03664
G3 X135.802 Y133.223 I-.261 J9.393 E.6647
G1 X135.465 Y133.702 E.01945
G1 X135.748 Y133.981 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.71 Y134.018 E.00162
G3 X127.112 Y118.25 I-7.72 J-6.019 E1.19124
G3 X128.26 Y118.214 I.899 J10.425 E.03529
G3 X136.127 Y133.442 I-.27 J9.785 E.64152
G1 X135.782 Y133.932 E.01841
M204 S10000
G1 X135.226 Y133.51 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231617
G1 F4449
G1 X134.969 Y133.859 E.00666
G3 X118.901 Y128.092 I-6.969 J-5.851 E.34056
G1 X118.901 Y128.088 E.00006
G3 X118.923 Y127.368 I10.114 J-.049 E.01108
G3 X135.505 Y133.154 I9.077 J.64 E.51384
G1 X135.263 Y133.463 E.00603
; CHANGE_LAYER
; Z_HEIGHT: 7.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.969 Y133.859 E-.18747
G1 X134.532 Y134.335 E-.24565
G1 X134.273 Y134.591 E-.13844
M73 P73 R3
G1 X133.9 Y134.918 E-.18845
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L36
M991 S0 P35 ;notify layer change


G17
G3 Z7.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.253
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4465
G1 X122.464 Y134.841 E.02286
G3 X127.824 Y119.199 I5.536 J-6.842 E.71276
G3 X128.781 Y119.233 I.137 J9.525 E.03178
G1 X128.879 Y119.241 E.00327
G3 X123.066 Y135.286 I-.879 J8.757 E1.06175
G1 X123.386 Y135.025 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4465
M204 S6000
G1 X123.25 Y134.937 E.00496
G3 X127.832 Y119.591 I4.75 J-6.939 E.65148
G3 X128.749 Y119.624 I.131 J9.111 E.02823
G1 X128.84 Y119.631 E.00279
G3 X123.82 Y135.295 I-.84 J8.367 E.92033
G1 X123.437 Y135.056 E.01388
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.937 E-.08411
G1 X122.71 Y134.537 E-.25558
G1 X122.452 Y134.32 E-.12802
G1 X121.965 Y133.856 E-.25564
G1 X121.899 Y133.786 E-.03664
; WIPE_END
G1 E-.04 F1800
G1 X129.531 Y133.762 Z7.6 F36000
G1 X135.437 Y133.743 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4465
G1 X135.401 Y133.777 E.00164
G3 X127.148 Y118.64 I-7.411 J-5.778 E1.23458
G3 X128.256 Y118.606 I1 J14.513 E.03676
G3 X135.606 Y133.504 I-.266 J9.393 E.67593
G1 X135.472 Y133.694 E.00772
G1 X135.746 Y133.975 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4465
M204 S6000
G1 X135.492 Y134.298 E.01263
G3 X118.237 Y127.286 I-7.492 J-6.299 E.75657
G3 X128.27 Y118.214 I9.764 J.715 E.4588
G3 X135.929 Y133.738 I-.27 J9.785 E.65259
G1 X135.783 Y133.928 E.00737
M204 S10000
G1 X135.225 Y133.513 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231504
G1 F4465
G1 X135.019 Y133.793 E.00536
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34148
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.561 Y133.064 I9.096 J.252 E.51788
G1 X135.261 Y133.465 E.00769
; CHANGE_LAYER
; Z_HEIGHT: 7.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.793 E-.15524
G1 X134.522 Y134.345 E-.28216
G1 X134.044 Y134.802 E-.2513
G1 X133.9 Y134.923 E-.07129
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L37
M991 S0 P36 ;notify layer change


G17
G3 Z7.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.029 Y135.261 E.00049
G3 X119.599 Y130.623 I4.971 J-7.263 E.19494
G3 X127.824 Y119.199 I8.403 J-2.623 E.5411
G3 X123.625 Y135.635 I.176 J8.799 E1.07489
G1 X123.091 Y135.302 E.02089
G1 X123.372 Y135.016 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.25 Y134.937 E.00446
G3 X127.832 Y119.591 I4.75 J-6.939 E.65148
G1 X128.168 Y119.591 E.01034
G3 X123.82 Y135.295 I-.168 J8.408 E.94101
G1 X123.423 Y135.048 E.01437
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.937 E-.07802
G1 X122.71 Y134.537 E-.25563
G1 X122.452 Y134.32 E-.1279
G1 X121.965 Y133.856 E-.25571
G1 X121.888 Y133.774 E-.04274
; WIPE_END
G1 E-.04 F1800
G1 X129.52 Y133.758 Z7.8 F36000
G1 X135.435 Y133.745 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.401 Y133.777 E.00154
G3 X127.148 Y118.64 I-7.411 J-5.777 E1.23458
G3 X128.268 Y118.606 I.987 J14.213 E.03719
G3 X135.8 Y133.224 I-.279 J9.393 E.66415
G1 X135.469 Y133.696 E.01912
G1 X135.749 Y133.972 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.492 Y134.298 E.01275
G3 X118.238 Y127.273 I-7.492 J-6.299 E.75697
G3 X128.283 Y118.215 I9.767 J.732 E.45874
G3 X135.929 Y133.738 I-.283 J9.784 E.6522
G1 X135.785 Y133.925 E.00725
M204 S10000
G1 X135.228 Y133.51 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4449
G1 X135.019 Y133.793 E.00542
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34166
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.561 Y133.064 I9.096 J.252 E.51816
G1 X135.263 Y133.462 E.00764
; CHANGE_LAYER
; Z_HEIGHT: 7.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.793 E-.15672
G1 X134.522 Y134.346 E-.28229
G1 X134.27 Y134.594 E-.13427
M73 P74 R3
G1 X133.902 Y134.92 E-.18672
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L38
M991 S0 P37 ;notify layer change


G17
G3 Z7.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.254
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4454
G1 X122.467 Y134.836 E.02287
G3 X127.824 Y119.199 I5.537 J-6.839 E.7124
G3 X132.78 Y135.389 I.175 J8.8 E.75538
G3 X123.068 Y135.282 I-4.775 J-7.392 E.34129
G1 X123.359 Y135.008 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4454
M204 S6000
G1 X123.25 Y134.938 E.00399
G3 X127.832 Y119.591 I4.75 J-6.939 E.65149
G3 X128.726 Y119.622 I.132 J9.055 E.02751
G1 X128.84 Y119.631 E.00351
G3 X123.82 Y135.295 I-.84 J8.367 E.92033
G1 X123.41 Y135.04 E.01485
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.938 E-.07209
G1 X122.71 Y134.537 E-.2557
G1 X122.452 Y134.32 E-.1279
G1 X121.965 Y133.856 E-.25571
G1 X121.877 Y133.763 E-.04861
; WIPE_END
G1 E-.04 F1800
G1 X129.51 Y133.748 Z8 F36000
G1 X135.442 Y133.737 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4454
G1 X135.402 Y133.777 E.0019
G3 X126.808 Y118.677 I-7.41 J-5.778 E1.22308
G3 X128.281 Y118.607 I1.195 J9.584 E.04897
G3 X135.606 Y133.505 I-.29 J9.392 E.67513
G1 X135.477 Y133.688 E.00744
G1 X135.751 Y133.969 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4454
M204 S6000
G1 X135.488 Y134.295 E.01287
G3 X118.239 Y127.26 I-7.49 J-6.298 E.75713
G3 X128.296 Y118.215 I9.761 J.74 E.45879
G3 X135.925 Y133.736 I-.298 J9.782 E.65163
G1 X135.787 Y133.921 E.00711
M204 S10000
G1 X135.238 Y133.5 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4454
G1 X134.967 Y133.857 E.00689
G3 X118.901 Y128.092 I-6.967 J-5.853 E.34043
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.46 Y133.214 I9.096 J.252 E.52098
G1 X135.274 Y133.452 E.00464
; CHANGE_LAYER
; Z_HEIGHT: 7.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.967 Y133.857 E-.19304
G1 X134.532 Y134.335 E-.24574
G1 X134.287 Y134.578 E-.13105
G1 X133.911 Y134.908 E-.19017
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L39
M991 S0 P38 ;notify layer change


G17
G3 Z8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.03 Y135.259 E.0005
G3 X127.824 Y119.199 I4.977 J-7.26 E.73574
G3 X126.037 Y136.578 I.171 J8.799 E.98828
G3 X123.626 Y135.634 I1.97 J-8.579 E.08621
G1 X123.091 Y135.302 E.02088
G1 X123.347 Y135 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.253 Y134.934 E.00354
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94068
G1 X123.398 Y135.031 E.01529
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.06651
G1 X122.71 Y134.537 E-.25552
G1 X122.452 Y134.32 E-.12802
G1 X121.965 Y133.856 E-.25558
G1 X121.867 Y133.752 E-.05437
; WIPE_END
G1 E-.04 F1800
G1 X129.5 Y133.741 Z8.2 F36000
G1 X135.444 Y133.734 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.402 Y133.777 E.00202
G3 X126.808 Y118.677 I-7.411 J-5.778 E1.22319
G3 X128.294 Y118.607 I1.194 J9.565 E.04939
G3 X135.607 Y133.505 I-.303 J9.392 E.6747
G1 X135.479 Y133.685 E.00731
G1 X135.754 Y133.966 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.492 Y134.299 E.013
G3 X118.24 Y127.247 I-7.492 J-6.299 E.75775
G3 X128.309 Y118.216 I9.772 J.766 E.45864
G3 X135.929 Y133.738 I-.309 J9.784 E.6514
G1 X135.79 Y133.919 E.007
M204 S10000
G1 X135.232 Y133.503 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4449
G1 X135.019 Y133.794 E.00554
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34167
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.562 Y133.064 I9.096 J.252 E.51816
G1 X135.268 Y133.455 E.00752
; CHANGE_LAYER
; Z_HEIGHT: 8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.15979
G1 X134.522 Y134.345 E-.28199
G1 X134.27 Y134.594 E-.13449
M73 P75 R3
G1 X133.908 Y134.914 E-.18373
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L40
M991 S0 P39 ;notify layer change


G17
G3 Z8.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.253
G1 Z8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4450
G1 X122.464 Y134.84 E.02286
G3 X120.09 Y124.142 I5.536 J-6.841 E.39241
G3 X127.824 Y119.199 I7.915 J3.862 E.32027
G3 X126.049 Y136.581 I.171 J8.799 E.98789
G3 X123.066 Y135.286 I1.952 J-8.581 E.10848
G1 X123.335 Y134.993 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4450
M204 S6000
G1 X123.253 Y134.934 E.00311
G3 X127.832 Y119.591 I4.748 J-6.938 E.65132
G3 X129.038 Y119.655 I-.01 J11.539 E.03712
G1 X129.174 Y119.672 E.00423
G3 X123.823 Y135.291 I-1.174 J8.324 E.90966
G1 X123.386 Y135.024 E.01573
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.06118
G1 X122.71 Y134.537 E-.25552
G1 X122.452 Y134.32 E-.12802
G1 X121.965 Y133.856 E-.25564
G1 X121.858 Y133.741 E-.05964
; WIPE_END
G1 E-.04 F1800
G1 X129.49 Y133.735 Z8.4 F36000
G1 X135.447 Y133.731 Z8.4
G1 Z8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4450
G1 X135.401 Y133.777 E.00215
G3 X126.808 Y118.677 I-7.41 J-5.778 E1.22311
G3 X128.307 Y118.608 I1.193 J9.553 E.04982
G3 X135.606 Y133.504 I-.317 J9.391 E.67422
G1 X135.481 Y133.681 E.00719
G1 X135.756 Y133.963 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4450
M204 S6000
G1 X135.488 Y134.296 E.01312
G3 X118.242 Y127.234 I-7.49 J-6.298 E.75792
G3 X125.505 Y118.534 I9.759 J.765 E.3714
G3 X128.322 Y118.216 I2.495 J9.472 E.08739
G3 X135.926 Y133.735 I-.323 J9.781 E.65082
G1 X135.792 Y133.915 E.00688
M204 S10000
G1 X135.234 Y133.5 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4450
G1 X135.019 Y133.794 E.0056
G3 X118.901 Y128.092 I-7.019 J-5.791 E.34168
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.562 Y133.064 I9.096 J.252 E.5182
G1 X135.271 Y133.452 E.00746
; CHANGE_LAYER
; Z_HEIGHT: 8.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.16122
G1 X134.522 Y134.345 E-.28221
G1 X134.27 Y134.594 E-.13435
G1 X133.911 Y134.912 E-.18222
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L41
M991 S0 P40 ;notify layer change


G17
G3 Z8.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z8.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.029 Y135.261 E.00049
G3 X127.824 Y119.199 I4.972 J-7.262 E.73605
G3 X126.06 Y136.583 I.175 J8.799 E.98788
G3 X123.625 Y135.635 I1.941 J-8.585 E.08699
G1 X123.091 Y135.302 E.02088
G1 X123.324 Y134.985 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.25 Y134.938 E.00269
G3 X127.832 Y119.591 I4.75 J-6.939 E.65149
G3 X128.691 Y119.619 I.132 J9.01 E.02643
G1 X128.84 Y119.631 E.00458
G3 X123.82 Y135.295 I-.84 J8.367 E.92033
G1 X123.374 Y135.017 E.01614
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.938 E-.05613
G1 X122.71 Y134.537 E-.25563
G1 X122.452 Y134.32 E-.12796
G1 X121.965 Y133.856 E-.25571
G1 X121.849 Y133.732 E-.06458
; WIPE_END
G1 E-.04 F1800
G1 X129.481 Y133.729 Z8.6 F36000
G1 X135.449 Y133.727 Z8.6
G1 Z8.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.402 Y133.777 E.00228
G3 X126.808 Y118.677 I-7.411 J-5.778 E1.2232
G3 X128.32 Y118.608 I1.192 J9.543 E.05025
G3 X135.607 Y133.504 I-.33 J9.391 E.6738
G1 X135.484 Y133.678 E.00707
G1 X135.756 Y133.958 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.387 Y134.415 E.01805
G3 X125.518 Y118.531 I-7.387 J-6.418 E1.1248
G3 X128.334 Y118.217 I2.482 J9.472 E.08739
G3 X135.926 Y133.736 I-.335 J9.78 E.65048
G1 X135.793 Y133.911 E.00676
M204 S10000
G1 X135.237 Y133.497 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231608
G1 F4449
G1 X135.018 Y133.793 E.00566
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34166
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.561 Y133.064 I9.096 J.252 E.51815
G1 X135.273 Y133.449 E.00739
; CHANGE_LAYER
; Z_HEIGHT: 8.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.018 Y133.793 E-.16269
G1 X134.522 Y134.345 E-.28215
G1 X134.27 Y134.594 E-.13441
M73 P76 R3
G1 X133.914 Y134.909 E-.18075
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L42
M991 S0 P41 ;notify layer change


G17
G3 Z8.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.032 Y135.257
G1 Z8.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X122.743 Y135.055 E.01167
G3 X125.237 Y119.644 I5.261 J-7.056 E.63681
G3 X127.824 Y119.199 I2.783 J8.438 E.08738
G3 X126.071 Y136.586 I.171 J8.799 E.98711
G3 X123.324 Y135.453 I1.933 J-8.587 E.09906
G1 X123.081 Y135.29 E.00969
G1 X123.313 Y134.979 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.25 Y134.937 E.00232
G3 X127.832 Y119.591 I4.75 J-6.939 E.65148
G3 X129.014 Y119.652 I-.015 J11.701 E.0364
G1 X129.174 Y119.672 E.00495
G3 X123.82 Y135.295 I-1.174 J8.327 E.90998
G1 X123.364 Y135.011 E.01652
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.937 E-.05143
G1 X122.71 Y134.537 E-.25558
G1 X122.452 Y134.32 E-.12796
G1 X121.965 Y133.856 E-.25571
G1 X121.84 Y133.723 E-.06932
; WIPE_END
G1 E-.04 F1800
G1 X129.473 Y133.726 Z8.8 F36000
G1 X135.446 Y133.729 Z8.8
G1 Z8.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.402 Y133.777 E.00218
G3 X126.808 Y118.677 I-7.411 J-5.778 E1.2232
G3 X128.333 Y118.609 I1.192 J9.538 E.05068
G3 X135.801 Y133.225 I-.343 J9.391 E.66207
G1 X135.481 Y133.68 E.01847
G1 X135.761 Y133.957 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.492 Y134.299 E.01336
G3 X118.244 Y127.208 I-7.492 J-6.299 E.75894
G3 X125.53 Y118.527 I9.756 J.791 E.3714
G3 X128.347 Y118.217 I2.47 J9.473 E.08739
G3 X135.929 Y133.738 I-.347 J9.782 E.6502
G1 X135.797 Y133.909 E.00664
M204 S10000
G1 X135.247 Y133.487 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231605
G1 F4449
G1 X134.967 Y133.857 E.00713
G3 X118.901 Y128.092 I-6.967 J-5.854 E.34042
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.46 Y133.214 I9.096 J.252 E.52099
G1 X135.284 Y133.44 E.0044
; CHANGE_LAYER
; Z_HEIGHT: 8.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X134.967 Y133.857 E-.19908
G1 X134.532 Y134.335 E-.24572
G1 X134.287 Y134.578 E-.13095
G1 X133.923 Y134.898 E-.18425
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L43
M991 S0 P42 ;notify layer change


G17
G3 Z8.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z8.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.029 Y135.261 E.00049
G3 X127.824 Y119.199 I4.972 J-7.262 E.73605
G3 X126.083 Y136.588 I.173 J8.799 E.98689
G3 X123.625 Y135.635 I1.918 J-8.59 E.08777
G1 X123.091 Y135.302 E.02088
G1 X123.303 Y134.973 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.253 Y134.934 E.00196
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G3 X128.668 Y119.617 I.132 J9.018 E.02572
G1 X128.84 Y119.631 E.0053
G3 X123.822 Y135.291 I-.84 J8.365 E.92001
G1 X123.354 Y135.004 E.01687
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.04693
G1 X122.71 Y134.537 E-.25563
G1 X122.452 Y134.32 E-.12796
G1 X121.965 Y133.856 E-.25565
G1 X121.832 Y133.714 E-.07383
; WIPE_END
G1 E-.04 F1800
G1 X129.465 Y133.721 Z9 F36000
G1 X135.448 Y133.726 Z9
G1 Z8.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.402 Y133.777 E.0023
G3 X126.808 Y118.677 I-7.411 J-5.778 E1.2232
G3 X128.346 Y118.609 I1.192 J9.535 E.05111
G3 X135.801 Y133.225 I-.355 J9.39 E.66164
G1 X135.483 Y133.677 E.01835
G1 X135.766 Y133.956 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.71 Y134.018 E.00257
G3 X126.759 Y118.288 I-7.72 J-6.019 E1.18034
G3 X128.36 Y118.217 I1.241 J9.935 E.04932
G3 X136.127 Y133.443 I-.37 J9.782 E.63846
G1 X135.8 Y133.907 E.01743
M204 S10000
G1 X135.239 Y133.503 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4449
G3 X118.912 Y128.456 I-7.24 J-5.511 E.34134
G1 X118.901 Y128.088 E.00566
G3 X135.275 Y133.456 I9.098 J-.096 E.5311
; CHANGE_LAYER
; Z_HEIGHT: 8.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.747 Y134.105 E-.31776
G1 X134.521 Y134.346 E-.1256
G1 X134.043 Y134.802 E-.25113
G1 X133.91 Y134.911 E-.06551
; WIPE_END
M73 P77 R3
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L44
M991 S0 P43 ;notify layer change


G17
G3 Z9 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z8.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4451
G1 X123.029 Y135.261 E.00049
G3 X127.824 Y119.199 I4.972 J-7.262 E.73605
G3 X126.094 Y136.591 I.171 J8.799 E.98634
G3 X123.625 Y135.635 I1.907 J-8.592 E.08816
G1 X123.091 Y135.302 E.02088
G1 X123.294 Y134.967 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4451
M204 S6000
G1 X123.253 Y134.934 E.00163
G3 X127.832 Y119.591 I4.747 J-6.938 E.65132
G3 X128.991 Y119.649 I-.021 J11.915 E.03569
G1 X129.174 Y119.672 E.00567
G3 X123.822 Y135.291 I-1.174 J8.324 E.90967
G1 X123.345 Y134.998 E.0172
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.04283
G1 X122.71 Y134.537 E-.25563
G1 X122.452 Y134.32 E-.1279
G1 X121.965 Y133.856 E-.25571
G1 X121.825 Y133.706 E-.07794
; WIPE_END
G1 E-.04 F1800
G1 X129.457 Y133.715 Z9.2 F36000
G1 X135.451 Y133.723 Z9.2
G1 Z8.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4451
G1 X135.401 Y133.777 E.00243
G3 X126.808 Y118.677 I-7.41 J-5.778 E1.22311
G3 X128.359 Y118.61 I1.192 J9.535 E.05154
G3 X135.801 Y133.224 I-.368 J9.389 E.6612
G1 X135.485 Y133.674 E.01821
G1 X135.766 Y133.951 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4451
M204 S6000
G1 X135.492 Y134.299 E.0136
G3 X118.421 Y130.011 I-7.492 J-6.299 E.67235
G3 X118.246 Y127.182 I9.833 J-2.028 E.08737
G3 X128.373 Y118.218 I9.762 J.825 E.4587
G3 X135.929 Y133.738 I-.373 J9.781 E.64941
G1 X135.802 Y133.903 E.0064
M204 S10000
G1 X135.24 Y133.504 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4451
G3 X118.912 Y128.456 I-7.24 J-5.512 E.34135
G1 X118.901 Y128.088 E.00566
G3 X135.276 Y133.456 I9.099 J-.096 E.53114
; CHANGE_LAYER
; Z_HEIGHT: 9
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.748 Y134.104 E-.31768
G1 X134.522 Y134.345 E-.12555
G1 X134.044 Y134.802 E-.25116
G1 X133.91 Y134.911 E-.06562
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L45
M991 S0 P44 ;notify layer change


G17
G3 Z9.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z9
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4451
G1 X123.029 Y135.261 E.00049
G3 X127.824 Y119.199 I4.972 J-7.262 E.73606
G3 X129.949 Y136.581 I.176 J8.8 E.85785
G3 X126.106 Y136.593 I-1.949 J-8.809 E.12846
G3 X123.625 Y135.635 I1.895 J-8.595 E.08855
G1 X123.091 Y135.302 E.02088
G1 X123.285 Y134.962 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4451
M204 S6000
G1 X123.253 Y134.934 E.00132
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G3 X128.98 Y119.648 I-.025 J12.045 E.03533
G1 X129.174 Y119.672 E.00603
G3 X123.822 Y135.291 I-1.174 J8.324 E.90967
G1 X123.337 Y134.993 E.01751
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.03903
G1 X122.71 Y134.537 E-.25558
G1 X122.452 Y134.32 E-.12796
G1 X121.965 Y133.856 E-.25571
G1 X121.818 Y133.699 E-.08173
; WIPE_END
G1 E-.04 F1800
G1 X129.45 Y133.708 Z9.4 F36000
G1 X135.458 Y133.715 Z9.4
G1 Z9
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4451
G1 X135.401 Y133.777 E.0028
G3 X126.808 Y118.677 I-7.41 J-5.778 E1.2231
G3 X128.372 Y118.61 I1.192 J9.54 E.05197
G3 X135.606 Y133.504 I-.381 J9.389 E.67209
G1 X135.493 Y133.666 E.00655
G1 X135.768 Y133.948 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4451
M204 S6000
G1 X135.492 Y134.298 E.01372
G3 X118.418 Y129.998 I-7.492 J-6.299 E.67275
G3 X128.386 Y118.218 I9.582 J-1.999 E.54618
G3 X135.929 Y133.738 I-.386 J9.781 E.64901
G1 X135.805 Y133.9 E.00628
M204 S10000
G1 X135.246 Y133.484 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4451
G1 X135.018 Y133.793 E.0059
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34165
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.561 Y133.064 I9.096 J.252 E.51815
G1 X135.282 Y133.436 E.00716
; CHANGE_LAYER
; Z_HEIGHT: 9.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
M73 P78 R3
G1 X135.018 Y133.793 E-.1687
G1 X134.522 Y134.345 E-.28206
G1 X134.27 Y134.594 E-.13442
G1 X133.926 Y134.899 E-.17481
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L46
M991 S0 P45 ;notify layer change


G17
G3 Z9.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.254
G1 Z9.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X122.464 Y134.84 E.02287
G3 X125.193 Y119.658 I5.536 J-6.841 E.62374
G3 X127.824 Y119.199 I2.828 J8.426 E.08893
G3 X134.22 Y134.225 I.175 J8.8 E.69389
G3 X123.066 Y135.286 I-6.22 J-6.226 E.40288
G1 X123.278 Y134.957 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X123.253 Y134.934 E.00104
G3 X127.832 Y119.591 I4.747 J-6.938 E.65132
G3 X128.968 Y119.647 I-.03 J12.195 E.03497
G1 X129.174 Y119.672 E.00639
G3 X123.822 Y135.291 I-1.174 J8.324 E.90967
G1 X123.329 Y134.988 E.01779
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.03554
G1 X122.71 Y134.537 E-.25563
G1 X122.452 Y134.32 E-.12796
G1 X121.965 Y133.856 E-.25564
G1 X121.812 Y133.692 E-.08522
; WIPE_END
G1 E-.04 F1800
G1 X129.444 Y133.706 Z9.6 F36000
G1 X135.455 Y133.717 Z9.6
G1 Z9.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X135.4 Y133.776 E.00269
G3 X127.148 Y118.64 I-7.412 J-5.777 E1.23461
G3 X128.385 Y118.611 I.922 J12.798 E.04105
G3 X135.8 Y133.224 I-.396 J9.389 E.66026
G1 X135.49 Y133.667 E.01796
G1 X135.77 Y133.945 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.492 Y134.298 E.01384
G3 X118.415 Y129.986 I-7.492 J-6.299 E.67315
G3 X118.248 Y127.157 I9.594 J-1.987 E.08739
G3 X118.473 Y125.754 I9.799 J.85 E.04369
G3 X125.58 Y118.514 I9.525 J2.243 E.32772
G3 X128.399 Y118.219 I2.421 J9.495 E.08739
G3 X135.929 Y133.738 I-.399 J9.78 E.64862
G1 X135.807 Y133.897 E.00616
M204 S10000
G1 X135.257 Y133.475 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4455
G1 X134.967 Y133.857 E.00738
G3 X118.901 Y128.092 I-6.967 J-5.854 E.34042
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.458 Y133.218 I9.096 J.252 E.52105
G1 X135.294 Y133.427 E.0041
; CHANGE_LAYER
; Z_HEIGHT: 9.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.967 Y133.857 E-.2052
G1 X134.532 Y134.335 E-.2456
G1 X134.287 Y134.578 E-.13104
G1 X133.935 Y134.887 E-.17816
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L47
M991 S0 P46 ;notify layer change


G17
G3 Z9.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z9.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.03 Y135.259 E.00051
G3 X125.182 Y119.662 I4.977 J-7.26 E.64643
G3 X127.824 Y119.199 I2.839 J8.424 E.08932
G3 X126.474 Y136.666 I.175 J8.8 E.97387
G3 X123.626 Y135.633 I1.533 J-8.668 E.10098
G1 X123.091 Y135.302 E.02089
G1 X123.271 Y134.952 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.25 Y134.937 E.00078
G3 X127.832 Y119.591 I4.75 J-6.939 E.65148
G3 X128.956 Y119.645 I-.035 J12.366 E.03461
G1 X129.174 Y119.672 E.00675
G3 X123.82 Y135.295 I-1.174 J8.327 E.90997
G1 X123.321 Y134.984 E.01806
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.937 E-.0324
G1 X122.71 Y134.537 E-.25558
G1 X122.452 Y134.32 E-.12802
G1 X121.965 Y133.856 E-.25565
G1 X121.806 Y133.686 E-.08836
; WIPE_END
G1 E-.04 F1800
G1 X129.439 Y133.699 Z9.8 F36000
G1 X135.463 Y133.709 Z9.8
G1 Z9.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.401 Y133.777 E.00306
G3 X127.148 Y118.64 I-7.411 J-5.777 E1.23459
G3 X128.398 Y118.611 I.919 J12.73 E.04148
G3 X135.606 Y133.504 I-.408 J9.388 E.67118
G1 X135.497 Y133.659 E.00629
G1 X135.773 Y133.941 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.492 Y134.298 E.01396
G3 X118.475 Y125.741 I-7.492 J-6.299 E.80463
G3 X128.412 Y118.219 I9.523 J2.256 E.41512
G3 X135.929 Y133.738 I-.412 J9.78 E.64822
G1 X135.809 Y133.894 E.00604
M204 S10000
G1 X135.251 Y133.478 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4449
G1 X135.019 Y133.794 E.00602
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34166
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.562 Y133.064 I9.096 J.252 E.51816
G1 X135.287 Y133.43 E.00704
; CHANGE_LAYER
; Z_HEIGHT: 9.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
M73 P79 R3
G1 X135.019 Y133.794 E-.17159
G1 X134.522 Y134.345 E-.28216
G1 X134.27 Y134.594 E-.13434
G1 X133.932 Y134.894 E-.1719
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L48
M991 S0 P47 ;notify layer change


G17
G3 Z9.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.032 Y135.257
G1 Z9.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X122.744 Y135.054 E.01168
G3 X127.824 Y119.199 I5.263 J-7.055 E.72406
G3 X126.485 Y136.669 I.175 J8.8 E.97349
G3 X123.324 Y135.452 I1.522 J-8.67 E.11306
G1 X123.082 Y135.29 E.00969
G1 X123.264 Y134.948 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.25 Y134.938 E.00054
M73 P79 R2
G3 X127.832 Y119.591 I4.75 J-6.939 E.65149
G3 X128.61 Y119.613 I.129 J9.251 E.02392
G1 X128.84 Y119.631 E.00709
G3 X123.82 Y135.295 I-.84 J8.367 E.92033
G1 X123.315 Y134.98 E.01829
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.938 E-.02942
G1 X122.71 Y134.537 E-.25564
G1 X122.452 Y134.32 E-.12796
G1 X121.965 Y133.856 E-.25571
G1 X121.801 Y133.68 E-.09128
; WIPE_END
G1 E-.04 F1800
G1 X129.433 Y133.697 Z10 F36000
G1 X135.46 Y133.71 Z10
G1 Z9.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.401 Y133.777 E.00295
G3 X127.148 Y118.64 I-7.411 J-5.778 E1.23454
G3 X128.411 Y118.612 I.917 J12.673 E.04191
G3 X135.801 Y133.225 I-.42 J9.388 E.6595
G1 X135.494 Y133.661 E.01769
G1 X135.777 Y133.94 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.71 Y134.018 E.00316
G3 X127.112 Y118.25 I-7.72 J-6.019 E1.19128
G3 X128.425 Y118.22 I.956 J13.211 E.04036
G3 X136.126 Y133.443 I-.435 J9.779 E.63647
G1 X135.812 Y133.891 E.01682
M204 S10000
G1 X135.253 Y133.475 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231605
G1 F4449
G1 X135.019 Y133.793 E.00608
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34166
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.561 Y133.064 I9.096 J.252 E.51816
G1 X135.289 Y133.427 E.00697
; CHANGE_LAYER
; Z_HEIGHT: 9.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.793 E-.17306
G1 X134.522 Y134.345 E-.28221
G1 X134.27 Y134.594 E-.13433
G1 X133.934 Y134.891 E-.1704
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L49
M991 S0 P48 ;notify layer change


G17
G3 Z10 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.254
G1 Z9.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4451
G1 X122.467 Y134.836 E.02287
G3 X119.31 Y129.389 I5.556 J-6.859 E.21357
G3 X127.824 Y119.199 I8.693 J-1.388 E.49902
G3 X130.699 Y119.623 I.115 J9.188 E.09681
G3 X126.151 Y136.604 I-2.699 J8.377 E.88792
G3 X123.068 Y135.282 I1.872 J-8.627 E.11196
G1 X123.258 Y134.944 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4451
M204 S6000
G1 X123.25 Y134.938 E.00032
G3 X127.832 Y119.591 I4.75 J-6.939 E.65149
G1 X128.168 Y119.591 E.01034
G3 X123.82 Y135.295 I-.168 J8.408 E.94101
G1 X123.309 Y134.976 E.01851
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.938 E-.02677
G1 X122.71 Y134.537 E-.2557
G1 X122.452 Y134.32 E-.1279
G1 X121.965 Y133.856 E-.25571
G1 X121.796 Y133.675 E-.09393
; WIPE_END
G1 E-.04 F1800
G1 X129.429 Y133.693 Z10.2 F36000
G1 X135.462 Y133.707 Z10.2
G1 Z9.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4451
G1 X135.402 Y133.777 E.00307
G3 X127.148 Y118.64 I-7.411 J-5.778 E1.23449
G3 X128.424 Y118.612 I.915 J12.626 E.04234
G3 X135.801 Y133.225 I-.432 J9.387 E.65911
G1 X135.497 Y133.658 E.01756
G1 X135.78 Y133.937 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4451
M204 S6000
G1 X135.712 Y134.02 E.00328
G3 X118.786 Y124.694 I-7.714 J-6.023 E.84886
G3 X128.438 Y118.22 I9.229 J3.327 E.38221
G3 X136.129 Y133.444 I-.439 J9.777 E.63636
G1 X135.814 Y133.888 E.01671
M204 S10000
G1 X135.255 Y133.472 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4451
G1 X135.018 Y133.793 E.00614
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34166
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.561 Y133.064 I9.095 J.252 E.51815
G1 X135.291 Y133.424 E.00692
; CHANGE_LAYER
; Z_HEIGHT: 10
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
M73 P80 R2
G1 X135.018 Y133.793 E-.17452
G1 X134.522 Y134.345 E-.28224
G1 X134.27 Y134.594 E-.13433
G1 X133.937 Y134.888 E-.16891
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L50
M991 S0 P49 ;notify layer change


G17
G3 Z10.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z10
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.029 Y135.261 E.00049
G3 X127.824 Y119.199 I4.973 J-7.262 E.73606
G3 X136.173 Y124.735 I.172 J8.805 E.35349
G3 X126.163 Y136.606 I-8.174 J3.264 E.63089
G3 X123.625 Y135.635 I1.839 J-8.607 E.09049
G1 X123.091 Y135.302 E.02088
G1 X123.253 Y134.941 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.251 Y134.936 E.00016
G3 X127.832 Y119.591 I4.749 J-6.939 E.65144
G1 X128.168 Y119.591 E.01034
G3 X123.821 Y135.294 I-.168 J8.407 E.94091
G1 X123.304 Y134.973 E.0187
; WIPE_START
G1 F12000
M204 S10000
G1 X123.251 Y134.936 E-.02443
G1 X122.71 Y134.537 E-.25562
G1 X122.452 Y134.32 E-.12796
G1 X121.965 Y133.856 E-.25565
G1 X121.792 Y133.671 E-.09635
; WIPE_END
G1 E-.04 F1800
G1 X129.424 Y133.687 Z10.4 F36000
G1 X135.47 Y133.699 Z10.4
G1 Z10
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.401 Y133.776 E.00344
G3 X127.488 Y118.615 I-7.411 J-5.777 E1.2459
G3 X128.436 Y118.613 I.504 J10.216 E.03148
G3 X135.605 Y133.504 I-.447 J9.386 E.66991
G1 X135.504 Y133.65 E.00589
G1 X135.784 Y133.935 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.711 Y134.019 E.0034
G3 X127.112 Y118.25 I-7.72 J-6.02 E1.19119
G3 X128.451 Y118.221 I.952 J13.12 E.04115
G3 X135.924 Y133.735 I-.459 J9.778 E.64667
G1 X135.818 Y133.886 E.00568
M204 S10000
G1 X135.266 Y133.462 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231524
G1 F4449
G1 X134.966 Y133.856 E.00761
G3 X118.901 Y128.092 I-6.967 J-5.853 E.34025
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.459 Y133.214 I9.096 J.252 E.52072
G1 X135.303 Y133.415 E.00391
; CHANGE_LAYER
; Z_HEIGHT: 10.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.966 Y133.856 E-.21102
G1 X134.532 Y134.335 E-.24552
G1 X134.287 Y134.578 E-.1311
G1 X133.946 Y134.877 E-.17237
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L51
M991 S0 P50 ;notify layer change


G17
G3 Z10.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z10.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.261 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06288
G1 X123.091 Y135.302 E.02087
G1 X123.248 Y134.938 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X122.713 Y134.532 E.02062
G3 X127.832 Y119.591 I5.287 J-6.536 E.63067
G1 X128.168 Y119.591 E.01034
G3 X123.297 Y134.964 I-.168 J8.405 E.9597
; WIPE_START
G1 F12000
M204 S10000
G1 X122.713 Y134.532 E-.27593
G1 X122.452 Y134.32 E-.12787
G1 X121.965 Y133.856 E-.25578
G1 X121.784 Y133.663 E-.10043
; WIPE_END
G1 E-.04 F1800
G1 X129.417 Y133.684 Z10.6 F36000
G1 X135.467 Y133.701 Z10.6
G1 Z10.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X135.4 Y133.776 E.00332
G3 X127.488 Y118.615 I-7.41 J-5.777 E1.24577
G3 X128.441 Y118.613 I.504 J10.23 E.03161
G3 X135.799 Y133.224 I-.451 J9.386 E.65846
G1 X135.501 Y133.652 E.01731
G1 X135.786 Y133.932 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.709 Y134.017 E.00352
G3 X127.467 Y118.224 I-7.719 J-6.019 E1.20211
G3 X128.461 Y118.221 I.525 J10.661 E.03055
G3 X135.922 Y133.733 I-.471 J9.777 E.64625
G1 X135.82 Y133.882 E.00557
M204 S10000
G1 X135.269 Y133.459 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231527
G1 F4455
G1 X134.962 Y133.854 E.00767
G3 X118.91 Y128.386 I-6.962 J-5.857 E.33551
G1 X118.901 Y128.088 E.00458
G3 X118.923 Y127.364 I9.07 J-.086 E.01114
G1 X118.94 Y127.162 E.00312
G3 X135.453 Y133.215 I9.06 J.834 E.51187
G1 X135.305 Y133.411 E.00379
; CHANGE_LAYER
; Z_HEIGHT: 10.4
; LAYER_HEIGHT: 0.2
; WIPE_START
M73 P81 R2
G1 F15000
G1 X134.962 Y133.854 E-.21245
G1 X134.532 Y134.335 E-.24544
G1 X134.287 Y134.578 E-.13133
G1 X133.949 Y134.875 E-.17078
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L52
M991 S0 P51 ;notify layer change


G17
G3 Z10.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z10.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.261 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06287
G1 X123.091 Y135.302 E.02088
G1 X123.244 Y134.935 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X122.713 Y134.532 E.02047
G3 X127.832 Y119.591 I5.287 J-6.536 E.63067
G1 X128.168 Y119.591 E.01034
G3 X123.295 Y134.963 I-.168 J8.405 E.95978
; WIPE_START
G1 F12000
M204 S10000
G1 X122.713 Y134.532 E-.27496
G1 X122.452 Y134.32 E-.12793
G1 X121.965 Y133.856 E-.25564
G1 X121.783 Y133.661 E-.10146
; WIPE_END
G1 E-.04 F1800
G1 X129.415 Y133.681 Z10.8 F36000
G1 X135.469 Y133.698 Z10.8
G1 Z10.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X135.401 Y133.779 E.00351
G3 X127.488 Y118.615 I-7.41 J-5.78 E1.24574
G3 X128.453 Y118.613 I.505 J10.28 E.03202
G3 X135.801 Y133.225 I-.462 J9.386 E.65816
G1 X135.503 Y133.649 E.01717
G1 X135.786 Y133.927 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.711 Y134.019 E.00365
G3 X127.467 Y118.224 I-7.719 J-6.02 E1.20212
G3 X128.473 Y118.222 I.527 J10.712 E.03094
G3 X136.127 Y133.443 I-.482 J9.777 E.63505
G1 X135.821 Y133.878 E.01635
M204 S10000
G1 X135.271 Y133.456 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231581
G1 F4455
G1 X134.961 Y133.851 E.00772
G3 X118.91 Y128.399 I-6.96 J-5.861 E.33528
G1 X118.901 Y128.088 E.00477
G3 X118.904 Y127.728 I57.623 J.41 E.00554
G1 X118.919 Y127.421 E.00473
G3 X135.454 Y133.21 I9.082 J.569 E.5162
G1 X135.306 Y133.408 E.0038
; CHANGE_LAYER
; Z_HEIGHT: 10.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X134.961 Y133.851 E-.21354
G1 X134.532 Y134.335 E-.2457
G1 X134.287 Y134.578 E-.13106
G1 X133.952 Y134.873 E-.1697
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L53
M991 S0 P52 ;notify layer change


G17
G3 Z10.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z10.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4454
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.261 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06287
G1 X123.091 Y135.302 E.02088
G1 X123.24 Y134.932 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4454
M204 S6000
G1 X122.713 Y134.532 E.02033
G3 X127.832 Y119.591 I5.287 J-6.536 E.63067
G1 X128.168 Y119.591 E.01034
G3 X123.292 Y134.961 I-.168 J8.405 E.95989
; WIPE_START
G1 F12000
M204 S10000
G1 X122.713 Y134.532 E-.27358
G1 X122.452 Y134.32 E-.12793
G1 X121.965 Y133.856 E-.25578
G1 X121.78 Y133.658 E-.10271
; WIPE_END
G1 E-.04 F1800
G1 X129.413 Y133.671 Z11 F36000
G1 X135.478 Y133.682 Z11
G1 Z10.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4454
G1 X135.184 Y134.041 E.0154
G3 X127.489 Y118.615 I-7.191 J-6.045 E1.23399
G3 X128.466 Y118.614 I.505 J10.324 E.0324
G3 X135.605 Y133.503 I-.473 J9.383 E.669
G1 X135.513 Y133.633 E.00528
G1 X135.787 Y133.923 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4454
M204 S6000
G1 X135.485 Y134.293 E.01468
G3 X127.467 Y118.224 I-7.492 J-6.297 E1.19074
G3 X128.486 Y118.222 I.527 J10.763 E.03132
G3 X135.922 Y133.733 I-.493 J9.774 E.64553
G1 X135.822 Y133.874 E.00533
M204 S10000
G1 X135.265 Y133.459 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231599
G1 F4454
G1 X135.014 Y133.79 E.00638
G3 X118.91 Y128.411 I-7.014 J-5.797 E.33646
M73 P82 R2
G1 X118.901 Y128.088 E.00497
G3 X118.904 Y127.728 I9.83 J-.079 E.00553
G1 X118.919 Y127.421 E.00472
G3 X135.557 Y133.061 I9.081 J.572 E.51335
G1 X135.3 Y133.411 E.00667
; CHANGE_LAYER
; Z_HEIGHT: 10.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.014 Y133.79 E-.18046
G1 X134.522 Y134.346 E-.28219
G1 X134.268 Y134.596 E-.13519
G1 X133.949 Y134.878 E-.16216
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L54
M991 S0 P53 ;notify layer change


G17
G3 Z11 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z10.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X123.03 Y135.257 E.00055
G3 X127.824 Y119.199 I4.97 J-7.261 E.73591
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06287
G1 X123.091 Y135.301 E.02089
G1 X123.237 Y134.93 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X122.713 Y134.532 E.02022
G3 X127.832 Y119.591 I5.287 J-6.536 E.63067
G1 X128.168 Y119.591 E.01034
G3 X123.289 Y134.959 I-.168 J8.405 E.95999
; WIPE_START
G1 F12000
M204 S10000
G1 X122.713 Y134.532 E-.27236
G1 X122.452 Y134.32 E-.12781
G1 X121.965 Y133.856 E-.25577
G1 X121.778 Y133.656 E-.10407
; WIPE_END
G1 E-.04 F1800
G1 X129.41 Y133.665 Z11.2 F36000
G1 X135.482 Y133.672 Z11.2
G1 Z10.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X134.986 Y134.275 E.02591
G3 X127.83 Y118.603 I-6.994 J-6.276 E1.23555
G3 X128.478 Y118.614 I.17 J8.93 E.02153
G3 X135.606 Y133.505 I-.486 J9.384 E.66868
G1 X135.518 Y133.623 E.00489
G1 X135.793 Y133.923 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.711 Y134.019 E.00388
G3 X127.823 Y118.211 I-7.719 J-6.02 E1.213
G3 X128.499 Y118.223 I.177 J9.309 E.02079
G3 X135.924 Y133.735 I-.507 J9.776 E.64521
G1 X135.827 Y133.873 E.0052
M204 S10000
G1 X135.262 Y133.473 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231594
G1 F4455
G1 X135.168 Y133.595 E.00237
G3 X118.911 Y128.423 I-7.169 J-5.603 E.34004
G1 X118.901 Y128.088 E.00516
G1 X118.904 Y127.751 E.00518
G3 X135.656 Y132.907 I9.096 J.241 E.51561
G1 X135.296 Y133.423 E.00968
; CHANGE_LAYER
; Z_HEIGHT: 11
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.168 Y133.595 E-.08128
G1 X134.779 Y134.069 E-.23318
G1 X134.52 Y134.346 E-.14393
G1 X134.27 Y134.594 E-.13384
G1 X133.939 Y134.887 E-.16777
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L55
M991 S0 P54 ;notify layer change


G17
G3 Z11.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z11
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.262 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06287
G1 X123.091 Y135.302 E.02087
G1 X123.235 Y134.928 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X122.713 Y134.532 E.02012
G3 X127.832 Y119.591 I5.287 J-6.536 E.63067
G1 X128.168 Y119.591 E.01034
G3 X123.287 Y134.957 I-.168 J8.405 E.96008
; WIPE_START
G1 F12000
M204 S10000
G1 X122.713 Y134.532 E-.27119
G1 X122.452 Y134.32 E-.128
G1 X121.965 Y133.856 E-.25557
G1 X121.78 Y133.65 E-.10524
; WIPE_END
G1 E-.04 F1800
G1 X129.412 Y133.672 Z11.4 F36000
G1 X135.476 Y133.689 Z11.4
G1 Z11
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X135.413 Y133.759 E.00314
G3 X128.17 Y118.603 I-7.423 J-5.761 E1.26918
G1 X128.491 Y118.615 E.01064
G3 X135.799 Y133.223 I-.502 J9.383 E.65678
G1 X135.51 Y133.64 E.01681
G1 X135.793 Y133.918 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.726 Y134.003 E.00334
G3 X127.823 Y118.211 I-7.731 J-6.005 E1.21351
G3 X128.512 Y118.223 I.177 J9.487 E.02119
G3 X136.129 Y133.444 I-.517 J9.775 E.63403
G1 X135.828 Y133.869 E.01601
M204 S10000
G1 X135.269 Y133.453 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231609
G1 F4455
G1 X135.019 Y133.793 E.00649
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34167
M73 P83 R2
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.561 Y133.064 I9.096 J.252 E.51815
G1 X135.305 Y133.405 E.00656
; CHANGE_LAYER
; Z_HEIGHT: 11.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.793 E-.18323
G1 X134.515 Y134.352 E-.28608
G1 X134.27 Y134.594 E-.13049
G1 X133.955 Y134.873 E-.16019
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L56
M991 S0 P55 ;notify layer change


G17
G3 Z11.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.31 Y135.447
G1 Z11.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4465
G1 X122.745 Y135.053 E.02285
G3 X127.472 Y119.213 I5.255 J-7.057 E.71259
G1 X127.824 Y119.199 E.01169
G3 X123.363 Y135.473 I.176 J8.797 E1.08478
G1 X123.237 Y134.922 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4465
M204 S6000
G1 X122.979 Y134.738 E.00972
G3 X127.495 Y119.604 I5.021 J-6.743 E.63067
G1 X127.832 Y119.591 E.01034
G3 X123.534 Y135.118 I.168 J8.405 E.96135
G1 X123.287 Y134.955 E.0091
; WIPE_START
G1 F12000
M204 S10000
G1 X122.979 Y134.738 E-.14296
G1 X122.71 Y134.537 E-.12782
G1 X122.204 Y134.093 E-.25579
G1 X121.776 Y133.652 E-.23344
; WIPE_END
G1 E-.04 F1800
G1 X129.409 Y133.67 Z11.6 F36000
G1 X135.478 Y133.685 Z11.6
G1 Z11.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4465
G1 X135.401 Y133.777 E.00396
G3 X128.17 Y118.603 I-7.405 J-5.781 E1.26778
G1 X128.504 Y118.615 E.01106
G3 X135.801 Y133.225 I-.507 J9.381 E.65663
G1 X135.512 Y133.636 E.01668
G1 X135.795 Y133.915 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4465
M204 S6000
G1 X135.71 Y134.018 E.0041
G3 X128.177 Y118.211 I-7.714 J-6.022 E1.22335
G1 X128.525 Y118.223 E.01068
G3 X136.127 Y133.443 I-.529 J9.772 E.63361
G1 X135.83 Y133.866 E.01589
M204 S10000
G1 X135.28 Y133.444 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.2316
G1 F4465
G1 X134.966 Y133.856 E.00797
G3 X118.901 Y128.092 I-6.967 J-5.853 E.34039
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.459 Y133.214 I9.096 J.252 E.52092
G1 X135.317 Y133.397 E.00356
; CHANGE_LAYER
; Z_HEIGHT: 11.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.966 Y133.856 E-.21972
G1 X134.532 Y134.335 E-.24553
G1 X134.287 Y134.578 E-.13132
G1 X133.963 Y134.862 E-.16343
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L57
M991 S0 P56 ;notify layer change


G17
G3 Z11.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.254
G1 Z11.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4471
G1 X122.47 Y134.839 E.02273
G3 X127.824 Y119.199 I5.53 J-6.844 E.71272
G1 X128.176 Y119.199 E.01169
G3 X123.068 Y135.282 I-.176 J8.797 E1.08477
G1 X123.231 Y134.925 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4471
M204 S6000
G1 X122.716 Y134.535 E.01986
G3 X127.832 Y119.591 I5.284 J-6.539 E.63079
G1 X128.168 Y119.591 E.01034
G3 X123.283 Y134.955 I-.168 J8.405 E.96022
; WIPE_START
G1 F12000
M204 S10000
G1 X122.716 Y134.535 E-.26808
G1 X122.204 Y134.093 E-.25715
G1 X121.773 Y133.649 E-.23477
; WIPE_END
G1 E-.04 F1800
G1 X129.406 Y133.668 Z11.8 F36000
G1 X135.48 Y133.682 Z11.8
G1 Z11.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4471
G1 X135.403 Y133.778 E.00408
G3 X127.829 Y118.603 I-7.405 J-5.782 E1.25639
G1 X128.175 Y118.603 E.01145
G3 X135.803 Y133.225 I-.177 J9.393 E.66761
G1 X135.515 Y133.633 E.01657
G1 X135.798 Y133.912 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4471
M204 S6000
G1 X135.712 Y134.019 E.00422
G3 X127.822 Y118.211 I-7.714 J-6.023 E1.21236
G1 X128.182 Y118.211 E.01104
G3 X136.128 Y133.444 I-.184 J9.785 E.64423
G1 X135.832 Y133.863 E.01578
M204 S10000
G1 X135.282 Y133.441 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231605
G1 F4471
G1 X134.965 Y133.855 E.00802
G3 X118.901 Y128.096 I-6.966 J-5.854 E.34027
M73 P84 R2
G1 X118.901 Y128.092 E.00006
G1 X118.904 Y127.751 E.00525
G3 X135.458 Y133.213 I9.096 J.25 E.521
G1 X135.319 Y133.394 E.0035
; CHANGE_LAYER
; Z_HEIGHT: 11.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X134.965 Y133.855 E-.22102
G1 X134.532 Y134.335 E-.2457
G1 X134.287 Y134.578 E-.13108
G1 X133.966 Y134.86 E-.1622
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L58
M991 S0 P57 ;notify layer change


G17
G3 Z11.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z11.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X123.031 Y135.257 E.00054
G3 X127.824 Y119.199 I4.969 J-7.261 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.627 Y135.631 I-.176 J8.797 E1.06288
G1 X123.092 Y135.302 E.02086
G1 X123.23 Y134.925 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X122.979 Y134.738 E.0096
G3 X127.832 Y119.591 I5.021 J-6.742 E.641
G1 X128.168 Y119.591 E.01034
G3 X123.282 Y134.954 I-.168 J8.405 E.96027
; WIPE_START
G1 F12000
M204 S10000
G1 X122.979 Y134.738 E-.14123
G1 X122.452 Y134.32 E-.25556
G1 X121.965 Y133.856 E-.25585
G1 X121.776 Y133.645 E-.10736
; WIPE_END
G1 E-.04 F1800
G1 X129.408 Y133.664 Z12 F36000
G1 X135.482 Y133.679 Z12
G1 Z11.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X135.4 Y133.776 E.00421
G3 X127.829 Y118.603 I-7.407 J-5.779 E1.25663
G1 X128.187 Y118.603 E.01188
G3 X135.8 Y133.223 I-.194 J9.393 E.66693
G1 X135.517 Y133.63 E.01646
G1 X135.8 Y133.909 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.708 Y134.017 E.00434
G3 X127.822 Y118.211 I-7.716 J-6.021 E1.21261
G1 X128.195 Y118.211 E.01144
G3 X136.125 Y133.441 I-.202 J9.785 E.64357
G1 X135.834 Y133.86 E.01567
M204 S10000
G1 X135.284 Y133.438 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231598
G1 F4455
G1 X134.966 Y133.857 E.00808
G3 X118.901 Y128.092 I-6.967 J-5.853 E.34039
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.752 E.00518
G3 X135.459 Y133.214 I9.096 J.252 E.52092
G1 X135.321 Y133.391 E.00345
; CHANGE_LAYER
; Z_HEIGHT: 11.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.966 Y133.857 E-.2225
G1 X134.543 Y134.323 E-.23941
G1 X134.287 Y134.578 E-.1371
G1 X133.969 Y134.857 E-.16099
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L59
M991 S0 P58 ;notify layer change


G17
G3 Z12 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z11.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.261 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.627 Y135.631 I-.176 J8.797 E1.06288
G1 X123.091 Y135.302 E.02087
G1 X123.229 Y134.924 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X122.713 Y134.532 E.0199
G3 X127.832 Y119.591 I5.287 J-6.536 E.63067
G1 X128.168 Y119.591 E.01034
G3 X123.281 Y134.953 I-.168 J8.405 E.9603
; WIPE_START
G1 F12000
M204 S10000
G1 X122.713 Y134.532 E-.26856
G1 X122.452 Y134.32 E-.12795
G1 X121.965 Y133.856 E-.25565
G1 X121.771 Y133.648 E-.10785
; WIPE_END
G1 E-.04 F1800
G1 X129.404 Y133.664 Z12.2 F36000
G1 X135.484 Y133.676 Z12.2
G1 Z11.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X135.403 Y133.777 E.0043
G3 X127.488 Y118.615 I-7.41 J-5.779 E1.24568
G3 X128.2 Y118.604 I.501 J9.082 E.02362
G3 X135.802 Y133.226 I-.206 J9.395 E.66665
G1 X135.519 Y133.627 E.01631
G1 X135.804 Y133.908 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.712 Y134.019 E.00444
G3 X127.467 Y118.224 I-7.719 J-6.021 E1.202
G3 X128.207 Y118.212 I.522 J9.454 E.02277
G3 X135.925 Y133.735 I-.214 J9.787 E.65425
G1 X135.839 Y133.859 E.00463
M204 S10000
G1 X135.287 Y133.434 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231582
G1 F4455
G1 X134.948 Y133.878 E.0086
G3 X118.901 Y128.092 I-6.949 J-5.875 E.33993
M73 P85 R2
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.752 E.00517
G3 X135.457 Y133.217 I9.096 J.252 E.52093
G1 X135.324 Y133.387 E.00331
; CHANGE_LAYER
; Z_HEIGHT: 12
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.948 Y133.878 E-.23539
G1 X134.532 Y134.335 E-.2347
G1 X134.287 Y134.578 E-.13118
G1 X133.973 Y134.854 E-.15872
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L60
M991 S0 P59 ;notify layer change


G17
G3 Z12.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z12
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.261 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.627 Y135.631 I-.176 J8.797 E1.06289
G1 X123.091 Y135.302 E.02086
G1 X123.229 Y134.923 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X122.713 Y134.532 E.01988
G3 X127.832 Y119.591 I5.287 J-6.536 E.63067
G1 X128.168 Y119.591 E.01034
G3 X123.281 Y134.953 I-.168 J8.405 E.96032
; WIPE_START
G1 F12000
M204 S10000
G1 X122.713 Y134.532 E-.26834
G1 X122.452 Y134.32 E-.12787
G1 X121.965 Y133.856 E-.25571
G1 X121.775 Y133.644 E-.10808
; WIPE_END
G1 E-.04 F1800
G1 X129.407 Y133.654 Z12.4 F36000
G1 X135.495 Y133.661 Z12.4
G1 Z12
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X135.187 Y134.042 E.01625
G3 X127.488 Y118.615 I-7.196 J-6.043 E1.23447
G3 X128.213 Y118.604 I.497 J9.006 E.02404
G3 X135.582 Y133.538 I-.221 J9.394 E.67881
G1 X135.53 Y133.612 E.00299
G1 X135.804 Y133.903 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.487 Y134.294 E.01548
G3 X127.467 Y118.224 I-7.496 J-6.296 E1.19119
G3 X128.22 Y118.212 I.518 J9.366 E.02316
G3 X135.899 Y133.769 I-.229 J9.786 E.65504
G1 X135.839 Y133.854 E.0032
M204 S10000
G1 X135.289 Y133.432 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231575
G1 F4455
G1 X134.967 Y133.856 E.00819
G3 X118.901 Y128.092 I-6.967 J-5.852 E.34037
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.753 E.00516
G3 X135.459 Y133.214 I9.096 J.251 E.52086
G1 X135.326 Y133.385 E.00334
; CHANGE_LAYER
; Z_HEIGHT: 12.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.967 Y133.856 E-.22523
G1 X134.749 Y134.103 E-.12515
G1 X134.287 Y134.578 E-.25161
G1 X133.975 Y134.852 E-.15802
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L61
M991 S0 P60 ;notify layer change


G17
G3 Z12.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.253
G1 Z12.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4471
G1 X122.467 Y134.837 E.02285
G3 X127.824 Y119.199 I5.533 J-6.841 E.7126
G1 X128.176 Y119.199 E.01169
G3 X123.068 Y135.282 I-.176 J8.797 E1.08477
G1 X123.228 Y134.923 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4471
M204 S6000
G1 X122.713 Y134.532 E.01987
G3 X127.832 Y119.591 I5.287 J-6.536 E.63067
G1 X128.168 Y119.591 E.01034
G3 X123.28 Y134.953 I-.168 J8.405 E.96032
; WIPE_START
G1 F12000
M204 S10000
G1 X122.713 Y134.532 E-.2682
G1 X122.452 Y134.32 E-.12793
G1 X121.965 Y133.856 E-.25571
G1 X121.775 Y133.644 E-.10816
; WIPE_END
G1 E-.04 F1800
G1 X129.407 Y133.659 Z12.6 F36000
G1 X135.489 Y133.67 Z12.6
G1 Z12.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4471
G1 X135.4 Y133.776 E.00458
G3 X127.488 Y118.615 I-7.411 J-5.778 E1.24581
G3 X128.225 Y118.605 I.495 J8.931 E.02446
G3 X135.799 Y133.223 I-.235 J9.394 E.6656
G1 X135.523 Y133.621 E.01606
G1 X135.806 Y133.9 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4471
M204 S6000
G1 X135.708 Y134.017 E.00468
G3 X127.112 Y118.25 I-7.716 J-6.02 E1.19076
G3 X128.233 Y118.213 I.907 J10.555 E.03447
G3 X136.124 Y133.441 I-.241 J9.784 E.64239
G1 X135.841 Y133.851 E.01531
M204 S10000
G1 X135.283 Y133.436 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231614
G1 F4471
M73 P86 R2
G1 X135.019 Y133.794 E.00684
G3 X118.901 Y128.092 I-7.02 J-5.789 E.3417
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.753 E.00515
G3 X135.562 Y133.064 I9.096 J.251 E.51818
G1 X135.319 Y133.388 E.00622
; CHANGE_LAYER
; Z_HEIGHT: 12.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.19176
G1 X134.523 Y134.344 E-.28149
G1 X134.248 Y134.615 E-.14673
M73 P86 R1
G1 X133.972 Y134.858 E-.14002
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L62
M991 S0 P61 ;notify layer change


G17
G3 Z12.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z12.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.261 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06288
G1 X123.091 Y135.302 E.02087
G1 X123.229 Y134.923 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X122.713 Y134.532 E.01987
G3 X127.832 Y119.591 I5.287 J-6.536 E.63067
G1 X128.168 Y119.591 E.01034
G3 X123.281 Y134.953 I-.168 J8.405 E.96032
; WIPE_START
G1 F12000
M204 S10000
G1 X122.713 Y134.532 E-.26828
G1 X122.452 Y134.32 E-.12793
G1 X121.965 Y133.856 E-.25571
G1 X121.771 Y133.648 E-.10809
; WIPE_END
G1 E-.04 F1800
G1 X129.403 Y133.659 Z12.8 F36000
G1 X135.491 Y133.667 Z12.8
G1 Z12.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X135.403 Y133.776 E.00465
G3 X127.148 Y118.64 I-7.412 J-5.777 E1.23455
G3 X128.238 Y118.605 I.866 J10.064 E.03618
G3 X135.802 Y133.225 I-.246 J9.394 E.66529
G1 X135.526 Y133.618 E.01595
G1 X135.811 Y133.899 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.712 Y134.018 E.00478
G3 X127.112 Y118.25 I-7.72 J-6.019 E1.19124
G3 X128.246 Y118.213 I.902 J10.488 E.03486
G3 X135.924 Y133.735 I-.255 J9.786 E.65296
G1 X135.845 Y133.849 E.00428
M204 S10000
G1 X135.295 Y133.423 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231563
G1 F4455
G1 X134.924 Y133.908 E.00938
G3 X118.901 Y128.092 I-6.925 J-5.901 E.33938
G1 X118.901 Y128.088 E.00006
G3 X118.946 Y127.092 I10.397 J-.022 E.01534
G3 X135.46 Y133.214 I9.053 J.915 E.51055
G1 X135.332 Y133.376 E.00317
; CHANGE_LAYER
; Z_HEIGHT: 12.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X134.924 Y133.908 E-.25456
G1 X134.287 Y134.578 E-.35146
G1 X133.983 Y134.845 E-.15398
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L63
M991 S0 P62 ;notify layer change


G17
G3 Z12.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z12.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X123.029 Y135.261 E.00051
G3 X127.824 Y119.199 I4.972 J-7.263 E.73609
G3 X129.227 Y119.283 I.026 J11.31 E.04665
G3 X123.625 Y135.635 I-1.226 J8.715 E1.02827
G1 X123.091 Y135.302 E.02088
G1 X123.229 Y134.924 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X122.976 Y134.742 E.00957
G3 X127.832 Y119.591 I5.024 J-6.744 E.64114
G3 X129.174 Y119.671 I.026 J10.78 E.04133
G3 X123.279 Y134.957 I-1.173 J8.327 E.92962
; WIPE_START
G1 F12000
M204 S10000
G1 X122.976 Y134.742 E-.14107
G1 X122.453 Y134.32 E-.25541
G1 X121.965 Y133.856 E-.256
G1 X121.772 Y133.649 E-.10752
; WIPE_END
G1 E-.04 F1800
G1 X129.404 Y133.655 Z13 F36000
G1 X135.5 Y133.66 Z13
G1 Z12.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X135.401 Y133.777 E.00506
G3 X127.148 Y118.64 I-7.411 J-5.778 E1.23454
G3 X128.25 Y118.606 I.863 J10.011 E.0366
G3 X135.606 Y133.504 I-.26 J9.393 E.67613
G1 X135.533 Y133.611 E.00427
G1 X135.813 Y133.896 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.71 Y134.018 E.00491
G3 X127.112 Y118.25 I-7.72 J-6.019 E1.19124
G3 X128.259 Y118.214 I.899 J10.43 E.03526
G3 X135.923 Y133.734 I-.269 J9.785 E.6525
G1 X135.847 Y133.846 E.00417
M204 S10000
G1 X135.292 Y133.425 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231554
G1 F4455
M73 P87 R1
G1 X134.963 Y133.853 E.00831
G3 X118.903 Y128.169 I-6.962 J-5.859 E.33887
G1 X118.903 Y128.166 E.00005
G3 X118.904 Y127.732 I24.929 J-.131 E.00668
G1 X118.923 Y127.364 E.00566
G3 X135.498 Y133.151 I9.078 J.63 E.51399
G1 X135.328 Y133.377 E.00435
; CHANGE_LAYER
; Z_HEIGHT: 12.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.963 Y133.853 E-.22827
G1 X134.532 Y134.335 E-.24551
G1 X134.287 Y134.578 E-.13109
G1 X133.98 Y134.847 E-.15512
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L64
M991 S0 P63 ;notify layer change


G17
G3 Z13 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z12.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X123.028 Y135.261 E.00049
G3 X127.824 Y119.199 I4.972 J-7.263 E.73611
G1 X128.176 Y119.199 E.01169
G3 X123.625 Y135.635 I-.176 J8.8 E1.06324
G1 X123.091 Y135.302 E.02089
G1 X123.23 Y134.924 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X122.711 Y134.536 E.01993
G3 X127.832 Y119.591 I5.289 J-6.537 E.63081
G1 X128.168 Y119.591 E.01034
G3 X123.28 Y134.958 I-.168 J8.408 E.96059
; WIPE_START
G1 F12000
M204 S10000
G1 X122.711 Y134.536 E-.26917
G1 X122.452 Y134.32 E-.12794
G1 X121.965 Y133.856 E-.25571
G1 X121.772 Y133.65 E-.10718
; WIPE_END
G1 E-.04 F1800
G1 X129.405 Y133.656 Z13.2 F36000
G1 X135.495 Y133.661 Z13.2
G1 Z12.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X135.401 Y133.777 E.00494
G3 X127.148 Y118.64 I-7.411 J-5.778 E1.2345
G3 X128.254 Y118.606 I1.002 J14.541 E.03673
G3 X135.8 Y133.224 I-.264 J9.393 E.66465
G1 X135.53 Y133.612 E.01569
G1 X135.812 Y133.891 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.493 Y134.299 E.01593
G3 X118.442 Y130.113 I-7.493 J-6.3 E.66919
G3 X118.237 Y127.287 I9.983 J-2.145 E.08737
G3 X128.269 Y118.214 I9.775 J.727 E.45865
G3 X135.93 Y133.739 I-.268 J9.785 E.65266
G1 X135.849 Y133.843 E.00407
M204 S10000
G1 X135.289 Y133.427 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231538
G1 F4455
G1 X135.019 Y133.793 E.00701
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34154
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.561 Y133.064 I9.096 J.252 E.51798
G1 X135.325 Y133.379 E.00604
; CHANGE_LAYER
; Z_HEIGHT: 13
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.793 E-.196
G1 X134.522 Y134.345 E-.28222
G1 X134.27 Y134.594 E-.13434
G1 X133.98 Y134.851 E-.14743
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L65
M991 S0 P64 ;notify layer change


G17
G3 Z13.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.254
G1 Z13
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4472
G1 X122.467 Y134.837 E.02286
G3 X127.824 Y119.199 I5.533 J-6.841 E.7126
G1 X128.176 Y119.199 E.01169
G3 X123.068 Y135.282 I-.176 J8.797 E1.08477
G1 X123.231 Y134.925 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4472
M204 S6000
G1 X122.711 Y134.536 E.01996
G3 X127.832 Y119.591 I5.289 J-6.537 E.63081
G1 X128.168 Y119.591 E.01034
G3 X123.281 Y134.958 I-.168 J8.408 E.96055
; WIPE_START
G1 F12000
M204 S10000
G1 X122.711 Y134.536 E-.26964
G1 X122.452 Y134.32 E-.12795
G1 X121.965 Y133.856 E-.25571
G1 X121.781 Y133.644 E-.1067
; WIPE_END
G1 E-.04 F1800
G1 X129.413 Y133.652 Z13.4 F36000
G1 X135.497 Y133.659 Z13.4
G1 Z13
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4472
G1 X135.4 Y133.776 E.00506
G3 X127.148 Y118.64 I-7.411 J-5.777 E1.23457
G3 X128.267 Y118.606 I.987 J14.228 E.03716
G3 X135.8 Y133.224 I-.278 J9.393 E.66418
G1 X135.532 Y133.609 E.01558
G1 X135.815 Y133.888 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4472
M204 S6000
G1 X135.716 Y134.022 E.00512
G3 X118.238 Y127.274 I-7.716 J-6.023 E.76786
G3 X128.282 Y118.215 I9.772 J.736 E.45868
G3 X136.132 Y133.447 I-.282 J9.784 E.64131
G1 X135.85 Y133.84 E.01487
M204 S10000
G1 X135.291 Y133.424 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4472
M73 P88 R1
G1 X135.019 Y133.794 E.00706
G3 X118.901 Y128.092 I-7.02 J-5.79 E.34168
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.562 Y133.064 I9.096 J.252 E.51817
G1 X135.327 Y133.376 E.00599
; CHANGE_LAYER
; Z_HEIGHT: 13.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.19724
G1 X134.522 Y134.345 E-.2822
G1 X134.27 Y134.594 E-.13442
G1 X133.982 Y134.849 E-.14614
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L66
M991 S0 P65 ;notify layer change


G17
G3 Z13.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.253
G1 Z13.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4471
G1 X122.467 Y134.837 E.02286
G3 X127.824 Y119.199 I5.533 J-6.841 E.71259
G3 X128.758 Y119.231 I.138 J9.472 E.03104
G1 X128.879 Y119.241 E.00401
G3 X123.068 Y135.282 I-.879 J8.755 E1.06141
G1 X123.232 Y134.926 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4471
M204 S6000
G1 X122.713 Y134.532 E.02001
G3 X127.832 Y119.591 I5.287 J-6.536 E.63066
G3 X128.727 Y119.622 I.131 J9.056 E.02754
G1 X128.84 Y119.631 E.00348
G3 X123.284 Y134.955 I-.84 J8.365 E.93952
; WIPE_START
G1 F12000
M204 S10000
G1 X122.713 Y134.532 E-.26992
G1 X122.452 Y134.32 E-.12794
G1 X121.965 Y133.856 E-.25564
G1 X121.774 Y133.651 E-.1065
; WIPE_END
G1 E-.04 F1800
G1 X129.406 Y133.651 Z13.6 F36000
G1 X135.506 Y133.652 Z13.6
G1 Z13.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4471
G1 X135.402 Y133.778 E.00542
G3 X126.808 Y118.677 I-7.411 J-5.778 E1.22317
G3 X128.28 Y118.607 I1.195 J9.585 E.04893
G3 X135.607 Y133.505 I-.289 J9.393 E.67518
G1 X135.54 Y133.602 E.00392
G1 X135.817 Y133.885 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4471
M204 S6000
G1 X135.492 Y134.299 E.01615
G3 X118.239 Y127.261 I-7.492 J-6.3 E.75733
G3 X128.295 Y118.215 I9.761 J.739 E.45879
G3 X135.929 Y133.738 I-.295 J9.784 E.65183
G1 X135.853 Y133.838 E.00385
M204 S10000
G1 X135.302 Y133.415 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4471
G1 X134.967 Y133.857 E.00853
G3 X118.901 Y128.092 I-6.967 J-5.854 E.34043
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.46 Y133.214 I9.096 J.252 E.52098
G1 X135.339 Y133.368 E.003
; CHANGE_LAYER
; Z_HEIGHT: 13.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.967 Y133.857 E-.23367
G1 X134.532 Y134.335 E-.24561
G1 X134.287 Y134.578 E-.13125
G1 X133.991 Y134.838 E-.14947
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L67
M991 S0 P66 ;notify layer change


G17
G3 Z13.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.254
G1 Z13.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4472
G1 X122.466 Y134.838 E.02287
G3 X123.663 Y120.342 I5.538 J-6.84 E.56792
G3 X127.824 Y119.199 I4.348 J7.685 E.1446
G3 X123.067 Y135.284 I.179 J8.799 E1.09694
G1 X123.234 Y134.927 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4472
M204 S6000
G1 X122.713 Y134.532 E.02007
G3 X127.832 Y119.591 I5.287 J-6.536 E.63067
G1 X128.168 Y119.591 E.01034
G3 X123.286 Y134.956 I-.168 J8.405 E.96013
; WIPE_START
G1 F12000
M204 S10000
G1 X122.713 Y134.532 E-.27061
G1 X122.452 Y134.32 E-.12787
G1 X121.965 Y133.856 E-.25571
G1 X121.775 Y133.652 E-.10581
; WIPE_END
G1 E-.04 F1800
G1 X129.407 Y133.653 Z13.8 F36000
G1 X135.501 Y133.653 Z13.8
G1 Z13.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4472
G1 X135.4 Y133.776 E.00529
G3 X126.808 Y118.677 I-7.409 J-5.778 E1.22298
G3 X128.293 Y118.607 I1.194 J9.567 E.04936
G3 X135.8 Y133.224 I-.302 J9.391 E.66336
G1 X135.536 Y133.604 E.01535
G1 X135.819 Y133.883 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4472
M204 S6000
G1 X135.711 Y134.019 E.00534
G3 X126.759 Y118.288 I-7.72 J-6.019 E1.18032
G3 X128.308 Y118.216 I1.244 J9.966 E.04769
G3 X136.127 Y133.443 I-.317 J9.784 E.6401
G1 X135.853 Y133.834 E.01465
M204 S10000
G1 X135.295 Y133.418 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4472
M73 P89 R1
G1 X135.019 Y133.794 E.00717
G3 X118.901 Y128.092 I-7.019 J-5.791 E.34168
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.562 Y133.064 I9.096 J.252 E.51819
G1 X135.332 Y133.37 E.00589
; CHANGE_LAYER
; Z_HEIGHT: 13.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.19996
G1 X134.522 Y134.345 E-.28218
G1 X134.27 Y134.594 E-.13441
G1 X133.988 Y134.844 E-.14346
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L68
M991 S0 P67 ;notify layer change


G17
G3 Z13.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.254
G1 Z13.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4471
G1 X122.464 Y134.841 E.02286
G3 X127.824 Y119.199 I5.536 J-6.842 E.71276
G3 X128.735 Y119.229 I.138 J9.434 E.03026
G1 X128.879 Y119.241 E.00479
G3 X123.066 Y135.286 I-.879 J8.757 E1.06174
G1 X123.235 Y134.928 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4471
M204 S6000
G1 X122.714 Y134.532 E.02013
G3 X127.832 Y119.591 I5.287 J-6.536 E.63066
G3 X128.704 Y119.62 I.132 J9.02 E.02682
G1 X128.84 Y119.631 E.00419
G3 X123.287 Y134.957 I-.84 J8.365 E.9394
; WIPE_START
G1 F12000
M204 S10000
G1 X122.714 Y134.532 E-.27131
G1 X122.452 Y134.32 E-.12793
G1 X121.965 Y133.856 E-.25571
G1 X121.776 Y133.654 E-.10506
; WIPE_END
G1 E-.04 F1800
G1 X129.409 Y133.651 Z14 F36000
G1 X135.505 Y133.649 Z14
G1 Z13.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4471
G1 X135.401 Y133.777 E.00547
G3 X126.808 Y118.677 I-7.41 J-5.778 E1.22314
G3 X128.306 Y118.608 I1.193 J9.554 E.04979
G3 X135.725 Y133.336 I-.315 J9.391 E.66745
G1 X135.54 Y133.6 E.01068
G1 X135.821 Y133.88 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4471
M204 S6000
G1 X135.488 Y134.296 E.01636
G3 X118.241 Y127.235 I-7.49 J-6.298 E.75789
G3 X125.504 Y118.534 I9.779 J.781 E.37128
G3 X128.32 Y118.216 I2.496 J9.472 E.08739
G3 X135.926 Y133.735 I-.322 J9.781 E.65086
G1 X135.856 Y133.831 E.00363
M204 S10000
G1 X135.298 Y133.415 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4471
G1 X135.019 Y133.794 E.00722
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34167
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.562 Y133.064 I9.096 J.252 E.51817
G1 X135.334 Y133.367 E.00584
; CHANGE_LAYER
; Z_HEIGHT: 13.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.794 E-.20132
G1 X134.522 Y134.345 E-.28223
G1 X134.27 Y134.594 E-.13434
G1 X133.99 Y134.842 E-.14211
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L69
M991 S0 P68 ;notify layer change


G17
G3 Z14 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.254
G1 Z13.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X122.466 Y134.838 E.02286
G3 X127.824 Y119.199 I5.541 J-6.839 E.71239
G3 X126.059 Y136.583 I.175 J8.799 E.98791
G3 X123.067 Y135.284 I1.948 J-8.584 E.10883
G1 X123.237 Y134.93 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X122.714 Y134.532 E.0202
G3 X127.832 Y119.591 I5.287 J-6.536 E.63066
G3 X129.027 Y119.654 I-.012 J11.611 E.03679
G1 X129.174 Y119.672 E.00456
G3 X123.289 Y134.958 I-1.174 J8.324 E.92898
; WIPE_START
G1 F12000
M204 S10000
G1 X122.714 Y134.532 E-.27214
G1 X122.452 Y134.32 E-.12793
G1 X121.965 Y133.856 E-.25571
G1 X121.778 Y133.655 E-.10422
; WIPE_END
G1 E-.04 F1800
G1 X129.41 Y133.649 Z14.2 F36000
G1 X135.512 Y133.643 Z14.2
G1 Z13.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X135.401 Y133.777 E.00577
G3 X126.808 Y118.677 I-7.411 J-5.778 E1.22317
G3 X128.319 Y118.608 I1.192 J9.544 E.05022
G3 X135.606 Y133.504 I-.328 J9.391 E.67384
G1 X135.546 Y133.594 E.00358
G1 X135.822 Y133.876 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.388 Y134.414 E.02125
G3 X125.517 Y118.531 I-7.388 J-6.417 E1.1248
G3 X128.333 Y118.216 I2.484 J9.472 E.08739
G3 X135.926 Y133.736 I-.334 J9.78 E.65051
G1 X135.858 Y133.828 E.00352
M204 S10000
G1 X135.3 Y133.413 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4455
M73 P90 R1
G1 X135.018 Y133.793 E.00728
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34165
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.561 Y133.064 I9.095 J.252 E.51815
G1 X135.336 Y133.365 E.00578
; CHANGE_LAYER
; Z_HEIGHT: 14
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.018 Y133.793 E-.20271
G1 X134.522 Y134.345 E-.28213
G1 X134.27 Y134.594 E-.13441
G1 X133.993 Y134.839 E-.14075
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L70
M991 S0 P69 ;notify layer change


G17
G3 Z14.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.253
G1 Z14
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4456
G1 X122.466 Y134.838 E.02285
G3 X127.824 Y119.199 I5.541 J-6.839 E.71239
G3 X131.109 Y119.766 I.163 J8.851 E.11127
G3 X135.497 Y132.608 I-3.109 J8.233 E.51405
G3 X126.07 Y136.585 I-7.508 J-4.635 E.36203
G3 X123.067 Y135.284 I1.937 J-8.586 E.10922
G1 X123.239 Y134.931 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4456
M204 S6000
G1 X122.714 Y134.532 E.02028
G3 X127.832 Y119.591 I5.287 J-6.536 E.63066
G3 X129.015 Y119.652 I-.015 J11.697 E.03643
G1 X129.174 Y119.672 E.00492
G3 X123.291 Y134.96 I-1.174 J8.324 E.92891
; WIPE_START
G1 F12000
M204 S10000
G1 X122.714 Y134.532 E-.27301
G1 X122.452 Y134.32 E-.12793
G1 X121.965 Y133.856 E-.25571
G1 X121.779 Y133.657 E-.10335
; WIPE_END
G1 E-.04 F1800
G1 X129.412 Y133.648 Z14.4 F36000
G1 X135.514 Y133.641 Z14.4
G1 Z14
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4456
G1 X135.401 Y133.777 E.00587
G3 X126.808 Y118.677 I-7.411 J-5.778 E1.22318
G3 X128.332 Y118.609 I1.192 J9.537 E.05064
G3 X135.606 Y133.504 I-.341 J9.391 E.67341
G1 X135.548 Y133.591 E.00347
G1 X135.825 Y133.874 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4456
M204 S6000
G1 X135.716 Y134.022 E.00565
G3 X125.375 Y137.429 I-7.716 J-6.023 E.35473
G3 X118.244 Y127.209 I2.642 J-9.442 E.41496
G3 X125.529 Y118.528 I9.757 J.79 E.3714
G3 X128.346 Y118.217 I2.471 J9.473 E.08739
G3 X136.132 Y133.447 I-.346 J9.782 E.63932
G1 X135.86 Y133.826 E.01434
M204 S10000
G1 X135.311 Y133.404 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4456
G1 X134.961 Y133.852 E.00873
G3 X118.905 Y128.264 I-6.961 J-5.86 E.33743
G1 X118.901 Y128.088 E.0027
G3 X118.923 Y127.364 I9.118 J-.084 E.01114
G1 X118.946 Y127.092 E.0042
G3 X135.454 Y133.21 I9.054 J.9 E.51111
G1 X135.346 Y133.356 E.00279
; CHANGE_LAYER
; Z_HEIGHT: 14.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.961 Y133.852 E-.23862
G1 X134.532 Y134.335 E-.24556
G1 X134.273 Y134.591 E-.13844
G1 X134.006 Y134.835 E-.13739
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L71
M991 S0 P70 ;notify layer change


G17
G3 Z14.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z14.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X123.028 Y135.261 E.00049
G3 X127.824 Y119.199 I4.972 J-7.263 E.73611
G3 X128.7 Y119.227 I.138 J9.431 E.0291
G1 X128.879 Y119.241 E.00595
G3 X123.625 Y135.635 I-.879 J8.757 E1.03987
G1 X123.091 Y135.302 E.02089
G1 X123.241 Y134.933 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X122.711 Y134.536 E.02037
G3 X127.832 Y119.591 I5.289 J-6.537 E.63081
G3 X128.669 Y119.617 I.132 J9.016 E.02575
G1 X128.84 Y119.631 E.00527
G3 X123.292 Y134.966 I-.84 J8.367 E.93947
; WIPE_START
G1 F12000
M204 S10000
G1 X122.711 Y134.536 E-.27467
G1 X122.452 Y134.32 E-.12801
G1 X121.965 Y133.856 E-.25565
G1 X121.782 Y133.66 E-.10167
; WIPE_END
G1 E-.04 F1800
G1 X129.415 Y133.648 Z14.6 F36000
G1 X135.516 Y133.638 Z14.6
G1 Z14.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4455
G1 X135.402 Y133.777 E.00598
G3 X126.808 Y118.677 I-7.411 J-5.778 E1.22321
G3 X128.345 Y118.609 I1.192 J9.535 E.05107
G3 X135.606 Y133.505 I-.354 J9.39 E.673
G1 X135.55 Y133.588 E.00334
G1 X135.83 Y133.874 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4455
M204 S6000
G1 X135.71 Y134.018 E.00576
G3 X126.759 Y118.288 I-7.72 J-6.019 E1.18026
G3 X128.359 Y118.217 I1.241 J9.935 E.04928
G3 X135.923 Y133.734 I-.369 J9.782 E.64938
G1 X135.863 Y133.824 E.00332
M204 S10000
G1 X135.294 Y133.433 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4455
M73 P91 R1
G1 X135.24 Y133.504 E.00137
G3 X118.912 Y128.456 I-7.24 J-5.512 E.34137
G1 X118.901 Y128.088 E.00566
G3 X135.736 Y132.783 I9.099 J-.096 E.51862
G1 X135.328 Y133.383 E.01116
; CHANGE_LAYER
; Z_HEIGHT: 14.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.24 Y133.504 E-.05674
G1 X134.747 Y134.104 E-.29504
G1 X134.522 Y134.345 E-.12541
G1 X134.044 Y134.802 E-.2513
G1 X133.979 Y134.854 E-.03151
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L72
M991 S0 P71 ;notify layer change


G17
G3 Z14.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z14.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4454
G1 X123.033 Y135.254 E.00059
G3 X125.216 Y119.651 I4.972 J-7.259 E.64746
G3 X127.824 Y119.199 I2.804 J8.431 E.08812
G3 X123.629 Y135.628 I.181 J8.796 E1.07481
G1 X123.091 Y135.301 E.02088
G1 X123.244 Y134.935 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4454
M204 S6000
G1 X122.713 Y134.532 E.02046
G3 X127.832 Y119.591 I5.287 J-6.536 E.63066
G3 X128.992 Y119.65 I-.021 J11.909 E.03572
G1 X129.174 Y119.672 E.00564
G3 X123.295 Y134.962 I-1.174 J8.324 E.92877
; WIPE_START
G1 F12000
M204 S10000
G1 X122.713 Y134.532 E-.27486
G1 X122.452 Y134.32 E-.12787
G1 X121.965 Y133.856 E-.25571
G1 X121.782 Y133.661 E-.10156
; WIPE_END
G1 E-.04 F1800
G1 X129.415 Y133.647 Z14.8 F36000
G1 X135.518 Y133.635 Z14.8
G1 Z14.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4454
G1 X135.4 Y133.775 E.00609
G3 X126.808 Y118.677 I-7.409 J-5.778 E1.22293
G3 X128.358 Y118.61 I1.192 J9.536 E.0515
G3 X135.604 Y133.503 I-.367 J9.388 E.67249
G1 X135.551 Y133.585 E.00324
G1 X135.829 Y133.869 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4454
M204 S6000
G1 X135.488 Y134.295 E.01677
G3 X118.246 Y127.184 I-7.49 J-6.298 E.75948
G3 X128.372 Y118.218 I9.754 J.816 E.45879
G3 X135.926 Y133.735 I-.374 J9.779 E.64927
G1 X135.864 Y133.82 E.00322
M204 S10000
G1 X135.306 Y133.405 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4454
G1 X135.018 Y133.793 E.00742
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34166
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.561 Y133.064 I9.095 J.252 E.51814
G1 X135.342 Y133.357 E.00563
; CHANGE_LAYER
; Z_HEIGHT: 14.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X135.018 Y133.793 E-.20626
G1 X134.522 Y134.345 E-.28229
G1 X134.27 Y134.594 E-.1344
G1 X134 Y134.833 E-.13705
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L73
M991 S0 P72 ;notify layer change


G17
G3 Z14.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.254
G1 Z14.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4456
G1 X122.464 Y134.84 E.02287
G3 X127.824 Y119.199 I5.537 J-6.842 E.7127
G3 X126.105 Y136.593 I.171 J8.799 E.98599
G3 X123.066 Y135.286 I1.896 J-8.595 E.11038
G1 X123.246 Y134.937 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4456
M204 S6000
G1 X122.711 Y134.536 E.02056
G3 X127.832 Y119.591 I5.289 J-6.537 E.63081
G3 X128.646 Y119.616 I.131 J9.063 E.02503
G1 X128.84 Y119.631 E.00599
G3 X123.296 Y134.969 I-.84 J8.367 E.93929
; WIPE_START
G1 F12000
M204 S10000
G1 X122.711 Y134.536 E-.27694
G1 X122.452 Y134.32 E-.12795
G1 X121.965 Y133.856 E-.25565
G1 X121.786 Y133.665 E-.09946
; WIPE_END
G1 E-.04 F1800
G1 X129.419 Y133.647 Z15 F36000
G1 X135.52 Y133.633 Z15
G1 Z14.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4456
G1 X135.402 Y133.777 E.0062
G3 X126.808 Y118.677 I-7.411 J-5.778 E1.22318
G3 X128.371 Y118.61 I1.192 J9.539 E.05193
G3 X135.607 Y133.505 I-.38 J9.389 E.67215
G1 X135.554 Y133.583 E.00314
G1 X135.834 Y133.868 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4456
M204 S6000
G1 X135.711 Y134.019 E.00596
G3 X126.759 Y118.288 I-7.72 J-6.019 E1.18035
G3 X128.385 Y118.218 I1.242 J9.939 E.05008
G3 X135.924 Y133.734 I-.394 J9.781 E.64864
M73 P92 R1
G1 X135.867 Y133.819 E.00313
M204 S10000
G1 X135.307 Y133.402 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4456
G1 X135.019 Y133.793 E.00748
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34166
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.561 Y133.064 I9.096 J.252 E.51816
G1 X135.343 Y133.354 E.00558
; CHANGE_LAYER
; Z_HEIGHT: 14.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.793 E-.20763
G1 X134.522 Y134.345 E-.28206
G1 X134.27 Y134.594 E-.13448
G1 X134.003 Y134.831 E-.13583
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L74
M991 S0 P73 ;notify layer change


G17
G3 Z15 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.253
G1 Z14.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4456
G1 X122.464 Y134.84 E.02286
G3 X127.824 Y119.199 I5.537 J-6.842 E.7127
G3 X131.066 Y119.75 I.163 J8.853 E.10972
G3 X126.116 Y136.596 I-3.068 J8.249 E.87607
G3 X123.066 Y135.286 I1.885 J-8.597 E.11077
G1 X123.25 Y134.937 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4456
M204 S6000
G3 X127.832 Y119.591 I4.75 J-6.939 E.65148
G3 X128.969 Y119.647 I-.029 J12.18 E.035
G1 X129.174 Y119.672 E.00636
G3 X123.3 Y134.971 I-1.174 J8.327 E.92882
; WIPE_START
G1 F12000
M204 S10000
G1 X122.71 Y134.537 E-.27835
G1 X122.452 Y134.32 E-.12802
G1 X121.965 Y133.856 E-.25564
G1 X121.789 Y133.667 E-.09798
; WIPE_END
G1 E-.04 F1800
G1 X129.421 Y133.647 Z15.2 F36000
G1 X135.522 Y133.63 Z15.2
G1 Z14.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4456
G1 X135.402 Y133.777 E.00629
G3 X126.808 Y118.677 I-7.41 J-5.778 E1.22309
G3 X128.384 Y118.611 I1.192 J9.545 E.05236
G3 X135.606 Y133.505 I-.392 J9.388 E.67173
G1 X135.555 Y133.58 E.00303
G1 X135.835 Y133.866 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4456
M204 S6000
G1 X135.71 Y134.018 E.00605
G3 X126.759 Y118.288 I-7.719 J-6.019 E1.18023
G3 X128.398 Y118.219 I1.242 J9.945 E.05047
G3 X135.924 Y133.734 I-.407 J9.78 E.64823
G1 X135.869 Y133.816 E.00303
M204 S10000
G1 X135.319 Y133.394 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231607
G1 F4456
G1 X134.967 Y133.857 E.00894
G3 X118.901 Y128.092 I-6.967 J-5.854 E.34042
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.458 Y133.218 I9.096 J.252 E.52105
G1 X135.356 Y133.347 E.00253
; CHANGE_LAYER
; Z_HEIGHT: 15
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.967 Y133.857 E-.24378
G1 X134.532 Y134.335 E-.24566
G1 X134.287 Y134.578 E-.13102
G1 X134.011 Y134.82 E-.13955
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L75
M991 S0 P74 ;notify layer change


G17
G3 Z15.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z15
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4450
G1 X123.029 Y135.261 E.00049
G3 X127.824 Y119.199 I4.971 J-7.263 E.73611
G3 X129.004 Y119.256 I-.035 J12.897 E.03922
G1 X129.229 Y119.283 E.00751
G3 X123.625 Y135.635 I-1.229 J8.715 E1.02819
G1 X123.091 Y135.302 E.02088
G1 X123.252 Y134.94 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4450
M204 S6000
G1 X123.25 Y134.938 E.00009
G3 X127.832 Y119.591 I4.75 J-6.939 E.65149
G3 X128.957 Y119.645 I-.034 J12.349 E.03464
G1 X129.174 Y119.672 E.00672
G3 X123.82 Y135.295 I-1.174 J8.327 E.90998
G1 X123.302 Y134.972 E.01875
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.938 E-.02381
G1 X122.71 Y134.537 E-.2557
G1 X122.452 Y134.32 E-.1279
G1 X121.965 Y133.856 E-.25571
G1 X121.791 Y133.67 E-.09689
; WIPE_END
G1 E-.04 F1800
G1 X129.423 Y133.647 Z15.4 F36000
G1 X135.52 Y133.63 Z15.4
G1 Z15
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4450
G1 X135.401 Y133.776 E.00628
G3 X127.148 Y118.64 I-7.411 J-5.777 E1.23458
G3 X128.397 Y118.611 I.92 J12.735 E.04144
G3 X135.672 Y133.41 I-.407 J9.388 E.6674
G1 X135.554 Y133.58 E.00687
G1 X135.834 Y133.861 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4450
M204 S6000
G1 X135.712 Y134.019 E.00614
G3 X119.74 Y133.251 I-7.715 J-6.022 E.57503
M73 P93 R1
G3 X118.413 Y129.974 I8.269 J-5.256 E.10924
G3 X128.411 Y118.219 I9.587 J-1.975 E.54618
G3 X136.129 Y133.444 I-.414 J9.778 E.63713
G1 X135.869 Y133.812 E.01385
M204 S10000
G1 X135.321 Y133.391 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231608
G1 F4450
G1 X134.967 Y133.857 E.00899
G3 X118.901 Y128.092 I-6.967 J-5.852 E.34043
M73 P93 R0
G1 X118.901 Y128.088 E.00006
G3 X118.923 Y127.364 I9.115 J-.084 E.01114
G1 X118.946 Y127.092 E.0042
G3 X135.457 Y133.217 I9.053 J.913 E.51081
G1 X135.358 Y133.344 E.00248
; CHANGE_LAYER
; Z_HEIGHT: 15.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.967 Y133.857 E-.24505
G1 X134.532 Y134.335 E-.24554
G1 X134.287 Y134.578 E-.13116
G1 X134.014 Y134.818 E-.13826
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L76
M991 S0 P75 ;notify layer change


G17
G3 Z15.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.254
G1 Z15.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4451
G1 X122.466 Y134.838 E.02286
G3 X127.824 Y119.199 I5.541 J-6.839 E.7124
G3 X126.139 Y136.601 I.173 J8.799 E.98505
G3 X123.067 Y135.284 I1.868 J-8.602 E.11154
G1 X123.254 Y134.942 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4451
M204 S6000
G1 X123.25 Y134.938 E.00019
G3 X127.832 Y119.591 I4.75 J-6.939 E.65149
G1 X128.168 Y119.591 E.01034
G3 X123.82 Y135.295 I-.168 J8.407 E.94101
G1 X123.305 Y134.974 E.01864
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.938 E-.02509
G1 X122.71 Y134.537 E-.25563
G1 X122.452 Y134.32 E-.12796
G1 X121.965 Y133.856 E-.25571
G1 X121.793 Y133.672 E-.09562
; WIPE_END
G1 E-.04 F1800
G1 X129.425 Y133.648 Z15.6 F36000
G1 X135.519 Y133.629 Z15.6
G1 Z15.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4451
G1 X135.401 Y133.776 E.00626
G3 X127.148 Y118.64 I-7.411 J-5.778 E1.2345
G3 X128.41 Y118.612 I.917 J12.678 E.04187
G3 X135.8 Y133.224 I-.419 J9.387 E.65951
G1 X135.553 Y133.58 E.01436
G1 X135.839 Y133.861 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4451
M204 S6000
G1 X135.71 Y134.018 E.00625
G3 X127.112 Y118.25 I-7.72 J-6.019 E1.19124
G3 X128.424 Y118.22 I.956 J13.216 E.04032
G3 X135.923 Y133.733 I-.434 J9.779 E.64739
G1 X135.872 Y133.811 E.00284
M204 S10000
G1 X135.313 Y133.395 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231606
G1 F4451
G1 X135.019 Y133.793 E.00762
G3 X118.901 Y128.092 I-7.019 J-5.79 E.34166
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00519
G3 X135.561 Y133.064 I9.096 J.252 E.51816
G1 X135.349 Y133.347 E.00543
; CHANGE_LAYER
; Z_HEIGHT: 15.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X135.019 Y133.793 E-.21119
G1 X134.522 Y134.345 E-.28222
G1 X134.27 Y134.594 E-.13433
G1 X134.01 Y134.825 E-.13227
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L77
M991 S0 P76 ;notify layer change


G17
G3 Z15.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.016 Y135.253
G1 Z15.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4451
G1 X122.466 Y134.838 E.02285
G3 X127.824 Y119.199 I5.541 J-6.839 E.71239
G3 X126.15 Y136.603 I.175 J8.8 E.98483
G3 X123.067 Y135.284 I1.857 J-8.604 E.11193
G1 X123.257 Y134.944 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4451
M204 S6000
G1 X123.25 Y134.937 E.0003
G3 X127.832 Y119.591 I4.75 J-6.939 E.65148
G1 X128.168 Y119.591 E.01034
G3 X123.82 Y135.295 I-.168 J8.408 E.94101
G1 X123.308 Y134.976 E.01854
; WIPE_START
G1 F12000
M204 S10000
G1 X123.25 Y134.937 E-.02643
G1 X122.71 Y134.537 E-.25558
G1 X122.452 Y134.32 E-.12802
G1 X121.965 Y133.856 E-.25564
G1 X121.795 Y133.675 E-.09433
; WIPE_END
G1 E-.04 F1800
G1 X129.428 Y133.646 Z15.8 F36000
G1 X135.528 Y133.623 Z15.8
G1 Z15.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4451
G1 X135.401 Y133.777 E.0066
G3 X127.148 Y118.64 I-7.41 J-5.778 E1.23446
G3 X128.422 Y118.612 I.915 J12.63 E.0423
G3 X135.606 Y133.504 I-.431 J9.387 E.67044
G1 X135.561 Y133.573 E.00273
G1 X135.839 Y133.857 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4451
M204 S6000
G1 X135.492 Y134.298 E.01726
G3 X118.481 Y125.717 I-7.492 J-6.299 E.8054
M73 P94 R0
G3 X128.437 Y118.22 I9.52 J2.283 E.4151
G3 X135.929 Y133.738 I-.437 J9.779 E.64747
G1 X135.875 Y133.809 E.00274
M204 S10000
G1 X135.325 Y133.386 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231605
G1 F4451
G1 X134.967 Y133.857 E.00909
G3 X118.901 Y128.092 I-6.968 J-5.853 E.34044
G1 X118.901 Y128.088 E.00006
G3 X118.923 Y127.364 I9.125 J-.084 E.01114
G1 X118.946 Y127.092 E.0042
G3 X135.458 Y133.218 I9.054 J.913 E.51084
G1 X135.362 Y133.339 E.00238
; CHANGE_LAYER
; Z_HEIGHT: 15.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X134.967 Y133.857 E-.24747
G1 X134.532 Y134.335 E-.24555
G1 X134.287 Y134.578 E-.13111
G1 X134.018 Y134.814 E-.13587
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L78
M991 S0 P77 ;notify layer change


G17
G3 Z15.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z15.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.029 Y135.261 E.00049
G3 X127.824 Y119.199 I4.973 J-7.262 E.73606
G3 X126.162 Y136.606 I.175 J8.8 E.98443
G3 X123.625 Y135.635 I1.84 J-8.607 E.09045
G1 X123.091 Y135.302 E.02087
G1 X123.26 Y134.946 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.253 Y134.934 E.00043
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G3 X128.587 Y119.611 I.126 J9.478 E.02323
G1 X128.84 Y119.631 E.00778
G3 X123.822 Y135.291 I-.84 J8.365 E.92002
G1 X123.311 Y134.977 E.01843
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.02763
G1 X122.71 Y134.537 E-.25569
G1 X122.452 Y134.32 E-.12796
G1 X121.965 Y133.856 E-.25565
G1 X121.798 Y133.677 E-.09307
; WIPE_END
G1 E-.04 F1800
G1 X129.43 Y133.642 Z16 F36000
G1 X135.532 Y133.613 Z16
G1 Z15.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.186 Y134.041 E.01825
G3 X127.488 Y118.615 I-7.197 J-6.042 E1.23461
G3 X128.435 Y118.613 I.504 J10.213 E.03144
G3 X135.605 Y133.504 I-.446 J9.387 E.66993
G1 X135.565 Y133.563 E.00239
G1 X135.843 Y133.856 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.71 Y134.018 E.00643
G3 X127.112 Y118.25 I-7.718 J-6.02 E1.19106
G3 X128.45 Y118.221 I.952 J13.124 E.04112
G3 X135.923 Y133.734 I-.458 J9.778 E.64666
G1 X135.876 Y133.806 E.00266
M204 S10000
G1 X135.326 Y133.384 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231521
G1 F4449
G1 X134.966 Y133.856 E.00913
G3 X118.901 Y128.092 I-6.967 J-5.853 E.34024
G1 X118.901 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.457 Y133.217 I9.096 J.252 E.52076
G1 X135.363 Y133.337 E.00234
; CHANGE_LAYER
; Z_HEIGHT: 15.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.966 Y133.856 E-.24855
G1 X134.532 Y134.335 E-.24548
G1 X134.287 Y134.578 E-.13133
G1 X134.02 Y134.812 E-.13464
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L79
M991 S0 P78 ;notify layer change


G17
G3 Z16 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z15.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.262 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06288
G1 X123.091 Y135.302 E.02087
G1 X123.263 Y134.947 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.253 Y134.934 E.00052
G3 X127.832 Y119.591 I4.747 J-6.938 E.65134
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94069
G1 X123.314 Y134.979 E.01833
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.02893
G1 X122.71 Y134.537 E-.25569
G1 X122.452 Y134.32 E-.1279
G1 X121.965 Y133.856 E-.25571
G1 X121.8 Y133.679 E-.09178
; WIPE_END
G1 E-.04 F1800
G1 X129.432 Y133.641 Z16.2 F36000
G1 X135.534 Y133.611 Z16.2
G1 Z15.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.186 Y134.041 E.01834
G3 X127.49 Y118.615 I-7.196 J-6.043 E1.23459
G3 X128.44 Y118.613 I.502 J10.223 E.03152
G3 X135.605 Y133.504 I-.45 J9.386 E.66982
G1 X135.567 Y133.561 E.00228
G1 X135.845 Y133.854 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.709 Y134.017 E.00652
G3 X127.467 Y118.224 I-7.719 J-6.019 E1.20213
M73 P95 R0
G3 X128.46 Y118.221 I.525 J10.657 E.0305
G3 X135.922 Y133.733 I-.47 J9.777 E.64628
G1 X135.877 Y133.803 E.00257
M204 S10000
G1 X135.328 Y133.382 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231577
G1 F4449
G1 X134.963 Y133.853 E.00917
G3 X118.91 Y128.385 I-6.963 J-5.857 E.33562
G1 X118.901 Y128.088 E.00457
G3 X118.923 Y127.364 I9.067 J-.086 E.01114
G1 X118.94 Y127.163 E.00311
G3 X135.455 Y133.211 I9.06 J.833 E.51196
G1 X135.364 Y133.334 E.00235
; CHANGE_LAYER
; Z_HEIGHT: 16
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X134.963 Y133.853 E-.24935
G1 X134.532 Y134.335 E-.24566
G1 X134.287 Y134.578 E-.13126
G1 X134.022 Y134.811 E-.13373
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L80
M991 S0 P79 ;notify layer change


G17
G3 Z16.2 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z16
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4450
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.261 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06288
G1 X123.091 Y135.302 E.02088
G1 X123.266 Y134.949 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4450
M204 S6000
G1 X123.253 Y134.934 E.00063
G3 X127.832 Y119.591 I4.747 J-6.938 E.65134
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94069
G1 X123.317 Y134.981 E.01822
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.03028
G1 X122.71 Y134.537 E-.25564
G1 X122.452 Y134.32 E-.1279
G1 X121.965 Y133.856 E-.25564
G1 X121.802 Y133.682 E-.09055
; WIPE_END
G1 E-.04 F1800
G1 X129.435 Y133.648 Z16.4 F36000
G1 X135.526 Y133.621 Z16.4
G1 Z16
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4450
G1 X135.439 Y133.73 E.00464
G3 X127.488 Y118.615 I-7.447 J-5.731 E1.24779
G3 X128.452 Y118.613 I.505 J10.279 E.03199
G3 X135.801 Y133.225 I-.461 J9.386 E.65818
G1 X135.56 Y133.571 E.01401
G1 X135.844 Y133.85 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4450
M204 S6000
G1 X135.748 Y133.97 E.00473
G3 X127.467 Y118.224 I-7.757 J-5.971 E1.20401
G3 X128.472 Y118.222 I.526 J10.709 E.03091
G3 X136.127 Y133.443 I-.481 J9.777 E.63508
G1 X135.878 Y133.801 E.01339
M204 S10000
G1 X135.32 Y133.385 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231575
G1 F4450
G1 X135.013 Y133.788 E.00779
G3 X118.91 Y128.398 I-7.013 J-5.799 E.33654
G1 X118.901 Y128.088 E.00476
G3 X118.904 Y127.728 I57.527 J.409 E.00554
G1 X118.919 Y127.421 E.00473
G3 X135.556 Y133.06 I9.082 J.569 E.5134
G1 X135.355 Y133.336 E.00525
; CHANGE_LAYER
; Z_HEIGHT: 16.2
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X135.013 Y133.788 E-.21539
G1 X134.522 Y134.345 E-.28221
G1 X134.27 Y134.594 E-.13442
G1 X134.018 Y134.817 E-.12798
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L81
M991 S0 P80 ;notify layer change


G17
G3 Z16.4 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z16.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.261 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06287
G1 X123.091 Y135.302 E.02088
G1 X123.269 Y134.951 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.253 Y134.934 E.00073
G3 X127.832 Y119.591 I4.747 J-6.938 E.65134
G1 X128.168 Y119.591 E.01034
G3 X123.823 Y135.291 I-.168 J8.405 E.94068
G1 X123.32 Y134.982 E.01812
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.03154
G1 X122.71 Y134.537 E-.25564
G1 X122.452 Y134.32 E-.12796
G1 X121.965 Y133.856 E-.25571
G1 X121.805 Y133.684 E-.08915
; WIPE_END
G1 E-.04 F1800
G1 X129.437 Y133.641 Z16.6 F36000
G1 X135.537 Y133.607 Z16.6
G1 Z16.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.185 Y134.04 E.01853
G3 X127.488 Y118.615 I-7.192 J-6.044 E1.23399
G3 X128.465 Y118.614 I.507 J10.329 E.03242
G3 X135.604 Y133.503 I-.472 J9.383 E.66902
G1 X135.57 Y133.556 E.00212
G1 X135.848 Y133.849 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
M73 P96 R0
G1 X135.708 Y134.017 E.0067
G3 X127.467 Y118.224 I-7.716 J-6.02 E1.20165
G3 X128.485 Y118.222 I.528 J10.76 E.03131
G3 X135.922 Y133.733 I-.493 J9.774 E.64555
G1 X135.88 Y133.799 E.0024
M204 S10000
G1 X135.331 Y133.378 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231613
G1 F4449
G1 X134.961 Y133.852 E.00925
G3 X118.91 Y128.41 I-6.961 J-5.86 E.33523
G1 X118.901 Y128.088 E.00495
G3 X118.904 Y127.728 I57.407 J.41 E.00553
G1 X118.919 Y127.421 E.00473
G3 X135.455 Y133.211 I9.081 J.572 E.51618
G1 X135.367 Y133.329 E.00227
; CHANGE_LAYER
; Z_HEIGHT: 16.4
; LAYER_HEIGHT: 0.199999
; WIPE_START
G1 F15000
G1 X134.961 Y133.852 E-.25151
G1 X134.286 Y134.579 E-.37672
G1 X134.026 Y134.807 E-.13177
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L82
M991 S0 P81 ;notify layer change


G17
G3 Z16.6 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.04 Y135.27
G1 Z16.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X123.031 Y135.257 E.00053
G3 X127.824 Y119.199 I4.969 J-7.262 E.73594
G1 X128.176 Y119.199 E.01169
G3 X123.628 Y135.631 I-.176 J8.797 E1.06288
G1 X123.091 Y135.302 E.02087
G1 X123.272 Y134.953 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X123.253 Y134.934 E.00082
G3 X127.832 Y119.591 I4.747 J-6.938 E.65134
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94069
G1 X123.323 Y134.984 E.01802
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.03274
G1 X122.71 Y134.537 E-.25563
G1 X122.452 Y134.32 E-.12796
G1 X121.965 Y133.856 E-.25571
G1 X121.807 Y133.687 E-.08797
; WIPE_END
G1 E-.04 F1800
G1 X129.439 Y133.641 Z16.8 F36000
G1 X135.539 Y133.604 Z16.8
G1 Z16.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4449
G1 X135.186 Y134.043 E.01867
G3 X127.83 Y118.603 I-7.195 J-6.045 E1.24572
G3 X128.477 Y118.614 I.17 J8.922 E.02149
G3 X135.607 Y133.505 I-.486 J9.384 E.66868
G1 X135.573 Y133.555 E.00201
G1 X135.848 Y133.846 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4449
M204 S6000
G1 X135.487 Y134.295 E.0177
G3 X127.823 Y118.211 I-7.495 J-6.296 E1.20209
G3 X128.498 Y118.222 I.177 J9.297 E.02076
G3 X135.924 Y133.734 I-.506 J9.776 E.64522
G1 X135.882 Y133.796 E.0023
M204 S10000
G1 X135.313 Y133.405 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231594
G1 F4449
G1 X135.239 Y133.503 E.00189
G3 X118.911 Y128.422 I-7.239 J-5.512 E.34182
G1 X118.901 Y128.088 E.00514
G1 X118.904 Y127.751 E.00518
G3 X135.734 Y132.783 I9.096 J.241 E.51336
G1 X135.346 Y133.356 E.01063
; CHANGE_LAYER
; Z_HEIGHT: 16.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X135.239 Y133.503 E-.06947
G1 X134.747 Y134.105 E-.29509
G1 X134.506 Y134.362 E-.13403
G1 X134.043 Y134.802 E-.24259
G1 X134.005 Y134.833 E-.01882
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L83
M991 S0 P82 ;notify layer change


G17
G3 Z16.8 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.015 Y135.253
G1 Z16.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4466
G1 X122.45 Y134.823 E.02355
G3 X127.824 Y119.199 I5.55 J-6.828 E.71188
G1 X128.176 Y119.199 E.01169
G3 X123.067 Y135.282 I-.176 J8.797 E1.08478
G1 X123.274 Y134.955 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4466
M204 S6000
G1 X123.253 Y134.934 E.00092
G3 X127.832 Y119.591 I4.747 J-6.938 E.65134
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94069
G1 X123.325 Y134.986 E.01792
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.03396
G1 X122.694 Y134.523 E-.26352
G1 X122.204 Y134.093 E-.24785
G1 X121.965 Y133.856 E-.1279
G1 X121.809 Y133.689 E-.08678
; WIPE_END
G1 E-.04 F1800
G1 X129.441 Y133.647 Z17 F36000
G1 X135.53 Y133.613 Z17
G1 Z16.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F4466
G1 X135.404 Y133.779 E.0069
G3 X127.83 Y118.603 I-7.409 J-5.78 E1.25693
G3 X128.49 Y118.615 I.17 J9.09 E.02192
G3 X135.815 Y133.208 I-.495 J9.384 E.65636
G1 X135.564 Y133.564 E.01446
G1 X135.848 Y133.842 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4466
M204 S6000
M73 P97 R0
G1 X135.713 Y134.02 E.00685
G3 X127.823 Y118.211 I-7.718 J-6.021 E1.21287
G3 X128.511 Y118.223 I.177 J9.475 E.02116
G3 X136.141 Y133.426 I-.516 J9.775 E.63337
G1 X135.882 Y133.793 E.01382
M204 S10000
G1 X135.324 Y133.379 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.231593
G1 F4466
G1 X135.018 Y133.794 E.00793
G3 X118.901 Y128.092 I-7.019 J-5.791 E.34163
G1 X118.9 Y128.088 E.00006
G1 X118.904 Y127.751 E.00518
G3 X135.573 Y133.046 I9.096 J.252 E.51778
G1 X135.36 Y133.331 E.00547
; CHANGE_LAYER
; Z_HEIGHT: 16.8
; LAYER_HEIGHT: 0.199999
; WIPE_START
G1 F15000
G1 X135.018 Y133.794 E-.21875
G1 X134.521 Y134.346 E-.2822
G1 X134.27 Y134.594 E-.13409
G1 X134.024 Y134.812 E-.12497
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L84
M991 S0 P83 ;notify layer change


G17
G3 Z17 I1.217 J0 P1  F36000
;======== P2S timeslape gcode ==========
;===== 2025/06/16 ====
; SKIPPABLE_START
; SKIPTYPE: timelapse
M622.1 S1 ; for prev firware, default turned on

M1002 judge_flag timelapse_record_flag
M622 J1
 ; timelapse without wipe tower
  M971 S11 C10 O0
  M1004 S5 P1  ; external shutter

M623
; SKIPPABLE_END

; OBJECT_ID: 15
G1 X123.277 Y134.956
G1 Z16.8
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F6499
M204 S6000
G1 X123.253 Y134.934 E.00102
G3 X127.832 Y119.591 I4.747 J-6.938 E.65133
G1 X128.168 Y119.591 E.01034
G3 X123.822 Y135.291 I-.168 J8.405 E.94069
G1 X123.328 Y134.988 E.01782
; WIPE_START
G1 F12000
M204 S10000
G1 X123.253 Y134.934 E-.03521
G1 X122.71 Y134.537 E-.2555
G1 X122.452 Y134.32 E-.12797
G1 X121.965 Y133.856 E-.25565
G1 X121.811 Y133.691 E-.08567
; WIPE_END
G1 E-.04 F1800
G1 X129.443 Y133.773 Z17.2 F36000
G1 X135.851 Y133.842 Z17.2
G1 Z16.8
G1 E.8 F1800
G1 F6499
M204 S6000
G1 X135.492 Y134.286 E.01755
G3 X128.177 Y118.211 I-7.497 J-6.291 E1.21277
G1 X128.523 Y118.223 E.01064
G3 X135.923 Y133.734 I-.528 J9.772 E.64453
G1 X135.884 Y133.792 E.00215
; WIPE_START
G1 F12000
M204 S10000
G1 X135.492 Y134.286 E-.23974
G1 X135.259 Y134.568 E-.13881
G1 X134.764 Y135.077 E-.27015
G1 X134.545 Y135.272 E-.1113
; WIPE_END
G1 E-.04 F1800
G1 X132.75 Y136.315 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
; FEATURE: Top surface
G1 F6499
M204 S2000
G1 X136.331 Y132.734 E.15561
G1 X136.834 Y131.697
G1 X131.7 Y136.832 E.22311
; WIPE_START
G1 F12000
M204 S10000
G1 X133.114 Y135.418 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X132.939 Y135.059 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
G1 F6499
M204 S2000
G1 X130.859 Y137.14 E.0904
G1 X130.13 Y137.335
G1 X131.682 Y135.783 E.06746
G1 X130.777 Y136.154
G1 X129.469 Y137.462 E.05684
G1 X128.857 Y137.542
G1 X130.023 Y136.375 E.0507
G1 X129.356 Y136.509
G1 X128.29 Y137.575 E.04634
G1 X127.757 Y137.575
G1 X128.755 Y136.577 E.04338
G1 X128.189 Y136.61
G1 X127.252 Y137.546 E.04069
G1 X126.768 Y137.497
G1 X127.656 Y136.61 E.03856
G1 X127.162 Y136.57
G1 X126.303 Y137.429 E.03732
G1 X125.861 Y137.338
G1 X126.684 Y136.515 E.03576
G1 X126.238 Y136.428
G1 X125.438 Y137.228 E.03476
G1 X125.025 Y137.107
G1 X125.802 Y136.33 E.03376
G1 X125.393 Y136.206
G1 X124.63 Y136.969 E.03314
G1 X124.254 Y136.812
G1 X124.992 Y136.074 E.0321
G1 X124.616 Y135.917
G1 X123.884 Y136.649 E.03181
G1 X123.53 Y136.469
G1 X124.247 Y135.753 E.03112
G1 X123.896 Y135.57
G1 X123.184 Y136.282 E.03093
G1 X122.856 Y136.077
G1 X123.554 Y135.379 E.03034
G1 X123.23 Y135.169
G1 X122.534 Y135.866 E.03028
G1 X122.223 Y135.643
G1 X122.914 Y134.952 E.03002
G1 X122.611 Y134.722
G1 X121.928 Y135.405 E.02964
G1 X121.636 Y135.163
G1 X122.325 Y134.475 E.02992
G1 X122.042 Y134.224
G1 X121.364 Y134.903 E.02949
G1 X121.094 Y134.639
G1 X121.78 Y133.954 E.0298
G1 X121.522 Y133.678
G1 X120.841 Y134.36 E.02962
G1 X120.592 Y134.075
G1 X121.281 Y133.386 E.02995
G1 X121.047 Y133.087
G1 X120.357 Y133.777 E.02998
G1 X120.135 Y133.465
G1 X120.83 Y132.77 E.0302
G1 X120.622 Y132.445
G1 X119.921 Y133.146 E.03044
G1 X119.721 Y132.813
G1 X120.426 Y132.108 E.03063
G1 X120.25 Y131.751
G1 X119.528 Y132.473 E.03137
G1 X119.353 Y132.114
G1 X120.079 Y131.388 E.03154
G1 X119.93 Y131.004
G1 X119.183 Y131.751 E.03245
G1 X119.033 Y131.368
G1 X119.793 Y130.608 E.033
G1 X119.67 Y130.197
G1 X118.895 Y130.973 E.03368
G1 X118.769 Y130.566
G1 X119.567 Y129.767 E.03469
G1 X119.489 Y129.312
G1 X118.66 Y130.141 E.03599
G1 X118.574 Y129.694
G1 X119.43 Y128.837 E.0372
G1 X119.392 Y128.342
G1 X118.499 Y129.236 E.03882
G1 X118.453 Y128.748
G1 X119.387 Y127.814 E.04058
G1 X119.42 Y127.248
G1 X118.426 Y128.242 E.0432
G1 X118.423 Y127.712
G1 X119.491 Y126.644 E.04641
G1 X119.632 Y125.97
G1 X118.459 Y127.143 E.05096
G1 X118.531 Y126.537
G1 X119.849 Y125.219 E.05726
G1 X120.204 Y124.331
G1 X118.662 Y125.873 E.06701
G1 X118.857 Y125.145
G1 X120.953 Y123.049 E.09106
; WIPE_START
G1 F12000
M204 S10000
G1 X119.538 Y124.463 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X126.231 Y128.132 Z17.2 F36000
G1 X135.038 Y132.96 Z17.2
G1 Z16.8
G1 E.8 F1800
G1 F6499
M204 S2000
G1 X137.148 Y130.85 E.09171
G1 X137.344 Y130.121
G1 X135.784 Y131.681 E.06778
G1 X136.158 Y130.774
G1 X137.463 Y129.469 E.0567
G1 X137.538 Y128.861
G1 X136.371 Y130.027 E.05068
G1 X136.506 Y129.359
G1 X137.577 Y128.289 E.04652
G1 X137.573 Y127.759
G1 X136.584 Y128.748 E.04298
G1 X136.612 Y128.187
G1 X137.549 Y127.25 E.04071
G1 X137.5 Y126.765
G1 X136.609 Y127.656 E.0387
G1 X136.571 Y127.162
G1 X137.426 Y126.307 E.03715
G1 X137.339 Y125.86
G1 X136.515 Y126.683 E.03579
G1 X136.429 Y126.236
G1 X137.232 Y125.434 E.03486
G1 X137.104 Y125.029
G1 X136.327 Y125.805 E.03375
G1 X136.212 Y125.388
G1 X136.97 Y124.629 E.03294
G1 X136.815 Y124.251
G1 X136.074 Y124.992 E.03222
G1 X135.918 Y124.614
G1 X136.649 Y123.884 E.03173
M73 P98 R0
G1 X136.47 Y123.529
G1 X135.752 Y124.247 E.0312
G1 X135.572 Y123.894
G1 X136.282 Y123.184 E.03083
G1 X136.082 Y122.851
G1 X135.376 Y123.556 E.03064
G1 X135.174 Y123.226
G1 X135.864 Y122.535 E.03002
G1 X135.644 Y122.222
G1 X134.955 Y122.911 E.02995
G1 X134.719 Y122.614
G1 X135.405 Y121.928 E.02983
G1 X135.164 Y121.636
G1 X134.48 Y122.32 E.02971
G1 X134.223 Y122.043
G1 X134.906 Y121.361 E.02966
G1 X134.638 Y121.095
G1 X133.955 Y121.778 E.02966
G1 X133.677 Y121.523
G1 X134.363 Y120.837 E.02983
G1 X134.076 Y120.591
G1 X133.388 Y121.279 E.0299
G1 X133.084 Y121.049
G1 X133.774 Y120.359 E.02999
G1 X133.468 Y120.133
G1 X132.773 Y120.827 E.03017
G1 X132.448 Y120.619
G1 X133.145 Y119.922 E.03027
G1 X132.818 Y119.716
G1 X132.104 Y120.429 E.031
G1 X131.754 Y120.246
G1 X132.474 Y119.527 E.03126
G1 X132.115 Y119.352
G1 X131.386 Y120.081 E.03169
G1 X131.008 Y119.926
G1 X131.749 Y119.185 E.03218
G1 X131.368 Y119.032
G1 X130.608 Y119.793 E.03304
G1 X130.2 Y119.668
G1 X130.976 Y118.891 E.03373
G1 X130.562 Y118.772
G1 X129.764 Y119.57 E.03468
G1 X129.313 Y119.488
G1 X130.139 Y118.662 E.03592
G1 X129.696 Y118.572
G1 X128.844 Y119.424 E.03701
G1 X128.341 Y119.394
G1 X129.237 Y118.497 E.03895
G1 X128.749 Y118.452
G1 X127.817 Y119.384 E.0405
G1 X127.25 Y119.418
G1 X128.242 Y118.426 E.04312
G1 X127.712 Y118.422
G1 X126.64 Y119.495 E.04662
G1 X125.977 Y119.624
G1 X127.146 Y118.455 E.05081
G1 X126.536 Y118.532
G1 X125.223 Y119.845 E.05703
G1 X124.331 Y120.204
G1 X125.876 Y118.659 E.06711
G1 X125.149 Y118.853
G1 X123.06 Y120.942 E.09078
; WIPE_START
G1 F12000
M204 S10000
G1 X124.474 Y119.528 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X124.305 Y119.164 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
G1 F6499
M204 S2000
G1 X119.156 Y124.313 E.22375
G1 X119.679 Y123.256
G1 X123.261 Y119.675 E.15563
; WIPE_START
G1 F12000
M204 S10000
G1 X121.846 Y121.089 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X128.792 Y124.254 Z17.2 F36000
G1 X136.682 Y127.849 Z17.2
G1 Z16.8
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.1245
G1 F6499
G1 X136.592 Y127.639 E.00152
; WIPE_START
G1 F15000
G1 X136.682 Y127.849 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X137.004 Y131.294 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
; LINE_WIDTH: 0.189752
G1 F6499
G1 X136.772 Y131.635 E.00493
G1 X135.846 Y131.742 F36000
; LINE_WIDTH: 0.199044
G1 F6499
G1 X135.77 Y131.849 E.00167
; LINE_WIDTH: 0.165011
G1 X135.694 Y131.956 E.00131
; LINE_WIDTH: 0.130608
G1 X135.616 Y132.066 E.00096
; LINE_WIDTH: 0.10065
G1 X135.542 Y132.161 E.00057
G1 X135.098 Y133.021 F36000
; LINE_WIDTH: 0.214351
G1 F6499
G1 X134.905 Y133.252 E.00421
; LINE_WIDTH: 0.175778
G1 X134.665 Y133.521 E.0039
; LINE_WIDTH: 0.131738
G1 X134.199 Y134.013 E.0049
G1 X133.701 Y134.498 E.00503
; LINE_WIDTH: 0.153697
G1 X133.446 Y134.728 E.0031
; LINE_WIDTH: 0.190052
G1 X133.187 Y134.961 E.00418
; LINE_WIDTH: 0.220892
G1 X132.999 Y135.12 E.00357
; WIPE_START
G1 F15000
G1 X133.187 Y134.961 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.8 Y133.56 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
; LINE_WIDTH: 0.0920904
G1 F6499
G1 X135.757 Y133.612 E.00027
; LINE_WIDTH: 0.117182
G1 X135.529 Y133.87 E.00209
; LINE_WIDTH: 0.159525
G1 X135.3 Y134.128 E.00328
; LINE_WIDTH: 0.199943
G3 X134.069 Y135.355 I-16.679 J-15.518 E.02224
; LINE_WIDTH: 0.153927
G1 X133.813 Y135.583 E.0031
; LINE_WIDTH: 0.111323
G1 X133.585 Y135.776 E.00167
; WIPE_START
G1 F15000
G1 X133.813 Y135.583 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X132.158 Y135.546 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
; LINE_WIDTH: 0.10112
G1 F6499
G1 X132.076 Y135.607 E.00049
; LINE_WIDTH: 0.127414
G1 X131.992 Y135.67 E.00073
; LINE_WIDTH: 0.159466
G1 X131.868 Y135.758 E.00144
; LINE_WIDTH: 0.196506
G1 X131.744 Y135.845 E.0019
; WIPE_START
G1 F15000
G1 X131.868 Y135.758 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X132.688 Y136.254 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
; LINE_WIDTH: 0.19923
G1 F6499
G1 X132.521 Y136.381 E.00268
; LINE_WIDTH: 0.153751
G1 X132.353 Y136.507 E.0019
; LINE_WIDTH: 0.10959
G1 X132.229 Y136.596 E.00083
G1 X131.637 Y136.77 F36000
; LINE_WIDTH: 0.190878
G1 F6499
G1 X131.465 Y136.885 E.0025
; LINE_WIDTH: 0.150866
G1 X131.293 Y137.001 E.00182
; WIPE_START
G1 F15000
G1 X131.465 Y136.885 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X124.833 Y133.109 Z17.2 F36000
G1 X119.662 Y130.166 Z17.2
G1 Z16.8
G1 E.8 F1800
; LINE_WIDTH: 0.093271
G1 F6499
G1 X119.58 Y130.021 E.00068
G1 X119.411 Y129.235 F36000
; LINE_WIDTH: 0.0902846
G1 F6499
G1 X119.467 Y129.067 E.00068
; WIPE_START
G1 F15000
G1 X119.411 Y129.235 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X119.714 Y125.645 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
; LINE_WIDTH: 0.103791
G1 F6499
G2 X119.564 Y125.902 I5.714 J3.521 E.00147
; WIPE_START
G1 F15000
G1 X119.714 Y125.645 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X120.464 Y123.832 Z17.2 F36000
G1 Z16.8
M73 P99 R0
G1 E.8 F1800
; LINE_WIDTH: 0.106556
G1 F6499
G1 X120.376 Y123.948 E.00075
; LINE_WIDTH: 0.143783
G1 X120.286 Y124.067 E.00123
; LINE_WIDTH: 0.176141
G1 X120.214 Y124.169 E.00135
; LINE_WIDTH: 0.202821
G1 X120.142 Y124.27 E.00162
; WIPE_START
G1 F15000
G1 X120.214 Y124.169 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X122.441 Y120.198 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
; LINE_WIDTH: 0.0994567
G1 F6499
G1 X122.321 Y120.3 E.00072
; LINE_WIDTH: 0.133979
G1 X122.053 Y120.534 E.00264
; LINE_WIDTH: 0.170418
G1 X121.801 Y120.768 E.00357
; LINE_WIDTH: 0.206078
G2 X120.821 Y121.74 I11.743 J12.827 E.01836
; LINE_WIDTH: 0.180961
G1 X120.59 Y121.992 E.00385
; LINE_WIDTH: 0.14672
G1 X120.4 Y122.21 E.00244
; LINE_WIDTH: 0.10768
G1 X120.211 Y122.428 E.00152
; WIPE_START
G1 F15000
G1 X120.4 Y122.21 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.071 Y120.953 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
; LINE_WIDTH: 0.192262
G1 F6499
G1 X122.927 Y120.942 E.00176
; LINE_WIDTH: 0.210497
G1 X122.68 Y121.159 E.00448
; LINE_WIDTH: 0.1692
G1 X122.432 Y121.378 E.00341
; LINE_WIDTH: 0.127806
G1 X121.681 Y122.11 E.00726
; LINE_WIDTH: 0.134494
G1 X121.447 Y122.362 E.00257
; LINE_WIDTH: 0.160503
G1 X121.209 Y122.619 E.00335
; LINE_WIDTH: 0.188945
G1 X121.051 Y122.804 E.0029
; LINE_WIDTH: 0.219204
G1 X120.892 Y122.989 E.0035
; WIPE_START
G1 F15000
G1 X121.051 Y122.804 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X124.27 Y120.142 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
; LINE_WIDTH: 0.203989
G1 F6499
G1 X124.143 Y120.231 E.00202
; LINE_WIDTH: 0.174853
G1 X124.04 Y120.308 E.00139
; LINE_WIDTH: 0.140176
G1 X123.936 Y120.386 E.00103
; LINE_WIDTH: 0.1055
G1 X123.833 Y120.463 E.00066
; WIPE_START
G1 F15000
G1 X123.936 Y120.386 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.774 Y119.401 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
; LINE_WIDTH: 0.110176
G1 F6499
G1 X123.623 Y119.512 E.00103
; LINE_WIDTH: 0.154178
G1 X123.472 Y119.624 E.0017
; LINE_WIDTH: 0.19818
G1 X123.322 Y119.736 E.00237
; WIPE_START
G1 F15000
G1 X123.472 Y119.624 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X125.911 Y119.558 Z17.2 F36000
G1 Z16.8
G1 E.8 F1800
; LINE_WIDTH: 0.150216
G1 F6499
G1 X125.641 Y119.715 E.00273
; close powerlost recovery
M1003 S0
; WIPE_START
G1 F15000
G1 X125.911 Y119.558 E-.76
; WIPE_END
G1 E-.04 F1800
M106 S0
M106 P2 S0
M981 S0 P20000 ; close spaghetti detector
; FEATURE: Custom
; MACHINE_END_GCODE_START
; filament end gcode 

;======== P2S end gcode ==========
;===== 2025/11/03 =====
M400 ; wait for buffer to clear
G92 E0 ; zero the extruder
G1 E-0.8 F1800 ; retract
G0 Z17.6 F900

; pull back filament to AMS
M620 S65535
T65535
G150.2
M621 S65535

G150.3

M400 ; wait all motion done
M991 S0 P-1 ;end smooth timelapse at safe pos

M1002 judge_flag timelapse_record_flag
M622 J1
    M400 S5 ;wait for last picture to be taken
M623  ;end of "timelapse_record_flag"

M106 S0 ; turn off fan
M106 P2 S0 ; turn off remote part cooling fan
M106 P3 S0 ; turn off chamber cooling fan
M106 P10 S0 ; turn off left aux fan

M400 ; wait all motion done
M17 S
M17 Z0.4 ; lower z motor current to reduce impact if there is something in the bottom

    
        G1 Z88.4 F600
        G1 Z86.4
    

M400 P100
M17 R ; restore z current


M220 S100  ; Reset feedrate magnitude
M201.2 K1.0 ; Reset acc magnitude
M73.2 R1.0 ;Reset left time magnitude
M1002 set_gcode_claim_speed_level : 0

M1015.3 S0 ;disable clog detect
M1015.4 S0 K0 ;disable air printing detect
;=====printer finish  sound=========
M17
M400 S1
M1006 S1
M1006 A53 B10 L99 C53 D10 M99 E53 F10 N99 
M1006 A57 B10 L99 C57 D10 M99 E57 F10 N99 
M1006 A0 B15 L0 C0 D15 M0 E0 F15 N0 
M1006 A53 B10 L99 C53 D10 M99 E53 F10 N99 
M1006 A57 B10 L99 C57 D10 M99 E57 F10 N99 
M1006 A0 B15 L0 C0 D15 M0 E0 F15 N0 
M1006 A48 B10 L99 C48 D10 M99 E48 F10 N99 
M1006 A0 B15 L0 C0 D15 M0 E0 F15 N0 
M1006 A60 B10 L99 C60 D10 M99 E60 F10 N99 
M1006 W
;=====printer finish  sound=========
M400
M18

M104 S0 ; turn off hotend
M140 S0 ; turn off bed
M73 P100 R0
; EXECUTABLE_BLOCK_END

