; HEADER_BLOCK_START
; BambuStudio 02.04.00.70
; model printing time: 9m 45s; total estimated time: 17m 41s
; total layer number: 50
; total filament length [mm] : 1485.25
; total filament volume [cm^3] : 3572.45
; total filament weight [g] : 4.50
; filament_density: 1.26
; filament_diameter: 1.75
; max_z_height: 10.00
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
M73 P0 R17
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
M73 P7 R16
  G1 Z5 F1200
  G90
  M400
  G150.1
;===== wipe left nozzle end =====


;===== mech mode sweep start =====
  M1002 gcode_claim_action : 3
  G90
M73 P8 R16
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
    
      G29 A1 X85.15 Y118 I85.7 J20
    
    M400
    M500 ; save cali data
  M623
    
  M622 J2
    M1002 gcode_claim_action : 1
    
      G29 A2 X85.15 Y118 I85.7 J20
    
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
M73 P9 R16
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
M73 P44 R9
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
G1 X129.957 Y123.143
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.5
G1 F3000
M204 S500
G1 X129.957 Y132.857 E.36181
G1 X125.043 Y132.857 E.18303
G1 X125.043 Y123.143 E.36181
G1 X129.897 Y123.143 E.1808
M204 S6000
G1 X129.5 Y123.6 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X129.5 Y132.4 E.32777
G1 X125.5 Y132.4 E.14898
G1 X125.5 Y123.6 E.32777
G1 X129.44 Y123.6 E.14675
; WIPE_START
G1 X129.454 Y125.6 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X123.389 Y130.234 Z.6 F36000
G1 X119.957 Y132.857 Z.6
G1 Z.2
M73 P45 R9
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X115.043 Y132.857 E.18303
G1 X115.043 Y123.143 E.36181
G1 X119.957 Y123.143 E.18303
G1 X119.957 Y132.797 E.35958
M204 S6000
G1 X119.5 Y132.4 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X115.5 Y132.4 E.14898
G1 X115.5 Y123.6 E.32777
G1 X119.5 Y123.6 E.14898
G1 X119.5 Y132.34 E.32553
; WIPE_START
G1 X117.5 Y132.37 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X110.849 Y128.626 Z.6 F36000
G1 X105.74 Y125.749 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X105.759 Y125.73 E.00098
G3 X107.127 Y125.166 I1.736 J2.267 E.05577
G1 X107.491 Y125.142 E.01359
G3 X105.477 Y125.977 I.004 J2.856 E.58499
G1 X105.695 Y125.788 E.01073
M204 S6000
G1 X106.03 Y126.102 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X106.037 Y126.094 E.00042
G3 X107.187 Y125.62 I1.458 J1.904 E.04683
G1 X107.492 Y125.6 E.01139
G3 X105.801 Y126.301 I.004 J2.398 E.49128
G1 X105.985 Y126.142 E.00906
; WIPE_START
G1 X106.037 Y126.094 E-.02701
G1 X106.3 Y125.921 E-.11935
G1 X106.581 Y125.782 E-.11933
G1 X106.879 Y125.681 E-.11934
G1 X107.187 Y125.62 E-.11931
G1 X107.492 Y125.6 E-.11618
G1 X107.813 Y125.62 E-.12224
G1 X107.857 Y125.628 E-.01725
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X115.406 Y126.757 Z.6 F36000
G1 X135.217 Y129.719 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X135.024 Y129.429 E.01295
G3 X137.127 Y125.166 I2.471 J-1.432 E.20919
G1 X137.491 Y125.142 E.01359
G3 X135.253 Y129.767 I.004 J2.856 E.43032
M204 S6000
G1 X135.602 Y129.47 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X135.596 Y129.461 E.00041
G3 X137.187 Y125.62 I1.9 J-1.463 E.18739
G1 X137.492 Y125.6 E.01139
G3 X135.803 Y129.697 I.004 J2.398 E.35074
G1 X135.642 Y129.515 E.00905
; WIPE_START
G1 X135.596 Y129.461 E-.02693
G1 X135.421 Y129.2 E-.11931
G1 X135.282 Y128.919 E-.11932
G1 X135.181 Y128.621 E-.11935
G1 X135.12 Y128.313 E-.11935
G1 X135.099 Y128 E-.11935
G1 X135.12 Y127.687 E-.11933
G1 X135.128 Y127.643 E-.01707
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X127.518 Y128.218 Z.6 F36000
G1 X92.707 Y130.851 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X92.707 Y125.149 E.21234
G1 X86.007 Y125.149 E.24955
G1 X86.007 Y122.861 E.08524
G1 X99.557 Y122.861 E.50469
G1 X99.557 Y120.86 E.07451
G1 X145.443 Y120.86 E1.70908
G1 X145.443 Y122.861 E.07451
G1 X160.707 Y122.861 E.56853
G1 X160.707 Y118.86 E.14902
G1 X161.993 Y118.86 E.04789
G1 X161.993 Y124.862 E.22354
G1 X169.993 Y124.862 E.29797
G1 X169.993 Y131.138 E.23378
G1 X161.993 Y131.138 E.29797
G1 X161.993 Y137.14 E.22354
G1 X160.707 Y137.14 E.04789
G1 X160.707 Y133.139 E.14902
G1 X145.443 Y133.139 E.56853
G1 X145.443 Y135.14 E.07451
G1 X99.557 Y135.14 E1.70908
G1 X99.557 Y133.139 E.07451
G1 X86.007 Y133.139 E.50469
G1 X86.007 Y130.851 E.08524
G1 X92.647 Y130.851 E.24731
M204 S6000
G1 X92.25 Y130.393 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X92.25 Y125.607 E.17829
G1 X85.55 Y125.607 E.24955
G1 X85.55 Y122.404 E.11929
M73 P46 R9
G1 X99.1 Y122.404 E.50469
G1 X99.1 Y120.403 E.07451
G1 X145.9 Y120.403 E1.74312
G1 X145.9 Y122.404 E.07451
G1 X160.25 Y122.404 E.53448
G1 X160.25 Y118.403 E.14902
G1 X162.45 Y118.403 E.08194
G1 X162.45 Y124.405 E.22354
G1 X170.45 Y124.405 E.29797
G1 X170.45 Y131.595 E.26783
G1 X162.45 Y131.595 E.29797
G1 X162.45 Y137.597 E.22354
G1 X160.25 Y137.597 E.08194
G1 X160.25 Y133.596 E.14902
G1 X145.9 Y133.596 E.53448
G1 X145.9 Y135.597 E.07451
G1 X99.1 Y135.597 E1.74312
G1 X99.1 Y133.596 E.07451
G1 X85.55 Y133.596 E.50469
G1 X85.55 Y130.393 E.11929
G1 X92.19 Y130.393 E.24731
; WIPE_START
G1 X92.215 Y128.394 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X99.785 Y127.419 Z.6 F36000
G1 X145.26 Y121.567 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Bottom surface
; LINE_WIDTH: 0.5024
G1 F6300
M204 S500
G1 X144.941 Y121.249 E.01687
G1 X144.292 Y121.249 E.02433
G1 X145.26 Y122.217 E.05128
; WIPE_START
G1 X144.292 Y121.249 E-.52044
G1 X144.922 Y121.249 E-.23956
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X152.483 Y120.207 Z.6 F36000
G1 X160.93 Y119.043 Z.6
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X161.604 Y119.717 E.03571
G1 X161.604 Y120.367 E.02433
G1 X161.096 Y119.858 E.02694
G1 X161.096 Y120.508 E.02433
G1 X161.604 Y121.017 E.02694
G1 X161.604 Y121.667 E.02433
G1 X161.096 Y121.158 E.02694
G1 X161.096 Y121.808 E.02433
G1 X161.604 Y122.317 E.02694
G1 X161.604 Y122.966 E.02433
G1 X161.096 Y122.457 E.02694
G1 X161.096 Y123.107 E.02433
G1 X161.604 Y123.616 E.02694
G1 X161.604 Y124.266 E.02433
G1 X160.382 Y123.044 E.06472
; WIPE_START
G1 X161.604 Y124.266 E-.65683
G1 X161.604 Y123.994 E-.10317
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X168.881 Y125.045 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X169.604 Y125.768 E.0383
G1 X169.604 Y126.418 E.02433
G1 X168.437 Y125.25 E.06182
G1 X167.787 Y125.25 E.02433
G1 X169.604 Y127.068 E.09623
G1 X169.604 Y127.717 E.02433
G1 X167.137 Y125.25 E.13064
G1 X166.488 Y125.25 E.02433
G1 X169.604 Y128.367 E.16504
G1 X169.604 Y129.017 E.02433
G1 X165.838 Y125.25 E.19945
G1 X165.188 Y125.25 E.02433
G1 X169.604 Y129.667 E.23386
G1 X169.604 Y130.317 E.02433
G1 X164.538 Y125.25 E.26827
G1 X163.888 Y125.25 E.02433
G1 X169.388 Y130.75 E.29121
G1 X168.738 Y130.75 E.02433
G1 X163.238 Y125.25 E.29121
G1 X162.589 Y125.25 E.02433
G1 X168.088 Y130.75 E.29121
G1 X167.438 Y130.75 E.02433
G1 X159.938 Y123.249 E.39715
G1 X159.288 Y123.249 E.02433
G1 X166.789 Y130.75 E.39715
G1 X166.139 Y130.75 E.02433
G1 X158.638 Y123.249 E.39715
G1 X157.989 Y123.249 E.02433
M73 P47 R9
G1 X165.489 Y130.75 E.39715
G1 X164.839 Y130.75 E.02433
G1 X157.339 Y123.249 E.39715
G1 X156.689 Y123.249 E.02433
G1 X164.189 Y130.75 E.39715
G1 X163.54 Y130.75 E.02433
G1 X156.039 Y123.249 E.39715
G1 X155.389 Y123.249 E.02433
G1 X162.89 Y130.75 E.39715
G1 X162.24 Y130.75 E.02433
G1 X154.74 Y123.249 E.39715
G1 X154.09 Y123.249 E.02433
G1 X161.604 Y130.764 E.3979
G1 X161.604 Y131.414 E.02433
G1 X153.44 Y123.249 E.43231
G1 X152.79 Y123.249 E.02433
G1 X161.604 Y132.064 E.46672
G1 X161.604 Y132.713 E.02433
G1 X152.14 Y123.249 E.50112
G1 X151.491 Y123.249 E.02433
G1 X161.81 Y133.569 E.54642
M204 S6000
G1 X160.89 Y133.298 F36000
G1 F6300
M204 S500
G1 X161.604 Y134.013 E.03783
G1 X161.604 Y134.663 E.02433
G1 X161.096 Y134.154 E.02694
G1 X161.096 Y134.804 E.02433
G1 X161.604 Y135.313 E.02694
G1 X161.604 Y135.962 E.02433
G1 X161.096 Y135.454 E.02694
G1 X161.096 Y136.103 E.02433
G1 X161.81 Y136.818 E.03783
; WIPE_START
G1 X161.096 Y136.103 E-.38398
G1 X161.096 Y135.454 E-.24693
G1 X161.336 Y135.694 E-.12909
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X160.548 Y132.956 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X150.841 Y123.249 E.51399
G1 X150.191 Y123.249 E.02433
G1 X159.692 Y132.751 E.5031
G1 X159.042 Y132.751 E.02433
G1 X149.541 Y123.249 E.5031
G1 X148.891 Y123.249 E.02433
G1 X158.393 Y132.751 E.5031
G1 X157.743 Y132.751 E.02433
G1 X148.242 Y123.249 E.5031
G1 X147.592 Y123.249 E.02433
G1 X157.093 Y132.751 E.5031
G1 X156.443 Y132.751 E.02433
G1 X146.942 Y123.249 E.5031
G1 X146.292 Y123.249 E.02433
G1 X155.793 Y132.751 E.5031
G1 X155.144 Y132.751 E.02433
G1 X145.642 Y123.249 E.5031
G1 X145.054 Y123.249 E.02202
G1 X145.054 Y122.661 E.02202
G1 X143.642 Y121.249 E.0748
G1 X142.992 Y121.249 E.02433
G1 X154.494 Y132.751 E.60903
G1 X153.844 Y132.751 E.02433
G1 X142.342 Y121.249 E.60903
G1 X141.692 Y121.249 E.02433
G1 X153.194 Y132.751 E.60903
G1 X152.544 Y132.751 E.02433
G1 X141.043 Y121.249 E.60903
G1 X140.393 Y121.249 E.02433
G1 X151.895 Y132.751 E.60903
G1 X151.245 Y132.751 E.02433
G1 X139.743 Y121.249 E.60903
G1 X139.093 Y121.249 E.02433
G1 X150.595 Y132.751 E.60903
G1 X149.945 Y132.751 E.02433
G1 X138.443 Y121.249 E.60903
G1 X137.794 Y121.249 E.02433
G1 X149.295 Y132.751 E.60903
G1 X148.646 Y132.751 E.02433
M73 P48 R9
G1 X137.144 Y121.249 E.60903
G1 X136.494 Y121.249 E.02433
G1 X147.996 Y132.751 E.60903
G1 X147.346 Y132.751 E.02433
G1 X135.844 Y121.249 E.60903
G1 X135.194 Y121.249 E.02433
G1 X146.696 Y132.751 E.60903
G1 X146.046 Y132.751 E.02433
G1 X140.683 Y127.387 E.284
G3 X140.742 Y128.096 I-3.402 J.64 E.02668
G1 X145.397 Y132.751 E.24647
G1 X145.054 Y132.751 E.01281
G1 X145.054 Y133.058 E.01152
G1 X140.671 Y128.674 E.23213
G3 X140.523 Y129.177 I-1.983 J-.308 E.01966
G1 X145.054 Y133.708 E.23992
G1 X145.054 Y134.358 E.02433
G1 X140.316 Y129.619 E.25092
G1 X140.052 Y130.006 E.01751
G1 X144.798 Y134.751 E.25128
G1 X144.148 Y134.751 E.02433
G1 X139.742 Y130.345 E.23331
G3 X139.386 Y130.638 I-1.293 J-1.208 E.01733
G1 X143.498 Y134.751 E.21777
G1 X142.849 Y134.751 E.02433
G1 X138.981 Y130.884 E.20479
G3 X138.523 Y131.076 I-.959 J-1.645 E.01864
G1 X142.199 Y134.751 E.19462
G1 X141.549 Y134.751 E.02433
G1 X138.003 Y131.205 E.18778
G3 X137.389 Y131.241 I-.53 J-3.771 E.02304
G1 X141.105 Y134.957 E.19676
; WIPE_START
G1 X139.691 Y133.543 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X138.532 Y125.999 Z.6 F36000
G1 X138.393 Y125.098 Z.6
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X134.545 Y121.249 E.20379
G1 X133.895 Y121.249 E.02433
G1 X137.404 Y124.758 E.18581
G2 X136.826 Y124.829 I-.019 J2.232 E.02189
G1 X133.245 Y121.249 E.18959
G1 X132.595 Y121.249 E.02433
G1 X136.323 Y124.977 E.19739
G2 X135.881 Y125.184 I.568 J1.783 E.01834
G1 X131.945 Y121.249 E.20839
G1 X131.296 Y121.249 E.02433
G1 X135.494 Y125.448 E.22233
G2 X135.155 Y125.758 I1.008 J1.443 E.01727
G1 X130.646 Y121.249 E.23876
G1 X129.996 Y121.249 E.02433
G1 X134.862 Y126.114 E.25764
G2 X134.616 Y126.519 I1.414 J1.134 E.01776
G1 X129.346 Y121.249 E.27906
G1 X128.696 Y121.249 E.02433
G1 X134.424 Y126.977 E.3033
G2 X134.295 Y127.497 I1.913 J.751 E.02014
G1 X130.346 Y123.548 E.20913
G1 X130.346 Y124.198 E.02433
G1 X134.48 Y128.332 E.2189
; WIPE_START
G1 X133.065 Y126.917 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X130.14 Y124.642 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X134.375 Y128.876 E.22423
G2 X136.622 Y131.124 I3.109 J-.861 E.12442
G1 X140.249 Y134.751 E.19208
G1 X139.6 Y134.751 E.02433
G1 X130.346 Y125.497 E.49
G1 X130.346 Y126.147 E.02433
G1 X138.95 Y134.751 E.45559
G1 X138.3 Y134.751 E.02433
G1 X130.346 Y126.797 E.42119
G1 X130.346 Y127.447 E.02433
G1 X137.65 Y134.751 E.38678
G1 X137 Y134.751 E.02433
G1 X130.346 Y128.096 E.35237
G1 X130.346 Y128.746 E.02433
G1 X136.35 Y134.751 E.31796
G1 X135.701 Y134.751 E.02433
G1 X130.346 Y129.396 E.28356
G1 X130.346 Y130.046 E.02433
G1 X135.051 Y134.751 E.24915
G1 X134.401 Y134.751 E.02433
M73 P49 R9
G1 X130.346 Y130.696 E.21474
G1 X130.346 Y131.345 E.02433
G1 X133.751 Y134.751 E.18033
G1 X133.101 Y134.751 E.02433
G1 X130.346 Y131.995 E.14593
G1 X130.346 Y132.645 E.02433
G1 X132.452 Y134.751 E.11152
G1 X131.802 Y134.751 E.02433
G1 X130.296 Y133.246 E.07972
G1 X129.646 Y133.246 E.02433
G1 X131.152 Y134.751 E.07972
G1 X130.502 Y134.751 E.02433
G1 X128.997 Y133.246 E.07972
G1 X128.347 Y133.246 E.02433
G1 X129.852 Y134.751 E.07972
G1 X129.203 Y134.751 E.02433
G1 X127.697 Y133.246 E.07972
G1 X127.047 Y133.246 E.02433
M73 P49 R8
G1 X128.553 Y134.751 E.07972
G1 X127.903 Y134.751 E.02433
G1 X126.397 Y133.246 E.07972
G1 X125.748 Y133.246 E.02433
G1 X127.459 Y134.957 E.09061
; WIPE_START
G1 X126.045 Y133.543 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X128.572 Y126.341 Z.6 F36000
G1 X129.758 Y122.96 Z.6
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X128.047 Y121.249 E.09061
G1 X127.397 Y121.249 E.02433
G1 X128.902 Y122.754 E.07972
G1 X128.253 Y122.754 E.02433
G1 X126.747 Y121.249 E.07972
G1 X126.097 Y121.249 E.02433
G1 X127.603 Y122.754 E.07972
G1 X126.953 Y122.754 E.02433
G1 X125.447 Y121.249 E.07972
G1 X124.798 Y121.249 E.02433
G1 X126.303 Y122.754 E.07972
G1 X125.653 Y122.754 E.02433
G1 X124.148 Y121.249 E.07972
G1 X123.498 Y121.249 E.02433
G1 X125.004 Y122.754 E.07972
G1 X124.654 Y122.754 E.01307
G1 X124.654 Y123.055 E.01126
G1 X122.848 Y121.249 E.09564
G1 X122.198 Y121.249 E.02433
G1 X124.654 Y123.705 E.13005
G1 X124.654 Y124.355 E.02433
G1 X121.549 Y121.249 E.16446
G1 X120.899 Y121.249 E.02433
G1 X124.654 Y125.005 E.19886
G1 X124.654 Y125.654 E.02433
G1 X120.249 Y121.249 E.23327
G1 X119.599 Y121.249 E.02433
G1 X124.654 Y126.304 E.26768
G1 X124.654 Y126.954 E.02433
G1 X118.949 Y121.249 E.30209
G1 X118.3 Y121.249 E.02433
G1 X119.805 Y122.754 E.07972
G1 X120.346 Y122.754 E.02023
G1 X120.346 Y123.295 E.02023
G1 X124.654 Y127.604 E.22816
G1 X124.654 Y128.254 E.02433
G1 X120.346 Y123.945 E.22816
G1 X120.346 Y124.594 E.02433
G1 X124.654 Y128.903 E.22816
G1 X124.654 Y129.553 E.02433
G1 X120.346 Y125.244 E.22816
G1 X120.346 Y125.894 E.02433
G1 X124.654 Y130.203 E.22816
G1 X124.654 Y130.853 E.02433
G1 X120.346 Y126.544 E.22816
G1 X120.346 Y127.194 E.02433
G1 X124.654 Y131.503 E.22816
G1 X124.654 Y132.152 E.02433
G1 X120.346 Y127.843 E.22816
G1 X120.346 Y128.493 E.02433
G1 X124.654 Y132.802 E.22816
G1 X124.654 Y133.246 E.0166
G1 X125.098 Y133.246 E.0166
G1 X126.603 Y134.751 E.07972
G1 X125.954 Y134.751 E.02433
G1 X120.346 Y129.143 E.29695
G1 X120.346 Y129.793 E.02433
G1 X125.304 Y134.751 E.26254
G1 X124.654 Y134.751 E.02433
G1 X120.346 Y130.443 E.22814
G1 X120.346 Y131.092 E.02433
G1 X124.004 Y134.751 E.19373
G1 X123.354 Y134.751 E.02433
G1 X120.346 Y131.742 E.15932
G1 X120.346 Y132.392 E.02433
G1 X122.705 Y134.751 E.12491
G1 X122.055 Y134.751 E.02433
G1 X120.346 Y133.042 E.09051
G1 X120.346 Y133.246 E.00763
G1 X119.899 Y133.246 E.0167
G1 X121.405 Y134.751 E.07972
G1 X120.755 Y134.751 E.02433
G1 X119.25 Y133.246 E.07972
G1 X118.6 Y133.246 E.02433
G1 X120.105 Y134.751 E.07972
G1 X119.456 Y134.751 E.02433
G1 X117.95 Y133.246 E.07972
G1 X117.3 Y133.246 E.02433
G1 X118.806 Y134.751 E.07972
G1 X118.156 Y134.751 E.02433
G1 X116.65 Y133.246 E.07972
G1 X116.001 Y133.246 E.02433
G1 X117.506 Y134.751 E.07972
G1 X116.856 Y134.751 E.02433
G1 X115.145 Y133.04 E.09061
; WIPE_START
G1 X116.559 Y134.454 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X118.367 Y127.039 Z.6 F36000
G1 X119.361 Y122.96 Z.6
G1 Z.2
M73 P50 R8
G1 E.8 F1800
G1 F6300
M204 S500
G1 X117.65 Y121.249 E.09061
G1 X117 Y121.249 E.02433
G1 X118.506 Y122.754 E.07972
G1 X117.856 Y122.754 E.02433
G1 X116.35 Y121.249 E.07972
G1 X115.7 Y121.249 E.02433
G1 X117.206 Y122.754 E.07972
G1 X116.556 Y122.754 E.02433
G1 X115.051 Y121.249 E.07972
G1 X114.401 Y121.249 E.02433
G1 X115.906 Y122.754 E.07972
G1 X115.257 Y122.754 E.02433
G1 X113.751 Y121.249 E.07972
G1 X113.101 Y121.249 E.02433
G1 X114.654 Y122.802 E.08225
G1 X114.654 Y123.452 E.02433
G1 X112.451 Y121.249 E.11665
G1 X111.802 Y121.249 E.02433
G1 X114.654 Y124.102 E.15106
G1 X114.654 Y124.752 E.02433
G1 X111.152 Y121.249 E.18547
G1 X110.502 Y121.249 E.02433
G1 X114.654 Y125.401 E.21988
G1 X114.654 Y126.051 E.02433
G1 X109.852 Y121.249 E.25428
G1 X109.202 Y121.249 E.02433
G1 X114.654 Y126.701 E.28869
G1 X114.654 Y127.351 E.02433
G1 X108.553 Y121.249 E.3231
G1 X107.903 Y121.249 E.02433
G1 X114.654 Y128.001 E.35751
G1 X114.654 Y128.65 E.02433
G1 X107.253 Y121.249 E.39191
G1 X106.603 Y121.249 E.02433
G1 X114.654 Y129.3 E.42632
G1 X114.654 Y129.95 E.02433
G1 X105.953 Y121.249 E.46073
G1 X105.304 Y121.249 E.02433
G1 X114.654 Y130.6 E.49514
G1 X114.654 Y131.25 E.02433
G1 X110.656 Y127.251 E.21173
G3 X110.748 Y127.993 I-2.77 J.72 E.02806
G1 X114.654 Y131.899 E.20686
G1 X114.654 Y132.549 E.02433
G1 X110.689 Y128.583 E.20999
G3 X110.551 Y129.096 I-2.016 J-.267 E.01991
G1 X116.207 Y134.751 E.29947
G1 X115.557 Y134.751 E.02433
G1 X110.352 Y129.546 E.27562
G3 X110.1 Y129.944 I-1.641 J-.761 E.01768
G1 X114.907 Y134.751 E.25456
G1 X114.257 Y134.751 E.02433
G1 X109.8 Y130.294 E.23603
G1 X109.451 Y130.595 E.01725
G1 X113.607 Y134.751 E.22009
G1 X112.958 Y134.751 E.02433
G1 X109.054 Y130.848 E.2067
G3 X108.605 Y131.048 I-.986 J-1.609 E.01848
G1 X112.308 Y134.751 E.19609
G1 X111.658 Y134.751 E.02433
G1 X108.094 Y131.187 E.18874
G3 X107.505 Y131.248 I-.527 J-2.204 E.02222
G1 X111.008 Y134.751 E.1855
G1 X110.358 Y134.751 E.02433
G1 X106.46 Y130.852 E.20645
; WIPE_START
G1 X107.874 Y132.267 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X108.558 Y125.154 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X104.654 Y121.249 E.20676
G1 X104.004 Y121.249 E.02433
G1 X107.509 Y124.754 E.18558
G1 X107.49 Y124.752 E.0007
G2 X106.917 Y124.811 I-.064 J2.204 E.02165
G1 X103.354 Y121.249 E.18863
G1 X102.704 Y121.249 E.02433
G1 X106.404 Y124.949 E.19592
G2 X105.954 Y125.148 I.532 J1.81 E.01849
G1 X102.054 Y121.249 E.20648
G1 X101.405 Y121.249 E.02433
G1 X105.556 Y125.4 E.21983
G1 X105.206 Y125.7 E.01725
G1 X100.755 Y121.249 E.23571
G1 X100.105 Y121.249 E.02433
G1 X104.905 Y126.049 E.25417
G2 X104.652 Y126.446 I1.383 J1.16 E.01767
G1 X99.946 Y121.739 E.24923
G1 X99.946 Y122.389 E.02433
G1 X104.452 Y126.896 E.23863
G2 X104.313 Y127.406 I1.927 J.798 E.01988
G1 X99.946 Y123.039 E.23127
G1 X99.946 Y123.249 E.00789
G1 X99.506 Y123.249 E.01644
G1 X104.252 Y128.002 E.25147
G2 X104.341 Y128.734 I2.904 J.016 E.02767
G1 X98.857 Y123.249 E.29041
G1 X98.207 Y123.249 E.02433
G1 X109.709 Y134.751 E.60903
G1 X109.059 Y134.751 E.02433
M73 P51 R8
G1 X97.557 Y123.249 E.60903
G1 X96.907 Y123.249 E.02433
G1 X108.409 Y134.751 E.60903
G1 X107.759 Y134.751 E.02433
G1 X96.257 Y123.249 E.60903
G1 X95.608 Y123.249 E.02433
G1 X107.109 Y134.751 E.60903
G1 X106.46 Y134.751 E.02433
G1 X94.958 Y123.249 E.60903
G1 X94.308 Y123.249 E.02433
G1 X105.81 Y134.751 E.60903
G1 X105.16 Y134.751 E.02433
G1 X93.658 Y123.249 E.60903
G1 X93.008 Y123.249 E.02433
G1 X104.51 Y134.751 E.60903
G1 X103.86 Y134.751 E.02433
G1 X92.359 Y123.249 E.60903
G1 X91.709 Y123.249 E.02433
G1 X103.211 Y134.751 E.60903
G1 X102.561 Y134.751 E.02433
G1 X93.096 Y125.286 E.50119
G1 X93.096 Y124.761 E.01966
G1 X92.571 Y124.761 E.01966
G1 X91.059 Y123.249 E.08004
G1 X90.409 Y123.249 E.02433
G1 X91.921 Y124.761 E.08004
G1 X91.271 Y124.761 E.02433
G1 X89.759 Y123.249 E.08004
G1 X89.11 Y123.249 E.02433
G1 X90.621 Y124.761 E.08004
G1 X89.971 Y124.761 E.02433
G1 X88.46 Y123.249 E.08004
G1 X87.81 Y123.249 E.02433
G1 X89.322 Y124.761 E.08004
G1 X88.672 Y124.761 E.02433
G1 X87.16 Y123.249 E.08004
G1 X86.51 Y123.249 E.02433
G1 X88.022 Y124.761 E.08004
G1 X87.372 Y124.761 E.02433
G1 X86.396 Y123.784 E.05171
G1 X86.396 Y124.434 E.02433
G1 X86.928 Y124.967 E.02819
; WIPE_START
G1 X86.396 Y124.434 E-.28612
G1 X86.396 Y123.784 E-.24692
G1 X86.818 Y124.207 E-.22696
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X92.89 Y125.73 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X101.911 Y134.751 E.47767
G1 X101.261 Y134.751 E.02433
G1 X99.946 Y133.436 E.06966
G1 X99.946 Y134.085 E.02433
G1 X100.611 Y134.751 E.03525
G1 X99.962 Y134.751 E.02433
G1 X99.74 Y134.53 E.01174
; WIPE_START
G1 X99.962 Y134.751 E-.11911
G1 X100.611 Y134.751 E-.24692
G1 X99.946 Y134.085 E-.35779
G1 X99.946 Y133.99 E-.03618
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X99.466 Y132.956 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X93.096 Y126.586 E.33733
G1 X93.096 Y127.235 E.02433
G1 X98.611 Y132.751 E.29204
G1 X97.961 Y132.751 E.02433
G1 X93.096 Y127.885 E.25763
G1 X93.096 Y128.535 E.02433
G1 X97.311 Y132.751 E.22322
G1 X96.661 Y132.751 E.02433
G1 X93.096 Y129.185 E.18881
G1 X93.096 Y129.835 E.02433
G1 X96.012 Y132.751 E.1544
G1 X95.362 Y132.751 E.02433
G1 X93.096 Y130.484 E.12
G1 X93.096 Y131.134 E.02433
G1 X94.712 Y132.751 E.08559
G1 X94.062 Y132.751 E.02433
G1 X92.551 Y131.239 E.08004
G1 X91.901 Y131.239 E.02433
G1 X93.412 Y132.751 E.08004
G1 X92.763 Y132.751 E.02433
G1 X91.251 Y131.239 E.08004
G1 X90.601 Y131.239 E.02433
G1 X92.113 Y132.751 E.08004
G1 X91.463 Y132.751 E.02433
G1 X89.951 Y131.239 E.08004
G1 X89.302 Y131.239 E.02433
G1 X90.813 Y132.751 E.08004
G1 X90.163 Y132.751 E.02433
G1 X88.652 Y131.239 E.08004
G1 X88.002 Y131.239 E.02433
G1 X89.514 Y132.751 E.08004
G1 X88.864 Y132.751 E.02433
G1 X87.352 Y131.239 E.08004
G1 X86.702 Y131.239 E.02433
G1 X88.214 Y132.751 E.08004
G1 X87.564 Y132.751 E.02433
G1 X86.396 Y131.582 E.06188
G1 X86.396 Y132.232 E.02433
G1 X87.12 Y132.956 E.03836
; CHANGE_LAYER
; Z_HEIGHT: 0.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F6300
G1 X86.396 Y132.232 E-.38931
G1 X86.396 Y131.582 E-.24693
M73 P52 R8
G1 X86.626 Y131.812 E-.12376
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
G1 X129.702 Y123.398
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X129.702 Y132.602 E.30532
G1 X125.298 Y132.602 E.14609
G1 X125.298 Y123.398 E.30532
G1 X129.642 Y123.398 E.1441
G1 X129.31 Y123.79 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X129.31 Y132.21 E.25872
G1 X125.69 Y132.21 E.11123
G1 X125.69 Y123.79 E.25872
G1 X129.25 Y123.79 E.10939
; WIPE_START
M204 S10000
G1 X129.264 Y125.79 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.048 Y130.218 Z.8 F36000
G1 X119.702 Y132.602 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X115.298 Y132.602 E.14609
G1 X115.298 Y123.398 E.30532
G1 X119.702 Y123.398 E.14609
G1 X119.702 Y132.542 E.30333
G1 X119.31 Y132.21 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X115.69 Y132.21 E.11123
G1 X115.69 Y123.79 E.25872
G1 X119.31 Y123.79 E.11123
G1 X119.31 Y132.15 E.25688
; WIPE_START
M204 S10000
G1 X117.31 Y132.183 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X110.624 Y128.503 Z.8 F36000
G1 X105.935 Y125.922 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.2 Y125.748 E.01051
G3 X107.438 Y125.401 I1.299 J2.252 E.0431
G3 X107.901 Y130.569 I.062 J2.599 E.25967
G3 X105.888 Y125.959 I-.403 J-2.569 E.22675
G1 X106.158 Y126.252 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.463 Y125.792 I1.349 J1.748 E.04324
G3 X108.072 Y125.865 I-.014 J2.699 E.01888
G3 X106.111 Y126.289 I-.565 J2.135 E.3624
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13248
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10986
G1 X107.211 Y125.808 E-.10986
G1 X107.463 Y125.792 E-.09589
G1 X107.789 Y125.808 E-.12378
G1 X107.99 Y125.849 E-.07825
; WIPE_END
G1 E-.04 F1800
G1 X115.553 Y126.882 Z.8 F36000
G1 X135.45 Y129.602 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.443 Y129.578 E.00083
G3 X137.438 Y125.401 I2.065 J-1.579 E.18941
G3 X138.496 Y125.595 I.08 J2.548 E.03597
G3 X135.666 Y129.834 I-.988 J2.405 E.30524
G1 X135.491 Y129.646 E.00851
G1 X135.754 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.463 Y125.792 I1.754 J-1.341 E.14947
G3 X138.072 Y125.865 I-.014 J2.699 E.01888
G3 X135.791 Y129.387 I-.564 J2.134 E.25604
; WIPE_START
M204 S10000
G1 X135.606 Y129.136 E-.11852
G1 X135.458 Y128.846 E-.12376
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07823
; WIPE_END
G1 E-.04 F1800
G1 X127.736 Y128.054 Z.8 F36000
G1 X92.452 Y130.577 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X92.452 Y125.423 E.17098
G1 X85.752 Y125.423 E.22225
G1 X85.752 Y122.614 E.09319
G1 X99.302 Y122.614 E.44948
G1 X99.302 Y120.612 E.0664
G1 X145.698 Y120.612 E1.53904
G1 X145.698 Y122.614 E.0664
G1 X160.452 Y122.614 E.48942
G1 X160.452 Y118.611 E.13277
G1 X162.248 Y118.611 E.05957
G1 X162.248 Y124.616 E.1992
G1 X170.248 Y124.616 E.26537
G1 X170.248 Y131.384 E.22451
G1 X162.248 Y131.384 E.26537
G1 X162.248 Y137.389 E.1992
G1 X160.452 Y137.389 E.05957
G1 X160.452 Y133.386 E.13277
G1 X145.698 Y133.386 E.48942
G1 X145.698 Y135.388 E.0664
G1 X99.302 Y135.388 E1.53904
G1 X99.302 Y133.386 E.0664
G1 X85.752 Y133.386 E.44948
G1 X85.752 Y130.577 E.09319
G1 X92.392 Y130.577 E.22026
G1 X92.06 Y130.185 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X92.06 Y125.815 E.13429
G1 X85.36 Y125.815 E.20587
G1 X85.36 Y122.222 E.11041
G1 X98.91 Y122.222 E.41635
G1 X98.91 Y120.22 E.06151
G1 X146.09 Y120.22 E1.44971
G1 X146.09 Y122.222 E.06151
G1 X160.06 Y122.222 E.42926
G1 X160.06 Y118.219 E.12299
G1 X162.64 Y118.219 E.07928
G1 X162.64 Y124.224 E.18452
G1 X170.64 Y124.224 E.24582
G1 X170.64 Y131.776 E.23206
G1 X162.64 Y131.776 E.24582
G1 X162.64 Y137.781 E.18452
G1 X160.06 Y137.781 E.07928
G1 X160.06 Y133.779 E.12299
G1 X146.09 Y133.779 E.42926
G1 X146.09 Y135.78 E.06151
G1 X98.91 Y135.78 E1.44971
G1 X98.91 Y133.779 E.06151
G1 X85.36 Y133.779 E.41635
G1 X85.36 Y130.185 E.11041
G1 X92 Y130.185 E.20403
M204 S10000
G1 X92.616 Y130.238 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42176
G1 F15000
G1 X101.908 Y120.945 E.4057
G1 X101.373 Y120.945 E.01654
G1 X92.785 Y129.532 E.3749
G1 X92.785 Y128.997 E.01654
G1 X98.835 Y122.947 E.26412
G1 X98.299 Y122.947 E.01654
G1 X92.785 Y128.461 E.24073
G1 X92.785 Y127.925 E.01654
G1 X97.764 Y122.947 E.21734
G1 X97.228 Y122.947 E.01654
G1 X92.785 Y127.389 E.19395
G1 X92.785 Y126.854 E.01654
G1 X96.692 Y122.947 E.17056
G1 X96.156 Y122.947 E.01654
G1 X92.785 Y126.318 E.14717
G1 X92.785 Y125.782 E.01654
G1 X95.621 Y122.947 E.12378
G1 X95.085 Y122.947 E.01654
G1 X92.785 Y125.246 E.10039
G1 X92.785 Y125.09 E.00484
G1 X92.406 Y125.09 E.0117
G1 X94.549 Y122.947 E.09355
G1 X94.013 Y122.947 E.01654
G1 X91.871 Y125.09 E.09355
G1 X91.335 Y125.09 E.01654
G1 X93.478 Y122.947 E.09355
G1 X92.942 Y122.947 E.01654
G1 X90.799 Y125.09 E.09355
G1 X90.263 Y125.09 E.01654
G1 X92.406 Y122.947 E.09355
G1 X91.87 Y122.947 E.01654
G1 X89.728 Y125.09 E.09355
G1 X89.192 Y125.09 E.01654
G1 X91.335 Y122.947 E.09355
G1 X90.799 Y122.947 E.01654
G1 X88.656 Y125.09 E.09355
G1 X88.12 Y125.09 E.01654
G1 X90.263 Y122.947 E.09355
G1 X89.727 Y122.947 E.01654
G1 X87.585 Y125.09 E.09355
G1 X87.049 Y125.09 E.01654
G1 X89.192 Y122.947 E.09355
G1 X88.656 Y122.947 E.01654
G1 X86.513 Y125.09 E.09355
G1 X86.085 Y125.09 E.0132
G1 X86.085 Y124.981 E.00334
G1 X88.12 Y122.947 E.08883
G1 X87.584 Y122.947 E.01654
G1 X86.085 Y124.446 E.06544
G1 X86.085 Y123.91 E.01654
G1 X87.048 Y122.947 E.04205
G1 X86.513 Y122.947 E.01654
G1 X85.916 Y123.544 E.02607
; WIPE_START
G1 X86.513 Y122.947 E-.32086
G1 X87.048 Y122.947 E-.20359
G1 X86.61 Y123.385 E-.23555
; WIPE_END
G1 E-.04 F1800
G1 X86.755 Y130.741 Z.8 F36000
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X86.085 Y131.411 E.02924
G1 X86.085 Y131.946 E.01654
G1 X87.121 Y130.91 E.04522
G1 X87.657 Y130.91 E.01654
G1 X86.085 Y132.482 E.06861
G1 X86.085 Y133.018 E.01654
G1 X88.193 Y130.91 E.092
G1 X88.729 Y130.91 E.01654
G1 X86.586 Y133.053 E.09355
G1 X87.122 Y133.053 E.01654
G1 X89.264 Y130.91 E.09355
G1 X89.8 Y130.91 E.01654
G1 X87.657 Y133.053 E.09355
G1 X88.193 Y133.053 E.01654
G1 X90.336 Y130.91 E.09355
G1 X90.872 Y130.91 E.01654
G1 X88.729 Y133.053 E.09355
G1 X89.265 Y133.053 E.01654
G1 X91.407 Y130.91 E.09355
G1 X91.943 Y130.91 E.01654
G1 X89.8 Y133.053 E.09355
G1 X90.336 Y133.053 E.01654
G1 X102.444 Y120.945 E.52861
G1 X102.98 Y120.945 E.01654
G1 X90.872 Y133.053 E.52861
G1 X91.408 Y133.053 E.01654
G1 X103.516 Y120.945 E.52861
G1 X104.051 Y120.945 E.01654
G1 X91.943 Y133.053 E.52861
G1 X92.479 Y133.053 E.01654
G1 X104.587 Y120.945 E.52861
G1 X105.123 Y120.945 E.01654
G1 X93.015 Y133.053 E.52861
G1 X93.551 Y133.053 E.01654
G1 X105.659 Y120.945 E.52861
G1 X106.194 Y120.945 E.01654
G1 X94.086 Y133.053 E.52861
G1 X94.622 Y133.053 E.01654
G1 X106.73 Y120.945 E.52861
G1 X107.266 Y120.945 E.01654
G1 X95.158 Y133.053 E.52861
G1 X95.694 Y133.053 E.01654
G1 X107.802 Y120.945 E.52861
G1 X108.338 Y120.945 E.01654
G1 X96.229 Y133.053 E.52861
G1 X96.765 Y133.053 E.01654
G1 X108.873 Y120.945 E.52861
G1 X109.409 Y120.945 E.01654
G1 X97.301 Y133.053 E.52861
G1 X97.837 Y133.053 E.01654
G1 X109.945 Y120.945 E.52861
G1 X110.481 Y120.945 E.01654
G1 X98.373 Y133.053 E.52861
G1 X98.908 Y133.053 E.01654
G1 X104.648 Y127.313 E.25059
G2 X104.567 Y127.93 I2.3 J.615 E.01925
G1 X99.444 Y133.053 E.22367
G1 X99.635 Y133.053 E.0059
G1 X99.635 Y133.398 E.01063
G1 X104.598 Y128.435 E.21666
G2 X104.7 Y128.869 I1.701 J-.169 E.0138
G1 X99.635 Y133.933 E.2211
G1 X99.635 Y134.469 E.01654
G1 X104.85 Y129.254 E.22768
G2 X105.042 Y129.598 I1.402 J-.558 E.01219
G1 X99.635 Y135.005 E.23606
G1 X99.635 Y135.055 E.00154
G1 X100.121 Y135.055 E.015
G1 X105.272 Y129.904 E.22486
G2 X105.536 Y130.176 I1.164 J-.869 E.01173
G1 X100.657 Y135.055 E.213
G1 X101.193 Y135.055 E.01654
G1 X105.835 Y130.413 E.20267
G2 X106.171 Y130.613 I.927 J-1.175 E.0121
G1 X101.728 Y135.055 E.19394
G1 X102.264 Y135.055 E.01654
G1 X106.55 Y130.769 E.18709
G2 X106.972 Y130.883 I.723 J-1.838 E.01352
G1 X102.8 Y135.055 E.18212
G1 X103.336 Y135.055 E.01654
G1 X107.456 Y130.934 E.17989
G2 X108.047 Y130.88 I-.026 J-3.489 E.01833
G1 X103.702 Y135.225 E.18969
G1 X117.096 Y135.225 F36000
G1 F15000
G1 X119.385 Y132.935 E.09994
M73 P53 R8
G1 X118.849 Y132.935 E.01654
G1 X116.73 Y135.055 E.09253
G1 X116.194 Y135.055 E.01654
G1 X118.314 Y132.935 E.09253
G1 X117.778 Y132.935 E.01654
G1 X115.658 Y135.055 E.09253
G1 X115.122 Y135.055 E.01654
G1 X117.242 Y132.935 E.09253
G1 X116.706 Y132.935 E.01654
G1 X114.587 Y135.055 E.09253
G1 X114.051 Y135.055 E.01654
G1 X116.17 Y132.935 E.09253
G1 X115.635 Y132.935 E.01654
G1 X113.515 Y135.055 E.09253
G1 X112.979 Y135.055 E.01654
G1 X115.099 Y132.935 E.09253
G1 X114.965 Y132.935 E.00415
G1 X114.965 Y132.534 E.01239
G1 X112.444 Y135.055 E.11006
G1 X111.908 Y135.055 E.01654
G1 X114.965 Y131.998 E.13345
G1 X114.965 Y131.462 E.01654
G1 X111.372 Y135.055 E.15684
G1 X110.836 Y135.055 E.01654
G1 X114.965 Y130.927 E.18023
G1 X114.965 Y130.391 E.01654
G1 X110.301 Y135.055 E.20362
G1 X109.765 Y135.055 E.01654
G1 X114.965 Y129.855 E.22701
G1 X114.965 Y129.319 E.01654
G1 X109.229 Y135.055 E.2504
G1 X108.693 Y135.055 E.01654
G1 X114.965 Y128.784 E.27379
G1 X114.965 Y128.248 E.01654
G1 X108.158 Y135.055 E.29718
G1 X107.622 Y135.055 E.01654
G1 X114.965 Y127.712 E.32057
G1 X114.965 Y127.176 E.01654
G1 X107.086 Y135.055 E.34396
G1 X106.55 Y135.055 E.01654
G1 X114.965 Y126.64 E.36735
G1 X114.965 Y126.105 E.01654
G1 X106.015 Y135.055 E.39074
G1 X105.479 Y135.055 E.01654
G1 X114.965 Y125.569 E.41413
G1 X114.965 Y125.033 E.01654
G1 X104.943 Y135.055 E.43752
G1 X104.407 Y135.055 E.01654
G1 X114.965 Y124.497 E.46091
G1 X114.965 Y123.962 E.01654
G1 X110.154 Y128.772 E.21003
; WIPE_START
G1 X111.568 Y127.358 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X106.558 Y125.404 Z.8 F36000
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X111.016 Y120.945 E.19465
G1 X111.552 Y120.945 E.01654
G1 X107.43 Y125.067 E.17996
G1 X107.935 Y125.098 E.01562
G1 X112.088 Y120.945 E.18131
G1 X112.624 Y120.945 E.01654
G1 X108.369 Y125.2 E.18574
G3 X108.754 Y125.35 I-.38 J1.537 E.0128
G1 X113.159 Y120.945 E.19232
G1 X113.695 Y120.945 E.01654
G1 X109.098 Y125.542 E.20071
G3 X109.404 Y125.772 I-.717 J1.279 E.01185
G1 X114.231 Y120.945 E.21071
G1 X114.767 Y120.945 E.01654
G1 X109.676 Y126.036 E.22225
G3 X109.913 Y126.335 I-1.017 J1.048 E.01181
G1 X115.302 Y120.945 E.23531
G1 X115.838 Y120.945 E.01654
G1 X110.113 Y126.671 E.24997
G3 X110.272 Y127.047 I-1.35 J.793 E.01266
G1 X116.374 Y120.945 E.2664
G1 X116.91 Y120.945 E.01654
G1 X110.383 Y127.472 E.28493
G3 X110.434 Y127.956 I-1.815 J.436 E.01509
G1 X114.965 Y123.426 E.19778
G1 X114.965 Y123.065 E.01115
G1 X115.326 Y123.065 E.01115
G1 X117.445 Y120.945 E.09253
G1 X117.981 Y120.945 E.01654
G1 X115.862 Y123.065 E.09253
G1 X116.397 Y123.065 E.01654
G1 X118.517 Y120.945 E.09253
G1 X119.053 Y120.945 E.01654
G1 X116.933 Y123.065 E.09253
G1 X117.469 Y123.065 E.01654
G1 X119.589 Y120.945 E.09253
G1 X120.124 Y120.945 E.01654
G1 X118.005 Y123.065 E.09253
G1 X118.54 Y123.065 E.01654
G1 X120.66 Y120.945 E.09253
G1 X121.196 Y120.945 E.01654
G1 X119.076 Y123.065 E.09253
G1 X119.612 Y123.065 E.01654
G1 X121.732 Y120.945 E.09253
G1 X122.267 Y120.945 E.01654
G1 X120.035 Y123.177 E.09744
G1 X120.035 Y123.713 E.01654
G1 X122.803 Y120.945 E.12083
G1 X123.339 Y120.945 E.01654
G1 X120.035 Y124.249 E.14422
G1 X120.035 Y124.784 E.01654
G1 X123.875 Y120.945 E.16761
G1 X124.41 Y120.945 E.01654
G1 X120.035 Y125.32 E.191
G1 X120.035 Y125.856 E.01654
G1 X124.946 Y120.945 E.21439
G1 X125.482 Y120.945 E.01654
G1 X120.035 Y126.392 E.23778
G1 X120.035 Y126.927 E.01654
G1 X126.018 Y120.945 E.26117
G1 X126.553 Y120.945 E.01654
G1 X120.035 Y127.463 E.28456
G1 X120.035 Y127.999 E.01654
G1 X127.089 Y120.945 E.30795
G1 X127.625 Y120.945 E.01654
G1 X125.505 Y123.065 E.09253
G1 X126.041 Y123.065 E.01654
G1 X128.161 Y120.945 E.09253
G1 X128.696 Y120.945 E.01654
G1 X126.577 Y123.065 E.09253
G1 X127.113 Y123.065 E.01654
G1 X129.232 Y120.945 E.09253
G1 X129.768 Y120.945 E.01654
G1 X127.648 Y123.065 E.09253
G1 X128.184 Y123.065 E.01654
G1 X130.304 Y120.945 E.09253
G1 X130.839 Y120.945 E.01654
G1 X128.72 Y123.065 E.09253
G1 X129.256 Y123.065 E.01654
G1 X131.375 Y120.945 E.09253
G1 X131.911 Y120.945 E.01654
G1 X129.791 Y123.065 E.09253
G1 X130.035 Y123.065 E.00753
G1 X130.035 Y123.357 E.00901
G1 X132.447 Y120.945 E.10528
G1 X132.983 Y120.945 E.01654
G1 X130.035 Y123.892 E.12867
G1 X130.035 Y124.428 E.01654
G1 X133.518 Y120.945 E.15206
G1 X134.054 Y120.945 E.01654
G1 X130.035 Y124.964 E.17545
G1 X130.035 Y125.5 E.01654
G1 X134.59 Y120.945 E.19884
G1 X135.126 Y120.945 E.01654
G1 X130.035 Y126.035 E.22223
G1 X130.035 Y126.571 E.01654
G1 X135.661 Y120.945 E.24562
G1 X136.197 Y120.945 E.01654
G1 X130.035 Y127.107 E.26901
G1 X130.035 Y127.643 E.01654
G1 X136.733 Y120.945 E.2924
G1 X137.269 Y120.945 E.01654
G1 X130.035 Y128.178 E.31579
G1 X130.035 Y128.714 E.01654
G1 X137.804 Y120.945 E.33918
G1 X138.34 Y120.945 E.01654
G1 X130.035 Y129.25 E.36257
G1 X130.035 Y129.786 E.01654
G1 X138.876 Y120.945 E.38596
G1 X139.412 Y120.945 E.01654
G1 X130.035 Y130.321 E.40935
G1 X130.035 Y130.857 E.01654
G1 X139.947 Y120.945 E.43274
G1 X140.483 Y120.945 E.01654
G1 X130.035 Y131.393 E.45613
G1 X130.035 Y131.929 E.01654
G1 X134.647 Y127.317 E.20136
G2 X134.567 Y127.933 I2.299 J.613 E.01924
G1 X129.866 Y132.634 E.20525
; WIPE_START
G1 X131.28 Y131.22 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X136.41 Y125.569 Z.8 F36000
G1 X136.562 Y125.402 Z.8
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X141.019 Y120.945 E.19459
G1 X141.555 Y120.945 E.01654
G1 X137.433 Y125.067 E.17995
G1 X137.937 Y125.098 E.0156
G1 X142.09 Y120.945 E.18133
G1 X142.626 Y120.945 E.01654
G1 X138.371 Y125.2 E.18577
G3 X138.756 Y125.351 I-.38 J1.536 E.0128
G1 X143.162 Y120.945 E.19236
G1 X143.698 Y120.945 E.01654
G1 X139.099 Y125.544 E.20075
G3 X139.406 Y125.773 I-.717 J1.278 E.01185
G1 X144.233 Y120.945 E.21077
G1 X144.769 Y120.945 E.01654
G1 X139.677 Y126.037 E.22231
G3 X139.914 Y126.337 I-1.02 J1.049 E.01181
G1 X145.305 Y120.945 E.23538
G1 X145.365 Y120.945 E.00184
G1 X145.365 Y121.421 E.0147
G1 X140.113 Y126.673 E.22926
G3 X140.273 Y127.049 I-1.349 J.792 E.01266
G1 X145.365 Y121.957 E.22231
G1 X145.365 Y122.493 E.01654
G1 X140.384 Y127.474 E.21745
G3 X140.435 Y127.959 I-1.815 J.435 E.0151
G1 X145.446 Y122.947 E.2188
G1 X145.982 Y122.947 E.01654
G1 X140.153 Y128.776 E.2545
G1 X149.636 Y133.223 F36000
G1 F15000
G1 X159.912 Y122.947 E.44863
G1 X159.376 Y122.947 E.01654
G1 X149.27 Y133.053 E.44122
G1 X148.734 Y133.053 E.01654
G1 X158.84 Y122.947 E.44122
G1 X158.305 Y122.947 E.01654
G1 X148.198 Y133.053 E.44122
G1 X147.663 Y133.053 E.01654
G1 X157.769 Y122.947 E.44122
G1 X157.233 Y122.947 E.01654
G1 X147.127 Y133.053 E.44122
G1 X146.591 Y133.053 E.01654
G1 X156.697 Y122.947 E.44122
G1 X156.162 Y122.947 E.01654
G1 X145.886 Y133.223 E.44863
G1 X145.534 Y133.574 F36000
G1 F15000
G1 X144.054 Y135.055 E.06465
G1 X144.589 Y135.055 E.01654
G1 X145.365 Y134.279 E.03385
G1 X145.365 Y134.815 E.01654
G1 X144.955 Y135.225 E.01787
G1 X143.348 Y135.225 F36000
G1 F15000
G1 X155.626 Y122.947 E.53602
G1 X155.09 Y122.947 E.01654
G1 X142.982 Y135.055 E.52861
G1 X142.446 Y135.055 E.01654
G1 X154.554 Y122.947 E.52861
G1 X154.019 Y122.947 E.01654
G1 X141.911 Y135.055 E.52861
G1 X141.375 Y135.055 E.01654
G1 X153.483 Y122.947 E.52861
G1 X152.947 Y122.947 E.01654
G1 X140.839 Y135.055 E.52861
G1 X140.303 Y135.055 E.01654
G1 X152.411 Y122.947 E.52861
G1 X151.875 Y122.947 E.01654
G1 X139.767 Y135.055 E.52861
G1 X139.232 Y135.055 E.01654
G1 X151.34 Y122.947 E.52861
G1 X150.804 Y122.947 E.01654
G1 X138.696 Y135.055 E.52861
G1 X138.16 Y135.055 E.01654
G1 X150.268 Y122.947 E.52861
G1 X149.732 Y122.947 E.01654
G1 X137.624 Y135.055 E.52861
G1 X137.089 Y135.055 E.01654
G1 X149.197 Y122.947 E.52861
G1 X148.661 Y122.947 E.01654
G1 X136.553 Y135.055 E.52861
G1 X136.017 Y135.055 E.01654
G1 X148.125 Y122.947 E.52861
G1 X147.589 Y122.947 E.01654
G1 X135.481 Y135.055 E.52861
G1 X134.946 Y135.055 E.01654
G1 X147.054 Y122.947 E.52861
G1 X146.518 Y122.947 E.01654
G1 X134.41 Y135.055 E.52861
G1 X133.874 Y135.055 E.01654
G1 X138.05 Y130.879 E.1823
G3 X137.459 Y130.935 I-.623 J-3.461 E.01836
G1 X133.338 Y135.055 E.17988
G1 X132.803 Y135.055 E.01654
G1 X136.974 Y130.884 E.1821
G3 X136.552 Y130.77 I.3 J-1.954 E.01352
G1 X132.267 Y135.055 E.18707
G1 X131.731 Y135.055 E.01654
G1 X136.173 Y130.613 E.1939
G3 X135.837 Y130.414 I.59 J-1.374 E.0121
G1 X131.195 Y135.055 E.20263
G1 X130.66 Y135.055 E.01654
G1 X135.537 Y130.177 E.21295
G3 X135.273 Y129.906 I.899 J-1.14 E.01173
G1 X130.124 Y135.055 E.2248
G1 X129.588 Y135.055 E.01654
G1 X135.044 Y129.599 E.23817
G3 X134.853 Y129.254 I1.457 J-1.028 E.0122
G1 X129.052 Y135.055 E.25325
G1 X128.516 Y135.055 E.01654
G1 X134.7 Y128.871 E.26997
G3 X134.598 Y128.437 I1.598 J-.604 E.0138
G1 X127.981 Y135.055 E.28892
G1 X127.445 Y135.055 E.01654
G1 X129.564 Y132.935 E.09253
G1 X129.029 Y132.935 E.01654
G1 X126.909 Y135.055 E.09253
G1 X126.373 Y135.055 E.01654
G1 X128.493 Y132.935 E.09253
G1 X127.957 Y132.935 E.01654
G1 X125.838 Y135.055 E.09253
G1 X125.302 Y135.055 E.01654
G1 X127.421 Y132.935 E.09253
G1 X126.886 Y132.935 E.01654
G1 X124.766 Y135.055 E.09253
G1 X124.23 Y135.055 E.01654
G1 X126.35 Y132.935 E.09253
G1 X125.814 Y132.935 E.01654
G1 X123.695 Y135.055 E.09253
G1 X123.159 Y135.055 E.01654
G1 X125.278 Y132.935 E.09253
G1 X124.965 Y132.935 E.00969
G1 X124.965 Y132.713 E.00685
G1 X122.623 Y135.055 E.10223
G1 X122.087 Y135.055 E.01654
G1 X124.965 Y132.178 E.12562
G1 X124.965 Y131.642 E.01654
G1 X121.552 Y135.055 E.14901
G1 X121.016 Y135.055 E.01654
G1 X124.965 Y131.106 E.1724
G1 X124.965 Y130.57 E.01654
G1 X120.48 Y135.055 E.19579
M73 P54 R8
G1 X119.944 Y135.055 E.01654
G1 X124.965 Y130.035 E.21918
G1 X124.965 Y129.499 E.01654
G1 X119.409 Y135.055 E.24257
G1 X118.873 Y135.055 E.01654
G1 X124.965 Y128.963 E.26596
G1 X124.965 Y128.427 E.01654
G1 X118.337 Y135.055 E.28935
G1 X117.801 Y135.055 E.01654
G1 X124.965 Y127.891 E.31274
G1 X124.965 Y127.356 E.01654
G1 X120.035 Y132.285 E.2152
G1 X120.035 Y131.749 E.01654
G1 X124.965 Y126.82 E.2152
G1 X124.965 Y126.284 E.01654
G1 X120.035 Y131.214 E.2152
G1 X120.035 Y130.678 E.01654
G1 X124.965 Y125.748 E.2152
G1 X124.965 Y125.213 E.01654
G1 X120.035 Y130.142 E.2152
G1 X120.035 Y129.606 E.01654
G1 X124.965 Y124.677 E.2152
G1 X124.965 Y124.141 E.01654
G1 X120.035 Y129.071 E.2152
G1 X120.035 Y128.535 E.01654
G1 X125.134 Y123.436 E.22261
G1 X99.935 Y120.775 F36000
G1 F15000
G1 X99.635 Y121.075 E.01308
G1 X99.635 Y121.611 E.01654
G1 X100.301 Y120.945 E.02907
G1 X100.837 Y120.945 E.01654
G1 X99.466 Y122.316 E.05986
; WIPE_START
G1 X100.837 Y120.945 E-.7369
G1 X100.776 Y120.945 E-.0231
; WIPE_END
G1 E-.04 F1800
G1 X108.404 Y120.672 Z.8 F36000
G1 X161.405 Y118.775 Z.8
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X160.785 Y119.395 E.02707
G1 X160.785 Y119.93 E.01654
G1 X161.771 Y118.944 E.04305
G1 X161.915 Y118.944 E.00442
G1 X161.915 Y119.337 E.01212
G1 X160.785 Y120.466 E.04931
G1 X160.785 Y121.002 E.01654
G1 X161.915 Y119.873 E.04931
G1 X161.915 Y120.408 E.01654
G1 X160.785 Y121.538 E.04931
G1 X160.785 Y122.073 E.01654
G1 X161.915 Y120.944 E.04931
G1 X161.915 Y121.48 E.01654
G1 X150.341 Y133.053 E.50527
G1 X150.877 Y133.053 E.01654
G1 X161.915 Y122.016 E.48188
G1 X161.915 Y122.551 E.01654
G1 X151.413 Y133.053 E.45849
G1 X151.949 Y133.053 E.01654
G1 X161.915 Y123.087 E.4351
G1 X161.915 Y123.623 E.01654
G1 X152.484 Y133.053 E.41171
G1 X153.02 Y133.053 E.01654
G1 X161.915 Y124.159 E.38832
G1 X161.915 Y124.694 E.01654
G1 X153.556 Y133.053 E.36493
G1 X154.092 Y133.053 E.01654
G1 X162.196 Y124.949 E.3538
G1 X162.731 Y124.949 E.01654
G1 X154.627 Y133.053 E.3538
G1 X155.163 Y133.053 E.01654
G1 X163.267 Y124.949 E.3538
G1 X163.803 Y124.949 E.01654
G1 X155.699 Y133.053 E.3538
G1 X156.235 Y133.053 E.01654
G1 X164.339 Y124.949 E.3538
G1 X164.874 Y124.949 E.01654
G1 X156.77 Y133.053 E.3538
G1 X157.306 Y133.053 E.01654
G1 X165.41 Y124.949 E.3538
G1 X165.946 Y124.949 E.01654
G1 X157.842 Y133.053 E.3538
G1 X158.378 Y133.053 E.01654
G1 X166.482 Y124.949 E.3538
G1 X167.017 Y124.949 E.01654
G1 X158.913 Y133.053 E.3538
G1 X159.449 Y133.053 E.01654
G1 X167.553 Y124.949 E.3538
G1 X168.089 Y124.949 E.01654
G1 X159.815 Y133.223 E.36121
; WIPE_START
G1 X161.23 Y131.809 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.706 Y137.225 Z.8 F36000
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X161.915 Y137.017 E.00911
G1 X161.915 Y136.481 E.01654
G1 X161.34 Y137.056 E.02509
G1 X160.804 Y137.056 E.01654
G1 X161.915 Y135.945 E.04848
G1 X161.915 Y135.41 E.01654
G1 X160.785 Y136.539 E.0493
G1 X160.785 Y136.003 E.01654
G1 X161.915 Y134.874 E.0493
G1 X161.915 Y134.338 E.01654
G1 X160.785 Y135.467 E.0493
G1 X160.785 Y134.932 E.01654
G1 X161.915 Y133.802 E.04931
G1 X161.915 Y133.267 E.01654
G1 X160.785 Y134.396 E.04931
G1 X160.785 Y133.86 E.01654
G1 X161.915 Y132.731 E.04931
G1 X161.915 Y132.195 E.01654
G1 X160.785 Y133.324 E.04931
G1 X160.785 Y133.053 E.00837
G1 X160.521 Y133.053 E.00817
G1 X162.084 Y131.49 E.06826
G1 X162.353 Y131.221 F36000
G1 F15000
G1 X168.625 Y124.949 E.27379
G1 X169.161 Y124.949 E.01654
G1 X163.059 Y131.051 E.26638
G1 X163.595 Y131.051 E.01654
G1 X169.696 Y124.949 E.26638
G1 X169.915 Y124.949 E.00674
G1 X169.915 Y125.267 E.0098
G1 X164.13 Y131.051 E.25253
G1 X164.666 Y131.051 E.01654
G1 X169.915 Y125.802 E.22914
G1 X169.915 Y126.338 E.01654
G1 X165.202 Y131.051 E.20575
G1 X165.738 Y131.051 E.01654
G1 X169.915 Y126.874 E.18236
G1 X169.915 Y127.41 E.01654
G1 X166.273 Y131.051 E.15897
G1 X166.809 Y131.051 E.01654
G1 X169.915 Y127.945 E.13558
G1 X169.915 Y128.481 E.01654
G1 X167.345 Y131.051 E.11219
G1 X167.881 Y131.051 E.01654
G1 X169.915 Y129.017 E.0888
G1 X169.915 Y129.553 E.01654
G1 X168.417 Y131.051 E.06541
G1 X168.952 Y131.051 E.01654
G1 X169.915 Y130.088 E.04202
G1 X169.915 Y130.624 E.01654
G1 X169.318 Y131.221 E.02603
; CHANGE_LAYER
; Z_HEIGHT: 0.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X169.915 Y130.624 E-.32047
G1 X169.915 Y130.088 E-.20359
G1 X169.476 Y130.527 E-.23594
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
G1 X129.702 Y123.398
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X129.702 Y132.602 E.30532
G1 X125.298 Y132.602 E.14609
G1 X125.298 Y123.398 E.30532
G1 X129.642 Y123.398 E.1441
G1 X129.31 Y123.79 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X129.31 Y132.21 E.25872
G1 X125.69 Y132.21 E.11123
G1 X125.69 Y123.79 E.25872
G1 X129.25 Y123.79 E.10939
; WIPE_START
M204 S10000
G1 X129.264 Y125.79 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.048 Y130.218 Z1 F36000
G1 X119.702 Y132.602 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X115.298 Y132.602 E.14609
G1 X115.298 Y123.398 E.30532
G1 X119.702 Y123.398 E.14609
G1 X119.702 Y132.542 E.30333
G1 X119.31 Y132.21 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X115.69 Y132.21 E.11123
G1 X115.69 Y123.79 E.25872
G1 X119.31 Y123.79 E.11123
G1 X119.31 Y132.15 E.25688
; WIPE_START
M204 S10000
G1 X117.31 Y132.183 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X110.624 Y128.503 Z1 F36000
G1 X105.935 Y125.922 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.201 Y125.75 E.01051
G3 X107.422 Y125.402 I1.301 J2.251 E.04257
G3 X106.903 Y130.53 I.078 J2.598 E.29347
G3 X105.89 Y125.961 I.599 J-2.53 E.19317
G1 X106.159 Y126.252 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.448 Y125.793 I1.348 J1.748 E.04275
G3 X108.346 Y125.958 I.067 J2.163 E.02827
G3 X106.112 Y126.289 I-.839 J2.042 E.35333
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13247
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10985
G1 X107.211 Y125.808 E-.10988
G1 X107.448 Y125.793 E-.09004
G1 X107.789 Y125.808 E-.12958
G1 X107.991 Y125.849 E-.07829
; WIPE_END
G1 E-.04 F1800
G1 X115.554 Y126.873 Z1 F36000
G1 X135.422 Y129.565 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.25 Y129.299 E.01051
G3 X137.422 Y125.402 I2.252 J-1.299 E.17794
G3 X136.903 Y130.53 I.076 J2.598 E.29335
G3 X135.461 Y129.61 I.599 J-2.53 E.0578
G1 X135.753 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.448 Y125.793 I1.754 J-1.341 E.149
G3 X138.346 Y125.958 I.067 J2.163 E.02827
G3 X135.79 Y129.387 I-.839 J2.042 E.24708
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13246
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07814
; WIPE_END
G1 E-.04 F1800
G1 X127.735 Y128.047 Z1 F36000
G1 X92.452 Y130.537 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X92.452 Y125.463 E.16834
G1 X85.752 Y125.463 E.22225
G1 X85.752 Y122.624 E.09415
G1 X99.302 Y122.624 E.44948
G1 X99.302 Y120.618 E.06654
G1 X145.698 Y120.618 E1.53904
G1 X145.698 Y122.624 E.06654
G1 X160.452 Y122.624 E.48942
G1 X160.452 Y118.617 E.13294
G1 X162.248 Y118.617 E.05957
G1 X162.248 Y124.637 E.19971
G1 X170.248 Y124.637 E.26537
G1 X170.248 Y131.363 E.22309
G1 X162.248 Y131.363 E.26537
G1 X162.248 Y137.383 E.19971
G1 X160.452 Y137.383 E.05957
G1 X160.452 Y133.376 E.13294
G1 X145.698 Y133.376 E.48942
G1 X145.698 Y135.382 E.06654
G1 X99.302 Y135.382 E1.53904
G1 X99.302 Y133.376 E.06654
G1 X85.752 Y133.376 E.44948
G1 X85.752 Y130.537 E.09415
G1 X92.392 Y130.537 E.22026
G1 X92.06 Y130.145 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X92.06 Y125.855 E.13184
G1 X85.36 Y125.855 E.20587
G1 X85.36 Y122.232 E.1113
G1 X98.91 Y122.232 E.41635
G1 X98.91 Y120.226 E.06164
G1 X146.09 Y120.226 E1.44971
G1 X146.09 Y122.232 E.06164
M73 P54 R7
G1 X160.06 Y122.232 E.42926
G1 X160.06 Y118.225 E.12314
G1 X162.64 Y118.225 E.07928
G1 X162.64 Y124.245 E.18499
G1 X170.64 Y124.245 E.24582
G1 X170.64 Y131.755 E.23074
G1 X162.64 Y131.755 E.24582
G1 X162.64 Y137.775 E.18499
G1 X160.06 Y137.775 E.07928
G1 X160.06 Y133.768 E.12314
G1 X146.09 Y133.768 E.42926
G1 X146.09 Y135.774 E.06164
G1 X98.91 Y135.774 E1.44971
G1 X98.91 Y133.768 E.06164
G1 X85.36 Y133.768 E.41635
G1 X85.36 Y130.145 E.1113
G1 X92 Y130.145 E.20403
; WIPE_START
M204 S10000
G1 X92.028 Y128.146 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X86.682 Y133.212 Z1 F36000
G1 Z.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42163
G1 F15000
G1 X86.085 Y132.616 E.02603
G1 X86.085 Y132.08 E.01653
M73 P55 R7
G1 X87.048 Y133.042 E.04199
G1 X87.583 Y133.042 E.01653
G1 X86.085 Y131.545 E.06537
G1 X86.085 Y131.009 E.01653
G1 X88.119 Y133.042 E.08874
G1 X88.654 Y133.042 E.01653
G1 X86.483 Y130.871 E.09478
G1 X87.018 Y130.871 E.01653
G1 X89.19 Y133.042 E.09478
G1 X89.725 Y133.042 E.01653
G1 X87.554 Y130.871 E.09478
G1 X88.089 Y130.871 E.01653
G1 X90.261 Y133.042 E.09478
G1 X90.797 Y133.042 E.01653
G1 X88.625 Y130.871 E.09478
G1 X89.161 Y130.871 E.01653
G1 X91.332 Y133.042 E.09478
G1 X91.868 Y133.042 E.01653
G1 X89.696 Y130.871 E.09478
G1 X90.232 Y130.871 E.01653
G1 X92.403 Y133.042 E.09478
G1 X92.939 Y133.042 E.01653
G1 X90.767 Y130.871 E.09478
G1 X91.303 Y130.871 E.01653
G1 X93.474 Y133.042 E.09478
G1 X94.01 Y133.042 E.01653
G1 X91.838 Y130.871 E.09478
G1 X92.374 Y130.871 E.01653
G1 X94.546 Y133.042 E.09478
G1 X95.081 Y133.042 E.01653
G1 X92.785 Y130.746 E.1002
G1 X92.785 Y130.211 E.01653
G1 X95.617 Y133.042 E.12357
G1 X96.152 Y133.042 E.01653
G1 X92.785 Y129.675 E.14695
G1 X92.785 Y129.14 E.01653
G1 X96.688 Y133.042 E.17032
G1 X97.224 Y133.042 E.01653
G1 X92.785 Y128.604 E.1937
G1 X92.785 Y128.069 E.01653
G1 X97.759 Y133.042 E.21707
G1 X98.295 Y133.042 E.01653
G1 X92.785 Y127.533 E.24044
G1 X92.785 Y126.997 E.01653
G1 X99 Y133.212 E.27122
; WIPE_START
G1 X97.586 Y131.798 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X99.466 Y134.749 Z1 F36000
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X99.765 Y135.048 E.01307
G1 X100.301 Y135.048 E.01653
G1 X99.635 Y134.383 E.02904
G1 X99.635 Y133.847 E.01653
G1 X100.836 Y135.048 E.05241
G1 X101.372 Y135.048 E.01653
G1 X92.785 Y126.462 E.37474
G1 X92.785 Y125.926 E.01653
G1 X102.077 Y135.218 E.40552
; WIPE_START
G1 X100.663 Y133.804 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X94.12 Y129.874 Z1 F36000
G1 X85.916 Y124.948 Z1
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X86.097 Y125.129 E.00791
G1 X86.633 Y125.129 E.01653
G1 X86.085 Y124.582 E.02388
G1 X86.085 Y124.046 E.01653
G1 X87.168 Y125.129 E.04726
G1 X87.704 Y125.129 E.01653
G1 X86.085 Y123.511 E.07063
G1 X86.085 Y122.975 E.01653
G1 X88.239 Y125.129 E.09401
G1 X88.775 Y125.129 E.01653
G1 X86.603 Y122.958 E.09478
G1 X87.139 Y122.958 E.01653
G1 X89.31 Y125.129 E.09478
G1 X89.846 Y125.129 E.01653
G1 X87.674 Y122.958 E.09478
G1 X88.21 Y122.958 E.01653
G1 X90.382 Y125.129 E.09478
G1 X90.917 Y125.129 E.01653
G1 X88.746 Y122.958 E.09478
G1 X89.281 Y122.958 E.01653
G1 X91.453 Y125.129 E.09478
G1 X91.988 Y125.129 E.01653
G1 X89.817 Y122.958 E.09478
G1 X90.352 Y122.958 E.01653
G1 X102.443 Y135.048 E.52767
G1 X102.979 Y135.048 E.01653
G1 X90.888 Y122.958 E.52767
G1 X91.423 Y122.958 E.01653
G1 X103.514 Y135.048 E.52767
G1 X104.05 Y135.048 E.01653
G1 X91.959 Y122.958 E.52767
G1 X92.495 Y122.958 E.01653
G1 X104.585 Y135.048 E.52767
G1 X105.121 Y135.048 E.01653
G1 X93.03 Y122.958 E.52767
G1 X93.566 Y122.958 E.01653
G1 X105.656 Y135.048 E.52767
G1 X106.192 Y135.048 E.01653
G1 X94.101 Y122.958 E.52767
G1 X94.637 Y122.958 E.01653
G1 X106.728 Y135.048 E.52767
G1 X107.263 Y135.048 E.01653
G1 X95.172 Y122.958 E.52767
G1 X95.708 Y122.958 E.01653
G1 X107.799 Y135.048 E.52767
G1 X108.334 Y135.048 E.01653
G1 X96.244 Y122.958 E.52767
G1 X96.779 Y122.958 E.01653
G1 X108.87 Y135.048 E.52767
G1 X109.405 Y135.048 E.01653
G1 X97.315 Y122.958 E.52767
G1 X97.85 Y122.958 E.01653
G1 X109.941 Y135.048 E.52767
G1 X110.477 Y135.048 E.01653
G1 X98.386 Y122.958 E.52767
G1 X98.921 Y122.958 E.01653
G1 X104.648 Y128.684 E.2499
G3 X104.567 Y128.068 I2.303 J-.614 E.01923
G1 X99.457 Y122.958 E.22302
G1 X99.635 Y122.958 E.0055
G1 X99.635 Y122.6 E.01103
G1 X104.598 Y127.563 E.2166
G3 X104.7 Y127.13 I1.698 J.17 E.01379
G1 X99.635 Y122.065 E.22104
G1 X99.635 Y121.529 E.01653
G1 X104.851 Y126.745 E.22762
G3 X105.043 Y126.401 I1.401 J.558 E.01218
G1 X99.635 Y120.994 E.23601
G1 X99.635 Y120.952 E.00129
G1 X100.129 Y120.952 E.01523
G1 X105.272 Y126.095 E.22446
G3 X105.536 Y125.824 I1.162 J.867 E.01172
G1 X100.665 Y120.952 E.21262
G1 X101.2 Y120.952 E.01653
G1 X105.835 Y125.587 E.2023
G3 X106.171 Y125.387 I.927 J1.176 E.01209
G1 X101.736 Y120.952 E.19358
G1 X102.271 Y120.952 E.01653
G1 X106.548 Y125.228 E.18663
G3 X106.972 Y125.117 I.636 J1.558 E.01357
G1 X102.807 Y120.952 E.18177
G1 X103.342 Y120.952 E.01653
G1 X107.461 Y125.07 E.17972
G3 X108.047 Y125.12 I.132 J1.895 E.01823
G1 X103.878 Y120.952 E.18193
G1 X104.414 Y120.952 E.01653
G1 X114.965 Y131.503 E.46048
G1 X114.965 Y130.967 E.01653
G1 X104.949 Y120.952 E.4371
G1 X105.485 Y120.952 E.01653
G1 X114.965 Y130.432 E.41373
G1 X114.965 Y129.896 E.01653
G1 X106.02 Y120.952 E.39036
G1 X106.556 Y120.952 E.01653
G1 X114.965 Y129.36 E.36698
G1 X114.965 Y128.825 E.01653
G1 X107.091 Y120.952 E.34361
G1 X107.627 Y120.952 E.01653
G1 X114.965 Y128.289 E.32023
G1 X114.965 Y127.754 E.01653
G1 X108.163 Y120.952 E.29686
G1 X108.698 Y120.952 E.01653
G1 X114.965 Y127.218 E.27348
G1 X114.965 Y126.683 E.01653
G1 X109.234 Y120.952 E.25011
G1 X109.769 Y120.952 E.01653
G1 X114.965 Y126.147 E.22674
G1 X114.965 Y125.611 E.01653
G1 X110.305 Y120.952 E.20336
G1 X110.841 Y120.952 E.01653
G1 X114.965 Y125.076 E.17999
G1 X114.965 Y124.54 E.01653
G1 X111.376 Y120.952 E.15661
G1 X111.912 Y120.952 E.01653
G1 X114.965 Y124.005 E.13324
G1 X114.965 Y123.469 E.01653
G1 X112.447 Y120.952 E.10987
G1 X112.983 Y120.952 E.01653
G1 X115.096 Y123.065 E.09222
G1 X115.631 Y123.065 E.01653
G1 X113.518 Y120.952 E.09222
G1 X114.054 Y120.952 E.01653
G1 X116.167 Y123.065 E.09222
G1 X116.703 Y123.065 E.01653
G1 X114.59 Y120.952 E.09222
G1 X115.125 Y120.952 E.01653
G1 X117.238 Y123.065 E.09222
G1 X117.774 Y123.065 E.01653
G1 X115.661 Y120.952 E.09222
G1 X116.196 Y120.952 E.01653
G1 X118.309 Y123.065 E.09222
G1 X118.845 Y123.065 E.01653
G1 X116.732 Y120.952 E.09222
G1 X117.267 Y120.952 E.01653
G1 X119.55 Y123.234 E.09962
; WIPE_START
G1 X118.136 Y121.82 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X116.017 Y129.153 Z1 F36000
G1 X115.134 Y132.208 Z1
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X110.154 Y127.228 E.21736
; WIPE_START
G1 X111.568 Y128.642 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X106.557 Y130.593 Z1 F36000
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X111.012 Y135.048 E.19443
G1 X111.548 Y135.048 E.01653
G1 X107.432 Y130.933 E.17961
G2 X107.937 Y130.902 I.003 J-4.023 E.0156
G1 X112.083 Y135.048 E.18097
G1 X112.619 Y135.048 E.01653
G1 X108.37 Y130.8 E.18542
G2 X108.755 Y130.649 I-.381 J-1.537 E.01279
G1 X113.154 Y135.048 E.192
G1 X113.69 Y135.048 E.01653
G1 X109.099 Y130.457 E.20038
G2 X109.405 Y130.228 I-.717 J-1.278 E.01184
G1 X114.226 Y135.048 E.21038
G1 X114.761 Y135.048 E.01653
G1 X109.676 Y129.964 E.22191
G2 X109.913 Y129.665 I-1.018 J-1.048 E.0118
G1 X115.297 Y135.048 E.23496
G1 X115.832 Y135.048 E.01653
G1 X110.113 Y129.329 E.24962
G2 X110.272 Y128.952 I-1.349 J-.792 E.01265
G1 X116.368 Y135.048 E.26604
G1 X116.904 Y135.048 E.01653
G1 X110.383 Y128.528 E.28456
G2 X110.434 Y128.044 I-1.815 J-.436 E.01508
G1 X114.965 Y132.574 E.19771
G1 X114.965 Y132.935 E.01115
G1 X115.326 Y132.935 E.01115
G1 X117.439 Y135.048 E.09222
G1 X117.975 Y135.048 E.01653
G1 X115.862 Y132.935 E.09222
G1 X116.397 Y132.935 E.01653
G1 X118.51 Y135.048 E.09222
G1 X119.046 Y135.048 E.01653
G1 X116.933 Y132.935 E.09222
G1 X117.468 Y132.935 E.01653
G1 X119.581 Y135.048 E.09222
G1 X120.117 Y135.048 E.01653
G1 X118.004 Y132.935 E.09222
G1 X118.54 Y132.935 E.01653
G1 X120.653 Y135.048 E.09222
G1 X121.188 Y135.048 E.01653
G1 X119.075 Y132.935 E.09222
G1 X119.611 Y132.935 E.01653
G1 X121.724 Y135.048 E.09222
G1 X122.259 Y135.048 E.01653
G1 X120.035 Y132.824 E.09706
G1 X120.035 Y132.289 E.01653
G1 X122.795 Y135.048 E.12043
G1 X123.33 Y135.048 E.01653
G1 X120.035 Y131.753 E.14381
G1 X120.035 Y131.218 E.01653
G1 X123.866 Y135.048 E.16718
G1 X124.402 Y135.048 E.01653
G1 X120.035 Y130.682 E.19056
G1 X120.035 Y130.146 E.01653
G1 X124.937 Y135.048 E.21393
G1 X125.473 Y135.048 E.01653
G1 X120.035 Y129.611 E.2373
G1 X120.035 Y129.075 E.01653
G1 X126.008 Y135.048 E.26068
G1 X126.544 Y135.048 E.01653
G1 X120.035 Y128.54 E.28405
G1 X120.035 Y128.004 E.01653
G1 X127.079 Y135.048 E.30743
G1 X127.615 Y135.048 E.01653
G1 X125.502 Y132.935 E.09222
G1 X126.038 Y132.935 E.01653
G1 X128.151 Y135.048 E.09222
G1 X128.686 Y135.048 E.01653
G1 X126.573 Y132.935 E.09222
G1 X127.109 Y132.935 E.01653
G1 X129.222 Y135.048 E.09222
G1 X129.757 Y135.048 E.01653
G1 X127.644 Y132.935 E.09222
G1 X128.18 Y132.935 E.01653
G1 X130.293 Y135.048 E.09222
G1 X130.829 Y135.048 E.01653
G1 X128.716 Y132.935 E.09222
G1 X129.251 Y132.935 E.01653
G1 X131.364 Y135.048 E.09222
G1 X131.9 Y135.048 E.01653
G1 X129.787 Y132.935 E.09222
G1 X130.035 Y132.935 E.00767
G1 X130.035 Y132.648 E.00885
G1 X132.435 Y135.048 E.10474
G1 X132.971 Y135.048 E.01653
G1 X130.035 Y132.113 E.12811
G1 X130.035 Y131.577 E.01653
G1 X133.506 Y135.048 E.15149
G1 X134.042 Y135.048 E.01653
G1 X130.035 Y131.042 E.17486
G1 X130.035 Y130.506 E.01653
G1 X134.578 Y135.048 E.19823
G1 X135.113 Y135.048 E.01653
G1 X130.035 Y129.971 E.22161
G1 X130.035 Y129.435 E.01653
G1 X135.649 Y135.048 E.24498
G1 X136.184 Y135.048 E.01653
G1 X130.035 Y128.899 E.26836
G1 X130.035 Y128.364 E.01653
G1 X136.72 Y135.048 E.29173
G1 X137.255 Y135.048 E.01653
G1 X130.035 Y127.828 E.3151
G1 X130.035 Y127.293 E.01653
G1 X137.791 Y135.048 E.33848
G1 X138.327 Y135.048 E.01653
G1 X130.035 Y126.757 E.36185
G1 X130.035 Y126.222 E.01653
G1 X138.862 Y135.048 E.38523
G1 X139.398 Y135.048 E.01653
G1 X130.035 Y125.686 E.4086
G1 X130.035 Y125.15 E.01653
G1 X140.103 Y135.218 E.43938
G1 X146.131 Y133.212 F36000
G1 F15000
G1 X140.382 Y127.463 E.2509
G3 X140.434 Y128.051 I-3.373 J.596 E.01824
G1 X145.425 Y133.042 E.21784
G1 X145.365 Y133.042 E.00187
G1 X145.365 Y133.517 E.01465
G1 X140.382 Y128.535 E.21745
G3 X140.27 Y128.958 I-1.666 J-.214 E.01356
G1 X145.365 Y134.053 E.22234
G1 X145.365 Y134.588 E.01653
G1 X140.11 Y129.334 E.22932
G3 X139.91 Y129.669 I-1.374 J-.594 E.01209
G1 X145.289 Y135.048 E.23476
G1 X144.754 Y135.048 E.01653
G1 X139.673 Y129.968 E.22173
G3 X139.401 Y130.231 I-1.137 J-.9 E.01172
M73 P56 R7
G1 X144.218 Y135.048 E.21022
G1 X143.682 Y135.048 E.01653
G1 X139.094 Y130.46 E.20025
G3 X138.75 Y130.652 I-.9 J-1.211 E.01219
G1 X143.147 Y135.048 E.19188
G1 X142.611 Y135.048 E.01653
G1 X138.365 Y130.802 E.18533
G3 X137.93 Y130.903 I-.601 J-1.599 E.01381
G1 X142.076 Y135.048 E.18092
G1 X141.54 Y135.048 E.01653
G1 X137.424 Y130.932 E.17963
G3 X136.804 Y130.848 I.117 J-3.189 E.01933
G1 X141.004 Y135.048 E.1833
G1 X140.469 Y135.048 E.01653
G1 X130.035 Y124.615 E.45535
G1 X130.035 Y124.079 E.01653
G1 X134.649 Y128.693 E.20137
G3 X134.568 Y128.076 I2.303 J-.619 E.01927
G1 X129.866 Y123.374 E.20521
; WIPE_START
G1 X131.28 Y124.788 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X126.549 Y130.777 Z1 F36000
G1 X125.134 Y132.568 Z1
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X120.035 Y127.469 E.22254
G1 X120.035 Y126.933 E.01653
G1 X124.965 Y131.862 E.21513
G1 X124.965 Y131.327 E.01653
G1 X120.035 Y126.397 E.21513
G1 X120.035 Y125.862 E.01653
G1 X124.965 Y130.791 E.21513
G1 X124.965 Y130.256 E.01653
G1 X120.035 Y125.326 E.21513
G1 X120.035 Y124.791 E.01653
G1 X124.965 Y129.72 E.21513
G1 X124.965 Y129.185 E.01653
G1 X120.035 Y124.255 E.21513
G1 X120.035 Y123.72 E.01653
G1 X124.965 Y128.649 E.21513
G1 X124.965 Y128.113 E.01653
G1 X117.803 Y120.952 E.31255
G1 X118.339 Y120.952 E.01653
G1 X124.965 Y127.578 E.28918
G1 X124.965 Y127.042 E.01653
G1 X118.874 Y120.952 E.26581
G1 X119.41 Y120.952 E.01653
G1 X124.965 Y126.507 E.24243
G1 X124.965 Y125.971 E.01653
G1 X119.945 Y120.952 E.21906
G1 X120.481 Y120.952 E.01653
G1 X124.965 Y125.435 E.19568
G1 X124.965 Y124.9 E.01653
G1 X121.016 Y120.952 E.17231
G1 X121.552 Y120.952 E.01653
G1 X124.965 Y124.364 E.14894
G1 X124.965 Y123.829 E.01653
G1 X122.088 Y120.952 E.12556
G1 X122.623 Y120.952 E.01653
G1 X124.965 Y123.293 E.10219
G1 X124.965 Y123.065 E.00705
G1 X125.272 Y123.065 E.00948
G1 X123.159 Y120.952 E.09222
G1 X123.694 Y120.952 E.01653
G1 X125.807 Y123.065 E.09222
G1 X126.343 Y123.065 E.01653
G1 X124.23 Y120.952 E.09222
G1 X124.766 Y120.952 E.01653
G1 X126.879 Y123.065 E.09222
G1 X127.414 Y123.065 E.01653
G1 X125.301 Y120.952 E.09222
G1 X125.837 Y120.952 E.01653
G1 X127.95 Y123.065 E.09222
G1 X128.485 Y123.065 E.01653
G1 X126.372 Y120.952 E.09222
G1 X126.908 Y120.952 E.01653
G1 X129.021 Y123.065 E.09222
G1 X129.556 Y123.065 E.01653
G1 X127.443 Y120.952 E.09222
G1 X127.979 Y120.952 E.01653
G1 X134.597 Y127.57 E.28883
G3 X134.698 Y127.135 I1.702 J.167 E.01381
G1 X128.515 Y120.952 E.26987
G1 X129.05 Y120.952 E.01653
G1 X134.848 Y126.75 E.25305
G3 X135.04 Y126.406 I1.402 J.555 E.01219
G1 X129.586 Y120.952 E.23804
G1 X130.121 Y120.952 E.01653
G1 X135.269 Y126.099 E.22464
G3 X135.532 Y125.827 I1.165 J.866 E.01172
G1 X130.657 Y120.952 E.21278
G1 X131.192 Y120.952 E.01653
G1 X135.831 Y125.59 E.20243
G3 X136.166 Y125.39 I.929 J1.174 E.01209
G1 X131.728 Y120.952 E.19369
G1 X132.264 Y120.952 E.01653
G1 X136.542 Y125.23 E.18671
G3 X136.965 Y125.118 I.638 J1.554 E.01356
G1 X132.799 Y120.952 E.18182
G1 X133.335 Y120.952 E.01653
G1 X137.453 Y125.069 E.17971
G1 X137.879 Y125.087 E.01318
G1 X138.037 Y125.118 E.00496
G1 X133.87 Y120.952 E.18184
G1 X134.406 Y120.952 E.01653
G1 X146.497 Y133.042 E.52767
G1 X147.032 Y133.042 E.01653
G1 X134.941 Y120.952 E.52767
G1 X135.477 Y120.952 E.01653
G1 X147.568 Y133.042 E.52767
G1 X148.103 Y133.042 E.01653
G1 X136.013 Y120.952 E.52767
G1 X136.548 Y120.952 E.01653
G1 X148.639 Y133.042 E.52767
G1 X149.174 Y133.042 E.01653
G1 X137.084 Y120.952 E.52767
G1 X137.619 Y120.952 E.01653
G1 X149.71 Y133.042 E.52767
G1 X150.246 Y133.042 E.01653
G1 X138.155 Y120.952 E.52767
G1 X138.691 Y120.952 E.01653
G1 X150.781 Y133.042 E.52767
G1 X151.317 Y133.042 E.01653
G1 X139.226 Y120.952 E.52767
G1 X139.762 Y120.952 E.01653
G1 X151.852 Y133.042 E.52767
G1 X152.388 Y133.042 E.01653
G1 X140.297 Y120.952 E.52767
G1 X140.833 Y120.952 E.01653
G1 X152.924 Y133.042 E.52767
G1 X153.459 Y133.042 E.01653
G1 X141.368 Y120.952 E.52767
G1 X141.904 Y120.952 E.01653
G1 X153.995 Y133.042 E.52767
G1 X154.53 Y133.042 E.01653
G1 X142.44 Y120.952 E.52767
G1 X142.975 Y120.952 E.01653
G1 X155.236 Y133.212 E.53508
; WIPE_START
G1 X153.821 Y131.798 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.119 Y136.11 Z1 F36000
G1 X160.616 Y136.45 Z1
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X161.216 Y137.05 E.02618
G1 X161.751 Y137.05 E.01653
G1 X160.785 Y136.084 E.04215
G1 X160.785 Y135.548 E.01653
G1 X161.915 Y136.678 E.04929
G1 X161.915 Y136.142 E.01653
G1 X160.785 Y135.013 E.04929
G1 X160.785 Y134.477 E.01653
G1 X161.915 Y135.607 E.04929
G1 X161.915 Y135.071 E.01653
G1 X160.785 Y133.942 E.04929
G1 X160.785 Y133.406 E.01653
G1 X162.084 Y134.705 E.05669
G1 X162.084 Y119.173 F36000
G1 F15000
G1 X161.861 Y118.95 E.00974
G1 X161.326 Y118.95 E.01653
G1 X161.915 Y119.539 E.02571
G1 X161.915 Y120.075 E.01653
G1 X160.785 Y118.95 E.04919
G1 X160.785 Y119.481 E.01639
G1 X161.915 Y120.61 E.04929
G1 X161.915 Y121.146 E.01653
G1 X160.785 Y120.017 E.04929
G1 X160.785 Y120.552 E.01653
G1 X161.915 Y121.682 E.04929
G1 X161.915 Y122.217 E.01653
G1 X160.785 Y121.088 E.04929
G1 X160.785 Y121.623 E.01653
G1 X161.915 Y122.753 E.04929
G1 X161.915 Y123.288 E.01653
G1 X160.785 Y122.159 E.04929
G1 X160.785 Y122.695 E.01653
G1 X161.915 Y123.824 E.04929
G1 X161.915 Y124.36 E.01653
G1 X160.513 Y122.958 E.06118
G1 X159.977 Y122.958 E.01653
G1 X168.049 Y131.029 E.35227
G1 X168.585 Y131.029 E.01653
G1 X162.526 Y124.971 E.26442
G1 X163.061 Y124.971 E.01653
G1 X169.12 Y131.029 E.26442
G1 X169.656 Y131.029 E.01653
G1 X163.597 Y124.971 E.26442
G1 X164.133 Y124.971 E.01653
G1 X169.915 Y130.753 E.25235
G1 X169.915 Y130.217 E.01653
G1 X164.668 Y124.971 E.22897
G1 X165.204 Y124.971 E.01653
G1 X169.915 Y129.682 E.2056
G1 X169.915 Y129.146 E.01653
G1 X165.739 Y124.971 E.18223
G1 X166.275 Y124.971 E.01653
G1 X169.915 Y128.61 E.15885
G1 X169.915 Y128.075 E.01653
G1 X166.81 Y124.971 E.13548
G1 X167.346 Y124.971 E.01653
G1 X169.915 Y127.539 E.1121
G1 X169.915 Y127.004 E.01653
G1 X167.882 Y124.971 E.08873
G1 X168.417 Y124.971 E.01653
G1 X169.915 Y126.468 E.06536
G1 X169.915 Y125.933 E.01653
G1 X168.953 Y124.971 E.04198
G1 X169.488 Y124.971 E.01653
G1 X170.084 Y125.567 E.02601
G1 X167.683 Y131.199 F36000
G1 F15000
G1 X159.442 Y122.958 E.35968
G1 X158.906 Y122.958 E.01653
G1 X166.978 Y131.029 E.35227
G1 X166.442 Y131.029 E.01653
G1 X158.371 Y122.958 E.35227
G1 X157.835 Y122.958 E.01653
G1 X165.907 Y131.029 E.35227
G1 X165.371 Y131.029 E.01653
G1 X157.299 Y122.958 E.35227
G1 X156.764 Y122.958 E.01653
G1 X164.835 Y131.029 E.35227
G1 X164.3 Y131.029 E.01653
G1 X156.228 Y122.958 E.35227
G1 X155.693 Y122.958 E.01653
G1 X163.764 Y131.029 E.35227
G1 X163.229 Y131.029 E.01653
G1 X155.157 Y122.958 E.35227
G1 X154.621 Y122.958 E.01653
G1 X162.693 Y131.029 E.35227
G1 X162.158 Y131.029 E.01653
G1 X154.086 Y122.958 E.35227
G1 X153.55 Y122.958 E.01653
G1 X161.915 Y131.322 E.36504
G1 X161.915 Y131.858 E.01653
G1 X153.015 Y122.958 E.38842
G1 X152.479 Y122.958 E.01653
G1 X161.915 Y132.393 E.41179
G1 X161.915 Y132.929 E.01653
G1 X151.944 Y122.958 E.43517
G1 X151.408 Y122.958 E.01653
G1 X161.915 Y133.464 E.45854
G1 X161.915 Y134 E.01653
G1 X150.872 Y122.958 E.48191
G1 X150.337 Y122.958 E.01653
G1 X160.422 Y133.042 E.44013
G1 X159.886 Y133.042 E.01653
G1 X149.801 Y122.958 E.44013
G1 X149.266 Y122.958 E.01653
G1 X159.35 Y133.042 E.44013
G1 X158.815 Y133.042 E.01653
G1 X148.73 Y122.958 E.44013
G1 X148.195 Y122.958 E.01653
G1 X158.279 Y133.042 E.44013
G1 X157.744 Y133.042 E.01653
G1 X147.659 Y122.958 E.44013
G1 X147.123 Y122.958 E.01653
G1 X157.208 Y133.042 E.44013
G1 X156.673 Y133.042 E.01653
G1 X146.588 Y122.958 E.44013
G1 X146.052 Y122.958 E.01653
G1 X156.137 Y133.042 E.44013
G1 X155.601 Y133.042 E.01653
G1 X143.511 Y120.952 E.52767
G1 X144.046 Y120.952 E.01653
G1 X145.365 Y122.27 E.05754
G1 X145.365 Y121.735 E.01653
G1 X144.582 Y120.952 E.03416
G1 X145.117 Y120.952 E.01653
G1 X145.534 Y121.369 E.0182
; CHANGE_LAYER
; Z_HEIGHT: 0.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X145.117 Y120.952 E-.22405
G1 X144.582 Y120.952 E-.20352
G1 X145.2 Y121.57 E-.33243
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
G1 X129.702 Y123.398
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X129.702 Y132.602 E.30532
G1 X125.298 Y132.602 E.14609
G1 X125.298 Y123.398 E.30532
G1 X129.642 Y123.398 E.1441
G1 X129.31 Y123.79 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X129.31 Y132.21 E.25872
G1 X125.69 Y132.21 E.11123
G1 X125.69 Y123.79 E.25872
G1 X129.25 Y123.79 E.10939
; WIPE_START
M204 S10000
G1 X129.264 Y125.79 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.048 Y130.218 Z1.2 F36000
G1 X119.702 Y132.602 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X115.298 Y132.602 E.14609
G1 X115.298 Y123.398 E.30532
G1 X119.702 Y123.398 E.14609
G1 X119.702 Y132.542 E.30333
G1 X119.31 Y132.21 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X115.69 Y132.21 E.11123
G1 X115.69 Y123.79 E.25872
G1 X119.31 Y123.79 E.11123
G1 X119.31 Y132.15 E.25688
; WIPE_START
M204 S10000
G1 X117.31 Y132.183 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X110.612 Y128.525 Z1.2 F36000
G1 X105.898 Y125.95 Z1.2
G1 Z.8
M73 P57 R7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.918 Y125.938 E.00078
G3 X107.407 Y125.403 I1.582 J2.062 E.05333
G3 X106.918 Y130.533 I.092 J2.597 E.29333
G3 X105.662 Y126.162 I.582 J-2.533 E.18365
G1 X105.853 Y125.99 E.00852
G1 X106.159 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.433 Y125.794 I1.349 J1.749 E.04227
G3 X108.346 Y125.958 I.085 J2.156 E.02874
G3 X106.112 Y126.29 I-.838 J2.043 E.35352
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13246
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10986
G1 X107.211 Y125.808 E-.10985
G1 X107.433 Y125.794 E-.0842
G1 X107.789 Y125.808 E-.1354
G1 X107.991 Y125.849 E-.07833
; WIPE_END
G1 E-.04 F1800
G1 X115.553 Y126.882 Z1.2 F36000
G1 X135.45 Y129.602 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.441 Y129.58 E.0008
G3 X137.407 Y125.403 I2.067 J-1.578 E.18843
G3 X138.802 Y125.745 I.081 J2.678 E.04824
G3 X135.664 Y129.836 I-1.294 J2.256 E.29409
G1 X135.491 Y129.647 E.00852
G1 X135.754 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.433 Y125.794 I1.754 J-1.34 E.14845
G3 X138.346 Y125.958 I.085 J2.156 E.02874
G3 X135.791 Y129.387 I-.838 J2.042 E.24713
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13246
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07815
; WIPE_END
G1 E-.04 F1800
G1 X127.734 Y128.036 Z1.2 F36000
G1 X92.452 Y130.472 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X92.452 Y125.528 E.164
G1 X85.752 Y125.528 E.22225
G1 X85.752 Y122.647 E.09555
G1 X99.302 Y122.647 E.44948
G1 X99.302 Y120.637 E.0667
G1 X145.698 Y120.637 E1.53904
G1 X145.698 Y122.647 E.0667
G1 X160.452 Y122.647 E.48942
G1 X160.452 Y118.629 E.13329
G1 X162.248 Y118.629 E.05957
G1 X162.248 Y124.665 E.20023
G1 X170.248 Y124.665 E.26537
G1 X170.248 Y131.335 E.22124
G1 X162.248 Y131.335 E.26537
G1 X162.248 Y137.371 E.20023
G1 X160.452 Y137.371 E.05957
G1 X160.452 Y133.353 E.13329
G1 X145.698 Y133.353 E.48942
G1 X145.698 Y135.363 E.0667
G1 X99.302 Y135.363 E1.53904
G1 X99.302 Y133.353 E.0667
G1 X85.752 Y133.353 E.44948
G1 X85.752 Y130.472 E.09555
G1 X92.392 Y130.472 E.22026
G1 X92.06 Y130.08 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X92.06 Y125.92 E.12782
G1 X92.019 Y125.92 E.00126
G1 X85.36 Y125.92 E.20461
G1 X85.36 Y125.896 E.00075
G1 X85.36 Y122.255 E.11186
G1 X98.91 Y122.255 E.41635
G1 X98.91 Y120.245 E.06179
G1 X146.09 Y120.245 E1.44971
G1 X146.09 Y122.255 E.06179
G1 X160.06 Y122.255 E.42926
G1 X160.06 Y118.237 E.12347
G1 X162.64 Y118.237 E.07928
G1 X162.64 Y124.273 E.18547
G1 X170.64 Y124.273 E.24582
G1 X170.64 Y131.727 E.22903
G1 X162.64 Y131.727 E.24582
G1 X162.64 Y137.763 E.18547
G1 X160.06 Y137.763 E.07928
G1 X160.06 Y133.745 E.12347
G1 X146.09 Y133.745 E.42926
G1 X146.09 Y135.755 E.06179
G1 X98.91 Y135.755 E1.44971
G1 X98.91 Y133.745 E.06179
G1 X85.36 Y133.745 E.41635
G1 X85.36 Y130.104 E.11186
G1 X85.36 Y130.08 E.00075
G1 X92 Y130.08 E.20403
; WIPE_START
M204 S10000
G1 X92.029 Y128.08 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X88.577 Y122.996 Z1.2 F36000
G1 Z.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.949 Y122.996 E.05401
G1 X86.1 Y123.844 E.03979
G1 X86.1 Y124.48 E.0211
G1 X86.8 Y125.18 E.03282
G1 X92.44 Y125.18 E.18711
G1 X94.624 Y122.996 E.10246
G1 X92.292 Y122.996 E.07738
G1 X104.311 Y135.015 E.56386
G1 X105.633 Y135.015 E.04384
G1 X114.95 Y125.698 E.43707
G1 X114.95 Y130.302 E.1527
G1 X105.633 Y120.985 E.43707
G1 X104.311 Y120.985 E.04384
G1 X92.292 Y133.004 E.56386
G1 X94.625 Y133.004 E.07738
G1 X92.441 Y130.82 E.10246
G1 X86.8 Y130.82 E.18711
G1 X86.1 Y131.52 E.03282
G1 X86.1 Y132.156 E.0211
G1 X86.949 Y133.004 E.03979
G1 X88.577 Y133.004 E.05401
; WIPE_START
G1 X86.949 Y133.004 E-.61876
G1 X86.686 Y132.741 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X94.21 Y134.023 Z1.2 F36000
G1 X99.65 Y134.95 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G1 X99.65 Y133.322 E.05401
G1 X104.583 Y128.389 E.23142
G3 X104.575 Y127.603 I3.46 J-.429 E.02612
G1 X99.65 Y122.678 E.23104
G1 X99.65 Y121.05 E.05401
; WIPE_START
G1 X99.65 Y122.678 E-.61876
G1 X99.913 Y122.941 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X105.943 Y127.62 Z1.2 F36000
G1 X109.369 Y130.279 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G3 X107.897 Y130.925 I-1.912 J-2.36 E.05396
G1 X111.987 Y135.015 E.19189
G1 X113.309 Y135.015 E.04384
G1 X115.374 Y132.95 E.09686
G1 X117.598 Y132.95 E.0738
G1 X119.663 Y135.015 E.09686
G1 X120.985 Y135.015 E.04384
G1 X124.95 Y131.05 E.186
G1 X124.95 Y124.95 E.20237
G1 X120.985 Y120.985 E.186
G1 X119.663 Y120.985 E.04384
G1 X117.598 Y123.05 E.09686
G1 X115.374 Y123.05 E.0738
G1 X113.309 Y120.985 E.09686
G1 X111.987 Y120.985 E.04384
G1 X107.897 Y125.075 E.19189
G3 X109.369 Y125.721 I-.44 J3.005 E.05396
; WIPE_START
G1 X108.63 Y125.272 E-.32852
G1 X107.897 Y125.075 E-.28838
G1 X108.163 Y124.809 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X115.653 Y126.277 Z1.2 F36000
G1 X149.985 Y133.004 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G1 X148.356 Y133.004 E.05401
G1 X136.337 Y120.985 E.56386
G1 X135.015 Y120.985 E.04384
G1 X130.05 Y125.95 E.23291
G1 X130.05 Y130.05 E.13603
G1 X135.015 Y135.015 E.23291
G1 X136.337 Y135.015 E.04384
G1 X148.356 Y122.996 E.56386
G1 X149.985 Y122.996 E.05401
; WIPE_START
G1 X148.356 Y122.996 E-.61876
G1 X148.093 Y123.259 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X153.654 Y128.487 Z1.2 F36000
G1 X160.8 Y135.208 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X153.7 Y122.996 E.38469
G1 X156.032 Y122.996 E.07738
G1 X146.024 Y133.004 E.46952
G1 X145.35 Y133.004 E.02235
G1 X145.35 Y133.678 E.02235
G1 X144.013 Y135.015 E.06272
G1 X142.691 Y135.015 E.04384
G1 X138.461 Y130.785 E.19845
G3 X134.715 Y128.961 I-.961 J-2.785 E.15351
G1 X128.661 Y135.015 E.28402
G1 X127.339 Y135.015 E.04384
G1 X125.274 Y132.95 E.09686
G1 X124.95 Y132.95 E.01077
G1 X124.95 Y132.626 E.01077
G1 X120.05 Y127.726 E.22984
G1 X120.05 Y128.274 E.01816
G1 X124.95 Y123.374 E.22984
G1 X124.95 Y123.05 E.01077
G1 X125.274 Y123.05 E.01077
G1 X127.339 Y120.985 E.09686
G1 X128.661 Y120.985 E.04384
G1 X134.718 Y127.042 E.28417
G3 X138.461 Y125.215 I2.781 J.95 E.15354
G1 X142.691 Y120.985 E.19845
G1 X144.013 Y120.985 E.04384
G1 X145.35 Y122.322 E.06272
G1 X145.35 Y122.996 E.02235
G1 X146.024 Y122.996 E.02235
G1 X156.032 Y133.004 E.46952
G1 X153.7 Y133.004 E.07738
G1 X161.9 Y124.804 E.38469
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
; WIPE_START
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X164.348 Y129.573 Z1.2 F36000
G1 X165.022 Y130.986 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G1 X163.393 Y130.986 E.05401
G1 X169.366 Y125.014 E.2802
G1 X163.393 Y125.014 E.19813
G1 X169.366 Y130.986 E.2802
G1 X169.9 Y130.986 E.0177
G1 X169.9 Y129.892 E.03632
; CHANGE_LAYER
; Z_HEIGHT: 1
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X169.9 Y130.986 E-.41605
G1 X169.366 Y130.986 E-.20271
G1 X169.103 Y130.724 E-.14124
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
G1 X129.702 Y123.398
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X129.702 Y132.602 E.30532
G1 X125.298 Y132.602 E.14609
G1 X125.298 Y123.398 E.30532
G1 X129.642 Y123.398 E.1441
G1 X129.31 Y123.79 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X129.31 Y132.21 E.25872
G1 X125.69 Y132.21 E.11123
G1 X125.69 Y123.79 E.25872
G1 X129.25 Y123.79 E.10939
; WIPE_START
M204 S10000
G1 X129.264 Y125.79 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.048 Y130.218 Z1.4 F36000
G1 X119.702 Y132.602 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X115.298 Y132.602 E.14609
G1 X115.298 Y123.398 E.30532
G1 X119.702 Y123.398 E.14609
G1 X119.702 Y132.542 E.30333
G1 X119.31 Y132.21 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X115.69 Y132.21 E.11123
G1 X115.69 Y123.79 E.25872
G1 X119.31 Y123.79 E.11123
G1 X119.31 Y132.15 E.25688
; WIPE_START
M204 S10000
G1 X117.31 Y132.183 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X110.624 Y128.503 Z1.4 F36000
G1 X105.935 Y125.922 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.203 Y125.753 E.0105
G3 X107.392 Y125.404 I1.306 J2.249 E.0415
M73 P58 R7
G3 X108.802 Y125.745 I.1 J2.67 E.04874
G3 X105.893 Y125.964 I-1.293 J2.256 E.4393
G1 X106.16 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.417 Y125.795 I1.349 J1.748 E.04178
G3 X108.346 Y125.958 I.102 J2.15 E.02921
G3 X106.113 Y126.291 I-.837 J2.043 E.35349
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13245
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10986
G1 X107.211 Y125.808 E-.10987
G1 X107.417 Y125.795 E-.07834
G1 X107.789 Y125.808 E-.14122
G1 X107.991 Y125.849 E-.07838
; WIPE_END
G1 E-.04 F1800
G1 X115.553 Y126.882 Z1.4 F36000
G1 X135.45 Y129.602 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.439 Y129.582 E.00078
G3 X137.392 Y125.404 I2.062 J-1.581 E.18818
G3 X136.933 Y130.536 I.113 J2.597 E.29371
G3 X135.663 Y129.837 I.568 J-2.536 E.04873
G1 X135.49 Y129.647 E.00852
G1 X135.753 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.417 Y125.795 I1.756 J-1.339 E.14796
G3 X138.346 Y125.958 I.102 J2.15 E.02921
G3 X135.79 Y129.387 I-.837 J2.043 E.2473
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13247
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07814
; WIPE_END
G1 E-.04 F1800
G1 X127.733 Y128.02 Z1.4 F36000
G1 X92.452 Y130.383 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X92.452 Y125.617 E.15813
G1 X85.752 Y125.617 E.22225
G1 X85.752 Y122.671 E.09772
G1 X99.302 Y122.671 E.44948
G1 X99.302 Y120.656 E.06682
G1 X145.698 Y120.656 E1.53904
G1 X145.698 Y122.671 E.06682
G1 X160.452 Y122.671 E.48942
G1 X160.452 Y118.647 E.13347
G1 X162.248 Y118.647 E.05957
G1 X162.248 Y124.709 E.20109
G1 X170.248 Y124.709 E.26537
G1 X170.248 Y131.291 E.21834
G1 X162.248 Y131.291 E.26537
G1 X162.248 Y137.353 E.20109
G1 X160.452 Y137.353 E.05957
G1 X160.452 Y133.329 E.13347
G1 X145.698 Y133.329 E.48942
G1 X145.698 Y135.344 E.06682
G1 X99.302 Y135.344 E1.53904
G1 X99.302 Y133.329 E.06682
G1 X85.752 Y133.329 E.44948
G1 X85.752 Y130.383 E.09773
G1 X92.392 Y130.383 E.22026
G1 X92.06 Y129.991 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X92.06 Y126.409 E.11009
G1 X92.06 Y126.009 E.01229
G1 F11234.209
G1 X92.019 Y126.009 E.00126
G1 F11100
G1 X85.36 Y126.009 E.20461
G1 F11255.861
G1 X85.36 Y125.961 E.00146
G1 F12000
G1 X85.36 Y125.561 E.01229
G1 X85.36 Y122.278 E.10086
G1 X98.91 Y122.278 E.41635
G1 X98.91 Y120.264 E.06189
G1 X146.09 Y120.264 E1.44971
G1 X146.09 Y122.278 E.06189
G1 X160.06 Y122.278 E.42926
G1 X160.06 Y118.255 E.12363
G1 X162.64 Y118.255 E.07928
G1 X162.64 Y124.317 E.18627
G1 X170.64 Y124.317 E.24582
G1 X170.64 Y131.683 E.22634
G1 X162.64 Y131.683 E.24582
G1 X162.64 Y137.745 E.18627
G1 X160.06 Y137.745 E.07928
G1 X160.06 Y133.722 E.12363
G1 X146.09 Y133.722 E.42926
G1 X146.09 Y135.736 E.06189
G1 X98.91 Y135.736 E1.44971
G1 X98.91 Y133.722 E.06189
G1 X85.36 Y133.722 E.41635
G1 X85.36 Y130.439 E.10086
G1 X85.36 Y130.039 E.01229
G1 F11255.861
G1 X85.36 Y129.991 E.00146
G1 F11100
G1 X92 Y129.991 E.20403
; WIPE_START
M204 S10000
G1 X92.033 Y127.992 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X88.554 Y132.981 Z1.4 F36000
G1 Z1
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.925 Y132.981 E.05401
G1 X86.1 Y132.156 E.03871
G1 X86.1 Y131.52 E.0211
G1 X86.889 Y130.732 E.03698
G1 X92.352 Y130.732 E.18123
G1 X94.601 Y132.981 E.10553
G1 X92.315 Y132.981 E.07585
G1 X104.292 Y121.005 E.56185
G1 X105.653 Y121.005 E.04515
G1 X114.95 Y130.302 E.43614
G1 X114.95 Y125.698 E.1527
G1 X105.653 Y134.995 E.43614
G1 X104.292 Y134.995 E.04515
G1 X92.315 Y123.019 E.56185
G1 X94.601 Y123.019 E.07584
G1 X92.352 Y125.268 E.10553
G1 X86.889 Y125.268 E.18123
G1 X86.1 Y124.48 E.03698
G1 X86.1 Y123.844 E.0211
G1 X86.925 Y123.019 E.03871
G1 X88.554 Y123.019 E.05401
; WIPE_START
G1 X86.925 Y123.019 E-.61876
G1 X86.663 Y123.282 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X94.185 Y121.989 Z1.4 F36000
G1 X99.65 Y121.05 Z1.4
G1 Z1
G1 E.8 F1800
G1 F15476.087
G1 X99.65 Y122.678 E.05401
G1 X104.575 Y127.603 E.23104
G2 X104.575 Y128.397 I34.472 J.396 E.02633
G1 X99.65 Y133.322 E.23104
G1 X99.65 Y134.95 E.05401
; WIPE_START
G1 X99.65 Y133.322 E-.61876
G1 X99.913 Y133.059 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X105.943 Y128.38 Z1.4 F36000
G1 X109.369 Y125.721 Z1.4
G1 Z1
G1 E.8 F1800
G1 F15476.087
G2 X107.897 Y125.075 I-1.912 J2.36 E.05396
G1 X111.968 Y121.005 E.19096
G1 X113.329 Y121.005 E.04515
G1 X115.374 Y123.05 E.09594
G1 X117.598 Y123.05 E.0738
G1 X119.644 Y121.005 E.09594
G1 X121.005 Y121.005 E.04515
G1 X124.95 Y124.95 E.18507
G1 X124.95 Y131.05 E.20237
G1 X121.005 Y134.995 E.18507
G1 X119.644 Y134.995 E.04515
G1 X117.598 Y132.95 E.09594
G1 X115.374 Y132.95 E.0738
G1 X113.329 Y134.995 E.09594
G1 X111.968 Y134.995 E.04515
G1 X107.897 Y130.925 E.19096
G2 X109.369 Y130.279 I-.44 J-3.006 E.05396
; WIPE_START
G1 X108.63 Y130.728 E-.32852
G1 X107.897 Y130.925 E-.28837
G1 X108.163 Y131.191 E-.14311
; WIPE_END
G1 E-.04 F1800
G1 X115.654 Y129.727 Z1.4 F36000
G1 X149.961 Y123.019 Z1.4
G1 Z1
G1 E.8 F1800
G1 F15476.087
G1 X148.333 Y123.019 E.05401
G1 X136.356 Y134.995 E.56185
G1 X134.995 Y134.995 E.04515
G1 X130.05 Y130.05 E.23199
G1 X130.05 Y125.95 E.13603
G1 X134.995 Y121.005 E.23199
G1 X136.356 Y121.005 E.04515
G1 X148.333 Y132.981 E.56185
G1 X149.961 Y132.981 E.05401
; WIPE_START
G1 X148.333 Y132.981 E-.61876
G1 X148.07 Y132.718 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X153.64 Y127.5 Z1.4 F36000
G1 X160.8 Y120.792 Z1.4
G1 Z1
G1 E.8 F1800
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.733 E.04023
G2 X161.82 Y124.883 I.036 J.115 E.00628
G1 X153.723 Y132.981 E.37988
G1 X156.009 Y132.981 E.07585
G1 X146.047 Y123.019 E.46736
G1 X145.35 Y123.019 E.02312
G1 X145.35 Y122.322 E.02312
G1 X144.032 Y121.005 E.0618
G1 X142.671 Y121.005 E.04515
G1 X138.461 Y125.215 E.19752
G2 X134.715 Y127.039 I-.961 J2.785 E.15351
G1 X128.681 Y121.005 E.28309
G1 X127.319 Y121.005 E.04515
G1 X125.274 Y123.05 E.09594
G1 X124.95 Y123.05 E.01077
G1 X124.95 Y123.374 E.01077
G1 X120.05 Y128.274 E.22984
G1 X120.05 Y127.726 E.01816
G1 X124.95 Y132.626 E.22984
G1 X124.95 Y132.95 E.01077
G1 X125.274 Y132.95 E.01077
G1 X127.319 Y134.995 E.09594
G1 X128.681 Y134.995 E.04515
G1 X134.715 Y128.961 E.28309
G2 X138.461 Y130.785 I2.785 J-.961 E.15351
G1 X142.671 Y134.995 E.19752
G1 X144.032 Y134.995 E.04515
G1 X145.35 Y133.678 E.0618
G1 X145.35 Y132.981 E.02312
G1 X146.047 Y132.981 E.02312
G1 X156.009 Y123.019 E.46736
G1 X153.723 Y123.019 E.07585
G1 X161.82 Y131.117 E.37988
G2 X161.9 Y131.267 I.115 J.036 E.00628
G1 X161.9 Y132.48 E.04023
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.208 E.05401
; WIPE_START
G1 X160.8 Y133.579 E-.61876
G1 X161.063 Y133.317 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X168.433 Y131.333 Z1.4 F36000
G1 X169.896 Y130.939 Z1.4
G1 Z1
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X162.267 Y130.939 E.21137
; Slow Down End
G1 X169.9 Y129.892 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X169.9 Y130.588 E.02309
G1 X168.967 Y130.588 E.03092
G1 X163.792 Y125.412 E.24279
G1 X168.967 Y125.412 E.17168
G1 X163.792 Y130.588 E.24279
G1 X165.42 Y130.588 E.05401
G1 X169.896 Y125.061 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X162.267 Y125.061 E.21137
; Slow Down End
; CHANGE_LAYER
; Z_HEIGHT: 1.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X164.267 Y125.061 E-.76
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
G1 X129.702 Y123.398
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X129.702 Y132.602 E.30532
G1 X125.298 Y132.602 E.14609
G1 X125.298 Y123.398 E.30532
G1 X129.642 Y123.398 E.1441
G1 X129.31 Y123.79 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X129.31 Y132.21 E.25872
G1 X125.69 Y132.21 E.11123
G1 X125.69 Y123.79 E.25872
G1 X129.25 Y123.79 E.10939
; WIPE_START
M204 S10000
G1 X129.264 Y125.79 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.048 Y130.218 Z1.6 F36000
G1 X119.702 Y132.602 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X115.298 Y132.602 E.14609
G1 X115.298 Y123.398 E.30532
G1 X119.702 Y123.398 E.14609
G1 X119.702 Y132.542 E.30333
G1 X119.31 Y132.21 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X115.69 Y132.21 E.11123
G1 X115.69 Y123.79 E.25872
G1 X119.31 Y123.79 E.11123
G1 X119.31 Y132.15 E.25688
; WIPE_START
M204 S10000
G1 X117.31 Y132.183 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X110.612 Y128.525 Z1.6 F36000
M73 P59 R7
G1 X105.898 Y125.95 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.919 Y125.939 E.00079
G3 X107.376 Y125.405 I1.582 J2.061 E.0523
G3 X110.057 Y127.539 I.137 J2.579 E.12427
G3 X108.905 Y130.186 I-2.528 J.474 E.10167
G3 X106.948 Y130.539 I-1.406 J-2.191 E.06768
G3 X105.663 Y126.163 I.553 J-2.539 E.1846
G1 X105.853 Y125.99 E.00852
G1 X106.159 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.402 Y125.796 I1.348 J1.749 E.04131
G3 X108.605 Y126.086 I.091 J2.264 E.03852
G3 X106.112 Y126.29 I-1.098 J1.916 E.34458
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13246
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.212 Y125.808 E-.10989
G1 X107.402 Y125.796 E-.07248
G1 X107.789 Y125.808 E-.14703
G1 X107.991 Y125.849 E-.0784
; WIPE_END
G1 E-.04 F1800
G1 X115.553 Y126.882 Z1.6 F36000
G1 X135.45 Y129.602 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.439 Y129.581 E.00079
G3 X137.376 Y125.405 I2.062 J-1.581 E.18766
G3 X137.961 Y130.557 I.123 J2.595 E.25945
G3 X136.948 Y130.539 I-.468 J-2.209 E.03392
G3 X135.663 Y129.837 I.553 J-2.539 E.04923
G1 X135.49 Y129.647 E.00852
G1 X135.754 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.402 Y125.796 I1.754 J-1.34 E.14751
G3 X138.605 Y126.086 I.091 J2.264 E.03852
G3 X135.791 Y129.387 I-1.098 J1.915 E.23821
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13246
G1 X135.458 Y128.846 E-.10989
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07815
; WIPE_END
G1 E-.04 F1800
G1 X127.732 Y127.999 Z1.6 F36000
G1 X92.452 Y130.267 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X92.452 Y125.733 E.15042
G1 X85.752 Y125.733 E.22225
G1 X85.752 Y122.708 E.10033
G1 X99.302 Y122.708 E.44948
G1 X99.302 Y120.68 E.06728
G1 X145.698 Y120.68 E1.53904
G1 X145.698 Y122.708 E.06728
G1 X160.452 Y122.708 E.48942
G1 X160.452 Y118.665 E.13412
G1 X162.248 Y118.665 E.05957
G1 X162.248 Y124.757 E.20207
G1 X170.248 Y124.757 E.26537
G1 X170.248 Y131.243 E.21518
G1 X162.248 Y131.243 E.26537
G1 X162.248 Y137.335 E.20207
G1 X160.452 Y137.335 E.05957
G1 X160.452 Y133.292 E.13412
G1 X145.698 Y133.292 E.48942
G1 X145.698 Y135.32 E.06728
G1 X99.302 Y135.32 E1.53904
G1 X99.302 Y133.292 E.06728
G1 X85.752 Y133.292 E.44948
G1 X85.752 Y130.267 E.10033
G1 X92.392 Y130.267 E.22026
G1 X92.06 Y129.875 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X92.06 Y128.125 E.05379
G1 X92.06 Y127.725 E.01229
G1 F11376.887
G1 X92.06 Y127.325 E.01229
G1 F10093.361
G1 X92.06 Y126.925 E.01229
G1 F8886.634
G1 X92.06 Y126.525 E.01229
G1 F7756.707
G1 X92.06 Y126.125 E.01229
G1 F6703.581
G1 X92.019 Y126.125 E.00126
G1 F6600
G1 X85.36 Y126.125 E.20461
G1 F6790.468
G1 X85.36 Y126.05 E.00231
G1 F7850.149
G1 X85.36 Y125.65 E.01229
G1 F8986.63
G1 X85.36 Y125.25 E.01229
G1 F10199.912
G1 X85.36 Y124.85 E.01229
G1 F11489.993
G1 X85.36 Y124.45 E.01229
G1 F12000
G1 X85.36 Y124.05 E.01229
G1 X85.36 Y122.316 E.05327
G1 X98.91 Y122.316 E.41635
G1 X98.91 Y120.288 E.06233
G1 X146.09 Y120.288 E1.44971
G1 X146.09 Y122.316 E.06233
G1 X160.06 Y122.316 E.42926
G1 X160.06 Y118.273 E.12424
G1 X162.64 Y118.273 E.07928
G1 X162.64 Y124.364 E.18718
G1 X170.64 Y124.364 E.24582
G1 X170.64 Y131.636 E.22342
G1 X162.64 Y131.636 E.24582
G1 X162.64 Y137.727 E.18718
G1 X160.06 Y137.727 E.07928
G1 X160.06 Y133.684 E.12424
G1 X146.09 Y133.684 E.42926
G1 X146.09 Y135.712 E.06233
G1 X98.91 Y135.712 E1.44971
G1 X98.91 Y133.684 E.06233
G1 X85.36 Y133.684 E.41635
G1 X85.36 Y131.95 E.05327
G1 X85.36 Y131.55 E.01229
G1 F11489.993
G1 X85.36 Y131.15 E.01229
G1 F10199.912
G1 X85.36 Y130.75 E.01229
G1 F8986.63
G1 X85.36 Y130.35 E.01229
G1 F7850.149
G1 X85.36 Y129.95 E.01229
G1 F6790.468
G1 X85.36 Y129.875 E.00231
G1 F6600
G1 X92 Y129.875 E.20403
; WIPE_START
M204 S10000
G1 X92.06 Y128.125 E-.66557
G1 X92.06 Y127.876 E-.09443
; WIPE_END
G1 E-.04 F1800
G1 X88.516 Y123.056 Z1.6 F36000
G1 Z1.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.888 Y123.056 E.05401
G1 X86.1 Y123.844 E.03695
G1 X86.1 Y124.48 E.0211
G1 X87.005 Y125.384 E.04242
G1 X92.236 Y125.384 E.17353
G1 X94.564 Y123.056 E.10922
G1 X92.353 Y123.056 E.07335
G1 X104.268 Y134.972 E.55899
G1 X105.676 Y134.972 E.0467
G1 X114.95 Y125.698 E.43504
G1 X114.95 Y130.302 E.1527
G1 X105.676 Y121.028 E.43504
G1 X104.268 Y121.028 E.0467
G1 X92.352 Y132.944 E.55899
G1 X94.564 Y132.944 E.07336
G1 X92.236 Y130.616 E.10922
G1 X87.005 Y130.616 E.17353
G1 X86.1 Y131.52 E.04242
G1 X86.1 Y132.156 E.0211
G1 X86.888 Y132.944 E.03695
G1 X88.516 Y132.944 E.05401
; WIPE_START
G1 X86.888 Y132.944 E-.61876
G1 X86.625 Y132.681 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X94.144 Y133.991 Z1.6 F36000
G1 X99.65 Y134.95 Z1.6
G1 Z1.2
G1 E.8 F1800
G1 F15476.087
G1 X99.65 Y133.322 E.05401
G1 X104.575 Y128.397 E.23104
G3 X104.575 Y127.603 I34.472 J-.397 E.02633
G1 X99.65 Y122.678 E.23104
G1 X99.65 Y121.05 E.05401
; WIPE_START
G1 X99.65 Y122.678 E-.61876
G1 X99.913 Y122.941 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X105.94 Y127.624 Z1.6 F36000
G1 X109.363 Y130.285 Z1.6
G1 Z1.2
G1 E.8 F1800
G1 F15476.087
G3 X107.887 Y130.914 I-2.253 J-3.235 E.05362
G1 X111.944 Y134.972 E.19035
G1 X113.352 Y134.972 E.0467
G1 X115.374 Y132.95 E.09484
G1 X117.598 Y132.95 E.0738
G1 X119.62 Y134.972 E.09484
G1 X121.028 Y134.972 E.0467
G1 X124.95 Y131.05 E.18398
G1 X124.95 Y124.95 E.20237
G1 X121.028 Y121.028 E.18398
G1 X119.62 Y121.028 E.0467
G1 X117.598 Y123.05 E.09484
G1 X115.374 Y123.05 E.0738
G1 X113.352 Y121.028 E.09484
G1 X111.944 Y121.028 E.0467
G1 X107.897 Y125.075 E.18986
G3 X109.369 Y125.721 I-.44 J3.006 E.05396
; WIPE_START
G1 X108.63 Y125.272 E-.32851
G1 X107.897 Y125.075 E-.28839
G1 X108.163 Y124.809 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X115.655 Y126.268 Z1.6 F36000
G1 X149.924 Y132.944 Z1.6
G1 Z1.2
G1 E.8 F1800
G1 F15476.087
G1 X148.296 Y132.944 E.05401
G1 X136.38 Y121.028 E.55899
G1 X134.972 Y121.028 E.0467
G1 X130.05 Y125.95 E.23089
G1 X130.05 Y130.05 E.13603
G1 X134.972 Y134.972 E.23089
G1 X136.38 Y134.972 E.0467
G1 X148.296 Y123.056 E.55899
G1 X149.924 Y123.056 E.05401
G1 X162.218 Y125.135 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39356
G1 F12000
G1 X169.809 Y125.135 E.21689
G1 X165.522 Y130.486 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X163.894 Y130.486 E.05401
G1 X168.866 Y125.514 E.23323
G1 X163.894 Y125.514 E.16492
G1 X168.866 Y130.486 E.23323
G1 X169.9 Y130.486 E.0343
G1 X169.9 Y129.892 E.01971
G1 X162.218 Y130.865 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39354
G1 F12000
G1 X169.809 Y130.865 E.21688
; WIPE_START
G1 X167.809 Y130.865 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.321 Y134.885 Z1.6 F36000
G1 X160.8 Y135.208 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.22 E.04181
G1 X153.76 Y123.056 E.3824
G1 X155.972 Y123.056 E.07335
G1 X146.084 Y132.944 E.46383
G1 X145.35 Y132.944 E.02437
G1 X145.35 Y133.678 E.02437
G1 X144.056 Y134.972 E.0607
G1 X142.648 Y134.972 E.0467
G1 X138.461 Y130.785 E.19642
G3 X134.715 Y128.961 I-.961 J-2.785 E.15351
G1 X128.704 Y134.972 E.28199
G1 X127.296 Y134.972 E.0467
G1 X125.274 Y132.95 E.09484
G1 X124.95 Y132.95 E.01077
G1 X124.95 Y132.626 E.01077
G1 X120.05 Y127.726 E.22984
G1 X120.05 Y128.274 E.01816
G1 X124.95 Y123.374 E.22984
G1 X124.95 Y123.05 E.01077
G1 X125.274 Y123.05 E.01077
G1 X127.296 Y121.028 E.09484
G1 X128.704 Y121.028 E.0467
G1 X134.715 Y127.039 E.28199
G3 X138.461 Y125.215 I2.785 J.961 E.15351
G1 X142.648 Y121.028 E.19642
G1 X144.056 Y121.028 E.0467
G1 X145.35 Y122.322 E.0607
G1 X145.35 Y123.056 E.02437
G1 X146.084 Y123.056 E.02437
G1 X155.972 Y132.944 E.46383
G1 X153.76 Y132.944 E.07336
G1 X161.9 Y124.78 E.3824
G1 X161.9 Y123.52 E.04181
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
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
G1 X129.702 Y123.398
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X129.702 Y132.602 E.30532
G1 X125.298 Y132.602 E.14609
G1 X125.298 Y123.398 E.30532
G1 X129.642 Y123.398 E.1441
G1 X129.31 Y123.79 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X129.31 Y132.21 E.25872
G1 X125.69 Y132.21 E.11123
G1 X125.69 Y123.79 E.25872
G1 X129.25 Y123.79 E.10939
; WIPE_START
M204 S10000
G1 X129.264 Y125.79 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.048 Y130.218 Z1.8 F36000
G1 X119.702 Y132.602 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X115.298 Y132.602 E.14609
G1 X115.298 Y123.398 E.30532
G1 X119.702 Y123.398 E.14609
G1 X119.702 Y132.542 E.30333
G1 X119.31 Y132.21 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X115.69 Y132.21 E.11123
G1 X115.69 Y123.79 E.25872
G1 X119.31 Y123.79 E.11123
G1 X119.31 Y132.15 E.25688
; WIPE_START
M204 S10000
G1 X117.31 Y132.183 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X110.624 Y128.503 Z1.8 F36000
G1 X105.935 Y125.922 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
M73 P60 R7
G1 F15476.087
G1 X106.201 Y125.75 E.01051
G3 X107.361 Y125.406 I1.299 J2.25 E.0405
G3 X106.963 Y130.542 I.139 J2.594 E.29329
G3 X105.89 Y125.961 I.537 J-2.542 E.19518
G1 X106.16 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.386 Y125.797 I1.348 J1.747 E.04083
G3 X108.605 Y126.086 I.109 J2.259 E.039
G3 X106.113 Y126.291 I-1.097 J1.915 E.34441
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13245
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.211 Y125.808 E-.10986
G1 X107.386 Y125.797 E-.06665
G1 X107.789 Y125.808 E-.15286
G1 X107.991 Y125.849 E-.07844
; WIPE_END
G1 E-.04 F1800
G1 X115.554 Y126.874 Z1.8 F36000
G1 X135.422 Y129.565 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.25 Y129.299 E.01051
G3 X137.361 Y125.406 I2.25 J-1.299 E.17587
G3 X136.963 Y130.542 I.139 J2.594 E.29329
G3 X135.461 Y129.61 I.537 J-2.542 E.05982
G1 X135.753 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.386 Y125.797 I1.755 J-1.339 E.14702
G3 X138.605 Y126.086 I.109 J2.259 E.039
G3 X135.79 Y129.387 I-1.097 J1.915 E.23827
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13247
G1 X135.458 Y128.846 E-.10989
G1 X135.365 Y128.572 E-.10986
G1 X135.331 Y128.4 E-.06664
G1 X135.29 Y128 E-.15285
G1 X135.308 Y127.711 E-.10989
G1 X135.349 Y127.509 E-.0784
; WIPE_END
G1 E-.04 F1800
G1 X127.73 Y127.972 Z1.8 F36000
G1 X92.452 Y130.116 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X92.452 Y125.884 E.14041
G1 X85.752 Y125.884 E.22225
G1 X85.752 Y122.747 E.10405
G1 X99.302 Y122.747 E.44948
G1 X99.302 Y120.713 E.06748
G1 X145.698 Y120.713 E1.53904
G1 X145.698 Y122.747 E.06748
G1 X160.452 Y122.747 E.48942
G1 X160.452 Y118.69 E.13458
G1 X162.248 Y118.69 E.05957
G1 X162.248 Y124.824 E.20347
G1 X170.248 Y124.824 E.26537
G1 X170.248 Y131.176 E.21074
G1 X162.248 Y131.176 E.26537
G1 X162.248 Y137.31 E.20347
G1 X160.452 Y137.31 E.05957
G1 X160.452 Y133.253 E.13458
G1 X145.698 Y133.253 E.48942
G1 X145.698 Y135.287 E.06748
G1 X99.302 Y135.287 E1.53904
G1 X99.302 Y133.253 E.06748
G1 X85.752 Y133.253 E.44948
G1 X85.752 Y130.116 E.10405
G1 X92.392 Y130.116 E.22026
G1 X92.06 Y129.724 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F11605.419
M204 S6000
G1 X92.06 Y129.476 E.00764
G1 F10789.981
G1 X92.06 Y129.076 E.01229
G1 F9541.003
G1 X92.06 Y128.676 E.01229
G1 F8368.826
G1 X92.06 Y128.276 E.01229
G1 F7273.448
G1 X92.06 Y127.876 E.01229
G1 F6254.87
G1 X92.06 Y127.476 E.01229
G1 F5313.093
G1 X92.06 Y127.076 E.01229
G1 F4448.115
G1 X92.06 Y126.676 E.01229
G1 F3659.938
G1 X92.06 Y126.276 E.01229
G1 F2948.56
G1 X92.019 Y126.276 E.00126
G1 F2880
G1 X85.36 Y126.276 E.20461
G1 F3065.568
G1 X85.36 Y126.166 E.00338
G1 F3790.169
G1 X85.36 Y125.766 E.01229
G1 F4591.57
G1 X85.36 Y125.366 E.01229
G1 F5469.77
G1 X85.36 Y124.966 E.01229
G1 F6424.771
G1 X85.36 Y124.566 E.01229
G1 F7456.572
G1 X85.36 Y124.166 E.01229
G1 F8565.172
G1 X85.36 Y123.766 E.01229
G1 F9750.573
G1 X85.36 Y123.366 E.01229
G1 F11012.773
G1 X85.36 Y122.966 E.01229
G1 F12000
G1 X85.36 Y122.566 E.01229
G1 X85.36 Y122.355 E.00648
G1 X98.91 Y122.355 E.41635
G1 X98.91 Y120.321 E.0625
G1 X146.09 Y120.321 E1.44971
G1 X146.09 Y122.355 E.0625
G1 X160.06 Y122.355 E.42926
G1 X160.06 Y118.298 E.12466
G1 X162.64 Y118.298 E.07928
G1 X162.64 Y124.432 E.18848
G1 X170.64 Y124.432 E.24582
G1 X170.64 Y131.569 E.2193
G1 X162.64 Y131.569 E.24582
G1 X162.64 Y137.702 E.18848
G1 X160.06 Y137.702 E.07928
G1 X160.06 Y133.645 E.12466
G1 X146.09 Y133.645 E.42926
G1 X146.09 Y135.679 E.0625
G1 X98.91 Y135.679 E1.44971
G1 X98.91 Y133.645 E.0625
G1 X85.36 Y133.645 E.41635
G1 X85.36 Y133.434 E.00648
G1 X85.36 Y133.034 E.01229
G1 F11012.773
G1 X85.36 Y132.634 E.01229
G1 F9750.573
G1 X85.36 Y132.234 E.01229
G1 F8565.172
G1 X85.36 Y131.834 E.01229
G1 F7456.572
G1 X85.36 Y131.434 E.01229
G1 F6424.771
G1 X85.36 Y131.034 E.01229
G1 F5469.77
G1 X85.36 Y130.634 E.01229
G1 F4591.57
G1 X85.36 Y130.234 E.01229
G1 F3790.169
G1 X85.36 Y129.834 E.01229
G1 F3065.568
G1 X85.36 Y129.724 E.00338
G1 F2880
G1 X92 Y129.724 E.20403
; WIPE_START
M204 S10000
G1 X92.06 Y129.476 E-.09724
G1 X92.06 Y129.076 E-.152
G1 X92.06 Y128.676 E-.152
G1 X92.06 Y128.276 E-.152
G1 X92.06 Y127.876 E-.152
G1 X92.06 Y127.732 E-.05476
; WIPE_END
G1 E-.04 F1800
G1 X88.477 Y132.905 Z1.8 F36000
G1 Z1.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.849 Y132.905 E.05401
G1 X86.1 Y132.156 E.03513
G1 X86.1 Y131.52 E.0211
G1 X87.155 Y130.465 E.0495
G1 X92.085 Y130.465 E.16352
G1 X94.525 Y132.905 E.11447
G1 X92.391 Y132.905 E.07078
G1 X104.235 Y121.061 E.55562
G1 X105.709 Y121.061 E.04889
G1 X114.95 Y130.302 E.43349
G1 X114.95 Y125.698 E.1527
G1 X105.709 Y134.939 E.4335
G1 X104.235 Y134.939 E.04889
G1 X92.391 Y123.095 E.55562
G1 X94.525 Y123.095 E.07078
M73 P60 R6
G1 X92.085 Y125.535 E.11447
G1 X87.156 Y125.535 E.16352
G1 X86.1 Y124.48 E.0495
G1 X86.1 Y123.844 E.0211
G1 X86.849 Y123.095 E.03513
G1 X88.477 Y123.095 E.05401
; WIPE_START
G1 X86.849 Y123.095 E-.61876
G1 X86.586 Y123.358 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X94.104 Y122.037 Z1.8 F36000
G1 X99.661 Y121.061 Z1.8
G1 Z1.4
G1 E.8 F1800
G1 F15476.087
G1 X99.65 Y122.678 E.05365
G1 X104.575 Y127.603 E.23104
G2 X104.575 Y128.397 I34.475 J.397 E.02633
G1 X99.65 Y133.322 E.23104
G1 X99.661 Y134.939 E.05365
; WIPE_START
G1 X99.65 Y133.322 E-.61455
G1 X99.921 Y133.051 E-.14545
; WIPE_END
G1 E-.04 F1800
G1 X105.951 Y128.372 Z1.8 F36000
G1 X109.369 Y125.721 Z1.8
G1 Z1.4
G1 E.8 F1800
G1 F15476.087
G2 X107.897 Y125.075 I-1.912 J2.36 E.05396
G1 X111.911 Y121.061 E.18831
G1 X113.385 Y121.061 E.04889
G1 X115.374 Y123.05 E.09329
G1 X117.598 Y123.05 E.0738
G1 X119.587 Y121.061 E.09329
G1 X121.061 Y121.061 E.04889
G1 X124.95 Y124.95 E.18243
G1 X124.95 Y131.05 E.20237
G1 X121.061 Y134.939 E.18243
G1 X119.587 Y134.939 E.04889
G1 X117.598 Y132.95 E.09329
G1 X115.374 Y132.95 E.0738
G1 X113.385 Y134.939 E.09329
G1 X111.911 Y134.939 E.04889
G1 X107.897 Y130.925 E.18831
G2 X109.369 Y130.279 I-.44 J-3.006 E.05396
; WIPE_START
G1 X108.63 Y130.728 E-.32851
G1 X107.897 Y130.925 E-.28838
G1 X108.163 Y131.191 E-.14311
; WIPE_END
G1 E-.04 F1800
G1 X115.656 Y129.737 Z1.8 F36000
G1 X149.885 Y123.095 Z1.8
G1 Z1.4
G1 E.8 F1800
G1 F15476.087
G1 X148.257 Y123.095 E.05401
G1 X136.413 Y134.939 E.55562
G1 X134.939 Y134.939 E.04889
G1 X130.05 Y130.05 E.22934
G1 X130.05 Y125.95 E.13603
G1 X134.939 Y121.061 E.22934
G1 X136.413 Y121.061 E.04889
G1 X148.257 Y132.905 E.55562
G1 X149.885 Y132.905 E.05401
G1 X162.228 Y130.775 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.43791
G1 F12000
G1 X169.787 Y130.775 E.24331
G1 X169.9 Y129.892 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X169.9 Y130.374 E.01602
G1 X168.754 Y130.374 E.038
G1 X164.005 Y125.626 E.22278
G1 X168.754 Y125.626 E.15753
G1 X164.005 Y130.374 E.22278
G1 X165.634 Y130.374 E.05401
G1 X162.228 Y125.225 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.43793
G1 F12000
G1 X169.787 Y125.225 E.24332
; WIPE_START
G1 X167.787 Y125.225 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.342 Y121.136 Z1.8 F36000
G1 X160.8 Y120.792 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X153.799 Y132.905 E.38002
G1 X155.933 Y132.905 E.07078
G1 X146.123 Y123.095 E.46019
G1 X145.35 Y123.095 E.02565
G1 X145.35 Y122.322 E.02565
G1 X144.089 Y121.061 E.05915
G1 X142.615 Y121.061 E.04889
G1 X138.461 Y125.215 E.19487
G2 X134.715 Y127.039 I-.932 J2.845 E.15286
G1 X128.737 Y121.061 E.28044
G1 X127.263 Y121.061 E.04889
G1 X125.274 Y123.05 E.09329
G1 X124.95 Y123.05 E.01077
G1 X124.95 Y123.374 E.01077
G1 X120.05 Y128.274 E.22984
G1 X120.05 Y127.726 E.01816
G1 X124.95 Y132.626 E.22984
G1 X124.95 Y132.95 E.01077
G1 X125.274 Y132.95 E.01077
G1 X127.263 Y134.939 E.09329
G1 X128.737 Y134.939 E.04889
G1 X134.715 Y128.961 E.28044
G2 X138.461 Y130.785 I2.814 J-1.021 E.15286
G1 X142.615 Y134.939 E.19487
G1 X144.089 Y134.939 E.04889
G1 X145.35 Y133.678 E.05915
G1 X145.35 Y132.905 E.02565
G1 X146.123 Y132.905 E.02565
G1 X155.933 Y123.095 E.46019
G1 X153.799 Y123.095 E.07078
G1 X161.9 Y131.196 E.38002
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.208 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X160.8 Y133.579 E-.61876
G1 X161.063 Y133.317 E-.14124
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
G1 X129.702 Y123.398
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X129.702 Y132.602 E.30532
G1 X125.298 Y132.602 E.14609
G1 X125.298 Y123.398 E.30532
G1 X129.642 Y123.398 E.1441
G1 X129.31 Y123.79 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X129.31 Y132.21 E.25872
G1 X125.69 Y132.21 E.11123
G1 X125.69 Y123.79 E.25872
G1 X129.25 Y123.79 E.10939
; WIPE_START
M204 S10000
G1 X129.264 Y125.79 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.048 Y130.218 Z2 F36000
G1 X119.702 Y132.602 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X115.298 Y132.602 E.14609
G1 X115.298 Y123.398 E.30532
G1 X119.702 Y123.398 E.14609
G1 X119.702 Y132.542 E.30333
G1 X119.31 Y132.21 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X115.69 Y132.21 E.11123
G1 X115.69 Y123.79 E.25872
G1 X119.31 Y123.79 E.11123
G1 X119.31 Y132.15 E.25688
; WIPE_START
M204 S10000
G1 X117.31 Y132.183 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X110.612 Y128.525 Z2 F36000
G1 X105.898 Y125.95 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.919 Y125.939 E.00079
M73 P61 R6
G3 X107.345 Y125.407 I1.581 J2.061 E.05127
G3 X104.955 Y127.478 I.155 J2.593 E.42865
G3 X105.663 Y126.163 I2.545 J.522 E.05025
G1 X105.853 Y125.99 E.00852
G1 X106.16 Y126.254 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.371 Y125.798 I1.348 J1.747 E.04035
G3 X108.605 Y126.086 I.125 J2.254 E.03947
G3 X106.113 Y126.291 I-1.097 J1.915 E.34436
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13245
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.211 Y125.808 E-.10986
G1 X107.371 Y125.798 E-.06079
G1 X107.789 Y125.808 E-.15868
G1 X107.991 Y125.849 E-.07846
; WIPE_END
G1 E-.04 F1800
G1 X115.553 Y126.883 Z2 F36000
G1 X135.45 Y129.602 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.439 Y129.581 E.00079
G3 X137.345 Y125.407 I2.061 J-1.581 E.18663
G3 X136.978 Y130.545 I.155 J2.593 E.29328
G3 X135.663 Y129.837 I.522 J-2.545 E.05025
G1 X135.49 Y129.647 E.00852
G1 X135.754 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.371 Y125.798 I1.754 J-1.339 E.14653
G3 X138.605 Y126.086 I.125 J2.254 E.03947
G3 X135.791 Y129.387 I-1.097 J1.915 E.23825
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13246
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07815
; WIPE_END
G1 E-.04 F1800
G1 X127.728 Y127.938 Z2 F36000
G1 X92.452 Y129.918 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X92.452 Y126.082 E.12728
G1 X85.752 Y126.082 E.22225
G1 X85.752 Y122.796 E.10897
G1 X99.302 Y122.796 E.44948
G1 X99.302 Y120.746 E.06802
G1 X145.698 Y120.746 E1.53904
G1 X145.698 Y122.796 E.06802
G1 X160.452 Y122.796 E.48942
G1 X160.452 Y118.72 E.13523
G1 X162.248 Y118.72 E.05957
G1 X162.248 Y124.896 E.2049
G1 X170.248 Y124.896 E.26537
G1 X170.248 Y131.104 E.2059
G1 X162.248 Y131.104 E.26537
G1 X162.248 Y137.28 E.2049
G1 X160.452 Y137.28 E.05957
G1 X160.452 Y133.204 E.13523
G1 X145.698 Y133.204 E.48942
G1 X145.698 Y135.254 E.06802
G1 X99.302 Y135.254 E1.53904
G1 X99.302 Y133.204 E.06802
G1 X85.752 Y133.204 E.44948
G1 X85.752 Y129.918 E.10897
G1 X92.392 Y129.918 E.22026
G1 X92.06 Y129.526 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F8912.197
M204 S6000
G1 X92.06 Y129.274 E.00777
G1 F8188.119
G1 X92.06 Y128.874 E.01229
G1 F7105.049
G1 X92.06 Y128.474 E.01229
G1 F6098.779
G1 X92.06 Y128.074 E.01229
G1 F5169.309
G1 X92.06 Y127.674 E.01229
G1 F4316.639
G1 X92.06 Y127.274 E.01229
G1 F3540.769
G1 X92.06 Y126.874 E.01229
G1 F2841.699
G1 X92.06 Y126.474 E.01229
G1 F2219.429
G1 X92.019 Y126.474 E.00126
G1 F2160
G1 X85.36 Y126.474 E.20461
G1 F2391.981
G1 X85.36 Y126.317 E.00482
G1 F3036.523
G1 X85.36 Y125.917 E.01229
G1 F3757.865
G1 X85.36 Y125.517 E.01229
G1 F4556.007
G1 X85.36 Y125.117 E.01229
G1 F5430.949
G1 X85.36 Y124.717 E.01229
G1 F6382.691
G1 X85.36 Y124.317 E.01229
G1 F7411.233
G1 X85.36 Y123.917 E.01229
G1 F8516.575
G1 X85.36 Y123.517 E.01229
G1 F9698.717
G1 X85.36 Y123.117 E.01229
G1 F10957.659
G1 X85.36 Y122.717 E.01229
G1 F11993.933
G1 X85.36 Y122.404 E.0096
G1 F12000
G1 X85.76 Y122.404 E.01229
G1 X98.91 Y122.404 E.40406
G1 X98.91 Y120.354 E.06301
G1 X146.09 Y120.354 E1.44971
G1 X146.09 Y122.404 E.06301
G1 X160.06 Y122.404 E.42926
G1 X160.06 Y118.328 E.12527
G1 X162.64 Y118.328 E.07928
G1 X162.64 Y124.504 E.1898
G1 X170.64 Y124.504 E.24582
G1 X170.64 Y131.496 E.21482
G1 X162.64 Y131.496 E.24582
G1 X162.64 Y137.672 E.1898
G1 X160.06 Y137.672 E.07928
G1 X160.06 Y133.596 E.12527
G1 X146.09 Y133.596 E.42926
G1 X146.09 Y135.646 E.06301
G1 X98.91 Y135.646 E1.44971
G1 X98.91 Y133.596 E.06301
G1 X85.76 Y133.596 E.40406
G1 X85.36 Y133.596 E.01229
G1 F11993.865
G1 X85.36 Y133.283 E.0096
G1 F10957.594
G1 X85.36 Y132.883 E.01229
G1 F9698.656
G1 X85.36 Y132.483 E.01229
G1 F8516.518
G1 X85.36 Y132.083 E.01229
G1 F7411.18
G1 X85.36 Y131.683 E.01229
G1 F6382.641
G1 X85.36 Y131.283 E.01229
G1 F5430.903
G1 X85.36 Y130.883 E.01229
G1 F4555.965
G1 X85.36 Y130.483 E.01229
G1 F3757.827
G1 X85.36 Y130.083 E.01229
G1 F3036.489
G1 X85.36 Y129.683 E.01229
G1 F2391.95
G1 X85.36 Y129.526 E.00482
G1 F2160
G1 X92 Y129.526 E.20403
; WIPE_START
M204 S10000
G1 X92.06 Y129.274 E-.09873
G1 X92.06 Y128.874 E-.152
G1 X92.06 Y128.474 E-.152
G1 X92.06 Y128.074 E-.152
G1 X92.06 Y127.674 E-.152
G1 X92.06 Y127.533 E-.05327
; WIPE_END
G1 E-.04 F1800
G1 X92.478 Y125.693 Z2 F36000
G1 Z1.6
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41234
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.2 Y125.693 E.18897
; Slow Down End
G1 X88.082 Y123.49 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.454 Y123.49 E.05401
G1 X86.1 Y123.844 E.01659
G1 X86.1 Y124.48 E.0211
G1 X86.925 Y125.305 E.0387
G1 X92.315 Y125.305 E.17879
G1 X94.13 Y123.49 E.08514
G1 X92.786 Y123.49 E.04457
G1 X104.202 Y134.906 E.53554
G1 X105.742 Y134.906 E.05108
G1 X114.95 Y125.698 E.43195
G1 X114.95 Y130.302 E.1527
G1 X105.742 Y121.094 E.43195
G1 X104.202 Y121.094 E.05108
G1 X92.786 Y132.51 E.53554
G1 X94.13 Y132.51 E.04457
G1 X92.315 Y130.695 E.08514
G1 X86.925 Y130.695 E.17879
G1 X86.1 Y131.52 E.0387
G1 X86.1 Y132.156 E.0211
G1 X86.454 Y132.51 E.0166
G1 X88.082 Y132.51 E.05401
G1 X86.14 Y130.307 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41234
G1 F3000;_EXTRUDE_SET_SPEED
G1 X92.418 Y130.307 E.18897
; Slow Down End
G1 X98.805 Y132.51 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.489 Y132.51 E.02268
G3 X99.65 Y133.18 I-.227 J.409 E.0257
G1 X99.65 Y133.322 E.00471
G1 X104.575 Y128.397 E.23104
G3 X104.575 Y127.603 I34.395 J-.397 E.02633
G1 X99.65 Y122.678 E.23104
G3 X99.73 Y123.249 I-2.464 J.633 E.01916
G1 X99.489 Y123.49 E.01131
G1 X98.805 Y123.49 E.02268
G1 X99.345 Y123.143 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.159 Y123.143 E.36532
; Slow Down End
; WIPE_START
G1 X88.159 Y123.143 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X93.922 Y128.148 Z2 F36000
G1 X99.345 Y132.857 Z2
G1 Z1.6
G1 E.8 F1800
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.159 Y132.857 E.36532
; Slow Down End
; WIPE_START
G1 X88.159 Y132.857 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X95.736 Y131.936 Z2 F36000
G1 X109.369 Y130.279 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X107.897 Y130.925 I-2.178 J-2.966 E.05375
G1 X111.878 Y134.906 E.18677
G1 X113.418 Y134.906 E.05108
G1 X115.374 Y132.95 E.09174
G1 X117.598 Y132.95 E.0738
G1 X119.554 Y134.906 E.09174
G1 X121.094 Y134.906 E.05108
G1 X124.95 Y131.05 E.18088
G1 X124.95 Y124.95 E.20237
G1 X121.094 Y121.094 E.18088
G1 X119.554 Y121.094 E.05108
G1 X117.598 Y123.05 E.09174
G1 X115.374 Y123.05 E.0738
G1 X113.418 Y121.094 E.09174
G1 X111.878 Y121.094 E.05108
G1 X107.897 Y125.075 E.18677
G3 X109.369 Y125.721 I-.44 J3.006 E.05396
; WIPE_START
G1 X108.63 Y125.272 E-.32853
G1 X107.897 Y125.075 E-.28837
G1 X108.163 Y124.809 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X115.523 Y126.829 Z2 F36000
G1 X144.949 Y134.906 Z2
G1 Z1.6
G1 E.8 F1800
G1 F15476.087
G1 X145.35 Y134.906 E.01329
G1 X145.35 Y133.678 E.04073
G1 X144.122 Y134.906 E.0576
G1 X142.582 Y134.906 E.05108
G1 X138.461 Y130.785 E.19333
G3 X134.715 Y128.961 I-.961 J-2.785 E.15351
G1 X128.77 Y134.906 E.2789
G1 X127.23 Y134.906 E.05108
G1 X125.274 Y132.95 E.09174
G1 X124.95 Y132.95 E.01077
G1 X124.95 Y132.626 E.01077
G1 X120.05 Y127.726 E.22984
G1 X120.05 Y128.274 E.01816
G1 X124.95 Y123.374 E.22984
G1 X124.95 Y123.05 E.01077
G1 X125.274 Y123.05 E.01077
G1 X127.23 Y121.094 E.09174
G1 X128.77 Y121.094 E.05108
G1 X134.715 Y127.039 E.27889
G3 X138.461 Y125.215 I2.814 J1.021 E.15286
G1 X142.582 Y121.094 E.19333
G1 X144.122 Y121.094 E.05108
G1 X145.35 Y122.322 E.0576
G1 X145.35 Y121.094 E.04073
G1 X144.949 Y121.094 E.01329
; WIPE_START
G1 X145.35 Y121.094 E-.15219
G1 X145.35 Y122.322 E-.46657
G1 X145.087 Y122.059 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X152.7 Y122.595 Z2 F36000
G1 X160.495 Y123.143 Z2
G1 Z1.6
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.715 Y123.143 E.40949
; Slow Down End
G1 X162.253 Y125.329 F36000
; LINE_WIDTH: 0.5013
G1 F12000
G1 X169.755 Y125.329 E.28022
G1 X165.77 Y130.238 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.142 Y130.238 E.05401
G1 X168.618 Y125.762 E.21
G1 X164.142 Y125.762 E.14849
G1 X168.618 Y130.238 E.21
G1 X169.9 Y130.238 E.04252
G1 X169.9 Y129.892 E.0115
G1 X162.253 Y130.671 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.50129
G1 F12000
G1 X169.755 Y130.671 E.28022
; WIPE_START
G1 X167.755 Y130.671 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.495 Y132.857 Z2 F36000
G1 Z1.6
G1 E.8 F1800
; Slow Down Start
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.715 Y132.857 E.40949
; Slow Down End
; WIPE_START
G1 X147.715 Y132.857 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.227 Y134.206 Z2 F36000
G1 X160.8 Y135.208 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X154.194 Y123.49 E.36149
G1 X155.538 Y123.49 E.04457
G1 X146.518 Y132.51 E.42313
G1 X147.862 Y132.51 E.04457
G1 X136.446 Y121.094 E.53554
G1 X134.906 Y121.094 E.05108
G1 X130.05 Y125.95 E.22779
G1 X130.05 Y130.05 E.13603
M73 P62 R6
G1 X134.906 Y134.906 E.22779
G1 X136.446 Y134.906 E.05108
G1 X147.862 Y123.49 E.53554
G1 X146.518 Y123.49 E.04457
G1 X155.538 Y132.51 E.42313
G1 X154.194 Y132.51 E.04457
G1 X161.9 Y124.804 E.36149
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
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
G1 X135.45 Y129.602
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X135.441 Y129.58 E.0008
G3 X137.33 Y125.408 I2.067 J-1.578 E.18585
G3 X139.085 Y125.935 I.185 J2.57 E.06213
G3 X135.664 Y129.836 I-1.577 J2.067 E.28275
G1 X135.491 Y129.647 E.00852
G1 X135.753 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.356 Y125.799 I1.755 J-1.339 E.14608
G3 X138.605 Y126.086 I.141 J2.252 E.03994
G3 X135.79 Y129.388 I-1.097 J1.916 E.2383
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13247
G1 X135.458 Y128.846 E-.10989
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10991
G1 X135.308 Y127.712 E-.10983
G1 X135.349 Y127.51 E-.07817
; WIPE_END
G1 E-.04 F1800
G17
G3 Z2.2 I.066 J-1.215 P1  F36000
G1 X105.935 Y125.922 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.201 Y125.75 E.01051
G3 X107.33 Y125.408 I1.299 J2.25 E.03948
G3 X108.007 Y130.548 I.17 J2.592 E.25944
G3 X106.993 Y130.548 I-.507 J-2.113 E.03393
G3 X105.89 Y125.961 I.507 J-2.548 E.1962
G1 X106.16 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.356 Y125.799 I1.348 J1.748 E.03988
G3 X108.605 Y126.086 I.141 J2.252 E.03994
G3 X106.113 Y126.291 I-1.097 J1.916 E.3445
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13245
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.212 Y125.808 E-.10989
G1 X107.356 Y125.799 E-.05492
G1 X107.5 Y125.79 E-.05494
G1 X107.789 Y125.808 E-.10988
G1 X107.99 Y125.849 E-.07817
; WIPE_END
G1 E-.04 F1800
G1 X100.576 Y127.662 Z2.2 F36000
G1 X92.452 Y129.65 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X92.452 Y126.35 E.10947
G1 X85.752 Y126.35 E.22225
G1 X85.752 Y122.851 E.11605
G1 X99.302 Y122.851 E.44948
G1 X99.302 Y120.788 E.06844
G1 X145.698 Y120.788 E1.53904
G1 X145.698 Y122.851 E.06844
G1 X160.452 Y122.851 E.48942
G1 X160.452 Y118.749 E.13607
G1 X162.248 Y118.749 E.05957
G1 X162.248 Y124.985 E.20684
G1 X170.248 Y124.985 E.26537
G1 X170.248 Y131.015 E.20004
G1 X162.248 Y131.015 E.26537
G1 X162.248 Y137.251 E.20684
G1 X160.452 Y137.251 E.05957
G1 X160.452 Y133.149 E.13607
G1 X145.698 Y133.149 E.48942
G1 X145.698 Y135.212 E.06844
G1 X99.302 Y135.212 E1.53904
G1 X99.302 Y133.149 E.06844
G1 X85.752 Y133.149 E.44948
G1 X85.752 Y129.65 E.11605
G1 X92.392 Y129.65 E.22026
G1 X92.06 Y129.258 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F5767.429
M204 S6000
G1 X92.06 Y128.742 E.01585
G1 F4617.296
G1 X92.06 Y128.342 E.01229
G1 F3813.546
G1 X92.06 Y127.942 E.01229
G1 F3086.596
G1 X92.06 Y127.542 E.01229
G1 F2436.446
G1 X92.06 Y127.142 E.01229
G1 F1863.096
G1 X92.06 Y126.742 E.01229
G1 F1366.546
G1 X92.019 Y126.742 E.00126
G1 F1320
G1 X85.36 Y126.742 E.20461
G1 F1588.419
G1 X85.36 Y126.515 E.00699
G1 F2120.764
G1 X85.36 Y126.115 E.01229
G1 F2729.909
G1 X85.36 Y125.715 E.01229
G1 F3415.853
G1 X85.36 Y125.315 E.01229
G1 F4178.598
G1 X85.36 Y124.915 E.01229
G1 F5018.142
G1 X85.36 Y124.515 E.01229
G1 F5934.487
G1 X85.36 Y124.115 E.01229
G1 F6927.631
G1 X85.36 Y123.715 E.01229
G1 F7997.576
G1 X85.36 Y123.315 E.01229
G1 F9144.32
G1 X85.36 Y122.915 E.01229
G1 F10543.126
G1 X85.36 Y122.459 E.01399
G1 F11854.092
G1 X85.76 Y122.459 E.01229
G1 F12000
G1 X86.16 Y122.459 E.01229
G1 X98.91 Y122.459 E.39177
G1 X98.91 Y120.396 E.06339
G1 X146.09 Y120.396 E1.44971
G1 X146.09 Y122.459 E.06339
G1 X160.06 Y122.459 E.42926
G1 X160.06 Y118.357 E.12604
G1 X162.64 Y118.357 E.07928
G1 X162.64 Y124.593 E.19159
G1 X170.64 Y124.593 E.24582
G1 X170.64 Y131.407 E.20939
G1 X162.64 Y131.407 E.24582
G1 X162.64 Y137.643 E.19159
G1 X160.06 Y137.643 E.07928
G1 X160.06 Y133.541 E.12604
G1 X146.09 Y133.541 E.42926
G1 X146.09 Y135.604 E.06339
G1 X98.91 Y135.604 E1.44971
G1 X98.91 Y133.541 E.06339
G1 X86.16 Y133.541 E.39177
G1 X85.76 Y133.541 E.01229
G1 F11854.059
G1 X85.36 Y133.541 E.01229
G1 F10543.095
G1 X85.36 Y133.085 E.01399
G1 F9144.35
G1 X85.36 Y132.685 E.01229
G1 F7997.604
G1 X85.36 Y132.285 E.01229
G1 F6927.657
G1 X85.36 Y131.885 E.01229
G1 F5934.511
G1 X85.36 Y131.485 E.01229
G1 F5018.164
G1 X85.36 Y131.085 E.01229
G1 F4178.618
G1 X85.36 Y130.685 E.01229
G1 F3415.871
G1 X85.36 Y130.285 E.01229
G1 F2729.925
G1 X85.36 Y129.885 E.01229
G1 F2120.778
G1 X85.36 Y129.485 E.01229
G1 F1588.432
G1 X85.36 Y129.258 E.00699
G1 F1320
G1 X92 Y129.258 E.20403
; WIPE_START
M204 S10000
G1 X92.06 Y128.742 E-.19738
G1 X92.06 Y128.342 E-.152
G1 X92.06 Y127.942 E-.152
G1 X92.06 Y127.542 E-.152
G1 X92.06 Y127.261 E-.10662
; WIPE_END
G1 E-.04 F1800
G1 X87.993 Y132.42 Z2.2 F36000
G1 Z1.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.364 Y132.42 E.05401
G1 X86.1 Y132.156 E.01239
G1 X86.1 Y131.52 E.0211
G1 X87.076 Y130.544 E.04578
G1 X92.164 Y130.544 E.16878
G1 X94.04 Y132.42 E.08801
G1 X92.876 Y132.42 E.03862
G1 X104.16 Y121.137 E.52934
G1 X105.785 Y121.137 E.0539
G1 X114.87 Y130.222 E.42623
G1 X114.87 Y125.778 E.14744
G1 X105.785 Y134.864 E.42623
G1 X104.16 Y134.864 E.0539
G1 X92.876 Y123.58 E.52934
G1 X94.04 Y123.58 E.03862
G1 X92.164 Y125.456 E.08801
G1 X87.076 Y125.456 E.16878
G1 X86.1 Y124.48 E.04578
G1 X86.1 Y123.844 E.0211
G1 X86.364 Y123.58 E.01239
G1 X87.993 Y123.58 E.05401
G1 X86.116 Y123.216 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X99.278 Y123.216 E.36465
G1 X98.895 Y123.58 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.489 Y123.58 E.0197
G1 X99.73 Y123.339 E.01131
G1 X99.73 Y122.954 E.01275
G3 X99.65 Y122.678 I.098 J-.178 E.01059
G1 X104.575 Y127.603 E.23104
G2 X104.575 Y128.397 I34.322 J.396 E.02633
G1 X99.65 Y133.322 E.23104
G2 X99.73 Y132.661 I-4.484 J-.873 E.02209
G1 X99.489 Y132.42 E.01131
G1 X98.895 Y132.42 E.0197
; WIPE_START
G1 X99.489 Y132.42 E-.22572
G1 X99.73 Y132.661 E-.12954
G1 X99.73 Y133.046 E-.1461
G1 X99.65 Y133.125 E-.04261
G1 X99.65 Y133.322 E-.0748
G1 X99.913 Y133.059 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X105.943 Y128.38 Z2.2 F36000
G1 X109.369 Y125.721 Z2.2
G1 Z1.8
G1 E.8 F1800
G1 F15476.087
G2 X107.897 Y125.075 I-1.912 J2.36 E.05396
G1 X111.836 Y121.137 E.18477
G1 X113.461 Y121.137 E.0539
G1 X115.294 Y122.97 E.08603
G1 X117.678 Y122.97 E.07906
G1 X119.512 Y121.137 E.08603
G1 X121.137 Y121.137 E.0539
G1 X124.87 Y124.87 E.17516
G1 X124.87 Y131.13 E.20763
G1 X121.136 Y134.864 E.17516
G1 X119.512 Y134.864 E.0539
G1 X117.678 Y133.03 E.08603
G1 X115.294 Y133.03 E.07906
G1 X113.461 Y134.864 E.08603
G1 X111.836 Y134.864 E.0539
G1 X107.897 Y130.925 E.18477
G1 X108.075 Y130.889 E.00601
G2 X109.369 Y130.279 I-.584 J-2.918 E.04793
G1 X115.093 Y132.633 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.429
G1 F3000
G1 X119.738 Y132.626 E.14613
G1 X119.738 Y132.247 E.01193
G1 X115.262 Y132.247 E.14079
G1 X115.262 Y131.861 E.01215
G1 X119.738 Y131.861 E.14079
G1 X119.738 Y131.475 E.01215
G1 X115.262 Y131.475 E.14079
G1 X115.262 Y131.089 E.01215
G1 X119.738 Y131.089 E.14079
G1 X119.738 Y130.703 E.01215
G1 X115.262 Y130.703 E.14079
G1 X115.262 Y130.317 E.01215
G1 X119.738 Y130.317 E.14079
G1 X119.738 Y129.93 E.01215
G1 X115.262 Y129.93 E.14079
G1 X115.262 Y129.544 E.01215
G1 X119.738 Y129.544 E.14079
G1 X119.738 Y129.158 E.01215
G1 X115.262 Y129.158 E.14079
G1 X115.262 Y128.772 E.01215
G1 X119.738 Y128.772 E.14079
G1 X119.738 Y128.386 E.01215
G1 X115.262 Y128.386 E.14079
G1 X115.262 Y128 E.01215
G1 X119.738 Y128 E.14079
G1 X119.738 Y127.614 E.01215
G1 X115.262 Y127.614 E.14079
G1 X115.262 Y127.228 E.01215
G1 X119.738 Y127.228 E.14079
G1 X119.738 Y126.842 E.01215
G1 X115.262 Y126.842 E.14079
G1 X115.262 Y126.456 E.01215
G1 X119.738 Y126.456 E.14079
G1 X119.738 Y126.07 E.01215
G1 X115.262 Y126.07 E.14079
G1 X115.262 Y125.684 E.01215
G1 X119.738 Y125.684 E.14079
G1 X119.738 Y125.297 E.01215
G1 X115.262 Y125.297 E.14079
G1 X115.262 Y124.911 E.01215
G1 X119.738 Y124.911 E.14079
G1 X119.738 Y124.525 E.01215
G1 X115.262 Y124.525 E.14079
G1 X115.262 Y124.139 E.01215
G1 X119.738 Y124.139 E.14079
G1 X119.738 Y123.753 E.01215
G1 X115.262 Y123.753 E.14079
G1 X115.262 Y123.374 E.01193
G1 X119.907 Y123.367 E.14613
G1 X129.907 Y123.367 F36000
G1 F3000
G1 X125.262 Y123.374 E.14613
G1 X125.262 Y123.753 E.01193
G1 X129.738 Y123.753 E.14079
G1 X129.738 Y124.139 E.01215
G1 X125.262 Y124.139 E.14079
G1 X125.262 Y124.525 E.01215
G1 X129.738 Y124.525 E.14079
G1 X129.738 Y124.911 E.01215
M73 P63 R6
G1 X125.262 Y124.911 E.14079
G1 X125.262 Y125.297 E.01215
G1 X129.738 Y125.297 E.14079
G1 X129.738 Y125.684 E.01215
G1 X125.262 Y125.684 E.14079
G1 X125.262 Y126.07 E.01215
G1 X129.738 Y126.07 E.14079
G1 X129.738 Y126.456 E.01215
G1 X125.262 Y126.456 E.14079
G1 X125.262 Y126.842 E.01215
G1 X129.738 Y126.842 E.14079
G1 X129.738 Y127.228 E.01215
G1 X125.262 Y127.228 E.14079
G1 X125.262 Y127.614 E.01215
G1 X129.738 Y127.614 E.14079
G1 X129.738 Y128 E.01215
G1 X125.262 Y128 E.14079
G1 X125.262 Y128.386 E.01215
G1 X129.738 Y128.386 E.14079
G1 X129.738 Y128.772 E.01215
G1 X125.262 Y128.772 E.14079
G1 X125.262 Y129.158 E.01215
G1 X129.738 Y129.158 E.14079
G1 X129.738 Y129.544 E.01215
G1 X125.262 Y129.544 E.14079
G1 X125.262 Y129.93 E.01215
G1 X129.738 Y129.93 E.14079
G1 X129.738 Y130.317 E.01215
G1 X125.262 Y130.317 E.14079
G1 X125.262 Y130.703 E.01215
G1 X129.738 Y130.703 E.14079
G1 X129.738 Y131.089 E.01215
G1 X125.262 Y131.089 E.14079
G1 X125.262 Y131.475 E.01215
G1 X129.738 Y131.475 E.14079
G1 X129.738 Y131.861 E.01215
G1 X125.262 Y131.861 E.14079
G1 X125.262 Y132.247 E.01215
G1 X129.738 Y132.247 E.14079
G1 X129.738 Y132.626 E.01193
G1 X125.093 Y132.633 E.14613
G1 X145.662 Y132.784 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X160.428 Y132.784 E.40909
G1 X162.284 Y130.552 F36000
; LINE_WIDTH: 0.56288
G1 F12000
G1 X169.724 Y130.552 E.31526
G1 X169.9 Y129.892 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X169.9 Y130.088 E.00652
G1 X168.468 Y130.088 E.04749
G1 X164.292 Y125.912 E.19592
G1 X168.468 Y125.912 E.13854
G1 X164.292 Y130.088 E.19592
G1 X165.92 Y130.088 E.05401
G1 X162.284 Y125.448 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.5629
G1 F12000
G1 X169.724 Y125.448 E.31527
; WIPE_START
G1 X167.724 Y125.448 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.391 Y121.189 Z2.2 F36000
G1 X160.8 Y120.792 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X154.284 Y132.42 E.35728
G1 X155.448 Y132.42 E.03862
G1 X146.608 Y123.58 E.41472
G1 X147.772 Y123.58 E.03862
G1 X136.488 Y134.864 E.52934
G1 X134.863 Y134.864 E.0539
G1 X130.13 Y130.13 E.22208
G1 X130.13 Y125.87 E.14129
G1 X134.863 Y121.137 E.22208
G1 X136.488 Y121.137 E.0539
G1 X147.772 Y132.42 E.52934
G1 X146.608 Y132.42 E.03862
G1 X155.448 Y123.58 E.41472
G1 X154.284 Y123.58 E.03862
G1 X161.9 Y131.196 E.35728
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.208 E.05401
; WIPE_START
G1 X160.8 Y133.579 E-.61876
G1 X161.063 Y133.317 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X154.622 Y129.221 Z2.2 F36000
G1 X145.749 Y123.58 Z2.2
G1 Z1.8
G1 E.8 F1800
G1 F15476.087
G1 X145.511 Y123.58 E.00788
G1 X145.27 Y123.339 E.01131
G1 X145.27 Y122.954 E.01275
G1 X145.35 Y122.875 E.00372
G1 X145.35 Y122.322 E.01835
G1 X144.164 Y121.137 E.05561
G1 X142.539 Y121.137 E.0539
G1 X138.461 Y125.215 E.19133
G2 X134.715 Y127.039 I-.932 J2.845 E.15286
G1 X128.812 Y121.137 E.2769
G1 X127.188 Y121.137 E.0539
G1 X125.354 Y122.97 E.08603
G1 X125.111 Y122.97 E.00803
G1 X124.87 Y123.211 E.01131
G1 X124.87 Y123.454 E.00803
G1 X120.13 Y128.194 E.2224
G1 X120.13 Y127.806 E.0129
G1 X124.87 Y132.546 E.2224
G1 X124.87 Y132.789 E.00803
G1 X125.111 Y133.03 E.01131
G1 X125.354 Y133.03 E.00804
G1 X127.188 Y134.864 E.08603
G1 X128.812 Y134.864 E.0539
G1 X134.715 Y128.961 E.2769
G2 X138.461 Y130.785 I2.785 J-.961 E.15351
G1 X142.539 Y134.864 E.19133
G1 X144.164 Y134.864 E.0539
G1 X145.35 Y133.678 E.05561
G1 X145.35 Y133.125 E.01835
G1 X145.27 Y133.046 E.00372
G1 X145.27 Y132.661 E.01275
G1 X145.511 Y132.42 E.01131
G1 X145.749 Y132.42 E.00788
G1 X145.662 Y123.216 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X160.428 Y123.216 E.40909
; WIPE_START
G1 X158.428 Y123.216 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X150.801 Y123.499 Z2.2 F36000
G1 X86.199 Y125.903 Z2.2
G1 Z1.8
G1 E.8 F1800
; LINE_WIDTH: 0.52982
G1 F12000
G1 X92.373 Y125.903 E.24494
; WIPE_START
G1 X90.373 Y125.903 E-.76
; WIPE_END
G1 E-.04 F1800
G17
G3 Z2.2 I-.863 J-.858 P1  F36000
G1 X86.199 Y130.097 Z2.2
G1 Z1.8
G1 E.8 F1800
; LINE_WIDTH: 0.5298
G1 F12000
G1 X92.373 Y130.097 E.24493
G1 X86.116 Y132.784 F36000
; LINE_WIDTH: 0.38292
G1 F12000
G1 X99.278 Y132.784 E.36465
; CHANGE_LAYER
; Z_HEIGHT: 2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X97.278 Y132.784 E-.76
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
G1 X135.422 Y129.565
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.254 Y129.297 E.0105
G3 X137.315 Y125.409 I2.253 J-1.296 E.17402
G3 X139.085 Y125.935 I.2 J2.57 E.06264
G3 X135.464 Y129.607 I-1.577 J2.066 E.2927
G1 X135.753 Y129.341 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.34 Y125.8 I1.755 J-1.339 E.14563
G3 X138.605 Y126.086 I.156 J2.251 E.04041
G3 X135.79 Y129.388 I-1.097 J1.916 E.23835
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13247
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10987
G1 X135.308 Y128.289 E-.10986
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07813
; WIPE_END
G1 E-.04 F1800
G17
G3 Z2.4 I.066 J-1.215 P1  F36000
G1 X105.935 Y125.922 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.203 Y125.753 E.0105
G3 X107.315 Y125.409 I1.305 J2.249 E.03895
G3 X109.085 Y125.935 I.2 J2.57 E.06264
G3 X105.893 Y125.964 I-1.577 J2.068 E.42801
G1 X106.16 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.34 Y125.8 I1.348 J1.748 E.03941
G3 X108.605 Y126.086 I.156 J2.251 E.04041
G3 X106.113 Y126.29 I-1.097 J1.916 E.34457
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13247
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.34 Y125.8 E-.15867
G1 X107.5 Y125.79 E-.06078
G1 X107.789 Y125.808 E-.10989
G1 X107.991 Y125.849 E-.07844
; WIPE_END
G1 E-.04 F1800
G1 X100.531 Y127.464 Z2.4 F36000
G1 X92.452 Y129.214 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X92.452 Y126.786 E.08051
G1 X92.032 Y126.786 E.01392
G1 X85.752 Y126.786 E.20833
G1 X85.752 Y126.77 E.00056
G1 X85.752 Y122.914 E.1279
G1 X99.302 Y122.914 E.44948
G1 X99.302 Y120.835 E.06896
G1 X145.698 Y120.835 E1.53904
G1 X145.698 Y122.914 E.06896
G1 X160.452 Y122.914 E.48942
G1 X160.452 Y118.787 E.13688
G1 X162.248 Y118.787 E.05957
G1 X162.248 Y125.087 E.20896
G1 X170.248 Y125.087 E.26537
G1 X170.248 Y130.913 E.19329
G1 X162.248 Y130.913 E.26537
G1 X162.248 Y137.213 E.20896
G1 X160.452 Y137.213 E.05957
G1 X160.452 Y133.086 E.13689
G1 X145.698 Y133.086 E.48942
G1 X145.698 Y135.165 E.06896
G1 X99.302 Y135.165 E1.53904
G1 X99.302 Y133.086 E.06896
G1 X85.752 Y133.086 E.44948
G1 X85.752 Y129.23 E.1279
G1 X85.752 Y129.214 E.00056
G1 X92.032 Y129.214 E.20833
G1 X92.392 Y129.214 E.01193
G1 X92.06 Y128.821 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F3169.55
M204 S6000
G1 X92.06 Y128.379 E.01361
G1 F2443.993
G1 X92.06 Y127.979 E.01229
G1 F1869.696
G1 X92.06 Y127.579 E.01229
G1 F1372.199
G1 X92.06 Y127.179 E.01229
G1 F951.503
G1 X92.019 Y127.179 E.00126
G1 F912.73
G1 X91.65 Y127.179 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F600
G1 X85.36 Y127.179 E.20865
G1 X85.36 Y127.152 E.00088
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F912.73
G1 X85.36 Y126.783 E.01134
G1 F1325.557
G1 X85.36 Y126.383 E.01229
G1 F1815.183
G1 X85.36 Y125.983 E.01229
G1 F2381.61
G1 X85.36 Y125.583 E.01229
G1 F3024.837
G1 X85.36 Y125.183 E.01229
G1 F3744.863
G1 X85.36 Y124.783 E.01229
G1 F4541.69
G1 X85.36 Y124.383 E.01229
G1 F5415.317
G1 X85.36 Y123.983 E.01229
G1 F6365.743
G1 X85.36 Y123.583 E.01229
G1 F7392.97
G1 X85.36 Y123.183 E.01229
G1 F8496.997
G1 X85.36 Y122.783 E.01229
G1 F9259.405
G1 X85.36 Y122.522 E.00803
G1 F10490.384
G1 X85.76 Y122.522 E.01229
G1 F11798.163
G1 X86.16 Y122.522 E.01229
G1 F12000
G1 X86.56 Y122.522 E.01229
G1 X98.91 Y122.522 E.37948
G1 X98.91 Y120.443 E.06388
G1 X146.09 Y120.443 E1.44971
G1 X146.09 Y122.522 E.06388
G1 X160.06 Y122.522 E.42926
G1 X160.06 Y118.395 E.1268
G1 X162.64 Y118.395 E.07928
G1 X162.64 Y124.695 E.19356
G1 X170.64 Y124.695 E.24582
G1 X170.64 Y131.305 E.20314
G1 X162.64 Y131.305 E.24582
G1 X162.64 Y137.605 E.19356
G1 X160.06 Y137.605 E.07928
G1 X160.06 Y133.478 E.1268
G1 X146.09 Y133.478 E.42926
G1 X146.09 Y135.557 E.06388
G1 X98.91 Y135.557 E1.44971
G1 X98.91 Y133.478 E.06388
G1 X86.56 Y133.478 E.37948
G1 X86.16 Y133.478 E.01229
G1 F11798.129
G1 X85.76 Y133.478 E.01229
M73 P64 R6
G1 F10490.352
G1 X85.36 Y133.478 E.01229
G1 F9259.375
G1 X85.36 Y133.217 E.00803
G1 F8496.997
G1 X85.36 Y132.817 E.01229
G1 F7392.97
G1 X85.36 Y132.417 E.01229
G1 F6365.743
G1 X85.36 Y132.017 E.01229
G1 F5415.317
G1 X85.36 Y131.617 E.01229
G1 F4541.69
G1 X85.36 Y131.217 E.01229
G1 F3744.863
G1 X85.36 Y130.817 E.01229
G1 F3024.837
G1 X85.36 Y130.417 E.01229
G1 F2381.61
G1 X85.36 Y130.017 E.01229
G1 F1815.183
G1 X85.36 Y129.617 E.01229
G1 F1325.557
G1 X85.36 Y129.217 E.01229
G1 F912.73
G1 X85.36 Y128.848 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F600
G1 X85.36 Y128.821 E.00088
G1 X91.65 Y128.821 E.20865
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F895.022
G1 X92 Y128.821 E.01075
; WIPE_START
M204 S10000
G1 X92.06 Y128.379 E-.16985
G1 X92.06 Y127.979 E-.152
G1 X92.06 Y127.579 E-.152
G1 X92.06 Y127.179 E-.152
G1 X92.019 Y127.179 E-.01558
G1 X91.707 Y127.179 E-.11857
; WIPE_END
G1 E-.04 F1800
G1 X92.495 Y129.78 Z2.4 F36000
G1 Z2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.405675
G1 F12000
G1 X92.495 Y129.598 E.00536
G1 X86.137 Y129.598 E.18794
G1 X86.137 Y129.961 E.01072
G1 X92.479 Y129.961 E.18747
G1 X92.49 Y129.84 E.00361
G1 X92.495 Y126.065 F36000
; LINE_WIDTH: 0.40567
G1 F12000
G1 X92.468 Y126.039 E.00111
G1 X86.137 Y126.039 E.18715
G1 X86.137 Y126.402 E.01072
G1 X92.495 Y126.402 E.18793
G1 X92.495 Y126.125 E.00816
G1 X87.899 Y123.673 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.271 Y123.673 E.05401
G1 X86.1 Y123.844 E.00801
G1 X86.1 Y124.48 E.0211
G1 X87.274 Y125.654 E.05507
G1 X91.966 Y125.654 E.15564
G1 X93.947 Y123.673 E.09293
G1 X92.969 Y123.673 E.03244
G1 X104.113 Y134.817 E.52278
G1 X105.831 Y134.817 E.05699
G1 X114.87 Y125.778 E.42405
G1 X114.87 Y130.222 E.14744
G1 X105.831 Y121.183 E.42404
G1 X104.113 Y121.183 E.057
G1 X92.969 Y132.327 E.52278
G1 X93.947 Y132.327 E.03244
G1 X91.966 Y130.346 E.09293
G1 X87.274 Y130.346 E.15564
G1 X86.1 Y131.52 E.05507
G1 X86.1 Y132.156 E.0211
G1 X86.271 Y132.327 E.00801
G1 X87.899 Y132.327 E.05401
G1 X86.132 Y132.706 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39516
G1 F12000
G1 X99.271 Y132.706 E.37715
G1 X98.988 Y132.327 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.489 Y132.327 E.01661
G1 X99.73 Y132.568 E.01131
G1 X99.73 Y132.983 E.01377
G2 X99.65 Y133.322 I.13 J.209 E.01282
G1 X104.575 Y128.397 E.23104
G3 X104.575 Y127.603 I3.43 J-.397 E.02639
G1 X99.65 Y122.678 E.23104
G3 X99.73 Y123.432 I-8.357 J1.26 E.02515
G1 X99.489 Y123.673 E.01131
G1 X98.988 Y123.673 E.01661
; WIPE_START
G1 X99.489 Y123.673 E-.19028
G1 X99.73 Y123.432 E-.12954
G1 X99.73 Y123.017 E-.15778
G1 X99.65 Y122.938 E-.04261
G1 X99.65 Y122.678 E-.09856
G1 X99.913 Y122.941 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X105.943 Y127.62 Z2.4 F36000
G1 X109.369 Y130.279 Z2.4
G1 Z2
G1 E.8 F1800
G1 F15476.087
G3 X107.897 Y130.925 I-1.912 J-2.36 E.05396
G1 X111.789 Y134.817 E.18259
G1 X113.507 Y134.817 E.05699
G1 X115.294 Y133.03 E.08384
G1 X117.678 Y133.03 E.07906
G1 X119.465 Y134.817 E.08384
G1 X121.183 Y134.817 E.05699
G1 X124.87 Y131.13 E.17298
G1 X124.87 Y124.87 E.20763
G1 X121.183 Y121.183 E.17298
G1 X119.465 Y121.183 E.057
G1 X117.678 Y122.97 E.08384
G1 X115.294 Y122.97 E.07906
G1 X113.507 Y121.183 E.08384
G1 X111.789 Y121.183 E.057
G1 X107.897 Y125.075 E.18258
G3 X109.369 Y125.721 I-.44 J3.006 E.05396
G1 X119.738 Y123.382 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X119.718 Y123.362 E.00085
G1 X115.274 Y123.362 E.13656
G1 X115.262 Y123.382 E.00069
G1 X115.262 Y132.626 E.28405
G1 X115.282 Y132.638 E.00069
G1 X119.726 Y132.638 E.13656
G1 X119.738 Y132.618 E.00069
G1 X119.738 Y123.442 E.28195
G1 X119.361 Y123.739 F36000
G1 F12000
G1 X115.639 Y123.739 E.11434
G1 X115.639 Y132.261 E.26182
G1 X119.361 Y132.261 E.11434
G1 X119.361 Y123.799 E.25998
G1 X118.983 Y124.117 F36000
G1 F12000
G1 X116.016 Y124.117 E.09117
G1 X116.016 Y131.884 E.23865
G1 X118.983 Y131.884 E.09117
G1 X118.983 Y124.177 E.23681
G1 X118.606 Y124.494 F36000
G1 F12000
G1 X116.394 Y124.494 E.06799
G1 X116.394 Y131.506 E.21548
G1 X118.606 Y131.506 E.06799
G1 X118.606 Y124.554 E.21364
G1 X118.229 Y124.871 F36000
G1 F12000
G1 X116.771 Y124.871 E.04482
G1 X116.771 Y131.129 E.19231
G1 X118.229 Y131.129 E.04482
G1 X118.229 Y124.931 E.19047
G1 X117.852 Y125.248 F36000
G1 F12000
G1 X117.148 Y125.248 E.02165
G1 X117.148 Y130.752 E.16914
G1 X117.852 Y130.752 E.02165
G1 X117.852 Y125.308 E.16729
G1 X117.5 Y130.4 F36000
; LINE_WIDTH: 0.37042
G1 F12000
G1 X117.5 Y125.66 E.1265
G1 X129.738 Y123.382 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X129.718 Y123.362 E.00085
G1 X125.274 Y123.362 E.13656
G1 X125.262 Y123.382 E.00069
G1 X125.262 Y132.626 E.28405
G1 X125.282 Y132.638 E.00069
G1 X129.726 Y132.638 E.13656
G1 X129.738 Y132.618 E.00069
G1 X129.738 Y123.442 E.28195
G1 X129.361 Y123.739 F36000
G1 F12000
G1 X125.639 Y123.739 E.11434
G1 X125.639 Y132.261 E.26182
G1 X129.361 Y132.261 E.11434
G1 X129.361 Y123.799 E.25998
G1 X128.984 Y124.117 F36000
G1 F12000
G1 X126.016 Y124.117 E.09117
G1 X126.016 Y131.884 E.23865
G1 X128.984 Y131.884 E.09117
G1 X128.984 Y124.177 E.23681
G1 X128.606 Y124.494 F36000
G1 F12000
G1 X126.394 Y124.494 E.06799
G1 X126.394 Y131.506 E.21548
G1 X128.606 Y131.506 E.06799
G1 X128.606 Y124.554 E.21364
G1 X128.229 Y124.871 F36000
G1 F12000
G1 X126.771 Y124.871 E.04482
G1 X126.771 Y131.129 E.19231
G1 X128.229 Y131.129 E.04482
G1 X128.229 Y124.931 E.19047
G1 X127.852 Y125.248 F36000
G1 F12000
G1 X127.148 Y125.248 E.02165
G1 X127.148 Y130.752 E.16914
G1 X127.852 Y130.752 E.02165
G1 X127.852 Y125.308 E.16729
G1 X127.5 Y130.4 F36000
; LINE_WIDTH: 0.37044
G1 F12000
G1 X127.5 Y125.66 E.1265
G1 X145.669 Y123.294 F36000
; LINE_WIDTH: 0.39515
G1 F12000
G1 X160.421 Y123.294 E.42344
G1 X162.316 Y125.583 F36000
; LINE_WIDTH: 0.62814
G1 F10765.183
G1 X169.692 Y125.583 E.35172
G1 X166.087 Y129.921 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.459 Y129.921 E.05401
G1 X168.301 Y126.079 E.18026
G1 X164.459 Y126.079 E.12746
G1 X168.301 Y129.921 E.18026
G1 X169.9 Y129.892 E.05304
G1 X162.316 Y130.417 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.62815
G1 F10764.999
G1 X169.692 Y130.417 E.35172
; WIPE_START
G1 X167.692 Y130.417 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.425 Y134.774 Z2.4 F36000
G1 X160.8 Y135.208 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X154.377 Y123.673 E.35291
G1 X155.355 Y123.673 E.03244
G1 X146.701 Y132.327 E.40597
G1 X147.679 Y132.327 E.03244
G1 X136.535 Y121.183 E.52278
G1 X134.817 Y121.183 E.057
G1 X130.13 Y125.87 E.21989
G1 X130.13 Y130.13 E.14129
G1 X134.817 Y134.817 E.21989
G1 X136.535 Y134.817 E.05699
G1 X147.679 Y123.673 E.52278
G1 X146.701 Y123.673 E.03244
G1 X155.355 Y132.327 E.40597
G1 X154.377 Y132.327 E.03244
G1 X161.9 Y124.804 E.35291
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
; WIPE_START
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X154.593 Y126.733 Z2.4 F36000
G1 X145.656 Y132.327 Z2.4
G1 Z2
G1 E.8 F1800
G1 F15476.087
G1 X145.511 Y132.327 E.00479
G1 X145.27 Y132.568 E.01131
G1 X145.27 Y132.983 E.01377
G1 X145.35 Y133.062 E.00372
G1 X145.35 Y133.678 E.02043
G1 X144.211 Y134.817 E.05342
G1 X142.493 Y134.817 E.05699
G1 X138.461 Y130.785 E.18914
G3 X134.715 Y128.961 I-.961 J-2.785 E.15351
G1 X128.859 Y134.817 E.27471
G1 X127.141 Y134.817 E.05699
G1 X125.354 Y133.03 E.08384
G1 X125.111 Y133.03 E.00804
G1 X124.87 Y132.789 E.01131
G1 X124.87 Y132.546 E.00803
G1 X120.13 Y127.806 E.2224
G1 X120.13 Y128.194 E.0129
G1 X124.87 Y123.454 E.2224
G1 X124.87 Y123.211 E.00803
G1 X125.111 Y122.97 E.01131
G1 X125.354 Y122.97 E.00803
G1 X127.141 Y121.183 E.08384
G1 X128.859 Y121.183 E.057
G1 X134.715 Y127.039 E.27471
G3 X138.461 Y125.215 I2.814 J1.021 E.15286
G1 X142.493 Y121.183 E.18914
G1 X144.211 Y121.183 E.057
G1 X145.35 Y122.322 E.05342
G1 X145.35 Y122.938 E.02043
G1 X145.27 Y123.017 E.00372
G1 X145.27 Y123.432 E.01377
G1 X145.511 Y123.673 E.01131
G1 X145.656 Y123.673 E.00479
G1 X145.669 Y132.706 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39517
G1 F12000
G1 X160.421 Y132.706 E.42346
; WIPE_START
G1 X158.421 Y132.706 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X150.853 Y131.721 Z2.4 F36000
G1 X86.132 Y123.294 Z2.4
G1 Z2
G1 E.8 F1800
; LINE_WIDTH: 0.39516
G1 F12000
G1 X99.271 Y123.294 E.37715
; CHANGE_LAYER
; Z_HEIGHT: 2.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X97.271 Y123.294 E-.76
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
G1 X135.422 Y129.565
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.254 Y129.297 E.0105
G3 X137.299 Y125.41 I2.255 J-1.295 E.17351
G3 X138.802 Y125.745 I.196 J2.652 E.0518
G3 X135.463 Y129.607 I-1.293 J2.256 E.30421
G1 X135.754 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.325 Y125.801 I1.754 J-1.34 E.14513
G3 X138.605 Y126.086 I.171 J2.252 E.04089
G3 X135.791 Y129.387 I-1.098 J1.915 E.23818
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13246
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07815
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z2.6 F36000
G1 X105.898 Y125.95 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.921 Y125.942 E.00082
G3 X107.299 Y125.41 I1.588 J2.059 E.0497
G3 X108.802 Y125.745 I.196 J2.652 E.0518
G3 X105.667 Y126.167 I-1.293 J2.256 E.4292
G1 X105.854 Y125.991 E.00851
G1 X106.16 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.325 Y125.801 I1.348 J1.747 E.03894
G3 X108.605 Y126.086 I.171 J2.252 E.04089
G3 X106.113 Y126.29 I-1.098 J1.915 E.34437
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13245
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.325 Y125.801 E-.15285
G1 X107.5 Y125.79 E-.06663
G1 X107.789 Y125.808 E-.10988
G1 X107.991 Y125.849 E-.07843
; WIPE_END
G1 E-.04 F1800
G1 X115.602 Y125.271 Z2.6 F36000
G1 X145.698 Y122.986 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y122.986 E.48942
G1 X160.452 Y118.829 E.13787
G1 X162.248 Y118.829 E.05957
G1 X162.248 Y125.198 E.21126
G1 X170.248 Y125.198 E.26537
G1 X170.248 Y130.802 E.18589
G1 X162.248 Y130.802 E.26537
G1 X162.248 Y137.171 E.21126
G1 X160.452 Y137.171 E.05957
G1 X160.452 Y133.014 E.13787
M73 P65 R6
G1 X145.698 Y133.014 E.48942
G1 X145.698 Y135.116 E.06973
G1 X99.302 Y135.116 E1.53904
G1 X99.302 Y133.014 E.06973
G1 X86.952 Y133.014 E.40967
G1 X86.552 Y133.014 E.01327
G1 F14448.212
G1 X86.152 Y133.014 E.01327
G1 F12996.899
G1 X85.752 Y133.014 E.01327
G1 F11622.386
G1 X85.752 Y132.794 E.00731
G1 F10898.137
G1 X85.752 Y132.394 E.01327
G1 F9642.723
G1 X85.752 Y131.994 E.01327
G1 F8464.109
G1 X85.752 Y131.594 E.01327
G1 F7362.296
G1 X85.752 Y131.194 E.01327
G1 F6337.282
G1 X85.752 Y130.794 E.01327
G1 F5389.068
G1 X85.752 Y130.394 E.01327
G1 F4517.655
G1 X85.752 Y129.994 E.01327
G1 F3723.041
G1 X85.752 Y129.594 E.01327
G1 F3005.227
G1 X85.752 Y129.194 E.01327
G1 F2364.214
G1 X85.752 Y128.794 E.01327
G1 F1800
G1 X85.752 Y128.411 E.01269
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X85.752 Y127.589 E.0273
; FEATURE: Inner wall
G1 F1800
M204 S10000
G1 X85.752 Y127.206 E.01269
G1 F2364.214
G1 X85.752 Y126.806 E.01327
G1 F3005.227
G1 X85.752 Y126.406 E.01327
G1 F3723.041
G1 X85.752 Y126.006 E.01327
G1 F4517.655
G1 X85.752 Y125.606 E.01327
G1 F5389.068
G1 X85.752 Y125.206 E.01327
G1 F6337.282
G1 X85.752 Y124.806 E.01327
G1 F7362.296
G1 X85.752 Y124.406 E.01327
G1 F8464.109
G1 X85.752 Y124.006 E.01327
G1 F9642.723
G1 X85.752 Y123.606 E.01327
G1 F10898.137
G1 X85.752 Y123.206 E.01327
G1 F11622.386
G1 X85.752 Y122.986 E.00731
G1 F12996.899
G1 X86.152 Y122.986 E.01327
G1 F14448.212
G1 X86.552 Y122.986 E.01327
G1 F15476.087
G1 X86.952 Y122.986 E.01327
G1 X99.302 Y122.986 E.40967
G1 X99.302 Y120.884 E.06973
G1 X145.698 Y120.884 E1.53904
G1 X145.698 Y122.926 E.06774
G1 X146.09 Y122.594 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y122.594 E.42926
G1 X160.06 Y118.437 E.12771
G1 X162.64 Y118.437 E.07928
G1 X162.64 Y124.806 E.19569
G1 X170.64 Y124.806 E.24582
G1 X170.64 Y131.194 E.19629
G1 X162.64 Y131.194 E.24582
G1 X162.64 Y137.563 E.19569
G1 X160.06 Y137.563 E.07928
G1 X160.06 Y133.406 E.12771
G1 X146.09 Y133.406 E.42926
G1 X146.09 Y135.509 E.06459
G1 X98.91 Y135.509 E1.44971
G1 X98.91 Y133.406 E.06459
G1 X85.36 Y133.406 E.41635
G1 X85.36 Y133.18 E.00694
G1 X85.36 Y132.78 E.01229
G1 F10898.137
G1 X85.36 Y132.38 E.01229
G1 F9642.723
G1 X85.36 Y131.98 E.01229
G1 F8464.109
G1 X85.36 Y131.58 E.01229
G1 F7362.296
G1 X85.36 Y131.18 E.01229
G1 F6337.282
G1 X85.36 Y130.78 E.01229
G1 F5389.068
G1 X85.36 Y130.38 E.01229
G1 F4517.655
G1 X85.36 Y129.98 E.01229
G1 F3723.041
G1 X85.36 Y129.58 E.01229
G1 F3005.227
G1 X85.36 Y129.18 E.01229
G1 F2364.214
G1 X85.36 Y128.78 E.01229
G1 F1800
G1 X85.36 Y128.411 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X85.36 Y127.589 E.0273
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1800
G1 X85.36 Y127.22 E.01134
G1 F2364.214
G1 X85.36 Y126.82 E.01229
G1 F3005.227
G1 X85.36 Y126.42 E.01229
G1 F3723.041
G1 X85.36 Y126.02 E.01229
G1 F4517.655
G1 X85.36 Y125.62 E.01229
G1 F5389.068
G1 X85.36 Y125.22 E.01229
G1 F6337.282
G1 X85.36 Y124.82 E.01229
G1 F7362.296
G1 X85.36 Y124.42 E.01229
G1 F8464.109
G1 X85.36 Y124.02 E.01229
G1 F9642.723
G1 X85.36 Y123.62 E.01229
G1 F10898.137
G1 X85.36 Y123.22 E.01229
G1 F12000
G1 X85.36 Y122.82 E.01229
G1 X85.36 Y122.594 E.00694
G1 X98.91 Y122.594 E.41635
G1 X98.91 Y120.492 E.06459
G1 X146.09 Y120.492 E1.44971
G1 X146.09 Y122.534 E.06275
M204 S10000
G1 X145.676 Y123.384 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.43199
G1 F12000
G1 X160.414 Y123.384 E.46724
G1 X160.8 Y120.792 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X154.486 Y132.218 E.34781
G1 X155.246 Y132.218 E.02522
G1 X146.81 Y123.782 E.39576
G1 X147.57 Y123.782 E.02522
G1 X136.93 Y134.422 E.49916
G1 X134.422 Y134.422 E.08318
G1 X129.402 Y129.402 E.23553
G1 X129.402 Y126.598 E.09298
G1 X134.422 Y121.578 E.23553
G1 X136.93 Y121.578 E.08318
G1 X147.57 Y132.218 E.49916
G1 X146.81 Y132.218 E.02522
G1 X155.246 Y123.782 E.39576
G1 X154.486 Y123.782 E.02522
G1 X161.9 Y131.196 E.34781
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.208 E.05401
G1 X162.192 Y130.43 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.37978
G1 F12000
G1 X169.876 Y130.43 E.21091
G1 X169.876 Y130.093 E.00925
G1 X162.216 Y130.093 E.21028
G1 X162.196 Y130.37 E.00762
G1 X169.729 Y129.721 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X168.101 Y129.721 E.05401
G1 X164.659 Y126.279 E.16149
G1 X168.101 Y126.279 E.11419
G1 X164.659 Y129.721 E.16149
G1 X163.03 Y129.721 E.05401
G1 X169.876 Y125.738 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.379775
G1 F12000
G1 X169.876 Y125.57 E.00462
G1 X162.192 Y125.57 E.21091
G1 X162.216 Y125.907 E.00927
G1 X169.876 Y125.907 E.21028
G1 X169.876 Y125.798 E.00298
; WIPE_START
G1 X169.876 Y125.907 E-.0412
G1 X167.984 Y125.907 E-.7188
; WIPE_END
G1 E-.04 F1800
G1 X160.51 Y124.363 Z2.6 F36000
G1 X145.351 Y121.231 Z2.6
G1 Z2.2
G1 E.8 F1800
; Slow Down Start
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X99.709 Y121.231 E1.26453
; Slow Down End
; WIPE_START
G1 X101.709 Y121.231 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X99.097 Y123.782 Z2.6 F36000
G1 Z2.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.489 Y123.782 E.013
G1 X99.73 Y123.541 E.01131
G1 X99.73 Y123.089 E.015
G1 X99.65 Y123.009 E.00372
G1 X99.65 Y122.678 E.01099
G1 X104.575 Y127.603 E.23104
G2 X104.575 Y128.397 I34.321 J.397 E.02633
G1 X99.65 Y133.322 E.23104
G1 X99.65 Y132.991 E.01099
G1 X99.73 Y132.911 E.00372
G1 X99.73 Y132.459 E.015
G1 X99.489 Y132.218 E.01131
G1 X99.097 Y132.218 E.013
G1 X92.477 Y129.835 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.44169
G1 F3000
G1 X92.477 Y126.355 E.11308
G1 X92.395 Y126.315 E.00296
G1 X92.078 Y126.315 E.01031
G1 X92.078 Y129.685 E.10953
G1 X91.679 Y129.685 E.01296
G1 X91.679 Y126.315 E.10953
G1 X91.28 Y126.315 E.01296
G1 X91.28 Y129.685 E.10953
G1 X90.881 Y129.685 E.01296
G1 X90.881 Y126.315 E.10953
G1 X90.483 Y126.315 E.01296
G1 X90.483 Y129.685 E.10953
G1 X90.084 Y129.685 E.01296
G1 X90.084 Y126.315 E.10953
G1 X89.685 Y126.315 E.01296
G1 X89.685 Y129.685 E.10953
G1 X89.286 Y129.685 E.01296
G1 X89.286 Y126.315 E.10953
G1 X88.888 Y126.315 E.01296
G1 X88.888 Y129.685 E.10953
G1 X88.489 Y129.685 E.01296
G1 X88.489 Y126.315 E.10953
G1 X88.09 Y126.315 E.01296
G1 X88.09 Y129.685 E.10953
G1 X87.691 Y129.685 E.01296
G1 X87.691 Y126.315 E.10953
G1 X87.293 Y126.315 E.01296
G1 X87.293 Y129.685 E.10953
G1 X86.894 Y129.685 E.01296
G1 X86.894 Y126.315 E.10953
G1 X86.495 Y126.315 E.01296
G1 X86.495 Y129.685 E.10953
G1 X86.096 Y129.685 E.01296
G1 X86.096 Y126.145 E.11505
G1 X87.03 Y123.782 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.1 Y123.782 E.03085
G1 X86.1 Y124.48 E.02316
G1 X87.543 Y125.922 E.06766
G1 X91.698 Y125.922 E.13783
G1 X93.838 Y123.782 E.10042
G1 X93.078 Y123.782 E.02522
G1 X103.718 Y134.422 E.49916
G1 X106.226 Y134.422 E.08318
G1 X115.598 Y125.05 E.43969
G1 X115.598 Y130.95 E.19574
G1 X106.226 Y121.578 E.43969
G1 X103.718 Y121.578 E.08318
G1 X93.078 Y132.218 E.49916
G1 X93.838 Y132.218 E.02522
G1 X91.698 Y130.078 E.10042
G1 X87.543 Y130.078 E.13783
G1 X86.1 Y131.52 E.06766
G1 X86.1 Y132.218 E.02316
G1 X87.03 Y132.218 E.03085
G1 X86.15 Y132.616 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.43199
G1 F12000
G1 X99.264 Y132.616 E.41576
; WIPE_START
G1 X97.264 Y132.616 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X103.896 Y128.838 Z2.6 F36000
G1 X109.369 Y125.721 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X107.897 Y125.075 I-1.912 J2.36 E.05396
G1 X111.394 Y121.578 E.16407
G1 X113.902 Y121.578 E.08318
G1 X116.022 Y123.698 E.09948
G1 X116.95 Y123.698 E.03075
G1 X119.07 Y121.578 E.09948
G1 X121.578 Y121.578 E.08318
G1 X125.598 Y125.598 E.18862
G1 X125.598 Y130.402 E.15933
G1 X121.578 Y134.422 E.18862
G1 X119.07 Y134.422 E.08318
G1 X116.95 Y132.302 E.09948
G1 X116.022 Y132.302 E.03076
G1 X113.902 Y134.422 E.09948
G1 X111.394 Y134.422 E.08318
G1 X107.897 Y130.925 E.16407
G2 X109.369 Y130.279 I-.44 J-3.005 E.05396
G1 X117.5 Y130.4 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42242
G1 F15000
G1 X117.5 Y125.66 E.14658
G1 X117.878 Y125.222 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X117.122 Y125.222 E.02325
G1 X117.122 Y130.778 E.17073
G1 X117.878 Y130.778 E.02325
G1 X117.878 Y125.282 E.16889
G1 X118.255 Y124.845 F36000
G1 F15000
G1 X116.745 Y124.845 E.04642
G1 X116.745 Y131.155 E.19391
G1 X118.255 Y131.155 E.04642
G1 X118.255 Y124.905 E.19206
G1 X118.632 Y124.468 F36000
G1 F15000
G1 X116.368 Y124.468 E.06959
G1 X116.368 Y131.532 E.21708
G1 X118.632 Y131.532 E.06959
G1 X118.632 Y124.528 E.21523
G1 X119.009 Y124.11 F36000
G1 F15000
G1 X118.99 Y124.091 E.00084
G1 X116.002 Y124.091 E.09182
G1 X115.991 Y124.11 E.00069
G1 X115.991 Y131.898 E.2393
G1 X116.01 Y131.91 E.00069
G1 X118.998 Y131.91 E.09182
G1 X119.009 Y131.89 E.00069
G1 X119.009 Y124.17 E.23721
G1 X127.5 Y130.4 F36000
; LINE_WIDTH: 0.42242
G1 F15000
G1 X127.5 Y125.66 E.14658
G1 X127.878 Y125.222 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X127.122 Y125.222 E.02325
G1 X127.122 Y130.778 E.17073
G1 X127.878 Y130.778 E.02325
G1 X127.878 Y125.282 E.16889
G1 X128.255 Y124.845 F36000
G1 F15000
G1 X126.745 Y124.845 E.04642
G1 X126.745 Y131.155 E.19391
G1 X128.255 Y131.155 E.04642
G1 X128.255 Y124.905 E.19206
G1 X128.632 Y124.468 F36000
G1 F15000
G1 X126.368 Y124.468 E.06959
G1 X126.368 Y131.532 E.21708
G1 X128.632 Y131.532 E.06959
G1 X128.632 Y124.528 E.21523
G1 X129.01 Y124.11 F36000
G1 F15000
G1 X128.99 Y124.091 E.00084
G1 X126.002 Y124.091 E.09182
G1 X125.991 Y124.11 E.00069
G1 X125.991 Y131.898 E.2393
G1 X126.01 Y131.91 E.00069
G1 X128.998 Y131.91 E.09182
G1 X129.01 Y131.89 E.00069
G1 X129.01 Y124.17 E.23721
G1 X130.882 Y121.578 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X129.254 Y121.578 E.05401
G1 X134.715 Y127.039 E.2562
G2 X134.715 Y128.961 I3.177 J.961 E.06468
G1 X129.254 Y134.422 E.2562
G1 X126.746 Y134.422 E.08318
G1 X119.402 Y127.078 E.34455
G1 X119.402 Y128.922 E.0612
M73 P66 R6
G1 X126.746 Y121.578 E.34455
G1 X125.118 Y121.578 E.05401
; WIPE_START
G1 X126.746 Y121.578 E-.61876
G1 X126.483 Y121.841 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X133.187 Y125.49 Z2.6 F36000
G1 X145.547 Y132.218 Z2.6
G1 Z2.2
G1 E.8 F1800
G1 F15476.087
G1 X145.27 Y132.459 E.01217
G1 X145.27 Y132.911 E.015
G1 X145.35 Y132.991 E.00372
G1 X145.35 Y133.678 E.02281
G1 X144.606 Y134.422 E.0349
G1 X142.098 Y134.422 E.08318
G1 X138.461 Y130.785 E.17063
G2 X138.461 Y125.215 I-.961 J-2.785 E.24208
G1 X142.098 Y121.578 E.17063
G1 X144.606 Y121.578 E.08318
G1 X145.35 Y122.322 E.0349
G1 X145.35 Y123.009 E.02281
G1 X145.27 Y123.089 E.00372
G1 X145.27 Y123.541 E.015
G1 X145.547 Y123.782 E.01217
G1 X145.676 Y132.616 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.43199
G1 F12000
G1 X160.414 Y132.616 E.46724
; WIPE_START
G1 X158.414 Y132.616 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X150.883 Y133.858 Z2.6 F36000
G1 X145.351 Y134.769 Z2.6
G1 Z2.2
G1 E.8 F1800
; Slow Down Start
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X99.709 Y134.769 E1.26453
; Slow Down End
; WIPE_START
G1 X101.709 Y134.769 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X95.55 Y130.262 Z2.6 F36000
G1 X86.15 Y123.384 Z2.6
G1 Z2.2
M73 P66 R5
G1 E.8 F1800
; LINE_WIDTH: 0.43199
G1 F12000
G1 X99.264 Y123.384 E.41576
; CHANGE_LAYER
; Z_HEIGHT: 2.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X97.264 Y123.384 E-.76
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
G1 X135.45 Y129.602
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.441 Y129.58 E.00081
G3 X137.284 Y125.411 I2.067 J-1.578 E.1843
G3 X138.802 Y125.745 I.211 J2.653 E.05232
G3 X135.665 Y129.836 I-1.293 J2.256 E.2941
G1 X135.491 Y129.647 E.00852
G1 X135.753 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.31 Y125.802 I1.756 J-1.339 E.14466
G3 X138.346 Y125.958 I.206 J2.151 E.03252
G3 X135.79 Y129.388 I-.837 J2.043 E.2473
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13247
G1 X135.458 Y128.846 E-.10989
G1 X135.365 Y128.572 E-.10987
G1 X135.308 Y128.288 E-.10989
G1 X135.29 Y128 E-.10985
G1 X135.308 Y127.712 E-.10985
G1 X135.349 Y127.51 E-.07817
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z2.8 F36000
G1 X105.898 Y125.95 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.921 Y125.942 E.00082
G3 X107.284 Y125.411 I1.588 J2.06 E.04919
G3 X108.802 Y125.745 I.211 J2.653 E.05231
G3 X105.666 Y126.166 I-1.293 J2.256 E.42922
G1 X105.854 Y125.991 E.00851
G1 X106.16 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.31 Y125.802 I1.349 J1.748 E.03847
G3 X108.346 Y125.958 I.206 J2.151 E.03252
G3 X106.113 Y126.291 I-.837 J2.043 E.35349
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13247
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.31 Y125.802 E-.14702
G1 X107.5 Y125.79 E-.07248
G1 X107.789 Y125.808 E-.10988
G1 X107.991 Y125.849 E-.07839
; WIPE_END
G1 E-.04 F1800
G1 X115.603 Y125.286 Z2.8 F36000
G1 X145.698 Y123.063 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y123.063 E.48942
G1 X160.452 Y118.872 E.13903
G1 X162.248 Y118.872 E.05957
G1 X162.248 Y125.334 E.21438
G1 X170.248 Y125.334 E.26537
G1 X170.248 Y130.666 E.17685
G1 X162.248 Y130.666 E.26537
G1 X162.248 Y137.128 E.21438
G1 X160.452 Y137.128 E.05957
G1 X160.452 Y132.937 E.13903
G1 X145.698 Y132.937 E.48942
G1 X145.698 Y135.056 E.07027
G1 X99.302 Y135.056 E1.53904
G1 X99.302 Y132.937 E.07027
G1 X85.752 Y132.937 E.44948
G1 X85.752 Y123.063 E.32756
G1 X99.302 Y123.063 E.44948
G1 X99.302 Y120.944 E.07027
G1 X145.698 Y120.944 E1.53904
G1 X145.698 Y123.003 E.06828
G1 X146.09 Y122.671 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y122.671 E.42926
G1 X160.06 Y118.479 E.12878
G1 X162.64 Y118.479 E.07928
G1 X162.64 Y124.942 E.19858
G1 X170.64 Y124.942 E.24582
G1 X170.64 Y131.058 E.18792
G1 X162.64 Y131.058 E.24582
G1 X162.64 Y137.521 E.19858
G1 X160.06 Y137.521 E.07928
G1 X160.06 Y133.329 E.12878
G1 X146.09 Y133.329 E.42926
G1 X146.09 Y135.448 E.06509
G1 X98.91 Y135.448 E1.44971
G1 X98.91 Y133.329 E.06509
G1 X85.36 Y133.329 E.41635
G1 X85.36 Y122.671 E.32752
G1 X98.91 Y122.671 E.41635
G1 X98.91 Y120.552 E.06509
G1 X146.09 Y120.552 E1.44971
G1 X146.09 Y122.611 E.06325
M204 S10000
G1 X145.686 Y123.478 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.46745
G1 F12000
G1 X160.404 Y123.478 E.50915
G1 X163.26 Y129.492 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X164.888 Y129.492 E.05401
G1 X167.872 Y126.508 E.13997
G1 X164.888 Y126.508 E.09897
G1 X167.872 Y129.492 E.13997
G1 X169.5 Y129.492 E.05401
G1 X169.853 Y125.921 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.4264
G1 F12000
G1 X169.853 Y125.73 E.00599
G1 X162.216 Y125.73 E.23865
G1 X162.232 Y126.113 E.01199
G1 X169.853 Y126.113 E.23814
G1 X169.853 Y125.981 E.00412
G1 X162.216 Y130.27 F36000
G1 F12000
G1 X169.853 Y130.27 E.23865
G1 X169.853 Y129.887 E.01198
G1 X162.225 Y129.887 E.23835
G1 X162.217 Y130.21 E.01011
G1 X160.8 Y135.208 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X154.598 Y123.894 E.34254
G1 X155.134 Y123.894 E.01777
G1 X146.922 Y132.106 E.38523
G1 X147.458 Y132.106 E.01777
G1 X137.008 Y121.656 E.49022
G1 X134.344 Y121.656 E.08837
G1 X121.656 Y134.344 E.59522
G1 X118.992 Y134.344 E.08837
G1 X106.304 Y121.656 E.59522
G1 X103.64 Y121.656 E.08837
G1 X93.19 Y132.106 E.49022
G1 X93.726 Y132.106 E.01777
G1 X91.261 Y129.641 E.11563
G1 X87.979 Y129.641 E.10888
G1 X86.1 Y131.52 E.08814
G1 X86.1 Y132.106 E.01944
G1 X87.143 Y132.106 E.03458
G1 X86.168 Y132.522 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.46746
G1 F12000
G1 X99.254 Y132.522 E.45271
G1 X99.209 Y132.106 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X99.73 Y132.347 I.14 J.381 E.02114
G1 X99.65 Y133.322 E.03245
G1 X104.575 Y128.397 E.23104
G3 X104.575 Y127.603 I34.397 J-.398 E.02633
G1 X99.65 Y122.678 E.23104
G1 X99.73 Y123.653 E.03245
G3 X99.209 Y123.894 I-.381 J-.14 E.02114
G1 X99.658 Y121.3 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X145.282 Y121.3 E1.26405
G1 X145.457 Y123.84 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X145.27 Y123.653 E.00876
G1 X145.27 Y123.166 E.01617
G1 X145.35 Y123.086 E.00372
G1 X145.35 Y122.322 E.02536
G1 X144.684 Y121.656 E.03123
G1 X142.02 Y121.656 E.08837
G1 X138.461 Y125.215 E.16696
G3 X138.461 Y130.785 I-.989 J2.785 E.24107
G1 X142.02 Y134.344 E.16696
G1 X144.684 Y134.344 E.08837
G1 X145.35 Y133.678 E.03123
G1 X145.35 Y132.914 E.02536
G1 X145.27 Y132.834 E.00372
G1 X145.27 Y132.347 E.01617
G1 X145.457 Y132.16 E.00876
G1 X145.686 Y132.522 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.46746
G1 F12000
G1 X160.404 Y132.522 E.50916
G1 X109.369 Y130.279 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X107.897 Y130.925 I-1.912 J-2.36 E.05396
G1 X111.316 Y134.344 E.1604
G1 X113.98 Y134.344 E.08837
G1 X126.668 Y121.656 E.59522
G1 X129.332 Y121.656 E.08837
G1 X134.715 Y127.039 E.25253
G2 X134.715 Y128.961 I3.178 J.961 E.06468
G1 X129.332 Y134.344 E.25253
G1 X126.668 Y134.344 E.08837
G1 X113.98 Y121.656 E.59522
G1 X111.316 Y121.656 E.08837
G1 X107.897 Y125.075 E.1604
G3 X109.369 Y125.721 I-.44 J3.005 E.05396
; WIPE_START
G1 X108.63 Y125.272 E-.3285
G1 X107.897 Y125.075 E-.2884
G1 X108.163 Y124.809 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X103.187 Y130.596 Z2.8 F36000
G1 X99.658 Y134.7 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X145.282 Y134.7 E1.26405
; WIPE_START
G1 X143.282 Y134.7 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.741 Y133.523 Z2.8 F36000
G1 X92.488 Y126.77 Z2.8
G1 Z2.4
G1 E.8 F1800
; LINE_WIDTH: 0.41999
G1 F12000
G1 X92.468 Y126.751 E.00085
G1 X86.144 Y126.751 E.19431
M73 P67 R5
G1 X86.144 Y129.249 E.07676
G1 X92.476 Y129.249 E.19456
G1 X92.488 Y126.83 E.07432
G1 X92.111 Y127.128 F36000
G1 F12000
G1 X86.521 Y127.128 E.17174
G1 X86.521 Y128.872 E.05359
G1 X92.111 Y128.872 E.17174
G1 X92.111 Y127.188 E.05175
G1 X91.733 Y127.505 F36000
G1 F12000
G1 X86.898 Y127.505 E.14857
G1 X86.898 Y128.495 E.03042
G1 X91.733 Y128.495 E.14857
G1 X91.733 Y127.565 E.02857
G1 X91.392 Y127.847 F36000
; LINE_WIDTH: 0.34936
G1 F12000
G1 X87.24 Y127.847 E.10367
G1 X87.24 Y128.153 E.00765
G1 X91.392 Y128.153 E.10367
G1 X91.392 Y127.907 E.00615
G1 X87.143 Y123.894 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.1 Y123.894 E.03458
G1 X86.1 Y124.48 E.01944
G1 X87.979 Y126.359 E.08814
G1 X91.261 Y126.359 E.10887
G1 X93.726 Y123.894 E.11563
G1 X93.19 Y123.894 E.01777
G1 X103.64 Y134.344 E.49022
G1 X106.304 Y134.344 E.08837
G1 X118.992 Y121.656 E.59522
G1 X121.656 Y121.656 E.08837
G1 X134.344 Y134.344 E.59522
G1 X137.008 Y134.344 E.08837
G1 X147.458 Y123.894 E.49022
G1 X146.922 Y123.894 E.01777
G1 X155.134 Y132.106 E.38523
G1 X154.598 Y132.106 E.01777
G1 X161.9 Y124.804 E.34254
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
; WIPE_START
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.431 Y122.764 Z2.8 F36000
G1 X86.168 Y123.478 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.46746
G1 F12000
G1 X99.254 Y123.478 E.45271
; CHANGE_LAYER
; Z_HEIGHT: 2.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X97.254 Y123.478 E-.76
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
G1 X135.45 Y129.602
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.442 Y129.579 E.00082
G3 X137.269 Y125.412 I2.066 J-1.578 E.18378
G3 X138.802 Y125.745 I.225 J2.654 E.05283
G3 X135.665 Y129.835 I-1.294 J2.255 E.29396
G1 X135.491 Y129.646 E.00852
G1 X135.753 Y129.341 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.294 Y125.803 I1.755 J-1.34 E.14425
G3 X138.346 Y125.958 I.22 J2.155 E.033
G3 X135.79 Y129.388 I-.838 J2.043 E.24728
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13247
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07813
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z3 F36000
G1 X105.898 Y125.95 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.921 Y125.942 E.00081
G3 X107.269 Y125.412 I1.587 J2.059 E.04869
G3 X108.802 Y125.745 I.225 J2.654 E.05283
G3 X105.666 Y126.166 I-1.294 J2.255 E.42905
G1 X105.854 Y125.991 E.00852
G1 X106.159 Y126.252 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.294 Y125.803 I1.349 J1.749 E.03801
G3 X108.346 Y125.958 I.22 J2.155 E.033
G3 X106.112 Y126.29 I-.838 J2.043 E.35352
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13246
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.294 Y125.803 E-.1412
G1 X107.5 Y125.79 E-.07833
G1 X107.789 Y125.808 E-.10988
G1 X107.991 Y125.849 E-.07837
; WIPE_END
G1 E-.04 F1800
G1 X115.604 Y125.304 Z3 F36000
G1 X145.698 Y123.152 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y123.152 E.48942
G1 X160.452 Y118.923 E.14029
G1 X162.248 Y118.923 E.05957
G1 X162.248 Y125.484 E.21765
G1 X170.248 Y125.484 E.26537
G1 X170.248 Y130.516 E.1669
G1 X162.248 Y130.516 E.26537
G1 X162.248 Y137.077 E.21765
G1 X160.452 Y137.077 E.05957
G1 X160.452 Y132.848 E.14029
G1 X145.698 Y132.848 E.48942
G1 X145.698 Y134.995 E.07123
G1 X99.302 Y134.995 E1.53904
G1 X99.302 Y132.848 E.07123
G1 X85.752 Y132.848 E.44948
G1 X85.752 Y123.152 E.32161
G1 X99.302 Y123.152 E.44948
G1 X99.302 Y121.005 E.07123
G1 X145.698 Y121.005 E1.53904
G1 X145.698 Y123.092 E.06924
G1 X146.09 Y122.76 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y122.76 E.42926
G1 X160.06 Y118.531 E.12995
G1 X162.64 Y118.531 E.07928
G1 X162.64 Y125.092 E.20161
G1 X170.64 Y125.092 E.24582
G1 X170.64 Y130.908 E.1787
G1 X162.64 Y130.908 E.24582
G1 X162.64 Y137.469 E.20161
G1 X160.06 Y137.469 E.07928
G1 X160.06 Y133.24 E.12995
G1 X146.09 Y133.24 E.42926
G1 X146.09 Y135.387 E.06598
G1 X98.91 Y135.387 E1.44971
G1 X98.91 Y133.24 E.06598
G1 X85.36 Y133.24 E.41635
G1 X85.36 Y122.76 E.32201
G1 X98.91 Y122.76 E.41635
G1 X98.91 Y120.613 E.06598
G1 X146.09 Y120.613 E1.44971
G1 X146.09 Y122.7 E.06414
M204 S10000
G1 X145.706 Y123.588 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.50731
G1 F12000
G1 X160.384 Y123.588 E.55544
G1 X162.245 Y130.091 F36000
; LINE_WIDTH: 0.485615
G1 F12000
G1 X169.823 Y130.091 E.27337
G1 X169.823 Y129.648 E.01597
G1 X162.245 Y129.648 E.27337
G1 X162.245 Y130.031 E.01381
G1 X169.231 Y129.223 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X167.603 Y129.223 E.05401
G1 X165.156 Y126.777 E.11478
G1 X167.603 Y126.777 E.08116
G1 X165.156 Y129.223 E.11478
G1 X163.528 Y129.223 E.05401
G1 X169.823 Y126.131 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.48561
G1 F12000
G1 X169.823 Y125.909 E.00798
G1 X162.245 Y125.909 E.27336
G1 X162.245 Y126.352 E.01597
G1 X169.823 Y126.352 E.27336
G1 X169.823 Y126.191 E.00582
G1 X145.706 Y132.412 F36000
; LINE_WIDTH: 0.5073
G1 F12000
G1 X160.384 Y132.412 E.55543
G1 X145.366 Y132.122 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X145.27 Y132.217 E.00447
G1 X145.27 Y132.745 E.01749
G1 X145.35 Y132.824 E.00372
G1 X145.35 Y133.678 E.02833
G1 X144.774 Y134.253 E.02698
G1 X141.929 Y134.253 E.09438
G1 X138.461 Y130.785 E.16271
G2 X138.461 Y125.215 I-.989 J-2.785 E.24107
G1 X141.929 Y121.747 E.16271
G1 X144.775 Y121.747 E.09438
G1 X145.35 Y122.322 E.02698
G1 X145.35 Y123.176 E.02833
G1 X145.27 Y123.255 E.00372
G1 X145.27 Y123.783 E.01749
G1 X145.366 Y123.878 E.00447
G1 X109.369 Y130.279 F36000
G1 F15476.087
G3 X107.897 Y130.925 I-1.912 J-2.36 E.05396
G1 X111.225 Y134.253 E.15615
G1 X114.071 Y134.253 E.09438
G1 X126.577 Y121.747 E.58672
G1 X129.423 Y121.747 E.09438
G1 X134.715 Y127.039 E.24828
G2 X134.715 Y128.961 I3.178 J.961 E.06468
G1 X129.423 Y134.253 E.24828
G1 X126.577 Y134.253 E.09438
G1 X114.071 Y121.747 E.58672
G1 X111.225 Y121.747 E.09438
G1 X107.897 Y125.075 E.15615
G3 X109.369 Y125.721 I-.44 J3.006 E.05396
; WIPE_START
G1 X108.63 Y125.272 E-.32852
G1 X107.897 Y125.075 E-.28837
G1 X108.163 Y124.809 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X100.561 Y124.132 Z3 F36000
G1 X99.338 Y124.024 Z3
G1 Z2.6
G1 E.8 F1800
G1 F15476.087
G1 X99.489 Y124.024 E.00498
G1 X99.73 Y123.783 E.01131
G1 X99.65 Y122.678 E.03673
G1 X104.575 Y127.603 E.23104
G2 X104.575 Y128.397 I27.882 J.397 E.02633
G1 X99.65 Y133.322 E.23104
G1 X99.73 Y132.217 E.03673
G1 X99.489 Y131.976 E.01131
G1 X99.338 Y131.976 E.00498
G1 X99.673 Y134.624 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X145.267 Y134.624 E1.26322
G1 X99.673 Y121.376 F36000
G1 F12000
G1 X145.267 Y121.376 E1.26322
; WIPE_START
G1 X143.267 Y121.376 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.697 Y122.349 Z3 F36000
G1 X91.76 Y128 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F15000
G1 X91.76 Y127.498 E.01541
G1 X91.239 Y127.479 E.01602
G1 X86.144 Y127.479 E.15653
G1 X86.144 Y128.521 E.03202
G1 X91.748 Y128.521 E.17219
G1 X91.758 Y128.06 E.01417
G1 X91.405 Y127.834 F36000
; LINE_WIDTH: 0.37545
G1 F15000
G1 X86.499 Y127.834 E.13293
G1 X86.499 Y128.166 E.00901
G1 X91.405 Y128.166 E.13293
G1 X91.405 Y127.894 E.00739
G1 X87.272 Y124.024 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.1 Y124.024 E.03887
G1 X86.1 Y124.48 E.01514
G1 X88.707 Y127.087 E.12229
G1 X90.533 Y127.087 E.06057
G1 X93.597 Y124.024 E.14371
G1 X93.32 Y124.024 E.00918
G1 X103.55 Y134.253 E.4799
G1 X106.395 Y134.253 E.09438
G1 X118.901 Y121.747 E.58672
G1 X121.747 Y121.747 E.09438
G1 X134.253 Y134.253 E.58672
G1 X137.099 Y134.253 E.09438
G1 X147.328 Y124.024 E.4799
G1 X147.052 Y124.024 E.00918
G1 X155.004 Y131.976 E.37308
G1 X154.727 Y131.976 E.00918
G1 X161.9 Y124.804 E.33646
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
; WIPE_START
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.491 Y123.637 Z3 F36000
G1 X87.272 Y131.976 Z3
G1 Z2.6
G1 E.8 F1800
M73 P68 R5
G1 F15476.087
G1 X86.1 Y131.976 E.03887
G1 X86.1 Y131.52 E.01514
G1 X88.707 Y128.913 E.12229
G1 X90.533 Y128.913 E.06057
G1 X93.597 Y131.976 E.14371
G1 X93.32 Y131.976 E.00918
G1 X103.55 Y121.747 E.4799
G1 X106.395 Y121.747 E.09438
G1 X118.901 Y134.253 E.58672
G1 X121.747 Y134.253 E.09438
G1 X134.253 Y121.747 E.58672
G1 X137.099 Y121.747 E.09438
G1 X147.328 Y131.976 E.4799
G1 X147.052 Y131.976 E.00918
G1 X155.004 Y124.024 E.37308
G1 X154.727 Y124.024 E.00918
G1 X161.9 Y131.196 E.33646
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.208 E.05401
; WIPE_START
G1 X160.8 Y133.579 E-.61876
G1 X161.063 Y133.317 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.431 Y133.224 Z3 F36000
G1 X86.188 Y132.412 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.5073
G1 F12000
G1 X99.234 Y132.412 E.49368
G1 X86.188 Y123.588 F36000
; LINE_WIDTH: 0.50732
G1 F12000
G1 X99.234 Y123.588 E.4937
; CHANGE_LAYER
; Z_HEIGHT: 2.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X97.234 Y123.588 E-.76
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
G1 X135.45 Y129.602
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.443 Y129.579 E.00083
G3 X137.253 Y125.413 I2.065 J-1.579 E.18328
G3 X138.802 Y125.745 I.239 J2.657 E.05334
G3 X135.666 Y129.834 I-1.294 J2.254 E.29382
G1 X135.491 Y129.646 E.00851
G1 X135.754 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.279 Y125.804 I1.755 J-1.34 E.14371
G3 X138.072 Y125.865 I.216 J2.391 E.02456
G3 X135.791 Y129.387 I-.563 J2.135 E.25616
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13252
G1 X135.458 Y128.846 E-.10987
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10991
G1 X135.308 Y127.712 E-.10982
G1 X135.349 Y127.51 E-.07814
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.098 Z3.2 F36000
G1 X105.935 Y125.922 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.202 Y125.752 E.01051
G3 X107.253 Y125.413 I1.305 J2.247 E.03692
G3 X108.802 Y125.745 I.239 J2.657 E.05334
G3 X105.892 Y125.963 I-1.294 J2.254 E.43893
G1 X106.159 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.279 Y125.804 I1.35 J1.747 E.03754
G3 X108.072 Y125.865 I.216 J2.39 E.02456
G3 X106.112 Y126.29 I-.563 J2.135 E.36233
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13252
G1 X106.654 Y125.958 E-.10986
G1 X106.928 Y125.865 E-.10989
G1 X107.279 Y125.804 E-.13538
G1 X107.5 Y125.79 E-.08417
G1 X107.789 Y125.808 E-.10989
G1 X107.991 Y125.849 E-.07829
; WIPE_END
G1 E-.04 F1800
G1 X115.605 Y125.323 Z3.2 F36000
G1 X145.698 Y123.246 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y123.246 E.48942
G1 X160.452 Y118.978 E.14157
G1 X162.248 Y118.978 E.05957
G1 X162.248 Y125.651 E.22137
G1 X170.248 Y125.651 E.26537
G1 X170.248 Y130.349 E.15583
G1 X162.248 Y130.349 E.26537
G1 X162.248 Y137.022 E.22137
G1 X160.452 Y137.022 E.05957
G1 X160.452 Y132.754 E.14157
G1 X145.698 Y132.754 E.48942
G1 X145.698 Y134.925 E.072
G1 X99.302 Y134.925 E1.53904
G1 X99.302 Y132.754 E.072
G1 X85.752 Y132.754 E.44948
G1 X85.752 Y123.246 E.31543
G1 X99.302 Y123.246 E.44948
G1 X99.302 Y121.075 E.072
G1 X145.698 Y121.075 E1.53904
G1 X145.698 Y123.186 E.07001
G1 X146.09 Y122.853 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y122.853 E.42926
G1 X160.06 Y118.586 E.13114
G1 X162.64 Y118.586 E.07928
G1 X162.64 Y125.259 E.20506
G1 X170.64 Y125.259 E.24582
G1 X170.64 Y130.741 E.16844
G1 X162.64 Y130.741 E.24582
G1 X162.64 Y137.414 E.20506
G1 X160.06 Y137.414 E.07928
G1 X160.06 Y133.147 E.13114
G1 X146.09 Y133.147 E.42926
G1 X146.09 Y135.317 E.0667
G1 X98.91 Y135.317 E1.44971
G1 X98.91 Y133.147 E.0667
G1 X85.36 Y133.147 E.41635
G1 X85.36 Y122.853 E.31628
G1 X98.91 Y122.853 E.41635
G1 X98.91 Y120.683 E.0667
G1 X146.09 Y120.683 E1.44971
G1 X146.09 Y122.793 E.06485
M204 S10000
G1 X145.727 Y123.702 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54909
G1 F12000
G1 X160.363 Y123.702 E.60369
G1 X163.853 Y128.898 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X165.482 Y128.898 E.05401
G1 X167.278 Y127.102 E.08427
G1 X165.482 Y127.102 E.05959
G1 X167.278 Y128.898 E.08427
G1 X168.906 Y128.898 E.05401
G1 X169.784 Y126.377 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.56474
G1 F12000
G1 X169.784 Y126.116 E.01109
G1 X162.285 Y126.116 E.31886
G1 X162.285 Y126.638 E.02219
G1 X169.784 Y126.638 E.31886
G1 X169.784 Y126.437 E.00854
G1 X162.285 Y129.884 F36000
G1 F12000
G1 X169.784 Y129.884 E.31886
G1 X169.784 Y129.363 E.02219
G1 X162.285 Y129.363 E.31886
G1 X162.285 Y129.824 E.01964
G1 X160.8 Y135.208 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X154.869 Y124.159 E.32997
G1 X147.187 Y131.841 E.36041
G1 X137.189 Y121.837 E.46915
G1 X134.163 Y121.837 E.10039
G1 X121.837 Y134.163 E.57821
G1 X118.811 Y134.163 E.10039
G1 X106.485 Y121.837 E.57821
G1 X103.459 Y121.837 E.10039
G1 X93.462 Y131.841 E.46915
G1 X86.1 Y124.48 E.34533
G1 X86.1 Y131.52 E.23352
G1 X93.462 Y124.159 E.34533
G1 X103.459 Y134.163 E.46915
G1 X106.485 Y134.163 E.10039
G1 X118.811 Y121.837 E.57821
G1 X121.837 Y121.837 E.10039
G1 X134.163 Y134.163 E.57821
G1 X137.189 Y134.163 E.10039
G1 X147.187 Y124.159 E.46915
G1 X154.869 Y131.841 E.36041
G1 X161.9 Y124.804 E.32997
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
; WIPE_START
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.454 Y123.278 Z3.2 F36000
G1 X145.27 Y123.917 Z3.2
G1 Z2.8
G1 E.8 F1800
G1 F15476.087
G1 X145.27 Y123.349 E.01887
G1 X145.35 Y123.269 E.00372
G1 X145.35 Y122.322 E.03143
G1 X144.865 Y121.837 E.02273
G1 X141.839 Y121.837 E.10039
G1 X138.461 Y125.215 E.15846
G3 X138.461 Y130.785 I-.989 J2.785 E.24107
G1 X141.839 Y134.163 E.15846
G1 X144.865 Y134.163 E.10039
G1 X145.35 Y133.678 E.02273
G1 X145.35 Y132.731 E.03143
G1 X145.27 Y132.651 E.00372
G1 X145.27 Y132.083 E.01887
G1 X145.727 Y132.298 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54908
G1 F12000
G1 X160.363 Y132.298 E.60368
G1 X109.369 Y130.279 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X107.897 Y130.925 I-1.912 J-2.36 E.05396
G1 X111.135 Y134.163 E.1519
G1 X114.161 Y134.163 E.10039
G1 X126.487 Y121.837 E.57821
G1 X129.513 Y121.837 E.10039
G1 X134.715 Y127.039 E.24403
G2 X134.715 Y128.961 I3.177 J.961 E.06468
G1 X129.513 Y134.163 E.24403
G1 X126.487 Y134.163 E.10039
G1 X114.161 Y121.837 E.57821
G1 X111.135 Y121.837 E.10039
G1 X107.897 Y125.075 E.1519
G3 X109.368 Y125.722 I-.431 J2.975 E.05395
G1 X99.683 Y121.456 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39824
G1 F12000
G1 X145.257 Y121.456 E1.31954
; WIPE_START
G1 X143.257 Y121.456 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.83 Y123.218 Z3.2 F36000
G1 X99.473 Y131.841 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.73 Y132.082 E.01167
G1 X99.65 Y133.322 E.0412
G1 X104.575 Y128.397 E.23104
G3 X104.575 Y127.603 I34.473 J-.397 E.02633
G1 X99.65 Y122.678 E.23104
G1 X99.73 Y123.918 E.0412
G1 X99.473 Y124.159 E.01167
G1 X99.683 Y134.544 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39824
G1 F12000
G1 X145.257 Y134.544 E1.31954
; WIPE_START
G1 X143.257 Y134.544 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.63 Y134.244 Z3.2 F36000
G1 X86.209 Y132.298 Z3.2
G1 Z2.8
G1 E.8 F1800
; LINE_WIDTH: 0.54907
G1 F12000
G1 X99.213 Y132.298 E.53636
G1 X86.209 Y123.702 F36000
; LINE_WIDTH: 0.5491
M73 P69 R5
G1 F12000
G1 X99.213 Y123.702 E.5364
; CHANGE_LAYER
; Z_HEIGHT: 3
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X97.213 Y123.702 E-.76
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
G1 X135.45 Y129.602
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.443 Y129.579 E.00083
G3 X137.238 Y125.414 I2.065 J-1.579 E.18278
G3 X138.496 Y125.595 I.276 J2.545 E.04261
G3 X135.666 Y129.834 I-.988 J2.405 E.30523
G1 X135.491 Y129.646 E.00852
G1 X135.753 Y129.341 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.264 Y125.805 I1.755 J-1.341 E.14335
G3 X138.072 Y125.865 I.229 J2.405 E.02503
G3 X135.79 Y129.388 I-.565 J2.135 E.25613
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13247
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10987
G1 X135.308 Y128.288 E-.1099
G1 X135.29 Y128 E-.10985
G1 X135.308 Y127.712 E-.10986
G1 X135.349 Y127.51 E-.07815
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.098 Z3.4 F36000
G1 X105.935 Y125.922 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.202 Y125.752 E.01051
G3 X107.238 Y125.414 I1.306 J2.249 E.03642
G3 X108.496 Y125.595 I.276 J2.546 E.04261
G3 X105.892 Y125.963 I-.988 J2.406 E.45059
G1 X106.159 Y126.252 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.264 Y125.805 I1.349 J1.747 E.03708
G3 X108.072 Y125.865 I.229 J2.404 E.02503
G3 X106.112 Y126.289 I-.564 J2.134 E.36218
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13247
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10986
G1 X107.264 Y125.805 E-.12958
G1 X107.5 Y125.79 E-.09005
G1 X107.788 Y125.808 E-.10983
G1 X107.991 Y125.849 E-.07832
; WIPE_END
G1 E-.04 F1800
G1 X115.606 Y125.345 Z3.4 F36000
G1 X145.698 Y123.354 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y123.354 E.48942
G1 X160.452 Y119.032 E.14336
G1 X162.248 Y119.032 E.05957
G1 X162.248 Y125.851 E.22619
G1 X170.248 Y125.851 E.26537
G1 X170.248 Y130.149 E.14256
G1 X162.248 Y130.149 E.26537
G1 X162.248 Y136.968 E.22619
G1 X160.452 Y136.968 E.05957
G1 X160.452 Y132.646 E.14337
G1 X145.698 Y132.646 E.48942
G1 X145.698 Y134.85 E.07311
G1 X99.302 Y134.85 E1.53904
G1 X99.302 Y132.646 E.07311
G1 X85.752 Y132.646 E.44948
G1 X85.752 Y123.354 E.30821
G1 X99.302 Y123.354 E.44948
G1 X99.302 Y121.15 E.07311
G1 X145.698 Y121.15 E1.53904
G1 X145.698 Y123.294 E.07112
G1 X146.09 Y122.962 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y122.962 E.42926
G1 X160.06 Y118.64 E.1328
G1 X162.64 Y118.64 E.07928
G1 X162.64 Y125.459 E.20952
G1 X170.64 Y125.459 E.24582
G1 X170.64 Y130.541 E.15615
G1 X162.64 Y130.541 E.24582
G1 X162.64 Y137.36 E.20952
G1 X160.06 Y137.36 E.07928
G1 X160.06 Y133.038 E.1328
G1 X146.09 Y133.038 E.42926
G1 X146.09 Y135.242 E.06772
G1 X98.91 Y135.242 E1.44971
G1 X98.91 Y133.038 E.06772
G1 X85.36 Y133.038 E.41635
G1 X85.36 Y122.962 E.30959
G1 X98.91 Y122.962 E.41635
G1 X98.91 Y120.758 E.06772
G1 X146.09 Y120.758 E1.44971
G1 X146.09 Y122.902 E.06588
M204 S10000
G1 X145.749 Y123.833 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.59278
G1 F11457.462
G1 X160.341 Y123.833 E.65384
; WIPE_START
G1 X158.341 Y123.833 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.8 Y120.792 Z3.4 F36000
G1 Z3
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X155.015 Y131.689 E.32298
G1 X154.717 Y131.689 E.00989
G1 X147.339 Y124.311 E.3461
G1 X147.041 Y124.311 E.00989
G1 X137.293 Y134.059 E.45729
G1 X134.059 Y134.059 E.10728
G1 X121.941 Y121.941 E.56848
G1 X118.707 Y121.941 E.10728
G1 X106.589 Y134.059 E.56848
G1 X103.355 Y134.059 E.10728
G1 X93.607 Y124.311 E.45729
G1 X93.309 Y124.311 E.00989
G1 X86.1 Y131.52 E.33818
G1 X86.1 Y124.48 E.23352
G1 X93.309 Y131.689 E.33818
G1 X93.607 Y131.689 E.00989
G1 X103.355 Y121.941 E.45729
G1 X106.589 Y121.941 E.10728
G1 X118.707 Y134.059 E.56848
G1 X121.941 Y134.059 E.10728
G1 X134.059 Y121.941 E.56848
G1 X137.293 Y121.941 E.10728
G1 X147.041 Y131.689 E.45729
G1 X147.339 Y131.689 E.00989
G1 X154.717 Y124.311 E.3461
G1 X155.015 Y124.311 E.00989
G1 X161.9 Y131.196 E.32298
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.208 E.05401
G1 X162.212 Y129.757 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X169.856 Y129.757 E.23486
G1 X169.856 Y128.875 E.02709
G1 X162.224 Y128.875 E.23451
G1 X162.213 Y129.697 E.02525
G1 X162.653 Y129.316 F36000
; LINE_WIDTH: 0.54752
G1 F12000
G1 X169.355 Y129.316 E.27557
G1 X168.491 Y128.483 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X166.863 Y128.483 E.05401
G1 X165.897 Y127.517 E.04532
G1 X166.863 Y127.517 E.03205
G1 X165.897 Y128.483 E.04532
G1 X164.268 Y128.483 E.05401
G1 X169.856 Y126.684 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X169.856 Y126.243 E.01355
G1 X162.212 Y126.243 E.23486
G1 X162.212 Y127.114 E.02674
G1 X169.856 Y127.125 E.23486
G1 X169.856 Y126.744 E.0117
G1 X162.653 Y126.684 F36000
; LINE_WIDTH: 0.54752
G1 F12000
G1 X169.355 Y126.684 E.27557
G1 X145.749 Y132.167 F36000
; LINE_WIDTH: 0.59278
G1 F11457.462
G1 X160.341 Y132.167 E.65384
G1 X145.27 Y132.083 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X145.27 Y132.543 E.01526
G1 X145.35 Y132.622 E.00372
G1 X145.35 Y133.678 E.03503
G1 X144.969 Y134.059 E.01786
G1 X141.735 Y134.059 E.10728
G1 X138.461 Y130.785 E.15359
G2 X138.461 Y125.215 I-.989 J-2.785 E.24107
G1 X141.735 Y121.941 E.15359
G1 X144.969 Y121.941 E.10728
G1 X145.35 Y122.322 E.01786
G1 X145.35 Y123.378 E.03503
G1 X145.27 Y123.457 E.00372
G1 X145.27 Y123.917 E.01526
G1 X109.368 Y125.722 F36000
G1 F15476.087
G2 X107.897 Y125.075 I-1.903 J2.332 E.05395
G1 X111.031 Y121.941 E.14703
G1 X114.265 Y121.941 E.10728
G1 X126.383 Y134.059 E.56848
G1 X129.617 Y134.059 E.10728
G1 X134.715 Y128.961 E.23916
G3 X134.715 Y127.039 I3.178 J-.961 E.06468
G1 X129.617 Y121.941 E.23916
G1 X126.383 Y121.941 E.10728
G1 X114.265 Y134.059 E.56848
G1 X111.031 Y134.059 E.10728
G1 X107.897 Y130.925 E.14703
G2 X109.369 Y130.279 I-.44 J-3.005 E.05396
G1 X99.697 Y134.454 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.42675
G1 F12000
G1 X145.242 Y134.454 E1.42452
; WIPE_START
G1 X143.242 Y134.454 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.812 Y132.711 Z3.4 F36000
G1 X99.586 Y124.214 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.73 Y124.07 E.00675
G1 X99.65 Y122.678 E.04625
G1 X104.575 Y127.603 E.23104
G2 X104.575 Y128.397 I34.549 J.397 E.02633
G1 X99.65 Y133.322 E.23104
G1 X99.73 Y131.93 E.04625
G1 X99.586 Y131.786 E.00675
G1 X99.697 Y121.546 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.42675
G1 F12000
G1 X145.243 Y121.546 E1.42452
; WIPE_START
G1 X143.243 Y121.546 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.616 Y121.852 Z3.4 F36000
G1 X86.231 Y123.833 Z3.4
G1 Z3
G1 E.8 F1800
; LINE_WIDTH: 0.59278
G1 F11457.462
G1 X99.191 Y123.833 E.58073
G1 X86.231 Y132.167 F36000
; LINE_WIDTH: 0.59277
G1 F11457.671
G1 X99.191 Y132.167 E.58072
; CHANGE_LAYER
; Z_HEIGHT: 3.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F11457.671
G1 X97.191 Y132.167 E-.76
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
G1 X135.422 Y129.565
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.254 Y129.297 E.0105
G3 X137.223 Y125.415 I2.253 J-1.298 E.17109
G3 X138.496 Y125.595 I.289 J2.551 E.04312
G3 X135.464 Y129.607 I-.989 J2.404 E.31526
G1 X135.755 Y129.339 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.248 Y125.806 I1.754 J-1.341 E.14282
G3 X137.789 Y125.808 I.261 J2.056 E.01665
G3 X135.792 Y129.386 I-.28 J2.19 E.26494
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13245
G1 X135.458 Y128.846 E-.10993
G1 X135.365 Y128.572 E-.10985
G1 X135.308 Y128.289 E-.10986
G1 X135.29 Y128 E-.10989
G1 X135.308 Y127.711 E-.10989
G1 X135.349 Y127.51 E-.07813
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z3.6 F36000
G1 X105.898 Y125.95 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.919 Y125.94 E.00079
M73 P70 R5
G3 X107.223 Y125.415 I1.588 J2.061 E.0472
G3 X108.496 Y125.595 I.289 J2.551 E.04312
G3 X105.664 Y126.164 I-.989 J2.406 E.44056
G1 X105.853 Y125.991 E.00852
G1 X106.158 Y126.252 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.248 Y125.806 I1.35 J1.748 E.03662
G3 X107.789 Y125.808 I.261 J2.056 E.01665
G3 X106.111 Y126.289 I-.28 J2.191 E.37133
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13249
G1 X106.654 Y125.958 E-.10992
G1 X106.928 Y125.865 E-.10987
G1 X107.248 Y125.806 E-.12376
G1 X107.5 Y125.79 E-.09587
G1 X107.789 Y125.808 E-.10989
G1 X107.99 Y125.849 E-.07821
; WIPE_END
G1 E-.04 F1800
G1 X115.608 Y125.367 Z3.6 F36000
G1 X145.698 Y123.467 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y123.467 E.48942
G1 X160.452 Y119.099 E.14489
G1 X162.248 Y119.099 E.05957
G1 X162.248 Y126.081 E.2316
G1 X170.248 Y126.081 E.26537
G1 X170.248 Y129.919 E.12734
G1 X162.248 Y129.919 E.26537
G1 X162.248 Y136.901 E.2316
G1 X160.452 Y136.901 E.05957
G1 X160.452 Y132.533 E.14489
G1 X145.698 Y132.533 E.48942
G1 X145.698 Y134.772 E.07424
G1 X99.302 Y134.772 E1.53904
G1 X99.302 Y132.533 E.07424
G1 X85.752 Y132.533 E.44948
G1 X85.752 Y123.467 E.30076
G1 X99.302 Y123.467 E.44948
G1 X99.302 Y121.228 E.07424
G1 X145.698 Y121.228 E1.53904
G1 X145.698 Y123.407 E.07225
G1 X146.09 Y123.075 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y123.075 E.42926
G1 X160.06 Y118.707 E.13421
G1 X162.64 Y118.707 E.07928
G1 X162.64 Y125.689 E.21454
G1 X170.64 Y125.689 E.24582
G1 X170.64 Y130.311 E.14205
G1 X162.64 Y130.311 E.24582
G1 X162.64 Y137.293 E.21454
G1 X160.06 Y137.293 E.07928
G1 X160.06 Y132.925 E.13421
G1 X146.09 Y132.925 E.42926
G1 X146.09 Y135.164 E.06877
G1 X98.91 Y135.164 E1.44971
G1 X98.91 Y132.925 E.06877
G1 X85.36 Y132.925 E.41635
G1 X85.36 Y123.075 E.30269
G1 X98.91 Y123.075 E.41635
G1 X98.91 Y120.836 E.06877
G1 X146.09 Y120.836 E1.44971
G1 X146.09 Y123.015 E.06693
; WIPE_START
M204 S10000
G1 X148.09 Y123.023 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.774 Y123.97 Z3.6 F36000
G1 Z3.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.6436
G1 F10488.113
G1 X160.316 Y123.97 E.71178
G1 X161.796 Y125.836 F36000
; LINE_WIDTH: 0.5392
G1 F12000
G1 X161.798 Y126.267 E.01746
G1 X161.796 Y130.164 F36000
G1 F12000
G1 X161.796 Y129.776 E.01572
G1 X162.044 Y129.527 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X169.856 Y129.527 E.24002
G1 X169.856 Y126.473 E.09386
G1 X162.044 Y126.473 E.24002
; LINE_WIDTH: 0.440489
G1 X161.962 Y126.424 E.00309
; LINE_WIDTH: 0.481485
G1 X161.88 Y126.376 E.00341
; LINE_WIDTH: 0.522482
G1 X161.798 Y126.327 E.00372
G1 X161.778 Y126.478 E.00596
; LINE_WIDTH: 0.481485
G1 X161.757 Y126.629 E.00545
; LINE_WIDTH: 0.421196
G1 X161.737 Y126.78 E.0047
G1 X161.737 Y129.22 E.07518
; LINE_WIDTH: 0.439859
G1 X161.757 Y129.385 E.00539
; LINE_WIDTH: 0.479595
G1 X161.776 Y129.55 E.00593
; LINE_WIDTH: 0.519332
G1 X161.796 Y129.716 E.00647
G1 X161.863 Y129.665 E.00326
; LINE_WIDTH: 0.479595
G1 X161.93 Y129.614 E.00298
; LINE_WIDTH: 0.439859
G1 X161.997 Y129.564 E.00271
G1 X169.479 Y126.85 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X162.114 Y126.85 E.2263
G1 X162.114 Y129.15 E.07068
G1 X169.479 Y129.15 E.2263
G1 X169.479 Y126.91 E.06884
G1 X169.102 Y127.227 F36000
G1 F12000
G1 X162.491 Y127.227 E.20313
G1 X162.491 Y128.773 E.04751
G1 X169.102 Y128.773 E.20313
G1 X169.102 Y127.287 E.04567
G1 X168.725 Y128 F36000
G1 F12000
G1 X168.725 Y127.604 E.01217
G1 X162.868 Y127.604 E.17996
G1 X162.868 Y128.396 E.02434
G1 X168.725 Y128.396 E.17996
G1 X168.725 Y128.06 E.01033
G1 X163.264 Y128 F36000
; Slow Down Start
; LINE_WIDTH: 0.458
G1 F3000;_EXTRUDE_SET_SPEED
G1 X168.269 Y128 E.16928
; Slow Down End
; WIPE_START
G1 X166.269 Y128 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.655 Y134.081 Z3.6 F36000
G1 X160.8 Y135.208 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X155.178 Y124.474 E.31533
G1 X154.554 Y124.474 E.02071
G1 X147.502 Y131.526 E.3308
G1 X146.878 Y131.526 E.02071
G1 X137.4 Y122.048 E.44462
G1 X133.952 Y122.048 E.11437
G1 X122.048 Y133.952 E.55845
G1 X118.6 Y133.952 E.11437
G1 X106.696 Y122.048 E.55845
G1 X103.248 Y122.048 E.11437
G1 X93.77 Y131.526 E.44462
G1 X93.146 Y131.526 E.02071
G1 X86.1 Y124.48 E.33053
G1 X86.1 Y131.52 E.23352
G1 X93.146 Y124.474 E.33053
G1 X93.77 Y124.474 E.02071
G1 X103.248 Y133.952 E.44462
G1 X106.696 Y133.952 E.11437
G1 X118.6 Y122.048 E.55845
G1 X122.048 Y122.048 E.11437
G1 X133.952 Y133.952 E.55845
G1 X137.4 Y133.952 E.11437
G1 X146.878 Y124.474 E.44462
G1 X147.502 Y124.474 E.02071
G1 X154.554 Y131.526 E.3308
G1 X155.178 Y131.526 E.02071
G1 X161.9 Y124.804 E.31533
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
; WIPE_START
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.454 Y123.278 Z3.6 F36000
G1 X145.27 Y123.917 Z3.6
G1 Z3.2
G1 E.8 F1800
G1 F15476.087
G1 X145.27 Y123.57 E.01154
G1 X145.35 Y123.49 E.00372
G1 X145.35 Y122.322 E.03876
G1 X145.076 Y122.048 E.01285
G1 X141.628 Y122.048 E.11437
G1 X138.461 Y125.215 E.14857
G3 X138.461 Y130.785 I-.989 J2.785 E.24107
G1 X141.628 Y133.952 E.14857
G1 X145.076 Y133.952 E.11437
G1 X145.35 Y133.678 E.01285
G1 X145.35 Y132.51 E.03876
G1 X145.27 Y132.43 E.00372
G1 X145.27 Y132.083 E.01154
G1 X145.774 Y132.03 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.64359
G1 F10488.288
G1 X160.316 Y132.03 E.71177
; WIPE_START
G1 X158.316 Y132.03 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X150.746 Y131.054 Z3.6 F36000
G1 X109.369 Y125.721 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X107.897 Y125.075 I-1.913 J2.361 E.05396
G1 X110.924 Y122.048 E.14201
G1 X114.372 Y122.048 E.11437
G1 X126.276 Y133.952 E.55845
G1 X129.724 Y133.952 E.11437
G1 X134.715 Y128.961 E.23414
G3 X134.715 Y127.039 I3.178 J-.961 E.06468
G1 X129.724 Y122.048 E.23414
G1 X126.276 Y122.048 E.11437
G1 X114.372 Y133.952 E.55845
G1 X110.924 Y133.952 E.11437
G1 X107.897 Y130.925 E.14201
G2 X109.369 Y130.279 I-.44 J-3.006 E.05396
; WIPE_START
G1 X108.63 Y130.728 E-.32851
G1 X107.897 Y130.925 E-.28839
G1 X108.163 Y131.191 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X100.547 Y131.684 Z3.6 F36000
G1 X99.701 Y131.738 Z3.6
G1 Z3.2
G1 E.8 F1800
G1 F15476.087
G1 X99.73 Y132.43 E.02298
G1 X99.65 Y132.51 E.00372
G1 X99.65 Y133.322 E.02694
G1 X104.575 Y128.397 E.23104
G3 X104.575 Y127.603 I29.893 J-.396 E.02633
G1 X99.65 Y122.678 E.23104
G1 X99.65 Y123.49 E.02694
G1 X99.73 Y123.57 E.00372
G1 X99.701 Y124.262 E.02298
G1 X99.712 Y121.638 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.45542
G1 F12000
G1 X145.228 Y121.638 E1.52996
G1 X99.712 Y134.362 F36000
; LINE_WIDTH: 0.45543
G1 F12000
G1 X145.228 Y134.362 E1.53
; WIPE_START
G1 X143.228 Y134.362 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.602 Y134.05 Z3.6 F36000
G1 X86.256 Y132.03 Z3.6
G1 Z3.2
G1 E.8 F1800
; LINE_WIDTH: 0.64359
G1 F10488.288
G1 X99.166 Y132.03 E.6319
G1 X86.256 Y123.97 F36000
; LINE_WIDTH: 0.6436
G1 F10488.113
G1 X99.166 Y123.97 E.63191
; CHANGE_LAYER
; Z_HEIGHT: 3.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F10488.113
G1 X97.166 Y123.97 E-.76
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
G1 X135.422 Y129.565
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.253 Y129.298 E.01051
G3 X137.169 Y125.418 I2.251 J-1.301 E.16952
G1 X137.5 Y125.397 E.011
G3 X135.463 Y129.608 I.004 J2.6 E.34896
G1 X135.752 Y129.341 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.22 Y125.808 I1.752 J-1.344 E.14219
G1 X137.5 Y125.79 E.00864
G3 X135.789 Y129.388 I.004 J2.208 E.27355
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13249
G1 X135.458 Y128.846 E-.10991
G1 X135.365 Y128.572 E-.10987
G1 X135.308 Y128.289 E-.10986
G1 X135.29 Y128 E-.1099
G1 X135.308 Y127.711 E-.10987
G1 X135.349 Y127.51 E-.07811
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z3.8 F36000
G1 X105.898 Y125.95 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.917 Y125.937 E.00078
G3 X107.169 Y125.418 I1.587 J2.06 E.04548
G1 X107.5 Y125.397 E.011
G3 X105.668 Y126.156 I.004 J2.6 E.47446
G1 X105.853 Y125.99 E.00823
G1 X106.156 Y126.249 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.22 Y125.808 I1.348 J1.749 E.03578
G1 X107.5 Y125.79 E.00864
G3 X106.109 Y126.286 I.004 J2.208 E.37996
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13255
G1 X106.654 Y125.958 E-.10987
G1 X106.928 Y125.865 E-.11002
G1 X107.22 Y125.808 E-.11278
G1 X107.5 Y125.79 E-.10681
M73 P71 R5
G1 X107.789 Y125.808 E-.1099
G1 X107.99 Y125.849 E-.07808
; WIPE_END
G1 E-.04 F1800
G1 X115.609 Y125.393 Z3.8 F36000
G1 X145.698 Y123.596 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y123.596 E.48942
G1 X160.452 Y119.166 E.14694
G1 X162.248 Y119.166 E.05957
G1 X162.248 Y126.349 E.23826
G1 X170.248 Y126.349 E.26537
G1 X170.248 Y129.651 E.10953
G1 X162.248 Y129.651 E.26537
G1 X162.248 Y136.834 E.23827
G1 X160.452 Y136.834 E.05957
G1 X160.452 Y132.404 E.14694
G1 X145.698 Y132.404 E.48942
G1 X145.698 Y134.681 E.07553
G1 X99.302 Y134.681 E1.53904
G1 X99.302 Y132.404 E.07553
G1 X85.752 Y132.404 E.44948
G1 X85.752 Y123.596 E.29217
G1 X99.302 Y123.596 E.44948
G1 X99.302 Y121.319 E.07553
G1 X145.698 Y121.319 E1.53904
G1 X145.698 Y123.536 E.07354
G1 X146.09 Y123.204 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y123.204 E.42926
G1 X160.06 Y118.774 E.13611
G1 X162.64 Y118.774 E.07928
G1 X162.64 Y125.957 E.22071
G1 X170.64 Y125.957 E.24582
G1 X170.64 Y130.043 E.12555
G1 X162.64 Y130.043 E.24582
G1 X162.64 Y137.226 E.22071
G1 X160.06 Y137.226 E.07928
G1 X160.06 Y132.796 E.13612
G1 X146.09 Y132.796 E.42926
G1 X146.09 Y135.073 E.06997
G1 X98.91 Y135.073 E1.44971
G1 X98.91 Y132.796 E.06997
G1 X85.36 Y132.796 E.41635
G1 X85.36 Y123.204 E.29473
G1 X98.91 Y123.204 E.41635
G1 X98.91 Y120.927 E.06997
G1 X146.09 Y120.927 E1.44971
G1 X146.09 Y123.144 E.06812
M204 S10000
G1 X145.636 Y123.962 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.36762
G1 F12000
G1 X160.514 Y123.962 E.39365
G3 X160.49 Y124.271 I-.949 J.081 E.00823
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X160.487 Y124.287 E.00043
G1 X145.663 Y124.287 E.39223
G1 X145.662 Y124.271 E.00042
; Slow Down End
G1 F12000
G1 X145.641 Y124.022 E.00661
G1 X145.27 Y132.083 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X145.35 Y133.678 I-6.419 J1.119 E.05312
G1 X145.191 Y133.836 E.00742
G1 X141.512 Y133.836 E.12204
G1 X138.461 Y130.785 E.14315
G2 X138.46 Y125.215 I-.989 J-2.785 E.24108
G1 X141.512 Y122.164 E.14317
G1 X145.191 Y122.164 E.12204
G1 X145.35 Y122.322 E.00742
G1 X145.35 Y123.62 E.04306
G2 X145.27 Y123.917 I.109 J.188 E.01134
; WIPE_START
G1 X145.27 Y123.699 E-.08293
G1 X145.35 Y123.62 E-.04261
G1 X145.35 Y122.322 E-.49322
G1 X145.191 Y122.164 E-.08504
G1 X145.044 Y122.164 E-.0562
; WIPE_END
G1 E-.04 F1800
G1 X152.647 Y121.502 Z3.8 F36000
G1 X160.8 Y120.792 Z3.8
G1 Z3.4
G1 E.8 F1800
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X155.356 Y131.348 E.30696
G1 X154.375 Y131.348 E.03254
G1 X147.68 Y124.652 E.31408
G1 X146.699 Y124.652 E.03254
G1 X137.515 Y133.836 E.43084
G1 X133.836 Y133.836 E.12204
G1 X122.164 Y122.164 E.5476
G1 X118.484 Y122.164 E.12204
G1 X106.812 Y133.836 E.5476
G1 X103.133 Y133.836 E.12204
G1 X93.949 Y124.652 E.43084
G1 X92.968 Y124.652 E.03254
G1 X86.273 Y131.348 E.31408
G1 X86.1 Y131.348 E.00572
G1 X86.1 Y124.652 E.22209
G1 X86.273 Y124.652 E.00572
G1 X92.968 Y131.348 E.31408
G1 X93.949 Y131.348 E.03254
G1 X103.133 Y122.164 E.43084
G1 X106.812 Y122.164 E.12204
G1 X118.485 Y133.836 E.5476
G1 X122.164 Y133.836 E.12204
G1 X133.836 Y122.164 E.5476
G1 X137.515 Y122.164 E.12204
G1 X146.699 Y131.348 E.43084
G1 X147.68 Y131.348 E.03254
G1 X154.375 Y124.652 E.31408
G1 X155.356 Y124.652 E.03254
G1 X161.9 Y131.196 E.30696
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.208 E.05401
G1 X160.514 Y131.759 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.36762
G1 F12000
G1 X160.514 Y132.038 E.00738
G1 X145.636 Y132.038 E.39365
G1 X145.662 Y131.729 E.0082
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.663 Y131.713 E.00042
G1 X160.471 Y131.717 E.39182
; Slow Down End
G1 X161.796 Y125.836 F36000
; LINE_WIDTH: 0.5392
G1 F12000
G1 X161.796 Y126.536 E.02832
G1 X161.796 Y130.164 F36000
G1 F12000
G1 X161.796 Y129.507 E.02657
G1 X169.856 Y128 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X169.856 Y126.741 E.03868
G1 X162.044 Y126.741 E.24002
; LINE_WIDTH: 0.440489
G1 X161.962 Y126.693 E.00309
; LINE_WIDTH: 0.481485
G1 X161.88 Y126.644 E.00341
; LINE_WIDTH: 0.522482
G1 X161.798 Y126.596 E.00372
G1 X161.778 Y126.747 E.00596
; LINE_WIDTH: 0.481485
G1 X161.757 Y126.898 E.00545
; LINE_WIDTH: 0.421511
G1 X161.737 Y127.049 E.0047
G1 X161.737 Y128.951 E.05868
; LINE_WIDTH: 0.439859
G1 X161.757 Y129.117 E.00539
; LINE_WIDTH: 0.479595
G1 X161.776 Y129.282 E.00593
; LINE_WIDTH: 0.519332
G1 X161.796 Y129.447 E.00647
G1 X161.879 Y129.385 E.00403
; LINE_WIDTH: 0.479595
G1 X161.962 Y129.322 E.0037
; LINE_WIDTH: 0.420217
G1 X162.044 Y129.259 E.00319
G1 X169.856 Y129.259 E.24016
G1 X169.856 Y128.06 E.03686
G1 X169.479 Y128 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X169.479 Y127.118 E.02709
G1 X162.114 Y127.118 E.2263
G1 X162.114 Y128.882 E.05419
G1 X169.479 Y128.882 E.2263
G1 X169.479 Y128.06 E.02525
G1 X169.102 Y128 F36000
G1 F12000
G1 X169.102 Y127.495 E.01551
G1 X162.491 Y127.495 E.20313
G1 X162.491 Y128.505 E.03102
G1 X169.102 Y128.505 E.20313
G1 X169.102 Y128.06 E.01366
G1 X168.755 Y128 F36000
; LINE_WIDTH: 0.3591
G1 F12000
G1 X168.755 Y127.842 E.00407
G1 X162.837 Y127.842 E.15247
G1 X162.837 Y128.158 E.00815
G1 X168.755 Y128.158 E.15247
G1 X168.755 Y128.06 E.00253
; WIPE_START
G1 X168.755 Y128.158 E-.03728
G1 X166.853 Y128.158 E-.72272
; WIPE_END
G1 E-.04 F1800
G1 X159.228 Y127.835 Z3.8 F36000
G1 X109.369 Y125.721 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X107.897 Y125.075 I-1.912 J2.36 E.05396
G1 X110.809 Y122.164 E.13659
G1 X114.488 Y122.164 E.12204
G1 X126.16 Y133.836 E.5476
G1 X129.84 Y133.836 E.12204
G1 X134.715 Y128.961 E.22872
G3 X134.715 Y127.04 I3.171 J-.96 E.06467
G1 X129.84 Y122.164 E.22874
G1 X126.16 Y122.164 E.12204
G1 X114.488 Y133.836 E.5476
G1 X110.809 Y133.836 E.12204
G1 X107.897 Y130.925 E.13659
G2 X109.369 Y130.279 I-.44 J-3.006 E.05396
; WIPE_START
G1 X108.63 Y130.728 E-.3285
G1 X107.897 Y130.925 E-.2884
G1 X108.163 Y131.191 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X100.547 Y131.683 Z3.8 F36000
G1 X99.364 Y131.759 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.367625
G1 F12000
G1 X99.364 Y132.038 E.00738
G1 X86.118 Y132.038 E.35048
G1 X86.118 Y131.729 E.00817
; Slow Down Start
; LINE_WIDTH: 0.367625
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.118 Y131.713 E.00042
G1 X99.321 Y131.717 E.34935
; Slow Down End
G1 X99.724 Y134.259 F36000
; LINE_WIDTH: 0.48044
G1 F12000
G1 X145.216 Y134.259 E1.62187
; WIPE_START
G1 X143.216 Y134.259 E-.76
; WIPE_END
G1 E-.04 F1800
M73 P71 R4
G1 X135.777 Y132.551 Z3.8 F36000
G1 X99.73 Y124.274 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.73 Y123.699 E.01906
G1 X99.65 Y123.62 E.00372
G1 X99.65 Y122.678 E.03123
G1 X104.575 Y127.603 E.23104
G2 X104.575 Y128.397 I31.825 J.397 E.02633
G1 X99.65 Y133.322 E.23104
G1 X99.65 Y132.38 E.03123
G1 X99.73 Y132.301 E.00372
G1 X99.73 Y131.726 E.01906
G1 X99.724 Y121.741 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.48044
G1 F12000
G1 X145.216 Y121.741 E1.62187
G1 X86.118 Y124.287 F36000
; Slow Down Start
; LINE_WIDTH: 0.36762
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.118 Y124.271 E.00042
; Slow Down End
G1 F12000
G1 X86.118 Y123.962 E.00817
G1 X99.364 Y123.962 E.35047
G3 X99.34 Y124.271 I-.949 J.081 E.00823
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X99.337 Y124.287 E.00043
; Slow Down End
G1 F12000
G1 X86.178 Y124.287 E.34818
; CHANGE_LAYER
; Z_HEIGHT: 3.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X88.178 Y124.287 E-.76
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
G1 X135.422 Y129.565
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.246 Y129.302 E.01052
G3 X137.16 Y125.419 I2.25 J-1.304 E.16965
G1 X137.491 Y125.397 E.01101
G3 X135.458 Y129.613 I.004 J2.6 E.34881
G1 X135.747 Y129.345 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.211 Y125.808 I1.749 J-1.347 E.14233
G1 X137.492 Y125.79 E.00864
G3 X135.784 Y129.392 I.004 J2.208 E.27346
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13257
G1 X135.458 Y128.846 E-.10986
G1 X135.365 Y128.572 E-.10988
G1 X135.308 Y128.289 E-.10988
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10987
G1 X135.349 Y127.51 E-.07805
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.098 Z4 F36000
G1 X105.935 Y125.922 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.198 Y125.744 E.01052
G3 X107.16 Y125.419 I1.298 J2.253 E.03392
G1 X107.491 Y125.397 E.01101
G3 X105.885 Y125.956 I.004 J2.6 E.48454
M73 P72 R4
G1 X106.153 Y126.245 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.211 Y125.808 I1.342 J1.753 E.03557
G1 X107.492 Y125.79 E.00864
G3 X106.106 Y126.282 I.004 J2.208 E.38022
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13259
G1 X106.654 Y125.958 E-.10986
G1 X106.928 Y125.865 E-.10988
G1 X107.211 Y125.808 E-.10985
G1 X107.492 Y125.79 E-.10684
G1 X107.788 Y125.808 E-.11277
G1 X107.99 Y125.849 E-.07821
; WIPE_END
G1 E-.04 F1800
G1 X115.61 Y125.421 Z4 F36000
G1 X145.698 Y123.731 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y123.731 E.48942
G1 X160.452 Y119.235 E.14914
G1 X162.248 Y119.235 E.05957
G1 X162.248 Y126.674 E.24677
G1 X170.248 Y126.674 E.26537
G1 X170.248 Y129.326 E.08795
G1 X162.248 Y129.326 E.26537
G1 X162.248 Y136.765 E.24677
G1 X160.452 Y136.765 E.05957
G1 X160.452 Y132.269 E.14914
G1 X145.698 Y132.269 E.48942
G1 X145.698 Y134.59 E.07701
G1 X99.302 Y134.59 E1.53904
G1 X99.302 Y132.269 E.07701
G1 X85.752 Y132.269 E.44948
G1 X85.752 Y123.731 E.28321
G1 X99.302 Y123.731 E.44948
G1 X99.302 Y121.41 E.07701
G1 X145.698 Y121.41 E1.53904
G1 X145.698 Y123.671 E.07502
G1 X146.09 Y123.339 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y123.339 E.42926
G1 X160.06 Y118.843 E.13815
G1 X162.64 Y118.843 E.07928
G1 X162.64 Y126.282 E.22858
G1 X170.64 Y126.282 E.24582
G1 X170.64 Y129.718 E.10556
G1 X162.64 Y129.718 E.24582
G1 X162.64 Y137.157 E.22858
G1 X160.06 Y137.157 E.07928
G1 X160.06 Y132.661 E.13815
G1 X146.09 Y132.661 E.42926
G1 X146.09 Y134.982 E.07133
G1 X98.91 Y134.982 E1.44971
G1 X98.91 Y132.661 E.07133
G1 X85.36 Y132.661 E.41635
G1 X85.36 Y123.339 E.28643
G1 X98.91 Y123.339 E.41635
G1 X98.91 Y121.018 E.07133
G1 X146.09 Y121.018 E1.44971
G1 X146.09 Y123.279 E.06949
M204 S10000
G1 X145.652 Y124.113 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39953
G1 F12000
G1 X160.498 Y124.113 E.43141
G3 X160.482 Y124.449 I-1.727 J.089 E.00979
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X160.48 Y124.47 E.0006
G1 X145.67 Y124.47 E.43039
G1 X145.669 Y124.449 E.0006
; Slow Down End
G1 F12000
G1 X145.655 Y124.173 E.00803
G1 X143.687 Y122.288 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X145.316 Y122.288 E.05401
G1 X145.35 Y123.755 E.04867
G2 X145.27 Y123.917 I.042 J.121 E.00666
G1 X145.27 Y132.083 F36000
G1 F15476.087
G2 X145.35 Y132.245 I.121 J.042 E.00666
G1 X145.316 Y133.712 E.04867
G1 X143.687 Y133.712 E.05401
; WIPE_START
G1 X145.316 Y133.712 E-.61876
G1 X145.324 Y133.34 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X152.905 Y132.451 Z4 F36000
G1 X160.498 Y131.56 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39954
G1 F12000
G1 X160.498 Y131.887 E.0095
G1 X145.652 Y131.887 E.43142
G1 X145.669 Y131.551 E.00977
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.67 Y131.53 E.0006
G1 X160.45 Y131.53 E.42953
; Slow Down End
G1 X160.8 Y135.208 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X155.555 Y124.851 E.29764
G1 X154.177 Y124.851 E.04573
G1 X147.879 Y131.149 E.29542
G1 X146.501 Y131.149 E.04573
G1 X137.64 Y122.288 E.41567
G1 X141.388 Y122.288 E.12433
G1 X138.461 Y125.215 E.13732
G3 X138.461 Y130.785 I-.989 J2.785 E.24107
G1 X141.388 Y133.712 E.13732
G1 X137.64 Y133.712 E.12433
G1 X146.501 Y124.851 E.41568
G1 X147.879 Y124.851 E.04573
G1 X154.177 Y131.149 E.29542
G1 X155.555 Y131.149 E.04573
G1 X161.9 Y124.804 E.29764
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
G1 X161.796 Y125.836 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53921
G1 F12000
G1 X161.796 Y126.861 E.04147
G1 X161.796 Y130.164 F36000
G1 F12000
G1 X161.796 Y129.182 E.03972
G1 X169.856 Y128 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X169.856 Y127.066 E.02869
G1 X162.044 Y127.066 E.24002
; LINE_WIDTH: 0.440489
G1 X161.962 Y127.018 E.00309
; LINE_WIDTH: 0.481485
G1 X161.88 Y126.969 E.00341
; LINE_WIDTH: 0.522482
G1 X161.798 Y126.921 E.00372
G1 X161.778 Y127.072 E.00596
; LINE_WIDTH: 0.481485
G1 X161.757 Y127.223 E.00545
; LINE_WIDTH: 0.422215
G1 X161.737 Y127.374 E.00471
G1 X161.737 Y128.626 E.03869
; LINE_WIDTH: 0.439859
G1 X161.757 Y128.791 E.00539
; LINE_WIDTH: 0.479595
G1 X161.776 Y128.957 E.00593
; LINE_WIDTH: 0.519332
G1 X161.796 Y129.122 E.00647
G1 X161.879 Y129.059 E.00403
; LINE_WIDTH: 0.479595
G1 X161.962 Y128.996 E.0037
; LINE_WIDTH: 0.420225
G1 X162.044 Y128.934 E.00319
G1 X169.856 Y128.934 E.24017
G1 X169.856 Y128.06 E.02686
G1 X169.479 Y128 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X169.479 Y127.443 E.0171
G1 X162.114 Y127.443 E.2263
G1 X162.114 Y128.557 E.0342
G1 X169.479 Y128.557 E.2263
G1 X169.479 Y128.06 E.01526
G1 X169.106 Y128 F36000
; LINE_WIDTH: 0.41095
G1 F12000
G1 X169.106 Y127.816 E.00552
G1 X162.486 Y127.816 E.19853
G1 X162.486 Y128.184 E.01104
G1 X169.106 Y128.184 E.19853
G1 X169.106 Y128.06 E.00372
; WIPE_START
G1 X169.106 Y128.184 E-.04713
G1 X167.23 Y128.184 E-.71287
; WIPE_END
G1 E-.04 F1800
G1 X159.605 Y127.859 Z4 F36000
G1 X109.369 Y125.721 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X107.897 Y125.075 I-1.912 J2.36 E.05396
G1 X110.684 Y122.288 E.13076
G1 X106.936 Y122.288 E.12433
G1 X118.36 Y133.712 E.53593
G1 X114.612 Y133.712 E.12433
G1 X126.036 Y122.288 E.53593
G1 X122.288 Y122.288 E.12433
G1 X133.712 Y133.712 E.53593
G1 X129.964 Y133.712 E.12433
G1 X134.715 Y128.961 E.22289
G3 X134.715 Y127.039 I3.177 J-.961 E.06468
G1 X129.964 Y122.288 E.22288
G1 X133.712 Y122.288 E.12433
G1 X122.288 Y133.712 E.53593
G1 X126.036 Y133.712 E.12433
G1 X114.612 Y122.288 E.53593
G1 X118.36 Y122.288 E.12433
G1 X106.936 Y133.712 E.53593
G1 X110.684 Y133.712 E.12433
G1 X107.897 Y130.925 E.13076
G2 X109.369 Y130.279 I-.44 J-3.006 E.05396
; WIPE_START
G1 X108.63 Y130.728 E-.3285
G1 X107.897 Y130.925 E-.2884
G1 X108.163 Y131.191 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X100.537 Y131.51 Z4 F36000
G1 X99.348 Y131.56 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39954
G1 F12000
G1 X99.348 Y131.887 E.0095
G1 X86.134 Y131.887 E.384
G1 X86.134 Y131.551 E.00976
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.134 Y131.53 E.0006
G1 X99.3 Y131.53 E.38261
; Slow Down End
G1 X99.741 Y134.151 F36000
; LINE_WIDTH: 0.51419
G1 F12000
G1 X145.199 Y134.151 E1.74569
G1 X99.741 Y121.849 F36000
G1 F12000
G1 X145.199 Y121.849 E1.74569
G1 X86.134 Y124.47 F36000
; Slow Down Start
; LINE_WIDTH: 0.39953
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.134 Y124.449 E.0006
; Slow Down End
G1 F12000
G1 X86.134 Y124.113 E.00976
G1 X99.348 Y124.113 E.38399
G3 X99.332 Y124.449 I-1.727 J.089 E.00979
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X99.33 Y124.47 E.0006
; Slow Down End
G1 F12000
G1 X86.194 Y124.47 E.38174
G1 X86.1 Y126.108 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.1 Y124.851 E.0417
G1 X86.472 Y124.851 E.01231
G1 X92.769 Y131.149 E.29542
G1 X94.147 Y131.149 E.04573
G1 X103.008 Y122.288 E.41567
G1 X99.65 Y122.288 E.11139
G1 X99.65 Y122.678 E.01294
G1 X104.575 Y127.603 E.23104
G2 X104.575 Y128.397 I57.075 J.397 E.02633
G1 X99.65 Y133.322 E.23104
G1 X99.65 Y133.712 E.01295
G1 X103.008 Y133.712 E.11139
G1 X94.148 Y124.851 E.41568
G1 X92.769 Y124.851 E.04573
G1 X86.472 Y131.149 E.29542
G1 X88.1 Y131.149 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 3.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X86.472 Y131.149 E-.61876
G1 X86.734 Y130.886 E-.14124
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
G1 X135.45 Y129.602
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X135.443 Y129.578 E.00083
G3 X137.438 Y125.401 I2.065 J-1.579 E.18941
G3 X138.496 Y125.595 I.08 J2.548 E.03597
G3 X135.666 Y129.834 I-.988 J2.405 E.30524
G1 X135.491 Y129.646 E.00852
G1 X135.754 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.463 Y125.792 I1.754 J-1.341 E.14947
G3 X138.072 Y125.865 I-.014 J2.699 E.01888
G3 X135.791 Y129.387 I-.564 J2.134 E.25604
; WIPE_START
M204 S10000
G1 X135.606 Y129.136 E-.11852
G1 X135.458 Y128.846 E-.12376
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07823
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z4.2 F36000
G1 X105.898 Y125.95 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.917 Y125.937 E.00077
G3 X107.438 Y125.401 I1.582 J2.064 E.05439
G3 X107.901 Y130.569 I.062 J2.599 E.25967
G3 X105.661 Y126.161 I-.403 J-2.569 E.21666
G1 X105.853 Y125.99 E.00853
G1 X106.158 Y126.252 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.463 Y125.792 I1.349 J1.748 E.04324
M73 P73 R4
G3 X108.072 Y125.865 I-.014 J2.699 E.01888
G3 X106.111 Y126.289 I-.565 J2.135 E.3624
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13248
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10986
G1 X107.211 Y125.808 E-.10986
G1 X107.463 Y125.792 E-.09589
G1 X107.789 Y125.808 E-.12378
G1 X107.99 Y125.849 E-.07825
; WIPE_END
G1 E-.04 F1800
G1 X115.613 Y125.451 Z4.2 F36000
G1 X145.698 Y123.884 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y123.884 E.48942
G1 X160.452 Y119.316 E.15151
G1 X162.248 Y119.316 E.05957
G1 X162.248 Y127.089 E.25785
G1 X170.248 Y127.089 E.26537
G1 X170.248 Y128.911 E.06041
G1 X162.248 Y128.911 E.26537
G1 X162.248 Y136.684 E.25785
G1 X160.452 Y136.684 E.05957
G1 X160.452 Y132.116 E.15151
G1 X145.698 Y132.116 E.48942
G1 X145.698 Y134.487 E.07862
G1 X99.302 Y134.487 E1.53904
G1 X99.302 Y132.116 E.07862
G1 X85.752 Y132.116 E.44948
G1 X85.752 Y123.884 E.2731
G1 X99.302 Y123.884 E.44948
G1 X99.302 Y121.514 E.07862
G1 X145.698 Y121.514 E1.53904
G1 X145.698 Y123.824 E.07663
G1 X146.09 Y123.492 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y123.492 E.42926
G1 X160.06 Y118.924 E.14034
G1 X162.64 Y118.924 E.07928
G1 X162.64 Y126.697 E.23885
G1 X170.64 Y126.697 E.24582
G1 X170.64 Y129.303 E.08006
G1 X162.64 Y129.303 E.24582
G1 X162.64 Y137.076 E.23885
G1 X160.06 Y137.076 E.07928
G1 X160.06 Y132.508 E.14034
G1 X146.09 Y132.508 E.42926
G1 X146.09 Y134.879 E.07283
G1 X98.91 Y134.879 E1.44971
G1 X98.91 Y132.508 E.07283
G1 X85.36 Y132.508 E.41635
G1 X85.36 Y123.492 E.27707
G1 X98.91 Y123.492 E.41635
G1 X98.91 Y121.121 E.07283
G1 X146.09 Y121.121 E1.44971
G1 X146.09 Y123.432 E.07098
M204 S10000
G1 X145.667 Y124.28 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.429005
G1 F12000
G1 X160.483 Y124.28 E.46614
G3 X160.475 Y124.648 I-4.041 J.097 E.01157
; Slow Down Start
; LINE_WIDTH: 0.429005
G1 F3000;_EXTRUDE_SET_SPEED
G1 X160.474 Y124.666 E.00058
G1 X145.682 Y124.666 E.46539
G1 X145.681 Y124.648 E.00058
; Slow Down End
; LINE_WIDTH: 0.42901
G1 F12000
G1 X145.669 Y124.34 E.00969
; WIPE_START
G1 X145.681 Y124.648 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.077 Y122.762 Z4.2 F36000
G1 X160.8 Y120.792 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X155.767 Y130.937 E.28772
G1 X153.965 Y130.937 E.05976
G1 X148.091 Y125.063 E.27559
G1 X146.289 Y125.063 E.05976
G1 X137.769 Y133.582 E.39968
G1 X141.258 Y133.582 E.11573
G1 X138.461 Y130.785 E.13124
G2 X138.461 Y125.215 I-.989 J-2.785 E.24107
G1 X141.258 Y122.418 E.13123
G1 X137.769 Y122.418 E.11573
G1 X146.289 Y130.937 E.39968
G1 X148.091 Y130.937 E.05976
G1 X153.965 Y125.063 E.27559
G1 X155.767 Y125.063 E.05976
G1 X161.9 Y131.196 E.28772
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.208 E.05401
G1 X160.483 Y131.72 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.42901
G1 F12000
G1 X145.667 Y131.72 E.46614
G1 X145.675 Y131.352 E.01157
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.676 Y131.334 E.00058
G1 X160.29 Y131.334 E.45979
; Slow Down End
G1 F12000
G1 X160.483 Y131.349 E.00609
G1 X160.483 Y131.66 E.00979
G1 X161.796 Y125.836 F36000
; LINE_WIDTH: 0.5392
G1 F12000
G1 X161.796 Y127.276 E.05826
G1 X161.796 Y130.164 F36000
G1 F12000
G1 X161.796 Y128.767 E.05651
G1 X169.856 Y128 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X169.856 Y127.481 E.01593
G1 X162.044 Y127.481 E.24002
; LINE_WIDTH: 0.440489
G1 X161.962 Y127.433 E.00309
; LINE_WIDTH: 0.481485
G1 X161.88 Y127.385 E.00341
; LINE_WIDTH: 0.522482
G1 X161.798 Y127.336 E.00372
G1 X161.778 Y127.557 E.00869
; LINE_WIDTH: 0.481485
G1 X161.757 Y127.779 E.00794
; LINE_WIDTH: 0.440489
G1 X161.737 Y128 E.0072
; LINE_WIDTH: 0.439859
G1 X161.757 Y128.236 E.00765
; LINE_WIDTH: 0.479595
G1 X161.776 Y128.471 E.00842
; LINE_WIDTH: 0.519332
G1 X161.796 Y128.707 E.00918
G1 X161.879 Y128.644 E.00403
; LINE_WIDTH: 0.479595
G1 X161.962 Y128.581 E.0037
; LINE_WIDTH: 0.420237
G1 X162.044 Y128.519 E.00319
G1 X169.856 Y128.519 E.24018
G1 X169.856 Y128.06 E.0141
G1 X169.502 Y128 F36000
; LINE_WIDTH: 0.37292
G1 F12000
G1 X169.502 Y127.835 E.00444
G1 X162.09 Y127.835 E.19932
G1 X162.09 Y128.165 E.00887
G1 X169.502 Y128.165 E.19932
G1 X169.502 Y128.06 E.00282
; WIPE_START
G1 X169.502 Y128.165 E-.0399
G1 X167.607 Y128.165 E-.7201
; WIPE_END
G1 E-.04 F1800
G1 X159.98 Y128.442 Z4.2 F36000
G1 X109.369 Y130.279 Z4.2
G1 Z3.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X107.897 Y130.925 I-1.912 J-2.36 E.05396
G1 X110.555 Y133.582 E.12468
G1 X107.066 Y133.582 E.11573
G1 X118.231 Y122.418 E.52377
G1 X114.742 Y122.418 E.11573
G1 X125.906 Y133.582 E.52377
G1 X122.418 Y133.582 E.11573
G1 X133.582 Y122.418 E.52377
G1 X130.094 Y122.418 E.11573
G1 X134.715 Y127.039 E.2168
G2 X134.715 Y128.961 I3.177 J.961 E.06468
G1 X130.094 Y133.582 E.21681
G1 X133.582 Y133.582 E.11573
G1 X122.418 Y122.418 E.52377
G1 X125.906 Y122.418 E.11573
G1 X114.742 Y133.582 E.52377
G1 X118.231 Y133.582 E.11573
G1 X107.066 Y122.418 E.52377
G1 X110.555 Y122.418 E.11573
G1 X107.897 Y125.075 E.12467
G3 X109.369 Y125.721 I-.44 J3.005 E.05396
G1 X99.754 Y121.966 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54003
G1 F12000
G1 X145.186 Y121.966 E1.84036
; WIPE_START
G1 X143.186 Y121.966 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.735 Y123.623 Z4.2 F36000
G1 X99.333 Y131.72 Z4.2
G1 Z3.8
G1 E.8 F1800
; LINE_WIDTH: 0.42901
G1 F12000
G1 X86.149 Y131.72 E.4148
G1 X86.149 Y131.352 E.01157
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.149 Y131.334 E.00058
G1 X99.14 Y131.334 E.40873
; Slow Down End
G1 F12000
G1 X99.333 Y131.349 E.00609
G1 X99.333 Y131.66 E.00979
G1 X99.754 Y134.034 F36000
; LINE_WIDTH: 0.54002
G1 F12000
G1 X145.186 Y134.034 E1.84032
G1 X88.311 Y130.937 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.683 Y130.937 E.05401
G1 X92.557 Y125.063 E.27559
G1 X94.359 Y125.063 E.05976
G1 X102.879 Y133.582 E.39968
G1 X99.65 Y133.582 E.10709
G1 X99.65 Y133.322 E.00865
G1 X104.575 Y128.397 E.23104
G3 X104.575 Y127.603 I34.174 J-.397 E.02633
G1 X99.65 Y122.678 E.23104
G1 X99.65 Y122.418 E.00864
G1 X102.879 Y122.418 E.10709
G1 X94.359 Y130.937 E.39968
G1 X92.557 Y130.937 E.05976
G1 X86.683 Y125.063 E.27559
G1 X86.1 Y125.063 E.01933
G1 X86.1 Y126.108 E.03469
G1 X86.149 Y124.666 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.42901
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.149 Y124.648 E.00058
; Slow Down End
; LINE_WIDTH: 0.429005
G1 F12000
G1 X86.149 Y124.28 E.01157
G1 X99.333 Y124.28 E.4148
G3 X99.325 Y124.648 I-4.041 J.097 E.01157
; Slow Down Start
; LINE_WIDTH: 0.429005
G1 F3000;_EXTRUDE_SET_SPEED
G1 X99.324 Y124.666 E.00058
; Slow Down End
G1 F12000
G1 X86.209 Y124.666 E.41263
; CHANGE_LAYER
; Z_HEIGHT: 4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X88.209 Y124.666 E-.76
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
G1 X135.45 Y129.602
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.439 Y129.582 E.00078
G3 X137.422 Y125.402 I2.063 J-1.582 E.18922
G3 X136.903 Y130.53 I.076 J2.598 E.29335
G3 X135.663 Y129.837 I.599 J-2.53 E.04772
G1 X135.49 Y129.647 E.00852
G1 X135.753 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.448 Y125.793 I1.754 J-1.341 E.149
G3 X138.346 Y125.958 I.067 J2.163 E.02827
G3 X135.79 Y129.387 I-.839 J2.042 E.24708
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13246
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07814
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.098 Z4.4 F36000
G1 X105.935 Y125.922 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.201 Y125.75 E.01051
G3 X107.422 Y125.402 I1.301 J2.251 E.04257
G3 X106.903 Y130.53 I.078 J2.598 E.29347
G3 X105.89 Y125.961 I.599 J-2.53 E.19316
G1 X106.159 Y126.252 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.448 Y125.793 I1.348 J1.748 E.04275
G3 X108.346 Y125.958 I.067 J2.163 E.02827
G3 X106.112 Y126.289 I-.839 J2.042 E.35333
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13247
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10985
G1 X107.211 Y125.808 E-.10988
G1 X107.448 Y125.793 E-.09004
G1 X107.789 Y125.808 E-.12958
G1 X107.991 Y125.849 E-.07829
; WIPE_END
G1 E-.04 F1800
G1 X115.614 Y125.484 Z4.4 F36000
G1 X145.698 Y124.047 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y124.047 E.48942
G1 X160.452 Y119.397 E.15423
G1 X162.248 Y119.397 E.05957
G1 X162.248 Y125.812 E.21277
G1 X161.772 Y125.812 E.01578
G1 X161.772 Y130.188 E.14519
M73 P74 R4
G1 X162.248 Y130.188 E.01578
G1 X162.248 Y136.603 E.21277
G1 X160.452 Y136.603 E.05957
G1 X160.452 Y131.953 E.15423
G1 X145.698 Y131.953 E.48942
G1 X145.698 Y134.38 E.08048
G1 X99.302 Y134.38 E1.53904
G1 X99.302 Y131.953 E.08048
G1 X85.752 Y131.953 E.44948
G1 X85.752 Y124.047 E.26228
G1 X99.302 Y124.047 E.44948
G1 X99.302 Y121.62 E.08048
G1 X145.698 Y121.62 E1.53904
G1 X145.698 Y123.987 E.07849
G1 X146.09 Y123.655 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y123.655 E.42926
G1 X160.06 Y119.005 E.14286
G1 X162.64 Y119.005 E.07928
G1 X162.64 Y127.339 E.25608
G1 X170.64 Y127.339 E.24582
G1 X170.64 Y128.661 E.0406
G1 X162.64 Y128.661 E.24582
G1 X162.64 Y136.995 E.25608
G1 X160.06 Y136.995 E.07928
G1 X160.06 Y132.345 E.14286
G1 X146.09 Y132.345 E.42926
G1 X146.09 Y134.772 E.07455
G1 X98.91 Y134.772 E1.44971
G1 X98.91 Y132.345 E.07455
G1 X85.36 Y132.345 E.41635
G1 X85.36 Y123.655 E.26704
G1 X98.91 Y123.655 E.41635
G1 X98.91 Y121.228 E.07455
G1 X146.09 Y121.228 E1.44971
G1 X146.09 Y123.595 E.07271
; WIPE_START
M204 S10000
G1 X148.09 Y123.603 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.694 Y124.263 Z4.4 F36000
G1 X160.463 Y124.676 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.468715
G1 F12000
G1 X160.463 Y124.463 E.00739
G1 X145.687 Y124.463 E.5127
G1 X145.687 Y124.889 E.01477
G1 X160.463 Y124.889 E.5127
G1 X160.463 Y124.736 E.00531
; WIPE_START
G1 X160.463 Y124.889 E-.0581
G1 X158.616 Y124.889 E-.7019
; WIPE_END
G1 E-.04 F1800
G1 X162.238 Y129.702 Z4.4 F36000
G1 Z4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50814
G1 F13541.982
G2 X162.236 Y129.803 I-.029 J.05 E.0091
; WIPE_START
G1 X162.179 Y129.803 E-.18544
G1 X162.15 Y129.752 E-.19152
G1 X162.179 Y129.702 E-.19154
G1 X162.238 Y129.702 E-.1915
; WIPE_END
G1 E-.04 F1800
G1 X160.463 Y131.537 Z4.4 F36000
G1 Z4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.46871
G1 F12000
G1 X145.687 Y131.537 E.5127
G1 X145.687 Y131.141 E.01374
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.687 Y131.111 E.00103
; Slow Down End
G1 F12000
G1 X160.463 Y131.111 E.5127
G1 X160.463 Y131.477 E.01269
G1 X160.8 Y131.951 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X156.009 Y125.305 E.27634
G1 X153.723 Y125.305 E.07585
G1 X148.333 Y130.695 E.25283
G1 X146.047 Y130.695 E.07584
G1 X137.913 Y122.561 E.38158
G1 X141.115 Y122.561 E.10623
G1 X138.461 Y125.215 E.12451
G3 X138.461 Y130.785 I-.989 J2.785 E.24107
G1 X141.115 Y133.439 E.12451
G1 X137.913 Y133.439 E.10623
G1 X146.047 Y125.305 E.38158
G1 X148.333 Y125.305 E.07585
G1 X153.723 Y130.695 E.25283
G1 X156.009 Y130.695 E.07584
G1 X161.9 Y124.804 E.27634
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y124.049 E.05401
; WIPE_START
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X167.713 Y126.429 Z4.4 F36000
G1 X170.433 Y127.961 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X169.941 Y128.453 E.02138
G1 X169.407 Y128.453
G1 X170.314 Y127.547 E.03939
G1 X169.781 Y127.547
G1 X168.874 Y128.453 E.03939
G1 X168.341 Y128.453
G1 X169.247 Y127.547 E.03939
G1 X168.714 Y127.547
G1 X167.808 Y128.453 E.03939
G1 X167.274 Y128.453
G1 X168.181 Y127.547 E.03939
G1 X167.648 Y127.547
G1 X166.741 Y128.453 E.03939
G1 X166.208 Y128.453
G1 X167.114 Y127.547 E.03939
G1 X166.581 Y127.547
G1 X165.675 Y128.453 E.03939
G1 X165.141 Y128.453
G1 X166.048 Y127.547 E.03939
G1 X165.515 Y127.547
G1 X164.608 Y128.453 E.03939
G1 X164.075 Y128.453
G1 X164.981 Y127.547 E.03939
G1 X164.448 Y127.547
G1 X163.542 Y128.453 E.03939
G1 X163.008 Y128.453
G1 X163.915 Y127.547 E.03939
G1 X163.382 Y127.547
G1 X162.475 Y128.453 E.03939
G1 X162.433 Y129.029
G1 X162.047 Y129.415 E.01676
G1 X161.995 Y128.934
G1 X162.433 Y128.496 E.01903
G1 X161.995 Y128.4
G1 X162.848 Y127.547 E.03709
G1 X162.433 Y127.429
G1 X161.995 Y127.867 E.01903
G1 X161.995 Y127.334
G1 X162.433 Y126.896 E.01903
M204 S10000
G1 X162.451 Y126.833 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.238378
G1 F15000
G1 X162.405 Y126.763 E.00134
; LINE_WIDTH: 0.272571
G1 X162.358 Y126.693 E.00158
; LINE_WIDTH: 0.316582
G1 X162.306 Y126.623 E.00195
G2 X162.198 Y126.661 I.008 J.195 E.0026
; LINE_WIDTH: 0.344139
G1 X161.976 Y126.814 E.00662
; WIPE_START
G1 X162.198 Y126.661 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.566 Y126.525 Z4.4 F36000
G1 X109.369 Y125.721 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X107.897 Y125.075 I-1.912 J2.36 E.05396
G1 X110.411 Y122.561 E.11795
G1 X107.209 Y122.561 E.10622
G1 X118.087 Y133.439 E.51032
G1 X114.885 Y133.439 E.10623
G1 X125.763 Y122.561 E.51032
G1 X122.561 Y122.561 E.10623
G1 X133.439 Y133.439 E.51032
G1 X130.237 Y133.439 E.10623
G1 X134.715 Y128.961 E.21008
G3 X134.715 Y127.039 I3.177 J-.961 E.06468
G1 X130.237 Y122.561 E.21008
G1 X133.439 Y122.561 E.10623
G1 X122.561 Y133.439 E.51032
G1 X125.763 Y133.439 E.10623
G1 X114.885 Y122.561 E.51032
G1 X118.087 Y122.561 E.10622
G1 X107.209 Y133.439 E.51032
G1 X110.411 Y133.439 E.10623
G1 X107.897 Y130.925 E.11795
G2 X109.369 Y130.279 I-.44 J-3.006 E.05396
; WIPE_START
G1 X108.63 Y130.728 E-.3285
G1 X107.897 Y130.925 E-.28839
G1 X108.163 Y131.191 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X100.537 Y131.489 Z4.4 F36000
G1 X99.313 Y131.537 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.46871
G1 F12000
G1 X86.168 Y131.537 E.45608
G1 X86.168 Y131.141 E.01374
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.168 Y131.111 E.00103
; Slow Down End
G1 F12000
G1 X99.313 Y131.111 E.45608
G1 X99.313 Y131.477 E.01269
G1 X99.772 Y133.909 F36000
; LINE_WIDTH: 0.57642
G1 F11808.809
G1 X145.168 Y133.909 E1.97349
; WIPE_START
G1 X143.168 Y133.909 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.699 Y132.337 Z4.4 F36000
G1 X99.313 Y124.676 Z4.4
G1 Z4
G1 E.8 F1800
; LINE_WIDTH: 0.468715
G1 F12000
G1 X99.313 Y124.463 E.00739
G1 X86.168 Y124.463 E.45608
G1 X86.168 Y124.889 E.01477
G1 X99.313 Y124.889 E.45608
G1 X99.313 Y124.736 E.00531
G1 X99.772 Y122.091 F36000
; LINE_WIDTH: 0.57644
G1 F11808.367
G1 X145.168 Y122.091 E1.97357
G1 X86.1 Y126.108 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.1 Y125.305 E.02664
G1 X86.925 Y125.305 E.02737
G1 X92.315 Y130.695 E.25283
G1 X94.601 Y130.695 E.07584
G1 X102.735 Y122.561 E.38158
G1 X99.65 Y122.561 E.10233
G1 X99.65 Y122.678 E.00389
G1 X104.575 Y127.603 E.23104
G2 X104.575 Y128.397 I34.322 J.396 E.02633
G1 X99.65 Y133.322 E.23104
G1 X99.65 Y133.439 E.00389
G1 X102.735 Y133.439 E.10233
G1 X94.601 Y125.305 E.38158
G1 X92.315 Y125.305 E.07585
G1 X86.925 Y130.695 E.25283
G1 X86.1 Y130.695 E.02737
G1 X86.1 Y129.892 E.02664
; CHANGE_LAYER
; Z_HEIGHT: 4.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X86.1 Y130.695 E-.30522
G1 X86.925 Y130.695 E-.31354
G1 X87.188 Y130.432 E-.14124
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
G1 X135.422 Y129.565
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X135.253 Y129.297 E.0105
G3 X137.407 Y125.403 I2.255 J-1.296 E.17717
G3 X138.802 Y125.745 I.081 J2.678 E.04824
G3 X135.463 Y129.608 I-1.294 J2.256 E.30417
G1 X135.754 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.433 Y125.794 I1.754 J-1.34 E.14845
G3 X138.346 Y125.958 I.085 J2.156 E.02874
G3 X135.791 Y129.387 I-.838 J2.042 E.24713
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13246
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07815
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z4.6 F36000
G1 X105.898 Y125.95 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.918 Y125.938 E.00078
G3 X107.407 Y125.403 I1.582 J2.062 E.05333
G3 X106.918 Y130.533 I.092 J2.597 E.29333
G3 X105.662 Y126.162 I.582 J-2.533 E.18365
G1 X105.853 Y125.99 E.00853
G1 X106.159 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.433 Y125.794 I1.349 J1.749 E.04227
G3 X108.346 Y125.958 I.085 J2.156 E.02874
G3 X106.112 Y126.29 I-.838 J2.043 E.35352
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13246
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10986
G1 X107.211 Y125.808 E-.10985
G1 X107.433 Y125.794 E-.0842
G1 X107.789 Y125.808 E-.1354
G1 X107.991 Y125.849 E-.07833
; WIPE_END
G1 E-.04 F1800
G1 X115.616 Y125.52 Z4.6 F36000
G1 X145.698 Y124.225 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y124.225 E.48942
M73 P75 R4
G1 X160.452 Y119.483 E.15729
G1 X162.248 Y119.483 E.05957
G1 X162.248 Y136.517 E.56503
G1 X160.452 Y136.517 E.05957
G1 X160.452 Y131.775 E.15729
G1 X145.698 Y131.775 E.48942
G1 X145.698 Y134.264 E.08256
G1 X99.302 Y134.264 E1.53904
G1 X99.302 Y131.775 E.08256
G1 X85.752 Y131.775 E.44948
G1 X85.752 Y124.225 E.25045
G1 X99.302 Y124.225 E.44948
G1 X99.302 Y121.736 E.08256
G1 X145.698 Y121.736 E1.53904
G1 X145.698 Y124.165 E.08057
G1 X146.09 Y123.833 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y123.833 E.42926
G1 X160.06 Y119.091 E.1457
G1 X162.64 Y119.091 E.07928
G1 X162.64 Y136.909 E.54748
G1 X160.06 Y136.909 E.07928
G1 X160.06 Y132.167 E.1457
G1 X146.09 Y132.167 E.42926
G1 X146.09 Y134.656 E.07648
G1 X98.91 Y134.656 E1.44971
G1 X98.91 Y132.167 E.07648
G1 X85.36 Y132.167 E.41635
G1 X85.36 Y123.833 E.25609
G1 X98.91 Y123.833 E.41635
G1 X98.91 Y121.344 E.07648
G1 X146.09 Y121.344 E1.44971
G1 X146.09 Y123.773 E.07463
; WIPE_START
M204 S10000
G1 X148.09 Y123.781 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.691 Y124.47 Z4.6 F36000
G1 X160.441 Y124.9 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.51426
G1 F12000
G1 X160.441 Y124.664 E.00905
G1 X145.71 Y124.664 E.56579
G1 X145.71 Y125.135 E.0181
G1 X160.441 Y125.135 E.56579
G1 X160.441 Y124.96 E.00675
G1 X160.8 Y124.049 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X156.278 Y130.425 E.26371
G1 X153.453 Y130.425 E.09371
G1 X148.602 Y125.575 E.22756
G1 X145.777 Y125.575 E.09371
G1 X138.059 Y133.293 E.36207
G1 X140.969 Y133.293 E.09651
G1 X138.461 Y130.785 E.11764
G2 X138.461 Y125.215 I-.989 J-2.785 E.24107
G1 X140.969 Y122.707 E.11764
G1 X138.059 Y122.707 E.09651
G1 X145.777 Y130.425 E.36207
G1 X148.602 Y130.425 E.09371
G1 X153.453 Y125.575 E.22756
G1 X156.278 Y125.575 E.09371
G1 X161.9 Y131.196 E.26371
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y131.951 E.05401
G1 X160.441 Y131.336 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.51425
G1 F12000
G1 X145.709 Y131.336 E.56578
G1 X145.709 Y130.898 E.01681
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.709 Y130.865 E.0013
; Slow Down End
G1 F12000
G1 X160.441 Y130.865 E.56578
G1 X160.441 Y131.276 E.0158
G1 X109.369 Y130.279 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X107.897 Y130.925 I-1.912 J-2.36 E.05396
G1 X110.265 Y133.293 E.11108
G1 X107.355 Y133.293 E.09651
G1 X117.941 Y122.707 E.49658
G1 X115.031 Y122.707 E.09651
G1 X125.617 Y133.293 E.49658
G1 X122.707 Y133.293 E.09651
G1 X133.293 Y122.707 E.49658
G1 X130.383 Y122.707 E.09651
G1 X134.718 Y127.042 E.20337
G2 X134.715 Y128.961 I3.125 J.965 E.06459
G1 X130.383 Y133.293 E.20321
G1 X133.293 Y133.293 E.09651
G1 X122.707 Y122.707 E.49658
G1 X125.617 Y122.707 E.09651
G1 X115.031 Y133.293 E.49658
G1 X117.941 Y133.293 E.09651
G1 X107.355 Y122.707 E.49658
G1 X110.265 Y122.707 E.09651
G1 X107.897 Y125.075 E.11108
G3 X109.369 Y125.721 I-.44 J3.005 E.05396
; WIPE_START
G1 X108.63 Y125.272 E-.32852
G1 X107.897 Y125.075 E-.28838
G1 X108.163 Y124.809 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X100.531 Y124.887 Z4.6 F36000
G1 X99.29 Y124.9 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.51426
G1 F12000
G1 X99.29 Y124.664 E.00905
G1 X86.191 Y124.664 E.50312
G1 X86.191 Y125.135 E.0181
G1 X99.29 Y125.135 E.50312
G1 X99.29 Y124.96 E.00675
G1 X99.788 Y122.222 F36000
; LINE_WIDTH: 0.60723
G1 F11164.077
G1 X145.152 Y122.222 E2.08605
; WIPE_START
G1 X143.152 Y122.222 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.679 Y123.775 Z4.6 F36000
G1 X99.291 Y131.336 Z4.6
G1 Z4.2
G1 E.8 F1800
; LINE_WIDTH: 0.51425
G1 F12000
G1 X86.191 Y131.336 E.50311
G1 X86.191 Y130.898 E.01681
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.191 Y130.865 E.0013
; Slow Down End
G1 F12000
G1 X99.291 Y130.865 E.50311
G1 X99.291 Y131.276 E.0158
G1 X99.788 Y133.778 F36000
; LINE_WIDTH: 0.60722
G1 F11164.274
G1 X145.152 Y133.778 E2.08601
G1 X86.1 Y129.892 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.1 Y130.425 E.01771
G1 X87.195 Y130.425 E.0363
G1 X92.046 Y125.575 E.22756
G1 X94.871 Y125.575 E.09371
G1 X102.589 Y133.293 E.36207
G1 X99.679 Y133.293 E.09651
G1 X104.583 Y128.389 E.23005
G3 X104.575 Y127.603 I3.46 J-.429 E.02612
G1 X99.679 Y122.707 E.22967
G1 X102.589 Y122.707 E.09651
G1 X94.871 Y130.425 E.36207
G1 X92.046 Y130.425 E.09371
G1 X87.195 Y125.575 E.22756
G1 X86.1 Y125.575 E.03631
G1 X86.1 Y126.108 E.01771
; CHANGE_LAYER
; Z_HEIGHT: 4.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X86.1 Y125.575 E-.20286
G1 X87.195 Y125.575 E-.4159
G1 X87.458 Y125.837 E-.14124
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
G1 X135.422 Y129.565
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X135.25 Y129.299 E.01051
G3 X137.392 Y125.404 I2.251 J-1.299 E.1769
G3 X136.933 Y130.536 I.113 J2.597 E.29371
G3 X135.461 Y129.61 I.568 J-2.536 E.0588
G1 X135.753 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.417 Y125.795 I1.756 J-1.339 E.14796
G3 X138.346 Y125.958 I.102 J2.15 E.02921
G3 X135.79 Y129.387 I-.837 J2.043 E.2473
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13247
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07814
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z4.8 F36000
G1 X105.898 Y125.95 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.921 Y125.942 E.00081
G3 X107.392 Y125.404 I1.588 J2.06 E.05277
G3 X108.802 Y125.745 I.1 J2.67 E.04874
G3 X105.666 Y126.166 I-1.293 J2.256 E.42921
G1 X105.854 Y125.991 E.00852
G1 X106.16 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.417 Y125.795 I1.349 J1.748 E.04178
G3 X108.346 Y125.958 I.102 J2.15 E.02921
G3 X106.113 Y126.291 I-.837 J2.043 E.35349
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13245
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10986
G1 X107.211 Y125.808 E-.10987
G1 X107.417 Y125.795 E-.07834
G1 X107.789 Y125.808 E-.14122
G1 X107.991 Y125.849 E-.07838
; WIPE_END
G1 E-.04 F1800
G1 X115.618 Y125.561 Z4.8 F36000
G1 X145.698 Y124.424 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y124.424 E.48942
G1 X160.452 Y119.579 E.16072
G1 X162.248 Y119.579 E.05957
G1 X162.248 Y136.421 E.5587
G1 X160.452 Y136.421 E.05957
G1 X160.452 Y131.576 E.16072
G1 X145.698 Y131.576 E.48942
G1 X145.698 Y134.14 E.08503
G1 X99.302 Y134.14 E1.53904
G1 X99.302 Y131.576 E.08503
G1 X85.752 Y131.576 E.44948
G1 X85.752 Y124.424 E.23726
G1 X99.302 Y124.424 E.44948
G1 X99.302 Y121.86 E.08503
G1 X145.698 Y121.86 E1.53904
G1 X145.698 Y124.364 E.08304
G1 X146.09 Y124.032 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y124.032 E.42926
G1 X160.06 Y119.187 E.14888
G1 X162.64 Y119.187 E.07928
G1 X162.64 Y136.813 E.54162
G1 X160.06 Y136.813 E.07928
G1 X160.06 Y131.968 E.14888
G1 X146.09 Y131.968 E.42926
G1 X146.09 Y134.532 E.07877
G1 X98.91 Y134.532 E1.44971
G1 X98.91 Y131.968 E.07877
G1 X85.36 Y131.968 E.41635
G1 X85.36 Y124.032 E.24387
G1 X98.91 Y124.032 E.41635
G1 X98.91 Y121.468 E.07877
M73 P76 R4
G1 X146.09 Y121.468 E1.44971
G1 X146.09 Y123.972 E.07692
; WIPE_START
M204 S10000
G1 X148.09 Y123.98 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.688 Y124.701 Z4.8 F36000
G1 X160.415 Y125.15 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.56531
G1 F12000
G1 X160.415 Y124.889 E.01112
G1 X145.735 Y124.889 E.6249
G1 X145.735 Y125.411 E.02224
G1 X160.415 Y125.411 E.6249
G1 X160.415 Y125.21 E.00856
G1 X160.415 Y131.112 F36000
G1 F12000
G1 X145.735 Y131.112 E.6249
G1 X145.735 Y130.629 E.02054
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.735 Y130.589 E.0017
; Slow Down End
G1 F12000
G1 X160.415 Y130.589 E.6249
G1 X160.415 Y131.052 E.01968
G1 X160.8 Y135.208 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X156.579 Y125.876 E.24959
G1 X153.152 Y125.876 E.11368
G1 X148.903 Y130.124 E.19933
G1 X145.494 Y130.142 E.1131
G1 X138.223 Y122.871 E.34108
G1 X140.804 Y122.871 E.08562
G1 X138.461 Y125.215 E.10994
G3 X138.461 Y130.785 I-.989 J2.785 E.24107
G1 X140.805 Y133.129 E.10994
G1 X138.223 Y133.129 E.08562
G1 X145.494 Y125.858 E.34108
G1 X148.903 Y125.876 E.1131
G1 X153.152 Y130.124 E.19933
G1 X156.579 Y130.124 E.11368
G1 X161.9 Y124.804 E.24959
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
; WIPE_START
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.444 Y123.131 Z4.8 F36000
G1 X109.369 Y125.721 Z4.8
G1 Z4.4
G1 E.8 F1800
G1 F15476.087
G2 X107.897 Y125.075 I-1.912 J2.36 E.05396
G1 X110.101 Y122.871 E.10338
G1 X107.52 Y122.871 E.08562
G1 X117.777 Y133.129 E.48118
G1 X115.195 Y133.129 E.08562
G1 X125.453 Y122.871 E.48118
G1 X122.871 Y122.871 E.08562
G1 X133.129 Y133.129 E.48118
G1 X130.547 Y133.129 E.08562
G1 X134.715 Y128.961 E.19551
G3 X134.715 Y127.039 I3.177 J-.961 E.06468
G1 X130.547 Y122.871 E.19551
G1 X133.129 Y122.871 E.08562
G1 X122.871 Y133.129 E.48118
G1 X125.453 Y133.129 E.08562
G1 X115.196 Y122.871 E.48118
G1 X117.777 Y122.871 E.08562
G1 X107.52 Y133.129 E.48118
G1 X110.101 Y133.129 E.08562
G1 X107.897 Y130.925 E.10338
G2 X109.369 Y130.279 I-.44 J-3.006 E.05396
G1 X99.808 Y133.634 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.647
G1 F10429.083
G1 X145.132 Y133.634 E2.2311
G1 X99.265 Y131.112 F36000
; LINE_WIDTH: 0.5653
G1 F12000
G1 X86.217 Y131.112 E.55543
G1 X86.217 Y130.629 E.02054
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.217 Y130.589 E.0017
; Slow Down End
G1 F12000
G1 X99.265 Y130.589 E.55543
G1 X99.265 Y131.052 E.01968
G1 X99.265 Y125.15 F36000
; LINE_WIDTH: 0.56531
G1 F12000
G1 X99.265 Y124.889 E.01112
G1 X86.217 Y124.889 E.55544
G1 X86.217 Y125.411 E.02224
G1 X99.265 Y125.411 E.55544
G1 X99.265 Y125.21 E.00856
G1 X99.808 Y122.366 F36000
; LINE_WIDTH: 0.647
G1 F10429.083
G1 X145.132 Y122.366 E2.2311
G1 X86.1 Y126.108 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X86.1 Y125.876 E.00773
G1 X87.496 Y125.876 E.04629
G1 X91.745 Y130.124 E.19933
G1 X95.172 Y130.124 E.11368
G1 X99.421 Y125.876 E.19933
G1 X99.489 Y125.876 E.00225
G1 X99.73 Y125.634 E.01131
G1 X99.73 Y125.567 E.00225
G1 X102.425 Y122.871 E.12643
G1 X99.844 Y122.871 E.08562
G1 X104.575 Y127.603 E.22197
G2 X104.575 Y128.397 I34.472 J.396 E.02633
G1 X99.844 Y133.129 E.22197
G1 X102.425 Y133.129 E.08562
G1 X99.73 Y130.433 E.12643
G1 X99.73 Y130.366 E.00225
G1 X99.489 Y130.124 E.01131
G1 X99.421 Y130.124 E.00225
G1 X95.172 Y125.876 E.19933
G1 X91.745 Y125.876 E.11368
G1 X87.496 Y130.125 E.19933
G1 X86.1 Y130.124 E.04629
G1 X86.1 Y129.892 E.00773
; CHANGE_LAYER
; Z_HEIGHT: 4.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X86.1 Y130.124 E-.08851
G1 X87.496 Y130.125 E-.53025
G1 X87.759 Y129.862 E-.14124
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
G1 X135.422 Y129.565
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X135.25 Y129.299 E.01051
G3 X137.376 Y125.405 I2.25 J-1.299 E.17638
G3 X137.961 Y130.557 I.123 J2.595 E.25945
G3 X136.948 Y130.539 I-.468 J-2.209 E.03392
G3 X135.461 Y129.61 I.553 J-2.539 E.05931
G1 X135.754 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.402 Y125.796 I1.754 J-1.34 E.14751
G3 X138.605 Y126.086 I.091 J2.264 E.03852
G3 X135.791 Y129.387 I-1.098 J1.915 E.23821
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13246
G1 X135.458 Y128.846 E-.10989
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07815
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z5 F36000
G1 X105.898 Y125.95 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.919 Y125.939 E.00078
G3 X107.376 Y125.405 I1.582 J2.061 E.0523
G3 X110.057 Y127.539 I.137 J2.579 E.12427
G3 X108.905 Y130.186 I-2.528 J.474 E.10167
G3 X106.948 Y130.539 I-1.406 J-2.191 E.06768
G3 X105.663 Y126.163 I.553 J-2.539 E.1846
G1 X105.853 Y125.99 E.00852
G1 X106.159 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.402 Y125.796 I1.348 J1.749 E.04131
G3 X108.605 Y126.086 I.091 J2.264 E.03852
G3 X106.112 Y126.29 I-1.098 J1.916 E.34458
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13246
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.212 Y125.808 E-.10989
G1 X107.402 Y125.796 E-.07248
G1 X107.789 Y125.808 E-.14703
G1 X107.991 Y125.849 E-.0784
; WIPE_END
G1 E-.04 F1800
G1 X115.619 Y125.603 Z5 F36000
G1 X145.698 Y124.635 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y124.635 E.48942
G1 X160.452 Y119.674 E.16457
G1 X162.248 Y119.674 E.05957
G1 X162.248 Y136.326 E.55238
G1 X160.452 Y136.326 E.05957
G1 X160.452 Y131.365 E.16457
G1 X145.698 Y131.365 E.48942
G1 X145.698 Y134.01 E.08775
G1 X99.302 Y134.01 E1.53904
G1 X99.302 Y131.365 E.08775
G1 X85.752 Y131.365 E.44948
G1 X85.752 Y124.635 E.22323
G1 X99.302 Y124.635 E.44948
G1 X99.302 Y121.99 E.08774
G1 X145.698 Y121.99 E1.53904
G1 X145.698 Y124.575 E.08575
G1 X146.09 Y124.243 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y124.243 E.42926
G1 X160.06 Y119.282 E.15245
G1 X162.64 Y119.282 E.07928
G1 X162.64 Y136.718 E.53577
G1 X160.06 Y136.718 E.07928
G1 X160.06 Y131.757 E.15245
G1 X146.09 Y131.757 E.42926
G1 X146.09 Y134.402 E.08128
G1 X98.91 Y134.402 E1.44971
G1 X98.91 Y131.757 E.08128
G1 X85.36 Y131.757 E.41635
G1 X85.36 Y124.243 E.23088
G1 X98.91 Y124.243 E.41635
G1 X98.91 Y121.598 E.08128
G1 X146.09 Y121.598 E1.44971
G1 X146.09 Y124.183 E.07943
M204 S10000
G1 X145.35 Y124.456 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X145.27 Y125.981 I5.725 J1.062 E.05077
G1 X145.321 Y126.031 E.00236
G1 X138.39 Y132.961 E.32512
G1 X140.637 Y132.961 E.07454
G1 X138.461 Y130.785 E.10211
G2 X138.461 Y125.215 I-.989 J-2.785 E.24107
G1 X140.637 Y123.039 E.1021
G1 X138.39 Y123.039 E.07454
G1 X145.321 Y129.969 E.32512
G1 X145.511 Y129.778 E.00894
G1 X149.25 Y129.778 E.124
G1 X152.806 Y126.222 E.16685
G1 X149.25 Y126.222 E.11798
G1 X152.806 Y129.778 E.16685
G1 X156.926 Y129.778 E.13665
G1 X160.482 Y126.222 E.16685
G1 X160.639 Y126.222 E.00519
G1 X160.88 Y125.981 E.01131
G1 X160.88 Y125.824 E.00519
G1 X161.9 Y124.804 E.04785
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
; WIPE_START
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X155.297 Y126.222 Z5 F36000
G1 Z4.6
G1 E.8 F1800
G1 F15476.087
G1 X156.926 Y126.222 E.05401
G1 X160.482 Y129.778 E.16685
G1 X160.639 Y129.778 E.00519
G1 X160.88 Y130.019 E.01131
G1 X160.88 Y130.176 E.00519
G1 X161.9 Y131.196 E.04785
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.208 E.05401
G1 X160.488 Y130.973 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X145.662 Y130.973 E.45553
G1 X145.672 Y130.328 E.01981
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.674 Y130.17 E.00485
G1 X160.086 Y130.17 E.44285
; Slow Down End
G1 F12000
M73 P77 R4
G1 X160.488 Y130.19 E.01234
G1 X160.488 Y130.913 E.02222
G1 X146.064 Y130.572 F36000
; LINE_WIDTH: 0.46834
G1 F12000
G1 X160.026 Y130.572 E.48404
G1 X146.064 Y125.83 F36000
; Slow Down Start
; LINE_WIDTH: 0.41999
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.662 Y125.818 E.01233
G1 X145.662 Y125.672 E.0045
; Slow Down End
G1 F12000
G1 X145.662 Y125.027 E.01981
G1 X160.488 Y125.027 E.45553
G3 X160.481 Y125.672 I-11.314 J.201 E.01981
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X160.476 Y125.83 E.00485
; Slow Down End
G1 F12000
G1 X146.124 Y125.83 E.441
G1 X146.064 Y125.429 F36000
; LINE_WIDTH: 0.46836
G1 F12000
G1 X160.026 Y125.429 E.48406
; WIPE_START
G1 X158.026 Y125.429 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X150.587 Y123.721 Z5 F36000
G1 X145.334 Y122.514 Z5
G1 Z4.6
G1 E.8 F1800
; LINE_WIDTH: 0.36368
G1 F12000
G1 X145.334 Y122.354 E.00419
G1 X99.666 Y122.354 E1.19367
G1 X99.666 Y122.675 E.00838
G1 X145.334 Y122.675 E1.19367
G1 X145.334 Y122.574 E.00262
G1 X109.363 Y130.285 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X107.887 Y130.914 I-2.253 J-3.235 E.05362
G1 X109.934 Y132.961 E.09603
G1 X107.687 Y132.962 E.07454
G1 X117.61 Y123.039 E.46551
G1 X115.363 Y123.039 E.07454
G1 X125.286 Y132.961 E.46551
G1 X123.039 Y132.961 E.07454
G1 X132.961 Y123.039 E.46551
G1 X130.714 Y123.039 E.07454
G1 X134.715 Y127.039 E.18767
G2 X134.715 Y128.961 I3.178 J.961 E.06468
G1 X130.714 Y132.961 E.18767
G1 X132.961 Y132.961 E.07454
G1 X123.039 Y123.039 E.46551
G1 X125.286 Y123.039 E.07454
G1 X115.363 Y132.962 E.46551
G1 X117.61 Y132.961 E.07454
G1 X107.687 Y123.039 E.46551
G1 X109.934 Y123.039 E.07454
G1 X107.897 Y125.075 E.09554
G3 X109.369 Y125.721 I-.44 J3.006 E.05396
; WIPE_START
G1 X108.63 Y125.272 E-.32851
G1 X107.897 Y125.075 E-.28839
G1 X108.163 Y124.809 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X100.549 Y125.343 Z5 F36000
G1 X99.338 Y125.429 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X99.331 Y125.672 E.00748
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X99.326 Y125.83 E.00485
G1 X86.144 Y125.83 E.40504
G1 X86.144 Y125.672 E.00485
; Slow Down End
G1 F12000
G1 X86.144 Y125.027 E.01981
G1 X99.338 Y125.027 E.40539
G1 X99.338 Y125.369 E.01049
G1 X86.545 Y125.429 F36000
; LINE_WIDTH: 0.46835
G1 F12000
G1 X98.876 Y125.429 E.42748
G1 X99.338 Y130.19 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X99.338 Y130.973 E.02406
G1 X86.144 Y130.973 E.40539
G1 X86.144 Y130.328 E.01981
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.144 Y130.17 E.00485
G1 X98.936 Y130.17 E.39306
G1 X99.278 Y130.187 E.0105
; Slow Down End
G1 X86.545 Y130.572 F36000
; LINE_WIDTH: 0.46834
G1 F12000
G1 X98.876 Y130.572 E.42747
; WIPE_START
G1 X96.876 Y130.572 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X99.666 Y133.646 Z5 F36000
G1 Z4.6
G1 E.8 F1800
; LINE_WIDTH: 0.36369
G1 F12000
G1 X145.334 Y133.646 E1.1937
G1 X145.334 Y133.325 E.00838
G1 X99.666 Y133.325 E1.1937
G1 X99.666 Y133.586 E.00682
; WIPE_START
G1 X99.666 Y133.325 E-.0991
G1 X101.405 Y133.325 E-.6609
; WIPE_END
G1 E-.04 F1800
G1 X95.858 Y128.083 Z5 F36000
G1 X93.89 Y126.222 Z5
G1 Z4.6
M73 P77 R3
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X95.518 Y126.222 E.05401
G1 X99.074 Y129.778 E.16685
G1 X99.489 Y129.778 E.01374
G1 X99.73 Y130.019 E.01131
G1 X99.73 Y130.433 E.01374
G1 X102.258 Y132.961 E.1186
G1 X100.011 Y132.961 E.07454
G1 X104.575 Y128.397 E.21413
G3 X104.575 Y127.603 I34.472 J-.397 E.02633
G1 X100.011 Y123.039 E.21413
G1 X102.258 Y123.039 E.07454
G1 X99.73 Y125.567 E.1186
G1 X99.73 Y125.981 E.01374
G1 X99.489 Y126.222 E.01131
G1 X99.074 Y126.222 E.01374
G1 X95.518 Y129.778 E.16685
G1 X91.399 Y129.778 E.13665
G1 X87.842 Y126.222 E.16685
G1 X91.398 Y126.222 E.11798
G1 X87.842 Y129.778 E.16685
G1 X86.214 Y129.778 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 4.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X87.842 Y129.778 E-.61876
G1 X88.105 Y129.515 E-.14125
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
G1 X135.422 Y129.565
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X135.25 Y129.299 E.01051
G3 X137.361 Y125.406 I2.25 J-1.299 E.17587
G3 X136.963 Y130.542 I.139 J2.594 E.29329
G3 X135.461 Y129.61 I.537 J-2.542 E.05982
G1 X135.753 Y129.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X137.386 Y125.797 I1.755 J-1.339 E.14702
G3 X138.605 Y126.086 I.109 J2.259 E.039
G3 X135.79 Y129.387 I-1.097 J1.915 E.23827
; WIPE_START
M204 S10000
G1 X135.586 Y129.105 E-.13247
G1 X135.458 Y128.846 E-.10989
G1 X135.365 Y128.572 E-.10986
G1 X135.331 Y128.4 E-.06664
G1 X135.29 Y128 E-.15285
G1 X135.308 Y127.711 E-.10989
G1 X135.349 Y127.509 E-.0784
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z5.2 F36000
G1 X105.898 Y125.95 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.919 Y125.939 E.00078
G3 X107.361 Y125.406 I1.582 J2.061 E.05178
G3 X106.963 Y130.542 I.139 J2.594 E.29329
G3 X105.663 Y126.163 I.537 J-2.542 E.1851
G1 X105.853 Y125.99 E.00852
G1 X106.16 Y126.253 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X107.386 Y125.797 I1.348 J1.747 E.04083
G3 X108.605 Y126.086 I.109 J2.259 E.039
G3 X106.113 Y126.291 I-1.097 J1.915 E.34441
; WIPE_START
M204 S10000
G1 X106.395 Y126.086 E-.13245
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.211 Y125.808 E-.10986
G1 X107.386 Y125.797 E-.06665
G1 X107.789 Y125.808 E-.15286
G1 X107.991 Y125.849 E-.07844
; WIPE_END
G1 E-.04 F1800
G1 X115.621 Y125.652 Z5.2 F36000
G1 X145.698 Y124.878 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y124.878 E.48942
G1 X160.452 Y119.779 E.16913
G1 X162.248 Y119.779 E.05957
G1 X162.248 Y136.221 E.5454
G1 X160.452 Y136.221 E.05957
G1 X160.452 Y131.122 E.16913
G1 X145.698 Y131.122 E.48942
G1 X145.698 Y133.867 E.09104
G1 X99.302 Y133.867 E1.53904
G1 X99.302 Y131.122 E.09104
G1 X85.752 Y131.122 E.44948
G1 X85.752 Y124.878 E.20715
G1 X99.302 Y124.878 E.44948
G1 X99.302 Y122.133 E.09104
G1 X145.698 Y122.133 E1.53904
G1 X145.698 Y124.818 E.08905
G1 X146.09 Y124.486 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y124.486 E.42926
G1 X160.06 Y119.387 E.15666
G1 X162.64 Y119.387 E.07928
G1 X162.64 Y136.613 E.5293
G1 X160.06 Y136.613 E.07928
G1 X160.06 Y131.514 E.15666
G1 X146.09 Y131.514 E.42926
G1 X146.09 Y134.259 E.08433
G1 X98.91 Y134.259 E1.44971
G1 X98.91 Y131.514 E.08433
G1 X85.36 Y131.514 E.41635
G1 X85.36 Y124.486 E.21597
G1 X98.91 Y124.486 E.41635
G1 X98.91 Y121.741 E.08433
G1 X146.09 Y121.741 E1.44971
G1 X146.09 Y124.426 E.08248
; WIPE_START
M204 S10000
G1 X148.09 Y124.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.333 Y125.243 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X145.414 Y125.253 E.00228
G1 X145.657 Y125.4 F36000
; Slow Down Start
; LINE_WIDTH: 0.395045
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.57 Y125.281 E.00424
G1 X145.474 Y125.26 E.00282
; Slow Down End
; LINE_WIDTH: 0.419378
G1 F12000
G1 X145.586 Y125.234 E.00354
G1 X146.15 Y125.27 E.01733
G1 X160.488 Y125.27 E.43983
G3 X160.482 Y126.018 I-15.889 J.244 E.02296
; Slow Down Start
; LINE_WIDTH: 0.419927
G1 F3000;_EXTRUDE_SET_SPEED
G1 X160.476 Y126.245 E.00698
G1 X146.15 Y126.245 E.44012
G1 X145.662 Y126.226 E.015
G1 X145.661 Y126.018 E.00638
; Slow Down End
; LINE_WIDTH: 0.417738
G1 F12000
G1 X145.658 Y125.46 E.01706
G1 X146.15 Y125.758 F36000
; LINE_WIDTH: 0.64139
G1 F10526.844
G1 X159.94 Y125.758 E.6725
G1 X155.713 Y126.637 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.341 Y126.637 E.05401
G1 X160.067 Y129.363 E.12786
G1 X160.639 Y129.363 E.01898
G1 X160.88 Y129.604 E.01131
G1 X160.88 Y130.176 E.01898
G1 X161.101 Y130.397 E.01037
G1 X161.178 Y130.397 E.00255
G1 X161.178 Y130.474 E.00255
G1 X161.523 Y130.819 E.01619
G1 X161.523 Y131.173 E.01174
G1 X161.814 Y131.11 E.00989
G1 X161.9 Y131.196 E.00402
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.208 E.05401
G1 X160.788 Y130.787 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.395367
G1 F12000
G1 X160.815 Y130.954 E.00486
G1 X160.683 Y130.761 E.00671
G1 X160.729 Y130.772 E.00136
G1 X145.674 Y129.755 F36000
; Slow Down Start
; LINE_WIDTH: 0.41999
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.671 Y129.982 E.00698
; Slow Down End
; LINE_WIDTH: 0.418613
G1 F12000
G1 X145.662 Y130.73 E.02291
G1 X160 Y130.73 E.43894
G1 X160.656 Y130.759 E.02009
G1 X160.492 Y130.6 E.00697
G1 X160.489 Y129.982 E.01893
; Slow Down Start
; LINE_WIDTH: 0.418906
G1 F3000;_EXTRUDE_SET_SPEED
G1 X160.488 Y129.774 E.00636
G1 X160 Y129.755 E.01496
; Slow Down End
; LINE_WIDTH: 0.41999
G1 F12000
G1 X145.734 Y129.755 E.43835
G1 X146.15 Y130.242 F36000
; LINE_WIDTH: 0.6414
G1 F10526.668
G1 X159.94 Y130.242 E.67251
M73 P78 R3
G1 X161.885 Y130.724 F36000
; Slow Down Start
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X161.885 Y126.162 E.12638
; Slow Down End
G1 X160.8 Y120.792 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X160.88 Y125.824 E.04785
G1 X160.88 Y126.396 E.01898
G1 X160.639 Y126.637 E.01131
G1 X160.067 Y126.637 E.01898
G1 X157.341 Y129.363 E.12786
G1 X152.391 Y129.363 E.16422
G1 X149.665 Y126.637 E.12786
G1 X152.391 Y126.637 E.09041
G1 X149.665 Y129.363 E.12786
G1 X145.511 Y129.363 E.13779
G2 X145.27 Y129.918 I.157 J.398 E.02232
G1 X138.578 Y123.226 E.31396
G1 X140.45 Y123.226 E.0621
G1 X138.461 Y125.215 E.09331
G3 X138.63 Y130.728 I-.966 J2.788 E.23626
G1 X138.461 Y130.785 E.00592
G1 X140.45 Y132.774 E.09331
G1 X138.578 Y132.774 E.0621
G1 X145.27 Y126.082 E.31396
G1 X145.27 Y125.603 E.01587
G1 X144.973 Y125.603 E.00988
G1 X144.983 Y124.765 E.02781
G1 X145.323 Y122.68 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38574
G1 F12000
G1 X145.323 Y122.508 E.00479
G1 X99.677 Y122.508 E1.27514
G1 X99.677 Y122.851 E.00958
G1 X145.323 Y122.851 E1.27514
G1 X145.323 Y122.74 E.00311
G1 X109.369 Y125.721 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X107.897 Y125.075 I-1.912 J2.36 E.05396
G1 X109.746 Y123.226 E.08675
G1 X107.874 Y123.226 E.0621
G1 X117.422 Y132.774 E.44792
G1 X115.55 Y132.774 E.0621
G1 X125.098 Y123.226 E.44792
G1 X123.226 Y123.226 E.0621
G1 X132.774 Y132.774 E.44792
G1 X130.902 Y132.774 E.0621
G1 X134.715 Y128.961 E.17888
G3 X134.715 Y127.039 I3.178 J-.961 E.06468
G1 X130.902 Y123.226 E.17888
G1 X132.774 Y123.226 E.0621
G1 X123.226 Y132.774 E.44792
G1 X125.098 Y132.774 E.0621
G1 X115.55 Y123.226 E.44792
G1 X117.422 Y123.226 E.0621
G1 X107.874 Y132.774 E.44792
G1 X109.746 Y132.774 E.0621
G1 X107.897 Y130.925 E.08675
G2 X109.369 Y130.279 I-.44 J-3.006 E.05396
G1 X99.677 Y133.492 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38574
G1 F12000
G1 X145.323 Y133.492 E1.27514
G1 X145.323 Y133.149 E.00958
G1 X99.677 Y133.149 E1.27514
G1 X99.677 Y133.432 E.0079
G1 X99.515 Y125.268 F36000
; LINE_WIDTH: 0.38292
G1 F12000
G1 X99.61 Y125.254 E.00266
G1 X86.144 Y125.27 F36000
; LINE_WIDTH: 0.407079
G1 F12000
G1 X98.85 Y125.27 E.37704
G1 X99.393 Y125.23 E.01616
G1 X99.515 Y125.268 E.00378
G1 X99.42 Y125.295 E.00292
G1 X99.345 Y125.4 E.00383
G1 X99.331 Y126.018 E.01836
; Slow Down Start
; LINE_WIDTH: 0.417123
G1 F3000;_EXTRUDE_SET_SPEED
G1 X99.326 Y126.245 E.00693
G1 X86.274 Y126.249 E.398
G1 X86.115 Y126.434 E.00745
G2 X86.141 Y126.018 I-2.649 J-.377 E.01271
; Slow Down End
; LINE_WIDTH: 0.418185
G1 F12000
G1 X86.144 Y125.33 E.02105
G1 X86.632 Y125.758 F36000
; LINE_WIDTH: 0.64139
G1 F10526.844
G1 X98.79 Y125.758 E.59292
G1 X86.116 Y129.594 F36000
; Slow Down Start
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X86.115 Y126.494 E.08589
; Slow Down End
G1 X86.274 Y129.75 F36000
; Slow Down Start
; LINE_WIDTH: 0.419904
G1 F3000;_EXTRUDE_SET_SPEED
G1 X98.85 Y129.755 E.38632
G1 X99.338 Y129.774 E.015
G1 X99.338 Y129.982 E.00638
; Slow Down End
; LINE_WIDTH: 0.418377
G1 F12000
G1 X99.338 Y130.73 E.0229
G1 X86.144 Y130.73 E.40366
G2 X86.116 Y129.594 I-16.628 J-.157 E.03478
G1 X86.231 Y129.708 E.00496
G1 X98.85 Y130.242 F36000
; LINE_WIDTH: 0.6414
G1 F10526.668
G1 X86.692 Y130.242 E.59293
G1 X86.629 Y129.363 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X88.257 Y129.363 E.05401
G1 X90.983 Y126.637 E.12786
G1 X88.257 Y126.637 E.09041
G1 X90.983 Y129.363 E.12786
G1 X95.933 Y129.363 E.16422
G1 X98.659 Y126.637 E.12786
G1 X99.489 Y126.637 E.02752
G1 X99.73 Y126.396 E.01131
G1 X99.73 Y125.603 E.02631
G1 X100.027 Y125.603 E.00988
G1 X100.027 Y125.269 E.01109
G1 X102.07 Y123.226 E.09583
G1 X100.198 Y123.226 E.0621
G1 X104.254 Y127.282 E.19029
G1 X104.173 Y127.692 E.01385
G1 X104.463 Y127.491 E.01171
G1 X104.575 Y127.603 E.00524
G2 X104.575 Y128.397 I34.475 J.397 E.02633
G1 X100.198 Y132.774 E.20534
G1 X102.07 Y132.774 E.0621
G1 X99.776 Y130.48 E.10763
G1 X99.73 Y130.398 E.00313
G1 X99.73 Y129.604 E.02633
G1 X99.489 Y129.363 E.01131
G1 X98.659 Y129.363 E.02752
G1 X95.933 Y126.637 E.12786
G1 X94.305 Y126.637 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 5
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X95.933 Y126.637 E-.61876
G1 X96.196 Y126.9 E-.14125
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
G1 X135.422 Y129.565
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X135.25 Y129.299 E.01051
G3 X137.345 Y125.407 I2.25 J-1.299 E.17535
G3 X136.978 Y130.545 I.155 J2.593 E.29328
G3 X135.461 Y129.61 I.522 J-2.545 E.06033
G1 X135.746 Y129.346 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.754 Y129.34 E.00028
G3 X137.371 Y125.798 I1.754 J-1.339 E.14653
G3 X138.605 Y126.086 I.125 J2.254 E.03947
G3 X135.943 Y129.557 I-1.097 J1.915 E.23124
G1 X135.787 Y129.39 E.00703
; WIPE_START
M204 S10000
G1 X135.754 Y129.34 E-.02277
G1 X135.586 Y129.105 E-.10968
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07816
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z5.4 F36000
G1 X105.898 Y125.95 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.919 Y125.939 E.00078
G3 X107.345 Y125.407 I1.581 J2.061 E.05127
G3 X104.955 Y127.478 I.155 J2.593 E.42865
G3 X105.663 Y126.163 I2.545 J.522 E.05025
G1 X105.853 Y125.99 E.00852
G1 X106.154 Y126.246 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X106.16 Y126.254 E.00028
G3 X107.371 Y125.798 I1.348 J1.747 E.04035
G3 X108.605 Y126.086 I.125 J2.254 E.03947
G3 X105.944 Y126.444 I-1.097 J1.915 E.33735
G1 X106.111 Y126.287 E.00702
; WIPE_START
M204 S10000
G1 X106.16 Y126.254 E-.02278
G1 X106.395 Y126.086 E-.10967
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.211 Y125.808 E-.10986
G1 X107.371 Y125.798 E-.06079
G1 X107.789 Y125.808 E-.15868
G1 X107.991 Y125.849 E-.07846
; WIPE_END
G1 E-.04 F1800
G1 X115.622 Y125.707 Z5.4 F36000
G1 X145.698 Y125.147 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y125.147 E.48942
G1 X160.452 Y119.889 E.1744
G1 X162.248 Y119.889 E.05957
G1 X162.248 Y136.111 E.53808
G1 X160.452 Y136.111 E.05957
G1 X160.452 Y130.853 E.1744
G1 X145.698 Y130.853 E.48942
G1 X145.698 Y133.72 E.09511
G1 X99.302 Y133.72 E1.53904
G1 X99.302 Y130.853 E.09511
G1 X85.752 Y130.853 E.44948
G1 X85.752 Y125.147 E.18928
G1 X99.302 Y125.147 E.44948
G1 X99.302 Y122.28 E.09511
G1 X145.698 Y122.28 E1.53904
G1 X145.698 Y125.087 E.09312
G1 X146.09 Y124.755 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y124.755 E.42926
G1 X160.06 Y119.497 E.16155
G1 X162.64 Y119.497 E.07928
G1 X162.64 Y136.503 E.52252
G1 X160.06 Y136.503 E.07928
G1 X160.06 Y131.245 E.16155
G1 X146.09 Y131.245 E.42926
G1 X146.09 Y134.112 E.0881
G1 X98.91 Y134.112 E1.44971
G1 X98.91 Y131.245 E.0881
G1 X85.36 Y131.245 E.41635
G1 X85.36 Y124.755 E.19942
G1 X98.91 Y124.755 E.41635
G1 X98.91 Y121.888 E.0881
G1 X146.09 Y121.888 E1.44971
G1 X146.09 Y124.695 E.08626
M204 S10000
G1 X145.324 Y124.825 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.49628
G1 F12000
G3 X145.238 Y124.778 I-.056 J0 E.00854
; WIPE_START
G1 X145.211 Y124.825 E-.18145
G1 X145.239 Y124.874 E-.19284
G1 X145.296 Y124.874 E-.19284
G1 X145.324 Y124.825 E-.19286
; WIPE_END
G1 E-.04 F1800
G1 X146.353 Y125.555 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.4509
G1 F12000
G1 X159.737 Y125.555 E.44495
G1 X160.904 Y125.355 F36000
; LINE_WIDTH: 0.53924
G1 F12000
G1 X160.904 Y124.906 E.01817
G1 X162.081 Y126.241 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.41125
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X160.226 Y125.639 E.10554
G1 X160.226 Y125.984 E.01867
G1 X159.795 Y125.984 E.02332
G1 X161.878 Y126.66 E.11854
G1 X161.878 Y127.145 E.02625
G1 X158.302 Y125.984 E.20348
G1 X156.81 Y125.984 E.08078
G1 X161.878 Y127.63 E.28842
G1 X161.878 Y128.115 E.02625
G1 X155.317 Y125.984 E.37336
G1 X153.824 Y125.984 E.08078
G1 X161.878 Y128.6 E.4583
G1 X161.878 Y129.085 E.02625
G1 X152.332 Y125.984 E.54324
G1 X150.839 Y125.984 E.08078
G1 X161.878 Y129.57 E.62818
G1 X161.878 Y130.055 E.02625
G1 X149.347 Y125.984 E.71312
G1 X147.854 Y125.984 E.08078
G1 X161.878 Y130.54 E.79806
G1 X161.878 Y130.658 E.00636
G1 X161.197 Y130.804 E.03768
G1 X160.023 Y130.423 E.0668
M73 P79 R3
G1 X159.797 Y130.445 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.433905
; LAYER_HEIGHT: 0.2
G1 F12000
G1 X153.075 Y130.445 E.21416
; LINE_WIDTH: 0.400185
G1 X146.353 Y130.445 E.19569
G1 X146.276 Y130.522 E.00315
; LINE_WIDTH: 0.38292
G1 X146.129 Y130.584 E.00444
; LINE_WIDTH: 0.407025
G1 X145.97 Y130.559 E.00476
; LINE_WIDTH: 0.455235
G1 X145.812 Y130.534 E.0054
; LINE_WIDTH: 0.503445
G1 X145.653 Y130.509 E.00603
; LINE_WIDTH: 0.551655
G1 X145.494 Y130.484 E.00666
; LINE_WIDTH: 0.391511
G1 X145.474 Y130.486 E.00059
; LINE_WIDTH: 0.423284
G1 X145.404 Y130.496 E.00218
; LINE_WIDTH: 0.469651
G1 X145.334 Y130.505 E.00245
; LINE_WIDTH: 0.54333
G1 X145.265 Y130.515 E.00287
G1 X145.246 Y130.649 E.00554
; LINE_WIDTH: 0.517125
G1 X145.246 Y130.872 E.00859
; LINE_WIDTH: 0.472975
G1 X145.246 Y131.094 E.00779
G1 X143.42 Y129.393 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.41125
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X145.924 Y130.206 E.14247
G1 X145.924 Y130.016 E.01028
G1 X146.832 Y130.016 E.04915
G1 X143.703 Y129 E.17808
G1 X143.791 Y128.543 E.02515
G1 X148.325 Y130.016 E.25798
G1 X149.818 Y130.016 E.08078
G1 X143.453 Y127.949 E.36217
G1 X143.422 Y127.744 E.0112
G1 X143.641 Y127.525 E.01678
G1 X151.31 Y130.016 E.43641
G1 X152.803 Y130.016 E.08078
G1 X144.007 Y127.159 E.50051
G1 X144.373 Y126.793 E.02802
G1 X154.295 Y130.016 E.56462
G1 X155.788 Y130.016 E.08078
G1 X140.444 Y125.031 E.87316
G3 X139.759 Y124.323 I5.009 J-5.535 E.05334
G1 X157.281 Y130.016 E.99708
G1 X158.773 Y130.016 E.08078
G1 X139.462 Y123.742 E1.09894
G1 X140.185 Y125.53 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
; LAYER_HEIGHT: 0.2
G1 F15476.087
G1 X140.128 Y125.704 E.00608
G1 X141.503 Y126.151 E.04794
G1 X142.969 Y127.617 E.06878
G1 X143.079 Y128.272 E.02205
G1 X138.771 Y132.581 E.20213
G1 X140.257 Y132.581 E.0493
G1 X138.461 Y130.785 E.08426
G2 X138.461 Y125.215 I-.989 J-2.785 E.24107
G1 X139.266 Y124.41 E.03774
G1 X138.896 Y123.988 E.01862
G1 X139.118 Y123.766 E.01043
G1 X138.771 Y123.419 E.01628
G1 X137.143 Y123.419 E.05401
G1 X141.801 Y123.927 F36000
G1 F15476.087
G1 X140.252 Y123.424 E.05401
G1 X141.885 Y123.419 E.05417
G1 X145.311 Y122.849 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.40896
G1 F12000
G1 X145.311 Y122.666 E.00546
G1 X99.689 Y122.666 E1.36082
G1 X99.689 Y123.032 E.01092
G1 X145.311 Y123.032 E1.36082
G1 X145.311 Y122.909 E.00367
; WIPE_START
G1 X145.311 Y123.032 E-.04675
G1 X143.434 Y123.032 E-.71325
; WIPE_END
G1 E-.04 F1800
G1 X151.004 Y122.056 Z5.4 F36000
G1 X160.8 Y120.792 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X161.355 Y125.348 E.02553
G1 X161.355 Y124.635 E.02365
G2 X160.8 Y124.394 I-.398 J.157 E.0223
G1 X160.8 Y124.134 E.00864
G1 X161.007 Y131.245 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X160.986 Y131.282 E.00118
G1 X160.922 Y131.245 E.00204
G1 X160.934 Y131.238 E.00038
G1 X160.8 Y133.579 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X161.9 Y132.48 E.05157
; WIPE_START
G1 X160.8 Y133.579 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.184 Y133.091 Z5.4 F36000
G1 X109.369 Y130.279 Z5.4
G1 Z5
G1 E.8 F1800
G1 F15476.087
G3 X107.897 Y130.925 I-2.178 J-2.966 E.05375
G1 X109.553 Y132.581 E.0777
G1 X108.067 Y132.581 E.0493
G1 X117.229 Y123.419 E.42982
G1 X115.743 Y123.419 E.0493
G1 X124.905 Y132.581 E.42982
G1 X123.419 Y132.581 E.0493
G1 X132.581 Y123.419 E.42982
G1 X131.095 Y123.419 E.0493
G1 X134.715 Y127.039 E.16983
G2 X134.715 Y128.961 I3.177 J.961 E.06468
G1 X131.095 Y132.581 E.16983
G1 X132.581 Y132.581 E.0493
G1 X123.419 Y123.419 E.42982
G1 X124.905 Y123.419 E.0493
G1 X115.743 Y132.581 E.42982
G1 X117.229 Y132.581 E.0493
G1 X108.067 Y123.419 E.42982
G1 X109.553 Y123.419 E.0493
G1 X107.897 Y125.075 E.0777
G2 X106.306 Y125.304 I-.38 J3.006 E.05397
G1 X99.779 Y124.816 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.48008
G1 F12000
G3 X99.694 Y124.774 I-.053 J.001 E.00781
G1 X99.65 Y124.307 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.65 Y123.419 E.02944
G1 X100.391 Y123.419 E.02457
G1 X101.188 Y124.216 E.03737
G1 X101.003 Y124.294 E.00667
G1 X101.877 Y123.419 E.04104
G1 X103.506 Y123.419 E.05401
G1 X101.151 Y129.777 F36000
G1 F15476.087
G1 X100.205 Y130.43 E.03813
G1 X100.205 Y130.909 E.01589
G1 X101.877 Y132.581 E.07843
G1 X100.391 Y132.581 E.0493
G1 X104.575 Y128.397 E.19629
G3 X104.575 Y127.603 I34.395 J-.397 E.02633
G1 X104.463 Y127.491 E.00525
G1 X103.123 Y128.416 E.05401
G1 X99.754 Y131.154 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53922
G1 F12000
G1 X99.754 Y130.856 E.01205
G1 X99.078 Y130.686 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.40266
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X104.295 Y127.085 E.32889
G1 X103.97 Y126.759 E.02388
G1 X99.076 Y130.137 E.30852
G1 X99.076 Y130.016 E.00627
G1 X98.454 Y130.016 E.03226
G1 X103.644 Y126.434 E.32721
G1 X103.319 Y126.109 E.02388
G1 X97.657 Y130.016 E.35693
G1 X96.861 Y130.016 E.04134
G1 X102.994 Y125.783 E.38665
G1 X102.668 Y125.458 E.02388
G1 X96.064 Y130.016 E.41637
G1 X95.267 Y130.016 E.04134
G1 X102.343 Y125.132 E.44609
G1 X102.017 Y124.807 E.02388
G1 X94.47 Y130.016 E.47581
G1 X93.673 Y130.016 E.04134
G1 X101.692 Y124.481 E.50553
G1 X101.683 Y124.472 E.00069
G1 X99.694 Y125.311 E.11199
G1 X92.876 Y130.016 E.42979
G1 X92.079 Y130.016 E.04134
G1 X97.922 Y125.984 E.36834
G1 X97.125 Y125.984 E.04134
G1 X91.283 Y130.016 E.36834
G1 X90.486 Y130.016 E.04134
G1 X96.328 Y125.984 E.36834
G1 X95.532 Y125.984 E.04134
G1 X89.689 Y130.016 E.36834
G1 X88.892 Y130.016 E.04134
G1 X94.735 Y125.984 E.36834
G1 X93.938 Y125.984 E.04134
G1 X88.095 Y130.016 E.36834
G1 X87.298 Y130.016 E.04134
G1 X93.141 Y125.984 E.36834
G1 X92.344 Y125.984 E.04134
G1 X86.502 Y130.016 E.36834
G1 X86.122 Y130.016 E.0197
G1 X86.122 Y129.729 E.01494
G1 X91.547 Y125.984 E.34205
G1 X90.751 Y125.984 E.04134
G1 X86.122 Y129.179 E.29181
G1 X86.122 Y128.629 E.02854
G1 X89.954 Y125.984 E.24157
G1 X89.157 Y125.984 E.04134
G1 X86.122 Y128.078 E.19134
G1 X86.122 Y127.528 E.02854
G1 X88.36 Y125.984 E.1411
G1 X87.563 Y125.984 E.04134
G1 X86.122 Y126.978 E.09087
G1 X86.122 Y126.428 E.02854
G1 X87.06 Y125.781 E.05913
G1 X86.16 Y125.555 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.4509
; LAYER_HEIGHT: 0.2
G1 F15000
G1 X98.587 Y125.555 E.41315
G1 X99.689 Y133.334 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.40896
G1 F12000
G1 X145.311 Y133.334 E1.36082
G1 X145.311 Y132.968 E.01092
G1 X99.689 Y132.968 E1.36082
G1 X99.689 Y133.274 E.00913
; WIPE_START
G1 X99.689 Y132.968 E-.1163
G1 X101.383 Y132.968 E-.6437
; WIPE_END
G1 E-.04 F1800
G1 X93.853 Y131.72 Z5.4 F36000
G1 X86.16 Y130.445 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.45092
G1 F15000
G1 X98.587 Y130.445 E.41317
; CHANGE_LAYER
; Z_HEIGHT: 5.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X96.587 Y130.445 E-.76
; WIPE_END
M73 P80 R3
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
G1 X135.422 Y129.565
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.253 Y129.297 E.0105
G3 X137.33 Y125.408 I2.255 J-1.295 E.17458
G3 X139.085 Y125.935 I.185 J2.57 E.06213
G3 X135.463 Y129.608 I-1.577 J2.067 E.29283
G1 X135.746 Y129.346 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.753 Y129.34 E.00026
G3 X137.356 Y125.799 I1.755 J-1.339 E.14608
G3 X138.605 Y126.086 I.141 J2.252 E.03994
G3 X135.942 Y129.558 I-1.097 J1.916 E.23129
G1 X135.787 Y129.39 E.00703
; WIPE_START
M204 S10000
G1 X135.753 Y129.34 E-.02278
G1 X135.586 Y129.105 E-.10969
G1 X135.458 Y128.846 E-.10989
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10991
G1 X135.308 Y127.712 E-.10983
G1 X135.349 Y127.51 E-.07816
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.098 Z5.6 F36000
G1 X105.935 Y125.922 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.201 Y125.75 E.01051
G3 X107.33 Y125.408 I1.299 J2.25 E.03948
G3 X108.007 Y130.548 I.17 J2.592 E.25944
G3 X106.993 Y130.548 I-.507 J-2.113 E.03393
G3 X105.89 Y125.961 I.507 J-2.548 E.1962
G1 X106.154 Y126.246 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X106.16 Y126.253 E.00027
G3 X107.356 Y125.799 I1.348 J1.748 E.03988
G3 X108.605 Y126.086 I.141 J2.252 E.03994
G3 X105.944 Y126.444 I-1.097 J1.916 E.33749
G1 X106.11 Y126.287 E.00702
; WIPE_START
M204 S10000
G1 X106.16 Y126.253 E-.0228
G1 X106.395 Y126.086 E-.10967
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.212 Y125.808 E-.10989
G1 X107.356 Y125.799 E-.05492
G1 X107.5 Y125.79 E-.05494
G1 X107.789 Y125.808 E-.10988
G1 X107.99 Y125.849 E-.07815
; WIPE_END
G1 E-.04 F1800
G1 X115.622 Y125.768 Z5.6 F36000
G1 X145.698 Y125.448 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y125.448 E.48942
G1 X160.452 Y120.001 E.18069
G1 X162.248 Y120.001 E.05957
G1 X162.248 Y135.999 E.53069
G1 X160.452 Y135.999 E.05957
G1 X160.452 Y130.552 E.18069
G1 X145.698 Y130.552 E.48942
G1 X145.698 Y133.556 E.09965
G1 X99.302 Y133.556 E1.53904
G1 X99.302 Y130.552 E.09965
G1 X85.752 Y130.552 E.44948
G1 X85.752 Y125.448 E.16931
G1 X99.302 Y125.448 E.44948
G1 X99.302 Y122.444 E.09965
G1 X145.698 Y122.444 E1.53904
G1 X145.698 Y125.388 E.09766
G1 X146.09 Y125.056 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y125.056 E.42926
G1 X160.06 Y119.609 E.16737
G1 X162.64 Y119.609 E.07928
G1 X162.64 Y136.391 E.51567
G1 X160.06 Y136.391 E.07928
G1 X160.06 Y130.944 E.16737
G1 X146.09 Y130.944 E.42926
G1 X146.09 Y133.948 E.09231
G1 X98.91 Y133.948 E1.44971
G1 X98.91 Y130.944 E.09231
G1 X85.36 Y130.944 E.41635
G1 X85.36 Y125.056 E.18093
G1 X98.91 Y125.056 E.41635
G1 X98.91 Y122.052 E.09231
G1 X146.09 Y122.052 E1.44971
G1 X146.09 Y124.996 E.09046
; WIPE_START
M204 S10000
G1 X148.09 Y125.005 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.299 Y123.038 Z5.6 F36000
G1 Z5.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.43366
G1 F12000
G1 X145.299 Y122.843 E.00622
G1 X99.701 Y122.843 E1.45186
G1 X99.701 Y123.234 E.01244
G1 X145.299 Y123.234 E1.45186
G1 X145.299 Y123.098 E.00431
G1 X139.78 Y126.131 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X138.461 Y125.215 I-2.289 J1.887 E.05395
G1 X140.044 Y123.632 E.07425
G1 X138.984 Y123.632 E.03514
G1 X144.795 Y129.443 E.27258
G1 X144.795 Y126.557 E.09572
G1 X138.984 Y132.368 E.27258
G1 X140.044 Y132.368 E.03514
G1 X138.461 Y130.785 E.07425
G2 X139.78 Y129.869 I-.971 J-2.804 E.05395
G1 X160.902 Y125.695 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54107
G1 F12000
G1 X160.904 Y124.906 E.03201
G1 X160.902 Y125.695 F36000
; LINE_WIDTH: 0.522449
G1 F12000
G1 X160.82 Y125.743 E.00372
; LINE_WIDTH: 0.481465
G1 X160.738 Y125.792 E.00341
; LINE_WIDTH: 0.420118
G1 X160.656 Y125.84 E.00293
G1 X145.494 Y125.84 E.46601
; LINE_WIDTH: 0.440489
G1 X145.412 Y125.792 E.00309
; LINE_WIDTH: 0.481485
G1 X145.33 Y125.743 E.00341
; LINE_WIDTH: 0.522482
G1 X145.248 Y125.695 E.00372
G1 X145.228 Y125.846 E.00596
; LINE_WIDTH: 0.481485
G1 X145.207 Y125.997 E.00545
; LINE_WIDTH: 0.4208
G1 X145.187 Y126.148 E.00469
G1 X145.187 Y129.852 E.11407
; LINE_WIDTH: 0.439859
G1 X145.207 Y130.018 E.00539
; LINE_WIDTH: 0.479595
G1 X145.226 Y130.183 E.00593
; LINE_WIDTH: 0.519332
G1 X145.246 Y130.349 E.00647
G1 X145.329 Y130.286 E.00403
; LINE_WIDTH: 0.479595
G1 X145.412 Y130.223 E.0037
; LINE_WIDTH: 0.420126
G1 X145.494 Y130.16 E.00319
G1 X160.656 Y130.16 E.46602
; LINE_WIDTH: 0.439859
G1 X160.738 Y130.223 E.00336
; LINE_WIDTH: 0.479595
G1 X160.821 Y130.286 E.0037
; LINE_WIDTH: 0.519332
G1 X160.904 Y130.349 E.00403
G1 X160.924 Y130.183 E.00647
; LINE_WIDTH: 0.479595
G1 X160.943 Y130.018 E.00593
; LINE_WIDTH: 0.420845
G1 X160.963 Y129.852 E.00513
G1 X160.963 Y126.148 E.11408
; LINE_WIDTH: 0.440482
G1 X160.946 Y126.017 E.00429
; LINE_WIDTH: 0.481465
G1 X160.928 Y125.885 E.00473
; LINE_WIDTH: 0.522449
G1 X160.91 Y125.754 E.00517
G1 X160.586 Y126.217 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X145.564 Y126.217 E.46159
G1 X145.564 Y129.783 E.10956
G1 X160.586 Y129.783 E.46159
G1 X160.586 Y126.277 E.10772
G1 X160.209 Y126.594 F36000
G1 F12000
G1 X145.941 Y126.594 E.43842
G1 X145.941 Y129.406 E.08639
G1 X160.209 Y129.406 E.43842
G1 X160.209 Y126.654 E.08455
G1 X159.832 Y126.971 F36000
G1 F12000
G1 X146.318 Y126.971 E.41525
G1 X146.318 Y129.029 E.06322
G1 X159.832 Y129.029 E.41525
G1 X159.832 Y127.031 E.06138
G1 X159.455 Y127.348 F36000
G1 F12000
G1 X146.695 Y127.348 E.39207
G1 X146.695 Y128.652 E.04005
G1 X159.455 Y128.652 E.39207
G1 X159.455 Y127.408 E.0382
G1 X159.035 Y127.768 F36000
; LINE_WIDTH: 0.50606
G1 F12000
G1 X147.115 Y127.768 E.44986
G1 X147.115 Y128.232 E.01748
G1 X159.035 Y128.232 E.44986
G1 X159.035 Y127.828 E.01522
G1 X160.904 Y131.154 F36000
; LINE_WIDTH: 0.5392
G1 F12000
G1 X160.904 Y130.409 E.03015
; WIPE_START
G1 X160.904 Y131.154 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.271 Y131.154 Z5.6 F36000
G1 X145.246 Y131.154 Z5.6
G1 Z5.2
G1 E.8 F1800
G1 F12000
G1 X145.246 Y130.409 E.03015
G1 X145.246 Y124.846 F36000
G1 F12000
G1 X145.246 Y125.635 E.0319
; WIPE_START
G1 X145.246 Y124.846 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.632 Y122.921 Z5.6 F36000
G1 X160.8 Y120.792 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X161.355 Y125.349 E.02554
G1 X161.355 Y130.652 E.17591
G1 X161.9 Y131.196 E.02554
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.208 E.05401
; WIPE_START
G1 X160.8 Y133.579 E-.61876
G1 X161.063 Y133.317 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.512 Y132.207 Z5.6 F36000
G1 X109.369 Y125.721 Z5.6
G1 Z5.2
G1 E.8 F1800
G1 F15476.087
G2 X107.897 Y125.075 I-1.912 J2.36 E.05396
G1 X109.34 Y123.632 E.06769
G1 X108.28 Y123.632 E.03514
G1 X117.016 Y132.368 E.40979
G1 X115.956 Y132.368 E.03514
G1 X124.692 Y123.632 E.40979
G1 X123.632 Y123.632 E.03514
G1 X132.368 Y132.368 E.40979
G1 X131.308 Y132.368 E.03514
G1 X134.715 Y128.961 E.15982
G3 X134.715 Y127.039 I3.177 J-.961 E.06468
G1 X131.308 Y123.632 E.15982
G1 X132.368 Y123.632 E.03514
G1 X123.632 Y132.368 E.40979
G1 X124.692 Y132.368 E.03514
G1 X115.956 Y123.632 E.40979
G1 X117.016 Y123.632 E.03514
G1 X108.28 Y132.368 E.40979
G1 X109.34 Y132.368 E.03514
G1 X107.897 Y130.925 E.06769
G1 X108.075 Y130.889 E.00601
G2 X109.369 Y130.279 I-.584 J-2.918 E.04793
; WIPE_START
G1 X108.63 Y130.728 E-.32849
G1 X108.075 Y130.889 E-.21972
G1 X107.897 Y130.925 E-.06889
G1 X108.163 Y131.191 E-.1429
; WIPE_END
G1 E-.04 F1800
G1 X101.509 Y127.452 Z5.6 F36000
G1 X100.205 Y126.719 Z5.6
G1 Z5.2
G1 E.8 F1800
G1 F15476.087
G1 X100.205 Y125.091 E.05401
G1 X101.664 Y123.632 E.06842
G1 X100.604 Y123.632 E.03514
G1 X104.575 Y127.603 E.18627
G2 X104.575 Y128.397 I34.322 J.396 E.02633
G1 X100.604 Y132.368 E.18628
G1 X101.664 Y132.368 E.03514
G1 X100.205 Y130.909 E.06842
G1 X100.205 Y129.281 E.05401
G1 X99.752 Y125.695 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54109
G1 F12000
G1 X99.754 Y124.906 E.03202
G1 X99.752 Y125.695 F36000
; LINE_WIDTH: 0.522465
G1 F12000
G1 X99.67 Y125.743 E.00372
; LINE_WIDTH: 0.481475
G1 X99.588 Y125.792 E.00341
; LINE_WIDTH: 0.420053
G1 X99.506 Y125.84 E.00293
G1 X86.144 Y125.84 E.41062
G1 X86.144 Y130.16 E.13276
G1 X99.506 Y130.16 E.41062
; LINE_WIDTH: 0.439862
G1 X99.588 Y130.223 E.00336
; LINE_WIDTH: 0.479605
G1 X99.671 Y130.286 E.0037
; LINE_WIDTH: 0.519349
G1 X99.754 Y130.349 E.00403
G1 X99.774 Y130.183 E.00647
; LINE_WIDTH: 0.479605
G1 X99.793 Y130.018 E.00593
; LINE_WIDTH: 0.420846
G1 X99.813 Y129.852 E.00513
G1 X99.813 Y126.148 E.11408
; LINE_WIDTH: 0.440485
G1 X99.796 Y126.017 E.00429
; LINE_WIDTH: 0.481475
G1 X99.778 Y125.885 E.00473
; LINE_WIDTH: 0.522465
G1 X99.76 Y125.754 E.00517
G1 X99.436 Y126.217 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X86.521 Y126.217 E.39683
G1 X86.521 Y129.783 E.10956
G1 X99.436 Y129.783 E.39683
G1 X99.436 Y126.277 E.10772
G1 X99.059 Y126.594 F36000
G1 F12000
G1 X86.898 Y126.594 E.37366
G1 X86.898 Y129.406 E.08639
G1 X99.059 Y129.406 E.37366
G1 X99.059 Y126.654 E.08455
G1 X98.682 Y126.971 F36000
G1 F12000
G1 X87.275 Y126.971 E.35049
G1 X87.275 Y129.029 E.06322
G1 X98.682 Y129.029 E.35049
G1 X98.682 Y127.031 E.06138
G1 X98.305 Y127.348 F36000
G1 F12000
G1 X87.652 Y127.348 E.32732
G1 X87.652 Y128.652 E.04005
G1 X98.305 Y128.652 E.32732
G1 X98.305 Y127.408 E.0382
G1 X97.885 Y127.768 F36000
; LINE_WIDTH: 0.50606
G1 F12000
G1 X88.073 Y127.768 E.37032
G1 X88.073 Y128.232 E.01748
G1 X97.885 Y128.232 E.37032
G1 X97.885 Y127.828 E.01522
G1 X99.754 Y131.154 F36000
; LINE_WIDTH: 0.53922
G1 F12000
G1 X99.754 Y130.409 E.03015
G1 X99.701 Y133.157 F36000
; LINE_WIDTH: 0.43365
G1 F12000
G1 X145.299 Y133.157 E1.45182
G1 X145.299 Y132.766 E.01244
G1 X99.701 Y132.766 E1.45182
G1 X99.701 Y133.097 E.01053
; CHANGE_LAYER
; Z_HEIGHT: 5.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X99.701 Y132.766 E-.12568
M73 P81 R3
G1 X101.37 Y132.766 E-.63432
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
G1 X135.45 Y129.602
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.442 Y129.579 E.00081
G3 X137.315 Y125.409 I2.066 J-1.578 E.18528
G3 X139.085 Y125.935 I.2 J2.57 E.06264
G3 X135.665 Y129.835 I-1.577 J2.066 E.28261
G1 X135.491 Y129.646 E.00852
G1 X135.746 Y129.346 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.753 Y129.341 E.00024
G3 X137.34 Y125.8 I1.755 J-1.339 E.14563
G3 X138.605 Y126.086 I.156 J2.251 E.04041
G3 X135.942 Y129.558 I-1.097 J1.916 E.23133
G1 X135.787 Y129.39 E.00702
; WIPE_START
M204 S10000
G1 X135.753 Y129.341 E-.0228
G1 X135.586 Y129.105 E-.1097
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10987
G1 X135.308 Y128.289 E-.10986
G1 X135.29 Y128 E-.10989
G1 X135.308 Y127.711 E-.10989
G1 X135.349 Y127.51 E-.0781
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.098 Z5.8 F36000
G1 X105.935 Y125.922 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.203 Y125.753 E.01051
G3 X107.315 Y125.409 I1.305 J2.249 E.03895
G3 X109.085 Y125.935 I.2 J2.57 E.06264
G3 X105.893 Y125.964 I-1.577 J2.068 E.42801
G1 X106.154 Y126.246 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X106.16 Y126.253 E.00026
G3 X107.34 Y125.8 I1.348 J1.748 E.03941
G3 X108.605 Y126.086 I.156 J2.251 E.04041
G3 X105.944 Y126.443 I-1.097 J1.916 E.33756
G1 X106.11 Y126.287 E.00702
; WIPE_START
M204 S10000
G1 X106.16 Y126.253 E-.0228
G1 X106.395 Y126.086 E-.10969
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.34 Y125.8 E-.15867
G1 X107.5 Y125.79 E-.06078
G1 X107.789 Y125.808 E-.10989
G1 X107.991 Y125.849 E-.07841
; WIPE_END
G1 E-.04 F1800
G1 X115.623 Y125.838 Z5.8 F36000
G1 X145.698 Y125.794 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y125.794 E.48942
G1 X160.452 Y120.127 E.18799
G1 X162.248 Y120.127 E.05957
G1 X162.248 Y135.873 E.52231
G1 X160.452 Y135.873 E.05957
G1 X160.452 Y130.206 E.18799
G1 X145.698 Y130.206 E.48942
G1 X145.698 Y133.389 E.10559
G1 X99.302 Y133.389 E1.53904
G1 X99.302 Y130.206 E.10559
G1 X85.752 Y130.206 E.44948
G1 X85.752 Y125.794 E.14634
G1 X99.302 Y125.794 E.44948
G1 X99.302 Y122.611 E.10559
G1 X145.698 Y122.611 E1.53904
G1 X145.698 Y125.734 E.1036
G1 X146.09 Y125.402 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y125.402 E.42926
G1 X160.06 Y119.735 E.17413
G1 X162.64 Y119.735 E.07928
G1 X162.64 Y136.265 E.50792
G1 X160.06 Y136.265 E.07928
G1 X160.06 Y130.598 E.17413
G1 X146.09 Y130.598 E.42926
G1 X146.09 Y133.781 E.09781
G1 X98.91 Y133.781 E1.44971
G1 X98.91 Y130.598 E.09781
G1 X85.36 Y130.598 E.41635
G1 X85.36 Y125.402 E.15965
G1 X98.91 Y125.402 E.41635
G1 X98.91 Y122.219 E.09781
G1 X146.09 Y122.219 E1.44971
G1 X146.09 Y125.342 E.09597
; WIPE_START
M204 S10000
G1 X148.09 Y125.351 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.284 Y123.235 Z5.8 F36000
G1 Z5.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.463325
G1 F12000
G1 X145.284 Y123.025 E.0072
G1 X99.716 Y123.025 E1.56107
G1 X99.716 Y123.445 E.0144
G1 X145.284 Y123.445 E1.56107
G1 X145.284 Y123.295 E.00515
G1 X139.78 Y129.869 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X138.461 Y130.785 I-2.289 J-1.887 E.05395
G1 X139.817 Y132.141 E.06363
G1 X139.211 Y132.141 E.02012
G1 X144.795 Y126.557 E.26196
G1 X144.795 Y129.443 E.09572
G1 X139.211 Y123.859 E.26196
G1 X139.817 Y123.859 E.02012
G1 X138.461 Y125.215 E.06363
G3 X139.78 Y126.131 I-.97 J2.804 E.05395
G1 X160.902 Y126.041 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.539272
G1 F12000
G2 X160.904 Y124.906 I-13.105 J-.589 E.04592
G1 X160.902 Y126.041 F36000
; LINE_WIDTH: 0.522449
G1 F12000
G1 X160.82 Y126.089 E.00372
; LINE_WIDTH: 0.481465
G1 X160.738 Y126.138 E.00341
; LINE_WIDTH: 0.420118
G1 X160.656 Y126.186 E.00293
G1 X145.494 Y126.186 E.46601
; LINE_WIDTH: 0.440489
G1 X145.412 Y126.138 E.00309
; LINE_WIDTH: 0.481485
G1 X145.33 Y126.089 E.00341
; LINE_WIDTH: 0.522482
G1 X145.248 Y126.041 E.00372
G1 X145.228 Y126.192 E.00596
; LINE_WIDTH: 0.481485
G1 X145.207 Y126.343 E.00545
; LINE_WIDTH: 0.420978
G1 X145.187 Y126.494 E.0047
G1 X145.187 Y129.506 E.09279
; LINE_WIDTH: 0.439859
G1 X145.207 Y129.671 E.00539
; LINE_WIDTH: 0.479595
G1 X145.226 Y129.837 E.00593
; LINE_WIDTH: 0.519332
G1 X145.246 Y130.002 E.00647
G1 X145.329 Y129.939 E.00403
; LINE_WIDTH: 0.479595
G1 X145.412 Y129.877 E.0037
; LINE_WIDTH: 0.420126
G1 X145.494 Y129.814 E.00319
G1 X160.656 Y129.814 E.46602
; LINE_WIDTH: 0.439859
G1 X160.738 Y129.877 E.00336
; LINE_WIDTH: 0.479595
G1 X160.821 Y129.939 E.0037
; LINE_WIDTH: 0.519332
G1 X160.904 Y130.002 E.00403
G1 X160.924 Y129.837 E.00647
; LINE_WIDTH: 0.479595
G1 X160.943 Y129.671 E.00593
; LINE_WIDTH: 0.421032
G1 X160.963 Y129.506 E.00513
G1 X160.963 Y126.494 E.0928
; LINE_WIDTH: 0.440482
G1 X160.946 Y126.363 E.00429
; LINE_WIDTH: 0.481465
G1 X160.928 Y126.232 E.00473
; LINE_WIDTH: 0.522449
G1 X160.91 Y126.1 E.00517
G1 X160.586 Y126.563 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X145.564 Y126.563 E.46159
G1 X145.564 Y129.437 E.08829
G1 X160.586 Y129.437 E.46159
G1 X160.586 Y126.623 E.08645
G1 X160.209 Y126.94 F36000
G1 F12000
G1 X145.941 Y126.94 E.43842
G1 X145.941 Y129.06 E.06512
G1 X160.209 Y129.06 E.43842
G1 X160.209 Y127 E.06327
G1 X159.832 Y127.317 F36000
G1 F12000
G1 X146.318 Y127.317 E.41525
G1 X146.318 Y128.683 E.04195
G1 X159.832 Y128.683 E.41525
G1 X159.832 Y127.377 E.0401
G1 X159.397 Y127.753 F36000
; LINE_WIDTH: 0.53694
G1 F12000
G1 X146.753 Y127.753 E.50897
G1 X146.753 Y128.247 E.01989
G1 X159.397 Y128.247 E.50897
G1 X159.397 Y127.813 E.01747
G1 X160.904 Y131.154 F36000
; LINE_WIDTH: 0.5392
G1 F12000
G1 X160.904 Y130.062 E.04415
; WIPE_START
G1 X160.904 Y131.154 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.271 Y131.154 Z5.8 F36000
G1 X145.246 Y131.154 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F12000
G1 X145.246 Y130.062 E.04415
G1 X145.246 Y124.846 F36000
G1 F12000
G1 X145.246 Y125.981 E.0459
; WIPE_START
G1 X145.246 Y124.846 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X151.598 Y129.078 Z5.8 F36000
G1 X160.8 Y135.208 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X161.355 Y130.652 E.02554
G1 X161.355 Y125.349 E.17591
G1 X161.9 Y124.804 E.02554
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
; WIPE_START
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.512 Y123.793 Z5.8 F36000
G1 X109.369 Y130.279 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F15476.087
G3 X107.897 Y130.925 I-1.912 J-2.36 E.05396
G1 X109.113 Y132.141 E.05707
G1 X108.507 Y132.141 E.02012
G1 X116.789 Y123.859 E.38855
G1 X116.183 Y123.859 E.02012
G1 X124.465 Y132.141 E.38855
G1 X123.859 Y132.141 E.02012
G1 X132.141 Y123.859 E.38855
G1 X131.535 Y123.859 E.02012
G1 X134.715 Y127.039 E.1492
G2 X134.715 Y128.961 I3.178 J.961 E.06468
G1 X131.535 Y132.141 E.1492
G1 X132.141 Y132.141 E.02012
G1 X123.859 Y123.859 E.38855
G1 X124.465 Y123.859 E.02012
G1 X116.183 Y132.141 E.38855
G1 X116.789 Y132.141 E.02012
G1 X108.507 Y123.859 E.38855
G1 X109.113 Y123.859 E.02012
G1 X107.897 Y125.075 E.05707
G3 X109.369 Y125.721 I-.44 J3.006 E.05396
; WIPE_START
G1 X108.63 Y125.272 E-.32853
G1 X107.897 Y125.075 E-.28837
G1 X108.163 Y124.809 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X100.742 Y126.59 Z5.8 F36000
G1 X100.205 Y126.719 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F15476.087
G1 X100.205 Y125.091 E.05401
G1 X101.437 Y123.859 E.0578
G1 X100.831 Y123.859 E.02012
G1 X104.575 Y127.603 E.17565
G2 X104.575 Y128.397 I3.43 J.397 E.02639
G1 X100.831 Y132.141 E.17565
G1 X101.437 Y132.141 E.02012
G1 X100.205 Y130.909 E.0578
G1 X100.205 Y129.281 E.05401
G1 X99.752 Y126.041 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.539292
G1 F12000
G2 X99.754 Y124.906 I-13.108 J-.589 E.04592
G1 X99.752 Y126.041 F36000
; LINE_WIDTH: 0.522465
G1 F12000
G1 X99.67 Y126.089 E.00372
; LINE_WIDTH: 0.481475
G1 X99.588 Y126.138 E.00341
; LINE_WIDTH: 0.420055
G1 X99.506 Y126.186 E.00293
G1 X86.144 Y126.186 E.41062
G1 X86.144 Y129.814 E.11148
G1 X99.506 Y129.814 E.41062
; LINE_WIDTH: 0.439862
G1 X99.588 Y129.877 E.00336
; LINE_WIDTH: 0.479605
G1 X99.671 Y129.939 E.0037
; LINE_WIDTH: 0.519349
G1 X99.754 Y130.002 E.00403
G1 X99.774 Y129.837 E.00647
; LINE_WIDTH: 0.479605
G1 X99.793 Y129.671 E.00593
; LINE_WIDTH: 0.421032
G1 X99.813 Y129.506 E.00513
G1 X99.813 Y126.494 E.0928
; LINE_WIDTH: 0.440485
G1 X99.796 Y126.363 E.00429
; LINE_WIDTH: 0.481475
G1 X99.778 Y126.232 E.00473
; LINE_WIDTH: 0.522465
G1 X99.76 Y126.1 E.00517
G1 X99.436 Y126.563 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X86.521 Y126.563 E.39683
G1 X86.521 Y129.437 E.08829
G1 X99.436 Y129.437 E.39683
G1 X99.436 Y126.623 E.08645
G1 X99.059 Y126.94 F36000
G1 F12000
G1 X86.898 Y126.94 E.37366
G1 X86.898 Y129.06 E.06512
G1 X99.059 Y129.06 E.37366
G1 X99.059 Y127 E.06327
G1 X98.682 Y127.317 F36000
G1 F12000
G1 X87.275 Y127.317 E.35049
G1 X87.275 Y128.683 E.04195
G1 X98.682 Y128.683 E.35049
G1 X98.682 Y127.377 E.0401
G1 X98.247 Y127.753 F36000
; LINE_WIDTH: 0.53694
G1 F12000
G1 X87.711 Y127.753 E.42413
G1 X87.711 Y128.247 E.01989
G1 X98.247 Y128.247 E.42413
G1 X98.247 Y127.813 E.01747
G1 X99.754 Y131.154 F36000
; LINE_WIDTH: 0.53922
G1 F12000
G1 X99.754 Y130.062 E.04415
G1 X99.716 Y132.975 F36000
; LINE_WIDTH: 0.46332
G1 F12000
G1 X145.284 Y132.975 E1.56105
G1 X145.284 Y132.555 E.0144
G1 X99.716 Y132.555 E1.56105
G1 X99.716 Y132.915 E.01235
; CHANGE_LAYER
; Z_HEIGHT: 5.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X99.716 Y132.555 E-.13695
G1 X101.355 Y132.555 E-.62305
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
G1 X135.45 Y129.602
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
M73 P82 R3
G1 F15476.087
G1 X135.442 Y129.579 E.00081
G3 X137.299 Y125.41 I2.067 J-1.578 E.18477
G3 X138.802 Y125.745 I.196 J2.652 E.0518
G3 X135.665 Y129.835 I-1.293 J2.256 E.29411
G1 X135.491 Y129.646 E.00852
G1 X135.747 Y129.346 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.754 Y129.34 E.00029
G3 X137.325 Y125.801 I1.754 J-1.34 E.14513
G3 X138.605 Y126.086 I.171 J2.252 E.04089
G3 X135.943 Y129.557 I-1.098 J1.915 E.23117
G1 X135.787 Y129.39 E.00702
; WIPE_START
M204 S10000
G1 X135.754 Y129.34 E-.02284
G1 X135.586 Y129.105 E-.10968
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10988
G1 X135.349 Y127.51 E-.07809
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z6 F36000
G1 X105.898 Y125.95 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.921 Y125.942 E.00082
G3 X107.299 Y125.41 I1.588 J2.059 E.0497
G3 X108.802 Y125.745 I.196 J2.652 E.0518
G3 X105.667 Y126.167 I-1.293 J2.256 E.4292
G1 X105.854 Y125.991 E.00852
G1 X106.154 Y126.247 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X106.16 Y126.253 E.00026
G3 X107.325 Y125.801 I1.348 J1.747 E.03894
G3 X108.605 Y126.086 I.171 J2.252 E.04089
G3 X105.944 Y126.443 I-1.098 J1.915 E.33736
G1 X106.11 Y126.288 E.00702
; WIPE_START
M204 S10000
G1 X106.16 Y126.253 E-.02284
G1 X106.395 Y126.086 E-.10968
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.325 Y125.801 E-.15285
G1 X107.5 Y125.79 E-.06663
G1 X107.789 Y125.808 E-.10988
G1 X107.991 Y125.849 E-.07837
; WIPE_END
G1 E-.04 F1800
G1 X115.623 Y125.922 Z6 F36000
G1 X145.698 Y126.21 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y126.21 E.48942
G1 X160.452 Y120.253 E.19758
G1 X162.248 Y120.253 E.05957
G1 X162.248 Y135.747 E.51394
G1 X160.452 Y135.747 E.05957
G1 X160.452 Y129.79 E.19758
G1 X145.698 Y129.79 E.48942
G1 X145.698 Y133.202 E.11316
G1 X99.302 Y133.202 E1.53904
G1 X99.302 Y129.79 E.11316
G1 X85.752 Y129.79 E.44948
G1 X85.752 Y126.21 E.11878
G1 X99.302 Y126.21 E.44948
G1 X99.302 Y122.798 E.11316
G1 X145.698 Y122.798 E1.53904
G1 X145.698 Y126.15 E.11117
G1 X146.09 Y125.818 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y125.818 E.42926
G1 X160.06 Y119.861 E.18302
G1 X162.64 Y119.861 E.07928
G1 X162.64 Y136.139 E.50016
G1 X160.06 Y136.139 E.07928
G1 X160.06 Y130.182 E.18302
G1 X146.09 Y130.182 E.42926
G1 X146.09 Y133.594 E.10482
G1 X98.91 Y133.594 E1.44971
G1 X98.91 Y130.182 E.10482
G1 X85.36 Y130.182 E.41635
G1 X85.36 Y125.818 E.13412
G1 X98.91 Y125.818 E.41635
G1 X98.91 Y122.406 E.10482
G1 X146.09 Y122.406 E1.44971
G1 X146.09 Y125.758 E.10298
; WIPE_START
M204 S10000
G1 X148.09 Y125.766 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.27 Y123.45 Z6 F36000
G1 Z5.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.491515
G1 F12000
G1 X145.27 Y123.226 E.0082
G1 X99.73 Y123.226 E1.66471
G1 X99.73 Y123.675 E.0164
G1 X145.27 Y123.675 E1.66471
G1 X145.27 Y123.51 E.00601
G1 X139.78 Y126.131 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X138.461 Y125.215 I-2.289 J1.887 E.05395
G1 X139.573 Y124.102 E.05219
G1 X139.454 Y124.102 E.00395
G1 X144.795 Y129.443 E.25053
G1 X144.795 Y126.557 E.09572
G1 X139.454 Y131.898 E.25053
G1 X139.574 Y131.898 E.00395
G1 X138.461 Y130.785 E.05219
G2 X139.78 Y129.869 I-1.189 J-3.118 E.0538
G1 X160.902 Y126.456 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.539253
G1 F12000
G1 X160.904 Y124.906 E.0627
G1 X160.902 Y126.456 F36000
; LINE_WIDTH: 0.522449
G1 F12000
G1 X160.82 Y126.505 E.00372
; LINE_WIDTH: 0.481465
G1 X160.738 Y126.553 E.00341
; LINE_WIDTH: 0.420118
G1 X160.656 Y126.602 E.00293
G1 X145.494 Y126.602 E.46601
; LINE_WIDTH: 0.440489
G1 X145.412 Y126.553 E.00309
; LINE_WIDTH: 0.481485
G1 X145.33 Y126.505 E.00341
; LINE_WIDTH: 0.522482
G1 X145.248 Y126.456 E.00372
G1 X145.228 Y126.607 E.00596
; LINE_WIDTH: 0.481485
G1 X145.207 Y126.758 E.00545
; LINE_WIDTH: 0.421329
G1 X145.187 Y126.909 E.0047
G1 X145.187 Y129.091 E.06726
; LINE_WIDTH: 0.439859
G1 X145.207 Y129.256 E.00539
; LINE_WIDTH: 0.479595
G1 X145.226 Y129.421 E.00593
; LINE_WIDTH: 0.519332
G1 X145.246 Y129.587 E.00647
G1 X145.329 Y129.524 E.00403
; LINE_WIDTH: 0.479595
G1 X145.412 Y129.461 E.0037
; LINE_WIDTH: 0.420126
G1 X145.494 Y129.398 E.00319
G1 X160.656 Y129.398 E.46602
; LINE_WIDTH: 0.439859
G1 X160.738 Y129.461 E.00336
; LINE_WIDTH: 0.479595
G1 X160.821 Y129.524 E.0037
; LINE_WIDTH: 0.519332
G1 X160.904 Y129.587 E.00403
G1 X160.924 Y129.421 E.00647
; LINE_WIDTH: 0.479595
G1 X160.943 Y129.256 E.00593
; LINE_WIDTH: 0.4214
G1 X160.963 Y129.091 E.00514
G1 X160.963 Y126.909 E.06727
; LINE_WIDTH: 0.440482
G1 X160.946 Y126.778 E.00429
; LINE_WIDTH: 0.481465
G1 X160.928 Y126.647 E.00473
; LINE_WIDTH: 0.522449
G1 X160.91 Y126.516 E.00517
G1 X160.586 Y126.979 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X145.564 Y126.979 E.46159
G1 X145.564 Y129.021 E.06276
G1 X160.586 Y129.021 E.46159
G1 X160.586 Y127.039 E.06091
G1 X160.209 Y127.356 F36000
G1 F12000
G1 X145.941 Y127.356 E.43842
G1 X145.941 Y128.644 E.03959
G1 X160.209 Y128.644 E.43842
G1 X160.209 Y127.416 E.03774
G1 X159.793 Y127.772 F36000
; LINE_WIDTH: 0.49855
G1 F12000
G1 X146.357 Y127.772 E.49884
G1 X146.357 Y128.228 E.01692
G1 X159.793 Y128.228 E.49884
G1 X159.793 Y127.832 E.01469
; WIPE_START
G1 X159.793 Y128.228 E-.15034
G1 X158.189 Y128.228 E-.60966
; WIPE_END
G1 E-.04 F1800
G1 X160.904 Y131.154 Z6 F36000
G1 Z5.6
G1 E.8 F1800
; LINE_WIDTH: 0.5392
G1 F12000
G1 X160.904 Y129.647 E.06095
; WIPE_START
G1 X160.904 Y131.154 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.271 Y131.154 Z6 F36000
G1 X145.246 Y131.154 Z6
G1 Z5.6
G1 E.8 F1800
G1 F12000
G1 X145.246 Y129.647 E.06095
G1 X145.246 Y124.846 F36000
G1 F12000
G1 X145.246 Y126.396 E.0627
; WIPE_START
G1 X145.246 Y124.846 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.632 Y122.921 Z6 F36000
G1 X160.8 Y120.792 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X161.355 Y125.349 E.02554
G1 X161.355 Y130.652 E.17591
G1 X161.9 Y131.196 E.02554
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.208 E.05401
; WIPE_START
G1 X160.8 Y133.579 E-.61876
G1 X161.063 Y133.317 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.512 Y132.207 Z6 F36000
G1 X109.369 Y125.721 Z6
G1 Z5.6
G1 E.8 F1800
G1 F15476.087
G2 X107.897 Y125.075 I-1.912 J2.36 E.05396
G1 X108.87 Y124.102 E.04563
G1 X108.751 Y124.102 E.00395
G1 X116.546 Y131.898 E.36568
G1 X116.426 Y131.898 E.00395
G1 X124.222 Y124.102 E.36568
G1 X124.102 Y124.102 E.00395
G1 X131.898 Y131.898 E.36568
G1 X131.778 Y131.898 E.00395
G1 X134.715 Y128.961 E.13776
G3 X134.715 Y127.039 I3.177 J-.961 E.06468
G1 X131.778 Y124.102 E.13776
G1 X131.898 Y124.102 E.00395
G1 X124.102 Y131.898 E.36568
G1 X124.222 Y131.898 E.00395
G1 X116.426 Y124.102 E.36568
G1 X116.546 Y124.102 E.00395
G1 X108.751 Y131.898 E.36568
G1 X108.87 Y131.898 E.00395
G1 X107.897 Y130.925 E.04563
G2 X109.369 Y130.279 I-.44 J-3.005 E.05396
; WIPE_START
G1 X108.63 Y130.728 E-.32848
G1 X107.897 Y130.925 E-.28841
G1 X108.163 Y131.191 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X100.742 Y129.41 Z6 F36000
G1 X100.205 Y129.281 Z6
G1 Z5.6
G1 E.8 F1800
G1 F15476.087
G1 X100.205 Y130.909 E.05401
G1 X101.194 Y131.898 E.04637
G1 X101.075 Y131.898 E.00395
G1 X104.575 Y128.397 E.16422
G3 X104.575 Y127.603 I34.321 J-.396 E.02633
G1 X101.075 Y124.102 E.16422
G1 X101.194 Y124.102 E.00395
G1 X100.205 Y125.091 E.04637
G1 X100.205 Y126.719 E.05401
G1 X99.752 Y126.456 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.539272
G1 F12000
G1 X99.754 Y124.906 E.06271
G1 X99.752 Y126.456 F36000
; LINE_WIDTH: 0.522465
G1 F12000
G1 X99.67 Y126.505 E.00372
; LINE_WIDTH: 0.481475
G1 X99.588 Y126.553 E.00341
; LINE_WIDTH: 0.420056
G1 X99.506 Y126.602 E.00293
G1 X86.144 Y126.602 E.41062
G1 X86.144 Y129.398 E.08595
G1 X99.506 Y129.398 E.41062
; LINE_WIDTH: 0.439862
G1 X99.588 Y129.461 E.00336
; LINE_WIDTH: 0.479605
G1 X99.671 Y129.524 E.0037
; LINE_WIDTH: 0.519349
G1 X99.754 Y129.587 E.00403
G1 X99.774 Y129.421 E.00647
; LINE_WIDTH: 0.479605
G1 X99.793 Y129.256 E.00593
; LINE_WIDTH: 0.421401
G1 X99.813 Y129.091 E.00514
G1 X99.813 Y126.909 E.06727
; LINE_WIDTH: 0.440485
G1 X99.796 Y126.778 E.00429
; LINE_WIDTH: 0.481475
G1 X99.778 Y126.647 E.00473
; LINE_WIDTH: 0.522465
G1 X99.76 Y126.516 E.00517
G1 X99.436 Y126.979 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X86.521 Y126.979 E.39683
G1 X86.521 Y129.021 E.06276
G1 X99.436 Y129.021 E.39683
G1 X99.436 Y127.039 E.06091
G1 X99.059 Y127.356 F36000
G1 F12000
G1 X86.898 Y127.356 E.37366
G1 X86.898 Y128.644 E.03959
G1 X99.059 Y128.644 E.37366
G1 X99.059 Y127.416 E.03774
G1 X98.643 Y127.772 F36000
; LINE_WIDTH: 0.49855
G1 F12000
G1 X87.315 Y127.772 E.4206
G1 X87.315 Y128.228 E.01692
G1 X98.643 Y128.228 E.4206
G1 X98.643 Y127.832 E.01469
; WIPE_START
G1 X98.643 Y128.228 E-.15034
G1 X97.038 Y128.228 E-.60966
; WIPE_END
G1 E-.04 F1800
G1 X99.754 Y131.154 Z6 F36000
G1 Z5.6
G1 E.8 F1800
; LINE_WIDTH: 0.53922
G1 F12000
G1 X99.754 Y129.647 E.06095
G1 X99.73 Y132.774 F36000
; LINE_WIDTH: 0.49151
G1 F12000
G1 X145.27 Y132.774 E1.6647
G1 X145.27 Y132.325 E.0164
G1 X99.73 Y132.325 E1.6647
G1 X99.73 Y132.714 E.01421
; CHANGE_LAYER
; Z_HEIGHT: 5.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X99.73 Y132.325 E-.14767
G1 X101.341 Y132.325 E-.61233
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
G1 X135.45 Y129.602
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.441 Y129.58 E.0008
G3 X137.284 Y125.411 I2.067 J-1.578 E.1843
G3 X138.802 Y125.745 I.211 J2.653 E.05232
G3 X135.665 Y129.836 I-1.293 J2.256 E.2941
G1 X135.491 Y129.646 E.00852
G1 X135.747 Y129.346 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.753 Y129.34 E.00027
G3 X137.31 Y125.802 I1.756 J-1.339 E.14466
G3 X138.346 Y125.958 I.206 J2.151 E.03252
G3 X135.943 Y129.558 I-.837 J2.043 E.24029
G1 X135.787 Y129.39 E.00702
; WIPE_START
M204 S10000
G1 X135.753 Y129.34 E-.02285
G1 X135.586 Y129.105 E-.10969
G1 X135.458 Y128.846 E-.10989
G1 X135.365 Y128.572 E-.10987
G1 X135.308 Y128.288 E-.10989
G1 X135.29 Y128 E-.10985
G1 X135.308 Y127.712 E-.10985
G1 X135.349 Y127.51 E-.0781
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.098 Z6.2 F36000
G1 X105.935 Y125.922 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.203 Y125.753 E.01051
G3 X107.284 Y125.411 I1.306 J2.249 E.03793
M73 P83 R3
G3 X108.802 Y125.745 I.211 J2.653 E.05231
G3 X105.893 Y125.964 I-1.293 J2.256 E.4393
G1 X106.154 Y126.247 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X106.16 Y126.253 E.00027
G3 X107.31 Y125.802 I1.349 J1.748 E.03847
G3 X108.346 Y125.958 I.206 J2.151 E.03252
G3 X105.944 Y126.444 I-.837 J2.043 E.34648
G1 X106.11 Y126.288 E.00702
; WIPE_START
M204 S10000
G1 X106.16 Y126.253 E-.02284
G1 X106.395 Y126.086 E-.10969
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.31 Y125.802 E-.14702
G1 X107.5 Y125.79 E-.07248
G1 X107.789 Y125.808 E-.10988
G1 X107.991 Y125.849 E-.07832
; WIPE_END
G1 E-.04 F1800
G1 X115.618 Y126.129 Z6.2 F36000
G1 X145.222 Y127.218 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X145.222 Y131.178 E.13137
G1 X145.698 Y131.178 E.01578
G1 X145.698 Y133.009 E.06073
G1 X99.302 Y133.009 E1.53904
G1 X99.302 Y131.178 E.06073
G1 X99.778 Y131.178 E.01578
G1 X99.778 Y124.822 E.21084
G1 X99.302 Y124.822 E.01578
G1 X99.302 Y122.991 E.06073
G1 X145.698 Y122.991 E1.53904
G1 X145.698 Y124.822 E.06073
G1 X145.222 Y124.822 E.01578
M73 P83 R2
G1 X145.222 Y127.158 E.07748
; WIPE_START
G1 X145.222 Y129.158 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.25 Y132.135 Z6.2 F36000
G1 X160.452 Y135.611 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F15476.087
G1 X160.452 Y131.178 E.14704
G1 X160.928 Y131.178 E.01578
G1 X160.928 Y124.822 E.21084
G1 X160.452 Y124.822 E.01578
G1 X160.452 Y120.389 E.14704
G1 X162.248 Y120.389 E.05957
G1 X162.248 Y135.611 E.50491
G1 X160.512 Y135.611 E.05758
; WIPE_START
G1 X160.485 Y133.611 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.67 Y130.173 Z6.2 F36000
G1 X146.09 Y126.35 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y126.35 E.42926
G1 X160.06 Y119.997 E.19519
G1 X162.64 Y119.997 E.07928
G1 X162.64 Y136.003 E.4918
G1 X160.06 Y136.003 E.07928
G1 X160.06 Y129.65 E.19519
G1 X146.09 Y129.65 E.42926
G1 X146.09 Y133.401 E.11525
G1 X98.91 Y133.401 E1.44971
G1 X98.91 Y129.65 E.11525
G1 X85.36 Y129.65 E.41635
G1 X85.36 Y126.35 E.10141
G1 X98.91 Y126.35 E.41635
G1 X98.91 Y122.599 E.11525
G1 X146.09 Y122.599 E1.44971
G1 X146.09 Y126.29 E.1134
; WIPE_START
M204 S10000
G1 X148.09 Y126.298 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.418 Y128 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.4379
G1 F15000
G1 X160.732 Y128 E.49287
G1 X160.657 Y128.928 F36000
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X159.953 Y128.224 E.03061
G1 X159.419 Y128.224
G1 X160.657 Y129.462 E.05378
G1 X160.657 Y129.995
G1 X160.267 Y129.605 E.01694
G1 X160.105 Y129.443
G1 X158.886 Y128.224 E.05296
G1 X158.353 Y128.224
G1 X159.572 Y129.443 E.05296
G1 X159.038 Y129.443
G1 X157.82 Y128.224 E.05296
G1 X157.286 Y128.224
G1 X158.505 Y129.443 E.05296
G1 X157.972 Y129.443
G1 X156.753 Y128.224 E.05296
G1 X156.22 Y128.224
G1 X157.439 Y129.443 E.05296
G1 X156.905 Y129.443
G1 X155.687 Y128.224 E.05296
G1 X155.153 Y128.224
G1 X156.372 Y129.443 E.05296
G1 X155.839 Y129.443
G1 X154.62 Y128.224 E.05296
G1 X154.087 Y128.224
G1 X155.306 Y129.443 E.05296
G1 X154.772 Y129.443
G1 X153.554 Y128.224 E.05296
G1 X153.02 Y128.224
G1 X154.239 Y129.443 E.05296
G1 X153.706 Y129.443
G1 X152.487 Y128.224 E.05296
G1 X151.954 Y128.224
G1 X153.173 Y129.443 E.05296
G1 X152.639 Y129.443
G1 X151.421 Y128.224 E.05296
G1 X150.887 Y128.224
G1 X152.106 Y129.443 E.05296
G1 X151.573 Y129.443
G1 X150.354 Y128.224 E.05296
G1 X149.821 Y128.224
G1 X151.04 Y129.443 E.05296
G1 X150.506 Y129.443
G1 X149.288 Y128.224 E.05296
G1 X148.754 Y128.224
G1 X149.973 Y129.443 E.05296
G1 X149.44 Y129.443
G1 X148.221 Y128.224 E.05296
G1 X147.688 Y128.224
G1 X148.907 Y129.443 E.05296
G1 X148.373 Y129.443
G1 X147.155 Y128.224 E.05296
G1 X146.621 Y128.224
G1 X147.84 Y129.443 E.05296
G1 X147.307 Y129.443
G1 X146.088 Y128.224 E.05296
G1 X145.555 Y128.224
G1 X146.774 Y129.443 E.05296
G1 X146.24 Y129.443
G1 X145.493 Y128.695 E.03248
G1 X145.493 Y129.229
G1 X145.883 Y129.618 E.01694
G1 X145.883 Y130.152
G1 X145.493 Y129.762 E.01694
M204 S10000
G1 X145.688 Y130.691 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50814
G1 F13541.982
G2 X145.686 Y130.792 I-.029 J.05 E.0091
; WIPE_START
G1 X145.629 Y130.792 E-.18544
G1 X145.6 Y130.742 E-.19152
G1 X145.629 Y130.691 E-.19154
G1 X145.688 Y130.691 E-.1915
; WIPE_END
G1 E-.04 F1800
G1 X139.779 Y129.866 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X138.461 Y130.785 I-2.276 J-1.86 E.05397
G1 X139.303 Y131.627 E.03949
G1 X139.725 Y131.627 E.01401
G1 X144.874 Y126.478 E.24154
G1 X144.874 Y129.522 E.10098
G1 X139.725 Y124.373 E.24154
G1 X139.303 Y124.373 E.01401
G1 X138.461 Y125.215 E.03949
G3 X139.78 Y126.131 I-.971 J2.804 E.05395
G1 X145.251 Y123.682 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53043
G1 F12000
G1 X145.251 Y123.439 E.00968
G1 X99.749 Y123.439 E1.80758
G1 X99.749 Y123.926 E.01937
G1 X145.251 Y123.926 E1.80758
G1 X145.251 Y123.742 E.0073
; WIPE_START
G1 X145.251 Y123.926 E-.06983
G1 X143.434 Y123.926 E-.69017
; WIPE_END
G1 E-.04 F1800
G1 X151.045 Y124.497 Z6.2 F36000
G1 X160.521 Y125.208 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50814
G1 F13541.982
G2 X160.519 Y125.309 I-.029 J.05 E.0091
G1 X160.657 Y126.262 F36000
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X160.267 Y125.872 E.01694
G1 X160.267 Y126.406
G1 X160.657 Y126.795 E.01694
G1 X160.657 Y127.329
G1 X159.886 Y126.557 E.03352
G1 X159.353 Y126.557
G1 X160.571 Y127.776 E.05296
G1 X160.038 Y127.776
G1 X158.819 Y126.557 E.05296
G1 X158.286 Y126.557
G1 X159.505 Y127.776 E.05296
G1 X158.972 Y127.776
G1 X157.753 Y126.557 E.05296
G1 X157.219 Y126.557
G1 X158.438 Y127.776 E.05296
G1 X157.905 Y127.776
G1 X156.686 Y126.557 E.05296
G1 X156.153 Y126.557
G1 X157.372 Y127.776 E.05296
G1 X156.839 Y127.776
G1 X155.62 Y126.557 E.05296
G1 X155.086 Y126.557
G1 X156.305 Y127.776 E.05296
G1 X155.772 Y127.776
G1 X154.553 Y126.557 E.05296
G1 X154.02 Y126.557
G1 X155.239 Y127.776 E.05296
G1 X154.706 Y127.776
G1 X153.487 Y126.557 E.05296
G1 X152.953 Y126.557
G1 X154.172 Y127.776 E.05296
G1 X153.639 Y127.776
G1 X152.42 Y126.557 E.05296
G1 X151.887 Y126.557
G1 X153.106 Y127.776 E.05296
G1 X152.572 Y127.776
G1 X151.354 Y126.557 E.05296
G1 X150.82 Y126.557
G1 X152.039 Y127.776 E.05296
G1 X151.506 Y127.776
G1 X150.287 Y126.557 E.05296
G1 X149.754 Y126.557
G1 X150.973 Y127.776 E.05296
G1 X150.439 Y127.776
G1 X149.221 Y126.557 E.05296
G1 X148.687 Y126.557
G1 X149.906 Y127.776 E.05296
G1 X149.373 Y127.776
G1 X148.154 Y126.557 E.05296
G1 X147.621 Y126.557
G1 X148.84 Y127.776 E.05296
G1 X148.306 Y127.776
G1 X147.088 Y126.557 E.05296
G1 X146.554 Y126.557
G1 X147.773 Y127.776 E.05296
G1 X147.24 Y127.776
G1 X146.021 Y126.557 E.05296
G1 X145.883 Y125.886
G1 X145.568 Y125.571 E.01368
G1 X145.493 Y126.029
G1 X145.883 Y126.419 E.01694
G1 X145.493 Y126.562
G1 X146.707 Y127.776 E.05274
G1 X146.173 Y127.776
G1 X145.493 Y127.096 E.02957
; WIPE_START
M204 S10000
G1 X146.173 Y127.776 E-.3657
G1 X146.707 Y127.776 E-.20264
G1 X146.35 Y127.419 E-.19167
; WIPE_END
G1 E-.04 F1800
G1 X153.936 Y126.575 Z6.2 F36000
G1 X160.724 Y125.82 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.328368
G1 F15000
G2 X160.383 Y125.605 I-.541 J.48 E.00949
; LINE_WIDTH: 0.289865
G1 X160.316 Y125.71 E.0025
; LINE_WIDTH: 0.244129
G1 X160.249 Y125.814 E.00204
; WIPE_START
G1 X160.316 Y125.71 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.705 Y133.332 Z6.2 F36000
G1 X160.8 Y135.208 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X161.276 Y130.572 E.02926
G1 X161.276 Y125.428 E.17065
G1 X161.9 Y124.804 E.02926
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y120.792 E.05401
; WIPE_START
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.512 Y123.793 Z6.2 F36000
G1 X109.369 Y130.279 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F15476.087
G3 X107.897 Y130.925 I-1.912 J-2.36 E.05396
G1 X108.599 Y131.627 E.03293
G1 X109.021 Y131.627 E.01401
G1 X116.275 Y124.373 E.34028
G1 X116.697 Y124.373 E.01402
G1 X123.951 Y131.627 E.34028
G1 X124.373 Y131.627 E.01401
G1 X131.627 Y124.373 E.34028
G1 X132.049 Y124.373 E.01402
G1 X134.715 Y127.039 E.12506
M73 P84 R2
G2 X134.715 Y128.961 I3.178 J.961 E.06468
G1 X132.049 Y131.627 E.12506
G1 X131.627 Y131.627 E.01401
G1 X124.373 Y124.373 E.34028
G1 X123.951 Y124.373 E.01402
G1 X116.697 Y131.627 E.34028
G1 X116.275 Y131.627 E.01401
G1 X109.021 Y124.373 E.34028
G1 X108.599 Y124.373 E.01402
G1 X107.897 Y125.075 E.03293
G3 X109.369 Y125.721 I-.44 J3.005 E.05396
; WIPE_START
G1 X108.63 Y125.272 E-.3285
G1 X107.897 Y125.075 E-.2884
G1 X108.163 Y124.809 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X100.754 Y126.643 Z6.2 F36000
G1 X100.126 Y126.798 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F15476.087
G1 X100.126 Y125.17 E.05401
G1 X100.923 Y124.373 E.03738
G1 X101.345 Y124.373 E.01402
G1 X104.575 Y127.603 E.15152
G2 X104.575 Y128.397 I34.397 J.396 E.02633
G1 X101.345 Y131.627 E.15152
G1 X100.923 Y131.627 E.01401
G1 X100.126 Y130.83 E.03738
G1 X100.126 Y129.202 E.05401
; WIPE_START
G1 X100.126 Y130.83 E-.61876
G1 X100.389 Y131.093 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X99.582 Y128 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.4379
G1 F15000
G1 X85.556 Y128 E.45143
G1 X99.161 Y128.224 F36000
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X99.555 Y128.618 E.01712
G1 X99.555 Y129.151
G1 X98.628 Y128.224 E.04029
G1 X98.095 Y128.224
G1 X99.555 Y129.684 E.06346
G1 X99.117 Y129.78
G1 X99.555 Y130.218 E.01903
G1 X98.78 Y129.443
G1 X97.562 Y128.224 E.05296
G1 X97.028 Y128.224
G1 X98.247 Y129.443 E.05296
G1 X97.714 Y129.443
G1 X96.495 Y128.224 E.05296
G1 X95.962 Y128.224
G1 X97.181 Y129.443 E.05296
G1 X96.647 Y129.443
G1 X95.429 Y128.224 E.05296
G1 X94.895 Y128.224
G1 X96.114 Y129.443 E.05296
G1 X95.581 Y129.443
G1 X94.362 Y128.224 E.05296
G1 X93.829 Y128.224
G1 X95.048 Y129.443 E.05296
G1 X94.514 Y129.443
G1 X93.296 Y128.224 E.05296
G1 X92.762 Y128.224
G1 X93.981 Y129.443 E.05296
G1 X93.448 Y129.443
G1 X92.229 Y128.224 E.05296
G1 X91.696 Y128.224
G1 X92.915 Y129.443 E.05296
G1 X92.381 Y129.443
G1 X91.162 Y128.224 E.05296
G1 X90.629 Y128.224
G1 X91.848 Y129.443 E.05296
G1 X91.315 Y129.443
G1 X90.096 Y128.224 E.05296
G1 X89.563 Y128.224
G1 X90.782 Y129.443 E.05296
G1 X90.248 Y129.443
G1 X89.029 Y128.224 E.05296
G1 X88.496 Y128.224
G1 X89.715 Y129.443 E.05296
G1 X89.182 Y129.443
G1 X87.963 Y128.224 E.05296
G1 X87.43 Y128.224
G1 X88.648 Y129.443 E.05296
G1 X88.115 Y129.443
G1 X86.896 Y128.224 E.05296
G1 X86.363 Y128.224
G1 X87.582 Y129.443 E.05296
G1 X87.049 Y129.443
G1 X85.83 Y128.224 E.05296
G1 X85.567 Y128.495
G1 X86.515 Y129.443 E.0412
G1 X85.982 Y129.443
G1 X85.567 Y129.028 E.01803
; WIPE_START
M204 S10000
G1 X85.982 Y129.443 E-.22292
G1 X86.515 Y129.443 E-.20264
G1 X85.893 Y128.82 E-.33444
; WIPE_END
G1 E-.04 F1800
G1 X93.298 Y126.969 Z6.2 F36000
G1 X99.117 Y125.514 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X99.555 Y125.952 E.01903
G1 X99.555 Y126.485
G1 X99.117 Y126.047 E.01903
G1 X99.094 Y126.557
G1 X99.555 Y127.018 E.02003
G1 X99.555 Y127.551
G1 X98.561 Y126.557 E.0432
G1 X98.028 Y126.557
G1 X99.247 Y127.776 E.05296
G1 X98.713 Y127.776
G1 X97.495 Y126.557 E.05296
G1 X96.961 Y126.557
G1 X98.18 Y127.776 E.05296
G1 X97.647 Y127.776
G1 X96.428 Y126.557 E.05296
G1 X95.895 Y126.557
G1 X97.114 Y127.776 E.05296
G1 X96.58 Y127.776
G1 X95.362 Y126.557 E.05296
G1 X94.828 Y126.557
G1 X96.047 Y127.776 E.05296
G1 X95.514 Y127.776
G1 X94.295 Y126.557 E.05296
G1 X93.762 Y126.557
G1 X94.981 Y127.776 E.05296
G1 X94.447 Y127.776
G1 X93.229 Y126.557 E.05296
G1 X92.695 Y126.557
G1 X93.914 Y127.776 E.05296
G1 X93.381 Y127.776
G1 X92.162 Y126.557 E.05296
G1 X91.629 Y126.557
G1 X92.848 Y127.776 E.05296
G1 X92.314 Y127.776
G1 X91.096 Y126.557 E.05296
G1 X90.562 Y126.557
G1 X91.781 Y127.776 E.05296
G1 X91.248 Y127.776
G1 X90.029 Y126.557 E.05296
G1 X89.496 Y126.557
G1 X90.715 Y127.776 E.05296
G1 X90.181 Y127.776
G1 X88.963 Y126.557 E.05296
G1 X88.429 Y126.557
G1 X89.648 Y127.776 E.05296
G1 X89.115 Y127.776
G1 X87.896 Y126.557 E.05296
G1 X87.363 Y126.557
G1 X88.582 Y127.776 E.05296
G1 X88.048 Y127.776
G1 X86.83 Y126.557 E.05296
G1 X86.296 Y126.557
G1 X87.515 Y127.776 E.05296
G1 X86.982 Y127.776
G1 X85.763 Y126.557 E.05296
G1 X85.567 Y126.895
G1 X86.449 Y127.776 E.03829
G1 X85.915 Y127.776
G1 X85.567 Y127.428 E.01512
; WIPE_START
M204 S10000
G1 X85.915 Y127.776 E-.18696
G1 X86.449 Y127.776 E-.20264
G1 X85.759 Y127.087 E-.3704
; WIPE_END
G1 E-.04 F1800
G1 X93.385 Y126.769 Z6.2 F36000
G1 X98.902 Y126.538 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.0834606
G1 F15000
G1 X98.883 Y126.569 E.00012
; LINE_WIDTH: 0.108721
G1 X99.001 Y126.651 E.00077
G1 X99.371 Y125.208 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50814
G1 F13541.982
G2 X99.369 Y125.309 I-.029 J.05 E.0091
; WIPE_START
G1 X99.312 Y125.309 E-.18546
G1 X99.283 Y125.258 E-.19152
G1 X99.312 Y125.208 E-.19153
G1 X99.371 Y125.208 E-.19149
; WIPE_END
G1 E-.04 F1800
G1 X99.749 Y132.561 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53043
G1 F12000
G1 X145.251 Y132.561 E1.80758
G1 X145.251 Y132.074 E.01937
G1 X99.749 Y132.074 E1.80758
G1 X99.749 Y132.501 E.01698
; CHANGE_LAYER
; Z_HEIGHT: 6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X99.749 Y132.074 E-.16246
G1 X101.322 Y132.074 E-.59754
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
G1 X135.422 Y129.565
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.254 Y129.297 E.0105
G3 X137.269 Y125.412 I2.254 J-1.296 E.17252
G3 X138.802 Y125.745 I.225 J2.654 E.05283
G3 X135.464 Y129.607 I-1.294 J2.255 E.30405
G1 X135.747 Y129.346 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.753 Y129.341 E.00024
G3 X137.294 Y125.803 I1.755 J-1.34 E.14425
G3 X138.346 Y125.958 I.22 J2.155 E.033
G3 X135.942 Y129.558 I-.838 J2.043 E.24026
G1 X135.787 Y129.39 E.00702
; WIPE_START
M204 S10000
G1 X135.753 Y129.341 E-.02286
G1 X135.586 Y129.105 E-.1097
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10988
G1 X135.308 Y127.711 E-.10989
G1 X135.349 Y127.51 E-.07804
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z6.4 F36000
G1 X105.898 Y125.95 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.921 Y125.942 E.00081
G3 X107.269 Y125.412 I1.587 J2.059 E.04869
G3 X108.802 Y125.745 I.225 J2.654 E.05283
G3 X105.666 Y126.166 I-1.294 J2.255 E.42905
G1 X105.854 Y125.991 E.00852
G1 X106.154 Y126.247 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X106.159 Y126.252 E.00024
G3 X107.294 Y125.803 I1.349 J1.749 E.03801
G3 X108.346 Y125.958 I.22 J2.155 E.033
G3 X105.943 Y126.443 I-.838 J2.043 E.34651
G1 X106.11 Y126.287 E.00702
; WIPE_START
M204 S10000
G1 X106.159 Y126.252 E-.02288
G1 X106.395 Y126.086 E-.10969
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10987
G1 X107.294 Y125.803 E-.1412
G1 X107.5 Y125.79 E-.07833
G1 X107.789 Y125.808 E-.10988
G1 X107.991 Y125.849 E-.07826
; WIPE_END
G1 E-.04 F1800
G1 X115.61 Y126.289 Z6.4 F36000
G1 X145.222 Y127.999 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X145.222 Y130.397 E.07956
G1 X145.698 Y130.397 E.01578
G1 X145.698 Y132.795 E.07955
G1 X99.302 Y132.795 E1.53904
G1 X99.302 Y130.397 E.07955
G1 X99.778 Y130.397 E.01578
G1 X99.778 Y125.603 E.15903
G1 X99.302 Y125.603 E.01578
G1 X99.302 Y123.205 E.07955
G1 X145.698 Y123.205 E1.53904
G1 X145.698 Y125.603 E.07955
G1 X145.222 Y125.603 E.01578
G1 X145.222 Y127.939 E.07748
; WIPE_START
G1 X145.222 Y129.939 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.397 Y132.543 Z6.4 F36000
G1 X160.452 Y135.467 Z6.4
G1 Z6
G1 E.8 F1800
G1 F15476.087
G1 X160.452 Y130.397 E.16818
G1 X160.928 Y130.397 E.01578
G1 X160.928 Y125.603 E.15903
G1 X160.452 Y125.603 E.01578
G1 X160.452 Y120.533 E.16818
G1 X162.248 Y120.533 E.05957
G1 X162.248 Y135.467 E.49539
G1 X160.512 Y135.467 E.05758
; WIPE_START
G1 X160.488 Y133.467 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.502 Y130.393 Z6.4 F36000
G1 X146.09 Y127.131 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y127.131 E.42926
G1 X160.06 Y120.141 E.21478
G1 X162.64 Y120.141 E.07928
G1 X162.64 Y135.859 E.48298
G1 X160.06 Y135.859 E.07928
G1 X160.06 Y128.869 E.21478
G1 X146.09 Y128.869 E.42926
G1 X146.09 Y133.187 E.13268
G1 X98.91 Y133.187 E1.44971
G1 X98.91 Y128.869 E.13268
G1 X85.36 Y128.869 E.41635
G1 X85.36 Y127.131 E.05342
G1 X98.91 Y127.131 E.41635
G1 X98.91 Y122.813 E.13268
G1 X146.09 Y122.813 E1.44971
G1 X146.09 Y127.071 E.13084
; WIPE_START
M204 S10000
G1 X148.09 Y127.079 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.688 Y129.91 Z6.4 F36000
G1 Z6
M73 P85 R2
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50814
G1 F13541.982
G2 X145.686 Y130.011 I-.029 J.05 E.0091
; WIPE_START
G1 X145.629 Y130.011 E-.18544
G1 X145.6 Y129.961 E-.19152
G1 X145.629 Y129.91 E-.19154
G1 X145.688 Y129.91 E-.1915
; WIPE_END
G1 E-.04 F1800
G1 X145.277 Y131.383 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.480676
G1 F12000
G1 X145.25 Y130.909 E.01695
G1 X145.232 Y132.329 F36000
; LINE_WIDTH: 0.568345
G1 F11990.294
G1 X99.768 Y132.329 E1.94654
; LINE_WIDTH: 0.548335
G1 F12000
G1 X99.768 Y132.191 E.00569
; LINE_WIDTH: 0.536529
G2 X99.754 Y131.83 I-2.904 J-.069 E.01452
; Slow Down Start
; LINE_WIDTH: 0.534997
G1 F3000;_EXTRUDE_SET_SPEED
G1 X99.73 Y131.431 E.01603
G1 X99.789 Y131.635 E.00853
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.552865
;_EXTRUDE_SET_SPEED
G1 X100.017 Y131.804 E.01179
G1 X144.969 Y131.804 E1.86792
; Slow Down End
; LINE_WIDTH: 0.54555
G1 F12000
G1 X145.09 Y131.719 E.00603
; LINE_WIDTH: 0.504642
G1 X145.211 Y131.635 E.00554
G1 X145.277 Y131.383 E.00982
; LINE_WIDTH: 0.49997
G1 X145.262 Y131.513 E.00487
; LINE_WIDTH: 0.551263
G2 X145.233 Y132.269 I6.969 J.648 E.03136
G1 X99.754 Y130.849 F36000
; LINE_WIDTH: 0.525462
G1 F12000
G1 X99.74 Y131.086 E.00934
; LINE_WIDTH: 0.497964
G1 X99.726 Y131.323 E.00882
G1 X100.126 Y129.314 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.126 Y130.421 E.03673
G1 X100.205 Y130.5 E.00372
G1 X100.205 Y130.909 E.01357
G1 X100.634 Y131.337 E.02009
G1 X101.635 Y131.337 E.03321
G1 X104.575 Y128.397 E.13794
G3 X104.575 Y127.603 I27.882 J-.397 E.02633
G1 X101.635 Y124.663 E.13794
G1 X100.634 Y124.663 E.03321
G1 X100.205 Y125.091 E.02009
G1 X100.205 Y125.5 E.01357
G1 X100.126 Y125.579 E.00372
G1 X100.126 Y126.686 E.03672
; WIPE_START
G1 X100.126 Y125.579 E-.4207
G1 X100.205 Y125.5 E-.04261
G1 X100.205 Y125.091 E-.15545
G1 X100.468 Y124.828 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X99.371 Y125.989 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50814
G1 F13541.982
G2 X99.369 Y126.09 I-.029 J.05 E.0091
; WIPE_START
G1 X99.312 Y126.09 E-.18546
G1 X99.283 Y126.039 E-.19152
G1 X99.312 Y125.989 E-.19153
G1 X99.371 Y125.989 E-.19149
; WIPE_END
G1 E-.04 F1800
G1 X99.754 Y125.151 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.523646
G1 F12000
G1 X99.739 Y124.933 E.00858
; LINE_WIDTH: 0.492497
G1 X99.725 Y124.714 E.00802
G1 X99.768 Y123.671 F36000
; LINE_WIDTH: 0.568322
G1 F11990.824
G1 X145.232 Y123.671 E1.94645
G2 X145.237 Y124.17 I10.7 J.131 E.02135
; Slow Down Start
; LINE_WIDTH: 0.556656
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.243 Y124.433 E.01101
G1 X145.215 Y124.363 E.00315
G1 X144.983 Y124.196 E.01196
G1 X100.031 Y124.196 E1.8818
G1 X99.785 Y124.363 E.01242
G1 X99.757 Y124.433 E.00315
G3 X99.76 Y124.17 I7.722 J-.039 E.01101
; Slow Down End
; LINE_WIDTH: 0.559915
G1 F12000
G1 X99.767 Y123.731 E.01848
G1 X145.246 Y125.151 F36000
; LINE_WIDTH: 0.523641
G1 F12000
G1 X145.261 Y124.933 E.00857
; LINE_WIDTH: 0.492482
G1 X145.275 Y124.714 E.00802
G1 X139.78 Y126.131 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X138.461 Y125.215 I-2.289 J1.887 E.05395
G1 X139.013 Y124.663 E.02591
G1 X140.015 Y124.663 E.03321
G1 X144.874 Y129.522 E.22797
G1 X144.874 Y126.478 E.10098
G1 X140.015 Y131.337 E.22797
G1 X139.013 Y131.337 E.03321
G1 X138.461 Y130.785 E.02592
G2 X139.78 Y129.869 I-.97 J-2.804 E.05395
; WIPE_START
G1 X139.297 Y130.342 E-.25693
G1 X138.461 Y130.785 E-.35961
G1 X138.728 Y131.052 E-.14347
; WIPE_END
G1 E-.04 F1800
G1 X146.343 Y130.537 Z6.4 F36000
G1 X160.267 Y129.594 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X160.705 Y129.157 E.01903
G1 X160.705 Y128.623
G1 X160.267 Y129.061 E.01903
G1 X160.133 Y128.662
G1 X160.705 Y128.09 E.02485
G1 X160.705 Y127.557
G1 X159.6 Y128.662 E.04802
G1 X159.067 Y128.662
G1 X160.705 Y127.023 E.0712
G1 X160.267 Y126.928
G1 X160.705 Y126.49 E.01903
G1 X159.857 Y127.338
G1 X158.534 Y128.662 E.05752
G1 X158 Y128.662
G1 X159.324 Y127.338 E.05752
G1 X158.791 Y127.338
G1 X157.467 Y128.662 E.05752
G1 X156.934 Y128.662
G1 X158.258 Y127.338 E.05752
G1 X157.724 Y127.338
G1 X156.401 Y128.662 E.05752
G1 X155.867 Y128.662
G1 X157.191 Y127.338 E.05752
G1 X156.658 Y127.338
G1 X155.334 Y128.662 E.05752
G1 X154.801 Y128.662
G1 X156.125 Y127.338 E.05752
G1 X155.591 Y127.338
G1 X154.268 Y128.662 E.05752
G1 X153.734 Y128.662
G1 X155.058 Y127.338 E.05752
G1 X154.525 Y127.338
G1 X153.201 Y128.662 E.05752
G1 X152.668 Y128.662
G1 X153.992 Y127.338 E.05752
G1 X153.458 Y127.338
G1 X152.135 Y128.662 E.05752
G1 X151.601 Y128.662
G1 X152.925 Y127.338 E.05752
G1 X152.392 Y127.338
G1 X151.068 Y128.662 E.05752
G1 X150.535 Y128.662
G1 X151.858 Y127.338 E.05752
G1 X151.325 Y127.338
G1 X150.002 Y128.662 E.05752
G1 X149.468 Y128.662
G1 X150.792 Y127.338 E.05752
G1 X150.259 Y127.338
G1 X148.935 Y128.662 E.05752
G1 X148.402 Y128.662
G1 X149.725 Y127.338 E.05752
G1 X149.192 Y127.338
G1 X147.869 Y128.662 E.05752
G1 X147.335 Y128.662
G1 X148.659 Y127.338 E.05752
G1 X148.126 Y127.338
G1 X146.802 Y128.662 E.05752
G1 X146.269 Y128.662
G1 X147.592 Y127.338 E.05752
; WIPE_START
M204 S10000
G1 X146.269 Y128.662 E-.71135
G1 X146.397 Y128.662 E-.04865
; WIPE_END
G1 E-.04 F1800
G1 X145.883 Y129.048 Z6.4 F36000
G1 Z6
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X145.445 Y129.486 E.01903
G1 X145.445 Y128.953
G1 X147.059 Y127.338 E.07015
G1 X146.526 Y127.338
G1 X145.445 Y128.419 E.04698
G1 X145.445 Y127.886
G1 X145.993 Y127.338 E.02381
G1 X145.883 Y126.915
G1 X145.445 Y127.353 E.01903
G1 X145.445 Y126.82
G1 X145.883 Y126.382 E.01903
; WIPE_START
M204 S10000
G1 X145.445 Y126.82 E-.23533
G1 X145.445 Y127.353 E-.20264
G1 X145.883 Y126.915 E-.23532
G1 X145.94 Y127.136 E-.08671
; WIPE_END
G1 E-.04 F1800
G1 X153.564 Y126.782 Z6.4 F36000
G1 X160.724 Y126.449 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.10638
G1 F15000
G2 X160.549 Y126.334 I-.24 J.176 E.0011
G1 X160.249 Y126.386 E.00158
G1 X160.724 Y129.507 F36000
; LINE_WIDTH: 0.172384
G1 F15000
G1 X160.653 Y129.567 E.00098
; LINE_WIDTH: 0.154942
G1 X160.577 Y129.619 E.00085
; LINE_WIDTH: 0.121489
G1 X160.5 Y129.672 E.0006
; LINE_WIDTH: 0.0964643
G1 X160.453 Y129.699 E.00023
; WIPE_START
G1 X160.5 Y129.672 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.056 Y127.985 Z6.4 F36000
G1 X145.663 Y126.308 Z6.4
G1 Z6
G1 E.8 F1800
; LINE_WIDTH: 0.104747
G1 F15000
G1 X145.578 Y126.367 E.00052
; LINE_WIDTH: 0.145993
G2 X145.426 Y126.482 I.555 J.894 E.0016
; WIPE_START
G1 X145.578 Y126.367 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.208 Y126.174 Z6.4 F36000
G1 X160.521 Y125.989 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50814
G1 F13541.982
G2 X160.519 Y126.09 I-.029 J.05 E.0091
; WIPE_START
G1 X160.462 Y126.09 E-.18544
G1 X160.433 Y126.039 E-.19152
G1 X160.462 Y125.989 E-.19154
G1 X160.521 Y125.989 E-.1915
; WIPE_END
G1 E-.04 F1800
G1 X160.904 Y125.151 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.5392
G1 F12000
G1 X160.904 Y124.906 E.00992
G1 X160.889 Y120.881 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y120.881 E.00295
G1 X160.8 Y122.421 E.05106
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X161.355 Y125.349 E.02554
G3 X161.276 Y125.579 I-.155 J.076 E.00899
G1 X161.276 Y130.421 E.1606
G2 X161.9 Y131.196 I1.844 J-.846 E.03334
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y135.119 E.05106
G1 X160.889 Y135.119 E.00295
G1 X160.904 Y131.154 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.5392
G1 F12000
G1 X160.904 Y130.909 E.00992
; WIPE_START
G1 X160.904 Y131.154 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.313 Y130.354 Z6.4 F36000
G1 X109.369 Y125.721 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X107.897 Y125.075 I-1.912 J2.36 E.05396
G1 X108.309 Y124.663 E.01935
G1 X109.311 Y124.663 E.03321
G1 X115.985 Y131.337 E.31313
G1 X116.987 Y131.337 E.03321
G1 X123.661 Y124.663 E.31313
G1 X124.663 Y124.663 E.03321
G1 X131.337 Y131.337 E.31313
G1 X132.339 Y131.337 E.03321
G1 X134.715 Y128.961 E.11148
G3 X134.715 Y127.039 I3.178 J-.961 E.06468
G1 X132.339 Y124.663 E.11148
G1 X131.337 Y124.663 E.03321
G1 X124.663 Y131.337 E.31313
G1 X123.661 Y131.337 E.03321
G1 X116.987 Y124.663 E.31313
G1 X115.985 Y124.663 E.03321
G1 X109.311 Y131.337 E.31313
G1 X108.31 Y131.337 E.03321
G1 X107.897 Y130.925 E.01935
G2 X109.369 Y130.279 I-.44 J-3.005 E.05396
; WIPE_START
G1 X108.63 Y130.728 E-.3285
G1 X107.897 Y130.925 E-.2884
G1 X108.163 Y131.191 E-.1431
; WIPE_END
G1 E-.04 F1800
G1 X100.77 Y129.294 Z6.4 F36000
G1 X99.555 Y128.982 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X99.117 Y129.42 E.01903
G1 X99.117 Y128.887
G1 X99.555 Y128.449 E.01903
G1 X99.555 Y127.915
G1 X98.809 Y128.662 E.03244
G1 X98.276 Y128.662
G1 X99.555 Y127.382 E.05561
G1 X99.117 Y127.287
G1 X99.555 Y126.849 E.01903
G1 X99.498 Y126.373
G1 X99.117 Y126.754 E.01652
G1 X99.066 Y127.338
G1 X97.742 Y128.662 E.05752
G1 X97.209 Y128.662
G1 X98.533 Y127.338 E.05752
G1 X97.999 Y127.338
G1 X96.676 Y128.662 E.05752
G1 X96.143 Y128.662
G1 X97.466 Y127.338 E.05752
G1 X96.933 Y127.338
G1 X95.609 Y128.662 E.05752
G1 X95.076 Y128.662
G1 X96.4 Y127.338 E.05752
G1 X95.866 Y127.338
G1 X94.543 Y128.662 E.05752
G1 X94.009 Y128.662
G1 X95.333 Y127.338 E.05752
G1 X94.8 Y127.338
G1 X93.476 Y128.662 E.05752
G1 X92.943 Y128.662
G1 X94.267 Y127.338 E.05752
G1 X93.733 Y127.338
G1 X92.41 Y128.662 E.05752
G1 X91.876 Y128.662
G1 X93.2 Y127.338 E.05752
G1 X92.667 Y127.338
G1 X91.343 Y128.662 E.05752
G1 X90.81 Y128.662
G1 X92.134 Y127.338 E.05752
G1 X91.6 Y127.338
M73 P86 R2
G1 X90.277 Y128.662 E.05752
G1 X89.743 Y128.662
G1 X91.067 Y127.338 E.05752
G1 X90.534 Y127.338
G1 X89.21 Y128.662 E.05752
G1 X88.677 Y128.662
G1 X90.001 Y127.338 E.05752
G1 X89.467 Y127.338
G1 X88.144 Y128.662 E.05752
G1 X87.61 Y128.662
G1 X88.934 Y127.338 E.05752
G1 X88.401 Y127.338
G1 X87.077 Y128.662 E.05752
G1 X86.544 Y128.662
G1 X87.868 Y127.338 E.05752
G1 X87.334 Y127.338
G1 X86.011 Y128.662 E.05752
G1 X85.567 Y128.572
G1 X86.801 Y127.338 E.05361
G1 X86.268 Y127.338
G1 X85.567 Y128.039 E.03044
; WIPE_START
M204 S10000
G1 X86.268 Y127.338 E-.37639
G1 X86.801 Y127.338 E-.20264
G1 X86.464 Y127.675 E-.18097
; WIPE_END
G1 E-.04 F1800
G1 X94.028 Y128.694 Z6.4 F36000
G1 X99.574 Y129.441 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.274775
G1 F15000
G1 X99.451 Y129.526 E.00282
; LINE_WIDTH: 0.23312
G3 X99.195 Y129.633 I-.232 J-.196 E.00446
G1 X99.099 Y129.425 E.00354
; CHANGE_LAYER
; Z_HEIGHT: 6.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X99.195 Y129.633 E-.33613
G1 X99.252 Y129.64 E-.08424
G1 X99.316 Y129.618 E-.09849
G1 X99.451 Y129.526 E-.24114
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
G1 X160.452 Y135.321
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y120.679 E.48567
G1 X162.248 Y120.679 E.05957
G1 X162.248 Y135.321 E.48567
G1 X160.512 Y135.321 E.05758
G1 X160.06 Y135.713 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y120.287 E.47397
G1 X162.64 Y120.287 E.07928
G1 X162.64 Y135.713 E.47397
G1 X160.12 Y135.713 E.07743
; WIPE_START
M204 S10000
G1 X160.112 Y133.713 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.036 Y134.972 Z6.6 F36000
G1 Z6.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y134.972 E.00781
G1 X160.8 Y133.579 E.0462
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X161.355 Y130.652 E.02554
G1 X161.355 Y125.349 E.17591
G1 X161.9 Y124.804 E.02554
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y121.028 E.0462
G1 X161.036 Y121.028 E.00781
G1 X160.904 Y131.154 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.5392
G1 F12000
G1 X160.904 Y124.906 E.25267
; WIPE_START
G1 X160.904 Y126.906 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.313 Y127.698 Z6.6 F36000
G1 X135.422 Y129.566 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.255 Y129.296 E.01051
G3 X137.253 Y125.413 I2.253 J-1.297 E.17202
G3 X138.802 Y125.745 I.239 J2.657 E.05334
G3 X135.464 Y129.606 I-1.294 J2.254 E.30391
G1 X135.746 Y129.345 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.595 Y129.1 E.00886
G3 X137.279 Y125.804 I1.915 J-1.1 E.13486
G3 X138.072 Y125.865 I.216 J2.391 E.02456
G3 X135.785 Y129.379 I-.563 J2.135 E.25646
; WIPE_START
M204 S10000
G1 X135.595 Y129.1 E-.1284
G1 X135.458 Y128.846 E-.10969
G1 X135.365 Y128.572 E-.10986
G1 X135.308 Y128.289 E-.10987
G1 X135.29 Y128 E-.10991
G1 X135.308 Y127.712 E-.10982
G1 X135.351 Y127.499 E-.08244
; WIPE_END
G1 E-.04 F1800
G1 X127.729 Y127.09 Z6.6 F36000
G1 X105.934 Y125.922 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X106.202 Y125.752 E.01051
G3 X107.253 Y125.413 I1.305 J2.247 E.03692
G3 X108.802 Y125.745 I.239 J2.657 E.05334
G3 X105.892 Y125.963 I-1.294 J2.254 E.43892
G1 X106.155 Y126.246 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X106.398 Y126.092 E.00886
G3 X107.279 Y125.804 I1.111 J1.908 E.02868
G3 X108.072 Y125.865 I.216 J2.39 E.02456
G3 X106.119 Y126.285 I-.563 J2.135 E.36258
; WIPE_START
M204 S10000
G1 X106.398 Y126.092 E-.12919
G1 X106.654 Y125.958 E-.1097
G1 X106.928 Y125.865 E-.10989
G1 X107.279 Y125.804 E-.13538
G1 X107.5 Y125.79 E-.08417
G1 X107.789 Y125.808 E-.10989
G1 X108 Y125.85 E-.08178
; WIPE_END
G1 E-.04 F1800
G1 X115.631 Y126.001 Z6.6 F36000
G1 X145.698 Y126.596 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X145.698 Y132.569 E.19813
G1 X99.302 Y132.569 E1.53904
G1 X99.302 Y123.431 E.30311
G1 X145.698 Y123.431 E1.53904
G1 X145.698 Y126.536 E.10299
G1 X146.09 Y126.596 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X146.09 Y132.961 E.19558
G1 X98.91 Y132.961 E1.44971
G1 X98.91 Y123.039 E.30487
G1 X146.09 Y123.039 E1.44971
G1 X146.09 Y126.536 E.10745
; WIPE_START
M204 S10000
G1 X146.09 Y128.536 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X139.779 Y129.867 Z6.6 F36000
G1 Z6.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X138.461 Y130.785 I-2.278 J-1.865 E.05396
G1 X138.692 Y131.016 E.01083
G1 X140.336 Y131.016 E.05455
G1 X144.795 Y126.557 E.20916
G1 X144.795 Y129.443 E.09572
G1 X140.336 Y124.984 E.20916
G1 X138.692 Y124.984 E.05455
G1 X138.461 Y125.215 E.01083
G3 X139.78 Y126.132 I-.971 J2.804 E.05397
; WIPE_START
G1 X139.301 Y125.66 E-.25534
G1 X138.461 Y125.215 E-.36145
G1 X138.692 Y124.984 E-.12402
G1 X138.742 Y124.984 E-.01919
; WIPE_END
G1 E-.04 F1800
G1 X131.231 Y126.338 Z6.6 F36000
G1 X109.369 Y130.279 Z6.6
G1 Z6.2
G1 E.8 F1800
G1 F15476.087
G3 X107.897 Y130.925 I-1.912 J-2.36 E.05396
G1 X107.988 Y131.016 E.00427
G1 X109.632 Y131.016 E.05455
G1 X115.664 Y124.984 E.28295
G1 X117.308 Y124.984 E.05455
G1 X123.34 Y131.016 E.28295
G1 X124.984 Y131.016 E.05455
G1 X131.016 Y124.984 E.28295
G1 X132.66 Y124.984 E.05455
G1 X134.715 Y127.039 E.0964
G2 X134.715 Y128.961 I3.177 J.961 E.06468
G1 X132.66 Y131.016 E.0964
G1 X131.016 Y131.016 E.05455
G1 X124.984 Y124.984 E.28295
G1 X123.34 Y124.984 E.05455
G1 X117.308 Y131.016 E.28295
G1 X115.664 Y131.016 E.05455
G1 X109.632 Y124.984 E.28295
G1 X107.988 Y124.984 E.05455
G1 X107.897 Y125.075 E.00427
G3 X109.368 Y125.722 I-.431 J2.975 E.05395
; WIPE_START
G1 X108.63 Y125.272 E-.32834
G1 X107.897 Y125.075 E-.2884
G1 X107.988 Y124.984 E-.04887
G1 X108.236 Y124.984 E-.09438
; WIPE_END
G1 E-.04 F1800
G1 X100.604 Y124.984 Z6.6 F36000
G1 X100.328 Y124.984 Z6.6
G1 Z6.2
G1 E.8 F1800
G1 F15476.087
G1 X101.956 Y124.984 E.05401
G1 X104.575 Y127.603 E.12285
G2 X104.575 Y128.397 I34.473 J.396 E.02633
G1 X101.956 Y131.016 E.12286
G1 X100.328 Y131.016 E.05401
G1 X99.756 Y131.17 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.539233
G1 F12000
G1 X99.754 Y124.933 E.25221
; WIPE_START
G1 X99.754 Y126.933 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X107.354 Y127.641 Z6.6 F36000
G1 X145.244 Y131.17 Z6.6
G1 Z6.2
G1 E.8 F1800
; LINE_WIDTH: 0.522465
G1 F12000
G1 X145.26 Y131.268 E.00387
; LINE_WIDTH: 0.481475
G1 X145.276 Y131.365 E.00354
; LINE_WIDTH: 0.420249
G1 X145.292 Y131.463 E.00305
G1 X145.306 Y132.177 E.02195
G1 X99.694 Y132.177 E1.40245
; LINE_WIDTH: 0.440489
G1 X99.694 Y132.049 E.00415
; LINE_WIDTH: 0.481485
G1 X99.694 Y131.92 E.00458
; LINE_WIDTH: 0.488459
G1 X99.756 Y131.17 E.02734
; LINE_WIDTH: 0.522482
G1 X99.785 Y131.208 E.00189
; LINE_WIDTH: 0.481485
G1 X99.814 Y131.247 E.00173
; Slow Down Start
; LINE_WIDTH: 0.465889
G1 F3000;_EXTRUDE_SET_SPEED
G2 X99.946 Y131.336 I.156 J-.088 E.00569
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.43397
;_EXTRUDE_SET_SPEED
G1 X100.089 Y131.408 E.00511
G1 X144.905 Y131.408 E1.42809
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.440485
;_EXTRUDE_SET_SPEED
G1 X144.953 Y131.393 E.00162
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.481475
;_EXTRUDE_SET_SPEED
G1 X145.001 Y131.377 E.00179
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.503066
;_EXTRUDE_SET_SPEED
G2 X145.062 Y131.349 I.003 J-.074 E.00262
; Slow Down End
; LINE_WIDTH: 0.476521
G1 F12000
G1 X145.132 Y131.281 E.00346
; LINE_WIDTH: 0.520814
G1 X145.202 Y131.212 E.00381
G1 X144.921 Y131.792 F36000
; LINE_WIDTH: 0.43486
G1 F12000
G1 X100.139 Y131.792 E1.43027
; WIPE_START
G1 X102.139 Y131.792 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X109.675 Y130.583 Z6.6 F36000
G1 X145.246 Y124.873 Z6.6
G1 Z6.2
G1 E.8 F1800
; LINE_WIDTH: 0.5392
G1 F12000
G1 X145.246 Y131.11 E.2522
; WIPE_START
G1 X145.246 Y129.11 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X137.65 Y128.365 Z6.6 F36000
G1 X99.95 Y124.668 Z6.6
G1 Z6.2
G1 E.8 F1800
; LINE_WIDTH: 0.474833
G1 F12000
G1 X99.899 Y124.694 E.002
; LINE_WIDTH: 0.517758
G1 X99.849 Y124.72 E.0022
; LINE_WIDTH: 0.455505
G1 X99.754 Y124.873 E.00606
; LINE_WIDTH: 0.519349
G1 X99.736 Y124.761 E.00441
; LINE_WIDTH: 0.479605
G1 X99.719 Y124.649 E.00404
; LINE_WIDTH: 0.420148
G1 X99.701 Y124.537 E.00349
G1 X99.694 Y123.823 E.02194
G1 X145.306 Y123.823 E1.40207
G1 X145.306 Y124.208 E.01182
; LINE_WIDTH: 0.434148
G1 X145.276 Y124.541 E.01065
; LINE_WIDTH: 0.468467
G1 X145.246 Y124.873 E.01159
G1 X145.151 Y124.72 E.00625
; Slow Down Start
; LINE_WIDTH: 0.464822
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.051 Y124.667 E.0039
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.448274
;_EXTRUDE_SET_SPEED
G1 X144.911 Y124.592 E.00525
G1 X100.095 Y124.592 E1.48033
; Slow Down End
; LINE_WIDTH: 0.43668
G1 F12000
G1 X100.003 Y124.64 E.00332
G1 X100.079 Y124.208 F36000
; LINE_WIDTH: 0.43486
G1 F12000
G1 X144.861 Y124.208 E1.43027
; CHANGE_LAYER
; Z_HEIGHT: 6.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X142.861 Y124.208 E-.76
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
G1 X160.452 Y135.158
M73 P87 R2
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y120.842 E.4749
G1 X162.248 Y120.842 E.05957
G1 X162.248 Y135.158 E.4749
G1 X160.512 Y135.158 E.05758
G1 X160.06 Y135.55 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y120.45 E.464
G1 X162.64 Y120.45 E.07928
G1 X162.64 Y135.55 E.464
G1 X160.12 Y135.55 E.07743
; WIPE_START
M204 S10000
G1 X160.112 Y133.55 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.78 Y125.947 Z6.8 F36000
G1 X161.198 Y121.19 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y121.19 E.01319
G1 X160.8 Y122.421 E.04082
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X160.8 Y125.903 E.05157
G1 X160.8 Y130.097 E.13909
G1 X161.9 Y131.196 E.05157
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y134.81 E.04082
G1 X161.198 Y134.81 E.0132
; WIPE_START
G1 X160.8 Y134.81 E-.15116
G1 X160.8 Y133.579 E-.4676
G1 X161.063 Y133.317 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.511 Y132.212 Z6.8 F36000
G1 X135.422 Y129.565 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X135.255 Y129.296 E.0105
G3 X137.238 Y125.414 I2.253 J-1.297 E.17152
G3 X138.496 Y125.595 I.276 J2.545 E.04261
G3 X135.464 Y129.606 I-.988 J2.405 E.31533
G1 X135.747 Y129.346 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.753 Y129.341 E.00025
G3 X137.264 Y125.805 I1.755 J-1.341 E.14335
G3 X138.072 Y125.865 I.229 J2.405 E.02503
G3 X135.942 Y129.558 I-.565 J2.135 E.24911
G1 X135.787 Y129.39 E.00702
; WIPE_START
M204 S10000
G1 X135.753 Y129.341 E-.0229
G1 X135.586 Y129.105 E-.10969
G1 X135.458 Y128.846 E-.1099
G1 X135.365 Y128.572 E-.10987
G1 X135.308 Y128.288 E-.1099
G1 X135.29 Y128 E-.10985
G1 X135.308 Y127.712 E-.10986
G1 X135.349 Y127.51 E-.07803
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z6.8 F36000
G1 X105.898 Y125.95 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.92 Y125.941 E.0008
G3 X107.238 Y125.414 I1.588 J2.06 E.04769
G3 X108.496 Y125.595 I.276 J2.546 E.04261
G3 X105.665 Y126.165 I-.988 J2.406 E.44051
G1 X105.854 Y125.991 E.00852
G1 X106.154 Y126.247 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X106.159 Y126.252 E.00021
G3 X107.264 Y125.805 I1.349 J1.747 E.03708
G3 X108.072 Y125.865 I.229 J2.404 E.02503
G3 X105.942 Y126.442 I-.564 J2.134 E.35516
G1 X106.11 Y126.287 E.00701
; WIPE_START
M204 S10000
G1 X106.159 Y126.252 E-.02291
G1 X106.395 Y126.086 E-.1097
G1 X106.654 Y125.958 E-.10989
G1 X106.928 Y125.865 E-.10986
G1 X107.264 Y125.805 E-.12958
G1 X107.5 Y125.79 E-.09005
G1 X107.788 Y125.808 E-.10983
G1 X107.99 Y125.849 E-.07818
; WIPE_END
G1 E-.04 F1800
G1 X115.62 Y126.042 Z6.8 F36000
G1 X145.698 Y126.802 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X145.698 Y132.325 E.1832
G1 X99.302 Y132.325 E1.53904
G1 X99.302 Y123.675 E.28694
G1 X145.698 Y123.675 E1.53904
G1 X145.698 Y126.742 E.10175
G1 X146.09 Y126.802 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X146.09 Y132.717 E.18175
G1 X98.91 Y132.717 E1.44971
G1 X98.91 Y123.283 E.28989
G1 X146.09 Y123.283 E1.44971
G1 X146.09 Y126.742 E.1063
; WIPE_START
M204 S10000
G1 X146.09 Y128.742 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X139.218 Y125.421 Z6.8 F36000
G1 X139.075 Y125.351 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X140.703 Y125.351 E.05401
G1 X144.795 Y129.443 E.19195
G1 X144.795 Y126.557 E.09572
G1 X140.703 Y130.649 E.19195
G1 X139.075 Y130.649 E.05401
; WIPE_START
G1 X140.703 Y130.649 E-.61876
G1 X140.966 Y130.386 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X133.42 Y129.241 Z6.8 F36000
G1 X109.151 Y125.56 Z6.8
G1 Z6.4
G1 E.8 F1800
G1 F15476.087
G2 X108.789 Y125.351 I-.974 J1.269 E.01389
G1 X109.999 Y125.351 E.04013
G1 X115.297 Y130.649 E.24854
G1 X117.675 Y130.649 E.07888
G1 X122.973 Y125.351 E.24854
G1 X125.351 Y125.351 E.07888
G1 X130.649 Y130.649 E.24854
G1 X133.027 Y130.649 E.07888
G1 X134.715 Y128.961 E.07919
G3 X134.715 Y127.039 I3.178 J-.961 E.06468
G1 X133.027 Y125.351 E.07919
G1 X130.649 Y125.351 E.07888
G1 X125.351 Y130.649 E.24854
G1 X122.973 Y130.649 E.07888
G1 X117.675 Y125.351 E.24854
G1 X115.297 Y125.351 E.07888
G1 X109.999 Y130.649 E.24854
G1 X108.789 Y130.649 E.04013
G2 X109.151 Y130.44 I-.612 J-1.478 E.01389
; WIPE_START
G1 X108.789 Y130.649 E-.1587
G1 X109.999 Y130.649 E-.45972
G1 X110.263 Y130.386 E-.14158
; WIPE_END
G1 E-.04 F1800
G1 X102.633 Y130.596 Z6.8 F36000
G1 X100.695 Y130.649 Z6.8
G1 Z6.4
G1 E.8 F1800
G1 F15476.087
G1 X102.323 Y130.649 E.05401
G1 X104.575 Y128.397 E.10565
G3 X104.575 Y127.603 I34.549 J-.397 E.02633
G1 X102.323 Y125.351 E.10565
G1 X100.695 Y125.351 E.05401
G1 X99.676 Y130.687 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.403268
G1 F12000
G1 X99.695 Y130.614 E.0022
; LINE_WIDTH: 0.442083
G1 X99.715 Y130.542 E.00244
; LINE_WIDTH: 0.480898
G1 X99.734 Y130.469 E.00268
; LINE_WIDTH: 0.538821
G1 X99.754 Y130.397 E.00303
G1 X99.754 Y125.603 E.19369
; LINE_WIDTH: 0.519595
G1 X99.738 Y125.553 E.00206
; LINE_WIDTH: 0.480545
G1 X99.723 Y125.502 E.00189
; LINE_WIDTH: 0.441495
G1 X99.708 Y125.451 E.00172
; LINE_WIDTH: 0.402445
G1 X99.692 Y125.4 E.00155
; WIPE_START
G1 X99.708 Y125.451 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X107.283 Y126.384 Z6.8 F36000
G1 X145.075 Y131.041 Z6.8
G1 Z6.4
G1 E.8 F1800
; LINE_WIDTH: 0.419132
G1 F12000
G1 X145.243 Y130.922 E.00631
G1 X145.319 Y130.724 E.00649
G2 X145.306 Y131.933 I26.145 J.878 E.03706
G1 X99.694 Y131.933 E1.39829
G2 X99.676 Y130.687 I-20.206 J-.331 E.03822
G1 X99.757 Y130.922 E.00763
G1 X99.925 Y131.041 E.00631
G1 X100.002 Y131.041 E.00236
; Slow Down Start
; LINE_WIDTH: 0.41999
G1 F3000;_EXTRUDE_SET_SPEED
G1 X144.998 Y131.041 E1.38258
; Slow Down End
G1 F12000
G1 X145.015 Y131.041 E.00052
G1 X144.86 Y131.487 F36000
; LINE_WIDTH: 0.55783
G1 F12000
G1 X100.2 Y131.487 E1.87386
; WIPE_START
G1 X102.2 Y131.487 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X109.756 Y130.411 Z6.8 F36000
G1 X145.325 Y125.343 Z6.8
G1 Z6.4
G1 E.8 F1800
; LINE_WIDTH: 0.402443
G1 F12000
G1 X145.306 Y125.408 E.00199
; LINE_WIDTH: 0.441488
G1 X145.286 Y125.473 E.00221
; LINE_WIDTH: 0.480533
G1 X145.266 Y125.538 E.00243
; LINE_WIDTH: 0.538827
G1 X145.246 Y125.603 E.00275
G1 X145.246 Y130.397 E.19369
; LINE_WIDTH: 0.519695
G1 X145.262 Y130.455 E.00233
; LINE_WIDTH: 0.480885
G1 X145.277 Y130.513 E.00214
; LINE_WIDTH: 0.442075
G1 X145.293 Y130.571 E.00195
; LINE_WIDTH: 0.403265
G1 X145.308 Y130.629 E.00176
G1 X145.306 Y124.513 F36000
; LINE_WIDTH: 0.419693
G1 F12000
G1 X145.306 Y124.067 E.01369
G1 X99.694 Y124.067 E1.40038
G3 X99.681 Y125.276 I-26.157 J.331 E.03711
G1 X99.756 Y125.078 E.0065
G1 X99.925 Y124.959 E.00634
G1 X145.075 Y124.959 E1.38621
G1 X145.244 Y125.078 E.00634
G1 X145.319 Y125.276 E.0065
G3 X145.306 Y124.573 I15.197 J-.625 E.02158
G1 X100.14 Y124.513 F36000
; LINE_WIDTH: 0.55782
G1 F12000
G1 X144.8 Y124.513 E1.87383
; CHANGE_LAYER
; Z_HEIGHT: 6.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X142.8 Y124.513 E-.76
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
G1 X160.452 Y134.996
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y121.004 E.46414
G1 X162.248 Y121.004 E.05957
G1 X162.248 Y134.996 E.46414
G1 X160.512 Y134.996 E.05758
G1 X160.06 Y135.388 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y120.612 E.45403
G1 X162.64 Y120.612 E.07928
G1 X162.64 Y135.388 E.45403
G1 X160.12 Y135.388 E.07743
; WIPE_START
M204 S10000
G1 X160.112 Y133.388 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.36 Y134.648 Z7 F36000
G1 Z6.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y134.648 E.01858
G1 X160.8 Y133.579 E.03544
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X160.8 Y130.097 E.05157
G1 X160.8 Y125.903 E.13909
G1 X161.9 Y124.804 E.05157
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y121.352 E.03544
G1 X161.36 Y121.352 E.01858
; WIPE_START
G1 X160.8 Y121.352 E-.21283
G1 X160.8 Y122.421 E-.40593
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.692 Y124.662 Z7 F36000
G1 X135.422 Y129.566 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X135.254 Y129.297 E.01051
G3 X137.223 Y125.415 I2.253 J-1.298 E.17109
G3 X138.496 Y125.595 I.289 J2.551 E.04312
G3 X135.464 Y129.607 I-.989 J2.404 E.31525
G1 X135.746 Y129.345 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.595 Y129.1 E.00885
G3 X137.248 Y125.806 I1.913 J-1.101 E.13398
G3 X137.789 Y125.808 I.261 J2.053 E.01665
G3 X135.785 Y129.378 I-.28 J2.19 E.26526
; WIPE_START
M204 S10000
G1 X135.595 Y129.1 E-.12812
G1 X135.458 Y128.846 E-.10974
G1 X135.365 Y128.572 E-.10985
G1 X135.308 Y128.289 E-.10986
G1 X135.29 Y128 E-.10989
G1 X135.308 Y127.711 E-.10989
G1 X135.351 Y127.498 E-.08265
; WIPE_END
G1 E-.04 F1800
G1 X127.729 Y127.097 Z7 F36000
G1 X105.898 Y125.95 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.919 Y125.94 E.00079
G3 X107.223 Y125.415 I1.588 J2.061 E.0472
G3 X108.496 Y125.595 I.289 J2.551 E.04313
G3 X105.664 Y126.164 I-.989 J2.406 E.44056
G1 X105.853 Y125.991 E.00852
G1 X106.154 Y126.247 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X106.158 Y126.252 E.0002
G3 X107.248 Y125.806 I1.35 J1.748 E.03662
G3 X107.789 Y125.808 I.261 J2.053 E.01665
G3 X105.942 Y126.442 I-.28 J2.191 E.36431
G1 X106.11 Y126.287 E.00701
; WIPE_START
M204 S10000
G1 X106.158 Y126.252 E-.0229
G1 X106.395 Y126.086 E-.10972
G1 X106.654 Y125.958 E-.10992
G1 X106.928 Y125.865 E-.10987
M73 P88 R2
G1 X107.248 Y125.806 E-.12376
G1 X107.5 Y125.79 E-.09587
G1 X107.789 Y125.808 E-.10989
G1 X107.99 Y125.849 E-.07808
; WIPE_END
G1 E-.04 F1800
G1 X115.619 Y126.081 Z7 F36000
G1 X145.698 Y126.998 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X145.698 Y132.054 E.16771
G1 X99.302 Y132.054 E1.53904
G1 X99.302 Y123.946 E.26898
G1 X145.698 Y123.946 E1.53904
G1 X145.698 Y126.938 E.09927
G1 X146.09 Y126.998 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X146.09 Y132.446 E.1674
G1 X98.91 Y132.446 E1.44971
G1 X98.91 Y123.554 E.27325
G1 X146.09 Y123.554 E1.44971
G1 X146.09 Y126.938 E.104
; WIPE_START
M204 S10000
G1 X146.09 Y128.938 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.306 Y125.375 Z7 F36000
G1 Z6.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X145.306 Y124.338 E.03188
G1 X99.694 Y124.338 E1.40149
G1 X99.694 Y125.375 E.03188
G1 X106.069 Y125.375 E.19588
G1 X106.703 Y125.113 E.02109
G1 X107.475 Y125.006 E.02395
G1 X108.251 Y125.101 E.02402
G1 X108.836 Y125.336 E.01935
G1 X109.034 Y125.375 E.0062
G1 X136.069 Y125.375 E.8307
G1 X136.703 Y125.113 E.02108
G1 X137.475 Y125.006 E.02395
G1 X138.251 Y125.101 E.02402
G1 X138.836 Y125.336 E.01935
G1 X139.034 Y125.375 E.0062
G1 X145.246 Y125.375 E.19088
G1 X144.952 Y124.857 F36000
; LINE_WIDTH: 0.374724
G1 F12000
G1 X144.952 Y124.691 E.00446
G1 X139.034 Y124.691 E.16002
G1 X138.453 Y124.71 E.01572
; LINE_WIDTH: 0.406118
G1 X138.301 Y124.721 E.00449
G1 X138.971 Y125.009 E.02157
; LINE_WIDTH: 0.373115
G1 X139.034 Y125.022 E.00173
G1 X144.952 Y125.022 E.15925
G1 X144.952 Y124.917 E.00283
G1 X136.676 Y124.723 F36000
; LINE_WIDTH: 0.41104
G1 F12000
G1 X137.054 Y124.698 E.01136
; LINE_WIDTH: 0.377296
G1 X137.432 Y124.673 E.01032
G1 X138.241 Y124.718 E.02209
G1 X136.676 Y124.723 F36000
; LINE_WIDTH: 0.42016
G1 F12000
G1 X136.321 Y124.707 E.01092
; LINE_WIDTH: 0.373705
G1 X135.966 Y124.691 E.00958
G1 X109.034 Y124.691 E.72596
G1 X108.453 Y124.71 E.01567
; LINE_WIDTH: 0.406129
G1 X108.301 Y124.721 E.00449
G1 X108.971 Y125.009 E.02157
; LINE_WIDTH: 0.373596
G1 X109.034 Y125.022 E.00173
G1 X135.999 Y125.022 E.7266
G1 X136.56 Y124.767 E.01661
; LINE_WIDTH: 0.42581
G1 X136.62 Y124.744 E.002
G1 X106.676 Y124.723 F36000
; LINE_WIDTH: 0.411025
G1 F12000
G1 X107.054 Y124.698 E.01136
; LINE_WIDTH: 0.377302
G1 X107.432 Y124.673 E.01032
G1 X108.241 Y124.718 E.02209
G1 X106.676 Y124.723 F36000
; LINE_WIDTH: 0.420143
G1 F12000
G1 X106.321 Y124.707 E.01092
; LINE_WIDTH: 0.374536
G1 X105.966 Y124.691 E.0096
G1 X100.048 Y124.691 E.15993
G1 X100.048 Y125.022 E.00892
G1 X105.999 Y125.022 E.16082
G1 X106.56 Y124.767 E.01666
; LINE_WIDTH: 0.42579
G1 X106.62 Y124.744 E.002
; WIPE_START
G1 X106.56 Y124.767 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X109.858 Y126.227 Z7 F36000
G1 Z6.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X109.422 Y125.767 I-2.86 J2.278 E.02104
G1 X110.415 Y125.767 E.03294
G1 X114.881 Y130.233 E.20949
G1 X118.091 Y130.233 E.10649
G1 X122.557 Y125.767 E.20949
G1 X125.767 Y125.767 E.10649
G1 X130.233 Y130.233 E.20949
G1 X133.443 Y130.233 E.10649
G1 X134.715 Y128.961 E.05967
G3 X134.715 Y127.039 I3.178 J-.961 E.06468
G1 X133.443 Y125.767 E.05967
G1 X130.233 Y125.767 E.10649
G1 X125.767 Y130.233 E.20949
G1 X122.557 Y130.233 E.10649
G1 X118.091 Y125.767 E.20949
G1 X114.881 Y125.767 E.10649
G1 X110.415 Y130.233 E.20949
G1 X109.422 Y130.233 E.03294
G2 X109.858 Y129.773 I-2.428 J-2.741 E.02104
; WIPE_START
G1 X109.422 Y130.233 E-.24074
G1 X110.415 Y130.233 E-.3774
G1 X110.679 Y129.969 E-.14186
; WIPE_END
G1 E-.04 F1800
G1 X103.691 Y126.9 Z7 F36000
G1 X101.111 Y125.767 Z7
G1 Z6.6
G1 E.8 F1800
G1 F15476.087
G1 X102.739 Y125.767 E.05401
G1 X104.575 Y127.603 E.08612
G2 X104.575 Y128.397 I29.893 J.398 E.02633
G1 X102.739 Y130.233 E.08612
G1 X101.111 Y130.233 E.05401
G1 X99.694 Y130.625 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X99.694 Y131.662 E.03188
G1 X145.306 Y131.662 E1.40149
G1 X145.306 Y130.625 E.03188
G1 X138.931 Y130.625 E.19588
G1 X138.299 Y130.886 E.02102
G1 X137.525 Y130.994 E.02401
G1 X136.749 Y130.899 E.02402
G1 X136.164 Y130.664 E.01935
G1 X135.966 Y130.625 E.0062
G1 X108.931 Y130.625 E.8307
G1 X108.299 Y130.886 E.02102
G1 X107.525 Y130.994 E.02401
G1 X106.749 Y130.899 E.02402
G1 X106.164 Y130.664 E.01935
G1 X105.966 Y130.625 E.0062
G1 X99.754 Y130.625 E.19088
G1 X144.952 Y131.143 F36000
; LINE_WIDTH: 0.375087
G1 F12000
G1 X144.952 Y130.978 E.00447
G1 X139.001 Y130.978 E.16108
G1 X138.442 Y131.233 E.01663
; LINE_WIDTH: 0.408033
G1 X138.326 Y131.277 E.00369
G1 X139.034 Y131.309 E.02109
; LINE_WIDTH: 0.37312
G1 X144.952 Y131.309 E.15925
G1 X144.952 Y131.203 E.00283
G1 X136.699 Y131.279 F36000
; LINE_WIDTH: 0.408755
G1 F12000
G1 X137.065 Y131.303 E.01095
; LINE_WIDTH: 0.377388
G1 X137.432 Y131.327 E.01001
G1 X138.266 Y131.281 E.02277
G1 X136.699 Y131.279 F36000
; LINE_WIDTH: 0.417865
G1 F12000
G1 X136.364 Y131.135 E.01113
; LINE_WIDTH: 0.373787
G1 X135.966 Y130.978 E.01152
G1 X109.001 Y130.978 E.72702
G1 X108.442 Y131.233 E.01656
; LINE_WIDTH: 0.408033
G1 X108.326 Y131.277 E.00369
G1 X109.034 Y131.309 E.02109
; LINE_WIDTH: 0.37351
G1 X135.966 Y131.309 E.72553
G1 X136.547 Y131.29 E.01567
; LINE_WIDTH: 0.421395
G1 X136.639 Y131.283 E.00283
G1 X106.699 Y131.279 F36000
; LINE_WIDTH: 0.40874
G1 F12000
G1 X107.065 Y131.303 E.01095
; LINE_WIDTH: 0.377387
G1 X107.432 Y131.327 E.01001
G1 X108.266 Y131.281 E.02277
G1 X106.699 Y131.279 F36000
; LINE_WIDTH: 0.41785
G1 F12000
G1 X106.364 Y131.135 E.01113
; LINE_WIDTH: 0.374346
G1 X105.966 Y130.978 E.01154
G1 X100.048 Y130.978 E.15984
G1 X100.048 Y131.309 E.00892
G1 X105.966 Y131.309 E.15984
G1 X106.547 Y131.29 E.01571
; LINE_WIDTH: 0.42138
G1 X106.639 Y131.283 E.00283
; WIPE_START
G1 X106.547 Y131.29 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X114.176 Y131.045 Z7 F36000
G1 X139.491 Y130.233 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.119 Y130.233 E.05401
G1 X145.35 Y126.002 E.19846
G1 X145.35 Y129.998 E.13254
G1 X141.119 Y125.767 E.19846
G1 X139.491 Y125.767 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 6.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X141.119 Y125.767 E-.61876
G1 X141.382 Y126.03 E-.14124
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
G1 X160.452 Y134.816
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X160.452 Y121.184 E.45219
G1 X162.248 Y121.184 E.05957
G1 X162.248 Y134.816 E.45219
G1 X160.512 Y134.816 E.05758
G1 X160.06 Y135.208 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y120.792 E.44296
G1 X162.64 Y120.792 E.07928
G1 X162.64 Y135.208 E.44296
G1 X160.12 Y135.208 E.07743
; WIPE_START
M204 S10000
G1 X160.112 Y133.208 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.039 Y125.632 Z7.2 F36000
G1 X161.54 Y121.532 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y121.532 E.02455
G1 X160.8 Y122.421 E.02946
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X160.8 Y125.903 E.05157
G1 X160.8 Y130.097 E.13909
G1 X161.9 Y131.196 E.05157
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y134.468 E.02946
G1 X161.54 Y134.468 E.02455
; WIPE_START
G1 X160.8 Y134.468 E-.28124
G1 X160.8 Y133.579 E-.33752
G1 X161.063 Y133.317 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.511 Y132.212 Z7.2 F36000
G1 X135.422 Y129.566 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X135.253 Y129.298 E.01051
G3 X137.169 Y125.418 I2.251 J-1.301 E.16952
G1 X137.5 Y125.397 E.011
G3 X135.463 Y129.608 I.004 J2.6 E.34896
G1 X135.747 Y129.346 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.752 Y129.341 E.00023
G3 X137.22 Y125.808 I1.752 J-1.344 E.14219
G1 X137.5 Y125.79 E.00864
M73 P88 R1
G3 X135.942 Y129.558 I.004 J2.208 E.26654
G1 X135.787 Y129.39 E.00701
; WIPE_START
M204 S10000
G1 X135.752 Y129.341 E-.02292
G1 X135.586 Y129.105 E-.10972
G1 X135.458 Y128.846 E-.10991
G1 X135.365 Y128.572 E-.10987
G1 X135.308 Y128.289 E-.10986
G1 X135.29 Y128 E-.1099
G1 X135.308 Y127.711 E-.10987
G1 X135.348 Y127.51 E-.07796
; WIPE_END
G1 E-.04 F1800
G1 X127.727 Y127.106 Z7.2 F36000
G1 X105.898 Y125.95 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.917 Y125.937 E.00077
G3 X107.169 Y125.418 I1.587 J2.06 E.04548
G1 X107.5 Y125.397 E.011
G3 X105.668 Y126.156 I.004 J2.6 E.47446
G1 X105.853 Y125.99 E.00824
G1 X106.155 Y126.246 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X106.396 Y126.088 E.00886
G3 X107.22 Y125.808 I1.108 J1.91 E.0269
G1 X107.5 Y125.79 E.00864
G3 X106.111 Y126.284 I.004 J2.208 E.38005
; WIPE_START
M204 S10000
G1 X106.396 Y126.088 E-.13137
G1 X106.654 Y125.958 E-.10981
G1 X106.928 Y125.865 E-.11002
G1 X107.22 Y125.808 E-.11278
G1 X107.5 Y125.79 E-.10681
G1 X107.789 Y125.808 E-.1099
G1 X107.993 Y125.849 E-.07932
; WIPE_END
G1 E-.04 F1800
G1 X115.621 Y126.119 Z7.2 F36000
G1 X145.698 Y127.183 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X145.698 Y131.765 E.15199
G1 X99.302 Y131.765 E1.53904
G1 X99.302 Y124.235 E.24978
G1 X145.698 Y124.235 E1.53904
G1 X145.698 Y127.123 E.09579
G1 X146.09 Y127.183 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X146.09 Y132.157 E.15284
G1 X98.91 Y132.157 E1.44971
G1 X98.91 Y123.843 E.25547
G1 X146.09 Y123.843 E1.44971
G1 X146.09 Y127.123 E.10078
; WIPE_START
M204 S10000
G1 X146.09 Y129.123 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.499 Y126.567 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G2 X140.333 Y126.258 I-1.256 J.475 E.01167
G1 X141.61 Y126.258 E.04236
G1 X144.973 Y129.621 E.15776
G1 X144.973 Y126.379 E.10752
G1 X141.61 Y129.742 E.15776
G1 X140.333 Y129.742 E.04236
G2 X140.499 Y129.433 I-1.091 J-.785 E.01167
; WIPE_START
G1 X140.333 Y129.742 E-.13329
G1 X141.61 Y129.742 E-.48525
G1 X141.873 Y129.479 E-.14146
; WIPE_END
G1 E-.04 F1800
G1 X134.48 Y128.32 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G3 X134.529 Y128.047 I.828 J.006 E.00772
G1 X110.493 Y127.45 F36000
G1 F12000
G1 X110.52 Y128.012 E.01559
G1 X110.481 Y128.093 E.0025
G1 X110.385 Y128.612 F36000
G1 F12000
M73 P89 R1
G1 X110.305 Y128.924 E.00894
G1 X110.253 Y129.339 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X110.125 Y129.339 E.00426
G3 X109.879 Y129.742 I-1.655 J-.731 E.01571
G1 X110.906 Y129.742 E.03406
G1 X114.39 Y126.258 E.16347
G1 X110.906 Y126.258 E.11559
G1 X114.39 Y129.742 E.16347
G1 X118.582 Y129.742 E.13904
G1 X122.066 Y126.258 E.16347
G1 X118.582 Y126.258 E.11559
G1 X122.066 Y129.742 E.16347
G1 X126.258 Y129.742 E.13904
G1 X129.742 Y126.258 E.16347
G1 X126.258 Y126.258 E.11559
G1 X129.742 Y129.742 E.16347
G1 X133.934 Y129.742 E.13904
G1 X134.715 Y128.961 E.03665
G3 X134.613 Y128.588 I1.366 J-.573 E.01287
G1 X134.241 Y128.653 E.01252
G3 X134.182 Y127.814 I3.277 J-.655 E.02798
G1 X134.486 Y127.564 E.01307
G2 X134.222 Y127.443 I-.181 J.048 E.01099
G3 X134.419 Y126.743 I2.679 J.372 E.02421
G1 X133.934 Y126.258 E.02275
G1 X132.305 Y126.258 E.05401
; WIPE_START
G1 X133.934 Y126.258 E-.61876
G1 X134.197 Y126.521 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X126.601 Y127.271 Z7.2 F36000
G1 X101.602 Y129.742 Z7.2
G1 Z6.8
G1 E.8 F1800
G1 F15476.087
G1 X103.23 Y129.742 E.05401
G1 X104.57 Y128.402 E.06285
G3 X104.57 Y127.598 I.972 J-.402 E.0274
G1 X103.23 Y126.258 E.06286
G1 X101.602 Y126.258 E.05401
G1 X99.666 Y129.973 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X99.665 Y126.114 E.10692
; Slow Down End
G1 X106.377 Y130.776 F36000
; LINE_WIDTH: 0.425095
G1 F12000
G1 X107.133 Y130.978 E.02439
G1 X107.916 Y130.972 E.02436
G1 X108.669 Y130.757 E.02439
G1 X109.224 Y130.436 E.01997
; Slow Down Start
; LINE_WIDTH: 0.41999
G1 F3000;_EXTRUDE_SET_SPEED
G1 X109.303 Y130.391 E.00282
G1 X109.591 Y130.134 E.01185
G1 X135.408 Y130.134 E.79325
G1 X135.697 Y130.39 E.01187
G1 X135.778 Y130.436 E.00286
; Slow Down End
; LINE_WIDTH: 0.425262
G1 F12000
G1 X136.377 Y130.776 E.02146
G1 X137.134 Y130.978 E.0244
G1 X137.916 Y130.972 E.02436
G1 X138.669 Y130.757 E.0244
G1 X139.224 Y130.436 E.01998
; Slow Down Start
; LINE_WIDTH: 0.41999
G1 F3000;_EXTRUDE_SET_SPEED
G1 X139.303 Y130.39 E.00282
G1 X139.592 Y130.134 E.01187
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.412946
;_EXTRUDE_SET_SPEED
G1 X139.746 Y130.132 E.00463
G1 X139.871 Y129.902 E.00791
G2 X139.896 Y130.128 I.185 J.094 E.00729
G1 X139.943 Y130.134 E.00142
G2 X145.176 Y130.129 I2.372 J-263.458 E.15778
G1 X145.334 Y129.973 E.00669
G1 X145.317 Y130.436 E.01397
; Slow Down End
; LINE_WIDTH: 0.424858
G1 F12000
G2 X145.306 Y131.373 I12.991 J.627 E.02916
G1 X138.702 Y131.373 E.20554
; LINE_WIDTH: 0.425185
G2 X136.298 Y131.373 I-1.202 J94.389 E.07487
G1 X108.702 Y131.373 E.85963
G2 X106.298 Y131.373 I-1.202 J94.392 E.07487
G1 X99.694 Y131.373 E.20572
; LINE_WIDTH: 0.401455
G2 X99.666 Y129.973 I-24.414 J-.21 E.0409
; Slow Down Start
; LINE_WIDTH: 0.418779
G1 F3000;_EXTRUDE_SET_SPEED
G1 X99.824 Y130.129 E.0068
G2 X105.079 Y130.133 I3.402 J-1163.164 E.16096
G1 X105.149 Y130.008 E.0044
G1 X105.21 Y130.13 E.00417
G1 X105.408 Y130.134 E.00607
G1 X105.697 Y130.39 E.01183
G1 X105.778 Y130.436 E.00285
; Slow Down End
; LINE_WIDTH: 0.41999
G1 F12000
G1 X106.325 Y130.746 E.01932
G1 X100.098 Y130.538 F36000
; LINE_WIDTH: 0.473955
G1 F12000
G1 X100.098 Y130.969 E.01513
G1 X105.886 Y130.968 E.20331
G1 X105.392 Y130.667 E.02031
G1 X105.251 Y130.541 E.00666
G1 X100.158 Y130.538 E.17887
G1 X105.124 Y129.901 F36000
; LINE_WIDTH: 0.38292
G1 F12000
G1 X104.936 Y129.624 E.00927
G1 X104.894 Y129.438 E.0053
G1 X104.882 Y126.629 F36000
G1 F12000
G1 X104.937 Y126.351 E.00784
G1 X105.093 Y126.147 E.00713
; WIPE_START
G1 X104.937 Y126.351 E-.36178
G1 X104.882 Y126.629 E-.39822
; WIPE_END
G1 E-.04 F1800
G1 X109.109 Y130.969 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
; LINE_WIDTH: 0.473695
G1 F12000
G1 X135.891 Y130.969 E.94011
G1 X135.393 Y130.666 E.02045
G1 X135.252 Y130.538 E.00669
G1 X109.748 Y130.538 E.89527
G3 X109.161 Y130.939 I-1.449 J-1.491 E.02505
G1 X139.115 Y130.967 F36000
; LINE_WIDTH: 0.474133
G1 F12000
G3 X139.943 Y130.969 I.362 J25.789 E.02909
G1 X144.902 Y130.969 E.17424
G1 X144.902 Y130.538 E.01514
G3 X139.751 Y130.538 I-2.479 J-748.671 E.18098
G3 X139.167 Y130.937 I-1.452 J-1.494 E.02499
G1 X140.118 Y129.371 F36000
; LINE_WIDTH: 0.38292
G1 F12000
G1 X140.062 Y129.648 E.00782
G1 X139.907 Y129.854 E.00715
; WIPE_START
G1 X140.062 Y129.648 E-.36288
G1 X140.118 Y129.371 E-.39712
; WIPE_END
G1 E-.04 F1800
G1 X139.874 Y126.102 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
G1 F12000
G1 X140.066 Y126.349 E.00867
G1 X140.107 Y126.562 E.00601
G1 X145.335 Y126.054 F36000
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.335 Y129.913 E.10692
; Slow Down End
G1 X145.335 Y126.054 F36000
; Slow Down Start
; LINE_WIDTH: 0.417834
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.176 Y125.869 E.00746
G2 X139.919 Y125.867 I-3.107 J1489.923 E.1606
G1 X139.85 Y125.972 E.00385
G1 X139.874 Y126.102 E.00404
G1 X139.766 Y125.872 E.00778
G1 X139.592 Y125.866 E.0053
G1 X139.303 Y125.61 E.0118
G1 X139.222 Y125.564 E.00284
; Slow Down End
; LINE_WIDTH: 0.429651
G1 F12000
G1 X138.632 Y125.228 E.02141
G1 X137.918 Y125.026 E.02338
G1 X137.475 Y125.005 E.01397
G1 X136.695 Y125.096 E.02475
G1 X135.982 Y125.419 E.02469
G1 X135.792 Y125.564 E.00751
; Slow Down Start
; LINE_WIDTH: 0.41999
G1 F3000;_EXTRUDE_SET_SPEED
G1 X135.399 Y125.864 E.0152
G1 X135.189 Y125.866 E.00644
G1 X109.592 Y125.866 E.7865
G1 X109.303 Y125.61 E.01187
G1 X109.222 Y125.564 E.00286
; Slow Down End
; LINE_WIDTH: 0.424258
G1 F12000
G1 X108.632 Y125.228 E.02111
G1 X107.867 Y125.022 E.02462
G1 X107.143 Y125.022 E.02249
G1 X106.703 Y125.114 E.01398
G1 X105.982 Y125.419 E.02433
G1 X105.793 Y125.564 E.00739
; Slow Down Start
; LINE_WIDTH: 0.41999
G1 F3000;_EXTRUDE_SET_SPEED
G1 X105.407 Y125.859 E.01493
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.413776
;_EXTRUDE_SET_SPEED
G1 X105.258 Y125.867 E.00452
G1 X105.129 Y126.099 E.008
G2 X105.102 Y125.871 I-.182 J-.094 E.00734
G1 X105.057 Y125.866 E.00139
G2 X99.824 Y125.869 I-2.372 J397.632 E.15813
G1 X99.665 Y126.054 E.00738
G1 X99.683 Y125.564 E.01484
; Slow Down End
; LINE_WIDTH: 0.424835
G1 F12000
G2 X99.694 Y124.627 I-12.9 J-.627 E.02915
G1 X106.606 Y124.627 E.2151
; LINE_WIDTH: 0.43831
G2 X108.712 Y124.627 I1.053 J-71.953 E.06785
G1 X135.872 Y124.627 E.87508
G2 X137.451 Y124.628 I.796 J-12.761 E.05091
G2 X145.306 Y124.627 I3.849 J-772.838 E.25309
G1 X145.306 Y125.246 E.01995
; LINE_WIDTH: 0.402039
G1 X145.333 Y125.994 E.0219
G1 X144.902 Y125.246 F36000
; LINE_WIDTH: 0.474051
G1 F12000
G1 X144.902 Y125.031 E.00757
G2 X139.116 Y125.033 I-2.479 J1450.238 E.20327
G1 X139.608 Y125.333 E.02024
G1 X139.751 Y125.463 E.0068
G3 X144.902 Y125.462 I2.671 J737.615 E.18095
G1 X144.902 Y125.306 E.00546
G1 X135.853 Y125.031 F36000
; LINE_WIDTH: 0.4737
G1 F12000
G1 X109.11 Y125.031 E.93876
G1 X109.607 Y125.334 E.02042
G1 X109.748 Y125.462 E.0067
G1 X135.262 Y125.462 E.89563
G1 X135.801 Y125.061 E.02356
G1 X105.847 Y125.033 F36000
; LINE_WIDTH: 0.474107
G1 F12000
G3 X105.057 Y125.031 I-.334 J-29.661 E.02776
G1 X100.098 Y125.031 E.17423
G1 X100.098 Y125.462 E.01514
G1 X105.259 Y125.462 E.18135
G1 X105.795 Y125.063 E.02347
; CHANGE_LAYER
; Z_HEIGHT: 7
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X105.259 Y125.462 E-.25379
G1 X103.927 Y125.462 E-.50621
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
G1 X160.452 Y134.633
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y121.367 E.44005
G1 X162.248 Y121.367 E.05957
G1 X162.248 Y134.633 E.44005
G1 X160.512 Y134.633 E.05758
G1 X160.06 Y135.025 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y120.975 E.43172
G1 X162.64 Y120.975 E.07928
G1 X162.64 Y135.025 E.43172
G1 X160.12 Y135.025 E.07743
; WIPE_START
M204 S10000
G1 X160.111 Y133.025 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.723 Y134.285 Z7.4 F36000
G1 Z7
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y134.285 E.03062
G1 X160.8 Y133.579 E.02339
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X160.8 Y130.097 E.05157
G1 X160.8 Y125.903 E.13909
G1 X161.9 Y124.804 E.05157
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y121.715 E.02339
G1 X161.723 Y121.715 E.03062
; WIPE_START
G1 X160.8 Y121.715 E-.35077
G1 X160.8 Y122.421 E-.26799
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.761 Y124.904 Z7.4 F36000
G1 X145.698 Y127.355 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X145.698 Y131.443 E.13562
G1 X99.302 Y131.443 E1.53904
G1 X99.302 Y124.557 E.22844
G1 X145.698 Y124.557 E1.53904
G1 X145.698 Y127.295 E.09083
G1 X146.09 Y127.355 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X146.09 Y131.835 E.13767
G1 X98.91 Y131.835 E1.44971
G1 X98.91 Y124.165 E.2357
G1 X146.09 Y124.165 E1.44971
G1 X146.09 Y127.295 E.09618
; WIPE_START
M204 S10000
G1 X146.09 Y129.295 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X140.716 Y127.637 Z7.4 F36000
G1 Z7
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.42131
G1 F3000
G3 X140.716 Y128.056 I-6.415 J.204 E.01292
G1 X140.707 Y128.193 E.00421
G1 X140.338 Y128.193 E.0114
G1 X140.338 Y127.613 E.0179
G1 X140.338 Y126.844 F36000
G1 F3000
G1 X140.338 Y126.158 E.02114
G1 X139.99 Y125.646 F36000
; LINE_WIDTH: 0.41923
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X140.228 Y125.604 E.01361
G1 X142.931 Y125.604 E.15197
G1 X140.542 Y126.025 E.1364
G1 X140.658 Y126.208 E.01219
G1 X140.784 Y126.459 E.01577
G1 X145.328 Y125.658 E.25953
G1 X145.328 Y126.134 E.0268
G1 X140.843 Y126.925 E.25617
G1 X140.728 Y127.088 E.01119
G1 X140.408 Y127.088 E.01799
G3 X140.486 Y127.393 I-1.24 J.479 E.01778
G1 X140.89 Y127.393 E.02271
G1 X145.328 Y126.611 E.25349
G1 X145.328 Y127.087 E.0268
G1 X141.122 Y127.829 E.24018
G1 X141.114 Y128.307 E.02688
G1 X145.328 Y127.564 E.24065
G1 X145.328 Y128.04 E.0268
G1 X140.408 Y128.912 E.28104
G1 X140.728 Y128.912 E.01802
G1 X140.927 Y129.192 E.01929
G1 X140.889 Y129.299 E.00639
G1 X145.328 Y128.517 E.25353
G1 X145.328 Y128.993 E.0268
G1 X140.642 Y129.819 E.26761
G1 X140.407 Y130.175 E.02398
G1 X140.25 Y130.365 E.01388
G1 X145.328 Y129.469 E.29003
G1 X145.328 Y129.946 E.0268
G1 X141.627 Y130.598 E.21136
G1 X140.338 Y129.156 F36000
; LINE_WIDTH: 0.42131
; LAYER_HEIGHT: 0.2
G1 F3000
G1 X140.338 Y129.51 E.01091
G1 X140.096 Y129.898 E.01409
G1 X139.959 Y130.069 E.00674
G1 X139.959 Y125.931 E.12758
G1 X139.776 Y125.727 E.00846
G1 X139.581 Y125.551 E.00809
G1 X139.581 Y130.449 E.151
G1 X139.203 Y130.727 E.01448
G1 X139.203 Y125.273 E.16815
G1 X138.824 Y125.071 E.01324
G1 X138.824 Y130.929 E.18065
G1 X138.446 Y131.072 E.01247
G1 X138.446 Y124.928 E.18944
G1 X138.324 Y124.89 E.00395
G1 X138.067 Y124.89 E.0079
G1 X138.067 Y131.11 E.19179
G1 X137.689 Y131.11 E.01167
G1 X137.689 Y124.89 E.19179
G1 X137.311 Y124.89 E.01167
G1 X137.311 Y131.11 E.19179
G1 X136.932 Y131.11 E.01167
M73 P90 R1
G1 X136.932 Y124.89 E.19179
G1 X136.676 Y124.89 E.0079
G1 X136.554 Y124.928 E.00395
G1 X136.554 Y131.072 E.18944
G1 X136.175 Y130.929 E.01247
G1 X136.175 Y125.071 E.18064
G1 X135.797 Y125.274 E.01324
G1 X135.797 Y130.726 E.16813
G1 X135.419 Y130.448 E.01448
G1 X135.419 Y125.552 E.15097
G1 X135.222 Y125.728 E.00814
G1 X135.04 Y125.932 E.00842
G1 X135.04 Y130.068 E.12754
G1 X134.906 Y129.901 E.00662
G1 X134.662 Y129.509 E.01423
G1 X134.662 Y129.156 E.01088
G1 X134.7 Y130.25 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X135.223 Y130.778 E.02284
G1 X135.609 Y131.051 E.01453
G1 X109.391 Y131.051 E.80559
G1 X109.777 Y130.778 E.01453
G1 X110.296 Y130.255 E.02264
G1 X110.509 Y129.946 E.01154
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X110.606 Y129.806 E.00522
G1 X110.839 Y129.326 E.01641
G1 X113.244 Y129.326 E.07388
G1 X113.864 Y129.946 E.02695
G2 X114.155 Y130.123 I.316 J-.191 E.01089
G1 X118.678 Y129.326 E.14113
G1 X120.92 Y129.326 E.06887
G1 X121.68 Y130.086 E.03302
G1 X121.846 Y130.138 E.00535
G1 X126.453 Y129.326 E.14374
G1 X128.596 Y129.326 E.06585
G1 X128.788 Y129.518 E.00835
G1 X128.954 Y129.57 E.00535
G1 X130.34 Y129.326 E.04325
G3 X134.163 Y129.333 I1.654 J132.572 E.11749
G1 X134.396 Y129.811 E.01632
G1 X134.489 Y129.946 E.00505
; Slow Down End
G1 F12000
G1 X134.666 Y130.201 E.00953
G1 X134.084 Y130.023 F36000
G1 F12000
G2 X134.589 Y130.674 I2.352 J-1.303 E.02541
; LINE_WIDTH: 0.444322
G1 X131.459 Y130.674 E.10238
; LINE_WIDTH: 0.492985
G1 X128.329 Y130.674 E.11479
; LINE_WIDTH: 0.541649
G1 X125.199 Y130.674 E.1272
; LINE_WIDTH: 0.40743
G1 X125 Y130.638 E.00602
; LINE_WIDTH: 0.38231
G1 X124.801 Y130.601 E.0056
; LINE_WIDTH: 0.581195
G1 F11704.055
G1 X123.679 Y130.65 E.04923
; LINE_WIDTH: 0.611625
G1 F11077.801
G1 X122.558 Y130.699 E.05202
; LINE_WIDTH: 0.36975
G1 F12000
G1 X122.159 Y130.571 E.01115
; LINE_WIDTH: 0.611625
G1 F11077.801
G1 X122.344 Y130.473 E.0097
; LINE_WIDTH: 0.581195
G1 F11704.055
G1 X122.529 Y130.375 E.00918
; LINE_WIDTH: 0.38231
G1 F12000
G1 X123.642 Y130.229 E.03104
; Slow Down Start
; LINE_WIDTH: 0.430189
G1 F3000;_EXTRUDE_SET_SPEED
G1 X124.755 Y130.082 E.03542
G1 X125.122 Y129.946 E.01234
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.419994
;_EXTRUDE_SET_SPEED
G1 X126.486 Y129.703 E.04257
G1 X128.439 Y129.703 E.06004
G1 X128.521 Y129.784 E.00355
G1 X128.911 Y129.946 E.01296
G2 X129.019 Y129.942 I.04 J-.365 E.00333
G1 X130.373 Y129.703 E.04225
G1 X133.923 Y129.703 E.10908
G1 X134.045 Y129.946 E.00836
; Slow Down End
; LINE_WIDTH: 0.41999
G1 F12000
G1 X134.057 Y129.97 E.00082
G1 X125.199 Y130.305 F36000
; LINE_WIDTH: 0.427892
G1 F12000
G1 X125.465 Y130.282 E.00837
; LINE_WIDTH: 0.474396
G1 X125.731 Y130.258 E.00938
; LINE_WIDTH: 0.5209
G1 X125.996 Y130.235 E.01039
; LINE_WIDTH: 0.567404
G1 X126.262 Y130.212 E.0114
; LINE_WIDTH: 0.634031
G1 F10657.911
G1 X126.528 Y130.189 E.01285
G1 X128.244 Y130.189 E.08264
; LINE_WIDTH: 0.612434
G1 F11062.064
G1 X128.379 Y130.213 E.00639
; LINE_WIDTH: 0.562982
G1 F12000
G1 X128.515 Y130.238 E.00584
; LINE_WIDTH: 0.51353
G1 X128.65 Y130.263 E.00528
; LINE_WIDTH: 0.464078
G1 X128.786 Y130.287 E.00473
; LINE_WIDTH: 0.405086
G2 X129.083 Y130.305 I.188 J-.644 E.00888
; LINE_WIDTH: 0.427406
G1 X129.35 Y130.282 E.00838
; LINE_WIDTH: 0.474018
G1 X129.616 Y130.258 E.00939
; LINE_WIDTH: 0.52063
G1 X129.882 Y130.235 E.01041
; LINE_WIDTH: 0.567242
G1 X130.149 Y130.212 E.01143
; LINE_WIDTH: 0.635324
G1 F10634.647
G1 X130.415 Y130.189 E.01291
G1 X133.558 Y130.189 E.15172
G1 X121.813 Y130.596 F36000
; LINE_WIDTH: 0.5888
G1 F11540.999
G1 X121.956 Y130.586 E.00639
; LINE_WIDTH: 0.61416
G1 F11028.639
G1 X122.099 Y130.575 E.00668
G1 X121.413 Y130.352 F36000
; LINE_WIDTH: 0.439507
G1 F12000
G1 X121.513 Y130.413 E.00378
; LINE_WIDTH: 0.478539
G1 X121.613 Y130.474 E.00416
; LINE_WIDTH: 0.517572
G1 X121.713 Y130.535 E.00453
; LINE_WIDTH: 0.556604
G1 X121.813 Y130.596 E.0049
G1 X121.68 Y130.616 E.00564
; LINE_WIDTH: 0.517572
G1 X121.546 Y130.635 E.00521
; LINE_WIDTH: 0.478539
G1 X121.413 Y130.655 E.00478
; LINE_WIDTH: 0.439507
G1 X121.28 Y130.674 E.00435
; LINE_WIDTH: 0.442594
G1 X120.648 Y130.674 E.02057
; LINE_WIDTH: 0.487802
G1 X120.017 Y130.674 E.02289
; LINE_WIDTH: 0.533009
G1 X119.385 Y130.674 E.02522
; LINE_WIDTH: 0.578217
G1 F11769.184
G1 X118.754 Y130.674 E.02755
; Slow Down Start
; LINE_WIDTH: 0.468443
G1 F3000;_EXTRUDE_SET_SPEED
G1 X114.236 Y130.584 E.15667
G1 X117.473 Y129.946 E.1144
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.42812
;_EXTRUDE_SET_SPEED
G3 X118.711 Y129.703 I6.707 J30.885 E.0396
G1 X120.764 Y129.703 E.06442
G1 X121.007 Y129.946 E.01079
; Slow Down End
; LINE_WIDTH: 0.41999
G1 F12000
G1 X121.371 Y130.31 E.01582
G1 X118.754 Y130.189 F36000
; LINE_WIDTH: 0.63716
G1 F10601.777
G1 X120.502 Y130.189 E.08468
G1 X113.722 Y130.338 F36000
; LINE_WIDTH: 0.441349
G1 F12000
G1 X113.822 Y130.4 E.00383
; LINE_WIDTH: 0.484067
G1 X113.922 Y130.463 E.00424
; LINE_WIDTH: 0.526784
G1 X114.022 Y130.526 E.00465
; LINE_WIDTH: 0.569502
G1 F11963.966
G1 X114.122 Y130.589 E.00507
G1 X113.987 Y130.61 E.00586
; LINE_WIDTH: 0.526784
G1 F12000
G1 X113.853 Y130.631 E.00538
; LINE_WIDTH: 0.484067
G1 X113.718 Y130.653 E.00491
; LINE_WIDTH: 0.420682
G1 X113.583 Y130.674 E.0042
G1 X110.414 Y130.674 E.09755
G2 X110.952 Y129.946 I-2.728 J-2.578 E.02794
; Slow Down Start
; LINE_WIDTH: 0.41999
G1 F3000;_EXTRUDE_SET_SPEED
G1 X111.077 Y129.703 E.0084
G1 X113.088 Y129.703 E.06177
G1 X113.331 Y129.946 E.01056
; Slow Down End
G1 F12000
G1 X113.68 Y130.295 E.01518
G1 X111.379 Y130.189 F36000
; LINE_WIDTH: 0.63716
G1 F10601.777
G1 X112.826 Y130.189 E.07009
G1 X113.96 Y127.006 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.42047
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X111.1 Y127.511 E.16429
G1 X111.13 Y127.983 E.02678
G1 X119.055 Y126.586 E.45526
G1 X119.461 Y126.992 E.03249
G1 X111.102 Y128.466 E.48021
G1 X111.09 Y128.606 E.00798
G1 X110.486 Y128.607 E.03417
G3 X110.426 Y128.858 I-1.248 J-.163 E.01463
G1 X110.408 Y128.911 E.00319
G1 X110.864 Y128.913 E.02576
G1 X113.033 Y128.53 E.12464
G1 X113.095 Y128.592 E.00494
G1 X120.984 Y127.201 E.45323
G1 X121.444 Y127.228 E.02607
G1 X121.492 Y127.496 E.01539
G1 X126.719 Y126.574 E.30032
G1 X126.799 Y126.653 E.00636
G1 X113.501 Y128.998 E.76392
G1 X113.907 Y129.404 E.03249
G1 X127.205 Y127.06 E.76392
G1 X127.279 Y127.134 E.00595
G1 X128.912 Y127.236 E.09255
G1 X120.839 Y128.66 E.46379
G1 X121.245 Y129.066 E.03249
G1 X134.07 Y126.805 E.73677
G1 X134.272 Y127.088 E.01967
G1 X134.556 Y127.088 E.01606
G1 X134.581 Y127.119 E.0023
G1 X134.555 Y127.197 E.00463
G1 X121.651 Y129.472 E.74131
G1 X121.889 Y129.711 E.01908
G1 X128.415 Y128.56 E.37486
G1 X128.582 Y128.728 E.01342
G1 X133.879 Y127.794 E.30429
G1 X133.883 Y128.271 E.02699
G1 X128.745 Y129.177 E.29519
G1 X134.283 Y127.638 F36000
; LINE_WIDTH: 0.42131
; LAYER_HEIGHT: 0.2
G1 F3000
G2 X134.293 Y128.193 I4.474 J.203 E.01714
G1 X134.662 Y128.193 E.01138
G1 X134.662 Y127.613 E.01788
G1 X134.662 Y126.844 F36000
G1 F3000
G1 X134.662 Y126.159 E.02111
G1 X139.315 Y124.928 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.354707
G1 F15000
G3 X139.793 Y125.273 I-8.939 J12.91 E.01499
G1 X140.153 Y125.224 E.00923
G1 X145.34 Y125.224 E.13177
G1 X145.34 Y124.915 E.00786
G1 X140.153 Y124.915 E.13177
G3 X139.375 Y124.928 I-.771 J-23.314 E.01979
; WIPE_START
G1 X140.153 Y124.915 E-.29597
G1 X141.375 Y124.915 E-.46403
; WIPE_END
G1 E-.04 F1800
G17
G3 Z7.4 I-1.152 J-.393 P1  F36000
G1 X139.271 Y131.085 Z7.4
G1 Z7
G1 E.8 F1800
; LINE_WIDTH: 0.3523
G1 F15000
G1 X145.34 Y131.085 E.153
G1 X145.34 Y130.776 E.0078
G1 X139.72 Y130.776 E.14169
G1 X139.323 Y131.055 E.01224
G1 X110.3 Y125.75 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X109.777 Y125.222 E.02283
G1 X109.391 Y124.949 E.01455
G1 X135.609 Y124.949 E.80559
G1 X135.223 Y125.222 E.01453
G1 X134.722 Y125.724 E.0218
G2 X134.497 Y126.054 I1.827 J1.48 E.01228
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X134.291 Y126.403 E.01245
G1 X134.165 Y126.256 E.00592
G1 X134.039 Y126.234 E.00394
G1 X131.543 Y126.674 E.07787
G1 X127.404 Y126.674 E.12717
G1 X126.929 Y126.199 E.02066
G1 X126.763 Y126.146 E.00535
G1 X123.769 Y126.674 E.09342
G1 X119.728 Y126.674 E.12415
G1 X119.238 Y126.184 E.02131
G1 X119.072 Y126.132 E.00535
G1 X115.995 Y126.674 E.09602
G1 X114.077 Y126.674 E.05892
G2 X113.908 Y126.585 I-.129 J.04 E.0065
G1 X113.403 Y126.674 E.01577
G3 X110.836 Y126.666 I-1.027 J-81.408 E.07886
G1 X110.605 Y126.191 E.01624
G1 X110.511 Y126.054 E.00511
; Slow Down End
G1 F12000
G1 X110.335 Y125.799 E.00953
G1 X114.205 Y126.297 F36000
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X114.172 Y126.255 E.00166
G1 X113.941 Y126.205 E.00727
G1 X113.37 Y126.297 E.01777
G1 X111.077 Y126.297 E.07045
G1 X110.955 Y126.054 E.00836
; Slow Down End
; LINE_WIDTH: 0.434755
G1 F12000
G1 X110.917 Y125.978 E.00271
G2 X110.411 Y125.326 I-2.356 J1.304 E.02646
G3 X119.105 Y125.338 I2.758 J1134.935 E.27759
G1 X119.75 Y125.326 E.0206
G3 X126.796 Y125.342 I-.038 J1582.972 E.22497
G1 X127.447 Y125.326 E.02079
; LINE_WIDTH: 0.440493
G1 X129.457 Y125.326 E.06514
; LINE_WIDTH: 0.470205
G3 X133.926 Y125.367 I1.005 J133.991 E.15563
; LINE_WIDTH: 0.499093
G1 X134.494 Y125.364 E.02111
G1 X134.136 Y125.832 E.02192
; LINE_WIDTH: 0.477155
G1 X134.051 Y125.827 E.003
; Slow Down Start
; LINE_WIDTH: 0.478898
G1 F3000;_EXTRUDE_SET_SPEED
G1 X133.966 Y125.822 E.00302
G1 X132.77 Y126.054 E.0433
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.424589
;_EXTRUDE_SET_SPEED
G3 X131.51 Y126.297 I-7.938 J-37.742 E.03989
G1 X127.561 Y126.297 E.12284
G1 X127.318 Y126.054 E.01069
; Slow Down End
; LINE_WIDTH: 0.44431
G1 F12000
G1 X127.195 Y125.932 E.00565
G1 X126.796 Y125.751 E.01437
G1 X125.066 Y126.054 E.05742
; Slow Down Start
; LINE_WIDTH: 0.421956
G1 F3000;_EXTRUDE_SET_SPEED
G3 X123.736 Y126.297 I-19.82 J-104.729 E.04177
G1 X119.885 Y126.297 E.11895
G1 X119.642 Y126.054 E.01062
; Slow Down End
; LINE_WIDTH: 0.439376
G1 F12000
G1 X119.505 Y125.917 E.00625
G1 X119.105 Y125.739 E.01414
G1 X117.302 Y126.054 E.05911
; Slow Down Start
; LINE_WIDTH: 0.426336
G1 F3000;_EXTRUDE_SET_SPEED
G3 X115.962 Y126.297 I-25.397 J-136.266 E.04257
; Slow Down End
; LINE_WIDTH: 0.41999
G1 F12000
G1 X114.265 Y126.297 E.05212
G1 X127.762 Y125.812 F36000
; LINE_WIDTH: 0.63717
G1 F10601.599
G1 X131.408 Y125.812 E.17656
G1 X120.086 Y125.812 F36000
G1 F10601.599
G1 X123.633 Y125.812 E.17179
G1 X111.382 Y125.812 F36000
; LINE_WIDTH: 0.63718
G1 F10601.421
G1 X113.328 Y125.812 E.09422
; LINE_WIDTH: 0.61419
G1 F11028.06
G1 X113.634 Y125.789 E.01432
; LINE_WIDTH: 0.581644
G1 F11694.301
G3 X114.371 Y125.812 I.306 J2.021 E.03254
; LINE_WIDTH: 0.63718
G1 F10601.421
G1 X115.859 Y125.812 E.07206
G1 X108.852 Y124.896 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.43098
G1 F3000
G1 X106.656 Y124.896 E.06943
G1 X106.244 Y125.038 E.0138
G1 X105.782 Y125.284 E.01653
G1 X109.218 Y125.284 E.10864
G1 X109.461 Y125.449 E.0093
G1 X109.718 Y125.672 E.01075
G1 X105.282 Y125.672 E.14028
G1 X104.934 Y126.06 E.01649
G1 X110.066 Y126.06 E.16229
G1 X110.317 Y126.448 E.01461
G1 X104.683 Y126.448 E.17815
G1 X104.571 Y126.674 E.00798
G1 X104.864 Y126.674 E.00924
G1 X104.979 Y126.836 E.00629
G1 X110.021 Y126.836 E.15941
G1 X109.929 Y126.964 E.00497
G1 X110.017 Y127.224 E.00869
G1 X104.983 Y127.224 E.1592
G1 X104.892 Y127.612 E.0126
G1 X110.108 Y127.612 E.16491
G1 X110.115 Y127.649 E.00121
G1 X110.307 Y127.807 E.00785
G1 X110.707 Y127.807 E.01264
G1 X110.717 Y128 E.00611
G1 X104.283 Y128 E.20344
G1 X104.293 Y128.193 E.00611
G1 X104.693 Y128.193 E.01264
G1 X104.885 Y128.351 E.00785
G1 X104.892 Y128.388 E.00121
G1 X110.108 Y128.388 E.16491
G1 X110.017 Y128.776 E.0126
G1 X104.983 Y128.776 E.1592
G1 X105.071 Y129.036 E.00869
G1 X104.979 Y129.164 E.00498
G1 X110.021 Y129.164 E.15941
G1 X110.136 Y129.326 E.00629
G1 X110.429 Y129.326 E.00924
G1 X110.317 Y129.552 E.00798
G1 X104.683 Y129.552 E.17815
G1 X104.934 Y129.94 E.01461
G1 X110.066 Y129.94 E.16229
G1 X109.718 Y130.328 E.01649
G1 X105.282 Y130.328 E.14027
G1 X105.54 Y130.551 E.01077
G1 X105.782 Y130.716 E.00928
G1 X109.218 Y130.716 E.10865
G1 X108.76 Y130.96 E.01641
G1 X108.344 Y131.104 E.01391
G1 X106.148 Y131.104 E.06945
G1 X105.56 Y131.034 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.45402
G1 F15000
G3 X105.012 Y130.609 I2.765 J-4.132 E.02326
G1 X104.915 Y130.626 E.0033
; LINE_WIDTH: 0.429178
G1 X104.352 Y130.7 E.01789
; LINE_WIDTH: 0.379493
G1 X103.788 Y130.775 E.01559
; LINE_WIDTH: 0.352316
G1 X99.66 Y130.776 E.10407
G1 X99.66 Y131.085 E.0078
G1 X103.815 Y131.084 E.10476
; LINE_WIDTH: 0.379515
G1 X104.383 Y131.059 E.01559
; LINE_WIDTH: 0.441395
G3 X105.5 Y131.034 I.843 J12.768 E.0363
G1 X104.354 Y129.362 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.40473
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X99.672 Y130.188 E.24924
G1 X99.672 Y130.396 E.01092
G1 X101.109 Y130.396 E.07533
G1 X104.36 Y129.823 E.17303
G1 X104.639 Y130.235 E.02611
G1 X102.579 Y130.599 E.10964
G1 X99.469 Y129.762 F36000
G1 F3000
G1 X104.575 Y128.861 E.27175
G3 X104.514 Y128.607 I1.089 J-.394 E.01375
G1 X103.91 Y128.607 E.03166
G1 X103.903 Y128.518 E.00466
G1 X99.672 Y129.264 E.22519
G1 X99.672 Y128.802 E.0242
G1 X103.871 Y128.062 E.22352
G1 X103.893 Y127.596 E.02443
G1 X99.672 Y128.341 E.22465
G1 X99.672 Y127.879 E.0242
M73 P91 R1
G1 X104.259 Y127.07 E.24418
G1 X104.074 Y126.811 E.0167
G1 X104.138 Y126.63 E.01007
G1 X99.672 Y127.417 E.23774
G1 X99.672 Y126.955 E.0242
G1 X104.393 Y126.123 E.25129
G1 X104.604 Y125.811 E.01975
G1 X104.778 Y125.604 E.01418
G1 X99.672 Y126.494 E.2717
G1 X99.672 Y126.032 E.0242
G1 X103.247 Y125.402 E.1903
G1 X105.729 Y124.915 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.352315
; LAYER_HEIGHT: 0.2
G1 F15000
G1 X99.66 Y124.915 E.15301
G1 X99.66 Y125.224 E.0078
G1 X105.28 Y125.224 E.14169
G1 X105.677 Y124.945 E.01224
; CHANGE_LAYER
; Z_HEIGHT: 7.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X105.28 Y125.224 E-.18449
G1 X103.766 Y125.224 E-.57551
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
G1 X160.452 Y134.434
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.452 Y121.566 E.42689
G1 X162.248 Y121.566 E.05957
G1 X162.248 Y134.434 E.42689
G1 X160.512 Y134.434 E.05758
G1 X160.06 Y134.827 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y121.173 E.41952
G1 X162.64 Y121.173 E.07928
G1 X162.64 Y134.827 E.41952
G1 X160.12 Y134.827 E.07743
; WIPE_START
M204 S10000
G1 X160.111 Y132.827 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.709 Y125.218 Z7.6 F36000
G1 X160.8 Y124.049 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X160.8 Y125.903 E.05157
G1 X160.8 Y130.097 E.13909
G1 X161.9 Y131.196 E.05157
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y131.951 E.05401
; WIPE_START
G1 X160.8 Y133.579 E-.61876
G1 X161.063 Y133.317 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.5 Y132.289 Z7.6 F36000
G1 X99.302 Y124.923 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X145.698 Y124.923 E1.53904
G1 X145.698 Y131.077 E.20411
G1 X99.302 Y131.077 E1.53904
G1 X99.302 Y124.983 E.20212
G1 X98.91 Y124.531 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X146.09 Y124.531 E1.44971
G1 X146.09 Y131.469 E.21316
G1 X98.91 Y131.469 E1.44971
G1 X98.91 Y124.591 E.21132
; WIPE_START
M204 S10000
G1 X100.91 Y124.589 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X108.52 Y125.174 Z7.6 F36000
G1 X145.306 Y128 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X145.306 Y125.316 E.08248
G1 X99.694 Y125.316 E1.40149
G1 X99.694 Y130.684 E.16497
G1 X145.306 Y130.684 E1.40149
G1 X145.306 Y128.06 E.08064
G1 X144.929 Y128 F36000
G1 F12000
G1 X144.929 Y125.693 E.0709
G1 X100.071 Y125.693 E1.37831
G1 X100.071 Y130.307 E.1418
G1 X144.929 Y130.307 E1.37831
G1 X144.929 Y128.06 E.06905
G1 X144.552 Y128 F36000
G1 F12000
G1 X144.552 Y126.07 E.05931
G1 X100.448 Y126.07 E1.35514
G1 X100.448 Y129.93 E.11862
G1 X144.552 Y129.93 E1.35514
G1 X144.552 Y128.06 E.05747
G1 X144.175 Y128 F36000
G1 F12000
G1 X144.175 Y126.447 E.04773
G1 X100.825 Y126.447 E1.33197
G1 X100.825 Y129.553 E.09545
G1 X144.175 Y129.553 E1.33197
G1 X144.175 Y128.06 E.04588
G1 X143.798 Y128 F36000
G1 F12000
G1 X143.798 Y126.824 E.03614
G1 X101.202 Y126.824 E1.3088
G1 X101.202 Y129.176 E.07228
G1 X143.798 Y129.176 E1.3088
G1 X143.798 Y128.06 E.0343
G1 X143.421 Y128 F36000
G1 F12000
G1 X143.421 Y127.201 E.02455
G1 X101.579 Y127.201 E1.28563
G1 X101.579 Y128.799 E.04911
G1 X143.421 Y128.799 E1.28563
G1 X143.421 Y128.06 E.02271
G1 X143.043 Y128 F36000
G1 F12000
G1 X143.043 Y127.578 E.01297
G1 X101.957 Y127.578 E1.26245
G1 X101.957 Y128.422 E.02594
G1 X143.043 Y128.422 E1.26245
G1 X143.043 Y128.06 E.01112
G1 X102.379 Y128 F36000
; LINE_WIDTH: 0.50994
G1 F12000
G1 X142.561 Y128 E1.52921
; CHANGE_LAYER
; Z_HEIGHT: 7.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X140.561 Y128 E-.76
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
G1 X160.452 Y134.228
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15306
G1 X160.452 Y121.772 E.41322
G1 X162.248 Y121.772 E.05957
G1 X162.248 Y134.228 E.41322
G1 X160.512 Y134.228 E.05758
G1 X160.06 Y134.621 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y121.379 E.40686
G1 X162.64 Y121.379 E.07928
G1 X162.64 Y134.621 E.40686
G1 X160.12 Y134.621 E.07743
; WIPE_START
M204 S10000
G1 X160.111 Y132.621 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.8 Y131.951 Z7.8 F36000
G1 Z7.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15306
G1 X160.8 Y133.579 E.05401
G1 X161.9 Y132.48 E.05157
G1 X161.9 Y131.196 E.0426
G1 X160.8 Y130.097 E.05157
G1 X160.8 Y125.903 E.13909
G1 X161.9 Y124.804 E.05157
G1 X161.9 Y123.52 E.0426
G1 X160.8 Y122.421 E.05157
G1 X160.8 Y124.049 E.05401
; WIPE_START
G1 F15476.087
G1 X160.8 Y122.421 E-.61876
G1 X161.063 Y122.683 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.438 Y123.011 Z7.8 F36000
G1 X99.302 Y125.34 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15306
G1 X145.698 Y125.34 E1.53904
G1 X145.698 Y130.66 E.1765
G1 X99.302 Y130.66 E1.53904
G1 X99.302 Y125.4 E.17451
G1 X98.91 Y124.948 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X146.09 Y124.948 E1.44971
G1 X146.09 Y131.052 E.18758
G1 X98.91 Y131.052 E1.44971
G1 X98.91 Y125.008 E.18574
; WIPE_START
M204 S10000
G1 X100.91 Y125.005 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X101.962 Y128 Z7.8 F36000
G1 Z7.4
M73 P92 R1
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.43168
G1 F15000
G1 X142.978 Y128 E1.29932
G1 X143.421 Y128 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X143.421 Y127.617 E.01177
G1 X101.579 Y127.617 E1.28563
G1 X101.579 Y128.383 E.02353
G1 X143.421 Y128.383 E1.28563
G1 X143.421 Y128.06 E.00992
G1 X143.798 Y128 F36000
G1 F15000
G1 X143.798 Y127.24 E.02335
G1 X101.202 Y127.24 E1.3088
G1 X101.202 Y128.76 E.0467
G1 X143.798 Y128.76 E1.3088
G1 X143.798 Y128.06 E.02151
G1 X144.175 Y128 F36000
G1 F15000
G1 X144.175 Y126.863 E.03494
G1 X100.825 Y126.863 E1.33197
G1 X100.825 Y129.137 E.06988
G1 X144.175 Y129.137 E1.33197
G1 X144.175 Y128.06 E.03309
G1 X144.552 Y128 F36000
G1 F15000
G1 X144.552 Y126.486 E.04652
G1 X100.448 Y126.486 E1.35514
G1 X100.448 Y129.514 E.09305
G1 X144.552 Y129.514 E1.35514
G1 X144.552 Y128.06 E.04468
G1 X144.929 Y128 F36000
G1 F15000
G1 X144.929 Y126.109 E.05811
G1 X100.071 Y126.109 E1.37831
G1 X100.071 Y129.891 E.11622
G1 X144.929 Y129.891 E1.37831
G1 X144.929 Y128.06 E.05627
G1 X145.306 Y128 F36000
G1 F15000
G1 X145.306 Y125.732 E.0697
G1 X99.694 Y125.732 E1.40149
G1 X99.694 Y130.268 E.13939
G1 X145.306 Y130.268 E1.40149
G1 X145.306 Y128.06 E.06785
; CHANGE_LAYER
; Z_HEIGHT: 7.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X145.306 Y130.06 E-.76
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
G1 X160.452 Y134.007
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F12427
G1 X160.452 Y121.993 E.3985
G1 X162.248 Y121.993 E.05957
G1 X162.248 Y134.007 E.3985
G1 X160.512 Y134.007 E.05758
G1 X160.06 Y134.399 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y121.601 E.39323
G1 X162.64 Y121.601 E.07928
G1 X162.64 Y134.399 E.39323
G1 X160.12 Y134.399 E.07743
; WIPE_START
M204 S10000
G1 X160.111 Y132.399 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.739 Y124.792 Z8 F36000
G1 X160.8 Y124.049 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F12427
G1 X160.8 Y122.421 E.05401
G1 X161.9 Y123.52 E.05157
G1 X161.9 Y124.804 E.0426
G1 X160.8 Y125.903 E.05157
G1 X160.8 Y130.097 E.13909
G1 X161.9 Y131.196 E.05157
G1 X161.9 Y132.48 E.0426
G1 X160.8 Y133.579 E.05157
G1 X160.8 Y131.951 E.05401
; WIPE_START
G1 F15476.087
G1 X160.8 Y133.579 E-.61876
G1 X161.063 Y133.317 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.486 Y132.398 Z8 F36000
G1 X99.302 Y125.83 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F12427
G1 X145.698 Y125.83 E1.53904
G1 X145.698 Y130.17 E.14396
G1 X99.302 Y130.17 E1.53904
G1 X99.302 Y125.89 E.14197
G1 X98.91 Y125.438 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X146.09 Y125.438 E1.44971
G1 X146.09 Y130.562 E.15744
G1 X98.91 Y130.562 E1.44971
G1 X98.91 Y125.498 E.1556
; WIPE_START
M204 S10000
G1 X100.91 Y125.496 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X108.529 Y125.941 Z8 F36000
G1 X143.757 Y128 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50101
G1 F12427
G1 X143.757 Y127.771 E.00855
G1 X101.243 Y127.771 E1.58699
G1 X101.243 Y128.229 E.0171
G1 X143.757 Y128.229 E1.58699
G1 X143.757 Y128.06 E.00631
G1 X144.175 Y128 F36000
; LINE_WIDTH: 0.41999
G1 F12427
G1 X144.175 Y127.353 E.01987
G1 X100.825 Y127.353 E1.33197
G1 X100.825 Y128.647 E.03974
G1 X144.175 Y128.647 E1.33197
G1 X144.175 Y128.06 E.01803
G1 X144.552 Y128 F36000
G1 F12427
G1 X144.552 Y126.976 E.03145
G1 X100.448 Y126.976 E1.35514
G1 X100.448 Y129.024 E.06291
G1 X144.552 Y129.024 E1.35514
G1 X144.552 Y128.06 E.02961
G1 X144.929 Y128 F36000
G1 F12427
G1 X144.929 Y126.599 E.04304
G1 X100.071 Y126.599 E1.37831
G1 X100.071 Y129.401 E.08608
G1 X144.929 Y129.401 E1.37831
G1 X144.929 Y128.06 E.0412
G1 X145.306 Y128 F36000
G1 F12427
G1 X145.306 Y126.222 E.05463
G1 X99.694 Y126.222 E1.40149
G1 X99.694 Y129.778 E.10925
G1 X145.306 Y129.778 E1.40149
G1 X145.306 Y128.06 E.05278
; CHANGE_LAYER
; Z_HEIGHT: 7.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X145.306 Y129.778 E-.65278
G1 X145.024 Y129.778 E-.10722
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
G1 X160.452 Y133.775
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15222
G1 X160.452 Y122.226 E.3831
G1 X162.248 Y122.226 E.05957
G1 X162.248 Y133.775 E.3831
G1 X160.512 Y133.775 E.05758
G1 X160.06 Y134.167 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X160.06 Y121.833 E.37896
G1 X162.64 Y121.833 E.07928
G1 X162.64 Y134.167 E.37896
G1 X160.12 Y134.167 E.07743
; WIPE_START
M204 S10000
G1 X160.11 Y132.167 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.8 Y131.951 Z8.2 F36000
G1 Z7.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15222
G1 X160.8 Y133.426 E.04893
G1 X160.954 Y133.426 E.00508
G1 X161.9 Y132.48 E.04439
G1 X161.9 Y131.196 E.0426
G1 X160.8 Y130.097 E.05157
G1 X160.8 Y125.903 E.13909
G1 X161.9 Y124.804 E.05157
G1 X161.9 Y123.52 E.0426
G1 X160.954 Y122.574 E.04439
G1 X160.8 Y122.574 E.00508
G1 X160.8 Y124.049 E.04893
; WIPE_START
G1 F15476.087
G1 X160.8 Y122.574 E-.56055
G1 X160.954 Y122.574 E-.05822
G1 X161.216 Y122.837 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.609 Y123.452 Z8.2 F36000
G1 X99.302 Y127.842 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15222
G1 X145.698 Y127.842 E1.53904
G1 X145.698 Y128.158 E.01046
G1 X99.302 Y128.158 E1.53904
G1 X99.302 Y127.902 E.00847
; WIPE_START
G1 F15476.087
G1 X101.302 Y127.9 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X98.91 Y126.049 Z8.2 F36000
M73 P93 R1
G1 Z7.8
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X146.09 Y126.049 E1.44971
G1 X146.09 Y129.951 E.11989
G1 X98.91 Y129.951 E1.44971
G1 X98.91 Y126.109 E.11805
; WIPE_START
M204 S10000
G1 X100.91 Y126.107 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X108.541 Y126.25 Z8.2 F36000
G1 X145.883 Y126.952 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Top surface
G1 F12000
M204 S2000
G1 X145.187 Y126.256 E.03023
G1 X144.654 Y126.256
G1 X145.883 Y127.485 E.0534
G1 X145.484 Y127.62
G1 X144.121 Y126.256 E.05925
G1 X143.587 Y126.256
G1 X144.951 Y127.62 E.05925
G1 X144.417 Y127.62
G1 X143.054 Y126.256 E.05925
G1 X142.521 Y126.256
G1 X143.884 Y127.62 E.05925
G1 X143.351 Y127.62
G1 X141.988 Y126.256 E.05925
G1 X141.454 Y126.256
G1 X142.818 Y127.62 E.05925
G1 X142.284 Y127.62
G1 X140.921 Y126.256 E.05925
G1 X140.388 Y126.256
G1 X141.751 Y127.62 E.05925
G1 X141.218 Y127.62
G1 X139.854 Y126.256 E.05925
G1 X139.321 Y126.256
G1 X140.685 Y127.62 E.05925
G1 X140.151 Y127.62
G1 X138.788 Y126.256 E.05925
G1 X138.255 Y126.256
G1 X139.618 Y127.62 E.05925
G1 X139.085 Y127.62
G1 X137.721 Y126.256 E.05925
G1 X137.188 Y126.256
G1 X138.552 Y127.62 E.05925
G1 X138.018 Y127.62
G1 X136.655 Y126.256 E.05925
G1 X136.122 Y126.256
G1 X137.485 Y127.62 E.05925
G1 X136.952 Y127.62
G1 X135.588 Y126.256 E.05925
G1 X135.055 Y126.256
G1 X136.419 Y127.62 E.05925
G1 X135.885 Y127.62
G1 X134.522 Y126.256 E.05925
G1 X133.989 Y126.256
G1 X135.352 Y127.62 E.05925
G1 X134.819 Y127.62
G1 X133.455 Y126.256 E.05925
G1 X132.922 Y126.256
G1 X134.286 Y127.62 E.05925
G1 X133.752 Y127.62
G1 X132.389 Y126.256 E.05925
G1 X131.856 Y126.256
G1 X133.219 Y127.62 E.05925
G1 X132.686 Y127.62
G1 X131.322 Y126.256 E.05925
G1 X130.789 Y126.256
G1 X132.153 Y127.62 E.05925
G1 X131.619 Y127.62
G1 X130.256 Y126.256 E.05925
G1 X129.723 Y126.256
G1 X131.086 Y127.62 E.05925
G1 X130.553 Y127.62
G1 X129.189 Y126.256 E.05925
G1 X128.656 Y126.256
G1 X130.02 Y127.62 E.05925
G1 X129.486 Y127.62
G1 X128.123 Y126.256 E.05925
G1 X127.59 Y126.256
G1 X128.953 Y127.62 E.05925
G1 X128.42 Y127.62
G1 X127.056 Y126.256 E.05925
G1 X126.523 Y126.256
G1 X127.886 Y127.62 E.05925
G1 X127.353 Y127.62
G1 X125.99 Y126.256 E.05925
G1 X125.457 Y126.256
G1 X126.82 Y127.62 E.05925
G1 X126.287 Y127.62
G1 X124.923 Y126.256 E.05925
G1 X124.39 Y126.256
G1 X125.753 Y127.62 E.05925
G1 X125.22 Y127.62
G1 X123.857 Y126.256 E.05925
G1 X123.324 Y126.256
G1 X124.687 Y127.62 E.05925
G1 X124.154 Y127.62
G1 X122.79 Y126.256 E.05925
G1 X122.257 Y126.256
G1 X123.62 Y127.62 E.05925
G1 X123.087 Y127.62
G1 X121.724 Y126.256 E.05925
G1 X121.19 Y126.256
G1 X122.554 Y127.62 E.05925
G1 X122.021 Y127.62
G1 X120.657 Y126.256 E.05925
G1 X120.124 Y126.256
G1 X121.487 Y127.62 E.05925
G1 X120.954 Y127.62
G1 X119.591 Y126.256 E.05925
G1 X119.057 Y126.256
G1 X120.421 Y127.62 E.05925
G1 X119.888 Y127.62
G1 X118.524 Y126.256 E.05925
G1 X117.991 Y126.256
G1 X119.354 Y127.62 E.05925
G1 X118.821 Y127.62
G1 X117.458 Y126.256 E.05925
G1 X116.924 Y126.256
G1 X118.288 Y127.62 E.05925
G1 X117.755 Y127.62
G1 X116.391 Y126.256 E.05925
G1 X115.858 Y126.256
G1 X117.221 Y127.62 E.05925
G1 X116.688 Y127.62
G1 X115.325 Y126.256 E.05925
G1 X114.791 Y126.256
G1 X116.155 Y127.62 E.05925
G1 X115.622 Y127.62
G1 X114.258 Y126.256 E.05925
G1 X113.725 Y126.256
G1 X115.088 Y127.62 E.05925
G1 X114.555 Y127.62
G1 X113.192 Y126.256 E.05925
G1 X112.658 Y126.256
G1 X114.022 Y127.62 E.05925
G1 X113.489 Y127.62
G1 X112.125 Y126.256 E.05925
G1 X111.592 Y126.256
G1 X112.955 Y127.62 E.05925
G1 X112.422 Y127.62
G1 X111.059 Y126.256 E.05925
G1 X110.525 Y126.256
G1 X111.889 Y127.62 E.05925
G1 X111.356 Y127.62
G1 X109.992 Y126.256 E.05925
G1 X109.459 Y126.256
G1 X110.822 Y127.62 E.05925
G1 X110.289 Y127.62
G1 X108.926 Y126.256 E.05925
G1 X108.392 Y126.256
G1 X109.756 Y127.62 E.05925
G1 X109.222 Y127.62
G1 X107.859 Y126.256 E.05925
G1 X107.326 Y126.256
G1 X108.689 Y127.62 E.05925
G1 X108.156 Y127.62
G1 X106.793 Y126.256 E.05925
G1 X106.259 Y126.256
G1 X107.623 Y127.62 E.05925
G1 X107.089 Y127.62
G1 X105.726 Y126.256 E.05925
G1 X105.193 Y126.256
G1 X106.556 Y127.62 E.05925
G1 X106.023 Y127.62
G1 X104.659 Y126.256 E.05925
G1 X104.126 Y126.256
G1 X105.49 Y127.62 E.05925
G1 X104.956 Y127.62
G1 X103.593 Y126.256 E.05925
G1 X103.06 Y126.256
G1 X104.423 Y127.62 E.05925
G1 X103.89 Y127.62
G1 X102.526 Y126.256 E.05925
G1 X101.993 Y126.256
G1 X103.357 Y127.62 E.05925
G1 X102.823 Y127.62
G1 X101.46 Y126.256 E.05925
G1 X100.927 Y126.256
G1 X102.29 Y127.62 E.05925
G1 X101.757 Y127.62
G1 X100.393 Y126.256 E.05925
G1 X99.86 Y126.256
G1 X101.224 Y127.62 E.05925
G1 X100.69 Y127.62
G1 X99.327 Y126.256 E.05925
G1 X99.117 Y126.58
G1 X100.157 Y127.62 E.04518
G1 X99.624 Y127.62
G1 X99.117 Y127.113 E.02201
; WIPE_START
M204 S10000
G1 X99.624 Y127.62 E-.27217
G1 X100.157 Y127.62 E-.20264
G1 X99.626 Y127.089 E-.28519
; WIPE_END
G1 E-.04 F1800
G1 X107.252 Y127.418 Z8.2 F36000
G1 X145.883 Y129.085 Z8.2
G1 Z7.8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X145.178 Y128.38 E.03063
G1 X144.644 Y128.38
G1 X145.883 Y129.618 E.05381
G1 X145.475 Y129.744
G1 X144.111 Y128.38 E.05925
G1 X143.578 Y128.38
G1 X144.941 Y129.744 E.05925
G1 X144.408 Y129.744
G1 X143.045 Y128.38 E.05925
G1 X142.511 Y128.38
G1 X143.875 Y129.744 E.05925
G1 X143.342 Y129.744
G1 X141.978 Y128.38 E.05925
G1 X141.445 Y128.38
G1 X142.808 Y129.744 E.05925
G1 X142.275 Y129.744
G1 X140.912 Y128.38 E.05925
G1 X140.378 Y128.38
G1 X141.742 Y129.744 E.05925
G1 X141.208 Y129.744
G1 X139.845 Y128.38 E.05925
G1 X139.312 Y128.38
G1 X140.675 Y129.744 E.05925
G1 X140.142 Y129.744
G1 X138.779 Y128.38 E.05925
G1 X138.245 Y128.38
G1 X139.609 Y129.744 E.05925
G1 X139.075 Y129.744
G1 X137.712 Y128.38 E.05925
G1 X137.179 Y128.38
G1 X138.542 Y129.744 E.05925
G1 X138.009 Y129.744
G1 X136.646 Y128.38 E.05925
G1 X136.112 Y128.38
G1 X137.476 Y129.744 E.05925
G1 X136.942 Y129.744
G1 X135.579 Y128.38 E.05925
G1 X135.046 Y128.38
G1 X136.409 Y129.744 E.05925
G1 X135.876 Y129.744
G1 X134.512 Y128.38 E.05925
G1 X133.979 Y128.38
G1 X135.343 Y129.744 E.05925
G1 X134.809 Y129.744
G1 X133.446 Y128.38 E.05925
G1 X132.913 Y128.38
G1 X134.276 Y129.744 E.05925
G1 X133.743 Y129.744
G1 X132.379 Y128.38 E.05925
G1 X131.846 Y128.38
G1 X133.21 Y129.744 E.05925
G1 X132.676 Y129.744
G1 X131.313 Y128.38 E.05925
G1 X130.78 Y128.38
G1 X132.143 Y129.744 E.05925
G1 X131.61 Y129.744
G1 X130.246 Y128.38 E.05925
G1 X129.713 Y128.38
G1 X131.077 Y129.744 E.05925
G1 X130.543 Y129.744
M73 P94 R1
G1 X129.18 Y128.38 E.05925
G1 X128.647 Y128.38
G1 X130.01 Y129.744 E.05925
G1 X129.477 Y129.744
G1 X128.113 Y128.38 E.05925
G1 X127.58 Y128.38
G1 X128.944 Y129.744 E.05925
G1 X128.41 Y129.744
G1 X127.047 Y128.38 E.05925
G1 X126.514 Y128.38
G1 X127.877 Y129.744 E.05925
G1 X127.344 Y129.744
G1 X125.98 Y128.38 E.05925
G1 X125.447 Y128.38
G1 X126.811 Y129.744 E.05925
G1 X126.277 Y129.744
G1 X124.914 Y128.38 E.05925
G1 X124.381 Y128.38
G1 X125.744 Y129.744 E.05925
G1 X125.211 Y129.744
G1 X123.847 Y128.38 E.05925
G1 X123.314 Y128.38
G1 X124.678 Y129.744 E.05925
G1 X124.144 Y129.744
G1 X122.781 Y128.38 E.05925
G1 X122.248 Y128.38
G1 X123.611 Y129.744 E.05925
G1 X123.078 Y129.744
G1 X121.714 Y128.38 E.05925
G1 X121.181 Y128.38
G1 X122.544 Y129.744 E.05925
G1 X122.011 Y129.744
G1 X120.648 Y128.38 E.05925
G1 X120.115 Y128.38
G1 X121.478 Y129.744 E.05925
G1 X120.945 Y129.744
G1 X119.581 Y128.38 E.05925
G1 X119.048 Y128.38
G1 X120.411 Y129.744 E.05925
G1 X119.878 Y129.744
G1 X118.515 Y128.38 E.05925
G1 X117.982 Y128.38
G1 X119.345 Y129.744 E.05925
G1 X118.812 Y129.744
G1 X117.448 Y128.38 E.05925
G1 X116.915 Y128.38
G1 X118.278 Y129.744 E.05925
G1 X117.745 Y129.744
G1 X116.382 Y128.38 E.05925
G1 X115.848 Y128.38
G1 X117.212 Y129.744 E.05925
G1 X116.679 Y129.744
G1 X115.315 Y128.38 E.05925
G1 X114.782 Y128.38
G1 X116.145 Y129.744 E.05925
G1 X115.612 Y129.744
G1 X114.249 Y128.38 E.05925
G1 X113.715 Y128.38
G1 X115.079 Y129.744 E.05925
G1 X114.546 Y129.744
G1 X113.182 Y128.38 E.05925
G1 X112.649 Y128.38
G1 X114.012 Y129.744 E.05925
G1 X113.479 Y129.744
G1 X112.116 Y128.38 E.05925
G1 X111.582 Y128.38
G1 X112.946 Y129.744 E.05925
G1 X112.413 Y129.744
G1 X111.049 Y128.38 E.05925
G1 X110.516 Y128.38
G1 X111.879 Y129.744 E.05925
G1 X111.346 Y129.744
G1 X109.983 Y128.38 E.05925
G1 X109.449 Y128.38
G1 X110.813 Y129.744 E.05925
G1 X110.28 Y129.744
G1 X108.916 Y128.38 E.05925
G1 X108.383 Y128.38
G1 X109.746 Y129.744 E.05925
G1 X109.213 Y129.744
G1 X107.85 Y128.38 E.05925
G1 X107.316 Y128.38
G1 X108.68 Y129.744 E.05925
G1 X108.147 Y129.744
G1 X106.783 Y128.38 E.05925
G1 X106.25 Y128.38
G1 X107.613 Y129.744 E.05925
G1 X107.08 Y129.744
G1 X105.717 Y128.38 E.05925
G1 X105.183 Y128.38
G1 X106.547 Y129.744 E.05925
G1 X106.014 Y129.744
G1 X104.65 Y128.38 E.05925
G1 X104.117 Y128.38
G1 X105.48 Y129.744 E.05925
G1 X104.947 Y129.744
G1 X103.584 Y128.38 E.05925
G1 X103.05 Y128.38
G1 X104.414 Y129.744 E.05925
G1 X103.88 Y129.744
G1 X102.517 Y128.38 E.05925
G1 X101.984 Y128.38
G1 X103.347 Y129.744 E.05925
G1 X102.814 Y129.744
G1 X101.451 Y128.38 E.05925
G1 X100.917 Y128.38
M73 P94 R0
G1 X102.281 Y129.744 E.05925
G1 X101.747 Y129.744
G1 X100.384 Y128.38 E.05925
G1 X99.851 Y128.38
G1 X101.214 Y129.744 E.05925
G1 X100.681 Y129.744
G1 X99.318 Y128.38 E.05925
G1 X99.117 Y128.713
G1 X100.148 Y129.744 E.04477
G1 X99.614 Y129.744
G1 X99.117 Y129.246 E.0216
; CHANGE_LAYER
; Z_HEIGHT: 8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
M204 S10000
G1 X99.614 Y129.744 E-.26711
G1 X100.148 Y129.744 E-.20264
G1 X99.608 Y129.203 E-.29025
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
G1 X160.452 Y133.522
G1 Z8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F7326
G1 X160.452 Y122.478 E.36637
G1 X162.248 Y122.478 E.05957
G1 X162.248 Y133.522 E.36637
G1 X160.512 Y133.522 E.05758
G1 X160.06 Y133.914 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F7326
M204 S6000
G1 X160.06 Y122.086 E.36346
G1 X162.64 Y122.086 E.07928
G1 X162.64 Y133.914 E.36346
G1 X160.12 Y133.914 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X160.11 Y131.914 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.777 Y124.311 Z8.4 F36000
G1 X160.8 Y124.049 Z8.4
G1 Z8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F7326
G1 X160.8 Y122.826 E.04057
G1 X161.206 Y122.826 E.01345
G1 X161.9 Y123.52 E.03255
G1 X161.9 Y124.804 E.0426
G1 X160.8 Y125.903 E.05157
G1 X160.8 Y130.097 E.13909
G1 X161.9 Y131.196 E.05157
G1 X161.9 Y132.48 E.0426
G1 X161.206 Y133.174 E.03255
G1 X160.8 Y133.174 E.01345
G1 X160.8 Y131.951 E.04057
; WIPE_START
G1 F15476.087
G1 X160.8 Y133.174 E-.46471
G1 X161.206 Y133.174 E-.15405
G1 X161.469 Y132.911 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X153.87 Y132.19 Z8.4 F36000
G1 X98.91 Y126.975 Z8.4
G1 Z8
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F7326
M204 S6000
G1 X146.09 Y126.975 E1.44971
G1 X146.09 Y129.025 E.06301
G1 X98.91 Y129.025 E1.44971
G1 X98.91 Y127.035 E.06117
; WIPE_START
G1 F12000
M204 S10000
G1 X100.91 Y127.032 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X108.541 Y127.193 Z8.4 F36000
G1 X145.883 Y127.981 Z8.4
G1 Z8
G1 E.8 F1800
; FEATURE: Top surface
G1 F7326
M204 S2000
G1 X145.046 Y128.818 E.03635
G1 X144.513 Y128.818
G1 X145.883 Y127.448 E.05953
G1 X145.616 Y127.182
G1 X143.98 Y128.818 E.07109
G1 X143.446 Y128.818
G1 X145.082 Y127.182 E.07109
G1 X144.549 Y127.182
G1 X142.913 Y128.818 E.07109
G1 X142.38 Y128.818
G1 X144.016 Y127.182 E.07109
G1 X143.482 Y127.182
G1 X141.847 Y128.818 E.07109
G1 X141.313 Y128.818
G1 X142.949 Y127.182 E.07109
G1 X142.416 Y127.182
G1 X140.78 Y128.818 E.07109
G1 X140.247 Y128.818
G1 X141.883 Y127.182 E.07109
G1 X141.349 Y127.182
G1 X139.713 Y128.818 E.07109
G1 X139.18 Y128.818
G1 X140.816 Y127.182 E.07109
G1 X140.283 Y127.182
G1 X138.647 Y128.818 E.07109
G1 X138.114 Y128.818
G1 X139.75 Y127.182 E.07109
G1 X139.216 Y127.182
G1 X137.58 Y128.818 E.07109
G1 X137.047 Y128.818
G1 X138.683 Y127.182 E.07109
G1 X138.15 Y127.182
G1 X136.514 Y128.818 E.07109
G1 X135.981 Y128.818
G1 X137.617 Y127.182 E.07109
G1 X137.083 Y127.182
G1 X135.447 Y128.818 E.07109
G1 X134.914 Y128.818
G1 X136.55 Y127.182 E.07109
G1 X136.017 Y127.182
G1 X134.381 Y128.818 E.07109
G1 X133.848 Y128.818
G1 X135.484 Y127.182 E.07109
G1 X134.95 Y127.182
G1 X133.314 Y128.818 E.07109
G1 X132.781 Y128.818
G1 X134.417 Y127.182 E.07109
G1 X133.884 Y127.182
G1 X132.248 Y128.818 E.07109
G1 X131.715 Y128.818
G1 X133.351 Y127.182 E.07109
G1 X132.817 Y127.182
G1 X131.181 Y128.818 E.07109
G1 X130.648 Y128.818
G1 X132.284 Y127.182 E.07109
G1 X131.751 Y127.182
G1 X130.115 Y128.818 E.07109
G1 X129.582 Y128.818
G1 X131.218 Y127.182 E.07109
G1 X130.684 Y127.182
G1 X129.048 Y128.818 E.07109
G1 X128.515 Y128.818
G1 X130.151 Y127.182 E.07109
G1 X129.618 Y127.182
G1 X127.982 Y128.818 E.07109
G1 X127.449 Y128.818
G1 X129.085 Y127.182 E.07109
G1 X128.551 Y127.182
G1 X126.915 Y128.818 E.07109
G1 X126.382 Y128.818
G1 X128.018 Y127.182 E.07109
G1 X127.485 Y127.182
G1 X125.849 Y128.818 E.07109
G1 X125.316 Y128.818
G1 X126.951 Y127.182 E.07109
G1 X126.418 Y127.182
M73 P95 R0
G1 X124.782 Y128.818 E.07109
G1 X124.249 Y128.818
G1 X125.885 Y127.182 E.07109
G1 X125.352 Y127.182
G1 X123.716 Y128.818 E.07109
G1 X123.183 Y128.818
G1 X124.818 Y127.182 E.07109
G1 X124.285 Y127.182
G1 X122.649 Y128.818 E.07109
G1 X122.116 Y128.818
G1 X123.752 Y127.182 E.07109
G1 X123.219 Y127.182
G1 X121.583 Y128.818 E.07109
G1 X121.049 Y128.818
G1 X122.685 Y127.182 E.07109
G1 X122.152 Y127.182
G1 X120.516 Y128.818 E.07109
G1 X119.983 Y128.818
G1 X121.619 Y127.182 E.07109
G1 X121.086 Y127.182
G1 X119.45 Y128.818 E.07109
G1 X118.916 Y128.818
G1 X120.552 Y127.182 E.07109
G1 X120.019 Y127.182
G1 X118.383 Y128.818 E.07109
G1 X117.85 Y128.818
G1 X119.486 Y127.182 E.07109
G1 X118.953 Y127.182
G1 X117.317 Y128.818 E.07109
G1 X116.783 Y128.818
G1 X118.419 Y127.182 E.07109
G1 X117.886 Y127.182
G1 X116.25 Y128.818 E.07109
G1 X115.717 Y128.818
G1 X117.353 Y127.182 E.07109
G1 X116.82 Y127.182
G1 X115.184 Y128.818 E.07109
G1 X114.65 Y128.818
G1 X116.286 Y127.182 E.07109
G1 X115.753 Y127.182
G1 X114.117 Y128.818 E.07109
G1 X113.584 Y128.818
G1 X115.22 Y127.182 E.07109
G1 X114.687 Y127.182
G1 X113.051 Y128.818 E.07109
G1 X112.517 Y128.818
G1 X114.153 Y127.182 E.07109
G1 X113.62 Y127.182
G1 X111.984 Y128.818 E.07109
G1 X111.451 Y128.818
G1 X113.087 Y127.182 E.07109
G1 X112.554 Y127.182
G1 X110.918 Y128.818 E.07109
G1 X110.384 Y128.818
G1 X112.02 Y127.182 E.07109
G1 X111.487 Y127.182
G1 X109.851 Y128.818 E.07109
G1 X109.318 Y128.818
G1 X110.954 Y127.182 E.07109
G1 X110.421 Y127.182
G1 X108.785 Y128.818 E.07109
G1 X108.251 Y128.818
G1 X109.887 Y127.182 E.07109
G1 X109.354 Y127.182
G1 X107.718 Y128.818 E.07109
G1 X107.185 Y128.818
G1 X108.821 Y127.182 E.07109
G1 X108.287 Y127.182
G1 X106.652 Y128.818 E.07109
G1 X106.118 Y128.818
G1 X107.754 Y127.182 E.07109
G1 X107.221 Y127.182
G1 X105.585 Y128.818 E.07109
G1 X105.052 Y128.818
G1 X106.688 Y127.182 E.07109
G1 X106.154 Y127.182
G1 X104.518 Y128.818 E.07109
G1 X103.985 Y128.818
G1 X105.621 Y127.182 E.07109
G1 X105.088 Y127.182
G1 X103.452 Y128.818 E.07109
G1 X102.919 Y128.818
G1 X104.555 Y127.182 E.07109
G1 X104.021 Y127.182
G1 X102.385 Y128.818 E.07109
G1 X101.852 Y128.818
G1 X103.488 Y127.182 E.07109
G1 X102.955 Y127.182
G1 X101.319 Y128.818 E.07109
G1 X100.786 Y128.818
G1 X102.422 Y127.182 E.07109
G1 X101.888 Y127.182
G1 X100.252 Y128.818 E.07109
G1 X99.719 Y128.818
G1 X101.355 Y127.182 E.07109
G1 X100.822 Y127.182
G1 X99.186 Y128.818 E.07109
G1 X99.117 Y128.353
G1 X100.289 Y127.182 E.0509
G1 X99.755 Y127.182
G1 X99.117 Y127.82 E.02772
; CHANGE_LAYER
; Z_HEIGHT: 8.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
M204 S10000
G1 X99.755 Y127.182 E-.34285
G1 X100.289 Y127.182 E-.20264
G1 X99.889 Y127.581 E-.21451
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
G1 X160.452 Y133.26
G1 Z8.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1200
G1 X160.452 Y122.74 E.34899
G1 X162.248 Y122.74 E.05957
G1 X162.248 Y133.26 E.34899
G1 X160.512 Y133.26 E.05758
G1 X160.06 Y133.652 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1200
M204 S6000
G1 X160.06 Y122.348 E.34736
G1 X162.64 Y122.348 E.07928
G1 X162.64 Y133.652 E.34736
G1 X160.12 Y133.652 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X160.109 Y131.652 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.8 Y131.951 Z8.6 F36000
G1 Z8.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F1200
G1 X160.8 Y132.912 E.03188
G1 X161.468 Y132.912 E.02214
G1 X161.9 Y132.48 E.02027
G1 X161.9 Y131.196 E.0426
G1 X160.8 Y130.097 E.05157
G1 X160.8 Y125.903 E.13909
G1 X161.9 Y124.804 E.05157
G1 X161.9 Y123.52 E.0426
G1 X161.468 Y123.088 E.02026
G1 X160.8 Y123.088 E.02214
G1 X160.8 Y124.049 E.03188
; CHANGE_LAYER
; Z_HEIGHT: 8.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X160.8 Y123.088 E-.36515
G1 X161.468 Y123.088 E-.25361
G1 X161.731 Y123.351 E-.14124
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
G1 X160.452 Y132.968
G1 Z8.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F1384
G1 X160.452 Y123.032 E.32958
G1 X162.248 Y123.032 E.05957
G1 X162.248 Y132.968 E.32958
G1 X160.512 Y132.968 E.05758
G1 X160.06 Y133.36 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1384
M204 S6000
G1 X160.06 Y122.64 E.32938
G1 X162.64 Y122.64 E.07928
G1 X162.64 Y133.36 E.32938
G1 X160.12 Y133.36 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X160.109 Y131.36 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.856 Y123.93 Z8.8 F36000
M73 P96 R0
G1 Z8.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F1384
G1 X161.856 Y123.424 E.01554
G1 X160.844 Y123.424 E.03109
G1 X160.844 Y132.576 E.28119
G1 X161.856 Y132.576 E.03109
G1 X161.856 Y123.99 E.2638
G1 X161.509 Y123.93 F36000
; LINE_WIDTH: 0.36025
G1 F1384
G1 X161.509 Y123.772 E.0041
G1 X161.191 Y123.772 E.00821
G1 X161.191 Y132.228 E.21868
G1 X161.509 Y132.228 E.00821
G1 X161.509 Y123.99 E.21303
; CHANGE_LAYER
; Z_HEIGHT: 8.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F12000
G1 X161.509 Y125.99 E-.76
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
G1 X160.452 Y132.662
G1 Z8.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1304
G1 X160.452 Y123.338 E.30927
G1 X162.248 Y123.338 E.05957
G1 X162.248 Y132.662 E.30927
G1 X160.512 Y132.662 E.05758
G1 X160.06 Y133.054 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1304
M204 S6000
G1 X160.06 Y122.946 E.31057
G1 X162.64 Y122.946 E.07928
G1 X162.64 Y133.054 E.31057
G1 X160.12 Y133.054 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X160.108 Y131.054 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.844 Y123.73 Z9 F36000
G1 Z8.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1304
G1 X160.844 Y132.27 E.26238
G1 X161.856 Y132.27 E.03109
G1 X161.856 Y123.73 E.26238
G1 X160.904 Y123.73 E.02924
G1 X161.191 Y124.078 F36000
; LINE_WIDTH: 0.36025
G1 F1304
G1 X161.191 Y131.922 E.20285
G1 X161.509 Y131.922 E.00821
G1 X161.509 Y124.078 E.20285
G1 X161.251 Y124.078 E.00665
; CHANGE_LAYER
; Z_HEIGHT: 8.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X161.509 Y124.078 E-.09779
G1 X161.509 Y125.82 E-.66221
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
G1 X160.452 Y132.323
G1 Z8.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1219
G1 X160.452 Y123.677 E.2868
G1 X162.248 Y123.677 E.05957
G1 X162.248 Y132.323 E.2868
G1 X160.512 Y132.323 E.05758
G1 X160.06 Y132.715 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1219
M204 S6000
G1 X160.06 Y123.285 E.28976
G1 X162.64 Y123.285 E.07928
G1 X162.64 Y132.715 E.28976
G1 X160.12 Y132.715 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X160.107 Y130.715 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.844 Y124.069 Z9.2 F36000
G1 Z8.8
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1219
G1 X160.844 Y131.931 E.24157
G1 X161.856 Y131.931 E.03109
G1 X161.856 Y124.069 E.24157
G1 X160.904 Y124.069 E.02924
G1 X161.191 Y124.416 F36000
; LINE_WIDTH: 0.36025
G1 F1219
G1 X161.191 Y131.584 E.18534
G1 X161.509 Y131.584 E.00821
G1 X161.509 Y124.416 E.18534
G1 X161.251 Y124.416 E.00665
; CHANGE_LAYER
; Z_HEIGHT: 9
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X161.509 Y124.416 E-.09779
G1 X161.509 Y126.159 E-.66221
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
G1 X160.452 Y131.948
G1 Z9
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1200
G1 X160.452 Y124.052 E.26192
G1 X162.248 Y124.052 E.05957
G1 X162.248 Y131.948 E.26192
M73 P97 R0
G1 X160.512 Y131.948 E.05758
G1 X160.06 Y132.34 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1200
M204 S6000
G1 X160.06 Y123.66 E.26671
G1 X162.64 Y123.66 E.07928
G1 X162.64 Y132.34 E.26671
G1 X160.12 Y132.34 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X160.106 Y130.34 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.844 Y124.444 Z9.4 F36000
G1 Z9
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1200
G1 X160.844 Y131.556 E.21852
G1 X161.856 Y131.556 E.03109
G1 X161.856 Y124.444 E.21852
G1 X160.904 Y124.444 E.02924
G1 X161.191 Y124.791 F36000
; LINE_WIDTH: 0.36025
G1 F1200
G1 X161.191 Y131.209 E.16594
G1 X161.509 Y131.209 E.00821
G1 X161.509 Y124.791 E.16594
G1 X161.251 Y124.791 E.00665
; CHANGE_LAYER
; Z_HEIGHT: 9.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X161.509 Y124.791 E-.09779
G1 X161.509 Y126.534 E-.66221
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
G1 X160.452 Y131.535
G1 Z9.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1200
G1 X160.452 Y124.465 E.23453
G1 X162.248 Y124.465 E.05957
G1 X162.248 Y131.535 E.23453
G1 X160.512 Y131.535 E.05758
G1 X160.06 Y131.927 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1200
M204 S6000
G1 X160.06 Y124.073 E.24134
G1 X162.64 Y124.073 E.07928
G1 X162.64 Y131.927 E.24134
G1 X160.12 Y131.927 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X160.105 Y129.927 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.844 Y124.857 Z9.6 F36000
M73 P98 R0
G1 Z9.2
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1200
G1 X160.844 Y131.143 E.19315
G1 X161.856 Y131.143 E.03109
G1 X161.856 Y124.857 E.19315
G1 X160.904 Y124.857 E.02924
G1 X161.191 Y125.204 F36000
; LINE_WIDTH: 0.36025
G1 F1200
G1 X161.191 Y130.796 E.14459
G1 X161.509 Y130.796 E.00821
G1 X161.509 Y125.204 E.14459
G1 X161.251 Y125.204 E.00665
; CHANGE_LAYER
; Z_HEIGHT: 9.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X161.509 Y125.204 E-.09779
G1 X161.509 Y126.947 E-.66221
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
G1 X160.452 Y131.067
G1 Z9.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1200
G1 X160.452 Y124.933 E.20348
G1 X162.248 Y124.933 E.05957
G1 X162.248 Y131.067 E.20348
G1 X160.512 Y131.067 E.05758
G1 X160.06 Y131.459 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1200
M204 S6000
G1 X160.06 Y124.541 E.21258
G1 X162.64 Y124.541 E.07928
G1 X162.64 Y131.459 E.21258
G1 X160.12 Y131.459 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X160.103 Y129.459 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.844 Y125.325 Z9.8 F36000
G1 Z9.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1200
G1 X160.844 Y130.675 E.16439
G1 X161.856 Y130.675 E.03109
G1 X161.856 Y125.325 E.16439
G1 X160.904 Y125.325 E.02924
G1 X161.191 Y125.672 F36000
; LINE_WIDTH: 0.36025
G1 F1200
G1 X161.191 Y130.328 E.12039
G1 X161.509 Y130.328 E.00821
G1 X161.509 Y125.672 E.12039
G1 X161.251 Y125.672 E.00665
; CHANGE_LAYER
; Z_HEIGHT: 9.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X161.509 Y125.672 E-.09779
G1 X161.509 Y127.415 E-.66221
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
G1 X160.452 Y129.336
G1 Z9.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1200
G1 X160.452 Y126.664 E.08864
G1 X162.248 Y126.664 E.05957
G1 X162.248 Y129.336 E.08864
G1 X160.512 Y129.336 E.05758
; WIPE_START
G1 F15476.087
G1 X160.467 Y127.337 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.06 Y130.905 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1200
M204 S6000
G1 X160.06 Y125.095 E.17853
G1 X162.64 Y125.095 E.07928
G1 X162.64 Y130.905 E.17853
G1 X160.12 Y130.905 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X160.099 Y128.905 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X162.433 Y130.095 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; FEATURE: Top surface
G1 F1200
M204 S2000
G1 X161.83 Y130.698 E.02617
G1 X161.297 Y130.698
G1 X162.433 Y129.562 E.04935
G1 X161.903 Y129.559
G1 X160.764 Y130.698 E.0495
G1 X160.267 Y130.661
G1 X161.37 Y129.559 E.0479
G1 X160.836 Y129.559
G1 X160.267 Y130.128 E.02473
; WIPE_START
G1 F12000
M204 S10000
G1 X160.836 Y129.559 E-.30581
G1 X161.37 Y129.559 E-.20264
G1 X160.902 Y130.027 E-.25155
; WIPE_END
G1 E-.04 F1800
G1 X160.844 Y127.056 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1200
G1 X160.844 Y128.944 E.05801
G1 X161.856 Y128.944 E.03109
G1 X161.856 Y127.056 E.05801
G1 X160.904 Y127.056 E.02924
G1 X161.191 Y127.403 F36000
; LINE_WIDTH: 0.36025
G1 F1200
G1 X161.191 Y128.597 E.03087
G1 X161.509 Y128.597 E.00821
G1 X161.509 Y127.403 E.03087
G1 X161.251 Y127.403 E.00665
; WIPE_START
G1 F15000
G1 X161.509 Y127.403 E-.09779
G1 X161.509 Y128.597 E-.4536
G1 X161.191 Y128.597 E-.12059
G1 X161.191 Y128.365 E-.08802
; WIPE_END
G1 E-.04 F1800
G1 X162.433 Y125.829 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F1200
M204 S2000
G1 X161.821 Y126.441 E.0266
G1 X161.287 Y126.441
G1 X162.427 Y125.302 E.0495
G1 X161.893 Y125.302
G1 X160.754 Y126.441 E.0495
G1 X160.267 Y126.395
G1 X161.36 Y125.302 E.04748
G1 X160.827 Y125.302
G1 X160.267 Y125.862 E.02431
; CHANGE_LAYER
; Z_HEIGHT: 9.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
M204 S10000
G1 X160.827 Y125.302 E-.30059
G1 X161.36 Y125.302 E-.20264
G1 X160.882 Y125.78 E-.25677
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
G1 X160.452 Y128.318
G1 Z9.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1200
G1 X160.452 Y127.682 E.02111
G1 X162.248 Y127.682 E.05957
G1 X162.248 Y128.318 E.02111
G1 X160.512 Y128.318 E.05758
; WIPE_START
G1 F15476.087
G1 X160.452 Y127.682 E-.24284
G1 X161.813 Y127.682 E-.51716
; WIPE_END
G1 E-.04 F1800
G1 X160.06 Y130.204 Z10.2 F36000
G1 Z9.8
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1200
M204 S6000
G1 X160.06 Y125.796 E.13544
G1 X162.64 Y125.796 E.07928
G1 X162.64 Y130.204 E.13544
G1 X160.12 Y130.204 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X160.093 Y128.204 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X160.656 Y128 Z10.2 F36000
G1 Z9.8
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.2721
G1 F1200
G1 X162.044 Y128 E.02594
; WIPE_START
G1 F15000
G1 X160.656 Y128 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X162.433 Y129.104 Z10.2 F36000
G1 Z9.8
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F1200
M204 S2000
G1 X161.869 Y128.541 E.02449
G1 X161.336 Y128.541
G1 X162.433 Y129.637 E.04766
G1 X162.259 Y129.996
G1 X160.803 Y128.541 E.06326
G1 X160.269 Y128.541
G1 X161.725 Y129.996 E.06326
G1 X161.192 Y129.997
G1 X160.267 Y129.072 E.04018
G1 X160.267 Y129.605
M73 P99 R0
G1 X160.659 Y129.997 E.01701
; WIPE_START
G1 F12000
M204 S10000
G1 X160.267 Y129.605 E-.21031
G1 X160.267 Y129.072 E-.20264
G1 X160.913 Y129.718 E-.34705
; WIPE_END
G1 E-.04 F1800
G1 X161.998 Y126.004 Z10.2 F36000
G1 Z9.8
G1 E.8 F1800
G1 F1200
M204 S2000
G1 X162.433 Y126.438 E.01887
G1 X162.433 Y126.971
G1 X161.465 Y126.004 E.04205
G1 X160.932 Y126.004
G1 X162.388 Y127.459 E.06327
G1 X161.854 Y127.459
G1 X160.399 Y126.004 E.06327
G1 X160.267 Y126.406
G1 X161.321 Y127.459 E.04579
G1 X160.788 Y127.459
G1 X160.267 Y126.939 E.02262
; CHANGE_LAYER
; Z_HEIGHT: 10
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
M204 S10000
G1 X160.788 Y127.459 E-.27973
G1 X161.321 Y127.459 E-.20264
G1 X160.805 Y126.943 E-.27763
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
G1 X160.06 Y129.186
G1 Z10
G1 E.8 F1800
; FEATURE: Outer wall
G1 F1200
M204 S6000
G1 X160.06 Y126.814 E.07288
G1 X162.64 Y126.814 E.07928
G1 X162.64 Y129.186 E.07288
G1 X160.12 Y129.186 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X160.069 Y127.187 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X161.95 Y128.979 Z10.4 F36000
G1 Z10
G1 E.8 F1800
; FEATURE: Top surface
G1 F1200
M204 S2000
G1 X162.433 Y128.496 E.02098
G1 X162.433 Y127.962
G1 X161.417 Y128.979 E.04416
G1 X160.883 Y128.979
G1 X162.433 Y127.429 E.06733
G1 X162.307 Y127.021
G1 X160.35 Y128.979 E.08504
G1 X160.267 Y128.528
G1 X161.774 Y127.021 E.06546
G1 X161.241 Y127.021
G1 X160.267 Y127.995 E.04229
G1 X160.267 Y127.461
G1 X160.707 Y127.021 E.01911
; close powerlost recovery
M1003 S0
; WIPE_START
G1 F12000
M204 S10000
G1 X160.267 Y127.461 E-.23639
G1 X160.267 Y127.995 E-.20264
G1 X160.865 Y127.397 E-.32097
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
G0 Z10.8 F900

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

    
        G1 Z85 F600
        G1 Z83
    

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

