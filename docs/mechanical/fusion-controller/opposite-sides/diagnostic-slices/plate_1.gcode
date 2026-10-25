; HEADER_BLOCK_START
; BambuStudio 02.04.00.70
; model printing time: 15m 15s; total estimated time: 23m 11s
; total layer number: 63
; total filament length [mm] : 3294.11
; total filament volume [cm^3] : 7923.26
; total filament weight [g] : 9.98
; filament_density: 1.26
; filament_diameter: 1.75
; max_z_height: 12.60
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
M73 P0 R23
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
M73 P6 R21
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
    
      G29 A1 X90.8414 Y100.5 I74.3172 J55
    
    M400
    M500 ; save cali data
  M623
    
  M622 J2
    M1002 gcode_claim_action : 1
    
      G29 A2 X90.8414 Y100.5 I74.3172 J55
    
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
M73 P34 R15
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
G1 X133.765 Y118.503
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.5
G1 F3000
M204 S500
G1 X133.303 Y119.081 E.02756
G3 X127.531 Y107.508 I-5.3 J-4.582 E1.02606
G3 X131.191 Y108.261 I.44 J7.136 E.14081
G3 X133.807 Y110.55 I-3.551 J6.698 E.13065
G1 X133.807 Y118.45 E.29424
G1 X133.802 Y118.456 E.00028
M204 S6000
G1 X133.326 Y118.319 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X132.961 Y118.786 E.02205
G3 X127.561 Y107.964 I-4.955 J-4.285 E.9593
G3 X133.35 Y110.71 I.417 J6.596 E.24913
G1 X133.35 Y118.268 E.28148
; WIPE_START
G1 X132.961 Y118.786 E-.24607
G1 X132.612 Y119.151 E-.19198
G1 X132.24 Y119.493 E-.19194
G1 X131.971 Y119.704 E-.13002
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X139.52 Y120.831 Z.6 F36000
G1 X139.561 Y120.837 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X164.01 Y132.238 E1.00478
G3 X91.99 Y132.238 I-36.01 J-17.747 E3.32822
G1 X116.431 Y120.84 E1.00446
G1 X115.821 Y119.44 E.05688
G3 X128.094 Y101.362 I12.181 J-4.936 E.9608
G3 X140.02 Y109.184 I-.098 J13.151 E.56146
G1 X140.503 Y110.357 E.04724
G1 X141.943 Y110.357 E.05363
G1 X141.943 Y118.643 E.30862
G1 X140.494 Y118.643 E.05396
G3 X139.583 Y120.784 I-27.162 J-10.294 E.08668
M204 S6000
G1 X140.161 Y120.612 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X164.624 Y132.019 E1.00534
G3 X91.376 Y132.019 I-36.624 J-17.528 E3.40088
G1 X115.834 Y120.614 E1.00514
G3 X114.515 Y116.268 I13.435 J-6.449 E.16985
G3 X128.097 Y100.905 I13.482 J-1.766 E.86519
G3 X140.438 Y109 I-.101 J13.609 E.58099
G1 X140.809 Y109.9 E.03628
G1 X142.4 Y109.9 E.05926
G1 X142.4 Y119.1 E.34267
G1 X140.805 Y119.1 E.05941
G3 X140.187 Y120.558 I-20.219 J-7.715 E.05899
; WIPE_START
G1 X141.997 Y121.407 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X148.761 Y124.944 Z.6 F36000
M73 P35 R15
G1 X163.573 Y132.691 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Bottom surface
; LINE_WIDTH: 0.50342
G1 F6300
M204 S500
G1 X163.144 Y132.262 E.02277
G1 X161.924 Y131.693 E.05052
G1 X163.2 Y132.97 E.06773
G3 X162.973 Y133.394 I-6.38 J-3.137 E.01806
G1 X160.704 Y131.124 E.12045
G1 X159.483 Y130.555 E.05052
G1 X162.741 Y133.813 E.17288
G1 X162.509 Y134.232 E.01798
G1 X158.263 Y129.986 E.22532
G1 X157.043 Y129.417 E.05052
G1 X162.269 Y134.643 E.27732
G1 X162.024 Y135.05 E.01781
G1 X155.822 Y128.848 E.32911
G1 X154.602 Y128.279 E.05052
G1 X161.78 Y135.457 E.38089
G3 X161.526 Y135.855 I-5.837 J-3.433 E.01771
G1 X153.382 Y127.71 E.43222
G1 X152.162 Y127.141 E.05052
G1 X161.27 Y136.25 E.48337
G1 X161.014 Y136.644 E.01767
G1 X150.941 Y126.572 E.53452
G1 X149.721 Y126.003 E.05052
G1 X160.748 Y137.03 E.58518
G1 X160.48 Y137.413 E.01755
G1 X148.501 Y125.434 E.6357
G1 X147.281 Y124.865 E.05052
G1 X160.212 Y137.796 E.68622
G3 X159.934 Y138.17 I-5.5 J-3.798 E.01747
G1 X146.06 Y124.296 E.73625
G1 X144.84 Y123.727 E.05052
G1 X159.654 Y138.541 E.78615
G1 X159.374 Y138.912 E.01745
G1 X143.62 Y123.158 E.83606
G1 X142.4 Y122.589 E.05052
G1 X159.085 Y139.274 E.88545
M73 P35 R14
G1 X158.793 Y139.634 E.01738
G1 X140.754 Y121.595 E.95731
; WIPE_START
G1 X142.168 Y123.009 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X141.897 Y115.381 Z.6 F36000
G1 X141.76 Y111.53 Z.6
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X140.77 Y110.54 E.05252
; WIPE_START
G1 X141.76 Y111.53 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X138.641 Y107.108 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G2 X136.66 Y105.137 I-75.292 J73.689 E.10488
G2 X134.293 Y103.412 I-8.812 J9.602 E.11012
G1 X139.097 Y108.215 E.25491
G3 X139.729 Y109.498 I-12.255 J6.834 E.05371
G1 X133.002 Y102.771 E.357
G2 X131.96 Y102.381 I-5.221 J12.345 E.04176
G1 X141.554 Y111.975 E.50916
G1 X141.554 Y112.626 E.02444
G1 X131.044 Y102.116 E.55776
G2 X130.22 Y101.944 I-4.121 J17.629 E.03158
G1 X141.554 Y113.278 E.60148
G1 X141.554 Y113.929 E.02444
G1 X129.459 Y101.834 E.64187
G2 X128.752 Y101.778 I-.763 J5.161 E.02663
G1 X141.554 Y114.58 E.67939
G1 X141.554 Y115.231 E.02444
G1 X128.074 Y101.751 E.71538
G1 X127.44 Y101.768 E.02381
G1 X141.554 Y115.883 E.74903
G1 X141.554 Y116.534 E.02444
G1 X126.825 Y101.804 E.78167
G2 X126.241 Y101.872 I.368 J5.759 E.02207
G1 X141.554 Y117.185 E.81265
G1 X141.554 Y117.836 E.02444
G1 X125.68 Y101.962 E.84243
G2 X125.139 Y102.072 I.814 J5.366 E.02072
G1 X130.677 Y107.61 E.29388
G2 X129.725 Y107.309 I-3.225 J8.544 E.0375
G1 X124.619 Y102.204 E.27093
G2 X124.119 Y102.355 I1.215 J4.935 E.01962
G1 X128.932 Y107.168 E.25544
G2 X128.225 Y107.112 I-.713 J4.485 E.02667
G1 X123.634 Y102.521 E.24362
G2 X123.164 Y102.702 I1.546 J4.715 E.01891
G1 X127.58 Y107.118 E.23435
G2 X126.986 Y107.175 I.073 J3.874 E.02242
G1 X122.707 Y102.897 E.22705
G1 X122.269 Y103.109 E.01829
G1 X126.433 Y107.273 E.22098
G2 X125.915 Y107.407 I.602 J3.418 E.02009
G1 X121.843 Y103.335 E.21607
G2 X121.429 Y103.573 I2.101 J4.142 E.01791
G1 X125.427 Y107.57 E.21214
G2 X124.966 Y107.76 I1 J3.079 E.01873
G1 X121.027 Y103.821 E.20902
G2 X120.641 Y104.087 I2.411 J3.913 E.01758
G1 X124.529 Y107.975 E.20632
G2 X124.115 Y108.212 I1.348 J2.841 E.01793
G1 X120.266 Y104.363 E.20423
M73 P36 R14
G2 X119.902 Y104.65 I2.62 J3.714 E.01741
G1 X123.722 Y108.47 E.20272
G1 X123.35 Y108.749 E.01745
G1 X119.55 Y104.95 E.20165
G2 X119.212 Y105.263 I2.896 J3.469 E.0173
G1 X123.002 Y109.053 E.20115
G2 X122.674 Y109.376 I1.923 J2.286 E.0173
G1 X118.884 Y105.585 E.20114
G1 X118.566 Y105.919 E.01728
G1 X122.365 Y109.718 E.20161
G2 X122.074 Y110.079 I2.23 J2.088 E.0174
G1 X118.263 Y106.268 E.20225
G2 X117.971 Y106.627 I3.379 J3.047 E.01738
G1 X121.804 Y110.46 E.20342
G1 X121.56 Y110.867 E.01781
G1 X117.689 Y106.996 E.20544
G1 X117.422 Y107.38 E.01755
G1 X121.338 Y111.297 E.20787
G2 X121.14 Y111.749 I2.832 J1.512 E.01857
G1 X117.167 Y107.776 E.21083
G2 X116.924 Y108.184 I3.843 J2.571 E.01783
G1 X120.967 Y112.228 E.21458
G2 X120.823 Y112.735 I3.156 J1.172 E.0198
G1 X116.691 Y108.603 E.21925
G1 X116.477 Y109.04 E.01826
G1 X120.711 Y113.274 E.22468
G2 X120.637 Y113.851 I3.699 J.766 E.02187
G1 X116.276 Y109.49 E.23145
G2 X116.088 Y109.953 I4.439 J2.072 E.01877
G1 X120.609 Y114.475 E.23994
G2 X120.638 Y115.154 I4.414 J.155 E.02556
G1 X115.914 Y110.431 E.25068
G1 X115.759 Y110.927 E.0195
G1 X120.739 Y115.907 E.2643
G2 X120.973 Y116.793 I10.35 J-2.266 E.03439
G1 X115.453 Y111.272 E.29295
; WIPE_START
G1 X116.867 Y112.687 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X124.46 Y111.905 Z.6 F36000
G1 X133.99 Y110.923 Z.6
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X141.321 Y118.254 E.38906
G1 X140.67 Y118.254 E.02444
G1 X134.196 Y111.78 E.34359
G1 X134.196 Y112.431 E.02444
G1 X140.171 Y118.406 E.31709
G1 X139.984 Y118.871 E.01878
G1 X134.196 Y113.082 E.30716
G1 X134.196 Y113.734 E.02444
G1 X139.797 Y119.335 E.29723
G3 X139.603 Y119.793 I-5.651 J-2.114 E.01866
G1 X134.196 Y114.385 E.28698
G1 X134.196 Y115.036 E.02444
G1 X139.556 Y120.397 E.28448
; WIPE_START
G1 X138.142 Y118.983 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X133.99 Y115.482 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X139.198 Y120.69 E.27639
G1 X139.047 Y121.025 E.01381
G1 X139.959 Y121.451 E.03778
G1 X158.502 Y139.994 E.98404
G3 X158.201 Y140.344 I-5.184 J-4.149 E.01733
G1 X134.196 Y116.339 E1.27393
G1 X134.196 Y116.99 E.02444
G1 X157.898 Y140.693 E1.25786
G1 X157.595 Y141.041 E.01732
G1 X134.196 Y117.641 E1.24179
G1 X134.196 Y118.292 E.02444
G1 X157.283 Y141.38 E1.2252
G1 X156.969 Y141.717 E.01729
G1 X134.037 Y118.785 E1.21696
G1 X133.748 Y119.147 E.01739
G1 X156.655 Y142.054 E1.21563
G3 X156.331 Y142.382 I-4.827 J-4.442 E.01728
G1 X133.446 Y119.497 E1.21445
G3 X133.126 Y119.828 I-2.3 J-1.909 E.0173
G1 X156.005 Y142.707 E1.21418
G1 X155.68 Y143.033 E.01728
G1 X132.786 Y120.139 E1.21493
G1 X132.421 Y120.426 E.01741
G1 X155.345 Y143.349 E1.21652
G1 X155.008 Y143.664 E.01729
G1 X132.036 Y120.692 E1.21906
G3 X131.631 Y120.937 I-1.818 J-2.546 E.01781
G1 X154.671 Y143.978 E1.22271
G3 X154.325 Y144.283 I-4.553 J-4.813 E.01732
G1 X131.203 Y121.162 E1.22702
G3 X130.752 Y121.362 I-1.521 J-2.818 E.01854
G1 X153.977 Y144.586 E1.23247
G1 X153.628 Y144.889 E.01732
M73 P37 R14
G1 X130.276 Y121.536 E1.23928
G1 X129.77 Y121.682 E.01975
G1 X153.271 Y145.183 E1.24716
G1 X152.911 Y145.474 E.01738
G1 X129.23 Y121.793 E1.25672
G3 X128.653 Y121.867 I-.77 J-3.693 E.02184
G1 X152.551 Y145.765 E1.26823
G3 X152.182 Y146.048 I-4.242 J-5.163 E.01744
G1 X128.029 Y121.895 E1.28175
G3 X127.346 Y121.863 I-.136 J-4.441 E.02568
G1 X151.811 Y146.328 E1.29828
G1 X151.439 Y146.607 E.01745
G1 X126.587 Y121.755 E1.31887
G3 X125.709 Y121.528 I1.527 J-7.729 E.03404
G1 X151.059 Y146.878 E1.34526
G1 X150.676 Y147.146 E.01755
G1 X124.584 Y121.055 E1.38461
G3 X121.444 Y117.914 I3.427 J-6.568 E.16929
G1 X115.503 Y111.973 E.31526
G2 X115.404 Y112.526 I5.361 J1.248 E.02106
G1 X150.293 Y147.414 E1.85148
G3 X149.9 Y147.673 I-3.889 J-5.487 E.01765
G1 X115.327 Y113.1 E1.83473
G2 X115.274 Y113.698 I5.852 J.815 E.02256
G1 X149.505 Y147.929 E1.81657
G1 X149.11 Y148.185 E.01767
G1 X115.25 Y114.325 E1.79691
G2 X115.258 Y114.984 I6.514 J.25 E.02475
G1 X148.704 Y148.431 E1.77496
G1 X148.298 Y148.676 E.01781
G1 X115.304 Y115.682 E1.75091
G2 X115.396 Y116.426 I7.332 J-.531 E.02812
G1 X147.891 Y148.92 E1.72443
G3 X147.472 Y149.153 I-3.519 J-5.838 E.01797
G1 X115.544 Y117.225 E1.69437
G2 X115.764 Y118.096 I17.565 J-3.972 E.03372
G1 X147.053 Y149.385 E1.66045
G3 X146.633 Y149.616 I-3.514 J-5.879 E.01799
G1 X116.103 Y119.086 E1.62019
G2 X116.584 Y120.218 I11.257 J-4.113 E.04617
G1 X146.202 Y149.836 E1.57178
G1 X145.771 Y150.056 E.01817
G1 X116.808 Y121.093 E1.537
G1 X116.364 Y121.3 E.01839
G1 X145.337 Y150.273 E1.53754
G1 X144.892 Y150.48 E.01839
M73 P38 R14
G1 X115.92 Y121.508 E1.53753
G1 X115.475 Y121.715 E.01839
G1 X144.448 Y150.687 E1.53753
G3 X143.999 Y150.89 I-3.123 J-6.333 E.01848
G1 X115.031 Y121.922 E1.53728
G1 X114.587 Y122.129 E.01839
G1 X143.542 Y151.084 E1.53659
G1 X143.085 Y151.278 E.01864
G1 X114.143 Y122.336 E1.53589
G1 X113.699 Y122.543 E.01839
G1 X142.62 Y151.464 E1.53479
G1 X142.149 Y151.645 E.01892
G1 X113.255 Y122.75 E1.53339
G1 X112.811 Y122.957 E.01839
G1 X141.679 Y151.825 E1.53198
G3 X141.197 Y151.995 I-2.664 J-6.818 E.01917
G1 X112.366 Y123.164 E1.52997
G1 X111.922 Y123.371 E.01839
G1 X140.712 Y152.161 E1.52783
G3 X140.226 Y152.327 I-2.615 J-6.9 E.01927
G1 X111.478 Y123.579 E1.5256
G1 X111.034 Y123.786 E.01839
G1 X139.727 Y152.479 E1.5227
G1 X139.229 Y152.632 E.01957
G1 X110.59 Y123.993 E1.51981
G1 X110.146 Y124.2 E.01839
G1 X138.723 Y152.777 E1.51655
G1 X138.209 Y152.915 E.01995
G1 X109.702 Y124.407 E1.51286
G1 X109.257 Y124.614 E.01839
G1 X137.696 Y153.052 E1.50917
G3 X137.169 Y153.177 I-2.049 J-7.492 E.02031
G1 X108.813 Y124.821 E1.50479
G1 X108.369 Y125.028 E.01839
G1 X136.64 Y153.299 E1.50028
G3 X136.106 Y153.417 I-1.95 J-7.595 E.02051
G1 X107.925 Y125.235 E1.49552
G1 X107.481 Y125.443 E.01839
G1 X135.561 Y153.523 E1.49016
G1 X135.016 Y153.629 E.02084
G1 X107.037 Y125.65 E1.48479
G1 X106.593 Y125.857 E.01839
G1 X134.457 Y153.721 E1.47871
G1 X133.895 Y153.81 E.02136
G1 X106.149 Y126.064 E1.47245
G1 X105.704 Y126.271 E.01839
M73 P39 R14
G1 X133.326 Y153.893 E1.46584
G1 X132.746 Y153.964 E.02193
G1 X105.26 Y126.478 E1.45863
G1 X104.816 Y126.685 E.01839
G1 X132.166 Y154.035 E1.45142
G3 X131.568 Y154.088 I-1.047 J-8.457 E.02255
G1 X104.372 Y126.892 E1.44323
G1 X103.928 Y127.099 E.01839
G1 X130.969 Y154.14 E1.43502
G3 X130.357 Y154.179 I-.865 J-8.761 E.02303
G1 X103.484 Y127.307 E1.42609
G1 X103.04 Y127.514 E.01839
G1 X129.738 Y154.212 E1.41682
G3 X129.11 Y154.235 I-.648 J-9.009 E.02359
G1 X102.595 Y127.721 E1.40707
G1 X102.151 Y127.928 E.01839
G1 X128.47 Y154.246 E1.39667
G3 X127.823 Y154.251 I-.393 J-9.261 E.02426
G1 X101.707 Y128.135 E1.38594
G1 X101.263 Y128.342 E.01839
G1 X127.161 Y154.24 E1.37434
G3 X126.494 Y154.224 I-.11 J-9.5 E.02504
G1 X100.819 Y128.549 E1.36251
G1 X100.375 Y128.756 E.01839
G1 X125.806 Y154.188 E1.34961
G3 X125.115 Y154.148 I.23 J-9.935 E.02599
G1 X99.931 Y128.963 E1.33649
G1 X99.486 Y129.17 E.01839
G1 X124.401 Y154.085 E1.32218
G3 X123.681 Y154.016 I.624 J-10.34 E.02715
G1 X99.042 Y129.378 E1.30754
G1 X98.598 Y129.585 E.01839
M73 P39 R13
G1 X122.939 Y153.925 E1.29172
G3 X122.185 Y153.823 I1.09 J-10.83 E.02855
G1 X98.154 Y129.792 E1.27528
G1 X97.71 Y129.999 E.01839
G1 X121.411 Y153.7 E1.25779
G3 X120.617 Y153.557 I1.651 J-11.444 E.03029
G1 X97.266 Y130.206 E1.2392
G1 X96.822 Y130.413 E.01839
G1 X119.808 Y153.4 E1.21987
G3 X118.965 Y153.208 I2.33 J-12.182 E.03246
G1 X96.377 Y130.62 E1.1987
G1 X95.933 Y130.827 E.01839
G1 X118.105 Y152.999 E1.17662
G1 X117.215 Y152.761 E.03456
G1 X95.489 Y131.034 E1.15298
G1 X95.045 Y131.242 E.01839
G1 X116.287 Y152.483 E1.12727
M73 P40 R13
G3 X115.327 Y152.175 I3.938 J-13.9 E.03783
G1 X94.601 Y131.449 E1.09991
G1 X94.157 Y131.656 E.01839
G1 X114.33 Y151.829 E1.07054
G1 X113.273 Y151.423 E.04249
G1 X93.713 Y131.863 E1.03802
G1 X93.268 Y132.07 E.01839
G1 X112.153 Y150.954 E1.00216
G3 X110.958 Y150.41 I7.19 J-17.386 E.04928
G1 X92.824 Y132.277 E.96231
G1 X92.519 Y132.419 E.01265
G1 X92.731 Y132.835 E.01752
G1 X109.664 Y149.768 E.89858
G3 X108.236 Y148.991 I10.401 J-20.82 E.06103
G1 X93.509 Y134.264 E.7815
G2 X94.52 Y135.927 I44.773 J-26.094 E.07302
G1 X106.573 Y147.98 E.63962
G3 X104.516 Y146.574 I25.668 J-39.768 E.09349
G1 X95.926 Y137.984 E.45588
G2 X99.353 Y142.062 I31.41 J-22.915 E.20004
G1 X102.777 Y145.486 E.18172
; CHANGE_LAYER
; Z_HEIGHT: 0.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F6300
G1 X101.363 Y144.072 E-.76
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
G1 X133.552 Y118.285
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.552 Y118.361 E.00251
G1 X133.11 Y118.914 E.02349
G3 X127.548 Y107.763 I-5.107 J-4.416 E.88054
G3 X133.552 Y110.639 I.413 J6.842 E.23062
G1 X133.552 Y118.225 E.25162
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.574 Y108.154 I-5.156 J-3.724 E.78549
G3 X133.16 Y110.777 I.408 J6.392 E.19785
G1 X133.16 Y118.163 E.22697
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22946
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X139.353 Y120.638 Z.8 F36000
G1 X139.897 Y120.712 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.8952
G3 X91.645 Y132.117 I-36.355 J-17.631 E3.00029
G1 X116.097 Y120.715 E.895
G3 X115.136 Y118.246 I16.182 J-7.719 E.08797
G3 X128.427 Y101.109 I12.872 J-3.739 E.83803
G3 X140.251 Y109.077 I-.429 J13.393 E.49871
G1 X140.674 Y110.102 E.03677
G1 X142.198 Y110.102 E.05056
G1 X142.198 Y118.898 E.29178
G1 X140.668 Y118.898 E.05076
G3 X139.92 Y120.659 I-23.396 J-8.899 E.06348
G1 X140.412 Y120.519 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.8295
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83055
G1 X115.586 Y120.521 E.82941
G3 X128.44 Y100.717 I12.425 J-6.009 E.87036
G3 X140.936 Y109.71 I-.459 J13.817 E.50172
G1 X142.59 Y109.71 E.05081
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05088
G3 X140.437 Y120.465 I-17.531 J-6.724 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.314 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X141.244 Y118.734 Z.8 F36000
G1 Z.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42235
G1 F15000
G1 X141.865 Y118.113 E.02715
G1 X141.865 Y117.577 E.01659
G1 X140.877 Y118.565 E.04319
G1 X140.443 Y118.565 E.01342
G1 X140.148 Y119.293 E.02429
G1 X109.441 Y150.001 E1.34272
G1 X109.791 Y150.187 E.01227
G1 X139.745 Y120.233 E1.30976
G1 X139.456 Y120.874 E.02174
G1 X139.582 Y120.933 E.0043
G1 X110.151 Y150.364 E1.28689
G1 X110.512 Y150.54 E.01241
G1 X139.948 Y121.103 E1.28712
G1 X140.314 Y121.274 E.01248
G1 X110.872 Y150.715 E1.28735
G2 X111.238 Y150.887 I2.631 J-5.145 E.01248
G1 X140.68 Y121.445 E1.28736
G1 X141.046 Y121.615 E.01248
G1 X111.609 Y151.052 E1.28713
G1 X111.981 Y151.217 E.01257
G1 X141.412 Y121.786 E1.2869
G1 X141.778 Y121.957 E.01248
G1 X112.352 Y151.382 E1.28666
G1 X112.734 Y151.537 E.01274
G1 X142.144 Y122.127 E1.28595
G1 X142.51 Y122.298 E.01248
G1 X113.116 Y151.691 E1.28524
G1 X113.499 Y151.846 E.01274
G1 X142.876 Y122.469 E1.28453
G1 X143.241 Y122.639 E.01248
G1 X113.888 Y151.993 E1.28351
G1 X114.281 Y152.136 E.01294
G1 X143.607 Y122.81 E1.28231
G1 X143.973 Y122.981 E.01248
G1 X114.675 Y152.279 E1.28111
G2 X115.071 Y152.419 I2.201 J-5.608 E.01301
G1 X144.339 Y123.151 E1.27977
G1 X144.705 Y123.322 E.01248
G1 X115.476 Y152.551 E1.27806
G1 X115.881 Y152.682 E.01317
G1 X145.071 Y123.492 E1.27635
G1 X145.437 Y123.663 E.01248
G1 X116.286 Y152.814 E1.27464
G1 X116.703 Y152.934 E.01341
G1 X145.803 Y123.834 E1.27241
G1 X146.169 Y124.004 E.01248
G1 X117.12 Y153.053 E1.27018
G1 X117.537 Y153.173 E.01341
G1 X146.535 Y124.175 E1.26794
G1 X146.901 Y124.346 E.01248
G1 X117.964 Y153.283 E1.26529
G1 X118.394 Y153.39 E.01369
G1 X147.267 Y124.516 E1.26251
G1 X147.633 Y124.687 E.01248
G1 X118.823 Y153.497 E1.25973
G2 X119.261 Y153.596 I1.636 J-6.212 E.01387
G1 X147.999 Y124.858 E1.2566
G1 X148.365 Y125.028 E.01248
M73 P41 R13
G1 X119.703 Y153.69 E1.25325
G1 X120.146 Y153.784 E.01399
G1 X148.731 Y125.199 E1.2499
G1 X149.097 Y125.37 E.01248
G1 X120.595 Y153.871 E1.24624
G1 X121.052 Y153.951 E.01432
G1 X149.463 Y125.54 E1.24229
G1 X149.829 Y125.711 E.01248
G1 X121.508 Y154.032 E1.23835
G2 X121.971 Y154.105 I1.282 J-6.614 E.01451
G1 X150.195 Y125.881 E1.23409
G1 X150.56 Y126.052 E.01248
G1 X122.442 Y154.171 E1.22952
G1 X122.912 Y154.237 E.01469
G1 X150.926 Y126.223 E1.22495
G1 X151.292 Y126.393 E.01248
G1 X123.391 Y154.295 E1.22
G1 X123.877 Y154.346 E.0151
G1 X151.658 Y126.564 E1.21477
G1 X152.024 Y126.735 E.01248
G1 X124.362 Y154.397 E1.20954
G2 X124.859 Y154.437 I.818 J-7.084 E.01541
G1 X152.39 Y126.905 E1.20383
G1 X152.756 Y127.076 E.01248
G1 X125.36 Y154.472 E1.1979
G1 X125.862 Y154.507 E.01554
G1 X153.122 Y127.247 E1.19197
G1 X153.488 Y127.417 E.01248
G1 X126.375 Y154.53 E1.18554
G2 X126.897 Y154.545 I.548 J-9.956 E.01613
G1 X153.854 Y127.588 E1.17873
G1 X154.22 Y127.759 E.01248
G1 X127.424 Y154.555 E1.17167
G1 X127.951 Y154.564 E.01631
G1 X154.586 Y127.929 E1.16461
G1 X154.952 Y128.1 E.01248
G1 X128.492 Y154.56 E1.15699
G2 X129.042 Y154.547 I.017 J-10.71 E.01701
G1 X155.318 Y128.271 E1.14895
G1 X155.684 Y128.441 E.01248
G1 X129.598 Y154.527 E1.14063
G2 X130.156 Y154.506 I-.033 J-8.047 E.01728
G1 X156.05 Y128.612 E1.13222
G1 X156.416 Y128.782 E.01248
G1 X130.733 Y154.465 E1.123
G1 X131.31 Y154.425 E.01788
G1 X156.782 Y128.953 E1.11377
G1 X157.148 Y129.124 E.01248
G1 X131.902 Y154.369 E1.10387
G1 X132.502 Y154.306 E.01864
G1 X157.514 Y129.294 E1.09365
G1 X157.879 Y129.465 E.01248
G1 X133.11 Y154.234 E1.08304
G1 X133.735 Y154.146 E.01949
G1 X158.245 Y129.636 E1.07174
G1 X158.611 Y129.806 E.01248
G1 X134.363 Y154.054 E1.06027
G1 X135.015 Y153.94 E.02045
G1 X158.977 Y129.977 E1.04778
G1 X159.343 Y130.148 E.01248
G1 X135.667 Y153.824 E1.03525
G1 X136.349 Y153.679 E.02154
G1 X159.709 Y130.318 E1.02146
G1 X160.075 Y130.489 E.01248
G1 X137.031 Y153.533 E1.00763
G1 X137.746 Y153.355 E.02278
G1 X160.441 Y130.66 E.99237
G1 X160.807 Y130.83 E.01248
G1 X138.465 Y153.172 E.97691
G1 X139.218 Y152.956 E.0242
G1 X161.173 Y131.001 E.96002
G1 X161.539 Y131.171 E.01248
G1 X139.984 Y152.726 E.94249
G1 X140.779 Y152.468 E.02584
G1 X161.905 Y131.342 E.92373
G1 X162.271 Y131.513 E.01248
G1 X141.607 Y152.177 E.90356
G2 X142.457 Y151.864 I-4.056 J-12.313 E.02801
G1 X162.637 Y131.683 E.8824
G1 X163.003 Y131.854 E.01248
G1 X143.357 Y151.5 E.85903
G2 X144.302 Y151.091 I-5.374 J-13.73 E.03184
G1 X163.369 Y132.025 E.8337
G1 X163.735 Y132.195 E.01248
G1 X145.297 Y150.633 E.80619
G2 X146.359 Y150.107 I-6.992 J-15.468 E.03665
G1 X163.6 Y132.866 E.75387
G3 X162.978 Y134.025 I-16.625 J-8.18 E.04067
G1 X147.514 Y149.489 E.67618
G2 X148.797 Y148.743 I-13.638 J-24.916 E.0459
G1 X162.23 Y135.31 E.58734
G3 X161.294 Y136.783 I-21.531 J-12.651 E.05395
G1 X150.283 Y147.794 E.48147
G2 X152.161 Y146.452 I-26.73 J-39.406 E.07137
G1 X159.952 Y138.661 E.34069
G3 X156.844 Y142.306 I-31.012 J-23.298 E.1482
G1 X153.684 Y145.465 E.13816
G1 X108.965 Y149.94 F36000
G1 F15000
G1 X141.865 Y117.04 E1.43857
G1 X141.865 Y116.504 E.01659
G1 X108.74 Y149.628 E1.4484
G3 X108.395 Y149.437 I2.573 J-5.036 E.0122
G1 X141.865 Y115.967 E1.46348
G1 X141.865 Y115.43 E.01659
G1 X108.055 Y149.24 E1.47836
G1 X107.715 Y149.044 E.01215
G1 X141.865 Y114.894 E1.49323
G1 X141.865 Y114.357 E.01659
G1 X107.375 Y148.847 E1.50811
G3 X107.044 Y148.641 I2.728 J-4.743 E.01205
G1 X141.865 Y113.821 E1.52256
G1 X141.865 Y113.284 E.01659
G1 X106.714 Y148.435 E1.537
G1 X106.384 Y148.229 E.01204
G1 X141.865 Y112.748 E1.55144
G1 X141.865 Y112.211 E.01659
G1 X106.057 Y148.019 E1.56572
G1 X105.737 Y147.802 E.01195
G1 X141.865 Y111.674 E1.57973
G1 X141.865 Y111.138 E.01659
G1 X105.416 Y147.586 E1.59374
G1 X105.096 Y147.37 E.01195
G1 X141.865 Y110.601 E1.60775
G1 X141.865 Y110.435 E.00513
G1 X141.494 Y110.435 E.01146
G1 X133.885 Y118.044 E.33269
G1 X133.885 Y117.507 E.01659
G1 X140.957 Y110.435 E.30923
G1 X140.451 Y110.435 E.01566
G1 X140.442 Y110.414 E.00071
G1 X133.885 Y116.971 E.2867
G1 X133.885 Y116.434 E.01659
G1 X140.285 Y110.034 E.27984
G1 X140.129 Y109.654 E.01271
G1 X133.885 Y115.897 E.27299
G1 X133.885 Y115.361 E.01659
G1 X139.972 Y109.274 E.26614
G2 X139.802 Y108.907 I-3.713 J1.495 E.0125
G1 X133.885 Y114.824 E.25872
G1 X133.885 Y114.288 E.01659
G1 X139.627 Y108.546 E.25104
G1 X139.439 Y108.197 E.01225
G1 X133.885 Y113.751 E.24285
G1 X133.885 Y113.215 E.01659
G1 X139.244 Y107.856 E.23433
G1 X139.042 Y107.521 E.01208
G1 X133.885 Y112.678 E.22548
G1 X133.885 Y112.141 E.01659
G1 X138.828 Y107.198 E.21614
G2 X138.61 Y106.88 I-3.232 J1.979 E.01194
G1 X133.885 Y111.605 E.2066
G1 X133.885 Y111.068 E.01659
G1 X138.38 Y106.574 E.19652
G2 X138.145 Y106.272 I-3.03 J2.122 E.01183
G1 X133.885 Y110.532 E.18624
G1 X133.651 Y110.229 E.01182
G1 X137.9 Y105.98 E.18579
G2 X137.647 Y105.696 I-2.909 J2.334 E.01176
G1 X133.413 Y109.931 E.18516
G2 X133.158 Y109.649 I-1.954 J1.509 E.01176
G1 X137.389 Y105.418 E.185
G2 X137.12 Y105.151 I-2.789 J2.545 E.01174
G1 X132.892 Y109.379 E.18486
G1 X132.612 Y109.122 E.01174
G1 X136.846 Y104.888 E.18514
G1 X136.561 Y104.637 E.01176
G1 X132.312 Y108.885 E.18576
G2 X132.002 Y108.658 I-1.692 J1.99 E.01188
G1 X136.27 Y104.39 E.18661
G1 X135.971 Y104.153 E.01181
G1 X131.679 Y108.445 E.18766
G1 X131.335 Y108.252 E.01219
G1 X135.664 Y103.924 E.18925
G1 X135.35 Y103.701 E.0119
G1 X130.976 Y108.075 E.19127
G2 X130.601 Y107.913 I-1.235 J2.342 E.01263
G1 X135.024 Y103.49 E.1934
G2 X134.695 Y103.283 I-2.186 J3.121 E.01204
G1 X130.21 Y107.768 E.19609
G1 X129.793 Y107.648 E.01341
G1 X134.353 Y103.088 E.19937
G2 X134.004 Y102.901 I-1.986 J3.28 E.01226
G1 X129.355 Y107.55 E.20327
G2 X128.892 Y107.476 I-.71 J2.954 E.0145
G1 X133.647 Y102.721 E.20789
G2 X133.278 Y102.554 I-1.828 J3.531 E.01253
G1 X128.4 Y107.431 E.21326
G2 X127.875 Y107.42 I-.338 J3.556 E.01627
G1 X132.903 Y102.392 E.21984
G1 X132.514 Y102.244 E.01285
G1 X127.305 Y107.453 E.22778
G2 X126.678 Y107.544 I.271 J4.097 E.01961
G1 X132.116 Y102.105 E.2378
G1 X131.711 Y101.974 E.01317
G1 X125.97 Y107.715 E.25101
M73 P42 R13
G2 X125.115 Y108.034 I2.264 J7.377 E.02826
G1 X131.288 Y101.86 E.26993
G2 X130.856 Y101.755 I-1.248 J4.186 E.01374
G1 X115.255 Y117.357 E.68219
G2 X115.36 Y117.788 I4.272 J-.817 E.01373
G1 X121.526 Y111.622 E.26961
G2 X121.215 Y112.469 I5.328 J2.435 E.02794
G1 X115.475 Y118.21 E.25101
G1 X115.605 Y118.617 E.0132
G1 X121.039 Y113.183 E.23762
G2 X120.952 Y113.806 I3.996 J.877 E.0195
G1 X115.744 Y119.014 E.2277
G2 X115.891 Y119.403 I3.965 J-1.274 E.01288
G1 X120.919 Y114.376 E.21985
G2 X120.929 Y114.902 I3.409 J.199 E.0163
G1 X116.054 Y119.778 E.21318
G1 X116.216 Y120.152 E.01261
G1 X120.973 Y115.395 E.20801
G1 X121.047 Y115.858 E.01449
G1 X116.379 Y120.526 E.20412
G1 X116.532 Y120.879 E.01192
G1 X115.582 Y121.323 E.03243
G1 X97.013 Y139.891 E.81193
G1 X97.258 Y140.183 E.01178
G1 X121.148 Y116.293 E1.0446
G2 X121.271 Y116.706 I2.738 J-.594 E.01334
G1 X97.503 Y140.475 E1.0393
G1 X97.748 Y140.767 E.01178
G1 X121.414 Y117.101 E1.03482
G2 X121.573 Y117.478 I2.519 J-.839 E.01268
G1 X98.001 Y141.05 E1.03068
G1 X98.256 Y141.332 E.01175
G1 X121.751 Y117.836 E1.02737
G2 X121.948 Y118.176 I2.301 J-1.105 E.01215
G1 X98.51 Y141.614 E1.02486
G2 X98.766 Y141.894 I4.13 J-3.529 E.01174
G1 X122.158 Y118.503 E1.02281
G1 X122.381 Y118.817 E.0119
G1 X99.03 Y142.167 E1.02102
G1 X99.294 Y142.44 E.01173
G1 X122.624 Y119.11 E1.02014
G2 X122.88 Y119.391 I1.948 J-1.511 E.01176
G1 X99.557 Y142.713 E1.01978
G2 X99.826 Y142.981 I3.964 J-3.716 E.01173
G1 X123.146 Y119.661 E1.01969
G1 X123.432 Y119.912 E.01175
G1 X100.099 Y143.244 E1.02023
G1 X100.372 Y143.508 E.01173
G1 X123.731 Y120.149 E1.02138
G2 X124.043 Y120.374 I1.612 J-1.903 E.01189
G1 X100.645 Y143.772 E1.02307
G2 X100.927 Y144.027 I3.788 J-3.891 E.01175
G1 X124.37 Y120.583 E1.02509
G2 X124.716 Y120.774 I1.405 J-2.147 E.01223
G1 X101.209 Y144.281 E1.02788
G1 X101.491 Y144.535 E.01175
G1 X125.077 Y120.95 E1.0313
G2 X125.453 Y121.11 I1.18 J-2.243 E.01266
G1 X101.776 Y144.788 E1.03531
G1 X102.067 Y145.033 E.01178
G1 X125.851 Y121.248 E1.03998
G2 X126.27 Y121.367 I1.012 J-2.779 E.01345
G1 X102.359 Y145.277 E1.04551
G1 X102.651 Y145.522 E.01178
G1 X126.711 Y121.462 E1.05203
G2 X127.177 Y121.533 I.691 J-2.98 E.01458
G1 X102.948 Y145.762 E1.05942
G1 X103.249 Y145.997 E.01182
G1 X127.672 Y121.574 E1.06791
G2 X128.204 Y121.579 I.298 J-3.44 E.01646
G1 X103.55 Y146.233 E1.07799
G1 X103.851 Y146.468 E.01182
G1 X128.781 Y121.538 E1.09007
G2 X129.419 Y121.437 I-.336 J-4.178 E.01999
G1 X104.161 Y146.695 E1.10442
G1 X104.472 Y146.921 E.01188
G1 X130.14 Y121.252 E1.12238
G2 X131.029 Y120.901 I-2.484 J-7.572 E.02955
G1 X104.661 Y147.268 E1.15294
G1 X96.651 Y139.717 F36000
G1 F15000
G1 X114.576 Y121.792 E.78379
G1 X113.571 Y122.26 E.0343
G1 X96.537 Y139.295 E.74483
G1 X96.301 Y138.993 E.01182
G1 X112.566 Y122.729 E.71116
G1 X111.56 Y123.198 E.0343
G1 X96.066 Y138.692 E.67749
G3 X95.838 Y138.384 I4.304 J-3.428 E.01186
G1 X110.555 Y123.667 E.64351
G1 X109.549 Y124.136 E.0343
G1 X95.612 Y138.073 E.60942
G1 X95.386 Y137.762 E.01188
G1 X108.544 Y124.605 E.57533
G1 X107.538 Y125.073 E.0343
G1 X95.161 Y137.451 E.5412
G1 X94.945 Y137.13 E.01195
G1 X106.533 Y125.542 E.50669
G1 X105.527 Y126.011 E.0343
G1 X94.729 Y136.81 E.47218
G1 X94.513 Y136.489 E.01195
G1 X104.522 Y126.48 E.43766
G1 X103.517 Y126.949 E.0343
G1 X94.301 Y136.164 E.40295
G1 X94.095 Y135.834 E.01204
G1 X102.511 Y127.418 E.36801
G1 X101.506 Y127.887 E.0343
G1 X93.888 Y135.504 E.33307
G1 X93.682 Y135.173 E.01204
G1 X100.5 Y128.355 E.29813
G1 X99.495 Y128.824 E.0343
G1 X93.485 Y134.834 E.2628
G1 X93.288 Y134.494 E.01215
G1 X98.489 Y129.293 E.22743
G1 X97.484 Y129.762 E.0343
G1 X93.092 Y134.154 E.19205
G3 X92.899 Y133.811 I4.819 J-2.936 E.01219
G1 X96.478 Y130.231 E.15653
G1 X95.473 Y130.7 E.0343
G1 X92.712 Y133.46 E.12071
G1 X92.526 Y133.11 E.01227
G1 X94.468 Y131.168 E.0849
G1 X93.462 Y131.637 E.0343
G1 X92.34 Y132.76 E.04908
G3 X92.16 Y132.403 I6.723 J-3.621 E.01235
G1 X92.808 Y131.755 E.02833
; WIPE_START
G1 X92.16 Y132.403 E-.34816
G1 X92.34 Y132.76 E-.15177
G1 X92.824 Y132.276 E-.26008
; WIPE_END
G1 E-.03999 F1800
G1 X99.118 Y127.959 Z.8 F36000
G1 X115.019 Y117.057 Z.8
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X130.414 Y101.661 E.67319
G1 X129.953 Y101.586 E.01446
G1 X115.086 Y116.452 E.65003
G3 X115.023 Y115.979 I4.608 J-.854 E.01478
G1 X129.478 Y101.524 E.63205
G2 X128.99 Y101.476 I-.708 J4.686 E.01518
G1 X114.974 Y115.491 E.61283
G1 X114.947 Y114.982 E.01576
G1 X128.483 Y101.446 E.59186
G2 X127.953 Y101.439 I-.335 J5.209 E.01638
G1 X114.94 Y114.452 E.56901
G3 X114.954 Y113.902 I5.286 J-.145 E.01702
G1 X127.402 Y101.454 E.54432
G2 X126.826 Y101.493 I.094 J5.65 E.01785
G1 X114.992 Y113.327 E.51746
G3 X115.06 Y112.722 I5.959 J.365 E.01882
G1 X126.221 Y101.561 E.48803
G2 X125.581 Y101.665 I.699 J6.323 E.02008
G1 X115.164 Y112.082 E.45546
G3 X115.314 Y111.395 I6.929 J1.151 E.02172
G1 X124.895 Y101.814 E.41895
G2 X124.153 Y102.02 I1.611 J7.253 E.02383
G1 X115.519 Y110.654 E.37752
G3 X115.8 Y109.836 I8.158 J2.349 E.02676
G1 X123.337 Y102.299 E.32955
G2 X122.397 Y102.702 I5.316 J13.683 E.03164
G1 X116.201 Y108.899 E.27094
G3 X116.826 Y107.737 I13.13 J6.316 E.0408
G1 X121.234 Y103.329 E.19275
G2 X118.821 Y105.205 I6.904 J11.368 E.09472
G1 X117.274 Y106.752 E.06764
; CHANGE_LAYER
; Z_HEIGHT: 0.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X118.688 Y105.338 E-.76
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
G1 X133.505 Y118.42
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02099
G3 X122.314 Y110.861 I-5.109 J-4.414 E.67149
G3 X128.007 Y107.75 I5.678 J3.624 E.22453
G3 X133.552 Y110.639 I-.039 J6.841 E.21542
G1 X133.552 Y118.361 E.25612
G1 X133.542 Y118.373 E.00052
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X128.018 Y108.141 I-5.156 J-3.723 E.79903
G3 X133.16 Y110.777 I-.043 J6.418 E.18416
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X139.352 Y120.641 Z1 F36000
G1 X139.909 Y120.717 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89477
G3 X91.645 Y132.117 I-36.355 J-17.631 E3.00028
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.1 J-7.692 E.08797
G3 X128.42 Y101.109 I12.872 J-3.739 E.83778
G3 X140.249 Y109.073 I-.422 J13.394 E.49878
G1 X140.674 Y110.102 E.03694
G1 X142.198 Y110.102 E.05055
G1 X142.198 Y118.898 E.29178
G1 X140.668 Y118.898 E.05076
G3 X139.914 Y120.67 I-23.567 J-8.968 E.0639
G1 X140.412 Y120.519 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.8295
G3 X91.122 Y131.928 I-36.878 J-17.438 E2.83054
G1 X115.586 Y120.52 E.82941
G3 X128.433 Y100.717 I12.424 J-6.009 E.87013
G3 X140.936 Y109.71 I-.451 J13.817 E.50195
G1 X142.59 Y109.71 E.05081
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05088
G3 X140.437 Y120.465 I-17.624 J-6.763 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.314 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.873 Y117.116 Z1 F36000
G1 X133.716 Y115.696 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42238
G1 F15000
G1 X158.497 Y140.477 E1.08366
G1 X158.247 Y140.764 E.01176
G1 X133.885 Y116.402 E1.06533
G1 X133.885 Y116.938 E.01659
G1 X157.998 Y141.051 E1.05441
G3 X157.747 Y141.337 I-4.241 J-3.46 E.01176
G1 X133.885 Y117.475 E1.04346
G1 X133.885 Y118.012 E.01659
G1 X157.488 Y141.615 E1.03214
G1 X157.229 Y141.892 E.01174
G1 X133.854 Y118.517 E1.02219
G1 X133.616 Y118.815 E.01181
G1 X156.97 Y142.17 E1.02129
G3 X156.707 Y142.444 I-4.049 J-3.624 E.01174
G1 X133.377 Y119.114 E1.02021
G3 X133.119 Y119.392 I-1.936 J-1.531 E.01175
M73 P43 R13
G1 X156.439 Y142.712 E1.01975
G1 X156.171 Y142.98 E.01173
G1 X132.85 Y119.66 E1.0198
G3 X132.569 Y119.915 I-1.791 J-1.688 E.01176
G1 X155.903 Y143.249 E1.02036
G3 X155.627 Y143.51 I-3.882 J-3.811 E.01174
G1 X132.268 Y120.151 E1.02147
G3 X131.954 Y120.374 I-1.596 J-1.919 E.01191
G1 X155.35 Y143.769 E1.02306
G1 X155.072 Y144.028 E.01174
G1 X131.628 Y120.584 E1.0252
G1 X131.284 Y120.777 E.01219
G1 X154.794 Y144.287 E1.02807
G1 X154.509 Y144.539 E.01176
G1 X130.921 Y120.95 E1.03149
G3 X130.543 Y121.109 I-1.214 J-2.368 E.01269
G1 X154.223 Y144.789 E1.03551
G1 X153.931 Y145.034 E.01178
G1 X130.147 Y121.25 E1.04004
G1 X129.731 Y121.37 E.01341
G1 X153.639 Y145.279 E1.04551
G1 X153.348 Y145.524 E.01178
G1 X129.288 Y121.464 E1.0521
G3 X128.821 Y121.533 I-.682 J-2.989 E.01462
G1 X153.051 Y145.763 E1.05955
G1 X152.749 Y145.999 E.01182
G1 X128.324 Y121.573 E1.0681
G3 X127.792 Y121.578 I-.294 J-3.445 E.01648
G1 X152.448 Y146.234 E1.0782
G1 X152.147 Y146.469 E.01182
G1 X127.215 Y121.537 E1.09026
G3 X126.579 Y121.438 I.323 J-4.161 E.01992
G1 X151.837 Y146.696 E1.10452
G1 X151.526 Y146.922 E.01188
G1 X125.856 Y121.252 E1.12256
G3 X124.971 Y120.903 I1.811 J-5.898 E.02944
G1 X151.216 Y147.148 E1.14767
G3 X150.902 Y147.371 I-3.36 J-4.377 E.0119
G1 X115.24 Y111.709 E1.55948
G3 X115.345 Y111.277 I4.422 J.839 E.01376
G1 X121.602 Y117.534 E.27363
G3 X121.253 Y116.649 I6.504 J-3.072 E.02944
G1 X115.457 Y110.853 E.25348
G1 X115.585 Y110.444 E.01324
G1 X121.06 Y115.919 E.23942
G1 X120.958 Y115.281 E.01997
G1 X115.723 Y110.045 E.22895
G1 X115.868 Y109.654 E.01291
G1 X120.919 Y114.705 E.22089
G3 X120.923 Y114.173 I3.447 J-.239 E.01648
G1 X116.029 Y109.278 E.21403
G3 X116.196 Y108.909 I3.722 J1.458 E.01255
G1 X120.962 Y113.675 E.20844
G1 X121.035 Y113.211 E.01453
G1 X116.373 Y108.549 E.20387
G3 X116.561 Y108.2 I3.597 J1.716 E.01225
G1 X121.134 Y112.773 E.19997
G3 X121.252 Y112.355 I2.509 J.485 E.01345
G1 X116.752 Y107.855 E.19678
G1 X116.959 Y107.525 E.01204
G1 X121.391 Y111.957 E.19381
G3 X121.546 Y111.575 I2.574 J.828 E.01274
G1 X117.169 Y107.199 E.19139
G1 X117.39 Y106.883 E.01192
G1 X121.725 Y111.217 E.18955
G3 X121.918 Y110.874 I2.32 J1.081 E.01219
G1 X117.619 Y106.575 E.188
G1 X117.853 Y106.273 E.01183
G1 X122.127 Y110.547 E.18689
G1 X122.348 Y110.231 E.01192
G1 X118.1 Y105.982 E.18577
G3 X118.35 Y105.696 I3.001 J2.375 E.01176
G1 X122.588 Y109.934 E.18532
G3 X122.84 Y109.65 I1.964 J1.487 E.01177
G1 X118.612 Y105.421 E.1849
G3 X118.878 Y105.151 I2.693 J2.389 E.01174
G1 X123.105 Y109.378 E.18482
G3 X123.389 Y109.125 I1.757 J1.696 E.01177
G1 X119.154 Y104.89 E.1852
G3 X119.438 Y104.638 I2.619 J2.655 E.01176
G1 X123.685 Y108.885 E.18574
G3 X123.994 Y108.657 I1.634 J1.885 E.01188
G1 X119.727 Y104.391 E.18657
G3 X120.029 Y104.155 I2.455 J2.827 E.01183
G1 X124.321 Y108.448 E.18772
G3 X124.664 Y108.254 I1.423 J2.12 E.01219
G1 X120.333 Y103.923 E.1894
G1 X120.65 Y103.704 E.01193
G1 X125.021 Y108.075 E.19114
G1 X125.394 Y107.911 E.01259
G1 X120.974 Y103.49 E.1933
G1 X121.305 Y103.285 E.01205
G1 X125.791 Y107.771 E.19617
G3 X126.207 Y107.65 I.992 J2.63 E.0134
G1 X121.646 Y103.089 E.19943
G1 X121.993 Y102.899 E.01222
G1 X126.643 Y107.55 E.20338
G3 X127.105 Y107.475 I.719 J2.945 E.01446
G1 X122.354 Y102.724 E.20776
G3 X122.72 Y102.553 I1.854 J3.506 E.0125
G1 X127.595 Y107.428 E.21317
G3 X128.124 Y107.421 I.316 J3.818 E.01639
G1 X123.097 Y102.394 E.21984
G3 X123.485 Y102.245 I1.667 J3.772 E.01285
G1 X128.69 Y107.45 E.22762
G3 X129.319 Y107.542 I-.282 J4.114 E.01967
G1 X123.881 Y102.104 E.23781
G1 X124.291 Y101.977 E.01327
G1 X130.029 Y107.716 E.25093
G3 X130.881 Y108.031 I-2.135 J7.08 E.0281
G1 X124.71 Y101.861 E.26982
G3 X125.14 Y101.753 I1.275 J4.173 E.01368
G1 X141.865 Y118.478 E.73138
G1 X141.865 Y117.942 E.01659
G1 X125.587 Y101.664 E.7118
G3 X126.047 Y101.587 I.987 J4.459 E.01441
G1 X141.865 Y117.405 E.69172
G1 X141.865 Y116.868 E.01659
G1 X126.518 Y101.522 E.67109
G1 X127.009 Y101.476 E.01523
G1 X141.865 Y116.332 E.64965
G1 X141.865 Y115.795 E.01659
G1 X127.518 Y101.449 E.62735
G3 X128.046 Y101.44 I.352 J5.242 E.01633
G1 X141.865 Y115.258 E.60428
G1 X141.865 Y114.722 E.01659
G1 X128.596 Y101.453 E.58022
G3 X129.169 Y101.49 I-.063 J5.489 E.01777
G1 X141.865 Y114.185 E.55516
G1 X141.865 Y113.648 E.01659
G1 X129.773 Y101.557 E.52876
G1 X130.414 Y101.661 E.02007
G1 X141.865 Y113.112 E.50074
G1 X141.865 Y112.575 E.01659
G1 X131.1 Y101.81 E.47074
G3 X131.843 Y102.017 I-1.602 J7.214 E.02385
G1 X142.034 Y112.208 E.44567
G1 X141.165 Y110.266 F36000
G1 F15000
G1 X141.865 Y110.965 E.03059
G1 X141.865 Y111.502 E.01659
G1 X140.798 Y110.435 E.04664
G1 X140.451 Y110.435 E.01073
G1 X140.207 Y109.844 E.01977
G1 X132.664 Y102.301 E.32985
G3 X133.595 Y102.696 I-5.809 J15.005 E.03128
G1 X139.798 Y108.899 E.27125
G2 X139.172 Y107.736 I-12.213 J5.829 E.04087
G1 X134.752 Y103.316 E.19325
G3 X136.883 Y104.92 I-7.249 J11.844 E.08258
G3 X138.731 Y106.758 I-68.317 J70.549 E.08059
G1 X133.716 Y110.866 F36000
G1 F15000
G1 X141.415 Y118.565 E.33667
G1 X140.878 Y118.565 E.01659
G1 X133.885 Y111.572 E.30578
G1 X133.885 Y112.109 E.01659
G1 X140.414 Y118.637 E.28548
G1 X140.259 Y119.019 E.01275
G1 X133.885 Y112.645 E.27872
G1 X133.885 Y113.182 E.01659
G1 X140.105 Y119.401 E.27197
G3 X139.948 Y119.782 I-4.899 J-1.789 E.01272
G1 X133.885 Y113.719 E.26514
G1 X133.885 Y114.255 E.01659
G1 X139.782 Y120.152 E.25785
G1 X139.615 Y120.522 E.01255
G1 X133.885 Y114.792 E.25056
G1 X133.885 Y115.329 E.01659
G1 X158.744 Y140.188 E1.08706
G1 X158.984 Y139.891 E.0118
G1 X140.414 Y121.321 E.81205
G1 X141.42 Y121.79 E.03431
G1 X159.225 Y139.594 E.77858
G1 X159.465 Y139.298 E.0118
G1 X142.425 Y122.259 E.74511
G1 X143.431 Y122.728 E.03431
G1 X159.699 Y138.996 E.71141
G1 X159.93 Y138.69 E.01185
G1 X144.436 Y123.196 E.67751
G1 X145.442 Y123.665 E.03431
G1 X160.16 Y138.384 E.64361
G1 X160.39 Y138.077 E.01185
G1 X146.447 Y124.134 E.60972
G1 X147.453 Y124.603 E.03431
G1 X160.613 Y137.764 E.5755
G1 X160.834 Y137.448 E.01192
G1 X148.458 Y125.072 E.54119
G1 X149.464 Y125.541 E.03431
G1 X161.055 Y137.132 E.50688
G2 X161.274 Y136.814 I-4.492 J-3.313 E.01194
G1 X150.47 Y126.01 E.47245
G1 X151.475 Y126.479 E.03431
G1 X161.485 Y136.488 E.43772
G1 X161.696 Y136.163 E.012
G1 X152.481 Y126.947 E.40299
G1 X153.486 Y127.416 E.03431
G1 X161.907 Y135.838 E.36826
G2 X162.112 Y135.506 I-4.634 J-3.086 E.01206
G1 X154.492 Y127.885 E.33324
G1 X155.497 Y128.354 E.03431
G1 X162.314 Y135.171 E.29808
G1 X162.515 Y134.835 E.01209
G1 X156.503 Y128.823 E.26291
G1 X157.508 Y129.292 E.03431
G1 X162.715 Y134.499 E.22771
G1 X162.907 Y134.154 E.01221
G1 X158.514 Y129.761 E.19211
G1 X159.519 Y130.23 E.03431
G1 X163.098 Y133.809 E.15651
G1 X163.29 Y133.463 E.01221
G1 X160.525 Y130.699 E.1209
G1 X161.53 Y131.167 E.03431
G1 X163.475 Y133.112 E.08505
G1 X163.656 Y132.757 E.01234
G1 X162.536 Y131.636 E.04899
G1 X163.541 Y132.105 E.03431
G1 X163.963 Y132.527 E.01845
G1 X150.704 Y147.71 F36000
G1 F15000
G1 X115.149 Y112.155 E1.55479
G2 X115.076 Y112.618 I4.525 J.953 E.01451
G1 X150.261 Y147.804 E1.53863
G1 X149.941 Y148.02 E.01195
G1 X115.015 Y113.094 E1.52727
G2 X114.969 Y113.584 I4.778 J.699 E.01523
G1 X149.614 Y148.23 E1.51502
G1 X149.284 Y148.436 E.01204
G1 X114.944 Y114.096 E1.50166
G2 X114.941 Y114.63 I5.036 J.296 E.0165
G1 X148.954 Y148.643 E1.48735
G3 X148.623 Y148.849 I-3.144 J-4.677 E.01205
G1 X114.958 Y115.183 E1.47216
G2 X115.001 Y115.763 I5.711 J-.132 E.01798
G1 X148.283 Y149.045 E1.45541
G1 X147.943 Y149.242 E.01215
G1 X115.074 Y116.373 E1.43733
G2 X115.184 Y117.02 I6.395 J-.757 E.0203
G1 X147.603 Y149.438 E1.41763
G3 X147.258 Y149.63 I-2.921 J-4.853 E.01221
G1 X115.341 Y117.713 E1.3957
G2 X115.556 Y118.465 I7.492 J-1.741 E.02421
G1 X146.907 Y149.816 E1.37095
G1 X146.557 Y150.002 E.01227
G1 X115.85 Y119.296 E1.34276
G2 X116.253 Y120.235 I9.411 J-3.476 E.03159
M73 P43 R12
G1 X146.207 Y150.189 E1.30986
G3 X145.846 Y150.365 I-2.698 J-5.051 E.0124
G1 X116.415 Y120.934 E1.28699
G1 X116.049 Y121.105 E.01249
M73 P44 R12
G1 X145.486 Y150.541 E1.28722
G1 X145.125 Y150.717 E.01241
G1 X115.683 Y121.275 E1.28745
G1 X115.317 Y121.446 E.01249
G1 X144.759 Y150.888 E1.28746
G1 X144.388 Y151.053 E.01257
G1 X114.951 Y121.617 E1.28723
G1 X114.585 Y121.787 E.01249
G1 X144.017 Y151.218 E1.287
G3 X143.645 Y151.383 I-2.614 J-5.383 E.01257
G1 X114.22 Y121.958 E1.28675
G1 X113.854 Y122.129 E.01249
G1 X143.263 Y151.538 E1.28604
G1 X142.881 Y151.692 E.01275
G1 X113.488 Y122.299 E1.28533
G1 X113.122 Y122.47 E.01249
G1 X142.498 Y151.847 E1.28462
G3 X142.109 Y151.994 I-2.304 J-5.502 E.01287
G1 X112.756 Y122.641 E1.2836
G1 X112.39 Y122.811 E.01249
G1 X141.716 Y152.137 E1.2824
G1 X141.322 Y152.28 E.01295
G1 X112.024 Y122.982 E1.2812
G1 X111.658 Y123.153 E.01249
G1 X140.925 Y152.42 E1.27985
G1 X140.52 Y152.552 E.01317
G1 X111.292 Y123.323 E1.27814
G1 X110.926 Y123.494 E.01249
G1 X140.115 Y152.684 E1.27644
G1 X139.71 Y152.815 E.01317
G1 X110.56 Y123.665 E1.27472
G1 X110.194 Y123.835 E.01249
G1 X139.293 Y152.935 E1.27249
G1 X138.876 Y153.054 E.01342
G1 X109.828 Y124.006 E1.27026
G1 X109.462 Y124.177 E.01249
G1 X138.459 Y153.174 E1.26802
G3 X138.032 Y153.284 I-1.781 J-6.041 E.01363
G1 X109.096 Y124.347 E1.26536
G1 X108.73 Y124.518 E.01249
G1 X137.603 Y153.391 E1.26258
G1 X137.173 Y153.498 E.01369
G1 X108.364 Y124.689 E1.2598
G1 X107.998 Y124.859 E.01249
G1 X136.735 Y153.597 E1.25667
G1 X136.293 Y153.691 E.01399
G1 X107.632 Y125.03 E1.25332
G1 X107.266 Y125.2 E.01249
G1 X135.85 Y153.785 E1.24997
G3 X135.4 Y153.872 I-1.465 J-6.387 E.01417
G1 X106.9 Y125.371 E1.2463
G1 X106.534 Y125.542 E.01249
G1 X134.944 Y153.952 E1.24236
G1 X134.488 Y154.032 E.01432
G1 X106.168 Y125.712 E1.23841
G1 X105.802 Y125.883 E.01249
G1 X134.024 Y154.106 E1.23414
G1 X133.554 Y154.172 E.01469
G1 X105.436 Y126.054 E1.22957
G1 X105.07 Y126.224 E.01249
G1 X133.083 Y154.238 E1.225
G3 X132.604 Y154.295 I-1.061 J-6.825 E.01493
G1 X104.704 Y126.395 E1.22005
G1 X104.338 Y126.566 E.01249
G1 X132.119 Y154.346 E1.21482
G1 X131.633 Y154.397 E.0151
G1 X103.972 Y126.736 E1.20959
G1 X103.606 Y126.907 E.01249
G1 X131.136 Y154.437 E1.20386
G1 X130.635 Y154.472 E.01555
G1 X103.24 Y127.078 E1.19793
G1 X102.874 Y127.248 E.01249
G1 X130.133 Y154.507 E1.192
G3 X129.616 Y154.527 I-.539 J-7.438 E.01601
G1 X102.508 Y127.419 E1.18539
G1 X102.142 Y127.59 E.01249
G1 X129.097 Y154.545 E1.17873
G3 X128.575 Y154.559 I-.539 J-10.305 E.01617
G1 X101.776 Y127.76 E1.17188
G1 X101.41 Y127.931 E.01249
G1 X128.043 Y154.564 E1.16465
G3 X127.498 Y154.556 I-.121 J-9.911 E.01686
G1 X101.044 Y128.102 E1.15682
G1 X100.678 Y128.272 E.01249
G1 X126.952 Y154.546 E1.14894
G3 X126.401 Y154.531 I.008 J-10.544 E.01706
G1 X100.312 Y128.443 E1.14083
G1 X99.946 Y128.614 E.01249
G1 X125.838 Y154.505 E1.13221
G1 X125.261 Y154.465 E.01788
G1 X99.58 Y128.784 E1.12299
G1 X99.214 Y128.955 E.01249
G1 X124.684 Y154.424 E1.11376
G3 X124.091 Y154.368 I.507 J-8.52 E.01841
G1 X98.848 Y129.126 E1.10384
G1 X98.482 Y129.296 E.01249
G1 X123.491 Y154.305 E1.09362
G3 X122.882 Y154.233 I.731 J-8.759 E.01896
G1 X98.116 Y129.467 E1.083
G1 X97.75 Y129.638 E.01249
G1 X122.258 Y154.145 E1.0717
G3 X121.629 Y154.053 I1.005 J-9.059 E.01965
G1 X97.384 Y129.808 E1.06021
G1 X97.019 Y129.979 E.01249
G1 X120.978 Y153.938 E1.04772
G3 X120.325 Y153.822 I1.336 J-9.398 E.02051
G1 X96.653 Y130.15 E1.03518
G1 X96.287 Y130.32 E.01249
G1 X119.643 Y153.677 E1.02138
G3 X118.961 Y153.531 I1.733 J-9.77 E.02159
G1 X95.921 Y130.491 E1.00753
G1 X95.555 Y130.662 E.01249
G1 X118.246 Y153.353 E.99227
G3 X117.526 Y153.169 I2.268 J-10.408 E.02298
G1 X95.189 Y130.832 E.97679
G1 X94.823 Y131.003 E.01249
G1 X116.773 Y152.954 E.95989
G3 X116.006 Y152.723 I2.919 J-11.101 E.02478
G1 X94.457 Y131.174 E.94234
G1 X94.091 Y131.344 E.01249
G1 X115.211 Y152.465 E.92358
G3 X114.383 Y152.173 I3.761 J-12.008 E.02715
G1 X93.725 Y131.515 E.90337
G1 X93.359 Y131.686 E.01249
G1 X113.532 Y151.859 E.88218
G1 X112.632 Y151.495 E.03003
G1 X92.993 Y131.856 E.85881
G1 X92.627 Y132.027 E.01249
G1 X111.686 Y151.086 E.83344
G3 X110.69 Y150.626 I6.085 J-14.5 E.03393
G1 X92.261 Y132.198 E.80588
G1 X92.096 Y132.275 E.00564
G2 X92.4 Y132.874 I11.573 J-5.512 E.02079
G1 X109.626 Y150.1 E.75327
G3 X108.47 Y149.48 I8.296 J-16.868 E.04057
G1 X93.02 Y134.03 E.6756
G2 X93.774 Y135.321 I18.871 J-10.159 E.04623
G1 X107.179 Y148.726 E.58619
G3 X105.683 Y147.766 I12.983 J-21.891 E.05497
G1 X94.734 Y136.817 E.47881
G2 X96.044 Y138.664 I43.426 J-29.418 E.07001
G1 X103.836 Y146.456 E.34077
G3 X99.769 Y142.925 I23.645 J-31.346 E.16669
G1 X97.088 Y140.245 E.1172
; CHANGE_LAYER
; Z_HEIGHT: 0.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X98.503 Y141.659 E-.76
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
G1 X125.474 Y148.741
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X127.581 Y147.448 I2.528 J1.756 E.08439
G3 X128.415 Y147.448 I.421 J3.217 E.02777
G3 X125.44 Y148.791 I-.414 J3.05 E.52729
; WIPE_START
G1 X125.746 Y148.4 E-.18852
G1 X126.056 Y148.111 E-.16131
G1 X126.399 Y147.868 E-.1597
G1 X126.773 Y147.675 E-.15982
G1 X126.998 Y147.595 E-.09065
; WIPE_END
G1 E-.04 F1800
G1 X134.196 Y145.057 Z1.2 F36000
G1 X150.443 Y139.33 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G3 X153.036 Y136.904 I3.014 J.623 E.12555
G3 X153.871 Y136.903 I.421 J3.217 E.02777
M73 P45 R12
G3 X150.431 Y139.389 I-.414 J3.05 E.48612
; WIPE_START
G1 X150.553 Y138.924 E-.18239
G1 X150.721 Y138.539 E-.15972
G1 X150.939 Y138.179 E-.15982
G1 X151.205 Y137.853 E-.15972
G1 X151.394 Y137.677 E-.09835
; WIPE_END
G1 E-.04 F1800
G1 X146.199 Y132.085 Z1.2 F36000
G1 X133.505 Y118.42 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G1 X133.11 Y118.914 E.021
G3 X127.992 Y107.75 I-5.107 J-4.414 E.89521
G3 X133.552 Y110.639 I-.031 J6.855 E.21588
G1 X133.552 Y118.361 E.25612
G1 X133.542 Y118.373 E.00051
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X128.003 Y108.142 I-5.157 J-3.722 E.79867
G3 X133.16 Y110.777 I-.019 J6.401 E.18465
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X125.322 Y123.655 Z1.2 F36000
G1 X99.471 Y139.842 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.474 Y139.746 E.00319
G3 X102.125 Y136.904 I3.071 J.208 E.1395
G3 X102.96 Y136.903 I.421 J3.217 E.02777
G3 X99.475 Y140.166 I-.414 J3.05 E.46031
G1 X99.472 Y139.902 E.00876
; WIPE_START
G1 X99.474 Y139.746 E-.05928
G1 X99.526 Y139.349 E-.15205
G1 X99.64 Y138.928 E-.16579
G1 X99.809 Y138.539 E-.16121
G1 X100.017 Y138.197 E-.15219
G1 X100.132 Y138.054 E-.06947
; WIPE_END
G1 E-.04 F1800
G1 X107.128 Y135.005 Z1.2 F36000
G1 X139.909 Y120.717 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G1 X164.355 Y132.117 E.89477
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.246 I16.111 J-7.697 E.08797
G3 X128.413 Y101.109 I12.871 J-3.739 E.83754
G3 X140.247 Y109.069 I-.416 J13.397 E.49886
G1 X140.674 Y110.102 E.0371
G1 X142.198 Y110.102 E.05054
G1 X142.198 Y118.898 E.29178
G1 X140.668 Y118.898 E.05077
G3 X139.915 Y120.67 I-23.659 J-9.004 E.06389
G1 X140.412 Y120.519 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82949
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82941
G3 X128.425 Y100.717 I12.424 J-6.009 E.86991
G3 X140.937 Y109.71 I-.444 J13.817 E.50218
G1 X142.59 Y109.71 E.05081
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05088
G3 X140.437 Y120.465 I-17.658 J-6.776 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.314 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.03 Y114.011 Z1.2 F36000
G1 X137.446 Y105.502 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X136.252 Y104.396 I-18.264 J18.519 E.05398
G1 X132.006 Y108.642 E.19921
G2 X131.182 Y108.154 I-4.709 J7.002 E.03179
G1 X124.865 Y101.837 E.29633
G2 X122.732 Y102.564 I4.761 J17.459 E.0748
G1 X116.066 Y109.23 E.31272
G2 X115.502 Y110.757 I12.361 J5.43 E.05401
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21892
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X103.857 Y136.791 E.8578
G3 X104.432 Y142.811 I-1.319 J3.163 E.24571
G1 X113.416 Y151.796 E.42149
G2 X118.061 Y153.291 I14.862 J-38.206 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.83 J-23.24 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-1.997 J-14.614 E.03419
G1 X130.146 Y153.173 E.05778
G3 X125.854 Y153.173 I-2.146 J-2.817 E.15291
G1 X124.623 Y154.405 E.05778
G3 X123.598 Y154.301 I.973 J-14.727 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.65 I36.647 J-19.025 E.18545
G1 X108.182 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.584 Y151.796 I-10.218 J-39.702 E.16194
G1 X151.568 Y142.811 E.42149
G3 X152.143 Y136.791 I1.894 J-2.857 E.24571
G1 X133.871 Y118.519 E.85718
G3 X132.791 Y119.734 I-6.803 J-4.96 E.05401
; WIPE_START
G1 X133.374 Y119.142 E-.31572
G1 X133.871 Y118.519 E-.30284
G1 X134.134 Y118.782 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X126.57 Y119.802 Z1.2 F36000
G1 X115.749 Y121.261 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.677 Y151.353 E1.37939
G2 X148.751 Y148.751 I-16.574 J-38.577 E.1893
G1 X114.961 Y114.961 E1.58519
G2 X115.336 Y117.636 I13.399 J-.515 E.08977
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I10.925 J6.2 E.05391
G1 X118.555 Y105.503 F36000
G1 F15476.087
G3 X119.746 Y104.394 I9.749 J9.28 E.05401
G1 X123.992 Y108.64 E.19919
G3 X124.816 Y108.156 I3.54 J5.081 E.03174
G1 X131.136 Y101.836 E.29649
G3 X133.271 Y102.567 I-4.83 J17.587 E.07488
G1 X139.939 Y109.236 E.31285
G1 X140.441 Y110.45 E.0436
G1 X141.154 Y110.45 E.02364
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y114.15 E.09966
G1 X107.249 Y148.751 E1.62321
G2 X112.323 Y151.353 I21.653 J-35.983 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X139.437 Y120.882 E.08381
G2 X140.433 Y118.55 I-29.281 J-13.884 E.08414
G1 X141.578 Y118.55 E.03798
G1 X133.9 Y110.872 E.36015
G1 X133.9 Y114.424 E.1178
G1 X139.667 Y108.657 E.27054
; WIPE_START
G1 X138.253 Y110.071 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X141.575 Y116.942 Z1.2 F36000
G1 X154.05 Y142.744 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X156.252 Y140.542 E.09567
G1 X156.306 Y139.954
G1 X153.448 Y142.813 E.1242
G1 X152.963 Y142.765
G1 X156.265 Y139.462 E.14352
G1 X156.158 Y139.036
G1 X152.54 Y142.654 E.15724
G1 X152.164 Y142.497
G1 X156.001 Y138.66 E.16673
G1 X155.8 Y138.328
G1 X151.83 Y142.298 E.17249
G1 X151.534 Y142.061
G1 X155.564 Y138.03 E.17515
G1 X155.292 Y137.77
G1 X151.273 Y141.788 E.17461
G1 X151.047 Y141.481
G1 X154.983 Y137.545 E.17105
G1 X154.637 Y137.357
G1 X150.86 Y141.135 E.16414
G1 X150.717 Y140.745
G1 X154.249 Y137.212 E.15351
G1 X153.806 Y137.122
G1 X150.626 Y140.302 E.13818
G1 X150.605 Y139.79
G1 X153.285 Y137.11 E.11644
G1 X152.642 Y137.22
G1 X150.725 Y139.137 E.08331
M204 S10000
G1 X152.141 Y137.427 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.101073
G1 F15000
G1 X152.064 Y137.483 E.00045
; LINE_WIDTH: 0.126869
G1 X151.987 Y137.54 E.00065
; LINE_WIDTH: 0.156194
G1 X151.839 Y137.664 E.00178
; LINE_WIDTH: 0.202102
G2 X151.162 Y138.337 I3.859 J4.564 E.0124
; LINE_WIDTH: 0.156513
G1 X151.037 Y138.496 E.00187
; LINE_WIDTH: 0.110952
G1 X150.912 Y138.655 E.00112
; WIPE_START
G1 X151.037 Y138.496 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.129 Y140.958 Z1.2 F36000
G1 Z.8
G1 E.8 F1800
; LINE_WIDTH: 0.108071
G1 F15000
G1 X156.065 Y141.052 E.00061
; LINE_WIDTH: 0.147874
G1 X156.001 Y141.147 E.00098
; LINE_WIDTH: 0.187678
G1 X155.936 Y141.241 E.00135
; LINE_WIDTH: 0.229168
G1 X155.825 Y141.383 E.00275
; LINE_WIDTH: 0.272354
G1 X155.713 Y141.526 E.00338
; LINE_WIDTH: 0.322788
G3 X155.182 Y142.078 I-4.087 J-3.399 E.01747
; LINE_WIDTH: 0.308793
G1 X155.045 Y142.193 E.00388
; LINE_WIDTH: 0.2783
G1 X154.908 Y142.308 E.00343
; LINE_WIDTH: 0.24302
G1 X154.761 Y142.417 E.00299
; LINE_WIDTH: 0.202968
G1 X154.614 Y142.526 E.00239
; LINE_WIDTH: 0.162916
G1 X154.466 Y142.634 E.00179
; WIPE_START
G1 X154.614 Y142.526 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X147.56 Y145.442 Z1.2 F36000
G1 X128.57 Y153.293 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X130.8 Y151.063 E.09692
G1 X130.851 Y150.479
G1 X127.974 Y153.356 E.125
G1 X127.491 Y153.306
G1 X130.807 Y149.989 E.14412
G1 X130.698 Y149.565
G1 X127.07 Y153.193 E.15768
G1 X126.695 Y153.035
G1 X130.539 Y149.191 E.16703
G1 X130.336 Y148.86
G1 X126.363 Y152.834 E.17266
G1 X126.068 Y152.596
G1 X130.1 Y148.564 E.17521
G1 X129.826 Y148.305
G1 X125.809 Y152.321 E.17456
G1 X125.584 Y152.013
G1 X129.516 Y148.081 E.17087
G1 X129.169 Y147.895
G1 X125.398 Y151.665 E.16384
G1 X125.256 Y151.274
G1 X128.779 Y147.752 E.15307
G1 X128.332 Y147.665
G1 X125.168 Y150.829 E.13749
G1 X125.149 Y150.314
G1 X127.808 Y147.656 E.11553
G1 X127.156 Y147.775
G1 X125.277 Y149.654 E.08166
M204 S10000
G1 X125.466 Y151.856 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.107488
G1 F15000
G1 X125.477 Y151.799 E.00031
G1 X125.417 Y151.71 E.00056
G1 X126.645 Y147.992 F36000
; LINE_WIDTH: 0.106978
G1 F15000
G1 X126.527 Y148.078 E.00076
; LINE_WIDTH: 0.14224
G1 X126.379 Y148.202 E.00156
; LINE_WIDTH: 0.187358
G2 X125.689 Y148.892 I3.804 J4.503 E.0115
; LINE_WIDTH: 0.14267
G1 X125.587 Y149.021 E.00133
; LINE_WIDTH: 0.106341
G1 X125.486 Y149.149 E.00085
; WIPE_START
G1 X125.587 Y149.021 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X130.688 Y151.468 Z1.2 F36000
G1 Z.8
G1 E.8 F1800
; LINE_WIDTH: 0.110427
G1 F15000
G1 X130.617 Y151.572 E.0007
; LINE_WIDTH: 0.15495
G1 X130.546 Y151.677 E.00116
; LINE_WIDTH: 0.199474
G1 X130.474 Y151.782 E.00162
; LINE_WIDTH: 0.244385
G1 X130.357 Y151.931 E.00312
; LINE_WIDTH: 0.289702
G1 X130.239 Y152.081 E.00382
; LINE_WIDTH: 0.337842
G3 X129.722 Y152.616 I-4.173 J-3.515 E.01791
; LINE_WIDTH: 0.321866
G1 X129.578 Y152.737 E.00427
; LINE_WIDTH: 0.289804
G1 X129.434 Y152.859 E.00378
; LINE_WIDTH: 0.254107
G1 X129.283 Y152.969 E.00322
; LINE_WIDTH: 0.214791
G1 X129.132 Y153.08 E.00262
; LINE_WIDTH: 0.175474
G1 X128.981 Y153.191 E.00202
; WIPE_START
G1 X129.132 Y153.08 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X122.062 Y150.203 Z1.2 F36000
G1 X103.489 Y142.645 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X105.242 Y140.893 E.07616
G1 X105.386 Y140.216
G1 X102.808 Y142.794 E.11203
G1 X102.274 Y142.795
G1 X105.384 Y139.684 E.13517
G1 X105.302 Y139.233
G1 X101.818 Y142.717 E.15138
G1 X101.42 Y142.582
G1 X105.166 Y138.836 E.16278
G1 X104.985 Y138.483
G1 X101.067 Y142.401 E.17025
G1 X100.754 Y142.181
G1 X104.766 Y138.169 E.17433
G1 X104.51 Y137.892
G1 X100.477 Y141.925 E.17529
G1 X100.235 Y141.634
G1 X104.219 Y137.649 E.17316
G1 X103.892 Y137.444
G1 X100.029 Y141.306 E.16785
G1 X99.863 Y140.939
G1 X103.523 Y137.279 E.15906
G1 X103.107 Y137.161
G1 X99.745 Y140.524 E.14612
G1 X99.694 Y140.042
G1 X102.629 Y137.106 E.12757
G1 X102.057 Y137.146
G1 X99.734 Y139.469 E.10094
; WIPE_START
M204 S10000
G1 X101.148 Y138.054 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.957 Y141.473 Z1.2 F36000
M73 P46 R12
G1 Z.8
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.103604
G1 F15000
G1 X104.863 Y141.593 E.00075
; LINE_WIDTH: 0.145407
G3 X104.327 Y142.147 I-4.321 J-3.639 E.00644
; LINE_WIDTH: 0.131134
G1 X104.19 Y142.263 E.00129
; LINE_WIDTH: 0.102495
G1 X104.053 Y142.378 E.00087
; WIPE_START
G1 X104.19 Y142.263 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X101.657 Y137.226 Z1.2 F36000
G1 Z.8
G1 E.8 F1800
; LINE_WIDTH: 0.223036
G1 F15000
G1 X101.478 Y137.356 E.00324
; LINE_WIDTH: 0.262013
G1 X101.3 Y137.487 E.00394
; LINE_WIDTH: 0.300991
G1 X101.122 Y137.617 E.00465
; LINE_WIDTH: 0.336378
G1 X100.979 Y137.737 E.00446
; LINE_WIDTH: 0.379911
G2 X100.312 Y138.403 I3.674 J4.349 E.02592
; LINE_WIDTH: 0.332909
G1 X100.202 Y138.544 E.00423
; LINE_WIDTH: 0.290208
G1 X100.091 Y138.685 E.00361
; LINE_WIDTH: 0.244456
G1 X100.001 Y138.818 E.00264
; LINE_WIDTH: 0.195656
G1 X99.91 Y138.95 E.002
; LINE_WIDTH: 0.146857
G1 X99.82 Y139.083 E.00136
; WIPE_START
G1 X99.91 Y138.95 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X94.777 Y133.302 Z1.2 F36000
G1 X93.334 Y131.714 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.688 Y138.068 E.29809
G2 X99.383 Y141.265 I3.08 J1.907 E.11039
G1 X98.771 Y141.877 E.02871
G2 X102.744 Y145.58 I38.374 J-37.184 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.678 E.07828
G1 X153.256 Y145.58 E1.12957
G2 X157.229 Y141.877 I-34.403 J-40.89 E.18024
G1 X156.617 Y141.265 E.02871
G2 X156.311 Y138.069 I-3.383 J-1.288 E.11035
G1 X162.666 Y131.714 E.29815
G1 X102.328 Y127.52 F36000
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.332 Y148.36 E1.00994
G3 X130.669 Y148.359 I2.669 J2.202 E.20217
G1 X152.196 Y126.832 E1.0099
G1 X153.672 Y127.52 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X152.196 Y126.832 E-.61876
G1 X151.934 Y127.094 E-.14125
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
G1 X130.543 Y149.947
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.548 Y149.971 E.0008
G3 X127.645 Y147.921 I-2.548 J.527 E.41248
G3 X128.352 Y147.92 I.355 J2.725 E.02351
G3 X130.452 Y149.628 I-.352 J2.578 E.09444
G1 X130.526 Y149.889 E.00899
G1 X130.153 Y150.053 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.699 Y148.31 I-2.162 J.446 E.32445
G1 X127.983 Y148.291 E.00875
G3 X130.14 Y149.994 I.008 J2.208 E.09117
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13721
G1 X130.205 Y150.651 E-.11464
G1 X130.164 Y150.95 E-.11465
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.1146
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.876 E-.04956
; WIPE_END
G1 E-.04 F1800
G1 X136.263 Y147.94 Z1.4 F36000
G1 X151.012 Y139.062 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.146 Y138.759 E.01098
G3 X153.101 Y137.377 I2.311 J1.195 E.08255
G3 X153.808 Y137.376 I.355 J2.727 E.02352
G3 X150.993 Y139.118 I-.352 J2.578 E.42319
G1 X151.367 Y139.214 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.155 Y137.766 I2.08 J.741 E.07435
G1 X153.439 Y137.747 E.00875
G3 X151.348 Y139.27 I.008 J2.208 E.34138
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13748
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11462
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11462
G1 X152.575 Y137.928 E-.11466
G1 X152.697 Y137.885 E-.04927
; WIPE_END
G1 E-.04 F1800
G1 X147.339 Y132.45 Z1.4 F36000
G1 X133.505 Y118.419 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.021
G3 X127.977 Y107.75 I-5.107 J-4.414 E.8947
G3 X133.048 Y110.019 I.037 J6.719 E.18998
G1 X133.552 Y110.639 E.02652
G1 X133.552 Y118.361 E.25612
G1 X133.543 Y118.373 E.00051
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.988 Y108.142 I-5.157 J-3.722 E.79818
G3 X133.16 Y110.777 I.003 J6.389 E.18514
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X125.394 Y123.767 Z1.4 F36000
G1 X103.917 Y137.745 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X104.187 Y137.936 E.01098
G3 X102.19 Y137.377 I-1.642 J2.018 E.47145
G3 X102.896 Y137.376 I.355 J2.727 E.02352
G3 X103.866 Y137.713 I-.352 J2.578 E.03428
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.243 Y137.766 I-1.148 J1.886 E.37993
G3 X102.844 Y137.766 I.301 J2.319 E.01853
G3 X103.641 Y138.037 I-.3 J2.188 E.02601
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13733
G1 X104.16 Y138.447 E-.11465
G1 X104.35 Y138.681 E-.11465
G1 X104.507 Y138.939 E-.11465
G1 X104.627 Y139.216 E-.11465
G1 X104.708 Y139.506 E-.11467
G1 X104.726 Y139.635 E-.04941
; WIPE_END
G1 E-.04 F1800
G1 X111.448 Y136.02 Z1.4 F36000
G1 X139.909 Y120.718 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89477
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.096 Y120.715 E.89496
G3 X115.344 Y118.897 I18.693 J-8.796 E.06529
G3 X128.405 Y101.109 I12.659 J-4.394 E.86006
G3 X140.245 Y109.064 I-.41 J13.398 E.49894
G1 X140.675 Y110.102 E.03725
G1 X142.198 Y110.102 E.05053
G1 X142.198 Y118.898 E.29178
G1 X140.668 Y118.898 E.05077
G3 X139.915 Y120.67 I-23.79 J-9.057 E.06389
G1 X140.412 Y120.519 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82949
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.585 Y120.521 E.8294
G3 X122.959 Y101.664 I12.456 J-5.999 E.69805
G3 X128.418 Y100.717 I5.049 J12.89 E.1714
G3 X140.937 Y109.71 I-.436 J13.817 E.50241
G1 X142.59 Y109.71 E.0508
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05088
G3 X140.437 Y120.465 I-17.723 J-6.802 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.314 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.72 Y120.056 Z1.4 F36000
G1 X132.791 Y119.734 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X133.871 Y118.519 I-5.724 J-6.176 E.05401
G1 X152.071 Y136.733 E.85412
G2 X151.511 Y142.868 I1.395 J3.221 E.24939
G1 X142.584 Y151.796 E.41882
G3 X137.939 Y153.291 I-14.862 J-38.207 E.16194
G1 X109.039 Y124.39 E1.3558
G1 X108.182 Y124.79 E.03133
G1 X95.323 Y137.65 E.60328
G3 X92.419 Y132.877 I33.745 J-23.799 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I1.998 J-14.62 E.03419
G1 X125.798 Y153.23 E.05512
G2 X130.202 Y153.23 I2.202 J-2.73 E.15797
G1 X131.377 Y154.405 E.05511
G2 X132.402 Y154.301 I-.972 J-14.718 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.676 Y137.648 I-35.734 J-18.467 E.18546
G1 X147.817 Y124.79 E.60321
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.218 J-39.701 E.16194
G1 X104.489 Y142.868 E.41882
G2 X103.919 Y136.729 I-1.952 J-2.915 E.24978
G1 X122.142 Y118.506 E.85489
G3 X121.002 Y113.326 I5.915 J-4.018 E.18027
G1 X116.335 Y108.659 E.21892
G1 X115.502 Y110.757 F36000
G1 F15476.087
G3 X116.066 Y109.23 I12.922 J3.903 E.05401
G1 X122.732 Y102.564 E.31272
G3 X124.865 Y101.837 I6.899 J16.749 E.0748
G1 X131.182 Y108.154 E.29633
G3 X132.006 Y108.642 I-3.883 J7.487 E.03179
G1 X136.252 Y104.396 E.19921
G3 X137.446 Y105.502 I-16.572 J19.088 E.05398
G1 X139.667 Y108.657 F36000
G1 F15476.087
G1 X133.9 Y114.424 E.27054
G1 X133.9 Y110.872 E.1178
G1 X141.578 Y118.55 E.36015
G1 X140.433 Y118.55 E.03798
G3 X139.437 Y120.882 I-30.481 J-11.634 E.08414
G1 X141.727 Y121.949 E.0838
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.575 J-38.578 E.1893
G1 X141.85 Y114.15 E1.62321
G1 X141.85 Y111.146 E.09966
G1 X141.154 Y110.45 E.03263
G1 X140.442 Y110.45 E.02363
G1 X139.939 Y109.235 E.04361
G1 X133.27 Y102.567 E.31284
G2 X131.136 Y101.836 I-6.96 J16.852 E.07488
G1 X124.816 Y108.156 E.29648
G2 X123.992 Y108.64 I2.717 J5.566 E.03174
G1 X119.746 Y104.394 E.19918
G2 X118.555 Y105.503 I8.5 J10.323 E.05401
G1 X122.553 Y109.953 F36000
G1 F15476.087
G2 X121.661 Y111.311 I8.471 J6.532 E.05393
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I13.021 J-3.19 E.08977
G1 X148.751 Y148.751 E1.58519
G3 X143.677 Y151.353 I-21.649 J-35.975 E.1893
G1 X114.273 Y121.949 E1.37939
G1 X115.749 Y121.261 E.05401
G1 X105.593 Y139.754 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.538741
G1 F12000
G2 X102.923 Y136.926 I-3.055 J.21 E.17025
G1 X102.162 Y136.926 E.03078
G2 X100.287 Y137.899 I.43 J3.12 E.087
G1 X99.848 Y138.521 E.03077
G1 X99.655 Y138.968 E.01968
G1 X99.5 Y139.714 E.03077
G2 X99.562 Y140.613 I2.953 J.247 E.03656
G1 X99.817 Y141.331 E.03077
G2 X101.362 Y142.771 I2.796 J-1.45 E.087
G1 X102.095 Y142.976 E.03078
G1 X102.581 Y143.009 E.01968
G1 X103.336 Y142.905 E.03077
G1 X103.795 Y142.742 E.01968
G1 X104.445 Y142.346 E.03077
G2 X105.593 Y139.814 I-1.947 J-2.409 E.11647
; WIPE_START
G1 X105.593 Y140.147 E-.12678
G1 X105.538 Y140.561 E-.1584
G1 X105.428 Y140.963 E-.15847
G1 X105.264 Y141.346 E-.15836
G1 X105.05 Y141.702 E-.158
; WIPE_END
G1 E-.04 F1800
G1 X112.297 Y144.098 Z1.4 F36000
G1 X131.049 Y150.298 Z1.4
G1 Z1
G1 E.8 F1800
; LINE_WIDTH: 0.538619
G1 F12000
G2 X130.694 Y149.063 I-3.382 J.303 E.05223
G1 X130.255 Y148.44 E.03077
G2 X128.379 Y147.47 I-2.301 J2.151 E.08698
G1 X127.618 Y147.47 E.03076
G2 X125.743 Y148.443 I.43 J3.12 E.08698
G1 X125.304 Y149.065 E.03076
G2 X125.527 Y152.291 I2.689 J1.435 E.13767
G1 X126.047 Y152.847 E.03076
G2 X126.818 Y153.315 I1.905 J-2.27 E.03656
G1 X127.551 Y153.521 E.03077
G2 X131.049 Y150.358 I.438 J-3.031 E.21739
; WIPE_START
G1 X131.049 Y150.692 E-.12678
G1 X130.994 Y151.105 E-.15844
G1 X130.884 Y151.507 E-.15842
G1 X130.72 Y151.89 E-.15838
G1 X130.506 Y152.247 E-.15797
; WIPE_END
G1 E-.04 F1800
G1 X137.385 Y148.941 Z1.4 F36000
G1 X156.505 Y139.754 Z1.4
G1 Z1
G1 E.8 F1800
; LINE_WIDTH: 0.538734
G1 F12000
G2 X156.15 Y138.518 I-3.384 J.304 E.05225
G1 X155.71 Y137.896 E.03078
G2 X153.835 Y136.926 I-2.301 J2.15 E.087
G1 X153.073 Y136.926 E.03077
G2 X150.983 Y141.747 I.394 J3.034 E.25529
G1 X151.503 Y142.303 E.03077
G2 X152.273 Y142.771 I1.905 J-2.27 E.03657
G1 X153.007 Y142.976 E.03078
G1 X153.493 Y143.009 E.01968
G1 X154.247 Y142.905 E.03077
G1 X154.706 Y142.742 E.01968
G1 X155.357 Y142.346 E.03077
G1 X155.713 Y142.013 E.01968
G1 X156.152 Y141.391 E.03077
G2 X156.505 Y139.814 I-2.653 J-1.422 E.06609
G1 X162.666 Y131.714 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.368 Y138.012 E.29545
G3 X156.678 Y141.326 I-2.858 J1.938 E.1152
G1 X157.226 Y141.874 E.02573
G3 X153.253 Y145.577 I-29.25 J-27.4 E.1803
G1 X129.178 Y121.502 E1.12941
G3 X126.825 Y121.499 I-1.165 J-8.681 E.07828
G1 X102.744 Y145.58 E1.12972
G3 X98.771 Y141.877 I34.397 J-40.883 E.18024
G1 X99.322 Y141.326 E.02588
G3 X99.63 Y138.01 I3.176 J-1.377 E.11523
G1 X93.334 Y131.714 E.29538
G1 X153.672 Y127.52 F36000
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.725 Y148.303 E1.00726
G2 X125.276 Y148.303 I-2.724 J2.18 E.20744
G1 X103.804 Y126.832 E1.00729
G1 X102.328 Y127.52 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X103.804 Y126.832 E-.61876
G1 X104.066 Y127.094 E-.14125
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
G1 X130.542 Y149.947
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.553 Y149.97 E.00083
G3 X127.927 Y147.902 I-2.546 J.532 E.42177
G3 X129.353 Y148.276 I.055 J2.694 E.04953
G3 X130.457 Y149.627 I-1.346 J2.226 E.05903
G1 X130.527 Y149.889 E.009
G1 X130.171 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.954 Y148.293 I-2.161 J.451 E.33197
G3 X128.596 Y148.372 I.003 J2.635 E.01995
G3 X130.158 Y149.991 I-.587 J2.129 E.07251
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13748
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11462
G1 X129.806 Y151.775 E-.1147
G1 X129.724 Y151.875 E-.04925
; WIPE_END
G1 E-.04 F1800
G1 X123.03 Y148.209 Z1.6 F36000
G1 X103.875 Y137.72 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X102.471 Y137.357 I-1.345 J2.224 E.49218
G3 X103.58 Y137.571 I.055 J2.694 E.03773
G1 X103.822 Y137.693 E.00899
G1 X103.694 Y138.065 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.498 Y137.749 I-1.141 J1.891 E.38776
M73 P47 R12
G3 X103.141 Y137.827 I.003 J2.636 E.01995
G3 X103.642 Y138.035 I-.587 J2.129 E.01673
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13738
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04938
; WIPE_END
G1 E-.04 F1800
G1 X110.87 Y135.106 Z1.6 F36000
G1 X133.505 Y118.419 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.021
G3 X127.961 Y107.751 I-5.109 J-4.413 E.89437
G3 X133.552 Y110.639 I.004 J6.847 E.21689
G1 X133.552 Y118.361 E.25612
G1 X133.543 Y118.372 E.0005
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.973 Y108.143 I-5.156 J-3.722 E.79759
G3 X133.16 Y110.777 I0 J6.424 E.18552
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22946
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X137.155 Y125.034 Z1.6 F36000
G1 X151.012 Y139.062 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.153 Y138.763 E.01096
G3 X153.383 Y137.357 I2.31 J1.194 E.09169
G3 X154.809 Y137.731 I.055 J2.694 E.04953
G3 X151.001 Y139.12 I-1.346 J2.225 E.38784
G1 X151.384 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.41 Y137.749 I2.082 J.737 E.08179
G3 X154.052 Y137.827 I.003 J2.636 E.01995
G3 X151.364 Y139.276 I-.587 J2.129 E.32269
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13718
G1 X151.626 Y138.721 E-.09701
G1 X151.84 Y138.447 E-.13215
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.0497
; WIPE_END
G1 E-.04 F1800
G1 X148.139 Y131.764 Z1.6 F36000
G1 X139.909 Y120.718 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89476
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.107 J-7.696 E.08797
G3 X128.398 Y101.109 I12.867 J-3.742 E.83714
G3 X140.243 Y109.06 I-.403 J13.399 E.499
G1 X140.675 Y110.102 E.03742
G1 X142.198 Y110.102 E.05053
G1 X142.198 Y118.898 E.29178
G1 X140.668 Y118.898 E.05077
G3 X139.915 Y120.67 I-23.922 J-9.11 E.06389
G1 X140.412 Y120.519 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82949
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.411 Y100.717 I12.426 J-6.008 E.86942
G3 X140.937 Y109.71 I-.428 J13.816 E.50263
G1 X142.59 Y109.71 E.0508
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05088
G3 X140.437 Y120.465 I-17.782 J-6.826 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.314 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.03 Y114.011 Z1.6 F36000
G1 X137.446 Y105.502 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X136.252 Y104.396 I-17.291 J17.472 E.05398
G1 X132.006 Y108.642 E.1992
G2 X131.182 Y108.154 I-4.706 J6.997 E.03179
G1 X124.865 Y101.837 E.29633
G2 X122.732 Y102.564 I4.767 J17.483 E.0748
G1 X116.066 Y109.23 E.31272
G2 X115.502 Y110.757 I12.355 J5.429 E.05401
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21892
G2 X122.142 Y118.506 I7.063 J1.161 E.18026
G1 X103.929 Y136.733 E.85474
G3 X104.489 Y142.868 I-1.395 J3.221 E.2494
G1 X113.416 Y151.796 E.41882
G2 X118.061 Y153.291 I14.863 J-38.208 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.833 J-23.241 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-1.997 J-14.614 E.03419
G1 X130.202 Y153.23 E.05511
G3 X125.798 Y153.23 I-2.202 J-2.73 E.15797
G1 X124.622 Y154.406 E.05515
G3 X123.598 Y154.301 I1.32 J-18.025 E.03417
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.649 I36.648 J-19.027 E.18545
G1 X108.182 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.584 Y151.796 I-10.135 J-39.442 E.16194
G1 X151.511 Y142.868 E.41882
G3 X152.081 Y136.729 I1.952 J-2.915 E.24977
G1 X133.871 Y118.519 E.85427
G3 X132.791 Y119.734 I-6.804 J-4.962 E.05401
; WIPE_START
G1 X133.374 Y119.142 E-.31576
G1 X133.871 Y118.519 E-.3028
G1 X134.134 Y118.782 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X126.57 Y119.802 Z1.6 F36000
G1 X115.749 Y121.261 Z1.6
G1 Z1.2
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.677 Y151.353 E1.37939
G2 X148.751 Y148.751 I-16.574 J-38.577 E.1893
G1 X114.961 Y114.961 E1.5852
G2 X115.336 Y117.636 I13.397 J-.515 E.08977
G1 X121.661 Y111.311 E.29673
G3 X122.553 Y109.953 I11.682 J6.697 E.05391
G1 X118.556 Y105.503 F36000
G1 F15476.087
G3 X119.746 Y104.394 I9.636 J9.153 E.05401
G1 X123.992 Y108.64 E.19918
G3 X124.816 Y108.156 I3.542 J5.083 E.03174
G1 X131.136 Y101.836 E.29647
G3 X133.27 Y102.566 I-4.821 J17.58 E.07488
G1 X139.939 Y109.235 E.31284
G1 X140.442 Y110.45 E.04363
G1 X141.154 Y110.45 E.02362
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y114.15 E.09966
G1 X107.249 Y148.751 E1.62321
G2 X112.323 Y151.353 I21.648 J-35.974 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X139.437 Y120.882 E.08379
G2 X140.433 Y118.55 I-29.723 J-14.062 E.08414
G1 X141.578 Y118.55 E.03798
G1 X133.9 Y110.872 E.36015
G1 X133.9 Y114.424 E.1178
G1 X139.667 Y108.657 E.27054
; WIPE_START
G1 X138.253 Y110.071 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X142.251 Y116.573 Z1.6 F36000
G1 X156.505 Y139.754 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.538655
G1 F12000
G2 X156.15 Y138.519 I-3.384 J.304 E.05221
G1 X155.71 Y137.896 E.0308
G2 X153.345 Y136.908 I-2.24 J2.037 E.10694
G1 X152.663 Y137.007 E.02784
G2 X151.2 Y137.898 I.779 J2.925 E.07017
G1 X150.76 Y138.521 E.03079
G2 X152.273 Y142.771 I2.693 J1.436 E.20506
G1 X153.007 Y142.976 E.03079
G2 X155.712 Y142.013 I.431 J-3.069 E.12061
G1 X156.152 Y141.391 E.03079
G2 X156.505 Y139.814 I-2.653 J-1.422 E.06608
; WIPE_START
G1 X156.504 Y140.147 E-.12679
G1 X156.45 Y140.561 E-.15843
G1 X156.34 Y140.963 E-.15842
G1 X156.152 Y141.391 E-.17755
G1 X155.941 Y141.689 E-.1388
; WIPE_END
G1 E-.04 F1800
G1 X148.728 Y144.184 Z1.6 F36000
G1 X131.049 Y150.298 Z1.6
G1 Z1.2
G1 E.8 F1800
; LINE_WIDTH: 0.538555
G1 F12000
G2 X130.694 Y149.063 I-3.383 J.303 E.0522
G1 X130.255 Y148.44 E.03079
G2 X127.889 Y147.452 I-2.241 J2.038 E.10692
G1 X127.207 Y147.551 E.02784
G2 X125.744 Y148.443 I.78 J2.926 E.07016
G1 X125.304 Y149.065 E.03078
G2 X125.306 Y151.937 I2.748 J1.434 E.12058
G1 X125.746 Y152.559 E.03079
G2 X126.817 Y153.315 I2.404 J-2.268 E.05329
G1 X127.551 Y153.521 E.03079
G2 X131.049 Y150.358 I.438 J-3.031 E.21737
; WIPE_START
G1 X131.049 Y150.692 E-.12679
G1 X130.994 Y151.105 E-.1584
G1 X130.884 Y151.507 E-.15845
G1 X130.72 Y151.89 E-.15835
G1 X130.506 Y152.247 E-.158
; WIPE_END
G1 E-.04 F1800
G1 X123.683 Y148.825 Z1.6 F36000
G1 X105.593 Y139.754 Z1.6
G1 Z1.2
G1 E.8 F1800
; LINE_WIDTH: 0.538513
G1 F12000
G2 X102.433 Y136.908 I-3.059 J.219 E.18977
G1 X101.751 Y137.007 E.02784
G2 X101.361 Y142.771 I.792 J2.949 E.30603
G1 X102.095 Y142.976 E.03078
G2 X105.593 Y139.814 I.438 J-3.031 E.21735
G1 X102.328 Y127.52 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.276 Y148.303 E1.00729
G3 X130.725 Y148.303 I2.725 J2.179 E.20744
G1 X152.196 Y126.832 E1.00726
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X99.63 Y138.01 E.29538
G2 X99.322 Y141.326 I2.868 J1.938 E.11523
G1 X98.771 Y141.877 E.02588
G2 X102.744 Y145.58 I38.368 J-37.178 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.68 E.07828
G1 X153.256 Y145.58 E1.12957
G2 X157.226 Y141.874 I-26.048 J-31.875 E.18028
G1 X156.678 Y141.326 E.02573
G2 X156.368 Y138.012 I-3.167 J-1.376 E.1152
G1 X162.666 Y131.714 E.29545
; CHANGE_LAYER
; Z_HEIGHT: 1.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.554 Y149.969 E.00083
G3 X127.911 Y147.903 I-2.546 J.532 E.42116
G3 X129.353 Y148.276 I.075 J2.683 E.05006
G3 X130.457 Y149.627 I-1.345 J2.226 E.05903
G1 X130.527 Y149.889 E.009
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.938 Y148.294 I-2.161 J.45 E.33137
G3 X128.881 Y148.473 I.079 J2.159 E.02974
G3 X130.156 Y149.991 I-.873 J2.027 E.06318
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13743
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11462
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.948 Z1.8 F36000
G1 X150.996 Y139.107 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.013 Y139.088 E.00085
G3 X153.367 Y137.358 I2.451 J.87 E.10288
G3 X154.809 Y137.731 I.075 J2.683 E.05006
G3 X150.917 Y139.428 I-1.345 J2.226 E.37734
G1 X150.982 Y139.166 E.00898
G1 X151.382 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.393 Y137.75 I2.081 J.738 E.08131
G3 X154.337 Y137.928 I.079 J2.159 E.02974
G3 X151.363 Y139.276 I-.873 J2.028 E.31344
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13721
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04954
; WIPE_END
G1 E-.04 F1800
G1 X147.339 Y132.45 Z1.8 F36000
G1 X133.505 Y118.419 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02101
G3 X127.946 Y107.751 I-5.109 J-4.413 E.89387
G3 X133.552 Y110.639 I.029 J6.827 E.21744
G1 X133.552 Y118.361 E.25612
G1 X133.543 Y118.372 E.0005
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.957 Y108.143 I-5.156 J-3.722 E.79709
G3 X133.16 Y110.777 I.035 J6.386 E.18607
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X125.388 Y123.759 Z1.8 F36000
G1 X103.875 Y137.72 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X102.455 Y137.358 I-1.345 J2.226 E.49197
G3 X103.58 Y137.571 I.075 J2.683 E.03827
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.066 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.482 Y137.75 I-1.141 J1.89 E.38725
G3 X103.425 Y137.928 I.079 J2.159 E.02974
G3 X103.641 Y138.036 I-.873 J2.028 E.00744
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13738
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04938
; WIPE_END
G1 E-.04 F1800
G1 X111.448 Y136.02 Z1.8 F36000
G1 X139.909 Y120.718 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89476
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.246 I16.103 J-7.694 E.08797
G3 X128.391 Y101.109 I12.871 J-3.739 E.83681
G3 X140.241 Y109.056 I-.397 J13.401 E.49908
G1 X140.675 Y110.102 E.03758
G1 X142.198 Y110.102 E.05052
G1 X142.198 Y118.898 E.29178
G1 X140.668 Y118.898 E.05076
G3 X139.915 Y120.67 I-24.053 J-9.162 E.06388
M73 P48 R12
G1 X140.412 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82949
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.404 Y100.717 I12.424 J-6.009 E.86924
G3 X140.937 Y109.71 I-.421 J13.816 E.50286
G1 X142.59 Y109.71 E.0508
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05088
G3 X140.437 Y120.465 I-17.849 J-6.853 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.314 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.72 Y120.056 Z1.8 F36000
G1 X132.791 Y119.734 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X133.871 Y118.519 I-5.722 J-6.175 E.05401
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.945 J2.796 E.22145
G1 X142.584 Y151.796 E.43751
G3 X137.939 Y153.291 I-14.862 J-38.207 E.16194
G1 X109.039 Y124.39 E1.3558
G1 X108.182 Y124.79 E.03133
G1 X95.323 Y137.649 E.60328
G3 X92.419 Y132.877 I33.738 J-23.795 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I1.998 J-14.62 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.448 E.12814
G1 X131.377 Y154.405 E.0738
G2 X132.402 Y154.301 I-.972 J-14.718 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.676 Y137.648 I-35.734 J-18.467 E.18546
G1 X147.817 Y124.79 E.60321
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.218 J-39.703 E.16194
G1 X104.09 Y142.47 E.43751
G2 X103.484 Y137.164 I-1.551 J-2.511 E.22145
G1 X122.142 Y118.506 E.87527
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.659 E.21892
G1 X115.502 Y110.757 F36000
G1 F15476.087
G3 X116.066 Y109.23 I12.918 J3.902 E.05401
G1 X122.732 Y102.564 E.31272
G3 X124.865 Y101.837 I6.896 J16.744 E.0748
G1 X131.182 Y108.154 E.29633
G3 X132.006 Y108.642 I-3.884 J7.489 E.03179
G1 X136.252 Y104.396 E.19919
G3 X137.445 Y105.502 I-15.639 J18.085 E.05398
G1 X139.667 Y108.657 F36000
G1 F15476.087
G1 X133.9 Y114.424 E.27054
G1 X133.9 Y110.872 E.1178
G1 X141.578 Y118.55 E.36015
G1 X140.433 Y118.55 E.03798
G3 X139.438 Y120.882 I-30.967 J-11.831 E.08413
G1 X141.727 Y121.949 E.08377
M73 P48 R11
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.572 J-38.572 E.1893
G1 X141.85 Y114.15 E1.62321
G1 X141.85 Y111.146 E.09966
G1 X141.154 Y110.45 E.03263
G1 X140.442 Y110.45 E.02361
G1 X139.939 Y109.235 E.04365
G1 X133.27 Y102.566 E.31283
G2 X131.136 Y101.837 I-6.952 J16.848 E.07488
G1 X124.816 Y108.156 E.29646
G2 X123.992 Y108.64 I2.717 J5.566 E.03174
G1 X119.746 Y104.394 E.19918
G2 X118.556 Y105.503 I8.453 J10.273 E.05401
G1 X122.553 Y109.953 F36000
G1 F15476.087
G2 X121.661 Y111.311 I11.206 J8.327 E.05391
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I13.021 J-3.191 E.08977
G1 X148.751 Y148.751 E1.5852
G3 X143.677 Y151.353 I-21.65 J-35.978 E.1893
G1 X114.273 Y121.949 E1.37939
G1 X115.749 Y121.261 E.05401
G1 X153.672 Y127.52 F36000
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.331 Y148.697 E1.02576
G2 X125.674 Y148.702 I-2.326 J1.849 E.17749
G1 X103.804 Y126.832 E1.02599
G1 X102.328 Y127.52 E.05401
G1 X162.666 Y131.714 F36000
G1 F15476.087
G1 X155.962 Y138.418 E.3145
G3 X156.251 Y140.899 I-2.497 J1.548 E.08558
G1 X157.226 Y141.874 E.04575
G3 X153.256 Y145.58 I-30.023 J-28.176 E.18028
G1 X129.178 Y121.502 E1.12957
G3 X126.825 Y121.499 I-1.164 J-8.683 E.07828
G1 X102.744 Y145.58 E1.12972
G3 X98.771 Y141.877 I34.397 J-40.883 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I2.815 J-.936 E.08564
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 1.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.554 Y149.969 E.00083
G3 X127.895 Y147.904 I-2.546 J.533 E.42056
G3 X129.353 Y148.276 I.094 J2.673 E.05059
G3 X130.457 Y149.627 I-1.344 J2.226 E.05903
G1 X130.527 Y149.889 E.00901
G1 X130.17 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.922 Y148.295 I-2.161 J.452 E.33104
G3 X128.881 Y148.473 I.097 J2.152 E.03023
G3 X130.157 Y149.991 I-.872 J2.029 E.06321
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13747
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04927
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.947 Z2 F36000
G1 X150.996 Y139.107 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.014 Y139.088 E.00087
G3 X153.351 Y137.36 I2.451 J.87 E.10232
G3 X154.809 Y137.731 I.095 J2.673 E.05059
G3 X150.918 Y139.429 I-1.344 J2.226 E.37733
G1 X150.982 Y139.166 E.00898
G1 X151.384 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.377 Y137.751 I2.081 J.738 E.08078
G3 X154.337 Y137.928 I.097 J2.152 E.03023
G3 X151.364 Y139.276 I-.872 J2.029 E.31346
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13719
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11464
G1 X152.061 Y138.241 E-.11462
G1 X152.307 Y138.067 E-.11465
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04955
; WIPE_END
G1 E-.04 F1800
G1 X147.339 Y132.45 Z2 F36000
G1 X133.505 Y118.419 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02101
G3 X127.931 Y107.752 I-5.109 J-4.412 E.89336
G3 X133.552 Y110.639 I.033 J6.85 E.21788
G1 X133.552 Y118.361 E.25612
G1 X133.543 Y118.372 E.00049
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.942 Y108.144 I-5.156 J-3.721 E.79664
G3 X133.16 Y110.777 I.051 J6.385 E.18653
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22946
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X125.388 Y123.759 Z2 F36000
G1 X103.875 Y137.72 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X102.439 Y137.36 I-1.344 J2.226 E.49139
G3 X103.58 Y137.571 I.094 J2.673 E.0388
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.066 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.466 Y137.751 I-1.14 J1.891 E.3868
G3 X103.425 Y137.928 I.097 J2.152 E.03023
G3 X103.642 Y138.036 I-.872 J2.029 E.00744
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13738
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11466
G1 X104.726 Y139.635 E-.04938
; WIPE_END
G1 E-.04 F1800
G1 X111.448 Y136.02 Z2 F36000
G1 X139.908 Y120.717 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89478
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.246 I16.106 J-7.695 E.08796
G3 X128.393 Y101.109 I12.871 J-3.739 E.83688
G3 X140.239 Y109.051 I-.4 J13.403 E.49886
G1 X140.674 Y110.102 E.03773
G1 X142.198 Y110.102 E.05054
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.914 Y120.67 I-23.754 J-9.053 E.06391
G1 X140.411 Y120.519 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.8295
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.399 Y100.717 I12.423 J-6.01 E.86913
G3 X140.936 Y109.71 I-.418 J13.819 E.50297
G1 X142.59 Y109.71 E.05081
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.437 Y120.465 I-18.155 J-6.99 E.03921
; WIPE_START
M204 S10000
G1 X142.247 Y121.314 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.03 Y114.011 Z2 F36000
G1 X137.445 Y105.502 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X136.252 Y104.397 I-16.387 J16.501 E.05398
G1 X132.006 Y108.642 E.19918
G2 X131.182 Y108.154 I-4.706 J6.997 E.03179
G1 X124.865 Y101.837 E.29633
G2 X122.732 Y102.564 I4.767 J17.484 E.0748
G1 X116.066 Y109.23 E.31272
G2 X115.502 Y110.757 I12.361 J5.431 E.05401
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21893
G2 X122.142 Y118.506 I7.077 J1.158 E.18024
G1 X103.484 Y137.164 E.87527
G3 X104.083 Y142.463 I-.973 J2.793 E.22039
G1 X113.416 Y151.796 E.43785
G2 X118.061 Y153.291 I14.863 J-38.208 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.831 J-23.24 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-1.997 J-14.614 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.448 E.12814
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.974 J-14.741 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.649 I36.642 J-19.023 E.18545
G1 X108.182 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.584 Y151.796 I-10.218 J-39.702 E.16194
G1 X151.91 Y142.47 E.43751
G3 X152.516 Y137.164 I1.551 J-2.511 E.22145
G1 X133.871 Y118.519 E.87466
G3 X132.791 Y119.734 I-6.804 J-4.962 E.05401
; WIPE_START
G1 X133.374 Y119.142 E-.31576
G1 X133.871 Y118.519 E-.3028
G1 X134.134 Y118.782 E-.14145
; WIPE_END
M73 P49 R11
G1 E-.04 F1800
G1 X126.57 Y119.802 Z2 F36000
G1 X115.749 Y121.261 Z2
G1 Z1.6
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.677 Y151.353 E1.37939
G2 X148.751 Y148.751 I-16.574 J-38.577 E.1893
G1 X114.961 Y114.961 E1.5852
G2 X115.336 Y117.636 I13.397 J-.515 E.08977
G1 X121.661 Y111.311 E.29673
G3 X122.553 Y109.953 I12.543 J7.262 E.05391
G1 X118.556 Y105.503 F36000
G1 F15476.087
G3 X119.746 Y104.394 I9.594 J9.109 E.05401
G1 X123.992 Y108.64 E.19918
G3 X124.816 Y108.156 I3.54 J5.081 E.03174
G1 X131.136 Y101.836 E.29646
G3 X133.27 Y102.566 I-4.849 J17.668 E.07487
G1 X139.938 Y109.234 E.31282
G1 X140.442 Y110.45 E.04365
G1 X141.154 Y110.45 E.02363
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y114.15 E.09966
G1 X107.249 Y148.751 E1.62321
G2 X112.323 Y151.353 I21.65 J-35.977 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X139.437 Y120.882 E.08378
G2 X140.431 Y118.55 I-27.58 J-13.122 E.08411
G1 X141.578 Y118.55 E.03805
G1 X133.9 Y110.872 E.36015
G1 X133.9 Y114.424 E.1178
G1 X139.667 Y108.657 E.27053
; WIPE_START
G1 X138.253 Y110.071 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.387 Y113.406 Z2 F36000
G1 X102.328 Y127.52 Z2
G1 Z1.6
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.669 Y148.697 E1.02576
G3 X130.331 Y148.697 I2.331 J1.858 E.17754
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.034 Y138.414 E.31433
G2 X99.749 Y140.899 I2.529 J1.549 E.08564
G1 X98.771 Y141.877 E.0459
G2 X102.744 Y145.58 I38.37 J-37.18 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.679 E.07828
G1 X153.253 Y145.577 E1.12941
G2 X157.226 Y141.874 I-25.273 J-31.099 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.966 Y138.414 I-2.815 J-.936 E.08565
G1 X162.666 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 1.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.547 Y149.971 E.0008
G3 X125.81 Y149.102 I-2.546 J.532 E.33782
G3 X127.879 Y147.905 I2.165 J1.354 E.08252
G3 X130.451 Y149.629 I.123 J2.598 E.11002
G1 X130.526 Y149.889 E.00899
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.906 Y148.296 I-2.161 J.452 E.33058
G3 X129.149 Y148.611 I.086 J2.267 E.03995
G3 X130.156 Y149.991 I-1.141 J1.89 E.05389
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13743
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X123.03 Y148.209 Z2.2 F36000
G1 X103.875 Y137.72 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X104.187 Y137.936 I-1.338 J2.204 E.0118
G3 X102.423 Y137.361 I-1.636 J2.022 E.47905
G3 X103.581 Y137.568 I.136 J2.574 E.03938
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.45 Y137.752 I-1.141 J1.889 E.38605
G3 X103.641 Y138.037 I.086 J2.267 E.0381
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13735
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.0494
; WIPE_END
G1 E-.04 F1800
G1 X110.87 Y135.106 Z2.2 F36000
G1 X133.505 Y118.419 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02101
G3 X127.916 Y107.752 I-5.107 J-4.413 E.89265
G3 X133.552 Y110.639 I.049 J6.849 E.21837
G1 X133.552 Y118.361 E.25613
G1 X133.543 Y118.372 E.00049
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.927 Y108.144 I-5.157 J-3.721 E.79631
G3 X133.16 Y110.777 I.063 J6.391 E.18698
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X137.146 Y125.042 Z2.2 F36000
G1 X150.996 Y139.107 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.013 Y139.088 E.00086
G3 X153.335 Y137.361 I2.45 J.87 E.10179
G3 X155.099 Y137.936 I.136 J2.574 E.06297
G3 X150.918 Y139.428 I-1.636 J2.021 E.36546
G1 X150.982 Y139.166 E.00898
G1 X151.384 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.361 Y137.752 I2.08 J.737 E.08028
G3 X154.604 Y138.067 I.086 J2.267 E.03995
G3 X151.364 Y139.276 I-1.141 J1.889 E.30392
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.1372
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04955
; WIPE_END
G1 E-.04 F1800
G1 X148.138 Y131.764 Z2.2 F36000
G1 X139.908 Y120.717 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89478
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.108 J-7.696 E.08797
G3 X128.386 Y101.108 I12.871 J-3.739 E.83665
G3 X140.237 Y109.047 I-.389 J13.397 E.49894
G1 X140.674 Y110.102 E.03789
G1 X142.198 Y110.102 E.05054
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.914 Y120.67 I-23.862 J-9.1 E.06391
G1 X140.411 Y120.519 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.8295
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.392 Y100.716 I12.423 J-6.009 E.86892
G3 X140.936 Y109.71 I-.408 J13.814 E.5032
G1 X142.59 Y109.71 E.05081
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.437 Y120.465 I-18.289 J-7.047 E.03921
; WIPE_START
M204 S10000
G1 X142.247 Y121.314 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.719 Y120.056 Z2.2 F36000
G1 X132.791 Y119.734 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X133.871 Y118.519 I-5.726 J-6.178 E.05401
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.945 J2.796 E.22145
G1 X142.584 Y151.796 E.43751
G3 X137.939 Y153.291 I-14.862 J-38.207 E.16194
G1 X109.039 Y124.39 E1.3558
G1 X108.182 Y124.79 E.03133
G1 X95.323 Y137.65 E.60328
G3 X92.419 Y132.877 I33.748 J-23.801 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I2.001 J-14.656 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.448 E.12814
G1 X131.377 Y154.405 E.0738
G2 X132.402 Y154.301 I-.972 J-14.718 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.676 Y137.648 I-35.732 J-18.466 E.18546
G1 X147.817 Y124.79 E.60321
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.218 J-39.703 E.16194
G1 X104.09 Y142.47 E.43751
G2 X103.484 Y137.164 I-1.551 J-2.511 E.22145
G1 X122.142 Y118.506 E.87528
G3 X121.002 Y113.326 I6.089 J-4.056 E.18006
G1 X116.335 Y108.659 E.21893
G1 X115.502 Y110.756 F36000
G1 F15476.087
G3 X116.066 Y109.23 I12.919 J3.903 E.05401
G1 X122.732 Y102.564 E.31272
G3 X124.865 Y101.837 I6.908 J16.783 E.0748
G1 X131.182 Y108.154 E.29632
G3 X132.006 Y108.642 I-3.879 J7.48 E.03179
G1 X136.252 Y104.396 E.1992
G3 X137.445 Y105.502 I-15.247 J17.65 E.05398
G1 X139.666 Y108.658 F36000
G1 F15476.087
G1 X133.9 Y114.424 E.2705
G1 X133.9 Y110.872 E.1178
G1 X141.578 Y118.55 E.36015
G1 X140.431 Y118.55 E.03804
G3 X139.438 Y120.882 I-28.61 J-10.806 E.08411
G1 X141.727 Y121.949 E.08378
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.577 J-38.581 E.1893
G1 X141.85 Y114.15 E1.62321
G1 X141.85 Y111.146 E.09966
G1 X141.154 Y110.45 E.03263
G1 X140.442 Y110.45 E.02363
G1 X139.938 Y109.234 E.04367
G1 X133.272 Y102.568 E.31274
G2 X131.135 Y101.837 I-6.897 J16.667 E.07494
G1 X124.816 Y108.156 E.29645
G2 X123.992 Y108.64 I2.716 J5.564 E.03174
G1 X119.746 Y104.395 E.19918
G2 X118.556 Y105.503 I8.356 J10.164 E.05401
G1 X122.552 Y109.953 F36000
G1 F15476.087
G2 X121.661 Y111.311 I8.507 J6.555 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I13.027 J-3.191 E.08977
G1 X148.751 Y148.751 E1.5852
G3 X143.677 Y151.353 I-21.649 J-35.975 E.1893
G1 X114.273 Y121.949 E1.37939
G1 X115.749 Y121.261 E.05401
G1 X153.672 Y127.52 F36000
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.331 Y148.697 E1.02576
G2 X125.669 Y148.697 I-2.331 J1.798 E.17844
G1 X103.804 Y126.832 E1.02576
G1 X102.328 Y127.52 E.05401
G1 X162.666 Y131.714 F36000
G1 F15476.087
G1 X155.966 Y138.414 E.31433
G3 X156.251 Y140.899 I-2.53 J1.549 E.08565
G1 X157.229 Y141.877 E.0459
G3 X153.256 Y145.58 I-38.368 J-37.178 E.18024
G1 X129.178 Y121.502 E1.12957
G3 X126.825 Y121.499 I-1.165 J-8.681 E.07828
G1 X102.744 Y145.58 E1.12972
G3 X98.771 Y141.877 I34.401 J-40.887 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I2.815 J-.936 E.08564
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.553 Y149.97 E.00082
G3 X127.863 Y147.906 I-2.545 J.533 E.41946
G3 X129.643 Y148.48 I.153 J2.572 E.0635
G3 X130.456 Y149.627 I-1.635 J2.022 E.04722
G1 X130.527 Y149.889 E.009
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
M73 P50 R11
G3 X127.89 Y148.297 I-2.161 J.452 E.33004
G3 X129.149 Y148.611 I.105 J2.26 E.04044
G3 X130.156 Y149.991 I-1.141 J1.89 E.05389
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13743
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11462
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X136.263 Y147.939 Z2.4 F36000
G1 X151.012 Y139.062 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.154 Y138.763 E.01096
G3 X153.319 Y137.362 I2.31 J1.195 E.0895
G3 X155.099 Y137.936 I.153 J2.572 E.0635
G3 X151.002 Y139.12 I-1.635 J2.022 E.37612
G1 X151.383 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.345 Y137.753 I2.081 J.738 E.07979
G3 X154.604 Y138.067 I.105 J2.26 E.04044
G3 X151.364 Y139.276 I-1.141 J1.89 E.30414
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13719
G1 X151.65 Y138.681 E-.11467
G1 X151.84 Y138.447 E-.11464
G1 X152.061 Y138.241 E-.11463
G1 X152.307 Y138.067 E-.11465
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04956
; WIPE_END
G1 E-.04 F1800
G1 X147.365 Y132.425 Z2.4 F36000
G1 X133.552 Y118.286 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.552 Y118.361 E.00247
G1 X133.11 Y118.914 E.02349
G3 X127.901 Y107.753 I-5.109 J-4.412 E.89234
G3 X133.552 Y110.639 I.065 J6.848 E.21888
G1 X133.552 Y118.226 E.25166
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.912 Y108.145 I-5.156 J-3.721 E.79569
G3 X133.16 Y110.777 I.079 J6.39 E.18744
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22946
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X125.388 Y123.759 Z2.4 F36000
G1 X103.875 Y137.72 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X104.187 Y137.936 I-1.337 J2.203 E.01179
G3 X102.407 Y137.362 I-1.635 J2.022 E.47849
G3 X103.581 Y137.568 I.153 J2.573 E.03991
G1 X103.822 Y137.693 E.009
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.434 Y137.753 I-1.141 J1.89 E.38577
G3 X103.641 Y138.037 I.105 J2.26 E.0386
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13734
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04942
; WIPE_END
G1 E-.04 F1800
G1 X111.448 Y136.021 Z2.4 F36000
G1 X139.909 Y120.718 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89475
G3 X91.645 Y132.117 I-36.355 J-17.62 E3.00058
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.11 J-7.697 E.08797
G3 X128.378 Y101.108 I12.871 J-3.739 E.83639
G3 X140.235 Y109.042 I-.383 J13.399 E.49903
G1 X140.675 Y110.102 E.03805
G1 X142.198 Y110.102 E.05053
G1 X142.198 Y118.898 E.29178
G1 X140.668 Y118.898 E.05077
G3 X139.916 Y120.67 I-24.34 J-9.274 E.06387
G1 X140.412 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82948
G3 X91.122 Y131.928 I-36.878 J-17.427 E2.83082
G1 X115.586 Y120.52 E.82942
G3 X128.385 Y100.716 I12.423 J-6.009 E.86867
G3 X140.936 Y109.71 I-.4 J13.814 E.50344
G1 X142.59 Y109.71 E.05081
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.437 Y120.465 I-17.961 J-6.897 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.314 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.03 Y114.011 Z2.4 F36000
G1 X137.445 Y105.502 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X136.252 Y104.396 I-16.094 J16.171 E.05398
G1 X132.006 Y108.642 E.1992
G2 X131.182 Y108.154 I-4.703 J6.991 E.03179
G1 X124.865 Y101.837 E.29632
G2 X122.732 Y102.564 I4.773 J17.507 E.0748
G1 X116.066 Y109.23 E.31272
G2 X115.503 Y110.756 I12.346 J5.426 E.05401
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21893
G2 X122.142 Y118.506 I7.091 J1.155 E.18022
G1 X103.484 Y137.164 E.87527
G3 X104.09 Y142.47 I-.982 J2.8 E.22044
G1 X113.416 Y151.796 E.43751
G2 X118.061 Y153.291 I14.863 J-38.209 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.833 J-23.241 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-2.001 J-14.646 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.448 E.12814
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.972 J-14.72 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.65 I36.649 J-19.027 E.18545
G1 X108.182 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.584 Y151.796 I-10.218 J-39.702 E.16194
G1 X151.91 Y142.47 E.43751
G3 X152.516 Y137.164 I1.551 J-2.511 E.22145
G1 X133.871 Y118.519 E.87466
G3 X132.791 Y119.734 I-6.806 J-4.963 E.05401
; WIPE_START
G1 X133.374 Y119.142 E-.3158
G1 X133.871 Y118.519 E-.30276
G1 X134.134 Y118.782 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X126.57 Y119.802 Z2.4 F36000
G1 X115.749 Y121.261 Z2.4
G1 Z2
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.677 Y151.353 E1.37939
G2 X148.751 Y148.751 I-16.574 J-38.577 E.1893
G1 X114.961 Y114.961 E1.5852
G2 X115.336 Y117.636 I13.399 J-.516 E.08977
G1 X121.661 Y111.311 E.29673
G3 X122.553 Y109.953 I13.551 J7.923 E.05391
G1 X118.556 Y105.504 F36000
G1 F15476.087
G3 X119.746 Y104.395 I9.497 J8.999 E.05401
G1 X123.992 Y108.64 E.19917
G3 X124.816 Y108.156 I3.54 J5.081 E.03174
G1 X131.135 Y101.837 E.29644
G3 X133.272 Y102.568 I-4.75 J17.373 E.07495
G1 X139.938 Y109.234 E.31272
G1 X140.442 Y110.45 E.04368
G1 X141.154 Y110.45 E.02363
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y114.15 E.09966
G1 X107.249 Y148.751 E1.62321
G2 X112.323 Y151.353 I21.651 J-35.979 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X139.439 Y120.882 E.08374
G2 X140.432 Y118.55 I-30.525 J-14.382 E.08413
G1 X141.578 Y118.55 E.03799
G1 X133.9 Y110.872 E.36015
G1 X133.9 Y114.424 E.1178
G1 X139.666 Y108.658 E.27049
; WIPE_START
G1 X138.252 Y110.072 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.386 Y113.406 Z2.4 F36000
G1 X102.328 Y127.52 Z2.4
G1 Z2
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.669 Y148.697 E1.02576
G3 X130.331 Y148.697 I2.331 J1.831 E.17793
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.034 Y138.414 E.31433
G2 X99.749 Y140.899 I2.53 J1.549 E.08564
G1 X98.771 Y141.877 E.0459
G2 X102.744 Y145.58 I38.37 J-37.18 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.68 E.07828
G1 X153.253 Y145.577 E1.12941
G2 X157.226 Y141.874 I-25.275 J-31.101 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.966 Y138.414 I-2.814 J-.936 E.08565
G1 X162.666 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 2.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.543 Y149.972 E.00082
G3 X127.448 Y153.038 I-2.543 J.528 E.17145
G3 X127.847 Y147.907 I.545 J-2.539 E.24752
G3 X130.447 Y149.63 I.153 J2.593 E.111
G1 X130.525 Y149.89 E.00898
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.874 Y148.298 I-2.161 J.453 E.32963
G3 X129.149 Y148.611 I.122 J2.255 E.04093
G3 X130.156 Y149.991 I-1.14 J1.891 E.0539
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13744
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.0493
; WIPE_END
G1 E-.04 F1800
G1 X123.03 Y148.209 Z2.6 F36000
G1 X103.875 Y137.72 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.895 Y137.734 E.0008
G3 X101.992 Y142.494 I-1.346 J2.222 E.24246
G3 X102.391 Y137.363 I.552 J-2.538 E.24715
G3 X103.58 Y137.571 I.158 J2.593 E.04041
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.418 Y137.754 I-1.14 J1.89 E.38526
G3 X103.641 Y138.037 I.122 J2.256 E.03909
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13734
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11463
G1 X104.507 Y138.939 E-.11463
G1 X104.627 Y139.216 E-.11465
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04942
; WIPE_END
G1 E-.04 F1800
G1 X110.87 Y135.106 Z2.6 F36000
G1 X133.506 Y118.419 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02103
G3 X127.886 Y107.753 I-5.109 J-4.412 E.89182
G3 X133.552 Y110.639 I.081 J6.847 E.21938
G1 X133.552 Y118.361 E.25612
G1 X133.543 Y118.372 E.00048
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.897 Y108.145 I-5.156 J-3.721 E.7952
G3 X133.16 Y110.777 I.104 J6.371 E.18795
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X137.146 Y125.042 Z2.6 F36000
G1 X150.996 Y139.107 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.008 Y139.086 E.00081
G3 X153.303 Y137.363 I2.448 J.87 E.10084
G3 X152.904 Y142.494 I.158 J2.593 E.29466
G3 X150.913 Y139.427 I.552 J-2.538 E.13454
G1 X150.981 Y139.165 E.00898
G1 X151.384 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.329 Y137.754 I2.081 J.738 E.07929
G3 X154.604 Y138.067 I.122 J2.255 E.04093
G3 X151.364 Y139.276 I-1.14 J1.89 E.30413
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.1372
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04955
; WIPE_END
G1 E-.04 F1800
G1 X148.138 Y131.764 Z2.6 F36000
G1 X139.908 Y120.717 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89478
G3 X91.645 Y132.117 I-36.355 J-17.622 E3.00054
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.107 J-7.696 E.08797
G3 X128.371 Y101.108 I12.871 J-3.739 E.83614
G3 X140.233 Y109.038 I-.371 J13.392 E.49915
G1 X140.675 Y110.102 E.03821
G1 X142.198 Y110.102 E.05053
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.914 Y120.67 I-24.111 J-9.205 E.0639
G1 X140.412 Y120.519 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.8295
G3 X91.122 Y131.928 I-36.878 J-17.429 E2.83078
G1 X115.586 Y120.52 E.82942
G3 X128.377 Y100.716 I12.423 J-6.009 E.86845
G3 X140.936 Y109.71 I-.398 J13.822 E.50362
G1 X142.59 Y109.71 E.05081
G1 X142.59 Y119.29 E.29437
M73 P51 R11
G1 X140.934 Y119.29 E.05089
G3 X140.437 Y120.465 I-18.558 J-7.161 E.03921
; WIPE_START
M204 S10000
G1 X142.247 Y121.314 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.719 Y120.056 Z2.6 F36000
G1 X132.791 Y119.734 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X133.871 Y118.519 I-5.722 J-6.174 E.05401
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.982 J2.8 E.22043
G1 X142.584 Y151.796 E.43751
G3 X137.939 Y153.291 I-14.862 J-38.207 E.16194
G1 X109.039 Y124.39 E1.3558
G1 X108.183 Y124.79 E.03133
G1 X95.323 Y137.65 E.60328
G3 X92.419 Y132.877 I33.741 J-23.797 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I2.001 J-14.656 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.346 E.12872
G1 X131.377 Y154.405 E.0738
G2 X132.402 Y154.301 I-.972 J-14.718 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.676 Y137.648 I-35.73 J-18.464 E.18546
G1 X147.817 Y124.79 E.60321
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.219 J-39.704 E.16194
G1 X104.09 Y142.47 E.43751
G2 X103.484 Y137.164 I-1.551 J-2.511 E.22145
G1 X122.142 Y118.506 E.87527
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.659 E.21893
G1 X115.503 Y110.756 F36000
G1 F15476.087
G3 X116.066 Y109.23 I12.926 J3.906 E.05401
G1 X122.732 Y102.564 E.31272
G3 X124.865 Y101.837 I6.908 J16.787 E.07479
G1 X131.182 Y108.154 E.29632
G3 X132.006 Y108.642 I-3.882 J7.486 E.03179
G1 X136.253 Y104.395 E.19927
G3 X137.447 Y105.501 I-30.404 J34.003 E.05398
G1 X139.666 Y108.658 F36000
G1 F15476.087
G1 X133.9 Y114.424 E.27049
G1 X133.9 Y110.872 E.1178
G1 X141.578 Y118.55 E.36015
G1 X140.431 Y118.55 E.03804
G3 X139.438 Y120.882 I-28.657 J-10.825 E.08411
G1 X141.727 Y121.949 E.08378
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.574 J-38.576 E.1893
G1 X141.85 Y114.15 E1.62321
G1 X141.85 Y111.146 E.09966
G1 X141.154 Y110.45 E.03263
G1 X140.442 Y110.45 E.02362
G1 X139.937 Y109.234 E.04369
G1 X133.272 Y102.568 E.31271
G2 X131.135 Y101.837 I-6.87 J16.599 E.07495
G1 X124.816 Y108.156 E.29643
G2 X123.992 Y108.64 I2.717 J5.566 E.03174
G1 X119.747 Y104.395 E.19917
G2 X118.556 Y105.504 I8.26 J10.057 E.054
G1 X122.553 Y109.953 F36000
G1 F15476.087
G2 X121.661 Y111.311 I13.224 J9.652 E.0539
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I13.008 J-3.188 E.08977
G1 X148.751 Y148.751 E1.58519
G3 X143.677 Y151.353 I-21.648 J-35.974 E.1893
G1 X114.273 Y121.949 E1.37939
G1 X115.749 Y121.261 E.05401
G1 X153.672 Y127.52 F36000
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.331 Y148.697 E1.02576
G1 X130.3 Y148.66 E.0016
G2 X125.669 Y148.697 I-2.301 J1.836 E.1768
G1 X103.804 Y126.832 E1.02576
G1 X102.328 Y127.52 E.05401
G1 X162.666 Y131.714 F36000
G1 F15476.087
G1 X155.966 Y138.414 E.31433
G3 X156.251 Y140.899 I-2.53 J1.549 E.08565
G1 X157.226 Y141.874 E.04575
G3 X153.253 Y145.577 I-29.25 J-27.4 E.1803
G1 X129.178 Y121.502 E1.12941
G3 X126.825 Y121.499 I-1.165 J-8.683 E.07828
G1 X102.744 Y145.58 E1.12972
G3 X98.771 Y141.877 I34.401 J-40.887 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I2.814 J-.936 E.08564
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 2.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.553 Y149.97 E.00082
G3 X127.831 Y147.908 I-2.545 J.533 E.41837
G3 X129.643 Y148.48 I.185 J2.57 E.06457
G3 X130.456 Y149.627 I-1.635 J2.022 E.04722
G1 X130.527 Y149.889 E.009
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.858 Y148.299 I-2.161 J.452 E.32903
G3 X129.149 Y148.611 I.139 J2.252 E.04143
G3 X130.156 Y149.991 I-1.14 J1.89 E.0539
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13744
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.0493
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.947 Z2.8 F36000
G1 X150.996 Y139.107 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.014 Y139.088 E.00087
G3 X153.287 Y137.364 I2.45 J.87 E.10017
G3 X155.099 Y137.936 I.185 J2.57 E.06457
G3 X150.918 Y139.429 I-1.635 J2.022 E.36549
G1 X150.982 Y139.166 E.00898
G1 X151.384 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.313 Y137.755 I2.08 J.738 E.07878
G3 X154.604 Y138.067 I.139 J2.252 E.04142
G3 X151.365 Y139.276 I-1.14 J1.89 E.30408
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13719
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11464
G1 X152.061 Y138.241 E-.11462
G1 X152.191 Y138.15 E-.06039
G1 X152.307 Y138.067 E-.05426
G1 X152.575 Y137.928 E-.11467
G1 X152.698 Y137.885 E-.04954
; WIPE_END
G1 E-.04 F1800
G1 X147.339 Y132.45 Z2.8 F36000
G1 X133.506 Y118.419 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02103
G3 X127.87 Y107.753 I-5.107 J-4.412 E.89113
G3 X133.552 Y110.639 I.105 J6.829 E.21993
G1 X133.552 Y118.361 E.25612
G1 X133.543 Y118.372 E.00047
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.882 Y108.145 I-5.157 J-3.72 E.79488
G3 X133.16 Y110.777 I.12 J6.37 E.18842
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22946
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X125.388 Y123.759 Z2.8 F36000
G1 X103.875 Y137.72 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X104.187 Y137.936 I-1.337 J2.202 E.0118
G3 X102.375 Y137.364 I-1.635 J2.022 E.4774
G3 X103.581 Y137.568 I.185 J2.57 E.04097
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.402 Y137.755 I-1.14 J1.89 E.38476
G3 X103.641 Y138.037 I.139 J2.252 E.03958
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13736
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11462
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.0494
; WIPE_END
G1 E-.04 F1800
G1 X111.448 Y136.021 Z2.8 F36000
G1 X139.91 Y120.718 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89474
G3 X91.645 Y132.117 I-36.355 J-17.62 E3.00057
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.105 J-7.695 E.08797
G3 X128.364 Y101.108 I12.871 J-3.739 E.8359
G3 X140.231 Y109.034 I-.363 J13.392 E.49923
G1 X140.675 Y110.102 E.03837
G1 X142.198 Y110.102 E.05053
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.916 Y120.67 I-24.544 J-9.356 E.06387
G1 X140.412 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82948
G3 X91.122 Y131.928 I-36.878 J-17.427 E2.83082
G1 X115.586 Y120.52 E.82942
G3 X128.37 Y100.716 I12.422 J-6.009 E.86822
G3 X140.936 Y109.71 I-.391 J13.822 E.50385
G1 X142.59 Y109.71 E.05081
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.437 Y120.465 I-18.053 J-6.934 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.03 Y114.012 Z2.8 F36000
G1 X137.445 Y105.502 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X136.252 Y104.396 I-15.78 J15.833 E.05398
G1 X132.005 Y108.643 E.19921
G2 X131.182 Y108.154 I-17.993 J29.374 E.03177
G1 X124.865 Y101.837 E.29632
G2 X122.732 Y102.564 I4.78 J17.53 E.07479
G1 X116.066 Y109.23 E.31272
G2 X115.503 Y110.756 I12.36 J5.432 E.05401
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21891
G2 X122.142 Y118.506 I7 J1.175 E.18033
G1 X103.484 Y137.164 E.87527
G3 X104.09 Y142.47 I-.945 J2.796 E.22145
G1 X113.416 Y151.796 E.43751
G2 X118.061 Y153.291 I14.863 J-38.209 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.833 J-23.241 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-1.997 J-14.614 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.448 E.12814
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.972 J-14.724 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.649 I36.642 J-19.023 E.18545
G1 X108.183 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.584 Y151.796 I-10.218 J-39.702 E.16194
G1 X151.91 Y142.47 E.43751
G3 X152.516 Y137.164 I1.551 J-2.511 E.22145
G1 X133.871 Y118.519 E.87466
G3 X132.791 Y119.734 I-6.805 J-4.962 E.05401
; WIPE_START
G1 X133.374 Y119.142 E-.31579
G1 X133.871 Y118.519 E-.30276
G1 X134.134 Y118.782 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X126.57 Y119.802 Z2.8 F36000
G1 X115.749 Y121.261 Z2.8
G1 Z2.4
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.677 Y151.353 E1.37939
G2 X148.751 Y148.751 I-16.574 J-38.577 E.1893
G1 X114.962 Y114.962 E1.58516
G2 X115.336 Y117.636 I16.378 J-.929 E.08969
G1 X121.661 Y111.311 E.29673
G3 X122.553 Y109.953 I14.743 J8.706 E.0539
M73 P52 R11
G1 X118.556 Y105.504 F36000
G1 F15476.087
G3 X119.747 Y104.395 I9.4 J8.892 E.054
G1 X123.992 Y108.64 E.19917
G3 X124.816 Y108.156 I3.54 J5.081 E.03174
G1 X131.135 Y101.837 E.29642
G3 X133.272 Y102.568 I-4.719 J17.293 E.07496
G1 X139.937 Y109.233 E.31269
G1 X140.442 Y110.45 E.04371
G1 X141.154 Y110.45 E.02362
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y114.15 E.09966
G1 X107.249 Y148.751 E1.62321
G2 X112.323 Y151.353 I21.651 J-35.979 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X139.439 Y120.883 E.08372
G2 X140.432 Y118.55 I-30.899 J-14.533 E.08413
G1 X141.578 Y118.55 E.03799
G1 X133.9 Y110.872 E.36015
G1 X133.9 Y114.424 E.1178
G1 X139.666 Y108.658 E.27048
; WIPE_START
G1 X138.252 Y110.072 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.386 Y113.407 Z2.8 F36000
G1 X102.328 Y127.52 Z2.8
G1 Z2.4
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.669 Y148.697 E1.02576
G3 X130.331 Y148.697 I2.331 J1.8 E.1784
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.034 Y138.414 E.31433
G2 X99.749 Y140.899 I2.53 J1.549 E.08564
G1 X98.771 Y141.877 E.0459
G2 X102.744 Y145.58 I38.37 J-37.18 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.678 E.07828
G1 X153.253 Y145.577 E1.12941
G2 X157.226 Y141.874 I-25.275 J-31.101 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.966 Y138.414 I-2.815 J-.936 E.08565
G1 X162.666 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 2.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.553 Y149.97 E.00082
G3 X127.815 Y147.909 I-2.545 J.533 E.41784
G3 X129.643 Y148.48 I.201 J2.569 E.0651
G3 X130.456 Y149.627 I-1.635 J2.022 E.04722
G1 X130.527 Y149.889 E.009
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.842 Y148.3 I-2.16 J.452 E.32843
G3 X129.149 Y148.611 I.155 J2.251 E.04192
G3 X130.156 Y149.991 I-1.14 J1.89 E.05389
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13743
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.947 Z3 F36000
G1 X150.996 Y139.107 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.013 Y139.088 E.00086
G3 X153.271 Y137.365 I2.45 J.87 E.09964
G3 X155.099 Y137.936 I.201 J2.569 E.0651
G3 X150.918 Y139.429 I-1.635 J2.022 E.36549
G1 X150.982 Y139.166 E.00898
G1 X151.384 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.297 Y137.756 I2.081 J.738 E.0783
G3 X154.604 Y138.067 I.155 J2.25 E.04192
G3 X151.364 Y139.276 I-1.14 J1.89 E.30414
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.1372
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04955
; WIPE_END
G1 E-.04 F1800
G1 X147.339 Y132.45 Z3 F36000
G1 X133.506 Y118.418 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02103
G3 X127.855 Y107.754 I-5.109 J-4.412 E.89081
G3 X133.552 Y110.639 I.12 J6.828 E.22043
G1 X133.552 Y118.361 E.25612
G1 X133.543 Y118.372 E.00047
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.866 Y108.146 I-5.156 J-3.721 E.79428
G3 X133.16 Y110.777 I.124 J6.392 E.18883
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22946
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X125.388 Y123.759 Z3 F36000
G1 X103.875 Y137.72 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X104.187 Y137.936 I-1.337 J2.203 E.01179
G3 X102.359 Y137.365 I-1.635 J2.022 E.47688
G3 X103.581 Y137.568 I.201 J2.569 E.04151
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.386 Y137.756 I-1.14 J1.89 E.38428
G3 X103.641 Y138.037 I.155 J2.25 E.04007
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13735
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.0494
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z3 F36000
G1 X139.91 Y120.718 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89474
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.108 J-7.696 E.08797
G3 X128.356 Y101.108 I12.871 J-3.739 E.83565
G3 X140.283 Y109.152 I-.371 J13.414 E.50364
G1 X140.673 Y110.102 E.03407
G1 X142.198 Y110.102 E.05059
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.917 Y120.67 I-24.607 J-9.38 E.06386
G1 X140.412 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82947
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.363 Y100.716 I12.422 J-6.009 E.86799
G3 X140.936 Y109.71 I-.377 J13.813 E.5041
G1 X142.59 Y109.71 E.05083
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.465 I-18.075 J-6.942 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.72 Y120.056 Z3 F36000
G1 X132.791 Y119.734 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X133.871 Y118.519 I-5.725 J-6.177 E.05401
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.945 J2.796 E.22145
G1 X142.584 Y151.796 E.43751
G3 X137.939 Y153.291 I-14.862 J-38.207 E.16194
G1 X109.039 Y124.39 E1.3558
G1 X108.183 Y124.79 E.03133
G1 X95.323 Y137.65 E.60328
G3 X92.419 Y132.877 I33.748 J-23.801 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
M73 P52 R10
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I2.001 J-14.656 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.448 E.12814
G1 X131.377 Y154.405 E.0738
G2 X132.402 Y154.301 I-.972 J-14.718 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.676 Y137.648 I-35.73 J-18.464 E.18546
G1 X147.817 Y124.79 E.60321
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.219 J-39.704 E.16194
G1 X104.09 Y142.47 E.43751
G2 X103.484 Y137.164 I-1.551 J-2.511 E.22145
G1 X122.142 Y118.506 E.87527
G3 X121.003 Y113.327 I6.079 J-4.052 E.18002
G1 X116.335 Y108.659 E.21899
G1 X115.503 Y110.756 F36000
G1 F15476.087
G3 X116.066 Y109.23 I12.922 J3.905 E.05401
G1 X122.732 Y102.564 E.31273
G3 X124.865 Y101.837 I6.916 J16.816 E.07479
G1 X131.182 Y108.154 E.29632
G3 X132.005 Y108.643 I-13.659 J23.903 E.03176
G1 X136.252 Y104.396 E.19924
G3 X137.445 Y105.502 I-14.27 J16.597 E.05398
G1 X139.666 Y108.658 F36000
G1 F15476.087
G1 X133.9 Y114.424 E.27048
G1 X133.9 Y110.872 E.1178
G1 X141.578 Y118.55 E.36015
G1 X140.432 Y118.55 E.03799
G3 X139.439 Y120.883 I-32.021 J-12.249 E.08413
G1 X141.727 Y121.949 E.08371
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.574 J-38.576 E.1893
G1 X141.85 Y114.15 E1.62321
G1 X141.85 Y111.146 E.09966
G1 X141.154 Y110.45 E.03263
G1 X140.44 Y110.45 E.02369
G1 X139.937 Y109.233 E.04368
G1 X133.276 Y102.572 E.3125
G2 X131.135 Y101.837 I-6.216 J14.633 E.07515
G1 X124.816 Y108.156 E.29641
G2 X123.992 Y108.64 I2.716 J5.565 E.03174
G1 X119.747 Y104.395 E.19917
G2 X118.555 Y105.502 I8.684 J10.541 E.05401
G1 X122.552 Y109.953 F36000
G1 F15476.087
G2 X121.661 Y111.311 I8.502 J6.552 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.962 Y114.962 I15.94 J-3.593 E.08967
G1 X148.751 Y148.751 E1.58513
G3 X143.677 Y151.353 I-21.648 J-35.974 E.1893
G1 X114.273 Y121.949 E1.37939
G1 X115.749 Y121.261 E.05401
G1 X153.672 Y127.52 F36000
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.331 Y148.697 E1.02576
G1 X130.28 Y148.635 E.00267
G2 X125.669 Y148.697 I-2.281 J1.862 E.17571
G1 X103.804 Y126.832 E1.02576
G1 X102.328 Y127.52 E.05401
G1 X162.666 Y131.714 F36000
G1 F15476.087
G1 X155.966 Y138.414 E.31433
G3 X156.251 Y140.899 I-2.53 J1.549 E.08565
G1 X157.226 Y141.874 E.04575
G3 X153.253 Y145.577 I-29.248 J-27.398 E.1803
G1 X129.178 Y121.502 E1.12941
G3 X126.825 Y121.499 I-1.165 J-8.682 E.07828
G1 X102.744 Y145.58 E1.12972
G3 X98.771 Y141.877 I34.401 J-40.887 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I2.815 J-.936 E.08564
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 2.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.543 Y149.972 E.00082
G3 X127.847 Y153.093 I-2.543 J.528 E.15808
G3 X127.799 Y147.91 I.147 J-2.593 E.25931
G3 X130.447 Y149.63 I.201 J2.59 E.1126
G1 X130.525 Y149.89 E.00898
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.825 Y148.301 I-2.161 J.452 E.32807
G3 X129.149 Y148.611 I.171 J2.25 E.04241
G3 X130.156 Y149.991 I-1.141 J1.89 E.05389
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13744
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X136.263 Y147.939 Z3.2 F36000
G1 X151.012 Y139.062 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.154 Y138.763 E.01096
G3 X153.255 Y137.366 I2.31 J1.195 E.08737
G3 X155.099 Y137.936 I.216 J2.569 E.06563
G3 X151.002 Y139.12 I-1.635 J2.022 E.37612
M73 P53 R10
G1 X151.383 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.281 Y137.757 I2.081 J.738 E.07782
G3 X154.604 Y138.067 I.171 J2.25 E.04241
G3 X151.364 Y139.276 I-1.141 J1.89 E.30414
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13719
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11464
G1 X152.061 Y138.241 E-.11462
G1 X152.164 Y138.168 E-.04819
G1 X152.307 Y138.067 E-.06648
G1 X152.575 Y137.928 E-.11464
G1 X152.698 Y137.885 E-.04956
; WIPE_END
G1 E-.04 F1800
G1 X147.364 Y132.425 Z3.2 F36000
G1 X133.552 Y118.287 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.552 Y118.361 E.00245
G1 X133.11 Y118.914 E.02349
G3 X127.84 Y107.754 I-5.109 J-4.412 E.89032
G3 X133.552 Y110.639 I.127 J6.845 E.22088
G1 X133.552 Y118.227 E.25168
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.851 Y108.146 I-5.156 J-3.721 E.79382
G3 X133.16 Y110.777 I.15 J6.368 E.18935
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X125.388 Y123.759 Z3.2 F36000
G1 X103.875 Y137.72 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X104.187 Y137.936 I-1.338 J2.204 E.0118
G3 X102.343 Y137.366 I-1.635 J2.022 E.47636
G3 X103.581 Y137.568 I.216 J2.569 E.04204
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.37 Y137.757 I-1.141 J1.89 E.3838
G3 X103.641 Y138.037 I.171 J2.25 E.04057
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13736
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.0494
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z3.2 F36000
G1 X139.91 Y120.718 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89474
G3 X91.645 Y132.117 I-36.355 J-17.622 E3.00054
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.101 J-7.693 E.08797
G3 X128.349 Y101.108 I12.871 J-3.739 E.83541
G3 X140.286 Y109.158 I-.363 J13.413 E.50411
G1 X140.673 Y110.102 E.03384
G1 X142.198 Y110.102 E.05059
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.917 Y120.67 I-24.693 J-9.413 E.06386
G1 X140.412 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82947
G3 X91.122 Y131.928 I-36.878 J-17.429 E2.83078
G1 X115.586 Y120.52 E.82942
G3 X128.355 Y100.716 I12.422 J-6.009 E.86777
G3 X140.936 Y109.71 I-.36 J13.799 E.50439
G1 X142.59 Y109.71 E.05083
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.465 I-18.132 J-6.965 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.03 Y114.012 Z3.2 F36000
G1 X137.445 Y105.502 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X136.252 Y104.396 I-15.197 J15.203 E.05398
G1 X132.006 Y108.642 E.19919
G2 X131.182 Y108.154 I-4.706 J6.997 E.03179
G1 X124.865 Y101.837 E.29632
G2 X122.733 Y102.564 I4.793 J17.571 E.07478
G1 X116.066 Y109.23 E.31273
G2 X115.503 Y110.756 I12.355 J5.431 E.05401
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21893
G1 X120.993 Y113.378 E.00176
G2 X122.142 Y118.506 I7.015 J1.121 E.17856
G1 X103.484 Y137.164 E.87527
G3 X104.09 Y142.47 I-.982 J2.8 E.22044
G1 X113.416 Y151.796 E.43751
G2 X118.061 Y153.291 I14.863 J-38.209 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.829 J-23.239 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-2.001 J-14.65 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.335 E.12879
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.972 J-14.716 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.649 I36.641 J-19.022 E.18545
G1 X108.183 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.587 Y151.793 I-10.077 J-39.216 E.16207
G1 X151.91 Y142.47 E.43736
G3 X152.516 Y137.164 I1.551 J-2.511 E.22147
G1 X133.871 Y118.519 E.87466
G3 X132.791 Y119.734 I-6.806 J-4.963 E.05401
; WIPE_START
G1 X133.374 Y119.142 E-.31579
G1 X133.871 Y118.519 E-.30276
G1 X134.134 Y118.782 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X126.57 Y119.802 Z3.2 F36000
G1 X115.749 Y121.261 Z3.2
G1 Z2.8
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.673 Y151.349 E1.37919
G2 X148.749 Y148.749 I-15.695 J-36.895 E.18934
G1 X114.961 Y114.961 E1.58506
G2 X115.336 Y117.636 I13.379 J-.512 E.08976
G1 X121.665 Y111.304 E.29698
G3 X122.552 Y109.953 I9.443 J5.239 E.05366
G1 X118.557 Y105.504 F36000
G1 F15476.087
G3 X119.747 Y104.395 I9.306 J8.787 E.054
G1 X123.992 Y108.64 E.19917
G3 X124.816 Y108.156 I3.541 J5.082 E.03174
G1 X131.134 Y101.838 E.2964
G3 X133.276 Y102.572 I-4.019 J15.205 E.07517
G1 X139.937 Y109.233 E.31247
G1 X140.44 Y110.45 E.04369
G1 X141.154 Y110.45 E.02369
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y114.15 E.09966
G1 X107.249 Y148.751 E1.62321
G2 X112.323 Y151.353 I21.649 J-35.974 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X139.44 Y120.883 E.0837
G2 X140.432 Y118.55 I-31.193 J-14.648 E.08413
G1 X141.578 Y118.55 E.03799
G1 X133.9 Y110.872 E.36015
G1 X133.9 Y114.424 E.1178
G1 X139.666 Y108.658 E.27047
; WIPE_START
G1 X138.252 Y110.072 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.386 Y113.407 Z3.2 F36000
G1 X102.328 Y127.52 Z3.2
G1 Z2.8
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.669 Y148.697 E1.02576
G3 X130.331 Y148.697 I2.331 J1.84 E.1778
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.015 Y138.446 E.31462
G2 X99.749 Y140.899 I2.55 J1.517 E.0844
G1 X98.771 Y141.877 E.0459
G2 X102.744 Y145.58 I38.37 J-37.18 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.68 E.07828
G1 X153.253 Y145.577 E1.1294
G2 X157.226 Y141.874 I-25.273 J-31.099 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.966 Y138.414 I-2.815 J-.936 E.08565
G1 X162.666 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 3
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.553 Y149.97 E.00082
G3 X127.783 Y147.911 I-2.545 J.532 E.41682
G3 X129.643 Y148.48 I.231 J2.569 E.06617
G3 X130.456 Y149.627 I-1.636 J2.022 E.04722
G1 X130.527 Y149.889 E.009
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.809 Y148.303 I-2.161 J.452 E.3276
G3 X129.149 Y148.611 I.186 J2.251 E.04291
G3 X130.156 Y149.991 I-1.141 J1.89 E.05389
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13743
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.948 Z3.4 F36000
G1 X150.996 Y139.107 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.003 Y139.084 E.0008
G3 X153.239 Y137.367 I2.447 J.872 E.09883
G3 X153.319 Y142.55 I.217 J2.589 E.28246
G3 X150.907 Y139.426 I.131 J-2.594 E.14868
G1 X150.98 Y139.165 E.00899
G1 X151.383 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.265 Y137.758 I2.081 J.738 E.07734
G3 X154.604 Y138.067 I.186 J2.251 E.0429
G3 X151.363 Y139.276 I-1.141 J1.89 E.30415
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.1372
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.151 Y138.177 E-.15644
G1 X152.307 Y138.067 E-.07258
G1 X152.575 Y137.928 E-.11465
G1 X152.699 Y137.884 E-.04983
; WIPE_END
G1 E-.04 F1800
G1 X147.34 Y132.449 Z3.4 F36000
G1 X133.506 Y118.418 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02105
G3 X127.825 Y107.755 I-5.109 J-4.412 E.88981
G3 X133.552 Y110.639 I.143 J6.844 E.22138
G1 X133.552 Y118.361 E.25612
G1 X133.544 Y118.371 E.00046
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.836 Y108.147 I-5.156 J-3.721 E.79335
G3 X133.16 Y110.777 I.157 J6.385 E.18977
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X125.388 Y123.759 Z3.4 F36000
G1 X103.875 Y137.72 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.896 Y137.734 E.0008
G3 X102.407 Y142.55 I-1.346 J2.222 E.22855
G3 X102.327 Y137.367 I.138 J-2.594 E.25893
G3 X103.58 Y137.571 I.223 J2.589 E.04255
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.354 Y137.758 I-1.141 J1.89 E.38331
G3 X103.641 Y138.037 I.186 J2.251 E.04106
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13736
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11462
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.0494
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z3.4 F36000
G1 X139.91 Y120.718 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89473
G3 X91.645 Y132.117 I-36.355 J-17.622 E3.00054
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.105 J-7.695 E.08798
G3 X128.342 Y101.108 I12.871 J-3.739 E.83516
G3 X140.289 Y109.165 I-.356 J13.414 E.50459
G1 X140.673 Y110.102 E.0336
G1 X142.198 Y110.102 E.05059
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.917 Y120.67 I-24.78 J-9.447 E.06386
G1 X140.412 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82947
G3 X91.122 Y131.928 I-36.878 J-17.429 E2.83078
G1 X115.586 Y120.52 E.82942
G3 X128.348 Y100.716 I12.422 J-6.009 E.86754
G3 X140.936 Y109.71 I-.361 J13.81 E.50456
G1 X142.59 Y109.71 E.05083
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
M73 P54 R10
G3 X140.438 Y120.465 I-18.138 J-6.967 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.72 Y120.057 Z3.4 F36000
G1 X132.791 Y119.734 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X133.871 Y118.519 I-5.724 J-6.176 E.05401
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.981 J2.8 E.22045
G1 X142.587 Y151.793 E.43736
G3 X137.939 Y153.291 I-14.724 J-37.717 E.16207
G1 X109.039 Y124.39 E1.3558
G1 X108.182 Y124.79 E.03133
G1 X95.323 Y137.649 E.60328
G3 X92.419 Y132.877 I33.738 J-23.795 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I1.998 J-14.62 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.448 E.12814
G1 X131.377 Y154.405 E.0738
G2 X132.402 Y154.301 I-.972 J-14.718 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.676 Y137.648 I-35.73 J-18.464 E.18546
G1 X147.817 Y124.79 E.60321
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.219 J-39.704 E.16194
G1 X104.09 Y142.47 E.43751
G2 X103.484 Y137.164 I-1.551 J-2.511 E.22145
G1 X122.142 Y118.506 E.87527
G3 X121.002 Y113.326 I6.09 J-4.056 E.18006
G1 X116.335 Y108.659 E.21891
G1 X115.503 Y110.756 F36000
G1 F15476.087
G3 X116.066 Y109.23 I12.924 J3.907 E.05401
G1 X122.733 Y102.564 E.31273
G3 X124.865 Y101.837 I6.925 J16.843 E.07478
G1 X131.182 Y108.154 E.29632
G3 X132.006 Y108.642 I-3.879 J7.48 E.03179
G1 X136.252 Y104.396 E.19919
G3 X137.445 Y105.502 I-13.71 J15.993 E.05398
G1 X139.666 Y108.658 F36000
G1 F15476.087
G1 X133.9 Y114.424 E.27047
G1 X133.9 Y110.872 E.1178
G1 X141.578 Y118.55 E.36015
G1 X140.432 Y118.55 E.03799
G3 X139.44 Y120.883 I-32.367 J-12.387 E.08413
G1 X141.727 Y121.949 E.08369
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.574 J-38.576 E.1893
G1 X141.85 Y114.15 E1.62321
G1 X141.85 Y111.146 E.09966
G1 X141.154 Y110.45 E.03263
G1 X140.44 Y110.45 E.02369
G1 X139.936 Y109.233 E.04371
G1 X133.277 Y102.573 E.31243
G2 X131.134 Y101.838 I-6.106 J14.309 E.0752
G1 X124.816 Y108.156 E.2964
G2 X123.992 Y108.64 I2.718 J5.569 E.03174
G1 X119.747 Y104.395 E.19916
G2 X118.555 Y105.502 I8.675 J10.531 E.05401
G1 X122.552 Y109.953 F36000
G1 F15476.087
G2 X121.661 Y111.311 I8.507 J6.555 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.963 Y114.963 I15.814 J-3.57 E.08964
G1 X148.749 Y148.749 E1.58497
G3 X143.673 Y151.349 I-20.77 J-34.295 E.18934
G1 X114.273 Y121.949 E1.37919
G1 X115.749 Y121.261 E.05401
G1 X153.672 Y127.52 F36000
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.331 Y148.697 E1.02576
G1 X130.26 Y148.61 E.00373
G2 X125.669 Y148.697 I-2.26 J1.889 E.17463
G1 X103.804 Y126.832 E1.02576
G1 X102.328 Y127.52 E.05401
G1 X162.666 Y131.714 F36000
G1 F15476.087
G1 X155.966 Y138.414 E.31433
G3 X156.251 Y140.899 I-2.53 J1.549 E.08565
G1 X157.226 Y141.874 E.04575
G3 X153.253 Y145.577 I-29.249 J-27.399 E.1803
G1 X129.178 Y121.502 E1.12941
G3 X126.825 Y121.499 I-1.165 J-8.682 E.07828
G1 X102.744 Y145.58 E1.12972
G3 X98.771 Y141.877 I34.401 J-40.887 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I2.814 J-.936 E.08564
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 3.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.554 Y149.969 E.00083
G3 X127.767 Y147.912 I-2.545 J.532 E.41627
G3 X129.353 Y148.276 I.227 J2.652 E.05485
G3 X130.457 Y149.627 I-1.344 J2.226 E.05903
G1 X130.527 Y149.889 E.00901
G1 X130.17 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.793 Y148.304 I-2.161 J.452 E.32709
G3 X128.881 Y148.473 I.223 J2.152 E.03418
G3 X130.157 Y149.991 I-.872 J2.029 E.0632
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13746
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11462
G1 X130.045 Y151.327 E-.15036
G1 X129.963 Y151.517 E-.07867
G1 X129.806 Y151.775 E-.11467
G1 X129.724 Y151.876 E-.04955
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.948 Z3.6 F36000
G1 X150.996 Y139.107 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.014 Y139.088 E.00087
G3 X153.223 Y137.368 I2.451 J.87 E.09805
G3 X154.809 Y137.731 I.228 J2.652 E.05485
G3 X150.918 Y139.429 I-1.344 J2.226 E.37733
G1 X150.982 Y139.166 E.00898
G1 X151.383 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.249 Y137.759 I2.081 J.738 E.07683
G3 X154.336 Y137.928 I.223 J2.152 E.03418
G3 X151.364 Y139.276 I-.872 J2.029 E.31346
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13719
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11464
G1 X152.061 Y138.241 E-.11463
G1 X152.307 Y138.067 E-.11465
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04956
; WIPE_END
G1 E-.04 F1800
G1 X147.34 Y132.45 Z3.6 F36000
G1 X133.506 Y118.418 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02106
G3 X127.81 Y107.755 I-5.108 J-4.412 E.88923
G3 X133.552 Y110.639 I.158 J6.844 E.22188
G1 X133.552 Y118.361 E.25612
G1 X133.544 Y118.371 E.00045
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.821 Y108.147 I-5.157 J-3.72 E.79303
G3 X133.16 Y110.777 I.173 J6.384 E.19024
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X125.388 Y123.759 Z3.6 F36000
G1 X103.875 Y137.72 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X102.311 Y137.368 I-1.344 J2.226 E.48713
G3 X103.58 Y137.571 I.227 J2.652 E.04306
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.066 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.338 Y137.759 I-1.14 J1.891 E.38286
G3 X103.425 Y137.928 I.222 J2.152 E.03418
G3 X103.642 Y138.036 I-.872 J2.029 E.00744
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13738
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04937
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.02 Z3.6 F36000
G1 X139.91 Y120.718 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89473
G3 X91.645 Y132.117 I-36.355 J-17.622 E3.00054
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.098 J-7.692 E.08797
G3 X128.334 Y101.108 I12.871 J-3.739 E.83492
G3 X140.291 Y109.17 I-.334 J13.392 E.50514
G1 X140.673 Y110.102 E.0334
G1 X142.198 Y110.102 E.05059
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.917 Y120.67 I-24.841 J-9.471 E.06386
G1 X140.412 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82947
G3 X91.122 Y131.928 I-36.878 J-17.429 E2.83078
G1 X115.586 Y120.52 E.82942
G3 X128.341 Y100.716 I12.422 J-6.009 E.86732
G3 X140.936 Y109.71 I-.36 J13.82 E.50474
G1 X142.59 Y109.71 E.05083
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.465 I-18.167 J-6.978 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.03 Y114.012 Z3.6 F36000
G1 X137.445 Y105.502 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X136.252 Y104.396 I-14.629 J14.591 E.05398
G1 X132.006 Y108.642 E.19919
G2 X131.182 Y108.154 I-4.704 J6.994 E.03179
G1 X124.865 Y101.837 E.29632
G2 X122.733 Y102.563 I4.8 J17.594 E.07478
G1 X116.066 Y109.23 E.31273
G2 X115.503 Y110.756 I12.355 J5.431 E.05401
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21893
G1 X120.989 Y113.408 E.00277
G2 X122.142 Y118.506 I7.019 J1.092 E.17755
G1 X103.484 Y137.164 E.87527
G3 X104.09 Y142.47 I-.982 J2.8 E.22044
G1 X113.416 Y151.796 E.43751
G2 X118.061 Y153.291 I14.863 J-38.209 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.831 J-23.24 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-1.997 J-14.614 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.448 E.12814
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.972 J-14.724 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06476
G2 X95.323 Y137.649 I36.642 J-19.023 E.18545
G1 X108.182 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.35579
G2 X142.587 Y151.793 I-10.077 J-39.216 E.16207
G1 X151.91 Y142.47 E.43736
G3 X152.516 Y137.164 I1.588 J-2.506 E.22044
G1 X133.871 Y118.519 E.87466
G3 X132.791 Y119.734 I-6.804 J-4.961 E.05401
; WIPE_START
G1 X133.374 Y119.142 E-.31572
G1 X133.871 Y118.519 E-.30283
G1 X134.134 Y118.782 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X126.57 Y119.802 Z3.6 F36000
G1 X115.749 Y121.261 Z3.6
G1 Z3.2
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.673 Y151.349 E1.37919
G2 X148.749 Y148.749 I-15.695 J-36.896 E.18934
G1 X114.961 Y114.961 E1.58506
G2 X115.336 Y117.636 I13.38 J-.512 E.08976
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.397 J5.197 E.05392
G1 X118.555 Y105.502 F36000
G1 F15476.087
G3 X119.747 Y104.395 I9.859 J9.416 E.05401
G1 X123.992 Y108.64 E.19916
M73 P55 R10
G3 X124.816 Y108.156 I3.544 J5.087 E.03174
G1 X131.134 Y101.838 E.29638
G3 X133.277 Y102.573 I-3.907 J14.879 E.07522
G1 X139.936 Y109.232 E.3124
G1 X140.44 Y110.45 E.04372
G1 X141.154 Y110.45 E.02369
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y114.15 E.09966
G1 X107.249 Y148.751 E1.62321
G2 X112.323 Y151.353 I21.649 J-35.974 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X139.44 Y120.883 E.08369
G2 X140.432 Y118.55 I-31.473 J-14.759 E.08413
G1 X141.578 Y118.55 E.03799
G1 X133.9 Y110.872 E.36015
G1 X133.9 Y114.424 E.1178
G1 X139.666 Y108.658 E.27047
; WIPE_START
G1 X138.251 Y110.073 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.386 Y113.407 Z3.6 F36000
G1 X102.328 Y127.52 Z3.6
G1 Z3.2
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.669 Y148.697 E1.02576
G3 X130.331 Y148.697 I2.331 J1.803 E.17836
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.034 Y138.414 E.31433
G1 X99.998 Y138.473 E.00231
G2 X99.749 Y140.899 I2.57 J1.489 E.08334
G1 X98.771 Y141.877 E.0459
G2 X102.744 Y145.58 I38.37 J-37.18 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.678 E.07828
G1 X153.253 Y145.577 E1.12941
G2 X157.226 Y141.874 I-25.273 J-31.099 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.966 Y138.414 I-2.814 J-.936 E.08565
G1 X162.666 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 3.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.544 Y149.971 E.00081
G3 X127.895 Y153.096 I-2.544 J.529 E.15654
G3 X126.869 Y152.839 I.033 J-2.308 E.03539
G3 X127.751 Y147.914 I1.132 J-2.339 E.22363
G3 X129.131 Y148.161 I.245 J2.614 E.04708
G3 X130.448 Y149.63 I-1.131 J2.339 E.06715
G1 X130.525 Y149.889 E.00898
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.777 Y148.305 I-2.161 J.451 E.32656
G3 X128.881 Y148.473 I.236 J2.156 E.03468
G3 X130.156 Y149.991 I-.873 J2.028 E.06319
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13744
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.0493
; WIPE_END
G1 E-.04 F1800
G1 X123.03 Y148.209 Z3.8 F36000
G1 X103.875 Y137.72 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.894 Y137.736 E.00081
G3 X102.439 Y142.552 I-1.351 J2.22 E.22712
G3 X102.295 Y137.369 I.105 J-2.596 E.25902
G3 X103.579 Y137.573 I.248 J2.586 E.0436
G1 X103.822 Y137.694 E.00899
G1 X103.693 Y138.066 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.322 Y137.761 I-1.141 J1.889 E.38218
G3 X103.425 Y137.928 I.236 J2.157 E.03468
G3 X103.641 Y138.036 I-.873 J2.027 E.00744
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13738
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11463
G1 X104.507 Y138.939 E-.11463
G1 X104.627 Y139.216 E-.11465
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04939
; WIPE_END
G1 E-.04 F1800
G1 X110.87 Y135.106 Z3.8 F36000
G1 X133.506 Y118.418 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02106
G3 X127.795 Y107.756 I-5.109 J-4.412 E.88879
G3 X133.552 Y110.639 I.173 J6.843 E.22239
G1 X133.552 Y118.361 E.25612
G1 X133.544 Y118.371 E.00044
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.806 Y108.148 I-5.156 J-3.72 E.79248
G3 X133.16 Y110.777 I.196 J6.367 E.19075
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22946
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X137.157 Y125.032 Z3.8 F36000
G1 X151.018 Y139.052 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.2 Y138.669 E.01409
G3 X153.207 Y137.369 I2.257 J1.287 E.0824
G3 X153.351 Y142.552 I.249 J2.586 E.28256
G3 X151 Y139.11 I.106 J-2.596 E.16047
G1 X151.383 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.233 Y137.761 I2.081 J.736 E.07636
G3 X154.337 Y137.928 I.236 J2.157 E.03468
G3 X151.364 Y139.276 I-.873 J2.027 E.31325
; WIPE_START
M204 S10000
G1 X151.534 Y138.872 E-.16667
G1 X151.65 Y138.681 E-.0848
G1 X151.84 Y138.447 E-.11462
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11467
G1 X152.699 Y137.884 E-.04994
; WIPE_END
G1 E-.04 F1800
G1 X148.139 Y131.764 Z3.8 F36000
G1 X139.91 Y120.718 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89473
G3 X91.645 Y132.117 I-36.355 J-17.622 E3.00054
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.098 J-7.692 E.08798
G3 X128.327 Y101.108 I12.867 J-3.742 E.83475
G3 X140.293 Y109.176 I-.326 J13.392 E.50559
G1 X140.673 Y110.102 E.03319
G1 X142.198 Y110.102 E.0506
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.917 Y120.67 I-24.942 J-9.511 E.06385
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82947
G3 X91.122 Y131.928 I-36.878 J-17.429 E2.83078
G1 X115.586 Y120.52 E.82942
G3 X128.333 Y100.715 I12.424 J-6.008 E.86705
G3 X140.936 Y109.71 I-.352 J13.82 E.50496
G1 X142.59 Y109.71 E.05083
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.465 I-18.204 J-6.993 E.03921
; WIPE_START
M204 S10000
G1 X142.248 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.72 Y120.057 Z3.8 F36000
G1 X132.791 Y119.734 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X133.871 Y118.519 I-5.726 J-6.178 E.05401
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.945 J2.796 E.22145
G1 X142.587 Y151.793 E.43736
G3 X137.939 Y153.291 I-14.724 J-37.717 E.16207
G1 X109.039 Y124.39 E1.3558
G1 X108.182 Y124.79 E.03133
G1 X95.323 Y137.65 E.60328
G3 X92.419 Y132.877 I33.745 J-23.799 E.18545
G1 X93.8 Y131.496 E.06476
G1 X98.569 Y129.273 E.17455
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I1.998 J-14.62 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.445 E.12815
G1 X131.377 Y154.405 E.0738
G2 X132.402 Y154.301 I-.972 J-14.718 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.676 Y137.648 I-35.735 J-18.467 E.18546
G1 X147.817 Y124.79 E.60321
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.219 J-39.705 E.16194
G1 X104.09 Y142.47 E.43751
G2 X103.484 Y137.164 I-1.551 J-2.511 E.22145
G1 X122.142 Y118.506 E.87527
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.659 E.21894
G1 X115.503 Y110.756 F36000
G1 F15476.087
G3 X116.066 Y109.23 I12.909 J3.902 E.05401
G1 X122.733 Y102.563 E.31273
G3 X124.865 Y101.837 I6.934 J16.874 E.07477
G1 X131.182 Y108.154 E.29632
G3 X132.006 Y108.642 I-3.882 J7.486 E.03179
G1 X136.252 Y104.397 E.19918
G3 X137.445 Y105.502 I-13.193 J15.435 E.05398
G1 X139.666 Y108.658 F36000
G1 F15476.087
G1 X133.9 Y114.424 E.27046
G1 X133.9 Y110.872 E.1178
G1 X141.578 Y118.55 E.36015
G1 X140.432 Y118.55 E.03799
G3 X139.44 Y120.883 I-32.653 J-12.5 E.08413
G1 X141.727 Y121.949 E.08368
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.574 J-38.576 E.1893
G1 X141.85 Y114.15 E1.62321
G1 X141.85 Y111.146 E.09966
G1 X141.154 Y110.45 E.03263
G1 X140.44 Y110.45 E.02369
G1 X139.936 Y109.232 E.04373
G1 X133.277 Y102.574 E.31237
G2 X131.134 Y101.838 I-5.996 J13.985 E.07524
G1 X124.816 Y108.156 E.29638
G2 X123.992 Y108.64 I2.716 J5.565 E.03174
G1 X119.747 Y104.395 E.19916
G2 X118.555 Y105.502 I8.666 J10.523 E.05401
G1 X122.552 Y109.953 F36000
G1 F15476.087
G2 X121.661 Y111.311 I8.511 J6.557 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.964 Y114.964 I15.694 J-3.549 E.08961
G1 X148.749 Y148.749 E1.58493
G3 X143.673 Y151.349 I-20.772 J-34.298 E.18934
G1 X114.273 Y121.949 E1.37919
G1 X115.749 Y121.261 E.05401
G1 X153.672 Y127.52 F36000
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.331 Y148.697 E1.02577
G2 X125.669 Y148.697 I-2.331 J1.848 E.17768
G1 X103.804 Y126.832 E1.02576
G1 X102.328 Y127.52 E.05401
G1 X162.666 Y131.714 F36000
G1 F15476.087
G1 X155.966 Y138.414 E.31433
G3 X156.251 Y140.899 I-2.53 J1.549 E.08565
G1 X157.226 Y141.874 E.04575
G3 X153.253 Y145.577 I-29.249 J-27.399 E.1803
G1 X129.178 Y121.502 E1.1294
G3 X126.825 Y121.499 I-1.165 J-8.683 E.07828
G1 X102.744 Y145.58 E1.12972
G3 X98.771 Y141.877 I34.401 J-40.887 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I2.814 J-.936 E.08564
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 3.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.553 Y149.97 E.00082
G3 X127.735 Y147.915 I-2.546 J.531 E.41522
G3 X129.353 Y148.276 I.257 J2.658 E.05592
G3 X130.456 Y149.627 I-1.346 J2.225 E.05902
G1 X130.527 Y149.889 E.009
G1 X130.17 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.761 Y148.306 I-2.162 J.451 E.32606
G3 X128.596 Y148.372 I.232 J2.396 E.02587
G3 X130.157 Y149.991 I-.587 J2.129 E.07251
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13746
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11465
G1 X129.806 Y151.775 E-.11462
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.947 Z4 F36000
G1 X150.996 Y139.107 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.011 Y139.087 E.00084
G3 X153.19 Y137.371 I2.452 J.871 E.09706
G3 X154.809 Y137.731 I.257 J2.657 E.05592
G3 X150.916 Y139.428 I-1.346 J2.227 E.37748
G1 X150.982 Y139.165 E.00898
G1 X151.383 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.217 Y137.762 I2.082 J.737 E.07588
G3 X154.052 Y137.827 I.232 J2.396 E.02587
G3 X151.364 Y139.276 I-.588 J2.129 E.32269
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13719
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11464
G1 X152.112 Y138.205 E-.13822
G1 X152.307 Y138.067 E-.09087
G1 X152.575 Y137.928 E-.11466
G1 X152.699 Y137.885 E-.04973
; WIPE_END
G1 E-.04 F1800
G1 X147.34 Y132.449 Z4 F36000
G1 X133.506 Y118.418 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02106
G3 X127.779 Y107.756 I-5.109 J-4.412 E.88829
G3 X133.552 Y110.639 I.198 J6.824 E.22294
M73 P56 R10
G1 X133.552 Y118.361 E.25613
G1 X133.544 Y118.371 E.00044
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.791 Y108.148 I-5.156 J-3.721 E.79198
G3 X133.16 Y110.777 I.2 J6.389 E.19116
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X125.388 Y123.759 Z4 F36000
G1 X103.875 Y137.72 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X102.279 Y137.371 I-1.346 J2.225 E.48606
G3 X103.58 Y137.571 I.257 J2.657 E.04413
G1 X103.822 Y137.693 E.00899
G1 X103.694 Y138.065 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.306 Y137.762 I-1.141 J1.891 E.38185
G3 X103.141 Y137.827 I.232 J2.396 E.02587
G3 X103.642 Y138.035 I-.588 J2.129 E.01672
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.1374
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11462
G1 X104.708 Y139.506 E-.11466
G1 X104.726 Y139.635 E-.04936
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.02 Z4 F36000
G1 X139.91 Y120.718 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89473
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.101 J-7.694 E.08798
G3 X128.32 Y101.107 I12.868 J-3.74 E.83447
G3 X140.296 Y109.182 I-.319 J13.392 E.50605
G1 X140.673 Y110.102 E.03296
G1 X142.198 Y110.102 E.0506
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.917 Y120.67 I-25.016 J-9.541 E.06385
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82947
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.326 Y100.715 I12.422 J-6.009 E.86686
G3 X140.936 Y109.71 I-.345 J13.82 E.50518
G1 X142.59 Y109.71 E.05083
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.465 I-18.231 J-7.004 E.03921
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.03 Y114.012 Z4 F36000
G1 X137.445 Y105.502 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X136.251 Y104.397 I-14.137 J14.06 E.05398
G1 X132.006 Y108.642 E.19918
G1 X131.915 Y108.582 E.00361
G2 X131.182 Y108.154 I-4.668 J7.154 E.02818
G1 X124.865 Y101.837 E.29632
G2 X122.733 Y102.563 I4.813 J17.637 E.07477
G1 X116.066 Y109.23 E.31274
G2 X115.503 Y110.756 I12.355 J5.432 E.05401
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21894
G1 X120.984 Y113.438 E.00377
G2 X122.142 Y118.506 I7.258 J1.008 E.17629
G1 X103.484 Y137.164 E.87527
G3 X104.09 Y142.47 I-.945 J2.796 E.22145
G1 X113.416 Y151.796 E.43751
G2 X118.061 Y153.291 I14.863 J-38.209 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.833 J-23.241 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-2.001 J-14.65 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.448 E.12814
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.972 J-14.724 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.649 I36.646 J-19.025 E.18545
G1 X108.182 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.587 Y151.793 I-10.077 J-39.216 E.16207
G1 X151.91 Y142.47 E.43736
G3 X152.516 Y137.164 I1.551 J-2.511 E.22145
G1 X133.871 Y118.519 E.87466
G3 X132.791 Y119.734 I-6.806 J-4.963 E.05401
; WIPE_START
G1 X133.374 Y119.142 E-.31579
G1 X133.871 Y118.519 E-.30276
G1 X134.134 Y118.782 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X126.57 Y119.802 Z4 F36000
G1 X115.749 Y121.261 Z4
G1 Z3.6
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.673 Y151.349 E1.37919
G2 X148.749 Y148.749 I-15.695 J-36.896 E.18934
G1 X114.964 Y114.964 E1.58491
G2 X115.336 Y117.636 I16.005 J-.866 E.0896
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.399 J5.198 E.05392
G1 X118.555 Y105.502 F36000
G1 F15476.087
G3 X119.747 Y104.395 I9.843 J9.401 E.05401
G1 X123.992 Y108.64 E.19916
G3 X124.816 Y108.156 I3.541 J5.082 E.03174
G1 X131.134 Y101.838 E.29637
G3 X133.278 Y102.574 I-3.801 J14.573 E.07527
G1 X139.936 Y109.232 E.31233
G1 X140.44 Y110.45 E.04374
G1 X141.154 Y110.45 E.02369
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y114.15 E.09966
G1 X107.249 Y148.751 E1.62321
G2 X112.323 Y151.353 I21.651 J-35.979 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X139.441 Y120.883 E.08367
G2 X140.432 Y118.55 I-31.801 J-14.89 E.08413
G1 X141.578 Y118.55 E.038
G1 X133.9 Y110.872 E.36015
G1 X133.9 Y114.424 E.1178
G1 X139.666 Y108.659 E.27046
; WIPE_START
G1 X138.251 Y110.073 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.386 Y113.407 Z4 F36000
G1 X102.328 Y127.52 Z4
G1 Z3.6
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.669 Y148.697 E1.02576
G3 X130.331 Y148.697 I2.331 J1.85 E.17765
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.034 Y138.414 E.31433
G2 X99.749 Y140.899 I2.53 J1.549 E.08564
G1 X98.771 Y141.877 E.0459
G2 X102.744 Y145.58 I38.37 J-37.18 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.68 E.07828
G1 X153.253 Y145.577 E1.1294
G2 X157.226 Y141.874 I-25.273 J-31.099 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.966 Y138.414 I-2.814 J-.936 E.08565
G1 X162.666 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 3.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.543 Y149.972 E.00082
G3 X127.927 Y153.098 I-2.545 J.528 E.15545
G3 X127.719 Y147.916 I.075 J-2.599 E.25899
G3 X130.447 Y149.63 I.279 J2.584 E.1153
G1 X130.525 Y149.89 E.00898
G1 X130.168 Y150.05 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.745 Y148.307 I-2.161 J.449 E.32546
G3 X128.596 Y148.372 I.245 J2.412 E.02636
G3 X130.155 Y149.991 I-.589 J2.127 E.07247
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13741
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11462
G1 X130.083 Y151.24 E-.11467
G1 X129.963 Y151.517 E-.11461
G1 X129.806 Y151.775 E-.11467
G1 X129.724 Y151.875 E-.04935
; WIPE_END
G1 E-.04 F1800
G1 X123.03 Y148.209 Z4.2 F36000
G1 X103.875 Y137.72 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.00081
G3 X102.263 Y137.372 I-1.345 J2.225 E.48532
G3 X103.581 Y137.568 I.295 J2.547 E.04474
G1 X103.822 Y137.693 E.009
G1 X103.694 Y138.066 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.29 Y137.763 I-1.142 J1.89 E.38136
G3 X103.141 Y137.827 I.245 J2.411 E.02636
G3 X103.642 Y138.035 I-.589 J2.128 E.01672
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13739
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11463
G1 X104.507 Y138.939 E-.11462
G1 X104.627 Y139.216 E-.11468
G1 X104.708 Y139.506 E-.11463
G1 X104.726 Y139.635 E-.04937
; WIPE_END
G1 E-.04 F1800
G1 X110.86 Y135.093 Z4.2 F36000
G1 X133.552 Y118.287 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.552 Y118.361 E.00243
G1 X133.11 Y118.914 E.02349
G3 X127.764 Y107.757 I-5.109 J-4.412 E.88777
G3 X133.552 Y110.639 I.204 J6.842 E.22339
G1 X133.552 Y118.227 E.25171
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.775 Y108.148 I-5.157 J-3.72 E.79164
G3 X133.16 Y110.777 I.226 J6.366 E.19168
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X137.146 Y125.042 Z4.2 F36000
G1 X150.996 Y139.107 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.012 Y139.087 E.00085
G3 X153.174 Y137.372 I2.451 J.869 E.09652
G3 X154.493 Y137.568 I.295 J2.547 E.04473
G3 X150.917 Y139.428 I-1.029 J2.388 E.3891
G1 X150.982 Y139.166 E.00898
G1 X151.382 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.201 Y137.763 I2.081 J.736 E.07543
G3 X154.052 Y137.827 I.245 J2.411 E.02636
G3 X151.363 Y139.276 I-.589 J2.127 E.32249
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13724
G1 X151.65 Y138.681 E-.11461
G1 X151.84 Y138.447 E-.11467
G1 X152.099 Y138.214 E-.13216
G1 X152.307 Y138.067 E-.09696
G1 X152.575 Y137.928 E-.1147
G1 X152.698 Y137.885 E-.04966
; WIPE_END
G1 E-.04 F1800
G1 X148.139 Y131.764 Z4.2 F36000
G1 X139.91 Y120.718 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89472
G3 X91.645 Y132.117 I-36.355 J-17.622 E3.00054
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.109 J-7.697 E.08798
G3 X128.312 Y101.107 I12.87 J-3.739 E.83419
G3 X140.299 Y109.189 I-.312 J13.392 E.50651
G1 X140.673 Y110.102 E.03274
G1 X142.198 Y110.102 E.0506
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.918 Y120.67 I-25.071 J-9.561 E.06385
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82946
M73 P56 R9
G3 X91.122 Y131.928 I-36.878 J-17.429 E2.83078
G1 X115.586 Y120.52 E.82942
G3 X128.319 Y100.715 I12.424 J-6.008 E.8666
G3 X140.936 Y109.71 I-.338 J13.82 E.50541
G1 X142.59 Y109.71 E.05083
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.465 I-18.24 J-7.006 E.03921
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.721 Y120.057 Z4.2 F36000
M73 P57 R9
G1 X132.791 Y119.734 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X133.871 Y118.519 I-5.726 J-6.178 E.05401
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.945 J2.796 E.22145
G1 X142.587 Y151.793 E.43736
G3 X137.939 Y153.291 I-14.724 J-37.717 E.16207
G1 X109.039 Y124.39 E1.3558
G1 X108.182 Y124.79 E.03133
G1 X95.323 Y137.65 E.60328
G3 X92.419 Y132.877 I33.745 J-23.799 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I1.998 J-14.62 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.446 E.12815
G1 X131.377 Y154.405 E.0738
G2 X132.402 Y154.301 I-.972 J-14.718 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.676 Y137.648 I-35.732 J-18.466 E.18546
G1 X147.817 Y124.79 E.60321
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.219 J-39.704 E.16194
G1 X104.09 Y142.47 E.43751
G2 X103.484 Y137.164 I-1.551 J-2.511 E.22145
G1 X122.148 Y118.5 E.87556
G3 X121.002 Y113.326 I5.801 J-4 E.18024
G1 X116.335 Y108.659 E.21894
G1 X115.503 Y110.756 F36000
G1 F15476.087
G3 X116.066 Y109.23 I12.925 J3.908 E.05401
G1 X122.733 Y102.563 E.31274
G3 X124.865 Y101.838 I6.944 J16.906 E.07477
G1 X131.182 Y108.154 E.29631
G3 X132.006 Y108.642 I-3.881 J7.484 E.03179
G1 X136.251 Y104.397 E.19918
G3 X137.445 Y105.502 I-12.725 J14.931 E.05398
G1 X139.665 Y108.659 F36000
G1 F15476.087
G1 X133.9 Y114.424 E.27045
G1 X133.9 Y110.872 E.1178
G1 X141.578 Y118.55 E.36015
G1 X140.432 Y118.55 E.038
G3 X139.441 Y120.884 I-32.901 J-12.597 E.08413
G1 X141.727 Y121.949 E.08366
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.574 J-38.576 E.1893
G1 X141.85 Y114.15 E1.62321
G1 X141.85 Y111.146 E.09966
G1 X141.154 Y110.45 E.03263
G1 X140.44 Y110.45 E.0237
G1 X139.935 Y109.232 E.04375
G1 X133.278 Y102.575 E.3123
G2 X131.133 Y101.839 I-5.896 J13.691 E.07529
G1 X124.816 Y108.156 E.29636
G2 X123.992 Y108.64 I2.715 J5.563 E.03174
G1 X119.747 Y104.395 E.19916
G2 X118.555 Y105.502 I8.653 J10.51 E.05401
G1 X122.552 Y109.953 F36000
G1 F15476.087
G2 X121.661 Y111.311 I8.505 J6.554 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I13.003 J-3.187 E.08976
G1 X148.749 Y148.749 E1.58506
G3 X143.673 Y151.349 I-20.771 J-34.296 E.18934
G1 X114.273 Y121.949 E1.37919
G1 X115.749 Y121.261 E.05401
G1 X153.672 Y127.52 F36000
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.331 Y148.697 E1.02576
G2 X125.669 Y148.697 I-2.331 J1.851 E.17763
G1 X103.804 Y126.832 E1.02576
G1 X102.328 Y127.52 E.05401
G1 X162.666 Y131.714 F36000
G1 F15476.087
G1 X155.966 Y138.414 E.31433
G3 X156.251 Y140.899 I-2.529 J1.549 E.08565
G1 X157.226 Y141.874 E.04575
G3 X153.253 Y145.577 I-29.249 J-27.399 E.1803
G1 X129.178 Y121.502 E1.12941
G3 X126.825 Y121.499 I-1.165 J-8.682 E.07828
G1 X102.744 Y145.58 E1.12972
G3 X98.771 Y141.877 I34.401 J-40.887 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I2.815 J-.936 E.08564
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.552 Y149.97 E.00081
G3 X127.664 Y147.92 I-2.547 J.529 E.41295
G3 X128.355 Y147.921 I.341 J2.512 E.02299
G3 X130.456 Y149.627 I-.35 J2.578 E.09443
G1 X130.527 Y149.889 E.009
G1 X130.17 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.716 Y148.309 I-2.162 J.448 E.32451
G1 X128 Y148.29 E.00875
G3 X130.157 Y149.991 I.008 J2.208 E.0911
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13749
G1 X130.205 Y150.651 E-.11463
G1 X130.164 Y150.95 E-.11464
G1 X130.083 Y151.24 E-.11465
G1 X129.963 Y151.517 E-.11466
G1 X129.806 Y151.775 E-.11465
G1 X129.724 Y151.875 E-.04928
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.947 Z4.4 F36000
G1 X150.996 Y139.107 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.008 Y139.086 E.00082
G3 X153.12 Y137.375 I2.452 J.868 E.09484
G3 X153.811 Y137.377 I.341 J2.513 E.02299
G3 X150.913 Y139.428 I-.35 J2.578 E.41256
G1 X150.981 Y139.165 E.00898
G1 X151.378 Y139.217 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.172 Y137.765 I2.082 J.737 E.07462
G3 X153.757 Y137.766 I.288 J2.128 E.01804
G3 X151.359 Y139.274 I-.297 J2.188 E.33187
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13729
G1 X151.65 Y138.681 E-.11464
G1 X151.84 Y138.447 E-.11463
G1 X152.061 Y138.241 E-.11468
G1 X152.307 Y138.067 E-.1146
G1 X152.575 Y137.928 E-.11468
G1 X152.698 Y137.885 E-.04947
; WIPE_END
G1 E-.04 F1800
G1 X147.34 Y132.449 Z4.4 F36000
G1 X133.507 Y118.418 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02108
G3 X127.749 Y107.757 I-5.107 J-4.413 E.88709
G3 X133.552 Y110.639 I.219 J6.841 E.2239
G1 X133.552 Y118.361 E.25612
G1 X133.544 Y118.371 E.00043
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.76 Y108.149 I-5.157 J-3.72 E.79115
G3 X133.16 Y110.777 I.241 J6.366 E.19215
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.2295
G1 X132.479 Y119.016 E-.18626
G1 X132.117 Y119.348 E-.1864
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X125.388 Y123.759 Z4.4 F36000
G1 X103.875 Y137.72 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.898 Y137.73 E.00081
G3 X102.208 Y137.375 I-1.349 J2.224 E.48378
G3 X102.899 Y137.377 I.341 J2.513 E.02299
G3 X103.582 Y137.567 I-.35 J2.578 E.02359
G1 X103.822 Y137.693 E.009
G1 X103.695 Y138.064 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.26 Y137.765 I-1.142 J1.89 E.38041
G1 X102.544 Y137.745 E.00875
G3 X103.643 Y138.033 I.008 J2.208 E.0353
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13745
G1 X104.16 Y138.447 E-.11465
G1 X104.35 Y138.681 E-.11463
G1 X104.507 Y138.939 E-.11466
G1 X104.627 Y139.216 E-.11465
G1 X104.708 Y139.506 E-.11463
G1 X104.726 Y139.635 E-.04934
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.02 Z4.4 F36000
G1 X139.91 Y120.718 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89472
G3 X91.645 Y132.117 I-36.355 J-17.622 E3.00054
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.103 J-7.694 E.08798
G3 X128.305 Y101.107 I12.865 J-3.743 E.83406
G3 X140.301 Y109.195 I-.305 J13.393 E.50699
G1 X140.673 Y110.102 E.03251
G1 X142.198 Y110.102 E.0506
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.918 Y120.67 I-25.161 J-9.597 E.06384
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82946
G3 X91.122 Y131.928 I-36.878 J-17.429 E2.83078
G1 X115.586 Y120.52 E.82942
G3 X128.311 Y100.715 I12.422 J-6.009 E.86641
G3 X140.936 Y109.71 I-.33 J13.82 E.50563
G1 X142.59 Y109.71 E.05083
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.465 I-18.273 J-7.019 E.03921
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X141.898 Y113.69 Z4.4 F36000
G1 X141.835 Y112.313 Z4.4
G1 Z4
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39742
G1 F3000;_EXTRUDE_SET_SPEED
G1 X141.835 Y118.376 E.17514
G1 X141.808 Y118.508 E.00389
G1 X141.676 Y118.535 E.00389
G1 X140.93 Y118.535 E.02155
; Slow Down End
G1 X141.473 Y111.864 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.473 Y111.438 E.01414
G1 X141.85 Y111.815 E.01769
G1 X141.85 Y111.146 E.02219
G1 X141.154 Y110.45 E.03263
G1 X140.485 Y110.45 E.02219
G1 X140.864 Y110.828 E.01774
G1 X140.188 Y110.828 E.02245
G1 X140.039 Y110.468 E.01292
G1 X140.316 Y110.282 E.01106
G1 X140.408 Y110.374 E.00431
G1 X139.935 Y109.231 E.04101
G1 X133.279 Y102.575 E.31226
G2 X131.133 Y101.839 I-5.843 J13.536 E.07532
G1 X124.816 Y108.156 E.29635
G2 X123.992 Y108.64 I2.716 J5.564 E.03174
G1 X119.747 Y104.395 E.19915
G2 X118.555 Y105.502 I8.644 J10.502 E.05401
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21894
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X103.484 Y137.164 E.87527
G3 X104.09 Y142.47 I-.945 J2.796 E.22145
G1 X113.416 Y151.796 E.43751
G2 X118.061 Y153.291 I14.863 J-38.208 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.829 J-23.239 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-1.997 J-14.614 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.448 E.12814
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.972 J-14.724 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.649 I36.642 J-19.023 E.18545
G1 X108.183 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.587 Y151.793 I-10.077 J-39.216 E.16207
G1 X151.91 Y142.47 E.43736
G3 X152.516 Y137.164 I1.551 J-2.511 E.22145
G1 X133.871 Y118.519 E.87466
G3 X132.791 Y119.734 I-6.801 J-4.958 E.05401
; WIPE_START
G1 X133.374 Y119.142 E-.31569
G1 X133.871 Y118.519 E-.30286
G1 X134.134 Y118.782 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X133.881 Y111.154 Z4.4 F36000
G1 X133.858 Y110.441 Z4.4
G1 Z4
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X133.915 Y110.568 E.00387
G1 X133.915 Y115.657 E.14098
; Slow Down End
G1 X139.665 Y108.659 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X134.278 Y114.047 E.25276
G1 X134.278 Y111.25 E.09278
G1 X141.2 Y118.173 E.32477
G1 X141.473 Y118.173 E.00903
G1 X141.473 Y114.527 E.12091
G1 X107.249 Y148.751 E1.60552
G2 X112.323 Y151.353 I21.651 J-35.979 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X140.251 Y121.261 E.05401
; WIPE_START
G1 X141.727 Y121.949 E-.61876
G1 X141.464 Y122.212 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X139.679 Y114.791 Z4.4 F36000
M73 P58 R9
G1 X137.445 Y105.502 Z4.4
G1 Z4
G1 E.8 F1800
G1 F15476.087
G2 X136.251 Y104.397 I-13.692 J13.58 E.05398
G1 X132.006 Y108.642 E.19918
G2 X131.182 Y108.154 I-4.708 J7.001 E.03179
G1 X124.865 Y101.838 E.29631
G2 X122.733 Y102.563 I4.822 J17.665 E.07476
G1 X116.066 Y109.23 E.31274
G2 X115.503 Y110.756 I12.357 J5.433 E.05401
; WIPE_START
G1 X116.066 Y109.23 E-.61829
G1 X116.33 Y108.966 E-.14171
; WIPE_END
G1 E-.04 F1800
G1 X115.97 Y116.59 Z4.4 F36000
G1 X115.749 Y121.261 Z4.4
G1 Z4
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.673 Y151.349 E1.37919
G2 X148.749 Y148.749 I-15.695 J-36.896 E.18934
G1 X114.965 Y114.965 E1.58488
G2 X115.336 Y117.636 I15.893 J-.846 E.08957
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.396 J5.196 E.05392
; WIPE_START
G1 X122.054 Y110.618 E-.31582
G1 X121.661 Y111.311 E-.30254
G1 X121.398 Y111.574 E-.14164
; WIPE_END
G1 E-.04 F1800
G1 X115.542 Y116.47 Z4.4 F36000
G1 X102.328 Y127.52 Z4.4
G1 Z4
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.669 Y148.697 E1.02576
G3 X130.331 Y148.697 I2.331 J1.857 E.17754
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.034 Y138.414 E.31433
G2 X99.749 Y140.899 I2.53 J1.549 E.08564
G1 X98.771 Y141.877 E.0459
G2 X102.744 Y145.58 I38.37 J-37.18 E.18024
G1 X126.828 Y121.496 E1.12984
G2 X129.178 Y121.502 I1.196 J-8.529 E.0782
G1 X153.253 Y145.577 E1.1294
G2 X157.226 Y141.874 I-25.273 J-31.099 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.966 Y138.414 I-2.814 J-.936 E.08564
G1 X162.666 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 4.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.546 Y149.971 E.0008
G3 X127.646 Y147.921 I-2.547 J.526 E.41228
G1 X128 Y147.897 E.01179
G3 X130.451 Y149.629 I0 J2.6 E.10613
G1 X130.526 Y149.889 E.00899
G1 X130.162 Y150.051 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.699 Y148.31 I-2.162 J.447 E.32425
G1 X128 Y148.29 E.00927
G3 X130.149 Y149.992 I0 J2.208 E.0909
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.1373
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.876 E-.04944
; WIPE_END
G1 E-.04 F1800
G1 X136.263 Y147.94 Z4.6 F36000
G1 X151.012 Y139.062 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.145 Y138.759 E.01098
G3 X153.101 Y137.377 I2.31 J1.194 E.08256
G1 X153.456 Y137.352 E.01179
G3 X150.993 Y139.118 I0 J2.6 E.43466
G1 X151.374 Y139.216 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.155 Y137.766 I2.081 J.737 E.0742
G1 X153.456 Y137.745 E.00927
G3 X151.355 Y139.273 I0 J2.208 E.34095
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13732
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11462
G1 X152.575 Y137.928 E-.11469
G1 X152.698 Y137.885 E-.04941
; WIPE_END
G1 E-.04 F1800
G1 X147.339 Y132.449 Z4.6 F36000
G1 X133.507 Y118.417 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02109
G3 X127.734 Y107.757 I-5.107 J-4.413 E.88661
G3 X133.552 Y110.639 I.234 J6.841 E.2244
G1 X133.552 Y118.361 E.25612
G1 X133.544 Y118.371 E.00042
G1 X133.159 Y118.224 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X132.815 Y118.659 E.01706
G3 X127.745 Y108.149 I-4.812 J-4.157 E.7736
G3 X133.16 Y110.777 I.256 J6.366 E.19261
G1 X133.16 Y118.164 E.22699
; WIPE_START
M204 S10000
G1 X132.815 Y118.659 E-.22936
G1 X132.479 Y119.016 E-.1863
G1 X132.117 Y119.348 E-.1864
G1 X131.79 Y119.604 E-.15795
; WIPE_END
G1 E-.04 F1800
G1 X125.388 Y123.759 Z4.6 F36000
G1 X103.875 Y137.72 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.732 E.0008
G3 X102.19 Y137.377 I-1.353 J2.221 E.48301
G1 X102.544 Y137.352 E.01179
G3 X103.581 Y137.568 I0 J2.6 E.03538
G1 X103.822 Y137.693 E.009
G1 X103.692 Y138.068 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.243 Y137.766 I-1.149 J1.886 E.37988
G1 X102.544 Y137.745 E.00927
G3 X103.641 Y138.037 I0 J2.208 E.03527
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13733
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04943
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z4.6 F36000
G1 X139.91 Y120.718 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89472
G3 X91.645 Y132.117 I-36.355 J-17.622 E3.00054
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.108 J-7.696 E.08798
G3 X128.298 Y101.107 I12.879 J-3.732 E.83351
G3 X140.304 Y109.201 I-.298 J13.393 E.50743
G1 X140.672 Y110.102 E.0323
G1 X142.198 Y110.102 E.0506
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.918 Y120.67 I-25.219 J-9.619 E.06384
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82946
G3 X91.122 Y131.928 I-36.878 J-17.429 E2.83078
G1 X115.586 Y120.52 E.82942
G3 X128.304 Y100.715 I12.421 J-6.01 E.86621
G3 X140.936 Y109.71 I-.323 J13.82 E.50585
G1 X142.59 Y109.71 E.05083
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.465 I-18.293 J-7.027 E.03921
M204 S10000
G1 X140.251 Y121.261 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.727 Y121.949 E.05401
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.574 J-38.576 E.1893
G1 X136.843 Y119.157 E1.38832
G1 X133.9 Y116.215 E.13803
G1 X133.871 Y118.519 E.07644
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.945 J2.796 E.22145
G1 X142.587 Y151.793 E.43736
G3 X137.939 Y153.291 I-14.724 J-37.717 E.16207
G1 X109.039 Y124.39 E1.3558
G1 X108.182 Y124.79 E.03133
G1 X95.323 Y137.65 E.60328
G3 X92.419 Y132.877 I33.745 J-23.799 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I1.998 J-14.62 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.448 E.12814
G1 X131.377 Y154.405 E.0738
G2 X132.402 Y154.301 I-.972 J-14.718 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.676 Y137.648 I-35.732 J-18.466 E.18546
G1 X147.817 Y124.79 E.60321
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.218 J-39.703 E.16194
G1 X104.09 Y142.47 E.43751
G2 X103.484 Y137.164 I-1.551 J-2.511 E.22145
G1 X122.142 Y118.506 E.87527
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.659 E.21894
G1 X115.502 Y110.756 F36000
G1 F15476.087
G3 X116.066 Y109.23 I12.919 J3.907 E.05401
G1 X122.733 Y102.563 E.31275
G3 X124.865 Y101.837 I6.967 J16.977 E.07476
G1 X131.182 Y108.154 E.29632
G3 X132.006 Y108.642 I-3.882 J7.486 E.03179
G1 X136.246 Y104.402 E.19892
G3 X137.444 Y105.502 I-7.369 J9.23 E.054
G1 X138.605 Y109.185 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.41251
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X141.828 Y112.408 E.24822
G1 X141.828 Y113.062 E.03562
G1 X138.421 Y109.655 E.26237
G1 X138.094 Y109.982 E.02518
G1 X141.828 Y113.717 E.28756
G1 X141.828 Y114.371 E.03562
G1 X137.767 Y110.309 E.31274
G1 X137.44 Y110.636 E.02519
G1 X141.828 Y115.025 E.33793
G1 X141.828 Y115.679 E.03562
G1 X137.113 Y110.963 E.36311
G1 X136.786 Y111.291 E.02518
G1 X141.828 Y116.333 E.3883
G1 X141.828 Y116.987 E.03562
G1 X136.459 Y111.618 E.41348
G1 X136.132 Y111.945 E.02518
G1 X141.828 Y117.641 E.43867
G1 X141.828 Y118.295 E.03562
G1 X133.922 Y110.389 E.60885
G1 X133.922 Y111.043 E.03562
G1 X141.407 Y118.528 E.57643
G1 X140.956 Y118.528 E.02456
G1 X139.338 Y116.91 E.12463
G1 X139.236 Y117.011 E.00782
G1 X133.922 Y111.697 E.40925
G1 X133.922 Y112.351 E.03562
G1 X138.909 Y117.338 E.38407
G1 X138.582 Y117.665 E.02518
G1 X133.922 Y113.005 E.35888
G1 X133.922 Y113.659 E.03562
G1 X138.255 Y117.992 E.3337
G1 X137.928 Y118.32 E.02518
G1 X133.922 Y114.313 E.30852
G1 X133.922 Y114.967 E.03562
G1 X137.601 Y118.647 E.28333
G1 X137.274 Y118.974 E.02518
G1 X133.719 Y115.419 E.27374
G1 X141.171 Y111.136 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
; LAYER_HEIGHT: 0.2
G1 F15476.087
G1 X141.85 Y111.815 E.03182
G1 X141.85 Y111.146 E.02219
G1 X141.154 Y110.45 E.03263
G1 X140.485 Y110.45 E.02219
G1 X141.164 Y111.129 E.03182
; WIPE_START
G1 X140.485 Y110.45 E-.36456
G1 X141.154 Y110.45 E-.2542
G1 X141.417 Y110.713 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X133.791 Y110.406 Z4.6 F36000
G1 X122.552 Y109.953 Z4.6
G1 Z4.2
G1 E.8 F1800
G1 F15476.087
G2 X121.661 Y111.311 I8.507 J6.555 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.965 Y114.965 I15.475 J-3.509 E.08956
G1 X148.749 Y148.749 E1.58486
G3 X143.673 Y151.349 I-20.771 J-34.296 E.18934
G1 X114.273 Y121.949 E1.37919
G1 X115.749 Y121.261 E.05401
; WIPE_START
G1 X114.273 Y121.949 E-.61876
G1 X114.536 Y122.212 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X116.321 Y114.791 Z4.6 F36000
M73 P59 R9
G1 X118.555 Y105.502 Z4.6
G1 Z4.2
G1 E.8 F1800
G1 F15476.087
G3 X119.747 Y104.395 I9.83 J9.389 E.05401
G1 X123.992 Y108.64 E.19915
G3 X124.816 Y108.156 I3.54 J5.081 E.03174
G1 X131.133 Y101.839 E.29634
G3 X133.279 Y102.575 I-3.65 J14.134 E.07534
G1 X139.935 Y109.231 E.31223
G1 X140.408 Y110.373 E.04099
G1 X139.179 Y109.145 E.05761
G1 X139.665 Y108.659 E.02279
; WIPE_START
G1 X139.179 Y109.145 E-.26108
G1 X140.108 Y110.073 E-.49892
; WIPE_END
G1 E-.04 F1800
G1 X144.793 Y116.099 Z4.6 F36000
G1 X153.672 Y127.52 Z4.6
G1 Z4.2
G1 E.8 F1800
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.331 Y148.697 E1.02576
G2 X125.669 Y148.697 I-2.331 J1.859 E.17751
G1 X103.804 Y126.832 E1.02576
G1 X102.328 Y127.52 E.05401
G1 X162.666 Y131.714 F36000
G1 F15476.087
G1 X155.966 Y138.414 E.31433
G3 X156.251 Y140.899 I-2.53 J1.549 E.08565
G1 X157.226 Y141.874 E.04575
G3 X153.253 Y145.577 I-29.249 J-27.399 E.1803
G1 X129.178 Y121.502 E1.1294
G3 X126.825 Y121.499 I-1.165 J-8.683 E.07828
G1 X102.744 Y145.58 E1.12972
G3 X98.771 Y141.877 I34.401 J-40.887 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I2.815 J-.936 E.08564
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 4.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.543 Y149.947
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.548 Y149.971 E.0008
G3 X127.645 Y147.921 I-2.548 J.527 E.41248
G3 X128.352 Y147.92 I.355 J2.725 E.02351
G3 X130.452 Y149.628 I-.352 J2.578 E.09444
G1 X130.526 Y149.889 E.00899
G1 X130.153 Y150.053 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.699 Y148.31 I-2.162 J.446 E.32445
G1 X127.983 Y148.291 E.00875
G3 X130.14 Y149.994 I.008 J2.208 E.09117
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13721
G1 X130.205 Y150.651 E-.11464
G1 X130.164 Y150.95 E-.11465
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.1146
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.876 E-.04956
; WIPE_END
G1 E-.04 F1800
G1 X136.263 Y147.94 Z4.8 F36000
G1 X151.012 Y139.062 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.146 Y138.759 E.01098
G3 X153.101 Y137.377 I2.311 J1.195 E.08255
G3 X153.808 Y137.376 I.355 J2.727 E.02352
G3 X150.993 Y139.118 I-.352 J2.578 E.42319
G1 X151.367 Y139.214 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.155 Y137.766 I2.08 J.741 E.07435
G1 X153.439 Y137.747 E.00875
G3 X151.348 Y139.27 I.008 J2.208 E.34138
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13748
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11462
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11462
G1 X152.575 Y137.928 E-.11466
G1 X152.697 Y137.885 E-.04927
; WIPE_END
G1 E-.04 F1800
G1 X147.339 Y132.449 Z4.8 F36000
G1 X133.507 Y118.417 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02108
G3 X121.453 Y116.134 I-5.107 J-4.417 E.48907
G3 X127.719 Y107.758 I6.549 J-1.633 E.39701
G3 X133.552 Y110.639 I.249 J6.841 E.2249
G1 X133.552 Y118.361 E.25613
G1 X133.544 Y118.37 E.00042
G1 X133.159 Y118.224 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X132.815 Y118.659 E.01705
G3 X127.73 Y108.15 I-4.812 J-4.157 E.77315
G3 X133.16 Y110.777 I.271 J6.366 E.19308
G1 X133.16 Y118.164 E.227
; WIPE_START
M204 S10000
G1 X132.815 Y118.659 E-.22922
G1 X132.479 Y119.016 E-.18637
G1 X132.117 Y119.348 E-.18636
G1 X131.79 Y119.604 E-.15805
; WIPE_END
G1 E-.04 F1800
G1 X125.393 Y123.768 Z4.8 F36000
G1 X103.917 Y137.745 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X104.187 Y137.936 E.01098
G3 X102.19 Y137.377 I-1.642 J2.018 E.47145
G3 X102.896 Y137.376 I.355 J2.727 E.02352
G3 X103.866 Y137.713 I-.352 J2.578 E.03428
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.243 Y137.766 I-1.148 J1.886 E.37993
G3 X102.844 Y137.766 I.301 J2.319 E.01853
G3 X103.641 Y138.037 I-.3 J2.188 E.02601
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13733
G1 X104.16 Y138.447 E-.11465
G1 X104.35 Y138.681 E-.11465
G1 X104.507 Y138.939 E-.11465
G1 X104.627 Y139.216 E-.11465
G1 X104.708 Y139.506 E-.11467
G1 X104.726 Y139.635 E-.04941
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z4.8 F36000
G1 X139.91 Y120.718 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89472
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.105 J-7.695 E.08797
G3 X128.29 Y101.107 I12.87 J-3.739 E.83346
G3 X140.307 Y109.207 I-.29 J13.393 E.5079
G1 X140.672 Y110.102 E.03207
G1 X142.198 Y110.102 E.05061
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.918 Y120.67 I-25.298 J-9.651 E.06384
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82946
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.297 Y100.715 I12.423 J-6.009 E.86593
G3 X140.936 Y109.71 I-.315 J13.82 E.50608
G1 X142.59 Y109.71 E.05083
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.465 I-18.322 J-7.038 E.03921
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.252 Y118.998 Z4.8 F36000
G1 Z4.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.432 Y118.55 E.01601
G1 X141.578 Y118.55 E.038
G1 X139.649 Y116.622 E.09045
G1 X139.378 Y116.622 E.00899
G1 X107.249 Y148.751 E1.50728
G2 X112.323 Y151.353 I21.651 J-35.979 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X143.202 Y122.638 E.05401
; WIPE_START
G1 X141.727 Y121.949 E-.61876
G1 X141.464 Y122.212 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X141.456 Y114.58 Z4.8 F36000
G1 X141.454 Y112.378 Z4.8
G1 Z4.4
G1 E.8 F1800
G1 F15476.087
G1 X141.85 Y112.378 E.01313
G1 X141.85 Y111.146 E.04089
G1 X141.154 Y110.45 E.03263
G1 X140.44 Y110.45 E.0237
G1 X139.935 Y109.231 E.04379
G1 X133.28 Y102.576 E.31219
G2 X131.133 Y101.839 I-5.777 J13.341 E.07536
G1 X124.816 Y108.156 E.29633
G2 X123.992 Y108.64 I2.716 J5.565 E.03174
G1 X119.747 Y104.395 E.19915
G2 X118.555 Y105.502 I8.633 J10.491 E.05401
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21894
G2 X122.147 Y118.501 I6.951 J1.176 E.18026
G1 X103.484 Y137.164 E.87552
G3 X104.09 Y142.47 I-.981 J2.799 E.22043
G1 X113.416 Y151.796 E.43753
G2 X118.061 Y153.291 I14.863 J-38.208 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.831 J-23.24 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-1.997 J-14.614 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.448 E.12814
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.972 J-14.724 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.65 I36.646 J-19.025 E.18545
G1 X108.182 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.587 Y151.793 I-10.077 J-39.216 E.16207
G1 X151.91 Y142.47 E.43736
G3 X152.516 Y137.164 I1.551 J-2.511 E.22145
G1 X133.871 Y118.519 E.87466
G3 X132.791 Y119.734 I-6.806 J-4.963 E.05401
G1 X136.411 Y114.705 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.45265
G1 F15000
G1 X140.281 Y114.705 E.12921
G1 X140.281 Y114.295 E.01368
G1 X136.411 Y114.295 E.12921
G1 X136.411 Y114.645 E.01168
G1 X136.018 Y115.098 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X140.675 Y115.098 E.14308
G1 X140.675 Y113.902 E.03677
G1 X136.018 Y113.902 E.14308
G1 X136.018 Y115.038 E.03492
G1 X135.641 Y115.475 F36000
G1 F15000
G1 X141.052 Y115.475 E.16626
G1 X141.052 Y113.525 E.05994
G1 X135.641 Y113.525 E.16626
G1 X135.641 Y115.415 E.05809
G1 X135.264 Y115.852 F36000
G1 F15000
G1 X141.429 Y115.852 E.18943
G1 X141.429 Y113.148 E.08311
G1 X135.264 Y113.148 E.18943
G1 X135.264 Y115.792 E.08127
G1 X134.906 Y116.229 F36000
G1 F15000
G1 X141.806 Y116.229 E.212
G1 X141.806 Y112.771 E.10628
G1 X134.898 Y112.771 E.21225
G1 X134.887 Y116.181 E.10478
G1 X139.658 Y108.666 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.946 Y112.378 E.17417
G1 X135.406 Y112.378 E.01789
G1 X133.9 Y110.872 E.07065
G1 X133.9 Y114.424 E.1178
G1 X134.495 Y113.829 E.02788
G1 X134.495 Y115.458 E.05401
G1 X137.444 Y105.502 F36000
G1 F15476.087
G2 X136.246 Y104.402 I-8.583 J8.145 E.054
G1 X132.006 Y108.642 E.19893
G2 X131.182 Y108.154 I-4.703 J6.991 E.03179
G1 X124.865 Y101.837 E.29632
G2 X122.733 Y102.563 I4.83 J17.69 E.07475
G1 X116.067 Y109.23 E.31275
G2 X115.503 Y110.756 I12.357 J5.434 E.05401
; WIPE_START
G1 X116.067 Y109.23 E-.61829
G1 X116.33 Y108.966 E-.14171
; WIPE_END
G1 E-.04 F1800
G1 X115.97 Y116.59 Z4.8 F36000
G1 X115.749 Y121.261 Z4.8
G1 Z4.4
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.673 Y151.349 E1.37919
G2 X148.749 Y148.749 I-15.695 J-36.896 E.18934
G1 X114.966 Y114.966 E1.58484
G2 X115.336 Y117.636 I15.795 J-.83 E.08954
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.392 J5.194 E.05392
; WIPE_START
G1 X122.054 Y110.618 E-.3158
G1 X121.661 Y111.311 E-.30256
G1 X121.398 Y111.574 E-.14165
; WIPE_END
G1 E-.04 F1800
G1 X115.542 Y116.47 Z4.8 F36000
G1 X102.328 Y127.52 Z4.8
G1 Z4.4
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.67 Y148.698 E1.02582
G3 X130.331 Y148.697 I2.331 J1.855 E.17752
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.034 Y138.414 E.31433
G2 X99.751 Y140.897 I2.519 J1.545 E.0856
G1 X98.771 Y141.877 E.04598
G2 X102.744 Y145.58 I38.37 J-37.18 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.679 E.07828
G1 X153.253 Y145.577 E1.1294
G2 X157.226 Y141.874 I-25.273 J-31.099 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.965 Y138.415 I-2.808 J-.935 E.08563
G1 X162.666 Y131.714 E.31436
; CHANGE_LAYER
; Z_HEIGHT: 4.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.553 Y149.97 E.00083
G3 X127.927 Y147.902 I-2.546 J.532 E.42177
G3 X129.353 Y148.276 I.055 J2.694 E.04953
G3 X130.457 Y149.627 I-1.346 J2.226 E.05903
G1 X130.527 Y149.889 E.009
G1 X130.171 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.954 Y148.293 I-2.161 J.451 E.33197
G3 X128.596 Y148.372 I.003 J2.635 E.01995
G3 X130.158 Y149.991 I-.587 J2.129 E.07251
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13748
M73 P60 R9
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11462
G1 X129.806 Y151.775 E-.1147
G1 X129.724 Y151.875 E-.04925
; WIPE_END
G1 E-.04 F1800
G1 X123.03 Y148.209 Z5 F36000
G1 X103.875 Y137.72 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X102.471 Y137.357 I-1.345 J2.224 E.49218
G3 X103.58 Y137.571 I.055 J2.694 E.03773
G1 X103.822 Y137.693 E.00899
G1 X103.694 Y138.065 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.498 Y137.749 I-1.141 J1.891 E.38776
G3 X103.141 Y137.827 I.003 J2.636 E.01995
G3 X103.642 Y138.035 I-.587 J2.129 E.01673
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13738
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04938
; WIPE_END
G1 E-.04 F1800
G1 X110.87 Y135.106 Z5 F36000
G1 X133.507 Y118.417 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02109
G3 X121.456 Y116.149 I-5.107 J-4.415 E.48863
G3 X127.704 Y107.758 I6.544 J-1.649 E.39704
G3 X133.552 Y110.639 I.277 J6.815 E.22549
G1 X133.552 Y118.361 E.25612
G1 X133.544 Y118.37 E.00041
G1 X133.16 Y118.222 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X133.16 Y118.223 E.00004
G3 X127.715 Y108.15 I-5.156 J-3.721 E.78966
G3 X133.16 Y110.777 I.274 J6.389 E.19349
G1 X133.16 Y118.162 E.22692
; WIPE_START
M204 S10000
G1 X133.16 Y118.223 E-.02334
G1 X132.813 Y118.658 E-.21121
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.801 Y119.596 E-.15277
; WIPE_END
G1 E-.04 F1800
G1 X137.162 Y125.028 Z5 F36000
G1 X151.012 Y139.062 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.153 Y138.763 E.01096
G3 X153.383 Y137.357 I2.31 J1.194 E.09169
G3 X154.809 Y137.731 I.055 J2.694 E.04953
G3 X151.001 Y139.12 I-1.346 J2.225 E.38784
G1 X151.384 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.41 Y137.749 I2.082 J.737 E.08179
G3 X154.052 Y137.827 I.003 J2.636 E.01995
G3 X151.364 Y139.276 I-.587 J2.129 E.32269
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13718
G1 X151.626 Y138.721 E-.09701
G1 X151.84 Y138.447 E-.13215
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.0497
; WIPE_END
G1 E-.04 F1800
G1 X148.139 Y131.764 Z5 F36000
G1 X139.91 Y120.718 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89471
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.106 J-7.696 E.08798
G3 X128.283 Y101.107 I12.87 J-3.739 E.83321
G3 X140.309 Y109.213 I-.283 J13.394 E.50835
G1 X140.672 Y110.102 E.03186
G1 X142.198 Y110.102 E.05061
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.918 Y120.67 I-25.335 J-9.664 E.06384
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82946
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.289 Y100.715 I12.423 J-6.009 E.86571
G3 X140.936 Y109.71 I-.308 J13.82 E.5063
G1 X142.59 Y109.71 E.05083
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.465 I-18.317 J-7.036 E.03921
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X143.202 Y122.638 Z5 F36000
G1 Z4.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.727 Y121.949 E.05401
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.574 J-38.576 E.1893
G1 X139.378 Y116.622 E1.50728
G1 X139.649 Y116.622 E.00899
G1 X141.578 Y118.55 E.09045
G1 X140.432 Y118.55 E.038
G1 X140.252 Y118.998 E.01601
G1 X137.352 Y116.405 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X137.589 Y116.234 E.009
G1 X137.63 Y116.229 E.00125
G1 X141.806 Y116.229 E.12832
G1 X141.806 Y112.771 E.10628
G1 X137.63 Y112.771 E.12832
G3 X137.352 Y112.595 I.102 J-.47 E.01031
G1 X133.944 Y112.595 E.1047
G1 X133.944 Y116.405 E.11707
G1 X137.292 Y116.405 E.10285
G1 X137.215 Y116.028 F36000
G1 F12000
G3 X137.63 Y115.852 I.421 J.416 E.01421
G1 X141.429 Y115.852 E.11673
G1 X141.429 Y113.148 E.08311
G1 X137.63 Y113.148 E.11673
G3 X137.147 Y112.972 I.092 J-1.005 E.01597
G1 X134.321 Y112.972 E.08682
G1 X134.321 Y116.028 E.0939
G1 X137.155 Y116.028 E.08706
G1 X141.052 Y114.5 F36000
G1 F12000
G1 X141.052 Y113.525 E.02997
G1 X137.63 Y113.525 E.10515
G1 X137.252 Y113.446 E.01186
G1 X137.096 Y113.349 E.00563
G1 X134.698 Y113.349 E.07368
G1 X134.698 Y115.651 E.07072
G1 X137.096 Y115.651 E.07368
G1 X137.428 Y115.497 E.01125
G1 X137.63 Y115.475 E.00623
G1 X141.052 Y115.475 E.10515
G1 X141.052 Y114.56 E.02813
G1 X140.675 Y114.5 F36000
G1 F12000
G1 X140.675 Y113.902 E.01838
G1 X137.63 Y113.902 E.09356
G1 X137.348 Y113.871 E.00872
G1 X136.996 Y113.726 E.01169
G1 X135.075 Y113.726 E.05901
G1 X135.075 Y115.274 E.04755
G1 X136.996 Y115.274 E.05901
G1 X137.348 Y115.129 E.01169
G1 X137.63 Y115.098 E.00872
G1 X140.675 Y115.098 E.09356
G1 X140.675 Y114.56 E.01654
G1 X140.281 Y114.5 F36000
; LINE_WIDTH: 0.439213
G1 F12000
G1 X140.281 Y114.295 E.00662
G1 X137.63 Y114.295 E.08563
G3 X136.791 Y114.103 I.168 J-2.667 E.02792
G1 X135.452 Y114.103 E.04321
G1 X135.452 Y114.897 E.02562
G1 X136.896 Y114.897 E.04661
G1 X137.265 Y114.753 E.01281
G1 X137.63 Y114.705 E.01186
G1 X140.281 Y114.705 E.08563
G1 X140.281 Y114.56 E.00468
G1 X135.849 Y114.5 F36000
; LINE_WIDTH: 0.45932
G1 F12000
G1 X136.731 Y114.5 E.02991
G1 X133.9 Y116.901 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.871 Y118.519 E.05368
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.945 J2.796 E.22145
G1 X142.587 Y151.793 E.43736
G3 X137.939 Y153.291 I-14.479 J-36.956 E.16208
G1 X109.039 Y124.39 E1.3558
G1 X108.182 Y124.79 E.03133
G1 X95.323 Y137.649 E.60328
G3 X92.419 Y132.877 I33.738 J-23.795 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I1.998 J-14.62 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.448 E.12814
G1 X131.377 Y154.405 E.07379
G2 X132.402 Y154.301 I-.972 J-14.718 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.676 Y137.648 I-35.73 J-18.464 E.18546
G1 X147.817 Y124.79 E.60321
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.218 J-39.703 E.16194
G1 X104.09 Y142.47 E.43751
G2 X103.484 Y137.164 I-1.551 J-2.511 E.22145
G1 X122.147 Y118.501 E.8755
G3 X121.002 Y113.326 I5.81 J-4 E.18026
G1 X116.334 Y108.659 E.21894
G1 X115.503 Y110.756 F36000
G1 F15476.087
G3 X116.067 Y109.23 I12.926 J3.91 E.05401
G1 X122.733 Y102.563 E.31275
G3 X124.865 Y101.837 I6.972 J16.995 E.07475
G1 X131.182 Y108.154 E.29632
G3 X132.006 Y108.642 I-6.552 J11.988 E.03178
G1 X136.246 Y104.402 E.19894
G3 X137.444 Y105.502 I-7.399 J9.258 E.054
G1 X139.658 Y108.666 F36000
G1 F15476.087
G1 X136.121 Y112.203 E.16594
G1 X135.231 Y112.203 E.02953
G1 X133.9 Y110.872 E.06241
G1 X133.9 Y110.517 E.01178
G2 X133.081 Y109.544 I-6.706 J4.816 E.04225
; WIPE_START
G1 X133.9 Y110.517 E-.48353
G1 X133.9 Y110.872 E-.13491
G1 X134.164 Y111.136 E-.14156
; WIPE_END
G1 E-.04 F1800
G1 X126.571 Y110.354 Z5 F36000
G1 X122.563 Y109.941 Z5
G1 Z4.6
G1 E.8 F1800
G1 F15476.087
G2 X121.673 Y111.299 I7.059 J5.594 E.05394
G1 X115.336 Y117.636 E.29728
G3 X114.966 Y114.966 I15.373 J-3.491 E.08953
G1 X148.749 Y148.749 E1.58482
G3 X143.673 Y151.349 I-20.771 J-34.296 E.18934
G1 X114.273 Y121.949 E1.37919
G1 X115.749 Y121.261 E.05401
; WIPE_START
G1 X114.273 Y121.949 E-.61876
G1 X114.536 Y122.212 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X116.321 Y114.791 Z5 F36000
G1 X118.555 Y105.502 Z5
G1 Z4.6
G1 E.8 F1800
G1 F15476.087
G3 X119.747 Y104.395 I9.827 J9.387 E.05401
G1 X123.992 Y108.64 E.19915
G3 X124.816 Y108.156 I3.544 J5.088 E.03174
G1 X131.133 Y101.839 E.29632
G3 X133.28 Y102.576 I-3.585 J13.947 E.07539
G1 X139.934 Y109.23 E.31216
G1 X140.44 Y110.45 E.0438
G1 X141.154 Y110.45 E.0237
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y112.378 E.04089
G1 X141.454 Y112.378 E.01313
; WIPE_START
G1 X141.85 Y112.378 E-.15037
G1 X141.85 Y111.146 E-.46839
G1 X141.587 Y110.883 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X146.073 Y117.058 Z5 F36000
G1 X153.672 Y127.52 Z5
G1 Z4.6
G1 E.8 F1800
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.331 Y148.697 E1.02576
G2 X125.673 Y148.701 I-2.327 J1.85 E.17749
G1 X103.804 Y126.832 E1.02596
G1 X102.328 Y127.52 E.05401
G1 X162.666 Y131.714 F36000
G1 F15476.087
G1 X155.963 Y138.417 E.31448
G3 X156.251 Y140.899 I-2.501 J1.548 E.08559
G1 X157.226 Y141.874 E.04575
G3 X153.253 Y145.577 I-29.251 J-27.402 E.1803
G1 X129.178 Y121.502 E1.12941
G3 X126.825 Y121.499 I-1.165 J-8.681 E.07828
G1 X102.744 Y145.58 E1.12972
G3 X98.771 Y141.877 I34.397 J-40.883 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I2.814 J-.936 E.08564
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 4.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.554 Y149.969 E.00083
G3 X127.911 Y147.903 I-2.546 J.532 E.42116
G3 X129.353 Y148.276 I.075 J2.683 E.05006
G3 X130.457 Y149.627 I-1.345 J2.226 E.05903
G1 X130.527 Y149.889 E.009
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.938 Y148.294 I-2.161 J.45 E.33137
G3 X128.881 Y148.473 I.079 J2.159 E.02974
G3 X130.156 Y149.991 I-.873 J2.027 E.06318
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13743
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11462
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.948 Z5.2 F36000
G1 X150.996 Y139.107 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.013 Y139.088 E.00085
G3 X153.367 Y137.358 I2.451 J.87 E.10288
G3 X154.809 Y137.731 I.075 J2.683 E.05006
G3 X150.917 Y139.428 I-1.345 J2.226 E.37734
G1 X150.982 Y139.166 E.00898
G1 X151.382 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.393 Y137.75 I2.081 J.738 E.08131
G3 X154.337 Y137.928 I.079 J2.159 E.02974
G3 X151.363 Y139.276 I-.873 J2.028 E.31344
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13721
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04954
; WIPE_END
G1 E-.04 F1800
G1 X147.364 Y132.425 Z5.2 F36000
G1 X133.552 Y118.288 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.552 Y118.361 E.0024
G1 X133.11 Y118.914 E.02349
G3 X121.607 Y116.662 I-5.108 J-4.415 E.47087
G3 X127.688 Y107.759 I6.394 J-2.161 E.41429
G3 X133.552 Y110.639 I.279 J6.841 E.22592
G1 X133.552 Y118.228 E.25173
G1 X133.159 Y118.225 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X132.815 Y118.659 E.01703
G3 X127.7 Y108.151 I-4.812 J-4.157 E.77221
G3 X133.16 Y110.777 I.294 J6.378 E.19399
G1 X133.16 Y118.165 E.22702
; WIPE_START
M204 S10000
G1 X132.815 Y118.659 E-.22904
G1 X132.479 Y119.016 E-.18637
G1 X132.117 Y119.348 E-.18636
G1 X131.79 Y119.605 E-.15824
; WIPE_END
G1 E-.04 F1800
G1 X125.387 Y123.76 Z5.2 F36000
G1 X103.875 Y137.72 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X102.455 Y137.358 I-1.345 J2.226 E.49197
G3 X103.58 Y137.571 I.075 J2.683 E.03827
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.066 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.482 Y137.75 I-1.141 J1.89 E.38725
G3 X103.425 Y137.928 I.079 J2.159 E.02974
G3 X103.641 Y138.036 I-.873 J2.028 E.00744
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13738
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04938
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z5.2 F36000
G1 X139.912 Y120.719 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89466
G3 X91.645 Y132.117 I-36.355 J-17.622 E3.00054
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.108 J-7.697 E.08797
G3 X128.276 Y101.107 I12.87 J-3.739 E.83297
G3 X140.312 Y109.219 I-.276 J13.394 E.50882
M73 P61 R9
G1 X140.672 Y110.102 E.03163
G1 X142.198 Y110.102 E.05061
G1 X142.198 Y118.898 E.29178
G1 X140.667 Y118.898 E.05077
G3 X139.922 Y120.67 I-25.902 J-9.856 E.06379
G1 X140.414 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82942
G3 X91.122 Y131.928 I-36.878 J-17.429 E2.83078
G1 X115.586 Y120.52 E.82942
G3 X128.282 Y100.715 I12.423 J-6.009 E.86548
G3 X140.936 Y109.71 I-.301 J13.82 E.50652
G1 X142.59 Y109.71 E.05084
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.439 Y120.466 I-17.554 J-6.695 E.03921
; WIPE_START
M204 S10000
G1 X142.25 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.254 Y118.997 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.431 Y118.55 E.01597
G1 X141.578 Y118.55 E.03805
G1 X139.877 Y116.849 E.07977
G1 X139.151 Y116.849 E.02409
G1 X107.249 Y148.751 E1.4966
G2 X112.323 Y151.353 I21.649 J-35.974 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X143.202 Y122.638 E.05401
; WIPE_START
G1 X141.727 Y121.949 E-.61876
G1 X141.464 Y122.212 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X141.802 Y114.587 Z5.2 F36000
G1 X141.806 Y114.5 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X141.806 Y112.543 E.06013
G1 X135.351 Y112.543 E.19834
G1 X135.176 Y112.595 E.00562
G1 X133.944 Y112.595 E.03784
G1 X133.944 Y116.405 E.11707
G1 X135.176 Y116.405 E.03784
G1 X135.468 Y116.457 E.00913
G1 X141.806 Y116.457 E.19474
G1 X141.806 Y114.56 E.05829
M73 P61 R8
G1 X141.429 Y114.5 F36000
G1 F12000
G1 X141.429 Y112.92 E.04855
G1 X135.418 Y112.92 E.18469
G1 X135.176 Y112.972 E.00762
G1 X134.321 Y112.972 E.02625
G1 X134.321 Y116.028 E.0939
G1 X135.176 Y116.028 E.02625
G1 X135.612 Y116.08 E.01351
G1 X141.429 Y116.08 E.17872
G1 X141.429 Y114.56 E.04671
G1 X141.052 Y114.5 F36000
G1 F12000
G1 X141.052 Y113.297 E.03696
G1 X135.482 Y113.297 E.17115
G1 X135.176 Y113.349 E.00954
G1 X134.698 Y113.349 E.01467
G1 X134.698 Y115.651 E.07072
G3 X135.901 Y115.703 I-1.397 J46.203 E.037
G1 X141.052 Y115.703 E.15826
G1 X141.052 Y114.56 E.03512
G1 X140.675 Y114.5 F36000
G1 F12000
G1 X140.675 Y113.674 E.02538
G1 X135.536 Y113.674 E.15791
G1 X135.075 Y113.726 E.01423
G1 X135.075 Y115.274 E.04755
G1 X135.612 Y115.326 E.01657
G1 X140.675 Y115.326 E.15555
G1 X140.675 Y114.56 E.02353
G1 X140.298 Y114.5 F36000
G1 F12000
G1 X140.298 Y114.051 E.01379
G1 X135.589 Y114.051 E.14467
G1 X135.452 Y114.07 E.00425
G1 X135.452 Y114.93 E.02641
G1 X135.901 Y114.949 E.0138
G1 X140.298 Y114.949 E.13508
G1 X140.298 Y114.56 E.01195
G1 X135.901 Y114.5 F36000
; LINE_WIDTH: 0.56347
G1 F12000
G1 X139.789 Y114.5 E.1649
G1 X141.226 Y112.151 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.85 Y112.151 E.02068
G1 X141.85 Y111.146 E.03334
G1 X141.154 Y110.45 E.03263
G1 X140.44 Y110.45 E.0237
G1 X139.934 Y109.23 E.04381
G1 X133.28 Y102.577 E.31213
G2 X131.132 Y101.84 I-5.685 J13.072 E.07541
G1 X124.816 Y108.156 E.29631
G2 X123.992 Y108.64 I2.722 J5.574 E.03174
G1 X119.747 Y104.395 E.19915
G2 X118.558 Y105.506 I7.716 J9.451 E.054
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.2189
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X103.484 Y137.164 E.87527
G3 X104.09 Y142.47 I-.945 J2.796 E.22145
G1 X113.416 Y151.796 E.43751
G2 X118.061 Y153.291 I14.863 J-38.208 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.83 J-23.239 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-2.001 J-14.65 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.448 E.12814
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.976 J-14.76 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.65 I36.646 J-19.025 E.18545
G1 X108.183 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.587 Y151.793 I-10.077 J-39.216 E.16207
G1 X151.91 Y142.47 E.43736
G3 X152.516 Y137.164 I1.551 J-2.511 E.22145
G1 X133.871 Y118.519 E.87466
G1 X133.9 Y116.901 E.05368
; WIPE_START
G1 X133.871 Y118.519 E-.61497
G1 X134.141 Y118.789 E-.14503
; WIPE_END
G1 E-.04 F1800
G1 X133.271 Y111.206 Z5.2 F36000
G1 X133.081 Y109.544 Z5.2
G1 Z4.8
G1 E.8 F1800
G1 F15476.087
G3 X133.9 Y110.517 I-5.889 J5.791 E.04225
G1 X133.9 Y110.872 E.01178
G1 X135.207 Y112.18 E.06132
G1 X136.173 Y112.151 E.03205
G1 X139.659 Y108.666 E.1635
G1 X137.444 Y105.502 F36000
G1 F15476.087
G2 X136.246 Y104.402 I-8.616 J8.174 E.054
G1 X132.006 Y108.642 E.19895
G2 X131.182 Y108.154 I-4.705 J6.996 E.03179
G1 X124.87 Y101.842 E.29609
G2 X122.731 Y102.565 I3.223 J13.062 E.075
G1 X116.067 Y109.23 E.31263
G2 X115.503 Y110.756 I12.367 J5.438 E.05401
; WIPE_START
G1 X116.067 Y109.23 E-.61829
G1 X116.33 Y108.966 E-.14172
; WIPE_END
G1 E-.04 F1800
G1 X115.97 Y116.59 Z5.2 F36000
G1 X115.749 Y121.261 Z5.2
G1 Z4.8
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.673 Y151.349 E1.37919
G2 X148.749 Y148.749 I-15.695 J-36.896 E.18934
G1 X114.966 Y114.966 E1.58481
G2 X115.336 Y117.636 I15.69 J-.812 E.08951
G1 X121.672 Y111.3 E.29724
G3 X122.562 Y109.942 I8.058 J4.308 E.05393
; WIPE_START
G1 X122.054 Y110.618 E-.32148
G1 X121.672 Y111.3 E-.29692
G1 X121.409 Y111.564 E-.1416
; WIPE_END
G1 E-.04 F1800
G1 X115.554 Y116.46 Z5.2 F36000
G1 X102.328 Y127.52 Z5.2
G1 Z4.8
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.674 Y148.702 E1.02599
G3 X130.331 Y148.697 I2.33 J1.844 E.17749
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.034 Y138.414 E.31433
G2 X99.749 Y140.899 I2.53 J1.549 E.08564
G1 X98.771 Y141.877 E.0459
G2 X102.744 Y145.58 I38.37 J-37.18 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.679 E.07828
G1 X153.253 Y145.577 E1.1294
G2 X157.226 Y141.874 I-25.275 J-31.101 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.962 Y138.418 I-2.785 J-.933 E.08558
G1 X162.666 Y131.714 E.3145
; CHANGE_LAYER
; Z_HEIGHT: 5
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.554 Y149.969 E.00083
G3 X127.895 Y147.904 I-2.546 J.533 E.42056
G3 X129.353 Y148.276 I.094 J2.673 E.05059
G3 X130.457 Y149.627 I-1.344 J2.226 E.05903
G1 X130.527 Y149.889 E.00901
G1 X130.17 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.922 Y148.295 I-2.161 J.452 E.33104
G3 X128.881 Y148.473 I.097 J2.152 E.03023
G3 X130.157 Y149.991 I-.872 J2.029 E.06321
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13747
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04927
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.947 Z5.4 F36000
G1 X150.996 Y139.107 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.014 Y139.088 E.00087
G3 X153.351 Y137.36 I2.451 J.87 E.10232
G3 X154.809 Y137.731 I.095 J2.673 E.05059
G3 X150.918 Y139.429 I-1.344 J2.226 E.37733
G1 X150.982 Y139.166 E.00898
G1 X151.384 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.377 Y137.751 I2.081 J.738 E.08078
G3 X154.337 Y137.928 I.097 J2.152 E.03023
G3 X151.364 Y139.276 I-.872 J2.029 E.31346
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13719
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11464
G1 X152.061 Y138.241 E-.11462
G1 X152.307 Y138.067 E-.11465
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04955
; WIPE_END
G1 E-.04 F1800
G1 X147.34 Y132.449 Z5.4 F36000
G1 X133.507 Y118.417 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.0211
G3 X127.673 Y107.759 I-5.109 J-4.412 E.8848
G3 X133.552 Y110.639 I.294 J6.84 E.22642
G1 X133.552 Y118.361 E.25612
G1 X133.544 Y118.37 E.00041
G1 X133.16 Y118.221 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X133.16 Y118.223 E.00006
G3 X127.684 Y108.151 I-5.156 J-3.722 E.78874
G3 X133.16 Y110.777 I.309 J6.377 E.19446
G1 X133.16 Y118.161 E.2269
; WIPE_START
M204 S10000
G1 X133.16 Y118.223 E-.02355
G1 X132.813 Y118.658 E-.21121
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.802 Y119.596 E-.15256
; WIPE_END
G1 E-.04 F1800
G1 X125.399 Y123.751 Z5.4 F36000
G1 X103.875 Y137.72 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X102.439 Y137.36 I-1.344 J2.226 E.49139
G3 X103.58 Y137.571 I.094 J2.673 E.0388
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.066 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.466 Y137.751 I-1.14 J1.891 E.3868
G3 X103.425 Y137.928 I.097 J2.152 E.03023
G3 X103.642 Y138.036 I-.872 J2.029 E.00744
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13738
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11466
G1 X104.726 Y139.635 E-.04938
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z5.4 F36000
G1 X139.91 Y120.718 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89471
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89502
G3 X115.136 Y118.245 I16.107 J-7.696 E.08798
G3 X128.269 Y101.107 I12.87 J-3.739 E.83272
G3 X140.314 Y109.226 I-.269 J13.394 E.50929
G1 X140.672 Y110.102 E.0314
G1 X142.198 Y110.102 E.05061
G1 X142.198 Y112.806 E.08969
G1 X134.922 Y112.806 E.24135
G1 X134.922 Y116.194 E.11239
G1 X142.198 Y116.194 E.24135
G1 X142.198 Y118.898 E.08969
G1 X140.667 Y118.898 E.05077
G3 X139.919 Y120.67 I-25.42 J-9.696 E.06383
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82945
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.275 Y100.715 I12.423 J-6.009 E.86526
G3 X140.936 Y109.71 I-.293 J13.82 E.50675
G1 X142.59 Y109.71 E.05084
G1 X142.59 Y119.29 E.29437
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.466 I-18.343 J-7.045 E.03921
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X143.202 Y122.638 Z5.4 F36000
M73 P62 R8
G1 Z5
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.727 Y121.949 E.05401
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.574 J-38.576 E.1893
G1 X138.953 Y117.047 E1.4873
G1 X140.075 Y117.047 E.03724
G1 X141.578 Y118.55 E.07047
G1 X140.431 Y118.55 E.03805
G1 X140.254 Y118.997 E.01597
G1 X135.397 Y116.621 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.48941
G1 F12000
G1 X141.711 Y116.621 E.22973
; WIPE_START
G1 X139.711 Y116.621 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X142.383 Y113.853 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X141.558 Y113.029 E.03585
G1 X141.024 Y113.029
G1 X142.383 Y114.387 E.05902
G1 X142.383 Y114.92
G1 X140.491 Y113.029 E.08219
G1 X139.958 Y113.029
G1 X142.383 Y115.453 E.10536
G1 X142.368 Y115.972
G1 X139.425 Y113.029 E.12789
G1 X138.891 Y113.029
G1 X141.834 Y115.972 E.12789
G1 X141.301 Y115.972
G1 X138.358 Y113.029 E.12789
G1 X137.825 Y113.029
G1 X140.768 Y115.972 E.12789
G1 X140.235 Y115.972
G1 X137.292 Y113.029 E.12789
G1 X136.758 Y113.029
G1 X139.701 Y115.972 E.12789
G1 X139.168 Y115.972
G1 X136.225 Y113.029 E.12789
G1 X135.692 Y113.029
G1 X138.635 Y115.972 E.12789
G1 X138.102 Y115.972
G1 X135.159 Y113.029 E.12789
G1 X135.145 Y113.548
G1 X137.568 Y115.972 E.10532
G1 X137.035 Y115.972
G1 X135.145 Y114.081 E.08215
G1 X135.145 Y114.614
G1 X136.502 Y115.972 E.05897
G1 X135.969 Y115.972
G1 X135.145 Y115.148 E.0358
; WIPE_START
M204 S10000
G1 X135.969 Y115.972 E-.44275
G1 X136.502 Y115.972 E-.20264
G1 X136.289 Y115.758 E-.11461
; WIPE_END
G1 E-.04 F1800
G1 X133.9 Y116.901 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.871 Y118.519 E.05368
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.945 J2.796 E.22145
G1 X142.587 Y151.793 E.43736
G3 X137.939 Y153.291 I-13.986 J-35.428 E.16208
G1 X109.039 Y124.39 E1.3558
G1 X108.183 Y124.79 E.03133
G1 X95.323 Y137.65 E.60328
G3 X92.419 Y132.877 I33.741 J-23.797 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I1.997 J-14.616 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.448 E.12814
G1 X131.377 Y154.405 E.0738
G2 X132.402 Y154.301 I-.975 J-14.75 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.676 Y137.648 I-35.729 J-18.464 E.18546
G1 X147.817 Y124.79 E.60321
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.218 J-39.703 E.16194
G1 X104.083 Y142.463 E.43785
G2 X103.484 Y137.164 I-1.571 J-2.506 E.22039
G1 X122.142 Y118.506 E.87527
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.334 Y108.659 E.21894
G1 X115.502 Y110.756 F36000
G1 F15476.087
G3 X116.067 Y109.23 I12.933 J3.913 E.05401
G1 X122.731 Y102.565 E.31264
G3 X124.87 Y101.842 I5.401 J12.455 E.07498
G1 X131.182 Y108.154 E.2961
G3 X132.006 Y108.642 I-5.873 J10.844 E.03178
G1 X136.247 Y104.401 E.19895
G3 X137.444 Y105.502 I-7.435 J9.291 E.054
G1 X139.659 Y108.665 F36000
G1 F15476.087
G1 X136.371 Y111.953 E.15421
G1 X135.211 Y111.953 E.03848
G1 X135.096 Y112.068 E.00542
G1 X133.9 Y110.872 E.05609
G1 X133.9 Y110.517 E.01178
G2 X133.081 Y109.544 I-6.711 J4.819 E.04225
G1 X134.478 Y112.647 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.52447
G1 F12000
G1 X133.996 Y112.647 E.0189
G1 X133.996 Y116.353 E.14541
G1 X134.478 Y116.353 E.0189
G1 X134.478 Y112.707 E.14306
G1 X135.397 Y112.379 F36000
; LINE_WIDTH: 0.48942
G1 F12000
G1 X141.711 Y112.379 E.22973
; WIPE_START
G1 X139.711 Y112.379 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X144.885 Y117.99 Z5.4 F36000
G1 X153.672 Y127.52 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.331 Y148.697 E1.02576
G2 X125.669 Y148.697 I-2.331 J1.858 E.17754
G1 X103.804 Y126.832 E1.02576
G1 X102.328 Y127.52 E.05401
; WIPE_START
G1 X103.804 Y126.832 E-.61876
G1 X104.066 Y127.094 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X109.663 Y121.905 Z5.4 F36000
G1 X122.552 Y109.953 Z5.4
G1 Z5
G1 E.8 F1800
G1 F15476.087
G2 X121.661 Y111.311 I8.506 J6.554 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.967 Y114.967 I15.278 J-3.474 E.0895
G1 X148.749 Y148.749 E1.58479
G3 X143.673 Y151.349 I-20.771 J-34.296 E.18934
G1 X114.273 Y121.949 E1.37919
G1 X115.749 Y121.261 E.05401
; WIPE_START
G1 X114.273 Y121.949 E-.61876
G1 X114.536 Y122.212 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X116.321 Y114.791 Z5.4 F36000
G1 X118.555 Y105.502 Z5.4
G1 Z5
G1 E.8 F1800
G1 F15476.087
G3 X119.747 Y104.395 I9.814 J9.374 E.05401
G1 X123.992 Y108.64 E.19915
G3 X124.816 Y108.156 I3.544 J5.086 E.03174
G1 X131.132 Y101.84 E.2963
G3 X133.281 Y102.577 I-3.491 J13.673 E.07543
G1 X139.934 Y109.23 E.31209
G1 X140.44 Y110.45 E.04383
G1 X141.154 Y110.45 E.02371
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y111.953 E.02676
G1 X141.028 Y111.953 E.02726
; WIPE_START
G1 X141.85 Y111.953 E-.31222
G1 X141.85 Y111.146 E-.30654
G1 X141.587 Y110.883 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X147.016 Y116.248 Z5.4 F36000
G1 X162.666 Y131.714 Z5.4
G1 Z5
G1 E.8 F1800
G1 F15476.087
G1 X155.966 Y138.414 E.31433
G3 X156.251 Y140.899 I-2.53 J1.549 E.08565
G1 X157.226 Y141.874 E.04575
G3 X153.253 Y145.577 I-29.249 J-27.399 E.1803
G1 X129.178 Y121.502 E1.1294
G3 X126.825 Y121.499 I-1.165 J-8.683 E.07828
G1 X102.744 Y145.58 E1.12972
G3 X98.771 Y141.877 I34.401 J-40.887 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I2.814 J-.936 E.08564
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 5.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.547 Y149.971 E.0008
G3 X125.81 Y149.102 I-2.546 J.532 E.33782
G3 X127.879 Y147.905 I2.165 J1.354 E.08252
G3 X130.451 Y149.629 I.123 J2.598 E.11002
G1 X130.526 Y149.889 E.00899
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.906 Y148.296 I-2.161 J.452 E.33058
G3 X129.149 Y148.611 I.086 J2.267 E.03995
G3 X130.156 Y149.991 I-1.141 J1.89 E.05389
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13743
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X123.03 Y148.209 Z5.6 F36000
G1 X103.875 Y137.72 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X104.187 Y137.936 I-1.338 J2.204 E.0118
G3 X102.423 Y137.361 I-1.636 J2.022 E.47905
G3 X103.581 Y137.568 I.136 J2.574 E.03938
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.45 Y137.752 I-1.141 J1.889 E.38605
G3 X103.641 Y138.037 I.086 J2.267 E.0381
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13735
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.0494
; WIPE_END
G1 E-.04 F1800
G1 X110.87 Y135.106 Z5.6 F36000
G1 X133.507 Y118.417 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.11 Y118.914 E.02111
G3 X121.616 Y116.691 I-5.108 J-4.416 E.46988
G3 X125.628 Y108.181 I6.379 J-2.193 E.34535
G3 X127.658 Y107.76 I2.402 J6.462 E.06905
G3 X133.552 Y110.639 I.308 J6.84 E.22693
G1 X133.552 Y118.361 E.25612
G1 X133.545 Y118.37 E.0004
G1 X133.16 Y118.221 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X133.16 Y118.223 E.00007
G3 X127.669 Y108.151 I-5.156 J-3.722 E.78828
G3 X133.16 Y110.777 I.32 J6.385 E.19491
G1 X133.16 Y118.161 E.2269
; WIPE_START
M204 S10000
G1 X133.16 Y118.223 E-.02365
G1 X132.813 Y118.658 E-.21121
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.802 Y119.595 E-.15246
; WIPE_END
G1 E-.04 F1800
G1 X137.154 Y125.036 Z5.6 F36000
G1 X150.996 Y139.107 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.013 Y139.088 E.00086
G3 X153.335 Y137.361 I2.45 J.87 E.10179
G3 X155.099 Y137.936 I.136 J2.574 E.06297
G3 X150.918 Y139.428 I-1.636 J2.021 E.36546
G1 X150.982 Y139.166 E.00898
G1 X151.384 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.361 Y137.752 I2.08 J.737 E.08028
G3 X154.604 Y138.067 I.086 J2.267 E.03995
G3 X151.364 Y139.276 I-1.141 J1.889 E.30392
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.1372
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04955
; WIPE_END
G1 E-.04 F1800
G1 X148.139 Y131.764 Z5.6 F36000
G1 X139.912 Y120.719 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89466
G3 X91.645 Y132.117 I-36.355 J-17.622 E3.00054
G1 X116.098 Y120.714 E.89503
G3 X115.136 Y118.245 I16.105 J-7.695 E.08798
G3 X128.261 Y101.106 I12.867 J-3.742 E.83256
G3 X140.317 Y109.232 I-.262 J13.395 E.50975
G1 X140.672 Y110.102 E.03118
G1 X142.198 Y110.102 E.05062
G1 X142.198 Y113.282 E.10547
G1 X135.398 Y113.282 E.22557
G1 X135.398 Y115.718 E.08083
G1 X142.198 Y115.718 E.22557
G1 X142.198 Y118.898 E.10547
G1 X140.667 Y118.898 E.05077
G3 X139.922 Y120.67 I-25.906 J-9.858 E.06379
G1 X140.414 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82942
G3 X91.122 Y131.928 I-36.878 J-17.429 E2.83078
G1 X115.586 Y120.52 E.82942
G3 X128.267 Y100.714 I12.419 J-6.011 E.86514
G3 X140.936 Y109.71 I-.286 J13.82 E.50697
G1 X142.59 Y109.71 E.05084
G1 X142.59 Y113.674 E.1218
G1 X135.79 Y113.674 E.20895
G1 X135.79 Y115.326 E.05078
G1 X142.59 Y115.326 E.20895
G1 X142.59 Y119.29 E.1218
G1 X140.934 Y119.29 E.05089
G3 X140.439 Y120.466 I-17.553 J-6.694 E.03921
; WIPE_START
M204 S10000
G1 X142.25 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.254 Y118.997 Z5.6 F36000
G1 Z5.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.431 Y118.55 E.01597
G1 X141.578 Y118.55 E.03805
G1 X140.225 Y117.197 E.06346
G1 X138.803 Y117.197 E.04716
G1 X107.249 Y148.751 E1.48029
G2 X112.323 Y151.353 I21.649 J-35.974 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X143.202 Y122.638 E.05401
; WIPE_START
G1 X141.727 Y121.949 E-.61876
G1 X141.464 Y122.212 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X135.833 Y117.06 Z5.6 F36000
M73 P63 R8
G1 X135.211 Y116.49 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.419157
G1 F12000
G1 X135.34 Y116.623 E.00567
G1 X135.382 Y116.805 E.00573
G1 X141.806 Y116.805 E.19695
G1 X141.806 Y116.11 E.02129
G1 X135.645 Y116.11 E.18888
G1 X135.138 Y116.092 E.01557
G1 X135.006 Y115.9 E.00713
G1 X135.006 Y113.078 E.08652
G1 X135.151 Y112.906 E.0069
G1 X135.645 Y112.89 E.01517
G1 X141.806 Y112.89 E.18888
G1 X141.806 Y112.195 E.02129
G1 X135.374 Y112.195 E.1972
G1 X135.306 Y112.42 E.00719
G1 X135.138 Y112.55 E.00653
G3 X133.944 Y112.569 I-.918 J-20.526 E.03661
G1 X133.944 Y116.431 E.11841
G3 X135.081 Y116.441 I.276 J35.109 E.03486
G1 X135.155 Y116.469 E.00241
; WIPE_START
G1 X135.081 Y116.441 E-.0299
G1 X133.944 Y116.431 E-.43211
G1 X133.944 Y115.647 E-.29799
; WIPE_END
G1 E-.04 F1800
G1 X140.998 Y112.733 Z5.6 F36000
G1 X141.459 Y112.542 Z5.6
G1 Z5.2
G1 E.8 F1800
; LINE_WIDTH: 0.36036
G1 F12000
G1 X135.705 Y112.542 E.14882
; WIPE_START
G1 X137.705 Y112.542 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.754 Y116.071 Z5.6 F36000
G1 Z5.2
G1 E.8 F1800
; LINE_WIDTH: 0.38525
G1 F12000
G1 X134.646 Y115.9 E.00564
G1 X134.646 Y113.078 E.07872
G1 X134.754 Y112.929 E.00515
G1 X134.304 Y112.929 E.01256
G1 X134.304 Y116.071 E.08767
G1 X134.694 Y116.071 E.01088
G1 X135.645 Y116.458 F36000
; LINE_WIDTH: 0.36037
G1 F12000
G1 X141.399 Y116.458 E.14883
; WIPE_START
G1 X139.399 Y116.458 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.879 Y111.803 Z5.6 F36000
G1 Z5.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.85 Y111.803 E.03221
G1 X141.85 Y111.146 E.0218
G1 X141.154 Y110.45 E.03263
G1 X140.439 Y110.45 E.02371
G1 X139.933 Y109.23 E.04384
G1 X133.281 Y102.578 E.31206
G2 X131.132 Y101.84 I-5.597 J12.811 E.07546
G1 X124.816 Y108.156 E.29629
G2 X123.992 Y108.64 I2.719 J5.569 E.03174
G1 X119.747 Y104.395 E.19915
G2 X118.559 Y105.506 I7.648 J9.374 E.054
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21894
G2 X122.146 Y118.502 I6.972 J1.174 E.18027
G1 X103.484 Y137.164 E.87545
G3 X104.09 Y142.47 I-.945 J2.796 E.22145
G1 X113.416 Y151.796 E.43751
G2 X118.061 Y153.291 I14.863 J-38.208 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.828 J-23.238 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-1.997 J-14.614 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.448 E.12814
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.976 J-14.76 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.65 I36.646 J-19.025 E.18545
G1 X108.183 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.587 Y151.793 I-10.077 J-39.216 E.16207
G1 X151.91 Y142.47 E.43736
G3 X152.516 Y137.164 I1.551 J-2.511 E.22145
G1 X133.871 Y118.519 E.87466
G1 X133.9 Y116.901 E.05368
; WIPE_START
G1 X133.871 Y118.519 E-.61496
G1 X134.141 Y118.789 E-.14504
; WIPE_END
G1 E-.04 F1800
G1 X133.271 Y111.206 Z5.6 F36000
G1 X133.081 Y109.544 Z5.6
G1 Z5.2
G1 E.8 F1800
G1 F15476.087
G3 X133.9 Y110.517 I-5.887 J5.79 E.04225
G1 X133.9 Y110.872 E.01178
G1 X135.021 Y111.993 E.05258
G1 X135.211 Y111.803 E.00893
G1 X136.521 Y111.803 E.04344
G1 X139.659 Y108.665 E.1472
G1 X137.444 Y105.502 F36000
G1 F15476.087
G2 X136.247 Y104.401 I-8.661 J8.218 E.054
G1 X132.006 Y108.642 E.19896
G2 X131.182 Y108.154 I-4.705 J6.996 E.03179
G1 X124.87 Y101.842 E.2961
G2 X122.715 Y102.581 I5 J18.089 E.07561
G1 X116.067 Y109.23 E.31189
G2 X115.502 Y110.756 I12.363 J5.437 E.05401
; WIPE_START
G1 X116.067 Y109.23 E-.61829
G1 X116.33 Y108.966 E-.14171
; WIPE_END
G1 E-.04 F1800
G1 X115.97 Y116.59 Z5.6 F36000
G1 X115.749 Y121.261 Z5.6
G1 Z5.2
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.673 Y151.349 E1.37919
G2 X148.749 Y148.749 I-15.696 J-36.898 E.18934
G1 X114.967 Y114.967 E1.58478
G2 X115.336 Y117.636 I15.594 J-.796 E.08949
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.396 J5.196 E.05392
; WIPE_START
G1 X122.054 Y110.618 E-.3158
G1 X121.661 Y111.311 E-.30255
G1 X121.398 Y111.574 E-.14165
; WIPE_END
G1 E-.04 F1800
G1 X115.542 Y116.47 Z5.6 F36000
G1 X102.328 Y127.52 Z5.6
G1 Z5.2
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.669 Y148.697 E1.02576
G3 X130.331 Y148.697 I2.331 J1.798 E.17844
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.034 Y138.414 E.31433
G2 X99.749 Y140.899 I2.53 J1.549 E.08564
G1 X98.771 Y141.877 E.0459
G2 X102.744 Y145.58 I38.37 J-37.18 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.678 E.07828
G1 X153.253 Y145.577 E1.12941
G2 X157.226 Y141.874 I-25.275 J-31.101 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.966 Y138.414 I-2.815 J-.936 E.08565
G1 X162.666 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 5.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X133.158 Y118.225
G1 Z5.4
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X132.815 Y118.659 E.017
G3 X127.654 Y108.152 I-4.812 J-4.158 E.77084
G3 X133.16 Y110.777 I.338 J6.378 E.1954
G1 X133.16 Y118.166 E.22704
; WIPE_START
M204 S10000
G1 X132.815 Y118.659 E-.22879
G1 X132.479 Y119.016 E-.18637
G1 X132.117 Y119.348 E-.18636
G1 X131.789 Y119.605 E-.15849
; WIPE_END
G1 E-.04 F1800
G1 X131.476 Y127.231 Z5.8 F36000
G1 X130.542 Y149.947 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X130.553 Y149.97 E.00082
G3 X127.863 Y147.906 I-2.545 J.533 E.41946
G3 X129.643 Y148.48 I.153 J2.572 E.0635
G3 X130.456 Y149.627 I-1.635 J2.022 E.04722
G1 X130.527 Y149.889 E.009
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.89 Y148.297 I-2.161 J.452 E.33004
G3 X129.149 Y148.611 I.105 J2.26 E.04044
G3 X130.156 Y149.991 I-1.141 J1.89 E.05389
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13743
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11462
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X136.263 Y147.939 Z5.8 F36000
G1 X151.012 Y139.062 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.154 Y138.763 E.01096
G3 X153.319 Y137.362 I2.31 J1.195 E.0895
G3 X155.099 Y137.936 I.153 J2.572 E.0635
G3 X151.002 Y139.12 I-1.635 J2.022 E.37612
G1 X151.383 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.345 Y137.753 I2.081 J.738 E.07979
G3 X154.604 Y138.067 I.105 J2.26 E.04044
G3 X151.364 Y139.276 I-1.141 J1.89 E.30414
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13719
G1 X151.65 Y138.681 E-.11467
G1 X151.84 Y138.447 E-.11464
G1 X152.061 Y138.241 E-.11463
G1 X152.307 Y138.067 E-.11465
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04956
; WIPE_END
G1 E-.04 F1800
G1 X145.066 Y137.859 Z5.8 F36000
G1 X103.875 Y137.72 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X104.187 Y137.936 I-1.337 J2.203 E.01179
G3 X102.407 Y137.362 I-1.635 J2.022 E.47849
G3 X103.581 Y137.568 I.153 J2.573 E.03991
G1 X103.822 Y137.693 E.009
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.434 Y137.753 I-1.141 J1.89 E.38577
G3 X103.641 Y138.037 I.105 J2.26 E.0386
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13734
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04942
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z5.8 F36000
G1 X139.911 Y120.718 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89471
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89503
G3 X115.136 Y118.245 I16.102 J-7.694 E.08798
G3 X128.254 Y101.106 I12.867 J-3.742 E.83231
G3 X140.319 Y109.238 I-.255 J13.395 E.5102
G1 X140.672 Y110.102 E.03097
G1 X142.198 Y110.102 E.05062
G1 X142.198 Y112.853 E.09124
G1 X137.318 Y112.853 E.16188
G1 X137.318 Y112.63 E.00737
G1 X133.552 Y112.63 E.12492
G1 X133.552 Y110.639 E.06605
G2 X126.518 Y107.912 I-5.579 J3.955 E.26508
G2 X133.11 Y118.914 I1.485 J6.586 E.84602
G1 X133.552 Y118.361 E.02349
G1 X133.552 Y116.37 E.06605
G1 X137.318 Y116.37 E.12492
G1 X137.318 Y116.147 E.00737
G1 X142.198 Y116.147 E.16188
G1 X142.198 Y118.898 E.09124
G1 X140.667 Y118.898 E.05077
G3 X139.919 Y120.67 I-25.52 J-9.734 E.06383
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82945
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.26 Y100.714 I12.419 J-6.011 E.86491
G3 X140.936 Y109.71 I-.279 J13.82 E.5072
G1 X142.59 Y109.71 E.05084
G1 X142.59 Y113.245 E.10861
G1 X135.79 Y113.245 E.20895
G1 X135.79 Y115.755 E.07714
G1 X142.59 Y115.755 E.20895
G1 X142.59 Y119.29 E.10861
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.466 I-18.331 J-7.038 E.03921
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X143.202 Y122.638 Z5.8 F36000
G1 Z5.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.727 Y121.949 E.05401
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.574 J-38.576 E.1893
G1 X138.689 Y117.311 E1.47492
G1 X140.339 Y117.311 E.05475
G1 X141.578 Y118.55 E.05809
G1 X140.431 Y118.55 E.03805
G1 X140.254 Y118.997 E.01597
G1 X135.441 Y116.84 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.57776
G1 F11779.224
G1 X137.461 Y116.84 E.08804
G1 X141.805 Y116.729 F36000
; LINE_WIDTH: 0.42276
G1 F12000
G1 X141.805 Y116.54 E.00586
G1 X137.9 Y116.54 E.12086
G1 X137.727 Y116.573 E.00547
G1 X137.709 Y116.658 E.00269
; LINE_WIDTH: 0.474544
G1 X137.646 Y116.719 E.00307
; LINE_WIDTH: 0.51583
G1 X137.584 Y116.78 E.00336
; LINE_WIDTH: 0.557117
G1 X137.521 Y116.84 E.00365
; LINE_WIDTH: 0.558222
G1 X137.616 Y116.86 E.00406
; LINE_WIDTH: 0.519144
G1 X137.711 Y116.88 E.00375
; LINE_WIDTH: 0.480067
G1 X137.806 Y116.899 E.00345
; LINE_WIDTH: 0.421913
G1 X137.9 Y116.919 E.00299
G1 X141.805 Y116.919 E.12059
G1 X141.805 Y116.789 E.00399
; WIPE_START
G1 X141.805 Y116.919 E-.04912
G1 X139.934 Y116.919 E-.71088
; WIPE_END
G1 E-.04 F1800
G1 X135.583 Y113.453 Z5.8 F36000
G1 Z5.4
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X134.983 Y112.853 E.02605
G1 X134.45 Y112.853
G1 X135.583 Y113.986 E.04923
G1 X135.583 Y114.519
G1 X133.917 Y112.853 E.0724
G1 X133.383 Y112.853
G1 X135.583 Y115.052 E.09557
G1 X135.583 Y115.586
G1 X133.367 Y113.37 E.09626
G1 X133.367 Y113.904
G1 X135.583 Y116.119 E.09626
G1 X135.078 Y116.147
G1 X133.367 Y114.437 E.07432
G1 X133.367 Y114.97
G1 X134.544 Y116.147 E.05115
G1 X134.011 Y116.147
G1 X133.367 Y115.503 E.02797
; WIPE_START
M204 S10000
G1 X134.011 Y116.147 E-.34594
G1 X134.544 Y116.147 E-.20264
G1 X134.151 Y115.754 E-.21143
; WIPE_END
G1 E-.04 F1800
G1 X133.9 Y116.901 Z5.8 F36000
G1 Z5.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.871 Y118.519 E.05368
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.945 J2.796 E.22145
G1 X142.587 Y151.793 E.43736
G3 X137.939 Y153.291 I-13.988 J-35.433 E.16208
G1 X109.039 Y124.39 E1.3558
G1 X108.182 Y124.79 E.03133
G1 X95.323 Y137.65 E.60328
G3 X92.419 Y132.877 I33.746 J-23.8 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
M73 P64 R8
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I2.001 J-14.656 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.448 E.12814
G1 X131.377 Y154.405 E.0738
G2 X132.402 Y154.301 I-.975 J-14.753 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.676 Y137.648 I-35.731 J-18.466 E.18546
G1 X147.817 Y124.79 E.60321
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.218 J-39.703 E.16194
G1 X104.09 Y142.47 E.43751
G1 X104.21 Y142.386 E.00486
G2 X103.484 Y137.164 I-1.667 J-2.43 E.21652
G1 X122.142 Y118.506 E.87527
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.659 E.21892
G1 X115.502 Y110.756 F36000
G1 F15476.087
G3 X116.067 Y109.23 I12.928 J3.912 E.05401
G1 X122.716 Y102.581 E.31191
G3 X124.87 Y101.842 I7.265 J17.673 E.07559
G1 X131.182 Y108.154 E.29611
G3 X132.006 Y108.642 I-3.881 J7.484 E.03179
G1 X136.251 Y104.397 E.19916
G3 X137.445 Y105.503 I-11.369 J13.468 E.05399
G1 X139.665 Y108.659 F36000
G1 F15476.087
G1 X136.635 Y111.689 E.14212
G1 X135.211 Y111.689 E.04723
G1 X134.97 Y111.943 E.01161
G1 X133.9 Y110.872 E.0502
G1 X133.9 Y110.517 E.01178
G2 X133.081 Y109.544 I-6.708 J4.817 E.04225
G1 X135.441 Y112.16 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.57776
G1 F11779.224
G1 X137.432 Y112.16 E.08678
G1 X141.805 Y112.271 F36000
; LINE_WIDTH: 0.42145
G1 F12000
G1 X141.805 Y112.081 E.00584
G1 X137.875 Y112.081 E.12123
; LINE_WIDTH: 0.444264
G1 X137.757 Y112.111 E.00397
; LINE_WIDTH: 0.48989
G1 X137.639 Y112.14 E.00442
; LINE_WIDTH: 0.535517
G1 X137.521 Y112.169 E.00487
; LINE_WIDTH: 0.53689
G1 X137.58 Y112.229 E.00336
; LINE_WIDTH: 0.49401
G1 X137.639 Y112.288 E.00307
; LINE_WIDTH: 0.438568
G3 X137.744 Y112.456 I-.158 J.215 E.00654
; LINE_WIDTH: 0.421579
G1 X141.805 Y112.46 E.12532
G1 X141.805 Y112.331 E.00399
; WIPE_START
G1 X141.805 Y112.46 E-.04912
G1 X139.934 Y112.458 E-.71088
; WIPE_END
G1 E-.04 F1800
G1 X145.078 Y118.097 Z5.8 F36000
G1 X153.672 Y127.52 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.31 Y148.672 E1.02566
G2 X125.669 Y148.697 I-2.311 J1.823 E.17735
G1 X103.804 Y126.832 E1.02576
G1 X102.328 Y127.52 E.05401
; WIPE_START
G1 X103.804 Y126.832 E-.61876
G1 X104.066 Y127.094 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X109.663 Y121.904 Z5.8 F36000
G1 X122.559 Y109.945 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F15476.087
G2 X121.669 Y111.303 I7.534 J5.909 E.05393
G1 X115.336 Y117.636 E.2971
G3 X114.967 Y114.967 I15.179 J-3.456 E.08948
G1 X148.749 Y148.749 E1.58476
G3 X143.673 Y151.349 I-20.772 J-34.298 E.18934
G1 X114.273 Y121.949 E1.37919
G1 X115.749 Y121.261 E.05401
; WIPE_START
G1 X114.273 Y121.949 E-.61876
G1 X114.536 Y122.212 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X116.321 Y114.791 Z5.8 F36000
G1 X118.555 Y105.502 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F15476.087
G3 X119.747 Y104.395 I9.805 J9.366 E.05401
G1 X123.992 Y108.64 E.19914
G3 X124.816 Y108.156 I3.548 J5.094 E.03174
G1 X131.129 Y101.843 E.29615
G3 X133.272 Y102.568 I-5.652 J20.243 E.07507
G1 X139.933 Y109.229 E.3125
G1 X140.439 Y110.45 E.04385
G1 X141.154 Y110.45 E.02371
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y111.689 E.01801
G1 X140.764 Y111.689 E.03601
; WIPE_START
G1 X141.85 Y111.689 E-.4125
G1 X141.85 Y111.146 E-.20626
G1 X141.587 Y110.883 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X147.016 Y116.248 Z5.8 F36000
G1 X162.666 Y131.714 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F15476.087
G1 X155.966 Y138.414 E.31433
G3 X156.251 Y140.899 I-2.529 J1.549 E.08565
G1 X157.226 Y141.874 E.04575
G3 X153.253 Y145.577 I-29.251 J-27.401 E.1803
G1 X129.178 Y121.502 E1.12941
G3 X126.825 Y121.499 I-1.165 J-8.681 E.07828
G1 X102.744 Y145.58 E1.12972
G3 X98.771 Y141.877 I34.401 J-40.887 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I2.814 J-.936 E.08564
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 5.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.543 Y149.972 E.00082
G3 X127.448 Y153.038 I-2.543 J.528 E.17145
G3 X127.847 Y147.907 I.545 J-2.539 E.24752
G3 X130.447 Y149.63 I.153 J2.593 E.111
G1 X130.525 Y149.89 E.00898
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.874 Y148.298 I-2.161 J.453 E.32963
G3 X129.149 Y148.611 I.122 J2.255 E.04093
G3 X130.156 Y149.991 I-1.14 J1.891 E.0539
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13744
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.0493
; WIPE_END
G1 E-.04 F1800
G1 X123.03 Y148.209 Z6 F36000
G1 X103.875 Y137.72 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.895 Y137.734 E.0008
G3 X101.992 Y142.494 I-1.346 J2.222 E.24246
G3 X102.391 Y137.363 I.552 J-2.538 E.24715
G3 X103.58 Y137.571 I.158 J2.593 E.04041
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.418 Y137.754 I-1.14 J1.89 E.38526
G3 X103.641 Y138.037 I.122 J2.256 E.03909
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13734
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11463
G1 X104.507 Y138.939 E-.11463
G1 X104.627 Y139.216 E-.11465
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04942
; WIPE_END
G1 E-.04 F1800
G1 X112.358 Y139.548 Z6 F36000
G1 X150.996 Y139.107 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.008 Y139.086 E.00081
G3 X153.303 Y137.363 I2.448 J.87 E.10084
G3 X152.904 Y142.494 I.158 J2.593 E.29466
G3 X150.913 Y139.427 I.552 J-2.538 E.13454
G1 X150.981 Y139.165 E.00898
G1 X151.384 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.329 Y137.754 I2.081 J.738 E.07929
G3 X154.604 Y138.067 I.122 J2.255 E.04093
G3 X151.364 Y139.276 I-1.14 J1.89 E.30413
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.1372
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04955
; WIPE_END
G1 E-.04 F1800
G1 X148.139 Y131.764 Z6 F36000
G1 X139.912 Y120.719 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89466
G3 X91.645 Y132.117 I-36.355 J-17.622 E3.00054
G1 X116.098 Y120.714 E.89503
G3 X115.136 Y118.245 I16.107 J-7.696 E.08798
G3 X128.247 Y101.106 I12.867 J-3.742 E.83207
G3 X140.322 Y109.244 I-.247 J13.396 E.51067
G1 X140.672 Y110.102 E.03074
G1 X142.198 Y110.102 E.05062
G1 X142.198 Y112.578 E.08214
G1 X135.398 Y112.578 E.22557
G1 X135.398 Y113.106 E.01751
G1 X133.552 Y113.106 E.06123
G1 X133.552 Y110.639 E.08183
G2 X126.518 Y107.912 I-5.579 J3.955 E.26508
G2 X133.11 Y118.914 I1.485 J6.586 E.84601
G1 X133.552 Y118.361 E.0235
G1 X133.552 Y115.894 E.08183
G1 X135.398 Y115.894 E.06123
G1 X135.398 Y116.422 E.01751
G1 X142.198 Y116.422 E.22557
G1 X142.198 Y118.898 E.08214
G1 X140.667 Y118.898 E.05078
G3 X139.922 Y120.67 I-25.881 J-9.846 E.06379
G1 X140.414 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82942
G3 X91.122 Y131.928 I-36.878 J-17.429 E2.83078
G1 X115.586 Y120.52 E.82942
G3 X128.253 Y100.714 I12.419 J-6.011 E.86468
G3 X140.936 Y109.71 I-.271 J13.82 E.50742
G1 X142.59 Y109.71 E.05084
G1 X142.59 Y112.97 E.10018
G1 X135.79 Y112.97 E.20895
G1 X135.79 Y113.498 E.01622
G1 X133.16 Y113.498 E.08081
G1 X133.16 Y110.777 E.08362
G2 X133.16 Y118.223 I-5.156 J3.723 E.98338
G1 X133.16 Y115.502 E.08362
G1 X135.79 Y115.502 E.08081
G1 X135.79 Y116.03 E.01622
G1 X142.59 Y116.03 E.20895
G1 X142.59 Y119.29 E.10018
G1 X140.934 Y119.29 E.05089
G3 X140.439 Y120.466 I-17.531 J-6.685 E.03921
; WIPE_START
M204 S10000
G1 X142.25 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.254 Y118.997 Z6 F36000
G1 Z5.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.43 Y118.55 E.01596
G1 X141.578 Y118.55 E.03805
G1 X140.426 Y117.398 E.05401
G1 X138.602 Y117.398 E.06052
G1 X107.249 Y148.751 E1.47084
G2 X112.323 Y151.353 I21.649 J-35.974 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X143.202 Y122.638 E.05401
; WIPE_START
G1 X141.727 Y121.949 E-.61876
G1 X141.464 Y122.212 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X135.74 Y117.163 Z6 F36000
G1 X135.453 Y116.91 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.61261
G1 F11058.646
G1 X141.65 Y116.91 E.28764
; WIPE_START
G1 X139.65 Y116.91 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.949 Y116.291 Z6 F36000
G1 Z5.6
G1 E.8 F1800
; Slow Down Start
; LINE_WIDTH: 0.43018
G1 F3000;_EXTRUDE_SET_SPEED
G1 X135.001 Y116.291 E.03318
G1 X135.02 Y116.678 E.01224
G1 X133.949 Y116.678 E.0338
G1 X133.949 Y116.351 E.01033
; Slow Down End
; WIPE_START
G1 X133.949 Y116.678 E-.12436
G1 X135.02 Y116.678 E-.40707
G1 X135.001 Y116.291 E-.14735
G1 X134.787 Y116.291 E-.08122
; WIPE_END
G1 E-.04 F1800
G1 X135.453 Y112.09 Z6 F36000
G1 Z5.6
G1 E.8 F1800
; LINE_WIDTH: 0.6126
G1 F11058.841
G1 X141.65 Y112.09 E.28764
; WIPE_START
G1 X139.65 Y112.09 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.001 Y112.709 Z6 F36000
G1 Z5.6
G1 E.8 F1800
; Slow Down Start
; LINE_WIDTH: 0.43018
G1 F3000;_EXTRUDE_SET_SPEED
G1 X133.949 Y112.709 E.03318
G1 X133.949 Y112.322 E.01222
G1 X135.02 Y112.322 E.0338
G1 X135.004 Y112.649 E.01034
; Slow Down End
G1 X133.081 Y109.544 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X133.9 Y110.517 I-5.891 J5.792 E.04225
G1 X133.9 Y110.872 E.01178
G1 X134.953 Y111.925 E.04936
G1 X135.211 Y111.602 E.01373
G1 X136.722 Y111.602 E.05012
G1 X139.665 Y108.659 E.13804
G1 X140.677 Y111.602 F36000
G1 F15476.087
G1 X141.85 Y111.602 E.03889
G1 X141.85 Y111.146 E.01512
G1 X141.154 Y110.45 E.03263
G1 X140.439 Y110.45 E.02371
G1 X139.933 Y109.229 E.04386
G1 X133.276 Y102.572 E.3123
G2 X131.129 Y101.843 I-5.307 J12.106 E.07529
G1 X124.816 Y108.156 E.29615
G2 X123.992 Y108.64 I2.721 J5.573 E.03174
G1 X119.747 Y104.395 E.19914
G2 X118.559 Y105.506 I7.579 J9.297 E.054
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21891
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X103.484 Y137.164 E.87527
G3 X104.09 Y142.47 I-.945 J2.796 E.22145
G1 X113.416 Y151.796 E.43751
G2 X118.061 Y153.291 I14.863 J-38.21 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.83 J-23.239 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-2 J-14.649 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.346 E.12872
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.976 J-14.76 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.65 I36.646 J-19.025 E.18545
G1 X108.183 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.587 Y151.793 I-9.34 J-36.931 E.16208
G1 X151.91 Y142.47 E.43736
G3 X152.516 Y137.164 I1.588 J-2.506 E.22043
G1 X133.871 Y118.519 E.87466
G1 X133.9 Y117.075 E.04791
G1 X134.075 Y117.075 E.00578
; WIPE_START
G1 X133.9 Y117.075 E-.0662
M73 P65 R8
G1 X133.871 Y118.519 E-.54878
G1 X134.141 Y118.789 E-.14502
; WIPE_END
G1 E-.04 F1800
G1 X135.981 Y111.382 Z6 F36000
G1 X137.441 Y105.507 Z6
G1 Z5.6
G1 E.8 F1800
G1 F15476.087
G2 X136.254 Y104.394 I-7.826 J7.162 E.05403
G1 X132.006 Y108.642 E.19929
G2 X131.182 Y108.154 I-4.708 J7.001 E.03179
G1 X124.87 Y101.842 E.29612
G2 X122.716 Y102.58 I5.22 J18.731 E.07556
G1 X116.082 Y109.214 E.31121
G2 X115.509 Y110.736 I10.489 J4.821 E.054
; WIPE_START
G1 X116.082 Y109.214 E-.61811
G1 X116.346 Y108.95 E-.14189
; WIPE_END
G1 E-.04 F1800
G1 X115.976 Y116.574 Z6 F36000
G1 X115.749 Y121.261 Z6
G1 Z5.6
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.673 Y151.349 E1.37919
G2 X148.749 Y148.749 I-15.696 J-36.898 E.18934
G1 X114.968 Y114.968 E1.58474
G2 X115.336 Y117.636 I15.504 J-.78 E.08947
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.398 J5.198 E.05392
; WIPE_START
G1 X122.054 Y110.618 E-.31577
G1 X121.661 Y111.311 E-.30259
G1 X121.398 Y111.574 E-.14164
; WIPE_END
G1 E-.04 F1800
G1 X115.542 Y116.47 Z6 F36000
G1 X102.328 Y127.52 Z6
G1 Z5.6
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.669 Y148.697 E1.02576
G3 X130.331 Y148.697 I2.331 J1.833 E.1779
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.034 Y138.414 E.31433
G2 X99.749 Y140.899 I2.529 J1.549 E.08564
G1 X98.771 Y141.877 E.0459
G2 X102.744 Y145.58 I38.37 J-37.18 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.679 E.07828
G1 X153.253 Y145.577 E1.12941
G2 X157.226 Y141.874 I-25.275 J-31.101 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.966 Y138.414 I-2.815 J-.936 E.08565
G1 X162.666 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 5.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.553 Y149.97 E.00082
G3 X127.831 Y147.908 I-2.545 J.533 E.41837
G3 X129.643 Y148.48 I.185 J2.57 E.06457
G3 X130.456 Y149.627 I-1.635 J2.022 E.04722
G1 X130.527 Y149.889 E.009
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.858 Y148.299 I-2.161 J.452 E.32903
G3 X129.149 Y148.611 I.139 J2.252 E.04143
G3 X130.156 Y149.991 I-1.14 J1.89 E.0539
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13744
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.0493
; WIPE_END
G1 E-.04 F1800
G1 X123.03 Y148.209 Z6.2 F36000
G1 X103.875 Y137.72 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X104.187 Y137.936 I-1.337 J2.202 E.0118
G3 X102.375 Y137.364 I-1.635 J2.022 E.4774
G3 X103.581 Y137.568 I.185 J2.57 E.04097
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.402 Y137.755 I-1.14 J1.89 E.38476
G3 X103.641 Y138.037 I.139 J2.252 E.03958
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13736
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11462
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.0494
; WIPE_END
G1 E-.04 F1800
G1 X112.358 Y139.548 Z6.2 F36000
G1 X150.996 Y139.107 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.014 Y139.088 E.00087
G3 X153.287 Y137.364 I2.45 J.87 E.10017
G3 X155.099 Y137.936 I.185 J2.57 E.06457
G3 X150.918 Y139.429 I-1.635 J2.022 E.36549
G1 X150.982 Y139.166 E.00898
G1 X151.384 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.313 Y137.755 I2.08 J.738 E.07878
G3 X154.604 Y138.067 I.139 J2.252 E.04142
G3 X151.365 Y139.276 I-1.14 J1.89 E.30408
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13719
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11464
G1 X152.061 Y138.241 E-.11462
G1 X152.191 Y138.15 E-.06039
G1 X152.307 Y138.067 E-.05426
G1 X152.575 Y137.928 E-.11467
G1 X152.698 Y137.885 E-.04954
; WIPE_END
G1 E-.04 F1800
G1 X148.139 Y131.764 Z6.2 F36000
G1 X139.911 Y120.718 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.8947
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89503
G3 X115.136 Y118.245 I16.105 J-7.695 E.08798
G3 X128.239 Y101.106 I12.867 J-3.742 E.83182
G3 X140.325 Y109.25 I-.24 J13.396 E.51113
G1 X140.672 Y110.102 E.03052
G1 X142.198 Y110.102 E.05062
G1 X142.198 Y112.38 E.07557
G1 X135.398 Y112.38 E.22557
G1 X135.398 Y112.808 E.0142
G1 X133.552 Y112.808 E.06123
G1 X133.552 Y110.639 E.07194
G2 X126.518 Y107.912 I-5.579 J3.955 E.26508
G2 X133.11 Y118.914 I1.485 J6.586 E.84601
G1 X133.552 Y118.361 E.0235
G1 X133.552 Y116.192 E.07194
G1 X135.398 Y116.192 E.06123
G1 X135.398 Y116.62 E.0142
G1 X142.198 Y116.62 E.22557
G1 X142.198 Y118.898 E.07557
G1 X140.667 Y118.898 E.05078
G3 X139.919 Y120.67 I-25.602 J-9.765 E.06382
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82945
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.246 Y100.714 I12.419 J-6.011 E.86445
G3 X140.935 Y109.71 I-.264 J13.821 E.50764
G1 X142.59 Y109.71 E.05084
G1 X142.59 Y112.772 E.09409
G1 X135.79 Y112.772 E.20895
G1 X135.79 Y113.2 E.01315
G1 X133.16 Y113.2 E.08081
G1 X133.16 Y110.777 E.07446
G2 X133.16 Y118.223 I-5.156 J3.723 E.98348
G1 X133.16 Y115.8 E.07446
G1 X135.79 Y115.8 E.08081
G1 X135.79 Y116.228 E.01315
G1 X142.59 Y116.228 E.20895
G1 X142.59 Y119.29 E.09409
M73 P65 R7
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.466 I-18.359 J-7.049 E.03921
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X143.202 Y122.638 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.727 Y121.949 E.05401
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.577 J-38.581 E.1893
G1 X138.538 Y117.462 E1.46784
G1 X140.49 Y117.462 E.06477
G1 X141.578 Y118.55 E.05101
G1 X140.43 Y118.55 E.03805
G1 X140.254 Y118.997 E.01596
G1 X134.149 Y117.15 F36000
G1 F15476.087
G1 X133.9 Y117.15 E.00825
G1 X133.871 Y118.519 E.04543
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.945 J2.796 E.22145
G1 X142.587 Y151.793 E.43735
G3 X137.939 Y153.291 I-14.708 J-37.662 E.16209
G1 X109.039 Y124.39 E1.3558
G1 X108.182 Y124.79 E.03133
G1 X95.323 Y137.65 E.60328
G3 X92.419 Y132.877 I33.75 J-23.802 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I2.001 J-14.656 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.448 E.12814
G1 X131.377 Y154.405 E.0738
G2 X132.402 Y154.301 I-.971 J-14.704 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.674 Y137.646 I-35.302 J-18.226 E.18544
G1 X147.817 Y124.79 E.60312
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.218 J-39.703 E.16194
G1 X104.09 Y142.47 E.43751
G2 X103.484 Y137.164 I-1.551 J-2.511 E.22145
G1 X122.142 Y118.506 E.87527
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.659 E.2189
G1 X115.502 Y110.756 F36000
G1 F15476.087
G3 X116.067 Y109.229 I12.926 J3.912 E.05401
G1 X122.716 Y102.58 E.31195
G3 X124.869 Y101.842 I7.479 J18.304 E.07554
G1 X131.182 Y108.154 E.29613
G3 X132.006 Y108.642 I-3.883 J7.487 E.03179
G1 X136.254 Y104.395 E.19928
G3 X137.441 Y105.507 I-6.637 J8.278 E.05403
G1 X139.665 Y108.659 F36000
G1 F15476.087
G1 X136.786 Y111.538 E.13504
G1 X135.211 Y111.538 E.05224
G1 X134.97 Y111.779 E.01131
G1 X134.97 Y111.85 E.00236
G1 X134.878 Y111.85 E.00307
G1 X133.9 Y110.872 E.04586
G1 X133.9 Y110.517 E.01178
G2 X133.081 Y109.544 I-6.709 J4.818 E.04225
; WIPE_START
G1 X133.9 Y110.517 E-.48352
G1 X133.9 Y110.872 E-.13492
G1 X134.164 Y111.136 E-.14156
; WIPE_END
G1 E-.04 F1800
G1 X134.031 Y112.329 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.59394
G1 F11433.343
G1 X134.919 Y112.329 E.03986
; LINE_WIDTH: 0.572838
G1 F11888.632
G1 X134.974 Y112.279 E.00321
; LINE_WIDTH: 0.530634
G1 F12000
G1 X135.029 Y112.229 E.00296
; LINE_WIDTH: 0.48843
G1 X135.084 Y112.179 E.0027
; LINE_WIDTH: 0.446226
G1 X135.139 Y112.129 E.00245
; LINE_WIDTH: 0.404022
G1 X135.194 Y112.079 E.00219
; LINE_WIDTH: 0.40677
G1 X135.293 Y112.019 E.00342
; LINE_WIDTH: 0.477893
G1 X135.392 Y111.959 E.00409
G1 X141.717 Y111.959 E.22419
; WIPE_START
G1 X139.717 Y111.959 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.031 Y116.671 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
; LINE_WIDTH: 0.59394
G1 F11433.343
G1 X134.919 Y116.671 E.03986
; LINE_WIDTH: 0.572838
G1 F11888.632
G1 X134.974 Y116.721 E.00321
; LINE_WIDTH: 0.530634
G1 F12000
G1 X135.029 Y116.771 E.00296
; LINE_WIDTH: 0.48843
G1 X135.084 Y116.821 E.0027
; LINE_WIDTH: 0.446226
G1 X135.139 Y116.871 E.00245
; LINE_WIDTH: 0.404022
G1 X135.194 Y116.921 E.00219
; LINE_WIDTH: 0.40677
G1 X135.293 Y116.981 E.00342
; LINE_WIDTH: 0.477893
G1 X135.392 Y117.041 E.00409
G1 X141.717 Y117.041 E.22419
; WIPE_START
G1 X139.717 Y117.041 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.82 Y121.624 Z6.2 F36000
G1 X153.672 Y127.52 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.331 Y148.697 E1.02576
G2 X125.669 Y148.697 I-2.331 J1.8 E.1784
G1 X103.804 Y126.832 E1.02576
G1 X102.328 Y127.52 E.05401
; WIPE_START
G1 X103.804 Y126.832 E-.61876
G1 X104.066 Y127.094 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X109.663 Y121.905 Z6.2 F36000
G1 X122.552 Y109.953 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F15476.087
G2 X121.661 Y111.311 I8.504 J6.553 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.968 Y114.968 I15.093 J-3.441 E.08945
G1 X148.749 Y148.749 E1.58473
G3 X143.67 Y151.346 I-20.409 J-33.645 E.18939
G1 X114.273 Y121.949 E1.37906
G1 X115.749 Y121.261 E.05401
; WIPE_START
G1 X114.273 Y121.949 E-.61876
G1 X114.536 Y122.212 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X116.321 Y114.791 Z6.2 F36000
G1 X118.555 Y105.502 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F15476.087
G3 X119.747 Y104.395 I9.8 J9.361 E.05401
G1 X123.992 Y108.64 E.19914
G3 X124.816 Y108.156 I3.54 J5.081 E.03174
G1 X131.129 Y101.843 E.29616
G3 X133.275 Y102.571 I-3.203 J12.957 E.07526
G1 X139.932 Y109.229 E.31231
G1 X140.439 Y110.45 E.04387
G1 X141.154 Y110.45 E.02371
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y111.538 E.013
G1 X140.613 Y111.538 E.04102
; WIPE_START
G1 X141.85 Y111.538 E-.46986
G1 X141.85 Y111.146 E-.14891
G1 X141.587 Y110.883 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X147.016 Y116.248 Z6.2 F36000
G1 X162.666 Y131.714 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F15476.087
G1 X155.966 Y138.414 E.31433
G3 X156.251 Y140.899 I-2.53 J1.549 E.08565
G1 X157.226 Y141.874 E.04575
G3 X153.253 Y145.577 I-29.248 J-27.398 E.1803
G1 X129.178 Y121.502 E1.12941
G3 X126.826 Y121.498 I-1.16 J-8.621 E.07825
G1 X102.744 Y145.58 E1.12977
G3 X98.771 Y141.877 I34.412 J-40.899 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I2.815 J-.936 E.08564
M73 P66 R7
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.553 Y149.97 E.00082
G3 X127.815 Y147.909 I-2.545 J.533 E.41784
G3 X129.643 Y148.48 I.201 J2.569 E.0651
G3 X130.456 Y149.627 I-1.635 J2.022 E.04722
G1 X130.527 Y149.889 E.009
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.842 Y148.3 I-2.16 J.452 E.32843
G3 X129.149 Y148.611 I.155 J2.251 E.04192
G3 X130.156 Y149.991 I-1.14 J1.89 E.05389
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13743
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X123.03 Y148.209 Z6.4 F36000
G1 X103.875 Y137.72 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X104.187 Y137.936 I-1.337 J2.203 E.01179
G3 X102.359 Y137.365 I-1.635 J2.022 E.47688
G3 X103.581 Y137.568 I.201 J2.569 E.04151
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.386 Y137.756 I-1.14 J1.89 E.38428
G3 X103.641 Y138.037 I.155 J2.25 E.04007
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13735
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.0494
; WIPE_END
G1 E-.04 F1800
G1 X112.358 Y139.548 Z6.4 F36000
G1 X150.996 Y139.107 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.013 Y139.088 E.00086
G3 X153.271 Y137.365 I2.45 J.87 E.09964
G3 X155.099 Y137.936 I.201 J2.569 E.0651
G3 X150.918 Y139.429 I-1.635 J2.022 E.36549
G1 X150.982 Y139.166 E.00898
G1 X151.384 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.297 Y137.756 I2.081 J.738 E.0783
G3 X154.604 Y138.067 I.155 J2.25 E.04192
G3 X151.364 Y139.276 I-1.14 J1.89 E.30414
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.1372
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04955
; WIPE_END
G1 E-.04 F1800
G1 X148.139 Y131.764 Z6.4 F36000
G1 X139.911 Y120.718 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.8947
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89503
G3 X115.136 Y118.245 I16.104 J-7.695 E.08798
G3 X128.232 Y101.106 I12.867 J-3.741 E.83158
G3 X140.327 Y109.256 I-.233 J13.396 E.51159
G1 X140.672 Y110.102 E.03031
G1 X142.198 Y110.102 E.05063
G1 X142.198 Y112.231 E.07061
G1 X135.398 Y112.231 E.22557
G1 X135.398 Y112.604 E.0124
G1 X133.552 Y112.604 E.06123
G1 X133.552 Y110.639 E.06518
G2 X126.518 Y107.912 I-5.579 J3.955 E.26508
G2 X133.11 Y118.914 I1.485 J6.586 E.84601
G1 X133.552 Y118.361 E.02349
G1 X133.552 Y116.396 E.06518
G1 X135.398 Y116.396 E.06123
G1 X135.398 Y116.769 E.0124
G1 X142.198 Y116.769 E.22557
G1 X142.198 Y118.898 E.07061
G1 X140.667 Y118.898 E.05078
G3 X139.919 Y120.67 I-25.636 J-9.777 E.06382
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82945
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.238 Y100.714 I12.419 J-6.011 E.86422
G3 X140.935 Y109.71 I-.256 J13.821 E.50787
G1 X142.59 Y109.71 E.05084
G1 X142.59 Y112.623 E.0895
G1 X135.79 Y112.623 E.20895
G1 X135.79 Y112.996 E.01148
G1 X133.16 Y112.996 E.08081
G1 X133.16 Y110.777 E.0682
G2 X133.16 Y118.223 I-5.156 J3.723 E.98338
G1 X133.16 Y116.004 E.0682
G1 X135.79 Y116.004 E.08081
G1 X135.79 Y116.377 E.01148
G1 X142.59 Y116.377 E.20895
G1 X142.59 Y119.29 E.0895
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.466 I-18.346 J-7.042 E.03921
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.254 Y118.997 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.43 Y118.55 E.01596
G1 X141.578 Y118.55 E.03805
G1 X140.534 Y117.506 E.04895
G1 X138.494 Y117.506 E.06768
G1 X107.249 Y148.751 E1.46578
G2 X112.323 Y151.353 I21.649 J-35.974 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X143.202 Y122.638 E.05401
; WIPE_START
G1 X141.727 Y121.949 E-.61876
G1 X141.464 Y122.212 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X135.596 Y117.331 Z6.4 F36000
G1 X135.364 Y117.138 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X141.77 Y117.138 E.17747
G1 X133.953 Y116.797 F36000
; LINE_WIDTH: 0.43856
G1 F12000
G1 X134.937 Y116.797 E.0317
; WIPE_START
G1 X133.953 Y116.797 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.364 Y111.862 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; LINE_WIDTH: 0.38292
G1 F12000
G1 X141.77 Y111.862 E.17747
G1 X133.953 Y112.203 F36000
; LINE_WIDTH: 0.43856
G1 F12000
G1 X134.937 Y112.203 E.0317
G1 X133.081 Y109.544 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X133.9 Y110.517 I-5.891 J5.793 E.04225
G1 X133.9 Y110.872 E.01178
G1 X134.83 Y111.802 E.04359
G1 X134.97 Y111.802 E.00467
G1 X134.97 Y111.735 E.00222
G1 X135.211 Y111.494 E.01131
G1 X136.83 Y111.494 E.0537
G1 X139.665 Y108.659 E.13298
G1 X140.569 Y111.494 F36000
G1 F15476.087
G1 X141.85 Y111.494 E.04247
G1 X141.85 Y111.146 E.01154
G1 X141.154 Y110.45 E.03263
G1 X140.439 Y110.45 E.02372
G1 X139.932 Y109.228 E.04388
G1 X133.275 Y102.571 E.31232
G2 X131.13 Y101.843 I-5.392 J12.358 E.07524
G1 X124.816 Y108.156 E.29617
G2 X123.992 Y108.64 I2.718 J5.567 E.03174
G1 X119.747 Y104.395 E.19914
G2 X118.559 Y105.506 I7.523 J9.233 E.054
G1 X116.336 Y108.66 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21889
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X103.484 Y137.164 E.87527
G3 X104.09 Y142.47 I-.945 J2.796 E.22145
G1 X113.416 Y151.796 E.43751
G2 X118.061 Y153.291 I14.863 J-38.208 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.674 Y137.646 E.60313
G2 X163.579 Y132.875 I-32.442 J-23.022 E.18544
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-2 J-14.645 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.448 E.12814
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.976 J-14.76 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.65 I36.649 J-19.027 E.18545
G1 X108.183 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.587 Y151.793 I-10.057 J-39.148 E.16209
G1 X151.91 Y142.47 E.43734
G3 X152.516 Y137.164 I1.551 J-2.511 E.22145
G1 X133.871 Y118.519 E.87466
G1 X133.9 Y117.198 E.04383
G1 X134.197 Y117.198 E.00986
; WIPE_START
G1 X133.9 Y117.198 E-.11292
G1 X133.871 Y118.519 E-.50207
G1 X134.141 Y118.789 E-.14501
; WIPE_END
G1 E-.04 F1800
G1 X135.981 Y111.382 Z6.4 F36000
G1 X137.441 Y105.507 Z6.4
G1 Z6
G1 E.8 F1800
G1 F15476.087
G2 X136.253 Y104.395 I-7.82 J7.165 E.05403
G1 X132.006 Y108.642 E.19927
G2 X131.182 Y108.154 I-4.706 J6.996 E.03179
G1 X124.869 Y101.841 E.29613
G2 X122.717 Y102.579 I5.455 J19.42 E.07551
G1 X116.081 Y109.215 E.31129
G2 X115.508 Y110.737 I10.569 J4.848 E.054
; WIPE_START
G1 X116.081 Y109.215 E-.61812
G1 X116.345 Y108.951 E-.14188
; WIPE_END
G1 E-.04 F1800
G1 X115.976 Y116.574 Z6.4 F36000
G1 X115.749 Y121.261 Z6.4
G1 Z6
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.67 Y151.346 E1.37905
G2 X148.749 Y148.749 I-15.305 J-36.198 E.18939
G1 X114.968 Y114.968 E1.58471
G2 X115.336 Y117.636 I12.797 J-.404 E.0895
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.394 J5.195 E.05392
; WIPE_START
G1 X122.054 Y110.618 E-.31575
G1 X121.661 Y111.311 E-.30261
G1 X121.398 Y111.574 E-.14164
; WIPE_END
G1 E-.04 F1800
G1 X115.542 Y116.47 Z6.4 F36000
G1 X102.328 Y127.52 Z6.4
G1 Z6
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.669 Y148.697 E1.02576
G3 X130.331 Y148.697 I2.331 J1.838 E.17784
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.034 Y138.414 E.31433
G2 X99.749 Y140.899 I2.53 J1.549 E.08564
G1 X98.771 Y141.877 E.0459
G2 X102.744 Y145.58 I38.368 J-37.178 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.679 E.07828
G1 X153.253 Y145.577 E1.12941
G2 X157.226 Y141.874 I-25.274 J-31.1 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.966 Y138.414 I-2.815 J-.936 E.08565
G1 X162.666 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 6.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.543 Y149.972 E.00082
G3 X127.847 Y153.093 I-2.543 J.528 E.15808
G3 X127.799 Y147.91 I.147 J-2.593 E.25931
G3 X130.447 Y149.63 I.201 J2.59 E.1126
G1 X130.525 Y149.89 E.00898
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.825 Y148.301 I-2.161 J.452 E.32807
G3 X129.149 Y148.611 I.171 J2.25 E.04241
G3 X130.156 Y149.991 I-1.141 J1.89 E.05389
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13744
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X136.263 Y147.939 Z6.6 F36000
G1 X151.012 Y139.062 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.154 Y138.763 E.01096
G3 X153.255 Y137.366 I2.31 J1.195 E.08737
G3 X155.099 Y137.936 I.216 J2.569 E.06563
G3 X151.002 Y139.12 I-1.635 J2.022 E.37612
G1 X151.383 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.281 Y137.757 I2.081 J.738 E.07782
G3 X154.604 Y138.067 I.171 J2.25 E.04241
G3 X151.364 Y139.276 I-1.141 J1.89 E.30414
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13719
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11464
G1 X152.061 Y138.241 E-.11462
G1 X152.164 Y138.168 E-.04819
G1 X152.307 Y138.067 E-.06648
G1 X152.575 Y137.928 E-.11464
G1 X152.698 Y137.885 E-.04956
; WIPE_END
G1 E-.04 F1800
G1 X145.066 Y137.859 Z6.6 F36000
G1 X103.875 Y137.72 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X104.187 Y137.936 I-1.338 J2.204 E.0118
G3 X102.343 Y137.366 I-1.635 J2.022 E.47636
G3 X103.581 Y137.568 I.216 J2.569 E.04204
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.37 Y137.757 I-1.141 J1.89 E.3838
G3 X103.641 Y138.037 I.171 J2.25 E.04057
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13736
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.0494
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z6.6 F36000
G1 X139.911 Y120.718 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.8947
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89503
G3 X115.136 Y118.245 I16.103 J-7.695 E.08798
G3 X128.225 Y101.106 I12.87 J-3.739 E.83126
G3 X140.33 Y109.262 I-.226 J13.397 E.51205
G1 X140.672 Y110.102 E.03008
M73 P67 R7
G1 X142.198 Y110.102 E.05063
G1 X142.198 Y112.116 E.06681
G1 X135.398 Y112.116 E.22557
G1 X135.398 Y112.458 E.01134
G1 X133.552 Y112.458 E.06123
G1 X133.552 Y110.639 E.06033
G2 X126.518 Y107.912 I-5.579 J3.955 E.26508
G2 X133.11 Y118.915 I1.485 J6.586 E.84599
G1 X133.552 Y118.361 E.02352
G1 X133.552 Y116.542 E.06033
G1 X135.398 Y116.542 E.06123
G1 X135.398 Y116.884 E.01134
G1 X142.198 Y116.884 E.22557
G1 X142.198 Y118.898 E.06681
G1 X140.667 Y118.898 E.05078
G3 X139.919 Y120.67 I-25.664 J-9.788 E.06382
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82945
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.231 Y100.714 I12.436 J-6.001 E.86362
G3 X140.935 Y109.71 I-.249 J13.821 E.50809
G1 X142.59 Y109.71 E.05084
G1 X142.59 Y112.508 E.08598
G1 X135.79 Y112.508 E.20895
G1 X135.79 Y112.85 E.01051
G1 X133.16 Y112.85 E.08081
G1 X133.16 Y110.777 E.06371
G2 X133.16 Y118.223 I-5.156 J3.723 E.98338
G1 X133.16 Y116.15 E.06371
G1 X135.79 Y116.15 E.08081
G1 X135.79 Y116.492 E.01051
G1 X142.59 Y116.492 E.20895
G1 X142.59 Y119.29 E.08598
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.466 I-18.341 J-7.04 E.03921
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X143.202 Y122.638 Z6.6 F36000
G1 Z6.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.727 Y121.949 E.05401
G1 X112.323 Y151.353 E1.37939
G3 X107.249 Y148.751 I16.575 J-38.578 E.1893
G1 X138.768 Y117.232 E1.47864
G1 X140.26 Y117.232 E.04949
G1 X141.578 Y118.55 E.06181
G1 X140.43 Y118.55 E.03805
G1 X140.254 Y118.997 E.01596
G1 X133.9 Y116.901 F36000
G1 F15476.087
G1 X133.871 Y118.519 E.05368
G1 X152.516 Y137.164 E.87466
G2 X151.91 Y142.47 I.945 J2.796 E.22147
G1 X142.587 Y151.793 E.43736
G3 X137.939 Y153.291 I-13.987 J-35.431 E.16208
G1 X109.039 Y124.39 E1.3558
G1 X108.183 Y124.79 E.03133
G1 X95.323 Y137.65 E.60328
G3 X92.419 Y132.877 I33.745 J-23.799 E.18545
G1 X93.8 Y131.496 E.06477
G1 X98.569 Y129.273 E.17455
G1 X123.598 Y154.301 E1.17415
G2 X124.623 Y154.405 I2.001 J-14.656 E.03419
G1 X126.196 Y152.832 E.0738
G2 X129.804 Y152.832 I1.804 J-2.335 E.12879
G1 X131.377 Y154.405 E.0738
G2 X132.402 Y154.301 I-.975 J-14.748 E.03419
G1 X157.431 Y129.273 E1.17415
G1 X162.2 Y131.496 E.17455
G1 X163.579 Y132.875 E.06468
G3 X160.674 Y137.646 I-35.39 J-18.275 E.18545
G1 X147.817 Y124.79 E.60314
G1 X146.961 Y124.39 E.03133
G1 X118.061 Y153.291 E1.3558
G3 X113.416 Y151.796 I10.218 J-39.703 E.16194
G1 X104.09 Y142.47 E.43751
G2 X103.484 Y137.164 I-1.588 J-2.506 E.22044
G1 X122.142 Y118.506 E.87527
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.336 Y108.66 E.21887
G1 X115.508 Y110.738 F36000
G1 F15476.087
G3 X116.081 Y109.215 I11.187 J3.34 E.054
G1 X122.718 Y102.579 E.31134
G3 X124.869 Y101.841 I7.731 J19.049 E.07548
G1 X131.182 Y108.154 E.29614
G3 X132.006 Y108.642 I-3.882 J7.486 E.03179
G1 X136.251 Y104.397 E.19916
G3 X137.442 Y105.506 I-9.747 J11.66 E.05399
G1 X139.665 Y108.659 F36000
G1 F15476.087
G1 X136.556 Y111.768 E.14583
G1 X135.05 Y111.768 E.04997
G1 X135.05 Y112.022 E.00842
G1 X133.9 Y110.872 E.05392
G1 X133.9 Y110.517 E.01178
G2 X133.081 Y109.544 I-6.711 J4.82 E.04225
; WIPE_START
G1 X133.9 Y110.517 E-.48353
G1 X133.9 Y110.872 E-.13491
G1 X134.164 Y111.136 E-.14156
; WIPE_END
G1 E-.04 F1800
G1 X126.571 Y110.362 Z6.6 F36000
G1 X122.553 Y109.952 Z6.6
G1 Z6.2
G1 E.8 F1800
G1 F15476.087
G2 X121.662 Y111.31 I8.368 J6.463 E.05392
G1 X115.336 Y117.636 E.29678
G3 X114.969 Y114.969 I12.404 J-3.067 E.08948
G1 X148.749 Y148.749 E1.5847
G3 X143.673 Y151.349 I-20.773 J-34.299 E.18934
G1 X114.273 Y121.949 E1.37919
G1 X115.749 Y121.261 E.05401
; WIPE_START
G1 X114.273 Y121.949 E-.61876
G1 X114.536 Y122.212 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X116.321 Y114.791 Z6.6 F36000
G1 X118.555 Y105.502 Z6.6
G1 Z6.2
G1 E.8 F1800
G1 F15476.087
G3 X119.747 Y104.395 I9.79 J9.351 E.05401
G1 X123.992 Y108.64 E.19914
G3 X124.816 Y108.156 I3.544 J5.087 E.03174
G1 X131.13 Y101.842 E.29618
G3 X133.274 Y102.57 I-3.289 J13.212 E.07521
G1 X139.932 Y109.228 E.31232
G1 X140.439 Y110.45 E.04389
G1 X141.154 Y110.45 E.02372
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y111.768 E.02064
G1 X140.843 Y111.768 E.03338
; WIPE_START
G1 X141.85 Y111.768 E-.38238
G1 X141.85 Y111.146 E-.23639
G1 X141.587 Y110.883 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X146.073 Y117.058 Z6.6 F36000
G1 X153.672 Y127.52 Z6.6
G1 Z6.2
G1 E.8 F1800
G1 F15476.087
G1 X152.196 Y126.832 E.05401
G1 X130.331 Y148.697 E1.02576
G1 X130.27 Y148.622 E.0032
G2 X125.669 Y148.697 I-2.27 J1.875 E.17517
G1 X103.804 Y126.832 E1.02576
G1 X102.328 Y127.52 E.05401
G1 X162.666 Y131.714 F36000
G1 F15476.087
G1 X155.966 Y138.414 E.31433
G3 X156.251 Y140.899 I-2.53 J1.549 E.08565
G1 X157.226 Y141.874 E.04575
G3 X153.253 Y145.577 I-29.252 J-27.402 E.1803
G1 X129.178 Y121.502 E1.12941
G3 X126.825 Y121.499 I-1.164 J-8.671 E.07828
G1 X102.744 Y145.58 E1.12973
G3 X98.771 Y141.877 I34.404 J-40.891 E.18024
G1 X99.749 Y140.899 E.0459
G3 X100.034 Y138.414 I3.06 J-.908 E.08525
G1 X93.334 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 6.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X94.748 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.553 Y149.97 E.00082
G3 X127.783 Y147.911 I-2.545 J.532 E.41682
G3 X129.643 Y148.48 I.231 J2.569 E.06617
G3 X130.456 Y149.627 I-1.636 J2.022 E.04722
G1 X130.527 Y149.889 E.009
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.809 Y148.303 I-2.161 J.452 E.3276
G3 X129.149 Y148.611 I.186 J2.251 E.04291
G3 X130.156 Y149.991 I-1.141 J1.89 E.05389
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13743
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.948 Z6.8 F36000
G1 X150.996 Y139.107 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.008 Y139.086 E.00081
G3 X153.239 Y137.367 I2.448 J.87 E.09871
G3 X153.319 Y142.55 I.217 J2.589 E.28246
G3 X150.913 Y139.427 I.138 J-2.594 E.14845
G1 X150.981 Y139.165 E.00898
G1 X151.383 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.265 Y137.758 I2.08 J.737 E.07733
G3 X154.604 Y138.067 I.186 J2.251 E.0429
G3 X151.364 Y139.276 I-1.141 J1.889 E.30402
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.1372
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.151 Y138.177 E-.15644
G1 X152.307 Y138.067 E-.07258
G1 X152.575 Y137.928 E-.11465
G1 X152.699 Y137.884 E-.04984
; WIPE_END
G1 E-.04 F1800
G1 X145.066 Y137.859 Z6.8 F36000
G1 X103.875 Y137.72 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.896 Y137.734 E.0008
G3 X102.407 Y142.55 I-1.346 J2.222 E.22855
G3 X102.327 Y137.367 I.138 J-2.594 E.25893
G3 X103.58 Y137.571 I.223 J2.589 E.04255
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.067 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.354 Y137.758 I-1.141 J1.89 E.38331
G3 X103.641 Y138.037 I.186 J2.251 E.04106
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13736
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11462
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.0494
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z6.8 F36000
G1 X139.911 Y120.718 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89469
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89503
G3 X115.136 Y118.245 I16.107 J-7.696 E.08799
G3 X128.217 Y101.106 I12.87 J-3.739 E.83101
G3 X140.333 Y109.269 I-.219 J13.397 E.51252
G1 X140.672 Y110.102 E.02985
G1 X142.198 Y110.102 E.05063
G1 X142.198 Y112.029 E.06393
G1 X135.398 Y112.029 E.22557
G1 X135.398 Y112.352 E.01071
G1 X133.552 Y112.352 E.06123
G1 X133.552 Y110.639 E.05682
G2 X127.03 Y107.818 I-5.585 J3.961 E.24786
G2 X133.11 Y118.914 I.972 J6.682 E.86347
G1 X133.552 Y118.361 E.0235
G1 X133.552 Y116.648 E.05682
G1 X135.398 Y116.648 E.06123
G1 X135.398 Y116.971 E.01071
G1 X142.198 Y116.971 E.22557
G1 X142.198 Y118.898 E.06393
G1 X140.667 Y118.898 E.05078
G3 X139.919 Y120.67 I-25.754 J-9.822 E.06382
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82944
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.224 Y100.714 I12.436 J-6 E.86338
G3 X140.935 Y109.71 I-.242 J13.821 E.50832
G1 X142.59 Y109.71 E.05084
G1 X142.59 Y112.421 E.08331
G1 X135.79 Y112.421 E.20895
G1 X135.79 Y112.744 E.00992
G1 X133.16 Y112.744 E.08081
G1 X133.16 Y110.777 E.06046
G2 X133.16 Y118.223 I-5.156 J3.723 E.98338
G1 X133.16 Y116.256 E.06046
G1 X135.79 Y116.256 E.08081
G1 X135.79 Y116.579 E.00992
G1 X142.59 Y116.579 E.20895
G1 X142.59 Y119.29 E.08331
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.466 I-18.387 J-7.058 E.03921
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.254 Y118.997 Z6.8 F36000
G1 Z6.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.43 Y118.55 E.01596
G1 X141.578 Y118.55 E.03805
G1 X140.347 Y117.319 E.05773
G1 X138.681 Y117.319 E.05526
G1 X107.249 Y148.751 E1.47456
G2 X112.323 Y151.353 I21.649 J-35.974 E.1893
G1 X141.727 Y121.949 E1.37939
G1 X143.202 Y122.638 E.05401
; WIPE_START
G1 X141.727 Y121.949 E-.61876
G1 X141.464 Y122.212 E-.14125
; WIPE_END
M73 P68 R7
G1 E-.04 F1800
G1 X140.952 Y114.597 Z6.8 F36000
G1 X140.757 Y111.681 Z6.8
G1 Z6.4
G1 E.8 F1800
G1 F15476.087
G1 X141.85 Y111.681 E.03626
G1 X141.85 Y111.146 E.01775
G1 X141.154 Y110.45 E.03263
G1 X140.439 Y110.45 E.02372
G1 X139.932 Y109.228 E.04391
G1 X133.274 Y102.57 E.31233
G2 X131.13 Y101.842 I-5.475 J12.608 E.07519
G1 X124.816 Y108.156 E.29619
G2 X123.992 Y108.64 I2.718 J5.568 E.03174
G1 X119.747 Y104.395 E.19914
G2 X118.555 Y105.502 I8.591 J10.452 E.05401
G1 X116.336 Y108.66 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21886
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X103.484 Y137.164 E.87527
G3 X104.09 Y142.47 I-.945 J2.796 E.22145
G1 X113.416 Y151.796 E.43751
G2 X118.061 Y153.291 I14.863 J-38.21 E.16194
G1 X146.961 Y124.39 E1.3558
G1 X147.817 Y124.79 E.03133
G1 X160.676 Y137.648 E.60321
G2 X163.579 Y132.875 I-32.831 J-23.24 E.18546
G1 X162.2 Y131.496 E.06468
G1 X157.431 Y129.273 E.17455
G1 X132.402 Y154.301 E1.17415
G3 X131.377 Y154.405 I-1.995 J-14.592 E.03419
G1 X129.804 Y152.832 E.0738
G3 X126.196 Y152.832 I-1.804 J-2.448 E.12814
G1 X124.623 Y154.405 E.0738
G3 X123.598 Y154.301 I.976 J-14.76 E.03419
G1 X98.569 Y129.273 E1.17415
G1 X93.8 Y131.496 E.17455
G1 X92.419 Y132.877 E.06477
G2 X95.323 Y137.65 I36.646 J-19.025 E.18545
G1 X108.183 Y124.79 E.60328
G1 X109.039 Y124.39 E.03133
G1 X137.939 Y153.291 E1.3558
G2 X142.587 Y151.793 I-9.338 J-36.925 E.16208
G1 X151.91 Y142.47 E.43736
G3 X152.516 Y137.164 I1.587 J-2.506 E.22045
G1 X133.871 Y118.519 E.87466
G1 X133.9 Y116.996 E.05054
G1 X133.995 Y116.996 E.00315
; WIPE_START
G1 X133.9 Y116.996 E-.03607
G1 X133.871 Y118.519 E-.57891
G1 X134.141 Y118.789 E-.14502
; WIPE_END
G1 E-.04 F1800
G1 X133.271 Y111.206 Z6.8 F36000
G1 X133.081 Y109.544 Z6.8
G1 Z6.4
G1 E.8 F1800
G1 F15476.087
G3 X133.9 Y110.517 I-5.838 J5.751 E.04225
G1 X133.9 Y110.872 E.01178
G1 X135.032 Y112.004 E.05308
G1 X135.05 Y111.681 E.01073
G1 X136.643 Y111.681 E.05285
G1 X139.665 Y108.659 E.14175
G1 X137.441 Y105.506 F36000
G1 F15476.087
G2 X136.251 Y104.397 I-10.779 J10.378 E.05399
G1 X132.006 Y108.642 E.19916
G2 X131.182 Y108.154 I-4.705 J6.996 E.03179
G1 X124.869 Y101.841 E.29615
G2 X122.718 Y102.578 I5.714 J20.18 E.07546
G1 X116.081 Y109.216 E.31137
G2 X115.508 Y110.738 I10.641 J4.872 E.054
; WIPE_START
G1 X116.081 Y109.216 E-.61812
G1 X116.345 Y108.952 E-.14188
; WIPE_END
G1 E-.04 F1800
G1 X115.976 Y116.575 Z6.8 F36000
G1 X115.749 Y121.261 Z6.8
G1 Z6.4
G1 E.8 F1800
G1 F15476.087
G1 X114.273 Y121.949 E.05401
G1 X143.673 Y151.349 E1.37919
G2 X148.749 Y148.749 I-15.694 J-36.894 E.18934
G1 X114.969 Y114.969 E1.58468
G2 X115.336 Y117.636 I12.747 J-.395 E.08947
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.391 J5.193 E.05392
; WIPE_START
G1 X122.054 Y110.618 E-.31578
G1 X121.661 Y111.311 E-.30257
G1 X121.398 Y111.574 E-.14165
; WIPE_END
G1 E-.04 F1800
G1 X115.542 Y116.47 Z6.8 F36000
G1 X102.328 Y127.52 Z6.8
G1 Z6.4
G1 E.8 F1800
G1 F15476.087
G1 X103.804 Y126.832 E.05401
G1 X125.669 Y148.697 E1.02576
G3 X130.331 Y148.697 I2.331 J1.842 E.17777
G1 X152.196 Y126.832 E1.02576
G1 X153.672 Y127.52 E.05401
G1 X93.334 Y131.714 F36000
G1 F15476.087
G1 X100.034 Y138.414 E.31433
G2 X99.749 Y140.899 I2.529 J1.549 E.08564
G1 X98.771 Y141.877 E.0459
G2 X102.744 Y145.58 I38.368 J-37.177 E.18024
G1 X126.825 Y121.499 E1.12972
G2 X129.178 Y121.502 I1.188 J-8.678 E.07828
G1 X153.253 Y145.577 E1.12941
G2 X157.226 Y141.874 I-25.279 J-31.105 E.1803
G1 X156.251 Y140.899 E.04575
G2 X155.966 Y138.414 I-2.815 J-.936 E.08565
G1 X162.666 Y131.714 E.31433
; CHANGE_LAYER
; Z_HEIGHT: 6.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X161.252 Y133.128 E-.76
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
G1 X130.542 Y149.947
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.554 Y149.969 E.00083
G3 X127.767 Y147.912 I-2.545 J.532 E.41627
G3 X129.353 Y148.276 I.227 J2.652 E.05485
G3 X130.457 Y149.627 I-1.344 J2.226 E.05903
G1 X130.527 Y149.889 E.00901
G1 X130.17 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.793 Y148.304 I-2.161 J.452 E.32709
G3 X128.881 Y148.473 I.223 J2.152 E.03418
G3 X130.157 Y149.991 I-.872 J2.029 E.0632
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13746
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11462
G1 X130.045 Y151.327 E-.15036
G1 X129.963 Y151.517 E-.07867
G1 X129.806 Y151.775 E-.11467
G1 X129.724 Y151.876 E-.04955
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.948 Z7 F36000
G1 X150.996 Y139.107 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.014 Y139.088 E.00087
G3 X153.223 Y137.368 I2.451 J.87 E.09805
G3 X154.809 Y137.731 I.228 J2.652 E.05485
G3 X150.918 Y139.429 I-1.344 J2.226 E.37733
G1 X150.982 Y139.166 E.00898
G1 X151.383 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.249 Y137.759 I2.081 J.738 E.07683
G3 X154.336 Y137.928 I.223 J2.152 E.03418
G3 X151.364 Y139.276 I-.872 J2.029 E.31346
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13719
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11464
G1 X152.061 Y138.241 E-.11463
G1 X152.307 Y138.067 E-.11465
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04956
; WIPE_END
G1 E-.04 F1800
G1 X145.066 Y137.859 Z7 F36000
G1 X103.875 Y137.72 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X102.311 Y137.368 I-1.344 J2.226 E.48713
G3 X103.58 Y137.571 I.227 J2.652 E.04306
G1 X103.822 Y137.693 E.00899
G1 X103.693 Y138.066 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.338 Y137.759 I-1.14 J1.891 E.38286
G3 X103.425 Y137.928 I.222 J2.152 E.03418
G3 X103.642 Y138.036 I-.872 J2.029 E.00744
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13738
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11463
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04937
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z7 F36000
G1 X139.912 Y120.719 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89466
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89503
G3 X115.136 Y118.245 I16.108 J-7.697 E.08798
G3 X128.21 Y101.106 I12.87 J-3.739 E.83077
G3 X140.335 Y109.274 I-.212 J13.398 E.51297
G1 X140.672 Y110.102 E.02964
G1 X142.198 Y110.102 E.05063
G1 X142.198 Y111.965 E.06181
G1 X135.398 Y111.965 E.22557
G1 X135.398 Y112.278 E.01036
G1 X133.552 Y112.278 E.06123
G1 X133.552 Y110.639 E.05434
G2 X127.03 Y107.818 I-5.588 J3.967 E.24782
G2 X133.11 Y118.914 I.971 J6.682 E.86358
G1 X133.552 Y118.361 E.02349
G1 X133.552 Y116.722 E.05434
G1 X135.398 Y116.722 E.06123
G1 X135.398 Y117.035 E.01036
G1 X142.198 Y117.035 E.22557
G1 X142.198 Y118.898 E.06181
G1 X140.667 Y118.898 E.05078
G3 X139.922 Y120.67 I-25.958 J-9.876 E.06379
G1 X140.414 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82942
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.216 Y100.714 I12.436 J-6 E.86315
G3 X140.935 Y109.71 I-.234 J13.821 E.50854
G1 X142.59 Y109.71 E.05084
G1 X142.59 Y112.357 E.08135
G1 X135.79 Y112.357 E.20895
G1 X135.79 Y112.67 E.0096
G1 X133.16 Y112.67 E.08081
G1 X133.16 Y110.777 E.05816
G2 X133.16 Y118.223 I-5.156 J3.723 E.98338
G1 X133.16 Y116.33 E.05816
G1 X135.79 Y116.33 E.08081
G1 X135.79 Y116.643 E.0096
G1 X142.59 Y116.643 E.20895
G1 X142.59 Y119.29 E.08135
G1 X140.934 Y119.29 E.05089
G3 X140.439 Y120.466 I-17.594 J-6.71 E.03921
; WIPE_START
M204 S10000
G1 X142.25 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.431 Y118.55 Z7 F36000
G1 Z6.6
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.389345
G1 F3000;_EXTRUDE_SET_SPEED
G1 X140.381 Y118.636 E.0028
G3 X139.49 Y120.751 I-30.255 J-11.503 E.0648
G1 X139.462 Y120.88 E.00373
G1 X139.568 Y120.959 E.00373
G1 X163.712 Y132.218 E.75203
G1 X163.823 Y132.301 E.0039
G1 X163.787 Y132.434 E.0039
G3 X92.329 Y132.676 I-35.79 J-17.933 E2.49275
G1 X92.174 Y132.302 E.01143
G1 X92.284 Y132.219 E.00388
G1 X116.431 Y120.959 E.75214
G1 X116.538 Y120.881 E.00373
G1 X116.51 Y120.751 E.00373
G1 X115.923 Y119.405 E.04144
G3 X115.517 Y118.227 I9.645 J-3.989 E.03521
; Slow Down End
G1 X115.508 Y110.739 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X116.08 Y109.216 I11.251 J3.361 E.054
G1 X122.719 Y102.578 E.31141
G3 X124.869 Y101.841 I8 J19.842 E.07543
G1 X131.182 Y108.154 E.29615
G3 X132.006 Y108.642 I-3.882 J7.485 E.03179
G1 X136.251 Y104.397 E.19916
G3 X137.441 Y105.506 I-9.44 J11.325 E.05399
G1 X139.665 Y108.659 F36000
G1 F15476.087
M73 P69 R7
G1 X136.707 Y111.617 E.13875
G1 X135.05 Y111.617 E.05498
G1 X135.05 Y111.929 E.01036
G1 X134.957 Y111.929 E.00307
G1 X133.9 Y110.872 E.04958
G1 X133.9 Y110.517 E.01178
G2 X133.08 Y109.545 I-6.474 J4.63 E.04225
; WIPE_START
G1 X133.9 Y110.517 E-.4835
G1 X133.9 Y110.872 E-.13492
G1 X134.164 Y111.136 E-.14158
; WIPE_END
G1 E-.04 F1800
G1 X134.07 Y117.071 Z7 F36000
G1 Z6.6
G1 E.8 F1800
G1 F15476.087
G1 X133.9 Y117.071 E.00562
G1 X133.871 Y118.519 E.04806
G1 X152.22 Y136.868 E.8608
G2 X150.914 Y142.096 I1.249 J3.09 E.20818
G2 X151.639 Y142.741 I2.626 J-2.226 E.03229
G1 X143.269 Y151.111 E.39265
G1 X143.385 Y151.061 E.00418
G1 X114.557 Y122.233 E1.35238
G1 X116.033 Y121.545 E.05401
G1 X122.552 Y109.953 F36000
G1 F15476.087
G2 X121.661 Y111.311 I8.505 J6.554 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.969 Y114.969 I12.36 J-3.058 E.08946
G1 X148.474 Y148.474 E1.57178
G2 X149.851 Y147.606 I-11.733 J-20.148 E.05402
; WIPE_START
G1 X148.474 Y148.474 E-.61867
G1 X148.211 Y148.211 E-.14133
; WIPE_END
G1 E-.04 F1800
G1 X153.525 Y142.733 Z7 F36000
G1 X156.416 Y139.753 Z7
G1 Z6.6
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G3 X155.778 Y141.79 I-3.015 J.174 E.06043
G1 X155.342 Y142.243 E.01744
G3 X153.82 Y142.898 I-1.863 J-2.235 E.04654
G1 X153.063 Y142.895 E.02098
G1 X152.618 Y142.799 E.01262
G1 X151.924 Y142.495 E.02097
G1 X151.572 Y142.246 E.01197
G1 X151.188 Y141.857 E.01514
G1 X150.832 Y141.337 E.01744
G3 X150.676 Y138.926 I2.601 J-1.379 E.06898
G1 X151.027 Y138.255 E.02098
G3 X153.199 Y137.007 I2.409 J1.678 E.0717
G1 X153.849 Y137.016 E.01802
G3 X156.407 Y139.694 I-.389 J2.933 E.11086
; Slow Down End
; WIPE_START
G1 X156.358 Y139.342 E-.13518
G1 X156.247 Y138.952 E-.15383
G1 X156.085 Y138.582 E-.15382
G1 X155.873 Y138.236 E-.15387
G1 X155.616 Y137.923 E-.15382
G1 X155.598 Y137.906 E-.00949
; WIPE_END
G1 E-.04 F1800
G1 X149.906 Y142.991 Z7 F36000
G1 X139.199 Y152.553 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X137.628 Y152.98 I-6.893 J-22.28 E.05402
G1 X109.322 Y124.674 E1.32788
G1 X107.403 Y125.569 E.07026
G1 X95.593 Y137.379 E.55403
G3 X92.698 Y132.598 I33.892 J-23.785 E.18555
G3 X93.618 Y131.997 I1.285 J.963 E.03719
G1 X99.76 Y138.14 E.28814
G1 X99.676 Y138.277 E.00536
G2 X99.458 Y141.19 I2.877 J1.68 E.10031
G1 X99.038 Y141.61 E.01971
G2 X103.011 Y145.313 I38.016 J-36.82 E.18024
G1 X126.825 Y121.499 E1.11716
G2 X129.178 Y121.502 I1.188 J-8.668 E.07828
G1 X152.985 Y145.309 E1.11683
G2 X156.959 Y141.607 I-24.998 J-30.824 E.1803
G1 X156.542 Y141.19 E.01955
G2 X156.24 Y138.139 I-3.321 J-1.212 E.10519
G1 X162.382 Y131.997 E.28814
G3 X163.298 Y132.595 I-.362 J1.557 E.03702
G3 X160.405 Y137.377 I-35.299 J-18.09 E.18557
G1 X148.597 Y125.569 E.55392
G1 X146.678 Y124.674 E.07026
G1 X118.372 Y152.98 E1.32788
G3 X116.801 Y152.554 I5.321 J-22.705 E.05402
G1 X106.147 Y147.606 F36000
G1 F15476.087
G2 X107.522 Y148.478 I13.155 J-19.236 E.05402
G1 X138.24 Y117.76 E1.44103
G1 X140.324 Y117.76 E.06913
G1 X139.947 Y117.383 E.01769
G1 X140.411 Y117.383 E.0154
G1 X141.578 Y118.55 E.05473
G1 X140.868 Y118.55 E.02352
G1 X140.938 Y118.374 E.00626
G1 X140.736 Y118.173 E.00946
G1 X140.174 Y118.173 E.01865
G3 X138.953 Y121.072 I-41.413 J-15.724 E.10439
G1 X141.443 Y122.233 E.09112
G1 X112.612 Y151.064 E1.35252
G1 X112.734 Y151.114 E.00437
G1 X104.361 Y142.741 E.39279
G2 X103.78 Y136.868 I-1.865 J-2.78 E.23958
G1 X122.142 Y118.506 E.86142
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.336 Y108.66 E.21885
G1 X118.555 Y105.502 F36000
G1 F15476.087
G3 X119.747 Y104.395 I9.783 J9.346 E.05401
G1 X123.992 Y108.64 E.19914
G3 X124.816 Y108.156 I3.542 J5.083 E.03174
G1 X131.13 Y101.842 E.2962
G3 X133.273 Y102.57 I-3.378 J13.472 E.07517
G1 X139.931 Y109.228 E.31234
G1 X140.439 Y110.45 E.04392
G1 X141.154 Y110.45 E.02372
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y111.617 E.01563
G1 X140.693 Y111.617 E.03839
; WIPE_START
G1 X141.85 Y111.617 E-.43973
G1 X141.85 Y111.146 E-.17903
G1 X141.587 Y110.883 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X139.448 Y117.398 Z7 F36000
G1 Z6.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X137.916 Y117.398 E.04245
G1 X131.271 Y149.893 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X130.599 Y148.429 I-3.332 J.644 E.05393
G1 X151.913 Y127.115 E.99987
G1 X157.147 Y129.556 E.1916
G1 X132.826 Y153.878 E1.14096
G3 X131.024 Y154.052 I-3.397 J-25.735 E.06008
G1 X130.075 Y153.103 E.04452
G3 X125.925 Y153.103 I-2.075 J-2.729 E.14785
G1 X124.976 Y154.052 E.04452
G3 X123.174 Y153.878 I1.594 J-25.909 E.06008
G1 X98.853 Y129.556 E1.14096
G1 X104.087 Y127.115 E.1916
G1 X125.401 Y148.429 E.99987
G3 X126.677 Y147.444 I2.709 J2.189 E.05395
; WIPE_START
G1 X125.898 Y147.916 E-.34604
G1 X125.401 Y148.429 E-.27131
G1 X125.136 Y148.164 E-.14266
; WIPE_END
G1 E-.04 F1800
G1 X130.96 Y150.297 Z7 F36000
G1 Z6.6
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G3 X130.731 Y151.639 I-3.18 J.148 E.03801
G1 X130.433 Y152.194 E.01744
G3 X128.364 Y153.442 I-2.421 J-1.675 E.06899
G1 X127.607 Y153.439 E.02097
G1 X127.162 Y153.343 E.01261
G1 X126.468 Y153.039 E.02098
G3 X125.449 Y148.999 I1.543 J-2.538 E.12794
G1 X125.82 Y148.49 E.01744
G3 X127.743 Y147.551 I2.196 J2.057 E.06062
G1 X128.393 Y147.561 E.01801
G1 X128.838 Y147.657 E.01261
G1 X129.532 Y147.961 E.02098
G3 X130.952 Y150.238 I-1.572 J2.561 E.07708
; Slow Down End
; WIPE_START
G1 X130.902 Y149.886 E-.13512
G1 X130.791 Y149.496 E-.15391
G1 X130.629 Y149.126 E-.15381
G1 X130.417 Y148.781 E-.15384
G1 X130.161 Y148.467 E-.15385
G1 X130.142 Y148.45 E-.00947
; WIPE_END
G1 E-.04 F1800
G1 X122.945 Y145.91 Z7 F36000
G1 X105.504 Y139.753 Z7
G1 Z6.6
G1 E.8 F1800
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G3 X104.867 Y141.79 I-3.015 J.174 E.06043
G1 X104.43 Y142.243 E.01744
G3 X102.908 Y142.898 I-1.863 J-2.235 E.04655
G1 X102.151 Y142.895 E.02097
G3 X99.993 Y138.455 I.389 J-2.933 E.16177
G1 X100.364 Y137.946 E.01744
G3 X102.287 Y137.007 I2.196 J2.057 E.06062
G1 X102.937 Y137.016 E.01802
G3 X105.496 Y139.694 I-.389 J2.933 E.11086
; Slow Down End
; CHANGE_LAYER
; Z_HEIGHT: 6.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X105.446 Y139.342 E-.13514
G1 X105.336 Y138.952 E-.15387
G1 X105.173 Y138.582 E-.15379
G1 X104.961 Y138.236 E-.15392
G1 X104.705 Y137.923 E-.15377
G1 X104.686 Y137.906 E-.00951
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
G1 X130.542 Y149.947
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X130.544 Y149.971 E.00081
G3 X127.895 Y153.096 I-2.544 J.529 E.15654
G3 X126.869 Y152.839 I.033 J-2.308 E.03539
G3 X127.751 Y147.914 I1.132 J-2.339 E.22363
G3 X129.131 Y148.161 I.245 J2.614 E.04708
G3 X130.448 Y149.63 I-1.131 J2.339 E.06715
G1 X130.525 Y149.889 E.00898
G1 X130.169 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.777 Y148.305 I-2.161 J.451 E.32656
G3 X128.881 Y148.473 I.236 J2.156 E.03468
G3 X130.156 Y149.991 I-.873 J2.028 E.06319
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13744
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.875 E-.0493
; WIPE_END
G1 E-.04 F1800
G1 X123.03 Y148.209 Z7.2 F36000
G1 X103.875 Y137.72 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.894 Y137.736 E.00081
G3 X102.439 Y142.552 I-1.351 J2.22 E.22712
G3 X102.295 Y137.369 I.105 J-2.596 E.25902
G3 X103.579 Y137.573 I.248 J2.586 E.0436
G1 X103.822 Y137.694 E.00899
G1 X103.693 Y138.066 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.322 Y137.761 I-1.141 J1.889 E.38218
G3 X103.425 Y137.928 I.236 J2.157 E.03468
G3 X103.641 Y138.036 I-.873 J2.027 E.00744
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13738
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11463
G1 X104.507 Y138.939 E-.11463
G1 X104.627 Y139.216 E-.11465
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04939
; WIPE_END
G1 E-.04 F1800
G1 X112.358 Y139.539 Z7.2 F36000
G1 X151.018 Y139.052 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.2 Y138.669 E.01409
G3 X153.207 Y137.369 I2.257 J1.287 E.0824
G3 X153.351 Y142.552 I.249 J2.586 E.28256
G3 X151 Y139.11 I.106 J-2.596 E.16047
G1 X151.383 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.233 Y137.761 I2.081 J.736 E.07636
G3 X154.337 Y137.928 I.236 J2.157 E.03468
G3 X151.364 Y139.276 I-.873 J2.027 E.31325
; WIPE_START
M204 S10000
G1 X151.534 Y138.872 E-.16667
G1 X151.65 Y138.681 E-.0848
G1 X151.84 Y138.447 E-.11462
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11467
G1 X152.699 Y137.884 E-.04994
; WIPE_END
G1 E-.04 F1800
G1 X148.139 Y131.764 Z7.2 F36000
G1 X139.911 Y120.719 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.89469
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89503
G3 X115.136 Y118.245 I16.103 J-7.695 E.08799
G3 X128.203 Y101.105 I12.867 J-3.741 E.8306
G3 X140.338 Y109.28 I-.205 J13.398 E.51343
G1 X140.671 Y110.102 E.02942
G1 X142.198 Y110.102 E.05064
G1 X142.198 Y111.921 E.06035
G1 X135.398 Y111.921 E.22557
G1 X135.398 Y112.229 E.01021
G1 X133.552 Y112.229 E.06123
G1 X133.552 Y110.639 E.05274
G2 X127.028 Y107.818 I-5.585 J3.96 E.2479
G2 X133.11 Y118.914 I.973 J6.682 E.86349
G1 X133.552 Y118.361 E.0235
G1 X133.552 Y116.771 E.05274
G1 X135.398 Y116.771 E.06123
G1 X135.398 Y117.079 E.01021
G1 X142.198 Y117.079 E.22557
G1 X142.198 Y118.898 E.06035
G1 X140.667 Y118.898 E.05078
G3 X139.92 Y120.67 I-25.866 J-9.867 E.06382
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82944
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.209 Y100.713 I12.42 J-6.011 E.86331
G3 X140.935 Y109.71 I-.227 J13.821 E.50877
G1 X142.59 Y109.71 E.05084
G1 X142.59 Y112.313 E.08
G1 X135.79 Y112.313 E.20895
G1 X135.79 Y112.621 E.00946
G1 X133.16 Y112.621 E.08081
G1 X133.16 Y110.777 E.05668
G2 X133.16 Y118.223 I-5.156 J3.723 E.98338
G1 X133.16 Y116.379 E.05668
G1 X135.79 Y116.379 E.08081
G1 X135.79 Y116.687 E.00946
G1 X142.59 Y116.687 E.20895
G1 X142.59 Y119.29 E.08
M73 P69 R6
G1 X140.934 Y119.29 E.05089
G3 X140.438 Y120.466 I-18.4 J-7.062 E.03921
M204 S10000
G1 X140.858 Y121.344 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.40183
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X159.146 Y139.633 E1.3364
G1 X159.432 Y139.28 E.02347
G1 X142.474 Y122.321 E1.23921
G1 X143.671 Y122.88 E.06826
G1 X159.711 Y138.92 E1.17211
G1 X159.986 Y138.556 E.02358
G1 X144.868 Y123.438 E1.10468
G1 X146.065 Y123.996 E.06826
G1 X160.26 Y138.191 E1.03726
G2 X160.529 Y137.821 I-5.168 J-4.022 E.02365
G1 X147.263 Y124.555 E.96937
G1 X148.46 Y125.113 E.06826
M73 P70 R6
G1 X160.792 Y137.445 E.90112
G1 X161.055 Y137.069 E.02371
G1 X149.657 Y125.671 E.83286
G1 X150.855 Y126.229 E.06826
G1 X161.312 Y136.687 E.76417
G1 X161.564 Y136.3 E.02387
G1 X152.052 Y126.788 E.69506
G1 X153.249 Y127.346 E.06826
G1 X161.816 Y135.912 E.62596
G2 X162.061 Y135.519 I-5.5 J-3.715 E.02396
G1 X154.446 Y127.904 E.55644
G1 X155.644 Y128.463 E.06826
G1 X162.301 Y135.12 E.48648
G1 X162.541 Y134.721 E.02406
G1 X156.841 Y129.021 E.41652
G1 X158.038 Y129.579 E.06826
G1 X162.775 Y134.316 E.34613
G1 X163.003 Y133.905 E.02429
G1 X159.236 Y130.138 E.2753
G1 X160.433 Y130.696 E.06826
G1 X163.231 Y133.494 E.20446
G2 X163.453 Y133.077 I-5.763 J-3.327 E.02442
G1 X161.63 Y131.254 E.13316
G1 X162.827 Y131.812 E.06826
G1 X163.819 Y132.804 E.07242
; WIPE_START
G1 X162.827 Y131.812 E-.53263
G1 X162.285 Y131.56 E-.22737
; WIPE_END
G1 E-.04 F1800
G1 X155.878 Y127.412 Z7.2 F36000
G1 X140.455 Y117.427 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
; LAYER_HEIGHT: 0.2
G1 F15476.087
G1 X141.578 Y118.55 E.05267
G1 X138.676 Y117.246 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.40183
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X140.286 Y118.856 E.11767
G1 X140.105 Y119.314 E.02544
G1 X138.239 Y117.448 E.13634
G1 X137.931 Y117.448 E.01595
G1 X137.981 Y117.772 E.0169
G1 X137.952 Y117.8 E.00208
G1 X139.914 Y119.761 E.14333
G1 X139.719 Y120.206 E.02506
G1 X137.633 Y118.119 E.15243
G1 X137.313 Y118.439 E.02335
G1 X158.861 Y139.986 E1.5745
G3 X158.571 Y140.336 I-5.149 J-3.969 E.02345
G1 X136.851 Y118.615 E1.58716
G1 X132.697 Y122.769 F36000
G1 F3000
G1 X150.565 Y140.637 E1.30566
G3 X150.489 Y139.921 I3.146 J-.698 E.03726
G1 X133.16 Y122.592 E1.26626
G1 X133.479 Y122.273 E.02335
G1 X150.547 Y139.34 E1.24716
G3 X150.702 Y138.856 I3.353 J.803 E.0263
G1 X133.799 Y121.953 E1.23511
G1 X134.118 Y121.634 E.02335
G1 X150.912 Y138.428 E1.22717
G3 X151.178 Y138.054 I1.494 J.78 E.02375
G1 X134.438 Y121.314 E1.22322
G1 X134.757 Y120.995 E.02335
G1 X151.492 Y137.73 E1.22285
G3 X151.855 Y137.454 I1.185 J1.182 E.02363
G1 X135.077 Y120.675 E1.22603
G1 X135.396 Y120.356 E.02335
G1 X152.269 Y137.229 E1.23294
G3 X152.753 Y137.074 I1.666 J4.361 E.02626
G1 X135.716 Y120.036 E1.24495
G1 X136.035 Y119.717 E.02335
G1 X153.31 Y136.992 E1.26231
G3 X153.995 Y137.037 I.158 J2.796 E.03554
G1 X136.355 Y119.397 E1.28898
G1 X136.674 Y119.078 E.02335
G1 X158.274 Y140.678 E1.57833
G1 X157.977 Y141.019 E.0234
G1 X156.377 Y139.42 E.11689
G3 X156.423 Y140.105 I-2.469 J.509 E.03557
G1 X157.677 Y141.359 E.09165
G1 X157.369 Y141.689 E.02336
G1 X156.34 Y140.66 E.07519
G3 X156.251 Y140.969 I-.977 J-.115 E.01666
G1 X156.178 Y141.137 E.00948
G1 X157.06 Y142.02 E.06451
G3 X156.751 Y142.349 I-4.866 J-4.271 E.02336
G1 X155.956 Y141.555 E.05806
G3 X155.683 Y141.92 I-1.468 J-.813 E.02366
G1 X156.431 Y142.669 E.05469
G1 X156.112 Y142.988 E.02335
G1 X155.36 Y142.237 E.0549
G3 X154.988 Y142.504 I-4.539 J-5.944 E.02367
G1 X155.792 Y143.307 E.05872
G1 X155.461 Y143.616 E.02336
G1 X154.558 Y142.713 E.06596
G3 X154.066 Y142.859 I-1.125 J-2.88 E.02658
G1 X155.13 Y143.924 E.07778
G1 X154.8 Y144.232 E.02336
G1 X153.485 Y142.917 E.0961
G3 X152.773 Y142.844 I-.1 J-2.542 E.03709
G1 X154.458 Y144.53 E.12317
G1 X154.117 Y144.827 E.0234
G1 X132.521 Y123.231 E1.57804
G1 X132.201 Y123.551 E.02335
G1 X153.775 Y145.124 E1.57641
G3 X153.423 Y145.412 I-4.298 J-4.899 E.02347
G1 X131.882 Y123.87 E1.57406
G1 X131.562 Y124.19 E.02335
G1 X153.07 Y145.698 E1.57161
G1 X152.717 Y145.983 E.02347
M73 P71 R6
G1 X131.243 Y124.509 E1.56915
G1 X130.923 Y124.829 E.02335
G1 X152.355 Y146.26 E1.56604
G1 X151.991 Y146.535 E.02358
G1 X130.604 Y125.148 E1.56276
G1 X130.284 Y125.468 E.02335
G1 X151.626 Y146.81 E1.55948
G3 X151.253 Y147.076 I-4.009 J-5.219 E.02367
G1 X129.965 Y125.787 E1.55559
G1 X129.645 Y126.107 E.02335
G1 X150.878 Y147.339 E1.55147
G1 X150.502 Y147.602 E.02371
G1 X129.326 Y126.426 E1.54736
G1 X129.006 Y126.746 E.02335
G1 X150.118 Y147.857 E1.54266
G1 X149.731 Y148.109 E.02387
G1 X128.583 Y126.961 E1.54533
G1 X128.556 Y126.963 E.00139
G1 X124.835 Y123.242 E.27191
G1 X124.53 Y123.547 E.02229
G1 X149.343 Y148.36 E1.81318
G3 X148.948 Y148.604 I-3.689 J-5.537 E.024
G1 X124.21 Y123.866 E1.80765
G1 X123.891 Y124.186 E.02335
G1 X148.549 Y148.844 E1.80183
G1 X148.15 Y149.084 E.02406
G1 X123.571 Y124.505 E1.79601
G1 X123.252 Y124.825 E.02335
G1 X147.743 Y149.316 E1.78961
G1 X147.332 Y149.544 E.02429
G1 X122.932 Y125.144 E1.78292
G1 X122.613 Y125.464 E.02335
G1 X146.921 Y149.772 E1.77623
G3 X146.501 Y149.991 I-3.357 J-5.905 E.02447
G1 X115.943 Y119.433 E2.23293
G1 X116.437 Y120.566 E.06385
G1 X146.078 Y150.207 E2.16592
G1 X145.654 Y150.423 E.02455
G1 X116.273 Y121.041 E2.14698
G1 X115.837 Y121.244 E.02484
G1 X145.222 Y150.629 E2.14721
G1 X144.786 Y150.832 E.02484
G1 X115.401 Y121.447 E2.14721
G1 X114.965 Y121.65 E.02484
M73 P72 R6
G1 X144.35 Y151.035 E2.14721
G3 X143.904 Y151.228 I-2.977 J-6.292 E.02513
G1 X114.53 Y121.854 E2.14643
G1 X114.094 Y122.057 E.02484
G1 X143.455 Y151.418 E2.14549
G1 X143.007 Y151.609 E.02518
G1 X113.658 Y122.26 E2.14455
G1 X113.222 Y122.463 E.02484
G1 X142.548 Y151.789 E2.14292
G3 X142.084 Y151.964 I-4.397 J-10.962 E.02563
G1 X112.786 Y122.666 E2.14085
G1 X112.351 Y122.87 E.02484
G1 X141.616 Y152.135 E2.13847
G1 X141.147 Y152.305 E.02576
G1 X111.915 Y123.073 E2.13608
G1 X111.479 Y123.276 E.02484
G1 X140.669 Y152.466 E2.13293
G1 X140.186 Y152.622 E.0262
G1 X111.043 Y123.479 E2.12953
G1 X110.608 Y123.682 E.02484
G1 X139.704 Y152.779 E2.12613
G1 X139.207 Y152.921 E.02669
G1 X110.172 Y123.886 E2.12169
G1 X109.736 Y124.089 E.02484
G1 X138.711 Y153.064 E2.11725
G3 X138.21 Y153.202 I-2.226 J-7.102 E.02685
G1 X109.3 Y124.292 E2.11248
G1 X108.864 Y124.495 E.02484
G1 X137.698 Y153.329 E2.10695
G1 X137.187 Y153.457 E.02724
G1 X108.429 Y124.698 E2.10142
G1 X107.993 Y124.902 E.02484
M73 P73 R6
G1 X136.666 Y153.574 E2.09516
G1 X136.139 Y153.686 E.02784
G1 X107.405 Y124.952 E2.09963
G1 X101.74 Y127.594 F36000
G1 F3000
G1 X125.062 Y150.917 E1.70424
G3 X125.033 Y150.297 I2.241 J-.417 E.03217
G1 X125.039 Y150.254 E.00222
G1 X102.328 Y127.543 E1.65954
G1 X102.764 Y127.34 E.02484
G1 X125.139 Y149.715 E1.63499
G3 X125.315 Y149.253 I1.454 J.29 E.02569
G1 X103.199 Y127.137 E1.61605
G1 X103.635 Y126.934 E.02484
G1 X125.539 Y148.837 E1.60053
G3 X125.819 Y148.479 I1.443 J.842 E.02359
G1 X104.071 Y126.731 E1.5892
G1 X104.507 Y126.527 E.02484
G1 X126.152 Y148.173 E1.58167
G3 X126.535 Y147.917 I1.122 J1.268 E.02388
G1 X104.942 Y126.324 E1.57784
G1 X105.378 Y126.121 E.02484
G1 X126.973 Y147.716 E1.578
G3 X127.219 Y147.632 I.412 J.799 E.01349
G1 X127.482 Y147.586 E.01376
G1 X105.814 Y125.918 E1.58331
G1 X106.25 Y125.714 E.02484
G1 X128.066 Y147.531 E1.59414
G3 X128.808 Y147.637 I-.018 J2.755 E.03887
G1 X106.686 Y125.511 E1.61667
G1 X107.121 Y125.308 E.02484
G1 X135.611 Y153.798 E2.08178
G1 X135.068 Y153.893 E.0285
G1 X130.85 Y149.676 E.30815
G3 X130.967 Y150.432 I-2.908 J.835 E.0396
G1 X134.524 Y153.989 E.25994
G3 X133.972 Y154.076 I-1.522 J-7.866 E.02888
G1 X130.923 Y151.026 E.22285
G3 X130.802 Y151.495 I-1.765 J-.202 E.02508
G1 X130.787 Y151.53 E.00197
G1 X133.412 Y154.155 E.19179
G3 X132.851 Y154.233 I-1.408 J-8.087 E.02928
G1 X130.582 Y151.964 E.16578
G3 X130.324 Y152.345 I-1.515 J-.75 E.02385
G1 X132.273 Y154.294 E.1424
G1 X131.695 Y154.354 E.03004
G1 X130.017 Y152.676 E.12261
G3 X129.661 Y152.959 I-1.208 J-1.154 E.02357
G1 X131.104 Y154.403 E.10547
G1 X130.507 Y154.445 E.03093
G1 X129.254 Y153.192 E.09154
G3 X128.79 Y153.366 I-2.124 J-4.948 E.02565
G1 X129.903 Y154.48 E.08138
G1 X129.286 Y154.502 E.03192
G1 X128.238 Y153.453 E.07659
G3 X127.591 Y153.445 I-.272 J-4.143 E.03347
G1 X128.668 Y154.522 E.07868
G1 X128.029 Y154.522 E.03302
G1 X101.456 Y127.95 E1.94169
G1 X101.02 Y128.153 E.02484
G1 X127.39 Y154.522 E1.92684
G3 X126.731 Y154.502 I-.044 J-9.445 E.03407
G1 X100.585 Y128.356 E1.91054
G1 X100.149 Y128.559 E.02484
M73 P74 R6
G1 X126.069 Y154.479 E1.894
G3 X125.388 Y154.437 I.259 J-9.768 E.03525
G1 X99.713 Y128.763 E1.87609
G1 X99.277 Y128.966 E.02484
G1 X124.701 Y154.389 E1.85773
G3 X123.994 Y154.322 I.615 J-10.153 E.03668
M73 P74 R5
G1 X98.842 Y129.169 E1.83794
G1 X98.406 Y129.372 E.02484
G1 X123.28 Y154.247 E1.81761
G3 X122.629 Y154.161 I.902 J-9.349 E.03391
G1 X122.543 Y154.149 E.00451
G1 X97.97 Y129.575 E1.7956
G1 X97.534 Y129.779 E.02484
G1 X121.8 Y154.044 E1.77312
G3 X121.027 Y153.91 I1.535 J-11.143 E.04055
G1 X96.946 Y129.829 E1.7596
G1 X92.813 Y134.003 F36000
G1 F3000
G1 X99.734 Y140.924 E.50577
G3 X99.577 Y140.159 I2.704 J-.954 E.04051
G1 X99.577 Y140.128 E.00158
G1 X92.577 Y133.128 E.51152
G3 X92.145 Y132.292 I15.756 J-8.671 E.04865
G1 X92.305 Y132.217 E.00913
G1 X99.609 Y139.521 E.53372
G3 X99.73 Y139.003 I1.944 J.18 E.02758
G1 X92.741 Y132.014 E.51071
G1 X93.176 Y131.811 E.02484
G1 X99.928 Y138.563 E.49338
G3 X100.173 Y138.169 I2.327 J1.173 E.024
G1 X93.612 Y131.607 E.47943
G1 X94.048 Y131.404 E.02484
G1 X100.474 Y137.83 E.46953
G3 X100.822 Y137.54 I1.23 J1.123 E.02352
G1 X94.484 Y131.201 E.46317
G1 X94.92 Y130.998 E.02484
G1 X101.221 Y137.3 E.46048
G3 X101.507 Y137.176 I.593 J.975 E.01615
G1 X101.676 Y137.116 E.00927
G1 X95.355 Y130.795 E.46188
G1 X95.791 Y130.591 E.02484
G1 X102.209 Y137.009 E.46896
G3 X102.841 Y137.002 I.347 J2.739 E.03273
G1 X96.227 Y130.388 E.48329
G1 X96.663 Y130.185 E.02484
G1 X103.693 Y137.215 E.51371
G3 X105.276 Y138.799 I-1.107 J2.691 E.11878
G1 X120.246 Y153.768 E1.09382
G1 X119.434 Y153.596 E.04287
G1 X105.498 Y139.66 E1.01831
G3 X105.493 Y140.293 I-3.228 J.288 E.03278
G1 X118.604 Y153.405 E.95809
G1 X117.753 Y153.193 E.04533
G1 X105.383 Y140.822 E.90393
G3 X105.24 Y141.196 I-1.429 J-.33 E.02072
G1 X105.203 Y141.282 E.00483
G1 X116.863 Y152.942 E.85202
G3 X115.949 Y152.666 I3.489 J-13.237 E.04936
G1 X104.965 Y141.682 E.80262
G3 X104.672 Y142.028 I-3.899 J-2.998 E.02344
G1 X115.002 Y152.359 E.75485
G3 X114.859 Y152.308 I.656 J-2.077 E.00788
G1 X114 Y151.995 E.04723
G1 X104.331 Y142.326 E.7065
G3 X103.94 Y142.574 I-1.131 J-1.35 E.02399
G1 X112.951 Y151.585 E.65842
G3 X111.843 Y151.116 I7.42 J-19.073 E.06218
G1 X103.494 Y142.767 E.61006
G3 X102.983 Y142.895 I-.721 J-1.797 E.0273
G1 X110.658 Y150.571 E.56086
G3 X109.73 Y150.114 I20.586 J-42.985 E.05344
G1 X109.372 Y149.923 E.02098
G1 X102.366 Y142.918 E.5119
G3 X101.652 Y142.788 I.202 J-3.137 E.03761
G1 X101.567 Y142.758 E.00464
G1 X107.944 Y149.134 E.46596
G3 X106.37 Y148.177 I12.914 J-23.015 E.09521
G1 X106.312 Y148.141 E.00354
M73 P75 R5
G1 X94.359 Y136.188 E.8734
G2 X95.795 Y138.263 I40.501 J-26.492 E.13036
G1 X104.237 Y146.705 E.61692
G3 X99.734 Y142.841 I24.445 J-33.043 E.30687
G1 X96.86 Y139.967 E.21002
; WIPE_START
G1 X98.274 Y141.381 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X102.782 Y135.222 Z7.2 F36000
G1 X115.286 Y118.138 Z7.2
G1 Z6.8
G1 E.8 F1800
G1 F3000
G1 X119.166 Y122.017 E.28346
G1 X119.393 Y122.285 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
; LAYER_HEIGHT: 0.2
G1 F15476.087
G1 X119.305 Y122.197 E.00413
G1 X119.941 Y121.561 E.02985
G1 X119.514 Y121.134 E.02003
G1 X122.142 Y118.506 E.12327
G3 X121.002 Y113.326 I5.868 J-4.008 E.18032
G1 X116.335 Y108.659 E.2189
G1 X122.552 Y109.953 F36000
G1 F15476.087
G2 X121.661 Y111.311 I8.498 J6.549 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I12.999 J-3.186 E.08976
G1 X123.735 Y123.735 E.41161
G1 X124.835 Y122.636 E.05158
G1 X125.261 Y123.063 E.02003
G1 X126.825 Y121.499 E.07336
G2 X129.178 Y121.502 I1.188 J-8.678 E.07828
G1 X131.411 Y123.735 E.10476
G1 X135.249 Y119.897 E.18005
G1 X133.871 Y118.519 E.06464
G1 X133.9 Y117.119 E.04646
G1 X134.118 Y117.119 E.00723
; WIPE_START
G1 X133.9 Y117.119 E-.0828
G1 X133.871 Y118.519 E-.53219
G1 X134.141 Y118.789 E-.14502
; WIPE_END
G1 E-.04 F1800
G1 X133.271 Y111.206 Z7.2 F36000
G1 X133.081 Y109.544 Z7.2
G1 Z6.8
G1 E.8 F1800
G1 F15476.087
G3 X133.9 Y110.517 I-5.889 J5.792 E.04225
G1 X133.9 Y110.872 E.01178
G1 X134.909 Y111.881 E.04731
G1 X135.05 Y111.881 E.00467
G1 X135.05 Y111.573 E.01021
G1 X136.751 Y111.573 E.05643
G1 X139.665 Y108.659 E.13669
G1 X140.649 Y111.573 F36000
G1 F15476.087
G1 X141.85 Y111.573 E.03984
G1 X141.85 Y111.146 E.01417
G1 X141.154 Y110.45 E.03263
G1 X140.439 Y110.45 E.02373
G1 X139.931 Y109.227 E.04393
G1 X133.273 Y102.569 E.31235
G2 X131.13 Y101.842 I-5.567 J12.881 E.07514
G1 X124.816 Y108.156 E.2962
G2 X123.992 Y108.64 I2.722 J5.574 E.03174
G1 X119.747 Y104.395 E.19913
G2 X118.555 Y105.502 I8.585 J10.447 E.05401
G1 X137.441 Y105.506 F36000
G1 F15476.087
G2 X136.251 Y104.397 I-10.471 J10.042 E.05399
G1 X132.006 Y108.642 E.19916
G2 X131.182 Y108.154 I-4.707 J6.999 E.03179
G1 X124.869 Y101.841 E.29616
G2 X122.719 Y102.577 I5.983 J20.968 E.07541
G1 X116.067 Y109.229 E.31206
G2 X115.502 Y110.755 I12.371 J5.443 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 7
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X116.067 Y109.229 E-.61829
G1 X116.331 Y108.966 E-.14171
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
G1 X130.542 Y149.947
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.553 Y149.97 E.00082
G3 X127.735 Y147.915 I-2.546 J.531 E.41522
G3 X129.353 Y148.276 I.257 J2.658 E.05592
G3 X130.456 Y149.627 I-1.346 J2.225 E.05902
G1 X130.527 Y149.889 E.009
G1 X130.17 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.761 Y148.306 I-2.162 J.451 E.32606
G3 X128.596 Y148.372 I.232 J2.396 E.02587
G3 X130.157 Y149.991 I-.587 J2.129 E.07251
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13746
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11463
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11465
G1 X129.806 Y151.775 E-.11462
G1 X129.724 Y151.875 E-.04931
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.947 Z7.4 F36000
G1 X150.996 Y139.107 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.012 Y139.087 E.00085
G3 X153.19 Y137.371 I2.451 J.87 E.09704
G3 X154.809 Y137.731 I.257 J2.657 E.05592
G3 X150.917 Y139.428 I-1.346 J2.225 E.37727
G1 X150.982 Y139.166 E.00898
G1 X151.383 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.217 Y137.762 I2.081 J.736 E.07587
G3 X154.052 Y137.827 I.232 J2.396 E.02587
G3 X151.364 Y139.276 I-.587 J2.128 E.3226
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13719
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04956
; WIPE_END
G1 E-.04 F1800
G1 X145.066 Y137.859 Z7.4 F36000
G1 X103.875 Y137.72 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.0008
G3 X102.279 Y137.371 I-1.345 J2.224 E.48578
G3 X103.58 Y137.571 I.257 J2.657 E.04413
G1 X103.822 Y137.693 E.00899
G1 X103.694 Y138.065 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.306 Y137.762 I-1.141 J1.891 E.38185
G3 X103.141 Y137.827 I.232 J2.396 E.02587
G3 X103.642 Y138.035 I-.588 J2.129 E.01672
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.1374
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11462
G1 X104.708 Y139.506 E-.11466
G1 X104.726 Y139.635 E-.04936
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z7.4 F36000
G1 X139.911 Y120.718 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.8947
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89503
G3 X115.136 Y118.245 I16.104 J-7.695 E.08799
G3 X128.195 Y101.105 I12.867 J-3.741 E.83036
G3 X140.34 Y109.287 I-.198 J13.399 E.51391
G1 X140.671 Y110.102 E.02919
G1 X142.198 Y110.102 E.05064
G1 X142.198 Y111.903 E.05975
G1 X135.398 Y111.903 E.22557
G1 X135.398 Y112.204 E.00999
G1 X133.552 Y112.204 E.06123
G1 X133.552 Y110.639 E.05192
G2 X126.518 Y107.912 I-5.579 J3.955 E.26508
G2 X133.11 Y118.914 I1.485 J6.586 E.84601
G1 X133.552 Y118.361 E.02349
G1 X133.552 Y116.796 E.05192
G1 X135.398 Y116.796 E.06123
G1 X135.398 Y117.097 E.00999
G1 X142.198 Y117.097 E.22557
G1 X142.198 Y118.898 E.05975
G1 X140.671 Y118.898 E.05066
G3 X139.92 Y120.67 I-29.918 J-11.633 E.06384
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82944
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.202 Y100.713 I12.42 J-6.011 E.86308
G3 X140.935 Y109.71 I-.22 J13.821 E.50899
G1 X142.59 Y109.71 E.05084
G1 X142.59 Y112.295 E.07944
G1 X135.79 Y112.295 E.20895
G1 X135.79 Y112.597 E.00925
G1 X133.16 Y112.597 E.08081
G1 X133.16 Y110.777 E.05592
G2 X133.16 Y118.223 I-5.156 J3.723 E.98348
G1 X133.16 Y116.403 E.05592
G1 X135.79 Y116.403 E.08081
G1 X135.79 Y116.705 E.00925
G1 X142.59 Y116.705 E.20895
G1 X142.59 Y119.29 E.07944
G1 X140.935 Y119.29 E.05085
G3 X140.438 Y120.466 I-20.279 J-7.876 E.03922
M204 S10000
G1 X140.651 Y121.244 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42104
G1 F15000
G1 X159.125 Y139.718 E.80499
G1 X159.364 Y139.422 E.01171
G1 X142.004 Y122.062 E.75647
G1 X143.006 Y122.529 E.03406
G1 X159.602 Y139.126 E.72318
G1 X159.832 Y138.821 E.01177
G1 X144.008 Y122.997 E.68953
G1 X145.01 Y123.464 E.03406
G1 X160.062 Y138.516 E.65588
G1 X160.292 Y138.211 E.01177
G1 X146.012 Y123.931 E.62223
G1 X147.014 Y124.398 E.03406
G1 X160.517 Y137.901 E.58839
G1 X160.737 Y137.587 E.01183
G1 X148.016 Y124.865 E.55433
G1 X149.018 Y125.333 E.03406
G1 X160.957 Y137.272 E.52026
G1 X161.178 Y136.958 E.01183
G1 X150.02 Y125.8 E.4862
G1 X151.022 Y126.267 E.03406
G1 X161.39 Y136.635 E.45178
G1 X161.6 Y136.311 E.01191
G1 X152.024 Y126.734 E.4173
G1 X153.026 Y127.202 E.03406
G1 X161.811 Y135.987 E.38281
G2 X162.019 Y135.66 I-4.564 J-3.146 E.01193
G1 X154.028 Y127.669 E.34824
G1 X155.03 Y128.136 E.03406
G1 X162.22 Y135.326 E.31332
G1 X162.421 Y134.992 E.01201
G1 X156.032 Y128.603 E.27841
G1 X157.033 Y129.07 E.03406
G1 X162.621 Y134.658 E.24349
G2 X162.816 Y134.318 I-4.775 J-2.955 E.01208
G1 X158.035 Y129.538 E.2083
G1 X159.037 Y130.005 E.03406
G1 X163.007 Y133.974 E.17295
G1 X163.197 Y133.63 E.01212
G1 X160.039 Y130.472 E.1376
G1 X161.041 Y130.939 E.03406
G1 X163.387 Y133.285 E.10222
G1 X163.568 Y132.931 E.01225
G1 X162.043 Y131.407 E.06642
G1 X163.045 Y131.874 E.03406
G1 X163.874 Y132.703 E.03611
G1 X154.24 Y144.993 F36000
G1 F15000
G1 X134.731 Y125.484 E.85009
G1 X134.397 Y125.685 E.01201
G1 X153.834 Y145.121 E.84694
G3 X153.541 Y145.363 I-3.606 J-4.067 E.01171
G1 X134.05 Y125.873 E.84929
G1 X133.698 Y126.055 E.01223
G1 X153.245 Y145.603 E.85178
G1 X152.95 Y145.842 E.01171
G1 X133.334 Y126.226 E.85474
G1 X132.962 Y126.389 E.01252
G1 X152.654 Y146.081 E.85808
G1 X152.349 Y146.31 E.01177
G1 X132.582 Y126.543 E.86135
G1 X132.187 Y126.683 E.01291
G1 X152.044 Y146.54 E.86528
G1 X151.739 Y146.77 E.01177
G1 X131.784 Y126.815 E.86953
G1 X131.37 Y126.936 E.01329
G1 X151.431 Y146.996 E.87413
G1 X151.116 Y147.216 E.01183
G1 X130.941 Y127.041 E.87913
G1 X130.503 Y127.138 E.01382
G1 X150.802 Y147.437 E.88451
G1 X150.487 Y147.657 E.01183
G1 X130.051 Y127.221 E.89051
G1 X129.58 Y127.285 E.01463
G1 X150.165 Y147.87 E.89699
G1 X149.841 Y148.081 E.01191
G1 X129.096 Y127.336 E.90395
G1 X128.597 Y127.371 E.01543
G1 X149.517 Y148.291 E.91159
G3 X149.192 Y148.5 I-3.142 J-4.525 E.01192
G1 X128.076 Y127.384 E.92013
G1 X128.004 Y127.386 E.00219
G3 X127.531 Y127.374 I-.004 J-9.182 E.0146
G1 X148.858 Y148.701 E.92931
G1 X148.524 Y148.902 E.01201
G1 X126.962 Y127.34 E.93954
G1 X126.365 Y127.278 E.0185
G1 X148.19 Y149.103 E.951
G3 X147.85 Y149.298 I-2.973 J-4.77 E.01207
G1 X125.733 Y127.181 E.96373
G1 X125.059 Y127.042 E.0212
G1 X147.506 Y149.489 E.97811
G1 X147.162 Y149.679 E.01212
G1 X124.332 Y126.849 E.99483
G1 X124.082 Y126.776 E.00802
G3 X123.531 Y126.583 I3.587 J-11.128 E.01797
G1 X146.818 Y149.87 E1.01471
G3 X146.464 Y150.051 I-2.731 J-4.911 E.01225
G1 X122.617 Y126.204 E1.03913
G1 X122.236 Y126.025 E.01296
G3 X121.504 Y125.626 I11.157 J-21.305 E.0257
G1 X146.11 Y150.231 E1.07219
M73 P76 R5
G1 X145.756 Y150.412 E.01225
G1 X116.321 Y120.978 E1.28259
G1 X115.957 Y121.148 E.0124
G1 X145.397 Y150.588 E1.28283
G1 X145.032 Y150.758 E.0124
G1 X115.592 Y121.318 E1.28283
G1 X115.227 Y121.488 E.0124
G1 X144.667 Y150.928 E1.28283
G1 X144.303 Y151.098 E.0124
G1 X114.863 Y121.658 E1.28283
G1 X114.498 Y121.828 E.0124
G1 X143.927 Y151.257 E1.28238
G1 X143.552 Y151.417 E.01257
G1 X114.133 Y121.998 E1.28191
G1 X113.769 Y122.168 E.0124
G1 X143.177 Y151.576 E1.28144
G3 X142.795 Y151.729 I-2.388 J-5.392 E.01267
G1 X113.404 Y122.338 E1.28071
G1 X113.039 Y122.508 E.0124
G1 X142.409 Y151.878 E1.27976
G1 X142.022 Y152.026 E.01275
G1 X112.675 Y122.678 E1.27882
G1 X112.31 Y122.848 E.0124
G1 X141.634 Y152.172 E1.27779
G1 X141.236 Y152.309 E.01296
G1 X111.945 Y123.018 E1.27634
G1 X111.581 Y123.188 E.0124
G1 X140.838 Y152.446 E1.2749
G1 X140.441 Y152.583 E.01296
G1 X111.216 Y123.358 E1.27346
G1 X110.851 Y123.529 E.0124
G1 X140.035 Y152.713 E1.27169
G3 X139.627 Y152.839 I-2.614 J-7.733 E.01317
G1 X110.486 Y123.699 E1.26979
G1 X110.122 Y123.869 E.0124
G1 X139.211 Y152.958 E1.26757
G1 X138.796 Y153.077 E.01332
G1 X109.757 Y124.039 E1.26535
G1 X109.392 Y124.209 E.0124
G1 X138.38 Y153.197 E1.26313
G3 X137.952 Y153.304 I-1.756 J-6.109 E.01359
G1 X109.028 Y124.379 E1.26039
G1 X108.663 Y124.549 E.0124
G1 X137.524 Y153.41 E1.25763
G1 X137.096 Y153.517 E.01359
G1 X108.298 Y124.719 E1.25487
G1 X107.934 Y124.889 E.0124
G1 X136.658 Y153.613 E1.25165
G1 X136.217 Y153.707 E.01389
G1 X107.569 Y125.059 E1.24833
G1 X107.204 Y125.229 E.0124
G1 X135.776 Y153.801 E1.245
G3 X135.325 Y153.885 I-1.43 J-6.404 E.01412
G1 X106.84 Y125.399 E1.24126
G1 X106.475 Y125.569 E.0124
G1 X128.521 Y147.615 E.96064
G2 X127.938 Y147.567 I-.576 J3.423 E.01804
G1 X106.11 Y125.739 E.95113
G1 X105.746 Y125.909 E.0124
G1 X127.461 Y147.625 E.94626
G2 X127.034 Y147.733 I.112 J1.345 E.01363
G1 X105.381 Y126.079 E.94355
G1 X105.016 Y126.249 E.0124
G1 X126.66 Y147.894 E.94314
G2 X126.326 Y148.094 I.564 J1.317 E.01204
G1 X104.651 Y126.42 E.94447
G1 X104.287 Y126.59 E.0124
G1 X126.029 Y148.331 E.94739
G2 X125.765 Y148.603 I.856 J1.093 E.01169
G1 X103.922 Y126.76 E.95182
G1 X103.557 Y126.93 E.0124
G1 X125.537 Y148.91 E.95777
G2 X125.346 Y149.253 I1.154 J.865 E.01216
G1 X103.193 Y127.1 E.96534
G1 X102.828 Y127.27 E.0124
G1 X125.198 Y149.639 E.97475
G2 X125.1 Y150.077 I1.541 J.574 E.01384
G1 X102.463 Y127.44 E.98639
G1 X102.099 Y127.61 E.0124
G1 X125.069 Y150.581 E1.00094
G2 X125.152 Y151.198 I3.188 J-.113 E.01923
G1 X101.734 Y127.78 E1.02044
G1 X101.369 Y127.95 E.0124
G1 X127.978 Y154.559 E1.15946
G1 X127.443 Y154.559 E.01648
G1 X101.005 Y128.12 E1.15205
G1 X100.64 Y128.29 E.0124
G1 X126.894 Y154.544 E1.14402
G1 X126.34 Y154.525 E.01708
G1 X100.275 Y128.46 E1.13577
G1 X99.911 Y128.63 E.0124
G1 X125.782 Y154.501 E1.12733
G1 X125.207 Y154.461 E.01776
G1 X99.546 Y128.8 E1.11816
G1 X99.181 Y128.97 E.0124
G1 X124.632 Y154.421 E1.109
G3 X124.039 Y154.363 I.533 J-8.509 E.01835
G1 X98.817 Y129.14 E1.09907
G1 X98.452 Y129.31 E.0124
G1 X123.442 Y154.3 E1.08892
G3 X122.833 Y154.226 I.758 J-8.768 E.0189
G1 X98.087 Y129.481 E1.07828
G1 X97.722 Y129.651 E.0124
G1 X122.211 Y154.139 E1.06706
G3 X121.582 Y154.045 I1.027 J-9.041 E.01958
G1 X97.358 Y129.821 E1.05557
G1 X96.993 Y129.991 E.0124
G1 X120.933 Y153.93 E1.04317
G3 X120.28 Y153.813 I1.355 J-9.369 E.02044
G1 X105.208 Y138.74 E.65679
G3 X105.441 Y139.508 I-2.54 J1.19 E.02481
G1 X119.601 Y153.668 E.61704
G3 X118.919 Y153.521 I1.772 J-9.848 E.02151
G1 X105.475 Y140.077 E.58583
G3 X105.419 Y140.556 I-5.93 J-.441 E.01487
G1 X118.207 Y153.343 E.5572
G3 X117.487 Y153.158 I2.283 J-10.384 E.02289
G1 X105.299 Y140.97 E.53111
G3 X105.133 Y141.339 I-1.422 J-.417 E.0125
G1 X116.737 Y152.943 E.50566
G3 X115.971 Y152.712 I2.938 J-11.097 E.02468
G1 X104.928 Y141.669 E.48118
G1 X104.688 Y141.964 E.01171
G1 X115.179 Y152.454 E.45713
G3 X114.352 Y152.162 I3.769 J-11.978 E.02703
G1 X104.412 Y142.222 E.43314
G3 X104.1 Y142.445 I-.966 J-1.021 E.01185
G1 X113.502 Y151.847 E.4097
G1 X112.605 Y151.485 E.02982
G1 X103.751 Y142.631 E.38579
G3 X103.361 Y142.776 I-.721 J-1.347 E.01286
G1 X111.66 Y151.075 E.36162
G3 X110.665 Y150.615 I6.084 J-14.463 E.03377
G1 X102.918 Y142.868 E.33757
G3 X102.399 Y142.883 I-.317 J-1.882 E.01605
G1 X109.604 Y150.088 E.31393
G3 X108.449 Y149.468 I8.304 J-16.856 E.04037
G1 X101.479 Y142.498 E.30373
G1 X97.094 Y140.251 F36000
G1 F15000
G1 X99.737 Y142.895 E.1152
G2 X103.823 Y146.446 I27.722 J-27.771 E.16691
G1 X96.054 Y138.677 E.33852
G3 X94.744 Y136.832 I40.981 J-30.493 E.06974
G1 X105.668 Y147.756 E.47604
G2 X107.161 Y148.715 I14.464 J-20.893 E.05468
G1 X93.785 Y135.339 E.58286
G3 X93.032 Y134.051 I18.052 J-11.423 E.04599
G1 X99.72 Y140.739 E.29144
G3 X99.614 Y140.098 I3.214 J-.863 E.02006
G1 X92.412 Y132.896 E.31379
G3 X92.095 Y132.275 I11.748 J-6.38 E.02151
G1 X92.252 Y132.201 E.00533
G1 X99.637 Y139.586 E.32179
G3 X99.728 Y139.143 I1.657 J.112 E.01399
G1 X92.617 Y132.031 E.30989
G1 X92.982 Y131.861 E.0124
G1 X99.872 Y138.752 E.30025
G3 X100.058 Y138.403 I1.359 J.503 E.01221
G1 X93.346 Y131.691 E.29248
G1 X93.711 Y131.521 E.0124
G1 X100.282 Y138.093 E.28634
G3 X100.541 Y137.817 I1.133 J.804 E.01169
G1 X94.076 Y131.351 E.28173
G1 X94.44 Y131.181 E.0124
G1 X100.835 Y137.575 E.27863
G3 X101.164 Y137.37 I.912 J1.098 E.012
G1 X94.805 Y131.011 E.2771
G1 X95.17 Y130.841 E.0124
G1 X101.534 Y137.205 E.2773
G3 X101.954 Y137.09 I.556 J1.214 E.01348
G1 X95.534 Y130.671 E.27973
G1 X95.899 Y130.501 E.0124
G1 X102.425 Y137.027 E.28436
G3 X102.944 Y137.046 I.19 J1.901 E.01607
G1 X102.988 Y137.055 E.00137
G1 X96.264 Y130.331 E.293
G1 X96.628 Y130.161 E.0124
G1 X104.244 Y137.776 E.33184
; WIPE_START
G1 X102.83 Y136.362 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X107.65 Y130.444 Z7.4 F36000
G1 X116.032 Y120.154 Z7.4
G1 Z7
G1 E.8 F1800
G1 F15000
G1 X116.874 Y120.995 E.03666
G3 X116.283 Y119.87 I10.682 J-6.324 E.03918
G1 X115.947 Y119.534 E.01464
G3 X115.652 Y118.765 I21.517 J-8.699 E.02537
G1 X115.693 Y118.745 E.00141
G1 X116.13 Y119.182 E.01902
G1 X115.507 Y110.74 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X116.079 Y109.217 I11.35 J3.394 E.054
G1 X122.719 Y102.577 E.3115
G3 X124.868 Y101.841 I8.273 J20.647 E.07539
G1 X131.182 Y108.154 E.29617
G3 X132.006 Y108.642 I-3.879 J7.48 E.03179
G1 X136.251 Y104.397 E.19916
G3 X137.441 Y105.506 I-9.156 J11.014 E.05399
G1 X139.665 Y108.659 F36000
G1 F15476.087
G1 X136.769 Y111.555 E.13584
G1 X135.05 Y111.555 E.05703
M73 P77 R5
G1 X135.05 Y111.856 E.00999
G1 X134.884 Y111.856 E.00549
G1 X133.9 Y110.872 E.04615
G1 X133.9 Y110.517 E.01178
G2 X133.081 Y109.544 I-6.711 J4.82 E.04225
; WIPE_START
G1 X133.9 Y110.517 E-.48352
G1 X133.9 Y110.872 E-.13492
G1 X134.164 Y111.136 E-.14156
; WIPE_END
G1 E-.04 F1800
G1 X134.143 Y117.144 Z7.4 F36000
G1 Z7
G1 E.8 F1800
G1 F15476.087
G1 X133.9 Y117.144 E.00805
G1 X133.871 Y118.519 E.04564
G1 X137.709 Y122.357 E.18006
G3 X133.426 Y125.75 I-10.034 J-8.27 E.18262
G1 X129.178 Y121.502 E.19927
G3 X126.825 Y121.499 I-1.164 J-8.681 E.07828
G1 X122.574 Y125.75 E.19945
G3 X118.29 Y122.358 I5.782 J-11.7 E.18261
G1 X122.142 Y118.506 E.18069
G3 X121.002 Y113.326 I5.868 J-4.007 E.18032
G1 X116.337 Y108.661 E.21883
G1 X118.555 Y105.502 F36000
G1 F15476.087
G3 X119.747 Y104.395 I9.772 J9.335 E.05401
G1 X123.992 Y108.64 E.19913
G3 X124.816 Y108.156 I3.547 J5.092 E.03174
G1 X131.13 Y101.842 E.29621
G3 X133.273 Y102.569 I-3.469 J13.74 E.07512
G1 X139.931 Y109.227 E.31235
G1 X140.439 Y110.45 E.04394
G1 X141.154 Y110.45 E.02373
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y111.555 E.01358
G1 X140.631 Y111.555 E.04044
; WIPE_START
G1 X141.85 Y111.555 E-.46323
G1 X141.85 Y111.146 E-.15553
G1 X141.587 Y110.883 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X140.547 Y118.444 Z7.4 F36000
G1 X140.48 Y118.934 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42104
G1 F15000
G1 X140.278 Y118.744 E.00854
G1 X140.104 Y119.093 E.012
G1 X140.196 Y119.184 E.00399
G1 X140.042 Y119.565 E.01265
G1 X139.926 Y119.45 E.00502
G1 X139.749 Y119.807 E.01229
G1 X139.878 Y119.936 E.00565
G1 X139.715 Y120.307 E.0125
G1 X139.571 Y120.164 E.00627
G1 X139.393 Y120.52 E.01229
G1 X158.886 Y140.013 E.84939
G3 X158.645 Y140.307 I-4.334 J-3.311 E.01171
G1 X139.201 Y120.863 E.84725
G1 X139.004 Y121.201 E.01205
G1 X158.396 Y140.593 E.84498
G1 X158.147 Y140.879 E.01168
G1 X156.211 Y138.943 E.08438
G1 X156.224 Y138.972 E.00099
G3 X156.37 Y139.637 I-2.342 J.865 E.02103
G1 X157.899 Y141.165 E.0666
G3 X157.645 Y141.447 I-4.148 J-3.479 E.01167
G1 X156.383 Y140.184 E.05502
G3 X156.307 Y140.643 I-1.706 J-.046 E.01438
G1 X157.387 Y141.723 E.04708
G1 X157.129 Y142 E.01166
G1 X156.177 Y141.048 E.0415
G3 X156.003 Y141.408 I-1.398 J-.453 E.01238
G1 X156.871 Y142.277 E.03784
G3 X156.606 Y142.546 I-3.991 J-3.671 E.01165
G1 X155.789 Y141.729 E.0356
G1 X155.541 Y142.016 E.01168
G1 X156.338 Y142.813 E.03472
G1 X156.071 Y143.081 E.01165
G1 X155.26 Y142.27 E.03534
G3 X154.942 Y142.486 I-.948 J-1.048 E.01189
G1 X155.803 Y143.347 E.0375
G1 X155.526 Y143.605 E.01166
G1 X154.585 Y142.665 E.04098
G3 X154.184 Y142.798 I-.685 J-1.395 E.01308
G1 X155.249 Y143.863 E.04642
G1 X154.972 Y144.121 E.01166
G1 X153.726 Y142.875 E.05431
G3 X153.192 Y142.875 I-.269 J-1.945 E.01652
G1 X154.692 Y144.375 E.06537
G1 X154.406 Y144.624 E.01168
G1 X152.506 Y142.724 E.08277
G3 X150.684 Y140.902 I.929 J-2.751 E.08227
G1 X135.059 Y125.277 E.68087
G1 X135.378 Y125.061 E.01187
G1 X150.534 Y140.217 E.66042
G3 X150.535 Y139.684 I3.909 J-.256 E.01644
G1 X135.688 Y124.837 E.64696
G1 X135.993 Y124.607 E.01177
G1 X150.616 Y139.23 E.63717
G3 X150.75 Y138.829 I1.525 J.288 E.01306
G1 X136.285 Y124.364 E.63031
G1 X136.573 Y124.118 E.01169
G1 X150.928 Y138.473 E.6255
G3 X151.144 Y138.154 I1.268 J.627 E.0119
G1 X136.85 Y123.86 E.62284
G1 X137.122 Y123.597 E.01165
G1 X151.395 Y137.87 E.62195
G3 X151.681 Y137.621 I1.047 J.914 E.01171
G1 X137.386 Y123.326 E.62291
G1 X137.64 Y123.045 E.01167
G1 X152.003 Y137.408 E.62585
G3 X152.363 Y137.234 I.813 J1.222 E.01238
G1 X137.89 Y122.761 E.63068
G1 X138.126 Y122.462 E.01173
G1 X152.771 Y137.107 E.63816
G3 X153.232 Y137.034 I.566 J2.065 E.01442
G1 X138.36 Y122.161 E.64807
G1 X138.582 Y121.848 E.01182
G1 X153.774 Y137.04 E.66199
G3 X154.477 Y137.209 I-.38 J3.14 E.02232
G1 X138.674 Y121.406 E.6886
; WIPE_START
G1 X140.088 Y122.82 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.934 Y118.305 Z7.4 F36000
G1 X122.552 Y109.953 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X121.661 Y111.311 I8.504 J6.553 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I12.999 J-3.186 E.08976
G1 X126.946 Y126.946 E.56223
G2 X129.054 Y126.946 I1.054 J-17.467 E.06999
G1 X138.555 Y117.445 E.4457
G1 X140.473 Y117.445 E.06361
G1 X141.578 Y118.55 E.05183
G1 X140.747 Y118.55 E.02754
G1 X140.314 Y118.316 E.01633
G1 X140.035 Y118.414 E.00979
G1 X135.017 Y154.112 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42104
G1 F15000
G1 X130.887 Y149.981 E.17998
G3 X130.931 Y150.56 I-2.082 J.448 E.01793
G1 X134.416 Y154.045 E.15189
G3 X133.952 Y154.116 I-1.243 J-6.615 E.01447
G1 X130.883 Y151.047 E.13373
G3 X130.772 Y151.47 I-1.594 J-.193 E.01353
G1 X133.483 Y154.182 E.11816
G1 X133.014 Y154.248 E.01459
G1 X130.611 Y151.844 E.10472
G1 X130.41 Y152.178 E.012
G1 X132.535 Y154.303 E.09259
G1 X132.051 Y154.354 E.01499
G1 X130.165 Y152.468 E.08217
G3 X129.899 Y152.736 I-1.357 J-1.079 E.01167
G1 X131.567 Y154.404 E.07268
G3 X131.07 Y154.442 I-.786 J-7.128 E.01537
G1 X129.591 Y152.964 E.06441
G3 X129.247 Y153.154 I-.867 J-1.159 E.01216
G1 X130.57 Y154.477 E.05762
G3 X130.069 Y154.511 I-.74 J-7.184 E.01547
G1 X128.862 Y153.304 E.05259
G3 X128.428 Y153.404 I-.583 J-1.529 E.01378
G1 X129.552 Y154.529 E.049
G1 X129.036 Y154.547 E.01593
G1 X127.921 Y153.432 E.04858
G3 X127.302 Y153.348 I-.004 J-2.293 E.01929
G1 X128.682 Y154.728 E.06014
; CHANGE_LAYER
; Z_HEIGHT: 7.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X127.302 Y153.348 E-.74167
G1 X127.349 Y153.358 E-.01833
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
G1 X130.542 Y149.947
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X130.543 Y149.972 E.00082
G3 X127.927 Y153.098 I-2.545 J.528 E.15545
G3 X127.719 Y147.916 I.075 J-2.599 E.25899
G3 X130.447 Y149.63 I.279 J2.584 E.1153
G1 X130.525 Y149.89 E.00898
G1 X130.168 Y150.05 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.745 Y148.307 I-2.161 J.449 E.32546
G3 X128.596 Y148.372 I.245 J2.412 E.02636
G3 X130.155 Y149.991 I-.589 J2.127 E.07247
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13741
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11462
G1 X130.083 Y151.24 E-.11467
G1 X129.963 Y151.517 E-.11461
G1 X129.806 Y151.775 E-.11467
G1 X129.724 Y151.875 E-.04935
; WIPE_END
G1 E-.04 F1800
G1 X123.03 Y148.209 Z7.6 F36000
G1 X103.875 Y137.72 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.897 Y137.731 E.00081
G3 X102.263 Y137.372 I-1.345 J2.225 E.48532
G3 X103.581 Y137.568 I.295 J2.547 E.04474
G1 X103.822 Y137.693 E.009
G1 X103.694 Y138.066 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.29 Y137.763 I-1.142 J1.89 E.38136
G3 X103.141 Y137.827 I.245 J2.411 E.02636
G3 X103.642 Y138.035 I-.589 J2.128 E.01672
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13739
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11463
G1 X104.507 Y138.939 E-.11462
G1 X104.627 Y139.216 E-.11468
G1 X104.708 Y139.506 E-.11463
G1 X104.726 Y139.635 E-.04937
; WIPE_END
G1 E-.04 F1800
G1 X112.358 Y139.548 Z7.6 F36000
G1 X150.996 Y139.107 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.012 Y139.087 E.00085
G3 X153.174 Y137.372 I2.451 J.869 E.09652
G3 X154.493 Y137.568 I.295 J2.547 E.04473
G3 X150.917 Y139.428 I-1.029 J2.388 E.3891
G1 X150.982 Y139.166 E.00898
G1 X151.382 Y139.219 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.201 Y137.763 I2.081 J.736 E.07543
G3 X154.052 Y137.827 I.245 J2.411 E.02636
G3 X151.363 Y139.276 I-.589 J2.127 E.32249
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13724
G1 X151.65 Y138.681 E-.11461
G1 X151.84 Y138.447 E-.11467
G1 X152.099 Y138.214 E-.13216
G1 X152.307 Y138.067 E-.09696
G1 X152.575 Y137.928 E-.1147
G1 X152.698 Y137.885 E-.04966
; WIPE_END
G1 E-.04 F1800
G1 X148.139 Y131.764 Z7.6 F36000
G1 X139.911 Y120.718 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.8947
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89503
G3 X115.136 Y118.245 I16.106 J-7.696 E.08798
G3 X128.188 Y101.105 I12.867 J-3.741 E.83012
G3 X140.343 Y109.293 I-.191 J13.4 E.51436
G1 X140.671 Y110.102 E.02897
G1 X142.198 Y110.102 E.05064
G1 X142.198 Y111.905 E.0598
G1 X135.398 Y111.905 E.22557
G1 X135.398 Y112.202 E.00985
G1 X133.552 Y112.202 E.06123
G1 X133.552 Y110.639 E.05183
G2 X128.5 Y107.769 I-5.581 J3.941 E.19907
G2 X133.11 Y118.914 I-.498 J6.732 E.9121
G1 X133.552 Y118.361 E.0235
G1 X133.552 Y116.798 E.05183
G1 X135.398 Y116.798 E.06123
G1 X135.398 Y117.095 E.00985
G1 X142.198 Y117.095 E.22557
G1 X142.198 Y118.898 E.0598
G1 X140.671 Y118.898 E.05066
G3 X139.92 Y120.67 I-29.906 J-11.625 E.06384
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82944
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.194 Y100.713 I12.42 J-6.011 E.86285
G3 X140.935 Y109.71 I-.212 J13.821 E.50922
G1 X142.59 Y109.71 E.05085
G1 X142.59 Y112.297 E.07949
G1 X135.79 Y112.297 E.20895
G1 X135.79 Y112.594 E.00913
G1 X133.16 Y112.594 E.08081
G1 X133.16 Y110.777 E.05584
G2 X133.16 Y118.223 I-5.156 J3.723 E.98342
G1 X133.16 Y116.406 E.05584
G1 X135.79 Y116.406 E.08081
G1 X135.79 Y116.703 E.00913
G1 X142.59 Y116.703 E.20895
G1 X142.59 Y119.29 E.07949
G1 X140.935 Y119.29 E.05085
G3 X140.438 Y120.466 I-20.266 J-7.869 E.03922
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.432 Y118.617 Z7.6 F36000
G1 Z7.2
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.421
G1 F15000
G1 X140.251 Y118.798 E.00789
G1 X139.72 Y119.863 E.03667
G1 X140.057 Y119.527 E.01468
G3 X139.639 Y120.48 I-15.715 J-6.332 E.03208
G1 X138.607 Y121.512 E.04496
G1 X140.035 Y118.414 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.314 Y118.316 E.00979
G1 X140.747 Y118.55 E.01633
G1 X141.578 Y118.55 E.02754
G1 X140.471 Y117.443 E.0519
G1 X138.557 Y117.443 E.06351
G1 X129.054 Y126.946 E.44578
G3 X126.946 Y126.946 I-1.054 J-17.471 E.06998
G1 X114.961 Y114.961 E.56223
G2 X115.336 Y117.636 I13.373 J-.511 E.08976
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.399 J5.198 E.05392
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.21893
G2 X122.142 Y118.506 I7.008 J1.173 E.18033
G1 X118.29 Y122.358 E.18069
G2 X122.574 Y125.75 I10.066 J-8.308 E.18261
G1 X126.825 Y121.499 E.19946
G2 X129.178 Y121.502 I1.188 J-8.678 E.07828
G1 X133.426 Y125.75 E.19927
G2 X137.709 Y122.357 I-5.75 J-11.662 E.18262
G1 X133.871 Y118.519 E.18006
G1 X133.9 Y117.146 E.04555
G1 X134.145 Y117.146 E.00813
; WIPE_START
G1 X133.9 Y117.146 E-.09315
G1 X133.871 Y118.519 E-.52184
G1 X134.141 Y118.789 E-.14502
; WIPE_END
G1 E-.04 F1800
G1 X133.271 Y111.206 Z7.6 F36000
G1 X133.081 Y109.544 Z7.6
G1 Z7.2
G1 E.8 F1800
G1 F15476.087
G3 X133.9 Y110.517 I-5.888 J5.791 E.04225
G1 X133.9 Y110.872 E.01178
G1 X134.882 Y111.854 E.04603
G1 X135.05 Y111.854 E.00557
G1 X135.05 Y111.557 E.00985
G1 X136.767 Y111.557 E.05698
G1 X139.665 Y108.66 E.13591
G1 X140.632 Y111.557 F36000
G1 F15476.087
G1 X141.85 Y111.557 E.04039
G1 X141.85 Y111.146 E.01363
G1 X141.154 Y110.45 E.03263
G1 X140.439 Y110.45 E.02373
G1 X139.931 Y109.227 E.04395
G1 X133.272 Y102.568 E.31236
G2 X131.131 Y101.841 I-5.661 J13.16 E.07509
G1 X124.816 Y108.156 E.29623
G2 X123.992 Y108.64 I2.717 J5.566 E.03174
G1 X119.747 Y104.395 E.19913
G2 X118.555 Y105.502 I8.581 J10.444 E.05401
G1 X115.529 Y118.924 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.421
G1 F15000
G1 X115.722 Y118.744 E.00813
G1 X115.896 Y119.093 E.01199
G1 X115.807 Y119.181 E.00385
G2 X115.96 Y119.563 I3.829 J-1.307 E.01268
G1 X116.073 Y119.449 E.00495
G1 X116.251 Y119.806 E.01228
G1 X116.122 Y119.935 E.00562
G1 X116.285 Y120.308 E.01251
G1 X116.429 Y120.163 E.0063
G1 X116.607 Y120.52 E.01228
G1 X97.115 Y140.012 E.84928
G1 X97.359 Y140.303 E.01169
G1 X116.799 Y120.863 E.84701
G1 X116.995 Y121.201 E.01205
G1 X97.482 Y140.714 E.85019
G1 X96.75 Y139.842 F36000
G1 F15000
G1 X114.997 Y121.596 E.795
G1 X113.995 Y122.063 E.03406
G1 X96.636 Y139.422 E.75633
G1 X96.401 Y139.121 E.01174
G1 X112.993 Y122.53 E.72289
G1 X111.991 Y122.997 E.03406
G1 X96.167 Y138.821 E.68946
G3 X95.935 Y138.518 I4.207 J-3.456 E.01175
G1 X110.989 Y123.464 E.6559
G1 X109.987 Y123.931 E.03406
G1 X95.71 Y138.209 E.62206
G1 X95.485 Y137.899 E.01179
G1 X108.985 Y124.399 E.58821
G1 X107.984 Y124.866 E.03406
G1 X95.26 Y137.589 E.55436
G3 X95.041 Y137.273 I4.414 J-3.29 E.01184
G1 X106.982 Y125.333 E.52024
G1 X105.98 Y125.8 E.03406
G1 X94.826 Y136.954 E.48597
G1 X94.611 Y136.635 E.01187
G1 X104.978 Y126.267 E.4517
G1 X103.976 Y126.735 E.03406
G1 X94.396 Y136.315 E.41743
G1 X94.19 Y135.986 E.01195
G1 X102.974 Y127.202 E.38274
M73 P78 R5
G1 X101.972 Y127.669 E.03406
G1 X93.984 Y135.657 E.34805
G1 X93.779 Y135.328 E.01195
G1 X100.971 Y128.136 E.31335
G1 X99.969 Y128.603 E.03406
G1 X93.577 Y134.995 E.27848
G1 X93.381 Y134.656 E.01206
G1 X98.967 Y129.07 E.24336
G1 X97.965 Y129.538 E.03406
G1 X93.186 Y134.317 E.20823
G1 X92.99 Y133.978 E.01206
G1 X96.963 Y130.005 E.17311
G1 X95.961 Y130.472 E.03406
G1 X92.803 Y133.63 E.13761
G1 X92.617 Y133.281 E.01218
G1 X94.959 Y130.939 E.10205
G1 X93.958 Y131.406 E.03406
G1 X92.432 Y132.932 E.06649
G3 X92.248 Y132.581 I6.594 J-3.664 E.01221
G1 X93.306 Y131.523 E.04611
G1 X121.062 Y125.154 F36000
G1 F15000
G1 X105.326 Y140.891 E.68564
G2 X105.467 Y140.215 I-2.387 J-.851 E.02133
G1 X120.621 Y125.061 E.66025
G1 X120.311 Y124.836 E.01179
G1 X105.465 Y139.682 E.64686
G2 X105.384 Y139.229 I-1.691 J.067 E.01425
G1 X120.006 Y124.607 E.63708
G1 X119.714 Y124.364 E.0117
G1 X105.25 Y138.828 E.63022
G2 X105.072 Y138.472 I-1.384 J.468 E.01232
G1 X119.426 Y124.117 E.62541
G1 X119.148 Y123.86 E.01166
G1 X104.855 Y138.153 E.62274
G2 X104.604 Y137.87 I-1.157 J.773 E.01171
G1 X118.877 Y123.597 E.62188
G1 X118.613 Y123.326 E.01165
G1 X104.318 Y137.621 E.62285
G2 X103.997 Y137.408 I-.937 J1.065 E.01192
G1 X118.359 Y123.045 E.62579
G1 X118.11 Y122.76 E.01167
G1 X103.636 Y137.234 E.63062
G2 X103.23 Y137.105 I-.672 J1.416 E.01316
G1 X117.873 Y122.462 E.638
G1 X117.64 Y122.161 E.01174
G1 X102.767 Y137.034 E.64802
G2 X102.226 Y137.04 I-.247 J1.974 E.01673
G1 X117.418 Y121.848 E.66194
G1 X117.203 Y121.528 E.01187
G1 X101.522 Y137.209 E.68321
G2 X99.79 Y138.941 I1.036 J2.768 E.07782
G1 X97.85 Y140.881 E.08454
G1 X98.103 Y141.163 E.01166
G1 X99.63 Y139.636 E.06653
G2 X99.613 Y140.156 I1.885 J.32 E.0161
G1 X99.617 Y140.183 E.00083
G1 X98.356 Y141.444 E.05493
G1 X98.61 Y141.725 E.01166
G1 X99.693 Y140.642 E.04719
G2 X99.823 Y141.047 I1.539 J-.271 E.01314
G1 X98.869 Y142.001 E.04155
G1 X99.132 Y142.273 E.01165
G1 X99.997 Y141.408 E.03769
G2 X100.209 Y141.73 I1.28 J-.613 E.01193
G1 X99.394 Y142.545 E.0355
G1 X99.657 Y142.817 E.01165
G1 X100.457 Y142.017 E.03485
G2 X100.739 Y142.269 I1.061 J-.903 E.0117
G1 X99.929 Y143.08 E.03532
G1 X100.201 Y143.342 E.01165
G1 X101.057 Y142.486 E.03731
G2 X101.414 Y142.664 I.826 J-1.206 E.01232
G1 X100.473 Y143.605 E.04099
G2 X100.747 Y143.865 I3.868 J-3.802 E.01165
G1 X101.815 Y142.798 E.04653
G2 X102.272 Y142.875 I.509 J-1.625 E.01434
G1 X101.028 Y144.119 E.0542
G1 X101.31 Y144.372 E.01166
G1 X102.806 Y142.875 E.06521
G2 X103.485 Y142.732 I-.279 J-2.991 E.02141
G1 X101.591 Y144.625 E.08251
G2 X101.878 Y144.874 I3.702 J-3.987 E.01168
G1 X121.268 Y125.484 E.84482
G1 X121.602 Y125.684 E.012
G1 X102.168 Y145.117 E.8467
G1 X102.459 Y145.361 E.01169
G1 X121.948 Y125.872 E.84914
G1 X122.3 Y126.055 E.01221
G1 X102.75 Y145.605 E.8518
G2 X103.049 Y145.841 I3.516 J-4.152 E.01173
G1 X122.664 Y126.226 E.85463
G1 X123.037 Y126.388 E.01252
G1 X103.349 Y146.076 E.85778
G1 X103.649 Y146.31 E.01174
G1 X123.417 Y126.543 E.86126
G1 X123.812 Y126.682 E.01292
G1 X103.951 Y146.543 E.86534
G1 X104.261 Y146.768 E.01179
G1 X124.214 Y126.815 E.86935
G1 X124.628 Y126.935 E.01329
G1 X104.571 Y146.993 E.8739
G1 X104.88 Y147.218 E.01179
G1 X125.057 Y127.041 E.87908
G1 X125.495 Y127.138 E.01383
G1 X105.195 Y147.437 E.88446
G1 X105.515 Y147.653 E.01187
G1 X125.947 Y127.22 E.89025
G1 X126.417 Y127.285 E.01462
G1 X105.834 Y147.868 E.89682
G1 X106.153 Y148.084 E.01187
G1 X126.901 Y127.336 E.90399
G1 X127.401 Y127.371 E.01542
G1 X106.482 Y148.29 E.91144
G1 X106.811 Y148.496 E.01195
G1 X127.922 Y127.384 E.91981
G2 X128.466 Y127.374 I.172 J-5.453 E.01679
G1 X107.14 Y148.701 E.92921
G2 X107.472 Y148.904 I3.07 J-4.663 E.01199
G1 X129.035 Y127.341 E.9395
G1 X129.632 Y127.278 E.01849
G1 X107.811 Y149.099 E.95074
G1 X108.15 Y149.295 E.01206
G1 X130.263 Y127.182 E.96347
G1 X130.938 Y127.042 E.02122
G1 X108.489 Y149.491 E.97809
G2 X108.835 Y149.679 I2.864 J-4.859 E.01215
G1 X131.664 Y126.85 E.99465
G2 X132.462 Y126.587 I-2.179 J-7.947 E.02589
G1 X109.184 Y149.865 E1.0142
G1 X109.533 Y150.05 E.01218
M73 P78 R4
G1 X133.378 Y126.206 E1.03891
G2 X134.358 Y125.709 I-7.878 J-16.746 E.03386
G1 X134.488 Y125.631 E.00467
G1 X109.885 Y150.234 E1.07196
G1 X110.244 Y150.409 E.01232
G1 X139.676 Y120.977 E1.28237
G1 X140.041 Y121.147 E.0124
G1 X110.603 Y150.584 E1.2826
G1 X110.963 Y150.76 E.01232
G1 X140.406 Y121.317 E1.28282
G1 X140.77 Y121.487 E.0124
G1 X111.33 Y150.927 E1.28273
G1 X111.7 Y151.092 E.01248
G1 X141.135 Y121.657 E1.28249
G1 X141.5 Y121.827 E.0124
G1 X112.07 Y151.257 E1.28226
G2 X112.442 Y151.419 I2.502 J-5.249 E.01252
G1 X141.864 Y121.997 E1.28191
G1 X142.229 Y122.167 E.0124
G1 X112.823 Y151.573 E1.28121
G1 X113.204 Y151.727 E.01265
G1 X142.594 Y122.337 E1.2805
G1 X142.958 Y122.507 E.0124
G1 X113.585 Y151.88 E1.2798
G2 X113.975 Y152.025 I2.263 J-5.52 E.01282
G1 X143.323 Y122.677 E1.27868
G1 X143.687 Y122.847 E.0124
G1 X114.367 Y152.167 E1.27749
G1 X114.759 Y152.31 E.01285
G1 X144.052 Y123.017 E1.27629
G1 X144.417 Y123.187 E.0124
G1 X115.157 Y152.447 E1.27485
G1 X115.561 Y152.578 E.01307
G1 X144.781 Y123.357 E1.27316
G1 X145.146 Y123.527 E.0124
G1 X115.964 Y152.709 E1.27146
G2 X116.37 Y152.838 I2.047 J-5.753 E.01312
G1 X145.511 Y123.697 E1.26966
G1 X145.875 Y123.867 E.0124
G1 X116.786 Y152.957 E1.26744
G1 X117.201 Y153.076 E.01332
G1 X146.24 Y124.037 E1.26523
G1 X146.605 Y124.208 E.0124
G1 X117.617 Y153.195 E1.26301
G2 X118.044 Y153.303 I1.729 J-5.992 E.01358
G1 X146.969 Y124.378 E1.26027
G1 X147.334 Y124.548 E.0124
G1 X118.472 Y153.409 E1.25751
G1 X118.9 Y153.516 E.01359
G1 X147.699 Y124.718 E1.25475
G1 X148.063 Y124.888 E.0124
G1 X119.339 Y153.612 E1.25154
G1 X119.779 Y153.706 E.01389
G1 X148.428 Y125.058 E1.24821
G1 X148.793 Y125.228 E.0124
G1 X120.22 Y153.8 E1.24489
G2 X120.671 Y153.884 I1.432 J-6.404 E.01412
G1 X149.157 Y125.398 E1.24115
G1 X149.522 Y125.568 E.0124
G1 X127.466 Y147.623 E.96096
G3 X128.058 Y147.566 I.577 J2.904 E.01834
G1 X149.886 Y125.738 E.95108
G1 X150.251 Y125.908 E.0124
G1 X128.54 Y147.619 E.94595
G3 X128.962 Y147.732 I-.199 J1.592 E.0135
G1 X150.616 Y126.078 E.94346
G1 X150.98 Y126.248 E.0124
G1 X129.337 Y147.892 E.94303
G3 X129.671 Y148.092 I-.562 J1.317 E.01205
G1 X151.345 Y126.418 E.94435
G1 X151.71 Y126.588 E.0124
G1 X129.967 Y148.331 E.94734
G3 X130.232 Y148.6 I-1.048 J1.3 E.01167
G1 X152.074 Y126.758 E.95166
G1 X152.439 Y126.928 E.0124
G1 X130.461 Y148.906 E.95759
G3 X130.652 Y149.25 I-1.153 J.867 E.01215
G1 X152.804 Y127.098 E.96515
G1 X153.168 Y127.268 E.0124
M73 P79 R4
G1 X130.801 Y149.635 E.97454
G3 X130.899 Y150.072 I-1.538 J.575 E.01383
G1 X153.533 Y127.438 E.98615
G1 X153.898 Y127.608 E.0124
G1 X130.931 Y150.575 E1.00067
G3 X130.85 Y151.19 I-3.209 J-.107 E.01915
G1 X154.262 Y127.778 E1.02007
G1 X154.627 Y127.948 E.0124
G1 X128.017 Y154.559 E1.15941
G1 X128.551 Y154.559 E.01647
G1 X154.992 Y128.118 E1.152
G1 X155.356 Y128.288 E.0124
G1 X129.1 Y154.545 E1.14398
G1 X129.654 Y154.525 E.01708
G1 X155.721 Y128.458 E1.13573
G1 X156.085 Y128.629 E.0124
G1 X130.212 Y154.502 E1.1273
G1 X130.787 Y154.461 E.01775
G1 X156.45 Y128.799 E1.11814
G1 X156.815 Y128.969 E.0124
G1 X131.362 Y154.421 E1.10898
G2 X131.954 Y154.364 I-.531 J-8.518 E.01834
G1 X157.179 Y129.139 E1.09905
G1 X157.544 Y129.309 E.0124
G1 X132.552 Y154.301 E1.08891
G2 X133.16 Y154.227 I-.754 J-8.759 E.01889
G1 X157.909 Y129.479 E1.07828
G1 X158.273 Y129.649 E.0124
G1 X133.783 Y154.14 E1.06707
G2 X134.411 Y154.046 I-1.023 J-9.041 E.01957
G1 X158.638 Y129.819 E1.05559
G1 X159.003 Y129.989 E.0124
G1 X134.851 Y154.141 E1.05231
G1 X127.312 Y154.728 F36000
G1 F15000
G1 X128.691 Y153.35 E.06006
G3 X128.081 Y153.425 I-.539 J-1.855 E.01902
G1 X126.959 Y154.547 E.04886
G1 X126.443 Y154.529 E.01593
G1 X127.568 Y153.403 E.04902
G3 X127.134 Y153.302 I.151 J-1.629 E.01376
G1 X125.926 Y154.511 E.05263
G3 X125.425 Y154.476 I.243 J-7.233 E.01546
G1 X126.749 Y153.153 E.05767
G3 X126.405 Y152.962 I.523 J-1.346 E.01215
G1 X124.926 Y154.441 E.06447
G3 X124.429 Y154.404 I.289 J-7.137 E.01536
G1 X126.098 Y152.734 E.07275
G3 X125.826 Y152.472 I.817 J-1.12 E.01169
G1 X123.945 Y154.353 E.08197
G1 X123.461 Y154.302 E.01499
G1 X125.588 Y152.175 E.09269
G1 X125.387 Y151.841 E.012
G1 X122.981 Y154.247 E.10482
G1 X122.513 Y154.181 E.01459
G1 X125.227 Y151.466 E.11828
G3 X125.116 Y151.043 I1.486 J-.615 E.01354
G1 X122.044 Y154.115 E.13387
G3 X121.58 Y154.044 I.78 J-6.679 E.01446
G1 X125.069 Y150.555 E.15204
G3 X125.114 Y149.976 I2.129 J-.128 E.01795
G1 X120.979 Y154.111 E.18016
; WIPE_START
G1 X122.393 Y152.697 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.829 Y150.977 Z7.6 F36000
G1 X153.689 Y145.461 Z7.6
G1 Z7.2
G1 E.8 F1800
G1 F15000
G1 X156.831 Y142.319 E.13689
G2 X159.944 Y138.672 I-27.89 J-26.953 E.14782
G1 X152.172 Y146.444 E.33861
G3 X150.296 Y147.785 I-29.094 J-38.708 E.07106
G1 X161.285 Y136.796 E.47879
G2 X162.22 Y135.327 I-20.534 J-14.093 E.05366
G1 X148.827 Y148.72 E.58352
G3 X147.544 Y149.468 I-11.359 J-18.005 E.04575
G1 X154.222 Y142.79 E.29094
G3 X153.593 Y142.884 I-.656 J-2.241 E.01964
G1 X146.387 Y150.09 E.31397
G3 X145.318 Y150.624 I-8.167 J-15.011 E.03681
G1 X153.075 Y142.867 E.33796
G1 X152.634 Y142.774 E.0139
G1 X144.317 Y151.091 E.36238
G3 X143.386 Y151.487 I-6.138 J-13.136 E.03116
G1 X152.244 Y142.629 E.38596
G3 X151.896 Y142.442 I.506 J-1.361 E.01221
G1 X142.485 Y151.854 E.41006
G3 X141.638 Y152.166 I-6.379 J-16.01 E.0278
G1 X151.585 Y142.219 E.43339
G1 X151.309 Y141.96 E.01165
G1 X140.812 Y152.457 E.45735
G1 X140.02 Y152.715 E.02566
G1 X151.069 Y141.666 E.48141
G3 X150.865 Y141.335 I1.1 J-.908 E.01201
G1 X139.254 Y152.946 E.50589
G1 X138.504 Y153.161 E.02403
G1 X150.699 Y140.966 E.53135
G1 X150.579 Y140.551 E.0133
G1 X137.785 Y153.345 E.55745
G1 X137.073 Y153.523 E.02262
G1 X150.525 Y140.07 E.58613
G3 X150.56 Y139.501 I2.091 J-.157 E.01764
G1 X136.391 Y153.67 E.61736
G1 X135.712 Y153.814 E.02139
G1 X150.791 Y138.735 E.65699
G3 X152.242 Y137.284 I2.672 J1.22 E.0646
G1 X159.367 Y130.159 E.31044
G1 X159.732 Y130.329 E.0124
G1 X152.995 Y137.066 E.29353
G3 X153.569 Y137.026 I.468 J2.606 E.01777
G1 X160.097 Y130.499 E.28439
G1 X160.461 Y130.669 E.0124
G1 X154.045 Y137.085 E.27955
G3 X154.462 Y137.203 I-.222 J1.576 E.01338
G1 X160.826 Y130.839 E.27729
G1 X161.191 Y131.009 E.0124
G1 X154.832 Y137.368 E.27706
G3 X155.162 Y137.573 I-.58 J1.304 E.012
G1 X161.555 Y131.179 E.27857
G1 X161.92 Y131.349 E.0124
G1 X155.456 Y137.813 E.28165
G3 X155.715 Y138.089 I-.872 J1.082 E.01169
G1 X162.285 Y131.519 E.28624
G1 X162.649 Y131.689 E.0124
G1 X155.939 Y138.399 E.29235
G3 X156.126 Y138.747 I-1.17 J.852 E.0122
G1 X163.014 Y131.859 E.3001
G1 X163.378 Y132.029 E.0124
G1 X156.27 Y139.138 E.30971
G3 X156.362 Y139.58 I-1.563 J.557 E.01397
G1 X163.743 Y132.199 E.32158
G1 X163.902 Y132.273 E.0054
G1 X163.589 Y132.888 E.02123
G1 X156.387 Y140.091 E.31383
G3 X156.283 Y140.729 I-3.273 J-.204 E.01996
G1 X163.403 Y133.609 E.31022
; WIPE_START
G1 X161.989 Y135.023 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X157.108 Y129.155 Z7.6 F36000
G1 X137.441 Y105.506 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X136.251 Y104.397 I-10.225 J9.773 E.05399
G1 X132.006 Y108.642 E.19916
G2 X131.182 Y108.154 I-4.705 J6.995 E.03179
G1 X124.868 Y101.84 E.29618
G2 X122.72 Y102.576 I6.275 J21.828 E.07536
G1 X116.079 Y109.217 E.31154
G2 X115.507 Y110.74 I10.818 J4.931 E.054
; CHANGE_LAYER
; Z_HEIGHT: 7.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X116.079 Y109.217 E-.61814
G1 X116.343 Y108.953 E-.14186
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
G1 X130.542 Y149.947
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X130.552 Y149.97 E.00081
G3 X127.664 Y147.92 I-2.547 J.529 E.41295
G3 X128.355 Y147.921 I.341 J2.512 E.02299
G3 X130.456 Y149.627 I-.35 J2.578 E.09443
G1 X130.527 Y149.889 E.009
G1 X130.17 Y150.049 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.716 Y148.309 I-2.162 J.448 E.32451
G1 X128 Y148.29 E.00875
G3 X130.157 Y149.991 I.008 J2.208 E.0911
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13749
G1 X130.205 Y150.651 E-.11463
G1 X130.164 Y150.95 E-.11464
G1 X130.083 Y151.24 E-.11465
G1 X129.963 Y151.517 E-.11466
G1 X129.806 Y151.775 E-.11465
G1 X129.724 Y151.875 E-.04928
; WIPE_END
G1 E-.04 F1800
G1 X136.268 Y147.947 Z7.8 F36000
G1 X150.996 Y139.107 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X151.008 Y139.086 E.00082
G3 X153.12 Y137.375 I2.452 J.868 E.09484
G3 X153.811 Y137.377 I.341 J2.513 E.02299
G3 X150.913 Y139.428 I-.35 J2.578 E.41256
G1 X150.981 Y139.165 E.00898
G1 X151.378 Y139.217 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X153.172 Y137.765 I2.082 J.737 E.07462
G3 X153.757 Y137.766 I.288 J2.128 E.01804
G3 X151.359 Y139.274 I-.297 J2.188 E.33187
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13729
G1 X151.65 Y138.681 E-.11464
G1 X151.84 Y138.447 E-.11466
G1 X152.061 Y138.241 E-.11464
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11468
G1 X152.698 Y137.885 E-.04947
; WIPE_END
G1 E-.04 F1800
G1 X145.065 Y137.859 Z7.8 F36000
G1 X103.875 Y137.72 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.898 Y137.73 E.00081
G3 X102.208 Y137.375 I-1.349 J2.224 E.48372
G3 X102.899 Y137.377 I.341 J2.513 E.02299
G3 X103.582 Y137.567 I-.35 J2.577 E.02359
G1 X103.822 Y137.693 E.009
G1 X103.695 Y138.064 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.26 Y137.765 I-1.142 J1.89 E.38041
G1 X102.544 Y137.745 E.00875
G3 X103.643 Y138.033 I.008 J2.208 E.0353
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13745
G1 X104.16 Y138.447 E-.11465
G1 X104.35 Y138.681 E-.11463
G1 X104.507 Y138.939 E-.11466
G1 X104.627 Y139.216 E-.11465
G1 X104.708 Y139.506 E-.11463
G1 X104.726 Y139.635 E-.04934
; WIPE_END
G1 E-.04 F1800
G1 X111.449 Y136.021 Z7.8 F36000
G1 X139.911 Y120.718 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.355 Y132.117 E.8947
G3 X91.645 Y132.117 I-36.355 J-17.63 E3.00031
G1 X116.098 Y120.714 E.89503
G3 X115.136 Y118.245 I16.104 J-7.695 E.08798
G3 X128.181 Y101.105 I12.867 J-3.741 E.82988
G3 X140.346 Y109.299 I-.184 J13.4 E.51483
G1 X140.671 Y110.102 E.02875
G1 X142.198 Y110.102 E.05065
G1 X142.198 Y111.924 E.06045
G1 X135.398 Y111.924 E.22557
G1 X135.398 Y112.227 E.01003
G1 X133.552 Y112.227 E.06123
G1 X133.552 Y110.639 E.05265
G2 X126.518 Y107.912 I-5.579 J3.955 E.26508
G1 X126.419 Y107.939 E.00342
G2 X133.11 Y118.914 I1.583 J6.563 E.84273
G1 X133.552 Y118.361 E.0235
G1 X133.552 Y116.773 E.05265
G1 X135.398 Y116.773 E.06123
G1 X135.398 Y117.076 E.01003
G1 X142.198 Y117.076 E.22557
G1 X142.198 Y118.898 E.06045
G1 X140.671 Y118.898 E.05067
G3 X139.92 Y120.67 I-29.858 J-11.603 E.06384
G1 X140.413 Y120.52 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82944
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.187 Y100.713 I12.42 J-6.011 E.86263
G3 X140.935 Y109.71 I-.205 J13.821 E.50944
G1 X142.59 Y109.71 E.05085
G1 X142.59 Y112.316 E.08009
G1 X135.79 Y112.316 E.20895
G1 X135.79 Y112.619 E.00929
G1 X133.16 Y112.619 E.08081
G1 X133.16 Y110.777 E.0566
G2 X133.16 Y118.223 I-5.156 J3.723 E.98342
G1 X133.16 Y116.381 E.0566
G1 X135.79 Y116.381 E.08081
G1 X135.79 Y116.684 E.00929
G1 X142.59 Y116.684 E.20895
G1 X142.59 Y119.29 E.08009
G1 X140.935 Y119.29 E.05085
G3 X140.438 Y120.466 I-20.236 J-7.856 E.03922
M204 S10000
G1 X140.651 Y121.244 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42104
G1 F15000
G1 X159.125 Y139.718 E.80499
G1 X159.364 Y139.422 E.01171
G1 X142.004 Y122.062 E.75647
G1 X143.006 Y122.529 E.03406
G1 X159.602 Y139.126 E.72318
G1 X159.832 Y138.821 E.01177
G1 X144.008 Y122.997 E.68953
G1 X145.01 Y123.464 E.03406
G1 X160.062 Y138.516 E.65588
G1 X160.291 Y138.211 E.01176
G1 X146.012 Y123.931 E.62223
G1 X147.014 Y124.398 E.03406
G1 X160.517 Y137.901 E.58839
G1 X160.737 Y137.587 E.01183
G1 X148.016 Y124.865 E.55433
G1 X149.018 Y125.333 E.03406
G1 X160.957 Y137.272 E.52026
G1 X161.177 Y136.958 E.01183
G1 X150.02 Y125.8 E.4862
G1 X151.022 Y126.267 E.03406
G1 X161.39 Y136.635 E.45178
G1 X161.6 Y136.311 E.01191
G1 X152.023 Y126.734 E.4173
G1 X153.025 Y127.202 E.03406
G1 X161.811 Y135.987 E.38281
G2 X162.019 Y135.66 I-4.559 J-3.142 E.01193
M73 P80 R4
G1 X154.027 Y127.669 E.34824
G1 X155.029 Y128.136 E.03406
G1 X162.22 Y135.326 E.31332
G1 X162.421 Y134.992 E.01201
G1 X156.031 Y128.603 E.27841
G1 X157.033 Y129.07 E.03406
G1 X162.621 Y134.658 E.24349
G2 X162.816 Y134.318 I-4.773 J-2.954 E.01208
G1 X158.035 Y129.538 E.2083
G1 X159.037 Y130.005 E.03406
G1 X163.006 Y133.974 E.17295
G1 X163.197 Y133.63 E.01212
G1 X160.039 Y130.472 E.1376
G1 X161.041 Y130.939 E.03406
G1 X163.387 Y133.285 E.10222
G1 X163.567 Y132.931 E.01225
G1 X162.043 Y131.407 E.06642
G1 X163.045 Y131.874 E.03406
G1 X163.874 Y132.703 E.03611
G1 X154.24 Y144.993 F36000
G1 F15000
G1 X134.731 Y125.484 E.85009
G1 X134.397 Y125.685 E.01201
G1 X153.833 Y145.121 E.84693
G3 X153.541 Y145.363 I-3.616 J-4.08 E.01171
G1 X134.05 Y125.873 E.84928
G1 X133.698 Y126.055 E.01223
G1 X153.245 Y145.603 E.85177
G1 X152.95 Y145.842 E.01171
G1 X133.334 Y126.226 E.85474
G1 X132.962 Y126.389 E.01252
G1 X152.654 Y146.081 E.85807
G1 X152.349 Y146.31 E.01177
G1 X132.582 Y126.544 E.86134
G1 X132.187 Y126.683 E.01291
G1 X152.044 Y146.54 E.86528
G1 X151.739 Y146.77 E.01177
G1 X131.784 Y126.815 E.86952
G1 X131.37 Y126.936 E.01329
G1 X151.43 Y146.996 E.87412
G1 X151.116 Y147.217 E.01183
G1 X130.941 Y127.041 E.87913
G1 X130.503 Y127.138 E.01382
G1 X150.801 Y147.437 E.8845
G1 X150.487 Y147.657 E.01183
G1 X130.051 Y127.221 E.8905
G1 X129.58 Y127.285 E.01463
G1 X150.165 Y147.87 E.89698
G1 X149.841 Y148.081 E.01191
G1 X129.096 Y127.336 E.90394
G1 X128.597 Y127.371 E.01543
G1 X149.517 Y148.291 E.91158
G3 X149.191 Y148.501 I-3.139 J-4.52 E.01192
G1 X128.076 Y127.385 E.92012
G1 X128.004 Y127.386 E.00219
G3 X127.531 Y127.374 I-.004 J-9.186 E.01461
G1 X148.857 Y148.701 E.92931
G1 X148.523 Y148.902 E.01201
G1 X126.962 Y127.34 E.93954
G1 X126.365 Y127.278 E.0185
G1 X148.189 Y149.103 E.951
G3 X147.85 Y149.298 I-2.972 J-4.768 E.01207
G1 X125.733 Y127.181 E.96373
G1 X125.059 Y127.042 E.0212
G1 X147.506 Y149.489 E.97811
G1 X147.162 Y149.679 E.01212
G1 X124.332 Y126.849 E.99483
G1 X124.082 Y126.776 E.00801
G3 X123.531 Y126.583 I3.342 J-10.43 E.01798
G1 X146.818 Y149.87 E1.01471
G3 X146.464 Y150.051 I-2.753 J-4.955 E.01225
G1 X122.617 Y126.204 E1.03912
G1 X122.236 Y126.026 E.01295
G3 X121.504 Y125.626 I11.125 J-21.247 E.02571
G1 X146.11 Y150.231 E1.07219
G1 X145.755 Y150.412 E.01225
G1 X116.321 Y120.978 E1.28258
G1 X115.957 Y121.148 E.0124
G1 X145.396 Y150.588 E1.28282
G1 X145.032 Y150.758 E.0124
G1 X115.592 Y121.318 E1.28282
G1 X115.227 Y121.488 E.0124
G1 X144.667 Y150.927 E1.28282
G1 X144.302 Y151.097 E.0124
G1 X114.863 Y121.658 E1.28281
G1 X114.498 Y121.828 E.0124
G1 X143.927 Y151.257 E1.28237
G1 X143.552 Y151.417 E.01257
G1 X114.133 Y121.998 E1.2819
G1 X113.769 Y122.168 E.0124
G1 X143.176 Y151.576 E1.28144
G3 X142.796 Y151.731 I-3.161 J-7.213 E.01264
G1 X113.404 Y122.338 E1.28077
G1 X113.039 Y122.508 E.0124
G1 X142.413 Y151.882 E1.27995
G3 X142.022 Y152.026 I-2.945 J-7.398 E.01284
G1 X112.675 Y122.678 E1.27881
G1 X112.31 Y122.848 E.0124
G1 X141.63 Y152.168 E1.27761
G1 X141.238 Y152.311 E.01285
G1 X111.945 Y123.019 E1.27642
G1 X111.58 Y123.189 E.0124
G1 X140.84 Y152.448 E1.27497
G1 X140.436 Y152.579 E.01308
G1 X111.216 Y123.359 E1.27328
G1 X110.851 Y123.529 E.0124
G1 X140.033 Y152.71 E1.27158
G3 X139.627 Y152.839 I-2.042 J-5.741 E.01313
G1 X110.486 Y123.699 E1.26978
G1 X110.122 Y123.869 E.0124
G1 X139.211 Y152.958 E1.26756
G1 X138.795 Y153.077 E.01332
G1 X109.757 Y124.039 E1.26534
G1 X109.392 Y124.209 E.0124
G1 X138.38 Y153.196 E1.26313
G3 X137.952 Y153.303 I-1.777 J-6.195 E.01359
G1 X109.028 Y124.379 E1.26038
G1 X108.663 Y124.549 E.0124
G1 X137.524 Y153.41 E1.25762
G1 X137.096 Y153.517 E.01359
G1 X108.298 Y124.719 E1.25486
G1 X107.934 Y124.889 E.0124
G1 X136.658 Y153.613 E1.25164
G1 X136.217 Y153.707 E.01389
G1 X107.569 Y125.059 E1.24832
G1 X107.204 Y125.229 E.0124
G1 X135.776 Y153.801 E1.24499
G3 X135.325 Y153.885 I-1.431 J-6.411 E.01413
G1 X106.84 Y125.399 E1.24125
G1 X106.475 Y125.569 E.0124
G1 X128.52 Y147.615 E.96063
G2 X127.938 Y147.567 I-.576 J3.422 E.01804
G1 X106.11 Y125.739 E.95112
G1 X105.745 Y125.909 E.0124
G1 X127.457 Y147.621 E.94608
G2 X127.034 Y147.733 I.174 J1.511 E.01352
G1 X105.381 Y126.08 E.94354
G1 X105.016 Y126.25 E.0124
G1 X126.66 Y147.894 E.94313
G2 X126.326 Y148.094 I.564 J1.316 E.01204
G1 X104.651 Y126.42 E.94447
G1 X104.287 Y126.59 E.0124
G1 X126.028 Y148.331 E.94739
G2 X125.765 Y148.603 I.856 J1.093 E.01169
G1 X103.922 Y126.76 E.95181
G1 X103.557 Y126.93 E.0124
G1 X125.537 Y148.91 E.95776
G2 X125.346 Y149.253 I1.155 J.866 E.01216
G1 X103.193 Y127.1 E.96534
G1 X102.828 Y127.27 E.0124
G1 X125.198 Y149.64 E.97475
G2 X125.1 Y150.077 I1.542 J.574 E.01384
G1 X102.463 Y127.44 E.98639
G1 X102.099 Y127.61 E.0124
G1 X125.069 Y150.581 E1.00094
G2 X125.152 Y151.198 I3.187 J-.113 E.01923
G1 X101.734 Y127.78 E1.02044
G1 X101.369 Y127.95 E.0124
G1 X127.978 Y154.559 E1.15945
G1 X128.512 Y154.559 E.01648
G1 X127.302 Y153.348 E.05274
G2 X127.921 Y153.432 I.614 J-2.209 E.01929
G1 X129.035 Y154.547 E.04857
G1 X129.552 Y154.529 E.01593
G1 X128.428 Y153.404 E.04899
G2 X128.862 Y153.304 I-.149 J-1.63 E.01378
G1 X130.069 Y154.511 E.05258
G2 X130.569 Y154.477 I-.234 J-7.147 E.01547
G1 X129.247 Y153.154 E.05761
G2 X129.591 Y152.964 I-.521 J-1.347 E.01216
G1 X131.069 Y154.442 E.0644
G2 X131.567 Y154.404 I-.288 J-7.154 E.01537
G1 X129.899 Y152.737 E.07267
G2 X130.172 Y152.475 I-.818 J-1.124 E.01169
G1 X132.05 Y154.353 E.08187
G1 X132.534 Y154.303 E.01499
G1 X130.41 Y152.178 E.09258
G1 X130.611 Y151.845 E.012
G1 X133.014 Y154.248 E.1047
G1 X133.483 Y154.182 E.01459
G1 X130.772 Y151.47 E.11814
G2 X130.883 Y151.047 I-1.484 J-.617 E.01353
G1 X133.952 Y154.116 E.13372
G2 X134.416 Y154.045 I-.777 J-6.676 E.01447
G1 X130.931 Y150.56 E.15187
G2 X130.887 Y149.981 I-2.126 J-.13 E.01793
G1 X135.017 Y154.111 E.17997
G1 X127.613 Y154.728 F36000
G1 F15000
G1 X101.005 Y128.12 E1.15944
G1 X100.64 Y128.29 E.0124
G1 X126.894 Y154.544 E1.14401
G1 X126.34 Y154.525 E.01708
G1 X100.275 Y128.46 E1.13576
G1 X99.911 Y128.63 E.0124
G1 X125.781 Y154.501 E1.12731
G1 X125.206 Y154.461 E.01776
G1 X99.546 Y128.8 E1.11815
G1 X99.181 Y128.97 E.0124
M73 P81 R4
G1 X124.631 Y154.421 E1.10899
G3 X124.039 Y154.363 I.533 J-8.505 E.01835
G1 X98.816 Y129.141 E1.09905
G1 X98.452 Y129.311 E.0124
G1 X123.441 Y154.3 E1.08891
G3 X122.832 Y154.226 I.756 J-8.754 E.0189
G1 X98.087 Y129.481 E1.07827
G1 X97.722 Y129.651 E.0124
G1 X122.21 Y154.138 E1.06705
G3 X121.582 Y154.045 I1.029 J-9.05 E.01958
G1 X97.358 Y129.821 E1.05555
G1 X96.993 Y129.991 E.0124
G1 X120.932 Y153.93 E1.04316
G3 X120.28 Y153.812 I1.365 J-9.429 E.02044
G1 X105.214 Y138.747 E.65649
G3 X105.441 Y139.508 I-2.711 J1.222 E.02455
G1 X119.601 Y153.668 E.61702
G3 X118.919 Y153.521 I1.768 J-9.827 E.02151
G1 X105.475 Y140.077 E.58581
G3 X105.419 Y140.556 I-5.924 J-.441 E.01487
G1 X118.206 Y153.343 E.55718
G3 X117.487 Y153.158 I2.286 J-10.393 E.02289
G1 X105.299 Y140.97 E.53109
G3 X105.133 Y141.339 I-1.424 J-.418 E.0125
G1 X116.737 Y152.943 E.50564
G3 X115.97 Y152.711 I2.935 J-11.087 E.02468
G1 X104.928 Y141.669 E.48115
G1 X104.687 Y141.962 E.0117
G1 X115.178 Y152.454 E.45717
G3 X114.351 Y152.162 I3.772 J-11.986 E.02704
G1 X104.411 Y142.222 E.43312
G3 X104.1 Y142.445 I-.968 J-1.024 E.01185
G1 X113.501 Y151.847 E.40968
G1 X112.604 Y151.484 E.02982
G1 X103.751 Y142.631 E.38577
G3 X103.361 Y142.776 I-.721 J-1.348 E.01286
G1 X111.66 Y151.074 E.3616
G3 X110.665 Y150.614 I6.083 J-14.46 E.03378
G1 X102.919 Y142.868 E.33754
G3 X102.399 Y142.883 I-.319 J-1.992 E.01605
G1 X109.603 Y150.087 E.3139
G3 X108.449 Y149.468 I8.279 J-16.81 E.04037
G1 X101.494 Y142.513 E.30306
G1 X97.096 Y140.254 F36000
G1 F15000
G1 X99.729 Y142.887 E.11474
G2 X103.821 Y146.445 I27.756 J-27.795 E.16722
G1 X96.055 Y138.679 E.3384
G3 X94.744 Y136.833 I40.95 J-30.475 E.06977
G1 X105.667 Y147.756 E.47596
G2 X107.16 Y148.714 I14.483 J-20.92 E.05468
G1 X93.786 Y135.34 E.58279
G3 X93.032 Y134.051 I18.058 J-11.427 E.04599
G1 X99.72 Y140.739 E.29141
G3 X99.613 Y140.098 I3.215 J-.864 E.02006
G1 X92.413 Y132.897 E.31377
G3 X92.096 Y132.275 I11.715 J-6.364 E.02153
G1 X92.252 Y132.202 E.00532
G1 X99.637 Y139.586 E.32178
G3 X99.728 Y139.143 I1.656 J.111 E.01399
G1 X92.617 Y132.032 E.30989
G1 X92.981 Y131.861 E.0124
G1 X99.872 Y138.752 E.30025
G3 X100.058 Y138.403 I1.359 J.503 E.01221
G1 X93.346 Y131.691 E.29248
G1 X93.711 Y131.521 E.0124
G1 X100.282 Y138.093 E.28634
G3 X100.541 Y137.817 I1.133 J.804 E.01169
G1 X94.076 Y131.351 E.28173
G1 X94.44 Y131.181 E.0124
G1 X100.834 Y137.575 E.27863
G3 X101.164 Y137.37 I.911 J1.096 E.012
G1 X94.805 Y131.011 E.2771
G1 X95.17 Y130.841 E.0124
G1 X101.533 Y137.205 E.2773
G3 X101.95 Y137.087 I.614 J1.377 E.0134
G1 X95.534 Y130.671 E.27958
G1 X95.899 Y130.501 E.0124
G1 X102.425 Y137.027 E.28435
G3 X102.944 Y137.046 I.19 J1.901 E.01608
G1 X102.987 Y137.055 E.00135
G1 X96.264 Y130.331 E.29298
G1 X96.628 Y130.161 E.0124
G1 X104.243 Y137.775 E.3318
; WIPE_START
G1 X102.829 Y136.361 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X107.649 Y130.444 Z7.8 F36000
G1 X116.033 Y120.154 Z7.8
G1 Z7.4
G1 E.8 F1800
G1 F15000
G1 X116.874 Y120.995 E.03665
G3 X116.283 Y119.87 I10.687 J-6.326 E.03918
G1 X115.947 Y119.534 E.01462
G3 X115.652 Y118.765 I21.553 J-8.713 E.02539
G1 X115.693 Y118.746 E.00141
G1 X116.13 Y119.182 E.01902
G1 X115.507 Y110.741 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X116.079 Y109.218 I11.436 J3.423 E.054
G1 X122.72 Y102.576 E.31158
G3 X124.868 Y101.84 I8.592 J21.588 E.07533
G1 X131.182 Y108.154 E.29618
G3 X132.006 Y108.642 I-3.88 J7.481 E.03179
G1 X136.251 Y104.397 E.19916
G3 X137.441 Y105.507 I-8.89 J10.724 E.05399
G1 X139.665 Y108.66 F36000
G1 F15476.087
G1 X136.748 Y111.576 E.13682
G1 X135.05 Y111.576 E.05634
G1 X135.05 Y111.878 E.01003
G1 X134.906 Y111.878 E.00476
G1 X133.9 Y110.872 E.04719
G1 X133.9 Y110.517 E.01178
G2 X133.081 Y109.544 I-6.71 J4.819 E.04225
; WIPE_START
G1 X133.9 Y110.517 E-.48353
G1 X133.9 Y110.872 E-.13491
G1 X134.164 Y111.136 E-.14156
; WIPE_END
G1 E-.04 F1800
G1 X134.121 Y117.122 Z7.8 F36000
G1 Z7.4
G1 E.8 F1800
G1 F15476.087
G1 X133.9 Y117.122 E.00731
G1 X133.871 Y118.519 E.04637
G1 X137.709 Y122.357 E.18006
G3 X133.426 Y125.75 I-10.034 J-8.27 E.18262
G1 X129.178 Y121.502 E.19927
G3 X126.825 Y121.499 I-1.165 J-8.668 E.07828
G1 X122.574 Y125.75 E.19946
G3 X118.29 Y122.358 I5.782 J-11.701 E.18261
G1 X122.142 Y118.506 E.18069
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.659 E.21893
G1 X118.555 Y105.502 F36000
G1 F15476.087
G3 X119.747 Y104.395 I9.772 J9.337 E.05401
G1 X123.992 Y108.64 E.19913
G3 X124.816 Y108.156 I3.543 J5.086 E.03174
G1 X131.131 Y101.841 E.29623
G3 X133.272 Y102.568 I-3.569 J14.033 E.07507
G1 X139.93 Y109.226 E.31237
G1 X140.439 Y110.45 E.04396
G1 X141.154 Y110.45 E.02373
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y111.576 E.01427
G1 X140.652 Y111.576 E.03974
; WIPE_START
G1 X141.85 Y111.576 E-.45529
G1 X141.85 Y111.146 E-.16347
G1 X141.587 Y110.883 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X140.547 Y118.444 Z7.8 F36000
G1 X140.48 Y118.934 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42104
G1 F15000
G1 X140.278 Y118.744 E.00853
G1 X140.104 Y119.093 E.012
G1 X140.195 Y119.184 E.00398
G3 X140.041 Y119.565 I-6.147 J-2.269 E.01265
G1 X139.926 Y119.45 E.00501
G1 X139.749 Y119.807 E.01229
G1 X139.878 Y119.936 E.00564
G1 X139.714 Y120.308 E.0125
G1 X139.571 Y120.164 E.00626
G1 X139.393 Y120.521 E.01229
G1 X158.885 Y140.013 E.84938
G3 X158.644 Y140.307 I-4.334 J-3.311 E.01171
G1 X139.201 Y120.863 E.84725
G1 X139.004 Y121.202 E.01205
G1 X158.396 Y140.593 E.84497
G1 X158.147 Y140.879 E.01168
G1 X156.207 Y138.939 E.08454
G3 X156.37 Y139.637 I-3.054 J1.083 E.02214
G1 X157.898 Y141.165 E.06659
G3 X157.645 Y141.447 I-4.154 J-3.485 E.01167
G1 X156.383 Y140.184 E.05501
G3 X156.307 Y140.643 I-1.707 J-.046 E.01438
G1 X157.387 Y141.723 E.04707
G1 X157.129 Y142 E.01166
G1 X156.177 Y141.048 E.04149
G3 X156.002 Y141.408 I-1.327 J-.42 E.01238
G1 X156.871 Y142.277 E.03785
G3 X156.605 Y142.546 I-3.991 J-3.671 E.01165
G1 X155.79 Y141.731 E.03553
G3 X155.542 Y142.017 I-1.169 J-.759 E.01172
G1 X156.338 Y142.813 E.03468
G1 X156.071 Y143.081 E.01165
G1 X155.26 Y142.27 E.03533
G3 X154.942 Y142.487 I-.948 J-1.049 E.01189
G1 X155.802 Y143.347 E.03749
G1 X155.526 Y143.605 E.01166
G1 X154.585 Y142.665 E.04098
G3 X154.184 Y142.798 I-.685 J-1.395 E.01308
G1 X155.249 Y143.863 E.04642
G1 X154.972 Y144.121 E.01166
G1 X153.726 Y142.874 E.05432
G3 X153.192 Y142.875 I-.27 J-2.055 E.0165
G1 X154.692 Y144.375 E.06537
G1 X154.406 Y144.624 E.01168
G1 X152.512 Y142.731 E.0825
G3 X150.675 Y140.893 I.909 J-2.746 E.08303
G1 X135.059 Y125.277 E.68048
G1 X135.378 Y125.061 E.01187
G1 X150.534 Y140.217 E.66042
G3 X150.535 Y139.684 I3.907 J-.256 E.01644
G1 X135.688 Y124.837 E.64696
G1 X135.993 Y124.607 E.01177
G1 X150.616 Y139.23 E.63717
G3 X150.75 Y138.829 I1.523 J.288 E.01306
G1 X136.285 Y124.365 E.6303
G1 X136.573 Y124.118 E.01169
G1 X150.928 Y138.473 E.62549
G3 X151.144 Y138.154 I1.268 J.626 E.0119
G1 X136.85 Y123.86 E.62284
G1 X137.122 Y123.597 E.01165
G1 X151.395 Y137.87 E.62194
G3 X151.681 Y137.621 I1.049 J.916 E.01171
G1 X137.386 Y123.326 E.62291
G1 X137.64 Y123.046 E.01167
G1 X152.002 Y137.408 E.62585
G3 X152.363 Y137.234 I.815 J1.225 E.01238
G1 X137.89 Y122.761 E.63067
G1 X138.126 Y122.462 E.01173
G1 X152.769 Y137.106 E.63808
G3 X153.232 Y137.034 I.509 J1.749 E.01447
G1 X138.36 Y122.161 E.64806
G1 X138.582 Y121.848 E.01182
G1 X153.773 Y137.04 E.66198
G3 X154.476 Y137.208 I-.379 J3.137 E.02232
G1 X138.674 Y121.406 E.68858
; WIPE_START
G1 X140.088 Y122.82 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.934 Y118.305 Z7.8 F36000
G1 X122.552 Y109.953 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X121.661 Y111.311 I8.509 J6.556 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I12.997 J-3.186 E.08976
G1 X126.946 Y126.946 E.56223
G2 X129.054 Y126.946 I1.054 J-17.471 E.06998
G1 X138.576 Y117.424 E.44669
G1 X140.452 Y117.424 E.06222
G1 X141.578 Y118.55 E.05281
G1 X140.747 Y118.55 E.02755
G1 X140.314 Y118.316 E.01632
G1 X140.035 Y118.414 E.00979
; CHANGE_LAYER
; Z_HEIGHT: 7.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X140.314 Y118.316 E-.1122
G1 X140.747 Y118.55 E-.187
G1 X141.578 Y118.55 E-.31556
G1 X141.307 Y118.279 E-.14524
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
G1 X130.162 Y150.051
G1 Z7.6
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.699 Y148.31 I-2.162 J.447 E.32425
G1 X128 Y148.29 E.00927
G3 X130.149 Y149.992 I0 J2.208 E.0909
; WIPE_START
M204 S10000
G1 X130.205 Y150.349 E-.13731
G1 X130.205 Y150.651 E-.11467
G1 X130.164 Y150.95 E-.11462
G1 X130.083 Y151.24 E-.11466
G1 X129.963 Y151.517 E-.11463
G1 X129.806 Y151.775 E-.11468
G1 X129.724 Y151.876 E-.04944
; WIPE_END
G1 E-.04 F1800
G1 X136.313 Y148.023 Z8 F36000
G1 X151.374 Y139.216 Z8
G1 Z7.6
G1 E.8 F1800
G1 F12000
M204 S6000
G3 X153.155 Y137.766 I2.081 J.737 E.0742
G1 X153.456 Y137.745 E.00927
G3 X151.355 Y139.273 I0 J2.208 E.34095
; WIPE_START
M204 S10000
G1 X151.493 Y138.939 E-.13732
G1 X151.65 Y138.681 E-.11468
G1 X151.84 Y138.447 E-.11461
G1 X152.061 Y138.241 E-.11467
G1 X152.307 Y138.067 E-.11463
G1 X152.575 Y137.928 E-.11466
G1 X152.698 Y137.885 E-.04943
; WIPE_END
G1 E-.04 F1800
G1 X147.952 Y131.907 Z8 F36000
G1 X139.217 Y120.906 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X139.086 Y121.138 E.00884
G3 X116.586 Y120.558 I-11.086 J-6.643 E.90607
G1 X115.701 Y118.781 E.06585
G1 X115.358 Y118.941 E.01254
G3 X128.173 Y101.105 I12.649 J-4.434 E.8538
G3 X140.348 Y109.305 I-.177 J13.401 E.51527
G1 X140.671 Y110.102 E.02854
G1 X142.198 Y110.102 E.05065
G1 X142.198 Y111.962 E.06171
G1 X135.398 Y111.962 E.22557
G1 X135.398 Y112.277 E.01045
G1 X133.552 Y112.277 E.06123
G1 X133.552 Y110.639 E.05433
G2 X126.518 Y107.912 I-5.579 J3.955 E.26508
G2 X133.11 Y118.914 I1.485 J6.586 E.84601
G1 X133.552 Y118.361 E.02349
G1 X133.552 Y116.723 E.05433
G1 X135.398 Y116.723 E.06123
G1 X135.398 Y117.038 E.01045
G1 X142.198 Y117.038 E.22557
G1 X142.198 Y118.898 E.06171
G1 X140.67 Y118.898 E.05067
G1 X140.651 Y118.945 E.00169
G1 X140.299 Y118.781 E.01289
G1 X139.414 Y120.558 E.06585
G1 X139.247 Y120.854 E.01128
; WIPE_START
G1 X139.086 Y121.138 E-.12409
G1 X138.73 Y121.701 E-.2531
G1 X138.36 Y122.221 E-.24256
G1 X138.132 Y122.512 E-.14026
; WIPE_END
G1 E-.04 F1800
G1 X131.176 Y125.653 Z8 F36000
G1 X103.692 Y138.068 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X102.243 Y137.766 I-1.149 J1.886 E.37988
G1 X102.544 Y137.745 E.00927
G3 X103.641 Y138.037 I0 J2.208 E.03526
; WIPE_START
M204 S10000
G1 X103.939 Y138.241 E-.13735
G1 X104.16 Y138.447 E-.11467
G1 X104.35 Y138.681 E-.11461
G1 X104.507 Y138.939 E-.11468
G1 X104.627 Y139.216 E-.11462
G1 X104.708 Y139.506 E-.11465
G1 X104.726 Y139.635 E-.04942
; WIPE_END
G1 E-.04 F1800
G1 X111.454 Y136.031 Z8 F36000
G1 X140.413 Y120.52 Z8
G1 Z7.6
G1 E.8 F1800
G1 F12000
M204 S6000
G1 X164.878 Y131.928 E.82944
G3 X91.122 Y131.928 I-36.878 J-17.437 E2.83057
G1 X115.586 Y120.52 E.82942
G3 X128.18 Y100.713 I12.42 J-6.01 E.8624
G3 X140.935 Y109.71 I-.198 J13.821 E.50967
G1 X142.59 Y109.71 E.05085
G1 X142.59 Y112.354 E.08125
G1 X135.79 Y112.354 E.20895
G1 X135.79 Y112.66 E.00939
G1 X135.79 Y112.669 E.00029
G1 X133.16 Y112.669 E.08081
G1 X133.16 Y112.66 E.00029
G1 X133.16 Y110.777 E.05786
G2 X133.16 Y118.223 I-5.156 J3.723 E.98338
G1 X133.16 Y116.34 E.05786
G1 X133.16 Y116.331 E.00029
G1 X135.79 Y116.331 E.08081
G1 X135.79 Y116.34 E.00029
G1 X135.79 Y116.646 E.00939
G1 X142.59 Y116.646 E.20895
M73 P82 R4
G1 X142.59 Y119.29 E.08125
G1 X140.935 Y119.29 E.05085
G3 X140.438 Y120.466 I-20.17 J-7.827 E.03922
; WIPE_START
M204 S10000
G1 X142.249 Y121.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.077 Y118.446 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.139 Y118.322 E.00461
G1 X140.627 Y118.55 E.01787
G1 X141.578 Y118.55 E.03153
G1 X140.414 Y117.386 E.05459
G1 X138.614 Y117.386 E.05971
G1 X128.968 Y127.032 E.45251
G3 X127.032 Y127.032 I-.968 J-18.879 E.06425
G1 X114.961 Y114.961 E.56627
G2 X115.336 Y117.636 I13.364 J-.509 E.08975
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.399 J5.198 E.05392
G1 X116.335 Y108.659 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.2189
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X118.234 Y122.414 E.18334
G2 X122.514 Y125.81 I10.136 J-8.38 E.18257
G1 X126.825 Y121.499 E.20225
G2 X129.178 Y121.502 I1.188 J-8.68 E.07828
G1 X133.485 Y125.809 E.20207
G2 X137.766 Y122.414 I-5.823 J-11.737 E.18258
G1 X133.871 Y118.519 E.18271
G1 X133.9 Y117.071 E.04805
G1 X134.07 Y117.071 E.00564
; WIPE_START
G1 X133.9 Y117.071 E-.06459
G1 X133.871 Y118.519 E-.5504
G1 X134.141 Y118.789 E-.14502
; WIPE_END
G1 E-.04 F1800
G1 X133.271 Y111.206 Z8 F36000
G1 X133.081 Y109.544 Z8
G1 Z7.6
G1 E.8 F1800
G1 F15476.087
G3 X133.9 Y110.517 I-5.89 J5.792 E.04225
G1 X133.9 Y110.872 E.01178
G1 X134.957 Y111.929 E.04956
G1 X135.05 Y111.929 E.00308
G1 X135.05 Y111.614 E.01045
G1 X136.71 Y111.614 E.05508
G1 X139.664 Y108.66 E.1386
G1 X140.689 Y111.614 F36000
G1 F15476.087
G1 X141.85 Y111.614 E.03849
G1 X141.85 Y111.146 E.01553
G1 X141.154 Y110.45 E.03263
G1 X140.439 Y110.45 E.02374
G1 X139.93 Y109.226 E.04397
G1 X133.271 Y102.567 E.31238
G2 X131.131 Y101.841 I-5.761 J13.459 E.07505
G1 X124.816 Y108.156 E.29624
G2 X123.992 Y108.64 I2.717 J5.566 E.03174
G1 X119.747 Y104.396 E.19913
G2 X118.555 Y105.502 I8.568 J10.431 E.05401
G1 X137.44 Y105.507 F36000
G1 F15476.087
G2 X136.251 Y104.397 I-9.956 J9.478 E.05399
G1 X132.006 Y108.642 E.19916
G2 X131.182 Y108.154 I-4.705 J6.996 E.03179
G1 X124.865 Y101.837 E.29632
G2 X122.735 Y102.561 I4.962 J18.105 E.07466
G1 X116.067 Y109.229 E.31283
G2 X115.502 Y110.755 I12.375 J5.445 E.05401
; WIPE_START
G1 X116.067 Y109.229 E-.61829
G1 X116.331 Y108.966 E-.14171
; WIPE_END
G1 E-.04 F1800
G1 X122.588 Y113.336 Z8 F36000
G1 X159.994 Y139.467 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X152.967 Y146.494 E.30534
; WIPE_START
M204 S10000
G1 X154.381 Y145.079 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X150.979 Y147.949 Z8 F36000
G1 Z7.6
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X161.449 Y137.479 E.45498
; WIPE_START
M204 S10000
G1 X160.034 Y138.893 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X162.46 Y135.934 Z8 F36000
G1 Z7.6
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X149.434 Y148.96 E.56602
; WIPE_START
M204 S10000
G1 X150.848 Y147.545 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X148.116 Y149.745 Z8 F36000
G1 Z7.6
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X163.245 Y134.616 E.65743
; WIPE_START
M204 S10000
G1 X161.831 Y136.03 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X163.895 Y133.433 Z8 F36000
G1 Z7.6
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X146.933 Y150.395 E.73707
G1 X145.847 Y150.947
G1 X154.915 Y141.879 E.39405
G1 X153.942 Y142.319
G1 X144.838 Y151.423 E.39561
G1 X143.882 Y151.846
G1 X153.36 Y142.368 E.41186
G1 X152.892 Y142.303
G1 X142.979 Y152.216 E.43076
G1 X142.113 Y152.548
G1 X152.489 Y142.172 E.45088
G1 X152.144 Y141.983
G1 X141.28 Y152.848 E.4721
G1 X140.479 Y153.116
G1 X151.843 Y141.751 E.49385
G1 X151.584 Y141.478
G1 X139.704 Y153.357 E.51621
G1 X138.953 Y153.575
G1 X151.366 Y141.162 E.5394
G1 X151.193 Y140.802
G1 X138.222 Y153.773 E.56363
G1 X137.511 Y153.951
G1 X151.079 Y140.382 E.58961
G1 X151.043 Y139.885
G1 X136.817 Y154.112 E.61822
G1 X136.138 Y154.257
G1 X151.149 Y139.246 E.65229
; WIPE_START
M204 S10000
G1 X149.735 Y140.66 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.379 Y141.415 Z8 F36000
G1 Z7.6
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X164.447 Y132.347 E.39406
G1 X164.35 Y131.911
G1 X155.825 Y140.436 E.37044
G1 X155.869 Y139.859
G1 X163.986 Y131.741 E.35276
G1 X163.623 Y131.572
G1 X155.803 Y139.391 E.33979
G1 X155.668 Y138.993
G1 X163.259 Y131.402 E.32986
G1 X162.895 Y131.233
G1 X155.483 Y138.645 E.32212
G1 X155.253 Y138.342
G1 X162.532 Y131.063 E.3163
G1 X162.168 Y130.893
G1 X154.982 Y138.08 E.31228
G1 X154.664 Y137.864
G1 X161.804 Y130.724 E.31029
G1 X161.441 Y130.554
G1 X154.3 Y137.695 E.31031
G1 X153.882 Y137.58
G1 X161.077 Y130.385 E.31268
G1 X160.713 Y130.215
G1 X153.386 Y137.542 E.31841
G1 X152.748 Y137.647
G1 X160.35 Y130.045 E.33031
G1 X159.986 Y129.876
G1 X135.475 Y154.387 E1.06512
G1 X134.825 Y154.503
G1 X159.622 Y129.706 E1.07755
G1 X159.259 Y129.537
G1 X134.188 Y154.607 E1.08942
G1 X133.563 Y154.699
G1 X158.895 Y129.367 E1.10079
G1 X158.531 Y129.197
G1 X132.949 Y154.78 E1.11167
G1 X132.347 Y154.848
G1 X158.168 Y129.028 E1.12202
G1 X157.804 Y128.858
G1 X131.755 Y154.907 E1.13195
G1 X131.172 Y154.957
G1 X157.44 Y128.689 E1.14148
G1 X157.077 Y128.519
G1 X130.598 Y154.998 E1.15063
G1 X130.031 Y155.031
M73 P82 R3
G1 X156.713 Y128.35 E1.15944
G1 X156.349 Y128.18
G1 X129.474 Y155.055 E1.16787
G1 X128.925 Y155.071
G1 X155.986 Y128.01 E1.1759
G1 X155.622 Y127.841
G1 X128.383 Y155.079 E1.18364
G1 X127.848 Y155.081
G1 X155.258 Y127.671 E1.1911
G1 X154.895 Y127.502
G1 X127.32 Y155.077 E1.19827
G1 X126.799 Y155.064
G1 X129.393 Y152.47 E.1127
G1 X128.461 Y152.868
G1 X126.285 Y155.045 E.09458
G1 X125.776 Y155.021
G1 X127.886 Y152.911 E.0917
G1 X127.42 Y152.844
G1 X125.273 Y154.99 E.09327
G1 X124.777 Y154.953
G1 X127.02 Y152.71 E.09748
G1 X126.677 Y152.519
G1 X124.286 Y154.911 E.10393
G1 X123.799 Y154.864
G1 X126.377 Y152.286 E.11204
G1 X126.119 Y152.011
G1 X123.32 Y154.81 E.12164
M73 P83 R3
G1 X122.844 Y154.752
G1 X125.902 Y151.694 E.13289
G1 X125.731 Y151.332
G1 X122.373 Y154.69 E.14592
G1 X121.909 Y154.621
G1 X125.621 Y150.909 E.1613
G1 X125.587 Y150.41
G1 X121.448 Y154.549 E.17987
G1 X120.991 Y154.472
G1 X125.701 Y149.763 E.20465
; WIPE_START
M204 S10000
G1 X124.287 Y151.177 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.987 Y151.876 Z8 F36000
G1 Z7.6
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X154.531 Y127.332 E1.06654
G1 X154.167 Y127.162
G1 X130.373 Y150.957 E1.03399
G1 X130.413 Y150.384
G1 X153.804 Y126.993 E1.01644
G1 X153.44 Y126.823
G1 X130.343 Y149.92 E1.00366
G1 X130.206 Y149.524
G1 X153.076 Y126.654 E.9938
G1 X152.712 Y126.484
G1 X130.019 Y149.177 E.98612
G1 X129.788 Y148.875
G1 X152.349 Y126.315 E.98036
G1 X151.985 Y126.145
G1 X129.514 Y148.616 E.97646
G1 X129.195 Y148.402
G1 X151.621 Y125.975 E.97454
G1 X151.258 Y125.806
G1 X128.829 Y148.234 E.97462
G1 X128.41 Y148.121
G1 X150.894 Y125.636 E.97706
G1 X150.53 Y125.467
G1 X127.909 Y148.088 E.983
G1 X127.262 Y148.202
G1 X150.167 Y125.297 E.99531
G1 X149.803 Y125.127
G1 X120.541 Y154.39 E1.27158
G1 X120.093 Y154.304
G1 X149.439 Y124.958 E1.27522
G1 X149.076 Y124.788
G1 X119.65 Y154.214 E1.27867
G1 X119.213 Y154.118
G1 X148.712 Y124.619 E1.2819
G1 X148.348 Y124.449
G1 X118.777 Y154.02 E1.285
G1 X118.347 Y153.917
G1 X147.985 Y124.28 E1.28788
G1 X147.621 Y124.11
G1 X117.921 Y153.81 E1.2906
G1 X117.498 Y153.7
G1 X147.257 Y123.94 E1.2932
G1 X146.894 Y123.771
G1 X117.08 Y153.584 E1.29554
G1 X116.665 Y153.466
G1 X146.53 Y123.601 E1.29778
G1 X146.166 Y123.432
G1 X116.253 Y153.344 E1.29986
G1 X115.846 Y153.218
G1 X145.803 Y123.262 E1.30175
G1 X145.439 Y123.092
G1 X115.441 Y153.09 E1.30355
G1 X115.042 Y152.957
G1 X145.075 Y122.923 E1.30511
G1 X144.712 Y122.753
G1 X114.644 Y152.821 E1.30658
G1 X114.25 Y152.681
G1 X144.348 Y122.584 E1.30789
G1 X143.984 Y122.414
G1 X113.86 Y152.538 E1.30903
G1 X113.472 Y152.393
G1 X143.621 Y122.245 E1.3101
G1 X143.257 Y122.075
G1 X113.089 Y152.243 E1.31093
G1 X112.708 Y152.091
G1 X142.893 Y121.905 E1.31169
G1 X142.53 Y121.736
G1 X112.331 Y151.934 E1.31227
G1 X111.957 Y151.775
G1 X142.166 Y121.566 E1.31274
G1 X141.802 Y121.397
G1 X111.585 Y151.614 E1.31308
G1 X111.217 Y151.448
G1 X141.439 Y121.227 E1.31326
G1 X141.075 Y121.057
G1 X110.851 Y151.281 E1.31337
G1 X110.49 Y151.109
G1 X140.711 Y120.888 E1.31326
G1 X140.348 Y120.718
G1 X138.187 Y122.878 E.09387
M204 S10000
G1 X139.401 Y121.132 F36000
G1 F12000
M204 S2000
G1 X140.324 Y120.209 E.04011
M204 S10000
G1 X136.391 Y124.675 F36000
G1 F12000
M204 S2000
G1 X110.13 Y150.936 E1.14117
G1 X109.774 Y150.758
G1 X134.631 Y125.902 E1.08015
G1 X133.527 Y126.473
G1 X109.421 Y150.579 E1.04752
G1 X109.07 Y150.396
G1 X132.605 Y126.862 E1.02269
G1 X131.805 Y127.128
G1 X108.723 Y150.21 E1.00303
G1 X108.377 Y150.023
M73 P84 R3
G1 X131.078 Y127.321 E.98647
G1 X130.398 Y127.468
G1 X108.036 Y149.831 E.97174
G1 X107.695 Y149.638
G1 X129.763 Y127.57 E.95895
G1 X129.162 Y127.638
G1 X107.36 Y149.44 E.94742
G1 X107.025 Y149.241
G1 X128.589 Y127.677 E.93705
G1 X128.042 Y127.692
G1 X106.695 Y149.039 E.92763
G1 X106.366 Y148.834
G1 X127.52 Y127.68 E.91924
G1 X127.015 Y127.651
G1 X106.04 Y148.627 E.91147
G1 X105.717 Y148.416
G1 X126.526 Y127.608 E.90424
G1 X126.054 Y127.546
G1 X105.396 Y148.204 E.89767
G1 X105.079 Y147.988
G1 X125.599 Y127.468 E.8917
G1 X125.155 Y127.379
G1 X104.763 Y147.771 E.88612
G1 X104.451 Y147.549
G1 X124.723 Y127.277 E.88093
G1 X124.307 Y127.161
G1 X104.14 Y147.327 E.87635
G1 X103.833 Y147.101
G1 X123.898 Y127.036 E.87191
G1 X123.505 Y126.896
G1 X103.528 Y146.873 E.8681
G1 X103.226 Y146.642
G1 X123.116 Y126.751 E.86433
G1 X122.737 Y126.597
G1 X102.926 Y146.409 E.86092
G1 X102.629 Y146.172
G1 X122.373 Y126.428 E.858
G1 X122.014 Y126.254
G1 X102.334 Y145.934 E.8552
G1 X102.041 Y145.693
G1 X121.666 Y126.068 E.85278
G1 X121.326 Y125.876
G1 X101.752 Y145.449 E.85058
G1 X101.464 Y145.204
G1 X120.993 Y125.675 E.84861
G1 X120.671 Y125.464
G1 X101.18 Y144.955 E.84697
G1 X100.897 Y144.705
G1 X103.383 Y142.218 E.10805
G1 X102.705 Y142.363
G1 X100.618 Y144.45 E.0907
G1 X100.339 Y144.196
G1 X102.189 Y142.346 E.08036
G1 X101.763 Y142.239
G1 X100.065 Y143.936 E.07376
G1 X99.792 Y143.676
G1 X101.392 Y142.076 E.06952
G1 X101.068 Y141.867
G1 X99.523 Y143.412 E.06713
G1 X99.255 Y143.147
G1 X100.786 Y141.616 E.06654
G1 X100.549 Y141.319
G1 X98.991 Y142.878 E.06773
G1 X98.728 Y142.607
G1 X100.358 Y140.978 E.07081
G1 X100.215 Y140.587
G1 X98.468 Y142.334 E.07592
G1 X98.211 Y142.058
G1 X100.133 Y140.135 E.08355
G1 X100.161 Y139.574
G1 X97.956 Y141.78 E.09584
G1 X97.703 Y141.499
G1 X100.456 Y138.747 E.11961
; WIPE_START
M204 S10000
G1 X99.041 Y140.161 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.813 Y140.788 Z8 F36000
G1 Z7.6
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X120.352 Y125.249 E.67524
G1 X120.047 Y125.021
G1 X104.957 Y140.111 E.65576
G1 X104.931 Y139.604
G1 X119.746 Y124.789 E.64377
G1 X119.455 Y124.546
G1 X104.83 Y139.172 E.63554
G1 X104.666 Y138.802
G1 X119.17 Y124.298 E.63027
G1 X118.894 Y124.041
G1 X104.454 Y138.481 E.62746
G1 X104.2 Y138.201
G1 X118.625 Y123.777 E.62683
G1 X118.362 Y123.506
G1 X103.905 Y137.963 E.62823
G1 X103.567 Y137.768
G1 X118.11 Y123.225 E.63198
G1 X117.861 Y122.941
G1 X103.179 Y137.623 E.63803
G1 X102.719 Y137.549
G1 X117.626 Y122.643 E.64776
G1 X117.393 Y122.342
G1 X102.165 Y137.57 E.66174
G1 X101.34 Y137.863
G1 X117.172 Y122.03 E.68799
G1 X116.957 Y121.712
G1 X97.453 Y141.216 E.84755
G1 X97.206 Y140.93
G1 X116.75 Y121.386 E.8493
G1 X116.553 Y121.05
G1 X96.96 Y140.642 E.8514
G1 X96.718 Y140.351
G1 X116.361 Y120.709 E.85355
G1 X116.182 Y120.354
G1 X96.477 Y140.059 E.85627
G1 X96.241 Y139.762
G1 X114.963 Y121.04 E.81357
G1 X113.964 Y121.506
G1 X96.005 Y139.465 E.7804
G1 X95.773 Y139.163
G1 X112.965 Y121.972 E.74705
G1 X111.965 Y122.438
G1 X95.543 Y138.86 E.71364
G1 X95.316 Y138.554
G1 X110.966 Y122.904 E.68008
G1 X109.967 Y123.369
G1 X95.091 Y138.246 E.64644
G1 X94.869 Y137.934
G1 X108.968 Y123.835 E.61267
G1 X107.969 Y124.301
G1 X94.649 Y137.621 E.5788
G1 X94.432 Y137.305
M73 P85 R3
G1 X106.969 Y124.767 E.54482
G1 X105.97 Y125.233
G1 X94.218 Y136.986 E.5107
G1 X94.005 Y136.665
G1 X104.971 Y125.699 E.47651
G1 X103.972 Y126.165
G1 X93.797 Y136.34 E.44215
G1 X93.59 Y136.014
G1 X102.973 Y126.631 E.40775
G1 X101.974 Y127.097
G1 X93.387 Y135.684 E.37314
G1 X93.185 Y135.352
G1 X100.974 Y127.563 E.33849
G1 X99.975 Y128.029
G1 X92.987 Y135.017 E.30366
G1 X92.791 Y134.679
G1 X98.976 Y128.495 E.26876
G1 X97.977 Y128.961
G1 X92.598 Y134.339 E.23371
G1 X92.408 Y133.996
G1 X96.978 Y129.427 E.19855
G1 X95.978 Y129.892
G1 X92.221 Y133.65 E.16329
G1 X92.037 Y133.301
G1 X94.979 Y130.358 E.12786
G1 X93.98 Y130.824
G1 X91.854 Y132.95 E.09238
G1 X91.676 Y132.595
G1 X92.981 Y131.29 E.05669
G1 X91.982 Y131.756
G1 X91.5 Y132.238 E.02094
; WIPE_START
M204 S10000
G1 X91.982 Y131.756 E-.259
G1 X92.981 Y131.29 E-.41895
G1 X92.828 Y131.443 E-.08205
; WIPE_END
G1 E-.04 F1800
G1 X99.689 Y128.099 Z8 F36000
G1 X115.712 Y120.291 Z8
G1 Z7.6
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X116.008 Y119.995 E.01287
G1 X115.846 Y119.623
G1 X115.55 Y119.919 E.01287
; WIPE_START
M204 S10000
G1 X115.846 Y119.623 E-.25611
G1 X116.008 Y119.995 E-.24776
G1 X115.712 Y120.291 E-.25614
; WIPE_END
G1 E-.04 F1800
G1 X118.862 Y127.243 Z8 F36000
G1 X130.048 Y151.937 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.221861
G1 F15000
G3 X129.453 Y152.53 I-4.071 J-3.487 E.01227
; WIPE_START
G1 X129.811 Y152.199 E-.44031
G1 X130.048 Y151.937 E-.31969
; WIPE_END
G1 E-.04 F1800
G1 X130.426 Y151.17 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.0926367
G1 F15000
G1 X130.359 Y150.943 E.00096
G1 X130.432 Y150.098 F36000
; LINE_WIDTH: 0.105032
G1 F15000
G2 X130.35 Y149.95 I-2.193 J1.123 E.00085
; WIPE_START
G1 X130.432 Y150.098 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X128.384 Y148.118 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.106032
G1 F15000
G2 X128.226 Y148.038 I-1.217 J2.192 E.00091
; WIPE_START
G1 X128.384 Y148.118 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X127.194 Y148.134 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.14997
G1 F15000
G1 X127.02 Y148.252 E.00184
; LINE_WIDTH: 0.133473
G1 X126.931 Y148.317 E.00081
; LINE_WIDTH: 0.103274
G1 X126.842 Y148.382 E.00054
; WIPE_START
G1 X126.931 Y148.317 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X125.872 Y149.353 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.0902401
G1 F15000
G1 X125.847 Y149.386 E.00016
; LINE_WIDTH: 0.111299
G1 X125.776 Y149.49 E.0007
; LINE_WIDTH: 0.147967
G1 X125.706 Y149.593 E.00107
; LINE_WIDTH: 0.184635
G1 X125.635 Y149.697 E.00145
G1 X125.521 Y150.21 F36000
; LINE_WIDTH: 0.121967
G1 F15000
G1 X125.6 Y150.423 E.00146
; WIPE_START
G1 X125.521 Y150.21 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X118.727 Y146.732 Z8 F36000
G1 X101.277 Y137.799 Z8
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.200686
G1 F15000
G2 X100.984 Y138.046 I3.443 J4.377 E.00492
; LINE_WIDTH: 0.176719
G1 X100.743 Y138.279 E.00366
G2 X100.516 Y138.531 I3.619 J3.487 E.00369
; LINE_WIDTH: 0.21333
G1 X100.395 Y138.686 E.00273
; WIPE_START
G1 X100.516 Y138.531 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X100.207 Y140.557 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.135954
G1 F15000
G1 X100.149 Y140.454 E.0009
G1 X100.179 Y140.356 E.00077
; WIPE_START
G1 X100.149 Y140.454 E-.35077
G1 X100.207 Y140.557 E-.40923
; WIPE_END
G1 E-.04 F1800
G1 X103.847 Y141.992 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.0910082
G1 F15000
G1 X103.803 Y142.029 E.00022
; LINE_WIDTH: 0.111222
G1 X103.714 Y142.094 E.00061
; LINE_WIDTH: 0.145036
G1 X103.624 Y142.159 E.00092
; LINE_WIDTH: 0.19012
G1 X103.446 Y142.281 E.00259
; WIPE_START
G1 X103.624 Y142.159 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.875 Y140.85 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.194146
G1 F15000
G1 X104.797 Y140.965 E.0017
; LINE_WIDTH: 0.157677
G1 X104.716 Y141.085 E.00136
; LINE_WIDTH: 0.126062
G1 X104.643 Y141.177 E.00079
; LINE_WIDTH: 0.100803
G1 X104.571 Y141.269 E.00055
; WIPE_START
G1 X104.643 Y141.177 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X112.01 Y143.171 Z8 F36000
G1 X143.82 Y151.783 Z8
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.189948
G1 F15000
G1 X143.703 Y151.861 E.00169
; LINE_WIDTH: 0.149228
G1 X143.586 Y151.94 E.00122
; LINE_WIDTH: 0.108507
G1 X143.469 Y152.018 E.00075
; WIPE_START
G1 X143.586 Y151.94 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.785 Y150.885 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.194414
G1 F15000
G1 X145.652 Y150.98 E.00201
; LINE_WIDTH: 0.151891
G1 X145.519 Y151.074 E.00145
; LINE_WIDTH: 0.109367
G1 X145.386 Y151.168 E.00088
; WIPE_START
G1 X145.519 Y151.074 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X148.055 Y149.684 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.204735
G1 F15000
G1 X147.925 Y149.782 E.00215
; LINE_WIDTH: 0.168985
G1 X147.796 Y149.881 E.00167
; LINE_WIDTH: 0.133234
G1 X147.666 Y149.979 E.0012
; LINE_WIDTH: 0.101761
G1 X147.572 Y150.05 E.00056
; WIPE_START
G1 X147.666 Y149.979 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X149.373 Y148.899 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.205933
G1 F15000
G1 X149.214 Y149.024 E.00269
; LINE_WIDTH: 0.165505
G1 X149.055 Y149.15 E.00202
; LINE_WIDTH: 0.125077
G1 X148.896 Y149.275 E.00136
; LINE_WIDTH: 0.0965193
G1 X148.826 Y149.33 E.00039
; WIPE_START
G1 X148.896 Y149.275 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X150.918 Y147.888 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.20986
G1 F15000
G1 X150.664 Y148.099 E.00449
; LINE_WIDTH: 0.171607
G1 X150.529 Y148.21 E.00183
; LINE_WIDTH: 0.138234
G1 X150.394 Y148.32 E.00135
; LINE_WIDTH: 0.104861
G1 X150.26 Y148.43 E.00088
; WIPE_START
G1 X150.394 Y148.32 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.907 Y146.433 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.217846
G1 F15000
G1 X152.653 Y146.656 E.00481
; LINE_WIDTH: 0.180005
G1 X152.399 Y146.879 E.00377
; LINE_WIDTH: 0.142859
G1 X152.204 Y147.047 E.0021
; LINE_WIDTH: 0.106394
G1 X152.009 Y147.215 E.00133
; WIPE_START
G1 X152.204 Y147.047 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X151.374 Y139.459 Z8 F36000
G1 X151.307 Y138.847 Z8
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.106747
G1 F15000
G1 X151.247 Y138.936 E.00056
; LINE_WIDTH: 0.143904
G1 X151.187 Y139.024 E.00088
; LINE_WIDTH: 0.181675
G1 X151.127 Y139.113 E.00121
G1 X151.158 Y139.255 E.00165
; WIPE_START
G1 X151.127 Y139.113 E-.43827
G1 X151.187 Y139.024 E-.32173
; WIPE_END
G1 E-.04 F1800
G1 X152.68 Y137.578 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.125469
G1 F15000
G2 X152.339 Y137.817 I3.231 J4.973 E.0028
; WIPE_START
G1 X152.68 Y137.578 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.891 Y139.57 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.0987533
G1 F15000
G2 X155.81 Y139.421 I-2.117 J1.07 E.00077
; WIPE_START
G1 X155.891 Y139.57 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.439 Y141.475 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.230722
G1 F15000
G3 X155.048 Y141.876 I-3.192 J-2.722 E.00857
G1 X155.025 Y141.876 E.00036
; LINE_WIDTH: 0.19382
G1 X154.906 Y141.87 E.00147
; WIPE_START
G1 X155.025 Y141.876 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X158.55 Y141.209 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.105608
G1 F15000
G1 X158.143 Y141.641 E.00303
; LINE_WIDTH: 0.150837
G3 X157.16 Y142.659 I-58.765 J-55.765 E.01244
; LINE_WIDTH: 0.171429
G3 X155.653 Y144.153 I-65.034 J-64.096 E.02223
; LINE_WIDTH: 0.138489
G1 X155.141 Y144.643 E.00552
; LINE_WIDTH: 0.105595
G1 X154.709 Y145.05 E.00303
; WIPE_START
G1 X155.141 Y144.643 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.274 Y138.994 Z8 F36000
G1 X160.715 Y138.509 Z8
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.106427
G1 F15000
G1 X160.546 Y138.704 E.00133
; LINE_WIDTH: 0.14295
G1 X160.378 Y138.899 E.0021
; LINE_WIDTH: 0.180085
G1 X160.156 Y139.153 E.00377
; LINE_WIDTH: 0.217872
G1 X159.933 Y139.407 E.00481
; WIPE_START
G1 X160.156 Y139.153 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.93 Y136.76 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.104858
G1 F15000
G1 X161.82 Y136.894 E.00088
; LINE_WIDTH: 0.138224
G1 X161.71 Y137.029 E.00135
; LINE_WIDTH: 0.17159
G1 X161.599 Y137.164 E.00183
; LINE_WIDTH: 0.209864
G1 X161.388 Y137.418 E.0045
; WIPE_START
G1 X161.599 Y137.164 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X162.83 Y135.326 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.0963954
G1 F15000
G1 X162.776 Y135.395 E.00038
; LINE_WIDTH: 0.124868
G1 X162.65 Y135.555 E.00136
; LINE_WIDTH: 0.165378
G1 X162.525 Y135.714 E.00203
; LINE_WIDTH: 0.205889
G1 X162.399 Y135.873 E.0027
; WIPE_START
G1 X162.525 Y135.714 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X163.55 Y134.072 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.101812
G1 F15000
G1 X163.479 Y134.166 E.00056
; LINE_WIDTH: 0.133307
G1 X163.381 Y134.296 E.0012
; LINE_WIDTH: 0.169022
G1 X163.282 Y134.425 E.00167
; LINE_WIDTH: 0.204737
G1 X163.184 Y134.555 E.00214
; WIPE_START
G1 X163.282 Y134.425 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X164.154 Y132.934 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109986
G1 F15000
G1 X164.047 Y133.08 E.00099
; LINE_WIDTH: 0.153621
G1 X163.94 Y133.226 E.00163
; LINE_WIDTH: 0.197255
G1 X163.833 Y133.371 E.00227
; WIPE_START
G1 X163.94 Y133.226 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X157.09 Y129.859 Z8 F36000
G1 X139.462 Y121.193 Z8
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.214662
G1 F15000
G1 X139.37 Y121.314 E.00212
; LINE_WIDTH: 0.186533
G1 X139.253 Y121.459 E.00219
; LINE_WIDTH: 0.147187
G1 X139.137 Y121.605 E.00159
; LINE_WIDTH: 0.107841
G1 X139.02 Y121.751 E.00099
G1 X138.176 Y122.867 F36000
; LINE_WIDTH: 0.214345
G1 F15000
G1 X138.182 Y123.012 E.00203
G1 X137.733 Y123.491 E.00918
; LINE_WIDTH: 0.196707
G1 X136.76 Y124.452 E.01713
; LINE_WIDTH: 0.226805
G1 X136.451 Y124.735 E.00628
G1 X135.256 Y125.514 F36000
; LINE_WIDTH: 0.105469
G1 F15000
G1 X135.096 Y125.647 E.00106
; LINE_WIDTH: 0.139952
G1 X134.961 Y125.752 E.00135
; LINE_WIDTH: 0.174089
G1 X134.827 Y125.857 E.00183
; LINE_WIDTH: 0.208225
G1 X134.692 Y125.962 E.0023
G1 X132.832 Y126.9 F36000
; LINE_WIDTH: 0.130082
G1 F15000
G1 X132.591 Y126.848 E.00175
; WIPE_START
G1 X132.832 Y126.9 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X125.203 Y127.101 Z8 F36000
G1 X124.07 Y127.131 Z8
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.0989497
G1 F15000
G1 X123.935 Y127.048 E.00072
; WIPE_START
G1 X124.07 Y127.131 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X117.899 Y122.639 Z8 F36000
G1 X115.413 Y120.83 Z8
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109246
G1 F15000
G1 X115.284 Y120.92 E.00085
; LINE_WIDTH: 0.151414
G1 X115.154 Y121.011 E.0014
; LINE_WIDTH: 0.193582
G1 X115.025 Y121.102 E.00194
; WIPE_START
G1 X115.154 Y121.011 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X113.415 Y121.762 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109246
G1 F15000
G1 X113.285 Y121.852 E.00085
; LINE_WIDTH: 0.151414
G1 X113.156 Y121.943 E.0014
; LINE_WIDTH: 0.193582
G1 X113.026 Y122.034 E.00194
; WIPE_START
G1 X113.156 Y121.943 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X111.416 Y122.693 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109246
G1 F15000
G1 X111.287 Y122.784 E.00085
; LINE_WIDTH: 0.151414
G1 X111.157 Y122.875 E.0014
; LINE_WIDTH: 0.193582
G1 X111.028 Y122.965 E.00194
; WIPE_START
G1 X111.157 Y122.875 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X109.418 Y123.625 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109244
G1 F15000
G1 X109.289 Y123.716 E.00085
; LINE_WIDTH: 0.151408
G1 X109.159 Y123.807 E.0014
; LINE_WIDTH: 0.193572
G1 X109.03 Y123.897 E.00194
; WIPE_START
G1 X109.159 Y123.807 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X107.42 Y124.557 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109246
G1 F15000
G1 X107.29 Y124.648 E.00085
; LINE_WIDTH: 0.151415
G1 X107.161 Y124.738 E.0014
; LINE_WIDTH: 0.193584
G1 X107.031 Y124.829 E.00194
; WIPE_START
G1 X107.161 Y124.738 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.421 Y125.489 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109244
G1 F15000
G1 X105.292 Y125.58 E.00085
; LINE_WIDTH: 0.151409
G1 X105.162 Y125.67 E.0014
; LINE_WIDTH: 0.193573
G1 X105.033 Y125.761 E.00194
; WIPE_START
G1 X105.162 Y125.67 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X103.423 Y126.421 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109244
G1 F15000
G1 X103.293 Y126.512 E.00085
; LINE_WIDTH: 0.151409
G1 X103.164 Y126.602 E.0014
; LINE_WIDTH: 0.193575
G1 X103.035 Y126.693 E.00194
; WIPE_START
G1 X103.164 Y126.602 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X101.424 Y127.353 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109244
G1 F15000
G1 X101.295 Y127.443 E.00085
; LINE_WIDTH: 0.151409
G1 X101.166 Y127.534 E.0014
; LINE_WIDTH: 0.193573
G1 X101.036 Y127.625 E.00194
; WIPE_START
G1 X101.166 Y127.534 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X99.426 Y128.285 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109244
G1 F15000
G1 X99.297 Y128.375 E.00085
; LINE_WIDTH: 0.151409
G1 X99.167 Y128.466 E.0014
; LINE_WIDTH: 0.193573
G1 X99.038 Y128.556 E.00194
; WIPE_START
G1 X99.167 Y128.466 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X97.428 Y129.216 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109244
G1 F15000
G1 X97.298 Y129.307 E.00085
; LINE_WIDTH: 0.151409
G1 X97.169 Y129.398 E.0014
; LINE_WIDTH: 0.193573
G1 X97.039 Y129.488 E.00194
; WIPE_START
G1 X97.169 Y129.398 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X95.429 Y130.148 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109244
G1 F15000
G1 X95.3 Y130.239 E.00085
; LINE_WIDTH: 0.151409
G1 X95.17 Y130.33 E.0014
; LINE_WIDTH: 0.193573
G1 X95.041 Y130.42 E.00194
; WIPE_START
G1 X95.17 Y130.33 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X93.431 Y131.08 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; LINE_WIDTH: 0.109244
G1 F15000
G1 X93.302 Y131.171 E.00085
; LINE_WIDTH: 0.151409
G1 X93.172 Y131.261 E.0014
; LINE_WIDTH: 0.193573
G1 X93.043 Y131.352 E.00194
; CHANGE_LAYER
; Z_HEIGHT: 7.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X93.172 Y131.261 E-.76
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
G1 X140.731 Y118.898
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F8205
G1 X140.67 Y118.898 E.00202
G3 X134.022 Y126.468 I-12.842 J-4.575 E.34232
G3 X128.166 Y101.105 I-6.019 J-11.968 E1.60852
G3 X140.351 Y109.311 I-.17 J13.401 E.51575
G1 X140.671 Y110.102 E.0283
G1 X142.198 Y110.102 E.05065
G1 X142.198 Y112.027 E.06386
G1 X135.398 Y112.027 E.22557
G1 X135.398 Y112.354 E.01083
G1 X133.552 Y112.354 E.06123
G1 X133.552 Y110.639 E.05687
G2 X127.03 Y107.818 I-5.585 J3.96 E.24785
G1 X126.899 Y107.842 E.00442
G2 X133.11 Y118.914 I1.102 J6.66 E.85898
G1 X133.552 Y118.361 E.02349
G1 X133.552 Y116.646 E.05687
G1 X135.398 Y116.646 E.06123
G1 X135.398 Y116.973 E.01083
G1 X142.198 Y116.973 E.22557
G1 X142.198 Y118.898 E.06386
G1 X140.791 Y118.898 E.04666
G1 X140.935 Y119.29 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F8205
M204 S6000
G3 X128.172 Y100.713 I-12.931 J-4.789 E1.85158
G3 X140.935 Y109.71 I-.19 J13.821 E.50989
G1 X142.59 Y109.71 E.05085
G1 X142.59 Y112.395 E.08251
G1 X142.59 Y112.419 E.00074
G1 X135.831 Y112.419 E.20769
G1 X135.79 Y112.419 E.00126
G1 X135.79 Y112.71 E.00894
G1 X135.79 Y112.746 E.00109
G1 X133.16 Y112.746 E.08081
G1 X133.16 Y112.71 E.00109
G1 X133.16 Y110.777 E.05941
G2 X133.16 Y118.223 I-5.153 J3.723 E.983
G1 X133.16 Y116.29 E.05941
G1 X133.16 Y116.254 E.00109
G1 X135.79 Y116.254 E.08081
G1 X135.79 Y116.29 E.00109
G1 X135.79 Y116.581 E.00894
G1 X135.831 Y116.581 E.00126
G1 X142.59 Y116.581 E.20769
G1 X142.59 Y116.605 E.00074
G1 X142.59 Y119.29 E.08251
G1 X140.995 Y119.29 E.04901
; WIPE_START
G1 F12000
M204 S10000
G1 X140.498 Y120.328 E-.43744
G1 X140.181 Y120.965 E-.27027
G1 X140.113 Y121.085 E-.0523
; WIPE_END
G1 E-.04 F1800
G1 X133.994 Y116.995 Z8.2 F36000
G1 Z7.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F8205
G1 X133.9 Y116.995 E.0031
G1 X133.871 Y118.519 E.05059
G1 X137.709 Y122.357 E.18006
G3 X133.426 Y125.75 I-10.034 J-8.27 E.18262
G1 X129.178 Y121.502 E.19927
G3 X126.825 Y121.499 I-1.165 J-8.682 E.07828
G1 X122.574 Y125.75 E.19946
G3 X118.29 Y122.358 I5.782 J-11.701 E.18261
G1 X122.142 Y118.506 E.18069
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.66 E.2189
G1 X115.502 Y110.757 F36000
G1 F8205
G3 X116.066 Y109.231 I17.237 J5.498 E.054
G1 X122.735 Y102.561 E.31289
G3 X124.865 Y101.837 I7.087 J17.363 E.07467
G1 X131.182 Y108.154 E.29632
G3 X132.006 Y108.642 I-3.881 J7.484 E.03179
G1 X136.251 Y104.397 E.19916
G3 X137.44 Y105.507 I-8.648 J10.458 E.05399
G1 X139.664 Y108.66 F36000
G1 F8205
G1 X136.645 Y111.679 E.14165
M73 P86 R3
G1 X135.05 Y111.679 E.05292
G1 X135.033 Y112.005 E.01084
G1 X133.9 Y110.872 E.05315
G1 X133.9 Y110.517 E.01178
G2 X133.081 Y109.544 I-6.709 J4.818 E.04225
; WIPE_START
G1 F15476.087
G1 X133.9 Y110.517 E-.48352
G1 X133.9 Y110.872 E-.13492
G1 X134.164 Y111.136 E-.14156
; WIPE_END
G1 E-.04 F1800
G1 X126.571 Y110.362 Z8.2 F36000
G1 X122.552 Y109.953 Z8.2
G1 Z7.8
G1 E.8 F1800
G1 F8205
G2 X121.661 Y111.311 I8.511 J6.558 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I12.983 J-3.183 E.08975
G1 X126.946 Y126.946 E.56222
G2 X129.054 Y126.946 I1.054 J-17.471 E.06998
G1 X138.679 Y117.321 E.45152
G1 X140.349 Y117.321 E.0554
G1 X141.578 Y118.55 E.05764
G1 X140.748 Y118.55 E.02753
G1 X140.314 Y118.316 E.01634
G1 X140.035 Y118.414 E.00979
; WIPE_START
G1 F15476.087
G1 X140.314 Y118.316 E-.11221
G1 X140.748 Y118.55 E-.18715
G1 X141.578 Y118.55 E-.31539
G1 X141.307 Y118.279 E-.14526
; WIPE_END
G1 E-.04 F1800
G1 X133.676 Y118.42 Z8.2 F36000
G1 X115.717 Y118.75 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.452615
G1 F8205
G1 X115.854 Y119.065 E.01146
; LINE_WIDTH: 0.488085
G1 X115.991 Y119.379 E.01245
; LINE_WIDTH: 0.538852
G2 X119.958 Y124.645 I12.343 J-5.172 E.26919
G2 X139.732 Y119.974 I8.039 J-10.158 E.94382
; LINE_WIDTH: 0.51684
G1 X139.997 Y119.394 E.02462
; LINE_WIDTH: 0.47236
G1 X140.262 Y118.815 E.02231
; WIPE_START
G1 F12000
G1 X139.997 Y119.394 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.591 Y115.244 Z8.2 F36000
G1 X118.555 Y105.502 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F8205
G3 X119.747 Y104.396 I9.773 J9.338 E.05401
G1 X123.992 Y108.64 E.19913
G3 X124.816 Y108.156 I3.541 J5.082 E.03174
G1 X131.131 Y101.841 E.29625
G3 X133.271 Y102.567 I-3.673 J14.338 E.07502
G1 X139.93 Y109.226 E.31238
G1 X140.439 Y110.45 E.04398
G1 X141.154 Y110.45 E.02374
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y111.679 E.01768
G1 X140.754 Y111.679 E.03633
; CHANGE_LAYER
; Z_HEIGHT: 8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X141.85 Y111.679 E-.41619
G1 X141.85 Y111.146 E-.20257
G1 X141.587 Y110.883 E-.14124
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
G1 X140.731 Y118.898
G1 Z8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F7901
G1 X140.67 Y118.898 E.00202
G3 X133.996 Y126.481 I-12.843 J-4.575 E.34327
G3 X128.159 Y101.105 I-5.994 J-11.981 E1.60735
G3 X140.353 Y109.317 I-.163 J13.402 E.5162
G1 X140.671 Y110.102 E.02809
G1 X142.198 Y110.102 E.05066
G1 X142.198 Y112.117 E.06682
G1 X135.398 Y112.117 E.22557
G1 X135.398 Y112.461 E.01143
G1 X133.552 Y112.461 E.06123
G1 X133.552 Y110.639 E.06043
G2 X126.518 Y107.912 I-5.579 J3.955 E.26508
G2 X133.11 Y118.914 I1.483 J6.587 E.84621
G1 X133.552 Y118.361 E.0235
G1 X133.552 Y116.539 E.06043
G1 X135.398 Y116.539 E.06123
G1 X135.398 Y116.883 E.01143
G1 X142.198 Y116.883 E.22557
G1 X142.198 Y118.898 E.06682
G1 X140.791 Y118.898 E.04666
G1 X140.935 Y119.29 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F7901
M204 S6000
G3 X128.165 Y100.713 I-12.93 J-4.789 E1.85124
G3 X140.935 Y109.71 I-.183 J13.821 E.51012
G1 X142.59 Y109.71 E.05085
G1 X142.59 Y111.66 E.05993
G1 X142.59 Y112.06 E.01229
G1 X142.59 Y112.46 E.01229
G1 X142.59 Y112.509 E.00149
G1 X135.831 Y112.509 E.20769
G1 X135.79 Y112.509 E.00126
G1 X135.79 Y112.787 E.00855
G1 F7679.201
G1 X135.79 Y112.853 E.00204
G1 F7500
G1 X133.16 Y112.853 E.08081
G1 F7679.201
G1 X133.16 Y112.787 E.00204
G1 F7901
G1 X133.16 Y112.387 E.01229
G1 X133.16 Y111.987 E.01229
G1 X133.16 Y111.587 E.01229
G1 X133.16 Y111.187 E.01229
G1 X133.16 Y110.777 E.0126
G2 X133.16 Y118.223 I-5.156 J3.723 E.98343
G1 X133.16 Y117.813 E.0126
G1 X133.16 Y117.413 E.01229
G1 X133.16 Y117.013 E.01229
G1 X133.16 Y116.613 E.01229
G1 X133.16 Y116.213 E.01229
G1 F7679.228
G1 X133.16 Y116.147 E.00204
G1 F7500
G1 X135.79 Y116.147 E.08081
G1 F7679.228
G1 X135.79 Y116.213 E.00204
G1 F7901
G1 X135.79 Y116.491 E.00855
G1 X135.831 Y116.491 E.00126
G1 X136.231 Y116.491 E.01229
G1 X136.631 Y116.491 E.01229
G1 X142.59 Y116.491 E.1831
G1 X142.59 Y116.54 E.00149
G1 X142.59 Y116.94 E.01229
G1 X142.59 Y117.34 E.01229
G1 X142.59 Y119.29 E.05993
G1 X140.995 Y119.29 E.04901
; WIPE_START
G1 F12000
M204 S10000
G1 X140.497 Y120.329 E-.43775
G1 X140.18 Y120.966 E-.2703
G1 X140.113 Y121.085 E-.05195
; WIPE_END
G1 E-.04 F1800
G1 X140.035 Y118.414 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F7901
G1 X140.314 Y118.316 E.00979
G1 X140.748 Y118.55 E.01634
G1 X141.578 Y118.55 E.02753
G1 X140.26 Y117.232 E.06183
G1 X138.768 Y117.232 E.04947
G1 X129.054 Y126.946 E.45571
G3 X126.946 Y126.946 I-1.054 J-17.471 E.06998
G1 X114.961 Y114.961 E.56222
G2 X115.336 Y117.636 I13.359 J-.508 E.08975
G1 X121.661 Y111.311 E.29673
G3 X122.553 Y109.953 I12.899 J7.496 E.05391
G1 X116.335 Y108.66 F36000
G1 F7901
G1 X121.002 Y113.326 E.2189
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X118.29 Y122.358 E.18069
G2 X122.574 Y125.75 I10.066 J-8.308 E.18261
G1 X126.825 Y121.499 E.19946
G2 X129.178 Y121.502 I1.188 J-8.677 E.07828
G1 X133.426 Y125.75 E.19927
G2 X137.709 Y122.357 I-5.75 J-11.662 E.18262
G1 X133.871 Y118.519 E.18006
G1 X133.9 Y116.901 E.05368
; WIPE_START
G1 F15476.087
G1 X133.871 Y118.519 E-.61497
G1 X134.141 Y118.789 E-.14503
; WIPE_END
G1 E-.04 F1800
G1 X133.271 Y111.206 Z8.4 F36000
G1 X133.081 Y109.544 Z8.4
G1 Z8
G1 E.8 F1800
G1 F7901
G3 X133.9 Y110.517 I-5.887 J5.789 E.04225
G1 X133.9 Y110.872 E.01178
G1 X135.05 Y112.022 E.05392
G1 X135.05 Y111.768 E.00841
G1 X136.556 Y111.768 E.04996
G1 X139.664 Y108.66 E.14583
G1 X140.844 Y111.768 F36000
G1 F7901
G1 X141.85 Y111.768 E.03337
G1 X141.85 Y111.146 E.02065
G1 X141.154 Y110.45 E.03263
G1 X140.438 Y110.45 E.02374
G1 X139.929 Y109.226 E.044
G1 X133.27 Y102.567 E.31239
G2 X131.131 Y101.841 I-5.863 J13.762 E.075
G1 X124.816 Y108.156 E.29626
G2 X123.992 Y108.64 I2.717 J5.566 E.03174
G1 X119.747 Y104.396 E.19913
G2 X118.555 Y105.502 I8.569 J10.434 E.05401
G1 X115.717 Y118.75 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.45261
G1 F7901
G1 X115.854 Y119.065 E.01146
; LINE_WIDTH: 0.48807
G1 X115.991 Y119.38 E.01245
; LINE_WIDTH: 0.538778
G2 X119.958 Y124.645 I12.342 J-5.171 E.26915
G2 X139.731 Y119.975 I8.039 J-10.159 E.94363
; LINE_WIDTH: 0.516845
G1 X139.996 Y119.395 E.02463
; LINE_WIDTH: 0.472295
G1 X140.262 Y118.815 E.02232
; WIPE_START
G1 F12000
G1 X139.996 Y119.395 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X138.615 Y111.888 Z8.4 F36000
G1 X137.44 Y105.507 Z8.4
G1 Z8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F7901
G2 X136.251 Y104.397 I-9.715 J9.214 E.05399
G1 X132.006 Y108.642 E.19916
G2 X131.182 Y108.154 I-4.703 J6.991 E.03179
G1 X124.865 Y101.837 E.29632
G2 X122.735 Y102.561 I4.966 J18.117 E.07466
G1 X116.066 Y109.231 E.31289
G2 X115.502 Y110.757 I16.378 J6.917 E.054
; CHANGE_LAYER
; Z_HEIGHT: 8.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X116.066 Y109.231 E-.61838
G1 X116.329 Y108.967 E-.14162
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
G1 X136.203 Y116.767
G1 Z8.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F7783
G1 X142.198 Y116.767 E.19885
G1 X142.198 Y118.898 E.07069
G1 X140.67 Y118.898 E.05068
G3 X133.996 Y126.481 I-12.842 J-4.574 E.34327
G3 X128.151 Y101.105 I-5.995 J-11.981 E1.60722
G3 X140.356 Y109.324 I-.156 J13.403 E.51667
G1 X140.671 Y110.102 E.02786
G1 X142.198 Y110.102 E.05066
G1 X142.198 Y112.233 E.07069
G1 X135.398 Y112.233 E.22557
G1 X135.398 Y112.608 E.01243
G1 X133.552 Y112.608 E.06123
G1 X133.552 Y110.639 E.06529
G2 X126.518 Y107.912 I-5.579 J3.955 E.26508
G2 X129.265 Y121.129 I1.484 J6.585 E.69596
G2 X133.552 Y118.361 I-1.318 J-6.745 E.17344
G1 X133.552 Y116.392 E.06529
G1 X135.398 Y116.392 E.06123
G1 X135.398 Y116.767 E.01243
G1 X136.143 Y116.767 E.02473
G1 X135.831 Y116.375 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F6600
M204 S6000
G1 X142.59 Y116.375 E.20769
G1 F6791.412
G1 X142.59 Y116.45 E.00232
G1 F7783
G1 X142.59 Y116.85 E.01229
G1 X142.59 Y117.25 E.01229
G1 X142.59 Y117.65 E.01229
G1 X142.59 Y118.05 E.01229
G1 X142.59 Y118.45 E.01229
G1 X142.59 Y119.29 E.0258
G1 X140.935 Y119.29 E.05086
G3 X128.158 Y100.713 I-12.931 J-4.789 E1.85109
G3 X140.935 Y109.71 I-.175 J13.821 E.51034
G1 X142.59 Y109.71 E.05085
G1 X142.59 Y110.55 E.0258
G1 X142.59 Y110.95 E.01229
G1 X142.59 Y111.35 E.01229
G1 X142.59 Y111.75 E.01229
G1 X142.59 Y112.15 E.01229
G1 X142.59 Y112.55 E.01229
G1 F6791.387
G1 X142.59 Y112.625 E.00232
G1 F6600
G1 X135.831 Y112.625 E.20769
G1 F6996.027
G1 X135.79 Y112.625 E.00126
G1 X135.79 Y112.894 E.00827
G1 F7133.622
G1 X135.79 Y113 E.00325
G1 F2880
G1 X133.16 Y113 E.08081
G1 F3058.385
G1 X133.16 Y112.894 E.00325
G1 F3782.181
G1 X133.16 Y112.494 E.01229
G1 F4582.777
G1 X133.16 Y112.094 E.01229
G1 F5460.173
G1 X133.16 Y111.694 E.01229
G1 F6414.369
G1 X133.16 Y111.294 E.01229
G1 F7762.541
G1 X133.16 Y110.777 E.0159
G1 F7783
G1 X132.813 Y110.342 E.01708
G1 X132.479 Y109.984 E.01507
G1 X132.119 Y109.651 E.01507
G2 X132.119 Y119.349 I-4.114 J4.849 E.8889
G1 X132.479 Y119.016 E.01507
G1 X132.813 Y118.658 E.01507
G1 X133.16 Y118.223 E.01708
G1 F7762.596
G1 X133.16 Y117.706 E.0159
G1 F6414.394
G1 X133.16 Y117.306 E.01229
G1 F5460.196
G1 X133.16 Y116.906 E.01229
G1 F4582.798
G1 X133.16 Y116.506 E.01229
G1 F3782.2
G1 X133.16 Y116.106 E.01229
G1 F3058.402
G1 X133.16 Y116 E.00325
G1 F2880
G1 X135.79 Y116 E.08081
G1 F3058.402
G1 X135.79 Y116.106 E.00325
G1 F3501.904
G1 X135.79 Y116.356 E.00768
; WIPE_START
M204 S10000
G1 X137.79 Y116.361 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.9 Y116.901 Z8.6 F36000
G1 Z8.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F7783
G1 X133.871 Y118.519 E.05368
G1 X138.104 Y122.752 E.19859
G3 X133.841 Y126.165 I-10.493 J-8.738 E.18238
G1 X129.178 Y121.502 E.21877
G3 X126.825 Y121.499 I-1.164 J-8.682 E.07828
G1 X122.156 Y126.168 E.21903
G3 X117.895 Y122.753 I5.931 J-11.767 E.18246
G1 X122.142 Y118.506 E.19923
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.66 E.2189
G1 X115.502 Y110.757 F36000
G1 F7783
G3 X116.066 Y109.231 I16.712 J5.306 E.054
G1 X122.735 Y102.561 E.31289
G3 X124.865 Y101.837 I7.124 J17.478 E.07465
G1 X131.182 Y108.154 E.29632
G3 X132.006 Y108.642 I-3.88 J7.482 E.03179
G1 X136.251 Y104.397 E.19916
G3 X137.44 Y105.507 I-8.414 J10.202 E.05399
G1 X139.664 Y108.66 F36000
G1 F7783
G1 X136.439 Y111.885 E.1513
G1 X135.05 Y111.885 E.04609
G1 X135.05 Y112.022 E.00455
G1 X133.9 Y110.872 E.05392
G1 X133.9 Y110.517 E.01178
G2 X133.081 Y109.544 I-6.707 J4.816 E.04225
; WIPE_START
G1 F15476.087
G1 X133.9 Y110.517 E-.48353
G1 X133.9 Y110.872 E-.13491
G1 X134.164 Y111.136 E-.14156
; WIPE_END
G1 E-.04 F1800
G1 X126.571 Y110.363 Z8.6 F36000
G1 X122.552 Y109.953 Z8.6
G1 Z8.2
G1 E.8 F1800
G1 F7783
G2 X121.661 Y111.311 I8.507 J6.555 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I12.982 J-3.183 E.08975
G1 X127.537 Y127.537 E.58998
G2 X128.463 Y127.537 I.463 J-8.961 E.0307
G1 X138.885 Y117.115 E.48893
G1 X140.143 Y117.115 E.04174
G1 X141.578 Y118.55 E.06729
G1 X140.438 Y118.55 E.0378
G1 X140.25 Y119.001 E.01622
; WIPE_START
G1 F15476.087
G1 X140.438 Y118.55 E-.18579
G1 X141.578 Y118.55 E-.43297
G1 X141.315 Y118.287 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X134.66 Y114.549 Z8.6 F36000
G1 X118.555 Y105.502 Z8.6
G1 Z8.2
G1 E.8 F1800
G1 F7783
G3 X119.747 Y104.396 I9.757 J9.323 E.05401
G1 X123.992 Y108.64 E.19913
G3 X124.816 Y108.156 I3.54 J5.08 E.03174
G1 X131.132 Y101.841 E.29627
G3 X133.27 Y102.566 I-3.742 J14.541 E.07498
G1 X139.929 Y109.225 E.3124
G1 X140.438 Y110.45 E.04401
G1 X141.154 Y110.45 E.02374
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y111.885 E.02451
G1 X140.96 Y111.885 E.0295
; CHANGE_LAYER
; Z_HEIGHT: 8.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X141.85 Y111.885 E-.33798
G1 X141.85 Y111.146 E-.28079
G1 X141.587 Y110.883 E-.14124
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
G1 X135.398 Y116.616
G1 Z8.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F9683
G1 X142.198 Y116.616 E.22557
G1 X142.198 Y118.898 E.07569
G1 X140.67 Y118.898 E.05068
G3 X133.996 Y126.481 I-12.84 J-4.572 E.34328
G3 X128.144 Y101.105 I-5.993 J-11.981 E1.60685
G3 X140.359 Y109.33 I-.149 J13.403 E.51714
G1 X140.671 Y110.102 E.02763
G1 X142.198 Y110.102 E.05066
G1 X142.198 Y112.384 E.07569
G1 X135.398 Y112.384 E.22557
G1 X135.398 Y112.794 E.0136
G1 X133.552 Y112.794 E.06123
G1 X133.552 Y110.639 E.07146
G2 X126.518 Y107.912 I-5.579 J3.955 E.26508
G2 X133.11 Y118.914 I1.484 J6.587 E.84617
G1 X133.552 Y118.361 E.0235
G1 X133.552 Y116.206 E.07146
G1 X135.398 Y116.206 E.06123
M73 P87 R3
G1 X135.398 Y116.556 E.0116
G1 X135.79 Y116.224 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F2948.56
M204 S6000
G1 X135.831 Y116.224 E.00126
G1 F2880
G1 X142.59 Y116.224 E.20769
G1 F3065.654
G1 X142.59 Y116.334 E.00338
G1 F3790.264
G1 X142.59 Y116.734 E.01229
G1 F4591.675
G1 X142.59 Y117.134 E.01229
G1 F5469.885
G1 X142.59 Y117.534 E.01229
G1 F6424.895
G1 X142.59 Y117.934 E.01229
G1 F7456.705
G1 X142.59 Y118.334 E.01229
G1 F8565.316
G1 X142.59 Y118.734 E.01229
G1 F9683
G1 X142.59 Y119.29 E.01709
G1 X142.19 Y119.29 E.01229
G1 X141.79 Y119.29 E.01229
G1 X140.935 Y119.29 E.02628
G3 X139.102 Y122.676 I-13.112 J-4.909 E.1187
G3 X128.15 Y100.712 I-11.102 J-8.177 E1.73214
G3 X140.935 Y109.71 I-.168 J13.821 E.51057
G1 X141.79 Y109.71 E.02627
G1 X142.19 Y109.71 E.01229
G1 X142.59 Y109.71 E.01229
G1 X142.59 Y110.266 E.01709
G1 F8565.287
G1 X142.59 Y110.666 E.01229
G1 F7456.679
G1 X142.59 Y111.066 E.01229
G1 F6424.87
G1 X142.59 Y111.466 E.01229
G1 F5469.862
G1 X142.59 Y111.866 E.01229
G1 F4591.654
G1 X142.59 Y112.266 E.01229
G1 F3790.245
G1 X142.59 Y112.666 E.01229
G1 F3065.637
G1 X142.59 Y112.776 E.00338
G1 F2880
G1 X135.831 Y112.776 E.20769
G1 F3139.892
G1 X135.79 Y112.776 E.00126
G1 X135.79 Y113.041 E.00814
G1 F3267.008
G1 X135.79 Y113.186 E.00445
G1 F2400
G1 X133.16 Y113.186 E.08081
G1 F2625.109
G1 X133.16 Y113.041 E.00445
G1 F3298.502
G1 X133.16 Y112.641 E.01229
G1 F4048.696
G1 X133.16 Y112.241 E.01229
G1 F4875.689
G1 X133.16 Y111.841 E.01229
G1 F5779.483
G1 X133.16 Y111.441 E.01229
G1 F6760.076
G1 X133.16 Y111.041 E.01229
G1 F7449.553
M73 P87 R2
G1 X133.16 Y110.777 E.00811
G1 F9010.075
G1 X132.813 Y110.342 E.01708
G1 F9683
G1 X132.479 Y109.984 E.01507
G1 X132.119 Y109.651 E.01507
G2 X132.119 Y119.349 I-4.115 J4.849 E.8889
G1 X132.479 Y119.016 E.01507
G1 X132.813 Y118.658 E.01507
G1 F9010.079
G1 X133.16 Y118.223 E.01708
G1 F7449.553
G1 X133.16 Y117.959 E.00811
G1 F6760.102
G1 X133.16 Y117.559 E.01229
G1 F5779.506
G1 X133.16 Y117.159 E.01229
G1 F4875.711
G1 X133.16 Y116.759 E.01229
G1 F4048.715
G1 X133.16 Y116.359 E.01229
G1 F3298.52
G1 X133.16 Y115.959 E.01229
G1 F2625.125
G1 X133.16 Y115.814 E.00446
G1 F2400
G1 X135.79 Y115.814 E.08081
G1 F2625.125
G1 X135.79 Y115.959 E.00446
G1 F2960.393
G1 X135.79 Y116.164 E.00629
; WIPE_START
M204 S10000
G1 X135.831 Y116.224 E-.02761
G1 X137.758 Y116.224 E-.73239
; WIPE_END
G1 E-.04 F1800
G1 X135.355 Y112.036 Z8.8 F36000
G1 Z8.4
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X141.79 Y112.036 E.17829
; Slow Down End
; WIPE_START
G1 X139.79 Y112.036 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.018 Y112.414 Z8.8 F36000
G1 Z8.4
G1 E.8 F1800
; LINE_WIDTH: 0.39616
G1 F9683
G1 X133.992 Y112.414 E.02952
; WIPE_START
G1 F12000
G1 X135.018 Y112.414 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.081 Y109.544 Z8.8 F36000
G1 Z8.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F9683
G3 X133.9 Y110.517 I-5.889 J5.791 E.04225
G1 X133.9 Y110.872 E.01178
G1 X134.97 Y111.943 E.0502
G1 X135.211 Y111.689 E.0116
G1 X136.635 Y111.689 E.04722
G1 X139.664 Y108.66 E.14211
G1 X140.765 Y111.689 F36000
G1 F9683
G1 X141.85 Y111.689 E.036
G1 X141.85 Y111.146 E.01802
G1 X141.154 Y110.45 E.03263
G1 X140.438 Y110.45 E.02375
G1 X139.929 Y109.225 E.04402
G1 X133.269 Y102.566 E.3124
G2 X131.132 Y101.84 I-5.938 J13.987 E.07495
G1 X124.816 Y108.156 E.29628
G2 X123.992 Y108.64 I2.717 J5.566 E.03174
G1 X119.748 Y104.396 E.19912
G2 X118.555 Y105.502 I8.568 J10.434 E.05401
G1 X116.335 Y108.66 F36000
G1 F9683
G1 X121.002 Y113.326 E.2189
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X117.895 Y122.753 E.19923
G2 X122.156 Y126.168 I10.192 J-8.352 E.18246
G1 X126.825 Y121.499 E.21903
G2 X129.178 Y121.502 I1.188 J-8.68 E.07828
G1 X133.84 Y126.165 E.21873
G2 X138.104 Y122.752 I-6.192 J-12.107 E.18239
G1 X133.871 Y118.519 E.19858
G1 X133.9 Y116.966 E.05152
G1 X133.966 Y116.966 E.00217
G1 X140.25 Y119.001 F36000
G1 F9683
G1 X140.438 Y118.55 E.01621
G1 X141.578 Y118.55 E.0378
G1 X140.339 Y117.311 E.05811
G1 X138.689 Y117.311 E.05473
G1 X128.463 Y127.537 E.47974
G3 X127.537 Y127.537 I-.463 J-8.961 E.0307
G1 X114.961 Y114.961 E.58998
G2 X115.336 Y117.636 I13.353 J-.507 E.08975
G1 X121.661 Y111.311 E.29673
G3 X122.553 Y109.953 I13.965 J8.195 E.0539
; WIPE_START
G1 F15476.087
G1 X122.052 Y110.621 E-.31723
G1 X121.661 Y111.311 E-.30128
G1 X121.398 Y111.574 E-.14149
; WIPE_END
G1 E-.04 F1800
G1 X128.537 Y108.874 Z8.8 F36000
G1 X137.443 Y105.505 Z8.8
G1 Z8.4
G1 E.8 F1800
G1 F9683
G2 X136.251 Y104.397 I-7.787 J7.179 E.05403
G1 X132.006 Y108.642 E.19918
G2 X131.182 Y108.154 I-4.706 J6.997 E.03179
G1 X124.865 Y101.837 E.29633
G2 X122.736 Y102.561 I5.017 J18.269 E.07465
G1 X116.066 Y109.23 E.3129
G2 X115.502 Y110.757 I15.91 J6.746 E.054
; WIPE_START
G1 F15476.087
G1 X116.066 Y109.23 E-.61837
G1 X116.329 Y108.967 E-.14163
; WIPE_END
G1 E-.04 F1800
G1 X123.613 Y111.249 Z8.8 F36000
G1 X141.85 Y116.964 Z8.8
G1 Z8.4
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X135.415 Y116.964 E.17829
; Slow Down End
G1 X135.018 Y116.586 F36000
; LINE_WIDTH: 0.39614
G1 F9683
G1 X133.992 Y116.586 E.02952
; CHANGE_LAYER
; Z_HEIGHT: 8.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F12000
G1 X135.018 Y116.586 E-.76
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
G1 X135.398 Y116.431
G1 Z8.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F8698
G1 X142.198 Y116.431 E.22557
G1 X142.198 Y118.898 E.08185
G1 X140.67 Y118.898 E.05069
G3 X133.996 Y126.481 I-12.839 J-4.571 E.34329
G3 X128.137 Y101.104 I-5.994 J-11.981 E1.60672
G3 X140.361 Y109.336 I-.142 J13.404 E.51759
G1 X140.67 Y110.102 E.02742
G1 X142.198 Y110.102 E.05067
G1 X142.198 Y112.57 E.08185
G1 X135.398 Y112.57 E.22557
G1 X135.398 Y112.994 E.01407
G1 X133.552 Y112.994 E.06123
G1 X133.552 Y110.639 E.0781
G2 X126.518 Y107.912 I-5.576 J3.948 E.26511
G2 X133.11 Y118.914 I1.485 J6.586 E.84602
G1 X133.552 Y118.361 E.0235
G1 X133.552 Y116.006 E.0781
G1 X135.398 Y116.006 E.06123
G1 X135.398 Y116.371 E.01208
G1 X135.79 Y116.038 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F2462.622
M204 S6000
G1 X135.831 Y116.038 E.00126
G1 F2400
G1 X142.59 Y116.038 E.20769
G1 F2624.474
G1 X142.59 Y116.183 E.00444
G1 F3297.79
G1 X142.59 Y116.583 E.01229
G1 F4047.907
G1 X142.59 Y116.983 E.01229
G1 F4874.824
G1 X142.59 Y117.383 E.01229
G1 F5778.541
G1 X142.59 Y117.783 E.01229
G1 F6759.057
G1 X142.59 Y118.183 E.01229
G1 F7816.374
G1 X142.59 Y118.583 E.01229
G1 F8698
G1 X142.59 Y118.983 E.01229
G1 X142.59 Y119.29 E.00943
G1 X142.19 Y119.29 E.01229
G1 X141.79 Y119.29 E.01229
G1 X140.935 Y119.29 E.02628
G3 X128.143 Y100.712 I-12.93 J-4.79 E1.85055
G3 X140.935 Y109.71 I-.161 J13.82 E.51079
G1 X141.79 Y109.71 E.02627
G1 X142.19 Y109.71 E.01229
G1 X142.59 Y109.71 E.01229
G1 X142.59 Y110.017 E.00943
G1 X142.59 Y110.417 E.01229
G1 F7816.346
G1 X142.59 Y110.817 E.01229
G1 F6759.032
G1 X142.59 Y111.217 E.01229
G1 F5778.517
G1 X142.59 Y111.617 E.01229
G1 F4874.802
G1 X142.59 Y112.017 E.01229
G1 F4047.887
G1 X142.59 Y112.417 E.01229
G1 F3297.773
G1 X142.59 Y112.817 E.01229
G1 F2624.458
G1 X142.59 Y112.962 E.00444
G1 F2400
G1 X135.831 Y112.962 E.20769
G1 F2638.063
G1 X135.79 Y112.962 E.00126
G1 X135.79 Y113.227 E.00815
G1 F2766.096
G1 X135.79 Y113.386 E.00489
G1 F2160
G1 X133.16 Y113.386 E.08081
G1 F2395.027
G1 X133.16 Y113.227 E.00489
G1 F3039.955
G1 X133.16 Y112.827 E.01229
G1 F3761.683
G1 X133.16 Y112.427 E.01229
G1 F4560.211
G1 X133.16 Y112.027 E.01229
G1 F5435.539
G1 X133.16 Y111.627 E.01229
G1 F6387.667
G1 X133.16 Y111.227 E.01229
G1 F7550.773
G1 X133.16 Y110.777 E.01383
G1 F8698
G1 X132.813 Y110.342 E.01708
G1 X132.479 Y109.984 E.01507
G1 X132.119 Y109.651 E.01507
G2 X132.119 Y119.349 I-4.115 J4.849 E.8889
G1 X132.479 Y119.016 E.01508
G1 X132.813 Y118.658 E.01506
G1 X133.16 Y118.223 E.01708
G1 F7550.773
G1 X133.16 Y117.773 E.01383
G1 F6387.692
G1 X133.16 Y117.373 E.01229
G1 F5435.562
G1 X133.16 Y116.973 E.01229
G1 F4560.232
G1 X133.16 Y116.573 E.01229
G1 F3761.702
G1 X133.16 Y116.173 E.01229
G1 F3039.973
G1 X133.16 Y115.773 E.01229
G1 F2395.043
G1 X133.16 Y115.614 E.00489
G1 F2160
G1 X135.79 Y115.614 E.08081
G1 F2395.043
G1 X135.79 Y115.773 E.00489
G1 F2716.395
G1 X135.79 Y115.978 E.00631
M204 S10000
G1 X135.37 Y116.813 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39997
G1 F8698
G1 X141.756 Y116.813 E.18581
G1 X133.959 Y116.413 F36000
; LINE_WIDTH: 0.44948
G1 F8698
G1 X134.931 Y116.413 E.03221
G1 X133.9 Y116.901 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F8698
G1 X133.871 Y118.519 E.05368
G1 X138.104 Y122.752 E.19858
G3 X133.84 Y126.164 I-10.421 J-8.655 E.1824
G1 X129.178 Y121.502 E.21869
G3 X126.825 Y121.499 I-1.165 J-8.682 E.07828
G1 X122.156 Y126.168 E.21903
G3 X117.895 Y122.753 I5.931 J-11.767 E.18246
G1 X122.142 Y118.506 E.19923
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.66 E.2189
G1 X115.502 Y110.757 F36000
G1 F8698
G3 X116.066 Y109.23 I16.289 J5.151 E.054
G1 X122.736 Y102.56 E.3129
G3 X124.865 Y101.837 I7.135 J17.516 E.07464
G1 X131.182 Y108.154 E.29632
G3 X132.006 Y108.642 I-3.882 J7.486 E.03179
G1 X136.253 Y104.395 E.19926
G3 X137.443 Y105.504 I-8.56 J10.373 E.05401
G1 X139.664 Y108.66 F36000
G1 F8698
G1 X136.519 Y111.806 E.14758
G1 X135.211 Y111.806 E.04336
G1 X135.022 Y111.995 E.00887
G1 X133.9 Y110.872 E.05264
G1 X133.9 Y110.517 E.01178
G2 X133.081 Y109.544 I-6.709 J4.818 E.04225
G1 X135.37 Y112.187 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39996
G1 F8698
G1 X141.756 Y112.187 E.1858
G1 X133.959 Y112.587 F36000
; LINE_WIDTH: 0.44948
G1 F8698
G1 X134.931 Y112.587 E.03221
; WIPE_START
G1 F12000
G1 X133.959 Y112.587 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X126.522 Y110.871 Z9 F36000
G1 X122.557 Y109.956 Z9
G1 Z8.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F8698
G2 X121.661 Y111.311 I6.914 J5.543 E.05394
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I12.978 J-3.182 E.08975
G1 X127.537 Y127.537 E.58998
G2 X128.463 Y127.537 I.463 J-8.961 E.0307
G1 X138.805 Y117.195 E.48521
G1 X140.222 Y117.195 E.047
G1 X141.578 Y118.55 E.06357
G1 X140.438 Y118.55 E.0378
G1 X140.25 Y119.001 E.01621
; WIPE_START
G1 F15476.087
G1 X140.438 Y118.55 E-.18571
G1 X141.578 Y118.55 E-.43306
G1 X141.315 Y118.287 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X134.66 Y114.549 Z9 F36000
G1 X118.555 Y105.502 Z9
G1 Z8.6
G1 E.8 F1800
G1 F8698
G3 X119.748 Y104.396 I9.754 J9.321 E.05401
G1 X123.992 Y108.64 E.19912
G3 X124.816 Y108.156 I3.541 J5.082 E.03174
G1 X131.132 Y101.84 E.29629
G3 X133.269 Y102.565 I-3.853 J14.868 E.07493
G1 X139.929 Y109.225 E.31241
G1 X140.438 Y110.45 E.04403
G1 X141.154 Y110.45 E.02375
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y111.806 E.02188
G1 X140.881 Y111.806 E.03213
; CHANGE_LAYER
; Z_HEIGHT: 8.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X141.85 Y111.806 E-.3681
G1 X141.85 Y111.146 E-.25066
G1 X141.587 Y110.883 E-.14124
; WIPE_END
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
G1 X135.398 Y116.231
G1 Z8.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F8860
G1 X142.198 Y116.231 E.22557
G1 X142.198 Y118.898 E.08848
G1 X140.67 Y118.898 E.05069
G3 X132.73 Y127.035 I-12.772 J-4.52 E.38916
G3 X128.129 Y101.104 I-4.727 J-12.535 E1.56053
G3 X140.364 Y109.342 I-.135 J13.405 E.51805
G1 X140.67 Y110.102 E.0272
G1 X142.198 Y110.102 E.05067
G1 X142.198 Y112.77 E.08848
G1 X135.398 Y112.77 E.22557
G1 X135.398 Y113.194 E.01407
G1 X133.552 Y113.194 E.06123
G1 X133.552 Y110.639 E.08473
G2 X126.518 Y107.912 I-5.578 J3.951 E.2651
G2 X133.11 Y118.914 I1.485 J6.586 E.84601
G1 X133.552 Y118.361 E.02349
G1 X133.552 Y115.806 E.08473
G1 X135.398 Y115.806 E.06123
G1 X135.398 Y116.171 E.01208
G1 X135.79 Y115.838 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F2219.429
M204 S6000
G1 X135.831 Y115.838 E.00126
G1 F2160
G1 X142.59 Y115.838 E.20769
G1 F2395.043
G1 X142.59 Y115.997 E.00489
G1 F3039.973
G1 X142.59 Y116.397 E.01229
G1 F3761.702
G1 X142.59 Y116.797 E.01229
G1 F4560.232
G1 X142.59 Y117.197 E.01229
G1 F5435.562
G1 X142.59 Y117.597 E.01229
G1 F6387.692
G1 X142.59 Y117.997 E.01229
G1 F7416.622
G1 X142.59 Y118.397 E.01229
G1 F8522.352
G1 X142.59 Y118.797 E.01229
G1 F8860
G1 X142.59 Y119.29 E.01514
G1 X142.19 Y119.29 E.01229
G1 X141.79 Y119.29 E.01229
G1 X140.935 Y119.29 E.02628
G3 X128.136 Y100.712 I-12.93 J-4.79 E1.85031
G3 X140.935 Y109.71 I-.153 J13.82 E.51102
G1 X141.79 Y109.71 E.02627
G1 X142.19 Y109.71 E.01229
G1 X142.59 Y109.71 E.01229
G1 X142.59 Y110.203 E.01514
G1 F8522.323
G1 X142.59 Y110.603 E.01229
G1 F7416.595
G1 X142.59 Y111.003 E.01229
G1 F6387.667
G1 X142.59 Y111.403 E.01229
G1 F5435.539
G1 X142.59 Y111.803 E.01229
G1 F4560.211
G1 X142.59 Y112.203 E.01229
G1 F3761.683
G1 X142.59 Y112.603 E.01229
G1 F3039.955
G1 X142.59 Y113.003 E.01229
G1 F2395.027
G1 X142.59 Y113.162 E.00489
G1 F2160
G1 X135.831 Y113.162 E.20769
G1 F2386.135
G1 X135.79 Y113.162 E.00126
G1 X135.79 Y113.427 E.00815
G1 F2507.975
G1 X135.79 Y113.586 E.00489
G1 F2160
G1 X133.16 Y113.586 E.08081
G1 F2395.027
G1 X133.16 Y113.427 E.00489
G1 F3039.955
G1 X133.16 Y113.027 E.01229
G1 F3761.683
G1 X133.16 Y112.627 E.01229
G1 F4560.211
G1 X133.16 Y112.227 E.01229
G1 F5435.539
G1 X133.16 Y111.827 E.01229
G1 F6387.667
G1 X133.16 Y111.427 E.01229
G1 F7416.595
G1 X133.16 Y111.027 E.01229
G1 F8098.843
G1 X133.16 Y110.777 E.00768
G1 F8860
G1 X132.813 Y110.342 E.01708
G1 X132.479 Y109.984 E.01507
G1 X132.119 Y109.651 E.01507
G2 X132.119 Y119.349 I-4.115 J4.849 E.8889
G1 X132.479 Y119.016 E.01507
G1 X132.813 Y118.658 E.01507
G1 X133.16 Y118.223 E.01708
G1 F8098.871
G1 X133.16 Y117.973 E.00768
G1 F7416.622
G1 X133.16 Y117.573 E.01229
G1 F6387.692
G1 X133.16 Y117.173 E.01229
G1 F5435.562
G1 X133.16 Y116.773 E.01229
G1 F4560.232
G1 X133.16 Y116.373 E.01229
G1 F3761.702
G1 X133.16 Y115.973 E.01229
G1 F3039.973
G1 X133.16 Y115.573 E.01229
G1 F2395.043
G1 X133.16 Y115.414 E.00489
G1 F2160
G1 X135.79 Y115.414 E.08081
G1 F2395.043
G1 X135.79 Y115.573 E.00489
G1 F2716.395
G1 X135.79 Y115.778 E.00631
M204 S10000
G1 X135.38 Y116.637 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.44908
G1 F8860
G1 X141.731 Y116.637 E.21022
G1 X133.966 Y116.22 F36000
; LINE_WIDTH: 0.4635
G1 F8860
G1 X134.924 Y116.22 E.03284
; WIPE_START
G1 F12000
G1 X133.966 Y116.22 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.38 Y112.363 Z9.2 F36000
G1 Z8.8
G1 E.8 F1800
; LINE_WIDTH: 0.44907
G1 F8860
G1 X141.731 Y112.363 E.21021
G1 X133.966 Y112.78 F36000
; LINE_WIDTH: 0.4635
G1 F8860
G1 X134.924 Y112.78 E.03284
G1 X133.081 Y109.544 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F8860
G3 X133.9 Y110.517 I-5.888 J5.79 E.04225
G1 X133.9 Y110.872 E.01178
G1 X135.098 Y112.07 E.05618
G1 X135.211 Y111.956 E.00533
G1 X136.368 Y111.956 E.03835
G1 X139.664 Y108.66 E.15466
G1 X141.032 Y111.956 F36000
G1 F8860
G1 X141.85 Y111.956 E.02713
G1 X141.85 Y111.146 E.02689
G1 X141.154 Y110.45 E.03263
G1 X140.438 Y110.45 E.02376
G1 X139.928 Y109.225 E.04404
G1 X133.269 Y102.565 E.31242
G2 X131.132 Y101.84 I-6.049 J14.318 E.0749
G1 X124.816 Y108.156 E.2963
G2 X123.992 Y108.64 I2.716 J5.565 E.03174
M73 P88 R2
G1 X119.748 Y104.396 E.19912
G2 X118.555 Y105.502 I8.56 J10.427 E.05401
G1 X116.335 Y108.66 F36000
G1 F8860
G1 X121.002 Y113.326 E.2189
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X117.895 Y122.753 E.19923
G2 X122.156 Y126.168 I10.192 J-8.352 E.18246
G1 X126.825 Y121.499 E.21903
G2 X129.178 Y121.502 I1.188 J-8.678 E.07828
G1 X133.839 Y126.163 E.21866
G2 X138.104 Y122.752 I-6.122 J-12.026 E.18242
G1 X133.871 Y118.519 E.19857
G1 X133.9 Y116.901 E.05368
G1 X140.25 Y119.001 F36000
G1 F8860
G1 X140.438 Y118.55 E.01621
G1 X141.578 Y118.55 E.03781
G1 X140.071 Y117.044 E.07065
G1 X138.956 Y117.044 E.03699
G1 X128.463 Y127.537 E.49229
G3 X127.537 Y127.537 I-.463 J-8.961 E.0307
G1 X114.961 Y114.961 E.58997
G2 X115.336 Y117.636 I13.352 J-.507 E.08975
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.398 J5.197 E.05392
; WIPE_START
G1 F15476.087
G1 X122.054 Y110.618 E-.31577
G1 X121.661 Y111.311 E-.30259
G1 X121.398 Y111.574 E-.14165
; WIPE_END
G1 E-.04 F1800
G1 X128.536 Y108.874 Z9.2 F36000
G1 X137.443 Y105.504 Z9.2
G1 Z8.8
G1 E.8 F1800
G1 F8860
G2 X136.253 Y104.395 I-9.743 J9.259 E.054
G1 X132.006 Y108.642 E.19926
G2 X131.182 Y108.154 I-4.704 J6.994 E.03179
G1 X124.865 Y101.837 E.29632
G2 X122.736 Y102.56 I5.018 J18.277 E.07463
G1 X116.066 Y109.23 E.31291
G2 X115.502 Y110.757 I15.487 J6.59 E.054
; CHANGE_LAYER
; Z_HEIGHT: 9
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X116.066 Y109.23 E-.61836
G1 X116.329 Y108.967 E-.14164
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
G1 X135.398 Y116.031
G1 Z9
G1 E.8 F1800
; FEATURE: Inner wall
G1 F8994
G1 X142.198 Y116.031 E.22557
G1 X142.198 Y118.898 E.09512
G1 X140.67 Y118.898 E.05069
G3 X130.743 Y127.614 I-12.748 J-4.508 E.45782
G3 X128.122 Y101.104 I-2.741 J-13.113 E1.49169
G3 X140.366 Y109.348 I-.128 J13.405 E.51851
G1 X140.67 Y110.102 E.02698
G1 X142.198 Y110.102 E.05068
G1 X142.198 Y112.97 E.09512
G1 X135.398 Y112.97 E.22557
G1 X135.398 Y113.394 E.01407
G1 X133.552 Y113.394 E.06123
G1 X133.552 Y110.639 E.09137
G2 X126.518 Y107.912 I-5.579 J3.954 E.26509
G2 X133.11 Y118.914 I1.485 J6.586 E.84601
G1 X133.552 Y118.361 E.02349
G1 X133.552 Y115.606 E.09137
G1 X135.398 Y115.606 E.06123
G1 X135.398 Y115.971 E.01208
G1 X135.79 Y115.638 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F2219.429
M204 S6000
G1 X135.831 Y115.638 E.00126
G1 F2160
G1 X142.59 Y115.638 E.20769
G1 F2395.043
G1 X142.59 Y115.797 E.00489
G1 F3039.973
G1 X142.59 Y116.197 E.01229
G1 F3761.702
G1 X142.59 Y116.597 E.01229
G1 F4560.232
G1 X142.59 Y116.997 E.01229
G1 F5435.562
G1 X142.59 Y117.397 E.01229
G1 F6387.692
G1 X142.59 Y117.797 E.01229
G1 F7416.622
G1 X142.59 Y118.197 E.01229
G1 F8522.352
G1 X142.59 Y118.597 E.01229
G1 F8994
G1 X142.59 Y118.997 E.01229
G1 X142.59 Y119.29 E.00899
G1 X142.19 Y119.29 E.01229
G1 X141.79 Y119.29 E.01229
G1 X140.935 Y119.29 E.02628
G3 X128.128 Y100.712 I-12.931 J-4.789 E1.85021
G3 X140.935 Y109.71 I-.146 J13.82 E.51124
G1 X141.79 Y109.71 E.02628
G1 X142.19 Y109.71 E.01229
G1 X142.59 Y109.71 E.01229
G1 X142.59 Y110.003 E.00899
G1 X142.59 Y110.403 E.01229
G1 F8522.323
G1 X142.59 Y110.803 E.01229
G1 F7416.595
G1 X142.59 Y111.203 E.01229
G1 F6387.667
G1 X142.59 Y111.603 E.01229
G1 F5435.539
G1 X142.59 Y112.003 E.01229
G1 F4560.211
G1 X142.59 Y112.403 E.01229
G1 F3761.683
G1 X142.59 Y112.803 E.01229
G1 F3039.955
G1 X142.59 Y113.203 E.01229
G1 F2395.027
G1 X142.59 Y113.362 E.00489
G1 F2160
G1 X135.831 Y113.362 E.20769
G1 F2386.135
G1 X135.79 Y113.362 E.00126
G1 X135.79 Y113.627 E.00815
G1 F2507.975
G1 X135.79 Y113.786 E.00489
G1 F2160
G1 X133.16 Y113.786 E.08081
G1 F2395.027
G1 X133.16 Y113.627 E.00489
G1 F3039.955
G1 X133.16 Y113.227 E.01229
G1 F3761.683
G1 X133.16 Y112.827 E.01229
G1 F4560.211
G1 X133.16 Y112.427 E.01229
G1 F5435.539
G1 X133.16 Y112.027 E.01229
G1 F6387.667
G1 X133.16 Y111.627 E.01229
G1 F7416.595
G1 X133.16 Y111.227 E.01229
G1 F8666.084
G1 X133.16 Y110.777 E.01383
G1 F8994
G1 X132.813 Y110.342 E.01708
G1 X132.479 Y109.984 E.01506
G1 X132.119 Y109.651 E.01507
G2 X132.119 Y119.349 I-4.115 J4.849 E.88894
G1 X132.479 Y119.016 E.01507
G1 X132.813 Y118.658 E.01507
G1 X133.16 Y118.223 E.01708
G1 F8666.141
G1 X133.16 Y117.773 E.01383
G1 F7416.622
G1 X133.16 Y117.373 E.01229
G1 F6387.692
G1 X133.16 Y116.973 E.01229
G1 F5435.562
G1 X133.16 Y116.573 E.01229
G1 F4560.232
G1 X133.16 Y116.173 E.01229
G1 F3761.702
G1 X133.16 Y115.773 E.01229
G1 F3039.973
G1 X133.16 Y115.373 E.01229
G1 F2395.043
G1 X133.16 Y115.214 E.00489
G1 F2160
G1 X135.79 Y115.214 E.08081
G1 F2395.043
G1 X135.79 Y115.373 E.00489
G1 F2716.395
G1 X135.79 Y115.578 E.00631
M204 S10000
G1 X135.384 Y116.444 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.4635
G1 F8994
G1 X141.724 Y116.444 E.21728
G1 X133.966 Y116.02 F36000
G1 F8994
G1 X134.924 Y116.02 E.03284
G1 X133.9 Y116.901 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F8994
G1 X133.871 Y118.519 E.05368
G1 X138.104 Y122.752 E.19856
G3 X133.838 Y126.162 I-10.354 J-8.577 E.18243
G1 X129.178 Y121.502 E.21862
G3 X126.825 Y121.499 I-1.164 J-8.683 E.07828
G1 X122.156 Y126.168 E.21903
G3 X117.895 Y122.753 I5.93 J-11.765 E.18246
G1 X122.142 Y118.506 E.19923
G3 X121.002 Y113.326 I6.01 J-4.039 E.18015
G1 X116.335 Y108.66 E.2189
G1 X115.502 Y110.757 F36000
G1 F8994
G3 X116.066 Y109.23 I15.858 J4.993 E.054
G1 X122.736 Y102.56 E.31291
G3 X124.865 Y101.837 I7.154 J17.576 E.07463
G1 X131.182 Y108.154 E.29632
G3 X132.006 Y108.642 I-3.881 J7.484 E.03179
G1 X136.251 Y104.397 E.19917
G3 X137.445 Y105.503 I-9.391 J11.334 E.054
G1 X139.664 Y108.66 F36000
G1 F8994
G1 X136.182 Y112.142 E.16336
G1 X135.191 Y112.163 E.0329
G1 X133.9 Y110.872 E.06053
G1 X133.9 Y112.501 E.05401
G1 X135.384 Y112.556 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.4635
G1 F8994
G1 X141.724 Y112.556 E.21728
G1 X133.966 Y112.98 F36000
G1 F8994
G1 X134.924 Y112.98 E.03284
; WIPE_START
G1 F12000
G1 X133.966 Y112.98 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X126.588 Y111.024 Z9.4 F36000
G1 X122.552 Y109.953 Z9.4
G1 Z9
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F8994
G2 X121.661 Y111.311 I5.456 J4.552 E.05399
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I12.974 J-3.182 E.08975
G1 X127.537 Y127.537 E.58997
G2 X128.468 Y127.532 I.422 J-7.437 E.03089
G1 X139.142 Y116.858 E.50074
G1 X139.886 Y116.858 E.02468
G1 X141.578 Y118.55 E.07936
G1 X140.438 Y118.55 E.03781
G1 X140.25 Y119 E.0162
; WIPE_START
G1 F15476.087
G1 X140.438 Y118.55 E-.1856
G1 X141.578 Y118.55 E-.43316
G1 X141.315 Y118.287 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X134.66 Y114.549 Z9.4 F36000
G1 X118.555 Y105.502 Z9.4
G1 Z9
G1 E.8 F1800
G1 F8994
G3 X119.748 Y104.396 I9.744 J9.312 E.05401
G1 X123.992 Y108.64 E.19912
G3 X124.816 Y108.156 I3.541 J5.082 E.03174
G1 X131.132 Y101.84 E.2963
G3 X133.269 Y102.565 I-3.068 J12.545 E.07495
G1 X139.928 Y109.224 E.31238
G1 X140.438 Y110.45 E.04405
G1 X141.154 Y110.45 E.02376
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y112.142 E.03304
G1 X141.217 Y112.142 E.02097
; CHANGE_LAYER
; Z_HEIGHT: 9.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X141.85 Y112.142 E-.24024
G1 X141.85 Y111.146 E-.37852
G1 X141.587 Y110.883 E-.14124
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
G1 X135.398 Y115.831
G1 Z9.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F8922
G1 X142.198 Y115.831 E.22557
G1 X142.198 Y118.898 E.10175
G1 X140.67 Y118.898 E.0507
G3 X130.064 Y127.738 I-12.738 J-4.5 E.48072
G3 X128.115 Y101.104 I-2.06 J-13.237 E1.46841
G3 X140.369 Y109.354 I-.121 J13.406 E.51896
G1 X140.67 Y110.102 E.02677
G1 X142.198 Y110.102 E.05068
G1 X142.198 Y113.17 E.10175
G1 X135.398 Y113.17 E.22557
G1 X135.398 Y113.594 E.01407
G1 X133.552 Y113.594 E.06123
G1 X133.552 Y110.639 E.098
G2 X125.047 Y108.427 I-5.562 J3.928 E.31686
G2 X133.11 Y118.914 I2.956 J6.07 E.79421
G1 X133.552 Y118.361 E.02349
G1 X133.552 Y115.406 E.098
G1 X135.398 Y115.406 E.06123
G1 X135.398 Y115.771 E.01208
G1 X135.79 Y115.438 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F2219.429
M204 S6000
G1 X135.831 Y115.438 E.00126
G1 F2160
G1 X142.59 Y115.438 E.20769
G1 F2395.043
G1 X142.59 Y115.597 E.00489
G1 F3039.973
G1 X142.59 Y115.997 E.01229
G1 F3761.702
G1 X142.59 Y116.397 E.01229
G1 F4560.232
G1 X142.59 Y116.797 E.01229
G1 F5435.562
G1 X142.59 Y117.197 E.01229
G1 F6387.692
G1 X142.59 Y117.597 E.01229
G1 F7416.622
G1 X142.59 Y117.997 E.01229
G1 F8522.352
G1 X142.59 Y118.397 E.01229
G1 F8922
G1 X142.59 Y118.797 E.01229
G1 X142.59 Y119.29 E.01514
G1 X142.19 Y119.29 E.01229
G1 X140.935 Y119.29 E.03857
G3 X139.167 Y122.585 I-13.048 J-4.88 E.11523
G3 X128.121 Y100.712 I-11.168 J-8.086 E1.73466
G3 X140.935 Y109.71 I-.139 J13.82 E.51147
G1 X142.19 Y109.71 E.03857
G1 X142.59 Y109.71 E.01229
G1 X142.59 Y110.203 E.01514
G1 X142.59 Y110.603 E.01229
G1 F8522.323
G1 X142.59 Y111.003 E.01229
G1 F7416.595
G1 X142.59 Y111.403 E.01229
G1 F6387.667
G1 X142.59 Y111.803 E.01229
G1 F5435.539
G1 X142.59 Y112.203 E.01229
G1 F4560.211
G1 X142.59 Y112.603 E.01229
G1 F3761.683
G1 X142.59 Y113.003 E.01229
G1 F3039.955
G1 X142.59 Y113.403 E.01229
G1 F2395.027
G1 X142.59 Y113.562 E.00489
G1 F2160
G1 X135.831 Y113.562 E.20769
G1 F2386.135
G1 X135.79 Y113.562 E.00126
G1 X135.79 Y113.827 E.00815
G1 F2507.975
G1 X135.79 Y113.986 E.00489
G1 F2160
G1 X133.16 Y113.986 E.08081
G1 F2395.027
G1 X133.16 Y113.827 E.00489
G1 F3039.955
G1 X133.16 Y113.427 E.01229
G1 F3761.683
G1 X133.16 Y113.027 E.01229
G1 F4560.211
G1 X133.16 Y112.627 E.01229
G1 F5435.539
G1 X133.16 Y112.227 E.01229
G1 F6387.667
G1 X133.16 Y111.827 E.01229
G1 F7416.595
G1 X133.16 Y111.427 E.01229
G1 F8522.323
G1 X133.16 Y111.027 E.01229
G1 F8922
G1 X133.16 Y110.777 E.00768
G1 X132.813 Y110.342 E.01708
G1 X132.48 Y109.982 E.01507
G2 X132.48 Y119.018 I-4.476 J4.518 E.91909
G1 X132.813 Y118.658 E.01507
G1 X133.16 Y118.223 E.01708
G1 X133.16 Y117.973 E.00768
G1 F8522.352
G1 X133.16 Y117.573 E.01229
G1 F7416.622
G1 X133.16 Y117.173 E.01229
G1 F6387.692
G1 X133.16 Y116.773 E.01229
G1 F5435.562
G1 X133.16 Y116.373 E.01229
G1 F4560.232
G1 X133.16 Y115.973 E.01229
G1 F3761.702
G1 X133.16 Y115.573 E.01229
G1 F3039.973
G1 X133.16 Y115.173 E.01229
G1 F2395.043
G1 X133.16 Y115.014 E.00489
G1 F2160
G1 X135.79 Y115.014 E.08081
G1 F2395.043
G1 X135.79 Y115.173 E.00489
G1 F2716.395
G1 X135.79 Y115.378 E.00631
M204 S10000
G1 X135.384 Y116.244 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.4635
G1 F8922
G1 X141.724 Y116.244 E.21728
G1 X133.966 Y115.82 F36000
G1 F8922
G1 X134.924 Y115.82 E.03284
; WIPE_START
G1 F12000
G1 X133.966 Y115.82 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.384 Y112.756 Z9.6 F36000
G1 Z9.2
G1 E.8 F1800
G1 F8922
G1 X141.724 Y112.756 E.21728
G1 X133.966 Y113.18 F36000
G1 F8922
G1 X134.924 Y113.18 E.03284
G1 X133.9 Y112.501 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F8922
G1 X133.9 Y110.872 E.05401
G1 X135.37 Y112.342 E.06894
G1 X135.982 Y112.342 E.02031
G1 X139.664 Y108.66 E.17274
G1 X137.445 Y105.503 F36000
G1 F8922
G2 X136.251 Y104.397 I-10.506 J10.144 E.054
G1 X132.006 Y108.642 E.19917
G2 X131.182 Y108.154 I-4.707 J6.998 E.03179
G1 X124.865 Y101.837 E.29632
G2 X122.736 Y102.56 I5.036 J18.333 E.07462
G1 X116.066 Y109.23 E.31291
G2 X115.502 Y110.756 I15.077 J6.44 E.054
G1 X116.335 Y108.66 F36000
G1 F8922
G1 X121.002 Y113.326 E.2189
G2 X122.142 Y118.506 I7.235 J1.123 E.18005
G1 X117.895 Y122.753 E.19923
G2 X122.156 Y126.168 I10.191 J-8.351 E.18246
G1 X126.825 Y121.499 E.21903
G2 X129.178 Y121.502 I1.188 J-8.678 E.07828
G1 X133.838 Y126.162 E.21859
G2 X138.104 Y122.752 I-6.056 J-11.95 E.18244
G1 X133.871 Y118.519 E.19856
G1 X133.9 Y116.901 E.05368
G1 X140.25 Y119 F36000
G1 F8922
G1 X140.438 Y118.55 E.0162
G1 X141.578 Y118.55 E.03782
G1 X139.686 Y116.658 E.08874
G1 X139.342 Y116.658 E.01141
G1 X128.469 Y127.531 E.51009
G3 X127.537 Y127.537 I-.513 J-7.286 E.03091
G1 X114.961 Y114.961 E.58997
G2 X115.336 Y117.636 I13.346 J-.506 E.08975
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.399 J5.198 E.05392
; WIPE_START
G1 F15476.087
G1 X122.054 Y110.618 E-.31576
G1 X121.661 Y111.311 E-.30259
G1 X121.398 Y111.574 E-.14165
; WIPE_END
G1 E-.04 F1800
G1 X129.025 Y111.867 Z9.6 F36000
G1 X141.417 Y112.342 Z9.6
G1 Z9.2
G1 E.8 F1800
G1 F8922
G1 X141.85 Y112.342 E.01434
G1 X141.85 Y111.146 E.03968
G1 X141.154 Y110.45 E.03263
G1 X140.438 Y110.45 E.02376
G1 X139.928 Y109.224 E.04406
G1 X133.269 Y102.565 E.31238
G2 X131.133 Y101.84 I-5.217 J11.853 E.07494
G1 X124.816 Y108.156 E.29631
G2 X123.992 Y108.64 I2.72 J5.571 E.03174
G1 X119.748 Y104.396 E.19912
G2 X118.555 Y105.502 I8.556 J10.424 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 9.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X119.748 Y104.396 E-.61828
G1 X120.011 Y104.659 E-.14172
; WIPE_END
G1 E-.03999 F1800
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
G1 X135.398 Y115.631
G1 Z9.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F9069
G1 X142.198 Y115.631 E.22557
G1 X142.198 Y118.898 E.10839
G1 X140.669 Y118.898 E.0507
G3 X130.063 Y127.738 I-12.739 J-4.502 E.48072
G3 X128.107 Y101.104 I-2.06 J-13.238 E1.46816
G3 X140.371 Y109.36 I-.114 J13.407 E.51944
G1 X140.67 Y110.102 E.02653
G1 X142.198 Y110.102 E.05069
G1 X142.198 Y113.37 E.10839
G1 X135.398 Y113.37 E.22557
G1 X135.398 Y113.794 E.01407
G1 X133.552 Y113.794 E.06123
G1 X133.552 Y110.639 E.10464
G2 X126.518 Y107.912 I-5.579 J3.955 E.26508
G2 X133.11 Y118.914 I1.485 J6.586 E.84601
G1 X133.552 Y118.361 E.0235
G1 X133.552 Y115.206 E.10463
G1 X135.398 Y115.206 E.06123
G1 X135.398 Y115.571 E.01208
M73 P89 R2
G1 X135.79 Y115.238 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F2219.429
M204 S6000
G1 X135.831 Y115.238 E.00126
G1 F2160
G1 X142.59 Y115.238 E.20769
G1 F2395.043
G1 X142.59 Y115.397 E.00489
G1 F3039.973
G1 X142.59 Y115.797 E.01229
G1 F3761.702
G1 X142.59 Y116.197 E.01229
G1 F4560.232
G1 X142.59 Y116.597 E.01229
G1 F5435.562
G1 X142.59 Y116.997 E.01229
G1 F6387.692
G1 X142.59 Y117.397 E.01229
G1 F7416.622
G1 X142.59 Y117.797 E.01229
G1 F8522.352
G1 X142.59 Y118.197 E.01229
G1 F9069
G1 X142.59 Y118.597 E.01229
G1 X142.59 Y118.997 E.01229
G1 X142.59 Y119.29 E.00899
G1 X142.19 Y119.29 E.01229
G1 X140.935 Y119.29 E.03857
G3 X128.114 Y100.712 I-12.931 J-4.789 E1.84975
G3 X140.935 Y109.71 I-.131 J13.82 E.51169
G1 X142.19 Y109.71 E.03857
G1 X142.59 Y109.71 E.01229
G1 X142.59 Y110.003 E.00899
G1 X142.59 Y110.403 E.01229
G1 X142.59 Y110.803 E.01229
G1 F8522.323
G1 X142.59 Y111.203 E.01229
G1 F7416.595
G1 X142.59 Y111.603 E.01229
G1 F6387.667
G1 X142.59 Y112.003 E.01229
G1 F5435.539
G1 X142.59 Y112.403 E.01229
G1 F4560.211
G1 X142.59 Y112.803 E.01229
G1 F3761.683
G1 X142.59 Y113.203 E.01229
G1 F3039.955
G1 X142.59 Y113.603 E.01229
G1 F2395.027
G1 X142.59 Y113.762 E.00489
G1 F2160
G1 X135.831 Y113.762 E.20769
G1 F2386.135
G1 X135.79 Y113.762 E.00126
G1 X135.79 Y114.027 E.00815
G1 F2507.975
G1 X135.79 Y114.186 E.00489
G1 F2160
G1 X133.16 Y114.186 E.08081
G1 F2395.027
G1 X133.16 Y114.027 E.00489
G1 F3039.955
G1 X133.16 Y113.627 E.01229
G1 F3761.683
G1 X133.16 Y113.227 E.01229
G1 F4560.211
G1 X133.16 Y112.827 E.01229
G1 F5435.539
G1 X133.16 Y112.427 E.01229
G1 F6387.667
G1 X133.16 Y112.027 E.01229
G1 F7416.595
G1 X133.16 Y111.627 E.01229
G1 F8522.323
G1 X133.16 Y111.227 E.01229
G1 F9069
G1 X133.16 Y110.777 E.01383
G1 X132.813 Y110.342 E.01708
G1 X132.48 Y109.982 E.01507
G2 X132.48 Y119.018 I-4.476 J4.518 E.91906
G1 X132.813 Y118.658 E.01507
G1 X133.16 Y118.223 E.01708
G1 X133.16 Y117.773 E.01383
G1 F8522.352
G1 X133.16 Y117.373 E.01229
G1 F7416.622
G1 X133.16 Y116.973 E.01229
G1 F6387.692
G1 X133.16 Y116.573 E.01229
G1 F5435.562
G1 X133.16 Y116.173 E.01229
G1 F4560.232
G1 X133.16 Y115.773 E.01229
G1 F3761.702
G1 X133.16 Y115.373 E.01229
G1 F3039.973
G1 X133.16 Y114.973 E.01229
G1 F2395.043
G1 X133.16 Y114.814 E.00489
G1 F2160
G1 X135.79 Y114.814 E.08081
G1 F2395.043
G1 X135.79 Y114.973 E.00489
G1 F2716.395
G1 X135.79 Y115.178 E.00631
M204 S10000
G1 X135.384 Y116.044 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.4635
G1 F9069
G1 X141.724 Y116.044 E.21728
G1 X133.966 Y115.62 F36000
G1 F9069
G1 X134.924 Y115.62 E.03284
G1 X133.9 Y116.901 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F9069
G1 X133.871 Y118.519 E.05368
G1 X138.103 Y122.752 E.19855
G3 X133.837 Y126.161 I-10.292 J-8.505 E.18245
G1 X129.178 Y121.502 E.21856
G3 X126.825 Y121.499 I-1.165 J-8.682 E.07828
G1 X122.156 Y126.168 E.21902
G3 X117.895 Y122.753 I5.929 J-11.765 E.18246
G1 X122.142 Y118.506 E.19923
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.66 E.2189
G1 X115.502 Y110.756 F36000
G1 F9069
G3 X116.066 Y109.23 I15.431 J4.837 E.054
G1 X122.736 Y102.56 E.31292
G3 X124.865 Y101.837 I7.171 J17.632 E.07461
G1 X131.182 Y108.154 E.29633
G3 X132.006 Y108.642 I-3.879 J7.48 E.03179
G1 X136.251 Y104.397 E.19917
G3 X137.445 Y105.502 I-9.25 J11.182 E.054
G1 X139.664 Y108.66 F36000
G1 F9069
G1 X135.782 Y112.542 E.18213
G1 X135.57 Y112.542 E.00704
G1 X133.9 Y110.872 E.07832
G1 X133.9 Y112.501 E.05401
G1 X135.384 Y112.956 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.4635
G1 F9069
G1 X141.724 Y112.956 E.21728
G1 X133.966 Y113.38 F36000
G1 F9069
G1 X134.924 Y113.38 E.03284
; WIPE_START
G1 F12000
G1 X133.966 Y113.38 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X126.656 Y111.185 Z9.8 F36000
G1 X122.552 Y109.953 Z9.8
G1 Z9.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F9069
G2 X121.661 Y111.311 I5.29 J4.443 E.05399
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I12.978 J-3.182 E.08975
G1 X127.537 Y127.537 E.58997
G2 X128.463 Y127.537 I.463 J-8.968 E.0307
G1 X139.542 Y116.458 E.51976
G1 X139.486 Y116.458 E.00186
G1 X141.578 Y118.55 E.09812
G1 X140.437 Y118.55 E.03782
G1 X140.249 Y119 E.01619
; WIPE_START
G1 F15476.087
G1 X140.437 Y118.55 E-.18551
G1 X141.578 Y118.55 E-.43325
G1 X141.315 Y118.287 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X134.66 Y114.549 Z9.8 F36000
G1 X118.555 Y105.502 Z9.8
G1 Z9.4
G1 E.8 F1800
G1 F9069
G3 X119.748 Y104.396 I9.74 J9.308 E.05401
G1 X123.992 Y108.64 E.19912
G3 X124.816 Y108.156 I3.541 J5.082 E.03174
G1 X131.133 Y101.839 E.29632
G3 X133.269 Y102.565 I-3.094 J12.617 E.07492
G1 X139.927 Y109.224 E.31237
G1 X140.438 Y110.45 E.04407
G1 X141.154 Y110.45 E.02377
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y112.542 E.04631
G1 X141.617 Y112.542 E.0077
; CHANGE_LAYER
; Z_HEIGHT: 9.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15476.087
G1 X141.85 Y112.542 E-.08824
G1 X141.85 Y111.146 E-.53052
G1 X141.587 Y110.883 E-.14124
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
G1 X133.506 Y118.418
G1 Z9.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F10956
G1 X133.11 Y118.914 E.02107
G3 X122.217 Y117.976 I-5.107 J-4.417 E.42267
G3 X127.798 Y107.756 I5.781 J-3.477 E.46609
G3 X131.526 Y108.748 I.178 J6.826 E.12971
G1 X131.962 Y109.032 E.01727
G1 X132.371 Y109.353 E.01726
G1 X132.755 Y109.705 E.01728
G1 F10248.814
G1 X133.11 Y110.086 E.01727
G1 F8681.047
G1 X133.302 Y110.327 E.01023
G1 F7813.917
G1 X133.552 Y110.639 E.01327
G1 F6756.773
G1 X133.552 Y111.013 E.0124
G1 F5838.03
G1 X133.552 Y111.413 E.01327
G1 F4929.476
G1 X133.552 Y111.813 E.01327
G1 F4097.723
G1 X133.552 Y112.213 E.01327
G1 F3342.769
G1 X133.552 Y112.613 E.01327
G1 F2664.615
G1 X133.552 Y113.013 E.01327
G1 F2063.261
G1 X133.552 Y113.413 E.01327
G1 F1538.708
G1 X133.552 Y113.813 E.01327
G1 F1090.954
G1 X133.552 Y114.213 E.01327
G1 F720
G1 X133.552 Y114.787 E.01902
G1 F1090.954
G1 X133.552 Y115.187 E.01327
G1 F1538.708
G1 X133.552 Y115.587 E.01327
G1 F2063.261
G1 X133.552 Y115.987 E.01327
G1 F2664.615
G1 X133.552 Y116.387 E.01327
G1 F3342.769
G1 X133.552 Y116.787 E.01327
G1 F4097.723
G1 X133.552 Y117.187 E.01327
G1 F4929.476
G1 X133.552 Y117.587 E.01327
G1 F5838.03
G1 X133.552 Y117.987 E.01327
G1 F6756.773
G1 X133.552 Y118.361 E.0124
G1 F6790.296
G1 X133.544 Y118.371 E.00044
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F10956
M204 S6000
G3 X127.81 Y108.147 I-5.156 J-3.721 E.79253
G3 X131.73 Y109.352 I.181 J6.389 E.12829
G1 X132.117 Y109.652 E.01506
G1 F10833.774
G1 X132.479 Y109.984 E.01507
G1 F9309.855
G1 X132.813 Y110.342 E.01507
G1 F7901.688
G1 X133.16 Y110.777 E.01708
G1 F6445.025
G1 X133.16 Y111.027 E.00768
G1 F5838.03
G1 X133.16 Y111.427 E.01229
G1 F4929.476
G1 X133.16 Y111.827 E.01229
G1 F4097.723
G1 X133.16 Y112.227 E.01229
G1 F3342.769
G1 X133.16 Y112.627 E.01229
G1 F2664.615
G1 X133.16 Y113.027 E.01229
G1 F2063.261
G1 X133.16 Y113.427 E.01229
G1 F1538.708
G1 X133.16 Y113.827 E.01229
G1 F1090.954
G1 X133.16 Y114.227 E.01229
G1 F720
G1 X133.16 Y114.773 E.01679
G1 F1090.954
G1 X133.16 Y115.173 E.01229
G1 F1538.708
G1 X133.16 Y115.573 E.01229
G1 F2063.261
G1 X133.16 Y115.973 E.01229
G1 F2664.615
G1 X133.16 Y116.373 E.01229
G1 F3342.769
G1 X133.16 Y116.773 E.01229
G1 F4097.723
G1 X133.16 Y117.173 E.01229
G1 F4929.476
G1 X133.16 Y117.573 E.01229
G1 F6296.645
G1 X133.16 Y118.163 E.01813
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.2295
G1 X132.479 Y119.016 E-.18626
G1 X132.117 Y119.348 E-.1864
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X135.398 Y115.431 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F10956
G1 X142.198 Y115.431 E.22557
G1 X142.198 Y118.898 E.11502
G1 X140.669 Y118.898 E.05071
G3 X130.063 Y127.738 I-12.74 J-4.502 E.48072
G3 X128.1 Y101.104 I-2.062 J-13.237 E1.46807
G3 X140.374 Y109.366 I-.114 J13.417 E.51985
G1 X140.67 Y110.102 E.02632
G1 X142.198 Y110.102 E.05069
G1 X142.198 Y113.57 E.11502
G1 X141.398 Y113.57 E.02654
G1 X140.998 Y113.57 E.01327
G1 X140.598 Y113.57 E.01327
G1 X140.198 Y113.57 E.01327
G1 X139.798 Y113.57 E.01327
G1 X139.398 Y113.57 E.01327
G1 F9756.476
G1 X138.998 Y113.57 E.01327
G1 F8570.705
G1 X138.598 Y113.57 E.01327
G1 F7461.734
G1 X138.198 Y113.57 E.01327
G1 F6429.563
G1 X137.798 Y113.57 E.01327
G1 F5474.192
G1 X137.398 Y113.57 E.01327
G1 F4595.621
G1 X136.998 Y113.57 E.01327
G1 F3793.85
G1 X136.598 Y113.57 E.01327
G1 F3068.879
G1 X136.198 Y113.57 E.01327
G1 F2420.708
G1 X135.798 Y113.57 E.01327
G1 F1849.337
G1 X135.398 Y113.57 E.01327
G1 F1354.766
G1 X135.398 Y113.813 E.00809
G1 F1090.954
G1 X135.398 Y114.213 E.01327
G1 F720
G1 X135.398 Y114.787 E.01902
G1 F1287.193
G1 X135.398 Y115.371 E.01937
G1 X135.79 Y115.038 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F2219.429
M204 S6000
G1 X135.831 Y115.038 E.00126
G1 F2160
G1 X142.59 Y115.038 E.20769
G1 F2395.043
G1 X142.59 Y115.197 E.00489
G1 F3039.973
G1 X142.59 Y115.597 E.01229
G1 F3761.702
G1 X142.59 Y115.997 E.01229
G1 F4560.232
G1 X142.59 Y116.397 E.01229
G1 F5435.562
G1 X142.59 Y116.797 E.01229
G1 F6387.692
G1 X142.59 Y117.197 E.01229
G1 F7416.622
G1 X142.59 Y117.597 E.01229
G1 F8522.352
G1 X142.59 Y117.997 E.01229
G1 F9704.882
G1 X142.59 Y118.397 E.01229
G1 F10956
G1 X142.59 Y118.797 E.01229
G1 X142.59 Y119.29 E.01514
G1 X140.935 Y119.29 E.05087
G3 X128.106 Y100.712 I-12.93 J-4.79 E1.84939
G3 X140.935 Y109.71 I-.11 J13.8 E.51202
G1 X142.59 Y109.71 E.05086
G1 X142.59 Y110.203 E.01514
G1 X142.59 Y110.603 E.01229
G1 F9704.851
G1 X142.59 Y111.003 E.01229
G1 F8522.323
G1 X142.59 Y111.403 E.01229
G1 F7416.595
G1 X142.59 Y111.803 E.01229
G1 F6387.667
G1 X142.59 Y112.203 E.01229
G1 F5435.539
G1 X142.59 Y112.603 E.01229
G1 F4560.211
G1 X142.59 Y113.003 E.01229
G1 F3761.683
G1 X142.59 Y113.403 E.01229
G1 F3039.955
G1 X142.59 Y113.803 E.01229
G1 F2395.027
G1 X142.59 Y113.962 E.00489
G1 F2160
G1 X135.831 Y113.962 E.20769
G1 F2386.135
G1 X135.79 Y113.962 E.00126
G1 X135.79 Y114.227 E.00815
G1 F720
G1 X135.79 Y114.773 E.01679
G1 F900.762
G1 X135.79 Y114.978 E.00631
M204 S10000
G1 X135.804 Y115.844 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.4634
G1 F10956
G1 X141.724 Y115.844 E.20285
; WIPE_START
G1 F14982.877
G1 X139.724 Y115.844 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X141.817 Y112.742 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F10956
G1 X141.85 Y111.146 E.05296
G1 X141.154 Y110.45 E.03263
G1 X140.437 Y110.45 E.02377
G1 X139.927 Y109.223 E.04408
G1 X133.267 Y102.563 E.31245
G2 X131.136 Y101.836 I-7.48 J18.426 E.07471
G1 X124.816 Y108.156 E.2965
G2 X123.992 Y108.64 I2.718 J5.568 E.03174
G1 X119.748 Y104.396 E.19912
G2 X118.554 Y105.502 I8.561 J10.43 E.05401
G1 X116.335 Y108.66 F36000
G1 F10956
G1 X121.002 Y113.326 E.2189
G2 X122.142 Y118.506 I7.235 J1.123 E.18005
G1 X117.895 Y122.753 E.19923
G2 X122.156 Y126.168 I10.191 J-8.35 E.18246
G1 X126.825 Y121.499 E.21903
G2 X129.178 Y121.502 I1.186 J-7.188 E.07839
G1 X133.836 Y126.16 E.21853
G2 X138.103 Y122.751 I-5.994 J-11.878 E.18247
G1 X133.871 Y118.519 E.19854
G1 X133.9 Y116.901 E.05368
G1 X134.686 Y115.611 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.4384
G1 F3000
G1 X134.686 Y113.558 E.06616
G1 X134.29 Y113.558 E.01274
G1 X134.29 Y115.442 E.06069
G1 X133.895 Y115.442 E.01274
G1 X133.895 Y113.389 E.06616
G1 X135.804 Y113.156 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.4634
G1 F10956
G1 X141.724 Y113.156 E.20285
G1 X139.662 Y108.662 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F10956
G1 X135.582 Y112.742 E.19142
G1 X135.77 Y112.742 E.00623
G1 X133.9 Y110.872 E.0877
G1 X133.9 Y112.501 E.05401
G1 X137.445 Y105.502 F36000
G1 F10956
G2 X136.251 Y104.397 I-10.378 J10.006 E.054
G1 X132.006 Y108.642 E.19917
G2 X131.182 Y108.154 I-4.707 J6.999 E.03179
G1 X124.865 Y101.837 E.29633
G2 X122.737 Y102.56 I5.056 J18.394 E.07461
G1 X116.066 Y109.23 E.31292
G2 X115.502 Y110.756 I14.68 J6.295 E.054
; WIPE_START
G1 F15476.087
G1 X116.066 Y109.23 E-.61835
G1 X116.33 Y108.966 E-.14165
; WIPE_END
G1 E-.04 F1800
G1 X123.368 Y111.919 Z10 F36000
G1 X140.249 Y119 Z10
G1 Z9.6
G1 E.8 F1800
G1 F10956
G1 X140.437 Y118.55 E.01619
G1 X141.578 Y118.55 E.03783
G1 X139.286 Y116.258 E.10751
G1 X139.742 Y116.258 E.01513
G1 X128.47 Y127.53 E.5288
G3 X127.537 Y127.537 I-.521 J-7.033 E.03095
G1 X114.961 Y114.961 E.58997
G2 X115.336 Y117.636 I13.344 J-.506 E.08975
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.399 J5.198 E.05392
; CHANGE_LAYER
; Z_HEIGHT: 9.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X122.054 Y110.618 E-.3158
G1 X121.661 Y111.311 E-.30255
G1 X121.398 Y111.574 E-.14165
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
G1 X133.506 Y118.418
G1 Z9.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F9072
G1 X133.11 Y118.914 E.02107
G3 X127.783 Y107.756 I-5.109 J-4.412 E.88841
G3 X133.552 Y110.639 I.185 J6.842 E.22276
G1 X133.552 Y118.361 E.25612
G1 X133.544 Y118.371 E.00044
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F9072
M204 S6000
G3 X127.794 Y108.148 I-5.156 J-3.721 E.79209
G3 X133.16 Y110.777 I.199 J6.384 E.19105
G1 X133.16 Y118.163 E.22696
; WIPE_START
G1 F12000
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X135.398 Y115.231 Z10.2 F36000
G1 Z9.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F9072
G1 X142.198 Y115.231 E.22557
G1 X142.198 Y118.898 E.12166
G1 X140.669 Y118.898 E.05071
G3 X130.063 Y127.738 I-12.739 J-4.502 E.48072
G3 X128.093 Y101.104 I-2.062 J-13.237 E1.46783
G3 X140.376 Y109.372 I-.106 J13.416 E.52031
G1 X140.67 Y110.102 E.0261
G1 X142.198 Y110.102 E.0507
G1 X142.198 Y113.77 E.12166
G1 X135.398 Y113.77 E.22557
G1 X135.398 Y115.171 E.04647
G1 X135.79 Y114.838 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F2219.429
M204 S6000
G1 X135.831 Y114.838 E.00126
G1 F2160
G1 X142.59 Y114.838 E.20769
G1 F2395.043
G1 X142.59 Y114.997 E.00489
G1 F3039.973
G1 X142.59 Y115.397 E.01229
G1 F3761.702
G1 X142.59 Y115.797 E.01229
G1 F4560.232
G1 X142.59 Y116.197 E.01229
G1 F5435.562
G1 X142.59 Y116.597 E.01229
G1 F6387.692
G1 X142.59 Y116.997 E.01229
G1 F7416.622
G1 X142.59 Y117.397 E.01229
G1 F8522.352
G1 X142.59 Y117.797 E.01229
G1 F9072
G1 X142.59 Y118.197 E.01229
G1 X142.59 Y118.597 E.01229
G1 X142.59 Y118.997 E.01229
G1 X142.59 Y119.29 E.00899
G1 X140.935 Y119.29 E.05087
G3 X134.445 Y126.686 I-12.954 J-4.821 E.30913
G3 X128.099 Y100.712 I-6.445 J-12.188 E1.54004
G3 X140.935 Y109.71 I-.111 J13.812 E.51218
G1 X142.59 Y109.71 E.05086
G1 X142.59 Y110.003 E.00899
G1 X142.59 Y110.403 E.01229
G1 X142.59 Y110.803 E.01229
G1 X142.59 Y111.203 E.01229
G1 F8522.323
G1 X142.59 Y111.603 E.01229
G1 F7416.595
G1 X142.59 Y112.003 E.01229
G1 F6387.667
G1 X142.59 Y112.403 E.01229
G1 F5435.539
G1 X142.59 Y112.803 E.01229
G1 F4560.211
G1 X142.59 Y113.203 E.01229
G1 F3761.683
G1 X142.59 Y113.603 E.01229
G1 F3039.955
G1 X142.59 Y114.003 E.01229
G1 F2395.027
G1 X142.59 Y114.162 E.00489
G1 F2160
G1 X135.831 Y114.162 E.20769
G1 F2219.429
G1 X135.79 Y114.162 E.00126
G1 F2841.699
G1 X135.79 Y114.562 E.01229
G1 F3211.15
G1 X135.79 Y114.778 E.00666
M204 S10000
G1 X135.384 Y115.644 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.4634
G1 F9072
G1 X141.724 Y115.644 E.21723
; WIPE_START
G1 F12000
G1 X139.724 Y115.644 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X141.784 Y113.356 Z10.2 F36000
G1 Z9.8
G1 E.8 F1800
G1 F9072
G1 X135.444 Y113.356 E.21723
G1 X135.006 Y115.242 F36000
; LINE_WIDTH: 0.41999
G1 F9072
G1 X135.006 Y113.758 E.04558
G1 X133.944 Y113.758 E.03262
G1 X133.944 Y115.242 E.04558
G1 X134.946 Y115.242 E.03078
G1 X134.646 Y114.882 F36000
; LINE_WIDTH: 0.38525
G1 F9072
G1 X134.646 Y114.118 E.02131
G1 X134.304 Y114.118 E.00955
G1 X134.304 Y114.882 E.02131
G1 X134.586 Y114.882 E.00788
G1 X135.188 Y112.965 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F9072
G1 X134.97 Y113.183 E.01022
G1 X134.958 Y113.366 E.00609
G1 X133.9 Y113.366 E.03508
G1 X133.9 Y110.872 E.08272
G1 X135.97 Y112.942 E.09708
G1 X135.382 Y112.942 E.0195
G1 X139.664 Y108.66 E.20089
; WIPE_START
G1 F15476.087
G1 X138.25 Y110.074 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.149 Y116.511 Z10.2 F36000
G1 X133.9 Y116.901 Z10.2
G1 Z9.8
G1 E.8 F1800
G1 F9072
G1 X133.871 Y118.519 E.05368
G1 X138.103 Y122.751 E.19854
G3 X133.836 Y126.16 I-10.232 J-8.434 E.18248
G1 X129.178 Y121.502 E.21851
G3 X126.825 Y121.499 I-1.165 J-8.681 E.07828
G1 X122.156 Y126.168 E.21902
G3 X117.895 Y122.753 I5.929 J-11.764 E.18246
G1 X122.142 Y118.506 E.19923
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.66 E.2189
M73 P90 R2
G1 X115.502 Y110.756 F36000
G1 F9072
G3 X116.066 Y109.23 I15.046 J4.696 E.054
G1 X122.737 Y102.559 E.31292
G3 X124.865 Y101.837 I7.196 J17.708 E.0746
G1 X131.182 Y108.154 E.29633
G3 X132.006 Y108.642 I-3.879 J7.48 E.03179
G1 X136.251 Y104.397 E.19918
G3 X137.445 Y105.502 I-9.124 J11.047 E.054
; WIPE_START
G1 F15476.087
G1 X136.251 Y104.397 E-.61826
G1 X135.988 Y104.66 E-.14174
; WIPE_END
G1 E-.04 F1800
G1 X128.886 Y107.458 Z10.2 F36000
G1 X122.552 Y109.953 Z10.2
G1 Z9.8
G1 E.8 F1800
G1 F9072
G2 X121.661 Y111.311 I8.504 J6.553 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I12.971 J-3.181 E.08975
G1 X127.537 Y127.537 E.58997
G2 X128.47 Y127.53 I.409 J-6.937 E.03097
G1 X139.942 Y116.058 E.53816
G1 X139.086 Y116.058 E.0284
G1 X141.578 Y118.55 E.11689
G1 X140.437 Y118.55 E.03783
G1 X140.249 Y119 E.01619
; WIPE_START
G1 F15476.087
G1 X140.437 Y118.55 E-.18541
G1 X141.578 Y118.55 E-.43335
G1 X141.315 Y118.287 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X134.66 Y114.549 Z10.2 F36000
G1 X118.554 Y105.502 Z10.2
G1 Z9.8
G1 E.8 F1800
G1 F9072
G3 X119.748 Y104.396 I9.742 J9.311 E.05401
G1 X123.992 Y108.64 E.19912
G3 X124.816 Y108.156 I3.54 J5.081 E.03174
G1 X131.136 Y101.836 E.29649
G3 X133.266 Y102.563 I-5.342 J19.14 E.0747
G1 X139.927 Y109.223 E.31246
G1 X140.437 Y110.45 E.04409
G1 X141.154 Y110.45 E.02378
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y112.774 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 10
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X141.85 Y111.146 E-.61876
G1 X141.587 Y110.883 E-.14124
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
G1 X133.552 Y118.287
G1 Z10
G1 E.8 F1800
; FEATURE: Inner wall
G1 F11056
G1 X133.552 Y118.361 E.00243
G1 X133.11 Y118.914 E.0235
G3 X127.768 Y107.756 I-5.109 J-4.412 E.88792
G3 X133.552 Y110.639 I.21 J6.823 E.22332
G1 X133.552 Y118.227 E.25171
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F11056
M204 S6000
G3 X127.779 Y108.148 I-5.156 J-3.721 E.7916
G3 X133.16 Y110.777 I.222 J6.366 E.19156
G1 X133.16 Y118.163 E.22696
; WIPE_START
G1 F12000
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X139.399 Y119.003 Z10.4 F36000
G1 X140.731 Y118.898 Z10.4
G1 Z10
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F11056
G1 X140.669 Y118.898 E.00205
G3 X130.063 Y127.738 I-12.738 J-4.501 E.48073
G3 X128.085 Y101.104 I-2.062 J-13.238 E1.46759
G3 X140.157 Y108.872 I-.094 J13.409 E.50249
G1 X140.379 Y109.378 E.01832
G1 X140.521 Y109.731 E.01261
G1 X140.67 Y110.102 E.01327
G1 X140.998 Y110.102 E.01089
G1 X141.398 Y110.102 E.01327
G1 F10040.868
G1 X141.798 Y110.102 E.01327
G1 F8837.383
G1 X142.198 Y110.102 E.01327
G1 F7710.699
G1 X142.198 Y110.589 E.01616
G1 F6442.608
G1 X142.198 Y110.989 E.01327
G1 F5486.229
G1 X142.198 Y111.389 E.01327
G1 F4606.651
G1 X142.198 Y111.789 E.01327
G1 F3803.872
G1 X142.198 Y112.189 E.01327
G1 F3077.893
G1 X142.198 Y112.589 E.01327
G1 F2428.715
G1 X142.198 Y112.989 E.01327
G1 F1856.336
G1 X142.198 Y113.389 E.01327
G1 F1360.757
G1 X142.198 Y113.789 E.01327
G1 F941.979
G1 X142.198 Y114.189 E.01327
G1 F600
G1 X142.198 Y114.811 E.02063
G1 F941.979
G1 X142.198 Y115.211 E.01327
G1 F1360.757
G1 X142.198 Y115.611 E.01327
G1 F1856.336
G1 X142.198 Y116.011 E.01327
G1 F2428.715
G1 X142.198 Y116.411 E.01327
G1 F3077.893
G1 X142.198 Y116.811 E.01327
G1 F3803.872
G1 X142.198 Y117.211 E.01327
G1 F4606.651
G1 X142.198 Y117.611 E.01327
G1 F5486.229
G1 X142.198 Y118.011 E.01327
G1 F6442.608
G1 X142.198 Y118.411 E.01327
G1 F7710.671
G1 X142.198 Y118.898 E.01615
G1 F8837.354
G1 X141.798 Y118.898 E.01327
G1 F10040.837
G1 X141.398 Y118.898 E.01327
G1 F11056
G1 X140.998 Y118.898 E.01327
G1 X140.791 Y118.898 E.00687
G1 X140.935 Y119.29 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F11056
M204 S6000
G3 X134.47 Y126.673 I-12.954 J-4.821 E.30825
G3 X128.092 Y100.712 I-6.469 J-12.175 E1.54057
G3 X140.935 Y109.71 I-.11 J13.821 E.51237
G1 X141.39 Y109.71 E.01399
G1 X141.79 Y109.71 E.01229
G1 X142.19 Y109.71 E.01229
G1 F10058.169
G1 X142.59 Y109.71 E.01229
G1 F8853.615
G1 X142.59 Y110.203 E.01514
G1 F7475.787
G1 X142.59 Y110.603 E.01229
G1 F6442.608
G1 X142.59 Y111.003 E.01229
G1 F5486.229
G1 X142.59 Y111.403 E.01229
G1 F4606.651
G1 X142.59 Y111.803 E.01229
G1 F3803.872
G1 X142.59 Y112.203 E.01229
G1 F3077.893
G1 X142.59 Y112.603 E.01229
G1 F2428.715
G1 X142.59 Y113.003 E.01229
G1 F1856.336
G1 X142.59 Y113.403 E.01229
G1 F1360.757
G1 X142.59 Y113.803 E.01229
G1 F941.979
G1 X142.59 Y114.203 E.01229
G1 F600
G1 X142.59 Y114.797 E.01828
G1 F941.979
G1 X142.59 Y115.197 E.01229
G1 F1360.757
G1 X142.59 Y115.597 E.01229
G1 F1856.336
G1 X142.59 Y115.997 E.01229
G1 F2428.715
G1 X142.59 Y116.397 E.01229
G1 F3077.893
G1 X142.59 Y116.797 E.01229
G1 F3803.872
G1 X142.59 Y117.197 E.01229
G1 F4606.651
G1 X142.59 Y117.597 E.01229
G1 F5486.229
G1 X142.59 Y117.997 E.01229
G1 F6442.608
G1 X142.59 Y118.397 E.01229
G1 F7475.787
G1 X142.59 Y118.797 E.01229
G1 F8853.585
G1 X142.59 Y119.29 E.01514
G1 F10058.137
G1 X142.19 Y119.29 E.01229
G1 F11056
G1 X141.79 Y119.29 E.01229
G1 X141.39 Y119.29 E.01229
G1 X140.995 Y119.29 E.01215
M204 S10000
G1 X140.249 Y119 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F11056
G1 X140.437 Y118.55 E.01618
G1 X141.578 Y118.55 E.03783
G1 X138.886 Y115.858 E.12627
G1 X140.142 Y115.858 E.04167
G1 X128.471 Y127.529 E.54752
G3 X127.537 Y127.537 I-.527 J-6.825 E.03099
G1 X114.961 Y114.961 E.58997
G2 X115.336 Y117.636 I13.347 J-.506 E.08975
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.399 J5.198 E.05392
G1 X116.335 Y108.66 F36000
G1 F11056
G1 X121.002 Y113.326 E.2189
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X117.895 Y122.753 E.19923
G2 X122.156 Y126.168 I10.19 J-8.349 E.18246
G1 X126.825 Y121.499 E.21902
G2 X129.178 Y121.502 I1.188 J-8.679 E.07828
G1 X133.835 Y126.159 E.21848
G2 X138.103 Y122.751 I-5.936 J-11.81 E.18249
G1 X133.871 Y118.519 E.19853
G3 X132.791 Y119.734 I-6.804 J-4.961 E.05401
G1 X135.297 Y115.629 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.42896
G1 F3000
G1 X135.297 Y114.487 E.03592
G1 X135.363 Y114.348 E.00485
G1 X135.374 Y113.534 E.0256
G1 X135.684 Y113.534 E.00974
G1 X135.684 Y115.466 E.06077
G1 X136.07 Y115.466 E.01214
G1 X136.07 Y113.534 E.06077
G1 X136.456 Y113.534 E.01214
G1 X136.456 Y115.466 E.06077
G1 X136.842 Y115.466 E.01214
G1 X136.842 Y113.534 E.06077
G1 X137.228 Y113.534 E.01214
G1 X137.228 Y115.466 E.06077
G1 X137.614 Y115.466 E.01214
G1 X137.614 Y113.534 E.06077
G1 X138 Y113.534 E.01214
G1 X138 Y115.466 E.06077
G1 X138.386 Y115.466 E.01214
G1 X138.386 Y113.534 E.06077
G1 X138.772 Y113.534 E.01214
G1 X138.772 Y115.466 E.06077
G1 X139.158 Y115.466 E.01214
G1 X139.158 Y113.534 E.06077
G1 X139.544 Y113.534 E.01214
G1 X139.544 Y115.466 E.06077
G1 X139.93 Y115.466 E.01214
G1 X139.93 Y113.534 E.06077
G1 X140.316 Y113.534 E.01214
G1 X140.316 Y115.466 E.06077
G1 X140.702 Y115.466 E.01214
G1 X140.702 Y113.534 E.06077
G1 X141.088 Y113.534 E.01214
G1 X141.088 Y115.466 E.06077
G1 X141.474 Y115.466 E.01214
G1 X141.474 Y113.534 E.06077
G1 X141.86 Y113.534 E.01214
G1 X141.86 Y115.636 E.06611
; WIPE_START
G1 X141.86 Y113.636 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X139.664 Y108.66 Z10.4 F36000
G1 Z10
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F11056
G1 X133.9 Y114.424 E.2704
G1 X133.9 Y110.872 E.1178
G1 X136.17 Y113.142 E.10647
G1 X141.85 Y113.142 E.18841
G1 X141.85 Y111.146 E.06621
G1 X141.154 Y110.45 E.03263
G1 X140.437 Y110.45 E.02378
G1 X139.927 Y109.223 E.0441
G1 X133.266 Y102.562 E.31247
G2 X131.136 Y101.836 I-7.501 J18.51 E.07468
G1 X124.816 Y108.156 E.29649
G2 X123.992 Y108.64 I2.717 J5.566 E.03174
G1 X119.748 Y104.396 E.19912
G2 X118.554 Y105.502 I8.554 J10.424 E.05401
G1 X137.445 Y105.502 F36000
G1 F11056
G2 X136.251 Y104.397 I-10.248 J9.866 E.054
G1 X132.006 Y108.642 E.19918
G2 X131.182 Y108.154 I-9.322 J14.783 E.03178
G1 X124.865 Y101.837 E.29633
G2 X122.737 Y102.56 I3.342 J13.345 E.07464
G1 X116.066 Y109.23 E.31292
G2 X115.502 Y110.756 I14.299 J6.155 E.054
; CHANGE_LAYER
; Z_HEIGHT: 10.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X116.066 Y109.23 E-.61834
G1 X116.33 Y108.966 E-.14166
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
G1 X133.506 Y118.418
G1 Z10.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F8069
G1 X133.11 Y118.914 E.02107
G3 X127.753 Y107.757 I-5.107 J-4.412 E.88724
G3 X133.552 Y110.639 I.215 J6.842 E.22377
G1 X133.552 Y118.361 E.25613
G1 X133.544 Y118.371 E.00044
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F8069
M204 S6000
G3 X127.764 Y108.149 I-5.157 J-3.72 E.79126
G3 X133.16 Y110.777 I.237 J6.366 E.19203
G1 X133.16 Y118.163 E.22696
; WIPE_START
G1 F12000
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.785 Y119.597 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X139.394 Y119.002 Z10.6 F36000
G1 X140.731 Y118.898 Z10.6
G1 Z10.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F8069
G1 X140.669 Y118.898 E.00205
G3 X130.063 Y127.738 I-12.737 J-4.5 E.48073
G3 X128.078 Y101.103 I-2.062 J-13.238 E1.46736
G3 X140.382 Y109.384 I-.092 J13.417 E.52125
G1 X140.669 Y110.102 E.02565
G1 X142.198 Y110.102 E.05071
G1 X142.198 Y118.898 E.29178
G1 X140.791 Y118.898 E.04668
G1 X140.934 Y119.29 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F8069
M204 S6000
G3 X128.084 Y100.711 I-12.93 J-4.79 E1.84872
G3 X140.935 Y109.71 I-.088 J13.8 E.5127
G1 X142.59 Y109.71 E.05087
G1 X142.59 Y119.29 E.29437
G1 X140.994 Y119.29 E.04903
; WIPE_START
G1 F12000
M204 S10000
G1 X140.494 Y120.337 E-.44107
G1 X140.176 Y120.973 E-.27004
G1 X140.113 Y121.085 E-.04889
; WIPE_END
G1 E-.04 F1800
G1 X141.806 Y114.5 Z10.6 F36000
G1 Z10.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F8069
G1 X141.806 Y113.734 E.02354
G1 X135.374 Y113.734 E.19763
G2 X135.362 Y115.255 I51.305 J1.144 E.04673
G1 X141.806 Y115.266 E.19798
G1 X141.806 Y114.56 E.02169
G1 X141.429 Y114.5 F36000
G1 F8069
G1 X141.429 Y114.111 E.01195
G1 X135.74 Y114.111 E.17481
G1 X135.74 Y114.889 E.0239
G1 X141.429 Y114.889 E.17481
G1 X141.429 Y114.56 E.01011
G1 X136.128 Y114.5 F36000
; LINE_WIDTH: 0.44364
G1 F8069
G1 X140.98 Y114.5 E.15842
G1 X132.791 Y119.734 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F8069
G2 X133.871 Y118.519 I-5.726 J-6.178 E.05401
G1 X138.105 Y122.753 E.19861
G3 X133.844 Y126.168 I-10.412 J-8.626 E.18239
G1 X129.178 Y121.502 E.21887
G3 X126.825 Y121.499 I-1.163 J-10.106 E.07822
G1 X122.156 Y126.168 E.21902
G3 X117.895 Y122.753 I5.929 J-11.764 E.18246
G1 X122.142 Y118.506 E.19923
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.66 E.2189
G1 X115.502 Y110.756 F36000
G1 F8069
G3 X116.066 Y109.23 I14.679 J4.561 E.054
G1 X122.736 Y102.56 E.31291
G3 X124.865 Y101.837 I5.468 J12.61 E.07465
G1 X131.182 Y108.154 E.29633
G3 X132.006 Y108.642 I-3.879 J7.48 E.03179
G1 X136.251 Y104.397 E.19918
G3 X137.445 Y105.502 I-8.997 J10.909 E.054
; WIPE_START
G1 F15476.087
G1 X136.251 Y104.397 E-.61826
G1 X135.988 Y104.66 E-.14174
; WIPE_END
G1 E-.04 F1800
G1 X128.886 Y107.458 Z10.6 F36000
G1 X122.552 Y109.953 Z10.6
G1 Z10.2
G1 E.8 F1800
G1 F8069
G2 X121.661 Y111.311 I8.508 J6.556 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I12.97 J-3.181 E.08975
G1 X127.537 Y127.537 E.58997
G2 X128.463 Y127.537 I.462 J-8.965 E.0307
G1 X140.342 Y115.658 E.55729
G1 X138.686 Y115.658 E.05493
G1 X141.578 Y118.55 E.13565
G1 X140.437 Y118.55 E.03784
G1 X140.249 Y119 E.01617
; WIPE_START
G1 F15476.087
G1 X140.437 Y118.55 E-.18529
G1 X141.578 Y118.55 E-.43347
G1 X141.315 Y118.287 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X134.66 Y114.549 Z10.6 F36000
G1 X118.554 Y105.502 Z10.6
G1 Z10.2
G1 E.8 F1800
G1 F8069
G3 X119.748 Y104.396 I9.732 J9.302 E.05401
G1 X123.992 Y108.64 E.19912
G3 X124.816 Y108.156 I3.541 J5.082 E.03174
G1 X131.136 Y101.836 E.29649
G3 X133.265 Y102.562 I-5.363 J19.219 E.07466
G1 X139.926 Y109.222 E.31247
G1 X140.437 Y110.45 E.04411
G1 X141.154 Y110.45 E.02379
G1 X141.85 Y111.146 E.03263
G1 X141.85 Y113.342 E.07285
G1 X136.37 Y113.342 E.18178
G1 X133.9 Y110.872 E.11585
G1 X133.9 Y114.424 E.1178
G1 X139.664 Y108.66 E.2704
; CHANGE_LAYER
; Z_HEIGHT: 10.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X138.25 Y110.074 E-.76
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
G1 X133.506 Y118.418
G1 Z10.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F7153
G1 X133.11 Y118.914 E.02107
G3 X127.738 Y107.757 I-5.103 J-4.415 E.88621
G3 X133.552 Y110.639 I.241 J6.82 E.22434
G1 X133.552 Y118.361 E.25613
G1 X133.544 Y118.371 E.00044
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F7153
M204 S6000
G3 X127.749 Y108.149 I-5.156 J-3.721 E.7907
G3 X133.16 Y110.777 I.241 J6.388 E.19244
G1 X133.16 Y118.163 E.22696
; WIPE_START
G1 F12000
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
M73 P91 R2
G1 E-.04 F1800
G1 X139.399 Y119.003 Z10.8 F36000
G1 X140.731 Y118.898 Z10.8
G1 Z10.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F7153
G1 X140.669 Y118.898 E.00205
G3 X130.063 Y127.738 I-12.739 J-4.501 E.48072
G3 X128.071 Y101.103 I-2.062 J-13.238 E1.46713
G3 X140.384 Y109.39 I-.085 J13.417 E.5217
G1 X140.669 Y110.102 E.02544
G1 X142.198 Y110.102 E.05071
G1 X142.198 Y118.898 E.29178
G1 X140.791 Y118.898 E.04668
G1 X140.934 Y119.29 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F7153
M204 S6000
G3 X139.265 Y122.447 I-12.999 J-4.856 E.11003
G3 X134.52 Y126.646 I-11.264 J-7.947 E.19644
G3 X128.077 Y100.711 I-6.521 J-12.148 E1.542
G3 X140.935 Y109.71 I-.081 J13.8 E.51293
G1 X142.59 Y109.71 E.05087
G1 X142.59 Y119.29 E.29437
G1 X140.994 Y119.29 E.04903
M204 S10000
G1 X140.249 Y119 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F7153
G1 X140.437 Y118.55 E.01617
G1 X141.578 Y118.55 E.03785
G1 X133.9 Y110.872 E.36015
G1 X133.9 Y114.424 E.1178
G1 X139.664 Y108.66 E.2704
G1 X137.445 Y105.502 F36000
G1 F7153
G2 X136.252 Y104.397 I-10.145 J9.754 E.054
G1 X132.006 Y108.642 E.19918
G2 X131.182 Y108.154 I-8.309 J13.074 E.03178
G1 X124.865 Y101.837 E.29633
G2 X122.736 Y102.56 I3.337 J13.326 E.07465
G1 X116.066 Y109.23 E.3129
G2 X115.502 Y110.756 I13.955 J6.029 E.054
G1 X116.335 Y108.66 F36000
G1 F7153
G1 X121.002 Y113.326 E.2189
G2 X122.148 Y118.5 I6.952 J1.175 E.18024
G1 X117.895 Y122.753 E.19949
G2 X122.156 Y126.168 I10.19 J-8.349 E.18246
G1 X126.828 Y121.496 E.21914
G2 X129.178 Y121.502 I1.196 J-8.535 E.07821
G1 X133.844 Y126.168 E.21887
G2 X138.105 Y122.753 I-6.133 J-12.02 E.1824
G1 X133.871 Y118.519 E.19861
G3 X132.791 Y119.734 I-6.806 J-4.963 E.05401
; WIPE_START
G1 F15476.087
G1 X133.374 Y119.142 E-.31579
G1 X133.871 Y118.519 E-.30276
G1 X134.134 Y118.782 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X128.07 Y114.147 Z10.8 F36000
G1 X122.564 Y109.939 Z10.8
G1 Z10.4
G1 E.8 F1800
G1 F7153
G2 X121.675 Y111.297 I6.812 J5.431 E.05394
G1 X115.336 Y117.636 E.29737
G3 X114.961 Y114.961 I12.97 J-3.181 E.08975
G1 X127.537 Y127.537 E.58997
G2 X128.463 Y127.537 I.463 J-8.961 E.0307
G1 X141.85 Y114.15 E.62802
G1 X141.85 Y111.146 E.09966
G1 X141.154 Y110.45 E.03263
G1 X140.437 Y110.45 E.02379
G1 X139.926 Y109.222 E.04412
G1 X133.265 Y102.561 E.31248
G2 X131.136 Y101.836 I-7.487 J18.488 E.07465
G1 X124.816 Y108.156 E.29648
G2 X123.992 Y108.64 I2.721 J5.573 E.03174
G1 X119.748 Y104.396 E.19912
G2 X118.554 Y105.502 I8.539 J10.409 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 10.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15476.087
G1 X119.748 Y104.396 E-.61828
G1 X120.011 Y104.66 E-.14172
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
G1 X133.552 Y118.287
G1 Z10.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F8096
G1 X133.552 Y118.361 E.00243
G1 X133.11 Y118.914 E.02349
G3 X121.452 Y116.13 I-5.107 J-4.415 E.48925
G3 X127.723 Y107.758 I6.549 J-1.629 E.39701
G3 X133.552 Y110.639 I.245 J6.841 E.22478
G1 X133.552 Y118.227 E.25171
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F8096
M204 S6000
G3 X127.734 Y108.15 I-5.157 J-3.721 E.79035
G3 X133.16 Y110.777 I.267 J6.366 E.19297
G1 X133.16 Y118.163 E.22696
; WIPE_START
G1 F12000
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X139.399 Y119.003 Z11 F36000
G1 X140.731 Y118.898 Z11
G1 Z10.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F8096
G1 X140.669 Y118.898 E.00206
G3 X130.063 Y127.738 I-12.736 J-4.498 E.48073
G3 X128.064 Y101.103 I-2.062 J-13.238 E1.4669
G3 X140.387 Y109.396 I-.063 J13.396 E.52228
G1 X140.669 Y110.102 E.02521
G1 X142.198 Y110.102 E.05072
G1 X142.198 Y118.898 E.29178
G1 X140.791 Y118.898 E.04668
G1 X140.934 Y119.29 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
M73 P91 R1
G1 F8096
M204 S6000
G3 X134.545 Y126.633 I-12.973 J-4.837 E.3056
G3 X128.07 Y100.711 I-6.546 J-12.134 E1.54267
G3 X140.934 Y109.71 I-.087 J13.819 E.51305
G1 X142.59 Y109.71 E.05087
G1 X142.59 Y119.29 E.29437
G1 X140.994 Y119.29 E.04903
; WIPE_START
G1 F12000
M204 S10000
G1 X140.493 Y120.338 E-.44157
G1 X140.176 Y120.974 E-.27009
G1 X140.113 Y121.085 E-.04834
; WIPE_END
G1 E-.04 F1800
G1 X132.791 Y119.734 Z11 F36000
G1 Z10.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F8096
G2 X133.871 Y118.519 I-5.726 J-6.178 E.05401
G1 X137.836 Y122.484 E.18601
G3 X137.438 Y122.94 I-3.647 J-2.782 E.02009
G1 X137.705 Y123.207 E.01253
G3 X133.844 Y126.168 I-10.152 J-9.244 E.16226
G1 X129.178 Y121.502 E.21887
G3 X126.825 Y121.499 I-1.165 J-8.682 E.07828
G1 X122.156 Y126.168 E.21902
G3 X117.895 Y122.753 I5.928 J-11.763 E.18246
G1 X122.142 Y118.506 E.19922
G3 X121.002 Y113.326 I5.861 J-4.006 E.18033
G1 X116.335 Y108.66 E.2189
G1 X115.502 Y110.756 F36000
G1 F8096
G3 X116.067 Y109.23 I14.316 J4.429 E.054
G1 X122.736 Y102.56 E.31289
G3 X124.865 Y101.837 I5.462 J12.587 E.07466
G1 X131.182 Y108.154 E.29634
G3 X132.006 Y108.642 I-3.882 J7.486 E.03179
G1 X136.251 Y104.397 E.19918
G3 X137.445 Y105.502 I-8.875 J10.778 E.054
G1 X139.236 Y107.904 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.383478
G1 F3000;_EXTRUDE_SET_SPEED
G3 X139.822 Y109.01 I-14.889 J8.593 E.03472
G1 X140.386 Y110.367 E.04079
G2 X140.533 Y110.465 I.114 J-.012 E.00559
G1 X141.676 Y110.465 E.03171
G1 X141.808 Y110.492 E.00374
G1 X141.835 Y110.624 E.00374
G1 X141.835 Y118.376 E.21513
G1 X141.808 Y118.508 E.00374
G1 X141.676 Y118.535 E.00374
G1 X140.533 Y118.535 E.03172
G2 X140.386 Y118.633 I-.033 J.11 E.00559
G1 X139.808 Y120.021 E.04172
G3 X137.978 Y122.877 I-13.092 J-6.375 E.09435
; Slow Down End
; WIPE_START
G1 X138.66 Y121.986 E-.42631
G1 X139.141 Y121.252 E-.33369
; WIPE_END
G1 E-.04 F1800
G1 X132.833 Y116.955 Z11 F36000
G1 X122.552 Y109.953 Z11
G1 Z10.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F8096
G2 X121.661 Y111.311 I8.5 J6.55 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I12.967 J-3.18 E.08975
G1 X127.537 Y127.537 E.58997
G2 X128.463 Y127.537 I.462 J-8.965 E.0307
G1 X141.473 Y114.527 E.61032
G1 X141.473 Y118.173 E.12091
G1 X141.2 Y118.173 E.00903
G1 X133.9 Y110.872 E.34246
G1 X133.9 Y114.424 E.1178
G1 X139.383 Y108.941 E.2572
G2 X139.101 Y108.397 I-6.204 J2.871 E.02033
G1 X133.265 Y102.561 E.27379
G2 X131.136 Y101.836 I-7.479 J18.477 E.07463
G1 X124.816 Y108.156 E.29648
G2 X123.992 Y108.64 I2.717 J5.566 E.03174
G1 X119.748 Y104.396 E.19912
G2 X118.554 Y105.502 I8.546 J10.417 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 10.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X119.748 Y104.396 E-.61828
G1 X120.011 Y104.66 E-.14172
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
G1 X133.552 Y118.287
G1 Z10.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X133.552 Y118.361 E.00243
G1 X133.11 Y118.914 E.0235
G3 X127.707 Y107.758 I-5.107 J-4.413 E.88574
G3 X133.552 Y110.639 I.26 J6.841 E.22528
G1 X133.552 Y118.227 E.25171
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.719 Y108.15 I-5.157 J-3.721 E.78989
G3 X133.16 Y110.777 I.282 J6.366 E.19343
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.2295
G1 X132.479 Y119.016 E-.18626
G1 X132.117 Y119.348 E-.1864
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X139.399 Y119.003 Z11.2 F36000
G1 X140.731 Y118.898 Z11.2
G1 Z10.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.669 Y118.898 E.00206
G3 X129.378 Y127.827 I-12.729 J-4.494 E.50361
G1 X129.135 Y127.846 E.0081
G3 X128.056 Y101.103 I-1.135 J-13.347 E1.43553
G3 X140.389 Y109.402 I-.055 J13.396 E.52274
G1 X140.669 Y110.102 E.02499
G1 X142.198 Y110.102 E.05072
G1 X142.198 Y118.898 E.29178
G1 X140.791 Y118.898 E.04668
G1 X140.934 Y119.29 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X128.062 Y100.711 I-12.93 J-4.79 E1.84805
G3 X140.934 Y109.71 I-.08 J13.819 E.51327
G1 X142.59 Y109.71 E.05087
G1 X142.59 Y119.29 E.29437
G1 X140.994 Y119.29 E.04903
; WIPE_START
M204 S10000
G1 X140.493 Y120.339 E-.44192
G1 X140.175 Y120.975 E-.27001
G1 X140.113 Y121.085 E-.04807
; WIPE_END
G1 E-.04 F1800
G1 X142.031 Y118.183 Z11.2 F36000
G1 Z10.8
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.40862
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X141.686 Y118.528 E.02608
G1 X141.037 Y118.528 E.03465
G1 X141.828 Y117.737 E.05979
G1 X141.828 Y117.088 E.03465
G1 X137.01 Y121.906 E.36404
G1 X137.335 Y122.23 E.0245
G1 X139.983 Y119.582 E.20011
G3 X139.38 Y120.834 I-10.374 J-4.227 E.07428
G1 X137.516 Y122.698 E.14086
G1 X136.543 Y121.725 F36000
G1 F3000
G1 X141.828 Y116.44 E.39937
G1 X141.828 Y115.791 E.03465
G1 X136.362 Y121.258 E.41305
G1 X136.261 Y121.157 E.0076
G1 X140.099 Y117.319 E.29001
G1 X139.876 Y117.095 E.01691
G1 X141.828 Y115.143 E.14755
G1 X141.828 Y114.494 E.03465
G1 X139.551 Y116.771 E.17205
G1 X139.227 Y116.447 E.0245
G1 X141.828 Y113.845 E.19656
G1 X141.828 Y113.197 E.03465
G1 X138.903 Y116.122 E.22106
G1 X138.578 Y115.798 E.0245
G1 X141.828 Y112.548 E.24557
G1 X141.828 Y111.9 E.03465
G1 X138.254 Y115.474 E.27007
G1 X137.93 Y115.15 E.0245
G1 X141.828 Y111.251 E.29457
G1 X141.828 Y110.603 E.03465
G1 X137.605 Y114.825 E.31908
G1 X137.281 Y114.501 E.0245
G1 X141.31 Y110.472 E.30445
G1 X140.662 Y110.472 E.03465
G1 X136.957 Y114.177 E.27995
G1 X136.633 Y113.852 E.0245
G1 X140.302 Y110.183 E.27727
G1 X140.112 Y109.725 E.02651
G1 X136.308 Y113.528 E.28738
G1 X135.984 Y113.204 E.0245
G1 X139.921 Y109.267 E.29749
G2 X139.72 Y108.819 I-3.462 J1.288 E.02623
G1 X135.66 Y112.879 E.30679
G1 X135.335 Y112.555 E.0245
G1 X139.503 Y108.387 E.31494
G1 X139.27 Y107.972 E.02545
G1 X134.868 Y112.374 E.33264
G1 X133.9 Y112.501 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
; LAYER_HEIGHT: 0.2
G1 F15476.087
G1 X133.9 Y110.872 E.05401
G1 X134.829 Y111.801 E.04356
M73 P92 R1
G1 X134.402 Y112.228 E.02003
G1 X135.249 Y113.075 E.03974
G1 X133.9 Y114.424 E.06327
G1 X133.871 Y118.519 E.13586
G1 X136.082 Y120.73 E.10372
G1 X139.493 Y117.319 E.16002
G1 X139.087 Y116.913 E.01905
G1 X128.463 Y127.537 E.49842
G3 X127.537 Y127.537 I-.463 J-8.961 E.0307
G1 X114.961 Y114.961 E.58997
G2 X115.336 Y117.636 I13.343 J-.506 E.08975
G1 X121.673 Y111.299 E.29729
G3 X122.563 Y109.941 I7.919 J4.216 E.05394
G1 X118.554 Y105.502 F36000
G1 F15476.087
G3 X119.748 Y104.396 I9.733 J9.304 E.05401
G1 X123.992 Y108.64 E.19911
G3 X124.816 Y108.156 I3.54 J5.081 E.03174
G1 X131.136 Y101.836 E.29648
G3 X133.264 Y102.56 I-5.345 J19.193 E.07461
G1 X138.667 Y107.963 E.25345
G1 X139.054 Y107.576 E.01817
G2 X136.252 Y104.397 I-11.038 J6.905 E.14121
G1 X132.006 Y108.642 E.19918
G2 X131.182 Y108.154 I-4.705 J6.996 E.03179
G1 X124.865 Y101.837 E.29634
G2 X122.736 Y102.56 I3.332 J13.305 E.07466
G1 X116.067 Y109.23 E.31288
G2 X115.502 Y110.756 I13.556 J5.883 E.054
G1 X116.335 Y108.66 F36000
G1 F15476.087
G1 X121.002 Y113.326 E.2189
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X117.895 Y122.753 E.19922
G2 X122.156 Y126.168 I10.189 J-8.348 E.18246
G1 X126.825 Y121.499 E.21902
G2 X129.178 Y121.502 I1.188 J-8.679 E.07828
G1 X133.844 Y126.168 E.21887
G2 X135.248 Y125.346 I-8.721 J-16.524 E.054
; CHANGE_LAYER
; Z_HEIGHT: 11
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X133.844 Y126.168 E-.61841
G1 X133.58 Y125.904 E-.14159
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
G1 X133.506 Y118.418
G1 Z11
G1 E.8 F1800
; FEATURE: Inner wall
G1 F7779
G1 X133.11 Y118.914 E.02107
G3 X121.459 Y116.16 I-5.107 J-4.418 E.48818
G3 X127.692 Y107.759 I6.543 J-1.658 E.39701
G3 X133.552 Y110.639 I.275 J6.841 E.22579
G1 X133.552 Y118.361 E.25612
G1 X133.544 Y118.371 E.00044
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F7779
M204 S6000
G3 X127.703 Y108.15 I-5.156 J-3.721 E.78932
G3 X133.16 Y110.777 I.291 J6.378 E.19387
G1 X133.16 Y118.163 E.22696
; WIPE_START
G1 F12000
M204 S10000
G1 X132.813 Y118.658 E-.2295
G1 X132.479 Y119.016 E-.18626
G1 X132.117 Y119.348 E-.1864
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X139.399 Y119.003 Z11.4 F36000
G1 X140.731 Y118.898 Z11.4
G1 Z11
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F7779
G1 X140.668 Y118.898 E.00206
G3 X129.378 Y127.827 I-12.729 J-4.492 E.50361
G3 X128.049 Y101.103 I-1.377 J-13.326 E1.44353
G3 X140.392 Y109.41 I-.05 J13.399 E.52323
G1 X140.669 Y110.102 E.02473
G1 X142.198 Y110.102 E.05073
G1 X142.198 Y118.898 E.29178
G1 X140.791 Y118.898 E.04668
G1 X140.934 Y119.29 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F7779
M204 S6000
G3 X128.055 Y100.711 I-12.93 J-4.79 E1.84783
G3 X140.934 Y109.71 I-.076 J13.825 E.51347
G1 X142.59 Y109.71 E.05087
G1 X142.59 Y119.29 E.29437
G1 X140.994 Y119.29 E.04903
; WIPE_START
G1 F12000
M204 S10000
G1 X140.492 Y120.34 E-.44226
G1 X140.175 Y120.976 E-.26995
G1 X140.113 Y121.085 E-.04779
; WIPE_END
G1 E-.04 F1800
G1 X132.791 Y119.734 Z11.4 F36000
G1 Z11
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F7779
G2 X133.871 Y118.519 I-5.723 J-6.176 E.05401
G1 X138.105 Y122.753 E.19861
G3 X133.844 Y126.168 I-10.338 J-8.534 E.18241
G1 X129.178 Y121.502 E.21887
G3 X126.825 Y121.499 I-1.165 J-8.683 E.07828
G1 X122.156 Y126.168 E.21902
G3 X117.895 Y122.753 I5.928 J-11.763 E.18246
G1 X122.142 Y118.506 E.19922
G3 X121.002 Y113.326 I5.863 J-4.007 E.18033
G1 X116.335 Y108.66 E.2189
G1 X115.502 Y110.756 F36000
G1 F7779
G3 X116.067 Y109.23 I14.004 J4.314 E.054
G1 X122.736 Y102.56 E.31288
G3 X124.865 Y101.837 I5.46 J12.577 E.07466
G1 X131.182 Y108.154 E.29634
G3 X132.006 Y108.642 I-3.881 J7.484 E.03179
G1 X136.252 Y104.397 E.19919
G3 X137.445 Y105.502 I-8.865 J10.767 E.054
G1 X139.379 Y108.159 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.407765
G1 F7779
G1 X139.554 Y108.557 E.01295
; LINE_WIDTH: 0.457455
G1 X139.73 Y108.956 E.01471
; LINE_WIDTH: 0.50622
G1 X139.98 Y109.583 E.02549
; LINE_WIDTH: 0.54531
G1 X140.279 Y110.37 E.03447
G1 X140.3 Y110.426 F36000
; LINE_WIDTH: 0.541547
G1 F7779
G1 X140.312 Y110.539 E.0046
; LINE_WIDTH: 0.49844
G1 X140.324 Y110.652 E.0042
; LINE_WIDTH: 0.455334
G1 X140.336 Y110.764 E.00381
; LINE_WIDTH: 0.420848
G3 X140.852 Y115.445 I-12.656 J3.763 E.14579
G3 X140.338 Y118.235 I-14.017 J-1.139 E.08752
; LINE_WIDTH: 0.458015
G1 X140.327 Y118.345 E.00376
; LINE_WIDTH: 0.501225
G1 X140.316 Y118.456 E.00415
; LINE_WIDTH: 0.544435
G1 X140.305 Y118.566 E.00454
G1 X140.381 Y118.543 E.00324
; LINE_WIDTH: 0.501225
G1 X140.457 Y118.52 E.00296
; LINE_WIDTH: 0.458015
G1 X140.533 Y118.498 E.00268
; LINE_WIDTH: 0.42065
G2 X141.806 Y118.506 I.938 J-46.753 E.03919
G1 X141.806 Y110.494 E.2466
G2 X140.531 Y110.501 I-.492 J26.982 E.03925
; LINE_WIDTH: 0.455334
G1 X140.473 Y110.482 E.00204
; LINE_WIDTH: 0.49844
G1 X140.415 Y110.464 E.00225
; LINE_WIDTH: 0.541547
G1 X140.357 Y110.445 E.00247
G1 X140.826 Y110.924 F36000
; LINE_WIDTH: 0.503375
G1 F7779
G1 X140.965 Y111.561 E.02449
; LINE_WIDTH: 0.465515
G1 X141.013 Y111.886 E.01129
; LINE_WIDTH: 0.432325
G1 X141.062 Y112.21 E.01041
; LINE_WIDTH: 0.390975
G1 X141.134 Y112.859 E.01852
; LINE_WIDTH: 0.337283
G3 X141.207 Y114.16 I-17.621 J1.641 E.03127
; LINE_WIDTH: 0.329357
G3 X141.137 Y116.11 I-19.882 J.259 E.04556
; LINE_WIDTH: 0.38803
G1 X141.065 Y116.759 E.01835
; LINE_WIDTH: 0.42848
G1 X141.018 Y117.082 E.01027
; LINE_WIDTH: 0.46096
G1 X140.97 Y117.406 E.01114
; LINE_WIDTH: 0.508965
G1 X140.834 Y118.049 E.02496
G1 X140.855 Y118.076 E.00134
G1 X141.376 Y118.076 E.01979
G1 X141.398 Y117.488 E.02235
; LINE_WIDTH: 0.4651
G1 X141.415 Y117.156 E.01146
; LINE_WIDTH: 0.43198
G1 X141.431 Y116.823 E.01056
; LINE_WIDTH: 0.390685
G1 X141.456 Y116.16 E.01879
; LINE_WIDTH: 0.332537
G2 X141.457 Y112.87 I-55.571 J-1.661 E.07768
; LINE_WIDTH: 0.388315
G1 X141.433 Y112.21 E.01857
; LINE_WIDTH: 0.428815
G1 X141.416 Y111.879 E.01043
; LINE_WIDTH: 0.461365
G1 X141.4 Y111.548 E.01131
; LINE_WIDTH: 0.516549
G3 X141.376 Y110.924 I5.08 J-.504 E.02412
G1 X140.886 Y110.924 E.01893
G1 X139.386 Y120.842 F36000
; LINE_WIDTH: 0.40755
G1 F7779
G1 X139.569 Y120.42 E.01367
; LINE_WIDTH: 0.45681
G1 X139.752 Y119.998 E.01551
; LINE_WIDTH: 0.50165
G1 X140.017 Y119.31 E.02756
; LINE_WIDTH: 0.54207
G1 X140.282 Y118.622 E.02999
; WIPE_START
G1 F12000
G1 X140.017 Y119.31 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.599 Y115.18 Z11.4 F36000
G1 X118.554 Y105.502 Z11.4
G1 Z11
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F7779
G3 X119.748 Y104.396 I9.727 J9.298 E.05401
G1 X123.992 Y108.64 E.19911
G3 X124.816 Y108.156 I3.541 J5.082 E.03174
G1 X131.136 Y101.836 E.29648
G3 X133.264 Y102.56 I-5.336 J19.175 E.07459
G1 X139.067 Y108.363 E.27222
G1 X139.303 Y109.021 E.0232
G1 X133.9 Y114.424 E.25345
G1 X133.9 Y110.872 E.1178
G1 X140.203 Y117.175 E.29566
G2 X140.447 Y115.553 I-13.042 J-2.795 E.05445
G1 X128.463 Y127.537 E.56223
G3 X127.537 Y127.537 I-.463 J-8.968 E.0307
G1 X114.961 Y114.961 E.58997
G2 X115.336 Y117.636 I13.339 J-.505 E.08974
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.393 J5.194 E.05392
; CHANGE_LAYER
; Z_HEIGHT: 11.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X122.054 Y110.618 E-.31584
G1 X121.661 Y111.311 E-.30252
G1 X121.398 Y111.574 E-.14165
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
G1 X133.552 Y118.287
G1 Z11.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F7835
G1 X133.552 Y118.361 E.00243
G1 X133.11 Y118.914 E.02349
G3 X127.677 Y107.759 I-5.109 J-4.412 E.88492
G3 X133.552 Y110.639 I.29 J6.841 E.22629
G1 X133.552 Y118.227 E.25171
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F7835
M204 S6000
G3 X127.688 Y108.151 I-5.156 J-3.722 E.78886
G3 X133.16 Y110.777 I.305 J6.378 E.19434
G1 X133.16 Y118.163 E.22696
; WIPE_START
G1 F12000
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15786
; WIPE_END
G1 E-.04 F1800
G1 X139.399 Y119.003 Z11.6 F36000
G1 X140.731 Y118.898 Z11.6
G1 Z11.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F7835
G1 X140.668 Y118.898 E.00207
G3 X129.378 Y127.827 I-12.728 J-4.491 E.50361
G3 X128.042 Y101.103 I-1.377 J-13.326 E1.4433
G3 X140.395 Y109.415 I-.06 J13.424 E.52356
G1 X140.668 Y110.102 E.02452
G1 X142.198 Y110.102 E.05073
G1 X142.198 Y118.898 E.29178
G1 X140.791 Y118.898 E.04669
G1 X140.934 Y119.29 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F7835
M204 S6000
G3 X128.048 Y100.711 I-12.93 J-4.79 E1.84761
G3 X140.934 Y109.71 I-.059 J13.811 E.51377
G1 X142.59 Y109.71 E.05088
G1 X142.59 Y119.29 E.29437
G1 X140.994 Y119.29 E.04903
; WIPE_START
G1 F12000
M204 S10000
G1 X140.492 Y120.341 E-.44252
G1 X140.175 Y120.976 E-.26996
G1 X140.113 Y121.085 E-.04752
; WIPE_END
G1 E-.04 F1800
G1 X139.68 Y113.465 Z11.6 F36000
G1 X139.379 Y108.159 Z11.6
G1 Z11.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.399604
G1 F7835
G1 X139.496 Y108.427 E.0085
; LINE_WIDTH: 0.43297
G1 X139.614 Y108.694 E.0093
; LINE_WIDTH: 0.466337
G1 X139.732 Y108.962 E.0101
; LINE_WIDTH: 0.50677
G1 X139.983 Y109.589 E.02551
; LINE_WIDTH: 0.54538
G1 X140.278 Y110.369 E.03415
G1 X141.806 Y111.164 F36000
; LINE_WIDTH: 0.420985
G1 F7835
G1 X141.806 Y110.494 E.02065
G2 X140.531 Y110.501 I-.492 J28.152 E.0393
; LINE_WIDTH: 0.454689
G1 X140.454 Y110.476 E.00271
; LINE_WIDTH: 0.497605
G1 X140.377 Y110.451 E.00299
; LINE_WIDTH: 0.540522
G1 X140.3 Y110.426 E.00327
G1 X140.312 Y110.539 E.00459
; LINE_WIDTH: 0.497605
G1 X140.324 Y110.652 E.00419
; LINE_WIDTH: 0.454689
G1 X140.335 Y110.764 E.0038
; LINE_WIDTH: 0.420828
G3 X140.852 Y115.445 I-12.647 J3.763 E.14579
G3 X140.338 Y118.235 I-14.019 J-1.139 E.08752
; LINE_WIDTH: 0.458025
G1 X140.327 Y118.345 E.00375
; LINE_WIDTH: 0.501175
G1 X140.316 Y118.456 E.00414
; LINE_WIDTH: 0.544325
G1 X140.305 Y118.566 E.00453
G1 X140.381 Y118.543 E.00324
; LINE_WIDTH: 0.501175
G1 X140.457 Y118.52 E.00296
; LINE_WIDTH: 0.458025
G1 X140.532 Y118.498 E.00268
; LINE_WIDTH: 0.420571
G2 X141.806 Y118.506 I.938 J-46.656 E.03919
G1 X141.806 Y111.224 E.22408
G1 X141.376 Y111.164 F36000
; LINE_WIDTH: 0.515029
G1 F7835
G1 X141.376 Y110.924 E.00927
G1 X140.826 Y110.924 E.02118
G1 X140.965 Y111.561 E.02511
; LINE_WIDTH: 0.465515
G1 X141.013 Y111.886 E.01129
; LINE_WIDTH: 0.432325
G1 X141.062 Y112.21 E.01041
; LINE_WIDTH: 0.390975
G1 X141.134 Y112.859 E.01852
; LINE_WIDTH: 0.337283
G3 X141.207 Y114.16 I-17.621 J1.641 E.03127
; LINE_WIDTH: 0.329357
G3 X141.137 Y116.11 I-19.882 J.259 E.04556
; LINE_WIDTH: 0.38803
G1 X141.065 Y116.759 E.01835
; LINE_WIDTH: 0.42848
G1 X141.018 Y117.082 E.01027
; LINE_WIDTH: 0.46096
G1 X140.97 Y117.406 E.01114
; LINE_WIDTH: 0.508965
G1 X140.834 Y118.049 E.02496
G1 X140.855 Y118.076 E.00134
G1 X141.376 Y118.076 E.01979
G1 X141.398 Y117.488 E.02235
; LINE_WIDTH: 0.4651
G1 X141.415 Y117.156 E.01146
; LINE_WIDTH: 0.43198
G1 X141.431 Y116.823 E.01056
; LINE_WIDTH: 0.390685
G1 X141.456 Y116.16 E.01879
; LINE_WIDTH: 0.332537
G2 X141.457 Y112.87 I-55.571 J-1.661 E.07768
; LINE_WIDTH: 0.388315
G1 X141.433 Y112.21 E.01857
; LINE_WIDTH: 0.428815
G1 X141.416 Y111.879 E.01043
; LINE_WIDTH: 0.461365
G1 X141.4 Y111.548 E.01131
; LINE_WIDTH: 0.50114
G1 X141.38 Y111.224 E.0121
G1 X139.386 Y120.842 F36000
; LINE_WIDTH: 0.407535
G1 F7835
G1 X139.569 Y120.42 E.01365
; LINE_WIDTH: 0.456765
G1 X139.752 Y119.999 E.0155
; LINE_WIDTH: 0.50157
G1 X140.017 Y119.31 E.02757
; LINE_WIDTH: 0.54195
G1 X140.282 Y118.622 E.03
G1 X137.445 Y105.502 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F7835
G2 X136.252 Y104.396 I-10.009 J9.607 E.054
G1 X132.006 Y108.642 E.19919
G2 X131.182 Y108.154 I-4.703 J6.991 E.03179
G1 X124.865 Y101.837 E.29634
G2 X122.736 Y102.56 I3.329 J13.291 E.07467
G1 X116.067 Y109.229 E.31287
G2 X115.502 Y110.755 I13.289 J5.786 E.054
G1 X116.335 Y108.66 F36000
G1 F7835
G1 X121.002 Y113.326 E.2189
G2 X122.142 Y118.506 I7.009 J1.173 E.18032
G1 X117.895 Y122.753 E.19922
G2 X122.156 Y126.168 I10.188 J-8.347 E.18246
G1 X126.825 Y121.499 E.21902
G2 X129.178 Y121.502 I1.188 J-8.679 E.07828
G1 X133.844 Y126.168 E.21887
G2 X138.105 Y122.753 I-6.058 J-11.925 E.18242
G1 X133.871 Y118.519 E.19861
G3 X132.791 Y119.734 I-6.805 J-4.962 E.05401
; WIPE_START
G1 F15476.087
G1 X133.374 Y119.142 E-.31575
G1 X133.871 Y118.519 E-.3028
G1 X134.134 Y118.782 E-.14145
; WIPE_END
G1 E-.04 F1800
G1 X128.064 Y114.155 Z11.6 F36000
G1 X122.552 Y109.953 Z11.6
G1 Z11.2
G1 E.8 F1800
G1 F7835
G2 X121.661 Y111.311 I8.505 J6.554 E.05392
G1 X115.336 Y117.636 E.29673
G3 X114.961 Y114.961 I12.962 J-3.18 E.08974
G1 X127.537 Y127.537 E.58997
G2 X128.463 Y127.537 I.463 J-8.972 E.0307
G1 X140.447 Y115.553 E.56223
G3 X140.203 Y117.175 I-13.286 J-1.173 E.05445
G1 X133.9 Y110.872 E.29566
G1 X133.9 Y114.424 E.1178
G1 X139.303 Y109.021 E.25345
G1 X139.067 Y108.363 E.0232
G1 X133.264 Y102.56 E.27221
G2 X131.136 Y101.836 I-7.43 J18.349 E.0746
G1 X124.816 Y108.156 E.29647
G2 X123.992 Y108.64 I2.717 J5.566 E.03174
G1 X119.748 Y104.396 E.19911
G2 X118.554 Y105.502 I8.538 J10.41 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 11.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X119.748 Y104.396 E-.61828
G1 X120.011 Y104.66 E-.14172
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
G1 X133.552 Y118.287
G1 Z11.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F7832
G1 X133.552 Y118.361 E.00243
G1 X133.11 Y118.914 E.02349
G3 X124.245 Y108.892 I-5.107 J-4.414 E.7634
G3 X127.662 Y107.759 I3.724 J5.515 E.1209
G3 X133.552 Y110.639 I.304 J6.84 E.2268
G1 X133.552 Y118.227 E.25171
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F7832
M204 S6000
G3 X127.673 Y108.151 I-5.154 J-3.723 E.78812
G3 X133.16 Y110.777 I.314 J6.39 E.19478
G1 X133.16 Y118.163 E.22696
; WIPE_START
G1 F12000
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X139.399 Y119.003 Z11.8 F36000
G1 X140.73 Y118.898 Z11.8
G1 Z11.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F7832
G1 X140.668 Y118.898 E.00207
G3 X129.378 Y127.827 I-12.727 J-4.49 E.50361
G3 X128.665 Y101.119 I-1.374 J-13.327 E1.46376
G3 X140.397 Y109.421 I-.667 J13.384 E.50322
G1 X140.668 Y110.102 E.0243
G1 X142.198 Y110.102 E.05074
G1 X142.198 Y118.898 E.29178
G1 X140.79 Y118.898 E.04669
G1 X140.934 Y119.29 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
M73 P93 R1
G1 F7832
M204 S6000
G3 X128.685 Y100.727 I-12.931 J-4.79 E1.86732
G3 X140.934 Y109.71 I-.705 J13.805 E.49415
G1 X142.59 Y109.71 E.05088
G1 X142.59 Y119.29 E.29437
G1 X140.994 Y119.29 E.04904
; WIPE_START
G1 F12000
M204 S10000
G1 X140.492 Y120.341 E-.44273
G1 X140.174 Y120.977 E-.27006
G1 X140.113 Y121.085 E-.04721
; WIPE_END
G1 E-.04 F1800
G1 X132.791 Y119.734 Z11.8 F36000
G1 Z11.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F7832
G2 X133.871 Y118.519 I-5.726 J-6.178 E.05401
G1 X138.105 Y122.753 E.19861
G3 X133.844 Y126.168 I-10.188 J-8.347 E.18246
G1 X129.178 Y121.502 E.21887
G3 X126.825 Y121.499 I-1.164 J-8.682 E.07828
G1 X122.156 Y126.168 E.21902
G3 X117.895 Y122.753 I5.927 J-11.762 E.18246
G1 X122.142 Y118.506 E.19922
G3 X121.002 Y113.326 I5.869 J-4.008 E.18032
G1 X116.335 Y108.66 E.2189
G1 X115.502 Y110.755 F36000
G1 F7832
G3 X116.067 Y109.229 I13.675 J4.194 E.054
G1 X122.736 Y102.56 E.31286
G3 X124.865 Y101.837 I5.455 J12.559 E.07467
G1 X131.182 Y108.154 E.29634
G3 X132.006 Y108.642 I-5.64 J10.451 E.03178
G1 X136.251 Y104.397 E.19917
G3 X137.446 Y105.501 I-8.521 J10.417 E.05401
G1 X139.379 Y108.159 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39972
G1 F7832
G1 X139.497 Y108.429 E.00857
; LINE_WIDTH: 0.43332
G1 X139.616 Y108.698 E.00938
; LINE_WIDTH: 0.46692
G1 X139.735 Y108.968 E.01018
; LINE_WIDTH: 0.50728
G1 X139.985 Y109.595 E.02553
; LINE_WIDTH: 0.54543
G1 X140.278 Y110.369 E.0339
G1 X141.806 Y111.164 F36000
; LINE_WIDTH: 0.420989
G1 F7832
G1 X141.806 Y110.494 E.02065
G2 X140.53 Y110.501 I-.492 J28.096 E.0393
; LINE_WIDTH: 0.45469
G1 X140.454 Y110.476 E.0027
; LINE_WIDTH: 0.49751
G1 X140.377 Y110.451 E.00299
; LINE_WIDTH: 0.54033
G1 X140.3 Y110.426 E.00327
G1 X140.312 Y110.539 E.00458
; LINE_WIDTH: 0.49751
G1 X140.324 Y110.651 E.00419
; LINE_WIDTH: 0.45469
G1 X140.335 Y110.764 E.00379
; LINE_WIDTH: 0.420831
G3 X140.852 Y115.445 I-12.648 J3.764 E.1458
G3 X140.338 Y118.235 I-14.021 J-1.14 E.08753
; LINE_WIDTH: 0.45804
G1 X140.327 Y118.345 E.00375
; LINE_WIDTH: 0.50112
G1 X140.316 Y118.456 E.00414
; LINE_WIDTH: 0.5442
G1 X140.305 Y118.566 E.00453
G1 X140.38 Y118.543 E.00324
; LINE_WIDTH: 0.50112
G1 X140.456 Y118.52 E.00296
; LINE_WIDTH: 0.45804
G1 X140.532 Y118.498 E.00268
; LINE_WIDTH: 0.420573
G2 X141.806 Y118.506 I.938 J-46.564 E.03919
G1 X141.806 Y111.224 E.22408
G1 X141.376 Y111.164 F36000
; LINE_WIDTH: 0.515029
G1 F7832
G1 X141.376 Y110.924 E.00927
G1 X140.826 Y110.924 E.02118
G1 X140.965 Y111.561 E.02511
; LINE_WIDTH: 0.465515
G1 X141.013 Y111.886 E.01129
; LINE_WIDTH: 0.432325
G1 X141.062 Y112.21 E.01041
; LINE_WIDTH: 0.390975
G1 X141.134 Y112.859 E.01852
; LINE_WIDTH: 0.337283
G3 X141.207 Y114.16 I-17.621 J1.641 E.03127
; LINE_WIDTH: 0.329357
G3 X141.137 Y116.11 I-19.882 J.259 E.04556
; LINE_WIDTH: 0.38803
G1 X141.065 Y116.759 E.01835
; LINE_WIDTH: 0.42848
G1 X141.018 Y117.082 E.01027
; LINE_WIDTH: 0.46096
G1 X140.97 Y117.406 E.01114
; LINE_WIDTH: 0.508965
G1 X140.834 Y118.049 E.02496
G1 X140.855 Y118.076 E.00134
G1 X141.376 Y118.076 E.01979
G1 X141.398 Y117.488 E.02235
; LINE_WIDTH: 0.4651
G1 X141.415 Y117.156 E.01146
; LINE_WIDTH: 0.43198
G1 X141.431 Y116.823 E.01056
; LINE_WIDTH: 0.390685
G1 X141.456 Y116.16 E.01879
; LINE_WIDTH: 0.332537
G2 X141.457 Y112.87 I-55.571 J-1.661 E.07768
; LINE_WIDTH: 0.388315
G1 X141.433 Y112.21 E.01857
; LINE_WIDTH: 0.428815
G1 X141.416 Y111.879 E.01043
; LINE_WIDTH: 0.461365
G1 X141.4 Y111.548 E.01131
; LINE_WIDTH: 0.50114
G1 X141.38 Y111.224 E.0121
G1 X139.386 Y120.842 F36000
; LINE_WIDTH: 0.40752
G1 F7832
G1 X139.569 Y120.42 E.01364
; LINE_WIDTH: 0.45672
G1 X139.752 Y119.999 E.01549
; LINE_WIDTH: 0.50148
G1 X140.017 Y119.31 E.02758
; LINE_WIDTH: 0.5418
G1 X140.282 Y118.622 E.03
; WIPE_START
G1 F12000
G1 X140.017 Y119.31 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.598 Y115.181 Z11.8 F36000
G1 X118.554 Y105.502 Z11.8
G1 Z11.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F7832
G3 X119.748 Y104.396 I9.725 J9.298 E.05401
G1 X123.995 Y108.643 E.19925
G3 X124.816 Y108.156 I4.026 J5.847 E.03169
G1 X131.136 Y101.836 E.29647
G3 X133.264 Y102.56 I-3.383 J13.434 E.07464
G1 X139.067 Y108.363 E.27221
G1 X139.303 Y109.021 E.0232
G1 X133.9 Y114.424 E.25345
G1 X133.9 Y110.872 E.1178
G1 X140.203 Y117.175 E.29566
G2 X140.447 Y115.553 I-13.042 J-2.795 E.05445
G1 X128.463 Y127.537 E.56223
G3 X127.537 Y127.537 I-.463 J-8.965 E.0307
G1 X114.961 Y114.961 E.58997
G2 X115.336 Y117.636 I13.338 J-.505 E.08974
G1 X121.661 Y111.311 E.29673
G3 X122.552 Y109.953 I9.398 J5.198 E.05392
; CHANGE_LAYER
; Z_HEIGHT: 11.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15476.087
G1 X122.054 Y110.618 E-.31576
G1 X121.661 Y111.311 E-.3026
G1 X121.398 Y111.574 E-.14165
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
G1 X133.552 Y118.287
G1 Z11.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X133.552 Y118.361 E.00243
G1 X133.11 Y118.914 E.0235
G3 X127.647 Y107.76 I-5.109 J-4.413 E.88394
G3 X133.552 Y110.639 I.319 J6.841 E.2273
G1 X133.552 Y118.227 E.25171
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.658 Y108.152 I-5.156 J-3.722 E.78794
G3 X133.16 Y110.777 I.334 J6.378 E.19528
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X139.364 Y118.658 Z12 F36000
G1 X140.272 Y118.544 Z12
G1 Z11.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.267 Y118.562 E.00062
G1 X139.467 Y120.818 E.07941
G1 X139.814 Y120.818 E.01152
G3 X128.669 Y101.119 I-11.813 J-6.318 E1.89811
G3 X139.813 Y108.182 I-.671 J13.382 E.45761
G1 X139.456 Y108.182 E.01184
G1 X140.265 Y110.434 E.07936
G3 X140.45 Y117.96 I-12.267 J4.067 E.2534
G1 X140.29 Y118.487 E.01827
; WIPE_START
G1 X140.267 Y118.562 E-.02987
G1 X139.624 Y120.373 E-.73013
; WIPE_END
G1 E-.04 F1800
G1 X140.934 Y119.29 Z12 F36000
G1 Z11.6
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X128.689 Y100.727 I-12.93 J-4.791 E1.86734
G3 X140.934 Y109.71 I-.707 J13.801 E.49404
G1 X142.59 Y109.71 E.05088
G1 X142.59 Y119.29 E.29437
G1 X140.994 Y119.29 E.04904
; WIPE_START
M204 S10000
G1 X140.491 Y120.342 E-.44314
G1 X140.174 Y120.978 E-.2699
G1 X140.113 Y121.085 E-.04697
; WIPE_END
G1 E-.04 F1800
G1 X140.024 Y120.424 Z12 F36000
G1 Z11.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.44103
G1 F15000
G1 X140.146 Y120.129 E.01034
; LINE_WIDTH: 0.439095
G1 X140.12 Y120.041 E.00295
; LINE_WIDTH: 0.401645
G1 X140.095 Y119.954 E.00267
; WIPE_START
G1 X140.12 Y120.041 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.433 Y112.415 Z12 F36000
G1 X140.518 Y110.348 Z12
G1 Z11.6
G1 E.8 F1800
; LINE_WIDTH: 0.38292
G1 F15000
G3 X140.366 Y119.077 I-12.491 J4.148 E.24657
; WIPE_START
G1 X140.708 Y118.029 E-.4189
G1 X140.866 Y117.401 E-.24627
G1 X140.915 Y117.156 E-.09483
; WIPE_END
G1 E-.04 F1800
G1 X140.124 Y109.565 Z12 F36000
G1 X140.022 Y108.58 Z12
G1 Z11.6
G1 E.8 F1800
; LINE_WIDTH: 0.44711
G1 F15000
G1 X140.144 Y108.873 E.01045
; LINE_WIDTH: 0.44262
G1 X140.118 Y108.958 E.0029
; LINE_WIDTH: 0.40282
G1 X140.092 Y109.044 E.00261
; WIPE_START
G1 X140.118 Y108.958 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.91 Y110.514 Z12 F36000
G1 Z11.6
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X133.915 Y118.432 E.21937
G1 X133.88 Y118.531 E.00292
G3 X130.737 Y121.068 I-6.152 J-4.407 E.11328
G3 X122.034 Y118.376 I-2.733 J-6.579 E.27382
G1 X121.521 Y117.419 E.03009
G3 X121.139 Y116.384 I5.209 J-2.514 E.03062
G1 X120.941 Y115.314 E.03014
G3 X124.902 Y108.095 I7.054 J-.826 E.24336
G1 X125.917 Y107.707 E.03011
G3 X126.991 Y107.457 I1.839 J5.48 E.03061
G1 X128.077 Y107.395 E.03014
G3 X133.389 Y109.853 I-.069 J7.115 E.16712
G1 X133.873 Y110.467 E.02165
; Slow Down End
; WIPE_START
G1 X133.389 Y109.853 E-.29701
G1 X133.015 Y109.452 E-.20852
G1 X132.611 Y109.081 E-.2084
G1 X132.516 Y109.006 E-.04607
; WIPE_END
G1 E-.04 F1800
G1 X132.892 Y116.629 Z12 F36000
G1 X133.058 Y120.001 Z12
G1 Z11.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X134.139 Y118.788 I-5.879 J-6.328 E.05401
G1 X137.836 Y122.484 E.17342
G3 X133.56 Y125.884 I-10.225 J-8.471 E.18252
G1 X129.497 Y121.821 E.1906
G3 X126.501 Y121.823 I-1.501 J-7.123 E.10009
G1 X122.44 Y125.884 E.19054
G3 X118.164 Y122.484 I5.949 J-11.871 E.18252
G1 X121.871 Y118.777 E.17394
G3 X120.676 Y113 I6.193 J-4.294 E.20106
G1 X116.617 Y108.941 E.19043
G3 X116.897 Y108.399 I5.404 J2.454 E.02024
G1 X121.899 Y103.397 E.23466
G3 X125.178 Y102.15 I6.204 J11.38 E.11673
G1 X130.475 Y107.447 E.24851
G3 X132.278 Y108.371 I-3.694 J9.434 E.06728
G1 X135.984 Y104.664 E.17387
G1 X136.35 Y104.968 E.01579
G3 X137.179 Y105.768 I-7.442 J8.543 E.03823
; WIPE_START
G1 X136.35 Y104.968 E-.43776
G1 X135.984 Y104.664 E-.18085
G1 X135.721 Y104.927 E-.1414
; WIPE_END
G1 E-.04 F1800
G1 X139.048 Y111.797 Z12 F36000
G1 X142.383 Y118.683 Z12
G1 Z11.6
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X141.983 Y119.083 E.01735
G1 X141.45 Y119.083
G1 X142.383 Y118.15 E.04053
G1 X142.383 Y117.617
G1 X140.917 Y119.083 E.0637
G1 X140.492 Y118.974
G1 X142.383 Y117.083 E.08217
G1 X142.383 Y116.55
G1 X140.747 Y118.186 E.07109
G1 X140.935 Y117.464
G1 X142.383 Y116.017 E.06289
G1 X142.383 Y115.484
G1 X141.071 Y116.795 E.05698
G1 X141.166 Y116.167
G1 X142.383 Y114.95 E.05287
G1 X142.383 Y114.417
G1 X141.226 Y115.573 E.05024
G1 X141.259 Y115.008
G1 X142.383 Y113.884 E.04883
G1 X142.383 Y113.351
G1 X141.268 Y114.465 E.04844
G1 X141.257 Y113.943
G1 X142.383 Y112.817 E.04893
G1 X142.383 Y112.284
G1 X141.228 Y113.439 E.05019
G1 X141.18 Y112.954
G1 X142.383 Y111.751 E.05227
G1 X142.383 Y111.218
G1 X141.114 Y112.486 E.05512
G1 X141.037 Y112.03
G1 X142.383 Y110.684 E.05849
G1 X142.383 Y110.151
G1 X140.948 Y111.586 E.06235
G1 X140.841 Y111.16
G1 X142.083 Y109.917 E.05399
G1 X141.55 Y109.917
G1 X140.725 Y110.742 E.03585
G1 X140.6 Y110.334
G1 X141.017 Y109.917 E.01809
M204 S10000
G1 X140.656 Y110.012 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.390478
G1 F15000
G2 X140.331 Y109.199 I-8.78 J3.029 E.0248
G1 X140.131 Y109.141 E.00591
G1 X141.304 Y113.629 F36000
; LINE_WIDTH: 0.118021
G1 F15000
G1 X141.21 Y113.421 E.0014
G1 X140.582 Y119.192 F36000
; LINE_WIDTH: 0.393949
G1 F15000
G3 X140.329 Y119.801 I-17.766 J-7.029 E.01887
G1 X140.127 Y119.854 E.00595
; WIPE_START
G1 X140.329 Y119.801 E-.18223
G1 X140.582 Y119.192 E-.57777
; WIPE_END
G1 E-.04 F1800
G1 X139.191 Y121.175 Z12 F36000
G1 Z11.6
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G3 X139.15 Y107.762 I-11.192 J-6.672 E1.87786
; Slow Down End
; WIPE_START
G1 X138.796 Y107.198 E-.2531
G1 X138.435 Y106.689 E-.23732
G1 X138.005 Y106.147 E-.26288
G1 X137.993 Y106.133 E-.00671
; WIPE_END
G1 E-.04 F1800
G1 X130.627 Y108.131 Z12 F36000
G1 X121.651 Y110.564 Z12
G1 Z11.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X120.945 Y112.027 I6.271 J3.928 E.05399
G1 X115.649 Y117.324 E.24846
G3 X115.36 Y115.36 I20.388 J-4.002 E.06587
G1 X127.139 Y127.139 E.5526
G2 X128.861 Y127.139 I.861 J-22.936 E.05713
G1 X140.536 Y115.464 E.54769
G3 X140.27 Y117.242 I-13.875 J-1.163 E.05967
G1 X134.278 Y111.25 E.28113
G1 X134.278 Y114.047 E.09278
G1 X139.365 Y108.959 E.23866
G2 X139.101 Y108.397 I-2.668 J.911 E.02064
G1 X134.1 Y103.396 E.2346
G1 X133.648 Y103.157 E.01697
G2 X130.822 Y102.15 I-5.75 J11.668 E.09973
G1 X125.522 Y107.45 E.24863
G2 X123.72 Y108.368 I2.654 J7.436 E.06729
G1 X120.016 Y104.664 E.17379
G2 X118.821 Y105.768 I8.349 J10.224 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 11.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X120.016 Y104.664 E-.61827
G1 X120.279 Y104.927 E-.14173
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
G1 X133.506 Y118.418
G1 Z11.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X133.11 Y118.914 E.02107
G3 X127.632 Y107.76 I-5.107 J-4.414 E.88326
G3 X133.552 Y110.639 I.334 J6.84 E.22781
G1 X133.552 Y118.361 E.25612
G1 X133.544 Y118.371 E.00044
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.643 Y108.152 I-5.156 J-3.722 E.78746
G3 X133.16 Y110.777 I.345 J6.387 E.19572
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.657 E-.22942
G1 X132.479 Y119.016 E-.1864
G1 X132.117 Y119.348 E-.1863
G1 X131.791 Y119.604 E-.15789
; WIPE_END
G1 E-.04 F1800
G1 X139.414 Y119.232 Z12.2 F36000
G1 X140.554 Y119.176 Z12.2
G1 Z11.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.545 Y119.211 E.0012
G3 X128.029 Y101.103 I-12.539 J-4.713 E1.93492
G1 X128.673 Y101.119 E.02137
G3 X140.719 Y118.719 I-.667 J13.379 E.81827
G1 X140.574 Y119.119 E.01414
G1 X140.923 Y119.307 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X140.912 Y119.348 E.0013
G3 X128.029 Y100.711 I-12.906 J-4.85 E1.84482
G1 X128.693 Y100.728 E.0204
G3 X141.091 Y118.841 I-.687 J13.77 E.78012
G1 X140.944 Y119.251 E.01337
; WIPE_START
M204 S10000
G1 X140.912 Y119.348 E-.0388
G1 X140.491 Y120.343 E-.41063
M73 P94 R1
G1 X140.173 Y120.978 E-.26993
G1 X140.121 Y121.071 E-.04064
; WIPE_END
G1 E-.04 F1800
G1 X133.907 Y125.503 Z12.2 F36000
G1 X131.411 Y127.282 Z12.2
G1 Z11.8
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.40695
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X125.147 Y121.017 E.46951
G2 X126.148 Y121.372 I2.727 J-6.106 E.05633
G1 X131.749 Y126.973 E.41977
G2 X132.237 Y126.815 I-1.287 J-4.819 E.02721
G1 X126.969 Y121.547 E.39481
G2 X127.675 Y121.607 I1.176 J-9.719 E.03755
G1 X132.711 Y126.643 E.37747
G1 X133.171 Y126.457 E.02628
G1 X128.324 Y121.61 E.36323
G2 X128.918 Y121.558 I-.04 J-3.874 E.03164
G1 X133.613 Y126.252 E.35184
G2 X133.899 Y126.114 I-1.204 J-2.849 E.01686
G1 X134.043 Y126.037 E.00867
G1 X129.47 Y121.464 E.34273
G2 X129.987 Y121.334 I-.579 J-3.406 E.02826
G1 X134.463 Y125.81 E.33546
G1 X134.867 Y125.568 E.02496
G1 X130.473 Y121.174 E.3293
G2 X130.931 Y120.986 I-.985 J-3.056 E.02628
G1 X135.259 Y125.313 E.32431
G2 X135.641 Y125.049 I-2.371 J-3.837 E.02463
G1 X131.365 Y120.773 E.32046
G2 X131.775 Y120.537 I-5.842 J-10.639 E.02508
G1 X136.01 Y124.772 E.31738
G2 X136.214 Y124.608 I-1.493 J-2.069 E.01391
G1 X136.366 Y124.482 E.01043
G1 X132.163 Y120.279 E.31499
G2 X132.291 Y120.18 I-.574 J-.878 E.00859
G1 X132.526 Y119.995 E.01582
G1 X136.712 Y124.182 E.31377
G1 X137.048 Y123.871 E.02423
G1 X132.869 Y119.692 E.31322
G2 X133.191 Y119.369 I-1.931 J-2.251 E.02424
G1 X137.369 Y123.546 E.3131
G2 X137.626 Y123.276 I-2.488 J-2.617 E.01978
G1 X137.681 Y123.213 E.00446
G1 X133.494 Y119.025 E.31381
G1 X133.781 Y118.666 E.02437
G1 X137.984 Y122.868 E.31495
G2 X138.128 Y122.689 I-1.674 J-1.492 E.01221
G1 X138.27 Y122.509 E.01216
G1 X133.922 Y118.16 E.3259
G1 X133.922 Y117.514 E.03425
G1 X138.548 Y122.14 E.3467
G2 X138.816 Y121.762 I-3.552 J-2.802 E.02458
G1 X133.922 Y116.868 E.36679
G1 X133.922 Y116.222 E.03425
G1 X139.067 Y121.367 E.38561
G2 X139.308 Y120.961 I-3.805 J-2.533 E.025
G1 X133.922 Y115.576 E.40365
G1 X133.922 Y114.929 E.03425
G1 X139.538 Y120.546 E.42092
G1 X139.753 Y120.115 E.02553
G1 X133.922 Y114.283 E.43705
G1 X133.922 Y113.637 E.03425
G1 X139.95 Y119.665 E.45176
G1 X140.141 Y119.21 E.02616
G1 X133.922 Y112.991 E.46608
G1 X133.922 Y112.344 E.03425
G1 X140.316 Y118.739 E.47924
G2 X140.452 Y118.317 I-4.603 J-1.71 E.0235
G1 X140.473 Y118.249 E.00376
G1 X133.922 Y111.698 E.49095
G1 X133.922 Y111.052 E.03425
G1 X140.614 Y117.744 E.50152
G2 X140.738 Y117.221 I-5.235 J-1.519 E.02846
G1 X125.277 Y101.761 E1.15869
G1 X124.755 Y101.885 E.02845
G1 X130.843 Y107.973 E.45628
G2 X129.85 Y107.626 I-3.072 J7.201 E.05578
G1 X124.251 Y102.027 E.41962
G2 X123.762 Y102.185 I1.287 J4.823 E.02722
G1 X129.034 Y107.457 E.3951
G2 X128.321 Y107.39 I-.789 J4.581 E.038
G1 X123.288 Y102.357 E.37721
G1 X122.829 Y102.544 E.02627
G1 X127.674 Y107.389 E.36312
G2 X127.08 Y107.441 I.095 J4.492 E.03163
G1 X122.387 Y102.748 E.35175
G2 X121.956 Y102.964 I1.876 J4.286 E.02553
G1 X126.527 Y107.534 E.34258
G2 X126.011 Y107.664 I.584 J3.411 E.02824
G1 X121.536 Y103.19 E.33534
G1 X121.133 Y103.433 E.02495
G1 X125.526 Y107.826 E.32922
G2 X125.068 Y108.014 I.991 J3.051 E.02625
G1 X120.741 Y103.687 E.3243
G2 X120.359 Y103.951 I2.373 J3.842 E.02463
G1 X124.636 Y108.228 E.32054
G2 X124.226 Y108.465 I1.327 J2.764 E.02509
G1 X119.99 Y104.229 E.31751
G2 X119.634 Y104.519 I2.64 J3.599 E.02435
G1 X123.839 Y108.724 E.31515
G2 X123.472 Y109.003 I1.625 J2.512 E.02446
G1 X119.287 Y104.818 E.31366
G1 X118.952 Y105.129 E.02423
G1 X123.129 Y109.306 E.31306
G2 X122.807 Y109.631 I1.941 J2.244 E.02424
G1 X118.631 Y105.454 E.31303
G2 X118.318 Y105.788 I4.441 J4.469 E.02423
G1 X122.506 Y109.976 E.31385
G1 X122.424 Y110.074 E.00679
G2 X122.225 Y110.341 I1.625 J1.424 E.01765
G1 X118.016 Y106.132 E.3154
G2 X117.729 Y106.492 I3.34 J2.957 E.02438
G1 X121.967 Y110.729 E.3176
G2 X121.726 Y111.134 I2.177 J1.575 E.02501
G1 X117.452 Y106.86 E.32029
G2 X117.184 Y107.238 I3.583 J2.824 E.02457
G1 X121.51 Y111.565 E.32427
G2 X121.324 Y112.024 I5.098 J2.341 E.02629
G1 X116.933 Y107.634 E.32908
G2 X116.692 Y108.039 I3.82 J2.543 E.025
G1 X121.164 Y112.511 E.33516
G2 X121.084 Y112.821 I1.965 J.675 E.01696
G1 X121.035 Y113.028 E.0113
G1 X116.462 Y108.455 E.34274
G1 X116.246 Y108.886 E.02553
G1 X120.94 Y113.58 E.35179
G2 X120.887 Y114.173 I3.81 J.643 E.03157
G1 X116.046 Y109.331 E.36282
G2 X115.859 Y109.791 I4.569 J2.131 E.02628
G1 X120.886 Y114.818 E.3768
G2 X120.958 Y115.537 I9.644 J-.608 E.03828
G1 X115.682 Y110.26 E.39543
G1 X115.526 Y110.75 E.02725
G1 X121.123 Y116.348 E.41949
G2 X121.473 Y117.344 I8.391 J-2.388 E.05598
G1 X115.386 Y111.257 E.45617
G2 X115.279 Y111.708 I4.323 J1.273 E.02456
G1 X115.263 Y111.78 E.00394
G1 X130.722 Y127.239 E1.15856
G3 X130.178 Y127.341 I-1.262 J-5.221 E.02935
G1 X115.159 Y112.322 E1.12564
G2 X115.074 Y112.883 I5.41 J1.102 E.03011
G1 X129.614 Y127.423 E1.0897
G3 X129.027 Y127.483 I-.957 J-6.49 E.03125
G1 X115.014 Y113.469 E1.05027
G2 X114.981 Y114.083 I5.961 J.628 E.03256
G1 X128.415 Y127.517 E1.00687
G3 X127.774 Y127.522 I-.368 J-6.218 E.034
G1 X114.976 Y114.724 E.95913
G2 X115.006 Y115.4 I6.568 J.055 E.03584
G1 X127.099 Y127.493 E.90632
G3 X126.382 Y127.423 I.319 J-6.974 E.03815
G1 X115.074 Y116.114 E.84752
G2 X115.19 Y116.867 I31.256 J-4.423 E.04037
G1 X125.617 Y127.304 E.78183
G3 X124.831 Y127.133 I1.259 J-7.71 E.04265
G1 X124.791 Y127.124 E.00217
G1 X115.378 Y117.711 E.70547
G2 X115.646 Y118.625 I9.001 J-2.14 E.05049
G1 X123.875 Y126.854 E.61675
G3 X122.832 Y126.458 I3.323 J-10.311 E.05914
G1 X116.048 Y119.673 E.50847
G2 X116.68 Y120.94 I12.003 J-5.199 E.07504
M73 P95 R1
G1 X121.541 Y125.813 E.36478
G3 X118.972 Y123.89 I6.683 J-11.607 E.17049
G1 X117.158 Y122.076 E.13593
G1 X125.647 Y101.485 F36000
G1 F3000
G1 X140.843 Y116.68 E1.13884
G1 X140.927 Y116.118 E.03014
G1 X126.385 Y101.577 E1.0898
G3 X126.972 Y101.517 I.872 J5.661 E.03126
G1 X140.986 Y115.531 E1.05026
G2 X141.019 Y114.918 I-6.182 J-.647 E.03253
G1 X127.585 Y101.484 E1.00686
G1 X127.931 Y101.475 E.01835
G3 X128.225 Y101.478 I.121 J2.915 E.01559
G1 X141.024 Y114.277 E.95924
G2 X140.996 Y113.602 I-6.858 J-.049 E.0358
G1 X128.901 Y101.507 E.90644
G3 X129.617 Y101.577 I-.321 J6.996 E.03814
G1 X140.927 Y112.888 E.84767
G1 X140.891 Y112.644 E.01309
G2 X140.806 Y112.12 I-5.351 J.604 E.02813
G1 X130.382 Y101.696 E.78121
G1 X130.507 Y101.719 E.00671
G3 X131.208 Y101.876 I-1.174 J6.89 E.03809
G1 X140.622 Y111.29 E.70556
G2 X140.358 Y110.38 I-16.857 J4.397 E.05024
G1 X132.124 Y102.146 E.61706
G3 X133.166 Y102.541 I-3.317 J10.313 E.05905
G1 X139.952 Y109.328 E.50861
G1 X139.916 Y109.245 E.00481
G2 X139.303 Y108.033 I-11.396 J4.997 E.072
G1 X134.459 Y103.188 E.36309
G3 X137.014 Y105.097 I-6.668 J11.59 E.16948
G1 X138.842 Y106.925 E.13698
; CHANGE_LAYER
; Z_HEIGHT: 12
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X137.428 Y105.511 E-.76
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
G1 X133.552 Y118.287
G1 Z12
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.552 Y118.361 E.00243
G1 X133.11 Y118.914 E.02349
G3 X127.616 Y107.761 I-5.108 J-4.413 E.88293
G3 X133.552 Y110.639 I.348 J6.841 E.22832
G1 X133.552 Y118.227 E.25171
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.628 Y108.153 I-5.156 J-3.723 E.78701
G3 X133.16 Y110.777 I.363 J6.378 E.19622
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22947
G1 X132.479 Y119.016 E-.18632
G1 X132.117 Y119.348 E-.18637
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X139.414 Y119.226 Z12.4 F36000
G1 X140.556 Y119.169 Z12.4
G1 Z12
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.406 Y119.562 E.01395
G3 X128.022 Y101.103 I-12.401 J-5.064 E1.92221
G1 X128.677 Y101.12 E.02175
G3 X140.579 Y119.114 I-.672 J13.378 E.83199
G1 X140.922 Y119.31 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X140.769 Y119.711 E.01319
G3 X128.022 Y100.71 I-12.764 J-5.213 E1.83264
G1 X128.697 Y100.728 E.02075
G3 X140.945 Y119.255 I-.692 J13.77 E.79341
; WIPE_START
M204 S10000
G1 X140.769 Y119.711 E-.18587
G1 X140.491 Y120.344 E-.26265
G1 X140.173 Y120.979 E-.2699
G1 X140.119 Y121.074 E-.04159
; WIPE_END
G1 E-.04 F1800
G1 X135.744 Y125.229 Z12.4 F36000
G1 Z12
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42154
G1 F15000
G2 X137.589 Y123.373 I-70.442 J-71.859 E.08075
G2 X139.179 Y121.259 I-9.536 J-8.827 E.08177
G1 X134.768 Y125.67 E.19245
G3 X133.607 Y126.296 I-6.838 J-11.296 E.04072
G1 X139.801 Y120.102 E.27025
G2 X140.199 Y119.168 I-15.257 J-7.063 E.03134
G1 X132.665 Y126.701 E.32871
G3 X131.85 Y126.981 I-6.715 J-18.229 E.0266
G1 X140.471 Y118.361 E.37613
G2 X140.684 Y117.612 I-5.625 J-2.011 E.02406
G1 X131.111 Y127.184 E.41769
G3 X130.428 Y127.333 I-1.781 J-6.567 E.02159
G1 X140.834 Y116.927 E.45403
G2 X140.938 Y116.287 I-6.362 J-1.369 E.02002
G1 X129.787 Y127.438 E.48654
G3 X129.182 Y127.508 I-.982 J-5.844 E.01881
G1 X141.007 Y115.682 E.51596
G2 X141.046 Y115.108 I-5.733 J-.678 E.01777
G1 X128.605 Y127.549 E.54282
G1 X128.056 Y127.563 E.01696
G1 X141.06 Y114.558 E.56742
G2 X141.053 Y114.03 I-5.3 J-.192 E.01631
G1 X127.531 Y127.552 E.59
G3 X127.024 Y127.524 I.025 J-4.93 E.01567
G1 X141.027 Y113.52 E.61099
G1 X140.979 Y113.034 E.01509
G1 X126.533 Y127.479 E.63029
G1 X126.059 Y127.418 E.01475
G1 X140.916 Y112.561 E.64822
G2 X140.84 Y112.102 I-4.634 J.531 E.01437
G1 X125.603 Y127.338 E.6648
G3 X125.158 Y127.248 I.653 J-4.364 E.01402
G1 X140.75 Y111.657 E.6803
G2 X140.643 Y111.227 I-4.345 J.846 E.01365
G1 X133.885 Y117.985 E.29487
G1 X133.885 Y117.45 E.01652
G1 X140.528 Y110.807 E.28984
G1 X140.402 Y110.398 E.01321
G1 X133.885 Y116.914 E.28433
G1 X133.885 Y116.379 E.01652
G1 X140.259 Y110.005 E.27811
G1 X140.114 Y109.614 E.01285
G1 X133.885 Y115.843 E.27179
G1 X133.885 Y115.308 E.01652
G1 X139.954 Y109.24 E.26477
G2 X139.787 Y108.871 I-3.76 J1.474 E.0125
G1 X133.885 Y114.773 E.25751
G1 X133.885 Y114.237 E.01652
G1 X139.609 Y108.514 E.24972
G2 X139.421 Y108.166 I-3.452 J1.638 E.0122
G1 X133.885 Y113.702 E.24154
G1 X133.885 Y113.166 E.01652
G1 X139.227 Y107.824 E.23309
G2 X139.022 Y107.494 I-3.32 J1.837 E.012
G1 X133.885 Y112.631 E.22413
G1 X133.885 Y112.095 E.01652
G1 X138.812 Y107.169 E.21495
G1 X138.589 Y106.856 E.01185
G1 X133.885 Y111.56 E.20525
G1 X133.885 Y111.024 E.01652
G1 X138.362 Y106.548 E.19531
G1 X138.125 Y106.249 E.01176
G1 X133.87 Y110.504 E.18565
G1 X133.633 Y110.206 E.01175
G1 X137.88 Y105.959 E.18532
G1 X137.629 Y105.674 E.01171
G1 X133.395 Y109.909 E.18476
G2 X133.139 Y109.629 I-1.936 J1.513 E.01171
G1 X137.368 Y105.4 E.1845
G1 X137.107 Y105.133 E.01153
G1 X132.872 Y109.361 E.18461
G1 X132.593 Y109.104 E.01169
G1 X136.825 Y104.873 E.18464
G2 X136.543 Y104.619 I-2.608 J2.611 E.0117
G1 X132.293 Y108.868 E.18542
G2 X131.982 Y108.644 I-1.605 J1.905 E.01185
G1 X136.251 Y104.376 E.18626
G2 X135.952 Y104.139 I-2.444 J2.779 E.01177
G1 X131.658 Y108.433 E.18737
M73 P95 R0
G1 X131.315 Y108.241 E.01213
G1 X135.646 Y103.91 E.18897
G2 X135.329 Y103.691 I-2.289 J2.966 E.01188
G1 X130.955 Y108.065 E.19087
G2 X130.579 Y107.905 I-1.224 J2.345 E.0126
G1 X135.009 Y103.475 E.19326
G2 X134.674 Y103.274 I-2.123 J3.153 E.01204
G1 X130.188 Y107.761 E.19577
G1 X129.772 Y107.642 E.01335
G1 X134.336 Y103.078 E.19915
G1 X133.986 Y102.892 E.01222
G1 X129.333 Y107.545 E.20304
G2 X128.87 Y107.473 I-.699 J2.958 E.01448
G1 X133.628 Y102.714 E.20762
G1 X133.263 Y102.544 E.01243
G1 X128.378 Y107.429 E.21315
G2 X127.851 Y107.421 I-.319 J3.404 E.01627
G1 X132.884 Y102.388 E.2196
G2 X132.499 Y102.237 I-1.656 J3.67 E.01276
G1 X127.277 Y107.459 E.22782
G2 X126.652 Y107.548 I.207 J3.663 E.01951
G1 X132.101 Y102.099 E.23775
G2 X131.692 Y101.973 I-1.432 J3.901 E.01321
G1 X125.946 Y107.719 E.25073
G2 X125.082 Y108.048 I2.796 J8.65 E.02854
G1 X131.276 Y101.854 E.27026
G1 X130.842 Y101.752 E.01374
G1 X115.252 Y117.343 E.68024
G2 X115.357 Y117.773 I4.229 J-.801 E.01368
G1 X121.539 Y111.591 E.26975
G2 X121.225 Y112.441 I5.342 J2.459 E.02798
G1 X115.47 Y118.195 E.25108
G1 X115.6 Y118.601 E.01315
G1 X121.043 Y113.158 E.23749
G2 X120.954 Y113.783 I3.995 J.89 E.01949
G1 X115.738 Y118.998 E.22755
G1 X115.885 Y119.387 E.01282
G1 X120.919 Y114.352 E.21966
G2 X120.927 Y114.88 I3.412 J.21 E.01628
G1 X116.046 Y119.761 E.21298
G2 X116.213 Y120.129 I3.659 J-1.435 E.01249
G1 X120.97 Y115.373 E.20754
G1 X121.042 Y115.836 E.01447
G1 X116.392 Y120.486 E.2029
G2 X116.579 Y120.835 I3.477 J-1.642 E.01221
G1 X121.143 Y116.271 E.19914
G2 X121.265 Y116.684 I2.739 J-.583 E.01331
G1 X116.772 Y121.177 E.19601
G2 X116.978 Y121.506 I3.289 J-1.83 E.01199
G1 X121.408 Y117.077 E.19326
G2 X121.562 Y117.457 I2.281 J-.707 E.01269
G1 X117.188 Y121.832 E.19086
G1 X117.411 Y122.145 E.01185
G1 X121.741 Y117.815 E.18893
G2 X121.936 Y118.155 I2.302 J-1.092 E.01212
G1 X117.638 Y122.452 E.1875
G1 X117.875 Y122.751 E.01176
G1 X122.146 Y118.48 E.18637
G1 X122.366 Y118.796 E.01187
G1 X118.12 Y123.042 E.18526
G1 X118.37 Y123.327 E.01171
G1 X122.607 Y119.09 E.18487
G2 X122.861 Y119.372 I1.953 J-1.498 E.01171
G1 X118.632 Y123.6 E.1845
G2 X118.897 Y123.871 I2.773 J-2.453 E.01169
G1 X123.126 Y119.642 E.18449
G1 X123.41 Y119.893 E.0117
G1 X119.175 Y124.128 E.18477
G2 X119.457 Y124.381 I2.6 J-2.609 E.0117
G1 X123.709 Y120.129 E.18552
G2 X124.017 Y120.358 I1.474 J-1.665 E.01182
G1 X119.749 Y124.625 E.18619
G2 X120.048 Y124.861 I2.444 J-2.785 E.01177
G1 X124.343 Y120.566 E.1874
G2 X124.687 Y120.758 I1.41 J-2.124 E.01216
G1 X120.354 Y125.091 E.18905
G2 X120.671 Y125.31 I2.281 J-2.961 E.01188
G1 X125.045 Y120.936 E.19085
G2 X125.418 Y121.098 I1.237 J-2.331 E.01256
G1 X120.991 Y125.525 E.19315
G1 X121.326 Y125.726 E.01204
G1 X125.814 Y121.237 E.19586
G2 X126.231 Y121.356 I.979 J-2.63 E.01337
G1 X121.664 Y125.923 E.19924
G1 X122.014 Y126.109 E.01221
G1 X126.668 Y121.454 E.20307
G2 X127.13 Y121.528 I.708 J-2.955 E.01444
G1 X122.372 Y126.286 E.20758
G1 X122.737 Y126.456 E.01242
G1 X127.624 Y121.569 E.21325
G2 X128.147 Y121.582 I.336 J-3.017 E.01615
G1 X123.116 Y126.613 E.2195
G2 X123.501 Y126.763 I1.647 J-3.655 E.01276
G1 X128.718 Y121.546 E.22761
G2 X129.348 Y121.452 I-.297 J-4.122 E.01968
G1 X123.899 Y126.901 E.23776
G2 X124.308 Y127.027 I1.429 J-3.902 E.01322
G1 X130.06 Y121.275 E.25097
G2 X130.919 Y120.951 I-2.16 J-7.03 E.02836
G1 X124.586 Y127.285 E.27635
G1 X115.016 Y117.043 F36000
G1 F15000
G1 X130.397 Y101.662 E.67112
G2 X129.941 Y101.582 I-1.002 J4.389 E.01428
G1 X115.085 Y116.439 E.64824
G3 X115.022 Y115.966 I4.553 J-.843 E.01472
G1 X129.467 Y101.521 E.63027
G2 X128.976 Y101.477 I-.679 J4.743 E.01521
G1 X114.973 Y115.479 E.61098
G1 X114.947 Y114.97 E.01573
G1 X128.47 Y101.448 E.59003
G2 X127.944 Y101.438 I-.357 J5.166 E.01623
G1 X114.94 Y114.442 E.56739
G3 X114.954 Y113.892 I5.333 J-.139 E.01697
M73 P96 R0
G1 X127.395 Y101.452 E.54281
G2 X126.818 Y101.493 I.097 J5.455 E.01783
G1 X114.993 Y113.318 E.51598
G3 X115.061 Y112.715 I5.889 J.358 E.01875
G1 X126.213 Y101.563 E.4866
G2 X125.573 Y101.667 I.698 J6.271 E.02003
G1 X115.165 Y112.075 E.45412
G3 X115.314 Y111.391 I6.716 J1.103 E.02162
G1 X124.889 Y101.816 E.41779
G2 X124.15 Y102.019 I1.604 J7.275 E.02365
G1 X115.52 Y110.649 E.37655
G3 X115.805 Y109.829 I7.802 J2.248 E.02679
G1 X123.335 Y102.298 E.32859
G2 X122.394 Y102.704 I3.474 J9.348 E.03166
G1 X116.199 Y108.899 E.27028
G3 X116.821 Y107.742 I15.186 J7.412 E.04053
G1 X121.233 Y103.33 E.19251
G2 X118.898 Y105.129 I6.917 J11.39 E.09113
G1 X117.278 Y106.749 E.07067
; CHANGE_LAYER
; Z_HEIGHT: 12.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X118.692 Y105.335 E-.76
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
G1 X133.552 Y118.287
G1 Z12.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.552 Y118.361 E.00243
G1 X133.109 Y118.915 E.02354
G3 X127.579 Y107.762 I-5.106 J-4.416 E.88152
G1 X128.068 Y107.748 E.01621
G3 X133.552 Y110.639 I-.124 J6.881 E.21333
G1 X133.552 Y118.227 E.25171
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.605 Y108.153 I-5.156 J-3.723 E.7864
G3 X133.16 Y110.777 I.38 J6.389 E.19689
G1 X133.16 Y118.163 E.22697
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22965
G1 X132.456 Y119.037 E-.19783
G1 X132.117 Y119.348 E-.1746
G1 X131.79 Y119.604 E-.15792
; WIPE_END
G1 E-.04 F1800
G1 X139.414 Y119.23 Z12.6 F36000
G1 X140.549 Y119.174 Z12.6
G1 Z12.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.407 Y119.557 E.01353
G3 X128.015 Y101.103 I-12.403 J-5.059 E1.92222
G1 X128.681 Y101.12 E.02212
G3 X140.685 Y118.81 I-.678 J13.378 E.82113
G1 X140.57 Y119.118 E.0109
G1 X140.917 Y119.311 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X140.769 Y119.705 E.01292
G3 X128.015 Y100.71 I-12.766 J-5.207 E1.83267
G1 X128.701 Y100.728 E.0211
G3 X141.057 Y118.936 I-.698 J13.77 E.78285
G1 X140.938 Y119.255 E.01048
; WIPE_START
M204 S10000
G1 X140.769 Y119.705 E-.18257
G1 X140.49 Y120.344 E-.26505
G1 X140.173 Y120.98 E-.26983
G1 X140.118 Y121.077 E-.04256
; WIPE_END
G1 E-.04 F1800
G1 X140.782 Y117.912 Z12.6 F36000
G1 Z12.2
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42154
G1 F15000
G1 X133.885 Y111.015 E.30094
G1 X133.885 Y111.551 E.01652
G1 X140.527 Y118.193 E.2898
G1 X140.396 Y118.597 E.01312
G1 X133.885 Y112.086 E.28409
G1 X133.885 Y112.622 E.01652
G1 X140.263 Y118.999 E.27826
G1 X140.115 Y119.387 E.0128
G1 X133.885 Y113.157 E.27181
G1 X133.885 Y113.692 E.01652
G1 X139.954 Y119.761 E.26478
G3 X139.787 Y120.129 I-3.679 J-1.444 E.01249
G1 X133.885 Y114.228 E.2575
G1 X133.885 Y114.763 E.01652
G1 X139.608 Y120.486 E.24971
G3 X139.421 Y120.835 I-3.469 J-1.638 E.01221
G1 X133.885 Y115.299 E.24155
G1 X133.885 Y115.834 E.01652
G1 X139.228 Y121.177 E.23311
G3 X139.022 Y121.506 I-3.297 J-1.834 E.01199
G1 X133.885 Y116.37 E.22411
G1 X133.885 Y116.905 E.01652
G1 X138.812 Y121.832 E.21495
G1 X138.589 Y122.145 E.01185
G1 X133.885 Y117.441 E.20525
G1 X133.885 Y117.976 E.01652
G1 X138.362 Y122.452 E.19531
G1 X138.125 Y122.751 E.01176
G1 X133.87 Y118.496 E.18565
G1 X133.632 Y118.794 E.01175
G1 X137.88 Y123.042 E.18533
G1 X137.63 Y123.327 E.01171
G1 X133.395 Y119.092 E.18478
G3 X133.138 Y119.371 I-1.831 J-1.427 E.0117
G1 X137.368 Y123.6 E.18455
G3 X137.103 Y123.871 I-2.749 J-2.43 E.01169
G1 X132.872 Y119.64 E.1846
G1 X132.593 Y119.896 E.01169
G1 X136.824 Y124.128 E.18465
G3 X136.543 Y124.381 I-2.604 J-2.613 E.0117
G1 X132.293 Y120.132 E.18542
G3 X131.981 Y120.356 I-1.605 J-1.905 E.01185
G1 X136.251 Y124.625 E.18628
G3 X135.952 Y124.861 I-2.44 J-2.779 E.01177
G1 X131.657 Y120.567 E.18737
G1 X131.314 Y120.76 E.01213
G1 X135.646 Y125.091 E.18899
G3 X135.329 Y125.31 I-2.286 J-2.969 E.01188
G1 X130.954 Y120.935 E.19088
G3 X130.579 Y121.095 I-1.224 J-2.346 E.0126
G1 X135.009 Y125.525 E.19328
G1 X134.674 Y125.726 E.01204
G1 X130.187 Y121.239 E.19578
G1 X129.771 Y121.358 E.01335
G1 X134.336 Y125.923 E.19915
G1 X133.986 Y126.109 E.01221
G1 X129.332 Y121.455 E.20305
G3 X128.869 Y121.527 I-.699 J-2.962 E.01448
G1 X133.628 Y126.286 E.20762
G1 X133.263 Y126.456 E.01242
G1 X128.377 Y121.571 E.21317
G3 X127.851 Y121.579 I-.319 J-3.408 E.01627
G1 X132.884 Y126.613 E.21961
G3 X132.499 Y126.763 I-1.652 J-3.669 E.01276
G1 X127.279 Y121.543 E.22775
G3 X126.652 Y121.451 I.316 J-4.359 E.01957
G1 X132.101 Y126.901 E.23778
G3 X131.692 Y127.027 I-1.43 J-3.905 E.01322
G1 X125.945 Y121.28 E.25075
G3 X125.078 Y120.949 I2.672 J-8.282 E.02866
G1 X131.275 Y127.146 E.2704
G1 X130.842 Y127.248 E.01373
G1 X115.252 Y111.658 E.68024
G3 X115.357 Y111.227 I4.226 J.801 E.01368
G1 X121.539 Y117.41 E.26977
G3 X121.225 Y116.56 I5.34 J-2.459 E.02798
G1 X115.47 Y110.805 E.25109
G1 X115.6 Y110.399 E.01315
G1 X121.045 Y115.844 E.23758
G3 X120.954 Y115.218 I11.723 J-2.023 E.01953
G1 X115.739 Y110.003 E.22755
G1 X115.885 Y109.614 E.01281
G1 X120.919 Y114.648 E.21963
G3 X120.928 Y114.121 I3.219 J-.212 E.01628
G1 X116.046 Y109.24 E.213
G3 X116.213 Y108.871 I3.674 J1.442 E.01249
G1 X120.97 Y113.628 E.20755
G1 X121.042 Y113.164 E.01447
G1 X116.391 Y108.514 E.20291
G3 X116.579 Y108.166 I3.479 J1.643 E.01221
G1 X121.143 Y112.73 E.19914
G3 X121.264 Y112.316 I2.74 J.583 E.01332
G1 X116.772 Y107.824 E.19602
G3 X116.978 Y107.494 I3.29 J1.83 E.01199
G1 X121.405 Y111.921 E.19315
G3 X121.562 Y111.543 I2.393 J.774 E.01265
G1 X117.188 Y107.169 E.19086
G1 X117.41 Y106.856 E.01185
G1 X121.742 Y111.187 E.18899
G3 X121.935 Y110.845 I2.452 J1.162 E.01213
G1 X117.638 Y106.548 E.1875
G1 X117.875 Y106.249 E.01176
G1 X122.143 Y110.518 E.18626
G1 X122.366 Y110.205 E.01185
G1 X118.12 Y105.959 E.18526
G1 X118.37 Y105.674 E.01171
G1 X122.607 Y109.911 E.18488
G3 X122.861 Y109.629 I1.951 J1.497 E.01171
G1 X118.632 Y105.4 E.1845
G3 X118.897 Y105.13 I2.748 J2.43 E.01169
G1 X123.125 Y109.358 E.18448
G1 X123.411 Y109.108 E.01171
G1 X119.175 Y104.872 E.18482
G3 X119.457 Y104.619 I2.604 J2.614 E.0117
G1 X123.707 Y108.869 E.18543
G3 X124.016 Y108.643 I1.618 J1.887 E.01183
G1 X119.749 Y104.375 E.18619
G3 X120.048 Y104.139 I2.441 J2.782 E.01177
G1 X124.343 Y108.434 E.1874
G3 X124.687 Y108.242 I1.411 J2.126 E.01215
G1 X120.354 Y103.909 E.18905
G3 X120.671 Y103.69 I2.283 J2.965 E.01188
G1 X125.045 Y108.064 E.19085
G3 X125.418 Y107.902 I1.235 J2.325 E.01256
G1 X120.991 Y103.475 E.19315
G1 X121.325 Y103.274 E.01204
G1 X125.814 Y107.763 E.19586
G3 X126.23 Y107.644 I.98 J2.634 E.01337
G1 X121.664 Y103.078 E.19923
G1 X122.013 Y102.892 E.01221
G1 X126.668 Y107.546 E.20307
G3 X127.13 Y107.472 I.678 J2.786 E.01445
G1 X122.372 Y102.715 E.2076
G1 X122.737 Y102.544 E.01242
G1 X127.62 Y107.427 E.21308
G3 X128.146 Y107.418 I.323 J3.397 E.01626
G1 X123.116 Y102.388 E.21949
G3 X123.501 Y102.237 I1.649 J3.662 E.01276
G1 X128.717 Y107.454 E.22759
G3 X129.347 Y107.548 I-.297 J4.123 E.01968
G1 X123.898 Y102.099 E.23775
G3 X124.307 Y101.973 I1.43 J3.908 E.01322
G1 X130.059 Y107.724 E.25095
G3 X130.918 Y108.048 I-2.163 J7.041 E.02835
G1 X124.725 Y101.854 E.27025
G1 X125.158 Y101.752 E.01373
G1 X140.749 Y117.343 E.68029
G1 X140.84 Y116.899 E.014
G1 X125.603 Y101.662 E.66482
G3 X126.059 Y101.583 I.998 J4.391 E.01429
G1 X140.915 Y116.439 E.64822
G2 X140.978 Y115.967 I-4.652 J-.862 E.01471
G1 X126.533 Y101.521 E.6303
G3 X127.024 Y101.477 I.676 J4.74 E.01522
G1 X141.027 Y115.48 E.61101
G1 X141.053 Y114.97 E.01575
G1 X127.531 Y101.448 E.59001
G3 X128.055 Y101.437 I.372 J5.131 E.01619
G1 X141.06 Y114.442 E.56744
G2 X141.046 Y113.892 I-5.451 J-.135 E.01697
G1 X128.605 Y101.451 E.54285
G3 X129.181 Y101.492 I-.117 J5.68 E.01785
G1 X141.007 Y113.318 E.51599
G2 X140.939 Y112.714 I-6.013 J.377 E.01876
G1 X129.787 Y101.562 E.48658
G3 X130.427 Y101.667 I-.696 J6.254 E.02003
G1 X140.834 Y112.074 E.45408
G2 X140.685 Y111.389 I-6.853 J1.135 E.02163
G1 X131.111 Y101.815 E.41774
G3 X131.849 Y102.018 I-1.6 J7.265 E.02364
G1 X140.479 Y110.648 E.37653
G2 X140.194 Y109.828 I-7.678 J2.205 E.02679
G1 X132.665 Y102.299 E.32851
G3 X133.606 Y102.704 I-3.46 J9.325 E.03162
G1 X139.802 Y108.9 E.27032
G2 X139.18 Y107.743 I-16.396 J8.06 E.04051
G1 X134.767 Y103.33 E.19256
G3 X137.096 Y105.123 I-6.929 J11.406 E.09085
G1 X138.722 Y106.749 E.07096
G1 X130.543 Y127.484 F36000
G1 F15000
G1 X115.159 Y112.101 E.67122
G2 X115.084 Y112.561 I4.433 J.956 E.01441
G1 X129.941 Y127.418 E.64822
G1 X129.467 Y127.479 E.01475
G1 X115.022 Y113.034 E.63026
G2 X114.973 Y113.521 I4.717 J.719 E.0151
G1 X128.976 Y127.524 E.61097
G3 X128.469 Y127.552 I-.532 J-4.907 E.01567
G1 X114.947 Y114.03 E.59
G2 X114.94 Y114.559 I5.127 J.331 E.01632
G1 X127.944 Y127.563 E.5674
G1 X127.395 Y127.549 E.01696
G1 X114.954 Y115.108 E.54281
G2 X114.993 Y115.682 I5.586 J-.087 E.01776
G1 X126.818 Y127.508 E.51597
G3 X126.213 Y127.438 I.377 J-5.917 E.01881
G1 X115.061 Y116.286 E.48658
G2 X115.165 Y116.925 I6.249 J-.688 E.02
G1 X125.572 Y127.333 E.4541
G3 X124.888 Y127.184 I1.095 J-6.704 E.02159
G1 X115.314 Y117.61 E.41777
G2 X115.52 Y118.352 I7.305 J-1.634 E.02378
G1 X124.15 Y126.981 E.37653
G3 X123.334 Y126.701 I5.9 J-18.509 E.0266
G1 X115.803 Y119.17 E.3286
G2 X116.199 Y120.102 I14.736 J-5.715 E.03123
G1 X122.393 Y126.295 E.27025
G3 X121.232 Y125.669 I5.673 J-11.915 E.04073
G1 X116.821 Y121.259 E.19244
G2 X118.842 Y123.816 I11.507 J-7.019 E.1008
G1 X120.256 Y125.229 E.06168
; CHANGE_LAYER
; Z_HEIGHT: 12.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X118.842 Y123.816 E-.75963
G1 X118.842 Y123.815 E-.00037
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
G1 X133.552 Y118.287
G1 Z12.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.552 Y118.361 E.00243
G1 X133.11 Y118.914 E.02349
G3 X127.564 Y107.762 I-5.107 J-4.415 E.88105
G3 X133.552 Y110.639 I.394 J6.851 E.23006
G1 X133.552 Y118.227 E.25171
G1 X133.16 Y118.223 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.589 Y108.154 I-5.156 J-3.723 E.78596
G3 X133.16 Y110.777 I.394 J6.391 E.19737
G1 X133.16 Y118.163 E.22697
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.2295
G1 X132.479 Y119.016 E-.18629
G1 X132.117 Y119.348 E-.1863
G1 X131.791 Y119.604 E-.15791
; WIPE_END
G1 E-.04 F1800
G1 X139.414 Y119.232 Z12.8 F36000
G1 X140.549 Y119.177 Z12.8
G1 Z12.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.407 Y119.553 E.01334
G3 X128.007 Y101.102 I-12.405 J-5.055 E1.92222
G1 X128.686 Y101.12 E.0225
G3 X140.669 Y118.855 I-.684 J13.378 E.82248
G1 X140.57 Y119.12 E.00941
G1 X140.916 Y119.314 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X140.77 Y119.7 E.01269
G3 X128.008 Y100.71 I-12.768 J-5.202 E1.8327
G1 X128.706 Y100.728 E.02146
G3 X141.039 Y118.982 I-.704 J13.77 E.78417
G1 X140.937 Y119.258 E.00903
; WIPE_START
M204 S10000
G1 X140.77 Y119.7 E-.17967
G1 X140.49 Y120.345 E-.26704
G1 X140.172 Y120.98 E-.26997
G1 X140.116 Y121.08 E-.04332
; WIPE_END
G1 E-.04 F1800
G1 X135.744 Y125.229 Z12.8 F36000
G1 Z12.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42154
G1 F15000
G2 X137.588 Y123.374 I-70.849 J-72.266 E.08072
G2 X139.179 Y121.258 I-9.54 J-8.832 E.08181
G1 X134.768 Y125.67 E.19246
G3 X133.608 Y126.294 I-6.716 J-11.081 E.04068
G1 X139.801 Y120.102 E.27021
G2 X140.195 Y119.172 I-13.775 J-6.393 E.03117
G1 X132.665 Y126.701 E.32854
G3 X131.85 Y126.981 I-6.719 J-18.238 E.0266
G1 X140.479 Y118.352 E.3765
G2 X140.685 Y117.61 I-7.172 J-2.396 E.02377
G1 X131.111 Y127.185 E.41774
G3 X130.428 Y127.333 I-1.779 J-6.556 E.02159
G1 X140.835 Y116.926 E.45408
G2 X140.939 Y116.286 I-6.223 J-1.343 E.02001
G1 X129.787 Y127.438 E.48657
G3 X129.182 Y127.508 I-.982 J-5.845 E.01881
G1 X141.007 Y115.682 E.51597
G2 X141.046 Y115.108 I-5.604 J-.667 E.01776
G1 X128.605 Y127.549 E.54282
G1 X128.056 Y127.563 E.01696
G1 X141.06 Y114.559 E.56741
G2 X141.053 Y114.03 I-5.188 J-.196 E.01631
G1 X127.531 Y127.552 E.59001
G3 X127.024 Y127.524 I.025 J-4.934 E.01567
G1 X141.027 Y113.521 E.61098
G2 X140.978 Y113.034 I-4.778 J.234 E.0151
G1 X126.533 Y127.479 E.63027
G1 X126.059 Y127.418 E.01475
G1 X140.915 Y112.561 E.64822
G2 X140.84 Y112.101 I-4.551 J.508 E.01439
M73 P97 R0
G1 X125.603 Y127.338 E.66483
G3 X125.158 Y127.248 I.653 J-4.362 E.01402
G1 X140.749 Y111.657 E.68025
G2 X140.643 Y111.227 I-4.271 J.817 E.01367
G1 X133.885 Y117.985 E.29486
G1 X133.885 Y117.45 E.01652
G1 X140.529 Y110.806 E.28988
G1 X140.401 Y110.399 E.01317
G1 X133.885 Y116.914 E.28427
G1 X133.885 Y116.379 E.01652
G1 X140.261 Y110.003 E.2782
G2 X140.115 Y109.614 I-3.775 J1.195 E.01284
G1 X133.885 Y115.843 E.27182
G1 X133.885 Y115.308 E.01652
G1 X139.953 Y109.24 E.26475
G2 X139.787 Y108.871 I-3.508 J1.354 E.0125
G1 X133.885 Y114.773 E.2575
G1 X133.885 Y114.237 E.01652
G1 X139.609 Y108.514 E.24972
G2 X139.421 Y108.166 I-3.468 J1.641 E.0122
G1 X133.885 Y113.702 E.24155
G1 X133.885 Y113.166 E.01652
G1 X139.228 Y107.824 E.2331
G2 X139.022 Y107.494 I-3.315 J1.841 E.01199
G1 X133.885 Y112.631 E.22412
G1 X133.885 Y112.095 E.01652
G1 X138.812 Y107.169 E.21496
G1 X138.589 Y106.856 E.01185
G1 X133.885 Y111.56 E.20525
G1 X133.885 Y111.024 E.01652
G1 X138.362 Y106.548 E.19531
G1 X138.125 Y106.249 E.01176
G1 X133.87 Y110.504 E.18565
G1 X133.633 Y110.206 E.01175
G1 X137.88 Y105.959 E.18533
G1 X137.63 Y105.674 E.01171
G1 X133.395 Y109.909 E.18477
G2 X133.139 Y109.629 I-1.942 J1.518 E.0117
G1 X137.368 Y105.4 E.18451
G2 X137.103 Y105.13 I-2.779 J2.462 E.01169
G1 X132.871 Y109.361 E.18462
G1 X132.593 Y109.104 E.01169
G1 X136.825 Y104.872 E.18465
G2 X136.543 Y104.619 I-2.574 J2.582 E.0117
G1 X132.293 Y108.868 E.18541
G2 X131.982 Y108.644 I-1.604 J1.903 E.01185
G1 X136.251 Y104.375 E.18627
G2 X135.952 Y104.139 I-2.423 J2.755 E.01177
G1 X131.658 Y108.433 E.18737
G1 X131.315 Y108.241 E.01213
G1 X135.646 Y103.909 E.18898
G2 X135.329 Y103.69 I-2.28 J2.956 E.01188
G1 X130.955 Y108.065 E.19088
G2 X130.579 Y107.905 I-1.224 J2.347 E.0126
G1 X135.009 Y103.475 E.19328
G1 X134.675 Y103.274 E.01204
G1 X130.188 Y107.761 E.19578
G1 X129.772 Y107.642 E.01335
G1 X134.336 Y103.078 E.19915
G1 X133.986 Y102.892 E.01221
G1 X129.333 Y107.545 E.20305
G2 X128.87 Y107.473 I-.699 J2.959 E.01448
G1 X133.628 Y102.714 E.20762
G1 X133.263 Y102.544 E.01243
G1 X128.378 Y107.429 E.21316
G2 X127.851 Y107.421 I-.319 J3.404 E.01627
G1 X132.884 Y102.388 E.2196
G2 X132.499 Y102.237 I-1.65 J3.659 E.01276
G1 X127.28 Y107.457 E.22773
G2 X126.652 Y107.548 I.263 J3.985 E.01958
G1 X132.102 Y102.099 E.23776
G2 X131.693 Y101.973 I-1.429 J3.896 E.01321
G1 X125.946 Y107.719 E.25074
G2 X125.082 Y108.048 I2.796 J8.648 E.02854
G1 X131.276 Y101.854 E.27026
G1 X130.842 Y101.752 E.01374
G1 X115.252 Y117.343 E.68025
G2 X115.357 Y117.773 I4.232 J-.802 E.01368
G1 X121.539 Y111.591 E.26975
G2 X121.225 Y112.441 I5.345 J2.46 E.02798
G1 X115.47 Y118.195 E.25108
G1 X115.6 Y118.601 E.01315
G1 X121.043 Y113.158 E.23749
G2 X120.955 Y113.782 I4.12 J.901 E.01945
G1 X115.738 Y118.998 E.2276
G1 X115.885 Y119.387 E.01282
G1 X120.919 Y114.352 E.21966
G2 X120.927 Y114.88 I3.416 J.21 E.01628
G1 X116.046 Y119.761 E.21298
G2 X116.213 Y120.129 I3.662 J-1.436 E.01249
G1 X120.97 Y115.373 E.20755
G1 X121.042 Y115.836 E.01447
G1 X116.392 Y120.486 E.2029
G2 X116.579 Y120.835 I3.473 J-1.64 E.01221
G1 X121.143 Y116.271 E.19914
G2 X121.265 Y116.684 I2.738 J-.582 E.01331
G1 X116.772 Y121.177 E.19601
G2 X116.978 Y121.506 I3.294 J-1.832 E.01199
G1 X121.406 Y117.079 E.19318
G2 X121.562 Y117.457 I2.456 J-.794 E.01266
G1 X117.188 Y121.832 E.19086
G1 X117.411 Y122.145 E.01185
G1 X121.741 Y117.815 E.18893
G2 X121.936 Y118.155 I2.301 J-1.091 E.01212
G1 X117.638 Y122.452 E.1875
G1 X117.875 Y122.751 E.01176
G1 X122.144 Y118.482 E.18628
G1 X122.366 Y118.796 E.01185
G1 X118.12 Y123.042 E.18526
G1 X118.37 Y123.327 E.01171
G1 X122.607 Y119.09 E.18487
G2 X122.861 Y119.372 I1.954 J-1.5 E.01171
G1 X118.632 Y123.6 E.1845
G2 X118.897 Y123.871 I2.766 J-2.446 E.01169
G1 X123.126 Y119.642 E.18449
G1 X123.41 Y119.893 E.0117
G1 X119.175 Y124.128 E.18477
G2 X119.457 Y124.381 I2.599 J-2.608 E.0117
G1 X123.708 Y120.131 E.18546
G2 X124.017 Y120.358 I1.578 J-1.825 E.01183
G1 X119.749 Y124.625 E.18619
G2 X120.048 Y124.861 I2.441 J-2.781 E.01177
G1 X124.343 Y120.566 E.1874
G2 X124.687 Y120.758 I1.415 J-2.132 E.01215
G1 X120.354 Y125.091 E.18905
G2 X120.671 Y125.31 I2.276 J-2.953 E.01188
G1 X125.045 Y120.936 E.19085
G2 X125.418 Y121.098 I1.241 J-2.34 E.01256
G1 X120.991 Y125.525 E.19315
G1 X121.326 Y125.726 E.01204
G1 X125.814 Y121.237 E.19586
G2 X126.231 Y121.356 I.979 J-2.629 E.01337
G1 X121.664 Y125.923 E.19923
G1 X122.014 Y126.109 E.01221
G1 X126.668 Y121.454 E.20307
G2 X127.13 Y121.527 I.719 J-3.054 E.01446
G1 X122.373 Y126.285 E.2076
G1 X122.738 Y126.455 E.01243
G1 X127.62 Y121.573 E.21304
G2 X128.147 Y121.582 I.322 J-3.406 E.01626
G1 X123.116 Y126.613 E.2195
G2 X123.501 Y126.763 I1.65 J-3.662 E.01276
G1 X128.718 Y121.546 E.2276
G2 X129.348 Y121.452 I-.297 J-4.123 E.01968
G1 X123.899 Y126.901 E.23776
G2 X124.308 Y127.027 I1.431 J-3.906 E.01322
G1 X130.06 Y121.275 E.25097
G2 X130.919 Y120.951 I-2.165 J-7.044 E.02836
G1 X124.586 Y127.285 E.27635
G1 X115.016 Y117.043 F36000
G1 F15000
G1 X130.397 Y101.662 E.67112
G2 X129.941 Y101.582 I-1 J4.389 E.01429
G1 X115.085 Y116.439 E.64823
G3 X115.022 Y115.966 I4.562 J-.844 E.01472
G1 X129.467 Y101.521 E.63027
G2 X128.976 Y101.477 I-.677 J4.742 E.01522
G1 X114.973 Y115.479 E.61098
G1 X114.947 Y114.97 E.01573
G1 X128.469 Y101.448 E.59002
G2 X127.944 Y101.437 I-.363 J5.106 E.01621
G1 X114.94 Y114.442 E.56741
G3 X114.954 Y113.892 I5.333 J-.139 E.01697
G1 X127.395 Y101.451 E.54283
G2 X126.818 Y101.492 I.106 J5.558 E.01784
G1 X114.993 Y113.318 E.51599
G3 X115.061 Y112.715 I5.895 J.359 E.01875
G1 X126.213 Y101.562 E.4866
G2 X125.573 Y101.667 I.699 J6.275 E.02003
G1 X115.165 Y112.075 E.45413
G3 X115.313 Y111.391 I6.706 J1.101 E.02162
G1 X124.889 Y101.815 E.4178
G2 X124.15 Y102.019 I1.602 J7.269 E.02364
G1 X115.52 Y110.649 E.37656
G3 X115.804 Y109.83 I7.988 J2.307 E.02675
G1 X123.335 Y102.298 E.32862
G2 X122.394 Y102.704 I3.467 J9.336 E.03164
G1 X116.199 Y108.899 E.2703
G3 X116.82 Y107.742 I15.308 J7.477 E.04052
G1 X121.233 Y103.33 E.19252
G2 X118.899 Y105.128 I6.918 J11.391 E.09107
G1 X117.278 Y106.749 E.07074
; CHANGE_LAYER
; Z_HEIGHT: 12.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X118.692 Y105.335 E-.76
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
G1 X133.16 Y118.223
G1 Z12.6
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X127.574 Y108.154 I-5.156 J-3.724 E.78549
G3 X133.16 Y110.777 I.408 J6.392 E.19785
G1 X133.16 Y118.163 E.22696
; WIPE_START
M204 S10000
G1 X132.813 Y118.658 E-.22946
G1 X132.479 Y119.016 E-.18633
G1 X132.117 Y119.348 E-.18636
G1 X131.791 Y119.604 E-.15785
; WIPE_END
G1 E-.04 F1800
G1 X139.419 Y119.364 Z13 F36000
G1 X140.916 Y119.317 Z13
G1 Z12.6
G1 E.8 F1800
G1 F12000
M204 S6000
G1 X140.771 Y119.694 E.01241
G3 X128 Y100.71 I-12.771 J-5.196 E1.83273
G1 X128.71 Y100.728 E.02182
G3 X141.021 Y119.03 I-.71 J13.769 E.78554
G1 X140.937 Y119.261 E.00756
; WIPE_START
M204 S10000
G1 X140.771 Y119.694 E-.17628
G1 X140.49 Y120.346 E-.26984
G1 X140.172 Y120.981 E-.26987
G1 X140.115 Y121.082 E-.04401
; WIPE_END
G1 E-.04 F1800
G1 X139.737 Y113.459 Z13 F36000
G1 X139.425 Y107.163 Z13
G1 Z12.6
G1 E.8 F1800
; FEATURE: Top surface
G1 F12000
M204 S2000
G1 X135.326 Y103.064 E.17815
; WIPE_START
M204 S10000
G1 X136.74 Y104.478 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.087 Y102.358 Z13 F36000
G1 Z12.6
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X140.133 Y108.404 E.2627
G1 X140.584 Y109.388
G1 X133.12 Y101.924 E.32434
G1 X132.272 Y101.61
G1 X140.889 Y110.227 E.37443
G1 X141.116 Y110.987
G1 X131.509 Y101.38 E.41746
G1 X130.807 Y101.212
G1 X141.284 Y111.688 E.45525
G1 X141.406 Y112.343
G1 X130.153 Y101.091 E.48898
G1 X129.537 Y101.008
G1 X141.491 Y112.962 E.51948
G1 X141.547 Y113.551
G1 X128.951 Y100.955 E.54736
G1 X128.39 Y100.928
G1 X141.576 Y114.113 E.57299
G1 X141.578 Y114.649
G1 X127.851 Y100.921 E.59651
G1 X127.331 Y100.935
G1 X141.562 Y115.166 E.61839
G1 X141.53 Y115.667
G1 X126.835 Y100.972 E.63858
G1 X126.352 Y101.022
G1 X141.48 Y116.15 E.65739
G1 X141.412 Y116.616
G1 X125.881 Y101.085 E.67491
G1 X125.43 Y101.167
G1 X141.334 Y117.071 E.69111
G1 X141.242 Y117.512
G1 X124.989 Y101.26 E.70625
G1 X124.558 Y101.361
G1 X141.135 Y117.939 E.72037
G1 X141.021 Y118.358
G1 X133.367 Y110.703 E.33263
G1 X133.367 Y111.237
G1 X140.892 Y118.762 E.327
G1 X140.755 Y119.158
G1 X133.367 Y111.771 E.32102
G1 X133.367 Y112.304
G1 X140.609 Y119.545 E.31468
G1 X140.45 Y119.919
G1 X133.367 Y112.837 E.30776
G1 X133.367 Y113.37
G1 X140.286 Y120.289 E.30065
G1 X140.108 Y120.645
G1 X133.367 Y113.904 E.29293
G1 X133.367 Y114.437
G1 X139.926 Y120.995 E.28499
G1 X139.733 Y121.336
G1 X133.367 Y114.97 E.27662
G1 X133.367 Y115.503
G1 X139.532 Y121.668 E.2679
G1 X139.325 Y121.994
G1 X133.367 Y116.037 E.25889
G1 X133.367 Y116.57
G1 X139.107 Y122.31 E.24943
G1 X138.886 Y122.622
G1 X133.367 Y117.103 E.2398
G1 X133.367 Y117.636
G1 X138.652 Y122.921 E.22962
G1 X138.415 Y123.217
G1 X133.367 Y118.17 E.21935
G1 X133.187 Y118.522
G1 X138.166 Y123.501 E.21637
G1 X137.913 Y123.782
M73 P98 R0
G1 X132.948 Y118.817 E.21577
G1 X132.691 Y119.093
G1 X137.65 Y124.052 E.21552
G1 X137.382 Y124.317
G1 X132.418 Y119.353 E.21572
G1 X132.132 Y119.6
G1 X137.105 Y124.574 E.21613
G1 X136.821 Y124.823
G1 X131.831 Y119.833 E.21684
G1 X131.512 Y120.047
G1 X136.531 Y125.066 E.21811
G1 X136.231 Y125.299
G1 X131.175 Y120.244 E.21969
G1 X130.823 Y120.425
G1 X135.926 Y125.528 E.22175
G1 X135.61 Y125.745
G1 X130.454 Y120.589 E.22405
G1 X130.066 Y120.734
G1 X135.291 Y125.959 E.22707
G1 X134.958 Y126.16
G1 X129.652 Y120.854 E.23057
G1 X129.216 Y120.95
G1 X134.622 Y126.357 E.23494
G1 X134.274 Y126.542
G1 X128.752 Y121.02 E.23996
G1 X128.257 Y121.058
G1 X133.92 Y126.721 E.24608
G1 X133.557 Y126.891
G1 X127.723 Y121.058 E.25349
G1 X127.141 Y121.009
G1 X133.183 Y127.05 E.26254
G1 X132.804 Y127.204
G1 X126.488 Y120.889 E.27444
G1 X125.722 Y120.656
G1 X132.408 Y127.343 E.29058
G1 X132.008 Y127.475
G1 X124.722 Y120.189 E.3166
; WIPE_START
M204 S10000
G1 X126.136 Y121.603 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.312 Y114.663 Z13 F36000
G1 X131.828 Y109.165 Z13
G1 Z12.6
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X124.144 Y101.481 E.3339
G1 X123.737 Y101.607
G1 X130.603 Y108.473 E.29837
G1 X129.78 Y108.183
G1 X123.341 Y101.745 E.27979
G1 X122.957 Y101.893
G1 X129.087 Y108.023 E.26639
G1 X128.483 Y107.953
G1 X122.578 Y102.047 E.25663
G1 X122.214 Y102.217
G1 X127.934 Y107.936 E.24855
G1 X127.425 Y107.961
G1 X121.854 Y102.39 E.24211
G1 X121.506 Y102.575
G1 X126.951 Y108.02 E.23661
G1 X126.504 Y108.107
G1 X121.164 Y102.767 E.23205
G1 X120.831 Y102.967
G1 X126.083 Y108.219 E.22822
G1 X125.687 Y108.356
G1 X120.507 Y103.176 E.2251
G1 X120.188 Y103.391
G1 X125.311 Y108.513 E.2226
G1 X124.952 Y108.688
G1 X119.881 Y103.617 E.22036
G1 X119.576 Y103.845
G1 X124.609 Y108.878 E.21871
G1 X124.284 Y109.086
G1 X119.285 Y104.088 E.21721
G1 X118.997 Y104.332
G1 X123.978 Y109.313 E.21646
G1 X123.686 Y109.554
G1 X118.72 Y104.588 E.2158
G1 X118.447 Y104.849
G1 X123.407 Y109.809 E.21557
G1 X123.144 Y110.08
G1 X118.183 Y105.119 E.21558
G1 X117.926 Y105.394
G1 X122.9 Y110.369 E.21615
G1 X122.67 Y110.671
G1 X117.677 Y105.678 E.21697
G1 X117.435 Y105.97
G1 X122.453 Y110.988 E.21807
G1 X122.254 Y111.322
G1 X117.199 Y106.268 E.21963
G1 X116.974 Y106.576
G1 X122.075 Y111.676 E.22164
G1 X121.913 Y112.047
G1 X116.753 Y106.887 E.22423
G1 X116.544 Y107.212
G1 X121.769 Y112.437 E.22707
G1 X121.647 Y112.848
G1 X116.338 Y107.539 E.2307
G1 X116.145 Y107.88
G1 X121.548 Y113.282 E.23477
G1 X121.476 Y113.744
G1 X115.957 Y108.225 E.23983
G1 X115.779 Y108.58
G1 X121.438 Y114.239 E.24589
G1 X121.439 Y114.773
G1 X115.61 Y108.944 E.25329
G1 X115.448 Y109.315
G1 X121.492 Y115.36 E.26265
G1 X121.615 Y116.015
G1 X115.299 Y109.7 E.27445
G1 X115.155 Y110.089
G1 X121.84 Y116.775 E.29051
G1 X122.318 Y117.785
G1 X115.026 Y110.493 E.31685
G1 X114.906 Y110.906
G1 X131.595 Y127.595 E.72522
G1 X131.169 Y127.703
G1 X114.794 Y111.328 E.71157
G1 X114.7 Y111.767
G1 X130.736 Y127.803 E.69684
G1 X130.285 Y127.885
G1 X114.614 Y112.215 E.68096
G1 X114.542 Y112.676
G1 X129.822 Y127.955 E.66396
G1 X129.347 Y128.014
G1 X114.489 Y113.156 E.64568
G1 X114.448 Y113.648
G1 X128.852 Y128.053 E.62595
G1 X128.34 Y128.074
G1 X114.422 Y114.155 E.60482
G1 X114.422 Y114.689
G1 X127.811 Y128.078 E.58181
G1 X127.261 Y128.061
G1 X114.442 Y115.242 E.55706
G1 X114.486 Y115.819
G1 X126.683 Y128.017 E.53004
G1 X126.076 Y127.942
G1 X114.558 Y116.425 E.5005
G1 X114.665 Y117.064
G1 X125.434 Y127.834 E.468
G1 X124.751 Y127.684
G1 X114.814 Y117.747 E.43182
G1 X115.019 Y118.485
G1 X124.015 Y127.482 E.39093
G1 X123.21 Y127.21
G1 X115.298 Y119.297 E.34385
G1 X115.678 Y120.21
G1 X122.283 Y126.816 E.28704
G1 X121.171 Y126.237
G1 X116.263 Y121.329 E.21328
; WIPE_START
M204 S10000
G1 X117.678 Y122.744 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.73 Y118.094 Z13 F36000
G1 X133.427 Y110.643 Z13
G1 Z12.6
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.224024
G1 F15000
G1 X133.218 Y110.41 E.00462
; LINE_WIDTH: 0.177228
G1 X132.655 Y109.809 E.00901
G1 X132.283 Y109.453 E.00564
; LINE_WIDTH: 0.197023
G1 X132.086 Y109.278 E.00331
; LINE_WIDTH: 0.222793
G1 X131.889 Y109.104 E.00386
; WIPE_START
G1 X132.086 Y109.278 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.699 Y116.528 Z13 F36000
G1 X128.183 Y121.132 Z13
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.113849
G1 F15000
G1 X127.982 Y121.049 E.00126
; WIPE_START
G1 X128.183 Y121.132 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X125.658 Y120.719 Z13 F36000
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.200196
G1 F15000
G1 X125.568 Y120.662 E.00137
; LINE_WIDTH: 0.176376
G1 X125.483 Y120.604 E.00112
; LINE_WIDTH: 0.141091
G1 X125.398 Y120.545 E.00082
; LINE_WIDTH: 0.105806
G1 X125.313 Y120.487 E.00053
M73 P99 R0
G1 X124.66 Y120.251 F36000
; LINE_WIDTH: 0.200713
G1 F15000
G1 X124.451 Y120.083 E.00345
; LINE_WIDTH: 0.15227
G1 X124.24 Y119.913 E.00242
; LINE_WIDTH: 0.108036
G1 X124.008 Y119.712 E.00163
; WIPE_START
G1 X124.24 Y119.913 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X122.773 Y118.477 Z13 F36000
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.107145
G1 F15000
G1 X122.62 Y118.296 E.00124
; LINE_WIDTH: 0.145492
G1 X122.464 Y118.111 E.00202
; LINE_WIDTH: 0.180097
G1 X122.36 Y117.979 E.00188
; LINE_WIDTH: 0.210115
G1 X122.257 Y117.846 E.00229
; WIPE_START
G1 X122.36 Y117.979 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X121.7 Y116.345 Z13 F36000
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.125814
G1 F15000
G1 X121.547 Y116.083 E.00205
; WIPE_START
G1 X121.7 Y116.345 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X126.383 Y110.319 Z13 F36000
G1 X128.219 Y107.956 Z13
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.164847
G1 F15000
G1 X128.067 Y107.89 E.00165
G1 X127.917 Y107.953 E.00161
; WIPE_START
G1 X128.067 Y107.89 E-.37559
G1 X128.219 Y107.956 E-.38441
; WIPE_END
G1 E-.04 F1800
G1 X131.06 Y108.691 Z13 F36000
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.0960676
G1 F15000
G1 X130.995 Y108.642 E.00035
; LINE_WIDTH: 0.1226
G1 X130.885 Y108.565 E.00087
; LINE_WIDTH: 0.159333
G1 X130.775 Y108.488 E.00127
; LINE_WIDTH: 0.196067
G1 X130.665 Y108.411 E.00167
; WIPE_START
G1 X130.775 Y108.488 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X125.058 Y113.545 Z13 F36000
G1 X116.325 Y121.268 Z13
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.204547
G1 F15000
G1 X116.225 Y121.138 E.00217
; LINE_WIDTH: 0.168368
G1 X116.125 Y121.007 E.00168
; LINE_WIDTH: 0.132188
G1 X116.026 Y120.876 E.0012
; LINE_WIDTH: 0.101132
G1 X115.965 Y120.792 E.00049
; WIPE_START
G1 X116.026 Y120.876 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X115.354 Y119.241 Z13 F36000
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.0960274
G1 F15000
G1 X115.153 Y118.911 E.00167
; WIPE_START
G1 X115.354 Y119.241 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X120.638 Y113.733 Z13 F36000
G1 X132.209 Y101.673 Z13
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.197607
G1 F15000
G1 X131.919 Y101.491 E.00431
; WIPE_START
G1 X132.209 Y101.673 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.026 Y102.42 Z13 F36000
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.19432
G1 F15000
G1 X133.895 Y102.328 E.00197
; LINE_WIDTH: 0.151859
G1 X133.764 Y102.237 E.00142
; LINE_WIDTH: 0.109398
G1 X133.634 Y102.145 E.00086
; WIPE_START
G1 X133.764 Y102.237 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.266 Y103.124 Z13 F36000
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.204047
G1 F15000
G1 X135.086 Y102.983 E.003
; LINE_WIDTH: 0.157697
G1 X134.906 Y102.842 E.00214
; LINE_WIDTH: 0.111347
G1 X134.725 Y102.702 E.00127
; WIPE_START
G1 X134.906 Y102.842 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X138.687 Y106.128 Z13 F36000
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.111001
G1 F15000
G1 X138.409 Y105.816 E.00231
; LINE_WIDTH: 0.15629
G1 X137.932 Y105.307 E.00645
; LINE_WIDTH: 0.178758
G2 X136.94 Y104.328 I-19.487 J18.748 E.01543
; LINE_WIDTH: 0.145064
G1 X136.682 Y104.092 E.00291
; LINE_WIDTH: 0.109321
G2 X136.356 Y103.797 I-5.891 J6.188 E.00238
; WIPE_START
G1 X136.682 Y104.092 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X139.79 Y107.767 Z13 F36000
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.10681
G1 F15000
G1 X139.7 Y107.648 E.00078
; LINE_WIDTH: 0.144079
G1 X139.609 Y107.529 E.00123
; LINE_WIDTH: 0.178994
G1 X139.487 Y107.377 E.00217
; LINE_WIDTH: 0.211547
G1 X139.365 Y107.224 E.00269
; WIPE_START
G1 X139.487 Y107.377 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X137.437 Y114.728 Z13 F36000
G1 X134.112 Y126.65 Z13
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.103668
G1 F15000
G1 X134.053 Y126.639 E.0003
G1 X133.969 Y126.698 E.00051
; WIPE_START
G1 X134.053 Y126.639 E-.4788
G1 X134.112 Y126.65 E-.2812
; WIPE_END
G1 E-.04 F1800
G1 X126.484 Y126.894 Z13 F36000
G1 X122.717 Y127.015 Z13
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.164713
G1 F15000
G1 X122.531 Y126.884 E.00225
; LINE_WIDTH: 0.198094
G1 X122.345 Y126.754 E.00287
; WIPE_START
G1 X122.531 Y126.884 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X120.364 Y125.725 Z13 F36000
G1 Z12.6
G1 E.8 F1800
; LINE_WIDTH: 0.113087
G1 F15000
G1 X120.147 Y125.547 E.00161
; LINE_WIDTH: 0.162723
G1 X119.883 Y125.318 E.00341
; LINE_WIDTH: 0.212153
G1 X119.619 Y125.089 E.00482
; LINE_WIDTH: 0.252527
G1 X119.362 Y124.854 E.00594
; LINE_WIDTH: 0.283865
G1 X119.106 Y124.62 E.00683
; LINE_WIDTH: 0.317382
G3 X118.119 Y123.646 I18.409 J-19.635 E.03101
; LINE_WIDTH: 0.295024
G1 X117.644 Y123.139 E.01426
; LINE_WIDTH: 0.25252
G1 X117.412 Y122.879 E.00595
; LINE_WIDTH: 0.212167
G1 X117.181 Y122.619 E.0048
; LINE_WIDTH: 0.174692
G1 X117.042 Y122.455 E.0023
; LINE_WIDTH: 0.140085
G1 X116.904 Y122.291 E.0017
; LINE_WIDTH: 0.105478
G1 X116.765 Y122.127 E.00109
; close powerlost recovery
M1003 S0
; WIPE_START
G1 F15000
G1 X116.904 Y122.291 E-.76
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
G0 Z13.4 F900

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

    
        G1 Z86.3 F600
        G1 Z84.3
    

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

