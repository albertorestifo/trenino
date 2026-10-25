; HEADER_BLOCK_START
; BambuStudio 02.04.00.70
; model printing time: 12m 1s; total estimated time: 19m 57s
; total layer number: 40
; total filament length [mm] : 2558.32
; total filament volume [cm^3] : 6153.49
; total filament weight [g] : 7.75
; filament_density: 1.26
; filament_diameter: 1.75
; max_z_height: 8.00
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
; bottom_shell_layers = 3
; bottom_shell_thickness = 0
; bottom_surface_pattern = monotonic
; bridge_angle = 0
; bridge_flow = 1
; bridge_no_support = 0
; bridge_speed = 50
; brim_object_gap = 0.1
; brim_type = auto_brim
; brim_width = 5
; chamber_temperatures = 0
; change_filament_gcode = ;======== P2S filament_change gcode ==========\n;===== 2025/11/10 =====\n\nM620 S[next_extruder]A\nM204 S9000\n{if toolchange_count > 1 && (z_hop_types[current_extruder] == 0 || z_hop_types[current_extruder] == 3)}\nG17\nG2 Z{z_after_toolchange + 0.4} I0.86 J0.86 P1 F10000 ; spiral lift a little from second lift\n{endif}\n\n;nozzle_change_gcode\n\nG1 Z{max_layer_z + 3.0} F1200\n\nM400\nM106 P1 S0\n\n{if toolchange_count == 2}\n; get travel path for change filament\n;M620.1 X[travel_point_1_x] Y[travel_point_1_y] F21000 P0\n;M620.1 X[travel_point_2_x] Y[travel_point_2_y] F21000 P1\n;M620.1 X[travel_point_3_x] Y[travel_point_3_y] F21000 P2\n{endif}\n\n{if ((filament_type[current_extruder] == "PLA") || (filament_type[current_extruder] == "PLA-CF") || (filament_type[current_extruder] == "PETG")) && (nozzle_diameter[current_extruder] == 0.2)}\nM620.10 A0 F74.8347 L[flush_length] H{nozzle_diameter[current_extruder]} T{flush_temperatures[current_extruder]} P[old_filament_temp] S1\n{else}\nM620.10 A0 F{flush_volumetric_speeds[current_extruder]/2.4053*60} L[flush_length] H{nozzle_diameter[current_extruder]} T{flush_temperatures[current_extruder]} P[old_filament_temp] S1\n{endif}\n\n{if ((filament_type[next_extruder] == "PLA") || (filament_type[next_extruder] == "PLA-CF") || (filament_type[next_extruder] == "PETG")) && (nozzle_diameter[next_extruder] == 0.2)}\nM620.10 A1 F74.8347 L[flush_length] H{nozzle_diameter[next_extruder]} T{flush_temperatures[next_extruder]} P[new_filament_temp] S1\n{else}\nM620.10 A1 F{flush_volumetric_speeds[next_extruder]/2.4053*60} L[flush_length] H{nozzle_diameter[next_extruder]} T{flush_temperatures[next_extruder]} P[new_filament_temp] S1\n{endif}\n\n{if long_retraction_when_cut}\nM620.11 P1 L0 I[current_extruder] E-{retraction_distance_when_cut} F{max((flush_volumetric_speeds[current_extruder]/2.4053*60), 200)}\n{else}\nM620.11 P0 L0 I[current_extruder] E0\n{endif}\n\nM620.11 K0 I[current_extruder] R0\n\n  \nT[next_extruder]\n\n;deretract\n{if filament_type[next_extruder] == "TPU"}\n{else}\n{if filament_type[next_extruder] == "PA"}\n;VG1 E1 F{max(new_filament_e_feedrate, 200)}\n;VG1 E1 F{max(new_filament_e_feedrate/2, 100)}\n{else}\n;VG1 E4 F{max(new_filament_e_feedrate, 200)}\n;VG1 E4 F{max(new_filament_e_feedrate/2, 100)}\n{endif}\n{endif}\n\n; VFLUSH_START\n{if flush_length>41.5}\n;VG1 E41.5 F{min(old_filament_e_feedrate,new_filament_e_feedrate)}\n;VG1 E{flush_length-41.5} F{new_filament_e_feedrate}\n{else}\n;VG1 E{flush_length} F{min(old_filament_e_feedrate,new_filament_e_feedrate)}\n{endif}\nSYNC T{ceil(flush_length / 80) * 5}\n; VFLUSH_END\n\nM1002 set_filament_type:{filament_type[next_extruder]}\n\nM400\nM83\n{if next_extruder < 255}\nM620.10 R{retract_length_toolchange[filament_map[next_extruder]-1]}\nM628 S0\n;VM109 S[new_filament_temp]\n\nM629\nM400\nM983.3 F{filament_max_volumetric_speed[next_extruder]/2.4} A0.4 R{retract_length_toolchange[filament_map[next_extruder]-1]}\nM400\n\nG1 Z{max_layer_z + 3.0} F3000\n{if layer_z <= (initial_layer_print_height + 0.001)}\nM204 S[initial_layer_acceleration]\n{else}\nM204 S[travel_acceleration]\n{endif}\n\n{else}\nG1 X[x_after_toolchange] Y[y_after_toolchange] Z[z_after_toolchange] F12000\n{endif}\n\nM621 S[next_extruder]A\n\n{if (filament_type[next_extruder] == "PLA") ||  (filament_type[next_extruder] == "PETG")\n ||  (filament_type[next_extruder] == "PLA-CF")  ||  (filament_type[next_extruder] == "PETG-CF")}\nM1015.4 S1 K1 H[nozzle_diameter] ;enable E air printing detect\n{else}\nM1015.4 S0 K0 H[nozzle_diameter] ;disable E air printing detect\n{endif}\n\nM620.6 I[next_extruder] W1 ;enable ams air printing detect\n\nG1 Y256 F18000\n\n{if (overall_chamber_temperature < 40)}\n{if (layer_num + 1 < close_fan_the_first_x_layers[next_extruder] + 1)}\n    {if (min_vitrification_temperature <= 50)}\n        M106 P2 S{first_x_layer_fan_speed[next_extruder]*255.0/100.0 };set first x_layer aux fan\n        M106 P10 S{first_x_layer_fan_speed[next_extruder]*255.0/100.0 };set first x_layer left aux fan \n    {endif}\n{else}\n    {if (min_vitrification_temperature <= 50)}\n        {if (nozzle_diameter == 0.2)}\n            M142 P1 R30 S40 U{max_additional_fan/100.0} V1.0 O45; set PLA/TPU ND0.2 chamber autocooling\n        {else}\n            M142 P1 R30 S40 U{max_additional_fan/100.0} V1.0 O45; set PLA/TPU ND0.4 chamber autocooling\n        {endif}\n    {endif}\n        M106 P10 S{additional_cooling_fan_speed[next_extruder]*255.0/100.0};set left aux fan \n{endif}\n{endif}\n;not set fan changing filament
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
; curr_bed_type = Supertack Plate
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
; filament_cooling_before_tower = 0
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
; machine_end_gcode = ;======== P2S end gcode ==========\n;===== 2025/11/12 =====\nM400 ; wait for buffer to clear\nG92 E0 ; zero the extruder\nG1 E-0.8 F1800 ; retract\nG0 Z{max_layer_z + 0.8} F900\n\n; pull back filament to AMS\nM620 S65535\nT65535\nG150.2\nM621 S65535\n\nG150.3\n\nM400 ; wait all motion done\n\nM1002 judge_flag timelapse_record_flag\nM622 J1\n    M991 S0 P-1 ;end smooth timelapse at safe pos\n    M400 S5 ;wait for last picture to be taken\nM623  ;end of "timelapse_record_flag"\n\nM106 S0 ; turn off fan\nM106 P2 S0 ; turn off remote part cooling fan\nM106 P3 S0 ; turn off chamber cooling fan\nM106 P10 S0 ; turn off left aux fan\n\nM400 ; wait all motion done\nM17 S\nM17 Z0.4 ; lower z motor current to reduce impact if there is something in the bottom\n{if (80.0 - max_layer_z/2) > 0}\n    {if (max_layer_z + 80.0 - max_layer_z/2) < 256}\n        G1 Z{max_layer_z + 80.0 - max_layer_z/2} F600\n        G1 Z{max_layer_z + 78.0 - max_layer_z/2}\n    {else}\n        G1 Z256 F600\n        G1 Z256\n    {endif}\n{else}\n    {if (max_layer_z + 4.0) < 256}\n        G1 Z{max_layer_z + 4.0} F600\n        G1 Z{max_layer_z + 2.0}\n    {else}\n        G1 Z256 F600\n        G1 Z256\n    {endif}\n{endif}\nM400 P100\nM17 R ; restore z current\n\n\nM220 S100  ; Reset feedrate magnitude\nM201.2 K1.0 ; Reset acc magnitude\nM73.2 R1.0 ;Reset left time magnitude\nM1002 set_gcode_claim_speed_level : 0\n\nM1015.3 S0 ;disable clog detect\nM1015.4 S0 K0 ;disable air printing detect\n\n;=====printer finish air purification=========\nM622.1 S0\nM1002 judge_flag print_finish_air_filt_flag\n\nM622 J1\nM1002 gcode_claim_action : 66\nM145 P1\nM106 P2 S255\nM400 S180\nM106 P2 S0\nM623\n\nM622 J2\nM1002 gcode_claim_action : 66\nM145 P0\nM106 P3 S255\nM400 S180\nM106 P3 S0\nM623\n;=====printer finish air purification=========\n\n;=====printer finish  sound=========\nM17\nM400 S1\nM1006 S1\nM1006 A53 B10 L50 C53 D10 M50 E53 F10 N50 \nM1006 A57 B10 L50 C57 D10 M50 E57 F10 N50 \nM1006 A0 B15 L0 C0 D15 M0 E0 F15 N0 \nM1006 A53 B10 L50 C53 D10 M50 E53 F10 N50 \nM1006 A57 B10 L50 C57 D10 M50 E57 F10 N50 \nM1006 A0 B15 L0 C0 D15 M0 E0 F15 N0 \nM1006 A48 B10 L50 C48 D10 M50 E48 F10 N50 \nM1006 A0 B15 L0 C0 D15 M0 E0 F15 N0 \nM1006 A60 B10 L50 C60 D10 M50 E60 F10 N50 \nM1006 W\n;=====printer finish  sound=========\nM400\nM18\n\nM104 S0 ; turn off hotend\nM140 S0 ; turn off bed
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
; machine_start_gcode = ;M1002 set_flag extrude_cali_flag=1\n;M1002 set_flag g29_before_print_flag=1\n;M1002 set_flag auto_cali_toolhead_offset_flag=1\n;M1002 set_flag build_plate_detect_flag=1\n\n;======== P2S start gcode==========\n;===== 2025/11/18 =====\n  \n  M140 S[bed_temperature_initial_layer_single] ; heat heatbed first\n  M993 A0 B0 C0 ; nozzle cam detection not allowed.\n  M400\n\n;=====printer start sound ===================\nM17\nM400 S1\nM1006 S1\nM1006 A53 B9 L50 C53 D9 M50 E53 F9 N50 \nM1006 A56 B9 L50 C56 D9 M50 E56 F9 N50 \nM1006 A61 B9 L50 C61 D9 M50 E61 F9 N50 \nM1006 A53 B9 L50 C53 D9 M50 E53 F9 N50 \nM1006 A56 B9 L50 C56 D9 M50 E56 F9 N50 \nM1006 A61 B18 L50 C61 D18 M50 E61 F18 N50 \nM1006 W\n;=====printer start sound ===================\n\n  M620 M ;enable remap\n  G389\n\n;===== avoid end stop =================\n  G91\n  G380 S2 Z22 F1200\n  G380 S2 Z-12 F1200\n  G90\n;===== avoid end stop =================\n\n;===== reset machine status =================\n  M204 S10000\n  M630 S0 P1\n  G90\n  M17 D ; reset motor current to default\n  M960 S5 P1 ; turn on logo lamp\n  G90\n  M220 S100 ;Reset Feedrate\n  M1002 set_gcode_claim_speed_level: 5\n  M221 S100 ;Reset Flowrate\n  M73.2   R1.0 ;Reset left time magnitude\n  G29.1 Z{+0.0} ; clear z-trim value first\n  M983.1 M1\n  M982.2 S1 ; turn on cog noise reduction\n  M983.4 S0\n;===== reset machine status =================\n\n;==== set airduct mode ==== \n;==== if Chamber Cooling is necessary ====\n{if (overall_chamber_temperature >= 40)}\nM145 P1 ; set airduct mode to heating mode for heating\nM106 P2 S255 ; turn on filter fan\n{else}\n{if (min_vitrification_temperature <= 50)}\nM145 P0 ; set airduct mode to cooling mode for cooling\nM106 P2 S255 ; turn on auxiliary fan for cooling\nM106 P3 S127 ; turn on chamber fan for cooling\nM1002 gcode_claim_action : 29\nM191 S0 ; wait for chamber temp\nM106 P2 S102 ; turn on chamber cooling fan\nM106 P10 S0 ; turn off left aux fan\nM142 P6 R30 S40 U0.3 V0.8 ; set PETG exhaust chamber autocooling\n{else}\nM145 P1 ; set airduct mode to heating mode for heating\nM106 P2 S127 ; turn on 50% filter fan\nM142 P6 R30 S40 U0.3 V0.8 ; set PLA/TPU exhaust chamber autocooling\n{endif}\n{endif}\n;==== set airduct mode ==== \n\n;===== start to heat heatbed & hotend==========\n  M1002 gcode_claim_action : 2\n  M1002 set_filament_type:{filament_type[initial_no_support_extruder]}\n  M104 S140 A        \n\n  G29.2 S0 ; avoid invalid abl data\n\n;===== first homing start =====\n  M1002 gcode_claim_action : 13\n  G28 X T300\n  G150.3\n  M972 S24 P0\n  M972 S26 P0 C0\n  M972 S42 P0 T5000\n  G150.1 F8000 ; wipe mouth to avoid filament stick to heatbed\n  G90\n  G1 X128 Y128 F30000\n  G28 Z P0 T400\n  M400\n;===== first homign end =====\n\n;===== detection start =====\n  M1002 gcode_claim_action : 11\n  M104 S{nozzle_temperature_initial_layer[initial_no_support_extruder]-80} A ; rise temp in advance\n  M972 S19 P0 T5000 ;plate type detection\n;===== detection end =====\n\n;===== prepare print temperature and material ==========\n  M400\n  M211 X0 Y0 Z0 ;turn off soft endstop\n  M975 S1 ; turn on input shaping\n  \n  G29.2 S0 ; avoid invalid abl data\n  G150.3\n{if ((filament_type[initial_no_support_extruder] == "PLA") || (filament_type[initial_no_support_extruder] == "PLA-CF") || (filament_type[initial_no_support_extruder] == "PETG")) && (nozzle_diameter[initial_no_support_extruder] == 0.2)}\nM620.10 A0 F74.8347 H{nozzle_diameter[initial_no_support_extruder]} T{flush_temperatures[initial_no_support_extruder]} P{nozzle_temperature_initial_layer[initial_no_support_extruder]} S1\nM620.10 A1 F74.8347 H{nozzle_diameter[initial_no_support_extruder]} T{flush_temperatures[initial_no_support_extruder]} P{nozzle_temperature_initial_layer[initial_no_support_extruder]} S1\n{else}\nM620.10 A0 F{flush_volumetric_speeds[initial_no_support_extruder]/2.4053*60} H{nozzle_diameter[initial_no_support_extruder]} T{flush_temperatures[initial_no_support_extruder]} P{nozzle_temperature_initial_layer[initial_no_support_extruder]} S1\nM620.10 A1 F{flush_volumetric_speeds[initial_no_support_extruder]/2.4053*60} H{nozzle_diameter[initial_no_support_extruder]} T{flush_temperatures[initial_no_support_extruder]} P{nozzle_temperature_initial_layer[initial_no_support_extruder]} S1\n{endif}\n  \n M620.11 P0 L0 I[initial_no_support_extruder] E0\n M620.11 K0 I[initial_no_support_extruder] R0\n  \n  M620 S[initial_no_support_extruder]A   ; switch material if AMS exist\n  M1002 gcode_claim_action : 4\n  M1002 set_filament_type:UNKNOWN\n  M400\n  T[initial_no_support_extruder]\n  M400\n  M628 S0\n  M629\n  M400\n  M1002 set_filament_type:{filament_type[initial_no_support_extruder]}\n  M621 S[initial_no_support_extruder]A\n  M104 S{nozzle_temperature_initial_layer[initial_no_support_extruder]}\n  M400\n  M106 P1 S0\n  M400\n  G29.2 S1\n;===== prepare print temperature and material ==========\n\n\n;===== auto extrude cali start =========================\n  M975 S1\n  M1002 judge_flag extrude_cali_flag\n  M622 J0\n    M983.3 F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4} A0.4 ; cali dynamic extrusion compensation\n  M623\n\n  M622 J1\n    M1002 set_filament_type:{filament_type[initial_no_support_extruder]}\n    M1002 gcode_claim_action : 8\n    M109 S{nozzle_temperature[initial_no_support_extruder]}\n    G90\n    M83\n    M983.3 F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4} A0.4 ; cali dynamic extrusion compensation\n    M400\n    M106 P1 S255\n    M400 S5\n    M106 P1 S0\n    G150.3\n  M623\n\n  M622 J2\n    M1002 set_filament_type:{filament_type[initial_no_support_extruder]}\n    M1002 gcode_claim_action : 8\n    M109 S{nozzle_temperature[initial_no_support_extruder]}\n    G90\n    M83\n    M983.3 F{filament_max_volumetric_speed[initial_no_support_extruder]/2.4} A0.4 ; cali dynamic extrusion compensation\n    M400\n    M106 P1 S255\n    M400 S5\n    M106 P1 S0\n    G150.3\n  M623\n;===== auto extrude cali end =========================\n\n  {if hold_chamber_temp_for_flat_print}\n    M1002 gcode_claim_action : 58\n    M104 S{first_layer_temperature[initial_no_support_extruder]}\n    {if bed_temperature_initial_layer_single > 89}\n        M1030 S1800      \n    {else}\n        M1030 S300\n    {endif}\n    M1030 C\n  {endif}\n  \n  {if filament_type[current_extruder] == "TPU" || filament_type[current_extruder] == "PVA"}\n  {else}\n    M83\n    G1 E-3 F1800\n    M400 P500\n  {endif}\n  G150.2\n  G150.1 F8000\n  G150.2\n  G150.1 F8000\n\n  G91\n  G1 Y-16 F12000 ; move away from the trash bin\n  G90\n  M400\n\n  M104 S{nozzle_temperature_initial_layer[initial_no_support_extruder]-80} A\n\n;===== wipe right nozzle start =====\n  M1002 gcode_claim_action : 14\n  G150 T{nozzle_temperature_initial_layer[initial_no_support_extruder]}\n  M400\n  \n{if filament_type[current_extruder] == "PC"}\n  M109 S170 A\n{else}\n  M109 S140 A\n{endif}\n  G91\n  G1 Z5 F1200\n  G90\n  M400\n  G150.1\n;===== wipe left nozzle end =====\n\n\n;===== mech mode sweep start =====\n  M1002 gcode_claim_action : 3\n  G90\n  G1 X128 Y128 F20000\n  G1 Z5 F1200\n  M400 P200\n  M970.3 Q1 A5 K0 O1\n  M970.2 Q1 K1 W74 Z0.01\n  M974 Q1 S2 P0\n  M970.3 Q0 A7 K0 O1\n  M970.2 Q0 K1 W74 Z0.01\n  M974 Q0 S2 P0\n  M975 S1\n  M400\n;===== mech mode sweep end =====\n\n;===== bed leveling ==================================\n  M1002 gcode_claim_action : 54\n  M190 S[bed_temperature_initial_layer_single]; ensure bed temp\n  M109 S140 A\n  M106 S0 ; turn off fan , too noisy\n  M1002 judge_flag g29_before_print_flag\n  M622 J1\n    M1002 gcode_claim_action : 1\n    {if hold_chamber_temp_for_flat_print}\n      G29 H\n    {else}\n      G29 A1 X{first_layer_print_min[0]} Y{first_layer_print_min[1]} I{first_layer_print_size[0]} J{first_layer_print_size[1]}\n    {endif}\n    M400\n    M500 ; save cali data\n  M623\n    \n  M622 J2\n    M1002 gcode_claim_action : 1\n    {if hold_chamber_temp_for_flat_print}\n      G29 H\n    {else}\n      G29 A2 X{first_layer_print_min[0]} Y{first_layer_print_min[1]} I{first_layer_print_size[0]} J{first_layer_print_size[1]}\n    {endif}\n    M400\n    M500 ; save cali data\n  M623\n\n  M622 J0\n    G28\n  M623\n  G29.2 S1\n  G28\n;===== bed leveling end ================================\n\n  M985.1 U0 E2\n  M985.1 U1 E2\n\n  M104 S[nozzle_temperature_initial_layer] A\n  G150.3 ; move to garbage can to wait for temp\n\n;===== wait temperature reaching the reference value =======\n  M190 S[bed_temperature_initial_layer_single] \n\n  ;========turn off light and fans =============\n  M960 S1 P0 ; turn off laser\n  M960 S2 P0 ; turn off laser\n  M106 S0 ; turn off cooling fan\n  \n;===== wait temperature reaching the reference value =======\n\n  M1002 gcode_claim_action : 255\n  M400\n  M975 S1 ; turn on mech mode supression\n\n;============switch again==================\n  M211 X0 Y0 Z0 ;turn off soft endstop\n  G91\n  G1 Z6 F1200\n  G90\n  M1002 set_filament_type:{filament_type[initial_no_support_extruder]}\n  M620 S[initial_no_support_extruder]A\n  M400\n  T[initial_no_support_extruder]\n  M400\n  M628 S0\n  M629\n  M400\n  M621 S[initial_no_support_extruder]A\n;============switch again==================\n\n;===== for Textured PEI Plate , lower the nozzle as the nozzle was touching topmost of the texture when homing ==\n  {if curr_bed_type=="Textured PEI Plate"}\n    G29.1 Z{0.01} ; for Textured PEI Plate\n  {else}\n    G29.1 Z{0.03}\n  {endif}\n\n;===== nozzle load line ===============================\nM1002 gcode_claim_action : 51\n  G29.2 S1 ; ensure z comp turn on\n  G90\n  M83\n  M109 S{nozzle_temperature_initial_layer[initial_no_support_extruder]}\n  G0 X100 Y0 F24000\n  M400\n  ;G130 O0 X100 Y-0.4 Z0.8 F{filament_max_volumetric_speed[initial_no_support_extruder]/2/2.4053} L40 E20 D5\n  G130 O0 X100 Y-0.2 Z0.6 F{filament_max_volumetric_speed[initial_no_support_extruder]/2/2.4053} L40 E12 D4\n  G90\n  M83\n  G1 Z0.5\n  M400\n;===== noozle load line end ===========================\nM1002 gcode_claim_action : 0\n  G29.99\n\n{if (filament_type[initial_no_support_extruder] == "TPU") || \n(filament_type[initial_no_support_extruder] == "PLA") ||  (filament_type[initial_no_support_extruder] == "PETG")}\nM1015.3 S1 H[nozzle_diameter];enable tpu, pla and petg clog detect\n{else}\nM1015.3 S0;disable clog detect\n{endif}\n\n{if (filament_type[initial_no_support_extruder] == "PLA") ||  (filament_type[initial_no_support_extruder] == "PETG")\n ||  (filament_type[initial_no_support_extruder] == "PLA-CF")  ||  (filament_type[initial_no_support_extruder] == "PETG-CF")}\nM1015.4 S1 K1 H[nozzle_diameter] ;enable E air printing detect\n{else}\nM1015.4 S0 K0 H[nozzle_diameter] ;disable E air printing detect\n{endif}\n\nM620.6 I[initial_no_support_extruder] W1 ;enable ams air printing detect\n\nM1010 Q0 B0.023 S0.01\nM1010 Q1 B0.005 S0.01\nM1010.1 S1\n\n
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
; print_settings_id = 0.20mm Standard @BBL P2S
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
; sparse_infill_density = 15%
; sparse_infill_filament = 0
; sparse_infill_line_width = 0.45
; sparse_infill_pattern = grid
; sparse_infill_speed = 270
; spiral_mode = 0
; spiral_mode_max_xy_smoothing = 200%
; spiral_mode_smooth = 0
; standby_temperature_delta = -5
; start_end_points = 30x-3,54x245
; supertack_plate_temp = 40
; supertack_plate_temp_initial_layer = 40
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
; wall_loops = 2
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
M73 P0 R19
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
;===== 2025/11/18 =====
  
  M140 S40 ; heat heatbed first
  M993 A0 B0 C0 ; nozzle cam detection not allowed.
  M400

;=====printer start sound ===================
M17
M400 S1
M1006 S1
M1006 A53 B9 L50 C53 D9 M50 E53 F9 N50 
M1006 A56 B9 L50 C56 D9 M50 E56 F9 N50 
M1006 A61 B9 L50 C61 D9 M50 E61 F9 N50 
M1006 A53 B9 L50 C53 D9 M50 E53 F9 N50 
M1006 A56 B9 L50 C56 D9 M50 E56 F9 N50 
M1006 A61 B18 L50 C61 D18 M50 E61 F18 N50 
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
M106 P3 S127 ; turn on chamber fan for cooling
M1002 gcode_claim_action : 29
M191 S0 ; wait for chamber temp
M106 P2 S102 ; turn on chamber cooling fan
M106 P10 S0 ; turn off left aux fan
M142 P6 R30 S40 U0.3 V0.8 ; set PETG exhaust chamber autocooling


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
  G150.2
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
M73 P7 R18
  G1 Z5 F1200
  G90
  M400
  G150.1
;===== wipe left nozzle end =====


;===== mech mode sweep start =====
  M1002 gcode_claim_action : 3
  G90
  G1 X128 Y128 F20000
  G1 Z5 F1200
  M400 P200
  M970.3 Q1 A5 K0 O1
  M970.2 Q1 K1 W74 Z0.01
  M974 Q1 S2 P0
  M970.3 Q0 A7 K0 O1
  M970.2 Q0 K1 W74 Z0.01
  M974 Q0 S2 P0
  M975 S1
  M400
;===== mech mode sweep end =====

;===== bed leveling ==================================
  M1002 gcode_claim_action : 54
  M190 S40; ensure bed temp
  M109 S140 A
  M106 S0 ; turn off fan , too noisy
  M1002 judge_flag g29_before_print_flag
  M622 J1
    M1002 gcode_claim_action : 1
    
      G29 A1 X82.417 Y108.259 I91.1655 J39.4811
    
    M400
    M500 ; save cali data
  M623
    
  M622 J2
    M1002 gcode_claim_action : 1
    
      G29 A2 X82.417 Y108.259 I91.1655 J39.4811
    
    M400
    M500 ; save cali data
  M623

  M622 J0
    G28
  M623
  G29.2 S1
  G28
;===== bed leveling end ================================

  M985.1 U0 E2
  M985.1 U1 E2

  M104 S220 A
  G150.3 ; move to garbage can to wait for temp

;===== wait temperature reaching the reference value =======
  M190 S40 

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
  
    G29.1 Z0.03
  

;===== nozzle load line ===============================
M1002 gcode_claim_action : 51
  G29.2 S1 ; ensure z comp turn on
  G90
  M83
  M109 S220
  G0 X100 Y0 F24000
  M400
  ;G130 O0 X100 Y-0.4 Z0.8 F4.36536 L40 E20 D5
  G130 O0 X100 Y-0.2 Z0.6 F4.36536 L40 E12 D4
  G90
  M83
  G1 Z0.5
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
M73 P39 R12
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
G1 X125.459 Y121.392
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.5
G1 F3000
M204 S500
G1 X125.46 Y121.365 E.00099
G3 X127.806 Y119.107 I2.542 J.293 E.13147
G1 X128.198 Y119.107 E.01459
G3 X125.445 Y121.757 I-.196 J2.551 E.43813
G1 X125.456 Y121.452 E.01137
M204 S6000
G1 X125.924 Y121.374 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X125.977 Y121.102 E.01032
G3 X127.842 Y119.564 I2.026 J.556 E.09594
G1 X128.163 Y119.564 E.01198
G3 X125.914 Y121.433 I-.161 J2.094 E.37107
; WIPE_START
G1 X125.977 Y121.102 E-.12801
G1 X126.083 Y120.805 E-.12006
G1 X126.238 Y120.517 E-.12417
G1 X126.434 Y120.261 E-.12245
G1 X126.665 Y120.038 E-.12226
G1 X126.929 Y119.853 E-.12225
G1 X126.978 Y119.829 E-.0208
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X119.931 Y122.761 Z.6 F36000
G1 X103.188 Y129.729 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X103.503 Y129.829 E.01231
G3 X102.351 Y129.651 I-.957 J2.373 E.555
G1 X102.742 Y129.651 E.01459
G3 X103.129 Y129.711 I-.196 J2.551 E.01461
G1 X103.131 Y129.711 E.00005
M204 S6000
G1 X102.448 Y130.108 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X102.707 Y130.108 E.00964
G3 X102.386 Y130.108 I-.161 J2.094 E.47957
G1 X102.388 Y130.108 E.0001
; WIPE_START
G1 X102.707 Y130.108 E-.12112
G1 X103.025 Y130.157 E-.12222
G1 X103.332 Y130.254 E-.12229
G1 X103.62 Y130.397 E-.1222
G1 X103.883 Y130.582 E-.12232
G1 X104.115 Y130.805 E-.12216
G1 X104.159 Y130.863 E-.0277
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X111.791 Y130.965 Z.6 F36000
G1 X155.931 Y131.551 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X156 Y131.91 E.0136
G3 X153.262 Y129.651 I-2.542 J.293 E.45272
G1 X153.654 Y129.651 E.01459
M73 P39 R11
G3 X155.917 Y131.493 I-.196 J2.551 E.11563
M204 S6000
G1 X155.457 Y131.57 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X155.484 Y131.647 E.00304
G3 X153.297 Y130.108 I-2.026 J.556 E.38363
G1 X153.619 Y130.108 E.01198
G3 X155.375 Y131.344 I-.161 J2.094 E.08395
G1 X155.436 Y131.513 E.0067
; WIPE_START
G1 X155.484 Y131.647 E-.05386
G1 X155.545 Y131.962 E-.12219
M73 P40 R11
G1 X155.558 Y132.284 E-.12226
G1 X155.522 Y132.598 E-.12008
G1 X155.436 Y132.913 E-.12416
G1 X155.304 Y133.207 E-.12241
G1 X155.168 Y133.417 E-.09504
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X155.496 Y141.042 Z.6 F36000
G1 X155.735 Y146.591 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G2 X100.27 Y146.591 I-27.732 J11.078 E2.64896
G1 X83.328 Y139.104 E.6899
G3 X84.018 Y137.442 I2.738 J.162 E.06832
G3 X85.545 Y135.796 I21.284 J18.213 E.08364
G2 X89.74 Y129.078 I-12.71 J-12.607 E.29746
G3 X90.637 Y126.791 I23.286 J7.81 E.09152
G3 X91.581 Y125.757 I2.196 J1.057 E.0529
G3 X93.476 Y124.634 I15.836 J24.547 E.08208
G2 X98.25 Y120.871 I-8.69 J-15.934 E.22748
G2 X100.524 Y117.965 I-37.44 J-31.649 E.13747
G3 X101.524 Y116.977 I3.355 J2.395 E.05261
G3 X103.104 Y116.445 I2.893 J5.974 E.06225
G2 X106.661 Y115.498 I-6.599 J-31.958 E.13717
G2 X111.686 Y112.739 I-6.057 J-16.985 E.21443
G3 X113.639 Y111.358 I14.664 J18.664 E.08913
G3 X115.145 Y111.032 I1.325 J2.485 E.05816
G3 X117.843 Y111.163 I-7.95 J191.467 E.10061
G2 X124.836 Y110.073 I.86 J-17.444 E.26544
G3 X127.412 Y109.191 I11.095 J28.211 E.10146
G3 X128.163 Y109.126 I.574 J2.254 E.02818
G3 X129.582 Y109.5 I-.806 J5.932 E.05479
G2 X133.33 Y110.725 I12.685 J-32.455 E.14695
G2 X138.742 Y111.135 I4.044 J-17.449 E.20296
G3 X141.221 Y111.033 I2.298 J25.694 E.09242
G3 X142.547 Y111.473 I-.072 J2.436 E.05279
G3 X144.322 Y112.743 I-15.254 J23.206 E.08132
G2 X149.344 Y115.498 I11.231 J-14.517 E.21421
G2 X152.905 Y116.441 I9.914 J-30.253 E.13728
G3 X154.439 Y116.95 I-1.234 J6.284 E.06036
G3 X155.475 Y117.969 I-2.489 J3.568 E.05438
G2 X157.755 Y120.871 I41.982 J-30.627 E.1375
G2 X162.29 Y124.495 I12.904 J-11.501 E.21724
G3 X164.606 Y125.879 I-13.517 J25.249 E.10052
G3 X165.513 Y127.116 I-1.631 J2.146 E.05794
G3 X166.703 Y130.19 I-750.953 J292.613 E.12277
G2 X170.464 Y135.798 I16.291 J-6.859 E.25307
G3 X172.129 Y137.61 I-16.946 J17.243 E.0917
G3 X172.622 Y138.786 I-1.864 J1.472 E.04808
G1 X172.67 Y139.106 E.01204
G1 X155.79 Y146.566 E.6874
M204 S6000
G1 X155.476 Y147.205 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G2 X100.528 Y147.205 I-27.474 J10.448 E2.64371
G1 X82.84 Y139.389 E.72028
G3 X83.164 Y137.902 I4.221 J.142 E.05699
G3 X84.229 Y136.513 I5.634 J3.216 E.06539
G2 X86.631 Y133.86 I-24.607 J-24.7 E.13334
G2 X89.312 Y128.917 I-13.688 J-10.623 E.21038
G3 X90.231 Y126.581 I23.406 J7.854 E.09355
G3 X91.321 Y125.382 I2.594 J1.263 E.06117
G3 X93.247 Y124.238 I16.039 J24.826 E.08347
G2 X97.908 Y120.567 I-8.465 J-15.543 E.22203
G2 X100.166 Y117.681 I-37.349 J-31.547 E.1365
G3 X101.289 Y116.585 I3.685 J2.651 E.05876
G3 X102.996 Y116 I3.098 J6.265 E.06737
G2 X106.511 Y115.066 I-6.498 J-31.534 E.13553
G2 X111.414 Y112.371 I-5.909 J-16.559 E.20928
G3 X113.413 Y110.96 I14.813 J18.864 E.09119
G3 X115.145 Y110.575 I1.547 J2.873 E.06691
G3 X117.86 Y110.707 I-7.585 J184.828 E.10125
G2 X124.683 Y109.642 I.844 J-16.985 E.25902
G3 X127.307 Y108.746 I11.139 J28.334 E.1033
G3 X128.201 Y108.67 I.68 J2.706 E.03355
G3 X129.732 Y109.068 I-.829 J6.331 E.05908
G2 X133.436 Y110.281 I12.545 J-32.058 E.14526
G2 X138.718 Y110.679 I3.937 J-17 E.19804
G3 X141.249 Y110.577 I2.306 J25.813 E.0944
G3 X142.785 Y111.083 I-.099 J2.883 E.06107
G3 X144.593 Y112.375 I-15.441 J23.524 E.08277
G2 X149.494 Y115.066 I10.964 J-14.156 E.20909
G2 X153.012 Y115.996 I9.771 J-29.838 E.13561
G3 X154.673 Y116.557 I-1.309 J6.62 E.0655
G3 X155.832 Y117.683 I-2.692 J3.932 E.06049
G2 X158.097 Y120.568 I41.92 J-30.578 E.13661
G2 X162.52 Y124.099 I12.563 J-11.198 E.21183
G3 X164.878 Y125.511 I-13.59 J25.376 E.10242
G3 X165.93 Y126.931 I-1.901 J2.509 E.06669
G3 X167.125 Y130.013 I-632.358 J246.761 E.12313
G2 X170.796 Y135.484 I15.873 J-6.684 E.24691
G3 X172.494 Y137.336 I-17.15 J17.438 E.09364
G3 X173.114 Y138.982 I-2.47 J1.868 E.06641
G3 X173.159 Y139.39 I-7.692 J1.056 E.01528
G1 X155.531 Y147.18 E.71783
; WIPE_START
G1 X155.262 Y146.646 E-.2276
G1 X154.861 Y145.701 E-.38989
G1 X154.702 Y145.361 E-.14251
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X158.523 Y138.754 Z.6 F36000
G1 X165.282 Y127.063 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Bottom surface
; LINE_WIDTH: 0.50154
G1 F6300
M204 S500
G1 X164.577 Y126.359 E.03724
G2 X163.978 Y125.92 I-2.562 J2.871 E.02779
G1 X162.811 Y125.241 E.05047
G1 X165.373 Y127.803 E.13539
G3 X165.766 Y128.844 I-17.988 J7.38 E.0416
G1 X161.21 Y124.289 E.24075
G3 X157.464 Y121.129 I9.394 J-14.939 E.18375
G1 X156.624 Y120.121 E.04902
G2 X155.298 Y118.377 I-35.975 J25.966 E.08189
G1 X154.184 Y117.262 E.0589
G1 X154.054 Y117.192 E.00553
G2 X153.195 Y116.922 I-1.807 J4.251 E.03369
G1 X166.164 Y129.891 E.68543
G1 X166.651 Y131.027 E.04617
G1 X152.339 Y116.715 E.75641
G1 X151.483 Y116.507 E.03292
G1 X167.352 Y132.376 E.8387
G1 X167.459 Y132.566 E.00815
G2 X168.723 Y134.396 I15.232 J-9.171 E.08316
G1 X150.614 Y116.287 E.9571
G1 X149.7 Y116.021 E.03557
G1 X172.144 Y138.466 E1.18623
M73 P41 R11
G3 X172.237 Y138.873 I-1.745 J.61 E.01563
G1 X172.005 Y138.975 E.00946
G1 X148.703 Y115.673 E1.23153
G1 X147.58 Y115.198 E.0456
G1 X171.555 Y139.174 E1.26715
G1 X171.105 Y139.373 E.01838
G1 X146.192 Y114.459 E1.31673
G3 X144.27 Y113.186 I14.706 J-24.286 E.08615
G1 X170.656 Y139.571 E1.3945
G1 X170.206 Y139.77 E.01838
G1 X142.105 Y111.669 E1.48517
G1 X141.696 Y111.496 E.0166
G2 X141.216 Y111.429 I-.471 J1.635 E.01816
G1 X169.756 Y139.969 E1.50836
G1 X169.306 Y140.168 E.01838
G1 X140.562 Y111.423 E1.51919
G2 X139.94 Y111.45 I.222 J12.518 E.02327
G1 X168.856 Y140.367 E1.52829
G1 X168.407 Y140.565 E.01838
G1 X139.326 Y111.485 E1.53694
G1 X138.713 Y111.52 E.02296
G1 X167.957 Y140.764 E1.54558
G1 X167.507 Y140.963 E.01838
G1 X138.096 Y111.552 E1.55441
G1 X137.455 Y111.559 E.02398
G1 X167.057 Y141.162 E1.56455
G1 X166.608 Y141.361 E.01838
G1 X136.809 Y111.563 E1.57487
G1 X136.127 Y111.529 E.02554
G1 X153.893 Y129.295 E.93899
G2 X153.215 Y129.265 I-.513 J3.955 E.0254
G1 X135.419 Y111.469 E.94057
G1 X134.686 Y111.385 E.02756
G1 X152.67 Y129.369 E.95046
G2 X152.198 Y129.546 I.349 J1.644 E.01889
G1 X133.892 Y111.239 E.96753
G3 X133.053 Y111.049 I1.073 J-6.685 E.03215
G1 X151.787 Y129.783 E.99012
G2 X151.43 Y130.074 I.763 J1.303 E.0173
G1 X132.155 Y110.799 E1.01871
G3 X131.203 Y110.496 I3.736 J-13.372 E.03734
G1 X151.123 Y130.416 E1.05281
G2 X150.869 Y130.81 I1.125 J1.004 E.01761
G1 X130.2 Y110.141 E1.0924
G1 X129.196 Y109.787 E.03977
G1 X150.672 Y131.262 E1.13501
G2 X150.544 Y131.783 I1.624 J.673 E.02013
M73 P42 R11
G1 X128.301 Y109.54 E1.17561
G2 X127.658 Y109.545 I-.302 J2.036 E.02412
G1 X150.756 Y132.643 E1.22076
; WIPE_START
G1 X149.342 Y131.229 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X156.11 Y131.511 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X166.158 Y141.559 E.53105
G1 X165.708 Y141.758 E.01838
G1 X156.391 Y132.441 E.49243
G3 X156.291 Y132.99 I-1.86 J-.054 E.02093
G1 X165.258 Y141.957 E.47392
G1 X164.808 Y142.156 E.01838
G1 X156.116 Y133.463 E.45941
G3 X155.879 Y133.875 I-1.45 J-.561 E.01782
G1 X164.359 Y142.355 E.44816
G1 X163.909 Y142.553 E.01838
G1 X155.588 Y134.233 E.43975
G3 X155.247 Y134.54 I-1.163 J-.951 E.01723
G1 X163.459 Y142.752 E.43403
G1 X163.009 Y142.951 E.01838
G1 X154.853 Y134.795 E.43106
G1 X154.767 Y134.846 E.00376
G1 X154.403 Y134.993 E.01467
G1 X162.559 Y143.15 E.43109
G1 X162.11 Y143.348 E.01838
G1 X153.881 Y135.12 E.43489
G3 X153.249 Y135.136 I-.369 J-2.037 E.02373
G1 X161.66 Y143.547 E.44453
G1 X161.21 Y143.746 E.01838
G1 X152.419 Y134.955 E.46463
G3 X150.697 Y133.234 I.997 J-2.718 E.09389
G1 X127.136 Y109.672 E1.24529
G2 X126.645 Y109.83 I1.576 J5.726 E.01926
G1 X160.76 Y143.945 E1.80304
G1 X160.31 Y144.144 E.01838
G1 X126.169 Y110.002 E1.80442
G1 X125.693 Y110.175 E.01892
G1 X159.861 Y144.342 E1.8058
G1 X159.411 Y144.541 E.01838
G1 X125.217 Y110.348 E1.80719
G3 X124.736 Y110.515 I-2.98 J-7.82 E.01905
G1 X158.961 Y144.74 E1.80887
G1 X158.511 Y144.939 E.01838
G1 X124.247 Y110.675 E1.8109
G3 X123.758 Y110.835 I-2.055 J-5.468 E.01923
G1 X158.061 Y145.138 E1.81297
G1 X157.612 Y145.336 E.01838
G1 X153.181 Y140.906 E.23416
G3 X154.237 Y142.61 I-32.35 J21.22 E.07494
G1 X157.162 Y145.535 E.15458
G1 X156.712 Y145.734 E.01838
G1 X154.988 Y144.01 E.09111
G3 X155.587 Y145.257 I-17.575 J9.2 E.0517
M73 P43 R11
G1 X156.418 Y146.089 E.04395
; WIPE_START
G1 X155.587 Y145.257 E-.44692
G1 X155.23 Y144.514 E-.31309
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X150.25 Y138.731 Z.6 F36000
G1 X145.566 Y133.291 Z.6
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X123.252 Y110.977 E1.17934
G3 X122.734 Y111.107 I-1.966 J-6.734 E.01998
G1 X143.051 Y131.424 E1.07382
G2 X141.651 Y130.673 I-11.458 J19.669 E.05939
G1 X122.201 Y111.223 E1.02797
G1 X121.653 Y111.324 E.02082
G1 X140.404 Y130.075 E.99104
G2 X139.274 Y129.593 I-25.324 J57.864 E.04591
G1 X130.915 Y121.234 E.44178
G1 X130.949 Y121.765 E.01987
G1 X130.934 Y121.901 E.00513
G1 X138.229 Y129.197 E.38557
G2 X137.246 Y128.862 I-5.28 J13.904 E.03882
G1 X130.834 Y122.451 E.33886
G3 X130.658 Y122.923 I-1.619 J-.335 E.01892
G1 X136.313 Y128.578 E.29887
G1 X135.427 Y128.341 E.03428
G1 X130.421 Y123.334 E.26459
G3 X130.13 Y123.692 I-1.304 J-.765 E.0173
G1 X134.579 Y128.141 E.23514
G2 X133.761 Y127.971 I-2.839 J11.644 E.03123
G1 X129.788 Y123.998 E.20998
G3 X129.394 Y124.253 I-1.022 J-1.149 E.0176
G1 X132.969 Y127.828 E.18895
G2 X132.198 Y127.706 I-2.095 J10.746 E.02916
G1 X128.943 Y124.451 E.17206
G1 X128.42 Y124.576 E.0201
G1 X131.459 Y127.615 E.16062
G2 X130.737 Y127.542 I-1.415 J10.312 E.02713
G1 X127.559 Y124.364 E.16793
; WIPE_START
G1 X128.973 Y125.778 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X128.689 Y119.008 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X121.092 Y111.411 E.4015
G1 X120.51 Y111.478 E.02189
G1 X127.754 Y118.722 E.38287
G1 X127.33 Y118.787 E.01602
G1 X127.209 Y118.826 E.00475
G1 X119.911 Y111.527 E.38575
G1 X119.293 Y111.558 E.02312
G1 X126.739 Y119.004 E.39352
G2 X126.328 Y119.242 I.566 J1.449 E.0178
G1 X118.647 Y111.56 E.40596
G1 X117.992 Y111.554 E.0245
G1 X125.971 Y119.533 E.42172
G2 X125.665 Y119.875 I.956 J1.164 E.01723
G1 X117.313 Y111.523 E.44142
G1 X116.626 Y111.485 E.0257
G1 X125.411 Y120.27 E.4643
G2 X125.214 Y120.722 I1.393 J.874 E.01849
G1 X115.939 Y111.447 E.4902
G2 X115.268 Y111.425 I-.757 J12.552 E.0251
G1 X125.087 Y121.244 E.51896
G1 X125.055 Y121.772 E.01977
G1 X125.067 Y121.872 E.00375
G1 X114.64 Y111.445 E.55109
G2 X114.117 Y111.57 I.229 J2.107 E.02016
G1 X125.246 Y122.7 E.58822
G2 X126.953 Y124.407 I2.709 J-1.002 E.09306
G1 X130.029 Y127.483 E.16257
G1 X129.345 Y127.447 E.02561
G1 X113.686 Y111.788 E.82757
G2 X113.293 Y112.044 I1.298 J2.424 E.01754
G1 X128.674 Y127.425 E.81291
G1 X128.014 Y127.414 E.02467
G1 X112.919 Y112.318 E.79782
G1 X112.544 Y112.592 E.01734
G1 X127.376 Y127.424 E.78391
G2 X126.746 Y127.442 I-.057 J9.045 E.02358
G1 X112.169 Y112.866 E.77038
G1 X111.795 Y113.14 E.01734
G1 X126.13 Y127.475 E.75761
G2 X125.525 Y127.519 I.337 J8.687 E.02264
G1 X111.419 Y113.413 E.74554
G1 X111.033 Y113.676 E.01745
M73 P44 R11
G1 X124.929 Y127.571 E.73442
G2 X124.349 Y127.639 I.686 J8.354 E.02185
G1 X110.647 Y113.938 E.72414
G3 X110.255 Y114.194 I-2.419 J-3.281 E.01753
G1 X123.772 Y127.711 E.71439
G1 X123.212 Y127.8 E.02118
G1 X109.849 Y114.437 E.70624
G3 X109.442 Y114.678 I-2.121 J-3.119 E.01771
G1 X122.655 Y127.891 E.69834
G1 X122.112 Y127.997 E.02067
G1 X109.014 Y114.899 E.69223
G1 X108.587 Y115.12 E.01799
G1 X121.573 Y128.107 E.68635
G1 X121.046 Y128.228 E.02021
G1 X108.14 Y115.322 E.68212
G1 X107.687 Y115.518 E.01842
G1 X120.524 Y128.355 E.67843
G1 X120.012 Y128.492 E.01979
G1 X107.222 Y115.702 E.67598
G1 X106.745 Y115.873 E.01895
G1 X119.506 Y128.634 E.67442
G1 X119.009 Y128.786 E.01941
G1 X106.258 Y116.035 E.67391
G1 X105.756 Y116.181 E.01956
G1 X118.516 Y128.942 E.67443
G1 X118.034 Y129.108 E.01907
G1 X105.253 Y116.327 E.67548
G3 X104.732 Y116.455 I-1.581 J-5.315 E.02005
G1 X117.554 Y129.277 E.67767
G1 X117.086 Y129.457 E.01876
G1 X104.209 Y116.58 E.68057
G1 X103.685 Y116.705 E.02011
G1 X116.619 Y129.639 E.68356
G1 X116.164 Y129.832 E.01849
G1 X103.163 Y116.831 E.68712
G1 X102.649 Y116.966 E.01984
G1 X115.708 Y130.025 E.69018
G2 X115.266 Y130.231 I2.716 J6.411 E.01825
G1 X102.162 Y117.127 E.69255
G2 X101.712 Y117.326 I.398 J1.509 E.01846
G1 X114.823 Y130.437 E.69295
G2 X114.391 Y130.654 I2.89 J6.301 E.01806
G1 X101.349 Y117.612 E.68928
G1 X101.039 Y117.95 E.01716
G1 X113.962 Y130.873 E.68298
G2 X113.54 Y131.1 I3.03 J6.142 E.0179
G1 X100.757 Y118.317 E.6756
G1 X100.476 Y118.684 E.01729
G1 X113.122 Y131.331 E.66838
G2 X112.71 Y131.567 I3.182 J6.026 E.01776
G1 X100.195 Y119.052 E.66143
G1 X99.915 Y119.42 E.01729
G1 X112.305 Y131.811 E.65485
G2 X111.902 Y132.056 I3.318 J5.897 E.01764
G1 X99.634 Y119.788 E.64839
G3 X99.352 Y120.155 I-4.428 J-3.117 E.01729
G1 X111.509 Y132.312 E.64252
G1 X111.116 Y132.567 E.01752
M73 P44 R10
G1 X99.057 Y120.508 E.63731
G1 X98.763 Y120.862 E.01721
M73 P45 R10
G1 X110.733 Y132.833 E.63268
G1 X110.352 Y133.1 E.0174
G1 X98.463 Y121.211 E.62836
G1 X98.148 Y121.545 E.01715
G1 X109.978 Y133.375 E.62523
G1 X109.608 Y133.654 E.01731
G1 X97.834 Y121.879 E.62232
G3 X97.5 Y122.194 I-2.606 J-2.424 E.01716
G1 X109.243 Y133.937 E.62063
G1 X108.884 Y134.227 E.01723
G1 X97.164 Y122.507 E.61942
G3 X96.819 Y122.81 I-2.408 J-2.403 E.01719
G1 X103.397 Y129.388 E.34766
G3 X105.368 Y131.359 I-.86 J2.831 E.10848
G1 X108.527 Y134.519 E.16698
G1 X108.18 Y134.82 E.01718
G1 X105.486 Y132.126 E.14238
G3 X105.446 Y132.734 I-2.028 J.169 E.02285
G1 X107.833 Y135.122 E.1262
G2 X107.495 Y135.433 I4.272 J4.985 E.01716
G1 X105.304 Y133.241 E.11583
G1 X105.094 Y133.68 E.01817
G1 X107.16 Y135.746 E.10919
G2 X106.83 Y136.064 I4.393 J4.879 E.01715
G1 X104.828 Y134.063 E.10578
G3 X104.511 Y134.394 I-1.231 J-.859 E.01721
G1 X106.506 Y136.388 E.10539
G2 X106.183 Y136.715 I4.521 J4.781 E.01714
G1 X104.143 Y134.675 E.10782
G3 X103.72 Y134.901 I-.941 J-1.255 E.01798
G1 X105.871 Y137.051 E.11363
G1 X105.558 Y137.386 E.01715
G1 X103.233 Y135.062 E.12283
G3 X102.666 Y135.143 I-.542 J-1.761 E.02151
G1 X105.255 Y137.732 E.13682
G1 X104.953 Y138.079 E.01718
G1 X101.675 Y134.801 E.17326
; WIPE_START
G1 X103.089 Y136.215 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X102.842 Y129.482 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X96.461 Y123.101 E.33723
G3 X96.102 Y123.391 I-2.477 J-2.701 E.01725
G1 X102.02 Y129.309 E.3128
G2 X101.511 Y129.448 I.185 J1.687 E.01983
G1 X95.724 Y123.661 E.30585
G1 X95.345 Y123.931 E.01738
G1 X101.068 Y129.654 E.30247
G1 X100.684 Y129.918 E.01743
G1 X94.952 Y124.186 E.30296
G1 X94.554 Y124.437 E.01758
G1 X100.352 Y130.234 E.30643
G1 X100.07 Y130.601 E.01729
G1 X94.155 Y124.687 E.31259
G1 X93.746 Y124.926 E.01772
G1 X99.845 Y131.025 E.32236
G1 X99.685 Y131.514 E.01921
G1 X93.336 Y125.165 E.33554
G1 X92.926 Y125.404 E.01772
G1 X99.608 Y132.085 E.35315
G2 X99.656 Y132.782 I3.95 J.08 E.02611
G1 X92.517 Y125.643 E.37731
G1 X92.107 Y125.881 E.01772
G1 X104.658 Y138.433 E.66336
G1 X104.368 Y138.791 E.01723
G1 X91.72 Y126.143 E.66846
G2 X91.361 Y126.432 I1.24 J1.91 E.01727
G1 X104.082 Y139.153 E.67231
G1 X103.803 Y139.523 E.01731
G1 X91.078 Y126.798 E.67253
G1 X90.861 Y127.23 E.01806
G1 X103.525 Y139.894 E.66929
G1 X103.258 Y140.275 E.0174
G1 X90.672 Y127.689 E.66518
G2 X90.492 Y128.157 I8.658 J3.601 E.01876
G1 X102.99 Y140.656 E.66058
G2 X102.732 Y141.047 I5.398 J3.849 E.0175
G1 X90.316 Y128.63 E.65623
G1 X90.14 Y129.103 E.01885
G1 X102.477 Y141.44 E.65202
G2 X102.228 Y141.839 I5.58 J3.76 E.0176
G1 X89.964 Y129.576 E.64815
G3 X89.779 Y130.04 I-6.352 J-2.258 E.01867
G1 X101.984 Y142.244 E.64504
M73 P46 R10
G2 X101.744 Y142.653 I5.748 J3.652 E.01771
G1 X89.589 Y130.498 E.6424
G3 X89.387 Y130.944 I-4.708 J-1.865 E.01832
G1 X101.513 Y143.07 E.64087
G2 X101.282 Y143.488 I5.896 J3.523 E.01785
G1 X89.179 Y131.385 E.63969
G3 X88.959 Y131.814 I-3.622 J-1.583 E.01802
G1 X101.063 Y143.918 E.63972
G1 X100.844 Y144.348 E.01802
G1 X88.729 Y132.232 E.64031
G3 X88.494 Y132.646 I-3.188 J-1.537 E.01779
G1 X100.637 Y144.788 E.64174
G1 X100.43 Y145.231 E.01824
G1 X88.241 Y133.041 E.64422
G1 X87.988 Y133.437 E.01755
G1 X100.233 Y145.682 E.6472
G1 X100.066 Y146.076 E.01599
G1 X99.909 Y146.007 E.00642
G1 X87.719 Y133.817 E.64427
G3 X87.444 Y134.19 I-4.71 J-3.186 E.01734
G1 X98.747 Y145.493 E.5974
G1 X97.585 Y144.98 E.04748
G1 X87.158 Y134.553 E.55107
G3 X86.861 Y134.905 I-3.703 J-2.826 E.01721
G1 X96.423 Y144.466 E.50535
G1 X95.261 Y143.953 E.04748
G1 X86.56 Y135.252 E.45987
G1 X86.258 Y135.598 E.01718
G1 X94.099 Y143.439 E.41439
G1 X92.937 Y142.926 E.04748
G1 X85.945 Y135.934 E.3695
G1 X85.631 Y136.269 E.01715
G1 X91.774 Y142.412 E.32469
G1 X90.612 Y141.899 E.04748
G1 X85.317 Y136.603 E.27987
G1 X85.003 Y136.938 E.01715
G1 X89.45 Y141.385 E.23505
G1 X88.288 Y140.872 E.04748
G1 X84.689 Y137.272 E.19023
G2 X84.384 Y137.616 I2.282 J2.336 E.01718
G1 X87.126 Y140.358 E.14494
G1 X85.964 Y139.845 E.04748
G1 X84.103 Y137.984 E.09836
G2 X83.872 Y138.401 I1.715 J1.219 E.01788
G1 X85.205 Y139.734 E.07043
; CHANGE_LAYER
; Z_HEIGHT: 0.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F6300
G1 X83.872 Y138.401 E-.71614
G1 X83.92 Y138.297 E-.04386
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
G1 X125.718 Y121.371
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X125.781 Y121.049 E.0109
G3 X127.823 Y119.362 I2.22 J.608 E.09362
G1 X128.179 Y119.362 E.01178
G3 X125.71 Y121.431 I-.178 J2.295 E.36142
G1 X126.11 Y121.413 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.161 Y121.153 E.00813
G3 X127.855 Y119.754 I1.841 J.504 E.07194
G1 X128.149 Y119.754 E.00901
G3 X126.102 Y121.472 I-.147 J1.903 E.27755
; WIPE_START
M204 S10000
G1 X126.161 Y121.153 E-.12331
G1 X126.259 Y120.878 E-.11114
G1 X126.399 Y120.621 E-.11115
G1 X126.566 Y120.401 E-.10488
G1 X126.786 Y120.186 E-.11703
G1 X127.026 Y120.017 E-.1115
G1 X127.217 Y119.922 E-.08099
; WIPE_END
G1 E-.04 F1800
G1 X120.125 Y122.743 Z.8 F36000
G1 X101.793 Y130.032 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.004 Y129.964 E.00734
G3 X102.368 Y129.906 I.541 J2.237 E.01223
G1 X102.723 Y129.906 E.01178
G3 X101.685 Y130.066 I-.178 J2.294 E.44452
G1 X101.736 Y130.05 E.00177
G1 X102.444 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00764
G3 X102.384 Y130.3 I-.147 J1.903 E.35904
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.11725
G1 X102.982 Y130.343 E-.11116
G1 X103.261 Y130.431 E-.11119
G1 X103.523 Y130.561 E-.11113
G1 X103.762 Y130.729 E-.11117
G1 X103.973 Y130.932 E-.11115
G1 X104.112 Y131.114 E-.08695
; WIPE_END
G1 E-.04 F1800
G1 X111.744 Y131.188 Z.8 F36000
G1 X155.684 Y131.616 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.745 Y131.939 E.0109
G3 X153.282 Y129.906 I-2.287 J.262 E.36263
G1 X153.634 Y129.906 E.0117
G3 X155.668 Y131.559 I-.176 J2.295 E.09248
G1 X155.28 Y131.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.299 Y131.697 E.00188
G3 X153.312 Y130.298 I-1.841 J.504 E.28753
G1 X153.604 Y130.298 E.00899
G3 X155.2 Y131.422 I-.146 J1.903 E.06296
G1 X155.259 Y131.583 E.00525
; WIPE_START
M204 S10000
G1 X155.299 Y131.697 E-.0461
G1 X155.356 Y131.984 E-.11112
G1 X155.367 Y132.276 E-.11112
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11115
G1 X155.137 Y133.116 E-.11113
G1 X154.978 Y133.362 E-.11117
G1 X154.895 Y133.454 E-.04703
; WIPE_END
G1 E-.04 F1800
G1 X155.287 Y141.076 Z.8 F36000
G1 X155.589 Y146.934 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.718 E2.35658
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.865 I3.579 J.167 E.04816
G3 X84.377 Y136.65 I5.976 J3.761 E.0516
G2 X86.79 Y133.986 I-24.739 J-24.825 E.1193
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18945
G3 X90.41 Y126.674 I23.305 J7.816 E.0825
G3 X91.436 Y125.548 I2.418 J1.171 E.05123
G3 X93.348 Y124.413 I15.943 J24.693 E.07379
G2 X98.06 Y120.701 I-8.564 J-15.716 E.19992
G2 X100.325 Y117.806 I-37.432 J-31.624 E.12194
G3 X101.394 Y116.758 I3.536 J2.536 E.04993
G3 X103.037 Y116.198 I2.998 J6.115 E.05773
G2 X106.576 Y115.257 I-6.554 J-31.783 E.12156
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18843
G3 X113.513 Y111.136 I14.718 J18.735 E.08042
G3 X115.144 Y110.777 I1.448 J2.699 E.05611
G3 X117.853 Y110.909 I-7.763 J188.159 E.08996
G2 X124.754 Y109.831 I.851 J-17.189 E.23329
G3 X127.354 Y108.943 I11.102 J28.232 E.09118
G3 X128.185 Y108.872 I.633 J2.505 E.02779
G3 X129.665 Y109.259 I-.819 J6.152 E.0509
G2 X133.389 Y110.477 I12.608 J-32.238 E.13004
G2 X138.729 Y110.881 I3.985 J-17.199 E.17831
G3 X141.236 Y110.779 I2.303 J25.773 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.376 J23.407 E.07317
G2 X149.428 Y115.257 I11.081 J-14.314 E.18822
G2 X152.965 Y116.193 I9.837 J-30.034 E.12145
G3 X154.57 Y116.731 I-1.274 J6.461 E.05628
G3 X155.675 Y117.81 I-2.603 J3.772 E.05148
G2 X157.946 Y120.702 I41.954 J-30.605 E.122
G2 X162.421 Y124.276 I12.716 J-11.334 E.1909
G3 X164.758 Y125.674 I-13.616 J25.414 E.09035
G3 X165.745 Y127.012 I-1.782 J2.348 E.05594
G3 X166.938 Y130.091 I-670.061 J261.34 E.10953
G2 X170.649 Y135.623 I16.058 J-6.761 E.22235
G3 X172.333 Y137.457 I-17.04 J17.333 E.08261
G3 X172.913 Y139.008 I-2.311 J1.749 E.05572
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.195 E2.17924
G1 X82.639 Y139.508 E.60452
G3 X82.93 Y137.962 I5.489 J.232 E.0485
G3 X83.717 Y136.795 I3.809 J1.721 E.04346
G2 X85.862 Y134.49 I-446.161 J-417.235 E.09674
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20158
G3 X90.062 Y126.493 I23.441 J7.865 E.07787
G3 X91.212 Y125.225 I2.76 J1.348 E.05332
G3 X93.152 Y124.073 I16.131 J24.955 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.381 E.18129
G2 X100.017 Y117.563 I-37.322 J-31.513 E.11228
G3 X101.193 Y116.421 I3.823 J2.758 E.05062
G3 X102.944 Y115.818 I3.177 J6.376 E.05708
G2 X106.448 Y114.887 I-6.47 J-31.43 E.11146
G2 X111.301 Y112.218 I-5.848 J-16.382 E.1709
G3 X113.32 Y110.795 I14.847 J18.908 E.07594
G3 X115.144 Y110.385 I1.638 J3.032 E.05818
G3 X117.867 Y110.517 I-7.447 J182.365 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21158
G3 X127.013 Y108.625 I13.213 J33.909 E.07784
G3 X128.217 Y108.481 I.99 J3.173 E.03746
G3 X129.794 Y108.888 I-.84 J6.501 E.05017
G2 X133.481 Y110.096 I12.484 J-31.887 E.11926
G2 X138.707 Y110.489 I3.893 J-16.813 E.16168
G3 X141.261 Y110.387 I2.31 J25.879 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05323
G3 X144.706 Y112.222 I-15.534 J23.676 E.06878
G2 X149.556 Y114.887 I10.852 J-14.005 E.17075
G2 X153.056 Y115.812 I9.715 J-29.681 E.11131
G3 X154.77 Y116.394 I-1.342 J6.763 E.05578
G3 X155.765 Y117.3 I-2.18 J3.39 E.04154
G2 X157.819 Y119.952 I1398.18 J-1081.061 E.10306
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.419 J30.404 E.07721
G3 X166.104 Y126.853 I-1.827 J2.82 E.06588
G3 X167.3 Y129.94 I-590.214 J230.466 E.10171
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.647 Y137.222 I-17.229 J17.514 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.385 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
M73 P47 R10
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X150.223 Y139.363 Z.8 F36000
G1 X146.961 Y134.716 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42192
G1 F15000
G1 X159.231 Y122.447 E.53589
G3 X158.953 Y122.188 I1.785 J-2.2 E.01172
G1 X146.786 Y134.356 E.53142
G1 X146.489 Y134.116 E.01177
G1 X158.676 Y121.93 E.53224
G3 X158.4 Y121.67 I1.87 J-2.259 E.01172
G1 X146.186 Y133.884 E.53347
G1 X145.88 Y133.653 E.01182
G1 X158.14 Y121.394 E.53546
G1 X157.88 Y121.118 E.01171
G1 X145.574 Y133.424 E.53748
G1 X145.258 Y133.203 E.01189
G1 X157.624 Y120.837 E.5401
G1 X157.381 Y120.545 E.01175
G1 X144.943 Y132.982 E.54323
G2 X144.624 Y132.766 I-3.375 J4.64 E.01192
G1 X157.137 Y120.252 E.54655
G1 X156.894 Y119.96 E.01175
G1 X144.299 Y132.555 E.55008
G1 X143.974 Y132.343 E.01196
G1 X156.661 Y119.656 E.55411
G1 X156.43 Y119.351 E.01182
G1 X143.643 Y132.139 E.5585
G1 X143.308 Y131.937 E.01206
G1 X156.199 Y119.046 E.56304
G1 X155.968 Y118.741 E.01182
G1 X142.973 Y131.736 E.56757
G1 X142.629 Y131.545 E.01218
G1 X155.737 Y118.436 E.57254
G2 X155.502 Y118.135 I-6.18 J4.583 E.01179
G1 X142.284 Y131.354 E.57734
G2 X141.935 Y131.166 I-2.866 J4.902 E.01222
G1 X155.265 Y117.837 E.58217
G2 X155.012 Y117.554 I-2.045 J1.576 E.01173
G1 X141.58 Y130.985 E.58662
G1 X141.225 Y130.804 E.01231
G1 X154.746 Y117.284 E.59052
G1 X154.443 Y117.051 E.0118
G1 X140.863 Y130.631 E.59312
G1 X140.497 Y130.46 E.01246
G1 X154.083 Y116.874 E.59339
G1 X153.686 Y116.736 E.013
G1 X140.13 Y130.291 E.59206
G1 X139.754 Y130.132 E.01262
G1 X153.265 Y116.62 E.59013
G1 X152.834 Y116.516 E.01371
G1 X139.378 Y129.972 E.58772
G2 X138.995 Y129.819 I-2.389 J5.405 E.01273
G1 X152.403 Y116.411 E.58559
G1 X151.971 Y116.306 E.01371
G1 X138.608 Y129.67 E.58367
G2 X138.22 Y129.522 I-2.335 J5.533 E.01283
G1 X151.54 Y116.202 E.58177
G1 X151.109 Y116.097 E.01371
G1 X137.821 Y129.384 E.58034
G1 X137.423 Y129.247 E.01302
G1 X150.685 Y115.984 E.57927
G1 X150.27 Y115.864 E.01336
G1 X137.017 Y129.117 E.57884
G1 X136.607 Y128.991 E.01326
G1 X149.855 Y115.743 E.57862
G3 X149.45 Y115.612 I.848 J-3.309 E.01315
G1 X136.194 Y128.867 E.57895
G1 X135.772 Y128.754 E.01352
G1 X149.055 Y115.47 E.58019
G1 X148.661 Y115.329 E.01294
G1 X135.349 Y128.641 E.58142
G2 X134.917 Y128.537 I-1.703 J6.146 E.01373
G1 X148.287 Y115.167 E.58395
G1 X147.913 Y115.005 E.01258
G1 X134.481 Y128.437 E.58665
G2 X134.04 Y128.342 I-1.582 J6.269 E.01393
G1 X147.545 Y114.837 E.58984
G1 X147.192 Y114.654 E.01228
G1 X133.591 Y128.254 E.59401
G2 X133.141 Y128.169 I-1.453 J6.432 E.01417
G1 X146.838 Y114.472 E.59825
G3 X146.495 Y114.279 I1.361 J-2.832 E.01217
G1 X132.678 Y128.096 E.60346
G1 X132.215 Y128.022 E.01447
G1 X146.16 Y114.078 E.60903
G1 X145.825 Y113.877 E.01207
G1 X131.74 Y127.962 E.61518
G1 X131.262 Y127.904 E.01485
G1 X145.503 Y113.663 E.622
G1 X145.184 Y113.446 E.01192
G1 X130.774 Y127.856 E.6294
G1 X130.281 Y127.813 E.01528
G1 X144.865 Y113.229 E.63699
G3 X144.552 Y113.006 I2.732 J-4.161 E.01187
G1 X129.778 Y127.78 E.64529
G1 X129.268 Y127.753 E.01575
G1 X144.244 Y112.778 E.65406
G1 X143.935 Y112.551 E.01184
G1 X128.749 Y127.737 E.66327
G1 X128.222 Y127.727 E.01627
G1 X143.627 Y112.323 E.6728
G1 X143.318 Y112.096 E.01184
G1 X127.685 Y127.729 E.68281
G1 X127.139 Y127.739 E.01685
G1 X143.003 Y111.875 E.69288
G2 X142.685 Y111.657 I-1.69 J2.128 E.01192
G1 X126.58 Y127.762 E.70339
G1 X126.015 Y127.791 E.01749
G1 X142.35 Y111.456 E.71348
G2 X141.996 Y111.274 I-.994 J1.507 E.01233
G1 X125.431 Y127.839 E.72347
G2 X124.843 Y127.891 I.459 J8.455 E.01825
G1 X128.487 Y124.247 E.15917
G1 X128.002 Y124.297 E.01505
G1 X127.908 Y124.29 E.00292
G1 X124.232 Y127.966 E.16057
G2 X123.612 Y128.051 I.894 J8.916 E.01933
G1 X127.434 Y124.228 E.16697
G3 X127.025 Y124.101 I.205 J-1.39 E.01329
G1 X122.975 Y128.151 E.1769
G2 X122.317 Y128.273 I1.414 J9.482 E.02066
G1 X126.666 Y123.925 E.18993
G3 X126.349 Y123.705 I.552 J-1.134 E.01194
G1 X121.646 Y128.408 E.20542
G1 X120.949 Y128.569 E.02209
G1 X126.072 Y123.446 E.22375
G3 X125.833 Y123.149 I.845 J-.921 E.01182
G1 X120.226 Y128.756 E.2449
G2 X119.48 Y128.966 I2.638 J10.797 E.02395
G1 X125.637 Y122.809 E.26892
G3 X125.485 Y122.425 I1.1 J-.658 E.01281
G1 X118.705 Y129.205 E.2961
G1 X117.888 Y129.486 E.0267
G1 X125.392 Y121.982 E.32774
G3 X125.378 Y121.461 I1.681 J-.307 E.01619
G1 X117.026 Y129.812 E.36477
G2 X116.111 Y130.191 I4.962 J13.282 E.03057
G1 X125.524 Y120.778 E.41109
G3 X127.124 Y119.178 I2.494 J.894 E.07222
G1 X135.173 Y111.129 E.35157
G3 X134.695 Y111.071 I.185 J-3.568 E.0149
G1 X115.13 Y130.637 E.85454
G2 X114.059 Y131.171 I7.117 J15.59 E.03697
G1 X134.242 Y110.988 E.88153
G1 X133.789 Y110.905 E.01422
G1 X112.848 Y131.846 E.91464
G2 X111.417 Y132.741 I12.092 J20.927 E.05212
G1 X133.354 Y110.805 E.9581
G1 X132.925 Y110.697 E.01365
G1 X109.469 Y134.153 E1.02445
G2 X104.496 Y139.126 I18.795 J23.768 E.2177
G1 X98.083 Y145.539 E.28009
G1 X97.711 Y145.375 E.01255
G1 X132.503 Y110.583 E1.51955
G1 X132.095 Y110.455 E.01321
G1 X97.34 Y145.211 E1.51797
G1 X96.968 Y145.046 E.01255
G1 X131.687 Y110.327 E1.51638
G3 X131.283 Y110.195 I1.633 J-5.67 E.01312
G1 X96.596 Y144.882 E1.51498
G1 X96.225 Y144.718 E.01255
G1 X130.887 Y110.055 E1.51392
G1 X130.491 Y109.915 E.01297
G1 X95.853 Y144.553 E1.51286
G1 X95.481 Y144.389 E.01255
G1 X130.095 Y109.775 E1.5118
G1 X129.699 Y109.635 E.01297
G1 X95.109 Y144.225 E1.51074
G1 X94.738 Y144.061 E.01255
G1 X129.303 Y109.495 E1.50968
G2 X128.896 Y109.366 I-.986 J2.397 E.01319
G1 X94.366 Y143.896 E1.50816
G1 X93.994 Y143.732 E.01255
G1 X102.913 Y134.813 E.38955
G3 X102.363 Y134.827 I-.321 J-1.774 E.01706
G1 X93.622 Y143.568 E.38176
G1 X93.251 Y143.404 E.01255
G1 X101.901 Y134.754 E.3778
G3 X101.501 Y134.617 I.268 J-1.44 E.01309
G1 X92.879 Y143.239 E.37658
G1 X92.507 Y143.075 E.01255
G1 X101.15 Y134.433 E.37746
G3 X100.841 Y134.206 I.581 J-1.114 E.01189
G1 X92.136 Y142.911 E.3802
G1 X91.764 Y142.747 E.01255
G1 X100.571 Y133.94 E.38465
G3 X100.34 Y133.635 I.872 J-.9 E.01186
G1 X91.392 Y142.582 E.3908
G1 X91.02 Y142.418 E.01255
G1 X100.15 Y133.288 E.39876
G3 X100.008 Y132.894 I1.204 J-.656 E.01299
G1 X90.649 Y142.254 E.4088
G1 X90.277 Y142.09 E.01255
G1 X99.926 Y132.441 E.42144
G3 X99.926 Y131.905 I1.733 J-.269 E.01661
G1 X89.905 Y141.925 E.43765
G1 X89.533 Y141.761 E.01255
G1 X100.122 Y131.173 E.46245
G1 X100.139 Y131.124 E.0016
G3 X101.516 Y129.778 I2.467 J1.147 E.06079
G1 X120.087 Y111.208 E.81109
G1 X119.523 Y111.236 E.01744
G1 X89.162 Y141.597 E1.32606
G1 X88.79 Y141.433 E.01255
G1 X118.969 Y111.254 E1.3181
G1 X118.439 Y111.248 E.01638
G1 X88.418 Y141.268 E1.31117
G1 X88.047 Y141.104 E.01255
M73 P48 R10
G1 X117.908 Y111.243 E1.30424
G3 X117.397 Y111.217 I.027 J-5.7 E.0158
G1 X87.675 Y140.94 E1.29817
G1 X87.303 Y140.776 E.01255
G1 X116.89 Y111.189 E1.29222
G1 X116.382 Y111.161 E.01571
G1 X86.931 Y140.611 E1.28628
G1 X86.56 Y140.447 E.01255
G1 X115.874 Y111.133 E1.28033
G2 X115.354 Y111.117 I-.557 J9.653 E.01607
G1 X86.188 Y140.283 E1.27386
G1 X85.816 Y140.119 E.01255
G1 X114.808 Y111.127 E1.26626
G2 X114.19 Y111.209 I-.018 J2.233 E.01932
G1 X85.444 Y139.954 E1.2555
G1 X85.073 Y139.79 E.01255
G1 X112.956 Y111.906 E1.21786
G1 X111.012 Y113.315 E.07417
G1 X84.701 Y139.626 E1.14915
G1 X84.329 Y139.461 E.01255
G1 X109.515 Y114.276 E1.10001
G1 X108.373 Y114.882 E.03992
G1 X83.958 Y139.297 E1.06638
G1 X83.586 Y139.133 E.01255
G1 X107.424 Y115.295 E1.04116
G1 X106.58 Y115.603 E.02776
G1 X83.474 Y138.709 E1.00917
G3 X83.862 Y137.785 I1.985 J.29 E.03128
G1 X105.802 Y115.844 E.95828
G3 X105.051 Y116.06 I-2.602 J-7.657 E.02415
G1 X87.446 Y133.665 E.76893
G2 X88.416 Y132.159 I-15.601 J-11.113 E.05533
G1 X104.347 Y116.228 E.69581
G1 X103.642 Y116.396 E.02236
G1 X88.999 Y131.04 E.63958
G2 X89.43 Y130.073 I-9.766 J-4.933 E.03271
G1 X102.932 Y116.571 E.58974
G2 X102.171 Y116.796 I.99 J4.747 E.02453
G1 X99.453 Y119.514 E.11872
G3 X95.937 Y123.127 I-14.957 J-11.036 E.1562
G1 X95.579 Y123.388 E.01368
G1 X89.776 Y129.191 E.25344
G1 X90.094 Y128.337 E.02812
G1 X94.033 Y124.398 E.17205
G3 X92.761 Y125.134 I-12.743 J-20.553 E.0454
G1 X90.426 Y127.469 E.10197
G3 X90.976 Y126.392 I5.049 J1.902 E.03741
G3 X91.939 Y125.42 I21.061 J19.885 E.04227
G1 X102.036 Y129.795 F36000
G1 F15000
G1 X120.685 Y111.145 E.81452
G2 X121.292 Y111.075 I-.22 J-4.522 E.01888
G1 X102.788 Y129.579 E.8082
G3 X103.239 Y129.664 I-.048 J1.502 E.01424
G1 X121.949 Y110.954 E.81716
G2 X122.624 Y110.814 I-.959 J-6.336 E.02133
G1 X103.633 Y129.806 E.82949
G3 X103.979 Y129.995 I-.439 J1.216 E.01225
G1 X123.346 Y110.628 E.84588
G2 X124.12 Y110.39 I-2.322 J-8.934 E.02501
G1 X104.285 Y130.226 E.86633
G3 X104.552 Y130.495 I-.738 J.998 E.01175
G1 X124.922 Y110.125 E.88969
G1 X125.763 Y109.82 E.02763
G1 X104.779 Y130.803 E.91648
G1 X104.964 Y131.154 E.01225
G1 X126.604 Y109.515 E.94512
G3 X127.363 Y109.292 I3.381 J10.099 E.02444
G1 X105.1 Y131.554 E.97236
G3 X105.172 Y132.019 I-1.467 J.464 E.01457
G1 X127.992 Y109.199 E.99668
G3 X128.472 Y109.254 I-.132 J3.26 E.01496
G1 X104.937 Y132.789 E1.02791
G1 X103.749 Y140.409 F36000
G1 F15000
G1 X98.455 Y145.703 E.23123
G1 X98.827 Y145.868 E.01255
G1 X102.19 Y142.505 E.14688
G2 X101.517 Y143.713 I32.158 J18.685 E.04271
G1 X99.198 Y146.032 E.10128
G1 X99.57 Y146.196 E.01255
G1 X100.98 Y144.786 E.06157
G2 X100.539 Y145.763 I10.75 J5.438 E.0331
G1 X99.813 Y146.489 E.03171
; WIPE_START
G1 X100.539 Y145.763 E-.39015
G1 X100.939 Y144.876 E-.36985
; WIPE_END
G1 E-.04 F1800
G1 X106.441 Y139.585 Z.8 F36000
G1 X127.606 Y119.232 Z.8
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X135.654 Y111.184 E.3515
G2 X136.155 Y111.219 I.527 J-3.876 E.0155
G1 X128.326 Y119.048 E.34191
G3 X128.768 Y119.142 I-.086 J1.476 E.01399
G1 X136.665 Y111.245 E.34494
G2 X137.194 Y111.252 I.322 J-4.353 E.01635
G1 X129.153 Y119.294 E.35123
G3 X129.491 Y119.491 I-.469 J1.196 E.01215
G1 X137.736 Y111.246 E.3601
G2 X138.284 Y111.234 I.151 J-5.873 E.01692
G1 X129.79 Y119.729 E.37099
G3 X130.049 Y120.005 I-.765 J.978 E.01176
G1 X138.852 Y111.202 E.3845
G1 X139.421 Y111.169 E.01759
G1 X130.269 Y120.321 E.39974
G3 X130.446 Y120.68 I-1.075 J.752 E.01241
G1 X139.99 Y111.136 E.41685
G3 X140.549 Y111.113 I.737 J11.198 E.01727
G1 X130.571 Y121.091 E.43577
G3 X130.631 Y121.567 I-1.514 J.431 E.01488
G1 X141.085 Y111.114 E.45657
G3 X141.575 Y111.159 I.089 J1.73 E.01528
G1 X130.357 Y122.377 E.48999
G1 X163.54 Y125.105 F36000
G1 F15000
G1 X156.062 Y132.583 E.32662
G2 X156.084 Y132.026 I-1.795 J-.348 E.0173
G1 X163.075 Y125.034 E.30536
G1 X162.734 Y124.839 E.01213
G1 X156.013 Y131.56 E.29357
G1 X155.878 Y131.159 E.01307
G1 X162.393 Y124.644 E.28456
G3 X162.057 Y124.444 I3.335 J-5.992 E.01208
G1 X155.693 Y130.808 E.27795
G2 X155.466 Y130.499 I-1.114 J.581 E.01189
G1 X161.724 Y124.241 E.27333
G1 X161.392 Y124.037 E.01204
G1 X155.2 Y130.229 E.27043
G2 X154.895 Y129.998 I-.9 J.872 E.01186
G1 X161.064 Y123.829 E.26945
G1 X160.744 Y123.614 E.01193
G1 X154.549 Y129.808 E.27056
G2 X154.156 Y129.665 I-.66 J1.2 E.01297
G1 X160.43 Y123.391 E.27403
G1 X160.12 Y123.165 E.01185
G1 X153.705 Y129.58 E.28017
G1 X153.256 Y129.573 E.01387
G1 X153.162 Y129.588 E.00295
G1 X159.822 Y122.927 E.29089
G1 X159.526 Y122.687 E.01177
G1 X152.443 Y129.77 E.30938
G2 X151.044 Y131.143 I1.076 J2.496 E.06191
G1 X151.029 Y131.184 E.00135
G1 X147.374 Y134.84 E.15967
G1 X147.66 Y135.089 E.01173
G1 X150.837 Y131.912 E.13874
G2 X150.838 Y132.447 I1.73 J.263 E.01657
G1 X147.947 Y135.338 E.12628
G3 X148.227 Y135.594 I-3.52 J4.136 E.01172
G1 X150.922 Y132.9 E.11768
G2 X151.064 Y133.293 I1.345 J-.265 E.01298
G1 X148.505 Y135.853 E.11179
G1 X148.782 Y136.111 E.01171
G1 X151.254 Y133.639 E.10797
G2 X151.486 Y133.944 I1.102 J-.597 E.01186
G1 X149.051 Y136.379 E.10636
G1 X149.319 Y136.647 E.0117
G1 X151.756 Y134.209 E.10646
G2 X152.066 Y134.436 I.888 J-.889 E.01189
G1 X149.585 Y136.916 E.10836
G1 X149.843 Y137.194 E.01171
G1 X152.418 Y134.619 E.11244
G2 X152.818 Y134.755 I.665 J-1.306 E.0131
G1 X150.102 Y137.471 E.11863
G3 X150.357 Y137.753 I-3.899 J3.784 E.01172
G1 X153.281 Y134.828 E.12774
G2 X153.833 Y134.813 I.227 J-1.79 E.0171
G1 X150.606 Y138.039 E.14093
G1 X150.855 Y138.326 E.01173
G1 X163.757 Y125.424 E.5635
G3 X164.089 Y125.628 I-2.083 J3.766 E.01204
G1 X151.098 Y138.619 E.5674
G1 X151.338 Y138.915 E.01177
G1 X164.414 Y125.84 E.5711
G1 X164.717 Y126.072 E.01181
G1 X151.578 Y139.212 E.57388
G3 X151.808 Y139.517 I-4.221 J3.435 E.01182
G1 X164.984 Y126.341 E.57544
G3 X165.198 Y126.663 I-4.605 J3.311 E.01194
G1 X152.039 Y139.822 E.57476
G3 X152.267 Y140.13 I-4.3 J3.429 E.01184
G1 X165.377 Y127.02 E.57259
G3 X165.541 Y127.392 I-2.363 J1.261 E.01257
G1 X152.488 Y140.445 E.57009
G1 X152.709 Y140.76 E.01189
G1 X165.696 Y127.773 E.56723
G1 X165.842 Y128.163 E.01286
G1 X152.925 Y141.08 E.56418
G1 X153.136 Y141.405 E.01197
G1 X165.988 Y128.553 E.56134
G1 X166.134 Y128.943 E.01286
G1 X153.347 Y141.73 E.5585
G3 X153.549 Y142.064 I-4.486 J2.96 E.01205
G1 X166.28 Y129.333 E.55602
G2 X166.429 Y129.72 I4.554 J-1.525 E.01282
G1 X153.75 Y142.399 E.55374
G3 X153.951 Y142.734 I-4.771 J3.08 E.01207
G1 X166.588 Y130.097 E.55195
G1 X166.748 Y130.473 E.01262
G1 X154.142 Y143.079 E.55058
G1 X154.333 Y143.424 E.01218
G1 X166.909 Y130.848 E.54925
G1 X167.086 Y131.206 E.01235
G1 X154.519 Y143.773 E.54888
G1 X154.7 Y144.129 E.01231
G1 X167.264 Y131.565 E.54875
G2 X167.449 Y131.916 I3.456 J-1.587 E.01227
G1 X154.881 Y144.484 E.54889
G3 X155.053 Y144.848 I-5.12 J2.642 E.01244
G1 X167.642 Y132.259 E.54982
G2 X167.845 Y132.592 I3.067 J-1.638 E.01205
G1 X155.224 Y145.213 E.55123
G3 X155.391 Y145.582 I-4.056 J2.057 E.01251
G1 X168.054 Y132.919 E.55307
G1 X168.263 Y133.246 E.01198
G1 X155.547 Y145.961 E.55536
G1 X155.704 Y146.341 E.01267
G1 X168.484 Y133.561 E.55816
G1 X168.709 Y133.872 E.01186
G1 X156.346 Y146.235 E.53996
G1 X157.306 Y145.811 E.03243
G1 X168.943 Y134.174 E.50825
G2 X169.18 Y134.473 I3.145 J-2.24 E.01179
M73 P49 R10
G1 X158.267 Y145.386 E.47663
G1 X159.227 Y144.962 E.03243
G1 X169.429 Y134.76 E.44557
G1 X169.678 Y135.046 E.01173
G1 X160.188 Y144.537 E.41452
G1 X161.148 Y144.113 E.03243
G1 X169.928 Y135.333 E.38346
G2 X170.184 Y135.612 I3.583 J-3.033 E.01172
G1 X162.109 Y143.688 E.35271
G1 X163.069 Y143.264 E.03243
G1 X170.445 Y135.888 E.32213
G1 X170.705 Y136.164 E.01171
G1 X164.03 Y142.839 E.29155
G1 X164.99 Y142.415 E.03243
G1 X170.965 Y136.44 E.26096
G1 X171.225 Y136.715 E.01171
G1 X165.951 Y141.99 E.23038
G1 X166.911 Y141.566 E.03243
G1 X171.485 Y136.991 E.19979
G3 X171.745 Y137.267 I-1.427 J1.604 E.01173
G1 X167.872 Y141.141 E.16919
G1 X168.832 Y140.717 E.03243
G1 X171.982 Y137.567 E.13758
G3 X172.211 Y137.873 I-.96 J.957 E.01187
G1 X169.793 Y140.292 E.10565
G1 X170.753 Y139.868 E.03243
G1 X172.391 Y138.229 E.07156
G3 X172.509 Y138.648 I-1.382 J.614 E.01347
G1 X171.381 Y139.776 E.04927
; CHANGE_LAYER
; Z_HEIGHT: 0.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X172.509 Y138.648 E-.60619
G1 X172.444 Y138.365 E-.11031
G1 X172.403 Y138.258 E-.04351
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
G1 X125.718 Y121.371
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X125.782 Y121.049 E.01089
G3 X127.826 Y119.362 I2.219 J.607 E.09368
G3 X130.19 Y122.368 I.167 J2.301 E.14952
G3 X125.712 Y121.431 I-2.188 J-.712 E.2233
G1 X126.109 Y121.416 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.161 Y121.153 E.00822
G3 X127.856 Y119.754 I1.841 J.504 E.07196
G3 X128.396 Y119.792 I.146 J1.767 E.0167
G1 X128.438 Y119.799 E.0013
G3 X126.102 Y121.475 I-.435 J1.859 E.26851
; WIPE_START
M204 S10000
G1 X126.161 Y121.153 E-.12442
G1 X126.259 Y120.878 E-.11112
G1 X126.399 Y120.621 E-.11118
G1 X126.576 Y120.388 E-.11113
G1 X126.787 Y120.185 E-.11118
G1 X127.026 Y120.017 E-.11115
G1 X127.214 Y119.924 E-.07983
; WIPE_END
G1 E-.04 F1800
G1 X120.122 Y122.744 Z1 F36000
G1 X101.819 Y130.024 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.022 Y129.96 E.00705
G3 X102.37 Y129.906 I.525 J2.24 E.01171
G1 X102.723 Y129.906 E.0117
G3 X101.685 Y130.067 I-.176 J2.294 E.44433
G1 X101.762 Y130.042 E.00266
G1 X102.438 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00781
G3 X102.379 Y130.3 I-.146 J1.902 E.35867
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.11935
G1 X102.982 Y130.343 E-.11117
G1 X103.261 Y130.431 E-.11117
G1 X103.485 Y130.542 E-.09514
G1 X103.762 Y130.729 E-.127
G1 X103.973 Y130.932 E-.11115
G1 X104.108 Y131.11 E-.08502
; WIPE_END
G1 E-.04 F1800
G1 X111.741 Y131.185 Z1 F36000
G1 X155.684 Y131.617 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.743 Y131.939 E.01088
G3 X153.282 Y129.906 I-2.285 J.26 E.36233
G1 X153.634 Y129.906 E.0117
G3 X155.667 Y131.559 I-.176 J2.293 E.09247
G1 X155.282 Y131.645 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.298 Y131.698 E.00168
G3 X153.312 Y130.298 I-1.84 J.503 E.28739
G1 X153.604 Y130.298 E.00899
G3 X155.2 Y131.422 I-.146 J1.902 E.06296
G1 X155.261 Y131.589 E.00546
; WIPE_START
M204 S10000
G1 X155.298 Y131.698 E-.04362
G1 X155.356 Y131.984 E-.11108
G1 X155.367 Y132.276 E-.11113
G1 X155.334 Y132.567 E-.1112
G1 X155.256 Y132.849 E-.11114
G1 X155.137 Y133.116 E-.11112
G1 X154.978 Y133.362 E-.11118
G1 X154.891 Y133.459 E-.04952
; WIPE_END
G1 E-.04 F1800
G1 X155.286 Y141.081 Z1 F36000
G1 X155.589 Y146.934 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.718 E2.35658
G1 X83.055 Y139.263 E.6296
G3 X83.411 Y137.865 I3.577 J.167 E.04817
G3 X84.377 Y136.65 I5.976 J3.761 E.05159
G2 X86.79 Y133.986 I-24.739 J-24.825 E.11929
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.309 J7.817 E.0825
G3 X91.436 Y125.548 I2.418 J1.172 E.05122
G3 X93.349 Y124.412 I15.961 J24.721 E.07382
G2 X98.059 Y120.701 I-8.564 J-15.714 E.19987
G2 X100.325 Y117.806 I-37.425 J-31.62 E.12197
G3 X101.394 Y116.758 I3.535 J2.535 E.04993
G3 X103.043 Y116.197 I3.008 J6.141 E.05795
G2 X106.577 Y115.257 I-6.546 J-31.733 E.12134
G2 X111.533 Y112.534 I-5.974 J-16.748 E.1884
G3 X113.513 Y111.136 I14.725 J18.745 E.08043
G3 X115.144 Y110.777 I1.449 J2.701 E.05612
G3 X117.853 Y110.909 I-7.763 J188.156 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.354 Y108.943 I11.09 J28.199 E.09118
G3 X128.105 Y108.865 I.643 J2.568 E.02515
G3 X129.666 Y109.259 I-.775 J6.363 E.05352
G2 X133.389 Y110.477 I12.289 J-31.262 E.13004
G2 X138.729 Y110.881 I3.984 J-17.198 E.17831
G3 X141.236 Y110.779 I2.302 J25.755 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.38 J23.413 E.07316
G2 X149.427 Y115.257 I11.081 J-14.315 E.18822
G2 X152.966 Y116.193 I9.837 J-30.031 E.12147
G3 X154.569 Y116.731 I-1.274 J6.463 E.05627
G3 X155.674 Y117.809 I-2.602 J3.771 E.05147
G2 X157.946 Y120.702 I41.963 J-30.612 E.12203
G2 X162.406 Y124.267 I12.705 J-11.323 E.1903
G3 X164.758 Y125.674 I-13.677 J25.536 E.09095
G3 X165.746 Y127.013 I-1.782 J2.348 E.05596
G3 X166.938 Y130.091 I-676.003 J263.635 E.10952
G2 X170.649 Y135.623 I16.058 J-6.761 E.22234
G3 X172.333 Y137.457 I-17.051 J17.343 E.08261
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.196 E2.17923
G1 X82.639 Y139.508 E.60452
G3 X82.93 Y137.962 I5.487 J.231 E.04851
G3 X83.717 Y136.795 I3.808 J1.721 E.04343
G2 X85.862 Y134.489 I-444.968 J-416.118 E.09678
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.443 J7.866 E.07788
G3 X91.213 Y125.225 I2.761 J1.349 E.05331
G3 X93.153 Y124.073 I16.139 J24.969 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18128
G2 X100.018 Y117.563 I-37.345 J-31.531 E.1123
G3 X101.193 Y116.421 I3.821 J2.757 E.05062
G3 X102.951 Y115.816 I3.187 J6.403 E.05729
G2 X106.448 Y114.887 I-6.46 J-31.371 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.851 J18.913 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.447 J182.361 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21158
G3 X127.013 Y108.625 I13.202 J33.875 E.07783
G3 X128.132 Y108.474 I1.009 J3.267 E.03484
G3 X129.794 Y108.889 I-.661 J6.195 E.05281
G2 X133.154 Y110.014 I13.007 J-33.254 E.10894
G2 X138.707 Y110.489 I4.211 J-16.533 E.17202
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.885 Y110.921 I-.11 J3.07 E.05322
G3 X144.706 Y112.222 I-15.536 J23.679 E.06878
G2 X149.556 Y114.887 I10.853 J-14.006 E.17076
G2 X153.057 Y115.812 I9.716 J-29.683 E.11131
G3 X154.77 Y116.394 I-1.342 J6.764 E.05577
G3 X155.765 Y117.301 I-2.181 J3.392 E.04156
G2 X157.819 Y119.952 I1376.331 J-1064.118 E.10304
G2 X162.603 Y123.928 I12.914 J-10.673 E.19227
G3 X164.784 Y125.21 I-16.467 J30.504 E.07775
G3 X166.104 Y126.854 I-1.827 J2.82 E.06589
G3 X167.3 Y129.94 I-589.837 J230.316 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.235 J17.519 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.393 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X156.194 Y146.488 Z1 F36000
G1 Z.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42196
G1 F15000
G1 X155.463 Y145.757 E.03193
G2 X155.022 Y144.78 I-11.195 J4.467 E.03313
G1 X156.437 Y146.195 E.06182
G1 X156.809 Y146.031 E.01255
G1 X154.486 Y143.708 E.10145
G2 X153.804 Y142.49 I-32.208 J17.229 E.0431
G1 X157.18 Y145.866 E.14746
G1 X157.552 Y145.702 E.01255
G1 X152.913 Y141.063 E.20263
G2 X151.492 Y139.106 I-18.149 J11.684 E.07476
G1 X158.053 Y145.666 E.28657
G1 X153.562 Y116.517 F36000
G1 F15000
G1 X157.666 Y120.622 E.17928
; WIPE_START
G1 X156.252 Y119.207 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X162.138 Y124.066 Z1 F36000
G1 X165.461 Y126.809 Z1
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X164.748 Y126.095 E.03116
G2 X163.251 Y125.135 I-6.319 J8.199 E.055
G1 X165.563 Y127.446 E.10097
G3 X165.901 Y128.321 I-15.02 J6.316 E.02897
G1 X161.973 Y124.393 E.17157
G3 X160.449 Y123.405 I9.842 J-16.852 E.05611
G1 X166.222 Y129.178 E.25214
G2 X166.576 Y130.068 I10.504 J-3.664 E.02961
G1 X153.084 Y116.576 E.58933
G1 X152.377 Y116.405 E.02249
G1 X166.996 Y131.024 E.63856
G2 X167.573 Y132.137 I10.887 J-4.94 E.03876
G1 X151.669 Y116.233 E.6947
G1 X150.961 Y116.061 E.02249
G1 X168.543 Y133.643 E.76795
G2 X170.011 Y135.429 I15.847 J-11.53 E.07146
G1 X171.742 Y137.263 E.07789
G1 X172.175 Y137.811 E.0216
G1 X150.21 Y115.846 E.95945
G3 X149.434 Y115.606 I1.54 J-6.354 E.02511
G1 X172.519 Y138.691 E1.00836
G3 X172.579 Y139.06 I-1.959 J.509 E.01157
G1 X172.422 Y139.13 E.00532
G1 X148.591 Y115.299 E1.04094
G1 X147.644 Y114.888 E.0319
G1 X172.05 Y139.294 E1.06609
G1 X171.678 Y139.459 E.01255
G1 X146.505 Y114.285 E1.0996
G3 X145.013 Y113.33 I7.618 J-13.534 E.05473
G1 X171.307 Y139.623 E1.14851
G1 X170.935 Y139.787 E.01255
G1 X143.067 Y111.92 E1.21728
G2 X141.941 Y111.249 I-4.036 J5.499 E.04055
G1 X141.82 Y111.209 E.00393
G1 X170.563 Y139.951 E1.25552
G1 X170.191 Y140.116 E.01255
G1 X141.194 Y111.118 E1.26664
G2 X140.65 Y111.11 I-.326 J3.609 E.01682
G1 X169.82 Y140.28 E1.27417
G1 X169.448 Y140.444 E.01255
G1 X140.132 Y111.128 E1.28056
G1 X139.625 Y111.157 E.01568
G1 X169.076 Y140.609 E1.28646
G1 X168.704 Y140.773 E.01255
G1 X139.118 Y111.186 E1.29236
G1 X138.611 Y111.216 E.01568
G1 X168.333 Y140.937 E1.29827
G1 X167.961 Y141.102 E.01255
G1 X138.101 Y111.242 E1.30429
G1 X137.571 Y111.248 E.01638
G1 X167.589 Y141.266 E1.31122
G1 X167.217 Y141.43 E.01255
G1 X137.041 Y111.253 E1.31814
G3 X136.487 Y111.236 I-.132 J-4.569 E.01712
G1 X166.846 Y141.594 E1.32608
G1 X166.474 Y141.759 E.01255
G1 X155.88 Y131.165 E.46275
G3 X156.079 Y131.899 I-2.28 J1.01 E.02359
G1 X166.102 Y141.923 E.43784
G1 X165.73 Y142.087 E.01255
G1 X156.079 Y132.436 E.42158
G3 X155.993 Y132.886 I-1.801 J-.11 E.0142
G1 X165.359 Y142.252 E.40909
G1 X164.987 Y142.416 E.01255
G1 X155.856 Y133.285 E.39886
G3 X155.667 Y133.632 I-1.219 J-.439 E.01225
G1 X164.615 Y142.58 E.39088
G1 X164.244 Y142.745 E.01255
G1 X155.436 Y133.937 E.38471
G3 X155.167 Y134.204 I-.997 J-.739 E.01175
G1 X163.872 Y142.909 E.38025
G1 X163.5 Y143.073 E.01255
G1 X154.858 Y134.431 E.37749
G3 X154.507 Y134.616 I-.775 J-1.044 E.0123
G1 X163.128 Y143.237 E.37658
G1 X162.757 Y143.402 E.01255
G1 X154.107 Y134.753 E.3778
G3 X153.646 Y134.827 I-.471 J-1.458 E.0145
G1 X162.385 Y143.566 E.38173
G1 X162.013 Y143.73 E.01255
G1 X152.877 Y134.594 E.39906
; WIPE_START
G1 X154.291 Y136.009 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.986 Y130.271 Z1 F36000
M73 P49 R9
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X135.923 Y111.208 E.83267
G3 X135.325 Y111.146 I.18 J-4.672 E.01857
G1 X153.769 Y129.59 E.80563
G1 X153.66 Y129.573 E.0034
G1 X153.221 Y129.578 E.01355
G1 X134.719 Y111.076 E.80821
G1 X134.062 Y110.955 E.02062
G1 X152.769 Y129.662 E.81714
M73 P50 R9
G2 X152.375 Y129.804 I.263 J1.347 E.01299
G1 X133.383 Y110.812 E.82959
G1 X132.668 Y110.633 E.02276
G1 X152.028 Y129.993 E.84565
G2 X151.722 Y130.223 I.592 J1.105 E.01187
G1 X131.89 Y110.391 E.86628
G3 X131.09 Y110.127 I3.262 J-11.226 E.02603
G1 X151.456 Y130.493 E.88959
G1 X151.231 Y130.804 E.01186
G1 X130.261 Y109.834 E.91599
G1 X129.432 Y109.541 E.02716
G1 X151.041 Y131.151 E.94393
G1 X150.905 Y131.551 E.01305
G1 X128.658 Y109.303 E.97179
G2 X128.017 Y109.199 I-.846 J3.173 E.02007
G1 X150.833 Y132.014 E.9966
G2 X150.853 Y132.57 I1.807 J.215 E.01724
G1 X127.535 Y109.252 E1.01855
G2 X127.103 Y109.357 I.385 J2.525 E.01373
G1 X161.641 Y143.895 E1.50865
G1 X161.27 Y144.059 E.01255
G1 X126.695 Y109.485 E1.51022
G2 X126.3 Y109.625 I1.416 J4.628 E.01297
G1 X160.898 Y144.223 E1.51128
G1 X160.526 Y144.388 E.01255
G1 X125.906 Y109.768 E1.51222
G1 X125.513 Y109.91 E.01292
G1 X160.154 Y144.552 E1.51316
G1 X159.783 Y144.716 E.01255
G1 X125.119 Y110.053 E1.51411
G3 X124.723 Y110.192 I-2.484 J-6.447 E.01299
G1 X159.411 Y144.88 E1.51521
G1 X159.039 Y145.045 E.01255
G1 X124.319 Y110.325 E1.51659
G1 X123.916 Y110.457 E.01312
G1 X158.667 Y145.209 E1.51798
G1 X158.296 Y145.373 E.01255
G1 X123.506 Y110.583 E1.51965
G1 X123.087 Y110.701 E.01343
G1 X146.556 Y134.17 E1.02513
G2 X144.598 Y132.748 I-13.643 J16.731 E.07475
G1 X122.657 Y110.806 E.95844
G3 X122.219 Y110.904 I-1.127 J-4.007 E.01387
G1 X143.166 Y131.852 E.91501
G2 X141.953 Y131.175 I-20.587 J35.466 E.0429
G1 X121.766 Y110.988 E.88182
G1 X121.313 Y111.071 E.01422
G1 X140.882 Y130.64 E.85479
G2 X139.899 Y130.193 I-6.89 J13.858 E.03334
G1 X130.479 Y120.773 E.4115
G3 X130.627 Y121.457 I-2.606 J.922 E.02167
G1 X138.984 Y129.814 E.36506
G2 X138.122 Y129.488 I-5.108 J12.195 E.02849
G1 X130.613 Y121.979 E.32799
G3 X130.52 Y122.422 I-1.482 J-.079 E.01404
G1 X137.304 Y129.207 E.29633
G2 X136.529 Y128.968 I-3.811 J10.986 E.02505
G1 X130.368 Y122.806 E.26914
G3 X130.173 Y123.147 I-1.038 J-.369 E.01219
G1 X135.783 Y128.757 E.24506
G2 X135.06 Y128.57 I-3.035 J10.248 E.02307
G1 X129.934 Y123.445 E.22389
G3 X129.657 Y123.704 I-.977 J-.767 E.01176
G1 X134.363 Y128.409 E.20555
G2 X133.692 Y128.274 I-2.274 J9.539 E.02116
G1 X129.341 Y123.923 E.19004
G3 X128.982 Y124.1 I-.752 J-1.074 E.01241
G1 X133.034 Y128.152 E.17698
G1 X132.397 Y128.051 E.01992
G1 X128.573 Y124.227 E.16704
G3 X128.099 Y124.29 I-.44 J-1.501 E.01481
G1 X131.776 Y127.967 E.16062
G1 X131.165 Y127.892 E.01902
G1 X127.294 Y124.02 E.1691
; WIPE_START
G1 X128.708 Y125.435 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.224 Y119.518 Z1 F36000
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X120.834 Y111.128 E.36649
G1 X120.353 Y111.183 E.01495
G1 X128.199 Y119.029 E.34269
G2 X127.681 Y119.047 I-.199 J1.686 E.01606
G1 X119.853 Y111.219 E.34193
G1 X119.343 Y111.245 E.01579
G1 X127.239 Y119.142 E.34494
G2 X126.854 Y119.292 I.295 J1.321 E.01283
G1 X118.814 Y111.252 E.35121
G1 X118.272 Y111.246 E.01673
G1 X126.515 Y119.489 E.36006
G2 X126.217 Y119.727 I.62 J1.084 E.01183
G1 X117.725 Y111.235 E.37092
G1 X117.158 Y111.204 E.01755
G1 X125.957 Y120.003 E.38437
G2 X125.737 Y120.319 I.913 J.871 E.01194
G1 X116.59 Y111.172 E.39954
G1 X116.023 Y111.141 E.01756
G1 X125.56 Y120.678 E.41659
G2 X125.434 Y121.088 I1.264 J.613 E.0133
G1 X115.466 Y111.12 E.43542
G2 X114.93 Y111.121 I-.261 J3.563 E.01654
G1 X125.374 Y121.564 E.45617
G2 X125.41 Y122.136 I1.869 J.17 E.01777
G1 X114.436 Y111.162 E.47934
G2 X114.006 Y111.269 I.201 J1.737 E.01371
G1 X130.577 Y127.839 E.72381
G2 X129.993 Y127.791 I-.973 J8.318 E.01809
G1 X113.65 Y111.448 E.71389
G1 X113.316 Y111.651 E.01205
G1 X129.427 Y127.762 E.70375
G2 X128.868 Y127.739 I-.61 J8.012 E.01729
G1 X113.002 Y111.873 E.69303
G1 X112.692 Y112.099 E.01185
G1 X128.322 Y127.729 E.68273
G2 X127.785 Y127.727 I-.294 J7.681 E.01662
G1 X112.383 Y112.326 E.67276
G1 X112.073 Y112.552 E.01185
G1 X127.258 Y127.737 E.66327
G2 X126.738 Y127.753 I-.02 J7.456 E.01605
G1 X111.764 Y112.778 E.65411
G1 X111.454 Y113.005 E.01185
G1 X126.229 Y127.78 E.64539
G2 X125.726 Y127.813 I.22 J7.212 E.01558
G1 X111.14 Y113.227 E.63711
G1 X110.821 Y113.444 E.01192
G1 X125.233 Y127.856 E.62951
G2 X124.744 Y127.903 I.434 J7.031 E.01517
G1 X110.502 Y113.662 E.6221
G3 X110.181 Y113.876 I-2.03 J-2.684 E.01194
G1 X124.267 Y127.962 E.61527
G2 X123.791 Y128.022 I.618 J6.817 E.01482
G1 X109.846 Y114.077 E.60912
G1 X109.511 Y114.278 E.01207
G1 X123.328 Y128.095 E.60355
G1 X122.865 Y128.169 E.01447
G1 X109.168 Y114.471 E.59834
G1 X108.814 Y114.654 E.01229
G1 X122.415 Y128.254 E.59408
G1 X121.966 Y128.341 E.01412
G1 X108.461 Y114.836 E.58991
G3 X108.093 Y115.004 I-1.426 J-2.635 E.0125
G1 X121.525 Y128.436 E.58672
G1 X121.089 Y128.537 E.01381
G1 X107.719 Y115.167 E.58402
G3 X107.345 Y115.328 I-1.432 J-2.799 E.0126
G1 X120.657 Y128.641 E.58149
G1 X120.234 Y128.754 E.01352
G1 X106.95 Y115.47 E.58025
G1 X106.556 Y115.612 E.01294
G1 X119.812 Y128.867 E.57901
G2 X119.399 Y128.991 I1.574 J5.991 E.0133
G1 X106.151 Y115.743 E.57868
G1 X105.736 Y115.864 E.01336
G1 X118.989 Y129.116 E.57889
G2 X118.583 Y129.247 I1.667 J5.877 E.01316
G1 X105.321 Y115.984 E.57931
G3 X104.897 Y116.097 I-1.37 J-4.318 E.01355
G1 X118.184 Y129.384 E.58041
G1 X117.786 Y129.521 E.01303
G1 X104.464 Y116.2 E.58189
G1 X104.032 Y116.303 E.01374
G1 X117.398 Y129.669 E.58384
G1 X117.01 Y129.818 E.01282
G1 X103.599 Y116.407 E.58582
G1 X103.166 Y116.51 E.01374
G1 X116.628 Y129.972 E.58801
G1 X116.251 Y130.131 E.01263
G1 X102.741 Y116.621 E.59014
G2 X102.325 Y116.741 I.523 J2.587 E.01338
G1 X115.875 Y130.291 E.59187
G2 X115.508 Y130.46 I2.231 J5.325 E.01248
G1 X101.929 Y116.881 E.59315
G2 X101.565 Y117.054 I.36 J1.227 E.01248
G1 X115.143 Y130.631 E.59306
G2 X114.78 Y130.804 I2.303 J5.282 E.01242
G1 X101.256 Y117.28 E.59074
G2 X100.988 Y117.548 I.806 J1.075 E.01175
G1 X114.425 Y130.985 E.58694
G1 X114.07 Y131.166 E.01231
G1 X100.736 Y117.832 E.58242
G1 X100.504 Y118.136 E.01181
G1 X113.721 Y131.354 E.57733
G1 X113.376 Y131.545 E.01218
G1 X100.272 Y118.44 E.5724
G1 X100.04 Y118.744 E.01181
G1 X113.032 Y131.736 E.56748
G1 X112.697 Y131.937 E.01207
G1 X99.808 Y119.049 E.56299
G1 X99.576 Y119.353 E.01181
G1 X112.362 Y132.138 E.55849
G2 X112.03 Y132.343 I2.763 J4.851 E.01203
G1 X99.344 Y119.657 E.55415
G3 X99.111 Y119.959 I-3.676 J-2.591 E.01181
G1 X111.705 Y132.554 E.55014
G1 X111.38 Y132.765 E.01197
G1 X98.867 Y120.252 E.54658
G1 X98.624 Y120.544 E.01176
M73 P51 R9
G1 X111.062 Y132.982 E.5433
G1 X110.746 Y133.203 E.01189
G1 X98.38 Y120.837 E.54016
G3 X98.125 Y121.118 I-2.411 J-1.935 E.01173
G1 X110.432 Y133.425 E.53757
G1 X110.126 Y133.654 E.01183
G1 X97.865 Y121.394 E.53556
G1 X97.605 Y121.67 E.01171
G1 X109.819 Y133.884 E.53354
G2 X109.515 Y134.116 I2.985 J4.235 E.01182
G1 X97.329 Y121.93 E.5323
G1 X97.052 Y122.188 E.01171
G1 X109.219 Y134.356 E.53148
G1 X108.923 Y134.596 E.01177
G1 X96.774 Y122.447 E.53068
G1 X96.478 Y122.687 E.01177
G1 X103.562 Y129.771 E.30944
G1 X103.533 Y129.756 E.00102
G2 X102.843 Y129.587 I-.892 J2.147 E.02203
G1 X96.183 Y122.927 E.29091
G3 X95.884 Y123.165 I-2.373 J-2.667 E.01179
G1 X102.299 Y129.58 E.28019
G2 X101.848 Y129.665 I.051 J1.5 E.01422
G1 X95.574 Y123.391 E.27405
G3 X95.261 Y123.614 I-3.107 J-4.048 E.01188
G1 X101.455 Y129.808 E.27059
G2 X101.109 Y129.998 I.442 J1.216 E.01224
G1 X94.94 Y123.829 E.26947
G3 X94.613 Y124.039 I-2.945 J-4.235 E.01199
G1 X100.804 Y130.229 E.27042
G2 X100.538 Y130.499 I.74 J.997 E.01175
G1 X94.282 Y124.243 E.27326
G3 X93.95 Y124.447 I-3.515 J-5.356 E.01204
G1 X100.311 Y130.808 E.27785
G1 X100.126 Y131.16 E.01226
G1 X93.61 Y124.644 E.28463
G1 X93.27 Y124.84 E.01212
G1 X99.992 Y131.561 E.29359
G2 X99.921 Y132.026 I1.472 J.462 E.0146
G1 X92.931 Y125.036 E.30534
G1 X92.591 Y125.232 E.01212
G1 X100.159 Y132.8 E.33056
; WIPE_START
G1 X98.744 Y131.386 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X101.949 Y134.591 Z1 F36000
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X105.398 Y138.04 E.15066
G1 X105.648 Y137.753 E.01174
G1 X102.722 Y134.828 E.12777
G2 X103.186 Y134.755 I-.004 J-1.536 E.01454
G1 X105.902 Y137.472 E.11866
G1 X106.161 Y137.194 E.01171
G1 X103.587 Y134.62 E.11244
G2 X103.938 Y134.436 I-.421 J-1.231 E.01231
G1 X106.419 Y136.917 E.10837
G3 X106.686 Y136.647 I4 J3.681 E.01171
G1 X104.248 Y134.209 E.10648
G2 X104.519 Y133.944 I-.724 J-1.008 E.01175
G1 X106.954 Y136.379 E.10637
G3 X107.222 Y136.111 I3.932 J3.679 E.01171
G1 X104.75 Y133.639 E.10798
G2 X104.94 Y133.293 I-1.025 J-.788 E.01224
G1 X107.5 Y135.853 E.1118
G1 X107.777 Y135.594 E.01171
G1 X105.083 Y132.9 E.11768
G2 X105.166 Y132.447 I-1.423 J-.496 E.01428
G1 X108.057 Y135.338 E.12629
G1 X108.344 Y135.089 E.01174
G1 X105.168 Y131.913 E.13875
G2 X104.975 Y131.184 I-4.733 J.86 E.02329
G1 X108.751 Y134.96 E.16493
G1 X105.269 Y138.447 F36000
G1 F15000
G1 X92.251 Y125.428 E.56865
G2 X91.92 Y125.634 I2.085 J3.735 E.01203
G1 X104.906 Y138.62 E.56725
G1 X104.666 Y138.916 E.01177
G1 X91.596 Y125.845 E.57094
G1 X91.293 Y126.079 E.01181
G1 X104.426 Y139.212 E.57369
G2 X104.196 Y139.517 I4.244 J3.451 E.01182
G1 X91.022 Y126.344 E.57542
G2 X90.799 Y126.657 I.785 J.795 E.01193
G1 X103.965 Y139.823 E.57509
G2 X103.737 Y140.131 I4.283 J3.416 E.01184
G1 X90.622 Y127.015 E.57289
G2 X90.459 Y127.388 I2.361 J1.254 E.01259
G1 X103.516 Y140.446 E.57037
G1 X103.295 Y140.761 E.01189
G1 X90.305 Y127.77 E.56745
G1 X90.159 Y128.161 E.01287
G1 X103.079 Y141.081 E.56437
G1 X102.868 Y141.406 E.01197
G1 X90.014 Y128.552 E.5615
G1 X89.869 Y128.943 E.01288
G1 X102.657 Y141.731 E.55863
G2 X102.454 Y142.064 I4.661 J3.073 E.01205
G1 X89.723 Y129.333 E.5561
G3 X89.576 Y129.722 I-5.31 J-1.798 E.01284
G1 X102.253 Y142.399 E.55376
G2 X102.053 Y142.735 I4.715 J3.032 E.01208
G1 X89.418 Y130.1 E.5519
G1 X89.261 Y130.479 E.01267
G1 X101.862 Y143.08 E.55041
G1 X101.671 Y143.425 E.01218
G1 X89.091 Y130.845 E.5495
G1 X88.919 Y131.209 E.01244
G1 X101.486 Y143.776 E.54893
G1 X101.304 Y144.131 E.0123
G1 X88.741 Y131.567 E.54877
G1 X88.551 Y131.913 E.01219
G1 X101.123 Y144.485 E.54915
G2 X100.951 Y144.849 I4.862 J2.521 E.01244
G1 X88.361 Y132.259 E.54994
G3 X88.16 Y132.594 I-2.588 J-1.327 E.01208
G1 X100.78 Y145.215 E.55128
G2 X100.613 Y145.584 I4.06 J2.058 E.01252
G1 X87.95 Y132.921 E.55313
G1 X87.741 Y133.247 E.01198
G1 X100.457 Y145.963 E.55543
G1 X100.3 Y146.342 E.01268
G1 X87.52 Y133.562 E.55824
G1 X87.295 Y133.874 E.01186
G1 X99.655 Y146.234 E.53989
G1 X98.695 Y145.809 E.03243
G1 X87.061 Y134.175 E.50818
G3 X86.824 Y134.475 I-3.139 J-2.237 E.01179
G1 X97.734 Y145.385 E.47656
G1 X96.774 Y144.96 E.03243
G1 X86.575 Y134.761 E.4455
G1 X86.325 Y135.048 E.01174
G1 X95.813 Y144.536 E.41444
G1 X94.853 Y144.112 E.03243
G1 X86.076 Y135.335 E.38337
G3 X85.82 Y135.615 I-3.781 J-3.206 E.01172
G1 X93.892 Y143.687 E.35261
G1 X92.932 Y143.263 E.03243
G1 X85.56 Y135.891 E.322
G1 X85.301 Y136.168 E.01171
G1 X91.971 Y142.838 E.29139
G1 X91.011 Y142.414 E.03243
G1 X85.041 Y136.444 E.26077
G1 X84.782 Y136.721 E.01171
G1 X90.051 Y141.99 E.23016
G1 X89.09 Y141.565 E.03243
G1 X84.522 Y136.997 E.19954
G2 X84.263 Y137.274 I1.41 J1.581 E.01173
G1 X88.13 Y141.141 E.16892
G1 X87.169 Y140.716 E.03243
G1 X84.027 Y137.574 E.13726
G2 X83.796 Y137.879 I.963 J.971 E.01186
G1 X86.209 Y140.292 E.1054
G1 X85.248 Y139.868 E.03243
G1 X83.61 Y138.23 E.07155
G2 X83.489 Y138.644 I1.351 J.622 E.01338
G1 X84.62 Y139.776 E.04943
; CHANGE_LAYER
; Z_HEIGHT: 0.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X83.489 Y138.644 E-.60815
G1 X83.543 Y138.403 E-.09379
G1 X83.598 Y138.261 E-.05806
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
G1 X125.718 Y121.371
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X125.782 Y121.049 E.01088
G3 X127.826 Y119.362 I2.218 J.606 E.0937
G3 X130.065 Y120.644 I.159 J2.319 E.09074
G3 X125.711 Y121.43 I-2.065 J1.011 E.28181
G1 X126.108 Y121.419 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.162 Y121.153 E.00832
G3 X127.856 Y119.754 I1.84 J.503 E.07194
G3 X128.386 Y119.791 I.146 J1.733 E.01638
G1 X128.438 Y119.799 E.00162
G3 X126.103 Y121.478 I-.435 J1.858 E.26823
; WIPE_START
M204 S10000
G1 X126.162 Y121.153 E-.12554
G1 X126.259 Y120.878 E-.1111
G1 X126.399 Y120.621 E-.11117
G1 X126.576 Y120.388 E-.11113
G1 X126.787 Y120.185 E-.11118
G1 X127.026 Y120.017 E-.11115
G1 X127.212 Y119.925 E-.07873
; WIPE_END
G1 E-.04 F1800
G1 X120.12 Y122.746 Z1.2 F36000
G1 X101.843 Y130.017 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.022 Y129.96 E.00621
G3 X102.37 Y129.906 I.526 J2.24 E.01171
G3 X103.65 Y130.186 I.176 J2.258 E.04408
G1 X103.724 Y130.223 E.00274
G3 X101.685 Y130.067 I-1.176 J1.977 E.40922
G1 X101.786 Y130.035 E.0035
G1 X102.433 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00796
G3 X102.374 Y130.301 I-.146 J1.902 E.35851
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.12123
G1 X102.982 Y130.343 E-.11117
G1 X103.261 Y130.431 E-.11118
G1 X103.476 Y130.538 E-.09117
G1 X103.762 Y130.729 E-.13093
G1 X103.973 Y130.932 E-.11115
G1 X104.106 Y131.106 E-.08318
; WIPE_END
G1 E-.04 F1800
G1 X111.738 Y131.182 Z1.2 F36000
G1 X155.684 Y131.617 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.745 Y131.939 E.01088
G3 X153.282 Y129.906 I-2.286 J.261 E.3624
G3 X154.561 Y130.186 I.176 J2.258 E.04408
G1 X154.635 Y130.223 E.00274
G3 X155.668 Y131.559 I-1.177 J1.977 E.05737
G1 X155.284 Y131.652 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.298 Y131.698 E.00148
G3 X153.312 Y130.298 I-1.84 J.503 E.28739
G1 X153.604 Y130.298 E.00899
G3 X155.2 Y131.422 I-.146 J1.902 E.06296
G1 X155.264 Y131.595 E.00566
; WIPE_START
M204 S10000
G1 X155.298 Y131.698 E-.04105
G1 X155.356 Y131.984 E-.11108
G1 X155.367 Y132.276 E-.11113
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11116
G1 X155.137 Y133.116 E-.11114
G1 X154.978 Y133.362 E-.11116
G1 X154.886 Y133.464 E-.0521
; WIPE_END
G1 E-.04 F1800
G1 X155.284 Y141.086 Z1.2 F36000
G1 X155.589 Y146.934 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.719 E2.35655
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.58 J.167 E.04815
G3 X84.377 Y136.65 I5.976 J3.76 E.05162
G2 X86.79 Y133.985 I-24.74 J-24.825 E.1193
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18944
G3 X90.41 Y126.674 I23.317 J7.82 E.08249
G3 X91.436 Y125.548 I2.418 J1.171 E.05124
G3 X93.349 Y124.413 I15.953 J24.709 E.0738
G2 X98.06 Y120.701 I-8.564 J-15.715 E.19989
G2 X100.325 Y117.807 I-37.423 J-31.618 E.12195
G3 X101.394 Y116.757 I3.535 J2.535 E.04995
G3 X103.044 Y116.197 I3.008 J6.143 E.05795
G2 X106.577 Y115.257 I-6.542 J-31.72 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.747 E.18842
G3 X113.513 Y111.136 I14.724 J18.743 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05612
G3 X117.853 Y110.909 I-7.765 J188.191 E.08995
G2 X124.754 Y109.831 I.851 J-17.19 E.2333
G3 X127.353 Y108.943 I11.097 J28.218 E.09117
G3 X128.106 Y108.866 I.643 J2.567 E.02517
G3 X129.665 Y109.259 I-.645 J5.844 E.05353
G2 X133.389 Y110.477 I12.289 J-31.263 E.13004
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.302 J25.755 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.389 J23.426 E.07315
G2 X149.428 Y115.257 I11.081 J-14.314 E.18824
G2 X152.965 Y116.193 I9.838 J-30.038 E.12144
G3 X154.57 Y116.731 I-1.274 J6.464 E.05629
G3 X155.675 Y117.81 I-2.604 J3.773 E.05149
G2 X157.946 Y120.702 I41.963 J-30.612 E.12199
G2 X162.421 Y124.276 I12.716 J-11.334 E.1909
G3 X164.758 Y125.674 I-13.518 J25.249 E.09035
G3 X165.746 Y127.013 I-1.782 J2.349 E.05598
G3 X166.938 Y130.091 I-684.228 J266.811 E.10949
G2 X170.649 Y135.623 I16.059 J-6.762 E.22235
G3 X172.333 Y137.457 I-17.054 J17.346 E.0826
G3 X172.913 Y139.008 I-2.311 J1.749 E.05572
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.197 E2.1792
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.199 J.192 E.05096
G3 X83.717 Y136.795 I3.893 J1.885 E.04099
G2 X85.862 Y134.49 I-445.171 J-416.313 E.09675
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20158
G3 X90.062 Y126.493 I23.446 J7.867 E.07787
G3 X91.213 Y125.225 I2.761 J1.348 E.05332
G3 X93.152 Y124.073 I16.13 J24.953 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.017 Y117.563 I-37.335 J-31.523 E.1123
G3 X101.193 Y116.421 I3.821 J2.758 E.05062
G3 X102.951 Y115.816 I3.187 J6.404 E.05729
G2 X106.448 Y114.887 I-6.458 J-31.364 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.848 J18.909 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.448 J182.385 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.014 Y108.625 I13.205 J33.886 E.07784
G3 X128.132 Y108.474 I1.009 J3.266 E.03483
G3 X129.794 Y108.889 I-.666 J6.212 E.0528
G2 X133.154 Y110.014 I13.007 J-33.255 E.10893
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05322
G3 X144.706 Y112.222 I-15.548 J23.696 E.06879
G2 X149.556 Y114.887 I10.852 J-14.004 E.17075
G2 X153.057 Y115.812 I9.717 J-29.686 E.11132
G3 X154.77 Y116.394 I-1.342 J6.764 E.05577
G3 X155.764 Y117.3 I-2.18 J3.39 E.04153
G2 X157.819 Y119.952 I1401.473 J-1083.622 E.10307
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.3 J30.203 E.07721
G3 X166.104 Y126.854 I-1.828 J2.82 E.0659
G3 X167.3 Y129.94 I-595.885 J232.652 E.10168
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.239 J17.523 E.07791
G3 X173.302 Y138.956 I-2.618 J1.981 E.05776
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z1.2 F36000
G1 Z.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.266 J11.569 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.656 J1.408 E.08774
G2 X162.172 Y124.532 I-25.046 J37.901 E.10008
G1 X155.776 Y130.928 E.30006
G3 X155.992 Y132.965 I-2.661 J1.313 E.06937
G1 X165.292 Y142.265 E.43628
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.908 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34273
G2 X140.386 Y111.134 I-1.124 J3.224 E.05407
G1 X129.352 Y123.934 F36000
G1 F15476.087
G2 X130.416 Y122.741 I-1.349 J-2.275 E.05391
G1 X136.671 Y128.995 E.29341
G2 X135.109 Y128.566 I-10.009 J33.387 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.645 Y112.355 I8.085 J-18.79 E.18603
G1 X128.286 Y127.714 E.7205
G2 X127.713 Y127.714 I-.285 J8.198 E.019
G1 X112.36 Y112.361 E.72024
G3 X107.571 Y115.247 I-12.978 J-16.116 E.18607
M73 P52 R9
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.486 J33.929 E.05383
G1 X125.587 Y122.737 E.29368
G2 X126.65 Y123.933 I2.416 J-1.078 E.05391
G1 X115.627 Y111.14 F36000
G1 F15476.087
G2 X114.015 Y111.281 I-.476 J3.84 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07074
G3 X83.957 Y137.688 I2.363 J.126 E.04916
G1 X86.809 Y140.541 E.1338
G1 X90.708 Y142.264 E.14141
G1 X100.011 Y132.961 E.43643
G3 X100.227 Y130.931 I2.877 J-.72 E.06912
G1 X93.83 Y124.534 E.30011
G2 X90.988 Y126.402 I5.505 J11.472 E.11314
G2 X90.068 Y128.448 I10.57 J5.98 E.07454
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.046 J23.848 E.05401
G1 X88.404 Y132.211 F36000
G1 F15476.087
G3 X87.525 Y133.581 I-17.716 J-10.403 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.658 Y109.99 E1.62438
G2 X127.87 Y109.214 I-3.762 J8.116 E.09642
G2 X125.341 Y109.989 I2.66 J13.194 E.08789
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.245 J-12.708 E.054
; WIPE_START
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
; WIPE_END
G1 E-.04 F1800
G1 X160.618 Y133.101 Z1.2 F36000
G1 X142.231 Y131.307 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G2 X140.777 Y130.574 I-15.8 J29.531 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.633 Y118.324 I-3.855 J5.097 E.06132
G2 X157.884 Y121.144 I27.093 J-19.31 E.11975
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-18.114 J24.796 E.18067
G1 X152.182 Y134.522 E.11675
G3 X152.697 Y129.669 I1.316 J-2.314 E.20476
G1 X133.984 Y110.956 E.87789
G2 X137.055 Y111.268 I4.403 J-28.037 E.10248
G1 X129.082 Y119.242 E.37406
G2 X126.919 Y119.244 I-1.079 J2.441 E.07387
G1 X118.944 Y111.268 E.37413
G2 X122.015 Y110.957 I-1.316 J-28.286 E.10243
G1 X103.304 Y129.668 E.87778
G3 X103.82 Y134.524 I-.754 J2.535 E.20633
G1 X106.309 Y137.013 E.11678
G3 X110.399 Y133.428 I22.212 J21.213 E.18067
G1 X98.118 Y121.147 E.57613
G2 X100.796 Y117.779 I-30.116 J-26.694 E.1428
G3 X101.665 Y117.017 I2.261 J1.701 E.03859
G1 X115.224 Y130.576 E.6361
G2 X113.77 Y131.309 I14.316 J30.192 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X115.224 Y130.576 E-.61863
G1 X114.961 Y130.313 E-.14137
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
G1 X125.713 Y121.43
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.719 Y121.396 E.00117
G3 X127.826 Y119.362 I2.291 J.265 E.10523
G3 X125.711 Y121.84 I.177 J2.293 E.35919
G1 X125.713 Y121.49 E.0116
G1 X126.108 Y121.422 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.161 Y121.153 E.00842
G3 X127.856 Y119.754 I1.841 J.504 E.07196
G1 X128.149 Y119.754 E.00899
G3 X126.102 Y121.482 I-.146 J1.903 E.27727
; WIPE_START
M204 S10000
G1 X126.161 Y121.153 E-.12681
G1 X126.259 Y120.878 E-.11113
G1 X126.399 Y120.621 E-.11115
G1 X126.576 Y120.388 E-.11115
G1 X126.787 Y120.185 E-.11116
G1 X127.026 Y120.017 E-.11115
G1 X127.209 Y119.926 E-.07744
; WIPE_END
G1 E-.04 F1800
G1 X120.117 Y122.748 Z1.4 F36000
G1 X101.868 Y130.009 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.022 Y129.962 E.00534
G3 X102.37 Y129.906 I.537 J2.247 E.01171
G3 X100.255 Y132.384 I.178 J2.294 E.35946
G3 X101.686 Y130.07 I2.304 J-.175 E.09652
G1 X101.811 Y130.028 E.00436
G1 X102.428 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00812
G3 X102.368 Y130.301 I-.146 J1.902 E.35835
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.12319
G1 X102.982 Y130.343 E-.11117
G1 X103.261 Y130.431 E-.11118
G1 X103.466 Y130.533 E-.08721
G1 X103.762 Y130.729 E-.13486
G1 X103.973 Y130.932 E-.11113
G1 X104.102 Y131.102 E-.08127
; WIPE_END
G1 E-.04 F1800
G1 X111.735 Y131.17 Z1.4 F36000
G1 X155.667 Y131.56 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.678 Y131.593 E.00117
G3 X153.282 Y129.906 I-2.22 J.608 E.37425
G3 X154.552 Y130.182 I.176 J2.253 E.04373
G1 X154.635 Y130.223 E.00309
G3 X155.52 Y131.177 I-1.177 J1.978 E.04376
G1 X155.645 Y131.504 E.01161
G1 X155.287 Y131.658 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.299 Y131.697 E.00126
G3 X153.312 Y130.298 I-1.841 J.504 E.28755
G1 X153.604 Y130.298 E.00899
G3 X155.201 Y131.422 I-.146 J1.903 E.06297
G1 X155.266 Y131.602 E.00588
; WIPE_START
M204 S10000
G1 X155.299 Y131.697 E-.0384
G1 X155.356 Y131.984 E-.11111
G1 X155.367 Y132.276 E-.11113
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11116
G1 X155.137 Y133.116 E-.11114
G1 X154.978 Y133.362 E-.11116
G1 X154.882 Y133.469 E-.05473
; WIPE_END
G1 E-.04 F1800
G1 X155.282 Y141.091 Z1.4 F36000
G1 X155.589 Y146.934 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.6296
G3 X83.411 Y137.866 I3.58 J.167 E.04815
G3 X84.377 Y136.65 I5.973 J3.758 E.05161
G2 X86.79 Y133.986 I-24.74 J-24.825 E.11929
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.304 J7.816 E.08251
G3 X91.436 Y125.548 I2.419 J1.173 E.05122
G3 X93.349 Y124.413 I15.952 J24.706 E.07381
G2 X98.06 Y120.701 I-8.564 J-15.715 E.1999
G2 X100.325 Y117.807 I-37.421 J-31.616 E.12194
G3 X101.394 Y116.758 I3.536 J2.535 E.04994
G3 X103.044 Y116.197 I3.008 J6.141 E.05795
G2 X106.576 Y115.257 I-6.546 J-31.734 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18843
G3 X113.513 Y111.136 I14.726 J18.745 E.0804
G3 X115.144 Y110.777 I1.449 J2.7 E.05613
G3 X117.853 Y110.909 I-7.764 J188.183 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.104 J28.238 E.09117
G3 X128.106 Y108.866 I.643 J2.567 E.02518
G3 X129.665 Y109.259 I-.645 J5.843 E.05352
G2 X133.389 Y110.477 I12.288 J-31.261 E.13004
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.773 E.08329
G3 X142.68 Y111.256 I-.086 J2.683 E.05114
G3 X144.474 Y112.538 I-15.375 J23.407 E.07316
G2 X149.428 Y115.257 I11.081 J-14.314 E.18823
G2 X152.965 Y116.193 I9.84 J-30.042 E.12145
G3 X154.569 Y116.731 I-1.274 J6.462 E.05628
G3 X155.674 Y117.809 I-2.428 J3.593 E.0515
G2 X157.946 Y120.702 I41.952 J-30.604 E.12203
G2 X162.421 Y124.276 I12.715 J-11.333 E.19089
G3 X164.757 Y125.673 I-13.539 J25.286 E.09033
G3 X165.746 Y127.013 I-1.782 J2.349 E.05599
G3 X166.938 Y130.091 I-683.985 J266.718 E.1095
G2 X170.649 Y135.623 I16.057 J-6.761 E.22233
G3 X172.333 Y137.457 I-17.046 J17.339 E.08262
G3 X172.913 Y139.008 I-2.311 J1.749 E.05572
G1 X172.943 Y139.264 E.00854
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.958 Y137.896 I5.223 J.195 E.05069
G3 X83.717 Y136.795 I3.877 J1.861 E.04126
G2 X85.862 Y134.489 I-444.928 J-416.081 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.435 J7.863 E.07788
G3 X91.212 Y125.225 I2.761 J1.35 E.0533
G3 X93.152 Y124.073 I16.135 J24.96 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.017 Y117.563 I-37.345 J-31.531 E.1123
G3 X101.193 Y116.421 I3.821 J2.758 E.05062
G3 X102.951 Y115.816 I3.187 J6.404 E.05729
G2 X106.448 Y114.887 I-6.458 J-31.366 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.852 J18.915 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.448 J182.378 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.216 J33.916 E.07783
G3 X128.132 Y108.474 I1.009 J3.266 E.03485
G3 X129.794 Y108.889 I-.666 J6.211 E.05279
G2 X133.154 Y110.014 I13.006 J-33.249 E.10893
G2 X138.707 Y110.489 I4.211 J-16.533 E.17203
G3 X141.261 Y110.387 I2.31 J25.879 E.07855
G3 X142.885 Y110.921 I-.109 J3.067 E.05323
G3 X144.706 Y112.222 I-15.537 J23.681 E.06878
G2 X149.556 Y114.887 I10.852 J-14.005 E.17076
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.77 Y116.394 I-1.342 J6.764 E.05576
G3 X155.981 Y117.565 I-2.617 J3.917 E.05203
G2 X158.239 Y120.441 I41.909 J-30.57 E.11239
G2 X162.618 Y123.937 I12.423 J-11.074 E.173
G3 X164.784 Y125.21 I-16.309 J30.216 E.07721
G3 X166.104 Y126.854 I-1.828 J2.82 E.06591
G3 X167.3 Y129.94 I-598.467 J233.65 E.10168
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.229 J17.514 E.07791
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.399 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X159.92 Y140.129 Z1.4 F36000
G1 X167.596 Y132.21 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X168.477 Y133.578 I20.562 J-12.27 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X125.341 Y109.989 E1.62449
G3 X127.87 Y109.214 I5.185 J12.405 E.0879
G3 X130.658 Y109.99 I-.974 J8.891 E.09642
G1 X96.032 Y144.616 E1.62438
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.857 J-11.786 E.054
G1 X102.064 Y142.685 F36000
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.253 J11.56 E.05397
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.926 J1.552 E.0865
G3 X93.83 Y124.534 I9.842 J12.99 E.10129
G1 X100.227 Y130.931 E.30011
G2 X100.011 Y132.961 I2.293 J1.27 E.06954
G1 X90.708 Y142.264 E.43643
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.13381
G2 X83.434 Y139.05 I1.842 J1.488 E.04916
G1 X85.385 Y139.911 E.07073
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.699 E.05406
G1 X126.65 Y123.933 F36000
G1 F15476.087
G3 X125.587 Y122.737 I1.353 J-2.273 E.05391
G1 X119.326 Y128.997 E.29368
G3 X120.891 Y128.567 I10.051 J33.499 E.05383
G1 X107.571 Y115.247 E.62487
G2 X112.36 Y112.361 I-8.189 J-19.003 E.18607
G1 X127.713 Y127.714 E.72024
G3 X128.286 Y127.714 I.288 J8.198 E.019
G1 X143.645 Y112.355 E.7205
G2 X148.43 Y115.246 I12.871 J-15.901 E.18603
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.448 J33.816 E.05372
G1 X130.416 Y122.741 E.29341
G3 X129.352 Y123.934 I-2.414 J-1.081 E.05391
G1 X140.386 Y111.134 F36000
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.382 E.05407
G1 X170.616 Y139.912 E1.34273
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.418 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X155.992 Y132.965 E.43628
G2 X155.776 Y130.928 I-2.877 J-.724 E.06937
G1 X162.172 Y124.532 E.30006
G3 X164.985 Y126.364 I-5.412 J11.382 E.11169
G3 X165.932 Y128.447 I-10.7 J6.124 E.07603
G1 X153.083 Y141.297 E.6028
G3 X153.939 Y142.682 I-19.41 J12.954 E.05402
; WIPE_START
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
; WIPE_END
G1 E-.04 F1800
G1 X145.934 Y139.212 Z1.4 F36000
G1 X113.77 Y131.309 Z1.4
G1 Z1
G1 E.8 F1800
G1 F15476.087
G3 X115.224 Y130.576 I15.769 J29.459 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.778 I1.391 J2.462 E.03858
G3 X98.118 Y121.146 I-32.799 J-23.329 E.14281
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.739 J27.781 E.18055
G1 X103.82 Y134.524 E.11678
G2 X103.304 Y129.668 I-1.313 J-2.316 E.20502
G1 X122.015 Y110.957 E.87778
G3 X118.944 Y111.268 I-4.388 J-27.981 E.10243
G1 X126.919 Y119.244 E.37413
G3 X129.082 Y119.242 I1.083 J2.439 E.07387
G1 X137.055 Y111.268 E.37406
G3 X133.984 Y110.956 I1.33 J-28.347 E.10248
G1 X152.697 Y129.669 E.87789
G2 X152.182 Y134.522 I.801 J2.539 E.20476
M73 P53 R9
G1 X149.693 Y137.011 E.11675
G2 X145.602 Y133.425 I-22.559 J21.615 E.18067
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.324 I24.844 J-22.131 E.11975
G2 X154.34 Y117.012 I-5.151 J3.787 E.06132
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.34 J30.252 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
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
G1 X125.713 Y121.42
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.715 Y121.395 E.00084
G3 X127.826 Y119.362 I2.284 J.26 E.10542
G3 X130.055 Y120.626 I.176 J2.287 E.09019
G3 X125.702 Y121.747 I-2.056 J1.029 E.27192
G1 X125.711 Y121.48 E.00886
G1 X126.107 Y121.425 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.162 Y121.153 E.00852
G3 X127.856 Y119.754 I1.841 J.504 E.07195
G1 X128.149 Y119.754 E.00899
G3 X126.102 Y121.485 I-.146 J1.903 E.27712
; WIPE_START
M204 S10000
G1 X126.162 Y121.153 E-.12805
G1 X126.259 Y120.878 E-.11112
G1 X126.364 Y120.685 E-.08327
G1 X126.576 Y120.388 E-.13877
G1 X126.787 Y120.185 E-.11117
G1 X127.026 Y120.017 E-.11115
G1 X127.206 Y119.928 E-.07646
; WIPE_END
G1 E-.04 F1800
G1 X120.146 Y122.827 Z1.6 F36000
G1 X102.855 Y129.927 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.07 Y129.967 E.00724
G3 X103.309 Y130.035 I-.562 J2.419 E.00826
G1 X103.408 Y130.066 E.00343
G3 X102.37 Y129.906 I-.861 J2.134 E.44446
G3 X102.722 Y129.912 I.138 J2.48 E.01169
G1 X102.796 Y129.92 E.00245
G1 X102.423 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.692 Y130.303 E.00828
G3 X103.191 Y130.409 I-.178 J2.061 E.0157
G1 X103.261 Y130.431 E.00226
G3 X102.363 Y130.301 I-.714 J1.77 E.34033
; WIPE_START
M204 S10000
G1 X102.692 Y130.303 E-.12506
G1 X102.982 Y130.343 E-.11106
G1 X103.191 Y130.409 E-.08328
G1 X103.261 Y130.431 E-.02791
G1 X103.523 Y130.561 E-.11111
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11113
G1 X104.099 Y131.098 E-.07927
; WIPE_END
G1 E-.04 F1800
G1 X111.731 Y131.175 Z1.6 F36000
G1 X155.684 Y131.618 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.741 Y131.94 E.01085
G3 X155.732 Y132.539 I-2.289 J.265 E.01994
G3 X153.282 Y129.906 I-2.274 J-.34 E.34229
G3 X155.665 Y131.561 I.17 J2.298 E.1041
G1 X155.289 Y131.665 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.3 Y131.697 E.00104
G3 X153.312 Y130.298 I-1.841 J.505 E.28767
G3 X154.102 Y130.409 I.114 J2.066 E.02468
G1 X154.172 Y130.431 E.00226
G3 X155.201 Y131.422 I-.714 J1.771 E.04498
G1 X155.269 Y131.609 E.0061
; WIPE_START
M204 S10000
G1 X155.3 Y131.697 E-.03565
G1 X155.356 Y131.984 E-.11112
G1 X155.367 Y132.276 E-.11113
G1 X155.342 Y132.494 E-.08329
G1 X155.256 Y132.849 E-.13878
G1 X155.137 Y133.116 E-.11116
G1 X154.978 Y133.362 E-.11115
G1 X154.877 Y133.475 E-.05772
; WIPE_END
G1 E-.04 F1800
G1 X155.28 Y141.097 Z1.6 F36000
G1 X155.589 Y146.934 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.972 J3.757 E.05162
G2 X86.79 Y133.985 I-24.732 J-24.818 E.1193
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18944
G3 X90.41 Y126.674 I23.307 J7.817 E.0825
G3 X91.436 Y125.548 I2.42 J1.173 E.05123
G3 X93.349 Y124.413 I15.965 J24.728 E.07381
G2 X98.06 Y120.701 I-8.564 J-15.715 E.1999
G2 X100.325 Y117.806 I-37.431 J-31.624 E.12196
G3 X101.394 Y116.758 I3.535 J2.535 E.04992
G3 X103.044 Y116.197 I3.009 J6.144 E.05796
G2 X106.577 Y115.257 I-6.546 J-31.734 E.12132
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18842
G3 X113.513 Y111.136 I14.722 J18.74 E.0804
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.766 J188.209 E.08995
G2 X124.754 Y109.831 I.851 J-17.19 E.2333
G3 X127.354 Y108.943 I11.101 J28.23 E.09118
G3 X128.106 Y108.866 I.66 J2.731 E.02517
G3 X129.666 Y109.259 I-.645 J5.845 E.05352
G2 X133.389 Y110.477 I12.289 J-31.263 E.13004
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.76 E.08329
G3 X142.68 Y111.256 I-.086 J2.682 E.05112
G3 X144.474 Y112.538 I-15.359 J23.386 E.07318
G2 X149.428 Y115.257 I11.08 J-14.314 E.18822
G2 X152.966 Y116.193 I9.84 J-30.045 E.12146
G3 X154.57 Y116.731 I-1.274 J6.462 E.05627
G3 X155.674 Y117.809 I-2.603 J3.771 E.05145
G2 X157.946 Y120.702 I41.976 J-30.622 E.12202
G2 X162.421 Y124.276 I12.716 J-11.334 E.1909
G3 X164.758 Y125.673 I-13.537 J25.282 E.09034
G3 X165.746 Y127.012 I-1.781 J2.348 E.05596
G3 X166.938 Y130.091 I-672.88 J262.428 E.10954
G2 X170.649 Y135.623 I16.058 J-6.761 E.22232
G3 X172.333 Y137.457 I-17.058 J17.35 E.08262
G3 X172.913 Y139.008 I-2.312 J1.749 E.05572
G1 X172.943 Y139.264 E.00854
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.957 Y137.898 I5.229 J.196 E.05062
G3 X83.717 Y136.795 I3.873 J1.856 E.04132
G2 X85.862 Y134.489 I-445.522 J-416.633 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.434 J7.863 E.07788
G3 X91.212 Y125.225 I2.762 J1.35 E.0533
G3 X93.152 Y124.073 I16.131 J24.954 E.06935
G2 X97.766 Y120.441 I-8.371 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.352 J-31.537 E.11231
G3 X101.193 Y116.421 I3.821 J2.757 E.0506
G3 X102.951 Y115.816 I3.188 J6.405 E.0573
G2 X106.448 Y114.887 I-6.459 J-31.367 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.857 J18.921 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05819
G3 X117.867 Y110.517 I-7.449 J182.402 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.211 J33.904 E.07783
G3 X128.132 Y108.474 I.997 J3.178 E.03486
G3 X129.794 Y108.889 I-.666 J6.211 E.0528
G2 X133.154 Y110.014 I13.009 J-33.259 E.10893
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.874 E.07855
G3 X142.884 Y110.921 I-.109 J3.067 E.05322
G3 X144.706 Y112.222 I-15.536 J23.681 E.06879
G2 X149.556 Y114.887 I10.852 J-14.004 E.17075
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.77 Y116.394 I-1.342 J6.763 E.05577
G3 X155.765 Y117.301 I-2.182 J3.392 E.04156
G2 X157.819 Y119.952 I1376.841 J-1064.516 E.10304
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.312 J30.223 E.07722
G3 X166.104 Y126.853 I-1.827 J2.819 E.06587
G3 X167.3 Y129.94 I-591.257 J230.867 E.10171
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.233 J17.518 E.07791
G3 X173.302 Y138.956 I-2.618 J1.981 E.05776
G3 X173.36 Y139.508 I-10.392 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z1.6 F36000
G1 Z1.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.266 J11.569 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.785 Y126.148 I-5.897 J1.507 E.08587
G2 X164.137 Y125.671 I-2.778 J3.095 E.02674
G1 X162.175 Y124.529 E.07533
G1 X155.776 Y130.928 E.30018
G1 X155.817 Y131.004 E.00286
G3 X155.992 Y132.965 I-2.371 J1.2 E.06691
G1 X165.292 Y142.265 E.43628
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.908 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34273
G2 X140.386 Y111.134 I-1.124 J3.225 E.05407
G1 X129.352 Y123.934 F36000
G1 F15476.087
G2 X130.416 Y122.741 I-1.349 J-2.275 E.05391
G1 X136.671 Y128.995 E.29341
G2 X135.109 Y128.566 I-10.009 J33.387 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.645 Y112.355 I8.085 J-18.79 E.18603
G1 X128.286 Y127.714 E.7205
G2 X127.713 Y127.714 I-.285 J8.198 E.019
G1 X112.36 Y112.361 E.72024
G3 X107.571 Y115.247 I-12.977 J-16.115 E.18607
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.486 J33.929 E.05383
G1 X125.587 Y122.737 E.29368
G2 X126.65 Y123.933 I2.416 J-1.078 E.05391
G1 X115.627 Y111.14 F36000
G1 F15476.087
G2 X114.015 Y111.281 I-.476 J3.838 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.365 J.127 E.04916
G1 X86.809 Y140.541 E.1338
G1 X90.708 Y142.264 E.14141
G1 X100.011 Y132.961 E.43643
G3 X100.227 Y130.931 I2.494 J-.761 E.06956
G1 X93.83 Y124.534 E.30011
G2 X90.988 Y126.402 I5.507 J11.475 E.11314
G2 X90.068 Y128.448 I10.571 J5.981 E.07454
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.046 J23.848 E.05401
G1 X88.404 Y132.211 F36000
G1 F15476.087
G3 X87.525 Y133.581 I-17.706 J-10.397 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.658 Y109.99 E1.62438
G2 X128.083 Y109.214 I-4.125 J9.026 E.08948
G2 X126.631 Y109.521 I.298 J4.998 E.0494
G1 X125.341 Y109.989 E.04555
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.25 J-12.711 E.054
; WIPE_START
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
; WIPE_END
G1 E-.04 F1800
G1 X160.618 Y133.101 Z1.6 F36000
G1 X142.231 Y131.307 Z1.6
G1 Z1.2
G1 E.8 F1800
G1 F15476.087
G2 X140.777 Y130.574 I-15.8 J29.531 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.633 Y118.324 I-3.859 J5.1 E.06133
G2 X157.884 Y121.144 I27.088 J-19.305 E.11974
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-18.114 J24.796 E.18067
G1 X152.182 Y134.522 E.11675
G3 X152.697 Y129.669 I1.278 J-2.318 E.20594
G1 X133.984 Y110.956 E.87789
G2 X137.055 Y111.268 I4.403 J-28.042 E.10248
G1 X129.082 Y119.242 E.37405
G2 X126.919 Y119.244 I-1.079 J2.441 E.07387
G1 X118.944 Y111.268 E.37413
G2 X122.015 Y110.957 I-1.316 J-28.286 E.10243
G1 X103.304 Y129.668 E.87778
G1 X103.414 Y129.703 E.00384
G3 X103.82 Y134.524 I-.87 J2.501 E.20236
G1 X106.309 Y137.013 E.11678
G3 X110.399 Y133.428 I22.212 J21.213 E.18067
G1 X98.118 Y121.146 E.57613
G2 X100.796 Y117.779 I-30.118 J-26.695 E.1428
G3 X101.665 Y117.017 I2.261 J1.702 E.03859
G1 X115.224 Y130.576 E.6361
G2 X113.77 Y131.309 I14.318 J30.196 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X115.224 Y130.576 E-.61863
G1 X114.961 Y130.313 E-.14137
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
G1 X125.719 Y121.37
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.784 Y121.049 E.01084
G3 X127.826 Y119.362 I2.219 J.606 E.09365
G3 X128.755 Y119.488 I.138 J2.474 E.03129
G1 X128.864 Y119.522 E.00378
G3 X125.713 Y121.429 I-.861 J2.133 E.33788
G1 X126.106 Y121.429 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.162 Y121.153 E.00863
G3 X127.856 Y119.754 I1.841 J.503 E.07194
G3 X128.637 Y119.862 I.114 J2.058 E.02436
G1 X128.717 Y119.887 E.00258
G3 X126.102 Y121.488 I-.714 J1.77 E.25898
; WIPE_START
M204 S10000
G1 X126.162 Y121.153 E-.12928
G1 X126.259 Y120.878 E-.1111
G1 X126.399 Y120.621 E-.11116
G1 X126.576 Y120.388 E-.11115
G1 X126.787 Y120.185 E-.11117
G1 X127.026 Y120.017 E-.11115
G1 X127.203 Y119.929 E-.07499
; WIPE_END
G1 E-.04 F1800
G1 X120.111 Y122.752 Z1.8 F36000
G1 X101.92 Y129.992 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.022 Y129.96 E.00352
G3 X102.37 Y129.906 I.526 J2.239 E.01171
G3 X103.299 Y130.032 I.138 J2.473 E.03129
G1 X103.408 Y130.066 E.00378
G3 X101.685 Y130.067 I-.861 J2.133 E.42082
G1 X101.863 Y130.01 E.0062
G1 X102.417 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.692 Y130.303 E.00845
G3 X103.181 Y130.406 I-.178 J2.054 E.01538
G1 X103.261 Y130.431 E.00258
G3 X102.358 Y130.302 I-.714 J1.769 E.33999
; WIPE_START
M204 S10000
G1 X102.692 Y130.303 E-.12714
G1 X102.982 Y130.343 E-.11106
G1 X103.181 Y130.406 E-.07932
G1 X103.261 Y130.431 E-.03186
G1 X103.523 Y130.561 E-.11112
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11113
G1 X104.096 Y131.094 E-.07719
; WIPE_END
G1 E-.04 F1800
G1 X111.728 Y131.171 Z1.8 F36000
G1 X155.685 Y131.618 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.744 Y131.939 E.01084
G3 X153.282 Y129.906 I-2.286 J.26 E.36239
G3 X154.211 Y130.032 I.138 J2.473 E.03129
G1 X154.319 Y130.066 E.00378
G3 X155.668 Y131.56 I-.861 J2.133 E.0691
G1 X155.292 Y131.672 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.299 Y131.697 E.00081
G3 X153.312 Y130.298 I-1.84 J.503 E.28738
G3 X154.092 Y130.406 I.114 J2.058 E.02436
G1 X154.172 Y130.431 E.00258
G3 X155.2 Y131.422 I-.714 J1.769 E.04497
G1 X155.271 Y131.616 E.00633
; WIPE_START
M204 S10000
G1 X155.299 Y131.697 E-.03278
G1 X155.356 Y131.984 E-.11109
G1 X155.367 Y132.276 E-.11113
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11114
G1 X155.137 Y133.116 E-.11116
G1 X154.978 Y133.362 E-.11114
G1 X154.872 Y133.48 E-.06037
; WIPE_END
G1 E-.04 F1800
G1 X155.278 Y141.102 Z1.8 F36000
G1 X155.589 Y146.934 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.6296
G3 X83.411 Y137.866 I3.58 J.167 E.04815
G3 X84.377 Y136.65 I5.974 J3.759 E.05161
G2 X86.79 Y133.986 I-24.737 J-24.822 E.11928
G2 X89.501 Y128.988 I-13.843 J-10.746 E.18946
G3 X90.41 Y126.674 I23.313 J7.819 E.08251
G3 X91.436 Y125.548 I2.419 J1.173 E.05122
G3 X93.349 Y124.413 I15.94 J24.687 E.07381
G2 X98.059 Y120.702 I-8.564 J-15.715 E.19987
G2 X100.325 Y117.806 I-37.407 J-31.607 E.12198
G3 X101.384 Y116.764 I3.552 J2.549 E.04953
G3 X103.044 Y116.197 I3.003 J6.076 E.05835
G2 X106.577 Y115.257 I-6.543 J-31.725 E.12133
G2 X111.534 Y112.534 I-5.975 J-16.748 E.18842
G3 X113.513 Y111.136 I14.726 J18.746 E.0804
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.765 J188.201 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.104 J28.24 E.09116
G3 X128.106 Y108.866 I.66 J2.729 E.02518
G3 X129.665 Y109.259 I-.645 J5.844 E.05351
G2 X133.389 Y110.477 I12.29 J-31.267 E.13004
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.765 E.08329
G3 X142.68 Y111.256 I-.085 J2.681 E.05113
G3 X144.474 Y112.538 I-15.385 J23.421 E.07317
G2 X149.427 Y115.257 I11.081 J-14.314 E.18821
G2 X152.965 Y116.193 I9.836 J-30.026 E.12146
G3 X154.57 Y116.731 I-1.273 J6.461 E.05629
G3 X155.674 Y117.809 I-2.603 J3.771 E.05146
G2 X157.946 Y120.702 I41.961 J-30.61 E.12202
G2 X162.421 Y124.276 I12.715 J-11.334 E.19089
G3 X164.758 Y125.674 I-13.525 J25.261 E.09035
G3 X165.746 Y127.012 I-1.782 J2.348 E.05594
G3 X166.938 Y130.092 I-678.328 J264.537 E.10954
M73 P54 R9
G2 X170.649 Y135.623 I16.058 J-6.762 E.22231
G3 X172.333 Y137.457 I-17.051 J17.343 E.08263
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.956 Y137.9 I5.235 J.197 E.05056
G3 X83.717 Y136.795 I3.87 J1.851 E.04139
G2 X85.862 Y134.489 I-442.595 J-413.913 E.09676
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.438 J7.864 E.07788
G3 X91.213 Y125.225 I2.762 J1.35 E.05331
G3 X93.152 Y124.073 I16.13 J24.953 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.342 J-31.528 E.11231
G3 X101.182 Y116.428 I3.837 J2.771 E.0502
G3 X102.951 Y115.816 I3.183 J6.339 E.0577
G2 X106.448 Y114.887 I-6.458 J-31.362 E.11124
G2 X111.301 Y112.219 I-5.849 J-16.383 E.1709
G3 X113.32 Y110.795 I14.854 J18.916 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05819
G3 X117.867 Y110.517 I-7.449 J182.394 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.208 J33.895 E.07784
G3 X128.132 Y108.474 I.997 J3.178 E.03485
G3 X129.794 Y108.889 I-.665 J6.21 E.0528
G2 X133.154 Y110.014 I13.01 J-33.262 E.10893
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.879 E.07855
G3 X142.885 Y110.921 I-.108 J3.066 E.05323
G3 X144.706 Y112.222 I-15.54 J23.686 E.06879
G2 X149.556 Y114.887 I10.852 J-14.004 E.17075
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.77 Y116.394 I-1.342 J6.762 E.05577
G3 X155.765 Y117.301 I-2.181 J3.391 E.04156
G2 X157.819 Y119.952 I1381.754 J-1068.325 E.10304
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.305 J30.21 E.07721
G3 X166.104 Y126.854 I-1.827 J2.82 E.06589
G3 X167.3 Y129.94 I-591.337 J230.896 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.232 J17.517 E.07791
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.395 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38731
G1 X154.608 Y145.61 E-.07071
; WIPE_END
G1 E-.04 F1800
G1 X159.92 Y140.129 Z1.8 F36000
G1 X167.597 Y132.209 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X168.477 Y133.578 I19.141 J-11.35 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X125.341 Y109.989 E1.62449
G3 X127.862 Y109.215 I5.242 J12.575 E.08763
G3 X129.051 Y109.422 I-.015 J3.597 E.04025
G1 X130.658 Y109.99 E.05652
G1 X96.032 Y144.616 E1.62438
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.827 J-11.767 E.054
G1 X102.064 Y142.685 F36000
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.25 J11.558 E.05398
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.925 J1.551 E.0865
G3 X93.83 Y124.534 I9.842 J12.99 E.10128
G1 X100.227 Y130.931 E.30011
G2 X100.011 Y132.961 I2.282 J1.269 E.06956
G1 X90.708 Y142.264 E.43643
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.1338
G2 X83.434 Y139.05 I1.842 J1.488 E.04916
G1 X85.385 Y139.911 E.07073
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.701 E.05406
G1 X126.65 Y123.933 F36000
G1 F15476.087
G3 X125.587 Y122.737 I1.352 J-2.273 E.05391
G1 X119.326 Y128.997 E.29368
G3 X120.891 Y128.567 I10.051 J33.499 E.05383
G1 X107.571 Y115.247 E.62487
G2 X112.36 Y112.361 I-8.189 J-19.004 E.18607
G1 X127.713 Y127.714 E.72024
G3 X128.286 Y127.714 I.288 J8.198 E.019
G1 X143.645 Y112.355 E.7205
G2 X148.43 Y115.246 I12.87 J-15.899 E.18603
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.448 J33.816 E.05372
G1 X130.416 Y122.741 E.29341
G3 X129.352 Y123.934 I-2.414 J-1.081 E.05391
G1 X140.386 Y111.134 F36000
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.382 E.05407
G1 X170.616 Y139.912 E1.34273
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.419 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X155.992 Y132.965 E.43628
G2 X155.776 Y130.928 I-2.538 J-.76 E.06976
G1 X162.172 Y124.532 E.30006
G3 X164.985 Y126.364 I-5.41 J11.379 E.11169
G3 X165.932 Y128.447 I-10.692 J6.121 E.07602
G1 X153.083 Y141.297 E.6028
G3 X153.939 Y142.682 I-19.41 J12.954 E.05402
; WIPE_START
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
; WIPE_END
G1 E-.04 F1800
G1 X145.934 Y139.212 Z1.8 F36000
G1 X113.77 Y131.309 Z1.8
G1 Z1.4
G1 E.8 F1800
G1 F15476.087
G3 X115.224 Y130.576 I15.772 J29.463 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.779 I1.395 J2.466 E.03859
G3 X98.118 Y121.147 I-32.815 J-23.343 E.1428
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.74 J27.782 E.18055
G1 X103.82 Y134.524 E.11678
G2 X103.304 Y129.668 I-1.275 J-2.32 E.2062
G1 X122.015 Y110.957 E.87778
G3 X118.944 Y111.268 I-4.387 J-27.976 E.10243
G1 X126.919 Y119.244 E.37413
G3 X129.082 Y119.242 I1.083 J2.439 E.07387
G1 X137.055 Y111.268 E.37406
G3 X133.984 Y110.956 I1.331 J-28.349 E.10248
G1 X152.697 Y129.669 E.87789
G2 X152.182 Y134.522 I.762 J2.535 E.20594
G1 X149.693 Y137.011 E.11675
G2 X145.602 Y133.425 I-22.7 J21.776 E.18066
G1 X157.884 Y121.144 E.57615
G3 X155.634 Y118.324 I24.841 J-22.128 E.11974
G2 X154.34 Y117.012 I-5.153 J3.788 E.06133
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.346 J30.264 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
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
G1 X125.719 Y121.369
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.784 Y121.049 E.01083
G3 X127.826 Y119.362 I2.219 J.606 E.09365
G3 X128.404 Y119.397 I.176 J1.89 E.0193
G1 X128.527 Y119.416 E.00413
G3 X125.713 Y121.429 I-.525 J2.24 E.34953
G1 X126.106 Y121.432 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.162 Y121.153 E.00873
G3 X127.856 Y119.754 I1.84 J.503 E.07194
G3 X128.345 Y119.784 I.146 J1.597 E.0151
G1 X128.438 Y119.799 E.0029
G3 X126.102 Y121.492 I-.435 J1.857 E.26781
; WIPE_START
M204 S10000
G1 X126.162 Y121.153 E-.13055
G1 X126.259 Y120.878 E-.1111
G1 X126.399 Y120.621 E-.11116
G1 X126.576 Y120.388 E-.11115
G1 X126.787 Y120.185 E-.11117
G1 X127.026 Y120.017 E-.11115
G1 X127.2 Y119.931 E-.07372
; WIPE_END
G1 E-.04 F1800
G1 X120.136 Y122.822 Z2 F36000
G1 X102.799 Y129.918 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.072 Y129.959 E.00914
G3 X100.259 Y132.415 I-.523 J2.24 E.33497
G3 X102.37 Y129.906 I2.3 J-.207 E.12096
G3 X102.723 Y129.906 I.179 J2.294 E.01171
G1 X102.74 Y129.909 E.00058
G1 X102.412 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.692 Y130.303 E.00862
G3 X103.171 Y130.403 I-.178 J2.047 E.01506
G1 X103.261 Y130.431 E.0029
G3 X102.352 Y130.303 I-.714 J1.769 E.33985
; WIPE_START
M204 S10000
G1 X102.692 Y130.303 E-.1293
G1 X102.982 Y130.343 E-.11106
G1 X103.171 Y130.403 E-.07537
G1 X103.261 Y130.431 E-.03582
G1 X103.523 Y130.561 E-.11112
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11113
G1 X104.093 Y131.089 E-.07504
; WIPE_END
G1 E-.04 F1800
G1 X111.725 Y131.16 Z2 F36000
G1 X155.671 Y131.568 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.672 Y131.595 E.00088
G3 X155.734 Y132.518 I-2.224 J.613 E.03091
G3 X153.282 Y129.906 I-2.277 J-.32 E.34291
G3 X155.553 Y131.264 I.166 J2.301 E.09349
G1 X155.649 Y131.512 E.00883
G1 X155.294 Y131.68 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.299 Y131.697 E.00057
G3 X153.312 Y130.298 I-1.84 J.503 E.28738
G3 X154.083 Y130.403 I.114 J2.052 E.02404
G1 X154.172 Y130.431 E.0029
G3 X155.2 Y131.422 I-.714 J1.769 E.04497
G1 X155.274 Y131.623 E.00657
; WIPE_START
M204 S10000
G1 X155.299 Y131.697 E-.02984
G1 X155.356 Y131.984 E-.11109
G1 X155.367 Y132.276 E-.11113
G1 X155.345 Y132.473 E-.07538
G1 X155.256 Y132.849 E-.14663
G1 X155.137 Y133.116 E-.11116
G1 X154.978 Y133.362 E-.11114
G1 X154.866 Y133.486 E-.06362
; WIPE_END
G1 E-.04 F1800
G1 X155.276 Y141.108 Z2 F36000
G1 X155.589 Y146.934 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.722 E2.35647
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.865 I3.579 J.167 E.04816
G3 X84.377 Y136.65 I5.977 J3.762 E.0516
G2 X86.79 Y133.986 I-24.731 J-24.818 E.11929
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.299 J7.813 E.08251
G3 X91.435 Y125.548 I2.42 J1.173 E.05122
G3 X93.349 Y124.413 I15.958 J24.717 E.07381
G2 X98.06 Y120.701 I-8.564 J-15.715 E.1999
G2 X100.325 Y117.806 I-37.417 J-31.613 E.12195
G3 X101.394 Y116.758 I3.535 J2.535 E.04993
G3 X103.043 Y116.197 I3.009 J6.144 E.05794
G2 X106.577 Y115.257 I-6.546 J-31.737 E.12134
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18842
G3 X113.513 Y111.136 I14.721 J18.739 E.08042
G3 X115.144 Y110.777 I1.449 J2.701 E.05612
G3 X117.853 Y110.909 I-7.765 J188.202 E.08995
G2 X124.754 Y109.831 I.851 J-17.19 E.2333
G3 X127.353 Y108.943 I11.104 J28.239 E.09116
G3 X128.107 Y108.866 I.66 J2.728 E.02519
G3 X129.665 Y109.259 I-.645 J5.843 E.0535
G2 X133.389 Y110.477 I12.289 J-31.263 E.13004
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.765 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.379 J23.413 E.07317
G2 X149.427 Y115.257 I11.081 J-14.315 E.18821
G2 X152.965 Y116.193 I9.838 J-30.034 E.12147
G3 X154.57 Y116.731 I-1.273 J6.46 E.05628
G3 X155.674 Y117.809 I-2.602 J3.771 E.05146
G2 X157.946 Y120.702 I41.97 J-30.617 E.12201
G2 X162.421 Y124.276 I12.715 J-11.333 E.1909
G3 X164.757 Y125.673 I-13.535 J25.278 E.09034
G3 X165.746 Y127.012 I-1.781 J2.348 E.05597
G3 X166.938 Y130.091 I-673.978 J262.852 E.10953
G2 X170.649 Y135.623 I16.058 J-6.761 E.22232
G3 X172.333 Y137.457 I-17.045 J17.338 E.08263
G3 X172.913 Y139.008 I-2.311 J1.749 E.05572
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.198 E2.17917
G1 X82.639 Y139.508 E.60452
G3 X82.955 Y137.902 I5.24 J.197 E.0505
G3 X83.717 Y136.795 I3.867 J1.846 E.04144
G2 X85.862 Y134.489 I-444.969 J-416.117 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.44 J7.865 E.07787
G3 X91.212 Y125.225 I2.762 J1.35 E.05331
G3 X93.152 Y124.073 I16.133 J24.957 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.333 J-31.521 E.1123
G3 X101.193 Y116.421 I3.821 J2.757 E.05062
G3 X102.951 Y115.816 I3.188 J6.405 E.05729
G2 X106.448 Y114.887 I-6.459 J-31.367 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.847 J18.907 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05817
G3 X117.867 Y110.517 I-7.449 J182.395 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.213 J33.909 E.07783
G3 X128.132 Y108.474 I.997 J3.178 E.03486
G3 X129.794 Y108.889 I-.666 J6.211 E.05279
G2 X133.154 Y110.014 I13.008 J-33.257 E.10893
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05323
G3 X144.706 Y112.222 I-15.54 J23.686 E.06878
G2 X149.556 Y114.887 I10.852 J-14.005 E.17075
G2 X153.057 Y115.812 I9.716 J-29.685 E.11132
G3 X154.77 Y116.394 I-1.342 J6.763 E.05576
G3 X155.764 Y117.3 I-2.181 J3.391 E.04153
G2 X157.819 Y119.952 I1396.984 J-1080.14 E.10307
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.317 J30.231 E.07721
G3 X166.104 Y126.854 I-1.827 J2.82 E.06588
G3 X167.3 Y129.94 I-591.337 J230.896 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.234 J17.519 E.07791
G3 X173.302 Y138.956 I-2.618 J1.981 E.05776
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z2 F36000
G1 Z1.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.245 J11.556 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.785 Y126.148 I-5.898 J1.507 E.08586
G2 X164.137 Y125.671 I-2.779 J3.096 E.02676
G1 X162.175 Y124.529 E.07531
G1 X155.776 Y130.928 E.30018
G3 X155.992 Y132.965 I-2.324 J1.277 E.06976
G1 X165.292 Y142.265 E.43628
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.907 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34273
G2 X140.386 Y111.134 I-1.124 J3.224 E.05407
G1 X129.352 Y123.934 F36000
G1 F15476.087
G2 X130.416 Y122.741 I-1.349 J-2.275 E.05391
G1 X136.671 Y128.995 E.29341
G2 X135.109 Y128.566 I-10.009 J33.387 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.645 Y112.355 I8.085 J-18.791 E.18603
G1 X128.286 Y127.714 E.7205
G2 X127.713 Y127.714 I-.285 J8.199 E.019
G1 X112.36 Y112.361 E.72024
G3 X107.571 Y115.247 I-12.978 J-16.117 E.18607
M73 P54 R8
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.486 J33.929 E.05383
G1 X125.587 Y122.737 E.29368
G2 X126.65 Y123.933 I2.416 J-1.078 E.05391
G1 X115.627 Y111.14 F36000
G1 F15476.087
M73 P55 R8
G2 X114.015 Y111.281 I-.475 J3.841 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.365 J.127 E.04916
G1 X86.809 Y140.541 E.13381
G1 X90.708 Y142.264 E.14141
G1 X100.011 Y132.961 E.43643
G3 X100.227 Y130.931 I2.54 J-.756 E.0695
G1 X93.83 Y124.534 E.30011
G2 X90.988 Y126.401 I5.508 J11.477 E.11313
G2 X90.068 Y128.448 I10.557 J5.975 E.07456
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.046 J23.848 E.05401
G1 X88.404 Y132.211 F36000
G1 F15476.087
G3 X87.525 Y133.581 I-17.706 J-10.397 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.658 Y109.99 E1.62438
G2 X128.083 Y109.214 I-4.127 J9.03 E.08947
G2 X126.631 Y109.521 I.296 J4.991 E.04941
G1 X125.341 Y109.989 E.04555
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.248 J-12.71 E.054
; WIPE_START
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
; WIPE_END
G1 E-.04 F1800
G1 X160.618 Y133.101 Z2 F36000
G1 X142.231 Y131.307 Z2
G1 Z1.6
G1 E.8 F1800
G1 F15476.087
G2 X140.777 Y130.574 I-15.8 J29.531 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.633 Y118.323 I-3.855 J5.096 E.06131
G2 X157.884 Y121.144 I27.095 J-19.311 E.11976
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-18.114 J24.796 E.18067
G1 X152.182 Y134.522 E.11675
G3 X152.697 Y129.669 I1.278 J-2.318 E.20594
G1 X133.984 Y110.956 E.87789
G2 X137.055 Y111.268 I4.402 J-28.037 E.10248
G1 X129.082 Y119.242 E.37406
G2 X126.919 Y119.244 I-1.079 J2.65 E.07357
G1 X118.944 Y111.268 E.37413
G2 X122.015 Y110.957 I-1.317 J-28.289 E.10243
G1 X103.304 Y129.668 E.87778
G1 X103.394 Y129.697 E.00315
G3 X103.82 Y134.524 I-.889 J2.511 E.20189
G1 X106.309 Y137.013 E.11678
G3 X110.399 Y133.428 I22.212 J21.213 E.18067
G1 X98.118 Y121.146 E.57613
G2 X100.796 Y117.779 I-30.116 J-26.694 E.14279
G3 X101.665 Y117.017 I2.261 J1.701 E.0386
G1 X115.224 Y130.576 E.6361
G2 X113.77 Y131.309 I14.318 J30.196 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X115.224 Y130.576 E-.61863
G1 X114.961 Y130.313 E-.14137
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
G1 X125.719 Y121.369
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.784 Y121.049 E.01082
G3 X127.826 Y119.362 I2.219 J.606 E.09365
G3 X128.735 Y119.482 I.138 J2.464 E.03059
G1 X128.864 Y119.522 E.00447
G3 X125.714 Y121.429 I-.861 J2.133 E.33789
G1 X126.105 Y121.436 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.162 Y121.154 E.00885
G3 X127.856 Y119.754 I1.84 J.503 E.07194
G3 X128.617 Y119.855 I.115 J2.046 E.02372
G1 X128.717 Y119.887 E.00322
G3 X126.102 Y121.495 I-.714 J1.769 E.25874
; WIPE_START
M204 S10000
G1 X126.162 Y121.154 E-.13177
G1 X126.259 Y120.878 E-.1111
G1 X126.349 Y120.712 E-.0714
G1 X126.576 Y120.388 E-.15056
G1 X126.787 Y120.185 E-.11117
G1 X127.026 Y120.017 E-.11115
G1 X127.198 Y119.932 E-.07285
; WIPE_END
G1 E-.04 F1800
G1 X120.107 Y122.755 Z2.2 F36000
G1 X101.976 Y129.975 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.022 Y129.96 E.00159
G3 X102.37 Y129.906 I.525 J2.24 E.01171
G1 X102.723 Y129.906 E.0117
G3 X101.685 Y130.067 I-.176 J2.294 E.44434
G1 X101.919 Y129.993 E.00812
G1 X102.406 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00881
G3 X102.346 Y130.303 I-.146 J1.902 E.35766
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13169
G1 X102.982 Y130.343 E-.11117
G1 X103.261 Y130.431 E-.11118
G1 X103.523 Y130.561 E-.11112
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11113
G1 X104.089 Y131.084 E-.07254
; WIPE_END
G1 E-.04 F1800
G1 X111.721 Y131.163 Z2.2 F36000
G1 X155.685 Y131.619 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.745 Y131.939 E.01082
G3 X153.282 Y129.906 I-2.287 J.262 E.36265
G1 X153.634 Y129.906 E.0117
G3 X155.669 Y131.561 I-.176 J2.295 E.09256
G1 X155.297 Y131.687 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.299 Y131.697 E.00033
G3 X153.312 Y130.298 I-1.841 J.504 E.2876
G1 X153.604 Y130.298 E.00899
G3 X155.201 Y131.422 I-.146 J1.903 E.06297
G1 X155.276 Y131.631 E.00681
; WIPE_START
M204 S10000
G1 X155.299 Y131.697 E-.02684
G1 X155.356 Y131.984 E-.11111
G1 X155.367 Y132.276 E-.11113
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11116
G1 X155.137 Y133.116 E-.11114
G1 X154.978 Y133.362 E-.11116
G1 X154.862 Y133.492 E-.06629
; WIPE_END
G1 E-.04 F1800
G1 X155.274 Y141.113 Z2.2 F36000
G1 X155.589 Y146.934 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.973 J3.758 E.0516
G2 X86.79 Y133.986 I-24.739 J-24.825 E.11929
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.338 J7.829 E.08249
G3 X91.436 Y125.548 I2.42 J1.174 E.05124
G3 X93.349 Y124.413 I15.968 J24.734 E.0738
G2 X98.06 Y120.701 I-8.564 J-15.715 E.1999
G2 X100.325 Y117.807 I-37.42 J-31.616 E.12194
G3 X101.394 Y116.757 I3.535 J2.534 E.04996
G3 X103.044 Y116.197 I3.009 J6.145 E.05794
G2 X106.577 Y115.257 I-6.546 J-31.736 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18842
G3 X113.513 Y111.136 I14.721 J18.739 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.765 J188.201 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.354 Y108.943 I11.096 J28.215 E.09117
G3 X128.106 Y108.866 I.66 J2.73 E.02518
G3 X129.665 Y109.259 I-.646 J5.845 E.0535
G2 X133.389 Y110.477 I12.289 J-31.263 E.13004
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.765 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.391 J23.429 E.07316
G2 X149.428 Y115.257 I11.082 J-14.315 E.18824
G2 X152.965 Y116.193 I9.838 J-30.038 E.12143
G3 X154.57 Y116.731 I-1.273 J6.462 E.0563
G3 X155.674 Y117.809 I-2.603 J3.772 E.05145
G2 X157.946 Y120.702 I41.969 J-30.617 E.12202
G2 X162.421 Y124.276 I12.715 J-11.333 E.1909
G3 X164.757 Y125.673 I-13.547 J25.299 E.09033
G3 X165.746 Y127.012 I-1.781 J2.348 E.05597
G3 X166.938 Y130.091 I-673.978 J262.852 E.10953
G2 X170.649 Y135.623 I16.058 J-6.761 E.22232
G3 X172.333 Y137.457 I-17.03 J17.324 E.08264
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00854
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.201 J.192 E.05095
G3 X83.717 Y136.795 I3.892 J1.884 E.041
G2 X85.862 Y134.489 I-444.791 J-415.955 E.09676
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.449 J7.868 E.07787
G3 X91.213 Y125.225 I2.763 J1.351 E.05332
G3 X93.152 Y124.073 I16.139 J24.969 E.06934
G2 X97.766 Y120.441 I-8.371 J-15.38 E.18129
G2 X100.017 Y117.563 I-37.323 J-31.513 E.11228
G3 X101.193 Y116.421 I3.822 J2.757 E.05064
G3 X102.951 Y115.816 I3.187 J6.405 E.05729
G2 X106.448 Y114.887 I-6.459 J-31.369 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.85 J18.912 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.449 J182.394 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.212 J33.905 E.07784
G3 X128.132 Y108.474 I.997 J3.178 E.03485
G3 X129.794 Y108.889 I-.666 J6.211 E.05279
G2 X133.154 Y110.014 I13.008 J-33.258 E.10893
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.879 E.07855
G3 X142.884 Y110.921 I-.11 J3.071 E.05322
G3 X144.706 Y112.222 I-15.539 J23.685 E.06879
G2 X149.556 Y114.887 I10.852 J-14.005 E.17075
G2 X153.056 Y115.812 I9.715 J-29.682 E.11131
G3 X154.77 Y116.394 I-1.342 J6.763 E.05578
G3 X155.765 Y117.301 I-2.18 J3.39 E.04154
G2 X157.819 Y119.952 I1363.934 J-1054.529 E.10307
G2 X162.618 Y123.937 I12.924 J-10.684 E.19279
G3 X164.784 Y125.21 I-16.314 J30.225 E.07723
G3 X166.104 Y126.854 I-1.827 J2.819 E.06587
G3 X167.3 Y129.94 I-591.337 J230.896 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.647 Y137.222 I-17.224 J17.51 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05775
G3 X173.36 Y139.508 I-10.397 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X159.92 Y140.129 Z2.2 F36000
G1 X167.597 Y132.209 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X168.477 Y133.578 I19.129 J-11.342 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X125.341 Y109.989 E1.62449
G3 X127.862 Y109.215 I5.238 J12.563 E.08763
G3 X129.051 Y109.422 I-.015 J3.597 E.04025
G1 X130.658 Y109.99 E.05651
G1 X96.032 Y144.616 E1.62438
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.827 J-11.767 E.054
G1 X102.064 Y142.685 F36000
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.25 J11.558 E.05398
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.925 J1.552 E.08651
G3 X93.83 Y124.534 I9.842 J12.991 E.10128
G1 X100.227 Y130.931 E.30011
G2 X100.011 Y132.961 I2.661 J1.309 E.06912
G1 X90.708 Y142.264 E.43643
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.13381
G2 X83.434 Y139.05 I1.841 J1.488 E.04916
G1 X85.385 Y139.911 E.07074
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.701 E.05406
G1 X126.65 Y123.933 F36000
G1 F15476.087
G3 X125.587 Y122.737 I1.352 J-2.273 E.05391
G1 X119.326 Y128.997 E.29368
G3 X120.891 Y128.567 I10.051 J33.499 E.05383
G1 X107.571 Y115.247 E.62487
G2 X112.36 Y112.361 I-8.188 J-19.002 E.18607
G1 X127.713 Y127.714 E.72024
G3 X128.286 Y127.714 I.288 J8.198 E.019
G1 X143.645 Y112.355 E.7205
G2 X148.43 Y115.246 I12.871 J-15.901 E.18603
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.445 J33.806 E.05372
G1 X130.416 Y122.741 E.29341
G3 X129.352 Y123.934 I-2.414 J-1.082 E.05391
G1 X140.386 Y111.134 F36000
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.38 E.05407
G1 X170.616 Y139.912 E1.34273
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.418 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X155.992 Y132.965 E.43628
G2 X155.776 Y130.928 I-2.874 J-.724 E.06938
G1 X162.172 Y124.532 E.30006
G3 X164.985 Y126.364 I-5.411 J11.38 E.11169
G3 X165.932 Y128.447 I-10.696 J6.123 E.07602
G1 X153.083 Y141.297 E.6028
G3 X153.939 Y142.682 I-19.41 J12.954 E.05402
; WIPE_START
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
; WIPE_END
G1 E-.04 F1800
G1 X145.934 Y139.212 Z2.2 F36000
G1 X113.77 Y131.309 Z2.2
G1 Z1.8
G1 E.8 F1800
G1 F15476.087
G3 X115.224 Y130.576 I15.769 J29.459 E.05401
G1 X101.665 Y117.017 E.63609
G2 X100.796 Y117.779 I1.392 J2.462 E.03859
G3 X98.118 Y121.146 I-32.79 J-23.322 E.1428
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.74 J27.782 E.18055
G1 X103.82 Y134.524 E.11678
G2 X103.304 Y129.668 I-1.313 J-2.316 E.20502
G1 X122.015 Y110.957 E.87778
G3 X118.944 Y111.268 I-4.387 J-27.978 E.10243
G1 X126.919 Y119.244 E.37413
G3 X129.082 Y119.242 I1.084 J2.753 E.07344
G1 X137.055 Y111.268 E.37405
G3 X133.984 Y110.956 I1.331 J-28.349 E.10248
G1 X152.697 Y129.669 E.87789
G2 X152.182 Y134.522 I.762 J2.535 E.20594
G1 X149.693 Y137.011 E.11676
G2 X145.602 Y133.425 I-25.031 J24.433 E.18062
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.323 I24.84 J-22.128 E.11975
G2 X154.34 Y117.012 I-5.151 J3.788 E.06132
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.346 J30.264 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
M73 P56 R8
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
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
G1 X125.719 Y121.369
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.785 Y121.05 E.0108
G3 X127.826 Y119.362 I2.216 J.603 E.09364
G3 X127.115 Y123.778 I.177 J2.294 E.27584
G3 X125.717 Y121.892 I.848 J-2.09 E.08192
G3 X125.715 Y121.428 I2.284 J-.239 E.01539
G1 X126.104 Y121.439 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.162 Y121.153 E.00896
G3 X127.856 Y119.754 I1.84 J.503 E.07194
G3 X128.324 Y119.781 I.146 J1.528 E.01446
G1 X128.438 Y119.799 E.00353
G3 X126.101 Y121.497 I-.435 J1.858 E.26765
; WIPE_START
M204 S10000
G1 X126.162 Y121.153 E-.13268
G1 X126.259 Y120.878 E-.1111
G1 X126.344 Y120.722 E-.06745
G1 X126.399 Y120.621 E-.04371
G1 X126.576 Y120.388 E-.11115
G1 X126.787 Y120.185 E-.11117
G1 X127.026 Y120.017 E-.11115
G1 X127.195 Y119.933 E-.07159
; WIPE_END
G1 E-.04 F1800
G1 X120.125 Y122.81 Z2.4 F36000
G1 X102.687 Y129.906 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.723 Y129.906 E.0012
G3 X102.37 Y129.906 I-.176 J2.297 E.46846
G1 X102.627 Y129.906 E.00851
G1 X102.398 Y130.299 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.4 Y130.298 E.00007
G1 X102.693 Y130.298 E.00899
G3 X102.111 Y130.343 I-.146 J1.905 E.35088
G1 X102.339 Y130.308 E.00708
; WIPE_START
M204 S10000
G1 X102.4 Y130.298 E-.02366
G1 X102.693 Y130.298 E-.11112
G1 X102.982 Y130.343 E-.11117
G1 X103.261 Y130.431 E-.11118
G1 X103.523 Y130.561 E-.11112
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11113
G1 X104.084 Y131.077 E-.06944
; WIPE_END
G1 E-.04 F1800
G1 X111.716 Y131.157 Z2.4 F36000
G1 X155.685 Y131.619 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.747 Y131.939 E.01081
G3 X153.282 Y129.906 I-2.289 J.264 E.36306
G1 X153.634 Y129.906 E.0117
G3 X155.671 Y131.561 I-.176 J2.297 E.09259
G1 X155.3 Y131.695 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.298 Y131.698 E.00011
G3 X153.312 Y130.298 I-1.84 J.502 E.2872
G1 X153.604 Y130.298 E.00899
G3 X155.199 Y131.423 I-.146 J1.901 E.06295
G1 X155.279 Y131.638 E.00706
; WIPE_START
M204 S10000
G1 X155.298 Y131.698 E-.02372
G1 X155.356 Y131.984 E-.11107
G1 X155.367 Y132.276 E-.11113
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11116
G1 X155.137 Y133.116 E-.11114
G1 X154.978 Y133.362 E-.11116
G1 X154.856 Y133.498 E-.06944
; WIPE_END
G1 E-.04 F1800
G1 X155.272 Y141.119 Z2.4 F36000
G1 X155.589 Y146.934 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.723 E2.35643
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.58 J.167 E.04814
G3 X84.377 Y136.65 I5.972 J3.757 E.05161
G2 X86.79 Y133.985 I-24.731 J-24.817 E.11931
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18944
G3 X90.41 Y126.674 I23.336 J7.828 E.08249
G3 X91.436 Y125.548 I2.421 J1.174 E.05124
G3 X93.349 Y124.413 I15.959 J24.718 E.07381
G2 X98.059 Y120.702 I-8.564 J-15.715 E.19987
G2 X100.325 Y117.807 I-37.4 J-31.601 E.12197
G3 X101.394 Y116.757 I3.536 J2.535 E.04994
G3 X103.044 Y116.197 I3.009 J6.144 E.05795
G2 X106.577 Y115.257 I-6.545 J-31.732 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.747 E.18842
G3 X113.513 Y111.136 I14.724 J18.743 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.766 J188.219 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.099 J28.224 E.09116
G3 X128.107 Y108.866 I.66 J2.729 E.0252
G3 X129.665 Y109.259 I-.646 J5.844 E.0535
G2 X133.389 Y110.477 I12.289 J-31.265 E.13004
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.765 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.373 J23.404 E.07315
G2 X149.428 Y115.257 I11.081 J-14.314 E.18824
G2 X152.965 Y116.193 I9.84 J-30.042 E.12145
G3 X154.57 Y116.731 I-1.273 J6.46 E.05628
G3 X155.675 Y117.81 I-2.604 J3.772 E.05147
G2 X157.946 Y120.702 I41.958 J-30.608 E.122
G2 X162.421 Y124.276 I12.716 J-11.334 E.1909
G3 X164.757 Y125.673 I-13.531 J25.272 E.09033
G3 X165.746 Y127.012 I-1.781 J2.349 E.05596
G3 X166.938 Y130.091 I-676.211 J263.717 E.10953
G2 X170.649 Y135.623 I16.058 J-6.762 E.22234
G3 X172.333 Y137.457 I-17.049 J17.341 E.0826
G3 X172.913 Y139.008 I-2.311 J1.749 E.05572
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.2 E2.17908
G1 X82.639 Y139.508 E.60452
G3 X82.954 Y137.905 I5.251 J.199 E.05038
G3 X83.717 Y136.795 I3.862 J1.838 E.04158
G2 X85.862 Y134.489 I-443.513 J-414.765 E.09676
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.447 J7.867 E.07787
G3 X91.212 Y125.225 I2.763 J1.351 E.05331
G3 X93.152 Y124.073 I16.126 J24.947 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.336 J-31.524 E.1123
G3 X101.193 Y116.421 I3.821 J2.758 E.05062
G3 X102.951 Y115.816 I3.187 J6.404 E.05729
G2 X106.448 Y114.887 I-6.458 J-31.364 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.382 E.1709
G3 X113.32 Y110.795 I14.855 J18.918 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.449 J182.411 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.207 J33.892 E.07783
G3 X128.132 Y108.474 I.997 J3.178 E.03486
G3 X129.794 Y108.889 I-.666 J6.21 E.05279
G2 X133.154 Y110.014 I13.009 J-33.261 E.10893
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05322
G3 X144.706 Y112.222 I-15.535 J23.678 E.06879
G2 X149.556 Y114.887 I10.852 J-14.004 E.17075
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.77 Y116.394 I-1.342 J6.763 E.05577
G3 X155.764 Y117.3 I-2.181 J3.391 E.04153
G2 X157.819 Y119.952 I1404.682 J-1086.108 E.10307
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.292 J30.188 E.07721
G3 X166.104 Y126.854 I-1.827 J2.82 E.06588
G3 X167.3 Y129.94 I-591.337 J230.896 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.229 J17.514 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z2.4 F36000
G1 Z2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.266 J11.569 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.652 J1.406 E.08776
G2 X162.172 Y124.532 I-25.074 J37.952 E.10006
G1 X155.776 Y130.928 E.30006
G1 X155.797 Y130.967 E.00148
G3 X155.992 Y132.965 I-2.698 J1.272 E.06791
G1 X165.292 Y142.265 E.43628
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.908 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34273
G2 X140.386 Y111.134 I-1.124 J3.224 E.05407
G1 X129.352 Y123.934 F36000
G1 F15476.087
G2 X130.416 Y122.741 I-1.349 J-2.275 E.05391
G1 X136.671 Y128.995 E.29341
G2 X135.109 Y128.566 I-10.009 J33.387 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.638 Y112.362 I8.287 J-19.192 E.18608
G1 X128.286 Y127.714 E.72019
G2 X127.713 Y127.714 I-.285 J8.198 E.019
G1 X112.36 Y112.361 E.72024
G3 X107.571 Y115.247 I-12.977 J-16.115 E.18607
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.486 J33.929 E.05383
G1 X125.587 Y122.737 E.29368
G2 X126.65 Y123.933 I2.415 J-1.078 E.05391
G1 X115.627 Y111.14 F36000
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.842 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07074
G3 X83.957 Y137.688 I2.365 J.127 E.04916
G1 X86.809 Y140.541 E.1338
G1 X90.708 Y142.264 E.14141
G1 X100.011 Y132.961 E.43643
G3 X100.227 Y130.931 I2.54 J-.756 E.0695
G1 X93.83 Y124.534 E.30011
G2 X90.989 Y126.401 I5.511 J11.481 E.11312
G2 X90.068 Y128.448 I10.56 J5.977 E.07456
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.02 J23.833 E.05401
G1 X88.404 Y132.211 F36000
G1 F15476.087
G3 X87.525 Y133.581 I-17.706 J-10.397 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.658 Y109.99 E1.62438
G2 X128.083 Y109.214 I-4.126 J9.029 E.08947
G2 X126.63 Y109.521 I.296 J4.993 E.04944
G1 X125.341 Y109.989 E.04552
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.263 J-12.72 E.054
; WIPE_START
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
; WIPE_END
G1 E-.04 F1800
G1 X160.618 Y133.101 Z2.4 F36000
G1 X142.231 Y131.307 Z2.4
G1 Z2
G1 E.8 F1800
G1 F15476.087
G2 X140.777 Y130.574 I-15.794 J29.519 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.634 Y118.324 I-3.851 J5.093 E.06135
G2 X157.884 Y121.144 I27.084 J-19.303 E.11972
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-18.114 J24.796 E.18067
G1 X152.182 Y134.522 E.11675
G3 X152.697 Y129.669 I1.316 J-2.314 E.20476
G1 X133.984 Y110.956 E.87789
G2 X137.055 Y111.268 I4.402 J-28.037 E.10248
G1 X129.082 Y119.242 E.37405
G2 X126.919 Y119.244 I-1.079 J2.441 E.07387
G1 X118.944 Y111.268 E.37413
G2 X122.015 Y110.957 I-1.317 J-28.289 E.10243
G1 X103.304 Y129.668 E.87778
G3 X103.82 Y134.524 I-.759 J2.536 E.2062
G1 X106.309 Y137.013 E.11678
G3 X110.399 Y133.428 I22.212 J21.213 E.18067
G1 X98.118 Y121.147 E.57613
G2 X100.796 Y117.778 I-30.135 J-26.709 E.1428
G3 X101.665 Y117.017 I2.261 J1.702 E.03858
G1 X115.224 Y130.576 E.6361
G2 X113.77 Y131.309 I14.316 J30.192 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 2.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X115.224 Y130.576 E-.61863
G1 X114.961 Y130.313 E-.14137
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
G1 X125.713 Y121.422
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.717 Y121.395 E.0009
G3 X127.826 Y119.362 I2.286 J.26 E.10535
G3 X128.374 Y119.392 I.176 J1.787 E.01826
G1 X128.527 Y119.416 E.00516
G3 X125.704 Y121.747 I-.525 J2.24 E.33901
G1 X125.711 Y121.482 E.0088
G1 X126.107 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.896 J.216 E.08093
G3 X128.314 Y119.78 I.146 J1.494 E.01414
G1 X128.438 Y119.799 E.00385
G3 X126.101 Y121.5 I-.435 J1.858 E.26757
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.1338
G1 X126.259 Y120.878 E-.11116
G1 X126.399 Y120.621 E-.11115
G1 X126.576 Y120.388 E-.11116
G1 X126.787 Y120.185 E-.11116
G1 X127.026 Y120.017 E-.11115
G1 X127.192 Y119.935 E-.07041
; WIPE_END
G1 E-.04 F1800
G1 X120.121 Y122.808 Z2.6 F36000
G1 X102.654 Y129.906 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.723 Y129.906 E.00226
G3 X102.37 Y129.906 I-.176 J2.294 E.4679
G1 X102.594 Y129.906 E.00744
G1 X102.399 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.4 Y130.298 E.00004
G1 X102.693 Y130.298 E.00899
G3 X102.111 Y130.343 I-.146 J1.903 E.35044
G1 X102.34 Y130.308 E.0071
; WIPE_START
M204 S10000
G1 X102.4 Y130.298 E-.02332
G1 X102.693 Y130.298 E-.11112
G1 X102.982 Y130.343 E-.11116
G1 X103.261 Y130.431 E-.11119
G1 X103.523 Y130.561 E-.11112
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11114
G1 X104.084 Y131.078 E-.06977
; WIPE_END
G1 E-.04 F1800
G1 X111.716 Y131.158 Z2.6 F36000
G1 X155.685 Y131.619 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.744 Y131.939 E.01079
G3 X153.282 Y129.906 I-2.286 J.261 E.36253
G1 X153.634 Y129.906 E.0117
G3 X155.669 Y131.562 I-.176 J2.294 E.09257
G1 X155.299 Y131.697 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.312 Y130.298 I-1.841 J.504 E.28748
G1 X153.604 Y130.298 E.00899
G3 X155.282 Y131.64 I-.146 J1.903 E.07011
; WIPE_START
M204 S10000
G1 X155.356 Y131.984 E-.13382
G1 X155.367 Y132.276 E-.11113
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11116
G1 X155.137 Y133.116 E-.11114
G1 X154.978 Y133.362 E-.11116
G1 X154.854 Y133.5 E-.07042
; WIPE_END
G1 E-.04 F1800
G1 X155.271 Y141.121 Z2.6 F36000
G1 X155.589 Y146.934 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.969 J3.755 E.05161
G2 X86.79 Y133.986 I-24.739 J-24.825 E.11929
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.297 J7.813 E.08251
G3 X91.436 Y125.548 I2.421 J1.174 E.05123
G3 X93.349 Y124.413 I15.966 J24.731 E.0738
G2 X98.06 Y120.701 I-8.564 J-15.715 E.1999
G2 X100.325 Y117.807 I-37.409 J-31.606 E.12194
G3 X101.377 Y116.768 I3.566 J2.561 E.04928
G3 X103.044 Y116.197 I2.999 J6.034 E.0586
G2 X106.576 Y115.257 I-6.544 J-31.729 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18843
G3 X113.513 Y111.136 I14.713 J18.728 E.08042
G3 X115.145 Y110.777 I1.449 J2.701 E.05612
G3 X117.853 Y110.909 I-7.765 J188.192 E.08995
G2 X124.754 Y109.831 I.851 J-17.19 E.2333
G3 X127.353 Y108.943 I11.102 J28.234 E.09117
G3 X128.107 Y108.866 I.659 J2.727 E.0252
G3 X129.665 Y109.259 I-.646 J5.845 E.05349
G2 X133.389 Y110.477 I12.289 J-31.265 E.13004
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.765 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.386 J23.422 E.07317
G2 X149.428 Y115.257 I11.08 J-14.314 E.18822
G2 X152.965 Y116.193 I9.839 J-30.04 E.12144
G3 X154.57 Y116.731 I-1.274 J6.462 E.05629
G3 X155.674 Y117.809 I-2.603 J3.772 E.05146
G2 X157.946 Y120.702 I41.963 J-30.612 E.12203
G2 X162.421 Y124.276 I12.715 J-11.334 E.19089
G3 X164.758 Y125.674 I-13.53 J25.27 E.09035
G3 X165.746 Y127.013 I-1.782 J2.348 E.05596
G3 X166.938 Y130.092 I-680.386 J265.329 E.10953
G2 X170.649 Y135.623 I16.058 J-6.762 E.22233
G3 X172.333 Y137.457 I-17.041 J17.334 E.08262
G3 X172.913 Y139.008 I-2.312 J1.749 E.0557
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.953 Y137.907 I5.256 J.2 E.05032
G3 X83.717 Y136.795 I3.859 J1.833 E.04163
G2 X85.862 Y134.489 I-445.258 J-416.388 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
M73 P57 R8
G3 X90.062 Y126.493 I23.429 J7.861 E.07788
G3 X91.213 Y125.225 I2.763 J1.351 E.05331
G3 X93.152 Y124.073 I16.142 J24.974 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.333 J-31.521 E.1123
G3 X101.175 Y116.432 I3.849 J2.781 E.04996
G3 X102.572 Y115.911 I2.611 J4.87 E.04596
G2 X105.821 Y115.092 I-12.104 J-54.833 E.10297
G2 X110.852 Y112.547 I-4.888 J-15.908 E.17407
G3 X112.855 Y111.082 I99.943 J134.622 E.07626
G3 X114.488 Y110.416 I2.052 J2.694 E.05482
G3 X115.868 Y110.406 I.755 J9.098 E.04244
G2 X119.447 Y110.52 I2.863 J-33.611 E.1101
G2 X124.623 Y109.462 I-.761 J-16.903 E.163
G3 X127.013 Y108.625 I13.212 J33.904 E.07783
G3 X128.132 Y108.474 I.997 J3.178 E.03486
G3 X129.794 Y108.889 I-.666 J6.211 E.05279
G2 X133.154 Y110.014 I13.009 J-33.261 E.10893
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05322
G3 X144.706 Y112.222 I-15.538 J23.682 E.06879
G2 X149.556 Y114.887 I10.852 J-14.004 E.17075
G2 X153.056 Y115.812 I9.715 J-29.681 E.11131
G3 X154.77 Y116.394 I-1.342 J6.764 E.05578
G3 X155.764 Y117.3 I-2.181 J3.391 E.04153
G2 X157.819 Y119.952 I1396.984 J-1080.14 E.10307
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.319 J30.235 E.07721
G3 X166.104 Y126.854 I-1.827 J2.82 E.0659
G3 X167.3 Y129.94 I-595.346 J232.446 E.10169
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.647 Y137.222 I-17.222 J17.507 E.07793
G3 X173.302 Y138.956 I-2.618 J1.98 E.05775
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X159.92 Y140.129 Z2.6 F36000
G1 X167.597 Y132.209 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X168.477 Y133.578 I19.129 J-11.342 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X125.341 Y109.989 E1.62449
G3 X127.862 Y109.215 I5.24 J12.571 E.08763
G3 X129.052 Y109.422 I-.015 J3.598 E.04026
G1 X130.658 Y109.99 E.0565
G1 X96.032 Y144.616 E1.62438
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.827 J-11.767 E.054
G1 X102.064 Y142.685 F36000
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.25 J11.558 E.05398
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.925 J1.551 E.0865
G3 X93.83 Y124.534 I9.839 J12.986 E.10129
G1 X100.227 Y130.931 E.30011
G2 X100.011 Y132.961 I2.661 J1.309 E.06912
G1 X90.708 Y142.264 E.43643
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.13381
G2 X83.434 Y139.05 I1.843 J1.488 E.04916
G1 X85.385 Y139.911 E.07073
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.701 E.05406
G1 X126.65 Y123.933 F36000
G1 F15476.087
G3 X125.587 Y122.737 I1.625 J-2.516 E.05372
G1 X119.326 Y128.997 E.29368
G3 X120.891 Y128.567 I10.051 J33.499 E.05383
G1 X107.571 Y115.247 E.62487
G2 X112.36 Y112.361 I-8.188 J-19.003 E.18607
G1 X127.713 Y127.714 E.72024
G3 X128.286 Y127.714 I.288 J8.198 E.019
G1 X143.645 Y112.355 E.7205
G2 X148.43 Y115.246 I12.872 J-15.902 E.18603
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.445 J33.806 E.05372
G1 X130.416 Y122.741 E.29341
G3 X129.352 Y123.934 I-2.414 J-1.082 E.05391
G1 X140.386 Y111.134 F36000
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.38 E.05407
G1 X170.616 Y139.912 E1.34272
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.418 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X155.992 Y132.965 E.43628
G2 X155.776 Y130.928 I-2.874 J-.724 E.06938
G1 X162.172 Y124.532 E.30006
G3 X164.985 Y126.364 I-5.41 J11.38 E.11169
G3 X165.932 Y128.447 I-10.701 J6.125 E.07602
G1 X153.083 Y141.297 E.6028
G3 X153.939 Y142.682 I-19.41 J12.954 E.05402
; WIPE_START
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
; WIPE_END
G1 E-.04 F1800
G1 X145.934 Y139.212 Z2.6 F36000
G1 X113.77 Y131.309 Z2.6
G1 Z2.2
G1 E.8 F1800
G1 F15476.087
G3 X115.224 Y130.576 I15.772 J29.463 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.779 I1.393 J2.464 E.0386
G3 X98.118 Y121.146 I-32.801 J-23.332 E.14279
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.74 J27.781 E.18055
G1 X103.82 Y134.524 E.11678
G2 X103.304 Y129.668 I-1.275 J-2.32 E.2062
G1 X122.015 Y110.957 E.87778
G3 X118.944 Y111.268 I-4.387 J-27.978 E.10243
G1 X126.919 Y119.244 E.37413
G3 X129.082 Y119.242 I1.083 J2.439 E.07387
G1 X137.055 Y111.268 E.37405
G3 X133.984 Y110.956 I1.331 J-28.349 E.10248
G1 X152.697 Y129.669 E.87789
G2 X152.182 Y134.522 I.762 J2.535 E.20594
G1 X149.693 Y137.011 E.11675
G2 X145.602 Y133.425 I-22.975 J22.09 E.18066
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.323 I24.85 J-22.135 E.11976
G2 X154.34 Y117.012 I-5.147 J3.784 E.06131
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.34 J30.252 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 2.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
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
G1 X125.713 Y121.422
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.717 Y121.395 E.00091
G3 X127.826 Y119.362 I2.286 J.26 E.10535
G1 X128.179 Y119.362 E.0117
G3 X125.704 Y121.747 I-.176 J2.294 E.35072
G1 X125.711 Y121.482 E.00879
G1 X126.107 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.896 J.216 E.08093
G1 X128.149 Y119.754 E.00899
G3 X126.101 Y121.5 I-.146 J1.902 E.27656
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.1338
G1 X126.259 Y120.877 E-.1112
G1 X126.399 Y120.621 E-.1111
G1 X126.576 Y120.388 E-.11117
G1 X126.787 Y120.185 E-.11117
G1 X127.026 Y120.017 E-.11115
G1 X127.192 Y119.935 E-.07041
; WIPE_END
G1 E-.04 F1800
G1 X120.104 Y122.765 Z2.8 F36000
G1 X102.122 Y129.945 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.37 Y129.906 E.00834
G1 X102.723 Y129.906 E.0117
G3 X102.022 Y129.96 I-.176 J2.294 E.45605
G1 X102.062 Y129.954 E.00137
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.4 Y130.298 E.00001
G1 X102.693 Y130.298 E.00899
G3 X102.111 Y130.343 I-.146 J1.902 E.35034
G1 X102.34 Y130.308 E.00713
; WIPE_START
M204 S10000
G1 X102.4 Y130.298 E-.02298
G1 X102.693 Y130.298 E-.11113
G1 X102.982 Y130.343 E-.11116
G1 X103.261 Y130.431 E-.11118
G1 X103.523 Y130.561 E-.11112
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11114
G1 X104.085 Y131.079 E-.0701
; WIPE_END
G1 E-.04 F1800
G1 X111.717 Y131.159 Z2.8 F36000
G1 X155.685 Y131.62 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.744 Y131.939 E.01078
G3 X153.282 Y129.906 I-2.286 J.26 E.3624
G1 X153.634 Y129.906 E.0117
G3 X155.668 Y131.562 I-.176 J2.294 E.09258
G1 X155.301 Y131.698 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.354 Y131.984 E.00895
G3 X153.312 Y130.298 I-1.896 J.216 E.2784
G1 X153.604 Y130.298 E.00899
G3 X155.282 Y131.642 I-.146 J1.902 E.07018
; WIPE_START
M204 S10000
G1 X155.354 Y131.984 E-.13284
G1 X155.367 Y132.276 E-.11106
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11116
G1 X155.137 Y133.116 E-.11113
G1 X154.978 Y133.362 E-.11118
G1 X154.853 Y133.502 E-.07144
; WIPE_END
G1 E-.04 F1800
G1 X155.27 Y141.123 Z2.8 F36000
G1 X155.589 Y146.934 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.721 E2.3565
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04816
G3 X84.377 Y136.65 I5.974 J3.758 E.05161
G2 X86.79 Y133.985 I-24.734 J-24.82 E.1193
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18944
G3 X90.41 Y126.674 I23.323 J7.823 E.08249
G3 X91.436 Y125.548 I2.421 J1.174 E.05123
G3 X93.349 Y124.413 I15.956 J24.714 E.07381
G2 X98.059 Y120.702 I-8.564 J-15.716 E.19987
G2 X100.325 Y117.807 I-37.406 J-31.606 E.12197
G3 X101.394 Y116.758 I3.536 J2.535 E.04993
G3 X103.044 Y116.197 I3.008 J6.141 E.05796
G2 X106.577 Y115.257 I-6.546 J-31.736 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18842
G3 X113.513 Y111.136 I14.721 J18.74 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05612
G3 X117.853 Y110.909 I-7.766 J188.219 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.097 J28.217 E.09116
G3 X128.107 Y108.866 I.66 J2.728 E.02521
G3 X129.665 Y109.259 I-.646 J5.844 E.05349
G2 X133.389 Y110.477 I12.289 J-31.263 E.13004
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.765 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.381 J23.415 E.07316
G2 X149.427 Y115.257 I11.081 J-14.314 E.18822
G2 X152.965 Y116.193 I9.837 J-30.032 E.12146
G3 X154.516 Y116.701 I-1.278 J6.527 E.05426
G3 X155.465 Y117.554 I-1.723 J2.873 E.0426
G2 X157.516 Y120.201 I1050.2 J-811.411 E.11111
G2 X162.421 Y124.276 I13.225 J-10.931 E.21276
G3 X164.757 Y125.673 I-13.54 J25.288 E.09033
G3 X165.746 Y127.013 I-1.781 J2.349 E.056
G3 X166.938 Y130.091 I-683.905 J266.686 E.10951
G2 X170.649 Y135.623 I16.058 J-6.762 E.22234
G3 X172.333 Y137.457 I-17.03 J17.324 E.08262
G3 X172.913 Y139.008 I-2.312 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.201 E2.17905
G1 X82.639 Y139.508 E.60452
G3 X82.952 Y137.909 I5.261 J.2 E.05025
G3 X83.717 Y136.795 I3.855 J1.827 E.04169
G2 X85.862 Y134.489 I-445.502 J-416.611 E.09678
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.447 J7.868 E.07787
G3 X91.212 Y125.225 I2.764 J1.351 E.05332
G3 X93.152 Y124.073 I16.129 J24.952 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.338 J-31.525 E.1123
G3 X101.193 Y116.421 I3.821 J2.757 E.05061
G3 X102.951 Y115.816 I3.187 J6.402 E.0573
G2 X106.448 Y114.887 I-6.459 J-31.369 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.855 J18.918 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.449 J182.411 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.207 J33.89 E.07783
G3 X128.132 Y108.474 I.997 J3.177 E.03487
G3 X129.794 Y108.889 I-.666 J6.211 E.05278
G2 X133.154 Y110.014 I13.006 J-33.252 E.10893
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05322
G3 X144.706 Y112.222 I-15.539 J23.684 E.06878
G2 X149.556 Y114.887 I10.852 J-14.005 E.17076
G2 X153.057 Y115.812 I9.716 J-29.685 E.11132
G3 X154.703 Y116.356 I-1.361 J6.878 E.05342
G3 X155.765 Y117.3 I-1.905 J3.21 E.04392
G2 X157.819 Y119.952 I1400.332 J-1082.729 E.10306
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.298 J30.199 E.07722
G3 X166.104 Y126.854 I-1.828 J2.82 E.0659
G3 X167.3 Y129.94 I-596.843 J233.022 E.10168
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.647 Y137.222 I-17.222 J17.508 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05775
G3 X173.36 Y139.508 I-10.392 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z2.8 F36000
G1 Z2.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.273 J11.574 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.785 Y126.148 I-5.9 J1.508 E.08586
G2 X164.137 Y125.671 I-2.779 J3.096 E.02675
G1 X162.175 Y124.529 E.07532
G1 X155.787 Y130.949 E.3004
G3 X155.992 Y132.965 I-2.678 J1.291 E.06859
G1 X165.292 Y142.265 E.43628
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.908 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34273
G2 X140.386 Y111.134 I-1.124 J3.224 E.05407
G1 X129.352 Y123.934 F36000
G1 F15476.087
G2 X130.416 Y122.741 I-1.349 J-2.275 E.05391
G1 X136.671 Y128.995 E.29341
G2 X135.109 Y128.566 I-10.009 J33.387 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.645 Y112.355 I8.086 J-18.791 E.18603
G1 X128.286 Y127.714 E.7205
G2 X127.713 Y127.714 I-.285 J8.198 E.019
G1 X112.36 Y112.361 E.72024
G3 X107.571 Y115.247 I-12.978 J-16.116 E.18607
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.486 J33.929 E.05383
G1 X125.587 Y122.737 E.29368
G2 X126.65 Y123.933 I2.416 J-1.078 E.05391
G1 X115.627 Y111.14 F36000
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.841 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.365 J.127 E.04916
G1 X86.809 Y140.541 E.13381
G1 X90.708 Y142.264 E.14141
G1 X100.011 Y132.961 E.43643
M73 P58 R8
G3 X100.227 Y130.931 I2.877 J-.72 E.06912
G1 X93.83 Y124.534 E.30011
G2 X90.988 Y126.401 I5.511 J11.481 E.11312
G2 X90.068 Y128.448 I10.562 J5.978 E.07456
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.02 J23.833 E.05401
G1 X88.404 Y132.211 F36000
G1 F15476.087
G3 X87.525 Y133.581 I-17.714 J-10.402 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.658 Y109.99 E1.62438
G2 X128.084 Y109.214 I-4.127 J9.032 E.08946
G2 X126.631 Y109.521 I.296 J4.992 E.04945
G1 X125.341 Y109.989 E.04552
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.248 J-12.71 E.054
; WIPE_START
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
; WIPE_END
G1 E-.04 F1800
G1 X160.618 Y133.101 Z2.8 F36000
G1 X142.231 Y131.307 Z2.8
G1 Z2.4
G1 E.8 F1800
G1 F15476.087
G2 X140.777 Y130.574 I-15.794 J29.519 E.05401
G1 X154.34 Y117.012 E.63625
G3 X155.633 Y118.323 I-3.876 J5.117 E.06131
G2 X157.884 Y121.144 I27.1 J-19.315 E.11976
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-18.951 J25.751 E.18066
G1 X152.182 Y134.522 E.11675
G3 X152.697 Y129.669 I1.278 J-2.318 E.20594
G1 X133.984 Y110.956 E.87789
G2 X137.055 Y111.268 I4.403 J-28.037 E.10248
G1 X129.082 Y119.242 E.37406
G2 X126.919 Y119.244 I-1.079 J2.441 E.07387
G1 X118.944 Y111.268 E.37413
G2 X122.015 Y110.957 I-1.316 J-28.288 E.10243
G1 X103.304 Y129.668 E.87778
G3 X103.82 Y134.524 I-.759 J2.536 E.2062
G1 X106.309 Y137.013 E.11678
G3 X110.399 Y133.428 I22.212 J21.213 E.18067
G1 X98.118 Y121.147 E.57613
G2 X100.796 Y117.778 I-30.146 J-26.718 E.14281
G3 X101.665 Y117.017 I2.261 J1.702 E.03858
G1 X115.224 Y130.576 E.6361
G2 X113.77 Y131.309 I14.318 J30.196 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 2.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X115.224 Y130.576 E-.61863
G1 X114.961 Y130.313 E-.14137
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
G1 X125.713 Y121.423
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.717 Y121.395 E.00092
G3 X127.826 Y119.362 I2.285 J.26 E.10535
G1 X128.179 Y119.362 E.0117
G3 X125.704 Y121.747 I-.176 J2.293 E.35067
G1 X125.711 Y121.483 E.00877
G1 X126.107 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.895 J.216 E.08093
G1 X128.149 Y119.754 E.00899
G3 X126.101 Y121.5 I-.146 J1.902 E.27652
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.1338
G1 X126.259 Y120.878 E-.11117
G1 X126.399 Y120.621 E-.11115
G1 X126.576 Y120.388 E-.11115
G1 X126.787 Y120.185 E-.11117
G1 X127.026 Y120.017 E-.11115
G1 X127.192 Y119.935 E-.07041
; WIPE_END
G1 E-.04 F1800
G1 X120.104 Y122.767 Z3 F36000
G1 X102.155 Y129.939 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.37 Y129.906 E.00724
G3 X103.405 Y134.334 I.176 J2.294 E.21638
G3 X100.265 Y132.467 I-.867 J-2.116 E.1404
G3 X102.022 Y129.962 I2.293 J-.26 E.11097
G1 X102.095 Y129.949 E.00247
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00899
G3 X102.341 Y130.304 I-.146 J1.902 E.35749
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13382
G1 X102.982 Y130.343 E-.11116
G1 X103.261 Y130.431 E-.11118
G1 X103.523 Y130.561 E-.11112
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11114
G1 X104.085 Y131.079 E-.0704
; WIPE_END
G1 E-.04 F1800
G1 X111.717 Y131.159 Z3 F36000
G1 X155.685 Y131.62 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.74 Y131.94 E.01076
G3 X155.74 Y132.467 I-2.29 J.266 E.01751
G3 X153.282 Y129.906 I-2.285 J-.267 E.34499
G3 X155.664 Y131.564 I.167 J2.299 E.10414
G1 X155.301 Y131.699 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.354 Y131.984 E.0089
G3 X153.312 Y130.298 I-1.896 J.216 E.2784
G1 X153.604 Y130.298 E.00899
G3 X155.283 Y131.643 I-.146 J1.902 E.0702
; WIPE_START
M204 S10000
G1 X155.354 Y131.984 E-.13253
G1 X155.367 Y132.276 E-.11106
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11115
G1 X155.137 Y133.116 E-.11115
G1 X154.978 Y133.362 E-.11117
G1 X154.852 Y133.503 E-.07176
; WIPE_END
G1 E-.04 F1800
G1 X155.27 Y141.124 Z3 F36000
G1 X155.589 Y146.934 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.972 J3.757 E.05162
G2 X86.79 Y133.986 I-24.735 J-24.821 E.11928
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.332 J7.826 E.08251
G3 X91.436 Y125.548 I2.418 J1.171 E.05123
G3 X93.349 Y124.413 I15.961 J24.722 E.0738
G2 X98.06 Y120.701 I-8.564 J-15.715 E.19989
G2 X100.325 Y117.806 I-37.43 J-31.624 E.12196
G3 X101.374 Y116.77 I3.572 J2.566 E.04915
G3 X103.044 Y116.197 I2.998 J6.016 E.05873
G2 X106.577 Y115.257 I-6.546 J-31.734 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18842
G3 X113.513 Y111.136 I14.727 J18.747 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.765 J188.201 E.08995
G2 X124.754 Y109.831 I.851 J-17.19 E.2333
G3 X127.353 Y108.943 I11.098 J28.22 E.09117
G3 X128.107 Y108.866 I.659 J2.728 E.0252
G3 X129.665 Y109.259 I-.646 J5.845 E.05349
G2 X133.389 Y110.477 I12.289 J-31.265 E.13004
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.768 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05112
G3 X144.474 Y112.538 I-15.384 J23.42 E.07318
G2 X149.428 Y115.257 I11.081 J-14.315 E.18822
G2 X152.965 Y116.193 I9.837 J-30.033 E.12144
G3 X154.569 Y116.731 I-1.274 J6.463 E.05629
G3 X155.674 Y117.809 I-2.602 J3.771 E.05146
G2 X157.946 Y120.702 I41.973 J-30.62 E.12203
G2 X162.421 Y124.276 I12.715 J-11.334 E.19089
G3 X164.758 Y125.674 I-13.525 J25.262 E.09035
G3 X165.746 Y127.013 I-1.782 J2.349 E.05599
G3 X166.938 Y130.091 I-686.719 J267.775 E.1095
G2 X170.649 Y135.623 I16.058 J-6.762 E.22234
G3 X172.333 Y137.457 I-17.035 J17.328 E.08261
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.199 J.192 E.05096
G3 X83.717 Y136.795 I3.894 J1.885 E.04099
G2 X85.862 Y134.489 I-444.189 J-415.396 E.09676
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.457 J7.872 E.07787
G3 X91.213 Y125.225 I2.76 J1.348 E.05332
G3 X93.152 Y124.073 I16.129 J24.952 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.34 J-31.527 E.1123
G3 X101.171 Y116.434 I3.855 J2.786 E.04983
G3 X102.572 Y115.911 I2.61 J4.854 E.04609
G2 X105.821 Y115.092 I-12.101 J-54.821 E.10297
G2 X110.852 Y112.547 I-4.888 J-15.908 E.17407
G3 X112.855 Y111.082 I100.207 J134.981 E.07626
G3 X114.488 Y110.416 I2.052 J2.695 E.05482
G3 X115.868 Y110.406 I.755 J9.097 E.04244
G2 X119.447 Y110.52 I2.863 J-33.612 E.1101
G2 X124.623 Y109.462 I-.761 J-16.903 E.163
G3 X127.013 Y108.625 I13.211 J33.904 E.07783
G3 X128.132 Y108.474 I.997 J3.178 E.03486
G3 X129.794 Y108.889 I-.666 J6.211 E.05279
G2 X133.154 Y110.014 I13.009 J-33.261 E.10893
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.874 E.07855
G3 X142.884 Y110.921 I-.11 J3.071 E.05322
G3 X144.706 Y112.222 I-15.546 J23.694 E.06879
G2 X149.556 Y114.887 I10.852 J-14.005 E.17075
G2 X153.056 Y115.812 I9.715 J-29.681 E.11131
G3 X154.77 Y116.394 I-1.342 J6.764 E.05577
G3 X155.765 Y117.3 I-2.181 J3.391 E.04154
G2 X157.819 Y119.952 I1380.954 J-1067.713 E.10306
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.308 J30.215 E.07721
G3 X166.104 Y126.854 I-1.828 J2.82 E.06591
G3 X167.3 Y129.94 I-597.875 J233.422 E.10168
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.229 J17.514 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X159.92 Y140.129 Z3 F36000
G1 X167.597 Y132.209 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X168.477 Y133.578 I19.136 J-11.346 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X125.341 Y109.989 E1.62449
G3 X127.862 Y109.214 I5.236 J12.557 E.08765
G3 X129.052 Y109.422 I-.016 J3.598 E.04024
G1 X130.658 Y109.99 E.05651
G1 X96.032 Y144.616 E1.62438
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.853 J-11.784 E.054
G1 X102.064 Y142.685 F36000
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.25 J11.558 E.05398
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.927 J1.552 E.08649
G3 X93.83 Y124.534 I9.839 J12.985 E.1013
G1 X100.227 Y130.931 E.30011
G2 X100.011 Y132.961 I2.325 J1.274 E.0695
G1 X90.708 Y142.264 E.43643
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.13381
G2 X83.434 Y139.05 I1.841 J1.487 E.04916
G1 X85.385 Y139.911 E.07073
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.699 E.05406
G1 X126.65 Y123.933 F36000
G1 F15476.087
G3 X125.587 Y122.737 I1.599 J-2.493 E.05373
G1 X119.326 Y128.997 E.29368
G3 X120.891 Y128.567 I10.051 J33.499 E.05383
G1 X107.571 Y115.247 E.62487
G2 X112.36 Y112.361 I-8.189 J-19.003 E.18607
G1 X127.713 Y127.714 E.72024
G3 X128.286 Y127.714 I.288 J8.199 E.019
G1 X143.645 Y112.355 E.7205
G2 X148.43 Y115.246 I12.871 J-15.9 E.18603
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.448 J33.816 E.05372
G1 X130.416 Y122.741 E.29341
G3 X129.352 Y123.934 I-2.907 J-1.522 E.05361
G1 X140.386 Y111.134 F36000
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.38 E.05407
G1 X170.616 Y139.912 E1.34272
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.418 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X155.992 Y132.965 E.43628
G2 X155.776 Y130.928 I-2.874 J-.724 E.06938
G1 X162.172 Y124.532 E.30006
G3 X164.985 Y126.364 I-5.411 J11.381 E.11169
G3 X165.932 Y128.447 I-10.698 J6.124 E.07603
G1 X153.083 Y141.297 E.6028
G3 X153.939 Y142.682 I-19.41 J12.954 E.05402
; WIPE_START
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
; WIPE_END
G1 E-.04 F1800
G1 X145.934 Y139.212 Z3 F36000
G1 X113.77 Y131.309 Z3
G1 Z2.6
G1 E.8 F1800
G1 F15476.087
G3 X115.224 Y130.576 I15.772 J29.463 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.779 I1.394 J2.465 E.0386
G3 X98.118 Y121.147 I-32.792 J-23.324 E.14279
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.74 J27.781 E.18055
G1 X103.82 Y134.524 E.11678
G2 X103.304 Y129.668 I-1.275 J-2.32 E.2062
G1 X122.015 Y110.957 E.87778
G3 X118.944 Y111.268 I-4.387 J-27.975 E.10243
G1 X126.919 Y119.244 E.37413
G3 X129.082 Y119.242 I1.083 J2.439 E.07387
G1 X137.055 Y111.268 E.37405
G3 X133.984 Y110.956 I1.331 J-28.349 E.10248
G1 X152.697 Y129.669 E.87789
G2 X152.182 Y134.522 I.801 J2.539 E.20476
G1 X149.693 Y137.011 E.11675
G2 X145.602 Y133.425 I-23.112 J22.246 E.18065
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.323 I24.845 J-22.132 E.11975
G2 X154.34 Y117.012 I-5.147 J3.783 E.06132
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.34 J30.252 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 2.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
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
G1 X125.719 Y121.367
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.781 Y121.049 E.01076
G3 X127.826 Y119.362 I2.221 J.61 E.09369
M73 P59 R8
G1 X128.179 Y119.362 E.0117
G3 X125.71 Y121.426 I-.176 J2.297 E.362
G1 X126.104 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.898 J.219 E.08097
G1 X128.149 Y119.754 E.00899
G3 X126.098 Y121.5 I-.146 J1.905 E.27706
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.13385
G1 X126.259 Y120.878 E-.11117
G1 X126.399 Y120.621 E-.11115
G1 X126.576 Y120.388 E-.11115
G1 X126.787 Y120.185 E-.11117
G1 X127.026 Y120.017 E-.11115
G1 X127.192 Y119.935 E-.07036
; WIPE_END
G1 E-.04 F1800
G1 X120.117 Y122.798 Z3.2 F36000
G1 X102.554 Y129.906 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.722 Y129.912 E.00557
G3 X103.23 Y130.01 I-.214 J2.457 E.01717
G1 X103.408 Y130.066 E.0062
G3 X102.37 Y129.906 I-.861 J2.133 E.44434
G1 X102.494 Y129.906 E.00412
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X103.111 Y130.384 I.115 J2.043 E.02212
G1 X103.261 Y130.431 E.00482
G3 X102.341 Y130.304 I-.714 J1.769 E.3395
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13382
G1 X102.982 Y130.343 E-.11116
G1 X103.111 Y130.384 E-.05162
G1 X103.261 Y130.431 E-.05956
G1 X103.523 Y130.561 E-.11112
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11114
G1 X104.085 Y131.079 E-.0704
; WIPE_END
G1 E-.04 F1800
G1 X111.717 Y131.159 Z3.2 F36000
G1 X155.685 Y131.621 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.744 Y131.939 E.01076
G3 X153.282 Y129.906 I-2.286 J.261 E.3624
G3 X154.141 Y130.01 I.138 J2.462 E.02887
G1 X154.319 Y130.066 E.0062
G3 X155.669 Y131.563 I-.861 J2.133 E.06919
G1 X155.301 Y131.701 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.354 Y131.984 E.00886
G3 X153.312 Y130.298 I-1.896 J.216 E.2784
G3 X154.023 Y130.384 I.115 J2.043 E.02212
G1 X154.172 Y130.431 E.00482
G3 X155.283 Y131.644 I-.714 J1.769 E.05225
; WIPE_START
M204 S10000
G1 X155.354 Y131.984 E-.1322
G1 X155.367 Y132.276 E-.11108
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11115
G1 X155.137 Y133.116 E-.11115
G1 X154.978 Y133.362 E-.11117
G1 X154.851 Y133.503 E-.07207
; WIPE_END
G1 E-.04 F1800
G1 X155.27 Y141.124 Z3.2 F36000
G1 X155.589 Y146.934 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.723 E2.35641
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.971 J3.756 E.05161
G2 X86.79 Y133.986 I-24.739 J-24.825 E.11929
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.316 J7.82 E.08249
G3 X91.436 Y125.548 I2.418 J1.171 E.05124
G3 X93.349 Y124.413 I15.955 J24.712 E.0738
G2 X98.06 Y120.701 I-8.564 J-15.715 E.1999
G2 X100.325 Y117.806 I-37.418 J-31.614 E.12195
G3 X101.394 Y116.758 I3.535 J2.535 E.04993
G3 X103.044 Y116.197 I3.009 J6.144 E.05796
G2 X106.576 Y115.257 I-6.545 J-31.731 E.12132
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18843
G3 X113.513 Y111.136 I14.72 J18.738 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.766 J188.228 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.354 Y108.943 I11.094 J28.211 E.09117
G3 X128.107 Y108.866 I.659 J2.729 E.0252
G3 X129.665 Y109.259 I-.646 J5.845 E.05348
G2 X133.389 Y110.477 I12.289 J-31.264 E.13004
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.765 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05112
G3 X144.474 Y112.538 I-15.378 J23.412 E.07319
G2 X149.428 Y115.257 I11.08 J-14.314 E.18822
G2 X152.965 Y116.193 I9.84 J-30.043 E.12145
G3 X154.57 Y116.731 I-1.273 J6.46 E.0563
G3 X155.674 Y117.809 I-2.604 J3.772 E.05145
G2 X157.946 Y120.702 I41.958 J-30.608 E.12202
G2 X162.421 Y124.276 I12.715 J-11.334 E.19089
G3 X164.758 Y125.674 I-13.53 J25.269 E.09035
G3 X165.746 Y127.013 I-1.782 J2.349 E.05599
G3 X166.938 Y130.091 I-686.285 J267.606 E.1095
G2 X170.649 Y135.623 I16.058 J-6.761 E.22232
G3 X172.333 Y137.457 I-17.056 J17.348 E.08263
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.201 E2.17905
G1 X82.639 Y139.508 E.60452
G3 X82.951 Y137.913 I5.274 J.202 E.05013
G3 X83.717 Y136.795 I3.85 J1.819 E.04181
G2 X85.862 Y134.489 I-445.258 J-416.388 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.443 J7.866 E.07787
G3 X91.212 Y125.225 I2.76 J1.348 E.05331
G3 X93.152 Y124.073 I16.128 J24.95 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.34 J-31.527 E.1123
G3 X101.193 Y116.421 I3.822 J2.758 E.05062
G3 X102.951 Y115.816 I3.188 J6.405 E.0573
G2 X106.448 Y114.887 I-6.458 J-31.366 E.11123
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.852 J18.915 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.45 J182.419 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.207 J33.892 E.07784
G3 X128.132 Y108.474 I.997 J3.178 E.03486
G3 X129.794 Y108.889 I-.666 J6.21 E.05279
G2 X133.154 Y110.014 I13.009 J-33.259 E.10893
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05321
G3 X144.706 Y112.222 I-15.534 J23.678 E.0688
G2 X149.556 Y114.887 I10.852 J-14.005 E.17075
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.77 Y116.394 I-1.342 J6.762 E.05577
G3 X155.765 Y117.3 I-2.18 J3.39 E.04153
G2 X157.819 Y119.952 I1402.906 J-1084.725 E.10306
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.3 J30.201 E.07722
G3 X166.104 Y126.854 I-1.828 J2.82 E.0659
G3 X167.3 Y129.94 I-597.875 J233.422 E.10168
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.232 J17.516 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.393 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z3.2 F36000
G1 Z2.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.266 J11.569 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.655 J1.408 E.08775
G2 X162.172 Y124.532 I-25.056 J37.921 E.10007
G1 X155.776 Y130.928 E.30006
G3 X155.992 Y132.965 I-2.658 J1.313 E.06938
G1 X165.292 Y142.265 E.43628
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.907 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34272
G2 X140.386 Y111.134 I-1.124 J3.223 E.05407
G1 X129.352 Y123.934 F36000
G1 F15476.087
G2 X130.416 Y122.741 I-1.349 J-2.275 E.05391
G1 X136.671 Y128.995 E.29341
G2 X135.109 Y128.566 I-10.009 J33.387 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.645 Y112.355 I8.086 J-18.791 E.18603
G1 X128.286 Y127.714 E.7205
G2 X127.713 Y127.714 I-.285 J8.199 E.019
G1 X112.36 Y112.361 E.72024
G3 X107.571 Y115.247 I-12.979 J-16.118 E.18607
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.475 J33.887 E.05383
G1 X125.587 Y122.737 E.29368
G2 X126.65 Y123.933 I2.416 J-1.078 E.05391
G1 X115.627 Y111.14 F36000
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.843 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.365 J.127 E.04916
G1 X86.809 Y140.541 E.13381
G1 X90.708 Y142.264 E.14141
G1 X100.011 Y132.961 E.43643
G3 X100.227 Y130.931 I2.738 J-.735 E.06926
G1 X93.83 Y124.534 E.30011
G2 X90.988 Y126.402 I5.504 J11.47 E.11315
G2 X90.068 Y128.448 I10.57 J5.98 E.07453
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.02 J23.833 E.05401
G1 X88.404 Y132.211 F36000
G1 F15476.087
G3 X87.525 Y133.581 I-17.732 J-10.414 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.658 Y109.99 E1.62438
G2 X128.084 Y109.214 I-4.128 J9.034 E.08945
G2 X126.631 Y109.521 I.295 J4.992 E.04945
G1 X125.341 Y109.989 E.04552
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.25 J-12.712 E.054
; WIPE_START
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
; WIPE_END
G1 E-.04 F1800
G1 X160.618 Y133.101 Z3.2 F36000
G1 X142.231 Y131.307 Z3.2
G1 Z2.8
G1 E.8 F1800
G1 F15476.087
G2 X140.777 Y130.574 I-15.794 J29.519 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.633 Y118.324 I-3.856 J5.097 E.06132
G2 X157.884 Y121.144 I27.098 J-19.313 E.11975
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-19.085 J25.904 E.18065
G1 X152.182 Y134.522 E.11675
G3 X152.697 Y129.669 I1.316 J-2.314 E.20476
G1 X133.984 Y110.956 E.87789
G2 X137.055 Y111.268 I4.403 J-28.037 E.10248
G1 X129.082 Y119.242 E.37405
G2 X126.919 Y119.244 I-1.079 J2.441 E.07387
G1 X118.944 Y111.268 E.37413
G2 X122.015 Y110.957 I-1.317 J-28.291 E.10243
G1 X103.335 Y129.678 E.87728
G3 X103.82 Y134.524 I-.789 J2.526 E.20511
G1 X106.309 Y137.013 E.11678
G3 X110.399 Y133.428 I22.212 J21.213 E.18067
G1 X98.118 Y121.146 E.57613
G2 X100.796 Y117.779 I-30.123 J-26.7 E.1428
G3 X101.665 Y117.017 I2.26 J1.7 E.03859
G1 X115.224 Y130.576 E.6361
G2 X113.77 Y131.309 I14.316 J30.192 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 3
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X115.224 Y130.576 E-.61863
G1 X114.961 Y130.313 E-.14137
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
G1 X125.713 Y121.424
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.717 Y121.395 E.00095
G3 X127.826 Y119.362 I2.286 J.26 E.10534
G3 X128.675 Y119.463 I.138 J2.468 E.02852
G1 X128.864 Y119.522 E.00654
G3 X125.704 Y121.747 I-.861 J2.133 E.32731
G1 X125.711 Y121.484 E.00875
G1 X126.107 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.896 J.216 E.08092
G3 X128.557 Y119.837 I.114 J2.049 E.0218
G1 X128.717 Y119.887 E.00514
G3 X126.101 Y121.5 I-.714 J1.769 E.25858
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.13379
G1 X126.259 Y120.878 E-.11116
G1 X126.319 Y120.767 E-.04767
G1 X126.399 Y120.621 E-.06351
G1 X126.576 Y120.388 E-.11112
G1 X126.787 Y120.185 E-.11118
G1 X126.889 Y120.113 E-.04766
G1 X127.026 Y120.017 E-.0635
G1 X127.192 Y119.935 E-.07041
; WIPE_END
G1 E-.04 F1800
G1 X120.106 Y122.771 Z3.4 F36000
G1 X102.222 Y129.929 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.37 Y129.906 E.00498
G3 X103.22 Y130.007 I.138 J2.467 E.02852
G1 X103.408 Y130.066 E.00654
G3 X102.022 Y129.96 I-.861 J2.133 E.43263
G1 X102.163 Y129.938 E.00473
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X103.101 Y130.381 I.115 J2.048 E.0218
G1 X103.261 Y130.431 E.00514
G3 X102.341 Y130.304 I-.714 J1.769 E.3395
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13382
G1 X102.982 Y130.343 E-.11116
G1 X103.101 Y130.381 E-.04767
G1 X103.261 Y130.431 E-.06351
G1 X103.523 Y130.561 E-.11112
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11114
G1 X104.085 Y131.079 E-.07039
; WIPE_END
G1 E-.04 F1800
G1 X111.717 Y131.159 Z3.4 F36000
G1 X155.685 Y131.621 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.744 Y131.939 E.01074
G3 X151.179 Y132.487 I-2.285 J.259 E.23861
G3 X153.282 Y129.906 I2.278 J-.291 E.12355
G3 X155.669 Y131.563 I.178 J2.292 E.10435
G1 X155.301 Y131.702 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.354 Y131.984 E.00882
G3 X153.312 Y130.298 I-1.896 J.216 E.27839
G3 X154.013 Y130.381 I.115 J2.048 E.0218
G1 X154.172 Y130.431 E.00514
G3 X155.284 Y131.645 I-.714 J1.769 E.05228
; WIPE_START
M204 S10000
G1 X155.354 Y131.984 E-.13171
G1 X155.367 Y132.276 E-.11108
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11115
G1 X155.137 Y133.116 E-.11115
G1 X154.978 Y133.362 E-.11117
G1 X154.851 Y133.504 E-.07256
; WIPE_END
G1 E-.04 F1800
G1 X155.269 Y141.125 Z3.4 F36000
G1 X155.589 Y146.934 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.724 E2.3564
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.975 J3.76 E.05162
G2 X86.79 Y133.986 I-24.728 J-24.815 E.11928
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.301 J7.815 E.08251
G3 X91.436 Y125.548 I2.417 J1.171 E.05122
G3 X93.349 Y124.413 I15.955 J24.712 E.07381
G2 X98.059 Y120.701 I-8.564 J-15.715 E.19988
G2 X100.325 Y117.806 I-37.413 J-31.611 E.12197
G3 X101.394 Y116.758 I3.536 J2.535 E.04993
G3 X103.044 Y116.197 I3.009 J6.144 E.05796
G2 X106.577 Y115.257 I-6.543 J-31.723 E.12132
G2 X111.534 Y112.534 I-5.974 J-16.747 E.18842
G3 X113.513 Y111.136 I14.721 J18.739 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.765 J188.201 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.099 J28.223 E.09117
G3 X128.107 Y108.866 I.659 J2.727 E.02522
G3 X129.664 Y109.258 I-.645 J5.836 E.05341
G2 X133.389 Y110.477 I12.295 J-31.277 E.1301
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.773 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05111
G3 X144.474 Y112.538 I-15.377 J23.411 E.07319
G2 X149.428 Y115.257 I11.081 J-14.315 E.18822
G2 X152.965 Y116.193 I9.84 J-30.042 E.12145
G3 X154.569 Y116.731 I-1.273 J6.46 E.05628
G3 X155.674 Y117.809 I-2.602 J3.771 E.05146
G2 X157.946 Y120.702 I41.981 J-30.626 E.12202
G2 X162.421 Y124.276 I12.716 J-11.334 E.19091
G3 X164.757 Y125.673 I-13.54 J25.287 E.09033
G3 X165.746 Y127.012 I-1.781 J2.348 E.05597
G3 X166.938 Y130.091 I-674.6 J263.092 E.10953
G2 X170.649 Y135.623 I16.058 J-6.761 E.22232
G3 X172.333 Y137.457 I-17.054 J17.346 E.08263
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17904
G1 X82.639 Y139.508 E.60452
G3 X82.95 Y137.915 I5.28 J.203 E.05007
G3 X83.717 Y136.795 I3.849 J1.815 E.04187
G2 X85.862 Y134.489 I-444.736 J-415.901 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
M73 P59 R7
G3 X90.062 Y126.493 I23.43 J7.861 E.07788
G3 X91.213 Y125.225 I2.76 J1.349 E.05331
M73 P60 R7
G3 X93.152 Y124.073 I16.129 J24.952 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.333 J-31.521 E.1123
G3 X101.193 Y116.421 I3.822 J2.758 E.05061
G3 X102.951 Y115.816 I3.188 J6.405 E.0573
G2 X106.448 Y114.887 I-6.458 J-31.362 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.382 E.1709
G3 X113.32 Y110.795 I14.847 J18.907 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05819
G3 X117.867 Y110.517 I-7.449 J182.394 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21158
G3 X127.013 Y108.625 I13.21 J33.899 E.07784
G3 X128.133 Y108.474 I.997 J3.177 E.03487
G3 X129.793 Y108.888 I-.666 J6.209 E.05276
G2 X133.154 Y110.014 I13.011 J-33.263 E.10895
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.884 Y110.921 I-.11 J3.071 E.05321
G3 X144.706 Y112.222 I-15.542 J23.69 E.0688
G2 X149.556 Y114.887 I10.852 J-14.005 E.17075
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.77 Y116.394 I-1.342 J6.762 E.05576
G3 X155.765 Y117.301 I-2.181 J3.391 E.04156
G2 X157.819 Y119.952 I1367.901 J-1057.598 E.10305
G2 X162.618 Y123.937 I12.924 J-10.684 E.19279
G3 X164.784 Y125.21 I-16.307 J30.214 E.07722
G3 X166.104 Y126.854 I-1.827 J2.819 E.06588
G3 X167.3 Y129.94 I-592.302 J231.27 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.236 J17.521 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X159.92 Y140.129 Z3.4 F36000
G1 X167.597 Y132.209 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X168.477 Y133.578 I19.139 J-11.349 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X125.341 Y109.989 E1.62449
G3 X127.862 Y109.214 I5.234 J12.551 E.08765
G3 X129.55 Y109.588 I-.614 J6.78 E.05749
G1 X130.661 Y109.987 E.03915
G1 X96.032 Y144.616 E1.62453
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.827 J-11.767 E.054
G1 X102.064 Y142.685 F36000
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.25 J11.558 E.05398
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.923 J1.55 E.08651
G3 X93.83 Y124.534 I9.847 J13 E.10128
G1 X100.213 Y130.958 E.30039
G2 X100.011 Y132.961 I2.34 J1.247 E.06849
G1 X90.708 Y142.264 E.43643
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.13381
G2 X83.434 Y139.05 I1.843 J1.488 E.04916
G1 X85.385 Y139.911 E.07073
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.701 E.05406
G1 X126.65 Y123.933 F36000
G1 F15476.087
G3 X125.587 Y122.737 I1.353 J-2.273 E.05391
G1 X119.326 Y128.997 E.29368
G3 X120.891 Y128.567 I10.041 J33.461 E.05383
G1 X107.571 Y115.247 E.62487
G2 X112.36 Y112.361 I-8.189 J-19.004 E.18607
G1 X127.713 Y127.714 E.72024
G3 X128.286 Y127.714 I.288 J8.198 E.019
G1 X143.645 Y112.355 E.7205
G2 X148.43 Y115.246 I12.87 J-15.9 E.18603
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.448 J33.816 E.05372
G1 X130.416 Y122.741 E.29341
G3 X129.352 Y123.934 I-2.414 J-1.082 E.05391
G1 X140.386 Y111.134 F36000
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.381 E.05407
G1 X170.616 Y139.912 E1.34273
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.418 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X155.992 Y132.965 E.43628
G2 X155.776 Y130.928 I-2.874 J-.724 E.06938
G1 X162.172 Y124.532 E.30006
G3 X164.985 Y126.364 I-5.413 J11.384 E.11168
G3 X165.932 Y128.447 I-10.693 J6.122 E.07603
G1 X153.083 Y141.297 E.60279
G3 X153.939 Y142.682 I-19.42 J12.96 E.05402
; WIPE_START
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
; WIPE_END
G1 E-.04 F1800
G1 X145.934 Y139.212 Z3.4 F36000
G1 X113.77 Y131.309 Z3.4
G1 Z3
G1 E.8 F1800
G1 F15476.087
G3 X115.224 Y130.576 I15.769 J29.459 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.779 I1.392 J2.463 E.0386
G3 X98.118 Y121.147 I-32.801 J-23.332 E.14279
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I19.895 J26.818 E.18057
G1 X103.82 Y134.524 E.11678
G2 X103.304 Y129.668 I-1.314 J-2.316 E.205
G1 X122.015 Y110.957 E.87778
G3 X118.944 Y111.268 I-4.387 J-27.976 E.10243
G1 X126.919 Y119.244 E.37413
G3 X129.082 Y119.242 I1.083 J2.753 E.07344
G1 X137.055 Y111.268 E.37406
G3 X133.984 Y110.956 I1.331 J-28.35 E.10248
G1 X152.697 Y129.669 E.87789
G2 X152.182 Y134.522 I.762 J2.535 E.20593
G1 X149.69 Y137.014 E.11689
G2 X145.602 Y133.425 I-24.711 J24.031 E.18062
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.324 I24.836 J-22.125 E.11974
G2 X154.34 Y117.012 I-5.154 J3.79 E.06133
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.34 J30.252 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 3.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
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
G1 X125.719 Y121.366
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.784 Y121.049 E.01073
G3 X127.826 Y119.362 I2.219 J.606 E.09364
G3 X128.666 Y119.46 I.138 J2.475 E.02818
G1 X128.864 Y119.522 E.00689
G3 X125.714 Y121.426 I-.861 J2.133 E.33798
G1 X126.107 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.896 J.216 E.08092
G3 X128.547 Y119.833 I.114 J2.058 E.02148
G1 X128.717 Y119.887 E.00546
G3 X126.101 Y121.5 I-.714 J1.769 E.25858
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.13379
G1 X126.259 Y120.878 E-.11117
G1 X126.314 Y120.776 E-.04371
G1 X126.399 Y120.621 E-.06744
G1 X126.576 Y120.388 E-.11116
G1 X126.787 Y120.185 E-.11116
G1 X127.026 Y120.017 E-.11115
G1 X127.192 Y119.935 E-.07041
; WIPE_END
G1 E-.04 F1800
G1 X120.107 Y122.773 Z3.6 F36000
G1 X102.256 Y129.924 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.37 Y129.906 E.00383
G1 X102.723 Y129.906 E.0117
G3 X102.022 Y129.96 I-.176 J2.294 E.45617
G1 X102.197 Y129.933 E.00588
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00899
G3 X102.341 Y130.304 I-.146 J1.903 E.35758
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13382
G1 X102.982 Y130.343 E-.11119
G1 X103.261 Y130.431 E-.11114
G1 X103.523 Y130.561 E-.11114
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11113
G1 X104.085 Y131.079 E-.07041
; WIPE_END
G1 E-.04 F1800
G1 X111.717 Y131.16 Z3.6 F36000
G1 X155.685 Y131.621 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.744 Y131.939 E.01073
G3 X153.282 Y129.906 I-2.286 J.26 E.3624
G1 X153.634 Y129.906 E.0117
G3 X155.669 Y131.564 I-.176 J2.294 E.09263
G1 X155.302 Y131.704 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.354 Y131.984 E.00878
G3 X153.312 Y130.298 I-1.896 J.216 E.2784
G1 X153.604 Y130.298 E.00899
G3 X155.284 Y131.646 I-.146 J1.902 E.07031
; WIPE_START
M204 S10000
G1 X155.354 Y131.984 E-.13114
G1 X155.367 Y132.276 E-.11106
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11114
G1 X155.137 Y133.116 E-.11116
G1 X154.978 Y133.362 E-.11115
G1 X154.85 Y133.505 E-.07316
; WIPE_END
G1 E-.04 F1800
G1 X155.269 Y141.126 Z3.6 F36000
G1 X155.589 Y146.934 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.58 J.167 E.04815
G3 X84.377 Y136.65 I5.975 J3.759 E.05162
G2 X86.79 Y133.985 I-24.732 J-24.818 E.1193
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18944
G3 X90.41 Y126.674 I23.329 J7.825 E.0825
G3 X91.435 Y125.548 I2.422 J1.175 E.05122
G3 X93.349 Y124.413 I15.948 J24.699 E.07381
G2 X98.06 Y120.701 I-8.564 J-15.715 E.1999
G2 X100.325 Y117.807 I-37.423 J-31.618 E.12194
G3 X101.394 Y116.758 I3.536 J2.536 E.04994
G3 X103.044 Y116.197 I3.009 J6.144 E.05796
G2 X106.577 Y115.257 I-6.546 J-31.734 E.12132
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18842
G3 X113.513 Y111.136 I14.723 J18.742 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.765 J188.192 E.08995
G2 X124.754 Y109.831 I.851 J-17.19 E.2333
G3 X127.354 Y108.943 I11.095 J28.212 E.09117
G3 X128.182 Y108.871 I.644 J2.635 E.0277
G3 X129.664 Y109.258 I-.809 J6.127 E.05092
G2 X133.389 Y110.477 I12.295 J-31.277 E.1301
G2 X138.729 Y110.881 I3.984 J-17.198 E.17831
G3 X141.236 Y110.779 I2.303 J25.773 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.398 J23.438 E.07317
G2 X149.428 Y115.257 I11.08 J-14.313 E.18822
G2 X152.965 Y116.193 I9.839 J-30.041 E.12144
G3 X154.57 Y116.731 I-1.274 J6.461 E.05629
G3 X155.674 Y117.809 I-2.603 J3.772 E.05145
G2 X157.946 Y120.702 I41.968 J-30.616 E.12202
G2 X162.421 Y124.276 I12.715 J-11.333 E.1909
G3 X164.758 Y125.673 I-13.535 J25.278 E.09034
G3 X165.746 Y127.012 I-1.782 J2.349 E.05595
G3 X166.938 Y130.092 I-676.92 J263.992 E.10954
G2 X170.649 Y135.623 I16.058 J-6.762 E.22233
G3 X172.333 Y137.457 I-17.038 J17.331 E.08261
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.949 Y137.916 I5.287 J.204 E.05001
G3 X83.717 Y136.795 I3.846 J1.811 E.04194
G2 X85.862 Y134.489 I-442.595 J-413.913 E.09676
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.453 J7.87 E.07788
G3 X91.212 Y125.225 I2.764 J1.352 E.0533
G3 X93.152 Y124.073 I16.128 J24.95 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.34 J-31.527 E.1123
G3 X101.193 Y116.421 I3.822 J2.758 E.05062
G3 X102.951 Y115.816 I3.187 J6.405 E.05729
G2 X106.448 Y114.887 I-6.459 J-31.367 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.852 J18.914 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.448 J182.386 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.203 J33.88 E.07783
G3 X128.216 Y108.481 I.983 J3.111 E.03745
G3 X129.793 Y108.888 I-.839 J6.502 E.05017
G2 X133.154 Y110.014 I13.011 J-33.263 E.10895
G2 X138.707 Y110.489 I4.212 J-16.533 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05323
G3 X144.706 Y112.222 I-15.549 J23.698 E.06878
G2 X149.556 Y114.887 I10.851 J-14.003 E.17075
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.771 Y116.394 I-1.342 J6.762 E.05577
G3 X155.765 Y117.3 I-2.181 J3.39 E.04153
G2 X157.819 Y119.952 I1394.883 J-1078.504 E.10306
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.308 J30.215 E.07721
G3 X166.104 Y126.854 I-1.827 J2.82 E.06588
G3 X167.3 Y129.94 I-592.302 J231.27 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.228 J17.513 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.393 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38731
G1 X154.608 Y145.61 E-.07071
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z3.6 F36000
G1 Z3.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.266 J11.569 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.652 J1.407 E.08776
G2 X162.172 Y124.532 I-25.06 J37.928 E.10007
G1 X155.776 Y130.928 E.30006
G3 X155.992 Y132.965 I-2.658 J1.313 E.06938
G1 X165.292 Y142.265 E.43628
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.907 J1.491 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34272
G2 X140.386 Y111.134 I-1.124 J3.223 E.05407
G1 X129.352 Y123.934 F36000
G1 F15476.087
G2 X130.416 Y122.741 I-1.349 J-2.275 E.05391
G1 X136.671 Y128.995 E.29341
G2 X135.109 Y128.566 I-26.492 J93.395 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.645 Y112.355 I8.087 J-18.794 E.18603
G1 X128.286 Y127.714 E.7205
G2 X127.713 Y127.714 I-.285 J8.198 E.019
G1 X112.36 Y112.361 E.72024
G3 X107.571 Y115.247 I-12.977 J-16.115 E.18607
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.489 J33.939 E.05383
G1 X125.587 Y122.737 E.29368
G2 X126.65 Y123.933 I2.416 J-1.078 E.05391
G1 X115.627 Y111.14 F36000
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.84 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.366 J.127 E.04916
G1 X86.809 Y140.541 E.13381
G1 X90.708 Y142.264 E.14141
G1 X100.011 Y132.961 E.43643
G3 X100.227 Y130.931 I2.539 J-.756 E.0695
G1 X93.83 Y124.534 E.30011
G2 X90.989 Y126.401 I5.513 J11.484 E.11311
G2 X90.068 Y128.448 I10.552 J5.974 E.07458
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.046 J23.848 E.05401
G1 X88.404 Y132.211 F36000
G1 F15476.087
G3 X87.525 Y133.581 I-17.709 J-10.399 E.054
M73 P61 R7
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.659 Y109.989 E1.62444
G2 X128.156 Y109.22 I-4.593 J10.499 E.08704
G2 X126.631 Y109.521 I.054 J4.296 E.05186
G1 X125.341 Y109.989 E.04553
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.239 J-12.705 E.054
; WIPE_START
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
; WIPE_END
G1 E-.04 F1800
G1 X160.618 Y133.101 Z3.6 F36000
G1 X142.231 Y131.307 Z3.6
G1 Z3.2
G1 E.8 F1800
G1 F15476.087
G2 X140.777 Y130.574 I-15.794 J29.519 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.634 Y118.324 I-3.853 J5.095 E.06134
G2 X157.884 Y121.144 I27.091 J-19.308 E.11974
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-18.113 J24.796 E.18067
G1 X152.182 Y134.522 E.11675
G3 X152.697 Y129.669 I1.316 J-2.314 E.20476
G1 X133.984 Y110.956 E.87789
G2 X137.055 Y111.268 I4.402 J-28.035 E.10248
G1 X129.082 Y119.242 E.37405
G2 X126.919 Y119.244 I-1.079 J2.441 E.07387
G1 X118.944 Y111.268 E.37413
G2 X122.015 Y110.957 I-1.316 J-28.286 E.10243
G1 X103.304 Y129.668 E.87778
G3 X103.82 Y134.524 I-.759 J2.536 E.2062
G1 X106.309 Y137.013 E.11678
G3 X110.399 Y133.428 I22.212 J21.213 E.18067
G1 X98.118 Y121.146 E.57613
G2 X100.796 Y117.779 I-30.112 J-26.69 E.14279
G3 X101.665 Y117.017 I2.261 J1.701 E.0386
G1 X115.224 Y130.576 E.6361
G2 X113.77 Y131.309 I14.318 J30.196 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 3.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X115.224 Y130.576 E-.61863
G1 X114.961 Y130.313 E-.14137
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
G1 X125.719 Y121.366
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.781 Y121.049 E.01072
G3 X127.826 Y119.362 I2.221 J.61 E.09369
G1 X128.179 Y119.362 E.0117
G3 X125.711 Y121.425 I-.176 J2.297 E.36202
G1 X126.104 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.898 J.219 E.08097
G1 X128.149 Y119.754 E.00899
G3 X126.098 Y121.5 I-.146 J1.905 E.27703
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.13385
G1 X126.309 Y120.786 E-.15058
G1 X126.399 Y120.621 E-.0714
G1 X126.576 Y120.388 E-.11116
G1 X126.787 Y120.185 E-.11116
G1 X127.026 Y120.017 E-.11115
G1 X127.193 Y119.934 E-.07071
; WIPE_END
G1 E-.04 F1800
G1 X120.114 Y122.787 Z3.8 F36000
G1 X102.451 Y129.906 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.723 Y129.906 E.00902
G3 X102.37 Y129.906 I-.176 J2.294 E.46776
G1 X102.391 Y129.906 E.00069
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00899
G3 X102.341 Y130.304 I-.146 J1.902 E.35749
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13382
G1 X102.982 Y130.343 E-.11119
G1 X103.261 Y130.431 E-.11114
G1 X103.523 Y130.561 E-.11114
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11113
G1 X104.085 Y131.079 E-.07041
; WIPE_END
G1 E-.04 F1800
G1 X111.717 Y131.16 Z3.8 F36000
G1 X155.685 Y131.622 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.745 Y131.939 E.01072
G3 X153.282 Y129.906 I-2.287 J.262 E.36266
G1 X153.634 Y129.906 E.0117
G3 X155.67 Y131.564 I-.176 J2.295 E.09266
G1 X155.302 Y131.705 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.355 Y131.984 E.00874
G3 X153.312 Y130.298 I-1.897 J.217 E.27861
G1 X153.604 Y130.298 E.00899
G3 X155.285 Y131.647 I-.146 J1.903 E.07036
; WIPE_START
M204 S10000
G1 X155.355 Y131.984 E-.13073
G1 X155.367 Y132.276 E-.11109
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11116
G1 X155.137 Y133.116 E-.11114
G1 X154.978 Y133.362 E-.11116
G1 X154.849 Y133.506 E-.07355
; WIPE_END
G1 E-.04 F1800
G1 X155.269 Y141.127 Z3.8 F36000
G1 X155.589 Y146.934 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.718 E2.35658
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.58 J.167 E.04815
G3 X84.377 Y136.65 I5.974 J3.758 E.05162
G2 X86.79 Y133.986 I-24.737 J-24.822 E.11928
G2 X89.501 Y128.988 I-13.843 J-10.746 E.18946
G3 X90.41 Y126.674 I23.305 J7.816 E.0825
G3 X91.435 Y125.548 I2.422 J1.175 E.05122
G3 X93.349 Y124.413 I15.951 J24.704 E.07381
G2 X98.059 Y120.702 I-8.564 J-15.715 E.19987
G2 X100.325 Y117.807 I-37.4 J-31.601 E.12197
G3 X101.394 Y116.758 I3.536 J2.535 E.04994
G3 X103.044 Y116.197 I2.963 J6.009 E.05797
G2 X106.576 Y115.257 I-6.545 J-31.731 E.12132
G2 X111.534 Y112.534 I-5.975 J-16.749 E.18843
G3 X113.513 Y111.136 I14.727 J18.747 E.0804
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.766 J188.209 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.354 Y108.943 I11.095 J28.214 E.09117
G3 X128.183 Y108.872 I.643 J2.634 E.02771
G3 X129.664 Y109.258 I-.81 J6.129 E.05091
G2 X133.389 Y110.477 I12.295 J-31.275 E.1301
G2 X138.729 Y110.881 I3.984 J-17.198 E.17831
G3 X141.236 Y110.779 I2.303 J25.773 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05114
G3 X144.474 Y112.538 I-15.394 J23.432 E.07314
G2 X149.428 Y115.257 I11.081 J-14.314 E.18824
G2 X152.965 Y116.193 I9.84 J-30.043 E.12145
G3 X154.57 Y116.731 I-1.273 J6.459 E.05629
G3 X155.674 Y117.809 I-2.603 J3.772 E.05146
G2 X157.946 Y120.702 I41.968 J-30.615 E.12201
G2 X162.421 Y124.276 I12.716 J-11.334 E.19091
G3 X164.757 Y125.673 I-13.532 J25.273 E.09033
G3 X165.746 Y127.012 I-1.781 J2.348 E.05596
G3 X166.938 Y130.092 I-673.426 J262.642 E.10954
G2 X170.649 Y135.623 I16.057 J-6.761 E.22231
G3 X172.333 Y137.457 I-17.049 J17.342 E.08262
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.195 E2.17924
G1 X82.639 Y139.508 E.60452
G3 X82.948 Y137.918 I5.294 J.205 E.04995
G3 X83.717 Y136.795 I3.843 J1.806 E.04199
G2 X85.862 Y134.489 I-445.469 J-416.584 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.433 J7.862 E.07788
G3 X91.212 Y125.225 I2.765 J1.352 E.0533
G3 X93.152 Y124.073 I16.134 J24.959 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.336 J-31.524 E.1123
G3 X101.193 Y116.421 I3.822 J2.758 E.05061
G3 X102.951 Y115.816 I3.144 J6.277 E.05731
G2 X106.448 Y114.887 I-6.458 J-31.366 E.11123
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.853 J18.915 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.449 J182.402 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.205 J33.886 E.07783
G3 X128.217 Y108.481 I.983 J3.111 E.03745
G3 X129.793 Y108.888 I-.839 J6.502 E.05017
G2 X133.154 Y110.014 I13.01 J-33.26 E.10895
G2 X138.707 Y110.489 I4.212 J-16.533 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05323
G3 X144.706 Y112.222 I-15.549 J23.698 E.06878
G2 X149.556 Y114.887 I10.852 J-14.004 E.17075
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.77 Y116.394 I-1.342 J6.762 E.05577
G3 X155.764 Y117.3 I-2.18 J3.39 E.04153
G2 X157.819 Y119.952 I1389.969 J-1074.713 E.10309
G2 X162.618 Y123.937 I12.924 J-10.684 E.19279
G3 X164.784 Y125.21 I-16.293 J30.19 E.07721
G3 X166.104 Y126.853 I-1.827 J2.82 E.06588
G3 X167.3 Y129.94 I-590.824 J230.699 E.10171
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.23 J17.514 E.07791
G3 X173.302 Y138.956 I-2.618 J1.981 E.05776
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X159.92 Y140.129 Z3.8 F36000
G1 X167.597 Y132.209 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X168.477 Y133.578 I19.134 J-11.345 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X125.341 Y109.989 E1.62449
G3 X127.741 Y109.227 I5.084 J11.858 E.08369
G3 X129.208 Y109.472 I.153 J3.601 E.04968
G1 X130.659 Y109.989 E.0511
G1 X96.032 Y144.616 E1.62444
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.847 J-11.779 E.054
G1 X102.064 Y142.685 F36000
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.25 J11.558 E.05398
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.926 J1.552 E.0865
G3 X93.83 Y124.534 I9.842 J12.991 E.10129
G1 X100.227 Y130.931 E.30011
G1 X100.203 Y130.976 E.0017
G2 X100.011 Y132.961 I2.709 J1.263 E.06743
G1 X90.708 Y142.264 E.43643
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.13381
G2 X83.434 Y139.05 I1.843 J1.488 E.04916
G1 X85.385 Y139.911 E.07073
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.698 E.05406
G1 X126.65 Y123.933 F36000
G1 F15476.087
G3 X125.587 Y122.737 I1.353 J-2.273 E.05391
G1 X119.326 Y128.997 E.29368
G3 X120.891 Y128.567 I10.051 J33.499 E.05383
G1 X107.571 Y115.247 E.62487
G2 X112.36 Y112.361 I-8.188 J-19.002 E.18607
G1 X127.713 Y127.714 E.72024
G3 X128.286 Y127.714 I.288 J8.198 E.019
G1 X143.645 Y112.355 E.7205
G2 X148.43 Y115.246 I12.871 J-15.901 E.18603
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.445 J33.806 E.05372
G1 X130.416 Y122.741 E.29341
G3 X129.352 Y123.934 I-2.414 J-1.082 E.05391
G1 X140.386 Y111.134 F36000
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.379 E.05407
G1 X170.616 Y139.912 E1.34273
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.418 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X155.992 Y132.965 E.43628
G2 X155.776 Y130.928 I-2.874 J-.724 E.06938
G1 X162.175 Y124.529 E.30018
G3 X164.62 Y126.008 I-7.834 J15.72 E.0949
G3 X165.684 Y127.785 I-2.303 J2.586 E.06978
G1 X165.932 Y128.447 E.02347
G1 X153.083 Y141.297 E.6028
G3 X153.939 Y142.682 I-19.42 J12.96 E.05402
; WIPE_START
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
; WIPE_END
G1 E-.04 F1800
G1 X145.934 Y139.212 Z3.8 F36000
G1 X113.77 Y131.309 Z3.8
G1 Z3.4
G1 E.8 F1800
G1 F15476.087
G3 X115.224 Y130.576 I15.772 J29.463 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.778 I1.392 J2.463 E.03858
G3 X98.118 Y121.147 I-32.813 J-23.341 E.14281
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.74 J27.782 E.18056
G1 X103.82 Y134.524 E.11678
G2 X103.304 Y129.668 I-1.313 J-2.316 E.20502
G1 X122.015 Y110.957 E.87778
G3 X118.944 Y111.268 I-4.387 J-27.98 E.10243
G1 X126.919 Y119.244 E.37413
G3 X129.082 Y119.242 I1.083 J2.439 E.07387
G1 X137.055 Y111.268 E.37405
G3 X133.984 Y110.956 I1.331 J-28.348 E.10248
G1 X152.697 Y129.669 E.87789
G2 X152.182 Y134.522 I.762 J2.535 E.20593
G1 X149.693 Y137.011 E.11675
G2 X145.602 Y133.425 I-23.376 J22.547 E.18065
G1 X157.884 Y121.144 E.57615
G3 X155.634 Y118.324 I24.835 J-22.123 E.11974
G2 X154.34 Y117.012 I-5.146 J3.782 E.06134
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.34 J30.252 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 3.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
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
G1 X125.719 Y121.366
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.784 Y121.049 E.0107
G3 X127.826 Y119.362 I2.219 J.606 E.09365
G3 X128.646 Y119.453 I.136 J2.5 E.02749
G1 X128.864 Y119.522 E.00758
G3 X125.714 Y121.425 I-.861 J2.133 E.33801
G1 X126.107 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.896 J.216 E.08092
G3 X128.527 Y119.827 I.112 J2.089 E.02084
G1 X128.717 Y119.887 E.00609
G3 X126.101 Y121.5 I-.714 J1.769 E.25858
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.13379
G1 X126.259 Y120.878 E-.11117
G1 X126.399 Y120.621 E-.11118
G1 X126.576 Y120.388 E-.11112
G1 X126.787 Y120.185 E-.11119
G1 X127.026 Y120.017 E-.11114
G1 X127.192 Y119.935 E-.07042
; WIPE_END
M73 P62 R7
G1 E-.04 F1800
G1 X120.108 Y122.777 Z4 F36000
G1 X102.322 Y129.914 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.37 Y129.906 E.00162
G3 X103.19 Y129.998 I.137 J2.499 E.02749
G1 X103.408 Y130.066 E.00758
G3 X102.022 Y129.96 I-.861 J2.134 E.43269
G1 X102.263 Y129.923 E.00809
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X103.072 Y130.371 I.112 J2.088 E.02084
G1 X103.261 Y130.431 E.0061
G3 X102.341 Y130.304 I-.714 J1.77 E.33957
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13382
G1 X103.072 Y130.371 E-.14665
G1 X103.261 Y130.431 E-.07538
G1 X103.523 Y130.561 E-.11112
G1 X103.762 Y130.729 E-.11118
G1 X103.973 Y130.932 E-.11115
G1 X104.08 Y131.084 E-.07071
; WIPE_END
G1 E-.04 F1800
G1 X111.712 Y131.164 Z4 F36000
G1 X155.685 Y131.622 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.74 Y131.94 E.01069
G3 X155.746 Y132.415 I-2.29 J.265 E.01579
G3 X153.282 Y129.906 I-2.289 J-.216 E.34641
G3 X155.665 Y131.566 I.169 J2.299 E.10423
G1 X155.302 Y131.706 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.354 Y131.984 E.0087
G3 X153.312 Y130.298 I-1.896 J.216 E.27845
G3 X153.983 Y130.371 I.112 J2.088 E.02084
G1 X154.172 Y130.431 E.0061
G3 X155.285 Y131.649 I-.714 J1.77 E.05241
; WIPE_START
M204 S10000
G1 X155.354 Y131.984 E-.13023
G1 X155.357 Y132.37 E-.14654
G1 X155.334 Y132.567 E-.07537
G1 X155.256 Y132.849 E-.11116
G1 X155.137 Y133.116 E-.11114
G1 X154.978 Y133.362 E-.11116
G1 X154.847 Y133.508 E-.0744
; WIPE_END
G1 E-.04 F1800
G1 X155.268 Y141.129 Z4 F36000
G1 X155.589 Y146.934 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.718 E2.35658
G1 X83.055 Y139.263 E.6296
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.971 J3.756 E.05161
G2 X86.79 Y133.985 I-24.735 J-24.821 E.11931
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18944
G3 X90.41 Y126.674 I23.295 J7.812 E.08252
G3 X91.435 Y125.548 I2.422 J1.176 E.0512
G3 X93.349 Y124.413 I15.95 J24.703 E.07381
G2 X98.06 Y120.701 I-8.564 J-15.715 E.19989
G2 X100.325 Y117.806 I-37.409 J-31.607 E.12196
G3 X101.394 Y116.758 I3.536 J2.535 E.04993
G3 X103.044 Y116.197 I3.009 J6.143 E.05796
G2 X106.577 Y115.257 I-6.545 J-31.731 E.12132
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18842
G3 X113.513 Y111.136 I14.72 J18.737 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05612
G3 X117.853 Y110.909 I-7.765 J188.201 E.08995
G2 X124.754 Y109.831 I.851 J-17.19 E.2333
G3 X127.353 Y108.943 I11.097 J28.218 E.09117
G3 X128.183 Y108.872 I.644 J2.634 E.02771
G3 X129.664 Y109.258 I-.809 J6.129 E.05091
G2 X133.389 Y110.477 I12.294 J-31.275 E.1301
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.773 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.379 J23.413 E.07317
G2 X149.428 Y115.257 I11.08 J-14.313 E.18822
G2 X152.965 Y116.193 I9.839 J-30.039 E.12144
G3 X154.569 Y116.731 I-1.274 J6.463 E.05629
G3 X155.674 Y117.809 I-2.602 J3.771 E.05146
G2 X157.946 Y120.702 I41.976 J-30.622 E.12202
G2 X162.421 Y124.276 I12.715 J-11.333 E.1909
G3 X164.757 Y125.673 I-13.538 J25.283 E.09034
G3 X165.746 Y127.012 I-1.781 J2.349 E.05597
G3 X166.938 Y130.091 I-673.7 J262.745 E.10953
G2 X170.649 Y135.623 I16.057 J-6.761 E.22232
G3 X172.333 Y137.457 I-17.043 J17.337 E.08263
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.195 E2.17924
G1 X82.639 Y139.508 E.60452
G3 X82.947 Y137.92 I5.301 J.206 E.04988
G3 X83.717 Y136.795 I3.842 J1.802 E.04207
G2 X85.862 Y134.489 I-444.738 J-415.906 E.09676
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.431 J7.861 E.07788
G3 X91.212 Y125.225 I2.765 J1.353 E.0533
G3 X93.152 Y124.073 I16.131 J24.955 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18128
G2 X100.018 Y117.563 I-37.327 J-31.518 E.11231
G3 X101.193 Y116.421 I3.821 J2.758 E.05062
G3 X102.951 Y115.816 I3.187 J6.404 E.05729
G2 X106.448 Y114.887 I-6.459 J-31.367 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.85 J18.911 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.449 J182.394 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.208 J33.895 E.07783
G3 X128.217 Y108.481 I.983 J3.111 E.03745
G3 X129.793 Y108.888 I-.839 J6.502 E.05017
G2 X133.154 Y110.014 I13.008 J-33.254 E.10895
G2 X138.707 Y110.489 I4.211 J-16.533 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05323
G3 X144.706 Y112.222 I-15.54 J23.686 E.06878
G2 X149.556 Y114.887 I10.851 J-14.004 E.17075
G2 X153.056 Y115.812 I9.715 J-29.681 E.11131
G3 X154.77 Y116.394 I-1.342 J6.764 E.05577
G3 X155.764 Y117.3 I-2.18 J3.391 E.04153
G2 X157.819 Y119.952 I1383.016 J-1069.319 E.10307
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.317 J30.231 E.07721
G3 X166.104 Y126.854 I-1.827 J2.82 E.06588
G3 X167.3 Y129.94 I-592.302 J231.27 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.226 J17.512 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.393 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z4 F36000
G1 Z3.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.266 J11.569 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.654 J1.407 E.08775
G2 X162.172 Y124.532 I-25.056 J37.919 E.10008
G1 X155.776 Y130.928 E.30006
G3 X155.992 Y132.965 I-2.323 J1.277 E.06976
G1 X165.292 Y142.265 E.43628
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.909 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34272
G2 X140.386 Y111.134 I-1.124 J3.223 E.05407
G1 X129.352 Y123.934 F36000
G1 F15476.087
G2 X130.416 Y122.741 I-1.349 J-2.275 E.05391
G1 X136.671 Y128.995 E.29341
G2 X135.109 Y128.566 I-10.007 J33.377 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.645 Y112.355 I8.087 J-18.793 E.18603
G1 X128.286 Y127.714 E.7205
G2 X127.713 Y127.714 I-.285 J8.198 E.019
G1 X112.36 Y112.361 E.72024
G3 X107.571 Y115.247 I-12.977 J-16.116 E.18607
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.486 J33.929 E.05383
G1 X125.587 Y122.737 E.29368
G2 X126.65 Y123.933 I2.416 J-1.078 E.05391
G1 X115.627 Y111.14 F36000
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.842 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.365 J.127 E.04916
G1 X86.809 Y140.541 E.13381
G1 X90.708 Y142.264 E.14141
G1 X100.011 Y132.961 E.43643
G3 X100.227 Y130.931 I2.877 J-.72 E.06912
G1 X93.83 Y124.534 E.30011
G2 X90.989 Y126.401 I5.513 J11.485 E.1131
G2 X90.068 Y128.448 I10.542 J5.97 E.07458
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.046 J23.848 E.05401
G1 X88.404 Y132.211 F36000
G1 F15476.087
G3 X87.525 Y133.581 I-17.719 J-10.405 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.659 Y109.989 E1.62444
G2 X128.157 Y109.22 I-4.595 J10.504 E.08703
G2 X126.63 Y109.521 I.054 J4.295 E.05189
G1 X125.341 Y109.989 E.04552
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.248 J-12.71 E.054
; WIPE_START
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
; WIPE_END
G1 E-.04 F1800
G1 X160.618 Y133.101 Z4 F36000
G1 X142.231 Y131.307 Z4
G1 Z3.6
G1 E.8 F1800
G1 F15476.087
G2 X140.777 Y130.574 I-15.8 J29.531 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.633 Y118.323 I-3.853 J5.094 E.06132
G2 X157.884 Y121.144 I27.094 J-19.31 E.11975
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-19.349 J26.206 E.18065
G1 X152.182 Y134.522 E.11675
G3 X152.697 Y129.669 I1.316 J-2.314 E.20476
G1 X133.984 Y110.956 E.87789
G2 X137.055 Y111.268 I4.402 J-28.035 E.10248
G1 X129.082 Y119.242 E.37406
G2 X126.919 Y119.244 I-1.079 J2.755 E.07344
G1 X118.944 Y111.268 E.37413
G2 X122.015 Y110.957 I-1.316 J-28.286 E.10243
G1 X103.304 Y129.668 E.87778
G3 X103.82 Y134.524 I-.759 J2.536 E.2062
G1 X106.309 Y137.013 E.11678
G3 X110.399 Y133.428 I22.211 J21.212 E.18067
G1 X98.118 Y121.146 E.57613
G2 X100.796 Y117.779 I-30.119 J-26.696 E.1428
G3 X101.665 Y117.017 I2.26 J1.701 E.03859
G1 X115.224 Y130.576 E.63609
G2 X113.77 Y131.309 I14.316 J30.192 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 3.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X115.224 Y130.576 E-.61863
G1 X114.961 Y130.313 E-.14137
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
G1 X125.719 Y121.366
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.784 Y121.049 E.0107
G3 X127.826 Y119.362 I2.219 J.606 E.09365
G1 X128.179 Y119.362 E.0117
G3 X125.714 Y121.425 I-.176 J2.293 E.36126
G1 X126.107 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.895 J.216 E.08093
G1 X128.149 Y119.754 E.00899
G3 X126.101 Y121.5 I-.146 J1.902 E.27649
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.13379
G1 X126.259 Y120.877 E-.1112
G1 X126.399 Y120.621 E-.11112
G1 X126.576 Y120.388 E-.11114
G1 X126.787 Y120.185 E-.11119
G1 X127.026 Y120.017 E-.11114
G1 X127.192 Y119.935 E-.07043
; WIPE_END
G1 E-.04 F1800
G1 X120.112 Y122.785 Z4.2 F36000
G1 X102.42 Y129.906 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.723 Y129.906 E.01005
G3 X102.36 Y129.907 I-.176 J2.295 E.46775
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00899
G3 X102.341 Y130.304 I-.146 J1.904 E.35777
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13382
G1 X102.982 Y130.343 E-.11116
G1 X103.261 Y130.431 E-.11118
G1 X103.523 Y130.561 E-.11114
G1 X103.762 Y130.729 E-.11116
G1 X103.973 Y130.932 E-.11115
G1 X104.085 Y131.079 E-.07039
; WIPE_END
G1 E-.04 F1800
G1 X111.717 Y131.16 Z4.2 F36000
G1 X155.685 Y131.622 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.744 Y131.939 E.01071
G3 X153.282 Y129.906 I-2.286 J.261 E.36249
G1 X153.634 Y129.906 E.0117
G3 X155.669 Y131.564 I-.176 J2.294 E.09266
G1 X155.303 Y131.708 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.355 Y131.984 E.00865
G3 X153.312 Y130.298 I-1.897 J.218 E.27866
G1 X153.604 Y130.298 E.00899
G3 X155.286 Y131.65 I-.146 J1.904 E.07045
; WIPE_START
M204 S10000
G1 X155.355 Y131.984 E-.12969
G1 X155.367 Y132.276 E-.11109
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11115
G1 X155.137 Y133.116 E-.11116
G1 X154.978 Y133.362 E-.11114
G1 X154.847 Y133.508 E-.07458
; WIPE_END
G1 E-.04 F1800
G1 X155.268 Y141.129 Z4.2 F36000
G1 X155.589 Y146.934 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.718 E2.35658
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.974 J3.759 E.05161
G2 X86.79 Y133.986 I-24.727 J-24.814 E.11928
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.333 J7.827 E.0825
G3 X91.435 Y125.548 I2.417 J1.171 E.05122
G3 X93.349 Y124.413 I15.955 J24.711 E.07381
G2 X98.06 Y120.701 I-8.564 J-15.715 E.1999
G2 X100.325 Y117.806 I-37.424 J-31.618 E.12194
G3 X101.394 Y116.758 I3.536 J2.535 E.04994
G3 X103.044 Y116.197 I3.008 J6.141 E.05796
G2 X106.577 Y115.257 I-6.546 J-31.734 E.12133
G2 X111.533 Y112.534 I-5.974 J-16.747 E.1884
G3 X113.513 Y111.136 I14.732 J18.754 E.08042
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.766 J188.211 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.104 J28.24 E.09117
G3 X128.183 Y108.872 I.644 J2.634 E.02772
G3 X129.664 Y109.258 I-.81 J6.13 E.0509
G2 X133.389 Y110.477 I12.295 J-31.277 E.1301
G2 X138.729 Y110.881 I3.984 J-17.198 E.17831
G3 X141.236 Y110.779 I2.303 J25.773 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.38 J23.414 E.07317
G2 X149.428 Y115.257 I11.081 J-14.314 E.18823
G2 X152.965 Y116.193 I9.84 J-30.043 E.12145
G3 X154.57 Y116.731 I-1.273 J6.461 E.05629
G3 X155.674 Y117.809 I-2.602 J3.771 E.05145
G2 X157.946 Y120.702 I41.987 J-30.631 E.12202
G2 X162.421 Y124.276 I12.716 J-11.334 E.19091
G3 X164.758 Y125.674 I-13.532 J25.272 E.09035
G3 X165.746 Y127.013 I-1.781 J2.348 E.05598
G3 X166.938 Y130.091 I-684.527 J266.928 E.10951
G2 X170.649 Y135.623 I16.058 J-6.762 E.22234
G3 X172.333 Y137.457 I-17.037 J17.33 E.08261
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.195 E2.17924
G1 X82.639 Y139.508 E.60452
G3 X82.947 Y137.922 I5.308 J.207 E.04983
G3 X83.717 Y136.795 I3.84 J1.798 E.04213
G2 X85.862 Y134.489 I-443.513 J-414.765 E.09676
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.457 J7.872 E.07787
G3 X91.212 Y125.225 I2.76 J1.348 E.05331
G3 X93.152 Y124.073 I16.131 J24.954 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.017 Y117.563 I-37.323 J-31.513 E.11228
G3 X101.193 Y116.421 I3.822 J2.757 E.05063
G3 X102.951 Y115.816 I3.187 J6.402 E.05729
G2 X106.448 Y114.887 I-6.459 J-31.369 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.854 J18.916 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.449 J182.403 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.211 J33.902 E.07783
G3 X128.217 Y108.481 I.983 J3.112 E.03746
G3 X129.793 Y108.888 I-.839 J6.502 E.05017
G2 X133.154 Y110.014 I13.011 J-33.263 E.10895
G2 X138.707 Y110.489 I4.212 J-16.533 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05322
G3 X144.706 Y112.222 I-15.528 J23.669 E.06879
G2 X149.556 Y114.887 I10.852 J-14.005 E.17076
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
M73 P63 R7
G3 X154.77 Y116.394 I-1.342 J6.763 E.05577
G3 X155.764 Y117.3 I-2.181 J3.391 E.04153
G2 X157.819 Y119.952 I1393.81 J-1077.681 E.10307
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.309 J30.218 E.07722
G3 X166.104 Y126.854 I-1.828 J2.82 E.0659
G3 X167.3 Y129.94 I-598.467 J233.65 E.10168
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.225 J17.51 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X159.92 Y140.129 Z4.2 F36000
G1 X167.597 Y132.209 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X168.477 Y133.578 I19.136 J-11.346 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X125.341 Y109.989 E1.62449
G3 X127.741 Y109.227 I5.084 J11.857 E.08368
G3 X129.209 Y109.472 I.153 J3.601 E.04972
G1 X130.659 Y109.989 E.05107
G1 X96.032 Y144.616 E1.62444
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.836 J-11.773 E.054
G1 X102.064 Y142.685 F36000
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.25 J11.558 E.05398
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.926 J1.552 E.0865
G3 X93.83 Y124.534 I9.842 J12.99 E.10129
G1 X100.227 Y130.931 E.30011
G2 X100.011 Y132.961 I2.661 J1.309 E.06912
G1 X90.708 Y142.264 E.43643
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.13381
G2 X83.434 Y139.05 I1.844 J1.488 E.04916
G1 X85.385 Y139.911 E.07074
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.699 E.05406
G1 X126.65 Y123.933 F36000
G1 F15476.087
G3 X125.587 Y122.737 I1.846 J-2.712 E.05361
G1 X119.326 Y128.997 E.29368
G3 X120.891 Y128.567 I10.051 J33.499 E.05383
G1 X107.571 Y115.247 E.62487
G2 X112.36 Y112.361 I-8.188 J-19.002 E.18607
G1 X127.713 Y127.714 E.72024
G3 X128.286 Y127.714 I.288 J8.199 E.019
G1 X143.645 Y112.355 E.7205
G2 X148.43 Y115.246 I12.871 J-15.901 E.18603
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.448 J33.816 E.05372
G1 X130.416 Y122.741 E.29341
G3 X129.352 Y123.934 I-2.414 J-1.082 E.05391
G1 X140.386 Y111.134 F36000
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.381 E.05407
G1 X170.616 Y139.912 E1.34273
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.419 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X155.992 Y132.965 E.43628
G2 X155.776 Y130.928 I-2.874 J-.724 E.06938
G1 X162.172 Y124.532 E.30006
G3 X164.985 Y126.364 I-5.412 J11.382 E.11169
G3 X165.932 Y128.447 I-10.698 J6.124 E.07603
G1 X153.083 Y141.297 E.60279
G3 X153.939 Y142.682 I-19.42 J12.96 E.05402
; WIPE_START
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
; WIPE_END
G1 E-.04 F1800
G1 X145.934 Y139.212 Z4.2 F36000
G1 X113.77 Y131.309 Z4.2
G1 Z3.8
G1 E.8 F1800
G1 F15476.087
G3 X115.224 Y130.576 I15.769 J29.459 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.778 I1.392 J2.462 E.03858
G3 X98.118 Y121.146 I-32.79 J-23.323 E.1428
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.74 J27.782 E.18056
G1 X103.82 Y134.524 E.11678
G2 X103.304 Y129.668 I-1.275 J-2.32 E.2062
G1 X122.015 Y110.957 E.87778
G3 X118.944 Y111.268 I-4.387 J-27.98 E.10243
G1 X126.919 Y119.244 E.37413
G3 X129.082 Y119.242 I1.083 J2.439 E.07387
G1 X137.055 Y111.268 E.37406
G3 X133.984 Y110.956 I1.331 J-28.348 E.10248
G1 X152.697 Y129.669 E.87789
G2 X152.182 Y134.522 I.762 J2.535 E.20594
G1 X149.689 Y137.015 E.11696
G2 X145.602 Y133.425 I-24.536 J23.811 E.18062
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.324 I24.838 J-22.126 E.11974
G2 X154.34 Y117.012 I-5.146 J3.782 E.06133
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.34 J30.252 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
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
G1 X125.719 Y121.366
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.783 Y121.049 E.01072
G3 X127.826 Y119.362 I2.219 J.606 E.09366
G1 X128.179 Y119.362 E.0117
G3 X125.713 Y121.426 I-.176 J2.294 E.36139
G1 X126.107 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.896 J.216 E.08093
G1 X128.149 Y119.754 E.00899
G3 X126.101 Y121.5 I-.146 J1.902 E.27656
; WIPE_START
M204 S10000
G1 X126.185 Y121.084 E-.16134
G1 X126.259 Y120.877 E-.08329
G1 X126.399 Y120.621 E-.11112
G1 X126.576 Y120.388 E-.11116
G1 X126.787 Y120.185 E-.11116
G1 X127.026 Y120.017 E-.11115
G1 X127.193 Y119.934 E-.07078
; WIPE_END
G1 E-.04 F1800
G1 X120.114 Y122.788 Z4.4 F36000
G1 X102.455 Y129.906 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.723 Y129.906 E.00888
G3 X102.37 Y129.906 I-.176 J2.297 E.46846
G1 X102.395 Y129.906 E.00083
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00899
G3 X102.341 Y130.304 I-.146 J1.905 E.35803
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13382
G1 X102.982 Y130.343 E-.11116
G1 X103.261 Y130.431 E-.11118
G1 X103.523 Y130.561 E-.11114
G1 X103.762 Y130.729 E-.11116
G1 X103.973 Y130.932 E-.11115
G1 X104.085 Y131.079 E-.07039
; WIPE_END
G1 E-.04 F1800
G1 X111.717 Y131.16 Z4.4 F36000
G1 X155.685 Y131.622 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.744 Y131.939 E.01072
G3 X153.282 Y129.906 I-2.285 J.26 E.36235
G1 X153.634 Y129.906 E.0117
G3 X155.669 Y131.564 I-.176 J2.293 E.09264
G1 X155.303 Y131.709 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.354 Y131.984 E.0086
G3 X153.312 Y130.298 I-1.896 J.216 E.27841
G1 X153.604 Y130.298 E.00899
G3 X155.285 Y131.652 I-.146 J1.902 E.07048
; WIPE_START
M204 S10000
G1 X155.354 Y131.984 E-.12907
G1 X155.367 Y132.276 E-.11107
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11114
G1 X155.097 Y133.178 E-.13877
G1 X154.978 Y133.362 E-.08327
G1 X154.845 Y133.51 E-.07549
; WIPE_END
G1 E-.04 F1800
G1 X155.267 Y141.131 Z4.4 F36000
G1 X155.589 Y146.934 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.718 E2.35658
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.58 J.167 E.04815
G3 X84.377 Y136.65 I5.972 J3.757 E.05162
G2 X86.79 Y133.986 I-24.728 J-24.815 E.11928
G2 X89.501 Y128.988 I-13.843 J-10.746 E.18946
G3 X90.41 Y126.674 I23.294 J7.812 E.08252
G3 X91.436 Y125.548 I2.417 J1.172 E.05123
G3 X93.349 Y124.413 I15.952 J24.707 E.07379
G2 X98.06 Y120.701 I-8.564 J-15.716 E.1999
G2 X100.325 Y117.807 I-37.422 J-31.617 E.12194
G3 X101.394 Y116.758 I3.536 J2.536 E.04993
G3 X103.044 Y116.197 I3.008 J6.141 E.05796
G2 X106.576 Y115.257 I-6.546 J-31.733 E.12132
G2 X111.534 Y112.534 I-5.975 J-16.749 E.18843
G3 X113.513 Y111.136 I14.724 J18.743 E.0804
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.765 J188.201 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.095 J28.214 E.09117
G3 X128.183 Y108.872 I.644 J2.634 E.02773
G3 X129.663 Y109.258 I-.81 J6.13 E.05089
G2 X133.389 Y110.477 I12.296 J-31.28 E.13011
G2 X138.729 Y110.881 I3.984 J-17.198 E.17831
G3 X141.236 Y110.779 I2.303 J25.773 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05112
G3 X144.474 Y112.538 I-15.362 J23.39 E.07317
G2 X149.428 Y115.257 I11.081 J-14.314 E.18823
G2 X152.965 Y116.193 I9.839 J-30.04 E.12144
G3 X154.57 Y116.731 I-1.273 J6.461 E.05629
G3 X155.674 Y117.809 I-2.602 J3.771 E.05145
G2 X157.946 Y120.702 I41.969 J-30.617 E.12203
G2 X162.421 Y124.276 I12.715 J-11.334 E.19089
G3 X164.758 Y125.674 I-13.53 J25.27 E.09035
G3 X165.746 Y127.013 I-1.782 J2.349 E.05598
G3 X166.938 Y130.092 I-686.511 J267.695 E.1095
G2 X170.649 Y135.623 I16.058 J-6.762 E.22233
G3 X172.333 Y137.457 I-17.02 J17.314 E.08262
G3 X172.913 Y139.008 I-2.311 J1.749 E.0557
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.195 E2.17924
G1 X82.639 Y139.508 E.60452
G3 X82.946 Y137.924 I5.314 J.208 E.04977
G3 X83.717 Y136.795 I3.838 J1.794 E.04218
G2 X85.862 Y134.489 I-444.503 J-415.684 E.09676
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.428 J7.86 E.07788
G3 X91.213 Y125.225 I2.76 J1.349 E.05331
G3 X93.152 Y124.073 I16.138 J24.968 E.06933
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.347 J-31.532 E.1123
G3 X101.193 Y116.421 I3.822 J2.758 E.05061
G3 X102.951 Y115.816 I3.187 J6.403 E.0573
G2 X106.448 Y114.887 I-6.459 J-31.368 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.851 J18.913 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.449 J182.394 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21158
G3 X127.013 Y108.625 I13.207 J33.891 E.07784
G3 X128.217 Y108.481 I.983 J3.112 E.03746
G3 X129.793 Y108.888 I-.839 J6.501 E.05016
G2 X133.154 Y110.014 I13.012 J-33.267 E.10897
G2 X138.707 Y110.489 I4.212 J-16.533 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05321
G3 X144.706 Y112.222 I-15.529 J23.671 E.06879
G2 X149.556 Y114.887 I10.852 J-14.004 E.17076
G2 X153.056 Y115.812 I9.715 J-29.681 E.11131
G3 X154.77 Y116.394 I-1.342 J6.764 E.05577
G3 X155.765 Y117.3 I-2.18 J3.39 E.04154
G2 X157.819 Y119.952 I1370.356 J-1059.503 E.10306
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.312 J30.223 E.07721
G3 X166.104 Y126.854 I-1.827 J2.82 E.06591
G3 X167.3 Y129.94 I-597.875 J233.422 E.10168
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.647 Y137.222 I-17.207 J17.494 E.07793
G3 X173.302 Y138.956 I-2.618 J1.98 E.05775
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38731
G1 X154.608 Y145.61 E-.07071
; WIPE_END
G1 E-.04 F1800
G1 X152.159 Y139.956 Z4.4 F36000
G1 Z4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X153.083 Y141.297 I-28.694 J20.773 E.05401
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.655 J1.408 E.08775
G2 X162.172 Y124.532 I-25.065 J37.936 E.10007
G1 X156.054 Y130.65 E.28701
G1 X156.079 Y130.695 E.00172
G3 X156.294 Y133.266 I-2.659 J1.517 E.08834
G1 X165.292 Y142.265 E.42213
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.907 J1.491 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34272
G2 X140.386 Y111.134 I-1.124 J3.224 E.05407
G1 X130.652 Y121.352 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X130.663 Y121.804 E.01253
G1 X130.505 Y122.577 E.02186
G1 X130.266 Y123.056 E.01482
G1 X129.867 Y123.565 E.01793
G3 X125.802 Y123.154 I-1.86 J-1.917 E.12888
G1 X125.501 Y122.581 E.01792
G3 X125.356 Y121.336 I2.768 J-.952 E.03501
G1 X125.48 Y120.815 E.01482
G1 X125.753 Y120.229 E.01792
G3 X130.02 Y119.919 I2.248 J1.427 E.13765
G1 X130.43 Y120.558 E.02102
G3 X130.64 Y121.293 I-2.223 J1.034 E.02128
; Slow Down End
; WIPE_START
G1 X130.57 Y120.941 E-.13648
G1 X130.43 Y120.558 E-.15511
G1 X130.02 Y119.919 E-.28831
G1 X129.69 Y119.594 E-.17611
G1 X129.681 Y119.588 E-.00398
; WIPE_END
G1 E-.04 F1800
G1 X127.587 Y126.928 Z4.4 F36000
G1 X127.365 Y127.706 Z4.4
G1 Z4
G1 E.8 F1800
G1 F12000
G3 X128.177 Y127.699 I.603 J23.209 E.02251
G1 X120.217 Y128.728 F36000
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G3 X123.748 Y128 I7.461 J27.248 E.09995
; Slow Down End
G1 X115.627 Y111.14 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.841 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.366 J.127 E.04916
G1 X86.809 Y140.541 E.13381
G1 X90.708 Y142.264 E.14141
G1 X99.709 Y133.263 E.42225
G3 X99.949 Y130.653 I3.158 J-1.026 E.08937
G1 X93.83 Y124.534 E.28706
G2 X90.988 Y126.402 I5.504 J11.469 E.11315
G2 X90.068 Y128.448 I10.566 J5.978 E.07453
G1 X102.92 Y141.3 E.60289
G3 X103.844 Y139.959 I29.75 J19.517 E.05401
G1 X105.244 Y138.172 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G3 X108.324 Y135.067 I22.867 J19.604 E.12127
; Slow Down End
G1 X105.196 Y131.897 F36000
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G3 X100.025 Y133.063 I-2.65 J.298 E.21591
G1 X99.883 Y132.317 E.02101
G3 X101.314 Y129.846 I2.684 J-.096 E.08342
G1 X101.918 Y129.613 E.01793
G3 X105.185 Y131.838 I.618 J2.604 E.12323
; Slow Down End
; WIPE_START
G1 X105.115 Y131.485 E-.13699
G1 X104.975 Y131.101 E-.15509
G1 X104.778 Y130.743 E-.15522
M73 P64 R7
G1 X104.529 Y130.42 E-.15507
G1 X104.234 Y130.138 E-.15521
G1 X104.228 Y130.134 E-.00242
; WIPE_END
G1 E-.04 F1800
G1 X96.661 Y131.128 Z4.4 F36000
G1 X88.404 Y132.211 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X87.525 Y133.581 I-17.709 J-10.399 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.659 Y109.989 E1.62444
G2 X128.157 Y109.22 I-4.595 J10.506 E.08702
G2 X126.631 Y109.521 I.053 J4.295 E.05189
G1 X125.341 Y109.989 E.04552
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.239 J-12.705 E.054
G1 X156.108 Y131.897 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G3 X153.822 Y134.843 I-2.652 J.301 E.11437
G1 X153.063 Y134.84 E.02101
G3 X152.226 Y129.846 I.391 J-2.633 E.1854
G1 X152.829 Y129.613 E.01793
G3 X155.767 Y130.881 I.63 J2.575 E.09517
G1 X156.023 Y131.476 E.01793
G1 X156.096 Y131.839 E.01026
; Slow Down End
; WIPE_START
G1 X156.023 Y131.476 E-.14072
G1 X155.767 Y130.881 E-.24586
G1 X155.46 Y130.443 E-.20325
G1 X155.145 Y130.138 E-.16651
G1 X155.137 Y130.133 E-.00367
; WIPE_END
G1 E-.03999 F1800
G1 X148.701 Y134.235 Z4.4 F36000
G1 X147.56 Y134.962 Z4.4
G1 Z4
G1 E.8 F1800
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G3 X150.787 Y138.202 I-19.736 J22.882 E.1268
; Slow Down End
; WIPE_START
G1 X150.272 Y137.611 E-.29781
G1 X149.559 Y136.845 E-.39768
G1 X149.439 Y136.725 E-.06452
; WIPE_END
G1 E-.04 F1800
G1 X143.338 Y132.139 Z4.4 F36000
G1 X142.231 Y131.307 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X140.777 Y130.574 I-15.794 J29.519 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.633 Y118.323 I-3.853 J5.094 E.06132
G2 X157.884 Y121.144 I27.095 J-19.311 E.11975
G1 X145.602 Y133.425 E.57615
G3 X147.275 Y134.734 I-396.155 J508.204 E.07046
G1 X147.543 Y134.467 E.01254
G3 X149.96 Y136.744 I-32.262 J36.672 E.11017
G1 X151.906 Y134.797 E.09132
G3 X152.397 Y129.369 I1.605 J-2.591 E.22371
G1 X133.984 Y110.956 E.86379
G2 X137.055 Y111.268 I4.402 J-28.035 E.10248
G1 X129.363 Y118.96 E.36085
G2 X126.638 Y118.962 I-1.361 J2.7 E.0938
G1 X118.944 Y111.268 E.36093
G2 X122.015 Y110.957 I-1.317 J-28.289 E.10243
G1 X103.604 Y129.368 E.86368
G3 X104.095 Y134.799 I-1.109 J2.838 E.22402
G1 X106.042 Y136.746 E.09135
G3 X108.445 Y134.482 I34.661 J34.366 E.10955
G1 X108.654 Y134.8 E.01263
G3 X110.399 Y133.428 I118.917 J149.481 E.07366
G1 X98.118 Y121.146 E.57613
G2 X100.796 Y117.779 I-30.12 J-26.697 E.14279
G3 X101.665 Y117.017 I2.262 J1.702 E.0386
G1 X115.224 Y130.576 E.6361
G3 X119.326 Y128.997 I12.806 J27.159 E.14594
G1 X125.301 Y123.023 E.28029
G2 X130.702 Y123.026 I2.701 J-1.37 E.2212
G1 X136.671 Y128.995 E.28002
G2 X135.109 Y128.566 I-10.009 J33.387 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.638 Y112.362 I8.288 J-19.193 E.18608
G1 X128.657 Y127.343 E.7028
G2 X127.343 Y127.343 I-.656 J18.81 E.04361
G1 X112.36 Y112.361 E.70285
G3 X107.571 Y115.247 I-12.977 J-16.115 E.18607
G1 X120.579 Y128.255 E.61024
G3 X122.168 Y127.902 I8.928 J36.45 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 4.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X120.579 Y128.255 E-.61865
G1 X120.316 Y127.992 E-.14135
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
G1 X125.719 Y121.366
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.784 Y121.05 E.01073
G3 X127.826 Y119.362 I2.218 J.605 E.09364
G3 X130.239 Y122.187 I.17 J2.298 E.14337
G3 X125.714 Y121.426 I-2.237 J-.533 E.2294
G1 X126.106 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.896 J.216 E.08094
G1 X128.149 Y119.754 E.00899
G3 X126.101 Y121.5 I-.146 J1.903 E.27663
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.1338
G1 X126.259 Y120.878 E-.11117
G1 X126.399 Y120.621 E-.11117
G1 X126.576 Y120.388 E-.11114
G1 X126.787 Y120.185 E-.11115
G1 X127.082 Y119.989 E-.13485
G1 X127.193 Y119.934 E-.04672
; WIPE_END
G1 E-.04 F1800
G1 X120.115 Y122.791 Z4.6 F36000
G1 X102.491 Y129.906 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.723 Y129.906 E.0077
G3 X102.37 Y129.906 I-.176 J2.293 E.46767
G1 X102.431 Y129.906 E.002
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00899
G3 X102.341 Y130.304 I-.146 J1.902 E.3575
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13382
G1 X102.982 Y130.343 E-.11118
G1 X103.261 Y130.431 E-.11113
G1 X103.523 Y130.561 E-.11116
G1 X103.762 Y130.729 E-.11116
G1 X103.973 Y130.932 E-.11115
G1 X104.085 Y131.079 E-.07039
; WIPE_END
G1 E-.04 F1800
G1 X111.717 Y131.16 Z4.6 F36000
G1 X155.685 Y131.621 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.741 Y131.94 E.01073
G3 X153.282 Y129.906 I-2.286 J.261 E.36255
G3 X155.592 Y131.348 I.162 J2.312 E.09656
G3 X155.666 Y131.565 I-2.137 J.852 E.00758
G1 X155.303 Y131.71 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.354 Y131.984 E.00856
G3 X153.312 Y130.298 I-1.896 J.216 E.2784
G1 X153.604 Y130.298 E.00899
G3 X155.286 Y131.653 I-.146 J1.902 E.07053
; WIPE_START
M204 S10000
G1 X155.354 Y131.984 E-.12854
G1 X155.367 Y132.276 E-.11106
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11115
G1 X155.137 Y133.116 E-.11116
G1 X154.978 Y133.362 E-.11115
G1 X154.845 Y133.51 E-.07577
; WIPE_END
G1 E-.04 F1800
G1 X155.267 Y141.131 Z4.6 F36000
G1 X155.589 Y146.934 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.718 E2.35658
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.58 J.167 E.04815
G3 X84.377 Y136.65 I5.977 J3.761 E.05163
G2 X86.79 Y133.986 I-24.729 J-24.815 E.11927
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.321 J7.822 E.08249
G3 X91.436 Y125.548 I2.423 J1.176 E.05124
G3 X93.349 Y124.413 I15.957 J24.716 E.07381
G2 X98.059 Y120.701 I-8.564 J-15.715 E.19988
G2 X100.325 Y117.807 I-37.426 J-31.621 E.12196
G3 X101.394 Y116.758 I3.536 J2.536 E.04994
G3 X103.044 Y116.197 I3.009 J6.144 E.05796
G2 X106.576 Y115.257 I-6.545 J-31.731 E.12132
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18843
G3 X113.513 Y111.136 I14.724 J18.743 E.0804
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.766 J188.219 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.101 J28.23 E.09115
G3 X128.183 Y108.872 I.644 J2.633 E.02774
G3 X129.664 Y109.258 I-.81 J6.129 E.0509
G2 X133.389 Y110.477 I12.299 J-31.287 E.1301
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.779 E.08329
G3 X142.68 Y111.256 I-.087 J2.685 E.05111
G3 X144.474 Y112.538 I-15.361 J23.388 E.07318
G2 X149.427 Y115.257 I11.081 J-14.315 E.18822
G2 X152.965 Y116.193 I9.838 J-30.034 E.12147
G3 X154.6 Y116.75 I-1.172 J6.125 E.05748
G3 X155.674 Y117.809 I-2.697 J3.808 E.05027
G2 X157.946 Y120.702 I41.972 J-30.619 E.12201
G2 X162.421 Y124.276 I12.715 J-11.333 E.19091
G3 X164.758 Y125.674 I-13.535 J25.277 E.09035
G3 X165.746 Y127.012 I-1.781 J2.348 E.05595
G3 X166.938 Y130.091 I-675.031 J263.259 E.10953
G2 X170.649 Y135.623 I16.058 J-6.762 E.22234
G3 X172.333 Y137.457 I-17.03 J17.323 E.08262
G3 X172.913 Y139.008 I-2.311 J1.749 E.0557
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.195 E2.17924
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.199 J.192 E.05096
G3 X83.717 Y136.795 I3.893 J1.885 E.04098
G2 X85.862 Y134.489 I-442.918 J-414.21 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.443 J7.866 E.07787
G3 X91.213 Y125.225 I2.766 J1.353 E.05332
G3 X93.152 Y124.073 I16.132 J24.957 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.35 J-31.535 E.1123
G3 X101.193 Y116.421 I3.821 J2.758 E.05062
G3 X102.951 Y115.816 I3.187 J6.404 E.05729
G2 X106.448 Y114.887 I-6.458 J-31.366 E.11123
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.85 J18.912 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05819
G3 X117.867 Y110.517 I-7.449 J182.411 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.212 J33.905 E.07783
G3 X128.217 Y108.481 I.983 J3.112 E.03746
G3 X129.793 Y108.888 I-.84 J6.502 E.05017
G2 X133.154 Y110.014 I13.012 J-33.267 E.10895
G2 X138.707 Y110.489 I4.211 J-16.533 E.17203
G3 X141.261 Y110.387 I2.31 J25.883 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05321
G3 X144.706 Y112.222 I-15.521 J23.659 E.06879
G2 X149.556 Y114.887 I10.853 J-14.006 E.17076
G2 X153.057 Y115.812 I9.716 J-29.685 E.11132
G3 X154.804 Y116.414 I-1.246 J6.448 E.05696
G3 X155.981 Y117.565 I-2.871 J4.115 E.05081
G2 X158.238 Y120.441 I41.923 J-30.58 E.11238
G2 X162.618 Y123.937 I12.424 J-11.074 E.17301
G3 X164.784 Y125.21 I-16.318 J30.233 E.0772
G3 X166.104 Y126.854 I-1.827 J2.82 E.06589
G3 X167.3 Y129.94 I-592.302 J231.27 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.647 Y137.222 I-17.228 J17.513 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05775
G3 X173.36 Y139.508 I-10.393 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.327 Y138.509 Z4.6 F36000
G1 Z4.2
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.41125
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X161.394 Y130.442 E.61741
G1 X161.067 Y130.116 E.02496
G1 X153.144 Y138.04 E.60645
G1 X152.818 Y137.714 E.02496
G1 X160.741 Y129.79 E.60645
G1 X160.415 Y129.464 E.02496
G1 X152.491 Y137.387 E.60646
G1 X152.165 Y137.061 E.02496
G1 X160.089 Y129.138 E.60646
G1 X159.763 Y128.812 E.02496
G1 X156.113 Y132.461 E.27936
G2 X156.101 Y131.821 I-2.957 J-.263 E.03471
G1 X159.437 Y128.485 E.25533
G1 X159.11 Y128.159 E.02496
G1 X155.968 Y131.302 E.24052
G1 X155.947 Y131.244 E.00333
G2 X155.761 Y130.856 I-1.347 J.408 E.02336
G1 X158.784 Y127.833 E.23138
G1 X158.458 Y127.507 E.02496
G1 X155.492 Y130.473 E.227
G2 X155.167 Y130.146 I-3.682 J3.348 E.02497
G1 X158.132 Y127.181 E.22697
G1 X157.806 Y126.855 E.02496
G1 X154.779 Y129.881 E.23167
G1 X154.7 Y129.842 E.0048
G2 X154.327 Y129.681 I-.708 J1.125 E.02205
G1 X157.48 Y126.528 E.24129
G1 X157.154 Y126.202 E.02496
G1 X153.798 Y129.557 E.25679
G2 X153.151 Y129.552 I-.346 J2.854 E.0351
G1 X156.827 Y125.876 E.28136
G1 X156.501 Y125.55 E.02496
G1 X148.578 Y133.474 E.60646
G1 X148.252 Y133.147 E.02496
G1 X156.175 Y125.224 E.60645
G1 X155.849 Y124.898 E.02496
G1 X147.925 Y132.821 E.60645
G1 X147.599 Y132.495 E.02496
G1 X155.523 Y124.572 E.60646
G1 X155.197 Y124.245 E.02496
G1 X147.13 Y132.312 E.61741
G1 X147.518 Y135.185 F36000
G1 F3000
G1 X150.801 Y131.903 E.25124
G1 X150.785 Y132.306 E.02183
G1 X150.813 Y132.543 E.01293
M73 P64 R6
G1 X148.011 Y135.345 E.21446
G3 X148.35 Y135.658 I-4.308 J5.003 E.02499
G1 X150.932 Y133.076 E.19765
G2 X151.034 Y133.314 I.821 J-.209 E.01407
G2 X151.136 Y133.524 I.731 J-.228 E.0127
G1 X148.687 Y135.973 E.18744
M73 P65 R6
G3 X149.018 Y136.295 I-4.442 J4.899 E.02497
G1 X151.405 Y133.908 E.18269
G2 X151.73 Y134.235 I2.015 J-1.678 E.025
G1 X149.344 Y136.621 E.18261
G3 X149.667 Y136.951 I-4.558 J4.777 E.02497
G1 X152.112 Y134.505 E.18716
G2 X152.555 Y134.715 I1.042 J-1.635 E.02659
G1 X149.981 Y137.288 E.19699
G3 X150.295 Y137.627 I-4.702 J4.68 E.02499
G1 X153.074 Y134.848 E.21264
G2 X153.72 Y134.854 I.347 J-2.651 E.03508
G1 X150.455 Y138.119 E.24989
G1 X149.776 Y129.051 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
; LAYER_HEIGHT: 0.2
G1 F15476.087
G1 X150.928 Y127.9 E.05401
G1 X133.984 Y110.956 E.79488
G2 X137.055 Y111.268 I4.402 J-28.035 E.10248
G1 X132.265 Y116.059 E.22475
G1 X129.517 Y113.311 E.12892
G1 X129.09 Y113.738 E.02003
G1 X125.341 Y109.989 E.17588
G3 X127.741 Y109.227 I5.084 J11.858 E.08369
G3 X129.209 Y109.472 I.152 J3.602 E.04971
G1 X130.659 Y109.989 E.05108
G1 X108.912 Y131.735 E1.02019
G1 X109.339 Y132.162 E.02003
G1 X109.237 Y132.265 E.00481
G1 X110.399 Y133.428 E.05454
G3 X111.745 Y132.511 I13.806 J18.807 E.05402
; WIPE_START
G1 X110.399 Y133.428 E-.61868
G1 X110.136 Y133.165 E-.14132
; WIPE_END
G1 E-.04 F1800
G1 X104.95 Y138.764 Z4.6 F36000
G1 X103.844 Y139.959 Z4.6
G1 Z4.2
G1 E.8 F1800
G1 F15476.087
G2 X102.92 Y141.3 I28.807 J20.845 E.05401
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.926 J1.552 E.0865
G3 X93.83 Y124.534 I9.841 J12.989 E.10129
G1 X96.869 Y127.573 E.14257
G1 X93.998 Y130.444 E.13467
G1 X94.425 Y130.871 E.02003
G1 X85.385 Y139.911 E.42412
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.363 J.126 E.04916
G1 X86.809 Y140.541 E.13381
G1 X90.708 Y142.264 E.14141
G1 X98.263 Y134.709 E.35442
G1 X102.101 Y138.547 E.18005
G1 X96.032 Y144.616 E.28473
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.826 J-11.766 E.054
G1 X94.465 Y130.297 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.41125
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X102.532 Y138.363 E.61741
G1 X102.858 Y138.037 E.02496
G1 X94.935 Y130.114 E.60646
G1 X95.261 Y129.787 E.02496
G1 X103.184 Y137.711 E.60646
G1 X103.511 Y137.385 E.02496
G1 X95.587 Y129.461 E.60646
G1 X95.913 Y129.135 E.02496
G1 X104.153 Y137.375 E.63066
G1 X105.282 Y138.118 E.07315
G1 X105.406 Y137.976 E.01019
G1 X102.288 Y134.858 E.2386
G2 X102.931 Y134.848 I.29 J-2.086 E.03492
G1 X105.709 Y137.627 E.21264
G3 X106.023 Y137.288 I5.01 J4.336 E.02499
G1 X103.449 Y134.715 E.19699
G2 X103.893 Y134.505 I-.456 J-1.54 E.02662
G1 X106.338 Y136.951 E.18716
G3 X106.66 Y136.621 I4.881 J4.447 E.02497
G1 X104.274 Y134.235 E.18261
G2 X104.6 Y133.908 I-.896 J-1.215 E.02506
G1 X106.986 Y136.295 E.18269
G3 X107.317 Y135.973 I4.773 J4.577 E.02497
G1 X104.868 Y133.524 E.18744
G1 X105.072 Y133.076 E.02665
G1 X107.655 Y135.658 E.19765
G3 X107.994 Y135.345 I4.662 J4.706 E.02499
G1 X105.192 Y132.543 E.21446
G1 X105.203 Y132.447 E.00523
G2 X105.204 Y131.903 I-1.761 J-.275 E.02958
G1 X108.217 Y134.916 E.23067
G1 X107.331 Y133.565 E.08749
G1 X107.424 Y133.471 E.00716
G1 X99.501 Y125.547 E.60646
G1 X99.175 Y125.874 E.02496
G1 X102.853 Y129.552 E.28155
G1 X102.751 Y129.536 E.00559
G2 X102.206 Y129.557 I-.205 J1.776 E.02963
G1 X98.849 Y126.2 E.25699
G1 X98.522 Y126.526 E.02496
G1 X101.677 Y129.681 E.24149
G2 X101.226 Y129.881 I.422 J1.562 E.02686
G1 X98.196 Y126.852 E.23186
G1 X97.87 Y127.178 E.02496
G1 X100.838 Y130.146 E.22716
G1 X100.512 Y130.473 E.02496
G1 X97.544 Y127.504 E.22719
G1 X97.218 Y127.831 E.02496
G1 X100.243 Y130.856 E.23158
G2 X100.037 Y131.302 I1.838 J1.123 E.02664
G1 X96.892 Y128.157 E.24072
G1 X96.565 Y128.483 E.02496
G1 X99.904 Y131.821 E.25553
G1 X99.889 Y131.897 E.00414
G2 X99.892 Y132.461 I1.83 J.275 E.03069
G1 X96.096 Y128.666 E.29051
G1 X99.684 Y125.078 F36000
G1 F3000
G1 X107.751 Y133.145 E.61741
G1 X108.077 Y132.819 E.02496
G1 X100.153 Y124.895 E.60645
G1 X100.479 Y124.569 E.02496
G1 X108.403 Y132.493 E.60645
G1 X108.729 Y132.166 E.02496
G1 X100.662 Y124.1 E.61741
G1 X115.627 Y111.14 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
; LAYER_HEIGHT: 0.2
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.84 E.05406
G1 X101.236 Y124.06 E.59947
G1 X100.81 Y123.633 E.02003
G1 X100.707 Y123.735 E.00481
G1 X98.118 Y121.147 E.12144
G2 X100.796 Y117.779 I-30.125 J-26.701 E.14279
G3 X101.665 Y117.017 I2.261 J1.701 E.0386
G1 X115.224 Y130.576 E.6361
G3 X119.326 Y128.997 I12.806 J27.159 E.14594
G1 X119.897 Y128.427 E.02676
G1 X119.058 Y127.588 E.03935
G1 X119.485 Y127.161 E.02003
G1 X107.571 Y115.247 E.55891
G2 X112.36 Y112.361 I-8.189 J-19.003 E.18607
G1 X121.414 Y121.414 E.42471
G1 X125.252 Y117.576 E.18005
G1 X118.944 Y111.268 E.2959
G2 X122.015 Y110.957 I-1.317 J-28.289 E.10243
G1 X105.074 Y127.897 E.79471
G1 X103.923 Y126.746 E.05401
G1 X121.454 Y121.988 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.41125
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X129.521 Y113.921 E.61741
G1 X129.847 Y114.248 E.02496
G1 X121.923 Y122.171 E.60645
G1 X122.249 Y122.497 E.02496
G1 X130.173 Y114.574 E.60645
G1 X130.499 Y114.9 E.02496
G1 X122.432 Y122.967 E.61741
G1 X126.02 Y126.554 F36000
G1 F3000
G1 X128.26 Y124.314 E.17147
G3 X127.923 Y124.328 I-.213 J-1.087 E.01836
G1 X127.618 Y124.304 E.01655
G1 X125.837 Y126.085 E.13629
G1 X125.73 Y125.978 E.00822
G1 X123.709 Y127.998 E.15465
G1 X123.189 Y128.081 E.02849
G1 X127.099 Y124.17 E.29927
G3 X126.656 Y123.961 I.455 J-1.539 E.02663
G1 X122.397 Y128.22 E.32598
G2 X121.579 Y128.386 I1.973 J11.819 E.04521
G1 X126.274 Y123.691 E.3594
G3 X126.059 Y123.482 I.449 J-.678 E.0163
G1 X125.955 Y123.358 E.00879
G1 X120.729 Y128.583 E.39997
G1 X120.293 Y128.7 E.02448
G1 X120.391 Y128.315 E.02152
G1 X120.368 Y128.292 E.00176
G1 X125.681 Y122.98 E.40658
G3 X125.476 Y122.532 I4.234 J-2.198 E.02667
G1 X120.042 Y127.966 E.41593
G1 X119.716 Y127.64 E.02496
G1 X125.357 Y121.999 E.43175
G3 X125.338 Y121.551 I1.438 J-.286 E.02435
G1 X125.345 Y121.359 E.01043
G1 X123.228 Y123.476 E.16204
G1 X122.902 Y123.15 E.02496
G1 X130.825 Y115.226 E.60645
G1 X131.151 Y115.552 E.02496
G1 X127.696 Y119.008 E.26451
G3 X128.343 Y119.013 I.301 J2.86 E.0351
G1 X131.478 Y115.878 E.23994
G1 X131.804 Y116.204 E.02496
G1 X128.871 Y119.137 E.22445
G3 X129.323 Y119.337 I-.423 J1.564 E.02686
G1 X132.13 Y116.531 E.21482
G1 X132.456 Y116.857 E.02496
G1 X129.711 Y119.602 E.21012
G1 X130.036 Y119.929 E.02496
G1 X132.782 Y117.183 E.2102
G1 X133.108 Y117.509 E.02496
G1 X130.305 Y120.312 E.21453
G3 X130.499 Y120.721 I-2.069 J1.23 E.02453
G1 X130.512 Y120.758 E.0021
G1 X133.435 Y117.835 E.22368
G1 X133.761 Y118.161 E.02496
G1 X130.645 Y121.277 E.23849
G1 X130.675 Y121.767 E.02658
G1 X130.652 Y121.922 E.00845
G1 X134.087 Y118.488 E.26287
G1 X134.413 Y118.814 E.02496
G1 X126.489 Y126.737 E.60645
G1 X126.816 Y127.063 E.02496
G1 X134.739 Y119.14 E.60645
G1 X135.065 Y119.466 E.02496
G1 X127.142 Y127.39 E.60645
G1 X127.449 Y127.697 E.02351
M73 P66 R6
G1 X127.487 Y127.696 E.00209
G1 X135.391 Y119.792 E.60495
G1 X135.718 Y120.118 E.02496
G1 X127.945 Y127.891 E.59488
G1 X130.912 Y125.539 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
; LAYER_HEIGHT: 0.2
G1 F15476.087
G1 X132.063 Y124.387 E.05401
G1 X136.671 Y128.995 E.21617
G2 X135.109 Y128.566 I-10.009 J33.387 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.638 Y112.362 I8.288 J-19.193 E.18608
G1 X136.103 Y119.897 E.35351
G1 X136.328 Y120.122 E.01056
G1 X135.901 Y120.549 E.02003
G1 X147.09 Y131.738 E.52489
G1 X146.663 Y132.165 E.02003
G1 X146.763 Y132.265 E.00469
G1 X145.602 Y133.425 E.05445
G2 X140.777 Y130.574 I-19.696 J27.825 E.18612
G1 X154.34 Y117.012 E.63624
G3 X155.633 Y118.323 I-3.865 J5.107 E.06131
G2 X157.884 Y121.144 I27.089 J-19.306 E.11976
G1 X155.292 Y123.735 E.12156
G1 X155.193 Y123.635 E.00469
G1 X154.766 Y124.062 E.02003
G1 X141.993 Y111.29 E.59917
G2 X140.386 Y111.134 I-1.124 J3.224 E.05407
G1 X167.597 Y132.209 F36000
G1 F15476.087
G2 X168.477 Y133.578 I19.136 J-11.347 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X153.901 Y138.549 E.28467
G1 X157.739 Y134.711 E.18005
G1 X165.292 Y142.265 E.35435
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.907 J1.491 E.04933
G1 X170.616 Y139.912 E.07063
G1 X161.577 Y130.873 E.42402
G1 X162.004 Y130.446 E.02003
G1 X159.13 Y127.573 E.13479
G1 X162.172 Y124.532 E.14268
G3 X164.985 Y126.364 I-5.41 J11.379 E.11169
G3 X165.932 Y128.447 I-10.7 J6.124 E.07602
G1 X153.083 Y141.297 E.60279
G2 X152.159 Y139.956 I-29.593 J19.416 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 4.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X153.083 Y141.297 E-.61864
G1 X153.346 Y141.034 E-.14136
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
G1 X125.719 Y121.367
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.783 Y121.049 E.01075
G3 X127.826 Y119.362 I2.219 J.606 E.09366
G1 X128.179 Y119.362 E.0117
G3 X125.713 Y121.427 I-.176 J2.294 E.36136
G1 X126.106 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.896 J.217 E.08095
G1 X128.149 Y119.754 E.00899
G3 X126.1 Y121.5 I-.146 J1.903 E.27672
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.13383
G1 X126.259 Y120.878 E-.11114
G1 X126.399 Y120.621 E-.11118
G1 X126.576 Y120.388 E-.11114
G1 X126.787 Y120.185 E-.11117
G1 X127.073 Y119.993 E-.13091
G1 X127.192 Y119.934 E-.05063
; WIPE_END
G1 E-.04 F1800
G1 X120.106 Y122.77 Z4.8 F36000
G1 X102.216 Y129.93 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.37 Y129.906 E.00516
G1 X102.723 Y129.906 E.0117
G3 X102.022 Y129.96 I-.176 J2.294 E.45605
G1 X102.157 Y129.939 E.00455
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00899
G3 X102.341 Y130.304 I-.146 J1.902 E.35749
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13382
G1 X102.982 Y130.343 E-.11119
G1 X103.261 Y130.431 E-.11113
G1 X103.523 Y130.561 E-.11118
G1 X103.762 Y130.729 E-.11114
G1 X103.973 Y130.932 E-.11116
G1 X104.082 Y131.082 E-.07039
; WIPE_END
G1 E-.04 F1800
G1 X111.714 Y131.162 Z4.8 F36000
G1 X155.685 Y131.621 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.74 Y131.94 E.01074
G3 X154.992 Y133.916 I-2.288 J.263 E.07281
G3 X153.282 Y129.906 I-1.532 J-1.716 E.28941
G3 X155.665 Y131.565 I.17 J2.297 E.10418
G1 X155.303 Y131.712 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.354 Y131.984 E.00852
G3 X153.312 Y130.298 I-1.896 J.216 E.2784
G1 X153.604 Y130.298 E.00899
G3 X155.286 Y131.654 I-.146 J1.902 E.07057
; WIPE_START
M204 S10000
G1 X155.354 Y131.984 E-.12802
G1 X155.367 Y132.276 E-.11106
G1 X155.334 Y132.567 E-.11118
G1 X155.256 Y132.849 E-.11114
G1 X155.137 Y133.116 E-.11117
G1 X154.978 Y133.362 E-.11116
G1 X154.844 Y133.511 E-.07628
; WIPE_END
G1 E-.04 F1800
G1 X155.267 Y141.132 Z4.8 F36000
G1 X155.589 Y146.934 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.718 E2.35658
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.971 J3.756 E.05162
G2 X86.79 Y133.985 I-24.731 J-24.817 E.1193
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18944
G3 X90.41 Y126.674 I23.3 J7.814 E.08252
G3 X91.436 Y125.547 I2.418 J1.172 E.05123
G3 X93.349 Y124.413 I15.958 J24.718 E.07379
G2 X98.06 Y120.701 I-8.564 J-15.715 E.1999
G2 X100.325 Y117.807 I-37.426 J-31.62 E.12194
G3 X101.394 Y116.758 I3.536 J2.535 E.04994
G3 X103.044 Y116.197 I3.009 J6.144 E.05796
G2 X106.577 Y115.257 I-6.546 J-31.734 E.12132
G2 X111.534 Y112.534 I-5.975 J-16.749 E.18842
G3 X113.513 Y111.136 I14.724 J18.743 E.0804
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.765 J188.192 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.099 J28.225 E.09116
G3 X128.183 Y108.872 I.644 J2.633 E.02774
G3 X129.664 Y109.258 I-.81 J6.13 E.05089
G2 X133.389 Y110.477 I12.296 J-31.282 E.1301
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.765 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05112
G3 X144.474 Y112.538 I-15.362 J23.39 E.07317
G2 X149.428 Y115.257 I11.081 J-14.315 E.18823
G2 X152.965 Y116.193 I9.839 J-30.04 E.12145
G3 X154.57 Y116.731 I-1.222 J6.306 E.05629
G3 X155.674 Y117.809 I-2.602 J3.771 E.05147
G2 X157.946 Y120.702 I41.961 J-30.611 E.12203
G2 X162.421 Y124.276 I12.715 J-11.334 E.19089
G3 X164.758 Y125.674 I-13.521 J25.254 E.09035
G3 X165.746 Y127.012 I-1.782 J2.348 E.05595
G3 X166.938 Y130.091 I-673.7 J262.745 E.10953
G2 X170.649 Y135.623 I16.058 J-6.762 E.22234
G3 X172.333 Y137.457 I-17.021 J17.315 E.08263
G3 X172.913 Y139.008 I-2.311 J1.749 E.0557
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.195 E2.17924
G1 X82.639 Y139.508 E.60452
G3 X82.944 Y137.927 I5.328 J.21 E.04964
G3 X83.717 Y136.795 I3.832 J1.785 E.04229
G2 X85.862 Y134.489 I-445.701 J-416.796 E.09678
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.433 J7.862 E.07788
G3 X91.213 Y125.225 I2.76 J1.349 E.05332
G3 X93.152 Y124.073 I16.127 J24.949 E.06933
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.34 J-31.527 E.1123
G3 X101.193 Y116.421 I3.821 J2.758 E.05061
G3 X102.951 Y115.816 I3.187 J6.403 E.0573
G2 X106.448 Y114.887 I-6.459 J-31.367 E.11124
G2 X111.301 Y112.219 I-5.849 J-16.383 E.1709
G3 X113.32 Y110.795 I14.853 J18.915 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05819
G3 X117.867 Y110.517 I-7.448 J182.386 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.208 J33.894 E.07784
G3 X128.217 Y108.481 I.983 J3.112 E.03746
G3 X129.793 Y108.888 I-.84 J6.502 E.05017
G2 X133.154 Y110.014 I13.009 J-33.259 E.10895
G2 X138.707 Y110.489 I4.211 J-16.533 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05322
G3 X144.706 Y112.222 I-15.529 J23.671 E.06879
G2 X149.556 Y114.887 I10.853 J-14.005 E.17076
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.77 Y116.394 I-1.292 J6.617 E.05577
G3 X155.764 Y117.3 I-2.181 J3.392 E.04154
G2 X157.819 Y119.952 I1407.999 J-1088.673 E.10307
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.29 J30.185 E.07722
G3 X166.104 Y126.854 I-1.828 J2.819 E.06587
G3 X167.3 Y129.94 I-591.867 J231.101 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.647 Y137.222 I-17.217 J17.503 E.07793
G3 X173.302 Y138.956 I-2.618 J1.98 E.05775
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z4.8 F36000
G1 Z4.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.266 J11.569 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.653 J1.407 E.08775
G2 X162.172 Y124.532 I-25.063 J37.931 E.10008
G1 X157.19 Y129.513 E.2337
G3 X157.474 Y134.447 I-3.733 J2.69 E.17305
G1 X165.292 Y142.265 E.36675
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.907 J1.491 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34272
G2 X140.386 Y111.134 I-1.124 J3.223 E.05407
G1 X149.963 Y115.79 F36000
G1 F15476.087
G3 X148.43 Y115.246 I5.462 J-17.808 E.05399
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.448 J33.816 E.05372
G1 X131.855 Y124.179 E.22592
G2 X131.922 Y124.078 I-.544 J-.433 E.00405
G1 X143.638 Y112.362 E.54962
G2 X144.96 Y113.312 I15.658 J-20.393 E.05402
G1 X149.343 Y131.302 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F15000
G2 X149.341 Y133.093 I4.773 J.902 E.05533
G2 X150.445 Y135.147 I4.244 J-.957 E.07256
G2 X152.732 Y136.348 I3.066 J-3.059 E.0806
G1 X153.409 Y136.416 E.02091
G2 X154.431 Y136.302 I.08 J-3.936 E.0317
G1 X155.215 Y136.031 E.02546
G2 X157.421 Y130.774 I-1.768 J-3.834 E.19231
G1 X157.06 Y130.021 E.02564
G2 X156.41 Y129.198 I-3.36 J1.986 E.03231
G1 X155.74 Y128.662 E.02638
G2 X149.359 Y131.244 I-2.275 J3.552 E.24737
G1 X149.662 Y131.671 F36000
G1 F15000
G2 X149.797 Y133.334 I3.959 J.516 E.05163
G1 X149.997 Y133.856 E.01718
G1 X150.36 Y134.457 E.02158
G2 X152.166 Y135.815 I3.159 J-2.321 E.07045
G1 X152.796 Y135.977 E.01997
G1 X153.431 Y136.039 E.01961
G1 X154.058 Y135.987 E.01934
G2 X155.513 Y135.442 I-.772 J-4.278 E.04799
G1 X156.151 Y134.935 E.02506
G2 X153.914 Y128.394 I-2.712 J-2.725 E.264
G1 X153.245 Y128.378 E.02055
G2 X151.096 Y129.181 I.238 J3.915 E.07153
G2 X150.013 Y130.515 I2.887 J3.45 E.05313
G1 X149.785 Y131.114 E.01967
G1 X149.675 Y131.613 E.0157
G1 X150.022 Y131.861 F36000
; LINE_WIDTH: 0.429512
G1 F15000
G1 X150.02 Y132.479 E.01946
G1 X150.165 Y133.228 E.02403
G1 X150.352 Y133.708 E.01621
G1 X150.67 Y134.237 E.01946
G2 X151.955 Y135.314 I3.129 J-2.43 E.05321
G1 X152.439 Y135.502 E.01635
G1 X153.067 Y135.632 E.02022
G1 X153.837 Y135.633 E.02426
G1 X154.43 Y135.515 E.01905
G2 X155.888 Y134.64 I-1.062 J-3.419 E.05408
G2 X156.784 Y131.278 I-2.397 J-2.439 E.11496
G1 X156.579 Y130.725 E.0186
G2 X150.032 Y131.802 I-3.117 J1.488 E.2804
G1 X150.411 Y131.808 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G3 X150.903 Y130.497 I3.489 J.561 E.04331
G1 X151.288 Y130.037 E.01843
G3 X152.8 Y129.202 I2.239 J2.271 E.05375
G1 X153.463 Y129.137 E.02045
G1 X154.116 Y129.202 E.02016
G3 X155.446 Y129.861 I-.823 J3.335 E.04597
G1 X155.854 Y130.288 E.01814
G1 X156.06 Y130.57 E.01073
G1 X156.355 Y131.197 E.0213
G1 X156.505 Y131.808 E.01933
G3 X156.335 Y133.282 I-3.409 J.353 E.04597
G1 X156.055 Y133.834 E.019
G1 X155.843 Y134.134 E.0113
G1 X155.293 Y134.662 E.02344
G3 X153.839 Y135.248 I-1.92 J-2.669 E.04862
G1 X153.07 Y135.247 E.02363
G1 X152.573 Y135.145 E.01561
G1 X152.071 Y134.945 E.01659
G1 X151.62 Y134.66 E.0164
G1 X151.071 Y134.131 E.02344
G3 X150.559 Y133.223 I2.301 J-1.897 E.0322
G1 X150.417 Y132.51 E.02232
G3 X150.408 Y131.868 I2.168 J-.35 E.01981
G1 X150.782 Y131.88 F36000
G1 F15000
G3 X151.016 Y131.064 I2.612 J.311 E.02618
G1 X151.368 Y130.509 E.0202
G1 X151.732 Y130.133 E.01609
G1 X152.093 Y129.878 E.01357
G3 X152.858 Y129.575 I1.565 J2.83 E.02536
G1 X153.463 Y129.514 E.01868
G1 X154.058 Y129.575 E.01839
G1 X154.622 Y129.779 E.01841
G1 X155.162 Y130.114 E.01955
G1 X155.554 Y130.517 E.01725
G1 X155.898 Y131.061 E.0198
G1 X156.077 Y131.585 E.017
G1 X156.138 Y131.908 E.01012
G1 X156.13 Y132.507 E.01839
G1 X156 Y133.101 E.01869
G1 X155.739 Y133.629 E.01811
G1 X155.582 Y133.862 E.00864
G1 X155.032 Y134.391 E.02344
G1 X154.642 Y134.626 E.01399
G1 X154.048 Y134.827 E.01926
G1 X153.838 Y134.871 E.00659
G1 X153.074 Y134.87 E.02348
G1 X152.598 Y134.756 E.01504
G1 X152.007 Y134.469 E.02017
G3 X151.305 Y133.826 I4.769 J-5.909 E.02926
G3 X150.911 Y133.084 I2.513 J-1.809 E.02589
G1 X150.767 Y132.335 E.02344
G1 X150.78 Y131.94 E.01215
; WIPE_START
G1 X150.767 Y132.335 E-.15028
G1 X150.911 Y133.084 E-.28991
G1 X151.046 Y133.396 E-.12927
G1 X151.305 Y133.826 E-.19054
; WIPE_END
G1 E-.04 F1800
G1 X158.9 Y133.072 Z4.8 F36000
G1 X167.597 Y132.209 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X168.477 Y133.578 I19.143 J-11.351 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X151.881 Y136.53 E.37942
G3 X150.768 Y135.935 I1.694 J-4.513 E.04197
G1 X149.693 Y137.011 E.05043
G2 X145.602 Y133.425 I-22.205 J21.211 E.18067
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.323 I24.85 J-22.135 E.11976
G2 X154.34 Y117.012 I-5.147 J3.784 E.06131
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.346 J30.264 E.05401
G1 X128.017 Y124.355 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F15000
G1 X127.403 Y124.281 E.01898
G1 X126.819 Y124.082 E.01897
G1 X126.426 Y123.845 E.0141
G1 X125.877 Y123.315 E.02344
G1 X125.585 Y122.841 E.0171
G1 X125.456 Y122.54 E.01008
G1 X125.311 Y121.791 E.02344
G1 X125.326 Y121.336 E.01399
G1 X125.463 Y120.773 E.01781
G1 X125.732 Y120.206 E.01927
G1 X126.093 Y119.764 E.01754
G1 X126.313 Y119.56 E.0092
G1 X126.969 Y119.171 E.02343
G1 X127.402 Y119.031 E.014
G1 X127.995 Y118.97 E.0183
G1 X128.602 Y119.031 E.01877
G1 X129.166 Y119.234 E.0184
G1 X129.706 Y119.57 E.01955
G1 X130.059 Y119.927 E.01543
G1 X130.449 Y120.531 E.02208
G3 X130.682 Y121.364 I-2.811 J1.235 E.02668
G1 X130.674 Y121.963 E.01839
G1 X130.544 Y122.557 E.01869
G1 X130.283 Y123.085 E.0181
G1 X129.882 Y123.592 E.01986
G3 X129.186 Y124.082 I-2.191 J-2.375 E.02624
G1 X128.592 Y124.283 E.01926
G1 X128.076 Y124.348 E.01597
G1 X128.046 Y124.731 F36000
G1 F15000
G3 X126.164 Y124.116 I-.055 J-3.018 E.06196
G1 X125.615 Y123.587 E.02344
G3 X125.103 Y122.678 I2.3 J-1.897 E.03221
G1 X124.961 Y121.966 E.02231
G3 X124.956 Y121.264 I2.372 J-.369 E.02166
G1 X125.108 Y120.645 E.01959
G1 X125.4 Y120.026 E.02104
G3 X126.076 Y119.265 I2.553 J1.587 E.03143
G1 X126.709 Y118.886 E.02264
G1 X127.26 Y118.678 E.01811
G3 X128.744 Y118.678 I.742 J3.345 E.04597
G1 X129.333 Y118.897 E.0193
G3 X130.352 Y119.686 I-1.444 J2.916 E.03986
G1 X130.766 Y120.326 E.02344
G3 X130.879 Y122.738 I-2.863 J1.343 E.07613
G1 X130.599 Y123.29 E.01899
G3 X129.327 Y124.431 I-2.694 J-1.723 E.05319
G1 X128.678 Y124.65 E.02103
G1 X128.105 Y124.723 E.01775
G1 X128.054 Y125.112 F36000
; LINE_WIDTH: 0.429606
G1 F15000
G2 X131.328 Y120.734 I-.064 J-3.461 E.19855
G1 X131.116 Y120.165 E.01916
G1 X130.701 Y119.512 E.02435
G1 X130.254 Y119.043 E.02044
G2 X126.779 Y118.431 I-2.264 J2.685 E.11647
G1 X126.165 Y118.75 E.0218
G2 X124.564 Y121.935 I1.85 J2.925 E.118
G1 X124.709 Y122.684 E.02404
G1 X124.89 Y123.153 E.01583
G1 X125.214 Y123.693 E.01986
G2 X126.499 Y124.77 I3.129 J-2.431 E.05323
G2 X127.994 Y125.108 I1.608 J-3.631 E.0486
G1 X127.908 Y125.491 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X128.427 Y125.473 E.01595
G1 X129.079 Y125.336 E.02048
G2 X130.985 Y124.072 I-1.125 J-3.765 E.0713
G2 X131.736 Y122.539 I-3.621 J-2.725 E.05277
G1 X131.827 Y121.885 E.02027
G2 X130.961 Y119.221 I-3.85 J-.222 E.08808
G1 X130.507 Y118.76 E.01989
G1 X130.065 Y118.425 E.01703
G1 X129.505 Y118.135 E.01939
G2 X126.74 Y118.036 I-1.513 J3.584 E.08692
G1 X125.973 Y118.405 E.02614
G2 X124.192 Y122.105 I2.068 J3.274 E.13301
G1 X124.341 Y122.79 E.02152
G1 X124.535 Y123.3 E.01676
G1 X124.904 Y123.913 E.022
G2 X126.71 Y125.271 I3.16 J-2.322 E.07044
G1 X127.34 Y125.433 E.01997
G1 X127.848 Y125.485 E.01571
G1 X127.886 Y125.868 F36000
G1 F15000
G2 X132.197 Y121.294 I.109 J-4.216 E.21789
G2 X131.755 Y119.75 I-4.069 J.329 E.04965
G1 X131.326 Y119.071 E.0247
G2 X126.416 Y117.761 I-3.324 J2.604 E.16753
G1 X125.79 Y118.075 E.02151
G2 X124.998 Y118.707 I2.005 J3.33 E.03123
G1 X124.528 Y119.284 E.02286
G2 X123.798 Y121.848 I3.528 J2.39 E.08333
G1 X123.885 Y122.549 E.02169
G2 X124.596 Y124.131 I4.339 J-1 E.05364
G2 X127.827 Y125.861 I3.417 J-2.497 E.11647
G1 X124.368 Y124.488 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X124.393 Y124.522 E.00141
G2 X125.572 Y125.572 I3.953 J-3.253 E.05257
G1 X127.713 Y127.714 E.10046
G3 X128.286 Y127.714 I.288 J8.198 E.019
G1 X130.456 Y125.558 E.10145
G2 X131.632 Y124.494 I-2.752 J-4.224 E.05281
G1 X113.77 Y131.309 F36000
G1 F15476.087
G3 X115.224 Y130.576 I15.769 J29.459 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.778 I1.392 J2.463 E.03858
G3 X98.118 Y121.146 I-32.793 J-23.325 E.1428
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.731 J27.772 E.18055
G1 X105.233 Y135.938 E.05046
G3 X104.115 Y136.533 I-2.813 J-3.936 E.04217
G1 X96.032 Y144.616 E.37919
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.817 J-11.761 E.054
G1 X104.787 Y128.185 F36000
G1 F15476.087
G1 X122.015 Y110.957 E.8082
G3 X118.944 Y111.268 I-4.387 J-27.975 E.10243
G1 X125.482 Y117.806 E.30671
G1 X125.53 Y117.772 E.00196
G3 X130.519 Y117.804 I2.47 J3.924 E.17476
G1 X137.055 Y111.268 E.30662
M73 P67 R6
G3 X133.984 Y110.956 I1.331 J-28.348 E.10248
G1 X151.215 Y128.187 E.80834
G1 X115.627 Y111.14 F36000
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.842 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.366 J.128 E.04916
G1 X86.809 Y140.541 E.13381
G1 X90.708 Y142.264 E.14141
G1 X98.528 Y134.444 E.36686
G3 X98.812 Y129.516 I4.018 J-2.24 E.1728
G1 X93.83 Y124.534 E.23373
G2 X90.988 Y126.402 I5.506 J11.472 E.11314
G2 X90.068 Y128.448 I10.566 J5.979 E.07454
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.046 J23.848 E.05401
G1 X107.153 Y132.175 F36000
G1 F15476.087
G1 X107.154 Y132.192 E.00055
G3 X106.876 Y133.771 I-5.052 J-.072 E.05343
G1 X130.659 Y109.989 E1.1157
G2 X128.157 Y109.22 I-4.596 J10.508 E.08701
G2 X126.631 Y109.521 I.052 J4.292 E.0519
G1 X125.341 Y109.989 E.04552
G1 X149.132 Y133.78 E1.11609
G1 X149.114 Y133.739 E.00148
G3 X148.851 Y132.184 I4.872 J-1.624 E.0525
; WIPE_START
G1 X148.881 Y132.731 E-.20783
G1 X149.114 Y133.739 E-.39324
G1 X149.132 Y133.78 E-.017
G1 X148.868 Y133.516 E-.14193
; WIPE_END
G1 E-.04 F1800
G1 X141.246 Y133.111 Z4.8 F36000
G1 X106.657 Y131.271 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F15000
G2 X106.299 Y130.295 I-4.11 J.951 E.03203
G1 X105.87 Y129.615 E.02471
G2 X99.23 Y129.606 I-3.323 J2.605 E.23475
G1 X98.796 Y130.291 E.02493
G2 X98.975 Y134.441 I3.789 J1.915 E.13335
G2 X102.112 Y136.393 I3.602 J-2.291 E.11741
G1 X102.967 Y136.395 E.02629
G2 X106.741 Y131.838 I-.441 J-4.206 E.20134
G2 X106.666 Y131.33 I-2.494 J.108 E.01579
G1 X106.361 Y131.8 F36000
G1 F15000
G2 X100.662 Y128.867 I-3.821 J.422 E.23285
G1 X100.185 Y129.181 E.01755
G1 X99.735 Y129.6 E.01887
G1 X99.313 Y130.14 E.02107
G2 X99.814 Y134.896 I3.281 J2.058 E.15836
G2 X101.255 Y135.815 I3.123 J-3.303 E.05283
G1 X101.884 Y135.977 E.01997
G1 X102.519 Y136.039 E.01961
G1 X103.146 Y135.987 E.01934
G2 X104.601 Y135.442 I-.772 J-4.277 E.04799
G1 X105.14 Y135.024 E.02097
G1 X105.529 Y134.616 E.01731
G2 X106.28 Y133.083 I-3.61 J-2.72 E.05277
G1 X106.371 Y132.429 E.02027
G1 X106.364 Y131.86 E.0175
G1 X105.98 Y131.821 F36000
; LINE_WIDTH: 0.429017
G1 F15000
G1 X105.873 Y131.278 E.0174
G1 X105.66 Y130.709 E.01913
G1 X105.246 Y130.056 E.02432
G1 X104.798 Y129.587 E.02041
G2 X99.635 Y130.369 I-2.245 J2.608 E.18649
G1 X99.386 Y130.812 E.01598
G2 X99.312 Y133.412 I3.321 J1.396 E.08372
G2 X102.155 Y135.632 I3.279 J-1.267 E.1192
G1 X102.926 Y135.633 E.02423
G1 X103.518 Y135.515 E.01902
G2 X105.984 Y131.881 I-1.007 J-3.337 E.14947
G1 X105.601 Y131.859 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G3 X105.423 Y133.282 I-3.59 J.275 E.04437
G1 X105.143 Y133.834 E.019
G3 X103.871 Y134.975 I-2.706 J-1.737 E.05316
G1 X103.222 Y135.194 E.02104
G1 X102.926 Y135.248 E.00925
G1 X102.159 Y135.247 E.02357
G1 X101.661 Y135.145 E.01561
G1 X101.161 Y134.946 E.01653
G1 X100.636 Y134.602 E.0193
G3 X99.945 Y133.826 I2.105 J-2.572 E.03205
G1 X99.67 Y133.282 E.01872
G1 X99.527 Y132.775 E.01621
G3 X99.653 Y131.189 I3.212 J-.542 E.04937
G1 X99.784 Y130.867 E.0107
G1 X100.2 Y130.227 E.02344
G3 X101.889 Y129.202 I2.414 J2.075 E.06172
G1 X102.539 Y129.137 E.02007
G1 X103.204 Y129.202 E.02054
G3 X104.896 Y130.23 I-.634 J2.951 E.06197
G1 X105.31 Y130.87 E.02344
G3 X105.589 Y131.8 I-2.507 J1.258 E.02998
G1 X105.226 Y131.908 F36000
G1 F15000
G1 X105.218 Y132.507 E.01839
G1 X105.089 Y133.101 E.01869
G1 X104.827 Y133.629 E.01811
G1 X104.426 Y134.136 E.01984
G1 X103.99 Y134.474 E.01696
G1 X103.398 Y134.759 E.02018
G1 X102.926 Y134.871 E.01491
G1 X102.162 Y134.87 E.02348
G1 X101.686 Y134.756 E.01504
G1 X101.096 Y134.469 E.02016
G1 X100.687 Y134.156 E.01582
G3 X100.261 Y133.622 I1.516 J-1.647 E.02108
G1 X100.014 Y133.128 E.01695
G1 X99.873 Y132.498 E.01985
G1 X99.867 Y131.909 E.01811
G1 X100.008 Y131.317 E.0187
G1 X100.101 Y131.072 E.00804
G1 X100.516 Y130.432 E.02344
G1 X100.842 Y130.114 E.014
G1 X101.391 Y129.775 E.01983
G1 X101.918 Y129.582 E.01724
G1 X102.539 Y129.514 E.01918
G1 X103.147 Y129.575 E.01877
G1 X103.71 Y129.779 E.01841
G1 X104.251 Y130.114 E.01955
G1 X104.603 Y130.471 E.01543
G1 X104.993 Y131.075 E.02208
G1 X105.166 Y131.585 E.01653
G1 X105.215 Y131.849 E.00828
G1 X111.04 Y113.314 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X112.36 Y112.361 I-13.404 J-19.957 E.05402
G1 X124.148 Y124.176 E.55363
G1 X119.326 Y128.997 E.22617
G3 X120.891 Y128.567 I10.051 J33.499 E.05383
G1 X107.571 Y115.247 E.62487
G3 X106.038 Y115.792 I-7.022 J-17.349 E.05399
; CHANGE_LAYER
; Z_HEIGHT: 4.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X107.571 Y115.247 E-.61834
G1 X107.835 Y115.511 E-.14166
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
G1 X125.719 Y121.367
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.783 Y121.049 E.01076
G3 X127.826 Y119.362 I2.22 J.607 E.09365
G3 X128.596 Y119.438 I.129 J2.645 E.02576
G1 X128.864 Y119.522 E.00931
G3 X125.713 Y121.427 I-.861 J2.134 E.33807
G1 X126.106 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.897 J.217 E.08095
G1 X128.149 Y119.754 E.00899
G3 X126.1 Y121.5 I-.146 J1.903 E.27678
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.13384
G1 X126.259 Y120.878 E-.11115
G1 X126.399 Y120.621 E-.11116
G1 X126.576 Y120.388 E-.11116
G1 X126.787 Y120.185 E-.11115
G1 X127.026 Y120.017 E-.11113
G1 X127.192 Y119.935 E-.0704
; WIPE_END
G1 E-.04 F1800
G1 X120.105 Y122.768 Z5 F36000
G1 X102.182 Y129.935 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.37 Y129.906 E.00633
G3 X102.474 Y134.502 I.176 J2.295 E.24804
G3 X102.022 Y129.96 I.074 J-2.301 E.21979
G1 X102.122 Y129.945 E.00338
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00899
G3 X102.341 Y130.304 I-.146 J1.904 E.35789
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13383
G1 X102.982 Y130.343 E-.11117
G1 X103.261 Y130.431 E-.11115
G1 X103.523 Y130.561 E-.11116
G1 X103.762 Y130.729 E-.11114
G1 X103.973 Y130.932 E-.11114
G1 X104.085 Y131.079 E-.07041
; WIPE_END
G1 E-.04 F1800
G1 X111.717 Y131.159 Z5 F36000
G1 X155.685 Y131.62 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.744 Y131.939 E.01076
G3 X153.282 Y129.906 I-2.286 J.26 E.36241
G1 X153.634 Y129.906 E.0117
G3 X155.669 Y131.563 I-.176 J2.294 E.0926
G1 X155.304 Y131.713 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.354 Y131.984 E.00848
G3 X153.312 Y130.298 I-1.896 J.216 E.2784
G1 X153.604 Y130.298 E.00899
G3 X155.287 Y131.656 I-.146 J1.902 E.07061
; WIPE_START
M204 S10000
G1 X155.354 Y131.984 E-.12749
G1 X155.367 Y132.276 E-.11106
G1 X155.334 Y132.567 E-.11119
G1 X155.256 Y132.849 E-.11114
G1 X155.137 Y133.116 E-.11115
G1 X154.978 Y133.361 E-.11112
G1 X154.843 Y133.512 E-.07684
; WIPE_END
G1 E-.04 F1800
G1 X155.266 Y141.133 Z5 F36000
G1 X155.589 Y146.934 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.718 E2.35658
G1 X83.055 Y139.263 E.62961
G3 X83.41 Y137.866 I3.58 J.167 E.04814
G3 X84.377 Y136.65 I5.969 J3.754 E.05162
G2 X86.79 Y133.986 I-24.73 J-24.817 E.11929
G2 X89.501 Y128.988 I-13.843 J-10.746 E.18946
G3 X90.41 Y126.674 I23.309 J7.817 E.0825
G3 X91.435 Y125.548 I2.417 J1.171 E.05121
G3 X93.349 Y124.413 I15.94 J24.684 E.07382
G2 X98.059 Y120.701 I-8.564 J-15.715 E.19987
G2 X100.325 Y117.807 I-37.406 J-31.606 E.12197
G3 X101.394 Y116.758 I3.536 J2.536 E.04993
G3 X103.044 Y116.197 I3.008 J6.142 E.05796
G2 X106.576 Y115.257 I-6.545 J-31.731 E.12132
G2 X111.534 Y112.534 I-5.974 J-16.747 E.18843
G3 X113.513 Y111.136 I14.723 J18.742 E.0804
G3 X115.145 Y110.777 I1.449 J2.701 E.05614
G3 X117.853 Y110.909 I-7.766 J188.219 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.105 J28.241 E.09116
G3 X128.183 Y108.872 I.644 J2.633 E.02774
G3 X129.664 Y109.258 I-.81 J6.13 E.05089
G2 X133.389 Y110.477 I12.298 J-31.286 E.1301
G2 X138.729 Y110.881 I3.984 J-17.198 E.17831
G3 X141.237 Y110.779 I2.303 J25.76 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05112
G3 X144.474 Y112.538 I-15.394 J23.433 E.07316
G2 X149.427 Y115.257 I11.081 J-14.315 E.18822
G2 X152.965 Y116.193 I9.837 J-30.03 E.12147
G3 X154.569 Y116.731 I-1.273 J6.46 E.05628
G3 X155.674 Y117.809 I-2.602 J3.771 E.05147
G2 X157.946 Y120.702 I41.964 J-30.613 E.12201
G2 X162.421 Y124.276 I12.716 J-11.334 E.19091
G3 X164.758 Y125.674 I-13.531 J25.27 E.09035
G3 X165.746 Y127.012 I-1.782 J2.348 E.05595
G3 X166.938 Y130.092 I-675.251 J263.345 E.10954
G2 X170.649 Y135.623 I16.057 J-6.761 E.22231
G3 X172.333 Y137.457 I-17.037 J17.33 E.08263
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.195 E2.17924
G1 X82.639 Y139.508 E.60452
G3 X82.93 Y137.961 I5.49 J.232 E.04851
G3 X83.717 Y136.795 I3.809 J1.722 E.04345
G2 X85.862 Y134.489 I-443.513 J-414.765 E.09676
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.438 J7.864 E.07788
G3 X91.212 Y125.226 I2.76 J1.348 E.05329
G3 X93.152 Y124.073 I16.115 J24.926 E.06936
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18128
G2 X100.018 Y117.563 I-37.334 J-31.523 E.11231
G3 X101.193 Y116.421 I3.822 J2.758 E.05061
G3 X102.951 Y115.816 I3.187 J6.403 E.0573
G2 X106.448 Y114.887 I-6.458 J-31.366 E.11123
G2 X111.301 Y112.218 I-5.848 J-16.382 E.1709
G3 X113.32 Y110.795 I14.855 J18.918 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05819
G3 X117.867 Y110.517 I-7.449 J182.411 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.208 J33.895 E.07784
G3 X128.217 Y108.481 I.982 J3.111 E.03745
G3 X129.793 Y108.888 I-.84 J6.502 E.05017
G2 X133.154 Y110.014 I13.012 J-33.268 E.10895
G2 X138.707 Y110.489 I4.212 J-16.533 E.17203
G3 X141.261 Y110.387 I2.31 J25.875 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05322
G3 X144.706 Y112.222 I-15.545 J23.692 E.06878
G2 X149.556 Y114.887 I10.853 J-14.005 E.17076
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.77 Y116.394 I-1.342 J6.762 E.05576
G3 X155.765 Y117.301 I-2.182 J3.392 E.04156
G2 X157.819 Y119.952 I1352.927 J-1045.99 E.10304
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.312 J30.222 E.07721
G3 X166.104 Y126.854 I-1.827 J2.82 E.06588
G3 X167.3 Y129.94 I-592.302 J231.27 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.224 J17.509 E.07791
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.393 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38731
G1 X154.608 Y145.61 E-.07071
; WIPE_END
G1 E-.04 F1800
G1 X156.247 Y138.155 Z5 F36000
G1 X157.649 Y131.779 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X157.421 Y130.774 I-3.922 J.363 E.03178
G1 X157.06 Y130.021 E.02564
G2 X156.41 Y129.198 I-3.36 J1.986 E.03231
G1 X155.74 Y128.662 E.02638
G2 X149.649 Y134.001 I-2.275 J3.549 E.33407
G2 X157.381 Y133.729 I3.807 J-1.805 E.3012
G2 X157.653 Y131.839 I-3.788 J-1.509 E.05921
G1 X157.273 Y131.8 F36000
G1 F12000
G2 X152.196 Y128.58 I-3.832 J.429 E.21185
G1 X151.574 Y128.867 E.02106
G1 X151.096 Y129.181 E.01755
G2 X150.013 Y130.515 I2.888 J3.451 E.05313
G1 X149.785 Y131.114 E.01967
G2 X149.818 Y133.407 I3.742 J1.094 E.07154
G1 X150.005 Y133.875 E.01548
G1 X150.442 Y134.574 E.02533
G2 X156.052 Y135.024 I3.015 J-2.393 E.19391
G1 X156.44 Y134.616 E.01731
G2 X157.192 Y133.083 I-3.611 J-2.72 E.05277
G1 X157.283 Y132.429 E.02027
G1 X157.276 Y131.86 E.0175
; WIPE_START
G1 X157.283 Y132.429 E-.21645
G1 X157.192 Y133.083 E-.25071
G1 X157.033 Y133.584 E-.19982
G1 X156.928 Y133.805 E-.09302
; WIPE_END
G1 E-.04 F1800
G1 X152.552 Y129.669 Z5 F36000
G1 Z4.6
G1 E.8 F1800
G1 F12000
G1 X152.858 Y129.575 E.00984
G1 X153.463 Y129.514 E.01868
G1 X154.058 Y129.575 E.01839
G1 X154.622 Y129.779 E.01841
G1 X155.162 Y130.114 E.01955
G1 X155.554 Y130.517 E.01725
G1 X155.898 Y131.061 E.01981
G1 X156.077 Y131.585 E.017
G1 X156.138 Y131.908 E.01012
G1 X156.13 Y132.507 E.01839
G1 X156 Y133.101 E.01869
G1 X155.739 Y133.629 E.0181
G1 X155.338 Y134.136 E.01985
G1 X154.902 Y134.474 E.01696
G1 X154.31 Y134.759 E.02017
G1 X153.782 Y134.875 E.01663
G1 X153.444 Y134.899 E.01042
G1 X152.859 Y134.825 E.0181
G1 X152.275 Y134.626 E.01897
G1 X151.787 Y134.311 E.01783
G1 X151.567 Y134.123 E.0089
G1 X151.105 Y133.515 E.02345
G1 X150.916 Y133.101 E.01399
G1 X150.785 Y132.498 E.01897
G1 X150.778 Y131.908 E.0181
G1 X150.915 Y131.328 E.01831
G1 X151.187 Y130.75 E.01964
G1 X151.549 Y130.308 E.01754
G1 X152.062 Y129.898 E.02017
G1 X152.498 Y129.695 E.01478
G1 X152.438 Y129.31 F36000
G1 F12000
G1 X152.8 Y129.202 E.01161
G1 X153.463 Y129.137 E.02045
G1 X154.116 Y129.202 E.02017
G3 X155.446 Y129.861 I-.823 J3.334 E.04597
G1 X155.854 Y130.288 E.01814
G1 X156.06 Y130.57 E.01074
G1 X156.355 Y131.197 E.02129
G1 X156.505 Y131.808 E.01933
G3 X156.335 Y133.282 I-3.409 J.353 E.04597
G1 X156.055 Y133.834 E.019
G3 X154.782 Y134.975 I-2.707 J-1.738 E.05317
G1 X154.134 Y135.194 E.02103
G1 X153.501 Y135.275 E.01958
G3 X152.056 Y134.937 I.04 J-3.43 E.04597
G1 X151.547 Y134.602 E.01872
G1 X151.267 Y134.351 E.01156
G1 X150.805 Y133.744 E.02345
G3 X150.411 Y131.808 I2.726 J-1.562 E.06174
G1 X150.56 Y131.201 E.01921
G3 X151.537 Y129.806 I3.053 J1.098 E.05295
G3 X152.384 Y129.335 I1.747 J2.142 E.02993
; WIPE_START
G1 X151.926 Y129.541 E-.19087
G1 X151.537 Y129.806 E-.17878
G1 X151.288 Y130.037 E-.12909
G1 X150.903 Y130.497 E-.22801
G1 X150.86 Y130.573 E-.03325
; WIPE_END
G1 E-.04 F1800
G1 X156.892 Y131.821 Z5 F36000
G1 Z4.6
G1 E.8 F1800
; LINE_WIDTH: 0.427384
G1 F12000
G1 X156.784 Y131.278 E.01733
G1 X156.579 Y130.725 E.0185
G2 X150.499 Y133.976 I-3.115 J1.485 E.34965
G1 X150.962 Y134.584 E.02391
G1 X151.414 Y134.984 E.01892
G2 X156.896 Y131.881 I2.037 J-2.795 E.24811
; WIPE_START
G1 X156.903 Y132.408 E-.20026
G1 X156.833 Y132.932 E-.20096
G1 X156.682 Y133.438 E-.20083
G1 X156.503 Y133.814 E-.15795
; WIPE_END
G1 E-.04 F1800
G1 X151.276 Y128.252 Z5 F36000
G1 X151.215 Y128.187 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.984 Y110.956 E.80834
G2 X137.055 Y111.268 I4.402 J-28.035 E.10248
G1 X130.519 Y117.804 E.30662
G1 X130.463 Y117.764 E.00229
G2 X125.482 Y117.806 I-2.457 J3.929 E.17444
G1 X118.944 Y111.268 E.30671
G2 X122.015 Y110.957 I-1.317 J-28.289 E.10243
G1 X104.787 Y128.185 E.8082
G1 X106.738 Y131.779 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X106.299 Y130.294 I-4.542 J.534 E.0478
G1 X105.87 Y129.615 E.02471
G2 X98.379 Y131.608 I-3.319 J2.598 E.30223
G2 X101.82 Y136.348 I4.167 J.595 E.19908
G1 X102.497 Y136.416 E.02091
G2 X103.52 Y136.302 I.08 J-3.937 E.03169
G1 X104.303 Y136.031 E.02546
G2 X106.741 Y131.839 I-1.766 J-3.833 E.15873
G1 X106.361 Y131.8 F36000
G1 F12000
G2 X100.662 Y128.867 I-3.821 J.422 E.23285
G1 X100.185 Y129.181 E.01755
G2 X99.097 Y130.528 I2.865 J3.428 E.05353
G1 X98.874 Y131.113 E.01926
G2 X98.737 Y132.649 I4.088 J1.139 E.04765
G1 X98.885 Y133.334 E.02152
G1 X99.079 Y133.844 E.01675
G1 X99.448 Y134.457 E.022
G1 X99.814 Y134.895 E.01755
G2 X101.255 Y135.815 I3.123 J-3.303 E.05283
G1 X101.884 Y135.977 E.01996
G1 X102.519 Y136.039 E.01961
G1 X103.147 Y135.987 E.01935
G2 X104.601 Y135.442 I-.772 J-4.276 E.04798
G1 X105.14 Y135.024 E.02097
G1 X105.529 Y134.616 E.01731
G2 X106.28 Y133.083 I-3.61 J-2.72 E.05277
G1 X106.371 Y132.429 E.02027
G1 X106.364 Y131.86 E.0175
; WIPE_START
G1 X106.371 Y132.429 E-.21642
G1 X106.28 Y133.083 E-.25068
G1 X106.121 Y133.584 E-.1998
G1 X106.016 Y133.805 E-.09309
; WIPE_END
G1 E-.04 F1800
G1 X100.411 Y133.849 Z5 F36000
G1 Z4.6
G1 E.8 F1800
G1 F12000
G3 X100 Y133.084 I2.515 J-1.845 E.02676
G1 X99.855 Y132.335 E.02345
G1 X99.87 Y131.88 E.01399
G1 X100.008 Y131.317 E.01781
G1 X100.276 Y130.75 E.01926
G1 X100.637 Y130.308 E.01753
G1 X101.15 Y129.898 E.02018
G3 X101.946 Y129.575 I1.577 J2.746 E.02649
G1 X102.539 Y129.514 E.0183
G1 X103.147 Y129.575 E.01877
G1 X103.71 Y129.779 E.01841
G1 X104.251 Y130.114 E.01955
G1 X104.603 Y130.472 E.01543
G1 X104.993 Y131.075 E.02208
G3 X105.226 Y131.908 I-2.811 J1.235 E.02668
G1 X105.218 Y132.507 E.01839
G1 X105.089 Y133.101 E.01869
G1 X104.827 Y133.629 E.01811
G1 X104.426 Y134.136 E.01984
G1 X103.99 Y134.474 E.01696
G1 X103.399 Y134.759 E.02018
G1 X102.927 Y134.871 E.0149
G1 X102.162 Y134.87 E.02349
G1 X101.686 Y134.756 E.01504
G1 X101.096 Y134.469 E.02016
G1 X100.687 Y134.156 E.01582
G1 X100.451 Y133.893 E.01085
G1 X100.129 Y134.099 F36000
G1 F12000
G3 X99.641 Y133.204 I2.355 J-1.864 E.03147
G1 X99.505 Y132.511 E.02173
G3 X99.5 Y131.808 I2.372 J-.369 E.02166
G1 X99.653 Y131.189 E.01959
G1 X99.944 Y130.57 E.02104
G3 X101.014 Y129.541 I2.851 J1.892 E.04597
G3 X101.889 Y129.202 I1.695 J3.083 E.02891
G1 X102.539 Y129.137 E.02007
G1 X103.204 Y129.202 E.02054
G3 X104.896 Y130.229 I-.634 J2.95 E.06195
G1 X105.31 Y130.87 E.02345
G3 X105.423 Y133.282 I-2.863 J1.343 E.07613
G1 X105.143 Y133.834 E.019
G3 X103.871 Y134.975 I-2.707 J-1.738 E.05317
G1 X103.222 Y135.194 E.02104
G1 X102.926 Y135.248 E.00923
G1 X102.159 Y135.247 E.02358
G1 X101.661 Y135.145 E.01561
G1 X101.161 Y134.946 E.01653
G1 X100.636 Y134.602 E.01931
G3 X100.169 Y134.144 I1.473 J-1.969 E.02015
; WIPE_START
G1 X100.385 Y134.387 E-.12342
G1 X100.636 Y134.602 E-.12556
G1 X101.161 Y134.946 E-.23877
G1 X101.661 Y135.145 E-.20437
G1 X101.836 Y135.181 E-.06788
; WIPE_END
G1 E-.04 F1800
G1 X105.98 Y131.821 Z5 F36000
G1 Z4.6
G1 E.8 F1800
; LINE_WIDTH: 0.429136
G1 F12000
G1 X105.873 Y131.278 E.0174
G1 X105.66 Y130.709 E.01913
G1 X105.245 Y130.056 E.02433
G1 X104.798 Y129.587 E.02041
G2 X99.094 Y132.263 I-2.244 J2.633 E.24924
G1 X99.19 Y132.964 E.02227
G2 X101.527 Y135.502 I3.347 J-.737 E.11377
G1 X102.155 Y135.632 E.0202
G1 X102.926 Y135.633 E.02425
G1 X103.519 Y135.515 E.01902
G2 X105.984 Y131.881 I-1.007 J-3.337 E.14951
G1 X102.064 Y142.685 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.25 J11.558 E.05398
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.926 J1.552 E.0865
G3 X93.83 Y124.534 I9.845 J12.995 E.10129
G1 X98.812 Y129.516 E.23373
G2 X98.528 Y134.444 I3.734 J2.687 E.1728
G1 X90.708 Y142.264 E.36686
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.13381
G2 X83.434 Y139.05 I1.845 J1.489 E.04916
G1 X85.385 Y139.911 E.07073
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.707 E.05406
G1 X106.038 Y115.792 F36000
G1 F15476.087
G2 X107.571 Y115.247 I-5.489 J-17.894 E.05399
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.486 J33.929 E.05383
G1 X124.148 Y124.176 E.22617
G1 X112.36 Y112.361 E.55363
G3 X111.04 Y113.314 I-14.74 J-19.026 E.05402
; WIPE_START
G1 X112.36 Y112.361 E-.61871
G1 X112.623 Y112.624 E-.14129
; WIPE_END
G1 E-.04 F1800
G1 X119.609 Y115.698 Z5 F36000
M73 P68 R6
G1 X132.194 Y121.235 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X131.755 Y119.75 I-4.541 J.533 E.04781
G1 X131.326 Y119.071 E.0247
G2 X125.934 Y117.995 I-3.322 J2.602 E.18399
G2 X127.886 Y125.868 I2.074 J3.664 E.33605
G2 X130.427 Y125.098 I.094 J-4.271 E.08295
G1 X130.946 Y124.672 E.02063
G2 X131.59 Y123.866 I-2.724 J-2.837 E.0318
G1 X131.925 Y123.185 E.02333
G2 X132.197 Y121.295 I-3.79 J-1.509 E.0592
G1 X131.817 Y121.256 F36000
G1 F12000
G2 X126.117 Y118.325 I-3.821 J.421 E.23288
G1 X125.641 Y118.637 E.0175
G2 X124.552 Y119.983 I2.865 J3.429 E.05353
G1 X124.329 Y120.569 E.01927
G2 X124.362 Y122.863 I3.742 J1.094 E.07154
G1 X124.553 Y123.338 E.01575
G1 X124.904 Y123.913 E.02068
G1 X125.27 Y124.351 E.01755
G2 X126.71 Y125.271 I3.107 J-3.279 E.05283
G1 X127.34 Y125.433 E.01997
G2 X129.615 Y125.138 I.658 J-3.851 E.07154
G1 X130.067 Y124.891 E.01584
G1 X130.695 Y124.391 E.02468
G2 X131.822 Y121.961 I-2.858 J-2.802 E.08391
G1 X131.82 Y121.316 E.01982
; WIPE_START
G1 X131.822 Y121.961 E-.24517
G1 X131.736 Y122.539 E-.22215
G1 X131.577 Y123.04 E-.19955
G1 X131.473 Y123.262 E-.09313
; WIPE_END
G1 E-.04 F1800
G1 X125.732 Y120.205 Z5 F36000
G1 Z4.6
G1 E.8 F1800
G1 F12000
G1 X126.093 Y119.764 E.01752
G1 X126.596 Y119.361 E.01979
G1 X127.096 Y119.125 E.017
G1 X127.402 Y119.031 E.00983
G1 X127.995 Y118.97 E.0183
G1 X128.602 Y119.031 E.01877
G1 X129.166 Y119.234 E.01841
G1 X129.706 Y119.57 E.01955
G1 X130.059 Y119.927 E.01543
G1 X130.449 Y120.531 E.02208
G3 X130.682 Y121.364 I-2.812 J1.235 E.02668
G1 X130.672 Y121.903 E.01655
G1 X130.548 Y122.543 E.02004
G1 X130.283 Y123.085 E.01852
G1 X130.126 Y123.318 E.00863
G1 X129.576 Y123.846 E.02345
G1 X129.186 Y124.082 E.014
G1 X128.592 Y124.283 E.01926
G1 X128.017 Y124.355 E.01782
G1 X127.403 Y124.281 E.01898
G1 X126.819 Y124.082 E.01897
G1 X126.332 Y123.767 E.01782
G1 X125.867 Y123.305 E.02014
G1 X125.585 Y122.841 E.01667
G1 X125.368 Y122.221 E.02018
G1 X125.31 Y121.684 E.01661
G1 X125.326 Y121.336 E.01071
G1 X125.463 Y120.773 E.01781
G1 X125.706 Y120.259 E.01745
G1 X125.402 Y120.023 F36000
G1 F12000
G3 X126.47 Y118.996 I2.853 J1.898 E.04589
G3 X127.345 Y118.658 I1.695 J3.081 E.02891
G1 X127.995 Y118.593 E.02007
G1 X128.66 Y118.658 E.02054
G3 X130.352 Y119.685 I-.634 J2.951 E.06195
G1 X130.766 Y120.326 E.02345
G3 X131.064 Y121.866 I-2.97 J1.373 E.04866
G1 X130.918 Y122.615 E.02345
G1 X130.722 Y123.089 E.01575
G1 X130.416 Y123.56 E.01728
G1 X129.88 Y124.077 E.02288
G1 X129.404 Y124.393 E.01753
G1 X128.915 Y124.594 E.01626
G3 X127.317 Y124.648 I-.905 J-3.122 E.04962
G1 X126.678 Y124.431 E.02075
G3 X125.533 Y123.487 I1.562 J-3.06 E.04597
G3 X125.097 Y122.657 I2.899 J-2.054 E.0289
G1 X124.955 Y121.997 E.02074
G1 X124.946 Y121.35 E.01988
G3 X125.373 Y120.076 I3.413 J.436 E.04155
; WIPE_START
G1 X125.217 Y120.363 E-.12411
G1 X125.041 Y120.837 E-.19226
G1 X124.946 Y121.35 E-.19809
G1 X124.955 Y121.996 E-.24554
; WIPE_END
G1 E-.04 F1800
G1 X131.436 Y121.277 Z5 F36000
G1 Z4.6
G1 E.8 F1800
; LINE_WIDTH: 0.429195
G1 F12000
G1 X131.328 Y120.734 E.01741
G1 X131.116 Y120.165 E.01913
G1 X130.701 Y119.512 E.02433
G1 X130.254 Y119.043 E.02042
G2 X129.928 Y124.524 I-2.246 J2.617 E.48206
G1 X130.432 Y124.095 E.0208
G2 X131.272 Y122.77 I-2.618 J-2.588 E.04977
G1 X131.426 Y122.049 E.0232
G2 X131.439 Y121.337 I-2.85 J-.409 E.02249
G1 X131.632 Y124.494 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X131.611 Y124.522 E.00115
G3 X130.425 Y125.575 I-3.896 J-3.198 E.05283
G1 X128.286 Y127.714 E.10033
G2 X127.713 Y127.714 I-.285 J8.198 E.019
G1 X125.561 Y125.566 E.10087
G3 X124.368 Y124.488 I2.743 J-4.232 E.05355
G1 X142.231 Y131.307 F36000
G1 F15476.087
G2 X140.777 Y130.574 I-15.794 J29.519 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.633 Y118.323 I-3.859 J5.1 E.06131
G2 X157.884 Y121.144 I27.086 J-19.304 E.11976
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-18.114 J24.796 E.18067
G1 X150.768 Y135.935 E.05043
G2 X151.881 Y136.53 I2.807 J-3.919 E.04197
G1 X159.969 Y144.617 E.37942
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.253 J-12.713 E.054
; WIPE_START
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
; WIPE_END
G1 E-.04 F1800
G1 X160.609 Y133.191 Z5 F36000
G1 X148.851 Y132.184 Z5
G1 Z4.6
G1 E.8 F1800
G1 F15476.087
G1 X148.851 Y132.192 E.00024
G2 X149.132 Y133.78 I5.034 J-.071 E.05373
G1 X125.341 Y109.989 E1.11609
G3 X128.006 Y109.211 I4.416 J10.178 E.09234
G3 X130.659 Y109.989 I-1.985 J11.691 E.09193
G1 X106.891 Y133.736 E1.11452
G2 X107.153 Y132.175 I-4.846 J-1.614 E.0527
; WIPE_START
G1 X107.123 Y132.731 E-.21131
G1 X106.891 Y133.736 E-.39208
G1 X107.183 Y133.445 E-.15661
; WIPE_END
G1 E-.04 F1800
G1 X99.567 Y132.944 Z5 F36000
G1 X88.404 Y132.211 Z5
G1 Z4.6
G1 E.8 F1800
G1 F15476.087
G3 X87.525 Y133.581 I-17.718 J-10.404 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X104.115 Y136.533 E.37919
G2 X105.233 Y135.938 I-1.695 J-4.532 E.04217
G1 X106.309 Y137.013 E.05046
G3 X110.399 Y133.428 I22.212 J21.213 E.18067
G1 X98.118 Y121.147 E.57613
G2 X100.796 Y117.779 I-30.137 J-26.71 E.14279
G3 X101.665 Y117.017 I2.261 J1.702 E.0386
G1 X115.224 Y130.576 E.6361
G2 X113.77 Y131.309 I14.318 J30.195 E.05401
; WIPE_START
G1 X115.224 Y130.576 E-.61863
G1 X114.961 Y130.313 E-.14137
; WIPE_END
G1 E-.04 F1800
G1 X121.054 Y125.717 Z5 F36000
G1 X140.386 Y111.134 Z5
G1 Z4.6
G1 E.8 F1800
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.38 E.05407
G1 X170.616 Y139.912 E1.34272
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.419 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X157.474 Y134.447 E.36675
G2 X157.19 Y129.513 I-4.017 J-2.244 E.17305
G1 X162.172 Y124.532 E.2337
G3 X164.985 Y126.364 I-5.41 J11.378 E.11169
G3 X165.932 Y128.447 I-10.698 J6.124 E.07602
G1 X153.083 Y141.297 E.60279
G3 X153.939 Y142.682 I-19.42 J12.96 E.05402
G1 X144.962 Y113.313 F36000
G1 F15476.087
G3 X143.645 Y112.355 I11.762 J-17.56 E.05402
G1 X131.911 Y124.098 E.55067
G3 X131.855 Y124.179 I-.739 J-.449 E.00328
G1 X136.671 Y128.995 E.22592
G2 X135.109 Y128.566 I-10.009 J33.387 E.05372
G1 X148.43 Y115.246 E.6249
G2 X149.963 Y115.79 I7.003 J-17.286 E.05399
; CHANGE_LAYER
; Z_HEIGHT: 4.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X148.43 Y115.246 E-.61834
G1 X148.166 Y115.509 E-.14167
; WIPE_END
G1 E-.03999 F1800
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
G1 X125.719 Y121.368
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X125.783 Y121.049 E.01078
G3 X127.477 Y119.416 I2.22 J.607 E.08194
G1 X127.829 Y119.362 E.01179
G3 X125.713 Y121.427 I.175 J2.295 E.37318
G1 X126.106 Y121.44 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.567 Y119.799 I1.896 J.217 E.07195
G1 X127.857 Y119.754 E.00902
G3 X126.1 Y121.5 I.145 J1.903 E.28562
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.13383
G1 X126.259 Y120.878 E-.11117
G1 X126.399 Y120.621 E-.11114
G1 X126.576 Y120.388 E-.11116
G1 X126.787 Y120.185 E-.11115
G1 X127.026 Y120.017 E-.11116
G1 X127.192 Y119.935 E-.0704
; WIPE_END
G1 E-.04 F1800
G1 X120.104 Y122.766 Z5.2 F36000
G1 X102.147 Y129.941 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.37 Y129.906 E.00749
G1 X102.723 Y129.906 E.0117
G3 X102.022 Y129.96 I-.176 J2.295 E.45639
G1 X102.088 Y129.95 E.00221
G1 X102.4 Y130.298 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00899
G3 X102.341 Y130.304 I-.146 J1.903 E.35773
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13382
G1 X102.982 Y130.343 E-.11116
G1 X103.261 Y130.431 E-.11116
G1 X103.523 Y130.561 E-.11115
G1 X103.762 Y130.729 E-.11117
G1 X103.973 Y130.932 E-.11113
G1 X104.085 Y131.079 E-.07041
; WIPE_END
G1 E-.04 F1800
G1 X111.717 Y131.151 Z5.2 F36000
G1 X155.67 Y131.567 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.679 Y131.593 E.00092
G3 X153.282 Y129.906 I-2.221 J.609 E.37453
G1 X153.634 Y129.906 E.0117
G3 X155.56 Y131.261 I-.176 J2.296 E.08197
G1 X155.65 Y131.51 E.00879
G1 X155.304 Y131.715 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.355 Y131.985 E.00846
G3 X153.312 Y130.298 I-1.897 J.217 E.27867
G1 X153.604 Y130.298 E.00899
G3 X155.288 Y131.657 I-.146 J1.904 E.07067
; WIPE_START
M204 S10000
G1 X155.355 Y131.985 E-.12738
G1 X155.365 Y132.293 E-.11699
G1 X155.334 Y132.567 E-.10487
G1 X155.256 Y132.849 E-.11117
G1 X155.136 Y133.117 E-.1115
G1 X154.967 Y133.374 E-.11702
G1 X154.842 Y133.514 E-.07108
; WIPE_END
G1 E-.04 F1800
G1 X155.266 Y141.134 Z5.2 F36000
G1 X155.589 Y146.934 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.971 J3.757 E.0516
G2 X86.79 Y133.985 I-24.735 J-24.821 E.11931
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18944
G3 X90.41 Y126.674 I23.293 J7.811 E.08252
G3 X91.435 Y125.548 I2.423 J1.177 E.0512
G3 X93.349 Y124.413 I15.953 J24.708 E.07381
G2 X98.06 Y120.701 I-8.564 J-15.715 E.19989
G2 X100.325 Y117.806 I-37.426 J-31.621 E.12197
G3 X101.394 Y116.758 I3.534 J2.534 E.04991
G3 X103.044 Y116.197 I3.008 J6.141 E.05796
G2 X106.577 Y115.257 I-6.546 J-31.736 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18842
G3 X113.513 Y111.136 I14.723 J18.742 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05612
G3 X117.853 Y110.909 I-7.765 J188.192 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.095 J28.214 E.09117
G3 X128.183 Y108.872 I.643 J2.633 E.02773
G3 X129.663 Y109.258 I-.81 J6.127 E.05088
G2 X133.389 Y110.477 I12.3 J-31.292 E.13011
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.779 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.383 J23.417 E.07316
G2 X149.427 Y115.257 I11.081 J-14.315 E.18822
G2 X152.965 Y116.193 I9.837 J-30.032 E.12146
G3 X154.57 Y116.731 I-1.273 J6.46 E.05629
G3 X155.674 Y117.809 I-2.601 J3.77 E.05145
G2 X157.946 Y120.702 I41.978 J-30.624 E.12204
G2 X162.421 Y124.276 I12.716 J-11.335 E.19089
G3 X164.758 Y125.673 I-13.536 J25.279 E.09034
G3 X165.746 Y127.012 I-1.781 J2.348 E.05596
G3 X166.938 Y130.092 I-677.63 J264.263 E.10954
G2 X170.649 Y135.623 I16.058 J-6.762 E.22233
G3 X172.333 Y137.457 I-17.03 J17.324 E.08261
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.943 Y137.931 I5.343 J.212 E.04952
G3 X83.717 Y136.795 I3.829 J1.778 E.04243
G2 X85.862 Y134.489 I-444.928 J-416.081 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.429 J7.861 E.07788
G3 X91.212 Y125.225 I2.766 J1.354 E.05329
G3 X93.152 Y124.073 I16.121 J24.937 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.017 Y117.563 I-37.331 J-31.52 E.1123
G3 X101.193 Y116.421 I3.821 J2.757 E.05061
G3 X102.951 Y115.816 I3.187 J6.403 E.0573
G2 X106.448 Y114.887 I-6.459 J-31.367 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.851 J18.913 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.448 J182.386 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.202 J33.877 E.07783
G3 X128.217 Y108.481 I.983 J3.111 E.03746
G3 X129.793 Y108.888 I-.839 J6.501 E.05015
G2 X133.154 Y110.014 I13.014 J-33.273 E.10897
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.883 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05323
G3 X144.706 Y112.222 I-15.542 J23.688 E.06877
G2 X149.556 Y114.887 I10.853 J-14.006 E.17076
G2 X153.057 Y115.812 I9.716 J-29.685 E.11132
G3 X154.77 Y116.394 I-1.341 J6.762 E.05577
G3 X155.765 Y117.301 I-2.181 J3.392 E.04156
G2 X157.819 Y119.952 I1354.501 J-1047.217 E.10305
G2 X162.618 Y123.937 I12.924 J-10.683 E.19279
G3 X164.784 Y125.21 I-16.304 J30.208 E.07722
G3 X166.104 Y126.854 I-1.827 J2.819 E.06588
G3 X167.3 Y129.94 I-590.012 J230.383 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.222 J17.507 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.266 J11.569 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.653 J1.407 E.08774
G2 X162.172 Y124.532 I-25.037 J37.887 E.10008
G1 X157.19 Y129.513 E.2337
G3 X157.474 Y134.447 I-3.733 J2.69 E.17305
G1 X165.292 Y142.265 E.36675
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.908 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34273
G2 X140.386 Y111.134 I-1.124 J3.225 E.05407
G1 X149.963 Y115.79 F36000
G1 F15476.087
G3 X148.43 Y115.246 I5.469 J-17.828 E.05399
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.448 J33.816 E.05372
G1 X131.855 Y124.179 E.22592
G2 X131.922 Y124.078 I-.544 J-.433 E.00405
G1 X143.645 Y112.355 E.54993
G2 X144.962 Y113.313 I13.079 J-16.602 E.05402
G1 X132.194 Y121.235 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X131.966 Y120.233 I-3.926 J.364 E.03169
G1 X131.605 Y119.477 E.02574
G2 X130.955 Y118.655 I-3.356 J1.983 E.0323
G1 X130.284 Y118.118 E.0264
G2 X124 Y122.967 I-2.275 J3.549 E.3179
G2 X131.918 Y123.202 I4.002 J-1.317 E.31669
G2 X132.197 Y121.295 I-3.775 J-1.526 E.05978
G1 X131.817 Y121.256 F36000
G1 F12000
G2 X126.117 Y118.325 I-3.821 J.422 E.23288
G1 X125.641 Y118.637 E.01751
G2 X124.552 Y119.983 I2.865 J3.429 E.05353
G1 X124.329 Y120.569 E.01926
G2 X124.362 Y122.863 I3.743 J1.094 E.07155
G1 X124.553 Y123.338 E.01574
G1 X124.904 Y123.913 E.02068
G1 X125.27 Y124.351 E.01755
G2 X126.71 Y125.271 I3.107 J-3.278 E.05283
G1 X127.34 Y125.433 E.01997
G2 X129.615 Y125.138 I.658 J-3.851 E.07153
G1 X130.067 Y124.891 E.01584
G1 X130.596 Y124.479 E.02059
G1 X130.985 Y124.072 E.01731
G2 X131.736 Y122.539 I-3.596 J-2.713 E.05277
G1 X131.827 Y121.885 E.02027
G1 X131.82 Y121.316 E.01749
; WIPE_START
G1 X131.827 Y121.885 E-.21634
G1 X131.736 Y122.539 E-.2507
G1 X131.57 Y123.057 E-.207
G1 X131.472 Y123.261 E-.08597
; WIPE_END
G1 E-.04 F1800
G1 X125.912 Y119.965 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
G1 F12000
G1 X126.276 Y119.588 E.01609
G1 X126.637 Y119.334 E.01356
G3 X127.988 Y118.971 I1.38 J2.435 E.04345
G1 X128.602 Y119.031 E.01897
G1 X129.166 Y119.234 E.01841
G1 X129.706 Y119.57 E.01955
G1 X130.098 Y119.972 E.01724
G1 X130.448 Y120.528 E.02018
G3 X130.682 Y121.364 I-2.821 J1.24 E.02678
G1 X130.674 Y121.963 E.01839
G1 X130.536 Y122.576 E.01931
G1 X130.283 Y123.085 E.01746
G1 X129.882 Y123.592 E.01986
G3 X129.186 Y124.082 I-2.192 J-2.376 E.02625
G1 X128.592 Y124.283 E.01926
G1 X127.996 Y124.354 E.01844
G1 X127.403 Y124.281 E.01835
G1 X126.819 Y124.082 E.01897
G1 X126.332 Y123.767 E.01782
G1 X125.867 Y123.305 E.02013
G1 X125.585 Y122.841 E.01667
G1 X125.368 Y122.221 E.02019
G1 X125.31 Y121.684 E.01661
G1 X125.326 Y121.336 E.0107
G1 X125.463 Y120.773 E.01781
G1 X125.732 Y120.206 E.01927
G1 X125.876 Y120.013 E.0074
G1 X125.612 Y119.737 F36000
G1 F12000
G1 X126.014 Y119.317 E.01786
G1 X126.446 Y119.009 E.01628
G1 X126.983 Y118.766 E.01811
G1 X127.345 Y118.658 E.0116
G1 X127.991 Y118.594 E.01997
G1 X128.66 Y118.658 E.02064
G3 X129.99 Y119.317 I-.823 J3.335 E.04597
G1 X130.398 Y119.744 E.01814
G1 X130.604 Y120.026 E.01074
G1 X130.899 Y120.654 E.02131
G1 X131.049 Y121.264 E.01931
G3 X130.871 Y122.756 I-3.388 J.352 E.04655
G1 X130.599 Y123.29 E.0184
G3 X129.326 Y124.431 I-2.694 J-1.723 E.05319
G1 X128.678 Y124.65 E.02103
G1 X128.022 Y124.73 E.02031
G1 X127.491 Y124.688 E.01637
G3 X125.841 Y123.842 I.613 J-3.226 E.05775
G1 X125.533 Y123.487 E.01445
G3 X125.097 Y122.657 I2.9 J-2.054 E.0289
G1 X124.955 Y121.997 E.02075
G1 X124.946 Y121.35 E.01988
G3 X125.576 Y119.784 I2.966 J.284 E.05258
; WIPE_START
G1 X125.447 Y119.953 E-.08062
G1 X125.217 Y120.363 E-.17871
G1 X125.041 Y120.837 E-.19228
G1 X124.946 Y121.35 E-.19813
G1 X124.95 Y121.64 E-.11027
; WIPE_END
G1 E-.04 F1800
G1 X131.436 Y121.277 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; LINE_WIDTH: 0.427109
G1 F12000
G1 X131.328 Y120.734 E.01732
G1 X131.123 Y120.181 E.01848
G2 X130.047 Y124.44 I-3.117 J1.478 E.52945
G2 X131.395 Y122.3 I-2.181 J-2.868 E.08091
G1 X131.454 Y121.719 E.01828
G1 X131.439 Y121.337 E.01196
; WIPE_START
G1 X131.454 Y121.719 E-.14523
G1 X131.395 Y122.3 E-.2219
G1 X131.267 Y122.783 E-.19019
G1 X131.068 Y123.244 E-.19055
G1 X131.052 Y123.271 E-.01214
; WIPE_END
G1 E-.04 F1800
G1 X124.368 Y124.488 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X124.393 Y124.522 E.00141
G2 X125.572 Y125.572 I3.953 J-3.253 E.05257
G1 X127.713 Y127.714 E.10046
G3 X128.286 Y127.714 I.288 J8.198 E.019
M73 P69 R6
G1 X130.456 Y125.558 E.10145
G2 X131.632 Y124.494 I-2.752 J-4.224 E.05281
G1 X113.77 Y131.309 F36000
G1 F15476.087
G3 X115.224 Y130.576 I15.749 J29.418 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.779 I1.393 J2.463 E.03859
G3 X98.118 Y121.147 I-32.794 J-23.326 E.14279
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.734 J27.775 E.18055
G1 X105.233 Y135.938 E.05046
G3 X104.115 Y136.533 I-2.813 J-3.936 E.04217
G1 X96.032 Y144.616 E.37919
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.853 J-11.784 E.054
G1 X104.787 Y128.185 F36000
G1 F15476.087
G1 X122.015 Y110.957 E.8082
G3 X118.944 Y111.268 I-4.387 J-27.98 E.10243
G1 X125.482 Y117.806 E.30671
G1 X125.53 Y117.772 E.00196
G3 X130.519 Y117.804 I2.47 J3.924 E.17476
G1 X137.055 Y111.268 E.30662
G3 X133.984 Y110.956 I1.331 J-28.35 E.10248
G1 X151.215 Y128.187 E.80834
G1 X157.649 Y131.779 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X157.421 Y130.774 I-3.922 J.363 E.03178
G1 X157.06 Y130.021 E.02564
G2 X156.41 Y129.198 I-3.36 J1.986 E.03232
G1 X155.74 Y128.662 E.02638
G2 X149.649 Y134.001 I-2.275 J3.549 E.33407
G2 X157.381 Y133.729 I3.807 J-1.805 E.30119
G2 X157.653 Y131.839 I-3.788 J-1.509 E.05921
G1 X157.273 Y131.8 F36000
G1 F12000
G2 X152.196 Y128.58 I-3.832 J.429 E.21185
G1 X151.574 Y128.867 E.02105
G1 X151.096 Y129.181 E.01756
G2 X150.013 Y130.515 I2.888 J3.451 E.05312
G1 X149.785 Y131.113 E.01967
G2 X149.818 Y133.407 I3.742 J1.094 E.07155
G1 X150.005 Y133.875 E.01548
G1 X150.36 Y134.457 E.02094
G1 X150.726 Y134.896 E.01755
G2 X152.166 Y135.815 I3.107 J-3.279 E.05283
G1 X152.796 Y135.977 E.01997
G2 X155.513 Y135.442 I.664 J-3.8 E.08703
G1 X156.052 Y135.024 E.02097
G1 X156.433 Y134.624 E.01696
G1 X156.782 Y134.11 E.0191
G2 X157.277 Y131.87 I-3.367 J-1.919 E.07154
G1 X157.276 Y131.86 E.00032
; WIPE_START
G1 X157.277 Y131.87 E-.00394
G1 X157.281 Y132.449 E-.21985
G1 X157.192 Y133.083 E-.24339
G1 X157.033 Y133.584 E-.19984
G1 X156.927 Y133.805 E-.09298
; WIPE_END
G1 E-.04 F1800
G1 X151.323 Y133.849 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
G1 F12000
G3 X150.916 Y133.101 I2.568 J-1.881 E.02624
G1 X150.785 Y132.498 E.01897
G1 X150.778 Y131.908 E.0181
G1 X150.915 Y131.328 E.01831
G1 X151.187 Y130.75 E.01965
G1 X151.549 Y130.308 E.01754
G1 X152.062 Y129.898 E.02017
G3 X152.858 Y129.575 I1.577 J2.746 E.02649
G1 X153.463 Y129.514 E.01867
G1 X154.058 Y129.575 E.01839
G1 X154.622 Y129.779 E.01841
G1 X155.162 Y130.114 E.01955
G1 X155.554 Y130.517 E.01725
G1 X155.898 Y131.061 E.0198
G1 X156.077 Y131.585 E.01701
G1 X156.139 Y131.913 E.01027
G1 X156.13 Y132.507 E.01823
G1 X156 Y133.101 E.01869
G1 X155.742 Y133.623 E.0179
G1 X155.338 Y134.136 E.02005
G3 X154.637 Y134.628 I-2.228 J-2.428 E.0264
G1 X154.048 Y134.827 E.0191
G1 X153.473 Y134.899 E.01781
G1 X152.859 Y134.825 E.01898
G1 X152.275 Y134.626 E.01898
G1 X151.787 Y134.311 E.01783
G1 X151.365 Y133.891 E.01828
G1 X151.041 Y134.1 F36000
G1 F12000
G3 X150.554 Y133.207 I2.346 J-1.859 E.03141
G1 X150.411 Y132.541 E.02094
G1 X150.402 Y131.894 E.01988
G3 X150.903 Y130.497 I3.404 J.434 E.04597
G1 X151.288 Y130.037 E.01843
G3 X152.801 Y129.202 I2.239 J2.271 E.05376
G1 X153.463 Y129.137 E.02045
G1 X154.116 Y129.202 E.02016
G3 X155.446 Y129.861 I-.823 J3.334 E.04597
G1 X155.854 Y130.288 E.01814
G1 X156.06 Y130.57 E.01074
G1 X156.355 Y131.197 E.02129
G1 X156.505 Y131.811 E.01943
G1 X156.527 Y132.351 E.01659
G3 X156.056 Y133.831 I-3.239 J-.215 E.04818
G1 X155.62 Y134.387 E.02172
G3 X154.784 Y134.975 I-2.121 J-2.123 E.03157
G1 X154.134 Y135.194 E.02107
G1 X153.502 Y135.275 E.01958
G3 X152.056 Y134.937 I.04 J-3.43 E.04597
G1 X151.547 Y134.602 E.01872
G3 X151.081 Y134.145 I1.472 J-1.967 E.02012
; WIPE_START
G1 X151.297 Y134.387 E-.12313
G1 X151.547 Y134.602 E-.12552
G1 X152.056 Y134.937 E-.23152
G1 X152.49 Y135.119 E-.17881
G1 X152.748 Y135.182 E-.10102
; WIPE_END
G1 E-.04 F1800
G1 X156.892 Y131.821 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; LINE_WIDTH: 0.427059
G1 F12000
G1 X156.784 Y131.278 E.01731
G1 X156.579 Y130.725 E.01848
G2 X155.503 Y134.984 I-3.118 J1.478 E.52962
G2 X156.894 Y131.881 I-2.105 J-2.807 E.11114
G1 X167.597 Y132.209 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X168.477 Y133.578 I19.128 J-11.341 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X151.881 Y136.53 E.37942
G3 X150.768 Y135.935 I1.694 J-4.513 E.04197
G1 X149.693 Y137.011 E.05043
G2 X145.602 Y133.425 I-22.204 J21.21 E.18067
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.323 I24.846 J-22.132 E.11975
G2 X154.34 Y117.012 I-5.152 J3.789 E.06132
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.346 J30.264 E.05401
; WIPE_START
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
; WIPE_END
G1 E-.04 F1800
G1 X134.947 Y125.715 Z5.2 F36000
G1 X115.627 Y111.14 Z5.2
G1 Z4.8
G1 E.8 F1800
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.844 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.366 J.127 E.04916
G1 X86.809 Y140.541 E.13381
G1 X90.708 Y142.264 E.14141
G1 X98.528 Y134.444 E.36686
G3 X98.812 Y129.516 I4.018 J-2.24 E.1728
G1 X93.83 Y124.534 E.23373
G2 X90.989 Y126.4 I5.519 J11.495 E.11308
G2 X90.068 Y128.448 I10.532 J5.966 E.0746
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.046 J23.848 E.05401
G1 X107.153 Y132.175 F36000
G1 F15476.087
G1 X107.154 Y132.192 E.00055
G3 X106.876 Y133.771 I-5.052 J-.072 E.05343
G1 X130.659 Y109.989 E1.1157
G2 X128.004 Y109.211 I-4.628 J10.88 E.09198
G2 X125.341 Y109.989 I1.76 J10.979 E.09229
G1 X149.132 Y133.78 E1.11609
G1 X149.114 Y133.739 E.00148
G3 X148.851 Y132.184 I4.872 J-1.624 E.0525
; WIPE_START
G1 X148.881 Y132.731 E-.20783
G1 X149.114 Y133.739 E-.39324
G1 X149.132 Y133.78 E-.017
G1 X148.868 Y133.516 E-.14193
; WIPE_END
G1 E-.04 F1800
G1 X141.242 Y133.202 Z5.2 F36000
G1 X106.738 Y131.779 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X106.51 Y130.777 I-3.928 J.364 E.03168
G1 X106.149 Y130.021 E.02574
G2 X105.499 Y129.198 I-3.363 J1.988 E.03232
G1 X104.828 Y128.662 E.02638
G2 X98.73 Y133.987 I-2.272 J3.552 E.3335
G2 X106.462 Y133.747 I3.814 J-1.793 E.30105
G2 X106.741 Y131.839 I-3.774 J-1.526 E.0598
G1 X106.361 Y131.8 F36000
G1 F12000
G2 X100.662 Y128.867 I-3.821 J.422 E.23284
G1 X100.185 Y129.181 E.01755
G2 X99.097 Y130.528 I2.865 J3.428 E.05353
G1 X98.874 Y131.113 E.01926
G2 X98.906 Y133.407 I3.742 J1.094 E.07155
G1 X99.098 Y133.882 E.01574
G1 X99.448 Y134.457 E.02068
G1 X99.814 Y134.895 E.01754
G2 X101.255 Y135.815 I3.106 J-3.278 E.05284
G1 X101.884 Y135.977 E.01997
G2 X104.601 Y135.442 I.664 J-3.799 E.08703
G1 X105.14 Y135.024 E.02097
G1 X105.529 Y134.616 E.01732
G2 X106.28 Y133.083 I-3.585 J-2.708 E.05277
G1 X106.371 Y132.429 E.02027
G1 X106.364 Y131.86 E.0175
; WIPE_START
G1 X106.371 Y132.429 E-.21641
G1 X106.28 Y133.083 E-.2507
G1 X106.114 Y133.602 E-.2071
G1 X106.016 Y133.805 E-.08579
; WIPE_END
G1 E-.04 F1800
G1 X100.291 Y130.726 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
G1 F12000
G1 X100.637 Y130.309 E.01665
G1 X101.15 Y129.898 E.02018
G3 X101.946 Y129.575 I1.577 J2.746 E.02649
G1 X102.539 Y129.514 E.0183
G1 X103.147 Y129.575 E.01877
G1 X103.71 Y129.779 E.01841
G1 X104.251 Y130.114 E.01955
G1 X104.642 Y130.516 E.01724
G1 X104.992 Y131.072 E.02018
G3 X105.226 Y131.908 I-2.819 J1.239 E.02678
G1 X105.218 Y132.507 E.01839
G1 X105.08 Y133.12 E.01931
G1 X104.827 Y133.629 E.01748
G1 X104.426 Y134.136 E.01984
G3 X103.725 Y134.628 I-2.227 J-2.426 E.0264
G1 X103.136 Y134.827 E.01911
G1 X102.561 Y134.899 E.01781
G1 X101.948 Y134.825 E.01898
G1 X101.345 Y134.615 E.0196
G1 X100.876 Y134.311 E.0172
G1 X100.411 Y133.849 E.02012
G1 X100.129 Y133.385 E.01668
G1 X99.912 Y132.765 E.02019
G1 X99.854 Y132.228 E.01661
G1 X99.87 Y131.88 E.0107
G1 X100.008 Y131.317 E.01781
G1 X100.262 Y130.778 E.01831
G1 X99.992 Y130.497 F36000
G1 F12000
G1 X100.376 Y130.037 E.01842
G3 X101.889 Y129.202 I2.239 J2.271 E.05377
G1 X102.539 Y129.137 E.02007
G1 X103.204 Y129.202 E.02054
G3 X104.534 Y129.861 I-.823 J3.335 E.04597
G1 X104.942 Y130.288 E.01813
G3 X105.603 Y131.894 I-2.492 J1.965 E.05406
G1 X105.593 Y132.55 E.02016
G3 X104.958 Y134.106 I-3.224 J-.408 E.05222
G1 X104.645 Y134.447 E.01422
G3 X103.863 Y134.979 I-2.386 J-2.665 E.02916
G1 X103.222 Y135.194 E.02078
G1 X102.59 Y135.275 E.01958
G3 X101.128 Y134.927 I.039 J-3.409 E.04655
G3 X100.385 Y134.387 I1.766 J-3.208 E.02831
G1 X100.077 Y134.031 E.01445
G3 X99.641 Y133.201 I2.9 J-2.055 E.0289
G1 X99.499 Y132.541 E.02074
G1 X99.49 Y131.894 E.01988
G3 X99.962 Y130.549 I3.344 J.419 E.04413
; WIPE_START
G1 X99.761 Y130.907 E-.156
G1 X99.585 Y131.381 E-.19216
G1 X99.49 Y131.894 E-.19819
G1 X99.498 Y132.456 E-.21365
; WIPE_END
G1 E-.04 F1800
G1 X105.98 Y131.821 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; LINE_WIDTH: 0.427419
G1 F12000
G2 X104.473 Y135.068 I-3.427 J.382 E.56095
G2 X105.984 Y131.881 I-1.993 J-2.897 E.11576
G1 X111.04 Y113.314 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X112.36 Y112.361 I-13.411 J-19.968 E.05402
G1 X124.148 Y124.176 E.55363
G1 X119.326 Y128.997 E.22617
G3 X120.891 Y128.567 I10.051 J33.499 E.05383
G1 X107.571 Y115.247 E.62487
G3 X106.038 Y115.792 I-7.023 J-17.352 E.05399
; CHANGE_LAYER
; Z_HEIGHT: 5
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X107.571 Y115.247 E-.61834
G1 X107.835 Y115.511 E-.14166
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
G1 X123.87 Y121.069
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X123.924 Y120.728 E.01146
G3 X127.534 Y117.506 I4.072 J.928 E.17123
G1 X127.989 Y117.48 E.0151
G3 X123.845 Y121.191 I.006 J4.176 E.66848
G1 X123.858 Y121.128 E.00212
; WIPE_START
G1 X123.924 Y120.728 E-.15401
G1 X124.057 Y120.279 E-.17818
G1 X124.232 Y119.858 E-.173
G1 X124.462 Y119.437 E-.18246
G1 X124.572 Y119.282 E-.07235
; WIPE_END
G1 E-.04 F1800
G1 X126.105 Y121.44 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.856 Y119.754 I1.897 J.218 E.08096
G1 X128.149 Y119.754 E.00899
G3 X126.099 Y121.5 I-.146 J1.904 E.27692
; WIPE_START
M204 S10000
G1 X126.16 Y121.153 E-.13388
G1 X126.259 Y120.877 E-.11115
G1 X126.399 Y120.621 E-.11113
G1 X126.576 Y120.388 E-.11115
G1 X126.787 Y120.185 E-.11112
G1 X127.026 Y120.017 E-.11122
G1 X127.192 Y119.935 E-.07034
; WIPE_END
G1 E-.04 F1800
G1 X134.355 Y122.569 Z5.4 F36000
G1 X157.475 Y131.073 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.53 Y131.274 E.00692
G3 X152.99 Y128.05 I-4.072 J.926 E.66824
G1 X153.458 Y128.024 E.01555
G3 X157.4 Y130.822 I0 J4.176 E.17101
G1 X157.458 Y131.015 E.00669
; WIPE_START
G1 X157.53 Y131.274 E-.10212
G1 X157.611 Y131.735 E-.17803
G1 X157.638 Y132.203 E-.1781
G1 X157.611 Y132.671 E-.17811
G1 X157.557 Y132.992 E-.12364
; WIPE_END
G1 E-.04 F1800
G1 X155.304 Y131.716 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X155.356 Y131.984 E.0084
G3 X153.312 Y130.298 I-1.898 J.219 E.27884
G1 X153.605 Y130.298 E.00899
G3 X155.289 Y131.658 I-.146 J1.905 E.07072
; WIPE_START
M204 S10000
G1 X155.356 Y131.984 E-.12655
G1 X155.367 Y132.276 E-.11111
G1 X155.334 Y132.567 E-.11117
G1 X155.256 Y132.849 E-.11131
G1 X155.134 Y133.121 E-.11307
G1 X154.978 Y133.361 E-.10906
G1 X154.842 Y133.514 E-.07774
; WIPE_END
G1 E-.04 F1800
G1 X147.248 Y132.744 Z5.4 F36000
G1 X104.219 Y128.379 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X104.358 Y128.441 E.00506
G3 X102.078 Y128.05 I-1.819 J3.759 E.79264
G1 X102.533 Y128.025 E.0151
G3 X103.926 Y128.261 I.007 J4.176 E.04709
G1 X104.163 Y128.357 E.00849
; WIPE_START
G1 X104.358 Y128.441 E-.0807
G1 X104.77 Y128.664 E-.17802
G1 X105.152 Y128.936 E-.17814
G1 X105.502 Y129.248 E-.17809
G1 X105.756 Y129.533 E-.14506
; WIPE_END
G1 E-.04 F1800
G1 X102.4 Y130.298 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.693 Y130.298 E.00899
G3 X102.341 Y130.304 I-.146 J1.905 E.35797
; WIPE_START
M204 S10000
G1 X102.693 Y130.298 E-.13388
G1 X102.982 Y130.343 E-.11115
G1 X103.261 Y130.431 E-.11117
G1 X103.523 Y130.561 E-.11106
G1 X103.762 Y130.729 E-.11119
G1 X103.973 Y130.932 E-.11114
G1 X104.085 Y131.079 E-.07042
; WIPE_END
G1 E-.04 F1800
G1 X111.38 Y133.325 Z5.4 F36000
G1 X155.589 Y146.934 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.718 E2.35658
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.58 J.167 E.04815
G3 X84.377 Y136.65 I5.974 J3.758 E.05161
G2 X86.79 Y133.986 I-24.738 J-24.824 E.11929
G2 X89.501 Y128.988 I-13.843 J-10.746 E.18946
G3 X90.41 Y126.674 I23.299 J7.813 E.08251
G3 X91.436 Y125.548 I2.423 J1.177 E.05122
G3 X93.349 Y124.413 I15.949 J24.702 E.07381
G2 X98.059 Y120.701 I-8.564 J-15.716 E.19988
G2 X100.325 Y117.807 I-37.419 J-31.615 E.12196
G3 X101.394 Y116.758 I3.536 J2.535 E.04994
G3 X103.044 Y116.197 I3.009 J6.143 E.05796
G2 X106.577 Y115.257 I-6.546 J-31.733 E.12132
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18842
G3 X113.513 Y111.136 I14.723 J18.742 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.766 J188.211 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.098 J28.221 E.09117
G3 X128.183 Y108.872 I.643 J2.633 E.02774
G3 X129.664 Y109.258 I-.811 J6.13 E.05089
G2 X133.389 Y110.477 I12.297 J-31.284 E.1301
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.765 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.374 J23.406 E.07317
G2 X149.428 Y115.257 I11.081 J-14.314 E.18823
G2 X152.965 Y116.193 I9.84 J-30.042 E.12145
G3 X154.57 Y116.731 I-1.273 J6.459 E.05629
G3 X155.674 Y117.809 I-2.603 J3.772 E.05146
G2 X157.946 Y120.702 I41.972 J-30.619 E.12201
G2 X162.421 Y124.276 I12.716 J-11.334 E.19091
G3 X164.757 Y125.673 I-13.529 J25.269 E.09034
G3 X165.746 Y127.013 I-1.782 J2.349 E.05599
G3 X166.938 Y130.092 I-685.933 J267.472 E.10951
G2 X170.649 Y135.623 I16.058 J-6.762 E.22233
G3 X172.333 Y137.457 I-17.034 J17.327 E.08261
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.195 E2.17924
G1 X82.639 Y139.508 E.60452
G3 X82.942 Y137.933 I5.353 J.213 E.04945
G3 X83.717 Y136.795 I3.828 J1.775 E.0425
G2 X85.862 Y134.489 I-444.242 J-415.445 E.09676
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.432 J7.862 E.07788
G3 X91.213 Y125.225 I2.766 J1.354 E.0533
G3 X93.152 Y124.073 I16.125 J24.944 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.34 J-31.527 E.1123
G3 X101.193 Y116.421 I3.821 J2.757 E.05061
G3 X102.951 Y115.816 I3.187 J6.404 E.0573
G2 X106.448 Y114.887 I-6.459 J-31.367 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.854 J18.917 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.449 J182.403 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21158
G3 X127.013 Y108.625 I13.211 J33.902 E.07784
G3 X128.217 Y108.481 I.982 J3.11 E.03746
G3 X129.793 Y108.888 I-.84 J6.502 E.05016
G2 X133.154 Y110.014 I13.011 J-33.265 E.10895
G2 X138.707 Y110.489 I4.211 J-16.533 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05323
G3 X144.706 Y112.222 I-15.539 J23.684 E.06878
G2 X149.556 Y114.887 I10.852 J-14.005 E.17076
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.77 Y116.394 I-1.341 J6.762 E.05577
G3 X155.764 Y117.3 I-2.181 J3.391 E.04153
G2 X157.819 Y119.952 I1407.999 J-1088.673 E.10307
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.313 J30.224 E.0772
G3 X166.104 Y126.854 I-1.828 J2.82 E.06592
G3 X167.3 Y129.94 I-596.892 J233.041 E.10168
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.222 J17.508 E.07791
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.393 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X151.583 Y138.602 Z5.4 F36000
G1 X150.153 Y135.29 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X149.279 Y133.928 I4.863 J-4.08 E.05382
G1 X125.341 Y109.989 E1.12302
G3 X128.002 Y109.211 I4.435 J10.235 E.09222
G3 X130.659 Y109.989 I-1.958 J11.618 E.09204
G1 X106.73 Y133.918 E1.12257
G3 X105.859 Y135.282 I-5.806 J-2.749 E.05382
; WIPE_START
G1 X106.381 Y134.612 E-.3225
G1 X106.73 Y133.918 E-.29535
G1 X106.994 Y133.653 E-.14215
; WIPE_END
G1 E-.04 F1800
M73 P69 R5
G1 X106.284 Y131.081 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X103.669 Y128.466 E.11364
G1 X102.991 Y128.321
M73 P70 R5
G1 X106.429 Y131.759 E.14943
G1 X106.449 Y132.312
G1 X102.438 Y128.301 E.1743
G1 X101.95 Y128.346
G1 X106.403 Y132.8 E.19352
G1 X106.309 Y133.239
G1 X104.521 Y131.45 E.07772
G1 X104.657 Y132.12
G1 X106.176 Y133.639 E.06598
G1 X106.009 Y134.005
G1 X104.623 Y132.619 E.06024
G1 X104.494 Y133.023
G1 X105.813 Y134.343 E.05734
G1 X105.59 Y134.653
G1 X104.307 Y133.37 E.05575
G1 X104.071 Y133.667
G1 X105.339 Y134.935 E.05508
G1 X105.061 Y135.19
G1 X103.788 Y133.917 E.0553
G1 X103.453 Y134.115
G1 X104.757 Y135.42 E.05667
G1 X104.427 Y135.623
G1 X103.057 Y134.253 E.05951
G1 X102.589 Y134.319
G1 X104.068 Y135.797 E.06424
G1 X103.676 Y135.939
G1 X101.976 Y134.239 E.07388
; WIPE_START
M204 S10000
G1 X103.39 Y135.653 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X103.295 Y130.224 Z5.4 F36000
G1 Z5
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X101.511 Y128.441 E.07751
G1 X101.111 Y128.574
G1 X102.628 Y130.091 E.06591
G1 X102.133 Y130.13
G1 X100.744 Y128.741 E.06036
G1 X100.407 Y128.937
G1 X101.724 Y130.253 E.05722
G1 X101.379 Y130.442
G1 X100.096 Y129.159 E.05573
G1 X99.815 Y129.411
G1 X101.083 Y130.68 E.05513
G1 X100.835 Y130.964
G1 X99.56 Y129.689 E.05541
G1 X99.33 Y129.993
G1 X100.635 Y131.297 E.05669
G1 X100.494 Y131.69
G1 X99.127 Y130.323 E.05941
G1 X98.953 Y130.682
G1 X100.434 Y132.163 E.06437
G1 X100.513 Y132.775
G1 X98.811 Y131.073 E.07396
G1 X98.707 Y131.503
G1 X103.247 Y136.042 E.19727
G1 X102.77 Y136.099
G1 X98.651 Y131.979 E.17902
G1 X98.656 Y132.518
G1 X102.232 Y136.094 E.1554
G1 X101.595 Y135.99
G1 X98.76 Y133.155 E.12319
G1 X99.093 Y134.021
G1 X100.728 Y135.657 E.07108
M204 S10000
G1 X101.159 Y135.873 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.217008
G1 F15000
G1 X100.79 Y135.596 E.00655
; WIPE_START
G1 X101.159 Y135.873 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X101.987 Y134.228 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.144288
G1 F15000
G1 X101.755 Y134.284 E.00197
G1 X102.605 Y134.303 F36000
; LINE_WIDTH: 0.0915435
G1 F15000
G1 X102.394 Y134.39 E.0009
; WIPE_START
G1 X102.605 Y134.303 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.582 Y131.389 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.204985
G1 F15000
G1 X104.532 Y131.307 E.00127
; LINE_WIDTH: 0.177462
G1 X104.435 Y131.177 E.00178
; LINE_WIDTH: 0.130227
G1 X104.334 Y131.043 E.00119
; LINE_WIDTH: 0.0973988
G1 X104.229 Y130.922 E.00071
G1 X103.826 Y130.518 F36000
; LINE_WIDTH: 0.107264
G1 F15000
G1 X103.638 Y130.361 E.00128
; LINE_WIDTH: 0.147911
G1 X103.498 Y130.26 E.00147
; LINE_WIDTH: 0.189846
G1 X103.359 Y130.16 E.00206
G1 X102.828 Y130.025 F36000
; LINE_WIDTH: 0.127328
G1 F15000
G1 X102.616 Y130.103 E.00155
; WIPE_START
G1 X102.828 Y130.025 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X100.664 Y133.166 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.110857
G1 F15000
G1 X100.586 Y133.054 E.00076
; LINE_WIDTH: 0.156276
G1 X100.508 Y132.941 E.00126
; LINE_WIDTH: 0.189743
G1 X100.449 Y132.839 E.00141
; WIPE_START
G1 X100.508 Y132.941 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X106.115 Y130.619 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.108647
G1 F15000
G1 X106.042 Y130.511 E.0007
; LINE_WIDTH: 0.149367
G1 X105.955 Y130.395 E.00126
; LINE_WIDTH: 0.189584
G1 X105.868 Y130.28 E.00173
; LINE_WIDTH: 0.229801
G1 X105.781 Y130.164 E.0022
; LINE_WIDTH: 0.267756
G1 X105.642 Y130.001 E.00392
; LINE_WIDTH: 0.30343
G1 X105.504 Y129.837 E.00455
; LINE_WIDTH: 0.332841
G2 X104.912 Y129.245 I-5.634 J5.042 E.01978
; LINE_WIDTH: 0.303399
G1 X104.749 Y129.107 E.00454
; LINE_WIDTH: 0.26775
G1 X104.585 Y128.969 E.00392
; LINE_WIDTH: 0.229011
G1 X104.435 Y128.856 E.00285
; LINE_WIDTH: 0.187223
G1 X104.285 Y128.743 E.00221
; LINE_WIDTH: 0.145436
G1 X104.134 Y128.63 E.00157
; WIPE_START
G1 X104.285 Y128.743 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.308 Y121.179 Z5.4 F36000
G1 X106.038 Y115.792 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X107.571 Y115.247 I-5.488 J-17.893 E.05399
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.486 J33.929 E.05383
G1 X124.204 Y124.119 E.22884
G1 X124.412 Y124.413 E.01192
G1 X112.36 Y112.361 E.56538
G3 X111.04 Y113.314 I-14.719 J-18.998 E.05402
; WIPE_START
G1 X112.36 Y112.361 E-.61871
G1 X112.623 Y112.624 E-.14129
; WIPE_END
G1 E-.04 F1800
G1 X119.721 Y115.431 Z5.4 F36000
G1 X131.591 Y120.126 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X129.535 Y118.07 E.08936
G1 X128.761 Y117.83
G1 X131.832 Y120.9 E.13341
G1 X131.902 Y121.504
G1 X128.159 Y117.76 E.16267
G1 X127.636 Y117.771
G1 X131.89 Y122.025 E.18485
G1 X131.82 Y122.488
G1 X129.592 Y120.261 E.09678
G1 X130.081 Y121.283
G1 X131.704 Y122.906 E.07053
G1 X131.552 Y123.287
G1 X130.107 Y121.842 E.06277
G1 X130.02 Y122.288
G1 X131.368 Y123.636 E.05858
G1 X131.156 Y123.958
G1 X129.865 Y122.667 E.05609
G1 X129.65 Y122.985
G1 X130.918 Y124.253 E.05509
G1 X130.655 Y124.522
G1 X129.387 Y123.255 E.05507
G1 X129.076 Y123.478
G1 X130.366 Y124.767 E.05603
G1 X130.051 Y124.985
G1 X128.715 Y123.649 E.05806
G1 X128.288 Y123.756
G1 X129.708 Y125.175 E.06169
G1 X129.331 Y125.332
G1 X127.758 Y123.759 E.06837
G1 X126.967 Y123.501
G1 X128.921 Y125.455 E.08492
; WIPE_START
M204 S10000
G1 X127.507 Y124.041 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.512 Y120.18 Z5.4 F36000
G1 Z5
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X127.173 Y117.842 E.10163
G1 X126.756 Y117.957
G1 X128.378 Y119.58 E.0705
G1 X127.816 Y119.55
G1 X126.375 Y118.11 E.06262
G1 X126.025 Y118.293
G1 X127.374 Y119.642 E.05862
G1 X126.998 Y119.799
G1 X125.704 Y118.505 E.05623
G1 X125.409 Y118.743
G1 X126.675 Y120.01 E.05504
G1 X126.404 Y120.272
G1 X125.139 Y119.007 E.05496
G1 X124.895 Y119.296
G1 X126.183 Y120.584 E.05597
G1 X126.013 Y120.948
G1 X124.676 Y119.61 E.05811
G1 X124.486 Y119.954
G1 X125.906 Y121.374 E.06169
G1 X125.904 Y121.905
G1 X124.329 Y120.33 E.06845
G1 X124.206 Y120.74
G1 X126.148 Y122.683 E.0844
; WIPE_START
M204 S10000
G1 X124.734 Y121.268 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X124.124 Y121.191 Z5.4 F36000
G1 Z5
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X128.47 Y125.538 E.18889
G1 X127.965 Y125.565
G1 X124.096 Y121.697 E.16812
G1 X124.15 Y122.284
G1 X127.377 Y125.511 E.14022
G1 X126.66 Y125.327
G1 X124.335 Y123.002 E.10103
M204 S10000
G1 X126.109 Y125.071 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.101604
G1 F15000
G1 X126.022 Y125.005 E.00052
; LINE_WIDTH: 0.12862
G1 X125.935 Y124.939 E.00076
; LINE_WIDTH: 0.160272
G1 X125.769 Y124.799 E.00208
; LINE_WIDTH: 0.196589
G1 X125.603 Y124.658 E.00273
; LINE_WIDTH: 0.226155
G3 X124.995 Y124.05 I5.115 J-5.715 E.01285
; LINE_WIDTH: 0.195651
G1 X124.859 Y123.888 E.00263
; LINE_WIDTH: 0.160148
G1 X124.723 Y123.727 E.00202
; LINE_WIDTH: 0.12883
G1 X124.657 Y123.639 E.00077
; LINE_WIDTH: 0.10168
G1 X124.591 Y123.552 E.00052
; WIPE_START
G1 X124.657 Y123.639 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.535 Y123.33 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.0998612
G1 F15000
G3 X131.447 Y123.449 I-2.202 J-1.544 E.00069
G1 X131.233 Y119.472 F36000
; LINE_WIDTH: 0.112017
G1 F15000
G1 X131.033 Y119.235 E.00175
; LINE_WIDTH: 0.147447
G2 X130.417 Y118.621 I-5.774 J5.168 E.00741
; LINE_WIDTH: 0.111389
G1 X130.189 Y118.428 E.00167
G1 X125.962 Y118.329 F36000
; LINE_WIDTH: 0.0956353
G1 F15000
G2 X125.869 Y118.404 I.707 J.968 E.00051
; WIPE_START
G1 X125.962 Y118.329 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X126.906 Y123.562 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.211473
G1 F15000
G1 X126.745 Y123.436 E.00281
; LINE_WIDTH: 0.179029
G3 X126.272 Y122.971 I4.197 J-4.74 E.00736
; LINE_WIDTH: 0.207655
G1 X126.088 Y122.743 E.00393
; WIPE_START
G1 X126.272 Y122.971 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.005 Y123.521 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.0969721
G1 F15000
G1 X128.943 Y123.569 E.00035
G1 X128.893 Y123.56 E.00023
; WIPE_START
G1 X128.943 Y123.569 E-.3
G1 X129.005 Y123.521 E-.46
; WIPE_END
G1 E-.04 F1800
G1 X131.478 Y124.554 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X128.286 Y127.714 I-268.581 J-268.196 E.14898
G2 X127.713 Y127.714 I-.285 J8.199 E.019
G1 X125.249 Y125.249 E.11562
G3 X124.54 Y124.57 I3.164 J-4.011 E.0326
; WIPE_START
G1 X125.249 Y125.249 E-.37285
G1 X125.969 Y125.97 E-.38715
; WIPE_END
G1 E-.03999 F1800
G1 X133.221 Y128.35 Z5.4 F36000
G1 X142.231 Y131.307 Z5.4
G1 Z5
G1 E.8 F1800
G1 F15476.087
G2 X140.777 Y130.574 I-15.8 J29.531 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.633 Y118.323 I-3.855 J5.096 E.06131
G2 X157.884 Y121.144 I27.089 J-19.306 E.11976
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-18.115 J24.798 E.18067
G1 X150.825 Y135.879 E.0531
G2 X151.735 Y136.383 I2.635 J-3.68 E.03458
G1 X159.969 Y144.617 E.38629
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.247 J-12.71 E.054
; WIPE_START
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
; WIPE_END
G1 E-.04 F1800
G1 X161.116 Y131.036 Z5.4 F36000
G1 X155.024 Y128.628 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X157.033 Y130.637 E.08731
G1 X157.283 Y131.421
G1 X154.241 Y128.378 E.13222
G1 X153.634 Y128.305
G1 X157.357 Y132.027 E.16176
G1 X157.347 Y132.551
G1 X153.111 Y128.314 E.1841
G1 X152.646 Y128.383
G1 X157.278 Y133.015 E.2013
G1 X157.164 Y133.435
G1 X155.532 Y131.803 E.07092
G1 X155.565 Y132.369
G1 X157.013 Y133.817 E.06292
G1 X156.831 Y134.168
G1 X155.48 Y132.817 E.0587
G1 X155.327 Y133.197
G1 X156.62 Y134.49 E.0562
G1 X156.383 Y134.786
G1 X155.115 Y133.519 E.05509
G1 X154.854 Y133.79
G1 X156.121 Y135.057 E.05505
G1 X155.833 Y135.303
G1 X154.545 Y134.015 E.05598
G1 X154.185 Y134.188
G1 X155.519 Y135.523 E.058
G1 X155.176 Y135.712
G1 X153.762 Y134.299 E.06144
G1 X153.235 Y134.305
G1 X154.801 Y135.871 E.06805
G1 X154.392 Y135.995
G1 X152.471 Y134.074 E.08349
; WIPE_START
M204 S10000
G1 X153.885 Y135.488 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.857 Y130.127 Z5.4 F36000
G1 Z5
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X152.227 Y128.497 E.07085
G1 X151.844 Y128.648
G1 X153.288 Y130.092 E.06275
G1 X152.845 Y130.182
G1 X151.494 Y128.831 E.05871
G1 X151.171 Y129.041
G1 X152.467 Y130.337 E.0563
G1 X152.143 Y130.546
G1 X150.875 Y129.278 E.05509
G1 X150.604 Y129.541
G1 X151.868 Y130.805 E.05493
G1 X151.645 Y131.115
G1 X150.358 Y129.828 E.05592
G1 X150.139 Y130.142
G1 X151.474 Y131.477 E.05803
G1 X151.365 Y131.901
G1 X149.949 Y130.485 E.06153
G1 X149.792 Y130.861
G1 X151.358 Y132.427 E.06805
G1 X151.584 Y133.187
G1 X149.666 Y131.269 E.08335
G1 X149.582 Y131.718
G1 X153.943 Y136.079 E.18949
G1 X153.441 Y136.111
G1 X149.551 Y132.22 E.16907
G1 X149.602 Y132.805
M73 P71 R5
G1 X152.857 Y136.059 E.14142
G1 X152.149 Y135.885
G1 X149.777 Y133.513 E.10308
; WIPE_START
M204 S10000
G1 X151.191 Y134.927 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X151.802 Y128.665 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.101979
G1 F15000
G2 X151.682 Y128.752 I.833 J1.271 E.00071
G1 X152.623 Y128.384 F36000
; LINE_WIDTH: 0.0937447
G1 F15000
G1 X152.464 Y128.468 E.00074
G1 X156.641 Y129.949 F36000
; LINE_WIDTH: 0.105096
G1 F15000
G1 X156.494 Y129.775 E.00116
; LINE_WIDTH: 0.132055
G2 X155.815 Y129.107 I-6.687 J6.115 E.00692
; LINE_WIDTH: 0.0975784
G1 X155.712 Y129.02 E.0006
; WIPE_START
G1 X155.815 Y129.107 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X151.363 Y131.926 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.0962563
G1 F15000
G2 X151.284 Y132.087 I2.035 J1.101 E.00078
; WIPE_START
G1 X151.363 Y131.926 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.41 Y134.135 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.204404
G1 F15000
G3 X152.205 Y133.975 I1.997 J-2.771 E.00342
; LINE_WIDTH: 0.165238
G3 X151.733 Y133.511 I4.2 J-4.743 E.0066
; LINE_WIDTH: 0.18581
G1 X151.628 Y133.38 E.00196
; LINE_WIDTH: 0.211882
G1 X151.522 Y133.249 E.00231
; WIPE_START
G1 X151.628 Y133.38 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.143 Y134.204 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.0978514
G1 F15000
G3 X154.015 Y134.284 I-1.099 J-1.618 E.00068
; WIPE_START
G1 X154.143 Y134.204 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.598 Y131.737 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.169393
G1 F15000
G2 X155.443 Y131.461 I-3.696 J1.898 E.00326
; WIPE_START
G1 X155.598 Y131.737 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X157.157 Y133.466 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.0911417
G1 F15000
G1 X157.071 Y133.608 E.00065
; WIPE_START
G1 X157.157 Y133.466 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X151.609 Y135.639 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.105173
G1 F15000
G1 X151.501 Y135.558 E.00068
; LINE_WIDTH: 0.139303
G1 X151.394 Y135.477 E.00106
; LINE_WIDTH: 0.174111
G1 X151.233 Y135.341 E.00225
; LINE_WIDTH: 0.209565
G1 X151.072 Y135.205 E.00286
; LINE_WIDTH: 0.239659
G3 X150.457 Y134.59 I5.092 J-5.707 E.01396
; LINE_WIDTH: 0.209546
G1 X150.32 Y134.428 E.00286
; LINE_WIDTH: 0.174094
G1 X150.184 Y134.267 E.00225
; LINE_WIDTH: 0.139305
G1 X150.103 Y134.16 E.00106
; LINE_WIDTH: 0.105181
G1 X150.022 Y134.053 E.00068
; WIPE_START
G1 X150.103 Y134.16 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.806 Y127.728 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X151.273 Y128.245 I1.279 J6.324 E.05382
G1 X133.984 Y110.956 E.81108
G2 X137.055 Y111.268 I4.403 J-28.037 E.10248
G1 X130.463 Y117.861 E.30929
G2 X125.539 Y117.863 I-2.46 J3.959 E.17207
G1 X118.944 Y111.268 E.30938
G2 X122.015 Y110.957 I-1.316 J-28.285 E.10243
G1 X104.728 Y128.243 E.81094
G2 X103.195 Y127.727 I-2.811 J5.817 E.05382
; WIPE_START
G1 X104.042 Y127.929 E-.33099
G1 X104.728 Y128.243 E-.28686
G1 X104.993 Y127.979 E-.14215
; WIPE_END
G1 E-.04 F1800
G1 X103.502 Y135.464 Z5.4 F36000
G1 X102.064 Y142.685 Z5.4
G1 Z5
G1 E.8 F1800
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.253 J11.56 E.05397
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.927 J1.552 E.08649
G3 X93.83 Y124.534 I9.841 J12.987 E.1013
G1 X98.869 Y129.573 E.2364
G2 X98.587 Y134.385 I3.677 J2.63 E.16865
G1 X90.708 Y142.264 E.3696
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.13381
G2 X83.434 Y139.05 I1.844 J1.489 E.04916
G1 X85.385 Y139.911 E.07073
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.701 E.05406
G1 X140.386 Y111.134 F36000
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.381 E.05407
G1 X170.616 Y139.912 E1.34273
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.418 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X157.416 Y134.388 E.36949
G2 X157.133 Y129.57 I-3.958 J-2.185 E.16889
G1 X162.172 Y124.532 E.23637
G3 X164.985 Y126.364 I-5.412 J11.382 E.11169
G3 X165.932 Y128.447 I-10.694 J6.122 E.07603
G1 X153.083 Y141.297 E.6028
G3 X153.939 Y142.682 I-19.42 J12.96 E.05402
; WIPE_START
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
; WIPE_END
G1 E-.04 F1800
G1 X151.136 Y133.728 Z5.4 F36000
G1 X144.962 Y113.313 Z5.4
G1 Z5
G1 E.8 F1800
G1 F15476.087
G3 X143.645 Y112.355 I11.755 J-17.549 E.05402
G1 X131.605 Y124.395 E.56483
G1 X131.798 Y124.122 E.01109
G1 X136.671 Y128.995 E.22859
G2 X135.109 Y128.566 I-9.999 J33.349 E.05372
G1 X148.43 Y115.246 E.6249
G2 X149.963 Y115.79 I6.996 J-17.265 E.05399
; WIPE_START
G1 X148.43 Y115.246 E-.61833
G1 X148.166 Y115.509 E-.14167
; WIPE_END
G1 E-.04 F1800
G1 X140.816 Y117.564 Z5.4 F36000
G1 X88.404 Y132.211 Z5.4
G1 Z5
G1 E.8 F1800
G1 F15476.087
G3 X87.525 Y133.581 I-17.72 J-10.406 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X104.261 Y136.387 E.38606
G2 X105.177 Y135.881 I-1.717 J-4.187 E.03477
G1 X106.309 Y137.013 E.05313
G3 X110.399 Y133.428 I22.212 J21.213 E.18067
G1 X98.118 Y121.147 E.57613
G2 X100.796 Y117.779 I-30.114 J-26.692 E.14279
G3 X101.665 Y117.017 I2.26 J1.701 E.0386
G1 X115.224 Y130.576 E.6361
G2 X113.77 Y131.309 I14.316 J30.192 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 5.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X115.224 Y130.576 E-.61863
G1 X114.961 Y130.313 E-.14137
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
G1 X124.322 Y121.262
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X124.319 Y121.244 E.00061
G3 X127.588 Y117.979 I3.677 J.413 E.16551
G1 X127.99 Y117.957 E.01336
G3 X124.296 Y121.659 I.006 J3.7 E.57849
G1 X124.318 Y121.322 E.01121
G1 X124.719 Y121.254 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.771 Y120.922 E.01033
G3 X127.632 Y118.37 I3.225 J.735 E.12564
G1 X127.99 Y118.349 E.01104
G3 X124.707 Y121.312 I.006 J3.308 E.48972
; WIPE_START
M204 S10000
G1 X124.771 Y120.922 E-.1504
G1 X124.878 Y120.566 E-.14115
G1 X125.015 Y120.234 E-.13652
G1 X125.199 Y119.898 E-.14544
G1 X125.414 Y119.595 E-.14119
G1 X125.494 Y119.506 E-.04529
; WIPE_END
G1 E-.04 F1800
G1 X118.404 Y122.333 Z5.6 F36000
G1 X102.885 Y128.519 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.96 Y128.525 E.00248
G3 X102.132 Y128.524 I-.42 J3.676 E.74364
G1 X102.534 Y128.501 E.01335
G1 X102.825 Y128.516 E.00968
G1 X102.258 Y128.909 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.534 Y128.894 E.00851
G3 X102.176 Y128.914 I.006 J3.308 E.62753
G1 X102.198 Y128.912 E.00069
; WIPE_START
M204 S10000
G1 X102.534 Y128.894 E-.12801
G1 X102.917 Y128.914 E-.14543
G1 X103.283 Y128.976 E-.14125
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.128 Y129.301 E-.06321
; WIPE_END
G1 E-.04 F1800
G1 X111.755 Y129.598 Z5.6 F36000
G1 X157.063 Y131.362 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.066 Y131.38 E.00059
G3 X153.044 Y128.524 I-3.608 J.821 E.59206
G1 X153.458 Y128.5 E.01377
G3 X156.951 Y130.98 I0 J3.7 E.15154
G1 X157.046 Y131.305 E.01123
G1 X156.666 Y131.401 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.0021
G3 X153.088 Y128.914 I-3.225 J.734 E.49027
G1 X153.458 Y128.893 E.01141
G3 X156.581 Y131.11 I0 J3.308 E.12551
G1 X156.65 Y131.343 E.00747
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.04878
G1 X156.748 Y131.833 E-.14106
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.1411
G1 X156.583 Y133.297 E-.14104
G1 X156.577 Y133.311 E-.00592
; WIPE_END
G1 E-.04 F1800
G1 X156.025 Y140.923 Z5.6 F36000
G1 X155.589 Y146.934 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.58 J.167 E.04815
G3 X84.377 Y136.65 I5.972 J3.757 E.0516
G2 X86.79 Y133.986 I-24.731 J-24.818 E.11929
G2 X89.501 Y128.988 I-13.843 J-10.746 E.18946
G3 X90.41 Y126.674 I23.3 J7.814 E.0825
G3 X91.435 Y125.548 I2.417 J1.171 E.05122
G3 X93.349 Y124.413 I15.957 J24.715 E.07381
G2 X98.059 Y120.702 I-8.564 J-15.715 E.19987
G2 X100.325 Y117.807 I-37.412 J-31.611 E.12197
G3 X101.394 Y116.758 I3.536 J2.535 E.04994
G3 X103.044 Y116.197 I3.008 J6.141 E.05796
G2 X106.577 Y115.257 I-6.544 J-31.724 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.747 E.18841
G3 X113.513 Y111.136 I14.715 J18.731 E.08042
G3 X115.145 Y110.777 I1.449 J2.701 E.05612
G3 X117.853 Y110.909 I-7.765 J188.201 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.101 J28.229 E.09117
G3 X128.183 Y108.872 I.643 J2.633 E.02775
G3 X129.664 Y109.258 I-.811 J6.13 E.05088
G2 X133.389 Y110.477 I12.298 J-31.287 E.1301
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.765 E.08329
G3 X142.679 Y111.256 I-.087 J2.685 E.05111
G3 X144.474 Y112.538 I-15.376 J23.41 E.07318
G2 X149.428 Y115.257 I11.08 J-14.313 E.18822
G2 X152.965 Y116.193 I9.836 J-30.028 E.12146
G3 X154.592 Y116.745 I-1.238 J6.327 E.05717
G3 X155.674 Y117.809 I-2.671 J3.796 E.05058
G2 X157.946 Y120.702 I41.964 J-30.613 E.12203
G2 X162.421 Y124.276 I12.715 J-11.334 E.19089
G3 X164.758 Y125.674 I-13.525 J25.261 E.09035
G3 X165.746 Y127.013 I-1.783 J2.349 E.05597
G3 X166.938 Y130.091 I-684.168 J266.789 E.10951
G2 X170.649 Y135.623 I16.058 J-6.762 E.22232
G3 X172.333 Y137.457 I-17.028 J17.322 E.08262
G3 X172.913 Y139.008 I-2.311 J1.749 E.05572
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.2 J.192 E.05096
G3 X83.717 Y136.795 I3.893 J1.884 E.041
G2 X85.862 Y134.489 I-443.543 J-414.793 E.09675
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.443 J7.866 E.07787
G3 X91.212 Y125.225 I2.76 J1.348 E.05331
G3 X93.152 Y124.073 I16.128 J24.95 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.341 J-31.528 E.1123
G3 X101.193 Y116.421 I3.821 J2.757 E.05061
G3 X102.951 Y115.816 I3.187 J6.403 E.05731
G2 X106.449 Y114.887 I-6.457 J-31.36 E.11124
G2 X111.301 Y112.219 I-5.849 J-16.382 E.17089
G3 X113.32 Y110.795 I14.845 J18.905 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.449 J182.394 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21158
G3 X127.013 Y108.625 I13.213 J33.907 E.07782
G3 X128.217 Y108.481 I.983 J3.111 E.03747
G3 X129.793 Y108.888 I-.84 J6.503 E.05016
G2 X133.154 Y110.014 I13.012 J-33.267 E.10895
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.88 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05321
G3 X144.706 Y112.222 I-15.538 J23.684 E.06879
G2 X149.556 Y114.887 I10.852 J-14.004 E.17076
G2 X153.057 Y115.812 I9.717 J-29.687 E.11131
G3 X154.703 Y116.356 I-1.36 J6.876 E.05342
G3 X155.765 Y117.301 I-1.907 J3.212 E.04394
G2 X157.819 Y119.952 I1368.425 J-1057.996 E.10304
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.299 J30.199 E.07722
G3 X166.104 Y126.854 I-1.828 J2.82 E.0659
G3 X167.3 Y129.94 I-597.04 J233.097 E.10168
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.22 J17.505 E.07791
G3 X173.302 Y138.956 I-2.618 J1.981 E.05776
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z5.6 F36000
G1 Z5.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.266 J11.569 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.655 J1.408 E.08775
G2 X162.172 Y124.532 I-25.059 J37.925 E.10007
G1 X157.19 Y129.513 E.2337
G3 X157.474 Y134.447 I-3.733 J2.69 E.17305
G1 X165.292 Y142.265 E.36675
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.908 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34272
G2 X140.386 Y111.134 I-1.124 J3.225 E.05407
G1 X149.963 Y115.79 F36000
G1 F15476.087
G3 X148.43 Y115.246 I5.472 J-17.836 E.05399
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.448 J33.816 E.05372
G1 X131.855 Y124.179 E.22592
G2 X131.922 Y124.078 I-.544 J-.433 E.00405
G1 X143.638 Y112.362 E.54962
G2 X144.96 Y113.312 I15.655 J-20.39 E.05402
G1 X132.132 Y121.199 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53945
G1 F12000
G1 X131.932 Y120.314 E.03675
G1 X131.534 Y119.473 E.03764
G1 X130.959 Y118.742 E.03763
G1 X130.236 Y118.157 E.03763
G1 X129.4 Y117.748 E.03764
G1 X128.494 Y117.534 E.03769
G1 X127.994 Y117.505 E.02024
G1 X127.105 Y117.603 E.0362
G1 X126.224 Y117.905 E.03768
G1 X125.434 Y118.394 E.03757
G1 X124.772 Y119.048 E.03764
G1 X124.476 Y119.462 E.02061
G1 X124.091 Y120.261 E.03589
G1 X123.878 Y121.166 E.03763
G1 X123.872 Y122.097 E.03763
G1 X124.073 Y123.005 E.03763
G1 X124.471 Y123.845 E.03764
G1 X125.046 Y124.576 E.03763
G1 X125.769 Y125.161 E.03763
G1 X126.604 Y125.57 E.03764
G1 X127.51 Y125.784 E.03764
G1 X128.44 Y125.79 E.03763
G1 X129.348 Y125.589 E.03763
G1 X129.819 Y125.395 E.02062
G1 X130.57 Y124.924 E.03588
G1 X131.232 Y124.271 E.03764
G1 X131.528 Y123.856 E.02061
G1 X131.914 Y123.057 E.03589
G1 X132.127 Y122.152 E.03763
G1 X132.133 Y121.259 E.03611
; WIPE_START
G1 X132.127 Y122.152 E-.3391
G1 X131.914 Y123.057 E-.35339
G1 X131.837 Y123.217 E-.06752
; WIPE_END
G1 E-.04 F1800
G1 X124.368 Y124.488 Z5.6 F36000
G1 Z5.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X124.393 Y124.522 E.00141
G2 X125.572 Y125.572 I3.953 J-3.253 E.05257
G1 X127.713 Y127.714 E.10046
G3 X128.286 Y127.714 I.288 J8.19 E.019
G1 X130.456 Y125.558 E.10145
G2 X131.632 Y124.494 I-2.752 J-4.224 E.05281
G1 X113.77 Y131.309 F36000
G1 F15476.087
G3 X115.224 Y130.576 I15.769 J29.459 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.778 I1.391 J2.462 E.03858
G3 X98.118 Y121.147 I-32.814 J-23.341 E.14281
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.733 J27.774 E.18055
G1 X105.233 Y135.938 E.05046
G3 X104.115 Y136.533 I-2.813 J-3.936 E.04217
G1 X96.032 Y144.616 E.37919
G1 X100.23 Y146.471 E.15226
M73 P72 R5
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.836 J-11.773 E.054
; WIPE_START
G1 X87.525 Y133.581 E-.61839
G1 X87.789 Y133.844 E-.14161
; WIPE_END
G1 E-.04 F1800
G1 X95.03 Y131.433 Z5.6 F36000
G1 X104.787 Y128.185 Z5.6
G1 Z5.2
G1 E.8 F1800
G1 F15476.087
G1 X122.015 Y110.957 E.8082
G3 X118.944 Y111.268 I-4.387 J-27.977 E.10243
G1 X125.482 Y117.806 E.30671
G1 X125.53 Y117.772 E.00196
G3 X130.519 Y117.804 I2.47 J3.924 E.17476
G1 X137.055 Y111.268 E.30662
G3 X133.984 Y110.956 I1.331 J-28.35 E.10248
G1 X151.215 Y128.187 E.80834
; WIPE_START
G1 X149.8 Y126.773 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.234 Y130.879 Z5.6 F36000
G1 X157.588 Y131.743 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.539475
G1 F12000
G1 X157.387 Y130.856 E.0368
G1 X156.99 Y130.017 E.03758
G1 X156.415 Y129.286 E.03763
G1 X155.691 Y128.701 E.03764
G1 X154.856 Y128.292 E.03763
G1 X153.951 Y128.079 E.03764
G1 X153.445 Y128.049 E.02052
G1 X152.561 Y128.148 E.03598
G1 X151.681 Y128.449 E.03763
G1 X150.89 Y128.938 E.03763
G1 X150.228 Y129.592 E.03764
G1 X149.727 Y130.377 E.0377
G1 X149.415 Y131.252 E.03758
G1 X149.304 Y132.175 E.03763
G1 X149.402 Y133.1 E.03764
G1 X149.542 Y133.59 E.02061
G1 X149.926 Y134.39 E.03589
G1 X150.501 Y135.121 E.03763
G1 X151.225 Y135.705 E.03764
G1 X152.06 Y136.115 E.03764
G1 X152.965 Y136.328 E.03764
G1 X153.896 Y136.334 E.03763
G1 X154.804 Y136.133 E.03763
G1 X155.644 Y135.735 E.03764
G1 X156.376 Y135.16 E.03763
G1 X156.96 Y134.437 E.03764
G1 X157.369 Y133.601 E.03763
G1 X157.583 Y132.696 E.03764
G1 X157.589 Y131.803 E.03612
G1 X167.597 Y132.209 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X168.477 Y133.578 I19.139 J-11.349 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X151.881 Y136.53 E.37942
G3 X150.768 Y135.935 I1.694 J-4.513 E.04197
G1 X149.693 Y137.011 E.05043
G2 X145.602 Y133.425 I-22.204 J21.21 E.18067
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.324 I24.849 J-22.135 E.11974
G2 X154.34 Y117.012 I-5.159 J3.795 E.06133
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.34 J30.252 E.05401
; WIPE_START
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
; WIPE_END
G1 E-.04 F1800
G1 X134.947 Y125.715 Z5.6 F36000
G1 X115.627 Y111.14 Z5.6
G1 Z5.2
G1 E.8 F1800
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.842 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.364 J.127 E.04916
G1 X86.809 Y140.541 E.13381
G1 X90.708 Y142.264 E.14141
G1 X98.528 Y134.444 E.36686
G3 X98.812 Y129.516 I4.018 J-2.24 E.1728
G1 X93.83 Y124.534 E.23373
G2 X90.988 Y126.402 I5.507 J11.474 E.11314
G2 X90.068 Y128.448 I10.56 J5.976 E.07454
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.046 J23.848 E.05401
G1 X107.153 Y132.175 F36000
G1 F15476.087
G1 X107.154 Y132.192 E.00055
G3 X106.876 Y133.771 I-5.052 J-.072 E.05343
G1 X130.659 Y109.989 E1.1157
G2 X128.001 Y109.211 I-4.603 J10.803 E.0921
G2 X125.341 Y109.989 I1.785 J11.044 E.09217
G1 X149.132 Y133.78 E1.11609
G1 X149.114 Y133.739 E.00148
G3 X148.851 Y132.184 I4.872 J-1.624 E.0525
; WIPE_START
G1 X148.881 Y132.731 E-.20783
G1 X149.114 Y133.739 E-.39324
G1 X149.132 Y133.78 E-.017
G1 X148.868 Y133.516 E-.14193
; WIPE_END
G1 E-.04 F1800
G1 X141.242 Y133.196 Z5.6 F36000
G1 X106.676 Y131.743 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.539505
G1 F12000
G1 X106.476 Y130.858 E.03674
G1 X106.078 Y130.017 E.03764
G1 X105.503 Y129.286 E.03764
G1 X104.78 Y128.701 E.03765
G1 X103.945 Y128.292 E.03763
G1 X103.038 Y128.079 E.0377
G1 X102.538 Y128.049 E.02024
G1 X101.649 Y128.148 E.03621
G1 X100.769 Y128.449 E.03763
G1 X99.978 Y128.938 E.03763
G1 X99.316 Y129.592 E.03764
G1 X99.021 Y130.006 E.02061
G1 X98.635 Y130.805 E.0359
G1 X98.422 Y131.711 E.03764
G1 X98.416 Y132.641 E.03763
G1 X98.617 Y133.549 E.03763
G1 X99.015 Y134.39 E.03764
G1 X99.59 Y135.121 E.03764
G1 X100.314 Y135.706 E.03769
G1 X101.148 Y136.115 E.03758
G1 X102.054 Y136.328 E.03764
G1 X102.984 Y136.334 E.03764
G1 X103.892 Y136.133 E.03764
G1 X104.733 Y135.735 E.03764
G1 X105.464 Y135.16 E.03764
G1 X106.049 Y134.437 E.03763
G1 X106.458 Y133.601 E.03764
G1 X106.671 Y132.696 E.03764
G1 X106.677 Y131.803 E.03612
G1 X111.04 Y113.314 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X112.36 Y112.361 I-13.397 J-19.946 E.05402
G1 X124.148 Y124.176 E.55363
G1 X119.326 Y128.997 E.22617
G3 X120.891 Y128.567 I10.051 J33.499 E.05383
G1 X107.571 Y115.247 E.62487
G3 X106.038 Y115.792 I-7.027 J-17.364 E.05399
; CHANGE_LAYER
; Z_HEIGHT: 5.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X107.571 Y115.247 E-.61834
G1 X107.835 Y115.511 E-.14167
; WIPE_END
G1 E-.03999 F1800
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
G1 X124.322 Y121.262
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X124.328 Y121.245 E.00061
G3 X127.934 Y117.96 I3.677 J.415 E.17666
G3 X126.459 Y125.022 I.066 J3.699 E.44045
G3 X124.305 Y121.659 I1.547 J-3.362 E.13991
G1 X124.319 Y121.322 E.01118
G1 X124.718 Y121.257 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.784 Y120.924 E.0104
G3 X127.956 Y118.351 I3.225 J.734 E.13526
G3 X129.096 Y118.535 I.061 J3.256 E.03566
G3 X124.719 Y121.316 I-1.087 J3.124 E.45545
; WIPE_START
M204 S10000
G1 X124.784 Y120.924 E-.15085
G1 X124.878 Y120.566 E-.14091
G1 X125.02 Y120.223 E-.14104
G1 X125.199 Y119.898 E-.14108
G1 X125.414 Y119.595 E-.14105
G1 X125.493 Y119.507 E-.04507
; WIPE_END
G1 E-.04 F1800
G1 X132.638 Y122.19 Z5.8 F36000
G1 X157.063 Y131.362 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.067 Y131.38 E.00059
G3 X153.044 Y128.524 I-3.609 J.822 E.59228
G1 X153.458 Y128.5 E.01377
G3 X156.952 Y130.981 I0 J3.701 E.15159
G1 X157.047 Y131.304 E.01119
G1 X156.668 Y131.406 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.00192
G3 X153.088 Y128.914 I-3.226 J.735 E.49047
G1 X153.458 Y128.893 E.01141
G3 X156.582 Y131.11 I0 J3.309 E.12553
G1 X156.651 Y131.349 E.00763
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.04661
G1 X156.748 Y131.833 E-.14108
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.14111
G1 X156.583 Y133.297 E-.14103
G1 X156.575 Y133.316 E-.00808
; WIPE_END
G1 E-.04 F1800
G1 X148.972 Y132.647 Z5.8 F36000
G1 X102.15 Y128.523 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.478 Y128.504 E.0109
G3 X104.153 Y128.867 I.043 J3.852 E.05734
G3 X102.091 Y128.532 I-1.599 J3.336 E.70074
G1 X102.254 Y128.909 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.5 Y128.896 E.00756
G3 X103.64 Y129.079 I.062 J3.255 E.03566
G3 X102.176 Y128.917 I-1.087 J3.125 E.59306
G1 X102.194 Y128.915 E.00056
; WIPE_START
M204 S10000
G1 X102.5 Y128.896 E-.1163
G1 X102.917 Y128.914 E-.15867
G1 X103.283 Y128.976 E-.1411
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.125 Y129.299 E-.06183
; WIPE_END
G1 E-.04 F1800
G1 X111.345 Y131.774 Z5.8 F36000
G1 X155.589 Y146.934 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.6296
G3 X83.411 Y137.866 I3.579 J.167 E.04816
G3 X84.377 Y136.65 I5.975 J3.759 E.05161
G2 X86.79 Y133.986 I-24.73 J-24.816 E.11928
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.3 J7.814 E.08251
G3 X91.435 Y125.548 I2.417 J1.171 E.05121
G3 X93.349 Y124.413 I15.938 J24.683 E.07381
G2 X98.059 Y120.702 I-8.564 J-15.715 E.19987
G2 X100.325 Y117.807 I-37.398 J-31.6 E.12197
G3 X101.394 Y116.758 I3.536 J2.536 E.04993
G3 X103.044 Y116.197 I3.009 J6.143 E.05796
G2 X106.576 Y115.257 I-6.544 J-31.726 E.12132
G2 X111.534 Y112.534 I-5.974 J-16.747 E.18843
G3 X113.513 Y111.136 I14.724 J18.743 E.0804
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.766 J188.211 E.08995
G2 X124.754 Y109.831 I.851 J-17.19 E.2333
G3 X127.353 Y108.943 I11.099 J28.223 E.09117
G3 X128.183 Y108.872 I.643 J2.633 E.02774
G3 X129.664 Y109.258 I-.81 J6.128 E.05088
G2 X133.389 Y110.477 I12.298 J-31.286 E.1301
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.779 E.08329
G3 X142.679 Y111.255 I-.087 J2.685 E.05111
G3 X144.474 Y112.538 I-15.359 J23.386 E.07318
G2 X149.428 Y115.257 I11.081 J-14.315 E.18823
G2 X152.965 Y116.193 I9.84 J-30.043 E.12145
G3 X154.569 Y116.731 I-1.274 J6.462 E.05628
G3 X155.674 Y117.809 I-2.601 J3.771 E.05146
G2 X157.946 Y120.702 I41.975 J-30.621 E.12202
G2 X162.421 Y124.276 I12.715 J-11.333 E.19091
G3 X164.757 Y125.673 I-13.536 J25.279 E.09034
G3 X165.746 Y127.013 I-1.782 J2.349 E.05598
G3 X166.938 Y130.091 I-681.24 J265.657 E.10951
G2 X170.649 Y135.623 I16.058 J-6.761 E.22232
G3 X172.333 Y137.457 I-17.023 J17.317 E.08263
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.94 Y137.937 I5.368 J.215 E.04933
G3 X83.717 Y136.795 I3.824 J1.766 E.04261
G2 X85.862 Y134.489 I-445.573 J-416.677 E.09678
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.434 J7.863 E.07788
G3 X91.212 Y125.225 I2.76 J1.348 E.0533
G3 X93.152 Y124.073 I16.117 J24.931 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.334 J-31.522 E.1123
G3 X101.193 Y116.421 I3.821 J2.758 E.05062
G3 X102.951 Y115.816 I3.187 J6.404 E.05729
G2 X106.448 Y114.887 I-6.459 J-31.367 E.11124
G2 X111.301 Y112.218 I-5.848 J-16.382 E.1709
G3 X113.32 Y110.795 I14.858 J18.922 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05819
G3 X117.867 Y110.517 I-7.449 J182.403 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21158
G3 X127.014 Y108.625 I13.201 J33.875 E.07784
G3 X128.217 Y108.481 I.982 J3.112 E.03746
G3 X129.793 Y108.888 I-.84 J6.502 E.05016
G2 X133.154 Y110.014 I13.012 J-33.267 E.10895
G2 X138.707 Y110.489 I4.211 J-16.532 E.17203
G3 X141.261 Y110.387 I2.31 J25.883 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05321
G3 X144.706 Y112.222 I-15.521 J23.66 E.0688
G2 X149.556 Y114.887 I10.853 J-14.005 E.17076
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.77 Y116.394 I-1.342 J6.763 E.05576
G3 X155.765 Y117.3 I-2.18 J3.39 E.04154
G2 X157.819 Y119.952 I1394.883 J-1078.504 E.10306
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.318 J30.233 E.0772
G3 X166.104 Y126.854 I-1.827 J2.82 E.06592
G3 X167.3 Y129.94 I-596.57 J232.916 E.10168
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.647 Y137.222 I-17.216 J17.502 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05775
G3 X173.36 Y139.508 I-10.393 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38731
G1 X154.608 Y145.61 E-.07071
; WIPE_END
G1 E-.04 F1800
G1 X156.206 Y138.146 Z5.8 F36000
G1 X157.575 Y131.745 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.540031
G1 F12000
G1 X157.501 Y131.252 E.02018
G1 X157.212 Y130.426 E.03545
G1 X156.723 Y129.635 E.03766
G1 X156.07 Y128.973 E.03768
G1 X155.285 Y128.473 E.03767
G1 X154.41 Y128.16 E.03768
G1 X153.486 Y128.05 E.03768
G1 X152.561 Y128.148 E.03768
G1 X151.681 Y128.449 E.03768
G2 X150.823 Y128.995 I1.67 J3.569 E.04131
G1 X150.227 Y129.593 E.03418
G1 X149.727 Y130.377 E.03769
G1 X149.537 Y130.84 E.02026
G1 X149.333 Y131.712 E.03627
G1 X149.327 Y132.641 E.03763
G1 X149.529 Y133.55 E.03775
G1 X149.744 Y134.058 E.02235
G1 X150.194 Y134.772 E.03418
G1 X150.847 Y135.433 E.03763
G1 X151.631 Y135.933 E.03767
G1 X152.507 Y136.247 E.03768
G1 X153.43 Y136.357 E.03768
G1 X154.355 Y136.259 E.03768
G1 X155.235 Y135.958 E.03768
G1 X156.026 Y135.468 E.03767
G1 X156.688 Y134.815 E.03769
G1 X157.188 Y134.031 E.03767
G1 X157.501 Y133.155 E.03768
G1 X157.612 Y132.231 E.03768
G1 X157.58 Y131.805 E.01733
; WIPE_START
G1 X157.612 Y132.231 E-.16254
G1 X157.501 Y133.155 E-.35348
G1 X157.285 Y133.759 E-.24398
; WIPE_END
G1 E-.04 F1800
G1 X151.662 Y128.598 Z5.8 F36000
G1 X151.215 Y128.187 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.984 Y110.956 E.80834
G2 X137.055 Y111.268 I4.403 J-28.037 E.10248
G1 X130.519 Y117.804 E.30662
G1 X130.463 Y117.764 E.00229
G2 X125.482 Y117.806 I-2.457 J3.929 E.17444
G1 X118.944 Y111.268 E.30671
G2 X122.015 Y110.957 I-1.317 J-28.29 E.10243
G1 X104.787 Y128.185 E.8082
G1 X106.664 Y131.745 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.539908
G1 F12000
G1 X106.589 Y131.252 E.02018
G1 X106.3 Y130.425 E.0355
G1 X106.029 Y129.944 E.02234
G1 X105.502 Y129.285 E.03416
G1 X104.78 Y128.701 E.03763
G1 X103.945 Y128.292 E.03767
G1 X103.037 Y128.079 E.03774
G1 X102.486 Y128.052 E.02236
G1 X101.648 Y128.148 E.03415
G1 X100.769 Y128.449 E.03762
G1 X99.978 Y128.939 E.03767
G1 X99.316 Y129.592 E.03767
G2 X98.78 Y130.456 I3.053 J2.492 E.04129
G1 X98.503 Y131.253 E.03418
G1 X98.393 Y132.175 E.03762
G1 X98.491 Y133.1 E.03767
G1 X98.792 Y133.981 E.03768
G1 X99.282 Y134.771 E.03765
G1 X99.935 Y135.433 E.03768
G1 X100.719 Y135.933 E.03766
G1 X101.595 Y136.247 E.03767
G1 X102.519 Y136.357 E.03766
G1 X103.444 Y136.259 E.03767
G1 X104.324 Y135.958 E.03768
G1 X105.114 Y135.468 E.03766
G1 X105.777 Y134.815 E.03768
G1 X106.277 Y134.031 E.03766
G1 X106.59 Y133.155 E.03767
G1 X106.7 Y132.231 E.03767
G1 X106.668 Y131.805 E.01732
; WIPE_START
G1 X106.7 Y132.231 E-.16252
G1 X106.59 Y133.155 E-.35345
G1 X106.374 Y133.759 E-.24403
; WIPE_END
G1 E-.04 F1800
G1 X103.055 Y140.633 Z5.8 F36000
G1 X102.064 Y142.685 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.253 J11.56 E.05397
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.924 J1.551 E.08651
G3 X93.83 Y124.534 I9.845 J12.995 E.10128
G1 X98.812 Y129.516 E.23373
G2 X98.528 Y134.444 I3.734 J2.687 E.1728
G1 X90.708 Y142.264 E.36686
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.1338
G2 X83.434 Y139.05 I1.844 J1.488 E.04916
G1 X85.385 Y139.911 E.07073
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.7 E.05406
G1 X106.038 Y115.792 F36000
G1 F15476.087
G2 X107.571 Y115.247 I-5.49 J-17.898 E.05399
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.486 J33.929 E.05383
G1 X124.148 Y124.176 E.22617
G1 X112.36 Y112.361 E.55363
G3 X111.04 Y113.314 I-14.725 J-19.006 E.05402
; WIPE_START
G1 X112.36 Y112.361 E-.61871
G1 X112.623 Y112.624 E-.1413
; WIPE_END
G1 E-.04 F1800
G1 X119.609 Y115.697 Z5.8 F36000
G1 X132.12 Y121.201 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.540692
G1 F12000
G1 X132.045 Y120.708 E.02022
G1 X131.757 Y119.882 E.03549
G1 X131.267 Y119.091 E.03771
G1 X130.614 Y118.429 E.03774
M73 P73 R5
G1 X129.83 Y117.929 E.03772
G1 X128.954 Y117.616 E.03774
G2 X127.942 Y117.508 I-.92 J3.827 E.04138
G1 X127.104 Y117.604 E.03421
G1 X126.225 Y117.905 E.03769
G2 X125.391 Y118.429 I3.143 J5.924 E.04
G1 X124.772 Y119.048 E.03549
G1 X124.273 Y119.832 E.03772
G1 X123.959 Y120.708 E.03772
G1 X123.849 Y121.631 E.03773
G1 X123.947 Y122.556 E.03773
G1 X124.248 Y123.436 E.03774
G1 X124.737 Y124.227 E.03772
G1 X125.391 Y124.889 E.03774
G2 X126.255 Y125.425 I2.493 J-3.056 E.04136
G1 X127.052 Y125.703 E.03423
G1 X127.974 Y125.813 E.03768
G1 X128.899 Y125.715 E.03773
G1 X129.78 Y125.413 E.03774
G2 X130.613 Y124.889 I-3.141 J-5.922 E.03999
G1 X131.232 Y124.27 E.0355
G1 X131.732 Y123.486 E.03772
G1 X132.046 Y122.61 E.03773
G1 X132.156 Y121.687 E.03773
G1 X132.124 Y121.261 E.01734
G1 X131.632 Y124.494 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X131.611 Y124.522 E.00115
G3 X130.425 Y125.575 I-3.896 J-3.198 E.05283
G1 X128.286 Y127.714 E.10033
G2 X127.713 Y127.714 I-.285 J8.19 E.019
G1 X125.561 Y125.566 E.10087
G3 X124.368 Y124.488 I2.743 J-4.232 E.05355
G1 X142.231 Y131.307 F36000
G1 F15476.087
G2 X140.777 Y130.574 I-15.794 J29.519 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.634 Y118.324 I-3.853 J5.095 E.06134
G2 X157.884 Y121.144 I27.085 J-19.303 E.11974
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-18.114 J24.796 E.18067
G1 X150.768 Y135.935 E.05043
G2 X151.881 Y136.53 I2.807 J-3.919 E.04197
G1 X159.969 Y144.617 E.37942
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.257 J-12.716 E.054
; WIPE_START
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
; WIPE_END
G1 E-.04 F1800
G1 X160.609 Y133.191 Z5.8 F36000
G1 X148.851 Y132.184 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F15476.087
G1 X148.851 Y132.192 E.00024
G2 X149.132 Y133.78 I5.034 J-.071 E.05373
G1 X125.341 Y109.989 E1.11609
G3 X127.999 Y109.211 I4.457 J10.302 E.09211
G3 X130.659 Y109.989 I-1.931 J11.546 E.09216
G1 X106.891 Y133.736 E1.11452
G2 X107.153 Y132.175 I-4.846 J-1.614 E.0527
; WIPE_START
G1 X107.123 Y132.731 E-.21131
G1 X106.891 Y133.736 E-.39208
G1 X107.183 Y133.445 E-.15661
; WIPE_END
G1 E-.04 F1800
G1 X99.567 Y132.944 Z5.8 F36000
G1 X88.404 Y132.211 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F15476.087
G3 X87.525 Y133.581 I-17.72 J-10.406 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X104.115 Y136.533 E.37919
G2 X105.233 Y135.938 I-1.695 J-4.532 E.04217
G1 X106.309 Y137.013 E.05046
G3 X110.399 Y133.428 I22.212 J21.213 E.18067
G1 X98.118 Y121.147 E.57613
G2 X100.796 Y117.778 I-30.14 J-26.713 E.14281
G3 X101.665 Y117.017 I2.261 J1.702 E.03858
G1 X115.224 Y130.576 E.6361
G2 X113.77 Y131.309 I14.316 J30.192 E.05401
; WIPE_START
G1 X115.224 Y130.576 E-.61863
G1 X114.961 Y130.313 E-.14137
; WIPE_END
G1 E-.04 F1800
G1 X121.054 Y125.717 Z5.8 F36000
G1 X140.386 Y111.134 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.379 E.05407
G1 X170.616 Y139.912 E1.34273
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.419 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X157.474 Y134.447 E.36675
G2 X157.19 Y129.513 I-4.017 J-2.244 E.17305
G1 X162.172 Y124.532 E.2337
G3 X164.984 Y126.363 I-5.418 J11.393 E.11165
G3 X165.932 Y128.447 I-10.676 J6.116 E.07606
G1 X153.083 Y141.297 E.6028
G3 X153.939 Y142.682 I-19.42 J12.96 E.05402
; WIPE_START
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
; WIPE_END
G1 E-.04 F1800
G1 X151.136 Y133.728 Z5.8 F36000
G1 X144.962 Y113.313 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F15476.087
G3 X143.645 Y112.355 I11.755 J-17.549 E.05402
G1 X131.911 Y124.098 E.55067
G3 X131.855 Y124.179 I-.739 J-.449 E.00328
G1 X136.671 Y128.995 E.22592
G2 X135.109 Y128.566 I-10.009 J33.387 E.05372
G1 X148.43 Y115.246 E.6249
G2 X149.963 Y115.79 I6.994 J-17.259 E.05399
; CHANGE_LAYER
; Z_HEIGHT: 5.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X148.43 Y115.246 E-.61833
G1 X148.166 Y115.509 E-.14167
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
G1 X124.322 Y121.263
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X124.334 Y121.246 E.00069
G3 X127.911 Y117.961 I3.677 J.414 E.17571
G3 X129.609 Y118.323 I.072 J3.829 E.0581
G3 X124.311 Y121.659 I-1.598 J3.337 E.52362
G1 X124.32 Y121.323 E.01117
G1 X124.718 Y121.259 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.786 Y120.925 E.01049
G3 X127.933 Y118.353 I3.225 J.734 E.13447
G3 X129.096 Y118.535 I.089 J3.238 E.03637
G3 X124.721 Y121.319 I-1.084 J3.125 E.45546
; WIPE_START
M204 S10000
G1 X124.786 Y120.925 E-.15156
G1 X124.878 Y120.566 E-.14084
G1 X125.02 Y120.223 E-.14107
G1 X125.199 Y119.898 E-.1411
G1 X125.414 Y119.595 E-.14102
G1 X125.492 Y119.508 E-.04441
; WIPE_END
G1 E-.04 F1800
G1 X132.637 Y122.191 Z6 F36000
G1 X157.063 Y131.362 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.067 Y131.38 E.0006
G3 X153.044 Y128.524 I-3.609 J.821 E.59221
G1 X153.458 Y128.5 E.01377
G3 X156.952 Y130.981 I0 J3.701 E.15158
G1 X157.046 Y131.304 E.01118
G1 X156.67 Y131.412 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.00175
G3 X153.088 Y128.914 I-3.226 J.735 E.49044
G1 X153.458 Y128.893 E.01141
G3 X156.582 Y131.11 I0 J3.309 E.12553
G1 X156.653 Y131.354 E.00781
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.04442
G1 X156.748 Y131.833 E-.14108
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.14111
G1 X156.583 Y133.297 E-.14104
G1 X156.572 Y133.322 E-.01026
; WIPE_END
G1 E-.04 F1800
G1 X148.969 Y132.652 Z6 F36000
G1 X102.114 Y128.527 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.132 Y128.528 E.00061
G3 X102.455 Y128.505 I.423 J3.676 E.01072
G3 X104.153 Y128.867 I.072 J3.829 E.0581
G3 X101.724 Y128.599 I-1.598 J3.337 E.68858
G1 X102.055 Y128.537 E.01118
G1 X102.25 Y128.91 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.477 Y128.897 E.00697
G3 X103.64 Y129.079 I.089 J3.238 E.03637
G3 X102.176 Y128.918 I-1.084 J3.125 E.59301
G1 X102.191 Y128.916 E.00045
; WIPE_START
M204 S10000
G1 X102.477 Y128.897 E-.10894
G1 X102.917 Y128.914 E-.16743
G1 X103.283 Y128.976 E-.1411
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.122 Y129.298 E-.06044
; WIPE_END
G1 E-.04 F1800
G1 X111.342 Y131.772 Z6 F36000
G1 X155.589 Y146.934 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04816
G3 X84.377 Y136.65 I5.975 J3.759 E.05161
G2 X86.79 Y133.986 I-24.732 J-24.818 E.11929
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18945
G3 X90.41 Y126.674 I23.305 J7.816 E.0825
G3 X91.436 Y125.548 I2.418 J1.171 E.05123
G3 X93.349 Y124.413 I15.943 J24.692 E.07381
G2 X98.059 Y120.701 I-8.564 J-15.715 E.19988
G2 X100.324 Y117.807 I-37.391 J-31.593 E.12194
G3 X101.394 Y116.758 I3.536 J2.535 E.04995
G3 X103.044 Y116.197 I3.008 J6.142 E.05796
G2 X106.577 Y115.257 I-6.544 J-31.729 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.747 E.18842
G3 X113.513 Y111.136 I14.725 J18.745 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.766 J188.209 E.08995
G2 X124.754 Y109.831 I.851 J-17.19 E.2333
G3 X127.354 Y108.943 I11.103 J28.237 E.09117
G3 X128.184 Y108.872 I.643 J2.632 E.02774
G3 X129.663 Y109.258 I-.811 J6.129 E.05087
G2 X133.389 Y110.477 I12.616 J-32.258 E.13011
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.778 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05112
G3 X144.474 Y112.538 I-15.39 J23.427 E.07317
G2 X149.427 Y115.257 I11.081 J-14.314 E.18822
G2 X152.965 Y116.193 I9.837 J-30.03 E.12147
G3 X154.57 Y116.731 I-1.24 J6.362 E.05629
G3 X155.675 Y117.81 I-2.604 J3.773 E.05149
G2 X157.946 Y120.702 I41.937 J-30.592 E.122
G2 X162.421 Y124.276 I12.715 J-11.333 E.19089
G3 X164.758 Y125.673 I-13.527 J25.265 E.09034
G3 X165.746 Y127.013 I-1.782 J2.349 E.05599
G3 X166.938 Y130.091 I-682.879 J266.289 E.1095
G2 X170.65 Y135.624 I16.058 J-6.762 E.22235
G3 X172.333 Y137.457 I-17.042 J17.334 E.08261
G3 X172.913 Y139.008 I-2.311 J1.749 E.0557
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.939 Y137.939 I5.375 J.216 E.04927
G3 X83.717 Y136.795 I3.823 J1.763 E.04268
G2 X85.862 Y134.489 I-444.708 J-415.878 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.435 J7.863 E.07787
G3 X91.213 Y125.225 I2.76 J1.348 E.05332
G3 X93.152 Y124.073 I16.126 J24.946 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.017 Y117.563 I-37.314 J-31.506 E.11229
G3 X101.193 Y116.421 I3.822 J2.758 E.05063
G3 X102.951 Y115.816 I3.187 J6.402 E.0573
G2 X106.448 Y114.887 I-6.459 J-31.369 E.11124
G2 X111.301 Y112.218 I-5.848 J-16.382 E.1709
G3 X113.32 Y110.795 I14.856 J18.92 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05819
G3 X117.867 Y110.517 I-7.449 J182.402 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.014 Y108.625 I13.218 J33.924 E.07784
G3 X128.217 Y108.481 I.982 J3.111 E.03746
G3 X129.793 Y108.888 I-.84 J6.501 E.05015
G2 X133.481 Y110.096 I12.491 J-31.904 E.1193
G2 X138.707 Y110.489 I3.893 J-16.812 E.16168
G3 X141.261 Y110.387 I2.31 J25.883 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05321
G3 X144.706 Y112.222 I-15.539 J23.685 E.06879
G2 X149.556 Y114.887 I10.852 J-14.004 E.17076
G2 X153.056 Y115.812 I9.715 J-29.679 E.1113
G3 X154.77 Y116.394 I-1.31 J6.671 E.05579
G3 X155.765 Y117.301 I-2.181 J3.391 E.04155
G2 X157.819 Y119.952 I1384.923 J-1070.783 E.10304
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.304 J30.21 E.07721
G3 X166.104 Y126.854 I-1.828 J2.82 E.06591
G3 X167.3 Y129.94 I-597.159 J233.144 E.10168
G2 X170.934 Y135.354 I15.7 J-6.612 E.2016
G3 X172.647 Y137.222 I-17.224 J17.508 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05775
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z6 F36000
G1 Z5.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.266 J11.569 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.655 J1.408 E.08775
G2 X162.172 Y124.532 I-25.034 J37.883 E.10008
G1 X156.792 Y129.911 E.25237
G3 X157.066 Y134.038 I-3.344 J2.294 E.14398
G1 X165.292 Y142.265 E.38591
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.908 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34273
G2 X140.386 Y111.134 I-1.124 J3.224 E.05407
G1 X130.347 Y124.956 F36000
G1 F15476.087
G2 X131.454 Y123.778 I-2.426 J-3.388 E.05396
G1 X136.671 Y128.995 E.24476
G2 X135.109 Y128.566 I-10.009 J33.387 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.645 Y112.355 I8.086 J-18.792 E.18603
G1 X128.286 Y127.714 E.7205
G2 X127.713 Y127.714 I-.285 J8.198 E.019
G1 X112.36 Y112.361 E.72024
G3 X107.571 Y115.247 I-12.978 J-16.116 E.18607
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.486 J33.929 E.05383
G1 X124.549 Y123.775 E.24502
G2 X125.655 Y124.954 I3.532 J-2.203 E.05396
G1 X113.77 Y131.309 F36000
G1 F15476.087
G3 X115.224 Y130.576 I15.772 J29.463 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.778 I1.393 J2.464 E.03858
G3 X98.118 Y121.147 I-32.804 J-23.333 E.14281
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.736 J27.777 E.18055
G1 X104.835 Y135.539 E.06913
; WIPE_START
G1 X106.25 Y136.954 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.644 Y129.599 Z6 F36000
G1 Z5.6
G1 E.8 F1800
G1 F15476.087
G2 X104.378 Y128.594 I-3.985 J3.719 E.05383
G1 X122.015 Y110.957 E.82736
G3 X118.944 Y111.268 I-4.387 J-27.978 E.10243
G1 X125.884 Y118.208 E.32555
G3 X130.118 Y118.206 I2.119 J3.613 E.14725
G1 X137.055 Y111.268 E.32547
G3 X133.984 Y110.956 I1.331 J-28.35 E.10248
G1 X151.623 Y128.595 E.8275
G2 X150.357 Y129.602 I2.706 J4.701 E.05385
; WIPE_START
G1 X150.861 Y129.099 E-.27046
G1 X151.623 Y128.595 E-.34714
G1 X151.358 Y128.33 E-.1424
; WIPE_END
G1 E-.04 F1800
G1 X151.166 Y135.537 Z6 F36000
G1 Z5.6
G1 E.8 F1800
G1 F15476.087
G1 X149.693 Y137.011 E.06911
G2 X145.602 Y133.425 I-22.204 J21.211 E.18067
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.323 I24.85 J-22.136 E.11978
G2 X154.34 Y117.012 I-5.149 J3.787 E.06129
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.34 J30.252 E.05401
; WIPE_START
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
; WIPE_END
G1 E-.04 F1800
G1 X134.947 Y125.715 Z6 F36000
G1 X115.627 Y111.14 Z6
G1 Z5.6
G1 E.8 F1800
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.839 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.367 J.128 E.04916
G1 X86.809 Y140.541 E.13381
G1 X90.708 Y142.264 E.14141
G1 X98.937 Y134.035 E.38602
M73 P74 R5
G3 X99.21 Y129.914 I3.62 J-1.829 E.14373
G1 X93.83 Y124.534 E.2524
G2 X90.988 Y126.402 I5.509 J11.477 E.11314
G2 X90.068 Y128.448 I10.56 J5.976 E.07454
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.046 J23.848 E.05401
G1 X88.404 Y132.211 F36000
G1 F15476.087
G3 X87.525 Y133.581 I-17.737 J-10.417 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.659 Y109.989 E1.62445
G2 X127.997 Y109.211 I-4.578 J10.728 E.09221
G2 X125.341 Y109.989 I1.808 J11.102 E.09206
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.225 J-12.696 E.054
; CHANGE_LAYER
; Z_HEIGHT: 5.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
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
G1 X124.322 Y121.263
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X124.333 Y121.246 E.00068
G3 X127.887 Y117.963 I3.677 J.415 E.17494
G3 X129.972 Y118.524 I.131 J3.667 E.0727
G3 X124.31 Y121.659 I-1.962 J3.137 E.50989
G1 X124.32 Y121.323 E.01116
G1 X124.717 Y121.262 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.786 Y120.925 E.01058
G3 X127.91 Y118.354 I3.224 J.734 E.13375
G3 X129.439 Y118.677 I.078 J3.414 E.04845
G3 X124.721 Y121.321 I-1.428 J2.983 E.4439
; WIPE_START
M204 S10000
G1 X124.786 Y120.925 E-.15256
G1 X124.878 Y120.566 E-.1409
G1 X125.02 Y120.223 E-.14104
G1 X125.199 Y119.898 E-.1411
G1 X125.414 Y119.595 E-.14101
G1 X125.49 Y119.51 E-.04338
; WIPE_END
G1 E-.04 F1800
G1 X132.636 Y122.192 Z6.2 F36000
G1 X157.063 Y131.362 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.067 Y131.38 E.00061
G3 X153.044 Y128.524 I-3.609 J.822 E.59229
G1 X153.458 Y128.5 E.01377
G3 X156.952 Y130.981 I0 J3.701 E.15159
G1 X157.046 Y131.304 E.01117
G1 X156.671 Y131.417 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.00157
G3 X153.088 Y128.914 I-3.226 J.734 E.49038
G1 X153.458 Y128.893 E.01141
G3 X156.582 Y131.11 I0 J3.308 E.12552
G1 X156.654 Y131.36 E.00798
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.04227
G1 X156.748 Y131.833 E-.14108
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.14111
G1 X156.583 Y133.297 E-.14104
G1 X156.57 Y133.327 E-.01242
; WIPE_END
G1 E-.04 F1800
G1 X148.967 Y132.657 Z6.2 F36000
G1 X102.114 Y128.527 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.132 Y128.528 E.00062
G3 X102.432 Y128.507 I.417 J3.679 E.00995
G3 X103.876 Y135.655 I.113 J3.697 E.34405
G3 X99.095 Y133.532 I-1.328 J-3.455 E.19267
G3 X98.917 Y131.493 I3.324 J-1.318 E.06889
G3 X101.724 Y128.598 I3.633 J.715 E.14142
G1 X102.055 Y128.537 E.01117
G1 X102.246 Y128.91 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.454 Y128.898 E.00639
G3 X103.983 Y129.221 I.078 J3.414 E.04845
G3 X102.176 Y128.918 I-1.428 J2.983 E.58145
G1 X102.187 Y128.917 E.00031
; WIPE_START
M204 S10000
G1 X102.454 Y128.898 E-.10176
G1 X102.917 Y128.914 E-.17619
G1 X103.283 Y128.976 E-.1411
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.118 Y129.296 E-.05886
; WIPE_END
G1 E-.04 F1800
G1 X111.339 Y131.77 Z6.2 F36000
G1 X155.589 Y146.934 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.721 E2.35649
G1 X83.055 Y139.263 E.6296
G3 X83.411 Y137.866 I3.58 J.167 E.04815
G3 X84.377 Y136.65 I5.975 J3.759 E.05162
G2 X86.79 Y133.986 I-24.728 J-24.815 E.11928
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.305 J7.816 E.0825
G3 X91.435 Y125.548 I2.417 J1.171 E.05121
G3 X93.349 Y124.413 I15.941 J24.687 E.07383
G2 X98.06 Y120.701 I-8.564 J-15.715 E.1999
G2 X100.325 Y117.806 I-37.432 J-31.625 E.12195
G3 X101.394 Y116.758 I3.535 J2.535 E.04992
G3 X103.044 Y116.197 I3.008 J6.141 E.05795
G2 X106.576 Y115.257 I-6.546 J-31.734 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18843
G3 X113.513 Y111.136 I14.719 J18.737 E.08042
G3 X115.145 Y110.777 I1.449 J2.701 E.05612
G3 X117.853 Y110.909 I-7.766 J188.211 E.08995
G2 X124.754 Y109.831 I.851 J-17.189 E.2333
G3 X127.353 Y108.943 I11.105 J28.242 E.09116
G3 X128.184 Y108.872 I.643 J2.632 E.02776
G3 X129.857 Y109.327 I-.985 J6.926 E.05767
G2 X133.389 Y110.477 I12.05 J-30.998 E.12328
G2 X138.729 Y110.881 I3.984 J-17.196 E.17831
G3 X141.237 Y110.779 I2.303 J25.779 E.08329
G3 X142.68 Y111.256 I-.087 J2.685 E.05111
G3 X144.474 Y112.538 I-15.368 J23.398 E.07318
G2 X149.428 Y115.257 I11.081 J-14.314 E.18823
G2 X152.965 Y116.193 I9.839 J-30.04 E.12144
G3 X154.57 Y116.731 I-1.273 J6.461 E.05629
G3 X155.674 Y117.809 I-2.602 J3.771 E.05146
G2 X157.946 Y120.702 I41.977 J-30.623 E.12202
G2 X162.421 Y124.276 I12.716 J-11.334 E.19091
G3 X164.758 Y125.673 I-13.526 J25.263 E.09034
G3 X165.746 Y127.013 I-1.782 J2.349 E.05596
G3 X166.938 Y130.092 I-678.334 J264.536 E.10953
G2 X170.649 Y135.623 I16.058 J-6.762 E.22231
G3 X172.333 Y137.457 I-17.048 J17.341 E.08263
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.195 E2.17924
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.2 J.192 E.05095
G3 X83.717 Y136.795 I3.892 J1.884 E.04099
G2 X85.862 Y134.489 I-444.736 J-415.901 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.437 J7.864 E.07787
G3 X91.212 Y125.226 I2.76 J1.348 E.0533
G3 X93.152 Y124.073 I16.109 J24.916 E.06936
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.337 J-31.524 E.1123
G3 X101.193 Y116.421 I3.821 J2.758 E.05061
G3 X102.951 Y115.816 I3.187 J6.402 E.0573
G2 X106.448 Y114.887 I-6.459 J-31.368 E.11124
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.852 J18.914 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.449 J182.403 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.211 J33.902 E.07783
G3 X128.217 Y108.481 I.983 J3.111 E.03747
G3 X129.989 Y108.957 I-1.008 J7.278 E.05652
G2 X133.481 Y110.096 I11.943 J-30.704 E.11292
G2 X138.707 Y110.489 I3.893 J-16.812 E.16168
G3 X141.261 Y110.387 I2.31 J25.883 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05321
G3 X144.706 Y112.222 I-15.532 J23.675 E.06879
G2 X149.556 Y114.887 I10.852 J-14.004 E.17076
G2 X153.056 Y115.812 I9.716 J-29.684 E.11131
G3 X154.77 Y116.394 I-1.341 J6.762 E.05578
G3 X155.765 Y117.301 I-2.181 J3.391 E.04155
G2 X157.819 Y119.952 I1385.317 J-1071.087 E.10304
G2 X162.618 Y123.937 I12.924 J-10.683 E.19281
G3 X164.784 Y125.21 I-16.311 J30.221 E.0772
G3 X166.104 Y126.854 I-1.827 J2.82 E.06589
G3 X167.3 Y129.94 I-591.021 J230.774 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.226 J17.512 E.07792
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38731
G1 X154.608 Y145.61 E-.07071
; WIPE_END
G1 E-.04 F1800
G1 X152.65 Y138.233 Z6.2 F36000
G1 X150.358 Y129.602 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X151.623 Y128.595 I3.988 J3.716 E.05383
G1 X133.984 Y110.956 E.8275
G2 X137.055 Y111.268 I4.403 J-28.037 E.10248
G1 X130.118 Y118.206 E.32547
G2 X125.884 Y118.208 I-2.116 J3.614 E.14725
G1 X118.944 Y111.268 E.32555
G2 X122.015 Y110.957 I-1.316 J-28.288 E.10243
G1 X104.378 Y128.594 E.82736
G3 X105.644 Y129.599 I-2.72 J4.725 E.05383
; WIPE_START
G1 X105.073 Y129.035 E-.30504
G1 X104.378 Y128.594 E-.31276
G1 X104.643 Y128.329 E-.1422
; WIPE_END
G1 E-.04 F1800
G1 X104.835 Y135.539 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
G1 F15476.087
G1 X106.309 Y137.013 E.06913
G3 X110.399 Y133.428 I23.05 J22.168 E.18065
G1 X98.118 Y121.146 E.57613
G2 X100.796 Y117.778 I-30.116 J-26.694 E.14281
G3 X101.665 Y117.017 I2.26 J1.7 E.03858
G1 X115.224 Y130.576 E.6361
G2 X113.77 Y131.309 I14.295 J30.151 E.05401
G1 X125.655 Y124.954 F36000
G1 F15476.087
G3 X124.549 Y123.775 I2.425 J-3.381 E.05396
G1 X119.326 Y128.997 E.24502
G3 X120.891 Y128.567 I10.051 J33.499 E.05383
G1 X107.571 Y115.247 E.62487
G2 X112.36 Y112.361 I-8.188 J-19.002 E.18607
G1 X127.713 Y127.714 E.72024
G3 X128.286 Y127.714 I.288 J8.198 E.019
G1 X143.638 Y112.362 E.72019
G2 X148.43 Y115.246 I13.081 J-16.311 E.18608
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.447 J33.813 E.05372
G1 X131.454 Y123.778 E.24476
G3 X130.347 Y124.956 I-3.533 J-2.21 E.05396
G1 X142.231 Y131.307 F36000
G1 F15476.087
G2 X140.777 Y130.574 I-15.8 J29.531 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.634 Y118.324 I-3.859 J5.1 E.06133
G2 X157.884 Y121.144 I27.088 J-19.306 E.11974
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-18.114 J24.796 E.18067
G1 X151.166 Y135.537 E.06911
; WIPE_START
G1 X149.752 Y136.952 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X157.128 Y134.991 Z6.2 F36000
G1 X167.597 Y132.209 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F15476.087
G2 X168.477 Y133.578 I19.131 J-11.343 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X125.341 Y109.989 E1.62449
G3 X127.995 Y109.211 I4.477 J10.361 E.092
G3 X130.66 Y109.988 I-1.548 J10.267 E.09235
G1 X96.032 Y144.616 E1.62448
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.832 J-11.77 E.054
G1 X102.064 Y142.685 F36000
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.25 J11.558 E.05398
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.926 J1.552 E.0865
G3 X93.83 Y124.534 I9.843 J12.992 E.10129
G1 X99.21 Y129.914 E.25241
G2 X98.937 Y134.035 I3.347 J2.292 E.14373
G1 X90.708 Y142.264 E.38602
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.1338
G2 X83.434 Y139.05 I1.841 J1.487 E.04916
G1 X85.385 Y139.911 E.07073
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.7 E.05406
G1 X140.386 Y111.134 F36000
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.38 E.05407
G1 X170.616 Y139.912 E1.34273
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.418 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X157.066 Y134.038 E.38591
G2 X156.792 Y129.911 I-3.618 J-1.833 E.14398
G1 X162.172 Y124.532 E.25237
G3 X164.985 Y126.364 I-5.412 J11.382 E.11169
G3 X165.932 Y128.447 I-10.691 J6.121 E.07603
G1 X153.083 Y141.297 E.6028
G3 X153.939 Y142.682 I-19.42 J12.96 E.05402
; CHANGE_LAYER
; Z_HEIGHT: 6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
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
G1 X124.322 Y121.263
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X124.334 Y121.246 E.00071
G3 X127.864 Y117.964 I3.677 J.415 E.17413
G3 X129.972 Y118.524 I.155 J3.664 E.07346
G3 X124.311 Y121.659 I-1.962 J3.137 E.50988
G1 X124.32 Y121.323 E.01115
G1 X124.717 Y121.265 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.787 Y120.925 E.01066
G3 X127.886 Y118.355 I3.225 J.736 E.13302
G3 X129.439 Y118.677 I.106 J3.399 E.04916
G3 X124.721 Y121.324 I-1.427 J2.984 E.44399
; WIPE_START
M204 S10000
G1 X124.787 Y120.925 E-.15348
G1 X124.878 Y120.566 E-.1409
G1 X125.02 Y120.223 E-.14104
G1 X125.199 Y119.898 E-.1411
G1 X125.414 Y119.595 E-.14101
G1 X125.489 Y119.512 E-.04246
; WIPE_END
G1 E-.04 F1800
G1 X132.634 Y122.194 Z6.4 F36000
G1 X157.063 Y131.361 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.066 Y131.38 E.00062
G3 X153.044 Y128.524 I-3.608 J.821 E.59206
G1 X153.458 Y128.5 E.01377
G3 X156.952 Y130.981 I0 J3.7 E.15157
G1 X157.046 Y131.304 E.01117
G1 X156.673 Y131.423 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.0014
G3 X153.088 Y128.914 I-3.225 J.734 E.49027
G1 X153.458 Y128.893 E.01141
G3 X156.581 Y131.111 I0 J3.308 E.12552
G1 X156.656 Y131.365 E.00815
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.04014
G1 X156.748 Y131.833 E-.14107
M73 P75 R4
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.14111
G1 X156.583 Y133.297 E-.14104
G1 X156.568 Y133.332 E-.01455
; WIPE_END
G1 E-.04 F1800
G1 X148.965 Y132.661 Z6.4 F36000
G1 X102.114 Y128.527 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.133 Y128.529 E.00063
G3 X102.408 Y128.508 I.422 J3.676 E.00918
G3 X104.517 Y129.068 I.155 J3.664 E.07346
G3 X101.724 Y128.6 I-1.962 J3.137 E.67481
G1 X102.055 Y128.538 E.01116
G1 X102.242 Y128.91 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.431 Y128.899 E.00579
G3 X103.983 Y129.221 I.106 J3.398 E.04916
G3 X102.176 Y128.919 I-1.427 J2.984 E.58159
G1 X102.183 Y128.918 E.0002
; WIPE_START
M204 S10000
G1 X102.431 Y128.899 E-.09434
G1 X102.917 Y128.914 E-.18496
G1 X103.283 Y128.976 E-.1411
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.115 Y129.294 E-.0575
; WIPE_END
G1 E-.04 F1800
G1 X111.335 Y131.768 Z6.4 F36000
G1 X155.589 Y146.934 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.72 E2.35654
G1 X83.055 Y139.263 E.6296
G3 X83.411 Y137.865 I3.578 J.167 E.04816
G3 X84.377 Y136.65 I5.974 J3.759 E.0516
G2 X86.79 Y133.985 I-24.729 J-24.816 E.1193
G2 X89.501 Y128.988 I-13.845 J-10.746 E.18944
G3 X90.41 Y126.674 I23.322 J7.822 E.0825
G3 X91.436 Y125.548 I2.418 J1.171 E.05123
G3 X93.349 Y124.413 I15.958 J24.716 E.07381
G2 X98.06 Y120.701 I-8.564 J-15.715 E.19989
G2 X100.325 Y117.806 I-37.408 J-31.607 E.12197
G3 X101.394 Y116.758 I3.536 J2.536 E.04991
G3 X103.044 Y116.197 I3.009 J6.144 E.05797
G2 X106.576 Y115.257 I-6.544 J-31.725 E.12132
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18843
G3 X113.513 Y111.136 I14.724 J18.743 E.0804
G3 X115.145 Y110.777 I1.449 J2.7 E.05613
G3 X117.853 Y110.909 I-7.766 J188.211 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.097 J28.218 E.09117
G3 X128.184 Y108.872 I.643 J2.632 E.02776
G3 X129.857 Y109.327 I-.985 J6.926 E.05768
G2 X133.389 Y110.477 I12.069 J-31.058 E.12328
G2 X138.729 Y110.881 I3.984 J-17.198 E.17831
G3 X141.236 Y110.779 I2.303 J25.779 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.38 J23.414 E.07316
G2 X149.428 Y115.257 I11.08 J-14.313 E.18822
G2 X152.965 Y116.193 I9.835 J-30.026 E.12145
G3 X154.586 Y116.741 I-1.221 J6.285 E.05693
G3 X155.674 Y117.809 I-2.65 J3.788 E.05082
G2 X157.946 Y120.702 I41.975 J-30.621 E.12204
G2 X162.422 Y124.276 I12.716 J-11.335 E.1909
G3 X164.757 Y125.673 I-13.522 J25.256 E.09032
G3 X165.746 Y127.013 I-1.782 J2.349 E.05597
G3 X166.938 Y130.092 I-684.55 J266.945 E.10953
G2 X170.649 Y135.623 I16.057 J-6.761 E.22232
G3 X172.333 Y137.457 I-17.039 J17.332 E.08262
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.201 E2.17906
G1 X82.639 Y139.508 E.60452
G3 X82.938 Y137.942 I5.391 J.218 E.04915
G3 X83.717 Y136.795 I3.819 J1.755 E.04279
G2 X85.862 Y134.489 I-443.977 J-415.196 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.444 J7.866 E.07787
G3 X91.212 Y125.225 I2.76 J1.348 E.05331
G3 X93.152 Y124.073 I16.126 J24.947 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.338 J-31.525 E.1123
G3 X101.193 Y116.421 I3.822 J2.758 E.05061
G3 X102.951 Y115.816 I3.188 J6.405 E.0573
G2 X106.448 Y114.887 I-6.458 J-31.366 E.11123
G2 X111.301 Y112.219 I-5.848 J-16.383 E.1709
G3 X113.32 Y110.795 I14.851 J18.913 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.449 J182.403 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.206 J33.888 E.07783
G3 X128.217 Y108.481 I.983 J3.11 E.03747
G3 X129.989 Y108.958 I-1.008 J7.28 E.05654
G2 X133.481 Y110.096 I11.956 J-30.748 E.1129
G2 X138.707 Y110.489 I3.893 J-16.814 E.16168
G3 X141.261 Y110.387 I2.31 J25.883 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05322
G3 X144.706 Y112.222 I-15.541 J23.687 E.06878
G2 X149.556 Y114.887 I10.852 J-14.004 E.17076
G2 X153.056 Y115.812 I9.714 J-29.676 E.1113
G3 X154.788 Y116.405 I-1.292 J6.597 E.05642
G3 X155.981 Y117.565 I-2.826 J4.099 E.05136
G2 X158.239 Y120.441 I41.907 J-30.568 E.11239
G2 X162.619 Y123.937 I12.424 J-11.075 E.17301
G3 X164.784 Y125.21 I-16.287 J30.179 E.0772
G3 X166.104 Y126.854 I-1.827 J2.82 E.06588
G3 X167.3 Y129.94 I-593.054 J231.563 E.1017
G2 X170.934 Y135.354 I15.7 J-6.612 E.2016
G3 X172.646 Y137.222 I-17.226 J17.51 E.07791
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.395 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.276 J11.575 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.654 J1.407 E.08775
G2 X162.172 Y124.532 I-25.065 J37.934 E.10007
G1 X156.792 Y129.911 E.25237
G3 X157.066 Y134.038 I-3.344 J2.294 E.14398
G1 X165.292 Y142.265 E.38591
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.908 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34273
G2 X140.386 Y111.134 I-1.124 J3.223 E.05407
G1 X130.347 Y124.956 F36000
G1 F15476.087
G2 X131.454 Y123.778 I-2.426 J-3.388 E.05396
G1 X136.671 Y128.995 E.24476
G2 X135.109 Y128.566 I-10.009 J33.387 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.645 Y112.355 I8.086 J-18.793 E.18603
G1 X128.286 Y127.714 E.7205
G2 X127.713 Y127.714 I-.285 J8.198 E.019
G1 X112.36 Y112.361 E.72024
G3 X107.571 Y115.247 I-12.978 J-16.116 E.18607
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.486 J33.929 E.05383
G1 X124.549 Y123.775 E.24502
G2 X125.655 Y124.954 I3.531 J-2.203 E.05396
G1 X113.77 Y131.309 F36000
G1 F15476.087
G3 X115.224 Y130.576 I15.758 J29.436 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.778 I1.392 J2.463 E.03858
G3 X98.118 Y121.146 I-32.798 J-23.329 E.14281
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.736 J27.777 E.18055
G1 X104.835 Y135.539 E.06913
; WIPE_START
G1 X106.25 Y136.954 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.644 Y129.599 Z6.4 F36000
G1 Z6
G1 E.8 F1800
G1 F15476.087
G2 X104.378 Y128.594 I-3.986 J3.72 E.05383
G1 X122.015 Y110.957 E.82736
G3 X118.944 Y111.268 I-4.387 J-27.978 E.10243
G1 X125.884 Y118.208 E.32555
G3 X130.118 Y118.206 I2.119 J3.612 E.14725
G1 X137.055 Y111.268 E.32547
G3 X133.984 Y110.956 I1.33 J-28.344 E.10248
G1 X151.623 Y128.595 E.8275
G2 X150.357 Y129.602 I2.699 J4.693 E.05385
; WIPE_START
G1 X150.825 Y129.131 E-.2524
G1 X151.623 Y128.595 E-.36511
G1 X151.358 Y128.33 E-.14249
; WIPE_END
G1 E-.04 F1800
G1 X151.166 Y135.537 Z6.4 F36000
G1 Z6
G1 E.8 F1800
G1 F15476.087
G1 X149.693 Y137.011 E.06911
G2 X145.602 Y133.425 I-22.205 J21.212 E.18067
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.324 I24.845 J-22.132 E.11974
G2 X154.34 Y117.012 I-5.154 J3.79 E.06133
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.346 J30.264 E.05401
; WIPE_START
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
; WIPE_END
G1 E-.04 F1800
G1 X134.947 Y125.715 Z6.4 F36000
G1 X115.627 Y111.14 Z6.4
G1 Z6
G1 E.8 F1800
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.843 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.367 J.128 E.04916
G1 X86.809 Y140.541 E.1338
G1 X90.708 Y142.264 E.14141
G1 X98.937 Y134.035 E.38602
G3 X99.21 Y129.914 I3.62 J-1.829 E.14373
G1 X93.83 Y124.534 E.25241
G2 X90.988 Y126.402 I5.508 J11.475 E.11314
G2 X90.068 Y128.448 I10.573 J5.982 E.07454
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.046 J23.848 E.05401
G1 X88.404 Y132.211 F36000
G1 F15476.087
G3 X87.525 Y133.581 I-17.723 J-10.408 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.66 Y109.988 E1.62448
G2 X127.994 Y109.211 I-4.203 J9.463 E.0924
G2 X125.341 Y109.989 I1.834 J11.169 E.09194
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.224 J-12.695 E.054
; CHANGE_LAYER
; Z_HEIGHT: 6.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
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
G1 X124.322 Y121.263
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X124.328 Y121.245 E.00064
G3 X127.841 Y117.965 I3.674 J.414 E.17355
G3 X129.374 Y125.093 I.161 J3.694 E.34402
G3 X124.305 Y121.659 I-1.372 J-3.434 E.23928
G1 X124.319 Y121.323 E.01115
G1 X124.716 Y121.268 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.786 Y120.925 E.01075
G3 X127.863 Y118.357 I3.225 J.736 E.13232
G3 X129.764 Y118.856 I.155 J3.273 E.06132
G3 X124.72 Y121.326 I-1.753 J2.805 E.43246
; WIPE_START
M204 S10000
G1 X124.786 Y120.925 E-.15462
G1 X124.878 Y120.566 E-.14091
G1 X125.02 Y120.223 E-.14104
G1 X125.199 Y119.898 E-.1411
G1 X125.414 Y119.595 E-.14101
G1 X125.487 Y119.514 E-.04132
; WIPE_END
G1 E-.04 F1800
G1 X132.633 Y122.195 Z6.6 F36000
G1 X157.063 Y131.361 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.066 Y131.38 E.00062
G3 X153.044 Y128.524 I-3.608 J.821 E.59206
G3 X154.526 Y128.663 I.41 J3.587 E.04976
G1 X154.681 Y128.708 E.00535
G3 X156.952 Y130.981 I-1.223 J3.492 E.11024
G1 X157.046 Y131.304 E.01116
G1 X156.674 Y131.428 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.00123
G3 X153.088 Y128.914 I-3.225 J.734 E.49027
G3 X154.418 Y129.04 I.366 J3.208 E.04135
G1 X154.552 Y129.079 E.00428
G3 X156.581 Y131.11 I-1.093 J3.122 E.09128
G1 X156.657 Y131.371 E.00833
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.03799
G1 X156.748 Y131.833 E-.14107
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.1411
G1 X156.583 Y133.297 E-.14104
G1 X156.566 Y133.337 E-.0167
; WIPE_END
G1 E-.04 F1800
G1 X148.963 Y132.664 Z6.6 F36000
G1 X102.151 Y128.522 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.385 Y128.509 E.0078
G3 X104.855 Y129.308 I.155 J3.739 E.08794
G3 X102.092 Y128.534 I-2.301 J2.897 E.67343
G1 X102.239 Y128.91 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.407 Y128.901 E.00519
G3 X104.308 Y129.4 I.155 J3.273 E.06132
G3 X102.176 Y128.919 I-1.753 J2.805 E.57017
G1 X102.179 Y128.919 E.00009
; WIPE_START
M204 S10000
G1 X102.407 Y128.901 E-.08689
G1 X102.917 Y128.914 E-.19374
G1 X103.283 Y128.976 E-.1411
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.112 Y129.292 E-.05618
; WIPE_END
G1 E-.04 F1800
G1 X111.332 Y131.767 Z6.6 F36000
G1 X155.589 Y146.934 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.975 J3.76 E.05161
G2 X86.79 Y133.986 I-24.732 J-24.818 E.11928
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18946
G3 X90.41 Y126.674 I23.298 J7.813 E.08251
G3 X91.436 Y125.548 I2.417 J1.171 E.05123
G3 X93.348 Y124.413 I15.952 J24.707 E.07379
G2 X98.059 Y120.702 I-8.564 J-15.716 E.19989
G2 X100.324 Y117.807 I-37.396 J-31.598 E.12196
G3 X101.394 Y116.758 I3.537 J2.536 E.04995
G3 X103.043 Y116.197 I3.009 J6.145 E.05794
G2 X106.577 Y115.257 I-6.541 J-31.716 E.12135
G2 X111.534 Y112.534 I-5.974 J-16.747 E.1884
G3 X113.513 Y111.136 I14.721 J18.738 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05614
G3 X117.853 Y110.909 I-7.766 J188.209 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.354 Y108.943 I11.101 J28.231 E.09117
G3 X128.184 Y108.872 I.643 J2.632 E.02776
G3 X129.857 Y109.327 I-.985 J6.925 E.05767
G2 X133.389 Y110.477 I12.084 J-31.102 E.12329
G2 X138.729 Y110.881 I3.984 J-17.196 E.17831
G3 X141.236 Y110.779 I2.303 J25.779 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.379 J23.411 E.07316
G2 X149.427 Y115.257 I11.081 J-14.314 E.18821
G2 X152.965 Y116.193 I9.836 J-30.027 E.12147
G3 X154.57 Y116.731 I-1.249 J6.387 E.0563
G3 X155.674 Y117.809 I-2.604 J3.773 E.05145
G2 X157.946 Y120.702 I41.968 J-30.615 E.12201
G2 X162.422 Y124.276 I12.716 J-11.334 E.19092
G3 X164.758 Y125.674 I-13.517 J25.247 E.09035
G3 X165.746 Y127.012 I-1.782 J2.348 E.05593
G3 X166.938 Y130.091 I-672.809 J262.401 E.10954
G2 X170.649 Y135.623 I16.059 J-6.762 E.22234
G3 X172.333 Y137.457 I-17.042 J17.335 E.08262
G3 X172.913 Y139.008 I-2.311 J1.749 E.0557
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.199 J.192 E.05096
G3 X83.717 Y136.795 I3.892 J1.884 E.04099
G2 X85.862 Y134.489 I-443.11 J-414.391 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.428 J7.86 E.07788
G3 X91.213 Y125.225 I2.76 J1.348 E.0533
G3 X93.152 Y124.073 I16.125 J24.945 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.017 Y117.563 I-37.324 J-31.514 E.11228
M73 P76 R4
G3 X101.193 Y116.421 I3.822 J2.758 E.05063
G3 X102.951 Y115.816 I3.188 J6.406 E.0573
G2 X106.449 Y114.887 I-6.456 J-31.356 E.11125
G2 X111.301 Y112.219 I-5.848 J-16.382 E.17088
G3 X113.32 Y110.795 I14.854 J18.916 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05819
G3 X117.867 Y110.517 I-7.449 J182.402 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21158
G3 X127.013 Y108.625 I13.206 J33.889 E.07783
G3 X128.217 Y108.481 I.983 J3.111 E.03748
G3 X129.989 Y108.957 I-1.008 J7.279 E.05652
G2 X133.481 Y110.096 I11.974 J-30.799 E.11292
G2 X138.707 Y110.489 I3.893 J-16.812 E.16168
G3 X141.261 Y110.387 I2.31 J25.883 E.07855
G3 X142.885 Y110.921 I-.11 J3.071 E.05323
G3 X144.706 Y112.222 I-15.537 J23.682 E.06878
G2 X149.556 Y114.887 I10.852 J-14.004 E.17075
G2 X153.057 Y115.812 I9.716 J-29.682 E.11132
G3 X154.771 Y116.394 I-1.318 J6.693 E.05578
G3 X155.765 Y117.3 I-2.18 J3.39 E.04153
G2 X157.819 Y119.952 I1373.717 J-1062.116 E.10308
G2 X162.619 Y123.937 I12.924 J-10.684 E.1928
G3 X164.784 Y125.21 I-16.279 J30.166 E.0772
G3 X166.104 Y126.854 I-1.827 J2.82 E.06588
G3 X167.3 Y129.94 I-591.915 J231.12 E.1017
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.647 Y137.222 I-17.227 J17.512 E.07793
G3 X173.302 Y138.956 I-2.618 J1.98 E.05775
G3 X173.36 Y139.508 I-10.366 J1.37 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38731
G1 X154.608 Y145.61 E-.07071
; WIPE_END
G1 E-.04 F1800
G1 X152.65 Y138.233 Z6.6 F36000
G1 X150.358 Y129.602 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X151.623 Y128.595 I3.096 J2.594 E.05399
G1 X133.984 Y110.956 E.8275
G2 X137.055 Y111.268 I4.402 J-28.035 E.10248
G1 X130.118 Y118.206 E.32547
G2 X125.884 Y118.208 I-2.116 J3.466 E.14775
G1 X118.944 Y111.268 E.32555
G2 X122.015 Y110.957 I-1.316 J-28.286 E.10243
G1 X104.378 Y128.594 E.82736
G3 X105.644 Y129.599 I-2.719 J4.724 E.05383
; WIPE_START
G1 X105.073 Y129.035 E-.30507
G1 X104.378 Y128.594 E-.31273
G1 X104.643 Y128.329 E-.1422
; WIPE_END
G1 E-.04 F1800
G1 X104.835 Y135.539 Z6.6 F36000
G1 Z6.2
G1 E.8 F1800
G1 F15476.087
G1 X106.309 Y137.013 E.06913
G3 X110.399 Y133.428 I22.212 J21.213 E.18067
G1 X98.118 Y121.147 E.57613
G2 X100.797 Y117.778 I-30.141 J-26.714 E.14283
G3 X101.665 Y117.017 I2.259 J1.701 E.03856
G1 X115.224 Y130.576 E.63609
G2 X113.77 Y131.309 I14.302 J30.165 E.05401
G1 X125.655 Y124.954 F36000
G1 F15476.087
G3 X124.549 Y123.775 I2.426 J-3.382 E.05396
G1 X119.326 Y128.997 E.24501
G3 X120.891 Y128.567 I10.052 J33.506 E.05383
G1 X107.571 Y115.247 E.62487
G2 X112.36 Y112.361 I-8.188 J-19.003 E.18607
G1 X127.713 Y127.714 E.72024
G3 X128.286 Y127.714 I.288 J8.19 E.019
G1 X143.645 Y112.355 E.7205
G2 X148.43 Y115.246 I12.871 J-15.901 E.18603
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.448 J33.816 E.05372
G1 X131.454 Y123.778 E.24476
G3 X130.347 Y124.956 I-3.533 J-2.21 E.05396
G1 X142.231 Y131.307 F36000
G1 F15476.087
G2 X140.777 Y130.574 I-15.794 J29.519 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.633 Y118.324 I-3.855 J5.096 E.06132
G2 X157.884 Y121.144 I27.088 J-19.305 E.11975
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-18.113 J24.795 E.18067
G1 X151.166 Y135.537 E.06911
; WIPE_START
G1 X149.752 Y136.952 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X157.128 Y134.991 Z6.6 F36000
G1 X167.597 Y132.209 Z6.6
G1 Z6.2
G1 E.8 F1800
G1 F15476.087
G2 X168.477 Y133.578 I19.106 J-11.327 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X125.341 Y109.989 E1.62449
G3 X127.992 Y109.211 I4.498 J10.423 E.09189
G3 X130.66 Y109.988 I-1.527 J10.214 E.09246
G1 X96.032 Y144.616 E1.62448
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.832 J-11.77 E.054
G1 X102.064 Y142.685 F36000
G1 F15476.087
G1 X102.064 Y142.684 E.00004
G3 X102.92 Y141.3 I20.237 J11.55 E.05398
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.926 J1.552 E.08649
G3 X93.83 Y124.534 I9.837 J12.981 E.1013
G1 X99.21 Y129.914 E.2524
G2 X98.937 Y134.035 I3.492 J2.301 E.14328
G1 X90.708 Y142.264 E.38602
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.1338
G2 X83.434 Y139.05 I1.841 J1.487 E.04916
G1 X85.385 Y139.911 E.07073
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.701 E.05406
G1 X140.386 Y111.134 F36000
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.379 E.05407
G1 X170.616 Y139.912 E1.34272
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.418 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X157.066 Y134.038 E.38591
G2 X156.792 Y129.911 I-3.759 J-1.823 E.14353
G1 X162.172 Y124.532 E.25237
G3 X164.985 Y126.364 I-5.411 J11.381 E.11169
G3 X165.932 Y128.447 I-10.696 J6.123 E.07602
G1 X153.083 Y141.297 E.6028
G3 X153.939 Y142.682 I-19.42 J12.96 E.05402
; CHANGE_LAYER
; Z_HEIGHT: 6.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
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
G1 X124.321 Y121.263
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X124.323 Y121.244 E.00063
G3 X127.818 Y117.966 I3.672 J.413 E.17295
G3 X126.566 Y125.066 I.184 J3.693 E.44034
G3 X124.299 Y121.659 I1.429 J-3.408 E.14385
G1 X124.318 Y121.323 E.01116
G1 X124.716 Y121.271 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.786 Y120.925 E.01083
G3 X127.84 Y118.358 I3.225 J.736 E.13159
G3 X129.764 Y118.856 I.179 J3.272 E.06203
G3 X124.72 Y121.329 I-1.753 J2.805 E.43238
; WIPE_START
M204 S10000
G1 X124.786 Y120.925 E-.15543
G1 X124.878 Y120.566 E-.14091
G1 X125.02 Y120.223 E-.14103
G1 X125.199 Y119.898 E-.1411
G1 X125.414 Y119.595 E-.14101
G1 X125.485 Y119.516 E-.04051
; WIPE_END
G1 E-.04 F1800
G1 X132.631 Y122.196 Z6.8 F36000
G1 X157.063 Y131.361 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.067 Y131.38 E.00063
G3 X153.044 Y128.524 I-3.609 J.822 E.59229
G1 X153.458 Y128.5 E.01377
G3 X156.952 Y130.981 I0 J3.701 E.15159
G1 X157.046 Y131.303 E.01115
G1 X156.676 Y131.433 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.00107
G3 X153.088 Y128.914 I-3.226 J.735 E.49048
G1 X153.458 Y128.893 E.01141
G3 X156.582 Y131.11 I0 J3.309 E.12553
G1 X156.659 Y131.375 E.00849
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.03605
G1 X156.748 Y131.833 E-.14109
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.1411
G1 X156.583 Y133.297 E-.14104
G1 X156.564 Y133.342 E-.01863
; WIPE_END
G1 E-.04 F1800
G1 X148.961 Y132.67 Z6.8 F36000
G1 X102.113 Y128.527 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.133 Y128.53 E.00065
G3 X102.362 Y128.511 I.422 J3.676 E.00764
G3 X104.855 Y129.308 I.179 J3.736 E.0887
G3 X101.724 Y128.6 I-2.301 J2.897 E.661
G1 X102.054 Y128.538 E.01115
G1 X102.236 Y128.91 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.384 Y128.902 E.00457
G3 X104.308 Y129.4 I.179 J3.271 E.06203
G3 X102.176 Y128.919 I-1.753 J2.805 E.57013
; WIPE_START
M204 S10000
G1 X102.384 Y128.902 E-.07925
G1 X102.546 Y128.893 E-.06173
G1 X102.917 Y128.914 E-.14105
G1 X103.283 Y128.976 E-.1411
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.109 Y129.29 E-.05477
; WIPE_END
G1 E-.04 F1800
G1 X111.329 Y131.765 Z6.8 F36000
G1 X155.589 Y146.934 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.721 E2.35648
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.974 J3.759 E.0516
G2 X86.79 Y133.985 I-24.734 J-24.82 E.11932
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18943
G3 X90.41 Y126.674 I23.301 J7.815 E.08251
G3 X91.435 Y125.548 I2.417 J1.171 E.0512
G3 X93.349 Y124.413 I15.938 J24.681 E.07383
G2 X98.059 Y120.702 I-8.564 J-15.715 E.19987
G2 X100.325 Y117.806 I-37.403 J-31.604 E.12198
G3 X101.394 Y116.757 I3.535 J2.535 E.04994
G3 X103.044 Y116.197 I3.009 J6.144 E.05795
G2 X106.577 Y115.257 I-6.544 J-31.726 E.12134
G2 X111.534 Y112.534 I-5.974 J-16.747 E.18841
G3 X113.513 Y111.136 I14.73 J18.752 E.0804
G3 X115.145 Y110.777 I1.449 J2.701 E.05614
G3 X117.853 Y110.909 I-7.765 J188.192 E.08995
G2 X124.754 Y109.831 I.851 J-17.19 E.2333
G3 X127.354 Y108.943 I11.097 J28.218 E.09117
G3 X128.184 Y108.872 I.643 J2.631 E.02776
G3 X129.857 Y109.327 I-.985 J6.925 E.05766
G2 X133.389 Y110.477 I12.221 J-31.522 E.12329
G2 X138.729 Y110.881 I3.984 J-17.198 E.17831
G3 X141.237 Y110.779 I2.303 J25.77 E.08329
G3 X142.68 Y111.256 I-.087 J2.685 E.05112
G3 X144.474 Y112.538 I-15.377 J23.41 E.07317
G2 X149.428 Y115.257 I11.081 J-14.315 E.18823
G2 X152.966 Y116.193 I9.84 J-30.044 E.12147
G3 X154.583 Y116.739 I-1.252 J6.378 E.05678
G3 X155.674 Y117.809 I-2.641 J3.785 E.05095
G2 X157.946 Y120.702 I41.964 J-30.613 E.12201
G2 X162.421 Y124.276 I12.716 J-11.334 E.1909
G3 X164.758 Y125.674 I-13.532 J25.273 E.09035
G3 X165.746 Y127.013 I-1.782 J2.349 E.05596
G3 X166.938 Y130.092 I-676.176 J263.702 E.10953
G2 X170.649 Y135.623 I16.057 J-6.761 E.22232
G3 X172.333 Y137.457 I-17.048 J17.341 E.08261
G3 X172.913 Y139.008 I-2.311 J1.749 E.05572
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.199 E2.17913
G1 X82.639 Y139.508 E.60452
G3 X82.936 Y137.946 I5.408 J.221 E.04903
G3 X83.717 Y136.795 I3.818 J1.749 E.04293
G2 X85.862 Y134.489 I-444.242 J-415.445 E.09676
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.435 J7.863 E.07788
G3 X91.212 Y125.226 I2.76 J1.348 E.0533
G3 X93.152 Y124.073 I16.124 J24.942 E.06936
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.018 Y117.563 I-37.34 J-31.527 E.1123
G3 X101.193 Y116.421 I3.821 J2.758 E.05062
G3 X102.951 Y115.816 I3.187 J6.403 E.05729
G2 X106.449 Y114.887 I-6.459 J-31.367 E.11125
G2 X111.301 Y112.218 I-5.849 J-16.382 E.17089
G3 X113.32 Y110.795 I14.853 J18.916 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.448 J182.386 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21158
G3 X127.013 Y108.625 I13.201 J33.875 E.07784
G3 X128.217 Y108.481 I.982 J3.11 E.03747
G3 X129.989 Y108.957 I-1.008 J7.279 E.05652
G2 X133.481 Y110.096 I12.11 J-31.218 E.11291
G2 X138.707 Y110.489 I3.893 J-16.812 E.16168
G3 X141.261 Y110.387 I2.31 J25.879 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05322
G3 X144.706 Y112.222 I-15.537 J23.681 E.06878
G2 X149.556 Y114.887 I10.852 J-14.005 E.17076
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.704 Y116.356 I-1.359 J6.874 E.05344
G3 X155.765 Y117.3 I-1.908 J3.212 E.0439
G2 X157.819 Y119.952 I1373.717 J-1062.116 E.10308
G2 X162.618 Y123.937 I12.924 J-10.684 E.19279
G3 X164.784 Y125.21 I-16.318 J30.232 E.0772
G3 X166.104 Y126.854 I-1.827 J2.82 E.06589
G3 X167.3 Y129.94 I-591.722 J231.047 E.1017
G2 X170.934 Y135.354 I15.7 J-6.612 E.2016
G3 X172.646 Y137.222 I-17.234 J17.518 E.0779
G3 X173.302 Y138.956 I-2.618 J1.981 E.05776
G3 X173.36 Y139.508 I-10.393 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38731
G1 X154.608 Y145.61 E-.07071
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z6.8 F36000
G1 Z6.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.245 J11.556 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.653 J1.407 E.08776
G2 X162.172 Y124.532 I-25.067 J37.94 E.10007
G1 X156.792 Y129.911 E.25237
G3 X157.066 Y134.038 I-3.485 J2.304 E.14353
G1 X165.292 Y142.265 E.38591
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.907 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34272
G2 X140.386 Y111.134 I-1.124 J3.223 E.05407
G1 X130.347 Y124.956 F36000
G1 F15476.087
G2 X131.454 Y123.778 I-2.426 J-3.388 E.05396
G1 X136.671 Y128.995 E.24476
G2 X135.109 Y128.566 I-10.004 J33.367 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.645 Y112.355 I8.084 J-18.789 E.18603
G1 X128.286 Y127.714 E.7205
G2 X127.713 Y127.714 I-.285 J8.19 E.019
G1 X112.36 Y112.361 E.72024
G3 X107.571 Y115.247 I-12.978 J-16.116 E.18607
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.488 J33.936 E.05383
G1 X124.549 Y123.775 E.24502
G2 X125.655 Y124.954 I3.531 J-2.202 E.05396
G1 X113.77 Y131.309 F36000
G1 F15476.087
G3 X115.224 Y130.576 I15.758 J29.436 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.796 Y117.779 I1.392 J2.463 E.0386
G3 X98.118 Y121.147 I-32.811 J-23.339 E.14279
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I18.108 J24.777 E.1806
G1 X104.835 Y135.539 E.06914
; WIPE_START
G1 X106.25 Y136.954 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.644 Y129.599 Z6.8 F36000
M73 P77 R4
G1 Z6.4
G1 E.8 F1800
G1 F15476.087
G2 X104.378 Y128.594 I-3.985 J3.719 E.05383
G1 X122.015 Y110.957 E.82736
G3 X118.944 Y111.268 I-4.388 J-27.98 E.10243
G1 X125.884 Y118.208 E.32555
G3 X130.118 Y118.206 I2.119 J3.466 E.14774
G1 X137.055 Y111.268 E.32546
G3 X133.984 Y110.956 I1.331 J-28.35 E.10248
G1 X151.623 Y128.595 E.8275
G2 X150.358 Y129.602 I2.722 J4.721 E.05383
; WIPE_START
G1 X150.932 Y129.035 E-.30645
G1 X151.623 Y128.595 E-.31135
G1 X151.358 Y128.331 E-.1422
; WIPE_END
G1 E-.04 F1800
G1 X151.166 Y135.537 Z6.8 F36000
G1 Z6.4
G1 E.8 F1800
G1 F15476.087
G1 X149.693 Y137.011 E.06911
G2 X145.602 Y133.425 I-22.204 J21.211 E.18067
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.323 I24.84 J-22.128 E.11976
G2 X154.34 Y117.012 I-5.154 J3.79 E.06131
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.34 J30.252 E.05401
; WIPE_START
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
; WIPE_END
G1 E-.04 F1800
G1 X134.947 Y125.715 Z6.8 F36000
G1 X115.627 Y111.14 Z6.8
G1 Z6.4
G1 E.8 F1800
G1 F15476.087
G2 X114.015 Y111.281 I-.475 J3.84 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07074
G3 X83.957 Y137.688 I2.367 J.128 E.04916
G1 X86.809 Y140.541 E.1338
G1 X90.708 Y142.264 E.14141
G1 X98.937 Y134.035 E.38602
G3 X99.21 Y129.914 I3.621 J-1.829 E.14373
G1 X93.83 Y124.534 E.25241
G2 X90.988 Y126.402 I5.51 J11.479 E.11313
G2 X90.068 Y128.448 I10.558 J5.975 E.07455
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.046 J23.848 E.05401
G1 X88.404 Y132.211 F36000
G1 F15476.087
G3 X87.525 Y133.581 I-17.724 J-10.408 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.66 Y109.988 E1.62448
G2 X127.99 Y109.211 I-4.185 J9.407 E.09252
G2 X125.341 Y109.989 I1.862 J11.244 E.09183
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.236 J-12.703 E.054
; CHANGE_LAYER
; Z_HEIGHT: 6.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
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
G1 X124.321 Y121.264
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X124.334 Y121.246 E.00072
G3 X127.795 Y117.968 I3.676 J.416 E.17183
G3 X130.311 Y118.764 I.203 J3.734 E.08947
G3 X124.31 Y121.659 I-2.301 J2.897 E.49607
G1 X124.32 Y121.324 E.01113
G1 X124.715 Y121.273 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.786 Y120.925 E.01092
G3 X127.817 Y118.359 I3.225 J.736 E.13088
G3 X129.764 Y118.856 I.202 J3.271 E.06274
G3 X124.72 Y121.331 I-1.753 J2.805 E.43232
; WIPE_START
M204 S10000
G1 X124.786 Y120.925 E-.15626
G1 X124.878 Y120.566 E-.14086
G1 X125.02 Y120.223 E-.14106
G1 X125.199 Y119.898 E-.14108
G1 X125.414 Y119.595 E-.14105
G1 X125.484 Y119.517 E-.03968
; WIPE_END
G1 E-.04 F1800
G1 X132.63 Y122.198 Z7 F36000
G1 X157.063 Y131.361 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.066 Y131.38 E.00064
G3 X153.044 Y128.524 I-3.608 J.821 E.59206
G1 X153.458 Y128.5 E.01377
G3 X156.952 Y130.981 I0 J3.7 E.15157
G1 X157.046 Y131.303 E.01115
G1 X156.677 Y131.438 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.00091
G3 X153.088 Y128.914 I-3.225 J.734 E.49027
G1 X153.458 Y128.893 E.01141
G3 X156.581 Y131.111 I0 J3.308 E.12552
G1 X156.66 Y131.381 E.00865
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.03404
G1 X156.748 Y131.833 E-.14107
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.1411
G1 X156.583 Y133.297 E-.14104
G1 X156.562 Y133.347 E-.02066
; WIPE_END
G1 E-.04 F1800
G1 X148.959 Y132.673 Z7 F36000
G1 X102.151 Y128.522 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.339 Y128.512 E.00625
G3 X104.855 Y129.308 I.203 J3.733 E.08947
G3 X102.093 Y128.535 I-2.301 J2.898 E.67352
G1 X102.232 Y128.911 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.361 Y128.903 E.00397
G3 X104.308 Y129.4 I.202 J3.27 E.06274
G3 X102.173 Y128.92 I-1.753 J2.805 E.57004
; WIPE_START
M204 S10000
G1 X102.361 Y128.903 E-.07176
G1 X102.546 Y128.893 E-.07054
G1 X102.917 Y128.914 E-.14105
G1 X103.283 Y128.976 E-.1411
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.106 Y129.289 E-.05345
; WIPE_END
G1 E-.04 F1800
G1 X111.326 Y131.763 Z7 F36000
G1 X155.589 Y146.934 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X132.945 Y128.475 I-27.592 J10.73 E1.01346
G2 X100.416 Y146.934 I-4.939 J29.187 E1.3429
G1 X83.055 Y139.263 E.6296
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.974 J3.759 E.05163
G2 X86.79 Y133.985 I-24.733 J-24.819 E.11929
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18944
G3 X90.41 Y126.674 I23.321 J7.822 E.08249
G3 X91.436 Y125.548 I2.425 J1.178 E.05124
G3 X93.349 Y124.413 I15.965 J24.728 E.07381
G2 X98.06 Y120.701 I-8.564 J-15.715 E.19988
G2 X100.325 Y117.806 I-37.403 J-31.603 E.12196
G3 X101.394 Y116.758 I3.536 J2.536 E.04993
G3 X103.044 Y116.197 I3.009 J6.144 E.05795
G2 X106.577 Y115.257 I-6.546 J-31.734 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.748 E.18842
G3 X113.513 Y111.136 I14.723 J18.742 E.0804
G3 X115.145 Y110.777 I1.449 J2.701 E.05614
G3 X117.853 Y110.909 I-7.765 J188.201 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.096 J28.214 E.09117
G3 X128.184 Y108.872 I.643 J2.631 E.02777
G3 X129.858 Y109.327 I-.985 J6.926 E.05767
G2 X133.389 Y110.477 I12.218 J-31.514 E.12327
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.771 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05112
G3 X144.473 Y112.538 I-15.37 J23.401 E.07316
G2 X149.427 Y115.257 I11.081 J-14.313 E.18824
G2 X152.965 Y116.193 I9.836 J-30.027 E.12147
G3 X154.581 Y116.738 I-1.254 J6.388 E.05674
G3 X155.675 Y117.81 I-2.636 J3.783 E.05101
G2 X157.945 Y120.701 I41.972 J-30.619 E.122
G2 X162.421 Y124.276 I12.716 J-11.334 E.19092
G3 X164.758 Y125.673 I-13.521 J25.255 E.09034
G3 X165.746 Y127.013 I-1.782 J2.349 E.05598
G3 X166.938 Y130.091 I-676.656 J263.884 E.1095
G2 X170.649 Y135.623 I16.058 J-6.761 E.22233
G3 X172.333 Y137.457 I-17.043 J17.336 E.08263
G3 X172.913 Y139.008 I-2.311 J1.749 E.05571
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.198 E2.17916
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.199 J.192 E.05096
G3 X83.717 Y136.795 I3.893 J1.885 E.04098
G2 X85.862 Y134.489 I-444.101 J-415.312 E.09677
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.494 I23.441 J7.865 E.07787
G3 X91.213 Y125.225 I2.768 J1.355 E.05332
G3 X93.153 Y124.073 I16.129 J24.952 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18127
G2 X100.018 Y117.563 I-37.331 J-31.521 E.11231
G3 X101.193 Y116.421 I3.822 J2.758 E.05062
G3 X102.951 Y115.816 I3.187 J6.404 E.05729
G2 X106.448 Y114.887 I-6.46 J-31.37 E.11124
G2 X111.301 Y112.219 I-5.849 J-16.383 E.1709
G3 X113.319 Y110.795 I14.851 J18.913 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05819
G3 X117.867 Y110.517 I-7.449 J182.394 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21158
G3 X127.013 Y108.625 I13.196 J33.86 E.07784
G3 X128.217 Y108.481 I.982 J3.11 E.03746
G3 X129.989 Y108.958 I-1.008 J7.28 E.05654
G2 X133.481 Y110.096 I12.107 J-31.21 E.1129
G2 X138.707 Y110.489 I3.893 J-16.812 E.16168
G3 X141.261 Y110.387 I2.31 J25.878 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05321
G3 X144.706 Y112.222 I-15.53 J23.672 E.06879
G2 X149.556 Y114.887 I10.852 J-14.004 E.17076
G2 X153.057 Y115.812 I9.716 J-29.684 E.11132
G3 X154.783 Y116.402 I-1.324 J6.695 E.05622
G3 X155.981 Y117.565 I-2.814 J4.096 E.05155
G2 X158.238 Y120.441 I41.9 J-30.563 E.11237
G2 X162.618 Y123.937 I12.424 J-11.074 E.17301
G3 X164.784 Y125.21 I-16.296 J30.195 E.07721
G3 X166.104 Y126.854 I-1.828 J2.82 E.0659
G3 X167.3 Y129.94 I-593.932 J231.898 E.10169
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.647 Y137.222 I-17.221 J17.506 E.07793
G3 X173.302 Y138.956 I-2.618 J1.98 E.05775
G3 X173.36 Y139.508 I-10.396 J1.373 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38731
G1 X154.608 Y145.61 E-.07071
; WIPE_END
G1 E-.04 F1800
G1 X152.65 Y138.233 Z7 F36000
G1 X150.358 Y129.602 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X151.623 Y128.595 I3.988 J3.716 E.05383
G1 X133.984 Y110.956 E.8275
G2 X137.055 Y111.268 I4.402 J-28.035 E.10248
G1 X130.118 Y118.206 E.32546
G2 X125.884 Y118.208 I-2.116 J3.47 E.14773
G1 X118.944 Y111.268 E.32555
G2 X122.015 Y110.957 I-1.316 J-28.285 E.10243
G1 X104.378 Y128.594 E.82736
G3 X105.644 Y129.599 I-2.719 J4.725 E.05383
; WIPE_START
G1 X105.073 Y129.035 E-.30504
G1 X104.378 Y128.594 E-.31276
G1 X104.643 Y128.329 E-.1422
; WIPE_END
G1 E-.04 F1800
G1 X104.835 Y135.539 Z7 F36000
G1 Z6.6
G1 E.8 F1800
G1 F15476.087
G1 X106.309 Y137.013 E.06913
G3 X110.399 Y133.428 I22.211 J21.212 E.18067
G1 X98.118 Y121.147 E.57613
G2 X100.796 Y117.778 I-30.134 J-26.708 E.14281
G3 X101.665 Y117.017 I2.259 J1.7 E.03858
G1 X115.224 Y130.576 E.63609
G2 X113.77 Y131.309 I14.316 J30.192 E.05401
G1 X125.655 Y124.954 F36000
G1 F15476.087
G3 X124.549 Y123.775 I2.425 J-3.382 E.05396
G1 X119.326 Y128.997 E.24502
G3 X120.891 Y128.567 I10.051 J33.499 E.05383
G1 X107.571 Y115.247 E.62487
G2 X112.36 Y112.361 I-8.189 J-19.003 E.18607
G1 X127.713 Y127.714 E.72024
G3 X128.286 Y127.714 I.288 J8.19 E.019
G1 X143.638 Y112.362 E.72019
G2 X148.43 Y115.246 I13.08 J-16.309 E.18608
G1 X135.109 Y128.566 E.6249
G3 X136.671 Y128.995 I-8.448 J33.816 E.05372
G1 X131.454 Y123.778 E.24476
G3 X130.347 Y124.956 I-3.533 J-2.21 E.05396
G1 X142.231 Y131.307 F36000
G1 F15476.087
G2 X140.777 Y130.574 I-15.797 J29.527 E.05401
G1 X154.34 Y117.012 E.63624
G3 X155.633 Y118.323 I-3.859 J5.1 E.06131
G2 X157.884 Y121.144 I27.082 J-19.3 E.11976
G1 X145.602 Y133.425 E.57615
G3 X149.693 Y137.011 I-18.112 J24.794 E.18067
G1 X151.166 Y135.537 E.06911
; WIPE_START
G1 X149.752 Y136.952 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X157.128 Y134.991 Z7 F36000
G1 X167.597 Y132.209 Z7
G1 Z6.6
G1 E.8 F1800
G1 F15476.087
G2 X168.477 Y133.578 I19.143 J-11.351 E.054
G1 X155.719 Y146.337 E.59854
G1 X155.774 Y146.471 E.00483
G1 X159.969 Y144.617 E.15213
G1 X125.341 Y109.989 E1.62449
G3 X127.989 Y109.211 I4.522 J10.498 E.09178
G3 X130.66 Y109.988 I-1.507 J10.162 E.09257
G1 X96.032 Y144.616 E1.62448
G1 X100.23 Y146.471 E.15226
G1 X100.284 Y146.34 E.0047
G1 X87.525 Y133.581 E.59857
G2 X88.404 Y132.211 I-16.846 J-11.779 E.054
G1 X102.064 Y142.685 F36000
G1 F15476.087
G1 X102.065 Y142.684 E.00004
G3 X102.92 Y141.3 I20.253 J11.56 E.05397
G1 X90.068 Y128.448 E.60289
G3 X91.238 Y126.14 I5.926 J1.552 E.0865
G3 X93.83 Y124.534 I9.845 J12.996 E.10129
G1 X99.21 Y129.914 E.2524
G2 X98.937 Y134.035 I3.347 J2.292 E.14373
G1 X90.708 Y142.264 E.38602
G1 X86.809 Y140.541 E.14141
G1 X83.957 Y137.688 E.13381
G2 X83.434 Y139.05 I1.841 J1.487 E.04916
G1 X85.385 Y139.911 E.07073
G1 X114.015 Y111.281 E1.34312
G3 X115.627 Y111.14 I1.136 J3.701 E.05406
G1 X140.386 Y111.134 F36000
G1 F15476.087
G3 X141.993 Y111.29 I.483 J3.38 E.05407
G1 X170.616 Y139.912 E1.34272
G1 X172.563 Y139.051 E.07063
G2 X172.052 Y137.679 I-2.418 J.12 E.04933
G1 X169.189 Y140.542 E.13431
G1 X165.292 Y142.265 E.14132
G1 X157.066 Y134.038 E.38591
M73 P78 R4
G2 X156.792 Y129.911 I-3.618 J-1.833 E.14398
G1 X162.172 Y124.532 E.25237
G3 X164.984 Y126.364 I-5.413 J11.385 E.11168
G3 X165.932 Y128.447 I-10.69 J6.121 E.07604
G1 X153.083 Y141.297 E.6028
G3 X153.939 Y142.682 I-19.416 J12.957 E.05402
; CHANGE_LAYER
; Z_HEIGHT: 6.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X153.083 Y141.297 E-.61867
G1 X153.346 Y141.034 E-.14133
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
G1 X124.321 Y121.264
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X124.334 Y121.246 E.00073
G3 X127.772 Y117.969 I3.676 J.415 E.17105
G3 X130.311 Y118.764 I.226 J3.733 E.09024
G3 X124.311 Y121.659 I-2.301 J2.897 E.49596
G1 X124.32 Y121.324 E.01113
G1 X124.715 Y121.276 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.786 Y120.925 E.011
G3 X127.794 Y118.36 I3.224 J.736 E.13017
G3 X129.764 Y118.856 I.224 J3.27 E.06346
G3 X124.72 Y121.333 I-1.753 J2.804 E.43221
; WIPE_START
M204 S10000
G1 X124.786 Y120.925 E-.157
G1 X124.878 Y120.566 E-.14091
G1 X125.02 Y120.223 E-.14104
G1 X125.199 Y119.898 E-.14108
G1 X125.414 Y119.595 E-.14105
G1 X125.482 Y119.519 E-.03893
; WIPE_END
G1 E-.04 F1800
G1 X132.629 Y122.199 Z7.2 F36000
G1 X157.063 Y131.361 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.066 Y131.38 E.00064
G3 X153.044 Y128.524 I-3.608 J.821 E.59206
G1 X153.458 Y128.5 E.01377
G3 X156.952 Y130.981 I0 J3.7 E.15158
G1 X157.046 Y131.303 E.01114
G1 X156.679 Y131.443 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.00075
G3 X153.088 Y128.914 I-3.225 J.734 E.49027
G1 X153.458 Y128.893 E.01141
G3 X156.581 Y131.111 I0 J3.308 E.12552
G1 X156.662 Y131.385 E.0088
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.0321
G1 X156.748 Y131.833 E-.14107
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.1411
G1 X156.583 Y133.297 E-.14104
G1 X156.56 Y133.352 E-.0226
; WIPE_END
G1 E-.04 F1800
G1 X148.957 Y132.677 Z7.2 F36000
G1 X102.151 Y128.522 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.316 Y128.513 E.00547
G3 X104.855 Y129.308 I.226 J3.732 E.09024
G3 X102.093 Y128.534 I-2.301 J2.897 E.6733
G1 X102.229 Y128.911 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.338 Y128.905 E.00336
G3 X104.308 Y129.4 I.224 J3.27 E.06345
G3 X102.17 Y128.92 I-1.753 J2.805 E.56995
; WIPE_START
M204 S10000
G1 X102.338 Y128.905 E-.06424
G1 X102.546 Y128.893 E-.07935
G1 X102.917 Y128.914 E-.14105
G1 X103.283 Y128.976 E-.1411
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.103 Y129.287 E-.05216
; WIPE_END
G1 E-.04 F1800
G1 X111.323 Y131.762 Z7.2 F36000
G1 X155.589 Y146.934 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.6296
G3 X83.411 Y137.866 I3.578 J.167 E.04816
G3 X84.377 Y136.65 I5.974 J3.759 E.05161
G2 X86.79 Y133.985 I-24.723 J-24.81 E.11932
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18942
G3 X90.41 Y126.674 I23.32 J7.822 E.08249
G3 X91.435 Y125.548 I2.418 J1.171 E.05123
G3 X93.349 Y124.413 I15.944 J24.693 E.07381
G2 X98.06 Y120.701 I-8.564 J-15.716 E.19989
G2 X100.324 Y117.807 I-37.387 J-31.589 E.12194
G3 X101.394 Y116.758 I3.538 J2.537 E.04995
G3 X103.044 Y116.197 I3.008 J6.14 E.05796
G2 X106.577 Y115.257 I-6.542 J-31.719 E.12134
G2 X111.534 Y112.534 I-5.975 J-16.747 E.18841
G3 X113.513 Y111.136 I14.724 J18.744 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.765 J188.201 E.08995
G2 X124.754 Y109.831 I.85 J-17.19 E.2333
G3 X127.353 Y108.943 I11.094 J28.209 E.09117
G3 X128.184 Y108.872 I.643 J2.631 E.02777
G3 X129.858 Y109.327 I-.985 J6.925 E.05768
G2 X133.389 Y110.477 I12.218 J-31.514 E.12327
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.778 E.08329
G3 X142.68 Y111.256 I-.087 J2.685 E.05112
G3 X144.474 Y112.538 I-15.363 J23.39 E.07317
G2 X149.427 Y115.257 I11.081 J-14.314 E.1882
G2 X152.965 Y116.193 I9.835 J-30.023 E.12147
G3 X154.58 Y116.737 I-1.257 J6.399 E.05669
G3 X155.674 Y117.809 I-2.632 J3.781 E.05107
G2 X157.946 Y120.702 I41.954 J-30.605 E.12203
G2 X162.421 Y124.276 I12.715 J-11.334 E.19089
G3 X164.758 Y125.674 I-13.535 J25.279 E.09035
G3 X165.746 Y127.013 I-1.781 J2.348 E.05596
G3 X166.938 Y130.092 I-674.257 J262.957 E.10953
G2 X170.649 Y135.623 I16.057 J-6.761 E.22232
G3 X172.333 Y137.457 I-17.056 J17.348 E.08261
G3 X172.913 Y139.008 I-2.311 J1.749 E.05572
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.202 E2.17903
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.199 J.192 E.05096
G3 X83.717 Y136.795 I3.894 J1.886 E.041
G2 X85.862 Y134.489 I-442.035 J-413.393 E.09675
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.062 Y126.493 I23.438 J7.864 E.07787
G3 X91.212 Y125.225 I2.76 J1.348 E.05332
G3 X93.152 Y124.073 I16.129 J24.952 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18128
G2 X100.017 Y117.563 I-37.316 J-31.508 E.1123
G3 X101.193 Y116.421 I3.823 J2.758 E.05063
G3 X102.951 Y115.816 I3.187 J6.401 E.0573
G2 X106.449 Y114.887 I-6.457 J-31.358 E.11126
G2 X111.301 Y112.219 I-5.849 J-16.382 E.17088
G3 X113.32 Y110.795 I14.852 J18.914 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.449 J182.394 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.198 J33.866 E.07783
G3 X128.217 Y108.481 I.983 J3.111 E.03747
G3 X129.989 Y108.958 I-1.008 J7.28 E.05654
G2 X133.481 Y110.096 I12.107 J-31.21 E.1129
G2 X138.707 Y110.489 I3.893 J-16.812 E.16168
G3 X141.261 Y110.387 I2.31 J25.883 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05322
G3 X144.706 Y112.222 I-15.534 J23.677 E.06879
G2 X149.556 Y114.887 I10.853 J-14.005 E.17075
G2 X153.056 Y115.812 I9.716 J-29.683 E.11132
G3 X154.781 Y116.401 I-1.326 J6.705 E.05617
G3 X155.981 Y117.565 I-2.808 J4.094 E.05161
G2 X158.239 Y120.441 I41.912 J-30.573 E.11239
G2 X162.618 Y123.937 I12.423 J-11.074 E.173
G3 X164.784 Y125.21 I-16.333 J30.258 E.07721
G3 X166.104 Y126.854 I-1.827 J2.82 E.0659
G3 X167.3 Y129.94 I-592.446 J231.323 E.10169
G2 X170.934 Y135.354 I15.7 J-6.612 E.2016
G3 X172.646 Y137.222 I-17.228 J17.513 E.07791
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.393 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X153.939 Y142.682 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X153.083 Y141.297 I-20.276 J11.575 E.05402
G1 X165.932 Y128.447 E.6028
G2 X164.742 Y126.11 I-5.654 J1.407 E.08775
G2 X162.172 Y124.532 I-25.057 J37.922 E.10007
G1 X156.792 Y129.911 E.25237
G3 X157.066 Y134.038 I-3.485 J2.304 E.14353
G1 X165.292 Y142.265 E.38591
G1 X169.189 Y140.542 E.14132
G1 X172.052 Y137.679 E.13431
G3 X172.563 Y139.051 I-1.907 J1.492 E.04933
G1 X170.616 Y139.912 E.07063
G1 X141.993 Y111.29 E1.34273
G2 X140.386 Y111.134 I-1.124 J3.225 E.05407
G1 X130.347 Y124.956 F36000
G1 F15476.087
G2 X131.454 Y123.778 I-2.426 J-3.388 E.05396
G1 X136.671 Y128.995 E.24476
G2 X135.109 Y128.566 I-9.999 J33.349 E.05372
G1 X148.43 Y115.246 E.6249
G3 X143.645 Y112.355 I8.084 J-18.789 E.18603
G1 X128.286 Y127.714 E.7205
G2 X127.713 Y127.714 I-.285 J8.199 E.019
G1 X112.36 Y112.361 E.72024
G3 X107.571 Y115.247 I-12.977 J-16.115 E.18607
G1 X120.891 Y128.567 E.62487
G2 X119.326 Y128.997 I8.486 J33.929 E.05383
G1 X124.549 Y123.775 E.24502
G2 X125.655 Y124.954 I3.531 J-2.203 E.05396
G1 X113.77 Y131.309 F36000
G1 F15476.087
G3 X115.224 Y130.576 I15.772 J29.463 E.05401
G1 X101.665 Y117.017 E.6361
G2 X100.797 Y117.778 I1.392 J2.463 E.03857
G3 X98.118 Y121.146 I-32.808 J-23.337 E.14281
G1 X110.398 Y133.429 E.57612
G2 X106.309 Y137.013 I20.739 J27.78 E.18056
G1 X104.835 Y135.539 E.06913
; WIPE_START
G1 X106.25 Y136.954 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.644 Y129.599 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
G1 F15476.087
G2 X104.378 Y128.594 I-3.986 J3.72 E.05383
G1 X122.015 Y110.957 E.82736
G3 X118.944 Y111.268 I-4.387 J-27.976 E.10243
G1 X125.884 Y118.208 E.32555
G3 X130.118 Y118.206 I2.119 J3.471 E.14773
G1 X137.055 Y111.268 E.32546
G3 X133.984 Y110.956 I1.331 J-28.35 E.10248
G1 X151.623 Y128.595 E.8275
G2 X150.358 Y129.602 I1.863 J3.641 E.05398
; WIPE_START
G1 X150.932 Y129.035 E-.30642
G1 X151.623 Y128.595 E-.31138
G1 X151.358 Y128.331 E-.1422
; WIPE_END
G1 E-.04 F1800
G1 X151.166 Y135.537 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
G1 F15476.087
G1 X149.693 Y137.011 E.06911
G2 X145.602 Y133.425 I-22.205 J21.211 E.18067
G1 X157.884 Y121.144 E.57615
G3 X155.633 Y118.323 I24.852 J-22.138 E.11977
G2 X154.34 Y117.012 I-5.151 J3.789 E.0613
G1 X140.777 Y130.574 E.63624
G3 X142.231 Y131.307 I-14.353 J30.278 E.05401
; WIPE_START
G1 X140.777 Y130.574 E-.61863
G1 X141.04 Y130.311 E-.14137
; WIPE_END
G1 E-.04 F1800
G1 X134.947 Y125.715 Z7.2 F36000
G1 X115.627 Y111.14 Z7.2
G1 Z6.8
G1 E.8 F1800
G1 F15476.087
G2 X114.015 Y111.281 I-.476 J3.841 E.05406
G1 X85.385 Y139.911 E1.34312
G1 X83.434 Y139.05 E.07073
G3 X83.957 Y137.688 I2.363 J.126 E.04916
G1 X86.809 Y140.541 E.1338
G1 X90.708 Y142.264 E.14141
G1 X98.937 Y134.035 E.38602
G3 X99.21 Y129.914 I3.621 J-1.829 E.14373
G1 X93.83 Y124.534 E.2524
G2 X90.988 Y126.402 I5.504 J11.47 E.11315
G2 X90.068 Y128.448 I10.573 J5.982 E.07453
G1 X102.92 Y141.3 E.60289
G2 X102.064 Y142.685 I37.046 J23.848 E.05401
G1 X88.404 Y132.211 F36000
G1 F15476.087
G3 X87.525 Y133.581 I-17.703 J-10.395 E.054
G1 X100.284 Y146.34 E.59857
G1 X100.23 Y146.471 E.0047
G1 X96.032 Y144.616 E.15226
G1 X130.66 Y109.988 E1.62448
G2 X127.987 Y109.211 I-4.168 J9.352 E.09263
G2 X125.341 Y109.989 I1.889 J11.314 E.09171
G1 X159.969 Y144.617 E1.62449
G1 X155.774 Y146.471 E.15213
G1 X155.719 Y146.337 E.00483
G1 X168.477 Y133.578 E.59854
G3 X167.597 Y132.209 I18.247 J-12.71 E.054
; CHANGE_LAYER
; Z_HEIGHT: 7
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X168.477 Y133.578 E-.61845
G1 X168.214 Y133.841 E-.14155
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
G1 X124.326 Y121.225
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X124.404 Y120.838 E.01311
G3 X127.749 Y117.97 I3.607 J.823 E.15655
G3 X129.972 Y118.524 I.27 J3.659 E.07731
G3 X124.33 Y121.283 I-1.961 J3.137 E.52237
G1 X124.716 Y121.273 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.82 Y120.79 E.01517
G3 X127.771 Y118.362 I3.19 J.869 E.1252
G3 X129.764 Y118.856 I.246 J3.271 E.06417
G3 X124.72 Y121.331 I-1.753 J2.804 E.43214
; WIPE_START
M204 S10000
G1 X124.82 Y120.79 E-.20883
G1 X124.878 Y120.566 E-.08817
G1 X125.02 Y120.223 E-.14104
G1 X125.199 Y119.898 E-.14108
G1 X125.414 Y119.595 E-.14105
G1 X125.484 Y119.517 E-.03982
; WIPE_END
G1 E-.04 F1800
G1 X132.628 Y122.204 Z7.4 F36000
G1 X157.072 Y131.398 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.135 Y131.789 E.01313
G3 X153.044 Y128.524 I-3.677 J.411 E.57829
G1 X153.458 Y128.5 E.01377
G3 X157.057 Y131.34 I0 J3.7 E.16401
G1 X156.68 Y131.448 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.0006
G3 X153.088 Y128.914 I-3.226 J.735 E.49049
G1 X153.458 Y128.893 E.01141
G3 X156.582 Y131.11 I0 J3.309 E.12553
G1 X156.663 Y131.39 E.00896
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.03023
G1 X156.748 Y131.833 E-.14109
G1 X156.768 Y132.203 E-.14104
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.1411
G1 X156.583 Y133.297 E-.14104
G1 X156.558 Y133.356 E-.02444
; WIPE_END
G1 E-.04 F1800
G1 X148.956 Y132.678 Z7.4 F36000
G1 X102.27 Y128.516 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.293 Y128.515 E.00076
G3 X104.517 Y129.068 I.27 J3.658 E.07731
G3 X102.133 Y128.529 I-1.961 J3.137 E.68856
G1 X102.21 Y128.522 E.00259
G1 X102.212 Y128.92 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.315 Y128.906 E.00318
G3 X104.308 Y129.4 I.246 J3.271 E.06417
G3 X101.811 Y128.982 I-1.753 J2.804 E.55859
G1 X102.153 Y128.929 E.01063
; WIPE_START
M204 S10000
G1 X102.315 Y128.906 E-.06212
G1 X102.315 Y128.906 E0
G1 X102.546 Y128.893 E-.08815
G1 X102.917 Y128.914 E-.14105
G1 X103.283 Y128.976 E-.1411
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.087 Y129.279 E-.04548
; WIPE_END
G1 E-.04 F1800
G1 X111.307 Y131.754 Z7.4 F36000
G1 X155.589 Y146.934 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.721 E2.35651
G1 X83.055 Y139.263 E.6296
G3 X83.411 Y137.866 I3.579 J.167 E.04815
M73 P79 R4
G3 X84.377 Y136.65 I5.973 J3.758 E.05161
G2 X86.79 Y133.985 I-24.734 J-24.82 E.11931
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18943
G3 X90.41 Y126.674 I23.321 J7.822 E.08251
G3 X91.435 Y125.548 I2.417 J1.171 E.0512
G3 X93.349 Y124.413 I15.926 J24.66 E.07383
G2 X98.059 Y120.701 I-8.564 J-15.715 E.19988
G2 X100.324 Y117.807 I-37.405 J-31.604 E.12194
G3 X101.394 Y116.757 I3.536 J2.535 E.04996
G3 X103.044 Y116.197 I3.009 J6.145 E.05794
G2 X106.577 Y115.257 I-6.545 J-31.731 E.12134
G2 X111.533 Y112.534 I-5.974 J-16.747 E.18839
G3 X113.513 Y111.136 I14.723 J18.741 E.08043
G3 X115.145 Y110.777 I1.449 J2.701 E.05613
G3 X117.853 Y110.909 I-7.763 J188.153 E.08995
G2 X124.754 Y109.831 I.851 J-17.19 E.2333
G3 X127.353 Y108.943 I11.108 J28.248 E.09114
G3 X128.114 Y108.866 I.66 J2.726 E.02545
G3 X129.858 Y109.327 I-.884 J6.875 E.06001
G2 X133.389 Y110.477 I12.217 J-31.512 E.12327
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.302 J25.757 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05111
G3 X144.474 Y112.538 I-15.374 J23.407 E.07318
G2 X149.427 Y115.257 I11.081 J-14.314 E.18821
G2 X152.965 Y116.193 I9.835 J-30.023 E.12147
G3 X154.57 Y116.731 I-1.273 J6.459 E.05628
G3 X155.674 Y117.809 I-2.603 J3.772 E.05146
G2 X157.945 Y120.701 I41.966 J-30.614 E.122
G2 X162.422 Y124.276 I12.716 J-11.334 E.19093
G3 X164.758 Y125.674 I-13.516 J25.245 E.09034
G3 X165.745 Y127.012 I-1.781 J2.348 E.05594
G3 X166.938 Y130.092 I-673.244 J262.572 E.10955
G2 X170.649 Y135.623 I16.058 J-6.762 E.22231
G3 X172.333 Y137.457 I-17.022 J17.317 E.08264
G3 X172.913 Y139.008 I-2.352 J1.764 E.05568
G1 X172.943 Y139.264 E.00855
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.198 E2.17914
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.199 J.192 E.05096
G3 X83.717 Y136.795 I3.892 J1.884 E.04099
G2 X85.861 Y134.49 I-447.166 J-418.171 E.09674
G2 X89.134 Y128.851 I-12.825 J-11.212 E.2016
G3 X90.062 Y126.493 I23.435 J7.863 E.07789
G3 X91.212 Y125.226 I2.76 J1.348 E.05328
G3 X93.152 Y124.073 I16.108 J24.914 E.06936
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18129
G2 X100.017 Y117.563 I-37.325 J-31.515 E.11228
G3 X101.193 Y116.421 I3.822 J2.758 E.05064
G3 X102.951 Y115.816 I3.188 J6.405 E.05729
G2 X106.449 Y114.887 I-6.459 J-31.367 E.11125
G2 X111.301 Y112.219 I-5.849 J-16.383 E.17088
G3 X113.319 Y110.795 I14.85 J18.911 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05819
G3 X117.867 Y110.517 I-7.447 J182.349 E.08376
G2 X124.623 Y109.462 I.837 J-16.796 E.21159
G3 X127.013 Y108.625 I13.202 J33.877 E.07783
G3 X128.135 Y108.474 I.997 J3.182 E.03494
G3 X129.989 Y108.957 I-.885 J7.196 E.05905
G2 X133.481 Y110.096 I12.107 J-31.21 E.11291
G2 X138.707 Y110.489 I3.893 J-16.812 E.16168
G3 X141.261 Y110.387 I2.31 J25.882 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05321
G3 X144.706 Y112.222 I-15.529 J23.67 E.06879
G2 X149.556 Y114.887 I10.852 J-14.004 E.17075
G2 X153.057 Y115.812 I9.715 J-29.68 E.11132
G3 X154.77 Y116.394 I-1.341 J6.762 E.05577
G3 X155.764 Y117.3 I-2.18 J3.39 E.04153
G2 X157.819 Y119.952 I1392.83 J-1076.932 E.10308
G2 X162.619 Y123.937 I12.924 J-10.684 E.1928
G3 X164.784 Y125.21 I-16.294 J30.191 E.0772
G3 X166.104 Y126.853 I-1.827 J2.82 E.06588
G3 X167.3 Y129.94 I-589.777 J230.295 E.10171
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.647 Y137.222 I-17.21 J17.496 E.07793
G3 X173.302 Y138.956 I-2.679 J2.003 E.05771
G3 X173.36 Y139.508 I-10.393 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30188
G1 X154.687 Y145.778 E-.38742
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X155.407 Y144.677 Z7.4 F36000
G1 Z7
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X155.975 Y145.97 I-14.238 J7.035 E.04686
G1 X156.173 Y145.883 E.00716
G1 X168.207 Y133.848 E.56457
G2 X171.445 Y137.52 I31.647 J-24.644 E.1625
G1 X171.783 Y137.948 E.01809
G1 X169.928 Y139.803 E.08704
G1 X165.006 Y141.979 E.1785
G1 X157.344 Y134.316 E.35947
G2 X157.063 Y129.641 I-3.886 J-2.113 E.16373
G1 X161.898 Y124.806 E.22681
G3 X164.489 Y126.391 I-25.269 J44.222 E.10078
G3 X165.333 Y127.922 I-3.77 J3.077 E.0583
G1 X165.639 Y128.74 E.02899
G1 X153.355 Y141.024 E.57626
G2 X152.428 Y139.686 I-28.672 J18.9 E.05401
G1 X150.416 Y135.416 F36000
G1 F15476.087
G3 X149.46 Y134.109 I3.243 J-3.373 E.05397
G1 X125.635 Y110.283 E1.1177
G3 X128.063 Y109.591 I3.806 J8.75 E.08401
G3 X130.364 Y110.284 I-1.492 J9.13 E.07993
G1 X106.548 Y134.1 E1.11728
G3 X105.596 Y135.409 I-4.196 J-2.049 E.05397
G1 X106.613 Y132.203 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X106.506 Y133.125 E.02572
G1 X106.201 Y133.983 E.02522
G1 X105.714 Y134.752 E.02522
G1 X105.07 Y135.39 E.02511
G1 X104.541 Y135.739 E.01756
G1 X103.872 Y136.046 E.02039
G1 X102.984 Y136.245 E.02522
G1 X102.055 Y136.237 E.02572
G1 X101.457 Y136.114 E.01694
G1 X100.767 Y135.858 E.02039
G1 X99.998 Y135.371 E.02522
G1 X99.346 Y134.707 E.02577
G1 X98.885 Y133.948 E.02462
G1 X98.579 Y133.09 E.02522
G1 X98.481 Y132.185 E.02522
G1 X98.587 Y131.281 E.02522
G1 X98.892 Y130.423 E.02522
G1 X99.379 Y129.655 E.02522
G1 X100.026 Y129.014 E.02522
G1 X100.799 Y128.533 E.02522
G1 X101.678 Y128.234 E.02573
G1 X102.563 Y128.147 E.02465
G1 X103.468 Y128.244 E.02522
G1 X104.326 Y128.548 E.02522
G1 X105.095 Y129.036 E.02522
G1 X105.746 Y129.698 E.02573
G1 X106.207 Y130.459 E.02465
G1 X106.514 Y131.316 E.02522
G1 X106.606 Y132.144 E.02307
; Slow Down End
; WIPE_START
G1 X106.514 Y131.316 E-.31638
G1 X106.207 Y130.459 E-.34595
G1 X106.074 Y130.239 E-.09767
; WIPE_END
G1 E-.04 F1800
G1 X103.539 Y137.438 Z7.4 F36000
G1 X101.789 Y142.41 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X102.647 Y141.027 I20.236 J11.599 E.05402
G1 X90.362 Y128.742 E.57633
G3 X91.491 Y126.421 I6.056 J1.512 E.08624
G3 X94.106 Y124.81 I9.941 J13.208 E.10203
G1 X98.94 Y129.644 E.22676
G2 X98.659 Y134.313 I3.607 J2.56 E.16348
G1 X90.994 Y141.978 E.35958
G1 X86.07 Y139.802 E.17858
G1 X84.225 Y137.957 E.08654
G1 X84.563 Y137.526 E.01817
G2 X87.795 Y133.851 I-29.349 J-29.07 E.16244
G1 X99.823 Y145.879 E.56426
G1 X100.029 Y145.97 E.00748
G3 X100.594 Y144.686 I14.707 J5.701 E.04654
G1 X100.285 Y146.301 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.384764
G1 F3000;_EXTRUDE_SET_SPEED
G1 X100.207 Y146.415 E.00382
G1 X100.073 Y146.386 E.00382
G1 X83.559 Y139.089 E.50294
G1 X83.474 Y139.034 E.00281
G1 X83.474 Y138.912 E.00341
G1 X83.584 Y138.378 E.01518
G1 X83.849 Y137.85 E.01646
G1 X84.288 Y137.29 E.01982
G1 X86.018 Y135.447 E.07043
G2 X89.634 Y129.658 I-12.943 J-12.108 E.19132
G3 X90.586 Y127.154 I44.45 J15.469 E.07463
G1 X90.985 Y126.434 E.02293
G3 X91.644 Y125.845 I2.105 J1.696 E.02473
G1 X92.157 Y125.517 E.01698
G2 X94.82 Y123.946 I-24.301 J-44.223 E.08612
G2 X99.159 Y119.948 I-9.558 J-14.727 E.16513
G1 X100.807 Y117.788 E.07568
G3 X101.471 Y117.142 I2.667 J2.074 E.0259
G1 X101.822 Y116.95 E.01114
G3 X103.129 Y116.549 I3.095 J7.764 E.03814
G1 X105.117 Y116.074 E.05692
G2 X110.235 Y113.875 I-4.284 J-17.028 E.15584
G2 X113.149 Y111.799 I-30.846 J-46.358 E.09968
G3 X114.055 Y111.287 I2.82 J3.935 E.02904
G1 X114.581 Y111.167 E.01504
G3 X115.833 Y111.161 I.689 J13.345 E.03488
G2 X117.985 Y111.273 I3.629 J-48.953 E.06005
G2 X123.7 Y110.559 I.752 J-17.219 E.16117
G2 X126.645 Y109.532 I-29.152 J-88.267 E.08689
G1 X127.674 Y109.251 E.02973
G3 X128.465 Y109.282 I.313 J2.099 E.02218
G1 X129.05 Y109.437 E.01686
G1 X131.699 Y110.369 E.07822
G2 X138.167 Y111.271 I5.63 J-16.729 E.18295
G3 X140.85 Y111.133 I4.093 J53.616 E.07486
G1 X141.394 Y111.156 E.01516
G1 X141.774 Y111.234 E.01081
G3 X143.303 Y112.121 I-2.444 J5.974 E.04941
G2 X145.764 Y113.875 I23.982 J-31.039 E.08419
G2 X150.89 Y116.074 I9.436 J-14.921 E.15603
G3 X153.551 Y116.72 I-23.516 J102.764 E.07629
G1 X154.154 Y116.93 E.01777
G3 X154.798 Y117.367 I-.805 J1.882 E.02183
G3 X155.62 Y118.331 I-6.133 J6.064 E.03531
G1 X156.844 Y119.947 E.05648
G2 X161.188 Y123.947 I13.924 J-10.76 E.16527
G2 X163.859 Y125.517 I51.161 J-83.995 E.08631
G1 X164.716 Y126.108 E.02898
G3 X165.165 Y126.662 I-1.313 J1.525 E.01998
G3 X165.67 Y127.788 I-7.165 J3.887 E.03439
G1 X166.371 Y129.66 E.05569
G2 X169.99 Y135.449 I16.558 J-6.324 E.19137
G1 X171.715 Y137.278 E.07003
G3 X172.162 Y137.848 I-5.694 J4.923 E.02021
G1 X172.414 Y138.37 E.01615
G3 X172.523 Y139.036 I-5.148 J1.183 E.01879
G1 X172.438 Y139.091 E.00283
G1 X155.931 Y146.386 E.50271
G1 X155.797 Y146.414 E.00382
G1 X155.72 Y146.301 E.00382
G2 X100.308 Y146.246 I-27.717 J11.348 E1.97094
; Slow Down End
G1 X94.828 Y143.672 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X96.318 Y144.33 E.05401
G1 X104.443 Y136.205 E.38119
G2 X105.106 Y135.81 I-2.602 J-5.123 E.0256
G1 X106.042 Y136.746 E.04392
G3 X110.13 Y133.158 I22.772 J21.82 E.18065
G1 X98.385 Y121.413 E.55098
G2 X101.085 Y118.021 I-29.949 J-26.612 E.14389
G3 X101.943 Y117.295 I1.98 J1.468 E.0376
G1 X114.94 Y130.292 E.60973
G2 X113.491 Y131.033 I14.474 J30.11 E.05401
G1 X106.332 Y116.099 F36000
G1 F15476.087
G2 X107.858 Y115.534 I-6.19 J-19.066 E.05399
G1 X120.579 Y128.255 E.59679
G1 X119.881 Y128.442 E.02396
G1 X124.283 Y124.041 E.20649
; WIPE_START
G1 X122.869 Y125.455 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X130.407 Y124.261 Z7.4 F36000
G1 X131.727 Y124.052 Z7.4
G1 Z7
G1 E.8 F1800
G1 F15476.087
G1 X136.116 Y128.44 E.20589
G1 X135.421 Y128.254 E.02386
G1 X148.143 Y115.532 E.59681
G2 X149.669 Y116.098 I7.742 J-18.556 E.05399
G1 X152.883 Y127.815 F36000
G1 F15476.087
G2 X151.345 Y128.318 I1.182 J6.217 E.05382
G1 X134.453 Y111.426 E.79244
G2 X136.685 Y111.638 I2.918 J-18.796 E.07442
G1 X130.392 Y117.932 E.29524
G2 X125.61 Y117.934 I-2.389 J3.754 E.16748
G1 X119.314 Y111.639 E.29532
G2 X121.545 Y111.427 I-.689 J-19.099 E.07437
G1 X104.656 Y128.316 E.79231
G2 X103.117 Y127.814 I-2.719 J5.727 E.05382
; WIPE_START
G1 X104.01 Y128.022 E-.34806
G1 X104.656 Y128.316 E-.26979
G1 X104.92 Y128.051 E-.14215
; WIPE_END
G1 E-.04 F1800
G1 X112.349 Y126.301 Z7.4 F36000
G1 X132.056 Y121.659 Z7.4
G1 Z7
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.383033
G1 F3000;_EXTRUDE_SET_SPEED
G1 X132.04 Y122.128 E.01301
G1 X131.913 Y122.749 E.01757
G1 X131.657 Y123.439 E.0204
G1 X131.172 Y124.204 E.02511
G1 X130.733 Y124.662 E.01757
G1 X130.15 Y125.111 E.0204
G1 X129.328 Y125.502 E.02523
G1 X128.44 Y125.701 E.02523
G1 X127.511 Y125.693 E.02573
G1 X126.912 Y125.569 E.01695
G1 X126.222 Y125.314 E.0204
G1 X125.454 Y124.826 E.02523
G1 X124.802 Y124.163 E.02577
G1 X124.467 Y123.653 E.01691
G1 X124.159 Y122.985 E.02039
G1 X123.961 Y122.097 E.02523
G1 X123.964 Y121.19 E.02512
G1 X124.092 Y120.569 E.01757
G1 X124.347 Y119.879 E.02039
G1 X124.835 Y119.111 E.02523
G1 X125.482 Y118.47 E.02523
G1 X126.254 Y117.989 E.02522
G1 X127.133 Y117.689 E.02572
G1 X127.729 Y117.616 E.01666
G1 X128.475 Y117.621 E.02067
G1 X129.362 Y117.828 E.02523
G1 X130.18 Y118.226 E.02523
G1 X130.889 Y118.797 E.02523
G1 X131.454 Y119.511 E.02523
G1 X131.845 Y120.333 E.02523
G1 X132.04 Y121.186 E.02425
G1 X132.054 Y121.599 E.01145
; Slow Down End
G1 X142.511 Y131.031 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X141.061 Y130.291 I-15.914 J29.362 E.05401
G1 X154.061 Y117.29 E.60988
G3 X155.335 Y118.555 I-2.962 J4.258 E.05984
G2 X157.617 Y121.411 I27.106 J-19.315 E.12132
G1 X145.872 Y133.156 E.55099
G3 X149.957 Y136.746 I-20.615 J27.58 E.18061
G1 X150.896 Y135.808 E.04402
M73 P80 R4
G2 X151.553 Y136.201 I3.398 J-4.933 E.02541
G1 X159.683 Y144.331 E.38141
G1 X161.172 Y143.673 E.05401
M73 P80 R3
G1 X170.33 Y139.626 F36000
G1 F15476.087
G1 X143.197 Y112.494 E1.27283
G1 X143.375 Y112.625 E.00733
G1 X128.657 Y127.343 E.69045
G2 X127.343 Y127.343 I-.656 J18.81 E.0436
G1 X112.628 Y112.628 E.69029
G1 X112.777 Y112.519 E.00614
G1 X85.671 Y139.625 E1.27163
; WIPE_START
G1 X87.085 Y138.211 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X94.685 Y137.514 Z7.4 F36000
G1 X157.487 Y131.749 Z7.4
G1 Z7
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.3831
G1 F3000;_EXTRUDE_SET_SPEED
G3 X157.481 Y132.693 I-2.767 J.457 E.02629
G1 X157.381 Y133.239 E.01537
G1 X157.113 Y133.983 E.02194
G1 X156.628 Y134.749 E.02512
G1 X156.189 Y135.206 E.01757
G1 X155.634 Y135.637 E.01948
G3 X153.896 Y136.245 I-2.486 J-4.319 E.05135
G1 X152.967 Y136.237 E.02574
G1 X152.103 Y136.026 E.02467
G1 X151.28 Y135.636 E.02523
G1 X150.571 Y135.065 E.02524
G1 X150.02 Y134.374 E.02449
G3 X149.416 Y132.641 I4.367 J-2.493 E.05117
G1 X149.42 Y131.734 E.02512
G1 X149.548 Y131.113 E.01757
G1 X149.803 Y130.423 E.0204
G1 X150.291 Y129.655 E.02523
G1 X150.943 Y129.022 E.02518
G1 X151.71 Y128.533 E.02524
G1 X152.571 Y128.236 E.02523
G1 X153.476 Y128.138 E.02524
G1 X154.38 Y128.244 E.02524
G1 X155.238 Y128.548 E.02523
G1 X156.007 Y129.036 E.02524
G1 X156.647 Y129.683 E.02523
G1 X157.12 Y130.459 E.02518
G1 X157.417 Y131.281 E.02425
G1 X157.478 Y131.69 E.01146
; Slow Down End
; CHANGE_LAYER
; Z_HEIGHT: 7.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X157.417 Y131.281 E-.15704
G1 X157.12 Y130.459 E-.33246
G1 X156.749 Y129.851 E-.27051
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
G1 X124.321 Y121.264
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X124.333 Y121.246 E.00073
G3 X127.726 Y117.972 I3.677 J.415 E.16955
G3 X129.972 Y118.524 I.292 J3.66 E.07808
G3 X124.31 Y121.659 I-1.962 J3.137 E.50988
G1 X124.32 Y121.324 E.01112
G1 X124.714 Y121.281 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.786 Y120.925 E.01115
G3 X127.748 Y118.363 I3.225 J.736 E.12877
G3 X129.439 Y118.677 I.248 J3.381 E.05343
G3 X124.719 Y121.336 I-1.428 J2.984 E.44362
; WIPE_START
M204 S10000
G1 X124.786 Y120.925 E-.15845
G1 X124.878 Y120.566 E-.14085
G1 X125.02 Y120.223 E-.1411
G1 X125.199 Y119.898 E-.14102
G1 X125.414 Y119.595 E-.14108
G1 X125.48 Y119.522 E-.03749
; WIPE_END
G1 E-.04 F1800
G1 X132.627 Y122.201 Z7.6 F36000
G1 X157.063 Y131.36 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.067 Y131.38 E.00065
G3 X153.044 Y128.524 I-3.609 J.822 E.59229
G1 X153.458 Y128.5 E.01377
G3 X156.952 Y130.981 I0 J3.701 E.15159
G1 X157.046 Y131.303 E.01113
G1 X156.681 Y131.452 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.00045
G3 X153.088 Y128.914 I-3.226 J.735 E.49049
G1 X153.458 Y128.893 E.01141
G3 X156.582 Y131.11 I0 J3.309 E.12553
G1 X156.665 Y131.395 E.0091
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.0284
G1 X156.748 Y131.833 E-.14108
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.14108
G1 X156.583 Y133.297 E-.14109
G1 X156.556 Y133.36 E-.02625
; WIPE_END
G1 E-.04 F1800
G1 X148.955 Y132.676 Z7.6 F36000
G1 X102.66 Y128.507 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.961 Y128.526 E.01
G3 X104.517 Y129.068 I-.399 J3.65 E.05512
G3 X102.27 Y128.516 I-1.962 J3.137 E.69314
G3 X102.546 Y128.504 I.292 J3.66 E.00919
G1 X102.6 Y128.505 E.00178
G1 X102.212 Y128.919 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.292 Y128.907 E.00248
G3 X103.983 Y129.221 I.248 J3.38 E.05343
G3 X101.811 Y128.981 I-1.428 J2.984 E.57023
G1 X102.152 Y128.928 E.01062
; WIPE_START
M204 S10000
G1 X102.292 Y128.907 E-.05351
G1 X102.292 Y128.907 E0
G1 X102.546 Y128.893 E-.09695
G1 X102.917 Y128.914 E-.14105
G1 X103.283 Y128.976 E-.1411
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.087 Y129.278 E-.04529
; WIPE_END
G1 E-.04 F1800
G1 X111.307 Y131.754 Z7.6 F36000
G1 X155.589 Y146.934 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.725 E2.35635
G1 X83.055 Y139.263 E.6296
G3 X83.411 Y137.866 I3.578 J.167 E.04816
G3 X84.377 Y136.651 I5.973 J3.758 E.05159
G2 X86.79 Y133.985 I-24.732 J-24.819 E.11934
G2 X89.501 Y128.988 I-13.846 J-10.746 E.18941
G3 X90.41 Y126.674 I23.305 J7.816 E.0825
G3 X91.435 Y125.548 I2.417 J1.171 E.05121
G3 X93.349 Y124.413 I15.941 J24.686 E.07383
G2 X98.059 Y120.701 I-8.564 J-15.715 E.19987
G2 X100.324 Y117.807 I-37.384 J-31.587 E.12194
G3 X101.394 Y116.758 I3.537 J2.535 E.04995
G3 X103.043 Y116.197 I3.008 J6.14 E.05795
G2 X106.576 Y115.257 I-6.544 J-31.729 E.12133
G2 X111.534 Y112.534 I-5.974 J-16.747 E.18842
G3 X113.509 Y111.138 I14.774 J18.811 E.08027
G3 X115.143 Y110.777 I1.446 J2.666 E.05623
G3 X118.157 Y110.918 I-14.28 J337.718 E.10009
G2 X124.754 Y109.831 I.585 J-17.011 E.22323
G3 X127.354 Y108.943 I11.092 J28.205 E.09119
G3 X128.114 Y108.866 I.658 J2.721 E.02541
G3 X129.858 Y109.327 I-.884 J6.876 E.06001
G2 X133.389 Y110.477 I12.215 J-31.506 E.12326
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.303 J25.779 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05112
G3 X144.474 Y112.538 I-15.378 J23.412 E.07318
G2 X149.428 Y115.257 I11.081 J-14.314 E.18823
G2 X152.965 Y116.193 I9.836 J-30.029 E.12143
G3 X154.57 Y116.731 I-1.273 J6.461 E.05631
G3 X155.675 Y117.81 I-2.603 J3.772 E.05146
G2 X157.946 Y120.702 I41.952 J-30.604 E.12202
G2 X162.422 Y124.276 I12.715 J-11.334 E.1909
G3 X164.758 Y125.674 I-13.525 J25.261 E.09034
G3 X165.746 Y127.013 I-1.782 J2.349 E.05597
G3 X166.938 Y130.091 I-681.577 J265.785 E.10951
G2 X170.65 Y135.624 I16.058 J-6.761 E.22236
G3 X172.333 Y137.457 I-17.045 J17.337 E.08259
G3 X172.913 Y139.008 I-2.311 J1.749 E.05572
G1 X172.943 Y139.264 E.00854
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.198 E2.17916
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.199 J.192 E.05096
G3 X83.717 Y136.795 I3.892 J1.884 E.04098
G2 X85.862 Y134.489 I-444.271 J-415.469 E.09678
G2 X89.134 Y128.851 I-12.826 J-11.212 E.20157
G3 X90.062 Y126.493 I23.44 J7.865 E.07787
G3 X91.212 Y125.226 I2.76 J1.348 E.0533
G3 X93.153 Y124.073 I16.121 J24.937 E.06937
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18128
G2 X100.017 Y117.563 I-37.318 J-31.509 E.11228
G3 X101.193 Y116.421 I3.823 J2.758 E.05063
G3 X102.951 Y115.816 I3.187 J6.401 E.05731
G2 X106.448 Y114.887 I-6.458 J-31.366 E.11123
G2 X111.301 Y112.219 I-5.848 J-16.382 E.1709
G3 X113.318 Y110.796 I14.873 J18.942 E.07589
G3 X115.144 Y110.385 I1.637 J3.018 E.05823
G3 X118.166 Y110.526 I-13.445 J320.488 E.09298
G2 X124.623 Y109.462 I.575 J-16.62 E.2024
G3 X127.013 Y108.625 I13.209 J33.898 E.07784
G3 X128.135 Y108.474 I.997 J3.177 E.03493
G3 X129.989 Y108.958 I-.884 J7.195 E.05906
G2 X133.481 Y110.096 I12.106 J-31.208 E.11289
G2 X138.707 Y110.489 I3.893 J-16.812 E.16168
G3 X141.261 Y110.387 I2.31 J25.883 E.07855
G3 X142.884 Y110.921 I-.11 J3.07 E.05321
G3 X144.706 Y112.222 I-15.541 J23.687 E.06879
G2 X149.556 Y114.887 I10.852 J-14.005 E.17076
G2 X153.056 Y115.812 I9.714 J-29.677 E.1113
G3 X154.77 Y116.394 I-1.341 J6.763 E.05579
G3 X155.765 Y117.301 I-2.181 J3.391 E.04156
G2 X157.819 Y119.952 I1371.455 J-1060.338 E.10304
G2 X162.619 Y123.937 I12.924 J-10.683 E.19282
G3 X164.784 Y125.21 I-16.295 J30.193 E.0772
G3 X166.104 Y126.854 I-1.827 J2.82 E.06589
G3 X167.3 Y129.94 I-594.718 J232.201 E.10169
G2 X170.934 Y135.354 I15.7 J-6.612 E.2016
G3 X172.646 Y137.222 I-17.227 J17.512 E.07791
G3 X173.302 Y138.956 I-2.618 J1.98 E.05776
G3 X173.36 Y139.508 I-10.392 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38731
G1 X154.608 Y145.61 E-.07071
; WIPE_END
G1 E-.04 F1800
G1 X154.938 Y144.993 Z7.6 F36000
G1 Z7.2
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.40027
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X156.203 Y146.258 E.09175
G1 X156.645 Y146.063 E.02475
G1 X154.773 Y144.192 E.13569
G2 X154.042 Y142.824 I-19.971 J9.796 E.07955
G1 X157.086 Y145.868 E.22073
G1 X157.528 Y145.673 E.02475
G1 X152.249 Y140.394 E.38274
G1 X160.773 Y144.46 F36000
G1 F3000
G1 X152.456 Y136.143 E.60302
G2 X153.015 Y136.252 I2.081 J-9.218 E.02919
G1 X153.212 Y136.263 E.01015
G1 X161.061 Y144.111 E.56906
G1 X161.503 Y143.916 E.02475
G1 X153.841 Y136.255 E.55547
G2 X154.364 Y136.174 I-.096 J-2.361 E.02719
G1 X154.39 Y136.167 E.00137
G1 X161.944 Y143.721 E.5477
G1 X162.386 Y143.526 E.02475
G1 X154.87 Y136.01 E.54495
G2 X155.319 Y135.822 I-.442 J-1.685 E.02503
G1 X162.827 Y143.331 E.54443
G1 X163.269 Y143.135 E.02475
G1 X155.719 Y135.586 E.5474
G2 X156.083 Y135.312 I-1.03 J-1.747 E.02336
G1 X163.711 Y142.94 E.55307
G1 X164.152 Y142.745 E.02475
G1 X156.41 Y135.003 E.56133
G2 X156.703 Y134.659 I-1.379 J-1.467 E.02321
G1 X164.594 Y142.55 E.57215
G1 X165.035 Y142.355 E.02475
G1 X156.958 Y134.278 E.58563
G2 X157.175 Y133.858 I-1.757 J-1.171 E.02429
G1 X165.477 Y142.16 E.60194
G1 X165.919 Y141.964 E.02475
G1 X157.348 Y133.393 E.62144
G2 X157.464 Y132.873 I-3.179 J-.985 E.02736
G1 X166.36 Y141.769 E.64501
G1 X166.802 Y141.574 E.02475
G1 X157.526 Y132.298 E.67253
G2 X157.484 Y131.62 I-4.626 J-.055 E.03489
G1 X167.243 Y141.379 E.70759
G1 X167.685 Y141.184 E.02475
G1 X157.263 Y130.762 E.75565
G2 X155.225 Y128.533 I-3.806 J1.434 E.15863
G1 X154.9 Y128.398 E.01806
G1 X137.783 Y111.282 E1.24104
G1 X137.153 Y111.289 E.0323
G1 X154.042 Y128.177 E1.22451
G2 X153.363 Y128.135 I-.624 J4.583 E.0349
G1 X136.501 Y111.273 E1.2226
G1 X135.831 Y111.24 E.0344
G1 X152.784 Y128.193 E1.22918
G2 X152.268 Y128.314 I.28 J2.349 E.02721
M73 P81 R3
G1 X135.113 Y111.158 E1.24386
G3 X134.365 Y111.048 I.443 J-5.577 E.03876
G1 X151.804 Y128.486 E1.26439
G2 X151.384 Y128.703 I.875 J2.213 E.02428
G1 X133.579 Y110.899 E1.29091
G1 X132.73 Y110.686 E.04488
G1 X151.003 Y128.959 E1.32485
G2 X150.79 Y129.133 I.803 J1.195 E.01413
G1 X150.658 Y129.251 E.00906
G1 X131.82 Y110.413 E1.36586
G3 X130.847 Y110.076 I3.628 J-12.06 E.05284
G1 X150.349 Y129.579 E1.41405
G2 X150.076 Y129.942 I1.551 J1.451 E.02336
G1 X129.864 Y109.731 E1.46544
G1 X128.902 Y109.405 E.0521
G1 X149.84 Y130.343 E1.51811
G2 X149.644 Y130.784 I1.86 J1.089 E.02479
G1 X128.097 Y109.237 E1.56228
G2 X127.516 Y109.293 I-.045 J2.561 E.02997
G1 X149.494 Y131.271 E1.59352
G2 X149.406 Y131.82 I7.012 J1.406 E.0285
G1 X127.01 Y109.424 E1.62383
G2 X126.53 Y109.58 I1.562 J5.619 E.02591
G1 X149.399 Y132.449 E1.65811
G2 X149.513 Y133.2 I4.383 J-.283 E.03901
G1 X126.063 Y109.75 E1.70028
G1 X125.595 Y109.919 E.02548
G1 X160.178 Y144.502 E2.50741
G1 X159.736 Y144.697 E.02475
G1 X125.128 Y110.089 E2.50928
G3 X124.655 Y110.253 I-2.927 J-7.672 E.02566
G1 X159.294 Y144.892 E2.51153
G1 X158.853 Y145.087 E.02475
G1 X124.176 Y110.41 E2.51426
G3 X123.697 Y110.568 I-2.073 J-5.507 E.02588
G1 X158.411 Y145.282 E2.51701
G1 X157.97 Y145.478 E.02475
G1 X123.035 Y110.543 E2.53295
G1 X122.523 Y110.668 F36000
M73 P82 R3
G1 F3000
G1 X145.268 Y133.412 E1.6491
; WIPE_START
G1 X143.853 Y131.998 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X151.283 Y130.25 Z7.6 F36000
G1 X165.505 Y126.905 Z7.6
G1 Z7.2
G1 E.8 F1800
G1 F3000
G1 X164.72 Y126.12 E.0569
G2 X162.992 Y125.028 I-7.01 J9.183 E.10497
G1 X165.601 Y127.638 E.18922
G3 X165.991 Y128.664 I-17.639 J7.279 E.05627
G1 X160.732 Y123.406 E.38127
; WIPE_START
G1 X162.146 Y124.82 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.749 Y119.423 Z7.6 F36000
G1 X156.516 Y119.19 Z7.6
G1 Z7.2
G1 E.8 F1800
G1 F3000
G1 X154.391 Y117.064 E.15411
G1 X154.163 Y116.941 E.01329
G1 X153.549 Y116.727 E.03333
G1 X153.374 Y116.684 E.00925
G1 X166.373 Y129.684 E.94255
G1 X166.843 Y130.79 E.06161
G1 X152.533 Y116.48 E1.03754
G1 X151.692 Y116.276 E.04435
G1 X167.503 Y132.087 E1.14636
G2 X168.286 Y133.349 I11.559 J-6.294 E.07618
G1 X168.694 Y133.915 E.03579
G1 X150.849 Y116.07 E1.29386
G1 X149.952 Y115.809 E.04791
G1 X172.341 Y138.198 E1.6233
G3 X172.539 Y139.033 I-3.601 J1.296 E.0441
G1 X148.992 Y115.486 E1.70726
G3 X147.914 Y115.045 I2.86 J-8.525 E.05976
G1 X172.101 Y139.232 E1.75368
G1 X171.659 Y139.427 E.02475
G1 X146.642 Y114.41 E1.81391
G3 X144.876 Y113.28 I8.996 J-16.014 E.10755
G1 X171.218 Y139.622 E1.90996
G1 X170.776 Y139.817 E.02475
G1 X142.617 Y111.659 E2.04166
G2 X141.758 Y111.23 I-2.201 J3.336 E.04934
G1 X141.504 Y111.182 E.01325
G1 X170.335 Y140.013 E2.09035
G1 X169.893 Y140.208 E.02475
G1 X140.826 Y111.141 E2.10752
G1 X140.209 Y111.161 E.03163
G1 X169.451 Y140.403 E2.12021
G1 X169.01 Y140.598 E.02475
G1 X139.606 Y111.195 E2.13191
G1 X139.004 Y111.229 E.03092
M73 P83 R3
G1 X168.568 Y140.793 E2.14354
G1 X168.127 Y140.989 E.02475
G1 X138.21 Y111.072 E2.16909
G1 X112.823 Y111.792 F36000
G1 F3000
G1 X124.244 Y123.214 E.82815
G1 X124.161 Y123.012 E.01122
G3 X123.99 Y122.323 I5.43 J-1.712 E.03643
G1 X113.343 Y111.676 E.77195
G3 X113.746 Y111.442 I1.474 J2.076 E.02392
G1 X123.931 Y121.627 E.73845
G3 X123.982 Y121.042 I2.623 J-.065 E.0302
G1 X114.189 Y111.248 E.71006
G3 X114.743 Y111.166 I.665 J2.573 E.02879
G1 X124.098 Y120.521 E.67826
G3 X124.266 Y120.052 I3.385 J.949 E.02555
G1 X115.366 Y111.152 E.64528
G1 X115.604 Y111.158 E.01221
G3 X116.029 Y111.178 I-.139 J7.161 E.02182
G1 X124.478 Y119.628 E.6126
G3 X124.73 Y119.243 I1.969 J1.013 E.02363
G1 X116.701 Y111.213 E.58218
G1 X117.372 Y111.248 E.03448
G1 X125.019 Y118.894 E.55441
G3 X125.343 Y118.582 I1.549 J1.281 E.02314
G1 X118.044 Y111.283 E.52921
G2 X118.688 Y111.29 I.512 J-16.695 E.03303
G1 X125.702 Y118.304 E.50858
G3 X126.099 Y118.064 I1.264 J1.641 E.02382
G1 X119.317 Y111.282 E.49172
G1 X119.924 Y111.252 E.03114
G1 X126.536 Y117.864 E.47942
G3 X127.018 Y117.71 I.926 J2.065 E.02603
G1 X120.51 Y111.202 E.47187
G1 X121.082 Y111.137 E.02948
G1 X127.566 Y117.621 E.47013
G3 X128.177 Y117.596 I.436 J3.143 E.03143
G1 X121.631 Y111.049 E.47464
G1 X122.169 Y110.951 E.02804
G1 X129.202 Y117.983 E.50989
; WIPE_START
G1 X127.787 Y116.569 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.678 Y120.46 Z7.6 F36000
G1 Z7.2
G1 E.8 F1800
G1 F3000
G1 X142.838 Y131.619 E.80913
G2 X141.47 Y130.888 I-11.167 J19.244 E.07955
G1 X132.066 Y121.484 E.68184
G3 X132.051 Y122.106 I-2.769 J.243 E.03194
G1 X140.25 Y130.305 E.59451
G2 X139.145 Y129.837 I-26.747 J61.612 E.06151
G1 X131.951 Y122.643 E.52162
G3 X131.797 Y123.125 I-4.885 J-1.296 E.02598
G1 X138.12 Y129.449 E.45849
G2 X137.156 Y129.121 I-5.163 J13.601 E.05226
G1 X131.597 Y123.562 E.40302
G3 X131.357 Y123.959 I-1.882 J-.868 E.02382
G1 X136.24 Y128.842 E.35403
G1 X135.37 Y128.609 E.04617
G1 X131.08 Y124.319 E.31105
G3 X130.767 Y124.643 I-2.45 J-2.053 E.02311
G1 X134.536 Y128.412 E.2733
G2 X133.732 Y128.245 I-2.797 J11.426 E.04212
G1 X130.419 Y124.931 E.24024
G3 X130.034 Y125.183 I-2.332 J-3.144 E.0236
G1 X132.953 Y128.102 E.21167
G1 X132.197 Y127.982 E.03927
G1 X129.609 Y125.395 E.18758
G3 X129.141 Y125.563 I-.981 J-1.998 E.02558
G1 X131.47 Y127.892 E.16886
G2 X130.759 Y127.818 I-1.414 J10.135 E.03664
G1 X128.62 Y125.679 E.15509
G3 X128.034 Y125.731 I-.52 J-2.571 E.0302
G1 X130.062 Y127.759 E.14704
G1 X129.39 Y127.723 E.0345
G1 X127.332 Y125.665 E.14924
G3 X126.447 Y125.417 I.334 J-2.895 E.04731
G1 X128.73 Y127.7 E.16553
G1 X128.082 Y127.689 E.03323
G1 X112.6 Y112.207 E1.12249
G1 X112.233 Y112.477 E.02335
G1 X127.453 Y127.697 E1.10353
G2 X126.832 Y127.712 I-.093 J8.907 E.03188
G1 X111.866 Y112.746 E1.08508
G1 X111.499 Y113.016 E.02335
G1 X126.227 Y127.744 E1.06782
G2 X125.631 Y127.785 I.29 J8.549 E.03062
G1 X111.128 Y113.282 E1.05155
G1 X110.752 Y113.542 E.02347
M73 P84 R3
G1 X125.045 Y127.836 E1.03639
G2 X124.474 Y127.901 I.664 J8.327 E.02949
G1 X110.37 Y113.797 E1.02261
G1 X109.981 Y114.045 E.02364
G1 X123.909 Y127.973 E1.00982
G2 X123.354 Y128.054 I1.028 J8.933 E.02878
G1 X109.581 Y114.282 E.9986
G3 X109.172 Y114.51 I-2.343 J-3.724 E.02401
G1 X122.804 Y128.142 E.98839
G2 X122.271 Y128.245 I1.261 J7.928 E.02786
G1 X108.752 Y114.727 E.98015
G3 X108.33 Y114.941 I-1.792 J-3.006 E.0243
G1 X121.738 Y128.35 E.97219
G1 X121.221 Y128.469 E.02722
G1 X107.886 Y115.134 E.96687
G1 X107.442 Y115.327 E.02482
G1 X120.705 Y128.59 E.96165
G1 X120.203 Y128.724 E.02666
G1 X106.977 Y115.499 E.95892
G1 X106.509 Y115.667 E.02552
G1 X119.702 Y128.86 E.95656
G1 X119.214 Y129.009 E.02615
G1 X106.023 Y115.818 E.95643
G1 X105.53 Y115.962 E.02634
G1 X118.727 Y129.159 E.95687
G1 X118.253 Y129.322 E.02568
G1 X105.033 Y116.102 E.95854
G1 X104.519 Y116.224 E.02709
G1 X117.78 Y129.485 E.96146
G2 X117.539 Y129.576 I1.184 J3.486 E.01322
G1 X117.319 Y129.661 E.01208
G1 X104.005 Y116.347 E.96531
G1 X103.491 Y116.47 E.02709
G1 X116.858 Y129.837 E.96921
G2 X116.409 Y130.025 I2.453 J6.517 E.02497
G1 X102.98 Y116.596 E.97367
G1 X102.476 Y116.728 E.02673
G1 X115.962 Y130.215 E.97781
G2 X115.523 Y130.413 I2.622 J6.384 E.02468
G1 X102.004 Y116.893 E.98024
G2 X101.568 Y117.094 I.411 J1.469 E.02472
G1 X115.089 Y130.615 E.98038
G2 X114.661 Y130.824 I2.767 J6.228 E.02443
G1 X101.205 Y117.368 E.97559
G1 X101.191 Y117.38 E.00093
G1 X100.899 Y117.699 E.02218
G1 X114.239 Y131.039 E.96723
G2 X113.82 Y131.257 I2.916 J6.103 E.0242
G1 X100.615 Y118.051 E.95747
G1 X100.339 Y118.413 E.02329
G1 X113.411 Y131.484 E.94775
G2 X113.002 Y131.712 I3.072 J6.007 E.02401
G1 X100.064 Y118.774 E.93806
G1 X99.788 Y119.135 E.02329
G1 X112.604 Y131.951 E.9292
G1 X112.206 Y132.19 E.02379
G1 X99.513 Y119.496 E.92035
G1 X99.237 Y119.857 E.02329
G1 X111.817 Y132.438 E.91216
G1 X111.431 Y132.688 E.0236
G1 X98.951 Y120.208 E.90488
G1 X98.662 Y120.556 E.02318
M73 P85 R3
G1 X111.051 Y132.945 E.8983
G1 X110.677 Y133.207 E.02344
M73 P85 R2
G1 X98.372 Y120.903 E.89212
G3 X98.066 Y121.233 I-2.838 J-2.327 E.02312
G1 X110.305 Y133.472 E.88737
G1 X109.941 Y133.746 E.02331
G1 X97.614 Y121.418 E.89383
; WIPE_START
G1 X99.028 Y122.832 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X101.487 Y130.058 Z7.6 F36000
G1 X104.614 Y139.244 Z7.6
G1 Z7.2
G1 E.8 F1800
G1 F3000
G1 X101.506 Y136.136 E.22537
G2 X102.268 Y136.261 I1.078 J-4.174 E.03966
G1 X104.755 Y138.748 E.18032
G1 X105.04 Y138.396 E.02321
G1 X102.901 Y136.257 E.15512
G2 X103.453 Y136.174 I-.089 J-2.494 E.02867
G1 X105.336 Y138.055 E.13647
G1 X105.632 Y137.715 E.02314
G1 X103.944 Y136.026 E.12242
G2 X104.387 Y135.833 I-.638 J-2.063 E.02484
G1 X105.936 Y137.382 E.11231
G1 X106.243 Y137.052 E.0231
G1 X104.79 Y135.598 E.10541
G2 X105.155 Y135.327 I-1.024 J-1.757 E.02338
G1 X106.555 Y136.727 E.1015
G1 X106.873 Y136.408 E.02309
G1 X105.484 Y135.019 E.1007
G2 X105.778 Y134.677 I-1.373 J-1.476 E.0232
G1 X107.192 Y136.09 E.10249
G1 X107.521 Y135.783 E.0231
G1 X106.036 Y134.297 E.1077
G2 X106.254 Y133.879 I-1.747 J-1.179 E.02425
G1 X107.851 Y135.476 E.11575
G1 X108.19 Y135.178 E.02313
G1 X106.429 Y133.417 E.12768
G2 X106.553 Y132.904 I-2.216 J-.805 E.02712
G1 X108.529 Y134.881 E.14333
G3 X108.874 Y134.588 I3.958 J4.31 E.02317
G1 X106.613 Y132.327 E.16393
G2 X106.579 Y131.657 I-4.684 J-.099 E.03447
G1 X109.226 Y134.303 E.19191
G3 X109.578 Y134.019 I4.251 J4.918 E.02322
G1 X106.373 Y130.814 E.23241
G2 X106.065 Y130.162 I-3.052 J1.043 E.03707
G2 X103.936 Y128.377 I-3.547 J2.069 E.1453
G1 X97.437 Y121.878 E.47116
G1 X97.108 Y122.186 E.0231
G1 X103.093 Y128.171 E.43396
G2 X102.546 Y128.13 I-.455 J2.406 E.02817
G1 X102.422 Y128.137 E.00637
G1 X96.777 Y122.491 E.40935
G1 X96.426 Y122.777 E.02321
G1 X101.85 Y128.202 E.39333
G2 X101.333 Y128.321 I.163 J1.894 E.02733
G1 X96.074 Y123.062 E.38125
G3 X95.712 Y123.336 I-2.74 J-3.251 E.02332
G1 X100.871 Y128.495 E.37406
G2 X100.767 Y128.54 I.134 J.455 E.0058
G1 X100.452 Y128.714 E.01843
G1 X95.342 Y123.603 E.37055
G1 X94.961 Y123.859 E.02352
G1 X100.073 Y128.972 E.37067
G2 X99.73 Y129.266 I1.135 J1.669 E.0232
G1 X94.572 Y124.107 E.37401
G1 X94.179 Y124.351 E.02371
G1 X99.423 Y129.595 E.38024
G2 X99.151 Y129.96 I1.485 J1.389 E.02338
G1 X93.779 Y124.588 E.38951
G1 X93.376 Y124.821 E.0239
G1 X98.917 Y130.363 E.40179
G2 X98.782 Y130.664 I1.27 J.75 E.01698
G1 X98.723 Y130.806 E.00785
G1 X92.972 Y125.054 E.41701
G1 X92.568 Y125.287 E.0239
G1 X98.576 Y131.295 E.43558
G2 X98.493 Y131.849 I7.77 J1.444 E.02872
G1 X92.165 Y125.52 E.45884
G1 X91.776 Y125.769 E.02364
G1 X98.489 Y132.481 E.4867
G2 X98.614 Y133.243 I4.207 J-.299 E.03963
G1 X91.407 Y126.037 E.52252
G2 X91.075 Y126.341 I.828 J1.234 E.0232
G1 X104.193 Y139.46 E.95113
G1 X103.92 Y139.823 E.02331
G1 X90.811 Y126.714 E.95044
G1 X90.6 Y127.14 E.02437
G1 X103.651 Y140.19 E.94621
G1 X103.388 Y140.565 E.02344
G1 X90.416 Y127.592 E.94059
G2 X90.239 Y128.052 I8.435 J3.512 E.02526
G1 X103.127 Y140.941 E.9345
G1 X102.877 Y141.327 E.0236
G1 X90.066 Y128.516 E.92884
G1 X89.893 Y128.98 E.02539
G1 X102.626 Y141.713 E.92318
G2 X102.385 Y142.109 I5.548 J3.648 E.02376
G1 X89.721 Y129.444 E.91823
G3 X89.541 Y129.901 I-6.252 J-2.204 E.02517
G1 X102.146 Y142.506 E.91396
G2 X101.914 Y142.911 I5.67 J3.52 E.02392
G1 X89.354 Y130.351 E.91067
G3 X89.157 Y130.791 I-4.631 J-1.811 E.02471
G1 X101.687 Y143.321 E.90849
G2 X101.464 Y143.735 I5.82 J3.401 E.02411
G1 X88.952 Y131.223 E.90715
G3 X88.739 Y131.646 I-3.575 J-1.538 E.02432
G1 X101.249 Y144.157 E.90705
G2 X101.036 Y144.58 I5.957 J3.265 E.02432
G1 X88.513 Y132.057 E.90796
G3 X88.285 Y132.466 I-11.592 J-6.211 E.02399
G1 X100.833 Y145.014 E.90983
G1 X100.631 Y145.449 E.02457
G1 X88.036 Y132.854 E.91318
G1 X87.787 Y133.242 E.02363
M73 P86 R2
G1 X100.444 Y145.898 E.91765
G1 X100.258 Y146.349 E.025
G1 X87.525 Y133.617 E.92315
G3 X87.257 Y133.985 I-4.628 J-3.1 E.02337
G1 X99.315 Y146.044 E.87433
G1 X98.175 Y145.539 E.06395
G1 X86.976 Y134.341 E.81193
G3 X86.687 Y134.688 I-3.664 J-2.765 E.02319
G1 X97.034 Y145.035 E.75022
G1 X95.893 Y144.531 E.06395
G1 X86.39 Y135.029 E.68897
G1 X86.094 Y135.37 E.02314
G1 X94.752 Y144.027 E.62772
G1 X93.611 Y143.523 E.06395
G1 X85.789 Y135.701 E.56714
G1 X85.481 Y136.029 E.0231
G1 X92.47 Y143.019 E.50677
G1 X91.329 Y142.515 E.06395
G1 X85.172 Y136.358 E.44641
G1 X84.864 Y136.686 E.0231
G1 X90.188 Y142.01 E.38604
G1 X89.047 Y141.506 E.06395
G1 X84.555 Y137.015 E.32567
G2 X84.251 Y137.347 I1.713 J1.872 E.02314
G1 X87.906 Y141.002 E.265
G1 X86.765 Y140.498 E.06395
G1 X83.971 Y137.704 E.20257
G2 X83.717 Y138.087 I1.233 J1.094 E.02363
G1 X85.624 Y139.994 E.13827
G1 X84.483 Y139.49 E.06395
G1 X83.377 Y138.384 E.08019
; CHANGE_LAYER
; Z_HEIGHT: 7.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X84.483 Y139.49 E-.59435
G1 X84.882 Y139.666 E-.16565
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
G1 X124.328 Y121.217
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X124.431 Y120.727 E.01661
G3 X127.702 Y117.973 I3.58 J.934 E.15123
G3 X129.609 Y118.323 I.291 J3.785 E.06502
G3 X124.331 Y121.276 I-1.598 J3.337 E.53636
G1 X124.714 Y121.283 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.786 Y120.925 E.01122
G3 X127.724 Y118.364 I3.225 J.735 E.12806
G3 X129.096 Y118.535 I.294 J3.237 E.04278
G3 X124.72 Y121.337 I-1.084 J3.125 E.45496
; WIPE_START
M204 S10000
G1 X124.786 Y120.925 E-.15845
G1 X124.878 Y120.566 E-.14089
G1 X125.02 Y120.223 E-.1411
G1 X125.199 Y119.898 E-.14101
G1 X125.414 Y119.595 E-.14108
G1 X125.48 Y119.522 E-.03747
; WIPE_END
G1 E-.04 F1800
G1 X132.627 Y122.201 Z7.8 F36000
G1 X157.063 Y131.36 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.067 Y131.38 E.00066
G3 X153.044 Y128.524 I-3.609 J.822 E.59234
G1 X153.458 Y128.5 E.01377
G3 X156.953 Y130.98 I0 J3.702 E.15159
G1 X157.046 Y131.302 E.01112
G1 X156.683 Y131.457 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.00031
G3 X153.088 Y128.914 I-3.225 J.734 E.49027
G1 X153.458 Y128.893 E.01141
G3 X156.581 Y131.111 I0 J3.308 E.12552
G1 X156.666 Y131.399 E.00925
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.02662
G1 X156.748 Y131.833 E-.14106
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.1411
G1 X156.583 Y133.297 E-.14104
G1 X156.554 Y133.365 E-.02808
; WIPE_END
G1 E-.04 F1800
G1 X148.953 Y132.68 Z7.8 F36000
G1 X102.612 Y128.504 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.96 Y128.53 E.0116
G3 X104.153 Y128.867 I-.423 J3.773 E.0413
G3 X102.247 Y128.517 I-1.598 J3.337 E.70613
G3 X102.546 Y128.506 I.291 J3.785 E.00996
G1 X102.552 Y128.506 E.00018
G1 X102.211 Y128.917 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.269 Y128.909 E.00178
G3 X103.64 Y129.079 I.295 J3.237 E.04278
G3 X101.811 Y128.981 I-1.084 J3.125 E.58159
G1 X102.152 Y128.926 E.01061
; WIPE_START
M204 S10000
G1 X102.269 Y128.909 E-.04481
G1 X102.269 Y128.909 E0
G1 X102.546 Y128.893 E-.10576
G1 X102.917 Y128.914 E-.14105
G1 X103.283 Y128.976 E-.14109
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.087 Y129.278 E-.04518
; WIPE_END
G1 E-.04 F1800
G1 X111.307 Y131.753 Z7.8 F36000
G1 X155.589 Y146.934 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.721 E2.3565
G1 X83.055 Y139.263 E.6296
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.65 I5.973 J3.758 E.05162
G2 X86.79 Y133.985 I-24.74 J-24.825 E.1193
G2 X89.501 Y128.988 I-13.844 J-10.746 E.18944
G3 X90.41 Y126.674 I23.316 J7.82 E.0825
G3 X91.435 Y125.548 I2.418 J1.171 E.05122
G3 X93.349 Y124.413 I15.947 J24.697 E.07382
G2 X98.059 Y120.702 I-8.564 J-15.715 E.19987
G2 X100.325 Y117.806 I-37.408 J-31.607 E.12198
G3 X101.394 Y116.758 I3.535 J2.534 E.04993
G3 X103.044 Y116.197 I3.009 J6.143 E.05796
G2 X106.577 Y115.257 I-6.544 J-31.728 E.12134
G2 X111.534 Y112.534 I-5.974 J-16.747 E.18841
G3 X113.513 Y111.136 I14.719 J18.737 E.08042
G3 X115.145 Y110.777 I1.449 J2.701 E.05612
G3 X117.853 Y110.909 I-7.768 J188.267 E.08995
G2 X124.754 Y109.831 I.851 J-17.19 E.2333
G3 X127.354 Y108.943 I11.099 J28.225 E.09118
G3 X128.114 Y108.866 I.679 J2.923 E.02541
G3 X129.858 Y109.327 I-.885 J6.877 E.06001
G2 X133.389 Y110.477 I12.214 J-31.504 E.12326
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.237 Y110.779 I2.302 J25.749 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.375 J23.407 E.07316
G2 X149.427 Y115.257 I11.081 J-14.315 E.18822
G2 X152.965 Y116.193 I9.837 J-30.032 E.12145
G3 X154.575 Y116.734 I-1.256 J6.404 E.0565
G3 X155.675 Y117.81 I-2.619 J3.778 E.05127
G2 X157.946 Y120.702 I41.95 J-30.602 E.122
G2 X162.421 Y124.276 I12.716 J-11.334 E.19091
G3 X164.757 Y125.673 I-13.532 J25.274 E.09034
G3 X165.746 Y127.013 I-1.781 J2.349 E.05598
G3 X166.938 Y130.092 I-673.611 J262.705 E.10952
G2 X170.649 Y135.623 I16.058 J-6.762 E.22233
G3 X172.333 Y137.457 I-17.041 J17.334 E.0826
G3 X172.913 Y139.009 I-2.311 J1.749 E.05573
G1 X172.943 Y139.264 E.00853
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.197 E2.17917
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.199 J.192 E.05096
G3 X83.717 Y136.795 I3.894 J1.885 E.041
G2 X85.861 Y134.49 I-444.31 J-415.52 E.09673
G2 X89.134 Y128.851 I-12.825 J-11.212 E.2016
G3 X90.062 Y126.493 I23.446 J7.867 E.07787
G3 X91.212 Y125.226 I2.76 J1.348 E.0533
G3 X93.152 Y124.073 I16.128 J24.948 E.06936
G2 X97.766 Y120.441 I-8.372 J-15.381 E.18128
G2 X100.017 Y117.563 I-37.327 J-31.517 E.11231
G3 X101.193 Y116.421 I3.821 J2.757 E.05061
G3 X102.951 Y115.816 I3.187 J6.403 E.0573
G2 X106.449 Y114.887 I-6.458 J-31.366 E.11125
G2 X111.301 Y112.219 I-5.849 J-16.383 E.17089
G3 X113.32 Y110.795 I14.854 J18.917 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.452 J182.456 E.08377
G2 X124.623 Y109.462 I.837 J-16.796 E.21158
G3 X127.013 Y108.625 I13.211 J33.903 E.07784
G3 X128.135 Y108.474 I1 J3.199 E.03494
G3 X129.989 Y108.958 I-.885 J7.197 E.05906
G2 X133.481 Y110.096 I12.106 J-31.207 E.11289
G2 X138.707 Y110.489 I3.893 J-16.812 E.16168
G3 X141.261 Y110.387 I2.31 J25.878 E.07855
G3 X142.885 Y110.921 I-.11 J3.07 E.05323
G3 X144.706 Y112.222 I-15.536 J23.679 E.06877
G2 X149.556 Y114.887 I10.853 J-14.006 E.17076
G2 X153.056 Y115.812 I9.716 J-29.685 E.11131
G3 X154.776 Y116.398 I-1.325 J6.708 E.05599
G3 X155.981 Y117.565 I-2.796 J4.091 E.05181
G2 X158.238 Y120.441 I41.9 J-30.563 E.11236
G2 X162.618 Y123.937 I12.424 J-11.074 E.17301
G3 X164.784 Y125.21 I-16.319 J30.234 E.07721
G3 X166.104 Y126.854 I-1.827 J2.82 E.06589
G3 X167.3 Y129.94 I-593.081 J231.569 E.10169
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.229 J17.514 E.07791
G3 X173.302 Y138.956 I-2.618 J1.981 E.05777
G3 X173.36 Y139.508 I-10.391 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30198
G1 X154.687 Y145.778 E-.38732
G1 X154.608 Y145.61 E-.0707
; WIPE_END
G1 E-.04 F1800
G1 X156.194 Y146.488 Z7.8 F36000
G1 Z7.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42196
G1 F15000
G1 X155.463 Y145.757 E.03193
G2 X155.022 Y144.779 I-11.201 J4.47 E.03313
G1 X156.437 Y146.195 E.06182
G1 X156.809 Y146.031 E.01255
G1 X154.486 Y143.708 E.10145
G2 X153.809 Y142.495 I-36.17 J19.389 E.0429
G1 X157.18 Y145.866 E.14725
G1 X157.552 Y145.702 E.01255
G1 X152.913 Y141.063 E.20263
G2 X151.492 Y139.106 I-18.151 J11.685 E.07475
G1 X158.053 Y145.666 E.28657
G1 X160.655 Y144.516 F36000
G1 F15000
G1 X152.163 Y136.025 E.37092
G2 X152.865 Y136.191 I1.089 J-3.033 E.02234
G1 X160.898 Y144.223 E.35087
G1 X161.27 Y144.059 E.01255
G1 X153.45 Y136.24 E.34155
G2 X153.954 Y136.207 I-.479 J-11.384 E.01559
G1 X161.641 Y143.895 E.33579
G1 X162.013 Y143.73 E.01255
G1 X154.407 Y136.124 E.33224
G2 X154.82 Y136.002 I-.337 J-1.891 E.01334
G1 X162.385 Y143.566 E.33042
G1 X162.757 Y143.402 E.01255
G1 X155.199 Y135.845 E.3301
G2 X155.546 Y135.655 I-.675 J-1.641 E.01222
G1 X163.128 Y143.237 E.33122
G1 X163.5 Y143.073 E.01255
G1 X155.865 Y135.438 E.33352
G2 X156.158 Y135.195 I-.928 J-1.425 E.01179
G1 X163.872 Y142.909 E.33693
G1 X164.244 Y142.745 E.01255
G1 X156.428 Y134.929 E.3414
G2 X156.673 Y134.638 I-1.169 J-1.232 E.01178
G1 X164.615 Y142.58 E.34694
G1 X164.987 Y142.416 E.01255
G1 X156.892 Y134.321 E.35357
G1 X157.083 Y133.976 E.01218
G1 X165.359 Y142.252 E.36148
G1 X165.731 Y142.087 E.01255
G1 X157.242 Y133.599 E.37077
G2 X157.368 Y133.189 I-1.757 J-.765 E.01328
G1 X166.102 Y141.923 E.3815
G1 X166.474 Y141.759 E.01255
G1 X157.455 Y132.74 E.39395
G2 X157.493 Y132.242 I-2.195 J-.416 E.01547
G1 X166.846 Y141.594 E.40854
G1 X167.217 Y141.43 E.01255
G1 X157.455 Y131.668 E.42641
G2 X157.299 Y130.975 I-3.151 J.349 E.02198
G1 X167.718 Y141.395 E.45512
; WIPE_START
G1 X166.304 Y139.98 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X159.043 Y137.629 Z7.8 F36000
G1 X129.041 Y127.911 Z7.8
G1 Z7.4
G1 E.8 F1800
G1 F15000
G1 X126.549 Y125.42 E.10885
G2 X127.285 Y125.619 I1.31 J-3.37 E.02359
G1 X129.427 Y127.762 E.09359
G1 X129.993 Y127.791 E.0175
G1 X127.891 Y125.69 E.09181
G2 X128.41 Y125.673 I.186 J-2.312 E.01608
G1 X130.577 Y127.839 E.09462
G3 X131.165 Y127.892 I-.459 J8.437 E.01826
G1 X128.873 Y125.599 E.10013
G2 X129.292 Y125.482 I-.312 J-1.918 E.01346
G1 X131.776 Y127.967 E.10854
G3 X132.397 Y128.051 I-.896 J8.917 E.01934
G1 X129.675 Y125.329 E.11891
G2 X130.027 Y125.145 I-.639 J-1.656 E.0123
G1 X133.034 Y128.152 E.13134
G3 X133.692 Y128.274 I-1.416 J9.483 E.02067
G1 X130.352 Y124.934 E.14589
G2 X130.651 Y124.697 I-.9 J-1.446 E.01181
G1 X134.363 Y128.409 E.16214
G1 X135.06 Y128.57 E.02209
G1 X130.926 Y124.436 E.18058
G2 X131.176 Y124.151 I-1.142 J-1.255 E.01176
G1 X135.783 Y128.757 E.20122
G3 X136.529 Y128.968 I-2.642 J10.804 E.02396
G1 X131.399 Y123.837 E.22411
G2 X131.593 Y123.495 I-1.419 J-1.03 E.01217
G1 X137.304 Y129.207 E.24949
G1 X138.122 Y129.488 E.02671
M73 P87 R2
G1 X131.758 Y123.124 E.27798
G2 X131.891 Y122.721 I-1.724 J-.791 E.01314
G1 X138.984 Y129.814 E.30985
G3 X139.899 Y130.193 I-4.963 J13.278 E.0306
G1 X131.985 Y122.279 E.3457
G2 X132.032 Y121.79 I-2.148 J-.451 E.01522
G1 X140.882 Y130.64 E.38658
G3 X141.953 Y131.175 I-7.127 J15.602 E.03701
G1 X132.015 Y121.237 E.4341
G2 X131.882 Y120.568 I-5.137 J.674 E.02109
G1 X143.662 Y132.348 E.51455
G1 X153.562 Y116.517 F36000
G1 F15000
G1 X157.666 Y120.621 E.17927
; WIPE_START
G1 X156.251 Y119.207 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X162.138 Y124.066 Z7.8 F36000
G1 X165.461 Y126.809 Z7.8
G1 Z7.4
G1 E.8 F1800
G1 F15000
G1 X164.748 Y126.095 E.03115
G2 X163.251 Y125.135 I-6.315 J8.192 E.055
G1 X165.563 Y127.446 E.10096
G3 X165.901 Y128.321 I-15.024 J6.317 E.02897
G1 X161.973 Y124.392 E.1716
G3 X160.449 Y123.405 I9.781 J-16.76 E.05608
G1 X166.222 Y129.178 E.25214
G2 X166.576 Y130.068 I10.488 J-3.658 E.02961
G1 X153.084 Y116.576 E.58932
G1 X152.377 Y116.405 E.02249
G1 X166.996 Y131.024 E.63856
G2 X167.573 Y132.137 I10.88 J-4.936 E.03876
G1 X151.669 Y116.233 E.6947
G1 X150.962 Y116.061 E.02249
G1 X168.543 Y133.642 E.76795
G2 X170.011 Y135.429 I15.85 J-11.532 E.07146
G1 X171.742 Y137.264 E.07793
G1 X172.175 Y137.811 E.02156
G1 X150.21 Y115.846 E.95944
G3 X149.434 Y115.606 I1.539 J-6.352 E.02511
G1 X172.519 Y138.691 E1.00836
G3 X172.579 Y139.06 I-1.956 J.509 E.01157
G1 X172.422 Y139.13 E.00532
G1 X148.591 Y115.299 E1.04094
G1 X147.644 Y114.888 E.0319
G1 X172.05 Y139.294 E1.06608
G1 X171.678 Y139.459 E.01255
G1 X146.505 Y114.285 E1.0996
G3 X145.013 Y113.33 I7.615 J-13.53 E.05473
G1 X171.307 Y139.623 E1.14851
G1 X170.935 Y139.787 E.01255
G1 X143.067 Y111.92 E1.21728
G2 X141.941 Y111.249 I-4.041 J5.508 E.04054
G1 X141.82 Y111.208 E.00394
G1 X170.563 Y139.951 E1.25552
G1 X170.191 Y140.116 E.01255
G1 X141.194 Y111.118 E1.26664
G2 X140.65 Y111.11 I-.326 J3.61 E.01682
G1 X169.82 Y140.28 E1.27417
G1 X169.448 Y140.444 E.01255
G1 X140.132 Y111.128 E1.28056
G1 X139.625 Y111.157 E.01568
G1 X169.076 Y140.609 E1.28646
G1 X168.704 Y140.773 E.01255
G1 X139.118 Y111.186 E1.29236
G1 X138.611 Y111.216 E.01568
G1 X168.333 Y140.937 E1.29827
G1 X167.961 Y141.102 E.01255
G1 X138.101 Y111.242 E1.30429
G1 X137.571 Y111.248 E.01638
G1 X154.686 Y128.363 E.74759
G2 X153.993 Y128.206 I-1.041 J2.995 E.02198
G1 X137.041 Y111.253 E.7405
G3 X136.487 Y111.236 I-.133 J-4.563 E.01712
G1 X153.42 Y128.169 E.73963
G2 X152.921 Y128.206 I-.082 J2.231 E.01547
G1 X135.923 Y111.208 E.7425
G3 X135.325 Y111.146 I.181 J-4.678 E.01857
G1 X152.472 Y128.293 E.74899
G2 X152.062 Y128.419 I.354 J1.882 E.01328
G1 X134.719 Y111.076 E.75757
G1 X134.062 Y110.955 E.02062
G1 X151.685 Y128.578 E.76978
G1 X151.34 Y128.769 E.01218
G1 X133.383 Y110.812 E.78437
G1 X132.668 Y110.633 E.02276
G1 X151.024 Y128.989 E.80177
G2 X150.733 Y129.234 I.943 J1.415 E.01178
G1 X131.898 Y110.399 E.82272
G3 X131.084 Y110.121 I2.99 J-10.095 E.02656
G1 X150.466 Y129.503 E.84661
G2 X150.224 Y129.797 I1.184 J1.222 E.01179
G1 X130.257 Y109.83 E.87215
G1 X129.43 Y109.539 E.02707
G1 X150.007 Y130.116 E.89879
G2 X149.817 Y130.462 I1.443 J1.017 E.01222
G1 X128.658 Y109.303 E.92425
G2 X128.016 Y109.198 I-.873 J3.317 E.0201
G1 X149.66 Y130.841 E.9454
G2 X149.542 Y131.259 I4.726 J1.556 E.01343
G1 X127.534 Y109.252 E.96131
G2 X127.103 Y109.357 I.389 J2.537 E.01372
G1 X149.455 Y131.708 E.97632
G1 X149.422 Y132.211 E.01558
G1 X126.695 Y109.485 E.9927
G2 X126.3 Y109.625 I1.417 J4.628 E.01297
G1 X149.471 Y132.796 E1.01213
G2 X149.649 Y133.51 I3.486 J-.491 E.02278
G1 X125.906 Y109.768 E1.0371
G1 X125.513 Y109.91 E.01292
G1 X160.154 Y144.552 E1.51317
G1 X159.783 Y144.716 E.01255
G1 X125.12 Y110.053 E1.51411
G3 X124.723 Y110.192 I-2.488 J-6.458 E.01299
G1 X159.411 Y144.88 E1.51521
G1 X159.039 Y145.045 E.01255
G1 X124.319 Y110.325 E1.51659
G1 X123.916 Y110.457 E.01312
G1 X158.667 Y145.209 E1.51798
G1 X158.296 Y145.373 E.01255
G1 X123.506 Y110.583 E1.51965
G1 X123.087 Y110.701 E.01343
G1 X146.556 Y134.17 E1.02513
G2 X144.598 Y132.748 I-13.633 J16.717 E.07475
G1 X122.657 Y110.806 E.95844
G3 X122.219 Y110.904 I-1.128 J-4.01 E.01387
G1 X129.093 Y117.779 E.30029
G2 X128.424 Y117.646 I-1.343 J5.004 E.02108
G1 X121.766 Y110.988 E.29084
G1 X121.313 Y111.071 E.01422
G1 X127.872 Y117.63 E.2865
G2 X127.388 Y117.682 I.054 J2.773 E.01505
G1 X120.834 Y111.128 E.28626
G1 X120.353 Y111.183 E.01495
G1 X126.941 Y117.771 E.28773
G2 X126.537 Y117.903 I.387 J1.855 E.01314
G1 X119.853 Y111.219 E.29197
G1 X119.343 Y111.245 E.01579
G1 X126.167 Y118.069 E.29808
G2 X125.824 Y118.263 I.688 J1.613 E.01217
G1 X118.814 Y111.252 E.30622
G1 X118.272 Y111.246 E.01673
G1 X125.511 Y118.485 E.31619
G2 X125.225 Y118.736 I.971 J1.395 E.01176
G1 X117.725 Y111.235 E.32761
G1 X117.158 Y111.204 E.01756
G1 X124.964 Y119.01 E.34099
G2 X124.727 Y119.31 I1.211 J1.201 E.01181
G1 X116.59 Y111.172 E.35544
G1 X116.023 Y111.141 E.01755
G1 X124.516 Y119.635 E.371
G2 X124.332 Y119.987 I1.472 J.992 E.0123
G1 X115.466 Y111.12 E.38731
G2 X114.93 Y111.121 I-.261 J3.563 E.01654
G1 X124.179 Y120.37 E.404
G2 X124.07 Y120.797 I2.367 J.832 E.01363
G1 X114.436 Y111.162 E.42084
G2 X114.006 Y111.269 I.2 J1.732 E.01371
G1 X123.988 Y121.251 E.43604
G2 X123.972 Y121.77 I2.295 J.334 E.01608
G1 X113.65 Y111.448 E.45088
G1 X113.316 Y111.651 E.01205
G1 X124.035 Y122.369 E.46821
G2 X124.254 Y123.125 I3.417 J-.584 E.02436
G1 X113.002 Y111.873 E.49151
G1 X112.693 Y112.099 E.01185
G1 X128.322 Y127.729 E.68273
G2 X127.785 Y127.727 I-.295 J7.698 E.01662
G1 X112.383 Y112.326 E.67276
G1 X112.073 Y112.552 E.01185
G1 X127.258 Y127.737 E.66327
G2 X126.738 Y127.753 I-.02 J7.447 E.01605
G1 X111.764 Y112.778 E.65411
G1 X111.454 Y113.005 E.01185
G1 X126.229 Y127.78 E.64539
G2 X125.726 Y127.813 I.221 J7.226 E.01558
G1 X111.14 Y113.227 E.63711
G1 X110.821 Y113.444 E.01192
G1 X125.233 Y127.856 E.62951
G2 X124.745 Y127.904 I.382 J6.443 E.01516
G1 X110.502 Y113.662 E.62211
G3 X110.181 Y113.876 I-2.029 J-2.684 E.01194
G1 X124.269 Y127.964 E.61534
G1 X123.793 Y128.024 E.01482
G1 X109.846 Y114.077 E.60919
G1 X109.511 Y114.278 E.01207
G1 X123.328 Y128.095 E.60355
G1 X122.865 Y128.169 E.01447
M73 P88 R2
G1 X109.168 Y114.471 E.59833
G1 X108.814 Y114.654 E.01229
G1 X122.415 Y128.254 E.59408
G1 X121.966 Y128.341 E.01412
G1 X108.461 Y114.836 E.58991
G3 X108.093 Y115.004 I-1.425 J-2.633 E.0125
G1 X121.525 Y128.436 E.58672
G1 X121.089 Y128.537 E.01381
G1 X107.719 Y115.167 E.58402
G3 X107.345 Y115.328 I-1.439 J-2.818 E.0126
G1 X120.657 Y128.64 E.58149
G1 X120.234 Y128.754 E.01352
G1 X106.95 Y115.47 E.58025
G1 X106.556 Y115.612 E.01294
G1 X119.812 Y128.867 E.57901
G2 X119.399 Y128.991 I1.571 J5.982 E.0133
G1 X106.151 Y115.743 E.57868
G1 X105.736 Y115.864 E.01336
G1 X118.989 Y129.116 E.57889
G2 X118.583 Y129.247 I1.663 J5.864 E.01316
G1 X105.321 Y115.984 E.57931
G3 X104.897 Y116.097 I-1.37 J-4.315 E.01355
G1 X118.184 Y129.384 E.58041
G1 X117.786 Y129.521 E.01303
G1 X104.464 Y116.2 E.58189
G1 X104.032 Y116.303 E.01374
G1 X117.398 Y129.669 E.58384
G1 X117.01 Y129.818 E.01282
G1 X103.599 Y116.407 E.58582
G1 X103.166 Y116.51 E.01374
G1 X116.628 Y129.972 E.58801
G1 X116.251 Y130.131 E.01263
G1 X102.741 Y116.621 E.59014
G2 X102.325 Y116.741 I.522 J2.586 E.01339
G1 X115.875 Y130.291 E.59187
G2 X115.508 Y130.46 I2.249 J5.364 E.01248
G1 X101.929 Y116.881 E.59315
G2 X101.566 Y117.054 I.36 J1.227 E.01248
G1 X115.143 Y130.631 E.59306
G2 X114.78 Y130.804 I2.302 J5.281 E.01242
G1 X101.256 Y117.28 E.59074
G2 X100.988 Y117.548 I.806 J1.075 E.01175
G1 X114.425 Y130.985 E.58694
G1 X114.07 Y131.166 E.01231
G1 X100.736 Y117.832 E.58242
G1 X100.504 Y118.136 E.01181
G1 X113.721 Y131.354 E.57733
G1 X113.376 Y131.545 E.01218
G1 X100.272 Y118.44 E.5724
G1 X100.04 Y118.744 E.01181
G1 X113.032 Y131.736 E.56748
G1 X112.697 Y131.937 E.01207
G1 X99.808 Y119.049 E.56299
G1 X99.576 Y119.353 E.01181
G1 X112.362 Y132.138 E.55849
G2 X112.03 Y132.343 I2.761 J4.846 E.01203
G1 X99.344 Y119.657 E.55415
G3 X99.111 Y119.959 I-3.677 J-2.592 E.01181
G1 X111.705 Y132.554 E.55014
G1 X111.38 Y132.765 E.01197
G1 X98.867 Y120.252 E.54658
G1 X98.624 Y120.544 E.01176
G1 X111.062 Y132.982 E.5433
G1 X110.746 Y133.203 E.01189
G1 X98.38 Y120.837 E.54016
G3 X98.125 Y121.118 I-2.409 J-1.933 E.01173
G1 X110.431 Y133.424 E.53754
G2 X110.125 Y133.653 I3.104 J4.462 E.01183
G1 X97.865 Y121.394 E.53551
G1 X97.605 Y121.67 E.01171
G1 X109.819 Y133.884 E.53352
G2 X109.515 Y134.116 I3.169 J4.462 E.01181
G1 X106.392 Y130.993 E.13641
G3 X106.546 Y131.683 I-2.983 J1.029 E.02189
G1 X109.219 Y134.356 E.11674
G1 X108.923 Y134.596 E.01177
G1 X106.58 Y132.253 E.10231
G3 X106.542 Y132.751 I-2.227 J.076 E.01544
G1 X108.631 Y134.84 E.09125
G1 X108.344 Y135.089 E.01174
G1 X106.454 Y133.199 E.08256
G3 X106.327 Y133.608 I-1.878 J-.358 E.01326
G1 X108.057 Y135.338 E.07557
G2 X107.777 Y135.594 I3.527 J4.143 E.01172
G1 X106.167 Y133.984 E.07032
G1 X105.976 Y134.329 E.01218
G1 X107.5 Y135.853 E.06654
G1 X107.222 Y136.111 E.01171
G1 X105.756 Y134.645 E.06405
G3 X105.51 Y134.935 I-1.412 J-.946 E.01177
G1 X106.954 Y136.379 E.06306
G1 X106.686 Y136.647 E.01171
G1 X105.24 Y135.201 E.06314
G3 X104.946 Y135.443 I-1.221 J-1.188 E.01179
G1 X106.419 Y136.917 E.06438
G1 X106.161 Y137.194 E.01171
G1 X104.626 Y135.659 E.06705
G3 X104.279 Y135.848 I-1.014 J-1.449 E.01223
G1 X105.902 Y137.472 E.07091
G2 X105.648 Y137.753 I3.906 J3.789 E.01172
G1 X103.9 Y136.005 E.07634
G3 X103.486 Y136.127 I-.748 J-1.778 E.01336
G1 X105.398 Y138.04 E.08355
G1 X105.149 Y138.327 E.01174
G1 X103.032 Y136.209 E.09249
G3 X102.525 Y136.239 I-.875 J-10.534 E.01566
G1 X104.906 Y138.62 E.104
G1 X104.666 Y138.916 E.01177
G1 X101.939 Y136.188 E.11915
G3 X101.234 Y136.02 I.396 J-3.211 E.02243
G1 X104.426 Y139.212 E.13945
G2 X104.196 Y139.517 I4.314 J3.504 E.01182
G1 X91.022 Y126.344 E.57542
G3 X91.293 Y126.079 I1.001 J.749 E.01175
G1 X98.73 Y133.516 E.32487
G3 X98.561 Y132.811 I3.042 J-1.101 E.02243
G1 X91.596 Y125.845 E.30427
G3 X91.92 Y125.634 I1.37 J1.744 E.01198
G1 X98.511 Y132.224 E.28789
G1 X98.51 Y132.203 E.00065
G3 X98.541 Y131.718 I2.167 J-.105 E.01505
G1 X92.251 Y125.428 E.27474
G1 X92.591 Y125.232 E.01212
G1 X98.623 Y131.264 E.26348
G3 X98.745 Y130.85 I1.899 J.334 E.01336
G1 X92.931 Y125.036 E.25396
G1 X93.27 Y124.84 E.01212
G1 X98.902 Y130.471 E.24597
G3 X99.091 Y130.124 I1.63 J.663 E.01223
G1 X93.61 Y124.643 E.23939
G1 X93.95 Y124.447 E.01212
G1 X99.307 Y129.804 E.23399
G3 X99.548 Y129.51 I1.428 J.925 E.01179
G1 X94.282 Y124.244 E.23002
G1 X94.613 Y124.039 E.01203
G1 X99.814 Y129.24 E.22718
G3 X100.105 Y128.994 I1.236 J1.167 E.01177
G1 X94.94 Y123.829 E.22559
G1 X95.261 Y123.614 E.01193
G1 X100.42 Y128.773 E.22537
G1 X100.765 Y128.583 E.01218
G1 X95.574 Y123.391 E.22676
G1 X95.884 Y123.165 E.01185
G1 X101.142 Y128.423 E.22964
G3 X101.551 Y128.296 I.768 J1.752 E.01326
G1 X96.183 Y122.927 E.23449
G1 X96.478 Y122.687 E.01177
G1 X102.006 Y128.215 E.24147
G3 X102.496 Y128.169 I.506 J2.758 E.01522
G1 X96.774 Y122.447 E.24997
G2 X97.052 Y122.188 I-1.757 J-2.169 E.01172
G1 X103.067 Y128.203 E.26274
G3 X103.757 Y128.358 I-.339 J3.14 E.02189
G1 X97.209 Y121.81 E.28602
; WIPE_START
G1 X98.623 Y123.224 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X100.994 Y130.479 Z7.8 F36000
G1 X104.086 Y139.944 Z7.8
G1 Z7.4
G1 E.8 F1800
G1 F15000
G1 X90.799 Y126.657 E.58038
G1 X90.622 Y127.015 E.01235
G1 X103.737 Y140.131 E.57289
G1 X103.516 Y140.446 E.01189
G1 X90.459 Y127.388 E.57037
G1 X90.305 Y127.77 E.01272
G1 X103.295 Y140.761 E.56745
G2 X103.079 Y141.081 I4.484 J3.257 E.01193
G1 X90.159 Y128.161 E.56437
G1 X90.014 Y128.552 E.01288
G1 X102.868 Y141.406 E.5615
G1 X102.657 Y141.731 E.01197
G1 X89.869 Y128.943 E.55863
G1 X89.723 Y129.333 E.01288
G1 X102.454 Y142.064 E.5561
G1 X102.253 Y142.399 E.01207
G1 X89.576 Y129.722 E.55376
G1 X89.418 Y130.1 E.01267
G1 X102.053 Y142.735 E.5519
G1 X101.862 Y143.08 E.01218
G1 X89.261 Y130.479 E.55041
G3 X89.091 Y130.845 I-3.855 J-1.573 E.01247
G1 X101.671 Y143.425 E.5495
G2 X101.484 Y143.775 I4.919 J2.844 E.01224
G1 X88.919 Y131.209 E.54888
G3 X88.741 Y131.567 I-3.019 J-1.276 E.01236
G1 X101.304 Y144.13 E.54874
G1 X101.123 Y144.485 E.01231
G1 X88.551 Y131.913 E.54915
G1 X88.361 Y132.259 E.01219
G1 X100.951 Y144.849 E.54994
G1 X100.78 Y145.215 E.01246
G1 X88.159 Y132.594 E.55128
G1 X87.95 Y132.921 E.01198
G1 X100.613 Y145.584 E.55313
G1 X100.457 Y145.963 E.01268
G1 X87.741 Y133.247 E.55543
G3 X87.52 Y133.562 I-2.934 J-1.822 E.01189
G1 X100.3 Y146.342 E.55824
G1 X100.238 Y146.491 E.00498
G1 X99.655 Y146.234 E.0197
G1 X87.295 Y133.874 E.53989
G3 X87.061 Y134.175 I-3.822 J-2.732 E.0118
G1 X98.695 Y145.809 E.50818
G1 X97.734 Y145.385 E.03243
G1 X86.824 Y134.475 E.47656
G1 X86.575 Y134.761 E.01174
G1 X96.774 Y144.96 E.4455
G1 X95.813 Y144.536 E.03243
G1 X86.325 Y135.048 E.41444
G1 X86.076 Y135.335 E.01174
G1 X94.853 Y144.112 E.38337
G1 X93.892 Y143.687 E.03243
G1 X85.82 Y135.615 E.35261
G1 X85.56 Y135.891 E.01171
G1 X92.932 Y143.263 E.322
G1 X91.971 Y142.838 E.03243
G1 X85.301 Y136.168 E.29139
G1 X85.041 Y136.444 E.01171
G1 X91.011 Y142.414 E.26077
G1 X90.051 Y141.99 E.03243
G1 X84.782 Y136.721 E.23016
G1 X84.522 Y136.997 E.01171
G1 X89.09 Y141.565 E.19954
G1 X88.13 Y141.141 E.03243
G1 X84.263 Y137.274 E.16892
G1 X84.027 Y137.574 E.01179
G1 X87.169 Y140.716 E.13725
G1 X86.209 Y140.292 E.03243
G1 X83.796 Y137.879 E.10541
G2 X83.61 Y138.23 I1.015 J.761 E.0123
G1 X85.248 Y139.868 E.07155
G1 X84.288 Y139.443 E.03243
G1 X83.347 Y138.502 E.04111
; CHANGE_LAYER
; Z_HEIGHT: 7.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X84.288 Y139.443 E-.50575
G1 X84.9 Y139.714 E-.25425
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
G1 X124.321 Y121.265
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X124.333 Y121.246 E.00073
G3 X127.679 Y117.974 I3.677 J.414 E.16807
G3 X129.609 Y118.323 I.311 J3.792 E.06579
G3 X124.31 Y121.659 I-1.599 J3.337 E.52359
G1 X124.32 Y121.325 E.0111
G1 X124.713 Y121.285 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.785 Y120.925 E.0113
G3 X127.701 Y118.366 I3.225 J.734 E.12739
G3 X129.096 Y118.535 I.314 J3.248 E.0435
G3 X124.718 Y121.338 I-1.086 J3.124 E.45472
; WIPE_START
M204 S10000
G1 X124.785 Y120.925 E-.15923
G1 X124.878 Y120.566 E-.14085
G1 X125.02 Y120.223 E-.14112
G1 X125.199 Y119.898 E-.14101
G1 X125.414 Y119.595 E-.14111
G1 X125.479 Y119.523 E-.03668
; WIPE_END
G1 E-.04 F1800
G1 X132.626 Y122.202 Z8 F36000
G1 X157.063 Y131.36 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.066 Y131.38 E.00067
G3 X153.044 Y128.524 I-3.608 J.821 E.59206
G1 X153.458 Y128.5 E.01377
G3 X156.952 Y130.981 I0 J3.7 E.15158
G1 X157.046 Y131.302 E.01111
G1 X156.684 Y131.461 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.684 Y131.467 E.00018
G3 X153.088 Y128.914 I-3.226 J.735 E.49045
G1 X153.458 Y128.893 E.01141
G3 X156.582 Y131.11 I0 J3.309 E.12553
G1 X156.667 Y131.404 E.00938
; WIPE_START
M204 S10000
G1 X156.684 Y131.467 E-.02493
G1 X156.748 Y131.833 E-.14108
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14106
G1 X156.685 Y132.94 E-.14107
G1 X156.583 Y133.297 E-.14109
G1 X156.553 Y133.369 E-.02972
; WIPE_END
G1 E-.04 F1800
G1 X148.951 Y132.684 Z8 F36000
G1 X102.564 Y128.501 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.96 Y128.53 E.01318
G3 X104.153 Y128.867 I-.425 J3.781 E.04131
G3 X102.224 Y128.518 I-1.599 J3.338 E.70557
G3 X102.505 Y128.506 I.311 J3.792 E.00933
G1 X102.211 Y128.915 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.245 Y128.91 E.00107
G3 X103.64 Y129.079 I.314 J3.248 E.0435
G3 X101.811 Y128.98 I-1.086 J3.125 E.58168
G1 X102.152 Y128.925 E.01061
; WIPE_START
M204 S10000
G1 X102.245 Y128.91 E-.03605
G1 X102.245 Y128.91 E0
G1 X102.546 Y128.893 E-.11456
G1 X102.917 Y128.914 E-.14105
G1 X103.283 Y128.976 E-.14109
G1 X103.64 Y129.079 E-.14103
G1 X103.983 Y129.221 E-.14112
G1 X104.087 Y129.278 E-.04509
; WIPE_END
G1 E-.04 F1800
G1 X111.307 Y131.753 Z8 F36000
G1 X155.589 Y146.934 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.72 E2.35654
G1 X83.055 Y139.263 E.6296
M73 P89 R2
G3 X83.411 Y137.866 I3.58 J.167 E.04815
G3 X84.377 Y136.65 I5.975 J3.76 E.05161
G2 X86.79 Y133.985 I-24.729 J-24.815 E.11933
G2 X89.501 Y128.988 I-13.845 J-10.745 E.18941
G3 X90.413 Y126.668 I23.16 J7.763 E.08272
G3 X91.435 Y125.548 I2.413 J1.175 E.051
G3 X93.348 Y124.413 I15.94 J24.685 E.07381
G2 X98.06 Y120.701 I-8.565 J-15.717 E.1999
G2 X100.325 Y117.807 I-37.41 J-31.608 E.12194
G3 X101.394 Y116.758 I3.536 J2.535 E.04995
G3 X103.044 Y116.197 I3.009 J6.144 E.05796
G2 X106.577 Y115.257 I-6.545 J-31.73 E.12134
G2 X111.534 Y112.534 I-5.975 J-16.749 E.18841
G3 X113.513 Y111.136 I14.727 J18.748 E.0804
G3 X115.145 Y110.777 I1.449 J2.701 E.05614
G3 X117.853 Y110.909 I-7.764 J188.173 E.08995
G2 X124.754 Y109.831 I.85 J-17.191 E.23331
G3 X127.354 Y108.943 I11.099 J28.225 E.09116
G3 X128.114 Y108.866 I.679 J2.924 E.02541
G3 X129.858 Y109.327 I-.884 J6.873 E.06001
G2 X133.389 Y110.477 I12.218 J-31.514 E.12328
G2 X138.729 Y110.881 I3.984 J-17.198 E.17831
G3 X141.236 Y110.779 I2.302 J25.758 E.08329
G3 X142.68 Y111.256 I-.087 J2.686 E.05113
G3 X144.474 Y112.538 I-15.386 J23.422 E.07316
G2 X149.428 Y115.257 I11.081 J-14.315 E.18823
G2 X152.966 Y116.193 I9.836 J-30.026 E.12146
G3 X154.573 Y116.733 I-1.129 J6.026 E.05644
G3 X155.675 Y117.81 I-2.615 J3.776 E.05135
G2 X157.946 Y120.702 I41.943 J-30.597 E.12198
G2 X162.422 Y124.276 I12.716 J-11.334 E.19092
G3 X164.758 Y125.673 I-13.531 J25.272 E.09033
G3 X165.746 Y127.013 I-1.782 J2.349 E.05598
G3 X166.938 Y130.092 I-682.062 J265.973 E.10951
G2 X170.649 Y135.623 I16.059 J-6.762 E.22233
G3 X172.333 Y137.457 I-17.034 J17.328 E.0826
G3 X172.913 Y139.009 I-2.311 J1.749 E.05574
G1 X172.943 Y139.264 E.00853
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.196 E2.1792
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.2 J.192 E.05096
G3 X83.717 Y136.795 I3.894 J1.885 E.04099
G2 X85.862 Y134.489 I-441.993 J-413.351 E.09676
G2 X89.134 Y128.851 I-12.825 J-11.212 E.20157
G3 X90.065 Y126.487 I23.272 J7.803 E.07809
G3 X91.212 Y125.225 I2.755 J1.353 E.05309
G3 X93.152 Y124.073 I16.12 J24.937 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.381 E.18128
G2 X100.017 Y117.563 I-37.324 J-31.515 E.11229
G3 X101.193 Y116.421 I3.822 J2.758 E.05063
G3 X102.951 Y115.816 I3.187 J6.404 E.0573
G2 X106.449 Y114.887 I-6.459 J-31.367 E.11125
G2 X111.301 Y112.218 I-5.849 J-16.383 E.17089
G3 X113.319 Y110.795 I14.854 J18.916 E.07593
G3 X115.144 Y110.385 I1.639 J3.034 E.05819
G3 X117.867 Y110.517 I-7.447 J182.369 E.08377
G2 X124.623 Y109.461 I.837 J-16.797 E.21159
G3 X127.013 Y108.625 I13.205 J33.887 E.07783
G3 X128.135 Y108.474 I1 J3.199 E.03493
G3 X129.99 Y108.958 I-.884 J7.195 E.05907
G2 X133.481 Y110.096 I12.105 J-31.206 E.11289
G2 X138.707 Y110.489 I3.893 J-16.813 E.16168
G3 X141.261 Y110.387 I2.31 J25.883 E.07855
G3 X142.885 Y110.921 I-.11 J3.07 E.05323
G3 X144.706 Y112.222 I-15.543 J23.689 E.06878
G2 X149.556 Y114.887 I10.853 J-14.005 E.17077
G2 X153.057 Y115.812 I9.716 J-29.688 E.1113
G3 X154.775 Y116.397 I-1.204 J6.354 E.05595
G3 X155.981 Y117.566 I-2.792 J4.09 E.05188
G2 X158.239 Y120.442 I41.889 J-30.555 E.11237
G2 X162.619 Y123.937 I12.424 J-11.075 E.17301
G3 X164.784 Y125.21 I-16.318 J30.233 E.0772
G3 X166.104 Y126.854 I-1.827 J2.82 E.06591
G3 X167.3 Y129.94 I-596.724 J232.975 E.10168
G2 X170.934 Y135.353 I15.7 J-6.612 E.20159
G3 X172.646 Y137.222 I-17.226 J17.512 E.07791
G3 X173.302 Y138.957 I-2.618 J1.981 E.05778
G3 X173.36 Y139.508 I-10.4 J1.372 E.01705
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30192
G1 X154.687 Y145.778 E-.38743
G1 X154.608 Y145.61 E-.07065
; WIPE_END
G1 E-.04 F1800
G1 X156.105 Y138.126 Z8 F36000
G1 X156.966 Y133.823 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42192
G1 F15000
G1 X164.717 Y126.072 E.33854
G1 X164.414 Y125.84 E.01181
G1 X157.443 Y132.81 E.30444
G2 X157.494 Y132.223 I-2.577 J-.518 E.01822
G1 X164.089 Y125.628 E.28805
G2 X163.757 Y125.424 I-2.41 J3.554 E.01204
G1 X157.464 Y131.717 E.27486
G2 X157.382 Y131.263 I-2.051 J.136 E.01428
G1 X163.416 Y125.229 E.26355
G1 X163.075 Y125.034 E.01213
G1 X157.26 Y130.849 E.25399
G1 X157.103 Y130.47 E.01267
G1 X162.734 Y124.839 E.24596
G1 X162.393 Y124.644 E.01213
G1 X156.914 Y130.123 E.23933
G2 X156.697 Y129.804 I-1.526 J.799 E.01195
G1 X162.057 Y124.444 E.23409
G1 X161.724 Y124.241 E.01204
G1 X156.456 Y129.509 E.23011
G2 X156.19 Y129.239 I-1.33 J1.044 E.01173
G1 X161.392 Y124.037 E.22719
G3 X161.064 Y123.829 I2.258 J-3.906 E.01199
G1 X155.9 Y128.994 E.22558
G2 X155.584 Y128.773 I-1.138 J1.292 E.01191
G1 X160.744 Y123.614 E.22535
G3 X160.43 Y123.391 I2.785 J-4.258 E.01188
G1 X155.239 Y128.582 E.22673
G2 X154.863 Y128.423 I-.897 J1.589 E.01265
G1 X160.12 Y123.165 E.22961
G3 X159.822 Y122.927 I2.069 J-2.897 E.01178
G1 X154.454 Y128.296 E.23447
G2 X154.005 Y128.208 I-.613 J1.944 E.01414
G1 X159.526 Y122.687 E.24114
G1 X159.231 Y122.447 E.01177
G1 X153.508 Y128.169 E.24995
G2 X152.938 Y128.203 I.082 J6.144 E.01765
G1 X158.953 Y122.188 E.26271
G1 X158.676 Y121.93 E.01171
G1 X151.961 Y128.645 E.29328
; WIPE_START
G1 X153.375 Y127.23 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X159.637 Y131.594 Z8 F36000
G1 X171.381 Y139.776 Z8
G1 Z7.6
G1 E.8 F1800
G1 F15000
G1 X172.509 Y138.648 E.04927
G2 X172.391 Y138.229 I-1.5 J.196 E.01347
G1 X170.753 Y139.868 E.07156
G1 X169.793 Y140.292 E.03243
G1 X172.211 Y137.873 E.10565
G2 X171.982 Y137.567 I-1.188 J.65 E.01186
G1 X168.832 Y140.717 E.13758
G1 X167.872 Y141.141 E.03243
G1 X171.745 Y137.267 E.16919
G2 X171.485 Y136.991 I-1.702 J1.341 E.01173
G1 X166.911 Y141.566 E.19979
G1 X165.951 Y141.99 E.03243
G1 X171.225 Y136.715 E.23038
G1 X170.965 Y136.44 E.01171
G1 X164.99 Y142.415 E.26096
G1 X164.03 Y142.839 E.03243
G1 X170.705 Y136.164 E.29155
G1 X170.445 Y135.888 E.01171
G1 X163.069 Y143.264 E.32213
G1 X162.109 Y143.688 E.03243
G1 X170.184 Y135.612 E.35271
G3 X169.928 Y135.333 I3.327 J-3.313 E.01172
G1 X161.148 Y144.113 E.38346
G1 X160.188 Y144.537 E.03243
G1 X169.678 Y135.046 E.41452
G1 X169.429 Y134.76 E.01173
G1 X159.227 Y144.962 E.44557
G1 X158.267 Y145.386 E.03243
G1 X169.18 Y134.473 E.47663
G3 X168.943 Y134.174 I2.926 J-2.554 E.01179
G1 X157.306 Y145.811 E.50825
G1 X156.346 Y146.235 E.03243
G1 X168.709 Y133.872 E.53996
G1 X168.484 Y133.561 E.01186
G1 X155.704 Y146.341 E.55817
G1 X155.547 Y145.961 E.01267
G1 X168.263 Y133.246 E.55536
G1 X168.054 Y132.919 E.01198
G1 X155.391 Y145.582 E.55307
G2 X155.224 Y145.213 I-4.234 J1.693 E.01251
G1 X167.844 Y132.593 E.55122
G3 X167.642 Y132.259 I2.851 J-1.958 E.01206
G1 X155.053 Y144.848 E.54982
G2 X154.881 Y144.484 I-5.286 J2.276 E.01244
G1 X167.449 Y131.916 E.54889
G3 X167.264 Y131.565 I3.255 J-1.931 E.01227
G1 X154.7 Y144.129 E.54874
G1 X154.519 Y143.773 E.01231
G1 X167.086 Y131.206 E.54888
G1 X166.909 Y130.848 E.01235
G1 X154.333 Y143.424 E.54925
G1 X154.142 Y143.079 E.01218
G1 X166.748 Y130.473 E.55058
G1 X166.588 Y130.097 E.01262
G1 X153.951 Y142.734 E.55195
G2 X153.751 Y142.398 I-4.929 J2.705 E.01208
G1 X166.429 Y129.72 E.55371
G3 X166.28 Y129.333 I4.409 J-1.914 E.01282
G1 X153.55 Y142.063 E.55601
G2 X153.347 Y141.73 I-4.879 J2.75 E.01205
G1 X166.134 Y128.943 E.5585
G1 X165.988 Y128.553 E.01286
G1 X153.136 Y141.405 E.56134
G1 X152.925 Y141.08 E.01197
G1 X165.842 Y128.163 E.56418
G1 X165.696 Y127.773 E.01286
G1 X152.709 Y140.76 E.56723
G1 X152.488 Y140.445 E.01189
G1 X165.541 Y127.392 E.57009
G2 X165.377 Y127.02 I-2.531 J.891 E.01257
G1 X152.267 Y140.13 E.57259
G2 X152.039 Y139.822 I-4.518 J3.114 E.01184
G1 X165.199 Y126.663 E.57476
G2 X164.984 Y126.341 I-4.815 J2.987 E.01194
G1 X151.808 Y139.517 E.57544
G2 X151.578 Y139.212 I-4.469 J3.142 E.01182
G1 X154.769 Y136.02 E.1394
G3 X154.065 Y136.188 I-1.1 J-3.041 E.02242
G1 X151.338 Y138.915 E.1191
G1 X151.098 Y138.619 E.01177
G1 X153.478 Y136.239 E.10396
G1 X152.972 Y136.209 E.01565
G1 X150.855 Y138.326 E.09248
G1 X150.606 Y138.039 E.01173
G1 X152.522 Y136.123 E.0837
G3 X152.104 Y136.005 I1.528 J-6.222 E.01342
G1 X150.357 Y137.753 E.07633
G2 X150.102 Y137.471 I-3.929 J3.306 E.01172
G1 X151.725 Y135.848 E.07091
G3 X151.378 Y135.659 I.666 J-1.635 E.01223
G1 X149.843 Y137.195 E.06708
G1 X149.583 Y136.918 E.01171
G1 X151.059 Y135.443 E.06443
G3 X150.764 Y135.201 I.925 J-1.428 E.01179
G1 X149.319 Y136.647 E.06314
G1 X149.051 Y136.379 E.0117
G1 X150.494 Y134.935 E.06305
G3 X150.249 Y134.645 I1.168 J-1.237 E.01177
G1 X148.782 Y136.111 E.06405
G1 X148.505 Y135.853 E.01171
G1 X150.028 Y134.329 E.06653
G1 X149.837 Y133.984 E.01218
G1 X148.227 Y135.594 E.07031
G2 X147.947 Y135.338 I-3.801 J3.882 E.01172
G1 X149.677 Y133.608 E.07557
G3 X149.551 Y133.199 I1.754 J-.768 E.01326
G1 X147.66 Y135.089 E.08255
G1 X147.374 Y134.84 E.01173
G1 X149.463 Y132.75 E.09125
G3 X149.424 Y132.253 I2.186 J-.421 E.01543
G1 X147.082 Y134.596 E.1023
G1 X146.786 Y134.356 E.01177
G1 X149.459 Y131.682 E.11678
G3 X149.612 Y130.993 I3.811 J.485 E.02183
G1 X146.489 Y134.116 E.1364
G2 X146.186 Y133.884 I-3.48 J4.24 E.01181
G1 X158.4 Y121.67 E.53346
G1 X158.14 Y121.394 E.01171
G1 X145.88 Y133.653 E.53546
G2 X145.574 Y133.424 I-3.488 J4.336 E.01183
G1 X157.88 Y121.118 E.53748
G3 X157.624 Y120.837 I2.172 J-2.231 E.01173
G1 X145.258 Y133.203 E.5401
G1 X144.943 Y132.982 E.01189
G1 X157.381 Y120.545 E.54323
G1 X157.137 Y120.252 E.01175
G1 X144.624 Y132.765 E.54651
G1 X144.299 Y132.554 E.01197
G1 X156.894 Y119.96 E.55006
G3 X156.661 Y119.656 I3.133 J-2.637 E.01181
G1 X143.974 Y132.343 E.55411
G2 X143.643 Y132.139 I-3.095 J4.647 E.01203
G1 X156.43 Y119.351 E.5585
G1 X156.199 Y119.046 E.01182
G1 X143.308 Y131.937 E.56304
G1 X142.973 Y131.736 E.01206
G1 X155.968 Y118.741 E.56757
G1 X155.737 Y118.436 E.01182
G1 X142.629 Y131.545 E.57254
G1 X142.284 Y131.354 E.01218
G1 X155.502 Y118.135 E.57734
G1 X155.265 Y117.837 E.01178
G1 X141.935 Y131.166 E.58217
G1 X141.58 Y130.985 E.01231
G1 X155.012 Y117.554 E.58662
G2 X154.746 Y117.284 I-1.099 J.816 E.01174
G1 X141.225 Y130.804 E.59052
G2 X140.863 Y130.631 I-2.662 J5.1 E.01242
G1 X154.443 Y117.051 E.59312
G2 X154.083 Y116.874 I-.724 J1.02 E.01242
G1 X140.497 Y130.46 E.59339
G2 X140.13 Y130.291 I-2.613 J5.188 E.01248
G1 X153.686 Y116.735 E.59207
G2 X153.265 Y116.62 I-.795 J2.083 E.0135
G1 X139.754 Y130.132 E.59012
G1 X139.378 Y129.972 E.01262
G1 X152.834 Y116.516 E.58771
G1 X152.403 Y116.411 E.01371
G1 X138.995 Y129.819 E.58558
G1 X138.608 Y129.67 E.01281
G1 X151.971 Y116.306 E.58366
G1 X151.54 Y116.202 E.01371
G1 X138.22 Y129.522 E.58176
G1 X137.821 Y129.385 E.01304
G1 X151.109 Y116.097 E.58037
G3 X150.685 Y115.984 I1.053 J-4.802 E.01353
G1 X137.421 Y129.249 E.57933
G2 X137.017 Y129.117 I-2.211 J6.088 E.01313
G1 X150.27 Y115.864 E.57884
G1 X149.855 Y115.743 E.01336
G1 X136.607 Y128.991 E.57862
G2 X136.194 Y128.867 I-1.974 J5.827 E.01329
G1 X149.45 Y115.612 E.57895
G1 X149.055 Y115.47 E.01294
G1 X135.772 Y128.754 E.58019
G1 X135.349 Y128.641 E.01352
G1 X148.661 Y115.329 E.58142
G3 X148.287 Y115.167 I1.042 J-2.929 E.0126
G1 X134.917 Y128.537 E.58395
G1 X134.481 Y128.437 E.0138
G1 X147.913 Y115.005 E.58665
M73 P90 R2
G3 X147.545 Y114.837 I1.056 J-2.8 E.0125
G1 X134.04 Y128.342 E.58984
G1 X133.591 Y128.254 E.01412
G1 X147.192 Y114.654 E.59401
G1 X146.838 Y114.471 E.01228
M73 P90 R1
G1 X133.141 Y128.169 E.59825
G1 X132.678 Y128.096 E.01447
G1 X146.495 Y114.279 E.60346
G1 X146.16 Y114.078 E.01207
G1 X132.215 Y128.022 E.60903
G2 X131.74 Y127.962 I-1.098 J6.775 E.01482
G1 X145.825 Y113.877 E.61518
G3 X145.503 Y113.663 I1.714 J-2.912 E.01194
G1 X131.262 Y127.904 E.622
G2 X130.774 Y127.856 I-.923 J6.977 E.01516
G1 X145.184 Y113.446 E.6294
G1 X144.865 Y113.229 E.01192
G1 X130.281 Y127.813 E.63699
G2 X129.778 Y127.78 I-.723 J7.165 E.01557
G1 X144.552 Y113.006 E.64529
G1 X144.244 Y112.778 E.01184
G1 X129.268 Y127.753 E.65406
G2 X128.749 Y127.737 I-.501 J7.435 E.01605
G1 X143.935 Y112.551 E.66327
G1 X143.627 Y112.323 E.01184
G1 X128.223 Y127.727 E.6728
G2 X127.685 Y127.729 I-.244 J7.704 E.01661
G1 X143.318 Y112.096 E.68281
G1 X143.003 Y111.875 E.01188
G1 X131.761 Y123.117 E.49103
G2 X131.963 Y122.379 I-3.437 J-1.338 E.02368
G1 X142.685 Y111.657 E.4683
G1 X142.351 Y111.455 E.01206
G1 X132.033 Y121.773 E.45064
G2 X132.016 Y121.254 I-2.313 J-.187 E.01609
G1 X141.996 Y111.274 E.43586
G2 X141.575 Y111.159 I-.594 J1.335 E.01351
G1 X131.943 Y120.791 E.42071
G2 X131.826 Y120.372 I-1.92 J.311 E.01346
G1 X141.085 Y111.114 E.40438
G2 X140.549 Y111.113 I-.269 J3.557 E.01656
G1 X131.673 Y119.989 E.38765
G2 X131.49 Y119.637 I-1.655 J.638 E.0123
G1 X139.99 Y111.136 E.37126
G1 X139.421 Y111.169 E.01759
G1 X131.279 Y119.312 E.35564
G2 X131.042 Y119.012 I-1.447 J.9 E.01181
G1 X138.852 Y111.202 E.34113
G1 X138.284 Y111.234 E.01759
G1 X130.781 Y118.737 E.32769
G2 X130.496 Y118.486 I-1.254 J1.14 E.01175
G1 X137.736 Y111.246 E.31624
G1 X137.194 Y111.252 E.01674
G1 X130.182 Y118.264 E.30626
G2 X129.84 Y118.07 I-1.031 J1.418 E.01217
G1 X136.665 Y111.245 E.29809
G1 X136.155 Y111.219 E.01579
G1 X129.47 Y117.904 E.29198
G2 X129.067 Y117.771 I-.792 J1.722 E.01313
G1 X135.654 Y111.184 E.28772
G1 X135.173 Y111.129 E.01495
G1 X128.625 Y117.677 E.28599
G2 X128.136 Y117.63 I-.453 J2.148 E.0152
G1 X134.695 Y111.071 E.28645
G1 X134.242 Y110.988 E.01422
G1 X127.578 Y117.652 E.29107
G2 X126.917 Y117.777 I.138 J2.542 E.02084
G1 X133.789 Y110.905 E.30016
G3 X133.354 Y110.805 I.571 J-3.478 E.01382
G1 X111.417 Y132.741 E.9581
G3 X112.848 Y131.846 I13.523 J20.034 E.05212
G1 X124.121 Y120.574 E.49236
G2 X123.989 Y121.241 I4.941 J1.321 E.02103
G1 X114.059 Y131.171 E.43371
G3 X115.13 Y130.637 I8.189 J15.058 E.03697
G1 X123.973 Y121.793 E.38625
G2 X124.02 Y122.282 I2.194 J.036 E.0152
G1 X116.112 Y130.191 E.34541
G3 X117.026 Y129.812 I5.88 J12.912 E.03057
G1 X124.115 Y122.724 E.3096
G2 X124.248 Y123.127 I1.855 J-.389 E.01313
G1 X117.888 Y129.486 E.27776
G1 X118.705 Y129.205 E.0267
G1 X124.413 Y123.497 E.24929
G2 X124.607 Y123.839 I1.618 J-.692 E.01217
G1 X119.48 Y128.966 E.22393
G3 X120.226 Y128.756 I3.385 J10.588 E.02394
G1 X124.83 Y124.153 E.20106
G2 X125.08 Y124.438 I1.391 J-.969 E.01175
G1 X120.949 Y128.569 E.18044
G1 X121.646 Y128.408 E.02209
G1 X125.355 Y124.699 E.16202
G2 X125.655 Y124.935 I1.199 J-1.211 E.01181
G1 X122.317 Y128.273 E.14578
G3 X122.975 Y128.151 I2.074 J9.372 E.02066
G1 X125.98 Y125.146 E.13125
G2 X126.332 Y125.33 I.991 J-1.474 E.0123
G1 X123.612 Y128.051 E.11883
G3 X124.232 Y127.966 I1.514 J8.833 E.01933
G1 X126.715 Y125.483 E.10848
G2 X127.141 Y125.593 I.811 J-2.254 E.0136
G1 X124.843 Y127.891 E.10039
G3 X125.431 Y127.839 I1.049 J8.42 E.01825
G1 X127.597 Y125.673 E.09459
G2 X128.117 Y125.69 I.332 J-2.296 E.01609
G1 X126.015 Y127.791 E.0918
G1 X126.58 Y127.762 E.01749
G1 X128.716 Y125.626 E.09327
G2 X129.46 Y125.418 I-.749 J-4.108 E.02391
G1 X126.967 Y127.911 E.10892
; WIPE_START
G1 X128.381 Y126.497 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X130.533 Y119.174 Z8 F36000
G1 X133.065 Y110.558 Z8
G1 Z7.6
G1 E.8 F1800
G1 F15000
G1 X108.06 Y135.562 E1.09209
G1 X106.059 Y133.811 F36000
G1 F15000
G1 X130.097 Y109.774 E1.04985
G1 X129.7 Y109.634 E.01298
G1 X106.53 Y132.805 E1.01199
G2 X106.583 Y132.216 I-2.185 J-.492 E.01831
G1 X129.304 Y109.495 E.99236
G2 X128.897 Y109.366 I-1.008 J2.473 E.0132
G1 X106.551 Y131.711 E.97596
G2 X106.468 Y131.258 I-2.05 J.139 E.01426
G1 X128.472 Y109.254 E.96105
G2 X127.993 Y109.197 I-.843 J5.067 E.01491
G1 X106.346 Y130.844 E.94546
G1 X106.189 Y130.465 E.01267
G1 X127.365 Y109.289 E.92489
G2 X126.604 Y109.515 I2.956 J11.381 E.02453
G1 X106 Y130.119 E.89991
G2 X105.783 Y129.8 I-1.524 J.801 E.01194
G1 X125.763 Y109.82 E.87264
G1 X124.922 Y110.125 E.02763
G1 X105.541 Y129.506 E.84647
G2 X105.275 Y129.236 I-1.329 J1.047 E.01173
G1 X124.12 Y110.39 E.82311
G3 X123.346 Y110.628 I-3.094 J-8.688 E.02501
G1 X104.984 Y128.991 E.80201
G2 X104.668 Y128.771 I-1.136 J1.294 E.01192
G1 X122.624 Y110.814 E.78428
G3 X121.949 Y110.954 I-1.635 J-6.194 E.02133
G1 X104.323 Y128.58 E.76983
G2 X103.946 Y128.42 I-.896 J1.591 E.01266
G1 X121.292 Y111.075 E.7576
G3 X120.685 Y111.145 I-.824 J-4.427 E.01888
G1 X103.536 Y128.294 E.74899
G2 X103.088 Y128.207 I-.611 J1.948 E.01415
G1 X120.087 Y111.208 E.74247
G1 X119.523 Y111.236 E.01744
G1 X102.59 Y128.169 E.73958
G2 X102.009 Y128.213 I.035 J4.264 E.01799
G1 X118.969 Y111.254 E.74074
G1 X118.439 Y111.248 E.01638
G1 X101.037 Y128.65 E.76003
G1 X91.939 Y125.42 F36000
G1 F15000
G2 X90.976 Y126.392 I20.135 J20.895 E.04226
G2 X90.426 Y127.469 I4.5 J2.979 E.03742
G1 X92.761 Y125.134 E.10198
G2 X94.032 Y124.399 I-11.328 J-21.051 E.04537
G1 X90.094 Y128.337 E.17202
G1 X89.776 Y129.191 E.02812
G1 X95.579 Y123.388 E.25344
G1 X95.937 Y123.127 E.01369
G2 X99.453 Y119.514 I-11.44 J-14.649 E.15618
G1 X102.171 Y116.795 E.11872
G3 X102.932 Y116.571 I1.746 J4.51 E.02453
G1 X89.43 Y130.073 E.58974
G3 X88.999 Y131.04 I-10.186 J-3.961 E.03271
G1 X103.643 Y116.396 E.63959
G1 X104.347 Y116.228 E.02236
G1 X88.415 Y132.159 E.69582
G3 X87.446 Y133.665 I-16.565 J-9.603 E.05533
G1 X105.051 Y116.06 E.76893
G2 X105.803 Y115.844 I-1.846 J-7.855 E.02415
G1 X83.862 Y137.785 E.95829
G2 X83.474 Y138.709 I1.597 J1.214 E.03127
G1 X106.58 Y115.603 E1.00917
G1 X107.424 Y115.295 E.02776
G1 X83.586 Y139.133 E1.04116
G1 X83.958 Y139.297 E.01255
G1 X108.373 Y114.881 E1.06639
G1 X109.515 Y114.276 E.03991
G1 X84.329 Y139.461 E1.10001
G1 X84.701 Y139.626 E.01255
G1 X111.012 Y113.315 E1.14915
G1 X112.957 Y111.906 E.07417
G1 X85.073 Y139.79 E1.21786
G1 X85.444 Y139.954 E.01255
G1 X114.19 Y111.209 E1.2555
G3 X114.808 Y111.127 I.6 J2.149 E.01932
G1 X85.816 Y140.119 E1.26626
G1 X86.188 Y140.283 E.01255
G1 X115.354 Y111.117 E1.27386
G3 X115.874 Y111.133 I-.04 J9.766 E.01607
G1 X86.56 Y140.447 E1.28033
G1 X86.931 Y140.611 E.01255
G1 X116.382 Y111.161 E1.28628
G1 X116.89 Y111.189 E.01571
G1 X87.303 Y140.776 E1.29222
G1 X87.675 Y140.94 E.01255
G1 X117.397 Y111.217 E1.29817
G2 X117.908 Y111.243 I.537 J-5.672 E.0158
G1 X88.047 Y141.104 E1.30424
G1 X88.418 Y141.268 E.01255
G1 X98.704 Y130.983 E.44922
G2 X98.549 Y131.673 I3.665 J1.181 E.02187
G1 X88.79 Y141.433 E.42626
G1 X89.162 Y141.597 E.01255
M73 P91 R1
G1 X98.512 Y132.247 E.40839
G2 X98.55 Y132.744 I2.227 J.08 E.01545
G1 X89.533 Y141.761 E.39381
G1 X89.905 Y141.925 E.01255
G1 X98.637 Y133.193 E.38138
G2 X98.764 Y133.603 I1.88 J-.356 E.01327
G1 X90.277 Y142.09 E.37067
G1 X90.649 Y142.254 E.01255
G1 X98.923 Y133.979 E.36139
G1 X99.114 Y134.325 E.01218
G1 X91.02 Y142.418 E.35349
G1 X91.392 Y142.582 E.01255
G1 X99.334 Y134.641 E.34687
G2 X99.579 Y134.931 I1.413 J-.943 E.01177
G1 X91.764 Y142.747 E.34134
G1 X92.136 Y142.911 E.01255
G1 X99.849 Y135.198 E.33688
G2 X100.143 Y135.44 I1.221 J-1.184 E.01178
G1 X92.507 Y143.075 E.33349
G1 X92.879 Y143.239 E.01255
G1 X100.462 Y135.656 E.3312
G2 X100.809 Y135.846 I1.013 J-1.44 E.01222
G1 X93.251 Y143.404 E.33009
G1 X93.622 Y143.568 E.01255
G1 X101.188 Y136.003 E.33041
G2 X101.605 Y136.122 I1.923 J-5.964 E.0134
G1 X93.994 Y143.732 E.3324
G1 X94.366 Y143.896 E.01255
G1 X102.055 Y136.208 E.33582
G1 X102.559 Y136.239 E.0156
G1 X94.738 Y144.061 E.34161
G1 X95.109 Y144.225 E.01255
G1 X103.145 Y136.19 E.35094
G2 X103.848 Y136.023 I-.389 J-3.202 E.02236
G1 X95.481 Y144.389 E.36541
G1 X95.853 Y144.553 E.01255
G1 X130.493 Y109.913 E1.51295
G1 X130.89 Y110.053 E.01298
G1 X96.225 Y144.718 E1.51403
G1 X96.596 Y144.882 E.01255
G1 X131.286 Y110.192 E1.51512
G1 X131.683 Y110.332 E.01298
G1 X96.968 Y145.046 E1.5162
G1 X97.34 Y145.211 E.01255
G1 X132.092 Y110.458 E1.51784
G1 X132.502 Y110.584 E.01325
G1 X97.711 Y145.375 E1.51953
G1 X98.083 Y145.539 E.01255
G1 X104.496 Y139.126 E.28009
G2 X103.084 Y141.074 I16.829 J13.684 E.07433
G1 X98.455 Y145.703 E.20219
G1 X98.827 Y145.868 E.01255
G1 X102.19 Y142.505 E.14688
G2 X101.515 Y143.716 I35.404 J20.528 E.04282
G1 X99.198 Y146.032 E.10116
G1 X99.57 Y146.196 E.01255
G1 X100.98 Y144.786 E.06157
G2 X100.539 Y145.763 I10.762 J5.444 E.0331
G1 X99.813 Y146.489 E.03171
; CHANGE_LAYER
; Z_HEIGHT: 7.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X100.539 Y145.763 E-.39014
G1 X100.939 Y144.876 E-.36986
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
G1 X124.321 Y121.265
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X124.332 Y121.246 E.00073
G3 X127.656 Y117.976 I3.678 J.414 E.16733
G3 X129.225 Y118.164 I.359 J3.638 E.05284
G3 X124.309 Y121.659 I-1.216 J3.496 E.53748
G1 X124.319 Y121.325 E.0111
G1 X124.713 Y121.287 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X124.782 Y120.924 E.01136
G3 X127.678 Y118.367 I3.227 J.736 E.12675
G3 X128.739 Y118.432 I.31 J3.633 E.03277
G3 X124.715 Y121.341 I-.73 J3.228 E.46645
; WIPE_START
M204 S10000
G1 X124.782 Y120.924 E-.16058
G1 X124.878 Y120.566 E-.14093
G1 X125.02 Y120.223 E-.14106
G1 X125.199 Y119.898 E-.14106
G1 X125.414 Y119.595 E-.14107
G1 X125.476 Y119.526 E-.03529
; WIPE_END
G1 E-.04 F1800
G1 X132.623 Y122.204 Z8.2 F36000
G1 X157.063 Y131.36 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.066 Y131.38 E.00067
G3 X153.044 Y128.524 I-3.608 J.821 E.59207
G1 X153.458 Y128.5 E.01377
G3 X156.952 Y130.981 I0 J3.7 E.15157
G1 X157.046 Y131.302 E.01111
G1 X156.685 Y131.465 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X156.683 Y131.467 E.00007
G3 X153.088 Y128.914 I-3.225 J.734 E.49027
G1 X153.458 Y128.893 E.01141
G3 X156.581 Y131.111 I0 J3.308 E.12552
G1 X156.668 Y131.408 E.00952
; WIPE_START
M204 S10000
G1 X156.683 Y131.467 E-.02328
G1 X156.748 Y131.833 E-.14108
G1 X156.768 Y132.203 E-.14105
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.14107
G1 X156.583 Y133.297 E-.14109
G1 X156.551 Y133.373 E-.03139
; WIPE_END
G1 E-.04 F1800
G1 X148.949 Y132.688 Z8.2 F36000
G1 X102.51 Y128.502 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.546 Y128.502 E.00121
G3 X103.769 Y128.708 I.013 J3.655 E.04134
G3 X102.2 Y128.52 I-1.215 J3.495 E.71845
G1 X102.45 Y128.506 E.0083
G1 X102.211 Y128.913 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X102.222 Y128.911 E.00035
G3 X103.283 Y128.976 I.311 J3.633 E.03277
G3 X101.811 Y128.979 I-.729 J3.226 E.59294
G1 X102.152 Y128.923 E.01063
; WIPE_START
M204 S10000
G1 X102.222 Y128.911 E-.02712
G1 X102.222 Y128.911 E0
G1 X102.546 Y128.893 E-.12336
G1 X102.917 Y128.914 E-.14105
G1 X103.283 Y128.976 E-.1411
G1 X103.64 Y129.079 E-.14105
G1 X103.983 Y129.221 E-.1411
G1 X104.087 Y129.278 E-.04523
; WIPE_END
G1 E-.04 F1800
G1 X111.307 Y131.753 Z8.2 F36000
G1 X155.589 Y146.934 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X100.416 Y146.934 I-27.586 J10.719 E2.35656
G1 X83.055 Y139.263 E.62961
G3 X83.411 Y137.866 I3.579 J.167 E.04815
G3 X84.377 Y136.651 I5.97 J3.756 E.0516
G2 X86.789 Y133.986 I-24.734 J-24.82 E.11929
G2 X89.501 Y128.988 I-13.844 J-10.747 E.18947
G3 X90.412 Y126.67 I23.203 J7.778 E.08264
G3 X91.435 Y125.548 I2.415 J1.174 E.05108
G3 X93.349 Y124.413 I15.95 J24.703 E.07381
G2 X98.059 Y120.701 I-8.564 J-15.715 E.19987
G2 X100.325 Y117.807 I-37.39 J-31.593 E.12196
G3 X101.394 Y116.758 I3.537 J2.536 E.04995
G3 X103.044 Y116.197 I3.008 J6.143 E.05796
G2 X106.577 Y115.257 I-6.544 J-31.728 E.12135
G2 X111.534 Y112.534 I-5.975 J-16.748 E.1884
G3 X113.513 Y111.136 I14.721 J18.739 E.08041
G3 X115.145 Y110.777 I1.449 J2.701 E.05612
G3 X117.853 Y110.909 I-7.77 J188.296 E.08995
G2 X124.754 Y109.831 I.849 J-17.201 E.23331
G3 X127.358 Y108.942 I11.042 J28.067 E.09131
G3 X128.114 Y108.866 I.674 J2.919 E.02528
G3 X129.866 Y109.33 I-.888 J6.895 E.06029
G2 X133.389 Y110.477 I12.181 J-31.422 E.12298
G2 X138.729 Y110.881 I3.984 J-17.197 E.17831
G3 X141.236 Y110.779 I2.302 J25.754 E.08328
G3 X142.68 Y111.256 I-.087 J2.686 E.05112
G3 X144.474 Y112.538 I-15.374 J23.405 E.07317
G2 X149.427 Y115.257 I11.081 J-14.314 E.18822
G2 X152.972 Y116.195 I9.855 J-30.089 E.12168
G3 X154.572 Y116.732 I-1.269 J6.427 E.05616
G3 X155.675 Y117.81 I-2.61 J3.774 E.05137
G2 X157.945 Y120.701 I41.979 J-30.624 E.12199
G2 X162.421 Y124.276 I12.716 J-11.334 E.19092
G3 X164.758 Y125.674 I-13.524 J25.259 E.09035
G3 X165.746 Y127.013 I-1.782 J2.349 E.05599
G3 X166.938 Y130.092 I-687.739 J268.175 E.10951
G2 X170.649 Y135.623 I16.057 J-6.761 E.22231
G3 X172.333 Y137.457 I-17.042 J17.335 E.08263
G3 X172.913 Y139.009 I-2.312 J1.749 E.05573
G1 X172.943 Y139.264 E.00853
G1 X155.644 Y146.91 E.6274
G1 X155.37 Y147.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.196 E2.17922
G1 X82.639 Y139.508 E.60452
G3 X82.93 Y137.961 I5.487 J.231 E.04851
G3 X83.717 Y136.795 I3.808 J1.722 E.04343
G2 X85.862 Y134.489 I-446.726 J-417.754 E.09678
G2 X89.134 Y128.851 I-12.826 J-11.212 E.20157
G3 X90.064 Y126.489 I23.337 J7.827 E.07801
G3 X91.212 Y125.225 I2.757 J1.351 E.05317
G3 X93.152 Y124.073 I16.124 J24.943 E.06935
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18128
G2 X100.017 Y117.563 I-37.31 J-31.504 E.11229
G3 X101.193 Y116.421 I3.823 J2.759 E.05064
G3 X102.951 Y115.816 I3.187 J6.403 E.0573
G2 X106.449 Y114.887 I-6.458 J-31.364 E.11126
G2 X111.301 Y112.219 I-5.849 J-16.383 E.17088
G3 X113.32 Y110.795 I14.852 J18.914 E.07594
G3 X115.144 Y110.385 I1.639 J3.034 E.05818
G3 X117.867 Y110.517 I-7.453 J182.483 E.08377
G2 X124.623 Y109.461 I.835 J-16.807 E.21159
G3 X127.013 Y108.625 I13.207 J33.891 E.07782
G3 X128.135 Y108.474 I1 J3.197 E.03494
G3 X129.997 Y108.96 I-.888 J7.213 E.05932
G2 X133.481 Y110.096 I12.073 J-31.127 E.11264
G2 X138.708 Y110.489 I3.893 J-16.813 E.16168
G3 X141.261 Y110.387 I2.31 J25.879 E.07854
G3 X142.884 Y110.921 I-.11 J3.07 E.05322
G3 X144.706 Y112.222 I-15.533 J23.676 E.06878
G2 X149.556 Y114.887 I10.853 J-14.005 E.17076
G2 X153.063 Y115.813 I9.734 J-29.743 E.11152
G3 X154.773 Y116.396 I-1.338 J6.731 E.05565
G3 X155.981 Y117.565 I-2.788 J4.089 E.05192
G2 X158.238 Y120.441 I41.909 J-30.57 E.11237
G2 X162.618 Y123.937 I12.424 J-11.074 E.17301
G3 X164.784 Y125.21 I-16.302 J30.206 E.07721
G3 X166.104 Y126.854 I-1.827 J2.82 E.06591
G3 X167.3 Y129.94 I-598.288 J233.587 E.1017
G2 X170.934 Y135.353 I15.699 J-6.612 E.20157
G3 X172.646 Y137.222 I-17.223 J17.508 E.07792
G3 X173.302 Y138.957 I-2.618 J1.981 E.05777
G3 X173.36 Y139.508 I-10.397 J1.372 E.01705
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30194
G1 X154.687 Y145.778 E-.38756
G1 X154.608 Y145.61 E-.0705
; WIPE_END
G1 E-.04 F1800
G1 X156.194 Y146.488 Z8.2 F36000
G1 Z7.8
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42196
G1 F15000
G1 X155.463 Y145.757 E.03193
G2 X155.02 Y144.777 I-10.922 J4.354 E.03321
G1 X156.437 Y146.195 E.06191
G1 X156.809 Y146.031 E.01255
G1 X154.486 Y143.708 E.10146
G2 X153.809 Y142.495 I-36.166 J19.387 E.0429
G1 X157.18 Y145.866 E.14726
G1 X157.552 Y145.702 E.01255
G1 X152.913 Y141.063 E.20264
G2 X151.492 Y139.105 I-18.139 J11.677 E.07476
G1 X158.053 Y145.666 E.28659
G1 X159.911 Y144.845 F36000
G1 F15000
G1 X125.12 Y110.053 E1.51973
G3 X124.723 Y110.192 I-2.483 J-6.445 E.01299
G1 X159.411 Y144.88 E1.51521
G1 X159.039 Y145.045 E.01255
G1 X124.319 Y110.325 E1.51659
G1 X123.916 Y110.457 E.01312
G1 X158.667 Y145.209 E1.51798
G1 X158.296 Y145.373 E.01255
G1 X123.506 Y110.583 E1.51965
G1 X123.087 Y110.701 E.01343
G1 X146.556 Y134.17 E1.02514
G2 X144.599 Y132.748 I-13.648 J16.737 E.07476
G1 X122.657 Y110.806 E.95844
G3 X122.219 Y110.904 I-1.128 J-4.012 E.01387
G1 X129.093 Y117.779 E.30029
G2 X128.424 Y117.646 I-1.343 J5.006 E.02109
G1 X121.766 Y110.988 E.29085
G1 X121.313 Y111.071 E.01422
G1 X127.872 Y117.63 E.2865
G2 X127.386 Y117.68 I.017 J2.54 E.01511
G1 X120.834 Y111.128 E.28618
G1 X120.353 Y111.183 E.01495
G1 X126.941 Y117.771 E.28773
G2 X126.537 Y117.903 I.387 J1.855 E.01314
G1 X119.853 Y111.219 E.29197
G1 X119.343 Y111.245 E.01579
G1 X126.167 Y118.069 E.29808
G2 X125.824 Y118.262 I.69 J1.616 E.01217
G1 X118.814 Y111.252 E.30622
G1 X118.272 Y111.246 E.01673
G1 X125.511 Y118.485 E.31619
G2 X125.225 Y118.735 I.968 J1.391 E.01176
G1 X117.725 Y111.235 E.32761
G1 X117.158 Y111.204 E.01756
G1 X124.964 Y119.01 E.34099
G2 X124.727 Y119.31 I1.211 J1.201 E.01181
G1 X116.59 Y111.172 E.35544
G1 X116.023 Y111.141 E.01755
G1 X124.516 Y119.635 E.371
G2 X124.332 Y119.987 I1.472 J.992 E.0123
G1 X115.466 Y111.12 E.38731
G2 X114.93 Y111.121 I-.261 J3.567 E.01654
G1 X124.179 Y120.37 E.404
G2 X124.062 Y120.788 I1.796 J.729 E.01346
G1 X114.436 Y111.162 E.42048
G2 X114.006 Y111.269 I.193 J1.703 E.01371
G1 X123.988 Y121.251 E.43603
G2 X123.972 Y121.77 I2.295 J.334 E.01608
G1 X113.65 Y111.448 E.45088
G1 X113.316 Y111.651 E.01205
G1 X124.035 Y122.369 E.4682
G2 X124.242 Y123.112 I4.124 J-.748 E.02386
G1 X113.002 Y111.873 E.49095
G1 X112.693 Y112.099 E.01185
G1 X128.323 Y127.729 E.68273
G2 X127.785 Y127.727 I-.295 J7.698 E.01662
G1 X112.383 Y112.326 E.67276
G1 X112.073 Y112.552 E.01185
G1 X127.258 Y127.737 E.66327
G2 X126.739 Y127.753 I-.02 J7.444 E.01605
G1 X111.764 Y112.778 E.65412
G1 X111.454 Y113.005 E.01185
G1 X126.229 Y127.78 E.64539
G2 X125.726 Y127.813 I.22 J7.221 E.01558
G1 X111.14 Y113.227 E.63711
G1 X110.821 Y113.444 E.01192
G1 X125.233 Y127.856 E.62951
G2 X124.744 Y127.903 I.435 J7.039 E.01517
M73 P92 R1
G1 X110.502 Y113.661 E.6221
G3 X110.181 Y113.876 I-2.025 J-2.678 E.01194
G1 X124.267 Y127.962 E.61527
G2 X123.791 Y128.022 I.622 J6.849 E.01482
G1 X109.846 Y114.077 E.60912
G1 X109.511 Y114.278 E.01207
G1 X123.328 Y128.095 E.60355
G1 X122.866 Y128.169 E.01447
G1 X109.168 Y114.471 E.59833
G1 X108.814 Y114.653 E.01229
G1 X122.415 Y128.254 E.59408
G1 X121.966 Y128.341 E.01412
G1 X108.461 Y114.836 E.58991
G3 X108.093 Y115.004 I-1.426 J-2.635 E.0125
G1 X121.525 Y128.436 E.58672
G1 X121.089 Y128.537 E.01381
G1 X107.719 Y115.167 E.58402
G3 X107.345 Y115.328 I-1.433 J-2.803 E.0126
G1 X120.657 Y128.64 E.58149
G1 X120.234 Y128.754 E.01352
G1 X106.95 Y115.47 E.58025
G1 X106.556 Y115.612 E.01294
G1 X119.812 Y128.867 E.57901
G2 X119.399 Y128.991 I1.572 J5.987 E.0133
G1 X106.151 Y115.743 E.57868
G1 X105.736 Y115.864 E.01336
G1 X118.989 Y129.116 E.57889
G2 X118.583 Y129.247 I1.662 J5.86 E.01316
G1 X105.321 Y115.984 E.57931
G3 X104.897 Y116.097 I-1.368 J-4.31 E.01355
G1 X118.184 Y129.384 E.58041
G1 X117.786 Y129.521 E.01303
G1 X104.464 Y116.2 E.58189
G1 X104.032 Y116.303 E.01374
G1 X117.398 Y129.669 E.58384
G1 X117.01 Y129.818 E.01282
G1 X103.599 Y116.407 E.58582
G1 X103.166 Y116.51 E.01374
G1 X116.628 Y129.972 E.58801
G1 X116.251 Y130.131 E.01263
G1 X102.741 Y116.621 E.59014
G2 X102.325 Y116.741 I.522 J2.586 E.01339
G1 X115.875 Y130.291 E.59187
G2 X115.508 Y130.46 I2.241 J5.346 E.01248
G1 X101.929 Y116.881 E.59315
G2 X101.566 Y117.054 I.359 J1.227 E.01248
G1 X115.143 Y130.631 E.59306
G2 X114.78 Y130.804 I2.304 J5.285 E.01242
G1 X101.256 Y117.28 E.59074
G2 X100.988 Y117.548 I.807 J1.075 E.01175
G1 X114.425 Y130.985 E.58694
G1 X114.07 Y131.166 E.01231
G1 X100.736 Y117.832 E.58241
G1 X100.504 Y118.136 E.01181
G1 X113.721 Y131.354 E.57733
G1 X113.376 Y131.545 E.01218
G1 X100.272 Y118.44 E.5724
G1 X100.04 Y118.744 E.01181
G1 X113.032 Y131.736 E.56748
G1 X112.697 Y131.937 E.01207
G1 X99.808 Y119.049 E.56299
G1 X99.576 Y119.353 E.01181
G1 X112.362 Y132.138 E.55849
G2 X112.031 Y132.343 I2.661 J4.682 E.01203
G1 X99.344 Y119.657 E.55415
G3 X99.111 Y119.959 I-3.687 J-2.6 E.01181
G1 X111.706 Y132.554 E.55016
G1 X111.381 Y132.766 E.01197
G1 X98.867 Y120.252 E.54662
G1 X98.624 Y120.544 E.01176
G1 X111.062 Y132.982 E.5433
G1 X110.746 Y133.203 E.01189
G1 X98.38 Y120.837 E.54016
G3 X98.125 Y121.118 I-2.413 J-1.936 E.01173
G1 X110.431 Y133.424 E.53754
G2 X110.125 Y133.653 I3.159 J4.535 E.01183
G1 X97.865 Y121.394 E.53551
G1 X97.605 Y121.67 E.01171
G1 X109.819 Y133.884 E.53352
G2 X109.515 Y134.116 I3.176 J4.471 E.01181
G1 X106.392 Y130.993 E.13642
G3 X106.546 Y131.683 I-2.983 J1.029 E.02189
G1 X109.219 Y134.356 E.11674
G1 X108.923 Y134.596 E.01177
G1 X106.58 Y132.253 E.10231
G3 X106.542 Y132.751 I-2.226 J.077 E.01544
G1 X108.631 Y134.84 E.09125
G1 X108.344 Y135.089 E.01174
G1 X106.454 Y133.199 E.08256
G3 X106.327 Y133.608 I-1.882 J-.359 E.01326
G1 X108.057 Y135.338 E.07557
G2 X107.777 Y135.594 I3.521 J4.137 E.01172
G1 X106.167 Y133.984 E.07032
G1 X105.976 Y134.329 E.01218
G1 X107.5 Y135.853 E.06654
G1 X107.222 Y136.111 E.01171
G1 X105.756 Y134.645 E.06405
G3 X105.51 Y134.935 I-1.411 J-.944 E.01177
G1 X106.954 Y136.379 E.06306
G1 X106.686 Y136.647 E.01171
G1 X105.24 Y135.201 E.06314
G3 X104.946 Y135.443 I-1.218 J-1.185 E.01179
G1 X106.42 Y136.917 E.06438
G1 X106.161 Y137.194 E.01171
G1 X104.626 Y135.659 E.06705
G3 X104.279 Y135.848 I-1.013 J-1.445 E.01223
G1 X105.902 Y137.471 E.07091
G2 X105.648 Y137.753 I3.905 J3.788 E.01172
G1 X103.9 Y136.005 E.07634
G3 X103.486 Y136.127 I-.747 J-1.775 E.01336
G1 X105.398 Y138.04 E.08355
G1 X105.149 Y138.326 E.01174
G1 X103.032 Y136.209 E.09249
G3 X102.525 Y136.239 I-.874 J-10.508 E.01566
G1 X104.906 Y138.62 E.10399
G1 X104.666 Y138.916 E.01177
G1 X101.936 Y136.186 E.11927
G3 X101.234 Y136.02 I.508 J-3.714 E.02232
G1 X104.427 Y139.212 E.13945
G2 X104.196 Y139.517 I4.293 J3.488 E.01182
G1 X91.022 Y126.344 E.57542
G3 X91.293 Y126.078 I1 J.748 E.01175
G1 X98.73 Y133.516 E.32487
G3 X98.561 Y132.811 I3.042 J-1.101 E.02243
G1 X91.596 Y125.845 E.30427
G3 X91.92 Y125.633 I1.372 J1.748 E.01198
G1 X98.511 Y132.224 E.28789
G1 X98.541 Y131.718 E.01566
G1 X92.251 Y125.428 E.27474
G1 X92.591 Y125.232 E.01212
G1 X98.625 Y131.266 E.26358
G3 X98.745 Y130.85 I8.492 J2.211 E.01339
G1 X92.931 Y125.036 E.25396
G1 X93.27 Y124.84 E.01212
G1 X98.902 Y130.471 E.24597
G3 X99.091 Y130.124 I1.633 J.665 E.01223
G1 X93.61 Y124.643 E.23939
G1 X93.95 Y124.447 E.01212
G1 X99.307 Y129.804 E.23399
G3 X99.548 Y129.51 I1.429 J.926 E.01179
G1 X94.282 Y124.244 E.23002
G1 X94.614 Y124.039 E.01203
G1 X99.814 Y129.239 E.22718
G3 X100.105 Y128.994 I1.236 J1.167 E.01177
G1 X94.94 Y123.829 E.22559
G1 X95.261 Y123.614 E.01193
G1 X100.42 Y128.773 E.22537
G1 X100.766 Y128.583 E.01218
G1 X95.574 Y123.391 E.22676
G1 X95.884 Y123.165 E.01185
G1 X101.142 Y128.423 E.22964
G3 X101.551 Y128.296 I.767 J1.751 E.01326
G1 X96.183 Y122.927 E.23449
G1 X96.478 Y122.687 E.01177
G1 X102.004 Y128.213 E.24137
G3 X102.496 Y128.169 I.471 J2.528 E.0153
G1 X96.774 Y122.447 E.24997
G2 X97.052 Y122.188 I-1.773 J-2.187 E.01172
G1 X103.067 Y128.203 E.26274
G3 X103.757 Y128.358 I-.339 J3.138 E.02189
G1 X97.209 Y121.81 E.28602
; WIPE_START
G1 X98.623 Y123.224 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X100.994 Y130.479 Z8.2 F36000
G1 X104.086 Y139.944 Z8.2
G1 Z7.8
G1 E.8 F1800
G1 F15000
G1 X90.799 Y126.657 E.58038
G1 X90.622 Y127.015 E.01235
G1 X103.737 Y140.131 E.57289
G1 X103.516 Y140.446 E.01189
G1 X90.459 Y127.388 E.57037
G1 X90.305 Y127.77 E.01272
G1 X103.295 Y140.761 E.56745
G2 X103.08 Y141.081 I4.485 J3.258 E.01193
G1 X90.159 Y128.161 E.56437
G1 X90.014 Y128.552 E.01288
G1 X102.868 Y141.406 E.5615
G1 X102.657 Y141.731 E.01197
G1 X89.869 Y128.942 E.55863
G1 X89.723 Y129.333 E.01288
G1 X102.455 Y142.064 E.55611
G1 X102.254 Y142.4 E.01207
G1 X89.576 Y129.722 E.55379
G1 X89.418 Y130.1 E.01267
G1 X102.053 Y142.735 E.5519
G1 X101.862 Y143.08 E.01218
G1 X89.261 Y130.479 E.55041
G3 X89.091 Y130.845 I-3.865 J-1.578 E.01247
G1 X101.671 Y143.425 E.5495
G2 X101.485 Y143.775 I4.917 J2.843 E.01224
G1 X88.919 Y131.209 E.54888
G3 X88.741 Y131.567 I-3.032 J-1.282 E.01236
G1 X101.304 Y144.13 E.54874
G1 X101.123 Y144.485 E.01231
G1 X88.551 Y131.913 E.54914
G1 X88.361 Y132.259 E.01219
G1 X100.951 Y144.849 E.54993
G1 X100.78 Y145.215 E.01246
G1 X88.159 Y132.594 E.5513
G1 X87.95 Y132.92 E.01199
G1 X100.613 Y145.584 E.55314
G1 X100.457 Y145.963 E.01268
G1 X87.741 Y133.247 E.55543
G3 X87.52 Y133.562 I-2.906 J-1.802 E.01189
G1 X100.3 Y146.342 E.55824
G1 X100.238 Y146.491 E.00498
G1 X99.655 Y146.234 E.01969
G1 X87.295 Y133.874 E.53989
G3 X87.061 Y134.175 I-3.811 J-2.723 E.0118
G1 X98.695 Y145.809 E.50818
G1 X97.734 Y145.385 E.03243
G1 X86.824 Y134.475 E.47657
G1 X86.575 Y134.761 E.01174
G1 X96.774 Y144.96 E.4455
G1 X95.813 Y144.536 E.03243
G1 X86.325 Y135.048 E.41444
G1 X86.076 Y135.335 E.01174
G1 X94.853 Y144.112 E.38338
G1 X93.892 Y143.687 E.03243
G1 X85.82 Y135.615 E.35262
G1 X85.56 Y135.891 E.01171
G1 X92.932 Y143.263 E.322
G1 X91.972 Y142.838 E.03243
G1 X85.301 Y136.168 E.29139
G1 X85.041 Y136.444 E.01171
G1 X91.011 Y142.414 E.26077
G1 X90.051 Y141.99 E.03243
G1 X84.782 Y136.721 E.23016
G1 X84.522 Y136.997 E.01171
G1 X89.09 Y141.565 E.19954
G1 X88.13 Y141.141 E.03243
G1 X84.263 Y137.274 E.16892
G1 X84.027 Y137.574 E.01179
G1 X87.169 Y140.716 E.13726
G1 X86.209 Y140.292 E.03243
G1 X83.796 Y137.879 E.10541
G2 X83.611 Y138.23 I1.022 J.764 E.0123
G1 X85.248 Y139.868 E.07154
G1 X84.288 Y139.443 E.03243
G1 X83.347 Y138.502 E.04111
; WIPE_START
G1 X84.288 Y139.443 E-.50578
G1 X84.9 Y139.714 E-.25423
; WIPE_END
G1 E-.04 F1800
G1 X92.273 Y137.742 Z8.2 F36000
G1 X129.041 Y127.911 Z8.2
G1 Z7.8
G1 E.8 F1800
G1 F15000
G1 X126.549 Y125.42 E.10884
G2 X127.287 Y125.622 I1.37 J-3.554 E.02368
G1 X129.427 Y127.762 E.09347
G1 X129.993 Y127.791 E.0175
G1 X127.891 Y125.69 E.09181
G2 X128.41 Y125.673 I.186 J-2.311 E.01608
G1 X130.577 Y127.839 E.09462
G3 X131.165 Y127.892 I-.461 J8.467 E.01826
G1 X128.873 Y125.599 E.10013
G2 X129.292 Y125.482 I-.312 J-1.92 E.01346
G1 X131.776 Y127.967 E.10854
G3 X132.397 Y128.051 I-.895 J8.91 E.01934
G1 X129.675 Y125.329 E.11891
G2 X130.027 Y125.145 I-.639 J-1.656 E.0123
G1 X133.034 Y128.152 E.13134
G3 X133.692 Y128.274 I-1.415 J9.477 E.02067
G1 X130.352 Y124.934 E.14589
G2 X130.651 Y124.697 I-.901 J-1.447 E.01181
G1 X134.363 Y128.409 E.16215
G1 X135.06 Y128.57 E.02209
G1 X130.926 Y124.436 E.18058
G2 X131.176 Y124.151 I-1.143 J-1.255 E.01176
G1 X135.784 Y128.758 E.20126
G3 X136.53 Y128.968 I-2.525 J10.414 E.02393
G1 X131.399 Y123.837 E.22411
G2 X131.593 Y123.495 I-1.422 J-1.032 E.01217
G1 X137.304 Y129.207 E.24949
G1 X138.122 Y129.488 E.02671
G1 X131.758 Y123.124 E.27798
G2 X131.891 Y122.721 I-1.725 J-.792 E.01314
G1 X138.984 Y129.814 E.30985
G3 X139.899 Y130.193 I-4.964 J13.279 E.0306
G1 X131.985 Y122.279 E.3457
G2 X132.032 Y121.79 I-2.148 J-.451 E.01522
G1 X140.882 Y130.64 E.38658
G3 X141.953 Y131.175 I-7.122 J15.592 E.03701
G1 X132.015 Y121.237 E.4341
G2 X131.882 Y120.568 I-5.137 J.674 E.02109
G1 X143.662 Y132.348 E.51456
G1 X153.562 Y116.517 F36000
M73 P93 R1
G1 F15000
G1 X157.665 Y120.621 E.17925
; WIPE_START
G1 X156.251 Y119.207 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X162.137 Y124.065 Z8.2 F36000
G1 X165.461 Y126.809 Z8.2
G1 Z7.8
G1 E.8 F1800
G1 F15000
G1 X164.748 Y126.096 E.03114
G2 X163.251 Y125.135 I-6.313 J8.189 E.05501
G1 X165.563 Y127.446 E.10096
G3 X165.901 Y128.321 I-15.057 J6.33 E.02897
G1 X161.973 Y124.392 E.17159
G3 X160.45 Y123.405 I9.789 J-16.774 E.05608
G1 X166.222 Y129.178 E.25214
G2 X166.576 Y130.068 I10.506 J-3.665 E.02961
G1 X153.085 Y116.576 E.58932
G1 X152.377 Y116.405 E.02249
G1 X166.996 Y131.023 E.63856
G2 X167.573 Y132.137 I10.892 J-4.942 E.03876
G1 X151.669 Y116.233 E.69469
G1 X150.962 Y116.061 E.02249
G1 X168.542 Y133.642 E.76795
G2 X170.011 Y135.429 I15.845 J-11.528 E.07148
G1 X171.742 Y137.263 E.07788
G1 X172.175 Y137.811 E.02158
G1 X150.211 Y115.846 E.95943
G3 X149.434 Y115.606 I1.54 J-6.354 E.02511
G1 X172.519 Y138.691 E1.00836
G3 X172.579 Y139.06 I-1.956 J.509 E.01158
G1 X172.422 Y139.13 E.00531
G1 X148.591 Y115.299 E1.04094
G1 X147.644 Y114.888 E.0319
G1 X172.05 Y139.294 E1.06608
G1 X171.678 Y139.459 E.01255
G1 X146.505 Y114.285 E1.0996
G3 X145.014 Y113.33 I7.612 J-13.525 E.05473
G1 X171.307 Y139.623 E1.1485
G1 X170.935 Y139.787 E.01255
G1 X143.067 Y111.92 E1.21727
G2 X141.941 Y111.249 I-4.04 J5.505 E.04055
G1 X141.82 Y111.209 E.00394
G1 X170.563 Y139.951 E1.25552
G1 X170.191 Y140.116 E.01255
G1 X141.194 Y111.118 E1.26664
G2 X140.65 Y111.11 I-.326 J3.607 E.01682
G1 X169.82 Y140.28 E1.27417
G1 X169.448 Y140.444 E.01255
G1 X140.132 Y111.128 E1.28056
G1 X139.625 Y111.157 E.01568
G1 X169.076 Y140.609 E1.28646
G1 X168.704 Y140.773 E.01255
G1 X139.118 Y111.186 E1.29236
G1 X138.611 Y111.216 E.01568
G1 X168.333 Y140.937 E1.29827
G1 X167.961 Y141.102 E.01255
G1 X138.101 Y111.242 E1.30429
G1 X137.571 Y111.248 E.01638
G1 X154.686 Y128.363 E.74759
G2 X153.993 Y128.206 I-1.041 J2.995 E.02198
G1 X137.041 Y111.253 E.7405
G3 X136.487 Y111.236 I-.133 J-4.565 E.01712
G1 X153.42 Y128.169 E.73963
G2 X152.922 Y128.206 I-.082 J2.23 E.01547
G1 X135.923 Y111.208 E.7425
G3 X135.325 Y111.146 I.181 J-4.672 E.01857
G1 X152.472 Y128.293 E.74899
G2 X152.062 Y128.419 I.354 J1.882 E.01328
G1 X134.719 Y111.076 E.75757
G1 X134.062 Y110.955 E.02062
G1 X151.685 Y128.578 E.76978
G1 X151.34 Y128.769 E.01218
G1 X133.383 Y110.812 E.78436
G1 X132.668 Y110.633 E.02276
G1 X151.024 Y128.989 E.80177
G2 X150.733 Y129.234 I.942 J1.415 E.01178
G1 X131.898 Y110.399 E.82272
G3 X131.084 Y110.121 I2.985 J-10.08 E.02656
G1 X150.468 Y129.505 E.84672
G2 X150.224 Y129.797 I1.01 J1.097 E.01178
G1 X130.257 Y109.83 E.87215
G1 X129.43 Y109.539 E.02707
G1 X150.007 Y130.116 E.89879
G2 X149.817 Y130.462 I1.439 J1.015 E.01222
G1 X128.658 Y109.303 E.92425
G2 X128.016 Y109.198 I-.872 J3.31 E.0201
G1 X149.66 Y130.841 E.9454
G2 X149.537 Y131.254 I1.777 J.752 E.01334
G1 X127.535 Y109.252 E.96109
G2 X127.103 Y109.357 I.388 J2.536 E.01372
G1 X149.454 Y131.707 E.9763
G2 X149.422 Y132.211 I11.363 J.984 E.01559
G1 X126.695 Y109.485 E.9927
G2 X126.3 Y109.625 I1.414 J4.621 E.01297
G1 X149.471 Y132.796 E1.01213
G2 X149.642 Y133.504 I4.211 J-.646 E.02252
G1 X125.906 Y109.768 E1.0368
G1 X125.513 Y109.91 E.01292
G1 X160.154 Y144.552 E1.51317
G1 X160.526 Y144.388 E.01255
G1 X152.163 Y136.025 E.3653
G2 X152.865 Y136.191 I1.088 J-3.031 E.02234
G1 X160.898 Y144.223 E.35086
G1 X161.27 Y144.059 E.01255
G1 X153.458 Y136.24 E.34137
G2 X153.954 Y136.207 I.102 J-2.217 E.01538
G1 X161.641 Y143.895 E.33579
G1 X162.013 Y143.73 E.01255
G1 X154.407 Y136.124 E.33224
G2 X154.815 Y135.997 I-.456 J-2.177 E.01324
G1 X162.385 Y143.566 E.33064
G1 X162.757 Y143.402 E.01255
G1 X155.2 Y135.845 E.3301
G1 X155.546 Y135.655 E.01219
G1 X163.128 Y143.237 E.33122
G1 X163.5 Y143.073 E.01255
G1 X155.865 Y135.438 E.33352
G2 X156.158 Y135.195 I-.928 J-1.425 E.01179
G1 X163.872 Y142.909 E.33693
G1 X164.244 Y142.745 E.01255
G1 X156.428 Y134.929 E.3414
G2 X156.673 Y134.638 I-1.168 J-1.231 E.01178
G1 X164.615 Y142.58 E.34694
G1 X164.987 Y142.416 E.01255
G1 X156.893 Y134.321 E.35358
G1 X157.083 Y133.976 E.01218
G1 X165.359 Y142.252 E.36148
G1 X165.731 Y142.087 E.01255
G1 X157.242 Y133.599 E.37077
G2 X157.368 Y133.189 I-1.76 J-.766 E.01328
G1 X166.102 Y141.923 E.3815
G1 X166.474 Y141.759 E.01255
G1 X157.454 Y132.739 E.39399
G2 X157.493 Y132.241 I-1.912 J-.398 E.01546
G1 X166.846 Y141.594 E.40854
G1 X167.218 Y141.43 E.01255
G1 X157.455 Y131.668 E.42642
G2 X157.299 Y130.975 I-3.151 J.349 E.02198
G1 X167.718 Y141.395 E.45512
; CHANGE_LAYER
; Z_HEIGHT: 8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X166.304 Y139.98 E-.76
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
G1 X124.721 Y121.289
G1 Z8
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.644 Y118.369 I3.287 J.367 E.13712
G1 X128.002 Y118.349 E.01104
G3 X124.715 Y121.349 I.006 J3.308 E.48857
; WIPE_START
M204 S10000
G1 X124.775 Y120.922 E-.16374
G1 X124.878 Y120.566 E-.14106
G1 X125.02 Y120.223 E-.14106
G1 X125.199 Y119.898 E-.14107
G1 X125.414 Y119.595 E-.14103
G1 X125.47 Y119.532 E-.03204
; WIPE_END
G1 E-.04 F1800
G1 X132.599 Y122.258 Z8.4 F36000
G1 X156.686 Y131.467 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S6000
G1 X156.745 Y131.833 E.01138
G3 X153.088 Y128.914 I-3.287 J.368 E.47887
G1 X153.458 Y128.893 E.01141
G3 X156.67 Y131.411 I0 J3.308 E.13514
; WIPE_START
M204 S10000
G1 X156.745 Y131.833 E-.16296
G1 X156.768 Y132.203 E-.14101
G1 X156.748 Y132.574 E-.14105
G1 X156.685 Y132.94 E-.1411
G1 X156.583 Y133.297 E-.14105
G1 X156.55 Y133.376 E-.03283
; WIPE_END
G1 E-.04 F1800
G1 X148.943 Y132.751 Z8.4 F36000
G1 X102.211 Y128.912 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S6000
G1 X102.546 Y128.893 E.01033
G3 X102.151 Y128.917 I.006 J3.308 E.6264
; WIPE_START
M204 S10000
G1 X102.546 Y128.893 E-.15051
G1 X102.917 Y128.914 E-.14105
G1 X103.283 Y128.976 E-.1411
G1 X103.64 Y129.079 E-.14104
G1 X103.983 Y129.221 E-.14106
G1 X104.087 Y129.278 E-.04525
; WIPE_END
G1 E-.04 F1800
G1 X111.281 Y131.829 Z8.4 F36000
G1 X155.37 Y147.459 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S6000
G2 X100.634 Y147.459 I-27.368 J10.195 E2.17924
G1 X82.639 Y139.508 E.60452
G3 X82.961 Y137.888 I5.201 J.192 E.05096
G3 X83.717 Y136.795 I3.892 J1.884 E.04098
G2 X85.862 Y134.49 I-446.734 J-417.765 E.09677
G2 X89.134 Y128.85 I-12.825 J-11.212 E.20159
G3 X90.062 Y126.493 I23.44 J7.865 E.07787
G3 X91.212 Y125.225 I2.76 J1.348 E.05331
G3 X93.152 Y124.073 I16.121 J24.937 E.06934
G2 X97.766 Y120.441 I-8.372 J-15.38 E.18128
G2 X100.017 Y117.563 I-37.392 J-31.569 E.11231
G3 X101.193 Y116.421 I3.822 J2.758 E.05061
G3 X102.951 Y115.816 I3.187 J6.402 E.0573
G2 X106.449 Y114.887 I-6.459 J-31.367 E.11125
G2 X111.304 Y112.217 I-5.976 J-16.615 E.17096
G3 X113.321 Y110.794 I14.818 J18.872 E.07588
G3 X115.144 Y110.385 I1.638 J3.035 E.05814
G3 X117.867 Y110.517 I-7.464 J182.725 E.08377
G2 X124.886 Y109.368 I.799 J-17.124 E.22012
G3 X127.261 Y108.562 I8.739 J21.848 E.07711
G3 X128.135 Y108.474 I.777 J3.362 E.02707
G3 X129.988 Y108.957 I-.884 J7.194 E.05903
G2 X133.814 Y110.172 I10.803 J-27.382 E.12342
G2 X138.711 Y110.489 I3.55 J-16.867 E.15131
G3 X141.262 Y110.387 I2.303 J25.795 E.07849
G3 X142.884 Y110.921 I-.111 J3.07 E.05317
G3 X144.706 Y112.222 I-15.563 J23.717 E.06878
G2 X149.556 Y114.887 I10.853 J-14.006 E.17077
G2 X153.059 Y115.812 I9.723 J-29.708 E.11138
G3 X154.703 Y116.356 I-1.359 J6.868 E.05335
G3 X155.765 Y117.301 I-1.906 J3.211 E.04394
G2 X157.819 Y119.952 I1359.977 J-1051.445 E.10304
G2 X162.618 Y123.937 I12.925 J-10.684 E.19281
G3 X164.784 Y125.21 I-16.314 J30.226 E.07721
G3 X166.104 Y126.854 I-1.827 J2.82 E.0659
G3 X167.3 Y129.94 I-596.632 J232.944 E.10169
G2 X170.934 Y135.353 I15.703 J-6.614 E.20158
G3 X172.647 Y137.222 I-17.214 J17.5 E.07793
G3 X173.302 Y138.956 I-2.619 J1.98 E.05776
G3 X173.36 Y139.508 I-10.394 J1.372 E.01706
G1 X155.425 Y147.435 E.60251
; WIPE_START
M204 S10000
G1 X155.085 Y146.717 E-.30195
G1 X154.682 Y145.767 E-.39221
G1 X154.608 Y145.61 E-.06583
; WIPE_END
G1 E-.04 F1800
G1 X161.753 Y142.924 Z8.4 F36000
G1 X173.047 Y138.678 Z8.4
G1 Z8
G1 E.8 F1800
; FEATURE: Top surface
G1 F12000
M204 S2000
G1 X171.717 Y140.008 E.05779
G1 X170.762 Y140.43
M73 P94 R1
G1 X172.946 Y138.246 E.09489
G1 X172.801 Y137.858
G1 X169.806 Y140.852 E.13012
G1 X168.851 Y141.275
G1 X172.605 Y137.521 E.16312
G1 X172.369 Y137.223
G1 X167.895 Y141.697 E.19443
G1 X166.939 Y142.119
G1 X172.134 Y136.925 E.22573
G1 X171.876 Y136.65
G1 X165.984 Y142.542 E.25602
G1 X165.028 Y142.964
G1 X171.617 Y136.376 E.2863
G1 X171.358 Y136.101
G1 X164.073 Y143.386 E.31657
G1 X163.117 Y143.809
G1 X171.099 Y135.827 E.34685
G1 X170.84 Y135.553
G1 X162.161 Y144.231 E.37712
G1 X161.206 Y144.653
G1 X170.581 Y135.278 E.40739
G1 X170.325 Y135.001
G1 X160.25 Y145.076 E.4378
G1 X159.295 Y145.498
G1 X170.077 Y134.716 E.46854
G1 X169.829 Y134.431
G1 X158.339 Y145.92 E.49928
G1 X157.383 Y146.343
G1 X169.581 Y134.146 E.53003
G1 X169.345 Y133.848
G1 X156.428 Y146.765 E.56133
G1 X155.484 Y147.176
G1 X169.113 Y133.547 E.59224
G1 X168.889 Y133.238
G1 X155.336 Y146.791 E.58895
G1 X155.181 Y146.412
G1 X168.67 Y132.924 E.58614
G1 X168.458 Y132.602
G1 X155.022 Y146.038 E.58386
G1 X154.863 Y145.664
G1 X168.253 Y132.273 E.58189
G1 X168.055 Y131.939
G1 X154.693 Y145.3 E.58063
G1 X154.523 Y144.937
G1 X167.867 Y131.593 E.57983
G1 X167.684 Y131.243
G1 X154.348 Y144.579 E.57949
G1 X154.168 Y144.225
G1 X167.502 Y130.892 E.57941
G1 X167.336 Y130.524
G1 X153.988 Y143.872 E.58003
G1 X153.799 Y143.528
G1 X167.17 Y130.157 E.58105
G1 X167.014 Y129.78
G1 X153.609 Y143.185 E.58251
G1 X153.415 Y142.845
G1 X166.863 Y129.398 E.58434
G1 X166.711 Y129.016
G1 X153.215 Y142.512 E.58647
G1 X153.015 Y142.179
G1 X166.566 Y128.629 E.58883
G1 X166.421 Y128.24
G1 X152.808 Y141.853 E.59155
G1 X152.598 Y141.529
G1 X166.277 Y127.851 E.5944
G1 X166.129 Y127.465
G1 X152.388 Y141.206 E.59712
G1 X152.169 Y140.892
G1 X165.975 Y127.086 E.59995
G1 X165.806 Y126.722
G1 X151.949 Y140.579 E.60216
G1 X151.726 Y140.268
G1 X165.627 Y126.367 E.60406
G1 X165.413 Y126.048
G1 X151.497 Y139.964 E.60472
G1 X151.268 Y139.66
G1 X165.155 Y125.773 E.60346
G1 X164.863 Y125.532
G1 X156.582 Y133.813 E.35986
G1 X156.891 Y132.971
G1 X164.553 Y125.309 E.33295
G1 X164.226 Y125.102
G1 X156.967 Y132.361 E.31544
G1 X156.956 Y131.839
G1 X163.891 Y124.904 E.30136
G1 X163.552 Y124.71
G1 X156.878 Y131.384 E.29002
G1 X156.752 Y130.977
G1 X163.213 Y124.516 E.28074
G1 X162.873 Y124.322
G1 X156.589 Y130.606 E.27309
G1 X156.393 Y130.269
G1 X162.534 Y124.128 E.26688
G1 X162.203 Y123.926
G1 X156.166 Y129.962 E.26231
G1 X155.911 Y129.685
G1 X161.872 Y123.724 E.25902
G1 X161.541 Y123.522
G1 X155.627 Y129.435 E.25698
G1 X155.314 Y129.215
G1 X161.22 Y123.309 E.25665
G1 X160.902 Y123.094
G1 X154.969 Y129.027 E.25782
G1 X154.589 Y128.874
G1 X160.593 Y122.869 E.26092
G1 X160.289 Y122.64
G1 X154.167 Y128.762 E.26603
G1 X153.697 Y128.699
G1 X159.995 Y122.401 E.27367
G1 X159.701 Y122.162
G1 X153.161 Y128.702 E.28421
G1 X152.508 Y128.822
G1 X159.417 Y121.913 E.30023
G1 X159.141 Y121.655
G1 X151.536 Y129.26 E.33047
; WIPE_START
M204 S10000
G1 X152.95 Y127.846 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.029 Y135.19 Z8.4 F36000
G1 X155.068 Y135.327 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X151.033 Y139.362 E.17535
G1 X150.794 Y139.067
G1 X154.226 Y135.636 E.14912
G1 X153.616 Y135.712
G1 X150.556 Y138.773 E.13298
G1 X150.308 Y138.487
G1 X153.094 Y135.701 E.12106
G1 X152.639 Y135.623
G1 X150.06 Y138.202 E.11206
G1 X149.811 Y137.918
G1 X152.231 Y135.497 E.1052
G1 X151.861 Y135.334
G1 X149.553 Y137.642 E.1003
G1 X149.296 Y137.366
G1 X151.524 Y135.138 E.09683
G1 X151.217 Y134.911
G1 X149.034 Y137.095 E.09487
G1 X148.767 Y136.828
G1 X150.939 Y134.656 E.09438
G1 X150.69 Y134.372
G1 X148.501 Y136.561 E.09514
G1 X148.227 Y136.302
G1 X150.47 Y134.059 E.09748
G1 X150.282 Y133.714
G1 X147.951 Y136.045 E.10128
G1 X147.675 Y135.788
G1 X150.129 Y133.334 E.10662
G1 X150.016 Y132.913
G1 X147.39 Y135.54 E.11413
G1 X147.104 Y135.292
G1 X149.954 Y132.442 E.12381
G1 X149.957 Y131.906
M73 P95 R1
G1 X146.816 Y135.047 E.13648
G1 X146.521 Y134.808
G1 X150.077 Y131.253 E.15449
G1 X150.515 Y130.281
G1 X146.227 Y134.57 E.18636
G1 X145.926 Y134.337
G1 X158.865 Y121.398 E.56224
M73 P95 R0
G1 X158.601 Y121.128
G1 X145.622 Y134.108 E.56401
G1 X145.318 Y133.878
G1 X158.342 Y120.854 E.56598
G1 X158.084 Y120.579
G1 X145.005 Y133.658 E.56833
G1 X144.691 Y133.438
G1 X157.841 Y120.289 E.57143
G1 X157.599 Y119.998
G1 X144.376 Y133.221 E.57462
G1 X144.052 Y133.011
G1 X157.357 Y119.707 E.57814
G1 X157.123 Y119.408
G1 X143.729 Y132.801 E.58202
G1 X143.4 Y132.597
G1 X156.893 Y119.104 E.58633
G1 X156.663 Y118.801
G1 X143.067 Y132.397 E.59082
G1 X142.734 Y132.197
G1 X156.433 Y118.497 E.59531
G1 X156.203 Y118.194
G1 X142.391 Y132.006 E.6002
G1 X142.048 Y131.816
G1 X155.971 Y117.893 E.60502
G1 X155.735 Y117.596
G1 X141.702 Y131.629 E.60979
G1 X141.349 Y131.449
G1 X155.489 Y117.308 E.61447
G1 X155.233 Y117.031
G1 X140.996 Y131.269 E.61868
G1 X140.635 Y131.096
G1 X154.948 Y116.782 E.622
G1 X154.632 Y116.566
G1 X140.271 Y130.927 E.62404
G1 X139.906 Y130.759
G1 X154.276 Y116.389 E.62445
G1 X153.881 Y116.25
G1 X139.531 Y130.6 E.62357
G1 X139.157 Y130.441
G1 X153.462 Y116.135 E.62165
G1 X153.033 Y116.031
G1 X138.775 Y130.289 E.61957
G1 X138.39 Y130.141
G1 X152.604 Y115.927 E.61767
G1 X152.175 Y115.823
G1 X138.003 Y129.995 E.61584
G1 X137.606 Y129.858
G1 X151.746 Y115.719 E.61443
G1 X151.317 Y115.615
G1 X137.21 Y129.722 E.61302
G1 X136.805 Y129.593
G1 X150.893 Y115.505 E.61219
G1 X150.48 Y115.385
G1 X136.396 Y129.469 E.61198
G1 X135.984 Y129.347
G1 X150.066 Y115.265 E.61193
G1 X149.661 Y115.138
G1 X135.564 Y129.235 E.61259
G1 X135.143 Y129.122
G1 X149.268 Y114.997 E.61381
G1 X148.876 Y114.856
G1 X134.711 Y129.021 E.61556
G1 X134.277 Y128.921
G1 X148.502 Y114.696 E.61814
G1 X148.131 Y114.535
G1 X133.836 Y128.83 E.62117
G1 X133.389 Y128.743
G1 X147.765 Y114.368 E.62467
G1 X147.413 Y114.186
G1 X132.938 Y128.661 E.62903
G1 X132.477 Y128.588
G1 X147.062 Y114.004 E.63376
G1 X146.72 Y113.813
G1 X132.014 Y128.518 E.63901
G1 X131.54 Y128.46
G1 X146.384 Y113.616 E.64505
G1 X146.057 Y113.409
G1 X131.064 Y128.402 E.65149
G1 X130.574 Y128.359
G1 X145.733 Y113.2 E.65873
G1 X145.417 Y112.982
G1 X130.083 Y128.316 E.66633
G1 X129.578 Y128.288
G1 X145.102 Y112.764 E.6746
G1 X144.793 Y112.54
G1 X129.071 Y128.262 E.68318
G1 X128.548 Y128.251
G1 X144.485 Y112.315 E.69252
G1 X144.177 Y112.089
G1 X128.024 Y128.242 E.70193
G1 X127.482 Y128.251
G1 X143.87 Y111.863 E.71212
G1 X143.562 Y111.637
G1 X126.938 Y128.262 E.7224
G1 X126.376 Y128.291
G1 X143.253 Y111.414 E.73339
G1 X142.932 Y111.201
G1 X131.327 Y122.806 E.50428
G1 X131.488 Y122.112
G1 X142.598 Y111.002 E.48279
G1 X142.248 Y110.819
G1 X131.514 Y121.552 E.46643
G1 X131.465 Y121.069
G1 X141.849 Y110.685 E.45124
G1 X141.392 Y110.609
G1 X131.363 Y120.637 E.43578
G1 X131.219 Y120.248
G1 X140.88 Y110.587 E.41981
G1 X140.331 Y110.602
M73 P96 R0
G1 X131.04 Y119.894 E.40376
G1 X130.828 Y119.572
G1 X139.77 Y110.63 E.38858
G1 X139.205 Y110.663
G1 X130.587 Y119.28 E.37448
G1 X130.317 Y119.017
G1 X138.639 Y110.695 E.36162
G1 X138.076 Y110.724
G1 X130.018 Y118.783 E.35017
G1 X129.689 Y118.578
G1 X137.537 Y110.73 E.34103
G1 X136.998 Y110.736
G1 X129.328 Y118.406 E.33331
G1 X128.93 Y118.271
G1 X136.484 Y110.717 E.32824
G1 X135.976 Y110.692
G1 X128.489 Y118.179 E.32534
G1 X127.993 Y118.142
G1 X135.491 Y110.644 E.32581
G1 X135.012 Y110.589
G1 X127.402 Y118.199 E.33068
G1 X126.651 Y118.417
G1 X134.55 Y110.518 E.34324
; WIPE_START
M204 S10000
G1 X133.135 Y111.932 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X130.906 Y119.232 Z8.4 F36000
G1 X129.149 Y124.984 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X125.807 Y128.326 E.14522
G1 X125.223 Y128.377
G1 X128.455 Y125.145 E.14044
G1 X127.896 Y125.171
G1 X124.627 Y128.44 E.14203
G1 X124.019 Y128.514
G1 X127.412 Y125.122 E.14743
G1 X126.98 Y125.02
G1 X123.39 Y128.61 E.15601
G1 X122.751 Y128.716
G1 X126.591 Y124.876 E.1669
G1 X126.237 Y124.697
G1 X122.089 Y128.845 E.18027
G1 X121.405 Y128.996
G1 X125.915 Y124.485 E.196
G1 X125.623 Y124.244
G1 X120.703 Y129.164 E.21382
G1 X119.974 Y129.36
G1 X125.36 Y123.974 E.23404
G1 X125.126 Y123.674
G1 X119.211 Y129.59 E.25706
G1 X118.415 Y129.853
G1 X124.921 Y123.346 E.28274
G1 X124.749 Y122.985
G1 X117.58 Y130.154 E.31156
G1 X116.695 Y130.506
G1 X124.614 Y122.587 E.34411
G1 X124.522 Y122.146
G1 X115.748 Y130.92 E.38129
G1 X114.717 Y131.417
G1 X124.485 Y121.65 E.42445
G1 X124.541 Y121.06
G1 X113.573 Y132.028 E.47661
; WIPE_START
M204 S10000
G1 X114.988 Y130.614 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X112.25 Y132.818 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X124.76 Y120.308 E.54362
; WIPE_START
M204 S10000
G1 X123.346 Y121.722 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X128.611 Y116.196 Z8.4 F36000
G1 X134.099 Y110.436 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X110.563 Y133.971 E1.02274
; WIPE_START
M204 S10000
G1 X111.978 Y132.557 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X107.153 Y138.471 Z8.4 F36000
G1 X100.172 Y147.028 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X100.849 Y146.352 E.02939
G1 X101.263 Y145.405
G1 X99.803 Y146.865 E.06346
G1 X99.433 Y146.702
G1 X101.761 Y144.373 E.10118
; WIPE_START
M204 S10000
G1 X100.347 Y145.788 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X102.371 Y143.23 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X99.063 Y146.538 E.14375
G1 X98.693 Y146.375
G1 X103.161 Y141.907 E.19414
; WIPE_START
M204 S10000
G1 X101.747 Y143.321 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.314 Y140.22 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X98.323 Y146.211 E.26034
G1 X97.953 Y146.048
G1 X133.655 Y110.346 E1.55141
G1 X133.228 Y110.24
G1 X97.584 Y145.885 E1.54894
G1 X97.214 Y145.721
G1 X132.802 Y110.133 E1.54648
G1 X132.395 Y110.007
G1 X96.844 Y145.558 E1.54486
G1 X96.474 Y145.394
G1 X131.989 Y109.879 E1.54329
G1 X131.583 Y109.752
G1 X96.104 Y145.231 E1.54173
G1 X95.734 Y145.067
G1 X131.189 Y109.613 E1.54068
G1 X130.795 Y109.473
G1 X95.365 Y144.904 E1.53963
G1 X94.995 Y144.741
G1 X130.401 Y109.334 E1.53858
G1 X130.007 Y109.195
G1 X105.879 Y133.323 E1.04847
G1 X106.036 Y132.632
G1 X129.613 Y109.056 E1.02452
G1 X129.219 Y108.916
G1 X106.057 Y132.078 E1.00649
G1 X106.006 Y131.596
G1 X128.798 Y108.805 E.9904
G1 X128.355 Y108.714
G1 X105.903 Y131.166 E.97565
G1 X105.758 Y130.778
G1 X127.849 Y108.686 E.95998
G1 X127.215 Y108.788
G1 X105.577 Y130.425 E.94025
G1 X105.364 Y130.105
G1 X126.444 Y109.026 E.91599
G1 X125.612 Y109.324
G1 X105.122 Y129.814 E.89038
G1 X104.851 Y129.552
M73 P97 R0
G1 X124.78 Y109.623 E.86602
G1 X123.974 Y109.896
G1 X104.551 Y129.319 E.84401
G1 X104.221 Y129.115
G1 X123.207 Y110.129 E.82504
G1 X122.489 Y110.314
G1 X103.858 Y128.945 E.8096
G1 X103.459 Y128.811
G1 X121.818 Y110.452 E.7978
G1 X121.167 Y110.569
G1 X103.016 Y128.72 E.78875
G1 X102.516 Y128.687
G1 X120.565 Y110.638 E.78431
G1 X119.975 Y110.695
G1 X101.923 Y128.747 E.78445
G1 X101.162 Y128.975
G1 X119.414 Y110.723 E.79315
; WIPE_START
M204 S10000
G1 X118 Y112.137 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X114.013 Y118.645 Z8.4 F36000
G1 X103.666 Y135.536 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X94.625 Y144.577 E.39288
G1 X94.255 Y144.414
G1 X102.976 Y135.693 E.37895
G1 X102.421 Y135.714
G1 X93.885 Y144.25 E.37093
G1 X93.515 Y144.087
G1 X101.939 Y135.663 E.36606
G1 X101.509 Y135.56
G1 X93.146 Y143.923 E.36344
G1 X92.776 Y143.76
G1 X101.121 Y135.415 E.36264
G1 X100.769 Y135.234
G1 X92.406 Y143.597 E.3634
G1 X92.036 Y143.433
G1 X100.448 Y135.021 E.36554
G1 X100.157 Y134.779
G1 X91.666 Y143.27 E.36897
G1 X91.296 Y143.106
G1 X99.895 Y134.508 E.37365
G1 X99.662 Y134.207
G1 X90.927 Y142.943 E.37961
G1 X90.557 Y142.78
G1 X99.459 Y133.878 E.38683
G1 X99.288 Y133.515
G1 X90.187 Y142.616 E.39548
G1 X89.817 Y142.453
G1 X99.154 Y133.116 E.40573
G1 X99.063 Y132.673
G1 X89.447 Y142.289 E.41787
G1 X89.077 Y142.126
G1 X99.03 Y132.173 E.43249
G1 X99.089 Y131.581
G1 X88.708 Y141.962 E.45114
G1 X88.338 Y141.799
G1 X99.32 Y130.817 E.47721
; WIPE_START
M204 S10000
G1 X97.905 Y132.231 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X92.362 Y137.478 Z8.4 F36000
G1 X87.968 Y141.636 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X118.869 Y110.735 E1.34279
G1 X118.341 Y110.729
G1 X87.598 Y141.472 E1.33593
G1 X87.228 Y141.309
G1 X117.815 Y110.722 E1.32916
G1 X117.31 Y110.694
G1 X86.858 Y141.145 E1.32327
G1 X86.489 Y140.982
G1 X116.805 Y110.666 E1.31739
G1 X116.3 Y110.638
G1 X86.119 Y140.818 E1.3115
G1 X85.749 Y140.655
G1 X115.793 Y110.611 E1.30555
G1 X115.274 Y110.596
G1 X85.379 Y140.492 E1.29909
G1 X85.009 Y140.328
G1 X114.725 Y110.612 E1.2913
G1 X114.105 Y110.699
G1 X84.639 Y140.165 E1.28042
G1 X84.27 Y140.001
G1 X113.091 Y111.18 E1.25242
; WIPE_START
M204 S10000
G1 X111.677 Y112.594 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X111.162 Y112.575 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X83.9 Y139.838 E1.18469
G1 X83.53 Y139.675
G1 X109.543 Y113.661 E1.13041
; WIPE_START
M204 S10000
G1 X108.129 Y115.075 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X108.372 Y114.3 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X83.16 Y139.511 E1.09556
G1 X82.877 Y139.261
G1 X107.395 Y114.743 E1.06544
G1 X106.536 Y115.069
G1 X82.956 Y138.648 E1.02466
G1 X83.206 Y137.865
G1 X105.751 Y115.32 E.97971
G1 X105 Y115.538
G1 X86.544 Y133.994 E.80196
; WIPE_START
M204 S10000
G1 X87.959 Y132.579 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X87.781 Y132.224 Z8.4 F36000
M73 P98 R0
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X104.297 Y115.707 E.71774
G1 X103.597 Y115.875
G1 X88.422 Y131.05 E.65943
G1 X88.877 Y130.061
G1 X102.893 Y116.046 E.60904
G1 X102.158 Y116.247
G1 X98.394 Y120.011 E.16357
; WIPE_START
M204 S10000
G1 X99.808 Y118.597 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X95.981 Y122.424 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X89.215 Y129.19 E.29401
G1 X89.549 Y128.323
G1 X94.164 Y123.708 E.20054
; WIPE_START
M204 S10000
G1 X92.75 Y125.122 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X92.86 Y124.479 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X89.882 Y127.456 E.12938
; WIPE_START
M204 S10000
G1 X91.297 Y126.042 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X98.925 Y125.797 Z8.4 F36000
G1 X129.56 Y124.812 Z8.4
G1 Z8
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.0919248
G1 F15000
G3 X129.22 Y125.055 I-4.591 J-6.07 E.00167
; WIPE_START
G1 X129.56 Y124.812 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X127.658 Y125.142 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.089308
G1 F15000
G1 X127.49 Y125.2 E.00067
; WIPE_START
G1 X127.658 Y125.142 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X124.608 Y120.745 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.147663
G1 F15000
G1 X124.472 Y120.991 E.0024
; WIPE_START
G1 X124.608 Y120.745 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X125 Y119.829 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.110947
G1 F15000
G1 X124.895 Y119.969 E.00097
; LINE_WIDTH: 0.168213
G2 X124.695 Y120.242 I4.689 J3.638 E.00346
; WIPE_START
G1 X124.895 Y119.969 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X126.589 Y118.355 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.195357
G1 F15000
G1 X126.451 Y118.447 E.00206
; LINE_WIDTH: 0.156534
G1 X126.312 Y118.552 E.00161
; LINE_WIDTH: 0.110962
G1 X126.173 Y118.656 E.00097
; WIPE_START
G1 X126.312 Y118.552 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.397 Y122.876 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0918902
G1 F15000
G3 X131.155 Y123.217 I-5.818 J-3.881 E.00167
; WIPE_START
G1 X131.397 Y122.876 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X138.677 Y125.169 Z8.4 F36000
G1 X151.475 Y129.2 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.213736
G1 F15000
G1 X151.226 Y129.411 E.00455
; LINE_WIDTH: 0.183584
G1 X150.66 Y129.977 E.00918
; LINE_WIDTH: 0.214249
G1 X150.455 Y130.22 E.00444
; WIPE_START
G1 X150.66 Y129.977 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.44 Y128.754 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.147112
G1 F15000
G1 X152.283 Y128.853 E.00158
; LINE_WIDTH: 0.131385
G1 X152.212 Y128.9 E.00061
; LINE_WIDTH: 0.102577
G1 X152.141 Y128.948 E.00041
; WIPE_START
G1 X152.212 Y128.9 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X157.04 Y132.434 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0935852
G1 F15000
G3 X156.946 Y132.627 I-3.456 J-1.563 E.00089
; WIPE_START
G1 X157.04 Y132.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.643 Y133.874 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.208565
G1 F15000
G1 X156.56 Y133.985 E.00187
; LINE_WIDTH: 0.181811
G1 X156.472 Y134.101 E.00165
; LINE_WIDTH: 0.151294
G1 X156.345 Y134.251 E.00174
; LINE_WIDTH: 0.104886
G1 X156.04 Y134.591 E.0023
G1 X155.845 Y134.785 F36000
; LINE_WIDTH: 0.0948222
G1 F15000
G1 X155.656 Y134.964 E.0011
; LINE_WIDTH: 0.119103
G1 X155.501 Y135.094 E.00126
; LINE_WIDTH: 0.154522
G1 X155.34 Y135.229 E.00191
; LINE_WIDTH: 0.197246
G1 X155.129 Y135.388 E.00332
; WIPE_START
G1 X155.34 Y135.229 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.401 Y135.594 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0889829
G1 F15000
G1 X152.274 Y135.514 E.00056
; WIPE_START
G1 X152.401 Y135.594 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X144.846 Y134.506 Z8.4 F36000
G1 X116.633 Y130.443 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.190605
G1 F15000
G1 X116.514 Y130.524 E.00173
; LINE_WIDTH: 0.149633
G1 X116.395 Y130.604 E.00125
; LINE_WIDTH: 0.108661
G1 X116.276 Y130.684 E.00077
; WIPE_START
G1 X116.395 Y130.604 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X114.656 Y131.356 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.196513
G1 F15000
G1 X114.514 Y131.459 E.0022
; LINE_WIDTH: 0.153172
G1 X114.371 Y131.562 E.00158
; LINE_WIDTH: 0.109832
G1 X114.229 Y131.666 E.00096
G1 X113.512 Y131.967 F36000
; LINE_WIDTH: 0.207184
G1 F15000
G1 X113.393 Y132.057 E.002
; LINE_WIDTH: 0.177923
G1 X113.272 Y132.148 E.00167
; LINE_WIDTH: 0.144316
G1 X113.142 Y132.249 E.00136
; LINE_WIDTH: 0.10688
G1 X113.012 Y132.351 E.00086
G1 X112.19 Y132.757 F36000
; LINE_WIDTH: 0.205349
G1 F15000
G1 X111.985 Y132.922 E.00348
; LINE_WIDTH: 0.158474
G1 X111.781 Y133.088 E.00248
; LINE_WIDTH: 0.111599
G1 X111.577 Y133.253 E.00147
; WIPE_START
G1 X111.781 Y133.088 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X110.503 Y133.911 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.21878
G1 F15000
G1 X110.294 Y134.093 E.00397
; LINE_WIDTH: 0.1846
G1 X110.085 Y134.275 E.0032
; LINE_WIDTH: 0.150323
G1 X109.874 Y134.458 E.00244
; LINE_WIDTH: 0.110653
G1 X109.538 Y134.76 E.0025
; WIPE_START
G1 X109.874 Y134.458 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.92 Y133.548 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.108281
G1 F15000
G1 X105.866 Y133.31 E.0013
; WIPE_START
G1 X105.92 Y133.548 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.158 Y129.08 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0956677
G1 F15000
G1 X104.088 Y129.027 E.00038
G1 X104.034 Y129.036 E.00023
; WIPE_START
G1 X104.088 Y129.027 E-.2911
G1 X104.158 Y129.08 E-.4689
; WIPE_END
G1 E-.04 F1800
G1 X101.099 Y128.913 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.202699
G1 F15000
G1 X100.992 Y128.985 E.00169
; LINE_WIDTH: 0.175871
G1 X100.886 Y129.065 E.00144
; LINE_WIDTH: 0.140793
G1 X100.779 Y129.145 E.00106
; LINE_WIDTH: 0.105714
G1 X100.673 Y129.225 E.00068
; WIPE_START
G1 X100.779 Y129.145 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X99.568 Y130.33 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.105123
G1 F15000
G1 X99.49 Y130.433 E.00065
; LINE_WIDTH: 0.139028
G1 X99.413 Y130.536 E.00101
; LINE_WIDTH: 0.174026
G1 X99.331 Y130.645 E.00146
; LINE_WIDTH: 0.201598
G1 X99.257 Y130.755 E.00171
; WIPE_START
G1 X99.331 Y130.645 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X99.063 Y132.65 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.106042
G1 F15000
G3 X98.983 Y132.487 I2.854 J-1.506 E.00093
; WIPE_START
G1 X99.063 Y132.65 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X99.271 Y133.472 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.106745
G1 F15000
G1 X99.21 Y133.382 E.00057
G1 X99.226 Y133.31 E.00038
; WIPE_START
G1 X99.21 Y133.382 E-.30657
G1 X99.271 Y133.472 E-.45343
; WIPE_END
G1 E-.04 F1800
G1 X103.891 Y135.577 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.108352
G1 F15000
G1 X103.653 Y135.523 E.0013
; WIPE_START
G1 X103.891 Y135.577 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.104 Y139.195 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.110718
G1 F15000
G1 X104.8 Y139.532 E.00251
; LINE_WIDTH: 0.1504
G1 X104.618 Y139.741 E.00243
; LINE_WIDTH: 0.18459
G1 X104.436 Y139.951 E.0032
; LINE_WIDTH: 0.21878
G1 X104.254 Y140.16 E.00397
; WIPE_START
G1 X104.436 Y139.951 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X103.597 Y141.233 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.111611
G1 F15000
G1 X103.431 Y141.438 E.00147
; LINE_WIDTH: 0.158488
G1 X103.266 Y141.642 E.00248
; LINE_WIDTH: 0.205365
G1 X103.1 Y141.846 E.00348
G1 X102.694 Y142.669 F36000
; LINE_WIDTH: 0.1069
G1 F15000
G1 X102.593 Y142.799 E.00086
; LINE_WIDTH: 0.144603
G1 X102.49 Y142.93 E.00139
; LINE_WIDTH: 0.178175
G1 X102.4 Y143.05 E.00165
; LINE_WIDTH: 0.207203
G1 X102.31 Y143.169 E.002
G1 X102.009 Y143.886 F36000
; LINE_WIDTH: 0.10983
G1 F15000
G1 X101.906 Y144.028 E.00096
; LINE_WIDTH: 0.15315
G1 X101.803 Y144.17 E.00158
; LINE_WIDTH: 0.19647
G1 X101.7 Y144.312 E.00219
G1 X101.473 Y144.955 F36000
; LINE_WIDTH: 0.109252
G1 F15000
G1 X101.382 Y145.084 E.00085
; LINE_WIDTH: 0.151405
G1 X101.292 Y145.213 E.0014
; LINE_WIDTH: 0.193558
G1 X101.201 Y145.343 E.00194
; WIPE_START
G1 X101.292 Y145.213 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X95.215 Y140.596 Z8.4 F36000
G1 X86.605 Y134.054 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.233705
G1 F15000
G1 X86.49 Y134.182 E.00268
; LINE_WIDTH: 0.207411
G1 X86.063 Y134.64 E.00839
; LINE_WIDTH: 0.16371
G1 X85.635 Y135.099 E.00618
; LINE_WIDTH: 0.128444
G1 X85.036 Y135.718 E.006
; LINE_WIDTH: 0.101598
G1 X84.436 Y136.337 E.00412
; WIPE_START
G1 X85.036 Y135.718 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X87.842 Y132.285 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.206514
G1 F15000
G1 X87.695 Y132.474 E.00319
; LINE_WIDTH: 0.163076
G1 X87.533 Y132.673 E.00251
; LINE_WIDTH: 0.113134
G1 X87.371 Y132.871 E.00147
; WIPE_START
G1 X87.533 Y132.673 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X88.483 Y131.111 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.197366
G1 F15000
G1 X88.376 Y131.257 E.00228
; LINE_WIDTH: 0.153693
G1 X88.268 Y131.404 E.00164
; LINE_WIDTH: 0.11002
G1 X88.161 Y131.55 E.00099
; WIPE_START
G1 X88.268 Y131.404 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X92.16 Y124.884 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.108264
G1 F15000
G1 X92.029 Y124.984 E.00088
; LINE_WIDTH: 0.148441
G1 X91.898 Y125.085 E.00142
; LINE_WIDTH: 0.191624
G1 X91.731 Y125.219 E.0026
; LINE_WIDTH: 0.237812
G1 X91.564 Y125.354 E.0034
; LINE_WIDTH: 0.283999
G1 X91.397 Y125.488 E.00421
; LINE_WIDTH: 0.324696
G1 X91.191 Y125.669 E.00629
; LINE_WIDTH: 0.367525
G2 X90.682 Y126.16 I2.975 J3.592 E.01875
; LINE_WIDTH: 0.34854
G1 X90.561 Y126.308 E.00477
; LINE_WIDTH: 0.311135
G1 X90.439 Y126.456 E.00418
; LINE_WIDTH: 0.267969
G1 X90.351 Y126.579 E.00277
; LINE_WIDTH: 0.219046
G1 X90.263 Y126.701 E.00217
; LINE_WIDTH: 0.170123
G1 X90.175 Y126.824 E.00156
; LINE_WIDTH: 0.121201
G1 X90.087 Y126.947 E.00096
; LINE_WIDTH: 0.0924617
G1 X90.064 Y126.983 E.00017
; WIPE_START
G1 X90.087 Y126.947 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X93.422 Y124.155 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.11073
G1 F15000
G1 X93.255 Y124.283 E.00116
; LINE_WIDTH: 0.15584
G1 X93.088 Y124.411 E.00194
; LINE_WIDTH: 0.20095
G1 X92.921 Y124.54 E.00271
; WIPE_START
G1 X93.088 Y124.411 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X94.825 Y123.285 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.104716
G1 F15000
G1 X94.684 Y123.401 E.00092
; LINE_WIDTH: 0.137987
G1 X94.541 Y123.518 E.00143
; LINE_WIDTH: 0.172737
G1 X94.383 Y123.643 E.00214
; LINE_WIDTH: 0.208641
G1 X94.225 Y123.769 E.00273
; WIPE_START
G1 X94.383 Y123.643 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X98.454 Y120.071 Z8.4 F36000
M73 P99 R0
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.226429
G1 F15000
G1 X98.208 Y120.341 E.00547
; LINE_WIDTH: 0.197468
G1 X97.958 Y120.614 E.00466
; LINE_WIDTH: 0.169452
G1 X97.243 Y121.351 E.01059
G1 X96.475 Y122.092 E.011
; LINE_WIDTH: 0.214749
G1 X96.041 Y122.484 E.00818
; WIPE_START
G1 X96.475 Y122.092 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X101.638 Y116.471 Z8.4 F36000
G1 X101.705 Y116.398 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.151609
G1 F15000
G1 X101.546 Y116.516 E.00176
; LINE_WIDTH: 0.196679
G1 X101.387 Y116.635 E.00248
; LINE_WIDTH: 0.241749
G1 X101.228 Y116.754 E.00321
; LINE_WIDTH: 0.292917
G2 X100.464 Y117.504 I4.904 J5.761 E.02183
; LINE_WIDTH: 0.263875
G1 X100.23 Y117.766 E.00633
; LINE_WIDTH: 0.222973
G1 X99.996 Y118.029 E.00516
; LINE_WIDTH: 0.183446
G1 X99.812 Y118.241 E.00322
; LINE_WIDTH: 0.145336
G1 X99.628 Y118.453 E.00235
; LINE_WIDTH: 0.107227
G1 X99.443 Y118.665 E.00147
; WIPE_START
G1 X99.628 Y118.453 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X106.52 Y115.176 Z8.4 F36000
G1 X107.821 Y114.557 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.108803
G1 F15000
G1 X107.7 Y114.64 E.00079
; LINE_WIDTH: 0.150059
G1 X107.578 Y114.722 E.00128
; LINE_WIDTH: 0.191315
G1 X107.457 Y114.805 E.00177
; WIPE_START
G1 X107.578 Y114.722 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X108.867 Y114.044 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.109933
G1 F15000
G1 X108.722 Y114.15 E.00098
; LINE_WIDTH: 0.153476
G1 X108.578 Y114.255 E.00161
; LINE_WIDTH: 0.197018
G1 X108.433 Y114.361 E.00225
; WIPE_START
G1 X108.578 Y114.255 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X110.179 Y113.263 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.109493
G1 F15000
G1 X110.02 Y113.391 E.00111
; LINE_WIDTH: 0.152158
G1 X109.861 Y113.519 E.00182
; LINE_WIDTH: 0.195165
G1 X109.699 Y113.649 E.00257
; LINE_WIDTH: 0.220547
G1 X109.604 Y113.722 E.00174
; WIPE_START
G1 X109.699 Y113.649 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X112.056 Y111.919 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.112618
G1 F15000
G1 X111.778 Y112.158 E.00208
; LINE_WIDTH: 0.161505
G1 X111.5 Y112.397 E.00354
; LINE_WIDTH: 0.210391
G1 X111.223 Y112.636 E.005
; WIPE_START
G1 X111.5 Y112.397 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X113.648 Y110.862 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.110844
G1 F15000
G1 X113.515 Y110.962 E.00092
; LINE_WIDTH: 0.15618
G1 X113.381 Y111.062 E.00154
; LINE_WIDTH: 0.201517
G1 X113.248 Y111.162 E.00216
; LINE_WIDTH: 0.227169
G1 X113.151 Y111.241 E.00187
; WIPE_START
G1 X113.248 Y111.162 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X118.008 Y110.795 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0936612
G1 F15000
G1 X117.796 Y110.703 E.00096
; WIPE_START
G1 X118.008 Y110.795 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X125.597 Y109.979 Z8.4 F36000
G1 X130.556 Y109.446 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.100838
G1 F15000
G2 X130.438 Y109.346 I-.28 J.21 E.00074
; WIPE_START
G1 X130.556 Y109.446 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X138.138 Y110.32 Z8.4 F36000
G1 X142.031 Y110.769 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0998633
G1 F15000
G1 X141.873 Y110.686 E.00083
; WIPE_START
G1 X142.031 Y110.769 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X148.172 Y115.302 Z8.4 F36000
G1 X166.696 Y128.975 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.098001
G1 F15000
G1 X166.613 Y128.848 E.00068
; WIPE_START
G1 X166.696 Y128.975 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X170.672 Y135.49 Z8.4 F36000
G1 X172.999 Y139.303 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.349468
G1 F15000
G1 X172.981 Y139.293 E.00053
; LINE_WIDTH: 0.383643
G1 X172.963 Y139.282 E.00059
; LINE_WIDTH: 0.378414
G1 X172.86 Y139.353 E.00341
; LINE_WIDTH: 0.33376
G1 X172.757 Y139.424 E.00296
; LINE_WIDTH: 0.289105
G1 X172.654 Y139.494 E.0025
; LINE_WIDTH: 0.244451
G1 X172.551 Y139.565 E.00205
; LINE_WIDTH: 0.199797
G1 X172.448 Y139.635 E.0016
; LINE_WIDTH: 0.155143
G1 X172.345 Y139.706 E.00114
; LINE_WIDTH: 0.110489
G1 X172.242 Y139.776 E.00069
; WIPE_START
G1 X172.345 Y139.706 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X170.7 Y140.368 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.191867
G1 F15000
G1 X170.577 Y140.452 E.00181
; LINE_WIDTH: 0.150385
G1 X170.454 Y140.537 E.00131
; LINE_WIDTH: 0.108903
G1 X170.33 Y140.621 E.0008
; WIPE_START
G1 X170.454 Y140.537 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X168.789 Y141.213 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.191849
G1 F15000
G1 X168.665 Y141.297 E.00181
; LINE_WIDTH: 0.150374
G1 X168.542 Y141.381 E.00131
; LINE_WIDTH: 0.108899
G1 X168.419 Y141.466 E.0008
; WIPE_START
G1 X168.542 Y141.381 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X166.877 Y142.057 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.191859
G1 F15000
G1 X166.754 Y142.142 E.00181
; LINE_WIDTH: 0.15038
G1 X166.631 Y142.226 E.00131
; LINE_WIDTH: 0.108901
G1 X166.508 Y142.31 E.0008
; WIPE_START
G1 X166.631 Y142.226 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X164.966 Y142.902 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.191868
G1 F15000
G1 X164.843 Y142.986 E.00181
; LINE_WIDTH: 0.150385
G1 X164.72 Y143.071 E.00131
; LINE_WIDTH: 0.108902
G1 X164.597 Y143.155 E.0008
; WIPE_START
G1 X164.72 Y143.071 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X163.055 Y143.747 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.191854
G1 F15000
G1 X162.932 Y143.831 E.00181
; LINE_WIDTH: 0.150377
G1 X162.809 Y143.915 E.00131
; LINE_WIDTH: 0.1089
G1 X162.686 Y144 E.0008
; WIPE_START
G1 X162.809 Y143.915 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.144 Y144.591 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.191867
G1 F15000
G1 X161.021 Y144.676 E.00181
; LINE_WIDTH: 0.150385
G1 X160.898 Y144.76 E.00131
; LINE_WIDTH: 0.108903
G1 X160.774 Y144.844 E.0008
; WIPE_START
G1 X160.898 Y144.76 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X159.233 Y145.436 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.191854
G1 F15000
G1 X159.109 Y145.52 E.00181
; LINE_WIDTH: 0.150377
G1 X158.986 Y145.605 E.00131
; LINE_WIDTH: 0.1089
G1 X158.863 Y145.689 E.0008
; WIPE_START
G1 X158.986 Y145.605 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X157.321 Y146.281 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.191849
G1 F15000
G1 X157.198 Y146.365 E.00181
; LINE_WIDTH: 0.150374
G1 X157.075 Y146.449 E.00131
; LINE_WIDTH: 0.108899
G1 X156.952 Y146.534 E.0008
; close powerlost recovery
M1003 S0
; WIPE_START
G1 F15000
G1 X157.075 Y146.449 E-.76
; WIPE_END
G1 E-.04 F1800
M106 S0
M106 P2 S0
M981 S0 P20000 ; close spaghetti detector
; FEATURE: Custom
; MACHINE_END_GCODE_START
; filament end gcode 

;======== P2S end gcode ==========
;===== 2025/11/12 =====
M400 ; wait for buffer to clear
G92 E0 ; zero the extruder
G1 E-0.8 F1800 ; retract
G0 Z8.8 F900

; pull back filament to AMS
M620 S65535
T65535
G150.2
M621 S65535

G150.3

M400 ; wait all motion done

M1002 judge_flag timelapse_record_flag
M622 J1
    M991 S0 P-1 ;end smooth timelapse at safe pos
    M400 S5 ;wait for last picture to be taken
M623  ;end of "timelapse_record_flag"

M106 S0 ; turn off fan
M106 P2 S0 ; turn off remote part cooling fan
M106 P3 S0 ; turn off chamber cooling fan
M106 P10 S0 ; turn off left aux fan

M400 ; wait all motion done
M17 S
M17 Z0.4 ; lower z motor current to reduce impact if there is something in the bottom

    
        G1 Z84 F600
        G1 Z82
    

M400 P100
M17 R ; restore z current


M220 S100  ; Reset feedrate magnitude
M201.2 K1.0 ; Reset acc magnitude
M73.2 R1.0 ;Reset left time magnitude
M1002 set_gcode_claim_speed_level : 0

M1015.3 S0 ;disable clog detect
M1015.4 S0 K0 ;disable air printing detect

;=====printer finish air purification=========
M622.1 S0
M1002 judge_flag print_finish_air_filt_flag

M622 J1
M1002 gcode_claim_action : 66
M145 P1
M106 P2 S255
M400 S180
M106 P2 S0
M623

M622 J2
M1002 gcode_claim_action : 66
M145 P0
M106 P3 S255
M400 S180
M106 P3 S0
M623
;=====printer finish air purification=========

;=====printer finish  sound=========
M17
M400 S1
M1006 S1
M1006 A53 B10 L50 C53 D10 M50 E53 F10 N50 
M1006 A57 B10 L50 C57 D10 M50 E57 F10 N50 
M1006 A0 B15 L0 C0 D15 M0 E0 F15 N0 
M1006 A53 B10 L50 C53 D10 M50 E53 F10 N50 
M1006 A57 B10 L50 C57 D10 M50 E57 F10 N50 
M1006 A0 B15 L0 C0 D15 M0 E0 F15 N0 
M1006 A48 B10 L50 C48 D10 M50 E48 F10 N50 
M1006 A0 B15 L0 C0 D15 M0 E0 F15 N0 
M1006 A60 B10 L50 C60 D10 M50 E60 F10 N50 
M1006 W
;=====printer finish  sound=========
M400
M18

M104 S0 ; turn off hotend
M140 S0 ; turn off bed
M73 P100 R0
; EXECUTABLE_BLOCK_END

