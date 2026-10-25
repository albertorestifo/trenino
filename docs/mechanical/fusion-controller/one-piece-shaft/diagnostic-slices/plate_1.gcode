; HEADER_BLOCK_START
; BambuStudio 02.04.00.70
; model printing time: 10m 49s; total estimated time: 18m 45s
; total layer number: 40
; total filament length [mm] : 2164.61
; total filament volume [cm^3] : 5206.49
; total filament weight [g] : 6.56
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
M73 P0 R18
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
M73 P7 R17
  G1 Z5 F1200
  G90
  M400
  G150.1
;===== wipe left nozzle end =====


;===== mech mode sweep start =====
  M1002 gcode_claim_action : 3
  G90
M73 P8 R17
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
    
      G29 A1 X86.6007 Y110.939 I82.7934 J34.1215
    
    M400
    M500 ; save cali data
  M623
    
  M622 J2
    M1002 gcode_claim_action : 1
    
      G29 A2 X86.6007 Y110.939 I82.7934 J34.1215
    
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
M73 P42 R10
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
G1 X126.944 Y121.224
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.5
G1 F3000
M204 S500
G1 X127.262 Y121.105 E.01265
G3 X127.619 Y121.028 I.718 J2.453 E.0136
G1 X127.977 Y121.002 E.01339
G3 X126.889 Y121.247 I.003 J2.556 E.55625
M204 S6000
G1 X127.187 Y121.621 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X127.391 Y121.545 E.00813
G3 X127.684 Y121.481 I.589 J2.014 E.01117
G1 X127.978 Y121.46 E.01097
G3 X127.111 Y121.649 I.003 J2.098 E.45772
G1 X127.131 Y121.642 E.00079
; WIPE_START
G1 X127.391 Y121.545 E-.10578
G1 X127.684 Y121.481 E-.11385
G1 X127.978 Y121.46 E-.11196
G1 X128.282 Y121.481 E-.11577
G1 X128.575 Y121.545 E-.11411
G1 X128.856 Y121.65 E-.11389
G1 X129.052 Y121.756 E-.08464
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X122.208 Y125.135 Z.6 F36000
G1 X100.611 Y135.799 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X100.596 Y135.779 E.00094
G3 X102.163 Y131.572 I1.929 J-1.677 E.20417
G1 X102.522 Y131.546 E.01338
G3 X100.854 Y136.036 I.003 J2.556 E.36699
G1 X100.654 Y135.841 E.01041
M204 S6000
G1 X100.913 Y135.445 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X100.762 Y135.24 E.00952
G3 X102.228 Y132.025 I1.763 J-1.137 E.15646
G1 X102.522 Y132.004 E.01097
G3 X100.952 Y135.491 I.003 J2.098 E.31184
; WIPE_START
G1 X100.762 Y135.24 E-.11983
G1 X100.616 Y134.978 E-.11388
G1 X100.512 Y134.697 E-.11392
G1 X100.448 Y134.404 E-.11383
G1 X100.427 Y134.105 E-.11399
G1 X100.448 Y133.806 E-.11396
G1 X100.487 Y133.624 E-.07059
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X108.115 Y133.354 Z.6 F36000
G1 X152.354 Y131.789 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X152.376 Y131.776 E.00095
G3 X153.075 Y131.572 I1.06 J2.326 E.02722
G1 X153.433 Y131.546 E.01339
G3 X152.055 Y131.951 I.003 J2.556 E.54391
G1 X152.301 Y131.818 E.01043
M204 S6000
G1 X152.647 Y132.164 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X152.847 Y132.089 E.00794
G3 X153.14 Y132.025 I.589 J2.014 E.01117
G1 X153.434 Y132.004 E.01097
G3 X152.566 Y132.193 I.002 J2.098 E.45771
G1 X152.591 Y132.184 E.00099
; WIPE_START
G1 X152.847 Y132.089 E-.10385
G1 X153.14 Y132.025 E-.11389
G1 X153.434 Y132.004 E-.11196
G1 X153.738 Y132.025 E-.11577
G1 X154.031 Y132.089 E-.11411
G1 X154.312 Y132.194 E-.11388
G1 X154.512 Y132.303 E-.08653
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X153.764 Y139.899 Z.6 F36000
G1 X153.374 Y143.87 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X153.024 Y143.299 E.02493
G2 X102.603 Y143.854 I-25.035 J16.257 E2.23663
G1 X87.593 Y133.862 E.67161
G3 X87.956 Y132.814 I4.055 J.819 E.04145
G3 X88.568 Y132.251 I2.984 J2.632 E.03101
G2 X91.33 Y129.864 I-14.664 J-19.754 E.13611
G2 X93.818 Y126.281 I-11.461 J-10.616 E.16298
G3 X94.62 Y124.866 I12.384 J6.083 E.06063
G3 X95.133 Y124.511 I1.061 J.982 E.02341
G2 X97.652 Y123.24 I-21.44 J-45.637 E.10509
G2 X101.184 Y120.507 I-8.733 J-14.932 E.16682
G3 X102.898 Y118.901 I16.163 J15.544 E.08753
G3 X104.062 Y118.307 I2.589 J3.635 E.04885
G2 X107.139 Y117.235 I-16.573 J-52.527 E.12135
G2 X110.501 Y115.491 I-7.853 J-19.246 E.14128
G3 X112.298 Y114.433 I10.865 J16.416 E.0777
G3 X113.904 Y114.066 I1.928 J4.731 E.06163
G2 X117.452 Y113.605 I-2.369 J-32.131 E.13334
G2 X120.493 Y112.668 I-3.518 J-16.832 E.1187
G3 X122.518 Y111.852 I9.449 J20.511 E.08136
G3 X123.394 Y111.847 I.448 J1.806 E.03294
G2 X125.777 Y112.257 I36.947 J-207.408 E.09005
G2 X130.82 Y112.159 I2.222 J-15.418 E.18869
G3 X132.903 Y111.805 I5.299 J24.877 E.07873
G3 X133.127 Y111.798 I.17 J1.834 E.00835
G3 X134.128 Y112.103 I-.476 J3.36 E.03914
G2 X137.442 Y113.35 I11.212 J-24.768 E.13198
G2 X140.674 Y113.927 I5.217 J-19.86 E.12241
G3 X143.011 Y114.21 I-1.502 J22.205 E.08772
G3 X144.511 Y114.897 I-1.384 J5.001 E.06172
G2 X147.908 Y116.835 I17.492 J-26.716 E.14573
G2 X151.574 Y118.19 I12.822 J-29.054 E.1457
G3 X153.138 Y118.956 I-1.383 J4.802 E.0652
G3 X154.592 Y120.321 I-13.625 J15.97 E.07426
G2 X158.77 Y123.566 I14.84 J-14.796 E.19758
G3 X160.689 Y124.749 I-11.43 J20.684 E.084
G3 X161.64 Y125.777 I-2.58 J3.342 E.05243
G2 X163.476 Y128.477 I50.044 J-32.051 E.12163
G2 X166.027 Y131.267 I17.045 J-13.022 E.14097
G3 X167.513 Y132.73 I-14.81 J16.539 E.07769
G3 X168.283 Y134.184 I-3.891 J2.992 E.06159
G1 X168.346 Y134.351 E.00664
G1 X153.424 Y143.838 E.6586
M204 S6000
G1 X153.227 Y144.505 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G2 X102.745 Y144.498 I-25.243 J15.06 E2.26134
G1 X87.064 Y134.059 E.70163
G3 X87.531 Y132.63 I7.974 J1.818 E.05607
G3 X88.281 Y131.895 I2.856 J2.166 E.03926
G2 X90.998 Y129.55 I-14.425 J-19.452 E.1338
G2 X93.416 Y126.064 I-11.133 J-10.306 E.15852
M73 P43 R10
G3 X94.262 Y124.582 I12.349 J6.062 E.06359
G3 X94.918 Y124.107 I1.401 J1.245 E.03042
G2 X97.425 Y122.843 I-21.509 J-45.783 E.10459
G2 X100.867 Y120.177 I-8.508 J-14.538 E.16261
G3 X102.625 Y118.535 I16.248 J15.631 E.08966
G3 X103.908 Y117.877 I2.877 J4.03 E.0539
G2 X106.392 Y117.034 I-152.688 J-454.26 E.0977
G2 X110.26 Y115.102 I-7.152 J-19.156 E.16135
G3 X112.108 Y114.017 I11.044 J16.703 E.07983
G3 X113.854 Y113.611 I2.119 J5.153 E.06705
G2 X117.361 Y113.157 I-2.325 J-31.701 E.13178
G2 X120.321 Y112.245 I-3.419 J-16.357 E.11554
G3 X122.399 Y111.41 I9.383 J20.358 E.08342
G3 X123.459 Y111.394 I.565 J2.232 E.03987
G2 X125.842 Y111.805 I38.898 J-218.72 E.09004
G2 X130.743 Y111.708 I2.157 J-14.964 E.1834
G3 X132.866 Y111.349 I5.317 J24.978 E.08023
G3 X133.149 Y111.341 I.209 J2.313 E.01054
G3 X134.301 Y111.68 I-.486 J3.78 E.04492
G2 X137.565 Y112.909 I11.072 J-24.438 E.12997
G2 X140.723 Y113.473 I5.092 J-19.404 E.11962
G3 X143.114 Y113.765 I-1.523 J22.421 E.08975
G3 X144.747 Y114.506 I-1.478 J5.426 E.0671
G2 X148.101 Y116.421 I17.305 J-26.414 E.14392
G2 X151.722 Y117.758 I12.661 J-28.723 E.14388
G3 X153.422 Y118.598 I-1.522 J5.219 E.07097
G3 X154.909 Y119.992 I-13.849 J16.265 E.07598
G2 X159.006 Y123.175 I14.522 J-14.467 E.19375
G3 X161.132 Y124.515 I-9.808 J17.911 E.09363
G3 X162.325 Y125.975 I-4.131 J4.595 E.07052
G2 X164.66 Y129.213 I22.091 J-13.464 E.14883
G2 X167.021 Y131.571 I20.461 J-18.133 E.12438
G3 X168.248 Y132.994 I-3.966 J4.659 E.07026
G3 X168.905 Y134.537 I-9.747 J5.061 E.06253
G1 X153.277 Y144.473 E.68975
; WIPE_START
G1 X152.64 Y143.548 E-.42662
G1 X152.144 Y142.825 E-.33339
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X156.008 Y136.244 Z.6 F36000
G1 X161.809 Y126.365 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Bottom surface
; LINE_WIDTH: 0.50188
G1 F6300
M204 S500
G1 X160.745 Y125.301 E.05627
G2 X160.281 Y124.936 I-2.381 J2.553 E.02211
G1 X158.868 Y124.073 E.0619
G1 X162.377 Y127.581 E.18555
G2 X164.926 Y130.741 I16.812 J-10.957 E.15211
G1 X166.821 Y132.553 E.09803
G3 X167.443 Y133.297 I-4.932 J4.756 E.03632
G1 X157.074 Y122.928 E.54842
G3 X155.167 Y121.398 I11.21 J-15.933 E.09151
G1 X153.159 Y119.482 E.1038
G2 X152.489 Y118.992 I-2.536 J2.763 E.03113
G1 X167.76 Y134.263 E.80771
G1 X167.363 Y134.515 E.01759
G1 X151.395 Y118.547 E.84457
G1 X150.411 Y118.212 E.03889
G1 X166.967 Y134.768 E.87564
G1 X166.57 Y135.02 E.01758
G1 X149.427 Y117.877 E.90671
G3 X148.365 Y117.464 I17.004 J-45.297 E.04262
G1 X166.173 Y135.272 E.9419
G1 X165.776 Y135.524 E.01759
G1 X147.149 Y116.897 E.98521
G3 X145.654 Y116.051 I12.934 J-24.606 E.06423
G1 X165.379 Y135.777 E1.04328
G1 X164.983 Y136.029 E.01758
G1 X144.012 Y115.058 E1.10917
G2 X142.888 Y114.583 I-1.958 J3.067 E.04585
G1 X164.586 Y136.281 E1.14763
G1 X164.189 Y136.533 E.01759
G1 X142.122 Y114.466 E1.16714
G1 X141.396 Y114.389 E.0273
G1 X163.792 Y136.786 E1.18455
G1 X163.395 Y137.038 E.01758
G1 X140.67 Y114.313 E1.20197
G3 X139.939 Y114.231 I.691 J-9.465 E.02752
G1 X162.999 Y137.29 E1.21964
G1 X162.602 Y137.543 E.01759
G1 X139.18 Y114.12 E1.23882
G3 X138.384 Y113.974 I5.576 J-32.514 E.03026
G1 X162.205 Y137.795 E1.25992
G1 X161.808 Y138.047 E.01758
M73 P44 R10
G1 X137.534 Y113.773 E1.28386
G3 X136.612 Y113.5 I2.422 J-9.859 E.03601
G1 X154.458 Y131.346 E.94389
G3 X156.199 Y133.087 I-1.018 J2.759 E.09501
G1 X161.411 Y138.299 E.27571
G1 X161.015 Y138.552 E.01759
G1 X156.374 Y133.911 E.24544
G3 X156.355 Y134.541 I-3.991 J.19 E.02358
G1 X160.618 Y138.804 E.22549
G1 X160.221 Y139.056 E.01758
G1 X156.223 Y135.058 E.21146
G3 X156.024 Y135.508 I-1.667 J-.467 E.01847
G1 X159.824 Y139.308 E.20099
G1 X159.427 Y139.561 E.01759
G1 X155.768 Y135.902 E.19353
G3 X155.461 Y136.243 I-1.34 J-.898 E.01725
G1 X159.031 Y139.813 E.18882
G1 X158.634 Y140.065 E.01759
G1 X155.102 Y136.534 E.18678
G3 X154.692 Y136.772 I-1.035 J-1.311 E.01782
G1 X158.237 Y140.318 E.18752
G1 X157.84 Y140.57 E.01759
G1 X154.216 Y136.946 E.19167
G3 X153.659 Y137.038 I-.598 J-1.89 E.02119
G1 X157.443 Y140.822 E.20015
G1 X157.047 Y141.074 E.01759
G1 X152.72 Y136.748 E.22882
; WIPE_START
G1 X154.135 Y138.162 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X153.86 Y131.397 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X135.593 Y113.13 E.96616
G3 X134.497 Y112.683 I6.773 J-18.175 E.04428
G1 X153.004 Y131.19 E.97884
G2 X152.486 Y131.321 I.199 J1.864 E.02004
G1 X133.421 Y112.257 E1.00835
G2 X132.736 Y112.22 I-.41 J1.258 E.02597
G1 X152.036 Y131.52 E1.02079
G2 X151.643 Y131.776 I.692 J1.494 E.01761
G1 X132.177 Y112.31 E1.02956
G1 X131.626 Y112.409 E.02091
G1 X151.301 Y132.083 E1.04061
G2 X151.011 Y132.442 I1.077 J1.169 E.01732
G1 X131.076 Y112.508 E1.05436
G3 X130.516 Y112.596 I-1.677 J-8.785 E.02122
G1 X150.772 Y132.852 E1.07137
G1 X150.598 Y133.328 E.01893
G1 X129.95 Y112.679 E1.09211
G3 X129.356 Y112.735 I-.768 J-5.026 E.02231
G1 X150.506 Y133.885 E1.11864
G2 X150.527 Y134.555 I3.672 J.221 E.0251
G1 X128.759 Y112.786 E1.15135
G1 X128.126 Y112.803 E.02367
G1 X156.65 Y141.327 E1.50865
G1 X156.253 Y141.579 E.01759
G1 X127.467 Y112.793 E1.52251
G3 X126.774 Y112.749 I.012 J-5.681 E.02599
G1 X155.856 Y141.831 E1.53817
G1 X155.46 Y142.083 E.01759
G1 X126.062 Y112.686 E1.55485
G1 X125.301 Y112.574 E.02875
M73 P45 R10
G1 X155.063 Y142.336 E1.5741
G1 X154.666 Y142.588 E.01759
G1 X124.52 Y112.442 E1.59445
G1 X123.73 Y112.301 E.03
G1 X154.269 Y142.84 E1.61524
G1 X153.872 Y143.093 E.01759
G1 X152.092 Y141.312 E.09416
G1 X151.489 Y140.526 E.03705
G2 X146.232 Y135.452 I-23.976 J19.579 E.2739
G1 X122.975 Y112.195 E1.23006
G2 X122.427 Y112.297 I-.064 J1.189 E.02103
G1 X144.117 Y133.986 E1.14717
G2 X142.542 Y133.061 I-9.619 J14.564 E.06833
G1 X121.959 Y112.477 E1.08868
G1 X121.501 Y112.668 E.01856
G1 X141.197 Y132.364 E1.04173
G2 X139.993 Y131.809 I-5.964 J11.353 E.04961
G1 X130.753 Y122.569 E.48871
G2 X128.975 Y120.791 I-2.771 J.993 E.09716
G1 X121.043 Y112.86 E.41951
G3 X120.584 Y113.05 I-3.226 J-7.152 E.01859
G1 X128.159 Y120.625 E.40067
G2 X127.534 Y120.648 I-.173 J3.729 E.02344
G1 X120.114 Y113.229 E.39244
G3 X119.642 Y113.405 I-2.126 J-4.96 E.01887
G1 X127.018 Y120.782 E.39013
G2 X126.569 Y120.982 I.472 J1.662 E.01844
G1 X119.153 Y113.566 E.39223
G3 X118.651 Y113.713 I-1.796 J-5.208 E.01957
G1 X126.177 Y121.239 E.39806
G2 X125.837 Y121.548 I.904 J1.338 E.01724
G1 X118.138 Y113.849 E.4072
G1 X117.608 Y113.968 E.02032
G1 X125.547 Y121.907 E.41991
G1 X125.31 Y122.319 E.01778
G1 X117.063 Y114.072 E.4362
G3 X116.503 Y114.162 I-1.431 J-7.153 E.0212
G1 X125.139 Y122.797 E.45676
G2 X125.049 Y123.356 I1.9 J.593 E.02125
G1 X115.937 Y114.244 E.48197
G3 X115.351 Y114.307 I-1.126 J-7.683 E.02204
G1 X125.345 Y124.301 E.52859
; WIPE_START
G1 X123.931 Y122.887 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X130.696 Y123.162 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X138.883 Y131.349 E.43302
G1 X137.873 Y130.987 E.04014
G1 X130.896 Y124.01 E.36902
G3 X130.763 Y124.526 I-1.861 J-.205 E.01999
G1 X136.906 Y130.669 E.32492
G1 X135.983 Y130.396 E.03597
G1 X130.562 Y124.975 E.28673
G3 X130.305 Y125.367 I-1.492 J-.698 E.01759
G1 X135.117 Y130.178 E.25448
G1 X134.808 Y130.104 E.01187
G2 X134.264 Y129.975 I-1.518 J5.185 E.02091
G1 X129.996 Y125.707 E.22574
G3 X129.637 Y125.997 I-1.186 J-1.104 E.01732
M73 P46 R10
G1 X133.467 Y129.827 E.20258
G2 X132.673 Y129.682 I-1.77 J7.425 E.03022
G1 X129.225 Y126.234 E.18234
G1 X128.747 Y126.405 E.01899
G1 X131.925 Y129.583 E.16811
G1 X131.178 Y129.485 E.0282
G1 X128.188 Y126.495 E.15814
G3 X127.512 Y126.468 I-.204 J-3.412 E.02533
G1 X130.471 Y129.427 E.15651
G1 X129.767 Y129.372 E.02643
G1 X114.764 Y114.37 E.79349
G1 X114.178 Y114.432 E.02206
G1 X129.089 Y129.344 E.78869
G1 X128.423 Y129.326 E.02494
G1 X113.592 Y114.496 E.78439
G1 X113.039 Y114.591 E.02101
G1 X127.768 Y129.32 E.77903
G1 X127.135 Y129.337 E.02366
G1 X112.55 Y114.751 E.77145
G2 X112.114 Y114.964 I.924 J2.44 E.01817
G1 X126.503 Y129.353 E.76105
G2 X125.896 Y129.396 I.101 J5.805 E.02275
G1 X111.707 Y115.207 E.75047
G1 X111.303 Y115.452 E.01768
G1 X125.294 Y129.443 E.74003
G2 X124.699 Y129.497 I.212 J5.719 E.02238
G1 X110.899 Y115.696 E.72991
G1 X110.494 Y115.941 E.01768
G1 X124.125 Y129.572 E.72095
G1 X123.552 Y129.648 E.02164
G1 X110.09 Y116.186 E.712
G3 X109.685 Y116.43 I-2.695 J-4.016 E.01769
G1 X122.991 Y129.736 E.70374
G1 X122.443 Y129.837 E.02083
G1 X109.263 Y116.658 E.69707
G1 X108.842 Y116.885 E.01791
G1 X121.895 Y129.939 E.6904
G2 X121.363 Y130.055 I.848 J5.135 E.02039
G1 X108.406 Y117.098 E.68531
G3 X107.962 Y117.304 I-3.123 J-6.169 E.01829
G1 X120.84 Y130.181 E.6811
G1 X120.316 Y130.307 E.02013
G1 X107.51 Y117.5 E.67734
G1 X107.045 Y117.685 E.0187
G1 X119.809 Y130.448 E.67507
G1 X119.308 Y130.596 E.01953
G1 X106.576 Y117.864 E.6734
G1 X106.091 Y118.029 E.01914
M73 P46 R9
G1 X118.807 Y130.745 E.67255
G2 X118.32 Y130.907 I1.306 J4.72 E.01919
G1 X105.607 Y118.193 E.67245
G1 X105.122 Y118.358 E.01914
G1 X117.841 Y131.077 E.67273
G1 X117.362 Y131.247 E.01902
G1 X104.637 Y118.522 E.67301
G2 X104.155 Y118.689 I.931 J3.462 E.01909
G1 X116.894 Y131.427 E.67374
G1 X116.435 Y131.618 E.01858
G1 X103.698 Y118.881 E.67363
G2 X103.277 Y119.109 I.644 J1.697 E.01797
G1 X115.976 Y131.808 E.67165
G2 X115.524 Y132.005 I1.654 J4.41 E.01845
G1 X102.911 Y119.392 E.66709
M73 P47 R9
G2 X102.577 Y119.707 I1.406 J1.824 E.0172
G1 X115.084 Y132.214 E.66151
G1 X114.645 Y132.424 E.01821
G1 X102.245 Y120.024 E.65586
G1 X101.912 Y120.34 E.01717
G1 X114.207 Y132.636 E.65031
G1 X113.787 Y132.864 E.0179
G1 X101.579 Y120.657 E.64565
G1 X101.247 Y120.973 E.01717
G1 X113.366 Y133.092 E.641
G1 X112.945 Y133.321 E.0179
G1 X100.914 Y121.29 E.63634
G3 X100.572 Y121.596 I-3.422 J-3.48 E.0172
G1 X112.539 Y133.564 E.63298
G1 X112.137 Y133.81 E.01765
G1 X100.224 Y121.897 E.63009
G3 X99.867 Y122.189 I-2.906 J-3.187 E.01726
G1 X111.734 Y134.057 E.62768
G2 X111.34 Y134.311 I2.231 J3.892 E.01757
G1 X99.501 Y122.473 E.62614
G3 X99.133 Y122.754 I-2.385 J-2.751 E.01733
G1 X110.955 Y134.576 E.62529
G1 X110.57 Y134.84 E.01746
G1 X98.746 Y123.016 E.6254
G3 X98.352 Y123.271 I-2.574 J-3.54 E.01756
G1 X110.187 Y135.106 E.62592
G1 X109.819 Y135.387 E.01731
G1 X97.947 Y123.515 E.62791
G3 X97.529 Y123.746 I-2.398 J-3.86 E.01788
G1 X109.452 Y135.669 E.63063
G1 X109.085 Y135.951 E.01731
G1 X97.106 Y123.972 E.63359
G3 X96.675 Y124.19 I-3.266 J-5.908 E.01806
G1 X108.728 Y136.244 E.63752
G1 X108.378 Y136.543 E.01722
G1 X105.426 Y133.59 E.15618
G1 X105.446 Y133.685 E.00365
G3 X105.464 Y134.277 I-2.052 J.358 E.02223
G1 X108.028 Y136.842 E.13563
G2 X107.681 Y137.144 I2.711 J3.462 E.01721
G1 X105.378 Y134.84 E.12185
G3 X105.212 Y135.324 I-1.763 J-.333 E.01918
G1 X107.348 Y137.46 E.11299
G1 X107.015 Y137.776 E.01717
G1 X104.978 Y135.738 E.10776
G3 X104.691 Y136.101 I-1.38 J-.797 E.01734
G1 X106.682 Y138.092 E.10531
G2 X106.362 Y138.421 I2.98 J3.226 E.01717
G1 X104.353 Y136.412 E.10623
G3 X103.964 Y136.672 I-1.099 J-1.227 E.01756
G1 X106.046 Y138.754 E.11011
G1 X105.73 Y139.087 E.01717
G1 X103.518 Y136.875 E.11699
G3 X103.005 Y137.011 I-.731 J-1.716 E.01991
G1 X105.419 Y139.425 E.12769
G1 X105.12 Y139.775 E.01722
G1 X102.167 Y136.822 E.15621
; WIPE_START
G1 X103.581 Y138.236 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X103.314 Y131.479 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X96.239 Y124.403 E.37424
G1 X95.803 Y124.616 E.01815
G1 X102.355 Y131.168 E.34657
G2 X101.792 Y131.255 I.019 J1.999 E.02137
G1 X95.366 Y124.829 E.33987
G2 X94.961 Y125.073 I1.74 J3.354 E.0177
G1 X101.309 Y131.42 E.33574
G1 X100.894 Y131.654 E.01782
G1 X94.702 Y125.463 E.32746
G1 X94.474 Y125.884 E.01791
G1 X100.532 Y131.941 E.32038
G2 X100.22 Y132.279 I1.02 J1.252 E.01724
G1 X94.246 Y126.305 E.31598
G1 X94.018 Y126.726 E.01791
M73 P48 R9
G1 X99.961 Y132.668 E.3143
G2 X99.758 Y133.115 I1.451 J.93 E.01839
G1 X93.785 Y127.142 E.31589
G1 X93.544 Y127.55 E.01773
G1 X99.621 Y133.627 E.32142
G1 X99.609 Y133.685 E.00221
G2 X99.589 Y134.244 I1.931 J.349 E.02097
G1 X93.3 Y127.955 E.33262
G1 X93.041 Y128.345 E.01751
G1 X99.738 Y135.042 E.35421
G2 X101.591 Y136.895 I2.801 J-.948 E.10152
G1 X104.821 Y140.125 E.17086
G1 X104.522 Y140.475 E.01722
G1 X92.772 Y128.725 E.62144
G1 X92.495 Y129.098 E.01735
G1 X104.237 Y140.84 E.62104
G1 X103.956 Y141.207 E.01731
G1 X92.204 Y129.455 E.62156
G1 X91.908 Y129.808 E.01723
G1 X103.674 Y141.574 E.62232
G2 X103.4 Y141.949 I3.436 J2.802 E.01738
G1 X91.597 Y130.146 E.62425
G1 X91.269 Y130.467 E.01717
G1 X103.135 Y142.334 E.62763
G1 X102.871 Y142.718 E.01746
G1 X90.94 Y130.788 E.631
G3 X90.602 Y131.098 I-2.519 J-2.409 E.01719
G1 X102.607 Y143.104 E.63497
G1 X102.482 Y143.307 E.00893
G1 X101.523 Y142.669 E.0431
G1 X90.252 Y131.398 E.59612
G3 X89.9 Y131.695 I-4.334 J-4.786 E.01723
G1 X99.581 Y141.376 E.51206
G1 X97.64 Y140.084 E.08723
G1 X89.539 Y131.982 E.42848
G1 X89.177 Y132.27 E.01727
G1 X95.698 Y138.791 E.34491
G1 X93.757 Y137.499 E.08723
G1 X88.816 Y132.558 E.26133
G2 X88.463 Y132.854 I1.641 J2.307 E.01725
G1 X91.815 Y136.206 E.17728
G1 X89.874 Y134.914 E.08723
G1 X88.031 Y133.071 E.09744
; CHANGE_LAYER
; Z_HEIGHT: 0.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F6300
G1 X89.446 Y134.486 E-.76
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
G1 X127.004 Y121.478
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X127.024 Y121.467 E.00079
G3 X127.656 Y121.281 I.96 J2.092 E.0219
G3 X128.309 Y121.28 I.329 J2.411 E.02174
G3 X126.724 Y121.633 I-.325 J2.279 E.42467
G1 X126.951 Y121.507 E.00861
G1 X127.248 Y121.801 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.445 Y121.727 E.00648
G3 X127.711 Y121.67 I.531 J1.833 E.00838
G1 X127.968 Y121.651 E.00791
G3 X127.188 Y121.821 I.007 J1.908 E.34363
G1 X127.191 Y121.82 E.00009
; WIPE_START
M204 S10000
G1 X127.445 Y121.727 E-.10291
G1 X127.711 Y121.67 E-.10358
G1 X127.968 Y121.651 E-.09776
G1 X128.255 Y121.669 E-.10908
G1 X128.522 Y121.728 E-.10391
G1 X128.777 Y121.823 E-.10354
G1 X129.016 Y121.953 E-.1036
G1 X129.091 Y122.01 E-.03562
; WIPE_END
G1 E-.04 F1800
G1 X136.107 Y125.016 Z.8 F36000
G1 X152.459 Y132.022 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.479 Y132.008 E.0008
G3 X153.111 Y131.825 I.951 J2.095 E.02191
G1 X153.422 Y131.802 E.01034
G3 X152.178 Y132.174 I.008 J2.301 E.43582
G1 X152.407 Y132.05 E.00861
G1 X152.708 Y132.344 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.901 Y132.271 E.00633
G3 X153.167 Y132.214 I.531 J1.833 E.00839
G1 X153.424 Y132.195 E.00791
G3 X152.644 Y132.366 I.008 J1.908 E.34363
G1 X152.651 Y132.363 E.00023
; WIPE_START
M204 S10000
G1 X152.901 Y132.271 E-.10112
G1 X153.167 Y132.214 E-.10361
G1 X153.424 Y132.195 E-.09777
G1 X153.71 Y132.214 E-.10906
G1 X153.978 Y132.272 E-.1039
G1 X154.233 Y132.367 E-.10359
G1 X154.472 Y132.498 E-.10359
G1 X154.551 Y132.557 E-.03737
; WIPE_END
G1 E-.04 F1800
G1 X146.931 Y132.987 Z.8 F36000
G1 X100.773 Y135.595 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.587 Y135.352 E.01015
G3 X102.2 Y131.825 I1.932 J-1.249 E.15304
G1 X102.511 Y131.802 E.01034
G3 X100.809 Y135.642 I.008 J2.301 E.30395
G1 X101.067 Y135.334 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X100.918 Y135.139 E.00752
G3 X102.256 Y132.214 I1.602 J-1.036 E.1176
G1 X102.512 Y132.195 E.00791
G3 X101.103 Y135.381 I.008 J1.908 E.23346
; WIPE_START
M204 S10000
G1 X100.918 Y135.139 E-.11571
G1 X100.79 Y134.899 E-.10369
G1 X100.694 Y134.643 E-.10356
G1 X100.637 Y134.377 E-.10357
G1 X100.617 Y134.105 E-.10362
G1 X100.637 Y133.833 E-.10358
G1 X100.694 Y133.567 E-.10357
G1 X100.715 Y133.511 E-.0227
; WIPE_END
G1 E-.04 F1800
G1 X108.194 Y135.035 Z.8 F36000
G1 X153.292 Y144.224 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98338
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.39 J1.748 E.04339
G3 X88.409 Y132.052 I2.727 J2.118 E.03251
G2 X91.148 Y129.685 I-14.517 J-19.568 E.12019
G2 X93.594 Y126.159 I-11.289 J-10.445 E.14282
G3 X94.42 Y124.708 I12.298 J6.035 E.05544
G3 X95.013 Y124.286 I1.249 J1.127 E.02431
G2 X97.525 Y123.019 I-21.448 J-45.657 E.09337
G2 X101.007 Y120.323 I-8.607 J-14.711 E.14647
G3 X102.746 Y118.697 I16.21 J15.593 E.07901
G3 X103.976 Y118.067 I2.745 J3.845 E.046
G2 X107.036 Y117.001 I-16.603 J-52.618 E.10751
G2 X110.366 Y115.274 I-7.743 J-18.999 E.12463
G3 X112.192 Y114.201 I10.963 J16.572 E.07027
G3 X113.876 Y113.812 I2.032 J4.959 E.05759
G2 X117.401 Y113.355 I-2.348 J-31.915 E.11795
G2 X120.397 Y112.432 I-3.464 J-16.57 E.10415
G3 X122.451 Y111.606 I9.472 J20.574 E.07349
G3 X123.43 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I38.043 J-213.777 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16542
G3 X132.882 Y111.551 I5.292 J24.836 E.07085
G3 X133.138 Y111.543 I.192 J2.086 E.00848
G3 X134.221 Y111.865 I-.473 J3.57 E.03765
G2 X137.511 Y113.104 I11.18 J-24.699 E.11669
G2 X140.701 Y113.674 I5.147 J-19.604 E.10762
G3 X143.069 Y113.962 I-1.513 J22.32 E.07915
G3 X144.643 Y114.679 I-1.437 J5.239 E.05763
G2 X148.014 Y116.603 I17.394 J-26.558 E.12886
G2 X151.657 Y117.949 I12.729 J-28.859 E.12888
G3 X153.296 Y118.756 I-1.46 J5.035 E.06091
G3 X154.769 Y120.137 I-15.607 J18.116 E.06702
G2 X158.902 Y123.348 I14.663 J-14.613 E.17409
G3 X161.003 Y124.671 I-9.764 J17.835 E.08241
G3 X161.851 Y125.633 I-2.916 J3.422 E.04267
G2 X163.68 Y128.324 I49.858 J-31.925 E.10796
G2 X166.201 Y131.081 I16.837 J-12.865 E.1241
G3 X167.71 Y132.568 I-14.879 J16.614 E.07028
G3 X168.522 Y134.093 I-4.102 J3.161 E.05759
G1 X168.658 Y134.455 E.01282
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.783 E1.86607
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.131 J2.085 E.05196
G3 X88.163 Y131.747 I2.98 J2.215 E.03456
G2 X90.863 Y129.416 I-14.313 J-19.31 E.1097
G2 X93.249 Y125.974 I-11.007 J-10.179 E.12911
G3 X94.113 Y124.464 I12.329 J6.05 E.05348
G3 X94.828 Y123.94 I1.546 J1.358 E.02749
G2 X97.331 Y122.678 I-21.51 J-45.786 E.08611
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.511 Y118.382 I16.289 J15.673 E.0747
G3 X103.843 Y117.698 I2.992 J4.184 E.04618
G2 X106.325 Y116.856 I-157.258 J-467.762 E.08053
G2 X110.161 Y114.94 I-7.083 J-18.974 E.13198
G3 X112.029 Y113.845 I11.12 J16.826 E.06659
G3 X113.834 Y113.423 I2.197 J5.323 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.541 E.10817
G2 X120.249 Y112.069 I-3.379 J-16.162 E.09422
G3 X122.349 Y111.227 I9.426 J20.467 E.06953
G3 X123.486 Y111.206 I.613 J2.41 E.03526
G2 X125.869 Y111.616 I39.624 J-222.936 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.312 J24.948 E.06669
G3 X133.157 Y111.151 I.225 J2.497 E.00941
G3 X134.369 Y111.502 I-.486 J3.946 E.03895
G2 X137.615 Y112.726 I11.063 J-24.422 E.10667
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.532 J22.512 E.07475
G3 X144.845 Y114.343 I-1.517 J5.603 E.05719
G2 X148.18 Y116.248 I17.232 J-26.296 E.11809
G2 X151.783 Y117.578 I12.595 J-28.584 E.11808
G3 X153.537 Y118.447 I-1.58 J5.394 E.06045
G3 X155.042 Y119.856 I-15.721 J18.293 E.06336
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.23 I-11.66 J21.07 E.0712
G3 X162.173 Y125.409 I-2.914 J3.812 E.04975
G2 X163.993 Y128.088 I49.751 J-31.85 E.09952
G2 X166.471 Y130.796 I16.519 J-12.624 E.11295
G3 X168.013 Y132.318 I-14.984 J16.727 E.06658
G3 X168.887 Y133.951 I-4.417 J3.416 E.05719
G1 X169.137 Y134.615 E.02179
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X150.601 Y140.225 Z.8 F36000
G1 Z.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42164
G1 F15000
G1 X154.194 Y136.631 E.15684
G1 X154.182 Y136.636 E.00039
G3 X153.556 Y136.734 I-.656 J-2.13 E.01965
M73 P49 R9
G1 X150.474 Y139.816 E.13449
G1 X150.227 Y139.527 E.01172
G1 X153.043 Y136.711 E.12289
G3 X152.614 Y136.605 I.155 J-1.546 E.0137
G1 X149.966 Y139.252 E.11553
G1 X149.706 Y138.977 E.01169
G1 X152.237 Y136.446 E.11048
G3 X151.905 Y136.243 I.541 J-1.257 E.01206
G1 X149.445 Y138.703 E.10736
G1 X149.184 Y138.428 E.01169
G1 X151.613 Y135.999 E.10599
G3 X151.359 Y135.717 I.856 J-1.022 E.01174
G1 X148.911 Y138.165 E.10686
G1 X148.636 Y137.904 E.01169
G1 X151.146 Y135.395 E.10953
G3 X150.976 Y135.029 I1.188 J-.775 E.01249
G1 X148.361 Y137.644 E.11411
G1 X148.087 Y137.383 E.01169
G1 X150.857 Y134.612 E.12091
G3 X150.803 Y134.131 I1.649 J-.428 E.01501
G1 X147.802 Y137.132 E.13101
G1 X147.513 Y136.886 E.01172
G1 X151.121 Y133.277 E.15748
; WIPE_START
G1 X149.707 Y134.692 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.612 Y131.787 Z.8 F36000
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X159.998 Y124.4 E.32237
G1 X160.331 Y124.603 E.01202
G1 X153.463 Y131.471 E.29974
G3 X153.947 Y131.523 I.072 J1.617 E.01508
G1 X160.648 Y124.822 E.29245
G3 X160.941 Y125.064 I-1.076 J1.602 E.01176
G1 X154.364 Y131.642 E.28707
G3 X154.729 Y131.812 I-.408 J1.356 E.01249
G1 X161.205 Y125.336 E.28263
G1 X161.44 Y125.637 E.01178
G1 X155.051 Y132.025 E.27881
G3 X155.334 Y132.278 I-.739 J1.108 E.01174
G1 X161.659 Y125.953 E.27606
G1 X161.874 Y126.274 E.01191
G1 X155.577 Y132.57 E.27481
G3 X155.78 Y132.903 I-1.053 J.873 E.01206
G1 X162.089 Y126.595 E.27531
G1 X162.304 Y126.915 E.01191
G1 X155.939 Y133.279 E.27775
G3 X156.046 Y133.709 I-1.439 J.584 E.0137
G1 X162.518 Y127.236 E.2825
G1 X162.733 Y127.557 E.01191
G1 X156.069 Y134.221 E.29087
G3 X155.97 Y134.848 I-2.227 J-.029 E.01965
G1 X155.966 Y134.86 E.00038
G1 X162.948 Y127.877 E.30474
G2 X163.171 Y128.19 I3.326 J-2.137 E.01185
G1 X150.968 Y140.394 E.53262
G1 X151.214 Y140.682 E.01172
G1 X163.4 Y128.497 E.53181
G2 X163.629 Y128.804 I3.841 J-2.63 E.01181
G1 X151.449 Y140.984 E.53158
G1 X151.681 Y141.287 E.01179
G1 X163.868 Y129.1 E.53188
G2 X164.111 Y129.393 I4.272 J-3.285 E.01174
G1 X151.914 Y141.59 E.53232
G1 X152.146 Y141.893 E.01179
G1 X164.36 Y129.679 E.53304
G2 X164.615 Y129.96 I3.522 J-2.944 E.0117
G1 X152.368 Y142.207 E.53449
G1 X152.586 Y142.524 E.01189
G1 X164.875 Y130.235 E.53633
G1 X165.135 Y130.511 E.01169
G1 X152.804 Y142.842 E.53817
G1 X153.022 Y143.159 E.01189
G1 X165.408 Y130.773 E.54057
G1 X165.682 Y131.035 E.01169
G1 X153.23 Y143.487 E.54344
G1 X153.399 Y143.761 E.00994
G1 X153.653 Y143.6 E.00929
G1 X165.956 Y131.297 E.53696
G1 X166.23 Y131.558 E.01169
G1 X155.123 Y142.665 E.48473
G1 X156.594 Y141.73 E.05378
G1 X166.504 Y131.82 E.4325
G1 X166.777 Y132.082 E.01169
G1 X158.064 Y140.795 E.38027
G1 X159.535 Y139.86 E.05378
G1 X167.051 Y132.344 E.32802
G1 X167.313 Y132.618 E.01169
G1 X161.005 Y138.925 E.27527
G1 X162.476 Y137.99 E.05378
G1 X167.555 Y132.911 E.22168
G3 X167.765 Y133.237 I-2.526 J1.853 E.01197
G1 X163.946 Y137.055 E.16665
G1 X165.417 Y136.12 E.05378
G1 X167.946 Y133.591 E.11037
G3 X168.11 Y133.963 I-3.36 J1.703 E.01254
G1 X166.335 Y135.737 E.07744
G1 X147.103 Y136.759 F36000
G1 F15000
G1 X159.666 Y124.197 E.54827
G1 X159.333 Y123.994 E.01202
G1 X146.935 Y136.392 E.54112
G2 X146.637 Y136.154 I-2.419 J2.719 E.01176
G1 X159.001 Y123.791 E.5396
G1 X158.669 Y123.588 E.01202
G1 X146.334 Y135.922 E.53831
G1 X146.031 Y135.689 E.01179
G1 X158.336 Y123.384 E.53703
G1 X158.004 Y123.181 E.01202
G1 X145.728 Y135.457 E.53574
G2 X145.418 Y135.231 I-2.305 J2.849 E.01184
G1 X157.683 Y122.966 E.53531
G1 X157.364 Y122.75 E.0119
G1 X145.1 Y135.013 E.53523
G1 X144.783 Y134.795 E.01189
G1 X157.049 Y122.529 E.53535
G1 X156.742 Y122.301 E.01182
G1 X144.466 Y134.577 E.53577
G2 X144.142 Y134.365 I-2.179 J2.98 E.01195
G1 X156.44 Y122.067 E.53674
G1 X156.142 Y121.83 E.01176
G1 X143.81 Y134.162 E.53822
G1 X143.478 Y133.958 E.01202
G1 X155.853 Y121.582 E.54013
G1 X155.566 Y121.334 E.01172
G1 X143.145 Y133.755 E.54209
G2 X142.807 Y133.557 I-2.051 J3.13 E.01209
G1 X155.284 Y121.081 E.54452
G1 X155.01 Y120.819 E.01169
G1 X142.46 Y133.369 E.54771
G1 X142.113 Y133.181 E.01219
G1 X154.735 Y120.558 E.5509
G1 X154.461 Y120.296 E.01169
G1 X141.766 Y132.992 E.55409
G2 X141.412 Y132.811 I-1.911 J3.291 E.01228
G1 X154.187 Y120.035 E.55759
G1 X153.913 Y119.773 E.01169
G1 X141.049 Y132.638 E.56145
G1 X140.686 Y132.465 E.0124
G1 X153.639 Y119.512 E.56532
G2 X153.365 Y119.25 I-2.205 J2.039 E.0117
G1 X140.324 Y132.292 E.56918
G2 X139.952 Y132.127 I-1.752 J3.462 E.01254
G1 X153.074 Y119.006 E.57266
G2 X152.758 Y118.786 I-1.078 J1.209 E.0119
G1 X139.574 Y131.971 E.57542
G1 X139.195 Y131.814 E.01265
G1 X152.411 Y118.598 E.5768
G1 X152.034 Y118.439 E.01262
G1 X138.816 Y131.657 E.57688
G2 X138.425 Y131.512 I-1.576 J3.657 E.01287
G1 X151.636 Y118.301 E.57656
G1 X151.236 Y118.165 E.01303
G1 X138.03 Y131.372 E.57639
G1 X137.634 Y131.232 E.01295
G1 X150.837 Y118.029 E.57621
G1 X150.437 Y117.893 E.01303
G1 X137.239 Y131.092 E.57604
G2 X136.826 Y130.969 I-1.393 J3.935 E.0133
G1 X150.038 Y117.757 E.57663
G1 X149.638 Y117.621 E.01303
G1 X136.413 Y130.847 E.57722
G1 X135.999 Y130.725 E.0133
G1 X149.245 Y117.479 E.57808
G1 X148.861 Y117.327 E.01273
G1 X135.58 Y130.609 E.57966
G1 X135.148 Y130.505 E.01371
G1 X148.478 Y117.175 E.58179
G1 X148.107 Y117.01 E.01252
G1 X134.716 Y130.401 E.58446
G1 X134.284 Y130.298 E.01371
G1 X147.741 Y116.841 E.58731
G1 X147.381 Y116.665 E.01236
G1 X133.836 Y130.21 E.59116
G1 X133.384 Y130.127 E.01418
G1 X147.029 Y116.481 E.59554
G1 X146.682 Y116.293 E.0122
G1 X132.932 Y130.043 E.60009
G2 X132.471 Y129.968 I-.945 J4.358 E.01441
G1 X146.337 Y116.102 E.60516
G1 X146.003 Y115.9 E.01204
G1 X131.998 Y129.906 E.61125
G1 X131.525 Y129.843 E.01473
G1 X145.67 Y115.698 E.61734
G1 X145.336 Y115.496 E.01204
G1 X131.048 Y129.784 E.62357
G1 X130.552 Y129.745 E.01537
G1 X145.002 Y115.295 E.63067
G1 X144.669 Y115.093 E.01204
G1 X130.055 Y129.706 E.63777
G1 X129.559 Y129.667 E.01537
G1 X144.335 Y114.891 E.64488
G2 X143.998 Y114.692 I-1.569 J2.265 E.01207
G1 X129.037 Y129.653 E.65296
G1 X128.515 Y129.639 E.01611
G1 X143.644 Y114.51 E.66028
G2 X143.258 Y114.361 I-2.249 J5.247 E.01278
G1 X127.994 Y129.625 E.6662
G2 X127.444 Y129.639 I-.144 J5.188 E.01697
G1 X142.825 Y114.258 E.6713
G2 X142.367 Y114.18 I-.825 J3.489 E.01435
G1 X126.894 Y129.654 E.67531
G2 X126.34 Y129.672 I-.1 J5.296 E.01712
G1 X141.883 Y114.129 E.67836
G1 X141.399 Y114.078 E.01503
G1 X125.759 Y129.718 E.68259
G1 X125.177 Y129.764 E.018
G1 X128.922 Y126.019 E.16345
G3 X128.224 Y126.181 I-.948 J-2.492 E.02219
G1 X124.58 Y129.825 E.15904
G1 X123.963 Y129.906 E.0192
G1 X127.692 Y126.178 E.16274
G3 X127.244 Y126.09 I.552 J-4.026 E.0141
G1 X123.347 Y129.988 E.17009
G2 X122.692 Y130.106 I.808 J6.312 E.02054
G1 X126.856 Y125.943 E.18172
G3 X126.515 Y125.748 I.506 J-1.282 E.01216
G1 X122.035 Y130.228 E.19554
G2 X121.35 Y130.378 I1.083 J6.609 E.02165
G1 X126.215 Y125.513 E.21232
G3 X125.953 Y125.239 I.823 J-1.048 E.01173
G1 X120.645 Y130.547 E.23167
G2 X119.917 Y130.74 I1.475 J7.044 E.02326
G1 X125.731 Y124.925 E.25376
G3 X125.551 Y124.569 I1.15 J-.802 E.01235
G1 X119.156 Y130.965 E.27914
G2 X118.364 Y131.221 I2.045 J7.681 E.02568
G1 X125.422 Y124.163 E.30803
G3 X125.355 Y123.694 I1.598 J-.466 E.01467
G1 X117.535 Y131.514 E.34131
G2 X116.649 Y131.864 I2.896 J8.623 E.0294
G1 X125.607 Y122.907 E.39093
; WIPE_START
G1 X124.193 Y124.321 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X130.076 Y124.865 Z.8 F36000
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X140.914 Y114.027 E.47304
G1 X140.43 Y113.975 E.01503
G1 X130.604 Y123.801 E.42885
G2 X130.6 Y123.269 I-1.853 J-.253 E.01647
G1 X139.951 Y113.919 E.40809
G1 X139.483 Y113.851 E.01458
G1 X130.515 Y122.819 E.39142
G1 X130.365 Y122.433 E.01278
G1 X139.02 Y113.778 E.37774
G1 X138.568 Y113.694 E.01418
G1 X130.171 Y122.092 E.36651
G2 X129.935 Y121.792 I-1.163 J.669 E.01181
G1 X138.129 Y113.598 E.35759
G3 X137.696 Y113.496 I.83 J-4.478 E.01374
G1 X129.661 Y121.53 E.35065
G2 X129.348 Y121.308 I-.93 J.98 E.0119
M73 P50 R9
G1 X137.276 Y113.38 E.34601
G3 X136.866 Y113.255 I.886 J-3.628 E.01324
G1 X128.992 Y121.129 E.34366
G2 X128.586 Y120.999 I-.654 J1.349 E.0132
G1 X136.466 Y113.119 E.34393
G1 X136.066 Y112.983 E.01303
G1 X128.116 Y120.934 E.347
G2 X127.552 Y120.962 I-.136 J2.935 E.01745
G1 X135.686 Y112.828 E.355
G1 X135.306 Y112.672 E.01266
G1 X115.726 Y132.252 E.85454
G1 X114.702 Y132.74 E.03502
G1 X134.927 Y112.516 E.88267
G1 X134.547 Y112.36 E.01266
G1 X113.575 Y133.332 E.91531
G2 X112.293 Y134.079 I6.484 J12.609 E.04581
G1 X134.168 Y112.204 E.95471
G2 X133.781 Y112.055 I-2.905 J6.959 E.01279
G1 X109.923 Y135.912 E1.04125
; WIPE_START
G1 X111.338 Y134.498 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.941 Y139.895 Z.8 F36000
G1 X104.335 Y141.501 Z.8
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X102.164 Y143.672 E.09475
G1 X101.842 Y143.458 F36000
G1 F15000
G1 X133.379 Y111.921 E1.37639
G2 X132.878 Y111.887 I-.336 J1.233 E.01561
G1 X101.643 Y143.121 E1.3632
G1 X101.322 Y142.907 E.01192
G1 X132.247 Y111.982 E1.34969
G1 X131.594 Y112.099 E.02047
G1 X101 Y142.693 E1.33524
G1 X100.679 Y142.479 E.01192
G1 X130.941 Y112.217 E1.32078
G3 X130.309 Y112.313 I-1.851 J-10.001 E.01974
G1 X100.357 Y142.265 E1.30723
G1 X100.036 Y142.051 E.01192
G1 X129.693 Y112.394 E1.29435
G1 X129.106 Y112.445 E.01818
G1 X99.714 Y141.837 E1.28277
G1 X99.392 Y141.623 E.01192
G1 X128.534 Y112.482 E1.27183
G1 X127.984 Y112.496 E.01698
G1 X99.071 Y141.409 E1.26187
G1 X98.749 Y141.195 E.01192
G1 X103.331 Y136.613 E.19996
G3 X102.677 Y136.732 I-.843 J-2.787 E.02057
G1 X98.428 Y140.981 E.18544
G1 X98.106 Y140.767 E.01192
G1 X102.152 Y136.716 E.17669
G3 X101.726 Y136.612 I.17 J-1.626 E.01359
G1 X97.785 Y140.553 E.172
G1 X97.463 Y140.339 E.01192
G1 X101.345 Y136.457 E.16942
G3 X101.011 Y136.256 I.532 J-1.264 E.01209
G1 X97.142 Y140.125 E.16885
G1 X96.82 Y139.911 E.01192
G1 X100.716 Y136.014 E.17005
G3 X100.461 Y135.734 I.847 J-1.029 E.01174
G1 X96.499 Y139.697 E.17293
G1 X96.177 Y139.483 E.01192
G1 X100.245 Y135.415 E.17754
G3 X100.073 Y135.051 I1.177 J-.782 E.01245
G1 X95.856 Y139.268 E.18405
G1 X95.534 Y139.054 E.01192
G1 X99.951 Y134.638 E.19277
G3 X99.894 Y134.159 I1.634 J-.438 E.01492
G1 X95.212 Y138.84 E.20431
G1 X94.891 Y138.626 E.01192
G1 X100.191 Y133.326 E.23132
; WIPE_START
G1 X98.777 Y134.74 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.721 Y135.223 Z.8 F36000
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X127.462 Y112.483 E.99247
G3 X126.953 Y112.456 I.008 J-5.09 E.01574
G1 X105.155 Y134.254 E.95135
G2 X105.139 Y133.734 I-1.817 J-.205 E.0161
G1 X126.455 Y112.418 E.93034
G1 X125.985 Y112.353 E.01467
G1 X105.036 Y133.302 E.91427
G2 X104.88 Y132.922 I-1.399 J.355 E.0127
G1 X125.514 Y112.288 E.90055
G3 X125.046 Y112.221 I.618 J-5.889 E.01459
G1 X104.679 Y132.588 E.88891
G2 X104.437 Y132.294 I-1.144 J.693 E.01178
G1 X124.591 Y112.14 E.8796
G1 X124.137 Y112.059 E.01425
G1 X104.157 Y132.038 E.87199
G2 X103.837 Y131.822 I-.91 J1.004 E.01195
G1 X123.682 Y111.978 E.8661
G2 X123.216 Y111.908 I-.677 J2.941 E.01456
G1 X103.474 Y131.65 E.86161
G2 X103.06 Y131.528 I-.63 J1.379 E.01336
G1 X122.69 Y111.899 E.85671
G1 X122.646 Y111.902 E.00136
G2 X121.878 Y112.175 I1.151 J4.465 E.02517
G1 X102.58 Y131.473 E.84226
G2 X101.987 Y131.53 I-.032 J2.777 E.0184
G1 X120.958 Y112.559 E.82797
G3 X120.067 Y112.915 I-6.082 J-13.941 E.02962
G1 X94.569 Y138.412 E1.11281
G1 X94.248 Y138.198 E.01192
G1 X119.233 Y113.213 E1.09044
G3 X118.469 Y113.441 I-2.781 J-7.919 E.0246
G1 X93.926 Y137.984 E1.07115
G1 X93.605 Y137.77 E.01192
G1 X117.759 Y113.616 E1.05417
G3 X117.087 Y113.752 I-2.129 J-8.796 E.02115
G1 X93.283 Y137.556 E1.0389
G1 X92.962 Y137.342 E.01192
G1 X116.448 Y113.856 E1.02502
G3 X115.823 Y113.945 I-1.468 J-8.093 E.01946
G1 X92.64 Y137.128 E1.0118
G1 X92.319 Y136.914 E.01192
G1 X115.224 Y114.009 E.99968
G1 X114.625 Y114.072 E.0186
G1 X91.997 Y136.7 E.98755
G1 X91.675 Y136.486 E.01192
G1 X114.025 Y114.136 E.97543
G2 X113.414 Y114.212 I.276 J4.725 E.01903
G1 X91.354 Y136.272 E.96278
G1 X91.032 Y136.058 E.01192
G1 X112.736 Y114.354 E.94724
G2 X111.715 Y114.839 I1.381 J4.221 E.03498
G1 X90.711 Y135.844 E.91672
G1 X90.389 Y135.63 E.01192
G1 X110.358 Y115.661 E.87151
G3 X109.078 Y116.405 I-8.206 J-12.642 E.04569
G1 X90.068 Y135.416 E.8297
G1 X89.746 Y135.202 E.01192
G1 X108.001 Y116.947 E.79672
G3 X107.072 Y117.34 I-5.231 J-11.054 E.03116
G1 X89.425 Y134.988 E.77019
G1 X89.103 Y134.773 E.01192
G1 X106.219 Y117.658 E.74699
G1 X105.408 Y117.933 E.02641
G1 X88.782 Y134.559 E.72564
G1 X88.46 Y134.345 E.01192
G1 X104.598 Y118.208 E.7043
G2 X103.744 Y118.526 I1.794 J6.116 E.02815
G1 X88.139 Y134.131 E.68106
G1 X87.817 Y133.917 E.01192
G1 X100.399 Y121.336 E.54912
G3 X98.194 Y123.004 I-10.52 J-11.606 E.08544
G1 X87.563 Y133.636 E.46401
; WIPE_START
G1 X88.977 Y132.222 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X92.755 Y127.908 Z.8 F36000
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X96.971 Y123.692 E.18403
G3 X95.908 Y124.219 I-7.914 J-14.616 E.03663
G1 X93.977 Y126.15 E.08428
G1 X94.467 Y125.246 E.03173
G3 X94.725 Y124.867 I1.884 J1.006 E.0142
G1 X95.231 Y124.361 E.02205
; CHANGE_LAYER
; Z_HEIGHT: 0.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X94.725 Y124.867 E-.27157
G1 X94.467 Y125.246 E-.17446
G1 X94.073 Y125.973 E-.31397
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
G1 X127.006 Y121.476
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X127.028 Y121.469 E.00077
G3 X127.916 Y121.262 I.957 J2.091 E.03045
G3 X129.283 Y125.458 I.067 J2.299 E.19609
G3 X126.741 Y121.627 I-1.298 J-1.898 E.24174
G1 X126.954 Y121.506 E.00813
G1 X127.242 Y121.804 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.446 Y121.732 E.00667
G3 X127.944 Y121.653 I.545 J1.829 E.01553
G3 X128.522 Y121.728 I-.003 J2.296 E.01794
G3 X127.188 Y121.83 I-.53 J1.833 E.32643
; WIPE_START
M204 S10000
G1 X127.446 Y121.732 E-.10516
G1 X127.711 Y121.67 E-.10343
G1 X127.944 Y121.653 E-.08869
G1 X128.255 Y121.67 E-.11839
G1 X128.522 Y121.728 E-.10358
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.953 E-.10358
G1 X129.087 Y122.006 E-.0336
; WIPE_END
G1 E-.04 F1800
G1 X122.206 Y125.309 Z1 F36000
G1 X100.773 Y135.595 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.597 Y135.346 E.01013
G3 X102.46 Y131.806 I1.939 J-1.239 E.16082
G3 X103.485 Y132.009 I.085 J2.25 E.03495
G3 X100.816 Y135.636 I-.949 J2.097 E.2718
G1 X101.069 Y135.336 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X100.928 Y135.133 E.00759
G3 X102.488 Y132.197 I1.607 J-1.028 E.124
G3 X103.066 Y132.272 I-.003 J2.295 E.01794
G3 X101.113 Y135.376 I-.53 J1.833 E.21699
; WIPE_START
M204 S10000
G1 X100.928 Y135.133 E-.11596
G1 X100.79 Y134.899 E-.10338
G1 X100.694 Y134.643 E-.10357
M73 P51 R9
G1 X100.637 Y134.377 E-.10358
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10357
G1 X100.715 Y133.511 E-.02273
; WIPE_END
G1 E-.04 F1800
G1 X108.345 Y133.291 Z1 F36000
G1 X152.462 Y132.02 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.485 Y132.016 E.00078
G3 X153.372 Y131.806 I.962 J2.09 E.03043
G3 X154.396 Y132.009 I.085 J2.25 E.03495
G3 X152.198 Y132.174 I-.949 J2.097 E.40339
G1 X152.41 Y132.051 E.00813
G1 X152.701 Y132.346 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.902 Y132.276 E.00654
G3 X153.4 Y132.197 I.545 J1.829 E.01553
G3 X153.978 Y132.272 I-.003 J2.295 E.01794
G3 X152.647 Y132.372 I-.53 J1.833 E.32655
; WIPE_START
M204 S10000
G1 X152.902 Y132.276 E-.10355
G1 X153.167 Y132.214 E-.10344
G1 X153.4 Y132.197 E-.08868
G1 X153.711 Y132.214 E-.11839
G1 X153.978 Y132.272 E-.10358
G1 X154.233 Y132.367 E-.10359
G1 X154.472 Y132.498 E-.10357
G1 X154.546 Y132.553 E-.03519
; WIPE_END
G1 E-.04 F1800
G1 X153.731 Y140.142 Z1 F36000
G1 X153.292 Y144.224 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98338
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.39 J1.747 E.04338
G3 X88.408 Y132.053 I2.736 J2.127 E.03248
G2 X91.148 Y129.685 I-14.52 J-19.572 E.12023
G2 X93.594 Y126.16 I-11.287 J-10.443 E.14279
G3 X94.42 Y124.708 I12.316 J6.045 E.05546
G3 X95.013 Y124.286 I1.249 J1.126 E.02432
G2 X97.525 Y123.019 I-21.462 J-45.683 E.09336
G2 X101.007 Y120.323 I-8.607 J-14.711 E.14646
G3 X102.746 Y118.697 I16.202 J15.584 E.07902
G3 X103.976 Y118.067 I2.756 J3.867 E.046
G2 X107.047 Y116.997 I-16.541 J-52.434 E.10791
G2 X110.366 Y115.274 I-7.762 J-19.009 E.12423
G3 X112.192 Y114.201 I10.971 J16.585 E.07026
G3 X113.876 Y113.812 I2.035 J4.97 E.05759
G2 X117.401 Y113.355 I-2.347 J-31.912 E.11796
G2 X120.397 Y112.432 I-3.462 J-16.567 E.10417
G3 X122.452 Y111.605 I9.399 J20.394 E.07348
G3 X123.43 Y111.594 I.513 J2.044 E.03276
G2 X125.813 Y112.005 I38.04 J-213.75 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16542
G3 X132.882 Y111.551 I5.36 J25.237 E.07085
G3 X133.136 Y111.543 I.192 J2.085 E.00843
G3 X134.063 Y111.801 I-.416 J3.281 E.03202
G2 X136.158 Y112.662 I45.288 J-107.209 E.07514
G2 X140.702 Y113.674 I6.095 J-16.668 E.15486
G3 X143.068 Y113.962 I-1.513 J22.32 E.07912
G3 X144.643 Y114.679 I-1.436 J5.237 E.05763
G2 X148.015 Y116.604 I17.39 J-26.551 E.12888
G2 X151.657 Y117.949 I12.728 J-28.858 E.12886
G3 X153.296 Y118.756 I-1.461 J5.035 E.06095
G3 X154.769 Y120.137 I-13.859 J16.25 E.06698
G2 X158.902 Y123.348 I14.663 J-14.613 E.17409
G3 X160.841 Y124.544 I-11.514 J20.824 E.07559
G3 X161.85 Y125.632 I-2.67 J3.489 E.04947
G2 X163.68 Y128.324 I49.733 J-31.84 E.10798
G2 X166.202 Y131.082 I16.837 J-12.864 E.12414
G3 X167.71 Y132.567 I-14.864 J16.599 E.07024
G3 X168.517 Y134.082 I-4.08 J3.147 E.05721
G1 X168.658 Y134.455 E.01321
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.786 E1.86603
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.137 J2.087 E.05195
G3 X88.162 Y131.747 I2.988 J2.222 E.03454
G2 X90.863 Y129.416 I-14.314 J-19.311 E.10972
G2 X93.249 Y125.974 I-11.005 J-10.177 E.12911
G3 X94.112 Y124.464 I12.335 J6.053 E.05348
G3 X94.828 Y123.94 I1.545 J1.357 E.02749
G2 X97.331 Y122.678 I-21.524 J-45.813 E.08612
G2 X100.735 Y120.04 I-8.414 J-14.374 E.1327
G3 X102.511 Y118.382 I16.29 J15.673 E.07471
G3 X103.843 Y117.698 I3.004 J4.208 E.04618
G2 X106.325 Y116.856 I-156.634 J-465.919 E.08054
G2 X110.161 Y114.94 I-7.082 J-18.974 E.13198
G3 X112.029 Y113.845 I11.124 J16.832 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.545 E.10818
G2 X120.25 Y112.069 I-3.378 J-16.161 E.09424
G3 X122.349 Y111.227 I9.362 J20.308 E.06953
G3 X123.486 Y111.206 I.613 J2.411 E.03526
G2 X125.869 Y111.617 I39.692 J-223.328 E.0743
G2 X130.711 Y111.521 I2.13 J-14.776 E.14948
G3 X132.851 Y111.16 I5.378 J25.334 E.06668
G3 X133.155 Y111.151 I.225 J2.499 E.00936
G3 X134.208 Y111.437 I-.433 J3.674 E.03366
G2 X136.296 Y112.295 I45.76 J-108.348 E.06937
G2 X140.743 Y113.284 I5.955 J-16.294 E.14037
G3 X143.156 Y113.579 I-1.533 J22.521 E.07474
G3 X144.845 Y114.343 I-1.517 J5.602 E.0572
G2 X148.18 Y116.248 I17.231 J-26.293 E.1181
G2 X151.783 Y117.578 I12.592 J-28.577 E.11808
G3 X153.54 Y118.449 I-1.58 J5.394 E.06055
G3 X155.042 Y119.856 I-14.065 J16.519 E.06327
G2 X159.105 Y123.012 I14.388 J-14.329 E.15851
G3 X161.075 Y124.23 I-11.662 J21.073 E.0712
G3 X162.172 Y125.409 I-2.916 J3.814 E.04973
G2 X163.993 Y128.088 I49.632 J-31.77 E.09954
G2 X166.471 Y130.796 I16.518 J-12.622 E.11296
G3 X168.012 Y132.318 I-14.982 J16.725 E.06657
G3 X168.883 Y133.941 I-4.395 J3.403 E.05685
G1 X169.137 Y134.615 E.02214
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X151.603 Y141.463 Z1 F36000
G1 Z.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42217
G1 F15000
G1 X153.706 Y143.566 E.0919
G1 X154.034 Y143.358 E.01201
G1 X122.595 Y111.918 E1.37405
G3 X123.11 Y111.898 I.32 J1.529 E.01602
G1 X154.362 Y143.149 E1.36585
G1 X154.689 Y142.941 E.01201
G1 X123.736 Y111.987 E1.35282
G1 X124.388 Y112.103 E.02049
G1 X155.017 Y142.732 E1.33863
G1 X155.345 Y142.524 E.01201
G1 X125.041 Y112.22 E1.32444
G2 X125.667 Y112.31 I1.438 J-7.784 E.01956
G1 X155.673 Y142.315 E1.3114
G1 X156.001 Y142.107 E.01201
G1 X126.289 Y112.395 E1.29856
G2 X126.881 Y112.451 I.76 J-4.89 E.0184
G1 X156.329 Y141.898 E1.28701
G1 X156.657 Y141.69 E.01201
G1 X127.449 Y112.482 E1.27652
G2 X127.999 Y112.496 I.405 J-5.286 E.01701
G1 X157.108 Y141.604 E1.27219
G1 X161.37 Y138.894 F36000
G1 F15000
G1 X156.007 Y133.532 E.23438
G3 X156.077 Y134.105 I-1.959 J.53 E.01791
G1 X156.075 Y134.136 E.00095
G1 X160.919 Y138.98 E.21172
G1 X160.591 Y139.188 E.01201
G1 X156.02 Y134.617 E.19977
G3 X155.901 Y135.034 I-1.509 J-.208 E.01344
G1 X160.263 Y139.397 E.19067
G1 X159.936 Y139.605 E.01201
G1 X155.73 Y135.4 E.18381
G3 X155.516 Y135.722 I-1.226 J-.584 E.01199
G1 X159.608 Y139.814 E.17885
G1 X159.28 Y140.022 E.01201
G1 X155.261 Y136.004 E.17563
G3 X154.968 Y136.247 I-.992 J-.897 E.01181
G1 X158.952 Y140.231 E.17411
G1 X158.624 Y140.439 E.01201
G1 X154.635 Y136.45 E.17435
G3 X154.257 Y136.608 I-.739 J-1.235 E.01271
G1 X158.296 Y140.648 E.17655
G1 X157.968 Y140.856 E.01201
G1 X153.826 Y136.713 E.18106
G3 X153.309 Y136.733 I-.408 J-3.878 E.01598
G1 X157.64 Y141.065 E.1893
G1 X157.312 Y141.273 E.01201
G1 X152.663 Y136.623 E.20321
G3 X150.921 Y134.881 I.804 J-2.546 E.07913
G1 X128.522 Y112.482 E.97896
G2 X129.028 Y112.452 I.009 J-4.147 E.01569
G1 X150.811 Y134.235 E.95202
G3 X150.828 Y133.73 I1.767 J-.192 E.01569
G1 X129.521 Y112.409 E.93152
G2 X130.006 Y112.358 I-.195 J-4.151 E.01508
G1 X150.936 Y133.288 E.91474
G3 X151.094 Y132.91 I1.396 J.362 E.01271
G1 X130.474 Y112.289 E.90122
G2 X130.938 Y112.217 I-.905 J-7.397 E.01453
G1 X151.297 Y132.576 E.88979
G3 X151.54 Y132.283 I1.141 J.699 E.01181
G1 X131.393 Y112.135 E.88054
G1 X131.848 Y112.054 E.01428
G1 X151.823 Y132.029 E.873
G3 X152.144 Y131.814 I.906 J1.012 E.01199
G1 X132.302 Y111.972 E.86719
G3 X132.766 Y111.9 I.839 J3.857 E.01452
G1 X152.51 Y131.643 E.86289
G3 X152.927 Y131.524 I.624 J1.39 E.01344
G1 X133.302 Y111.899 E.85769
G3 X134.127 Y112.188 I-1.664 J6.082 E.02703
G1 X153.414 Y131.474 E.84292
G3 X154.013 Y131.537 I.114 J1.807 E.0187
G1 X135.038 Y112.562 E.8293
G1 X135.948 Y112.936 E.03043
G1 X161.575 Y138.563 E1.12001
G1 X161.903 Y138.355 E.01201
G1 X136.77 Y113.222 E1.09841
G2 X137.537 Y113.452 I2.382 J-6.546 E.02474
G1 X162.231 Y138.146 E1.07925
G1 X162.559 Y137.938 E.01201
G1 X138.246 Y113.625 E1.0626
G2 X138.916 Y113.759 I2.11 J-8.798 E.02114
G1 X162.886 Y137.729 E1.04762
G1 X163.214 Y137.521 E.01201
G1 X139.555 Y113.861 E1.03403
G2 X140.178 Y113.949 I1.438 J-8.011 E.01946
G1 X163.542 Y137.312 E1.02111
G1 X163.87 Y137.104 E.01201
G1 X140.778 Y114.012 E1.00922
G1 X141.378 Y114.076 E.01864
G1 X164.198 Y136.895 E.99733
G1 X164.526 Y136.687 E.01201
G1 X141.978 Y114.139 E.98544
G3 X142.593 Y114.218 I-.298 J4.772 E.01918
G1 X164.854 Y136.478 E.9729
G1 X165.182 Y136.27 E.01201
G1 X143.278 Y114.367 E.95728
G3 X144.345 Y114.897 I-1.718 J4.793 E.03689
G1 X165.51 Y136.062 E.92499
G1 X165.837 Y135.853 E.01201
G1 X145.702 Y115.718 E.88
G2 X146.969 Y116.449 I8.128 J-12.632 E.04521
G1 X166.165 Y135.645 E.83896
G1 X166.493 Y135.436 E.01201
G1 X148.034 Y116.977 E.80675
G2 X148.959 Y117.366 I5.161 J-10.987 E.03102
G1 X166.821 Y135.228 E.78066
G1 X167.149 Y135.019 E.01201
G1 X149.809 Y117.679 E.75785
G1 X150.622 Y117.956 E.02655
G1 X167.477 Y134.811 E.73663
G1 X167.805 Y134.602 E.01201
G1 X151.436 Y118.233 E.71541
G3 X152.282 Y118.543 I-1.765 J6.128 E.02789
G1 X168.133 Y134.394 E.69274
G1 X168.248 Y134.32 E.00424
G2 X168.011 Y133.736 I-5.502 J1.893 E.01949
G1 X155.884 Y121.609 E.53003
G2 X157.975 Y123.164 I15.739 J-18.984 E.08058
G1 X163.686 Y128.875 E.2496
M73 P52 R9
G3 X162.385 Y127.037 I21.477 J-16.588 E.0696
G1 X159.354 Y124.007 E.13246
G1 X160.455 Y124.679 E.03988
G3 X161.017 Y125.133 I-2.014 J3.068 E.02233
G1 X161.915 Y126.031 E.03925
G1 X131.58 Y130.022 F36000
G1 F15000
G1 X127.739 Y126.181 E.16786
G2 X128.272 Y126.178 I.256 J-1.857 E.01653
G1 X132.001 Y129.906 E.16294
G1 X132.618 Y129.987 E.01925
G1 X128.723 Y126.092 E.17023
G1 X129.11 Y125.943 E.01282
G1 X133.273 Y130.106 E.18195
G1 X133.932 Y130.228 E.02069
G1 X129.45 Y125.747 E.19587
G2 X129.752 Y125.512 I-2.06 J-2.973 E.01182
G1 X134.618 Y130.378 E.21264
G1 X135.324 Y130.547 E.02243
G1 X130.014 Y125.238 E.23204
G2 X130.237 Y124.924 I-.981 J-.93 E.01193
G1 X136.053 Y130.74 E.2542
G1 X136.815 Y130.966 E.02456
G1 X130.416 Y124.567 E.27967
G2 X130.546 Y124.16 I-1.353 J-.654 E.01324
G1 X137.608 Y131.223 E.30866
G1 X138.438 Y131.517 E.02722
M73 P52 R8
G1 X130.612 Y123.69 E.34206
G2 X130.581 Y123.123 I-3.012 J-.119 E.01759
G1 X139.64 Y132.182 E.39592
; WIPE_START
G1 X138.225 Y130.767 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X144.599 Y134.965 Z1 F36000
G1 X146.081 Y135.941 Z1
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X122.188 Y112.048 E1.04426
G2 X121.808 Y112.204 I.702 J2.247 E.01272
G1 X143.695 Y134.091 E.95657
G2 X142.408 Y133.341 I-7.808 J11.908 E.04607
G1 X121.429 Y112.362 E.91686
G1 X121.051 Y112.52 E.01267
G1 X141.277 Y132.746 E.88398
G1 X140.251 Y132.257 E.03511
G1 X120.673 Y112.678 E.85569
G3 X120.288 Y112.83 I-2.603 J-6.017 E.01277
G1 X128.422 Y120.964 E.35546
G1 X128.355 Y120.949 E.00211
G2 X127.854 Y120.932 I-.321 J2.097 E.01553
G1 X119.9 Y112.978 E.34763
G3 X119.508 Y113.123 I-1.736 J-4.103 E.01291
G1 X127.384 Y120.999 E.34421
G2 X126.977 Y121.128 I.247 J1.481 E.01324
G1 X119.104 Y113.255 E.34407
G3 X118.692 Y113.38 I-1.511 J-4.269 E.01331
G1 X126.625 Y121.312 E.3467
G2 X126.306 Y121.53 I.753 J1.447 E.01196
G1 X118.272 Y113.496 E.35113
G3 X117.838 Y113.598 I-1.266 J-4.385 E.01378
G1 X126.032 Y121.792 E.35809
G2 X125.796 Y122.092 I.927 J.969 E.01185
G1 X117.398 Y113.695 E.36703
G1 X116.946 Y113.778 E.01422
G1 X125.601 Y122.434 E.37829
G1 X125.452 Y122.821 E.01282
G1 X116.482 Y113.851 E.39202
G1 X116.014 Y113.919 E.01462
G1 X125.366 Y123.272 E.40875
G2 X125.363 Y123.805 I1.853 J.278 E.01653
G1 X115.534 Y113.976 E.42959
G1 X115.049 Y114.027 E.01507
G1 X125.528 Y124.506 E.45798
G2 X127.033 Y126.011 I2.442 J-.937 E.06774
G1 X130.785 Y129.763 E.16399
G1 X130.203 Y129.717 E.01805
G1 X114.564 Y114.079 E.68349
G1 X114.08 Y114.13 E.01507
G1 X129.621 Y129.672 E.67923
G2 X129.066 Y129.653 I-.451 J5.267 E.01716
G1 X113.595 Y114.182 E.67618
G2 X113.137 Y114.26 I.37 J3.56 E.01438
G1 X128.516 Y129.639 E.67214
G2 X127.966 Y129.626 I-.404 J5.254 E.017
G1 X112.703 Y114.363 E.66704
G2 X112.316 Y114.512 I1.799 J5.251 E.01283
G1 X127.443 Y129.639 E.66112
G1 X126.92 Y129.653 E.01616
G1 X111.962 Y114.694 E.65378
G2 X111.625 Y114.894 I1.243 J2.476 E.0121
G1 X126.399 Y129.668 E.64568
G1 X125.902 Y129.707 E.01541
G1 X111.291 Y115.096 E.63855
G1 X110.957 Y115.298 E.01207
G1 X125.404 Y129.746 E.63142
G1 X124.907 Y129.785 E.01541
G1 X110.623 Y115.501 E.62429
G1 X110.289 Y115.703 E.01207
G1 X124.431 Y129.845 E.61807
G1 X123.957 Y129.907 E.01477
G1 X109.955 Y115.905 E.61196
G1 X109.621 Y116.107 E.01207
G1 X123.483 Y129.97 E.60585
G2 X123.022 Y130.045 I.491 J4.432 E.01444
G1 X109.275 Y116.299 E.6008
G1 X108.927 Y116.487 E.01223
G1 X122.57 Y130.129 E.59624
G1 X122.117 Y130.213 E.01422
G1 X108.575 Y116.671 E.59187
G1 X108.214 Y116.847 E.01239
G1 X121.669 Y130.301 E.58803
G1 X121.236 Y130.405 E.01375
G1 X107.847 Y117.015 E.58519
G1 X107.475 Y117.18 E.01256
G1 X120.804 Y130.509 E.58251
G1 X120.371 Y130.613 E.01375
G1 X107.091 Y117.333 E.5804
G1 X106.707 Y117.485 E.01277
G1 X119.952 Y130.729 E.57884
G1 X119.538 Y130.852 E.01334
G1 X106.312 Y117.626 E.57802
G1 X105.912 Y117.762 E.01307
G1 X119.124 Y130.974 E.57744
G2 X118.711 Y131.098 I.966 J3.98 E.01332
G1 X105.511 Y117.898 E.5769
G1 X105.111 Y118.034 E.01307
G1 X118.315 Y131.238 E.5771
G1 X117.919 Y131.378 E.01299
G1 X104.71 Y118.17 E.57729
G1 X104.31 Y118.305 E.01307
G1 X117.523 Y131.519 E.57748
G2 X117.132 Y131.664 I1.195 J3.799 E.01289
G1 X103.92 Y118.452 E.57745
G1 X103.543 Y118.611 E.01266
G1 X116.753 Y131.821 E.57737
G1 X116.374 Y131.979 E.01269
G1 X103.194 Y118.799 E.57603
G2 X102.882 Y119.023 I.704 J1.313 E.01191
G1 X115.995 Y132.136 E.57311
G2 X115.624 Y132.301 I1.391 J3.624 E.01256
G1 X102.59 Y119.267 E.56963
G1 X102.315 Y119.529 E.01172
G1 X115.26 Y132.474 E.56578
G1 X114.897 Y132.647 E.01243
G1 X102.04 Y119.79 E.56192
G1 X101.765 Y120.052 E.01172
G1 X114.534 Y132.821 E.55806
G2 X114.181 Y133.003 I1.568 J3.469 E.01231
G1 X101.491 Y120.313 E.55462
G1 X101.216 Y120.575 E.01172
G1 X113.833 Y133.192 E.55144
G1 X113.485 Y133.381 E.01222
G1 X100.941 Y120.836 E.54826
G1 X100.666 Y121.098 E.01172
G1 X113.138 Y133.569 E.54508
G2 X112.8 Y133.768 I1.725 J3.323 E.01211
G1 X100.382 Y121.35 E.54272
G1 X100.095 Y121.599 E.01175
G1 X112.467 Y133.972 E.54075
G1 X112.135 Y134.175 E.01205
G1 X99.805 Y121.845 E.53889
G1 X99.503 Y122.08 E.01181
G1 X111.802 Y134.379 E.53756
G2 X111.479 Y134.592 I1.87 J3.19 E.01197
G1 X99.201 Y122.314 E.53663
G3 X98.892 Y122.542 I-1.936 J-2.294 E.01186
G1 X111.161 Y134.811 E.53621
G1 X110.843 Y135.029 E.01192
G1 X98.573 Y122.759 E.53628
G3 X98.249 Y122.971 I-2.146 J-2.916 E.01198
G1 X110.525 Y135.248 E.53654
G2 X110.216 Y135.474 I2.009 J3.07 E.01187
G1 X97.914 Y123.173 E.53762
G3 X97.575 Y123.37 I-2.035 J-3.121 E.01213
G1 X109.912 Y135.707 E.5392
G1 X109.609 Y135.94 E.01182
G1 X97.225 Y123.556 E.54123
G1 X96.875 Y123.743 E.01225
G1 X109.305 Y136.173 E.54325
G2 X109.008 Y136.412 I2.138 J2.952 E.01179
G1 X96.518 Y123.922 E.54591
G1 X96.157 Y124.098 E.01239
G1 X108.719 Y136.66 E.54902
G1 X108.43 Y136.907 E.01176
G1 X105.107 Y133.584 E.14524
G3 X105.16 Y134.174 I-2.873 J.559 E.01834
G1 X108.141 Y137.154 E.13025
G2 X107.856 Y137.406 I2.257 J2.833 E.01175
G1 X105.101 Y134.651 E.1204
G3 X104.978 Y135.064 I-1.497 J-.222 E.01336
G1 X107.581 Y137.667 E.11377
G1 X107.306 Y137.928 E.01172
G1 X104.804 Y135.426 E.10935
G3 X104.586 Y135.745 I-1.218 J-.597 E.01197
G1 X107.031 Y138.189 E.10682
G2 X106.759 Y138.453 I2.379 J2.723 E.01173
G1 X104.329 Y136.024 E.10617
G3 X104.033 Y136.264 I-.985 J-.911 E.01182
G1 X106.497 Y138.729 E.1077
G1 X106.236 Y139.004 E.01172
G1 X103.696 Y136.463 E.11103
G3 X103.315 Y136.619 I-.653 J-1.051 E.01276
G1 X105.975 Y139.279 E.11625
G2 X105.715 Y139.555 I2.507 J2.618 E.01173
G1 X102.877 Y136.718 E.12402
G3 X102.354 Y136.73 I-.306 J-1.816 E.01625
G1 X105.468 Y139.845 E.13612
G1 X105.221 Y140.134 E.01176
G1 X101.686 Y136.599 E.15449
G3 X100.033 Y134.946 I.851 J-2.504 E.07483
G1 X92.973 Y127.886 E.30856
G1 X92.759 Y128.208 E.01196
G1 X104.974 Y140.423 E.53385
G1 X104.727 Y140.712 E.01176
G1 X92.537 Y128.522 E.53277
G1 X92.308 Y128.83 E.01185
G1 X104.494 Y141.015 E.53257
G1 X104.261 Y141.319 E.01182
G1 X92.07 Y129.128 E.5328
G1 X91.821 Y129.416 E.01175
G1 X104.028 Y141.622 E.53349
G1 X103.795 Y141.926 E.01182
G1 X91.573 Y129.704 E.53418
G3 X91.318 Y129.985 I-1.807 J-1.378 E.01175
G1 X103.575 Y142.242 E.53568
G1 X103.356 Y142.56 E.01192
G1 X91.047 Y130.25 E.53798
G1 X90.776 Y130.515 E.01172
G1 X103.138 Y142.878 E.54029
G1 X102.919 Y143.196 E.01192
G1 X90.501 Y130.777 E.54276
G1 X90.212 Y131.024 E.01176
G1 X102.713 Y143.525 E.54636
G1 X102.579 Y143.744 E.00793
G1 X102.03 Y143.379 E.02038
G1 X89.923 Y131.272 E.52913
G3 X89.629 Y131.514 I-3.547 J-4.003 E.01178
G1 X100.425 Y142.311 E.47186
G1 X98.821 Y141.243 E.05956
G1 X89.33 Y131.752 E.41479
G1 X89.032 Y131.99 E.0118
M73 P53 R8
G1 X97.217 Y140.174 E.35772
G1 X95.612 Y139.106 E.05956
G1 X88.733 Y132.227 E.30066
G1 X88.434 Y132.465 E.0118
G1 X94.008 Y138.038 E.24359
G1 X92.403 Y136.97 E.05956
G1 X88.154 Y132.721 E.18574
G2 X87.933 Y133.036 I.423 J.531 E.01207
G1 X90.799 Y135.902 E.12527
G1 X89.195 Y134.834 E.05956
G1 X87.663 Y133.303 E.06695
G1 X100.087 Y134.463 F36000
G1 F15000
G1 X93.18 Y127.557 E.30184
G1 X93.379 Y127.22 E.0121
G1 X99.915 Y133.755 E.28564
G3 X100.013 Y133.317 I4.824 J.855 E.01388
G1 X93.578 Y126.882 E.28124
G2 X93.768 Y126.536 I-4.592 J-2.744 E.01221
G1 X100.168 Y132.936 E.27971
G3 X100.368 Y132.599 I1.269 J.526 E.01214
G1 X93.957 Y126.188 E.28021
G1 X94.145 Y125.84 E.01223
G1 X100.608 Y132.303 E.28248
G3 X100.888 Y132.046 I1.035 J.843 E.01177
G1 X94.334 Y125.492 E.28644
G3 X94.527 Y125.149 I2.828 J1.372 E.01217
G1 X101.211 Y131.833 E.29209
G3 X101.569 Y131.654 I.707 J.972 E.01242
G1 X94.755 Y124.841 E.29777
G3 X95.082 Y124.631 I.89 J1.023 E.01203
G1 X101.982 Y131.531 E.30157
G3 X102.459 Y131.472 I.612 J3.007 E.01489
G1 X95.436 Y124.45 E.30693
G1 X95.797 Y124.274 E.01239
G1 X103.283 Y131.76 E.32718
; CHANGE_LAYER
; Z_HEIGHT: 0.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X101.869 Y130.345 E-.76
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
G1 X127.006 Y121.476
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X127.029 Y121.471 E.00079
G3 X127.907 Y121.263 I.961 J2.091 E.03011
G3 X129.229 Y121.623 I.063 J2.377 E.04611
G3 X126.742 Y121.629 I-1.238 J1.939 E.39247
G1 X126.954 Y121.506 E.00812
G1 X127.235 Y121.806 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.447 Y121.733 E.00688
G3 X127.935 Y121.654 I.546 J1.828 E.01523
G3 X128.522 Y121.728 I.017 J2.233 E.01824
G3 X127.182 Y121.834 I-.529 J1.833 E.32615
; WIPE_START
M204 S10000
G1 X127.447 Y121.733 E-.10766
G1 X127.712 Y121.67 E-.10346
G1 X127.935 Y121.654 E-.08498
G1 X128.255 Y121.67 E-.12205
G1 X128.522 Y121.728 E-.10358
G1 X128.777 Y121.823 E-.10356
G1 X129.016 Y121.953 E-.10358
G1 X129.082 Y122.003 E-.03112
; WIPE_END
G1 E-.04 F1800
G1 X122.201 Y125.306 Z1.2 F36000
G1 X100.773 Y135.595 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.596 Y135.346 E.01012
G3 X102.451 Y131.807 I1.939 J-1.24 E.16056
G3 X103.773 Y132.167 I.063 J2.377 E.04611
G3 X100.816 Y135.636 I-1.238 J1.939 E.26081
G1 X101.071 Y135.338 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X100.929 Y135.132 E.00769
G3 X102.479 Y132.198 I1.608 J-1.027 E.12363
G3 X103.066 Y132.272 I.017 J2.232 E.01824
G3 X101.115 Y135.377 I-.529 J1.833 E.217
; WIPE_START
M204 S10000
G1 X100.929 Y135.132 E-.11695
G1 X100.79 Y134.899 E-.10338
G1 X100.694 Y134.643 E-.10357
G1 X100.637 Y134.377 E-.10358
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10357
G1 X100.714 Y133.513 E-.02176
; WIPE_END
G1 E-.04 F1800
G1 X108.344 Y133.293 Z1.2 F36000
G1 X152.462 Y132.021 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.485 Y132.016 E.00079
G3 X153.362 Y131.807 I.961 J2.091 E.03011
G3 X154.685 Y132.167 I.063 J2.377 E.04611
G3 X152.198 Y132.173 I-1.238 J1.939 E.39247
G1 X152.41 Y132.051 E.00812
G1 X152.695 Y132.349 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.903 Y132.277 E.00676
G3 X153.39 Y132.198 I.546 J1.828 E.01523
G3 X153.978 Y132.272 I.017 J2.232 E.01824
G3 X152.641 Y132.376 I-.529 J1.833 E.32627
; WIPE_START
M204 S10000
G1 X152.903 Y132.277 E-.10621
G1 X153.167 Y132.214 E-.10345
G1 X153.39 Y132.198 E-.08499
G1 X153.711 Y132.214 E-.12204
G1 X153.978 Y132.272 E-.10358
G1 X154.233 Y132.367 E-.10357
G1 X154.472 Y132.498 E-.10359
G1 X154.541 Y132.549 E-.03256
; WIPE_END
G1 E-.04 F1800
G1 X153.729 Y140.138 Z1.2 F36000
G1 X153.292 Y144.224 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98338
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.393 J1.749 E.04338
G3 X88.408 Y132.052 I2.734 J2.125 E.0325
G2 X91.148 Y129.685 I-14.522 J-19.574 E.12021
G2 X93.594 Y126.16 I-11.287 J-10.443 E.14279
G3 X94.42 Y124.708 I12.313 J6.043 E.05547
G3 X95.013 Y124.286 I1.249 J1.126 E.02432
G2 X97.525 Y123.019 I-21.471 J-45.703 E.09335
G2 X101.007 Y120.323 I-8.605 J-14.709 E.14649
G3 X102.746 Y118.696 I16.204 J15.587 E.07903
G3 X103.976 Y118.067 I2.751 J3.858 E.04599
G2 X107.047 Y116.997 I-16.539 J-52.425 E.1079
G2 X110.366 Y115.274 I-7.762 J-19.008 E.12423
G3 X112.192 Y114.201 I10.961 J16.569 E.07027
G3 X113.876 Y113.812 I2.035 J4.969 E.05759
G2 X117.401 Y113.355 I-2.348 J-31.917 E.11795
G2 X120.397 Y112.432 I-3.463 J-16.568 E.10417
G3 X122.451 Y111.606 I9.574 J20.827 E.07347
G3 X123.431 Y111.594 I.514 J2.043 E.03279
G2 X125.813 Y112.005 I37.951 J-213.238 E.0802
G2 X130.777 Y111.907 I2.186 J-15.165 E.16542
G3 X132.883 Y111.551 I5.292 J24.835 E.07086
G3 X133.14 Y111.543 I.194 J2.122 E.00854
G3 X134.213 Y111.862 I-.479 J3.573 E.03728
G2 X137.511 Y113.104 I11.269 J-24.916 E.11699
G2 X140.702 Y113.674 I5.147 J-19.605 E.10764
G3 X143.068 Y113.962 I-1.515 J22.336 E.07911
G3 X144.643 Y114.679 I-1.436 J5.237 E.05764
G2 X148.014 Y116.603 I17.393 J-26.557 E.12885
G2 X151.657 Y117.949 I12.732 J-28.865 E.12889
G3 X153.297 Y118.757 I-1.46 J5.035 E.06096
G3 X154.769 Y120.137 I-13.911 J16.305 E.06697
G2 X158.902 Y123.348 I14.664 J-14.614 E.17409
G3 X161.004 Y124.671 I-9.761 J17.831 E.08242
G3 X161.85 Y125.633 I-2.916 J3.421 E.04265
G2 X163.68 Y128.324 I49.848 J-31.917 E.10796
G2 X166.202 Y131.082 I16.837 J-12.865 E.12414
G3 X167.71 Y132.568 I-14.861 J16.595 E.07026
G3 X168.516 Y134.078 I-4.076 J3.144 E.05705
G1 X168.658 Y134.455 E.01335
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.788 E1.86598
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.135 J2.086 E.05195
G3 X88.163 Y131.747 I2.988 J2.222 E.03456
G2 X90.863 Y129.416 I-14.317 J-19.314 E.10971
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.338 J6.055 E.05347
G3 X94.828 Y123.939 I1.545 J1.357 E.0275
G2 X97.331 Y122.678 I-21.516 J-45.797 E.08611
G2 X100.735 Y120.04 I-8.413 J-14.373 E.13271
G3 X102.512 Y118.382 I16.286 J15.67 E.07471
G3 X103.843 Y117.698 I2.998 J4.197 E.04617
G2 X106.325 Y116.856 I-157.127 J-467.373 E.08053
G2 X110.161 Y114.94 I-7.083 J-18.975 E.13198
G3 X112.029 Y113.845 I11.12 J16.827 E.06658
G3 X113.834 Y113.423 I2.199 J5.333 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.541 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.518 J20.695 E.06952
G3 X123.486 Y111.206 I.614 J2.41 E.03527
G2 X125.869 Y111.616 I39.601 J-222.8 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.31 J24.939 E.0667
G3 X133.155 Y111.151 I.226 J2.505 E.00935
G3 X134.361 Y111.499 I-.479 J3.925 E.03873
G2 X137.615 Y112.726 I11.153 J-24.643 E.10695
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.534 J22.53 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.05721
G2 X148.18 Y116.248 I17.23 J-26.293 E.11809
G2 X151.783 Y117.578 I12.596 J-28.587 E.11808
G3 X153.54 Y118.449 I-1.58 J5.393 E.06055
G3 X155.042 Y119.856 I-14.108 J16.565 E.06326
G2 X159.105 Y123.012 I14.388 J-14.329 E.15851
G3 X161.075 Y124.229 I-11.661 J21.072 E.07119
G3 X162.173 Y125.409 I-2.919 J3.817 E.04975
G2 X163.993 Y128.088 I49.741 J-31.844 E.09952
G2 X166.471 Y130.796 I16.517 J-12.622 E.11296
G3 X168.013 Y132.318 I-14.982 J16.725 E.06659
G3 X168.881 Y133.936 I-4.392 J3.4 E.05669
G1 X169.137 Y134.615 E.02228
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X147.22 Y137.207 Z1.2 F36000
G1 X145.8 Y135.493 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X144.466 Y134.559 I-9.576 J12.26 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.357 Y119.262 I24.442 J-30.413 E.15054
G2 X152.621 Y118.728 I-2.721 J2.972 E.03021
G1 X139.447 Y131.902 E.61802
G1 X139.666 Y131.992 E.00784
G1 X130.54 Y122.867 E.42809
G3 X125.419 Y122.903 I-2.556 J.675 E.31963
G1 X116.349 Y131.973 E.4255
G1 X116.539 Y131.894 E.00685
G1 X103.363 Y118.717 E.61815
G2 X102.704 Y119.18 I1.456 J2.774 E.02677
G3 X99.258 Y122.288 I-22.947 J-21.971 E.15409
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.885 J12.762 E.05403
G1 X120.865 Y130.479 F36000
G1 F15476.087
G3 X122.456 Y130.135 I4.073 J15.003 E.05402
G1 X108.861 Y116.54 E.63779
G3 X108.636 Y116.657 I-1.537 J-2.658 E.00843
G1 X89.965 Y135.329 E.87592
G1 X88.609 Y134.427 E.05401
G1 X100.936 Y131.991 F36000
G1 F15476.087
G2 X100.293 Y132.677 I4.341 J4.717 E.03123
G1 X94.573 Y138.397 E.26832
G1 X99.181 Y141.464 E.18364
G1 X128.138 Y112.507 E1.35844
G3 X127.857 Y112.508 I-.148 J-2.692 E.00933
G1 X156.88 Y141.53 E1.3615
G1 X161.572 Y138.547 E.18446
G1 X155.597 Y132.571 E.28033
G2 X155.136 Y132.07 I-2.46 J1.797 E.02264
G1 X160.005 Y124.422 F36000
G1 F15476.087
G3 X161.265 Y125.436 I-1.768 J3.484 E.05403
G1 X154.844 Y131.857 E.30121
G3 X154.973 Y131.948 I-.25 J.492 E.00524
G1 X135.998 Y112.973 E.89013
G1 X135.538 Y112.784 E.01652
G1 X127.325 Y120.996 E.38526
G3 X128.677 Y121.004 I.656 J3.467 E.04512
G1 X120.456 Y112.783 E.38567
G1 X120.021 Y112.948 E.01543
G1 X101.1 Y131.87 E.88765
G1 X101.141 Y131.847 E.00156
G1 X94.506 Y125.212 E.31127
G3 X91.467 Y129.849 I-19.921 J-9.741 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.064 J18.209 E.18071
G1 X104.785 Y135.492 E.11572
; WIPE_START
G1 X106.199 Y136.906 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X113.65 Y135.252 Z1.2 F36000
G1 X135.125 Y130.484 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G2 X133.534 Y130.139 I-4.085 J15.003 E.05402
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.763 J-3.098 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02426
G1 X168.093 Y133.96 E.0568
G2 X167.031 Y132.345 I-4.207 J1.608 E.06465
G3 X164.508 Y129.869 I23.141 J-26.102 E.11729
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.039 J18.156 E.18072
G1 X151.192 Y135.51 E.11551
G1 X143.449 Y114.447 F36000
G1 F15476.087
G2 X141.856 Y114.141 I-2.393 J8.171 E.0539
G1 X126.34 Y129.657 E.72787
G3 X129.657 Y129.659 I1.643 J20.583 E.11013
G1 X114.137 Y114.139 E.72808
G2 X112.541 Y114.437 I.889 J9.196 E.05391
; CHANGE_LAYER
; Z_HEIGHT: 1
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X112.968 Y114.304 E-.16972
G1 X114.137 Y114.139 E-.44862
G1 X114.4 Y114.403 E-.14166
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
G1 X127.006 Y121.477
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.03 Y121.472 E.0008
G3 X127.897 Y121.263 I.961 J2.091 E.02977
G3 X129.229 Y121.623 I.075 J2.37 E.04644
G3 X126.742 Y121.63 I-1.238 J1.94 E.39244
G1 X126.954 Y121.507 E.00812
G1 X127.228 Y121.808 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.447 Y121.733 E.0071
G3 X127.925 Y121.654 I.544 J1.829 E.01493
G3 X128.777 Y121.823 I.074 J1.865 E.02694
G3 X127.175 Y121.836 I-.786 J1.738 E.31755
; WIPE_START
M204 S10000
G1 X127.447 Y121.733 E-.11037
G1 X127.712 Y121.67 E-.10345
G1 X127.925 Y121.654 E-.0813
G1 X128.255 Y121.67 E-.1257
G1 X128.522 Y121.728 E-.10358
G1 X128.777 Y121.823 E-.10356
G1 X129.016 Y121.954 E-.1036
G1 X129.076 Y121.998 E-.02843
; WIPE_END
G1 E-.04 F1800
G1 X122.196 Y125.303 Z1.4 F36000
G1 X100.773 Y135.595 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.594 Y135.347 E.01011
G3 X102.441 Y131.807 I1.933 J-1.243 E.16045
G3 X103.697 Y132.125 I.078 J2.33 E.04354
G3 X100.815 Y135.637 I-1.169 J1.979 E.26295
G1 X101.073 Y135.341 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X100.927 Y135.134 E.00779
G3 X102.469 Y132.199 I1.608 J-1.028 E.12345
G3 X103.321 Y132.367 I.074 J1.864 E.02694
G3 X101.116 Y135.382 I-.786 J1.739 E.20849
; WIPE_START
M204 S10000
G1 X100.927 Y135.134 E-.11859
G1 X100.79 Y134.899 E-.10342
G1 X100.694 Y134.643 E-.10356
G1 X100.637 Y134.377 E-.10358
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10357
G1 X100.713 Y133.517 E-.02008
; WIPE_END
G1 E-.04 F1800
G1 X108.342 Y133.297 Z1.4 F36000
G1 X152.462 Y132.021 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.485 Y132.016 E.0008
G3 X153.353 Y131.807 I.961 J2.091 E.02978
G3 X154.685 Y132.167 I.075 J2.371 E.04643
G3 X152.198 Y132.174 I-1.238 J1.94 E.39244
G1 X152.41 Y132.051 E.00812
G1 X152.688 Y132.351 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.902 Y132.277 E.00699
G3 X153.381 Y132.199 I.544 J1.828 E.01493
G3 X154.233 Y132.367 I.074 J1.865 E.02694
G3 X152.634 Y132.379 I-.786 J1.738 E.31756
; WIPE_START
M204 S10000
G1 X152.902 Y132.277 E-.10906
G1 X153.167 Y132.214 E-.10345
G1 X153.381 Y132.199 E-.0813
G1 X153.711 Y132.214 E-.1257
G1 X153.978 Y132.272 E-.10359
G1 X154.233 Y132.367 E-.10357
G1 X154.472 Y132.498 E-.1036
G1 X154.535 Y132.545 E-.02973
; WIPE_END
G1 E-.04 F1800
G1 X153.727 Y140.134 Z1.4 F36000
G1 X153.292 Y144.224 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.388 J1.747 E.04339
G3 X88.409 Y132.052 I2.737 J2.129 E.0325
G2 X91.148 Y129.685 I-14.52 J-19.572 E.12021
G2 X93.594 Y126.161 I-11.286 J-10.443 E.14278
M73 P54 R8
G3 X94.42 Y124.708 I12.321 J6.047 E.05547
G3 X95.012 Y124.286 I1.249 J1.126 E.02432
G2 X97.525 Y123.019 I-21.468 J-45.696 E.09337
G2 X101.007 Y120.323 I-8.607 J-14.711 E.14647
G3 X102.746 Y118.696 I16.204 J15.586 E.07904
G3 X103.976 Y118.067 I2.751 J3.858 E.046
G2 X107.047 Y116.997 I-16.527 J-52.391 E.10789
G2 X110.366 Y115.274 I-7.762 J-19.009 E.12423
G3 X112.192 Y114.201 I10.96 J16.567 E.07028
G3 X113.876 Y113.812 I2.028 J4.939 E.05757
G2 X117.401 Y113.355 I-2.348 J-31.921 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10417
G3 X122.452 Y111.606 I9.4 J20.396 E.07348
G3 X123.431 Y111.594 I.513 J2.044 E.03277
G2 X125.813 Y112.005 I38.083 J-213.997 E.08021
G2 X130.777 Y111.907 I2.186 J-15.166 E.16542
G3 X132.883 Y111.551 I5.293 J24.841 E.07086
G3 X133.138 Y111.543 I.193 J2.109 E.0085
G3 X134.063 Y111.801 I-.423 J3.296 E.03194
G2 X136.158 Y112.662 I45.411 J-107.507 E.07514
G2 X140.702 Y113.674 I6.096 J-16.669 E.15488
G3 X143.068 Y113.962 I-1.514 J22.324 E.07912
G3 X144.643 Y114.679 I-1.436 J5.238 E.05764
G2 X148.015 Y116.604 I17.392 J-26.555 E.12888
G2 X151.657 Y117.949 I12.732 J-28.868 E.12887
G3 X153.297 Y118.756 I-1.46 J5.034 E.06094
G3 X154.769 Y120.137 I-13.932 J16.328 E.06699
G2 X158.902 Y123.348 I14.663 J-14.612 E.17408
G3 X160.841 Y124.544 I-11.509 J20.816 E.07559
G3 X161.85 Y125.632 I-2.665 J3.484 E.04948
G2 X163.68 Y128.324 I49.86 J-31.926 E.10797
G2 X166.202 Y131.082 I16.839 J-12.867 E.12414
G3 X167.71 Y132.568 I-14.857 J16.591 E.07025
G3 X168.522 Y134.093 I-4.097 J3.158 E.05759
G1 X168.658 Y134.455 E.01281
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.135 J2.086 E.05195
G3 X88.163 Y131.747 I2.988 J2.223 E.03456
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10971
G2 X93.249 Y125.974 I-11.005 J-10.177 E.1291
G3 X94.112 Y124.464 I12.338 J6.055 E.05348
G3 X94.828 Y123.94 I1.545 J1.356 E.02748
G2 X97.331 Y122.678 I-21.542 J-45.849 E.08613
G2 X100.735 Y120.04 I-8.414 J-14.373 E.1327
G3 X102.512 Y118.382 I16.286 J15.669 E.07472
G3 X103.844 Y117.698 I2.998 J4.196 E.04618
G2 X106.325 Y116.856 I-156.943 J-466.837 E.08052
G2 X110.161 Y114.94 I-7.082 J-18.974 E.13198
G3 X112.029 Y113.845 I11.113 J16.815 E.06659
G3 X113.833 Y113.423 I2.192 J5.303 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.543 E.10818
G2 X120.25 Y112.069 I-3.378 J-16.161 E.09424
G3 X122.349 Y111.227 I9.359 J20.3 E.06953
G3 X123.486 Y111.206 I.613 J2.411 E.03526
G2 X125.869 Y111.616 I39.722 J-223.499 E.07429
G2 X130.711 Y111.521 I2.13 J-14.776 E.14949
G3 X132.851 Y111.16 I5.313 J24.953 E.06669
G3 X133.153 Y111.151 I.226 J2.499 E.00931
G3 X134.208 Y111.437 I-.429 J3.667 E.03369
G2 X136.296 Y112.295 I45.865 J-108.602 E.06937
G2 X140.743 Y113.284 I5.956 J-16.295 E.14039
G3 X143.156 Y113.579 I-1.533 J22.522 E.07474
G3 X144.845 Y114.343 I-1.517 J5.604 E.05721
G2 X148.18 Y116.248 I17.231 J-26.294 E.11809
G2 X151.784 Y117.578 I12.597 J-28.59 E.1181
G3 X153.54 Y118.449 I-1.58 J5.392 E.06053
G3 X155.042 Y119.856 I-14.141 J16.6 E.06327
G2 X159.105 Y123.012 I14.388 J-14.329 E.1585
G3 X161.075 Y124.23 I-11.652 J21.057 E.0712
G3 X162.172 Y125.409 I-2.911 J3.809 E.04974
G2 X163.993 Y128.088 I49.753 J-31.852 E.09952
G2 X166.471 Y130.796 I16.518 J-12.623 E.11296
G3 X168.013 Y132.318 I-14.975 J16.718 E.06659
G3 X168.887 Y133.951 I-4.412 J3.413 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X151.192 Y135.51 Z1.4 F36000
G1 Z1
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X148.729 Y137.972 E.11551
G3 X152.298 Y142.079 I-21.47 J22.263 E.18072
G1 X164.508 Y129.869 E.57279
G3 X167.553 Y132.932 I-261.721 J263.253 E.14326
G3 X168.093 Y133.96 I-8.416 J5.069 E.03856
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.498 J-3.225 E.00975
G1 X133.534 Y130.139 E.63753
G3 X135.125 Y130.484 I-2.495 J15.348 E.05402
; WIPE_START
G1 X133.534 Y130.139 E-.61855
G1 X133.797 Y129.876 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X141.39 Y130.656 Z1.4 F36000
G1 X155.136 Y132.07 Z1.4
G1 Z1
G1 E.8 F1800
G1 F15476.087
G3 X155.597 Y132.571 I-1.998 J2.297 E.02265
G1 X161.572 Y138.547 E.28033
G1 X156.88 Y141.53 E.18446
G1 X127.857 Y112.508 E1.3615
G2 X128.138 Y112.507 I.133 J-2.693 E.00933
G1 X99.181 Y141.464 E1.35844
G1 X100.537 Y142.367 E.05401
G1 X104.785 Y135.492 F36000
G1 F15476.087
G1 X107.252 Y137.958 E.11572
G2 X103.68 Y142.062 I21.493 J22.314 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.881 J-14.378 E.18439
G1 X101.141 Y131.847 E.31127
G1 X101.1 Y131.87 E.00156
G1 X120.021 Y112.948 E.88766
G1 X120.456 Y112.783 E.01543
G1 X128.677 Y121.004 E.38567
G2 X127.325 Y120.996 I-.696 J3.456 E.04512
G1 X135.538 Y112.784 E.38525
G1 X135.998 Y112.973 E.01653
G1 X154.973 Y131.948 E.89013
G2 X154.844 Y131.857 I-.379 J.403 E.00524
G1 X161.265 Y125.437 E.3012
G2 X160.005 Y124.422 I-3.031 J2.473 E.05403
; WIPE_START
G1 X160.782 Y124.94 E-.35472
G1 X161.265 Y125.437 E-.26314
G1 X161 Y125.701 E-.14214
; WIPE_END
G1 E-.04 F1800
G1 X153.471 Y126.951 Z1.4 F36000
G1 X112.9 Y133.689 Z1.4
G1 Z1
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.5 J13.619 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.18 I-19.496 J-25.075 E.15409
G3 X103.363 Y118.717 I2.114 J2.311 E.02677
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X125.419 Y122.903 E.4255
G2 X130.54 Y122.867 I2.565 J.64 E.31963
G1 X139.666 Y131.992 E.42809
G1 X139.447 Y131.902 E.00784
G1 X152.621 Y118.728 E.61802
G3 X153.357 Y119.263 I-1.984 J3.504 E.03025
G2 X156.721 Y122.304 I27.782 J-27.344 E.15051
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.242 J13.194 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X138.234 Y130.288 Z1.4 F36000
G1 X112.541 Y114.437 Z1.4
G1 Z1
G1 E.8 F1800
G1 F15476.087
G3 X114.137 Y114.139 I2.485 J8.901 E.05391
G1 X129.657 Y129.659 E.72808
G2 X126.34 Y129.657 I-1.673 J20.581 E.11013
G1 X141.856 Y114.141 E.72787
G3 X143.449 Y114.447 I-.8 J8.48 E.0539
G1 X100.936 Y131.991 F36000
G1 F15476.087
G2 X100.293 Y132.677 I4.34 J4.717 E.03123
G1 X94.573 Y138.397 E.26832
G1 X89.965 Y135.329 E.18364
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.314 J-2.777 E.00843
G1 X122.456 Y130.135 E.63779
G2 X120.865 Y130.479 I2.482 J15.347 E.05402
; CHANGE_LAYER
; Z_HEIGHT: 1.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X122.456 Y130.135 E-.61855
G1 X122.193 Y129.872 E-.14145
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
G1 X127.005 Y121.477
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.03 Y121.472 E.00082
G3 X127.887 Y121.264 I.962 J2.09 E.02945
G3 X129.229 Y121.623 I.086 J2.365 E.04676
G3 X126.743 Y121.63 I-1.237 J1.94 E.39242
G1 X126.954 Y121.507 E.0081
G1 X127.222 Y121.811 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.447 Y121.733 E.00732
G3 X127.915 Y121.655 I.545 J1.828 E.01463
G3 X128.777 Y121.823 I.085 J1.86 E.02724
G3 X127.169 Y121.84 I-.786 J1.738 E.31723
; WIPE_START
M204 S10000
G1 X127.447 Y121.733 E-.11305
G1 X127.712 Y121.67 E-.10344
G1 X127.915 Y121.655 E-.0776
G1 X128.255 Y121.67 E-.12938
G1 X128.522 Y121.728 E-.10357
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.953 E-.10358
G1 X129.071 Y121.994 E-.0258
; WIPE_END
G1 E-.04 F1800
G1 X122.191 Y125.3 Z1.6 F36000
G1 X100.772 Y135.594 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.598 Y135.345 E.01009
G3 X102.431 Y131.808 I1.937 J-1.239 E.15979
G3 X103.773 Y132.167 I.086 J2.365 E.04675
G3 X100.817 Y135.634 I-1.237 J1.939 E.26074
G1 X101.075 Y135.344 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X100.927 Y135.133 E.00789
G3 X102.459 Y132.199 I1.608 J-1.027 E.1231
G3 X103.321 Y132.367 I.085 J1.86 E.02724
G3 X101.118 Y135.384 I-.786 J1.739 E.20842
; WIPE_START
M204 S10000
G1 X100.927 Y135.133 E-.11961
G1 X100.79 Y134.899 E-.10344
G1 X100.694 Y134.643 E-.10356
G1 X100.637 Y134.377 E-.10359
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10359
G1 X100.712 Y133.52 E-.01904
; WIPE_END
G1 E-.04 F1800
G1 X108.341 Y133.296 Z1.6 F36000
G1 X152.505 Y132.001 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.792 Y131.901 E.01009
G3 X153.343 Y131.808 I.655 J2.206 E.01858
G3 X154.685 Y132.167 I.086 J2.365 E.04675
G3 X152.453 Y132.031 I-1.238 J1.94 E.40212
G1 X152.68 Y132.354 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.903 Y132.277 E.00723
G3 X153.371 Y132.199 I.545 J1.828 E.01463
G3 X154.233 Y132.367 I.085 J1.861 E.02724
G3 X152.628 Y132.383 I-.786 J1.738 E.31732
; WIPE_START
M204 S10000
G1 X152.903 Y132.277 E-.11194
G1 X153.167 Y132.214 E-.10344
G1 X153.371 Y132.199 E-.07762
G1 X153.711 Y132.214 E-.12936
G1 X153.978 Y132.272 E-.10359
G1 X154.233 Y132.367 E-.10357
G1 X154.472 Y132.498 E-.10359
G1 X154.529 Y132.54 E-.02689
; WIPE_END
G1 E-.04 F1800
G1 X153.725 Y140.13 Z1.6 F36000
G1 X153.292 Y144.224 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.391 J1.748 E.04339
G3 X88.408 Y132.053 I2.737 J2.129 E.03248
G2 X91.148 Y129.685 I-14.521 J-19.573 E.12022
G2 X93.594 Y126.16 I-11.287 J-10.443 E.14279
G3 X94.42 Y124.708 I12.314 J6.043 E.05546
G3 X95.013 Y124.286 I1.249 J1.126 E.02433
G2 X97.525 Y123.019 I-21.482 J-45.724 E.09336
G2 X101.007 Y120.323 I-8.607 J-14.712 E.14648
G3 X102.746 Y118.696 I16.199 J15.581 E.07902
G3 X103.976 Y118.067 I2.749 J3.855 E.04598
G2 X107.047 Y116.997 I-16.544 J-52.44 E.10791
G2 X110.366 Y115.274 I-7.762 J-19.009 E.12423
G3 X112.192 Y114.201 I10.969 J16.583 E.07027
G3 X113.876 Y113.812 I2.035 J4.97 E.05758
G2 X117.401 Y113.355 I-2.348 J-31.919 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.568 E.10417
G3 X122.452 Y111.606 I9.398 J20.39 E.07348
G3 X123.431 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I37.884 J-212.85 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16542
G3 X132.883 Y111.551 I5.293 J24.842 E.07086
G3 X133.137 Y111.543 I.193 J2.109 E.00845
G3 X134.227 Y111.868 I-.476 J3.587 E.03789
G2 X137.511 Y113.104 I11.111 J-24.528 E.11647
G2 X140.701 Y113.674 I5.146 J-19.604 E.10762
G3 X143.068 Y113.962 I-1.514 J22.331 E.07914
G3 X144.643 Y114.679 I-1.437 J5.239 E.05764
G2 X148.015 Y116.604 I17.393 J-26.557 E.12887
G2 X151.656 Y117.949 I12.727 J-28.854 E.12886
G3 X153.297 Y118.757 I-1.46 J5.034 E.06097
G3 X154.769 Y120.137 I-13.758 J16.142 E.06697
G2 X158.902 Y123.348 I14.664 J-14.613 E.17409
G3 X161.003 Y124.671 I-9.765 J17.838 E.08241
G3 X161.85 Y125.633 I-2.916 J3.422 E.04267
G2 X163.68 Y128.324 I49.842 J-31.913 E.10796
G2 X166.202 Y131.082 I16.837 J-12.865 E.12414
G3 X167.71 Y132.568 I-14.864 J16.598 E.07026
G3 X168.522 Y134.093 I-4.097 J3.157 E.05759
G1 X168.658 Y134.455 E.01281
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.136 J2.086 E.05195
G3 X88.162 Y131.747 I2.989 J2.224 E.03454
G2 X90.863 Y129.416 I-14.315 J-19.313 E.10972
G2 X93.249 Y125.974 I-11.005 J-10.177 E.12911
G3 X94.112 Y124.465 I12.337 J6.054 E.05347
G3 X94.828 Y123.94 I1.546 J1.357 E.0275
G2 X97.331 Y122.678 I-21.535 J-45.835 E.08612
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.512 Y118.382 I16.282 J15.665 E.07471
G3 X103.843 Y117.698 I2.997 J4.195 E.04617
G2 X106.325 Y116.856 I-156.798 J-466.401 E.08053
G2 X110.161 Y114.94 I-7.082 J-18.974 E.13198
G3 X112.029 Y113.845 I11.124 J16.833 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.546 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.161 E.09424
G3 X122.349 Y111.227 I9.359 J20.3 E.06953
G3 X123.486 Y111.206 I.613 J2.411 E.03526
G2 X125.869 Y111.616 I39.613 J-222.868 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.313 J24.955 E.06669
G3 X133.152 Y111.151 I.225 J2.496 E.00926
G3 X134.376 Y111.505 I-.476 J3.938 E.03931
G2 X137.615 Y112.726 I10.992 J-24.245 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.521 E.07474
G3 X144.845 Y114.343 I-1.517 J5.604 E.0572
G2 X148.18 Y116.248 I17.231 J-26.294 E.11809
G2 X151.783 Y117.578 I12.592 J-28.578 E.11808
G3 X153.54 Y118.449 I-1.579 J5.392 E.06056
G3 X155.042 Y119.856 I-13.962 J16.408 E.06326
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.229 I-11.666 J21.08 E.07119
G3 X162.172 Y125.409 I-2.925 J3.822 E.04974
G2 X163.993 Y128.088 I49.749 J-31.849 E.09953
G2 X166.471 Y130.796 I16.518 J-12.623 E.11296
G3 X168.013 Y132.318 I-14.976 J16.719 E.06659
G3 X168.887 Y133.951 I-4.412 J3.413 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X147.22 Y137.207 Z1.6 F36000
G1 X145.8 Y135.493 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X144.466 Y134.559 I-9.576 J12.26 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.357 Y119.263 I24.414 J-30.381 E.15053
G2 X152.621 Y118.728 I-2.722 J2.972 E.03023
G1 X139.447 Y131.902 E.61802
G1 X139.666 Y131.992 E.00784
G1 X130.54 Y122.867 E.42809
G3 X125.419 Y122.903 I-2.556 J.675 E.31961
G1 X116.349 Y131.973 E.4255
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.45 J2.764 E.02677
G3 X99.258 Y122.288 I-22.944 J-21.968 E.15409
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.885 J12.762 E.05403
G1 X120.865 Y130.479 F36000
G1 F15476.087
G3 X122.456 Y130.135 I4.073 J15.003 E.05402
G1 X108.861 Y116.54 E.63778
G3 X108.636 Y116.657 I-1.535 J-2.654 E.00843
G1 X89.965 Y135.329 E.87591
G1 X94.573 Y138.397 E.18364
G1 X100.293 Y132.677 E.26832
G3 X100.901 Y132.017 I5.681 J4.63 E.02981
; WIPE_START
G1 X100.523 Y132.368 E-.19617
G1 X100.293 Y132.677 E-.14647
M73 P55 R8
G1 X99.516 Y133.454 E-.41736
; WIPE_END
G1 E-.04 F1800
G1 X100.384 Y141.036 Z1.6 F36000
G1 X100.537 Y142.367 Z1.6
G1 Z1.2
G1 E.8 F1800
G1 F15476.087
G1 X99.181 Y141.464 E.05401
G1 X128.138 Y112.507 E1.35844
G3 X127.857 Y112.508 I-.148 J-2.689 E.00933
G1 X156.88 Y141.53 E1.36151
G1 X161.572 Y138.547 E.18446
G1 X155.597 Y132.571 E.28033
G2 X155.136 Y132.07 I-2.458 J1.795 E.02264
G1 X160.005 Y124.422 F36000
G1 F15476.087
G3 X161.265 Y125.436 I-1.768 J3.483 E.05403
G1 X154.844 Y131.857 E.30121
G3 X154.973 Y131.948 I-.25 J.493 E.00524
G1 X135.998 Y112.973 E.89013
G1 X135.538 Y112.784 E.01652
G1 X127.325 Y120.996 E.38526
G3 X128.677 Y121.004 I.656 J3.461 E.04512
G1 X120.456 Y112.783 E.38567
G1 X120.021 Y112.948 E.01543
G1 X101.068 Y131.901 E.88912
G1 X101.148 Y131.854 E.00306
G1 X94.506 Y125.212 E.3116
G3 X91.467 Y129.849 I-19.922 J-9.742 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.065 J18.21 E.18071
G1 X104.785 Y135.492 E.11572
; WIPE_START
G1 X106.199 Y136.906 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X113.65 Y135.252 Z1.6 F36000
G1 X135.125 Y130.484 Z1.6
G1 Z1.2
G1 E.8 F1800
G1 F15476.087
G2 X133.534 Y130.139 I-4.085 J15.003 E.05402
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.76 J-3.093 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02425
G1 X168.093 Y133.96 E.0568
G2 X167.03 Y132.344 I-4.207 J1.608 E.06465
G3 X164.508 Y129.869 I23.158 J-26.118 E.11728
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.039 J18.156 E.18072
G1 X151.192 Y135.51 E.11551
G1 X143.449 Y114.447 F36000
G1 F15476.087
G2 X141.856 Y114.141 I-2.393 J8.173 E.0539
G1 X126.34 Y129.657 E.72787
G3 X129.657 Y129.659 I1.643 J20.583 E.11013
G1 X114.137 Y114.139 E.72808
G2 X112.541 Y114.437 I.89 J9.201 E.05391
; CHANGE_LAYER
; Z_HEIGHT: 1.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X112.968 Y114.304 E-.16971
G1 X114.137 Y114.139 E-.44864
G1 X114.4 Y114.403 E-.14166
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
G1 X127.005 Y121.477
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.03 Y121.473 E.00083
G3 X127.878 Y121.265 I.962 J2.09 E.02913
G3 X129.229 Y121.623 I.097 J2.361 E.04708
G3 X126.743 Y121.63 I-1.237 J1.94 E.3924
G1 X126.953 Y121.507 E.00809
G1 X127.214 Y121.814 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.447 Y121.733 E.00756
G3 X127.906 Y121.656 I.545 J1.829 E.01433
G3 X128.777 Y121.823 I.096 J1.857 E.02753
G3 X127.163 Y121.843 I-.785 J1.739 E.31717
; WIPE_START
M204 S10000
G1 X127.447 Y121.733 E-.11582
G1 X127.712 Y121.67 E-.10343
G1 X127.906 Y121.656 E-.07392
G1 X128.255 Y121.67 E-.13304
G1 X128.522 Y121.728 E-.10357
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.953 E-.1036
G1 X129.065 Y121.99 E-.02305
; WIPE_END
G1 E-.04 F1800
G1 X122.186 Y125.297 Z1.8 F36000
G1 X100.772 Y135.594 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.597 Y135.345 E.01009
G3 X102.422 Y131.809 I1.939 J-1.239 E.15948
G3 X103.773 Y132.167 I.097 J2.361 E.04707
G3 X100.816 Y135.635 I-1.237 J1.94 E.26088
G1 X101.077 Y135.347 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X100.928 Y135.133 E.008
G3 X102.45 Y132.2 I1.608 J-1.027 E.12276
G3 X103.321 Y132.367 I.096 J1.857 E.02753
G3 X101.12 Y135.385 I-.785 J1.739 E.20835
; WIPE_START
M204 S10000
G1 X100.928 Y135.133 E-.12064
G1 X100.79 Y134.899 E-.10341
G1 X100.694 Y134.643 E-.10357
G1 X100.637 Y134.377 E-.10357
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.1036
G1 X100.694 Y133.567 E-.10357
G1 X100.711 Y133.522 E-.01804
; WIPE_END
G1 E-.04 F1800
G1 X108.34 Y133.301 Z1.8 F36000
G1 X152.461 Y132.021 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.486 Y132.017 E.00083
G3 X153.333 Y131.809 I.962 J2.09 E.02913
G3 X154.685 Y132.167 I.097 J2.36 E.04707
G3 X152.199 Y132.174 I-1.237 J1.94 E.3924
G1 X152.409 Y132.051 E.00809
G1 X152.673 Y132.357 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.903 Y132.278 E.00748
G3 X153.361 Y132.2 I.545 J1.828 E.01433
G3 X154.233 Y132.367 I.096 J1.857 E.02753
G3 X152.621 Y132.387 I-.785 J1.738 E.31707
; WIPE_START
M204 S10000
G1 X152.903 Y132.278 E-.11488
G1 X153.167 Y132.214 E-.10343
G1 X153.361 Y132.2 E-.07393
G1 X153.711 Y132.214 E-.13303
G1 X153.978 Y132.272 E-.10357
G1 X154.233 Y132.367 E-.10358
G1 X154.472 Y132.498 E-.10359
G1 X154.523 Y132.535 E-.02399
; WIPE_END
G1 E-.04 F1800
G1 X153.723 Y140.126 Z1.8 F36000
G1 X153.292 Y144.224 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98338
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.384 J1.746 E.04339
G3 X88.408 Y132.053 I2.737 J2.129 E.03249
G2 X91.148 Y129.685 I-14.521 J-19.573 E.12021
G2 X93.594 Y126.16 I-11.287 J-10.443 E.14279
G3 X94.42 Y124.708 I12.31 J6.041 E.05547
G3 X95.013 Y124.286 I1.25 J1.128 E.02433
G2 X97.525 Y123.019 I-21.463 J-45.685 E.09335
G2 X101.007 Y120.323 I-8.607 J-14.711 E.14647
G3 X102.746 Y118.696 I16.202 J15.584 E.07903
G3 X103.976 Y118.067 I2.749 J3.855 E.046
G2 X106.463 Y117.223 I-147.684 J-439.457 E.08711
G2 X110.366 Y115.274 I-7.223 J-19.346 E.145
G3 X112.192 Y114.201 I10.959 J16.566 E.07027
G3 X113.876 Y113.812 I2.035 J4.97 E.05757
G2 X117.401 Y113.355 I-2.348 J-31.918 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10417
G3 X122.451 Y111.606 I9.4 J20.397 E.07347
G3 X123.431 Y111.594 I.513 J2.043 E.03278
G2 X125.813 Y112.005 I37.876 J-212.804 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16542
G3 X132.882 Y111.551 I5.032 J23.301 E.07085
G3 X133.135 Y111.543 I.193 J2.104 E.0084
G3 X134.2 Y111.857 I-.46 J3.522 E.03697
G2 X137.511 Y113.104 I11.252 J-24.846 E.11745
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.068 Y113.962 I-1.514 J22.334 E.07913
G3 X144.643 Y114.679 I-1.436 J5.238 E.05764
G2 X148.015 Y116.604 I17.392 J-26.555 E.12887
G2 X151.657 Y117.949 I12.728 J-28.856 E.12887
G3 X153.297 Y118.757 I-1.46 J5.033 E.06096
G3 X154.769 Y120.137 I-13.759 J16.143 E.06697
G2 X158.902 Y123.348 I14.663 J-14.613 E.17409
G3 X160.841 Y124.544 I-11.515 J20.827 E.07559
G3 X161.85 Y125.632 I-2.679 J3.497 E.04947
G2 X163.68 Y128.324 I49.885 J-31.943 E.10797
G2 X166.202 Y131.082 I16.836 J-12.864 E.12414
G3 X167.71 Y132.567 I-14.872 J16.606 E.07024
G3 X168.522 Y134.093 I-4.119 J3.17 E.0576
G1 X168.658 Y134.455 E.01281
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.793 E1.86587
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.131 J2.085 E.05195
G3 X88.163 Y131.747 I2.99 J2.225 E.03455
G2 X90.863 Y129.416 I-14.316 J-19.313 E.10971
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.332 J6.052 E.05348
G3 X94.829 Y123.939 I1.546 J1.359 E.0275
G2 X97.331 Y122.678 I-21.515 J-45.795 E.08611
G2 X100.735 Y120.04 I-8.414 J-14.373 E.1327
G3 X102.512 Y118.382 I16.287 J15.67 E.07471
G3 X103.844 Y117.698 I2.997 J4.194 E.04618
G2 X106.325 Y116.856 I-156.852 J-466.563 E.08052
G2 X110.161 Y114.94 I-7.083 J-18.974 E.13198
G3 X112.029 Y113.845 I11.117 J16.821 E.06659
G3 X113.833 Y113.423 I2.199 J5.334 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.545 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.358 J20.298 E.06953
G3 X123.486 Y111.206 I.613 J2.411 E.03527
G2 X125.869 Y111.616 I39.604 J-222.817 E.07429
G2 X130.711 Y111.521 I2.13 J-14.776 E.14949
G3 X132.851 Y111.16 I5.067 J23.493 E.06669
G3 X133.15 Y111.151 I.225 J2.492 E.00921
G3 X134.348 Y111.494 I-.462 J3.879 E.03846
G2 X137.615 Y112.726 I11.133 J-24.564 E.10736
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.522 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.0572
G2 X148.18 Y116.248 I17.231 J-26.295 E.11809
G2 X151.783 Y117.578 I12.593 J-28.58 E.11808
G3 X153.54 Y118.449 I-1.579 J5.392 E.06056
G3 X155.042 Y119.856 I-13.966 J16.412 E.06326
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.23 I-11.651 J21.056 E.0712
G3 X162.172 Y125.409 I-2.927 J3.824 E.04973
G2 X163.993 Y128.088 I49.777 J-31.868 E.09954
G2 X166.471 Y130.796 I16.517 J-12.621 E.11296
G3 X168.012 Y132.318 I-14.984 J16.727 E.06657
G3 X168.887 Y133.951 I-4.435 J3.426 E.05721
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X151.192 Y135.51 Z1.8 F36000
G1 Z1.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X148.729 Y137.972 E.11551
G3 X152.298 Y142.079 I-21.47 J22.263 E.18072
G1 X164.508 Y129.869 E.57279
G3 X167.553 Y132.932 I-262.573 J264.102 E.14327
G3 X168.093 Y133.96 I-8.841 J5.291 E.03855
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.498 J-3.224 E.00975
G1 X133.534 Y130.139 E.63753
G3 X135.125 Y130.484 I-2.495 J15.348 E.05402
; WIPE_START
G1 X133.534 Y130.139 E-.61855
G1 X133.797 Y129.876 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X141.39 Y130.656 Z1.8 F36000
G1 X155.136 Y132.07 Z1.8
G1 Z1.4
G1 E.8 F1800
G1 F15476.087
G3 X155.597 Y132.571 I-1.998 J2.297 E.02264
G1 X161.572 Y138.547 E.28033
G1 X156.88 Y141.53 E.18446
G1 X127.857 Y112.508 E1.36151
G2 X128.138 Y112.507 I.133 J-2.689 E.00933
G1 X99.181 Y141.464 E1.35844
G1 X94.573 Y138.397 E.18364
G1 X100.293 Y132.677 E.26832
G3 X100.936 Y131.991 I4.982 J4.03 E.03123
; WIPE_START
G1 X100.523 Y132.368 E-.21256
G1 X100.293 Y132.677 E-.14645
G1 X99.546 Y133.423 E-.40099
; WIPE_END
G1 E-.04 F1800
G1 X104.785 Y135.492 Z1.8 F36000
G1 Z1.4
G1 E.8 F1800
G1 F15476.087
G1 X107.252 Y137.958 E.11572
G2 X103.68 Y142.062 I21.495 J22.316 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.883 J-14.379 E.18439
G1 X101.141 Y131.847 E.31127
G1 X101.1 Y131.87 E.00156
G1 X120.021 Y112.948 E.88766
G1 X120.456 Y112.783 E.01542
G1 X128.677 Y121.004 E.38567
G2 X127.325 Y120.996 I-.696 J3.453 E.04512
G1 X135.538 Y112.784 E.38526
G1 X135.998 Y112.973 E.01652
G1 X154.973 Y131.948 E.89013
G2 X154.844 Y131.857 I-.379 J.402 E.00524
G1 X161.265 Y125.436 E.30121
G2 X160.005 Y124.422 I-3.027 J2.469 E.05403
; WIPE_START
G1 X160.782 Y124.941 E-.35501
G1 X161.265 Y125.436 E-.26286
G1 X161 Y125.701 E-.14214
; WIPE_END
G1 E-.04 F1800
G1 X153.471 Y126.951 Z1.8 F36000
G1 X112.9 Y133.689 Z1.8
G1 Z1.4
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.5 J13.619 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.703 Y119.18 I-19.495 J-25.073 E.15408
G3 X103.362 Y118.717 I2.109 J2.303 E.02679
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X125.419 Y122.903 E.4255
G2 X130.54 Y122.867 I2.565 J.64 E.31963
G1 X139.666 Y131.992 E.42809
G1 X139.447 Y131.902 E.00784
G1 X152.621 Y118.728 E.61802
G3 X153.356 Y119.262 I-1.987 J3.508 E.03021
G2 X156.721 Y122.304 I27.782 J-27.344 E.15055
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.242 J13.194 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X138.234 Y130.288 Z1.8 F36000
G1 X112.541 Y114.437 Z1.8
G1 Z1.4
G1 E.8 F1800
G1 F15476.087
G3 X114.137 Y114.139 I2.484 J8.9 E.05391
G1 X129.657 Y129.659 E.72808
G2 X126.34 Y129.657 I-1.673 J20.581 E.11013
G1 X141.856 Y114.141 E.72787
G3 X143.449 Y114.447 I-.8 J8.478 E.0539
G1 X88.609 Y134.427 F36000
G1 F15476.087
G1 X89.965 Y135.329 E.05401
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.312 J-2.775 E.00842
G1 X122.456 Y130.135 E.63779
G2 X120.865 Y130.479 I2.482 J15.347 E.05402
; CHANGE_LAYER
; Z_HEIGHT: 1.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X122.456 Y130.135 E-.61855
G1 X122.193 Y129.872 E-.14145
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
G1 X127.005 Y121.477
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.03 Y121.473 E.00084
M73 P56 R8
G3 X127.868 Y121.265 I.962 J2.09 E.0288
G3 X129.229 Y121.623 I.109 J2.356 E.0474
G3 X126.743 Y121.631 I-1.237 J1.94 E.39238
G1 X126.953 Y121.507 E.00809
G1 X127.207 Y121.816 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.447 Y121.734 E.0078
G3 X127.896 Y121.656 I.545 J1.828 E.01403
G3 X128.777 Y121.823 I.106 J1.855 E.02783
G3 X127.156 Y121.847 I-.785 J1.739 E.31692
; WIPE_START
M204 S10000
G1 X127.447 Y121.734 E-.11859
G1 X127.712 Y121.67 E-.10343
G1 X127.896 Y121.656 E-.07021
G1 X127.896 Y121.656 E0
G1 X128.255 Y121.67 E-.13672
G1 X128.522 Y121.728 E-.10358
G1 X128.777 Y121.823 E-.10356
G1 X129.016 Y121.953 E-.1036
G1 X129.059 Y121.986 E-.0203
; WIPE_END
G1 E-.04 F1800
G1 X122.181 Y125.294 Z2 F36000
G1 X100.772 Y135.594 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.598 Y135.345 E.01007
G3 X102.412 Y131.81 I1.939 J-1.239 E.15914
G3 X103.773 Y132.167 I.109 J2.357 E.0474
G3 X100.816 Y135.634 I-1.237 J1.94 E.2609
G1 X101.079 Y135.349 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X100.928 Y135.133 E.00811
G3 X102.44 Y132.201 I1.608 J-1.027 E.12243
G3 X103.321 Y132.367 I.106 J1.854 E.02783
G3 X101.122 Y135.387 I-.785 J1.739 E.20829
; WIPE_START
M204 S10000
G1 X100.928 Y135.133 E-.12149
G1 X100.79 Y134.899 E-.10342
G1 X100.694 Y134.643 E-.10356
G1 X100.637 Y134.377 E-.10359
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10358
G1 X100.71 Y133.524 E-.01716
; WIPE_END
G1 E-.04 F1800
G1 X108.339 Y133.303 Z2 F36000
G1 X152.461 Y132.021 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.486 Y132.017 E.00084
G3 X153.324 Y131.81 I.962 J2.09 E.0288
G3 X154.685 Y132.167 I.108 J2.357 E.04739
G3 X152.199 Y132.175 I-1.237 J1.94 E.39238
G1 X152.409 Y132.052 E.00808
G1 X152.665 Y132.36 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.903 Y132.278 E.00773
G3 X153.352 Y132.201 I.545 J1.828 E.01403
G3 X154.233 Y132.367 I.106 J1.855 E.02783
G3 X152.614 Y132.39 I-.785 J1.739 E.31698
; WIPE_START
M204 S10000
G1 X152.903 Y132.278 E-.11784
G1 X153.167 Y132.214 E-.10344
G1 X153.352 Y132.201 E-.07024
G1 X153.711 Y132.214 E-.13669
G1 X153.978 Y132.272 E-.10358
G1 X154.233 Y132.367 E-.10357
G1 X154.472 Y132.498 E-.10359
G1 X154.517 Y132.531 E-.02105
; WIPE_END
G1 E-.04 F1800
G1 X153.721 Y140.122 Z2 F36000
G1 X153.292 Y144.224 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98338
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.397 J1.75 E.04339
G3 X88.408 Y132.052 I2.735 J2.127 E.0325
G2 X91.148 Y129.685 I-14.519 J-19.57 E.12021
G2 X93.594 Y126.159 I-11.288 J-10.444 E.14282
G3 X94.42 Y124.708 I12.307 J6.04 E.05543
G3 X95.013 Y124.286 I1.249 J1.126 E.02434
G2 X97.525 Y123.019 I-21.46 J-45.68 E.09335
G2 X101.007 Y120.323 I-8.607 J-14.712 E.14648
G3 X102.746 Y118.697 I16.201 J15.583 E.07901
G3 X103.976 Y118.067 I2.749 J3.854 E.04599
G2 X106.463 Y117.223 I-148.987 J-443.295 E.08712
G2 X110.366 Y115.274 I-7.223 J-19.346 E.14501
G3 X112.192 Y114.202 I10.973 J16.59 E.07026
G3 X113.876 Y113.812 I2.035 J4.969 E.05759
G2 X117.401 Y113.355 I-2.347 J-31.912 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10417
G3 X122.452 Y111.606 I9.398 J20.39 E.07348
G3 X123.43 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I37.95 J-213.235 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16542
G3 X132.882 Y111.551 I5.295 J24.851 E.07085
G3 X133.134 Y111.543 I.193 J2.095 E.00835
G3 X134.227 Y111.868 I-.465 J3.568 E.03801
G2 X137.511 Y113.104 I11.112 J-24.531 E.11646
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.068 Y113.962 I-1.514 J22.329 E.07914
G3 X144.643 Y114.679 I-1.437 J5.239 E.05764
G2 X148.015 Y116.604 I17.389 J-26.55 E.12888
G2 X151.657 Y117.949 I12.729 J-28.862 E.12886
G3 X153.297 Y118.756 I-1.46 J5.034 E.06095
G3 X154.769 Y120.137 I-13.761 J16.146 E.06698
G2 X158.902 Y123.348 I14.663 J-14.613 E.17409
G3 X161.003 Y124.671 I-9.76 J17.83 E.08241
G3 X161.851 Y125.633 I-2.916 J3.422 E.04268
G2 X163.68 Y128.324 I49.88 J-31.94 E.10794
G2 X166.202 Y131.082 I16.837 J-12.865 E.12414
G3 X167.71 Y132.567 I-14.867 J16.601 E.07024
G3 X168.522 Y134.094 I-4.097 J3.158 E.05761
G1 X168.658 Y134.455 E.0128
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.795 E1.86584
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.139 J2.087 E.05195
G3 X88.163 Y131.747 I2.988 J2.222 E.03456
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10971
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.336 J6.054 E.05347
G3 X94.829 Y123.939 I1.546 J1.358 E.02751
G2 X97.331 Y122.678 I-21.51 J-45.785 E.08611
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.511 Y118.382 I16.283 J15.667 E.0747
G3 X103.843 Y117.698 I2.996 J4.193 E.04618
G2 X106.325 Y116.856 I-157.193 J-467.564 E.08053
G2 X110.161 Y114.94 I-7.082 J-18.973 E.13198
G3 X112.029 Y113.845 I11.123 J16.83 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.545 E.10818
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.358 J20.298 E.06953
G3 X123.486 Y111.206 I.613 J2.41 E.03526
G2 X125.869 Y111.616 I39.577 J-222.664 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.315 J24.962 E.06668
G3 X133.148 Y111.151 I.225 J2.487 E.00916
G3 X134.376 Y111.505 I-.467 J3.922 E.03942
G2 X137.615 Y112.726 I10.994 J-24.251 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.521 E.07475
G3 X144.845 Y114.343 I-1.517 J5.603 E.0572
G2 X148.18 Y116.248 I17.23 J-26.293 E.11809
G2 X151.783 Y117.578 I12.593 J-28.58 E.11808
G3 X153.54 Y118.449 I-1.58 J5.393 E.06055
G3 X155.042 Y119.856 I-13.966 J16.412 E.06326
G2 X159.105 Y123.012 I14.388 J-14.329 E.15851
G3 X161.075 Y124.23 I-11.648 J21.051 E.0712
G3 X162.173 Y125.409 I-2.928 J3.825 E.04975
G2 X163.993 Y128.088 I49.742 J-31.845 E.09951
G2 X166.471 Y130.796 I16.517 J-12.621 E.11296
G3 X168.012 Y132.318 I-14.981 J16.725 E.06658
G3 X168.887 Y133.951 I-4.412 J3.413 E.05721
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X147.22 Y137.207 Z2 F36000
G1 X145.8 Y135.493 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X144.466 Y134.559 I-9.576 J12.26 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.357 Y119.263 I24.432 J-30.401 E.15053
G2 X152.621 Y118.728 I-2.72 J2.97 E.03023
G1 X139.447 Y131.902 E.61802
G1 X139.666 Y131.992 E.00784
G1 X130.54 Y122.867 E.42809
G3 X125.419 Y122.903 I-2.556 J.675 E.31963
G1 X116.349 Y131.973 E.4255
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.452 J2.767 E.02678
G3 X99.258 Y122.288 I-22.941 J-21.965 E.15408
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.883 J12.76 E.05403
G1 X120.865 Y130.479 F36000
G1 F15476.087
G3 X122.456 Y130.135 I4.073 J15.003 E.05402
G1 X108.861 Y116.54 E.63779
G3 X108.636 Y116.657 I-1.539 J-2.661 E.00843
G1 X89.965 Y135.329 E.87592
G1 X88.609 Y134.427 E.05401
G1 X100.936 Y131.991 F36000
G1 F15476.087
G2 X100.293 Y132.677 I4.339 J4.716 E.03123
G1 X94.573 Y138.397 E.26832
G1 X99.181 Y141.464 E.18364
G1 X128.138 Y112.507 E1.35844
G3 X127.857 Y112.508 I-.148 J-2.689 E.00933
G1 X156.88 Y141.53 E1.36151
G1 X161.572 Y138.547 E.18446
G1 X155.596 Y132.571 E.28033
G2 X155.136 Y132.07 I-2.458 J1.795 E.02264
G1 X160.005 Y124.422 F36000
G1 F15476.087
G3 X161.265 Y125.436 I-1.766 J3.482 E.05403
G1 X154.844 Y131.857 E.30121
G3 X154.973 Y131.948 I-.25 J.493 E.00524
G1 X135.998 Y112.973 E.89013
G1 X135.538 Y112.784 E.01652
G1 X127.325 Y120.996 E.38526
G3 X128.677 Y121.004 I.661 J2.56 E.04534
G1 X120.456 Y112.783 E.38567
G1 X120.021 Y112.948 E.01543
G1 X101.1 Y131.87 E.88766
G1 X101.141 Y131.847 E.00156
G1 X94.506 Y125.212 E.31127
G3 X91.467 Y129.849 I-19.923 J-9.743 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.064 J18.209 E.18071
G1 X104.785 Y135.492 E.11572
; WIPE_START
G1 X106.199 Y136.906 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X113.65 Y135.252 Z2 F36000
G1 X135.125 Y130.484 Z2
G1 Z1.6
G1 E.8 F1800
G1 F15476.087
G2 X133.534 Y130.139 I-4.085 J15.003 E.05402
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.757 J-3.086 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02426
G1 X168.093 Y133.96 E.0568
G2 X167.03 Y132.344 I-4.207 J1.608 E.06466
G3 X164.508 Y129.869 I23.14 J-26.1 E.11728
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.039 J18.156 E.18072
G1 X151.192 Y135.51 E.11551
G1 X143.449 Y114.447 F36000
G1 F15476.087
G2 X141.856 Y114.141 I-2.393 J8.172 E.0539
G1 X126.34 Y129.657 E.72787
G3 X129.657 Y129.659 I1.643 J20.583 E.11013
G1 X114.137 Y114.139 E.72808
G2 X112.541 Y114.437 I.888 J9.193 E.05391
; CHANGE_LAYER
; Z_HEIGHT: 1.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X112.968 Y114.304 E-.16973
G1 X114.137 Y114.139 E-.44861
G1 X114.4 Y114.403 E-.14166
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
G1 X127.05 Y121.457
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.336 Y121.357 E.01006
G3 X127.858 Y121.266 I.654 J2.206 E.01761
G3 X129.492 Y121.82 I.14 J2.275 E.05869
G3 X126.999 Y121.487 I-1.501 J1.743 E.3912
G1 X127.2 Y121.819 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.447 Y121.733 E.00804
G3 X127.886 Y121.657 I.544 J1.828 E.01373
G3 X129.016 Y121.953 I.092 J1.954 E.03646
G3 X127.15 Y121.85 I-1.026 J1.608 E.30821
; WIPE_START
M204 S10000
G1 X127.447 Y121.733 E-.12135
G1 X127.712 Y121.67 E-.10343
G1 X127.886 Y121.657 E-.06654
G1 X128.255 Y121.67 E-.14037
G1 X128.522 Y121.728 E-.10358
G1 X128.777 Y121.823 E-.10356
G1 X129.016 Y121.953 E-.10358
G1 X129.053 Y121.981 E-.01758
; WIPE_END
G1 E-.04 F1800
G1 X122.176 Y125.291 Z2.2 F36000
G1 X100.772 Y135.594 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.595 Y135.347 E.01007
G3 X102.402 Y131.81 I1.933 J-1.242 E.15912
G3 X104.39 Y132.759 I.146 J2.252 E.07633
G3 X100.814 Y135.636 I-1.863 J1.346 E.23158
G1 X101.081 Y135.352 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X100.927 Y135.134 E.00822
G3 X102.43 Y132.201 I1.608 J-1.027 E.12221
G3 X103.56 Y132.498 I.092 J1.954 E.03646
G3 X101.123 Y135.39 I-1.026 J1.609 E.19972
; WIPE_START
M204 S10000
G1 X100.927 Y135.134 E-.12289
G1 X100.79 Y134.899 E-.10342
G1 X100.694 Y134.643 E-.10356
G1 X100.637 Y134.377 E-.10358
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10358
G1 X100.709 Y133.528 E-.01577
; WIPE_END
G1 E-.04 F1800
G1 X108.338 Y133.306 Z2.2 F36000
G1 X152.461 Y132.021 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.486 Y132.017 E.00085
G3 X153.314 Y131.81 I.961 J2.089 E.02848
G3 X154.948 Y132.364 I.139 J2.276 E.05868
G3 X152.199 Y132.175 I-1.501 J1.742 E.38125
G1 X152.409 Y132.052 E.00807
G1 X152.657 Y132.363 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.903 Y132.278 E.00799
G3 X153.342 Y132.201 I.544 J1.829 E.01373
G3 X154.472 Y132.498 I.092 J1.954 E.03646
G3 X152.607 Y132.393 I-1.026 J1.609 E.30837
; WIPE_START
M204 S10000
G1 X152.903 Y132.278 E-.12084
G1 X153.167 Y132.214 E-.10344
G1 X153.342 Y132.201 E-.06656
G1 X153.711 Y132.214 E-.14036
G1 X153.978 Y132.272 E-.10358
G1 X154.233 Y132.367 E-.10357
G1 X154.472 Y132.498 E-.10359
G1 X154.51 Y132.526 E-.01806
; WIPE_END
G1 E-.04 F1800
G1 X153.719 Y140.118 Z2.2 F36000
G1 X153.292 Y144.224 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.39 J1.747 E.04339
G3 X88.408 Y132.052 I2.737 J2.129 E.0325
G2 X91.148 Y129.685 I-14.519 J-19.57 E.12021
G2 X93.594 Y126.161 I-11.286 J-10.443 E.14278
G3 X94.42 Y124.708 I12.327 J6.05 E.05547
G3 X95.013 Y124.286 I1.249 J1.126 E.02433
G2 X97.525 Y123.019 I-21.466 J-45.694 E.09335
G2 X101.007 Y120.323 I-8.607 J-14.711 E.14649
G3 X102.746 Y118.697 I16.209 J15.591 E.07901
G3 X103.976 Y118.067 I2.751 J3.858 E.04601
G2 X107.047 Y116.997 I-16.538 J-52.424 E.10789
G2 X110.366 Y115.274 I-7.763 J-19.01 E.12423
G3 X112.192 Y114.201 I10.974 J16.59 E.07026
G3 X113.876 Y113.812 I2.035 J4.969 E.05759
G2 X117.401 Y113.355 I-2.348 J-31.921 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.57 E.10417
G3 X122.452 Y111.606 I9.393 J20.377 E.07348
G3 X123.43 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I37.891 J-212.891 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.296 J24.854 E.07086
G3 X133.132 Y111.543 I.192 J2.09 E.0083
G3 X134.192 Y111.853 I-.447 J3.486 E.03678
G2 X137.511 Y113.104 I11.292 J-24.934 E.11774
G2 X140.701 Y113.674 I5.146 J-19.604 E.10762
G3 X143.068 Y113.962 I-1.514 J22.334 E.07914
G3 X144.643 Y114.679 I-1.436 J5.238 E.05764
G2 X148.014 Y116.603 I17.394 J-26.558 E.12885
G2 X150.332 Y117.514 I10.347 J-22.927 E.08263
G3 X152.669 Y118.351 I-5.676 J19.536 E.0824
G3 X153.961 Y119.348 I-2.503 J4.58 E.05438
G2 X156.837 Y121.957 I22.741 J-22.175 E.12888
G2 X158.902 Y123.348 I15.074 J-20.158 E.08263
G3 X160.841 Y124.544 I-11.516 J20.829 E.07559
G3 X161.851 Y125.633 I-2.683 J3.501 E.0495
G2 X163.68 Y128.324 I49.833 J-31.908 E.10795
G2 X166.202 Y131.082 I16.836 J-12.863 E.12414
G3 X167.71 Y132.568 I-14.854 J16.588 E.07025
G3 X168.522 Y134.093 I-4.097 J3.158 E.0576
G1 X168.658 Y134.455 E.01281
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.135 J2.086 E.05195
G3 X88.163 Y131.747 I2.989 J2.223 E.03455
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10971
G2 X93.249 Y125.974 I-11.004 J-10.177 E.1291
G3 X94.112 Y124.465 I12.347 J6.059 E.05347
G3 X94.828 Y123.94 I1.545 J1.357 E.02749
G2 X97.331 Y122.678 I-21.519 J-45.804 E.08613
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.511 Y118.382 I16.288 J15.672 E.0747
G3 X103.844 Y117.698 I2.998 J4.197 E.04619
G2 X106.325 Y116.856 I-156.601 J-465.83 E.08052
G2 X110.161 Y114.94 I-7.082 J-18.973 E.13198
G3 X112.029 Y113.845 I11.124 J16.833 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.545 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.354 J20.288 E.06953
G3 X123.486 Y111.206 I.613 J2.41 E.03527
G2 X125.869 Y111.616 I39.631 J-222.979 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.313 J24.954 E.06669
G3 X133.147 Y111.151 I.225 J2.483 E.0091
G3 X134.34 Y111.49 I-.45 J3.847 E.03828
G2 X137.615 Y112.726 I11.175 J-24.656 E.10765
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.521 E.07475
G3 X144.845 Y114.343 I-1.517 J5.602 E.0572
G2 X148.18 Y116.248 I17.231 J-26.295 E.11809
G2 X150.456 Y117.142 I10.163 J-22.526 E.07517
G3 X152.644 Y117.905 I-6.817 J23.075 E.07122
G3 X154.232 Y119.064 I-2.359 J4.898 E.06074
G2 X157.076 Y121.646 I22.522 J-21.951 E.11811
G2 X159.105 Y123.012 I14.8 J-19.796 E.07517
G3 X161.075 Y124.229 I-11.66 J21.07 E.07119
G3 X162.172 Y125.409 I-2.931 J3.828 E.04973
G2 X163.993 Y128.088 I49.765 J-31.86 E.09953
G2 X166.471 Y130.796 I16.517 J-12.621 E.11296
G3 X168.012 Y132.318 I-14.978 J16.721 E.06658
G3 X168.887 Y133.951 I-4.411 J3.413 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
M73 P57 R8
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X151.192 Y135.51 Z2.2 F36000
G1 Z1.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X148.729 Y137.972 E.11551
G3 X152.298 Y142.079 I-21.47 J22.263 E.18072
G1 X164.508 Y129.869 E.57279
G3 X167.553 Y132.931 I-263.44 J264.97 E.14325
G3 X168.093 Y133.96 I-8.408 J5.066 E.03857
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.5 J-3.229 E.00975
G1 X133.534 Y130.139 E.63753
G3 X135.125 Y130.484 I-2.495 J15.348 E.05402
; WIPE_START
G1 X133.534 Y130.139 E-.61855
G1 X133.797 Y129.876 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X141.39 Y130.657 Z2.2 F36000
G1 X155.136 Y132.07 Z2.2
G1 Z1.8
G1 E.8 F1800
G1 F15476.087
G3 X155.596 Y132.571 I-1.997 J2.296 E.02264
G1 X161.572 Y138.547 E.28033
G1 X156.88 Y141.53 E.18446
G1 X127.857 Y112.508 E1.36151
G2 X128.138 Y112.507 I.133 J-2.689 E.00933
G1 X99.181 Y141.464 E1.35844
G1 X100.537 Y142.367 E.05401
G1 X104.785 Y135.492 F36000
G1 F15476.087
G1 X107.252 Y137.958 E.11572
G2 X103.68 Y142.062 I21.495 J22.316 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.882 J-14.378 E.18439
G1 X101.141 Y131.847 E.31127
G1 X101.1 Y131.87 E.00156
G1 X120.021 Y112.948 E.88766
G1 X120.456 Y112.783 E.01543
G1 X128.677 Y121.004 E.38567
G2 X127.325 Y120.996 I-.69 J2.558 E.04534
G1 X135.538 Y112.784 E.38526
G1 X135.998 Y112.973 E.01652
G1 X154.973 Y131.948 E.89013
G2 X154.844 Y131.857 I-.379 J.402 E.00524
G1 X161.265 Y125.436 E.30121
G2 X160.005 Y124.422 I-3.025 J2.467 E.05403
; WIPE_START
G1 X160.783 Y124.941 E-.35502
G1 X161.265 Y125.436 E-.26285
G1 X161 Y125.701 E-.14213
; WIPE_END
G1 E-.04 F1800
G1 X153.471 Y126.951 Z2.2 F36000
G1 X112.9 Y133.689 Z2.2
G1 Z1.8
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.502 J13.621 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.703 Y119.18 I-19.495 J-25.073 E.15407
G3 X103.362 Y118.717 I2.11 J2.303 E.02679
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X125.419 Y122.903 E.4255
G2 X130.54 Y122.867 I2.565 J.64 E.31963
G1 X139.666 Y131.992 E.42809
G1 X139.447 Y131.902 E.00784
G1 X152.623 Y118.726 E.61812
G3 X153.357 Y119.263 I-2.175 J3.742 E.03022
G2 X156.721 Y122.304 I27.784 J-27.347 E.15052
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.242 J13.194 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X138.234 Y130.288 Z2.2 F36000
G1 X112.541 Y114.437 Z2.2
G1 Z1.8
G1 E.8 F1800
G1 F15476.087
G3 X114.137 Y114.139 I2.484 J8.899 E.05391
G1 X129.657 Y129.659 E.72808
G2 X126.34 Y129.657 I-1.673 J20.581 E.11013
G1 X141.856 Y114.141 E.72787
G3 X143.449 Y114.447 I-.8 J8.48 E.0539
G1 X100.936 Y131.991 F36000
G1 F15476.087
G2 X100.293 Y132.677 I4.344 J4.721 E.03123
G1 X94.573 Y138.397 E.26832
G1 X89.965 Y135.329 E.18364
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.315 J-2.779 E.00843
G1 X122.456 Y130.135 E.63779
G2 X120.865 Y130.479 I2.482 J15.347 E.05402
; CHANGE_LAYER
; Z_HEIGHT: 2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X122.456 Y130.135 E-.61855
G1 X122.193 Y129.872 E-.14145
; WIPE_END
G1 E-.04 F1800
;======== P2S layer_change gcode ==========
;===== 2025/11/04 ====






; update layer progress
M73 L10
M991 S0 P9 ;notify layer change


G17
M73 P57 R7
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
G1 X127.004 Y121.477
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.03 Y121.473 E.00086
G3 X127.848 Y121.267 I.961 J2.09 E.02816
G3 X129.492 Y121.82 I.149 J2.274 E.05901
G3 X126.743 Y121.63 I-1.501 J1.743 E.38147
G1 X126.953 Y121.508 E.00806
G1 X127.192 Y121.822 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.447 Y121.734 E.0083
G3 X127.877 Y121.658 I.544 J1.828 E.01343
G3 X129.016 Y121.953 I.102 J1.951 E.03675
G3 X127.145 Y121.852 I-1.025 J1.608 E.30806
; WIPE_START
M204 S10000
G1 X127.447 Y121.734 E-.12312
G1 X127.712 Y121.67 E-.10343
G1 X127.877 Y121.658 E-.06286
G1 X128.255 Y121.67 E-.14404
G1 X128.522 Y121.728 E-.10357
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.953 E-.1036
G1 X129.05 Y121.978 E-.01581
; WIPE_END
G1 E-.04 F1800
G1 X122.173 Y125.289 Z2.4 F36000
G1 X100.772 Y135.593 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.598 Y135.345 E.01005
G3 X101.174 Y132.248 I1.937 J-1.242 E.1151
G3 X102.393 Y131.811 I1.355 J1.861 E.04354
G3 X102.855 Y131.825 I.183 J1.617 E.01541
G3 X100.816 Y135.633 I-.321 J2.279 E.29352
G1 X101.083 Y135.355 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X100.927 Y135.133 E.00834
G3 X102.421 Y132.202 I1.608 J-1.027 E.1219
G3 X103.561 Y132.498 I.102 J1.951 E.03675
G3 X101.124 Y135.391 I-1.026 J1.609 E.1997
; WIPE_START
M204 S10000
G1 X100.927 Y135.133 E-.12323
G1 X100.79 Y134.899 E-.10342
G1 X100.732 Y134.744 E-.06284
G1 X100.637 Y134.377 E-.14401
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10359
G1 X100.709 Y133.528 E-.01572
; WIPE_END
G1 E-.04 F1800
G1 X108.338 Y133.306 Z2.4 F36000
G1 X152.46 Y132.021 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.486 Y132.017 E.00086
G3 X153.304 Y131.811 I.961 J2.089 E.02816
G3 X154.948 Y132.364 I.149 J2.274 E.059
G3 X152.199 Y132.175 I-1.501 J1.742 E.38125
G1 X152.409 Y132.052 E.00806
G1 X152.649 Y132.366 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.903 Y132.278 E.00826
G3 X153.332 Y132.202 I.544 J1.829 E.01343
G3 X154.472 Y132.498 I.102 J1.951 E.03675
G3 X152.601 Y132.396 I-1.026 J1.609 E.30818
; WIPE_START
M204 S10000
G1 X152.903 Y132.278 E-.12302
G1 X153.167 Y132.214 E-.10344
G1 X153.332 Y132.202 E-.06287
G1 X153.711 Y132.214 E-.14402
G1 X153.978 Y132.272 E-.10358
G1 X154.233 Y132.367 E-.10357
G1 X154.472 Y132.498 E-.10359
G1 X154.506 Y132.523 E-.0159
; WIPE_END
G1 E-.04 F1800
G1 X153.718 Y140.114 Z2.4 F36000
G1 X153.292 Y144.224 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.395 J1.749 E.04338
G3 X88.408 Y132.053 I2.737 J2.128 E.03249
G2 X91.148 Y129.685 I-14.521 J-19.573 E.12022
G2 X93.594 Y126.16 I-11.287 J-10.443 E.14279
G3 X94.42 Y124.708 I12.317 J6.045 E.05546
G3 X95.012 Y124.286 I1.249 J1.126 E.02431
G2 X97.525 Y123.019 I-21.483 J-45.727 E.09336
G2 X101.007 Y120.323 I-8.607 J-14.712 E.14649
G3 X102.746 Y118.696 I16.197 J15.579 E.07902
G3 X103.976 Y118.067 I2.749 J3.854 E.04599
G2 X107.047 Y116.997 I-16.537 J-52.422 E.1079
G2 X110.366 Y115.274 I-7.761 J-19.008 E.12423
G3 X112.192 Y114.201 I10.967 J16.58 E.07027
G3 X113.876 Y113.812 I2.035 J4.97 E.05757
G2 X117.401 Y113.355 I-2.348 J-31.918 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.57 E.10417
G3 X122.451 Y111.606 I9.399 J20.391 E.07347
G3 X123.43 Y111.594 I.513 J2.043 E.03278
G2 X125.813 Y112.005 I37.899 J-212.937 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16542
G3 X132.882 Y111.551 I5.294 J24.844 E.07085
G3 X133.131 Y111.542 I.193 J2.093 E.00825
G3 X134.227 Y111.868 I-.457 J3.551 E.0381
G2 X137.511 Y113.104 I11.112 J-24.531 E.11646
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.068 Y113.962 I-1.514 J22.329 E.07914
G3 X144.643 Y114.679 I-1.437 J5.239 E.05764
G2 X148.014 Y116.603 I17.394 J-26.557 E.12885
G2 X151.657 Y117.949 I12.727 J-28.853 E.12889
G3 X153.297 Y118.757 I-1.46 J5.033 E.06097
G3 X154.769 Y120.137 I-14.154 J16.564 E.06696
G2 X158.902 Y123.348 I14.663 J-14.613 E.17409
G3 X161.003 Y124.671 I-9.758 J17.827 E.08242
G3 X161.851 Y125.633 I-2.917 J3.423 E.04268
G2 X163.68 Y128.324 I49.831 J-31.907 E.10794
G2 X166.202 Y131.082 I16.837 J-12.865 E.12414
G3 X167.71 Y132.568 I-14.861 J16.595 E.07025
G3 X168.522 Y134.093 I-4.098 J3.158 E.05758
G1 X168.658 Y134.455 E.01283
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.137 J2.086 E.05195
G3 X88.163 Y131.747 I2.989 J2.223 E.03455
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10971
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.334 J6.053 E.05347
G3 X94.828 Y123.94 I1.545 J1.357 E.02749
G2 X97.331 Y122.678 I-21.521 J-45.807 E.08612
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.512 Y118.382 I16.282 J15.665 E.07471
G3 X103.844 Y117.698 I2.997 J4.195 E.04618
G2 X106.326 Y116.856 I-155.722 J-463.233 E.08053
G2 X110.161 Y114.94 I-7.083 J-18.974 E.13198
G3 X112.029 Y113.845 I11.118 J16.823 E.06659
G3 X113.833 Y113.423 I2.199 J5.334 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.545 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.359 J20.3 E.06952
G3 X123.486 Y111.206 I.614 J2.41 E.03527
G2 X125.869 Y111.616 I39.64 J-223.03 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.313 J24.954 E.06669
G3 X133.145 Y111.15 I.225 J2.481 E.00905
G3 X134.376 Y111.505 I-.459 J3.908 E.03952
G2 X137.615 Y112.726 I10.994 J-24.252 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.521 E.07475
G3 X144.845 Y114.343 I-1.517 J5.603 E.0572
G2 X148.18 Y116.248 I17.232 J-26.295 E.11809
G2 X151.783 Y117.578 I12.593 J-28.58 E.11808
G3 X153.54 Y118.449 I-1.579 J5.392 E.06056
G3 X155.042 Y119.856 I-14.359 J16.832 E.06325
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.23 I-11.647 J21.05 E.07121
G3 X162.173 Y125.409 I-2.912 J3.81 E.04974
G2 X163.993 Y128.088 I49.739 J-31.842 E.09951
G2 X166.471 Y130.796 I16.517 J-12.621 E.11296
G3 X168.013 Y132.318 I-14.977 J16.72 E.06659
G3 X168.887 Y133.951 I-4.412 J3.413 E.05719
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X147.22 Y137.207 Z2.4 F36000
G1 X145.8 Y135.493 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X144.466 Y134.559 I-9.576 J12.26 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.357 Y119.263 I24.426 J-30.394 E.15051
G2 X152.621 Y118.728 I-2.722 J2.972 E.03024
G1 X139.447 Y131.902 E.61802
G1 X139.666 Y131.992 E.00784
G1 X130.54 Y122.867 E.42809
G3 X125.419 Y122.903 I-2.556 J.675 E.31963
G1 X116.349 Y131.973 E.4255
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.449 J2.763 E.02677
G3 X99.258 Y122.288 I-22.942 J-21.966 E.15409
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.883 J12.76 E.05403
G1 X120.865 Y130.479 F36000
G1 F15476.087
G3 X122.456 Y130.135 I4.073 J15.003 E.05402
G1 X108.861 Y116.54 E.63778
G3 X108.636 Y116.657 I-1.537 J-2.657 E.00842
G1 X89.965 Y135.329 E.87592
G1 X88.609 Y134.427 E.05401
G1 X100.936 Y131.991 F36000
G1 F15476.087
G2 X100.293 Y132.677 I4.339 J4.716 E.03123
G1 X94.573 Y138.397 E.26832
G1 X99.181 Y141.464 E.18364
G1 X128.138 Y112.507 E1.35844
G3 X127.857 Y112.508 I-.148 J-2.689 E.00933
G1 X156.88 Y141.53 E1.36151
G1 X161.572 Y138.547 E.18446
G1 X155.597 Y132.571 E.28033
G2 X155.136 Y132.07 I-2.458 J1.795 E.02264
G1 X160.005 Y124.422 F36000
G1 F15476.087
G3 X161.265 Y125.436 I-1.776 J3.494 E.05403
G1 X154.844 Y131.857 E.30121
G3 X154.973 Y131.948 I-.25 J.493 E.00524
G1 X135.998 Y112.973 E.89013
G1 X135.538 Y112.784 E.01652
G1 X127.325 Y120.996 E.38526
G3 X128.677 Y121.004 I.661 J2.572 E.04534
G1 X120.456 Y112.783 E.38567
G1 X120.021 Y112.948 E.01543
G1 X101.1 Y131.87 E.88765
G1 X101.141 Y131.847 E.00156
G1 X94.506 Y125.212 E.31127
G3 X91.467 Y129.849 I-19.922 J-9.742 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.066 J18.211 E.18071
G1 X104.785 Y135.492 E.11572
; WIPE_START
G1 X106.199 Y136.906 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X113.65 Y135.252 Z2.4 F36000
G1 X135.125 Y130.484 Z2.4
G1 Z2
G1 E.8 F1800
G1 F15476.087
G2 X133.534 Y130.139 I-4.085 J15.003 E.05402
G1 X147.124 Y116.549 E.63753
M73 P58 R7
G2 X147.385 Y116.684 I1.758 J-3.086 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02426
G1 X168.093 Y133.96 E.0568
G2 X167.031 Y132.345 I-4.209 J1.609 E.06464
G3 X164.508 Y129.869 I23.145 J-26.106 E.1173
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.039 J18.156 E.18072
G1 X151.192 Y135.51 E.11551
G1 X143.449 Y114.447 F36000
G1 F15476.087
G2 X141.856 Y114.141 I-2.392 J8.168 E.0539
G1 X126.34 Y129.657 E.72787
G3 X129.657 Y129.659 I1.643 J20.585 E.11013
G1 X114.137 Y114.139 E.72808
G2 X112.541 Y114.437 I.889 J9.199 E.05391
; CHANGE_LAYER
; Z_HEIGHT: 2.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X112.968 Y114.304 E-.16974
G1 X114.137 Y114.139 E-.4486
G1 X114.4 Y114.403 E-.14166
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
G1 X127.004 Y121.477
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.03 Y121.473 E.00087
G3 X127.839 Y121.267 I.961 J2.09 E.02784
G3 X129.492 Y121.82 I.159 J2.274 E.05933
G3 X126.743 Y121.63 I-1.501 J1.743 E.38146
G1 X126.952 Y121.508 E.00805
G1 X127.189 Y121.823 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.193 Y121.83 E.00023
G3 X127.867 Y121.659 I.798 J1.732 E.02148
G3 X129.016 Y121.953 I.113 J1.948 E.03705
G3 X126.955 Y121.961 I-1.025 J1.608 E.30122
G1 X127.137 Y121.854 E.00648
; WIPE_START
M204 S10000
G1 X127.193 Y121.83 E-.02313
G1 X127.445 Y121.728 E-.10339
G1 X127.712 Y121.67 E-.10358
G1 X127.867 Y121.659 E-.05918
G1 X128.255 Y121.67 E-.14771
G1 X128.522 Y121.728 E-.10357
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.953 E-.10358
G1 X129.042 Y121.973 E-.0123
; WIPE_END
G1 E-.04 F1800
G1 X122.166 Y125.286 Z2.6 F36000
G1 X100.771 Y135.593 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.598 Y135.345 E.01004
G3 X102.383 Y131.812 I1.937 J-1.239 E.15816
G3 X104.036 Y132.364 I.159 J2.274 E.05933
G3 X100.816 Y135.633 I-1.501 J1.742 E.24982
G1 X101.088 Y135.352 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.411 Y132.203 I1.446 J-1.245 E.12997
G3 X103.56 Y132.498 I.113 J1.948 E.03705
G3 X101.128 Y135.397 I-1.026 J1.609 E.19955
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12619
G1 X100.79 Y134.899 E-.1036
G1 X100.694 Y134.643 E-.10357
G1 X100.637 Y134.377 E-.10357
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.1036
G1 X100.694 Y133.567 E-.10357
G1 X100.706 Y133.536 E-.01229
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.31 Z2.6 F36000
G1 X152.506 Y132.001 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.792 Y131.902 E.01004
G3 X153.295 Y131.812 I.655 J2.204 E.01697
G3 X154.948 Y132.364 I.159 J2.274 E.05933
G3 X152.455 Y132.031 I-1.501 J1.742 E.391
G1 X152.645 Y132.367 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.649 Y132.374 E.00022
G3 X153.323 Y132.203 I.798 J1.734 E.02149
G3 X154.472 Y132.498 I.113 J1.948 E.03705
G3 X152.411 Y132.504 I-1.026 J1.609 E.30153
G1 X152.593 Y132.397 E.00651
; WIPE_START
M204 S10000
G1 X152.649 Y132.374 E-.02288
G1 X152.901 Y132.272 E-.10339
G1 X153.167 Y132.214 E-.10359
G1 X153.323 Y132.203 E-.05918
G1 X153.711 Y132.214 E-.1477
G1 X153.978 Y132.272 E-.10357
G1 X154.233 Y132.367 E-.10358
G1 X154.472 Y132.498 E-.10359
G1 X154.499 Y132.517 E-.01252
; WIPE_END
G1 E-.04 F1800
G1 X153.716 Y140.11 Z2.6 F36000
G1 X153.292 Y144.224 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.389 J1.747 E.04338
G3 X88.408 Y132.053 I2.736 J2.127 E.03249
G2 X91.148 Y129.685 I-14.522 J-19.575 E.12023
G2 X93.594 Y126.16 I-11.287 J-10.443 E.14279
G3 X94.42 Y124.708 I12.311 J6.042 E.05547
G3 X95.013 Y124.286 I1.249 J1.127 E.02432
G2 X97.525 Y123.019 I-21.471 J-45.702 E.09337
G2 X101.007 Y120.323 I-8.607 J-14.711 E.14647
G3 X102.746 Y118.697 I16.202 J15.584 E.07901
G3 X103.976 Y118.067 I2.748 J3.852 E.04601
G2 X107.047 Y116.997 I-16.542 J-52.436 E.1079
G2 X110.366 Y115.274 I-7.762 J-19.009 E.12423
G3 X112.192 Y114.201 I10.974 J16.59 E.07026
G3 X113.876 Y113.812 I2.035 J4.969 E.05759
G2 X117.401 Y113.355 I-2.347 J-31.913 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10417
G3 X122.451 Y111.606 I9.401 J20.399 E.07347
G3 X123.43 Y111.594 I.513 J2.043 E.03278
G2 X125.813 Y112.005 I37.966 J-213.327 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16542
G3 X132.882 Y111.551 I5.297 J24.862 E.07085
G3 X133.13 Y111.542 I.192 J2.094 E.0082
G3 X134.227 Y111.868 I-.453 J3.544 E.03814
G2 X137.511 Y113.104 I11.112 J-24.53 E.11647
G2 X140.701 Y113.674 I5.146 J-19.604 E.10762
G3 X143.068 Y113.962 I-1.514 J22.33 E.07913
G3 X144.643 Y114.679 I-1.436 J5.238 E.05765
G2 X148.015 Y116.604 I17.388 J-26.547 E.12888
G2 X150.332 Y117.514 I10.345 J-22.925 E.08261
G3 X152.669 Y118.351 I-5.675 J19.534 E.08239
G3 X153.962 Y119.349 I-2.504 J4.583 E.05441
G2 X156.837 Y121.957 I22.727 J-22.161 E.12885
G2 X158.902 Y123.348 I15.073 J-20.156 E.08263
G3 X160.841 Y124.544 I-11.508 J20.815 E.07558
G3 X161.85 Y125.632 I-2.664 J3.484 E.04947
G2 X163.68 Y128.324 I49.886 J-31.943 E.10799
G2 X166.201 Y131.081 I16.838 J-12.865 E.12411
G3 X167.71 Y132.567 I-14.869 J16.605 E.07027
G3 X168.522 Y134.094 I-4.098 J3.158 E.05761
G1 X168.658 Y134.455 E.0128
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.135 J2.086 E.05195
G3 X88.162 Y131.747 I2.989 J2.223 E.03454
G2 X90.863 Y129.416 I-14.317 J-19.315 E.10972
G2 X93.249 Y125.974 I-11.005 J-10.177 E.12911
G3 X94.112 Y124.464 I12.332 J6.052 E.05348
G3 X94.828 Y123.939 I1.546 J1.358 E.0275
G2 X97.331 Y122.678 I-21.517 J-45.799 E.08611
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.512 Y118.382 I16.281 J15.664 E.0747
G3 X103.844 Y117.698 I2.996 J4.193 E.04618
G2 X106.325 Y116.856 I-157.094 J-467.272 E.08053
G2 X110.161 Y114.94 I-7.082 J-18.973 E.13198
G3 X112.029 Y113.845 I11.124 J16.833 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.545 E.10818
G2 X120.25 Y112.069 I-3.379 J-16.163 E.09424
G3 X122.349 Y111.227 I9.359 J20.3 E.06952
G3 X123.486 Y111.206 I.613 J2.41 E.03527
G2 X125.869 Y111.616 I39.595 J-222.766 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.315 J24.966 E.06669
G3 X133.143 Y111.15 I.224 J2.481 E.009
G3 X134.376 Y111.505 I-.455 J3.902 E.03957
G2 X137.615 Y112.726 I10.992 J-24.247 E.10646
G2 X140.743 Y113.284 I5.04 J-19.215 E.09773
G3 X143.156 Y113.579 I-1.533 J22.523 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.0572
G2 X148.18 Y116.248 I17.23 J-26.292 E.11809
G2 X150.457 Y117.142 I10.158 J-22.513 E.07518
G3 X152.846 Y118.001 I-5.728 J19.698 E.07806
G3 X154.232 Y119.065 I-2.674 J4.921 E.05392
G2 X157.076 Y121.646 I22.515 J-21.942 E.11809
G2 X159.105 Y123.012 I14.799 J-19.794 E.07517
G3 X161.075 Y124.229 I-11.658 J21.067 E.07119
G3 X162.172 Y125.408 I-2.911 J3.809 E.04973
G2 X163.993 Y128.088 I49.787 J-31.874 E.09954
G2 X166.471 Y130.796 I16.518 J-12.623 E.11296
G3 X168.012 Y132.318 I-14.98 J16.723 E.06658
G3 X168.887 Y133.951 I-4.411 J3.413 E.05721
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X151.192 Y135.51 Z2.6 F36000
G1 Z2.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X148.729 Y137.972 E.11551
G3 X152.298 Y142.079 I-21.47 J22.263 E.18072
G1 X164.508 Y129.869 E.57279
G3 X167.553 Y132.932 I-262.773 J264.303 E.14326
G3 X168.093 Y133.96 I-8.397 J5.059 E.03856
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.498 J-3.223 E.00975
G1 X133.534 Y130.139 E.63753
G3 X135.125 Y130.484 I-2.495 J15.348 E.05402
; WIPE_START
G1 X133.534 Y130.139 E-.61855
G1 X133.797 Y129.876 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X141.39 Y130.656 Z2.6 F36000
G1 X155.136 Y132.07 Z2.6
G1 Z2.2
G1 E.8 F1800
G1 F15476.087
G3 X155.596 Y132.571 I-1.996 J2.296 E.02264
G1 X161.572 Y138.547 E.28033
G1 X156.88 Y141.53 E.18446
G1 X127.857 Y112.508 E1.3615
G2 X128.138 Y112.507 I.133 J-2.693 E.00933
G1 X99.181 Y141.464 E1.35844
G1 X94.573 Y138.397 E.18364
G1 X100.293 Y132.677 E.26832
G3 X100.936 Y131.991 I4.984 J4.031 E.03123
; WIPE_START
G1 X100.523 Y132.368 E-.2125
G1 X100.293 Y132.677 E-.14652
G1 X99.546 Y133.423 E-.40098
; WIPE_END
G1 E-.04 F1800
G1 X104.785 Y135.492 Z2.6 F36000
G1 Z2.2
G1 E.8 F1800
G1 F15476.087
G1 X107.252 Y137.958 E.11572
G2 X103.68 Y142.062 I21.494 J22.315 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.884 J-14.38 E.18439
G1 X101.141 Y131.847 E.31127
G1 X101.1 Y131.87 E.00156
G1 X120.021 Y112.948 E.88765
G1 X120.456 Y112.783 E.01543
G1 X128.677 Y121.004 E.38567
G2 X127.325 Y120.996 I-.691 J2.571 E.04533
G1 X135.538 Y112.784 E.38526
G1 X135.998 Y112.973 E.01652
G1 X154.973 Y131.948 E.89013
G2 X154.844 Y131.857 I-.379 J.402 E.00524
G1 X161.265 Y125.437 E.3012
G2 X160.005 Y124.422 I-3.03 J2.472 E.05403
; WIPE_START
G1 X160.782 Y124.94 E-.35481
G1 X161.265 Y125.437 E-.26305
G1 X161 Y125.701 E-.14215
; WIPE_END
G1 E-.03999 F1800
G1 X153.471 Y126.951 Z2.6 F36000
G1 X112.9 Y133.689 Z2.6
G1 Z2.2
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.5 J13.619 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.18 I-19.497 J-25.075 E.15408
G3 X103.362 Y118.717 I2.11 J2.304 E.02678
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X125.419 Y122.903 E.4255
G2 X130.54 Y122.867 I2.566 J.656 E.32116
G1 X139.666 Y131.992 E.42809
G1 X139.447 Y131.902 E.00784
G1 X152.623 Y118.726 E.61812
G3 X153.357 Y119.263 I-2.174 J3.74 E.03022
G2 X156.721 Y122.304 I27.785 J-27.348 E.15051
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.242 J13.194 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X138.234 Y130.288 Z2.6 F36000
G1 X112.541 Y114.437 Z2.6
G1 Z2.2
G1 E.8 F1800
G1 F15476.087
G3 X114.137 Y114.139 I2.485 J8.901 E.05391
G1 X129.657 Y129.659 E.72808
G2 X126.34 Y129.657 I-1.673 J20.581 E.11013
G1 X141.856 Y114.141 E.72787
G3 X143.449 Y114.447 I-.799 J8.478 E.0539
G1 X88.609 Y134.427 F36000
G1 F15476.087
G1 X89.965 Y135.329 E.05401
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.315 J-2.779 E.00843
G1 X122.456 Y130.135 E.63779
G2 X120.865 Y130.479 I2.482 J15.347 E.05402
; CHANGE_LAYER
; Z_HEIGHT: 2.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X122.456 Y130.135 E-.61855
G1 X122.193 Y129.872 E-.14145
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
G1 X127.051 Y121.456
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.337 Y121.358 E.01003
G3 X127.829 Y121.268 I.654 J2.205 E.01664
G3 X129.492 Y121.82 I.169 J2.273 E.05965
G3 X127 Y121.487 I-1.501 J1.743 E.39122
G1 X127.187 Y121.824 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.193 Y121.83 E.00024
G3 X127.857 Y121.659 I.798 J1.733 E.02119
G3 X129.016 Y121.953 I.123 J1.947 E.03735
G3 X126.955 Y121.96 I-1.025 J1.609 E.30142
G1 X127.135 Y121.855 E.00643
; WIPE_START
M204 S10000
G1 X127.193 Y121.83 E-.02383
G1 X127.445 Y121.728 E-.1034
G1 X127.712 Y121.67 E-.10361
G1 X127.857 Y121.659 E-.05546
G1 X127.983 Y121.65 E-.04811
G1 X128.255 Y121.67 E-.1036
G1 X128.522 Y121.728 E-.10357
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.953 E-.1036
G1 X129.04 Y121.971 E-.01125
; WIPE_END
G1 E-.04 F1800
G1 X122.164 Y125.284 Z2.8 F36000
G1 X100.771 Y135.593 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.597 Y135.346 E.01003
G3 X102.373 Y131.812 I1.938 J-1.239 E.1579
G3 X104.036 Y132.364 I.169 J2.273 E.05965
G3 X100.814 Y135.634 I-1.501 J1.743 E.24996
G1 X101.089 Y135.351 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.401 Y132.203 I1.446 J-1.245 E.12963
G3 X103.561 Y132.498 I.123 J1.946 E.03735
G3 X101.129 Y135.396 I-1.025 J1.609 E.19948
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12618
G1 X100.79 Y134.899 E-.1036
G1 X100.694 Y134.643 E-.10357
G1 X100.637 Y134.377 E-.10357
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10359
G1 X100.706 Y133.536 E-.01229
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.31 Z2.8 F36000
G1 X152.507 Y132 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.792 Y131.902 E.01003
G3 X153.285 Y131.812 I.654 J2.206 E.01664
G3 X154.948 Y132.364 I.169 J2.273 E.05965
G3 X152.455 Y132.031 I-1.501 J1.744 E.39132
G1 X152.643 Y132.368 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.649 Y132.374 E.00023
G3 X153.313 Y132.203 I.798 J1.733 E.02119
G3 X154.472 Y132.498 I.123 J1.946 E.03735
G3 X152.411 Y132.504 I-1.025 J1.609 E.30152
G1 X152.591 Y132.399 E.00643
; WIPE_START
M204 S10000
G1 X152.649 Y132.374 E-.02377
G1 X152.901 Y132.272 E-.1034
G1 X153.167 Y132.214 E-.10358
G1 X153.313 Y132.203 E-.0555
G1 X153.439 Y132.194 E-.04811
G1 X153.711 Y132.214 E-.10359
G1 X153.978 Y132.272 E-.10357
G1 X154.233 Y132.367 E-.10358
G1 X154.472 Y132.498 E-.10359
G1 X154.496 Y132.515 E-.01131
; WIPE_END
G1 E-.04 F1800
G1 X153.715 Y140.108 Z2.8 F36000
G1 X153.292 Y144.224 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98338
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.385 J1.746 E.04339
G3 X88.408 Y132.052 I2.738 J2.13 E.03249
G2 X91.148 Y129.685 I-14.519 J-19.571 E.12021
G2 X93.594 Y126.161 I-11.286 J-10.443 E.14278
M73 P59 R7
G3 X94.42 Y124.708 I12.31 J6.041 E.05548
G3 X95.013 Y124.286 I1.249 J1.127 E.02432
G2 X97.525 Y123.019 I-21.466 J-45.693 E.09335
G2 X101.007 Y120.323 I-8.607 J-14.711 E.14649
G3 X102.746 Y118.696 I16.194 J15.576 E.07903
G3 X103.976 Y118.067 I2.749 J3.855 E.04598
G2 X106.463 Y117.223 I-147.955 J-440.251 E.08713
G2 X110.366 Y115.274 I-7.223 J-19.345 E.14499
G3 X112.192 Y114.201 I10.962 J16.57 E.07028
G3 X113.876 Y113.812 I2.035 J4.97 E.05758
G2 X117.401 Y113.355 I-2.348 J-31.916 E.11796
G2 X120.397 Y112.432 I-3.462 J-16.567 E.10417
G3 X122.451 Y111.606 I9.405 J20.407 E.07346
G3 X123.43 Y111.594 I.514 J2.043 E.03278
G2 X125.813 Y112.005 I37.873 J-212.782 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.883 Y111.551 I5.295 J24.851 E.07087
G3 X133.128 Y111.542 I.192 J2.085 E.00815
G3 X134.179 Y111.848 I-.43 J3.439 E.03646
G2 X137.511 Y113.104 I11.358 J-25.083 E.1182
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.068 Y113.962 I-1.514 J22.33 E.07914
G3 X144.643 Y114.679 I-1.436 J5.238 E.05764
G2 X148.014 Y116.603 I17.393 J-26.556 E.12885
G2 X150.332 Y117.514 I10.344 J-22.919 E.08264
G3 X152.669 Y118.351 I-5.675 J19.532 E.0824
G3 X153.963 Y119.349 I-2.504 J4.582 E.05442
G2 X156.837 Y121.957 I22.726 J-22.16 E.12883
G2 X158.902 Y123.348 I15.073 J-20.157 E.08263
G3 X160.841 Y124.544 I-11.516 J20.828 E.07558
G3 X161.851 Y125.633 I-2.69 J3.508 E.04949
G2 X163.68 Y128.324 I49.855 J-31.923 E.10796
G2 X166.202 Y131.082 I16.838 J-12.865 E.12414
G3 X167.71 Y132.567 I-14.864 J16.599 E.07024
G3 X168.522 Y134.093 I-4.096 J3.158 E.05761
G1 X168.658 Y134.455 E.01281
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.8 E1.86573
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.133 J2.085 E.05195
G3 X88.163 Y131.747 I2.989 J2.224 E.03455
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10971
G2 X93.249 Y125.974 I-11.004 J-10.177 E.1291
G3 X94.112 Y124.464 I12.332 J6.051 E.05349
G3 X94.828 Y123.94 I1.545 J1.358 E.02749
G2 X97.331 Y122.678 I-21.514 J-45.794 E.08612
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.512 Y118.382 I16.279 J15.662 E.07471
G3 X103.843 Y117.698 I2.996 J4.194 E.04617
G2 X106.325 Y116.856 I-156.454 J-465.384 E.08053
G2 X110.16 Y114.94 I-7.082 J-18.973 E.13197
G3 X112.029 Y113.845 I11.119 J16.824 E.0666
G3 X113.833 Y113.423 I2.199 J5.335 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.545 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.361 J20.306 E.06952
G3 X123.486 Y111.206 I.614 J2.41 E.03527
G2 X125.869 Y111.616 I39.572 J-222.629 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.314 J24.957 E.06669
G3 X133.142 Y111.15 I.224 J2.472 E.00895
G3 X134.327 Y111.485 I-.434 J3.803 E.03801
G2 X137.615 Y112.726 I11.241 J-24.804 E.10807
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.522 E.07474
G3 X144.845 Y114.343 I-1.517 J5.602 E.0572
G2 X148.18 Y116.248 I17.231 J-26.295 E.11809
G2 X150.457 Y117.142 I10.161 J-22.523 E.07518
G3 X152.846 Y118.001 I-5.727 J19.694 E.07807
G3 X154.233 Y119.065 I-2.675 J4.921 E.05392
G2 X157.076 Y121.646 I22.514 J-21.942 E.11808
G2 X159.105 Y123.012 I14.799 J-19.795 E.07517
G3 X161.075 Y124.229 I-11.664 J21.077 E.07119
G3 X162.173 Y125.409 I-2.939 J3.835 E.04975
G2 X163.993 Y128.088 I49.76 J-31.857 E.09951
G2 X166.471 Y130.796 I16.518 J-12.622 E.11296
G3 X168.012 Y132.318 I-14.981 J16.724 E.06657
G3 X168.887 Y133.951 I-4.411 J3.413 E.05721
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X147.22 Y137.207 Z2.8 F36000
G1 X145.8 Y135.493 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X144.466 Y134.559 I-9.576 J12.26 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.357 Y119.262 I24.43 J-30.399 E.15054
G2 X152.623 Y118.726 I-2.907 J3.203 E.03019
G1 X139.447 Y131.902 E.61812
G1 X139.666 Y131.992 E.00784
G1 X130.54 Y122.867 E.42809
G1 X130.571 Y123.008 E.00477
G3 X125.419 Y122.903 I-2.588 J.543 E.31547
G1 X116.349 Y131.973 E.4255
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.45 J2.765 E.02677
G3 X99.258 Y122.288 I-22.947 J-21.971 E.15409
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.883 J12.76 E.05403
G1 X120.865 Y130.479 F36000
G1 F15476.087
G3 X122.456 Y130.135 I4.073 J15.003 E.05402
G1 X108.861 Y116.54 E.63779
G3 X108.636 Y116.657 I-1.538 J-2.659 E.00843
G1 X89.965 Y135.329 E.87592
G1 X94.573 Y138.397 E.18364
G1 X100.293 Y132.677 E.26832
G3 X100.936 Y131.991 I4.984 J4.031 E.03123
; WIPE_START
G1 X100.523 Y132.368 E-.21252
G1 X100.293 Y132.677 E-.14649
G1 X99.546 Y133.423 E-.40098
; WIPE_END
G1 E-.04 F1800
G1 X100.386 Y141.009 Z2.8 F36000
G1 X100.537 Y142.367 Z2.8
G1 Z2.4
G1 E.8 F1800
G1 F15476.087
G1 X99.181 Y141.464 E.05401
G1 X128.138 Y112.507 E1.35844
G3 X127.857 Y112.508 I-.148 J-2.692 E.00933
G1 X156.88 Y141.53 E1.3615
G1 X161.572 Y138.547 E.18446
G1 X155.596 Y132.571 E.28034
G2 X155.136 Y132.07 I-2.457 J1.794 E.02264
G1 X160.005 Y124.422 F36000
G1 F15476.087
G3 X161.265 Y125.437 I-1.758 J3.47 E.05404
G1 X154.844 Y131.857 E.3012
G3 X154.973 Y131.948 I-.25 J.493 E.00524
G1 X135.998 Y112.973 E.89013
G1 X135.538 Y112.784 E.01652
G1 X127.325 Y120.996 E.38526
G3 X128.677 Y121.004 I.661 J2.584 E.04533
G1 X120.456 Y112.783 E.38567
G1 X120.021 Y112.948 E.01543
G1 X101.1 Y131.87 E.88765
G1 X101.141 Y131.847 E.00156
G1 X94.506 Y125.212 E.31127
G3 X91.467 Y129.849 I-19.924 J-9.744 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.066 J18.211 E.18071
G1 X104.785 Y135.492 E.11572
; WIPE_START
G1 X106.199 Y136.906 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X113.65 Y135.252 Z2.8 F36000
G1 X135.125 Y130.484 Z2.8
G1 Z2.4
G1 E.8 F1800
G1 F15476.087
G2 X133.534 Y130.139 I-4.085 J15.003 E.05402
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.763 J-3.098 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02425
G1 X168.093 Y133.96 E.0568
G2 X167.03 Y132.344 I-4.207 J1.608 E.06466
G3 X164.508 Y129.869 I23.148 J-26.108 E.11727
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.039 J18.156 E.18072
G1 X151.192 Y135.51 E.11551
G1 X143.449 Y114.447 F36000
G1 F15476.087
G2 X141.856 Y114.141 I-2.393 J8.171 E.0539
G1 X126.34 Y129.657 E.72787
G3 X129.657 Y129.659 I1.643 J20.583 E.11013
G1 X114.137 Y114.139 E.72808
G2 X112.541 Y114.437 I.888 J9.195 E.05391
; CHANGE_LAYER
; Z_HEIGHT: 2.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X112.968 Y114.304 E-.16972
G1 X114.137 Y114.139 E-.44862
G1 X114.4 Y114.403 E-.14166
; WIPE_END
G1 E-.03999 F1800
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
G1 X127.051 Y121.456
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.337 Y121.358 E.01002
G3 X127.819 Y121.269 I.655 J2.204 E.01632
G3 X129.492 Y121.82 I.178 J2.272 E.05997
G3 X127 Y121.487 I-1.501 J1.742 E.39102
G1 X127.185 Y121.825 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.193 Y121.829 E.00026
G3 X127.847 Y121.66 I.798 J1.733 E.02089
G3 X129.016 Y121.953 I.133 J1.945 E.03765
G3 X126.955 Y121.96 I-1.025 J1.609 E.30142
G1 X127.134 Y121.856 E.00637
; WIPE_START
M204 S10000
G1 X127.193 Y121.829 E-.02455
G1 X127.445 Y121.728 E-.1034
G1 X127.712 Y121.67 E-.10358
G1 X127.847 Y121.66 E-.05179
G1 X127.983 Y121.65 E-.0518
G1 X128.255 Y121.67 E-.10358
G1 X128.522 Y121.728 E-.10361
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.953 E-.1036
G1 X129.039 Y121.97 E-.01053
; WIPE_END
G1 E-.04 F1800
G1 X136.052 Y124.98 Z3 F36000
G1 X152.459 Y132.022 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.482 Y132.009 E.00087
G3 X153.111 Y131.825 I.957 J2.095 E.02182
G1 X153.439 Y131.801 E.0109
G3 X152.194 Y132.167 I0 J2.303 E.43636
G1 X152.407 Y132.051 E.00805
G1 X152.641 Y132.369 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.646 Y132.367 E.00016
G3 X153.167 Y132.214 I.794 J1.738 E.01676
G1 X153.439 Y132.194 E.00838
G3 X152.406 Y132.498 I0 J1.91 E.33525
G1 X152.588 Y132.398 E.00637
; WIPE_START
M204 S10000
G1 X152.646 Y132.367 E-.02479
G1 X152.901 Y132.272 E-.10356
G1 X153.167 Y132.214 E-.10359
G1 X153.439 Y132.194 E-.10359
G1 X153.711 Y132.214 E-.1036
G1 X153.978 Y132.272 E-.10358
G1 X154.233 Y132.367 E-.10357
G1 X154.472 Y132.498 E-.10359
G1 X154.494 Y132.514 E-.01012
; WIPE_END
G1 E-.04 F1800
G1 X146.874 Y132.95 Z3 F36000
G1 X100.771 Y135.592 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.591 Y135.35 E.01003
G3 X102.2 Y131.825 I1.937 J-1.246 E.15274
G1 X102.528 Y131.801 E.0109
G3 X100.81 Y135.638 I0 J2.303 E.30427
G1 X101.087 Y135.353 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.256 Y132.214 I1.441 J-1.251 E.12564
G1 X102.528 Y132.194 E.00838
G3 X101.127 Y135.398 I0 J1.908 E.23252
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12621
G1 X100.79 Y134.899 E-.1036
G1 X100.694 Y134.643 E-.10356
G1 X100.637 Y134.377 E-.10359
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.1036
G1 X100.694 Y133.567 E-.10358
G1 X100.706 Y133.536 E-.01226
; WIPE_END
G1 E-.04 F1800
G1 X108.185 Y135.057 Z3 F36000
G1 X153.292 Y144.224 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98338
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.387 J1.747 E.04339
G3 X88.408 Y132.052 I2.738 J2.13 E.03249
G2 X91.148 Y129.685 I-14.519 J-19.57 E.12022
G2 X93.594 Y126.16 I-11.287 J-10.443 E.14278
G3 X94.42 Y124.708 I12.313 J6.043 E.05547
G3 X95.013 Y124.286 I1.249 J1.126 E.02432
G2 X97.525 Y123.019 I-21.469 J-45.699 E.09335
G2 X101.007 Y120.323 I-8.606 J-14.711 E.14649
G3 X102.746 Y118.696 I16.206 J15.589 E.07903
G3 X103.976 Y118.067 I2.749 J3.855 E.04598
G2 X106.463 Y117.223 I-149.059 J-443.507 E.08712
G2 X110.366 Y115.274 I-7.223 J-19.346 E.145
G3 X112.192 Y114.201 I10.968 J16.58 E.07027
G3 X113.876 Y113.812 I2.035 J4.969 E.05759
G2 X117.401 Y113.355 I-2.348 J-31.919 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10417
G3 X122.451 Y111.606 I9.403 J20.404 E.07346
G3 X123.43 Y111.594 I.514 J2.043 E.03277
G2 X125.813 Y112.005 I37.873 J-212.782 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16542
G3 X132.882 Y111.551 I5.295 J24.854 E.07085
G3 X133.126 Y111.542 I.192 J2.085 E.0081
G3 X134.227 Y111.868 I-.444 J3.528 E.03824
G2 X137.511 Y113.104 I11.112 J-24.531 E.11647
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.068 Y113.962 I-1.514 J22.33 E.07914
G3 X144.643 Y114.679 I-1.437 J5.238 E.05764
G2 X148.015 Y116.604 I17.39 J-26.551 E.12887
G2 X151.657 Y117.949 I12.73 J-28.863 E.12887
G3 X153.297 Y118.757 I-1.46 J5.033 E.06097
G3 X154.769 Y120.137 I-14.31 J16.73 E.06695
G2 X158.902 Y123.348 I14.664 J-14.614 E.17409
G3 X161.003 Y124.671 I-9.763 J17.834 E.08241
G3 X161.85 Y125.633 I-2.917 J3.423 E.04266
G2 X163.68 Y128.324 I49.881 J-31.94 E.10797
G2 X166.202 Y131.082 I16.837 J-12.865 E.12414
G3 X167.71 Y132.568 I-14.86 J16.593 E.07025
G3 X168.522 Y134.093 I-4.095 J3.156 E.05758
G1 X168.658 Y134.455 E.01283
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.801 E1.86571
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.132 J2.085 E.05195
G3 X88.163 Y131.747 I2.989 J2.223 E.03455
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10972
G2 X93.249 Y125.974 I-11.005 J-10.177 E.12911
G3 X94.112 Y124.464 I12.335 J6.053 E.05347
G3 X94.828 Y123.94 I1.546 J1.357 E.02749
G2 X97.331 Y122.678 I-21.518 J-45.802 E.08612
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.512 Y118.382 I16.285 J15.669 E.07471
G3 X103.843 Y117.698 I2.997 J4.195 E.04617
G2 X106.325 Y116.856 I-156.93 J-466.788 E.08053
G2 X110.16 Y114.94 I-7.082 J-18.973 E.13197
G3 X112.029 Y113.845 I11.119 J16.823 E.06659
G3 X113.833 Y113.423 I2.199 J5.333 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.545 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.36 J20.302 E.06952
G3 X123.486 Y111.206 I.614 J2.41 E.03527
G2 X125.869 Y111.616 I39.572 J-222.629 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.315 J24.963 E.06668
G3 X133.14 Y111.15 I.224 J2.471 E.0089
G3 X134.376 Y111.505 I-.446 J3.887 E.03967
G2 X137.615 Y112.726 I10.994 J-24.251 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.522 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.0572
G2 X148.18 Y116.248 I17.23 J-26.292 E.11809
G2 X151.783 Y117.578 I12.595 J-28.585 E.11808
G3 X153.54 Y118.449 I-1.58 J5.392 E.06056
G3 X155.042 Y119.856 I-14.499 J16.981 E.06325
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.23 I-11.651 J21.057 E.07121
G3 X162.172 Y125.409 I-2.941 J3.837 E.04972
G2 X163.993 Y128.088 I49.787 J-31.875 E.09953
G2 X166.471 Y130.796 I16.517 J-12.621 E.11296
G3 X168.013 Y132.318 I-14.979 J16.722 E.06658
G3 X168.887 Y133.951 I-4.41 J3.412 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X151.192 Y135.51 Z3 F36000
G1 Z2.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X148.729 Y137.972 E.11551
G3 X152.298 Y142.079 I-21.47 J22.263 E.18072
G1 X164.508 Y129.869 E.57279
G3 X167.553 Y132.932 I-262.167 J263.696 E.14327
G3 X168.093 Y133.96 I-8.441 J5.082 E.03855
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.5 J-3.229 E.00975
G1 X133.534 Y130.139 E.63753
G3 X135.125 Y130.484 I-2.495 J15.348 E.05402
; WIPE_START
G1 X133.534 Y130.139 E-.61855
G1 X133.797 Y129.876 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X141.39 Y130.656 Z3 F36000
G1 X155.136 Y132.07 Z3
G1 Z2.6
G1 E.8 F1800
G1 F15476.087
G3 X155.597 Y132.571 I-1.997 J2.297 E.02264
G1 X161.572 Y138.547 E.28033
G1 X156.88 Y141.53 E.18446
G1 X127.857 Y112.508 E1.3615
G2 X128.138 Y112.507 I.133 J-2.693 E.00933
G1 X99.181 Y141.464 E1.35844
G1 X100.537 Y142.367 E.05401
G1 X104.785 Y135.492 F36000
G1 F15476.087
G1 X107.252 Y137.958 E.11572
G2 X103.68 Y142.062 I21.495 J22.316 E.18071
M73 P60 R7
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.884 J-14.38 E.18439
G1 X101.141 Y131.847 E.31127
G1 X101.1 Y131.87 E.00156
G1 X120.021 Y112.948 E.88766
G1 X120.456 Y112.783 E.01543
G1 X128.677 Y121.004 E.38567
G2 X127.325 Y120.996 I-.691 J2.582 E.04533
G1 X135.538 Y112.784 E.38526
G1 X135.998 Y112.973 E.01652
G1 X154.973 Y131.948 E.89013
G2 X154.844 Y131.857 I-.379 J.403 E.00524
G1 X161.265 Y125.436 E.30122
G2 X160.005 Y124.422 I-3.023 J2.465 E.05404
; WIPE_START
G1 X160.783 Y124.941 E-.35506
G1 X161.265 Y125.436 E-.26282
G1 X161 Y125.701 E-.14213
; WIPE_END
G1 E-.04 F1800
G1 X153.471 Y126.951 Z3 F36000
G1 X112.9 Y133.689 Z3
G1 Z2.6
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.5 J13.619 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.18 I-19.497 J-25.075 E.15408
G3 X103.362 Y118.717 I2.109 J2.302 E.02678
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X125.419 Y122.903 E.4255
G2 X130.54 Y122.867 I2.565 J.64 E.31963
G1 X139.666 Y131.992 E.42809
G1 X139.447 Y131.902 E.00784
G1 X152.621 Y118.728 E.61802
G3 X153.357 Y119.263 I-1.985 J3.504 E.03025
G2 X156.721 Y122.304 I27.776 J-27.338 E.15051
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.242 J13.194 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X138.234 Y130.288 Z3 F36000
G1 X112.541 Y114.437 Z3
G1 Z2.6
G1 E.8 F1800
G1 F15476.087
G3 X114.137 Y114.139 I2.483 J8.892 E.05391
G1 X129.657 Y129.659 E.72808
G2 X126.34 Y129.657 I-1.673 J20.581 E.11013
G1 X141.856 Y114.141 E.72787
G3 X143.449 Y114.447 I-.8 J8.48 E.0539
G1 X100.936 Y131.991 F36000
G1 F15476.087
G2 X100.293 Y132.677 I1.647 J2.19 E.03136
G1 X94.573 Y138.397 E.26832
G1 X89.965 Y135.329 E.18364
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.314 J-2.777 E.00843
G1 X122.456 Y130.135 E.63779
G2 X120.865 Y130.479 I2.482 J15.347 E.05402
; CHANGE_LAYER
; Z_HEIGHT: 2.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X122.456 Y130.135 E-.61855
G1 X122.193 Y129.872 E-.14145
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
G1 X127.051 Y121.456
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.336 Y121.357 E.01001
G3 X127.81 Y121.27 I.654 J2.205 E.016
G3 X129.492 Y121.82 I.188 J2.272 E.06029
G3 X127 Y121.487 I-1.501 J1.743 E.39125
G1 X127.184 Y121.826 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.193 Y121.83 E.0003
G3 X127.838 Y121.661 I.798 J1.732 E.02059
G3 X129.016 Y121.953 I.142 J1.944 E.03795
G3 X126.955 Y121.96 I-1.025 J1.608 E.30133
G1 X127.132 Y121.856 E.00631
; WIPE_START
M204 S10000
G1 X127.193 Y121.83 E-.02528
G1 X127.445 Y121.728 E-.1034
G1 X127.712 Y121.67 E-.10358
G1 X127.838 Y121.661 E-.04812
G1 X127.983 Y121.65 E-.05545
G1 X128.255 Y121.67 E-.10363
G1 X128.522 Y121.728 E-.10358
G1 X128.777 Y121.823 E-.10356
G1 X129.016 Y121.953 E-.1036
G1 X129.037 Y121.969 E-.00981
; WIPE_END
G1 E-.04 F1800
G1 X122.161 Y125.283 Z3.2 F36000
G1 X100.771 Y135.592 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.597 Y135.345 E.01001
G3 X102.354 Y131.814 I1.938 J-1.239 E.15723
G3 X104.036 Y132.364 I.188 J2.272 E.06029
G3 X100.815 Y135.633 I-1.501 J1.743 E.24991
G1 X101.089 Y135.351 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.382 Y132.205 I1.446 J-1.245 E.12905
G3 X103.56 Y132.498 I.142 J1.944 E.03794
G3 X101.129 Y135.396 I-1.025 J1.609 E.19948
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12622
G1 X100.79 Y134.899 E-.10358
G1 X100.745 Y134.78 E-.04809
G1 X100.694 Y134.643 E-.05547
G1 X100.637 Y134.377 E-.10358
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10358
G1 X100.706 Y133.536 E-.01228
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.31 Z3.2 F36000
G1 X152.507 Y132 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.792 Y131.902 E.01001
G3 X153.266 Y131.814 I.655 J2.204 E.016
G3 X154.948 Y132.364 I.188 J2.272 E.06029
G3 X152.456 Y132.031 I-1.501 J1.742 E.39103
G1 X152.639 Y132.371 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.649 Y132.374 E.00031
G3 X153.294 Y132.205 I.798 J1.733 E.02059
G3 X154.472 Y132.498 I.142 J1.944 E.03795
G3 X152.411 Y132.504 I-1.025 J1.609 E.30143
G1 X152.587 Y132.401 E.00628
; WIPE_START
M204 S10000
G1 X152.649 Y132.374 E-.0256
G1 X152.901 Y132.272 E-.10339
G1 X153.167 Y132.214 E-.10359
G1 X153.294 Y132.205 E-.04812
G1 X153.439 Y132.194 E-.05547
G1 X153.711 Y132.214 E-.1036
G1 X153.978 Y132.272 E-.10358
G1 X154.233 Y132.367 E-.10357
G1 X154.472 Y132.498 E-.10359
G1 X154.492 Y132.513 E-.00948
; WIPE_END
G1 E-.04 F1800
G1 X153.714 Y140.105 Z3.2 F36000
G1 X153.292 Y144.224 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.394 J1.749 E.04339
G3 X88.408 Y132.053 I2.736 J2.128 E.03249
G2 X91.148 Y129.685 I-14.521 J-19.573 E.12022
G2 X93.594 Y126.159 I-11.288 J-10.444 E.14282
G3 X94.42 Y124.708 I12.304 J6.038 E.05544
G3 X95.013 Y124.286 I1.249 J1.127 E.02433
G2 X97.525 Y123.019 I-21.467 J-45.695 E.09334
G2 X101.007 Y120.323 I-8.607 J-14.711 E.14649
G3 X102.746 Y118.696 I16.202 J15.585 E.07902
G3 X103.977 Y118.067 I2.75 J3.857 E.04602
G2 X107.047 Y116.997 I-16.537 J-52.418 E.10788
G2 X110.366 Y115.274 I-7.762 J-19.008 E.12423
G3 X112.192 Y114.201 I10.969 J16.582 E.07026
G3 X113.876 Y113.812 I2.035 J4.969 E.05759
G2 X117.401 Y113.355 I-2.348 J-31.92 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.57 E.10417
G3 X122.451 Y111.606 I9.4 J20.395 E.07347
G3 X123.43 Y111.594 I.513 J2.043 E.03278
G2 X125.813 Y112.005 I37.894 J-212.905 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16542
G3 X132.882 Y111.551 I5.297 J24.861 E.07085
G3 X133.125 Y111.542 I.192 J2.084 E.00805
G3 X134.171 Y111.845 I-.419 J3.409 E.03627
G2 X137.511 Y113.104 I11.398 J-25.171 E.11849
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.068 Y113.962 I-1.514 J22.332 E.07914
G3 X144.643 Y114.679 I-1.437 J5.239 E.05764
G2 X148.015 Y116.604 I17.393 J-26.556 E.12887
G2 X150.332 Y117.514 I10.347 J-22.929 E.08262
G3 X152.669 Y118.351 I-5.676 J19.535 E.0824
G3 X153.962 Y119.348 I-2.503 J4.581 E.05438
G2 X156.837 Y121.957 I22.736 J-22.17 E.12887
G2 X158.902 Y123.348 I15.074 J-20.158 E.08263
G3 X161.003 Y124.671 I-9.764 J17.836 E.08241
G3 X161.85 Y125.632 I-2.917 J3.422 E.04263
G2 X163.68 Y128.324 I49.886 J-31.943 E.10799
G2 X166.202 Y131.082 I16.837 J-12.864 E.12414
G3 X167.71 Y132.568 I-14.859 J16.593 E.07025
G3 X168.522 Y134.093 I-4.097 J3.157 E.05758
G1 X168.658 Y134.455 E.01283
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.136 J2.086 E.05195
G3 X88.163 Y131.747 I2.989 J2.223 E.03455
G2 X90.863 Y129.416 I-14.316 J-19.313 E.10971
G2 X93.249 Y125.974 I-11.005 J-10.177 E.12911
G3 X94.112 Y124.464 I12.33 J6.051 E.05348
G3 X94.829 Y123.939 I1.546 J1.359 E.0275
G2 X97.331 Y122.678 I-21.506 J-45.779 E.08611
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.512 Y118.382 I16.285 J15.668 E.07471
G3 X103.844 Y117.698 I2.998 J4.196 E.04618
G2 X106.326 Y116.856 I-155.999 J-464.046 E.08052
G2 X110.161 Y114.94 I-7.082 J-18.973 E.13198
G3 X112.029 Y113.845 I11.121 J16.827 E.06658
G3 X113.833 Y113.423 I2.199 J5.334 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.546 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.362 J20.307 E.06952
G3 X123.486 Y111.206 I.614 J2.411 E.03528
G2 X125.869 Y111.616 I39.496 J-222.187 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.315 J24.967 E.06668
G3 X133.138 Y111.15 I.224 J2.47 E.00885
G3 X134.319 Y111.482 I-.423 J3.776 E.03783
G2 X137.615 Y112.726 I11.281 J-24.893 E.10835
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.522 E.07475
G3 X144.845 Y114.343 I-1.517 J5.603 E.0572
G2 X148.18 Y116.248 I17.231 J-26.295 E.11809
G2 X150.457 Y117.142 I10.16 J-22.52 E.07518
G3 X152.846 Y118.001 I-5.728 J19.697 E.07807
G3 X154.232 Y119.064 I-2.674 J4.92 E.05389
G2 X157.076 Y121.646 I22.522 J-21.951 E.11811
G2 X159.105 Y123.012 I14.8 J-19.796 E.07517
G3 X161.075 Y124.23 I-11.659 J21.069 E.0712
G3 X162.172 Y125.408 I-2.943 J3.839 E.04972
G2 X163.993 Y128.088 I49.787 J-31.874 E.09954
G2 X166.471 Y130.796 I16.518 J-12.622 E.11296
G3 X168.013 Y132.318 I-14.975 J16.718 E.06659
G3 X168.887 Y133.951 I-4.411 J3.413 E.05719
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X147.22 Y137.207 Z3.2 F36000
G1 X145.8 Y135.493 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X144.466 Y134.559 I-9.576 J12.26 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.356 Y119.262 I24.425 J-30.394 E.15055
G2 X152.623 Y118.726 I-2.908 J3.205 E.03018
G1 X139.447 Y131.902 E.61812
G1 X139.666 Y131.992 E.00784
G1 X130.54 Y122.867 E.42809
G3 X125.419 Y122.903 I-2.556 J.675 E.31963
G1 X116.349 Y131.973 E.4255
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.451 J2.766 E.02677
G3 X99.258 Y122.288 I-22.944 J-21.968 E.15409
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.885 J12.762 E.05403
G1 X120.865 Y130.479 F36000
G1 F15476.087
G3 X122.456 Y130.135 I4.073 J15.003 E.05402
G1 X108.861 Y116.54 E.63779
G3 X108.636 Y116.657 I-1.541 J-2.664 E.00843
G1 X89.965 Y135.329 E.87592
G1 X88.609 Y134.427 E.05401
G1 X100.936 Y131.991 F36000
G1 F15476.087
G1 X100.934 Y131.993 E.00009
G2 X100.293 Y132.677 I4.37 J4.739 E.03114
G1 X94.573 Y138.397 E.26832
G1 X99.181 Y141.464 E.18364
G1 X128.138 Y112.507 E1.35844
G3 X127.857 Y112.508 I-.148 J-2.692 E.00933
G1 X156.88 Y141.53 E1.3615
G1 X161.572 Y138.547 E.18446
G1 X155.596 Y132.571 E.28034
G2 X155.136 Y132.07 I-2.457 J1.794 E.02264
G1 X160.005 Y124.422 F36000
G1 F15476.087
G3 X161.265 Y125.437 I-1.756 J3.468 E.05404
G1 X154.844 Y131.857 E.30121
G3 X154.973 Y131.948 I-.25 J.493 E.00524
G1 X135.998 Y112.973 E.89013
G1 X135.538 Y112.784 E.01652
G1 X127.325 Y120.996 E.38526
G3 X128.677 Y121.004 I.661 J2.594 E.04533
G1 X120.456 Y112.783 E.38567
G1 X120.021 Y112.948 E.01543
G1 X101.1 Y131.87 E.88765
G1 X101.141 Y131.847 E.00156
G1 X94.506 Y125.212 E.31127
G3 X91.467 Y129.849 I-19.921 J-9.742 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.064 J18.209 E.18071
G1 X104.785 Y135.492 E.11572
; WIPE_START
G1 X106.199 Y136.906 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X113.65 Y135.252 Z3.2 F36000
G1 X135.125 Y130.484 Z3.2
G1 Z2.8
G1 E.8 F1800
G1 F15476.087
G2 X133.534 Y130.139 I-4.085 J15.003 E.05402
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.761 J-3.093 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02426
G1 X168.093 Y133.96 E.0568
G2 X167.031 Y132.345 I-4.207 J1.608 E.06464
G3 X164.508 Y129.869 I23.151 J-26.112 E.11729
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.039 J18.156 E.18072
G1 X151.192 Y135.51 E.11551
G1 X143.449 Y114.447 F36000
G1 F15476.087
G2 X141.856 Y114.141 I-2.393 J8.174 E.0539
G1 X126.34 Y129.657 E.72787
G3 X129.657 Y129.659 I1.643 J20.583 E.11013
G1 X114.137 Y114.139 E.72808
G2 X112.541 Y114.437 I.887 J9.188 E.05391
; CHANGE_LAYER
; Z_HEIGHT: 3
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X112.968 Y114.304 E-.16975
G1 X114.137 Y114.139 E-.4486
G1 X114.4 Y114.403 E-.14166
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
G1 X127.003 Y121.478
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.03 Y121.473 E.00091
G3 X127.8 Y121.27 I.961 J2.09 E.02655
G3 X129.492 Y121.82 I.197 J2.272 E.06062
G3 X126.743 Y121.63 I-1.501 J1.743 E.38147
G1 X126.951 Y121.508 E.00801
G1 X127.182 Y121.827 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.193 Y121.829 E.00033
G3 X127.828 Y121.661 I.798 J1.733 E.0203
G3 X129.016 Y121.953 I.152 J1.944 E.03824
G3 X126.955 Y121.96 I-1.026 J1.609 E.30144
G1 X127.13 Y121.857 E.00625
; WIPE_START
M204 S10000
G1 X127.193 Y121.829 E-.02598
G1 X127.445 Y121.728 E-.1034
G1 X127.828 Y121.661 E-.14769
G1 X127.983 Y121.65 E-.05916
G1 X128.255 Y121.67 E-.1036
G1 X128.522 Y121.728 E-.10357
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.953 E-.10358
G1 X129.036 Y121.968 E-.00944
; WIPE_END
G1 E-.04 F1800
M73 P61 R7
G1 X122.166 Y125.294 Z3.4 F36000
G1 X100.806 Y135.632 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.792 Y135.609 E.0009
G3 X102.344 Y131.814 I1.743 J-1.502 E.16782
G3 X104.036 Y132.364 I.197 J2.272 E.06062
G3 X101.023 Y135.841 I-1.501 J1.743 E.24019
G1 X100.849 Y135.674 E.00801
G1 X101.09 Y135.351 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.372 Y132.205 I1.445 J-1.245 E.12873
G3 X103.56 Y132.498 I.152 J1.944 E.03824
G3 X101.13 Y135.396 I-1.025 J1.608 E.1994
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12617
G1 X100.749 Y134.789 E-.1477
G1 X100.694 Y134.643 E-.05916
G1 X100.637 Y134.377 E-.10358
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10359
G1 X100.706 Y133.535 E-.01262
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.312 Z3.4 F36000
G1 X152.459 Y132.022 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.486 Y132.017 E.00091
G3 X153.256 Y131.814 I.961 J2.09 E.02655
G3 X154.948 Y132.364 I.197 J2.272 E.06061
G3 X152.199 Y132.174 I-1.501 J1.743 E.38147
G1 X152.407 Y132.053 E.00801
G1 X152.637 Y132.372 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.649 Y132.374 E.00037
G3 X153.284 Y132.205 I.798 J1.732 E.02029
G3 X154.472 Y132.498 I.152 J1.944 E.03824
G3 X152.411 Y132.504 I-1.025 J1.608 E.30133
G1 X152.585 Y132.402 E.00621
; WIPE_START
M204 S10000
G1 X152.649 Y132.374 E-.02649
G1 X152.901 Y132.272 E-.10339
G1 X153.284 Y132.205 E-.1477
G1 X153.439 Y132.194 E-.05917
G1 X153.711 Y132.214 E-.1036
G1 X153.978 Y132.272 E-.10357
G1 X154.233 Y132.367 E-.10358
G1 X154.472 Y132.498 E-.10359
G1 X154.491 Y132.512 E-.00891
; WIPE_END
G1 E-.04 F1800
G1 X153.714 Y140.104 Z3.4 F36000
G1 X153.292 Y144.224 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98338
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.39 J1.747 E.04339
G3 X88.408 Y132.053 I2.739 J2.13 E.03249
G2 X91.148 Y129.685 I-14.52 J-19.572 E.12022
G2 X93.594 Y126.159 I-11.287 J-10.443 E.14282
G3 X94.42 Y124.708 I12.299 J6.036 E.05543
G3 X95.013 Y124.286 I1.249 J1.126 E.02434
G2 X97.525 Y123.019 I-21.459 J-45.678 E.09335
G2 X101.007 Y120.323 I-8.607 J-14.712 E.14648
G3 X102.746 Y118.697 I16.209 J15.591 E.07901
G3 X103.976 Y118.067 I2.749 J3.854 E.046
G2 X106.463 Y117.223 I-147.513 J-438.949 E.08713
G2 X110.366 Y115.274 I-7.223 J-19.346 E.145
G3 X112.192 Y114.201 I10.976 J16.594 E.07026
G3 X113.876 Y113.812 I2.035 J4.97 E.05759
G2 X117.401 Y113.355 I-2.349 J-31.922 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10416
G3 X122.451 Y111.606 I9.404 J20.405 E.07348
G3 X123.43 Y111.594 I.514 J2.043 E.03279
G2 X125.813 Y112.005 I37.935 J-213.148 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.297 J24.861 E.07086
G3 X133.123 Y111.542 I.192 J2.082 E.00801
G3 X134.167 Y111.843 I-.413 J3.394 E.03617
G2 X137.511 Y113.104 I11.419 J-25.218 E.11864
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.069 Y113.962 I-1.514 J22.329 E.07914
G3 X144.643 Y114.679 I-1.437 J5.239 E.05763
G2 X148.015 Y116.604 I17.395 J-26.559 E.12887
G2 X151.657 Y117.949 I12.727 J-28.854 E.12888
G3 X153.297 Y118.757 I-1.46 J5.034 E.06095
G3 X154.769 Y120.137 I-13.765 J16.15 E.06697
G2 X158.902 Y123.348 I14.664 J-14.614 E.17409
G3 X160.841 Y124.544 I-11.512 J20.821 E.07559
G3 X161.851 Y125.633 I-2.665 J3.484 E.0495
G2 X163.68 Y128.324 I49.87 J-31.933 E.10795
G2 X166.202 Y131.082 I16.838 J-12.865 E.12414
G3 X167.71 Y132.567 I-14.863 J16.598 E.07024
G3 X168.522 Y134.094 I-4.098 J3.159 E.05761
G1 X168.658 Y134.455 E.0128
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.782 E1.86611
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.135 J2.086 E.05195
G3 X88.163 Y131.747 I2.991 J2.225 E.03455
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10971
G2 X93.249 Y125.974 I-11.005 J-10.177 E.12911
G3 X94.112 Y124.464 I12.332 J6.052 E.05347
G3 X94.828 Y123.94 I1.545 J1.357 E.0275
G2 X97.331 Y122.678 I-21.512 J-45.791 E.08612
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.511 Y118.382 I16.288 J15.672 E.0747
G3 X103.843 Y117.698 I2.997 J4.194 E.04618
G2 X106.325 Y116.856 I-156.098 J-464.336 E.08053
G2 X110.161 Y114.94 I-7.082 J-18.973 E.13198
G3 X112.029 Y113.845 I11.123 J16.83 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.545 E.10817
G2 X120.249 Y112.069 I-3.378 J-16.161 E.09423
G3 X122.349 Y111.227 I9.359 J20.3 E.06953
G3 X123.486 Y111.206 I.614 J2.411 E.03528
G2 X125.869 Y111.616 I39.541 J-222.45 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.313 J24.956 E.06669
G3 X133.137 Y111.15 I.224 J2.47 E.0088
G3 X134.314 Y111.48 I-.418 J3.762 E.03774
G2 X137.615 Y112.726 I11.303 J-24.943 E.10849
G2 X140.743 Y113.284 I5.04 J-19.215 E.09773
G3 X143.156 Y113.579 I-1.533 J22.521 E.07475
G3 X144.845 Y114.343 I-1.518 J5.604 E.0572
G2 X148.18 Y116.248 I17.231 J-26.295 E.11809
G2 X151.783 Y117.578 I12.593 J-28.58 E.11808
G3 X153.359 Y118.312 I-1.679 J5.66 E.05362
G3 X155.042 Y119.856 I-11.414 J14.132 E.07021
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.23 I-11.65 J21.055 E.0712
G3 X162.172 Y125.409 I-2.911 J3.809 E.04973
G2 X163.993 Y128.088 I49.776 J-31.867 E.09953
G2 X166.471 Y130.796 I16.518 J-12.622 E.11296
G3 X168.012 Y132.318 I-14.981 J16.725 E.06658
G3 X168.887 Y133.951 I-4.412 J3.413 E.05721
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X151.192 Y135.51 Z3.4 F36000
G1 Z3
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X148.729 Y137.972 E.11551
G3 X152.298 Y142.079 I-21.47 J22.263 E.18072
G1 X164.508 Y129.869 E.57279
G3 X167.553 Y132.932 I-262.352 J263.884 E.14326
G3 X168.093 Y133.96 I-8.399 J5.06 E.03856
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02425
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.502 J-3.233 E.00975
G1 X133.534 Y130.139 E.63753
G3 X135.125 Y130.484 I-2.495 J15.348 E.05402
; WIPE_START
G1 X133.534 Y130.139 E-.61855
G1 X133.797 Y129.876 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X141.39 Y130.656 Z3.4 F36000
G1 X155.136 Y132.07 Z3.4
G1 Z3
G1 E.8 F1800
G1 F15476.087
G3 X155.597 Y132.571 I-1.997 J2.297 E.02264
G1 X161.572 Y138.547 E.28033
G1 X156.88 Y141.53 E.18446
G1 X127.857 Y112.508 E1.3615
G2 X128.138 Y112.507 I.133 J-2.693 E.00933
G1 X99.181 Y141.464 E1.35844
G1 X94.573 Y138.397 E.18364
G1 X100.293 Y132.677 E.26832
G3 X100.936 Y131.991 I4.981 J4.028 E.03123
; WIPE_START
G1 X100.523 Y132.368 E-.21248
G1 X100.293 Y132.677 E-.14652
G1 X99.546 Y133.423 E-.401
; WIPE_END
G1 E-.04 F1800
G1 X104.785 Y135.492 Z3.4 F36000
G1 Z3
G1 E.8 F1800
G1 F15476.087
G1 X107.252 Y137.958 E.11572
G2 X103.68 Y142.062 I21.495 J22.316 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.881 J-14.378 E.18439
G1 X101.141 Y131.847 E.31127
G1 X101.1 Y131.87 E.00156
G1 X120.021 Y112.948 E.88765
G1 X120.456 Y112.783 E.01543
G1 X128.677 Y121.004 E.38567
G2 X127.325 Y120.996 I-.691 J2.592 E.04533
G1 X135.538 Y112.784 E.38526
G1 X135.998 Y112.973 E.01652
G1 X154.973 Y131.948 E.89013
G2 X154.844 Y131.857 I-.379 J.403 E.00524
G1 X161.264 Y125.437 E.30118
G2 X160.005 Y124.422 I-3.678 J3.273 E.05389
; WIPE_START
G1 X160.782 Y124.94 E-.35488
G1 X161.264 Y125.437 E-.26307
G1 X161 Y125.701 E-.14205
; WIPE_END
G1 E-.04 F1800
G1 X153.47 Y126.952 Z3.4 F36000
G1 X112.9 Y133.689 Z3.4
G1 Z3
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.502 J13.621 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.18 I-19.495 J-25.073 E.15408
G3 X103.362 Y118.717 I2.11 J2.303 E.02678
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X125.419 Y122.903 E.4255
G2 X130.54 Y122.867 I2.565 J.64 E.31961
G1 X139.666 Y131.992 E.42809
G1 X139.447 Y131.902 E.00784
G1 X152.621 Y118.728 E.61803
G3 X153.356 Y119.262 I-2.004 J3.529 E.03021
G2 X156.721 Y122.304 I27.786 J-27.348 E.15055
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.242 J13.194 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X138.234 Y130.288 Z3.4 F36000
G1 X112.541 Y114.437 Z3.4
G1 Z3
G1 E.8 F1800
G1 F15476.087
G3 X114.137 Y114.139 I2.485 J8.903 E.05391
G1 X129.657 Y129.659 E.72808
G2 X126.34 Y129.657 I-1.673 J20.581 E.11013
G1 X141.856 Y114.141 E.72787
G3 X143.449 Y114.447 I-.8 J8.481 E.0539
G1 X88.609 Y134.427 F36000
G1 F15476.087
G1 X89.965 Y135.329 E.05401
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.315 J-2.779 E.00843
G1 X122.456 Y130.135 E.63779
G2 X120.865 Y130.479 I2.482 J15.347 E.05402
; CHANGE_LAYER
; Z_HEIGHT: 3.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X122.456 Y130.135 E-.61855
G1 X122.193 Y129.872 E-.14145
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
G1 X127.003 Y121.478
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.03 Y121.473 E.00093
G3 X127.79 Y121.271 I.962 J2.09 E.02623
G3 X129.229 Y121.623 I.189 J2.344 E.04997
G3 X126.743 Y121.631 I-1.237 J1.94 E.39237
G1 X126.951 Y121.509 E.008
G1 X127.18 Y121.828 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.193 Y121.83 E.00039
G3 X127.818 Y121.662 I.8 J1.732 E.02
G3 X128.777 Y121.823 I.182 J1.854 E.03022
G3 X126.955 Y121.961 I-.785 J1.739 E.30982
G1 X127.129 Y121.858 E.00619
; WIPE_START
M204 S10000
G1 X127.193 Y121.83 E-.02672
G1 X127.445 Y121.728 E-.10339
G1 X127.818 Y121.662 E-.14402
G1 X127.984 Y121.65 E-.06288
G1 X128.255 Y121.67 E-.10354
G1 X128.522 Y121.728 E-.10361
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.953 E-.10358
G1 X129.035 Y121.967 E-.00869
; WIPE_END
G1 E-.04 F1800
G1 X122.165 Y125.293 Z3.6 F36000
G1 X100.806 Y135.633 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.793 Y135.608 E.00092
G3 X102.335 Y131.815 I1.743 J-1.501 E.16743
G3 X103.773 Y132.167 I.189 J2.344 E.04997
G3 X101.024 Y135.84 I-1.237 J1.94 E.25117
G1 X100.849 Y135.674 E.008
G1 X101.09 Y135.35 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.363 Y132.206 I1.446 J-1.244 E.12839
G3 X103.321 Y132.367 I.182 J1.854 E.03022
G3 X101.13 Y135.395 I-.785 J1.739 E.20793
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12622
G1 X100.79 Y134.899 E-.10357
G1 X100.694 Y134.643 E-.10359
G1 X100.637 Y134.377 E-.10359
G1 X100.617 Y134.105 E-.10354
G1 X100.637 Y133.833 E-.10362
G1 X100.694 Y133.567 E-.10358
G1 X100.706 Y133.536 E-.01229
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.31 Z3.6 F36000
G1 X152.508 Y132 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.792 Y131.902 E.00999
G3 X153.246 Y131.815 I.656 J2.205 E.01536
G3 X154.685 Y132.167 I.189 J2.344 E.04997
G3 X152.457 Y132.031 I-1.237 J1.94 E.40218
G1 X152.635 Y132.373 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.649 Y132.374 E.00043
G3 X153.274 Y132.206 I.8 J1.732 E.02
G3 X154.233 Y132.367 I.182 J1.854 E.03022
G3 X152.411 Y132.505 I-.785 J1.739 E.30982
G1 X152.583 Y132.403 E.00614
; WIPE_START
M204 S10000
G1 X152.649 Y132.374 E-.02742
G1 X152.901 Y132.272 E-.1034
G1 X153.274 Y132.206 E-.14402
G1 X153.439 Y132.194 E-.06285
G1 X153.711 Y132.214 E-.10359
G1 X153.978 Y132.272 E-.10358
G1 X154.233 Y132.367 E-.10357
G1 X154.472 Y132.498 E-.10357
G1 X154.489 Y132.51 E-.00799
; WIPE_END
G1 E-.04 F1800
G1 X153.713 Y140.103 Z3.6 F36000
G1 X153.292 Y144.224 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.127 E1.98351
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.391 J1.748 E.04338
G3 X88.408 Y132.053 I2.734 J2.125 E.03249
G2 X91.148 Y129.685 I-14.52 J-19.573 E.12022
G2 X93.594 Y126.161 I-11.286 J-10.443 E.14278
G3 X94.42 Y124.708 I12.32 J6.047 E.05548
G3 X95.012 Y124.286 I1.249 J1.126 E.02431
G2 X97.525 Y123.019 I-21.492 J-45.745 E.09337
G2 X101.007 Y120.323 I-8.608 J-14.712 E.14648
G3 X102.746 Y118.696 I16.194 J15.576 E.07903
G3 X103.976 Y118.067 I2.751 J3.858 E.04598
G2 X107.047 Y116.997 I-16.55 J-52.458 E.10791
G2 X110.366 Y115.274 I-7.763 J-19.011 E.12423
G3 X112.192 Y114.201 I10.971 J16.586 E.07027
G3 X113.876 Y113.812 I2.035 J4.97 E.05758
G2 X117.401 Y113.355 I-2.348 J-31.915 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10417
G3 X122.451 Y111.606 I9.402 J20.401 E.07347
G3 X123.43 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I37.94 J-213.171 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.298 J24.869 E.07086
G3 X133.122 Y111.542 I.192 J2.081 E.00795
G3 X134.227 Y111.868 I-.431 J3.504 E.0384
G2 X137.511 Y113.104 I11.112 J-24.53 E.11647
G2 X140.702 Y113.674 I5.146 J-19.603 E.10764
G3 X143.068 Y113.962 I-1.514 J22.327 E.07911
G3 X144.643 Y114.679 I-1.436 J5.237 E.05764
G2 X148.015 Y116.604 I17.394 J-26.559 E.12887
G2 X151.657 Y117.949 I12.733 J-28.869 E.12886
G3 X153.297 Y118.756 I-1.461 J5.036 E.06096
G3 X154.769 Y120.137 I-13.765 J16.15 E.06697
G2 X158.902 Y123.348 I14.663 J-14.613 E.17409
G3 X161.004 Y124.671 I-9.76 J17.829 E.08242
G3 X161.851 Y125.633 I-2.916 J3.422 E.04267
G2 X163.68 Y128.324 I49.866 J-31.931 E.10795
G2 X166.202 Y131.082 I16.835 J-12.863 E.12414
G3 X167.71 Y132.567 I-14.869 J16.603 E.07024
G3 X168.522 Y134.093 I-4.097 J3.158 E.0576
G1 X168.658 Y134.455 E.01281
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.135 J2.086 E.05195
G3 X88.163 Y131.747 I2.988 J2.222 E.03456
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10971
G2 X93.249 Y125.974 I-11.004 J-10.177 E.1291
G3 X94.112 Y124.464 I12.338 J6.055 E.05349
G3 X94.828 Y123.94 I1.545 J1.357 E.02748
G2 X97.331 Y122.678 I-21.528 J-45.823 E.08613
G2 X100.735 Y120.04 I-8.414 J-14.374 E.13271
G3 X102.512 Y118.382 I16.28 J15.663 E.07471
G3 X103.843 Y117.698 I2.998 J4.197 E.04617
G2 X106.325 Y116.856 I-155.968 J-463.953 E.08053
G2 X110.161 Y114.94 I-7.083 J-18.975 E.13198
G3 X112.029 Y113.845 I11.127 J16.837 E.06658
G3 X113.833 Y113.423 I2.199 J5.334 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.545 E.10818
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.358 J20.298 E.06953
G3 X123.486 Y111.206 I.613 J2.411 E.03526
G2 X125.869 Y111.616 I39.527 J-222.365 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.315 J24.966 E.06668
G3 X133.135 Y111.15 I.224 J2.47 E.00875
G3 X134.376 Y111.505 I-.434 J3.867 E.03983
G2 X137.615 Y112.726 I10.994 J-24.251 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.524 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.05721
G2 X148.18 Y116.248 I17.233 J-26.297 E.11809
M73 P62 R7
G2 X151.783 Y117.578 I12.595 J-28.587 E.11808
G3 X153.54 Y118.449 I-1.58 J5.394 E.06056
G3 X155.042 Y119.856 I-13.967 J16.414 E.06326
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.229 I-11.659 J21.069 E.07119
G3 X162.172 Y125.409 I-2.911 J3.81 E.04974
G2 X163.993 Y128.088 I49.777 J-31.868 E.09952
G2 X166.471 Y130.796 I16.517 J-12.621 E.11296
G3 X168.013 Y132.318 I-14.984 J16.728 E.06658
G3 X168.887 Y133.951 I-4.412 J3.413 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X147.22 Y137.207 Z3.6 F36000
G1 X145.8 Y135.493 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X144.466 Y134.559 I-9.583 J12.27 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.357 Y119.263 I24.414 J-30.381 E.15053
G2 X152.621 Y118.728 I-2.722 J2.972 E.03023
G1 X139.447 Y131.902 E.61802
G1 X139.666 Y131.992 E.00784
G1 X130.54 Y122.867 E.42809
G3 X125.419 Y122.903 I-2.556 J.691 E.32116
G1 X116.349 Y131.973 E.4255
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.455 J2.772 E.02678
G3 X99.258 Y122.288 I-22.942 J-21.966 E.15408
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.885 J12.762 E.05403
G1 X120.865 Y130.479 F36000
G1 F15476.087
G3 X122.456 Y130.135 I4.073 J15.003 E.05402
G1 X108.861 Y116.54 E.63778
G3 X108.636 Y116.657 I-1.537 J-2.658 E.00842
G1 X89.965 Y135.329 E.87592
G1 X88.609 Y134.427 E.05401
G1 X100.936 Y131.991 F36000
G1 F15476.087
G2 X100.293 Y132.677 I4.34 J4.717 E.03123
G1 X94.573 Y138.397 E.26832
G1 X99.181 Y141.464 E.18364
G1 X128.138 Y112.507 E1.35844
G3 X127.857 Y112.508 I-.148 J-2.692 E.00933
G1 X156.88 Y141.53 E1.3615
G1 X161.572 Y138.547 E.18446
G1 X155.597 Y132.571 E.28033
G2 X155.136 Y132.07 I-2.458 J1.795 E.02264
G1 X160.005 Y124.422 F36000
G1 F15476.087
G3 X161.264 Y125.437 I-2.42 J4.289 E.05389
G1 X154.844 Y131.857 E.30118
G3 X154.973 Y131.948 I-.25 J.494 E.00524
G1 X135.998 Y112.973 E.89013
G1 X135.538 Y112.784 E.01652
G1 X127.325 Y120.996 E.38526
G3 X128.677 Y121.004 I.661 J2.604 E.04533
G1 X120.456 Y112.783 E.38567
G1 X120.021 Y112.948 E.01543
G1 X101.1 Y131.87 E.88766
G1 X101.141 Y131.847 E.00156
G1 X94.506 Y125.212 E.31127
G3 X91.467 Y129.849 I-19.924 J-9.744 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.066 J18.211 E.18071
G1 X104.785 Y135.492 E.11572
; WIPE_START
G1 X106.199 Y136.906 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X113.65 Y135.252 Z3.6 F36000
G1 X135.125 Y130.484 Z3.6
G1 Z3.2
G1 E.8 F1800
G1 F15476.087
G2 X133.534 Y130.139 I-4.085 J15.003 E.05402
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.76 J-3.091 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02425
G1 X168.093 Y133.96 E.0568
G2 X167.03 Y132.344 I-4.207 J1.608 E.06465
G3 X164.508 Y129.869 I23.143 J-26.103 E.11728
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-29.946 J22.421 E.18065
G1 X151.192 Y135.51 E.11551
G1 X143.449 Y114.447 F36000
G1 F15476.087
G2 X141.856 Y114.141 I-2.393 J8.171 E.0539
G1 X126.34 Y129.657 E.72787
G3 X129.657 Y129.659 I1.643 J20.583 E.11013
G1 X114.137 Y114.139 E.72808
G2 X112.541 Y114.437 I.889 J9.197 E.05391
; CHANGE_LAYER
; Z_HEIGHT: 3.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X112.968 Y114.304 E-.16972
G1 X114.137 Y114.139 E-.44862
G1 X114.4 Y114.403 E-.14166
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
G1 X127.052 Y121.456
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.336 Y121.357 E.00997
G3 X127.781 Y121.272 I.655 J2.205 E.01503
G3 X129.229 Y121.623 I.198 J2.345 E.05029
G3 X127.001 Y121.486 I-1.237 J1.94 E.40221
G1 X127.179 Y121.829 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.193 Y121.829 E.00043
G3 X127.809 Y121.663 I.799 J1.733 E.0197
G3 X128.777 Y121.823 I.19 J1.856 E.03052
G3 X126.955 Y121.96 I-.785 J1.739 E.30984
G1 X127.127 Y121.859 E.00613
; WIPE_START
M204 S10000
G1 X127.193 Y121.829 E-.02746
G1 X127.445 Y121.728 E-.1034
G1 X127.809 Y121.663 E-.14035
G1 X127.984 Y121.65 E-.06658
G1 X128.255 Y121.67 E-.10354
G1 X128.522 Y121.728 E-.10361
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.953 E-.1036
G1 X129.033 Y121.966 E-.0079
; WIPE_END
G1 E-.04 F1800
G1 X122.158 Y125.28 Z3.8 F36000
G1 X100.77 Y135.591 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.597 Y135.345 E.00997
G3 X102.325 Y131.816 I1.939 J-1.239 E.15626
G3 X103.773 Y132.167 I.198 J2.344 E.05029
G3 X100.814 Y135.632 I-1.237 J1.94 E.26099
G1 X101.09 Y135.351 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.353 Y132.207 I1.446 J-1.245 E.12812
G3 X103.321 Y132.367 I.191 J1.856 E.03052
G3 X101.13 Y135.396 I-.785 J1.739 E.20793
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12617
G1 X100.79 Y134.899 E-.10359
G1 X100.694 Y134.643 E-.10358
G1 X100.637 Y134.377 E-.10358
G1 X100.617 Y134.105 E-.10359
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10358
G1 X100.706 Y133.536 E-.01232
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.313 Z3.8 F36000
G1 X152.458 Y132.023 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.484 Y132.014 E.00092
G3 X153.237 Y131.816 I.954 J2.094 E.02593
G3 X154.506 Y132.07 I.201 J2.297 E.04354
G3 X152.197 Y132.171 I-1.068 J2.038 E.39918
G1 X152.406 Y132.052 E.00799
G1 X152.632 Y132.374 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.649 Y132.374 E.0005
G3 X153.265 Y132.207 I.799 J1.733 E.0197
G3 X154.233 Y132.367 I.19 J1.856 E.03052
G3 X152.411 Y132.505 I-.785 J1.739 E.30984
G1 X152.581 Y132.405 E.00606
; WIPE_START
M204 S10000
G1 X152.649 Y132.374 E-.02837
G1 X152.901 Y132.272 E-.1034
G1 X153.265 Y132.207 E-.14036
G1 X153.439 Y132.194 E-.06654
G1 X153.711 Y132.214 E-.10359
G1 X153.978 Y132.272 E-.10358
G1 X154.233 Y132.367 E-.10357
G1 X154.472 Y132.498 E-.10359
G1 X154.487 Y132.509 E-.00699
; WIPE_END
G1 E-.04 F1800
G1 X153.712 Y140.102 Z3.8 F36000
G1 X153.292 Y144.224 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.395 J1.749 E.04338
G3 X88.408 Y132.053 I2.734 J2.125 E.03249
G2 X91.148 Y129.685 I-14.52 J-19.572 E.12022
G2 X93.594 Y126.159 I-11.287 J-10.444 E.14282
G3 X94.42 Y124.708 I12.307 J6.04 E.05544
G3 X95.013 Y124.286 I1.25 J1.127 E.02433
G2 X97.525 Y123.019 I-21.467 J-45.694 E.09336
G2 X101.007 Y120.323 I-8.607 J-14.711 E.14647
G3 X102.746 Y118.696 I16.211 J15.594 E.07902
G3 X103.976 Y118.067 I2.749 J3.855 E.04599
G2 X106.463 Y117.223 I-147.169 J-437.933 E.08714
G2 X110.366 Y115.274 I-7.223 J-19.346 E.145
G3 X112.192 Y114.201 I10.973 J16.589 E.07026
G3 X113.876 Y113.812 I2.035 J4.968 E.05759
G2 X117.401 Y113.355 I-2.348 J-31.919 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.57 E.10417
G3 X122.451 Y111.606 I9.401 J20.397 E.07347
G3 X123.43 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I37.94 J-213.171 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.883 Y111.551 I5.297 J24.861 E.07087
G3 X133.12 Y111.542 I.191 J2.069 E.00789
G3 X134.158 Y111.84 I-.402 J3.363 E.03597
G2 X137.511 Y113.104 I11.464 J-25.32 E.11894
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.068 Y113.961 I-1.514 J22.334 E.07913
G3 X144.643 Y114.679 I-1.436 J5.238 E.05765
G2 X148.015 Y116.604 I17.389 J-26.549 E.12888
G2 X150.332 Y117.514 I10.348 J-22.931 E.0826
G3 X152.669 Y118.351 I-5.674 J19.531 E.08241
G3 X153.961 Y119.348 I-2.503 J4.58 E.05437
G2 X156.837 Y121.957 I22.737 J-22.171 E.12888
G2 X158.902 Y123.348 I15.069 J-20.151 E.08263
G3 X160.841 Y124.544 I-11.526 J20.845 E.07559
G3 X161.85 Y125.632 I-2.665 J3.485 E.04948
G2 X163.68 Y128.324 I49.868 J-31.931 E.10797
G2 X166.202 Y131.082 I16.837 J-12.864 E.12414
G3 X167.71 Y132.567 I-14.864 J16.598 E.07024
G3 X168.522 Y134.093 I-4.096 J3.158 E.05761
G1 X168.658 Y134.455 E.01281
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.138 J2.087 E.05195
G3 X88.162 Y131.747 I2.987 J2.221 E.03455
G2 X90.863 Y129.416 I-14.315 J-19.313 E.10972
G2 X93.249 Y125.974 I-11.005 J-10.177 E.12911
G3 X94.112 Y124.464 I12.336 J6.054 E.05348
G3 X94.828 Y123.939 I1.546 J1.358 E.0275
G2 X97.331 Y122.678 I-21.513 J-45.791 E.08611
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.512 Y118.382 I16.283 J15.667 E.07472
G3 X103.843 Y117.698 I2.997 J4.195 E.04616
G2 X106.326 Y116.856 I-155.869 J-463.662 E.08053
G2 X110.161 Y114.94 I-7.082 J-18.973 E.13198
G3 X112.029 Y113.845 I11.123 J16.83 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.546 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.361 J20.305 E.06952
G3 X123.486 Y111.206 I.614 J2.41 E.03527
G2 X125.869 Y111.616 I39.527 J-222.365 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.313 J24.955 E.06669
G3 X133.133 Y111.15 I.224 J2.462 E.00869
G3 X134.306 Y111.477 I-.407 J3.734 E.03757
G2 X137.615 Y112.726 I11.347 J-25.042 E.10877
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.525 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.05721
G2 X148.18 Y116.248 I17.23 J-26.292 E.11809
G2 X150.456 Y117.142 I10.163 J-22.526 E.07517
G3 X152.643 Y117.905 I-6.823 J23.094 E.07119
G3 X154.232 Y119.064 I-2.357 J4.897 E.06077
G2 X157.076 Y121.646 I22.52 J-21.948 E.11811
G2 X159.105 Y123.012 I14.801 J-19.797 E.07517
G3 X161.075 Y124.229 I-11.663 J21.075 E.07119
G3 X162.172 Y125.409 I-2.911 J3.809 E.04974
G2 X163.993 Y128.088 I49.775 J-31.867 E.09953
G2 X166.471 Y130.796 I16.518 J-12.622 E.11296
G3 X168.012 Y132.318 I-14.979 J16.723 E.06658
G3 X168.887 Y133.951 I-4.411 J3.413 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X151.192 Y135.51 Z3.8 F36000
G1 Z3.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X148.729 Y137.972 E.11551
G3 X152.298 Y142.079 I-21.47 J22.263 E.18072
G1 X164.508 Y129.869 E.57279
G3 X167.553 Y132.932 I-261.986 J263.517 E.14326
M73 P62 R6
G3 X168.093 Y133.96 I-8.411 J5.066 E.03856
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.502 J-3.232 E.00975
G1 X133.534 Y130.139 E.63753
G3 X135.125 Y130.484 I-2.495 J15.348 E.05402
; WIPE_START
G1 X133.534 Y130.139 E-.61855
G1 X133.797 Y129.876 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X141.39 Y130.656 Z3.8 F36000
G1 X155.136 Y132.07 Z3.8
G1 Z3.4
G1 E.8 F1800
G1 F15476.087
G3 X155.596 Y132.571 I-1.998 J2.297 E.02264
G1 X161.572 Y138.547 E.28033
G1 X156.88 Y141.53 E.18446
G1 X127.857 Y112.508 E1.3615
G2 X128.138 Y112.507 I.133 J-2.693 E.00933
G1 X99.181 Y141.464 E1.35844
G1 X94.573 Y138.397 E.18364
G1 X100.293 Y132.677 E.26832
G3 X100.936 Y131.991 I2.349 J1.559 E.03134
; WIPE_START
G1 X100.523 Y132.368 E-.21252
G1 X100.293 Y132.677 E-.14646
G1 X99.546 Y133.423 E-.40102
; WIPE_END
G1 E-.04 F1800
G1 X104.785 Y135.492 Z3.8 F36000
G1 Z3.4
G1 E.8 F1800
G1 F15476.087
G1 X107.252 Y137.958 E.11572
G2 X103.68 Y142.062 I21.494 J22.315 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.882 J-14.379 E.18439
G1 X101.141 Y131.847 E.31127
G1 X101.1 Y131.87 E.00156
G1 X120.021 Y112.948 E.88766
G1 X120.456 Y112.783 E.01543
G1 X128.677 Y121.004 E.38567
G2 X127.325 Y120.996 I-.691 J2.601 E.04532
G1 X135.538 Y112.784 E.38526
G1 X135.998 Y112.973 E.01652
G1 X154.973 Y131.948 E.89013
G2 X154.844 Y131.857 I-.379 J.404 E.00524
G1 X161.265 Y125.437 E.30121
G2 X160.005 Y124.422 I-3.03 J2.472 E.05403
; WIPE_START
G1 X160.782 Y124.94 E-.3549
G1 X161.265 Y125.437 E-.26296
G1 X161 Y125.701 E-.14215
; WIPE_END
G1 E-.04 F1800
G1 X153.471 Y126.951 Z3.8 F36000
G1 X112.9 Y133.689 Z3.8
G1 Z3.4
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.502 J13.621 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.18 I-19.498 J-25.076 E.15408
G3 X103.362 Y118.717 I2.109 J2.301 E.02678
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X125.419 Y122.903 E.4255
G2 X130.54 Y122.867 I2.566 J.656 E.32116
G1 X139.666 Y131.992 E.42809
G1 X139.447 Y131.902 E.00784
G1 X152.623 Y118.726 E.61812
G3 X153.358 Y119.263 I-2.175 J3.741 E.03024
G2 X156.721 Y122.304 I27.788 J-27.352 E.1505
M73 P63 R6
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.249 J13.204 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X138.234 Y130.288 Z3.8 F36000
G1 X112.541 Y114.437 Z3.8
G1 Z3.4
G1 E.8 F1800
G1 F15476.087
G3 X114.137 Y114.139 I2.485 J8.902 E.05391
G1 X129.657 Y129.659 E.72808
G2 X126.34 Y129.657 I-1.673 J20.581 E.11013
G1 X141.856 Y114.141 E.72787
G3 X143.449 Y114.447 I-.8 J8.482 E.0539
G1 X88.609 Y134.427 F36000
G1 F15476.087
G1 X89.965 Y135.329 E.05401
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.315 J-2.779 E.00843
G1 X122.456 Y130.135 E.63779
G2 X120.865 Y130.479 I2.482 J15.347 E.05402
; CHANGE_LAYER
; Z_HEIGHT: 3.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X122.456 Y130.135 E-.61855
G1 X122.193 Y129.872 E-.14145
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
G1 X127.002 Y121.479
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.029 Y121.47 E.00093
G3 X127.771 Y121.272 I.955 J2.09 E.0256
G3 X130.119 Y122.712 I.227 J2.265 E.09814
G3 X126.741 Y121.627 I-2.136 J.848 E.34449
G1 X126.95 Y121.508 E.00798
G1 X127.177 Y121.83 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.193 Y121.829 E.00048
G3 X127.799 Y121.663 I.799 J1.732 E.0194
G3 X128.777 Y121.823 I.199 J1.858 E.03082
G3 X126.955 Y121.96 I-.785 J1.738 E.30967
G1 X127.125 Y121.86 E.00607
; WIPE_START
M204 S10000
G1 X127.193 Y121.829 E-.02822
G1 X127.445 Y121.728 E-.1034
G1 X127.799 Y121.663 E-.13669
G1 X127.983 Y121.65 E-.07023
G1 X128.255 Y121.67 E-.10357
G1 X128.522 Y121.728 E-.10361
G1 X128.777 Y121.823 E-.10356
G1 X129.016 Y121.953 E-.10358
G1 X129.031 Y121.965 E-.00714
; WIPE_END
G1 E-.04 F1800
G1 X122.156 Y125.28 Z4 F36000
G1 X100.77 Y135.591 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.597 Y135.346 E.00996
G3 X102.315 Y131.816 I1.939 J-1.239 E.15596
G3 X103.773 Y132.167 I.207 J2.345 E.05061
G3 X100.813 Y135.632 I-1.237 J1.94 E.26099
G1 X101.09 Y135.351 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.343 Y132.208 I1.446 J-1.245 E.12786
G3 X103.321 Y132.367 I.199 J1.858 E.03081
G3 X101.129 Y135.396 I-.786 J1.739 E.20791
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12622
G1 X100.759 Y134.816 E-.13667
G1 X100.694 Y134.643 E-.07023
G1 X100.637 Y134.377 E-.10357
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10358
G1 X100.706 Y133.536 E-.01254
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.309 Z4 F36000
G1 X152.509 Y132 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.792 Y131.901 E.00996
G3 X153.227 Y131.816 I.655 J2.205 E.01472
G3 X154.685 Y132.167 I.207 J2.345 E.05061
G3 X152.457 Y132.03 I-1.237 J1.94 E.40224
G1 X152.63 Y132.375 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.649 Y132.373 E.00056
G3 X153.255 Y132.208 I.799 J1.732 E.01941
G3 X154.233 Y132.367 I.199 J1.858 E.03082
G3 X152.411 Y132.504 I-.785 J1.738 E.30967
G1 X152.579 Y132.406 E.00598
; WIPE_START
M204 S10000
G1 X152.649 Y132.373 E-.02933
G1 X152.901 Y132.272 E-.10339
G1 X153.255 Y132.208 E-.1367
G1 X153.439 Y132.194 E-.07022
G1 X153.711 Y132.214 E-.10359
G1 X153.978 Y132.272 E-.10359
G1 X154.233 Y132.367 E-.10357
G1 X154.472 Y132.498 E-.10359
G1 X154.485 Y132.507 E-.00601
; WIPE_END
G1 E-.04 F1800
G1 X153.712 Y140.1 Z4 F36000
G1 X153.292 Y144.224 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.39 J1.747 E.04339
G3 X88.408 Y132.053 I2.738 J2.13 E.03249
G2 X91.148 Y129.685 I-14.52 J-19.573 E.12022
G2 X93.594 Y126.159 I-11.288 J-10.444 E.14282
G3 X94.42 Y124.708 I12.308 J6.041 E.05543
G3 X95.013 Y124.286 I1.249 J1.127 E.02432
G2 X97.525 Y123.019 I-21.47 J-45.701 E.09335
G2 X101.007 Y120.323 I-8.606 J-14.71 E.14647
G3 X102.746 Y118.697 I16.212 J15.594 E.07902
G3 X103.976 Y118.067 I2.75 J3.856 E.04601
G2 X107.047 Y116.997 I-16.539 J-52.428 E.1079
G2 X110.366 Y115.274 I-7.762 J-19.009 E.12423
G3 X112.192 Y114.201 I10.964 J16.574 E.07027
G3 X113.876 Y113.812 I2.035 J4.968 E.05758
G2 X117.401 Y113.355 I-2.348 J-31.915 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.57 E.10417
G3 X122.452 Y111.606 I9.396 J20.386 E.07348
G3 X123.43 Y111.594 I.513 J2.043 E.03276
G2 X125.813 Y112.005 I37.873 J-212.782 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.883 Y111.551 I5.296 J24.855 E.07087
G3 X133.119 Y111.542 I.191 J2.063 E.00784
G3 X134.227 Y111.868 I-.423 J3.491 E.0385
G2 X137.511 Y113.104 I11.112 J-24.53 E.11647
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.068 Y113.962 I-1.514 J22.33 E.07914
G3 X144.643 Y114.679 I-1.436 J5.238 E.05764
G2 X148.014 Y116.603 I17.394 J-26.557 E.12885
G2 X150.332 Y117.514 I10.345 J-22.922 E.08264
G3 X152.669 Y118.351 I-5.676 J19.535 E.0824
G3 X153.962 Y119.349 I-2.503 J4.581 E.0544
G2 X156.837 Y121.957 I22.727 J-22.161 E.12885
G2 X158.902 Y123.348 I15.07 J-20.153 E.08263
G3 X161.003 Y124.671 I-9.761 J17.831 E.08241
G3 X161.85 Y125.632 I-2.915 J3.421 E.04263
G2 X163.68 Y128.324 I49.894 J-31.949 E.10799
G2 X166.202 Y131.082 I16.837 J-12.865 E.12414
G3 X167.71 Y132.568 I-14.855 J16.589 E.07025
G3 X168.522 Y134.093 I-4.098 J3.158 E.05758
G1 X168.658 Y134.455 E.01282
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.134 J2.086 E.05195
G3 X88.163 Y131.747 I2.991 J2.225 E.03455
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10971
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.338 J6.055 E.05348
G3 X94.828 Y123.94 I1.545 J1.357 E.02749
G2 X97.331 Y122.678 I-21.512 J-45.791 E.08612
G2 X100.735 Y120.04 I-8.413 J-14.372 E.13271
G3 X102.511 Y118.382 I16.286 J15.67 E.0747
G3 X103.844 Y117.698 I2.998 J4.195 E.04619
G2 X106.325 Y116.856 I-157.081 J-467.237 E.08052
G2 X110.161 Y114.94 I-7.082 J-18.973 E.13198
G3 X112.029 Y113.845 I11.121 J16.829 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.543 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.359 J20.3 E.06953
G3 X123.486 Y111.206 I.613 J2.411 E.03526
G2 X125.869 Y111.616 I39.572 J-222.629 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.313 J24.956 E.06669
G3 X133.132 Y111.15 I.224 J2.46 E.00864
G3 X134.376 Y111.505 I-.426 J3.855 E.03993
G2 X137.615 Y112.726 I10.994 J-24.251 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.522 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.05721
G2 X148.18 Y116.248 I17.23 J-26.292 E.11809
G2 X150.457 Y117.142 I10.159 J-22.516 E.07518
G3 X152.643 Y117.905 I-6.824 J23.097 E.07118
G3 X154.232 Y119.065 I-2.357 J4.898 E.06079
G2 X157.076 Y121.646 I22.515 J-21.942 E.11809
G2 X159.105 Y123.012 I14.8 J-19.797 E.07517
G3 X161.075 Y124.23 I-11.649 J21.053 E.0712
G3 X162.172 Y125.409 I-2.911 J3.809 E.04973
G2 X163.993 Y128.088 I49.771 J-31.864 E.09953
G2 X166.471 Y130.796 I16.517 J-12.621 E.11296
G3 X168.013 Y132.318 I-14.971 J16.714 E.06659
G3 X168.887 Y133.951 I-4.413 J3.413 E.05719
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X147.22 Y137.207 Z4 F36000
G1 X145.8 Y135.493 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X144.466 Y134.559 I-9.583 J12.27 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.357 Y119.262 I24.432 J-30.401 E.15054
G2 X152.623 Y118.726 I-2.907 J3.203 E.03019
G1 X139.447 Y131.902 E.61812
G1 X139.666 Y131.992 E.00784
G1 X130.54 Y122.867 E.42809
G3 X125.419 Y122.903 I-2.556 J.675 E.31963
G1 X116.349 Y131.973 E.4255
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.449 J2.763 E.02678
G3 X99.258 Y122.288 I-22.944 J-21.968 E.15408
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.885 J12.762 E.05403
G1 X120.865 Y130.479 F36000
G1 F15476.087
G3 X122.456 Y130.135 I4.073 J15.003 E.05402
G1 X108.861 Y116.54 E.63779
G3 X108.636 Y116.657 I-1.538 J-2.659 E.00843
G1 X89.965 Y135.329 E.87592
G1 X88.609 Y134.427 E.05401
G1 X100.936 Y131.991 F36000
G1 F15476.087
G2 X100.293 Y132.677 I4.338 J4.715 E.03123
G1 X94.573 Y138.397 E.26832
G1 X99.181 Y141.464 E.18364
G1 X128.138 Y112.507 E1.35844
G3 X127.857 Y112.508 I-.148 J-2.692 E.00933
G1 X156.88 Y141.53 E1.3615
G1 X161.572 Y138.547 E.18446
G1 X155.597 Y132.571 E.28033
G2 X155.136 Y132.07 I-2.459 J1.796 E.02264
G1 X160.005 Y124.422 F36000
G1 F15476.087
G3 X161.265 Y125.437 I-1.77 J3.486 E.05403
G1 X154.844 Y131.857 E.3012
G3 X154.973 Y131.948 I-.25 J.493 E.00524
G1 X135.998 Y112.973 E.89013
G1 X135.538 Y112.784 E.01652
G1 X127.325 Y120.996 E.38526
G3 X128.677 Y121.004 I.661 J2.613 E.04532
G1 X120.456 Y112.783 E.38567
G1 X120.021 Y112.948 E.01543
G1 X101.1 Y131.87 E.88766
G1 X101.141 Y131.847 E.00156
G1 X94.506 Y125.212 E.31127
G3 X91.467 Y129.849 I-19.924 J-9.744 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.064 J18.209 E.18071
G1 X104.785 Y135.492 E.11572
; WIPE_START
G1 X106.199 Y136.906 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X113.65 Y135.252 Z4 F36000
G1 X135.125 Y130.484 Z4
G1 Z3.6
G1 E.8 F1800
G1 F15476.087
G2 X133.534 Y130.139 I-4.085 J15.003 E.05402
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.763 J-3.098 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02426
G1 X168.093 Y133.96 E.0568
G2 X167.03 Y132.345 I-4.208 J1.609 E.06465
G3 X164.508 Y129.869 I23.14 J-26.101 E.11729
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.039 J18.156 E.18072
G1 X151.192 Y135.51 E.11551
G1 X143.449 Y114.447 F36000
G1 F15476.087
G2 X141.856 Y114.141 I-2.393 J8.174 E.0539
G1 X126.34 Y129.657 E.72787
G3 X129.657 Y129.659 I1.643 J20.583 E.11013
G1 X114.137 Y114.139 E.72808
G2 X112.541 Y114.437 I.888 J9.193 E.05391
; CHANGE_LAYER
; Z_HEIGHT: 3.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X112.968 Y114.304 E-.16976
G1 X114.137 Y114.139 E-.44857
G1 X114.4 Y114.403 E-.14166
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
G1 X127.002 Y121.479
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.029 Y121.47 E.00093
G3 X127.761 Y121.273 I.955 J2.09 E.02528
G3 X130.116 Y122.703 I.222 J2.288 E.09799
G3 X126.741 Y121.627 I-2.132 J.857 E.34482
G1 X126.95 Y121.508 E.00798
G1 X127.175 Y121.831 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.192 Y121.829 E.00053
G3 X127.789 Y121.664 I.799 J1.733 E.01911
G3 X128.777 Y121.823 I.207 J1.861 E.03111
G3 X126.954 Y121.959 I-.786 J1.739 E.30988
G1 X127.123 Y121.861 E.00601
; WIPE_START
M204 S10000
G1 X127.192 Y121.829 E-.02898
G1 X127.445 Y121.728 E-.10342
G1 X127.789 Y121.664 E-.13303
G1 X127.983 Y121.65 E-.07391
G1 X128.255 Y121.67 E-.10361
G1 X128.522 Y121.728 E-.10356
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.954 E-.1036
G1 X129.03 Y121.963 E-.00632
; WIPE_END
G1 E-.04 F1800
G1 X122.16 Y125.29 Z4.2 F36000
G1 X100.806 Y135.633 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.792 Y135.609 E.00094
G3 X102.306 Y131.817 I1.743 J-1.502 E.16655
G3 X103.773 Y132.167 I.216 J2.346 E.05094
G3 X101.023 Y135.841 I-1.238 J1.94 E.25115
G1 X100.85 Y135.675 E.00797
G1 X101.09 Y135.351 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.334 Y132.208 I1.445 J-1.245 E.12757
G3 X103.321 Y132.367 I.208 J1.86 E.03111
G3 X101.13 Y135.396 I-.786 J1.738 E.20783
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12619
G1 X100.762 Y134.825 E-.13302
G1 X100.694 Y134.643 E-.07392
G1 X100.637 Y134.377 E-.10357
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.1036
G1 X100.694 Y133.567 E-.10358
G1 X100.706 Y133.536 E-.01253
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.313 Z4.2 F36000
G1 X152.458 Y132.023 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.485 Y132.016 E.00094
G3 X153.217 Y131.817 I.961 J2.09 E.02527
G3 X154.685 Y132.167 I.216 J2.346 E.05093
G3 X152.198 Y132.174 I-1.238 J1.94 E.39243
G1 X152.406 Y132.053 E.00797
G1 X152.628 Y132.377 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.648 Y132.373 E.00063
G3 X153.245 Y132.208 I.799 J1.731 E.01911
G3 X154.233 Y132.367 I.208 J1.861 E.03112
G3 X152.41 Y132.504 I-.786 J1.737 E.30957
G1 X152.576 Y132.407 E.0059
; WIPE_START
M204 S10000
G1 X152.648 Y132.373 E-.03029
G1 X152.901 Y132.272 E-.1034
G1 X153.245 Y132.208 E-.13304
G1 X153.439 Y132.194 E-.07391
G1 X153.711 Y132.214 E-.1036
G1 X153.978 Y132.272 E-.10357
G1 X154.233 Y132.367 E-.10358
G1 X154.472 Y132.498 E-.10357
G1 X154.483 Y132.506 E-.00503
; WIPE_END
G1 E-.04 F1800
G1 X153.711 Y140.099 Z4.2 F36000
G1 X153.292 Y144.224 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98338
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.396 J1.749 E.04338
G3 X88.408 Y132.052 I2.736 J2.127 E.0325
G2 X91.148 Y129.685 I-14.518 J-19.57 E.12022
G2 X93.594 Y126.159 I-11.288 J-10.444 E.14282
G3 X94.42 Y124.708 I12.303 J6.038 E.05543
G3 X95.013 Y124.286 I1.249 J1.126 E.02434
G2 X97.525 Y123.019 I-21.467 J-45.695 E.09334
G2 X101.007 Y120.323 I-8.606 J-14.71 E.14647
G3 X102.746 Y118.696 I16.209 J15.591 E.07904
G3 X103.976 Y118.067 I2.749 J3.855 E.04601
G2 X107.047 Y116.997 I-16.542 J-52.435 E.10789
G2 X110.366 Y115.274 I-7.762 J-19.008 E.12423
M73 P64 R6
G3 X112.192 Y114.201 I10.976 J16.594 E.07026
G3 X113.876 Y113.812 I2.035 J4.969 E.05759
G2 X117.401 Y113.355 I-2.348 J-31.92 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.57 E.10417
G3 X122.451 Y111.606 I9.406 J20.409 E.07346
G3 X123.43 Y111.594 I.514 J2.043 E.03279
G2 X125.813 Y112.005 I37.921 J-213.06 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.298 J24.869 E.07086
G3 X133.117 Y111.542 I.192 J2.065 E.0078
G3 X134.227 Y111.868 I-.418 J3.483 E.03854
G2 X137.511 Y113.104 I11.111 J-24.528 E.11648
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.068 Y113.962 I-1.514 J22.332 E.07914
G3 X144.643 Y114.679 I-1.436 J5.238 E.05764
G2 X148.015 Y116.604 I17.39 J-26.551 E.12888
G2 X150.332 Y117.514 I10.346 J-22.926 E.08261
G3 X152.669 Y118.351 I-5.676 J19.535 E.0824
G3 X153.962 Y119.349 I-2.505 J4.583 E.05441
G2 X156.837 Y121.957 I22.727 J-22.16 E.12884
G2 X158.902 Y123.348 I15.073 J-20.156 E.08263
G3 X161.004 Y124.671 I-9.758 J17.827 E.08242
G3 X161.851 Y125.634 I-2.918 J3.423 E.04271
G2 X163.68 Y128.324 I49.819 J-31.899 E.1079
G2 X166.202 Y131.082 I16.836 J-12.863 E.12415
G3 X167.71 Y132.567 I-14.859 J16.593 E.07023
G3 X168.522 Y134.093 I-4.096 J3.157 E.0576
G1 X168.658 Y134.455 E.01281
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.782 E1.86611
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.137 J2.086 E.05194
G3 X88.163 Y131.747 I2.988 J2.222 E.03456
G2 X90.863 Y129.416 I-14.314 J-19.311 E.10972
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.334 J6.053 E.05348
G3 X94.829 Y123.939 I1.546 J1.357 E.0275
G2 X97.331 Y122.678 I-21.507 J-45.78 E.08611
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.512 Y118.382 I16.287 J15.671 E.07471
G3 X103.844 Y117.698 I2.997 J4.195 E.04618
G2 X106.325 Y116.856 I-155.744 J-463.295 E.08052
G2 X110.161 Y114.94 I-7.083 J-18.974 E.13198
G3 X112.029 Y113.845 I11.123 J16.83 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05719
G2 X117.323 Y112.971 I-2.31 J-31.548 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.361 J20.306 E.06952
G3 X123.486 Y111.206 I.614 J2.411 E.03528
G2 X125.869 Y111.616 I39.525 J-222.357 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.315 J24.967 E.06668
G3 X133.13 Y111.15 I.224 J2.462 E.00859
G3 X134.376 Y111.505 I-.422 J3.848 E.03998
G2 X137.615 Y112.726 I10.992 J-24.245 E.10646
G2 X140.743 Y113.284 I5.04 J-19.215 E.09773
G3 X143.156 Y113.579 I-1.533 J22.523 E.07474
G3 X144.845 Y114.343 I-1.516 J5.602 E.0572
G2 X148.18 Y116.248 I17.23 J-26.292 E.11809
G2 X150.457 Y117.142 I10.161 J-22.523 E.07518
G3 X152.643 Y117.905 I-6.825 J23.098 E.07119
G3 X154.233 Y119.065 I-2.358 J4.899 E.06079
G2 X157.076 Y121.646 I22.514 J-21.942 E.11808
G2 X159.105 Y123.012 I14.799 J-19.794 E.07517
G3 X161.075 Y124.229 I-11.662 J21.074 E.07119
G3 X162.173 Y125.409 I-2.911 J3.81 E.04976
G2 X163.993 Y128.088 I49.754 J-31.853 E.0995
G2 X166.471 Y130.796 I16.517 J-12.621 E.11296
G3 X168.013 Y132.318 I-14.98 J16.724 E.06658
G3 X168.887 Y133.951 I-4.411 J3.412 E.05719
G1 X169.137 Y134.615 E.02179
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X151.192 Y135.51 Z4.2 F36000
G1 Z3.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X148.729 Y137.972 E.11551
G3 X152.298 Y142.079 I-21.47 J22.263 E.18072
G1 X164.508 Y129.869 E.57279
G3 X167.553 Y132.932 I-262.726 J264.257 E.14326
G3 X168.093 Y133.96 I-8.433 J5.078 E.03856
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.497 J-3.223 E.00975
G1 X133.534 Y130.139 E.63753
G3 X135.125 Y130.484 I-2.495 J15.348 E.05402
; WIPE_START
G1 X133.534 Y130.139 E-.61855
G1 X133.797 Y129.876 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X141.39 Y130.656 Z4.2 F36000
G1 X155.136 Y132.07 Z4.2
G1 Z3.8
G1 E.8 F1800
G1 F15476.087
G3 X155.596 Y132.571 I-1.997 J2.296 E.02264
G1 X161.572 Y138.547 E.28033
G1 X156.88 Y141.53 E.18446
G1 X127.857 Y112.508 E1.36151
G2 X128.138 Y112.507 I.133 J-2.689 E.00933
G1 X99.181 Y141.464 E1.35844
G1 X100.537 Y142.367 E.05401
G1 X104.785 Y135.492 F36000
G1 F15476.087
G1 X107.252 Y137.958 E.11572
G2 X103.68 Y142.062 I21.494 J22.315 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.886 J-14.381 E.18439
G1 X101.141 Y131.847 E.31127
G1 X101.1 Y131.87 E.00156
G1 X120.021 Y112.948 E.88765
G1 X120.456 Y112.783 E.01543
G1 X128.677 Y121.004 E.38567
G2 X127.323 Y120.999 I-.689 J3.21 E.04525
G1 X135.538 Y112.784 E.38539
G1 X135.998 Y112.973 E.01652
G1 X154.973 Y131.948 E.89013
G2 X154.844 Y131.857 I-.379 J.403 E.00524
G1 X161.264 Y125.437 E.30118
G2 X160.005 Y124.422 I-3.679 J3.274 E.05389
; WIPE_START
G1 X160.782 Y124.94 E-.35498
G1 X161.264 Y125.437 E-.26297
G1 X161 Y125.701 E-.14206
; WIPE_END
G1 E-.04 F1800
G1 X153.47 Y126.952 Z4.2 F36000
G1 X112.9 Y133.689 Z4.2
G1 Z3.8
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.502 J13.621 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.18 I-19.499 J-25.078 E.15408
G3 X103.362 Y118.717 I2.109 J2.302 E.02678
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X125.419 Y122.903 E.4255
G2 X130.54 Y122.867 I2.565 J.64 E.31963
G1 X139.666 Y131.992 E.42809
G1 X139.447 Y131.902 E.00785
G1 X152.623 Y118.726 E.61812
G3 X153.357 Y119.262 I-2.175 J3.742 E.0302
G2 X156.721 Y122.304 I27.794 J-27.357 E.15054
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.249 J13.204 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X138.234 Y130.288 Z4.2 F36000
G1 X112.541 Y114.437 Z4.2
G1 Z3.8
G1 E.8 F1800
G1 F15476.087
G3 X114.137 Y114.139 I2.484 J8.897 E.05391
G1 X129.657 Y129.659 E.72808
G2 X126.34 Y129.657 I-1.673 J20.583 E.11013
G1 X141.856 Y114.141 E.72787
G3 X143.449 Y114.447 I-.8 J8.479 E.0539
G1 X100.936 Y131.991 F36000
G1 F15476.087
G2 X100.293 Y132.677 I4.341 J4.718 E.03123
G1 X94.573 Y138.397 E.26832
G1 X89.965 Y135.329 E.18364
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.312 J-2.774 E.00842
G1 X122.456 Y130.135 E.63778
G2 X120.865 Y130.479 I2.482 J15.347 E.05402
; CHANGE_LAYER
; Z_HEIGHT: 4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X122.456 Y130.135 E-.61855
G1 X122.193 Y129.872 E-.14145
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
G1 X127.002 Y121.478
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.03 Y121.472 E.00093
G3 X127.752 Y121.274 I.961 J2.09 E.02495
G3 X129.229 Y121.623 I.225 J2.348 E.05126
G3 X126.742 Y121.63 I-1.238 J1.939 E.39234
G1 X126.951 Y121.509 E.00799
G1 X127.173 Y121.832 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.192 Y121.828 E.00059
G3 X127.78 Y121.665 I.798 J1.732 E.01882
G3 X128.777 Y121.823 I.216 J1.863 E.03142
G3 X126.954 Y121.959 I-.787 J1.737 E.30958
G1 X127.122 Y121.862 E.00595
; WIPE_START
M204 S10000
G1 X127.192 Y121.828 E-.02975
G1 X127.445 Y121.728 E-.10342
G1 X127.78 Y121.665 E-.12936
G1 X127.984 Y121.65 E-.07763
G1 X128.255 Y121.67 E-.10355
G1 X128.522 Y121.728 E-.1036
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.953 E-.1036
G1 X129.028 Y121.962 E-.00552
; WIPE_END
G1 E-.04 F1800
G1 X122.153 Y125.278 Z4.4 F36000
G1 X100.77 Y135.592 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.596 Y135.346 E.00998
G3 X102.296 Y131.818 I1.939 J-1.24 E.15539
G3 X103.773 Y132.167 I.225 J2.348 E.05126
G3 X100.813 Y135.633 I-1.238 J1.939 E.26095
G1 X101.09 Y135.35 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.324 Y132.209 I1.444 J-1.246 E.12729
G3 X103.321 Y132.367 I.216 J1.863 E.03141
G3 X101.13 Y135.395 I-.787 J1.738 E.20772
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.1262
G1 X100.766 Y134.834 E-.12936
G1 X100.694 Y134.643 E-.07761
G1 X100.637 Y134.377 E-.10358
G1 X100.617 Y134.105 E-.10356
G1 X100.637 Y133.833 E-.10363
G1 X100.694 Y133.567 E-.10356
G1 X100.706 Y133.536 E-.0125
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.313 Z4.4 F36000
G1 X152.458 Y132.023 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.484 Y132.014 E.00092
G3 X153.208 Y131.818 I.955 J2.091 E.02496
G3 X154.481 Y132.056 I.227 J2.312 E.04354
G3 X152.196 Y132.171 I-1.042 J2.049 E.3997
G1 X152.406 Y132.052 E.008
G1 X152.626 Y132.378 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.648 Y132.372 E.00071
G3 X153.236 Y132.209 I.798 J1.732 E.01882
G3 X154.233 Y132.367 I.216 J1.864 E.03142
G3 X152.41 Y132.503 I-.787 J1.737 E.30958
G1 X152.574 Y132.408 E.00583
; WIPE_START
M204 S10000
G1 X152.648 Y132.372 E-.03126
G1 X152.901 Y132.272 E-.10342
G1 X153.236 Y132.209 E-.12936
G1 X153.439 Y132.194 E-.0776
G1 X153.711 Y132.214 E-.1036
G1 X153.978 Y132.272 E-.10357
G1 X154.233 Y132.367 E-.10358
G1 X154.472 Y132.498 E-.10359
G1 X154.481 Y132.504 E-.00401
; WIPE_END
G1 E-.04 F1800
G1 X153.71 Y140.097 Z4.4 F36000
G1 X153.292 Y144.224 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.388 J1.747 E.04339
G3 X88.409 Y132.052 I2.738 J2.13 E.0325
G2 X91.148 Y129.685 I-14.52 J-19.571 E.12021
G2 X93.594 Y126.16 I-11.287 J-10.443 E.14279
G3 X94.42 Y124.708 I12.321 J6.047 E.05546
G3 X95.012 Y124.286 I1.249 J1.126 E.02432
G2 X97.525 Y123.019 I-21.479 J-45.719 E.09336
G2 X101.007 Y120.323 I-8.606 J-14.71 E.14647
G3 X102.746 Y118.697 I16.209 J15.591 E.07903
G3 X103.977 Y118.067 I2.75 J3.855 E.04603
G2 X107.047 Y116.997 I-16.525 J-52.387 E.10788
G2 X110.366 Y115.274 I-7.762 J-19.009 E.12422
G3 X112.192 Y114.201 I10.963 J16.572 E.07027
G3 X113.876 Y113.812 I2.035 J4.969 E.05758
G2 X117.401 Y113.355 I-2.348 J-31.921 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.57 E.10417
G3 X122.452 Y111.605 I9.395 J20.384 E.07349
G3 X123.43 Y111.594 I.513 J2.043 E.03275
G2 X125.813 Y112.005 I37.94 J-213.171 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.298 J24.867 E.07086
G3 X133.116 Y111.542 I.192 J2.076 E.00775
G3 X134.146 Y111.835 I-.386 J3.319 E.03567
G2 X137.511 Y113.104 I11.525 J-25.456 E.11939
G2 X140.701 Y113.674 I5.146 J-19.603 E.10762
G3 X143.068 Y113.962 I-1.514 J22.335 E.07914
G3 X144.643 Y114.679 I-1.436 J5.238 E.05764
G2 X148.015 Y116.604 I17.39 J-26.551 E.12888
G2 X150.332 Y117.514 I10.346 J-22.926 E.08261
G3 X152.669 Y118.351 I-5.674 J19.529 E.08241
G3 X153.962 Y119.349 I-2.505 J4.583 E.0544
G2 X156.837 Y121.957 I22.727 J-22.16 E.12884
G2 X158.902 Y123.348 I15.071 J-20.155 E.08263
G3 X161.004 Y124.671 I-9.763 J17.834 E.08242
G3 X161.85 Y125.632 I-2.917 J3.422 E.04262
G2 X163.68 Y128.324 I49.858 J-31.924 E.10799
G2 X166.202 Y131.082 I16.835 J-12.863 E.12414
G3 X167.71 Y132.568 I-14.871 J16.605 E.07025
G3 X168.522 Y134.093 I-4.097 J3.158 E.05759
G1 X168.658 Y134.455 E.01281
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.133 J2.085 E.05196
G3 X88.163 Y131.747 I2.991 J2.225 E.03455
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10971
G2 X93.249 Y125.974 I-11.005 J-10.177 E.12911
G3 X94.112 Y124.465 I12.338 J6.055 E.05347
G3 X94.828 Y123.94 I1.545 J1.357 E.02749
G2 X97.331 Y122.678 I-21.529 J-45.824 E.08613
G2 X100.735 Y120.04 I-8.413 J-14.372 E.13271
G3 X102.512 Y118.382 I16.285 J15.668 E.0747
G3 X103.844 Y117.698 I2.998 J4.196 E.0462
G2 X106.326 Y116.856 I-155.131 J-461.497 E.08051
G2 X110.16 Y114.94 I-7.082 J-18.973 E.13197
G3 X112.029 Y113.845 I11.124 J16.833 E.06659
G3 X113.833 Y113.423 I2.199 J5.333 E.05718
G2 X117.323 Y112.971 I-2.31 J-31.548 E.10817
G2 X120.25 Y112.069 I-3.379 J-16.163 E.09424
G3 X122.349 Y111.227 I9.355 J20.29 E.06954
G3 X123.486 Y111.206 I.613 J2.411 E.03525
G2 X125.869 Y111.616 I39.527 J-222.365 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.315 J24.966 E.06668
G3 X133.128 Y111.15 I.224 J2.463 E.00854
G3 X134.293 Y111.471 I-.392 J3.694 E.0373
G2 X137.615 Y112.726 I11.41 J-25.184 E.10919
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.522 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.0572
G2 X148.18 Y116.248 I17.23 J-26.292 E.11809
G2 X150.457 Y117.142 I10.161 J-22.523 E.07518
G3 X152.644 Y117.905 I-6.825 J23.099 E.07119
G3 X154.233 Y119.065 I-2.359 J4.899 E.06079
G2 X157.076 Y121.646 I22.514 J-21.942 E.11808
G2 X159.105 Y123.012 I14.797 J-19.792 E.07517
G3 X161.075 Y124.23 I-11.66 J21.07 E.0712
G3 X162.172 Y125.408 I-2.957 J3.852 E.04971
G2 X163.993 Y128.088 I49.787 J-31.874 E.09954
G2 X166.471 Y130.796 I16.517 J-12.621 E.11296
G3 X168.013 Y132.318 I-14.984 J16.727 E.06658
G3 X168.887 Y133.951 I-4.411 J3.413 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X152.276 Y136.496 Z4.4 F36000
G1 Z4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X151.71 Y136.132 E.01865
G3 X151.155 Y135.454 I1.428 J-1.734 E.02442
G1 X151.041 Y135.945 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X152.211 Y136.862 I2.336 J-1.778 E.04984
G1 X156.88 Y141.53 E.21903
G1 X161.572 Y138.547 E.18446
G1 X156.367 Y133.342 E.24418
G1 X156.469 Y133.808 E.01581
G1 X156.068 Y133.774 E.01332
G1 X156.079 Y133.924 E.00499
G1 X156.165 Y133.786 E.00541
G1 X156.452 Y133.857 E.00981
G1 X156.462 Y133.997 E.00467
G1 X156.024 Y134.689 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X155.946 Y134.969 E.00804
G1 X155.693 Y135.528 E.01702
G3 X154.143 Y136.666 I-2.255 J-1.448 E.05448
; Slow Down End
; WIPE_START
G1 X154.557 Y136.526 E-.16619
G1 X154.89 Y136.342 E-.14448
G1 X155.194 Y136.113 E-.14463
G1 X155.462 Y135.843 E-.14451
G1 X155.693 Y135.528 E-.14821
G1 X155.706 Y135.5 E-.01198
; WIPE_END
G1 E-.04 F1800
G1 X150.794 Y133.817 Z4.4 F36000
G1 Z4
G1 E.8 F1800
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G3 X151.709 Y132.077 I2.693 J.305 E.05575
G1 X152.159 Y131.779 E.01494
; Slow Down End
G1 X154.254 Y131.572 F36000
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X154.88 Y131.874 E.01925
G3 X155.48 Y132.392 I-1.116 J1.897 E.02208
G1 X155.859 Y132.987 E.01956
G1 X155.977 Y133.351 E.01059
; Slow Down End
G1 X160.005 Y124.422 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X161.265 Y125.437 I-1.748 J3.459 E.05404
G1 X155.117 Y131.584 E.28841
G2 X154.202 Y131.177 I-3.617 J6.891 E.03324
G1 X135.998 Y112.973 E.85398
G1 X135.538 Y112.784 E.01652
G1 X127.777 Y120.545 E.36408
G3 X128.22 Y120.547 I.214 J1.544 E.01476
G1 X120.456 Y112.783 E.36424
G1 X120.021 Y112.948 E.01543
G1 X101.798 Y131.172 E.85491
G2 X100.866 Y131.572 I2.662 J7.475 E.03366
G1 X94.506 Y125.212 E.29837
G3 X91.467 Y129.849 I-19.925 J-9.744 E.18439
G1 X103.68 Y142.062 E.57295
G3 X104.096 Y141.508 I5.492 J3.696 E.023
G1 X103.827 Y141.239 E.01262
G3 X106.985 Y137.692 I20.954 J15.471 E.15777
M73 P65 R6
G1 X105.06 Y135.767 E.09031
G2 X105.286 Y135.359 I-9.961 J-5.799 E.01547
G1 X128.138 Y112.507 E1.07202
G3 X127.857 Y112.508 I-.148 J-2.689 E.00933
G1 X150.664 Y135.315 E1.06991
G2 X150.919 Y135.782 I4.453 J-2.122 E.01768
G1 X148.996 Y137.705 E.0902
G3 X152.14 Y141.24 I-20.53 J21.425 E.1571
G1 X151.871 Y141.509 E.01262
G3 X152.298 Y142.079 I-5.221 J4.362 E.02363
G1 X164.508 Y129.869 E.57279
G3 X167.552 Y132.93 I-269.671 J271.195 E.14318
G3 X168.093 Y133.96 I-8.347 J5.038 E.03864
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02425
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.497 J-3.223 E.00975
G1 X133.534 Y130.139 E.63753
G3 X135.125 Y130.484 I-2.495 J15.348 E.05402
G1 X130.28 Y125.037 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X129.935 Y125.419 E.01427
G1 X129.424 Y125.802 E.0177
G1 X128.972 Y126.021 E.0139
G1 X128.383 Y126.196 E.01702
G1 X127.99 Y126.217 E.0109
; Slow Down End
; WIPE_START
G1 X128.383 Y126.196 E-.14956
G1 X128.972 Y126.021 E-.23351
G1 X129.424 Y125.802 E-.19071
G1 X129.816 Y125.509 E-.18623
; WIPE_END
G1 E-.04 F1800
G1 X125.342 Y123.905 Z4.4 F36000
G1 Z4
G1 E.8 F1800
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G3 X126.253 Y121.533 I2.681 J-.332 E.07332
G3 X127.133 Y120.963 I13.353 J19.657 E.02905
G3 X128.342 Y120.919 I.935 J9.142 E.03354
G3 X130.244 Y122.151 I-.352 J2.628 E.06487
G1 X130.534 Y122.789 E.01942
G1 X130.62 Y123.333 E.01527
; Slow Down End
; WIPE_START
G1 X130.534 Y122.789 E-.20939
G1 X130.244 Y122.151 E-.26633
G1 X130.006 Y121.823 E-.154
G1 X129.765 Y121.58 E-.13028
; WIPE_END
G1 E-.04 F1800
G1 X125.497 Y121.837 Z4.4 F36000
G1 Z4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X124.967 Y123.354 I2.516 J1.73 E.05392
G1 X116.349 Y131.973 E.40432
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.452 J2.767 E.02677
G3 X99.258 Y122.288 I-22.95 J-21.974 E.15409
G1 X111.517 Y134.548 E.57511
G2 X110.183 Y135.481 I8.235 J13.2 E.05403
G1 X104.832 Y135.418 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X104.555 Y135.835 E.01388
G1 X104.265 Y136.127 E.0114
G1 X103.764 Y136.455 E.01659
G1 X101.876 Y136.684 F36000
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G3 X101.083 Y136.347 I.572 J-2.446 E.02402
G1 X100.574 Y135.962 E.01767
G1 X100.266 Y135.621 E.01274
; Slow Down End
G1 X99.881 Y134.014 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.887 Y133.937 E.00257
G1 X99.48 Y134.344 E.0191
G3 X99.592 Y133.378 I3.415 J-.093 E.03238
G1 X94.573 Y138.397 E.23546
G1 X99.181 Y141.464 E.18364
G1 X103.782 Y136.864 E.21582
G2 X104.938 Y135.93 I-1.244 J-2.723 E.04984
; WIPE_START
G1 X104.512 Y136.395 E-.23983
G1 X103.782 Y136.864 E-.32984
G1 X103.427 Y137.218 E-.19033
; WIPE_END
G1 E-.04 F1800
G1 X103.759 Y131.747 Z4.4 F36000
G1 Z4
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X104.257 Y132.077 E.01657
G3 X105.158 Y133.749 I-1.743 J2.017 E.05381
; Slow Down End
; WIPE_START
G1 X105.09 Y133.37 E-.14634
G1 X104.958 Y133.008 E-.14667
G1 X104.777 Y132.673 E-.14457
G1 X104.55 Y132.367 E-.1446
G1 X104.257 Y132.077 E-.15674
G1 X104.211 Y132.046 E-.02108
; WIPE_END
G1 E-.04 F1800
G1 X99.962 Y133.415 Z4.4 F36000
G1 Z4
G1 E.8 F1800
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G3 X100.54 Y132.33 I2.613 J.697 E.03436
G1 X101.077 Y131.869 E.0196
G3 X101.983 Y131.507 I1.416 J2.229 E.02719
; Slow Down End
; WIPE_START
G1 X101.795 Y131.541 E-.07241
G1 X101.43 Y131.675 E-.14776
G1 X101.077 Y131.869 E-.15318
G1 X100.54 Y132.33 E-.26889
G1 X100.351 Y132.575 E-.11776
; WIPE_END
G1 E-.04 F1800
G1 X103.532 Y139.514 Z4.4 F36000
G1 X104.309 Y141.208 Z4.4
G1 Z4
G1 E.8 F1800
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X104.696 Y140.703 E.01763
G3 X109.428 Y136.042 I23.974 J19.603 E.18438
; Slow Down End
; WIPE_START
G1 X109.126 Y136.273 E-.14466
G1 X107.933 Y137.292 E-.59618
G1 X107.896 Y137.327 E-.01915
; WIPE_END
G1 E-.04 F1800
G1 X114.646 Y133.764 Z4.4 F36000
G1 X120.873 Y130.477 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X121.446 Y130.339 E.01954
G1 X121.517 Y129.934 E.01363
G3 X122.133 Y129.811 I1.477 J5.792 E.02085
G1 X108.861 Y116.54 E.6226
G3 X108.636 Y116.657 I-1.538 J-2.659 E.00843
G1 X89.965 Y135.329 E.87592
G1 X88.609 Y134.427 E.05401
; WIPE_START
G1 X89.965 Y135.329 E-.61876
G1 X90.227 Y135.066 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X97.772 Y133.913 Z4.4 F36000
G1 X121.85 Y130.232 Z4.4
G1 Z4
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G3 X127.082 Y129.619 I5.93 J27.966 E.14615
; Slow Down End
; WIPE_START
G1 X126.415 Y129.637 E-.25349
G1 X125.086 Y129.741 E-.50651
; WIPE_END
G1 E-.04 F1800
G1 X132.44 Y131.783 Z4.4 F36000
G1 X145.8 Y135.493 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X144.466 Y134.559 I-9.571 J12.253 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.358 Y119.263 I24.411 J-30.377 E.15049
G2 X152.623 Y118.726 I-2.91 J3.204 E.03025
G1 X139.447 Y131.902 E.61812
G1 X139.666 Y131.992 E.00785
G1 X130.997 Y123.324 E.40665
G2 X130.451 Y121.813 I-3.776 J.51 E.05371
G1 X143.449 Y114.447 F36000
G1 F15476.087
G2 X141.856 Y114.141 I-2.393 J8.172 E.0539
G1 X126.732 Y129.266 E.70951
G1 X127.86 Y129.236 E.03743
G1 X127.95 Y129.532 E.01025
G1 X127.822 Y129.614 E.00507
G3 X129.657 Y129.659 I-.566 J60.329 E.0609
G1 X114.137 Y114.139 E.72808
G2 X112.541 Y114.437 I.889 J9.2 E.05391
; WIPE_START
G1 X112.968 Y114.304 E-.16972
G1 X114.137 Y114.139 E-.44862
G1 X114.4 Y114.403 E-.14166
; WIPE_END
G1 E-.04 F1800
G1 X120.732 Y118.665 Z4.4 F36000
G1 X146.492 Y136.006 Z4.4
G1 Z4
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X146.844 Y136.276 E.01231
G3 X151.622 Y141.161 I-19.439 J23.792 E.1897
; Slow Down End
; CHANGE_LAYER
; Z_HEIGHT: 4.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X151.271 Y140.703 E-.21929
G1 X150.347 Y139.621 E-.54071
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
G1 X127.052 Y121.456
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X127.336 Y121.356 E.00999
G3 X127.742 Y121.274 I.656 J2.205 E.01375
G3 X128.94 Y121.465 I.257 J2.245 E.04075
G3 X127 Y121.486 I-.948 J2.096 E.41305
G1 X127.172 Y121.833 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.192 Y121.828 E.00064
G3 X127.77 Y121.665 I.8 J1.733 E.01852
G3 X128.522 Y121.728 I.207 J2.067 E.02331
G3 X126.954 Y121.959 I-.53 J1.833 E.3182
G1 X127.12 Y121.863 E.00589
; WIPE_START
M204 S10000
G1 X127.192 Y121.828 E-.03049
G1 X127.445 Y121.728 E-.10345
G1 X127.77 Y121.665 E-.12568
G1 X127.984 Y121.65 E-.08132
G1 X128.255 Y121.67 E-.10354
G1 X128.522 Y121.728 E-.10361
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.954 E-.1036
G1 X129.026 Y121.961 E-.00474
; WIPE_END
G1 E-.04 F1800
G1 X122.152 Y125.277 Z4.6 F36000
G1 X100.77 Y135.592 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.595 Y135.347 E.00999
G3 X102.286 Y131.819 I1.934 J-1.243 E.15528
G3 X104.708 Y134.835 I.239 J2.288 E.15241
G3 X100.813 Y135.634 I-2.179 J-.731 E.15935
G1 X101.091 Y135.349 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.314 Y132.21 I1.444 J-1.245 E.12692
G3 X103.066 Y132.272 I.207 J2.068 E.0233
G3 X101.131 Y135.394 I-.53 J1.832 E.21613
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12617
G1 X100.79 Y134.899 E-.1036
G1 X100.694 Y134.643 E-.10356
G1 X100.637 Y134.377 E-.10358
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10358
G1 X100.706 Y133.536 E-.01231
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.31 Z4.6 F36000
G1 X152.508 Y132 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.792 Y131.9 E.01
G3 X153.198 Y131.819 I.656 J2.205 E.01375
G3 X154.396 Y132.009 I.257 J2.246 E.04075
G3 X152.456 Y132.03 I-.948 J2.096 E.41305
G1 X152.624 Y132.379 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.648 Y132.372 E.00078
G3 X153.226 Y132.21 I.8 J1.733 E.01852
G3 X153.978 Y132.272 I.207 J2.068 E.0233
G3 X152.41 Y132.503 I-.53 J1.833 E.3182
G1 X152.572 Y132.409 E.00575
; WIPE_START
M204 S10000
G1 X152.648 Y132.372 E-.03222
G1 X152.901 Y132.272 E-.10345
G1 X153.226 Y132.21 E-.12568
G1 X153.439 Y132.194 E-.0813
G1 X153.711 Y132.214 E-.10359
G1 X153.978 Y132.272 E-.10357
G1 X154.233 Y132.367 E-.10359
G1 X154.472 Y132.498 E-.10359
G1 X154.479 Y132.502 E-.00301
; WIPE_END
G1 E-.04 F1800
G1 X153.71 Y140.096 Z4.6 F36000
G1 X153.292 Y144.224 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98338
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.391 J1.748 E.04339
G3 X88.409 Y132.052 I2.736 J2.127 E.0325
G2 X91.148 Y129.685 I-14.523 J-19.575 E.12021
G2 X93.594 Y126.159 I-11.289 J-10.445 E.14282
G3 X94.42 Y124.708 I12.303 J6.038 E.05543
G3 X95.012 Y124.286 I1.249 J1.126 E.02432
G2 X97.525 Y123.019 I-21.477 J-45.714 E.09336
G2 X101.007 Y120.322 I-8.607 J-14.712 E.1465
G3 X102.746 Y118.697 I16.197 J15.579 E.07899
G3 X103.976 Y118.067 I2.75 J3.855 E.04603
G2 X107.047 Y116.997 I-16.521 J-52.376 E.10788
G2 X110.366 Y115.274 I-7.761 J-19.007 E.12423
G3 X112.192 Y114.202 I10.973 J16.59 E.07026
G3 X113.876 Y113.812 I2.035 J4.969 E.05759
G2 X117.401 Y113.355 I-2.348 J-31.917 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10415
G3 X122.452 Y111.606 I9.402 J20.399 E.07349
G3 X123.43 Y111.594 I.513 J2.043 E.03276
G2 X125.813 Y112.005 I37.893 J-212.901 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.298 J24.867 E.07086
G3 X133.114 Y111.542 I.192 J2.071 E.0077
G3 X134.227 Y111.868 I-.41 J3.469 E.03865
G2 X137.511 Y113.104 I11.112 J-24.53 E.11647
G2 X140.701 Y113.674 I5.146 J-19.603 E.10762
G3 X143.068 Y113.961 I-1.514 J22.333 E.07913
G3 X144.643 Y114.679 I-1.436 J5.238 E.05765
G2 X148.015 Y116.604 I17.396 J-26.562 E.12887
G2 X150.332 Y117.514 I10.345 J-22.922 E.08263
G3 X152.669 Y118.351 I-5.675 J19.532 E.08241
G3 X153.962 Y119.348 I-2.504 J4.581 E.05438
G2 X156.837 Y121.957 I22.729 J-22.162 E.12886
G2 X158.902 Y123.348 I15.068 J-20.149 E.08263
G3 X161.003 Y124.671 I-9.763 J17.834 E.08241
G3 X161.851 Y125.634 I-2.916 J3.421 E.0427
G2 X163.68 Y128.324 I49.84 J-31.913 E.10792
G2 X166.202 Y131.082 I16.837 J-12.864 E.12415
G3 X167.71 Y132.567 I-14.863 J16.596 E.07023
G3 X168.522 Y134.094 I-4.097 J3.158 E.05761
G1 X168.658 Y134.455 E.0128
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.782 E1.86611
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.134 J2.086 E.05195
G3 X88.163 Y131.747 I2.989 J2.223 E.03456
G2 X90.863 Y129.416 I-14.317 J-19.314 E.10971
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.333 J6.052 E.05348
G3 X94.828 Y123.94 I1.545 J1.357 E.02748
G2 X97.331 Y122.678 I-21.529 J-45.824 E.08613
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.511 Y118.382 I16.284 J15.667 E.07469
G3 X103.844 Y117.698 I2.998 J4.195 E.04621
G2 X106.326 Y116.856 I-155.482 J-462.531 E.08051
G2 X110.161 Y114.94 I-7.083 J-18.974 E.13198
G3 X112.029 Y113.845 I11.123 J16.832 E.06658
G3 X113.833 Y113.423 I2.199 J5.332 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.545 E.10818
G2 X120.249 Y112.069 I-3.378 J-16.161 E.09422
G3 X122.349 Y111.227 I9.362 J20.307 E.06954
G3 X123.486 Y111.206 I.613 J2.41 E.03526
G2 X125.869 Y111.616 I39.554 J-222.527 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.315 J24.966 E.06668
G3 X133.127 Y111.15 I.224 J2.466 E.00849
G3 X134.376 Y111.505 I-.414 J3.836 E.04008
G2 X137.615 Y112.726 I10.994 J-24.251 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.524 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.05721
G2 X148.18 Y116.248 I17.233 J-26.297 E.11809
G2 X150.457 Y117.142 I10.161 J-22.523 E.07518
G3 X152.643 Y117.905 I-6.827 J23.103 E.07118
G3 X154.232 Y119.064 I-2.357 J4.898 E.06078
G2 X157.076 Y121.646 I22.515 J-21.943 E.1181
G2 X159.105 Y123.012 I14.798 J-19.794 E.07517
G3 X161.075 Y124.229 I-11.663 J21.076 E.07119
G3 X162.173 Y125.409 I-2.911 J3.809 E.04975
G2 X163.993 Y128.088 I49.762 J-31.858 E.09952
G2 X166.471 Y130.796 I16.518 J-12.622 E.11296
G3 X168.012 Y132.318 I-14.979 J16.723 E.06658
G3 X168.887 Y133.952 I-4.412 J3.413 E.05721
G1 X169.137 Y134.615 E.02177
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X153.211 Y143.427 Z4.6 F36000
G1 Z4.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X152.298 Y142.079 I-13.312 J8.035 E.05403
G1 X164.508 Y129.869 E.57279
G3 X167.552 Y132.93 I-268.409 J269.936 E.14318
G3 X168.093 Y133.96 I-8.35 J5.04 E.03864
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X162.041 Y131.339 E.19816
G1 X162.467 Y130.913 E.02003
G1 X161.743 Y130.188 E.03399
G1 X160.005 Y124.422 F36000
G1 F15476.087
G3 X161.264 Y125.437 I-2.419 J4.288 E.05389
G1 X159.128 Y127.573 E.10021
G1 X156.452 Y124.897 E.12555
G1 X156.025 Y125.324 E.02003
G1 X147.385 Y116.684 E.40531
G3 X147.124 Y116.549 I1.497 J-3.222 E.00975
G1 X133.534 Y130.139 E.63753
G2 X129.657 Y129.659 I-5.817 J31.107 E.12968
G1 X129.165 Y129.168 E.02305
G1 X133.003 Y125.33 E.18005
G1 X139.666 Y131.992 E.31255
G1 X139.447 Y131.902 E.00785
G1 X152.623 Y118.726 E.61812
G3 X153.356 Y119.262 I-2.176 J3.743 E.03018
G2 X156.721 Y122.304 I27.782 J-27.344 E.15055
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.249 J13.204 E.05403
G1 X146.794 Y136.49 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.41125
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X157.116 Y126.167 E.79007
G1 X156.79 Y125.841 E.02496
G1 X146.573 Y136.059 E.78202
G1 X146.55 Y136.041 E.00154
G1 X148.846 Y133.745 E.17577
G1 X148.54 Y133.439 E.02343
G1 X156.464 Y125.515 E.60645
G1 X156.452 Y125.503 E.00092
M73 P66 R6
G1 X152.614 Y129.341 E.29375
G1 X152.3 Y129.027 E.02404
G1 X148.071 Y133.256 E.32366
G1 X150.827 Y134.577 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.44474
; LAYER_HEIGHT: 0.2
G1 F12000
G3 X150.747 Y134.542 I-.048 J.001 E.00634
; WIPE_START
G1 X150.726 Y134.577 E-.16084
G1 X150.752 Y134.621 E-.19972
G1 X150.802 Y134.621 E-.19972
G1 X150.827 Y134.577 E-.19972
; WIPE_END
G1 E-.04 F1800
G1 X153.167 Y136.838 Z4.6 F36000
G1 Z4.2
G1 E.8 F1800
; LINE_WIDTH: 0.54022
G1 F12000
G3 X153.076 Y136.784 I-.059 J-.004 E.0097
G1 X154.268 Y139.453 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.41125
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X158.497 Y135.224 E.32366
G1 X158.17 Y134.898 E.02496
G1 X154.085 Y138.983 E.3127
G1 X153.938 Y138.836 E.01126
G1 X151.623 Y141.151 E.17716
G1 X151.468 Y140.948 E.01382
G1 X161.682 Y130.733 E.78181
G1 X161.356 Y130.407 E.02496
G1 X151.179 Y140.585 E.77895
G1 X150.878 Y140.233 E.02504
G1 X161.03 Y130.081 E.77699
G1 X160.704 Y129.755 E.02496
G1 X156.665 Y133.794 E.30911
G1 X156.902 Y133.414 E.02421
G1 X156.432 Y133.374 E.02551
G1 X160.378 Y129.429 E.30199
G1 X160.052 Y129.103 E.02496
G1 X155.95 Y133.204 E.3139
G2 X155.743 Y132.759 I-1.655 J.498 E.02667
G1 X159.725 Y128.777 E.30477
G1 X159.399 Y128.45 E.02496
G1 X155.476 Y132.374 E.30029
G1 X155.147 Y132.051 E.02496
G1 X159.073 Y128.124 E.30053
G1 X158.747 Y127.798 E.02496
G1 X154.759 Y131.786 E.30524
G2 X154.39 Y131.613 I-.787 J1.193 E.02213
G1 X154.335 Y131.558 E.00421
G1 X158.421 Y127.472 E.3127
G1 X158.095 Y127.146 E.02496
G1 X154.009 Y131.231 E.3127
G1 X153.683 Y130.905 E.02496
G1 X157.768 Y126.82 E.3127
G1 X157.442 Y126.494 E.02496
G1 X147.289 Y136.647 E.77711
G1 X147.641 Y136.947 E.02504
G1 X150.654 Y133.935 E.23059
G1 X150.245 Y134.649 E.04451
G1 X150.419 Y134.822 E.01326
G1 X147.993 Y137.248 E.18568
G3 X148.33 Y137.563 I-2.842 J3.374 E.02499
G1 X150.745 Y135.148 E.18486
G1 X151.077 Y135.468 E.02497
G1 X148.664 Y137.881 E.18469
G1 X148.999 Y138.198 E.02497
G1 X151.385 Y135.812 E.18264
G2 X151.708 Y136.141 I3.534 J-3.147 E.02497
G1 X149.326 Y138.524 E.18237
G1 X149.643 Y138.859 E.02497
G1 X152.093 Y136.409 E.18749
G1 X152.209 Y136.472 E.00717
G1 X152.212 Y136.615 E.00772
G1 X152.376 Y136.779 E.01252
G1 X149.961 Y139.193 E.18481
G3 X150.277 Y139.529 I-3.051 J3.192 E.02499
G1 X152.702 Y137.105 E.18556
G1 X153.028 Y137.431 E.02496
G1 X150.434 Y140.025 E.19851
; WIPE_START
G1 X151.848 Y138.61 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.195 Y133.796 Z4.6 F36000
G1 Z4.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.48132
; LAYER_HEIGHT: 0.2
G1 F12000
G3 X156.111 Y133.753 I-.054 J.001 E.00786
G1 X158.68 Y135.655 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X161.572 Y138.547 E.13568
G1 X156.88 Y141.53 E.18446
G1 X154.842 Y139.493 E.09559
; WIPE_START
G1 X156.256 Y140.907 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.092 Y133.588 Z4.6 F36000
G1 X153.457 Y131.443 Z4.6
G1 Z4.2
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.35335
G1 F3000;_EXTRUDE_SET_SPEED
G1 X152.882 Y131.52 E.01468
G1 X153.321 Y131.081 E.0157
G1 X153.713 Y131.473 E.01402
G1 X153.517 Y131.45 E.00499
; Slow Down End
G1 X143.449 Y114.447 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X141.856 Y114.141 I-2.392 J8.17 E.0539
G1 X136.1 Y119.897 E.27002
G1 X137.109 Y120.906 E.04733
G1 X136.682 Y121.333 E.02003
G1 X148.031 Y132.681 E.53238
G1 X151.869 Y128.844 E.18005
G1 X135.998 Y112.973 E.74451
G1 X135.538 Y112.784 E.01652
G1 X132.262 Y116.059 E.15366
G1 X130.775 Y114.572 E.06976
G1 X130.348 Y114.999 E.02003
G1 X127.857 Y112.508 E.11687
G2 X128.138 Y112.507 I.133 J-2.693 E.00933
G1 X107.951 Y132.695 E.94704
G1 X104.113 Y128.857 E.18005
G1 X120.021 Y112.948 E.74631
G1 X120.456 Y112.783 E.01543
G1 X126.192 Y118.519 E.2691
G1 X122.354 Y122.357 E.18005
G1 X114.137 Y114.139 E.3855
G2 X112.541 Y114.437 I.888 J9.192 E.05391
G1 X122.394 Y122.931 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.41125
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X126.623 Y118.702 E.32366
G1 X126.937 Y119.016 E.02404
G1 X130.775 Y115.178 E.29375
G1 X130.787 Y115.19 E.00092
G1 X122.864 Y123.114 E.60645
G1 X123.17 Y123.42 E.02343
G1 X119.332 Y127.258 E.29375
G1 X119.352 Y127.278 E.00153
G1 X131.113 Y115.517 E.9002
G1 X131.44 Y115.843 E.02496
G1 X119.678 Y127.604 E.9002
G1 X120.004 Y127.93 E.02496
G1 X131.766 Y116.169 E.90021
G1 X132.092 Y116.495 E.02496
G1 X127.719 Y120.868 E.33467
G1 X128.328 Y120.911 E.03303
G1 X132.418 Y116.821 E.31304
G1 X132.744 Y117.147 E.02496
G1 X128.853 Y121.038 E.2978
G3 X129.302 Y121.242 I-.751 J2.253 E.02672
G1 X133.07 Y117.473 E.28841
G1 X133.396 Y117.8 E.02496
G1 X129.69 Y121.506 E.28369
G3 X130.004 Y121.809 I-.897 J1.245 E.02373
G1 X130.019 Y121.829 E.00133
G1 X133.723 Y118.126 E.28345
G1 X134.049 Y118.452 E.02496
G1 X130.287 Y122.214 E.28791
G3 X130.494 Y122.659 I-1.978 J1.19 E.02663
G1 X134.375 Y118.778 E.29703
G1 X134.701 Y119.104 E.02496
G1 X130.63 Y123.176 E.31163
G1 X130.663 Y123.331 E.00861
G1 X130.775 Y123.349 E.00611
G1 X130.942 Y123.516 E.01277
G1 X135.027 Y119.43 E.3127
G1 X135.353 Y119.757 E.02496
G1 X131.125 Y123.985 E.32366
G1 X130.735 Y124.037 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.597336
; LAYER_HEIGHT: 0.2
G1 F11363.309
G1 X130.661 Y124.161 E.00653
; LINE_WIDTH: 0.549688
G1 F12000
G1 X130.587 Y124.285 E.00597
; LINE_WIDTH: 0.50204
G1 X130.513 Y124.409 E.00541
; LINE_WIDTH: 0.454392
G1 X130.438 Y124.533 E.00485
; LINE_WIDTH: 0.406744
G1 X130.364 Y124.657 E.00428
G1 X130.293 Y124.744 E.00335
; LINE_WIDTH: 0.454392
G1 X130.221 Y124.832 E.00379
; LINE_WIDTH: 0.50204
G1 X130.15 Y124.919 E.00423
; LINE_WIDTH: 0.549688
G1 X130.078 Y125.007 E.00467
; LINE_WIDTH: 0.597336
G1 F11363.309
G1 X130.007 Y125.095 E.0051
; WIPE_START
G1 X130.078 Y125.007 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X127.119 Y126.187 Z4.6 F36000
G1 Z4.2
G1 E.8 F1800
; Slow Down Start
; LINE_WIDTH: 0.54231
G1 F3000;_EXTRUDE_SET_SPEED
G1 X127.051 Y126.143 E.00327
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.49677
;_EXTRUDE_SET_SPEED
G1 X126.984 Y126.099 E.00297
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.45123
;_EXTRUDE_SET_SPEED
G1 X126.916 Y126.055 E.00268
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.406504
;_EXTRUDE_SET_SPEED
G1 X126.261 Y125.536 E.02478
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.403167
;_EXTRUDE_SET_SPEED
G1 X126.09 Y125.352 E.00736
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.44366
;_EXTRUDE_SET_SPEED
G1 X125.92 Y125.169 E.00819
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.484154
;_EXTRUDE_SET_SPEED
G1 X125.749 Y124.985 E.00902
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.40569
;_EXTRUDE_SET_SPEED
G1 X125.683 Y124.891 E.0034
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.45123
;_EXTRUDE_SET_SPEED
G1 X125.616 Y124.797 E.00383
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.49677
;_EXTRUDE_SET_SPEED
G1 X125.55 Y124.703 E.00425
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.54231
;_EXTRUDE_SET_SPEED
G1 X125.484 Y124.609 E.00468
; Slow Down End
G1 X125.582 Y123.005 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.41125
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X120.33 Y128.257 E.40192
G1 X120.656 Y128.583 E.02496
G1 X125.204 Y124.036 E.34802
G1 X124.893 Y124.648 E.03716
G1 X125.068 Y124.823 E.01339
G1 X120.983 Y128.909 E.3127
G1 X121.309 Y129.235 E.02496
G1 X125.394 Y125.149 E.3127
G1 X125.721 Y125.476 E.02496
G1 X121.635 Y129.561 E.3127
G1 X121.96 Y129.889 E.02496
G1 X126.047 Y125.802 E.31281
G1 X126.373 Y126.128 E.02496
G1 X122.372 Y130.129 E.30621
G1 X123.173 Y129.98 E.04407
G1 X126.699 Y126.454 E.26989
G1 X127.025 Y126.78 E.02496
G1 X123.932 Y129.874 E.23678
G1 X124.683 Y129.775 E.04101
G1 X128.241 Y126.217 E.27234
G2 X129.143 Y125.967 I-.27 J-2.727 E.05092
G1 X125.4 Y129.709 E.28647
G1 X126.108 Y129.654 E.03844
G1 X135.68 Y120.083 E.73255
G1 X136.006 Y120.409 E.02496
G1 X126.795 Y129.62 E.70498
G1 X127.028 Y129.614 E.01263
G1 X128.212 Y128.855 E.07609
G1 X136.332 Y120.735 E.62149
M73 P67 R6
G1 X136.503 Y120.906 E.01309
G1 X132.665 Y124.744 E.29375
G1 X132.82 Y124.899 E.01187
G1 X128.591 Y129.128 E.32366
; WIPE_START
G1 X130.005 Y127.714 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X127.197 Y121.123 Z4.6 F36000
G1 Z4.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
; LAYER_HEIGHT: 0.2
G1 F12000
G1 X127.176 Y121.159 E.00118
G1 X127.112 Y121.123 E.00204
G1 X127.124 Y121.116 E.00038
G1 X110.183 Y135.481 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X111.517 Y134.548 I9.569 J12.267 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.18 I-19.495 J-25.074 E.15409
G3 X103.362 Y118.717 I2.109 J2.303 E.02678
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X119.894 Y128.427 E.16635
G1 X118.726 Y127.258 E.05483
G1 X119.153 Y126.831 E.02003
G1 X108.861 Y116.54 E.4828
G3 X108.636 Y116.657 I-1.537 J-2.657 E.00842
G1 X99.956 Y125.337 E.40718
G1 X99.53 Y124.91 E.02003
G1 X96.867 Y127.573 E.12493
G1 X94.506 Y125.212 E.11076
G3 X91.467 Y129.849 I-19.923 J-9.743 E.18439
G1 X103.68 Y142.062 E.57295
G2 X102.574 Y143.723 I15.283 J11.377 E.06621
G1 X99.181 Y141.464 E.1352
G1 X101.139 Y139.506 E.09187
G1 X102.94 Y136.843 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.5525
G1 F12000
G3 X102.848 Y136.788 I-.06 J-.004 E.01024
G1 X100.859 Y136.002 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.41125
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X105.089 Y140.232 E.32373
G1 X105.39 Y139.88 E.02504
G1 X102.954 Y137.444 E.18645
G1 X103.28 Y137.118 E.02496
G1 X105.69 Y139.529 E.18449
G3 X106.007 Y139.193 I3.366 J2.856 E.02499
G1 X103.606 Y136.792 E.18375
G1 X103.772 Y136.626 E.01268
G1 X103.771 Y136.459 E.00908
G1 X103.873 Y136.407 E.00619
G1 X106.324 Y138.858 E.18762
G1 X106.642 Y138.523 E.02497
G1 X104.259 Y136.141 E.18236
G1 X104.279 Y136.126 E.00133
G2 X104.582 Y135.811 I-.942 J-1.211 E.02373
G1 X106.969 Y138.198 E.18265
G1 X107.303 Y137.88 E.02497
G1 X104.906 Y135.483 E.18349
G1 X105.237 Y135.161 E.02497
G1 X107.638 Y137.563 E.1838
G3 X107.975 Y137.247 I3.176 J3.055 E.02499
G1 X105.563 Y134.835 E.18462
G1 X105.736 Y134.661 E.01329
G1 X105.322 Y133.942 E.04493
G1 X108.327 Y136.947 E.22997
G1 X108.679 Y136.646 E.02504
G1 X98.539 Y126.507 E.77605
G1 X98.865 Y126.181 E.02496
G1 X109.03 Y136.346 E.77802
G1 X109.395 Y136.058 E.02514
G1 X99.191 Y125.854 E.78096
G1 X99.518 Y125.528 E.02496
G1 X107.441 Y133.452 E.60646
G1 X107.767 Y133.126 E.02496
G1 X103.538 Y128.897 E.32366
G1 X102.442 Y131.062 F36000
G1 F3000
G1 X98.213 Y126.833 E.32366
G1 X97.887 Y127.159 E.02496
G1 X101.972 Y131.245 E.3127
G1 X101.954 Y131.263 E.00142
G1 X101.965 Y131.502 E.01295
G2 X101.658 Y131.582 I.092 J.985 E.01727
G1 X97.561 Y127.485 E.31358
G1 X97.234 Y127.811 E.02496
G1 X101.209 Y131.786 E.30419
G2 X100.824 Y132.053 I.885 J1.685 E.02543
G1 X96.908 Y128.138 E.29969
G1 X96.582 Y128.464 E.02496
G1 X100.492 Y132.373 E.29923
G2 X100.224 Y132.758 I2.449 J1.991 E.02538
G1 X96.256 Y128.79 E.3037
G1 X95.93 Y129.116 E.02496
G1 X100.017 Y133.203 E.31282
G1 X99.961 Y133.352 E.00863
G1 X99.853 Y133.365 E.00592
G1 X99.689 Y133.528 E.01249
G1 X95.604 Y129.442 E.3127
G1 X95.278 Y129.768 E.02496
G1 X99.363 Y133.854 E.3127
G1 X99.037 Y134.18 E.02496
G1 X94.951 Y130.094 E.3127
G1 X94.625 Y130.421 E.02496
G1 X104.789 Y140.584 E.77788
G2 X104.5 Y140.947 I3.328 J2.942 E.02514
G1 X94.299 Y130.747 E.78074
G1 X94.12 Y130.926 E.0137
G1 X97.958 Y134.764 E.29375
G1 X97.811 Y134.911 E.01126
G1 X101.897 Y138.996 E.3127
G1 X101.57 Y139.323 E.02496
G1 X97.342 Y135.094 E.32366
G1 X97.301 Y135.668 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
; LAYER_HEIGHT: 0.2
G1 F15476.087
G1 X94.573 Y138.397 E.12801
G1 X89.965 Y135.329 E.18364
G1 X93.941 Y131.353 E.18653
G1 X93.514 Y130.926 E.02003
G1 X94.238 Y130.201 E.03399
G1 X100.372 Y135.5 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X100.501 Y135.641 E.0053
G1 X99.998 Y134.97 F36000
; Slow Down Start
; LINE_WIDTH: 0.385785
G1 F3000;_EXTRUDE_SET_SPEED
G1 X99.875 Y134.474 E.01428
G1 X99.871 Y133.907 E.01583
G1 X99.513 Y134.265 E.01412
G1 X99.535 Y134.507 E.00679
G1 X99.955 Y134.928 E.01663
; Slow Down End
; WIPE_START
G1 X99.535 Y134.507 E-.22615
G1 X99.513 Y134.265 E-.09236
G1 X99.871 Y133.907 E-.19207
G1 X99.875 Y134.474 E-.21534
G1 X99.896 Y134.561 E-.03408
; WIPE_END
G1 E-.04 F1800
G1 X102.925 Y131.474 Z4.6 F36000
G1 Z4.2
G1 E.8 F1800
; LINE_WIDTH: 0.35177
G1 F12000
G1 X102.377 Y131.463 E.01379
G1 X102.342 Y131.429 E.00124
G1 X102.66 Y131.093 E.01165
G1 X103.084 Y131.517 E.01509
G1 X102.983 Y131.489 E.00265
; WIPE_START
G1 X103.084 Y131.517 E-.04527
G1 X102.66 Y131.093 E-.25813
G1 X102.342 Y131.429 E-.19936
G1 X102.377 Y131.463 E-.0213
G1 X102.925 Y131.474 E-.23595
; WIPE_END
G1 E-.04 F1800
G1 X105.245 Y134.593 Z4.6 F36000
G1 Z4.2
G1 E.8 F1800
; LINE_WIDTH: 0.45778
G1 F12000
G3 X105.164 Y134.555 I-.05 J.001 E.00686
; CHANGE_LAYER
; Z_HEIGHT: 4.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X105.142 Y134.593 E-.16668
G1 X105.168 Y134.638 E-.19776
G1 X105.219 Y134.638 E-.19778
G1 X105.245 Y134.593 E-.19778
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
G1 X127.003 Y121.478
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X127.029 Y121.471 E.0009
G3 X127.732 Y121.275 I.962 J2.09 E.02432
G3 X128.94 Y121.465 I.265 J2.249 E.04107
G3 X126.742 Y121.629 I-.949 J2.096 E.40329
G1 X126.951 Y121.508 E.00801
G1 X127.17 Y121.834 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.192 Y121.827 E.0007
G3 X127.76 Y121.666 I.799 J1.733 E.01823
G3 X128.522 Y121.728 I.216 J2.076 E.0236
G3 X126.954 Y121.958 I-.531 J1.833 E.31824
G1 X127.118 Y121.864 E.00583
; WIPE_START
M204 S10000
G1 X127.192 Y121.827 E-.03128
G1 X127.445 Y121.728 E-.10346
G1 X127.76 Y121.666 E-.12207
G1 X127.983 Y121.65 E-.08493
G1 X128.255 Y121.67 E-.10362
G1 X128.522 Y121.728 E-.10359
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.953 E-.10357
G1 X129.025 Y121.96 E-.00392
; WIPE_END
G1 E-.04 F1800
G1 X122.156 Y125.288 Z4.8 F36000
G1 X100.806 Y135.632 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.79 Y135.611 E.00089
G3 X102.277 Y131.819 I1.738 J-1.506 E.16593
G3 X103.412 Y136.227 I.251 J2.286 E.21784
G3 X101.022 Y135.843 I-.885 J-2.122 E.08459
G1 X100.849 Y135.674 E.00802
G1 X101.091 Y135.35 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.305 Y132.21 I1.444 J-1.246 E.12669
G3 X103.066 Y132.272 I.216 J2.076 E.0236
G3 X101.131 Y135.395 I-.531 J1.832 E.21608
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12619
G1 X100.79 Y134.899 E-.10359
G1 X100.694 Y134.643 E-.10355
G1 X100.637 Y134.377 E-.10359
G1 X100.617 Y134.105 E-.1036
G1 X100.637 Y133.833 E-.10359
G1 X100.694 Y133.567 E-.10358
G1 X100.706 Y133.536 E-.01231
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.313 Z4.8 F36000
G1 X152.459 Y132.022 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.485 Y132.015 E.0009
G3 X153.188 Y131.819 I.962 J2.09 E.02432
G3 X154.396 Y132.009 I.265 J2.248 E.04107
G3 X152.198 Y132.173 I-.949 J2.096 E.4033
G1 X152.407 Y132.052 E.00801
G1 X152.621 Y132.38 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.648 Y132.372 E.00085
G3 X153.216 Y132.21 I.799 J1.733 E.01823
G3 X153.978 Y132.272 I.216 J2.076 E.0236
G3 X152.41 Y132.503 I-.531 J1.833 E.31825
G1 X152.569 Y132.41 E.00567
; WIPE_START
M204 S10000
G1 X152.648 Y132.372 E-.03321
G1 X152.901 Y132.272 E-.10347
G1 X153.216 Y132.21 E-.12204
G1 X153.439 Y132.194 E-.08498
G1 X153.711 Y132.214 E-.10359
G1 X153.978 Y132.272 E-.10358
G1 X154.276 Y132.39 E-.12203
G1 X154.472 Y132.498 E-.08498
G1 X154.477 Y132.501 E-.00213
; WIPE_END
G1 E-.04 F1800
G1 X153.709 Y140.095 Z4.8 F36000
G1 X153.292 Y144.224 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.385 J1.746 E.04339
G3 X88.408 Y132.053 I2.738 J2.13 E.03249
G2 X91.148 Y129.685 I-14.52 J-19.572 E.12021
G2 X93.594 Y126.161 I-11.286 J-10.443 E.14278
G3 X94.42 Y124.708 I12.318 J6.045 E.05548
G3 X95.012 Y124.286 I1.249 J1.127 E.02431
G2 X97.525 Y123.019 I-21.479 J-45.718 E.09337
G2 X101.007 Y120.323 I-8.607 J-14.712 E.14647
G3 X102.746 Y118.697 I16.204 J15.586 E.07902
G3 X103.976 Y118.067 I2.75 J3.856 E.046
G2 X107.047 Y116.997 I-16.537 J-52.422 E.1079
G2 X110.366 Y115.274 I-7.762 J-19.008 E.12423
G3 X112.192 Y114.201 I10.971 J16.586 E.07026
G3 X113.876 Y113.812 I2.035 J4.969 E.05759
G2 X117.401 Y113.355 I-2.348 J-31.916 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10416
G3 X122.451 Y111.606 I9.407 J20.411 E.07347
G3 X123.43 Y111.594 I.514 J2.043 E.03278
G2 X125.813 Y112.005 I37.932 J-213.125 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16542
G3 X132.882 Y111.551 I5.296 J24.858 E.07085
G3 X133.113 Y111.542 I.192 J2.07 E.00765
G3 X134.137 Y111.831 I-.376 J3.29 E.03547
G2 X137.511 Y113.104 I11.569 J-25.556 E.11969
G2 X140.701 Y113.674 I5.147 J-19.607 E.10762
G3 X143.068 Y113.962 I-1.514 J22.327 E.07914
G3 X144.643 Y114.679 I-1.436 J5.237 E.05764
G2 X148.015 Y116.604 I17.394 J-26.559 E.12887
G2 X150.332 Y117.514 I10.346 J-22.927 E.08262
G3 X152.669 Y118.351 I-5.674 J19.53 E.08241
G3 X153.962 Y119.348 I-2.504 J4.581 E.05437
G2 X156.837 Y121.957 I22.735 J-22.169 E.12887
G2 X158.902 Y123.348 I15.071 J-20.153 E.08263
G3 X160.841 Y124.544 I-11.504 J20.809 E.0756
G3 X161.85 Y125.632 I-2.665 J3.484 E.04944
G2 X163.68 Y128.324 I49.862 J-31.927 E.108
G2 X166.201 Y131.081 I16.834 J-12.862 E.12411
G3 X167.71 Y132.568 I-14.871 J16.606 E.07028
G3 X168.522 Y134.094 I-4.097 J3.158 E.0576
G1 X168.658 Y134.455 E.0128
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.135 J2.086 E.05195
G3 X88.163 Y131.747 I2.989 J2.224 E.03456
G2 X90.863 Y129.416 I-14.315 J-19.312 E.1097
G2 X93.249 Y125.974 I-11.004 J-10.177 E.1291
G3 X94.112 Y124.464 I12.339 J6.055 E.05349
G3 X94.828 Y123.94 I1.545 J1.357 E.02748
G2 X97.331 Y122.678 I-21.525 J-45.816 E.08613
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.512 Y118.382 I16.286 J15.67 E.0747
G3 X103.844 Y117.698 I2.998 J4.196 E.04618
G2 X106.325 Y116.856 I-155.95 J-463.907 E.08052
G2 X110.161 Y114.94 I-7.082 J-18.973 E.13198
G3 X112.029 Y113.845 I11.124 J16.833 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.543 E.10817
G2 X120.249 Y112.069 I-3.378 J-16.161 E.09423
G3 X122.348 Y111.227 I9.363 J20.309 E.06953
G3 X123.486 Y111.206 I.614 J2.41 E.03527
G2 X125.869 Y111.616 I39.518 J-222.314 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.314 J24.962 E.06668
G3 X133.125 Y111.15 I.224 J2.462 E.00844
G3 X134.285 Y111.468 I-.383 J3.67 E.03713
G2 X137.615 Y112.726 I11.452 J-25.277 E.10946
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.524 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.05721
G2 X148.18 Y116.248 I17.231 J-26.295 E.11809
G2 X150.457 Y117.142 I10.16 J-22.52 E.07518
G3 X152.644 Y117.905 I-6.821 J23.087 E.0712
G3 X154.232 Y119.064 I-2.358 J4.898 E.06076
G2 X157.076 Y121.646 I22.52 J-21.948 E.1181
G2 X159.105 Y123.012 I14.797 J-19.791 E.07517
G3 X161.075 Y124.23 I-11.649 J21.053 E.0712
G3 X162.172 Y125.408 I-2.911 J3.809 E.04972
G2 X163.993 Y128.088 I49.787 J-31.874 E.09954
G2 X166.471 Y130.796 I16.518 J-12.622 E.11296
G3 X168.013 Y132.318 I-14.981 J16.724 E.06658
G3 X168.887 Y133.951 I-4.412 J3.413 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
M73 P68 R6
G1 X152.403 Y138.591 Z4.8 F36000
G1 Z4.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.455 Y138.605 E.00177
G2 X154.021 Y138.672 I.99 J-4.861 E.05221
G1 X156.88 Y141.53 E.13412
G1 X161.572 Y138.547 E.18446
G1 X157.969 Y134.944 E.16903
G2 X157.974 Y133.324 I-4.322 J-.824 E.05403
G1 X157.651 Y134.053 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X157.495 Y132.979 I-9.638 J.845 E.03337
G2 X157.012 Y131.869 I-6.951 J2.369 E.03721
G1 X156.711 Y131.458 E.01565
G1 X156.129 Y130.861 E.02564
G1 X155.714 Y130.564 E.01567
G1 X154.975 Y130.18 E.02561
G1 X154.485 Y130.028 E.01575
G1 X153.653 Y129.896 E.02587
G1 X153.155 Y129.906 E.01532
G1 X152.331 Y130.039 E.02565
G1 X151.85 Y130.208 E.01567
G1 X151.11 Y130.593 E.02562
G1 X150.704 Y130.906 E.01575
G1 X150.121 Y131.507 E.02573
G1 X149.649 Y132.261 E.02734
G1 X149.46 Y132.735 E.01567
G1 X149.262 Y133.545 E.02562
G1 X149.231 Y134.054 E.01566
G1 X149.298 Y134.885 E.02564
G1 X149.428 Y135.378 E.01564
G1 X149.752 Y136.147 E.02565
G1 X150.031 Y136.573 E.01566
G1 X150.58 Y137.201 E.02563
G1 X150.979 Y137.519 E.01567
G1 X151.697 Y137.943 E.02562
G1 X152.176 Y138.119 E.01566
G1 X152.991 Y138.295 E.02563
G1 X153.5 Y138.313 E.01566
G1 X154.33 Y138.224 E.02563
G1 X154.819 Y138.081 E.01567
G1 X155.58 Y137.735 E.02567
G1 X156.007 Y137.439 E.01598
G1 X156.611 Y136.881 E.02526
M73 P68 R5
G1 X156.918 Y136.474 E.01567
G1 X157.322 Y135.744 E.02563
G1 X157.486 Y135.261 E.01567
G1 X157.64 Y134.441 E.02564
G1 X157.649 Y134.113 E.0101
G1 X157.274 Y134.043 F36000
G1 F12000
G2 X157.095 Y132.958 I-7.098 J.61 E.03381
G2 X156.669 Y132.037 I-8.256 J3.263 E.03122
G2 X155.88 Y131.145 I-4.334 J3.039 E.03664
G1 X155.54 Y130.899 E.0129
G1 X154.828 Y130.529 E.02468
G1 X154.41 Y130.398 E.01345
G1 X153.624 Y130.273 E.02445
G1 X153.215 Y130.278 E.01257
G1 X152.421 Y130.406 E.02472
G2 X151.311 Y130.913 I1.738 J5.273 E.03757
G1 X150.936 Y131.209 E.01466
G1 X150.42 Y131.741 E.02278
G1 X149.985 Y132.436 E.02518
G2 X149.636 Y133.605 I5.258 J2.208 E.03757
G2 X149.671 Y134.825 I5.865 J.44 E.03757
G1 X149.8 Y135.289 E.01478
G1 X150.088 Y135.972 E.02279
G1 X150.315 Y136.325 E.01289
G1 X150.844 Y136.93 E.02471
G2 X151.863 Y137.602 I3.77 J-4.607 E.03756
G2 X153.041 Y137.92 I2.178 J-5.725 E.03756
G1 X153.547 Y137.929 E.01554
G1 X154.259 Y137.853 E.02203
G1 X154.663 Y137.737 E.0129
G1 X155.396 Y137.405 E.02473
G2 X156.333 Y136.624 I-3.429 J-5.066 E.03753
G1 X156.634 Y136.208 E.01577
G1 X156.977 Y135.588 E.0218
G2 X157.272 Y134.103 I-4.307 J-1.626 E.04673
; WIPE_START
G1 X157.264 Y134.401 E-.11345
G1 X157.136 Y135.081 E-.26306
G1 X156.977 Y135.588 E-.20159
G1 X156.745 Y136.006 E-.18191
; WIPE_END
G1 E-.04 F1800
G1 X150.993 Y132.973 Z4.8 F36000
G1 Z4.4
G1 E.8 F1800
G1 F12000
G1 X151.331 Y132.433 E.01956
G1 X151.731 Y132.025 E.01758
G1 X152.297 Y131.664 E.02062
G1 X152.709 Y131.511 E.01349
G1 X153.413 Y131.411 E.02185
G1 X153.836 Y131.439 E.01304
G3 X154.654 Y131.704 I-.663 J3.431 E.0265
G1 X155.19 Y132.056 E.01968
G1 X155.557 Y132.445 E.01645
G1 X155.886 Y132.973 E.0191
G1 X156.045 Y133.428 E.01481
G1 X156.135 Y134.087 E.02043
G1 X156.106 Y134.502 E.01279
G1 X155.915 Y135.163 E.02115
G1 X155.643 Y135.649 E.01711
G1 X155.215 Y136.133 E.01987
G1 X154.845 Y136.402 E.01405
G1 X154.24 Y136.677 E.02044
G1 X153.81 Y136.775 E.01355
G1 X153.146 Y136.781 E.02038
G1 X152.602 Y136.663 E.01711
G1 X151.993 Y136.38 E.02063
G1 X151.649 Y136.118 E.01329
G1 X151.211 Y135.617 E.02044
G1 X150.982 Y135.212 E.01431
G1 X150.795 Y134.602 E.0196
G1 X150.744 Y134.091 E.01578
G1 X150.773 Y133.708 E.01182
G3 X150.971 Y133.029 I3.296 J.594 E.02177
G1 X150.662 Y132.792 F36000
G1 F12000
G1 X151.029 Y132.208 E.02121
G1 X151.472 Y131.751 E.01955
G1 X152.096 Y131.345 E.02288
G1 X152.602 Y131.148 E.01667
G1 X153.331 Y131.041 E.02265
G3 X154.812 Y131.36 I.082 J3.218 E.04699
G1 X155.392 Y131.737 E.02124
G1 X155.787 Y132.124 E.01701
G1 X156.045 Y132.478 E.01347
G1 X156.333 Y133.087 E.02069
G1 X156.474 Y133.628 E.01717
G3 X155.945 Y135.875 I-3.113 J.453 E.07263
G1 X155.481 Y136.4 E.02152
G3 X154.106 Y137.098 I-2.113 J-2.458 E.04785
G1 X153.48 Y137.177 E.01941
G3 X152.126 Y136.882 I.079 J-3.622 E.04282
G1 X151.596 Y136.556 E.01915
G1 X151.144 Y136.147 E.01871
G3 X150.628 Y135.344 I2.295 J-2.042 E.02944
G1 X150.426 Y134.683 E.02126
G1 X150.367 Y134.145 E.01661
G1 X150.404 Y133.628 E.01594
G1 X150.56 Y133.05 E.01838
G1 X150.64 Y132.848 E.00667
; WIPE_START
G1 X150.56 Y133.05 E-.08255
G1 X150.404 Y133.628 E-.22735
G1 X150.367 Y134.145 E-.19711
G1 X150.426 Y134.683 E-.20544
G1 X150.463 Y134.802 E-.04755
; WIPE_END
G1 E-.04 F1800
G1 X156.892 Y134.033 Z4.8 F36000
G1 Z4.4
G1 E.8 F1800
; LINE_WIDTH: 0.422596
G1 F12000
G1 X156.788 Y133.266 E.02392
G2 X156.357 Y132.256 I-4.158 J1.176 E.03409
G2 X155.627 Y131.434 I-3.575 J2.44 E.03408
G1 X155.067 Y131.075 E.0206
G1 X154.503 Y130.822 E.01912
G2 X153.438 Y130.652 I-1.221 J4.234 E.03345
G1 X152.602 Y130.762 E.0261
G1 X152.069 Y130.942 E.01741
G1 X151.519 Y131.246 E.01943
G1 X151.21 Y131.475 E.01189
G1 X150.792 Y131.897 E.01837
G1 X150.327 Y132.609 E.02634
G2 X150.014 Y133.666 I4.017 J1.765 E.03419
G2 X150.149 Y135.142 I3.785 J.398 E.04613
G1 X150.43 Y135.795 E.022
G1 X150.794 Y136.309 E.01949
G1 X151.194 Y136.727 E.01792
G2 X153.092 Y137.539 I2.325 J-2.811 E.06475
G1 X153.506 Y137.553 E.01283
G1 X154.188 Y137.474 E.02123
G1 X154.809 Y137.264 E.02027
G1 X155.32 Y137 E.0178
G2 X156.628 Y135.429 I-2.058 J-3.043 E.06409
G1 X156.766 Y135.012 E.0136
G1 X156.881 Y134.36 E.02047
G1 X156.89 Y134.093 E.00829
G1 X160.005 Y124.422 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X161.265 Y125.437 I-1.77 J3.486 E.05403
G1 X156.244 Y130.457 E.23552
G2 X152.603 Y129.578 I-2.812 J3.67 E.12791
G1 X135.998 Y112.973 E.77898
G1 X135.538 Y112.784 E.01652
G1 X129.203 Y119.118 E.29716
G2 X126.786 Y119.112 I-1.22 J4.634 E.08107
G1 X120.456 Y112.783 E.29695
G1 X120.021 Y112.948 E.01543
G1 X103.385 Y129.584 E.78042
G2 X99.739 Y130.445 I-.856 J4.526 E.12801
G1 X94.506 Y125.212 E.24549
G3 X91.467 Y129.849 I-19.921 J-9.742 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.066 J18.211 E.18071
G1 X106.187 Y136.894 E.04994
G2 X107.099 Y133.547 I-3.609 J-2.78 E.11805
G1 X128.138 Y112.507 E.98701
G3 X127.857 Y112.508 I-.148 J-2.692 E.00933
G1 X148.87 Y133.521 E.98577
G2 X149.792 Y136.91 I4.523 J.59 E.11957
G1 X148.729 Y137.972 E.04984
G3 X152.298 Y142.079 I-21.47 J22.263 E.18072
G1 X164.508 Y129.869 E.57279
G3 X167.553 Y132.931 I-262.831 J264.363 E.14325
G3 X168.093 Y133.96 I-8.418 J5.07 E.03857
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.499 J-3.227 E.00975
G1 X133.534 Y130.139 E.63753
G2 X129.657 Y129.659 I-5.817 J31.108 E.12968
G1 X128.156 Y128.159 E.07039
G3 X127.837 Y128.16 I-.167 J-1.605 E.01062
G1 X126.34 Y129.657 E.07021
G2 X122.456 Y130.135 I1.928 J31.699 E.12989
G1 X108.861 Y116.54 E.63779
G3 X108.636 Y116.657 I-1.539 J-2.661 E.00843
G1 X89.965 Y135.329 E.87592
G1 X88.609 Y134.427 E.05401
G1 X97.988 Y133.348 F36000
G1 F15476.087
G2 X98.002 Y134.967 I4.829 J.769 E.05397
G1 X94.573 Y138.397 E.16087
G1 X99.181 Y141.464 E.18364
G1 X101.97 Y138.675 E.13083
G1 X102.027 Y138.685 E.00191
G2 X103.587 Y138.585 I.468 J-4.947 E.05207
G1 X106.739 Y134.053 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X106.584 Y132.979 I-9.634 J.845 E.03336
G2 X106.101 Y131.87 I-6.943 J2.365 E.0372
G1 X105.799 Y131.458 E.01568
G1 X105.218 Y130.861 E.02563
G1 X104.803 Y130.565 E.01565
G1 X104.063 Y130.18 E.02562
G1 X103.573 Y130.028 E.01575
G1 X102.747 Y129.897 E.02572
G1 X101.858 Y129.944 E.02735
G1 X101.359 Y130.062 E.01575
G1 X100.585 Y130.365 E.02555
G1 X100.15 Y130.632 E.01568
G1 X99.508 Y131.164 E.02561
G1 X99.18 Y131.554 E.01567
G1 X98.738 Y132.262 E.02563
G1 X98.549 Y132.735 E.01565
G1 X98.351 Y133.545 E.02562
G1 X98.319 Y134.054 E.01567
G1 X98.386 Y134.885 E.02563
G1 X98.516 Y135.378 E.01565
G1 X98.841 Y136.147 E.02564
G1 X99.119 Y136.574 E.01567
G1 X99.668 Y137.201 E.02562
G1 X100.067 Y137.519 E.01567
G1 X100.785 Y137.942 E.02562
G1 X101.264 Y138.119 E.01567
G1 X102.079 Y138.295 E.02563
G1 X102.588 Y138.313 E.01566
G1 X103.418 Y138.224 E.02563
G1 X103.908 Y138.081 E.01569
G1 X104.668 Y137.735 E.02565
G1 X105.096 Y137.439 E.01599
G1 X105.699 Y136.881 E.02525
G1 X106.006 Y136.474 E.01567
G1 X106.41 Y135.744 E.02563
G1 X106.574 Y135.261 E.01566
G1 X106.729 Y134.442 E.02563
G1 X106.737 Y134.113 E.01011
G1 X106.362 Y134.043 F36000
G1 F12000
G2 X106.184 Y132.958 I-7.099 J.611 E.0338
G2 X105.757 Y132.037 I-8.244 J3.257 E.03121
G2 X104.969 Y131.145 I-4.327 J3.032 E.03666
G2 X103.916 Y130.529 I-3.276 J4.385 E.03756
G1 X103.495 Y130.398 E.01354
G1 X102.727 Y130.275 E.02391
G1 X101.908 Y130.319 E.02519
G2 X100.75 Y130.705 I1.17 J5.436 E.03758
G1 X100.391 Y130.923 E.01291
G1 X99.772 Y131.435 E.02468
G1 X99.5 Y131.754 E.01289
G1 X99.073 Y132.436 E.0247
G2 X98.724 Y133.605 I5.269 J2.211 E.03756
G2 X98.76 Y134.825 I5.862 J.44 E.03758
G1 X98.888 Y135.289 E.01477
G1 X99.176 Y135.972 E.0228
G1 X99.403 Y136.325 E.01289
G1 X99.932 Y136.93 E.02469
G2 X100.951 Y137.602 I3.771 J-4.607 E.03756
G2 X102.129 Y137.92 I2.177 J-5.721 E.03756
G1 X102.635 Y137.929 E.01554
G1 X103.348 Y137.853 E.02203
G2 X104.484 Y137.405 I-1.555 J-5.611 E.0376
G2 X105.421 Y136.624 I-3.426 J-5.063 E.03752
G1 X105.722 Y136.208 E.01578
G1 X106.066 Y135.588 E.0218
G2 X106.36 Y134.103 I-4.309 J-1.627 E.04673
; WIPE_START
G1 X106.352 Y134.401 E-.11354
G1 X106.224 Y135.081 E-.26301
G1 X106.066 Y135.588 E-.20159
G1 X105.834 Y136.006 E-.18186
; WIPE_END
G1 E-.04 F1800
G1 X100.258 Y132.649 Z4.8 F36000
G1 Z4.4
G1 E.8 F1800
G1 F12000
G3 X100.849 Y132.002 I2.494 J1.685 E.027
G1 X101.388 Y131.663 E.01958
G1 X101.797 Y131.511 E.01341
G1 X102.501 Y131.411 E.02185
G1 X102.925 Y131.439 E.01305
G1 X103.5 Y131.597 E.01834
G1 X103.974 Y131.83 E.01622
G1 X104.303 Y132.076 E.01264
G1 X104.645 Y132.445 E.01545
G1 X104.974 Y132.973 E.01911
G1 X105.133 Y133.428 E.01482
G1 X105.223 Y134.087 E.02042
G1 X105.194 Y134.502 E.01279
G1 X105.004 Y135.163 E.02115
G1 X104.732 Y135.649 E.01711
G1 X104.303 Y136.133 E.01987
G3 X103.546 Y136.595 I-1.731 J-1.985 E.02738
G1 X102.936 Y136.768 E.01949
G3 X101.69 Y136.663 I-.388 J-2.838 E.03873
G1 X101.081 Y136.38 E.02063
G1 X100.737 Y136.118 E.01329
G1 X100.3 Y135.618 E.02042
G1 X100.07 Y135.212 E.01431
G1 X99.883 Y134.602 E.01961
G1 X99.832 Y134.091 E.01578
G1 X99.861 Y133.708 E.01182
G1 X100.001 Y133.181 E.01674
G1 X100.231 Y132.703 E.01631
G1 X99.939 Y132.449 F36000
G1 F12000
G1 X100.245 Y132.05 E.01547
G1 X100.648 Y131.683 E.01673
G1 X101.192 Y131.341 E.01976
G1 X101.712 Y131.143 E.01708
G1 X102.448 Y131.037 E.02285
G1 X102.974 Y131.064 E.01618
G1 X103.632 Y131.244 E.02097
G1 X104.154 Y131.499 E.01787
G1 X104.57 Y131.81 E.01594
G1 X104.947 Y132.219 E.0171
G1 X105.305 Y132.792 E.02076
G3 X105.586 Y134.333 I-2.949 J1.334 E.04861
G1 X105.486 Y134.932 E.01865
G1 X105.305 Y135.418 E.01594
G1 X105.033 Y135.875 E.01635
G1 X104.57 Y136.4 E.02152
G1 X104.139 Y136.72 E.01649
G1 X103.649 Y136.958 E.01673
G1 X103.039 Y137.131 E.01949
G3 X100.684 Y136.556 I-.484 J-3.125 E.07645
G1 X100.233 Y136.147 E.01871
G3 X99.717 Y135.344 I2.295 J-2.042 E.02944
G1 X99.515 Y134.682 E.02126
G1 X99.456 Y134.145 E.01661
G1 X99.493 Y133.628 E.01594
G1 X99.648 Y133.05 E.0184
G1 X99.91 Y132.502 E.01865
; WIPE_START
G1 X99.648 Y133.05 E-.2307
G1 X99.493 Y133.628 E-.22751
G1 X99.456 Y134.145 E-.19711
G1 X99.486 Y134.419 E-.10468
; WIPE_END
G1 E-.04 F1800
G1 X105.98 Y134.033 Z4.8 F36000
G1 Z4.4
G1 E.8 F1800
; LINE_WIDTH: 0.423746
G1 F12000
G1 X105.876 Y133.266 E.02399
G2 X105.445 Y132.256 I-4.155 J1.175 E.03418
G2 X103.435 Y130.774 I-3.032 J2.008 E.07911
G1 X102.707 Y130.659 E.02289
G1 X101.96 Y130.71 E.02321
G2 X100.447 Y131.365 I.637 J3.547 E.05163
G1 X100.042 Y131.712 E.01656
G2 X99.376 Y132.696 I3.011 J2.756 E.03699
G2 X99.083 Y134.172 I3.466 J1.456 E.04703
G1 X99.14 Y134.764 E.01846
G1 X99.237 Y135.141 E.01209
G1 X99.518 Y135.795 E.02207
G1 X99.882 Y136.309 E.01955
G1 X100.282 Y136.727 E.01797
G2 X102.18 Y137.539 I2.325 J-2.811 E.06495
G2 X103.752 Y137.322 I.257 J-3.932 E.04959
G1 X104.297 Y137.069 E.01864
G2 X105.716 Y135.429 I-1.922 J-3.096 E.06832
G1 X105.854 Y135.012 E.01364
G1 X105.969 Y134.36 E.02053
G1 X105.978 Y134.092 E.00832
G1 X112.541 Y114.437 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X114.137 Y114.139 I2.483 J8.892 E.05391
G1 X123.378 Y123.427 E.43463
G2 X123.544 Y124.777 I5.092 J.06 E.04526
G1 X116.349 Y131.973 E.33757
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.451 J2.766 E.02677
G3 X99.258 Y122.288 I-22.943 J-21.967 E.15409
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.885 J12.762 E.05403
; WIPE_START
G1 X111.517 Y134.548 E-.61868
G1 X111.254 Y134.285 E-.14132
; WIPE_END
G1 E-.04 F1800
G1 X117.979 Y130.675 Z4.8 F36000
G1 X132.162 Y123.063 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X132.077 Y122.56 E.01566
G1 X131.774 Y121.718 E.02751
G1 X131.519 Y121.277 E.01565
G1 X131.003 Y120.621 E.02564
G1 X130.622 Y120.282 E.01567
G1 X129.925 Y119.82 E.02569
G1 X129.448 Y119.616 E.01596
G1 X128.654 Y119.4 E.02527
G2 X127.699 Y119.362 I-.654 J4.391 E.02943
G1 X126.875 Y119.495 E.02564
G1 X126.394 Y119.664 E.01567
G1 X125.654 Y120.049 E.02563
G1 X125.251 Y120.36 E.01566
G1 X124.669 Y120.958 E.02563
G1 X124.384 Y121.381 E.01567
G1 X124.019 Y122.13 E.02562
G1 X123.881 Y122.621 E.01567
G1 X123.77 Y123.448 E.02562
G1 X123.794 Y123.96 E.01577
G1 X123.95 Y124.782 E.02571
G1 X124.297 Y125.602 E.02735
G1 X124.575 Y126.03 E.01567
G1 X125.124 Y126.657 E.02562
G1 X125.523 Y126.975 E.01565
G1 X126.242 Y127.398 E.02564
G1 X126.72 Y127.575 E.01566
G1 X127.535 Y127.751 E.02563
G1 X128.044 Y127.769 E.01566
G1 X128.874 Y127.68 E.02563
G1 X129.364 Y127.536 E.01569
G1 X130.122 Y127.192 E.0256
G1 X130.542 Y126.902 E.01567
G1 X131.155 Y126.337 E.02562
G1 X131.464 Y125.927 E.01577
G1 X131.868 Y125.194 E.02572
G1 X132.125 Y124.342 E.02734
G1 X132.183 Y123.836 E.01567
G1 X132.164 Y123.123 E.02192
G1 X131.785 Y123.073 F36000
G1 F12000
G1 X131.702 Y122.63 E.01384
G1 X131.429 Y121.874 E.02469
G2 X130.725 Y120.878 I-4.71 J2.579 E.03757
G1 X130.404 Y120.59 E.01326
G1 X129.743 Y120.152 E.02438
G1 X129.349 Y119.98 E.0132
G1 X128.584 Y119.772 E.02435
G2 X127.759 Y119.734 I-.604 J4.189 E.02543
G1 X126.965 Y119.862 E.02472
G2 X125.855 Y120.369 I1.735 J5.267 E.03758
G2 X124.96 Y121.199 I3.42 J4.583 E.03757
G1 X124.703 Y121.586 E.01427
G1 X124.371 Y122.268 E.02331
G1 X124.255 Y122.671 E.0129
G1 X124.148 Y123.468 E.02469
G2 X124.313 Y124.673 I5.687 J-.166 E.03743
G1 X124.632 Y125.428 E.02519
G1 X124.859 Y125.781 E.0129
G1 X125.388 Y126.386 E.0247
G2 X126.407 Y127.058 I3.776 J-4.615 E.03756
G2 X127.585 Y127.376 I2.178 J-5.724 E.03756
G1 X128.091 Y127.385 E.01554
G1 X128.804 Y127.308 E.02203
G2 X129.939 Y126.861 I-1.554 J-5.612 E.03757
G2 X130.877 Y126.08 I-3.485 J-5.136 E.03755
G2 X131.518 Y125.047 I-4.11 J-3.27 E.03745
G1 X131.755 Y124.262 E.02518
G2 X131.787 Y123.133 I-5.852 J-.731 E.03478
; WIPE_START
G1 X131.8 Y123.618 E-.18443
G1 X131.755 Y124.262 E-.24549
G1 X131.518 Y125.047 E-.31143
G1 X131.495 Y125.09 E-.01865
; WIPE_END
G1 E-.04 F1800
G1 X125.937 Y125.316 Z4.8 F36000
G1 Z4.4
G1 E.8 F1800
G1 F12000
G3 X125.493 Y124.579 I2.441 J-1.974 E.02651
G1 X125.32 Y123.969 E.01949
G1 X125.288 Y123.543 E.01314
G1 X125.378 Y122.884 E.02042
G1 X125.537 Y122.429 E.01482
G1 X125.866 Y121.901 E.0191
G1 X126.208 Y121.532 E.01546
G1 X126.537 Y121.286 E.01264
G3 X127.253 Y120.967 I1.711 J2.88 E.02413
G1 X127.957 Y120.866 E.02185
G1 X128.38 Y120.894 E.01305
G1 X128.982 Y121.063 E.01921
G1 X129.443 Y121.294 E.01585
G1 X129.904 Y121.677 E.01841
G1 X130.246 Y122.094 E.01656
G1 X130.474 Y122.542 E.01544
G1 X130.647 Y123.152 E.01949
G3 X130.636 Y124.019 I-2.5 J.403 E.02677
G1 X130.454 Y124.633 E.01967
G1 X130.208 Y125.075 E.01554
G1 X129.767 Y125.581 E.02062
G3 X129.002 Y126.051 I-1.723 J-1.945 E.02773
G1 X128.392 Y126.224 E.01949
G3 X127.146 Y126.119 I-.388 J-2.837 E.03872
G1 X126.537 Y125.836 E.02063
G3 X125.98 Y125.359 I1.4 J-2.201 E.02263
G1 X125.636 Y125.542 F36000
G1 F12000
G3 X124.957 Y124.072 I2.742 J-2.157 E.0502
G1 X124.912 Y123.52 E.01701
G1 X124.949 Y123.084 E.01346
G1 X125.09 Y122.543 E.01718
G1 X125.377 Y121.934 E.02069
G3 X126.357 Y120.955 I2.909 J1.93 E.04283
G1 X126.879 Y120.699 E.01788
G1 X127.2 Y120.594 E.01036
G1 X127.903 Y120.493 E.02185
G1 X128.444 Y120.523 E.01663
G1 X129.114 Y120.709 E.02138
G1 X129.61 Y120.955 E.017
G3 X130.824 Y122.402 I-1.611 J2.584 E.05901
G1 X131.01 Y123.049 E.0207
G1 X131.055 Y123.601 E.01701
G1 X131.005 Y124.1 E.01539
G1 X130.808 Y124.765 E.02132
G1 X130.534 Y125.265 E.0175
G1 X130.05 Y125.83 E.02288
G1 X129.65 Y126.143 E.01562
G1 X129.184 Y126.385 E.01611
G3 X128.381 Y126.607 I-2.312 J-6.792 E.02563
G3 X126.139 Y126.011 I-.356 J-3.176 E.07292
G1 X125.675 Y125.587 E.01933
; WIPE_START
G1 X126.139 Y126.011 E-.23905
G1 X126.671 Y126.338 E-.23694
G1 X127.014 Y126.473 E-.14031
G1 X127.381 Y126.564 E-.1437
; WIPE_END
G1 E-.04 F1800
G1 X131.404 Y123.083 Z4.8 F36000
G1 Z4.4
G1 E.8 F1800
; LINE_WIDTH: 0.422269
G1 F12000
G1 X131.197 Y122.337 E.02394
G1 X130.938 Y121.776 E.0191
G2 X130.267 Y120.971 I-3.729 J2.428 E.03247
G2 X128.441 Y120.138 I-2.412 J2.87 E.0628
G1 X127.849 Y120.113 E.01831
G1 X127.146 Y120.218 E.02198
G1 X126.613 Y120.398 E.01739
G1 X126.06 Y120.693 E.01937
G2 X125.044 Y121.752 I2.173 J3.1 E.04565
G1 X124.73 Y122.408 E.0225
G2 X124.531 Y123.586 I3.932 J1.271 E.03704
G1 X124.581 Y124.093 E.01575
G1 X124.769 Y124.785 E.02217
G1 X124.975 Y125.25 E.01572
G1 X125.338 Y125.765 E.01947
G1 X125.738 Y126.183 E.0179
G2 X127.636 Y126.995 I2.325 J-2.812 E.0647
G2 X129.208 Y126.777 I.257 J-3.932 E.0494
G1 X129.753 Y126.525 E.01855
G2 X131.148 Y124.935 I-1.922 J-3.094 E.06634
G1 X131.379 Y124.181 E.02438
G2 X131.407 Y123.143 I-4.022 J-.627 E.03219
G1 X145.8 Y135.493 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X144.466 Y134.559 I-9.576 J12.26 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.357 Y119.263 I24.427 J-30.396 E.15052
G2 X152.623 Y118.726 I-2.91 J3.206 E.03021
G1 X139.447 Y131.902 E.61812
G1 X139.666 Y131.992 E.00785
G1 X132.428 Y124.755 E.33954
G2 X132.587 Y123.41 I-4.231 J-1.182 E.04509
G1 X141.856 Y114.141 E.43482
G3 X143.449 Y114.447 I-.8 J8.48 E.0539
; CHANGE_LAYER
; Z_HEIGHT: 4.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X142.991 Y114.302 E-.18254
G1 X141.856 Y114.141 E-.43577
G1 X141.592 Y114.405 E-.14169
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
G1 X127.051 Y121.456
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.336 Y121.355 E.01002
G3 X127.723 Y121.276 I.655 J2.204 E.01312
G3 X128.94 Y121.465 I.273 J2.251 E.04139
G3 X126.999 Y121.485 I-.95 J2.094 E.41281
G1 X127.168 Y121.835 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.192 Y121.828 E.00076
G3 X127.751 Y121.667 I.801 J1.732 E.01794
G3 X128.255 Y121.67 I.243 J1.757 E.01556
G3 X126.954 Y121.959 I-.263 J1.89 E.32651
G1 X127.116 Y121.865 E.00576
; WIPE_START
M204 S10000
G1 X127.192 Y121.828 E-.03205
G1 X127.445 Y121.728 E-.10346
G1 X127.751 Y121.667 E-.11838
G1 X127.983 Y121.65 E-.08866
G1 X128.255 Y121.67 E-.10361
G1 X128.522 Y121.728 E-.10355
G1 X128.777 Y121.823 E-.10358
G1 X129.016 Y121.954 E-.1036
G1 X129.023 Y121.958 E-.00311
; WIPE_END
G1 E-.04 F1800
G1 X122.149 Y125.276 Z5 F36000
G1 X100.771 Y135.592 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.598 Y135.345 E.01001
G3 X102.267 Y131.82 I1.937 J-1.241 E.15441
G3 X103.484 Y132.009 I.273 J2.252 E.04139
G3 X100.815 Y135.632 I-.95 J2.095 E.27166
G1 X101.092 Y135.349 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.295 Y132.211 I1.445 J-1.246 E.12635
G3 X102.8 Y132.214 I.243 J1.757 E.01556
G3 X101.131 Y135.394 I-.263 J1.89 E.22462
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12616
G1 X100.79 Y134.899 E-.10361
G1 X100.694 Y134.643 E-.10356
G1 X100.637 Y134.377 E-.10359
G1 X100.617 Y134.105 E-.10359
G1 X100.637 Y133.833 E-.10361
G1 X100.694 Y133.567 E-.10357
G1 X100.706 Y133.536 E-.01233
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.313 Z5 F36000
G1 X152.459 Y132.022 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.485 Y132.015 E.00088
G3 X153.179 Y131.82 I.962 J2.091 E.02401
G3 X154.396 Y132.009 I.273 J2.252 E.04139
G3 X152.198 Y132.173 I-.95 J2.096 E.40344
G1 X152.407 Y132.052 E.00802
G1 X152.619 Y132.381 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.648 Y132.372 E.00093
G3 X153.207 Y132.211 I.801 J1.732 E.01794
G3 X153.711 Y132.214 I.243 J1.757 E.01556
G3 X152.41 Y132.503 I-.263 J1.89 E.32649
G1 X152.567 Y132.412 E.00559
; WIPE_START
M204 S10000
G1 X152.648 Y132.372 E-.03416
G1 X152.901 Y132.272 E-.10346
G1 X153.207 Y132.211 E-.11839
G1 X153.439 Y132.194 E-.08865
G1 X153.711 Y132.214 E-.1036
G1 X153.978 Y132.272 E-.10357
G1 X154.233 Y132.367 E-.10359
G1 X154.472 Y132.498 E-.10358
G1 X154.474 Y132.499 E-.00101
; WIPE_END
G1 E-.04 F1800
G1 X153.708 Y140.093 Z5 F36000
G1 X153.292 Y144.224 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.387 J1.746 E.04339
G3 X88.408 Y132.053 I2.737 J2.128 E.0325
G2 X91.148 Y129.685 I-14.519 J-19.571 E.12021
G2 X93.594 Y126.159 I-11.288 J-10.444 E.14282
G3 X94.42 Y124.708 I12.306 J6.04 E.05543
G3 X95.013 Y124.286 I1.249 J1.127 E.02433
G2 X97.525 Y123.019 I-21.458 J-45.677 E.09334
G2 X101.007 Y120.323 I-8.607 J-14.712 E.14649
G3 X102.746 Y118.696 I16.203 J15.585 E.07902
G3 X103.976 Y118.067 I2.749 J3.854 E.046
G2 X107.048 Y116.997 I-16.534 J-52.411 E.10791
G2 X110.366 Y115.274 I-7.762 J-19.007 E.12422
G3 X112.192 Y114.201 I10.975 J16.592 E.07026
G3 X113.876 Y113.812 I2.035 J4.968 E.05759
G2 X117.401 Y113.355 I-2.348 J-31.919 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.57 E.10417
G3 X122.451 Y111.606 I9.401 J20.398 E.07347
G3 X123.43 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I37.91 J-213.002 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.297 J24.862 E.07087
G3 X133.111 Y111.542 I.191 J2.064 E.00759
G3 X134.227 Y111.868 I-.402 J3.455 E.03875
G2 X137.511 Y113.104 I11.112 J-24.53 E.11647
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.068 Y113.961 I-1.514 J22.333 E.07913
M73 P69 R5
G3 X144.643 Y114.679 I-1.436 J5.238 E.05765
G2 X148.015 Y116.604 I17.389 J-26.549 E.12886
G2 X150.332 Y117.514 I10.344 J-22.92 E.08263
G3 X152.669 Y118.351 I-5.673 J19.527 E.08241
G3 X153.962 Y119.348 I-2.503 J4.58 E.05437
G2 X156.837 Y121.957 I22.738 J-22.172 E.12887
G2 X158.902 Y123.348 I15.07 J-20.153 E.08263
G3 X160.841 Y124.544 I-11.517 J20.83 E.07559
G3 X161.851 Y125.634 I-2.666 J3.485 E.04953
G2 X163.68 Y128.324 I49.844 J-31.916 E.10792
G2 X166.202 Y131.082 I16.837 J-12.864 E.12414
G3 X167.71 Y132.568 I-14.858 J16.592 E.07025
G3 X168.522 Y134.093 I-4.096 J3.157 E.05758
G1 X168.658 Y134.455 E.01283
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.134 J2.086 E.05195
G3 X88.163 Y131.747 I2.99 J2.224 E.03456
G2 X90.863 Y129.416 I-14.314 J-19.311 E.10971
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.334 J6.053 E.05348
G3 X94.828 Y123.939 I1.546 J1.358 E.0275
G2 X97.331 Y122.678 I-21.511 J-45.788 E.08611
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.511 Y118.382 I16.287 J15.671 E.0747
G3 X103.844 Y117.698 I2.997 J4.194 E.04619
G2 X106.326 Y116.856 I-156.325 J-465.009 E.08053
G2 X110.161 Y114.94 I-7.083 J-18.974 E.13198
G3 X112.029 Y113.845 I11.123 J16.83 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.546 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.358 J20.298 E.06953
G3 X123.486 Y111.206 I.613 J2.41 E.03526
G2 X125.869 Y111.616 I39.53 J-222.382 E.0743
G2 X130.711 Y111.521 I2.13 J-14.776 E.14949
G3 X132.851 Y111.16 I5.315 J24.965 E.06668
G3 X133.123 Y111.15 I.224 J2.466 E.00839
G3 X134.376 Y111.505 I-.407 J3.824 E.04018
G2 X137.615 Y112.726 I10.992 J-24.247 E.10646
G2 X140.743 Y113.284 I5.04 J-19.215 E.09773
G3 X143.156 Y113.579 I-1.533 J22.525 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.05721
G2 X148.18 Y116.248 I17.23 J-26.292 E.11809
G2 X150.457 Y117.142 I10.161 J-22.523 E.07518
G3 X152.643 Y117.905 I-6.827 J23.104 E.07118
G3 X154.232 Y119.064 I-2.357 J4.897 E.06077
G2 X157.076 Y121.646 I22.522 J-21.951 E.11811
G2 X159.105 Y123.012 I14.8 J-19.797 E.07517
G3 X161.075 Y124.229 I-11.662 J21.074 E.07119
G3 X162.173 Y125.409 I-2.911 J3.809 E.04975
G2 X163.993 Y128.088 I49.777 J-31.868 E.09952
G2 X166.471 Y130.796 I16.519 J-12.623 E.11296
G3 X168.013 Y132.318 I-14.975 J16.718 E.06659
G3 X168.887 Y133.951 I-4.411 J3.412 E.05719
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26194
; WIPE_END
G1 E-.04 F1800
G1 X156.092 Y136.584 Z5 F36000
G1 X157.651 Y134.053 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X157.495 Y132.979 I-9.634 J.845 E.03337
G2 X157.012 Y131.87 I-6.95 J2.368 E.03721
G1 X156.711 Y131.458 E.01565
G1 X156.129 Y130.861 E.02564
G1 X155.715 Y130.565 E.01565
G1 X154.975 Y130.18 E.02563
G1 X154.485 Y130.029 E.01574
G1 X153.653 Y129.896 E.02588
G1 X153.155 Y129.906 E.01532
G1 X152.331 Y130.039 E.02565
G1 X151.85 Y130.208 E.01566
G1 X151.11 Y130.593 E.02562
G1 X150.705 Y130.906 E.01575
G1 X150.121 Y131.507 E.02573
G1 X149.65 Y132.261 E.02733
G1 X149.46 Y132.735 E.01567
G1 X149.262 Y133.545 E.02562
G1 X149.231 Y134.054 E.01566
G1 X149.298 Y134.885 E.02564
G1 X149.428 Y135.378 E.01564
G1 X149.752 Y136.146 E.02564
G1 X150.031 Y136.574 E.01567
G1 X150.58 Y137.201 E.02563
G1 X150.979 Y137.519 E.01567
G1 X151.697 Y137.942 E.02562
G1 X152.176 Y138.119 E.01568
G1 X152.991 Y138.295 E.02561
G1 X153.5 Y138.313 E.01566
G1 X154.33 Y138.224 E.02563
G1 X154.82 Y138.08 E.01569
G1 X155.58 Y137.735 E.02564
G1 X156.007 Y137.439 E.01598
G1 X156.611 Y136.88 E.02526
G1 X156.918 Y136.474 E.01566
G1 X157.322 Y135.744 E.02563
G1 X157.486 Y135.261 E.01566
G1 X157.64 Y134.441 E.02564
G1 X157.649 Y134.113 E.0101
G1 X157.274 Y134.043 F36000
G1 F12000
G2 X157.095 Y132.958 I-7.099 J.611 E.03381
G2 X156.669 Y132.037 I-8.256 J3.263 E.03122
G2 X155.88 Y131.145 I-4.337 J3.042 E.03664
G2 X154.827 Y130.529 I-3.278 J4.389 E.03757
G1 X154.407 Y130.398 E.01353
G1 X153.624 Y130.273 E.02437
G1 X153.215 Y130.278 E.01257
G1 X152.421 Y130.406 E.02472
G2 X151.311 Y130.913 I1.737 J5.271 E.03757
G2 X150.42 Y131.741 I3.358 J4.507 E.03744
G1 X149.985 Y132.436 E.02518
G2 X149.636 Y133.605 I5.261 J2.209 E.03757
G2 X149.671 Y134.825 I5.866 J.44 E.03757
G1 X149.8 Y135.289 E.01477
G1 X150.088 Y135.972 E.02279
G1 X150.319 Y136.33 E.01307
G1 X150.844 Y136.93 E.02452
G2 X151.863 Y137.602 I3.633 J-4.399 E.03757
G1 X152.256 Y137.751 E.01291
G1 X153.041 Y137.92 E.02468
G1 X153.544 Y137.929 E.01546
G1 X154.259 Y137.852 E.0221
G2 X155.396 Y137.405 I-1.594 J-5.711 E.03759
G2 X156.333 Y136.624 I-3.426 J-5.063 E.03753
G2 X156.977 Y135.588 I-4.296 J-3.392 E.03758
G2 X157.272 Y134.103 I-4.307 J-1.626 E.04673
; WIPE_START
G1 X157.264 Y134.401 E-.11344
G1 X157.136 Y135.082 E-.26309
G1 X156.977 Y135.588 E-.20154
G1 X156.745 Y136.006 E-.18192
; WIPE_END
G1 E-.04 F1800
G1 X151.186 Y135.582 Z5 F36000
G1 Z4.6
G1 E.8 F1800
G1 F12000
G1 X150.982 Y135.213 E.01297
G1 X150.795 Y134.602 E.01961
G1 X150.744 Y134.091 E.01578
G1 X150.773 Y133.708 E.01182
G1 X150.913 Y133.182 E.01673
G1 X151.164 Y132.659 E.01783
G3 X152.708 Y131.511 I2.332 J1.525 E.06035
G1 X153.413 Y131.411 E.02185
G1 X153.836 Y131.439 E.01305
G1 X154.412 Y131.597 E.01834
G1 X154.885 Y131.83 E.01622
G1 X155.215 Y132.076 E.01265
G1 X155.557 Y132.445 E.01546
G1 X155.886 Y132.973 E.0191
G1 X156.045 Y133.428 E.01482
G1 X156.135 Y134.087 E.02043
G1 X156.106 Y134.502 E.01279
G1 X155.915 Y135.163 E.02115
G1 X155.67 Y135.611 E.01567
G1 X155.223 Y136.125 E.02093
G3 X154.467 Y136.592 I-1.733 J-1.959 E.02742
G1 X153.848 Y136.768 E.0198
G3 X152.96 Y136.753 I-.401 J-2.474 E.02744
G1 X152.343 Y136.566 E.01979
G1 X151.838 Y136.262 E.01811
G1 X151.604 Y136.073 E.00924
G1 X151.224 Y135.628 E.01798
G1 X150.897 Y135.825 F36000
G1 F12000
G3 X150.404 Y133.628 I2.636 J-1.745 E.07075
G1 X150.56 Y133.05 E.01839
G1 X150.833 Y132.478 E.01948
G3 X151.813 Y131.499 I2.908 J1.928 E.04283
G1 X152.335 Y131.243 E.01787
G1 X152.655 Y131.138 E.01035
G1 X153.359 Y131.037 E.02185
G1 X153.885 Y131.064 E.01618
G1 X154.543 Y131.243 E.02096
G1 X155.066 Y131.499 E.01787
G1 X155.482 Y131.81 E.01595
G1 X155.859 Y132.219 E.01711
G1 X156.217 Y132.792 E.02075
G3 X156.498 Y134.333 I-2.95 J1.334 E.0486
G1 X156.398 Y134.932 E.01866
G3 X155.951 Y135.867 I-2.833 J-.78 E.03202
G1 X155.506 Y136.374 E.02072
G3 X154.08 Y137.094 I-2.088 J-2.362 E.04963
G1 X153.837 Y137.151 E.00769
G1 X153.383 Y137.176 E.01396
G1 X152.851 Y137.114 E.01646
G1 X152.234 Y136.927 E.01979
G1 X151.732 Y136.658 E.01752
G1 X151.322 Y136.323 E.01625
G1 X150.936 Y135.871 E.01827
; WIPE_START
G1 X151.322 Y136.323 E-.22599
G1 X151.732 Y136.658 E-.20091
G1 X152.234 Y136.927 E-.21668
G1 X152.527 Y137.016 E-.11642
; WIPE_END
G1 E-.04 F1800
G1 X156.892 Y134.033 Z5 F36000
G1 Z4.6
G1 E.8 F1800
; LINE_WIDTH: 0.425304
G1 F12000
G1 X156.788 Y133.266 E.02409
G2 X156.357 Y132.256 I-4.158 J1.176 E.03433
G2 X154.347 Y130.774 I-3.032 J2.009 E.07942
G1 X153.594 Y130.657 E.02375
G1 X153.276 Y130.659 E.00989
G1 X152.601 Y130.762 E.02127
G1 X152.069 Y130.942 E.01752
G1 X151.516 Y131.237 E.01952
G2 X150.723 Y131.978 I2.295 J3.25 E.03394
G1 X150.327 Y132.609 E.02321
G2 X150.014 Y133.666 I4.018 J1.766 E.03444
G2 X150.148 Y135.141 I3.786 J.398 E.04646
G1 X150.43 Y135.794 E.02216
G1 X150.607 Y136.077 E.01039
G1 X151.029 Y136.564 E.02007
G1 X151.499 Y136.953 E.01902
G2 X153.504 Y137.553 I1.98 J-2.963 E.06618
G1 X154.055 Y137.494 E.01727
G1 X154.674 Y137.317 E.02008
G1 X155.209 Y137.069 E.01837
G2 X156.766 Y135.012 I-1.934 J-3.082 E.08217
G1 X156.881 Y134.36 E.02062
G1 X156.89 Y134.093 E.00834
G1 X157.974 Y133.324 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X157.969 Y134.944 I-4.327 J.796 E.05403
G1 X161.572 Y138.547 E.16904
G1 X156.88 Y141.53 E.18446
G1 X154.021 Y138.671 E.13412
G1 X153.94 Y138.684 E.00272
G3 X152.403 Y138.591 I-.468 J-4.992 E.05127
G1 X132.162 Y123.063 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X132.077 Y122.56 E.01566
G1 X131.774 Y121.718 E.0275
G1 X131.518 Y121.277 E.01565
G1 X131.003 Y120.621 E.02563
G1 X130.622 Y120.282 E.01567
G1 X129.925 Y119.82 E.02569
G1 X129.448 Y119.616 E.01596
G1 X128.654 Y119.4 E.02527
G2 X127.699 Y119.362 I-.654 J4.391 E.02943
G1 X126.875 Y119.495 E.02564
G1 X126.394 Y119.664 E.01567
G1 X125.654 Y120.049 E.02563
G1 X125.251 Y120.36 E.01566
G1 X124.669 Y120.958 E.02563
G1 X124.384 Y121.38 E.01566
G1 X124.019 Y122.131 E.02563
G1 X123.881 Y122.621 E.01567
G1 X123.771 Y123.448 E.02562
G1 X123.794 Y123.96 E.01577
G1 X123.951 Y124.782 E.0257
G1 X124.297 Y125.602 E.02736
G1 X124.575 Y126.029 E.01567
G1 X125.125 Y126.657 E.02563
G1 X125.523 Y126.975 E.01566
G1 X126.242 Y127.398 E.02563
G1 X126.72 Y127.575 E.01566
G1 X127.535 Y127.751 E.02563
G1 X128.045 Y127.769 E.01567
G1 X128.874 Y127.68 E.02562
G1 X129.363 Y127.536 E.01567
G1 X130.122 Y127.192 E.02562
G1 X130.542 Y126.902 E.01567
G1 X131.155 Y126.336 E.02563
G1 X131.463 Y125.927 E.01576
G1 X131.868 Y125.194 E.02572
G1 X132.125 Y124.342 E.02734
G1 X132.183 Y123.835 E.01568
G1 X132.164 Y123.123 E.0219
G1 X131.785 Y123.073 F36000
G1 F12000
G1 X131.702 Y122.63 E.01383
G1 X131.429 Y121.875 E.02469
G2 X130.725 Y120.878 I-4.712 J2.58 E.03757
G1 X130.404 Y120.59 E.01326
G1 X129.743 Y120.152 E.02437
G1 X129.349 Y119.98 E.0132
G1 X128.584 Y119.772 E.02435
G2 X127.759 Y119.734 I-.604 J4.189 E.02543
G1 X126.965 Y119.862 E.02472
G2 X125.855 Y120.369 I1.736 J5.268 E.03758
G2 X124.96 Y121.199 I3.421 J4.585 E.03757
G1 X124.703 Y121.586 E.01427
G1 X124.371 Y122.268 E.02331
G1 X124.255 Y122.671 E.0129
G1 X124.148 Y123.468 E.02469
G2 X124.313 Y124.672 I5.685 J-.166 E.03743
G1 X124.632 Y125.428 E.0252
G1 X124.861 Y125.783 E.01298
G1 X125.388 Y126.386 E.02461
G2 X126.407 Y127.058 I3.638 J-4.406 E.03757
G2 X127.585 Y127.376 I2.181 J-5.736 E.03756
G1 X128.004 Y127.394 E.01289
G1 X128.804 Y127.308 E.02469
G1 X129.207 Y127.193 E.0129
G1 X129.939 Y126.861 E.02469
G2 X130.877 Y126.08 I-3.484 J-5.135 E.03756
G2 X131.518 Y125.047 I-4.215 J-3.334 E.03744
G1 X131.755 Y124.262 E.02518
G2 X131.787 Y123.133 I-4.535 J-.693 E.03481
; WIPE_START
G1 X131.804 Y123.762 E-.23924
G1 X131.755 Y124.262 E-.19099
G1 X131.518 Y125.047 E-.31143
G1 X131.495 Y125.089 E-.01833
; WIPE_END
G1 E-.04 F1800
G1 X125.708 Y122.115 Z5 F36000
G1 Z4.6
G1 E.8 F1800
G1 F12000
G3 X127.253 Y120.967 I2.332 J1.525 E.06036
G1 X127.957 Y120.866 E.02186
G1 X128.38 Y120.894 E.01305
G1 X128.983 Y121.063 E.01921
G1 X129.443 Y121.294 E.01585
G1 X129.904 Y121.677 E.01841
G1 X130.245 Y122.094 E.01655
G1 X130.47 Y122.533 E.01514
G1 X130.647 Y123.155 E.01987
G1 X130.673 Y123.658 E.01548
G1 X130.576 Y124.295 E.01982
G3 X130.193 Y125.097 I-2.415 J-.663 E.02744
G1 X129.767 Y125.58 E.01979
G1 X129.389 Y125.858 E.01442
G1 X128.784 Y126.133 E.02042
G1 X128.347 Y126.232 E.01377
G3 X127.249 Y126.153 I-.284 J-3.75 E.03395
G1 X126.851 Y126.007 E.01301
G3 X126.148 Y125.529 I1.539 J-3.017 E.02619
G1 X125.729 Y125.036 E.01988
G1 X125.497 Y124.589 E.01548
G1 X125.32 Y123.969 E.0198
G1 X125.288 Y123.543 E.01315
G1 X125.378 Y122.884 E.02042
G1 X125.537 Y122.429 E.01482
G1 X125.68 Y122.167 E.00915
G1 X125.377 Y121.934 F36000
G1 F12000
G3 X126.357 Y120.955 I2.91 J1.931 E.04283
G1 X126.879 Y120.699 E.01788
G1 X127.199 Y120.594 E.01035
G1 X127.903 Y120.493 E.02186
G1 X128.444 Y120.523 E.01663
G1 X129.114 Y120.709 E.02138
G1 X129.61 Y120.955 E.017
G3 X130.833 Y122.429 I-1.601 J2.571 E.05988
G1 X131.01 Y123.051 E.01987
G1 X131.051 Y123.604 E.01702
G3 X130.919 Y124.465 I-7.825 J-.755 E.02679
G3 X130.496 Y125.322 I-2.849 J-.875 E.02951
G1 X130.05 Y125.83 E.02075
G3 X128.365 Y126.608 I-2.145 J-2.429 E.05787
G1 X127.829 Y126.623 E.01646
G1 X127.192 Y126.526 E.0198
G1 X126.671 Y126.338 E.01703
G1 X126.149 Y126.014 E.01887
G1 X125.861 Y125.773 E.01152
G1 X125.441 Y125.28 E.01992
G1 X125.175 Y124.796 E.01696
G1 X124.957 Y124.073 E.02321
G1 X124.912 Y123.52 E.01704
G1 X124.949 Y123.084 E.01347
G1 X125.09 Y122.543 E.01718
G1 X125.352 Y121.988 E.01884
; WIPE_START
G1 X125.09 Y122.543 E-.23302
G1 X124.949 Y123.084 E-.21244
G1 X124.912 Y123.52 E-.16654
G1 X124.944 Y123.908 E-.14801
; WIPE_END
G1 E-.04 F1800
G1 X131.405 Y123.083 Z5 F36000
G1 Z4.6
G1 E.8 F1800
; LINE_WIDTH: 0.423601
G1 F12000
G1 X131.193 Y122.326 E.02436
G1 X130.937 Y121.773 E.01892
G2 X130.267 Y120.971 I-3.74 J2.443 E.0325
G2 X128.441 Y120.139 I-2.412 J2.871 E.06302
G1 X127.849 Y120.113 E.01837
G1 X127.145 Y120.218 E.02207
G1 X126.613 Y120.398 E.01745
G1 X126.06 Y120.693 E.01943
G2 X125.044 Y121.752 I2.173 J3.1 E.04581
G1 X124.73 Y122.409 E.02258
G2 X124.531 Y123.586 I3.932 J1.271 E.03717
G1 X124.581 Y124.093 E.0158
G1 X124.773 Y124.795 E.0226
G1 X125.031 Y125.348 E.01891
G1 X125.573 Y126.02 E.02677
G1 X126.044 Y126.408 E.01894
G2 X126.947 Y126.851 I1.917 J-2.768 E.03133
G1 X127.637 Y126.988 E.02182
G1 X127.964 Y127.012 E.01016
G2 X129.049 Y126.845 I-.071 J-4.07 E.03418
G1 X129.753 Y126.525 E.02397
G2 X131.417 Y123.856 I-1.849 J-3.006 E.10114
G2 X131.408 Y123.143 I-7.647 J-.258 E.02213
G1 X143.449 Y114.447 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X141.856 Y114.141 I-2.393 J8.17 E.0539
G1 X132.588 Y123.427 E.43519
G3 X132.428 Y124.755 I-5.009 J.068 E.04449
G1 X139.666 Y131.992 E.33954
G1 X139.447 Y131.902 E.00785
G1 X152.623 Y118.726 E.61812
G3 X153.356 Y119.262 I-2.174 J3.741 E.03017
G2 X156.721 Y122.304 I27.799 J-27.361 E.15056
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.243 J13.195 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X137.098 Y134.15 Z5 F36000
G1 X112.9 Y133.689 Z5
G1 Z4.6
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.502 J13.621 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.18 I-19.499 J-25.077 E.15409
G3 X103.362 Y118.717 I2.108 J2.301 E.02677
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X123.544 Y124.777 E.33757
G3 X123.382 Y123.385 I4.19 J-1.195 E.04671
G1 X114.137 Y114.139 E.43371
G2 X112.541 Y114.437 I.888 J9.192 E.05391
G1 X106.739 Y134.053 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X106.583 Y132.979 I-9.638 J.846 E.03336
G2 X106.101 Y131.87 I-6.943 J2.365 E.03719
G1 X105.799 Y131.458 E.01568
G1 X105.218 Y130.861 E.02563
G1 X104.803 Y130.565 E.01565
G1 X104.063 Y130.18 E.02563
G1 X103.573 Y130.029 E.01575
G1 X102.747 Y129.897 E.02572
G1 X101.858 Y129.944 E.02735
G1 X101.359 Y130.062 E.01575
G1 X100.585 Y130.365 E.02555
G1 X100.151 Y130.632 E.01566
G1 X99.508 Y131.165 E.02564
G1 X99.18 Y131.554 E.01566
G1 X98.738 Y132.262 E.02563
G1 X98.549 Y132.735 E.01565
G1 X98.351 Y133.545 E.02563
G1 X98.32 Y134.054 E.01567
G1 X98.386 Y134.885 E.02563
G1 X98.516 Y135.378 E.01565
G1 X98.841 Y136.146 E.02564
G1 X99.119 Y136.574 E.01567
G1 X99.668 Y137.201 E.02562
G1 X100.067 Y137.519 E.01567
G1 X100.785 Y137.942 E.02561
G1 X101.265 Y138.119 E.01569
G1 X102.079 Y138.295 E.0256
G1 X102.588 Y138.313 E.01566
G1 X103.418 Y138.224 E.02563
G1 X103.908 Y138.08 E.01569
G1 X104.668 Y137.735 E.02566
G1 X105.095 Y137.438 E.01599
G1 X105.699 Y136.881 E.02524
G1 X106.006 Y136.474 E.01568
G1 X106.41 Y135.744 E.02563
G1 X106.574 Y135.261 E.01566
G1 X106.728 Y134.442 E.02563
G1 X106.737 Y134.113 E.01011
G1 X106.362 Y134.043 F36000
G1 F12000
G2 X106.183 Y132.958 I-7.101 J.611 E.03381
G2 X105.757 Y132.037 I-8.247 J3.258 E.0312
G2 X104.968 Y131.145 I-4.328 J3.033 E.03666
G2 X103.916 Y130.529 I-3.277 J4.386 E.03757
G1 X103.495 Y130.398 E.01353
G1 X102.727 Y130.275 E.02391
G1 X101.908 Y130.319 E.02519
G2 X100.75 Y130.705 I1.17 J5.437 E.03758
G1 X100.363 Y130.946 E.01402
G1 X99.772 Y131.436 E.02357
G1 X99.5 Y131.754 E.01289
G1 X99.073 Y132.436 E.0247
G2 X98.724 Y133.605 I5.271 J2.212 E.03756
G1 X98.702 Y134.11 E.01554
G1 X98.76 Y134.825 E.02204
G1 X98.888 Y135.289 E.01477
G1 X99.176 Y135.972 E.02279
G1 X99.407 Y136.33 E.01307
G1 X99.932 Y136.93 E.02452
G2 X100.951 Y137.602 I3.634 J-4.399 E.03757
G1 X101.344 Y137.751 E.01292
G1 X102.129 Y137.92 E.02468
G1 X102.632 Y137.929 E.01546
G1 X103.348 Y137.852 E.02211
G2 X104.484 Y137.405 I-1.596 J-5.716 E.0376
G2 X105.421 Y136.624 I-3.426 J-5.063 E.03751
G1 X105.722 Y136.208 E.01578
G1 X106.066 Y135.588 E.0218
G2 X106.36 Y134.103 I-4.309 J-1.627 E.04673
; WIPE_START
G1 X106.352 Y134.401 E-.11354
G1 X106.224 Y135.081 E-.26301
G1 X106.066 Y135.588 E-.20155
G1 X105.834 Y136.006 E-.1819
; WIPE_END
G1 E-.04 F1800
G1 X100.258 Y132.649 Z5 F36000
G1 Z4.6
G1 E.8 F1800
G1 F12000
G1 X100.579 Y132.249 E.01575
G1 X101.059 Y131.844 E.01929
G3 X101.797 Y131.511 I1.444 J2.216 E.02497
G1 X102.501 Y131.411 E.02186
G1 X102.925 Y131.439 E.01305
G1 X103.5 Y131.597 E.01834
G1 X103.974 Y131.83 E.01622
G1 X104.303 Y132.076 E.01264
G1 X104.645 Y132.445 E.01545
G1 X104.974 Y132.973 E.01911
G1 X105.133 Y133.428 E.01482
G1 X105.223 Y134.087 E.02042
G1 X105.194 Y134.502 E.01279
G1 X105.004 Y135.163 E.02115
G1 X104.732 Y135.649 E.01711
G1 X104.303 Y136.133 E.01987
G3 X103.556 Y136.592 I-1.741 J-2.002 E.02706
G1 X102.936 Y136.768 E.0198
G3 X102.048 Y136.753 I-.401 J-2.474 E.02744
G1 X101.431 Y136.566 E.0198
G1 X100.927 Y136.262 E.01811
G1 X100.693 Y136.073 E.00924
G1 X100.274 Y135.582 E.01983
G1 X100.07 Y135.213 E.01297
G1 X99.883 Y134.602 E.01961
G1 X99.837 Y134.044 E.0172
G1 X99.935 Y133.37 E.02094
G3 X100.229 Y132.702 I2.378 J.648 E.02252
G1 X99.939 Y132.449 F36000
G1 F12000
G1 X100.312 Y131.983 E.01837
G1 X100.833 Y131.543 E.02095
G3 X101.743 Y131.138 I1.622 J2.424 E.03076
G1 X102.448 Y131.037 E.02186
G1 X102.974 Y131.064 E.01618
G1 X103.632 Y131.243 E.02096
G1 X104.154 Y131.499 E.01787
G1 X104.57 Y131.81 E.01594
G1 X104.947 Y132.219 E.0171
G1 X105.305 Y132.792 E.02076
G3 X105.586 Y134.333 I-2.949 J1.334 E.04861
G1 X105.486 Y134.932 E.01865
G1 X105.305 Y135.418 E.01594
G1 X105.033 Y135.875 E.01635
G1 X104.57 Y136.4 E.02152
G1 X104.14 Y136.719 E.01644
G1 X103.659 Y136.954 E.01646
G1 X103.04 Y137.131 E.0198
G1 X102.515 Y137.178 E.01619
G1 X101.983 Y137.125 E.01642
G1 X101.322 Y136.927 E.02119
G1 X100.82 Y136.658 E.01752
G1 X100.41 Y136.323 E.01624
G1 X99.986 Y135.825 E.02011
G3 X99.48 Y134.486 I2.783 J-1.816 E.04433
G1 X99.466 Y133.951 E.01646
G1 X99.562 Y133.314 E.0198
G1 X99.749 Y132.794 E.01696
G1 X99.91 Y132.502 E.01025
; WIPE_START
G1 X99.749 Y132.794 E-.12677
G1 X99.562 Y133.314 E-.20975
G1 X99.466 Y133.951 E-.24483
G1 X99.478 Y134.421 E-.17864
; WIPE_END
G1 E-.04 F1800
G1 X105.98 Y134.033 Z5 F36000
G1 Z4.6
G1 E.8 F1800
; LINE_WIDTH: 0.425498
G1 F12000
G1 X105.876 Y133.267 E.0241
G2 X105.445 Y132.256 I-4.156 J1.175 E.03433
G2 X103.435 Y130.774 I-3.032 J2.008 E.07947
G1 X102.707 Y130.66 E.02299
G1 X101.96 Y130.71 E.02332
G1 X101.495 Y130.817 E.0149
G1 X100.919 Y131.052 E.01939
G1 X100.605 Y131.238 E.01138
G1 X100.041 Y131.711 E.02295
G2 X99.376 Y132.696 I3.058 J2.784 E.03716
G2 X99.237 Y135.141 I3.355 J1.417 E.07789
G1 X99.518 Y135.794 E.02217
G1 X99.696 Y136.077 E.0104
G1 X100.117 Y136.564 E.02008
G1 X100.588 Y136.953 E.01903
G2 X102.592 Y137.553 I1.98 J-2.963 E.06622
G1 X103.143 Y137.494 E.01728
G1 X103.763 Y137.317 E.02008
G1 X104.297 Y137.069 E.01838
G2 X105.716 Y135.429 I-1.922 J-3.096 E.06863
G1 X105.854 Y135.012 E.0137
G1 X105.969 Y134.36 E.02062
G1 X105.978 Y134.092 E.00836
; WIPE_START
G1 X105.969 Y134.36 E-.10186
G1 X105.854 Y135.012 E-.25135
G1 X105.716 Y135.429 E-.16701
G1 X105.458 Y135.915 E-.2092
G1 X105.412 Y135.981 E-.03059
; WIPE_END
G1 E-.04 F1800
G1 X98.218 Y133.429 Z5 F36000
G1 X97.988 Y133.348 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X98.002 Y134.967 I4.829 J.769 E.05397
G1 X94.573 Y138.397 E.16088
G1 X89.965 Y135.329 E.18364
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.314 J-2.779 E.00842
G1 X122.456 Y130.135 E.63778
G3 X126.34 Y129.657 I5.812 J31.221 E.12989
G1 X127.837 Y128.16 E.07021
G2 X128.156 Y128.159 I.153 J-1.604 E.01061
G1 X129.657 Y129.659 E.07039
G3 X133.534 Y130.139 I-1.94 J31.584 E.12968
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.763 J-3.097 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02426
G1 X168.093 Y133.96 E.0568
G2 X167.03 Y132.345 I-4.208 J1.609 E.06465
G3 X164.508 Y129.869 I23.144 J-26.104 E.11729
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.038 J18.155 E.18072
G1 X149.792 Y136.909 E.04984
G3 X148.87 Y133.521 I3.602 J-2.799 E.11957
G1 X127.857 Y112.508 E.98577
G2 X128.138 Y112.507 I.133 J-2.693 E.00933
G1 X107.099 Y133.547 E.98701
G3 X106.187 Y136.894 I-4.52 J.567 E.11805
G1 X107.252 Y137.958 E.04994
G2 X103.68 Y142.062 I21.495 J22.316 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.886 J-14.381 E.18439
G1 X99.739 Y130.445 E.24549
G3 X103.385 Y129.584 I2.79 J3.665 E.12801
G1 X120.021 Y112.948 E.78042
G1 X120.456 Y112.783 E.01543
G1 X126.786 Y119.112 E.29695
G3 X129.203 Y119.118 I1.198 J4.639 E.08106
G1 X135.538 Y112.784 E.29717
G1 X135.998 Y112.973 E.01652
G1 X152.604 Y129.578 E.77898
G3 X156.244 Y130.457 I.828 J4.549 E.12791
G1 X161.264 Y125.437 E.2355
G2 X160.005 Y124.422 I-3.679 J3.274 E.05389
; WIPE_START
G1 X160.782 Y124.94 E-.35493
G1 X161.264 Y125.437 E-.26302
G1 X161 Y125.701 E-.14205
; WIPE_END
G1 E-.04 F1800
G1 X153.642 Y127.729 Z5 F36000
G1 X100.537 Y142.367 Z5
G1 Z4.6
G1 E.8 F1800
G1 F15476.087
G1 X99.181 Y141.464 E.05401
G1 X101.97 Y138.675 E.13084
G1 X102.027 Y138.684 E.00191
G2 X103.587 Y138.585 I.468 J-4.948 E.05207
; CHANGE_LAYER
; Z_HEIGHT: 4.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X103.006 Y138.687 E-.22402
G1 X102.027 Y138.684 E-.37216
G1 X101.97 Y138.675 E-.02187
G1 X101.706 Y138.939 E-.14195
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
G1 X127.004 Y121.478
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.028 Y121.469 E.00086
G3 X127.673 Y121.279 I.964 J2.089 E.02236
G1 X127.983 Y121.257 E.01034
G3 X126.741 Y121.627 I.008 J2.3 E.43585
G1 X126.952 Y121.507 E.00804
G1 X127.166 Y121.836 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.191 Y121.826 E.00082
G3 X127.727 Y121.669 I.8 J1.732 E.01722
G1 X127.983 Y121.65 E.0079
G3 X126.953 Y121.957 I.007 J1.908 E.33484
G1 X127.114 Y121.865 E.00571
; WIPE_START
M204 S10000
G1 X127.191 Y121.826 E-.03283
G1 X127.446 Y121.727 E-.1038
G1 X127.727 Y121.669 E-.10909
G1 X127.983 Y121.65 E-.09776
M73 P70 R5
G1 X128.255 Y121.67 E-.10357
G1 X128.522 Y121.728 E-.10358
G1 X128.777 Y121.823 E-.10358
G1 X129.016 Y121.953 E-.10359
G1 X129.021 Y121.957 E-.00221
; WIPE_END
G1 E-.04 F1800
G1 X122.153 Y125.286 Z5.2 F36000
G1 X100.805 Y135.632 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.791 Y135.609 E.00087
G3 X102.217 Y131.824 I1.74 J-1.506 E.16389
G3 X102.855 Y131.825 I.315 J2.223 E.02126
G3 X101.023 Y135.841 I-.324 J2.279 E.28365
G1 X100.848 Y135.673 E.00804
G1 X101.091 Y135.349 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.271 Y132.213 I1.444 J-1.247 E.12572
G1 X102.528 Y132.194 E.0079
G3 X101.131 Y135.394 I.007 J1.908 E.23287
; WIPE_START
M204 S10000
G1 X100.92 Y135.138 E-.12616
G1 X100.79 Y134.899 E-.10359
G1 X100.694 Y134.643 E-.10357
G1 X100.636 Y134.376 E-.10391
G1 X100.618 Y134.09 E-.10905
G1 X100.637 Y133.833 E-.09776
G1 X100.694 Y133.567 E-.10357
G1 X100.706 Y133.536 E-.01238
; WIPE_END
G1 E-.04 F1800
G1 X108.335 Y133.313 Z5.2 F36000
G1 X152.46 Y132.022 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.483 Y132.012 E.00086
G3 X153.128 Y131.824 I.96 J2.092 E.02237
G3 X153.767 Y131.825 I.315 J2.224 E.02126
G3 X152.196 Y132.17 I-.324 J2.279 E.42516
G1 X152.407 Y132.051 E.00805
G1 X152.617 Y132.383 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.647 Y132.37 E.00101
G3 X153.183 Y132.213 I.8 J1.732 E.01722
G1 X153.439 Y132.194 E.0079
G3 X152.409 Y132.501 I.007 J1.908 E.33484
G1 X152.565 Y132.412 E.00552
; WIPE_START
M204 S10000
G1 X152.647 Y132.37 E-.03519
G1 X152.902 Y132.271 E-.10382
G1 X153.183 Y132.213 E-.10905
G1 X153.439 Y132.194 E-.09774
G1 X153.711 Y132.214 E-.10361
G1 X153.978 Y132.272 E-.10388
G1 X154.246 Y132.374 E-.10906
G1 X154.472 Y132.498 E-.09765
; WIPE_END
G1 E-.04 F1800
G1 X153.708 Y140.092 Z5.2 F36000
G1 X153.292 Y144.224 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98336
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.395 J1.749 E.04338
G3 X88.408 Y132.053 I2.735 J2.126 E.03249
G2 X91.148 Y129.685 I-14.52 J-19.573 E.12022
G2 X93.594 Y126.16 I-11.287 J-10.443 E.14279
G3 X94.42 Y124.708 I12.323 J6.048 E.05547
G3 X95.013 Y124.286 I1.249 J1.127 E.02433
G2 X97.525 Y123.019 I-21.46 J-45.681 E.09335
G2 X101.007 Y120.323 I-8.606 J-14.711 E.14647
G3 X102.746 Y118.697 I16.206 J15.588 E.07902
G3 X103.976 Y118.067 I2.75 J3.856 E.04602
G2 X107.047 Y116.997 I-16.522 J-52.379 E.10788
G2 X110.366 Y115.274 I-7.762 J-19.009 E.12423
G3 X112.192 Y114.201 I10.972 J16.587 E.07026
G3 X113.876 Y113.812 I2.035 J4.97 E.05758
G2 X117.401 Y113.355 I-2.348 J-31.919 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.57 E.10417
G3 X122.451 Y111.606 I9.399 J20.393 E.07347
G3 X123.43 Y111.594 I.513 J2.043 E.03276
G2 X125.813 Y112.005 I37.865 J-212.736 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16542
G3 X132.882 Y111.551 I5.296 J24.857 E.07085
G3 X133.229 Y111.549 I.18 J1.876 E.01153
G3 X134.227 Y111.868 I-.723 J3.991 E.03484
G2 X137.511 Y113.104 I11.112 J-24.53 E.11647
G2 X140.702 Y113.674 I5.147 J-19.606 E.10764
G3 X143.068 Y113.961 I-1.514 J22.33 E.07911
G3 X144.642 Y114.679 I-1.436 J5.237 E.05763
G2 X148.014 Y116.603 I17.396 J-26.561 E.12886
G2 X151.656 Y117.949 I12.731 J-28.863 E.12888
G3 X153.297 Y118.757 I-1.46 J5.035 E.06097
G3 X154.769 Y120.137 I-13.769 J16.154 E.06697
G2 X158.902 Y123.348 I14.663 J-14.613 E.17409
G3 X161.003 Y124.671 I-9.762 J17.834 E.0824
G3 X161.851 Y125.634 I-2.918 J3.424 E.04272
G2 X163.68 Y128.324 I49.834 J-31.909 E.10791
G2 X166.202 Y131.082 I16.837 J-12.865 E.12414
G3 X167.71 Y132.567 I-14.864 J16.598 E.07024
G3 X168.522 Y134.093 I-4.097 J3.158 E.05761
G1 X168.658 Y134.455 E.01281
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.782 E1.86611
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.139 J2.087 E.05194
G3 X88.163 Y131.747 I2.988 J2.222 E.03456
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10971
G2 X93.249 Y125.974 I-11.005 J-10.177 E.12911
G3 X94.112 Y124.464 I12.345 J6.059 E.05347
G3 X94.828 Y123.94 I1.546 J1.357 E.0275
G2 X97.331 Y122.678 I-21.512 J-45.791 E.08612
G2 X100.735 Y120.04 I-8.414 J-14.373 E.1327
G3 X102.511 Y118.382 I16.29 J15.673 E.07471
G3 X103.844 Y117.698 I2.999 J4.197 E.04621
G2 X106.326 Y116.856 I-155.482 J-462.531 E.08051
G2 X110.161 Y114.94 I-7.082 J-18.973 E.13198
G3 X112.029 Y113.845 I11.124 J16.833 E.06658
G3 X113.833 Y113.423 I2.199 J5.334 E.05719
G2 X117.323 Y112.971 I-2.31 J-31.547 E.10818
G2 X120.25 Y112.069 I-3.379 J-16.163 E.09424
G3 X122.349 Y111.227 I9.362 J20.307 E.06952
G3 X123.486 Y111.206 I.614 J2.41 E.03527
G2 X125.869 Y111.616 I39.543 J-222.459 E.0743
G2 X130.711 Y111.521 I2.13 J-14.776 E.14949
G3 X132.851 Y111.16 I5.314 J24.958 E.06669
G3 X133.273 Y111.159 I.213 J2.329 E.01299
G3 X134.376 Y111.505 I-.758 J4.351 E.0356
G2 X137.615 Y112.726 I10.993 J-24.249 E.10646
G2 X140.743 Y113.284 I5.04 J-19.215 E.09773
G3 X143.156 Y113.579 I-1.533 J22.524 E.07474
G3 X144.845 Y114.343 I-1.516 J5.602 E.05719
G2 X148.18 Y116.248 I17.233 J-26.298 E.11811
G2 X151.783 Y117.578 I12.596 J-28.588 E.11808
G3 X153.54 Y118.449 I-1.58 J5.393 E.06056
G3 X155.042 Y119.856 I-13.97 J16.417 E.06326
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.229 I-11.662 J21.074 E.07119
G3 X162.173 Y125.409 I-3 J3.892 E.04975
G2 X163.993 Y128.088 I49.743 J-31.846 E.09951
G2 X166.471 Y130.796 I16.518 J-12.622 E.11296
G3 X168.012 Y132.318 I-14.979 J16.723 E.06658
G3 X168.887 Y133.951 I-4.412 J3.413 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26194
; WIPE_END
G1 E-.04 F1800
G1 X152.403 Y138.591 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.455 Y138.605 E.00177
G2 X154.021 Y138.671 I.99 J-4.861 E.05221
G1 X156.88 Y141.53 E.13412
G1 X161.572 Y138.547 E.18446
G1 X157.969 Y134.944 E.16904
G2 X157.974 Y133.324 I-4.322 J-.824 E.05403
G1 X157.651 Y134.053 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X157.495 Y132.979 I-9.651 J.847 E.03337
G1 X157.377 Y132.62 E.0116
G1 X157.012 Y131.87 E.02564
G1 X156.711 Y131.458 E.01565
G1 X156.129 Y130.861 E.02564
G1 X155.714 Y130.564 E.01568
G1 X154.975 Y130.18 E.0256
G1 X154.485 Y130.029 E.01574
G1 X153.653 Y129.896 E.02587
G1 X153.155 Y129.906 E.01532
G1 X152.331 Y130.039 E.02565
G1 X151.85 Y130.208 E.01566
G1 X151.11 Y130.593 E.02562
G1 X150.705 Y130.906 E.01575
G1 X150.121 Y131.507 E.02573
G1 X149.65 Y132.261 E.02733
G1 X149.46 Y132.735 E.01567
G1 X149.262 Y133.545 E.02562
G1 X149.231 Y134.054 E.01566
G1 X149.298 Y134.885 E.02564
G1 X149.428 Y135.378 E.01564
G1 X149.752 Y136.146 E.02564
G1 X150.031 Y136.574 E.01567
G1 X150.58 Y137.201 E.02563
G1 X150.979 Y137.519 E.01567
G1 X151.697 Y137.942 E.02562
G1 X152.175 Y138.119 E.01566
G1 X152.991 Y138.295 E.02563
G1 X153.5 Y138.313 E.01566
G1 X154.33 Y138.224 E.02563
G1 X154.819 Y138.081 E.01567
G1 X155.58 Y137.735 E.02567
G1 X156.007 Y137.439 E.01598
G1 X156.611 Y136.88 E.02526
G1 X156.918 Y136.474 E.01566
G1 X157.322 Y135.744 E.02563
G1 X157.486 Y135.261 E.01566
G1 X157.64 Y134.441 E.02564
G1 X157.649 Y134.113 E.0101
G1 X157.274 Y134.043 F36000
G1 F12000
G2 X157.076 Y132.895 I-6.708 J.563 E.03583
G1 X156.757 Y132.208 E.02326
G1 X156.48 Y131.769 E.01597
G2 X155.593 Y130.932 I-4.193 J3.558 E.03754
G2 X154.606 Y130.455 I-3.549 J6.088 E.03373
G2 X153.506 Y130.273 I-1.703 J6.875 E.03428
G1 X153.215 Y130.278 E.00896
G1 X152.421 Y130.406 E.02472
G2 X151.311 Y130.913 I1.737 J5.271 E.03757
G2 X150.42 Y131.741 I3.359 J4.508 E.03744
G1 X149.985 Y132.436 E.02518
G2 X149.636 Y133.605 I5.259 J2.209 E.03757
G2 X149.671 Y134.825 I5.867 J.44 E.03757
G1 X149.8 Y135.288 E.01477
G1 X150.088 Y135.972 E.0228
G1 X150.322 Y136.334 E.01324
G1 X150.844 Y136.93 E.02436
G2 X151.863 Y137.602 I3.713 J-4.52 E.03757
G2 X153.041 Y137.92 I2.179 J-5.728 E.03756
G1 X153.547 Y137.929 E.01554
G1 X154.259 Y137.852 E.02202
G1 X154.663 Y137.737 E.0129
G1 X155.396 Y137.405 E.02472
G2 X156.333 Y136.624 I-3.427 J-5.064 E.03753
G1 X156.634 Y136.208 E.01577
G1 X156.977 Y135.588 E.0218
G2 X157.272 Y134.103 I-4.426 J-1.65 E.04671
; WIPE_START
G1 X157.264 Y134.401 E-.11341
G1 X157.141 Y135.056 E-.25306
G1 X156.977 Y135.588 E-.21151
G1 X156.745 Y136.007 E-.18202
; WIPE_END
G1 E-.04 F1800
G1 X150.985 Y132.99 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
G1 F12000
G1 X151.331 Y132.434 E.02013
G1 X151.684 Y132.059 E.01583
G1 X151.993 Y131.83 E.01182
G3 X152.709 Y131.511 I1.713 J2.883 E.02414
G1 X153.413 Y131.411 E.02183
G1 X153.836 Y131.439 E.01304
G1 X154.406 Y131.596 E.01815
G1 X154.599 Y131.674 E.00641
G1 X155.184 Y132.051 E.02139
G3 X155.729 Y132.687 I-2.02 J2.285 E.02581
G1 X156.017 Y133.32 E.02138
G1 X156.11 Y133.739 E.01319
G1 X156.118 Y134.249 E.01567
G1 X156.032 Y134.839 E.0183
G3 X155.643 Y135.649 I-2.417 J-.661 E.02777
G1 X155.215 Y136.133 E.01987
G1 X154.845 Y136.402 E.01405
G1 X154.24 Y136.677 E.02043
G1 X153.81 Y136.775 E.01355
G1 X153.146 Y136.781 E.02038
G1 X152.602 Y136.663 E.01711
G1 X151.99 Y136.378 E.02073
G1 X151.642 Y136.111 E.01351
G1 X151.186 Y135.582 E.02145
G1 X150.982 Y135.213 E.01297
G1 X150.795 Y134.602 E.01961
G1 X150.744 Y134.091 E.01578
G1 X150.773 Y133.708 E.01182
G3 X150.964 Y133.046 I3.459 J.638 E.0212
G1 X150.637 Y132.843 F36000
G1 F12000
G3 X152.656 Y131.138 I2.833 J1.306 E.08385
G1 X153.359 Y131.037 E.02183
G1 X153.885 Y131.064 E.01618
G1 X154.54 Y131.243 E.02086
G1 X154.803 Y131.357 E.00881
G1 X155.388 Y131.735 E.02139
G1 X155.792 Y132.13 E.01737
G1 X156.072 Y132.531 E.01503
G1 X156.36 Y133.164 E.02138
G1 X156.483 Y133.676 E.01617
G1 X156.505 Y134.204 E.01624
G1 X156.405 Y134.893 E.02139
G1 X156.217 Y135.418 E.01713
G1 X155.945 Y135.875 E.01635
G1 X155.481 Y136.4 E.02152
G3 X154.106 Y137.098 I-2.113 J-2.458 E.04785
G1 X153.48 Y137.177 E.01941
G3 X152.126 Y136.882 I.08 J-3.623 E.04282
G1 X151.599 Y136.557 E.01905
G1 X151.356 Y136.357 E.00965
G1 X150.897 Y135.825 E.02159
G3 X150.404 Y133.628 I2.636 J-1.745 E.07075
G3 X150.616 Y132.899 I3.839 J.72 E.02334
; WIPE_START
G1 X150.56 Y133.05 E-.06109
G1 X150.404 Y133.628 E-.22738
G1 X150.371 Y134.02 E-.14972
G1 X150.393 Y134.502 E-.1833
G1 X150.466 Y134.859 E-.13851
; WIPE_END
G1 E-.04 F1800
G1 X156.891 Y134.033 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; LINE_WIDTH: 0.425116
G1 F12000
G1 X156.788 Y133.266 E.02408
G1 X156.69 Y132.954 E.0102
G1 X156.417 Y132.374 E.01996
G1 X156.096 Y131.906 E.01767
G2 X154.832 Y130.954 I-2.944 J2.589 E.04961
G1 X154.35 Y130.775 E.01602
G1 X153.594 Y130.657 E.02385
G1 X153.276 Y130.659 E.00989
G1 X152.602 Y130.762 E.02123
G1 X152.069 Y130.942 E.01754
G1 X151.516 Y131.237 E.01951
G2 X150.723 Y131.978 I2.293 J3.249 E.03392
G1 X150.327 Y132.609 E.02319
G2 X150.014 Y133.666 I4.017 J1.766 E.03442
G2 X150.148 Y135.141 I3.786 J.398 E.04643
G1 X150.43 Y135.794 E.02215
G1 X150.611 Y136.081 E.01056
G1 X151.068 Y136.606 E.02167
G2 X152.403 Y137.395 I2.613 J-2.897 E.04863
G1 X153.015 Y137.528 E.01951
G1 X153.507 Y137.553 E.01533
G1 X154.188 Y137.474 E.02137
G1 X154.808 Y137.264 E.0204
G1 X155.32 Y137 E.01792
G2 X156.627 Y135.429 I-2.058 J-3.043 E.06451
G2 X156.888 Y134.093 I-4.502 J-1.571 E.04255
G1 X160.005 Y124.422 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X161.265 Y125.436 I-2.673 J4.609 E.05386
G1 X156.244 Y130.457 E.23554
G2 X152.604 Y129.578 I-2.812 J3.67 E.12791
G1 X135.991 Y112.966 E.77934
G1 X135.531 Y112.79 E.01632
G1 X129.203 Y119.118 E.29685
G2 X126.786 Y119.112 I-1.22 J4.634 E.08106
G1 X120.456 Y112.783 E.29695
G1 X120.021 Y112.948 E.01543
G1 X103.385 Y129.584 E.78042
G2 X99.739 Y130.445 I-.856 J4.526 E.12801
G1 X94.506 Y125.212 E.24549
G3 X91.467 Y129.849 I-19.924 J-9.744 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.067 J18.212 E.18071
G1 X106.187 Y136.894 E.04994
G2 X107.099 Y133.547 I-3.609 J-2.78 E.11805
G1 X128.138 Y112.507 E.98701
G3 X127.857 Y112.508 I-.148 J-2.692 E.00933
G1 X148.87 Y133.521 E.98577
G2 X149.792 Y136.909 I4.523 J.59 E.11957
G1 X148.729 Y137.972 E.04984
G3 X152.298 Y142.079 I-24.78 J25.14 E.18067
G1 X164.508 Y129.869 E.57279
G3 X167.552 Y132.93 I-267.011 J268.541 E.1432
G3 X168.093 Y133.96 I-8.397 J5.064 E.03862
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.502 J-3.233 E.00975
G1 X133.534 Y130.139 E.63753
G2 X129.657 Y129.659 I-5.817 J31.108 E.12968
G1 X128.156 Y128.159 E.07039
G3 X127.837 Y128.16 I-.167 J-1.603 E.01061
G1 X126.34 Y129.657 E.07021
G2 X122.456 Y130.135 I1.928 J31.699 E.12989
G1 X108.861 Y116.54 E.63778
G3 X108.636 Y116.657 I-1.539 J-2.66 E.00843
G1 X89.965 Y135.329 E.87591
G1 X88.609 Y134.427 E.05401
G1 X97.988 Y133.348 F36000
G1 F15476.087
G2 X98.002 Y134.967 I4.829 J.769 E.05397
G1 X94.573 Y138.397 E.16088
G1 X99.181 Y141.464 E.18364
G1 X101.97 Y138.675 E.13084
G1 X102.027 Y138.684 E.00191
G2 X103.587 Y138.585 I.468 J-4.948 E.05207
G1 X106.739 Y134.053 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X106.583 Y132.979 I-9.651 J.847 E.03337
G1 X106.465 Y132.62 E.01161
G1 X106.101 Y131.87 E.02562
G1 X105.799 Y131.458 E.01568
G1 X105.218 Y130.861 E.02563
G1 X104.802 Y130.564 E.01568
G1 X104.063 Y130.18 E.0256
G1 X103.573 Y130.029 E.01575
G1 X102.747 Y129.897 E.02572
G1 X101.858 Y129.944 E.02735
G1 X101.359 Y130.062 E.01575
G1 X100.585 Y130.365 E.02555
G1 X100.151 Y130.632 E.01566
G1 X99.508 Y131.165 E.02564
G1 X99.18 Y131.554 E.01566
G1 X98.738 Y132.262 E.02563
G1 X98.549 Y132.735 E.01565
G1 X98.351 Y133.545 E.02563
G1 X98.32 Y134.054 E.01567
G1 X98.386 Y134.885 E.02563
G1 X98.516 Y135.378 E.01565
G1 X98.841 Y136.146 E.02564
G1 X99.119 Y136.574 E.01567
G1 X99.668 Y137.201 E.02562
G1 X100.067 Y137.519 E.01567
G1 X100.785 Y137.942 E.02562
G1 X101.264 Y138.119 E.01567
G1 X102.079 Y138.295 E.02562
G1 X102.588 Y138.313 E.01566
G1 X103.418 Y138.224 E.02563
G1 X103.908 Y138.08 E.01569
G1 X104.668 Y137.735 E.02565
G1 X105.095 Y137.438 E.01599
G1 X105.699 Y136.881 E.02524
G1 X106.006 Y136.474 E.01568
G1 X106.41 Y135.744 E.02563
G1 X106.574 Y135.261 E.01566
G1 X106.728 Y134.442 E.02563
G1 X106.737 Y134.113 E.01011
G1 X106.362 Y134.043 F36000
G1 F12000
G2 X106.164 Y132.895 I-6.711 J.564 E.03583
G1 X105.846 Y132.208 E.02326
G1 X105.568 Y131.768 E.01598
G2 X104.681 Y130.932 I-4.192 J3.557 E.03754
G2 X103.694 Y130.455 I-3.549 J6.087 E.03372
G2 X101.908 Y130.319 I-1.258 J4.71 E.05536
G2 X100.75 Y130.705 I1.167 J5.428 E.03758
G1 X100.363 Y130.946 E.01402
G1 X99.772 Y131.436 E.02357
G1 X99.5 Y131.754 E.01289
G1 X99.073 Y132.436 E.0247
G2 X98.724 Y133.605 I5.27 J2.211 E.03756
G2 X98.76 Y134.825 I5.615 J.447 E.03758
G1 X98.888 Y135.288 E.01477
G1 X99.176 Y135.972 E.0228
G1 X99.403 Y136.325 E.0129
G1 X99.932 Y136.93 E.02469
G2 X100.951 Y137.602 I3.771 J-4.607 E.03756
G2 X102.129 Y137.92 I2.177 J-5.722 E.03756
G1 X102.635 Y137.929 E.01555
G1 X103.348 Y137.852 E.02203
G1 X103.752 Y137.737 E.01292
G1 X104.484 Y137.405 E.02471
G2 X105.421 Y136.624 I-3.426 J-5.063 E.03751
G1 X105.722 Y136.208 E.01578
G1 X106.066 Y135.588 E.02181
G2 X106.36 Y134.103 I-4.428 J-1.65 E.04672
; WIPE_START
G1 X106.352 Y134.401 E-.1135
G1 X106.229 Y135.056 E-.25302
G1 X106.066 Y135.588 E-.21147
G1 X105.834 Y136.007 E-.182
; WIPE_END
G1 E-.04 F1800
G1 X100.253 Y132.659 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
G1 F12000
G1 X100.579 Y132.249 E.01609
G1 X101.059 Y131.844 E.0193
G3 X101.798 Y131.511 I1.445 J2.217 E.025
G1 X102.501 Y131.411 E.02183
G1 X102.925 Y131.439 E.01305
G1 X103.494 Y131.596 E.01814
G1 X103.687 Y131.674 E.00641
G1 X104.272 Y132.051 E.02139
G3 X104.817 Y132.687 I-2.019 J2.284 E.02581
G1 X105.105 Y133.32 E.02138
G1 X105.199 Y133.739 E.01319
G1 X105.206 Y134.249 E.01568
G1 X105.12 Y134.839 E.0183
G3 X104.732 Y135.649 I-2.418 J-.661 E.02777
G1 X104.303 Y136.133 E.01987
G3 X103.605 Y136.573 I-1.811 J-2.099 E.02544
G1 X102.937 Y136.768 E.02141
G3 X101.69 Y136.663 I-.389 J-2.835 E.03874
G1 X101.082 Y136.38 E.02063
G1 X100.737 Y136.118 E.01329
G1 X100.3 Y135.618 E.02042
G1 X100.07 Y135.213 E.01431
G1 X99.883 Y134.602 E.01961
G1 X99.833 Y134.099 E.01554
G1 X99.935 Y133.371 E.02259
G3 X100.224 Y132.711 I2.353 J.637 E.02221
G1 X99.922 Y132.478 F36000
G1 F12000
G3 X100.546 Y131.757 I2.607 J1.627 E.02944
G1 X101.103 Y131.389 E.02051
G1 X101.627 Y131.168 E.01747
G1 X102.448 Y131.037 E.02554
G1 X102.974 Y131.064 E.01618
G1 X103.628 Y131.243 E.02086
G1 X103.892 Y131.357 E.00881
G1 X104.476 Y131.735 E.02139
G1 X104.881 Y132.13 E.01737
G1 X105.161 Y132.531 E.01503
G1 X105.449 Y133.164 E.02138
G1 X105.571 Y133.676 E.01617
G1 X105.594 Y134.204 E.01624
G1 X105.493 Y134.893 E.02139
G1 X105.305 Y135.418 E.01713
G1 X105.033 Y135.875 E.01635
G1 X104.57 Y136.4 E.02152
G3 X103.711 Y136.935 I-1.948 J-2.169 E.03125
G1 X103.041 Y137.131 E.02145
G1 X102.516 Y137.178 E.0162
G3 X101.215 Y136.882 I.157 J-3.7 E.04122
G1 X100.684 Y136.556 E.01915
G1 X100.232 Y136.147 E.01871
G3 X99.717 Y135.344 I2.294 J-2.041 E.02943
G1 X99.515 Y134.682 E.02126
G1 X99.457 Y134.123 E.01728
G1 X99.562 Y133.317 E.02498
G3 X99.893 Y132.531 I2.595 J.632 E.02632
; WIPE_START
G1 X99.725 Y132.843 E-.1347
G1 X99.562 Y133.317 E-.19041
G1 X99.457 Y134.123 E-.30893
G1 X99.491 Y134.453 E-.12596
; WIPE_END
G1 E-.04 F1800
G1 X105.979 Y134.033 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; LINE_WIDTH: 0.425349
G1 F12000
G1 X105.876 Y133.267 E.02409
G1 X105.778 Y132.954 E.01021
G1 X105.505 Y132.374 E.01997
G1 X105.184 Y131.906 E.01768
G2 X103.921 Y130.954 I-2.945 J2.59 E.04965
G1 X103.439 Y130.775 E.01603
G1 X102.707 Y130.66 E.02309
G1 X101.96 Y130.71 E.02331
G1 X101.496 Y130.816 E.01486
G1 X100.919 Y131.052 E.01941
G1 X100.605 Y131.238 E.01137
G1 X100.041 Y131.711 E.02295
G2 X99.376 Y132.696 I3.057 J2.784 E.03715
G2 X99.237 Y135.141 I3.412 J1.421 E.07781
G1 X99.518 Y135.794 E.02216
G1 X99.882 Y136.309 E.01963
G1 X100.282 Y136.727 E.01805
G2 X102.18 Y137.539 I2.325 J-2.811 E.06522
G2 X103.816 Y137.296 I.257 J-3.887 E.05194
G1 X104.298 Y137.069 E.01658
G2 X105.716 Y135.429 I-1.927 J-3.1 E.06861
G2 X105.976 Y134.092 I-4.501 J-1.571 E.04257
G1 X112.541 Y114.437 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X114.137 Y114.139 I2.484 J8.899 E.05391
G1 X123.378 Y123.427 E.43463
G2 X123.544 Y124.777 I5.092 J.06 E.04525
G1 X116.349 Y131.973 E.33757
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.45 J2.765 E.02678
G3 X99.258 Y122.288 I-22.942 J-21.966 E.15408
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.885 J12.762 E.05403
; WIPE_START
G1 X111.517 Y134.548 E-.61868
G1 X111.254 Y134.285 E-.14132
; WIPE_END
G1 E-.04 F1800
G1 X117.979 Y130.675 Z5.2 F36000
G1 X132.162 Y123.063 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X132.077 Y122.56 E.01566
G1 X131.774 Y121.718 E.0275
G1 X131.518 Y121.277 E.01565
G1 X131.003 Y120.621 E.02563
G1 X130.622 Y120.282 E.01567
G1 X129.925 Y119.82 E.02569
G1 X129.448 Y119.616 E.01596
G1 X128.654 Y119.4 E.02527
G2 X127.699 Y119.362 I-.653 J4.389 E.02943
G1 X126.875 Y119.495 E.02564
G1 X126.394 Y119.664 E.01567
G1 X125.654 Y120.049 E.02563
G1 X125.251 Y120.36 E.01566
G1 X124.669 Y120.958 E.02563
G1 X124.384 Y121.38 E.01566
G1 X124.019 Y122.131 E.02563
G1 X123.881 Y122.621 E.01567
G1 X123.771 Y123.448 E.02562
G1 X123.794 Y123.96 E.01577
G1 X123.951 Y124.782 E.0257
G1 X124.297 Y125.602 E.02736
G1 X124.575 Y126.029 E.01566
G1 X125.125 Y126.657 E.02563
G1 X125.523 Y126.975 E.01566
G1 X126.242 Y127.398 E.02562
G1 X126.72 Y127.575 E.01566
G1 X127.535 Y127.751 E.02563
G1 X128.044 Y127.769 E.01566
G1 X128.874 Y127.68 E.02563
G1 X129.363 Y127.536 E.01567
G1 X130.122 Y127.192 E.02562
G1 X130.542 Y126.902 E.01567
G1 X131.155 Y126.336 E.02563
G1 X131.464 Y125.927 E.01576
G1 X131.868 Y125.194 E.02571
G1 X132.125 Y124.342 E.02734
G1 X132.183 Y123.836 E.01567
G1 X132.164 Y123.123 E.02192
G1 X131.785 Y123.073 F36000
G1 F12000
G1 X131.664 Y122.526 E.0172
G1 X131.429 Y121.875 E.02129
G2 X130.725 Y120.878 I-4.731 J2.594 E.03757
G1 X130.404 Y120.59 E.01326
G1 X129.743 Y120.152 E.02438
G1 X129.349 Y119.98 E.0132
G1 X128.584 Y119.772 E.02435
G2 X127.759 Y119.734 I-.604 J4.186 E.02543
G1 X126.965 Y119.862 E.02472
G2 X125.855 Y120.369 I1.735 J5.267 E.03758
G2 X124.96 Y121.199 I3.423 J4.586 E.03757
G1 X124.703 Y121.586 E.01427
G1 X124.371 Y122.268 E.02331
G1 X124.255 Y122.671 E.0129
G1 X124.148 Y123.468 E.02469
G2 X124.313 Y124.672 I5.688 J-.166 E.03743
G1 X124.632 Y125.428 E.0252
G1 X124.859 Y125.781 E.01289
G1 X125.388 Y126.386 E.0247
G1 X125.715 Y126.65 E.01289
G1 X126.407 Y127.058 E.0247
G2 X127.585 Y127.376 I2.169 J-5.694 E.03756
G1 X128.091 Y127.384 E.01554
G1 X128.804 Y127.308 E.02202
G1 X129.207 Y127.193 E.0129
G1 X129.939 Y126.861 E.02469
G2 X130.877 Y126.08 I-3.483 J-5.134 E.03756
G2 X131.518 Y125.047 I-4.762 J-3.675 E.03743
G1 X131.755 Y124.262 E.02518
G2 X131.787 Y123.133 I-5.852 J-.731 E.03478
; WIPE_START
G1 X131.8 Y123.618 E-.18442
G1 X131.755 Y124.262 E-.24549
G1 X131.518 Y125.047 E-.31143
G1 X131.495 Y125.09 E-.01866
; WIPE_END
G1 E-.04 F1800
G1 X125.937 Y125.316 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
G1 F12000
G1 X125.642 Y124.886 E.01603
G1 X125.401 Y124.333 E.01853
G1 X125.301 Y123.764 E.01776
G1 X125.313 Y123.19 E.01762
G1 X125.443 Y122.674 E.01635
G1 X125.708 Y122.115 E.01903
G3 X127.253 Y120.967 I2.332 J1.525 E.06038
G1 X127.957 Y120.866 E.02184
G1 X128.38 Y120.894 E.01304
G1 X128.983 Y121.063 E.01921
G1 X129.443 Y121.294 E.01585
G1 X129.904 Y121.677 E.01841
G1 X130.244 Y122.092 E.01647
G1 X130.441 Y122.453 E.01264
G1 X130.597 Y122.923 E.01521
G1 X130.679 Y123.547 E.01935
G1 X130.636 Y124.019 E.01457
G1 X130.454 Y124.633 E.01967
G1 X130.221 Y125.059 E.0149
G1 X129.768 Y125.58 E.02122
G1 X129.389 Y125.858 E.01446
G1 X128.784 Y126.133 E.02041
G1 X128.354 Y126.231 E.01355
G1 X127.691 Y126.236 E.02038
G1 X127.152 Y126.121 E.01692
G1 X126.824 Y125.992 E.01084
G1 X126.239 Y125.614 E.02139
G1 X125.98 Y125.358 E.01119
G1 X125.636 Y125.542 F36000
G1 F12000
G1 X125.311 Y125.066 E.01769
G1 X125.047 Y124.465 E.02018
G3 X125.09 Y122.543 I2.905 J-.897 E.06011
G1 X125.377 Y121.934 E.02069
G3 X126.357 Y120.955 I2.91 J1.931 E.04283
G1 X126.879 Y120.699 E.01787
G1 X127.2 Y120.594 E.01038
G1 X127.904 Y120.493 E.02184
G1 X128.444 Y120.523 E.01663
G1 X129.114 Y120.709 E.02138
G1 X129.61 Y120.955 E.017
G3 X130.966 Y122.843 I-1.693 J2.646 E.07315
G1 X131.055 Y123.52 E.021
G3 X130.506 Y125.306 I-3.036 J.043 E.05835
G1 X130.052 Y125.827 E.02122
G3 X128.651 Y126.554 I-2.136 J-2.402 E.04903
G1 X128.024 Y126.633 E.01941
G3 X126.619 Y126.309 I.056 J-3.449 E.04462
G1 X126.035 Y125.931 E.02139
G1 X125.675 Y125.587 E.01529
; WIPE_START
G1 X126.035 Y125.931 E-.18913
G1 X126.619 Y126.309 E-.26449
G1 X127.017 Y126.474 E-.16374
G1 X127.382 Y126.564 E-.14265
; WIPE_END
G1 E-.04 F1800
G1 X131.404 Y123.083 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; LINE_WIDTH: 0.421324
G1 F12000
G2 X130.193 Y120.908 I-3.596 J.578 E.07835
G1 X129.557 Y120.489 E.0235
M73 P71 R5
G2 X127.982 Y120.108 I-1.654 J3.4 E.05033
G1 X127.146 Y120.218 E.026
G1 X126.613 Y120.398 E.01737
G1 X126.06 Y120.693 E.01931
G2 X125.044 Y121.752 I2.173 J3.1 E.04554
G1 X124.73 Y122.409 E.02244
G2 X124.531 Y123.586 I3.932 J1.271 E.03695
G2 X124.693 Y124.597 I4.291 J-.167 E.03165
G1 X124.974 Y125.25 E.02193
G1 X125.338 Y125.765 E.01942
G1 X125.738 Y126.183 E.01786
G1 X126.415 Y126.625 E.02493
G1 X126.881 Y126.832 E.0157
G2 X128.939 Y126.878 I1.109 J-3.488 E.06435
G2 X130.261 Y126.144 I-1.121 J-3.576 E.04696
G1 X130.796 Y125.559 E.02446
G2 X131.407 Y123.143 I-2.926 J-2.025 E.0785
G1 X145.8 Y135.493 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X144.466 Y134.559 I-9.583 J12.27 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.357 Y119.262 I24.421 J-30.39 E.15054
G2 X152.621 Y118.728 I-2.724 J2.975 E.03022
G1 X139.447 Y131.902 E.61802
G1 X139.666 Y131.992 E.00784
G1 X132.428 Y124.755 E.33954
G2 X132.587 Y123.41 I-4.232 J-1.182 E.04509
G1 X141.856 Y114.141 E.43483
G3 X143.449 Y114.447 I-.8 J8.479 E.0539
; CHANGE_LAYER
; Z_HEIGHT: 5
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X142.991 Y114.302 E-.1826
G1 X141.856 Y114.141 E-.43571
G1 X141.592 Y114.405 E-.14169
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
G1 X126.254 Y119.762
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X126.462 Y119.668 E.00754
G3 X127.761 Y119.387 I1.522 J3.892 E.04429
G1 X128.206 Y119.387 E.01476
G3 X126.056 Y119.852 I-.222 J4.173 E.79714
G1 X126.2 Y119.787 E.00522
; WIPE_START
G1 X126.462 Y119.668 E-.10921
G1 X126.884 Y119.529 E-.16909
G1 X127.319 Y119.435 E-.16902
G1 X127.761 Y119.387 E-.16903
G1 X128.139 Y119.387 E-.14366
; WIPE_END
G1 E-.04 F1800
G1 X127.165 Y121.837 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.19 Y121.824 E.00088
G3 X127.717 Y121.669 I.795 J1.734 E.01692
G1 X127.983 Y121.65 E.00822
G3 X126.951 Y121.955 I.002 J1.908 E.33482
G1 X127.112 Y121.866 E.00565
; WIPE_START
M204 S10000
G1 X127.19 Y121.824 E-.03364
G1 X127.445 Y121.728 E-.10364
G1 X127.717 Y121.669 E-.10543
G1 X127.983 Y121.65 E-.10164
G1 X128.256 Y121.67 E-.10367
G1 X128.522 Y121.728 E-.10355
G1 X128.777 Y121.823 E-.10357
G1 X129.016 Y121.954 E-.10361
G1 X129.019 Y121.956 E-.00126
; WIPE_END
G1 E-.04 F1800
G1 X136.182 Y124.592 Z5.4 F36000
G1 X151.71 Y130.307 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.917 Y130.213 E.00754
G3 X153.217 Y129.932 I1.522 J3.89 E.04429
G1 X153.662 Y129.932 E.01476
G3 X151.512 Y130.397 I-.222 J4.171 E.79681
G1 X151.656 Y130.331 E.00522
; WIPE_START
G1 X151.917 Y130.213 E-.1092
G1 X152.34 Y130.073 E-.16904
G1 X152.775 Y129.979 E-.16907
G1 X153.217 Y129.932 E-.16903
G1 X153.595 Y129.932 E-.14366
; WIPE_END
G1 E-.04 F1800
G1 X152.615 Y132.384 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.646 Y132.368 E.00108
G3 X153.173 Y132.213 I.795 J1.734 E.01692
G1 X153.439 Y132.194 E.00822
G3 X152.407 Y132.499 I.002 J1.908 E.33485
G1 X152.562 Y132.413 E.00544
; WIPE_START
M204 S10000
G1 X152.646 Y132.368 E-.03618
G1 X152.901 Y132.272 E-.10368
G1 X153.173 Y132.213 E-.10541
G1 X153.439 Y132.194 E-.10164
G1 X153.711 Y132.214 E-.10365
G1 X153.978 Y132.272 E-.10352
G1 X154.233 Y132.367 E-.10353
G1 X154.469 Y132.496 E-.10239
; WIPE_END
G1 E-.04 F1800
G1 X146.86 Y133.084 Z5.4 F36000
G1 X99.306 Y136.76 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.108 Y136.507 E.01068
G3 X102.305 Y129.932 I3.419 J-2.402 E.29526
G1 X102.75 Y129.932 E.01476
G3 X99.383 Y136.857 I-.222 J4.173 E.5462
G1 X99.344 Y136.807 E.00209
; WIPE_START
G1 X99.108 Y136.507 E-.14511
G1 X98.872 Y136.13 E-.16901
G1 X98.677 Y135.73 E-.1691
G1 X98.526 Y135.311 E-.16905
G1 X98.459 Y135.036 E-.10773
; WIPE_END
G1 E-.04 F1800
G1 X101.088 Y135.352 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.261 Y132.213 I1.442 J-1.249 E.12565
G1 X102.528 Y132.194 E.00822
G3 X101.128 Y135.396 I.002 J1.908 E.23262
; WIPE_START
M204 S10000
G1 X100.918 Y135.133 E-.12796
G1 X100.79 Y134.899 E-.10164
G1 X100.694 Y134.643 E-.10363
G1 X100.636 Y134.377 E-.10359
G1 X100.617 Y134.105 E-.10356
G1 X100.637 Y133.833 E-.10365
G1 X100.694 Y133.567 E-.10352
G1 X100.706 Y133.536 E-.01245
; WIPE_END
G1 E-.04 F1800
G1 X108.185 Y135.056 Z5.4 F36000
G1 X153.292 Y144.224 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.389 J1.747 E.04339
G3 X88.408 Y132.053 I2.739 J2.131 E.03249
G2 X91.148 Y129.685 I-14.519 J-19.57 E.12023
G2 X93.594 Y126.159 I-11.288 J-10.444 E.14282
G3 X94.42 Y124.708 I12.307 J6.04 E.05543
G3 X95.013 Y124.286 I1.249 J1.127 E.02433
G2 X97.525 Y123.019 I-21.458 J-45.678 E.09334
G2 X101.007 Y120.323 I-8.607 J-14.712 E.14649
G3 X102.746 Y118.696 I16.194 J15.576 E.07903
G3 X103.977 Y118.067 I2.751 J3.858 E.04602
G2 X107.047 Y116.997 I-16.524 J-52.382 E.10787
G2 X110.366 Y115.274 I-7.762 J-19.008 E.12423
G3 X112.192 Y114.202 I10.975 J16.592 E.07025
G3 X113.876 Y113.812 I2.035 J4.968 E.05759
G2 X117.401 Y113.355 I-2.347 J-31.911 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.57 E.10417
G3 X122.451 Y111.606 I9.4 J20.395 E.07347
G3 X123.43 Y111.594 I.513 J2.043 E.03278
G2 X125.813 Y112.005 I37.872 J-212.779 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.297 J24.861 E.07086
G3 X133.229 Y111.549 I.18 J1.871 E.01153
G3 X134.227 Y111.868 I-.724 J3.993 E.03483
G2 X137.511 Y113.104 I11.113 J-24.533 E.11647
G2 X140.702 Y113.674 I5.146 J-19.603 E.10764
G3 X143.068 Y113.962 I-1.514 J22.331 E.07912
G3 X144.643 Y114.679 I-1.437 J5.239 E.05764
G2 X148.015 Y116.604 I17.388 J-26.548 E.12888
G2 X150.332 Y117.514 I10.348 J-22.931 E.0826
G3 X152.669 Y118.351 I-5.674 J19.53 E.08241
G3 X153.962 Y119.349 I-2.504 J4.582 E.0544
G2 X156.837 Y121.957 I22.723 J-22.156 E.12885
G2 X158.902 Y123.348 I15.071 J-20.155 E.08263
G3 X161.003 Y124.671 I-9.765 J17.839 E.0824
G3 X161.85 Y125.632 I-2.917 J3.423 E.04264
G2 X163.68 Y128.324 I49.881 J-31.94 E.108
G2 X166.202 Y131.082 I16.838 J-12.865 E.12414
G3 X167.71 Y132.567 I-14.868 J16.602 E.07024
G3 X168.522 Y134.094 I-4.098 J3.159 E.05761
G1 X168.658 Y134.455 E.0128
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.134 J2.086 E.05195
G3 X88.163 Y131.747 I2.99 J2.225 E.03455
G2 X90.863 Y129.416 I-14.314 J-19.31 E.10972
G2 X93.249 Y125.974 I-11.005 J-10.177 E.12911
G3 X94.112 Y124.464 I12.336 J6.054 E.05348
G3 X94.828 Y123.939 I1.545 J1.357 E.0275
G2 X97.331 Y122.678 I-21.511 J-45.787 E.08611
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.512 Y118.382 I16.279 J15.662 E.07471
G3 X103.844 Y117.697 I2.998 J4.197 E.0462
G2 X106.325 Y116.856 I-155.115 J-461.454 E.0805
G2 X110.161 Y114.94 I-7.083 J-18.974 E.13198
G3 X112.029 Y113.845 I11.127 J16.838 E.06657
G3 X113.833 Y113.423 I2.2 J5.333 E.05719
G2 X117.323 Y112.971 I-2.308 J-31.537 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.355 J20.291 E.06953
G3 X123.486 Y111.206 I.613 J2.411 E.03527
G2 X125.869 Y111.616 I39.508 J-222.255 E.07429
G2 X130.711 Y111.521 I2.13 J-14.776 E.14949
G3 X132.851 Y111.16 I5.314 J24.96 E.06669
G3 X133.273 Y111.159 I.213 J2.326 E.013
G3 X134.376 Y111.505 I-.759 J4.353 E.0356
G2 X137.615 Y112.726 I10.994 J-24.251 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.524 E.07474
G3 X144.845 Y114.343 I-1.517 J5.604 E.05721
G2 X148.18 Y116.248 I17.229 J-26.291 E.11809
G2 X150.456 Y117.142 I10.163 J-22.526 E.07517
G3 X152.846 Y118.001 I-5.728 J19.698 E.07808
G3 X154.232 Y119.065 I-2.674 J4.92 E.05391
G2 X157.076 Y121.646 I22.509 J-21.937 E.11809
G2 X159.105 Y123.012 I14.797 J-19.792 E.07517
G3 X161.075 Y124.23 I-11.65 J21.053 E.0712
G3 X162.172 Y125.408 I-2.968 J3.862 E.04971
G2 X163.993 Y128.088 I49.768 J-31.862 E.09954
G2 X166.471 Y130.796 I16.518 J-12.622 E.11296
G3 X168.013 Y132.318 I-14.981 J16.724 E.06658
G3 X168.887 Y133.952 I-4.412 J3.413 E.0572
G1 X169.137 Y134.615 E.02177
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X155.964 Y136.507 Z5.4 F36000
G1 X157.88 Y133.255 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X157.898 Y134.873 I-6.246 J.879 E.05384
G1 X161.572 Y138.547 E.17235
G1 X156.88 Y141.53 E.18446
G1 X153.952 Y138.602 E.13736
G3 X152.336 Y138.491 I-.488 J-4.692 E.05397
; WIPE_START
G1 X152.958 Y138.607 E-.24029
G1 X153.952 Y138.602 E-.37757
G1 X154.216 Y138.867 E-.14215
; WIPE_END
G1 E-.04 F1800
G1 X157.149 Y132.888 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X154.658 Y130.397 E.10825
G1 X153.963 Y130.236
G1 X157.313 Y133.585 E.14555
G1 X157.342 Y134.148
G1 X153.396 Y130.202 E.17148
G1 X152.898 Y130.238
G1 X157.305 Y134.644 E.19147
G1 X157.216 Y135.089
G1 X155.375 Y133.247 E.08003
G1 X155.547 Y133.953
G1 X157.087 Y135.493 E.06694
G1 X156.924 Y135.863
G1 X155.524 Y134.463 E.06084
G1 X155.406 Y134.878
G1 X156.73 Y136.203 E.05755
G1 X156.509 Y136.515
G1 X155.23 Y135.235 E.0556
G1 X154.997 Y135.536
G1 X156.262 Y136.801 E.05497
G1 X155.989 Y137.061
G1 X154.716 Y135.788 E.05529
G1 X154.389 Y135.994
G1 X155.69 Y137.295 E.05654
G1 X155.364 Y137.503
G1 X154.006 Y136.144 E.05904
G1 X153.544 Y136.216
G1 X155.01 Y137.681 E.06368
G1 X154.622 Y137.828
G1 X152.957 Y136.163 E.07235
; WIPE_START
M204 S10000
G1 X154.372 Y137.577 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.297 Y132.17 Z5.4 F36000
G1 Z5
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X152.453 Y130.325 E.08014
G1 X152.048 Y130.454
G1 X153.592 Y131.997 E.06705
G1 X153.082 Y132.021
G1 X151.679 Y130.618 E.06095
G1 X151.34 Y130.812
G1 X152.666 Y132.138 E.05762
G1 X152.309 Y132.315
G1 X151.028 Y131.034 E.05564
G1 X150.743 Y131.282
G1 X152.009 Y132.547 E.05498
G1 X151.756 Y132.828
G1 X150.484 Y131.556 E.05527
G1 X150.25 Y131.855
G1 X151.55 Y133.155 E.0565
G1 X151.4 Y133.539
G1 X150.043 Y132.182 E.05896
G1 X149.865 Y132.537
G1 X151.328 Y134 E.06359
G1 X151.382 Y134.587
G1 X149.719 Y132.924 E.07225
G1 X149.61 Y133.349
G1 X154.197 Y137.936 E.19933
G1 X153.726 Y137.998
G1 X149.547 Y133.819 E.18161
G1 X149.542 Y134.346
G1 X153.195 Y138 E.15877
G1 X152.577 Y137.915
G1 X149.634 Y134.972 E.1279
G1 X149.919 Y135.791
G1 X151.758 Y137.629 E.0799
; WIPE_START
M204 S10000
G1 X150.344 Y136.215 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.956 Y132.403 Z5.4 F36000
G1 X156.957 Y132.402 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.106563
G1 F15000
G1 X156.873 Y132.29 E.00073
; LINE_WIDTH: 0.143396
G1 X156.788 Y132.179 E.00115
; LINE_WIDTH: 0.180229
G1 X156.704 Y132.067 E.00156
; LINE_WIDTH: 0.216403
G1 X156.573 Y131.911 E.00288
; LINE_WIDTH: 0.251901
G1 X156.442 Y131.755 E.00347
; LINE_WIDTH: 0.28624
G2 X155.865 Y131.17 I-5.7 J5.047 E.0163
; LINE_WIDTH: 0.266142
G1 X155.715 Y131.04 E.00361
; LINE_WIDTH: 0.237125
G1 X155.565 Y130.911 E.00314
; LINE_WIDTH: 0.205264
G1 X155.456 Y130.826 E.00183
; LINE_WIDTH: 0.170598
G1 X155.347 Y130.741 E.00144
; LINE_WIDTH: 0.135933
G1 X155.237 Y130.657 E.00105
; LINE_WIDTH: 0.101719
G1 X155.148 Y130.594 E.00052
; WIPE_START
G1 X155.237 Y130.657 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X150.125 Y131.999 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.0987236
G1 F15000
G3 X150.079 Y132.118 I-.083 J.037 E.00065
; WIPE_START
G1 X150.132 Y132.048 E-.48414
G1 X150.125 Y131.999 E-.27586
; WIPE_END
G1 E-.04 F1800
G1 X151.496 Y134.946 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.19021
G1 F15000
G1 X151.354 Y134.72 E.00321
G1 X151.392 Y134.577 E.00178
; WIPE_START
G1 X151.354 Y134.72 E-.27108
G1 X151.496 Y134.946 E-.48892
; WIPE_END
G1 E-.04 F1800
G1 X155.172 Y137.577 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.101359
G1 F15000
G1 X155.055 Y137.663 E.00069
G1 X154.38 Y137.852 F36000
; LINE_WIDTH: 0.0974134
G1 F15000
G1 X154.22 Y137.935 E.0008
G1 X150.883 Y137.051 F36000
; LINE_WIDTH: 0.0934804
G1 F15000
G3 X150.468 Y136.636 I6.846 J-7.253 E.00242
; WIPE_START
G1 X150.883 Y137.051 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.968 Y136.152 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.190217
G1 F15000
G1 X152.824 Y136.19 E.00178
G1 X152.598 Y136.048 E.00321
; WIPE_START
G1 X152.824 Y136.19 E-.48853
G1 X152.968 Y136.152 E-.27147
; WIPE_END
G1 E-.04 F1800
G1 X155.607 Y134.279 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.0938604
G1 F15000
G3 X155.527 Y134.437 I-2.192 J-1.015 E.00073
; WIPE_START
G1 X155.607 Y134.279 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.437 Y133.185 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.202817
G1 F15000
G1 X155.346 Y133.064 E.00197
; LINE_WIDTH: 0.171511
G1 X155.25 Y132.936 E.00167
; LINE_WIDTH: 0.126783
G1 X154.839 Y132.494 E.00413
G1 X154.602 Y132.289 E.00214
; LINE_WIDTH: 0.172327
G1 X154.481 Y132.198 E.0016
; LINE_WIDTH: 0.202823
G1 X154.359 Y132.107 E.00197
; WIPE_START
G1 X154.481 Y132.198 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X157.144 Y133.15 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.12763
G1 F15000
G1 X157.144 Y132.893 E.00177
G1 X157.249 Y133.233 F36000
; LINE_WIDTH: 0.100077
G1 F15000
G1 X157.094 Y132.943 E.00153
G1 X157.33 Y134.161 F36000
; LINE_WIDTH: 0.10306
G1 F15000
G1 X157.33 Y134.402 E.00118
; WIPE_START
G1 X157.33 Y134.161 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.936 Y127.92 Z5.4 F36000
G1 X143.449 Y114.447 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X141.856 Y114.141 I-2.394 J8.175 E.0539
G1 X132.509 Y123.489 E.4385
G3 X132.362 Y124.689 I-4.763 J.029 E.04022
G1 X139.666 Y131.992 E.34262
G1 X139.447 Y131.902 E.00784
G1 X152.623 Y118.726 E.61812
G3 X153.356 Y119.262 I-2.172 J3.738 E.03019
G2 X156.721 Y122.304 I27.782 J-27.344 E.15055
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.249 J13.204 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X139.099 Y129.143 Z5.4 F36000
G1 X131.701 Y122.372 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X129.173 Y119.843 E.10988
G1 X128.485 Y119.689
G1 X131.859 Y123.063 E.14659
G1 X131.886 Y123.623
G1 X127.921 Y119.658 E.1723
G1 X127.425 Y119.695
G1 X131.847 Y124.117 E.19214
G1 X131.757 Y124.56
M73 P72 R5
G1 X129.93 Y122.734 E.07936
G1 X130.093 Y123.43
G1 X131.626 Y124.963 E.06665
G1 X131.462 Y125.332
G1 X130.065 Y123.935 E.06072
G1 X129.945 Y124.348
G1 X131.267 Y125.671 E.05745
G1 X131.045 Y125.982
G1 X129.767 Y124.704 E.05553
G1 X129.531 Y125.001
G1 X130.796 Y126.266 E.05497
G1 X130.522 Y126.525
G1 X129.249 Y125.253 E.05531
G1 X128.92 Y125.457
G1 X130.222 Y126.759 E.05658
G1 X129.896 Y126.965
G1 X128.534 Y125.604 E.05918
G1 X128.069 Y125.673
G1 X129.54 Y127.143 E.06389
G1 X129.151 Y127.288
G1 X127.477 Y125.613 E.07277
; WIPE_START
M204 S10000
G1 X128.891 Y127.027 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X128.81 Y121.614 Z5.4 F36000
G1 Z5
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X126.981 Y119.785 E.07949
G1 X126.578 Y119.915
G1 X128.115 Y121.452 E.06678
G1 X127.61 Y121.48
G1 X126.21 Y120.08 E.06085
G1 X125.872 Y120.275
G1 X127.196 Y121.599 E.05754
G1 X126.841 Y121.777
G1 X125.562 Y120.498 E.05558
G1 X125.277 Y120.747
G1 X126.543 Y122.013 E.05499
G1 X126.292 Y122.295
G1 X125.019 Y121.022 E.0553
G1 X124.786 Y121.323
G1 X126.087 Y122.624 E.05655
G1 X125.941 Y123.01
G1 X124.58 Y121.65 E.05911
G1 X124.403 Y122.006
G1 X125.871 Y123.474 E.06378
G1 X125.931 Y124.068
G1 X124.259 Y122.395 E.07268
G1 X124.151 Y122.821
G1 X128.725 Y127.394 E.19873
G1 X128.252 Y127.455
G1 X124.09 Y123.293 E.18087
G1 X124.086 Y123.822
G1 X127.719 Y127.455 E.15785
G1 X127.094 Y127.363
G1 X124.184 Y124.453 E.12646
G1 X124.482 Y125.285
G1 X126.262 Y127.064 E.07733
; WIPE_START
M204 S10000
G1 X124.847 Y125.65 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.498 Y121.906 Z5.4 F36000
G1 X131.517 Y121.895 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.0937006
G1 F15000
G1 X131.487 Y121.851 E.00022
; LINE_WIDTH: 0.118723
G1 X131.404 Y121.74 E.00086
; LINE_WIDTH: 0.157162
G1 X131.32 Y121.63 E.00129
; LINE_WIDTH: 0.195601
G1 X131.237 Y121.519 E.00173
; LINE_WIDTH: 0.232313
G1 X131.105 Y121.363 E.00315
; LINE_WIDTH: 0.267326
G1 X130.973 Y121.206 E.00374
; LINE_WIDTH: 0.300667
G2 X130.413 Y120.638 I-5.668 J5.033 E.01677
; LINE_WIDTH: 0.280725
G1 X130.259 Y120.505 E.00394
; LINE_WIDTH: 0.251243
G1 X130.105 Y120.372 E.00345
; LINE_WIDTH: 0.21917
G1 X129.996 Y120.287 E.00199
; LINE_WIDTH: 0.184465
G1 X129.887 Y120.203 E.0016
; LINE_WIDTH: 0.149759
G1 X129.777 Y120.118 E.0012
; LINE_WIDTH: 0.108041
G1 X129.656 Y120.034 E.00078
G1 X127.405 Y119.694 F36000
; LINE_WIDTH: 0.097486
G1 F15000
G1 X127.238 Y119.775 E.00083
; WIPE_START
G1 X127.405 Y119.694 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X130.148 Y123.752 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.10187
G1 F15000
G3 X130.068 Y123.909 I-2.151 J-1.001 E.00085
; WIPE_START
G1 X130.148 Y123.752 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.995 Y122.67 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.19613
G1 F15000
G1 X129.894 Y122.536 E.00209
; LINE_WIDTH: 0.159968
G1 X129.789 Y122.396 E.00167
; LINE_WIDTH: 0.112931
G1 X129.378 Y121.954 E.00344
G1 X129.143 Y121.751 E.00178
; LINE_WIDTH: 0.160678
G1 X129.008 Y121.65 E.00161
; LINE_WIDTH: 0.196121
G1 X128.874 Y121.55 E.00209
; WIPE_START
G1 X129.008 Y121.65 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.696 Y122.633 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.128802
G1 F15000
G1 X131.696 Y122.377 E.00179
; WIPE_START
G1 X131.696 Y122.633 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.703 Y127.039 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.101367
G1 F15000
G1 X129.581 Y127.128 E.00072
G1 X126.672 Y127.257 F36000
; LINE_WIDTH: 0.217252
G1 F15000
G1 X126.323 Y127.003 E.00614
; WIPE_START
G1 X126.672 Y127.257 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X119.757 Y130.487 Z5.4 F36000
G1 X112.9 Y133.689 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X111.517 Y134.548 I7.502 J13.621 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.179 I-19.492 J-25.07 E.15409
G3 X103.362 Y118.717 I2.108 J2.302 E.02677
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X123.61 Y124.711 E.34065
G3 X123.458 Y123.46 I4.745 J-1.213 E.04193
G1 X114.137 Y114.139 E.43726
G2 X112.541 Y114.437 I.887 J9.184 E.05391
; WIPE_START
G1 X112.968 Y114.304 E-.16968
G1 X114.137 Y114.139 E-.44865
G1 X114.4 Y114.403 E-.14166
; WIPE_END
G1 E-.04 F1800
G1 X111.207 Y121.335 Z5.4 F36000
G1 X106.076 Y132.475 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X104.162 Y130.561 E.08317
G1 X103.36 Y130.292
G1 X106.343 Y133.275 E.12962
G1 X106.426 Y133.891
G1 X102.737 Y130.203 E.16029
G1 X102.215 Y130.213
G1 X106.423 Y134.421 E.18286
G1 X106.354 Y134.886
G1 X101.748 Y130.28 E.20014
G1 X101.326 Y130.392
G1 X102.974 Y132.04 E.07162
G1 X102.397 Y131.996
G1 X100.941 Y130.539 E.06329
G1 X100.587 Y130.719
G1 X101.939 Y132.07 E.05874
G1 X101.56 Y132.225
G1 X100.262 Y130.927 E.05644
G1 X99.963 Y131.161
G1 X101.235 Y132.433 E.05527
G1 X100.956 Y132.688
G1 X99.69 Y131.421 E.05504
G1 X99.442 Y131.707
G1 X100.728 Y132.992 E.05584
G1 X100.553 Y133.351
G1 X99.222 Y132.02 E.05784
G1 X99.031 Y132.363
G1 X100.438 Y133.769 E.06113
G1 X100.422 Y134.287
G1 X98.87 Y132.734 E.06745
G1 X98.742 Y133.14
G1 X100.617 Y135.015 E.08146
; WIPE_START
M204 S10000
G1 X99.203 Y133.6 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.593 Y133.658 Z5.4 F36000
G1 Z5
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X106.243 Y135.308 E.07169
G1 X106.095 Y135.693
G1 X104.637 Y134.235 E.06336
G1 X104.562 Y134.694
G1 X105.916 Y136.048 E.05883
G1 X105.708 Y136.373
G1 X104.407 Y135.072 E.05655
G1 X104.199 Y135.398
G1 X105.474 Y136.672 E.05538
G1 X105.211 Y136.943
G1 X103.945 Y135.676 E.05505
G1 X103.64 Y135.905
G1 X104.923 Y137.188 E.05576
G1 X104.609 Y137.407
G1 X103.281 Y136.079 E.05772
G1 X102.863 Y136.194
G1 X104.268 Y137.599 E.06103
G1 X103.896 Y137.76
G1 X102.346 Y136.21 E.06736
G1 X101.618 Y136.016
G1 X103.49 Y137.888 E.08135
G1 X103.044 Y137.975
G1 X98.654 Y133.585 E.19074
G1 X98.623 Y134.087
G1 X102.548 Y138.012 E.17055
G1 X101.971 Y137.968
G1 X98.665 Y134.662 E.14366
G1 X98.833 Y135.364
G1 X101.275 Y137.805 E.10611
; WIPE_START
M204 S10000
G1 X99.86 Y136.391 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.625 Y131.728 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.105658
G1 F15000
G2 X104.922 Y131.024 I-14.443 J13.731 E.00509
; WIPE_START
G1 X105.318 Y131.396 E-.41445
G1 X105.625 Y131.728 E-.34555
; WIPE_END
G1 E-.04 F1800
G1 X103.328 Y132.141 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.176442
G1 F15000
G2 X103.039 Y131.974 I-2.466 J3.932 E.00363
; WIPE_START
G1 X103.328 Y132.141 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X101.557 Y136.077 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.198139
G1 F15000
G1 X101.353 Y135.924 E.00322
; LINE_WIDTH: 0.146579
G1 X100.905 Y135.506 E.00518
G3 X100.699 Y135.268 I3.295 J-3.049 E.00266
; LINE_WIDTH: 0.199765
G1 X100.556 Y135.076 E.00306
; WIPE_START
G1 X100.699 Y135.268 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X100.759 Y137.584 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.105253
G1 F15000
G1 X100.658 Y137.51 E.00063
; LINE_WIDTH: 0.139546
G1 X100.558 Y137.436 E.00098
; LINE_WIDTH: 0.177035
G1 X100.399 Y137.306 E.00225
; LINE_WIDTH: 0.21774
G1 X100.24 Y137.175 E.00293
; LINE_WIDTH: 0.264591
G3 X99.655 Y136.613 I4.987 J-5.769 E.01466
; LINE_WIDTH: 0.245713
G1 X99.391 Y136.315 E.00658
; LINE_WIDTH: 0.198745
G1 X99.262 Y136.153 E.00262
; LINE_WIDTH: 0.152374
G1 X99.133 Y135.992 E.00184
; LINE_WIDTH: 0.108627
G1 X99.047 Y135.871 E.00079
; WIPE_START
G1 X99.133 Y135.992 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.512 Y134.911 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.0898134
G1 F15000
G1 X104.441 Y135.01 E.00047
; WIPE_START
G1 X104.512 Y134.911 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.616 Y133.948 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.159672
G1 F15000
G1 X104.686 Y134.102 E.00161
G1 X104.625 Y134.247 E.00149
G1 X104.658 Y133.593 F36000
; LINE_WIDTH: 0.176467
G1 F15000
G2 X104.491 Y133.305 I-4.157 J2.209 E.00363
; WIPE_START
G1 X104.658 Y133.593 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X106.24 Y132.874 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.150316
G1 F15000
G1 X106.127 Y132.705 E.00178
; LINE_WIDTH: 0.190707
G1 X106.013 Y132.537 E.00245
; WIPE_START
G1 X106.127 Y132.705 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X103.654 Y138.485 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X102.039 Y138.606 I-1.159 J-4.612 E.05397
G1 X99.181 Y141.464 E.13408
G1 X94.573 Y138.397 E.18364
G1 X98.072 Y134.898 E.16414
G3 X98.082 Y133.279 I6.328 J-.769 E.05385
G1 X88.609 Y134.427 F36000
G1 F15476.087
G1 X89.965 Y135.329 E.05401
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.314 J-2.779 E.00842
G1 X122.456 Y130.135 E.63778
G3 X126.34 Y129.657 I5.812 J31.221 E.12989
G1 X127.912 Y128.085 E.07375
G2 X128.081 Y128.084 I.078 J-.789 E.0056
G1 X129.657 Y129.659 E.07393
G3 X133.534 Y130.139 I-1.94 J31.588 E.12968
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.763 J-3.097 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02426
G1 X168.093 Y133.96 E.0568
G2 X167.03 Y132.344 I-4.207 J1.608 E.06467
G3 X164.508 Y129.869 I23.145 J-26.105 E.11727
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.039 J18.156 E.18072
G1 X149.848 Y136.853 E.05249
G3 X148.944 Y133.595 I3.883 J-2.832 E.11462
G1 X127.857 Y112.508 E.98923
G2 X128.138 Y112.507 I.133 J-2.693 E.00933
G1 X107.025 Y133.621 E.99047
G3 X106.131 Y136.837 I-4.794 J.4 E.11311
G1 X107.252 Y137.958 E.05259
G2 X103.68 Y142.062 I21.494 J22.315 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.883 J-14.379 E.18439
G1 X99.795 Y130.502 E.24815
G3 X103.319 Y129.651 I2.738 J3.616 E.12368
G1 X120.021 Y112.948 E.78356
G1 X120.456 Y112.783 E.01543
G1 X126.852 Y119.179 E.30008
G3 X129.137 Y119.184 I1.133 J4.51 E.07658
G1 X135.531 Y112.79 E.29994
G1 X135.991 Y112.965 E.01632
G1 X152.67 Y129.645 E.78247
G3 X156.187 Y130.514 I.756 J4.494 E.12359
G1 X161.265 Y125.436 E.2382
G2 X160.005 Y124.422 I-3.928 J3.589 E.05386
; CHANGE_LAYER
; Z_HEIGHT: 5.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X160.78 Y124.939 E-.35397
G1 X161.265 Y125.436 E-.26401
G1 X161.001 Y125.7 E-.14202
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
G1 X126.292 Y120.268
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X126.635 Y120.112 E.01252
M73 P73 R5
G3 X127.786 Y119.863 I1.348 J3.448 E.03924
G1 X128.181 Y119.863 E.01307
G3 X126.238 Y120.295 I-.197 J3.697 E.7048
G1 X126.53 Y120.59 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.778 Y120.478 E.00836
G3 X127.807 Y120.255 I1.205 J3.082 E.03249
G1 X128.16 Y120.255 E.01083
G3 X126.457 Y120.623 I-.176 J3.305 E.58485
G1 X126.476 Y120.615 E.00062
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.12623
G1 X127.113 Y120.367 E-.1339
G1 X127.457 Y120.293 E-.1339
G1 X127.807 Y120.255 E-.13387
G1 X128.16 Y120.255 E-.13391
G1 X128.417 Y120.283 E-.09819
; WIPE_END
G1 E-.04 F1800
G1 X135.373 Y123.422 Z5.6 F36000
G1 X151.747 Y130.812 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.091 Y130.656 E.01251
G3 X153.242 Y130.407 I1.348 J3.447 E.03924
G1 X153.636 Y130.407 E.01307
G3 X151.694 Y130.839 I-.197 J3.696 E.70454
G1 X151.979 Y131.137 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.00859
G3 X153.263 Y130.799 I1.205 J3.081 E.03249
G1 X153.615 Y130.799 E.01083
G3 X151.913 Y131.168 I-.176 J3.304 E.58458
G1 X151.925 Y131.162 E.00039
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.12902
G1 X152.568 Y130.911 E-.13387
G1 X152.913 Y130.837 E-.13393
G1 X153.263 Y130.799 E-.13387
G1 X153.615 Y130.799 E-.13391
G1 X153.865 Y130.826 E-.09541
; WIPE_END
G1 E-.04 F1800
G1 X146.275 Y131.626 Z5.6 F36000
G1 X99.73 Y136.53 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.498 Y136.233 E.01251
G3 X102.331 Y130.407 I3.03 J-2.128 E.2616
G1 X102.725 Y130.407 E.01308
G3 X99.77 Y136.575 I-.197 J3.697 E.48251
G1 X100.014 Y136.257 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.819 Y136.007 E.00974
G3 X102.351 Y130.799 I2.708 J-1.903 E.21663
G1 X102.704 Y130.799 E.01083
G3 X100.053 Y136.303 I-.176 J3.305 E.39999
; WIPE_START
M204 S10000
G1 X99.819 Y136.007 E-.1432
G1 X99.632 Y135.709 E-.13387
G1 X99.478 Y135.392 E-.13395
G1 X99.358 Y135.061 E-.13387
G1 X99.275 Y134.718 E-.13389
G1 X99.246 Y134.506 E-.08123
; WIPE_END
G1 E-.04 F1800
G1 X106.758 Y135.857 Z5.6 F36000
G1 X153.292 Y144.224 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.391 J1.748 E.04338
G3 X88.408 Y132.053 I2.735 J2.127 E.03249
G2 X91.148 Y129.685 I-14.52 J-19.572 E.12023
G2 X93.594 Y126.159 I-11.289 J-10.444 E.14281
G3 X94.42 Y124.708 I12.315 J6.044 E.05543
G3 X95.013 Y124.286 I1.249 J1.126 E.02433
G2 X97.525 Y123.019 I-21.464 J-45.69 E.09335
G2 X101.007 Y120.323 I-8.607 J-14.712 E.14649
G3 X102.746 Y118.696 I16.198 J15.58 E.07902
G3 X103.976 Y118.067 I2.75 J3.856 E.04601
G2 X107.047 Y116.997 I-16.533 J-52.407 E.10789
G2 X110.366 Y115.274 I-7.762 J-19.009 E.12423
G3 X112.192 Y114.201 I10.962 J16.57 E.07026
G3 X113.876 Y113.812 I2.035 J4.969 E.05758
G2 X117.401 Y113.355 I-2.348 J-31.917 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10416
G3 X122.451 Y111.606 I9.407 J20.412 E.07348
G3 X123.43 Y111.594 I.513 J2.043 E.03278
G2 X125.813 Y112.005 I37.911 J-213.004 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.297 J24.861 E.07086
G3 X133.23 Y111.549 I.18 J1.865 E.01154
G3 X134.227 Y111.868 I-.724 J3.993 E.03482
G2 X137.511 Y113.104 I11.113 J-24.533 E.11647
G2 X140.702 Y113.674 I5.146 J-19.603 E.10764
G3 X143.068 Y113.961 I-1.514 J22.33 E.07911
G3 X144.643 Y114.679 I-1.436 J5.238 E.05764
G2 X148.015 Y116.604 I17.389 J-26.549 E.12887
G2 X151.657 Y117.949 I12.733 J-28.869 E.12888
G3 X153.297 Y118.757 I-1.459 J5.033 E.06096
G3 X154.769 Y120.137 I-13.756 J16.14 E.06697
G2 X158.902 Y123.348 I14.663 J-14.612 E.17409
G3 X161.003 Y124.671 I-9.762 J17.832 E.08242
G3 X161.85 Y125.632 I-2.918 J3.423 E.04262
G2 X163.68 Y128.324 I49.886 J-31.943 E.10799
G2 X166.202 Y131.082 I16.837 J-12.865 E.12415
G3 X167.71 Y132.567 I-14.87 J16.604 E.07023
G3 X168.522 Y134.093 I-4.095 J3.157 E.05759
G1 X168.658 Y134.455 E.01283
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.137 J2.086 E.05195
G3 X88.162 Y131.747 I2.987 J2.221 E.03455
G2 X90.863 Y129.416 I-14.314 J-19.312 E.10973
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.338 J6.055 E.05347
G3 X94.828 Y123.94 I1.546 J1.358 E.0275
G2 X97.331 Y122.678 I-21.51 J-45.787 E.08612
G2 X100.735 Y120.04 I-8.413 J-14.372 E.1327
G3 X102.512 Y118.382 I16.281 J15.665 E.07473
G3 X103.844 Y117.698 I2.997 J4.196 E.04618
G2 X106.325 Y116.856 I-155.616 J-462.925 E.08051
G2 X110.161 Y114.94 I-7.082 J-18.973 E.13198
G3 X112.029 Y113.845 I11.116 J16.82 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.543 E.10817
G2 X120.249 Y112.069 I-3.378 J-16.161 E.09423
G3 X122.349 Y111.227 I9.364 J20.311 E.06953
G3 X123.486 Y111.206 I.614 J2.41 E.03528
G2 X125.869 Y111.616 I39.571 J-222.62 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.314 J24.961 E.06668
G3 X133.273 Y111.159 I.213 J2.32 E.01301
G3 X134.376 Y111.505 I-.759 J4.354 E.03559
G2 X137.615 Y112.726 I10.994 J-24.251 E.10646
G2 X140.743 Y113.284 I5.04 J-19.215 E.09773
G3 X143.156 Y113.579 I-1.533 J22.523 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.0572
G2 X148.18 Y116.248 I17.23 J-26.292 E.11809
G2 X151.783 Y117.578 I12.596 J-28.588 E.11808
G3 X153.54 Y118.449 I-1.579 J5.392 E.06056
G3 X155.042 Y119.856 I-13.961 J16.407 E.06326
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.23 I-11.65 J21.053 E.07121
G3 X162.172 Y125.408 I-2.97 J3.864 E.0497
G2 X163.993 Y128.088 I49.787 J-31.874 E.09954
G2 X166.471 Y130.796 I16.518 J-12.622 E.11296
G3 X168.012 Y132.318 I-14.984 J16.727 E.06658
G3 X168.887 Y133.951 I-4.41 J3.412 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26194
; WIPE_END
G1 E-.04 F1800
G1 X152.403 Y138.591 Z5.6 F36000
G1 Z5.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.455 Y138.605 E.00177
G2 X154.021 Y138.671 I.99 J-4.861 E.05221
G1 X156.88 Y141.53 E.13412
G1 X161.572 Y138.547 E.18446
G1 X157.969 Y134.944 E.16904
G2 X157.974 Y133.324 I-4.322 J-.824 E.05403
G1 X157.582 Y133.996 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.534188
G1 F12000
G1 X157.464 Y133.12 E.03537
G1 X157.337 Y132.671 E.01868
G1 X156.973 Y131.925 E.03325
G1 X156.425 Y131.233 E.03534
G1 X155.757 Y130.658 E.03526
G1 X154.976 Y130.247 E.03535
G1 X154.11 Y130.018 E.03585
G1 X153.634 Y129.956 E.01922
G1 X152.805 Y130.011 E.03325
G1 X151.951 Y130.227 E.03526
G1 X151.166 Y130.63 E.03535
G1 X150.48 Y131.207 E.03585
G1 X150.177 Y131.551 E.01837
G1 X149.712 Y132.294 E.03509
M73 P73 R4
G1 X149.524 Y132.721 E.01867
G1 X149.327 Y133.528 E.03326
G1 X149.308 Y134.41 E.03534
G1 X149.455 Y135.279 E.03526
G1 X149.794 Y136.094 E.03535
G1 X150.305 Y136.814 E.03534
G1 X150.941 Y137.423 E.03525
G1 X151.699 Y137.876 E.03535
G1 X152.539 Y138.148 E.03534
G1 X153.413 Y138.258 E.03526
G1 X154.291 Y138.169 E.03535
G1 X155.128 Y137.887 E.03534
G1 X155.905 Y137.446 E.03577
G1 X156.547 Y136.859 E.03484
G1 X157.051 Y136.134 E.03533
G1 X157.408 Y135.329 E.03526
G1 X157.577 Y134.462 E.03535
G1 X157.581 Y134.056 E.01627
G1 X160.005 Y124.422 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X161.265 Y125.436 I-2.669 J4.605 E.05386
G1 X156.244 Y130.457 E.23554
G2 X152.604 Y129.578 I-2.812 J3.67 E.12791
G1 X135.991 Y112.965 E.77934
G1 X135.531 Y112.79 E.01632
G1 X129.203 Y119.118 E.29685
G2 X126.786 Y119.112 I-1.22 J4.634 E.08106
G1 X120.456 Y112.783 E.29695
G1 X120.021 Y112.948 E.01543
G1 X103.385 Y129.584 E.78042
G2 X99.739 Y130.445 I-.856 J4.526 E.12801
G1 X94.506 Y125.212 E.24549
G3 X91.467 Y129.849 I-19.926 J-9.745 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.067 J18.212 E.18071
G1 X106.187 Y136.894 E.04994
G2 X107.099 Y133.547 I-3.609 J-2.78 E.11805
G1 X128.138 Y112.507 E.98701
G3 X127.857 Y112.508 I-.148 J-2.692 E.00933
G1 X148.87 Y133.521 E.98577
G2 X149.792 Y136.909 I4.523 J.59 E.11957
G1 X148.729 Y137.972 E.04984
G3 X152.298 Y142.079 I-21.469 J22.262 E.18072
G1 X164.508 Y129.869 E.57279
G3 X167.553 Y132.932 I-260.946 J262.481 E.14327
G3 X168.093 Y133.96 I-8.444 J5.084 E.03855
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.5 J-3.228 E.00975
G1 X133.534 Y130.139 E.63753
G2 X129.657 Y129.659 I-5.817 J31.108 E.12968
G1 X128.156 Y128.159 E.07039
G3 X127.837 Y128.16 I-.167 J-1.603 E.01061
G1 X126.34 Y129.657 E.07021
G2 X122.456 Y130.135 I1.928 J31.696 E.12989
G1 X108.861 Y116.54 E.63779
G3 X108.636 Y116.657 I-1.539 J-2.661 E.00843
G1 X89.965 Y135.329 E.87592
G1 X88.609 Y134.427 E.05401
G1 X97.988 Y133.348 F36000
G1 F15476.087
G2 X98.002 Y134.967 I4.829 J.769 E.05397
G1 X94.573 Y138.397 E.16088
G1 X99.181 Y141.464 E.18364
G1 X101.97 Y138.675 E.13084
G1 X102.027 Y138.684 E.00191
G2 X103.587 Y138.585 I.468 J-4.948 E.05207
; WIPE_START
G1 X103.006 Y138.687 E-.22402
G1 X102.027 Y138.684 E-.37216
G1 X101.97 Y138.675 E-.02187
G1 X101.706 Y138.939 E-.14195
; WIPE_END
G1 E-.04 F1800
G1 X106.67 Y133.996 Z5.6 F36000
G1 Z5.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53285
G1 F12000
G1 X106.553 Y133.12 E.03526
G1 X106.425 Y132.671 E.01863
G1 X106.062 Y131.925 E.03315
G1 X105.513 Y131.233 E.03525
G1 X104.846 Y130.658 E.03516
G1 X104.064 Y130.247 E.03525
G1 X103.199 Y130.018 E.03575
G1 X102.722 Y129.957 E.01916
G1 X101.893 Y130.001 E.03316
G1 X101.031 Y130.243 E.03575
G1 X100.253 Y130.629 E.03466
G1 X99.571 Y131.189 E.03524
G1 X99.029 Y131.886 E.03525
G1 X98.63 Y132.671 E.03516
G1 X98.415 Y133.528 E.03526
G1 X98.397 Y134.41 E.03524
G1 X98.543 Y135.279 E.03516
G1 X98.882 Y136.094 E.03525
G1 X99.394 Y136.814 E.03524
G1 X100.029 Y137.423 E.03516
G1 X100.788 Y137.876 E.03526
G1 X101.627 Y138.148 E.03524
G1 X102.501 Y138.258 E.03516
G1 X103.38 Y138.169 E.03525
G1 X104.216 Y137.887 E.03524
G1 X104.993 Y137.446 E.03567
G1 X105.636 Y136.859 E.03474
G1 X106.139 Y136.134 E.03524
G1 X106.496 Y135.329 E.03516
G1 X106.665 Y134.462 E.03525
G1 X106.669 Y134.056 E.01624
G1 X112.541 Y114.437 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X114.137 Y114.139 I2.484 J8.898 E.05391
G1 X123.378 Y123.427 E.43463
G2 X123.544 Y124.777 I5.092 J.06 E.04525
G1 X116.349 Y131.973 E.33757
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.449 J2.764 E.02677
G3 X99.258 Y122.288 I-22.944 J-21.968 E.15409
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.885 J12.762 E.05403
; WIPE_START
G1 X111.517 Y134.548 E-.61868
G1 X111.254 Y134.285 E-.14132
; WIPE_END
G1 E-.04 F1800
G1 X117.968 Y130.653 Z5.6 F36000
G1 X132.101 Y123.008 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.532888
G1 F12000
G1 X131.889 Y122.179 E.03418
G1 X131.518 Y121.38 E.03515
G1 X130.977 Y120.682 E.03526
G1 X130.294 Y120.123 E.03524
G1 X129.508 Y119.698 E.03567
G1 X128.67 Y119.465 E.03475
G1 X128.178 Y119.412 E.01974
G1 X127.349 Y119.467 E.03316
G1 X126.496 Y119.683 E.03516
G1 X125.71 Y120.086 E.03526
G1 X125.033 Y120.653 E.03524
G1 X124.476 Y121.335 E.03517
G1 X124.086 Y122.127 E.03525
G1 X123.881 Y122.986 E.03525
G1 X123.841 Y123.867 E.03522
G1 X124.001 Y124.734 E.0352
G1 X124.338 Y125.55 E.03524
G1 X124.849 Y126.269 E.03524
G1 X125.485 Y126.879 E.03517
G1 X126.244 Y127.331 E.03525
G1 X127.083 Y127.604 E.03525
G1 X127.957 Y127.714 E.03517
G1 X128.835 Y127.625 E.03525
G1 X129.672 Y127.343 E.03525
G1 X130.439 Y126.91 E.03516
G1 X131.091 Y126.315 E.03526
G1 X131.601 Y125.578 E.03576
G1 X131.803 Y125.167 E.01831
G1 X132.056 Y124.327 E.035
G1 X132.125 Y123.866 E.01863
G1 X132.104 Y123.068 E.03185
G1 X145.8 Y135.493 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X144.466 Y134.559 I-9.583 J12.27 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.357 Y119.263 I24.428 J-30.397 E.15053
G2 X152.621 Y118.728 I-2.723 J2.973 E.03023
G1 X139.447 Y131.902 E.61802
G1 X139.666 Y131.992 E.00784
G1 X132.428 Y124.755 E.33954
G2 X132.587 Y123.41 I-4.232 J-1.182 E.04509
G1 X141.856 Y114.141 E.43482
G3 X143.449 Y114.447 I-.8 J8.482 E.0539
; CHANGE_LAYER
; Z_HEIGHT: 5.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X142.991 Y114.302 E-.18261
G1 X141.856 Y114.141 E-.4357
G1 X141.592 Y114.405 E-.14169
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
G1 X126.292 Y120.268
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X126.635 Y120.112 E.01251
G3 X127.786 Y119.863 I1.348 J3.447 E.03924
G1 X128.181 Y119.863 E.01307
G3 X126.238 Y120.295 I-.197 J3.696 E.70459
G1 X126.525 Y120.593 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.778 Y120.478 E.00854
G3 X127.807 Y120.255 I1.205 J3.082 E.0325
G1 X128.16 Y120.255 E.01083
G3 X126.457 Y120.623 I-.176 J3.304 E.5847
G1 X126.47 Y120.617 E.00045
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.12836
G1 X127.112 Y120.367 E-.13389
G1 X127.457 Y120.293 E-.1339
G1 X127.807 Y120.255 E-.13388
G1 X128.16 Y120.255 E-.13392
G1 X128.411 Y120.282 E-.09605
; WIPE_END
G1 E-.04 F1800
G1 X121.77 Y124.044 Z5.8 F36000
G1 X99.73 Y136.53 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.501 Y136.231 E.0125
G3 X102.331 Y130.407 I3.027 J-2.129 E.2615
G1 X102.725 Y130.407 E.01308
G3 X99.772 Y136.572 I-.197 J3.695 E.48217
G1 X100.016 Y136.259 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.822 Y136.005 E.00982
G3 X102.351 Y130.799 I2.706 J-1.903 E.21654
G1 X102.704 Y130.799 E.01083
G3 X100.058 Y136.303 I-.176 J3.303 E.3996
; WIPE_START
M204 S10000
G1 X99.822 Y136.005 E-.14418
G1 X99.632 Y135.709 E-.13381
G1 X99.478 Y135.392 E-.13395
G1 X99.358 Y135.061 E-.13385
G1 X99.275 Y134.718 E-.13391
G1 X99.247 Y134.509 E-.08031
; WIPE_END
G1 E-.04 F1800
G1 X106.86 Y133.975 Z5.8 F36000
G1 X151.713 Y130.83 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.732 Y130.819 E.00072
G3 X153.242 Y130.407 I1.707 J3.283 E.05232
G3 X153.964 Y130.442 I.197 J3.393 E.024
G1 X154.028 Y130.449 E.00216
G3 X151.339 Y131.056 I-.589 J3.653 E.67751
G1 X151.662 Y130.861 E.01251
G1 X151.974 Y131.14 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.00878
G3 X153.263 Y130.799 I1.206 J3.08 E.03249
G3 X153.922 Y130.832 I.176 J3.099 E.02031
G1 X153.966 Y130.837 E.00136
G3 X151.913 Y131.168 I-.526 J3.266 E.57366
G1 X151.919 Y131.165 E.0002
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.13135
G1 X152.568 Y130.911 E-.13389
G1 X152.913 Y130.837 E-.1339
G1 X153.263 Y130.799 E-.13389
G1 X153.615 Y130.799 E-.13391
G1 X153.859 Y130.825 E-.09306
; WIPE_END
G1 E-.04 F1800
G1 X153.536 Y138.451 Z5.8 F36000
G1 X153.292 Y144.224 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.39 J1.747 E.04338
G3 X88.408 Y132.053 I2.736 J2.128 E.03249
G2 X91.148 Y129.685 I-14.52 J-19.573 E.12022
G2 X93.594 Y126.159 I-11.288 J-10.444 E.14282
M73 P74 R4
G3 X94.42 Y124.708 I12.309 J6.041 E.05543
G3 X95.012 Y124.286 I1.249 J1.126 E.02432
G2 X97.525 Y123.019 I-21.479 J-45.718 E.09336
G2 X101.007 Y120.323 I-8.608 J-14.713 E.14649
G3 X102.746 Y118.696 I16.203 J15.585 E.07902
G3 X104.031 Y118.047 I2.777 J3.9 E.04794
G2 X107.35 Y116.872 I-13.883 J-44.47 E.11682
G2 X110.367 Y115.274 I-8.549 J-19.786 E.11337
G3 X112.192 Y114.201 I10.965 J16.575 E.07024
G3 X113.876 Y113.812 I2.035 J4.969 E.05759
G2 X117.401 Y113.355 I-2.348 J-31.916 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10414
G3 X122.451 Y111.606 I9.407 J20.411 E.07349
G3 X123.43 Y111.594 I.513 J2.042 E.03277
G2 X125.813 Y112.005 I37.96 J-213.29 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.297 J24.864 E.07087
G3 X133.23 Y111.549 I.18 J1.861 E.01153
G3 X134.117 Y111.823 I-.662 J3.722 E.03086
G2 X137.511 Y113.104 I11.671 J-25.783 E.12043
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.068 Y113.961 I-1.514 J22.331 E.07913
G3 X144.643 Y114.679 I-1.436 J5.238 E.05764
G2 X148.014 Y116.603 I17.393 J-26.555 E.12885
G2 X151.657 Y117.949 I12.733 J-28.868 E.12889
G3 X153.297 Y118.757 I-1.46 J5.034 E.06096
G3 X154.769 Y120.137 I-13.76 J16.145 E.06697
G2 X158.902 Y123.348 I14.664 J-14.614 E.17409
G3 X160.841 Y124.544 I-11.509 J20.817 E.0756
G3 X161.85 Y125.632 I-2.665 J3.484 E.04944
G2 X163.68 Y128.324 I49.865 J-31.929 E.10799
G2 X166.202 Y131.082 I16.836 J-12.863 E.12414
G3 X167.71 Y132.568 I-14.859 J16.593 E.07025
G3 X168.522 Y134.094 I-4.097 J3.158 E.05761
G1 X168.658 Y134.455 E.0128
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.135 J2.086 E.05195
G3 X88.163 Y131.747 I2.988 J2.222 E.03456
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10971
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.337 J6.054 E.05348
G3 X94.828 Y123.94 I1.545 J1.357 E.02748
G2 X97.331 Y122.678 I-21.525 J-45.816 E.08613
G2 X100.735 Y120.04 I-8.415 J-14.375 E.13271
G3 X102.512 Y118.382 I16.289 J15.673 E.07471
G3 X104.372 Y117.515 I3.499 J5.08 E.06336
G2 X108.367 Y115.965 I-7.381 J-24.94 E.13183
G2 X111.121 Y114.343 I-15.975 J-30.269 E.09824
G3 X112.803 Y113.582 I3.178 J4.787 E.05697
G3 X115.224 Y113.284 I3.957 J22.159 E.075
G2 X120.249 Y112.069 I-1.408 J-16.824 E.15947
G3 X122.349 Y111.227 I9.363 J20.309 E.06954
G3 X123.486 Y111.206 I.613 J2.41 E.03526
G2 X125.869 Y111.616 I39.584 J-222.697 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.315 J24.966 E.06668
G3 X133.273 Y111.159 I.213 J2.317 E.013
G3 X134.264 Y111.459 I-.699 J4.093 E.03189
G2 X137.615 Y112.726 I11.558 J-25.513 E.11016
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.524 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.0572
G2 X148.18 Y116.248 I17.23 J-26.292 E.11809
G2 X151.783 Y117.578 I12.596 J-28.588 E.11808
G3 X153.54 Y118.449 I-1.58 J5.392 E.06056
G3 X155.042 Y119.856 I-13.966 J16.412 E.06326
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.23 I-11.651 J21.056 E.0712
G3 X162.172 Y125.408 I-2.912 J3.809 E.04971
G2 X163.993 Y128.088 I49.773 J-31.865 E.09954
G2 X166.471 Y130.796 I16.518 J-12.622 E.11296
G3 X168.013 Y132.318 I-14.977 J16.72 E.06658
G3 X168.887 Y133.951 I-4.411 J3.413 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26194
; WIPE_END
G1 E-.04 F1800
G1 X156.043 Y136.554 Z5.8 F36000
G1 X157.593 Y133.995 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.532091
G1 F12000
G1 X157.479 Y133.145 E.0342
G1 X157.175 Y132.316 E.03519
G1 X156.722 Y131.561 E.03511
G1 X156.11 Y130.925 E.0352
G1 X155.372 Y130.441 E.03519
G1 X154.556 Y130.104 E.03517
G1 X153.686 Y129.96 E.03513
G1 X152.805 Y130.011 E.03518
G1 X151.951 Y130.227 E.03511
G1 X151.148 Y130.653 E.03625
G1 X150.769 Y130.925 E.0186
G1 X150.189 Y131.521 E.03313
G1 X149.716 Y132.265 E.03516
G1 X149.421 Y133.097 E.03518
G1 X149.288 Y133.968 E.03511
G1 X149.354 Y134.849 E.0352
G1 X149.613 Y135.692 E.03519
G1 X150.025 Y136.471 E.03511
G1 X150.603 Y137.138 E.0352
G1 X151.315 Y137.661 E.03519
G1 X152.11 Y138.04 E.0351
G1 X152.972 Y138.231 E.0352
G1 X153.854 Y138.226 E.03518
G1 X154.719 Y138.056 E.03511
G1 X155.526 Y137.695 E.03525
G1 X156.231 Y137.166 E.03513
G1 X156.823 Y136.514 E.03512
G1 X157.255 Y135.744 E.03519
G1 X157.505 Y134.897 E.03519
G1 X157.588 Y134.055 E.03373
G1 X157.974 Y133.324 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X157.969 Y134.944 I-4.327 J.796 E.05403
G1 X161.572 Y138.547 E.16904
G1 X156.88 Y141.53 E.18446
G1 X154.021 Y138.671 E.13412
G1 X153.94 Y138.684 E.00272
G3 X152.403 Y138.591 I-.468 J-4.992 E.05127
G1 X132.09 Y123.01 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.532612
G1 F12000
G1 X132.011 Y122.55 E.01862
G1 X131.729 Y121.768 E.03314
G1 X131.257 Y121.023 E.03522
G1 X130.655 Y120.38 E.03515
G1 X129.921 Y119.888 E.03523
G1 X129.098 Y119.571 E.03523
G1 X128.231 Y119.415 E.03514
G1 X127.349 Y119.467 E.03523
G1 X126.496 Y119.683 E.03514
G1 X125.71 Y120.086 E.03524
G1 X125.033 Y120.653 E.03522
G1 X124.476 Y121.335 E.03515
G1 X124.086 Y122.127 E.03523
G1 X123.881 Y122.986 E.03523
G1 X123.841 Y123.866 E.03514
G1 X124.001 Y124.734 E.03523
G1 X124.338 Y125.55 E.03523
G1 X124.849 Y126.269 E.03522
G1 X125.485 Y126.879 E.03515
G1 X126.244 Y127.331 E.03523
G1 X127.083 Y127.604 E.03523
G1 X127.957 Y127.714 E.03515
G1 X128.836 Y127.625 E.03523
G1 X129.672 Y127.343 E.03523
G1 X130.439 Y126.91 E.03514
G1 X131.103 Y126.289 E.03629
G1 X131.397 Y125.926 E.01862
G1 X131.799 Y125.199 E.03316
G1 X132.059 Y124.356 E.03521
G1 X132.125 Y123.476 E.03523
G1 X132.095 Y123.069 E.01625
G1 X143.449 Y114.447 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X141.856 Y114.141 I-2.394 J8.178 E.0539
G1 X132.588 Y123.427 E.43519
G3 X132.428 Y124.755 I-5.009 J.068 E.04449
G1 X139.666 Y131.992 E.33954
G1 X139.447 Y131.902 E.00784
G1 X152.621 Y118.728 E.61802
G3 X153.356 Y119.262 I-1.989 J3.51 E.03021
G2 X156.721 Y122.304 I27.788 J-27.35 E.15055
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.249 J13.204 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X137.098 Y134.15 Z5.8 F36000
G1 X112.9 Y133.689 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.502 J13.621 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.18 I-19.502 J-25.081 E.15409
G3 X103.362 Y118.717 I2.109 J2.303 E.02677
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X123.544 Y124.777 E.33757
G3 X123.382 Y123.385 I4.19 J-1.195 E.04671
G1 X114.137 Y114.139 E.43371
G2 X112.541 Y114.437 I.888 J9.189 E.05391
G1 X106.681 Y133.995 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.531026
G1 F12000
G1 X106.568 Y133.145 E.03412
G1 X106.264 Y132.316 E.03511
G1 X105.811 Y131.561 E.03503
G1 X105.197 Y130.924 E.03519
G1 X104.46 Y130.441 E.03505
G1 X103.646 Y130.105 E.03503
G1 X102.775 Y129.96 E.03512
G1 X101.893 Y130.001 E.03511
G1 X101.043 Y130.238 E.03512
G1 X100.254 Y130.629 E.03503
G1 X99.571 Y131.189 E.03511
G1 X99.029 Y131.886 E.03512
G1 X98.629 Y132.671 E.03503
G1 X98.415 Y133.528 E.03512
G1 X98.397 Y134.41 E.03511
G1 X98.543 Y135.279 E.03503
G1 X98.882 Y136.094 E.03512
G1 X99.394 Y136.814 E.03511
G1 X100.029 Y137.423 E.03503
G1 X100.788 Y137.876 E.03513
G1 X101.627 Y138.148 E.03511
G1 X102.501 Y138.258 E.03503
G1 X103.38 Y138.169 E.03512
G1 X104.216 Y137.887 E.03511
G1 X104.66 Y137.669 E.01968
G1 X105.319 Y137.166 E.03297
G1 X105.911 Y136.514 E.03504
G1 X106.343 Y135.744 E.03512
G1 X106.593 Y134.897 E.03511
G1 X106.677 Y134.055 E.03366
; WIPE_START
G1 X106.593 Y134.897 E-.32159
G1 X106.343 Y135.744 E-.33545
G1 X106.211 Y135.98 E-.10296
; WIPE_END
G1 E-.04 F1800
G1 X98.942 Y133.653 Z5.8 F36000
G1 X97.988 Y133.348 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X98.002 Y134.967 I4.829 J.769 E.05397
G1 X94.573 Y138.397 E.16088
G1 X89.965 Y135.329 E.18364
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.314 J-2.779 E.00842
G1 X122.456 Y130.135 E.63778
G3 X126.34 Y129.657 I5.812 J31.218 E.12989
G1 X127.837 Y128.16 E.07021
G2 X128.156 Y128.159 I.153 J-1.604 E.01061
G1 X129.657 Y129.659 E.07039
G3 X133.534 Y130.139 I-1.94 J31.587 E.12968
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.763 J-3.098 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02426
G1 X168.093 Y133.96 E.0568
G2 X167.031 Y132.345 I-4.207 J1.608 E.06463
G3 X164.508 Y129.869 I23.146 J-26.107 E.1173
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.038 J18.155 E.18072
G1 X149.792 Y136.909 E.04984
G3 X148.87 Y133.521 I3.602 J-2.799 E.11957
G1 X127.857 Y112.508 E.98577
G2 X128.138 Y112.507 I.133 J-2.693 E.00933
G1 X107.099 Y133.547 E.98701
G3 X106.187 Y136.894 I-4.52 J.567 E.11805
G1 X107.252 Y137.958 E.04994
G2 X103.68 Y142.062 I21.492 J22.313 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.884 J-14.38 E.18439
G1 X99.739 Y130.445 E.24549
G3 X103.385 Y129.584 I2.79 J3.665 E.12801
G1 X120.021 Y112.948 E.78042
G1 X120.456 Y112.783 E.01543
G1 X126.786 Y119.112 E.29695
G3 X129.203 Y119.118 I1.198 J4.639 E.08106
G1 X135.531 Y112.79 E.29685
G1 X135.991 Y112.966 E.01632
G1 X152.604 Y129.578 E.77934
G3 X156.244 Y130.457 I.828 J4.549 E.12791
G1 X161.265 Y125.437 E.23552
G2 X160.005 Y124.422 I-3.03 J2.471 E.05403
; WIPE_START
G1 X160.782 Y124.94 E-.35477
G1 X161.265 Y125.437 E-.26309
G1 X161 Y125.701 E-.14215
; WIPE_END
G1 E-.04 F1800
G1 X153.642 Y127.729 Z5.8 F36000
G1 X100.537 Y142.367 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F15476.087
G1 X99.181 Y141.464 E.05401
G1 X101.97 Y138.675 E.13084
G1 X102.027 Y138.684 E.00191
G2 X103.587 Y138.585 I.468 J-4.948 E.05207
; CHANGE_LAYER
; Z_HEIGHT: 5.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X103.006 Y138.687 E-.22402
G1 X102.027 Y138.684 E-.37216
G1 X101.97 Y138.675 E-.02187
G1 X101.706 Y138.939 E-.14195
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
G1 X126.292 Y120.268
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X126.635 Y120.112 E.0125
G3 X127.786 Y119.863 I1.348 J3.447 E.03924
G1 X128.181 Y119.863 E.01307
G3 X126.238 Y120.295 I-.197 J3.696 E.70457
G1 X126.52 Y120.595 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.778 Y120.478 E.00871
G3 X127.807 Y120.255 I1.205 J3.081 E.0325
G1 X128.16 Y120.255 E.01083
G3 X126.457 Y120.623 I-.176 J3.304 E.58465
G1 X126.465 Y120.62 E.00028
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.13047
G1 X127.113 Y120.367 E-.1339
G1 X127.457 Y120.293 E-.13389
G1 X127.807 Y120.255 E-.13389
G1 X128.16 Y120.255 E-.13391
G1 X128.405 Y120.281 E-.09393
; WIPE_END
G1 E-.04 F1800
G1 X135.359 Y123.427 Z6 F36000
G1 X151.717 Y130.828 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.732 Y130.819 E.00057
G3 X153.242 Y130.407 I1.707 J3.284 E.05232
G1 X153.636 Y130.407 E.01307
G3 X151.392 Y131.02 I-.197 J3.696 E.69286
G1 X151.665 Y130.858 E.01051
G1 X151.968 Y131.142 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.00896
G3 X153.263 Y130.799 I1.205 J3.081 E.0325
G1 X153.615 Y130.799 E.01083
G3 X151.913 Y131.168 I-.176 J3.304 E.58462
G1 X151.914 Y131.167 E.00002
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.13367
G1 X152.568 Y130.911 E-.1339
G1 X152.913 Y130.837 E-.1339
G1 X153.263 Y130.799 E-.13389
G1 X153.615 Y130.799 E-.13391
G1 X153.853 Y130.825 E-.09074
; WIPE_END
G1 E-.04 F1800
G1 X146.263 Y131.629 Z6 F36000
G1 X99.753 Y136.556 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.743 Y136.541 E.00058
G3 X102.331 Y130.407 I2.784 J-2.438 E.2746
G1 X102.725 Y130.407 E.01308
G3 X100.018 Y136.823 I-.197 J3.696 E.4706
G1 X99.795 Y136.598 E.0105
G1 X100.018 Y136.262 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.821 Y136.006 E.00992
G3 X102.351 Y130.799 I2.707 J-1.903 E.21657
G1 X102.704 Y130.799 E.01083
G3 X100.059 Y136.306 I-.176 J3.304 E.39962
; WIPE_START
M204 S10000
G1 X99.821 Y136.006 E-.14536
G1 X99.632 Y135.709 E-.13383
G1 X99.478 Y135.392 E-.13395
G1 X99.358 Y135.061 E-.13385
G1 X99.275 Y134.718 E-.13391
G1 X99.247 Y134.512 E-.0791
; WIPE_END
G1 E-.04 F1800
G1 X106.759 Y135.862 Z6 F36000
G1 X153.292 Y144.224 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.394 J1.748 E.04338
G3 X88.408 Y132.053 I2.738 J2.13 E.03249
G2 X91.148 Y129.685 I-14.521 J-19.574 E.12022
G2 X93.594 Y126.159 I-11.288 J-10.444 E.14282
G3 X94.42 Y124.708 I12.304 J6.038 E.05544
G3 X95.012 Y124.286 I1.249 J1.127 E.02431
G2 X97.525 Y123.019 I-21.473 J-45.706 E.09335
G2 X101.007 Y120.323 I-8.606 J-14.711 E.14648
G3 X102.746 Y118.696 I16.213 J15.596 E.07903
G3 X103.977 Y118.067 I2.75 J3.856 E.04602
G2 X107.047 Y116.997 I-16.533 J-52.41 E.10788
G2 X110.366 Y115.274 I-7.762 J-19.008 E.12422
G3 X112.192 Y114.201 I10.959 J16.565 E.07028
G3 X113.876 Y113.812 I2.035 J4.969 E.05758
G2 X117.401 Y113.355 I-2.348 J-31.92 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10416
G3 X122.451 Y111.606 I9.404 J20.405 E.07348
G3 X123.43 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I37.932 J-213.125 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.298 J24.87 E.07086
G3 X133.23 Y111.549 I.18 J1.856 E.01155
G3 X134.227 Y111.868 I-.724 J3.992 E.03481
G2 X137.511 Y113.104 I11.112 J-24.531 E.11648
G2 X140.701 Y113.674 I5.147 J-19.606 E.10762
G3 X143.068 Y113.961 I-1.515 J22.336 E.07913
G3 X144.643 Y114.679 I-1.436 J5.237 E.05765
G2 X148.015 Y116.604 I17.387 J-26.546 E.12887
G2 X151.657 Y117.949 I12.728 J-28.856 E.12887
G3 X153.296 Y118.756 I-1.46 J5.035 E.06093
G3 X154.769 Y120.137 I-13.751 J16.136 E.06699
G2 X158.902 Y123.347 I14.663 J-14.613 E.17407
G3 X161.004 Y124.671 I-9.767 J17.841 E.08244
G3 X161.85 Y125.632 I-2.915 J3.42 E.04262
G2 X163.68 Y128.324 I49.861 J-31.927 E.10799
G2 X166.201 Y131.081 I16.838 J-12.865 E.12411
G3 X167.71 Y132.567 I-14.869 J16.604 E.07027
G3 X168.522 Y134.094 I-4.097 J3.158 E.05762
G1 X168.658 Y134.455 E.01279
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.136 J2.086 E.05195
G3 X88.163 Y131.747 I2.99 J2.225 E.03455
G2 X90.863 Y129.416 I-14.316 J-19.313 E.10971
G2 X93.249 Y125.974 I-11.005 J-10.177 E.12911
G3 X94.112 Y124.464 I12.334 J6.053 E.05348
G3 X94.828 Y123.94 I1.546 J1.358 E.02749
G2 X97.331 Y122.678 I-21.514 J-45.794 E.08612
G2 X100.735 Y120.04 I-8.413 J-14.373 E.1327
G3 X102.511 Y118.382 I16.294 J15.678 E.07471
G3 X103.844 Y117.698 I2.998 J4.196 E.0462
G2 X106.325 Y116.856 I-156.088 J-464.315 E.08051
G2 X110.16 Y114.94 I-7.083 J-18.974 E.13197
G3 X112.029 Y113.845 I11.118 J16.822 E.06659
G3 X113.833 Y113.423 I2.199 J5.332 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.546 E.10817
G2 X120.249 Y112.069 I-3.378 J-16.162 E.09423
G3 X122.349 Y111.227 I9.361 J20.304 E.06953
G3 X123.486 Y111.206 I.614 J2.41 E.03527
G2 X125.869 Y111.616 I39.518 J-222.314 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.315 J24.965 E.06668
G3 X133.273 Y111.159 I.213 J2.311 E.01301
G3 X134.376 Y111.505 I-.758 J4.352 E.03559
G2 X137.615 Y112.726 I10.992 J-24.247 E.10646
G2 X140.743 Y113.284 I5.04 J-19.215 E.09773
G3 X143.156 Y113.579 I-1.533 J22.526 E.07473
G3 X144.845 Y114.343 I-1.516 J5.602 E.05721
G2 X148.18 Y116.248 I17.23 J-26.292 E.11809
G2 X151.783 Y117.578 I12.593 J-28.58 E.11808
G3 X153.539 Y118.448 I-1.58 J5.393 E.06054
G3 X155.042 Y119.856 I-13.959 J16.406 E.06328
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.229 I-11.665 J21.079 E.07119
M73 P75 R4
G3 X162.172 Y125.409 I-2.91 J3.809 E.04973
G2 X163.993 Y128.088 I49.773 J-31.866 E.09954
G2 X166.471 Y130.796 I16.518 J-12.623 E.11296
G3 X168.012 Y132.318 I-14.983 J16.726 E.06657
G3 X168.887 Y133.952 I-4.411 J3.413 E.05721
G1 X169.137 Y134.615 E.02177
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X155.082 Y137.807 Z6 F36000
G1 Z5.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X153.502 Y138.153 I-1.934 J-5.043 E.05385
G1 X156.88 Y141.53 E.15843
G1 X161.572 Y138.547 E.18446
G1 X157.475 Y134.45 E.1922
G3 X157.016 Y136.001 I-5.353 J-.74 E.05385
; WIPE_START
G1 X157.318 Y135.275 E-.29888
G1 X157.475 Y134.45 E-.319
G1 X157.74 Y134.714 E-.14211
; WIPE_END
G1 E-.04 F1800
G1 X150.123 Y135.211 Z6 F36000
G1 X145.8 Y135.493 Z6
G1 Z5.6
G1 E.8 F1800
G1 F15476.087
G2 X144.466 Y134.559 I-9.583 J12.27 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.357 Y119.262 I24.416 J-30.383 E.15054
G2 X152.621 Y118.728 I-2.718 J2.967 E.03022
G1 X139.447 Y131.902 E.61802
G1 X139.666 Y131.992 E.00784
G1 X131.967 Y124.294 E.36115
G1 X132.008 Y123.989 E.0102
G1 X141.856 Y114.141 E.46198
G3 X143.449 Y114.447 I-.8 J8.482 E.0539
G1 X160.005 Y124.422 F36000
G1 F15476.087
G3 X161.265 Y125.437 I-1.769 J3.485 E.05403
G1 X155.847 Y130.854 E.25413
G2 X153.098 Y130.072 I-2.49 J3.534 E.09665
G1 X135.991 Y112.965 E.80252
G1 X135.531 Y112.79 E.01632
G1 X128.737 Y119.584 E.31871
G2 X127.253 Y119.579 I-.756 J4.078 E.04951
G1 X120.456 Y112.783 E.31885
G1 X120.021 Y112.948 E.01543
G1 X102.894 Y130.075 E.80346
G2 X100.135 Y130.842 I-.289 J4.308 E.09682
G1 X94.506 Y125.212 E.2641
G3 X91.467 Y129.849 I-19.922 J-9.742 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.064 J18.209 E.18071
G1 X105.792 Y136.499 E.06848
G2 X106.576 Y134.07 I-3.309 J-2.409 E.0861
G1 X128.138 Y112.507 E1.01153
G3 X127.857 Y112.508 I-.148 J-2.692 E.00933
G1 X149.39 Y134.041 E1.01016
G2 X150.187 Y136.514 I4.094 J.046 E.08771
G1 X148.729 Y137.972 E.06839
G3 X152.298 Y142.079 I-21.469 J22.263 E.18072
G1 X164.508 Y129.869 E.57279
G3 X167.552 Y132.93 I-266.436 J267.963 E.14321
G3 X168.093 Y133.96 I-8.369 J5.048 E.03861
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.499 J-3.227 E.00975
G1 X133.534 Y130.139 E.63753
G2 X129.657 Y129.659 I-5.817 J31.104 E.12968
G1 X127.589 Y127.591 E.09702
G2 X128.408 Y127.59 I.402 J-3.83 E.02721
G1 X126.34 Y129.657 E.09698
G2 X122.456 Y130.135 I1.928 J31.699 E.12989
G1 X108.861 Y116.54 E.63779
G3 X108.636 Y116.657 I-1.537 J-2.657 E.00842
G1 X89.965 Y135.329 E.87592
G1 X88.609 Y134.427 E.05401
G1 X98.961 Y136.023 F36000
G1 F15476.087
G3 X98.495 Y134.474 I4.877 J-2.313 E.05385
G1 X94.573 Y138.397 E.184
G1 X99.181 Y141.464 E.18364
G1 X102.491 Y138.155 E.15527
G3 X100.909 Y137.816 I.326 J-5.391 E.05385
; WIPE_START
G1 X101.671 Y138.065 E-.30451
G1 X102.491 Y138.155 E-.31338
G1 X102.226 Y138.419 E-.14211
; WIPE_END
G1 E-.04 F1800
G1 X105.242 Y131.408 Z6 F36000
G1 X112.541 Y114.437 Z6
G1 Z5.6
G1 E.8 F1800
G1 F15476.087
G3 X114.137 Y114.139 I2.484 J8.896 E.05391
G1 X123.954 Y123.957 E.46057
G2 X124.003 Y124.318 I1.721 J-.05 E.0121
G1 X116.349 Y131.973 E.35911
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.45 J2.765 E.02677
G3 X99.258 Y122.288 I-22.943 J-21.967 E.15409
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.885 J12.762 E.05403
; CHANGE_LAYER
; Z_HEIGHT: 5.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X111.517 Y134.548 E-.61868
G1 X111.254 Y134.285 E-.14132
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
G1 X126.292 Y120.268
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X126.635 Y120.112 E.01249
G3 X127.786 Y119.863 I1.348 J3.446 E.03924
G1 X128.181 Y119.863 E.01307
G3 X126.239 Y120.295 I-.197 J3.695 E.70451
G1 X126.515 Y120.597 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.778 Y120.478 E.00888
G3 X127.807 Y120.255 I1.205 J3.081 E.0325
G1 X128.16 Y120.255 E.01083
G3 X126.457 Y120.624 I-.176 J3.304 E.58459
G1 X126.46 Y120.622 E.00011
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.13256
G1 X127.113 Y120.367 E-.1339
G1 X127.457 Y120.293 E-.1339
G1 X127.807 Y120.255 E-.13389
G1 X128.16 Y120.255 E-.13391
G1 X128.4 Y120.281 E-.09185
; WIPE_END
G1 E-.04 F1800
G1 X135.353 Y123.428 Z6.2 F36000
G1 X151.711 Y130.832 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.732 Y130.819 E.00083
G3 X153.242 Y130.407 I1.707 J3.283 E.05232
G1 X153.636 Y130.407 E.01307
G3 X151.303 Y131.081 I-.197 J3.695 E.68914
G1 X151.659 Y130.864 E.01386
G1 X151.963 Y131.145 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.00915
G3 X153.263 Y130.799 I1.205 J3.081 E.0325
G1 X153.615 Y130.799 E.01083
G3 X151.908 Y131.17 I-.176 J3.303 E.58436
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.13595
G1 X152.568 Y130.911 E-.1339
G1 X152.913 Y130.837 E-.1339
G1 X153.263 Y130.799 E-.13389
G1 X153.615 Y130.799 E-.13391
G1 X153.847 Y130.824 E-.08846
; WIPE_END
G1 E-.04 F1800
G1 X146.257 Y131.624 Z6.2 F36000
G1 X99.73 Y136.529 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.496 Y136.234 E.0125
G3 X102.331 Y130.407 I3.025 J-2.131 E.26185
G3 X104.481 Y130.964 I.197 J3.67 E.07484
G3 X99.768 Y136.576 I-1.96 J3.139 E.42012
G1 X100.02 Y136.264 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.822 Y136.005 E.01
G3 X102.351 Y130.799 I2.706 J-1.903 E.21655
G1 X102.704 Y130.799 E.01083
G3 X100.061 Y136.307 I-.176 J3.303 E.39942
; WIPE_START
M204 S10000
G1 X99.822 Y136.005 E-.14638
G1 X99.632 Y135.709 E-.13382
G1 X99.478 Y135.392 E-.13395
G1 X99.358 Y135.061 E-.13385
G1 X99.275 Y134.718 E-.13391
G1 X99.247 Y134.515 E-.0781
; WIPE_END
G1 E-.04 F1800
G1 X106.76 Y135.864 Z6.2 F36000
G1 X153.292 Y144.224 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.393 J1.748 E.04338
G3 X88.409 Y132.052 I2.737 J2.128 E.0325
G2 X91.148 Y129.685 I-14.52 J-19.572 E.12021
G2 X93.594 Y126.161 I-11.287 J-10.443 E.14278
G3 X94.42 Y124.708 I12.314 J6.044 E.05548
G3 X95.013 Y124.286 I1.249 J1.126 E.02432
G2 X97.525 Y123.019 I-21.474 J-45.708 E.09335
G2 X101.007 Y120.323 I-8.606 J-14.71 E.14647
G3 X102.746 Y118.696 I16.213 J15.596 E.07904
G3 X103.976 Y118.067 I2.751 J3.858 E.046
G2 X107.048 Y116.997 I-16.529 J-52.398 E.1079
G2 X110.366 Y115.274 I-7.762 J-19.008 E.12422
G3 X112.192 Y114.201 I10.965 J16.577 E.07027
G3 X113.876 Y113.812 I2.035 J4.969 E.05758
G2 X117.401 Y113.355 I-2.347 J-31.911 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.57 E.10417
G3 X122.452 Y111.606 I9.399 J20.394 E.07348
G3 X123.43 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I37.917 J-213.041 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.295 J24.853 E.07087
G3 X133.23 Y111.549 I.18 J1.853 E.01155
G3 X134.227 Y111.868 I-.725 J3.994 E.03482
G2 X137.511 Y113.104 I11.112 J-24.531 E.11647
G2 X140.701 Y113.674 I5.147 J-19.607 E.10762
G3 X143.068 Y113.961 I-1.514 J22.334 E.07913
G3 X144.643 Y114.679 I-1.436 J5.238 E.05764
G2 X148.015 Y116.604 I17.391 J-26.552 E.12887
G2 X151.657 Y117.949 I12.733 J-28.87 E.12888
G3 X153.296 Y118.756 I-1.46 J5.034 E.06094
G3 X154.769 Y120.137 I-13.744 J16.129 E.06699
G2 X158.902 Y123.348 I14.664 J-14.614 E.17409
G3 X160.841 Y124.544 I-11.506 J20.812 E.0756
G3 X161.85 Y125.632 I-2.745 J3.558 E.04943
G2 X163.68 Y128.324 I49.905 J-31.956 E.108
G2 X166.202 Y131.082 I16.838 J-12.865 E.12415
G3 X167.71 Y132.567 I-14.876 J16.611 E.07022
G3 X168.522 Y134.094 I-4.096 J3.158 E.05763
G1 X168.658 Y134.455 E.01279
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.136 J2.086 E.05195
G3 X88.163 Y131.747 I2.989 J2.223 E.03455
G2 X90.863 Y129.416 I-14.316 J-19.313 E.10971
G2 X93.249 Y125.974 I-11.006 J-10.177 E.1291
G3 X94.112 Y124.464 I12.339 J6.055 E.05349
G3 X94.828 Y123.94 I1.545 J1.357 E.02749
G2 X97.331 Y122.678 I-21.516 J-45.798 E.08612
G2 X100.735 Y120.04 I-8.413 J-14.372 E.13271
G3 X102.512 Y118.382 I16.287 J15.671 E.07471
G3 X103.844 Y117.698 I2.998 J4.197 E.04618
G2 X106.325 Y116.856 I-155.378 J-462.22 E.08051
G2 X110.161 Y114.94 I-7.082 J-18.973 E.13198
G3 X112.029 Y113.845 I11.121 J16.828 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05718
G2 X117.323 Y112.971 I-2.308 J-31.536 E.10818
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.349 Y111.227 I9.359 J20.301 E.06953
G3 X123.486 Y111.206 I.613 J2.41 E.03526
G2 X125.869 Y111.616 I39.647 J-223.073 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.313 J24.951 E.06669
G3 X133.273 Y111.159 I.213 J2.306 E.013
G3 X134.376 Y111.505 I-.759 J4.353 E.03559
G2 X137.615 Y112.726 I10.994 J-24.252 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.525 E.07473
G3 X144.845 Y114.343 I-1.517 J5.603 E.05721
G2 X148.18 Y116.248 I17.23 J-26.292 E.11809
G2 X151.783 Y117.578 I12.596 J-28.589 E.11809
G3 X153.54 Y118.449 I-1.58 J5.393 E.06054
G3 X155.042 Y119.856 I-13.956 J16.402 E.06327
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.23 I-11.646 J21.047 E.0712
G3 X162.172 Y125.408 I-3 J3.891 E.0497
G2 X163.993 Y128.088 I49.767 J-31.861 E.09955
G2 X166.471 Y130.796 I16.518 J-12.623 E.11296
G3 X168.012 Y132.317 I-14.988 J16.732 E.06656
G3 X168.887 Y133.951 I-4.41 J3.413 E.05722
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26194
; WIPE_END
G1 E-.04 F1800
G1 X156.448 Y136.817 Z6.2 F36000
G1 X157.016 Y136.001 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X157.475 Y134.45 I-4.895 J-2.291 E.05385
G1 X161.572 Y138.547 E.1922
G1 X156.88 Y141.53 E.18446
G1 X153.502 Y138.153 E.15843
G2 X155.082 Y137.807 I-.354 J-5.39 E.05385
; WIPE_START
G1 X154.296 Y138.065 E-.31457
G1 X153.502 Y138.153 E-.30331
G1 X153.767 Y138.418 E-.14212
; WIPE_END
G1 E-.04 F1800
G1 X150.749 Y131.407 Z6.2 F36000
G1 X143.449 Y114.447 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F15476.087
G2 X141.856 Y114.141 I-2.394 J8.176 E.0539
G1 X132.008 Y123.989 E.46198
G1 X131.967 Y124.294 E.0102
G1 X139.666 Y131.992 E.36115
G1 X139.447 Y131.902 E.00784
G1 X152.621 Y118.728 E.61802
G3 X153.356 Y119.262 I-1.987 J3.507 E.0302
G2 X156.721 Y122.304 I27.782 J-27.343 E.15056
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.242 J13.194 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X137.098 Y134.15 Z6.2 F36000
G1 X112.9 Y133.689 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.5 J13.619 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.18 I-19.503 J-25.082 E.15409
G3 X103.362 Y118.717 I2.112 J2.307 E.02678
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X124.003 Y124.318 E.35911
G3 X123.954 Y123.957 I1.672 J-.411 E.0121
G1 X114.137 Y114.139 E.46057
G2 X112.541 Y114.437 I.889 J9.199 E.05391
; WIPE_START
G1 X112.968 Y114.304 E-.16981
G1 X114.137 Y114.139 E-.44853
G1 X114.4 Y114.403 E-.14166
; WIPE_END
G1 E-.04 F1800
G1 X110.59 Y121.016 Z6.2 F36000
G1 X100.909 Y137.816 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F15476.087
G2 X102.491 Y138.155 I1.908 J-5.053 E.05385
G1 X99.181 Y141.464 E.15527
G1 X94.573 Y138.397 E.18364
G1 X98.495 Y134.474 E.184
G2 X98.961 Y136.023 I5.343 J-.765 E.05385
G1 X88.609 Y134.427 F36000
G1 F15476.087
G1 X89.965 Y135.329 E.05401
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.314 J-2.777 E.00843
G1 X122.456 Y130.135 E.63779
G3 X126.34 Y129.657 I5.812 J31.221 E.12989
G1 X128.408 Y127.59 E.09698
G3 X127.589 Y127.591 I-.417 J-3.828 E.02721
G1 X129.657 Y129.659 E.09702
G3 X133.534 Y130.139 I-1.94 J31.588 E.12968
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.76 J-3.091 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02426
G1 X168.093 Y133.96 E.0568
G2 X167.03 Y132.345 I-4.207 J1.608 E.06465
G3 X164.508 Y129.869 I23.153 J-26.113 E.11729
G1 X152.298 Y142.079 E.57279
M73 P76 R4
G2 X148.729 Y137.972 I-25.038 J18.155 E.18072
G1 X150.187 Y136.514 E.06839
G3 X149.39 Y134.041 I3.297 J-2.427 E.08771
G1 X127.857 Y112.508 E1.01016
G2 X128.138 Y112.507 I.133 J-2.693 E.00933
G1 X106.576 Y134.07 E1.01153
G3 X105.792 Y136.499 I-4.092 J.021 E.0861
G1 X107.252 Y137.958 E.06848
G2 X103.68 Y142.062 I21.492 J22.313 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.884 J-14.38 E.18439
G1 X100.135 Y130.842 E.2641
G3 X102.894 Y130.075 I2.47 J3.542 E.09682
G1 X120.021 Y112.948 E.80346
G1 X120.456 Y112.783 E.01543
G1 X127.253 Y119.579 E.31885
G3 X128.737 Y119.584 I.729 J4.083 E.04951
G1 X135.531 Y112.79 E.31871
G1 X135.991 Y112.965 E.01632
G1 X153.098 Y130.072 E.80252
G3 X155.847 Y130.854 I.26 J4.315 E.09665
G1 X161.265 Y125.436 E.25415
G2 X160.005 Y124.422 I-3.932 J3.594 E.05386
; CHANGE_LAYER
; Z_HEIGHT: 6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X160.78 Y124.939 E-.35419
G1 X161.265 Y125.436 E-.26379
G1 X161.001 Y125.7 E-.14202
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
G1 X126.292 Y120.268
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X126.635 Y120.112 E.01249
G3 X127.786 Y119.863 I1.349 J3.446 E.03924
G3 X129.207 Y120.071 I.197 J3.615 E.04796
G1 X129.332 Y120.112 E.00435
G3 X126.239 Y120.295 I-1.348 J3.446 E.66519
G1 X126.51 Y120.599 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.778 Y120.478 E.00904
G3 X127.807 Y120.255 I1.206 J3.08 E.0325
G3 X129.084 Y120.443 I.176 J3.235 E.03993
G1 X129.189 Y120.478 E.00339
G3 X126.456 Y120.625 I-1.205 J3.081 E.55194
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.13461
G1 X127.113 Y120.367 E-.1339
G1 X127.457 Y120.293 E-.1339
G1 X127.807 Y120.255 E-.13389
G1 X128.16 Y120.255 E-.13391
G1 X128.395 Y120.28 E-.0898
; WIPE_END
G1 E-.04 F1800
G1 X135.352 Y123.418 Z6.4 F36000
G1 X151.748 Y130.812 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.091 Y130.657 E.01249
G3 X153.242 Y130.407 I1.349 J3.446 E.03924
G3 X154.663 Y130.615 I.197 J3.615 E.04796
G1 X154.788 Y130.656 E.00435
G3 X151.695 Y130.839 I-1.348 J3.446 E.66519
G1 X151.957 Y131.147 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.00933
G3 X153.263 Y130.799 I1.206 J3.08 E.03249
G3 X154.54 Y130.987 I.176 J3.235 E.03993
G1 X154.645 Y131.022 E.00339
G3 X151.903 Y131.173 I-1.205 J3.081 E.55165
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.13819
G1 X152.568 Y130.911 E-.1339
G1 X152.913 Y130.837 E-.1339
G1 X153.263 Y130.799 E-.13389
G1 X153.615 Y130.799 E-.13391
G1 X153.841 Y130.823 E-.08622
; WIPE_END
G1 E-.04 F1800
G1 X146.251 Y131.628 Z6.4 F36000
G1 X99.753 Y136.556 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.744 Y136.54 E.0006
G3 X102.331 Y130.407 I2.783 J-2.438 E.27457
G1 X102.725 Y130.407 E.01307
G3 X100.019 Y136.822 I-.197 J3.695 E.47052
G1 X99.796 Y136.598 E.01049
G1 X100.022 Y136.266 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.822 Y136.005 E.01009
G3 X102.351 Y130.799 I2.706 J-1.903 E.21654
G1 X102.704 Y130.799 E.01083
G3 X100.063 Y136.309 I-.176 J3.303 E.39934
; WIPE_START
M204 S10000
G1 X99.822 Y136.005 E-.14745
G1 X99.632 Y135.709 E-.13381
G1 X99.478 Y135.392 E-.13395
G1 X99.358 Y135.061 E-.13385
G1 X99.275 Y134.718 E-.13391
G1 X99.248 Y134.517 E-.07703
; WIPE_END
G1 E-.04 F1800
G1 X106.76 Y135.867 Z6.4 F36000
G1 X153.292 Y144.224 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98338
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.393 J1.749 E.04338
G3 X88.409 Y132.052 I2.737 J2.128 E.0325
G2 X91.148 Y129.685 I-14.52 J-19.572 E.12021
G2 X93.594 Y126.159 I-11.288 J-10.444 E.14282
G3 X94.42 Y124.708 I12.308 J6.041 E.05543
G3 X95.012 Y124.286 I1.249 J1.126 E.02431
G2 X97.525 Y123.019 I-21.478 J-45.717 E.09338
G2 X101.007 Y120.323 I-8.607 J-14.711 E.14646
G3 X102.746 Y118.697 I16.201 J15.582 E.07902
G3 X103.976 Y118.067 I2.75 J3.855 E.04601
G2 X107.048 Y116.997 I-16.537 J-52.421 E.10791
G2 X110.366 Y115.274 I-7.764 J-19.011 E.12422
G3 X112.192 Y114.201 I10.961 J16.569 E.07028
G3 X113.876 Y113.812 I2.035 J4.97 E.05757
G2 X117.401 Y113.355 I-2.348 J-31.918 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10416
G3 X122.451 Y111.606 I9.409 J20.417 E.07347
G3 X123.43 Y111.594 I.514 J2.043 E.03278
G2 X125.813 Y112.005 I37.932 J-213.125 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.882 Y111.551 I5.298 J24.871 E.07087
G3 X133.23 Y111.55 I.179 J1.849 E.01155
G3 X134.227 Y111.868 I-.725 J3.994 E.03482
G2 X137.511 Y113.104 I11.112 J-24.529 E.11647
G2 X140.701 Y113.674 I5.147 J-19.608 E.10762
G3 X143.068 Y113.962 I-1.514 J22.332 E.07913
G3 X144.643 Y114.679 I-1.436 J5.237 E.05764
G2 X148.015 Y116.604 I17.389 J-26.549 E.12887
G2 X150.332 Y117.514 I10.345 J-22.922 E.08263
G3 X152.581 Y118.308 I-6.308 J21.461 E.07913
G3 X153.962 Y119.348 I-2.379 J4.594 E.05763
G2 X156.837 Y121.957 I22.738 J-22.171 E.12887
G2 X158.902 Y123.348 I15.076 J-20.161 E.08263
G3 X161.003 Y124.671 I-9.76 J17.831 E.08242
G3 X161.85 Y125.633 I-2.92 J3.425 E.04265
G2 X163.68 Y128.324 I49.832 J-31.906 E.10796
G2 X166.202 Y131.082 I16.836 J-12.863 E.12414
G3 X167.71 Y132.567 I-14.875 J16.609 E.07023
G3 X168.522 Y134.093 I-4.095 J3.158 E.05762
G1 X168.658 Y134.455 E.01281
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.782 E1.86611
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.136 J2.086 E.05195
G3 X88.163 Y131.747 I2.989 J2.223 E.03456
G2 X90.863 Y129.416 I-14.315 J-19.312 E.10971
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.334 J6.053 E.05348
G3 X94.828 Y123.94 I1.545 J1.357 E.02748
G2 X97.331 Y122.678 I-21.525 J-45.816 E.08613
G2 X100.735 Y120.04 I-8.414 J-14.373 E.1327
G3 X102.512 Y118.382 I16.284 J15.667 E.07471
G3 X103.844 Y117.698 I2.997 J4.195 E.04618
G2 X106.326 Y116.856 I-155.37 J-462.195 E.08053
G2 X110.161 Y114.94 I-7.083 J-18.975 E.13198
G3 X112.029 Y113.845 I11.12 J16.826 E.06659
G3 X113.833 Y113.423 I2.199 J5.334 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.545 E.10817
G2 X120.249 Y112.069 I-3.378 J-16.161 E.09423
G3 X122.348 Y111.227 I9.367 J20.318 E.06953
G3 X123.486 Y111.206 I.614 J2.41 E.03527
G2 X125.869 Y111.616 I39.518 J-222.314 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.317 J24.975 E.06668
G3 X133.273 Y111.159 I.213 J2.304 E.013
G3 X134.376 Y111.505 I-.758 J4.353 E.03559
G2 X137.615 Y112.726 I10.993 J-24.25 E.10646
G2 X140.743 Y113.284 I5.04 J-19.215 E.09773
G3 X143.156 Y113.579 I-1.533 J22.528 E.07473
G3 X144.845 Y114.343 I-1.516 J5.602 E.05721
G2 X148.18 Y116.248 I17.228 J-26.289 E.11809
G2 X150.457 Y117.142 I10.161 J-22.523 E.07518
G3 X152.749 Y117.953 I-6.367 J21.643 E.07475
G3 X154.232 Y119.064 I-2.556 J4.957 E.05721
G2 X157.076 Y121.646 I22.519 J-21.947 E.1181
G2 X159.105 Y123.012 I14.802 J-19.8 E.07517
G3 X161.075 Y124.23 I-11.65 J21.055 E.0712
G3 X162.172 Y125.409 I-3 J3.891 E.04972
G2 X163.993 Y128.088 I49.766 J-31.861 E.09952
G2 X166.471 Y130.796 I16.518 J-12.622 E.11296
G3 X168.012 Y132.317 I-14.99 J16.734 E.06656
G3 X168.887 Y133.951 I-4.41 J3.413 E.05722
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26194
; WIPE_END
G1 E-.04 F1800
G1 X155.082 Y137.807 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X153.502 Y138.153 I-1.934 J-5.043 E.05385
G1 X156.88 Y141.53 E.15843
G1 X161.572 Y138.547 E.18446
G1 X157.475 Y134.45 E.1922
G3 X157.016 Y136.001 I-5.353 J-.74 E.05385
; WIPE_START
G1 X157.318 Y135.275 E-.29889
G1 X157.475 Y134.45 E-.319
G1 X157.74 Y134.714 E-.14211
; WIPE_END
G1 E-.04 F1800
G1 X150.123 Y135.211 Z6.4 F36000
G1 X145.8 Y135.493 Z6.4
G1 Z6
G1 E.8 F1800
G1 F15476.087
G2 X144.466 Y134.559 I-9.583 J12.27 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.357 Y119.262 I24.412 J-30.379 E.15053
G2 X152.621 Y118.728 I-2.735 J2.989 E.03022
G1 X139.447 Y131.902 E.61803
G1 X139.666 Y131.992 E.00784
G1 X131.967 Y124.294 E.36115
G1 X132.008 Y123.989 E.0102
G1 X141.856 Y114.141 E.46198
G3 X143.449 Y114.447 I-.799 J8.473 E.0539
G1 X160.005 Y124.422 F36000
G1 F15476.087
G3 X161.265 Y125.436 I-2.673 J4.61 E.05386
G1 X155.847 Y130.854 E.25415
G2 X153.098 Y130.072 I-2.49 J3.534 E.09665
G1 X135.991 Y112.966 E.80252
G1 X135.531 Y112.79 E.01632
G1 X128.737 Y119.584 E.31871
G2 X127.253 Y119.579 I-.756 J4.078 E.04951
G1 X120.456 Y112.783 E.31885
G1 X120.021 Y112.948 E.01543
G1 X102.894 Y130.075 E.80346
G2 X100.135 Y130.842 I-.289 J4.308 E.09682
G1 X94.506 Y125.212 E.2641
G3 X91.467 Y129.849 I-19.923 J-9.743 E.18439
G1 X103.68 Y142.062 E.57295
G3 X107.252 Y137.958 I25.066 J18.211 E.18071
G1 X105.792 Y136.499 E.06848
G2 X106.576 Y134.07 I-3.309 J-2.409 E.0861
G1 X128.138 Y112.507 E1.01153
G3 X127.857 Y112.508 I-.148 J-2.692 E.00933
G1 X149.39 Y134.041 E1.01016
G2 X150.187 Y136.514 I4.094 J.046 E.08771
G1 X148.729 Y137.972 E.06839
G3 X152.298 Y142.079 I-21.469 J22.262 E.18072
G1 X164.508 Y129.869 E.57279
G3 X167.553 Y132.932 I-261.746 J263.276 E.14327
G3 X168.093 Y133.96 I-8.437 J5.08 E.03855
G1 X166.882 Y135.171 E.0568
G1 X166.265 Y135.564 E.02426
G1 X147.385 Y116.684 E.88568
G3 X147.124 Y116.549 I1.497 J-3.221 E.00975
G1 X133.534 Y130.139 E.63753
G2 X129.657 Y129.659 I-5.817 J31.104 E.12968
G1 X127.589 Y127.591 E.09702
G2 X128.408 Y127.59 I.402 J-3.83 E.02721
G1 X126.34 Y129.657 E.09698
G2 X122.456 Y130.135 I1.928 J31.699 E.12989
G1 X108.861 Y116.54 E.63778
G3 X108.636 Y116.657 I-1.537 J-2.658 E.00842
G1 X89.965 Y135.329 E.87592
G1 X88.609 Y134.427 E.05401
G1 X98.961 Y136.023 F36000
G1 F15476.087
G3 X98.495 Y134.474 I4.877 J-2.313 E.05385
G1 X94.573 Y138.397 E.184
G1 X99.181 Y141.464 E.18364
G1 X102.491 Y138.155 E.15527
G3 X100.909 Y137.816 I.326 J-5.391 E.05385
; WIPE_START
G1 X101.671 Y138.065 E-.30451
G1 X102.491 Y138.155 E-.31338
G1 X102.226 Y138.419 E-.14211
; WIPE_END
G1 E-.04 F1800
G1 X105.242 Y131.408 Z6.4 F36000
G1 X112.541 Y114.437 Z6.4
G1 Z6
G1 E.8 F1800
G1 F15476.087
G3 X114.137 Y114.139 I2.484 J8.899 E.05391
G1 X123.954 Y123.957 E.46057
G2 X124.003 Y124.318 I1.721 J-.05 E.0121
G1 X116.349 Y131.973 E.35911
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.45 J2.765 E.02678
G3 X99.258 Y122.288 I-22.94 J-21.964 E.15408
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.885 J12.762 E.05403
; CHANGE_LAYER
; Z_HEIGHT: 6.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X111.517 Y134.548 E-.61868
G1 X111.254 Y134.285 E-.14132
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
G1 X126.292 Y120.268
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X126.635 Y120.112 E.01248
G3 X127.786 Y119.863 I1.349 J3.446 E.03924
G3 X129.187 Y120.064 I.197 J3.606 E.04723
G1 X129.332 Y120.112 E.00508
G3 X126.239 Y120.295 I-1.348 J3.446 E.66522
G1 X126.505 Y120.602 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.778 Y120.478 E.0092
G3 X127.807 Y120.255 I1.206 J3.081 E.0325
G3 X129.063 Y120.436 I.176 J3.225 E.03925
G1 X129.189 Y120.478 E.00406
G3 X126.451 Y120.627 I-1.205 J3.081 E.5518
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.13663
G1 X127.113 Y120.367 E-.1339
G1 X127.457 Y120.293 E-.1339
G1 X127.807 Y120.255 E-.13389
G1 X128.16 Y120.255 E-.13391
G1 X128.389 Y120.28 E-.08778
; WIPE_END
G1 E-.04 F1800
G1 X135.343 Y123.427 Z6.6 F36000
G1 X151.709 Y130.834 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.732 Y130.819 E.00092
G3 X153.242 Y130.407 I1.707 J3.282 E.05232
G1 X153.636 Y130.407 E.01307
G3 X151.267 Y131.107 I-.197 J3.695 E.68758
G1 X151.657 Y130.865 E.01524
G1 X151.952 Y131.15 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.00951
G3 X153.263 Y130.799 I1.205 J3.08 E.0325
G1 X153.615 Y130.799 E.01083
G3 X151.898 Y131.176 I-.176 J3.303 E.5839
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.14033
G1 X152.568 Y130.911 E-.1339
G1 X152.913 Y130.837 E-.1339
G1 X153.263 Y130.799 E-.13389
G1 X153.615 Y130.799 E-.13391
G1 X153.835 Y130.823 E-.08408
; WIPE_END
G1 E-.04 F1800
G1 X146.246 Y131.627 Z6.6 F36000
G1 X99.753 Y136.556 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.743 Y136.542 E.0006
G3 X102.331 Y130.407 I2.78 J-2.44 E.27476
G3 X105.339 Y131.703 I.182 J3.719 E.11252
G3 X100.018 Y136.823 I-2.816 J2.398 E.3706
G1 X99.796 Y136.599 E.01048
G1 X100.023 Y136.268 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.822 Y136.005 E.01018
G3 X102.351 Y130.799 I2.706 J-1.903 E.21655
G1 X102.704 Y130.799 E.01083
G3 X100.065 Y136.311 I-.176 J3.303 E.39925
; WIPE_START
M204 S10000
G1 X99.822 Y136.005 E-.1485
G1 X99.632 Y135.709 E-.13382
G1 X99.478 Y135.392 E-.13395
M73 P77 R4
G1 X99.358 Y135.061 E-.13385
G1 X99.275 Y134.718 E-.13391
G1 X99.248 Y134.52 E-.07598
; WIPE_END
G1 E-.04 F1800
G1 X106.76 Y135.869 Z6.6 F36000
G1 X153.292 Y144.224 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.39 J1.747 E.04339
G3 X88.408 Y132.053 I2.735 J2.126 E.0325
G2 X91.148 Y129.685 I-14.523 J-19.575 E.12022
G2 X93.594 Y126.159 I-11.289 J-10.444 E.14282
G3 X94.42 Y124.708 I12.31 J6.042 E.05543
G3 X95.013 Y124.285 I1.25 J1.127 E.02434
G2 X97.525 Y123.019 I-21.452 J-45.665 E.09333
G2 X101.007 Y120.323 I-8.607 J-14.712 E.14649
G3 X102.746 Y118.696 I16.202 J15.584 E.07902
G3 X103.976 Y118.067 I2.75 J3.856 E.046
G2 X107.048 Y116.997 I-16.539 J-52.425 E.1079
G2 X110.366 Y115.274 I-7.762 J-19.008 E.12422
G3 X112.192 Y114.201 I10.965 J16.576 E.07027
G3 X113.876 Y113.812 I2.035 J4.97 E.05757
G2 X117.401 Y113.355 I-2.348 J-31.918 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10416
G3 X122.452 Y111.606 I9.402 J20.399 E.07349
G3 X123.43 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I37.988 J-213.454 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.883 Y111.551 I5.295 J24.852 E.07088
G3 X133.23 Y111.55 I.179 J1.845 E.01154
G3 X134.227 Y111.868 I-.724 J3.992 E.03482
G2 X137.511 Y113.104 I11.112 J-24.529 E.11647
G2 X140.701 Y113.674 I5.146 J-19.604 E.10762
G3 X143.067 Y113.961 I-1.517 J22.36 E.0791
G3 X144.643 Y114.679 I-1.434 J5.237 E.05768
G2 X148.015 Y116.604 I17.389 J-26.549 E.12886
G2 X150.332 Y117.514 I10.345 J-22.923 E.08263
G3 X152.669 Y118.351 I-5.677 J19.54 E.0824
G3 X153.963 Y119.349 I-2.504 J4.582 E.05442
G2 X156.837 Y121.957 I22.724 J-22.157 E.12883
G2 X158.902 Y123.347 I15.067 J-20.148 E.08261
G3 X161.002 Y124.67 I-9.772 J17.851 E.08239
G3 X161.85 Y125.632 I-3.368 J3.822 E.04265
G2 X163.68 Y128.324 I49.891 J-31.947 E.10797
G2 X166.201 Y131.081 I16.837 J-12.864 E.12413
G3 X167.71 Y132.567 I-14.882 J16.617 E.07027
G3 X168.522 Y134.094 I-4.096 J3.158 E.05761
G1 X168.658 Y134.455 E.0128
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.139 J2.087 E.05195
G3 X88.163 Y131.747 I2.988 J2.222 E.03456
G2 X90.863 Y129.416 I-14.317 J-19.314 E.10972
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.338 J6.055 E.05348
G3 X94.829 Y123.939 I1.546 J1.358 E.02751
G2 X97.331 Y122.678 I-21.503 J-45.771 E.0861
G2 X100.735 Y120.04 I-8.414 J-14.374 E.13271
G3 X102.512 Y118.382 I16.286 J15.67 E.07471
G3 X103.844 Y117.698 I2.997 J4.196 E.04618
G2 X106.326 Y116.856 I-155.393 J-462.262 E.08052
G2 X110.161 Y114.94 I-7.083 J-18.974 E.13198
G3 X112.029 Y113.845 I11.125 J16.834 E.06659
G3 X113.833 Y113.423 I2.199 J5.333 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.544 E.10817
G2 X120.249 Y112.069 I-3.378 J-16.162 E.09423
G3 X122.349 Y111.227 I9.359 J20.299 E.06954
G3 X123.486 Y111.206 I.613 J2.41 E.03527
G2 X125.869 Y111.616 I39.572 J-222.629 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.313 J24.953 E.0667
G3 X133.273 Y111.159 I.213 J2.299 E.01299
G3 X134.376 Y111.505 I-.758 J4.352 E.03559
G2 X137.615 Y112.726 I10.993 J-24.25 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.534 J22.535 E.07472
G3 X144.845 Y114.343 I-1.516 J5.601 E.05722
G2 X148.18 Y116.248 I17.228 J-26.289 E.11809
G2 X150.457 Y117.142 I10.159 J-22.516 E.07518
G3 X152.644 Y117.905 I-6.821 J23.087 E.0712
G3 X154.233 Y119.065 I-2.358 J4.898 E.06078
G2 X157.076 Y121.646 I22.511 J-21.939 E.11808
G2 X159.105 Y123.012 I14.799 J-19.795 E.07517
G3 X161.075 Y124.23 I-11.647 J21.05 E.07121
G3 X162.172 Y125.408 I-2.87 J3.77 E.04971
G2 X163.993 Y128.088 I49.777 J-31.868 E.09954
G2 X166.471 Y130.796 I16.518 J-12.623 E.11296
G3 X168.012 Y132.318 I-14.987 J16.73 E.06658
G3 X168.887 Y133.952 I-4.412 J3.413 E.05721
G1 X169.137 Y134.615 E.02177
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26194
; WIPE_END
G1 E-.04 F1800
G1 X156.448 Y136.817 Z6.6 F36000
G1 X157.016 Y136.001 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X157.475 Y134.45 I-4.894 J-2.291 E.05385
G1 X161.572 Y138.547 E.1922
G1 X156.88 Y141.53 E.18446
G1 X153.502 Y138.153 E.15843
G2 X155.082 Y137.807 I-.354 J-5.39 E.05385
; WIPE_START
G1 X154.296 Y138.065 E-.31457
G1 X153.502 Y138.153 E-.30332
G1 X153.767 Y138.418 E-.14211
; WIPE_END
G1 E-.04 F1800
G1 X150.749 Y131.407 Z6.6 F36000
G1 X143.449 Y114.447 Z6.6
G1 Z6.2
G1 E.8 F1800
G1 F15476.087
G2 X141.856 Y114.141 I-2.394 J8.175 E.0539
G1 X132.008 Y123.989 E.46198
G1 X131.967 Y124.294 E.0102
G1 X139.666 Y131.992 E.36115
G1 X139.447 Y131.902 E.00784
G1 X152.623 Y118.726 E.61812
G3 X153.357 Y119.263 I-2.173 J3.739 E.0302
G2 X156.721 Y122.304 I27.785 J-27.347 E.15053
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.243 J13.195 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X137.098 Y134.15 Z6.6 F36000
G1 X112.9 Y133.689 Z6.6
G1 Z6.2
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.502 J13.621 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.18 I-19.499 J-25.077 E.15409
G3 X103.362 Y118.717 I2.108 J2.302 E.02677
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X124.003 Y124.318 E.35911
G3 X123.954 Y123.957 I1.672 J-.411 E.0121
G1 X114.137 Y114.139 E.46057
G2 X112.541 Y114.437 I.89 J9.202 E.05391
; WIPE_START
G1 X112.968 Y114.304 E-.1698
G1 X114.137 Y114.139 E-.44854
G1 X114.4 Y114.403 E-.14166
; WIPE_END
G1 E-.04 F1800
G1 X110.59 Y121.016 Z6.6 F36000
G1 X100.909 Y137.816 Z6.6
G1 Z6.2
G1 E.8 F1800
G1 F15476.087
G2 X102.491 Y138.155 I1.908 J-5.053 E.05385
G1 X99.181 Y141.464 E.15526
G1 X94.573 Y138.397 E.18364
G1 X98.495 Y134.474 E.184
G2 X98.961 Y136.023 I5.343 J-.765 E.05385
G1 X88.609 Y134.427 F36000
G1 F15476.087
G1 X89.965 Y135.329 E.05401
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.316 J-2.782 E.00843
G1 X122.456 Y130.135 E.63778
G3 X126.34 Y129.657 I5.812 J31.221 E.12989
G1 X128.408 Y127.59 E.09698
G3 X127.589 Y127.591 I-.417 J-3.828 E.02721
G1 X129.657 Y129.659 E.09702
G3 X133.534 Y130.139 I-1.94 J31.588 E.12968
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.76 J-3.091 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02426
G1 X168.093 Y133.96 E.0568
G2 X167.03 Y132.344 I-4.206 J1.608 E.06465
G3 X164.508 Y129.869 I23.145 J-26.106 E.11728
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.038 J18.155 E.18072
G1 X150.187 Y136.514 E.06839
G3 X149.39 Y134.041 I3.297 J-2.427 E.08771
G1 X127.857 Y112.508 E1.01016
G2 X128.138 Y112.507 I.133 J-2.693 E.00933
G1 X106.576 Y134.07 E1.01153
G3 X105.792 Y136.499 I-4.092 J.021 E.0861
G1 X107.252 Y137.958 E.06848
G2 X103.68 Y142.062 I21.494 J22.315 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.885 J-14.38 E.18439
G1 X100.135 Y130.842 E.2641
G3 X102.894 Y130.075 I2.47 J3.542 E.09682
G1 X120.021 Y112.948 E.80346
G1 X120.456 Y112.783 E.01543
G1 X127.253 Y119.579 E.31885
G3 X128.737 Y119.584 I.729 J4.083 E.04951
G1 X135.531 Y112.79 E.31871
G1 X135.991 Y112.966 E.01632
G1 X153.098 Y130.072 E.80252
G3 X155.847 Y130.854 I.26 J4.315 E.09665
G1 X161.265 Y125.436 E.25415
G2 X160.005 Y124.422 I-3.945 J3.611 E.05386
; CHANGE_LAYER
; Z_HEIGHT: 6.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X160.779 Y124.938 E-.35358
G1 X161.265 Y125.436 E-.2644
G1 X161.001 Y125.7 E-.14202
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
G1 X126.293 Y120.267
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X126.635 Y120.112 E.01248
G3 X127.786 Y119.863 I1.349 J3.446 E.03924
G3 X129.166 Y120.057 I.197 J3.599 E.0465
G1 X129.332 Y120.112 E.00581
G3 X126.239 Y120.295 I-1.348 J3.446 E.66521
G1 X126.5 Y120.604 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.778 Y120.478 E.00937
G3 X127.807 Y120.255 I1.206 J3.08 E.0325
G3 X129.043 Y120.429 I.176 J3.218 E.03858
G1 X129.189 Y120.478 E.00474
G3 X126.446 Y120.629 I-1.205 J3.081 E.55162
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.13861
G1 X127.113 Y120.367 E-.13389
G1 X127.457 Y120.293 E-.13389
G1 X127.807 Y120.255 E-.1339
G1 X128.16 Y120.255 E-.13391
G1 X128.384 Y120.279 E-.0858
; WIPE_END
G1 E-.04 F1800
G1 X135.339 Y123.424 Z6.8 F36000
G1 X151.716 Y130.828 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.732 Y130.819 E.0006
G3 X153.242 Y130.407 I1.707 J3.283 E.05232
G1 X153.636 Y130.407 E.01307
G3 X151.393 Y131.02 I-.197 J3.695 E.69269
G1 X151.665 Y130.859 E.01049
G1 X151.947 Y131.152 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.00969
G3 X153.263 Y130.799 I1.205 J3.08 E.0325
G1 X153.615 Y130.799 E.01083
G3 X151.893 Y131.178 I-.176 J3.303 E.58374
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.14255
G1 X152.568 Y130.911 E-.1339
G1 X152.913 Y130.837 E-.1339
G1 X153.263 Y130.799 E-.13389
G1 X153.615 Y130.799 E-.13391
G1 X153.83 Y130.822 E-.08186
; WIPE_END
G1 E-.04 F1800
G1 X146.239 Y131.623 Z6.8 F36000
G1 X99.73 Y136.529 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.501 Y136.231 E.01247
G3 X102.331 Y130.407 I3.027 J-2.129 E.2615
G1 X102.725 Y130.407 E.01307
G3 X99.772 Y136.572 I-.197 J3.695 E.48221
G1 X100.025 Y136.27 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.822 Y136.005 E.01026
G3 X102.351 Y130.799 I2.706 J-1.903 E.21654
G1 X102.704 Y130.799 E.01083
G3 X100.067 Y136.313 I-.176 J3.303 E.39917
; WIPE_START
M204 S10000
G1 X99.822 Y136.005 E-.14953
G1 X99.632 Y135.709 E-.13381
G1 X99.478 Y135.392 E-.13395
G1 X99.358 Y135.061 E-.13385
G1 X99.275 Y134.718 E-.13391
G1 X99.248 Y134.523 E-.07495
; WIPE_END
G1 E-.04 F1800
G1 X106.761 Y135.871 Z6.8 F36000
G1 X153.292 Y144.224 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.391 J1.748 E.04338
G3 X88.409 Y132.052 I2.736 J2.128 E.03251
G2 X91.148 Y129.685 I-14.518 J-19.569 E.12021
G2 X93.594 Y126.159 I-11.288 J-10.444 E.14282
G3 X94.42 Y124.708 I12.308 J6.041 E.05543
G3 X95.012 Y124.286 I1.249 J1.127 E.02431
G2 X97.525 Y123.019 I-21.475 J-45.711 E.09337
G2 X101.007 Y120.322 I-8.607 J-14.712 E.1465
G3 X102.746 Y118.697 I16.217 J15.6 E.07899
G3 X103.976 Y118.067 I2.751 J3.857 E.04602
G2 X107.048 Y116.997 I-16.532 J-52.406 E.1079
G2 X110.366 Y115.274 I-7.763 J-19.011 E.12422
G3 X112.192 Y114.201 I10.974 J16.592 E.07027
G3 X113.876 Y113.812 I2.035 J4.969 E.05758
G2 X117.401 Y113.355 I-2.347 J-31.914 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10415
G3 X122.451 Y111.606 I9.404 J20.404 E.07349
G3 X123.43 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I37.897 J-212.922 E.08022
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.883 Y111.551 I5.297 J24.86 E.07087
G3 X133.23 Y111.55 I.179 J1.839 E.01155
G3 X134.227 Y111.868 I-.724 J3.991 E.0348
G2 X137.511 Y113.104 I11.114 J-24.535 E.11648
G2 X140.702 Y113.674 I5.147 J-19.606 E.10764
G3 X143.068 Y113.961 I-1.515 J22.333 E.07911
G3 X144.642 Y114.679 I-1.436 J5.238 E.05763
G2 X148.015 Y116.604 I17.391 J-26.553 E.1289
G2 X150.332 Y117.514 I10.342 J-22.918 E.08261
G3 X152.58 Y118.307 I-6.312 J21.475 E.07912
G3 X153.961 Y119.348 I-2.379 J4.594 E.05764
G2 X156.837 Y121.957 I22.738 J-22.172 E.12889
G2 X158.902 Y123.348 I15.065 J-20.146 E.08261
G3 X161.002 Y124.67 I-9.775 J17.854 E.08237
G3 X161.85 Y125.633 I-2.913 J3.421 E.0427
G2 X163.68 Y128.324 I49.889 J-31.946 E.10796
G2 X166.202 Y131.082 I16.836 J-12.863 E.12414
G3 X167.71 Y132.567 I-14.868 J16.602 E.07023
G3 X168.522 Y134.093 I-4.097 J3.158 E.05761
G1 X168.658 Y134.455 E.01282
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.134 J2.086 E.05195
G3 X88.163 Y131.747 I2.989 J2.223 E.03456
G2 X90.863 Y129.416 I-14.315 J-19.311 E.10972
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.334 J6.053 E.05348
G3 X94.828 Y123.94 I1.545 J1.357 E.02747
G2 X97.331 Y122.678 I-21.529 J-45.824 E.08613
G2 X100.735 Y120.04 I-8.413 J-14.372 E.13271
G3 X102.511 Y118.382 I16.301 J15.686 E.07469
G3 X103.844 Y117.698 I2.998 J4.196 E.0462
G2 X106.325 Y116.856 I-155.454 J-462.45 E.08051
G2 X110.161 Y114.94 I-7.083 J-18.974 E.13198
G3 X112.029 Y113.845 I11.124 J16.833 E.06659
G3 X113.833 Y113.423 I2.199 J5.334 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.541 E.10818
G2 X120.249 Y112.069 I-3.379 J-16.162 E.09422
G3 X122.349 Y111.227 I9.365 J20.314 E.06953
G3 X123.486 Y111.206 I.614 J2.41 E.03527
G2 X125.869 Y111.616 I39.537 J-222.425 E.0743
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.314 J24.96 E.06669
G3 X133.273 Y111.159 I.213 J2.295 E.013
G3 X134.376 Y111.505 I-.758 J4.352 E.03559
G2 X137.615 Y112.726 I10.994 J-24.251 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.528 E.07473
G3 X144.845 Y114.343 I-1.517 J5.603 E.05721
G2 X148.18 Y116.248 I17.232 J-26.296 E.11809
G2 X150.457 Y117.142 I10.159 J-22.516 E.07518
G3 X152.749 Y117.953 I-6.371 J21.656 E.07474
G3 X154.232 Y119.064 I-2.556 J4.957 E.05721
G2 X157.076 Y121.646 I22.52 J-21.948 E.11811
G2 X159.105 Y123.012 I14.793 J-19.787 E.07517
G3 X161.075 Y124.23 I-11.661 J21.071 E.07121
G3 X162.173 Y125.409 I-2.912 J3.81 E.04974
G2 X163.993 Y128.088 I49.735 J-31.84 E.09951
G2 X166.471 Y130.796 I16.517 J-12.621 E.11296
G3 X168.012 Y132.318 I-14.984 J16.727 E.06657
G3 X168.887 Y133.951 I-4.411 J3.413 E.05721
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26194
; WIPE_END
G1 E-.04 F1800
G1 X155.082 Y137.807 Z6.8 F36000
G1 Z6.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X153.502 Y138.153 I-1.934 J-5.043 E.05385
G1 X156.88 Y141.53 E.15843
G1 X161.572 Y138.547 E.18446
G1 X157.475 Y134.45 E.1922
G3 X157.016 Y136.001 I-5.353 J-.74 E.05385
; WIPE_START
G1 X157.318 Y135.275 E-.29892
G1 X157.475 Y134.45 E-.31897
G1 X157.74 Y134.714 E-.14211
; WIPE_END
G1 E-.04 F1800
G1 X150.123 Y135.211 Z6.8 F36000
M73 P78 R4
G1 X145.8 Y135.493 Z6.8
G1 Z6.4
G1 E.8 F1800
G1 F15476.087
G2 X144.466 Y134.559 I-9.577 J12.262 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.356 Y119.262 I24.42 J-30.389 E.15055
G2 X152.621 Y118.728 I-2.722 J2.973 E.03021
G1 X139.447 Y131.902 E.61802
G1 X139.666 Y131.992 E.00784
G1 X131.967 Y124.294 E.36115
G1 X132.008 Y123.989 E.0102
G1 X141.856 Y114.141 E.46199
G3 X143.449 Y114.447 I-.799 J8.473 E.0539
G1 X112.541 Y114.437 F36000
G1 F15476.087
G3 X114.137 Y114.139 I2.484 J8.896 E.05391
G1 X123.954 Y123.957 E.46057
G2 X124.003 Y124.318 I1.721 J-.05 E.0121
G1 X116.349 Y131.973 E.35911
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.452 J2.768 E.02677
G3 X99.258 Y122.288 I-22.941 J-21.965 E.15409
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.885 J12.762 E.05403
G1 X100.537 Y142.367 F36000
G1 F15476.087
G1 X99.181 Y141.464 E.05401
G1 X102.491 Y138.155 E.15526
G3 X98.495 Y134.474 I.042 J-4.055 E.19745
G1 X94.573 Y138.397 E.184
G1 X89.965 Y135.329 E.18364
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.316 J-2.783 E.00843
G1 X122.456 Y130.135 E.63778
G3 X126.34 Y129.657 I5.812 J31.218 E.12989
G1 X128.408 Y127.59 E.09698
G3 X127.589 Y127.591 I-.417 J-3.828 E.02721
G1 X129.657 Y129.659 E.09702
G3 X133.534 Y130.139 I-1.94 J31.587 E.12968
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.758 J-3.088 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02426
G1 X168.093 Y133.96 E.0568
G2 X167.03 Y132.344 I-4.211 J1.611 E.06467
G3 X164.508 Y129.869 I23.138 J-26.098 E.11727
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.038 J18.155 E.18072
G1 X150.187 Y136.514 E.06839
G3 X149.39 Y134.041 I3.297 J-2.427 E.08771
G1 X127.857 Y112.508 E1.01016
G2 X128.138 Y112.507 I.133 J-2.689 E.00933
G1 X106.576 Y134.07 E1.01153
G3 X105.792 Y136.499 I-4.093 J.021 E.0861
G1 X107.252 Y137.958 E.06848
G2 X103.68 Y142.062 I21.495 J22.316 E.18071
G1 X91.467 Y129.849 E.57295
G2 X94.506 Y125.212 I-16.885 J-14.38 E.18439
G1 X100.135 Y130.842 E.2641
G3 X102.894 Y130.075 I2.47 J3.542 E.09682
G1 X120.021 Y112.948 E.80346
G1 X120.456 Y112.783 E.01543
G1 X127.253 Y119.579 E.31885
G3 X128.737 Y119.584 I.729 J4.083 E.04951
G1 X135.531 Y112.79 E.31871
G1 X135.991 Y112.965 E.01632
G1 X153.098 Y130.072 E.80252
G3 X155.847 Y130.854 I.26 J4.315 E.09665
G1 X161.265 Y125.437 E.25413
G2 X160.005 Y124.422 I-3.031 J2.474 E.05403
; CHANGE_LAYER
; Z_HEIGHT: 6.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X160.781 Y124.94 E-.35439
G1 X161.265 Y125.437 E-.26346
G1 X161 Y125.701 E-.14215
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
G1 X126.293 Y120.267
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X126.635 Y120.112 E.01247
G3 X127.786 Y119.863 I1.349 J3.447 E.03924
G3 X129.145 Y120.05 I.197 J3.594 E.04577
G1 X129.332 Y120.112 E.00654
G3 X126.239 Y120.295 I-1.348 J3.448 E.66552
G1 X126.496 Y120.606 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.778 Y120.478 E.00952
G3 X127.807 Y120.255 I1.206 J3.083 E.0325
G3 X129.022 Y120.422 I.176 J3.213 E.0379
G1 X129.189 Y120.478 E.00541
G3 X126.442 Y120.632 I-1.205 J3.083 E.55182
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.14053
G1 X127.113 Y120.367 E-.1339
G1 X127.457 Y120.293 E-.13389
G1 X127.807 Y120.255 E-.13389
G1 X128.16 Y120.255 E-.13391
G1 X128.379 Y120.279 E-.08387
; WIPE_END
G1 E-.04 F1800
G1 X135.337 Y123.415 Z7 F36000
G1 X151.749 Y130.812 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.091 Y130.656 E.01247
G3 X153.242 Y130.407 I1.348 J3.449 E.03924
G1 X153.636 Y130.407 E.01307
G3 X151.695 Y130.839 I-.197 J3.698 E.70499
G1 X151.942 Y131.154 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.00986
G3 X153.263 Y130.799 I1.205 J3.083 E.0325
G1 X153.615 Y130.799 E.01083
G3 X151.888 Y131.181 I-.176 J3.306 E.58406
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.14467
G1 X152.568 Y130.911 E-.1339
G1 X152.913 Y130.837 E-.1339
G1 X153.263 Y130.799 E-.13389
G1 X153.615 Y130.799 E-.13391
G1 X153.824 Y130.822 E-.07973
; WIPE_END
G1 E-.04 F1800
G1 X146.234 Y131.627 Z7 F36000
G1 X99.754 Y136.556 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.744 Y136.54 E.00062
G3 X102.331 Y130.407 I2.783 J-2.438 E.27457
G1 X102.725 Y130.407 E.01307
G3 X100.019 Y136.822 I-.197 J3.695 E.47052
G1 X99.796 Y136.599 E.01047
G1 X100.027 Y136.273 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.822 Y136.005 E.01035
G3 X102.351 Y130.799 I2.706 J-1.903 E.21654
G1 X102.704 Y130.799 E.01083
G3 X100.069 Y136.315 I-.176 J3.303 E.39909
; WIPE_START
M204 S10000
G1 X99.822 Y136.005 E-.15052
G1 X99.632 Y135.709 E-.13381
G1 X99.478 Y135.392 E-.13395
G1 X99.358 Y135.061 E-.13385
G1 X99.275 Y134.718 E-.13391
G1 X99.249 Y134.525 E-.07396
; WIPE_END
G1 E-.04 F1800
G1 X106.761 Y135.874 Z7 F36000
G1 X153.292 Y144.224 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98336
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.389 J1.747 E.04339
G3 X88.409 Y132.052 I2.737 J2.128 E.0325
G2 X91.148 Y129.685 I-14.52 J-19.571 E.12022
G2 X93.594 Y126.16 I-11.286 J-10.443 E.14278
G3 X94.42 Y124.708 I12.319 J6.046 E.05547
G3 X95.012 Y124.286 I1.249 J1.126 E.02431
G2 X97.525 Y123.019 I-21.497 J-45.754 E.09336
G2 X101.007 Y120.323 I-8.607 J-14.712 E.14647
G3 X102.746 Y118.696 I16.214 J15.596 E.07903
G3 X103.976 Y118.067 I2.75 J3.855 E.04599
G2 X107.048 Y116.997 I-16.551 J-52.462 E.10792
G2 X110.366 Y115.274 I-7.763 J-19.009 E.12422
G3 X112.192 Y114.202 I10.97 J16.584 E.07025
G3 X113.876 Y113.812 I2.035 J4.968 E.0576
G2 X117.401 Y113.355 I-2.348 J-31.922 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10415
G3 X122.451 Y111.606 I9.4 J20.396 E.07349
G3 X123.43 Y111.594 I.513 J2.043 E.03278
G2 X125.813 Y112.005 I37.996 J-213.5 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.883 Y111.551 I5.294 J24.848 E.07088
G3 X133.234 Y111.55 I.18 J1.85 E.01168
G3 X134.227 Y111.868 I-.745 J4.039 E.03467
G2 X137.511 Y113.104 I11.112 J-24.531 E.11648
G2 X140.702 Y113.674 I5.146 J-19.604 E.10764
G3 X143.068 Y113.961 I-1.514 J22.328 E.07911
G3 X144.643 Y114.679 I-1.435 J5.236 E.05765
G2 X148.015 Y116.604 I17.392 J-26.555 E.12888
G2 X151.656 Y117.949 I12.729 J-28.86 E.12885
G3 X153.297 Y118.757 I-1.46 J5.033 E.06098
G3 X154.769 Y120.137 I-13.778 J16.163 E.06695
G2 X158.902 Y123.348 I14.664 J-14.614 E.17407
G3 X160.841 Y124.544 I-11.511 J20.821 E.07562
G3 X161.85 Y125.633 I-2.666 J3.485 E.04947
G2 X163.68 Y128.324 I49.867 J-31.93 E.10796
G2 X166.202 Y131.082 I16.836 J-12.864 E.12414
G3 X167.71 Y132.567 I-14.881 J16.616 E.07023
G3 X168.522 Y134.094 I-4.096 J3.158 E.05763
G1 X168.658 Y134.455 E.0128
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.795 E1.86584
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.133 J2.085 E.05195
G3 X88.163 Y131.747 I2.99 J2.224 E.03456
G2 X90.863 Y129.416 I-14.314 J-19.311 E.10971
G2 X93.249 Y125.974 I-11.005 J-10.177 E.1291
G3 X94.112 Y124.464 I12.34 J6.056 E.05348
G3 X94.828 Y123.94 I1.545 J1.357 E.02748
G2 X97.331 Y122.678 I-21.522 J-45.811 E.08613
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13271
G3 X102.511 Y118.382 I16.292 J15.675 E.0747
G3 X103.843 Y117.698 I2.997 J4.195 E.04618
G2 X106.326 Y116.856 I-156.913 J-466.738 E.08053
G2 X110.161 Y114.94 I-7.083 J-18.974 E.13198
G3 X112.029 Y113.845 I11.129 J16.84 E.06657
G3 X113.833 Y113.423 I2.2 J5.333 E.0572
G2 X117.323 Y112.971 I-2.309 J-31.546 E.10818
G2 X120.249 Y112.069 I-3.378 J-16.16 E.09422
G3 X122.349 Y111.227 I9.358 J20.297 E.06954
G3 X123.486 Y111.206 I.613 J2.41 E.03526
G2 X125.869 Y111.616 I39.581 J-222.68 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.312 J24.948 E.0667
G3 X133.275 Y111.159 I.213 J2.294 E.01304
G3 X134.376 Y111.505 I-.765 J4.366 E.03554
G2 X137.615 Y112.726 I10.993 J-24.249 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.525 E.07473
G3 X144.845 Y114.343 I-1.516 J5.601 E.05721
G2 X148.18 Y116.248 I17.231 J-26.295 E.11809
G2 X151.783 Y117.578 I12.594 J-28.583 E.11809
G3 X153.54 Y118.449 I-1.579 J5.391 E.06057
G3 X155.042 Y119.856 I-13.987 J16.433 E.06324
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.23 I-11.654 J21.061 E.0712
G3 X162.172 Y125.409 I-2.912 J3.81 E.04974
G2 X163.993 Y128.088 I49.747 J-31.848 E.09952
G2 X166.471 Y130.796 I16.518 J-12.623 E.11296
G3 X168.012 Y132.317 I-14.993 J16.737 E.06656
G3 X168.887 Y133.951 I-4.41 J3.413 E.05723
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26194
; WIPE_END
G1 E-.04 F1800
G1 X156.448 Y136.817 Z7 F36000
G1 X157.016 Y136.001 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X157.475 Y134.45 I-4.894 J-2.291 E.05385
G1 X161.572 Y138.547 E.1922
G1 X156.88 Y141.53 E.18446
G1 X153.502 Y138.153 E.15843
G2 X155.082 Y137.807 I-.354 J-5.39 E.05385
; WIPE_START
G1 X154.296 Y138.065 E-.31457
G1 X153.502 Y138.153 E-.30332
G1 X153.767 Y138.418 E-.14211
; WIPE_END
G1 E-.04 F1800
G1 X150.749 Y131.407 Z7 F36000
G1 X143.449 Y114.447 Z7
G1 Z6.6
G1 E.8 F1800
G1 F15476.087
G2 X141.856 Y114.141 I-2.394 J8.179 E.0539
G1 X132.008 Y123.989 E.46198
M73 P78 R3
G1 X131.967 Y124.294 E.0102
G1 X139.666 Y131.992 E.36115
G1 X139.447 Y131.902 E.00784
G1 X152.621 Y118.728 E.61802
G3 X153.357 Y119.262 I-1.989 J3.51 E.03022
G2 X156.721 Y122.304 I27.79 J-27.353 E.15054
G1 X144.466 Y134.559 E.57489
G3 X145.8 Y135.493 I-8.242 J13.194 E.05403
; WIPE_START
G1 X144.466 Y134.559 E-.61864
G1 X144.729 Y134.296 E-.14136
; WIPE_END
G1 E-.04 F1800
G1 X137.098 Y134.15 Z7 F36000
G1 X112.9 Y133.689 Z7
G1 Z6.6
G1 E.8 F1800
G1 F15476.087
G2 X111.517 Y134.548 I7.502 J13.621 E.05403
G1 X99.258 Y122.288 E.57511
G2 X102.704 Y119.18 I-19.497 J-25.075 E.15408
G3 X103.362 Y118.717 I2.111 J2.305 E.02678
G1 X116.539 Y131.894 E.61815
G1 X116.349 Y131.973 E.00685
G1 X124.003 Y124.318 E.35911
G3 X123.954 Y123.957 I1.66 J-.409 E.0121
G1 X114.137 Y114.139 E.46057
G2 X112.541 Y114.437 I.888 J9.194 E.05391
G1 X93.176 Y127.618 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G3 X91.484 Y129.851 I-12.061 J-7.379 E.07774
; Slow Down End
G1 X88.609 Y134.427 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X89.965 Y135.329 E.05401
G1 X108.636 Y116.657 E.87592
G2 X108.861 Y116.54 I-1.314 J-2.778 E.00843
G1 X122.456 Y130.135 E.63778
G3 X126.34 Y129.657 I5.812 J31.221 E.12989
G1 X128.408 Y127.59 E.09698
G3 X127.589 Y127.591 I-.417 J-3.828 E.02721
G1 X129.657 Y129.659 E.09702
G3 X133.534 Y130.139 I-1.94 J31.584 E.12968
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.758 J-3.088 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02425
G1 X168.093 Y133.96 E.0568
G2 X167.03 Y132.344 I-4.208 J1.609 E.06465
G3 X164.508 Y129.869 I23.14 J-26.101 E.11728
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-26.595 J19.508 E.18069
G1 X150.187 Y136.514 E.06839
G3 X149.39 Y134.041 I3.297 J-2.427 E.08771
G1 X127.857 Y112.508 E1.01016
G2 X128.138 Y112.507 I.133 J-2.689 E.00933
G1 X106.576 Y134.07 E1.01153
G3 X105.792 Y136.499 I-4.093 J.021 E.0861
G1 X107.252 Y137.958 E.06848
G2 X103.68 Y142.062 I21.495 J22.316 E.18071
G1 X91.734 Y130.116 E.5604
G2 X93.631 Y127.564 I-13.875 J-12.295 E.10562
G1 X93.356 Y127.289 E.01292
G2 X94.506 Y125.212 I-99.994 J-56.724 E.07875
G1 X100.135 Y130.842 E.2641
G3 X102.894 Y130.075 I2.47 J3.542 E.09682
G1 X120.021 Y112.948 E.80346
G1 X120.456 Y112.783 E.01543
G1 X127.253 Y119.579 E.31885
G3 X128.737 Y119.584 I.729 J4.083 E.04951
G1 X135.531 Y112.79 E.31871
G1 X135.991 Y112.965 E.01632
M73 P79 R3
G1 X153.098 Y130.072 E.80252
G3 X155.847 Y130.854 I.26 J4.315 E.09665
G1 X161.265 Y125.437 E.25413
G2 X160.005 Y124.422 I-3.029 J2.471 E.05403
; WIPE_START
G1 X160.782 Y124.94 E-.35477
G1 X161.265 Y125.437 E-.26308
G1 X161 Y125.701 E-.14215
; WIPE_END
G1 E-.04 F1800
G1 X153.518 Y127.21 Z7 F36000
G1 X100.909 Y137.816 Z7
G1 Z6.6
G1 E.8 F1800
G1 F15476.087
G2 X102.491 Y138.155 I1.908 J-5.053 E.05385
G1 X99.181 Y141.464 E.15527
G1 X94.573 Y138.397 E.18364
G1 X98.159 Y134.81 E.16825
G3 X98.199 Y133.192 I5.998 J-.664 E.05384
G1 X98.529 Y134.773 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X98.475 Y134.013 E.02112
G1 X98.586 Y133.158 E.02388
G1 X98.749 Y132.639 E.01508
; Slow Down End
; CHANGE_LAYER
; Z_HEIGHT: 6.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X98.586 Y133.158 E-.20684
G1 X98.475 Y134.013 E-.32746
G1 X98.517 Y134.605 E-.22569
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
G1 X126.293 Y120.267
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X126.635 Y120.112 E.01246
G3 X127.786 Y119.863 I1.348 J3.446 E.03924
G3 X126.657 Y127.013 I.198 J3.695 E.43718
G3 X126.239 Y120.294 I1.326 J-3.455 E.2804
G1 X126.491 Y120.608 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.778 Y120.478 E.00967
G3 X127.807 Y120.255 I1.205 J3.08 E.0325
G1 X128.16 Y120.255 E.01083
G3 X126.437 Y120.634 I-.176 J3.303 E.58379
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.14241
G1 X127.113 Y120.367 E-.1339
G1 X127.457 Y120.293 E-.13389
G1 X127.807 Y120.255 E-.13389
G1 X128.16 Y120.255 E-.13391
G1 X128.374 Y120.278 E-.08199
; WIPE_END
G1 E-.04 F1800
G1 X135.333 Y123.414 Z7.2 F36000
G1 X151.749 Y130.811 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.091 Y130.656 E.01246
G3 X153.242 Y130.407 I1.348 J3.446 E.03924
G1 X153.636 Y130.407 E.01307
G3 X151.695 Y130.839 I-.197 J3.695 E.70439
G1 X151.937 Y131.157 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.01002
G3 X153.263 Y130.799 I1.205 J3.08 E.0325
G1 X153.615 Y130.799 E.01083
G3 X151.883 Y131.184 I-.176 J3.303 E.5834
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.14669
G1 X152.568 Y130.911 E-.13391
G1 X152.913 Y130.837 E-.1339
G1 X153.263 Y130.799 E-.13389
G1 X153.615 Y130.799 E-.13391
G1 X153.819 Y130.821 E-.07771
; WIPE_END
G1 E-.04 F1800
G1 X146.228 Y131.622 Z7.2 F36000
G1 X99.729 Y136.529 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.501 Y136.231 E.01246
G3 X102.331 Y130.407 I3.027 J-2.129 E.2615
G1 X102.725 Y130.407 E.01307
G3 X99.772 Y136.571 I-.197 J3.695 E.48221
G1 X100.028 Y136.275 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.822 Y136.005 E.01043
G3 X102.351 Y130.799 I2.706 J-1.903 E.21655
G1 X102.704 Y130.799 E.01083
G3 X100.07 Y136.317 I-.176 J3.303 E.39901
; WIPE_START
M204 S10000
G1 X99.822 Y136.005 E-.15148
G1 X99.632 Y135.709 E-.13382
G1 X99.478 Y135.392 E-.13395
G1 X99.358 Y135.061 E-.13385
G1 X99.275 Y134.718 E-.13391
G1 X99.249 Y134.528 E-.073
; WIPE_END
G1 E-.04 F1800
G1 X106.762 Y135.876 Z7.2 F36000
G1 X153.292 Y144.224 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98336
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.224 J1.693 E.04339
G3 X88.408 Y132.052 I2.738 J2.13 E.03249
G2 X91.148 Y129.685 I-14.516 J-19.567 E.12023
G2 X93.594 Y126.159 I-11.288 J-10.444 E.14281
G3 X94.42 Y124.708 I12.317 J6.045 E.05543
G3 X95.012 Y124.286 I1.249 J1.126 E.02432
G2 X97.525 Y123.019 I-21.48 J-45.721 E.09336
G2 X101.007 Y120.323 I-8.606 J-14.711 E.14647
G3 X102.746 Y118.697 I16.22 J15.602 E.07902
G3 X103.976 Y118.067 I2.75 J3.855 E.04602
G2 X107.048 Y116.997 I-16.527 J-52.392 E.1079
G2 X110.366 Y115.274 I-7.763 J-19.009 E.12422
G3 X112.192 Y114.201 I10.965 J16.575 E.07027
G3 X113.876 Y113.812 I2.035 J4.969 E.05757
G2 X117.401 Y113.355 I-2.348 J-31.918 E.11797
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10417
G3 X122.452 Y111.606 I9.389 J20.37 E.07348
G3 X123.43 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I37.945 J-213.199 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.883 Y111.551 I5.297 J24.863 E.07087
G3 X133.236 Y111.55 I.18 J1.849 E.01174
G3 X134.227 Y111.868 I-.763 J4.087 E.03462
G2 X137.511 Y113.104 I11.113 J-24.532 E.11648
G2 X140.701 Y113.674 I5.147 J-19.608 E.10762
G3 X143.068 Y113.961 I-1.514 J22.334 E.07913
G3 X144.642 Y114.679 I-1.435 J5.236 E.05763
G2 X148.015 Y116.604 I17.39 J-26.551 E.1289
G2 X150.332 Y117.514 I10.343 J-22.919 E.08261
G3 X152.58 Y118.307 I-6.31 J21.469 E.07911
G3 X153.961 Y119.348 I-2.378 J4.594 E.05765
G2 X156.837 Y121.957 I22.736 J-22.17 E.12889
G2 X158.902 Y123.348 I15.071 J-20.154 E.08262
G3 X161.003 Y124.67 I-9.765 J17.839 E.08238
G3 X161.851 Y125.634 I-2.914 J3.421 E.04273
G2 X163.679 Y128.323 I49.855 J-31.923 E.10789
G2 X166.202 Y131.082 I16.838 J-12.864 E.12417
G3 X167.71 Y132.567 I-14.87 J16.604 E.07022
G3 X168.522 Y134.093 I-4.095 J3.158 E.05761
G1 X168.658 Y134.455 E.01281
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.793 E1.86587
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I8.996 J2.041 E.05196
G3 X88.163 Y131.747 I2.99 J2.225 E.03456
G2 X90.863 Y129.416 I-14.314 J-19.31 E.10971
G2 X93.249 Y125.974 I-11.006 J-10.178 E.1291
G3 X94.112 Y124.464 I12.345 J6.059 E.05347
G3 X94.828 Y123.94 I1.545 J1.357 E.02749
G2 X97.331 Y122.678 I-21.52 J-45.805 E.08613
G2 X100.735 Y120.04 I-8.414 J-14.374 E.13271
G3 X102.511 Y118.382 I16.295 J15.679 E.07469
G3 X103.844 Y117.698 I2.997 J4.195 E.0462
G2 X106.325 Y116.856 I-155.403 J-462.3 E.08051
G2 X110.161 Y114.94 I-7.083 J-18.975 E.13198
G3 X112.029 Y113.845 I11.115 J16.818 E.06659
G3 X113.833 Y113.423 I2.199 J5.334 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.543 E.10818
G2 X120.25 Y112.069 I-3.379 J-16.163 E.09423
G3 X122.349 Y111.227 I9.351 J20.28 E.06953
G3 X123.486 Y111.206 I.613 J2.411 E.03526
G2 X125.869 Y111.616 I39.514 J-222.289 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.314 J24.959 E.06669
G3 X133.275 Y111.159 I.213 J2.291 E.01306
G3 X134.376 Y111.505 I-.784 J4.424 E.03553
G2 X137.615 Y112.726 I10.994 J-24.251 E.10646
G2 X140.743 Y113.284 I5.04 J-19.215 E.09773
G3 X143.156 Y113.579 I-1.533 J22.525 E.07474
G3 X144.845 Y114.343 I-1.516 J5.602 E.05719
G2 X148.18 Y116.248 I17.232 J-26.295 E.11811
G2 X150.457 Y117.142 I10.159 J-22.517 E.07518
G3 X152.749 Y117.953 I-6.37 J21.652 E.07474
G3 X154.232 Y119.064 I-2.555 J4.957 E.05721
G2 X157.076 Y121.646 I22.52 J-21.948 E.11811
G2 X159.105 Y123.012 I14.797 J-19.793 E.07517
G3 X161.075 Y124.229 I-11.661 J21.073 E.07119
G3 X162.173 Y125.409 I-2.911 J3.809 E.04975
G2 X163.992 Y128.087 I49.789 J-31.876 E.0995
G2 X166.471 Y130.796 I16.518 J-12.622 E.11298
G3 X168.012 Y132.318 I-14.985 J16.729 E.06657
G3 X168.887 Y133.951 I-4.41 J3.413 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26194
; WIPE_END
G1 E-.04 F1800
G1 X155.082 Y137.807 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X153.502 Y138.153 I-1.934 J-5.043 E.05385
G1 X156.88 Y141.53 E.15843
G1 X161.572 Y138.547 E.18446
G1 X157.475 Y134.45 E.1922
G3 X157.016 Y136.001 I-5.354 J-.741 E.05385
; WIPE_START
G1 X157.318 Y135.275 E-.29892
G1 X157.475 Y134.45 E-.31897
G1 X157.74 Y134.714 E-.14211
; WIPE_END
G1 E-.04 F1800
G1 X150.123 Y135.211 Z7.2 F36000
G1 X145.8 Y135.493 Z7.2
G1 Z6.8
G1 E.8 F1800
G1 F15476.087
G2 X144.466 Y134.559 I-9.578 J12.264 E.05403
G1 X156.721 Y122.304 E.57489
G3 X153.356 Y119.262 I24.425 J-30.394 E.15055
G2 X152.621 Y118.728 I-2.721 J2.971 E.03021
G1 X139.447 Y131.902 E.61802
G1 X139.666 Y131.992 E.00784
G1 X131.967 Y124.294 E.36115
G1 X132.008 Y123.989 E.0102
G1 X141.856 Y114.141 E.46198
G3 X143.449 Y114.447 I-.799 J8.476 E.0539
G1 X160.005 Y124.422 F36000
G1 F15476.087
G3 X161.264 Y125.437 I-2.417 J4.286 E.05389
G1 X155.847 Y130.854 E.25411
G2 X153.098 Y130.072 I-2.49 J3.534 E.09665
G1 X135.991 Y112.966 E.80252
G1 X135.531 Y112.79 E.01632
G1 X128.737 Y119.584 E.31871
G2 X127.253 Y119.579 I-.756 J4.078 E.04951
G1 X120.456 Y112.783 E.31885
G1 X120.021 Y112.948 E.01543
G1 X102.894 Y130.075 E.80346
G2 X100.135 Y130.842 I-.289 J4.308 E.09682
G1 X94.506 Y125.212 E.2641
G3 X93.356 Y127.289 I-100.91 J-54.514 E.07875
G1 X95.253 Y129.186 E.08901
G1 X95.571 Y128.868 E.01493
G1 X95.998 Y129.295 E.02003
G1 X108.636 Y116.657 E.59286
G2 X108.861 Y116.54 I-1.314 J-2.779 E.00843
G1 X122.456 Y130.135 E.63779
G3 X126.34 Y129.657 I5.812 J31.221 E.12989
G1 X128.408 Y127.59 E.09698
G3 X127.589 Y127.591 I-.417 J-3.828 E.02721
G1 X129.657 Y129.659 E.09702
G3 X133.534 Y130.139 I-1.94 J31.588 E.12968
G1 X147.124 Y116.549 E.63753
G2 X147.385 Y116.684 I1.758 J-3.088 E.00975
G1 X166.265 Y135.564 E.88568
G1 X166.882 Y135.171 E.02426
G1 X168.093 Y133.96 E.0568
G2 X167.031 Y132.345 I-4.208 J1.609 E.06465
G3 X164.508 Y129.869 I23.156 J-26.117 E.11729
G1 X152.298 Y142.079 E.57279
G2 X148.729 Y137.972 I-25.037 J18.155 E.18072
G1 X150.187 Y136.514 E.06839
G3 X149.39 Y134.041 I3.297 J-2.427 E.08771
G1 X127.857 Y112.508 E1.01016
G2 X128.138 Y112.507 I.133 J-2.689 E.00933
G1 X106.576 Y134.07 E1.01153
G3 X105.792 Y136.499 I-4.093 J.02 E.0861
G1 X107.252 Y137.958 E.06848
G2 X103.68 Y142.062 I21.491 J22.313 E.18071
G1 X97.72 Y136.103 E.27957
G1 X96.634 Y137.189 E.05097
G1 X96.207 Y136.762 E.02003
G1 X94.573 Y138.397 E.07667
G1 X99.181 Y141.464 E.18364
G1 X102.491 Y138.155 E.15526
G3 X100.909 Y137.816 I.326 J-5.392 E.05385
; WIPE_START
G1 X101.671 Y138.065 E-.30454
G1 X102.491 Y138.155 E-.31334
G1 X102.226 Y138.419 E-.14211
; WIPE_END
G1 E-.04 F1800
G1 X97.648 Y132.312 Z7.2 F36000
G1 X95.42 Y129.339 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.42251
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X98.721 Y132.64 E.26666
G2 X98.568 Y133.155 I7.628 J2.552 E.03069
G1 X93.129 Y127.717 E.43933
G1 X92.863 Y128.118 E.02754
G1 X98.477 Y133.733 E.45355
G2 X98.466 Y134.39 I3.073 J.379 E.03764
G1 X92.589 Y128.513 E.47479
G1 X92.304 Y128.896 E.02728
G1 X98.313 Y134.905 E.4854
G1 X97.978 Y135.239 E.02699
G1 X92.002 Y129.262 E.4828
G1 X91.692 Y129.621 E.02706
G1 X97.644 Y135.573 E.48084
G1 X97.31 Y135.907 E.02699
G1 X93.225 Y131.821 E.33006
G1 X92.89 Y132.155 E.02699
G1 X96.976 Y136.241 E.33006
G1 X96.642 Y136.575 E.02699
G1 X92.413 Y132.346 E.34163
G1 X92.667 Y131.773 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
; LAYER_HEIGHT: 0.2
G1 F15476.087
G1 X91.942 Y132.497 E.03399
G1 X92.369 Y132.924 E.02003
G1 X89.965 Y135.329 E.1128
G1 X88.609 Y134.427 E.05401
G1 X112.541 Y114.437 F36000
G1 F15476.087
G3 X114.137 Y114.139 I2.485 J8.901 E.05391
G1 X123.954 Y123.957 E.46057
G2 X124.003 Y124.318 I1.721 J-.05 E.0121
G1 X116.349 Y131.973 E.35911
G1 X116.539 Y131.894 E.00685
G1 X103.362 Y118.717 E.61815
G2 X102.704 Y119.18 I1.449 J2.764 E.02677
G3 X99.258 Y122.288 I-22.947 J-21.971 E.15409
G1 X111.517 Y134.548 E.57511
G3 X112.9 Y133.689 I8.885 J12.762 E.05403
; CHANGE_LAYER
; Z_HEIGHT: 7
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X111.517 Y134.548 E-.61868
G1 X111.254 Y134.285 E-.14132
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
G1 X126.414 Y120.212
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X126.635 Y120.112 E.00804
G3 X127.786 Y119.863 I1.348 J3.446 E.03924
G3 X126.678 Y127.021 I.195 J3.695 E.43627
G3 X126.276 Y120.275 I1.305 J-3.462 E.28251
G1 X126.36 Y120.237 E.00305
G1 X126.479 Y120.623 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.576 Y120.565 E.00346
G3 X127.807 Y120.255 I1.408 J2.994 E.03927
G1 X128.16 Y120.255 E.01083
G3 X126.154 Y120.803 I-.176 J3.303 E.57367
G1 X126.427 Y120.652 E.00958
; WIPE_START
M204 S10000
G1 X126.576 Y120.565 E-.06553
G1 X126.778 Y120.478 E-.0837
G1 X127.113 Y120.367 E-.1339
G1 X127.457 Y120.293 E-.1339
M73 P80 R3
G1 X127.807 Y120.255 E-.13389
G1 X128.16 Y120.255 E-.13391
G1 X128.356 Y120.276 E-.07516
; WIPE_END
G1 E-.04 F1800
G1 X135.312 Y123.418 Z7.4 F36000
G1 X151.716 Y130.829 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.732 Y130.819 E.00062
G3 X153.242 Y130.407 I1.707 J3.283 E.05232
G1 X153.636 Y130.407 E.01307
G3 X151.393 Y131.02 I-.197 J3.695 E.69271
G1 X151.664 Y130.859 E.01046
G1 X151.932 Y131.159 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.01019
G3 X153.263 Y130.799 I1.205 J3.08 E.0325
G1 X153.615 Y130.799 E.01083
G3 X151.878 Y131.186 I-.176 J3.303 E.58326
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.14873
G1 X152.568 Y130.911 E-.1339
G1 X152.913 Y130.837 E-.1339
G1 X153.263 Y130.799 E-.13389
G1 X153.615 Y130.799 E-.13391
G1 X153.814 Y130.82 E-.07568
; WIPE_END
G1 E-.04 F1800
G1 X146.224 Y131.626 Z7.4 F36000
G1 X99.754 Y136.557 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.744 Y136.54 E.00063
G3 X102.331 Y130.407 I2.783 J-2.438 E.27457
G1 X102.725 Y130.407 E.01308
G3 X100.019 Y136.822 I-.197 J3.695 E.47052
G1 X99.796 Y136.599 E.01046
G1 X100.03 Y136.277 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.822 Y136.005 E.01051
G3 X102.351 Y130.799 I2.706 J-1.903 E.21654
G1 X102.704 Y130.799 E.01083
G3 X100.072 Y136.319 I-.176 J3.303 E.39894
; WIPE_START
M204 S10000
G1 X99.822 Y136.005 E-.1524
G1 X99.632 Y135.709 E-.13382
G1 X99.478 Y135.392 E-.13391
G1 X99.358 Y135.061 E-.13391
G1 X99.275 Y134.718 E-.13388
G1 X99.249 Y134.53 E-.07208
; WIPE_END
G1 E-.04 F1800
G1 X106.762 Y135.878 Z7.4 F36000
G1 X153.292 Y144.224 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.821 J16.119 E1.98368
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.247 J1.7 E.04339
G3 X88.409 Y132.052 I2.736 J2.128 E.03251
G2 X91.148 Y129.685 I-14.519 J-19.57 E.12021
G2 X93.594 Y126.16 I-11.288 J-10.443 E.14278
G3 X94.42 Y124.708 I12.321 J6.047 E.05546
G3 X95.012 Y124.286 I1.249 J1.126 E.02431
G2 X97.525 Y123.019 I-21.485 J-45.73 E.09336
G2 X101.007 Y120.323 I-8.607 J-14.712 E.14649
G3 X102.746 Y118.696 I16.208 J15.591 E.07902
G3 X103.976 Y118.067 I2.75 J3.856 E.04601
G2 X107.048 Y116.997 I-16.55 J-52.456 E.1079
G2 X110.366 Y115.274 I-7.763 J-19.01 E.12421
G3 X112.192 Y114.201 I10.965 J16.576 E.07027
G3 X113.876 Y113.812 I2.035 J4.968 E.05758
G2 X117.401 Y113.355 I-2.347 J-31.911 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10417
G3 X122.451 Y111.606 I9.402 J20.399 E.07346
G3 X123.43 Y111.594 I.514 J2.043 E.03279
G2 X125.813 Y112.005 I37.875 J-212.794 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16541
G3 X132.883 Y111.551 I5.296 J24.858 E.07087
G3 X133.236 Y111.55 I.18 J1.844 E.01174
G3 X134.227 Y111.868 I-.762 J4.085 E.03462
G2 X137.511 Y113.104 I11.112 J-24.531 E.11648
G2 X140.702 Y113.674 I5.147 J-19.605 E.10764
G3 X143.068 Y113.961 I-1.515 J22.334 E.07911
G3 X144.643 Y114.679 I-1.437 J5.239 E.05765
G2 X148.015 Y116.604 I17.387 J-26.547 E.12887
G2 X151.658 Y117.949 I12.736 J-28.877 E.12893
G3 X153.297 Y118.757 I-1.46 J5.03 E.0609
G3 X154.769 Y120.137 I-13.763 J16.148 E.06698
G2 X158.902 Y123.348 I14.663 J-14.613 E.17408
G3 X161.004 Y124.671 I-9.762 J17.833 E.08242
G3 X161.85 Y125.632 I-2.916 J3.422 E.04264
G2 X163.68 Y128.324 I49.896 J-31.95 E.10797
G2 X166.202 Y131.082 I16.841 J-12.868 E.12414
G3 X167.71 Y132.568 I-14.869 J16.603 E.07025
G3 X168.522 Y134.094 I-4.097 J3.158 E.05761
G1 X168.658 Y134.455 E.0128
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.802 E1.86569
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.015 J2.047 E.05195
G3 X88.163 Y131.747 I2.988 J2.223 E.03457
G2 X90.863 Y129.416 I-14.313 J-19.309 E.1097
G2 X93.249 Y125.974 I-11.006 J-10.178 E.12911
G3 X94.112 Y124.464 I12.339 J6.056 E.05348
G3 X94.828 Y123.94 I1.545 J1.358 E.02748
G2 X97.331 Y122.678 I-21.528 J-45.823 E.08612
G2 X100.735 Y120.04 I-8.414 J-14.374 E.13271
G3 X102.512 Y118.382 I16.291 J15.675 E.07471
G3 X103.844 Y117.698 I2.997 J4.195 E.04618
G2 X106.325 Y116.856 I-155.838 J-463.573 E.08052
G2 X110.16 Y114.94 I-7.083 J-18.974 E.13197
G3 X112.029 Y113.845 I11.125 J16.834 E.06659
G3 X113.833 Y113.423 I2.199 J5.332 E.05718
G2 X117.323 Y112.971 I-2.308 J-31.538 E.10817
G2 X120.25 Y112.069 I-3.378 J-16.162 E.09424
G3 X122.348 Y111.227 I9.362 J20.307 E.06951
G3 X123.486 Y111.206 I.614 J2.41 E.03528
G2 X125.869 Y111.616 I39.556 J-222.535 E.07429
G2 X130.711 Y111.521 I2.13 J-14.775 E.14949
G3 X132.851 Y111.16 I5.313 J24.955 E.0667
G3 X133.275 Y111.159 I.213 J2.287 E.01306
G3 X134.376 Y111.505 I-.784 J4.424 E.03553
G2 X137.615 Y112.726 I10.994 J-24.251 E.10646
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.526 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.05721
G2 X148.181 Y116.248 I17.227 J-26.287 E.1181
G2 X151.784 Y117.578 I12.596 J-28.589 E.1181
G3 X153.54 Y118.449 I-1.58 J5.391 E.06053
G3 X155.042 Y119.856 I-13.97 J16.417 E.06327
G2 X159.105 Y123.012 I14.387 J-14.328 E.1585
G3 X161.075 Y124.23 I-11.649 J21.052 E.07121
G3 X162.172 Y125.409 I-2.911 J3.809 E.04973
G2 X163.993 Y128.088 I49.761 J-31.857 E.09953
G2 X166.471 Y130.797 I16.52 J-12.624 E.11296
G3 X168.012 Y132.318 I-14.982 J16.725 E.06658
G3 X168.887 Y133.951 I-4.411 J3.413 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26194
; WIPE_END
G1 E-.04 F1800
G1 X155.84 Y136.436 Z7.4 F36000
G1 X157.458 Y133.567 Z7.4
G1 Z7
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.382948
G1 F3000;_EXTRUDE_SET_SPEED
G1 X157.481 Y134.428 E.02389
G1 X157.321 Y135.275 E.02388
G1 X156.986 Y136.07 E.02388
G1 X156.489 Y136.777 E.02395
G1 X156.095 Y137.173 E.01548
G1 X155.488 Y137.615 E.02082
G1 X154.7 Y137.969 E.02394
G1 X153.854 Y138.148 E.02395
G1 X152.991 Y138.144 E.02393
G1 X152.147 Y137.958 E.02395
G1 X151.362 Y137.599 E.02392
G1 X150.88 Y137.256 E.01637
G1 X150.369 Y136.769 E.01957
G1 X149.876 Y136.06 E.02394
G1 X149.543 Y135.262 E.02394
G1 X149.387 Y134.412 E.02394
G1 X149.413 Y133.549 E.02394
G1 X149.622 Y132.71 E.02394
G1 X150.003 Y131.935 E.02394
G1 X150.539 Y131.257 E.02394
G1 X151.207 Y130.709 E.02394
G1 X151.975 Y130.313 E.02394
G1 X152.809 Y130.09 E.02394
G1 X153.672 Y130.047 E.02394
G1 X154.525 Y130.188 E.02394
G1 X155.328 Y130.506 E.02394
G1 X156.046 Y130.985 E.02391
G1 X156.448 Y131.388 E.01577
G1 X156.876 Y131.953 E.01964
G1 X157.253 Y132.729 E.02391
G1 X157.444 Y133.508 E.02222
; Slow Down End
; WIPE_START
G1 X157.253 Y132.729 E-.3047
G1 X156.876 Y131.953 E-.32793
G1 X156.674 Y131.686 E-.12737
; WIPE_END
G1 E-.04 F1800
G1 X149.435 Y129.267 Z7.4 F36000
G1 X132.037 Y123.453 Z7.4
G1 Z7
G1 E.8 F1800
; Slow Down Start
; LINE_WIDTH: 0.382978
G1 F3000;_EXTRUDE_SET_SPEED
G1 X131.968 Y124.312 E.02389
G1 X131.719 Y125.137 E.02388
G1 X131.301 Y125.891 E.02389
G1 X130.734 Y126.54 E.02388
G1 X130.042 Y127.054 E.02389
G1 X129.257 Y127.41 E.02388
G1 X128.414 Y127.592 E.02389
G1 X127.553 Y127.592 E.02388
G1 X126.71 Y127.41 E.02389
G1 X125.925 Y127.054 E.02388
G1 X125.233 Y126.54 E.02389
G1 X124.664 Y125.889 E.02395
G1 X124.373 Y125.413 E.01549
G1 X124.087 Y124.718 E.02081
G1 X123.931 Y123.868 E.02394
G1 X123.957 Y123.005 E.02394
G1 X124.166 Y122.166 E.02395
G1 X124.546 Y121.39 E.02394
G1 X125.089 Y120.72 E.0239
G1 X125.756 Y120.174 E.02388
G1 X126.522 Y119.78 E.02388
G1 X127.354 Y119.556 E.02388
G1 X128.208 Y119.502 E.02371
G1 X129.05 Y119.649 E.02368
G1 X129.853 Y119.963 E.02389
G1 X130.571 Y120.439 E.02388
G1 X131.173 Y121.057 E.02389
G1 X131.63 Y121.788 E.02388
G1 X131.922 Y122.599 E.02389
G1 X132.029 Y123.393 E.02222
; Slow Down End
; WIPE_START
G1 X131.922 Y122.599 E-.30468
G1 X131.63 Y121.788 E-.32757
G1 X131.452 Y121.503 E-.12775
; WIPE_END
G1 E-.04 F1800
G1 X124.281 Y118.886 Z7.4 F36000
G1 X112.872 Y114.723 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X114.48 Y114.482 I2.161 J8.928 E.05401
G1 X123.559 Y123.561 E.42593
G2 X123.691 Y124.63 I4.526 J-.019 E.0358
G1 X117.045 Y131.276 E.31178
G1 X116.251 Y131.605 E.02854
G1 X103.641 Y118.995 E.59156
G2 X102.95 Y119.466 I1.751 J3.311 E.02779
G3 X99.527 Y122.557 I-23.108 J-22.149 E.15313
G1 X111.246 Y134.277 E.54978
G2 X106.985 Y137.692 I15.431 J23.617 E.18142
G1 X106.061 Y136.767 E.04336
G2 X106.933 Y133.712 I-3.832 J-2.747 E.1075
G1 X127.763 Y112.883 E.97714
G2 X128.231 Y112.882 I.228 J-4.486 E.01555
G1 X149.036 Y133.686 E.97597
G2 X149.918 Y136.783 I4.693 J.336 E.10901
G1 X148.996 Y137.705 E.04327
G2 X144.737 Y134.288 I-28.123 J30.685 E.18126
G1 X156.451 Y122.574 E.54952
G3 X153.104 Y119.543 I25.855 J-31.912 E.14986
G2 X152.344 Y119.006 I-2.483 J2.707 E.03098
G1 X139.736 Y131.613 E.59146
G1 X138.969 Y131.296 E.02754
G1 X132.281 Y124.608 E.31375
G2 X132.407 Y123.59 I-4.36 J-1.058 E.03409
G1 X141.513 Y114.484 E.42717
G3 X143.12 Y114.73 I-.515 J8.761 E.054
; WIPE_START
G1 X141.513 Y114.484 E-.61776
G1 X141.248 Y114.749 E-.14224
; WIPE_END
G1 E-.04 F1800
G1 X134.576 Y118.455 Z7.4 F36000
G1 X106.592 Y133.997 Z7.4
G1 Z7
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G3 X106.518 Y134.875 I-14.144 J-.74 E.02441
G1 X106.266 Y135.701 E.02394
G1 X105.844 Y136.455 E.02394
G1 X105.272 Y137.103 E.02394
G1 X104.576 Y137.615 E.02394
G1 X103.788 Y137.969 E.02394
G1 X102.943 Y138.148 E.02395
G1 X102.079 Y138.144 E.02393
G1 X101.235 Y137.958 E.02395
G1 X100.45 Y137.599 E.02392
G1 X99.969 Y137.256 E.01637
G1 X99.458 Y136.769 E.01957
G1 X98.964 Y136.06 E.02394
G1 X98.631 Y135.262 E.02394
G1 X98.576 Y134.96 E.00852
; Slow Down End
G1 F12000
G1 X98.475 Y134.412 E.01542
G1 X98.501 Y133.549 E.02394
G1 X98.71 Y132.71 E.02394
G1 X98.847 Y132.432 E.0086
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X99.092 Y131.932 E.01543
G1 X99.633 Y131.264 E.02381
G1 X100.3 Y130.718 E.02387
G1 X101.066 Y130.324 E.02388
G1 X101.898 Y130.1 E.02388
G1 X102.761 Y130.047 E.02394
G1 X103.613 Y130.188 E.02394
G1 X104.417 Y130.506 E.02394
G1 X105.135 Y130.987 E.02393
G1 X105.735 Y131.608 E.02394
G1 X106.19 Y132.343 E.02394
G1 X106.48 Y133.157 E.02394
G1 X106.584 Y133.937 E.02181
; Slow Down End
; WIPE_START
G1 X106.48 Y133.157 E-.29918
G1 X106.19 Y132.343 E-.32831
G1 X106.006 Y132.046 E-.13251
; WIPE_END
G1 E-.04 F1800
G1 X98.617 Y130.137 Z7.4 F36000
G1 X97.273 Y129.79 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X97.032 Y129.191 I-.42 J-.179 E.02378
G1 X96.102 Y129.191 E.03084
G1 X107.851 Y117.443 E.55114
G2 X109.139 Y116.818 I-7.316 J-16.726 E.04752
G1 X122.133 Y129.811 E.60955
G3 X126.732 Y129.266 I5.463 J26.39 E.15382
G1 X128.009 Y127.989 E.0599
G1 X129.264 Y129.266 E.05941
G3 X133.856 Y129.818 I-3.409 J47.802 E.15348
G1 X146.846 Y116.828 E.60938
G2 X148.166 Y117.465 I8.728 J-16.395 E.04866
G1 X165.992 Y135.29 E.83622
G1 X161.299 Y138.274 E.18446
G1 X157.811 Y134.786 E.16364
G3 X153.861 Y138.512 I-4.402 J-.71 E.19366
G1 X156.606 Y141.257 E.12879
G1 X153.525 Y143.216 E.12113
G2 X152.57 Y141.808 I-13.927 J8.416 E.05649
G1 X164.241 Y130.136 E.54755
G3 X161.176 Y125.937 I22.896 J-19.933 E.17267
G1 X160.996 Y125.705 E.00972
G1 X156.117 Y130.584 E.22888
G2 X152.755 Y129.73 I-2.754 J3.796 E.11787
G1 X136.611 Y113.586 E.75735
G3 X135.24 Y113.081 I9.702 J-28.467 E.04845
G1 X129.054 Y119.267 E.29019
G2 X126.935 Y119.262 I-1.07 J4.359 E.07096
G1 X120.746 Y113.073 E.29036
G3 X119.397 Y113.572 I-11.078 J-27.848 E.0477
G1 X103.237 Y129.733 E.75814
G2 X99.866 Y130.572 I-.692 J4.411 E.11836
G1 X94.782 Y125.488 E.23851
G3 X91.734 Y130.116 I-17.144 J-7.971 E.18449
G1 X92.814 Y131.196 E.05065
G1 X92.814 Y132.48 E.04257
G1 X90.237 Y135.057 E.1209
G1 X94.845 Y138.125 E.18364
G1 X98.159 Y134.81 E.15549
G2 X102.132 Y138.513 I4.374 J-.71 E.19392
G1 X99.453 Y141.192 E.12568
G1 X102.457 Y143.192 E.1197
G3 X103.409 Y141.791 I13.822 J8.367 E.0562
G1 X96.268 Y134.651 E.33498
G1 X97.032 Y134.651 E.02534
G1 X97.273 Y134.409 E.01131
G1 X97.273 Y133.886 E.01736
G1 X96.881 Y130.466 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X96.881 Y131.439 E.0299
G1 X96.729 Y131.514 E.00521
G1 X96.586 Y131.696 E.00711
G1 X96.581 Y132.102 E.01248
G1 X96.62 Y132.217 E.00372
G1 X96.881 Y132.403 E.00986
G1 X96.87 Y134.259 E.05703
G1 X93.206 Y134.247 E.11258
G1 X93.217 Y129.583 E.14331
G1 X96.862 Y129.583 E.11198
G1 X96.881 Y129.595 E.0007
G1 X96.881 Y130.406 E.02493
G1 X96.504 Y130.089 F36000
G1 F12000
G1 X96.504 Y131.23 E.03505
G1 X96.37 Y131.34 E.00533
G1 X96.22 Y131.608 E.00945
G1 X96.213 Y132.2 E.01818
G1 X96.32 Y132.446 E.00825
G1 X96.504 Y132.612 E.00762
G1 X96.504 Y133.882 E.03901
G1 X93.583 Y133.882 E.08976
G1 X93.583 Y129.96 E.12049
G1 X96.504 Y129.96 E.08976
G1 X96.504 Y130.029 E.00211
G1 X96.127 Y132.792 F36000
G1 F12000
G1 X96.021 Y132.675 E.00487
G1 X95.841 Y132.265 E.01375
G1 X95.827 Y131.74 E.01614
G1 X95.853 Y131.52 E.00679
G3 X96.127 Y131.015 I1.635 J.561 E.01773
G1 X96.127 Y130.337 E.02084
G1 X93.96 Y130.337 E.06659
G1 X93.96 Y133.504 E.09732
G1 X96.127 Y133.504 E.06659
G1 X96.127 Y132.852 E.02003
G1 X95.75 Y132.936 F36000
G1 F12000
G1 X95.486 Y132.409 E.01811
G1 X95.45 Y131.74 E.0206
G1 X95.486 Y131.433 E.0095
G1 X95.721 Y130.938 E.01682
G1 X95.75 Y130.714 E.00693
G1 X94.337 Y130.714 E.04342
G1 X94.337 Y133.127 E.07415
G1 X95.75 Y133.127 E.04342
G1 X95.75 Y132.996 E.00403
G1 X95.227 Y132.742 F36000
; LINE_WIDTH: 0.426956
G1 F12000
G1 X95.096 Y132.396 E.01158
G3 X95.111 Y131.343 I4.648 J-.459 E.03302
G1 X95.227 Y131.1 E.00842
G1 X94.723 Y131.1 E.01578
G2 X94.723 Y132.742 I34.027 J.821 E.05139
G1 X95.167 Y132.742 E.0139
G1 X91.334 Y130.011 F36000
; LINE_WIDTH: 0.38292
G1 F12000
G1 X92.209 Y129.013 E.03676
G2 X93.259 Y127.481 I-12.407 J-9.635 E.05151
; Slow Down Start
; LINE_WIDTH: 0.385134
G1 F3000;_EXTRUDE_SET_SPEED
G2 X94.49 Y125.265 I-29.318 J-17.733 E.07068
G1 X94.756 Y124.881 E.01302
G1 X95.187 Y124.604 E.01429
G2 X97.704 Y123.334 I-16.558 J-35.951 E.07864
G2 X100.61 Y121.192 I-8.546 J-14.631 E.10087
G1 X102.707 Y119.196 E.08073
G3 X103.463 Y118.677 I2.348 J2.604 E.02564
G1 X104.105 Y118.406 E.01944
G1 X106.588 Y117.564 E.07313
G2 X109.566 Y116.175 I-8.459 J-22.024 E.09169
G1 X111.93 Y114.744 E.07706
G1 X112.36 Y114.534 E.01335
G3 X113.583 Y114.213 I1.831 J4.475 E.03537
G1 X115.879 Y113.969 E.06438
G2 X120.53 Y112.77 I-1.985 J-17.321 E.13435
G1 X122.166 Y112.086 E.04944
G1 X122.634 Y111.937 E.01371
G1 X122.904 Y111.91 E.00756
G1 X123.381 Y111.954 E.01334
G2 X126.462 Y112.448 I7.726 J-38.3 E.08705
G2 X130.832 Y112.266 I1.52 J-16.027 E.12236
G1 X132.587 Y111.951 E.04972
G3 X133.228 Y111.921 I.651 J7.009 E.01789
G1 X133.796 Y112.087 E.01648
G2 X137.05 Y113.348 I14.145 J-31.668 E.09737
M73 P81 R3
G2 X140.088 Y113.969 I5.282 J-18.116 E.08657
G1 X142.38 Y114.211 E.06427
G1 X143.318 Y114.42 E.02679
G1 X144.029 Y114.74 E.02175
G1 X146.401 Y116.175 E.07731
G2 X149.38 Y117.564 I11.435 J-20.634 E.09172
G1 X152.01 Y118.461 E.0775
G3 X152.796 Y118.844 I-4.44 J10.102 E.0244
G1 X153.349 Y119.275 E.01954
G1 X155.356 Y121.191 E.07736
G2 X157.961 Y123.19 I15.634 J-17.678 E.09165
G1 X160.433 Y124.7 E.08079
G3 X161.024 Y125.182 I-4.584 J6.222 E.02128
G1 X161.471 Y125.726 E.01963
G1 X163.01 Y128.022 E.07707
G2 X165.126 Y130.543 I19.076 J-13.859 E.09186
G1 X167.017 Y132.352 E.07298
G3 X167.55 Y132.954 I-11.235 J10.474 E.02241
G3 X168.187 Y134.3 I-4.434 J2.923 E.04167
G1 X168.102 Y134.378 E.00323
G1 X153.545 Y143.633 E.48103
G1 X153.417 Y143.681 E.0038
G1 X153.114 Y143.24 E.01493
G2 X141.587 Y132.862 I-25.235 J16.437 E.43746
G2 X102.85 Y143.244 I-13.597 J26.724 E1.225
G1 X102.561 Y143.662 E.01418
G1 X102.432 Y143.611 E.00386
G1 X87.815 Y133.881 E.48965
G1 X87.738 Y133.809 E.00293
G1 X87.826 Y133.44 E.01059
G1 X88.047 Y132.889 E.01654
G1 X88.398 Y132.532 E.01396
G2 X90.583 Y130.745 I-23.986 J-31.564 E.07874
G1 X91.291 Y130.052 E.02762
; Slow Down End
; CHANGE_LAYER
; Z_HEIGHT: 7.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X90.583 Y130.745 E-.37635
G1 X89.816 Y131.402 E-.38365
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
G1 X126.293 Y120.267
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X126.635 Y120.112 E.01245
G3 X127.786 Y119.863 I1.348 J3.446 E.03924
G3 X127.46 Y127.222 I.195 J3.695 E.40941
G3 X126.24 Y120.294 I.523 J-3.663 E.30803
G1 X126.483 Y120.612 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.778 Y120.478 E.00997
G3 X127.807 Y120.255 I1.205 J3.078 E.0325
G1 X128.16 Y120.255 E.01083
G3 X126.429 Y120.639 I-.176 J3.301 E.58299
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.14601
G1 X127.113 Y120.367 E-.1339
G1 X127.457 Y120.293 E-.1339
G1 X127.807 Y120.255 E-.13389
G1 X128.16 Y120.255 E-.13391
G1 X128.365 Y120.277 E-.07839
; WIPE_END
G1 E-.04 F1800
G1 X121.727 Y124.044 Z7.6 F36000
G1 X99.729 Y136.529 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.501 Y136.231 E.01245
G3 X102.331 Y130.407 I3.027 J-2.129 E.2615
G1 X102.725 Y130.407 E.01307
G3 X99.771 Y136.571 I-.197 J3.695 E.48223
G1 X100.032 Y136.279 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.822 Y136.006 E.01058
G3 X102.351 Y130.799 I2.706 J-1.903 E.21655
G1 X102.704 Y130.799 E.01083
G3 X100.073 Y136.321 I-.176 J3.303 E.39888
; WIPE_START
M204 S10000
G1 X99.822 Y136.006 E-.15329
G1 X99.632 Y135.709 E-.13382
G1 X99.478 Y135.392 E-.13395
G1 X99.358 Y135.061 E-.13385
G1 X99.275 Y134.718 E-.13391
G1 X99.25 Y134.533 E-.07119
; WIPE_END
G1 E-.04 F1800
G1 X106.863 Y133.993 Z7.6 F36000
G1 X151.749 Y130.811 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.091 Y130.656 E.01245
G3 X153.242 Y130.407 I1.348 J3.446 E.03924
G1 X153.636 Y130.407 E.01307
G3 X151.696 Y130.839 I-.197 J3.695 E.70446
G1 X151.927 Y131.161 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.01034
G3 X153.263 Y130.799 I1.205 J3.081 E.0325
G1 X153.615 Y130.799 E.01083
G3 X151.874 Y131.188 I-.176 J3.303 E.58314
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.15065
G1 X152.568 Y130.911 E-.13392
G1 X152.913 Y130.837 E-.13389
G1 X153.263 Y130.799 E-.1339
G1 X153.615 Y130.799 E-.1339
G1 X153.808 Y130.82 E-.07374
; WIPE_END
G1 E-.04 F1800
G1 X153.514 Y138.447 Z7.6 F36000
G1 X153.292 Y144.224 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X102.682 Y144.213 I-24.82 J16.134 E1.98338
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.388 J1.747 E.04339
G3 X88.408 Y132.053 I2.736 J2.127 E.03249
G2 X91.148 Y129.685 I-14.522 J-19.574 E.12022
G2 X93.594 Y126.16 I-11.287 J-10.443 E.1428
G3 X94.42 Y124.708 I12.317 J6.045 E.05546
G3 X95.013 Y124.286 I1.249 J1.126 E.02433
G2 X97.525 Y123.019 I-21.485 J-45.73 E.09335
G2 X101.007 Y120.323 I-8.608 J-14.713 E.14649
G3 X102.746 Y118.697 I16.21 J15.592 E.07901
G3 X103.976 Y118.067 I2.75 J3.856 E.04601
G2 X107.047 Y116.997 I-16.553 J-52.467 E.1079
G2 X110.366 Y115.274 I-7.764 J-19.013 E.12422
G3 X112.192 Y114.201 I10.969 J16.581 E.07028
G3 X113.876 Y113.812 I2.035 J4.969 E.05758
G2 X117.401 Y113.355 I-2.348 J-31.92 E.11796
G2 X120.397 Y112.432 I-3.463 J-16.569 E.10416
G3 X122.452 Y111.606 I9.401 J20.397 E.07349
G3 X123.43 Y111.594 I.513 J2.043 E.03277
G2 X125.813 Y112.005 I37.913 J-213.017 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16543
G3 X132.882 Y111.551 I5.298 J24.871 E.07084
G3 X133.236 Y111.55 I.18 J1.843 E.01175
G3 X134.41 Y111.943 I-.933 J4.728 E.04117
G2 X137.511 Y113.104 I10.352 J-22.937 E.10992
G2 X140.702 Y113.674 I5.147 J-19.606 E.10764
G3 X143.068 Y113.962 I-1.513 J22.322 E.07911
G3 X144.642 Y114.679 I-1.436 J5.237 E.05763
G2 X148.015 Y116.604 I17.393 J-26.556 E.12888
G2 X151.656 Y117.949 I12.731 J-28.864 E.12887
G3 X153.297 Y118.756 I-1.46 J5.034 E.06096
G3 X154.769 Y120.137 I-13.751 J16.135 E.06698
G2 X158.903 Y123.348 I14.662 J-14.611 E.1741
G3 X161.003 Y124.671 I-9.758 J17.826 E.0824
G3 X161.85 Y125.632 I-2.915 J3.421 E.04264
G2 X163.68 Y128.324 I49.879 J-31.939 E.10797
G2 X166.202 Y131.082 I16.837 J-12.864 E.12417
G3 X167.71 Y132.567 I-14.857 J16.59 E.07023
G3 X168.522 Y134.094 I-4.098 J3.159 E.05762
G1 X168.658 Y134.455 E.01279
G1 X153.342 Y144.192 E.60204
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.79 E1.86594
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.135 J2.086 E.05195
G3 X88.162 Y131.747 I2.988 J2.222 E.03454
G2 X90.863 Y129.416 I-14.319 J-19.317 E.10972
G2 X93.249 Y125.974 I-11.005 J-10.178 E.12912
G3 X94.112 Y124.465 I12.335 J6.053 E.05347
G3 X94.828 Y123.939 I1.546 J1.357 E.0275
G2 X97.331 Y122.678 I-21.522 J-45.811 E.08611
G2 X100.735 Y120.04 I-8.415 J-14.374 E.13271
G3 X102.511 Y118.382 I16.288 J15.672 E.0747
G3 X103.844 Y117.698 I2.998 J4.195 E.04619
G2 X106.326 Y116.856 I-155.985 J-464.012 E.08053
G2 X110.16 Y114.94 I-7.084 J-18.977 E.13196
G3 X112.029 Y113.845 I11.123 J16.83 E.06659
G3 X113.833 Y113.423 I2.199 J5.333 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.543 E.10817
G2 X120.249 Y112.069 I-3.378 J-16.162 E.09423
G3 X122.349 Y111.227 I9.355 J20.289 E.06955
G3 X123.486 Y111.206 I.613 J2.41 E.03526
G2 X125.869 Y111.616 I39.532 J-222.4 E.0743
G2 X130.712 Y111.521 I2.13 J-14.776 E.1495
G3 X132.851 Y111.16 I5.313 J24.953 E.06667
G3 X133.276 Y111.159 I.213 J2.283 E.01307
G3 X134.559 Y111.581 I-.935 J5.011 E.04163
G2 X137.615 Y112.726 I10.229 J-22.647 E.10036
G2 X140.743 Y113.284 I5.04 J-19.214 E.09773
G3 X143.156 Y113.579 I-1.533 J22.522 E.07473
G3 X144.845 Y114.343 I-1.516 J5.602 E.0572
G2 X148.18 Y116.248 I17.233 J-26.298 E.11811
G2 X151.783 Y117.578 I12.597 J-28.591 E.11808
G3 X153.54 Y118.449 I-1.58 J5.393 E.06056
G3 X155.042 Y119.856 I-13.955 J16.401 E.06326
G2 X159.105 Y123.012 I14.388 J-14.329 E.15852
G3 X161.075 Y124.229 I-11.654 J21.061 E.07118
G3 X162.172 Y125.409 I-2.91 J3.808 E.04974
G2 X163.992 Y128.087 I49.789 J-31.876 E.09952
G2 X166.471 Y130.797 I16.518 J-12.622 E.11298
G3 X168.013 Y132.318 I-14.973 J16.715 E.06657
G3 X168.887 Y133.952 I-4.411 J3.413 E.05721
G1 X169.137 Y134.615 E.02177
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49807
G1 X152.091 Y143.084 E-.26193
; WIPE_END
G1 E-.04 F1800
G1 X151.53 Y137.468 Z7.6 F36000
G1 Z7.2
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.40274
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X156.077 Y142.015 E.33379
G1 X156.468 Y141.767 E.02407
G1 X152.828 Y138.126 E.26721
G2 X153.516 Y138.174 I.656 J-4.478 E.03583
G1 X156.86 Y141.518 E.24544
G1 X157.251 Y141.269 E.02407
G1 X154.1 Y138.118 E.23126
G2 X154.621 Y137.999 I-.3 J-2.496 E.02778
G1 X157.642 Y141.02 E.22178
G1 X158.034 Y140.771 E.02407
G1 X155.09 Y137.827 E.21612
G2 X155.513 Y137.61 I-5.713 J-11.686 E.0247
G1 X158.425 Y140.522 E.21376
G1 X158.817 Y140.273 E.02407
G1 X155.895 Y137.352 E.21444
G2 X156.235 Y137.051 I-1.71 J-2.268 E.02357
G1 X159.208 Y140.025 E.21827
G1 X159.6 Y139.776 E.02407
G1 X156.551 Y136.728 E.22374
G1 X156.666 Y136.582 E.00961
G2 X156.825 Y136.361 I-.953 J-.858 E.01417
G1 X159.991 Y139.527 E.23236
G1 X160.382 Y139.278 E.02407
G1 X157.061 Y135.957 E.24377
G2 X157.256 Y135.511 I-1.986 J-1.132 E.02529
G1 X160.774 Y139.029 E.25823
G1 X161.165 Y138.78 E.02407
G1 X157.403 Y135.018 E.27615
G1 X157.415 Y134.971 E.00253
G2 X157.494 Y134.469 I-2.309 J-.623 E.02642
G1 X161.557 Y138.531 E.2982
G1 X161.948 Y138.283 E.02407
G1 X157.498 Y133.832 E.32666
G2 X157.375 Y133.07 I-4.519 J.334 E.04014
G1 X162.339 Y138.034 E.36438
G1 X162.731 Y137.785 E.02407
G1 X138.702 Y113.756 E1.76376
G2 X139.473 Y113.886 I2.651 J-13.38 E.04054
G1 X163.122 Y137.536 E1.73597
G1 X163.514 Y137.287 E.02407
G1 X140.216 Y113.989 E1.71015
G1 X140.932 Y114.065 E.03738
G1 X163.905 Y137.038 E1.68631
G1 X164.297 Y136.789 E.02407
G1 X141.648 Y114.141 E1.66247
G1 X142.364 Y114.217 E.03738
M73 P82 R3
G1 X164.688 Y136.541 E1.63863
G1 X165.079 Y136.292 E.02407
G1 X143.159 Y114.371 E1.60905
G3 X144.402 Y114.974 I-1.612 J4.905 E.07195
G1 X165.471 Y136.043 E1.5465
G1 X165.862 Y135.794 E.02407
G1 X146.023 Y115.954 E1.45628
G2 X147.446 Y116.738 I11.651 J-19.492 E.08434
G1 X166.254 Y135.545 E1.38053
G1 X166.645 Y135.296 E.02407
G1 X148.619 Y117.27 E1.32317
G1 X149.192 Y117.497 E.03201
G2 X149.654 Y117.665 I1.948 J-4.645 E.02551
G1 X167.036 Y135.047 E1.27592
G1 X167.428 Y134.799 E.02407
G1 X150.625 Y117.996 E1.23335
G1 X151.597 Y118.327 E.05327
G1 X167.819 Y134.55 E1.19078
G1 X168.203 Y134.306 E.02363
G1 X152.713 Y118.803 E1.13747
G3 X153.342 Y119.278 I-2.409 J3.844 E.04093
G1 X155.351 Y121.196 E.14416
G1 X155.59 Y121.403 E.01644
G2 X157.302 Y122.751 I17.16 J-20.016 E.11312
G1 X167.626 Y133.076 E.75786
G2 X167.015 Y132.359 I-4.358 J3.097 E.04895
G1 X165.121 Y130.548 E.13602
G3 X162.573 Y127.383 I14.119 J-13.971 E.21129
G1 X159.06 Y123.869 E.25788
G1 X160.435 Y124.71 E.08368
G1 X160.705 Y124.91 E.01741
G3 X160.975 Y125.144 I-1.04 J1.47 E.01856
G1 X162.011 Y126.181 E.07611
G1 X154.785 Y130.479 F36000
G1 F3000
G1 X137.887 Y113.582 E1.24033
G3 X137.007 Y113.341 I7.313 J-28.523 E.04738
G1 X153.709 Y130.043 E1.22597
G2 X153.135 Y130.047 I-.25 J5.554 E.0298
G1 X153.078 Y130.053 E.00295
G1 X136.028 Y113.003 E1.25154
G3 X134.967 Y112.582 I9.701 J-26.017 E.05924
G1 X152.526 Y130.141 E1.28888
G1 X152.031 Y130.287 E.02677
G1 X133.87 Y112.126 E1.33307
G2 X133.399 Y111.96 I-1.412 J3.277 E.02594
G2 X133.024 Y111.92 I-.285 J.889 E.01968
G1 X151.584 Y130.48 E1.36236
G2 X151.18 Y130.716 I7.393 J13.117 E.0243
G1 X132.447 Y111.983 E1.37505
G1 X131.905 Y112.081 E.02863
G1 X150.815 Y130.992 E1.38811
G2 X150.518 Y131.267 I3.245 J3.806 E.02105
G1 X150.486 Y131.303 E.00248
G1 X131.362 Y112.178 E1.40381
M73 P83 R3
G3 X130.818 Y112.275 I-1.81 J-8.578 E.02865
G1 X150.193 Y131.65 E1.42217
G2 X149.937 Y132.034 I1.667 J1.391 E.02401
G1 X130.26 Y112.357 E1.44432
G3 X129.693 Y112.431 I-1.34 J-8.107 E.02967
G1 X149.72 Y132.457 E1.47
G2 X149.555 Y132.899 I1.985 J.994 E.02453
G1 X149.547 Y132.924 E.00138
G1 X129.105 Y112.482 E1.50053
G3 X128.501 Y112.519 I-.604 J-4.906 E.03139
G1 X149.425 Y133.443 E1.53586
G2 X149.368 Y134.026 I5.621 J.841 E.03045
G1 X127.872 Y112.53 E1.57792
G1 X127.214 Y112.513 E.03413
G1 X149.417 Y134.716 E1.62977
G2 X149.651 Y135.589 I4.187 J-.651 E.04703
G1 X126.521 Y112.46 E1.69778
G3 X125.784 Y112.362 I.44 J-6.17 E.03865
G1 X155.685 Y142.264 E2.19489
G1 X155.294 Y142.513 E.02407
G1 X125.037 Y112.256 E2.22097
G1 X124.258 Y112.117 E.04107
G1 X154.903 Y142.762 E2.24942
G1 X154.511 Y143.011 E.02407
G1 X123.479 Y111.978 E2.27788
G2 X122.919 Y111.915 I-.682 J3.543 E.02929
G1 X122.787 Y111.927 E.00686
G1 X154.12 Y143.26 E2.29993
G1 X153.728 Y143.509 E.02407
G1 X152.381 Y142.161 E.0989
G2 X147.114 Y136.497 I-23.779 J16.832 E.40263
G1 X146.845 Y136.268 E.01833
G1 X145.383 Y135.163 E.09512
G1 X122.116 Y111.896 E1.70787
; WIPE_START
G1 X123.53 Y113.311 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X125.992 Y120.535 Z7.6 F36000
G1 X129.157 Y129.822 Z7.6
G1 Z7.2
M73 P84 R3
G1 E.8 F1800
G1 F3000
G1 X126.785 Y127.45 E.17411
G2 X127.588 Y127.613 I1.398 J-4.83 E.04259
G1 X129.61 Y129.634 E.14837
G1 X130.305 Y129.689 E.03618
G1 X128.236 Y127.62 E.15183
G2 X128.804 Y127.548 I-.053 J-2.692 E.02978
G1 X131 Y129.744 E.16114
G3 X131.73 Y129.834 I-.494 J7.019 E.03821
G1 X129.307 Y127.411 E.17785
G2 X129.759 Y127.222 I-.657 J-2.209 E.02546
M73 P84 R2
G1 X132.467 Y129.931 E.19882
G3 X133.129 Y130.049 I-.931 J7.141 E.03491
G1 X133.246 Y130.07 E.00619
G1 X130.169 Y126.992 E.22591
G2 X130.541 Y126.724 I-1.07 J-1.877 E.02385
G1 X134.027 Y130.21 E.25587
G3 X134.854 Y130.397 I-1.201 J7.228 E.04407
G1 X130.877 Y126.42 E.29197
G2 X131.177 Y126.079 I-1.439 J-1.573 E.02359
G1 X135.697 Y130.599 E.33177
G3 X135.987 Y130.683 I-.65 J2.806 E.01565
G1 X136.603 Y130.865 E.03338
G1 X131.441 Y125.703 E.37893
G2 X131.666 Y125.288 I-1.826 J-1.26 E.02455
G1 X137.537 Y131.159 E.43093
G1 X138.528 Y131.51 E.05458
G1 X131.849 Y124.831 E.49027
G2 X131.984 Y124.325 I-2.343 J-.894 E.02721
G1 X139.601 Y131.943 E.55915
G3 X140.757 Y132.458 I-4.334 J11.274 E.06569
G1 X132.047 Y123.748 E.6393
G2 X132.026 Y123.087 I-3.104 J-.231 E.03442
G1 X142.037 Y133.098 E.73486
G3 X143.523 Y133.943 I-7.316 J14.587 E.08874
G1 X131.84 Y122.26 E.85757
G2 X129.288 Y119.708 I-3.826 J1.274 E.19422
G1 X121.819 Y112.239 E.54824
G1 X121.367 Y112.428 E.0254
G1 X128.46 Y119.521 E.52068
G2 X127.792 Y119.493 I-.479 J3.475 E.03476
G1 X120.915 Y112.616 E.50479
G3 X120.462 Y112.803 I-3.184 J-7.085 E.02546
G1 X127.223 Y119.564 E.49625
G2 X126.715 Y119.696 I.366 J2.443 E.02729
G1 X119.998 Y112.98 E.493
G3 X119.532 Y113.153 I-2.084 J-4.889 E.02585
G1 X126.256 Y119.878 E.4936
G2 X125.84 Y120.102 I.867 J2.102 E.02457
G1 X119.05 Y113.312 E.49846
G3 X118.554 Y113.456 I-1.764 J-5.15 E.02683
G1 X125.464 Y120.366 E.50722
G2 X125.123 Y120.666 I1.234 J1.743 E.02359
G1 X118.046 Y113.589 E.51945
G1 X117.524 Y113.706 E.02781
G1 X124.823 Y121.006 E.53578
G1 X124.55 Y121.373 E.02375
G1 X116.985 Y113.808 E.55528
G3 X116.432 Y113.895 I-1.398 J-7.08 E.02907
G1 X124.319 Y121.783 E.57895
G2 X124.134 Y122.238 I2.036 J1.093 E.02555
G1 X115.873 Y113.976 E.60642
G1 X115.294 Y114.038 E.03021
G1 X123.999 Y122.743 E.63896
G2 X123.923 Y123.308 I2.604 J.635 E.02964
G1 X114.715 Y114.099 E.6759
G1 X114.137 Y114.161 E.03021
G1 X123.933 Y123.957 E.71908
G2 X124.065 Y124.662 I3.359 J-.267 E.03728
G2 X124.09 Y124.755 I.449 J-.07 E.00502
G1 X113.559 Y114.224 E.77303
G1 X113.013 Y114.318 E.02875
G1 X128.292 Y129.597 E1.12148
G2 X127.652 Y129.597 I-.314 J6.103 E.03322
G1 X112.522 Y114.468 E1.11057
G2 X112.292 Y114.566 I.408 J1.278 E.01301
G1 X112.086 Y114.671 E.01202
G1 X127.028 Y129.614 E1.09681
G2 X126.405 Y129.63 I-.15 J5.994 E.03238
G1 X111.678 Y114.904 E1.08095
G1 X111.28 Y115.146 E.0242
G1 X125.811 Y129.677 E1.06666
G1 X125.218 Y129.724 E.0309
G1 X110.881 Y115.387 E1.05236
G1 X110.482 Y115.629 E.0242
G1 X124.635 Y129.781 E1.03885
G1 X124.069 Y129.856 E.02962
G1 X110.083 Y115.87 E1.02659
G1 X109.684 Y116.112 E.0242
G1 X123.503 Y129.93 E1.01433
G2 X122.953 Y130.021 I.592 J5.294 E.02892
G1 X109.274 Y116.341 E1.00415
G1 X108.858 Y116.566 E.02452
G1 X122.413 Y130.121 E.99501
G1 X121.873 Y130.221 E.02851
G1 X108.433 Y116.781 E.98657
G3 X107.999 Y116.987 I-7.517 J-15.196 E.02493
M73 P85 R2
G1 X121.351 Y130.34 E.9801
G1 X120.835 Y130.464 E.02756
G1 X107.556 Y117.185 E.97472
G3 X107.1 Y117.369 I-2.454 J-5.43 E.02554
G1 X120.319 Y130.588 E.97032
G2 X119.821 Y130.73 I1.11 J4.827 E.02689
G1 X106.641 Y117.55 E.96742
G3 X106.165 Y117.715 I-1.871 J-4.647 E.02615
G1 X119.327 Y130.876 E.9661
G1 X118.833 Y131.023 E.02674
G1 X105.687 Y117.877 E.96494
G1 X105.209 Y118.039 E.0262
G1 X118.355 Y131.185 E.96498
G1 X117.882 Y131.353 E.02604
G1 X104.731 Y118.201 E.96536
G1 X104.253 Y118.363 E.0262
G1 X117.41 Y131.52 E.96575
G2 X116.95 Y131.701 I1.491 J4.475 E.02565
G1 X103.794 Y118.545 E.96568
G2 X103.355 Y118.746 I.536 J1.746 E.02513
G1 X116.497 Y131.888 E.96465
G1 X116.044 Y132.076 E.02544
G1 X102.969 Y119.001 E.95975
G2 X102.619 Y119.29 I2.539 J3.431 E.02362
G1 X115.6 Y132.272 E.95288
G1 X115.167 Y132.478 E.02493
G1 X102.291 Y119.602 E.94514
G1 X101.962 Y119.915 E.02351
G1 X114.733 Y132.685 E.93741
G2 X114.303 Y132.895 I1.792 J4.215 E.02486
G1 X101.634 Y120.227 E.92991
G1 X101.306 Y120.539 E.02351
G1 X113.888 Y133.121 E.92354
G1 X113.473 Y133.346 E.02451
G1 X100.978 Y120.851 E.91716
G1 X100.65 Y121.163 E.02351
G1 X113.058 Y133.571 E.91078
G2 X112.658 Y133.812 I2.097 J3.934 E.02422
G1 X100.308 Y121.462 E.90652
G1 X99.965 Y121.759 E.02356
G1 X112.261 Y134.055 E.90257
G1 X111.864 Y134.298 E.02417
G1 X99.609 Y122.043 E.89958
G1 X99.249 Y122.323 E.02369
G1 X111.476 Y134.55 E.89752
G1 X111.096 Y134.811 E.0239
G1 X98.88 Y122.594 E.89673
G1 X98.498 Y122.853 E.02393
G1 X110.717 Y135.072 E.89687
G2 X110.339 Y135.334 I2.326 J3.759 E.02389
G1 X98.105 Y123.101 E.89796
G1 X97.706 Y123.341 E.02421
G1 X109.976 Y135.612 E.9007
G1 X109.614 Y135.89 E.0237
G1 X106.295 Y132.57 E.24366
G3 X106.545 Y133.461 I-3.918 J1.583 E.04812
G1 X109.252 Y136.168 E.19868
G2 X108.901 Y136.457 I2.584 J3.502 E.02362
M73 P86 R2
G1 X106.595 Y134.151 E.16922
G3 X106.546 Y134.742 I-2.791 J.065 E.03084
G1 X108.555 Y136.752 E.14748
G1 X108.21 Y137.047 E.02357
G1 X106.431 Y135.267 E.1306
G3 X106.258 Y135.735 I-8.852 J-3.007 E.02587
G1 X107.868 Y137.345 E.11816
G1 X107.539 Y137.656 E.02351
G1 X106.041 Y136.158 E.10997
G3 X105.785 Y136.543 I-1.925 J-1.004 E.02401
G1 X107.211 Y137.968 E.10464
G1 X106.882 Y138.28 E.02351
G1 X105.492 Y136.89 E.102
G3 X105.164 Y137.202 I-1.625 J-1.38 E.02355
G1 X106.566 Y138.604 E.10286
G1 X106.254 Y138.932 E.02351
G1 X104.8 Y137.478 E.10671
G3 X104.398 Y137.717 I-1.314 J-1.758 E.0243
G1 X105.942 Y139.261 E.11333
G2 X105.635 Y139.593 I3.025 J3.104 E.02353
G1 X103.955 Y137.914 E.12328
G3 X103.466 Y138.065 I-.959 J-2.239 E.02663
G1 X105.34 Y139.939 E.13755
G1 X105.045 Y140.284 E.02357
G1 X102.918 Y138.157 E.15612
G3 X102.503 Y138.177 I-.299 J-1.942 E.02157
G1 X102.285 Y138.165 E.01133
G1 X104.75 Y140.629 E.18089
G2 X104.468 Y140.988 I3.283 J2.863 E.02368
G1 X101.226 Y137.746 E.23802
; WIPE_START
G1 X102.64 Y139.16 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.307 Y131.712 Z7.6 F36000
G1 X104.514 Y130.789 Z7.6
G1 Z7.2
G1 E.8 F1800
G1 F3000
G1 X97.288 Y123.564 E.53035
G1 X96.871 Y123.787 E.02456
G1 X103.167 Y130.083 E.46214
G2 X102.481 Y130.038 I-.554 J3.186 E.03572
G1 X96.443 Y123.999 E.44326
G1 X96.012 Y124.209 E.02485
G1 X101.886 Y130.083 E.43117
G2 X101.368 Y130.204 I1.675 J8.315 E.02766
G1 X95.582 Y124.419 E.42467
G2 X95.154 Y124.631 I1.248 J3.058 E.02482
G1 X100.9 Y130.377 E.42176
G2 X100.476 Y130.593 I1.477 J3.424 E.02473
G1 X94.764 Y124.881 E.41926
G2 X94.502 Y125.259 I1.526 J1.339 E.02393
G1 X100.091 Y130.848 E.41026
G2 X99.743 Y131.14 I1.192 J1.774 E.02363
G1 X94.276 Y125.674 E.40123
G1 X94.052 Y126.09 E.02452
G1 X99.43 Y131.468 E.3948
G2 X99.154 Y131.832 I1.565 J1.477 E.02376
G1 X93.677 Y126.356 E.40198
G1 X95.257 Y131.051 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.494466
; LAYER_HEIGHT: 0.2
G1 F13952.088
G1 X94.674 Y131.051 E.02146
G2 X94.674 Y132.791 I78.676 J.87 E.06402
G1 X95.257 Y132.791 E.02146
G1 X95.125 Y132.53 E.01077
G1 X95.125 Y131.312 E.04481
G1 X95.23 Y131.104 E.00856
G1 X95.829 Y130.635 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X94.258 Y130.636 E.04826
G1 X94.258 Y133.206 E.07899
G1 X95.829 Y133.206 E.04826
G1 X95.829 Y132.916 E.00892
G1 X95.695 Y132.782 E.00584
G1 X95.535 Y132.467 E.01083
G1 X95.529 Y131.46 E.03094
G1 X95.535 Y131.375 E.00263
G1 X95.695 Y131.06 E.01083
G1 X95.829 Y130.926 E.00584
G1 X95.829 Y130.695 E.00707
G1 X96.206 Y130.258 F36000
G1 F15000
G1 X93.881 Y130.258 E.07144
G1 X93.881 Y133.583 E.10216
G1 X96.206 Y133.583 E.07144
G1 X96.206 Y132.76 E.0253
G1 X95.961 Y132.515 E.01064
G1 X95.906 Y132.382 E.00443
G1 X95.906 Y131.46 E.02832
G1 X95.961 Y131.327 E.00443
G1 X96.206 Y131.082 E.01064
G1 X96.206 Y130.318 E.02346
G1 X90.668 Y130.389 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.40274
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X93.468 Y133.189 E.20553
G1 X93.468 Y132.549 E.03323
G1 X91.134 Y130.216 E.17125
G2 X91.455 Y129.896 I-3.583 J-3.908 E.02351
G1 X93.468 Y131.908 E.14774
G1 X93.468 Y131.268 E.03323
G1 X91.752 Y129.552 E.12595
G1 X92.049 Y129.209 E.02356
G1 X93.468 Y130.628 E.10416
G1 X93.468 Y129.987 E.03323
G1 X92.335 Y128.855 E.08314
G1 X92.608 Y128.488 E.02375
G1 X93.965 Y129.845 E.09962
G1 X94.605 Y129.845 E.03323
G1 X92.869 Y128.109 E.12745
G2 X93.124 Y127.723 I-3.475 J-2.578 E.02399
G1 X95.246 Y129.845 E.15572
G1 X95.886 Y129.845 E.03323
G1 X93.362 Y127.321 E.18528
G1 X93.6 Y126.918 E.02427
G1 X98.915 Y132.233 E.39014
G2 X98.829 Y132.408 I.773 J.487 E.0101
G1 X98.716 Y132.675 E.01507
G1 X96.62 Y130.578 E.15391
G1 X96.62 Y131.219 E.03323
G1 X98.566 Y133.165 E.14286
G2 X98.478 Y133.718 I2.54 J.686 E.0291
G1 X96.319 Y131.559 E.15845
G1 X96.32 Y132.199 E.03323
G1 X98.465 Y134.345 E.1575
G2 X98.585 Y135.105 I4.405 J-.304 E.03998
G1 X96.62 Y133.139 E.14426
G1 X96.62 Y133.78 E.03323
G1 X104.19 Y141.351 E.55573
G1 X103.912 Y141.713 E.0237
G1 X96.196 Y133.997 E.56638
G1 X95.556 Y133.997 E.03323
G1 X103.641 Y142.081 E.59343
G1 X103.38 Y142.461 E.0239
G1 X94.916 Y133.997 E.62129
G1 X94.276 Y133.997 E.03323
G1 X103.119 Y142.84 E.64914
G1 X102.858 Y143.22 E.0239
G1 X90.48 Y130.842 E.90857
G1 X90.136 Y131.137 E.02357
G1 X102.614 Y143.616 E.91598
G1 X102.567 Y143.693 E.00466
G1 X101.022 Y142.664 E.09638
G1 X89.79 Y131.432 E.82443
G1 X89.434 Y131.716 E.02365
G1 X99.106 Y141.389 E.71001
G1 X97.191 Y140.114 E.11942
G1 X89.077 Y132 E.59559
G1 X88.721 Y132.284 E.02365
G1 X95.276 Y138.839 E.48117
G1 X93.361 Y137.564 E.11942
G1 X88.367 Y132.57 E.36656
G1 X88.1 Y132.821 E.01904
G1 X88.048 Y132.891 E.00451
G1 X91.445 Y136.289 E.24938
G1 X89.53 Y135.014 E.11942
G1 X87.705 Y133.189 E.13394
; CHANGE_LAYER
; Z_HEIGHT: 7.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X89.12 Y134.603 E-.76
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
G1 X126.293 Y120.267
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X126.635 Y120.112 E.01245
G3 X127.786 Y119.863 I1.348 J3.446 E.03924
G3 X130.694 Y126.077 I.192 J3.698 E.29108
G3 X126.24 Y120.294 I-2.711 J-2.519 E.42636
G1 X126.479 Y120.614 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.778 Y120.478 E.0101
G3 X127.807 Y120.255 I1.205 J3.081 E.0325
G1 X128.16 Y120.255 E.01083
G3 X126.425 Y120.641 I-.176 J3.304 E.58347
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.14772
G1 X127.113 Y120.367 E-.1339
G1 X127.457 Y120.293 E-.1339
G1 X127.807 Y120.255 E-.13389
G1 X128.16 Y120.255 E-.13391
G1 X128.36 Y120.277 E-.07668
; WIPE_END
G1 E-.04 F1800
G1 X121.723 Y124.044 Z7.8 F36000
G1 X99.729 Y136.528 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.501 Y136.231 E.01244
G3 X102.331 Y130.407 I3.027 J-2.129 E.2615
G1 X102.725 Y130.407 E.01307
G3 X99.771 Y136.571 I-.197 J3.695 E.48223
G1 X100.033 Y136.28 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.822 Y136.005 E.01065
G3 X102.351 Y130.799 I2.706 J-1.903 E.21655
G1 X102.704 Y130.799 E.01083
G3 X100.075 Y136.322 I-.176 J3.303 E.39881
; WIPE_START
M204 S10000
G1 X99.822 Y136.005 E-.15403
G1 X99.632 Y135.709 E-.13382
G1 X99.478 Y135.392 E-.13395
G1 X99.358 Y135.061 E-.13385
G1 X99.275 Y134.718 E-.13391
G1 X99.25 Y134.535 E-.07045
; WIPE_END
G1 E-.04 F1800
G1 X106.863 Y133.995 Z7.8 F36000
G1 X151.749 Y130.811 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.091 Y130.656 E.01245
G3 X153.242 Y130.407 I1.348 J3.446 E.03924
G1 X153.636 Y130.407 E.01307
G3 X151.696 Y130.839 I-.197 J3.695 E.70447
G1 X151.923 Y131.163 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.01049
G3 X153.263 Y130.799 I1.205 J3.08 E.0325
G1 X153.615 Y130.799 E.01083
G3 X151.87 Y131.191 I-.176 J3.303 E.58298
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.15253
G1 X152.568 Y130.911 E-.13391
G1 X152.913 Y130.837 E-.13389
G1 X153.263 Y130.799 E-.1339
G1 X153.615 Y130.799 E-.13391
G1 X153.804 Y130.819 E-.07186
; WIPE_END
G1 E-.04 F1800
G1 X153.512 Y138.446 Z7.8 F36000
G1 X153.292 Y144.224 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03058
G2 X102.682 Y144.213 I-24.821 J16.134 E1.98337
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.386 J1.746 E.04339
G3 X88.422 Y132.042 I2.759 J2.148 E.03306
G2 X91.148 Y129.685 I-13.377 J-18.23 E.11968
G2 X93.594 Y126.16 I-11.287 J-10.443 E.14278
G3 X94.42 Y124.708 I12.326 J6.05 E.05546
G3 X95.012 Y124.286 I1.249 J1.125 E.02432
G2 X97.525 Y123.019 I-21.174 J-45.114 E.09336
G2 X101.007 Y120.323 I-8.609 J-14.714 E.14649
G3 X102.746 Y118.697 I16.199 J15.581 E.07901
G3 X103.976 Y118.067 I2.75 J3.855 E.04602
G2 X107.048 Y116.997 I-16.533 J-52.408 E.10791
G2 X110.366 Y115.274 I-7.763 J-19.01 E.12421
G3 X112.192 Y114.202 I10.967 J16.578 E.07025
G3 X113.876 Y113.812 I2.035 J4.969 E.05759
G2 X117.401 Y113.355 I-2.348 J-31.916 E.11797
G2 X120.397 Y112.432 I-3.463 J-16.567 E.10415
G3 X122.452 Y111.606 I9.396 J20.386 E.0735
G3 X123.43 Y111.594 I.513 J2.043 E.03277
M73 P87 R2
G2 X125.813 Y112.005 I37.947 J-213.215 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16543
G3 X132.968 Y111.545 I4.714 J21.68 E.07369
G3 X133.236 Y111.55 I.102 J1.677 E.0089
G3 X134.409 Y111.943 I-.932 J4.726 E.04115
G2 X137.511 Y113.104 I10.354 J-22.942 E.10994
G2 X140.702 Y113.674 I5.147 J-19.606 E.10764
G3 X143.068 Y113.961 I-1.514 J22.331 E.0791
G3 X144.643 Y114.679 I-1.435 J5.236 E.05765
G2 X148.014 Y116.604 I17.394 J-26.557 E.12887
G2 X151.657 Y117.949 I12.732 J-28.867 E.12888
G3 X153.296 Y118.756 I-1.461 J5.035 E.06094
G3 X154.769 Y120.137 I-13.745 J16.129 E.067
G2 X158.903 Y123.348 I14.663 J-14.612 E.17409
G3 X161.003 Y124.671 I-9.768 J17.842 E.08239
G3 X161.85 Y125.632 I-2.914 J3.42 E.04264
G2 X163.679 Y128.323 I49.945 J-31.983 E.10796
G2 X166.201 Y131.081 I16.837 J-12.864 E.12413
G3 X167.71 Y132.567 I-14.874 J16.609 E.07026
G3 X168.522 Y134.094 I-4.096 J3.158 E.05763
G1 X168.658 Y134.455 E.01279
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.788 E1.86597
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.135 J2.086 E.05195
G3 X88.176 Y131.736 I3.01 J2.241 E.03509
G2 X90.863 Y129.416 I-14.238 J-19.202 E.10919
G2 X93.249 Y125.974 I-11.007 J-10.178 E.12911
G3 X94.112 Y124.465 I12.344 J6.058 E.05347
G3 X94.828 Y123.94 I1.545 J1.357 E.02749
G2 X97.331 Y122.678 I-21.211 J-45.193 E.08613
G2 X100.735 Y120.04 I-8.415 J-14.375 E.13271
G3 X102.511 Y118.382 I16.283 J15.666 E.0747
G3 X103.844 Y117.698 I2.997 J4.195 E.04619
G2 X106.325 Y116.856 I-156.179 J-464.584 E.08052
G2 X110.161 Y114.94 I-7.083 J-18.976 E.13198
G3 X112.029 Y113.845 I11.123 J16.832 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.543 E.10819
G2 X120.249 Y112.069 I-3.378 J-16.161 E.09422
G3 X122.349 Y111.227 I9.356 J20.291 E.06955
G3 X123.486 Y111.206 I.613 J2.411 E.03526
G2 X125.869 Y111.616 I39.597 J-222.773 E.07429
G2 X130.712 Y111.521 I2.13 J-14.776 E.1495
G3 X132.852 Y111.159 I5.309 J24.932 E.06671
G3 X133.276 Y111.159 I.212 J2.633 E.01303
G3 X134.559 Y111.581 I-.935 J5.011 E.04162
G2 X137.615 Y112.726 I10.231 J-22.652 E.10037
G2 X140.743 Y113.284 I5.04 J-19.215 E.09773
G3 X143.156 Y113.579 I-1.533 J22.528 E.07473
G3 X144.845 Y114.343 I-1.516 J5.603 E.05722
G2 X148.18 Y116.248 I17.228 J-26.289 E.11809
G2 X151.784 Y117.578 I12.596 J-28.589 E.11809
G3 X153.539 Y118.448 I-1.58 J5.394 E.06053
G3 X155.042 Y119.856 I-13.958 J16.405 E.06329
G2 X159.105 Y123.012 I14.388 J-14.33 E.15851
G3 X161.075 Y124.229 I-11.664 J21.077 E.07118
G3 X162.172 Y125.409 I-2.91 J3.808 E.04973
G2 X163.992 Y128.087 I49.807 J-31.888 E.09952
G2 X166.471 Y130.797 I16.518 J-12.621 E.11298
G3 X168.012 Y132.318 I-14.978 J16.722 E.06657
G3 X168.887 Y133.952 I-4.41 J3.413 E.05722
G1 X169.137 Y134.615 E.02177
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49802
G1 X152.091 Y143.084 E-.26198
; WIPE_END
G1 E-.04 F1800
G1 X155.796 Y142.438 Z7.8 F36000
G1 Z7.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42217
G1 F15000
G1 X125.667 Y112.31 E1.31677
G3 X125.041 Y112.22 I.811 J-7.872 E.01956
G1 X155.345 Y142.524 E1.32444
G1 X155.017 Y142.732 E.01201
G1 X124.389 Y112.103 E1.33863
G1 X123.736 Y111.987 E.02049
G1 X154.689 Y142.941 E1.35282
G1 X154.362 Y143.149 E.01201
G1 X123.11 Y111.898 E1.36585
G2 X122.595 Y111.919 I-.196 J1.517 E.01601
G1 X154.034 Y143.358 E1.37404
G1 X153.706 Y143.566 E.01201
G1 X151.603 Y141.463 E.09191
G1 X162.682 Y138.061 F36000
G1 F15000
G1 X157.149 Y132.528 E.2418
G3 X157.391 Y133.306 I-3.745 J1.59 E.02522
G1 X162.231 Y138.146 E.21154
G1 X161.903 Y138.355 E.01201
G1 X157.468 Y133.92 E.19381
G3 X157.46 Y134.448 I-6.957 J.158 E.01633
G1 X161.575 Y138.563 E.17984
G1 X161.247 Y138.771 E.01201
G1 X157.391 Y134.915 E.16854
G3 X157.279 Y135.34 I-2.044 J-.311 E.01359
G1 X160.919 Y138.98 E.1591
G1 X160.591 Y139.188 E.01201
G1 X157.132 Y135.729 E.1512
G3 X156.954 Y136.087 I-1.768 J-.654 E.01239
G1 X160.263 Y139.397 E.14465
G1 X159.936 Y139.605 E.01201
G1 X156.747 Y136.417 E.13934
G3 X156.512 Y136.718 I-1.527 J-.95 E.01183
G1 X159.608 Y139.814 E.13529
G1 X159.28 Y140.022 E.01201
G1 X156.252 Y136.994 E.13233
G3 X155.967 Y137.246 I-1.317 J-1.208 E.01177
G1 X158.952 Y140.231 E.13047
G1 X158.624 Y140.439 E.01201
G1 X155.656 Y137.471 E.1297
G3 X155.319 Y137.671 I-1.099 J-1.475 E.01212
G1 X158.296 Y140.648 E.13011
G1 X157.968 Y140.856 E.01201
G1 X154.953 Y137.841 E.13177
G3 X154.555 Y137.979 I-.843 J-1.793 E.01306
G1 X157.64 Y141.065 E.13486
G1 X157.313 Y141.273 E.01201
G1 X154.118 Y138.078 E.13962
G3 X153.634 Y138.131 I-.488 J-2.237 E.01506
G1 X156.985 Y141.481 E.14642
G1 X156.657 Y141.69 E.01201
G1 X153.09 Y138.123 E.1559
G3 X152.441 Y138.011 I.447 J-4.518 E.02035
G1 X156.329 Y141.898 E.1699
G1 X156.001 Y142.107 E.01201
G1 X151.571 Y137.677 E.19362
G3 X149.864 Y135.97 I1.88 J-3.587 E.07576
G1 X126.289 Y112.395 E1.03033
G2 X126.881 Y112.451 I.761 J-4.892 E.0184
G1 X149.534 Y135.103 E.99002
G3 X149.419 Y134.452 I2.99 J-.863 E.02047
G1 X127.449 Y112.482 E.96019
G2 X127.999 Y112.496 I.406 J-5.3 E.01701
G1 X149.411 Y133.908 E.93582
G3 X149.465 Y133.426 I2.282 J.012 E.01502
G1 X128.522 Y112.482 E.91534
G2 X129.028 Y112.452 I.009 J-4.146 E.01569
G1 X149.565 Y132.99 E.89758
G3 X149.703 Y132.591 I1.934 J.444 E.01306
G1 X129.521 Y112.409 E.88204
G2 X130.006 Y112.358 I-.195 J-4.145 E.01508
G1 X149.873 Y132.224 E.86827
G3 X150.071 Y131.887 I1.678 J.759 E.01213
G1 X130.474 Y112.289 E.85652
G2 X130.938 Y112.217 I-.907 J-7.408 E.01453
G1 X150.297 Y131.575 E.84605
G1 X150.547 Y131.289 E.01175
G1 X131.393 Y112.135 E.83711
G1 X131.848 Y112.054 E.01428
G1 X150.826 Y131.032 E.82943
G3 X151.13 Y130.799 I1.239 J1.305 E.01185
G1 X132.303 Y111.972 E.82283
G3 X132.768 Y111.902 I.739 J3.307 E.01457
G1 X151.459 Y130.593 E.8169
G3 X151.817 Y130.414 I1.015 J1.586 E.01238
G1 X133.308 Y111.905 E.80897
G3 X134.136 Y112.197 I-1.289 J4.977 E.02718
G1 X152.206 Y130.267 E.78976
G3 X152.631 Y130.156 I.734 J1.933 E.0136
G1 X135.055 Y112.579 E.76818
G2 X135.943 Y112.931 I6.215 J-14.378 E.02955
G1 X153.099 Y130.087 E.7498
G3 X153.622 Y130.074 I.324 J2.443 E.0162
G1 X136.775 Y113.227 E.73631
G2 X137.537 Y113.452 I2.758 J-7.923 E.02456
G1 X154.238 Y130.154 E.72993
G3 X155.014 Y130.393 I-.851 J4.133 E.02513
G1 X138.246 Y113.625 E.73285
G2 X138.916 Y113.759 I2.108 J-8.789 E.02114
G1 X162.886 Y137.729 E1.04762
G1 X163.214 Y137.521 E.01201
G1 X139.555 Y113.861 E1.03403
G2 X140.179 Y113.949 I1.437 J-8.002 E.01946
G1 X163.542 Y137.312 E1.02111
G1 X163.87 Y137.104 E.01201
G1 X140.778 Y114.012 E1.00922
G1 X141.378 Y114.076 E.01864
G1 X164.198 Y136.895 E.99733
G1 X164.526 Y136.687 E.01201
G1 X141.978 Y114.139 E.98544
G3 X142.593 Y114.218 I-.299 J4.779 E.01917
G1 X164.854 Y136.478 E.97289
G1 X165.182 Y136.27 E.01201
G1 X143.279 Y114.367 E.95727
G3 X144.345 Y114.897 I-1.717 J4.792 E.03689
G1 X165.51 Y136.061 E.92499
G1 X165.837 Y135.853 E.01201
G1 X145.703 Y115.718 E.87999
G2 X146.969 Y116.449 I8.123 J-12.624 E.04521
G1 X166.165 Y135.645 E.83895
G1 X166.493 Y135.436 E.01201
G1 X148.034 Y116.977 E.80675
G2 X148.959 Y117.366 I5.163 J-10.991 E.03102
G1 X166.821 Y135.228 E.78065
G1 X167.149 Y135.019 E.01201
G1 X149.809 Y117.679 E.75784
G1 X150.623 Y117.957 E.02656
G1 X167.477 Y134.811 E.73661
G1 X167.805 Y134.602 E.01201
G1 X151.436 Y118.234 E.71538
G3 X152.282 Y118.543 I-1.743 J6.077 E.02785
G1 X168.133 Y134.394 E.69275
G1 X168.248 Y134.32 E.00424
G2 X168.011 Y133.736 I-5.515 J1.898 E.01949
G1 X155.884 Y121.609 E.53
G2 X157.975 Y123.164 I15.75 J-18.999 E.08056
G1 X163.686 Y128.874 E.24958
G3 X162.386 Y127.039 I21.076 J-16.296 E.06953
G1 X159.355 Y124.007 E.13251
G1 X160.456 Y124.68 E.03988
G3 X161.02 Y125.136 I-2.014 J3.068 E.02247
G1 X161.916 Y126.032 E.03916
G1 X129.241 Y129.828 F36000
G1 F15000
G1 X126.84 Y127.427 E.10492
G2 X127.518 Y127.569 I1.001 J-3.1 E.02144
G1 X129.621 Y129.672 E.09191
G1 X130.203 Y129.718 E.01805
G1 X128.078 Y127.592 E.09288
G2 X128.571 Y127.549 I.043 J-2.329 E.01532
G1 X130.785 Y129.763 E.09678
G3 X131.383 Y129.825 I-.287 J5.738 E.01858
G1 X129.016 Y127.457 E.10346
G2 X129.421 Y127.327 I-.408 J-1.961 E.0132
G1 X132.001 Y129.906 E.11273
G3 X132.624 Y129.993 I-.601 J6.566 E.01947
G1 X129.794 Y127.163 E.12371
G2 X130.137 Y126.969 I-.731 J-1.698 E.01219
G1 X133.279 Y130.111 E.13732
G1 X133.933 Y130.23 E.02056
G1 X130.453 Y126.749 E.15211
G2 X130.744 Y126.504 I-1.006 J-1.487 E.01178
G1 X134.618 Y130.378 E.16931
G1 X135.324 Y130.547 E.02243
G1 X131.008 Y126.232 E.18859
G2 X131.246 Y125.933 I-1.276 J-1.256 E.01182
G1 X136.053 Y130.74 E.21011
G1 X136.815 Y130.966 E.02456
G1 X131.457 Y125.608 E.23417
G2 X131.641 Y125.256 I-1.556 J-1.037 E.01231
G1 X137.608 Y131.223 E.26078
G1 X138.439 Y131.517 E.02722
G1 X131.795 Y124.873 E.29035
G2 X131.914 Y124.456 I-1.893 J-.766 E.01344
G1 X139.326 Y131.868 E.32394
G3 X140.252 Y132.257 I-3.247 J9.017 E.03104
G1 X131.992 Y123.997 E.36099
G2 X132.018 Y123.487 I-2.375 J-.376 E.01583
G1 X141.277 Y132.746 E.40468
G3 X142.408 Y133.341 I-5.108 J11.09 E.03949
G1 X131.959 Y122.892 E.45664
G2 X131.77 Y122.167 I-5.037 J.925 E.02318
M73 P88 R2
G1 X144.212 Y134.609 E.54376
G1 X146.081 Y135.941 F36000
G1 F15000
G1 X122.188 Y112.048 E1.04426
G2 X121.808 Y112.204 I.692 J2.223 E.01272
G1 X129.381 Y119.777 E.33098
G2 X128.647 Y119.58 I-1.287 J3.329 E.02351
G1 X121.429 Y112.362 E.31546
G1 X121.051 Y112.52 E.01267
G1 X128.061 Y119.53 E.30635
G2 X127.548 Y119.553 I-.146 J2.41 E.01589
G1 X120.673 Y112.678 E.30048
G3 X120.288 Y112.83 I-2.603 J-6.017 E.01277
G1 X127.088 Y119.63 E.29719
G2 X126.671 Y119.749 I.348 J2.014 E.01344
G1 X119.9 Y112.978 E.29592
G3 X119.508 Y113.123 I-1.739 J-4.113 E.01291
G1 X126.289 Y119.903 E.29634
G2 X125.937 Y120.088 I.687 J1.736 E.0123
G1 X119.104 Y113.255 E.29861
G3 X118.692 Y113.38 I-1.512 J-4.271 E.01331
G1 X125.613 Y120.3 E.30247
G2 X125.315 Y120.538 I.967 J1.516 E.01182
G1 X118.272 Y113.496 E.3078
G3 X117.838 Y113.598 I-1.265 J-4.382 E.01378
G1 X125.042 Y120.802 E.31481
G2 X124.793 Y121.09 I1.221 J1.303 E.01177
G1 X117.398 Y113.695 E.3232
G1 X116.946 Y113.778 E.01422
G1 X124.572 Y121.405 E.3333
G2 X124.379 Y121.748 I1.515 J1.075 E.0122
G1 X116.482 Y113.851 E.34515
G1 X116.014 Y113.919 E.01462
G1 X124.216 Y122.121 E.35846
G2 X124.085 Y122.527 I1.834 J.815 E.01319
G1 X115.534 Y113.976 E.37372
G1 X115.049 Y114.027 E.01507
G1 X123.993 Y122.971 E.39088
G2 X123.948 Y123.463 I9.322 J1.087 E.01527
G1 X114.564 Y114.079 E.41013
G1 X114.08 Y114.13 E.01507
G1 X123.979 Y124.03 E.43267
G2 X124.112 Y124.699 I3.197 J-.286 E.02112
G1 X113.595 Y114.182 E.45965
G2 X113.137 Y114.26 I.368 J3.548 E.01438
G1 X128.516 Y129.639 E.67214
G2 X127.966 Y129.626 I-.404 J5.242 E.017
G1 X112.703 Y114.363 E.66704
G2 X112.316 Y114.512 I1.801 J5.258 E.01283
G1 X127.443 Y129.639 E.66113
G1 X126.921 Y129.653 E.01616
G1 X111.962 Y114.694 E.65378
G2 X111.625 Y114.894 I1.246 J2.481 E.0121
G1 X126.399 Y129.668 E.64568
G1 X125.902 Y129.707 E.01541
G1 X111.291 Y115.096 E.63855
G1 X110.957 Y115.298 E.01207
G1 X125.404 Y129.746 E.63142
G1 X124.907 Y129.785 E.01541
G1 X110.623 Y115.501 E.62429
G1 X110.289 Y115.703 E.01207
G1 X124.431 Y129.845 E.61807
G1 X123.957 Y129.907 E.01477
G1 X109.955 Y115.905 E.61196
G1 X109.621 Y116.107 E.01207
G1 X123.483 Y129.97 E.60585
G2 X123.022 Y130.045 I.491 J4.433 E.01444
G1 X109.275 Y116.299 E.6008
G1 X108.927 Y116.487 E.01223
G1 X122.57 Y130.129 E.59624
G1 X122.117 Y130.213 E.01422
G1 X108.575 Y116.671 E.59187
G1 X108.214 Y116.847 E.01239
G1 X121.669 Y130.301 E.58803
G1 X121.236 Y130.405 E.01375
G1 X107.847 Y117.015 E.58519
G1 X107.476 Y117.18 E.01256
G1 X120.804 Y130.509 E.58251
G1 X120.371 Y130.612 E.01375
G1 X107.091 Y117.333 E.5804
G1 X106.707 Y117.485 E.01277
G1 X119.952 Y130.729 E.57884
G1 X119.538 Y130.852 E.01334
G1 X106.312 Y117.626 E.57802
G1 X105.912 Y117.762 E.01307
G1 X119.124 Y130.974 E.57744
G2 X118.711 Y131.098 I.97 J3.994 E.01332
G1 X105.511 Y117.898 E.5769
G1 X105.111 Y118.034 E.01307
G1 X118.315 Y131.238 E.5771
G1 X117.919 Y131.378 E.01299
G1 X104.71 Y118.17 E.57729
G1 X104.31 Y118.305 E.01307
G1 X117.523 Y131.519 E.57748
G2 X117.132 Y131.664 I1.193 J3.794 E.01289
G1 X103.92 Y118.452 E.57745
G1 X103.543 Y118.611 E.01266
G1 X116.753 Y131.821 E.57737
G1 X116.374 Y131.979 E.01269
G1 X103.194 Y118.799 E.57603
G2 X102.882 Y119.023 I.705 J1.314 E.01191
G1 X115.995 Y132.136 E.57311
G2 X115.624 Y132.301 I1.392 J3.625 E.01256
G1 X102.59 Y119.267 E.56964
G1 X102.315 Y119.529 E.01172
G1 X115.261 Y132.474 E.56578
G1 X114.897 Y132.647 E.01243
G1 X102.04 Y119.79 E.56192
G1 X101.765 Y120.052 E.01172
G1 X114.534 Y132.821 E.55806
G2 X114.181 Y133.003 I1.566 J3.466 E.01231
G1 X101.491 Y120.313 E.55462
G1 X101.216 Y120.575 E.01172
G1 X113.833 Y133.192 E.55144
G1 X113.485 Y133.381 E.01222
G1 X100.941 Y120.836 E.54826
G1 X100.666 Y121.098 E.01172
G1 X113.138 Y133.569 E.54508
G2 X112.8 Y133.768 I1.722 J3.317 E.01211
G1 X100.382 Y121.35 E.54272
G1 X100.095 Y121.599 E.01175
G1 X112.467 Y133.972 E.54075
G1 X112.135 Y134.175 E.01205
G1 X99.805 Y121.845 E.53889
G1 X99.503 Y122.08 E.01181
G1 X111.802 Y134.379 E.53756
G2 X111.479 Y134.592 I1.866 J3.183 E.01197
G1 X99.201 Y122.314 E.53663
G3 X98.892 Y122.542 I-1.938 J-2.297 E.01186
G1 X111.161 Y134.811 E.53621
G1 X110.843 Y135.029 E.01192
G1 X98.573 Y122.759 E.53628
G3 X98.249 Y122.971 I-2.145 J-2.914 E.01198
G1 X110.525 Y135.248 E.53654
G2 X110.216 Y135.474 I2.006 J3.067 E.01187
G1 X97.914 Y123.173 E.53762
G3 X97.575 Y123.37 I-2.035 J-3.12 E.01213
G1 X109.912 Y135.707 E.5392
G1 X109.609 Y135.94 E.01182
G1 X106.267 Y132.598 E.14605
G3 X106.488 Y133.356 I-3.798 J1.521 E.02443
G1 X109.305 Y136.173 E.12311
G2 X109.008 Y136.412 I2.137 J2.951 E.01179
G1 X106.56 Y133.964 E.107
G3 X106.544 Y134.484 I-7.063 J.037 E.01608
G1 X108.719 Y136.66 E.09508
G1 X108.43 Y136.907 E.01176
G1 X106.471 Y134.948 E.08561
G3 X106.357 Y135.37 I-2.031 J-.325 E.01353
G1 X108.141 Y137.154 E.07797
G2 X107.856 Y137.406 I2.259 J2.835 E.01175
G1 X106.207 Y135.756 E.07209
G3 X106.027 Y136.112 I-1.76 J-.668 E.01236
G1 X107.581 Y137.667 E.06794
G1 X107.306 Y137.928 E.01172
G1 X105.819 Y136.441 E.065
G1 X105.583 Y136.741 E.01181
G1 X107.031 Y138.189 E.06328
G2 X106.759 Y138.453 I2.386 J2.729 E.01173
G1 X105.32 Y137.015 E.06286
G3 X105.033 Y137.264 I-1.311 J-1.222 E.01177
G1 X106.497 Y138.728 E.06401
G1 X106.236 Y139.004 E.01172
G1 X104.72 Y137.488 E.06626
G3 X104.381 Y137.685 I-1.091 J-1.489 E.01215
G1 X105.975 Y139.279 E.06968
G2 X105.715 Y139.555 I2.504 J2.614 E.01173
G1 X104.012 Y137.852 E.07442
G3 X103.611 Y137.988 I-.832 J-1.808 E.01311
G1 X105.468 Y139.845 E.08116
G1 X105.221 Y140.134 E.01176
G1 X103.171 Y138.084 E.08959
G3 X102.684 Y138.133 I-.473 J-2.255 E.01516
G1 X104.974 Y140.423 E.10008
G1 X104.727 Y140.712 E.01176
G1 X102.135 Y138.121 E.11327
G3 X101.474 Y137.996 I.59 J-4.933 E.02081
G1 X104.494 Y141.015 E.13198
G1 X104.261 Y141.319 E.01182
G1 X92.07 Y129.128 E.5328
G1 X91.821 Y129.416 E.01175
G1 X104.028 Y141.622 E.53349
G1 X103.795 Y141.926 E.01182
G1 X91.573 Y129.704 E.53418
G3 X91.318 Y129.985 I-1.805 J-1.377 E.01175
G1 X103.575 Y142.242 E.53568
G1 X103.356 Y142.56 E.01192
G1 X91.047 Y130.25 E.53798
G1 X90.776 Y130.515 E.01172
G1 X103.138 Y142.878 E.54029
G1 X102.919 Y143.195 E.01192
G1 X90.501 Y130.777 E.54276
G1 X90.212 Y131.024 E.01176
G1 X102.713 Y143.525 E.54636
G1 X102.579 Y143.744 E.00793
G1 X102.03 Y143.379 E.02038
G1 X89.923 Y131.272 E.52914
G3 X89.629 Y131.514 I-3.547 J-4.003 E.01178
G1 X100.425 Y142.311 E.47187
G1 X98.821 Y141.243 E.05956
G1 X89.33 Y131.752 E.4148
G1 X89.032 Y131.989 E.0118
G1 X97.217 Y140.175 E.35773
G1 X95.612 Y139.107 E.05956
G1 X88.733 Y132.227 E.30066
G1 X88.434 Y132.465 E.0118
G1 X94.008 Y138.039 E.24359
G1 X92.404 Y136.971 E.05956
G1 X88.154 Y132.721 E.18575
G2 X87.933 Y133.036 I.427 J.534 E.01207
G1 X90.799 Y135.903 E.12528
G1 X89.195 Y134.835 E.05956
G1 X87.663 Y133.303 E.06696
G1 X98.897 Y135.418 F36000
G1 F15000
G1 X92.308 Y128.83 E.28795
G1 X92.537 Y128.522 E.01185
G1 X98.513 Y134.499 E.26121
G3 X98.497 Y133.946 I5.797 J-.454 E.01711
G1 X92.759 Y128.208 E.25075
G1 X92.973 Y127.886 E.01196
G1 X98.547 Y133.46 E.24361
G3 X98.644 Y133.021 I2.103 J.235 E.01393
G1 X93.18 Y127.557 E.2388
G1 X93.379 Y127.219 E.0121
G1 X98.779 Y132.619 E.236
G3 X98.947 Y132.251 I1.81 J.599 E.01254
G1 X93.578 Y126.882 E.23462
G2 X93.768 Y126.536 I-4.602 J-2.75 E.01221
G1 X99.143 Y131.91 E.2349
G3 X99.366 Y131.597 I1.573 J.882 E.01191
G1 X93.957 Y126.188 E.2364
G1 X94.145 Y125.84 E.01223
G1 X99.616 Y131.311 E.23911
G3 X99.893 Y131.051 I1.354 J1.166 E.01175
G1 X94.334 Y125.492 E.24297
G3 X94.527 Y125.149 I2.823 J1.369 E.01217
G1 X100.195 Y130.817 E.24769
G3 X100.522 Y130.608 I1.138 J1.426 E.01203
G1 X94.756 Y124.841 E.25203
G3 X95.082 Y124.631 I.891 J1.024 E.01203
G1 X100.878 Y130.427 E.25331
G3 X101.264 Y130.277 I.895 J1.732 E.01283
G1 X95.437 Y124.45 E.25469
G1 X95.797 Y124.274 E.01239
G1 X101.686 Y130.163 E.25739
G3 X102.151 Y130.091 I.567 J2.137 E.01456
G1 X96.157 Y124.098 E.26195
G1 X96.518 Y123.922 E.01239
G1 X102.67 Y130.074 E.26889
G3 X103.275 Y130.142 I-.245 J4.877 E.01882
G1 X96.875 Y123.743 E.27968
G1 X97.225 Y123.556 E.01225
G1 X104.388 Y130.719 E.31306
; CHANGE_LAYER
; Z_HEIGHT: 7.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X102.974 Y129.305 E-.76
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
G1 X126.293 Y120.267
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X126.635 Y120.112 E.01244
M73 P89 R2
G3 X127.786 Y119.863 I1.348 J3.447 E.03924
G1 X128.181 Y119.863 E.01307
G3 X126.24 Y120.294 I-.197 J3.696 E.70462
G1 X126.475 Y120.615 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.778 Y120.478 E.01024
G3 X127.807 Y120.255 I1.205 J3.08 E.0325
G1 X128.16 Y120.255 E.01083
G3 X126.421 Y120.643 I-.176 J3.303 E.58323
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.14938
G1 X127.113 Y120.367 E-.1339
G1 X127.457 Y120.293 E-.13389
G1 X127.807 Y120.255 E-.13389
G1 X128.16 Y120.255 E-.13391
G1 X128.356 Y120.276 E-.07502
; WIPE_END
G1 E-.04 F1800
G1 X135.312 Y123.418 Z8 F36000
G1 X151.715 Y130.829 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.732 Y130.819 E.00063
G3 X153.242 Y130.407 I1.707 J3.283 E.05232
G1 X153.636 Y130.407 E.01307
G3 X151.392 Y131.02 I-.197 J3.695 E.69274
G1 X151.664 Y130.859 E.01046
G1 X151.918 Y131.165 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.01064
G3 X153.263 Y130.799 I1.205 J3.08 E.0325
G1 X153.615 Y130.799 E.01083
G3 X151.865 Y131.193 I-.176 J3.303 E.58283
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.15434
G1 X152.568 Y130.911 E-.13391
G1 X152.913 Y130.837 E-.13389
G1 X153.263 Y130.799 E-.13389
G1 X153.615 Y130.799 E-.13392
G1 X153.799 Y130.819 E-.07005
; WIPE_END
G1 E-.04 F1800
G1 X146.209 Y131.625 Z8 F36000
G1 X99.754 Y136.557 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.741 Y136.543 E.00063
G3 X102.331 Y130.407 I2.787 J-2.438 E.2747
G1 X102.725 Y130.407 E.01308
G3 X100.016 Y136.826 I-.197 J3.698 E.47091
G1 X99.796 Y136.6 E.01045
G1 X100.034 Y136.282 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.819 Y136.008 E.01073
G3 X102.351 Y130.799 I2.709 J-1.903 E.21664
G1 X102.704 Y130.799 E.01083
G3 X100.074 Y136.327 I-.176 J3.306 E.39904
; WIPE_START
M204 S10000
G1 X99.819 Y136.008 E-.15546
G1 X99.632 Y135.709 E-.13388
G1 X99.478 Y135.392 E-.13393
G1 X99.358 Y135.061 E-.13387
G1 X99.275 Y134.718 E-.1339
G1 X99.251 Y134.538 E-.06896
; WIPE_END
G1 E-.04 F1800
G1 X106.763 Y135.885 Z8 F36000
G1 X153.292 Y144.224 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03058
G2 X102.682 Y144.213 I-24.821 J16.133 E1.98339
G1 X87.298 Y133.972 E.61306
G3 X87.706 Y132.731 I7.391 J1.748 E.04338
G3 X88.408 Y132.053 I2.737 J2.128 E.03249
G2 X91.148 Y129.685 I-14.523 J-19.576 E.12025
G2 X93.594 Y126.16 I-11.288 J-10.443 E.14277
G3 X94.42 Y124.708 I12.314 J6.044 E.05547
G3 X95.012 Y124.286 I1.249 J1.127 E.0243
G2 X97.525 Y123.019 I-21.491 J-45.743 E.09337
G2 X101.007 Y120.323 I-8.608 J-14.713 E.14648
G3 X102.746 Y118.696 I16.201 J15.583 E.07902
G3 X103.976 Y118.067 I2.75 J3.857 E.04601
G2 X107.047 Y116.997 I-16.542 J-52.434 E.10789
G2 X110.366 Y115.274 I-7.764 J-19.012 E.12423
G3 X112.192 Y114.201 I10.957 J16.563 E.07027
G3 X113.876 Y113.812 I2.035 J4.969 E.05757
G2 X117.401 Y113.355 I-2.347 J-31.914 E.11797
G2 X120.397 Y112.432 I-3.463 J-16.568 E.10414
G3 X122.452 Y111.605 I9.4 J20.396 E.0735
G3 X123.43 Y111.594 I.513 J2.043 E.03276
G2 X125.813 Y112.005 I38.025 J-213.676 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16543
G3 X132.966 Y111.545 I4.73 J21.77 E.07363
G3 X133.236 Y111.55 I.103 J1.679 E.00897
G3 X134.409 Y111.943 I-.932 J4.724 E.04115
G2 X137.511 Y113.104 I10.354 J-22.942 E.10994
G2 X140.701 Y113.674 I5.147 J-19.606 E.10761
G3 X143.068 Y113.962 I-1.495 J22.174 E.07914
G3 X144.643 Y114.679 I-1.436 J5.238 E.05764
G2 X148.015 Y116.604 I17.386 J-26.543 E.12887
G2 X151.657 Y117.949 I12.727 J-28.853 E.12887
G3 X153.297 Y118.757 I-1.46 J5.034 E.06097
G3 X154.769 Y120.137 I-13.78 J16.165 E.06695
G2 X158.903 Y123.348 I14.664 J-14.614 E.1741
G3 X161.003 Y124.671 I-9.762 J17.833 E.08239
G3 X161.85 Y125.632 I-2.914 J3.42 E.04265
G2 X163.68 Y128.324 I49.904 J-31.955 E.10797
G2 X166.202 Y131.082 I16.836 J-12.863 E.12416
G3 X167.71 Y132.567 I-14.87 J16.604 E.07023
G3 X168.522 Y134.093 I-4.095 J3.158 E.0576
G1 X168.658 Y134.455 E.01282
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.783 E1.86607
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.136 J2.086 E.05195
G3 X88.162 Y131.747 I2.989 J2.223 E.03455
G2 X90.863 Y129.416 I-14.317 J-19.314 E.10973
G2 X93.249 Y125.974 I-11.006 J-10.177 E.1291
G3 X94.112 Y124.464 I12.336 J6.054 E.05348
G3 X94.828 Y123.94 I1.545 J1.358 E.02748
G2 X97.331 Y122.678 I-21.535 J-45.835 E.08613
G2 X100.735 Y120.04 I-8.415 J-14.374 E.13271
G3 X102.512 Y118.382 I16.29 J15.674 E.0747
G3 X103.844 Y117.698 I2.998 J4.196 E.04619
G2 X106.326 Y116.856 I-155.404 J-462.295 E.08053
G2 X110.161 Y114.94 I-7.084 J-18.976 E.13197
G3 X112.029 Y113.845 I11.11 J16.809 E.06659
G3 X113.833 Y113.423 I2.199 J5.333 E.05717
G2 X117.323 Y112.971 I-2.308 J-31.537 E.10818
G2 X120.249 Y112.069 I-3.378 J-16.161 E.09421
G3 X122.349 Y111.227 I9.362 J20.307 E.06955
G3 X123.486 Y111.206 I.613 J2.41 E.03525
G2 X125.869 Y111.616 I39.699 J-223.373 E.0743
G2 X130.712 Y111.521 I2.13 J-14.776 E.1495
G3 X132.949 Y111.153 I4.708 J21.655 E.06968
G3 X133.276 Y111.159 I.123 J2.035 E.01006
G3 X134.559 Y111.581 I-.934 J5.009 E.04162
G2 X137.615 Y112.726 I10.23 J-22.651 E.10037
G2 X140.743 Y113.284 I5.04 J-19.213 E.09772
G3 X143.156 Y113.579 I-1.513 J22.364 E.07474
G3 X144.845 Y114.343 I-1.517 J5.603 E.0572
G2 X148.18 Y116.248 I17.229 J-26.29 E.11808
G2 X151.783 Y117.578 I12.593 J-28.58 E.1181
G3 X153.54 Y118.449 I-1.58 J5.392 E.06056
G3 X155.042 Y119.856 I-13.977 J16.423 E.06325
G2 X159.105 Y123.012 I14.39 J-14.331 E.15852
G3 X161.075 Y124.23 I-11.663 J21.075 E.07119
G3 X162.172 Y125.409 I-2.911 J3.809 E.04973
G2 X163.993 Y128.088 I49.791 J-31.878 E.09953
G2 X166.471 Y130.797 I16.518 J-12.623 E.11297
G3 X168.012 Y132.318 I-14.981 J16.724 E.06657
G3 X168.887 Y133.951 I-4.411 J3.413 E.0572
G1 X169.137 Y134.615 E.02178
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49802
G1 X152.091 Y143.084 E-.26198
; WIPE_END
G1 E-.04 F1800
G1 X151.56 Y141.408 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42164
G1 F15000
G1 X155.273 Y137.694 E.16205
G3 X154.415 Y138.017 I-1.864 J-3.658 E.02834
G1 X151.449 Y140.984 E.12948
G2 X151.214 Y140.682 I-2.984 J2.082 E.01178
G1 X153.773 Y138.124 E.11167
G3 X153.231 Y138.13 I-.302 J-2.53 E.01677
G1 X150.968 Y140.394 E.09877
G1 X150.721 Y140.105 E.01172
G1 X152.749 Y138.077 E.08851
G3 X152.314 Y137.976 I.252 J-2.085 E.01381
G1 X150.474 Y139.816 E.08029
G1 X150.227 Y139.527 E.01172
M73 P89 R1
G1 X151.917 Y137.838 E.07373
G3 X151.552 Y137.667 I.617 J-1.792 E.01245
G1 X149.966 Y139.252 E.06919
G1 X149.706 Y138.977 E.01169
G1 X151.216 Y137.467 E.06591
G3 X150.906 Y137.241 I.902 J-1.56 E.01185
G1 X149.445 Y138.703 E.06379
G1 X149.184 Y138.428 E.01169
G1 X150.622 Y136.99 E.06276
G3 X150.363 Y136.714 I1.158 J-1.349 E.01172
G1 X148.911 Y138.165 E.06335
G1 X148.636 Y137.904 E.01169
G1 X150.128 Y136.413 E.06511
G1 X149.922 Y136.083 E.01199
G1 X148.361 Y137.644 E.06811
G1 X148.087 Y137.383 E.01169
G1 X149.745 Y135.725 E.07236
G3 X149.598 Y135.336 I1.747 J-.881 E.01285
G1 X147.801 Y137.133 E.07844
G1 X147.511 Y136.887 E.01173
G1 X149.487 Y134.912 E.08623
G3 X149.418 Y134.445 I2.152 J-.556 E.01458
G1 X147.221 Y136.642 E.09587
G1 X146.931 Y136.396 E.01173
G1 X149.411 Y133.917 E.1082
G3 X149.488 Y133.303 I2.908 J.058 E.01912
G1 X146.516 Y136.275 E.12972
; WIPE_START
G1 X147.931 Y134.861 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.554 Y135.224 Z8 F36000
G1 X166.335 Y135.737 Z8
G1 Z7.6
G1 E.8 F1800
G1 F15000
G1 X168.11 Y133.963 E.07744
G2 X167.946 Y133.591 I-3.504 J1.323 E.01254
G1 X165.417 Y136.12 E.11037
G1 X163.946 Y137.055 E.05378
G1 X167.765 Y133.237 E.16665
G2 X167.555 Y132.911 I-2.779 J1.557 E.01197
G1 X162.476 Y137.99 E.22168
G1 X161.005 Y138.925 E.05378
G1 X167.313 Y132.618 E.27527
G1 X167.051 Y132.344 E.01169
G1 X159.535 Y139.86 E.32802
G1 X158.064 Y140.795 E.05378
G1 X166.777 Y132.082 E.38027
G1 X166.504 Y131.82 E.01169
G1 X156.594 Y141.73 E.4325
G1 X155.123 Y142.665 E.05378
G1 X166.23 Y131.558 E.48473
G1 X165.956 Y131.297 E.01169
G1 X153.653 Y143.6 E.53696
G1 X153.399 Y143.761 E.00929
G1 X153.23 Y143.487 E.00994
G1 X165.682 Y131.035 E.54344
G1 X165.408 Y130.773 E.01169
G1 X153.022 Y143.159 E.54057
G1 X152.804 Y142.842 E.01189
G1 X165.135 Y130.511 E.53817
G1 X164.875 Y130.235 E.01169
G1 X152.586 Y142.524 E.53633
G1 X152.368 Y142.207 E.01189
G1 X164.615 Y129.96 E.5345
G3 X164.36 Y129.679 I3.261 J-3.219 E.0117
G1 X152.146 Y141.893 E.53304
G1 X151.914 Y141.59 E.01179
G1 X164.111 Y129.393 E.53232
G3 X163.868 Y129.1 I4.024 J-3.573 E.01174
G1 X157.03 Y135.937 E.29843
G2 X157.35 Y135.082 I-3.647 J-1.85 E.02823
G1 X163.629 Y128.804 E.27403
G3 X163.4 Y128.497 I3.579 J-2.912 E.01181
G1 X157.462 Y134.435 E.25914
G2 X157.466 Y133.895 I-7.057 J-.326 E.01667
G1 X163.171 Y128.19 E.24899
G3 X162.948 Y127.877 I3.095 J-2.443 E.01185
G1 X157.411 Y133.414 E.24167
G2 X157.31 Y132.98 I-2.084 J.255 E.0138
G1 X162.733 Y127.556 E.23669
G1 X162.519 Y127.236 E.01191
G1 X157.172 Y132.582 E.23335
G2 X157.002 Y132.217 I-1.794 J.614 E.01246
G1 X162.304 Y126.915 E.2314
G1 X162.089 Y126.594 E.01191
G1 X156.803 Y131.88 E.2307
G2 X156.577 Y131.57 I-1.565 J.899 E.01186
G1 X161.874 Y126.274 E.23115
G1 X161.659 Y125.953 E.01191
G1 X156.327 Y131.285 E.2327
G1 X156.049 Y131.028 E.0117
G1 X161.44 Y125.637 E.23528
G1 X161.205 Y125.336 E.01178
G1 X155.745 Y130.796 E.23831
G2 X155.415 Y130.59 I-1.128 J1.441 E.01202
G1 X160.941 Y125.064 E.24118
G2 X160.648 Y124.822 I-1.366 J1.355 E.01176
G1 X155.057 Y130.412 E.244
G2 X154.668 Y130.266 I-.882 J1.748 E.01285
G1 X160.331 Y124.603 E.24713
G1 X159.998 Y124.4 E.01202
G1 X154.244 Y130.155 E.25115
G2 X153.776 Y130.087 I-.55 J2.152 E.01462
G1 X159.666 Y124.197 E.25706
G1 X159.333 Y123.994 E.01202
G1 X153.253 Y130.074 E.26536
G2 X152.637 Y130.154 I.375 J5.283 E.01917
G1 X159.001 Y123.791 E.27773
G1 X158.668 Y123.588 E.01202
G1 X151.862 Y130.394 E.29707
G2 X149.731 Y132.525 I1.528 J3.659 E.09541
G1 X146.334 Y135.922 E.14823
G1 X146.031 Y135.689 E.01179
G1 X158.336 Y123.384 E.53703
G1 X158.004 Y123.181 E.01202
G1 X145.728 Y135.457 E.53575
G2 X145.418 Y135.231 I-2.306 J2.851 E.01184
G1 X157.683 Y122.966 E.53531
G1 X157.364 Y122.75 E.0119
G1 X145.1 Y135.013 E.53523
G1 X144.783 Y134.795 E.01189
G1 X157.049 Y122.529 E.53535
G1 X156.742 Y122.301 E.01182
G1 X144.466 Y134.577 E.53577
G2 X144.142 Y134.365 I-2.178 J2.979 E.01195
G1 X156.44 Y122.067 E.53674
G1 X156.142 Y121.83 E.01176
G1 X143.81 Y134.162 E.53822
G1 X143.478 Y133.958 E.01202
G1 X155.853 Y121.582 E.54013
G1 X155.566 Y121.334 E.01172
G1 X143.145 Y133.755 E.54209
G2 X142.807 Y133.557 I-2.051 J3.129 E.01209
G1 X155.284 Y121.081 E.54452
G1 X155.01 Y120.819 E.01169
G1 X142.46 Y133.369 E.54771
G1 X142.113 Y133.181 E.01219
G1 X154.735 Y120.558 E.5509
G1 X154.461 Y120.296 E.01169
G1 X141.766 Y132.992 E.55409
G2 X141.412 Y132.811 I-1.91 J3.29 E.01228
G1 X154.187 Y120.035 E.55758
G1 X153.913 Y119.773 E.01169
G1 X141.049 Y132.638 E.56145
G1 X140.686 Y132.465 E.0124
G1 X153.639 Y119.512 E.56532
G1 X153.367 Y119.251 E.01164
G1 X140.324 Y132.292 E.56919
G2 X139.952 Y132.127 I-1.752 J3.461 E.01254
G1 X153.073 Y119.006 E.57265
G2 X152.758 Y118.786 I-1.08 J1.213 E.0119
G1 X139.574 Y131.971 E.57541
G1 X139.195 Y131.814 E.01265
G1 X152.411 Y118.598 E.5768
G1 X152.034 Y118.439 E.01262
G1 X138.816 Y131.657 E.57689
G2 X138.425 Y131.512 I-1.575 J3.654 E.01287
G1 X151.636 Y118.302 E.57655
G1 X151.236 Y118.166 E.01302
G1 X138.03 Y131.372 E.57638
G1 X137.634 Y131.232 E.01295
G1 X150.837 Y118.029 E.57621
G1 X150.437 Y117.893 E.01302
G1 X137.239 Y131.092 E.57604
G2 X136.826 Y130.969 I-1.388 J3.918 E.0133
G1 X150.038 Y117.757 E.57662
G1 X149.638 Y117.621 E.01302
G1 X136.413 Y130.847 E.57722
G1 X135.999 Y130.725 E.0133
G1 X149.245 Y117.479 E.57808
G1 X148.861 Y117.327 E.01273
G1 X135.58 Y130.609 E.57966
G1 X135.148 Y130.505 E.01371
G1 X148.478 Y117.175 E.58179
G1 X148.107 Y117.01 E.01252
M73 P90 R1
G1 X134.716 Y130.401 E.58446
G1 X134.284 Y130.298 E.01371
G1 X147.741 Y116.841 E.58731
G1 X147.381 Y116.665 E.01236
G1 X133.836 Y130.21 E.59116
G1 X133.384 Y130.127 E.01418
G1 X147.029 Y116.481 E.59554
G1 X146.682 Y116.293 E.0122
G1 X132.932 Y130.043 E.60009
G2 X132.471 Y129.968 I-.945 J4.358 E.01441
G1 X146.337 Y116.102 E.60516
G1 X146.003 Y115.9 E.01204
G1 X131.998 Y129.906 E.61125
G1 X131.525 Y129.843 E.01473
G1 X145.67 Y115.698 E.61734
G1 X145.336 Y115.496 E.01204
G1 X131.048 Y129.784 E.62357
G1 X130.552 Y129.745 E.01537
G1 X145.002 Y115.295 E.63067
G1 X144.669 Y115.093 E.01204
G1 X130.055 Y129.706 E.63777
G1 X129.559 Y129.667 E.01537
G1 X144.335 Y114.891 E.64488
G2 X143.998 Y114.692 I-1.57 J2.267 E.01207
G1 X129.037 Y129.653 E.65296
G1 X128.515 Y129.639 E.01611
G1 X143.644 Y114.51 E.66028
G2 X143.258 Y114.361 I-2.258 J5.27 E.01278
G1 X127.994 Y129.625 E.6662
G2 X127.444 Y129.639 I-.144 J5.185 E.01697
G1 X142.825 Y114.258 E.6713
G2 X142.367 Y114.18 I-.825 J3.485 E.01435
G1 X131.857 Y124.691 E.45871
G2 X131.988 Y124.024 I-3.056 J-.949 E.02102
G1 X141.883 Y114.129 E.43184
G1 X141.399 Y114.078 E.01503
G1 X132.019 Y123.458 E.40939
G2 X131.974 Y122.967 I-9.807 J.652 E.01521
G1 X140.914 Y114.027 E.39021
G1 X140.43 Y113.975 E.01503
G1 X131.881 Y122.524 E.37311
G2 X131.75 Y122.119 I-1.959 J.409 E.01315
G1 X139.951 Y113.919 E.3579
G1 X139.483 Y113.851 E.01458
G1 X131.587 Y121.747 E.34463
G2 X131.394 Y121.404 I-1.703 J.729 E.01216
G1 X139.02 Y113.778 E.33282
G1 X138.568 Y113.694 E.01418
G1 X131.174 Y121.089 E.32274
G2 X130.926 Y120.802 I-1.469 J1.016 E.01174
G1 X138.129 Y113.598 E.31438
G3 X137.696 Y113.496 I.83 J-4.48 E.01374
G1 X130.653 Y120.539 E.30738
G2 X130.355 Y120.301 I-1.262 J1.275 E.01178
G1 X137.276 Y113.38 E.30206
G3 X136.864 Y113.256 I1.101 J-4.404 E.01327
G1 X130.032 Y120.089 E.29821
G2 X129.681 Y119.904 I-1.04 J1.551 E.01226
G1 X136.461 Y113.124 E.29593
G3 X136.07 Y112.98 I1.345 J-4.257 E.01288
G1 X129.299 Y119.75 E.2955
G2 X128.883 Y119.631 I-.766 J1.89 E.01339
G1 X135.682 Y112.832 E.29675
G3 X135.298 Y112.68 I2.29 J-6.364 E.01274
G1 X128.424 Y119.554 E.29999
G2 X127.913 Y119.53 I-.369 J2.38 E.01583
G1 X134.92 Y112.523 E.30581
G1 X134.542 Y112.365 E.01264
G1 X127.329 Y119.578 E.31479
G2 X126.598 Y119.773 I.547 J3.514 E.02338
G1 X134.163 Y112.208 E.33017
G2 X133.784 Y112.052 I-1.308 J2.631 E.01267
G1 X110.726 Y135.11 E1.00634
G3 X112.293 Y134.079 I10.616 J14.425 E.0579
G1 X124.191 Y122.181 E.51927
G2 X124.006 Y122.901 I5.215 J1.721 E.02297
G1 X113.575 Y133.332 E.45524
G3 X114.702 Y132.74 I6.213 J10.467 E.0393
G1 X123.949 Y123.493 E.40358
G2 X123.976 Y124.003 I2.393 J.131 E.01576
G1 X115.726 Y132.252 E.36003
G3 X116.649 Y131.864 I4.153 J8.602 E.03091
G1 X124.054 Y124.46 E.32315
G2 X124.173 Y124.876 I2.007 J-.349 E.01339
G1 X117.535 Y131.514 E.2897
G1 X118.364 Y131.221 E.02715
G1 X124.327 Y125.258 E.26023
G2 X124.515 Y125.606 I2.078 J-.901 E.01221
G1 X119.156 Y130.965 E.2339
G1 X119.917 Y130.74 E.02449
G1 X124.722 Y125.934 E.20973
G2 X124.959 Y126.233 I1.513 J-.958 E.01179
G1 X120.645 Y130.547 E.18828
G1 X121.35 Y130.378 E.02237
G1 X125.223 Y126.504 E.16906
G2 X125.514 Y126.749 I1.293 J-1.237 E.01175
G1 X122.035 Y130.228 E.15184
G1 X122.692 Y130.106 E.02063
G1 X125.829 Y126.969 E.13693
G2 X126.172 Y127.162 I1.073 J-1.504 E.01216
G1 X123.347 Y129.988 E.12331
G1 X123.963 Y129.906 E.0192
G1 X126.544 Y127.326 E.11262
G2 X126.949 Y127.457 I.814 J-1.828 E.01315
G1 X124.58 Y129.825 E.10337
G3 X125.177 Y129.764 I.885 J5.663 E.01853
G1 X127.392 Y127.548 E.09668
G2 X127.884 Y127.592 I.45 J-2.281 E.01527
G1 X125.759 Y129.718 E.09278
G1 X126.34 Y129.672 E.018
G1 X128.442 Y127.57 E.09176
G2 X129.118 Y127.429 I-.319 J-3.234 E.02134
G1 X126.72 Y129.828 E.10468
; WIPE_START
G1 X128.134 Y128.414 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X120.959 Y131.016 Z8 F36000
G1 X105.445 Y136.642 Z8
G1 Z7.6
G1 E.8 F1800
G1 F15000
G1 X129.693 Y112.394 E1.05825
G1 X129.106 Y112.445 E.01818
G1 X106.428 Y135.123 E.98972
G2 X106.546 Y134.47 I-2.995 J-.875 E.02051
G1 X128.534 Y112.482 E.95964
G1 X127.984 Y112.496 E.01698
G1 X106.557 Y133.923 E.93515
G2 X106.504 Y133.44 I-2.286 J.005 E.01502
G1 X127.462 Y112.483 E.91467
G3 X126.953 Y112.456 I.008 J-5.091 E.01574
G1 X106.406 Y133.003 E.89675
G2 X106.269 Y132.604 I-1.934 J.437 E.01305
G1 X126.455 Y112.418 E.881
G1 X125.984 Y112.353 E.01467
G1 X106.101 Y132.237 E.8678
G2 X105.904 Y131.898 I-1.679 J.752 E.01211
G1 X125.514 Y112.288 E.85585
G3 X125.046 Y112.221 I.616 J-5.883 E.01459
G1 X105.68 Y131.586 E.8452
G1 X105.43 Y131.301 E.01171
G1 X124.591 Y112.14 E.83627
G1 X124.137 Y112.059 E.01425
G1 X105.153 Y131.042 E.82853
G2 X104.851 Y130.809 I-1.243 J1.297 E.01181
G1 X123.682 Y111.978 E.82188
G2 X123.216 Y111.908 I-.677 J2.942 E.01456
G1 X104.522 Y130.602 E.81586
G2 X104.166 Y130.422 I-1.017 J1.573 E.01233
G1 X122.69 Y111.899 E.80843
G1 X122.646 Y111.902 E.00136
G2 X121.878 Y112.175 I1.154 J4.472 E.02517
G1 X103.78 Y130.273 E.7899
G2 X103.357 Y130.16 I-.74 J1.919 E.01352
G1 X120.958 Y112.559 E.76819
G3 X120.067 Y112.915 I-6.08 J-13.937 E.02962
G1 X102.892 Y130.09 E.74959
G2 X102.372 Y130.074 I-.334 J2.424 E.01607
G1 X119.233 Y113.213 E.73587
G3 X118.469 Y113.441 I-2.78 J-7.916 E.0246
G1 X101.765 Y130.146 E.72904
G2 X101.006 Y130.369 I.935 J4.581 E.02443
G1 X117.759 Y113.616 E.73114
G3 X117.087 Y113.752 I-2.129 J-8.797 E.02115
G1 X97.838 Y133.001 E.84011
G1 X97.819 Y132.807 E.00601
G1 X97.755 Y132.549 E.00822
G1 X116.448 Y113.856 E.81583
G3 X115.823 Y113.945 I-1.464 J-8.059 E.01946
G1 X97.589 Y132.18 E.79583
G1 X97.538 Y132.101 E.00287
G1 X97.538 Y131.74 E.01115
G1 X97.612 Y131.62 E.00436
G1 X115.224 Y114.009 E.76863
G1 X114.625 Y114.072 E.0186
G1 X97.838 Y130.859 E.73265
G2 X97.838 Y130.323 I-10.699 J-.276 E.01654
G1 X114.025 Y114.136 E.70647
G2 X113.414 Y114.212 I.275 J4.722 E.01903
G1 X97.784 Y129.842 E.68216
G1 X97.742 Y129.715 E.00412
G2 X97.632 Y129.458 I-2.276 J.823 E.00863
G1 X112.736 Y114.354 E.65921
G2 X111.715 Y114.839 I1.38 J4.22 E.03498
G1 X97.415 Y129.14 E.62412
G1 X97.26 Y128.995 E.00653
G1 X97.121 Y128.898 E.00524
G1 X110.358 Y115.661 E.57772
G3 X109.078 Y116.405 I-8.208 J-12.647 E.04569
G1 X96.758 Y128.726 E.53773
G1 X96.566 Y128.667 E.00619
G1 X96.319 Y128.629 E.0077
G1 X108.001 Y116.947 E.50985
G3 X107.072 Y117.34 I-5.234 J-11.059 E.03116
G1 X95.786 Y128.626 E.49257
G1 X95.25 Y128.626 E.01653
G1 X106.219 Y117.658 E.4787
G1 X105.408 Y117.933 E.02641
G1 X94.715 Y128.626 E.46671
G1 X94.179 Y128.626 E.01653
G1 X104.598 Y118.208 E.45471
G2 X103.744 Y118.526 I1.797 J6.125 E.02815
G1 X93.382 Y128.888 E.45221
G1 X92.755 Y127.908 F36000
G1 F15000
G1 X96.971 Y123.692 E.18403
G3 X95.908 Y124.219 I-7.92 J-14.628 E.03663
G1 X93.977 Y126.15 E.08428
G1 X94.467 Y125.246 E.03173
G3 X94.725 Y124.866 I1.885 J1.006 E.01421
G1 X95.231 Y124.361 E.02205
G1 X99.161 Y132.214 F36000
G1 F15000
G1 X97.664 Y133.711 E.06532
G1 X97.631 Y133.57 F36000
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X96.193 Y135.008 E.06248
G1 X95.66 Y135.008
G1 X97.631 Y133.037 E.08565
G1 X97.547 Y132.587
G1 X95.126 Y135.008 E.1052
G1 X94.593 Y135.008
G1 X97.373 Y132.228 E.1208
G1 X97.331 Y131.737
G1 X94.06 Y135.008 E.14213
G1 X93.563 Y134.972
G1 X97.627 Y130.908 E.17659
G1 X97.631 Y130.371
G1 X93.176 Y134.825 E.19357
G1 X92.865 Y134.603
G1 X97.581 Y129.887 E.20495
G1 X97.425 Y129.51
M73 P91 R1
G1 X92.642 Y134.293 E.20783
G1 X92.494 Y133.907
G1 X97.192 Y129.209 E.20416
G1 X96.871 Y128.997
G1 X92.456 Y133.412 E.19182
G1 X92.456 Y132.878
G1 X96.475 Y128.86 E.17462
G1 X95.968 Y128.834
G1 X92.456 Y132.345 E.15259
G1 X92.456 Y131.812
G1 X95.435 Y128.834 E.12941
G1 X94.901 Y128.834
G1 X92.456 Y131.279 E.10624
G1 X92.456 Y130.745
G1 X94.368 Y128.834 E.08307
G1 X93.835 Y128.834
G1 X92.456 Y130.212 E.0599
M204 S10000
G1 X93.485 Y128.88 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.207016
G1 F15000
G2 X93.137 Y129.128 I3.388 J5.137 E.00572
; LINE_WIDTH: 0.258585
G2 X92.736 Y129.533 I1.295 J1.683 E.01005
; LINE_WIDTH: 0.206996
G2 X92.502 Y129.862 I6.009 J4.518 E.00539
; WIPE_START
G1 X92.736 Y129.533 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X97.534 Y131.298 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.156299
G1 F15000
G3 X97.36 Y131.541 I-3.757 J-2.519 E.00276
; LINE_WIDTH: 0.191404
G1 X97.258 Y131.665 E.00194
G1 X97.613 Y133.903 F36000
; LINE_WIDTH: 0.250778
G1 F15000
G3 X97.318 Y134.316 I-6.379 J-4.237 E.00861
; LINE_WIDTH: 0.300236
G3 X96.911 Y134.717 I-1.69 J-1.309 E.01202
; LINE_WIDTH: 0.256919
G1 X96.841 Y134.768 E.00151
; LINE_WIDTH: 0.222121
G1 X96.68 Y134.876 E.00284
; LINE_WIDTH: 0.179417
G1 X96.518 Y134.984 E.00216
G1 X87.563 Y133.636 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42164
G1 F15000
G1 X98.194 Y123.004 E.46401
G2 X100.398 Y121.336 I-8.316 J-13.276 E.08542
G1 X87.817 Y133.917 E.5491
G1 X88.139 Y134.131 E.01192
G1 X92.269 Y130.001 E.18028
G2 X92.249 Y130.556 I2.234 J.359 E.0172
G1 X88.46 Y134.345 E.16537
G1 X88.782 Y134.559 E.01192
G1 X92.249 Y131.092 E.15133
G1 X92.249 Y131.628 E.01653
G1 X89.103 Y134.773 E.1373
G1 X89.425 Y134.988 E.01192
G1 X92.249 Y132.163 E.12327
G1 X92.249 Y132.699 E.01653
G1 X89.746 Y135.202 E.10923
G1 X90.068 Y135.416 E.01192
G1 X92.249 Y133.234 E.0952
G2 X92.25 Y133.662 I8.92 J.205 E.01319
G1 X92.257 Y133.762 E.00309
G1 X90.389 Y135.63 E.08153
G1 X90.711 Y135.844 E.01192
G1 X92.369 Y134.185 E.07238
G1 X92.455 Y134.383 E.00666
G1 X92.549 Y134.541 E.00566
G1 X91.032 Y136.058 E.06621
G1 X91.354 Y136.272 E.01192
G1 X92.801 Y134.825 E.06315
G1 X93.129 Y135.032 E.01198
G1 X91.675 Y136.486 E.06343
G1 X91.997 Y136.7 E.01192
G1 X93.522 Y135.175 E.06655
G1 X93.753 Y135.212 E.00723
G1 X94.017 Y135.215 E.00814
G1 X92.319 Y136.914 E.07414
G1 X92.64 Y137.128 E.01192
G1 X94.553 Y135.215 E.08348
G1 X95.088 Y135.215 E.01653
G1 X92.962 Y137.342 E.09282
G1 X93.283 Y137.556 E.01192
G1 X95.624 Y135.215 E.10216
G1 X96.16 Y135.215 E.01653
G1 X93.605 Y137.77 E.1115
G1 X93.926 Y137.984 E.01192
G1 X98.57 Y133.341 E.20266
G2 X98.496 Y133.95 I2.811 J.648 E.01897
G1 X94.248 Y138.198 E.18541
G1 X94.569 Y138.412 E.01192
G1 X98.51 Y134.472 E.17198
G2 X98.581 Y134.936 I2.209 J-.102 E.01452
G1 X94.891 Y138.626 E.16106
G1 X95.212 Y138.84 E.01192
G1 X98.695 Y135.358 E.15197
G2 X98.843 Y135.745 I1.887 J-.502 E.01282
G1 X95.534 Y139.054 E.14442
G1 X95.856 Y139.268 E.01192
G1 X99.022 Y136.102 E.1382
G2 X99.229 Y136.431 I1.643 J-.803 E.01201
G1 X96.177 Y139.483 E.13319
G1 X96.499 Y139.697 E.01192
G1 X99.464 Y136.731 E.12944
G2 X99.726 Y137.005 I1.412 J-1.082 E.01171
G1 X96.82 Y139.911 E.1268
G1 X97.142 Y140.125 E.01192
G1 X100.011 Y137.255 E.12525
G2 X100.323 Y137.479 I1.205 J-1.343 E.01186
G1 X97.463 Y140.339 E.12479
G1 X97.785 Y140.553 E.01192
G1 X100.66 Y137.677 E.1255
G2 X101.027 Y137.846 I.973 J-1.629 E.01248
G1 X98.106 Y140.767 E.12747
G1 X98.428 Y140.981 E.01192
G1 X101.426 Y137.983 E.13086
G2 X101.864 Y138.081 I.678 J-1.997 E.01386
G1 X98.749 Y141.195 E.13591
G1 X99.071 Y141.409 E.01192
G1 X102.348 Y138.132 E.14302
G2 X102.893 Y138.122 I.226 J-2.555 E.01687
G1 X99.392 Y141.623 E.1528
G1 X99.714 Y141.837 E.01192
G1 X103.546 Y138.005 E.16723
G2 X104.425 Y137.662 I-1.031 J-3.934 E.02921
G1 X100.036 Y142.051 E.19158
G1 X100.357 Y142.265 E.01192
G1 X130.309 Y112.313 E1.30723
G2 X130.941 Y112.217 I-1.218 J-10.092 E.01974
G1 X100.679 Y142.479 E1.32078
G1 X101 Y142.693 E.01192
G1 X131.594 Y112.099 E1.33524
G1 X132.247 Y111.982 E.02046
G1 X101.322 Y142.907 E1.34969
G1 X101.643 Y143.121 E.01192
G1 X132.875 Y111.89 E1.36306
G3 X133.381 Y111.92 I.171 J1.424 E.01573
G1 X101.842 Y143.458 E1.37645
G1 X102.164 Y143.672 F36000
G1 F15000
G1 X104.335 Y141.501 E.09476
; CHANGE_LAYER
; Z_HEIGHT: 7.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X102.921 Y142.915 E-.76
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
G1 X126.305 Y120.265
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X126.334 Y120.246 E.00115
G3 X127.786 Y119.863 I1.649 J3.314 E.05017
G1 X128.181 Y119.863 E.01307
G3 X125.937 Y120.475 I-.197 J3.696 E.69299
G1 X126.253 Y120.295 E.01209
G1 X126.471 Y120.62 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X126.496 Y120.603 E.00094
G3 X127.807 Y120.255 I1.487 J2.956 E.04197
G1 X128.16 Y120.255 E.01083
G3 X126.154 Y120.802 I-.176 J3.304 E.5738
G1 X126.419 Y120.65 E.0094
; WIPE_START
M204 S10000
G1 X126.496 Y120.603 E-.03441
G1 X126.778 Y120.478 E-.11715
G1 X127.112 Y120.367 E-.13387
G1 X127.457 Y120.293 E-.13393
G1 X127.807 Y120.255 E-.13388
G1 X128.16 Y120.255 E-.13391
G1 X128.35 Y120.276 E-.07284
; WIPE_END
G1 E-.04 F1800
G1 X135.306 Y123.417 Z8.2 F36000
G1 X151.715 Y130.829 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.732 Y130.819 E.00064
G3 X153.242 Y130.407 I1.707 J3.283 E.05232
G1 X153.636 Y130.407 E.01308
G3 X151.392 Y131.02 I-.197 J3.695 E.69274
G1 X151.664 Y130.859 E.01045
G1 X151.914 Y131.167 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X152.234 Y131.022 E.01078
G3 X153.263 Y130.799 I1.205 J3.08 E.0325
G1 X153.615 Y130.799 E.01083
G3 X151.861 Y131.195 I-.176 J3.303 E.58269
; WIPE_START
M204 S10000
G1 X152.234 Y131.022 E-.15605
G1 X152.568 Y130.911 E-.13392
G1 X152.913 Y130.837 E-.13389
G1 X153.263 Y130.799 E-.13389
G1 X153.615 Y130.799 E-.13391
G1 X153.794 Y130.818 E-.06834
; WIPE_END
G1 E-.04 F1800
G1 X146.204 Y131.62 Z8.2 F36000
G1 X99.729 Y136.528 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.501 Y136.231 E.01243
G3 X102.331 Y130.407 I3.027 J-2.129 E.2615
G1 X102.725 Y130.407 E.01308
G3 X99.771 Y136.571 I-.197 J3.695 E.48224
G1 X100.036 Y136.284 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.822 Y136.005 E.01079
G3 X102.351 Y130.799 I2.706 J-1.903 E.21654
G1 X102.704 Y130.799 E.01083
G3 X100.077 Y136.324 I-.176 J3.303 E.39873
; WIPE_START
M204 S10000
G1 X99.822 Y136.005 E-.15501
G1 X99.632 Y135.709 E-.13383
G1 X99.478 Y135.392 E-.13385
G1 X99.358 Y135.061 E-.13395
G1 X99.275 Y134.718 E-.13387
G1 X99.253 Y134.537 E-.0695
; WIPE_END
G1 E-.04 F1800
G1 X96.846 Y131.019 Z8.2 F36000
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X96.846 Y131.423 E.01341
G1 X96.546 Y131.423 E.00995
G1 X96.546 Y132.419 E.03303
G1 X96.846 Y132.419 E.00995
G1 X96.846 Y134.223 E.05985
G1 X93.241 Y134.223 E.11956
G1 X93.241 Y129.619 E.15273
G1 X96.846 Y129.619 E.11956
G1 X96.846 Y130.959 E.04444
G1 X96.154 Y131.411 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X96.154 Y132.431 E.03134
G1 X94.654 Y132.431 E.04609
G1 X94.654 Y132.811 E.01168
G1 X96.454 Y132.811 E.05531
G1 X96.454 Y133.831 E.03134
G1 X93.634 Y133.831 E.08665
G1 X93.634 Y130.011 E.11738
G1 X96.454 Y130.011 E.08665
G1 X96.454 Y131.031 E.03134
G1 X94.654 Y131.031 E.05531
G1 X94.654 Y131.411 E.01168
G1 X96.094 Y131.411 E.04425
; WIPE_START
M204 S10000
G1 X96.154 Y132.431 E-.38827
G1 X95.175 Y132.431 E-.37173
; WIPE_END
G1 E-.04 F1800
G1 X102.655 Y133.949 Z8.2 F36000
G1 X153.292 Y144.224 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.81 Y143.438 E.03059
G2 X132.542 Y130.313 I-24.883 J16.213 E.82486
G2 X102.682 Y144.213 I-4.565 J29.218 E1.15879
G1 X87.298 Y133.972 E.61306
G3 X87.707 Y132.731 I7.35 J1.734 E.04339
G3 X88.408 Y132.053 I2.737 J2.129 E.03249
G2 X91.148 Y129.685 I-14.519 J-19.571 E.12023
G2 X93.594 Y126.161 I-11.287 J-10.443 E.14277
G3 X94.42 Y124.708 I12.311 J6.041 E.05548
G3 X95.013 Y124.286 I1.249 J1.127 E.02432
G2 X97.525 Y123.019 I-21.353 J-45.47 E.09337
G2 X101.007 Y120.323 I-8.607 J-14.712 E.14648
G3 X102.749 Y118.694 I16.138 J15.519 E.07915
G3 X103.977 Y118.067 I2.748 J3.861 E.04589
G2 X107.047 Y116.997 I-16.529 J-52.398 E.10788
G2 X110.366 Y115.274 I-7.762 J-19.009 E.12423
G3 X112.192 Y114.201 I10.967 J16.579 E.07027
G3 X113.876 Y113.812 I2.035 J4.969 E.05758
G2 X117.401 Y113.355 I-2.348 J-31.915 E.11798
G2 X120.397 Y112.432 I-3.463 J-16.567 E.10413
G3 X122.452 Y111.606 I9.404 J20.406 E.0735
G3 X123.43 Y111.594 I.513 J2.044 E.03277
G2 X125.813 Y112.005 I37.992 J-213.478 E.08021
G2 X130.777 Y111.907 I2.186 J-15.165 E.16543
G3 X132.965 Y111.545 I4.745 J21.849 E.07357
G3 X133.236 Y111.55 I.104 J1.683 E.00902
G3 X134.409 Y111.943 I-.931 J4.721 E.04114
G2 X137.511 Y113.104 I10.354 J-22.942 E.10995
G2 X140.702 Y113.674 I5.146 J-19.605 E.10764
G3 X143.068 Y113.962 I-1.514 J22.323 E.07912
G3 X144.643 Y114.679 I-1.436 J5.238 E.05764
G2 X148.015 Y116.604 I17.389 J-26.549 E.12887
G2 X151.657 Y117.949 I12.729 J-28.86 E.12887
G3 X153.297 Y118.756 I-1.46 J5.034 E.06094
G3 X154.768 Y120.137 I-13.844 J16.234 E.06696
G2 X158.902 Y123.348 I14.663 J-14.612 E.17411
G3 X160.841 Y124.544 I-11.463 J20.741 E.07559
G3 X161.85 Y125.632 I-2.664 J3.483 E.04946
G2 X163.68 Y128.324 I49.9 J-31.953 E.10798
G2 X166.202 Y131.082 I16.837 J-12.865 E.12415
G3 X167.71 Y132.567 I-14.867 J16.6 E.07024
G3 X168.522 Y134.094 I-4.095 J3.157 E.05761
G1 X168.658 Y134.455 E.0128
G1 X153.342 Y144.192 E.60203
G1 X153.166 Y144.769 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.785 E1.86605
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.102 J2.075 E.05195
G3 X88.163 Y131.747 I2.99 J2.225 E.03455
G2 X90.863 Y129.416 I-14.313 J-19.31 E.10971
G2 X93.249 Y125.974 I-11.006 J-10.177 E.1291
G3 X94.112 Y124.464 I12.333 J6.052 E.05349
G3 X94.828 Y123.94 I1.545 J1.358 E.02748
G2 X97.331 Y122.678 I-21.382 J-45.532 E.08613
G2 X100.735 Y120.04 I-8.414 J-14.373 E.1327
G3 X102.515 Y118.38 I16.223 J15.606 E.07483
G3 X103.844 Y117.698 I2.996 J4.202 E.04607
G2 X106.325 Y116.856 I-155.894 J-463.749 E.08051
G2 X110.161 Y114.94 I-7.083 J-18.975 E.13198
G3 X112.029 Y113.845 I11.124 J16.833 E.06658
G3 X113.833 Y113.423 I2.199 J5.333 E.05719
G2 X117.323 Y112.971 I-2.309 J-31.542 E.10818
G2 X120.249 Y112.069 I-3.378 J-16.16 E.09421
G3 X122.349 Y111.227 I9.363 J20.309 E.06955
G3 X123.486 Y111.206 I.613 J2.412 E.03526
G2 X125.869 Y111.616 I39.569 J-222.612 E.07429
G2 X130.712 Y111.521 I2.13 J-14.776 E.1495
G3 X132.947 Y111.153 I4.722 J21.728 E.06962
G3 X133.276 Y111.16 I.125 J2.036 E.01012
G3 X134.559 Y111.581 I-.934 J5.009 E.04162
G2 X137.616 Y112.726 I10.23 J-22.649 E.10038
G2 X140.743 Y113.284 I5.04 J-19.215 E.09772
G3 X143.156 Y113.579 I-1.532 J22.516 E.07475
G3 X144.845 Y114.343 I-1.517 J5.602 E.0572
G2 X148.18 Y116.248 I17.228 J-26.289 E.11809
G2 X151.784 Y117.578 I12.595 J-28.584 E.11809
G3 X153.54 Y118.449 I-1.58 J5.393 E.06054
G3 X155.042 Y119.856 I-14.055 J16.507 E.06326
G2 X159.105 Y123.012 I14.388 J-14.329 E.15852
G3 X161.075 Y124.23 I-11.596 J20.967 E.07119
G3 X162.172 Y125.409 I-2.911 J3.808 E.04973
G2 X163.993 Y128.088 I49.806 J-31.888 E.09953
G2 X166.471 Y130.797 I16.519 J-12.623 E.11297
G3 X168.012 Y132.318 I-14.98 J16.723 E.06657
G3 X168.887 Y133.952 I-4.41 J3.412 E.05721
G1 X169.137 Y134.615 E.02177
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49802
G1 X152.091 Y143.084 E-.26198
; WIPE_END
G1 E-.04 F1800
G1 X155.796 Y142.438 Z8.2 F36000
G1 Z7.8
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42217
G1 F15000
G1 X125.667 Y112.31 E1.31677
G3 X125.041 Y112.22 I.812 J-7.879 E.01956
G1 X155.345 Y142.524 E1.32444
G1 X155.017 Y142.732 E.01201
G1 X124.389 Y112.103 E1.33863
G1 X123.736 Y111.987 E.02049
G1 X154.689 Y142.941 E1.35282
G1 X154.362 Y143.149 E.01201
G1 X123.11 Y111.898 E1.36585
G2 X122.595 Y111.919 I-.196 J1.513 E.01601
G1 X154.034 Y143.358 E1.37404
G1 X153.706 Y143.566 E.01201
G1 X151.603 Y141.463 E.09191
G1 X162.682 Y138.061 F36000
G1 F15000
G1 X157.149 Y132.528 E.2418
M73 P92 R1
G3 X157.391 Y133.306 I-3.747 J1.59 E.02522
G1 X162.231 Y138.146 E.21154
G1 X161.903 Y138.355 E.01201
G1 X157.468 Y133.92 E.19381
G3 X157.46 Y134.448 I-6.957 J.158 E.01633
G1 X161.575 Y138.563 E.17984
G1 X161.247 Y138.771 E.01201
G1 X157.391 Y134.915 E.16854
G3 X157.279 Y135.34 I-2.042 J-.311 E.01359
G1 X160.919 Y138.98 E.1591
G1 X160.591 Y139.188 E.01201
G1 X157.132 Y135.729 E.1512
G3 X156.954 Y136.087 I-1.761 J-.651 E.01239
G1 X160.263 Y139.397 E.14464
G1 X159.936 Y139.605 E.01201
G1 X156.747 Y136.417 E.13934
G3 X156.512 Y136.718 I-1.531 J-.953 E.01183
G1 X159.608 Y139.814 E.13529
G1 X159.28 Y140.022 E.01201
G1 X156.252 Y136.994 E.13233
G3 X155.967 Y137.246 I-1.317 J-1.207 E.01177
G1 X158.952 Y140.231 E.13047
G1 X158.624 Y140.439 E.01201
G1 X155.656 Y137.471 E.1297
G3 X155.319 Y137.671 I-1.1 J-1.477 E.01212
G1 X158.296 Y140.648 E.13011
G1 X157.968 Y140.856 E.01201
G1 X154.953 Y137.841 E.13177
G3 X154.555 Y137.979 I-.843 J-1.794 E.01306
G1 X157.64 Y141.065 E.13486
G1 X157.313 Y141.273 E.01201
G1 X154.118 Y138.078 E.13962
G3 X153.634 Y138.131 I-.489 J-2.238 E.01506
G1 X156.985 Y141.481 E.14642
G1 X156.657 Y141.69 E.01201
G1 X153.09 Y138.123 E.1559
G3 X152.441 Y138.011 I.447 J-4.518 E.02035
G1 X156.329 Y141.898 E.1699
G1 X156.001 Y142.107 E.01201
G1 X151.571 Y137.677 E.19362
G3 X149.864 Y135.97 I1.88 J-3.587 E.07576
G1 X126.289 Y112.395 E1.03033
G2 X126.881 Y112.451 I.761 J-4.894 E.0184
G1 X149.534 Y135.103 E.99002
G3 X149.419 Y134.452 I2.99 J-.863 E.02047
G1 X127.449 Y112.482 E.96019
G2 X127.999 Y112.496 I.406 J-5.3 E.01701
G1 X149.411 Y133.908 E.93582
G3 X149.465 Y133.426 I2.283 J.012 E.01502
G1 X128.522 Y112.482 E.91534
G2 X129.028 Y112.452 I.009 J-4.151 E.01569
G1 X149.565 Y132.99 E.89758
G3 X149.703 Y132.591 I1.934 J.444 E.01306
G1 X129.521 Y112.409 E.88204
G2 X130.006 Y112.358 I-.195 J-4.147 E.01508
G1 X149.873 Y132.224 E.86827
G3 X150.071 Y131.887 I1.678 J.759 E.01213
G1 X130.474 Y112.289 E.85652
G2 X130.938 Y112.217 I-.908 J-7.412 E.01453
G1 X150.297 Y131.575 E.84605
G1 X150.547 Y131.289 E.01175
G1 X131.393 Y112.135 E.83711
G1 X131.848 Y112.054 E.01428
G1 X150.826 Y131.032 E.82943
G3 X151.13 Y130.799 I1.24 J1.306 E.01185
G1 X132.303 Y111.972 E.82283
G3 X132.768 Y111.902 I.745 J3.338 E.01457
G1 X151.459 Y130.593 E.8169
G3 X151.817 Y130.414 I1.014 J1.584 E.01238
G1 X133.308 Y111.905 E.80897
G3 X134.136 Y112.197 I-1.289 J4.977 E.02718
G1 X152.206 Y130.267 E.78977
G3 X152.631 Y130.156 I.734 J1.93 E.0136
G1 X135.055 Y112.579 E.76818
G2 X135.943 Y112.931 I6.221 J-14.394 E.02955
G1 X153.099 Y130.087 E.7498
G3 X153.622 Y130.074 I.324 J2.441 E.0162
G1 X136.775 Y113.227 E.73631
G2 X137.537 Y113.452 I2.755 J-7.913 E.02456
G1 X154.238 Y130.154 E.72993
G3 X155.014 Y130.393 I-.851 J4.136 E.02513
G1 X138.246 Y113.625 E.73285
G2 X138.916 Y113.759 I2.108 J-8.792 E.02114
G1 X162.886 Y137.729 E1.04762
G1 X163.214 Y137.521 E.01201
G1 X139.555 Y113.861 E1.03403
G2 X140.179 Y113.949 I1.437 J-8.008 E.01946
G1 X163.542 Y137.312 E1.02111
G1 X163.87 Y137.104 E.01201
G1 X140.778 Y114.012 E1.00922
G1 X141.378 Y114.076 E.01864
G1 X164.198 Y136.895 E.99733
G1 X164.526 Y136.687 E.01201
G1 X141.978 Y114.139 E.98544
G3 X142.593 Y114.218 I-.297 J4.767 E.01918
G1 X164.854 Y136.478 E.97289
G1 X165.182 Y136.27 E.01201
G1 X143.279 Y114.367 E.95727
G3 X144.345 Y114.897 I-1.718 J4.793 E.03689
G1 X165.51 Y136.061 E.92499
G1 X165.837 Y135.853 E.01201
G1 X145.703 Y115.718 E.87999
G2 X146.969 Y116.449 I8.126 J-12.629 E.04521
G1 X166.165 Y135.645 E.83895
G1 X166.493 Y135.436 E.01201
G1 X148.034 Y116.977 E.80675
G2 X148.959 Y117.366 I5.164 J-10.995 E.03102
G1 X166.821 Y135.228 E.78065
G1 X167.149 Y135.019 E.01201
G1 X149.809 Y117.679 E.75784
G1 X150.623 Y117.956 E.02656
G1 X167.477 Y134.811 E.73662
G1 X167.805 Y134.602 E.01201
G1 X151.436 Y118.234 E.7154
G3 X152.282 Y118.543 I-1.758 J6.112 E.02787
G1 X168.133 Y134.394 E.69275
G1 X168.248 Y134.32 E.00424
G2 X168.011 Y133.736 I-5.512 J1.897 E.01949
G1 X155.884 Y121.609 E.53001
G2 X157.975 Y123.164 I15.749 J-18.998 E.08057
G1 X163.686 Y128.874 E.24957
G3 X162.386 Y127.039 I21.095 J-16.309 E.06953
G1 X159.355 Y124.007 E.13251
G1 X160.456 Y124.68 E.03988
G3 X161.021 Y125.137 I-2.013 J3.067 E.0225
G1 X161.916 Y126.032 E.03913
G1 X129.241 Y129.828 F36000
G1 F15000
G1 X126.84 Y127.427 E.10492
G2 X127.518 Y127.569 I1.001 J-3.098 E.02144
G1 X129.621 Y129.672 E.09191
G1 X130.203 Y129.718 E.01805
G1 X128.078 Y127.592 E.09288
G2 X128.571 Y127.549 I.044 J-2.327 E.01532
G1 X130.785 Y129.763 E.09678
G3 X131.383 Y129.825 I-.286 J5.732 E.01858
G1 X129.016 Y127.457 E.10346
G2 X129.421 Y127.327 I-.408 J-1.962 E.0132
G1 X132.001 Y129.906 E.11273
G3 X132.62 Y129.989 I-.522 J6.256 E.01931
G1 X129.794 Y127.163 E.12352
G2 X130.137 Y126.969 I-.732 J-1.701 E.01219
G1 X133.276 Y130.109 E.13721
G1 X133.933 Y130.229 E.02062
G1 X130.453 Y126.749 E.15208
G2 X130.744 Y126.504 I-1.003 J-1.483 E.01178
G1 X134.618 Y130.378 E.16931
G1 X135.324 Y130.547 E.02243
G1 X131.008 Y126.232 E.18859
G2 X131.246 Y125.933 I-1.273 J-1.254 E.01182
G1 X136.053 Y130.74 E.21011
G1 X136.815 Y130.966 E.02456
G1 X131.457 Y125.608 E.23417
G2 X131.641 Y125.256 I-1.555 J-1.037 E.01231
G1 X137.608 Y131.223 E.26078
G1 X138.439 Y131.517 E.02722
G1 X131.795 Y124.873 E.29035
G2 X131.914 Y124.456 I-1.892 J-.766 E.01343
G1 X139.326 Y131.868 E.32394
G3 X140.252 Y132.257 I-3.247 J9.017 E.03104
G1 X131.992 Y123.997 E.36099
G2 X132.018 Y123.487 I-2.376 J-.376 E.01582
G1 X141.277 Y132.746 E.40468
G3 X142.408 Y133.341 I-5.107 J11.088 E.03949
G1 X131.959 Y122.892 E.45665
G2 X131.77 Y122.167 I-5.039 J.925 E.02318
G1 X144.212 Y134.608 E.54375
G1 X146.081 Y135.941 F36000
G1 F15000
G1 X122.188 Y112.048 E1.04427
G2 X121.808 Y112.204 I.69 J2.219 E.01272
G1 X129.381 Y119.777 E.33098
G2 X128.647 Y119.58 I-1.289 J3.334 E.02351
G1 X121.429 Y112.362 E.31546
G1 X121.051 Y112.52 E.01267
G1 X128.061 Y119.53 E.30635
G2 X127.548 Y119.553 I-.146 J2.41 E.01589
G1 X120.673 Y112.678 E.30048
G3 X120.288 Y112.83 I-2.608 J-6.028 E.01277
G1 X127.088 Y119.63 E.29719
G2 X126.671 Y119.749 I.348 J2.012 E.01344
G1 X119.9 Y112.978 E.29592
G3 X119.508 Y113.123 I-1.737 J-4.106 E.01291
G1 X126.289 Y119.903 E.29634
G2 X125.939 Y120.09 I.844 J1.999 E.01226
G1 X119.104 Y113.255 E.29871
G3 X118.692 Y113.38 I-1.51 J-4.267 E.01331
G1 X125.613 Y120.3 E.30246
G2 X125.315 Y120.538 I.966 J1.516 E.01182
G1 X118.272 Y113.496 E.3078
G3 X117.838 Y113.598 I-1.267 J-4.39 E.01378
G1 X125.042 Y120.802 E.31481
G2 X124.793 Y121.09 I1.228 J1.309 E.01177
G1 X117.398 Y113.695 E.3232
G1 X116.946 Y113.778 E.01422
G1 X124.572 Y121.405 E.33331
G2 X124.379 Y121.748 I1.505 J1.069 E.0122
G1 X116.482 Y113.851 E.34515
G1 X116.014 Y113.919 E.01462
G1 X124.216 Y122.121 E.35846
G2 X124.085 Y122.527 I1.831 J.814 E.01319
G1 X115.534 Y113.976 E.37372
G1 X115.049 Y114.027 E.01507
G1 X123.993 Y122.971 E.39088
G2 X123.948 Y123.463 I9.346 J1.089 E.01527
G1 X114.564 Y114.079 E.41013
G1 X114.08 Y114.13 E.01507
G1 X123.979 Y124.03 E.43267
G2 X124.112 Y124.699 I3.197 J-.286 E.02112
G1 X113.595 Y114.182 E.45965
G2 X113.137 Y114.26 I.37 J3.561 E.01438
G1 X128.516 Y129.639 E.67214
G2 X127.966 Y129.626 I-.404 J5.244 E.017
G1 X112.703 Y114.363 E.66704
G2 X112.316 Y114.512 I1.799 J5.25 E.01283
G1 X127.443 Y129.639 E.66113
G1 X126.921 Y129.653 E.01616
G1 X111.962 Y114.694 E.65378
G2 X111.625 Y114.894 I1.241 J2.472 E.0121
G1 X126.399 Y129.668 E.64568
G1 X125.902 Y129.707 E.01541
G1 X111.291 Y115.096 E.63855
G1 X110.957 Y115.298 E.01207
G1 X125.404 Y129.746 E.63142
G1 X124.907 Y129.785 E.01541
G1 X110.623 Y115.501 E.62429
G1 X110.289 Y115.703 E.01207
G1 X124.431 Y129.845 E.61807
G1 X123.957 Y129.907 E.01477
M73 P93 R1
G1 X109.955 Y115.905 E.61196
G1 X109.621 Y116.107 E.01207
G1 X123.483 Y129.97 E.60585
G2 X123.022 Y130.045 I.491 J4.436 E.01444
G1 X109.275 Y116.299 E.6008
G1 X108.927 Y116.487 E.01223
G1 X122.57 Y130.129 E.59624
G1 X122.117 Y130.213 E.01422
G1 X108.575 Y116.671 E.59187
G1 X108.214 Y116.847 E.01239
G1 X121.669 Y130.301 E.58803
G1 X121.236 Y130.405 E.01375
G1 X107.847 Y117.015 E.58519
G1 X107.476 Y117.18 E.01256
G1 X120.804 Y130.509 E.58251
G1 X120.371 Y130.612 E.01375
G1 X107.091 Y117.333 E.5804
G1 X106.707 Y117.485 E.01277
G1 X119.952 Y130.729 E.57884
G1 X119.538 Y130.852 E.01334
G1 X106.312 Y117.626 E.57802
G1 X105.912 Y117.762 E.01307
G1 X119.124 Y130.974 E.57744
G2 X118.711 Y131.098 I.97 J3.994 E.01332
G1 X105.511 Y117.898 E.5769
G1 X105.111 Y118.034 E.01307
G1 X118.315 Y131.238 E.5771
G1 X117.919 Y131.378 E.01299
G1 X104.71 Y118.17 E.57729
G1 X104.31 Y118.305 E.01307
G1 X117.523 Y131.519 E.57748
G2 X117.132 Y131.664 I1.193 J3.794 E.01289
G1 X103.92 Y118.452 E.57745
G1 X103.543 Y118.611 E.01266
G1 X116.753 Y131.821 E.57737
G1 X116.374 Y131.979 E.01269
G1 X103.194 Y118.799 E.57603
G2 X102.882 Y119.023 I.704 J1.312 E.01191
G1 X115.995 Y132.136 E.57311
G2 X115.624 Y132.301 I1.392 J3.625 E.01256
G1 X102.59 Y119.267 E.56964
G1 X102.315 Y119.529 E.01172
G1 X115.261 Y132.474 E.56578
G1 X114.897 Y132.647 E.01243
G1 X102.04 Y119.79 E.56192
G1 X101.765 Y120.052 E.01172
G1 X114.534 Y132.821 E.55806
G2 X114.181 Y133.003 I1.564 J3.462 E.01231
G1 X101.491 Y120.313 E.55462
G1 X101.216 Y120.575 E.01172
G1 X113.833 Y133.192 E.55144
G1 X113.485 Y133.381 E.01222
G1 X100.941 Y120.836 E.54826
G1 X100.666 Y121.098 E.01172
G1 X113.138 Y133.569 E.54508
G2 X112.8 Y133.768 I1.726 J3.324 E.01211
G1 X100.382 Y121.35 E.54272
G1 X100.095 Y121.599 E.01175
G1 X112.467 Y133.972 E.54075
G1 X112.135 Y134.175 E.01205
G1 X99.805 Y121.845 E.53889
G1 X99.503 Y122.08 E.01181
G1 X111.802 Y134.379 E.53756
G2 X111.479 Y134.592 I1.868 J3.187 E.01197
G1 X99.201 Y122.314 E.53663
G3 X98.892 Y122.542 I-1.939 J-2.298 E.01186
G1 X111.161 Y134.811 E.53621
G1 X110.843 Y135.029 E.01192
G1 X98.573 Y122.759 E.53628
G3 X98.249 Y122.971 I-2.144 J-2.913 E.01198
G1 X110.525 Y135.248 E.53654
G2 X110.216 Y135.474 I2.011 J3.073 E.01187
G1 X97.914 Y123.173 E.53762
G3 X97.575 Y123.37 I-2.037 J-3.125 E.01213
G1 X109.912 Y135.707 E.5392
G1 X109.609 Y135.94 E.01182
G1 X106.267 Y132.598 E.14605
G3 X106.488 Y133.356 I-3.8 J1.521 E.02443
G1 X109.305 Y136.173 E.12311
G2 X109.008 Y136.412 I2.137 J2.951 E.01179
G1 X106.56 Y133.964 E.107
G1 X106.543 Y134.483 E.01605
G1 X108.719 Y136.66 E.09511
G1 X108.43 Y136.907 E.01176
G1 X106.471 Y134.948 E.08561
G3 X106.357 Y135.37 I-2.031 J-.325 E.01353
G1 X108.141 Y137.154 E.07797
G2 X107.856 Y137.406 I2.263 J2.84 E.01175
G1 X106.207 Y135.756 E.07209
G3 X106.027 Y136.112 I-1.756 J-.666 E.01236
G1 X107.581 Y137.667 E.06794
G1 X107.306 Y137.928 E.01172
G1 X105.819 Y136.441 E.065
G1 X105.583 Y136.741 E.01181
G1 X107.031 Y138.189 E.06328
G2 X106.759 Y138.453 I2.386 J2.73 E.01173
G1 X105.32 Y137.015 E.06286
G3 X105.033 Y137.264 I-1.309 J-1.22 E.01177
G1 X106.497 Y138.729 E.06401
G1 X106.236 Y139.004 E.01172
G1 X104.72 Y137.488 E.06626
G3 X104.381 Y137.685 I-1.091 J-1.488 E.01215
G1 X105.975 Y139.279 E.06968
G2 X105.715 Y139.555 I2.505 J2.616 E.01173
G1 X104.012 Y137.852 E.07442
G3 X103.611 Y137.988 I-.832 J-1.808 E.01311
G1 X105.468 Y139.845 E.08116
G1 X105.221 Y140.134 E.01176
G1 X103.171 Y138.084 E.08959
G3 X102.684 Y138.133 I-.473 J-2.256 E.01516
G1 X104.974 Y140.423 E.10008
G1 X104.727 Y140.712 E.01176
G1 X102.135 Y138.121 E.11328
G3 X101.474 Y137.996 I.589 J-4.932 E.02081
G1 X104.494 Y141.015 E.13198
G1 X104.261 Y141.319 E.01182
G1 X97.179 Y134.237 E.30951
G1 X97.179 Y133.701 E.01658
G1 X98.635 Y135.157 E.06365
G3 X98.513 Y134.499 I3.018 J-.898 E.02072
G1 X97.179 Y133.164 E.05833
G1 X97.179 Y132.628 E.01658
G1 X98.497 Y133.946 E.05759
G3 X98.547 Y133.46 I2.296 J-.006 E.01512
G1 X96.879 Y131.792 E.07292
G1 X96.879 Y131.756 E.0011
G1 X97.179 Y131.756 E.00927
G1 X97.179 Y131.555 E.00621
G1 X98.644 Y133.021 E.06405
G3 X98.779 Y132.619 I1.946 J.431 E.01311
G1 X97.179 Y131.019 E.06995
G1 X97.179 Y130.483 E.01658
G1 X98.947 Y132.251 E.07727
G3 X99.143 Y131.91 I1.689 J.748 E.01216
G1 X97.009 Y129.777 E.09326
G1 X96.688 Y129.455 F36000
G1 F15000
G1 X93.768 Y126.536 E.12759
G3 X93.578 Y126.882 I-4.785 J-2.399 E.01221
G1 X95.982 Y129.286 E.10504
G1 X95.445 Y129.286 E.01658
G1 X93.379 Y127.219 E.0903
G1 X93.18 Y127.557 E.0121
G1 X94.909 Y129.286 E.07556
G1 X94.373 Y129.286 E.01658
G1 X92.973 Y127.886 E.06116
G1 X92.759 Y128.208 E.01196
G1 X93.836 Y129.286 E.04708
G1 X93.3 Y129.286 E.01658
G1 X92.537 Y128.522 E.03335
G1 X92.308 Y128.83 E.01185
G1 X92.908 Y129.43 E.02623
G1 X92.908 Y129.966 E.01658
G1 X92.07 Y129.128 E.03663
G1 X91.821 Y129.416 E.01175
G1 X92.908 Y130.503 E.0475
G1 X92.908 Y131.039 E.01658
G1 X91.573 Y129.704 E.05837
G3 X91.318 Y129.985 I-1.805 J-1.376 E.01175
G1 X92.908 Y131.575 E.0695
G1 X92.908 Y132.112 E.01658
G1 X91.047 Y130.25 E.08135
G1 X90.776 Y130.515 E.01172
G1 X92.908 Y132.648 E.09321
G1 X92.908 Y133.184 E.01658
G1 X90.501 Y130.777 E.10522
G1 X90.212 Y131.024 E.01176
G1 X93.078 Y133.89 E.12527
G1 X93.574 Y134.387 F36000
G1 F15000
G1 X102.713 Y143.525 E.39941
G3 X102.919 Y143.195 I3.248 J1.805 E.01203
G1 X94.28 Y134.556 E.37758
G1 X94.816 Y134.556 E.01658
G1 X103.138 Y142.878 E.36369
G1 X103.356 Y142.56 E.01192
G1 X95.353 Y134.556 E.34979
G1 X95.889 Y134.556 E.01658
G1 X103.575 Y142.242 E.3359
G3 X103.795 Y141.926 I3.12 J1.94 E.01191
G1 X96.425 Y134.556 E.32209
G1 X96.962 Y134.556 E.01658
G1 X104.149 Y141.743 E.31412
G1 X102.632 Y143.981 F36000
G1 F15000
G1 X89.923 Y131.272 E.55547
G3 X89.629 Y131.514 I-3.536 J-3.989 E.01178
G1 X100.425 Y142.311 E.47187
G1 X98.821 Y141.243 E.05956
G1 X89.33 Y131.752 E.4148
G1 X89.032 Y131.989 E.0118
G1 X97.217 Y140.175 E.35773
G1 X95.612 Y139.107 E.05956
G1 X88.733 Y132.227 E.30066
G1 X88.434 Y132.465 E.0118
G1 X94.008 Y138.039 E.2436
G1 X92.404 Y136.971 E.05956
G1 X88.154 Y132.721 E.18575
G2 X87.933 Y133.036 I.427 J.534 E.01206
G1 X90.799 Y135.903 E.12528
G1 X89.195 Y134.835 E.05956
G1 X87.663 Y133.302 E.06696
; WIPE_START
G1 X89.077 Y134.717 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X96.411 Y132.603 Z8.2 F36000
G1 X99.486 Y131.717 Z8.2
G1 Z7.8
G1 E.8 F1800
G1 F15000
G1 X93.957 Y126.188 E.24166
G1 X94.145 Y125.84 E.01223
G1 X99.616 Y131.311 E.23911
G3 X99.896 Y131.055 I1.186 J1.016 E.01176
G1 X94.334 Y125.492 E.24312
G3 X94.527 Y125.149 I2.834 J1.376 E.01217
G1 X100.195 Y130.817 E.24769
G3 X100.522 Y130.608 I1.14 J1.429 E.01203
G1 X94.756 Y124.841 E.25203
G3 X95.082 Y124.631 I.889 J1.021 E.01203
G1 X100.878 Y130.427 E.25331
G3 X101.264 Y130.277 I.895 J1.733 E.01283
G1 X95.436 Y124.45 E.25469
G1 X95.797 Y124.274 E.01239
G1 X101.686 Y130.163 E.25739
G3 X102.151 Y130.091 I.566 J2.135 E.01456
G1 X96.157 Y124.098 E.26195
G1 X96.518 Y123.922 E.01239
G1 X102.67 Y130.074 E.26889
G3 X103.275 Y130.142 I-.245 J4.879 E.01882
G1 X96.875 Y123.743 E.27968
G1 X97.225 Y123.556 E.01225
G1 X104.388 Y130.719 E.31306
; CHANGE_LAYER
; Z_HEIGHT: 8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X102.974 Y129.305 E-.76
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
G1 X126.467 Y120.618
G1 Z8
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.807 Y120.255 I1.516 J2.942 E.04298
G1 X128.16 Y120.255 E.01083
G3 X126.414 Y120.646 I-.176 J3.305 E.58334
; WIPE_START
M204 S10000
G1 X126.778 Y120.478 E-.15234
G1 X127.112 Y120.367 E-.13389
G1 X127.457 Y120.293 E-.13391
G1 X127.807 Y120.255 E-.1339
G1 X128.16 Y120.255 E-.1339
G1 X128.348 Y120.275 E-.07207
; WIPE_END
G1 E-.04 F1800
G1 X121.704 Y124.032 Z8.4 F36000
G1 X100.037 Y136.284 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S6000
G3 X102.351 Y130.799 I2.49 J-2.18 E.22744
G1 X102.704 Y130.799 E.01083
G3 X100.077 Y136.329 I-.176 J3.305 E.39884
; WIPE_START
M204 S10000
G1 X99.819 Y136.008 E-.1566
G1 X99.632 Y135.709 E-.1339
G1 X99.478 Y135.392 E-.13387
G1 X99.358 Y135.061 E-.1339
G1 X99.275 Y134.718 E-.1339
G1 X99.251 Y134.541 E-.06782
; WIPE_END
G1 E-.04 F1800
G1 X96.154 Y131.411 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S6000
G1 X96.154 Y132.431 E.03134
G1 X94.654 Y132.431 E.04609
G1 X94.654 Y132.811 E.01168
G1 X96.454 Y132.811 E.05531
G1 X96.454 Y133.831 E.03134
G1 X93.634 Y133.831 E.08665
G1 X93.634 Y130.011 E.11738
G1 X96.454 Y130.011 E.08665
G1 X96.454 Y131.031 E.03134
G1 X94.654 Y131.031 E.05531
G1 X94.654 Y131.411 E.01168
G1 X96.094 Y131.411 E.04425
; WIPE_START
M204 S10000
G1 X96.154 Y132.431 E-.38827
G1 X95.175 Y132.431 E-.37173
; WIPE_END
G1 E-.04 F1800
G1 X102.806 Y132.261 Z8.4 F36000
G1 X151.912 Y131.168 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S6000
G1 X151.913 Y131.168 E.00004
G3 X153.263 Y130.799 I1.526 J2.937 E.04333
G1 X153.615 Y130.799 E.01083
G3 X151.609 Y131.347 I-.176 J3.305 E.57395
G1 X151.86 Y131.199 E.00895
; WIPE_START
M204 S10000
G1 X151.913 Y131.168 E-.02327
G1 X152.234 Y131.022 E-.13385
G1 X152.568 Y130.911 E-.13389
G1 X152.913 Y130.837 E-.13392
G1 X153.263 Y130.799 E-.1339
G1 X153.615 Y130.799 E-.1339
G1 X153.792 Y130.818 E-.06727
; WIPE_END
G1 E-.04 F1800
G1 X153.449 Y138.443 Z8.4 F36000
G1 X153.166 Y144.769 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S6000
G2 X102.804 Y144.765 I-25.182 J14.782 E1.86611
G1 X86.844 Y134.141 E.58912
G3 X87.366 Y132.535 I9.13 J2.084 E.05194
G3 X88.163 Y131.747 I2.988 J2.222 E.03457
G2 X90.863 Y129.416 I-14.314 J-19.311 E.10972
G2 X93.249 Y125.974 I-11.006 J-10.178 E.1291
G3 X94.112 Y124.464 I12.336 J6.054 E.05348
G3 X94.828 Y123.94 I1.546 J1.358 E.02749
G2 X97.331 Y122.678 I-21.471 J-45.709 E.08612
G2 X100.735 Y120.04 I-8.414 J-14.373 E.13269
G3 X102.511 Y118.382 I16.299 J15.683 E.07471
G3 X103.846 Y117.697 I2.999 J4.198 E.04626
G2 X106.329 Y116.855 I-148.209 J-441.041 E.08057
G2 X110.161 Y114.94 I-7.087 J-18.975 E.13185
G3 X112.029 Y113.845 I11.123 J16.831 E.06659
G3 X113.833 Y113.423 I2.199 J5.334 E.05718
G2 X117.323 Y112.971 I-2.309 J-31.541 E.10818
G2 X120.249 Y112.069 I-3.377 J-16.158 E.09423
G3 X122.349 Y111.227 I9.353 J20.286 E.06955
G3 X123.486 Y111.206 I.613 J2.411 E.03526
G2 X125.869 Y111.616 I39.482 J-222.103 E.07429
G2 X130.712 Y111.521 I2.13 J-14.776 E.1495
M73 P94 R1
G3 X132.945 Y111.153 I4.737 J21.811 E.06955
G3 X133.218 Y111.154 I.129 J2.102 E.0084
G3 X134.21 Y111.438 I-.557 J3.827 E.03182
G2 X136.296 Y112.295 I45.677 J-108.143 E.06929
G2 X140.743 Y113.284 I5.956 J-16.294 E.14039
G3 X143.156 Y113.579 I-1.533 J22.524 E.07474
G3 X144.847 Y114.344 I-1.518 J5.606 E.05727
G2 X148.18 Y116.248 I17.22 J-26.278 E.11803
G2 X151.783 Y117.578 I12.596 J-28.587 E.11808
G3 X153.54 Y118.449 I-1.58 J5.393 E.06055
G3 X155.042 Y119.856 I-13.964 J16.41 E.06327
G2 X159.105 Y123.012 I14.389 J-14.33 E.15851
G3 X161.075 Y124.23 I-11.641 J21.041 E.0712
G3 X162.172 Y125.409 I-2.911 J3.809 E.04972
G2 X163.992 Y128.087 I49.694 J-31.811 E.09952
G2 X166.471 Y130.796 I16.518 J-12.621 E.11298
G3 X168.012 Y132.318 I-14.995 J16.739 E.06657
G3 X168.887 Y133.952 I-4.41 J3.413 E.05722
G1 X169.137 Y134.615 E.02177
G1 X153.216 Y144.737 E.57971
; WIPE_START
M204 S10000
G1 X152.481 Y143.652 E-.49802
G1 X152.091 Y143.084 E-.26198
; WIPE_END
G1 E-.04 F1800
G1 X158.94 Y139.717 Z8.4 F36000
G1 X166.807 Y135.85 Z8.4
G1 Z8
G1 E.8 F1800
; FEATURE: Top surface
G1 F12000
M204 S2000
G1 X168.667 Y133.99 E.08085
G1 X168.516 Y133.608
G1 X165.343 Y136.781 E.13791
; WIPE_START
M204 S10000
G1 X166.757 Y135.367 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X163.879 Y137.712 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X168.351 Y133.239 E.19436
G1 X168.163 Y132.895
G1 X162.415 Y138.643 E.24978
; WIPE_START
M204 S10000
G1 X163.829 Y137.229 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.95 Y139.574 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X167.949 Y132.575 E.30414
G1 X167.708 Y132.283
G1 X159.486 Y140.505 E.35726
; WIPE_START
M204 S10000
G1 X160.901 Y139.09 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X158.022 Y141.436 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X167.448 Y132.01 E.40959
G1 X167.176 Y131.748
G1 X156.558 Y142.366 E.4614
; WIPE_START
M204 S10000
G1 X157.972 Y140.952 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.094 Y143.297 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X166.902 Y131.489 E.51312
G1 X166.628 Y131.23
G1 X153.63 Y144.228 E.56484
G1 X153.085 Y144.24
G1 X166.354 Y130.97 E.57663
G1 X166.081 Y130.711
G1 X152.882 Y143.909 E.57353
G1 X152.68 Y143.579
G1 X165.81 Y130.448 E.57058
G1 X165.543 Y130.182
G1 X152.464 Y143.261 E.56836
G1 X152.247 Y142.945
G1 X165.278 Y129.914 E.56627
G1 X165.025 Y129.633
G1 X152.03 Y142.629 E.56473
G1 X151.812 Y142.313
G1 X164.773 Y129.352 E.5632
G1 X164.52 Y129.072
G1 X151.583 Y142.009 E.5622
G1 X151.351 Y141.707
G1 X164.277 Y128.782 E.56169
G1 X164.039 Y128.487
G1 X151.12 Y141.406 E.56138
G1 X150.888 Y141.104
G1 X154.549 Y137.443 E.15909
G1 X153.864 Y137.595
G1 X150.645 Y140.814 E.13988
G1 X150.399 Y140.526
G1 X153.31 Y137.616 E.12647
G1 X152.828 Y137.565
G1 X150.153 Y140.239 E.11621
G1 X149.908 Y139.951
G1 X152.397 Y137.462 E.10818
G1 X152.008 Y137.317
G1 X149.652 Y139.674 E.10239
G1 X149.393 Y139.4
G1 X151.656 Y137.137 E.09834
G1 X151.335 Y136.924
G1 X149.133 Y139.126 E.09571
G1 X148.873 Y138.853
G1 X151.045 Y136.681 E.09436
G1 X150.783 Y136.41
G1 X148.604 Y138.588 E.09466
G1 X148.331 Y138.329
G1 X150.55 Y136.11 E.09642
G1 X150.347 Y135.779
G1 X148.057 Y138.069 E.0995
G1 X147.784 Y137.809
G1 X150.177 Y135.416 E.10402
G1 X150.045 Y135.014
G1 X147.502 Y137.558 E.11053
G1 X147.214 Y137.312
G1 X149.957 Y134.569 E.1192
G1 X149.924 Y134.069
G1 X146.926 Y137.067 E.13027
G1 X146.639 Y136.822
G1 X149.983 Y133.477 E.14532
G1 X150.214 Y132.713
G1 X146.344 Y136.582 E.16814
; WIPE_START
M204 S10000
G1 X147.759 Y135.168 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.391 Y135.213 Z8.4 F36000
G1 X156.771 Y135.221 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X163.81 Y128.182 E.30589
G1 X163.583 Y127.876
G1 X156.926 Y134.533 E.28927
G1 X156.953 Y133.973
G1 X163.362 Y127.564 E.27849
G1 X163.148 Y127.245
G1 X156.899 Y133.493 E.27154
G1 X156.795 Y133.064
G1 X162.934 Y126.925 E.26677
G1 X162.72 Y126.606
G1 X156.649 Y132.676 E.26379
G1 X156.469 Y132.324
G1 X162.506 Y126.287 E.26234
G1 X162.292 Y125.968
G1 X156.256 Y132.003 E.26228
G1 X156.014 Y131.712
G1 X162.078 Y125.648 E.26352
G1 X161.859 Y125.333
G1 X155.743 Y131.45 E.2658
G1 X155.443 Y131.217
M73 P94 R0
G1 X161.626 Y125.034 E.2687
G1 X161.371 Y124.755
G1 X155.113 Y131.014 E.27195
G1 X154.751 Y130.842
G1 X161.089 Y124.504 E.27541
G1 X160.782 Y124.277
G1 X154.352 Y130.708 E.27945
G1 X153.905 Y130.622
G1 X160.459 Y124.068 E.28481
G1 X160.132 Y123.861
G1 X153.401 Y130.592 E.29247
G1 X152.814 Y130.646
G1 X159.799 Y123.661 E.30354
G1 X159.467 Y123.46
G1 X152.049 Y130.878 E.32237
; WIPE_START
M204 S10000
G1 X153.463 Y129.464 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X147.868 Y134.656 Z8.4 F36000
G1 X146.043 Y136.351 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X159.134 Y123.259 E.5689
G1 X158.802 Y123.058
G1 X145.741 Y136.119 E.56756
G1 X145.439 Y135.888
G1 X158.469 Y122.858 E.56623
G1 X158.142 Y122.651
G1 X145.131 Y135.663 E.5654
G1 X144.815 Y135.446
G1 X157.824 Y122.436 E.56532
G1 X157.507 Y122.221
G1 X144.499 Y135.228 E.56524
G1 X144.183 Y135.011
G1 X157.199 Y121.995 E.56561
G1 X156.894 Y121.767
G1 X143.86 Y134.8 E.56638
G1 X143.53 Y134.598
G1 X156.597 Y121.53 E.56785
G1 X156.305 Y121.289
G1 X143.199 Y134.396 E.56955
G1 X142.868 Y134.193
M73 P95 R0
G1 X156.02 Y121.041 E.57151
G1 X155.734 Y120.794
G1 X142.531 Y133.997 E.57373
G1 X142.185 Y133.809
G1 X155.46 Y120.534 E.57687
G1 X155.188 Y120.274
G1 X141.84 Y133.622 E.58003
G1 X141.494 Y133.434
G1 X154.915 Y120.013 E.5832
G1 X154.642 Y119.753
G1 X141.14 Y133.255 E.58673
G1 X140.779 Y133.083
G1 X154.369 Y119.492 E.59056
G1 X154.096 Y119.232
G1 X140.418 Y132.91 E.59439
G1 X140.057 Y132.738
G1 X153.823 Y118.971 E.59823
G1 X153.541 Y118.721
G1 X139.685 Y132.577 E.60212
G1 X139.307 Y132.421
G1 X153.24 Y118.488 E.60543
G1 X152.914 Y118.281
G1 X138.93 Y132.265 E.60764
G1 X138.553 Y132.109
G1 X152.562 Y118.1 E.60875
G1 X152.187 Y117.942
G1 X138.161 Y131.968 E.60949
G1 X137.767 Y131.828
G1 X151.789 Y117.807 E.60932
G1 X151.391 Y117.671
G1 X137.373 Y131.689 E.60915
G1 X136.975 Y131.554
G1 X150.993 Y117.536 E.60916
G1 X150.595 Y117.4
G1 X136.564 Y131.432 E.60975
G1 X136.152 Y131.31
G1 X150.198 Y117.265 E.61034
G1 X149.8 Y117.129
G1 X135.741 Y131.188 E.61093
G1 X135.317 Y131.078
G1 X149.409 Y116.987 E.61234
G1 X149.027 Y116.836
G1 X134.887 Y130.975 E.61443
G1 X134.457 Y130.872
G1 X148.647 Y116.683 E.61659
G1 X148.278 Y116.519
G1 X134.024 Y130.772 E.61938
G1 X133.574 Y130.689
G1 X147.914 Y116.349 E.62313
G1 X147.555 Y116.174
G1 X133.124 Y130.605 E.6271
G1 X132.674 Y130.522
G1 X147.208 Y115.989 E.63154
G1 X146.861 Y115.802
G1 X132.207 Y130.456 E.63678
G1 X131.736 Y130.394
G1 X146.521 Y115.608 E.64249
G1 X146.189 Y115.407
G1 X131.265 Y130.332 E.64853
G1 X130.781 Y130.283
G1 X145.857 Y115.206 E.65513
G1 X145.525 Y115.005
G1 X130.286 Y130.244 E.66218
G1 X129.792 Y130.205
G1 X145.192 Y114.804 E.66922
G1 X144.86 Y114.603
G1 X129.286 Y130.177 E.67676
G1 X128.766 Y130.164
G1 X144.528 Y114.402 E.68491
G1 X144.189 Y114.208
G1 X128.247 Y130.15 E.69278
G1 X127.713 Y130.15
G1 X143.836 Y114.028 E.7006
G1 X143.452 Y113.878
G1 X127.166 Y130.165 E.70773
G1 X126.618 Y130.179
G1 X143.029 Y113.768 E.71314
G1 X142.574 Y113.689
G1 X131.12 Y125.144 E.49776
G1 X131.415 Y124.316
G1 X142.099 Y113.631 E.46429
G1 X141.617 Y113.58
G1 X131.494 Y123.704 E.43991
G1 X131.478 Y123.186
G1 X141.135 Y113.529 E.41966
G1 X140.653 Y113.478
G1 X131.402 Y122.729 E.40201
G1 X131.274 Y122.323
G1 X140.171 Y113.427 E.38659
G1 X139.705 Y113.36
G1 X131.11 Y121.955 E.37349
G1 X130.912 Y121.619
G1 X139.239 Y113.292 E.36184
G1 X138.789 Y113.209
G1 X130.685 Y121.313 E.35218
G1 X130.428 Y121.036
G1 X138.348 Y113.117 E.34415
G1 X137.913 Y113.019
G1 X130.143 Y120.789 E.33764
G1 X129.828 Y120.57
G1 X137.495 Y112.903 E.33316
G1 X137.083 Y112.782
G1 X129.482 Y120.383 E.33032
G1 X129.101 Y120.23
G1 X136.685 Y112.646 E.32956
G1 X136.287 Y112.511
G1 X128.681 Y120.117 E.33053
G1 X128.213 Y120.052
M73 P96 R0
G1 X135.906 Y112.359 E.3343
G1 X135.528 Y112.204
G1 X127.671 Y120.061 E.34144
G1 X127.019 Y120.18
G1 X135.15 Y112.048 E.35334
G1 X134.772 Y111.893
G1 X126.028 Y120.637 E.37996
; WIPE_START
M204 S10000
G1 X127.443 Y119.223 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X126.483 Y126.794 Z8.4 F36000
G1 X126.049 Y130.215 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X129.567 Y126.697 E.15287
G1 X128.733 Y126.998
G1 X125.47 Y130.26 E.14177
G1 X124.891 Y130.307
G1 X128.126 Y127.071 E.1406
G1 X127.606 Y127.058
G1 X124.277 Y130.388 E.14468
G1 X123.662 Y130.468
G1 X127.155 Y126.976 E.15176
G1 X126.748 Y126.85
G1 X123.026 Y130.571 E.16172
G1 X122.372 Y130.693
G1 X126.379 Y126.685 E.17413
G1 X126.042 Y126.489
G1 X121.706 Y130.825 E.18842
G1 X121.005 Y130.993
G1 X125.737 Y126.261 E.20562
G1 X125.46 Y126.004
G1 X120.298 Y131.167 E.22434
G1 X119.54 Y131.391
G1 X125.212 Y125.719 E.24647
G1 X124.993 Y125.405
G1 X118.772 Y131.626 E.27033
G1 X117.947 Y131.918
G1 X124.806 Y125.059 E.29806
G1 X124.652 Y124.679
G1 X117.088 Y132.243 E.3287
G1 X116.178 Y132.62
G1 X124.538 Y124.26 E.36329
G1 X124.475 Y123.79
G1 X115.178 Y133.088 E.40403
G1 X114.09 Y133.642
G1 X124.484 Y123.247 E.45168
G1 X124.606 Y122.592
G1 X112.86 Y134.339 E.51043
; WIPE_START
M204 S10000
G1 X114.274 Y132.924 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X111.369 Y135.297 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X125.073 Y121.592 E.59554
; WIPE_START
M204 S10000
G1 X123.659 Y123.006 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X128.924 Y117.48 Z8.4 F36000
G1 X134.394 Y111.738 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X109.214 Y136.918 E1.09422
; WIPE_START
M204 S10000
G1 X110.628 Y135.504 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.435 Y141.098 Z8.4 F36000
G1 X103.719 Y142.946 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X102.411 Y144.254 E.05686
G1 X102.091 Y144.041
G1 X105.341 Y140.791 E.14124
; WIPE_START
M204 S10000
G1 X103.927 Y142.205 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X101.77 Y143.828 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X134.013 Y111.586 E1.40109
G1 X133.617 Y111.449
G1 X101.45 Y143.615 E1.39779
G1 X101.13 Y143.402
G1 X133.171 Y111.361 E1.39232
G1 X132.6 Y111.399
G1 X100.81 Y143.189 E1.38142
G1 X100.49 Y142.976
G1 X131.958 Y111.508 E1.36743
G1 X131.308 Y111.625
G1 X100.17 Y142.763 E1.3531
G1 X99.85 Y142.55
G1 X130.661 Y111.738 E1.33892
G1 X130.036 Y111.83
G1 X99.529 Y142.336 E1.32566
G1 X99.209 Y142.123
G1 X104.071 Y137.262 E.21125
G1 X103.253 Y137.546
G1 X98.889 Y141.91 E.18963
G1 X98.569 Y141.697
G1 X102.65 Y137.616 E.17733
G1 X102.133 Y137.6
G1 X98.249 Y141.484 E.16879
G1 X97.929 Y141.271
G1 X101.684 Y137.516 E.16317
G1 X101.278 Y137.388
G1 X97.609 Y141.058 E.15945
G1 X97.289 Y140.845
G1 X100.91 Y137.223 E.15737
G1 X100.575 Y137.025
G1 X96.968 Y140.632 E.15672
G1 X96.648 Y140.418
G1 X100.27 Y136.797 E.15739
G1 X99.994 Y136.539
G1 X96.328 Y140.205 E.15932
G1 X96.008 Y139.992
G1 X99.747 Y136.253 E.1625
G1 X99.53 Y135.937
G1 X95.688 Y139.779 E.16696
G1 X95.368 Y139.566
G1 X99.343 Y135.59 E.17277
G1 X99.191 Y135.209
G1 X95.048 Y139.353 E.18007
G1 X94.727 Y139.14
G1 X99.078 Y134.789 E.18907
G1 X99.019 Y134.315
G1 X94.407 Y138.927 E.2004
G1 X94.087 Y138.713
G1 X99.03 Y133.77 E.2148
G1 X99.159 Y133.108
G1 X93.767 Y138.5 E.2343
G1 X93.447 Y138.287
G1 X99.664 Y132.07 E.27015
; WIPE_START
M204 S10000
G1 X98.249 Y133.485 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.577 Y135.62 Z8.4 F36000
G1 X105.682 Y135.65 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X129.436 Y111.897 E1.0322
G1 X128.851 Y111.948
G1 X105.966 Y134.834 E.99449
G1 X106.039 Y134.228
G1 X128.296 Y111.97 E.9672
G1 X127.761 Y111.972
G1 X106.02 Y133.713 E.94471
G1 X105.941 Y133.259
G1 X127.241 Y111.959 E.9256
G1 X126.75 Y111.916
G1 X105.813 Y132.854 E.90985
G1 X105.647 Y132.486
M73 P97 R0
G1 X126.26 Y111.873 E.89574
G1 X125.791 Y111.809
G1 X105.448 Y132.151 E.88396
G1 X105.22 Y131.847
G1 X125.326 Y111.741 E.8737
G1 X124.871 Y111.662
G1 X104.962 Y131.571 E.86516
G1 X104.676 Y131.324
G1 X124.42 Y111.58 E.858
G1 X123.969 Y111.498
G1 X104.36 Y131.107 E.85212
G1 X104.013 Y130.921
G1 X123.509 Y111.424 E.84723
G1 X123.029 Y111.371
G1 X103.631 Y130.77 E.84296
G1 X103.209 Y130.658
G1 X122.442 Y111.425 E.83576
G1 X121.607 Y111.727
G1 X102.739 Y130.595 E.8199
G1 X102.193 Y130.608
G1 X120.691 Y112.109 E.80385
G1 X119.808 Y112.459
G1 X101.534 Y130.733 E.79411
G1 X100.497 Y131.237
G1 X118.984 Y112.75 E.80337
G1 X118.231 Y112.97
G1 X93.127 Y138.074 E1.0909
G1 X92.807 Y137.861
G1 X96.629 Y134.038 E.16612
G1 X96.096 Y134.038
G1 X92.486 Y137.648 E.15686
G1 X92.166 Y137.435
G1 X95.563 Y134.038 E.1476
G1 X95.03 Y134.038
G1 X91.846 Y137.222 E.13833
G1 X91.526 Y137.009
G1 X94.496 Y134.038 E.12907
G1 X93.963 Y134.038
G1 X91.206 Y136.795 E.11981
G1 X90.886 Y136.582
G1 X93.43 Y134.038 E.11055
G1 X93.426 Y133.509
G1 X90.566 Y136.369 E.12431
G1 X90.245 Y136.156
G1 X93.426 Y132.975 E.13822
G1 X93.426 Y132.442
G1 X89.925 Y135.943 E.15213
G1 X89.605 Y135.73
G1 X93.426 Y131.909 E.16604
G1 X93.426 Y131.376
G1 X89.285 Y135.517 E.17995
G1 X88.965 Y135.304
G1 X93.426 Y130.842 E.19387
G1 X93.426 Y130.309
G1 X88.645 Y135.09 E.20778
; WIPE_START
M204 S10000
G1 X90.059 Y133.676 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X96.661 Y134.007 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X117.531 Y113.137 E.9069
G1 X116.868 Y113.266
G1 X96.661 Y133.473 E.87811
G1 X96.661 Y132.94
G1 X116.238 Y113.363 E.85071
G1 X115.622 Y113.445
G1 X96.464 Y132.604 E.83251
G1 X96.361 Y132.174
G1 X115.026 Y113.509 E.81107
G1 X114.429 Y113.572
G1 X96.361 Y131.64 E.78514
G1 X96.661 Y130.807
G1 X113.832 Y113.636 E.74617
G1 X113.213 Y113.721
G1 X96.661 Y130.274 E.71928
G1 X96.598 Y129.803
G1 X112.526 Y113.875 E.69215
G1 X111.51 Y114.358
G1 X96.065 Y129.803 E.67117
G1 X95.531 Y129.803
G1 X110.158 Y115.177 E.6356
; WIPE_START
M204 S10000
G1 X108.744 Y116.591 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X108.876 Y115.926 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X94.998 Y129.803 E.60306
G1 X94.465 Y129.803
G1 X107.798 Y116.47 E.57941
G1 X106.873 Y116.862
G1 X93.932 Y129.803 E.56237
; WIPE_START
M204 S10000
G1 X95.346 Y128.389 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X89.74 Y133.569 Z8.4 F36000
G1 X88.325 Y134.877 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X106.025 Y117.177 E.76918
G1 X105.218 Y117.45
G1 X88.004 Y134.664 E.74802
G1 X87.684 Y134.451
G1 X104.411 Y117.724 E.72687
G1 X103.56 Y118.043
G1 X87.364 Y134.238 E.70377
G1 X87.114 Y133.955
G1 X101.294 Y119.775 E.61621
; WIPE_START
M204 S10000
G1 X99.88 Y121.189 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X98.047 Y122.488 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X91.312 Y129.224 E.29271
; WIPE_START
M204 S10000
G1 X92.726 Y127.81 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X92.771 Y127.231 Z8.4 F36000
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X96.813 Y123.189 E.17564
G1 X95.748 Y123.721
G1 X93.47 Y125.999 E.09898
; WIPE_START
M204 S10000
G1 X94.885 Y124.585 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X89.854 Y130.325 Z8.4 F36000
M73 P98 R0
G1 X87.332 Y133.203 Z8.4
G1 Z8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X90.083 Y130.453 E.11954
; WIPE_START
M204 S10000
G1 X88.669 Y131.867 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X96.233 Y130.848 Z8.4 F36000
G1 X126.569 Y126.762 Z8.4
G1 Z8
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.0971554
G1 F15000
G1 X126.512 Y126.772 E.00026
G1 X126.437 Y126.716 E.00041
G1 X127.333 Y127.065 F36000
; LINE_WIDTH: 0.104155
G1 F15000
G3 X127.185 Y126.982 I1.449 J-2.776 E.00085
; WIPE_START
G1 X127.333 Y127.065 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X128.392 Y127.05 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0966218
G1 F15000
G3 X128.198 Y127.143 I-1.778 J-3.439 E.00094
; WIPE_START
G1 X128.392 Y127.05 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X130.258 Y126.241 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0978437
G1 F15000
G1 X130.088 Y126.397 E.00103
; LINE_WIDTH: 0.126372
G1 X129.943 Y126.515 E.00127
; LINE_WIDTH: 0.164416
G1 X129.792 Y126.638 E.00193
; LINE_WIDTH: 0.2016
G1 X129.629 Y126.758 E.00263
; WIPE_START
G1 X129.792 Y126.638 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.181 Y125.206 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.212828
G1 F15000
G1 X131.114 Y125.3 E.0016
; LINE_WIDTH: 0.186388
G1 X130.997 Y125.447 E.00219
; LINE_WIDTH: 0.143564
G1 X130.878 Y125.597 E.00157
; LINE_WIDTH: 0.10515
G1 X130.675 Y125.826 E.00155
; WIPE_START
G1 X130.878 Y125.597 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X128.23 Y120.07 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0895819
G1 F15000
G1 X128.021 Y119.977 E.00087
; WIPE_START
G1 X128.23 Y120.07 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X126.95 Y120.11 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.100209
G1 F15000
G2 X126.65 Y120.308 I3.578 J5.745 E.00168
G1 X125.968 Y120.577 F36000
; LINE_WIDTH: 0.216263
G1 F15000
G1 X125.698 Y120.81 E.00505
; LINE_WIDTH: 0.199152
G1 X125.424 Y121.074 E.00484
G1 X125.013 Y121.531 E.00783
G1 X124.736 Y122.222 F36000
; LINE_WIDTH: 0.10136
G1 F15000
G1 X124.691 Y122.288 E.00038
; LINE_WIDTH: 0.138026
G2 X124.539 Y122.525 I4.301 J2.943 E.00218
; WIPE_START
G1 X124.691 Y122.288 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X124.942 Y125.325 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0941456
G1 F15000
G1 X124.899 Y125.272 E.00029
G1 X124.906 Y125.226 E.00019
; WIPE_START
G1 X124.899 Y125.272 E-.30557
G1 X124.942 Y125.325 E-.45443
; WIPE_END
G1 E-.04 F1800
G1 X118.779 Y129.827 Z8.4 F36000
G1 X109.154 Y136.858 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.220577
G1 F15000
G1 X108.714 Y137.264 E.00866
; LINE_WIDTH: 0.177406
G1 X108.273 Y137.672 E.00659
; LINE_WIDTH: 0.135678
G1 X107.169 Y138.748 E.01165
G1 X106.093 Y139.852 E.01166
; LINE_WIDTH: 0.1775
G1 X105.687 Y140.292 E.00656
; LINE_WIDTH: 0.220566
G1 X105.281 Y140.731 E.00866
; WIPE_START
G1 X105.687 Y140.292 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X111.308 Y135.236 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.209676
G1 F15000
G1 X111.101 Y135.408 E.00366
; LINE_WIDTH: 0.16615
G1 X110.894 Y135.581 E.00271
; LINE_WIDTH: 0.1225
G1 X110.686 Y135.754 E.00176
; LINE_WIDTH: 0.0944017
G1 X110.597 Y135.832 E.0005
; WIPE_START
G1 X110.686 Y135.754 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X112.799 Y134.278 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.203143
G1 F15000
G1 X112.615 Y134.423 E.00305
; LINE_WIDTH: 0.157151
G1 X112.432 Y134.567 E.00218
; LINE_WIDTH: 0.111158
G1 X112.248 Y134.712 E.0013
; WIPE_START
G1 X112.432 Y134.567 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X114.029 Y133.581 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.198715
G1 F15000
G1 X113.875 Y133.695 E.00243
; LINE_WIDTH: 0.154493
G1 X113.722 Y133.81 E.00174
; LINE_WIDTH: 0.110272
G1 X113.568 Y133.924 E.00105
; WIPE_START
G1 X113.722 Y133.81 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X116.114 Y132.557 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.187659
G1 F15000
G1 X115.995 Y132.639 E.00171
; LINE_WIDTH: 0.162258
G1 X115.867 Y132.729 E.00153
; LINE_WIDTH: 0.11286
G1 X115.738 Y132.82 E.0009
; WIPE_START
G1 X115.867 Y132.729 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.434 Y131.733 Z8.4 F36000
G1 X132.651 Y130.52 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.116535
G1 F15000
G1 X132.492 Y130.438 E.00107
; WIPE_START
G1 X132.651 Y130.52 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.139 Y131.996 Z8.4 F36000
G1 X156.839 Y135.288 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.138535
G1 F15000
G1 X156.706 Y135.486 E.00186
; LINE_WIDTH: 0.112859
G1 X156.606 Y135.626 E.00098
; WIPE_START
G1 X156.706 Y135.486 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.997 Y134.603 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.116054
G1 F15000
G1 X156.879 Y134.826 E.0015
; WIPE_START
G1 X156.997 Y134.603 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X151.987 Y130.816 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.188731
G1 F15000
G1 X151.801 Y130.945 E.00268
; LINE_WIDTH: 0.162877
G1 X151.796 Y130.949 E.00006
; LINE_WIDTH: 0.14346
G1 X151.671 Y131.045 E.00129
; LINE_WIDTH: 0.106594
G1 X151.547 Y131.142 E.00082
; WIPE_START
G1 X151.671 Y131.045 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X150.465 Y132.222 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.105493
G1 F15000
G1 X150.386 Y132.328 E.00067
; LINE_WIDTH: 0.140142
G1 X150.307 Y132.433 E.00105
; LINE_WIDTH: 0.175875
G1 X150.223 Y132.545 E.00152
; LINE_WIDTH: 0.202856
G1 X150.151 Y132.651 E.00166
; WIPE_START
G1 X150.223 Y132.545 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X149.855 Y133.872 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.105661
G1 F15000
G1 X149.94 Y134.085 E.00117
; WIPE_START
G1 X149.855 Y133.872 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.955 Y137.277 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.101716
G1 F15000
G3 X154.618 Y137.512 I-4.602 J-6.221 E.00197
; WIPE_START
G1 X154.955 Y137.277 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.033 Y143.237 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.20454
G1 F15000
G1 X154.837 Y143.394 E.00331
; LINE_WIDTH: 0.157989
G1 X154.641 Y143.551 E.00236
; LINE_WIDTH: 0.111437
G1 X154.445 Y143.708 E.0014
; WIPE_START
G1 X154.641 Y143.551 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.497 Y142.306 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.204548
G1 F15000
G1 X156.301 Y142.463 E.00331
; LINE_WIDTH: 0.157993
G1 X156.105 Y142.62 E.00236
; LINE_WIDTH: 0.111439
G1 X155.909 Y142.778 E.0014
; WIPE_START
G1 X156.105 Y142.62 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X157.962 Y141.375 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.20454
G1 F15000
G1 X157.765 Y141.532 E.00331
; LINE_WIDTH: 0.157989
G1 X157.569 Y141.689 E.00236
; LINE_WIDTH: 0.111437
G1 X157.373 Y141.847 E.0014
; WIPE_START
G1 X157.569 Y141.689 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X159.426 Y140.444 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.204549
G1 F15000
G1 X159.229 Y140.601 E.00331
; LINE_WIDTH: 0.157994
G1 X159.033 Y140.759 E.00236
; LINE_WIDTH: 0.111439
G1 X158.837 Y140.916 E.0014
; WIPE_START
G1 X159.033 Y140.759 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.89 Y139.513 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.204549
G1 F15000
G1 X160.694 Y139.67 E.00331
; LINE_WIDTH: 0.157994
G1 X160.497 Y139.828 E.00236
; LINE_WIDTH: 0.111439
G1 X160.301 Y139.985 E.0014
; WIPE_START
G1 X160.497 Y139.828 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X162.354 Y138.582 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.204548
G1 F15000
G1 X162.158 Y138.74 E.00331
; LINE_WIDTH: 0.157993
G1 X161.962 Y138.897 E.00236
; LINE_WIDTH: 0.111439
G1 X161.765 Y139.054 E.0014
; WIPE_START
G1 X161.962 Y138.897 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X163.818 Y137.651 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.204541
G1 F15000
G1 X163.622 Y137.809 E.00331
; LINE_WIDTH: 0.157989
G1 X163.426 Y137.966 E.00236
; LINE_WIDTH: 0.111437
G1 X163.229 Y138.123 E.0014
; WIPE_START
G1 X163.426 Y137.966 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X165.282 Y136.721 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.204556
G1 F15000
G1 X165.086 Y136.878 E.00331
; LINE_WIDTH: 0.157998
G1 X164.89 Y137.035 E.00236
; LINE_WIDTH: 0.11144
G1 X164.694 Y137.193 E.0014
; WIPE_START
G1 X164.89 Y137.035 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X166.746 Y135.79 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.204539
G1 F15000
G1 X166.55 Y135.947 E.00331
; LINE_WIDTH: 0.157988
G1 X166.354 Y136.104 E.00236
; LINE_WIDTH: 0.111437
G1 X166.158 Y136.262 E.0014
; WIPE_START
G1 X166.354 Y136.104 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X168.834 Y134.359 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.359192
G1 F15000
G1 X168.632 Y134.521 E.00667
; LINE_WIDTH: 0.309913
G1 X168.43 Y134.683 E.00563
; LINE_WIDTH: 0.260635
G1 X168.228 Y134.845 E.00459
; LINE_WIDTH: 0.211357
G1 X168.026 Y135.007 E.00355
; LINE_WIDTH: 0.162079
G1 X167.824 Y135.169 E.00251
; LINE_WIDTH: 0.1128
G1 X167.622 Y135.331 E.00147
; WIPE_START
G1 X167.824 Y135.169 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X162.75 Y129.467 Z8.4 F36000
G1 X152.725 Y118.203 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.103356
G1 F15000
G2 X152.606 Y118.117 I-.864 J1.073 E.00072
; WIPE_START
G1 X152.725 Y118.203 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.784 Y115.028 Z8.4 F36000
G1 X143.212 Y113.851 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0998045
G1 F15000
G1 X143.052 Y113.769 E.00083
; WIPE_START
G1 X143.212 Y113.851 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X137.67 Y112.994 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0922703
G1 F15000
G1 X137.525 Y112.91 E.00068
; WIPE_START
G1 X137.67 Y112.994 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X130.871 Y111.795 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.142959
G1 F15000
G1 X130.646 Y111.723 E.00192
; WIPE_START
G1 X130.871 Y111.795 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.239 Y111.905 Z8.4 F36000
G1 X121.106 Y111.935 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.108563
G1 F15000
G1 X120.989 Y112.014 E.00076
; LINE_WIDTH: 0.149339
G1 X120.871 Y112.093 E.00123
; LINE_WIDTH: 0.190114
G1 X120.754 Y112.171 E.00169
; WIPE_START
G1 X120.871 Y112.093 E-.76
; WIPE_END
M73 P99 R0
G1 E-.04 F1800
G1 X113.501 Y114.076 Z8.4 F36000
G1 X110.759 Y114.814 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.11108
G1 F15000
G1 X110.579 Y114.955 E.00127
; LINE_WIDTH: 0.15689
G1 X110.399 Y115.096 E.00212
; LINE_WIDTH: 0.2027
G1 X110.219 Y115.238 E.00298
G1 X109.408 Y115.633 F36000
; LINE_WIDTH: 0.100992
G1 F15000
G1 X109.306 Y115.712 E.00061
; LINE_WIDTH: 0.131701
G1 X109.183 Y115.804 E.00111
; LINE_WIDTH: 0.167274
G1 X109.06 Y115.895 E.00155
; LINE_WIDTH: 0.202847
G1 X108.937 Y115.987 E.00199
G1 X108.26 Y116.248 F36000
; LINE_WIDTH: 0.109115
G1 F15000
G1 X108.151 Y116.326 E.00073
; LINE_WIDTH: 0.151021
G1 X108.041 Y116.404 E.00119
; LINE_WIDTH: 0.182727
G1 X107.932 Y116.482 E.00153
G1 X107.785 Y116.457 E.00169
; WIPE_START
G1 X107.932 Y116.482 E-.39892
G1 X108.041 Y116.404 E-.36108
; WIPE_END
G1 E-.04 F1800
G1 X102.985 Y118.323 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.111993
G1 F15000
G1 X102.818 Y118.452 E.00119
; LINE_WIDTH: 0.15345
G1 X102.607 Y118.638 E.00253
; LINE_WIDTH: 0.188682
G1 X102.396 Y118.824 E.00334
; LINE_WIDTH: 0.231978
G2 X101.354 Y119.835 I41.829 J44.155 E.02236
; WIPE_START
G1 X102.396 Y118.824 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X98.799 Y121.973 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0943214
G1 F15000
G1 X98.708 Y122.053 E.00051
; LINE_WIDTH: 0.122126
G1 X98.508 Y122.219 E.00167
; LINE_WIDTH: 0.16522
G1 X98.308 Y122.384 E.00258
; LINE_WIDTH: 0.208313
G1 X98.108 Y122.549 E.0035
G1 X97.325 Y122.917 F36000
; LINE_WIDTH: 0.110137
G1 F15000
G1 X97.175 Y123.028 E.00102
; LINE_WIDTH: 0.154117
G1 X97.024 Y123.139 E.00169
; LINE_WIDTH: 0.198097
G1 X96.874 Y123.251 E.00236
; WIPE_START
G1 X97.024 Y123.139 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X95.174 Y124.001 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.109195
G1 F15000
G1 X95.061 Y124.082 E.00075
; LINE_WIDTH: 0.151263
G1 X94.948 Y124.163 E.00123
; LINE_WIDTH: 0.19012
G1 X94.838 Y124.248 E.00166
; LINE_WIDTH: 0.225741
G1 X94.728 Y124.332 E.00207
; LINE_WIDTH: 0.261363
G1 X94.618 Y124.417 E.00247
; LINE_WIDTH: 0.292004
G2 X94.276 Y124.761 I1.349 J1.686 E.00987
; LINE_WIDTH: 0.259047
G1 X94.174 Y124.889 E.00288
; LINE_WIDTH: 0.222103
G1 X94.072 Y125.017 E.00239
; LINE_WIDTH: 0.184373
G1 X93.988 Y125.13 E.00163
; LINE_WIDTH: 0.145892
G1 X93.903 Y125.243 E.00118
; LINE_WIDTH: 0.10741
G1 X93.819 Y125.356 E.00074
G1 X93.532 Y126.06 F36000
; LINE_WIDTH: 0.198636
G1 F15000
G1 X93.417 Y126.213 E.00242
; LINE_WIDTH: 0.154449
G1 X93.303 Y126.366 E.00173
; LINE_WIDTH: 0.110263
G1 X93.189 Y126.519 E.00105
G1 X92.832 Y127.292 F36000
; LINE_WIDTH: 0.207774
G1 F15000
G1 X92.693 Y127.471 E.00304
; LINE_WIDTH: 0.173637
G1 X92.571 Y127.618 E.00204
; LINE_WIDTH: 0.13945
G1 X92.449 Y127.766 E.00151
; LINE_WIDTH: 0.105264
G1 X92.326 Y127.914 E.00097
; WIPE_START
G1 X92.449 Y127.766 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X91.372 Y129.284 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.232415
G1 F15000
G1 X91.067 Y129.606 E.00684
G3 X90.143 Y130.513 I-59.178 J-59.431 E.01999
; WIPE_START
G1 X91.067 Y129.606 E-.56618
G1 X91.372 Y129.284 E-.19382
; WIPE_END
G1 E-.04 F1800
G1 X88.425 Y131.814 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.101424
G1 F15000
G1 X88.241 Y131.978 E.00117
; LINE_WIDTH: 0.143438
G2 X87.625 Y132.574 I5.38 J6.178 E.00702
; LINE_WIDTH: 0.11805
G1 X87.513 Y132.719 E.00113
; LINE_WIDTH: 0.0912308
G1 X87.492 Y132.751 E.00015
; WIPE_START
G1 X87.513 Y132.719 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X93.734 Y137.142 Z8.4 F36000
G1 X103.135 Y143.825 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.107472
G1 F15000
G1 X103.014 Y143.978 E.00103
; LINE_WIDTH: 0.14609
G1 X102.894 Y144.132 E.00164
; LINE_WIDTH: 0.184708
G1 X102.773 Y144.285 E.00225
; LINE_WIDTH: 0.223326
G1 X102.652 Y144.438 E.00287
; WIPE_START
G1 X102.773 Y144.285 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.254 Y142.174 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0944839
G1 F15000
G1 X104.176 Y142.264 E.0005
; LINE_WIDTH: 0.122633
G1 X104.003 Y142.471 E.00175
; LINE_WIDTH: 0.166159
G1 X103.831 Y142.678 E.00271
; LINE_WIDTH: 0.209685
G1 X103.659 Y142.886 E.00366
; WIPE_START
G1 X103.831 Y142.678 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.688 Y136.88 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0908671
G1 F15000
G1 X104.628 Y136.935 E.00032
; LINE_WIDTH: 0.112408
G1 X104.484 Y137.053 E.00106
; LINE_WIDTH: 0.150384
G1 X104.333 Y137.176 E.0017
; LINE_WIDTH: 0.194526
G1 X104.132 Y137.323 E.00308
; WIPE_START
G1 X104.333 Y137.176 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.744 Y135.712 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.205475
G1 F15000
G1 X105.652 Y135.84 E.00209
; LINE_WIDTH: 0.172339
G1 X105.535 Y135.987 E.00198
; LINE_WIDTH: 0.129519
G1 X105.416 Y136.137 E.00135
; LINE_WIDTH: 0.0981408
G1 X105.287 Y136.282 E.00087
; WIPE_START
G1 X105.416 Y136.137 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X106.035 Y134.903 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.0972447
G1 F15000
G3 X105.88 Y135.161 I-4.66 J-2.628 E.00133
; WIPE_START
G1 X106.035 Y134.903 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X102.122 Y130.537 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.108022
G1 F15000
G2 X101.91 Y130.647 I1.892 J3.903 E.00127
; WIPE_START
G1 X102.122 Y130.537 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X100.436 Y131.177 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.212892
G1 F15000
G1 X99.969 Y131.607 E.0088
G1 X99.603 Y132.01 E.00753
G1 X99.295 Y132.732 F36000
; LINE_WIDTH: 0.104958
G1 F15000
G1 X99.239 Y132.814 E.0005
; LINE_WIDTH: 0.150056
G2 X99.092 Y133.042 I4.168 J2.865 E.00237
; WIPE_START
G1 X99.239 Y132.814 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X99.179 Y135.172 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.100431
G1 F15000
G3 X99.097 Y135.037 I2.247 J-1.461 E.00074
; WIPE_START
G1 X99.179 Y135.172 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X93.622 Y134.019 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.101534
G1 F15000
G1 X93.645 Y134.048 E.00018
G1 X93.531 Y134.14 E.0007
; close powerlost recovery
M1003 S0
; WIPE_START
G1 F15000
G1 X93.645 Y134.048 E-.60596
G1 X93.622 Y134.019 E-.15404
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

