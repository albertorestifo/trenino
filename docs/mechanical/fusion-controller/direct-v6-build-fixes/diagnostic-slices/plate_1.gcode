; HEADER_BLOCK_START
; BambuStudio 02.04.00.70
; model printing time: 10m 32s; total estimated time: 18m 28s
; total layer number: 50
; total filament length [mm] : 1566.79
; total filament volume [cm^3] : 3768.57
; total filament weight [g] : 4.75
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
    
      G29 A1 X94.8682 Y94.8682 I66.2559 J66.2559
    
    M400
    M500 ; save cali data
  M623
    
  M622 J2
    M1002 gcode_claim_action : 1
    
      G29 A2 X94.8682 Y94.8682 I66.2559 J66.2559
    
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
G1 X134.229 Y127.36
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.5
G1 F3000
M204 S500
G1 X127.36 Y134.229 E.36182
G1 X123.885 Y130.754 E.18303
G1 X129.794 Y124.845 E.31127
G1 X130.754 Y123.885 E.05055
G1 X134.186 Y127.317 E.1808
M204 S6000
G1 X133.582 Y127.36 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X127.36 Y133.582 E.32777
M73 P43 R10
G1 X124.531 Y130.754 E.14899
G1 X130.118 Y125.168 E.29424
G1 X130.754 Y124.531 E.03352
G1 X133.54 Y127.317 E.14675
; WIPE_START
G1 X132.135 Y128.741 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X124.57 Y127.73 Z.6 F36000
G1 X120.289 Y127.158 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X116.814 Y123.683 E.18303
G1 X122.745 Y117.751 E.31243
G1 X123.683 Y116.814 E.04938
G1 X127.158 Y120.289 E.18303
G1 X120.331 Y127.115 E.35958
M204 S6000
G1 X120.289 Y126.511 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X117.46 Y123.683 E.14898
G1 X123.069 Y118.075 E.29541
G1 X123.683 Y117.46 E.03236
G1 X126.511 Y120.289 E.14898
G1 X120.331 Y126.469 E.32553
; WIPE_START
G1 X118.896 Y125.076 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X116.131 Y117.962 Z.6 F36000
G1 X114.016 Y112.521 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X114.332 Y112.423 E.01232
G3 X114.7 Y112.365 I.582 J2.49 E.01389
G1 X115.056 Y112.36 E.0133
G3 X113.959 Y112.541 I-.143 J2.553 E.55662
M204 S6000
G1 X114.104 Y112.98 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X114.155 Y112.956 E.00209
G3 X114.739 Y112.821 I.759 J1.957 E.0224
G1 X115.032 Y112.817 E.01091
G3 X113.89 Y113.081 I-.117 J2.096 E.44701
G1 X114.05 Y113.006 E.00657
; WIPE_START
G1 X114.155 Y112.956 E-.04408
G1 X114.435 Y112.869 E-.11166
G1 X114.739 Y112.821 E-.11667
G1 X115.032 Y112.817 E-.11134
G1 X115.309 Y112.851 E-.10633
G1 X115.605 Y112.931 E-.11639
G1 X115.875 Y113.046 E-.11139
G1 X115.97 Y113.103 E-.04215
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X120.64 Y119.14 Z.6 F36000
G1 X133.584 Y135.87 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X133.633 Y135.558 E.01176
G3 X135.913 Y133.578 I2.493 J.567 E.1203
G1 X136.27 Y133.573 E.0133
G3 X133.577 Y135.93 I-.143 J2.553 E.45073
M204 S6000
G1 X134.041 Y135.907 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X134.08 Y135.661 E.00927
G3 X135.952 Y134.035 I2.047 J.465 E.09881
G1 X136.245 Y134.03 E.01092
G3 X134.034 Y135.967 I-.118 J2.096 E.37003
; WIPE_START
G1 X134.08 Y135.661 E-.11735
G1 X134.169 Y135.369 E-.11601
G1 X134.287 Y135.116 E-.10642
G1 X134.446 Y134.87 E-.11104
G1 X134.637 Y134.648 E-.11138
G1 X134.858 Y134.454 E-.11167
G1 X135.048 Y134.331 E-.08613
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X129.193 Y129.435 Z.6 F36000
G1 X98.217 Y103.53 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F3000
M204 S500
G1 X101.268 Y106.581 E.16068
G1 X102.121 Y105.727 E.04495
G1 X102.651 Y106.258 E.02793
G1 X103.599 Y105.31 E.04994
G1 X106.258 Y102.651 E.14003
G1 X105.727 Y102.121 E.02793
G1 X106.581 Y101.268 E.04495
G1 X103.53 Y98.217 E.16069
G1 X102.677 Y99.07 E.04495
G1 X101.52 Y97.914 E.06093
G1 X103.351 Y96.083 E.09643
G1 X112.932 Y105.664 E.50469
G1 X114.347 Y104.25 E.07451
G1 X139.263 Y129.166 E1.31247
G1 X146.793 Y136.696 E.39661
G1 X145.378 Y138.11 E.07451
G1 X156.172 Y148.904 E.56853
G1 X159.001 Y146.075 E.14902
G1 X159.91 Y146.984 E.04789
G1 X154.255 Y152.639 E.29786
G1 X156.377 Y154.76 E.11174
G1 X154.76 Y156.377 E.08514
G1 X152.639 Y154.255 E.11174
G1 X146.984 Y159.91 E.29786
G1 X146.075 Y159.001 E.04789
G1 X148.904 Y156.172 E.14902
G1 X138.11 Y145.378 E.56853
G1 X136.696 Y146.793 E.07451
G1 X106.098 Y116.195 E1.61172
G1 X104.25 Y114.347 E.09735
G1 X105.664 Y112.932 E.07451
G1 X96.083 Y103.351 E.50469
G1 X97.914 Y101.52 E.09643
G1 X99.07 Y102.677 E.06093
M73 P44 R10
G1 X98.259 Y103.488 E.04272
M204 S6000
G1 X98.863 Y103.53 F36000
; FEATURE: Outer wall
G1 F3000
M204 S500
G1 X101.268 Y105.934 E.12664
G1 X102.121 Y105.081 E.04495
G1 X102.651 Y105.611 E.02793
G1 X103.276 Y104.987 E.03292
G1 X105.611 Y102.651 E.12301
G1 X105.081 Y102.121 E.02793
G1 X105.934 Y101.268 E.04495
G1 X103.53 Y98.863 E.12664
G1 X102.677 Y99.717 E.04495
G1 X100.874 Y97.914 E.09498
G1 X103.351 Y95.437 E.13048
G1 X112.932 Y105.018 E.50469
G1 X114.347 Y103.603 E.07451
G1 X139.587 Y128.843 E1.32949
G1 X147.439 Y136.696 E.41363
G1 X146.025 Y138.11 E.07451
G1 X156.172 Y148.257 E.53448
G1 X159.001 Y145.428 E.14902
G1 X160.556 Y146.984 E.08194
G1 X154.902 Y152.639 E.29786
G1 X157.023 Y154.76 E.11174
G1 X154.76 Y157.023 E.11919
G1 X152.639 Y154.902 E.11174
G1 X146.984 Y160.556 E.29786
G1 X145.428 Y159.001 E.08194
G1 X148.257 Y156.172 E.14902
G1 X138.11 Y146.025 E.53448
G1 X136.696 Y147.439 E.07451
G1 X105.775 Y116.518 E1.62875
G1 X103.603 Y114.347 E.11438
G1 X105.018 Y112.932 E.07451
G1 X95.437 Y103.351 E.50469
G1 X97.914 Y100.874 E.13048
G1 X99.717 Y102.677 E.09498
G1 X98.906 Y103.488 E.04272
; WIPE_START
G1 X100.295 Y104.927 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X107.927 Y104.894 Z.6 F36000
G1 X113.986 Y104.869 Z.6
G1 Z.2
G1 E.8 F1800
; FEATURE: Bottom surface
; LINE_WIDTH: 0.50343
G1 F6300
M204 S500
G1 X146.029 Y136.911 E1.70046
G1 X145.703 Y137.236 E.01728
G1 X113.806 Y105.34 E1.69274
G1 X113.481 Y105.665 E.01728
G1 X145.523 Y137.708 E1.70046
; WIPE_START
G1 X144.109 Y136.293 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X150.388 Y140.632 Z.6 F36000
G1 X158.854 Y146.48 Z.6
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X159.359 Y146.985 E.02681
G1 X159.034 Y147.311 E.01728
G1 X158.674 Y146.951 E.01909
G1 X158.348 Y147.277 E.01728
G1 X158.708 Y147.637 E.01909
G1 X158.382 Y147.962 E.01728
G1 X158.023 Y147.602 E.01909
G1 X157.697 Y147.928 E.01728
G1 X158.057 Y148.288 E.01909
G1 X157.731 Y148.613 E.01728
G1 X157.371 Y148.254 E.01909
G1 X157.046 Y148.579 E.01728
G1 X157.406 Y148.939 E.01909
G1 X157.08 Y149.265 E.01728
G1 X156.575 Y148.759 E.02681
; WIPE_START
G1 X157.08 Y149.265 E-.27152
G1 X157.406 Y148.939 E-.17499
G1 X157.046 Y148.579 E-.19336
G1 X157.269 Y148.356 E-.12012
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X156.9 Y149.736 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X156.395 Y149.231 E.02681
G1 X156.172 Y149.453 E.01182
G1 X144.829 Y138.11 E.60196
G1 X145.052 Y137.888 E.01182
G1 X113.155 Y105.991 E1.69274
G1 X112.932 Y106.214 E.01182
G1 X103.351 Y96.632 E.50847
G1 X103.248 Y96.735 E.00546
M73 P45 R10
G1 X123.23 Y116.717 E1.06043
G1 X122.904 Y117.043 E.01728
G1 X102.922 Y97.061 E1.06043
G1 X102.597 Y97.387 E.01728
G1 X103.204 Y97.994 E.03223
G1 X102.878 Y98.319 E.01728
G1 X102.126 Y97.567 E.03995
; WIPE_START
G1 X102.878 Y98.319 E-.40452
G1 X103.204 Y97.994 E-.17499
G1 X102.868 Y97.658 E-.18048
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X98.465 Y103.024 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X97.712 Y102.271 E.03995
G1 X97.387 Y102.597 E.01728
G1 X98.139 Y103.349 E.03995
; WIPE_START
G1 X97.387 Y102.597 E-.40452
G1 X97.712 Y102.271 E-.17499
G1 X98.048 Y102.607 E-.18049
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X105.612 Y101.589 Z.6 F36000
G1 X106.659 Y101.448 Z.6
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X122.579 Y117.369 E.84487
G1 X122.253 Y117.694 E.01728
G1 X106.478 Y101.919 E.83716
G1 X106.277 Y102.121 E.01069
G1 X106.807 Y102.651 E.02814
G1 X106.683 Y102.775 E.00659
G1 X121.928 Y118.02 E.80901
G1 X121.602 Y118.345 E.01728
G1 X117.842 Y114.586 E.19953
G3 X117.839 Y115.234 I-2.245 J.313 E.0244
G1 X121.276 Y118.671 E.18242
G1 X120.951 Y118.997 E.01728
G1 X117.733 Y115.779 E.17077
G3 X117.543 Y116.24 I-1.694 J-.429 E.01878
G1 X120.625 Y119.322 E.16359
G1 X120.299 Y119.648 E.01728
G1 X117.295 Y116.644 E.15944
G3 X116.995 Y116.994 I-1.399 J-.894 E.01739
G1 X119.974 Y119.974 E.1581
G1 X119.648 Y120.299 E.01728
G1 X116.644 Y117.295 E.15943
G3 X116.241 Y117.543 I-1.107 J-1.349 E.01782
G1 X119.322 Y120.625 E.16355
G1 X118.997 Y120.95 E.01728
G1 X115.768 Y117.737 E.17093
G3 X115.235 Y117.84 I-.642 J-1.897 E.02046
G1 X118.671 Y121.276 E.18237
G1 X118.346 Y121.602 E.01728
G1 X114.332 Y117.588 E.21301
; WIPE_START
G1 X115.746 Y119.002 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X115.495 Y112.239 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X106.357 Y103.101 E.48493
G1 X106.032 Y103.427 E.01728
G1 X114.593 Y111.988 E.45435
G2 X114.056 Y112.102 I.124 J1.919 E.02069
G1 X105.706 Y103.752 E.4431
G1 X105.381 Y104.078 E.01728
G1 X113.59 Y112.287 E.43567
G2 X113.183 Y112.532 I.688 J1.608 E.01787
G1 X105.055 Y104.404 E.43136
G1 X104.729 Y104.729 E.01728
G1 X112.826 Y112.834 E.4299
G2 X112.533 Y113.184 I1.129 J1.244 E.01717
G1 X104.404 Y105.055 E.43139
G1 X104.078 Y105.38 E.01728
G1 X112.288 Y113.59 E.43568
G2 X112.101 Y114.055 I1.559 J.894 E.01886
G1 X103.752 Y105.706 E.44308
G1 X103.427 Y106.032 E.01728
G1 X111.987 Y114.592 E.4543
G1 X111.978 Y114.649 E.00216
G2 X111.992 Y115.248 I2.137 J.25 E.02255
G1 X103.101 Y106.357 E.47183
G1 X102.776 Y106.683 E.01728
G1 X118.02 Y121.927 E.80901
M73 P45 R9
G1 X117.694 Y122.253 E.01728
G1 X101.92 Y106.478 E.83716
G1 X101.594 Y106.804 E.01728
G1 X117.369 Y122.579 E.83716
G1 X117.043 Y122.904 E.01728
G1 X97.061 Y102.922 E1.06043
G1 X96.735 Y103.248 E.01728
M73 P46 R9
G1 X116.863 Y123.375 E1.06815
; WIPE_START
G1 X115.449 Y121.961 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X123.029 Y121.074 Z.6 F36000
G1 X127.109 Y120.596 Z.6
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X130.301 Y123.788 E.16941
G1 X129.975 Y124.114 E.01728
G1 X126.929 Y121.067 E.16169
G1 X126.603 Y121.393 E.01728
G1 X129.65 Y124.44 E.16169
G1 X129.324 Y124.765 E.01728
G1 X126.277 Y121.718 E.16169
G1 X125.952 Y122.044 E.01728
G1 X128.999 Y125.091 E.16169
G1 X128.673 Y125.417 E.01728
G1 X125.626 Y122.37 E.16169
G1 X125.301 Y122.695 E.01728
G1 X128.347 Y125.742 E.16169
G1 X128.022 Y126.068 E.01728
G1 X124.975 Y123.021 E.16169
G1 X124.649 Y123.347 E.01728
G1 X127.696 Y126.393 E.16169
G1 X127.37 Y126.719 E.01728
G1 X124.324 Y123.672 E.16169
G1 X123.998 Y123.998 E.01728
G1 X127.045 Y127.045 E.16169
G1 X126.719 Y127.37 E.01728
G1 X123.672 Y124.323 E.16169
G1 X123.347 Y124.649 E.01728
G1 X126.394 Y127.696 E.16169
G1 X126.068 Y128.022 E.01728
G1 X123.021 Y124.975 E.16169
G1 X122.695 Y125.3 E.01728
G1 X125.742 Y128.347 E.16169
G1 X125.417 Y128.673 E.01728
G1 X122.37 Y125.626 E.16169
G1 X122.044 Y125.952 E.01728
G1 X125.091 Y128.998 E.16169
G1 X124.765 Y129.324 E.01728
G1 X121.719 Y126.277 E.16169
G1 X121.393 Y126.603 E.01728
G1 X124.44 Y129.65 E.16169
G1 X124.114 Y129.975 E.01728
G1 X121.067 Y126.929 E.16169
G1 X120.742 Y127.254 E.01728
G1 X123.934 Y130.446 E.16941
; WIPE_START
G1 X122.52 Y129.032 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X130.1 Y128.145 Z.6 F36000
G1 X134.18 Y127.667 Z.6
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X156.429 Y149.916 E1.18073
G1 X156.103 Y150.242 E.01728
G1 X134 Y128.138 E1.17301
G1 X133.674 Y128.464 E.01728
G1 X155.777 Y150.567 E1.17301
G1 X155.452 Y150.893 E.01728
G1 X133.348 Y128.79 E1.17301
G1 X133.023 Y129.115 E.01728
G1 X155.126 Y151.218 E1.17301
G1 X154.801 Y151.544 E.01728
G1 X139.056 Y135.8 E.83553
G3 X139.053 Y136.448 I-2.371 J.31 E.02437
G1 X154.475 Y151.87 E.81845
G1 X154.149 Y152.195 E.01728
G1 X138.946 Y136.992 E.80682
G1 X138.756 Y137.454 E.01872
G1 X153.824 Y152.521 E.79961
G1 X153.706 Y152.639 E.00626
G1 X155.827 Y154.76 E.11258
G1 X155.619 Y154.968 E.01103
G1 X138.508 Y137.857 E.90807
G3 X138.207 Y138.207 I-1.397 J-.895 E.01739
G1 X155.294 Y155.294 E.90676
G1 X154.968 Y155.619 E.01728
G1 X137.857 Y138.508 E.90807
G3 X137.454 Y138.756 I-1.108 J-1.349 E.01782
M73 P47 R9
G1 X152.521 Y153.824 E.79961
G1 X152.196 Y154.149 E.01728
G1 X136.984 Y138.949 E.80695
G3 X136.447 Y139.052 I-.645 J-1.911 E.02057
G1 X151.87 Y154.475 E.81846
G1 X151.544 Y154.8 E.01728
G1 X135.545 Y138.801 E.84907
; WIPE_START
G1 X136.959 Y140.215 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X136.708 Y133.452 Z.6 F36000
G1 Z.2
G1 E.8 F1800
G1 F6300
M204 S500
G1 X132.697 Y129.441 E.21287
G1 X132.372 Y129.766 E.01728
G1 X135.807 Y133.201 E.18229
G2 X135.269 Y133.315 I.125 J1.92 E.02069
G1 X132.046 Y130.092 E.17104
G1 X131.72 Y130.418 E.01728
G1 X134.803 Y133.5 E.16358
G2 X134.397 Y133.746 I.671 J1.567 E.01786
G1 X131.395 Y130.743 E.15933
G1 X131.069 Y131.069 E.01728
G1 X134.044 Y134.044 E.15786
G1 X133.745 Y134.396 E.01734
G1 X130.743 Y131.395 E.15929
G1 X130.418 Y131.72 E.01728
G1 X133.5 Y134.803 E.16358
G2 X133.315 Y135.269 I1.566 J.89 E.01889
G1 X130.092 Y132.046 E.17105
G1 X129.767 Y132.371 E.01728
G1 X133.201 Y135.806 E.18225
G1 X133.192 Y135.863 E.00217
G2 X133.206 Y136.462 I2.139 J.25 E.02257
G1 X129.441 Y132.697 E.19979
G1 X129.115 Y133.023 E.01728
G1 X151.219 Y155.126 E1.17301
G1 X150.893 Y155.452 E.01728
G1 X128.79 Y133.348 E1.17301
G1 X128.464 Y133.674 E.01728
G1 X150.567 Y155.777 E1.17301
G1 X150.242 Y156.103 E.01728
G1 X128.138 Y134 E1.17301
G1 X127.813 Y134.325 E.01728
G1 X149.916 Y156.429 E1.17301
G1 X149.59 Y156.754 E.01728
G1 X149.231 Y156.394 E.01909
G1 X149.453 Y156.172 E.01181
G1 X138.11 Y144.829 E.60196
G1 X137.888 Y145.052 E.01181
G1 X105.991 Y113.155 E1.69274
G1 X105.665 Y113.48 E.01728
G1 X137.562 Y145.377 E1.69274
G1 X137.237 Y145.703 E.01728
G1 X105.34 Y113.806 E1.69274
G1 X105.014 Y114.132 E.01728
G1 X137.056 Y146.174 E1.70046
; WIPE_START
G1 X135.642 Y144.76 E-.76
; WIPE_END
G1 E-.04 F1800
M204 S6000
G1 X141.313 Y149.868 Z.6 F36000
G1 X148.76 Y156.575 Z.6
G1 Z.2
M73 P48 R9
G1 E.8 F1800
G1 F6300
M204 S500
G1 X149.265 Y157.08 E.02681
G1 X148.939 Y157.405 E.01728
G1 X148.579 Y157.046 E.0191
G1 X148.254 Y157.371 E.01728
G1 X148.614 Y157.731 E.0191
G1 X148.288 Y158.057 E.01728
G1 X147.928 Y157.697 E.01909
G1 X147.603 Y158.023 E.01728
G1 X147.962 Y158.382 E.01909
G1 X147.637 Y158.708 E.01728
G1 X147.277 Y158.348 E.0191
G1 X146.951 Y158.674 E.01728
G1 X147.311 Y159.034 E.0191
G1 X146.985 Y159.359 E.01728
G1 X146.48 Y158.854 E.02681
; CHANGE_LAYER
; Z_HEIGHT: 0.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F6300
G1 X146.985 Y159.359 E-.27152
G1 X147.311 Y159.034 E-.17499
G1 X146.951 Y158.674 E-.19337
G1 X147.175 Y158.45 E-.12012
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
G1 X133.868 Y127.36
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X127.36 Y133.868 E.30532
G1 X124.246 Y130.754 E.14609
G1 X130.754 Y124.246 E.30532
G1 X133.826 Y127.317 E.1441
G1 X133.314 Y127.36 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.36 Y133.314 E.25872
G1 X124.8 Y130.754 E.11123
G1 X130.754 Y124.8 E.25872
G1 X133.271 Y127.317 E.10939
; WIPE_START
M204 S10000
G1 X131.867 Y128.742 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X124.34 Y127.477 Z.8 F36000
G1 X120.289 Y126.797 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X117.175 Y123.683 E.14609
G1 X118.661 Y122.196 E.06973
G1 X123.683 Y117.175 E.23559
G1 X126.797 Y120.289 E.14609
G1 X120.331 Y126.755 E.30333
G1 X120.289 Y126.243 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X117.729 Y123.683 E.11123
G1 X118.938 Y122.474 E.05254
G1 X123.683 Y117.729 E.20618
G1 X126.243 Y120.289 E.11123
G1 X120.331 Y126.2 E.25688
; WIPE_START
M204 S10000
G1 X118.894 Y124.81 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X116.091 Y117.71 Z.8 F36000
G1 X114.132 Y112.75 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X114.358 Y112.68 E.00784
G3 X114.739 Y112.618 I.555 J2.232 E.01283
G1 X115.057 Y112.616 E.01055
G3 X114.076 Y112.77 I-.144 J2.296 E.44618
G1 X114.174 Y113.158 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X114.249 Y113.125 E.00252
G3 X114.769 Y113.01 I.665 J1.788 E.01642
G1 X115.035 Y113.009 E.00815
G3 X114.013 Y113.231 I-.12 J1.904 E.33574
G1 X114.12 Y113.183 E.0036
; WIPE_START
M204 S10000
G1 X114.249 Y113.125 E-.05391
G1 X114.46 Y113.06 E-.0838
G1 X114.769 Y113.01 E-.11909
G1 X115.035 Y113.009 E-.10083
G1 X115.306 Y113.046 E-.104
G1 X115.555 Y113.115 E-.09849
G1 X115.764 Y113.204 E-.08615
G1 X115.993 Y113.338 E-.10084
G1 X116.019 Y113.36 E-.01288
; WIPE_END
G1 E-.04 F1800
G1 X120.75 Y119.349 Z.8 F36000
G1 X133.838 Y135.923 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.839 Y135.885 E.00126
G3 X135.952 Y133.832 I2.289 J.243 E.10607
G1 X136.274 Y133.83 E.01066
G3 X133.83 Y136.274 I-.146 J2.298 E.35017
G1 X133.837 Y135.983 E.00966
G1 X134.23 Y135.926 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.272 Y135.678 E.00775
G3 X135.982 Y134.224 I1.856 J.45 E.07374
G1 X136.249 Y134.222 E.00819
G3 X134.224 Y135.986 I-.121 J1.906 E.27715
; WIPE_START
M204 S10000
G1 X134.272 Y135.678 E-.11857
G1 X134.352 Y135.425 E-.10081
G1 X134.445 Y135.225 E-.08383
G1 X134.615 Y134.962 E-.11905
G1 X134.792 Y134.763 E-.10083
G1 X134.958 Y134.619 E-.08383
G1 X135.219 Y134.448 E-.11861
G1 X135.302 Y134.41 E-.03447
; WIPE_END
G1 E-.04 F1800
G1 X129.46 Y129.498 Z.8 F36000
G1 X98.578 Y103.53 Z.8
G1 Z.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X101.268 Y106.22 E.12619
G1 X102.137 Y105.35 E.0408
G1 X102.668 Y105.881 E.02488
G1 X105.881 Y102.668 E.15073
G1 X105.35 Y102.137 E.02488
G1 X106.22 Y101.268 E.0408
G1 X103.53 Y98.578 E.12619
G1 X102.661 Y99.447 E.0408
G1 X101.143 Y97.93 E.07118
G1 X103.346 Y95.728 E.10332
G1 X109.296 Y101.678 E.27914
G1 X112.927 Y105.309 E.17034
G1 X114.342 Y103.894 E.0664
G1 X147.149 Y136.7 E1.53904
G1 X145.734 Y138.116 E.0664
G1 X156.166 Y148.549 E.48942
G1 X158.997 Y145.718 E.13278
G1 X160.267 Y146.988 E.05957
G1 X154.616 Y152.639 E.26509
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X146.988 Y160.267 E.26509
G1 X145.718 Y158.997 E.05957
G1 X148.549 Y156.166 E.13278
G1 X138.116 Y145.734 E.48942
G1 X136.7 Y147.149 E.0664
G1 X103.894 Y114.342 E1.53904
G1 X105.309 Y112.927 E.0664
G1 X95.728 Y103.346 E.44948
G1 X97.93 Y101.143 E.10332
G1 X99.447 Y102.661 E.07118
G1 X98.62 Y103.488 E.03881
G1 X99.132 Y103.53 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X101.268 Y105.666 E.0928
G1 X102.137 Y104.796 E.0378
G1 X102.668 Y105.326 E.02305
G1 X105.326 Y102.668 E.11553
G1 X104.796 Y102.137 E.02305
G1 X105.666 Y101.268 E.0378
G1 X103.53 Y99.132 E.0928
G1 X102.661 Y100.002 E.0378
G1 X100.589 Y97.93 E.09003
G1 X103.346 Y95.173 E.1198
G1 X109.573 Y101.401 E.27062
G1 X112.927 Y104.754 E.14574
G1 X114.342 Y103.339 E.0615
G1 X147.704 Y136.7 E1.44971
G1 X146.288 Y138.116 E.0615
G1 X156.166 Y147.994 E.42926
G1 X158.997 Y145.164 E.12299
G1 X160.821 Y146.988 E.07928
G1 X155.17 Y152.639 E.24555
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X146.988 Y160.821 E.24555
G1 X145.164 Y158.997 E.07928
G1 X147.994 Y156.166 E.12299
G1 X138.116 Y146.288 E.42926
G1 X136.7 Y147.704 E.0615
G1 X103.339 Y114.342 E1.44971
G1 X104.754 Y112.927 E.0615
G1 X95.173 Y103.346 E.41635
G1 X97.93 Y100.589 E.1198
G1 X100.002 Y102.661 E.09003
G1 X99.175 Y103.488 E.03595
; WIPE_START
M204 S10000
G1 X100.56 Y104.93 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X96.079 Y103.466 Z.8 F36000
G1 Z.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42009
G1 F15000
G1 X97.931 Y101.615 E.08046
G1 X98.197 Y101.882 E.01159
G1 X96.466 Y103.613 E.07524
G1 X96.733 Y103.88 E.01159
G1 X98.464 Y102.148 E.07524
G1 X98.731 Y102.415 E.01159
G1 X97 Y104.146 E.07524
G1 X97.266 Y104.413 E.01159
G1 X98.128 Y103.552 E.03744
G1 X98.394 Y103.818 E.01159
G1 X97.533 Y104.68 E.03744
G1 X97.8 Y104.946 E.01159
G1 X98.661 Y104.085 E.03744
G1 X98.928 Y104.352 E.01159
G1 X98.066 Y105.213 E.03744
G1 X98.333 Y105.48 E.01159
G1 X99.194 Y104.618 E.03744
G1 X99.461 Y104.885 E.01159
G1 X98.6 Y105.746 E.03744
G1 X98.866 Y106.013 E.01159
G1 X99.728 Y105.152 E.03744
G1 X99.994 Y105.418 E.01159
G1 X99.133 Y106.28 E.03744
G1 X99.4 Y106.547 E.01159
G1 X100.261 Y105.685 E.03744
G1 X100.528 Y105.952 E.01159
G1 X99.667 Y106.813 E.03744
G1 X99.933 Y107.08 E.01159
G1 X100.795 Y106.219 E.03744
G1 X101.061 Y106.485 E.01159
G1 X100.2 Y107.347 E.03744
G1 X100.467 Y107.613 E.01159
G1 X102.198 Y105.882 E.07524
G1 X102.464 Y106.149 E.01159
G1 X100.613 Y108 E.08046
; WIPE_START
G1 X102.028 Y106.586 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X103.063 Y99.024 Z.8 F36000
G1 X103.466 Y96.079 Z.8
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X101.615 Y97.931 E.08046
G1 X101.882 Y98.197 E.01159
G1 X103.613 Y96.466 E.07524
G1 X103.88 Y96.733 E.01159
G1 X102.148 Y98.464 E.07524
G1 X102.415 Y98.731 E.01159
G1 X104.146 Y97 E.07524
G1 X104.413 Y97.266 E.01159
G1 X103.552 Y98.128 E.03744
G1 X103.818 Y98.394 E.01159
G1 X104.68 Y97.533 E.03744
G1 X104.946 Y97.8 E.01159
G1 X104.085 Y98.661 E.03744
G1 X104.352 Y98.928 E.01159
G1 X105.213 Y98.066 E.03744
G1 X105.48 Y98.333 E.01159
G1 X104.618 Y99.194 E.03744
G1 X104.885 Y99.461 E.01159
G1 X105.746 Y98.6 E.03744
G1 X106.013 Y98.866 E.01159
G1 X105.152 Y99.728 E.03744
G1 X105.418 Y99.994 E.01159
G1 X106.28 Y99.133 E.03744
G1 X106.546 Y99.4 E.01159
G1 X105.685 Y100.261 E.03744
G1 X105.952 Y100.528 E.01159
G1 X106.813 Y99.667 E.03744
G1 X107.08 Y99.933 E.01159
G1 X106.219 Y100.795 E.03744
G1 X106.485 Y101.061 E.01159
G1 X107.347 Y100.2 E.03744
G1 X107.613 Y100.467 E.01159
G1 X105.882 Y102.198 E.07524
G1 X106.149 Y102.464 E.01159
G1 X107.88 Y100.733 E.07524
G1 X108.147 Y101 E.01159
G1 X101 Y108.147 E.31063
G1 X101.267 Y108.413 E.01159
G1 X108.413 Y101.267 E.31063
G1 X108.68 Y101.533 E.01159
G1 X101.533 Y108.68 E.31063
G1 X101.8 Y108.947 E.01159
G1 X108.947 Y101.8 E.31063
G1 X109.213 Y102.067 E.01159
G1 X102.067 Y109.213 E.31063
G1 X102.334 Y109.48 E.01159
G1 X109.48 Y102.334 E.31063
G1 X109.747 Y102.6 E.01159
G1 X102.6 Y109.747 E.31063
G1 X102.867 Y110.014 E.01159
G1 X110.014 Y102.867 E.31063
G1 X110.28 Y103.134 E.01159
G1 X103.134 Y110.28 E.31063
G1 X103.4 Y110.547 E.01159
G1 X110.547 Y103.4 E.31063
G1 X110.814 Y103.667 E.01159
G1 X103.667 Y110.814 E.31063
G1 X103.934 Y111.08 E.01159
G1 X111.08 Y103.934 E.31063
G1 X111.347 Y104.2 E.01159
G1 X104.2 Y111.347 E.31063
G1 X104.467 Y111.614 E.01159
G1 X111.614 Y104.467 E.31063
G1 X111.88 Y104.734 E.01159
G1 X104.734 Y111.88 E.31063
G1 X105.001 Y112.147 E.01159
G1 X112.147 Y105.001 E.31063
G1 X112.414 Y105.267 E.01159
G1 X105.267 Y112.414 E.31063
G1 X105.534 Y112.681 E.01159
G1 X112.681 Y105.534 E.31063
G1 X112.927 Y105.78 E.01071
G1 X114.342 Y104.365 E.06152
G1 X114.363 Y104.385 E.00089
G1 X104.385 Y114.363 E.43367
G1 X104.652 Y114.629 E.01159
G1 X114.629 Y104.652 E.43367
G1 X114.896 Y104.919 E.01159
G1 X104.919 Y114.896 E.43367
G1 X105.185 Y115.163 E.01159
G1 X115.163 Y105.185 E.43367
G1 X115.429 Y105.452 E.01159
G1 X105.452 Y115.429 E.43367
G1 X105.719 Y115.696 E.01159
G1 X115.696 Y105.719 E.43367
G1 X115.963 Y105.985 E.01159
G1 X105.985 Y115.963 E.43367
G1 X106.252 Y116.23 E.01159
G1 X116.23 Y106.252 E.43367
G1 X116.496 Y106.519 E.01159
G1 X106.519 Y116.496 E.43367
G1 X106.786 Y116.763 E.01159
G1 X116.763 Y106.786 E.43367
G1 X117.03 Y107.052 E.01159
G1 X107.052 Y117.03 E.43367
G1 X107.319 Y117.296 E.01159
G1 X117.296 Y107.319 E.43367
G1 X117.563 Y107.586 E.01159
M73 P49 R9
G1 X107.586 Y117.563 E.43367
G1 X107.852 Y117.83 E.01159
G1 X117.83 Y107.852 E.43367
G1 X118.096 Y108.119 E.01159
G1 X107.999 Y118.216 E.43888
G1 X111.466 Y121.684 F36000
G1 F15000
G1 X115.733 Y117.417 E.18544
G3 X115.074 Y117.542 I-.838 J-2.611 E.02066
G1 X111.319 Y121.297 E.16319
G1 X111.053 Y121.03 E.01159
G1 X114.548 Y117.525 E.15213
G3 X114.124 Y117.426 I.142 J-1.558 E.01343
G1 X110.786 Y120.763 E.14508
G1 X110.519 Y120.497 E.01159
G1 X113.744 Y117.272 E.14016
G3 X113.412 Y117.07 I.587 J-1.339 E.01197
G1 X110.253 Y120.23 E.13733
G1 X109.986 Y119.963 E.01159
G1 X113.115 Y116.835 E.13599
G3 X112.859 Y116.557 I.945 J-1.126 E.01163
G1 X109.719 Y119.697 E.13647
G1 X109.453 Y119.43 E.01159
G1 X112.642 Y116.241 E.13862
G3 X112.469 Y115.88 I1.162 J-.777 E.01234
G1 X109.186 Y119.163 E.14272
G1 X108.919 Y118.897 E.01159
G1 X112.34 Y115.475 E.1487
G3 X112.283 Y114.999 I3.649 J-.676 E.01476
G1 X108.652 Y118.63 E.15782
G1 X108.386 Y118.363 E.01159
G1 X112.567 Y114.182 E.18172
; WIPE_START
G1 X111.152 Y115.596 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X114.186 Y112.563 Z.8 F36000
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X118.363 Y108.386 E.18156
G1 X118.63 Y108.652 E.01159
G1 X114.999 Y112.283 E.15782
G3 X115.471 Y112.344 I-.082 J2.496 E.01466
G1 X118.897 Y108.919 E.14888
G1 X119.163 Y109.186 E.01159
G1 X115.883 Y112.466 E.14259
G3 X116.24 Y112.642 I-.501 J1.47 E.01228
G1 X119.43 Y109.453 E.13865
G1 X119.697 Y109.719 E.01159
G1 X116.554 Y112.861 E.13657
G3 X116.835 Y113.115 I-.805 J1.172 E.01164
G1 X119.963 Y109.986 E.13599
G1 X120.23 Y110.253 E.01159
G1 X117.073 Y113.41 E.13723
G3 X117.269 Y113.747 I-1.066 J.846 E.01203
G1 X120.497 Y110.519 E.1403
G1 X120.763 Y110.786 E.01159
G1 X117.424 Y114.125 E.14513
G3 X117.526 Y114.557 I-1.617 J.609 E.01367
G1 X121.03 Y111.053 E.1523
G1 X121.297 Y111.319 E.01159
G1 X117.538 Y115.078 E.16336
G3 X117.417 Y115.732 I-2.563 J-.136 E.02052
G1 X121.564 Y111.586 E.18022
G1 X121.83 Y111.853 E.01159
G1 X111.853 Y121.83 E.43367
G1 X112.12 Y122.097 E.01159
G1 X122.097 Y112.12 E.43367
G1 X122.364 Y112.386 E.01159
G1 X112.386 Y122.364 E.43367
G1 X112.653 Y122.63 E.01159
G1 X122.63 Y112.653 E.43367
G1 X122.897 Y112.92 E.01159
G1 X112.92 Y122.897 E.43367
G1 X113.186 Y123.164 E.01159
G1 X123.164 Y113.186 E.43367
G1 X123.43 Y113.453 E.01159
G1 X113.453 Y123.43 E.43367
G1 X113.72 Y123.697 E.01159
G1 X123.697 Y113.72 E.43367
G1 X123.964 Y113.986 E.01159
G1 X113.986 Y123.964 E.43367
G1 X114.253 Y124.231 E.01159
G1 X124.231 Y114.253 E.43367
G1 X124.497 Y114.52 E.01159
G1 X114.52 Y124.497 E.43367
G1 X114.787 Y124.764 E.01159
G1 X124.764 Y114.787 E.43367
G1 X125.031 Y115.053 E.01159
G1 X114.933 Y125.151 E.43888
; WIPE_START
G1 X116.347 Y123.736 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X123.347 Y120.693 Z.8 F36000
G1 X128.618 Y118.4 Z.8
G1 Z.4
G1 E.8 F1800
G1 F15000
G1 X126.999 Y120.019 E.07036
G1 X126.732 Y119.753 E.01159
G1 X128.231 Y118.254 E.06515
G1 X127.964 Y117.987 E.01159
G1 X126.465 Y119.486 E.06515
G1 X126.199 Y119.219 E.01159
G1 X127.698 Y117.72 E.06515
G1 X127.431 Y117.454 E.01159
G1 X125.932 Y118.952 E.06515
G1 X125.665 Y118.686 E.01159
G1 X127.164 Y117.187 E.06515
G1 X126.898 Y116.92 E.01159
G1 X125.399 Y118.419 E.06515
G1 X125.132 Y118.152 E.01159
G1 X126.631 Y116.653 E.06515
G1 X126.364 Y116.387 E.01159
G1 X124.865 Y117.886 E.06515
G1 X124.599 Y117.619 E.01159
G1 X126.097 Y116.12 E.06515
G1 X125.831 Y115.853 E.01159
G1 X124.332 Y117.352 E.06515
G1 X124.065 Y117.086 E.01159
G1 X125.564 Y115.587 E.06515
G1 X125.297 Y115.32 E.01159
G1 X115.32 Y125.297 E.43367
G1 X115.587 Y125.564 E.01159
G1 X117.086 Y124.065 E.06515
G1 X117.352 Y124.332 E.01159
G1 X115.853 Y125.831 E.06515
G1 X116.12 Y126.097 E.01159
G1 X117.619 Y124.599 E.06515
G1 X117.886 Y124.865 E.01159
G1 X116.387 Y126.364 E.06515
G1 X116.653 Y126.631 E.01159
G1 X118.152 Y125.132 E.06515
G1 X118.419 Y125.399 E.01159
G1 X116.92 Y126.898 E.06515
G1 X117.187 Y127.164 E.01159
G1 X118.686 Y125.665 E.06515
G1 X118.952 Y125.932 E.01159
G1 X117.454 Y127.431 E.06515
G1 X117.72 Y127.698 E.01159
G1 X119.219 Y126.199 E.06515
G1 X119.486 Y126.465 E.01159
G1 X117.987 Y127.964 E.06515
G1 X118.254 Y128.231 E.01159
G1 X119.753 Y126.732 E.06515
G1 X120.019 Y126.999 E.01159
G1 X118.52 Y128.498 E.06515
G1 X118.787 Y128.764 E.01159
G1 X128.764 Y118.787 E.43367
G1 X129.031 Y119.054 E.01159
G1 X119.054 Y129.031 E.43367
G1 X119.32 Y129.298 E.01159
G1 X129.298 Y119.32 E.43367
G1 X129.565 Y119.587 E.01159
G1 X119.587 Y129.565 E.43367
G1 X119.854 Y129.831 E.01159
G1 X129.831 Y119.854 E.43367
G1 X130.098 Y120.121 E.01159
G1 X120.121 Y130.098 E.43367
G1 X120.387 Y130.365 E.01159
G1 X130.365 Y120.387 E.43367
G1 X130.631 Y120.654 E.01159
G1 X120.654 Y130.631 E.43367
G1 X120.921 Y130.898 E.01159
G1 X130.898 Y120.921 E.43367
G1 X131.165 Y121.187 E.01159
G1 X121.187 Y131.165 E.43367
G1 X121.454 Y131.431 E.01159
G1 X131.431 Y121.454 E.43367
G1 X131.698 Y121.721 E.01159
G1 X121.721 Y131.698 E.43367
G1 X121.987 Y131.965 E.01159
G1 X131.965 Y121.987 E.43367
G1 X132.232 Y122.254 E.01159
G1 X122.134 Y132.351 E.43888
G1 X125.601 Y135.819 F36000
G1 F15000
G1 X127.22 Y134.2 E.07036
G1 X126.953 Y133.933 E.01159
G1 X125.455 Y135.432 E.06515
G1 X125.188 Y135.165 E.01159
G1 X126.687 Y133.666 E.06515
G1 X126.42 Y133.4 E.01159
G1 X124.921 Y134.899 E.06515
G1 X124.654 Y134.632 E.01159
G1 X126.153 Y133.133 E.06515
G1 X125.887 Y132.866 E.01159
G1 X124.388 Y134.365 E.06515
G1 X124.121 Y134.098 E.01159
G1 X125.62 Y132.6 E.06515
G1 X125.353 Y132.333 E.01159
G1 X123.854 Y133.832 E.06515
G1 X123.588 Y133.565 E.01159
G1 X125.087 Y132.066 E.06515
G1 X124.82 Y131.799 E.01159
G1 X123.321 Y133.298 E.06515
G1 X123.054 Y133.032 E.01159
G1 X124.553 Y131.533 E.06515
G1 X124.286 Y131.266 E.01159
G1 X122.788 Y132.765 E.06515
G1 X122.521 Y132.498 E.01159
G1 X124.02 Y130.999 E.06515
G1 X123.774 Y130.754 E.01067
G1 X130.754 Y123.774 E.30337
G1 X130.999 Y124.02 E.01067
G1 X132.498 Y122.521 E.06515
G1 X132.765 Y122.788 E.01159
G1 X131.266 Y124.286 E.06515
G1 X131.533 Y124.553 E.01159
G1 X133.032 Y123.054 E.06515
G1 X133.298 Y123.321 E.01159
G1 X131.799 Y124.82 E.06515
G1 X132.066 Y125.087 E.01159
G1 X133.565 Y123.588 E.06515
G1 X133.832 Y123.854 E.01159
G1 X132.333 Y125.353 E.06515
G1 X132.6 Y125.62 E.01159
G1 X134.098 Y124.121 E.06515
G1 X134.365 Y124.388 E.01159
G1 X132.866 Y125.887 E.06515
G1 X133.133 Y126.153 E.01159
G1 X134.632 Y124.654 E.06515
G1 X134.898 Y124.921 E.01159
G1 X133.4 Y126.42 E.06515
G1 X133.666 Y126.687 E.01159
G1 X135.165 Y125.188 E.06515
G1 X135.432 Y125.455 E.01159
G1 X133.933 Y126.953 E.06515
G1 X134.2 Y127.22 E.01159
G1 X135.699 Y125.721 E.06515
G1 X135.965 Y125.988 E.01159
G1 X125.988 Y135.965 E.43367
G1 X126.255 Y136.232 E.01159
G1 X136.232 Y126.255 E.43367
G1 X136.499 Y126.521 E.01159
G1 X126.521 Y136.499 E.43367
G1 X126.788 Y136.765 E.01159
G1 X136.765 Y126.788 E.43367
G1 X137.032 Y127.055 E.01159
G1 X127.055 Y137.032 E.43367
G1 X127.321 Y137.299 E.01159
G1 X137.299 Y127.321 E.43367
G1 X137.565 Y127.588 E.01159
G1 X127.588 Y137.565 E.43367
G1 X127.855 Y137.832 E.01159
G1 X137.832 Y127.855 E.43367
G1 X138.099 Y128.122 E.01159
G1 X128.122 Y138.099 E.43367
G1 X128.388 Y138.366 E.01159
G1 X138.366 Y128.388 E.43367
G1 X138.632 Y128.655 E.01159
G1 X128.655 Y138.632 E.43367
G1 X128.922 Y138.899 E.01159
G1 X138.899 Y128.922 E.43367
G1 X139.166 Y129.188 E.01159
G1 X129.068 Y139.286 E.43888
G1 X132.535 Y142.753 F36000
G1 F15000
G1 X136.559 Y138.729 E.1749
G3 X136.002 Y138.752 I-.36 J-1.912 E.01719
G1 X132.389 Y142.366 E.15707
G1 X132.122 Y142.099 E.01159
G1 X135.531 Y138.691 E.14816
G3 X135.125 Y138.563 I.251 J-1.507 E.01312
G1 X131.855 Y141.833 E.14211
G1 X131.589 Y141.566 E.01159
G1 X134.771 Y138.384 E.13831
G1 X134.455 Y138.166 E.01178
G1 X131.322 Y141.299 E.13619
G1 X131.055 Y141.033 E.01159
G1 X134.183 Y137.904 E.13597
G3 X133.951 Y137.604 I.921 J-.954 E.01173
G1 X130.789 Y140.766 E.13744
G1 X130.522 Y140.499 E.01159
G1 X133.753 Y137.268 E.14043
G3 X133.605 Y136.882 I1.419 J-.762 E.01274
G1 X130.255 Y140.232 E.14562
G1 X129.988 Y139.966 E.01159
G1 X133.515 Y136.439 E.1533
G3 X133.505 Y135.916 I1.641 J-.295 E.01614
G1 X129.722 Y139.699 E.16444
G1 X129.455 Y139.432 E.01159
G1 X133.651 Y135.236 E.18238
G3 X135.236 Y133.651 I2.451 J.866 E.07125
G1 X139.432 Y129.455 E.18238
G1 X139.699 Y129.722 E.01159
G1 X135.922 Y133.499 E.16418
G3 X136.439 Y133.515 I.127 J4.101 E.0159
G1 X139.966 Y129.988 E.1533
G1 X140.232 Y130.255 E.01159
G1 X136.882 Y133.605 E.14562
G3 X137.266 Y133.755 I-.368 J1.505 E.01269
G1 X140.499 Y130.522 E.14055
G1 X140.766 Y130.789 E.01159
G1 X137.608 Y133.947 E.13727
G3 X137.905 Y134.183 I-4.623 J6.118 E.01167
G1 X141.033 Y131.055 E.13595
G1 X141.299 Y131.322 E.01159
G1 X138.164 Y134.457 E.13627
G3 X138.386 Y134.769 I-.868 J.851 E.01181
G1 X141.566 Y131.589 E.13824
G1 X141.833 Y131.855 E.01159
G1 X138.565 Y135.123 E.14202
G3 X138.689 Y135.532 I-1.327 J.626 E.01319
G1 X142.099 Y132.122 E.14821
G1 X142.366 Y132.389 E.01159
G1 X138.757 Y135.998 E.15689
G3 X138.722 Y136.566 I-2.768 J.118 E.01751
G1 X142.633 Y132.655 E.16997
G1 X142.899 Y132.922 E.01159
G1 X132.922 Y142.899 E.43367
G1 X133.189 Y143.166 E.01159
G1 X143.166 Y133.189 E.43367
G1 X143.433 Y133.456 E.01159
G1 X133.456 Y143.433 E.43367
G1 X133.722 Y143.7 E.01159
G1 X143.7 Y133.722 E.43367
G1 X143.966 Y133.989 E.01159
G1 X133.989 Y143.966 E.43367
G1 X134.256 Y144.233 E.01159
G1 X144.233 Y134.256 E.43367
G1 X144.5 Y134.522 E.01159
G1 X134.522 Y144.5 E.43367
G1 X134.789 Y144.766 E.01159
G1 X144.766 Y134.789 E.43367
G1 X145.033 Y135.056 E.01159
G1 X135.056 Y145.033 E.43367
G1 X135.322 Y145.3 E.01159
G1 X145.3 Y135.322 E.43367
G1 X145.566 Y135.589 E.01159
G1 X135.589 Y145.566 E.43367
G1 X135.856 Y145.833 E.01159
G1 X145.833 Y135.856 E.43367
G1 X146.1 Y136.123 E.01159
G1 X136.123 Y146.1 E.43367
G1 X136.389 Y146.367 E.01159
G1 X146.367 Y136.389 E.43367
G1 X146.633 Y136.656 E.01159
G1 X136.656 Y146.633 E.43367
G1 X136.7 Y146.678 E.00193
G1 X138.116 Y145.262 E.06152
G1 X138.338 Y145.485 E.00966
G1 X145.485 Y138.338 E.31063
G1 X145.751 Y138.605 E.01159
G1 X138.605 Y145.751 E.31063
G1 X138.871 Y146.018 E.01159
G1 X146.018 Y138.871 E.31063
G1 X146.285 Y139.138 E.01159
G1 X139.138 Y146.285 E.31063
G1 X139.405 Y146.551 E.01159
M73 P50 R9
G1 X146.551 Y139.405 E.31063
G1 X146.818 Y139.671 E.01159
G1 X139.671 Y146.818 E.31063
G1 X139.938 Y147.085 E.01159
G1 X147.085 Y139.938 E.31063
G1 X147.352 Y140.205 E.01159
G1 X140.205 Y147.352 E.31063
G1 X140.472 Y147.618 E.01159
G1 X147.618 Y140.472 E.31063
G1 X147.885 Y140.738 E.01159
G1 X140.738 Y147.885 E.31063
G1 X141.005 Y148.152 E.01159
G1 X148.152 Y141.005 E.31063
G1 X148.418 Y141.272 E.01159
G1 X141.272 Y148.418 E.31063
G1 X141.538 Y148.685 E.01159
G1 X148.685 Y141.538 E.31063
G1 X148.952 Y141.805 E.01159
G1 X141.805 Y148.952 E.31063
G1 X142.072 Y149.218 E.01159
G1 X149.218 Y142.072 E.31063
G1 X149.485 Y142.338 E.01159
G1 X142.338 Y149.485 E.31063
G1 X142.605 Y149.752 E.01159
G1 X149.752 Y142.605 E.31063
G1 X150.019 Y142.872 E.01159
G1 X142.872 Y150.019 E.31063
G1 X143.139 Y150.285 E.01159
G1 X150.285 Y143.139 E.31063
G1 X150.552 Y143.405 E.01159
G1 X143.405 Y150.552 E.31063
G1 X143.672 Y150.819 E.01159
G1 X150.819 Y143.672 E.31063
G1 X151.085 Y143.939 E.01159
G1 X143.939 Y151.085 E.31063
G1 X144.205 Y151.352 E.01159
G1 X151.352 Y144.205 E.31063
G1 X151.619 Y144.472 E.01159
G1 X144.472 Y151.619 E.31063
G1 X144.739 Y151.885 E.01159
G1 X151.885 Y144.739 E.31063
G1 X152.152 Y145.005 E.01159
G1 X145.005 Y152.152 E.31063
G1 X145.272 Y152.419 E.01159
G1 X152.419 Y145.272 E.31063
G1 X152.686 Y145.539 E.01159
G1 X145.539 Y152.686 E.31063
G1 X145.806 Y152.952 E.01159
G1 X152.952 Y145.806 E.31063
G1 X153.219 Y146.072 E.01159
G1 X146.072 Y153.219 E.31063
G1 X146.339 Y153.486 E.01159
G1 X153.486 Y146.339 E.31063
G1 X153.752 Y146.606 E.01159
G1 X146.606 Y153.752 E.31063
G1 X146.872 Y154.019 E.01159
G1 X154.019 Y146.872 E.31063
G1 X154.286 Y147.139 E.01159
G1 X147.139 Y154.286 E.31063
G1 X147.406 Y154.552 E.01159
G1 X154.552 Y147.406 E.31063
G1 X154.819 Y147.672 E.01159
G1 X147.672 Y154.819 E.31063
G1 X147.939 Y155.086 E.01159
G1 X155.086 Y147.939 E.31063
G1 X155.352 Y148.206 E.01159
G1 X148.206 Y155.353 E.31063
G1 X148.473 Y155.619 E.01159
G1 X155.619 Y148.473 E.31063
G1 X155.886 Y148.739 E.01159
G1 X148.739 Y155.886 E.31063
G1 X149.006 Y156.153 E.01159
G1 X156.153 Y149.006 E.31063
G1 X156.166 Y149.02 E.0006
G1 X158.997 Y146.19 E.12302
G1 X159.25 Y146.442 E.01099
G1 X146.442 Y159.25 E.55667
G1 X146.709 Y159.516 E.01159
G1 X159.516 Y146.709 E.55667
G1 X159.783 Y146.976 E.01159
G1 X146.976 Y159.783 E.55667
G1 X146.988 Y159.795 E.00054
G1 X152.639 Y154.145 E.24561
G1 X152.893 Y154.399 E.01106
G1 X154.399 Y152.893 E.06544
G1 X154.666 Y153.16 E.01159
G1 X153.16 Y154.666 E.06544
G1 X153.427 Y154.932 E.01159
G1 X154.932 Y153.427 E.06544
G1 X155.199 Y153.693 E.01159
G1 X153.693 Y155.199 E.06544
G1 X153.96 Y155.466 E.01159
G1 X155.466 Y153.96 E.06544
G1 X155.732 Y154.227 E.01159
G1 X154.227 Y155.732 E.06544
G1 X154.493 Y155.999 E.01159
G1 X155.999 Y154.493 E.06544
G1 X156.266 Y154.76 E.01159
G1 X154.64 Y156.386 E.07066
; CHANGE_LAYER
; Z_HEIGHT: 0.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X156.054 Y154.972 E-.76
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
G1 X133.868 Y127.36
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X127.36 Y133.868 E.30532
G1 X124.246 Y130.754 E.14609
G1 X126.439 Y128.56 E.1029
G1 X130.754 Y124.246 E.20242
G1 X133.826 Y127.317 E.1441
G1 X133.314 Y127.36 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.36 Y133.314 E.25872
G1 X124.8 Y130.754 E.11123
G1 X126.716 Y128.838 E.08327
G1 X130.754 Y124.8 E.17545
G1 X133.271 Y127.317 E.10939
; WIPE_START
M204 S10000
G1 X131.867 Y128.742 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X124.34 Y127.477 Z1 F36000
G1 X120.289 Y126.797 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X117.175 Y123.683 E.14609
G1 X119.368 Y121.489 E.1029
G1 X123.683 Y117.175 E.20242
G1 X126.797 Y120.289 E.14609
G1 X120.331 Y126.755 E.30333
G1 X120.289 Y126.243 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X117.729 Y123.683 E.11123
G1 X119.645 Y121.767 E.08327
G1 X123.683 Y117.729 E.17545
G1 X126.243 Y120.289 E.11123
G1 X120.331 Y126.2 E.25688
; WIPE_START
M204 S10000
G1 X118.894 Y124.81 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X116.054 Y117.725 Z1 F36000
G1 X114.07 Y112.776 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X114.346 Y112.684 E.00964
G3 X114.766 Y112.618 I.568 J2.23 E.01413
G1 X114.983 Y112.614 E.00719
G3 X114.014 Y112.797 I-.068 J2.3 E.44669
G1 X114.16 Y113.163 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X114.195 Y113.146 E.00119
G3 X114.787 Y113.01 I.72 J1.768 E.01875
G1 X114.976 Y113.006 E.00582
G3 X114.023 Y113.226 I-.061 J1.908 E.33818
G1 X114.105 Y113.188 E.00279
; WIPE_START
M204 S10000
G1 X114.195 Y113.146 E-.03753
G1 X114.448 Y113.063 E-.10122
G1 X114.787 Y113.01 E-.13038
G1 X114.976 Y113.006 E-.07199
G1 X115.241 Y113.034 E-.1012
G1 X115.573 Y113.122 E-.13045
G1 X115.747 Y113.196 E-.07196
G1 X115.978 Y113.329 E-.10123
G1 X116.007 Y113.352 E-.01403
; WIPE_END
G1 E-.04 F1800
G1 X120.74 Y119.34 Z1 F36000
G1 X133.84 Y135.913 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.841 Y135.876 E.00125
G3 X135.979 Y133.831 I2.287 J.252 E.1066
G1 X136.196 Y133.827 E.00719
G3 X133.833 Y136.3 I-.068 J2.3 E.35174
G1 X133.839 Y135.973 E.01085
G1 X134.231 Y135.915 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.277 Y135.661 E.00792
G3 X136 Y134.223 I1.851 J.467 E.07372
G1 X136.189 Y134.22 E.00582
G3 X134.225 Y135.974 I-.061 J1.908 E.27927
; WIPE_START
M204 S10000
G1 X134.277 Y135.661 E-.12061
G1 X134.332 Y135.48 E-.07201
G1 X134.44 Y135.236 E-.1012
G1 X134.627 Y134.948 E-.13041
G1 X134.751 Y134.805 E-.072
G1 X134.948 Y134.627 E-.10124
G1 X135.236 Y134.44 E-.13042
G1 X135.314 Y134.405 E-.03211
; WIPE_END
G1 E-.04 F1800
G1 X129.471 Y129.495 Z1 F36000
G1 X98.578 Y103.53 Z1
G1 Z.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X101.268 Y106.22 E.12619
G1 X102.171 Y105.317 E.04238
G1 X102.701 Y105.847 E.02488
G1 X105.847 Y102.701 E.14757
G1 X105.317 Y102.171 E.02488
G1 X106.22 Y101.268 E.04239
G1 X103.53 Y98.578 E.12619
G1 X102.627 Y99.481 E.04238
G1 X101.109 Y97.964 E.07118
G1 X103.338 Y95.736 E.10452
G1 X112.919 Y105.317 E.44948
G1 X114.338 Y103.898 E.06656
G1 X147.145 Y136.705 E1.53904
G1 X145.726 Y138.124 E.06656
G1 X156.158 Y148.557 E.48942
G1 X158.993 Y145.722 E.13296
G1 X160.263 Y146.992 E.05957
G1 X154.616 Y152.639 E.2649
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X146.992 Y160.263 E.2649
G1 X145.722 Y158.993 E.05957
G1 X148.557 Y156.158 E.13296
G1 X138.124 Y145.726 E.48942
G1 X136.705 Y147.145 E.06656
G1 X103.898 Y114.338 E1.53904
G1 X105.317 Y112.919 E.06656
G1 X95.736 Y103.338 E.44948
G1 X97.964 Y101.109 E.10452
G1 X99.481 Y102.627 E.07118
G1 X98.62 Y103.488 E.04039
G1 X99.132 Y103.53 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X101.268 Y105.666 E.0928
G1 X102.166 Y104.767 E.03906
G1 X102.171 Y104.762 E.0002
G1 X102.672 Y105.264 E.02179
G1 X102.701 Y105.293 E.00126
G1 X105.293 Y102.701 E.1126
G1 X105.264 Y102.672 E.00126
G1 X104.762 Y102.171 E.02179
G1 X104.767 Y102.166 E.0002
G1 X105.666 Y101.268 E.03906
G1 X103.53 Y99.132 E.0928
G1 X102.632 Y100.031 E.03906
G1 X102.627 Y100.036 E.0002
G1 X100.555 Y97.964 E.09003
G1 X100.56 Y97.959 E.0002
G1 X103.338 Y95.181 E.12071
G1 X112.919 Y104.763 E.41635
G1 X114.338 Y103.344 E.06166
G1 X147.699 Y136.705 E1.44971
G1 X146.28 Y138.124 E.06166
G1 X156.158 Y148.002 E.42926
G1 X158.993 Y145.168 E.12316
G1 X160.817 Y146.992 E.07928
G1 X155.17 Y152.639 E.24538
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X146.992 Y160.817 E.24538
G1 X145.168 Y158.993 E.07928
G1 X148.002 Y156.158 E.12316
G1 X138.124 Y146.28 E.42926
G1 X136.705 Y147.699 E.06166
G1 X103.344 Y114.338 E1.44971
G1 X104.763 Y112.919 E.06166
G1 X95.181 Y103.338 E.41635
G1 X97.959 Y100.56 E.12071
G1 X97.964 Y100.555 E.0002
G1 X100.036 Y102.627 E.09003
G1 X100.031 Y102.632 E.0002
G1 X99.175 Y103.488 E.03721
M204 S10000
G1 X99.072 Y102.805 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42001
G1 F15000
G1 X97.906 Y101.639 E.05067
G1 X97.639 Y101.905 E.01159
G1 X98.685 Y102.951 E.04546
G1 X98.419 Y103.218 E.01159
G1 X97.253 Y102.052 E.05067
; WIPE_START
G1 X98.419 Y103.218 E-.62663
G1 X98.667 Y102.97 E-.13337
; WIPE_END
G1 E-.04 F1800
G1 X101.993 Y105.726 Z1 F36000
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X118.327 Y122.059 E.70979
G1 X118.06 Y122.326 E.01159
G1 X101.847 Y106.113 E.70457
G1 X101.58 Y106.379 E.01159
G1 X117.793 Y122.593 E.70457
G1 X117.527 Y122.859 E.01159
G1 X97.106 Y102.439 E.88741
G1 X96.839 Y102.705 E.01159
G1 X117.26 Y123.126 E.88741
G1 X116.993 Y123.393 E.01159
G1 X96.573 Y102.972 E.88741
G1 X96.306 Y103.239 E.01159
G1 X149.925 Y156.858 E2.33009
G1 X150.192 Y156.591 E.01159
G1 X127.65 Y134.049 E.97959
G1 X127.917 Y133.783 E.01159
G1 X150.459 Y156.325 E.97959
G1 X150.725 Y156.058 E.01159
M73 P51 R9
G1 X128.183 Y133.516 E.97959
G1 X128.45 Y133.249 E.01159
G1 X150.992 Y155.791 E.97959
G1 X151.259 Y155.525 E.01159
G1 X128.717 Y132.983 E.97959
G1 X128.983 Y132.716 E.01159
G1 X151.645 Y155.378 E.9848
G1 X149.779 Y157.245 F36000
G1 F15000
G1 X148.86 Y156.326 E.03992
G1 X148.594 Y156.593 E.01159
G1 X149.392 Y157.391 E.0347
G1 X149.126 Y157.658 E.01159
G1 X148.327 Y156.859 E.0347
G1 X148.06 Y157.126 E.01159
G1 X148.859 Y157.925 E.0347
G1 X148.592 Y158.191 E.01159
G1 X147.794 Y157.393 E.0347
G1 X147.527 Y157.659 E.01159
G1 X148.326 Y158.458 E.0347
G1 X148.059 Y158.724 E.01159
G1 X147.26 Y157.926 E.0347
G1 X146.994 Y158.193 E.01159
G1 X147.792 Y158.991 E.0347
G1 X147.526 Y159.258 E.01159
G1 X146.727 Y158.459 E.0347
G1 X146.46 Y158.726 E.01159
G1 X147.259 Y159.524 E.0347
G1 X146.992 Y159.791 E.01159
G1 X146.074 Y158.872 E.03992
; WIPE_START
G1 X146.992 Y159.791 E-.49363
G1 X147.259 Y159.524 E-.1433
G1 X147.03 Y159.295 E-.12308
; WIPE_END
G1 E-.04 F1800
G1 X142.866 Y152.899 Z1 F36000
G1 X138.076 Y145.542 Z1
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X105.621 Y113.086 E1.41039
G1 X105.354 Y113.353 E.01159
G1 X137.69 Y145.689 E1.40517
G1 X137.423 Y145.955 E.01159
G1 X105.087 Y113.62 E1.40517
G1 X104.821 Y113.886 E.01159
G1 X137.156 Y146.222 E1.40517
G1 X136.89 Y146.489 E.01159
G1 X104.434 Y114.033 E1.41039
; WIPE_START
G1 X105.848 Y115.447 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.031 Y108.034 Z1 F36000
G1 X101.519 Y97.786 Z1
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X102.685 Y98.952 E.05067
G1 X102.952 Y98.685 E.01159
G1 X101.906 Y97.639 E.04546
G1 X102.172 Y97.372 E.01159
G1 X103.338 Y98.538 E.05067
; WIPE_START
G1 X102.172 Y97.372 E-.62662
G1 X101.924 Y97.621 E-.13338
; WIPE_END
G1 E-.04 F1800
G1 X108.576 Y101.363 Z1 F36000
G1 X114.033 Y104.434 Z1
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X146.489 Y136.889 E1.41039
G1 X146.222 Y137.156 E.01159
G1 X113.887 Y104.821 E1.40517
G1 X113.62 Y105.087 E.01159
G1 X145.955 Y137.423 E1.40517
G1 X145.689 Y137.689 E.01159
G1 X113.353 Y105.354 E1.40517
G1 X113.087 Y105.62 E.01159
M73 P51 R8
G1 X145.422 Y137.956 E1.40517
G1 X145.254 Y138.124 E.00729
G1 X156.158 Y149.028 E.47385
G1 X156.326 Y148.86 E.00729
G1 X157.125 Y149.659 E.0347
G1 X157.391 Y149.392 E.01159
G1 X156.593 Y148.593 E.0347
G1 X156.86 Y148.327 E.01159
G1 X157.658 Y149.125 E.0347
G1 X157.925 Y148.859 E.01159
G1 X157.126 Y148.06 E.0347
G1 X157.393 Y147.793 E.01159
G1 X158.191 Y148.592 E.0347
G1 X158.458 Y148.325 E.01159
G1 X157.659 Y147.527 E.0347
G1 X157.926 Y147.26 E.01159
G1 X158.725 Y148.059 E.0347
G1 X158.991 Y147.792 E.01159
G1 X158.193 Y146.994 E.0347
G1 X158.459 Y146.727 E.01159
G1 X159.258 Y147.525 E.0347
G1 X159.525 Y147.259 E.01159
G1 X158.726 Y146.46 E.0347
G1 X158.993 Y146.194 E.01159
G1 X159.911 Y147.112 E.03992
; WIPE_START
G1 X158.993 Y146.194 E-.49363
G1 X158.726 Y146.46 E-.1433
G1 X158.955 Y146.689 E-.12307
; WIPE_END
G1 E-.04 F1800
G1 X152.17 Y143.194 Z1 F36000
G1 X120.459 Y126.858 Z1
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X124.065 Y130.464 E.15668
G1 X124.331 Y130.197 E.01159
G1 X120.846 Y126.711 E.15147
G1 X121.112 Y126.445 E.01159
G1 X124.598 Y129.93 E.15147
G1 X124.864 Y129.664 E.01159
G1 X121.379 Y126.178 E.15147
G1 X121.646 Y125.912 E.01159
G1 X125.131 Y129.397 E.15147
G1 X125.398 Y129.13 E.01159
G1 X121.912 Y125.645 E.15147
G1 X122.179 Y125.378 E.01159
G1 X125.664 Y128.864 E.15147
G1 X125.931 Y128.597 E.01159
G1 X122.445 Y125.112 E.15147
G1 X122.712 Y124.845 E.01159
G1 X126.198 Y128.331 E.15147
G1 X126.464 Y128.064 E.01159
G1 X122.979 Y124.578 E.15147
G1 X123.245 Y124.312 E.01159
G1 X126.731 Y127.797 E.15147
G1 X126.998 Y127.531 E.01159
G1 X123.512 Y124.045 E.15147
G1 X123.779 Y123.778 E.01159
G1 X127.264 Y127.264 E.15147
G1 X127.531 Y126.997 E.01159
G1 X124.045 Y123.512 E.15147
G1 X124.312 Y123.245 E.01159
G1 X127.798 Y126.731 E.15147
G1 X128.064 Y126.464 E.01159
G1 X124.579 Y122.978 E.15147
G1 X124.845 Y122.712 E.01159
G1 X128.331 Y126.197 E.15147
G1 X128.597 Y125.931 E.01159
G1 X125.112 Y122.445 E.15147
G1 X125.379 Y122.179 E.01159
G1 X128.864 Y125.664 E.15147
G1 X129.131 Y125.397 E.01159
G1 X125.645 Y121.912 E.15147
G1 X125.912 Y121.645 E.01159
G1 X129.397 Y125.131 E.15147
G1 X129.664 Y124.864 E.01159
G1 X126.178 Y121.379 E.15147
G1 X126.445 Y121.112 E.01159
G1 X129.931 Y124.598 E.15147
G1 X130.197 Y124.331 E.01159
G1 X126.712 Y120.845 E.15147
G1 X126.978 Y120.579 E.01159
G1 X130.584 Y124.184 E.15668
; WIPE_START
G1 X129.17 Y122.77 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X132.33 Y129.13 Z1 F36000
G1 Z.6
G1 E.8 F1800
G1 F15000
G1 X136.787 Y133.587 E.19369
G2 X136.161 Y133.495 I-.721 J2.719 E.01947
G1 X132.183 Y129.516 E.17288
G1 X131.916 Y129.783 E.01159
G1 X135.675 Y133.542 E.16335
G2 X135.249 Y133.649 I.115 J1.354 E.01356
G1 X131.65 Y130.05 E.15643
G1 X131.383 Y130.316 E.01159
G1 X134.877 Y133.81 E.15184
G1 X134.554 Y134.02 E.01185
G1 X131.116 Y130.583 E.14938
G1 X130.85 Y130.85 E.01159
G1 X134.267 Y134.267 E.14849
G2 X134.02 Y134.553 I.752 J.895 E.01167
G1 X130.583 Y131.116 E.14937
G1 X130.316 Y131.383 E.01159
G1 X133.81 Y134.877 E.15184
G2 X133.649 Y135.249 I2.295 J1.215 E.01247
G1 X130.05 Y131.649 E.15642
G1 X129.783 Y131.916 E.01159
G1 X133.539 Y135.672 E.1632
G2 X133.502 Y136.168 I1.498 J.361 E.01537
G1 X129.517 Y132.183 E.17319
G1 X129.25 Y132.449 E.01159
G1 X133.576 Y136.776 E.18801
G2 X135.478 Y138.677 I2.547 J-.646 E.08673
G1 X151.792 Y154.991 E.70895
G1 X152.059 Y154.725 E.01159
G1 X136.088 Y138.754 E.69401
G2 X136.589 Y138.722 I.152 J-1.547 E.01549
G1 X152.325 Y154.458 E.68382
G1 X152.592 Y154.192 E.01159
G1 X137.009 Y138.609 E.67715
G2 X137.373 Y138.439 I-.422 J-1.377 E.01237
G1 X154.98 Y156.046 E.76513
G1 X155.247 Y155.78 E.01159
G1 X137.704 Y138.237 E.76235
G2 X137.988 Y137.987 I-.919 J-1.334 E.01164
G1 X155.513 Y155.513 E.76159
G1 X155.78 Y155.246 E.01159
G1 X138.232 Y137.698 E.76258
G2 X138.445 Y137.378 I-1.031 J-.917 E.01186
G1 X156.046 Y154.98 E.7649
G1 X156.266 Y154.76 E.00954
G1 X154.145 Y152.639 E.09218
G1 X154.192 Y152.592 E.00205
G1 X138.609 Y137.008 E.67718
G1 X138.717 Y136.583 E.01348
G1 X154.458 Y152.325 E.68407
G1 X154.725 Y152.058 E.01159
G1 X138.762 Y136.095 E.69369
G2 X138.677 Y135.477 I-2.242 J-.007 E.01924
G1 X154.992 Y151.792 E.70897
G1 X155.258 Y151.525 E.01159
G1 X132.716 Y128.983 E.97959
G1 X132.983 Y128.716 E.01159
G1 X155.525 Y151.258 E.97959
G1 X155.792 Y150.992 E.01159
G1 X133.25 Y128.45 E.97959
G1 X133.516 Y128.183 E.01159
G1 X156.058 Y150.725 E.97959
G1 X156.325 Y150.459 E.01159
G1 X133.783 Y127.916 E.97959
G1 X134.049 Y127.65 E.01159
G1 X156.712 Y150.312 E.9848
G1 X156.978 Y150.045 F36000
G1 F15000
G1 X103.239 Y96.306 E2.3353
G1 X102.972 Y96.572 E.01159
G1 X123.393 Y116.993 E.88741
G1 X123.126 Y117.26 E.01159
G1 X102.705 Y96.839 E.88741
G1 X102.439 Y97.106 E.01159
G1 X122.86 Y117.526 E.88741
G1 X122.593 Y117.793 E.01159
G1 X106.379 Y101.58 E.70457
G1 X106.113 Y101.846 E.01159
G1 X122.326 Y118.06 E.70457
G1 X122.06 Y118.326 E.01159
G1 X105.846 Y102.113 E.70457
G1 X105.788 Y102.171 E.00253
G1 X106.318 Y102.701 E.02305
G1 X106.11 Y102.91 E.00906
G1 X115.574 Y112.374 E.41126
G2 X114.952 Y112.286 I-.6 J2 E.01936
M73 P52 R8
G1 X105.843 Y103.177 E.39584
G1 X105.577 Y103.443 E.01159
G1 X114.462 Y112.329 E.38613
G2 X114.036 Y112.436 I.115 J1.355 E.01356
G1 X105.31 Y103.71 E.3792
G1 X105.043 Y103.976 E.01159
G1 X113.664 Y112.597 E.37462
G1 X113.339 Y112.806 E.01186
G1 X104.777 Y104.243 E.37211
G1 X104.51 Y104.51 E.01159
G1 X113.054 Y113.054 E.37129
G2 X112.807 Y113.34 I1.662 J1.691 E.01163
G1 X104.243 Y104.776 E.37212
G1 X103.977 Y105.043 E.01159
G1 X112.599 Y113.666 E.3747
G2 X112.438 Y114.038 I1.055 J.678 E.01251
G1 X103.71 Y105.31 E.37928
G1 X103.443 Y105.576 E.01159
G1 X112.324 Y114.456 E.3859
G2 X112.281 Y114.948 I2.063 J.424 E.01518
G1 X103.177 Y105.843 E.39565
G1 X102.91 Y106.11 E.01159
G1 X112.363 Y115.563 E.41079
G2 X114.264 Y117.464 I2.563 J-.661 E.08666
G1 X118.593 Y121.793 E.18811
G1 X118.86 Y121.526 E.01159
G1 X114.875 Y117.541 E.17317
G2 X115.376 Y117.509 I.152 J-1.545 E.01549
G1 X119.127 Y121.259 E.16298
G1 X119.393 Y120.993 E.01159
G1 X115.791 Y117.39 E.15656
G2 X116.164 Y117.23 I-.302 J-1.218 E.01253
G1 X119.66 Y120.726 E.15193
G1 X119.927 Y120.46 E.01159
G1 X116.49 Y117.023 E.14932
G2 X116.774 Y116.774 I-.919 J-1.334 E.01164
G1 X120.193 Y120.193 E.14856
G1 X120.46 Y119.926 E.01159
G1 X117.018 Y116.485 E.14955
G2 X117.229 Y116.162 I-.879 J-.805 E.01189
G1 X120.726 Y119.66 E.15198
G1 X120.993 Y119.393 E.01159
G1 X117.396 Y115.796 E.15632
G2 X117.509 Y115.376 I-5.97 J-1.838 E.01337
G1 X121.26 Y119.126 E.16297
G1 X121.526 Y118.86 E.01159
G1 X117.549 Y114.882 E.17284
G2 X117.468 Y114.268 I-3.096 J.094 E.01905
G1 X121.913 Y118.713 E.19314
; CHANGE_LAYER
; Z_HEIGHT: 0.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X120.499 Y117.299 E-.76
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
G1 X133.868 Y127.36
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X127.36 Y133.868 E.30532
G1 X124.246 Y130.754 E.14609
G1 X127.146 Y127.853 E.13607
G1 X130.754 Y124.246 E.16924
G1 X133.826 Y127.317 E.1441
G1 X133.314 Y127.36 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.36 Y133.314 E.25872
G1 X124.8 Y130.754 E.11123
G1 X127.423 Y128.131 E.114
G1 X130.754 Y124.8 E.14472
G1 X133.271 Y127.317 E.10939
; WIPE_START
M204 S10000
G1 X131.867 Y128.742 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X124.34 Y127.477 Z1.2 F36000
G1 X120.289 Y126.797 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X117.175 Y123.683 E.14609
G1 X120.075 Y120.782 E.13607
G1 X123.683 Y117.175 E.16925
G1 X126.797 Y120.289 E.14609
G1 X120.331 Y126.755 E.30333
G1 X120.289 Y126.243 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X117.729 Y123.683 E.11123
G1 X120.352 Y121.059 E.114
G1 X123.683 Y117.729 E.14473
G1 X126.243 Y120.289 E.11123
G1 X120.331 Y126.2 E.25688
; WIPE_START
M204 S10000
G1 X118.894 Y124.81 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X115.907 Y117.786 Z1.2 F36000
G1 X113.826 Y112.891 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X113.856 Y112.871 E.00117
G3 X114.779 Y112.617 I1.059 J2.043 E.03198
G1 X114.971 Y112.614 E.00636
G3 X113.478 Y113.116 I-.056 J2.3 E.42628
G1 X113.776 Y112.923 E.01177
G1 X114.141 Y113.18 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X114.436 Y113.067 E.00971
G3 X114.799 Y113.009 I.479 J1.848 E.01132
G1 X114.964 Y113.006 E.00505
G3 X114.034 Y113.221 I-.049 J1.908 E.3389
G1 X114.085 Y113.201 E.00167
; WIPE_START
M204 S10000
G1 X114.436 Y113.067 E-.14287
G1 X114.799 Y113.009 E-.13982
G1 X114.964 Y113.006 E-.06251
G1 X115.329 Y113.051 E-.13986
G1 X115.736 Y113.191 E-.16343
G1 X115.987 Y113.342 E-.11151
; WIPE_END
G1 E-.04 F1800
G1 X120.725 Y119.326 Z1.2 F36000
G1 X133.841 Y135.889 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.842 Y135.863 E.00086
G3 X135.992 Y133.831 I2.286 J.264 E.10659
G1 X136.184 Y133.827 E.00636
G3 X133.828 Y136.184 I-.056 J2.3 E.35598
G1 X133.838 Y135.949 E.0078
G1 X134.233 Y135.903 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.328 Y135.492 E.01297
G3 X136.012 Y134.222 I1.8 J.636 E.06865
G1 X136.177 Y134.219 E.00505
G3 X134.226 Y135.962 I-.049 J1.908 E.27997
; WIPE_START
M204 S10000
G1 X134.328 Y135.492 E-.18303
G1 X134.484 Y135.158 E-.13985
G1 X134.742 Y134.815 E-.16342
G1 X135.02 Y134.573 E-.13987
G1 X135.328 Y134.402 E-.13383
; WIPE_END
G1 E-.04 F1800
G1 X129.484 Y129.493 Z1.2 F36000
G1 X98.578 Y103.53 Z1.2
G1 Z.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X101.268 Y106.22 E.12619
G1 X102.224 Y105.264 E.04487
G1 X102.754 Y105.794 E.02488
G1 X105.794 Y102.754 E.14261
G1 X105.264 Y102.224 E.02488
G1 X106.22 Y101.268 E.04487
G1 X103.53 Y98.578 E.12619
G1 X102.574 Y99.534 E.04487
G1 X101.057 Y98.017 E.07118
G1 X103.322 Y95.752 E.10626
G1 X104.983 Y97.413 E.07794
G1 X112.903 Y105.333 E.37154
G1 X114.325 Y103.911 E.0667
G1 X147.131 Y136.718 E1.53904
G1 X145.71 Y138.14 E.0667
G1 X156.142 Y148.573 E.48942
G1 X158.983 Y145.732 E.13328
G1 X160.253 Y147.001 E.05957
G1 X154.616 Y152.639 E.26447
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.001 Y160.253 E.26447
G1 X145.732 Y158.983 E.05957
G1 X148.572 Y156.143 E.13328
G1 X138.14 Y145.71 E.48942
G1 X136.718 Y147.131 E.0667
G1 X103.911 Y114.325 E1.53904
G1 X105.333 Y112.903 E.0667
G1 X95.752 Y103.322 E.44948
G1 X98.017 Y101.057 E.10626
G1 X99.534 Y102.574 E.07118
G1 X98.62 Y103.488 E.04287
G1 X99.132 Y103.53 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X101.268 Y105.666 E.0928
G1 X102.2 Y104.733 E.04052
G1 X102.224 Y104.709 E.00104
G1 X102.725 Y105.211 E.02179
G1 X102.754 Y105.24 E.00126
G1 X105.24 Y102.754 E.10801
G1 X105.211 Y102.725 E.00126
G1 X104.709 Y102.224 E.02179
G1 X104.733 Y102.2 E.00104
G1 X105.666 Y101.268 E.04052
G1 X103.53 Y99.132 E.0928
G1 X102.598 Y100.065 E.04052
G1 X102.574 Y100.088 E.00104
G1 X100.502 Y98.017 E.09003
G1 X100.526 Y97.993 E.00104
G1 X103.322 Y95.197 E.12148
G1 X105.26 Y97.136 E.08424
G1 X112.903 Y104.778 E.33211
G1 X114.325 Y103.357 E.06178
G1 X145.363 Y134.395 E1.34875
G1 X147.686 Y136.718 E.10096
G1 X146.264 Y138.14 E.06178
G1 X156.142 Y148.018 E.42926
G1 X158.983 Y145.177 E.12345
G1 X160.808 Y147.001 E.07928
G1 X155.17 Y152.639 E.24498
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.001 Y160.808 E.24498
G1 X145.177 Y158.983 E.07928
G1 X148.018 Y156.143 E.12345
G1 X138.14 Y146.264 E.42926
G1 X136.718 Y147.686 E.06178
G1 X103.357 Y114.325 E1.44971
G1 X104.778 Y112.903 E.06178
G1 X95.197 Y103.322 E.41635
G1 X97.993 Y100.526 E.12148
G1 X98.017 Y100.502 E.00104
G1 X100.088 Y102.574 E.09003
G1 X100.065 Y102.598 E.00104
G1 X99.175 Y103.488 E.03868
; WIPE_START
M204 S10000
G1 X100.56 Y104.93 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X99.559 Y105.004 Z1.2 F36000
G1 Z.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X98.408 Y103.853 E.05401
G1 X97.592 Y104.669 E.03829
G1 X101.43 Y108.507 E.18005
G1 X108.507 Y101.43 E.33202
G1 X104.669 Y97.592 E.18005
G1 X103.853 Y98.408 E.03829
G1 X106.713 Y101.268 E.13416
G1 X105.756 Y102.224 E.04487
G1 X106.287 Y102.754 E.02488
G1 X104.52 Y104.521 E.08286
G1 X113.043 Y113.043 E.39983
G3 X117.505 Y115.459 I1.87 J1.875 E.22491
G1 X121.443 Y111.522 E.18472
G1 X117.605 Y107.684 E.18005
G1 X107.684 Y117.605 E.46541
G1 X111.522 Y121.443 E.18005
G1 X115.463 Y117.501 E.18489
G2 X116.787 Y116.787 I-.568 J-2.636 E.05058
G1 X120.182 Y120.182 E.15929
G1 X116.682 Y123.683 E.16421
G1 X116.82 Y123.821 E.00647
G1 X115.36 Y125.281 E.06849
G1 X119.198 Y129.119 E.18005
G1 X129.119 Y119.198 E.46541
G1 X125.281 Y115.36 E.18005
G1 X123.821 Y116.82 E.06849
G1 X127.29 Y120.289 E.16273
G1 X123.789 Y123.789 E.16421
G1 X127.253 Y127.254 E.16252
G1 X123.753 Y130.754 E.16421
G1 X124.496 Y131.497 E.03484
G1 X123.036 Y132.957 E.06849
G1 X121.884 Y131.805 E.05401
; WIPE_START
G1 X123.036 Y132.957 E-.61876
G1 X123.299 Y132.694 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X129.296 Y127.974 Z1.2 F36000
G1 X134.108 Y124.187 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G1 X132.957 Y123.036 E.05401
G1 X131.497 Y124.496 E.06849
G1 X134.361 Y127.36 E.13436
G1 X130.86 Y130.86 E.16421
G1 X134.258 Y134.258 E.15937
G3 X137.486 Y133.858 I1.877 J1.926 E.1159
G1 X140.633 Y130.712 E.1476
G1 X136.795 Y126.874 E.18005
G1 X126.874 Y136.795 E.46541
G1 X130.712 Y140.633 E.18005
G1 X133.856 Y137.488 E.14752
G2 X137.994 Y137.994 I2.275 J-1.437 E.15816
G1 X155.502 Y155.502 E.82137
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X156.142 Y149.065 E.01404
G1 X154.563 Y147.485 E.07411
G1 X147.485 Y154.563 E.33202
G1 X149.065 Y156.143 E.07411
G1 X148.766 Y156.442 E.01404
G1 X149.543 Y157.219 E.03647
G1 X148.392 Y158.37 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X144.116 Y151.336 Z1.2 F36000
G1 X142.496 Y149.573 Z1.2
G1 Z.8
G1 E.8 F1800
G1 F15476.087
G1 X143.647 Y150.725 E.05401
G1 X150.725 Y143.647 E.33202
G1 X146.887 Y139.809 E.18005
G1 X139.809 Y146.887 E.33202
G1 X138.14 Y145.217 E.07832
G1 X137.841 Y145.516 E.01404
G1 X105.526 Y113.202 E1.51593
G1 X105.825 Y112.903 E.01404
G1 X105.268 Y112.345 E.02617
G1 X112.345 Y105.268 E.33202
M73 P53 R8
G1 X112.903 Y105.825 E.02617
G1 X113.202 Y105.526 E.01404
G1 X145.516 Y137.841 E1.51593
G1 X146.639 Y136.718 E.05266
G1 X144.471 Y134.55 E.10172
G1 X134.55 Y144.471 E.46541
G1 X133.398 Y143.319 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X134.55 Y144.471 E-.61876
G1 X134.812 Y144.208 E-.14124
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
G1 X133.868 Y127.36
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.36 Y133.868 E.30532
G1 X124.246 Y130.754 E.14609
G1 X130.754 Y124.246 E.30532
G1 X133.826 Y127.317 E.1441
G1 X133.314 Y127.36 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.36 Y133.314 E.25872
G1 X124.8 Y130.754 E.11123
G1 X130.754 Y124.8 E.25872
G1 X133.271 Y127.317 E.10939
; WIPE_START
M204 S10000
G1 X131.867 Y128.742 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X124.34 Y127.477 Z1.4 F36000
G1 X120.289 Y126.797 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X117.175 Y123.683 E.14609
G1 X120.782 Y120.075 E.16925
G1 X123.683 Y117.175 E.13607
G1 X126.797 Y120.289 E.14609
G1 X120.331 Y126.755 E.30333
G1 X120.289 Y126.243 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X117.729 Y123.683 E.11123
G1 X121.059 Y120.352 E.14473
G1 X123.683 Y117.729 E.114
G1 X126.243 Y120.289 E.11123
G1 X120.331 Y126.2 E.25688
; WIPE_START
M204 S10000
G1 X118.894 Y124.81 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X115.914 Y117.783 Z1.4 F36000
G1 X113.838 Y112.885 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X113.867 Y112.866 E.00118
G3 X114.791 Y112.617 I1.048 J2.048 E.03197
G1 X114.958 Y112.614 E.00553
G3 X113.469 Y113.124 I-.043 J2.3 E.42624
G1 X113.787 Y112.918 E.01259
G1 X114.128 Y113.184 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X114.424 Y113.07 E.00975
G3 X114.812 Y113.008 I.491 J1.844 E.01209
G1 X114.951 Y113.006 E.00429
G3 X114.045 Y113.215 I-.036 J1.908 E.33962
G1 X114.072 Y113.205 E.00086
; WIPE_START
M204 S10000
G1 X114.424 Y113.07 E-.14335
G1 X114.812 Y113.008 E-.14925
G1 X114.951 Y113.006 E-.05302
G1 X115.341 Y113.054 E-.14931
G1 X115.724 Y113.186 E-.15399
G1 X115.975 Y113.336 E-.11109
; WIPE_END
G1 E-.04 F1800
G1 X120.74 Y119.298 Z1.4 F36000
G1 X133.866 Y135.721 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.87 Y135.686 E.00117
G3 X136.004 Y133.83 I2.258 J.442 E.10104
G1 X136.171 Y133.827 E.00553
G3 X133.828 Y136.171 I-.043 J2.3 E.35676
G1 X133.861 Y135.781 E.013
G1 X134.244 Y135.882 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.255 Y135.761 E.00375
G3 X136.025 Y134.222 I1.873 J.367 E.07761
G1 X136.164 Y134.219 E.00429
G3 X134.22 Y136.164 I-.036 J1.908 E.2741
G1 X134.239 Y135.942 E.00686
; WIPE_START
M204 S10000
G1 X134.255 Y135.761 E-.06918
G1 X134.369 Y135.385 E-.14926
G1 X134.49 Y135.147 E-.10122
G1 X134.734 Y134.824 E-.154
G1 X134.929 Y134.642 E-.10124
G1 X135.258 Y134.428 E-.14928
G1 X135.346 Y134.395 E-.03583
; WIPE_END
G1 E-.04 F1800
G1 X129.501 Y129.487 Z1.4 F36000
G1 X98.578 Y103.53 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X101.268 Y106.22 E.12619
G1 X102.299 Y105.188 E.04841
G1 X102.83 Y105.719 E.02488
G1 X105.719 Y102.83 E.13553
G1 X105.188 Y102.299 E.02488
G1 X106.22 Y101.268 E.04841
G1 X103.53 Y98.578 E.12619
G1 X102.498 Y99.61 E.04841
G1 X100.981 Y98.092 E.07118
G1 X103.305 Y95.768 E.10904
G1 X107.67 Y100.133 E.20477
G1 X112.887 Y105.349 E.24471
G1 X114.311 Y103.925 E.06682
G1 X147.118 Y136.732 E1.53904
G1 X145.693 Y138.156 E.06682
G1 X156.126 Y148.589 E.48942
G1 X158.971 Y145.744 E.13347
G1 X160.241 Y147.014 E.05957
G1 X154.616 Y152.639 E.2639
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.014 Y160.241 E.2639
G1 X145.744 Y158.971 E.05957
G1 X148.589 Y156.126 E.13347
G1 X138.156 Y145.694 E.48942
G1 X136.732 Y147.118 E.06682
G1 X103.925 Y114.311 E1.53904
G1 X105.349 Y112.887 E.06682
G1 X95.768 Y103.305 E.44948
G1 X98.092 Y100.981 E.10904
G1 X99.609 Y102.498 E.07118
G1 X98.62 Y103.488 E.04642
G1 X99.132 Y103.53 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X100.985 Y105.383 E.0805
G1 X101.268 Y105.666 E.01229
G1 F11926.732
G1 X101.687 Y105.246 E.01824
G1 F10003.014
G1 X101.97 Y104.963 E.01229
G1 F8801.873
G1 X102.253 Y104.68 E.01229
G1 F7677.531
G1 X102.299 Y104.634 E.00202
G1 F7500
G1 X102.801 Y105.135 E.02179
G1 F7610.413
G1 X102.83 Y105.164 E.00126
G1 F8729.997
G1 X103.113 Y104.881 E.01229
G1 F9926.381
G1 X103.395 Y104.599 E.01229
G1 F11199.565
G1 X103.678 Y104.316 E.01229
G1 F12000
G1 X103.961 Y104.033 E.01229
G1 X104.316 Y103.678 E.01541
G1 F11199.565
G1 X104.599 Y103.395 E.01229
G1 F9926.381
G1 X104.881 Y103.113 E.01229
G1 F8729.997
G1 X105.164 Y102.83 E.01229
G1 F7610.413
G1 X105.135 Y102.801 E.00126
G1 F7500
G1 X104.634 Y102.299 E.02179
G1 F7677.493
G1 X104.68 Y102.253 E.00202
G1 F8801.832
G1 X104.963 Y101.97 E.01229
G1 F10002.97
G1 X105.246 Y101.687 E.01229
G1 F11926.756
G1 X105.666 Y101.268 E.01824
G1 F12000
G1 X105.383 Y100.985 E.01229
G1 X103.813 Y99.415 E.06821
G1 X103.53 Y99.132 E.01229
G1 F11926.732
G1 X103.111 Y99.552 E.01824
G1 F10002.949
G1 X102.828 Y99.835 E.01229
G1 F8801.811
G1 X102.545 Y100.117 E.01229
G1 F7677.474
G1 X102.498 Y100.164 E.00202
G1 F7500
G1 X100.427 Y98.092 E.09003
G1 F7677.512
G1 X100.473 Y98.046 E.00202
G1 F8801.852
G1 X100.756 Y97.763 E.01229
G1 F10002.992
G1 X101.039 Y97.48 E.01229
G1 F11280.932
G1 X101.322 Y97.197 E.01229
G1 F12000
G1 X101.604 Y96.914 E.01229
G1 X103.305 Y95.213 E.07391
G1 X107.948 Y99.856 E.20172
G1 X112.887 Y104.795 E.21463
G1 X114.311 Y103.37 E.06189
G1 X147.672 Y136.732 E1.44971
G1 X146.248 Y138.156 E.06189
G1 X156.126 Y148.034 E.42926
G1 X158.971 Y145.189 E.12363
G1 X160.796 Y147.014 E.07928
G1 X155.17 Y152.639 E.24445
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.014 Y160.796 E.24445
G1 X145.189 Y158.971 E.07928
G1 X148.034 Y156.126 E.12363
G1 X138.156 Y146.248 E.42926
G1 X136.732 Y147.672 E.06189
G1 X103.37 Y114.311 E1.44971
G1 X104.795 Y112.887 E.06189
G1 X95.213 Y103.305 E.41635
G1 X96.914 Y101.604 E.07391
G1 X97.197 Y101.322 E.01229
G1 F11280.979
G1 X97.48 Y101.039 E.01229
G1 F10003.036
G1 X97.763 Y100.756 E.01229
G1 F8801.893
G1 X98.046 Y100.473 E.01229
G1 F7677.551
G1 X98.092 Y100.427 E.00202
G1 F7500
G1 X100.164 Y102.498 E.09003
G1 F7677.512
G1 X100.117 Y102.545 E.00202
G1 F8801.852
G1 X99.835 Y102.828 E.01229
G1 F10002.992
G1 X99.552 Y103.111 E.01229
G1 F11724.529
G1 X99.175 Y103.488 E.01639
; WIPE_START
M204 S10000
G1 X100.556 Y104.934 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X106.979 Y109.056 Z1.4 F36000
G1 X112.777 Y112.777 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X104.52 Y104.521 E.38733
G1 X106.211 Y102.83 E.07932
G1 X105.681 Y102.299 E.02488
G1 X106.713 Y101.268 E.04841
G1 X103.853 Y98.408 E.13416
G1 X104.653 Y97.608 E.03753
G1 X108.491 Y101.446 E.18005
G1 X101.446 Y108.491 E.33049
G1 X97.608 Y104.653 E.18005
G1 X98.408 Y103.853 E.03753
G1 X99.559 Y105.004 E.05401
; WIPE_START
G1 X98.408 Y103.853 E-.61876
G1 X98.145 Y104.116 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X105.706 Y105.156 Z1.4 F36000
G1 X116.515 Y106.642 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X116.885 Y107.011 E.01447
G1 X117.366 Y107.493 F36000
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X123.089 Y113.216 E.22424
; Slow Down End
G1 X117.575 Y114.932 F36000
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X117.532 Y115.404 E.01312
G3 X116.524 Y117.031 I-2.671 J-.529 E.05418
G1 X116.049 Y117.319 E.01539
G1 X115.521 Y117.503 E.01548
G1 X114.99 Y117.574 E.01485
G1 X114.481 Y117.543 E.01413
G1 X113.942 Y117.394 E.01551
G1 X113.456 Y117.14 E.01518
G1 X113.043 Y116.81 E.01465
G1 X112.764 Y116.485 E.01187
G1 X112.494 Y116.028 E.01469
G1 X112.321 Y115.523 E.01481
G3 X112.407 Y114.031 I2.915 J-.58 E.04185
G1 X112.636 Y113.533 E.01519
G1 X112.955 Y113.11 E.01466
G1 X113.257 Y112.83 E.01142
G1 X113.717 Y112.534 E.01516
G1 X114.244 Y112.337 E.01559
G1 X114.789 Y112.257 E.01524
G1 X115.35 Y112.288 E.01559
G1 X115.88 Y112.437 E.01523
G1 X116.381 Y112.692 E.01559
G1 X116.802 Y113.041 E.01515
G1 X117.14 Y113.45 E.01468
G1 X117.357 Y113.863 E.01293
G1 X117.522 Y114.398 E.01553
G1 X117.569 Y114.872 E.0132
; Slow Down End
; WIPE_START
G1 X117.522 Y114.398 E-.18101
G1 X117.357 Y113.863 E-.21307
G1 X117.14 Y113.45 E-.17729
G1 X116.823 Y113.067 E-.18864
; WIPE_END
G1 E-.04 F1800
G1 X118.82 Y120.434 Z1.4 F36000
G1 X121.898 Y131.792 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X123.049 Y132.943 E.05401
G1 X124.496 Y131.497 E.06785
G1 X123.753 Y130.754 E.03484
G1 X127.253 Y127.254 E.16421
G1 X123.789 Y123.789 E.16252
G1 X127.29 Y120.289 E.16421
G1 X123.821 Y116.82 E.16273
G1 X125.267 Y115.373 E.06785
G1 X129.105 Y119.211 E.18005
G1 X119.211 Y129.105 E.46413
G1 X115.373 Y125.267 E.18005
G1 X116.82 Y123.821 E.06785
G1 X116.682 Y123.683 E.00647
G1 X120.182 Y120.182 E.16421
G1 X117.058 Y117.047 E.14684
G2 X117.93 Y115.034 I-2.241 J-2.168 E.07438
G1 X121.162 Y111.802 E.15162
G1 X117.324 Y107.964 E.18005
G1 X107.697 Y117.591 E.45162
G1 X111.535 Y121.429 E.18005
G1 X115.027 Y117.938 E.16378
G3 X113.464 Y117.559 I-.007 J-3.382 E.05384
; WIPE_START
G1 X113.844 Y117.748 E-.16098
G1 X114.417 Y117.902 E-.2255
G1 X115.027 Y117.938 E-.23218
G1 X114.764 Y118.201 E-.14134
; WIPE_END
G1 E-.04 F1800
G1 X121.8 Y121.159 Z1.4 F36000
G1 X137.729 Y127.855 Z1.4
G1 Z1
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X138.098 Y128.225 E.01447
G1 X138.58 Y128.707 F36000
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X144.303 Y134.43 E.22424
; Slow Down End
G1 X138.782 Y135.965 F36000
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X138.765 Y136.493 E.01463
G1 X138.637 Y137.005 E.01463
G1 X138.398 Y137.515 E.01558
G1 X138.092 Y137.928 E.01424
G1 X137.737 Y138.244 E.01317
G1 X137.263 Y138.533 E.0154
G1 X136.734 Y138.716 E.0155
G1 X136.224 Y138.788 E.01428
G1 X135.698 Y138.757 E.0146
G1 X135.155 Y138.607 E.0156
G1 X134.67 Y138.354 E.01517
G1 X134.256 Y138.024 E.01465
G1 X133.977 Y137.698 E.01188
G1 X133.707 Y137.242 E.01468
G1 X133.529 Y136.708 E.01559
G1 X133.469 Y136.161 E.01523
G1 X133.511 Y135.628 E.01481
G3 X134.47 Y134.043 I2.678 J.537 E.05237
G1 X134.93 Y133.748 E.01516
G1 X135.458 Y133.551 E.01559
G1 X135.999 Y133.472 E.01515
G1 X136.528 Y133.494 E.01468
G1 X136.943 Y133.593 E.01182
G1 X137.428 Y133.81 E.01471
G1 X137.887 Y134.134 E.01557
G1 X138.259 Y134.539 E.01523
G1 X138.532 Y134.989 E.01459
G1 X138.673 Y135.373 E.01135
G1 X138.771 Y135.906 E.01502
; Slow Down End
G1 X149.557 Y142.512 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X150.709 Y143.664 E.05401
G1 X143.664 Y150.709 E.33049
G1 X139.826 Y146.871 E.18005
G1 X146.871 Y139.826 E.33049
G1 X145.201 Y138.156 E.07833
G1 X145.516 Y137.841 E.0148
G1 X113.202 Y105.526 E1.51593
G1 X112.887 Y105.842 E.0148
G1 X112.329 Y105.284 E.02617
G1 X105.284 Y112.329 E.33049
G1 X105.842 Y112.887 E.02617
G1 X105.526 Y113.202 E.0148
G1 X137.841 Y145.516 E1.51593
G1 X136.732 Y146.625 E.05202
G1 X134.563 Y144.457 E.10172
G1 X144.19 Y134.83 E.45162
G1 X140.352 Y130.992 E.18005
G1 X137.756 Y133.589 E.12181
G2 X133.99 Y133.99 I-1.627 J2.603 E.13538
G1 X130.86 Y130.86 E.14683
G1 X134.361 Y127.36 E.16421
G1 X131.497 Y124.496 E.13436
G1 X132.943 Y123.049 E.06785
M73 P54 R8
G1 X136.781 Y126.887 E.18005
G1 X126.887 Y136.781 E.46413
G1 X130.725 Y140.619 E.18005
G1 X133.589 Y137.755 E.13434
G2 X138.265 Y138.265 I2.541 J-1.609 E.17916
G1 X155.502 Y155.502 E.80863
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X156.126 Y149.081 E.0148
G1 X154.547 Y147.502 E.07411
G1 X147.502 Y154.547 E.33049
G1 X149.081 Y156.126 E.07411
G1 X148.766 Y156.442 E.0148
G1 X149.543 Y157.219 E.03647
G1 X148.392 Y158.37 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
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
G1 X133.868 Y127.36
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.36 Y133.868 E.30532
G1 X124.246 Y130.754 E.14609
G1 X128.56 Y126.439 E.20242
G1 X130.754 Y124.246 E.1029
G1 X133.826 Y127.317 E.1441
G1 X133.314 Y127.36 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.36 Y133.314 E.25872
G1 X124.8 Y130.754 E.11123
G1 X128.838 Y126.716 E.17545
G1 X130.754 Y124.8 E.08327
G1 X133.271 Y127.317 E.10939
; WIPE_START
M204 S10000
G1 X131.867 Y128.742 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X124.34 Y127.477 Z1.6 F36000
G1 X120.289 Y126.797 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X117.175 Y123.683 E.14609
G1 X121.489 Y119.368 E.20242
G1 X123.683 Y117.175 E.1029
G1 X126.797 Y120.289 E.14609
G1 X120.331 Y126.755 E.30333
G1 X120.289 Y126.243 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X117.729 Y123.683 E.11123
G1 X121.767 Y119.645 E.17545
G1 X123.683 Y117.729 E.08327
G1 X126.243 Y120.289 E.11123
G1 X120.331 Y126.2 E.25688
; WIPE_START
M204 S10000
G1 X118.894 Y124.81 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X115.959 Y117.764 Z1.6 F36000
G1 X113.911 Y112.847 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X114.31 Y112.694 E.01417
G3 X114.804 Y112.616 I.605 J2.22 E.01661
G1 X114.946 Y112.614 E.00471
G3 X113.856 Y112.871 I-.031 J2.3 E.44199
G1 X114.112 Y113.188 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X114.412 Y113.073 E.00986
G3 X114.824 Y113.008 I.503 J1.841 E.01286
G1 X114.939 Y113.006 E.00352
G3 X114.056 Y113.21 I-.024 J1.908 E.34033
; WIPE_START
M204 S10000
G1 X114.412 Y113.073 E-.14478
G1 X114.824 Y113.008 E-.1587
G1 X114.939 Y113.006 E-.04353
G1 X115.353 Y113.057 E-.15875
G1 X115.713 Y113.181 E-.14455
G1 X115.96 Y113.329 E-.10968
; WIPE_END
G1 E-.04 F1800
G1 X120.708 Y119.305 Z1.6 F36000
G1 X133.854 Y135.851 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.868 Y135.698 E.00509
G3 X136.017 Y133.829 I2.26 J.429 E.10187
G1 X136.159 Y133.827 E.00471
G3 X133.828 Y136.159 I-.031 J2.3 E.35755
G1 X133.849 Y135.911 E.00826
G1 X134.237 Y135.873 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.32 Y135.516 E.01129
G3 X136.037 Y134.221 I1.808 J.612 E.07019
G1 X136.152 Y134.219 E.00352
G3 X134.23 Y135.933 I-.024 J1.908 E.28158
; WIPE_START
M204 S10000
G1 X134.32 Y135.516 E-.16229
G1 X134.496 Y135.137 E-.15872
G1 X134.725 Y134.833 E-.14455
G1 X134.919 Y134.65 E-.10128
G1 X135.27 Y134.423 E-.15872
G1 X135.354 Y134.39 E-.03444
; WIPE_END
G1 E-.04 F1800
G1 X129.507 Y129.484 Z1.6 F36000
G1 X98.578 Y103.53 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X101.268 Y106.22 E.12619
G1 X102.404 Y105.084 E.0533
G1 X102.934 Y105.615 E.02488
G1 X105.615 Y102.934 E.12575
G1 X105.084 Y102.404 E.02488
G1 X106.22 Y101.268 E.0533
G1 X103.53 Y98.578 E.12619
G1 X102.394 Y99.714 E.0533
G1 X100.877 Y98.196 E.07118
G1 X103.279 Y95.795 E.11267
G1 X112.86 Y105.376 E.44948
G1 X114.294 Y103.942 E.06727
G1 X147.101 Y136.749 E1.53904
G1 X145.667 Y138.183 E.06727
G1 X156.099 Y148.616 E.48942
G1 X158.959 Y145.756 E.13415
G1 X160.229 Y147.026 E.05957
G1 X154.616 Y152.639 E.26333
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.026 Y160.229 E.26333
G1 X145.756 Y158.959 E.05957
G1 X148.615 Y156.1 E.13415
G1 X138.183 Y145.667 E.48942
G1 X136.749 Y147.101 E.06727
G1 X103.942 Y114.294 E1.53904
G1 X105.376 Y112.86 E.06727
G1 X95.795 Y103.279 E.44948
G1 X98.196 Y100.877 E.11267
G1 X99.714 Y102.394 E.07118
G1 X98.62 Y103.488 E.05131
G1 X99.132 Y103.53 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.571 Y103.969 E.01905
G1 X99.853 Y104.252 E.01229
G1 F11998.951
G1 X100.136 Y104.534 E.01229
G1 F10679.765
G1 X100.419 Y104.817 E.01229
G1 F9437.38
G1 X100.702 Y105.1 E.01229
G1 F8271.794
G1 X100.985 Y105.383 E.01229
G1 F7183.008
G1 X101.268 Y105.666 E.01229
G1 F6171.023
G1 X101.48 Y105.453 E.00923
G1 F5461.792
G1 X101.763 Y105.171 E.01229
G1 F4584.26
G1 X102.046 Y104.888 E.01229
G1 F3783.528
G1 X102.328 Y104.605 E.01229
G1 F3059.596
G1 X102.404 Y104.53 E.00327
G1 F2880
G1 X102.905 Y105.031 E.02179
G1 F2948.562
G1 X102.934 Y105.06 E.00126
G1 F3659.94
G1 X103.217 Y104.777 E.01229
G1 F4448.117
G1 X103.5 Y104.494 E.01229
G1 F5313.095
G1 X103.782 Y104.212 E.01229
G1 F6020.3
G1 X104.065 Y103.929 E.01229
G1 F5790.246
G1 X104.212 Y103.782 E.00635
G1 F5313.095
G1 X104.494 Y103.5 E.01229
G1 F4448.117
G1 X104.777 Y103.217 E.01229
G1 F3659.94
G1 X105.06 Y102.934 E.01229
G1 F2948.562
G1 X105.031 Y102.905 E.00126
G1 F2880
G1 X104.53 Y102.404 E.02179
G1 F3059.596
G1 X104.605 Y102.328 E.00327
G1 F3783.528
G1 X104.888 Y102.046 E.01229
G1 F4584.26
G1 X105.171 Y101.763 E.01229
G1 F5461.792
G1 X105.453 Y101.48 E.01229
G1 F6171.057
G1 X105.666 Y101.268 E.00923
G1 F7183.045
G1 X105.383 Y100.985 E.01229
G1 F8271.834
G1 X105.1 Y100.702 E.01229
G1 F9437.422
G1 X104.817 Y100.419 E.01229
G1 F10393.502
G1 X104.534 Y100.136 E.01229
G1 F10111.211
G1 X104.379 Y99.981 E.00676
G1 F9437.401
G1 X104.096 Y99.698 E.01229
G1 F8271.814
G1 X103.813 Y99.415 E.01229
G1 F7183.027
G1 X103.53 Y99.132 E.01229
G1 F6171.04
G1 X103.318 Y99.344 E.00923
G1 F5461.808
G1 X103.035 Y99.627 E.01229
G1 F4584.275
G1 X102.752 Y99.91 E.01229
G1 F3783.542
G1 X102.469 Y100.193 E.01229
G1 F3059.609
G1 X102.394 Y100.268 E.00327
G1 F2880
G1 X100.322 Y98.196 E.09003
G1 F3059.584
G1 X100.398 Y98.121 E.00327
G1 F3783.515
G1 X100.68 Y97.838 E.01229
G1 F4584.245
G1 X100.963 Y97.555 E.01229
G1 F5461.776
G1 X101.246 Y97.273 E.01229
G1 F6416.107
G1 X101.529 Y96.99 E.01229
G1 F7447.237
G1 X101.812 Y96.707 E.01229
G1 F8555.168
G1 X102.095 Y96.424 E.01229
G1 F9739.898
G1 X102.378 Y96.141 E.01229
G1 F11001.429
G1 X102.66 Y95.858 E.01229
G1 F12000
G1 X102.943 Y95.576 E.01229
G1 X103.279 Y95.24 E.01458
G1 X112.86 Y104.821 E.41635
G1 X114.294 Y103.388 E.06231
G1 X141.072 Y130.166 E1.16364
G1 X147.655 Y136.749 E.28607
G1 X146.221 Y138.183 E.06231
G1 X156.099 Y148.061 E.42926
G1 X158.959 Y145.201 E.12427
G1 X160.784 Y147.026 E.07928
G1 X155.17 Y152.639 E.24392
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.026 Y160.784 E.24392
G1 X145.201 Y158.959 E.07928
G1 X148.061 Y156.1 E.12427
G1 X138.183 Y146.221 E.42926
G1 X136.749 Y147.655 E.06231
G1 X103.388 Y114.294 E1.44971
G1 X104.821 Y112.86 E.06231
G1 X95.24 Y103.279 E.41635
G1 X95.576 Y102.943 E.01458
G1 X95.858 Y102.66 E.01229
G1 F11001.429
G1 X96.141 Y102.378 E.01229
G1 F9739.898
G1 X96.424 Y102.095 E.01229
G1 F8555.168
G1 X96.707 Y101.812 E.01229
G1 F7447.237
G1 X96.99 Y101.529 E.01229
G1 F6416.107
G1 X97.273 Y101.246 E.01229
G1 F5461.776
G1 X97.555 Y100.963 E.01229
G1 F4584.245
G1 X97.838 Y100.68 E.01229
G1 F3783.515
G1 X98.121 Y100.398 E.01229
G1 F3059.584
G1 X98.196 Y100.322 E.00327
G1 F2880
G1 X100.268 Y102.394 E.09003
G1 F3059.609
G1 X100.193 Y102.469 E.00327
G1 F3783.542
G1 X99.91 Y102.752 E.01229
G1 F4584.275
G1 X99.627 Y103.035 E.01229
G1 F5461.808
G1 X99.344 Y103.318 E.01229
G1 F6025.826
G1 X99.175 Y103.488 E.00738
; WIPE_START
M204 S10000
G1 X99.571 Y103.969 E-.2367
G1 X99.853 Y104.252 E-.152
G1 X100.136 Y104.534 E-.152
G1 X100.419 Y104.817 E-.152
G1 X100.544 Y104.942 E-.06731
; WIPE_END
G1 E-.03999 F1800
G1 X99.559 Y105.004 Z1.6 F36000
G1 Z1.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X98.408 Y103.853 E.05401
G1 X97.635 Y104.626 E.03627
G1 X101.473 Y108.464 E.18005
G1 X108.464 Y101.473 E.32798
G1 X104.626 Y97.635 E.18005
G1 X103.853 Y98.408 E.03627
G1 X106.713 Y101.268 E.13416
G1 X105.577 Y102.404 E.05329
G1 X106.107 Y102.934 E.02488
G1 X104.52 Y104.521 E.07443
G1 X111.322 Y111.322 E.31909
G1 X115.16 Y107.484 E.18005
G1 X113.469 Y105.793 E.07936
G1 X112.86 Y106.402 E.02857
G1 X112.035 Y105.577 E.03868
G1 X105.311 Y112.302 E.31547
G1 X105.868 Y112.86 E.02617
G1 X105.526 Y113.202 E.01606
G1 X107.484 Y115.16 E.09186
G1 X107.057 Y115.587 E.02003
G1 X108.379 Y116.909 E.06202
G1 X107.715 Y117.574 E.03119
G1 X106.563 Y116.423 E.05401
G1 X108.827 Y117.037 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.41073
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X117.847 Y108.018 E.68859
G1 X117.521 Y107.692 E.02487
G1 X108.645 Y116.568 E.67766
G1 X108.319 Y116.243 E.02487
G1 X112.405 Y112.157 E.31192
G1 X112.079 Y111.831 E.02487
G1 X107.993 Y115.917 E.31192
G1 X107.667 Y115.591 E.02487
G1 X116.687 Y106.571 E.68859
G1 X112.015 Y105.135 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38445
; LAYER_HEIGHT: 0.2
G1 F3000;_EXTRUDE_SET_SPEED
G1 X112.387 Y105.493 E.01436
G1 X112.53 Y105.559 E.00437
G1 X112.86 Y105.85 E.01226
G1 X112.972 Y105.776 E.00375
G1 X114.181 Y104.568 E.04758
G1 X114.294 Y104.494 E.00375
G1 X114.406 Y104.568 E.00375
G1 X116.231 Y106.392 E.07181
; Slow Down End
G1 X119.603 Y117.3 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X118.452 Y118.452 E.05401
G1 X120.182 Y120.182 E.08119
G1 X116.682 Y123.683 E.16421
G1 X116.82 Y123.821 E.00647
G1 X115.391 Y125.25 E.06705
G1 X111.553 Y121.412 E.18005
G1 X112.217 Y120.747 E.03118
G1 X114.187 Y122.717 E.09239
G1 X114.614 Y122.29 E.02003
G1 X128.698 Y136.374 E.6607
G1 X128.271 Y136.8 E.02003
G1 X131.407 Y139.937 E.14715
G1 X130.743 Y140.602 E.03118
G1 X134.581 Y144.44 E.18005
G1 X135.245 Y143.775 E.03118
G1 X135.4 Y143.93 E.00726
G1 X135.827 Y143.503 E.02003
G1 X137.841 Y145.516 E.09446
G1 X138.183 Y145.174 E.01605
G1 X139.852 Y146.844 E.07833
G1 X146.844 Y139.852 E.32798
G1 X145.174 Y138.183 E.07833
G1 X145.516 Y137.841 E.01606
G1 X143.503 Y135.827 E.09446
G1 X139.665 Y139.665 E.18005
G1 X155.502 Y155.502 E.74297
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X156.099 Y149.108 E.01606
G1 X154.52 Y147.528 E.07411
G1 X147.528 Y154.52 E.32798
G1 X149.108 Y156.1 E.07411
G1 X148.766 Y156.442 E.01605
G1 X149.543 Y157.219 E.03647
G1 X148.392 Y158.37 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X149.413 Y149.325 Z1.6 F36000
G1 X149.53 Y142.539 Z1.6
G1 Z1.2
G1 E.8 F1800
G1 F15476.087
G1 X150.682 Y143.69 E.05401
G1 X143.69 Y150.682 E.32798
G1 X142.539 Y149.53 E.05401
; WIPE_START
G1 X143.69 Y150.682 E-.61876
G1 X143.953 Y150.419 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X137.992 Y145.653 Z1.6 F36000
G1 X135.253 Y143.463 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.41073
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X144.273 Y134.444 E.68859
G1 X143.947 Y134.118 E.02487
G1 X135.07 Y142.994 E.67766
G1 X134.745 Y142.668 E.02487
G1 X143.621 Y133.792 E.67766
G1 X143.295 Y133.466 E.02487
M73 P55 R8
G1 X134.419 Y142.343 E.67766
G1 X134.093 Y142.017 E.02487
G1 X142.969 Y133.14 E.67766
G1 X142.644 Y132.815 E.02487
G1 X138.723 Y136.735 E.2993
G2 X138.794 Y136.013 I-2.175 J-.578 E.03935
G1 X142.318 Y132.489 E.26903
G1 X141.992 Y132.163 E.02487
G1 X138.701 Y135.454 E.25128
G2 X138.534 Y134.969 I-2.226 J.494 E.02774
G1 X141.666 Y131.837 E.23913
G1 X141.341 Y131.511 E.02487
G1 X138.285 Y134.566 E.23323
G1 X137.987 Y134.213 E.02496
G1 X141.015 Y131.186 E.23113
G1 X140.689 Y130.86 E.02487
G1 X137.629 Y133.92 E.23364
G2 X137.205 Y133.692 I-1.023 J1.393 E.02605
G1 X140.363 Y130.534 E.2411
G1 X140.037 Y130.208 E.02487
G1 X136.717 Y133.528 E.25347
G1 X136.701 Y133.525 E.0009
G2 X136.129 Y133.465 I-.505 J2.065 E.03113
G1 X139.712 Y129.883 E.2735
G1 X139.386 Y129.557 E.02487
G1 X135.374 Y133.569 E.3063
G1 X135.19 Y133.639 E.01061
G2 X133.568 Y135.375 I.909 J2.476 E.13305
G1 X130.509 Y138.433 E.23348
G1 X130.835 Y138.759 E.02487
G1 X133.458 Y136.136 E.20021
G1 X133.456 Y136.158 E.00117
G2 X133.524 Y136.722 I2.612 J-.031 E.03071
G1 X131.161 Y139.085 E.18041
G1 X131.487 Y139.411 E.02487
G1 X133.688 Y137.21 E.16803
G1 X133.699 Y137.242 E.00188
G2 X133.92 Y137.629 I1.877 J-.818 E.02407
G1 X131.813 Y139.736 E.1609
G1 X132.138 Y140.062 E.02487
G1 X134.213 Y137.987 E.1584
G1 X134.566 Y138.286 E.02496
G1 X132.464 Y140.388 E.1605
G1 X132.79 Y140.714 E.02487
G1 X134.973 Y138.531 E.16667
G2 X135.454 Y138.701 I.735 J-1.314 E.0277
G1 X133.116 Y141.039 E.17855
G1 X133.441 Y141.365 E.02487
G1 X136.013 Y138.794 E.1963
G2 X136.735 Y138.723 I.135 J-2.346 E.03934
G1 X133.624 Y141.834 E.2375
G1 X130.04 Y138.251 F36000
G1 F3000
G1 X139.06 Y129.231 E.68859
G1 X138.734 Y128.905 E.02487
G1 X129.858 Y137.782 E.67766
G1 X129.532 Y137.456 E.02487
G1 X133.618 Y133.37 E.31192
G1 X133.292 Y133.044 E.02487
G1 X129.206 Y137.13 E.31193
G1 X128.88 Y136.804 E.02487
G1 X137.9 Y127.785 E.68859
G1 X136.576 Y126.737 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
; LAYER_HEIGHT: 0.2
G1 F12000
G1 X137.444 Y127.605 E.03402
G1 X124.972 Y117.971 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X123.821 Y116.82 E.05401
G1 X125.25 Y115.391 E.06705
G1 X123.381 Y113.522 E.08766
G1 X122.29 Y114.614 E.05121
G1 X136.374 Y128.698 E.66071
G1 X137.199 Y127.873 E.0387
G1 X136.497 Y127.171 E.03291
G1 X126.905 Y136.764 E.45001
G1 X123.067 Y132.926 E.18005
G1 X124.496 Y131.497 E.06705
G1 X123.753 Y130.754 E.03484
G1 X127.253 Y127.254 E.16421
G1 X123.789 Y123.789 E.16252
G1 X122.638 Y124.941 E.05401
G1 X120.38 Y130.239 F36000
G1 F15476.087
G1 X119.229 Y129.088 E.05401
G1 X129.088 Y119.229 E.46252
G1 X132.926 Y123.067 E.18005
G1 X131.497 Y124.496 E.06705
G1 X134.361 Y127.36 E.13436
G1 X130.86 Y130.86 E.16421
G1 X132.536 Y132.536 E.07859
G1 X131.384 Y133.687 E.05401
; WIPE_START
G1 X132.536 Y132.536 E-.61876
G1 X132.273 Y132.273 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X125.584 Y128.596 Z1.6 F36000
G1 X114.04 Y122.25 Z1.6
G1 Z1.2
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.41073
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X123.059 Y113.23 E.68859
G1 X122.734 Y112.905 E.02487
G1 X113.857 Y121.781 E.67766
G1 X113.531 Y121.455 E.02487
G1 X122.408 Y112.579 E.67766
G1 X122.082 Y112.253 E.02487
G1 X113.206 Y121.129 E.67766
G1 X112.88 Y120.804 E.02487
G1 X121.756 Y111.927 E.67766
G1 X121.43 Y111.601 E.02487
G1 X117.513 Y115.519 E.2991
G2 X117.581 Y114.8 I-3.083 J-.655 E.03911
G1 X121.105 Y111.276 E.26903
G1 X120.779 Y110.95 E.02487
G1 X117.487 Y114.241 E.25128
G2 X117.317 Y113.76 I-1.484 J.254 E.0277
G1 X120.453 Y110.624 E.2394
G1 X120.127 Y110.298 E.02487
G1 X117.072 Y113.353 E.23323
G1 X116.774 Y113 E.02496
G1 X119.802 Y109.972 E.23113
G1 X119.476 Y109.647 E.02487
G1 X116.415 Y112.707 E.23363
G2 X115.992 Y112.479 I-1.023 J1.393 E.02605
G1 X119.15 Y109.321 E.2411
G1 X118.824 Y108.995 E.02487
G1 X115.508 Y112.311 E.25314
G2 X114.916 Y112.252 I-.507 J2.078 E.03225
G1 X118.498 Y108.669 E.2735
G1 X118.173 Y108.344 E.02487
G1 X114.16 Y112.356 E.3063
G2 X112.354 Y114.162 I.803 J2.609 E.14348
G1 X109.296 Y117.22 E.23348
G1 X109.622 Y117.546 E.02487
G1 X112.244 Y114.923 E.20021
G2 X112.311 Y115.508 I4.011 J-.159 E.03182
G1 X109.948 Y117.872 E.18041
G1 X110.274 Y118.197 E.02487
G1 X112.474 Y115.996 E.16803
G1 X112.486 Y116.029 E.00187
G2 X112.707 Y116.415 I1.879 J-.819 E.02408
G1 X110.599 Y118.523 E.1609
G1 X110.925 Y118.849 E.02487
G1 X113 Y116.774 E.1584
G1 X113.353 Y117.072 E.02496
G1 X111.251 Y119.175 E.1605
G1 X111.577 Y119.5 E.02487
G1 X113.76 Y117.317 E.16667
G2 X114.241 Y117.487 I.735 J-1.315 E.0277
G1 X111.902 Y119.826 E.17855
G1 X112.228 Y120.152 E.02487
G1 X114.801 Y117.579 E.19644
G2 X115.522 Y117.51 I.105 J-2.71 E.03918
G1 X112.411 Y120.621 E.2375
; CHANGE_LAYER
; Z_HEIGHT: 1.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X113.825 Y119.207 E-.76
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
G1 X133.868 Y127.36
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X127.36 Y133.868 E.30532
G1 X124.246 Y130.754 E.14609
G1 X130.754 Y124.246 E.30532
G1 X133.826 Y127.317 E.1441
G1 X133.314 Y127.36 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.36 Y133.314 E.25872
G1 X124.8 Y130.754 E.11123
G1 X130.754 Y124.8 E.25872
G1 X133.271 Y127.317 E.10939
; WIPE_START
M204 S10000
G1 X131.867 Y128.742 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.853 Y135.838 Z1.8 F36000
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.866 Y135.71 E.00427
G3 X136.029 Y133.829 I2.262 J.416 E.1027
G1 X136.146 Y133.826 E.00388
G3 X133.828 Y136.146 I-.018 J2.3 E.35835
G1 X133.848 Y135.898 E.00825
G1 X134.239 Y135.858 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.29 Y135.613 E.00771
G3 X136.05 Y134.22 I1.838 J.514 E.07371
G1 X136.139 Y134.219 E.00275
G3 X134.231 Y135.918 I-.011 J1.908 E.28239
; WIPE_START
M204 S10000
G1 X134.29 Y135.613 E-.11804
G1 X134.417 Y135.281 E-.13514
G1 X134.503 Y135.126 E-.06726
G1 X134.658 Y134.91 E-.10118
G1 X134.91 Y134.658 E-.13518
G1 X135.126 Y134.503 E-.10119
G1 X135.281 Y134.417 E-.06724
G1 X135.366 Y134.384 E-.03478
; WIPE_END
G1 E-.04 F1800
G1 X128.548 Y130.953 Z1.8 F36000
G1 X120.289 Y126.797 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X117.175 Y123.683 E.14609
G1 X122.196 Y118.661 E.23559
G1 X123.683 Y117.175 E.06973
G1 X126.797 Y120.289 E.14609
G1 X120.331 Y126.755 E.30333
G1 X120.289 Y126.243 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X117.729 Y123.683 E.11123
G1 X122.474 Y118.938 E.20618
G1 X123.683 Y117.729 E.05254
G1 X126.243 Y120.289 E.11123
G1 X120.331 Y126.2 E.25688
; WIPE_START
M204 S10000
G1 X118.894 Y124.81 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X115.967 Y117.761 Z1.8 F36000
M73 P56 R8
G1 X113.924 Y112.841 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X114.298 Y112.697 E.01328
G3 X114.816 Y112.615 I.616 J2.216 E.01744
G1 X114.933 Y112.613 E.00388
G3 X113.869 Y112.864 I-.019 J2.3 E.44285
G1 X114.098 Y113.192 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X114.4 Y113.076 E.00993
G3 X114.837 Y113.007 I.515 J1.837 E.01363
G1 X114.926 Y113.006 E.00275
G3 X114.043 Y113.216 I-.012 J1.908 E.34024
; WIPE_START
M204 S10000
G1 X114.4 Y113.076 E-.14553
G1 X114.66 Y113.023 E-.10122
G1 X114.837 Y113.007 E-.0672
G1 X114.926 Y113.006 E-.03404
G1 X115.192 Y113.026 E-.10118
G1 X115.365 Y113.059 E-.06728
G1 X115.702 Y113.175 E-.13515
G1 X115.936 Y113.302 E-.10115
G1 X115.952 Y113.313 E-.00726
; WIPE_END
G1 E-.04 F1800
G1 X109.301 Y109.568 Z1.8 F36000
G1 X98.578 Y103.53 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X101.268 Y106.22 E.12619
G1 X102.548 Y104.94 E.06006
G1 X103.078 Y105.47 E.02488
G1 X105.47 Y103.078 E.11223
G1 X104.94 Y102.548 E.02488
G1 X106.22 Y101.268 E.06006
G1 X103.53 Y98.578 E.12619
G1 X102.25 Y99.858 E.06006
G1 X100.733 Y98.34 E.07118
G1 X103.252 Y95.821 E.11817
G1 X112.833 Y105.403 E.44948
G1 X114.271 Y103.965 E.06745
G1 X147.078 Y136.772 E1.53904
G1 X145.64 Y138.21 E.06745
G1 X156.073 Y148.642 E.48942
G1 X158.94 Y145.775 E.13453
G1 X160.21 Y147.044 E.05957
G1 X154.616 Y152.639 E.26245
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.044 Y160.21 E.26245
G1 X145.775 Y158.94 E.05957
G1 X148.642 Y156.073 E.13453
G1 X138.209 Y145.64 E.48942
G1 X136.772 Y147.078 E.06745
G1 X103.965 Y114.271 E1.53904
G1 X105.403 Y112.833 E.06745
G1 X95.821 Y103.252 E.44948
G1 X98.34 Y100.733 E.11818
G1 X99.858 Y102.25 E.07118
G1 X98.62 Y103.488 E.05807
G1 X99.132 Y103.53 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.571 Y103.969 E.01905
G1 X99.853 Y104.252 E.01229
G1 F11131.72
G1 X100.136 Y104.534 E.01229
G1 F9862.514
G1 X100.419 Y104.817 E.01229
G1 F8670.109
G1 X100.702 Y105.1 E.01229
G1 F7554.503
G1 X100.985 Y105.383 E.01229
G1 F6515.698
G1 X101.268 Y105.666 E.01229
G1 F5553.692
G1 X101.584 Y105.349 E.01375
G1 F4568.16
G1 X101.867 Y105.066 E.01229
G1 F3768.903
G1 X102.15 Y104.784 E.01229
G1 F3046.446
G1 X102.433 Y104.501 E.01229
G1 F2400.789
G1 X102.548 Y104.386 E.005
G1 F2160
G1 X103.049 Y104.887 E.02179
G1 F2219.441
G1 X103.078 Y104.916 E.00126
G1 F2841.712
G1 X103.361 Y104.633 E.01229
G1 F3540.784
G1 X103.644 Y104.35 E.01229
G1 F4316.655
G1 X103.927 Y104.067 E.01229
G1 F4521.691
G1 X104.209 Y103.785 E.01229
G1 F3917.414
G1 X104.633 Y103.361 E.01841
G1 F2841.689
G1 X104.916 Y103.078 E.01229
G1 F2219.42
G1 X104.887 Y103.049 E.00126
G1 F2160
G1 X104.386 Y102.548 E.02179
G1 F2400.767
G1 X104.501 Y102.433 E.005
G1 F3046.422
G1 X104.784 Y102.15 E.01229
G1 F3768.876
G1 X105.066 Y101.867 E.01229
G1 F4568.13
G1 X105.349 Y101.584 E.01229
G1 F5553.692
G1 X105.666 Y101.268 E.01376
G1 F6515.698
G1 X105.383 Y100.985 E.01229
G1 F7554.503
G1 X105.1 Y100.702 E.01229
G1 F8670.109
G1 X104.817 Y100.419 E.01229
G1 F9587.487
G1 X104.534 Y100.136 E.01229
G1 F9316.429
G1 X104.379 Y99.981 E.00676
G1 F8670.109
G1 X104.096 Y99.698 E.01229
G1 F7554.503
G1 X103.813 Y99.415 E.01229
G1 F6515.698
G1 X103.53 Y99.132 E.01229
G1 F5553.692
G1 X103.214 Y99.449 E.01376
G1 F4568.13
G1 X102.931 Y99.732 E.01229
G1 F3768.876
G1 X102.648 Y100.014 E.01229
G1 F3046.422
G1 X102.365 Y100.297 E.01229
G1 F2400.767
G1 X102.25 Y100.412 E.005
G1 F2160
G1 X100.178 Y98.34 E.09003
G1 F2400.778
G1 X100.293 Y98.225 E.005
G1 F3046.434
G1 X100.576 Y97.943 E.01229
G1 F3768.889
G1 X100.859 Y97.66 E.01229
G1 F4568.145
G1 X101.142 Y97.377 E.01229
G1 F5444.201
G1 X101.425 Y97.094 E.01229
G1 F6397.056
G1 X101.708 Y96.811 E.01229
G1 F7426.712
G1 X101.99 Y96.528 E.01229
G1 F8533.168
G1 X102.273 Y96.245 E.01229
G1 F9716.424
G1 X102.556 Y95.963 E.01229
G1 F10976.479
G1 X102.839 Y95.68 E.01229
G1 F12000
G1 X103.252 Y95.267 E.01794
G1 X112.833 Y104.848 E.41635
G1 X114.271 Y103.41 E.06248
G1 X144.098 Y133.237 E1.29612
G1 X147.632 Y136.772 E.15359
G1 X146.194 Y138.21 E.06248
G1 X156.073 Y148.088 E.42926
G1 X158.94 Y145.22 E.12462
G1 X160.765 Y147.044 E.07928
G1 X155.17 Y152.639 E.24311
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.044 Y160.765 E.24311
G1 X145.22 Y158.94 E.07928
G1 X148.088 Y156.073 E.12462
G1 X138.209 Y146.194 E.42926
G1 X136.772 Y147.632 E.06248
G1 X103.41 Y114.271 E1.44971
G1 X104.848 Y112.833 E.06248
G1 X95.267 Y103.252 E.41635
G1 X95.68 Y102.839 E.01794
G1 F10976.456
G1 X95.963 Y102.556 E.01229
G1 F9716.402
G1 X96.245 Y102.273 E.01229
G1 F8533.148
G1 X96.528 Y101.99 E.01229
G1 F7426.693
G1 X96.811 Y101.708 E.01229
G1 F6397.039
G1 X97.094 Y101.425 E.01229
G1 F5444.185
G1 X97.377 Y101.142 E.01229
G1 F4568.13
G1 X97.66 Y100.859 E.01229
G1 F3768.876
G1 X97.943 Y100.576 E.01229
G1 F3046.422
G1 X98.225 Y100.293 E.01229
G1 F2400.767
G1 X98.34 Y100.178 E.005
G1 F2160
G1 X100.412 Y102.25 E.09003
G1 F2400.778
G1 X100.297 Y102.365 E.005
G1 F3046.434
G1 X100.014 Y102.648 E.01229
G1 F3768.889
G1 X99.731 Y102.931 E.01229
G1 F4568.145
G1 X99.449 Y103.214 E.01229
G1 F5415.994
G1 X99.175 Y103.488 E.01191
; WIPE_START
M204 S10000
G1 X99.571 Y103.969 E-.2367
G1 X99.853 Y104.252 E-.152
G1 X100.136 Y104.534 E-.152
G1 X100.419 Y104.817 E-.152
G1 X100.544 Y104.942 E-.06731
; WIPE_END
G1 E-.03999 F1800
G1 X106.729 Y109.415 Z1.8 F36000
G1 X107.271 Y109.808 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.40611
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X110.638 Y112.931 E.24237
G1 X110.96 Y112.609 E.02409
G1 X107.742 Y109.623 E.23167
G1 X108.065 Y109.3 E.02409
G1 X111.283 Y112.286 E.23167
G1 X111.606 Y111.963 E.02409
G1 X108.388 Y108.977 E.23167
G1 X108.711 Y108.655 E.02409
G1 X112.812 Y112.46 E.29524
G1 X113.134 Y112.137 E.02409
G1 X109.033 Y108.332 E.29524
G1 X109.356 Y108.009 E.02409
G1 X113.457 Y111.814 E.29524
G1 X113.78 Y111.491 E.02409
G1 X109.679 Y107.686 E.29524
G1 X110.002 Y107.364 E.02409
G1 X114.103 Y111.169 E.29524
G1 X114.425 Y110.846 E.02409
G1 X110.324 Y107.041 E.29524
G1 X110.647 Y106.718 E.02409
G1 X114.748 Y110.523 E.29524
G1 X115.071 Y110.2 E.02409
G1 X110.97 Y106.395 E.29524
G1 X111.293 Y106.073 E.02409
G1 X115.394 Y109.878 E.29524
G1 X115.716 Y109.555 E.02409
G1 X111.615 Y105.75 E.29524
G2 X111.929 Y105.419 I-4.253 J-4.351 E.02408
G1 X116.039 Y109.232 E.29587
G1 X116.362 Y108.91 E.02409
G1 X112.984 Y105.775 E.24321
G1 X113.306 Y105.452 E.02409
G1 X116.685 Y108.587 E.24321
G1 X117.007 Y108.264 E.02409
G1 X113.629 Y105.13 E.24321
G1 X113.952 Y104.807 E.02409
G1 X117.479 Y108.079 E.25391
G1 X112.858 Y113.084 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.5472
; LAYER_HEIGHT: 0.2
G1 F12493.06
G1 X113.136 Y112.813 E.01596
G1 X111.911 Y116.543 F36000
; LINE_WIDTH: 0.38858
G1 F15000
G1 X111.743 Y116.211 E.01048
G1 X111.547 Y115.542 E.01964
G1 X111.507 Y114.979 E.01588
G1 X111.262 Y115.893 E.02666
G1 X111.869 Y116.5 E.02417
G1 X114.789 Y118.34 F36000
; LINE_WIDTH: 0.38726
G1 F15000
G1 X114.524 Y118.318 E.00744
G1 X113.846 Y118.169 E.0195
G1 X113.285 Y117.917 E.01724
G1 X113.936 Y118.568 E.02583
G1 X114.731 Y118.355 E.0231
G1 X117.484 Y117.626 F36000
; LINE_WIDTH: 0.413948
G1 F15000
G3 X120.76 Y114.315 I115.193 J110.693 E.14082
G1 X121.88 Y113.195 E.0479
G1 X117.804 Y109.119 E.17429
G1 X115.415 Y111.508 E.10216
G1 X116.08 Y111.674 E.02075
G1 X116.682 Y111.958 E.02012
G1 X117.298 Y112.428 E.02342
G1 X117.734 Y112.935 E.02021
G1 X118.153 Y113.75 E.02771
G1 X118.232 Y113.999 E.0079
G1 X118.349 Y114.687 E.02108
G1 X118.346 Y115.234 E.01655
G1 X118.194 Y115.967 E.02263
G1 X117.93 Y116.581 E.0202
G3 X117.284 Y117.364 I-2.954 J-1.782 E.03081
G3 X116.668 Y117.845 I-1.776 J-1.638 E.02371
G1 X117.426 Y117.642 E.02372
G1 X117.666 Y117.942 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X122.413 Y113.195 E.20627
G1 X117.804 Y108.586 E.2003
G1 X114.502 Y111.888 E.14349
G1 X114.842 Y111.847 E.01053
G1 X115.424 Y111.889 E.01793
G1 X115.983 Y112.039 E.01778
G1 X116.511 Y112.294 E.01803
G1 X117.061 Y112.722 E.0214
G1 X117.441 Y113.172 E.01812
G1 X117.813 Y113.913 E.02547
G1 X117.977 Y114.75 E.02621
G1 X117.956 Y115.321 E.01756
G1 X117.826 Y115.882 E.0177
G1 X117.589 Y116.422 E.01811
G1 X117.279 Y116.87 E.01676
G1 X116.871 Y117.278 E.01771
; LINE_WIDTH: 0.44236
G1 X116.64 Y117.463 E.00964
; LINE_WIDTH: 0.4871
G1 F14183.439
G1 X116.408 Y117.647 E.01072
; LINE_WIDTH: 0.532446
G1 F12869.592
G1 X116.327 Y117.713 E.00415
G1 X115.879 Y117.877 E.01904
G3 X115.067 Y118.048 I-1.767 J-6.374 E.03313
; LINE_WIDTH: 0.532249
G1 F12874.791
G1 X114.745 Y117.984 E.01309
; LINE_WIDTH: 0.487345
G1 F14175.621
G1 X114.423 Y117.92 E.01189
; LINE_WIDTH: 0.431259
G1 F15000
G3 X113.787 Y117.768 I.697 J-4.327 E.0207
; LINE_WIDTH: 0.44142
G1 X113.52 Y117.656 E.00942
; LINE_WIDTH: 0.48428
G1 F14274.062
G1 X113.252 Y117.544 E.01043
; LINE_WIDTH: 0.527221
G1 F13008.456
G1 X113.113 Y117.469 E.00626
G1 X112.598 Y116.998 E.02754
G1 X112.483 Y116.871 E.00676
; LINE_WIDTH: 0.510424
G1 F13475.841
G1 X112.374 Y116.665 E.00888
; LINE_WIDTH: 0.47425
G1 F14605.986
G1 X112.265 Y116.459 E.00819
; LINE_WIDTH: 0.423382
G1 F15000
G1 X112.155 Y116.253 E.00723
G3 X111.871 Y115.285 I5.263 J-2.074 E.03133
; LINE_WIDTH: 0.441918
G1 X111.846 Y114.936 E.01136
; LINE_WIDTH: 0.485773
G1 F14225.956
G1 X111.822 Y114.588 E.01261
; LINE_WIDTH: 0.527282
G1 F13006.818
G1 X111.939 Y113.986 E.0242
G1 X112.154 Y113.448 E.02288
G2 X111.749 Y113.024 I-8.566 J7.767 E.02312
G1 X111.706 Y113.076 E.00268
G2 X111.362 Y114.328 I31.516 J9.336 E.05125
; LINE_WIDTH: 0.507199
G1 F13569.446
G1 X111.267 Y114.613 E.01137
; LINE_WIDTH: 0.472315
G1 F14671.805
G1 X111.173 Y114.898 E.01051
; LINE_WIDTH: 0.422416
G1 F15000
G2 X110.859 Y116.001 I9.326 J3.248 E.03549
G1 X111.575 Y116.718 E.03133
; LINE_WIDTH: 0.438077
G1 X111.752 Y116.869 E.00751
; LINE_WIDTH: 0.47425
G1 F14605.986
G1 X111.93 Y117.021 E.00819
; LINE_WIDTH: 0.529262
G1 F12953.854
G1 X112.107 Y117.172 E.00924
G1 X112.772 Y117.83 E.03708
; LINE_WIDTH: 0.519499
G1 F13219.234
G1 X112.948 Y118.034 E.01044
; LINE_WIDTH: 0.479695
G1 F14423.902
G1 X113.123 Y118.238 E.00957
; LINE_WIDTH: 0.42262
G1 F15000
G2 X113.828 Y118.97 I5.288 J-4.38 E.03149
G1 X114.811 Y118.707 E.03149
; LINE_WIDTH: 0.442442
G1 X114.918 Y118.655 E.00386
; LINE_WIDTH: 0.487345
G1 F14175.621
G1 X115.025 Y118.603 E.0043
; LINE_WIDTH: 0.535454
G1 F12791.014
G1 X115.131 Y118.551 E.00476
G2 X116.494 Y118.189 I-3.022 J-14.114 E.05661
; LINE_WIDTH: 0.52749
G1 F13001.217
G1 X116.699 Y118.157 E.00818
; LINE_WIDTH: 0.48449
G1 F14267.274
G1 X116.903 Y118.124 E.00746
; LINE_WIDTH: 0.426133
G1 F15000
G2 X117.608 Y117.957 I-.447 J-3.464 E.02267
G1 X118.275 Y117.867 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X122.947 Y113.195 E.20299
G1 X117.804 Y108.052 E.22347
G1 X113.54 Y112.317 E.1853
; LINE_WIDTH: 0.442035
G1 X113.419 Y112.468 E.00629
; LINE_WIDTH: 0.486125
G1 F14214.642
G1 X113.299 Y112.619 E.00698
; LINE_WIDTH: 0.530215
G1 F12928.513
G1 X113.179 Y112.771 E.00768
G1 X113.352 Y112.685 E.00768
; LINE_WIDTH: 0.486125
G1 F14214.642
G1 X113.525 Y112.598 E.00698
; LINE_WIDTH: 0.420267
G1 F15000
G3 X114.783 Y112.225 I1.533 J2.859 E.04064
G1 X115.288 Y112.247 E.01553
M73 P56 R7
G1 X115.886 Y112.403 E.019
G1 X116.34 Y112.63 E.01562
G1 X116.824 Y113.015 E.01901
G1 X117.148 Y113.409 E.0157
G1 X117.473 Y114.076 E.02279
G1 X117.605 Y114.813 E.02304
G1 X117.588 Y115.236 E.01302
G1 X117.459 Y115.798 E.01772
G1 X117.247 Y116.262 E.0157
G1 X117.012 Y116.604 E.01275
G1 X116.604 Y117.012 E.01772
G1 X116.178 Y117.293 E.0157
G1 X115.793 Y117.46 E.0129
G1 X115.11 Y117.6 E.02144
G1 X114.682 Y117.597 E.01315
G1 X114.003 Y117.448 E.02137
G1 X113.443 Y117.17 E.01925
G1 X112.881 Y116.679 E.02292
G1 X112.474 Y116.051 E.02303
G1 X112.255 Y115.334 E.02305
G1 X112.243 Y114.585 E.02303
G1 X112.353 Y114.082 E.01584
G1 X112.52 Y113.688 E.01315
; LINE_WIDTH: 0.44171
G1 X112.664 Y113.438 E.00935
; LINE_WIDTH: 0.48515
G1 F14245.981
G1 X112.808 Y113.189 E.01037
; LINE_WIDTH: 0.524505
G1 F13081.803
G1 X112.858 Y113.084 E.00457
G1 X112.764 Y113.153 E.00457
; LINE_WIDTH: 0.48515
G1 F14245.981
G1 X112.613 Y113.135 E.00551
; LINE_WIDTH: 0.420218
G1 F15000
G1 X112.461 Y113.116 E.0047
G1 X111.749 Y112.405 E.03095
G1 X111.316 Y112.838 E.01882
G1 X110.44 Y116.108 E.10411
G2 X113.711 Y119.387 I167.682 J-164.032 E.14239
G2 X117.859 Y118.281 I-53.829 J-210.202 E.13198
G1 X118.233 Y117.909 E.01621
G1 X118.583 Y115.959 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X121.347 Y113.195 E.12012
G1 X117.804 Y109.652 E.15395
G1 X116.153 Y111.303 E.07175
G1 X116.854 Y111.622 E.02366
G1 X117.535 Y112.135 E.02621
G1 X118.027 Y112.697 E.02297
G1 X118.192 Y112.958 E.00948
G1 X118.493 Y113.587 E.02143
G1 X118.604 Y113.936 E.01124
G1 X118.721 Y114.624 E.02143
G1 X118.723 Y115.25 E.01926
G1 X118.594 Y115.9 E.02036
G1 X119.113 Y114.895 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X120.814 Y113.195 E.07388
G1 X117.804 Y110.185 E.13078
G1 X116.812 Y111.177 E.0431
G3 X118.391 Y112.553 I-1.913 J3.788 E.06503
G1 X118.833 Y113.424 E.03002
G1 X118.976 Y113.873 E.01446
G1 X119.092 Y114.56 E.02143
G1 X119.11 Y114.835 E.00846
G1 X119.394 Y114.082 F36000
; LINE_WIDTH: 0.420167
G1 F15000
G1 X120.28 Y113.195 E.03855
G2 X119.367 Y112.283 I-506.897 J506.489 E.03968
; LINE_WIDTH: 0.435393
G1 X119.163 Y112.098 E.0088
; LINE_WIDTH: 0.466855
G1 F14860.777
G3 X117.958 Y110.913 I206.522 J-211.189 E.0584
G1 X117.804 Y110.759 E.00751
G1 X117.47 Y111.093 E.01631
G1 X118.019 Y111.536 E.02436
G3 X118.728 Y112.317 I-6.139 J6.28 E.03646
; LINE_WIDTH: 0.471673
G1 F14693.792
G1 X118.951 Y112.789 E.01825
; LINE_WIDTH: 0.426842
G1 F15000
G3 X119.383 Y114.023 I-3.982 J2.09 E.04103
G1 X119.673 Y113.138 F36000
; LINE_WIDTH: 0.57208
G1 F11905.663
G2 X119.676 Y113.247 I-.028 J.055 E.01113
; WIPE_START
G1 X119.606 Y113.252 E-.19699
G1 X119.573 Y113.195 E-.18767
G1 X119.606 Y113.138 E-.18767
G1 X119.673 Y113.138 E-.18767
; WIPE_END
G1 E-.04 F1800
G1 X121.532 Y120.54 Z1.8 F36000
G1 X122.638 Y124.941 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X123.789 Y123.789 E.05401
G1 X127.253 Y127.254 E.16252
G1 X123.753 Y130.754 E.16421
G1 X124.496 Y131.497 E.03484
G1 X123.089 Y132.903 E.06598
G1 X126.927 Y136.741 E.18005
G1 X130.344 Y133.325 E.16026
G1 X129.903 Y132.912 E.02003
G1 X131.407 Y131.407 E.07058
G1 X130.86 Y130.86 E.02567
G1 X134.361 Y127.36 E.16421
G1 X131.497 Y124.496 E.13436
G1 X132.903 Y123.089 E.06598
G1 X129.065 Y119.251 E.18005
G1 X119.251 Y129.065 E.46037
G1 X115.413 Y125.227 E.18005
G1 X116.82 Y123.821 E.06597
G1 X117.971 Y124.972 E.05401
; WIPE_START
G1 X116.82 Y123.821 E-.61876
G1 X116.557 Y124.083 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X123.02 Y128.144 Z1.8 F36000
G1 X130.372 Y132.762 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.40278
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X131.85 Y134.146 E.10508
G1 X132.17 Y133.826 E.02352
G1 X130.84 Y132.581 E.09456
G1 X131.161 Y132.26 E.02352
G1 X132.49 Y133.505 E.09456
G1 X132.811 Y133.185 E.02352
G1 X131.481 Y131.94 E.09456
G1 X131.801 Y131.62 E.02352
G1 X134.01 Y133.688 E.15708
G1 X134.33 Y133.368 E.02352
G1 X132.122 Y131.299 E.15708
G1 X132.442 Y130.979 E.02352
G1 X134.651 Y133.047 E.15708
G1 X134.971 Y132.727 E.02352
G1 X132.762 Y130.659 E.15708
G1 X133.083 Y130.338 E.02352
G1 X135.291 Y132.407 E.15708
G1 X135.612 Y132.086 E.02352
G1 X133.403 Y130.018 E.15708
G1 X133.538 Y129.883 E.00994
G1 X133.724 Y129.698 E.01358
G1 X135.932 Y131.766 E.15708
G1 X136.252 Y131.446 E.02352
G1 X134.044 Y129.377 E.15708
G1 X134.364 Y129.057 E.02352
G1 X136.573 Y131.125 E.15708
G1 X136.893 Y130.805 E.02352
G1 X134.685 Y128.736 E.15708
G1 X135.005 Y128.416 E.02352
G1 X137.213 Y130.485 E.15708
G1 X137.534 Y130.164 E.02352
G1 X135.325 Y128.096 E.15708
G1 X135.646 Y127.775 E.02352
M73 P57 R7
G1 X137.854 Y129.844 E.15708
G1 X138.174 Y129.524 E.02352
G1 X135.966 Y127.455 E.15708
G1 X136.286 Y127.135 E.02352
G1 X138.642 Y129.342 E.1676
G1 X136.225 Y126.411 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
; LAYER_HEIGHT: 0.2
G1 F15476.087
G1 X136.307 Y126.494 E.00387
G3 X135.245 Y127.569 I-41.125 J-39.522 E.05014
G1 X122.186 Y114.51 E.61264
G1 X123.255 Y113.441 E.05014
G1 X125.227 Y115.413 E.09252
G1 X123.821 Y116.82 E.06597
G1 X123.683 Y116.682 E.00646
G1 X120.182 Y120.182 E.16421
G1 X118.348 Y118.348 E.08606
G3 X118.01 Y118.646 I-.725 J-.481 E.01511
G1 X113.721 Y119.795 E.1473
G3 X113.367 Y119.597 I-.006 J-.406 E.01409
G1 X111.575 Y121.389 E.08405
G1 X107.738 Y117.551 E.18005
G1 X110.347 Y114.942 E.1224
G1 X110.754 Y113.421 E.05223
G1 X110.716 Y113.459 E.00179
; WIPE_START
G1 X110.754 Y113.421 E-.02048
G1 X110.347 Y114.942 E-.59829
G1 X110.084 Y115.205 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X115.535 Y120.547 Z1.8 F36000
G1 X134.498 Y139.131 Z1.8
G1 Z1.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.38726
G1 F15000
G1 X135.149 Y139.781 E.02583
G1 X136.002 Y139.553 E.02478
G1 X135.738 Y139.531 E.00745
G1 X135.059 Y139.382 E.0195
G1 X134.553 Y139.155 E.01556
G1 X132.702 Y136.259 F36000
; LINE_WIDTH: 0.37881
G1 F15000
G2 X132.47 Y137.108 I50.721 J14.348 E.0241
G1 X133.126 Y137.764 E.02539
G1 X132.836 Y137.06 E.02084
G1 X132.712 Y136.318 E.02058
G1 X133.99 Y134.391 F36000
; LINE_WIDTH: 0.58216
G1 F11683.11
G1 X134.592 Y133.819 E.03651
G1 X132.962 Y134.241 F36000
; LINE_WIDTH: 0.533316
G1 F12846.765
G2 X132.473 Y135.999 I12.642 J4.465 E.07297
; LINE_WIDTH: 0.541432
G1 F12637.618
G1 X132.433 Y136.055 E.00278
; LINE_WIDTH: 0.492855
G1 F14002.022
G1 X132.393 Y136.11 E.00251
; LINE_WIDTH: 0.420739
G1 F15000
G1 X132.353 Y136.166 E.00211
G1 X132.072 Y137.215 E.03344
G1 X132.825 Y137.968 E.03279
; LINE_WIDTH: 0.443795
G1 X132.902 Y138.011 E.00287
; LINE_WIDTH: 0.491405
G1 F14047.292
G1 X132.978 Y138.054 E.00321
; LINE_WIDTH: 0.535105
G1 F12800.065
G1 X133.055 Y138.096 E.00352
G2 X134.014 Y139.071 I10.229 J-9.108 E.05488
; LINE_WIDTH: 0.520865
G1 F13181.432
G1 X134.18 Y139.266 E.00995
; LINE_WIDTH: 0.480515
G1 F14396.874
G1 X134.346 Y139.46 E.00911
; LINE_WIDTH: 0.422541
G1 F15000
G2 X135.041 Y140.184 I4.913 J-4.024 E.03107
G1 X136.024 Y139.92 E.03149
; LINE_WIDTH: 0.440165
G1 X136.178 Y139.858 E.00538
; LINE_WIDTH: 0.480515
G1 F14396.874
G1 X136.333 Y139.796 E.00593
; LINE_WIDTH: 0.526002
G1 F13041.281
G1 X136.487 Y139.734 E.00654
G1 X137.031 Y139.602 E.02205
; LINE_WIDTH: 0.538405
G1 F12714.815
G1 X137.805 Y139.369 E.03262
; LINE_WIDTH: 0.538999
G1 F12699.608
G1 X137.893 Y139.37 E.00355
; LINE_WIDTH: 0.491395
G1 F14047.606
G1 X137.98 Y139.371 E.00321
; LINE_WIDTH: 0.420067
G1 F15000
G1 X138.068 Y139.373 E.0027
G1 X138.88 Y139.155 E.02582
G1 X143.627 Y134.408 E.20631
G1 X139.017 Y129.799 E.20034
G1 X135.715 Y133.101 E.14352
G1 X136.081 Y133.062 E.01133
G1 X136.773 Y133.13 E.02135
G1 X137.574 Y133.423 E.02622
G3 X138.397 Y134.061 I-1.627 J2.954 E.03213
G1 X138.857 Y134.73 E.02494
G1 X139.11 Y135.405 E.02217
G1 X139.194 Y135.989 E.01811
G1 X139.166 Y136.547 E.01719
G1 X138.993 Y137.223 E.02144
G1 X138.741 Y137.736 E.01755
G1 X138.394 Y138.196 E.01771
G1 X137.746 Y138.732 E.02585
; LINE_WIDTH: 0.443792
G1 X137.71 Y138.781 E.00197
; LINE_WIDTH: 0.491395
G1 F14047.606
G1 X137.674 Y138.829 E.00221
; LINE_WIDTH: 0.535268
G1 F12795.844
G1 X137.638 Y138.878 E.00242
G1 X136.985 Y139.123 E.028
G1 X136.383 Y139.247 E.02465
; LINE_WIDTH: 0.520865
G1 F13181.432
G1 X136.194 Y139.224 E.00743
; LINE_WIDTH: 0.480515
G1 F14396.874
G1 X136.004 Y139.201 E.00681
; LINE_WIDTH: 0.424337
G1 F15000
G1 X135.815 Y139.178 E.00593
G1 X135.136 Y139.03 E.0216
; LINE_WIDTH: 0.441413
G1 X134.801 Y138.894 E.01175
; LINE_WIDTH: 0.484258
G1 F14274.789
G1 X134.466 Y138.757 E.01301
; LINE_WIDTH: 0.5267
G1 F13022.458
G1 X134.347 Y138.702 E.00515
G1 X133.942 Y138.352 E.02112
; LINE_WIDTH: 0.538405
G1 F12714.815
G1 X133.445 Y137.754 E.03138
; LINE_WIDTH: 0.539015
G1 F12699.18
G1 X133.438 Y137.694 E.00244
; LINE_WIDTH: 0.491405
G1 F14047.292
G1 X133.431 Y137.634 E.00221
; LINE_WIDTH: 0.420963
G1 F15000
G1 X133.424 Y137.574 E.00186
G1 X133.168 Y136.928 E.02141
G1 X133.061 Y136.215 E.02223
; LINE_WIDTH: 0.444279
G1 X133.036 Y136.173 E.00159
; LINE_WIDTH: 0.492855
G1 F14002.022
G1 X133.011 Y136.131 E.00178
; LINE_WIDTH: 0.540492
G1 F12661.491
G1 X132.986 Y136.09 E.00197
G1 X133.068 Y135.522 E.02324
G3 X133.369 Y134.647 I6.023 J1.579 E.03754
G1 X133.005 Y134.284 E.02085
G1 X132.962 Y133.618 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X132.53 Y134.051 E.01881
G1 X131.653 Y137.322 E.10404
G2 X134.924 Y140.6 I165.572 J-161.928 E.1423
G2 X139.072 Y139.494 I-53.8 J-210.098 E.1319
G2 X144.16 Y134.408 I-954.022 J-959.475 E.22104
G1 X139.017 Y129.266 E.22347
G1 X135.12 Y133.163 E.16935
; LINE_WIDTH: 0.444677
G1 X134.973 Y133.345 E.00766
; LINE_WIDTH: 0.49405
G1 F13964.932
G1 X134.826 Y133.527 E.0086
; LINE_WIDTH: 0.543424
G1 F12587.33
G1 X134.679 Y133.708 E.00954
; LINE_WIDTH: 0.586565
G1 F11588.446
G1 X134.636 Y133.778 E.0036
; LINE_WIDTH: 0.581892
G1 F11688.935
G1 X134.822 Y133.719 E.00855
; LINE_WIDTH: 0.535634
G1 F12786.329
G1 X135.007 Y133.66 E.00782
; LINE_WIDTH: 0.489377
G1 F14111.125
G1 X135.193 Y133.601 E.00709
; LINE_WIDTH: 0.420289
G1 F15000
G1 X135.378 Y133.542 E.00599
G1 X135.996 Y133.438 E.01927
G1 X136.736 Y133.505 E.02282
G1 X137.435 Y133.774 E.02304
G1 X137.86 Y134.065 E.01584
G1 X138.158 Y134.36 E.01289
G1 X138.543 Y134.938 E.02137
G1 X138.753 Y135.528 E.01926
G1 X138.82 Y136.035 E.0157
G1 X138.8 Y136.454 E.0129
G1 X138.627 Y137.129 E.02145
G1 X138.44 Y137.509 E.01302
G1 X138.093 Y137.969 E.01772
G1 X137.512 Y138.437 E.02292
G1 X136.823 Y138.729 E.02304
G1 X136.315 Y138.815 E.01583
G1 X135.896 Y138.81 E.0129
G1 X135.217 Y138.661 E.02137
G1 X134.656 Y138.383 E.01925
G1 X134.256 Y138.065 E.0157
G1 X133.8 Y137.481 E.0228
G1 X133.518 Y136.789 E.02296
G1 X133.435 Y136.168 E.01926
G1 X133.476 Y135.659 E.01571
G1 X133.58 Y135.258 E.01275
G1 X133.823 Y134.735 E.01772
; LINE_WIDTH: 0.443209
G1 X133.879 Y134.62 E.00416
; LINE_WIDTH: 0.489645
G1 F14102.636
G1 X133.934 Y134.506 E.00464
; LINE_WIDTH: 0.536082
G1 F12774.715
G1 X133.99 Y134.391 E.00512
G1 X133.898 Y134.381 E.00373
; LINE_WIDTH: 0.489645
G1 F14102.636
G1 X133.805 Y134.372 E.00338
; LINE_WIDTH: 0.421968
G1 F15000
G1 X133.713 Y134.362 E.00287
G3 X133.005 Y133.66 I42.762 J-43.871 E.03079
G1 X136.614 Y132.735 F36000
; LINE_WIDTH: 0.419755
G1 F15000
G1 X137.064 Y132.816 E.01404
G1 X137.712 Y133.073 E.02142
G1 X138.229 Y133.403 E.01881
G1 X138.661 Y133.791 E.01787
G1 X139.171 Y134.521 E.02732
G1 X139.466 Y135.282 E.02508
G1 X139.568 Y135.943 E.02052
G1 X139.56 Y136.447 E.0155
G1 X139.358 Y137.317 E.0274
G1 X139.13 Y137.814 E.0168
; LINE_WIDTH: 0.376518
G1 X138.675 Y138.407 E.02033
G1 X137.964 Y139.007 E.02529
G1 X137.873 Y139.063 E.0029
G1 X138.698 Y138.842 E.02324
G1 X139.312 Y138.198 E.02418
; LINE_WIDTH: 0.41976
G3 X143.093 Y134.408 I684.191 J678.885 E.16438
G1 X139.017 Y130.332 E.17702
G1 X136.656 Y132.693 E.10253
G1 X137.356 Y132.526 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X137.851 Y132.722 E.01636
G1 X138.445 Y133.094 E.02152
G1 X138.926 Y133.522 E.01979
G1 X139.485 Y134.312 E.02973
G3 X139.951 Y136.114 I-3.752 J1.932 E.05768
G1 X139.896 Y136.734 E.01913
G1 X139.78 Y137.188 E.0144
G1 X142.56 Y134.408 E.12081
G1 X139.017 Y130.865 E.15395
G1 X137.398 Y132.484 E.07033
G1 X138.025 Y132.39 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X138.661 Y132.785 E.02299
G1 X139.19 Y133.253 E.0217
G3 X140.056 Y134.681 I-3.403 J3.043 E.05161
G1 X140.259 Y135.383 E.02246
G1 X140.327 Y136.108 E.02237
G1 X142.027 Y134.408 E.07386
G1 X139.017 Y131.399 E.13078
G1 X138.068 Y132.348 E.04126
G1 X138.682 Y132.306 F36000
; LINE_WIDTH: 0.460686
G1 F15000
G1 X139.215 Y132.728 E.02316
G1 X139.718 Y133.26 E.02491
; LINE_WIDTH: 0.429622
G3 X140.535 Y134.913 I-4.735 J3.37 E.05836
G1 X140.621 Y135.281 E.0119
G1 X141.493 Y134.408 E.0389
G3 X139.502 Y132.439 I654.523 J-663.743 E.08826
; LINE_WIDTH: 0.467569
G1 F14835.788
G1 X139.017 Y131.971 E.02332
G1 X138.725 Y132.263 E.01431
G1 X140.879 Y134.35 F36000
; LINE_WIDTH: 0.58192
G1 F11688.313
G2 X140.883 Y134.46 I-.029 J.056 E.01159
G1 X144.551 Y134.737 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X144.468 Y134.654 E.00388
G1 X143.399 Y135.723 E.05014
G1 X145.516 Y137.841 E.09933
G1 X145.147 Y138.21 E.01731
G1 X146.817 Y139.879 E.07832
G1 X139.879 Y146.817 E.32547
G1 X138.209 Y145.147 E.07833
G1 X137.841 Y145.516 E.01731
G1 X105.526 Y113.202 E1.51593
G1 X105.895 Y112.833 E.01731
G1 X105.337 Y112.275 E.02617
G1 X107.242 Y110.37 E.08937
G1 X106.8 Y109.959 E.02003
G1 X108.38 Y108.38 E.07411
G1 X104.52 Y104.52 E.18104
G1 X105.963 Y103.078 E.06767
G1 X105.433 Y102.548 E.02488
G1 X106.713 Y101.268 E.06006
G1 X103.853 Y98.408 E.13416
G1 X104.599 Y97.661 E.03501
G1 X108.437 Y101.499 E.18005
G1 X101.499 Y108.437 E.32547
G1 X97.661 Y104.599 E.18005
G1 X98.408 Y103.853 E.03502
G1 X99.559 Y105.004 E.05401
; WIPE_START
G1 X98.408 Y103.853 E-.61876
G1 X98.145 Y104.116 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X103.486 Y109.568 Z1.8 F36000
G1 X144.868 Y151.806 Z1.8
G1 Z1.4
G1 E.8 F1800
G1 F15476.087
G1 X143.717 Y150.655 E.05401
G1 X150.655 Y143.717 E.32547
G1 X149.504 Y142.566 E.05401
; WIPE_START
G1 X150.655 Y143.717 E-.61876
G1 X150.392 Y143.98 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X149.341 Y151.54 Z1.8 F36000
G1 X148.392 Y158.37 Z1.8
G1 Z1.4
G1 E.8 F1800
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X149.135 Y156.073 E.01731
G1 X147.555 Y154.493 E.07411
G1 X154.493 Y147.555 E.32547
G1 X156.073 Y149.135 E.07411
G1 X156.442 Y148.766 E.01731
G1 X157.219 Y149.543 E.03647
G1 X154.123 Y152.639 E.14523
G1 X155.604 Y154.12 E.06947
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X139.561 Y139.561 E.74783
G3 X139.138 Y139.882 I-.603 J-.356 E.01807
G1 X134.603 Y144.417 E.21273
G1 X130.765 Y140.579 E.18005
G1 X132.557 Y138.787 E.08405
G1 X133.708 Y139.939 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 1.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X132.557 Y138.787 E-.61876
G1 X132.294 Y139.05 E-.14124
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
G1 X133.868 Y127.36
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X127.36 Y133.868 E.30532
G1 X124.246 Y130.754 E.14609
G1 X130.754 Y124.246 E.30532
G1 X133.826 Y127.317 E.1441
G1 X133.314 Y127.36 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X127.36 Y133.314 E.25872
G1 X124.8 Y130.754 E.11123
G1 X130.754 Y124.8 E.25872
G1 X133.271 Y127.317 E.10939
; WIPE_START
M204 S10000
G1 X131.867 Y128.742 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.853 Y135.825 Z2 F36000
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.863 Y135.723 E.00341
G3 X136.042 Y133.828 I2.264 J.404 E.10354
G1 X136.134 Y133.826 E.00305
G3 X133.827 Y136.134 I-.006 J2.3 E.35912
G1 X133.848 Y135.885 E.00829
G1 X134.241 Y135.845 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.312 Y135.539 E.00964
G3 X136.062 Y134.22 I1.815 J.587 E.07174
G1 X136.127 Y134.219 E.00199
G3 X134.233 Y135.904 I.001 J1.908 E.28316
; WIPE_START
M204 S10000
G1 X134.312 Y135.539 E-.14198
G1 X134.411 Y135.292 E-.10121
G1 X134.509 Y135.115 E-.0767
G1 X134.708 Y134.851 E-.12572
G1 X134.851 Y134.708 E-.07673
G1 X135.061 Y134.544 E-.10122
G1 X135.292 Y134.411 E-.10123
G1 X135.378 Y134.378 E-.0352
; WIPE_END
G1 E-.04 F1800
G1 X128.558 Y130.952 Z2 F36000
G1 X120.289 Y126.797 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X117.175 Y123.683 E.14609
G1 X122.904 Y117.954 E.26876
G1 X123.683 Y117.175 E.03656
G1 X126.797 Y120.289 E.14609
G1 X120.331 Y126.755 E.30333
G1 X120.289 Y126.243 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X117.729 Y123.683 E.11123
G1 X123.181 Y118.231 E.23691
G1 X123.683 Y117.729 E.02182
G1 X126.243 Y120.289 E.11123
G1 X120.331 Y126.2 E.25688
; WIPE_START
M204 S10000
G1 X118.894 Y124.81 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X115.983 Y117.754 Z2 F36000
G1 X113.951 Y112.828 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X113.984 Y112.81 E.00125
G3 X114.829 Y112.615 I.931 J2.104 E.02894
G1 X114.921 Y112.613 E.00305
G3 X113.623 Y113.01 I-.006 J2.3 E.43373
G1 X113.898 Y112.857 E.01046
G1 X114.086 Y113.199 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X114.137 Y113.171 E.00179
G3 X114.849 Y113.006 I.777 J1.743 E.02259
G1 X114.914 Y113.005 E.00199
G3 X113.848 Y113.331 I.001 J1.908 E.33363
G1 X114.034 Y113.228 E.00653
; WIPE_START
M204 S10000
G1 X114.137 Y113.171 E-.04495
G1 X114.388 Y113.08 E-.10129
G1 X114.584 Y113.034 E-.07665
G1 X114.849 Y113.006 E-.10126
G1 X114.914 Y113.005 E-.02455
G1 X115.179 Y113.024 E-.1012
G1 X115.378 Y113.062 E-.07674
G1 X115.69 Y113.17 E-.12567
G1 X115.926 Y113.295 E-.10121
G1 X115.939 Y113.305 E-.00647
; WIPE_END
G1 E-.04 F1800
G1 X109.288 Y109.56 Z2 F36000
G1 X98.578 Y103.53 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X101.268 Y106.22 E.12619
G1 X102.754 Y104.734 E.06974
G1 X103.285 Y105.264 E.02488
G1 X105.264 Y103.285 E.09286
G1 X104.734 Y102.754 E.02488
G1 X106.22 Y101.268 E.06974
G1 X103.53 Y98.578 E.12619
G1 X102.044 Y100.064 E.06974
G1 X100.526 Y98.547 E.07118
G1 X103.216 Y95.857 E.12617
G1 X105.758 Y98.4 E.11927
G1 X112.797 Y105.439 E.33021
G1 X114.248 Y103.988 E.06806
G1 X120.554 Y110.294 E.29582
G1 X147.055 Y136.795 E1.24321
G1 X145.604 Y138.245 E.06806
G1 X156.037 Y148.678 E.48942
G1 X158.92 Y145.795 E.13526
G1 X160.19 Y147.065 E.05957
G1 X154.616 Y152.639 E.2615
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.065 Y160.19 E.2615
G1 X145.795 Y158.92 E.05957
G1 X148.678 Y156.037 E.13526
G1 X138.245 Y145.604 E.48942
G1 X136.795 Y147.055 E.06806
G1 X103.988 Y114.248 E1.53904
G1 X105.439 Y112.797 E.06806
G1 X95.857 Y103.216 E.44948
G1 X98.547 Y100.526 E.12618
G1 X100.064 Y102.044 E.07118
G1 X98.62 Y103.488 E.06775
G1 X99.132 Y103.53 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X99.288 Y103.686 E.00676
G1 F11434.489
G1 X99.571 Y103.969 E.01229
G1 F10147.62
G1 X99.853 Y104.252 E.01229
G1 F8937.551
G1 X100.136 Y104.534 E.01229
G1 F7804.282
G1 X100.419 Y104.817 E.01229
G1 F6747.813
G1 X100.702 Y105.1 E.01229
G1 F5768.145
G1 X100.985 Y105.383 E.01229
G1 F4865.276
G1 X101.268 Y105.666 E.01229
G1 F4039.207
G1 X101.445 Y105.488 E.00773
G1 F3559.238
G1 X101.728 Y105.205 E.01229
G1 F2858.247
G1 X102.011 Y104.922 E.01229
G1 F2234.056
G1 X102.294 Y104.639 E.01229
G1 F1686.665
G1 X102.577 Y104.357 E.01229
G1 F1216.074
G1 X102.754 Y104.179 E.00771
G1 F960
G1 X103.256 Y104.68 E.02179
G1 F999.762
G1 X103.285 Y104.709 E.00126
G1 F1430.033
G1 X103.567 Y104.427 E.01229
G1 F1937.105
G1 X103.85 Y104.144 E.01229
G1 F2230.505
G1 X104.133 Y103.861 E.01229
G1 F1957.823
G1 X104.427 Y103.567 E.01276
G1 F1430.033
G1 X104.709 Y103.285 E.01229
G1 F999.762
G1 X104.68 Y103.256 E.00126
G1 F960
G1 X104.179 Y102.754 E.02179
G1 F1216.067
G1 X104.357 Y102.577 E.00771
G1 F1686.656
G1 X104.639 Y102.294 E.01229
G1 F2234.046
G1 X104.922 Y102.011 E.01229
G1 F2858.236
G1 X105.205 Y101.728 E.01229
G1 F3559.225
G1 X105.488 Y101.445 E.01229
G1 F4039.193
G1 X105.666 Y101.268 E.00773
G1 F4865.26
G1 X105.383 Y100.985 E.01229
G1 F5768.128
G1 X105.1 Y100.702 E.01229
G1 F6747.795
G1 X104.817 Y100.419 E.01229
G1 F7559.816
G1 X104.534 Y100.136 E.01229
G1 F7319.32
G1 X104.379 Y99.981 E.00676
G1 F6747.777
G1 X104.096 Y99.698 E.01229
G1 F5768.111
G1 X103.813 Y99.415 E.01229
G1 F4865.245
G1 X103.53 Y99.132 E.01229
G1 F4039.179
G1 X103.353 Y99.31 E.00773
G1 F3559.212
G1 X103.07 Y99.593 E.01229
G1 F2858.224
G1 X102.787 Y99.876 E.01229
G1 F2234.036
G1 X102.504 Y100.158 E.01229
G1 F1686.647
G1 X102.221 Y100.441 E.01229
G1 F1216.059
G1 X102.044 Y100.619 E.00771
G1 F960
G1 X99.972 Y98.547 E.09003
G1 F1216.074
G1 X100.149 Y98.369 E.00771
G1 F1686.665
G1 X100.432 Y98.087 E.01229
G1 F2234.056
G1 X100.715 Y97.804 E.01229
G1 F2858.247
G1 X100.998 Y97.521 E.01229
G1 F3559.238
G1 X101.281 Y97.238 E.01229
G1 F4337.029
G1 X101.564 Y96.955 E.01229
G1 F5191.62
G1 X101.846 Y96.672 E.01229
G1 F6123.011
G1 X102.129 Y96.39 E.01229
G1 F7131.202
G1 X102.412 Y96.107 E.01229
G1 F8216.193
G1 X102.695 Y95.824 E.01229
G1 F9377.984
G1 X102.978 Y95.541 E.01229
G1 F10415.977
G1 X103.216 Y95.303 E.01035
G1 F11719.246
G1 X103.499 Y95.586 E.01229
G1 F12000
G1 X103.782 Y95.869 E.01229
G1 X106.036 Y98.123 E.09795
G1 X112.797 Y104.884 E.29382
G1 X114.248 Y103.433 E.06305
G1 X120.831 Y110.016 E.28607
G1 X147.609 Y136.795 E1.16364
G1 X146.159 Y138.245 E.06305
G1 X156.037 Y148.124 E.42926
G1 X158.92 Y145.24 E.1253
G1 X160.744 Y147.065 E.07928
G1 X155.17 Y152.639 E.24222
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.065 Y160.744 E.24222
G1 X145.24 Y158.92 E.07928
G1 X148.124 Y156.037 E.1253
G1 X138.245 Y146.159 E.42926
G1 X136.795 Y147.609 E.06305
G1 X103.433 Y114.248 E1.44971
G1 X104.884 Y112.797 E.06305
M73 P58 R7
G1 X95.869 Y103.782 E.39177
G1 X95.586 Y103.499 E.01229
G1 F11719.317
G1 X95.303 Y103.216 E.01229
G1 F10416.044
G1 X95.541 Y102.978 E.01035
G1 F9378.005
G1 X95.824 Y102.695 E.01229
G1 F8216.213
G1 X96.107 Y102.412 E.01229
G1 F7131.221
G1 X96.39 Y102.129 E.01229
G1 F6123.028
G1 X96.672 Y101.846 E.01229
G1 F5191.636
G1 X96.955 Y101.564 E.01229
G1 F4337.044
G1 X97.238 Y101.281 E.01229
G1 F3559.251
G1 X97.521 Y100.998 E.01229
G1 F2858.259
G1 X97.804 Y100.715 E.01229
G1 F2234.067
G1 X98.087 Y100.432 E.01229
G1 F1686.674
G1 X98.369 Y100.149 E.01229
G1 F1216.082
G1 X98.547 Y99.972 E.00771
G1 F960
G1 X100.619 Y102.044 E.09003
G1 F1216.067
G1 X100.441 Y102.221 E.00771
G1 F1686.656
G1 X100.158 Y102.504 E.01229
G1 F2234.046
G1 X99.876 Y102.787 E.01229
G1 F2858.236
G1 X99.593 Y103.07 E.01229
G1 F3921.881
G1 X99.175 Y103.488 E.01817
; WIPE_START
M204 S10000
G1 X99.288 Y103.686 E-.08665
G1 X99.571 Y103.969 E-.152
G1 X99.853 Y104.252 E-.152
G1 X100.136 Y104.534 E-.152
G1 X100.419 Y104.817 E-.152
G1 X100.541 Y104.939 E-.06535
; WIPE_END
G1 E-.04 F1800
G1 X96.349 Y103.216 Z2 F36000
G1 Z1.6
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X105.672 Y112.539 E.3653
; Slow Down End
G1 X106.609 Y116.377 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X107.76 Y117.528 E.05401
G1 X110.347 Y114.942 E.12133
G1 X111.183 Y111.819 E.10724
G3 X111.481 Y111.482 I.779 J.387 E.01511
G1 X104.52 Y104.521 E.32655
G1 X103.285 Y105.756 E.05798
G1 X102.754 Y105.226 E.02488
G1 X101.268 Y106.713 E.06974
G1 X98.408 Y103.853 E.13416
G1 X97.942 Y104.318 E.02183
G1 X101.78 Y108.156 E.18005
G1 X108.156 Y101.78 E.29911
G1 X104.318 Y97.942 E.18005
G1 X103.853 Y98.408 E.02183
G1 X103.53 Y98.085 E.01514
G1 X102.702 Y98.914 E.03888
G1 X103.216 Y96.349 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X111.942 Y105.075 E.3419
; Slow Down End
G1 F12000
G1 X112.539 Y105.672 E.0234
G1 X116.231 Y106.463 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X116.309 Y106.541 E.00366
G1 X116.287 Y106.676 E.00454
G1 X115.319 Y107.644 E.04539
G1 X113.202 Y105.526 E.09933
G3 X112.779 Y106.062 I-7.706 J-5.658 E.02265
G1 X112.438 Y106.062 E.01131
G1 X111.994 Y105.618 E.0208
G1 X105.618 Y111.994 E.29911
G1 X106.062 Y112.438 E.0208
G3 X105.702 Y113.027 I-.451 J.129 E.02573
G1 X105.526 Y113.202 E.00823
G1 X137.841 Y145.516 E1.51593
G3 X138.264 Y144.981 I7.578 J5.559 E.02266
G1 X138.605 Y144.981 E.0113
G1 X140.16 Y146.536 E.07296
G1 X146.536 Y140.16 E.29911
G1 X144.981 Y138.605 E.07296
G3 X145.341 Y138.016 I.451 J-.129 E.02573
G1 X145.516 Y137.841 E.00823
G1 X143.399 Y135.723 E.09933
G1 X144.367 Y134.756 E.04539
G1 X144.502 Y134.734 E.00454
G1 X144.58 Y134.812 E.00366
G1 X144.14 Y134.434 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X137.822 Y128.116 E.27457
G1 X132.765 Y133.179 E.21989
G2 X131.653 Y137.322 I1373.939 J370.835 E.13178
G2 X134.924 Y140.6 I165.488 J-161.844 E.1423
G2 X139.072 Y139.494 I-53.829 J-210.205 E.1319
G2 X144.095 Y134.473 I-1105.121 J-1110.56 E.21822
G1 X143.604 Y134.431 F36000
G1 F12000
G1 X137.825 Y128.652 E.25111
G1 X133.101 Y133.376 E.20528
G1 X132.895 Y134.144 E.02443
; LINE_WIDTH: 0.439169
G1 X132.9 Y134.2 E.00181
; LINE_WIDTH: 0.477527
G1 X132.905 Y134.256 E.00199
; LINE_WIDTH: 0.515884
G1 X132.91 Y134.312 E.00216
; LINE_WIDTH: 0.543043
G1 X132.914 Y134.368 E.00228
G2 X132.486 Y135.942 I12.701 J4.303 E.06654
; LINE_WIDTH: 0.537115
G1 X132.443 Y136.012 E.00332
; LINE_WIDTH: 0.490265
G1 X132.4 Y136.082 E.003
; LINE_WIDTH: 0.420843
G1 X132.357 Y136.153 E.00254
G1 X132.072 Y137.215 E.03386
G1 X132.838 Y137.98 E.03335
; LINE_WIDTH: 0.443444
G1 X132.914 Y138.023 E.00286
; LINE_WIDTH: 0.49035
G1 X132.99 Y138.066 E.00319
; LINE_WIDTH: 0.534193
G1 X133.066 Y138.109 E.0035
G2 X134.005 Y139.063 I10.261 J-9.162 E.05357
; LINE_WIDTH: 0.519774
G1 X134.177 Y139.263 E.01025
; LINE_WIDTH: 0.47986
G1 X134.349 Y139.463 E.00939
; LINE_WIDTH: 0.422576
G2 X135.041 Y140.184 I5.096 J-4.203 E.03096
G1 X136.042 Y139.916 E.03204
; LINE_WIDTH: 0.44211
G1 X136.148 Y139.864 E.00386
; LINE_WIDTH: 0.48635
G1 X136.255 Y139.813 E.00429
; LINE_WIDTH: 0.535209
G1 X136.362 Y139.761 E.00476
G2 X137.724 Y139.397 I-3.038 J-14.099 E.05658
; LINE_WIDTH: 0.528974
G1 X137.919 Y139.367 E.00781
; LINE_WIDTH: 0.48538
G1 X138.114 Y139.338 E.00711
; LINE_WIDTH: 0.42057
G1 X138.309 Y139.308 E.00607
G1 X138.88 Y139.155 E.01819
G1 X143.561 Y134.473 E.20375
; WIPE_START
G1 X142.147 Y135.888 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.526 Y135.47 Z2 F36000
G1 X133.532 Y135.415 Z2
G1 Z1.6
G1 E.8 F1800
; LINE_WIDTH: 0.41999
G1 F12000
G1 X133.828 Y134.727 E.02302
G1 X134.138 Y134.312 E.01592
G1 X134.418 Y134.048 E.01183
G1 X134.923 Y133.72 E.0185
G1 X135.412 Y133.532 E.0161
G1 X136.007 Y133.438 E.01851
G1 X136.422 Y133.45 E.01275
G1 X137.024 Y133.593 E.01902
G1 X137.251 Y133.681 E.00748
G1 X137.842 Y134.051 E.02144
G1 X138.149 Y134.349 E.01315
G1 X138.538 Y134.928 E.02143
G1 X138.697 Y135.321 E.01303
G1 X138.812 Y135.913 E.01851
G1 X138.803 Y136.434 E.01603
G1 X138.668 Y137.023 E.01857
G1 X138.452 Y137.49 E.01581
G1 X138.233 Y137.807 E.01183
G1 X137.807 Y138.233 E.0185
G1 X137.38 Y138.513 E.0157
G1 X137.02 Y138.668 E.01205
G1 X136.337 Y138.812 E.02143
G1 X135.909 Y138.811 E.01315
G1 X135.229 Y138.666 E.02137
G1 X134.645 Y138.376 E.02004
G1 X134.251 Y138.061 E.0155
G1 X133.807 Y137.493 E.02215
G1 X133.521 Y136.802 E.02296
G1 X133.435 Y136.155 E.02005
G1 X133.524 Y135.475 E.02109
G1 X133.11 Y135.357 F36000
; LINE_WIDTH: 0.531413
G1 F12000
G1 X133.262 Y134.95 E.01727
; LINE_WIDTH: 0.559418
G1 X133.413 Y134.544 E.01826
; LINE_WIDTH: 0.554242
G1 X133.447 Y134.524 E.00164
; LINE_WIDTH: 0.515884
G1 X133.481 Y134.503 E.00152
; LINE_WIDTH: 0.477527
G1 X133.515 Y134.483 E.0014
; LINE_WIDTH: 0.420062
G1 X133.549 Y134.463 E.00121
G1 X133.877 Y134.04 E.01645
G1 X134.212 Y133.732 E.01401
G1 X134.717 Y133.403 E.01851
G1 X135.239 Y133.19 E.01731
G1 X135.948 Y133.065 E.02213
G1 X136.494 Y133.08 E.01677
G1 X137.017 Y133.189 E.01645
G1 X137.451 Y133.361 E.01434
G1 X138.042 Y133.732 E.02144
G1 X138.462 Y134.139 E.01797
G1 X138.851 Y134.718 E.02144
G1 X139.067 Y135.249 E.01764
G1 X139.183 Y135.841 E.01851
G1 X139.185 Y136.402 E.01725
G1 X139.035 Y137.108 E.02218
G1 X138.809 Y137.624 E.01732
G1 X138.5 Y138.074 E.01677
G1 X138.074 Y138.5 E.01851
; LINE_WIDTH: 0.44259
G1 X137.854 Y138.677 E.00922
; LINE_WIDTH: 0.48779
G1 X137.633 Y138.855 E.01026
; LINE_WIDTH: 0.532468
G1 X137.556 Y138.92 E.00403
G1 X137.108 Y139.086 E.01905
G3 X136.297 Y139.26 I-1.78 J-6.313 E.03312
; LINE_WIDTH: 0.53059
G1 X135.968 Y139.196 E.01329
; LINE_WIDTH: 0.48635
G1 X135.64 Y139.133 E.01209
; LINE_WIDTH: 0.431453
G3 X135.012 Y138.986 I.597 J-3.962 E.02044
; LINE_WIDTH: 0.441225
G1 X134.733 Y138.868 E.00982
; LINE_WIDTH: 0.483695
G1 X134.455 Y138.75 E.01087
; LINE_WIDTH: 0.525949
G1 X134.337 Y138.694 E.00513
G1 X133.951 Y138.361 E.02007
; LINE_WIDTH: 0.537365
G1 X133.454 Y137.767 E.03119
; LINE_WIDTH: 0.537257
G1 X133.446 Y137.708 E.00243
; LINE_WIDTH: 0.49035
G1 X133.439 Y137.648 E.0022
; LINE_WIDTH: 0.420929
G1 X133.431 Y137.588 E.00185
G1 X133.172 Y136.943 E.02142
G1 X133.061 Y136.202 E.02309
; LINE_WIDTH: 0.443415
G1 X133.038 Y136.149 E.00186
; LINE_WIDTH: 0.490265
G1 X133.015 Y136.097 E.00208
; LINE_WIDTH: 0.538823
G1 X132.992 Y136.045 E.00231
G1 X133.1 Y135.416 E.02578
G1 X132.704 Y136.246 F36000
; LINE_WIDTH: 0.37834
G1 F12000
G2 X132.47 Y137.108 I80.871 J22.448 E.02443
G1 X133.125 Y137.764 E.02535
G1 X132.841 Y137.076 E.02034
G1 X132.714 Y136.305 E.02137
G1 X134.494 Y139.126 F36000
; LINE_WIDTH: 0.38679
G1 F12000
G1 X135.149 Y139.782 E.02596
G1 X136.001 Y139.553 E.02472
G1 X135.236 Y139.422 E.02175
G3 X134.547 Y139.154 I.38 J-1.997 E.02083
; WIPE_START
G1 X134.849 Y139.307 E-.12851
G1 X135.236 Y139.422 E-.15359
G1 X136.001 Y139.553 E-.29493
G1 X135.536 Y139.678 E-.18297
; WIPE_END
G1 E-.04 F1800
G1 X141.799 Y135.316 Z2 F36000
G1 X143.07 Y134.431 Z2
G1 Z1.6
G1 E.8 F1800
; LINE_WIDTH: 0.41904
G1 F12000
G1 X137.825 Y129.185 E.22737
G1 X134.248 Y132.762 E.15502
G1 X133.808 Y133.173 E.01847
; LINE_WIDTH: 0.367226
G1 X133.444 Y133.527 E.0134
G2 X133.191 Y134.388 I14.691 J4.784 E.02372
G1 X133.538 Y133.897 E.01588
G1 X134.018 Y133.433 E.01765
; LINE_WIDTH: 0.411041
G1 X134.512 Y133.087 E.01807
G1 X135.104 Y132.838 E.01926
G1 X135.889 Y132.693 E.02397
G1 X136.416 Y132.693 E.01581
G1 X137.003 Y132.795 E.01785
G1 X137.651 Y133.042 E.02082
G1 X138.243 Y133.412 E.02093
G1 X138.649 Y133.778 E.01641
G1 X139.164 Y134.507 E.02678
G1 X139.387 Y135.007 E.0164
G1 X139.553 Y135.769 E.02339
G1 X139.562 Y136.408 E.0192
G1 X139.403 Y137.192 E.02399
G1 X139.15 Y137.783 E.01927
G1 X138.749 Y138.323 E.02018
G1 X138.324 Y138.749 E.01807
G1 X137.888 Y139.056 E.016
G1 X138.697 Y138.839 E.02514
G2 X139.485 Y138.017 I-13.861 J-14.064 E.03415
G1 X143.028 Y134.473 E.15032
G1 X142.537 Y134.431 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X137.825 Y129.719 E.20477
G1 X135.09 Y132.453 E.11883
G1 X135.83 Y132.32 E.02311
G1 X136.428 Y132.316 E.01838
G1 X137.075 Y132.425 E.02013
G1 X137.605 Y132.602 E.01719
G1 X138.443 Y133.093 E.02983
G1 X138.912 Y133.508 E.01924
G1 X139.477 Y134.297 E.02983
G1 X139.737 Y134.866 E.01923
G1 X139.923 Y135.696 E.02614
G1 X139.939 Y136.415 E.02209
G1 X139.794 Y137.174 E.02376
G1 X142.495 Y134.473 E.11737
G1 X142.004 Y134.431 F36000
G1 F12000
G1 X137.825 Y130.252 E.1816
G1 X136.147 Y131.93 E.07291
G1 X136.709 Y131.97 E.01733
G1 X137.407 Y132.127 E.02198
G1 X138.052 Y132.403 E.02155
G1 X138.643 Y132.773 E.02144
G1 X139.175 Y133.237 E.02167
G1 X139.401 Y133.508 E.01084
G1 X139.79 Y134.086 E.02143
G1 X140.087 Y134.726 E.02166
G1 X140.293 Y135.624 E.02833
G1 X140.322 Y136.113 E.01505
G1 X141.961 Y134.473 E.07126
G1 X141.471 Y134.431 F36000
; LINE_WIDTH: 0.427732
G1 F12000
G3 X137.825 Y130.785 I189.366 J-193.012 E.16168
G1 X136.973 Y131.637 E.03777
G1 X137.537 Y131.773 E.01818
G1 X138.252 Y132.083 E.02445
G1 X138.855 Y132.435 E.02189
G1 X139.442 Y132.962 E.02472
G1 X139.728 Y133.288 E.0136
G1 X140.103 Y133.876 E.02188
G1 X140.437 Y134.585 E.02459
G1 X140.612 Y135.29 E.02276
G1 X141.428 Y134.473 E.0362
G1 X140.88 Y134.377 F36000
; LINE_WIDTH: 0.5453
G1 F12000
G2 X140.882 Y134.483 I-.026 J.054 E.00992
G1 X137.856 Y131.354 F36000
; LINE_WIDTH: 0.54804
G1 F12000
G2 X137.858 Y131.461 I-.026 J.054 E.01004
G1 X145.328 Y138.461 F36000
; Slow Down Start
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X155.779 Y148.912 E.40947
; Slow Down End
G1 X149.223 Y142.847 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X150.374 Y143.998 E.05401
G1 X143.998 Y150.374 E.29911
G1 X142.847 Y149.223 E.05401
G1 X138.461 Y145.328 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X148.912 Y155.779 E.40947
; Slow Down End
; WIPE_START
G1 X147.497 Y154.365 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X141.517 Y149.622 Z2 F36000
G1 X133.475 Y143.243 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X134.626 Y144.394 E.05401
G1 X139.138 Y139.882 E.21167
G2 X139.561 Y139.561 I-.18 J-.677 E.01806
G1 X155.502 Y155.502 E.74784
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G3 X156.018 Y149.301 I-7.593 J-5.571 E.02266
G1 X155.677 Y149.301 E.0113
G1 X154.212 Y147.836 E.06874
G1 X147.836 Y154.212 E.29911
G1 X149.301 Y155.677 E.06874
G3 X148.941 Y156.266 I-.451 J.129 E.02573
G1 X148.766 Y156.442 E.00823
G1 X149.543 Y157.219 E.03647
G1 X148.392 Y158.37 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X143.941 Y151.502 Z2 F36000
G1 X117.971 Y124.972 Z2
G1 Z1.6
G1 E.8 F1800
G1 F15476.087
G1 X116.82 Y123.821 E.05401
G1 X115.436 Y125.204 E.0649
G1 X111.598 Y121.366 E.18005
G1 X113.367 Y119.597 E.08298
G2 X113.721 Y119.795 I.348 J-.208 E.01409
G1 X118.01 Y118.646 E.1473
G2 X118.348 Y118.348 I-.387 J-.779 E.01511
G1 X120.182 Y120.182 E.08606
G1 X123.683 Y116.682 E.16421
G1 X123.821 Y116.82 E.00646
G1 X125.204 Y115.436 E.0649
G1 X123.288 Y113.521 E.08987
G1 X123.154 Y113.542 E.00452
G1 X122.186 Y114.51 E.0454
G1 X136.533 Y128.857 E.67304
G1 X137.501 Y127.889 E.04541
G1 X137.522 Y127.754 E.00451
G1 X136.718 Y126.95 E.03773
G1 X126.95 Y136.718 E.45823
G1 X130.788 Y140.556 E.18005
G1 X132.557 Y138.787 E.08298
G1 X131.304 Y137.535 E.05876
G1 X131.247 Y137.322 E.00732
G1 X132.397 Y133.032 E.1473
G3 X132.695 Y132.695 I.779 J.387 E.01511
G1 X130.86 Y130.86 E.08606
G1 X127.36 Y134.361 E.16421
G1 X124.496 Y131.497 E.13436
G1 X123.112 Y132.88 E.0649
G1 X119.274 Y129.042 E.18005
G1 X129.042 Y119.274 E.45823
G1 X132.88 Y123.112 E.18005
G1 X131.497 Y124.496 E.0649
G1 X130.754 Y123.753 E.03484
G1 X127.254 Y127.254 E.16421
G1 X123.789 Y123.789 E.16252
G1 X124.941 Y122.638 E.05401
; WIPE_START
G1 X123.789 Y123.789 E-.61876
G1 X124.052 Y124.052 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X123.263 Y116.46 Z2 F36000
G1 X122.927 Y113.221 Z2
G1 Z1.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X116.608 Y106.902 E.27457
G1 X111.551 Y111.966 E.21989
G2 X110.44 Y116.108 I1179.89 J318.776 E.13178
G2 X113.711 Y119.387 I165.844 J-162.198 E.1423
G2 X117.859 Y118.281 I-53.5 J-208.966 E.1319
G2 X122.882 Y113.26 I-1321.582 J-1327.113 E.21822
G1 X122.39 Y113.218 F36000
G1 F12000
G1 X116.612 Y107.439 E.25111
G1 X111.887 Y112.163 E.20528
G1 X111.673 Y112.964 E.02548
; LINE_WIDTH: 0.438195
G1 X111.636 Y113.171 E.00677
; LINE_WIDTH: 0.474605
G1 X111.6 Y113.378 E.00739
; LINE_WIDTH: 0.520688
G3 X111.402 Y114.167 I-4.227 J-.641 E.03172
; LINE_WIDTH: 0.54141
G1 X111.263 Y114.773 E.02528
; LINE_WIDTH: 0.539949
G1 X111.221 Y114.834 E.00298
; LINE_WIDTH: 0.491965
G1 X111.18 Y114.895 E.00269
; LINE_WIDTH: 0.421046
G1 X111.139 Y114.956 E.00227
G1 X110.859 Y116.001 E.03334
G1 X111.225 Y116.367 E.01595
; LINE_WIDTH: 0.43331
G1 X111.48 Y116.604 E.01107
; LINE_WIDTH: 0.45995
G1 X111.735 Y116.84 E.01182
; LINE_WIDTH: 0.492025
G1 X111.831 Y116.909 E.0043
; LINE_WIDTH: 0.530105
G1 X111.926 Y116.978 E.00467
G2 X112.792 Y117.849 I10.09 J-9.154 E.04879
; LINE_WIDTH: 0.519765
G1 X112.964 Y118.05 E.01025
; LINE_WIDTH: 0.479855
G1 X113.136 Y118.25 E.00939
; LINE_WIDTH: 0.423017
G2 X113.828 Y118.97 I5.096 J-4.203 E.03099
G1 X114.542 Y118.779 E.0229
; LINE_WIDTH: 0.432525
G1 X114.831 Y118.689 E.0096
; LINE_WIDTH: 0.457595
G1 X115.119 Y118.598 E.01022
; LINE_WIDTH: 0.48705
G1 X115.225 Y118.553 E.00419
; LINE_WIDTH: 0.530393
G1 X115.332 Y118.507 E.00459
G2 X116.511 Y118.184 I-3.135 J-13.773 E.04858
; LINE_WIDTH: 0.528957
G1 X116.706 Y118.154 E.00781
; LINE_WIDTH: 0.48537
G1 X116.901 Y118.125 E.00711
; LINE_WIDTH: 0.42057
G1 X117.095 Y118.095 E.00607
G1 X117.666 Y117.942 E.01819
G1 X122.348 Y113.26 E.20375
; WIPE_START
G1 X120.934 Y114.675 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X113.305 Y114.452 Z2 F36000
G1 X112.267 Y114.422 Z2
G1 Z1.6
G1 E.8 F1800
; LINE_WIDTH: 0.41999
G1 F12000
G1 X112.443 Y113.844 E.01857
G1 X112.691 Y113.393 E.01581
G1 X112.933 Y113.091 E.0119
G1 X113.388 Y112.696 E.0185
G1 X114.054 Y112.364 E.02286
G1 X114.79 Y112.225 E.02302
G1 X115.32 Y112.253 E.01631
G1 X115.99 Y112.446 E.02142
G1 X116.627 Y112.837 E.02296
G1 X117.077 Y113.31 E.02006
G1 X117.348 Y113.762 E.01621
G1 X117.562 Y114.426 E.02143
G1 X117.595 Y115.172 E.02296
G1 X117.455 Y115.81 E.02005
G1 X117.111 Y116.472 E.02293
G3 X116.563 Y117.045 I-9.134 J-8.184 E.02434
G3 X115.806 Y117.455 I-1.61 J-2.068 E.02657
G1 X115.126 Y117.599 E.02137
G1 X114.474 Y117.571 E.02006
G1 X113.97 Y117.437 E.01603
G1 X113.432 Y117.163 E.01856
G1 X113.038 Y116.848 E.0155
G1 X112.644 Y116.363 E.01919
G1 X112.335 Y115.686 E.02285
G1 X112.222 Y114.946 E.02303
G1 X112.261 Y114.482 E.0143
G1 X111.859 Y114.298 F36000
; LINE_WIDTH: 0.526108
G1 F12000
G3 X112.076 Y113.596 I5.482 J1.306 E.02896
; LINE_WIDTH: 0.521657
G1 X112.182 Y113.451 E.00702
; LINE_WIDTH: 0.48099
G1 X112.289 Y113.306 E.00642
; LINE_WIDTH: 0.420342
G3 X113.141 Y112.412 I3.467 J2.452 E.03812
G1 X113.888 Y112.025 E.02587
G1 X114.724 Y111.854 E.02624
G1 X115.297 Y111.869 E.01765
G1 X116.069 Y112.077 E.02459
G1 X116.827 Y112.517 E.02695
G1 X117.353 Y113.052 E.02307
G1 X117.654 Y113.529 E.01733
G1 X117.921 Y114.31 E.0254
G1 X117.972 Y115.16 E.02617
G1 X117.822 Y115.894 E.02306
G1 X117.444 Y116.649 E.02596
G1 X117.024 Y117.117 E.01935
; LINE_WIDTH: 0.442595
G1 X116.722 Y117.379 E.01303
; LINE_WIDTH: 0.487805
G1 X116.42 Y117.642 E.0145
; LINE_WIDTH: 0.53109
G1 X116.342 Y117.706 E.00402
G1 X115.895 Y117.873 E.019
G1 X115.216 Y118.025 E.02766
; LINE_WIDTH: 0.518174
G1 X114.962 Y118 E.00989
; LINE_WIDTH: 0.4789
G1 X114.708 Y117.974 E.00907
; LINE_WIDTH: 0.426129
G1 X114.454 Y117.948 E.00797
G1 X113.909 Y117.815 E.01753
; LINE_WIDTH: 0.44122
G1 X113.575 Y117.676 E.01174
; LINE_WIDTH: 0.48368
G1 X113.242 Y117.537 E.01299
; LINE_WIDTH: 0.528607
G1 X113.124 Y117.481 E.00516
G1 X112.738 Y117.148 E.02017
G1 X112.301 Y116.64 E.02649
; LINE_WIDTH: 0.526907
G1 X112.198 Y116.374 E.01128
; LINE_WIDTH: 0.48414
G1 X112.094 Y116.107 E.01028
; LINE_WIDTH: 0.425359
G1 X111.991 Y115.84 E.00891
G1 X111.849 Y114.999 E.02659
; LINE_WIDTH: 0.443982
G1 X111.824 Y114.954 E.00169
; LINE_WIDTH: 0.491965
G1 X111.799 Y114.909 E.00189
; LINE_WIDTH: 0.541163
G1 X111.774 Y114.863 E.0021
G1 X111.848 Y114.357 E.02079
G1 X111.495 Y115.004 F36000
; LINE_WIDTH: 0.37843
G1 F12000
G1 X111.256 Y115.895 E.02521
G1 X111.923 Y116.562 E.02577
G1 X111.666 Y115.986 E.01725
G1 X111.595 Y115.74 E.00699
G1 X111.498 Y115.064 E.01866
G1 X113.269 Y117.905 F36000
; LINE_WIDTH: 0.3822
G1 F12000
G1 X113.935 Y118.571 E.02605
G1 X114.846 Y118.327 E.02607
G1 X114.245 Y118.275 E.01668
G1 X113.637 Y118.092 E.01755
G1 X113.322 Y117.932 E.00976
; WIPE_START
G1 X113.637 Y118.092 E-.13412
G1 X114.245 Y118.275 E-.24128
G1 X114.846 Y118.327 E-.22927
G1 X114.451 Y118.433 E-.15533
; WIPE_END
G1 E-.04 F1800
G1 X120.692 Y114.039 Z2 F36000
G1 X121.857 Y113.218 Z2
G1 Z1.6
G1 E.8 F1800
; LINE_WIDTH: 0.419733
G1 F12000
G1 X116.612 Y107.972 E.22779
G3 X112.883 Y111.694 I-275.776 J-272.541 E.16175
; LINE_WIDTH: 0.375312
G1 X112.238 Y112.307 E.02411
G2 X111.977 Y113.18 I10.303 J3.559 E.02468
G1 X112.337 Y112.668 E.01695
G1 X112.905 Y112.14 E.021
G1 X113.099 Y111.996 E.00655
; LINE_WIDTH: 0.411453
G1 X113.722 Y111.686 E.02089
G1 X113.971 Y111.605 E.00786
G1 X114.657 Y111.483 E.02095
G1 X115.317 Y111.492 E.01981
G1 X116.174 Y111.715 E.02659
G1 X116.438 Y111.829 E.00863
G1 X117.027 Y112.198 E.02089
G1 X117.628 Y112.795 E.02545
G1 X117.977 Y113.335 E.01929
G1 X118.28 Y114.194 E.02738
G1 X118.325 Y114.452 E.00785
G1 X118.349 Y115.147 E.02088
G1 X118.19 Y115.979 E.02544
G1 X118.104 Y116.209 E.00737
G1 X117.769 Y116.821 E.02095
G3 X116.961 Y117.658 I-5.324 J-4.334 E.03497
G1 X116.681 Y117.84 E.01004
G1 X117.483 Y117.625 E.02494
G3 X121.815 Y113.26 I208.873 J202.957 E.18467
G1 X121.324 Y113.218 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X116.612 Y108.506 E.20477
G1 X113.873 Y111.244 E.11901
G1 X114.591 Y111.111 E.02245
G1 X115.337 Y111.116 E.02291
G1 X116.279 Y111.352 E.02984
G1 X116.638 Y111.509 E.01204
G1 X117.227 Y111.878 E.02137
G1 X117.491 Y112.096 E.01051
G1 X117.904 Y112.538 E.01857
G1 X118.3 Y113.14 E.02216
G1 X118.639 Y114.079 E.03065
G1 X118.702 Y114.439 E.01125
G1 X118.725 Y115.134 E.02137
G3 X118.581 Y115.961 I-3.236 J-.141 E.02587
G1 X121.282 Y113.26 E.11736
M73 P59 R7
G1 X120.791 Y113.218 F36000
G1 F12000
G1 X116.612 Y109.039 E.1816
G1 X114.933 Y110.717 E.07293
G1 X115.739 Y110.804 E.02489
G1 X116.409 Y110.997 E.02142
G1 X116.838 Y111.189 E.01446
G1 X117.428 Y111.559 E.02137
G3 X118.18 Y112.28 I-2.385 J3.237 E.03211
G1 X118.623 Y112.946 E.02459
G3 X119.079 Y114.427 I-4.892 J2.316 E.04776
G1 X119.095 Y114.913 E.01496
G1 X120.748 Y113.26 E.07183
G1 X120.257 Y113.218 F36000
; LINE_WIDTH: 0.43075
G1 F12000
G2 X117.901 Y110.893 I-103.262 J102.304 E.10464
G2 X116.612 Y109.572 I-21.277 J19.48 E.05833
G1 X115.757 Y110.427 E.03821
G1 X116.488 Y110.628 E.02397
G3 X117.64 Y111.22 I-2.03 J5.361 E.04101
G3 X118.465 Y112.014 I-3.742 J4.715 E.03624
; LINE_WIDTH: 0.454262
G1 X118.743 Y112.355 E.01475
G1 X119.143 Y113.183 E.03083
; LINE_WIDTH: 0.41999
G1 X119.357 Y113.847 E.02143
G1 X119.397 Y114.078 E.00721
G1 X120.215 Y113.26 E.03554
G1 X119.657 Y113.162 F36000
; LINE_WIDTH: 0.56142
G1 F12000
G2 X119.659 Y113.27 I-.027 J.055 E.01064
G1 X116.644 Y110.145 F36000
; LINE_WIDTH: 0.55498
G1 F12000
G2 X116.646 Y110.253 I-.027 J.054 E.01035
; CHANGE_LAYER
; Z_HEIGHT: 1.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X116.58 Y110.256 E-.19463
G1 X116.548 Y110.201 E-.18846
G1 X116.58 Y110.145 E-.18846
G1 X116.644 Y110.145 E-.18845
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
G1 X133.849 Y135.805
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.854 Y135.78 E.00081
G3 X135.782 Y133.851 I2.275 J.346 E.09686
G1 X136.075 Y133.825 E.00976
G3 X133.828 Y136.073 I.054 J2.301 E.36327
G1 X133.844 Y135.864 E.00694
G1 X134.242 Y135.831 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.306 Y135.558 E.00864
G3 X135.842 Y134.239 I1.822 J.568 E.06557
G1 X136.082 Y134.218 E.0074
G3 X134.234 Y135.891 I.046 J1.908 E.28503
; WIPE_START
M204 S10000
G1 X134.306 Y135.558 E-.12948
G1 X134.391 Y135.333 E-.09153
G1 X134.519 Y135.099 E-.10121
G1 X134.695 Y134.865 E-.11133
G1 X134.885 Y134.678 E-.10128
G1 X135.077 Y134.533 E-.0912
G1 X135.309 Y134.402 E-.10128
G1 X135.389 Y134.372 E-.03269
; WIPE_END
G1 E-.04 F1800
G17
G3 Z2.2 I.861 J-.86 P1  F36000
G1 X113.906 Y112.846 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X113.928 Y112.834 E.00085
G3 X114.54 Y112.642 I.987 J2.079 E.02132
G1 X114.858 Y112.612 E.01059
G3 X113.648 Y112.992 I.058 J2.301 E.43705
G1 X113.854 Y112.876 E.00782
G1 X114.07 Y113.203 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X114.096 Y113.189 E.00088
G3 X114.603 Y113.03 I.819 J1.724 E.01638
G1 X114.867 Y113.005 E.00817
G3 X113.864 Y113.32 I.048 J1.908 E.33569
G1 X114.018 Y113.233 E.00546
; WIPE_START
M204 S10000
G1 X114.096 Y113.189 E-.03373
G1 X114.368 Y113.084 E-.11101
G1 X114.603 Y113.03 E-.09142
G1 X114.867 Y113.005 E-.10101
G1 X115.134 Y113.017 E-.10157
G1 X115.422 Y113.073 E-.11132
G1 X115.673 Y113.162 E-.10126
G1 X115.888 Y113.271 E-.09152
G1 X115.925 Y113.297 E-.01718
; WIPE_END
G1 E-.04 F1800
G1 X109.282 Y109.538 Z2.2 F36000
G1 X98.609 Y103.499 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F6529.89
G1 X98.881 Y103.227 E.01278
G1 F5601.237
G1 X99.164 Y102.944 E.01327
G1 F4712.087
G1 X99.447 Y102.661 E.01327
G1 F3899.736
G1 X99.73 Y102.378 E.01327
G1 F3164.185
G1 X100.013 Y102.095 E.01327
G1 F2505.435
G1 X100.361 Y101.747 E.01633
G1 F1800
G1 X100.631 Y101.477 E.01269
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X101.477 Y100.631 E.03965
; FEATURE: Inner wall
G1 F1920
M204 S10000
G1 X101.747 Y100.361 E.01269
G1 F2501.458
G1 X102.03 Y100.078 E.01327
G1 F3159.716
G1 X102.313 Y99.795 E.01327
G1 F3894.774
G1 X102.596 Y99.512 E.01327
G1 F4706.632
G1 X102.878 Y99.23 E.01327
G1 F5595.29
G1 X103.161 Y98.947 E.01327
G1 F6756.765
G1 X103.499 Y98.609 E.01584
G1 F7813.908
G1 X103.782 Y98.892 E.01327
G1 F8947.852
G1 X104.065 Y99.175 E.01327
G1 F10158.596
G1 X104.347 Y99.458 E.01327
G1 F11446.14
G1 X104.63 Y99.74 E.01327
G1 F12469.297
G1 X104.913 Y100.023 E.01327
G1 F8249.435
G1 X105.057 Y100.168 E.00677
G1 F7684.929
G1 X105.34 Y100.451 E.01327
G1 F6636.865
G1 X105.623 Y100.733 E.01327
G1 F5665.6
G1 X105.906 Y101.016 E.01327
G1 F4771.136
G1 X106.189 Y101.299 E.01327
G1 F3953.471
G1 X105.851 Y101.637 E.01584
G1 F3077.893
G1 X105.568 Y101.92 E.01327
G1 F2428.715
G1 X105.285 Y102.202 E.01327
G1 F1856.336
G1 X105.003 Y102.485 E.01327
G1 F1360.757
G1 X104.72 Y102.768 E.01327
G1 F941.979
G1 X104.437 Y103.051 E.01327
G1 F600
G1 X103.051 Y104.437 E.06502
G1 F941.979
G1 X102.768 Y104.72 E.01327
G1 F1360.757
G1 X102.485 Y105.003 E.01327
G1 F1856.336
G1 X102.202 Y105.285 E.01327
G1 F2428.715
G1 X101.92 Y105.568 E.01327
G1 F3077.893
G1 X101.637 Y105.851 E.01327
G1 F3953.471
G1 X101.299 Y106.189 E.01584
G1 F4771.136
G1 X101.016 Y105.906 E.01327
G1 F5665.6
G1 X100.733 Y105.623 E.01327
G1 F6636.865
G1 X100.451 Y105.34 E.01327
G1 F7684.929
G1 X100.168 Y105.057 E.01327
G1 F8809.794
G1 X99.885 Y104.775 E.01327
G1 F10011.458
G1 X99.602 Y104.492 E.01327
G1 F11289.923
G1 X99.319 Y104.209 E.01327
G1 F12645.187
G1 X99.036 Y103.926 E.01327
G1 F14612.038
G1 X98.652 Y103.541 E.01805
G1 X99.164 Y103.499 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F5616.461
M204 S6000
G1 X99.516 Y103.146 E.01533
G1 F4517.655
G1 X99.799 Y102.863 E.01229
G1 F3723.041
G1 X100.082 Y102.58 E.01229
G1 F3005.227
G1 X100.365 Y102.298 E.01229
G1 F2364.214
G1 X100.648 Y102.015 E.01229
G1 F1800
G1 X100.909 Y101.754 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X101.571 Y101.092 E.03105

G1 X101.754 Y100.909 E.00859
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1920
G1 X102.015 Y100.648 E.01134
G1 F2501.458
G1 X102.298 Y100.365 E.01229
G1 F3159.716
G1 X102.58 Y100.082 E.01229
G1 F3894.774
G1 X102.863 Y99.799 E.01229
G1 F4706.632
G1 X103.146 Y99.516 E.01229
G1 F5826.951
G1 X103.499 Y99.164 E.01533
G1 F5924.354
G1 X103.528 Y99.193 E.00126
G1 F6916.683
G1 X103.811 Y99.475 E.01229
G1 F7985.812
G1 X104.094 Y99.758 E.01229
G1 F9131.742
G1 X104.376 Y100.041 E.01229
G1 F9945.49
G1 X104.659 Y100.324 E.01229
G1 F9544.843
G1 X105.04 Y100.704 E.01653
G1 F7985.754
G1 X105.322 Y100.987 E.01229
G1 F6916.629
G1 X105.605 Y101.27 E.01229
G1 F5924.304
G1 X105.634 Y101.299 E.00126
G1 F5826.968
G1 X105.281 Y101.652 E.01533
G1 F4706.632
G1 X104.999 Y101.935 E.01229
G1 F3894.774
G1 X104.716 Y102.218 E.01229
G1 F3159.716
G1 X104.433 Y102.5 E.01229
G1 F2501.458
G1 X104.15 Y102.783 E.01229
G1 F1920
G1 X103.889 Y103.044 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X103.044 Y103.889 E.03965
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1920
G1 X102.783 Y104.15 E.01134
G1 F2501.458
G1 X102.5 Y104.433 E.01229
G1 F3159.716
G1 X102.218 Y104.716 E.01229
G1 F3894.774
G1 X101.935 Y104.999 E.01229
G1 F4706.632
G1 X101.652 Y105.281 E.01229
G1 F5826.968
G1 X101.299 Y105.634 E.01533
G1 F5924.32
G1 X101.27 Y105.605 E.00126
G1 F6916.647
G1 X100.987 Y105.322 E.01229
G1 F7985.773
G1 X100.704 Y105.04 E.01229
G1 F9131.7
G1 X100.422 Y104.757 E.01229
G1 F10354.426
G1 X100.139 Y104.474 E.01229
G1 F11653.953
G1 X99.856 Y104.191 E.01229
G1 F12000
G1 X99.573 Y103.908 E.01229
G1 X99.206 Y103.541 E.01595
; WIPE_START
M204 S10000
G1 X99.516 Y103.146 E-.19097
G1 X99.799 Y102.863 E-.152
G1 X100.082 Y102.58 E-.152
G1 X100.365 Y102.298 E-.152
G1 X100.575 Y102.087 E-.11303
; WIPE_END
G1 E-.04 F1800
G1 X106.149 Y107.301 Z2.2 F36000
G1 X154.616 Y152.639 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.085 Y160.17 E.26054
G1 X145.815 Y158.9 E.05957
G1 X148.716 Y155.999 E.13609
G1 X138.283 Y145.566 E.48942
G1 X136.825 Y147.024 E.06839
G1 X104.019 Y114.217 E1.53904
G1 X105.476 Y112.759 E.06839
G1 X96.744 Y104.027 E.40967
G1 X96.461 Y103.744 E.01327
G1 F14260.321
G1 X96.178 Y103.461 E.01327
G1 F12818.726
G1 X95.895 Y103.178 E.01327
G1 F11453.931
G1 X96.298 Y102.775 E.0189
G1 F9642.723
G1 X96.581 Y102.492 E.01327
G1 F8464.109
G1 X96.864 Y102.21 E.01327
G1 F7362.296
G1 X97.147 Y101.927 E.01327
G1 F6337.282
G1 X97.429 Y101.644 E.01327
G1 F5389.068
G1 X97.712 Y101.361 E.01327
G1 F4517.655
G1 X97.995 Y101.078 E.01327
G1 F3723.041
G1 X98.278 Y100.795 E.01327
G1 F3005.227
G1 X98.561 Y100.512 E.01327
G1 F2364.214
G1 X98.844 Y100.23 E.01327
G1 F1800
G1 X99.114 Y99.959 E.01269
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X99.959 Y99.114 E.03965
; FEATURE: Inner wall
G1 F1800
M204 S10000
G1 X100.23 Y98.844 E.01269
G1 F2364.214
G1 X100.512 Y98.561 E.01327
G1 F3005.227
G1 X100.795 Y98.278 E.01327
G1 F3723.041
G1 X101.078 Y97.995 E.01327
G1 F4517.655
G1 X101.361 Y97.712 E.01327
G1 F5389.068
G1 X101.644 Y97.429 E.01327
G1 F6337.282
G1 X101.927 Y97.147 E.01327
G1 F7362.296
G1 X102.21 Y96.864 E.01327
G1 F8464.109
G1 X102.492 Y96.581 E.01327
G1 F9642.723
G1 X102.775 Y96.298 E.01327
G1 F11453.931
G1 X103.178 Y95.895 E.0189
G1 F12818.726
G1 X103.461 Y96.178 E.01327
G1 F14260.321
G1 X103.744 Y96.461 E.01327
G1 F15476.087
G1 X104.027 Y96.744 E.01327
G1 X107.543 Y100.26 E.16496
G1 X112.759 Y105.477 E.24471
G1 X114.217 Y104.018 E.0684
G1 X115.567 Y105.367 E.06329
G1 X147.024 Y136.825 E1.47575
G1 X145.566 Y138.283 E.06839
G1 X155.999 Y148.716 E.48942
G1 X158.9 Y145.815 E.13609
G1 X160.17 Y147.085 E.05957
G1 X154.658 Y152.596 E.25855
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.085 Y160.724 E.24134
G1 X145.261 Y158.9 E.07928
G1 X148.162 Y155.999 E.12606
G1 X138.283 Y146.121 E.42926
G1 X136.825 Y147.578 E.06335
G1 X103.464 Y114.217 E1.44971
G1 X104.922 Y112.759 E.06335
G1 X95.341 Y103.178 E.41635
G1 X95.748 Y102.771 E.01768
G1 F11190.58
G1 X96.03 Y102.488 E.01229
G1 F9917.922
G1 X96.313 Y102.206 E.01229
G1 F8722.064
G1 X96.596 Y101.923 E.01229
G1 F7603.006
G1 X96.879 Y101.64 E.01229
G1 F6560.748
G1 X97.162 Y101.357 E.01229
G1 F5595.29
G1 X97.445 Y101.074 E.01229
G1 F4706.632
G1 X97.727 Y100.791 E.01229
G1 F3894.774
G1 X98.01 Y100.509 E.01229
G1 F3159.716
G1 X98.293 Y100.226 E.01229
G1 F2501.458
G1 X98.576 Y99.943 E.01229
G1 F1920
G1 X98.837 Y99.682 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X99.682 Y98.837 E.03965
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1920
G1 X99.943 Y98.576 E.01134
G1 F2501.458
G1 X100.226 Y98.293 E.01229
G1 F3159.716
G1 X100.509 Y98.01 E.01229
G1 F3894.774
G1 X100.791 Y97.727 E.01229
G1 F4706.632
G1 X101.074 Y97.445 E.01229
G1 F5595.29
G1 X101.357 Y97.162 E.01229
G1 F6560.748
G1 X101.64 Y96.879 E.01229
G1 F7603.006
G1 X101.923 Y96.596 E.01229
G1 F8722.064
G1 X102.206 Y96.313 E.01229
G1 F9917.922
G1 X102.488 Y96.03 E.01229
G1 F11190.58
G1 X102.771 Y95.748 E.01229
G1 F12000
G1 X103.178 Y95.341 E.01768
G1 X107.82 Y99.983 E.20172
G1 X112.759 Y104.922 E.21463
G1 X114.217 Y103.464 E.06335
G1 X115.845 Y105.089 E.07067
G1 X147.578 Y136.825 E1.37904
G1 X146.121 Y138.283 E.06335
G1 X155.999 Y148.162 E.42926
G1 X158.9 Y145.261 E.12606
G1 X160.724 Y147.085 E.07928
G1 X155.213 Y152.596 E.2395
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X149.849 Y157.601 Z2.2 F36000
G1 X148.392 Y158.37 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X149.363 Y155.957 E.02552
G1 X149.363 Y155.616 E.01131
G1 X147.898 Y154.15 E.06874
G1 X154.15 Y147.898 E.29332
G1 X155.616 Y149.363 E.06874
G1 X155.957 Y149.363 E.01131
G1 X156.442 Y148.766 E.02552
G1 X157.219 Y149.543 E.03647
G1 X154.123 Y152.639 E.14523
G1 X155.604 Y154.12 E.06947
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X139.561 Y139.561 E.74784
G3 X139.138 Y139.882 I-.603 J-.356 E.01806
G1 X134.657 Y144.363 E.21022
G1 X130.819 Y140.525 E.18005
G1 X132.557 Y138.787 E.08153
G1 X131.304 Y137.535 E.05876
G1 X131.247 Y137.322 E.00732
G1 X132.397 Y133.032 E.1473
G3 X132.695 Y132.695 I.779 J.387 E.01511
G1 X130.916 Y130.916 E.08343
G1 X127.53 Y134.302 E.15885
G1 X127.189 Y134.302 E.01131
G1 X124.44 Y131.553 E.12899
G1 X123.143 Y132.849 E.06082
G1 X126.981 Y136.687 E.18005
G1 X136.688 Y126.981 E.45535
G1 X137.477 Y127.77 E.03703
G1 X137.455 Y127.934 E.00549
G1 X136.533 Y128.857 E.04327
G1 X122.186 Y114.51 E.67304
G1 X123.109 Y113.587 E.04328
G1 X123.273 Y113.566 E.00551
G1 X125.174 Y115.467 E.08916
G1 X123.877 Y116.764 E.06086
G1 X123.512 Y116.74 E.01211
G1 X120.126 Y120.126 E.15885
G1 X118.348 Y118.348 E.08343
G3 X118.01 Y118.646 I-.725 J-.481 E.01511
G1 X113.721 Y119.795 E.1473
G3 X113.367 Y119.597 I-.006 J-.405 E.01409
G1 X111.629 Y121.335 E.08153
G1 X115.467 Y125.173 E.18005
G1 X116.764 Y123.877 E.06082
G1 X120.118 Y127.231 E.15737
G1 X120.459 Y127.231 E.01131
G1 X123.845 Y123.845 E.15885
G1 X127.197 Y127.197 E.15726
G1 X130.583 Y123.811 E.15885
G1 X130.924 Y123.811 E.01131
G1 X131.553 Y124.44 E.02948
G1 X132.85 Y123.143 E.06085
G1 X129.012 Y119.305 E.18005
G1 X119.305 Y129.011 E.45536
G1 X120.457 Y130.163 E.05401
G1 X124.079 Y130.631 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.42899
G1 F3000
G1 X127.368 Y133.91 E.14612
G1 X127.636 Y133.642 E.01193
G1 X124.472 Y130.478 E.14078
G1 X124.745 Y130.205 E.01215
G1 X127.909 Y133.369 E.14078
G1 X128.182 Y133.096 E.01215
G1 X125.018 Y129.932 E.14078
G1 X125.291 Y129.659 E.01215
G1 X128.455 Y132.823 E.14078
G1 X128.728 Y132.55 E.01215
G1 X125.564 Y129.386 E.14078
G1 X125.837 Y129.113 E.01215
G1 X129.001 Y132.277 E.14078
G1 X129.274 Y132.004 E.01215
G1 X126.11 Y128.84 E.14078
G1 X126.383 Y128.567 E.01215
G1 X129.547 Y131.731 E.14078
G1 X129.82 Y131.458 E.01215
G1 X126.656 Y128.294 E.14078
G1 X126.929 Y128.021 E.01215
G1 X130.093 Y131.185 E.14078
G1 X130.366 Y130.912 E.01215
G1 X127.202 Y127.748 E.14078
G1 X127.475 Y127.475 E.01215
G1 X130.639 Y130.639 E.14078
G1 X130.912 Y130.366 E.01215
G1 X127.748 Y127.202 E.14078
G1 X128.021 Y126.929 E.01215
G1 X131.185 Y130.093 E.14078
G1 X131.458 Y129.82 E.01215
G1 X128.294 Y126.656 E.14078
G1 X128.567 Y126.383 E.01215
G1 X131.731 Y129.547 E.14078
G1 X132.004 Y129.274 E.01215
G1 X128.84 Y126.11 E.14078
G1 X129.113 Y125.837 E.01215
G1 X132.277 Y129.001 E.14078
G1 X132.55 Y128.728 E.01215
G1 X129.386 Y125.564 E.14078
G1 X129.659 Y125.291 E.01215
G1 X132.823 Y128.455 E.14078
G1 X133.096 Y128.182 E.01215
G1 X129.932 Y125.018 E.14078
G1 X130.205 Y124.745 E.01215
G1 X133.369 Y127.909 E.14078
G1 X133.642 Y127.636 E.01215
G1 X130.478 Y124.472 E.14078
G1 X130.746 Y124.204 E.01194
G1 X134.035 Y127.483 E.14612
G1 X126.964 Y120.412 F36000
G1 F3000
G1 X123.675 Y117.133 E.14612
G1 X123.407 Y117.401 E.01194
G1 X126.571 Y120.565 E.14078
G1 X126.298 Y120.838 E.01215
G1 X123.134 Y117.674 E.14078
G1 X122.861 Y117.947 E.01215
G1 X126.025 Y121.111 E.14078
G1 X125.752 Y121.384 E.01215
G1 X122.588 Y118.22 E.14078
G1 X122.315 Y118.493 E.01215
G1 X125.479 Y121.657 E.14078
G1 X125.206 Y121.93 E.01215
G1 X122.042 Y118.766 E.14078
G1 X121.769 Y119.039 E.01215
M73 P60 R7
G1 X124.933 Y122.203 E.14078
G1 X124.66 Y122.476 E.01215
G1 X121.496 Y119.312 E.14078
G1 X121.223 Y119.585 E.01215
G1 X124.387 Y122.749 E.14078
G1 X124.114 Y123.022 E.01215
G1 X120.95 Y119.858 E.14078
G1 X120.677 Y120.131 E.01215
G1 X123.841 Y123.295 E.14078
G1 X123.568 Y123.568 E.01215
G1 X120.404 Y120.404 E.14078
G1 X120.131 Y120.677 E.01215
G1 X123.295 Y123.841 E.14078
G1 X123.022 Y124.114 E.01215
G1 X119.858 Y120.95 E.14078
G1 X119.585 Y121.223 E.01215
G1 X122.749 Y124.387 E.14078
G1 X122.476 Y124.66 E.01215
G1 X119.312 Y121.496 E.14078
G1 X119.039 Y121.769 E.01215
G1 X122.203 Y124.933 E.14078
G1 X121.93 Y125.206 E.01215
G1 X118.766 Y122.042 E.14078
G1 X118.493 Y122.315 E.01215
G1 X121.657 Y125.479 E.14078
G1 X121.384 Y125.752 E.01215
G1 X118.22 Y122.588 E.14078
G1 X117.947 Y122.861 E.01215
G1 X121.111 Y126.025 E.14078
G1 X120.838 Y126.298 E.01215
G1 X117.674 Y123.134 E.14078
G1 X117.401 Y123.407 E.01215
G1 X120.565 Y126.571 E.14078
G1 X120.297 Y126.839 E.01193
G1 X117.008 Y123.56 E.14612
G1 X122.902 Y113.256 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X116.574 Y106.927 E.275
G1 X111.551 Y111.966 E.21859
G2 X110.44 Y116.108 I1161.08 J313.728 E.13178
G2 X113.711 Y119.387 I166.447 J-162.802 E.1423
G2 X117.859 Y118.281 I-53.902 J-210.471 E.1319
G2 X122.852 Y113.289 I-1166.854 J-1172.296 E.21694
G1 X122.36 Y113.248 F36000
G1 F12000
G1 X116.582 Y107.469 E.25111
G1 X111.888 Y112.163 E.20398
G1 X111.666 Y112.989 E.02626
; LINE_WIDTH: 0.441212
G1 X111.657 Y113.107 E.00385
; LINE_WIDTH: 0.483655
G1 X111.647 Y113.225 E.00426
; LINE_WIDTH: 0.532623
G1 X111.637 Y113.343 E.00473
G1 X111.396 Y114.191 E.03519
; LINE_WIDTH: 0.494758
G1 X111.251 Y114.637 E.01726
; LINE_WIDTH: 0.424565
G2 X110.859 Y116.001 I12.615 J4.357 E.04416
G1 X111.661 Y116.803 E.03526
; LINE_WIDTH: 0.437967
G1 X111.799 Y116.916 E.00574
; LINE_WIDTH: 0.47392
G1 X111.937 Y117.029 E.00626
; LINE_WIDTH: 0.518177
G3 X112.429 Y117.504 I-1.826 J2.379 E.02655
; LINE_WIDTH: 0.49076
G1 X112.712 Y117.821 E.01552
; LINE_WIDTH: 0.42432
G2 X113.828 Y118.97 I10.898 J-9.466 E.0498
G1 X114.724 Y118.729 E.02882
; LINE_WIDTH: 0.441564
G1 X114.781 Y118.694 E.00219
; LINE_WIDTH: 0.480752
G1 X114.838 Y118.658 E.00241
; LINE_WIDTH: 0.519939
G1 X114.896 Y118.622 E.00263
; LINE_WIDTH: 0.542176
G1 X114.953 Y118.587 E.00275
G2 X116.503 Y118.186 I-2.571 J-13.129 E.06519
; LINE_WIDTH: 0.529474
G1 X116.69 Y118.158 E.0075
; LINE_WIDTH: 0.48568
G1 X116.878 Y118.131 E.00683
; LINE_WIDTH: 0.420551
G1 X117.065 Y118.103 E.00582
G1 X117.666 Y117.942 E.01916
G1 X122.318 Y113.29 E.20243
; WIPE_START
G1 X120.904 Y114.705 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X113.274 Y114.516 Z2.2 F36000
G1 X112.253 Y114.491 Z2.2
G1 Z1.8
G1 E.8 F1800
; LINE_WIDTH: 0.41999
G1 F12000
G1 X112.469 Y113.785 E.02266
G1 X112.679 Y113.412 E.01316
G1 X113.138 Y112.89 E.02135
G1 X113.739 Y112.491 E.02216
G1 X114.164 Y112.327 E.014
G1 X114.823 Y112.222 E.0205
G1 X115.241 Y112.239 E.01286
G1 X115.814 Y112.38 E.01812
G1 X116.006 Y112.452 E.00633
G1 X116.603 Y112.815 E.02145
G1 X116.914 Y113.109 E.01315
G1 X117.309 Y113.68 E.02136
G1 X117.551 Y114.36 E.02216
G1 X117.607 Y114.817 E.01414
G1 X117.542 Y115.511 E.02144
G1 X117.276 Y116.212 E.02304
G1 X117.041 Y116.569 E.01312
G1 X116.569 Y117.041 E.0205
G1 X116.187 Y117.29 E.01401
G1 X115.561 Y117.53 E.0206
G1 X114.816 Y117.607 E.02301
G1 X114.153 Y117.49 E.0207
G1 X113.658 Y117.298 E.01633
G1 X113.108 Y116.913 E.02062
G3 X112.584 Y116.266 I1.726 J-1.931 E.02568
G1 X112.323 Y115.652 E.0205
G1 X112.236 Y115.2 E.01415
G1 X112.251 Y114.551 E.01997
G1 X111.825 Y114.453 F36000
; LINE_WIDTH: 0.531278
G1 F12000
G1 X112.101 Y113.532 E.03824
; LINE_WIDTH: 0.526099
G1 X112.314 Y113.279 E.01303
; LINE_WIDTH: 0.483655
G1 X112.526 Y113.025 E.01189
; LINE_WIDTH: 0.420672
G3 X112.971 Y112.54 I3.03 J2.329 E.02028
G1 X113.533 Y112.175 E.02064
G1 X114.105 Y111.955 E.01885
G1 X114.763 Y111.85 E.02054
G1 X115.313 Y111.869 E.01692
G1 X115.939 Y112.024 E.01986
G1 X116.202 Y112.13 E.00874
G1 X116.799 Y112.493 E.02149
G1 X117.224 Y112.894 E.01799
G1 X117.619 Y113.466 E.02139
G1 X117.908 Y114.237 E.02534
G1 X117.983 Y114.852 E.01908
G1 X117.917 Y115.547 E.02148
G1 X117.627 Y116.35 E.02628
G1 X117.308 Y116.836 E.0179
G1 X116.836 Y117.308 E.02054
; LINE_WIDTH: 0.442592
G1 X116.686 Y117.434 E.00639
; LINE_WIDTH: 0.487795
G1 X116.536 Y117.561 E.00712
; LINE_WIDTH: 0.535161
G1 X116.386 Y117.688 E.00787
G1 X115.714 Y117.927 E.02862
; LINE_WIDTH: 0.531613
G1 X115.286 Y117.994 E.01724
; LINE_WIDTH: 0.563018
G1 X114.859 Y118.061 E.01835
; LINE_WIDTH: 0.559127
G1 X114.818 Y118.04 E.00194
; LINE_WIDTH: 0.519939
G1 X114.777 Y118.019 E.0018
; LINE_WIDTH: 0.480752
G1 X114.736 Y117.997 E.00165
; LINE_WIDTH: 0.42129
G1 X114.695 Y117.976 E.00143
G1 X114.084 Y117.86 E.01918
G1 X113.545 Y117.664 E.01769
; LINE_WIDTH: 0.436767
G1 X113.317 Y117.53 E.00845
; LINE_WIDTH: 0.47032
G1 X113.09 Y117.397 E.00917
; LINE_WIDTH: 0.51505
G1 X112.863 Y117.264 E.01013
G1 X112.506 Y116.901 E.01959
; LINE_WIDTH: 0.504174
G1 X112.416 Y116.739 E.00697
; LINE_WIDTH: 0.4705
G1 X112.327 Y116.576 E.00646
; LINE_WIDTH: 0.422109
G1 X112.237 Y116.414 E.00573
G1 X111.976 Y115.8 E.02062
G1 X111.859 Y115.191 E.01916
; LINE_WIDTH: 0.442775
G1 X111.845 Y114.852 E.01107
; LINE_WIDTH: 0.488345
G1 X111.831 Y114.512 E.01233
G1 X111.509 Y114.95 F36000
; LINE_WIDTH: 0.37689
G1 F12000
G1 X111.256 Y115.895 E.02664
G1 X111.908 Y116.547 E.0251
G1 X111.649 Y115.939 E.01799
G1 X111.52 Y115.381 E.0156
G1 X111.511 Y115.01 E.0101
G1 X113.303 Y117.938 F36000
; LINE_WIDTH: 0.384034
G1 F12000
G1 X113.935 Y118.57 E.02487
G3 X114.789 Y118.338 I26.382 J95.366 E.02459
G1 X114.017 Y118.213 E.02172
G1 X113.355 Y117.967 E.01965
; WIPE_START
G1 X114.017 Y118.213 E-.26859
G1 X114.789 Y118.338 E-.29699
G1 X114.295 Y118.472 E-.19442
; WIPE_END
G1 E-.04 F1800
G1 X120.567 Y114.122 Z2.2 F36000
G1 X121.827 Y113.248 Z2.2
G1 Z1.8
G1 E.8 F1800
; LINE_WIDTH: 0.411169
G1 F12000
G1 X116.582 Y108.002 E.2226
G1 X113.058 Y111.526 E.14954
G2 X112.204 Y112.346 I14.421 J15.881 E.03552
G1 X111.992 Y113.136 E.02456
G1 X112.474 Y112.539 E.02304
G1 X112.777 Y112.242 E.01272
G1 X113.327 Y111.859 E.02013
G1 X113.856 Y111.633 E.01724
G1 X114.704 Y111.477 E.02587
G3 X116.398 Y111.808 I.178 J3.598 E.05232
G1 X116.995 Y112.171 E.02095
G1 X117.407 Y112.531 E.01643
G1 X117.929 Y113.251 E.02669
G3 X118.309 Y114.306 I-5.076 J2.421 E.0337
G1 X118.358 Y114.887 E.0175
G1 X118.292 Y115.582 E.02094
G1 X118.232 Y115.836 E.00784
G1 X117.978 Y116.487 E.02095
G1 X117.679 Y116.945 E.01642
G3 X116.936 Y117.678 I-5.935 J-5.266 E.03135
G1 X116.692 Y117.837 E.00876
G1 X117.483 Y117.625 E.0246
G3 X121.785 Y113.29 I159.554 J154.009 E.18325
G1 X121.294 Y113.248 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X116.582 Y108.536 E.20476
G1 X113.878 Y111.239 E.11748
G1 X114.645 Y111.105 E.02391
G1 X115.264 Y111.106 E.01904
G3 X116.347 Y111.368 I-.354 J3.824 E.03436
G1 X117.191 Y111.849 E.02982
G1 X117.666 Y112.258 E.01926
G1 X118.239 Y113.036 E.02972
G3 X118.683 Y114.26 I-4.867 J2.456 E.04009
G1 X118.733 Y114.923 E.02041
G1 X118.668 Y115.618 E.02144
G1 X118.588 Y115.954 E.01061
G1 X121.251 Y113.29 E.11573
G1 X120.761 Y113.248 F36000
G1 F12000
G1 X116.582 Y109.069 E.18159
G1 X114.937 Y110.714 E.07147
G3 X116.143 Y110.897 I-.023 J4.216 E.03761
G1 X116.79 Y111.164 E.02152
G1 X117.387 Y111.526 E.02145
G1 X117.925 Y111.984 E.0217
G3 X118.854 Y113.512 I-3.257 J3.028 E.05532
G1 X119.057 Y114.214 E.02248
G1 X119.108 Y114.9 E.02114
G1 X120.718 Y113.29 E.06997
G1 X120.227 Y113.248 F36000
; LINE_WIDTH: 0.421521
G1 F12000
G3 X116.582 Y109.602 I558.976 J-562.59 E.15906
G1 X115.764 Y110.42 E.03569
G1 X116.268 Y110.541 E.01601
G1 X116.986 Y110.841 E.02402
G1 X117.59 Y111.193 E.02154
G1 X118.181 Y111.713 E.02429
G1 X118.467 Y112.033 E.01325
G1 X118.859 Y112.607 E.02144
G1 X119.115 Y113.111 E.01742
G3 X119.408 Y114.067 I-4.387 J1.869 E.03092
G1 X120.185 Y113.29 E.03389
G1 X119.648 Y113.195 F36000
; LINE_WIDTH: 0.52778
G1 F12000
G2 X119.648 Y113.3 I-.024 J.052 E.00917
G1 X116.611 Y110.151 F36000
; LINE_WIDTH: 0.51402
G1 F12000
G2 X116.61 Y110.253 I-.029 J.051 E.00939
G1 X105.627 Y102.945 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.45751
G1 F3000
G1 X103.065 Y105.507 E.12242
G1 X102.772 Y105.214 E.01401
G1 X105.334 Y102.652 E.12242
; WIPE_START
G1 X103.92 Y104.066 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.973 Y99.591 Z2.2 F36000
G1 Z1.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.821 Y98.439 E.05401
G1 X104.257 Y98.004 E.02041
G1 X108.095 Y101.842 E.18005
G1 X101.842 Y108.095 E.29332
G1 X98.004 Y104.257 E.18005
G1 X98.439 Y103.821 E.02042
G1 X101.299 Y106.681 E.13416
G1 X102.492 Y105.489 E.05595
G1 X102.908 Y105.905 E.01951
G1 X103.249 Y105.905 E.01131
G1 X104.577 Y104.577 E.0623
G1 X111.481 Y111.482 E.32392
G2 X111.183 Y111.819 I.481 J.725 E.01511
G1 X110.347 Y114.942 E.10724
G1 X107.791 Y117.497 E.11988
G1 X106.64 Y116.346 E.05401
; WIPE_START
G1 X107.791 Y117.497 E-.61876
G1 X108.054 Y117.234 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X104.276 Y110.603 Z2.2 F36000
G1 X99.45 Y102.133 Z2.2
G1 Z1.8
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.4954
G1 F3000
G1 X102.013 Y99.57 E.13361
G1 X101.693 Y99.25 E.01668
G1 X99.25 Y101.693 E.12735
G1 X98.931 Y101.373 E.01668
G1 X101.373 Y98.931 E.12735
G1 X101.053 Y98.611 E.01668
G1 X98.491 Y101.173 E.13361
G1 X96.41 Y103.178 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X105.717 Y112.485 E.36465
; WIPE_START
G1 X104.303 Y111.07 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X103.719 Y103.46 Z2.2 F36000
G1 X103.178 Y96.41 Z2.2
G1 Z1.8
G1 E.8 F1800
G1 F12000
G1 X112.485 Y105.717 E.36465
G1 X144.114 Y134.47 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X137.786 Y128.141 E.27498
G1 X132.765 Y133.179 E.21856
G2 X131.653 Y137.322 I1317.05 J355.571 E.13178
G2 X134.924 Y140.6 I166.164 J-162.52 E.1423
G2 X139.072 Y139.494 I-53.719 J-209.785 E.1319
G1 X144.065 Y134.503 E.21691
G1 X143.573 Y134.462 F36000
G1 F12000
G1 X137.794 Y128.683 E.25111
G1 X133.101 Y133.376 E.20395
G1 X132.904 Y134.112 E.02341
; LINE_WIDTH: 0.439854
G1 X132.91 Y134.164 E.0017
; LINE_WIDTH: 0.479582
G1 X132.917 Y134.217 E.00187
; LINE_WIDTH: 0.519309
G1 X132.923 Y134.269 E.00204
; LINE_WIDTH: 0.542148
G1 X132.93 Y134.321 E.00214
G2 X132.503 Y135.86 I12.647 J4.337 E.06501
; LINE_WIDTH: 0.529024
G1 X132.436 Y136.026 E.00711
; LINE_WIDTH: 0.48541
G1 X132.369 Y136.193 E.00647
; LINE_WIDTH: 0.434479
G1 X132.301 Y136.36 E.00573
G1 X132.072 Y137.215 E.02825
G1 X132.917 Y138.025 E.03736
; LINE_WIDTH: 0.489175
G1 X133.02 Y138.099 E.0046
; LINE_WIDTH: 0.533
G1 X133.123 Y138.173 E.00505
G1 X133.604 Y138.678 E.02789
; LINE_WIDTH: 0.492133
G1 X133.906 Y139.014 E.0165
; LINE_WIDTH: 0.424628
G2 X135.041 Y140.184 I11.519 J-10.048 E.05074
G1 X135.724 Y140.001 E.022
; LINE_WIDTH: 0.436135
G1 X136.042 Y139.899 E.0107
; LINE_WIDTH: 0.468425
G1 X136.361 Y139.797 E.01158
; LINE_WIDTH: 0.50067
G1 X136.865 Y139.645 E.01966
; LINE_WIDTH: 0.5338
G1 X137.708 Y139.401 E.0351
; LINE_WIDTH: 0.529024
G1 X137.886 Y139.376 E.00712
; LINE_WIDTH: 0.48541
G1 X138.064 Y139.351 E.00648
; LINE_WIDTH: 0.420519
G1 X138.242 Y139.326 E.00553
G1 X138.88 Y139.155 E.02031
G1 X143.53 Y134.504 E.20238
; WIPE_START
G1 X142.116 Y135.918 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.526 Y136.722 Z2.2 F36000
G1 X133.525 Y136.828 Z2.2
G1 Z1.8
G1 E.8 F1800
; LINE_WIDTH: 0.41999
G1 F12000
G3 X133.436 Y136.038 I2.526 J-.685 E.0245
G1 X133.548 Y135.353 E.02135
G1 X133.846 Y134.696 E.02216
G1 X134.18 Y134.271 E.01659
G1 X134.392 Y134.068 E.00904
G1 X134.952 Y133.704 E.02051
G1 X135.38 Y133.539 E.01411
G1 X136.042 Y133.435 E.02059
G1 X136.499 Y133.459 E.01405
G1 X137.172 Y133.645 E.02146
G1 X137.816 Y134.028 E.02302
G1 X138.127 Y134.322 E.01315
G1 X138.522 Y134.893 E.02135
G1 X138.764 Y135.573 E.02216
G3 X138.808 Y136.404 I-2.53 J.548 E.02569
G1 X138.658 Y137.054 E.02051
G1 X138.465 Y137.468 E.01401
G1 X138.063 Y138.003 E.02059
G3 X137.396 Y138.504 I-1.865 J-1.785 E.02572
G1 X136.744 Y138.751 E.02144
G1 X136.321 Y138.815 E.01312
G1 X135.655 Y138.78 E.0205
G3 X134.868 Y138.509 I.438 J-2.548 E.02568
G1 X134.321 Y138.127 E.02051
G1 X133.841 Y137.552 E.02301
G1 X133.545 Y136.884 E.02244
G1 X133.155 Y136.9 F36000
; LINE_WIDTH: 0.443665
G1 F12000
G1 X133.082 Y136.498 E.01333
; LINE_WIDTH: 0.491015
G1 X133.009 Y136.096 E.0149
; LINE_WIDTH: 0.533422
G1 X132.999 Y135.967 E.0052
G1 X133.128 Y135.284 E.02778
; LINE_WIDTH: 0.53192
G1 X133.28 Y134.893 E.01669
; LINE_WIDTH: 0.56324
G1 X133.432 Y134.503 E.01775
; LINE_WIDTH: 0.559037
G1 X133.465 Y134.486 E.00157
; LINE_WIDTH: 0.519309
G1 X133.498 Y134.469 E.00145
; LINE_WIDTH: 0.479582
G1 X133.532 Y134.452 E.00133
; LINE_WIDTH: 0.420059
G1 X133.565 Y134.435 E.00115
G3 X134.187 Y133.752 I2.695 J1.827 E.02849
G1 X134.746 Y133.388 E.02051
G1 X135.322 Y133.167 E.01895
G1 X135.984 Y133.063 E.0206
G1 X136.599 Y133.096 E.01894
G1 X137.274 Y133.282 E.02151
G1 X138.012 Y133.706 E.02617
G1 X138.437 Y134.107 E.01796
G1 X138.832 Y134.679 E.02136
G1 X139.121 Y135.45 E.02529
G1 X139.198 Y136.026 E.01788
G1 X139.175 Y136.489 E.01423
G1 X139.025 Y137.139 E.02051
G1 X138.767 Y137.694 E.01883
G1 X138.364 Y138.23 E.0206
G1 X137.929 Y138.616 E.01788
; LINE_WIDTH: 0.441797
G1 X137.804 Y138.717 E.00523
; LINE_WIDTH: 0.48541
G1 X137.678 Y138.818 E.0058
; LINE_WIDTH: 0.53039
G1 X137.553 Y138.918 E.00639
G1 X136.894 Y139.149 E.02773
G1 X136.424 Y139.243 E.01903
; LINE_WIDTH: 0.51699
G1 X136.161 Y139.215 E.01022
; LINE_WIDTH: 0.47819
G1 X135.898 Y139.186 E.00938
; LINE_WIDTH: 0.423911
G1 X135.635 Y139.157 E.00821
G1 X135.072 Y139.013 E.01805
G1 X134.652 Y138.818 E.01437
; LINE_WIDTH: 0.436764
G1 X134.46 Y138.705 E.00716
; LINE_WIDTH: 0.47031
G1 X134.268 Y138.591 E.00777
; LINE_WIDTH: 0.503857
G1 X134.076 Y138.477 E.00838
; LINE_WIDTH: 0.53572
G1 X133.499 Y137.832 E.03477
; LINE_WIDTH: 0.529007
G1 X133.396 Y137.56 E.01151
; LINE_WIDTH: 0.4854
G1 X133.293 Y137.288 E.01048
; LINE_WIDTH: 0.437956
G3 X133.172 Y136.957 I2.657 J-1.158 E.01136
G1 X132.706 Y136.221 F36000
; LINE_WIDTH: 0.37689
G1 F12000
G1 X132.469 Y137.108 E.02499
G1 X133.129 Y137.768 E.0254
G1 X132.865 Y137.157 E.01811
G1 X132.733 Y136.594 E.01575
G1 X132.711 Y136.281 E.00852
G1 X134.507 Y139.144 F36000
; LINE_WIDTH: 0.38018
G1 F12000
G1 X135.148 Y139.785 E.02491
G1 X136.073 Y139.537 E.02632
G1 X135.426 Y139.483 E.01785
G3 X134.561 Y139.169 I.585 J-2.958 E.02538
; WIPE_START
G1 X134.93 Y139.34 E-.15442
G1 X135.426 Y139.483 E-.19611
G1 X136.073 Y139.537 E-.2468
G1 X135.66 Y139.648 E-.16267
; WIPE_END
G1 E-.04 F1800
G1 X141.904 Y135.26 Z2.2 F36000
G1 X143.04 Y134.462 Z2.2
G1 Z1.8
G1 E.8 F1800
; LINE_WIDTH: 0.418882
G1 F12000
G1 X137.794 Y129.216 E.22727
G1 X134.271 Y132.739 E.15264
G1 X133.784 Y133.196 E.02046
; LINE_WIDTH: 0.366777
G1 X133.414 Y133.557 E.01365
G1 X133.193 Y134.38 E.02248
G1 X133.515 Y133.921 E.0148
G1 X133.993 Y133.454 E.01763
; LINE_WIDTH: 0.41837
G1 X134.541 Y133.072 E.02043
G1 X135.072 Y132.846 E.01767
G1 X135.925 Y132.69 E.02654
G1 X136.498 Y132.7 E.01754
G1 X137.372 Y132.917 E.02754
G1 X137.612 Y133.021 E.00799
G1 X138.208 Y133.384 E.02136
G1 X138.62 Y133.745 E.01675
G1 X139.142 Y134.464 E.0272
G3 X139.522 Y135.519 I-5.079 J2.422 E.03437
G3 X139.393 Y137.223 I-3.777 J.571 E.05273
G1 X139.168 Y137.752 E.01758
; LINE_WIDTH: 0.404608
G1 X138.906 Y138.096 E.01275
; LINE_WIDTH: 0.365987
G1 X138.644 Y138.44 E.01139
G1 X138.224 Y138.829 E.01506
G1 X137.876 Y139.064 E.01105
G1 X138.699 Y138.843 E.02244
; LINE_WIDTH: 0.375093
G1 X139.022 Y138.502 E.0127
; LINE_WIDTH: 0.418031
G3 X139.777 Y137.724 I18.063 J16.78 E.03314
G1 X142.997 Y134.504 E.1392
G1 X142.506 Y134.462 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X137.794 Y129.749 E.20476
G1 X135.091 Y132.452 E.11744
G1 X135.867 Y132.318 E.02417
G1 X136.518 Y132.323 E.02002
G1 X137.472 Y132.554 E.03015
G1 X137.808 Y132.699 E.01124
G1 X138.404 Y133.062 E.02145
G1 X138.879 Y133.471 E.01926
G1 X139.452 Y134.25 E.02971
G3 X139.896 Y135.473 I-4.869 J2.457 E.0401
G1 X139.952 Y136.045 E.01764
G1 X139.91 Y136.658 E.01887
G1 X139.79 Y137.178 E.01639
G1 X142.464 Y134.504 E.11617
G1 X141.973 Y134.462 F36000
G1 F12000
G1 X137.794 Y130.283 E.18159
G2 X136.161 Y131.922 I68.006 J69.374 E.07112
G1 X136.899 Y132.005 E.02283
G1 X137.578 Y132.192 E.02164
G1 X138.004 Y132.377 E.01425
G1 X138.6 Y132.74 E.02145
G1 X139.138 Y133.197 E.0217
G3 X140.067 Y134.725 I-3.259 J3.028 E.05534
G1 X140.27 Y135.428 E.02246
G1 X140.328 Y136.107 E.02096
G1 X141.931 Y134.504 E.06966
G1 X141.44 Y134.462 F36000
; LINE_WIDTH: 0.421379
G1 F12000
G3 X137.794 Y130.816 I598.185 J-601.793 E.159
G1 X136.973 Y131.637 E.03583
G1 X137.672 Y131.827 E.02234
G3 X138.803 Y132.406 I-1.837 J4.979 E.03928
G1 X139.394 Y132.927 E.02429
G1 X139.68 Y133.247 E.01324
G1 X140.073 Y133.82 E.02143
G1 X140.328 Y134.324 E.01741
G3 X140.621 Y135.28 I-4.384 J1.869 E.03092
G1 X141.397 Y134.504 E.03385
G1 X140.861 Y134.409 F36000
; LINE_WIDTH: 0.527
G1 F12000
G2 X140.861 Y134.514 I-.024 J.052 E.00914
G1 X137.824 Y131.367 F36000
; LINE_WIDTH: 0.51804
G1 F12000
G2 X137.823 Y131.47 I-.03 J.051 E.00958
G1 X144.588 Y134.882 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X144.485 Y134.779 E.00484
G1 X144.322 Y134.8 E.00545
G1 X143.399 Y135.723 E.04329
G1 X145.516 Y137.841 E.09933
G1 X144.919 Y138.326 E.02553
G1 X144.919 Y138.667 E.01131
G1 X146.474 Y140.222 E.07296
G1 X140.222 Y146.474 E.29332
G1 X138.667 Y144.919 E.07296
G1 X138.326 Y144.919 E.01131
G1 X137.841 Y145.516 E.02553
G1 X105.526 Y113.202 E1.51593
G1 X106.123 Y112.717 E.02552
G1 X106.123 Y112.376 E.01131
G1 X105.68 Y111.933 E.02081
G1 X111.933 Y105.68 E.29332
G1 X112.376 Y106.123 E.0208
G1 X112.717 Y106.123 E.01131
G1 X113.202 Y105.526 E.02553
G1 X115.319 Y107.644 E.09933
G1 X116.242 Y106.721 E.04329
G1 X116.264 Y106.556 E.00551
G1 X116.162 Y106.454 E.00478
G1 X145.283 Y138.516 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X155.724 Y148.956 E.40909
G1 X145.211 Y151.464 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X144.06 Y150.312 E.05401
G1 X150.312 Y144.06 E.29332
G1 X149.161 Y142.908 E.05401
G1 X138.516 Y145.283 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X148.956 Y155.724 E.40909
; CHANGE_LAYER
; Z_HEIGHT: 2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X147.542 Y154.31 E-.76
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
G1 X134.243 Y135.82
G1 Z2
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.302 Y135.57 E.00791
G3 X135.829 Y134.241 I1.826 J.556 E.06556
G1 X136.095 Y134.218 E.00819
G3 X134.235 Y135.88 I.033 J1.908 E.28494
; WIPE_START
M204 S10000
G1 X134.302 Y135.57 E-.12053
G1 X134.396 Y135.321 E-.10128
G1 X134.526 Y135.087 E-.10129
G1 X134.686 Y134.875 E-.10127
G1 X134.875 Y134.686 E-.10131
M73 P61 R7
G1 X135.087 Y134.526 E-.10127
G1 X135.32 Y134.396 E-.10128
G1 X135.399 Y134.366 E-.03177
; WIPE_END
G1 E-.04 F1800
G17
G3 Z2.4 I.857 J-.864 P1  F36000
G1 X114.06 Y113.209 Z2.4
G1 Z2
G1 E.8 F1800
G1 F12000
M204 S6000
G1 X114.107 Y113.183 E.00166
G3 X114.616 Y113.028 I.807 J1.73 E.01639
G1 X114.881 Y113.005 E.00819
G3 X113.874 Y113.313 I.033 J1.909 E.33583
G1 X114.008 Y113.239 E.00469
; WIPE_START
M204 S10000
G1 X114.107 Y113.183 E-.04336
G1 X114.356 Y113.088 E-.1013
G1 X114.616 Y113.028 E-.10126
G1 X114.881 Y113.005 E-.10128
G1 X115.148 Y113.018 E-.10128
G1 X115.409 Y113.069 E-.10129
G1 X115.661 Y113.156 E-.10127
G1 X115.899 Y113.277 E-.1013
G1 X115.915 Y113.289 E-.00765
; WIPE_END
G1 E-.04 F1800
G1 X109.336 Y109.419 Z2.4 F36000
G1 X98.854 Y103.254 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.499 Y99.609 E.17101
G1 X103.254 Y98.854 E.0354
G1 X105.944 Y101.544 E.12619
G1 X101.544 Y105.944 E.20641
G1 X98.896 Y103.296 E.1242
G1 X99.409 Y103.254 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F11963.591
M204 S6000
G1 X99.562 Y103.101 E.00666
G1 F11240.88
G1 X99.845 Y102.818 E.01229
G1 F9965.279
G1 X100.127 Y102.535 E.01229
G1 F8766.478
G1 X100.41 Y102.252 E.01229
G1 F7644.477
G1 X100.693 Y101.969 E.01229
G1 F6599.275
G1 X100.976 Y101.687 E.01229
G1 F5630.874
G1 X101.259 Y101.404 E.01229
G1 F4739.273
G1 X101.542 Y101.121 E.01229
G1 F3924.472
G1 X101.84 Y100.823 E.01296
G1 F3148.77
G1 X102.123 Y100.54 E.01229
G1 F2491.72
G1 X102.405 Y100.257 E.01229
G1 F1911.47
G1 X102.688 Y99.974 E.01229
G1 F1408.019
G1 X102.971 Y99.691 E.01229
G1 F981.369
G1 X103.254 Y99.409 E.01229
G1 F631.519
G1 X103.283 Y99.438 E.00126
G1 F600
G1 X105.36 Y101.515 E.09028
G1 F631.519
G1 X105.389 Y101.544 E.00126
G1 F981.369
G1 X105.107 Y101.827 E.01229
G1 F1408.019
G1 X104.824 Y102.11 E.01229
G1 F1911.47
G1 X104.541 Y102.392 E.01229
G1 F2491.72
G1 X104.258 Y102.675 E.01229
G1 F3148.77
G1 X103.975 Y102.958 E.01229
G1 F3882.62
G1 X103.692 Y103.241 E.01229
G1 F4523.102
G1 X103.409 Y103.524 E.01229
G1 F4356.13
G1 X103.241 Y103.692 E.00732
G1 F3882.607
G1 X102.958 Y103.975 E.01229
G1 F3148.758
G1 X102.675 Y104.258 E.01229
G1 F2491.709
G1 X102.392 Y104.541 E.01229
G1 F1911.46
G1 X102.11 Y104.824 E.01229
G1 F1408.011
G1 X101.827 Y105.107 E.01229
G1 F981.362
G1 X101.544 Y105.389 E.01229
G1 F631.513
G1 X101.515 Y105.36 E.00126
G1 F600
G1 X99.451 Y103.296 E.08969
; WIPE_START
M204 S10000
G1 X99.562 Y103.101 E-.08542
G1 X99.845 Y102.818 E-.152
G1 X100.127 Y102.535 E-.152
G1 X100.41 Y102.252 E-.152
G1 X100.693 Y101.969 E-.152
G1 X100.817 Y101.845 E-.06659
; WIPE_END
G1 E-.04 F1800
G17
G3 Z2.4 I-.835 J.885 P1  F36000
G1 X154.616 Y152.639 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.113 Y160.141 E.25921
G1 X145.844 Y158.871 E.05957
G1 X148.762 Y155.953 E.13689
G1 X138.329 Y145.521 E.48942
G1 X136.858 Y146.992 E.06901
G1 X104.051 Y114.185 E1.53904
G1 X105.522 Y112.714 E.06901
G1 X95.941 Y103.133 E.44948
G1 X103.133 Y95.941 E.33738
G1 X110.801 Y103.609 E.35974
G1 X112.714 Y105.522 E.08974
G1 X114.185 Y104.051 E.06902
G1 X116.853 Y106.715 E.12506
G1 X111.581 Y111.986 E.24729
G1 X110.478 Y116.104 E.14139
G1 X113.726 Y119.351 E.15236
G1 X117.843 Y118.248 E.14139
G1 X123.114 Y112.978 E.24725
G1 X138.066 Y127.929 E.7014
G1 X132.795 Y133.2 E.24727
G1 X131.691 Y137.317 E.14139
G1 X134.939 Y140.565 E.15236
G1 X139.056 Y139.461 E.14139
G1 X144.328 Y134.19 E.24729
G1 X146.992 Y136.858 E.12506
G1 X145.521 Y138.329 E.06902
G1 X155.953 Y148.762 E.48942
G1 X158.871 Y145.844 E.13689
G1 X160.141 Y147.113 E.05957
G1 X154.658 Y152.596 E.25722
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.113 Y160.696 E.2401
G1 X145.289 Y158.871 E.07928
G1 X148.207 Y155.953 E.1268
G1 X138.329 Y146.075 E.42926
G1 X136.858 Y147.546 E.06393
G1 X103.496 Y114.185 E1.44971
G1 X104.968 Y112.714 E.06393
G1 X95.386 Y103.133 E.41635
G1 X103.133 Y95.386 E.33661
G1 X111.078 Y103.332 E.34528
G1 X112.714 Y104.968 E.07108
G1 X114.185 Y103.496 E.06393
G1 X117.893 Y107.199 E.16101
G1 X147.546 Y136.858 E1.2887
G1 X146.075 Y138.329 E.06393
G1 X155.953 Y148.207 E.42926
G1 X158.871 Y145.289 E.1268
G1 X160.696 Y147.113 E.07928
G1 X155.213 Y152.596 E.23826
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.313 Y147.723 Z2.4 F36000
G1 X149.093 Y142.976 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X150.244 Y144.128 E.05401
G1 X144.128 Y150.244 E.28694
G1 X142.976 Y149.093 E.05401
G1 X138.577 Y145.231 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39622
G1 F12000
G1 X149.009 Y155.663 E.42471
G1 X145.231 Y138.577 F36000
; LINE_WIDTH: 0.39626
G1 F12000
G1 X155.663 Y149.009 E.42476
; WIPE_START
G1 X154.248 Y147.594 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X149.686 Y141.476 Z2.4 F36000
G1 X145.483 Y135.84 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X144.333 Y134.688 E.05401
G1 X134.689 Y144.331 E.45238
G1 X130.851 Y140.493 E.18005
G1 X132.613 Y138.731 E.08265
G1 X131.303 Y137.421 E.06147
G1 X132.482 Y133.019 E.15116
G1 X132.751 Y132.751 E.01259
G1 X130.916 Y130.916 E.08606
G1 X127.53 Y134.302 E.15885
G1 X127.189 Y134.302 E.01131
G1 X124.44 Y131.553 E.12899
G1 X123.175 Y132.817 E.05931
G1 X119.338 Y128.979 E.18005
G1 X128.98 Y119.336 E.45236
G1 X132.818 Y123.174 E.18005
G1 X131.553 Y124.44 E.05937
G1 X130.924 Y123.811 E.02948
G1 X130.583 Y123.811 E.01131
G1 X127.197 Y127.197 E.15884
G1 X123.845 Y123.845 E.15726
G1 X120.459 Y127.231 E.15884
G1 X120.118 Y127.231 E.01131
G1 X116.764 Y123.877 E.15737
G1 X115.5 Y125.141 E.05931
G1 X114.348 Y123.99 E.05401
G1 X126.839 Y120.289 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X123.691 Y117.132 E.13698
G1 X123.669 Y117.138 E.0007
G1 X117.132 Y123.675 E.28404
G1 X117.138 Y123.697 E.0007
G1 X120.281 Y126.839 E.13656
G1 X120.303 Y126.834 E.0007
G1 X126.803 Y120.334 E.28245
G1 X126.314 Y120.289 F36000
G1 F12000
G1 X123.683 Y117.657 E.11434
G1 X117.657 Y123.683 E.26182
G1 X120.289 Y126.314 E.11434
G1 X126.272 Y120.331 E.25998
G1 X125.781 Y120.289 F36000
G1 F12000
G1 X123.683 Y118.191 E.09117
G1 X118.191 Y123.683 E.23865
G1 X120.289 Y125.781 E.09117
G1 X125.738 Y120.331 E.23681
G1 X125.248 Y120.289 F36000
G1 F12000
G1 X123.683 Y118.724 E.06799
G1 X118.724 Y123.683 E.21548
G1 X120.289 Y125.248 E.06799
G1 X125.205 Y120.331 E.21364
G1 X124.714 Y120.289 F36000
G1 F12000
G1 X123.683 Y119.257 E.04482
G1 X119.257 Y123.683 E.19231
G1 X120.289 Y124.714 E.04482
G1 X124.672 Y120.331 E.19047
G1 X124.181 Y120.289 F36000
G1 F12000
G1 X123.683 Y119.791 E.02165
G1 X119.79 Y123.683 E.16914
G1 X120.289 Y124.181 E.02165
G1 X124.139 Y120.331 E.16729
G1 X120.289 Y123.683 F36000
; LINE_WIDTH: 0.37047
G1 F12000
G1 X123.64 Y120.331 E.12652
; WIPE_START
G1 X122.226 Y121.745 E-.76
; WIPE_END
G1 E-.04 F1800
G17
G3 Z2.4 I1.213 J.093 P1  F36000
G1 X122.93 Y112.532 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X117.366 Y118.096 E.24176
G1 X116.638 Y118.291
G1 X122.663 Y112.266 E.26183
G1 X122.396 Y111.999
G1 X115.909 Y118.486 E.2819
G1 X115.181 Y118.681
G1 X122.13 Y111.732 E.30197
G1 X121.863 Y111.466
G1 X114.452 Y118.877 E.32204
G1 X113.783 Y119.013
G1 X116.188 Y116.608 E.10452
G1 X115.263 Y116.999
G1 X113.51 Y118.753 E.0762
G1 X113.243 Y118.486
G1 X114.71 Y117.019 E.06375
G1 X114.267 Y116.929
G1 X112.977 Y118.219 E.05607
G1 X112.71 Y117.953
G1 X113.895 Y116.767 E.0515
G1 X113.578 Y116.551
G1 X112.443 Y117.686 E.0493
G1 X112.177 Y117.419
G1 X113.307 Y116.289 E.04911
G1 X113.085 Y115.978
G1 X111.91 Y117.153 E.05105
G1 X111.643 Y116.886
G1 X112.919 Y115.61 E.05544
G1 X112.814 Y115.182
G1 X111.377 Y116.619 E.06245
G1 X111.11 Y116.353
G1 X112.817 Y114.646 E.07416
G1 X113.1 Y113.83
G1 X110.844 Y116.086 E.09804
; WIPE_START
M204 S10000
G1 X112.258 Y114.672 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X116.608 Y116.188 Z2.4 F36000
G1 Z2
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X121.597 Y111.199 E.2168
G1 X121.33 Y110.932
G1 X116.999 Y115.263 E.18821
G1 X117.019 Y114.71
G1 X121.064 Y110.665 E.17577
G1 X120.797 Y110.399
G1 X116.929 Y114.267 E.16809
G1 X116.767 Y113.895
G1 X120.53 Y110.132 E.16352
G1 X120.264 Y109.865
G1 X116.551 Y113.578 E.16133
G1 X116.289 Y113.307
G1 X119.997 Y109.599 E.16114
G1 X119.731 Y109.332
G1 X115.978 Y113.085 E.16308
G1 X115.61 Y112.919
M73 P62 R7
G1 X119.464 Y109.065 E.16747
G1 X119.198 Y108.799
G1 X115.182 Y112.814 E.17448
G1 X114.646 Y112.817
G1 X118.931 Y108.532 E.1862
G1 X118.665 Y108.265
G1 X113.83 Y113.1 E.21008
; WIPE_START
M204 S10000
G1 X115.244 Y111.686 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X110.929 Y115.468 Z2.4 F36000
G1 Z2
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X118.398 Y107.999 E.32458
G1 X118.131 Y107.732
G1 X111.124 Y114.74 E.30452
G1 X111.319 Y114.011
G1 X117.865 Y107.465 E.28445
G1 X117.598 Y107.199
G1 X111.514 Y113.283 E.26438
G1 X111.709 Y112.554
G1 X117.331 Y106.932 E.24431
; WIPE_START
M204 S10000
G1 X115.917 Y108.346 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X122.455 Y112.285 Z2.4 F36000
G1 X123.095 Y112.671 Z2.4
G1 Z2
M73 P62 R6
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.0956561
G1 F15000
G1 X122.592 Y113.174 E.00306
; WIPE_START
G1 X123.095 Y112.671 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X117.681 Y107.291 Z2.4 F36000
G1 X117.121 Y106.735 Z2.4
G1 Z2
G1 E.8 F1800
; LINE_WIDTH: 0.0946159
G1 F15000
G1 X116.649 Y107.311 E.00314
G1 X111.819 Y112.15 E.0288
G1 X117.176 Y106.75 F36000
; LINE_WIDTH: 0.13967
G1 F15000
G1 X116.705 Y107.221 E.00525
G3 X116.629 Y107.368 I-.804 J-.325 E.00131
; WIPE_START
G1 X116.705 Y107.221 E-.15144
G1 X117.176 Y106.75 E-.60856
; WIPE_END
G1 E-.04 F1800
G1 X113.84 Y113.109 Z2.4 F36000
G1 Z2
G1 E.8 F1800
; LINE_WIDTH: 0.175565
G1 F15000
G1 X113.729 Y113.098 E.0012
; LINE_WIDTH: 0.199968
G1 X113.697 Y113.096 E.00041
G1 X113.494 Y113.272 E.00344
G2 X113.096 Y113.697 I4.399 J4.523 E.00745
G1 X113.098 Y113.729 E.00042
; LINE_WIDTH: 0.17547
G1 X113.109 Y113.84 E.0012
; WIPE_START
G1 X113.098 Y113.729 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X114.659 Y112.83 Z2.4 F36000
G1 Z2
G1 E.8 F1800
; LINE_WIDTH: 0.117947
G1 F15000
G1 X114.438 Y112.758 E.00142
; WIPE_START
G1 X114.659 Y112.83 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X117.066 Y115.33 Z2.4 F36000
G1 Z2
G1 E.8 F1800
; LINE_WIDTH: 0.182854
G1 F15000
G3 X116.923 Y115.591 I-4.226 J-2.124 E.0034
G1 X116.668 Y116.248 F36000
; LINE_WIDTH: 0.235969
G1 F15000
G3 X116.248 Y116.668 I-3.276 J-2.857 E.00934
; WIPE_START
G1 X116.668 Y116.248 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X116.295 Y108.625 Z2.4 F36000
G1 X116.193 Y106.548 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X116.36 Y106.715 E.00783
G1 X115.376 Y107.7 E.04618
G1 X113.202 Y105.526 E.10196
G1 X112.649 Y106.191 E.0287
G1 X112.308 Y106.191 E.01131
G1 X111.865 Y105.748 E.0208
G1 X105.748 Y111.865 E.28694
G1 X106.191 Y112.308 E.0208
G1 X106.191 Y112.649 E.01131
G1 X105.526 Y113.202 E.0287
G1 X137.841 Y145.516 E1.51593
G1 X138.394 Y144.851 E.0287
G1 X138.735 Y144.851 E.01131
G1 X140.29 Y146.406 E.07296
G1 X146.406 Y140.29 E.28694
G1 X144.851 Y138.735 E.07296
G1 X144.851 Y138.394 E.01131
G1 X145.01 Y138.235 E.00746
G2 X145.516 Y137.841 I-2.456 J-3.677 E.0213
G1 X143.343 Y135.667 E.10196
G1 X139.505 Y139.505 F36000
G1 F15476.087
G1 X155.502 Y155.502 E.75047
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X155.889 Y149.431 E.0287
G1 X155.548 Y149.431 E.01131
G1 X154.082 Y147.966 E.06874
G1 X147.966 Y154.082 E.28694
G1 X149.431 Y155.548 E.06874
G1 X149.431 Y155.889 E.01131
G1 X149.272 Y156.048 E.00747
G2 X148.766 Y156.442 I2.439 J3.655 E.02129
G1 X149.543 Y157.219 E.03647
G1 X148.392 Y158.37 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X145.196 Y150.509 Z2.4 F36000
G1 X138.171 Y139.418 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X143.994 Y133.595 E.25306
G1 X143.728 Y133.328
G1 X137.442 Y139.614 E.27313
G1 X136.714 Y139.809
G1 X143.461 Y133.062 E.2932
G1 X143.195 Y132.795
G1 X135.986 Y140.004 E.31327
G1 X135.257 Y140.199
G1 X142.928 Y132.528 E.33333
G1 X142.661 Y132.262
G1 X138.136 Y136.787 E.19663
G1 X138.241 Y136.149
G1 X142.395 Y131.995 E.18048
G1 X142.128 Y131.729
G1 X138.192 Y135.665 E.17105
G1 X138.058 Y135.266
G1 X141.861 Y131.462 E.16528
G1 X141.595 Y131.195
G1 X137.868 Y134.922 E.16192
G1 X137.624 Y134.633
G1 X141.328 Y130.929 E.16097
G1 X141.061 Y130.662
G1 X137.332 Y134.391 E.16205
G1 X136.993 Y134.197
G1 X140.795 Y130.396 E.16519
G1 X140.528 Y130.129
G1 X136.592 Y134.065 E.17105
G1 X136.113 Y134.011
G1 X140.261 Y129.862 E.18027
G1 X139.995 Y129.596
G1 X135.476 Y134.115 E.19637
; WIPE_START
M204 S10000
G1 X136.89 Y132.701 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X136.787 Y138.136 Z2.4 F36000
G1 Z2
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X134.84 Y140.083 E.08458
G1 X134.574 Y139.816
G1 X136.149 Y138.241 E.06844
G1 X135.665 Y138.192
G1 X134.307 Y139.55 E.05901
G1 X134.04 Y139.283
G1 X135.266 Y138.058 E.05324
G1 X134.922 Y137.868
G1 X133.774 Y139.016 E.04988
G1 X133.507 Y138.75
G1 X134.633 Y137.624 E.04893
G1 X134.391 Y137.332
G1 X133.24 Y138.483 E.05001
G1 X132.974 Y138.216
G1 X134.197 Y136.993 E.05316
G1 X134.065 Y136.592
G1 X132.707 Y137.95 E.05902
G1 X132.441 Y137.683
G1 X134.011 Y136.113 E.06825
G1 X134.115 Y135.476
G1 X132.174 Y137.417 E.08434
G1 X132.056 Y137.001
G1 X139.728 Y129.329 E.33338
G1 X139.461 Y129.063
G1 X132.251 Y136.273 E.31331
G1 X132.446 Y135.544
G1 X139.195 Y128.796 E.29324
G1 X138.928 Y128.53
G1 X132.642 Y134.816 E.27317
G1 X132.837 Y134.087
G1 X138.661 Y128.263 E.2531
M204 S10000
G1 X138.41 Y127.985 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.260433
G1 F15000
G1 X137.921 Y128.583 E.01368
G1 X133.127 Y133.377 E.12017
G1 X132.944 Y133.616 E.00535
G1 X138.447 Y128.022 F36000
; LINE_WIDTH: 0.305008
G1 F15000
G1 X137.999 Y128.471 E.01354
G1 X137.728 Y128.929 E.01138
; WIPE_START
G1 X137.999 Y128.471 E-.34715
G1 X138.447 Y128.022 E-.41285
; WIPE_END
G1 E-.04 F1800
G1 X143.845 Y133.419 Z2.4 F36000
G1 X144.271 Y133.846 Z2.4
G1 Z2
G1 E.8 F1800
; LINE_WIDTH: 0.259265
G1 F15000
G1 X143.674 Y134.335 E.01362
G1 X138.88 Y139.129 E.11952
G1 X138.642 Y139.312 E.00529
G1 X144.241 Y133.988 F36000
; LINE_WIDTH: 0.299867
G1 F15000
G1 X143.33 Y134.526 E.02217
G1 X144.234 Y133.809 F36000
; LINE_WIDTH: 0.307122
G1 F15000
G1 X143.785 Y134.257 E.01367
; LINE_WIDTH: 0.290421
G1 X143.805 Y134.3 E.00094
; LINE_WIDTH: 0.257013
G1 X143.825 Y134.342 E.00082
; LINE_WIDTH: 0.223604
G1 X143.845 Y134.384 E.00069
; WIPE_START
G1 X143.825 Y134.342 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X137.222 Y137.939 Z2.4 F36000
G1 Z2
G1 E.8 F1800
; LINE_WIDTH: 0.0942576
G1 F15000
G1 X137.158 Y137.99 E.00034
; LINE_WIDTH: 0.117691
G1 X137.079 Y138.046 E.00059
; LINE_WIDTH: 0.151346
G1 X136.999 Y138.102 E.00086
; LINE_WIDTH: 0.186051
G1 X136.92 Y138.157 E.00113
G1 X136.778 Y138.127 E.0017
; WIPE_START
G1 X136.92 Y138.157 E-.45605
G1 X136.999 Y138.102 E-.30395
; WIPE_END
G1 E-.04 F1800
G1 X138.127 Y136.778 Z2.4 F36000
G1 Z2
G1 E.8 F1800
; LINE_WIDTH: 0.186804
G1 F15000
G1 X138.157 Y136.92 E.0017
; LINE_WIDTH: 0.184987
G1 X138.102 Y136.999 E.00112
; LINE_WIDTH: 0.151324
G1 X138.046 Y137.079 E.00086
; LINE_WIDTH: 0.106936
G1 X137.939 Y137.222 E.00093
; WIPE_START
G1 X138.046 Y137.079 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X138.278 Y135.845 Z2.4 F36000
G1 Z2
G1 E.8 F1800
; LINE_WIDTH: 0.0928566
G1 F15000
G2 X138.197 Y135.694 I-2.053 J1.007 E.0007
; WIPE_START
G1 X138.278 Y135.845 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.407 Y134.046 Z2.4 F36000
G1 Z2
G1 E.8 F1800
; LINE_WIDTH: 0.146465
G1 F15000
G1 X135.216 Y134.18 E.00197
; LINE_WIDTH: 0.130928
G1 X135.125 Y134.249 E.00082
; LINE_WIDTH: 0.102417
G1 X135.034 Y134.317 E.00055
; WIPE_START
G1 X135.125 Y134.249 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X134.317 Y135.034 Z2.4 F36000
G1 Z2
G1 E.8 F1800
; LINE_WIDTH: 0.102437
G1 F15000
G1 X134.249 Y135.125 E.00055
; LINE_WIDTH: 0.141412
G2 X134.046 Y135.407 I3.945 J3.044 E.00279
; WIPE_START
G1 X134.249 Y135.125 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.916 Y127.5 Z2.4 F36000
G1 X133.91 Y127.36 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X130.762 Y124.203 E.13698
G1 X130.74 Y124.209 E.0007
G1 X124.203 Y130.746 E.28404
G1 X124.209 Y130.768 E.0007
G1 X127.352 Y133.91 E.13656
G1 X127.374 Y133.905 E.0007
G1 X133.874 Y127.405 E.28245
G1 X133.385 Y127.36 F36000
G1 F12000
G1 X130.754 Y124.729 E.11434
G1 X124.729 Y130.754 E.26182
G1 X127.36 Y133.385 E.11434
G1 X133.343 Y127.402 E.25998
G1 X132.852 Y127.36 F36000
G1 F12000
G1 X130.754 Y125.262 E.09117
G1 X125.262 Y130.754 E.23865
G1 X127.36 Y132.852 E.09117
G1 X132.809 Y127.402 E.23681
G1 X132.319 Y127.36 F36000
G1 F12000
G1 X130.754 Y125.795 E.06799
G1 X125.795 Y130.754 E.21548
G1 X127.36 Y132.319 E.06799
G1 X132.276 Y127.402 E.21364
G1 X131.785 Y127.36 F36000
G1 F12000
G1 X130.754 Y126.328 E.04482
G1 X126.328 Y130.754 E.19231
G1 X127.36 Y131.785 E.04482
G1 X131.743 Y127.402 E.19047
G1 X131.252 Y127.36 F36000
G1 F12000
G1 X130.754 Y126.862 E.02165
G1 X126.862 Y130.754 E.16914
G1 X127.36 Y131.252 E.02165
G1 X131.21 Y127.402 E.16729
G1 X127.36 Y130.754 F36000
; LINE_WIDTH: 0.37046
G1 F12000
G1 X130.711 Y127.402 E.12651
G1 X125.862 Y135.503 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X127.013 Y136.655 E.05401
G1 X136.656 Y127.012 E.45237
G1 X137.573 Y127.929 E.043
G1 X136.589 Y128.913 E.04617
G1 X122.13 Y114.454 E.67829
G1 X123.114 Y113.47 E.04615
G1 X125.142 Y115.498 E.09515
G1 X123.877 Y116.764 E.05936
G1 X123.512 Y116.74 E.01211
G1 X120.126 Y120.126 E.15885
M73 P63 R6
G1 X118.292 Y118.292 E.08606
G1 X118.023 Y118.56 E.01259
G1 X113.622 Y119.74 E.15116
G1 X113.423 Y119.541 E.00931
G1 X111.662 Y121.303 E.08265
G1 X107.824 Y117.465 E.18005
G1 X110.459 Y114.83 E.12363
G1 X111.269 Y111.806 E.10384
G1 X111.538 Y111.538 E.0126
G1 X103.99 Y103.99 E.35406
G1 X101.544 Y106.436 E.11476
G1 X98.684 Y103.577 E.13416
G1 X98.072 Y104.189 E.02872
G1 X101.91 Y108.027 E.18005
G1 X108.027 Y101.91 E.28694
G1 X104.189 Y98.072 E.18005
G1 X103.577 Y98.684 E.02872
G1 X103.254 Y98.362 E.01514
G1 X102.425 Y99.19 E.03888
G1 X103.133 Y96.478 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39623
G1 F12000
G1 X112.423 Y105.769 E.37827
; WIPE_START
G1 X111.009 Y104.355 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X103.567 Y102.659 Z2.4 F36000
G1 X99.762 Y101.792 Z2.4
G1 Z2
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F15000
G1 X101.792 Y99.762 E.0882
G1 X100.829 Y98.799 E.04184
G1 X98.799 Y100.829 E.0882
G1 X99.719 Y101.749 E.04
G1 X99.762 Y101.177 F36000
; LINE_WIDTH: 0.53525
G1 F12796.295
G1 X101.177 Y99.762 E.08028
G1 X100.829 Y99.414 E.01975
G1 X99.414 Y100.829 E.08028
G1 X99.719 Y101.134 E.01734
G1 X96.478 Y103.133 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39624
G1 F12000
G1 X105.769 Y112.423 E.37828
; CHANGE_LAYER
; Z_HEIGHT: 2.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X104.355 Y111.009 E-.76
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
G1 X99.099 Y103.009
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X101.342 Y100.766 E.10521
G1 X103.009 Y99.099 E.07821
G1 X105.699 Y101.789 E.12619
G1 X101.789 Y105.699 E.18342
G1 X99.141 Y103.051 E.1242
G1 X99.653 Y103.009 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F9730.842
M204 S6000
G1 X99.922 Y102.741 E.01167
G1 F8605.193
G1 X100.205 Y102.458 E.01229
G1 F7493.916
G1 X100.488 Y102.175 E.01229
G1 F6459.439
G1 X100.77 Y101.892 E.01229
G1 F5501.761
G1 X101.053 Y101.609 E.01229
G1 F4620.884
G1 X101.336 Y101.326 E.01229
G1 F3816.807
G1 X101.619 Y101.043 E.01229
G1 F3089.53
G1 X101.878 Y100.785 E.01124
G1 F2491.72
G1 X102.16 Y100.502 E.01229
G1 F1911.47
G1 X102.443 Y100.219 E.01229
G1 F1408.019
G1 X102.726 Y99.936 E.01229
G1 F981.369
G1 X103.009 Y99.653 E.01229
G1 F631.519
G1 X103.038 Y99.682 E.00126
G1 F600
G1 X105.115 Y101.76 E.09028
G1 F631.519
G1 X105.144 Y101.789 E.00126
G1 F981.369
G1 X104.862 Y102.072 E.01229
G1 F1408.019
G1 X104.579 Y102.355 E.01229
G1 F1911.47
G1 X104.296 Y102.637 E.01229
G1 F2491.72
G1 X104.013 Y102.92 E.01229
G1 F3148.77
G1 X103.73 Y103.203 E.01229
G1 F3830.053
G1 X103.447 Y103.486 E.01229
G1 F3777.888
G1 X103.203 Y103.73 E.01061
G1 F3148.746
G1 X102.92 Y104.013 E.01229
G1 F2491.698
G1 X102.637 Y104.296 E.01229
G1 F1911.45
G1 X102.355 Y104.579 E.01229
G1 F1408.003
G1 X102.072 Y104.862 E.01229
G1 F981.355
G1 X101.789 Y105.144 E.01229
G1 F631.508
G1 X101.76 Y105.115 E.00126
G1 F600
G1 X99.696 Y103.051 E.08969
; WIPE_START
M204 S10000
G1 X99.922 Y102.741 E-.14606
G1 X100.205 Y102.458 E-.152
G1 X100.488 Y102.175 E-.152
G1 X100.77 Y101.892 E-.152
G1 X101.053 Y101.609 E-.152
G1 X101.064 Y101.598 E-.00595
; WIPE_END
G1 E-.04 F1800
G17
G3 Z2.6 I-.915 J.803 P1  F36000
G1 X132.239 Y137.11 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X138.81 Y139.035 E.12805
G1 X143.953 Y133.892 E.24125
G1 X146.956 Y136.894 E.14084
G1 X145.471 Y138.378 E.06965
G1 X155.904 Y148.811 E.48942
G1 X158.843 Y145.872 E.13787
G1 X160.113 Y147.142 E.05957
G1 X154.616 Y152.639 E.25786
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.142 Y160.113 E.25786
G1 X145.872 Y158.843 E.05957
G1 X148.811 Y155.904 E.13787
G1 X138.378 Y145.471 E.48942
G1 X136.893 Y146.956 E.06966
G1 X104.087 Y114.149 E1.53904
G1 X105.572 Y112.664 E.06966
G1 X95.99 Y103.083 E.44948
G1 X103.083 Y95.99 E.33274
G1 X112.664 Y105.572 E.44948
G1 X114.149 Y104.087 E.06965
G1 X117.151 Y107.09 E.14084
G1 X112.008 Y112.233 E.24126
G1 X111.009 Y115.961 E.12805
G1 X113.868 Y118.821 E.13414
G1 X117.597 Y117.822 E.12805
G1 X122.739 Y112.679 E.24125
G1 X138.364 Y128.303 E.73296
G1 X133.221 Y133.446 E.24125
G1 X132.255 Y137.053 E.12386
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.953 Y133.338 E.23229
G1 X147.51 Y136.894 E.15456
G1 X146.026 Y138.378 E.06452
G1 X155.904 Y148.257 E.42926
G1 X158.843 Y145.318 E.12771
G1 X160.667 Y147.142 E.07928
G1 X155.17 Y152.639 E.23886
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.142 Y160.667 E.23886
G1 X145.318 Y158.843 E.07928
G1 X148.257 Y155.904 E.12771
G1 X138.378 Y146.026 E.42926
G1 X136.893 Y147.51 E.06452
G1 X103.532 Y114.149 E1.44971
G1 X105.017 Y112.664 E.06452
G1 X95.436 Y103.083 E.41635
G1 X103.083 Y95.436 E.33231
G1 X112.664 Y105.017 E.41635
G1 X114.149 Y103.532 E.06452
G1 X117.705 Y107.09 E.15456
G1 X112.359 Y112.436 E.23229
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X122.739 Y112.125 E.23229
G1 X138.918 Y128.303 E.70304
G1 X133.573 Y133.649 E.23229
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.047 Y132.686 Z2.6 F36000
G1 X127.36 Y130.754 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.42266
G1 F15000
G1 X130.711 Y127.402 E.14667
G1 X130.754 Y126.825 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X126.825 Y130.754 E.17074
G1 X127.36 Y131.289 E.02325
G1 X131.289 Y127.36 E.17074
G1 X130.796 Y126.867 E.02141
G1 X130.754 Y126.291 F36000
G1 F15000
G1 X126.291 Y130.754 E.19391
G1 X127.36 Y131.822 E.04643
G1 X131.822 Y127.36 E.19391
G1 X130.796 Y126.334 E.04458
G1 X130.754 Y125.758 F36000
G1 F15000
G1 X125.758 Y130.754 E.21708
G1 X127.36 Y132.356 E.0696
G1 X132.356 Y127.36 E.21708
G1 X130.796 Y125.801 E.06775
G1 X130.74 Y125.239 F36000
G1 F15000
G1 X125.233 Y130.746 E.2393
G1 X127.352 Y132.881 E.09242
G1 X132.881 Y127.368 E.23991
G1 X130.788 Y125.259 E.09127
G1 X125.285 Y120.289 F36000
G1 F15000
G1 X123.683 Y118.687 E.0696
G1 X118.687 Y123.683 E.21708
G1 X120.289 Y125.285 E.0696
G1 X125.242 Y120.331 E.21524
G1 X124.751 Y120.289 F36000
G1 F15000
G1 X123.683 Y119.22 E.04643
G1 X119.22 Y123.683 E.19391
G1 X120.289 Y124.751 E.04643
G1 X124.709 Y120.331 E.19207
G1 X120.289 Y123.683 F36000
; LINE_WIDTH: 0.42265
G1 F15000
G1 X123.64 Y120.331 E.14667
G1 X120.289 Y124.218 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X124.218 Y120.289 E.17074
G1 X123.683 Y119.754 E.02325
G1 X119.754 Y123.683 E.17074
G1 X120.246 Y124.176 E.02141
G1 X120.303 Y125.804 F36000
G1 F15000
G1 X125.81 Y120.297 E.2393
G1 X123.691 Y118.162 E.09242
G1 X118.162 Y123.675 E.23991
G1 X120.254 Y125.783 E.09127
G1 X104.576 Y114.149 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X136.851 Y146.424 E1.26459
; Slow Down End
G1 X138.644 Y145.174 F36000
; LINE_WIDTH: 0.43195
G1 F12000
G1 X149.065 Y155.595 E.46719
G1 X143.051 Y149.018 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X144.203 Y150.17 E.05401
G1 X150.17 Y144.203 E.27993
G1 X149.018 Y143.051 E.05401
G1 X145.174 Y138.644 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.43195
G1 F12000
G1 X155.595 Y149.065 E.46719
; WIPE_START
G1 X154.181 Y147.651 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X149.733 Y141.449 Z2.6 F36000
G1 X146.467 Y136.894 Z2.6
G1 Z2.2
G1 E.8 F1800
; Slow Down Start
; LINE_WIDTH: 0.405768
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.917 Y136.344 E.02297
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.451463
;_EXTRUDE_SET_SPEED
G1 X145.368 Y135.795 E.02586
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.497158
;_EXTRUDE_SET_SPEED
G1 X144.819 Y135.246 E.02876
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.521501
;_EXTRUDE_SET_SPEED
G1 X144.269 Y134.697 E.0303
G1 X144.103 Y134.619 E.00714
; Slow Down End
; LINE_WIDTH: 0.493947
G1 F12000
G1 X144.028 Y134.584 E.00304
; LINE_WIDTH: 0.53922
G1 X143.953 Y134.55 E.00335
G1 X143.862 Y134.621 E.00467
G1 X139.091 Y139.393 E.2729
G1 X138.98 Y139.457 E.00519
; LINE_WIDTH: 0.551427
G1 X135.085 Y140.501 E.16709
G1 X134.952 Y140.518 E.00556
G1 X134.845 Y140.436 E.00556
G1 X131.819 Y137.411 E.1773
G1 X131.738 Y137.304 E.00556
G1 X131.755 Y137.171 E.00556
G1 X132.799 Y133.276 E.16709
G1 X132.863 Y133.165 E.00532
G1 X137.635 Y128.393 E.27962
; LINE_WIDTH: 0.519648
G1 X137.653 Y128.371 E.00112
; LINE_WIDTH: 0.480583
G1 X137.67 Y128.348 E.00103
; LINE_WIDTH: 0.441518
G1 X137.688 Y128.326 E.00093
; LINE_WIDTH: 0.402453
G1 X137.706 Y128.303 E.00084
; LINE_WIDTH: 0.543845
G1 X137.671 Y128.228 E.00338
; Slow Down Start
; LINE_WIDTH: 0.500453
G1 F3000;_EXTRUDE_SET_SPEED
G1 X137.636 Y128.153 E.00309
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.454798
;_EXTRUDE_SET_SPEED
G1 X137.598 Y128.07 E.00307
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.40688
;_EXTRUDE_SET_SPEED
G1 X137.559 Y127.987 E.00271
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.405748
;_EXTRUDE_SET_SPEED
G1 X133.933 Y124.361 E.15161
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.451403
;_EXTRUDE_SET_SPEED
G1 X130.308 Y120.735 E.17068
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.497058
;_EXTRUDE_SET_SPEED
G1 X126.682 Y117.109 E.18976
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.538857
;_EXTRUDE_SET_SPEED
G1 X123.056 Y113.483 E.20722
G1 X122.89 Y113.406 E.0074
; Slow Down End
; LINE_WIDTH: 0.493862
G1 F12000
G1 X122.815 Y113.371 E.00305
; LINE_WIDTH: 0.539228
G1 X122.739 Y113.336 E.00335
G1 X122.649 Y113.408 E.00466
G1 X117.878 Y118.18 E.27291
G1 X117.766 Y118.244 E.00519
; LINE_WIDTH: 0.551466
G1 X113.871 Y119.287 E.1671
G1 X113.738 Y119.305 E.00556
G1 X113.632 Y119.223 E.00556
G1 X110.606 Y116.198 E.17732
G1 X110.525 Y116.091 E.00556
G1 X110.542 Y115.958 E.00556
G1 X111.586 Y112.063 E.1671
G1 X111.65 Y111.952 E.00532
G1 X116.421 Y107.18 E.27964
; LINE_WIDTH: 0.519648
G1 X116.439 Y107.158 E.00112
; LINE_WIDTH: 0.480583
G1 X116.457 Y107.135 E.00103
; LINE_WIDTH: 0.441518
G1 X116.475 Y107.112 E.00094
; LINE_WIDTH: 0.402453
G1 X116.493 Y107.09 E.00085
; LINE_WIDTH: 0.543988
G1 X116.458 Y107.015 E.00338
; Slow Down Start
; LINE_WIDTH: 0.500565
M73 P64 R6
G1 F3000;_EXTRUDE_SET_SPEED
G1 X116.423 Y106.94 E.00309
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.45487
;_EXTRUDE_SET_SPEED
G1 X116.385 Y106.857 E.00307
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.38362
;_EXTRUDE_SET_SPEED
G1 X116.346 Y106.774 E.00254
G1 X114.191 Y104.618 E.08461
; Slow Down End
; WIPE_START
G1 X115.606 Y106.033 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X108.689 Y102.805 Z2.6 F36000
G1 X106.001 Y101.551 Z2.6
G1 Z2.2
G1 E.8 F1800
; LINE_WIDTH: 0.399625
G1 F12000
G1 X103.247 Y98.797 E.11323
G1 X103.328 Y98.723 E.00318
; Slow Down Start
; LINE_WIDTH: 0.399625
G1 F3000;_EXTRUDE_SET_SPEED
G1 X103.511 Y98.557 E.0072
G1 X106.127 Y101.173 E.10754
; Slow Down End
; LINE_WIDTH: 0.39963
G1 F12000
G1 X106.241 Y101.299 E.00494
G1 X106.043 Y101.508 E.00837
; WIPE_START
G1 X106.241 Y101.299 E-.4781
G1 X106.127 Y101.173 E-.2819
; WIPE_END
G1 E-.04 F1800
G1 X102.706 Y98.91 Z2.6 F36000
G1 Z2.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G3 X103.328 Y98.175 I1.954 J1.025 E.03221
G3 X103.878 Y98.383 I.17 J.379 E.02164
G1 X104.114 Y98.147 E.01109
G1 X107.952 Y101.985 E.18005
G1 X101.985 Y107.952 E.27993
G1 X98.147 Y104.114 E.18005
G1 X98.383 Y103.878 E.01109
G1 X101.129 Y106.623 E.12879
G1 X101.469 Y106.623 E.01131
G1 X102.018 Y106.074 E.02575
G1 X102.018 Y105.962 E.00372
G1 X103.99 Y103.99 E.0925
G1 X111.481 Y111.482 E.35143
G2 X111.183 Y111.819 I.481 J.725 E.01511
G1 X110.347 Y114.942 E.10724
G1 X108.102 Y117.186 E.10529
G1 X111.94 Y121.024 E.18005
G1 X113.367 Y119.597 E.06694
G2 X113.721 Y119.795 I.348 J-.208 E.01409
G1 X118.01 Y118.646 E.1473
G2 X118.348 Y118.348 I-.387 J-.779 E.01511
G1 X120.641 Y120.641 E.10758
G1 X117.77 Y123.512 E.13469
G1 X117.77 Y123.853 E.01131
G1 X120.118 Y126.202 E.11016
G1 X120.459 Y126.202 E.01131
G1 X123.33 Y123.33 E.13469
G1 X127.712 Y127.712 E.20556
G1 X130.583 Y124.841 E.13469
G1 X130.924 Y124.841 E.01131
G1 X131.038 Y124.955 E.00532
G1 X132.539 Y123.454 E.0704
G1 X128.701 Y119.616 E.18005
G1 X119.616 Y128.7 E.42616
G1 X115.778 Y124.862 E.18005
G1 X124.863 Y115.778 E.42616
G1 X122.89 Y113.806 E.09252
G1 X122.186 Y114.51 E.03304
G1 X136.533 Y128.857 E.67304
G1 X137.237 Y128.152 E.03304
G1 X136.376 Y127.292 E.04037
G1 X127.292 Y136.376 E.42616
G1 X123.454 Y132.538 E.18005
G1 X124.955 Y131.038 E.07038
G1 X127.189 Y133.273 E.10484
G1 X127.53 Y133.273 E.01131
G1 X130.401 Y130.401 E.13469
G1 X132.695 Y132.695 E.10758
G2 X132.397 Y133.032 I.481 J.725 E.01511
G1 X131.247 Y137.322 E.1473
G1 X131.304 Y137.535 E.00732
G1 X132.557 Y138.787 E.05876
G1 X131.13 Y140.214 E.06694
G1 X134.968 Y144.052 E.18005
G1 X139.138 Y139.882 E.19563
G2 X139.561 Y139.561 I-.18 J-.677 E.01806
G1 X155.502 Y155.502 E.74784
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X155.814 Y149.506 E.03219
G1 X155.473 Y149.506 E.01131
G1 X154.008 Y148.041 E.06874
G1 X148.04 Y154.008 E.27993
G1 X149.506 Y155.473 E.06874
G1 X149.506 Y155.814 E.01131
G1 X148.766 Y156.442 E.03219
G1 X149.543 Y157.219 E.03647
G1 X148.392 Y158.37 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X146.758 Y149.753 Z2.6 F36000
G1 X142.248 Y136.875 Z2.6
G1 Z2.2
G1 E.8 F1800
G1 F15476.087
G1 X143.399 Y135.723 E.05401
G1 X145.516 Y137.841 E.09933
G1 X144.776 Y138.468 E.03219
G1 X144.776 Y138.809 E.01131
G1 X146.332 Y140.365 E.07296
G1 X140.365 Y146.332 E.27993
G1 X138.809 Y144.776 E.07296
G1 X138.468 Y144.776 E.01131
G1 X137.841 Y145.516 E.03219
G1 X105.526 Y113.202 E1.51593
G1 X106.266 Y112.574 E.03219
G1 X106.266 Y112.233 E.01131
G1 X105.823 Y111.79 E.0208
G1 X111.79 Y105.823 E.27993
G1 X112.233 Y106.266 E.0208
G1 X112.574 Y106.266 E.01131
G1 X112.747 Y106.094 E.00808
G3 X113.202 Y105.526 I3.987 J2.733 E.02417
G1 X115.319 Y107.644 E.09933
G1 X114.168 Y108.795 E.05401
; WIPE_START
G1 X115.319 Y107.644 E-.61876
G1 X115.057 Y107.381 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X108.273 Y103.883 Z2.6 F36000
G1 X101.277 Y100.277 Z2.6
G1 Z2.2
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F15000
G1 X100.314 Y99.314 E.04184
G1 X99.314 Y100.314 E.04346
G1 X100.277 Y101.277 E.04184
G1 X101.234 Y100.319 E.04161
G1 X100.662 Y100.277 F36000
; LINE_WIDTH: 0.53525
G1 F12796.295
G1 X100.314 Y99.929 E.01975
G1 X99.929 Y100.314 E.02186
G1 X100.277 Y100.662 E.01975
G1 X100.62 Y100.319 E.01946
G1 X98.797 Y103.247 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.399626
G1 F12000
G1 X101.551 Y106.001 E.11323
G1 X101.425 Y106.127 E.00518
; Slow Down Start
; LINE_WIDTH: 0.399625
G1 F3000;_EXTRUDE_SET_SPEED
G1 X101.287 Y106.241 E.00521
G1 X98.557 Y103.511 E.11222
G1 X98.723 Y103.328 E.0072
; Slow Down End
; LINE_WIDTH: 0.39962
G1 F12000
G1 X98.756 Y103.291 E.00144
G1 X96.553 Y103.083 F36000
; LINE_WIDTH: 0.43196
G1 F12000
G1 X105.826 Y112.356 E.41573
; WIPE_START
G1 X104.412 Y110.942 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X103.71 Y103.341 Z2.6 F36000
G1 X103.083 Y96.553 Z2.6
G1 Z2.2
G1 E.8 F1800
; LINE_WIDTH: 0.43195
G1 F12000
G1 X112.356 Y105.826 E.41571
; CHANGE_LAYER
; Z_HEIGHT: 2.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X110.942 Y104.412 E-.76
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
G1 X99.344 Y102.764
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X101.296 Y100.812 E.09156
G1 X102.764 Y99.344 E.06888
G1 X105.454 Y102.034 E.12619
G1 X102.034 Y105.454 E.16044
G1 X99.386 Y102.806 E.1242
G1 X99.898 Y102.764 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F7728.533
M204 S6000
G1 X100.159 Y102.504 E.01131
G1 F6758.609
G1 X100.442 Y102.221 E.01229
G1 F5778.126
G1 X100.724 Y101.938 E.01229
G1 F4874.443
G1 X101.007 Y101.655 E.01229
G1 F4047.561
G1 X101.29 Y101.372 E.01229
G1 F3297.478
G1 X101.573 Y101.09 E.01229
G1 F2624.195
G1 X101.915 Y100.747 E.01489
G1 F1911.489
G1 X102.198 Y100.464 E.01229
G1 F1408.036
G1 X102.481 Y100.181 E.01229
G1 F981.383
G1 X102.764 Y99.898 E.01229
G1 F631.53
G1 X102.793 Y99.927 E.00126
G1 F600
G1 X104.87 Y102.005 E.09028
G1 F631.519
G1 X104.899 Y102.034 E.00126
G1 F981.369
G1 X104.617 Y102.317 E.01229
G1 F1408.019
G1 X104.334 Y102.6 E.01229
G1 F1911.47
G1 X104.051 Y102.882 E.01229
G1 F2491.72
G1 X103.768 Y103.165 E.01229
G1 F3148.77
G1 X103.485 Y103.448 E.01229
G1 F3194.605
G1 X103.202 Y103.731 E.01229
G1 F2573.67
G1 X102.882 Y104.051 E.01391
G1 F1911.45
G1 X102.6 Y104.334 E.01229
G1 F1408.003
G1 X102.317 Y104.617 E.01229
G1 F981.355
G1 X102.034 Y104.899 E.01229
G1 F631.508
G1 X102.005 Y104.87 E.00126
G1 F600
G1 X99.941 Y102.806 E.08969
; WIPE_START
M204 S10000
G1 X100.159 Y102.504 E-.14171
G1 X100.442 Y102.221 E-.152
G1 X100.724 Y101.938 E-.152
G1 X101.007 Y101.655 E-.152
G1 X101.29 Y101.372 E-.152
G1 X101.309 Y101.353 E-.0103
; WIPE_END
G1 E-.04 F1800
G17
G3 Z2.8 I-.92 J.796 P1  F36000
G1 X132.239 Y137.11 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X138.81 Y139.035 E.12805
G1 X143.913 Y133.932 E.23941
G1 X146.914 Y136.935 E.14084
G1 X145.415 Y138.434 E.07033
G1 X155.848 Y148.867 E.48942
G1 X158.813 Y145.902 E.13908
G1 X160.082 Y147.172 E.05957
G1 X154.616 Y152.639 E.25645
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.172 Y160.082 E.25645
G1 X145.902 Y158.813 E.05957
G1 X148.867 Y155.848 E.13908
G1 X138.434 Y145.415 E.48942
G1 X136.935 Y146.914 E.07032
G1 X104.129 Y114.107 E1.53904
G1 X105.628 Y112.608 E.07032
G1 X96.046 Y103.027 E.44948
G1 X103.027 Y96.046 E.32748
G1 X112.608 Y105.628 E.44948
G1 X114.107 Y104.128 E.07033
G1 X117.111 Y107.129 E.14084
G1 X112.008 Y112.233 E.23941
G1 X111.009 Y115.961 E.12805
G1 X113.868 Y118.821 E.13414
G1 X117.597 Y117.822 E.12805
G1 X122.7 Y112.718 E.23941
G1 X138.324 Y128.342 E.73296
G1 X133.221 Y133.446 E.23941
G1 X132.255 Y137.053 E.12386
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.914 Y133.377 E.23059
G1 X147.469 Y136.935 E.15456
G1 X145.97 Y138.434 E.06514
G1 X155.848 Y148.313 E.42926
G1 X158.813 Y145.348 E.12883
G1 X160.637 Y147.172 E.07928
G1 X155.17 Y152.639 E.23755
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.172 Y160.637 E.23755
G1 X145.348 Y158.813 E.07928
G1 X148.313 Y155.848 E.12883
G1 X138.434 Y145.97 E.42926
G1 X136.935 Y147.469 E.06514
G1 X103.574 Y114.107 E1.44971
G1 X105.073 Y112.608 E.06514
G1 X95.492 Y103.027 E.41635
G1 X103.027 Y95.492 E.32744
G1 X112.608 Y105.073 E.41635
G1 X114.107 Y103.574 E.06514
G1 X117.666 Y107.129 E.15456
G1 X112.359 Y112.436 E.23059
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X122.7 Y112.164 E.23059
G1 X138.879 Y128.342 E.70304
G1 X133.573 Y133.649 E.23059
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X138.431 Y144.697 Z2.8 F36000
G1 X138.721 Y145.113 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.46831
G1 F12000
G1 X149.127 Y155.519 E.51015
G1 X148.392 Y158.37 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X149.588 Y155.732 E.03602
G1 X149.588 Y155.391 E.01131
G1 X148.122 Y153.926 E.06874
G1 X153.926 Y148.122 E.27226
G1 X155.391 Y149.588 E.06874
G2 X155.918 Y149.402 I.17 J-.356 E.02059
G3 X156.442 Y148.766 I4.369 J3.065 E.02735
G1 X157.219 Y149.543 E.03647
G1 X154.123 Y152.639 E.14523
G1 X155.604 Y154.12 E.06947
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X139.561 Y139.561 E.74784
G3 X139.138 Y139.882 I-.603 J-.356 E.01806
G1 X135.025 Y143.995 E.19294
G1 X131.187 Y140.157 E.18005
G1 X132.557 Y138.787 E.06426
G1 X131.304 Y137.535 E.05876
G1 X131.247 Y137.322 E.00732
G1 X132.397 Y133.032 E.1473
G3 X132.695 Y132.695 I.779 J.387 E.01511
G1 X118.348 Y118.348 E.67304
G3 X118.01 Y118.646 I-.725 J-.481 E.01511
M73 P65 R6
G1 X113.721 Y119.795 E.1473
G3 X113.367 Y119.597 I-.006 J-.405 E.01409
G1 X111.998 Y120.967 E.06426
G1 X115.835 Y124.805 E.18005
G1 X124.805 Y115.836 E.42076
G1 X122.832 Y113.864 E.09252
G1 X122.186 Y114.51 E.03032
G1 X136.533 Y128.857 E.67304
G1 X137.179 Y128.21 E.03032
G1 X136.319 Y127.35 E.04037
G1 X127.349 Y136.319 E.42076
G1 X123.511 Y132.481 E.18005
G1 X132.481 Y123.512 E.42076
G1 X128.643 Y119.674 E.18005
G1 X119.673 Y128.643 E.42076
G1 X120.825 Y129.794 E.05401
G1 X107.008 Y115.978 F36000
G1 F15476.087
G1 X108.16 Y117.129 E.05401
G1 X110.347 Y114.942 E.10261
G1 X111.183 Y111.819 E.10724
G3 X111.481 Y111.482 I.779 J.387 E.01511
G1 X103.99 Y103.99 E.35143
G1 X102.263 Y105.717 E.08101
G1 X102.263 Y105.829 E.00372
G1 X101.714 Y106.378 E.02575
G1 X101.374 Y106.378 E.01131
G1 X98.628 Y103.633 E.12879
G1 X98.229 Y104.032 E.01874
G1 X102.067 Y107.87 E.18005
G1 X107.87 Y102.067 E.27225
G1 X104.032 Y98.229 E.18005
G1 X103.633 Y98.628 E.01874
G2 X103.083 Y98.42 I-.379 J.17 E.02164
G1 X102.534 Y98.969 E.02575
G1 X102.534 Y99.081 E.00372
G1 X100.808 Y100.808 E.08101
G1 X99.783 Y99.783 E.04808
G1 X100.934 Y98.631 E.05401
G1 X103.027 Y96.635 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.46833
G1 F12000
G1 X112.28 Y105.888 E.45361
G1 X114.108 Y104.633 F36000
; LINE_WIDTH: 0.38292
G1 F12000
G1 X116.297 Y106.822 E.08579
; LINE_WIDTH: 0.407058
G1 X116.335 Y106.899 E.00253
; LINE_WIDTH: 0.455333
G1 X116.372 Y106.976 E.00287
; LINE_WIDTH: 0.503608
G1 X116.409 Y107.053 E.0032
; LINE_WIDTH: 0.539788
G1 X116.446 Y107.129 E.00345
G1 X116.364 Y107.238 E.00552
G1 X111.65 Y111.952 E.26991
G1 X111.586 Y112.063 E.0052
G1 X110.542 Y115.958 E.16326
G1 X110.525 Y116.091 E.00543
G1 X110.606 Y116.198 E.00543
G1 X113.632 Y119.223 E.17324
G1 X113.738 Y119.305 E.00543
G1 X113.871 Y119.287 E.00543
G1 X117.766 Y118.244 E.16326
G1 X117.878 Y118.18 E.0052
G1 X122.591 Y113.466 E.2699
G1 X122.7 Y113.383 E.00554
; LINE_WIDTH: 0.552005
G1 X122.777 Y113.42 E.00354
; LINE_WIDTH: 0.503695
G1 X122.854 Y113.458 E.0032
; LINE_WIDTH: 0.455385
G1 X122.931 Y113.495 E.00287
; LINE_WIDTH: 0.38302
G1 X123.007 Y113.532 E.00236
G1 X137.511 Y128.035 E.56844
; LINE_WIDTH: 0.407083
G1 X137.548 Y128.112 E.00253
; LINE_WIDTH: 0.455408
G1 X137.585 Y128.189 E.00287
; LINE_WIDTH: 0.503733
G1 X137.622 Y128.266 E.0032
; LINE_WIDTH: 0.539773
G1 X137.659 Y128.342 E.00345
G1 X137.577 Y128.451 E.00554
G1 X132.863 Y133.165 E.26989
G1 X132.799 Y133.276 E.0052
G1 X131.755 Y137.171 E.16326
G1 X131.738 Y137.304 E.00543
G1 X131.819 Y137.411 E.00543
G1 X134.845 Y140.436 E.17324
G1 X134.952 Y140.518 E.00543
G1 X135.085 Y140.501 E.00543
G1 X138.98 Y139.457 E.16326
G1 X139.091 Y139.393 E.0052
G1 X143.805 Y134.679 E.2699
G1 X143.913 Y134.596 E.00552
; LINE_WIDTH: 0.551865
G1 X143.99 Y134.634 E.00354
; LINE_WIDTH: 0.503595
G1 X144.067 Y134.671 E.0032
; LINE_WIDTH: 0.455325
G1 X144.144 Y134.708 E.00287
; LINE_WIDTH: 0.38358
G1 X144.22 Y134.745 E.00237
G1 X146.367 Y136.893 E.08429
G1 X145.113 Y138.721 F36000
; LINE_WIDTH: 0.46831
G1 F12000
G1 X155.519 Y149.127 E.51015
G1 X151.239 Y145.436 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X150.088 Y144.284 E.05401
G1 X144.284 Y150.088 E.27226
G1 X145.436 Y151.239 E.05401
; WIPE_START
G1 X144.284 Y150.088 E-.61876
G1 X144.547 Y149.825 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X140.005 Y143.691 Z2.8 F36000
G1 X114.168 Y108.795 Z2.8
G1 Z2.4
G1 E.8 F1800
G1 F15476.087
G1 X115.319 Y107.644 E.05401
G1 X113.202 Y105.526 E.09933
G1 X112.492 Y106.348 E.03602
G1 X112.152 Y106.348 E.01131
G1 X111.708 Y105.905 E.0208
G1 X105.905 Y111.708 E.27225
G1 X106.348 Y112.152 E.0208
G1 X106.348 Y112.492 E.01131
G1 X105.526 Y113.202 E.03602
G1 X137.841 Y145.516 E1.51593
G1 X138.55 Y144.695 E.03602
G1 X138.891 Y144.695 E.01131
G1 X140.446 Y146.25 E.07296
G1 X146.25 Y140.446 E.27226
G1 X144.695 Y138.891 E.07296
G1 X144.695 Y138.55 E.01131
G1 X145.516 Y137.841 E.03602
G1 X143.399 Y135.723 E.09933
G1 X142.248 Y136.875 E.05401
; WIPE_START
G1 X143.399 Y135.723 E-.61876
G1 X143.662 Y135.986 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X137.004 Y132.254 Z2.8 F36000
G1 X104.633 Y114.107 Z2.8
G1 Z2.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X136.893 Y146.367 E1.264
G1 X101.67 Y105.882 F36000
; LINE_WIDTH: 0.39963
G1 F12000
G1 X101.796 Y105.756 E.00518
G1 X99.042 Y103.002 E.11324
G1 X98.802 Y103.266 E.01038
G1 X101.532 Y105.996 E.11222
G1 X101.624 Y105.921 E.00347
G1 X96.635 Y103.027 F36000
; LINE_WIDTH: 0.46834
G1 F12000
G1 X105.888 Y112.28 E.45361
G1 X105.996 Y101.544 F36000
; LINE_WIDTH: 0.399625
G1 F12000
G1 X103.266 Y98.802 E.11248
G1 X103.002 Y99.042 E.01038
G1 X105.756 Y101.796 E.11323
G1 X105.955 Y101.587 E.00837
; CHANGE_LAYER
; Z_HEIGHT: 2.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X105.756 Y101.796 E-.10948
G1 X104.546 Y100.586 E-.65052
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
G1 X99.589 Y102.519
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X101.25 Y100.858 E.0779
G1 X102.519 Y99.589 E.05956
G1 X105.209 Y102.279 E.12619
G1 X102.279 Y105.209 E.13746
G1 X99.631 Y102.561 E.1242
G1 X100.143 Y102.519 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F5956.584
M204 S6000
G1 X100.395 Y102.267 E.01095
G1 F5134.768
G1 X100.678 Y101.984 E.01229
G1 F4285.08
G1 X100.961 Y101.701 E.01229
G1 F3512.192
G1 X101.244 Y101.418 E.01229
G1 F2816.104
G1 X101.527 Y101.136 E.01229
G1 F2196.816
G1 X101.671 Y100.992 E.00625
G1 F1911.489
G1 X101.953 Y100.709 E.01229
G1 F1408.036
G1 X102.236 Y100.426 E.01229
G1 F981.383
G1 X102.519 Y100.143 E.01229
G1 F631.53
G1 X102.548 Y100.172 E.00126
G1 F600
G1 X104.626 Y102.25 E.09028
G1 F631.519
G1 X104.655 Y102.279 E.00126
G1 F981.369
G1 X104.372 Y102.562 E.01229
G1 F1408.019
G1 X104.089 Y102.845 E.01229
G1 F1911.47
G1 X103.806 Y103.127 E.01229
G1 F2491.72
G1 X103.523 Y103.41 E.01229
G1 F2616.774
G1 X103.24 Y103.693 E.01229
G1 F2133.999
G1 X102.844 Y104.089 E.0172
G1 F1408.019
G1 X102.562 Y104.372 E.01229
G1 F981.369
G1 X102.279 Y104.655 E.01229
G1 F631.519
G1 X102.25 Y104.626 E.00126
G1 F600
G1 X100.186 Y102.561 E.08969
; WIPE_START
M204 S10000
G1 X100.395 Y102.267 E-.13736
G1 X100.678 Y101.984 E-.152
G1 X100.961 Y101.701 E-.152
G1 X101.244 Y101.418 E-.152
G1 X101.527 Y101.136 E-.152
G1 X101.554 Y101.108 E-.01465
; WIPE_END
G1 E-.04 F1800
G17
G3 Z3 I-.926 J.789 P1  F36000
G1 X132.239 Y137.11 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X138.81 Y139.035 E.12805
G1 X143.868 Y133.977 E.23729
G1 X146.872 Y136.978 E.14084
G1 X145.353 Y138.496 E.07124
G1 X155.786 Y148.929 E.48942
G1 X158.775 Y145.94 E.14023
G1 X160.045 Y147.209 E.05957
G1 X154.616 Y152.639 E.2547
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.209 Y160.045 E.2547
G1 X145.94 Y158.775 E.05957
G1 X148.929 Y155.786 E.14023
G1 X138.496 Y145.353 E.48942
G1 X136.977 Y146.872 E.07124
G1 X104.171 Y114.065 E1.53904
G1 X105.689 Y112.547 E.07124
G1 X96.108 Y102.965 E.44948
G1 X102.965 Y96.108 E.32169
G1 X112.547 Y105.689 E.44948
G1 X114.065 Y104.171 E.07124
G1 X117.066 Y107.174 E.14084
G1 X112.008 Y112.233 E.23729
G1 X111.009 Y115.961 E.12805
G1 X113.868 Y118.821 E.13414
G1 X117.597 Y117.822 E.12805
G1 X122.655 Y112.763 E.23729
G1 X138.279 Y128.388 E.73296
G1 X133.221 Y133.446 E.23728
G1 X132.255 Y137.053 E.12386
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.868 Y133.422 E.22861
G1 X147.426 Y136.977 E.15456
G1 X145.908 Y138.496 E.06599
G1 X155.786 Y148.374 E.42926
G1 X158.775 Y145.385 E.1299
G1 X160.6 Y147.209 E.07928
G1 X155.17 Y152.639 E.23593
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.209 Y160.6 E.23593
G1 X145.385 Y158.775 E.07928
G1 X148.374 Y155.786 E.1299
G1 X138.496 Y145.908 E.42926
G1 X136.977 Y147.427 E.06599
G1 X103.616 Y114.065 E1.44971
G1 X105.135 Y112.547 E.06599
G1 X95.554 Y102.965 E.41635
G1 X102.965 Y95.554 E.32208
G1 X112.547 Y105.135 E.41635
G1 X114.065 Y103.616 E.06599
G1 X117.62 Y107.175 E.15456
G1 X112.359 Y112.436 E.22862
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X122.655 Y112.209 E.22862
G1 X138.833 Y128.388 E.70304
G1 X133.573 Y133.649 E.22861
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X132.553 Y134.595 Z3 F36000
G1 Z2.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.909 Y133.266 E.04565
G1 X133.087 Y133.087 E.00837
G1 X117.955 Y117.956 E.70986
G1 X117.777 Y118.134 E.00837
G1 X113.76 Y119.205 E.13792
G1 X112.06 Y120.904 E.07973
G1 X115.898 Y124.742 E.18005
G1 X124.744 Y115.896 E.41498
G1 X122.379 Y113.532 E.11093
G1 X121.793 Y114.118 E.02748
G1 X136.925 Y129.249 E.70986
G1 X137.511 Y128.663 E.02749
G1 X136.258 Y127.41 E.05878
G1 X127.412 Y136.256 E.41499
G1 X131.25 Y140.094 E.18005
G1 X132.95 Y138.395 E.07973
G1 X134.977 Y140.422 E.09512
G1 X138.99 Y139.347 E.13782
G1 X139.169 Y139.169 E.00837
G1 X155.502 Y155.502 E.76625
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X155.643 Y149.676 E.04018
M73 P66 R6
G1 X155.302 Y149.676 E.01131
G1 X153.837 Y148.211 E.06874
G1 X148.211 Y153.837 E.26392
G1 X149.676 Y155.302 E.06874
G1 X149.676 Y155.643 E.01131
G1 X148.766 Y156.442 E.04018
G1 X149.543 Y157.219 E.03647
G1 X148.392 Y158.37 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X145.525 Y151.15 Z3 F36000
G1 Z2.6
G1 E.8 F1800
G1 F15476.087
G1 X144.373 Y149.999 E.05401
G1 X149.999 Y144.373 E.26392
G1 X151.15 Y145.525 E.05401
G1 X145.051 Y138.81 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.50672
G1 F12000
G1 X155.43 Y149.189 E.55476
G1 X138.81 Y145.051 F36000
; LINE_WIDTH: 0.50673
G1 F12000
G1 X149.189 Y155.43 E.55477
; WIPE_START
G1 X147.775 Y154.016 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X141.849 Y149.205 Z3 F36000
G1 X133.937 Y142.781 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.088 Y143.932 E.05401
G1 X144.21 Y134.81 E.42793
G1 X143.868 Y134.469 E.01602
G1 X143.007 Y135.331 E.04042
G1 X145.516 Y137.841 E.11774
G1 X144.606 Y138.639 E.04018
G1 X144.606 Y138.98 E.01131
G1 X146.161 Y140.535 E.07296
G1 X140.535 Y146.161 E.26392
G1 X138.98 Y144.606 E.07296
G1 X138.639 Y144.606 E.01131
G1 X137.841 Y145.516 E.04018
G1 X105.526 Y113.202 E1.51593
G1 X106.437 Y112.404 E.04018
G1 X106.437 Y112.063 E.01131
G1 X105.993 Y111.619 E.0208
G1 X111.619 Y105.993 E.26392
G1 X112.063 Y106.437 E.0208
G1 X112.404 Y106.437 E.01131
G1 X113.202 Y105.526 E.04018
G1 X115.712 Y108.036 E.11774
G1 X116.574 Y107.174 E.04042
G1 X116.284 Y106.884 E.01359
; WIPE_START
G1 X116.574 Y107.174 E-.15572
G1 X115.712 Y108.036 E-.46304
G1 X115.449 Y107.773 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X121.511 Y112.41 Z3 F36000
G1 X122.655 Y113.285 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X137.715 Y128.345 E.59007
G1 X133.572 Y124.724 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.42 Y123.572 E.05401
G1 X123.574 Y132.418 E.41499
G1 X119.736 Y128.58 E.18005
G1 X128.582 Y119.734 E.41499
G1 X127.431 Y118.583 E.05401
; WIPE_START
G1 X128.582 Y119.734 E-.61876
G1 X128.319 Y119.997 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X120.917 Y118.138 Z3 F36000
G1 X104.696 Y114.065 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X136.935 Y146.304 E1.26319
G1 X101.915 Y105.637 F36000
; LINE_WIDTH: 0.39962
G1 F12000
G1 X102.041 Y105.511 E.00518
G1 X99.286 Y102.757 E.11323
G1 X99.047 Y103.021 E.01038
G1 X101.777 Y105.751 E.11222
G1 X101.869 Y105.676 E.00346
G1 X105.751 Y101.789 F36000
; LINE_WIDTH: 0.399625
G1 F12000
G1 X103.021 Y99.047 E.11247
G1 X102.757 Y99.287 E.01038
G1 X105.511 Y102.041 E.11323
G1 X105.71 Y101.832 E.00837
; WIPE_START
G1 X105.511 Y102.041 E-.10949
G1 X104.301 Y100.831 E-.65051
; WIPE_END
G1 E-.04 F1800
G17
G3 Z3 I.666 J-1.019 P1  F36000
G1 X100.934 Y98.631 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.783 Y99.783 E.05401
G1 X100.808 Y100.808 E.04808
G1 X102.29 Y99.326 E.06952
G1 X102.29 Y99.214 E.00372
G1 X102.839 Y98.665 E.02575
G3 X103.388 Y98.873 I.17 J.379 E.02164
G1 X103.943 Y98.317 E.02606
G1 X107.781 Y102.155 E.18005
G1 X102.155 Y107.781 E.26392
G1 X98.317 Y103.943 E.18005
G1 X98.873 Y103.388 E.02606
G1 X101.618 Y106.133 E.12879
G1 X101.959 Y106.133 E.01131
G1 X102.508 Y105.584 E.02575
G1 X102.508 Y105.472 E.00372
G1 X103.99 Y103.99 E.06952
G1 X111.874 Y111.874 E.36984
G1 X111.696 Y112.052 E.00837
G1 X111.132 Y114.157 E.07228
G1 X108.222 Y117.066 E.13649
G1 X107.071 Y115.915 E.05401
; WIPE_START
G1 X108.222 Y117.066 E-.61876
G1 X108.485 Y116.804 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X103.542 Y110.988 Z3 F36000
G1 X96.724 Y102.965 Z3
G1 Z2.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.50677
G1 F12000
G1 X105.949 Y112.191 E.49314
; WIPE_START
G1 X104.535 Y110.776 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X103.688 Y103.191 Z3 F36000
G1 X102.965 Y96.724 Z3
G1 Z2.6
G1 E.8 F1800
; LINE_WIDTH: 0.50674
G1 F12000
G1 X112.191 Y105.949 E.49311
; CHANGE_LAYER
; Z_HEIGHT: 2.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X110.776 Y104.535 E-.76
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
G1 X100.111 Y102.551
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.834 Y102.274 E.01301
G1 X101.52 Y100.588 E.07908
G1 X102.274 Y99.834 E.0354
G1 X104.964 Y102.524 E.12619
G1 X102.524 Y104.964 E.11448
G1 X100.154 Y102.594 E.11119
G1 X100.388 Y102.274 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F4415.05
M204 S6000
G1 X100.577 Y102.085 E.0082
G1 F3882.62
G1 X100.86 Y101.803 E.01229
G1 F3148.77
G1 X101.143 Y101.52 E.01229
G1 F2491.72
G1 X101.426 Y101.237 E.01229
G1 F1911.47
G1 X101.708 Y100.954 E.01229
G1 F1408.019
G1 X101.991 Y100.671 E.01229
G1 F981.369
G1 X102.274 Y100.388 E.01229
G1 F631.519
G1 X102.303 Y100.417 E.00126
G1 F600
G1 X104.381 Y102.495 E.09028
G1 F631.508
G1 X104.41 Y102.524 E.00126
G1 F981.355
G1 X104.127 Y102.807 E.01229
G1 F1408.003
G1 X103.844 Y103.089 E.01229
G1 F1911.45
G1 X103.561 Y103.372 E.01229
G1 F2096.515
G1 X103.278 Y103.655 E.01229
G1 F1735.453
G1 X103.089 Y103.844 E.0082
G1 F1408.011
G1 X102.807 Y104.127 E.01229
G1 F981.362
G1 X102.524 Y104.41 E.01229
G1 F631.513
G1 X102.495 Y104.381 E.00126
G1 F600
G1 X100.431 Y102.317 E.08969
; WIPE_START
M204 S10000
G1 X100.577 Y102.085 E-.10397
G1 X100.86 Y101.803 E-.152
G1 X101.143 Y101.52 E-.152
G1 X101.426 Y101.237 E-.152
G1 X101.708 Y100.954 E-.152
G1 X101.798 Y100.865 E-.04804
; WIPE_END
G1 E-.04 F1800
G1 X106.706 Y106.709 Z3.2 F36000
G1 X132.239 Y137.11 Z3.2
G1 Z2.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X138.81 Y139.035 E.12805
G1 X143.82 Y134.025 E.23501
G1 X146.821 Y137.028 E.14084
G1 X145.285 Y138.564 E.07205
G1 X155.718 Y148.997 E.48942
G1 X158.738 Y145.977 E.14168
G1 X160.008 Y147.247 E.05957
G1 X154.616 Y152.639 E.25296
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.247 Y160.008 E.25296
G1 X145.977 Y158.738 E.05957
G1 X148.997 Y155.718 E.14168
G1 X138.564 Y145.285 E.48942
G1 X137.028 Y146.821 E.07204
G1 X104.222 Y114.014 E1.53904
G1 X105.757 Y112.479 E.07204
G1 X96.176 Y102.897 E.44948
G1 X102.897 Y96.176 E.31531
G1 X107.262 Y100.541 E.20477
G1 X112.479 Y105.757 E.24471
G1 X114.014 Y104.221 E.07205
G1 X117.017 Y107.223 E.14084
G1 X112.008 Y112.233 E.23501
G1 X111.009 Y115.961 E.12805
G1 X113.868 Y118.821 E.13414
G1 X117.597 Y117.822 E.12805
G1 X122.606 Y112.812 E.23501
G1 X138.231 Y128.436 E.73296
G1 X133.221 Y133.446 E.23501
G1 X132.255 Y137.053 E.12386
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.82 Y133.471 E.22651
G1 X147.376 Y137.028 E.15456
G1 X145.84 Y138.564 E.06674
G1 X155.718 Y148.442 E.42926
G1 X158.738 Y145.422 E.13124
G1 X160.563 Y147.247 E.07928
G1 X155.17 Y152.639 E.23432
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.247 Y160.563 E.23432
G1 X145.422 Y158.738 E.07928
G1 X148.442 Y155.718 E.13124
G1 X138.564 Y145.84 E.42926
G1 X137.028 Y147.376 E.06673
G1 X103.667 Y114.014 E1.44971
G1 X105.203 Y112.479 E.06673
G1 X95.622 Y102.897 E.41635
G1 X102.897 Y95.622 E.31617
G1 X107.539 Y100.264 E.20172
G1 X112.479 Y105.203 E.21463
G1 X114.014 Y103.667 E.06674
G1 X117.572 Y107.223 E.15456
G1 X112.359 Y112.436 E.22651
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X122.606 Y112.258 E.22651
G1 X138.785 Y128.436 E.70304
G1 X133.573 Y133.649 E.22651
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X130.163 Y138.879 Z3.2 F36000
G1 Z2.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X131.314 Y140.03 E.05401
G1 X132.95 Y138.395 E.07672
G1 X131.833 Y137.279 E.05236
G1 X132.909 Y133.266 E.13782
G1 X133.087 Y133.087 E.00837
G1 X117.955 Y117.956 E.70986
G1 X117.777 Y118.134 E.00837
G1 X113.76 Y119.205 E.13792
G1 X112.124 Y120.84 E.07672
G1 X108.286 Y117.002 E.18005
G1 X111.132 Y114.157 E.13348
G1 X111.696 Y112.052 E.07228
G1 X111.874 Y111.874 E.00837
G1 X103.99 Y103.99 E.36985
G1 X102.753 Y105.227 E.05802
G1 X102.753 Y105.339 E.00372
G1 X102.204 Y105.888 E.02575
G1 X101.863 Y105.888 E.01131
G1 X99.118 Y103.143 E.12879
G1 X98.416 Y103.845 E.03295
G1 X102.254 Y107.683 E.18005
G1 X107.683 Y102.254 E.25471
G1 X103.845 Y98.416 E.18005
G1 X103.143 Y99.118 E.03295
G2 X102.319 Y99.184 I-.393 J.266 E.03325
G1 X102.045 Y99.459 E.01288
G1 X102.045 Y99.571 E.00372
G1 X100.808 Y100.808 E.05802
G1 X99.783 Y99.783 E.04808
M73 P67 R6
G1 X100.934 Y98.631 E.05401
G1 X102.897 Y96.822 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54942
G1 F12000
G1 X112.093 Y106.017 E.53672
G1 X116.186 Y106.885 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X116.525 Y107.223 E.01588
G1 X115.712 Y108.036 E.03813
G1 X113.202 Y105.526 E.11774
G1 X112.708 Y106.02 E.02318
G3 X112.305 Y106.535 I-.886 J-.278 E.02215
G1 X111.964 Y106.535 E.01131
G1 X111.521 Y106.092 E.0208
G1 X106.092 Y111.521 E.25471
G1 X106.535 Y111.965 E.0208
G1 X106.535 Y112.305 E.01131
G1 X106.132 Y112.708 E.01889
G1 X106.02 Y112.708 E.00372
G1 X105.526 Y113.202 E.02318
G1 X137.841 Y145.516 E1.51593
G1 X137.321 Y146.036 E.02439
G1 X135.152 Y143.868 E.10172
G1 X144.161 Y134.859 E.42262
G1 X143.82 Y134.518 E.01602
G1 X143.007 Y135.331 E.03813
G1 X145.516 Y137.841 E.11774
G1 X145.022 Y138.335 E.02318
G2 X144.635 Y138.61 I.172 J.652 E.01609
G1 X144.508 Y138.737 E.00599
G1 X144.508 Y139.078 E.01131
G1 X146.063 Y140.633 E.07296
G1 X140.633 Y146.063 E.25471
G1 X144.471 Y149.901 E.18005
G1 X149.901 Y144.471 E.25471
G1 X148.749 Y143.32 E.05401
G1 X144.983 Y138.908 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54938
G1 F12000
G1 X155.332 Y149.257 E.60402
G1 X138.908 Y144.983 F36000
; LINE_WIDTH: 0.54941
G1 F12000
G1 X149.257 Y155.332 E.60406
G1 X137.661 Y139.703 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X138.99 Y139.347 E.04565
G1 X139.169 Y139.169 E.00837
G1 X155.502 Y155.502 E.76625
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X155.948 Y149.26 E.02318
G1 X155.948 Y149.372 E.00372
G1 X155.545 Y149.775 E.01889
G1 X155.204 Y149.775 E.01131
G1 X153.739 Y148.309 E.06874
G1 X148.309 Y153.739 E.25471
G1 X149.775 Y155.204 E.06874
G3 X149.558 Y155.762 I-.387 J.17 E.02204
G2 X148.766 Y156.442 I4.04 J5.507 E.03467
G1 X149.543 Y157.219 E.03647
G1 X148.392 Y158.37 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X145.919 Y150.104 Z3.2 F36000
G1 X133.504 Y124.792 Z3.2
G1 Z2.8
G1 E.8 F1800
G1 F15476.087
G1 X132.352 Y123.64 E.05401
G1 X123.638 Y132.354 E.40879
G1 X127.476 Y136.192 E.18005
G1 X136.19 Y127.478 E.40879
G1 X137.443 Y128.731 E.05878
G1 X136.925 Y129.249 E.0243
G1 X121.793 Y114.118 E.70986
G1 X122.312 Y113.599 E.02431
G1 X124.676 Y115.964 E.11093
G1 X115.962 Y124.678 E.4088
G1 X119.8 Y128.516 E.18005
G1 X128.514 Y119.802 E.4088
G1 X129.666 Y120.953 E.05401
G1 X122.606 Y113.353 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.40117
G1 F12000
G1 X137.647 Y128.394 E.62095
; WIPE_START
G1 X136.233 Y126.98 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.176 Y124.072 Z3.2 F36000
G1 X104.76 Y114.014 Z3.2
G1 Z2.8
G1 E.8 F1800
; LINE_WIDTH: 0.39736
G1 F12000
G1 X136.986 Y146.24 E1.3163
; WIPE_START
G1 X135.572 Y144.826 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X130.638 Y139.003 Z3.2 F36000
G1 X102.16 Y105.393 Z3.2
G1 Z2.8
G1 E.8 F1800
; LINE_WIDTH: 0.39962
G1 F12000
G1 X102.286 Y105.266 E.00518
G1 X99.531 Y102.512 E.11323
G1 X99.292 Y102.776 E.01038
G1 X102.022 Y105.506 E.11222
G1 X102.114 Y105.431 E.00346
G1 X105.506 Y102.034 F36000
G1 F12000
G1 X102.776 Y99.292 E.11247
G1 X102.512 Y99.531 E.01038
G1 X105.266 Y102.286 E.11323
G1 X105.465 Y102.077 E.00837
; WIPE_START
G1 X105.266 Y102.286 E-.10948
G1 X104.056 Y101.076 E-.65052
; WIPE_END
G1 E-.04 F1800
G17
G3 Z3.2 I-.297 J-1.18 P1  F36000
G1 X96.822 Y102.897 Z3.2
G1 Z2.8
G1 E.8 F1800
; LINE_WIDTH: 0.54943
G1 F12000
G1 X106.017 Y112.093 E.53673
; CHANGE_LAYER
; Z_HEIGHT: 3
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X104.603 Y110.678 E-.76
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
G1 X100.356 Y101.752
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.029 Y100.079 E.07849
G1 X104.719 Y102.769 E.12619
G1 X102.769 Y104.719 E.0915
G1 X100.079 Y102.029 E.12619
G1 X100.314 Y101.794 E.01102
G1 X100.633 Y102.029 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F3103.902
M204 S6000
G1 X100.898 Y101.765 E.0115
G1 F2491.72
G1 X101.181 Y101.482 E.01229
G1 F1911.47
G1 X101.463 Y101.199 E.01229
G1 F1408.019
G1 X101.746 Y100.916 E.01229
G1 F981.369
G1 X102.029 Y100.633 E.01229
G1 F631.519
G1 X102.058 Y100.662 E.00126
G1 F600
G1 X104.136 Y102.74 E.09028
G1 F631.508
G1 X104.165 Y102.769 E.00126
G1 F981.355
G1 X103.882 Y103.052 E.01229
G1 F1408.003
G1 X103.599 Y103.334 E.01229
G1 F1633.868
G1 X103.316 Y103.617 E.01229
G1 F1378.066
G1 X103.052 Y103.882 E.0115
G1 F981.355
G1 X102.769 Y104.165 E.01229
G1 F631.508
G1 X102.74 Y104.136 E.00126
G1 F600
G1 X100.676 Y102.072 E.08969
; WIPE_START
M204 S10000
G1 X100.898 Y101.765 E-.14398
G1 X101.181 Y101.482 E-.152
G1 X101.463 Y101.199 E-.152
G1 X101.746 Y100.916 E-.152
G1 X102.029 Y100.633 E-.152
G1 X102.044 Y100.648 E-.00803
; WIPE_END
G1 E-.04 F1800
G17
G3 Z3.4 I-.937 J.776 P1  F36000
G1 X132.239 Y137.11 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X138.81 Y139.035 E.12805
G1 X143.767 Y134.078 E.23254
G1 X146.769 Y137.08 E.14084
G1 X145.211 Y138.639 E.07311
G1 X155.643 Y149.072 E.48942
G1 X158.697 Y146.018 E.14327
G1 X159.967 Y147.287 E.05957
G1 X154.616 Y152.639 E.25105
G1 X156.737 Y154.76 E.09952
M73 P67 R5
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.287 Y159.967 E.25105
G1 X146.018 Y158.697 E.05957
G1 X149.072 Y155.643 E.14327
G1 X138.639 Y145.211 E.48942
G1 X137.08 Y146.769 E.07311
G1 X104.274 Y113.962 E1.53904
G1 X105.832 Y112.404 E.07311
G1 X96.251 Y102.823 E.44948
G1 X102.822 Y96.251 E.3083
G1 X103.604 Y97.033 E.03668
G1 X112.404 Y105.832 E.4128
G1 X113.962 Y104.274 E.07311
G1 X116.965 Y107.276 E.14084
G1 X112.008 Y112.233 E.23254
G1 X111.009 Y115.961 E.12805
G1 X113.868 Y118.821 E.13414
G1 X117.597 Y117.822 E.12805
G1 X122.554 Y112.865 E.23254
G1 X138.178 Y128.489 E.73296
G1 X133.221 Y133.446 E.23254
G1 X132.255 Y137.053 E.12386
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.767 Y133.523 E.22423
G1 X147.324 Y137.08 E.15456
G1 X145.765 Y138.639 E.06772
G1 X155.643 Y148.517 E.42926
G1 X158.697 Y145.463 E.13271
G1 X160.522 Y147.287 E.07928
G1 X155.17 Y152.639 E.23255
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.287 Y160.522 E.23255
G1 X145.463 Y158.697 E.07928
G1 X148.517 Y155.643 E.13271
G1 X138.639 Y145.765 E.42926
G1 X137.08 Y147.324 E.06772
G1 X103.719 Y113.962 E1.44971
G1 X105.278 Y112.404 E.06772
G1 X95.696 Y102.823 E.41635
G1 X102.822 Y95.696 E.30967
G1 X103.882 Y96.755 E.04602
G1 X112.404 Y105.278 E.37033
G1 X113.962 Y103.719 E.06772
G1 X117.519 Y107.276 E.15456
G1 X112.359 Y112.436 E.22423
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X122.554 Y112.31 E.22423
G1 X138.732 Y128.489 E.70304
G1 X133.573 Y133.649 E.22423
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X138.7 Y144.5 Z3.4 F36000
G1 X139.012 Y144.908 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.59131
G1 F11488.175
G1 X149.332 Y155.228 E.65216
G1 X148.392 Y158.37 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X149.335 Y155.873 E.02669
G1 X149.447 Y155.873 E.00372
G1 X149.879 Y155.441 E.02028
G1 X149.879 Y155.1 E.01131
G1 X148.414 Y153.634 E.06874
G1 X153.634 Y148.414 E.24491
G1 X155.1 Y149.879 E.06874
G1 X155.441 Y149.879 E.01131
G1 X155.873 Y149.447 E.02028
G1 X155.873 Y149.335 E.00372
G1 X156.442 Y148.766 E.02669
G1 X157.219 Y149.543 E.03647
G1 X154.123 Y152.639 E.14523
G1 X155.604 Y154.12 E.06947
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X139.169 Y139.169 E.76625
G1 X138.99 Y139.347 E.00837
G1 X137.661 Y139.703 E.04565
G1 X144.908 Y139.012 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.5913
G1 F11488.385
G1 X155.228 Y149.332 E.65215
G1 X150.948 Y145.727 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.796 Y144.576 E.05401
G1 X144.576 Y149.796 E.24491
G1 X140.738 Y145.958 E.18005
G1 X145.958 Y140.738 E.24491
G1 X144.403 Y139.183 E.07296
G1 X144.403 Y138.842 E.01131
G1 X144.836 Y138.409 E.02028
G1 X144.948 Y138.409 E.00372
G1 X145.516 Y137.841 E.02669
G1 X143.007 Y135.331 E.11774
G1 X143.767 Y134.57 E.03567
G1 X144.108 Y134.912 E.01602
G1 X135.226 Y143.794 E.41669
G1 X137.394 Y145.963 E.10172
M73 P68 R5
G1 X137.841 Y145.516 E.02093
G1 X105.526 Y113.202 E1.51593
G1 X106.095 Y112.633 E.02669
G1 X106.207 Y112.633 E.00372
G1 X106.639 Y112.201 E.02028
G1 X106.639 Y111.86 E.01131
G1 X106.196 Y111.417 E.0208
G1 X111.417 Y106.196 E.24491
G1 X111.86 Y106.639 E.0208
G1 X112.201 Y106.639 E.01131
G1 X112.633 Y106.207 E.02028
G1 X112.633 Y106.095 E.00372
G1 X113.202 Y105.526 E.02669
G1 X115.712 Y108.036 E.11774
G1 X116.472 Y107.276 E.03567
G1 X116.081 Y106.885 E.01834
; WIPE_START
G1 X116.472 Y107.276 E-.21015
G1 X115.712 Y108.036 E-.40861
G1 X115.449 Y107.773 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X121.423 Y112.523 Z3.4 F36000
G1 X122.554 Y113.423 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.42487
G1 F12000
G1 X137.578 Y128.446 E.66129
G1 X131.132 Y122.558 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.283 Y123.709 E.05401
G1 X123.712 Y132.28 E.40208
G1 X119.874 Y128.442 E.18005
G1 X128.445 Y119.871 E.40208
G1 X127.294 Y118.72 E.05401
; WIPE_START
G1 X128.445 Y119.871 E-.61876
G1 X128.182 Y120.134 E-.14125
; WIPE_END
G1 E-.04 F1800
G1 X120.803 Y118.184 Z3.4 F36000
G1 X104.834 Y113.962 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.42809
G1 F12000
G1 X137.038 Y146.166 E1.42945
; WIPE_START
G1 X135.624 Y144.752 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X130.719 Y138.904 Z3.4 F36000
G1 X102.405 Y105.148 Z3.4
G1 Z3
G1 E.8 F1800
; LINE_WIDTH: 0.399625
G1 F12000
G1 X102.531 Y105.021 E.00518
G1 X99.776 Y102.267 E.11324
G1 X99.536 Y102.531 E.01038
G1 X102.266 Y105.261 E.11222
G1 X102.359 Y105.186 E.00347
G1 X105.261 Y102.279 F36000
; LINE_WIDTH: 0.39962
G1 F12000
G1 X102.531 Y99.536 E.11247
G1 X102.267 Y99.776 E.01038
G1 X105.021 Y102.531 E.11323
G1 X105.22 Y102.322 E.00837
G1 X100.934 Y98.631 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.783 Y99.783 E.05401
G1 X100.808 Y100.808 E.04808
G1 X101.8 Y99.816 E.04653
G1 X101.8 Y99.704 E.00372
G1 X102.349 Y99.155 E.02575
G3 X102.898 Y99.363 I.17 J.379 E.02164
G1 X103.741 Y98.52 E.03954
G1 X107.579 Y102.358 E.18005
G1 X102.358 Y107.579 E.24491
G1 X98.52 Y103.741 E.18005
G1 X99.363 Y102.898 E.03954
G1 X102.108 Y105.643 E.12879
G1 X102.449 Y105.643 E.01131
G1 X102.998 Y105.094 E.02575
G1 X102.998 Y104.982 E.00372
G1 X103.99 Y103.99 E.04653
G1 X111.874 Y111.874 E.36984
G1 X111.696 Y112.052 E.00837
G1 X111.132 Y114.157 E.07228
G1 X108.36 Y116.928 E.13002
G1 X112.198 Y120.766 E.18005
G1 X113.76 Y119.205 E.07326
G1 X117.777 Y118.134 E.13792
G1 X117.955 Y117.956 E.00837
G1 X133.087 Y133.087 E.70986
G1 X132.909 Y133.266 E.00837
G1 X131.833 Y137.279 E.13782
G1 X132.95 Y138.395 E.05236
G1 X131.388 Y139.956 E.07326
G1 X127.55 Y136.118 E.18005
G1 X136.121 Y127.547 E.40208
G1 X137.374 Y128.8 E.05878
G1 X136.925 Y129.249 E.02106
G1 X121.793 Y114.118 E.70986
G1 X122.242 Y113.669 E.02105
G1 X124.607 Y116.034 E.11093
G1 X116.036 Y124.604 E.40208
G1 X114.885 Y123.453 E.05401
; WIPE_START
G1 X116.036 Y124.604 E-.61876
G1 X116.299 Y124.342 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X111.192 Y118.669 Z3.4 F36000
G1 X96.926 Y102.823 Z3.4
G1 Z3
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.59132
G1 F11487.965
G1 X106.092 Y111.988 E.57925
; WIPE_START
G1 X104.678 Y110.574 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X103.65 Y103.011 Z3.4 F36000
G1 X102.822 Y96.926 Z3.4
G1 Z3
G1 E.8 F1800
; LINE_WIDTH: 0.59131
G1 F11488.175
G1 X111.988 Y106.092 E.57924
; CHANGE_LAYER
; Z_HEIGHT: 3.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F11488.175
G1 X110.574 Y104.678 E-.76
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
G1 X100.324 Y101.784
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X101.111 Y100.997 E.03695
G1 X101.784 Y100.324 E.03157
G1 X104.474 Y103.014 E.12619
G1 X103.014 Y104.474 E.06851
G1 X100.366 Y101.827 E.1242
G1 X100.878 Y101.784 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F2023.146
M204 S6000
G1 X101.106 Y101.557 E.00988
G1 F1599.693
G1 X101.388 Y101.274 E.01229
G1 F1142.399
G1 X101.784 Y100.878 E.0172
G1 F631.519
G1 X101.813 Y100.907 E.00126
G1 F600
G1 X103.891 Y102.985 E.09028
G1 F631.513
G1 X103.92 Y103.014 E.00126
G1 F981.362
G1 X103.637 Y103.297 E.01229
G1 F1228.833
G1 X103.354 Y103.579 E.01229
G1 F1061.852
G1 X103.014 Y103.92 E.01479
G1 X102.985 Y103.891 E.00126
G1 F600
G1 X100.921 Y101.827 E.08969
; WIPE_START
M204 S10000
G1 X101.106 Y101.557 E-.12435
G1 X101.388 Y101.274 E-.152
G1 X101.784 Y100.878 E-.21265
G1 X101.813 Y100.907 E-.01558
G1 X102.289 Y101.383 E-.25543
; WIPE_END
G1 E-.04 F1800
G17
G3 Z3.6 I-.933 J.782 P1  F36000
G1 X132.239 Y137.11 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X138.81 Y139.035 E.12805
G1 X143.709 Y134.136 E.22983
G1 X146.712 Y137.138 E.14084
G1 X145.129 Y138.721 E.07426
G1 X155.562 Y149.153 E.48942
G1 X158.651 Y146.064 E.14495
G1 X159.921 Y147.333 E.05957
G1 X154.616 Y152.639 E.24889
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.333 Y159.921 E.24889
G1 X146.064 Y158.651 E.05957
G1 X149.153 Y155.562 E.14495
G1 X138.721 Y145.129 E.48942
G1 X137.138 Y146.712 E.07426
G1 X104.331 Y113.905 E1.53904
G1 X105.914 Y112.322 E.07426
G1 X96.333 Y102.741 E.44948
G1 X102.741 Y96.333 E.30062
G1 X105.845 Y99.437 E.14561
G1 X112.322 Y105.914 E.30387
G1 X113.905 Y104.331 E.07426
G1 X116.907 Y107.333 E.14084
G1 X112.008 Y112.233 E.22983
G1 X111.009 Y115.961 E.12805
G1 X113.868 Y118.821 E.13414
G1 X117.597 Y117.822 E.12805
G1 X122.496 Y112.923 E.22983
G1 X138.12 Y128.547 E.73296
G1 X133.221 Y133.446 E.22983
G1 X132.255 Y137.053 E.12386
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.709 Y133.581 E.22171
G1 X147.266 Y137.138 E.15456
G1 X145.683 Y138.721 E.06879
G1 X155.562 Y148.599 E.42926
G1 X158.651 Y145.509 E.13427
G1 X160.476 Y147.333 E.07928
G1 X155.17 Y152.639 E.23055
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.333 Y160.476 E.23055
G1 X145.509 Y158.651 E.07928
G1 X148.599 Y155.562 E.13427
G1 X138.721 Y145.683 E.42926
G1 X137.138 Y147.266 E.06879
G1 X103.776 Y113.905 E1.44971
G1 X105.359 Y112.322 E.06879
G1 X95.778 Y102.741 E.41635
G1 X102.741 Y95.778 E.30256
G1 X106.122 Y99.159 E.14693
G1 X112.322 Y105.359 E.26942
G1 X113.905 Y103.776 E.06879
G1 X117.461 Y107.333 E.15456
G1 X112.359 Y112.436 E.22171
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X122.496 Y112.368 E.22171
G1 X138.675 Y128.547 E.70304
G1 X133.573 Y133.649 E.22171
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X137.661 Y139.703 Z3.6 F36000
G1 Z3.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X138.99 Y139.347 E.04565
G1 X139.169 Y139.169 E.00837
G1 X155.502 Y155.502 E.76625
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X155.791 Y149.416 E.03052
G1 X155.791 Y149.529 E.00372
G1 X155.322 Y149.997 E.02198
G1 X154.982 Y149.997 E.01131
G1 X153.516 Y148.532 E.06874
G1 X148.532 Y153.516 E.23383
G1 X149.997 Y154.982 E.06874
G1 X149.997 Y155.322 E.01131
G1 X149.529 Y155.791 E.02198
G1 X149.416 Y155.791 E.00372
G1 X148.766 Y156.442 E.03052
G1 X149.543 Y157.219 E.03647
G1 X148.392 Y158.37 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X144.382 Y151.103 Z3.6 F36000
G1 X139.13 Y144.826 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.64274
G1 F10503.152
G1 X149.413 Y155.11 E.71081
G1 X144.826 Y139.13 F36000
; LINE_WIDTH: 0.6427
G1 F10503.852
G1 X155.11 Y149.413 E.71076
; WIPE_START
G1 X153.695 Y147.999 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X148.568 Y142.345 Z3.6 F36000
G1 X127.215 Y118.798 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X128.367 Y119.95 E.05401
G1 X119.948 Y128.369 E.39494
G1 X123.786 Y132.207 E.18005
G1 X132.205 Y123.788 E.39494
G1 X133.356 Y124.939 E.05401
G1 X122.496 Y113.501 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.45382
G1 F12000
M73 P69 R5
G1 X137.499 Y128.504 E.71044
G1 X114.958 Y123.379 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X116.11 Y124.531 E.05401
G1 X124.529 Y116.112 E.39494
G1 X122.164 Y113.747 E.11093
G1 X121.793 Y114.118 E.01738
G1 X136.925 Y129.249 E.70986
G1 X137.295 Y128.879 E.01737
G1 X136.042 Y127.626 E.05878
G1 X127.624 Y136.045 E.39494
G1 X131.462 Y139.883 E.18005
G1 X132.95 Y138.395 E.0698
G1 X131.833 Y137.279 E.05236
G1 X132.909 Y133.266 E.13782
G1 X133.087 Y133.087 E.00837
G1 X117.955 Y117.956 E.70986
G1 X117.777 Y118.134 E.00837
G1 X113.76 Y119.205 E.13792
G1 X112.272 Y120.693 E.0698
G1 X108.434 Y116.855 E.18005
G1 X111.132 Y114.157 E.12655
G1 X111.696 Y112.052 E.07228
G1 X111.874 Y111.874 E.00837
G1 X103.99 Y103.99 E.36984
G1 X103.243 Y104.737 E.03504
G1 X103.243 Y104.849 E.00372
G1 X102.694 Y105.398 E.02575
G1 X102.353 Y105.398 E.01131
G1 X99.608 Y102.653 E.12879
G1 X98.638 Y103.623 E.04549
G1 X102.476 Y107.461 E.18005
G1 X107.461 Y102.476 E.23383
G1 X103.623 Y98.638 E.18005
G1 X102.653 Y99.608 E.04549
G2 X102.104 Y99.4 I-.379 J.17 E.02164
G1 X101.555 Y99.949 E.02575
G1 X101.555 Y100.061 E.00372
G1 X100.808 Y100.808 E.03504
G1 X99.783 Y99.783 E.04808
G1 X100.934 Y98.631 E.05401
G1 X102.741 Y97.044 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.64271
G1 F10503.677
G1 X111.87 Y106.174 E.63102
G1 X115.966 Y106.885 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X116.414 Y107.333 E.02106
G1 X115.712 Y108.036 E.03296
G1 X113.202 Y105.526 E.11774
G1 X112.552 Y106.177 E.03052
G1 X112.551 Y106.289 E.00372
G1 X112.083 Y106.758 E.02198
G1 X111.742 Y106.758 E.01131
G1 X111.298 Y106.314 E.0208
G1 X106.314 Y111.299 E.23383
G1 X106.758 Y111.742 E.0208
G1 X106.758 Y112.083 E.01131
G1 X106.289 Y112.551 E.02198
G1 X106.177 Y112.551 E.00372
G1 X105.526 Y113.202 E.03052
G1 X137.841 Y145.516 E1.51593
G1 X137.468 Y145.889 E.01747
G1 X135.3 Y143.721 E.10172
G1 X144.051 Y134.97 E.41052
G1 X143.709 Y134.628 E.01602
G1 X143.007 Y135.331 E.03296
G1 X145.516 Y137.841 E.11774
G1 X144.866 Y138.491 E.03052
G1 X144.754 Y138.491 E.00372
G1 X144.285 Y138.96 E.02198
G1 X144.285 Y139.301 E.01131
G1 X145.84 Y140.856 E.07296
G1 X140.856 Y145.84 E.23383
G1 X144.694 Y149.678 E.18005
G1 X149.678 Y144.694 E.23383
G1 X150.83 Y145.845 E.05401
; WIPE_START
G1 X149.678 Y144.694 E-.61876
G1 X149.415 Y144.957 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X143.156 Y140.59 Z3.6 F36000
G1 X104.908 Y113.905 Z3.6
G1 Z3.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.45153
G1 F12000
G1 X137.095 Y146.093 E1.51566
; WIPE_START
G1 X135.681 Y144.678 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X130.805 Y138.807 Z3.6 F36000
G1 X102.65 Y104.903 Z3.6
G1 Z3.2
G1 E.8 F1800
; LINE_WIDTH: 0.399625
G1 F12000
G1 X102.776 Y104.777 E.00518
G1 X100.021 Y102.022 E.11324
G1 X99.781 Y102.286 E.01038
G1 X102.511 Y105.016 E.11222
G1 X102.604 Y104.941 E.00346
G1 X105.016 Y102.524 F36000
; LINE_WIDTH: 0.399635
G1 F12000
G1 X102.286 Y99.781 E.11248
G1 X102.022 Y100.021 E.01038
G1 X104.777 Y102.776 E.11324
G1 X104.975 Y102.567 E.00837
; WIPE_START
G1 X104.777 Y102.776 E-.10948
G1 X103.566 Y101.566 E-.65052
; WIPE_END
G1 E-.04 F1800
G17
G3 Z3.6 I-.216 J-1.198 P1  F36000
G1 X97.044 Y102.741 Z3.6
G1 Z3.2
G1 E.8 F1800
; LINE_WIDTH: 0.64271
G1 F10503.677
G1 X106.174 Y111.87 E.63102
; CHANGE_LAYER
; Z_HEIGHT: 3.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F10503.677
G1 X104.76 Y110.456 E-.76
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
G1 X100.846 Y101.262
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X101.539 Y100.569 E.03253
G1 X104.229 Y103.259 E.12619
G1 X103.259 Y104.229 E.04553
G1 X100.569 Y101.539 E.12619
G1 X100.803 Y101.304 E.01102
G1 X101.123 Y101.539 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1172.811
M204 S6000
G1 X101.539 Y101.123 E.01808
G1 F631.519
G1 X101.568 Y101.152 E.00126
G1 F600
G1 X103.646 Y103.23 E.09028
G1 F631.519
G1 X103.675 Y103.259 E.00126
G1 F881.388
G1 X103.259 Y103.675 E.01808
G1 F631.519
G1 X103.23 Y103.646 E.00126
G1 F600
G1 X101.166 Y101.582 E.08969
; WIPE_START
M204 S10000
G1 X101.539 Y101.123 E-.22477
G1 X101.568 Y101.152 E-.01558
G1 X102.535 Y102.119 E-.51965
; WIPE_END
G1 E-.04 F1800
G17
G3 Z3.8 I-.928 J.788 P1  F36000
G1 X132.239 Y137.11 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X138.81 Y139.035 E.12805
G1 X143.649 Y134.196 E.22698
G1 X146.649 Y137.2 E.14084
G1 X145.04 Y138.81 E.0755
G1 X155.473 Y149.242 E.48942
G1 X158.606 Y146.109 E.14697
G1 X159.875 Y147.379 E.05957
G1 X154.616 Y152.639 E.24674
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.379 Y159.875 E.24674
G1 X146.109 Y158.606 E.05957
G1 X149.242 Y155.473 E.14697
G1 X138.81 Y145.04 E.48942
G1 X137.2 Y146.649 E.07549
G1 X104.393 Y113.842 E1.53904
G1 X106.003 Y112.233 E.07549
G1 X96.421 Y102.652 E.44948
G1 X102.652 Y96.421 E.29228
G1 X103.234 Y97.003 E.0273
G1 X112.233 Y106.003 E.42217
G1 X113.843 Y104.393 E.0755
G1 X116.846 Y107.394 E.14084
G1 X112.008 Y112.233 E.22699
G1 X111.009 Y115.961 E.12805
G1 X113.868 Y118.821 E.13414
G1 X117.597 Y117.822 E.12805
G1 X122.435 Y112.983 E.22699
G1 X138.06 Y128.607 E.73296
G1 X133.221 Y133.446 E.22699
G1 X132.255 Y137.053 E.12386
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.649 Y133.642 E.21908
G1 X147.204 Y137.2 E.15456
G1 X145.594 Y138.81 E.06993
G1 X155.473 Y148.688 E.42926
G1 X158.606 Y145.555 E.13614
G1 X160.43 Y147.379 E.07928
G1 X155.17 Y152.639 E.22855
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.379 Y160.43 E.22855
G1 X145.555 Y158.606 E.07928
G1 X148.688 Y155.473 E.13614
G1 X138.81 Y145.594 E.42926
G1 X137.2 Y147.204 E.06993
G1 X103.839 Y113.842 E1.44971
G1 X105.448 Y112.233 E.06993
G1 X95.867 Y102.652 E.41635
G1 X102.652 Y95.867 E.29484
G1 X103.511 Y96.726 E.03734
G1 X112.233 Y105.448 E.37901
G1 X113.842 Y103.839 E.06993
G1 X117.401 Y107.394 E.15456
G1 X112.359 Y112.436 E.21908
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X122.436 Y112.429 E.21908
G1 X138.614 Y128.607 E.70304
G1 X133.573 Y133.649 E.21908
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X141.021 Y141.583 Z3.8 F36000
G1 X150.706 Y145.969 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.555 Y144.817 E.05401
G1 X144.817 Y149.555 E.22223
G1 X140.979 Y145.717 E.18005
G1 X145.717 Y140.979 E.22223
G1 X144.161 Y139.424 E.07296
G1 X144.161 Y139.083 E.01131
G1 X144.665 Y138.58 E.02361
G1 X144.777 Y138.58 E.00372
G1 X145.516 Y137.841 E.03469
G1 X143.007 Y135.331 E.11774
G1 X143.648 Y134.689 E.03011
G1 X143.99 Y135.031 E.01602
G1 X135.384 Y143.636 E.40371
G1 X137.552 Y145.805 E.10172
G1 X137.841 Y145.516 E.01352
G1 X105.526 Y113.202 E1.51593
G1 X106.266 Y112.463 E.03469
G1 X106.378 Y112.463 E.00372
G1 X106.881 Y111.959 E.02361
G1 X106.881 Y111.618 E.01131
G1 X106.438 Y111.175 E.0208
G1 X111.175 Y106.438 E.22223
G1 X111.618 Y106.881 E.0208
G1 X111.959 Y106.881 E.01131
G1 X112.463 Y106.378 E.02361
G1 X112.463 Y106.266 E.00372
G1 X113.202 Y105.526 E.03469
G1 X115.712 Y108.036 E.11774
G1 X114.561 Y109.187 E.05401
G1 X106.42 Y111.674 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.36736
G1 F3000;_EXTRUDE_SET_SPEED
G1 X106.51 Y111.782 E.00372
; Slow Down End
G1 F12000
G1 X106.305 Y112.018 E.00826
G1 X96.939 Y102.652 E.3502
G1 X97.159 Y102.431 E.00824
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X97.168 Y102.422 E.00033
; Slow Down End
G1 F12000
G1 X106.377 Y111.632 E.34432
; WIPE_START
G1 X104.963 Y110.218 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X104.992 Y113.842 Z3.8 F36000
G1 Z3.4
G1 E.8 F1800
; LINE_WIDTH: 0.48206
G1 F12000
G1 X137.158 Y146.008 E1.62782
; WIPE_START
G1 X135.744 Y144.594 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X141.874 Y149.141 Z3.8 F36000
G1 X149.659 Y154.914 Z3.8
G1 Z3.4
M73 P70 R5
G1 E.8 F1800
; Slow Down Start
; LINE_WIDTH: 0.36736
G1 F3000;_EXTRUDE_SET_SPEED
G1 X149.749 Y155.022 E.00371
; Slow Down End
G1 F12000
G1 X149.545 Y155.258 E.00826
G1 X139.024 Y144.738 E.39334
G1 X139.263 Y144.535 E.00827
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X139.273 Y144.527 E.00033
; Slow Down End
G1 F12000
G1 X149.617 Y154.871 E.38675
G1 X148.392 Y158.37 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X149.505 Y155.702 E.03469
G2 X149.745 Y155.575 I.056 J-.184 E.01001
G1 X150.121 Y155.199 E.01763
G1 X150.121 Y154.858 E.01131
G1 X148.655 Y153.393 E.06874
G1 X153.393 Y148.655 E.22223
G1 X154.858 Y150.121 E.06874
G1 X155.199 Y150.121 E.01131
G1 X155.702 Y149.617 E.02361
G1 X155.702 Y149.505 E.00372
G1 X156.442 Y148.766 E.03469
G1 X157.219 Y149.543 E.03647
G1 X154.123 Y152.639 E.14523
G1 X155.604 Y154.12 E.06947
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X139.169 Y139.169 E.76625
G1 X138.99 Y139.347 E.00837
G1 X137.661 Y139.703 E.04565
G1 X155.143 Y149.659 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.36736
G1 F12000
G1 X155.02 Y149.748 E.00401
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X155.009 Y149.755 E.00034
G1 X144.527 Y139.273 E.39192
G1 X144.535 Y139.263 E.00034
; Slow Down End
G1 F12000
G1 X144.738 Y139.024 E.00827
G1 X155.258 Y149.545 E.39334
G1 X155.186 Y149.617 E.0027
; WIPE_START
G1 X155.258 Y149.545 E-.03885
G1 X153.916 Y148.203 E-.72115
; WIPE_END
G1 E-.04 F1800
G1 X148.781 Y142.556 Z3.8 F36000
G1 X122.435 Y113.58 Z3.8
G1 Z3.4
G1 E.8 F1800
; LINE_WIDTH: 0.48042
G1 F12000
G1 X137.42 Y128.565 E.75548
; WIPE_START
G1 X136.006 Y127.151 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.989 Y122.454 Z3.8 F36000
G1 X104.771 Y102.769 Z3.8
G1 Z3.4
G1 E.8 F1800
; LINE_WIDTH: 0.399625
G1 F12000
G1 X102.041 Y100.026 E.11248
G1 X101.777 Y100.266 E.01038
G1 X104.532 Y103.021 E.11323
G1 X104.73 Y102.812 E.00837
G1 X102.895 Y104.658 F36000
; LINE_WIDTH: 0.39963
G1 F12000
G1 X103.021 Y104.532 E.00518
G1 X100.266 Y101.777 E.11324
G1 X100.026 Y102.041 E.01038
G1 X102.756 Y104.771 E.11222
G1 X102.848 Y104.696 E.00347
G1 X101.448 Y106.186 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X102.6 Y107.337 E.05401
G1 X107.337 Y102.6 E.22223
G1 X103.499 Y98.762 E.18005
G1 X102.408 Y99.853 E.05119
G2 X101.859 Y99.645 I-.379 J.17 E.02164
G1 X100.808 Y100.808 E.052
G1 X99.783 Y99.783 E.04808
G1 X97.414 Y102.151 E.11112
G1 X98.762 Y103.499 E.06321
G1 X99.853 Y102.408 E.05119
G1 X102.598 Y105.153 E.12879
G1 X102.939 Y105.153 E.01131
G1 X103.99 Y103.99 E.052
G1 X111.874 Y111.874 E.36984
G1 X111.696 Y112.052 E.00837
G1 X111.132 Y114.157 E.07228
G1 X108.518 Y116.77 E.12261
G1 X112.356 Y120.608 E.18005
G1 X113.76 Y119.205 E.06585
G1 X117.777 Y118.134 E.13792
G1 X117.955 Y117.956 E.00837
G1 X133.087 Y133.087 E.70986
G1 X132.909 Y133.266 E.00837
G1 X131.833 Y137.279 E.13782
G1 X132.95 Y138.395 E.05236
G1 X131.546 Y139.798 E.06585
G1 X127.708 Y135.96 E.18005
G1 X135.963 Y127.705 E.38727
G1 X137.216 Y128.958 E.05878
G1 X136.925 Y129.249 E.01366
G1 X121.793 Y114.118 E.70986
G1 X122.085 Y113.826 E.01366
G1 X124.449 Y116.191 E.11093
G1 X116.194 Y124.446 E.38727
G1 X120.032 Y128.284 E.18005
G1 X128.287 Y120.029 E.38727
G1 X132.125 Y123.867 E.18005
G1 X123.87 Y132.122 E.38727
G1 X122.719 Y130.971 E.05401
; WIPE_START
G1 X123.87 Y132.122 E-.61876
G1 X124.133 Y131.86 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X120.134 Y125.359 Z3.8 F36000
G1 X102.652 Y96.939 Z3.8
G1 Z3.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.367365
G1 F12000
G1 X112.018 Y106.305 E.3502
G3 X111.78 Y106.508 I-.732 J-.618 E.00831
; Slow Down Start
; LINE_WIDTH: 0.367365
G1 F3000;_EXTRUDE_SET_SPEED
G1 X111.77 Y106.516 E.00034
G1 X102.422 Y97.168 E.34949
G1 X102.431 Y97.159 E.00033
; Slow Down End
; LINE_WIDTH: 0.36736
G1 F12000
G1 X102.609 Y96.981 E.00666
; CHANGE_LAYER
; Z_HEIGHT: 3.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X102.431 Y97.159 E-.76
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
G1 X132.239 Y137.11
G1 Z3.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X138.81 Y139.035 E.12805
G1 X143.581 Y134.264 E.22381
G1 X146.585 Y137.265 E.14084
G1 X144.942 Y138.908 E.07708
G1 X155.375 Y149.34 E.48942
G1 X158.553 Y146.162 E.14912
G1 X159.823 Y147.432 E.05957
G1 X154.616 Y152.639 E.24428
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.432 Y159.823 E.24428
G1 X146.162 Y158.553 E.05957
G1 X149.34 Y155.375 E.14912
G1 X138.908 Y144.942 E.48942
G1 X137.264 Y146.585 E.07709
G1 X104.458 Y113.778 E1.53904
G1 X106.101 Y112.135 E.07709
G1 X96.52 Y102.554 E.44948
G1 X102.554 Y96.52 E.28307
G1 X105.325 Y99.291 E.13002
G1 X112.135 Y106.101 E.31946
G1 X113.778 Y104.458 E.07708
G1 X116.779 Y107.462 E.14084
G1 X112.008 Y112.233 E.22381
G1 X111.009 Y115.961 E.12805
G1 X113.868 Y118.821 E.13414
G1 X117.597 Y117.822 E.12805
G1 X122.368 Y113.051 E.22381
G1 X137.992 Y128.675 E.73296
G1 X133.221 Y133.446 E.22381
G1 X132.255 Y137.053 E.12386
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.581 Y133.71 E.21613
G1 X147.139 Y137.265 E.15456
G1 X145.496 Y138.908 E.0714
G1 X155.375 Y148.786 E.42926
G1 X158.553 Y145.607 E.13813
G1 X160.378 Y147.432 E.07928
G1 X155.17 Y152.639 E.22628
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.432 Y160.378 E.22628
G1 X145.607 Y158.553 E.07928
G1 X148.786 Y155.375 E.13813
G1 X138.908 Y145.496 E.42926
G1 X137.264 Y147.139 E.07141
G1 X103.903 Y113.778 E1.44971
G1 X105.546 Y112.135 E.07141
G1 X95.965 Y102.554 E.41635
G1 X102.554 Y95.965 E.2863
G1 X105.602 Y99.014 E.13248
G1 X112.135 Y105.546 E.28387
G1 X113.778 Y103.903 E.0714
G1 X117.333 Y107.462 E.15456
G1 X112.359 Y112.436 E.21613
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X122.368 Y112.496 E.21613
G1 X138.546 Y128.675 E.70304
G1 X133.573 Y133.649 E.21613
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X135.345 Y130.909 Z4 F36000
G1 X135.873 Y127.795 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X127.794 Y135.875 E.37904
G1 X132.036 Y123.957 F36000
G1 F15476.087
G1 X123.956 Y132.037 E.37904
G1 X128.198 Y120.119 F36000
G1 F15476.087
G1 X120.118 Y128.199 E.37904
G1 X112.442 Y120.523 F36000
G1 F15476.087
G1 X113.76 Y119.205 E.06182
G1 X117.777 Y118.134 E.13792
G1 X117.955 Y117.956 E.00837
G1 X133.087 Y133.087 E.70986
G1 X136.925 Y129.249 E.18005
G1 X121.793 Y114.118 E.70986
G1 X120.642 Y115.269 E.05401
G1 X122.368 Y113.67 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.51141
G1 F12000
G1 X137.33 Y128.633 E.80782
G1 X124.36 Y116.281 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X116.28 Y124.361 E.37904
G1 X108.604 Y116.685 F36000
G1 F15476.087
G1 X111.132 Y114.157 E.11858
G1 X111.696 Y112.052 E.07228
G1 X111.874 Y111.874 E.00837
G1 X104.046 Y104.046 E.36721
G1 X103.184 Y104.908 E.04044
G1 X102.843 Y104.908 E.01131
G1 X100.098 Y102.163 E.12879
G1 X98.903 Y103.358 E.05604
G1 X97.556 Y102.01 E.06321
G1 X99.783 Y99.783 E.10448
G1 X100.752 Y100.752 E.04545
G1 X101.614 Y99.89 E.04044
G3 X102.163 Y100.098 I.17 J.379 E.02164
G1 X103.358 Y98.903 E.05604
G1 X107.196 Y102.741 E.18005
G1 X102.741 Y107.196 E.20897
G1 X101.59 Y106.044 E.05401
G1 X102.89 Y104.641 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.42949
G1 F3000
G1 X104.516 Y103.006 E.07264
G1 X104.248 Y102.737 E.01196
G1 X102.737 Y104.247 E.06729
G1 X102.464 Y103.974 E.01218
G1 X103.974 Y102.464 E.06729
G1 X103.701 Y102.191 E.01218
G1 X102.19 Y103.701 E.06729
G1 X101.917 Y103.427 E.01218
G1 X103.428 Y101.917 E.06729
G1 X103.154 Y101.644 E.01218
G1 X101.644 Y103.154 E.06729
G1 X101.37 Y102.881 E.01218
G1 X102.881 Y101.37 E.06729
G1 X102.608 Y101.097 E.01218
G1 X101.097 Y102.607 E.06729
G1 X100.824 Y102.334 E.01218
G1 X102.334 Y100.824 E.06729
G1 X102.061 Y100.55 E.01218
G1 X100.55 Y102.061 E.06729
G1 X100.282 Y101.792 E.01196
G1 X101.908 Y100.157 E.07264
G1 X102.319 Y97.293 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.39789
G1 F12000
G1 X102.554 Y97.058 E.00962
G1 X111.898 Y106.403 E.38227
G3 X111.652 Y106.627 I-1.236 J-1.11 E.00964
; Slow Down Start
M73 P71 R5
G1 F3000;_EXTRUDE_SET_SPEED
G1 X111.635 Y106.642 E.00065
G1 X102.329 Y97.336 E.38067
; Slow Down End
G1 X106.642 Y111.647 F36000
; LINE_WIDTH: 0.397895
G1 F12000
G1 X106.403 Y111.898 E.01001
G1 X97.058 Y102.554 E.38227
G1 X97.293 Y102.319 E.00962
; Slow Down Start
; LINE_WIDTH: 0.397895
G1 F3000;_EXTRUDE_SET_SPEED
G1 X97.309 Y102.303 E.00065
G1 X106.601 Y111.603 E.38028
; Slow Down End
G1 X105.077 Y113.778 F36000
; LINE_WIDTH: 0.51237
G1 F12000
G1 X137.222 Y145.923 E1.73901
; WIPE_START
G1 X135.808 Y144.509 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X143.428 Y144.08 Z4 F36000
G1 X148.262 Y143.807 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.413 Y144.959 E.05401
G1 X144.959 Y149.413 E.20896
G1 X143.807 Y148.262 E.05401
G1 X149.768 Y154.762 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.397895
G1 F12000
G1 X149.881 Y154.887 E.00488
G1 X149.643 Y155.138 E.01001
G1 X139.144 Y144.639 E.42947
G1 X139.391 Y144.416 E.00963
; Slow Down Start
; LINE_WIDTH: 0.397895
G1 F3000;_EXTRUDE_SET_SPEED
G1 X139.408 Y144.401 E.00065
G1 X149.726 Y154.719 E.42208
; Slow Down End
G1 X148.392 Y158.37 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X149.603 Y155.604 E.0393
G1 X149.716 Y155.604 E.00372
G1 X150.262 Y155.057 E.02564
G1 X150.262 Y154.717 E.01131
G1 X148.797 Y153.251 E.06874
G1 X153.251 Y148.797 E.20896
G1 X154.717 Y150.262 E.06874
G1 X155.057 Y150.262 E.01131
G1 X155.604 Y149.716 E.02564
G1 X155.604 Y149.603 E.00372
G1 X156.442 Y148.766 E.0393
G1 X157.219 Y149.543 E.03647
G1 X154.123 Y152.639 E.14523
G1 X155.604 Y154.12 E.06947
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X139.169 Y139.169 E.76625
G1 X138.99 Y139.347 E.00837
G1 X134.977 Y140.422 E.13782
G1 X132.95 Y138.395 E.09512
G1 X131.632 Y139.713 E.06182
G1 X155.013 Y149.768 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.3979
G1 F12000
G1 X154.892 Y149.867 E.00451
; Slow Down Start
; LINE_WIDTH: 0.397895
G1 F3000;_EXTRUDE_SET_SPEED
G1 X154.874 Y149.881 E.00065
G1 X144.401 Y139.408 E.42844
G1 X144.416 Y139.391 E.00065
; Slow Down End
; LINE_WIDTH: 0.397895
G1 F12000
G1 X144.639 Y139.144 E.00963
G1 X155.138 Y149.643 E.42947
G1 X155.055 Y149.726 E.0034
; WIPE_START
G1 X155.138 Y149.643 E-.04465
G1 X153.807 Y148.312 E-.71536
; WIPE_END
G1 E-.04 F1800
G1 X148.402 Y142.923 Z4 F36000
G1 X114.561 Y109.187 Z4
G1 Z3.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X115.712 Y108.036 E.05401
G1 X113.202 Y105.526 E.11774
G1 X112.364 Y106.364 E.0393
G1 X112.364 Y106.476 E.00372
G1 X111.818 Y107.023 E.02564
G1 X111.477 Y107.023 E.01131
G1 X111.034 Y106.579 E.0208
G1 X106.579 Y111.034 E.20896
G1 X107.023 Y111.477 E.0208
G1 X107.023 Y111.818 E.01131
G1 X106.476 Y112.364 E.02564
G1 X106.364 Y112.364 E.00372
G1 X105.526 Y113.202 E.0393
G1 X137.841 Y145.516 E1.51593
G1 X138.678 Y144.679 E.0393
G1 X138.678 Y144.567 E.00372
G1 X139.225 Y144.02 E.02564
G1 X139.566 Y144.02 E.01131
G1 X141.121 Y145.575 E.07296
G1 X145.575 Y141.121 E.20897
G1 X144.02 Y139.566 E.07296
G1 X144.02 Y139.225 E.01131
G1 X144.567 Y138.678 E.02564
G1 X144.679 Y138.678 E.00372
G1 X145.516 Y137.841 E.0393
G1 X143.007 Y135.331 E.11774
G1 X143.581 Y134.756 E.02695
G1 X143.923 Y135.098 E.01602
G1 X135.47 Y143.551 E.39655
; CHANGE_LAYER
; Z_HEIGHT: 3.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X136.884 Y142.136 E-.76
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
G1 X132.239 Y137.11
G1 Z3.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X138.81 Y139.035 E.12805
G1 X143.511 Y134.334 E.22055
G1 X146.512 Y137.338 E.14084
G1 X144.837 Y139.012 E.07854
G1 X155.27 Y149.445 E.48942
G1 X158.498 Y146.217 E.15143
G1 X159.768 Y147.487 E.05957
G1 X154.616 Y152.639 E.2417
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.487 Y159.768 E.2417
G1 X146.217 Y158.498 E.05957
G1 X149.445 Y155.27 E.15143
G1 X139.012 Y144.837 E.48942
G1 X137.338 Y146.511 E.07852
G1 X104.531 Y113.704 E1.53904
G1 X106.205 Y112.031 E.07852
G1 X96.624 Y102.449 E.44948
G1 X102.449 Y96.624 E.27328
G1 X107.357 Y101.532 E.23025
G1 X112.031 Y106.205 E.21923
G1 X113.705 Y104.531 E.07854
G1 X116.709 Y107.531 E.14084
G1 X112.008 Y112.233 E.22055
G1 X111.009 Y115.961 E.12805
G1 X113.868 Y118.821 E.13414
G1 X117.597 Y117.822 E.12805
G1 X122.298 Y113.12 E.22055
G1 X137.923 Y128.744 E.73296
G1 X133.221 Y133.446 E.22056
G1 X132.255 Y137.053 E.12386
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.512 Y133.779 E.21312
G1 X147.066 Y137.338 E.15456
G1 X145.392 Y139.012 E.07274
G1 X155.27 Y148.89 E.42926
G1 X158.498 Y145.662 E.14027
G1 X160.322 Y147.487 E.07928
G1 X155.17 Y152.639 E.22389
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.487 Y160.322 E.22389
G1 X145.662 Y158.498 E.07928
G1 X148.89 Y155.27 E.14027
G1 X139.012 Y145.392 E.42926
G1 X137.338 Y147.066 E.07274
G1 X107.218 Y116.945 E1.30887
G1 X103.977 Y113.704 E.14084
G1 X105.651 Y112.031 E.07273
G1 X96.069 Y102.449 E.41635
G1 X102.449 Y96.069 E.27723
G1 X107.635 Y101.255 E.22533
G1 X112.031 Y105.651 E.19102
G1 X113.704 Y103.977 E.07274
G1 X117.264 Y107.531 E.15456
G1 X112.359 Y112.436 E.21313
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X122.298 Y112.566 E.21313
G1 X138.477 Y128.744 E.70304
G1 X133.573 Y133.649 E.21313
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.726 Y139.618 Z4.2 F36000
G1 Z3.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.95 Y138.395 E.05739
G1 X134.977 Y140.422 E.09512
G1 X138.99 Y139.347 E.13782
G1 X139.169 Y139.169 E.00837
G1 X155.502 Y155.502 E.76625
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X155.5 Y149.708 E.04419
G1 X155.5 Y149.82 E.00372
G1 X155.087 Y150.233 E.01936
G3 X154.563 Y150.415 I-.353 J-.17 E.02043
G1 X153.098 Y148.95 E.06874
G1 X148.95 Y153.098 E.1946
G1 X150.415 Y154.563 E.06874
G1 X150.415 Y154.904 E.01131
G1 X149.82 Y155.5 E.02793
G1 X149.708 Y155.5 E.00372
G1 X148.766 Y156.442 E.04419
G1 X149.543 Y157.219 E.03647
G1 X148.392 Y158.37 E.05401
G1 X150.017 Y154.734 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.43238
G1 F12000
G1 X149.747 Y155.009 E.01224
G1 X139.273 Y144.535 E.4701
G1 X139.538 Y144.28 E.01167
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X139.554 Y144.265 E.00069
G1 X149.976 Y154.691 E.46783
; Slow Down End
G1 X146.263 Y150.412 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X145.112 Y149.26 E.05401
G1 X149.26 Y145.112 E.1946
G1 X150.412 Y146.263 E.05401
G1 X154.872 Y149.885 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.43238
G1 F12000
G1 X154.744 Y150.002 E.00549
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X154.728 Y150.017 E.00069
G1 X144.269 Y139.558 E.46943
G1 X144.284 Y139.542 E.00069
; Slow Down End
G1 F12000
G1 X144.535 Y139.273 E.01167
G1 X155.009 Y149.747 E.4701
G1 X154.914 Y149.842 E.00428
G1 X135.564 Y143.456 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X143.852 Y135.168 E.38882
G1 X143.511 Y134.826 E.01602
G1 X143.007 Y135.331 E.02367
G1 X145.516 Y137.841 E.11774
G1 X144.574 Y138.783 E.04419
G1 X144.462 Y138.783 E.00372
G1 X143.867 Y139.378 E.02793
G1 X143.867 Y139.719 E.01131
G1 X145.422 Y141.274 E.07296
G1 X141.274 Y145.422 E.1946
G1 X139.719 Y143.867 E.07296
G1 X139.378 Y143.867 E.01131
G1 X138.783 Y144.462 E.02793
G1 X138.783 Y144.574 E.00372
G1 X137.841 Y145.516 E.04419
G1 X105.526 Y113.202 E1.51593
G1 X106.468 Y112.26 E.04419
G1 X106.58 Y112.26 E.00372
G1 X107.176 Y111.665 E.02793
G1 X107.176 Y111.324 E.01131
G1 X106.732 Y110.88 E.0208
G1 X110.88 Y106.732 E.1946
G1 X111.324 Y107.176 E.0208
G1 X111.665 Y107.176 E.01131
G1 X112.26 Y106.58 E.02793
G1 X112.26 Y106.468 E.00372
G1 X113.202 Y105.526 E.04419
G1 X115.712 Y108.036 E.11774
G1 X114.561 Y109.187 E.05401
G1 X106.777 Y111.494 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.43238
G1 F12000
G1 X106.508 Y111.77 E.01224
G1 X97.187 Y102.449 E.41832
G1 X97.447 Y102.189 E.01167
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X97.463 Y102.174 E.00069
G1 X106.736 Y111.451 E.41629
; Slow Down End
G1 X105.172 Y113.704 F36000
; LINE_WIDTH: 0.54178
G1 F12000
G1 X137.296 Y145.828 E1.84676
G1 X127.888 Y135.78 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
M73 P72 R5
G1 X135.783 Y127.885 E.37037
G1 X124.05 Y131.942 F36000
G1 F15476.087
G1 X131.945 Y124.047 E.37037
G1 X120.212 Y128.104 F36000
G1 F15476.087
G1 X128.107 Y120.209 E.37037
G1 X122.298 Y113.76 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54114
G1 F12000
G1 X137.24 Y128.702 E.85787
G1 X116.374 Y124.266 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X124.269 Y116.371 E.37037
G1 X120.642 Y115.269 F36000
G1 F15476.087
G1 X121.793 Y114.118 E.05401
G1 X136.925 Y129.249 E.70986
G1 X133.087 Y133.087 E.18005
G1 X117.955 Y117.956 E.70986
G1 X117.777 Y118.134 E.00837
G1 X113.76 Y119.205 E.13792
G1 X112.536 Y120.428 E.05739
; WIPE_START
G1 X113.76 Y119.205 E-.65744
G1 X114.02 Y119.135 E-.10256
; WIPE_END
G1 E-.04 F1800
G1 X111.271 Y112.015 Z4.2 F36000
G1 X108.194 Y104.046 Z4.2
G1 Z3.8
G1 E.8 F1800
G1 F15476.087
G1 X107.042 Y102.894 E.05401
G1 X102.894 Y107.042 E.1946
G1 X99.056 Y103.204 E.18005
G1 X100.343 Y101.918 E.06035
G3 X100.134 Y101.369 I.17 J-.379 E.02164
G1 X100.752 Y100.752 E.02895
G1 X99.783 Y99.783 E.04545
G1 X101.857 Y97.709 E.0973
G1 X103.204 Y99.056 E.06321
G1 X101.918 Y100.343 E.06035
G1 X104.663 Y103.088 E.12879
G1 X104.663 Y103.429 E.01131
G1 X104.046 Y104.046 E.02895
G1 X111.874 Y111.874 E.36721
G1 X111.696 Y112.052 E.00837
G1 X111.132 Y114.157 E.07228
G1 X108.698 Y116.59 E.11415
G1 X104.271 Y103.259 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G2 X101.547 Y100.526 I-172.123 J168.89 E.11855
G2 X100.526 Y101.531 I31.107 J32.63 E.04401
G2 X103.25 Y104.271 I87.663 J-84.42 E.11873
G2 X104.235 Y103.303 I-30.031 J-31.519 E.04242
G1 X103.746 Y103.259 F36000
G1 F12000
G1 X101.539 Y101.052 E.0959
G1 X101.052 Y101.539 E.02119
G1 X103.259 Y103.746 E.0959
G1 X103.704 Y103.301 E.01935
G1 X101.539 Y101.539 F36000
; LINE_WIDTH: 0.35548
G1 F12000
G1 X103.216 Y103.216 E.0604
G1 X102.189 Y97.447 F36000
; LINE_WIDTH: 0.43238
G1 F12000
G1 X102.449 Y97.187 E.01167
G1 X111.77 Y106.508 E.41832
G3 X111.505 Y106.763 I-3.31 J-3.172 E.01167
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X111.489 Y106.777 E.00069
G1 X102.201 Y97.49 E.41686
; Slow Down End
; CHANGE_LAYER
; Z_HEIGHT: 4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X103.615 Y98.904 E-.76
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
G1 X132.239 Y137.11
G1 Z4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X138.81 Y139.035 E.12805
G1 X143.433 Y134.412 E.21688
G1 X146.437 Y137.412 E.14084
G1 X144.719 Y139.13 E.08059
G1 X155.152 Y149.563 E.48942
G1 X158.443 Y146.272 E.15437
G1 X159.713 Y147.542 E.05957
G1 X154.616 Y152.639 E.2391
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.542 Y159.713 E.2391
G1 X146.272 Y158.443 E.05957
G1 X149.563 Y155.152 E.15438
G1 X139.13 Y144.719 E.48942
G1 X137.412 Y146.437 E.0806
G1 X104.605 Y113.631 E1.53904
G1 X106.323 Y111.912 E.0806
G1 X96.742 Y102.331 E.44948
G1 X102.331 Y96.742 E.26219
G1 X104.455 Y98.866 E.09966
G1 X111.912 Y106.323 E.34982
G1 X113.63 Y104.605 E.08059
G1 X116.631 Y107.609 E.14084
G1 X112.008 Y112.233 E.21688
G1 X111.009 Y115.961 E.12805
G1 X113.868 Y118.821 E.13414
G1 X117.597 Y117.822 E.12805
G1 X122.22 Y113.198 E.21688
G1 X137.844 Y128.823 E.73296
G1 X133.221 Y133.446 E.21688
G1 X132.255 Y137.053 E.12386
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.433 Y133.857 E.20971
G1 X146.992 Y137.412 E.15456
G1 X145.274 Y139.13 E.07466
G1 X155.152 Y149.009 E.42926
G1 X158.443 Y145.718 E.143
G1 X160.267 Y147.542 E.07928
G1 X155.17 Y152.639 E.22148
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.542 Y160.267 E.22148
G1 X145.718 Y158.443 E.07928
G1 X149.009 Y155.152 E.143
G1 X139.13 Y145.274 E.42926
G1 X137.412 Y146.992 E.07466
G1 X104.051 Y113.631 E1.44971
G1 X105.769 Y111.912 E.07466
G1 X96.188 Y102.331 E.41635
G1 X102.331 Y96.188 E.26697
G1 X104.733 Y98.589 E.10436
G1 X111.912 Y105.769 E.31199
G1 X113.631 Y104.051 E.07466
G1 X117.185 Y107.61 E.15456
G1 X112.359 Y112.436 E.20971
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X122.22 Y112.644 E.20971
G1 X138.398 Y128.823 E.70304
G1 X133.573 Y133.649 E.20971
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X132.834 Y133.197 Z4.4 F36000
G1 Z4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54302
G1 F12000
G1 X132.937 Y133.092 E.00599
G1 X132.834 Y133.197 F36000
; Slow Down Start
; LINE_WIDTH: 0.522515
G1 F3000;_EXTRUDE_SET_SPEED
G1 X132.826 Y133.224 E.00112
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.481505
;_EXTRUDE_SET_SPEED
G1 X132.818 Y133.252 E.00102
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.467077
;_EXTRUDE_SET_SPEED
G1 X132.369 Y135.112 E.06614
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.41999
;_EXTRUDE_SET_SPEED
G1 X132.108 Y136.086 E.031
G3 X130.991 Y134.953 I28.255 J-28.969 E.04889
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.443735
;_EXTRUDE_SET_SPEED
G1 X131.192 Y134.751 E.00932
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.491225
;_EXTRUDE_SET_SPEED
G1 X131.394 Y134.549 E.01043
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.440495
;_EXTRUDE_SET_SPEED
G1 X131.85 Y134.116 E.02036
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.481505
;_EXTRUDE_SET_SPEED
G1 X132.305 Y133.683 E.02246
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.522819
;_EXTRUDE_SET_SPEED
G1 X132.785 Y133.232 E.02577
; Slow Down End
G1 X132.187 Y134.302 F36000
; Slow Down Start
; LINE_WIDTH: 0.43677
G1 F3000;_EXTRUDE_SET_SPEED
G1 X131.908 Y135.342 E.03453
G1 X131.528 Y134.961 E.01727
G1 X132.144 Y134.345 E.02798
; Slow Down End
G1 X135.682 Y127.986 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X127.987 Y135.681 E.36101
G1 X135.663 Y143.357 F36000
G1 F15476.087
G1 X137.363 Y141.657 E.07976
G1 X137.124 Y141.657 E.00792
G1 X135.697 Y140.23 E.06697
G1 X134.977 Y140.422 E.02471
G1 X132.95 Y138.395 E.09512
G1 X131.825 Y139.519 E.05276
; WIPE_START
G1 X132.95 Y138.395 E-.60443
G1 X133.239 Y138.684 E-.15557
; WIPE_END
G1 E-.04 F1800
G1 X139.091 Y139.393 Z4.4 F36000
G1 Z4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.5392
G1 F12000
G1 X139.164 Y139.319 E.00419
G1 X139.091 Y139.393 F36000
; Slow Down Start
; LINE_WIDTH: 0.519332
G1 F3000;_EXTRUDE_SET_SPEED
G1 X139.064 Y139.429 E.00174
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.479595
;_EXTRUDE_SET_SPEED
G1 X139.038 Y139.465 E.0016
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.459142
;_EXTRUDE_SET_SPEED
G1 X137.706 Y140.862 E.06544
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.41999
;_EXTRUDE_SET_SPEED
G1 X137.287 Y141.265 E.0179
G1 X136.17 Y140.148 E.04854
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.439795
;_EXTRUDE_SET_SPEED
G1 X136.657 Y140.018 E.01631
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.479405
;_EXTRUDE_SET_SPEED
G1 X137.144 Y139.887 E.01794
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.439859
;_EXTRUDE_SET_SPEED
G1 X137.754 Y139.737 E.02032
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.479595
;_EXTRUDE_SET_SPEED
G1 X138.364 Y139.588 E.02236
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.51932
;_EXTRUDE_SET_SPEED
G1 X139.035 Y139.414 E.02689
; Slow Down End
G1 X137.954 Y140.069 F36000
; Slow Down Start
; LINE_WIDTH: 0.43676
G1 F3000;_EXTRUDE_SET_SPEED
G1 X137.295 Y140.728 E.0299
G1 X136.914 Y140.348 E.01727
G1 X137.896 Y140.085 E.03261
; Slow Down End
G1 X147.943 Y144.126 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.095 Y145.278 E.05401
G1 X145.278 Y149.095 E.17907
G1 X144.126 Y147.943 E.05401
G1 X150.164 Y154.568 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.465905
G1 F12000
G1 X149.865 Y154.867 E.01458
G1 X139.415 Y144.417 E.50942
G1 X139.698 Y144.134 E.0138
; Slow Down Start
; LINE_WIDTH: 0.465905
G1 F3000;_EXTRUDE_SET_SPEED
G1 X139.714 Y144.118 E.00078
G1 X150.122 Y154.526 E.50735
; Slow Down End
G1 X154.718 Y150.015 F36000
; LINE_WIDTH: 0.4659
G1 F12000
G1 X154.584 Y150.148 E.00651
; Slow Down Start
; LINE_WIDTH: 0.465905
G1 F3000;_EXTRUDE_SET_SPEED
G1 X154.568 Y150.164 E.00078
G1 X144.118 Y139.714 E.50941
G1 X144.134 Y139.698 E.00078
; Slow Down End
; LINE_WIDTH: 0.465905
G1 F12000
G1 X144.417 Y139.415 E.0138
G1 X154.867 Y149.865 E.50941
G1 X154.76 Y149.973 E.00522
; WIPE_START
G1 X154.867 Y149.865 E-.05757
G1 X153.56 Y148.558 E-.70243
; WIPE_END
G1 E-.04 F1800
G1 X148.487 Y142.856 Z4.4 F36000
G1 X131.844 Y124.148 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X124.149 Y131.844 E.36101
G1 X128.006 Y120.31 F36000
G1 F15476.087
G1 X120.311 Y128.006 E.361
G1 X117.878 Y118.18 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.5392
G1 F12000
G1 X117.951 Y118.106 E.00419
G1 X117.878 Y118.18 F36000
; Slow Down Start
; LINE_WIDTH: 0.519332
G1 F3000;_EXTRUDE_SET_SPEED
G1 X117.851 Y118.216 E.00174
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.479595
;_EXTRUDE_SET_SPEED
G1 X117.824 Y118.252 E.0016
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.459142
;_EXTRUDE_SET_SPEED
G1 X116.493 Y119.648 E.06544
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.41999
;_EXTRUDE_SET_SPEED
G1 X116.073 Y120.052 E.0179
G1 X114.956 Y118.935 E.04854
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.439795
;_EXTRUDE_SET_SPEED
G1 X115.444 Y118.805 E.01631
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.479405
;_EXTRUDE_SET_SPEED
G1 X115.931 Y118.674 E.01794
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.439859
;_EXTRUDE_SET_SPEED
G1 X116.541 Y118.524 E.02032
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.479595
;_EXTRUDE_SET_SPEED
G1 X117.151 Y118.374 E.02236
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.51932
;_EXTRUDE_SET_SPEED
G1 X117.822 Y118.201 E.02689
; Slow Down End
G1 X116.74 Y118.856 F36000
; Slow Down Start
; LINE_WIDTH: 0.43679
G1 F3000;_EXTRUDE_SET_SPEED
G1 X116.081 Y119.515 E.02991
G1 X115.701 Y119.135 E.01727
G1 X116.682 Y118.872 E.03261
; Slow Down End
G1 X120.642 Y115.269 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X121.793 Y114.118 E.05401
G1 X136.925 Y129.249 E.70986
G1 X133.407 Y132.768 E.16505
G2 X132.695 Y132.695 I-.391 J.309 E.02648
G1 X118.348 Y118.348 E.67303
G1 X116.252 Y120.444 E.09833
G1 X115.911 Y120.444 E.01131
G1 X114.483 Y119.016 E.06697
G1 X113.76 Y119.205 E.02481
G1 X112.635 Y120.33 E.05276
; WIPE_START
G1 X113.76 Y119.205 E-.60443
G1 X114.156 Y119.102 E-.15557
; WIPE_END
G1 E-.04 F1800
G1 X111.621 Y111.984 Z4.4 F36000
G1 Z4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54296
G1 F12000
G1 X111.724 Y111.879 E.00599
G1 X110.181 Y114.16 F36000
; Slow Down Start
; LINE_WIDTH: 0.41999
G1 F3000;_EXTRUDE_SET_SPEED
G1 X109.777 Y113.74 E.0179
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.443723
;_EXTRUDE_SET_SPEED
G1 X109.979 Y113.538 E.00932
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.491188
;_EXTRUDE_SET_SPEED
G1 X110.181 Y113.336 E.01043
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.440485
;_EXTRUDE_SET_SPEED
G1 X110.636 Y112.903 E.02036
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.481475
;_EXTRUDE_SET_SPEED
G1 X111.092 Y112.47 E.02246
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.523283
;_EXTRUDE_SET_SPEED
G1 X111.621 Y111.984 E.02813
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.522465
;_EXTRUDE_SET_SPEED
G1 X111.613 Y112.011 E.00112
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.481475
;_EXTRUDE_SET_SPEED
G1 X111.605 Y112.039 E.00102
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.467053
;_EXTRUDE_SET_SPEED
G1 X111.155 Y113.899 E.06614
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.41999
;_EXTRUDE_SET_SPEED
M73 P72 R4
G1 X110.894 Y114.873 E.031
G1 X110.224 Y114.202 E.02915
; Slow Down End
G1 X110.973 Y113.089 F36000
; Slow Down Start
; LINE_WIDTH: 0.43677
G1 F3000;_EXTRUDE_SET_SPEED
G1 X110.695 Y114.128 E.03453
G1 X110.314 Y113.748 E.01727
G1 X110.931 Y113.132 E.02798
; Slow Down End
G1 X106.925 Y111.329 F36000
; LINE_WIDTH: 0.46591
G1 F12000
G1 X106.626 Y111.628 E.01458
G1 X97.329 Y102.331 E.45318
G1 X97.612 Y102.048 E.0138
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X97.628 Y102.032 E.00078
G1 X106.882 Y111.286 E.45111
; Slow Down End
G1 X105.271 Y113.631 F36000
; LINE_WIDTH: 0.57695
M73 P73 R4
G1 F11797.091
G1 X137.37 Y145.73 E1.97543
; WIPE_START
G1 X135.955 Y144.315 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X132.98 Y137.287 Z4.4 F36000
G1 X124.168 Y116.472 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X116.473 Y124.168 E.36099
G1 X122.22 Y113.862 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.57336
G1 F11876.933
G1 X137.139 Y128.78 E.91196
; WIPE_START
G1 X135.725 Y127.366 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X129.935 Y122.393 Z4.4 F36000
G1 X114.561 Y109.187 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X115.712 Y108.036 E.05401
G1 X113.202 Y105.526 E.11774
G1 X112.142 Y106.586 E.04974
G1 X112.142 Y106.699 E.00372
G1 X111.499 Y107.341 E.03015
G1 X111.158 Y107.341 E.01131
G1 X110.715 Y106.898 E.0208
G1 X106.898 Y110.715 E.17907
G1 X107.341 Y111.158 E.0208
G1 X107.341 Y111.499 E.01131
G1 X106.698 Y112.142 E.03015
G1 X106.586 Y112.142 E.00372
G1 X105.526 Y113.202 E.04974
G1 X137.841 Y145.516 E1.51593
G1 X138.901 Y144.456 E.04974
G1 X138.901 Y144.344 E.00372
G1 X139.543 Y143.701 E.03015
G1 X139.884 Y143.701 E.01131
G1 X141.44 Y145.257 E.07296
G1 X145.257 Y141.44 E.17907
G1 X143.701 Y139.884 E.07296
G1 X143.701 Y139.543 E.01131
G1 X144.191 Y139.054 E.02297
G2 X145.516 Y137.841 I-4.058 J-5.763 E.05977
G1 X143.007 Y135.331 E.11774
G1 X143.433 Y134.904 E.02002
G1 X143.775 Y135.245 E.01602
G1 X139.667 Y139.354 E.19273
G3 X139.561 Y139.561 I-.188 J.035 E.0083
G1 X155.502 Y155.502 E.74784
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X155.382 Y149.826 E.04974
G1 X155.382 Y149.938 E.00372
G1 X154.934 Y150.386 E.021
G3 X154.398 Y150.581 I-.366 J-.17 E.02102
G1 X152.933 Y149.116 E.06874
G1 X149.115 Y152.933 E.17907
G1 X150.581 Y154.398 E.06874
G3 X150.386 Y154.934 I-.366 J.17 E.02102
G1 X149.938 Y155.382 E.021
G1 X149.826 Y155.382 E.00372
G1 X148.766 Y156.442 E.04974
G1 X149.543 Y157.219 E.03647
G1 X148.392 Y158.37 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X144.688 Y150.86 Z4.4 F36000
G1 X111.478 Y106.775 Z4.4
G1 Z4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.46591
G1 F12000
G1 X111.345 Y106.909 E.00651
; Slow Down Start
; LINE_WIDTH: 0.465905
G1 F3000;_EXTRUDE_SET_SPEED
G1 X111.329 Y106.925 E.00079
G1 X102.032 Y97.628 E.45317
G1 X102.048 Y97.612 E.00078
; Slow Down End
G1 F12000
G1 X102.331 Y97.329 E.0138
G1 X111.628 Y106.626 E.45317
G1 X111.521 Y106.733 E.00522
G1 X101.908 Y105.726 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X103.06 Y106.877 E.05401
G1 X106.877 Y103.06 E.17907
G1 X103.039 Y99.222 E.18005
G1 X99.222 Y103.039 E.17907
G1 X97.874 Y101.691 E.06321
G1 X99.783 Y99.783 E.08953
G1 X111.481 Y111.482 E.54881
G1 X109.385 Y113.578 E.09833
G1 X109.385 Y113.918 E.01131
G1 X110.378 Y114.911 E.04655
G1 X108.797 Y116.492 E.07416
; CHANGE_LAYER
; Z_HEIGHT: 4.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X110.211 Y115.077 E-.76
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
G1 X132.239 Y137.11
G1 Z4.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X138.81 Y139.035 E.12805
G1 X143.354 Y134.491 E.21316
G1 X146.354 Y137.496 E.14084
G1 X144.596 Y139.254 E.08247
G1 X155.028 Y149.687 E.48942
G1 X158.378 Y146.337 E.15714
G1 X159.648 Y147.607 E.05957
G1 X154.616 Y152.639 E.23607
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.607 Y159.648 E.23607
G1 X146.337 Y158.378 E.05957
G1 X149.687 Y155.028 E.15714
G1 X139.254 Y144.596 E.48942
G1 X137.496 Y146.353 E.08245
G1 X104.689 Y113.546 E1.53904
G1 X106.447 Y111.789 E.08245
G1 X96.866 Y102.208 E.44948
G1 X102.208 Y96.866 E.2506
G1 X106.286 Y100.944 E.19134
G1 X111.789 Y106.447 E.25814
G1 X113.547 Y104.689 E.08247
G1 X116.552 Y107.689 E.14084
G1 X112.008 Y112.233 E.21316
G1 X111.009 Y115.961 E.12805
G1 X113.868 Y118.821 E.13414
G1 X117.597 Y117.822 E.12805
G1 X122.141 Y113.278 E.21316
G1 X137.765 Y128.902 E.73296
G1 X133.221 Y133.446 E.21316
G1 X132.255 Y137.053 E.12386
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.354 Y133.936 E.20628
G1 X146.908 Y137.496 E.15456
G1 X145.15 Y139.254 E.07638
G1 X155.028 Y149.132 E.42926
G1 X158.378 Y145.782 E.14556
G1 X160.202 Y147.607 E.07928
G1 X155.17 Y152.639 E.21867
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.607 Y160.203 E.21867
G1 X145.782 Y158.378 E.07928
G1 X149.132 Y155.028 E.14556
G1 X139.254 Y145.15 E.42926
G1 X137.496 Y146.908 E.07637
G1 X124.181 Y133.593 E.57859
G1 X104.135 Y113.546 E.87112
G1 X105.892 Y111.789 E.07637
G1 X96.311 Y102.208 E.41635
G1 X102.208 Y96.311 E.25623
G1 X106.563 Y100.667 E.18928
G1 X111.789 Y105.893 E.22707
G1 X113.547 Y104.135 E.07638
G1 X117.106 Y107.689 E.15456
G1 X112.359 Y112.436 E.20628
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X122.141 Y112.723 E.20628
G1 X138.319 Y128.902 E.70304
G1 X133.573 Y133.649 E.20628
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X132.834 Y133.197 Z4.6 F36000
G1 Z4.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54111
G1 F12000
G1 X132.937 Y133.092 E.00597
G1 X132.834 Y133.197 F36000
; LINE_WIDTH: 0.528995
G1 F12000
G1 X132.76 Y133.25 E.0036
; LINE_WIDTH: 0.491225
G1 X132.077 Y133.9 E.03443
; LINE_WIDTH: 0.425431
G2 X130.991 Y134.953 I20.353 J22.09 E.04718
G2 X132.108 Y136.086 I29.372 J-27.836 E.0496
G1 X132.369 Y135.112 E.03144
; LINE_WIDTH: 0.443735
G1 X132.59 Y134.196 E.03078
; LINE_WIDTH: 0.491225
G1 X132.811 Y133.279 E.03443
; LINE_WIDTH: 0.528995
G1 X132.818 Y133.255 E.00102
G1 X132.187 Y134.302 F36000
; LINE_WIDTH: 0.43677
G1 F12000
G1 X131.528 Y134.961 E.02991
G1 X131.908 Y135.342 E.01727
G1 X132.171 Y134.36 E.03261
; WIPE_START
G1 X131.908 Y135.342 E-.3861
G1 X131.528 Y134.961 E-.20445
G1 X131.843 Y134.646 E-.16945
; WIPE_END
G1 E-.04 F1800
G1 X136.142 Y140.675 Z4.6 F36000
G1 Z4.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X137.124 Y141.657 E.04609
G1 X137.363 Y141.657 E.00792
G1 X135.77 Y143.251 E.07475
G1 X131.932 Y139.413 E.18005
G1 X132.95 Y138.395 E.04775
G1 X131.833 Y137.279 E.05236
G1 X131.846 Y137.23 E.00166
; WIPE_START
G1 X131.833 Y137.279 E-.01896
G1 X132.95 Y138.395 E-.5998
G1 X132.687 Y138.658 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X139.091 Y139.393 Z4.6 F36000
G1 Z4.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53921
G1 F12000
G1 X139.164 Y139.319 E.00419
G1 X139.091 Y139.393 F36000
; LINE_WIDTH: 0.51922
G1 F12000
G1 X138.974 Y139.438 E.00484
; LINE_WIDTH: 0.479413
G1 X138.059 Y139.662 E.03352
; LINE_WIDTH: 0.424529
G2 X136.17 Y140.148 I10.609 J45.186 E.06068
G1 X137.287 Y141.265 E.04912
G1 X137.706 Y140.862 E.01811
; LINE_WIDTH: 0.439798
G1 X138.359 Y140.181 E.03048
; LINE_WIDTH: 0.479413
G1 X139.011 Y139.501 E.03352
; LINE_WIDTH: 0.51922
G1 X139.055 Y139.441 E.00289
G1 X137.954 Y140.069 F36000
; LINE_WIDTH: 0.43676
G1 F12000
G1 X136.914 Y140.348 E.03453
G1 X137.295 Y140.728 E.01727
G1 X137.911 Y140.112 E.02798
G1 X150.322 Y154.377 F36000
; LINE_WIDTH: 0.514025
G1 F12000
G1 X149.989 Y154.71 E.01809
G1 X139.572 Y144.293 E.56552
G1 X139.88 Y143.985 E.01672
; Slow Down Start
; LINE_WIDTH: 0.514025
G1 F3000;_EXTRUDE_SET_SPEED
G1 X139.905 Y143.96 E.00136
G1 X150.28 Y154.334 E.56322
; Slow Down End
G1 X148.392 Y158.37 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X149.95 Y155.258 E.05553
G2 X150.233 Y155.087 I.056 J-.227 E.01218
G1 X150.772 Y154.547 E.02532
G1 X150.772 Y154.206 E.01131
G1 X149.307 Y152.741 E.06874
G1 X152.741 Y149.307 E.16109
G1 X154.206 Y150.772 E.06874
G1 X154.547 Y150.772 E.01131
G1 X155.258 Y150.062 E.03334
G1 X155.258 Y149.95 E.00372
G1 X156.442 Y148.766 E.05553
G1 X157.219 Y149.543 E.03647
G1 X154.123 Y152.639 E.14523
G1 X155.604 Y154.12 E.06947
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X139.561 Y139.561 E.74784
G2 X139.667 Y139.354 I-.082 J-.172 E.0083
G1 X143.695 Y135.326 E.18897
G1 X143.354 Y134.984 E.01602
G1 X143.007 Y135.331 E.01627
G1 X145.516 Y137.841 E.11774
G1 X144.333 Y139.024 E.05553
G1 X144.221 Y139.024 E.00372
G1 X143.51 Y139.735 E.03334
G1 X143.51 Y140.076 E.01131
G1 X145.065 Y141.631 E.07296
G1 X141.631 Y145.065 E.16109
G1 X145.469 Y148.903 E.18005
G1 X148.903 Y145.469 E.16109
G1 X150.054 Y146.621 E.05401
G1 X154.543 Y150.156 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.51402
G1 F12000
G1 X154.402 Y150.297 E.00768
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X154.377 Y150.322 E.00136
G1 X143.96 Y139.905 E.56551
G1 X143.985 Y139.88 E.00136
; Slow Down End
G1 F12000
G1 X144.293 Y139.572 E.01672
G1 X154.71 Y149.989 E.56551
G1 X154.586 Y150.113 E.00674
; WIPE_START
G1 X154.71 Y149.989 E-.06671
G1 X153.42 Y148.699 E-.69329
; WIPE_END
G1 E-.04 F1800
G1 X146.924 Y144.692 Z4.6 F36000
G1 X121.569 Y129.05 Z4.6
G1 Z4.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X120.418 Y127.899 E.05401
G1 X127.899 Y120.418 E.35095
G1 X131.737 Y124.256 E.18005
G1 X124.256 Y131.737 E.35095
G1 X128.094 Y135.575 E.18005
G1 X135.575 Y128.094 E.35095
G1 X136.828 Y129.347 E.05878
G1 X133.407 Y132.768 E.16048
M73 P74 R4
G2 X132.695 Y132.695 I-.391 J.309 E.02648
G1 X118.348 Y118.348 E.67303
G1 X116.252 Y120.444 E.09833
G1 X115.911 Y120.444 E.01131
G1 X114.483 Y119.016 E.06697
G1 X113.76 Y119.205 E.02481
G1 X112.742 Y120.223 E.04775
G1 X116.58 Y124.061 E.18005
G1 X124.061 Y116.58 E.35095
G1 X122.909 Y115.428 E.05401
G1 X122.141 Y113.969 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.61301
G1 F11050.887
G1 X137.031 Y128.86 E.97828
G1 X117.878 Y118.18 F36000
; LINE_WIDTH: 0.5392
G1 F12000
G1 X117.951 Y118.106 E.00419
G1 X117.878 Y118.18 F36000
; LINE_WIDTH: 0.519205
G1 F12000
G1 X117.761 Y118.225 E.00484
; LINE_WIDTH: 0.479405
G1 X116.846 Y118.449 E.03352
; LINE_WIDTH: 0.424528
G2 X114.956 Y118.935 I10.607 J45.176 E.06068
G1 X116.073 Y120.052 E.04912
G1 X116.493 Y119.648 E.01811
; LINE_WIDTH: 0.439795
G1 X117.146 Y118.968 E.03048
; LINE_WIDTH: 0.479405
G1 X117.798 Y118.288 E.03352
; LINE_WIDTH: 0.519205
G1 X117.842 Y118.228 E.00289
G1 X116.74 Y118.856 F36000
; LINE_WIDTH: 0.43679
G1 F12000
G1 X115.701 Y119.135 E.03454
G1 X116.081 Y119.515 E.01727
G1 X116.698 Y118.899 E.02798
; WIPE_START
G1 X116.081 Y119.515 E-.33131
G1 X115.701 Y119.135 E-.20445
G1 X116.271 Y118.982 E-.22424
; WIPE_END
G1 E-.04 F1800
G1 X112.047 Y112.625 Z4.6 F36000
G1 X111.621 Y111.984 Z4.6
G1 Z4.2
G1 E.8 F1800
; LINE_WIDTH: 0.54108
G1 F12000
G1 X111.724 Y111.879 E.00596
G1 X111.621 Y111.984 F36000
; LINE_WIDTH: 0.52894
G1 F12000
G1 X111.547 Y112.037 E.0036
; LINE_WIDTH: 0.491188
G1 X110.864 Y112.687 E.03443
; LINE_WIDTH: 0.425428
G2 X109.777 Y113.74 I20.374 J22.111 E.04718
G2 X110.894 Y114.873 I29.404 J-27.866 E.0496
G1 X111.155 Y113.899 E.03144
; LINE_WIDTH: 0.443723
G1 X111.376 Y112.982 E.03078
; LINE_WIDTH: 0.491188
G1 X111.597 Y112.066 E.03443
; LINE_WIDTH: 0.52894
G1 X111.604 Y112.041 E.00102
G1 X110.973 Y113.089 F36000
; LINE_WIDTH: 0.43677
G1 F12000
G1 X110.314 Y113.748 E.02991
G1 X110.695 Y114.128 E.01727
G1 X110.958 Y113.147 E.03261
G1 X107.752 Y115.233 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X108.904 Y116.385 E.05401
G1 X110.378 Y114.911 E.06915
G1 X109.385 Y113.918 E.04655
G1 X109.385 Y113.578 E.01131
G1 X111.481 Y111.482 E.09833
G1 X99.783 Y99.783 E.54881
G1 X98.066 Y101.5 E.08054
G1 X99.413 Y102.847 E.06321
G1 X102.847 Y99.413 E.16109
G1 X106.685 Y103.251 E.18005
G1 X103.251 Y106.685 E.16109
G1 X107.089 Y110.523 E.18005
G1 X110.523 Y107.089 E.16109
G1 X110.967 Y107.533 E.0208
G2 X111.529 Y107.312 I.17 J-.391 E.02224
G1 X112.018 Y106.822 E.02298
G1 X112.018 Y106.71 E.00372
G1 X113.202 Y105.526 E.05553
G1 X115.712 Y108.036 E.11774
G1 X114.561 Y109.187 E.05401
G1 X107.082 Y111.137 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.514025
G1 F12000
G1 X106.749 Y111.47 E.01809
G1 X97.487 Y102.208 E.50288
G1 X97.795 Y101.9 E.01672
; Slow Down Start
; LINE_WIDTH: 0.514025
G1 F3000;_EXTRUDE_SET_SPEED
G1 X97.82 Y101.874 E.00136
G1 X107.04 Y111.095 E.50057
; Slow Down End
G1 X105.377 Y113.546 F36000
; LINE_WIDTH: 0.6089
G1 F11131.136
G1 X137.454 Y145.623 E2.09214
; WIPE_START
G1 X136.04 Y144.209 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.563 Y138.027 Z4.6 F36000
G1 X102.208 Y97.487 Z4.6
G1 Z4.2
G1 E.8 F1800
; LINE_WIDTH: 0.51402
G1 F12000
G1 X111.47 Y106.749 E.50287
G1 X111.162 Y107.057 E.01672
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X111.137 Y107.082 E.00136
G1 X101.874 Y97.82 E.50287
G1 X101.9 Y97.795 E.00136
; Slow Down End
G1 F12000
G1 X102.165 Y97.529 E.01442
; CHANGE_LAYER
; Z_HEIGHT: 4.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X101.9 Y97.795 E-.76
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
G1 X132.239 Y137.11
G1 Z4.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X138.81 Y139.035 E.12805
G1 X143.264 Y134.581 E.20895
G1 X146.267 Y137.582 E.14084
G1 X144.454 Y139.395 E.08506
G1 X154.887 Y149.828 E.48942
G1 X158.314 Y146.401 E.16075
G1 X159.583 Y147.671 E.05957
G1 X154.616 Y152.639 E.23304
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.671 Y159.583 E.23304
G1 X146.401 Y158.314 E.05957
G1 X149.828 Y154.887 E.16075
G1 X139.395 Y144.454 E.48942
G1 X137.582 Y146.268 E.08506
G1 X104.775 Y113.461 E1.53904
G1 X106.588 Y111.647 E.08506
G1 X97.007 Y102.066 E.44948
G1 X102.066 Y97.007 E.23733
G1 X103.125 Y98.066 E.04967
G1 X111.647 Y106.588 E.39981
G1 X113.461 Y104.775 E.08506
G1 X116.462 Y107.779 E.14084
G1 X112.008 Y112.233 E.20895
G1 X111.009 Y115.961 E.12805
G1 X113.868 Y118.821 E.13414
G1 X117.597 Y117.822 E.12805
G1 X122.051 Y113.368 E.20895
G1 X137.675 Y128.992 E.73296
G1 X133.221 Y133.446 E.20895
G1 X132.255 Y137.053 E.12386
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.264 Y134.026 E.20237
G1 X146.822 Y137.582 E.15456
G1 X145.009 Y139.395 E.07879
G1 X154.887 Y149.274 E.42926
G1 X158.314 Y145.847 E.1489
G1 X160.138 Y147.671 E.07928
G1 X155.17 Y152.639 E.21587
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.671 Y160.138 E.21587
G1 X145.847 Y158.314 E.07928
G1 X149.274 Y154.887 E.1489
G1 X139.395 Y145.009 E.42926
G1 X137.582 Y146.822 E.07879
G1 X104.221 Y113.461 E1.44971
G1 X106.034 Y111.647 E.07879
G1 X96.453 Y102.066 E.41635
G1 X102.066 Y96.453 E.24393
G1 X103.402 Y97.789 E.05805
G1 X111.647 Y106.034 E.3583
G1 X113.461 Y104.221 E.07879
G1 X117.016 Y107.779 E.15456
G1 X112.359 Y112.436 E.20237
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X122.051 Y112.813 E.20237
G1 X138.229 Y128.992 E.70304
G1 X133.573 Y133.649 E.20236
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X131.543 Y133.846 Z4.8 F36000
G1 Z4.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.695 Y132.695 E.05401
G1 X118.348 Y118.348 E.67303
G1 X116.252 Y120.444 E.09833
G1 X115.911 Y120.444 E.01131
G1 X114.483 Y119.016 E.06697
G1 X113.76 Y119.205 E.02481
G1 X112.855 Y120.11 E.04246
G1 X109.017 Y116.272 E.18005
G1 X110.378 Y114.911 E.06386
G1 X109.385 Y113.918 E.04655
G1 X109.385 Y113.578 E.01131
G1 X111.482 Y111.482 E.09833
G1 X99.783 Y99.783 E.54881
G1 X98.281 Y101.284 E.07044
G1 X99.629 Y102.632 E.06321
G1 X102.632 Y99.629 E.14088
G1 X106.47 Y103.467 E.18005
G1 X103.467 Y106.47 E.14087
G1 X107.305 Y110.308 E.18005
G1 X110.308 Y107.305 E.14087
G1 X110.751 Y107.748 E.0208
G1 X111.092 Y107.748 E.01131
G1 X111.877 Y106.964 E.03682
G1 X111.877 Y106.851 E.00372
G1 X113.202 Y105.526 E.06217
G1 X115.712 Y108.036 E.11774
G1 X114.561 Y109.187 E.05401
G1 X111.621 Y111.984 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54108
G1 F12000
G1 X111.724 Y111.879 E.00596
G1 X111.621 Y111.984 F36000
; LINE_WIDTH: 0.52894
G1 F12000
G1 X111.547 Y112.037 E.0036
; LINE_WIDTH: 0.491188
G1 X110.864 Y112.687 E.03443
; LINE_WIDTH: 0.425428
G2 X109.777 Y113.74 I20.374 J22.111 E.04718
G2 X110.894 Y114.873 I29.404 J-27.866 E.0496
G1 X111.155 Y113.899 E.03144
; LINE_WIDTH: 0.443723
G1 X111.376 Y112.982 E.03078
; LINE_WIDTH: 0.491188
G1 X111.597 Y112.066 E.03443
; LINE_WIDTH: 0.52894
G1 X111.604 Y112.041 E.00102
G1 X110.973 Y113.089 F36000
; LINE_WIDTH: 0.43677
G1 F12000
G1 X110.314 Y113.748 E.02991
G1 X110.695 Y114.128 E.01727
G1 X110.958 Y113.147 E.03261
G1 X107.23 Y110.952 F36000
; LINE_WIDTH: 0.56639
G1 F12000
G1 X106.891 Y111.292 E.02049
G1 X97.665 Y102.066 E.55654
G1 X98.005 Y101.726 E.02049
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X98.035 Y101.696 E.00184
; Slow Down End
G1 F12000
G1 X107.249 Y110.91 E.55582
G1 X105.49 Y113.461 F36000
; LINE_WIDTH: 0.64718
G1 F10425.976
G1 X137.54 Y145.51 E2.23176
G1 X137.034 Y144.289 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X135.882 Y143.138 E.05401
G1 X137.363 Y141.657 E.06946
G1 X137.124 Y141.657 E.00792
G1 X135.697 Y140.23 E.06697
G1 X134.977 Y140.422 E.02471
G1 X132.95 Y138.395 E.09512
G1 X132.044 Y139.3 E.04246
G1 X128.206 Y135.462 E.18005
G1 X135.462 Y128.206 E.34037
G1 X131.624 Y124.368 E.18005
G1 X124.368 Y131.624 E.34037
G1 X123.217 Y130.473 E.05401
G1 X132.834 Y133.197 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.54112
G1 F12000
G1 X132.937 Y133.092 E.00597
G1 X132.834 Y133.197 F36000
; LINE_WIDTH: 0.528995
G1 F12000
G1 X132.76 Y133.25 E.0036
; LINE_WIDTH: 0.491225
G1 X132.077 Y133.9 E.03443
; LINE_WIDTH: 0.425431
G2 X130.991 Y134.953 I20.353 J22.09 E.04718
G2 X132.108 Y136.086 I29.372 J-27.836 E.0496
G1 X132.369 Y135.112 E.03144
; LINE_WIDTH: 0.443735
G1 X132.59 Y134.196 E.03078
; LINE_WIDTH: 0.491225
G1 X132.811 Y133.279 E.03443
; LINE_WIDTH: 0.528995
G1 X132.818 Y133.255 E.00102
G1 X132.187 Y134.302 F36000
; LINE_WIDTH: 0.43677
G1 F12000
G1 X131.528 Y134.961 E.02991
G1 X131.908 Y135.342 E.01727
G1 X132.171 Y134.36 E.03261
; WIPE_START
G1 X131.908 Y135.342 E-.3861
G1 X131.528 Y134.961 E-.20445
G1 X131.843 Y134.646 E-.16945
; WIPE_END
G1 E-.04 F1800
G1 X138.228 Y138.828 Z4.8 F36000
G1 X139.091 Y139.393 Z4.8
G1 Z4.4
G1 E.8 F1800
; LINE_WIDTH: 0.53921
G1 F12000
G1 X139.164 Y139.319 E.00419
G1 X139.091 Y139.393 F36000
; LINE_WIDTH: 0.51922
G1 F12000
G1 X138.974 Y139.438 E.00484
; LINE_WIDTH: 0.479413
G1 X138.059 Y139.662 E.03352
; LINE_WIDTH: 0.424529
G2 X136.17 Y140.148 I10.609 J45.186 E.06068
G1 X137.287 Y141.265 E.04912
G1 X137.706 Y140.862 E.01811
; LINE_WIDTH: 0.439798
G1 X138.359 Y140.181 E.03048
; LINE_WIDTH: 0.479413
G1 X139.011 Y139.501 E.03352
; LINE_WIDTH: 0.51922
G1 X139.055 Y139.441 E.00289
G1 X137.954 Y140.069 F36000
; LINE_WIDTH: 0.43676
G1 F12000
G1 X136.914 Y140.348 E.03453
G1 X137.295 Y140.728 E.01727
G1 X137.911 Y140.112 E.02798
G1 X150.315 Y153.976 F36000
; LINE_WIDTH: 0.56637
G1 F12000
G1 X150.501 Y154.161 E.01116
G1 X150.13 Y154.531 E.02233
G1 X139.751 Y144.152 E.62612
G1 X140.09 Y143.812 E.02049
; Slow Down Start
; LINE_WIDTH: 0.56637
G1 F3000;_EXTRUDE_SET_SPEED
G1 X140.121 Y143.782 E.00184
G1 X150.273 Y153.934 E.6124
; Slow Down End
G1 X150.695 Y156.068 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X150.091 Y155.117 E.06217
G1 X150.203 Y155.117 E.00372
G1 X150.988 Y154.332 E.03682
G1 X150.988 Y153.991 E.01131
G1 X149.523 Y152.526 E.06874
G1 X152.526 Y149.523 E.14087
G1 X148.688 Y145.685 E.18005
G1 X145.685 Y148.688 E.14088
G1 X141.847 Y144.85 E.18005
G1 X144.85 Y141.847 E.14088
G1 X143.294 Y140.291 E.07296
G3 X143.539 Y139.706 I.415 J-.17 E.0234
G1 X144.079 Y139.166 E.02532
G1 X144.191 Y139.166 E.00372
G1 X145.516 Y137.841 E.06217
M73 P75 R4
G1 X143.007 Y135.331 E.11774
G1 X143.264 Y135.073 E.01208
G1 X143.606 Y135.415 E.01602
G1 X139.667 Y139.354 E.18479
G3 X139.561 Y139.561 I-.188 J.035 E.0083
G1 X155.502 Y155.502 E.74784
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X157.593 Y147.614 E.05401
G1 X154.346 Y150.315 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.56636
G1 F12000
G1 X154.192 Y150.47 E.00933
; Slow Down Start
; LINE_WIDTH: 0.566365
G1 F3000;_EXTRUDE_SET_SPEED
G1 X154.161 Y150.5 E.00184
G1 X143.782 Y140.121 E.62612
G1 X143.812 Y140.09 E.00184
; Slow Down End
; LINE_WIDTH: 0.566365
G1 F12000
G1 X144.152 Y139.751 E.02049
G1 X154.531 Y150.13 E.62612
G1 X154.389 Y150.273 E.0086
; WIPE_START
G1 X154.531 Y150.13 E-.07666
G1 X153.26 Y148.859 E-.68334
; WIPE_END
G1 E-.04 F1800
G1 X148.11 Y143.226 Z4.8 F36000
G1 X122.797 Y115.541 Z4.8
G1 Z4.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X123.948 Y116.693 E.05401
G1 X116.692 Y123.948 E.34037
G1 X120.53 Y127.786 E.18005
G1 X127.786 Y120.53 E.34037
G1 X128.937 Y121.682 E.05401
G1 X122.051 Y114.082 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.6456
G1 F10453.309
G1 X136.919 Y128.949 E1.03261
G1 X117.878 Y118.18 F36000
; LINE_WIDTH: 0.5392
G1 F12000
G1 X117.951 Y118.106 E.00419
G1 X117.878 Y118.18 F36000
; LINE_WIDTH: 0.519205
G1 F12000
G1 X117.761 Y118.225 E.00484
; LINE_WIDTH: 0.479405
G1 X116.846 Y118.449 E.03352
; LINE_WIDTH: 0.424528
G2 X114.956 Y118.935 I10.607 J45.176 E.06068
G1 X116.073 Y120.052 E.04912
G1 X116.493 Y119.648 E.01811
; LINE_WIDTH: 0.439795
G1 X117.146 Y118.968 E.03048
; LINE_WIDTH: 0.479405
G1 X117.798 Y118.288 E.03352
; LINE_WIDTH: 0.519205
G1 X117.842 Y118.228 E.00289
G1 X116.74 Y118.856 F36000
; LINE_WIDTH: 0.43679
G1 F12000
G1 X115.701 Y119.135 E.03454
G1 X116.081 Y119.515 E.01727
G1 X116.698 Y118.899 E.02798
; WIPE_START
G1 X116.081 Y119.515 E-.33131
G1 X115.701 Y119.135 E-.20445
G1 X116.271 Y118.982 E-.22424
; WIPE_END
G1 E-.04 F1800
G1 X112.039 Y112.63 Z4.8 F36000
G1 X102.066 Y97.665 Z4.8
G1 Z4.4
G1 E.8 F1800
; LINE_WIDTH: 0.566386
G1 F12000
G1 X111.292 Y106.891 E.55654
G1 X110.952 Y107.23 E.02049
; Slow Down Start
; LINE_WIDTH: 0.566385
G1 F3000;_EXTRUDE_SET_SPEED
G1 X110.922 Y107.261 E.00184
G1 X101.696 Y98.035 E.55654
G1 X101.726 Y98.005 E.00184
; Slow Down End
; LINE_WIDTH: 0.56638
G1 F12000
G1 X102.024 Y97.708 E.01793
; CHANGE_LAYER
; Z_HEIGHT: 4.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X101.726 Y98.005 E-.76
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
G1 X132.239 Y137.11
G1 Z4.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X132.222 Y137.175 E.0022
G1 X135.081 Y140.034 E.13414
G1 X135.889 Y139.818 E.02774
G1 X137.295 Y141.223 E.06594
G1 X139.241 Y139.276 E.09132
G1 X138.995 Y138.85 E.01634
G1 X143.173 Y134.671 E.19602
G1 X146.173 Y137.676 E.14084
G1 X144.301 Y139.548 E.08783
G1 X154.734 Y149.981 E.48942
G1 X158.245 Y146.47 E.16469
G1 X159.514 Y147.74 E.05957
G1 X154.616 Y152.639 E.2298
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.74 Y159.514 E.2298
G1 X146.47 Y158.245 E.05957
G1 X149.981 Y154.734 E.16469
G1 X139.548 Y144.301 E.48942
G1 X137.676 Y146.173 E.08781
G1 X104.87 Y113.366 E1.53904
G1 X106.741 Y111.494 E.08781
G1 X97.16 Y101.913 E.44948
G1 X101.913 Y97.16 E.22297
G1 X111.494 Y106.741 E.44948
G1 X113.367 Y104.869 E.08783
G1 X116.371 Y107.869 E.14084
G1 X112.193 Y112.048 E.19602
G1 X111.766 Y111.801 E.01634
G1 X109.82 Y113.748 E.09132
G1 X111.225 Y115.154 E.06594
G1 X111.009 Y115.961 E.02774
G1 X113.868 Y118.821 E.13414
G1 X114.676 Y118.604 E.02774
G1 X116.081 Y120.01 E.06594
G1 X118.028 Y118.063 E.09132
G1 X117.782 Y117.637 E.01634
G1 X121.961 Y113.458 E.19603
G1 X137.585 Y129.082 E.73296
G1 X133.406 Y133.261 E.19603
G1 X132.98 Y133.015 E.01634
G1 X131.033 Y134.961 E.09132
G1 X132.438 Y136.367 E.06594
G1 X132.255 Y137.053 E.02355
G1 X132.659 Y137.057 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X135.198 Y139.597 E.11035
G1 X138.607 Y138.683 E.10843
G1 X143.174 Y134.117 E.19844
G1 X146.728 Y137.676 E.15456
G1 X144.856 Y139.548 E.08135
G1 X154.734 Y149.427 E.42926
G1 X158.245 Y145.916 E.15255
G1 X160.069 Y147.74 E.07928
G1 X155.17 Y152.639 E.21287
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.74 Y160.069 E.21287
G1 X145.916 Y158.245 E.07928
G1 X149.427 Y154.734 E.15255
G1 X139.548 Y144.856 E.42926
G1 X137.676 Y146.728 E.08134
G1 X104.315 Y113.366 E1.44971
G1 X106.187 Y111.494 E.08134
G1 X96.606 Y101.913 E.41635
G1 X101.913 Y96.606 E.23063
G1 X111.494 Y106.187 E.41635
G1 X113.366 Y104.315 E.08134
G1 X116.926 Y107.869 E.15456
G1 X112.359 Y112.436 E.19844
G1 X111.446 Y115.844 E.10843
G1 X113.985 Y118.383 E.11035
G1 X117.394 Y117.47 E.10843
G1 X121.961 Y112.903 E.19844
G1 X138.139 Y129.082 E.70304
G1 X133.573 Y133.649 E.19844
G1 X132.675 Y136.999 E.10659
; WIPE_START
M204 S10000
G1 X134.068 Y138.434 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X132.754 Y133.554 Z5 F36000
G1 Z4.6
G1 E.8 F1800
; FEATURE: Top surface
G1 F12000
M204 S2000
G1 X133.25 Y134.05 E.02155
G1 X133.138 Y134.471
G1 X132.488 Y133.821 E.02824
G1 X132.221 Y134.088
G1 X133.025 Y134.891 E.03493
G1 X132.912 Y135.312
G1 X131.954 Y134.354 E.04162
G1 X131.688 Y134.621
G1 X132.799 Y135.732 E.04831
M204 S10000
G1 X132.787 Y135.851 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.188554
G1 F15000
G1 X132.736 Y135.889 E.00075
; LINE_WIDTH: 0.237211
G1 X132.685 Y135.926 E.001
; LINE_WIDTH: 0.285868
G1 X132.634 Y135.963 E.00125
; LINE_WIDTH: 0.353789
G1 X132.584 Y136.001 E.0016
G1 X132.556 Y135.976 E.00094
G1 X131.431 Y134.851 E.0403
; WIPE_START
G1 X132.556 Y135.976 E-.71502
G1 X132.584 Y136.001 E-.01664
G1 X132.634 Y135.963 E-.02834
; WIPE_END
G1 E-.04 F1800
G1 X138.206 Y139.006 Z5 F36000
G1 Z4.6
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X138.702 Y139.501 E.02155
G1 X138.435 Y139.768
G1 X137.785 Y139.118 E.02824
G1 X137.365 Y139.231
G1 X138.168 Y140.035 E.03493
G1 X137.902 Y140.301
G1 X136.944 Y139.344 E.04162
G1 X136.523 Y139.456
G1 X137.635 Y140.568 E.04831
M204 S10000
G1 X136.404 Y139.469 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.188547
G1 F15000
G1 X136.367 Y139.52 E.00075
; LINE_WIDTH: 0.237207
G1 X136.33 Y139.57 E.001
; LINE_WIDTH: 0.285866
G1 X136.293 Y139.621 E.00125
; LINE_WIDTH: 0.353776
G1 X136.255 Y139.672 E.0016
G1 X136.28 Y139.7 E.00094
G1 X137.405 Y140.825 E.0403
; WIPE_START
G1 X136.28 Y139.7 E-.71503
G1 X136.255 Y139.672 E-.01663
G1 X136.293 Y139.621 E-.02834
; WIPE_END
G1 E-.04 F1800
G1 X137.155 Y144.168 Z5 F36000
G1 Z4.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X136.004 Y143.016 E.05401
G1 X143.016 Y136.004 E.32895
G1 X145.185 Y138.172 E.10172
G1 X144.038 Y139.319 E.05378
G1 X143.926 Y139.319 E.00372
G1 X143.047 Y140.198 E.04123
G1 X143.047 Y140.539 E.01131
G1 X144.602 Y142.094 E.07296
G1 X142.094 Y144.602 E.11769
G1 X145.932 Y148.44 E.18005
G1 X148.44 Y145.932 E.11769
G1 X152.278 Y149.77 E.18005
G1 X149.77 Y152.278 E.11769
G1 X151.235 Y153.744 E.06874
G1 X151.235 Y154.085 E.01131
G1 X150.356 Y154.963 E.04123
G1 X150.244 Y154.963 E.00372
G1 X148.766 Y156.442 E.06935
G1 X149.543 Y157.219 E.03647
G1 X150.695 Y156.068 E.05401
G1 X150.567 Y153.63 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X150.843 Y153.922 E.01234
G1 X150.283 Y154.482 E.02432
G1 X139.8 Y143.999 E.45553
G1 X140.261 Y143.551 E.01972
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X140.376 Y143.439 E.00495
G1 X150.525 Y153.588 E.441
; Slow Down End
G1 X140.368 Y143.999 F36000
; LINE_WIDTH: 0.46873
G1 F12000
G1 X150.241 Y153.872 E.48447
G1 X157.593 Y147.614 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.442 Y148.766 E.05401
G1 X157.219 Y149.543 E.03647
G1 X154.123 Y152.639 E.14523
G1 X155.604 Y154.12 E.06947
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X139.505 Y139.505 E.75047
G1 X143.715 Y140.652 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F3000;_EXTRUDE_SET_SPEED
G1 X143.439 Y140.36 E.01234
G1 X143.545 Y140.254 E.0046
; Slow Down End
G1 F12000
G1 X143.999 Y139.8 E.01972
G1 X154.482 Y150.283 E.45553
G3 X154.023 Y150.732 I-8.113 J-7.83 E.01972
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X153.906 Y150.843 E.00495
; Slow Down End
G1 F12000
G1 X143.757 Y140.694 E.441
G1 X143.999 Y140.368 F36000
; LINE_WIDTH: 0.46871
G1 F12000
G1 X153.872 Y150.241 E.48445
; WIPE_START
G1 X152.457 Y148.827 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X148.406 Y142.358 Z5 F36000
G1 X145.544 Y137.79 Z5
G1 Z4.6
G1 E.8 F1800
; Slow Down Start
; LINE_WIDTH: 0.365376
G1 F3000;_EXTRUDE_SET_SPEED
G1 X145.431 Y137.903 E.00423
G1 X142.945 Y135.417 E.0924
G1 X143.173 Y135.188 E.00849
G1 X145.658 Y137.676 E.0924
G1 X145.587 Y137.747 E.00265
; Slow Down End
G1 X137.79 Y145.544 F36000
; LINE_WIDTH: 0.364295
G1 F12000
G1 X137.676 Y145.658 E.00421
G1 X105.385 Y113.366 E1.19594
G1 X105.604 Y113.147 E.00811
; Slow Down Start
; LINE_WIDTH: 0.364295
G1 F3000;_EXTRUDE_SET_SPEED
G1 X137.896 Y145.439 E1.19594
; Slow Down End
; LINE_WIDTH: 0.36429
G1 F12000
G1 X137.832 Y145.502 E.00233
; WIPE_START
G1 X137.896 Y145.439 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.292 Y139.351 Z5 F36000
M73 P76 R4
G1 X116.992 Y117.792 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X117.488 Y118.288 E.02155
G1 X117.222 Y118.555
G1 X116.572 Y117.905 E.02824
G1 X116.151 Y118.018
G1 X116.955 Y118.822 E.03493
G1 X116.688 Y119.088
G1 X115.731 Y118.13 E.04162
G1 X115.31 Y118.243
G1 X116.422 Y119.355 E.04831
M204 S10000
G1 X115.191 Y118.256 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.188561
G1 F15000
G1 X115.154 Y118.306 E.00075
; LINE_WIDTH: 0.237221
G1 X115.117 Y118.357 E.001
; LINE_WIDTH: 0.28588
G1 X115.079 Y118.408 E.00125
; LINE_WIDTH: 0.353783
G1 X115.042 Y118.459 E.0016
G1 X115.067 Y118.487 E.00094
G1 X116.192 Y119.612 E.0403
; WIPE_START
G1 X115.067 Y118.487 E-.71502
G1 X115.042 Y118.459 E-.01663
G1 X115.079 Y118.408 E-.02834
; WIPE_END
G1 E-.04 F1800
G1 X121.495 Y114.274 Z5 F36000
G1 X121.961 Y113.975 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.36647
G1 F12000
G1 X137.068 Y129.082 E.5633
G1 X136.847 Y129.303 E.00825
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X121.739 Y114.196 E.5633
; Slow Down End
G1 F12000
G1 X121.918 Y114.017 E.00667
; WIPE_START
G1 X121.739 Y114.196 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X116.437 Y108.705 Z5 F36000
G1 X115.74 Y107.984 Z5
G1 Z4.6
G1 E.8 F1800
; LINE_WIDTH: 0.365381
G1 F12000
G1 X115.855 Y107.869 E.00425
G1 X113.367 Y105.384 E.0924
G1 X113.139 Y105.612 E.00845
G1 X115.626 Y108.098 E.0924
G1 X115.698 Y108.026 E.00267
G1 X111.312 Y107.529 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X110.845 Y107.995 E.0219
G1 X110.504 Y107.995 E.01131
G1 X110.061 Y107.552 E.0208
G1 X107.552 Y110.061 E.11769
G1 X103.714 Y106.223 E.18005
G1 X106.223 Y103.714 E.11769
G1 X107.374 Y104.865 E.05401
G1 X107.044 Y111.242 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X97.715 Y101.913 E.40539
G1 X98.168 Y101.459 E.01972
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X98.282 Y101.345 E.00495
G1 X107.328 Y110.391 E.39305
; Slow Down End
G1 F12000
G1 X107.603 Y110.683 E.01234
G1 X107.086 Y111.2 E.02247
G1 X98.282 Y101.913 F36000
; LINE_WIDTH: 0.46875
G1 F12000
G1 X107.001 Y110.632 E.42787
; WIPE_START
G1 X105.587 Y109.218 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X111.541 Y112.341 Z5 F36000
G1 Z4.6
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X112.037 Y112.837 E.02155
G1 X111.924 Y113.258
G1 X111.275 Y112.608 E.02824
G1 X111.008 Y112.874
G1 X111.812 Y113.678 E.03493
G1 X111.699 Y114.099
G1 X110.741 Y113.141 E.04162
G1 X110.475 Y113.408
G1 X111.586 Y114.519 E.04831
M204 S10000
G1 X111.574 Y114.638 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.188537
G1 F15000
G1 X111.523 Y114.676 E.00075
; LINE_WIDTH: 0.2372
G1 X111.472 Y114.713 E.001
; LINE_WIDTH: 0.285863
G1 X111.421 Y114.75 E.00125
; LINE_WIDTH: 0.353789
G1 X111.37 Y114.787 E.0016
G1 X111.343 Y114.763 E.00094
G1 X110.218 Y113.638 E.0403
; WIPE_START
G1 X111.343 Y114.763 E-.71503
G1 X111.37 Y114.787 E-.01663
G1 X111.421 Y114.75 E-.02834
; WIPE_END
G1 E-.04 F1800
G1 X106.233 Y109.152 Z5 F36000
G1 X101.027 Y103.536 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X99.876 Y102.385 E.05401
G1 X102.385 Y99.876 E.11769
G1 X101.037 Y98.529 E.06321
G1 X99.783 Y99.783 E.05884
G1 X111.538 Y111.538 E.55144
G1 X109.327 Y113.748 E.1037
G1 X110.434 Y114.855 E.05192
G1 X109.138 Y116.15 E.06078
G1 X112.976 Y119.988 E.18005
G1 X113.76 Y119.205 E.03675
G1 X114.572 Y118.993 E.02785
G1 X116.081 Y120.502 E.07082
G1 X118.292 Y118.292 E.1037
G1 X132.751 Y132.751 E.67829
G1 X130.54 Y134.961 E.1037
G1 X132.05 Y136.471 E.07082
G1 X131.833 Y137.279 E.02774
G1 X132.95 Y138.395 E.05236
G1 X132.166 Y139.178 E.03675
G1 X128.328 Y135.34 E.18005
G1 X135.34 Y128.328 E.32895
G1 X131.502 Y124.49 E.18005
G1 X124.49 Y131.502 E.32895
G1 X120.652 Y127.664 E.18005
G1 X127.664 Y120.652 E.32895
G1 X123.826 Y116.814 E.18005
G1 X116.814 Y123.826 E.32895
G1 X115.663 Y122.675 E.05401
; WIPE_START
G1 X116.814 Y123.826 E-.61876
G1 X117.077 Y123.563 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X113.079 Y117.062 Z5 F36000
G1 X101.459 Y98.168 Z5
G1 Z4.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X101.913 Y97.715 E.01972
G1 X111.242 Y107.044 E.40539
G3 X110.784 Y107.493 I-8.096 J-7.812 E.01972
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X110.666 Y107.604 E.00495
G1 X101.345 Y98.282 E.40504
; Slow Down End
G1 F12000
G1 X101.417 Y98.211 E.00311
G1 X101.913 Y98.282 F36000
; LINE_WIDTH: 0.46875
G1 F12000
G1 X110.632 Y107.001 E.42787
; CHANGE_LAYER
; Z_HEIGHT: 4.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X109.218 Y105.587 E-.76
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
G1 X131.983 Y134.684
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F13356.604
G1 X132.133 Y134.534 E.00704
G1 F12608.027
G1 X132.416 Y134.251 E.01327
G1 F11254.812
G1 X132.698 Y133.968 E.01327
G1 F9978.397
G1 X132.981 Y133.685 E.01327
G1 F8778.781
G1 X133.264 Y133.403 E.01327
G1 F7655.966
G1 X133.547 Y133.12 E.01327
G1 F6609.951
G1 X133.83 Y132.837 E.01327
G1 F5640.736
G1 X134.113 Y132.554 E.01327
G1 F4748.32
G1 X134.396 Y132.271 E.01327
G1 F3932.705
G1 X134.678 Y131.988 E.01327
G1 F3193.89
G1 X134.961 Y131.706 E.01327
G1 F2531.875
G1 X135.258 Y132.002 E.01392
G1 F1920
G1 X135.528 Y132.273 E.01269
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X139.983 Y136.728 E.20898
; FEATURE: Inner wall
G1 F1800
M204 S10000
G1 X140.254 Y136.998 E.01269
G1 F2393.787
G1 X140.55 Y137.295 E.01392
G1 F3038.558
G1 X140.267 Y137.577 E.01327
G1 F3760.129
G1 X139.985 Y137.86 E.01327
G1 F4558.499
G1 X139.702 Y138.143 E.01327
G1 F5433.67
G1 X139.419 Y138.426 E.01327
G1 F6385.641
G1 X139.136 Y138.709 E.01327
G1 F7414.412
G1 X138.853 Y138.992 E.01327
G1 F8519.983
G1 X138.57 Y139.275 E.01327
G1 F8963.745
G1 X138.288 Y139.557 E.01327
G1 F8254.461
G1 X138.143 Y139.702 E.00677
G1 F7689.749
G1 X137.86 Y139.985 E.01327
G1 F6641.344
G1 X137.577 Y140.267 E.01327
G1 F5669.739
G1 X137.295 Y140.55 E.01327
G1 F4774.933
G1 X136.926 Y140.181 E.01731
G1 F3723.041
G1 X136.643 Y139.898 E.01327
G1 F3005.227
G1 X136.36 Y139.616 E.01327
G1 F2364.214
G1 X136.077 Y139.333 E.01327
G1 F1800
G1 X135.765 Y139.02 E.01465
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X133.235 Y136.491 E.11866
; FEATURE: Inner wall
G1 F1920
M204 S10000
G1 X132.923 Y136.179 E.01465
G1 F2501.458
G1 X132.64 Y135.896 E.01327
G1 F3159.716
G1 X132.357 Y135.613 E.01327
G1 F3894.774
G1 X132.075 Y135.33 E.01327
G1 F4969.163
G1 X131.706 Y134.961 E.01731
G1 F5720.903
G1 X131.94 Y134.726 E.01102
G1 X132.26 Y134.961 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F10739.582
M204 S6000
G1 X132.416 Y134.806 E.00676
G1 F10044.831
G1 X132.698 Y134.523 E.01229
G1 F8841.101
G1 X132.981 Y134.24 E.01229
G1 F7714.172
G1 X133.264 Y133.957 E.01229
G1 F6664.042
G1 X133.547 Y133.674 E.01229
G1 F5690.712
G1 X133.83 Y133.391 E.01229
G1 F4794.183
G1 X134.113 Y133.109 E.01229
G1 F3974.453
G1 X134.396 Y132.826 E.01229
G1 F3231.523
G1 X134.678 Y132.543 E.01229
G1 F2565.394
G1 X134.961 Y132.26 E.01229
G1 F1976.064
G1 X134.99 Y132.289 E.00126
G1 F1920
G1 X135.251 Y132.55 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X139.706 Y137.005 E.20898
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1800
G1 X139.967 Y137.266 E.01134
G1 F1854.297
G1 X139.996 Y137.295 E.00126
G1 F2426.382
G1 X139.713 Y137.577 E.01229
G1 F3075.267
G1 X139.43 Y137.86 E.01229
G1 F3800.953
G1 X139.147 Y138.143 E.01229
G1 F4603.438
G1 X138.864 Y138.426 E.01229
G1 F5482.723
G1 X138.582 Y138.709 E.01229
G1 F6438.808
G1 X138.299 Y138.992 E.01229
G1 F6561.158
G1 X138.016 Y139.275 E.01229
G1 F5709.828
G1 X137.86 Y139.43 E.00676
G1 F5206.352
G1 X137.577 Y139.713 E.01229
G1 F4350.495
G1 X137.295 Y139.996 E.01229
G1 F3571.438
G1 X137.069 Y139.77 E.0098
G1 F3005.227
G1 X136.786 Y139.487 E.01229
G1 F2364.214
G1 X136.503 Y139.205 E.01229
G1 F1800
G1 X136.202 Y138.903 E.01309
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X133.353 Y136.054 E.13368
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1920
G1 X133.051 Y135.752 E.01309
G1 F2501.458
G1 X132.768 Y135.47 E.01229
G1 F3159.716
G1 X132.486 Y135.187 E.01229
G1 F3626.859
G1 X132.302 Y135.004 E.00796
; WIPE_START
M204 S10000
G1 X132.416 Y134.806 E-.08666
G1 X132.698 Y134.523 E-.152
G1 X132.981 Y134.24 E-.152
G1 X133.264 Y133.957 E-.152
G1 X133.547 Y133.674 E-.152
G1 X133.669 Y133.553 E-.06535
; WIPE_END
G1 E-.04 F1800
G1 X127.93 Y128.52 Z5.2 F36000
G1 X110.77 Y113.471 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F13036.93
G1 X111.014 Y113.227 E.01145
G1 F11845.013
G1 X111.296 Y112.944 E.01327
G1 F10534.564
G1 X111.579 Y112.661 E.01327
G1 F9300.915
G1 X111.862 Y112.378 E.01327
G1 F8144.066
G1 X112.145 Y112.095 E.01327
G1 F7064.016
G1 X112.428 Y111.813 E.01327
G1 F6060.767
G1 X112.711 Y111.53 E.01327
G1 F5134.318
G1 X112.993 Y111.247 E.01327
G1 F4284.669
G1 X113.182 Y111.058 E.00886
G1 F3760.129
G1 X113.465 Y110.775 E.01327
G1 F3038.558
G1 X113.748 Y110.492 E.01327
G1 F2393.787
G1 X114.045 Y110.789 E.01392
G1 F1800
G1 X114.315 Y111.06 E.01269
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X118.77 Y115.514 E.20898
; FEATURE: Inner wall
G1 F1920
M204 S10000
G1 X119.04 Y115.785 E.01269
G1 F2531.875
G1 X119.337 Y116.081 E.01392
G1 F3193.89
G1 X119.054 Y116.364 E.01327
G1 F3932.705
G1 X118.771 Y116.647 E.01327
G1 F4748.32
G1 X118.489 Y116.93 E.01327
G1 F5640.736
G1 X118.206 Y117.213 E.01327
G1 F6609.951
G1 X117.923 Y117.496 E.01327
G1 F7655.966
G1 X117.64 Y117.779 E.01327
G1 F8778.781
G1 X117.357 Y118.061 E.01327
G1 F9229.127
G1 X117.074 Y118.344 E.01327
G1 F8509.185
G1 X116.93 Y118.489 E.00677
G1 F7935.672
G1 X116.647 Y118.771 E.01327
G1 F6870.026
G1 X116.364 Y119.054 E.01327
G1 F5881.179
G1 X116.081 Y119.337 E.01327
G1 F4969.132
G1 X115.712 Y118.968 E.01731
G1 F3894.774
G1 X115.43 Y118.685 E.01327
G1 F3159.716
G1 X115.147 Y118.402 E.01327
G1 F2501.458
G1 X114.864 Y118.12 E.01327
G1 F1920
G1 X114.552 Y117.807 E.01465
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X112.022 Y115.278 E.11866
; FEATURE: Inner wall
G1 F1800
M204 S10000
G1 X111.71 Y114.966 E.01465
G1 F2364.214
G1 X111.427 Y114.683 E.01327
G1 F3005.227
G1 X111.144 Y114.4 E.01327
G1 F3723.041
G1 X110.861 Y114.117 E.01327
G1 F4774.903
G1 X110.492 Y113.748 E.01731
G1 F5512.325
G1 X110.727 Y113.513 E.01102
G1 X111.047 Y113.748 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F10453.177
M204 S6000
G1 X111.202 Y113.592 E.00676
G1 F9767.908
G1 X111.485 Y113.31 E.01229
G1 F8581.42
G1 X111.768 Y113.027 E.01229
G1 F7471.732
G1 X112.051 Y112.744 E.01229
G1 F6438.844
G1 X112.334 Y112.461 E.01229
G1 F5482.756
G1 X112.617 Y112.178 E.01229
G1 F4603.468
G1 X112.899 Y111.895 E.01229
G1 F3800.98
G1 X113.182 Y111.613 E.01229
G1 F3075.292
G1 X113.465 Y111.33 E.01229
G1 F2426.404
G1 X113.748 Y111.047 E.01229
G1 F1854.316
G1 X113.777 Y111.076 E.00126
G1 F1800
G1 X114.038 Y111.337 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X118.493 Y115.792 E.20898
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1920
G1 X118.754 Y116.052 E.01134
G1 F1976.064
G1 X118.783 Y116.081 E.00126
G1 F2565.394
G1 X118.5 Y116.364 E.01229
G1 F3231.523
G1 X118.217 Y116.647 E.01229
G1 F3974.453
G1 X117.934 Y116.93 E.01229
G1 F4794.183
G1 X117.651 Y117.213 E.01229
G1 F5690.712
G1 X117.368 Y117.496 E.01229
G1 F6664.042
G1 X117.086 Y117.779 E.01229
G1 F6788.485
G1 X116.803 Y118.061 E.01229
G1 F5922.008
G1 X116.647 Y118.217 E.00676
G1 F5409.048
G1 X116.364 Y118.5 E.01229
G1 F4535.95
G1 X116.081 Y118.783 E.01229
G1 F3739.651
G1 X115.856 Y118.557 E.0098
G1 F3159.716
G1 X115.573 Y118.274 E.01229
G1 F2501.458
G1 X115.29 Y117.991 E.01229
G1 F1920
G1 X114.989 Y117.69 E.01309
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X112.139 Y114.841 E.13368
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1800
G1 X111.838 Y114.539 E.01309
G1 F2364.214
G1 X111.555 Y114.256 E.01229
G1 F3005.227
G1 X111.272 Y113.974 E.01229
G1 F3461.154
G1 X111.089 Y113.79 E.00796
; WIPE_START
M204 S10000
G1 X111.202 Y113.592 E-.08666
G1 X111.485 Y113.31 E-.152
G1 X111.768 Y113.027 E-.152
G1 X112.051 Y112.744 E-.152
G1 X112.334 Y112.461 E-.152
G1 X112.455 Y112.339 E-.06535
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.2 I-.841 J.88 P1  F36000
G1 X154.616 Y152.639 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.815 Y159.44 E.2263
G1 X146.545 Y158.17 E.05957
G1 X150.147 Y154.568 E.16896
G1 X139.714 Y144.136 E.48942
G1 X137.775 Y146.074 E.09095
G1 X104.968 Y113.268 E1.53904
G1 X106.907 Y111.329 E.09095
G1 X97.326 Y101.748 E.44948
G1 X101.747 Y97.326 E.20743
G1 X110.741 Y106.319 E.42191
G1 X111.329 Y106.907 E.02757
G1 X112.702 Y105.534 E.06441
G1 X112.985 Y105.251 E.01327
G1 F14617.019
G1 X113.268 Y104.968 E.01327
G1 F13157.029
G1 X113.455 Y105.156 E.00881
G1 F12230.35
G1 X113.738 Y105.439 E.01327
G1 F10898.137
G1 X114.021 Y105.722 E.01327
G1 F9642.723
G1 X114.304 Y106.004 E.01327
G1 F8464.109
G1 X114.587 Y106.287 E.01327
G1 F7362.296
G1 X114.87 Y106.57 E.01327
G1 F6337.282
G1 X115.152 Y106.853 E.01327
G1 F5389.068
G1 X115.435 Y107.136 E.01327
G1 F4517.655
G1 X115.718 Y107.419 E.01327
G1 F3723.041
G1 X116.001 Y107.701 E.01327
G1 F3005.227
G1 X116.284 Y107.984 E.01327
G1 F2364.214
G1 X116.567 Y108.267 E.01327
G1 F1800
G1 X116.837 Y108.538 E.01269
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X121.292 Y112.992 E.20898
; FEATURE: Inner wall
G1 F1920
M204 S10000
G1 X121.563 Y113.263 E.01269
G1 F2501.458
G1 X121.845 Y113.545 E.01327
G1 F3159.716
G1 X122.128 Y113.828 E.01327
G1 F3894.774
G1 X122.411 Y114.111 E.01327
G1 F4706.632
G1 X122.694 Y114.394 E.01327
G1 F5595.29
G1 X122.977 Y114.677 E.01327
G1 F6560.748
G1 X123.26 Y114.96 E.01327
G1 F7603.006
G1 X123.542 Y115.242 E.01327
G1 F8722.064
G1 X123.825 Y115.525 E.01327
G1 F9917.922
G1 X124.108 Y115.808 E.01327
G1 F11190.58
G1 X124.391 Y116.091 E.01327
G1 F12540.038
G1 X124.674 Y116.374 E.01327
G1 F13966.296
G1 X124.957 Y116.657 E.01327
G1 F15469.354
G1 X125.24 Y116.939 E.01327
G1 F15476.087
G1 X125.522 Y117.222 E.01327
G1 X133.821 Y125.52 E.38928
G1 X134.103 Y125.803 E.01327
G1 F15469.354
G1 X134.386 Y126.086 E.01327
G1 F13966.296
G1 X134.669 Y126.369 E.01327
G1 F12540.038
G1 X134.952 Y126.651 E.01327
G1 F11190.58
G1 X135.235 Y126.934 E.01327
G1 F9917.922
G1 X135.518 Y127.217 E.01327
G1 F8722.064
G1 X135.8 Y127.5 E.01327
G1 F7603.006
G1 X136.083 Y127.783 E.01327
G1 F6560.748
G1 X136.366 Y128.066 E.01327
G1 F5595.29
G1 X136.649 Y128.348 E.01327
G1 F4706.632
G1 X136.932 Y128.631 E.01327
G1 F3894.774
G1 X137.215 Y128.914 E.01327
G1 F3159.716
G1 X137.498 Y129.197 E.01327
G1 F2501.458
G1 X137.78 Y129.48 E.01327
G1 F1920
G1 X138.051 Y129.75 E.01269
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X142.505 Y134.205 E.20898
; FEATURE: Inner wall
G1 F1800
M204 S10000
G1 X142.776 Y134.476 E.01269
G1 F2364.214
G1 X143.059 Y134.759 E.01327
G1 F3005.227
G1 X143.341 Y135.042 E.01327
G1 F3723.041
G1 X143.624 Y135.324 E.01327
G1 F4517.655
G1 X143.907 Y135.607 E.01327
G1 F5389.068
G1 X144.19 Y135.89 E.01327
G1 F6337.282
G1 X144.473 Y136.173 E.01327
G1 F7362.296
G1 X144.755 Y136.456 E.01327
G1 F8464.109
G1 X145.038 Y136.739 E.01327
G1 F9642.723
G1 X145.321 Y137.022 E.01327
G1 F10898.137
G1 X145.604 Y137.304 E.01327
G1 F12230.35
G1 X145.887 Y137.587 E.01327
G1 F13157.054
G1 X146.074 Y137.775 E.00881
G1 F14617.046
G1 X145.792 Y138.058 E.01327
G1 F15476.087
G1 X145.509 Y138.341 E.01327
G1 X144.136 Y139.714 E.06441
G1 X154.568 Y150.147 E.48942
G1 X158.17 Y146.545 E.16896
G1 X159.44 Y147.815 E.05957
G1 X154.658 Y152.596 E.22431
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.815 Y159.994 E.20963
G1 X145.991 Y158.17 E.07928
G1 X149.592 Y154.568 E.15651
G1 X139.714 Y144.69 E.42926
G1 X137.775 Y146.629 E.08425
G1 X104.414 Y113.268 E1.44971
G1 X106.353 Y111.329 E.08425
G1 X96.771 Y101.748 E.41635
G1 X101.747 Y96.771 E.21624
G1 X111.018 Y106.042 E.40286
G1 X111.329 Y106.353 E.01349
G1 X113.268 Y104.414 E.08425
G1 X113.742 Y104.888 E.02062
G1 X114.025 Y105.171 E.01229
G1 F10898.137
G1 X114.308 Y105.454 E.01229
G1 F9642.723
G1 X114.591 Y105.737 E.01229
G1 F8464.109
G1 X114.873 Y106.02 E.01229
G1 F7362.296
G1 X115.156 Y106.302 E.01229
G1 F6337.282
G1 X115.439 Y106.585 E.01229
G1 F5389.068
G1 X115.722 Y106.868 E.01229
G1 F4517.655
G1 X116.005 Y107.151 E.01229
G1 F3723.041
G1 X116.288 Y107.434 E.01229
G1 F3005.227
G1 X116.571 Y107.717 E.01229
G1 F2364.214
G1 X116.853 Y107.999 E.01229
G1 F1800
G1 X117.114 Y108.26 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X121.569 Y112.715 E.20898
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1920
G1 X121.83 Y112.976 E.01134
G1 F2501.458
G1 X122.113 Y113.259 E.01229
G1 F3159.716
G1 X122.396 Y113.541 E.01229
G1 F3894.774
G1 X122.679 Y113.824 E.01229
G1 F4706.632
G1 X122.962 Y114.107 E.01229
G1 F5595.29
G1 X123.244 Y114.39 E.01229
G1 F6560.748
G1 X123.527 Y114.673 E.01229
G1 F7603.006
G1 X123.81 Y114.956 E.01229
G1 F8722.064
G1 X124.093 Y115.238 E.01229
G1 F9917.922
G1 X124.376 Y115.521 E.01229
G1 F11190.58
G1 X124.659 Y115.804 E.01229
G1 F12000
G1 X124.942 Y116.087 E.01229
G1 X134.956 Y126.101 E.43517
G1 X135.239 Y126.384 E.01229
G1 F11190.58
G1 X135.522 Y126.667 E.01229
G1 F9917.922
G1 X135.804 Y126.949 E.01229
G1 F8722.064
G1 X136.087 Y127.232 E.01229
G1 F7603.006
G1 X136.37 Y127.515 E.01229
G1 F6560.748
G1 X136.653 Y127.798 E.01229
G1 F5595.29
G1 X136.936 Y128.081 E.01229
G1 F4706.632
G1 X137.219 Y128.364 E.01229
G1 F3894.774
G1 X137.501 Y128.646 E.01229
G1 F3159.716
G1 X137.784 Y128.929 E.01229
G1 F2501.458
G1 X138.067 Y129.212 E.01229
G1 F1920
G1 X138.328 Y129.473 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X142.782 Y133.928 E.20898
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1800
G1 X143.043 Y134.189 E.01134
G1 F2364.214
G1 X143.326 Y134.472 E.01229
G1 F3005.227
M73 P77 R4
G1 X143.609 Y134.755 E.01229
G1 F3723.041
G1 X143.892 Y135.038 E.01229
G1 F4517.655
G1 X144.175 Y135.321 E.01229
G1 F5389.068
G1 X144.457 Y135.603 E.01229
G1 F6337.282
G1 X144.74 Y135.886 E.01229
G1 F7362.296
G1 X145.023 Y136.169 E.01229
G1 F8464.109
G1 X145.306 Y136.452 E.01229
G1 F9642.723
G1 X145.589 Y136.735 E.01229
G1 F10898.137
G1 X145.872 Y137.018 E.01229
G1 F12000
G1 X146.154 Y137.301 E.01229
G1 X146.629 Y137.775 E.02062
G1 X144.69 Y139.714 E.08425
G1 X154.568 Y149.592 E.42926
G1 X158.17 Y145.991 E.15651
G1 X159.994 Y147.815 E.07928
G1 X155.213 Y152.596 E.20778
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.395 Y150.637 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X154.526 Y150.767 E.00511
G1 X154.239 Y150.555 F36000
; Slow Down Start
; LINE_WIDTH: 0.419733
G1 F3000;_EXTRUDE_SET_SPEED
G1 X153.612 Y151.137 E.02627
G1 X143.485 Y141.011 E.43975
G1 X143.151 Y140.649 E.01513
G1 X143.294 Y140.497 E.00639
; Slow Down End
; LINE_WIDTH: 0.412517
G1 F12000
G1 X143.726 Y140.042 E.0189
G1 X143.649 Y139.89 E.00513
G1 X143.76 Y139.966 E.00405
G1 X143.833 Y139.897 E.00303
G1 X144.181 Y140.314 E.01637
G1 X153.968 Y150.101 E.41684
G1 X154.383 Y150.449 E.01632
G1 X154.315 Y150.521 E.00299
G1 X154.395 Y150.637 E.00423
; Slow Down Start
; LINE_WIDTH: 0.38293
G1 F3000;_EXTRUDE_SET_SPEED
G1 X154.395 Y150.636 E0
; Slow Down End
; LINE_WIDTH: 0.39863
G1 F12000
G1 X154.292 Y150.583 E.00336
G1 X143.833 Y140.662 F36000
; LINE_WIDTH: 0.65066
G1 F10366.275
G1 X153.577 Y150.407 E.68245
G1 X143.473 Y139.714 F36000
; LINE_WIDTH: 0.38292
G1 F12000
G1 X143.607 Y139.848 E.00524
G1 X144.039 Y137.284 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X142.888 Y136.133 E.05401
G1 X139.667 Y139.354 E.1511
G3 X139.561 Y139.561 I-.188 J.035 E.00831
G1 X155.502 Y155.502 E.74783
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X154.798 Y150.41 E.07711
G3 X154.721 Y150.599 I-.133 J.056 E.00753
G1 X154.931 Y150.809 E.00988
G1 X154.568 Y151.173 E.01703
G1 X154.358 Y150.962 E.00988
G1 X153.79 Y151.529 E.02662
G1 X153.449 Y151.529 E.01131
G1 X151.984 Y150.064 E.06874
G1 X150.064 Y151.984 E.09008
G1 X146.226 Y148.146 E.18005
G1 X148.146 Y146.226 E.09008
G1 X144.308 Y142.388 E.18005
G1 X142.388 Y144.308 E.09008
G1 X141.237 Y143.157 E.05401
G1 X139.714 Y143.473 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X139.848 Y143.607 E.00524
G1 X150.797 Y153.272 F36000
; LINE_WIDTH: 0.412666
G1 F12000
G1 X151.137 Y153.62 E.01466
G1 X150.555 Y154.239 E.0256
G1 X150.637 Y154.395 E.00531
G1 X150.521 Y154.315 E.00423
G1 X150.449 Y154.383 E.00299
G1 X150.101 Y153.968 E.01633
G1 X140.314 Y144.181 E.41701
G1 X139.897 Y143.833 E.01638
G1 X139.966 Y143.76 E.00303
G1 X139.89 Y143.649 E.00405
G1 X140.042 Y143.726 E.00513
G1 X140.503 Y143.3 E.01892
; Slow Down Start
; LINE_WIDTH: 0.419978
G1 F3000;_EXTRUDE_SET_SPEED
G1 X140.67 Y143.145 E.007
G1 X150.755 Y153.229 E.43819
; Slow Down End
G1 X150.809 Y154.568 F36000
; LINE_WIDTH: 0.38292
G1 F12000
G1 X150.679 Y154.438 E.00511
G1 X140.662 Y143.833 F36000
; LINE_WIDTH: 0.65066
G1 F10366.275
G1 X150.407 Y153.578 E.68245
; WIPE_START
G1 X148.992 Y152.163 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X149.917 Y155.29 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X148.766 Y156.442 E.05401
G1 X149.543 Y157.219 E.03647
G1 X150.695 Y156.068 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X143.918 Y151.524 Z5.2 F36000
G1 X137.896 Y145.423 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38535
G1 F12000
G1 X137.775 Y145.544 E.00478
G1 X105.498 Y113.268 E1.2737
G1 X105.733 Y113.033 E.00926
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X138.01 Y145.31 E1.2737
; Slow Down End
G1 F12000
G1 X137.939 Y145.381 E.00281
G1 X136.667 Y140.561 F36000
; LINE_WIDTH: 0.53921
G1 F12000
G1 X137.119 Y141.014 E.02587
; LINE_WIDTH: 0.5605
G1 X137.207 Y141.071 E.00443
; LINE_WIDTH: 0.588874
G1 F11539.444
G1 X137.295 Y141.129 E.00467
G1 X137.47 Y141.014 E.00934
; LINE_WIDTH: 0.53921
G1 F12000
G1 X139.164 Y139.319 E.09689
; WIPE_START
G1 X137.75 Y140.734 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X136.558 Y140.319 Z5.2 F36000
G1 Z4.8
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.4693
G1 F3000
G1 X132.367 Y136.129 E.20592
G1 X132.208 Y136.086 E.00571
G1 X132.002 Y135.88 E.01012
G1 X131.96 Y135.938 E.00249
G1 X132.323 Y136.301 E.01783
G1 X132.371 Y136.481 E.00646
G1 X132.317 Y136.682 E.00723
G1 X135.574 Y139.939 E.16002
G1 X135.098 Y140.066 E.01711
G1 X132.051 Y137.019 E.14972
G1 X131.801 Y137.265 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X131.835 Y137.392 E.00436
G1 X132.893 Y138.451 E.04966
G1 X132.295 Y139.05 E.02809
G1 X136.133 Y142.888 E.18005
G1 X137.363 Y141.657 E.05772
G1 X137.124 Y141.657 E.00792
G1 X136.142 Y140.675 E.04609
; WIPE_START
G1 X137.124 Y141.657 E-.52802
G1 X137.363 Y141.657 E-.09074
G1 X137.1 Y141.92 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X132.144 Y136.116 Z5.2 F36000
G1 X131.692 Y135.586 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.5392
G1 F12000
G1 X131.242 Y135.137 E.02572
; LINE_WIDTH: 0.56051
G1 X131.185 Y135.049 E.00443
; LINE_WIDTH: 0.588897
G1 F11538.959
G1 X131.127 Y134.961 E.00467
G1 X131.242 Y134.786 E.00934
; LINE_WIDTH: 0.53922
G1 F12000
G1 X132.936 Y133.092 E.09689
G1 X135.332 Y131.045 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.45723
G1 F3000
G1 X141.091 Y136.804 E.27497
G1 X141.384 Y136.511 E.01399
G1 X135.745 Y130.872 E.26924
G1 X136.038 Y130.579 E.01399
G1 X141.677 Y136.218 E.26924
G1 X141.97 Y135.925 E.01399
G1 X136.331 Y130.286 E.26924
G1 X136.624 Y129.993 E.01399
G1 X142.263 Y135.632 E.26924
G1 X142.459 Y135.436 E.00936
G1 X142.652 Y135.436 E.00654
G1 X136.82 Y129.603 E.27851
G1 X136.82 Y129.51 E.00313
G1 X136.553 Y129.243 E.01272
G1 X136.8 Y128.997 E.01177
G1 X143.378 Y135.576 E.31412
G1 X145.423 Y137.896 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38539
G1 F12000
G1 X145.31 Y138.01 E.00449
; Slow Down Start
; LINE_WIDTH: 0.38544
G1 F3000;_EXTRUDE_SET_SPEED
G1 X143.262 Y135.962 E.08083
; Slow Down End
; LINE_WIDTH: 0.385436
G1 F12000
G1 X143.497 Y135.727 E.00927
G1 X145.544 Y137.775 E.08083
G1 X145.466 Y137.854 E.0031
; WIPE_START
G1 X145.544 Y137.775 E-.04227
G1 X144.209 Y136.439 E-.71773
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.2 I.861 J-.861 P1  F36000
G1 X122.284 Y114.514 Z5.2
G1 Z4.8
G1 E.8 F1800
; LINE_WIDTH: 0.385747
G1 F12000
G1 X136.529 Y128.759 E.56279
G1 X136.294 Y128.994 E.00929
; Slow Down Start
; LINE_WIDTH: 0.385744
G1 F3000;_EXTRUDE_SET_SPEED
G1 X122.049 Y114.749 E.56278
; Slow Down End
; LINE_WIDTH: 0.38564
G1 F12000
G1 X122.241 Y114.556 E.00761
G1 X122.165 Y114.363 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.45718
G1 F3000
G1 X115.586 Y107.784 E.31408
G1 X115.34 Y108.03 E.01175
G1 X115.606 Y108.297 E.01271
G1 X115.606 Y108.39 E.00317
G1 X121.44 Y114.223 E.27846
G1 X121.245 Y114.223 E.00655
G1 X121.05 Y114.419 E.00935
G1 X115.41 Y108.78 E.26921
G1 X115.117 Y109.073 E.01398
G1 X120.757 Y114.712 E.26921
G1 X120.464 Y115.005 E.01398
G1 X114.824 Y109.366 E.26921
G1 X114.531 Y109.659 E.01398
G1 X120.171 Y115.298 E.26921
G1 X119.878 Y115.591 E.01398
G1 X114.119 Y109.832 E.27494
G1 X115.194 Y107.667 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.385414
G1 F12000
G1 X115.315 Y107.546 E.00478
G1 X113.268 Y105.498 E.08083
G1 X113.025 Y105.74 E.00956
G1 X115.073 Y107.788 E.08083
G1 X115.152 Y107.71 E.00311
G1 X111.156 Y107.397 F36000
; LINE_WIDTH: 0.38292
G1 F12000
G1 X111.286 Y107.527 E.00511
G1 X111.156 Y107.397 F36000
; Slow Down Start
; LINE_WIDTH: 0.416894
G1 F3000;_EXTRUDE_SET_SPEED
G1 X111 Y107.316 E.00537
G1 X110.372 Y107.898 E.02607
G1 X101.141 Y98.671 E.39776
G1 X100.897 Y98.689 E.00744
G2 X101.21 Y98.414 I-1.606 J-2.14 E.01272
; Slow Down End
; LINE_WIDTH: 0.413506
G1 F12000
G1 X101.747 Y97.88 E.02287
G1 X110.729 Y106.861 E.38355
G1 X111.144 Y107.209 E.01636
G1 X111.076 Y107.282 E.003
G1 X111.122 Y107.348 E.00243
G1 X107.57 Y111.329 F36000
; LINE_WIDTH: 0.38292
G1 F12000
G1 X107.439 Y111.198 E.00511
G1 X98.67 Y100.918 F36000
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X100.855 Y98.732 E.08562
; Slow Down End
G1 X101.747 Y98.577 F36000
; LINE_WIDTH: 0.65068
G1 F10365.934
G1 X110.338 Y107.167 E.60166
G1 X107.282 Y111.076 F36000
; LINE_WIDTH: 0.418236
G1 F12000
G1 X107.209 Y111.144 E.00304
G1 X106.861 Y110.729 E.01657
G1 X97.88 Y101.748 E.38844
G2 X98.67 Y100.918 I-11.813 J-12.038 E.03506
; Slow Down Start
; LINE_WIDTH: 0.418405
G1 F3000;_EXTRUDE_SET_SPEED
G1 X98.672 Y101.14 E.00679
G1 X107.558 Y110.032 E.38465
G1 X107.892 Y110.394 E.01508
G1 X107.316 Y111 E.02557
G1 X107.397 Y111.156 E.00539
; Slow Down End
; LINE_WIDTH: 0.394958
G1 F12000
G1 X107.331 Y111.11 E.0023
G1 X107.209 Y110.38 F36000
; LINE_WIDTH: 0.65067
G1 F10366.104
G1 X98.619 Y101.79 E.60165
G1 X101.322 Y103.242 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X100.17 Y102.09 E.05401
G1 X102.09 Y100.17 E.09008
G1 X101.01 Y99.09 E.0507
G1 X100.05 Y100.05 E.04504
G1 X111.481 Y111.481 E.53629
G1 X109.385 Y113.578 E.09833
G1 X109.385 Y113.919 E.01131
G1 X110.378 Y114.911 E.04655
G1 X109.267 Y116.022 E.05212
G1 X113.105 Y119.86 E.18005
G1 X113.734 Y119.23 E.02953
G1 X113.863 Y119.265 E.00443
G1 X114.548 Y119.081 E.02352
G1 X115.911 Y120.444 E.06394
G1 X116.252 Y120.444 E.01131
G1 X118.348 Y118.348 E.09833
G1 X132.695 Y132.695 E.67303
G3 X133.407 Y132.767 I.321 J.382 E.02649
G1 X134.732 Y131.443 E.06215
G1 X134.732 Y131.33 E.00372
G1 X136.409 Y129.653 E.07867
G1 X135.212 Y128.457 E.05615
G1 X128.457 Y135.212 E.31689
G1 X124.619 Y131.374 E.18005
G1 X131.374 Y124.619 E.31689
G1 X127.536 Y120.781 E.18005
G1 X120.781 Y127.536 E.31689
G1 X116.943 Y123.698 E.18005
G1 X123.698 Y116.943 E.31689
M73 P78 R4
G1 X122.546 Y115.791 E.05401
; WIPE_START
G1 X123.698 Y116.943 E-.61876
G1 X123.435 Y117.206 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X116.005 Y118.951 Z5.2 F36000
G1 X115.344 Y119.106 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.4693
G1 F3000
G1 X111.154 Y114.915 E.20592
G1 X110.995 Y114.873 E.00571
G1 X110.789 Y114.667 E.01013
G1 X110.747 Y114.725 E.00249
G1 X111.11 Y115.088 E.01783
G1 X111.158 Y115.268 E.00646
G1 X111.104 Y115.469 E.00723
G1 X114.361 Y118.725 E.16002
G1 X113.885 Y118.853 E.01711
G1 X110.838 Y115.806 E.14972
G1 X110.479 Y114.373 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53922
G1 F12000
G1 X110.029 Y113.923 E.02572
; LINE_WIDTH: 0.56051
G1 X109.971 Y113.836 E.00443
; LINE_WIDTH: 0.588897
G1 F11538.952
G1 X109.914 Y113.748 E.00467
G1 X110.029 Y113.573 E.00934
; LINE_WIDTH: 0.53921
G1 F12000
G1 X111.723 Y111.878 E.09689
G1 X107.08 Y105.16 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.928 Y104.008 E.05401
G1 X104.008 Y105.928 E.09008
G1 X107.846 Y109.766 E.18005
G1 X109.766 Y107.846 E.09008
G1 X110.21 Y108.29 E.02081
G1 X110.551 Y108.29 E.01131
G1 X111.018 Y107.823 E.0219
; WIPE_START
G1 X110.551 Y108.29 E-.25085
G1 X110.21 Y108.29 E-.12957
G1 X109.766 Y107.846 E-.23834
G1 X109.504 Y108.109 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X113.075 Y114.855 Z5.2 F36000
G1 X115.454 Y119.348 Z5.2
G1 Z4.8
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53921
G1 F12000
G1 X115.906 Y119.8 E.02587
; LINE_WIDTH: 0.56051
G1 X115.994 Y119.858 E.00443
; LINE_WIDTH: 0.588897
G1 F11538.959
G1 X116.081 Y119.916 E.00467
G1 X116.257 Y119.8 E.00934
; LINE_WIDTH: 0.53921
G1 F12000
G1 X117.951 Y118.106 E.09689
; CHANGE_LAYER
; Z_HEIGHT: 5
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X116.537 Y119.52 E-.76
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
G1 X132.872 Y136.128
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F2531.886
G1 X133.169 Y135.831 E.01392
G1 F1920
G1 X133.439 Y135.561 E.01269
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X134.5 Y134.5 E.04976

G1 X135.561 Y133.439 E.04976
; FEATURE: Inner wall
G1 F1920
M204 S10000
G1 X135.831 Y133.169 E.01269
G1 F2531.886
G1 X136.128 Y132.872 E.01392
G1 F3193.902
G1 X136.411 Y133.155 E.01327
G1 F3932.719
G1 X136.694 Y133.438 E.01327
G1 F4748.336
G1 X136.976 Y133.721 E.01327
G1 F5640.752
G1 X137.259 Y134.004 E.01327
G1 F6609.969
G1 X137.542 Y134.287 E.01327
G1 F7392.778
G1 X137.825 Y134.569 E.01327
G1 F7134.236
G1 X137.969 Y134.714 E.00677
G1 F6609.969
G1 X138.252 Y134.997 E.01327
G1 F5640.752
G1 X138.535 Y135.279 E.01327
G1 F4748.336
G1 X138.818 Y135.562 E.01327
G1 F3932.719
G1 X139.101 Y135.845 E.01327
G1 F3193.902
G1 X139.384 Y136.128 E.01327
G1 F2531.886
G1 X139.087 Y136.425 E.01392
G1 F1920
G1 X138.816 Y136.695 E.01269
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X136.695 Y138.816 E.09952
; FEATURE: Inner wall
G1 F1920
M204 S10000
G1 X136.425 Y139.087 E.01269
G1 F2531.886
G1 X136.128 Y139.384 E.01392
G1 F3193.902
G1 X135.845 Y139.101 E.01327
G1 F3932.719
G1 X135.562 Y138.818 E.01327
G1 F4748.336
G1 X135.279 Y138.535 E.01327
G1 F5640.752
G1 X134.997 Y138.252 E.01327
G1 F6609.969
G1 X134.714 Y137.969 E.01327
G1 F7655.985
G1 X134.431 Y137.687 E.01327
G1 F8778.802
G1 X134.148 Y137.404 E.01327
G1 F9978.418
G1 X133.865 Y137.121 E.01327
G1 F11254.835
G1 X133.582 Y136.838 E.01327
G1 F12608.052
G1 X133.3 Y136.555 E.01327
G1 F14572.187
G1 X132.915 Y136.17 E.01805
G1 X133.427 Y136.128 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1976.064
M204 S6000
G1 X133.456 Y136.099 E.00126
G1 F1920
G1 X133.717 Y135.838 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X134.777 Y134.777 E.04976

G1 X135.838 Y133.717 E.04976
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1920
G1 X136.099 Y133.456 E.01134
G1 F1976.064
G1 X136.128 Y133.427 E.00126
G1 F2565.394
G1 X136.411 Y133.71 E.01229
G1 F3231.523
G1 X136.694 Y133.992 E.01229
G1 F3974.453
G1 X136.976 Y134.275 E.01229
G1 F4794.183
G1 X137.259 Y134.558 E.01229
G1 F5482.284
G1 X137.542 Y134.841 E.01229
G1 F5277.788
G1 X137.698 Y134.997 E.00676
G1 F4794.183
G1 X137.981 Y135.279 E.01229
G1 F3974.453
G1 X138.263 Y135.562 E.01229
G1 F3231.523
G1 X138.546 Y135.845 E.01229
G1 F2565.394
G1 X138.829 Y136.128 E.01229
G1 F1976.064
G1 X138.8 Y136.157 E.00126
G1 F1920
G1 X138.539 Y136.418 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X136.418 Y138.539 E.09952
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1920
G1 X136.157 Y138.8 E.01134
G1 F1976.064
G1 X136.128 Y138.829 E.00126
G1 F2565.394
G1 X135.845 Y138.546 E.01229
G1 F3231.523
G1 X135.562 Y138.263 E.01229
G1 F3974.453
G1 X135.279 Y137.981 E.01229
G1 F4794.183
G1 X134.997 Y137.698 E.01229
G1 F5690.712
G1 X134.714 Y137.415 E.01229
G1 F6664.042
G1 X134.431 Y137.132 E.01229
G1 F7714.172
G1 X134.148 Y136.849 E.01229
G1 F8841.101
G1 X133.865 Y136.566 E.01229
G1 F10547.82
G1 X133.469 Y136.17 E.01721
; WIPE_START
M204 S10000
G1 X133.456 Y136.099 E-.02761
G1 X133.717 Y135.838 E-.14022
G1 X134.777 Y134.777 E-.57
G1 X134.819 Y134.736 E-.02217
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.4 I.79 J-.925 P1  F36000
G1 X111.936 Y115.192 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F3180.068
G1 X111.659 Y114.915 E.01301
G1 F2531.886
G1 X111.956 Y114.618 E.01392
G1 F1920
G1 X112.226 Y114.348 E.01269
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X114.348 Y112.226 E.09952
; FEATURE: Inner wall
G1 F1920
M204 S10000
G1 X114.618 Y111.956 E.01269
G1 F2531.886
G1 X114.915 Y111.659 E.01392
G1 F3193.902
G1 X115.198 Y111.942 E.01327
G1 F3932.719
G1 X115.48 Y112.225 E.01327
G1 F4748.336
G1 X115.763 Y112.508 E.01327
G1 F5640.752
G1 X116.046 Y112.79 E.01327
G1 F6609.969
G1 X116.329 Y113.073 E.01327
G1 F7392.797
G1 X116.612 Y113.356 E.01327
G1 F7134.273
G1 X116.756 Y113.501 E.00677
G1 F6609.969
G1 X117.039 Y113.783 E.01327
G1 F5640.752
G1 X117.322 Y114.066 E.01327
G1 F4748.336
G1 X117.605 Y114.349 E.01327
G1 F3932.719
G1 X117.888 Y114.632 E.01327
G1 F3193.902
G1 X118.17 Y114.915 E.01327
G1 F2531.886
G1 X117.874 Y115.211 E.01392
G1 F1920
G1 X117.603 Y115.482 E.01269
; FEATURE: Overhang wall
G1 F3000
M204 S6000
G1 X115.482 Y117.603 E.09952
; FEATURE: Inner wall
G1 F1920
M204 S10000
G1 X115.211 Y117.874 E.01269
G1 F2531.886
G1 X114.915 Y118.17 E.01392
G1 F3193.902
G1 X114.632 Y117.888 E.01327
G1 F3932.719
G1 X114.349 Y117.605 E.01327
G1 F4748.336
G1 X114.066 Y117.322 E.01327
G1 F5640.752
G1 X113.783 Y117.039 E.01327
G1 F6609.969
G1 X113.501 Y116.756 E.01327
G1 F7655.985
G1 X113.218 Y116.473 E.01327
G1 F8778.802
G1 X112.935 Y116.19 E.01327
G1 F9978.418
G1 X112.652 Y115.908 E.01327
G1 F11254.835
G1 X112.369 Y115.625 E.01327
G1 F13142.575
G1 X111.979 Y115.234 E.01831
G1 X112.214 Y114.915 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1976.064
M204 S6000
G1 X112.243 Y114.886 E.00126
G1 F1920
G1 X112.503 Y114.625 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X114.625 Y112.504 E.09952
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1920
G1 X114.886 Y112.243 E.01134
G1 F1976.064
G1 X114.915 Y112.214 E.00126
G1 F2565.394
G1 X115.198 Y112.496 E.01229
G1 F3231.523
G1 X115.48 Y112.779 E.01229
G1 F3974.453
G1 X115.763 Y113.062 E.01229
G1 F4794.183
G1 X116.046 Y113.345 E.01229
G1 F5482.284
G1 X116.329 Y113.628 E.01229
G1 F5277.788
G1 X116.485 Y113.783 E.00676
G1 F4794.183
G1 X116.767 Y114.066 E.01229
G1 F3974.453
G1 X117.05 Y114.349 E.01229
G1 F3231.523
G1 X117.333 Y114.632 E.01229
G1 F2565.394
G1 X117.616 Y114.915 E.01229
G1 F1976.064
G1 X117.587 Y114.944 E.00126
G1 F1920
G1 X117.326 Y115.205 E.01134
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45
G1 F3000
G1 X115.205 Y117.326 E.09952
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1920
G1 X114.944 Y117.587 E.01134
G1 F1976.064
G1 X114.915 Y117.616 E.00126
G1 F2565.394
G1 X114.632 Y117.333 E.01229
G1 F3231.523
G1 X114.349 Y117.05 E.01229
G1 F3974.453
G1 X114.066 Y116.767 E.01229
G1 F4794.183
G1 X113.783 Y116.485 E.01229
G1 F5690.712
G1 X113.501 Y116.202 E.01229
G1 F6664.042
G1 X113.218 Y115.919 E.01229
G1 F7714.172
G1 X112.935 Y115.636 E.01229
G1 F8841.101
G1 X112.652 Y115.353 E.01229
G1 F10547.775
G1 X112.256 Y114.957 E.01721
; WIPE_START
M204 S10000
G1 X112.243 Y114.886 E-.02762
G1 X112.503 Y114.625 E-.14022
G1 X113.605 Y113.523 E-.59217
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.4 I-.84 J.881 P1  F36000
G1 X154.616 Y152.639 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.89 Y159.365 E.2228
G1 X146.62 Y158.095 E.05957
G1 X150.338 Y154.377 E.17445
G1 X139.905 Y143.944 E.48942
G1 X137.882 Y145.968 E.09493
G1 X105.075 Y113.161 E1.53904
G1 X107.099 Y111.137 E.09493
G1 X97.517 Y101.556 E.44948
G1 X101.556 Y97.517 E.18946
G1 X111.137 Y107.099 E.44948
G1 X113.161 Y105.075 E.09493
G1 X145.968 Y137.882 E1.53904
G1 X143.944 Y139.905 E.09493
G1 X154.377 Y150.338 E.48942
G1 X158.095 Y146.62 E.17445
M73 P78 R3
G1 X159.365 Y147.89 E.05957
G1 X154.658 Y152.596 E.22081
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.89 Y159.92 E.20638
G1 X146.065 Y158.095 E.07928
G1 X149.784 Y154.377 E.16159
G1 X139.905 Y144.498 E.42926
G1 X137.882 Y146.522 E.08793
G1 X104.521 Y113.161 E1.44971
G1 X106.544 Y111.137 E.08793
G1 X96.963 Y101.556 E.41635
G1 X101.556 Y96.963 E.19959
G1 X111.137 Y106.544 E.41635
G1 X113.161 Y104.521 E.08793
G1 X131.274 Y122.634 E.78713
G1 X146.522 Y137.882 E.66258
G1 X144.498 Y139.905 E.08793
G1 X154.377 Y149.784 E.42926
G1 X158.095 Y146.065 E.16159
G1 X159.92 Y147.89 E.07928
G1 X155.213 Y152.596 E.20454
M204 S10000
G1 X154.453 Y152.968 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.604 Y154.12 E.05401
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X153.029 Y153.029 E.11602
G1 X155.09 Y150.968 E.09668
G1 X155.057 Y150.935 E.00155
G1 X155.378 Y150.614 E.01506
G2 X155.156 Y150.051 I-.393 J-.17 E.0223
G1 X156.442 Y148.766 E.06031
G1 X157.219 Y149.543 E.03647
G1 X156.068 Y150.695 E.05401
G1 X154.769 Y150.585 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53922
G1 F12000
G1 X154.867 Y150.486 E.00562
; WIPE_START
G1 X154.769 Y150.585 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X149.185 Y145.382 Z5.4 F36000
G1 X144.119 Y140.662 Z5.4
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.4586
G1 F12000
G1 X153.577 Y150.121 E.45309
; WIPE_START
G1 X152.163 Y148.707 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X146.993 Y143.092 Z5.4 F36000
G1 X143.698 Y139.513 Z5.4
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.5392
G1 F12000
G1 X143.796 Y139.415 E.00562
G1 X142.278 Y139.976 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.127 Y141.127 E.05401
G1 X139.561 Y139.561 E.07345
G2 X139.667 Y139.354 I-.083 J-.173 E.00831
G1 X142.747 Y136.273 E.14452
G1 X143.899 Y137.424 E.05401
G1 X145.291 Y138.011 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.413447
G1 F12000
G1 X145.421 Y137.882 E.00553
G2 X142.263 Y134.732 I-264.928 J262.423 E.13466
G1 X121.703 Y114.164 E.87809
G3 X115.666 Y108.127 I1168.883 J-1174.92 E.25778
G1 X113.161 Y105.622 E.10696
G1 X112.902 Y105.881 E.01105
G1 X115.407 Y108.386 E.10696
G3 X115.411 Y108.779 I-.313 J.2 E.01253
G1 X114.311 Y109.879 E.04696
G1 X114.477 Y109.941 E.00536
G1 X114.821 Y110.166 E.01239
G1 X115.514 Y110.855 E.02951
G1 X115.707 Y111.254 E.01337
G1 X115.716 Y111.604 E.01057
G1 X115.627 Y111.817 E.00699
G1 X118.008 Y114.198 E.10165
G1 X118.307 Y114.102 E.00948
G1 X118.645 Y114.141 E.01027
G1 X118.974 Y114.315 E.01125
G1 X119.627 Y114.968 E.02789
G1 X119.884 Y115.343 E.01371
G1 X119.947 Y115.522 E.00572
G1 X121.05 Y114.419 E.04709
G1 X121.183 Y114.364 E.00436
G1 X121.42 Y114.401 E.00724
G1 X136.62 Y129.599 E.64898
G3 X136.624 Y129.993 I-.313 J.2 E.01253
G1 X135.524 Y131.092 E.04696
G1 X135.691 Y131.154 E.00536
G1 X136.034 Y131.379 E.01239
G1 X136.727 Y132.068 E.02951
G1 X136.92 Y132.467 E.01337
G1 X136.929 Y132.817 E.01057
G1 X136.841 Y133.031 E.00699
G1 X139.221 Y135.411 E.10165
G1 X139.52 Y135.315 E.00948
G1 X139.858 Y135.355 E.01027
G1 X140.188 Y135.529 E.01125
G1 X140.841 Y136.182 E.02789
G1 X141.098 Y136.557 E.01372
G1 X141.16 Y136.735 E.0057
G1 X142.263 Y135.632 E.04709
G1 X142.397 Y135.577 E.00436
G1 X142.634 Y135.614 E.00724
G1 X145.162 Y138.141 E.10792
G1 X145.249 Y138.054 E.00372
G1 X142.256 Y135.258 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X136.998 Y130 E.22848
G1 X136.891 Y130.259 E.00862
G1 X136.15 Y131 E.0322
G3 X136.994 Y131.802 I-9.056 J10.385 E.03578
G1 X137.239 Y132.231 E.01519
G1 X137.317 Y132.707 E.01482
G1 X137.283 Y132.94 E.00724
G1 X139.317 Y134.973 E.08836
G1 X139.607 Y134.944 E.00895
G1 X140.025 Y135.017 E.01305
G1 X140.454 Y135.262 E.01519
G1 X141.107 Y135.915 E.02838
G1 X141.253 Y136.109 E.00745
G1 X141.997 Y135.365 E.0323
G1 X142.2 Y135.281 E.00678
G1 X141.595 Y135.182 F36000
; LINE_WIDTH: 0.492805
G1 F12000
G1 X141.065 Y134.651 E.02751
; LINE_WIDTH: 0.474605
G1 X140.827 Y134.388 E.01248
; LINE_WIDTH: 0.42316
G1 X140.589 Y134.125 E.01099
G1 X138.123 Y131.674 E.10772
; LINE_WIDTH: 0.46292
G1 X137.998 Y131.579 E.00539
; LINE_WIDTH: 0.501042
G1 X137.873 Y131.483 E.00588
G2 X137.074 Y130.661 I-24.091 J22.629 E.04281
G1 X136.755 Y130.98 E.01684
G1 X137.284 Y131.507 E.0279
G1 X137.486 Y131.761 E.01209
; LINE_WIDTH: 0.50789
G1 X137.548 Y131.977 E.00852
; LINE_WIDTH: 0.47273
G1 X137.61 Y132.193 E.00788
; LINE_WIDTH: 0.424394
G1 X137.672 Y132.409 E.00699
G1 X137.675 Y132.799 E.01211
G1 X139.458 Y134.581 E.07835
G1 X139.847 Y134.584 E.0121
G1 X140.481 Y134.797 E.02082
; LINE_WIDTH: 0.493936
G1 X140.619 Y134.857 E.00551
G3 X141.277 Y135.5 I-21.489 J22.63 E.03382
G1 X141.553 Y135.224 E.01433
G1 X140.246 Y134.312 F36000
; LINE_WIDTH: 0.415865
G1 F12000
G1 X137.944 Y132.01 E.09892
G3 X138.075 Y132.668 I-1.903 J.721 E.0205
G1 X139.598 Y134.191 E.06542
G3 X140.188 Y134.296 I.034 J1.521 E.01835
G1 X121.043 Y114.045 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X115.785 Y108.787 E.22848
G1 X115.677 Y109.046 E.00862
G1 X114.936 Y109.787 E.0322
G3 X115.781 Y110.588 I-9.054 J10.382 E.03578
G1 X116.026 Y111.018 E.01519
G1 X116.104 Y111.494 E.01482
G1 X116.07 Y111.727 E.00724
G1 X118.104 Y113.76 E.08836
G1 X118.393 Y113.73 E.00895
G1 X118.812 Y113.803 E.01305
G1 X119.241 Y114.049 E.01519
G1 X119.894 Y114.702 E.02838
G1 X120.04 Y114.896 E.00746
G1 X120.783 Y114.152 E.0323
G1 X120.987 Y114.068 E.00678
G1 X120.382 Y113.969 F36000
; LINE_WIDTH: 0.492835
G1 F12000
G1 X119.851 Y113.438 E.02751
; LINE_WIDTH: 0.47462
G1 X119.614 Y113.175 E.01248
; LINE_WIDTH: 0.423161
G1 X119.376 Y112.911 E.01099
G1 X116.91 Y110.461 E.10771
; LINE_WIDTH: 0.462918
G1 X116.785 Y110.366 E.00539
; LINE_WIDTH: 0.501034
G1 X116.66 Y110.27 E.00588
G2 X115.861 Y109.448 I-24.101 J22.639 E.0428
G1 X115.542 Y109.767 E.01684
G1 X116.071 Y110.294 E.0279
G1 X116.273 Y110.547 E.01209
; LINE_WIDTH: 0.507882
G1 X116.335 Y110.764 E.00852
; LINE_WIDTH: 0.472725
G1 X116.397 Y110.98 E.00788
; LINE_WIDTH: 0.424391
G1 X116.459 Y111.196 E.00699
G1 X116.462 Y111.586 E.01211
G1 X118.244 Y113.368 E.07834
G1 X118.633 Y113.371 E.0121
G1 X119.268 Y113.584 E.02081
; LINE_WIDTH: 0.493963
G1 X119.406 Y113.643 E.00551
G3 X120.064 Y114.287 I-21.537 J22.679 E.03383
G1 X120.34 Y114.011 E.01433
G1 X119.033 Y113.098 F36000
; LINE_WIDTH: 0.415865
G1 F12000
G1 X116.731 Y110.797 E.09892
G3 X116.862 Y111.455 I-1.902 J.721 E.0205
G1 X118.384 Y112.977 E.06542
G3 X118.975 Y113.082 I.034 J1.521 E.01835
G1 X118.808 Y114.449 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.44802
G1 F3000
G1 X118.492 Y114.765 E.01475
G1 X118.641 Y114.915 E.00698
G1 X114.915 Y118.642 E.17398
G1 X114.765 Y118.492 E.00698
G1 X114.58 Y118.677 E.00863
G1 X114.741 Y118.72 E.00549
G1 X114.926 Y118.904 E.00862
G1 X118.978 Y114.852 E.18917
G1 X119.264 Y115.139 E.01337
G1 X115.212 Y119.191 E.18917
G1 X115.499 Y119.477 E.01337
G1 X119.52 Y115.456 E.18773
G1 X119.663 Y115.806 E.01247
G1 X117.931 Y117.538 E.08085
G1 X117.919 Y117.63 E.00307
G1 X115.871 Y119.678 E.0956
G1 X116.033 Y119.702 E.00539
G1 X116.187 Y119.696 E.0051
G1 X116.355 Y119.664 E.00564
G1 X116.516 Y119.605 E.00566
G1 X118.189 Y117.932 E.0781
; WIPE_START
G1 X116.775 Y119.346 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X114.202 Y118.768 Z5.4 F36000
G1 Z5
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X114.123 Y118.576 E.0064
G1 X114.114 Y118.226 E.01075
G1 X114.202 Y118.012 E.00711
G1 X111.828 Y115.638 E.10317
G1 X111.672 Y115.7 E.00514
G1 X111.276 Y115.706 E.01219
G1 X111.06 Y115.633 E.007
G1 X110.977 Y115.98 E.01096
G1 X113.853 Y118.856 E.12498
G1 X114.144 Y118.783 E.00922
G1 X111.713 Y116.12 F36000
; LINE_WIDTH: 0.50935
G1 F12000
G1 X113.664 Y118.071 E.10487
G1 X111.022 Y115.38 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.44799
G1 F3000
G1 X111.337 Y115.064 E.01474
G1 X111.188 Y114.915 E.00698
G1 X114.915 Y111.188 E.17397
G1 X115.064 Y111.337 E.00698
G1 X115.258 Y111.144 E.00903
G1 X114.977 Y110.852 E.01337
G1 X110.925 Y114.904 E.18915
G1 X110.639 Y114.617 E.01337
G1 X114.691 Y110.565 E.18915
G1 X114.529 Y110.413 E.00734
G1 X114.373 Y110.31 E.00616
G1 X110.352 Y114.331 E.18771
G3 X110.152 Y113.958 I.407 J-.459 E.01425
G1 X112.2 Y111.911 E.09559
G1 X112.058 Y111.929 E.0047
G1 X111.773 Y111.764 E.01088
G1 X109.974 Y113.564 E.08398
G1 X107.761 Y111.563 F36000
; LINE_WIDTH: 0.4
; LAYER_HEIGHT: 0.4
G1 F3000
M73 P79 R3
G1 X111.42 Y107.904 E.26493
G1 X111.102 Y107.586 E.02304
G1 X107.586 Y111.102 E.25456
G1 X107.268 Y110.784 E.02304
G1 X110.784 Y107.268 E.25456
G1 X110.716 Y107.2 E.00491
G1 X110.38 Y107.536 E.02429
G1 X110.13 Y107.285 E.01813
G1 X107.285 Y110.13 E.20597
G1 X106.967 Y109.812 E.02304
G1 X109.812 Y106.967 E.20597
G1 X109.494 Y106.649 E.02304
G1 X106.649 Y109.494 E.20597
G1 X106.331 Y109.175 E.02304
G1 X109.175 Y106.331 E.20597
G1 X108.857 Y106.013 E.02304
G1 X106.013 Y108.857 E.20597
G1 X105.694 Y108.539 E.02304
G1 X108.539 Y105.694 E.20597
G1 X108.221 Y105.376 E.02304
G1 X105.376 Y108.221 E.20597
G1 X105.058 Y107.903 E.02304
G1 X107.903 Y105.058 E.20597
G1 X107.584 Y104.74 E.02304
G1 X104.74 Y107.584 E.20597
G1 X104.422 Y107.266 E.02304
G1 X107.266 Y104.422 E.20597
G1 X106.948 Y104.103 E.02304
G1 X104.103 Y106.948 E.20597
G1 X103.785 Y106.63 E.02304
G1 X106.63 Y103.785 E.20597
G1 X106.312 Y103.467 E.02304
G1 X103.467 Y106.312 E.20597
G1 X103.149 Y105.993 E.02304
G1 X105.993 Y103.149 E.20597
G1 X105.675 Y102.831 E.02304
G1 X102.831 Y105.675 E.20597
G1 X102.512 Y105.357 E.02304
G1 X105.357 Y102.512 E.20597
G1 X105.039 Y102.194 E.02304
G1 X102.194 Y105.039 E.20597
G1 X101.876 Y104.721 E.02304
G1 X104.721 Y101.876 E.20597
G1 X104.402 Y101.558 E.02304
G1 X101.558 Y104.402 E.20597
G1 X101.24 Y104.084 E.02304
G1 X104.084 Y101.24 E.20597
G1 X103.766 Y100.921 E.02304
G1 X100.921 Y103.766 E.20597
G1 X100.603 Y103.448 E.02304
G1 X103.448 Y100.603 E.20597
G1 X103.13 Y100.285 E.02304
G1 X100.285 Y103.13 E.20597
G1 X99.967 Y102.811 E.02304
G1 X102.811 Y99.967 E.20597
G1 X102.493 Y99.649 E.02304
G1 X99.649 Y102.493 E.20597
G1 X99.33 Y102.175 E.02304
G1 X102.175 Y99.33 E.20597
G1 X101.857 Y99.012 E.02304
G1 X99.012 Y101.857 E.20597
G1 X98.694 Y101.539 E.02304
G1 X101.539 Y98.694 E.20597
G1 X101.22 Y98.376 E.02304
G1 X98.233 Y101.364 E.21634
G1 X101.556 Y98.099 F36000
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.45863
; LAYER_HEIGHT: 0.2
G1 F15000
G1 X110.338 Y106.881 E.42072
G1 X111.53 Y107.345 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53922
G1 F12000
G1 X111.628 Y107.247 E.00562
G1 X111.117 Y108.814 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X109.965 Y109.965 E.05401
G1 X111.481 Y111.481 E.07112
G1 X109.385 Y113.578 E.09833
G1 X109.385 Y113.919 E.01131
G1 X110.378 Y114.911 E.04655
G1 X109.407 Y115.882 E.04554
G1 X113.245 Y119.72 E.18005
G1 X113.734 Y119.23 E.02295
G1 X113.863 Y119.265 E.00443
G1 X114.548 Y119.081 E.02352
G1 X115.911 Y120.444 E.06393
G1 X116.252 Y120.444 E.01131
G1 X118.348 Y118.348 E.09833
G1 X132.695 Y132.695 E.67303
G1 X130.599 Y134.791 E.09833
G1 X130.599 Y135.132 E.01131
G1 X131.961 Y136.495 E.06394
G1 X131.778 Y137.179 E.02352
G1 X131.835 Y137.392 E.00732
G1 X132.893 Y138.451 E.04966
G1 X132.435 Y138.909 E.02151
G1 X136.273 Y142.747 E.18005
G1 X137.363 Y141.657 E.05114
G1 X137.124 Y141.657 E.00792
G1 X136.142 Y140.675 E.04609
G1 X135.416 Y139.981 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X135.336 Y139.789 E.0064
G1 X135.327 Y139.439 E.01075
G1 X135.415 Y139.225 E.00711
G1 X133.041 Y136.851 E.10317
G1 X132.885 Y136.913 E.00514
G1 X132.489 Y136.919 E.01219
G1 X132.273 Y136.846 E.007
G1 X132.19 Y137.193 E.01096
G1 X135.066 Y140.069 E.12498
G1 X135.357 Y139.996 E.00922
G1 X132.926 Y137.333 F36000
; LINE_WIDTH: 0.50932
G1 F12000
G1 X134.877 Y139.284 E.10487
G1 X132.235 Y136.593 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.44799
G1 F3000
G1 X132.551 Y136.278 E.01474
G1 X132.401 Y136.128 E.00698
G1 X132.962 Y135.567 E.0262
G1 X136.128 Y132.401 E.14777
G1 X136.277 Y132.551 E.00698
G1 X136.471 Y132.357 E.00903
G1 X136.19 Y132.065 E.01337
G1 X132.138 Y136.117 E.18915
G1 X131.852 Y135.83 E.01337
G1 X135.904 Y131.778 E.18915
G1 X135.742 Y131.626 E.00734
G1 X135.587 Y131.523 E.00616
G1 X131.566 Y135.544 E.1877
G3 X131.365 Y135.171 I.407 J-.459 E.01425
G1 X133.413 Y133.124 E.09559
G1 X133.272 Y133.142 E.0047
G1 X132.986 Y132.978 E.01088
G1 X131.187 Y134.777 E.08399
; WIPE_START
G1 X132.601 Y133.362 E-.76
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.4 I-.36 J1.162 P1  F36000
G1 X140.021 Y135.662 Z5.4
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.44802
G1 F3000
G1 X139.705 Y135.978 E.01475
G1 X139.855 Y136.128 E.00698
G1 X139.293 Y136.689 E.0262
G1 X136.128 Y139.855 E.14778
G1 X135.978 Y139.705 E.00698
G1 X135.794 Y139.89 E.00863
G1 X135.954 Y139.933 E.00549
G1 X136.139 Y140.117 E.00862
G1 X140.191 Y136.065 E.18917
G1 X140.478 Y136.352 E.01337
G1 X136.425 Y140.404 E.18917
G1 X136.712 Y140.69 E.01337
G1 X140.733 Y136.669 E.18773
G1 X140.876 Y137.019 E.01247
G1 X139.144 Y138.751 E.08085
G1 X139.132 Y138.843 E.00307
G1 X137.084 Y140.891 E.0956
G1 X137.246 Y140.915 E.0054
G1 X137.401 Y140.909 E.0051
G1 X137.568 Y140.877 E.00564
G1 X137.73 Y140.818 E.00566
G1 X139.403 Y139.145 E.07811
G1 X139.532 Y143.334 F36000
; LINE_WIDTH: 0.40624
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X143.19 Y139.675 E.27326
G1 X143.513 Y139.997 E.02409
G1 X139.997 Y143.513 E.26256
G1 X140.32 Y143.836 E.02409
G1 X143.842 Y140.327 E.26256
G1 X143.507 Y140.662 E.02506
G1 X143.823 Y140.978 E.02358
G1 X140.978 Y143.823 E.21245
G1 X141.301 Y144.145 E.02409
G1 X144.145 Y141.301 E.21245
G1 X144.468 Y141.623 E.02409
G1 X141.623 Y144.468 E.21245
G1 X141.946 Y144.79 E.02409
G1 X144.79 Y141.946 E.21245
G1 X145.113 Y142.268 E.02409
G1 X142.268 Y145.113 E.21245
G1 X142.591 Y145.436 E.02409
G1 X145.436 Y142.591 E.21245
G1 X145.758 Y142.914 E.02409
G1 X142.914 Y145.758 E.21245
G1 X143.236 Y146.081 E.02409
G1 X146.081 Y143.236 E.21245
G1 X146.404 Y143.559 E.02409
G1 X143.559 Y146.404 E.21245
G1 X143.882 Y146.726 E.02409
G1 X146.726 Y143.882 E.21245
G1 X147.049 Y144.204 E.02409
G1 X144.204 Y147.049 E.21245
G1 X144.527 Y147.371 E.02409
G1 X147.371 Y144.527 E.21245
G1 X147.694 Y144.849 E.02409
G1 X144.849 Y147.694 E.21245
G1 X145.172 Y148.017 E.02409
G1 X148.017 Y145.172 E.21245
G1 X148.339 Y145.495 E.02409
G1 X145.495 Y148.339 E.21245
G1 X145.817 Y148.662 E.02409
G1 X148.662 Y145.817 E.21245
G1 X148.984 Y146.14 E.02409
G1 X146.14 Y148.984 E.21245
G1 X146.462 Y149.307 E.02409
G1 X149.307 Y146.462 E.21245
G1 X149.63 Y146.785 E.02409
G1 X146.785 Y149.63 E.21245
G1 X147.108 Y149.952 E.02409
G1 X149.952 Y147.108 E.21245
G1 X150.275 Y147.43 E.02409
G1 X147.43 Y150.275 E.21245
G1 X147.753 Y150.597 E.02409
G1 X150.597 Y147.753 E.21245
G1 X150.92 Y148.075 E.02409
G1 X148.075 Y150.92 E.21245
G1 X148.398 Y151.243 E.02409
G1 X151.243 Y148.398 E.21245
G1 X151.565 Y148.721 E.02409
G1 X148.721 Y151.565 E.21245
G1 X149.043 Y151.888 E.02409
G1 X151.888 Y149.043 E.21245
G1 X152.211 Y149.366 E.02409
G1 X149.366 Y152.211 E.21245
G1 X149.689 Y152.533 E.02409
G1 X152.533 Y149.689 E.21245
G1 X152.856 Y150.011 E.02409
G1 X150.011 Y152.856 E.21245
G1 X150.334 Y153.178 E.02409
G1 X153.178 Y150.334 E.21245
G1 X153.501 Y150.656 E.02409
G1 X150.656 Y153.501 E.21245
G1 X150.775 Y153.62 E.00888
G1 X150.44 Y153.955 E.02506
G1 X150.643 Y154.159 E.01521
G1 X154.159 Y150.643 E.26256
G1 X154.482 Y150.966 E.02409
G1 X150.823 Y154.625 E.27326
G1 X150.444 Y154.91 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53922
; LAYER_HEIGHT: 0.2
G1 F12000
G1 X150.542 Y154.812 E.00562
G1 X150.695 Y156.068 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X149.917 Y155.29 E.05401
; WIPE_START
G1 X148.766 Y156.442 E-.61876
G1 X149.029 Y156.705 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X144.803 Y150.348 Z5.4 F36000
G1 X140.662 Y144.119 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.45858
G1 F15000
G1 X150.121 Y153.578 E.45307
; WIPE_START
G1 X148.707 Y152.163 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X143.01 Y147.083 Z5.4 F36000
G1 X139.372 Y143.838 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53918
G1 F12000
G1 X139.471 Y143.74 E.00562
G1 X138.011 Y145.291 F36000
; LINE_WIDTH: 0.40903
G1 F12000
G1 X137.882 Y145.421 E.00546
G1 X105.622 Y113.161 E1.36108
G1 X105.87 Y112.913 E.01046
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X105.881 Y112.902 E.00046
G1 X138.141 Y145.162 E1.36108
G1 X138.13 Y145.173 E.00046
; Slow Down End
G1 F12000
G1 X138.054 Y145.249 E.00321
G1 X123.608 Y130.082 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
M73 P80 R3
G1 X124.759 Y131.233 E.05401
G1 X131.233 Y124.759 E.30373
G1 X135.071 Y128.597 E.18005
G1 X128.597 Y135.071 E.30373
G1 X127.446 Y133.92 E.05401
G1 X128.547 Y122.072 F36000
G1 F15476.087
G1 X127.395 Y120.921 E.05401
G1 X120.921 Y127.395 E.30373
G1 X117.083 Y123.557 E.18005
G1 X123.557 Y117.083 E.30373
G1 X122.406 Y115.932 E.05401
; WIPE_START
G1 X123.557 Y117.083 E-.61876
G1 X123.295 Y117.346 E-.14124
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.4 I.405 J-1.148 P1  F36000
G1 X107.204 Y111.67 Z5.4
G1 Z5
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53922
G1 F12000
G1 X107.302 Y111.572 E.00562
; WIPE_START
G1 X107.204 Y111.67 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X102.098 Y105.998 Z5.4 F36000
G1 X98.099 Y101.556 Z5.4
G1 Z5
G1 E.8 F1800
; LINE_WIDTH: 0.45861
G1 F12000
G1 X106.881 Y110.338 E.4207
; CHANGE_LAYER
; Z_HEIGHT: 5.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X105.467 Y108.924 E-.76
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
G1 X134.184 Y134.901
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F6463.435
G1 X134.299 Y134.728 E.0069
G1 F5955.396
G1 X134.499 Y134.499 E.01007
G1 F5251.769
G1 X134.727 Y134.299 E.01007
G1 F4592.438
G1 X134.98 Y134.131 E.01006
G1 F3977.489
G1 X135.252 Y133.997 E.01007
G1 F3406.637
G1 X135.54 Y133.901 E.01006
G1 F2880.126
G1 X135.729 Y133.864 E.0064
G1 F2568.193
G1 X135.836 Y133.843 E.00361
G1 F2400
G1 X136.111 Y133.825 E.00915
G1 F2280
G1 X136.439 Y133.846 E.01087
G1 F2412.736
G1 X136.525 Y133.863 E.00293
G1 F2707.41
G1 X136.71 Y133.9 E.00624
G1 F3218.813
G1 X136.998 Y133.995 E.01007
G1 F3824.896
G1 X137.293 Y134.142 E.01094
G1 F4371.373
G1 X137.523 Y134.295 E.00914
G1 F5011.827
G1 X137.751 Y134.493 E.01002
G1 F5044.227
G1 X137.951 Y134.721 E.01006
G1 F4428.974
G1 X138.12 Y134.972 E.01006
G1 F3825.64
G1 X138.255 Y135.245 E.01007
G1 F3266.024
G1 X138.353 Y135.532 E.01007
G1 F2750.833
G1 X138.392 Y135.73 E.0067
G1 F2432.437
G1 X138.412 Y135.829 E.00336
G1 F2280
G1 X138.431 Y136.132 E.01007
G1 F2400
G1 X138.411 Y136.434 E.01003
G1 F2543.908
G1 X138.393 Y136.526 E.0031
G1 F2835.969
G1 X138.357 Y136.704 E.00603
G1 F3405.315
G1 X138.253 Y137.016 E.01092
G1 F3978.637
G1 X138.117 Y137.289 E.01011
G1 F4536.198
G1 X137.964 Y137.518 E.00915
G1 F5218.724
G1 X137.746 Y137.763 E.01087
G1 F5191.255
G1 X137.54 Y137.947 E.00916
G1 F4593.228
G1 X137.291 Y138.116 E.00999
G1 F3982.345
G1 X137.016 Y138.253 E.01017
G1 F3405.51
G1 X136.704 Y138.357 E.01092
G1 F2836.512
G1 X136.526 Y138.393 E.00604
G1 F2544.031
G1 X136.434 Y138.411 E.0031
G1 F2400
G1 X136.132 Y138.431 E.01003
G1 F2280
G1 X135.829 Y138.412 E.01006
G1 F2432.749
G1 X135.73 Y138.392 E.00337
G1 F2751.244
G1 X135.532 Y138.353 E.0067
G1 F3266.444
G1 X135.244 Y138.255 E.01006
G1 F3825.649
G1 X134.973 Y138.121 E.01006
G1 F4429.508
G1 X134.721 Y137.951 E.01007
G1 F5039.055
G1 X134.493 Y137.751 E.01006
G1 X134.295 Y137.523 E.01002
G1 F4526.743
G1 X134.142 Y137.293 E.00914
G1 F3970.362
G1 X133.996 Y137 E.01087
G1 F3356.365
G1 X133.907 Y136.738 E.00917
G1 F2878.309
G1 X133.864 Y136.526 E.00719
G1 F2529.377
G1 X133.847 Y136.443 E.00279
G1 F2400
G3 X133.848 Y135.809 I2.223 J-.314 E.02111
G1 F2523.864
G1 X133.863 Y135.73 E.00267
G1 F2836.901
G1 X133.901 Y135.539 E.00648
G1 F3357.319
G1 X133.997 Y135.252 E.01002
G1 F3924.168
G1 X134.132 Y134.98 E.01007
G1 F3992.676
G1 X134.151 Y134.951 E.00117
G1 X134.234 Y135.9 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F600
M204 S6000
G1 X134.237 Y135.861 E.0012
G1 X134.281 Y135.64 E.00694
G1 F805.799
G1 X134.361 Y135.402 E.00772
G1 F1042.345
G1 X134.472 Y135.176 E.00773
G1 F1171.184
G1 X134.541 Y135.072 E.00384
G1 F1605.68
G1 X134.775 Y134.775 E.01161
G3 X135.072 Y134.541 I1.128 J1.128 E.01164
G1 F1171.635
G1 X135.176 Y134.472 E.00384
G1 F1042.806
G1 X135.402 Y134.361 E.00773
G1 F806.197
G1 X135.64 Y134.281 E.00773
G1 F600
G1 X135.887 Y134.233 E.00772
G1 X135.903 Y134.232 E.00049
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45

G3 X136.355 Y134.233 I.22 J1.754 E.01504
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 X136.388 Y134.236 E.00102
G1 X136.61 Y134.28 E.00694
G1 F806.169
G1 X136.848 Y134.359 E.00773
G1 F1068.351
G1 X137.097 Y134.482 E.00851
G1 F1175.856
G1 X137.183 Y134.54 E.00318
G1 F1605.065
G1 X137.474 Y134.772 E.01145
G1 F1621.393
G1 X137.715 Y135.072 E.01181
G1 F1164.3
G1 X137.781 Y135.17 E.00363
G1 F1042.818
G1 X137.892 Y135.395 E.00773
G1 F806.181
G1 X137.973 Y135.633 E.00773
G1 F600
G1 X138.022 Y135.88 E.00773
G1 X138.024 Y135.902 E.00068
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45

G3 X138.023 Y136.354 I-1.701 J.224 E.01502
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 X138.021 Y136.382 E.00087
G1 X137.977 Y136.603 E.00693
G1 F828.525
G1 X137.89 Y136.866 E.00851
G1 F1068.619
G1 X137.777 Y137.092 E.00775
G1 F1182.257
G1 X137.716 Y137.183 E.00336
G1 F1621.037
G1 X137.472 Y137.489 E.01206
G1 F1606.192
G3 X137.185 Y137.714 I-1.146 J-1.166 E.01123
G1 F1185.351
G1 X137.092 Y137.777 E.00344
G1 F1069.072
G1 X136.866 Y137.89 E.00777
G1 F828.381
G1 X136.604 Y137.977 E.0085
G1 F600
G1 X136.382 Y138.021 E.00694
G1 X136.354 Y138.023 E.00087
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45

G3 X135.902 Y138.024 I-.227 J-1.701 E.01502
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 X135.88 Y138.022 E.00068
G1 X135.633 Y137.973 E.00774
G1 F806.195
G1 X135.395 Y137.892 E.00773
G1 F1042.749
G1 X135.17 Y137.781 E.00773
G1 F1164.313
G1 X135.072 Y137.715 E.00363
G1 F1589.858
G1 X134.77 Y137.476 E.01182
G1 F1572.863
G3 X134.54 Y137.183 I1.152 J-1.143 E.01148
G1 F1147.988
G1 X134.482 Y137.097 E.00318
G1 F1041.796
G1 X134.359 Y136.849 E.00849
G1 F783.79
G1 X134.286 Y136.635 E.00694
G1 F600
G1 X134.236 Y136.39 E.0077
G1 X134.233 Y136.355 E.00108
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45

G3 X134.227 Y135.96 I1.593 J-.224 E.01313
; WIPE_START
M204 S10000
G1 X134.237 Y135.861 E-.03759
G1 X134.281 Y135.64 E-.08582
G1 X134.361 Y135.402 E-.09546
G1 X134.472 Y135.176 E-.09563
G1 X134.541 Y135.072 E-.04752
G1 X134.775 Y134.775 E-.1436
G1 X135.072 Y134.541 E-.14361
G1 X135.176 Y134.472 E-.0475
G1 X135.325 Y134.398 E-.06327
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.6 I.818 J-.901 P1  F36000
G1 X112.823 Y113.961 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F7259.686
G1 X112.922 Y113.769 E.00715
G1 F6701.915
G1 X113.086 Y113.514 E.01006
G1 F5955.053
G1 X113.286 Y113.286 E.01007
G1 F5251.67
G1 X113.514 Y113.086 E.01007
G1 F4592.184
G1 X113.767 Y112.918 E.01006
G1 F3977.345
G1 X114.039 Y112.784 E.01007
G1 F3406.407
G1 X114.327 Y112.688 E.01006
G1 F2880.008
G1 X114.516 Y112.651 E.0064
G1 F2567.943
G1 X114.623 Y112.63 E.00361
G1 F2400
G1 X114.899 Y112.612 E.00916
G1 F2280
G1 X115.228 Y112.633 E.01094
G1 F2410.2
G1 X115.313 Y112.65 E.00288
G1 F2751.189
G1 X115.525 Y112.694 E.00719
G1 F3219.007
G1 X115.787 Y112.783 E.00917
G1 F3820.807
G1 X116.08 Y112.929 E.01087
G1 F4366.979
G1 X116.309 Y113.082 E.00914
G1 F5006.96
G1 X116.537 Y113.28 E.01001
G1 F5041.815
G1 X116.736 Y113.509 E.01006
G1 F4428.77
G1 X116.907 Y113.759 E.01006
G1 F3825.548
G1 X117.042 Y114.031 E.01007
G1 F3265.947
G1 X117.14 Y114.319 E.01006
G1 F2750.88
G1 X117.179 Y114.517 E.0067
G1 F2432.467
G1 X117.199 Y114.616 E.00336
G1 F2280
G1 X117.218 Y114.919 E.01007
G1 F2400
G1 X117.198 Y115.221 E.01003
G1 F2543.982
G1 X117.179 Y115.312 E.0031
G1 F2836.302
G1 X117.144 Y115.491 E.00604
G1 F3405.577
G1 X117.04 Y115.803 E.01092
G1 F3978.885
G1 X116.904 Y116.076 E.01011
G1 F4536.238
G1 X116.75 Y116.305 E.00915
G1 F5218.731
G1 X116.533 Y116.55 E.01087
G1 F5191.182
G1 X116.327 Y116.734 E.00916
G1 F4593.114
G1 X116.077 Y116.903 E.00999
G1 F3982.407
G1 X115.803 Y117.04 E.01017
G1 F3405.559
G1 X115.491 Y117.144 E.01092
G1 F2836.286
G1 X115.312 Y117.179 E.00604
G1 F2543.982
G1 X115.221 Y117.198 E.0031
G1 F2400
G1 X114.919 Y117.218 E.01003
G1 F2280
G1 X114.616 Y117.199 E.01006
G1 F2432.56
G1 X114.517 Y117.179 E.00337
G1 F2751.014
G1 X114.319 Y117.14 E.0067
G1 F3266.238
G1 X114.031 Y117.042 E.01007
G1 F3825.667
G1 X113.759 Y116.907 E.01007
G1 F4429.223
G1 X113.507 Y116.738 E.01006
G1 F5038.993
G1 X113.282 Y116.535 E.01006
G1 X113.082 Y116.309 E.01001
G1 F4526.95
G1 X112.929 Y116.08 E.00914
G1 F3970.567
G1 X112.783 Y115.787 E.01087
G1 F3356.345
G1 X112.694 Y115.525 E.00917
G1 F2878.537
G1 X112.65 Y115.313 E.00719
G1 F2529.444
G1 X112.633 Y115.23 E.00279
G1 F2400
G3 X112.634 Y114.596 I2.224 J-.314 E.0211
G1 F2523.788
G1 X112.65 Y114.517 E.00267
G1 F3406.424
G3 X112.788 Y114.041 I2.266 J.399 E.01648
G1 X112.799 Y114.016 E.00091
G1 X113.076 Y114.402 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F2160
M204 S6000
G1 X113.148 Y114.189 E.00692
G1 F2537.582
G1 X113.258 Y113.963 E.00773
G1 F2736.538
G1 X113.328 Y113.858 E.00384
G1 F3382.622
G1 X113.561 Y113.561 E.01161
G1 F1606.709
G3 X113.859 Y113.328 I1.127 J1.127 E.01164
G1 F1171.588
G1 X113.963 Y113.258 E.00384
G1 F1042.786
G1 X114.189 Y113.148 E.00773
G1 F806.164
G1 X114.427 Y113.068 E.00773
G1 F600
G1 X114.673 Y113.02 E.00771
G1 X114.689 Y113.019 E.00049
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45

G3 X115.142 Y113.02 I.22 J1.754 E.01504
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 X115.175 Y113.022 E.00104
G1 X115.422 Y113.073 E.00773
G1 F783.798
G1 X115.636 Y113.146 E.00694
G1 F1041.859
G1 X115.883 Y113.269 E.00849
G1 F1147.979
G1 X115.969 Y113.326 E.00318
G1 F1572.438
G1 X116.261 Y113.559 E.01145
G1 F1588.683
G1 X116.502 Y113.858 E.01181
G1 F1164.246
G1 X116.567 Y113.956 E.00363
G1 F1042.788
G1 X116.679 Y114.182 E.00773
G1 F806.159
G1 X116.76 Y114.42 E.00773
G1 F600
G1 X116.809 Y114.667 E.00773
G1 X116.81 Y114.689 E.00068
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45

G3 X116.81 Y115.141 I-1.704 J.224 E.01502
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 X116.808 Y115.169 E.00087
G1 X116.764 Y115.39 E.00694
G1 F828.395
G1 X116.677 Y115.653 E.0085
G1 F1068.481
G1 X116.564 Y115.878 E.00775
G1 F1182.15
G1 X116.503 Y115.969 E.00336
G1 F1620.827
G1 X116.258 Y116.276 E.01206
G1 F1606.201
G3 X115.972 Y116.501 I-1.147 J-1.167 E.01122
G1 F1185.509
G1 X115.879 Y116.564 E.00344
G1 F1069.101
G1 X115.653 Y116.677 E.00777
G1 F828.395
G1 X115.39 Y116.764 E.0085
G1 F600
G1 X115.169 Y116.808 E.00694
G1 X115.141 Y116.81 E.00087
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45

G3 X114.689 Y116.81 I-.227 J-1.704 E.01502
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 X114.667 Y116.809 E.00068
G1 X114.42 Y116.76 E.00773
G1 F806.165
G1 X114.182 Y116.679 E.00773
G1 F1042.768
G1 X113.956 Y116.567 E.00773
G1 F1164.262
G1 X113.858 Y116.502 E.00363
G1 F1589.81
G1 X113.557 Y116.263 E.01182
G1 F1572.832
G3 X113.326 Y115.97 I1.151 J-1.143 E.01148
G1 F1147.977
G1 X113.269 Y115.883 E.00318
G1 F1041.857
G1 X113.146 Y115.636 E.00849
G1 F783.766
G1 X113.073 Y115.422 E.00694
G1 F600
G1 X113.023 Y115.176 E.0077
G1 X113.02 Y115.141 E.00108
; FEATURE: Overhang wall
; LINE_WIDTH: 0.45

G3 X113.021 Y114.687 I1.593 J-.224 E.01512
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 X113.024 Y114.648 E.0012
G1 X113.061 Y114.46 E.00589
; WIPE_START
M204 S10000
G1 X113.148 Y114.189 E-.1083
G1 X113.258 Y113.963 E-.09563
G1 X113.328 Y113.858 E-.04752
G1 X113.561 Y113.561 E-.1436
G1 X113.859 Y113.328 E-.14362
G1 X113.963 Y113.258 E-.04749
G1 X114.189 Y113.148 E-.09564
G1 X114.384 Y113.082 E-.07818
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.6 I-.853 J.868 P1  F36000
G1 X154.616 Y152.639 Z5.6
G1 Z5.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X147.974 Y159.281 E.21884
G1 X146.704 Y158.011 E.05957
G1 X150.554 Y154.161 E.1806
G1 X140.121 Y143.729 E.48942
G1 X137.995 Y145.855 E.09975
G1 X105.188 Y113.048 E1.53904
G1 X107.314 Y110.922 E.09975
G1 X97.733 Y101.34 E.44948
G1 X101.34 Y97.733 E.16924
G1 X110.922 Y107.314 E.44948
G1 X113.048 Y105.188 E.09975
G1 X114.063 Y106.203 E.04763
G1 X145.855 Y137.995 E1.49141
G1 X143.729 Y140.121 E.09975
G1 X154.161 Y150.554 E.48942
G1 X158.011 Y146.704 E.1806
G1 X159.281 Y147.974 E.05957
G1 X154.658 Y152.596 E.21685
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X147.974 Y159.835 E.20272
G1 X146.15 Y158.011 E.07928
G1 X149.999 Y154.161 E.16729
G1 X140.121 Y144.283 E.42926
G1 X137.995 Y146.409 E.0924
G1 X104.633 Y113.048 E1.44971
G1 X106.76 Y110.922 E.0924
G1 X97.178 Y101.34 E.41635
G1 X101.34 Y97.178 E.18086
G1 X110.922 Y106.76 E.41635
G1 X113.048 Y104.633 E.0924
G1 X114.34 Y105.926 E.05617
G1 X146.409 Y137.995 E1.39354
G1 X144.283 Y140.121 E.0924
G1 X154.161 Y149.999 E.42926
G1 X158.011 Y146.15 E.16729
G1 X159.835 Y147.974 E.07928
G1 X155.213 Y152.596 E.20087
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.337 Y151.017 Z5.6 F36000
G1 Z5.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53922
G1 F12000
G1 X154.867 Y150.486 E.03035
G1 X154.337 Y151.017 F36000
; LINE_WIDTH: 0.519349
G1 F12000
G1 X154.234 Y151.003 E.00403
; LINE_WIDTH: 0.479605
G1 X154.131 Y150.989 E.0037
; LINE_WIDTH: 0.420126
G1 X154.028 Y150.975 E.00319
G1 X143.307 Y140.254 E.46602
; LINE_WIDTH: 0.440495
G1 X143.284 Y140.162 E.00309
; LINE_WIDTH: 0.481505
G1 X143.26 Y140.07 E.00341
; LINE_WIDTH: 0.522515
G1 X143.236 Y139.977 E.00373
G1 X143.115 Y140.07 E.00596
; LINE_WIDTH: 0.481505
G1 X142.993 Y140.162 E.00545
; LINE_WIDTH: 0.420801
G1 X142.872 Y140.254 E.00469
G1 X140.254 Y142.872 E.114
; LINE_WIDTH: 0.439862
G1 X140.151 Y143.003 E.00539
; LINE_WIDTH: 0.479605
G1 X140.048 Y143.134 E.00593
; LINE_WIDTH: 0.519349
G1 X139.945 Y143.265 E.00647
G1 X140.048 Y143.279 E.00403
; LINE_WIDTH: 0.479605
G1 X140.151 Y143.293 E.0037
; LINE_WIDTH: 0.420126
G1 X140.254 Y143.307 E.00319
G1 X150.975 Y154.028 E.46602
; LINE_WIDTH: 0.440489
G1 X150.999 Y154.12 E.00309
; LINE_WIDTH: 0.481485
G1 X151.022 Y154.213 E.00341
; LINE_WIDTH: 0.522482
G1 X151.046 Y154.305 E.00373
G1 X151.168 Y154.213 E.00596
; LINE_WIDTH: 0.481485
G1 X151.289 Y154.12 E.00545
; LINE_WIDTH: 0.420801
G1 X151.41 Y154.028 E.00469
G1 X154.028 Y151.41 E.114
; LINE_WIDTH: 0.439862
G1 X154.119 Y151.295 E.00474
; LINE_WIDTH: 0.479605
G1 X154.209 Y151.179 E.00522
; LINE_WIDTH: 0.519349
G1 X154.3 Y151.064 E.00569
G1 X153.712 Y151.192 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X143.09 Y140.57 E.46159
G1 X140.57 Y143.09 E.1095
G1 X151.192 Y153.712 E.46159
G1 X153.67 Y151.235 E.10765
G1 X153.179 Y151.192 F36000
G1 F12000
G1 X143.09 Y141.103 E.43842
G1 X141.103 Y143.09 E.08633
G1 X151.192 Y153.179 E.43842
G1 X153.137 Y151.235 E.08448
G1 X152.646 Y151.192 F36000
G1 F12000
G1 X143.09 Y141.636 E.41525
G1 X141.636 Y143.09 E.06315
G1 X151.192 Y152.646 E.41525
G1 X152.603 Y151.235 E.06131
G1 X152.113 Y151.192 F36000
G1 F12000
G1 X143.09 Y142.17 E.39207
G1 X142.17 Y143.09 E.03998
G1 X151.192 Y152.113 E.39207
G1 X152.07 Y151.235 E.03814
G1 X151.519 Y151.192 F36000
; LINE_WIDTH: 0.50499
G1 F12000
G1 X143.09 Y142.763 E.44886
G1 X142.763 Y143.09 E.0174
G1 X151.192 Y151.519 E.44886
G1 X151.477 Y151.235 E.01514
G1 X150.444 Y154.91 F36000
; LINE_WIDTH: 0.53922
G1 F12000
G1 X151.005 Y154.349 E.0321
; WIPE_START
G1 X150.444 Y154.91 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.047 Y149.513 Z5.6 F36000
G1 X139.372 Y143.838 Z5.6
G1 Z5.2
G1 E.8 F1800
G1 F12000
G1 X139.903 Y143.308 E.03035
G1 X143.838 Y139.372 F36000
G1 F12000
G1 X143.277 Y139.934 E.0321
G1 X137.57 Y143.753 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X136.419 Y142.601 E.05401
G1 X142.601 Y136.419 E.29004
G1 X141.801 Y135.619 E.03754
G1 X140.64 Y136.78 E.05447
G1 X140.984 Y137.124 E.01615
G1 X140.984 Y137.465 E.01131
G1 X139.225 Y139.225 E.08255
G1 X141.286 Y141.286 E.0967
G1 X140.135 Y142.437 E.05401
G1 X138.132 Y145.154 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.43253
G1 F12000
G1 X137.995 Y145.291 E.00619
G1 X105.751 Y113.048 E1.4477
G1 X106.018 Y112.781 E.012
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X138.262 Y145.024 E1.4477
; Slow Down End
G1 F12000
G1 X138.175 Y145.111 E.00391
G1 X134.56 Y139.087 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X133.408 Y137.936 E.05401
M73 P81 R3
G1 X132.581 Y138.763 E.03882
G1 X128.743 Y134.925 E.18005
G1 X134.925 Y128.743 E.29004
G1 X131.087 Y124.905 E.18005
G1 X124.905 Y131.088 E.29004
G1 X121.067 Y127.25 E.18005
G1 X127.25 Y121.067 E.29004
G1 X123.412 Y117.229 E.18005
G1 X117.229 Y123.412 E.29004
G1 X113.391 Y119.574 E.18005
G1 X114.552 Y118.412 E.05447
G1 X115.911 Y119.771 E.06375
G1 X116.252 Y119.771 E.01131
G1 X118.012 Y118.012 E.08255
G1 X133.031 Y133.031 E.70459
G1 X134.182 Y131.88 E.05401
G1 X113.491 Y117.321 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.60068
G1 F11295.181
G1 X113.238 Y117.098 E.01531
; LINE_WIDTH: 0.570148
G1 F11949.295
G1 X112.985 Y116.876 E.01448
G1 X112.564 Y116.403 E.0272
G1 X134.704 Y138.534 F36000
; LINE_WIDTH: 0.60072
G1 F11294.371
G1 X134.451 Y138.312 E.01531
; LINE_WIDTH: 0.570124
G1 F11949.85
G1 X134.198 Y138.089 E.01447
G1 X133.777 Y137.616 E.02721
; WIPE_START
G1 X134.198 Y138.089 E-.4961
G1 X134.451 Y138.312 E-.2639
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.6 I.456 J1.128 P1  F36000
G1 X142.005 Y135.259 Z5.6
G1 Z5.2
G1 E.8 F1800
; LINE_WIDTH: 0.420505
G1 F12000
G1 X141.98 Y135.236 E.00104
G1 X141.736 Y135.208 E.00755
G1 X141.602 Y135.263 E.00444
G1 X140.285 Y136.581 E.05734
G1 X140.231 Y136.69 E.00374
G1 X140.244 Y136.918 E.00701
G1 X140.592 Y137.303 E.01599
G3 X137.287 Y140.592 I-120.611 J-117.899 E.1435
G3 X135.928 Y139.231 I248.176 J-249.012 E.05919
; LINE_WIDTH: 0.439473
G1 X135.832 Y139.193 E.00333
; LINE_WIDTH: 0.456841
G1 X135.736 Y139.156 E.00348
G1 X135.298 Y139.225 E.01494
; LINE_WIDTH: 0.508685
G1 X135.254 Y139.181 E.00235
; LINE_WIDTH: 0.554155
G1 X135.211 Y139.137 E.00257
; LINE_WIDTH: 0.54755
G1 X134.704 Y138.534 E.0324
; LINE_WIDTH: 0.599625
G1 F11316.586
G1 X134.724 Y138.541 E.00095
; LINE_WIDTH: 0.554155
G1 F12000
G1 X134.744 Y138.548 E.00087
; LINE_WIDTH: 0.508685
G1 X134.763 Y138.554 E.0008
; LINE_WIDTH: 0.57979
G1 F11734.685
G1 X134.921 Y138.604 E.00723
; LINE_WIDTH: 0.53879
G1 F12000
G1 X135.079 Y138.654 E.00668
; LINE_WIDTH: 0.49779
G1 X135.236 Y138.704 E.00613
; LINE_WIDTH: 0.45679
G1 X135.394 Y138.754 E.00558
; LINE_WIDTH: 0.469893
G1 X135.514 Y138.761 E.00419
; LINE_WIDTH: 0.420775
G3 X136.157 Y138.823 I-.358 J7.116 E.01989
G1 X136.781 Y138.741 E.01936
G2 X137.509 Y138.442 I-3.253 J-8.941 E.02424
G1 X138.041 Y138.025 E.02083
G1 X138.468 Y137.463 E.02172
G1 X138.691 Y136.92 E.01807
G2 X138.819 Y136.083 I-3.193 J-.918 E.02616
G1 X138.695 Y135.336 E.02329
G1 X138.446 Y134.755 E.01947
G1 X138.009 Y134.199 E.02178
G1 X137.468 Y133.791 E.02086
G1 X136.785 Y133.516 E.02266
G1 X136.179 Y133.44 E.01882
G2 X134.764 Y133.805 I.08 J3.237 E.04538
G1 X134.205 Y134.24 E.02181
G1 X133.78 Y134.807 E.02181
G1 X133.517 Y135.462 E.02175
G1 X133.433 Y136.114 E.02023
; LINE_WIDTH: 0.438103
G1 X133.443 Y136.225 E.0036
; LINE_WIDTH: 0.470268
G1 X133.453 Y136.337 E.0039
; LINE_WIDTH: 0.451962
G1 X133.467 Y136.472 E.00453
; LINE_WIDTH: 0.499384
G1 X133.48 Y136.607 E.00505
; LINE_WIDTH: 0.546807
G1 X133.493 Y136.743 E.00558
; LINE_WIDTH: 0.548318
G1 X133.506 Y136.878 E.0056
G1 X133.738 Y137.571 E.03009
; LINE_WIDTH: 0.596009
G1 F11390.586
G1 X133.717 Y137.556 E.00114
; LINE_WIDTH: 0.552145
G1 F12000
G1 X133.697 Y137.542 E.00104
; LINE_WIDTH: 0.508282
G1 X133.676 Y137.527 E.00095
; LINE_WIDTH: 0.573674
G1 F11869.912
G1 X133.515 Y137.385 E.0093
; LINE_WIDTH: 0.534602
G1 F12000
G1 X133.354 Y137.242 E.00862
; LINE_WIDTH: 0.495529
G1 X133.192 Y137.1 E.00793
; LINE_WIDTH: 0.45699
G1 X133.031 Y136.958 E.00726
G1 X133.103 Y136.596 E.01244
; LINE_WIDTH: 0.421347
G1 X133.076 Y136.413 E.00569
G1 X132.968 Y136.273 E.00547
G3 X131.663 Y134.953 I43.825 J-44.641 E.05722
G1 X134.969 Y131.663 E.14382
G1 X135.338 Y132.012 E.01565
G1 X135.542 Y132.026 E.00629
G1 X135.675 Y131.971 E.00445
G1 X136.993 Y130.653 E.05747
G2 X136.997 Y130.251 I-.348 J-.205 E.01298
G1 X136.491 Y129.745 E.02209
; Slow Down Start
; LINE_WIDTH: 0.43253
G1 F3000;_EXTRUDE_SET_SPEED
G1 X121.298 Y114.552 E.68214
; Slow Down End
; LINE_WIDTH: 0.42143
G1 F12000
G2 X120.766 Y114.023 I-6.397 J5.89 E.02314
G1 X120.523 Y113.995 E.00757
G1 X120.389 Y114.05 E.00445
G1 X119.071 Y115.368 E.05748
G1 X119.018 Y115.477 E.00375
G1 X119.031 Y115.704 E.00703
G1 X119.379 Y116.09 E.01603
G3 X116.073 Y119.379 I-120.434 J-117.722 E.14386
G3 X114.714 Y118.018 I249.011 J-249.847 E.05934
; LINE_WIDTH: 0.43947
G1 X114.618 Y117.98 E.00333
; LINE_WIDTH: 0.456835
G1 X114.522 Y117.943 E.00348
G1 X114.085 Y118.012 E.01494
; LINE_WIDTH: 0.508667
G1 X114.041 Y117.968 E.00234
; LINE_WIDTH: 0.55412
G1 X113.998 Y117.924 E.00257
; LINE_WIDTH: 0.547522
G1 X113.491 Y117.321 E.0324
; LINE_WIDTH: 0.599574
G1 F11317.636
G1 X113.51 Y117.328 E.00095
; LINE_WIDTH: 0.55412
G1 F12000
G1 X113.53 Y117.334 E.00087
; LINE_WIDTH: 0.508667
G1 X113.55 Y117.341 E.00079
; LINE_WIDTH: 0.579755
G1 F11735.449
G1 X113.708 Y117.391 E.00724
; LINE_WIDTH: 0.538765
G1 F12000
G1 X113.865 Y117.441 E.00668
; LINE_WIDTH: 0.497775
G1 X114.023 Y117.491 E.00613
; LINE_WIDTH: 0.456785
G1 X114.181 Y117.541 E.00558
; LINE_WIDTH: 0.469888
G1 X114.301 Y117.548 E.00419
; LINE_WIDTH: 0.420775
G3 X114.944 Y117.61 I-.357 J7.11 E.01988
G1 X115.567 Y117.528 E.01937
G2 X116.295 Y117.228 I-3.252 J-8.937 E.02424
G1 X116.828 Y116.811 E.02082
G1 X117.254 Y116.25 E.02171
G1 X117.477 Y115.707 E.01807
G2 X117.606 Y114.87 I-3.197 J-.918 E.02616
G1 X117.482 Y114.123 E.0233
G1 X117.233 Y113.542 E.01947
G1 X116.796 Y112.986 E.02178
G1 X116.256 Y112.579 E.02083
G1 X115.603 Y112.31 E.02173
G1 X114.96 Y112.226 E.01996
G2 X113.55 Y112.591 I.095 J3.27 E.04522
G1 X112.992 Y113.027 E.02181
G1 X112.567 Y113.593 E.02181
G1 X112.304 Y114.249 E.02175
G1 X112.219 Y114.901 E.02024
; LINE_WIDTH: 0.438105
G1 X112.23 Y115.012 E.0036
; LINE_WIDTH: 0.470275
G1 X112.24 Y115.124 E.0039
; LINE_WIDTH: 0.451978
G1 X112.253 Y115.259 E.00453
; LINE_WIDTH: 0.499413
G1 X112.267 Y115.394 E.00505
; LINE_WIDTH: 0.546848
G1 X112.28 Y115.529 E.00558
; LINE_WIDTH: 0.548353
G1 X112.293 Y115.665 E.0056
G1 X112.524 Y116.358 E.03009
; LINE_WIDTH: 0.59606
G1 F11389.522
G1 X112.504 Y116.343 E.00113
; LINE_WIDTH: 0.55218
G1 F12000
G1 X112.483 Y116.328 E.00104
; LINE_WIDTH: 0.5083
G1 X112.463 Y116.314 E.00095
; LINE_WIDTH: 0.573722
G1 F11868.85
G1 X112.302 Y116.171 E.0093
; LINE_WIDTH: 0.534644
G1 F12000
G1 X112.14 Y116.029 E.00862
; LINE_WIDTH: 0.495567
G1 X111.979 Y115.887 E.00793
; LINE_WIDTH: 0.457008
G1 X111.818 Y115.744 E.00726
G1 X111.889 Y115.383 E.01245
; LINE_WIDTH: 0.421348
G1 X111.863 Y115.2 E.00569
G1 X111.755 Y115.059 E.00547
G3 X110.45 Y113.74 I43.777 J-44.593 E.05722
G1 X113.756 Y110.45 E.14382
G1 X114.125 Y110.799 E.01565
G1 X114.328 Y110.813 E.00629
G1 X114.462 Y110.758 E.00445
G1 X115.779 Y109.44 E.05747
G2 X115.784 Y109.038 I-.348 J-.205 E.01298
G1 X115.277 Y108.532 E.02209
; Slow Down Start
; LINE_WIDTH: 0.432536
G1 F3000;_EXTRUDE_SET_SPEED
G1 X112.781 Y106.018 E.11247
; Slow Down End
; LINE_WIDTH: 0.42694
G1 F12000
G1 X113.048 Y105.751 E.01182
G1 X116.385 Y109.079 E.14747
G3 X121.067 Y113.77 I-358.029 J362.033 E.2074
G1 X137.598 Y130.292 E.73138
G3 X142.28 Y134.983 I-358.504 J362.507 E.2074
G1 X145.291 Y137.995 E.13327
G1 X145.024 Y138.262 E.01182
; Slow Down Start
; LINE_WIDTH: 0.432536
G1 F3000;_EXTRUDE_SET_SPEED
G1 X142.511 Y135.765 E.11247
; Slow Down End
; LINE_WIDTH: 0.432531
G1 F12000
G1 X142.047 Y135.301 E.02083
G1 X141.642 Y134.87 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X137.386 Y130.614 E.18494
G1 X137.259 Y130.92 E.01019
G1 X135.941 Y132.238 E.05726
G1 X135.711 Y132.377 E.00827
G1 X135.383 Y132.403 E.01012
G1 X135.193 Y132.36 E.00597
G1 X134.961 Y132.189 E.00887
; LINE_WIDTH: 0.432888
G1 X134.633 Y132.535 E.01518
; LINE_WIDTH: 0.458683
G1 X134.304 Y132.882 E.01619
; LINE_WIDTH: 0.490545
G1 X134.234 Y132.979 E.00436
; LINE_WIDTH: 0.525874
G1 X134.164 Y133.076 E.0047
G2 X133.076 Y134.164 I8.869 J9.957 E.06059
; LINE_WIDTH: 0.52619
G1 X132.886 Y134.324 E.00978
; LINE_WIDTH: 0.48371
G1 X132.696 Y134.484 E.00892
; LINE_WIDTH: 0.42205
G2 X132.189 Y134.961 I2.528 J3.195 E.02155
G1 X133.086 Y135.859 E.03922
G1 X133.181 Y135.271 E.01839
; LINE_WIDTH: 0.4362
G1 X133.291 Y134.961 E.01055
; LINE_WIDTH: 0.46862
G1 X133.401 Y134.651 E.01142
; LINE_WIDTH: 0.50048
G1 X133.428 Y134.573 E.00306
; LINE_WIDTH: 0.525999
G1 X133.455 Y134.496 E.00323
G1 X133.873 Y133.986 E.02596
G1 X134.496 Y133.455 E.03223
; LINE_WIDTH: 0.526199
G1 X134.728 Y133.374 E.00967
; LINE_WIDTH: 0.483715
G1 X134.96 Y133.294 E.00882
; LINE_WIDTH: 0.42074
G3 X136.832 Y133.141 I1.193 J3.078 E.05865
G1 X137.612 Y133.443 E.02575
G1 X138.239 Y133.9 E.02387
G1 X138.745 Y134.525 E.02475
G1 X139.043 Y135.192 E.0225
G1 X139.111 Y135.406 E.00691
G1 X139.196 Y136.059 E.0203
G1 X139.136 Y136.668 E.01883
G1 X139.039 Y137.063 E.01254
; LINE_WIDTH: 0.435975
G1 X138.943 Y137.341 E.00941
; LINE_WIDTH: 0.467945
G1 X138.846 Y137.618 E.01018
; LINE_WIDTH: 0.499245
G1 X138.818 Y137.697 E.00311
; LINE_WIDTH: 0.524754
G1 X138.79 Y137.776 E.00329
G1 X138.372 Y138.281 E.02573
G1 X137.776 Y138.79 E.03077
; LINE_WIDTH: 0.524174
G1 X137.559 Y138.865 E.00902
; LINE_WIDTH: 0.4825
G1 X137.341 Y138.94 E.00824
; LINE_WIDTH: 0.422128
G3 X136.829 Y139.115 I-32.034 J-92.773 E.01672
G1 X136.398 Y139.171 E.01343
G1 X137.295 Y140.067 E.03917
; LINE_WIDTH: 0.432603
G1 X137.63 Y139.714 E.01548
; LINE_WIDTH: 0.457828
G1 X137.966 Y139.36 E.01648
; LINE_WIDTH: 0.489083
G1 X138.036 Y139.264 E.00435
; LINE_WIDTH: 0.524701
G1 X138.107 Y139.167 E.0047
G2 X139.166 Y138.108 I-8.877 J-9.935 E.05884
; LINE_WIDTH: 0.524324
G1 X139.376 Y137.927 E.01085
; LINE_WIDTH: 0.48259
G1 X139.585 Y137.747 E.00991
; LINE_WIDTH: 0.421479
G2 X140.067 Y137.295 I-2.747 J-3.409 E.02041
G1 X139.877 Y137.009 E.01059
G1 X139.857 Y136.641 E.01137
G1 X139.922 Y136.442 E.00645
G3 X141.336 Y134.997 I25.96 J23.97 E.06239
G1 X141.587 Y134.893 E.00838
G1 X141.019 Y134.78 F36000
; LINE_WIDTH: 0.417826
G1 F12000
G1 X137.476 Y131.237 E.15308
G1 X136.208 Y132.505 E.05477
G3 X135.82 Y132.723 I-.627 J-.658 E.01374
G1 X136.272 Y132.691 E.01384
G1 X136.879 Y132.767 E.01868
G1 X137.757 Y133.095 E.02862
G1 X138.468 Y133.601 E.02668
G1 X138.64 Y133.772 E.00742
G1 X139.043 Y134.294 E.02013
G1 X139.391 Y135.047 E.02534
G1 X139.485 Y135.357 E.00988
G1 X139.57 Y136.011 E.02014
G1 X139.504 Y136.595 E.01798
G1 X139.594 Y136.263 E.01053
G1 X139.751 Y136.048 E.00814
G1 X140.977 Y134.822 E.05294
G1 X140.393 Y134.78 F36000
; LINE_WIDTH: 0.531469
G1 F12000
G1 X140.21 Y134.569 E.01113
; LINE_WIDTH: 0.492905
G1 X140.026 Y134.358 E.01026
; LINE_WIDTH: 0.454342
G1 X139.842 Y134.147 E.00938
; LINE_WIDTH: 0.41158
G1 X139.487 Y133.758 E.01583
; LINE_WIDTH: 0.362769
G2 X138.411 Y132.679 I-8.793 J7.685 E.03974
; LINE_WIDTH: 0.40362
G1 X138.223 Y132.52 E.00726
; LINE_WIDTH: 0.44598
G1 X138.034 Y132.361 E.00811
; LINE_WIDTH: 0.48834
G1 X137.845 Y132.202 E.00896
; LINE_WIDTH: 0.548573
G3 X137.476 Y131.863 I1.784 J-2.311 E.02066
G1 X136.995 Y132.344 E.02801
G1 X137.378 Y132.458 E.01648
; LINE_WIDTH: 0.532235
G1 X137.554 Y132.552 E.00792
; LINE_WIDTH: 0.492945
G1 X137.729 Y132.646 E.00729
; LINE_WIDTH: 0.453655
G1 X137.904 Y132.74 E.00665
; LINE_WIDTH: 0.41085
G1 X138.289 Y133.036 E.01457
; LINE_WIDTH: 0.363086
G1 X138.674 Y133.333 E.01268
G1 X139.327 Y134.075 E.02579
; LINE_WIDTH: 0.404302
G1 X139.445 Y134.276 E.00686
; LINE_WIDTH: 0.446144
G1 X139.563 Y134.476 E.00765
; LINE_WIDTH: 0.487987
G1 X139.682 Y134.677 E.00844
; LINE_WIDTH: 0.546859
G1 X139.8 Y134.877 E.00956
G1 X139.913 Y135.261 E.0164
G1 X140.351 Y134.822 E.02544
G1 X139.504 Y136.595 F36000
; LINE_WIDTH: 0.400394
G1 F12000
G1 X139.493 Y136.774 E.00522
; LINE_WIDTH: 0.4463
G1 X139.482 Y136.953 E.00589
; LINE_WIDTH: 0.492207
G1 X139.47 Y137.132 E.00657
; LINE_WIDTH: 0.534355
G1 X139.47 Y137.156 E.00094
; LINE_WIDTH: 0.572745
G1 F11890.719
G1 X139.469 Y137.179 E.00101
G1 X137.327 Y139.374 F36000
; LINE_WIDTH: 0.56584
G1 F12000
G2 X137.33 Y139.483 I-.028 J.055 E.01084
; WIPE_START
G1 X137.262 Y139.488 E-.1961
G1 X137.229 Y139.431 E-.18796
G1 X137.262 Y139.374 E-.18796
G1 X137.327 Y139.374 E-.18797
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.6 I.86 J-.861 P1  F36000
G1 X132.856 Y134.905 Z5.6
G1 Z5.2
G1 E.8 F1800
; LINE_WIDTH: 0.56356
G1 F12000
G2 X132.858 Y135.013 I-.028 J.055 E.01074
G1 X135.016 Y132.787 F36000
; LINE_WIDTH: 0.569188
G1 F11971.087
G1 X135.121 Y132.782 E.00451
; LINE_WIDTH: 0.528324
G1 F12000
G1 X135.226 Y132.777 E.00416
; LINE_WIDTH: 0.48746
G1 X135.331 Y132.773 E.00381
; LINE_WIDTH: 0.446596
G1 X135.436 Y132.768 E.00346
; LINE_WIDTH: 0.393903
G2 X135.761 Y132.732 I-.022 J-1.678 E.00935
G1 X120.429 Y113.656 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X116.173 Y109.401 E.18494
G1 X116.046 Y109.707 E.01019
G1 X114.728 Y111.025 E.05726
G1 X114.498 Y111.164 E.00827
G1 X114.17 Y111.19 E.01012
G1 X113.98 Y111.147 E.00598
G1 X113.748 Y110.975 E.00887
; LINE_WIDTH: 0.432888
G1 X113.419 Y111.322 E.01518
; LINE_WIDTH: 0.458683
G1 X113.091 Y111.669 E.01619
; LINE_WIDTH: 0.49054
G1 X113.021 Y111.766 E.00436
; LINE_WIDTH: 0.525869
G1 X112.951 Y111.863 E.0047
G2 X111.863 Y112.951 I8.867 J9.955 E.06059
; LINE_WIDTH: 0.52619
G1 X111.673 Y113.111 E.00978
; LINE_WIDTH: 0.48371
G1 X111.483 Y113.271 E.00892
; LINE_WIDTH: 0.42205
G2 X110.975 Y113.748 I2.527 J3.194 E.02155
G1 X111.873 Y114.646 E.03922
G1 X111.968 Y114.058 E.01839
; LINE_WIDTH: 0.4362
G1 X112.078 Y113.748 E.01055
; LINE_WIDTH: 0.46862
G1 X112.188 Y113.438 E.01142
; LINE_WIDTH: 0.50048
G1 X112.215 Y113.36 E.00306
; LINE_WIDTH: 0.525984
G1 X112.241 Y113.283 E.00323
G1 X112.659 Y112.772 E.02596
G1 X113.282 Y112.241 E.03223
; LINE_WIDTH: 0.526182
G1 X113.514 Y112.161 E.00967
; LINE_WIDTH: 0.483705
G1 X113.746 Y112.081 E.00882
; LINE_WIDTH: 0.42074
G3 X114.972 Y111.847 I1.364 J3.823 E.03856
G1 X115.652 Y111.937 E.02112
G1 X116.402 Y112.231 E.02482
G1 X117.025 Y112.687 E.02377
G1 X117.531 Y113.311 E.02475
G1 X117.83 Y113.978 E.0225
G1 X117.897 Y114.193 E.00691
G1 X117.983 Y114.846 E.02029
G1 X117.923 Y115.455 E.01883
G1 X117.826 Y115.85 E.01253
; LINE_WIDTH: 0.435978
G1 X117.729 Y116.128 E.00941
; LINE_WIDTH: 0.467953
G1 X117.633 Y116.405 E.01018
; LINE_WIDTH: 0.499243
G1 X117.605 Y116.484 E.00311
; LINE_WIDTH: 0.524742
G1 X117.576 Y116.563 E.00329
G1 X117.159 Y117.068 E.02573
G1 X116.563 Y117.577 E.03076
; LINE_WIDTH: 0.524165
G1 X116.346 Y117.652 E.00902
; LINE_WIDTH: 0.482495
G1 X116.128 Y117.727 E.00824
; LINE_WIDTH: 0.422128
G3 X115.616 Y117.902 I-32.46 J-94.022 E.01672
G1 X115.185 Y117.958 E.01342
G1 X116.081 Y118.854 E.03917
; LINE_WIDTH: 0.4326
G1 X116.417 Y118.501 E.01548
; LINE_WIDTH: 0.45782
G1 X116.753 Y118.147 E.01648
; LINE_WIDTH: 0.489073
G1 X116.823 Y118.05 E.00435
; LINE_WIDTH: 0.524697
G1 X116.894 Y117.954 E.0047
G2 X117.953 Y116.895 I-8.873 J-9.931 E.05882
; LINE_WIDTH: 0.52429
G1 X118.162 Y116.714 E.01085
; LINE_WIDTH: 0.48257
G1 X118.372 Y116.534 E.00991
; LINE_WIDTH: 0.421478
G2 X118.854 Y116.081 I-2.753 J-3.415 E.02041
G1 X118.663 Y115.796 E.01058
G1 X118.644 Y115.428 E.01137
G1 X118.709 Y115.229 E.00646
G3 X120.123 Y113.783 I26.032 J24.042 E.06239
G1 X120.373 Y113.679 E.00838
G1 X119.806 Y113.567 F36000
; LINE_WIDTH: 0.417826
G1 F12000
G1 X116.263 Y110.024 E.15308
G1 X114.995 Y111.291 E.05477
G3 X114.607 Y111.51 I-.627 J-.658 E.01374
G1 X115.058 Y111.478 E.01382
G1 X115.701 Y111.563 E.0198
G1 X116.549 Y111.884 E.02769
G1 X117.255 Y112.388 E.02651
G1 X117.427 Y112.559 E.00742
G1 X117.83 Y113.081 E.02014
G1 X118.178 Y113.834 E.02534
G1 X118.271 Y114.144 E.00988
G1 X118.357 Y114.797 E.02013
G1 X118.291 Y115.382 E.01799
G1 X118.381 Y115.049 E.01054
G1 X118.538 Y114.835 E.00813
G1 X119.763 Y113.609 E.05294
G1 X119.18 Y113.567 F36000
; LINE_WIDTH: 0.531477
G1 F12000
G1 X118.997 Y113.356 E.01113
; LINE_WIDTH: 0.49291
G1 X118.813 Y113.145 E.01025
; LINE_WIDTH: 0.454344
G1 X118.629 Y112.934 E.00938
; LINE_WIDTH: 0.411578
G1 X118.274 Y112.545 E.01583
; LINE_WIDTH: 0.362763
G2 X117.198 Y111.466 I-8.797 J7.689 E.03974
; LINE_WIDTH: 0.403419
G1 X117.009 Y111.306 E.00726
; LINE_WIDTH: 0.445377
G1 X116.82 Y111.147 E.00811
; LINE_WIDTH: 0.487334
G1 X116.631 Y110.988 E.00895
; LINE_WIDTH: 0.546988
G3 X116.263 Y110.649 I1.805 J-2.333 E.02058
G1 X115.781 Y111.13 E.02797
G1 X116.164 Y111.241 E.01637
; LINE_WIDTH: 0.530584
G1 X116.342 Y111.338 E.00804
; LINE_WIDTH: 0.49121
G1 X116.52 Y111.434 E.00739
; LINE_WIDTH: 0.451837
G1 X116.698 Y111.531 E.00674
; LINE_WIDTH: 0.409458
G1 X117.079 Y111.825 E.0144
; LINE_WIDTH: 0.362928
G1 X117.461 Y112.12 E.01257
G1 X118.114 Y112.862 E.02577
; LINE_WIDTH: 0.404285
G1 X118.232 Y113.062 E.00686
; LINE_WIDTH: 0.446135
G1 X118.35 Y113.263 E.00765
; LINE_WIDTH: 0.487985
G1 X118.468 Y113.464 E.00844
; LINE_WIDTH: 0.546869
G1 X118.587 Y113.664 E.00956
G1 X118.7 Y114.047 E.01641
G1 X119.138 Y113.609 E.02545
G1 X118.291 Y115.382 F36000
; LINE_WIDTH: 0.40039
G1 F12000
G1 X118.28 Y115.561 E.00523
; LINE_WIDTH: 0.44633
G1 X118.268 Y115.74 E.0059
; LINE_WIDTH: 0.49227
G1 X118.257 Y115.919 E.00657
; LINE_WIDTH: 0.53441
G1 X118.256 Y115.943 E.00094
; LINE_WIDTH: 0.57275
G1 F11890.607
G1 X118.256 Y115.966 E.00101
G1 X116.114 Y118.161 F36000
; LINE_WIDTH: 0.5659
G1 F12000
G2 X116.117 Y118.27 I-.028 J.055 E.01084
; WIPE_START
G1 X116.049 Y118.274 E-.19615
G1 X116.016 Y118.218 E-.18795
G1 X116.049 Y118.161 E-.18796
G1 X116.114 Y118.161 E-.18793
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.6 I.86 J-.861 P1  F36000
G1 X111.643 Y113.692 Z5.6
G1 Z5.2
G1 E.8 F1800
; LINE_WIDTH: 0.56356
G1 F12000
G2 X111.645 Y113.8 I-.028 J.055 E.01074
G1 X113.803 Y111.574 F36000
; LINE_WIDTH: 0.569152
G1 F11971.906
G1 X113.908 Y111.569 E.00451
; LINE_WIDTH: 0.528296
G1 F12000
G1 X114.013 Y111.564 E.00416
; LINE_WIDTH: 0.48744
G1 X114.118 Y111.559 E.00381
; LINE_WIDTH: 0.446584
G1 X114.223 Y111.555 E.00346
; LINE_WIDTH: 0.393903
G2 X114.548 Y111.519 I-.023 J-1.681 E.00935
G1 X111.097 Y107.777 F36000
; LINE_WIDTH: 0.5392
G1 F12000
G1 X111.628 Y107.247 E.03035
G1 X111.097 Y107.777 F36000
; LINE_WIDTH: 0.519315
G1 F12000
G1 X110.994 Y107.763 E.00403
; LINE_WIDTH: 0.479585
G1 X110.891 Y107.749 E.0037
; LINE_WIDTH: 0.420057
G1 X110.788 Y107.735 E.00319
G1 X101.34 Y98.287 E.41062
G1 X98.287 Y101.34 E.13269
G1 X107.735 Y110.788 E.41062
; LINE_WIDTH: 0.440492
G1 X107.759 Y110.881 E.00309
; LINE_WIDTH: 0.481495
G1 X107.783 Y110.973 E.00341
; LINE_WIDTH: 0.522499
G1 X107.807 Y111.065 E.00373
G1 X107.928 Y110.973 E.00596
; LINE_WIDTH: 0.481495
G1 X108.049 Y110.881 E.00545
; LINE_WIDTH: 0.420801
G1 X108.17 Y110.788 E.00469
G1 X110.788 Y108.171 E.114
; LINE_WIDTH: 0.439855
G1 X110.879 Y108.055 E.00474
; LINE_WIDTH: 0.479585
G1 X110.97 Y107.94 E.00522
; LINE_WIDTH: 0.519315
G1 X111.06 Y107.825 E.00569
G1 X110.473 Y107.953 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X101.34 Y98.821 E.39683
G1 X98.821 Y101.34 E.1095
G1 X107.953 Y110.473 E.39683
G1 X110.43 Y107.995 E.10765
G1 X109.939 Y107.953 F36000
G1 F12000
G1 X101.34 Y99.354 E.37366
G1 X99.354 Y101.34 E.08633
G1 X107.953 Y109.939 E.37366
G1 X109.897 Y107.995 E.08448
G1 X109.406 Y107.953 F36000
G1 F12000
G1 X101.34 Y99.887 E.35049
G1 X99.887 Y101.34 E.06315
G1 X107.953 Y109.406 E.35049
G1 X109.364 Y107.995 E.06131
G1 X108.873 Y107.953 F36000
G1 F12000
G1 X101.34 Y100.42 E.32732
G1 X100.42 Y101.34 E.03998
G1 X107.953 Y108.873 E.32732
G1 X108.831 Y107.995 E.03814
G1 X108.28 Y107.953 F36000
; LINE_WIDTH: 0.504985
G1 F12000
G1 X101.34 Y101.014 E.3695
G1 X101.014 Y101.34 E.0174
G1 X107.953 Y108.28 E.3695
G1 X108.237 Y107.995 E.01514
G1 X107.204 Y111.67 F36000
; LINE_WIDTH: 0.53922
G1 F12000
G1 X107.766 Y111.109 E.0321
G1 X108.402 Y114.584 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X109.553 Y115.736 E.05401
G1 X110.714 Y114.574 E.05447
G1 X110.058 Y113.918 E.03077
G1 X110.058 Y113.578 E.01131
G1 X111.818 Y111.818 E.08255
G1 X109.757 Y109.757 E.0967
G1 X110.908 Y108.605 E.05401
; WIPE_START
G1 X109.757 Y109.757 E-.61876
G1 X110.019 Y110.019 E-.14124
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.6 I-.913 J.805 P1  F36000
G1 X149.917 Y155.29 Z5.6
G1 Z5.2
G1 E.8 F1800
G1 F15476.087
G1 X148.766 Y156.442 E.05401
G1 X149.543 Y157.219 E.03647
G1 X150.695 Y156.068 E.05401
G1 X156.068 Y150.695 F36000
G1 F15476.087
G1 X157.219 Y149.543 E.05401
G1 X156.442 Y148.766 E.03647
G1 X155.156 Y150.051 E.06031
G3 X155.378 Y150.614 I-.17 J.392 E.02229
G1 X152.996 Y152.996 E.11174
G1 X155.502 Y155.502 E.11757
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.453 Y152.968 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 5.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X155.604 Y154.12 E-.61876
G1 X155.341 Y154.383 E-.14124
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
G1 X134.158 Y134.946
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X134.182 Y134.914 E.0013
G3 X136.072 Y133.828 I1.955 J1.213 E.07532
G3 X136.454 Y133.849 I.082 J1.998 E.01271
G3 X134.005 Y135.263 I-.316 J2.279 E.37853
G1 X134.132 Y135 E.00969
G1 X134.247 Y135.836 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X136.088 Y134.219 I1.886 J.291 E.08173
G3 X136.4 Y134.238 I.061 J1.635 E.00962
G3 X134.239 Y135.896 I-.267 J1.89 E.27531
; WIPE_START
M204 S10000
G1 X134.279 Y135.646 E-.09594
G1 X134.359 Y135.407 E-.09595
G1 X134.504 Y135.126 E-.12002
G1 X134.61 Y134.967 E-.07257
G1 X134.777 Y134.777 E-.09616
G1 X134.968 Y134.61 E-.0962
G1 X135.126 Y134.504 E-.07239
G1 X135.385 Y134.37 E-.11077
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.8 I.824 J-.896 P1  F36000
G1 X112.946 Y113.731 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X112.969 Y113.701 E.00126
G3 X114.859 Y112.614 I1.955 J1.213 E.07531
G3 X115.241 Y112.635 I.082 J2.002 E.0127
G3 X112.792 Y114.049 I-.316 J2.279 E.37853
G1 X112.92 Y113.785 E.00975
G1 X113.107 Y114.309 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X113.152 Y114.196 E.00375
G3 X114.875 Y113.006 I1.768 J.718 E.0681
G3 X115.187 Y113.024 I.061 J1.636 E.00961
G3 X113.073 Y114.435 I-.267 J1.89 E.28306
G1 X113.091 Y114.367 E.00215
; WIPE_START
M204 S10000
G1 X113.152 Y114.196 E-.06908
G1 X113.291 Y113.913 E-.12003
G1 X113.397 Y113.754 E-.07232
G1 X113.564 Y113.564 E-.09618
G1 X113.754 Y113.397 E-.09618
G1 X113.913 Y113.291 E-.07231
G1 X114.193 Y113.146 E-.12025
G1 X114.434 Y113.066 E-.0963
G1 X114.479 Y113.057 E-.01735
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.8 I-.855 J.866 P1  F36000
G1 X154.616 Y152.639 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X148.059 Y159.196 E.21484
G1 X146.789 Y157.926 E.05957
G1 X150.801 Y153.914 E.18819
G1 X140.368 Y143.481 E.48942
G1 X138.116 Y145.733 E.10563
G1 X105.31 Y112.926 E1.53904
G1 X107.561 Y110.675 E.10563
G1 X97.98 Y101.093 E.44948
G1 X101.093 Y97.98 E.14605
G1 X107.876 Y104.763 E.31819
G1 X110.675 Y107.561 E.13129
G1 X112.926 Y105.31 E.10563
G1 X145.733 Y138.116 E1.53904
G1 X143.481 Y140.368 E.10563
G1 X153.914 Y150.801 E.48942
G1 X157.926 Y146.789 E.18819
G1 X159.196 Y148.059 E.05957
G1 X154.658 Y152.596 E.21285
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X148.059 Y159.75 E.19901
G1 X146.235 Y157.926 E.07928
G1 X150.246 Y153.914 E.17432
G1 X140.368 Y144.036 E.42926
G1 X138.116 Y146.288 E.09785
G1 X104.755 Y112.926 E1.44971
G1 X107.007 Y110.675 E.09785
G1 X97.425 Y101.093 E.41635
G1 X101.093 Y97.425 E.15938
G1 X108.153 Y104.485 E.30679
G1 X110.675 Y107.007 E.10957
M73 P82 R3
G1 X112.926 Y104.755 E.09785
G1 X117.485 Y109.314 E.1981
G1 X146.288 Y138.116 E1.25161
G1 X144.036 Y140.368 E.09785
G1 X153.914 Y150.246 E.42926
G1 X157.926 Y146.235 E.17432
G1 X159.75 Y148.059 E.07928
G1 X155.213 Y152.596 E.19717
M204 S10000
G1 X154.453 Y152.968 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.604 Y154.12 E.05401
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X152.996 Y152.996 E.11757
G1 X155.378 Y150.614 E.11174
G2 X155.156 Y150.051 I-.392 J-.17 E.02229
G1 X156.442 Y148.766 E.06031
G1 X157.219 Y149.543 E.03647
G1 X156.068 Y150.695 E.05401
G1 X154.09 Y151.264 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53922
G1 F12000
G1 X154.867 Y150.486 E.04449
G1 X154.09 Y151.264 F36000
; LINE_WIDTH: 0.519349
G1 F12000
G1 X153.987 Y151.25 E.00403
; LINE_WIDTH: 0.479605
G1 X153.884 Y151.236 E.0037
; LINE_WIDTH: 0.420126
G1 X153.781 Y151.222 E.00319
G1 X143.06 Y140.501 E.46602
; LINE_WIDTH: 0.440492
G1 X143.036 Y140.409 E.00309
; LINE_WIDTH: 0.481495
G1 X143.013 Y140.317 E.00341
; LINE_WIDTH: 0.522499
G1 X142.989 Y140.224 E.00373
G1 X142.868 Y140.317 E.00596
; LINE_WIDTH: 0.481495
G1 X142.746 Y140.409 E.00545
; LINE_WIDTH: 0.420981
G1 X142.625 Y140.501 E.0047
G1 X140.501 Y142.625 E.09252
; LINE_WIDTH: 0.439859
G1 X140.398 Y142.756 E.00539
; LINE_WIDTH: 0.479595
G1 X140.296 Y142.887 E.00593
; LINE_WIDTH: 0.519332
G1 X140.193 Y143.018 E.00647
G1 X140.296 Y143.032 E.00403
; LINE_WIDTH: 0.479595
G1 X140.398 Y143.046 E.0037
; LINE_WIDTH: 0.420126
G1 X140.501 Y143.06 E.00319
G1 X151.222 Y153.781 E.46602
; LINE_WIDTH: 0.440489
G1 X151.246 Y153.873 E.00309
; LINE_WIDTH: 0.481485
G1 X151.27 Y153.965 E.00341
; LINE_WIDTH: 0.522482
G1 X151.293 Y154.058 E.00373
G1 X151.415 Y153.965 E.00596
; LINE_WIDTH: 0.481485
G1 X151.536 Y153.873 E.00545
; LINE_WIDTH: 0.42098
G1 X151.657 Y153.781 E.0047
G1 X153.781 Y151.657 E.09252
; LINE_WIDTH: 0.439862
G1 X153.871 Y151.542 E.00474
; LINE_WIDTH: 0.479605
G1 X153.962 Y151.427 E.00522
; LINE_WIDTH: 0.519349
G1 X154.053 Y151.311 E.00569
G1 X153.465 Y151.44 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X142.843 Y140.817 E.46159
G1 X140.817 Y142.843 E.08802
G1 X151.44 Y153.465 E.46159
G1 X153.423 Y151.482 E.08618
G1 X152.932 Y151.44 F36000
G1 F12000
G1 X142.843 Y141.35 E.43842
G1 X141.35 Y142.843 E.06485
G1 X151.44 Y152.932 E.43842
G1 X152.89 Y151.482 E.063
G1 X152.399 Y151.44 F36000
G1 F12000
G1 X142.843 Y141.884 E.41525
G1 X141.884 Y142.843 E.04167
G1 X151.44 Y152.399 E.41525
G1 X152.356 Y151.482 E.03983
G1 X151.786 Y151.44 F36000
; LINE_WIDTH: 0.53254
G1 F12000
G1 X142.843 Y142.496 E.50461
G1 X142.496 Y142.843 E.01954
G1 X151.44 Y151.786 E.50461
G1 X151.743 Y151.482 E.01714
G1 X150.444 Y154.91 F36000
; LINE_WIDTH: 0.53922
G1 F12000
G1 X151.252 Y154.101 E.04624
; WIPE_START
G1 X150.444 Y154.91 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.047 Y149.513 Z5.8 F36000
G1 X139.372 Y143.838 Z5.8
G1 Z5.4
G1 E.8 F1800
; LINE_WIDTH: 0.53919
G1 F12000
G1 X140.15 Y143.061 E.04448
G1 X143.838 Y139.372 F36000
; LINE_WIDTH: 0.53922
G1 F12000
G1 X143.03 Y140.181 E.04624
G1 X140.135 Y142.437 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.286 Y141.286 E.05401
G1 X138.71 Y138.71 E.12085
G1 X139.955 Y137.465 E.0584
G1 X139.955 Y137.124 E.01131
G1 X139.473 Y136.643 E.02259
G1 X139.818 Y136.298 E.01615
G1 X139.818 Y135.957 E.01131
G1 X138.615 Y134.754 E.05644
G1 X138.451 Y134.856 E.00638
G2 X137.489 Y133.856 I-3.14 J2.057 E.04632
G1 X138.6 Y132.745 E.05211
G1 X142.438 Y136.583 E.18005
G1 X136.583 Y142.438 E.27466
G1 X137.734 Y143.589 E.05401
G1 X138.265 Y145 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.462355
G1 F12000
G1 X138.116 Y145.149 E.00717
G1 X105.894 Y112.926 E1.5575
G1 X106.175 Y112.645 E.01358
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X106.191 Y112.63 E.00076
G1 X138.413 Y144.852 E1.5575
G1 X138.397 Y144.868 E.00076
; Slow Down End
; LINE_WIDTH: 0.46235
G1 F12000
G1 X138.307 Y144.958 E.00436
G1 X139.563 Y137.295 F36000
; LINE_WIDTH: 0.410108
G1 F12000
G1 X139.118 Y136.842 E.019
G1 X139.087 Y136.577 E.00796
G1 X139.121 Y136.447 E.00402
; LINE_WIDTH: 0.428978
G1 X139.255 Y136.288 E.00655
; LINE_WIDTH: 0.481786
G1 X139.389 Y136.128 E.00745
G1 X138.777 Y135.517 E.03092
G1 X138.854 Y136.106 E.02124
; LINE_WIDTH: 0.46033
G1 X138.796 Y136.384 E.00967
; LINE_WIDTH: 0.407511
G3 X138.618 Y137.156 I-12.399 J-2.448 E.02355
; LINE_WIDTH: 0.44492
G1 X138.485 Y137.444 E.01037
; LINE_WIDTH: 0.49478
G1 X138.353 Y137.731 E.01166
; LINE_WIDTH: 0.52127
G1 X137.848 Y138.267 E.0287
; LINE_WIDTH: 0.50569
G1 X137.633 Y138.377 E.00912
; LINE_WIDTH: 0.47141
G1 X137.418 Y138.488 E.00844
; LINE_WIDTH: 0.43713
G1 X137.203 Y138.599 E.00777
; LINE_WIDTH: 0.412984
G3 X136.16 Y138.843 I-2.239 J-7.205 E.03232
; LINE_WIDTH: 0.479216
G1 X135.517 Y138.777 E.023
G1 X136.128 Y139.389 E.03074
; LINE_WIDTH: 0.466823
G1 X136.287 Y139.254 E.00719
; LINE_WIDTH: 0.432308
G1 X136.446 Y139.12 E.0066
; LINE_WIDTH: 0.41384
G1 X136.73 Y139.08 E.00868
G1 X136.839 Y139.12 E.00352
G1 X137.281 Y139.557 E.01878
G1 X137.668 Y139.198 E.01595
; LINE_WIDTH: 0.438397
G1 X137.81 Y139.029 E.00712
; LINE_WIDTH: 0.47521
G1 X137.953 Y138.861 E.00778
; LINE_WIDTH: 0.52578
G1 X138.096 Y138.692 E.00869
G1 X138.667 Y138.122 E.03176
; LINE_WIDTH: 0.510549
G1 X138.846 Y137.969 E.00897
; LINE_WIDTH: 0.474325
G1 X139.025 Y137.815 E.00828
; LINE_WIDTH: 0.426153
G2 X139.526 Y137.339 I-2.834 J-3.489 E.02162
G1 X139.026 Y137.248 F36000
; LINE_WIDTH: 0.47502
G1 F12000
G2 X139.02 Y137.341 I-.027 J.045 E.00759
G1 X137.322 Y138.952 F36000
; LINE_WIDTH: 0.47498
G1 F12000
G2 X137.316 Y139.046 I-.027 J.045 E.00758
; WIPE_START
G1 X137.268 Y139.046 E-.17371
G1 X137.241 Y138.999 E-.19544
G1 X137.268 Y138.952 E-.19544
G1 X137.322 Y138.952 E-.19542
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.8 I1.21 J-.13 P1  F36000
G1 X136.731 Y133.473 Z5.8
G1 Z5.4
G1 E.8 F1800
; LINE_WIDTH: 0.48694
G1 F12000
G1 X136.128 Y132.869 E.03088
; LINE_WIDTH: 0.468665
G1 X135.969 Y133.003 E.0072
; LINE_WIDTH: 0.432115
G1 X135.81 Y133.136 E.00658
; LINE_WIDTH: 0.411292
G1 X135.499 Y133.174 E.00939
G3 X134.947 Y132.699 I3.732 J-4.894 E.02187
; LINE_WIDTH: 0.438795
G1 X134.694 Y132.979 E.01218
; LINE_WIDTH: 0.476405
G1 X134.441 Y133.259 E.01334
; LINE_WIDTH: 0.523858
G3 X133.626 Y134.094 I-7.959 J-6.948 E.04574
; LINE_WIDTH: 0.506924
G1 X133.428 Y134.268 E.00998
; LINE_WIDTH: 0.47215
G1 X133.229 Y134.442 E.00924
; LINE_WIDTH: 0.423331
G2 X132.699 Y134.975 I2.245 J2.762 E.02336
G1 X133.138 Y135.414 E.01926
; LINE_WIDTH: 0.393963
G1 X133.168 Y135.679 E.00761
G1 X133.136 Y135.81 E.00386
; LINE_WIDTH: 0.430978
G1 X133.002 Y135.969 E.00658
; LINE_WIDTH: 0.482288
G1 X132.868 Y136.128 E.00745
G1 X133.474 Y136.734 E.03069
G1 X133.402 Y136.182 E.01993
; LINE_WIDTH: 0.460105
G1 X133.459 Y135.888 E.0102
; LINE_WIDTH: 0.406182
G3 X133.644 Y135.085 I7.167 J1.228 E.0244
; LINE_WIDTH: 0.44398
G1 X133.788 Y134.786 E.01085
; LINE_WIDTH: 0.49196
G1 X133.932 Y134.487 E.01215
; LINE_WIDTH: 0.52013
G1 X134.434 Y133.966 E.02813
; LINE_WIDTH: 0.506924
G1 X134.651 Y133.859 E.00916
; LINE_WIDTH: 0.47215
G1 X134.868 Y133.751 E.00847
; LINE_WIDTH: 0.437377
G1 X135.085 Y133.644 E.00778
; LINE_WIDTH: 0.408295
G3 X136.044 Y133.426 I2.254 J7.728 E.02929
; LINE_WIDTH: 0.484631
G1 X136.104 Y133.404 E.0023
G1 X136.672 Y133.466 E.02057
G1 X134.988 Y133.209 F36000
; LINE_WIDTH: 0.47358
G1 F12000
G2 X134.982 Y133.303 I-.027 J.045 E.00752
G1 X133.283 Y134.915 F36000
; LINE_WIDTH: 0.4736
G1 F12000
G2 X133.277 Y135.008 I-.027 J.045 E.00752
G1 X123.917 Y129.772 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X125.069 Y130.924 E.05401
G1 X130.924 Y125.069 E.27466
G1 X127.086 Y121.231 E.18005
G1 X121.231 Y127.086 E.27466
G1 X117.393 Y123.248 E.18005
G1 X123.248 Y117.393 E.27466
G1 X124.399 Y118.544 E.05401
G1 X118.35 Y116.081 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.410109
G1 F12000
G1 X117.905 Y115.628 E.019
G1 X117.873 Y115.364 E.00797
G1 X117.908 Y115.234 E.00403
; LINE_WIDTH: 0.428998
G1 X118.042 Y115.074 E.00655
; LINE_WIDTH: 0.481806
G1 X118.175 Y114.915 E.00745
G1 X117.564 Y114.303 E.03092
G1 X117.641 Y114.892 E.02124
; LINE_WIDTH: 0.460345
G1 X117.583 Y115.171 E.00968
; LINE_WIDTH: 0.407514
G3 X117.405 Y115.943 I-12.391 J-2.445 E.02355
; LINE_WIDTH: 0.44492
G1 X117.272 Y116.231 E.01037
; LINE_WIDTH: 0.49478
G1 X117.139 Y116.518 E.01166
; LINE_WIDTH: 0.521265
G1 X116.634 Y117.054 E.0287
; LINE_WIDTH: 0.505682
G1 X116.419 Y117.164 E.00912
; LINE_WIDTH: 0.471405
G1 X116.204 Y117.275 E.00844
; LINE_WIDTH: 0.437129
G1 X115.989 Y117.385 E.00777
; LINE_WIDTH: 0.412997
G3 X114.947 Y117.63 I-2.236 J-7.19 E.03232
; LINE_WIDTH: 0.479248
G1 X114.303 Y117.564 E.023
G1 X114.915 Y118.175 E.03074
; LINE_WIDTH: 0.46684
G1 X115.074 Y118.041 E.00719
; LINE_WIDTH: 0.43232
G1 X115.232 Y117.906 E.0066
; LINE_WIDTH: 0.413836
G1 X115.517 Y117.866 E.00868
G1 X115.626 Y117.907 E.00352
G1 X116.068 Y118.344 E.01878
G1 X116.454 Y117.985 E.01595
; LINE_WIDTH: 0.438399
G1 X116.597 Y117.816 E.00712
; LINE_WIDTH: 0.475215
G1 X116.74 Y117.647 E.00778
; LINE_WIDTH: 0.525794
G1 X116.882 Y117.479 E.00869
G1 X117.454 Y116.909 E.03176
; LINE_WIDTH: 0.510565
G1 X117.633 Y116.755 E.00897
; LINE_WIDTH: 0.474335
G1 X117.811 Y116.602 E.00828
; LINE_WIDTH: 0.426155
G2 X118.313 Y116.126 I-2.833 J-3.488 E.02161
G1 X117.813 Y116.035 F36000
; LINE_WIDTH: 0.47496
G1 F12000
G2 X117.807 Y116.128 I-.027 J.045 E.00759
G1 X116.108 Y117.739 F36000
; LINE_WIDTH: 0.47502
G1 F12000
G2 X116.102 Y117.832 I-.027 J.045 E.00759
G1 X113.637 Y117.235 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X113.541 Y117.401 E.00637
G1 X114.552 Y118.412 E.04743
G1 X113.555 Y119.41 E.04678
G1 X109.717 Y115.572 E.18005
G1 X111.229 Y114.06 E.07094
G1 X111.569 Y114.4 E.01597
G1 X111.225 Y114.744 E.01615
G2 X111.451 Y115.311 I.396 J.17 E.02247
; WIPE_START
G1 X111.225 Y115.085 E-.12128
G1 X111.225 Y114.744 E-.12953
G1 X111.569 Y114.4 E-.18506
G1 X111.229 Y114.06 E-.18289
G1 X110.966 Y114.322 E-.14124
; WIPE_END
G1 E-.04 F1800
G17
G3 Z5.8 I.504 J1.108 P1  F36000
G1 X115.509 Y112.255 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.49339
G1 F12000
G1 X114.915 Y111.661 E.03085
; LINE_WIDTH: 0.473993
G1 X114.756 Y111.792 E.00724
; LINE_WIDTH: 0.435198
G1 X114.597 Y111.923 E.00658
; LINE_WIDTH: 0.415483
G1 X114.334 Y111.964 E.00808
G1 X114.201 Y111.925 E.00422
G1 X113.756 Y111.48 E.01911
G1 X113.402 Y111.817 E.01484
; LINE_WIDTH: 0.438794
G1 X113.26 Y111.987 E.00715
; LINE_WIDTH: 0.4764
G1 X113.117 Y112.156 E.00782
; LINE_WIDTH: 0.525368
G1 X112.974 Y112.325 E.00871
G1 X112.413 Y112.881 E.03104
; LINE_WIDTH: 0.506915
G1 X112.214 Y113.055 E.00998
; LINE_WIDTH: 0.472145
G1 X112.016 Y113.229 E.00923
; LINE_WIDTH: 0.42333
G2 X111.486 Y113.762 I2.244 J2.761 E.02336
G1 X111.925 Y114.201 E.01926
; LINE_WIDTH: 0.407218
G1 X111.939 Y114.342 E.0042
; LINE_WIDTH: 0.385926
G3 X111.922 Y114.596 I-.337 J.106 E.0073
; LINE_WIDTH: 0.430993
G1 X111.788 Y114.756 E.00658
; LINE_WIDTH: 0.482289
G1 X111.654 Y114.915 E.00745
G1 X112.261 Y115.521 E.03069
G1 X112.189 Y114.969 E.01994
; LINE_WIDTH: 0.460105
G1 X112.245 Y114.674 E.01019
; LINE_WIDTH: 0.406181
G3 X112.43 Y113.872 I7.171 J1.229 E.0244
; LINE_WIDTH: 0.443975
G1 X112.574 Y113.573 E.01085
; LINE_WIDTH: 0.491945
G1 X112.718 Y113.273 E.01215
; LINE_WIDTH: 0.52011
G1 X113.221 Y112.753 E.02813
; LINE_WIDTH: 0.506907
G1 X113.438 Y112.646 E.00915
; LINE_WIDTH: 0.47214
G1 X113.655 Y112.538 E.00847
; LINE_WIDTH: 0.437374
G1 X113.872 Y112.43 E.00778
; LINE_WIDTH: 0.40442
G1 X114.378 Y112.308 E.01536
; LINE_WIDTH: 0.406274
G1 X114.556 Y112.273 E.00537
; LINE_WIDTH: 0.44112
G1 X114.735 Y112.239 E.00589
; LINE_WIDTH: 0.489015
G1 X114.913 Y112.204 E.00659
G1 X115.316 Y112.213 E.01466
G1 X115.45 Y112.242 E.005
G1 X113.775 Y111.996 F36000
; LINE_WIDTH: 0.47358
G1 F12000
G2 X113.769 Y112.089 I-.027 J.045 E.00753
G1 X112.07 Y113.701 F36000
G1 F12000
G2 X112.064 Y113.795 I-.027 J.045 E.00753
G1 X110.908 Y108.605 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X109.757 Y109.757 E.05401
G1 X112.333 Y112.333 E.12085
G1 X113.578 Y111.088 E.0584
G1 X113.918 Y111.088 E.01131
G1 X114.06 Y111.229 E.00662
G1 X115.572 Y109.717 E.07094
G1 X119.41 Y113.555 E.18005
G1 X118.412 Y114.552 E.04678
G3 X118.605 Y115.085 I-.17 J.363 E.02088
G1 X118.26 Y115.43 E.01615
G1 X118.742 Y115.911 E.02259
G1 X118.742 Y116.252 E.01131
G1 X117.497 Y117.497 E.0584
G1 X133.546 Y133.546 E.7529
G1 X132.301 Y134.791 E.0584
G1 X132.301 Y135.132 E.01131
G1 X132.782 Y135.613 E.02259
G1 X132.438 Y135.957 E.01615
G1 X132.438 Y136.298 E.01131
G1 X133.64 Y137.501 E.0564
G1 X133.809 Y137.398 E.00657
G1 X133.856 Y137.489 E.00339
G1 X132.745 Y138.6 E.05211
G1 X128.907 Y134.762 E.18005
G1 X134.762 Y128.907 E.27466
G1 X135.913 Y130.058 E.05401
; WIPE_START
G1 X134.762 Y128.907 E-.61876
G1 X134.499 Y129.17 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X138.436 Y135.708 Z5.8 F36000
G1 X150.695 Y156.068 Z5.8
G1 Z5.4
G1 E.8 F1800
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X149.917 Y155.29 E.05401
; WIPE_START
G1 X148.766 Y156.442 E-.61876
G1 X149.029 Y156.705 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X144.318 Y150.699 Z5.8 F36000
G1 X110.85 Y108.025 Z5.8
G1 Z5.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53919
G1 F12000
G1 X111.628 Y107.247 E.04449
G1 X110.85 Y108.025 F36000
; LINE_WIDTH: 0.519315
G1 F12000
G1 X110.747 Y108.011 E.00403
; LINE_WIDTH: 0.479585
G1 X110.644 Y107.996 E.0037
; LINE_WIDTH: 0.420058
G1 X110.541 Y107.982 E.00319
G1 X101.093 Y98.534 E.41062
G1 X98.534 Y101.093 E.11121
G1 X107.982 Y110.541 E.41062
; LINE_WIDTH: 0.440492
G1 X108.006 Y110.634 E.00309
; LINE_WIDTH: 0.481495
G1 X108.03 Y110.726 E.00341
; LINE_WIDTH: 0.522499
G1 X108.054 Y110.818 E.00373
G1 X108.175 Y110.726 E.00596
; LINE_WIDTH: 0.481495
G1 X108.296 Y110.634 E.00545
; LINE_WIDTH: 0.420981
G1 X108.418 Y110.541 E.0047
G1 X110.541 Y108.418 E.09252
; LINE_WIDTH: 0.439855
G1 X110.632 Y108.302 E.00474
; LINE_WIDTH: 0.479585
G1 X110.722 Y108.187 E.00522
; LINE_WIDTH: 0.519315
G1 X110.813 Y108.072 E.00569
G1 X110.226 Y108.2 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X101.093 Y99.068 E.39683
G1 X99.068 Y101.093 E.08802
G1 X108.2 Y110.226 E.39683
G1 X110.183 Y108.242 E.08617
G1 X109.692 Y108.2 F36000
G1 F12000
G1 X101.093 Y99.601 E.37366
G1 X99.601 Y101.093 E.06485
G1 X108.2 Y109.692 E.37366
G1 X109.65 Y108.242 E.063
G1 X109.159 Y108.2 F36000
G1 F12000
G1 X101.093 Y100.134 E.35049
G1 X100.134 Y101.093 E.04168
G1 X108.2 Y109.159 E.35049
G1 X109.117 Y108.242 E.03983
G1 X108.546 Y108.2 F36000
; LINE_WIDTH: 0.53254
G1 F12000
G1 X101.093 Y100.747 E.42053
G1 X100.747 Y101.093 E.01954
G1 X108.2 Y108.546 E.42053
G1 X108.504 Y108.242 E.01714
G1 X107.204 Y111.67 F36000
; LINE_WIDTH: 0.53922
G1 F12000
G1 X108.013 Y110.862 E.04624
G1 X112.645 Y106.175 F36000
; LINE_WIDTH: 0.462355
G1 F12000
G1 X112.926 Y105.894 E.01358
G1 X145.149 Y138.116 E1.5575
G1 X144.868 Y138.397 E.01358
; Slow Down Start
; LINE_WIDTH: 0.462351
G1 F3000;_EXTRUDE_SET_SPEED
G1 X144.852 Y138.413 E.00076
G1 X141.835 Y135.396 E.14581
; Slow Down End
; LINE_WIDTH: 0.462352
G1 F12000
G1 X136.859 Y130.42 E.24052
; Slow Down Start
; LINE_WIDTH: 0.462355
G1 F3000;_EXTRUDE_SET_SPEED
G1 X120.622 Y114.183 E.78484
; Slow Down End
; LINE_WIDTH: 0.462359
G1 F12000
G1 X115.646 Y109.207 E.24052
; Slow Down Start
; LINE_WIDTH: 0.46236
G1 F3000;_EXTRUDE_SET_SPEED
G1 X112.656 Y106.217 E.14452
; Slow Down End
; CHANGE_LAYER
; Z_HEIGHT: 5.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F3000
G1 X114.071 Y107.632 E-.76
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
G1 X134.172 Y134.925
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X134.189 Y134.891 E.00126
G3 X136.056 Y133.828 I1.94 J1.236 E.07417
G3 X135.721 Y138.39 I.073 J2.299 E.2557
G3 X133.996 Y135.266 I.407 J-2.263 E.13554
G1 X134.144 Y134.978 E.01072
G1 X134.26 Y135.743 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.282 Y135.654 E.00283
G3 X136.072 Y134.22 I1.848 J.473 E.0756
G3 X136.328 Y134.229 I.071 J1.538 E.00786
G3 X134.248 Y135.819 I-.197 J1.897 E.2796
G1 X134.25 Y135.802 E.00051
; WIPE_START
M204 S10000
G1 X134.282 Y135.654 E-.05777
G1 X134.357 Y135.412 E-.09632
G1 X134.517 Y135.107 E-.13052
G1 X134.609 Y134.969 E-.06338
G1 X134.777 Y134.777 E-.09681
G1 X134.969 Y134.609 E-.09681
G1 X135.108 Y134.517 E-.06348
G1 X135.412 Y134.357 E-.13042
G1 X135.473 Y134.337 E-.0245
; WIPE_END
G1 E-.04 F1800
G17
G3 Z6 I.822 J-.897 P1  F36000
G1 X112.958 Y113.712 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X112.977 Y113.68 E.00122
G3 X114.843 Y112.615 I1.941 J1.233 E.07417
M73 P83 R3
G3 X115.151 Y112.626 I.09 J1.853 E.01024
G3 X112.785 Y114.053 I-.234 J2.288 E.38091
G1 X112.931 Y113.765 E.01071
G1 X113.148 Y114.2 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X114.859 Y113.007 I1.769 J.713 E.06782
G3 X115.114 Y113.016 I.071 J1.536 E.00785
G3 X113.127 Y114.256 I-.197 J1.897 E.29072
; WIPE_START
M204 S10000
G1 X113.303 Y113.894 E-.15305
G1 X113.396 Y113.756 E-.06338
G1 X113.564 Y113.564 E-.09681
G1 X113.756 Y113.396 E-.09681
G1 X113.895 Y113.303 E-.06348
G1 X114.198 Y113.144 E-.13041
G1 X114.441 Y113.064 E-.09696
G1 X114.594 Y113.036 E-.0591
; WIPE_END
G1 E-.04 F1800
G17
G3 Z6 I-.856 J.865 P1  F36000
G1 X154.616 Y152.639 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X148.15 Y159.105 E.21059
G1 X146.88 Y157.835 E.05957
G1 X151.095 Y153.62 E.19774
G1 X140.662 Y143.187 E.48942
G1 X138.245 Y145.605 E.11341
G1 X105.438 Y112.798 E1.53904
G1 X107.855 Y110.38 E.11341
G1 X98.274 Y100.799 E.44948
G1 X100.799 Y98.274 E.11845
G1 X102.649 Y100.124 E.0868
G1 X110.38 Y107.855 E.36268
G1 X112.798 Y105.438 E.11341
G1 X145.605 Y138.245 E1.53904
G1 X143.187 Y140.662 E.11341
G1 X153.62 Y151.095 E.48942
G1 X157.835 Y146.88 E.19774
G1 X159.105 Y148.15 E.05957
G1 X154.658 Y152.596 E.2086
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X148.15 Y159.659 E.19507
G1 X146.325 Y157.835 E.07928
G1 X150.541 Y153.62 E.18317
G1 X140.662 Y143.742 E.42926
G1 X138.245 Y146.159 E.10505
G1 X104.884 Y112.798 E1.44971
G1 X107.301 Y110.38 E.10505
G1 X97.72 Y100.799 E.41635
G1 X100.799 Y97.72 E.13381
G1 X102.926 Y99.847 E.09245
G1 X110.38 Y107.301 E.32391
G1 X112.798 Y104.884 E.10505
G1 X146.159 Y138.245 E1.44971
G1 X143.742 Y140.662 E.10505
G1 X153.62 Y150.541 E.42926
G1 X157.835 Y146.325 E.18317
G1 X159.659 Y148.15 E.07928
G1 X155.213 Y152.596 E.19323
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.795 Y151.558 Z6 F36000
G1 Z5.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53923
G1 F12000
G1 X154.867 Y150.486 E.06132
G1 X153.795 Y151.558 F36000
; LINE_WIDTH: 0.519365
G1 F12000
G1 X153.692 Y151.544 E.00403
; LINE_WIDTH: 0.479615
G1 X153.59 Y151.53 E.0037
; LINE_WIDTH: 0.420126
G1 X153.487 Y151.516 E.00319
G1 X142.766 Y140.796 E.46602
; LINE_WIDTH: 0.440489
G1 X142.742 Y140.703 E.00309
; LINE_WIDTH: 0.481485
G1 X142.718 Y140.611 E.00341
; LINE_WIDTH: 0.522482
G1 X142.695 Y140.519 E.00372
G1 X142.573 Y140.611 E.00596
; LINE_WIDTH: 0.481485
G1 X142.452 Y140.703 E.00545
; LINE_WIDTH: 0.421335
G1 X142.331 Y140.796 E.0047
G1 X140.796 Y142.331 E.06695
; LINE_WIDTH: 0.439862
G1 X140.693 Y142.462 E.00539
; LINE_WIDTH: 0.479605
G1 X140.59 Y142.593 E.00593
; LINE_WIDTH: 0.519349
G1 X140.487 Y142.724 E.00647
G1 X140.59 Y142.738 E.00403
; LINE_WIDTH: 0.479605
G1 X140.693 Y142.752 E.0037
; LINE_WIDTH: 0.420126
G1 X140.796 Y142.766 E.00319
G1 X151.516 Y153.487 E.46602
; LINE_WIDTH: 0.440495
G1 X151.54 Y153.579 E.00309
; LINE_WIDTH: 0.481505
G1 X151.564 Y153.671 E.00341
; LINE_WIDTH: 0.522515
G1 X151.588 Y153.764 E.00373
G1 X151.709 Y153.671 E.00596
; LINE_WIDTH: 0.481505
G1 X151.83 Y153.579 E.00545
; LINE_WIDTH: 0.421336
G1 X151.951 Y153.487 E.0047
G1 X153.487 Y151.951 E.06695
; LINE_WIDTH: 0.439865
G1 X153.577 Y151.836 E.00474
; LINE_WIDTH: 0.479615
G1 X153.668 Y151.721 E.00522
; LINE_WIDTH: 0.519365
G1 X153.758 Y151.606 E.00569
G1 X153.171 Y151.734 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X142.548 Y141.111 E.46159
G1 X141.111 Y142.548 E.06245
G1 X151.734 Y153.171 E.46159
G1 X153.129 Y151.776 E.06061
G1 X152.638 Y151.734 F36000
G1 F12000
G1 X142.548 Y141.645 E.43842
G1 X141.645 Y142.548 E.03928
G1 X151.734 Y152.638 E.43842
G1 X152.595 Y151.776 E.03743
G1 X152.052 Y151.734 F36000
; LINE_WIDTH: 0.493525
G1 F12000
G1 X142.548 Y142.23 E.49353
G1 X142.23 Y142.548 E.01655
G1 X151.734 Y152.052 E.49353
G1 X152.01 Y151.776 E.01434
; WIPE_START
G1 X151.734 Y152.052 E-.14843
G1 X150.596 Y150.914 E-.61157
; WIPE_END
G1 E-.04 F1800
G1 X150.444 Y154.91 Z6 F36000
G1 Z5.6
G1 E.8 F1800
; LINE_WIDTH: 0.53923
G1 F12000
G1 X151.547 Y153.807 E.06306
; WIPE_START
G1 X150.444 Y154.91 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X145.047 Y149.513 Z6 F36000
G1 X139.372 Y143.838 Z6
G1 Z5.6
G1 E.8 F1800
; LINE_WIDTH: 0.5392
G1 F12000
G1 X140.444 Y142.766 E.06131
G1 X143.838 Y139.372 F36000
; LINE_WIDTH: 0.53921
G1 F12000
G1 X142.736 Y140.475 E.06306
G1 X138.404 Y144.84 F36000
; LINE_WIDTH: 0.49275
G1 F12000
G1 X138.245 Y144.999 E.00824
G1 X106.044 Y112.798 E1.66925
G1 X106.35 Y112.492 E.01584
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X106.362 Y112.48 E.00065
G1 X138.563 Y144.681 E1.66925
G1 X138.55 Y144.693 E.00065
; Slow Down End
G1 F12000
G1 X138.446 Y144.797 E.0054
; WIPE_START
G1 X138.55 Y144.693 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X144.121 Y149.911 Z6 F36000
G1 X150.695 Y156.068 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X150.051 Y155.156 E.06031
G2 X150.614 Y155.378 I.392 J-.17 E.02229
G1 X152.996 Y152.996 E.11174
G1 X155.502 Y155.502 E.11757
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.123 Y152.639 E.06947
G1 X157.219 Y149.543 E.14523
G1 X156.442 Y148.766 E.03647
G1 X155.29 Y149.917 E.05401
; WIPE_START
G1 X156.442 Y148.766 E-.61876
G1 X156.705 Y149.029 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X151.116 Y143.831 Z6 F36000
G1 X125.763 Y120.251 Z6
G1 Z5.6
G1 E.8 F1800
G1 F15476.087
G1 X126.914 Y121.402 E.05401
G1 X121.402 Y126.914 E.25858
G1 X125.24 Y130.752 E.18005
G1 X130.752 Y125.24 E.25858
G1 X134.59 Y129.078 E.18005
G1 X129.078 Y134.59 E.25858
G1 X130.23 Y135.742 E.05401
G1 X108.737 Y114.249 F36000
G1 F15476.087
G1 X109.888 Y115.4 E.05401
G1 X115.4 Y109.888 E.25858
G1 X112.12 Y106.608 E.15388
G1 X111.916 Y106.812 E.00955
G3 X112.138 Y107.375 I-.17 J.392 E.02229
G1 X109.757 Y109.757 E.11174
G1 X113.039 Y113.039 E.15399
G2 X115.459 Y117.506 I1.903 J1.858 E.22406
G1 X113.726 Y119.238 E.08127
G1 X117.564 Y123.076 E.18005
G1 X123.076 Y117.564 E.25858
G1 X119.238 Y113.726 E.18005
G1 X117.506 Y115.459 E.08127
G3 X116.786 Y116.786 I-2.605 J-.555 E.05078
G1 X134.252 Y134.252 E.8194
G2 X133.857 Y137.488 I1.979 J1.884 E.11584
G1 X132.916 Y138.428 E.04412
G1 X136.754 Y142.266 E.18005
G1 X142.266 Y136.754 E.25858
G1 X138.428 Y132.916 E.18005
G1 X137.488 Y133.857 E.04412
G3 X137.999 Y137.999 I-1.405 J2.276 E.15882
G1 X141.286 Y141.286 E.15421
G1 X140.135 Y142.437 E.05401
; WIPE_START
G1 X141.286 Y141.286 E-.61876
G1 X141.023 Y141.023 E-.14124
; WIPE_END
G1 E-.04 F1800
G17
G3 Z6 I.89 J-.83 P1  F36000
G1 X110.556 Y108.319 Z6
G1 Z5.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53919
G1 F12000
G1 X111.628 Y107.247 E.06131
G1 X110.556 Y108.319 F36000
; LINE_WIDTH: 0.519315
G1 F12000
G1 X110.453 Y108.305 E.00403
; LINE_WIDTH: 0.479585
M73 P83 R2
G1 X110.35 Y108.291 E.0037
; LINE_WIDTH: 0.42006
G1 X110.247 Y108.277 E.00319
G1 X100.799 Y98.829 E.41063
G1 X98.829 Y100.799 E.08564
G1 X108.277 Y110.247 E.41063
; LINE_WIDTH: 0.440492
G1 X108.3 Y110.339 E.00309
; LINE_WIDTH: 0.481495
G1 X108.324 Y110.432 E.00341
; LINE_WIDTH: 0.522499
G1 X108.348 Y110.524 E.00373
G1 X108.469 Y110.432 E.00596
; LINE_WIDTH: 0.481495
G1 X108.591 Y110.339 E.00545
; LINE_WIDTH: 0.421335
G1 X108.712 Y110.247 E.0047
G1 X110.247 Y108.712 E.06695
; LINE_WIDTH: 0.439855
G1 X110.338 Y108.597 E.00474
; LINE_WIDTH: 0.479585
G1 X110.428 Y108.481 E.00522
; LINE_WIDTH: 0.519315
G1 X110.519 Y108.366 E.00569
G1 X109.931 Y108.494 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X100.799 Y99.362 E.39683
G1 X99.362 Y100.799 E.06245
G1 X108.494 Y109.931 E.39683
G1 X109.889 Y108.537 E.06061
G1 X109.398 Y108.494 F36000
G1 F12000
G1 X100.799 Y99.895 E.37366
G1 X99.895 Y100.799 E.03928
G1 X108.494 Y109.398 E.37366
G1 X109.356 Y108.537 E.03743
G1 X108.813 Y108.494 F36000
; LINE_WIDTH: 0.493535
G1 F12000
G1 X100.799 Y100.48 E.41615
G1 X100.48 Y100.799 E.01655
G1 X108.494 Y108.813 E.41615
G1 X108.77 Y108.537 E.01434
; WIPE_START
G1 X108.494 Y108.813 E-.14843
G1 X107.356 Y107.675 E-.61157
; WIPE_END
G1 E-.04 F1800
G1 X107.204 Y111.67 Z6 F36000
G1 Z5.6
G1 E.8 F1800
; LINE_WIDTH: 0.53921
G1 F12000
G1 X108.307 Y110.568 E.06306
G1 X112.798 Y106.044 F36000
; LINE_WIDTH: 0.492755
G1 F12000
G1 X144.999 Y138.245 E1.66927
G1 X144.693 Y138.55 E.01584
; Slow Down Start
; LINE_WIDTH: 0.492755
G1 F3000;_EXTRUDE_SET_SPEED
G1 X144.681 Y138.563 E.00065
G1 X112.48 Y106.362 E1.66927
G1 X112.492 Y106.35 E.00065
; Slow Down End
; LINE_WIDTH: 0.49276
G1 F12000
G1 X112.755 Y106.086 E.01365
; CHANGE_LAYER
; Z_HEIGHT: 5.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X112.492 Y106.35 E-.76
; WIPE_END
M73 P84 R2
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
G1 X134.2 Y134.876
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X134.202 Y134.874 E.00008
G3 X136.041 Y133.829 I1.929 J1.254 E.0729
G3 X136.35 Y133.838 I.102 J1.861 E.0103
G3 X134.128 Y134.995 I-.22 J2.29 E.39163
G1 X134.169 Y134.927 E.00265
G1 X134.302 Y135.609 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.359 Y135.418 E.00612
G3 X136.057 Y134.221 I1.772 J.71 E.06751
G3 X136.314 Y134.228 I.084 J1.545 E.00791
G3 X134.25 Y135.802 I-.183 J1.9 E.28076
G1 X134.286 Y135.667 E.0043
; WIPE_START
M204 S10000
G1 X134.359 Y135.418 E-.09851
G1 X134.529 Y135.089 E-.14062
G1 X134.777 Y134.777 E-.1516
G1 X135.089 Y134.529 E-.1517
G1 X135.416 Y134.355 E-.14067
G1 X135.609 Y134.293 E-.07691
; WIPE_END
G1 E-.04 F1800
G1 X129.969 Y129.15 Z6.2 F36000
G1 X112.986 Y113.663 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X112.988 Y113.661 E.00009
G3 X114.828 Y112.616 I1.929 J1.254 E.07292
G3 X115.137 Y112.624 I.102 J1.871 E.01029
G3 X112.915 Y113.782 I-.22 J2.29 E.3916
G1 X112.956 Y113.715 E.00262
G1 X113.191 Y114.111 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X113.316 Y113.877 E.00814
G3 X114.844 Y113.008 I1.602 J1.038 E.05614
G3 X115.1 Y113.015 I.084 J1.549 E.0079
G3 X113.146 Y114.205 I-.183 J1.9 E.29305
G1 X113.165 Y114.165 E.00137
; WIPE_START
M204 S10000
G1 X113.316 Y113.877 E-.12346
G1 X113.564 Y113.564 E-.15183
G1 X113.876 Y113.315 E-.1517
G1 X114.203 Y113.142 E-.14067
G1 X114.448 Y113.063 E-.09761
G1 X114.695 Y113.028 E-.09473
; WIPE_END
G1 E-.04 F1800
G1 X119.195 Y119.193 Z6.2 F36000
G1 X138.345 Y145.424 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.578 Y112.658 E1.53715
G1 X106.868 Y111.368 E.0605
G1 X107.204 Y111.704 E.01578
G1 X111.704 Y107.204 E.2111
G1 X111.368 Y106.868 E.01578
G1 X112.658 Y105.578 E.0605
G1 X145.464 Y138.385 E1.53904
G1 X144.175 Y139.675 E.0605
G1 X143.838 Y139.338 E.01578
G1 X139.338 Y143.838 E.2111
G1 X139.675 Y144.175 E.01578
G1 X138.387 Y145.462 E.0604
; WIPE_START
G1 X136.973 Y144.048 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X143.835 Y147.389 Z6.2 F36000
G1 X154.616 Y152.639 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X148.246 Y159.008 E.20606
G1 X146.977 Y157.738 E.05957
G1 X150.108 Y154.607 E.14688
G1 X150.444 Y154.944 E.01578
G1 X154.944 Y150.444 E.2111
G1 X154.607 Y150.108 E.01578
G1 X157.738 Y146.977 E.14688
G1 X159.008 Y148.246 E.05957
G1 X154.658 Y152.596 E.20407
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X148.246 Y159.563 E.19087
G1 X146.422 Y157.738 E.07928
G1 X150.911 Y153.25 E.19505
G1 X141.032 Y143.372 E.42926
G1 X138.385 Y146.019 E.11504
G1 X105.024 Y112.658 E1.44971
G1 X107.671 Y110.01 E.11504
G1 X98.09 Y100.429 E.41635
G1 X100.429 Y98.09 E.10165
G1 X106.152 Y103.813 E.2487
G1 X110.01 Y107.671 E.16766
G1 X112.658 Y105.024 E.11504
G1 X146.019 Y138.385 E1.44971
G1 X143.372 Y141.032 E.11504
G1 X153.25 Y150.911 E.42926
G1 X157.738 Y146.422 E.19505
G1 X159.563 Y148.246 E.07928
G1 X155.213 Y152.596 E.18903
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.356 Y150.394 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50814
G1 F13541.982
G2 X154.354 Y150.494 I-.029 J.05 E.0091
; WIPE_START
G1 X154.298 Y150.494 E-.18544
G1 X154.269 Y150.444 E-.19152
G1 X154.298 Y150.394 E-.19154
G1 X154.356 Y150.394 E-.1915
; WIPE_END
G1 E-.04 F1800
G1 X155.29 Y149.917 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.442 Y148.766 E.05401
G1 X157.219 Y149.543 E.03647
G1 X154.123 Y152.639 E.14523
G1 X155.604 Y154.12 E.06947
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X152.94 Y152.94 E.1202
G1 X150.444 Y155.436 E.1171
G1 X150.108 Y155.1 E.01578
G1 X148.766 Y156.442 E.06294
G1 X149.543 Y157.219 E.03647
G1 X150.695 Y156.068 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X152.103 Y152.902 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X141.38 Y142.18 E.46596
G1 X141.113 Y142.446
G1 X151.836 Y153.169 E.46596
G1 X151.569 Y153.436
G1 X140.847 Y142.713 E.46596
G1 X140.855 Y143.255
G1 X140.58 Y142.98 E.01198
G1 X140.311 Y143.244
G1 X140.589 Y143.522 E.01205
; WIPE_START
M204 S10000
G1 X140.311 Y143.244 E-.14908
G1 X140.58 Y142.98 E-.14329
G1 X140.855 Y143.255 E-.14811
G1 X140.847 Y142.713 E-.20608
G1 X141.058 Y142.924 E-.11345
; WIPE_END
G1 E-.04 F1800
G1 X146.312 Y148.46 Z6.2 F36000
G1 X151.027 Y153.427 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X151.303 Y153.702 E.01198
G1 X151.038 Y153.971
G1 X150.76 Y153.693 E.01205
M204 S10000
G1 X153.693 Y150.76 F36000
G1 F12000
M204 S2000
G1 X153.971 Y151.038 E.01205
G1 X153.702 Y151.303
G1 X153.427 Y151.027 E.01198
; WIPE_START
M204 S10000
G1 X153.702 Y151.303 E-.25555
G1 X153.971 Y151.038 E-.24724
G1 X153.693 Y150.76 E-.25721
; WIPE_END
G1 E-.04 F1800
G1 X148.296 Y145.364 Z6.2 F36000
G1 X143.522 Y140.589 Z6.2
G1 Z5.8
G1 E.8 F1800
G1 F12000
M204 S2000
G1 X143.244 Y140.312 E.01205
G1 X142.98 Y140.58
G1 X143.255 Y140.856 E.01198
G1 X142.713 Y140.847
G1 X153.436 Y151.569 E.46596
G1 X153.169 Y151.836
G1 X142.446 Y141.113 E.46596
G1 X142.18 Y141.38
G1 X152.902 Y152.103 E.46596
M204 S10000
G1 X151.032 Y154.022 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.107345
G1 F15000
G1 X150.927 Y154.127 E.00078
; LINE_WIDTH: 0.123454
G1 X150.893 Y154.138 E.00024
; LINE_WIDTH: 0.155674
G1 X150.859 Y154.15 E.00033
; LINE_WIDTH: 0.197144
G1 X150.48 Y153.947 E.0054
G1 X152.314 Y152.718 F36000
; LINE_WIDTH: 0.225467
G1 F15000
G1 X141.564 Y141.968 E.22613
G1 X152.718 Y152.314 F36000
; LINE_WIDTH: 0.225382
G1 F15000
G1 X141.968 Y141.564 E.22603
G1 X143.817 Y140.32 F36000
; LINE_WIDTH: 0.197268
G1 F15000
G1 X143.423 Y140.133 E.00549
; LINE_WIDTH: 0.155727
G1 X143.389 Y140.144 E.00033
; LINE_WIDTH: 0.110528
G1 X143.355 Y140.155 E.0002
G1 X143.25 Y140.26 E.00082
G1 X141.727 Y141.727 F36000
; LINE_WIDTH: 0.416612
G1 F15000
G1 X152.555 Y152.555 E.46631
; WIPE_START
G1 X151.141 Y151.141 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X144.768 Y146.941 Z6.2 F36000
G1 X139.984 Y143.788 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50816
G1 F13541.398
G2 X139.983 Y143.889 I-.029 J.05 E.0091
; WIPE_START
G1 X139.926 Y143.889 E-.18544
G1 X139.897 Y143.838 E-.19152
G1 X139.926 Y143.788 E-.19154
G1 X139.984 Y143.788 E-.1915
; WIPE_END
G1 E-.04 F1800
G1 X140.191 Y142.494 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X141.342 Y141.342 E.05401
G1 X137.998 Y137.998 E.15688
G2 X137.486 Y133.858 I-1.867 J-1.871 E.15947
G1 X138.239 Y133.106 E.03529
G1 X142.077 Y136.944 E.18005
G1 X136.944 Y142.077 E.2408
G1 X133.106 Y138.239 E.18005
G1 X133.858 Y137.486 E.03529
G3 X134.252 Y134.252 I2.29 J-1.362 E.11628
G1 X116.785 Y116.785 E.81944
G2 X117.506 Y115.458 I-1.893 J-1.889 E.05077
G1 X119.049 Y113.916 E.07237
G1 X122.887 Y117.754 E.18005
G1 X117.754 Y122.887 E.2408
G1 X121.592 Y126.725 E.18005
G1 X126.725 Y121.592 E.2408
G1 X130.563 Y125.43 E.18005
G1 X125.43 Y130.563 E.2408
G1 X129.268 Y134.401 E.18005
G1 X134.401 Y129.268 E.2408
G1 X135.552 Y130.419 E.05401
G1 X112.315 Y106.551 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.52756
G1 F3000;_EXTRUDE_SET_SPEED
G1 X112.333 Y106.533 E.00102
; Slow Down End
; LINE_WIDTH: 0.527555
G1 F12000
G1 X112.658 Y106.209 E.01812
G1 X144.834 Y138.385 E1.79703
G1 X144.509 Y138.71 E.01812
; Slow Down Start
; LINE_WIDTH: 0.527555
G1 F3000;_EXTRUDE_SET_SPEED
G1 X144.491 Y138.728 E.00102
; Slow Down End
G1 F12000
G1 X112.357 Y106.594 E1.79466
; WIPE_START
G1 X113.771 Y108.008 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X111.116 Y107.154 Z6.2 F36000
G1 Z5.8
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50814
G1 F13541.982
G2 X111.115 Y107.255 I-.029 J.05 E.0091
G1 X109.316 Y109.316 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.41662
G1 F15000
G1 X99.398 Y99.398 E.42711
G1 X99.006 Y99.806 F36000
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X108.897 Y109.697 E.42981
G1 X108.63 Y109.964
G1 X98.739 Y100.073 E.42981
G1 X98.473 Y100.339
G1 X108.364 Y110.23 E.42981
G1 X108.097 Y110.497
G1 X107.787 Y110.187 E.01346
G1 X107.521 Y110.454
G1 X107.83 Y110.763 E.01346
M204 S10000
G1 X110.763 Y107.831 F36000
G1 F12000
M204 S2000
G1 X110.454 Y107.521 E.01346
G1 X110.187 Y107.788
G1 X110.497 Y108.097 E.01346
G1 X110.23 Y108.364
G1 X100.339 Y98.473 E.42981
G1 X100.073 Y98.739
G1 X109.963 Y108.63 E.42981
G1 X109.697 Y108.897
G1 X99.806 Y99.006 E.42981
M204 S10000
G1 X109.512 Y109.108 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.225375
G1 F15000
G1 X99.595 Y99.191 E.20853
G1 X109.108 Y109.512 F36000
; LINE_WIDTH: 0.225453
G1 F15000
G1 X99.191 Y99.595 E.20862
; WIPE_START
M73 P85 R2
G1 X100.605 Y101.009 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.398 Y106.948 Z6.2 F36000
G1 X108.549 Y110.852 Z6.2
G1 Z5.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X109.701 Y109.701 E.05401
G1 X113.039 Y113.039 E.15662
G2 X115.458 Y117.506 I1.877 J1.872 E.22522
G1 X113.916 Y119.049 E.07237
G1 X110.078 Y115.211 E.18005
G1 X115.211 Y110.078 E.2408
G1 X114.059 Y108.926 E.05401
G1 X106.209 Y112.658 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.527565
G1 F12000
G1 X138.385 Y144.834 E1.79707
G1 X138.728 Y144.491 E.01914
G1 X106.551 Y112.315 E1.79707
G1 X106.251 Y112.615 E.01677
; CHANGE_LAYER
; Z_HEIGHT: 6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X106.551 Y112.315 E-.16136
G1 X107.665 Y113.429 E-.59864
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
G1 X134.212 Y134.857
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X134.214 Y134.856 E.00009
G3 X136.025 Y133.83 I1.917 J1.272 E.07164
G3 X136.336 Y133.836 I.115 J1.876 E.01035
G3 X134.126 Y134.999 I-.206 J2.291 E.39196
G1 X134.181 Y134.909 E.0035
G1 X134.331 Y135.498 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.36 Y135.424 E.00244
G3 X136.041 Y134.221 I1.771 J.699 E.06715
G3 X136.3 Y134.227 I.097 J1.558 E.00795
G3 X134.257 Y135.786 I-.169 J1.896 E.28092
G1 X134.316 Y135.556 E.00728
; WIPE_START
M204 S10000
G1 X134.36 Y135.424 E-.05295
G1 X134.541 Y135.071 E-.15073
G1 X134.777 Y134.777 E-.14333
G1 X135.071 Y134.541 E-.14342
G1 X135.421 Y134.353 E-.15093
G1 X135.668 Y134.274 E-.09828
G1 X135.721 Y134.267 E-.02035
; WIPE_END
G1 E-.04 F1800
G1 X130.069 Y129.137 Z6.4 F36000
G1 X112.999 Y113.644 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X113.001 Y113.642 E.00009
G3 X114.812 Y112.616 I1.917 J1.272 E.07165
G3 X115.123 Y112.623 I.115 J1.871 E.01034
G3 X112.913 Y113.786 I-.206 J2.292 E.39197
G1 X112.968 Y113.695 E.00351
G1 X113.262 Y113.98 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X113.33 Y113.859 E.00425
G3 X114.828 Y113.008 I1.588 J1.051 E.05495
G3 X115.087 Y113.014 I.096 J1.554 E.00795
G3 X113.146 Y114.211 I-.169 J1.896 E.29249
G1 X113.235 Y114.034 E.00609
; WIPE_START
M204 S10000
G1 X113.33 Y113.859 E-.0754
G1 X113.564 Y113.564 E-.14324
G1 X113.858 Y113.327 E-.14342
G1 X114.208 Y113.14 E-.15093
G1 X114.454 Y113.061 E-.09828
G1 X114.828 Y113.008 E-.14344
G1 X114.842 Y113.009 E-.0053
; WIPE_END
G1 E-.04 F1800
G1 X119.355 Y119.164 Z6.4 F36000
G1 X138.524 Y145.311 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X105.724 Y112.512 E1.53869
G1 X107.43 Y110.805 E.08004
G1 X107.767 Y111.142 E.01578
G1 X111.142 Y107.767 E.15833
G1 X110.805 Y107.43 E.01578
G1 X112.512 Y105.724 E.08004
G1 X145.318 Y138.531 E1.53904
G1 X143.612 Y140.237 E.08004
G1 X143.276 Y139.901 E.01578
G1 X139.901 Y143.276 E.15833
G1 X140.237 Y143.612 E.01578
G1 X138.566 Y145.283 E.07839
; WIPE_START
G1 X137.151 Y143.871 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X143.972 Y147.295 Z6.4 F36000
G1 X154.616 Y152.639 Z6.4
G1 Z6
G1 E.8 F1800
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X148.345 Y158.91 E.20146
G1 X147.075 Y157.64 E.05957
G1 X150.67 Y154.045 E.16867
G1 X151.006 Y154.381 E.01578
G1 X154.381 Y151.006 E.15833
G1 X154.045 Y150.67 E.01578
G1 X157.64 Y147.075 E.16866
G1 X158.91 Y148.345 E.05957
G1 X154.658 Y152.596 E.19947
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X148.345 Y159.465 E.18661
G1 X146.52 Y157.64 E.07928
G1 X151.473 Y152.687 E.21523
G1 X141.595 Y142.809 E.42926
G1 X138.531 Y145.873 E.13313
G1 X105.17 Y112.512 E1.44971
G1 X108.234 Y109.448 E.13313
G1 X98.652 Y99.867 E.41635
G1 X99.866 Y98.652 E.05276
G1 X101.612 Y100.398 E.07586
G1 X109.448 Y108.234 E.34049
G1 X112.512 Y105.17 E.13313
G1 X126.246 Y118.904 E.59682
G1 X145.873 Y138.531 E.85289
G1 X142.809 Y141.595 E.13313
G1 X152.687 Y151.473 E.42926
G1 X157.64 Y146.52 E.21523
G1 X159.465 Y148.345 E.07928
G1 X155.213 Y152.596 E.18477
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.684 Y150.67 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53922
G1 F12000
G1 X154.867 Y150.486 E.01051
; WIPE_START
G1 X154.684 Y150.67 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.793 Y150.956 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50814
G1 F13541.982
G2 X153.792 Y151.057 I-.029 J.05 E.0091
; WIPE_START
G1 X153.735 Y151.057 E-.18544
G1 X153.706 Y151.006 E-.19152
G1 X153.735 Y150.956 E-.19154
G1 X153.793 Y150.956 E-.1915
; WIPE_END
G1 E-.04 F1800
G1 X156.068 Y150.695 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.219 Y149.543 E.05401
G1 X156.442 Y148.766 E.03647
G1 X155.156 Y150.051 E.06031
G3 X155.378 Y150.614 I-.17 J.392 E.02229
G1 X154.756 Y151.236 E.02916
G1 X154.644 Y151.236 E.00372
G1 X152.94 Y152.94 E.07995
G1 X155.502 Y155.502 E.1202
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.453 Y152.968 E.05401
; WIPE_START
G1 X155.604 Y154.12 E-.61876
G1 X155.341 Y154.383 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X151.209 Y153.576 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X153.584 Y151.201 E.10322
G1 X152.587 Y151.666
G1 X151.666 Y152.587 E.04002
G1 X151.399 Y152.32
G1 X152.32 Y151.399 E.04002
G1 X152.053 Y151.132
G1 X151.132 Y152.053 E.04002
G1 X150.866 Y151.787
G1 X151.787 Y150.866 E.04002
G1 X151.52 Y150.599
G1 X150.599 Y151.52 E.04002
G1 X150.332 Y151.253
G1 X151.253 Y150.332 E.04002
G1 X150.987 Y150.066
G1 X150.066 Y150.987 E.04002
G1 X149.799 Y150.72
G1 X150.72 Y149.799 E.04002
G1 X150.453 Y149.533
G1 X149.533 Y150.454 E.04002
G1 X149.266 Y150.187
G1 X150.187 Y149.266 E.04002
G1 X149.92 Y148.999
G1 X148.999 Y149.92 E.04002
G1 X148.733 Y149.654
G1 X149.654 Y148.733 E.04002
G1 X149.387 Y148.466
G1 X148.466 Y149.387 E.04002
G1 X148.199 Y149.12
G1 X149.12 Y148.199 E.04002
G1 X148.854 Y147.933
G1 X147.933 Y148.854 E.04002
G1 X147.666 Y148.587
G1 X148.587 Y147.666 E.04002
G1 X148.32 Y147.4
G1 X147.4 Y148.32 E.04002
G1 X147.133 Y148.054
G1 X148.054 Y147.133 E.04002
G1 X147.787 Y146.866
G1 X146.866 Y147.787 E.04002
G1 X146.6 Y147.521
G1 X147.521 Y146.6 E.04002
G1 X147.254 Y146.333
G1 X146.333 Y147.254 E.04002
G1 X146.066 Y146.987
G1 X146.987 Y146.066 E.04002
G1 X146.721 Y145.8
G1 X145.8 Y146.721 E.04002
G1 X145.533 Y146.454
G1 X146.454 Y145.533 E.04002
G1 X146.187 Y145.267
G1 X145.267 Y146.187 E.04002
G1 X145 Y145.921
G1 X145.921 Y145 E.04002
G1 X145.654 Y144.733
G1 X144.733 Y145.654 E.04002
G1 X144.467 Y145.388
G1 X145.388 Y144.467 E.04002
G1 X145.121 Y144.2
G1 X144.2 Y145.121 E.04002
G1 X143.933 Y144.854
G1 X144.854 Y143.933 E.04002
G1 X144.588 Y143.667
G1 X143.667 Y144.588 E.04002
G1 X143.4 Y144.321
G1 X144.321 Y143.4 E.04002
G1 X144.054 Y143.133
G1 X143.133 Y144.054 E.04002
G1 X142.867 Y143.788
G1 X143.788 Y142.867 E.04002
G1 X143.521 Y142.6
G1 X142.6 Y143.521 E.04002
G1 X142.334 Y143.255
G1 X143.255 Y142.334 E.04002
G1 X142.988 Y142.067
G1 X142.067 Y142.988 E.04002
G1 X141.8 Y142.721
G1 X142.721 Y141.8 E.04002
G1 X143.196 Y140.792
G1 X140.77 Y143.218 E.10542
M204 S10000
G1 X142.862 Y140.613 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.224128
G1 F15000
G1 X142.883 Y140.711 E.00147
G1 X140.632 Y142.961 E.047
; WIPE_START
G1 X142.046 Y141.547 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X147.064 Y147.298 Z6.4 F36000
G1 X151.776 Y152.697 Z6.4
G1 Z6
G1 E.8 F1800
; LINE_WIDTH: 0.106519
G1 F15000
G1 X151.044 Y153.432 E.00538
G2 X151.099 Y153.497 I.13 J-.055 E.00045
; WIPE_START
G1 X151.044 Y153.432 E-.0575
G1 X151.776 Y152.697 E-.7025
; WIPE_END
G1 E-.04 F1800
G1 X150.444 Y154.91 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53922
G1 F12000
G1 X150.628 Y154.726 E.01051
G1 X149.917 Y155.29 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X148.766 Y156.442 E.05401
G1 X149.543 Y157.219 E.03647
G1 X150.695 Y156.068 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X145.184 Y150.516 Z6.4 F36000
G1 X140.547 Y143.225 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50812
G1 F13542.563
G2 X140.545 Y143.326 I-.029 J.05 E.0091
; WIPE_START
G1 X140.489 Y143.326 E-.18544
G1 X140.46 Y143.276 E-.19152
G1 X140.489 Y143.225 E-.19154
G1 X140.547 Y143.225 E-.1915
; WIPE_END
G1 E-.04 F1800
G1 X139.262 Y143.99 Z6.4 F36000
G1 Z6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.48181
G1 F12000
G1 X139.559 Y143.657 E.01592
G1 X138.531 Y144.656 F36000
; LINE_WIDTH: 0.571895
G1 F11909.825
G1 X106.386 Y112.512 E1.95954
; LINE_WIDTH: 0.552688
G1 F12000
G1 X106.483 Y112.414 E.0057
; LINE_WIDTH: 0.541499
G2 X106.729 Y112.15 I-2.126 J-2.223 E.01468
; Slow Down Start
; LINE_WIDTH: 0.53998
G1 F3000;_EXTRUDE_SET_SPEED
G1 X106.998 Y111.848 E.01637
G1 X106.896 Y112.035 E.00861
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.560842
;_EXTRUDE_SET_SPEED
G1 X106.94 Y112.317 E.01207
G1 X138.718 Y144.095 E1.89669
G1 X139.009 Y144.15 E.0125
; Slow Down End
; LINE_WIDTH: 0.559493
G1 F12000
G1 X139.085 Y144.118 E.00344
G3 X138.574 Y144.615 I-34.238 J-34.713 E.02997
G1 X107.027 Y111.808 F36000
; LINE_WIDTH: 0.49795
M73 P86 R2
G1 F12000
G1 X107.04 Y111.794 E.00071
; LINE_WIDTH: 0.485111
G1 X107.386 Y111.484 E.01673
G1 X108.549 Y110.852 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X109.701 Y109.701 E.05401
G1 X113.039 Y113.039 E.15662
G3 X117.506 Y115.458 I1.858 J1.902 E.22408
G1 X118.84 Y114.125 E.06256
G1 X115.002 Y110.287 E.18005
G1 X110.287 Y115.002 E.22121
G1 X114.125 Y118.84 E.18005
G1 X115.463 Y117.505 E.0627
G2 X116.784 Y116.784 I-1.077 J-3.542 E.05028
G1 X134.252 Y134.252 E.81948
G2 X133.856 Y137.488 I1.887 J1.873 E.11641
G1 X133.314 Y138.03 E.02541
G1 X129.476 Y134.192 E.18005
G1 X134.192 Y129.476 E.22121
G1 X130.354 Y125.638 E.18005
G1 X125.638 Y130.354 E.22121
G1 X121.8 Y126.516 E.18005
G1 X126.516 Y121.8 E.22121
G1 X122.678 Y117.963 E.18005
G1 X117.962 Y122.678 E.22121
G1 X116.811 Y121.527 E.05401
; WIPE_START
G1 X117.962 Y122.678 E-.61876
G1 X118.225 Y122.415 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X114.141 Y115.968 Z6.4 F36000
G1 X109.393 Y108.472 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X108.472 Y109.393 E.04002
G1 X108.205 Y109.126
G1 X109.126 Y108.205 E.04002
G1 X108.859 Y107.938
G1 X107.938 Y108.859 E.04002
G1 X107.672 Y108.593
G1 X108.593 Y107.672 E.04002
G1 X108.326 Y107.405
G1 X107.405 Y108.326 E.04002
G1 X107.139 Y108.06
G1 X108.06 Y107.139 E.04002
G1 X107.793 Y106.872
G1 X106.872 Y107.793 E.04002
G1 X106.605 Y107.526
G1 X107.526 Y106.605 E.04002
G1 X107.26 Y106.339
G1 X106.339 Y107.26 E.04002
G1 X106.072 Y106.993
G1 X106.993 Y106.072 E.04002
G1 X106.726 Y105.805
G1 X105.805 Y106.726 E.04002
G1 X105.539 Y106.46
G1 X106.46 Y105.539 E.04002
G1 X106.193 Y105.272
G1 X105.272 Y106.193 E.04002
G1 X105.006 Y105.927
G1 X105.926 Y105.006 E.04002
G1 X105.66 Y104.739
G1 X104.739 Y105.66 E.04002
G1 X104.472 Y105.393
G1 X105.393 Y104.472 E.04002
G1 X105.127 Y104.206
G1 X104.206 Y105.127 E.04002
G1 X103.939 Y104.86
G1 X104.86 Y103.939 E.04002
G1 X104.593 Y103.672
G1 X103.672 Y104.593 E.04002
G1 X103.406 Y104.327
G1 X104.327 Y103.406 E.04002
G1 X104.06 Y103.139
G1 X103.139 Y104.06 E.04002
G1 X102.873 Y103.793
G1 X103.793 Y102.873 E.04002
G1 X103.527 Y102.606
G1 X102.606 Y103.527 E.04002
G1 X102.339 Y103.26
G1 X103.26 Y102.339 E.04002
G1 X102.994 Y102.073
G1 X102.073 Y102.994 E.04002
G1 X101.806 Y102.727
G1 X102.727 Y101.806 E.04002
G1 X102.46 Y101.539
G1 X101.539 Y102.46 E.04002
G1 X101.273 Y102.194
G1 X102.194 Y101.273 E.04002
G1 X101.927 Y101.006
G1 X101.006 Y101.927 E.04002
G1 X100.74 Y101.66
G1 X101.66 Y100.74 E.04002
G1 X101.394 Y100.473
G1 X100.473 Y101.394 E.04002
G1 X100.206 Y101.127
G1 X101.127 Y100.206 E.04002
G1 X100.861 Y99.94
G1 X99.94 Y100.861 E.04002
G1 X99.673 Y100.594
G1 X100.594 Y99.673 E.04002
G1 X100.327 Y99.406
G1 X99.406 Y100.327 E.04002
G1 X99.14 Y100.061
G1 X100.061 Y99.14 E.04002
; WIPE_START
M204 S10000
G1 X99.14 Y100.061 E-.49491
G1 X99.406 Y100.327 E-.14329
G1 X99.633 Y100.101 E-.1218
; WIPE_END
G1 E-.04 F1800
G1 X105.497 Y104.986 Z6.4 F36000
G1 X109.752 Y108.532 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.496899
G1 F13877.292
G1 X109.718 Y108.597 E.00273
; LINE_WIDTH: 0.453714
G1 F15000
G1 X109.683 Y108.662 E.00247
; LINE_WIDTH: 0.390094
G1 X109.648 Y108.727 E.00209
G1 X108.727 Y109.648 E.03684
; LINE_WIDTH: 0.410527
G1 X108.662 Y109.683 E.00221
; LINE_WIDTH: 0.453709
G1 X108.597 Y109.718 E.00247
; LINE_WIDTH: 0.496891
G1 F13877.536
G1 X108.532 Y109.752 E.00273
; LINE_WIDTH: 0.496844
G1 F13878.998
G1 X108.524 Y109.693 E.00221
; LINE_WIDTH: 0.453552
G1 F15000
G1 X108.516 Y109.634 E.002
; LINE_WIDTH: 0.410261
G1 X108.508 Y109.575 E.00179
; LINE_WIDTH: 0.36697
G1 X108.5 Y109.516 E.00158
; LINE_WIDTH: 0.323678
G1 X108.491 Y109.457 E.00137
; WIPE_START
G1 X108.5 Y109.516 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X103.681 Y103.596 Z6.4 F36000
G1 X99.904 Y98.956 Z6.4
G1 Z6
G1 E.8 F1800
; LINE_WIDTH: 0.147728
G1 F15000
G1 X98.956 Y99.904 E.01145
; WIPE_START
G1 X99.904 Y98.956 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X105.798 Y103.805 Z6.4 F36000
G1 X110.554 Y107.716 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.50814
G1 F13541.982
G2 X110.552 Y107.817 I-.029 J.05 E.0091
; WIPE_START
G1 X110.496 Y107.817 E-.18546
G1 X110.467 Y107.767 E-.19152
G1 X110.496 Y107.716 E-.19153
G1 X110.554 Y107.716 E-.19149
; WIPE_END
G1 E-.04 F1800
G1 X115.215 Y113.761 Z6.4 F36000
G1 X136.001 Y140.716 Z6.4
G1 Z6
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X137.152 Y141.868 E.05401
G1 X141.868 Y137.152 E.22121
G1 X138.03 Y133.314 E.18005
G1 X137.488 Y133.856 E.02541
G3 X137.997 Y137.997 I-1.36 J2.269 E.15945
G1 X141.342 Y141.342 E.15692
G1 X140.191 Y142.494 E.05401
G1 X144.015 Y139.234 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.497985
G1 F12000
G1 X144.002 Y139.248 E.00071
; LINE_WIDTH: 0.485148
G1 X143.657 Y139.559 E.01673
G1 X112.512 Y106.386 F36000
; LINE_WIDTH: 0.57189
G1 F11909.938
G1 X144.656 Y138.531 E1.95952
; LINE_WIDTH: 0.552688
G1 F12000
G1 X144.559 Y138.628 E.0057
; LINE_WIDTH: 0.540549
G2 X144.045 Y139.195 I8.489 J8.225 E.03103
G1 X144.146 Y139.008 E.00862
; LINE_WIDTH: 0.5571
G1 X144.103 Y138.725 E.01198
; Slow Down Start
; LINE_WIDTH: 0.560812
G1 F3000;_EXTRUDE_SET_SPEED
G1 X112.324 Y106.947 E1.89658
G1 X112.033 Y106.893 E.0125
G1 X111.958 Y106.924 E.00345
G3 X112.154 Y106.733 I6.121 J6.064 E.01156
; Slow Down End
; LINE_WIDTH: 0.563933
G1 F12000
G1 X112.468 Y106.428 E.01861
G1 X111.444 Y107.43 F36000
; LINE_WIDTH: 0.525095
G1 F12000
G1 X111.592 Y107.264 E.00875
; LINE_WIDTH: 0.496844
G1 X111.74 Y107.098 E.00823
; CHANGE_LAYER
; Z_HEIGHT: 6.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X111.592 Y107.264 E-.76
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
G1 X154.616 Y152.639
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X148.454 Y158.801 E.19634
G1 X147.184 Y157.531 E.05957
G1 X157.531 Y147.184 E.48542
G1 X158.185 Y147.837 E.03066
G1 X158.801 Y148.454 E.02891
G1 X154.658 Y152.596 E.19435
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X148.454 Y159.356 E.18187
G1 X146.629 Y157.531 E.07928
G1 X157.531 Y146.629 E.47374
G1 X158.462 Y147.56 E.04045
G1 X159.356 Y148.454 E.03883
G1 X155.213 Y152.596 E.18003
M204 S10000
G1 X154.453 Y152.968 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.604 Y154.12 E.05401
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X152.996 Y152.996 E.11757
G1 X155.378 Y150.614 E.11174
G2 X155.156 Y150.051 I-.392 J-.17 E.02229
G1 X156.442 Y148.766 E.06031
G1 X157.219 Y149.543 E.03647
G1 X156.068 Y150.695 E.05401
G1 X150.444 Y154.91 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53922
G1 F12000
G1 X154.867 Y150.486 E.253
G1 X150.695 Y156.068 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X149.917 Y155.29 E.05401
; WIPE_START
G1 X148.766 Y156.442 E-.61876
G1 X149.029 Y156.705 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X144.759 Y150.378 Z6.6 F36000
G1 X134.249 Y134.808 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X134.502 Y134.502 E.01317
G3 X136.009 Y133.83 I1.628 J1.625 E.05598
G3 X136.323 Y133.835 I.128 J1.879 E.0104
G3 X134.213 Y134.856 I-.192 J2.293 E.39796
G1 X134.357 Y135.429 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G3 X136.026 Y134.222 I1.773 J.695 E.06684
G3 X136.286 Y134.226 I.109 J1.563 E.008
G3 X134.336 Y135.485 I-.155 J1.898 E.29103
; WIPE_START
M204 S10000
G1 X134.463 Y135.192 E-.12136
G1 X134.553 Y135.053 E-.06285
G1 X134.777 Y134.777 E-.13507
G1 X135.053 Y134.553 E-.13506
G1 X135.192 Y134.463 E-.06285
G1 X135.426 Y134.351 E-.09877
G1 X135.674 Y134.272 E-.09894
G1 X135.792 Y134.256 E-.0451
; WIPE_END
G1 E-.04 F1800
G1 X130.141 Y129.125 Z6.6 F36000
G1 X113.035 Y113.595 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X113.289 Y113.289 E.01319
G3 X114.796 Y112.617 I1.628 J1.625 E.05599
G3 X115.109 Y112.622 I.127 J1.891 E.01039
G3 X113 Y113.644 I-.192 J2.293 E.39794
G1 X113.334 Y113.849 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X113.341 Y113.841 E.00034
G3 X114.813 Y113.009 I1.576 J1.07 E.05381
G3 X115.073 Y113.012 I.109 J1.57 E.008
G3 X113.255 Y113.981 I-.155 J1.898 E.30084
G1 X113.303 Y113.9 E.00289
; WIPE_START
M204 S10000
G1 X113.341 Y113.841 E-.0269
G1 X113.564 Y113.564 E-.135
G1 X113.84 Y113.339 E-.13517
G1 X113.978 Y113.25 E-.06271
G1 X114.213 Y113.138 E-.0988
G1 X114.461 Y113.059 E-.09896
G1 X114.813 Y113.009 E-.13487
G1 X114.99 Y113.011 E-.0676
; WIPE_END
G1 E-.04 F1800
G1 X112.348 Y105.888 Z6.6 F36000
G1 Z6.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X115.054 Y108.594 E.12694
G1 X145.154 Y138.695 E1.41209
G1 X138.695 Y145.154 E.30303
G1 X105.888 Y112.348 E1.53904
G1 X112.305 Y105.931 E.30104
G1 X112.348 Y105.334 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X115.331 Y108.317 E.12964
G1 X145.709 Y138.695 E1.32008
G1 X138.695 Y145.709 E.30479
G1 X105.334 Y112.348 E1.44971
G1 X112.305 Y105.376 E.30294
; WIPE_START
M204 S10000
G1 X113.739 Y106.77 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X109.631 Y113.203 Z6.6 F36000
G1 X109.362 Y113.623 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X110.514 Y114.775 E.05401
G1 X114.775 Y110.514 E.1999
G1 X118.613 Y114.352 E.18005
G1 X117.506 Y115.458 E.05191
G2 X113.038 Y113.038 I-2.596 J-.541 E.2252
G1 X109.757 Y109.757 E.15395
G1 X110.908 Y108.605 E.05401
; WIPE_START
G1 X109.757 Y109.757 E-.61876
G1 X110.019 Y110.019 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X114.62 Y116.11 Z6.6 F36000
G1 X123.179 Y127.44 Z6.6
G1 Z6.2
G1 E.8 F1800
G1 F15476.087
G1 X122.028 Y126.289 E.05401
G1 X126.289 Y122.028 E.1999
M73 P87 R2
G1 X130.127 Y125.866 E.18005
G1 X125.866 Y130.127 E.1999
G1 X129.704 Y133.965 E.18005
G1 X133.965 Y129.704 E.1999
G1 X135.116 Y130.855 E.05401
; WIPE_START
G1 X133.965 Y129.704 E-.61876
G1 X133.702 Y129.966 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X137.201 Y136.75 Z6.6 F36000
G1 X140.135 Y142.437 Z6.6
G1 Z6.2
G1 E.8 F1800
G1 F15476.087
G1 X141.286 Y141.286 E.05401
G1 X137.998 Y137.999 E.15423
G2 X137.488 Y133.856 I-1.906 J-1.868 E.15896
G1 X137.803 Y133.542 E.01476
G1 X141.641 Y137.38 E.18005
G1 X137.38 Y141.641 E.1999
G1 X133.542 Y137.803 E.18005
G1 X133.856 Y137.488 E.01476
G3 X134.252 Y134.252 I2.287 J-1.363 E.1164
G1 X116.785 Y116.785 E.81938
G3 X115.458 Y117.506 I-1.961 J-2.029 E.05071
G1 X114.352 Y118.613 E.05191
G1 X118.19 Y122.451 E.18005
G1 X122.451 Y118.19 E.1999
G1 X123.602 Y119.341 E.05401
; WIPE_START
G1 X122.451 Y118.19 E-.61876
G1 X122.188 Y118.453 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X126.473 Y124.768 Z6.6 F36000
G1 X139.396 Y143.814 Z6.6
G1 Z6.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.53918
G1 F12000
G1 X143.802 Y139.408 E.25197
G1 X139.221 Y143.856 F36000
; LINE_WIDTH: 0.49226
G1 F12000
G1 X139.309 Y143.835 E.0033
; LINE_WIDTH: 0.52354
G1 X139.396 Y143.814 E.00353
; LINE_WIDTH: 0.519315
G1 X139.33 Y143.906 E.00441
; LINE_WIDTH: 0.479585
G1 X139.263 Y143.998 E.00404
; LINE_WIDTH: 0.42015
G1 X139.196 Y144.089 E.00349
G1 X138.695 Y144.6 E.02198
G1 X106.443 Y112.348 E1.40208
; LINE_WIDTH: 0.440485
G1 X106.533 Y112.257 E.00416
; LINE_WIDTH: 0.481475
G1 X106.624 Y112.166 E.00459
; LINE_WIDTH: 0.467098
G1 X107.199 Y111.678 E.02606
; LINE_WIDTH: 0.522465
G1 X107.193 Y111.726 E.00189
; LINE_WIDTH: 0.481475
G1 X107.186 Y111.774 E.00173
; Slow Down Start
; LINE_WIDTH: 0.465748
G1 F3000;_EXTRUDE_SET_SPEED
G2 X107.218 Y111.935 I.179 J.049 E.00586
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.448235
;_EXTRUDE_SET_SPEED
G1 X107.267 Y112.082 E.00514
G1 X138.957 Y143.772 E1.48018
G1 X139.108 Y143.82 E.00523
; Slow Down End
; LINE_WIDTH: 0.464484
G1 F12000
G1 X139.164 Y143.838 E.00202
G1 X106.988 Y112.348 F36000
; LINE_WIDTH: 0.43639
G1 F12000
G1 X138.653 Y144.013 E1.43581
; WIPE_START
G1 X137.238 Y142.598 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X132.764 Y136.415 Z6.6 F36000
G1 X111.646 Y107.228 Z6.6
G1 Z6.2
G1 E.8 F1800
; LINE_WIDTH: 0.53918
G1 F12000
G1 X107.24 Y111.634 E.25197
G1 X111.822 Y107.187 F36000
; LINE_WIDTH: 0.49226
G1 F12000
G1 X111.734 Y107.208 E.0033
; LINE_WIDTH: 0.52354
G1 X111.646 Y107.228 E.00353
; LINE_WIDTH: 0.519315
G1 X111.713 Y107.137 E.00441
; LINE_WIDTH: 0.479585
G1 X111.78 Y107.045 E.00404
; LINE_WIDTH: 0.42015
G1 X111.847 Y106.953 E.00349
G1 X112.348 Y106.443 E.02198
G1 X144.6 Y138.695 E1.40208
; LINE_WIDTH: 0.440485
G1 X144.509 Y138.786 E.00416
; LINE_WIDTH: 0.481475
G1 X144.418 Y138.877 E.00459
; LINE_WIDTH: 0.467098
G1 X143.843 Y139.365 E.02606
; LINE_WIDTH: 0.522465
G1 X143.85 Y139.317 E.00189
; LINE_WIDTH: 0.481475
G1 X143.857 Y139.269 E.00173
; Slow Down Start
; LINE_WIDTH: 0.465747
G1 F3000;_EXTRUDE_SET_SPEED
G2 X143.825 Y139.108 I-.179 J-.049 E.00586
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.448235
;_EXTRUDE_SET_SPEED
G1 X143.776 Y138.96 E.00514
G1 X112.086 Y107.271 E1.48018
G1 X111.935 Y107.223 E.00523
; Slow Down End
; LINE_WIDTH: 0.464482
G1 F12000
G1 X111.879 Y107.205 E.00202
G1 X144.055 Y138.695 F36000
; LINE_WIDTH: 0.43629
G1 F12000
G1 X112.39 Y107.03 E1.43544
; CHANGE_LAYER
; Z_HEIGHT: 6.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X113.804 Y108.444 E-.76
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
G1 X154.616 Y152.639
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X148.563 Y158.692 E.19122
G1 X147.293 Y157.422 E.05957
G1 X157.422 Y147.293 E.47519
G1 X158.692 Y148.563 E.05957
G1 X154.658 Y152.596 E.18923
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X148.563 Y159.247 E.17713
G1 X146.738 Y157.422 E.07928
G1 X157.422 Y146.738 E.46427
G1 X159.247 Y148.563 E.07928
G1 X155.213 Y152.596 E.17529
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.068 Y150.695 Z6.8 F36000
G1 Z6.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.219 Y149.543 E.05401
G1 X156.442 Y148.766 E.03647
G1 X152.604 Y152.604 E.18005
G1 X155.502 Y155.502 E.13598
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.453 Y152.968 E.05401
G1 X149.917 Y155.29 F36000
G1 F15476.087
G1 X148.766 Y156.442 E.05401
G1 X149.543 Y157.219 E.03647
G1 X150.695 Y156.068 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X144.999 Y150.637 Z6.8 F36000
G1 X134.262 Y134.789 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X134.503 Y134.503 E.01239
G3 X135.994 Y133.831 I1.629 J1.625 E.05545
G3 X136.517 Y133.859 I.15 J2.085 E.01741
G3 X134.227 Y134.837 I-.384 J2.269 E.39237
G1 X134.402 Y135.319 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.465 Y135.197 E.00423
G3 X136.01 Y134.223 I1.666 J.931 E.05851
G3 X136.457 Y134.247 I.128 J1.784 E.0138
G3 X134.354 Y135.433 I-.326 J1.88 E.28812
G1 X134.379 Y135.374 E.00196
; WIPE_START
M204 S10000
G1 X134.465 Y135.197 E-.07502
G1 X134.565 Y135.035 E-.07233
G1 X134.777 Y134.777 E-.1268
G1 X135.035 Y134.565 E-.12705
G1 X135.194 Y134.461 E-.07216
G1 X135.431 Y134.349 E-.09949
G1 X135.681 Y134.271 E-.09963
G1 X135.909 Y134.237 E-.08752
; WIPE_END
G1 E-.04 F1800
G1 X130.247 Y129.12 Z6.8 F36000
G1 X113.048 Y113.576 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X113.29 Y113.29 E.01243
G3 X114.781 Y112.618 I1.629 J1.624 E.05546
G3 X115.303 Y112.646 I.15 J2.089 E.01741
G3 X113.014 Y113.625 I-.384 J2.269 E.39226
G1 X113.444 Y113.71 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X113.567 Y113.567 E.0058
G3 X114.797 Y113.01 I1.351 J1.348 E.04241
G3 X115.244 Y113.034 I.128 J1.787 E.01379
G3 X113.353 Y113.822 I-.326 J1.881 E.30203
G1 X113.406 Y113.756 E.0026
; WIPE_START
M204 S10000
G1 X113.567 Y113.567 E-.09447
G1 X113.822 Y113.352 E-.12677
G1 X113.981 Y113.248 E-.07229
G1 X114.218 Y113.136 E-.09951
G1 X114.468 Y113.057 E-.09962
G1 X114.797 Y113.01 E-.12625
G1 X114.99 Y113.006 E-.07332
G1 X115.167 Y113.025 E-.06778
; WIPE_END
G1 E-.04 F1800
G1 X112.176 Y106.06 Z6.8 F36000
G1 Z6.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X117.487 Y111.37 E.24914
G1 X144.983 Y138.866 E1.2899
G1 X138.866 Y144.983 E.28694
G1 X106.06 Y112.176 E1.53904
G1 X112.134 Y106.102 E.28495
G1 X112.176 Y105.505 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X117.764 Y111.093 E.24282
G1 X145.538 Y138.866 E1.20689
G1 X138.866 Y145.538 E.28989
G1 X105.505 Y112.176 E1.44971
G1 X112.134 Y105.548 E.28805
; WIPE_START
M204 S10000
G1 X113.559 Y106.951 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X109.615 Y113.371 Z6.8 F36000
G1 Z6.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X110.766 Y114.522 E.05401
G1 X114.522 Y110.766 E.17619
G1 X111.576 Y107.82 E.13821
G1 X111.576 Y107.937 E.00388
G1 X109.757 Y109.757 E.08535
G1 X113.038 Y113.038 E.15396
G2 X115.459 Y117.506 I1.879 J1.871 E.22518
G1 X114.604 Y118.36 E.04008
G1 X118.442 Y122.198 E.18005
G1 X122.198 Y118.442 E.17619
G1 X118.36 Y114.604 E.18005
G1 X117.506 Y115.459 E.04008
G3 X116.785 Y116.785 I-2.695 J-.605 E.05072
G1 X134.252 Y134.252 E.81939
G2 X133.857 Y137.488 I1.965 J1.882 E.11596
G1 X133.794 Y137.55 E.00293
G1 X137.632 Y141.388 E.18005
G1 X141.388 Y137.632 E.17619
G1 X143.222 Y139.467 E.08606
G1 X143.105 Y139.467 E.00388
G1 X141.286 Y141.286 E.08535
G1 X137.998 Y137.998 E.15423
G2 X137.488 Y133.857 I-1.908 J-1.867 E.1589
G1 X137.55 Y133.794 E.00293
G1 X138.701 Y134.946 E.05401
G1 X139.784 Y143.551 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.402445
G1 F12000
G1 X139.817 Y143.486 E.00213
; LINE_WIDTH: 0.441495
G1 X139.851 Y143.422 E.00237
; LINE_WIDTH: 0.480545
G1 X139.885 Y143.357 E.0026
; LINE_WIDTH: 0.538827
G1 X139.918 Y143.292 E.00294
G1 X143.292 Y139.918 E.19283
; LINE_WIDTH: 0.519595
G1 X143.349 Y139.887 E.0025
; LINE_WIDTH: 0.480545
G1 X143.405 Y139.855 E.0023
; LINE_WIDTH: 0.441495
G1 X143.461 Y139.824 E.00209
; LINE_WIDTH: 0.402445
G1 X143.518 Y139.792 E.00189
G1 X143.652 Y139.342 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X143.585 Y139.275 E.0029
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X111.768 Y107.458 E1.38258
; Slow Down End
; LINE_WIDTH: 0.41932
G1 F12000
G1 X111.701 Y107.391 E.00289
G1 X111.499 Y107.358 E.00629
G1 X111.309 Y107.451 E.0065
G2 X112.176 Y106.614 I-9.845 J-11.074 E.03699
M73 P88 R2
G1 X144.429 Y138.866 E1.399
G2 X143.592 Y139.734 I10.243 J10.718 E.03699
G1 X143.683 Y139.543 E.0065
G1 X143.661 Y139.401 E.00442
G1 X143.803 Y138.866 F36000
; LINE_WIDTH: 0.55107
G1 F12000
G1 X112.219 Y107.282 E1.84954
G1 X111.259 Y107.492 F36000
; LINE_WIDTH: 0.402445
G1 F12000
G1 X111.225 Y107.556 E.00213
; LINE_WIDTH: 0.441495
G1 X111.192 Y107.621 E.00237
; LINE_WIDTH: 0.480545
G1 X111.158 Y107.686 E.0026
; LINE_WIDTH: 0.538817
G1 X111.124 Y107.75 E.00294
G1 X107.75 Y111.124 E.19282
; LINE_WIDTH: 0.519578
G1 X107.694 Y111.156 E.0025
; LINE_WIDTH: 0.480533
G1 X107.638 Y111.187 E.0023
; LINE_WIDTH: 0.441488
G1 X107.581 Y111.219 E.00209
; LINE_WIDTH: 0.402443
G1 X107.525 Y111.25 E.00189
G1 X139.341 Y143.652 F36000
; LINE_WIDTH: 0.419178
G1 F12000
G1 X139.544 Y143.685 E.00628
G1 X139.784 Y143.551 E.00842
G2 X138.866 Y144.429 I10.379 J11.766 E.03893
G1 X106.614 Y112.176 E1.39847
G2 X107.451 Y111.309 I-10.229 J-10.704 E.03697
G1 X107.359 Y111.499 E.00649
G1 X107.391 Y111.701 E.00626
G1 X107.458 Y111.768 E.00289
; Slow Down Start
; LINE_WIDTH: 0.41999
G1 F3000;_EXTRUDE_SET_SPEED
G1 X139.275 Y143.585 E1.38258
; Slow Down End
G1 F12000
G1 X139.299 Y143.609 E.00105
G1 X107.24 Y112.176 F36000
; LINE_WIDTH: 0.55106
G1 F12000
G1 X138.824 Y143.76 E1.84951
; WIPE_START
G1 X137.41 Y142.346 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X133.781 Y135.631 Z6.8 F36000
G1 X127.187 Y123.432 Z6.8
G1 Z6.4
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X126.036 Y122.28 E.05401
G1 X122.28 Y126.036 E.17619
G1 X126.118 Y129.874 E.18005
G1 X129.874 Y126.118 E.17619
G1 X133.712 Y129.956 E.18005
G1 X129.956 Y133.712 E.17619
G1 X131.108 Y134.863 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 6.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X129.956 Y133.712 E-.61876
G1 X130.219 Y133.449 E-.14124
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
G1 X154.616 Y152.639
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X148.683 Y158.572 E.18557
G1 X147.413 Y157.302 E.05957
G1 X157.302 Y147.413 E.46389
G1 X158.162 Y148.274 E.04038
G1 X158.572 Y148.683 E.01919
G1 X154.658 Y152.596 E.18358
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X148.683 Y159.126 E.17189
G1 X146.859 Y157.302 E.07928
G1 X157.302 Y146.859 E.45379
G1 X158.44 Y147.997 E.04945
G1 X159.126 Y148.683 E.02983
G1 X155.213 Y152.596 E.17005
M204 S10000
G1 X154.453 Y152.968 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.604 Y154.12 E.05401
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X152.604 Y152.604 E.13598
G1 X156.442 Y148.766 E.18005
G1 X157.219 Y149.543 E.03647
G1 X156.068 Y150.695 E.05401
G1 X150.695 Y156.068 F36000
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X149.917 Y155.29 E.05401
; WIPE_START
G1 X148.766 Y156.442 E-.61876
G1 X149.029 Y156.705 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X144.769 Y150.371 Z7 F36000
G1 X134.275 Y134.77 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X134.505 Y134.505 E.01163
G3 X135.978 Y133.832 I1.632 J1.623 E.05491
G3 X136.549 Y133.863 I.165 J2.179 E.01901
G3 X134.243 Y134.82 I-.412 J2.264 E.39211
G1 X134.45 Y135.217 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.468 Y135.202 E.00071
G3 X135.994 Y134.224 I1.669 J.925 E.05806
G1 X136.213 Y134.22 E.00671
G3 X134.356 Y135.44 I-.076 J1.907 E.29559
G1 X134.427 Y135.272 E.00558
; WIPE_START
M204 S10000
G1 X134.468 Y135.202 E-.03088
G1 X134.577 Y135.017 E-.08156
G1 X134.777 Y134.777 E-.11879
G1 X135.016 Y134.577 E-.11856
G1 X135.197 Y134.459 E-.08199
G1 X135.436 Y134.347 E-.1002
G1 X135.688 Y134.269 E-.10029
G1 X135.994 Y134.224 E-.11769
G1 X136.021 Y134.223 E-.01005
; WIPE_END
G1 E-.04 F1800
G1 X130.348 Y129.117 Z7 F36000
G1 X113.061 Y113.557 Z7
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X113.289 Y113.289 E.01167
G3 X114.765 Y112.618 I1.628 J1.625 E.05496
G3 X114.393 Y117.154 I.144 J2.295 E.2617
G3 X113.025 Y113.605 I.524 J-2.24 E.14854
G1 X113.546 Y113.585 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X113.569 Y113.569 E.00088
G3 X114.781 Y113.01 I1.355 J1.344 E.0419
G1 X115 Y113.006 E.00672
G3 X113.369 Y113.807 I-.076 J1.907 E.31026
G1 X113.508 Y113.632 E.00687
; WIPE_START
M204 S10000
G1 X113.569 Y113.569 E-.03332
G1 X113.803 Y113.364 E-.11841
G1 X113.984 Y113.246 E-.08188
G1 X114.223 Y113.134 E-.10024
G1 X114.475 Y113.056 E-.10027
G1 X114.781 Y113.01 E-.1177
G1 X115 Y113.006 E-.08308
G1 X115.262 Y113.036 E-.10033
G1 X115.325 Y113.053 E-.02477
; WIPE_END
G1 E-.04 F1800
G1 X111.987 Y106.249 Z7 F36000
G1 Z6.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X144.794 Y139.056 E1.53904
G1 X139.056 Y144.794 E.26916
G1 X106.249 Y111.987 E1.53904
G1 X111.944 Y106.292 E.26717
G1 X111.987 Y105.695 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X145.348 Y139.056 E1.44971
G1 X139.056 Y145.348 E.27342
G1 X105.695 Y111.987 E1.44971
G1 X111.944 Y105.737 E.27158
; WIPE_START
M204 S10000
G1 X113.36 Y107.149 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X111.257 Y107.534 Z7 F36000
G1 Z6.6
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X111.987 Y106.804 E.03173
G1 X144.239 Y139.056 E1.40149
G1 X143.509 Y139.786 E.03173
G1 X143.393 Y139.67 E.00503
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X138.378 Y134.653 E.21795
G1 X137.992 Y134.182 E.01871
G1 X137.598 Y133.875 E.01536
G1 X117.165 Y113.44 E.88793
G1 X116.779 Y112.969 E.01872
G1 X116.385 Y112.662 E.01536
G1 X111.372 Y107.65 E.21781
; Slow Down End
G1 F12000
G1 X111.299 Y107.576 E.00319
G1 X143.625 Y139.172 F36000
; LINE_WIDTH: 0.369628
G1 F12000
G1 X143.741 Y139.056 E.00436
G1 X138.877 Y134.191 E.18314
G2 X138.055 Y133.37 I-8.57 J7.754 E.03095
G1 X117.663 Y112.978 E.76773
G2 X116.841 Y112.157 I-8.573 J7.757 E.03095
G1 X111.987 Y107.302 E.18278
G1 X111.755 Y107.534 E.00873
G1 X116.617 Y112.396 E.18307
G1 X117.005 Y112.717 E.0134
G2 X117.432 Y113.209 I11.539 J-9.59 E.01736
G1 X137.831 Y133.609 E.76803
G1 X138.218 Y133.931 E.0134
G2 X138.645 Y134.423 I11.801 J-9.818 E.01735
G1 X143.509 Y139.288 E.18315
G1 X143.582 Y139.214 E.00277
G1 X139.786 Y143.509 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X139.056 Y144.239 E.03173
G1 X106.804 Y111.987 E1.40149
G1 X107.534 Y111.257 E.03173
G1 X107.65 Y111.372 E.00504
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X112.638 Y116.36 E.21675
G1 X112.969 Y116.779 E.01641
G1 X113.441 Y117.165 E.01873
G1 X133.851 Y137.574 E.88685
G1 X134.182 Y137.992 E.01641
G1 X134.654 Y138.379 E.01873
G1 X139.67 Y143.393 E.21794
; Slow Down End
G1 F12000
G1 X139.744 Y143.466 E.00319
G1 X139.172 Y143.625 F36000
; LINE_WIDTH: 0.369646
G1 F12000
G1 X139.288 Y143.509 E.00436
G1 X134.423 Y138.646 E.18315
G1 X133.968 Y138.253 E.01598
G2 X133.602 Y137.823 I-16.025 J13.278 E.01506
G1 X113.21 Y117.432 E.76776
G1 X112.755 Y117.04 E.01598
G2 X112.388 Y116.61 I-16.421 J13.615 E.01506
G1 X107.534 Y111.755 E.18279
G1 X107.302 Y111.987 E.00873
G1 X112.157 Y116.841 E.18279
G2 X112.978 Y117.664 I8.013 J-7.186 E.03097
G1 X133.37 Y138.055 E.76776
G2 X134.192 Y138.877 I8.017 J-7.19 E.03097
G1 X139.056 Y143.741 E.18314
G1 X139.129 Y143.667 E.00277
G1 X136.775 Y139.943 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X137.926 Y141.094 E.05401
G1 X141.094 Y137.926 E.14864
G1 X143.263 Y140.094 E.10172
G1 X141.678 Y141.678 E.07432
G1 X137.999 Y137.999 E.17262
G2 X138.737 Y136.578 I-2.328 J-2.111 E.0537
; WIPE_START
G1 X138.539 Y137.233 E-.25981
G1 X138.362 Y137.557 E-.14042
G1 X137.999 Y137.999 E-.2174
G1 X138.264 Y138.264 E-.14237
; WIPE_END
G1 E-.04 F1800
G1 X135.678 Y133.523 Z7 F36000
G1 Z6.6
G1 E.8 F1800
G1 F15476.087
G2 X134.252 Y134.252 I.451 J2.643 E.05397
G1 X116.786 Y116.786 E.81937
G2 X117.505 Y115.459 I-1.954 J-1.919 E.05072
G1 X118.066 Y114.898 E.02633
G1 X121.904 Y118.736 E.18005
G1 X118.736 Y121.904 E.14864
G1 X122.574 Y125.742 E.18005
G1 X125.742 Y122.574 E.14864
G1 X129.58 Y126.412 E.18005
G1 X126.412 Y129.58 E.14864
G1 X130.25 Y133.418 E.18005
M73 P89 R2
G1 X133.418 Y130.25 E.14864
G1 X134.57 Y131.401 E.05401
G1 X116.049 Y119.218 F36000
G1 F15476.087
G1 X114.898 Y118.066 E.05401
G1 X115.459 Y117.505 E.02633
G3 X114.328 Y117.497 I-.529 J-4.808 E.03761
G1 X114.673 Y117.841 E.01618
; WIPE_START
G1 X114.328 Y117.497 E-.1853
G1 X114.958 Y117.567 E-.24076
G1 X115.459 Y117.505 E-.19199
G1 X115.195 Y117.769 E-.14195
; WIPE_END
G1 E-.04 F1800
G1 X111.839 Y110.915 Z7 F36000
G1 X110.516 Y108.213 Z7
G1 Z6.6
G1 E.8 F1800
G1 F15476.087
G1 X109.364 Y109.364 E.05401
G1 X113.039 Y113.039 E.17237
G2 X112.334 Y115.503 I2.064 J1.922 E.08825
G1 X111.06 Y114.229 E.05979
G1 X114.229 Y111.06 E.14864
G1 X113.077 Y109.909 E.05401
; CHANGE_LAYER
; Z_HEIGHT: 6.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15476.087
G1 X114.229 Y111.06 E-.61876
G1 X113.966 Y111.323 E-.14124
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
G1 X154.616 Y152.639
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X148.806 Y158.449 E.17982
G1 X147.536 Y157.179 E.05957
G1 X157.179 Y147.536 E.45239
G1 X158.449 Y148.806 E.05957
G1 X154.658 Y152.596 E.17783
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X148.806 Y159.003 E.16657
G1 X146.981 Y157.179 E.07928
G1 X157.179 Y146.981 E.44314
G1 X159.003 Y148.806 E.07928
G1 X155.213 Y152.596 E.16473
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.068 Y150.695 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X157.219 Y149.543 E.05401
G1 X156.442 Y148.766 E.03647
G1 X152.604 Y152.604 E.18005
G1 X155.502 Y155.502 E.13598
G1 X154.76 Y156.245 E.03482
G1 X154.12 Y155.604 E.03004
G1 X155.604 Y154.12 E.06964
G1 X154.453 Y152.968 E.05401
G1 X149.917 Y155.29 F36000
G1 F15476.087
G1 X148.766 Y156.442 E.05401
G1 X149.543 Y157.219 E.03647
G1 X150.695 Y156.068 E.05401
; WIPE_START
G1 X149.543 Y157.219 E-.61876
G1 X149.28 Y156.956 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X145.006 Y150.633 Z7.2 F36000
G1 X134.275 Y134.762 Z7.2
M73 P89 R1
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X134.291 Y134.742 E.00082
G3 X135.936 Y133.833 I1.839 J1.384 E.06423
G1 X136.243 Y133.827 E.01019
G3 X134.117 Y135.011 I-.113 J2.299 E.39464
G1 X134.243 Y134.812 E.0078
G1 X134.503 Y135.13 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X134.604 Y134.979 E.0056
G3 X135.97 Y134.224 I1.525 J1.148 E.04937
G1 X136.223 Y134.22 E.00779
G3 X134.46 Y135.201 I-.093 J1.906 E.3032
G1 X134.472 Y135.182 E.00071
; WIPE_START
M204 S10000
G1 X134.604 Y134.979 E-.09204
G1 X134.769 Y134.786 E-.09625
G1 X134.977 Y134.603 E-.10559
G1 X135.211 Y134.452 E-.10565
G1 X135.441 Y134.345 E-.09628
G1 X135.695 Y134.267 E-.1011
G1 X135.97 Y134.224 E-.10551
G1 X136.121 Y134.222 E-.05759
; WIPE_END
G1 E-.04 F1800
G1 X130.446 Y129.118 Z7.2 F36000
G1 X113.09 Y113.511 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X113.278 Y113.297 E.00944
G3 X114.722 Y112.62 I1.638 J1.616 E.05405
G1 X115.03 Y112.614 E.01019
G3 X113.055 Y113.559 I-.114 J2.298 E.4039
G1 X113.692 Y113.453 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X113.765 Y113.391 E.00296
G3 X114.756 Y113.011 I1.151 J1.523 E.03305
G1 X115.01 Y113.007 E.00779
G3 X113.556 Y113.574 I-.093 J1.907 E.31915
G1 X113.647 Y113.493 E.00373
; WIPE_START
M204 S10000
G1 X113.765 Y113.391 E-.05938
G1 X113.998 Y113.239 E-.10554
G1 X114.228 Y113.132 E-.09636
G1 X114.482 Y113.054 E-.10109
G1 X114.756 Y113.011 E-.10545
G1 X115.01 Y113.007 E-.09632
G1 X115.274 Y113.038 E-.10099
G1 X115.515 Y113.103 E-.09487
; WIPE_END
G1 E-.04 F1800
G1 X111.778 Y106.458 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X144.585 Y139.265 E1.53904
G1 X139.265 Y144.585 E.24958
G1 X106.458 Y111.778 E1.53904
G1 X111.736 Y106.5 E.24759
G1 X111.778 Y105.903 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X115.026 Y109.151 E.14113
G1 X145.139 Y139.265 E1.30858
G1 X139.265 Y145.139 E.25528
G1 X105.903 Y111.778 E1.44971
G1 X111.736 Y105.946 E.25344
; WIPE_START
M204 S10000
G1 X113.168 Y107.341 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X112.732 Y110.254 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X113.883 Y111.405 E.05401
G1 X111.405 Y113.883 E.11626
G1 X111.933 Y114.411 E.02477
G3 X112.045 Y113.961 I1.696 J.183 E.01544
G1 X112.466 Y113.888 E.01418
G1 X112.549 Y113.711 E.00648
G3 X112.997 Y112.997 I12.552 J7.375 E.02795
G1 X109.631 Y109.631 E.15791
G1 X110.782 Y108.479 E.05401
; WIPE_START
G1 X109.631 Y109.631 E-.61876
G1 X109.894 Y109.894 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X116.076 Y114.37 Z7.2 F36000
G1 X118.873 Y116.395 Z7.2
G1 Z6.8
G1 E.8 F1800
G1 F15476.087
G1 X117.721 Y115.243 E.05401
G2 X117.321 Y116.032 I1.063 J1.036 E.02981
G1 X117.165 Y116.312 E.01063
G1 X117.2 Y116.277 E.00167
G1 X117.487 Y116.526 E.01259
G1 X117.321 Y116.746 E.00913
G1 X124.071 Y126.549 F36000
G1 F15476.087
G1 X122.919 Y125.397 E.05401
G1 X125.397 Y122.919 E.11626
G1 X121.559 Y119.081 E.18005
G1 X119.081 Y121.559 E.11626
G1 X115.243 Y117.721 E.18005
G3 X116.031 Y117.321 I1.034 J1.06 E.02975
G1 X116.308 Y117.168 E.01052
G1 X116.529 Y117.483 E.01275
G2 X117.052 Y117.052 I-1.228 J-2.028 E.02256
G1 X133.986 Y133.986 E.7944
G1 X134.388 Y133.633 E.01774
G1 X134.509 Y133.754 E.0057
G1 X134.541 Y133.723 E.00147
G1 X134.438 Y133.62 E.00479
G3 X135.546 Y133.144 I1.889 J2.861 E.04021
G1 X135.381 Y133.454 E.01165
G1 X135.485 Y133.557 E.00486
G3 X135.962 Y133.484 I.858 J3.997 E.01604
G1 X133.073 Y130.595 E.13553
G1 X130.595 Y133.073 E.11626
G1 X126.757 Y129.235 E.18005
G1 X129.235 Y126.757 E.11626
G1 X130.387 Y127.909 E.05401
G1 X133.717 Y134.788 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F12000
G1 X134.155 Y134.233 E.01961
G1 X134.584 Y134.065 E.01277
G1 X135.037 Y133.71 E.01593
; WIPE_START
G1 X134.584 Y134.065 E-.25059
G1 X134.155 Y134.233 E-.20087
G1 X133.717 Y134.788 E-.30854
; WIPE_END
G1 E-.04 F1800
G1 X138.493 Y140.742 Z7.2 F36000
G1 X139.422 Y141.901 Z7.2
G1 Z6.8
G1 E.8 F1800
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X138.271 Y140.749 E.05401
G1 X140.749 Y138.271 E.11626
G1 X139.114 Y136.636 E.07672
G1 X139.015 Y137.061 E.0145
G1 X138.575 Y137.156 E.01495
G3 X138.048 Y138.048 I-4.553 J-2.093 E.03441
G1 X141.412 Y141.412 E.15782
G1 X142.563 Y140.26 E.05401
G1 X143.07 Y140.265 F36000
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.38292
G1 F3000;_EXTRUDE_SET_SPEED
G1 X140.328 Y143.009 E.10748
; Slow Down End
G1 X139.698 Y143.597 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X139.265 Y144.03 E.01883
; LINE_WIDTH: 0.444825
G1 X137.504 Y142.269 E.08156
; LINE_WIDTH: 0.494495
G1 X135.743 Y140.509 E.09163
; LINE_WIDTH: 0.534861
G1 X133.982 Y138.748 E.09983
G1 X133.738 Y138.398 E.01711
; LINE_WIDTH: 0.544165
G1 X133.609 Y138.276 E.00724
; LINE_WIDTH: 0.494495
G1 X133.48 Y138.154 E.00652
; LINE_WIDTH: 0.473221
G2 X132.826 Y137.592 I-4.831 J4.962 E.03026
; LINE_WIDTH: 0.444825
G1 X126.141 Y130.906 E.30966
; LINE_WIDTH: 0.494495
G1 X119.455 Y124.22 E.34793
; LINE_WIDTH: 0.54142
G1 X112.769 Y117.535 E.38408
G1 X112.525 Y117.185 E.01733
; LINE_WIDTH: 0.544165
G1 X112.396 Y117.063 E.00724
; LINE_WIDTH: 0.494495
G1 X112.267 Y116.941 E.00652
; LINE_WIDTH: 0.473217
G2 X111.613 Y116.379 I-4.833 J4.965 E.03026
; LINE_WIDTH: 0.418146
G1 X107.012 Y111.778 E.19894
G2 X107.659 Y111.115 I-8.786 J-9.219 E.02832
; Slow Down Start
; LINE_WIDTH: 0.417265
G1 F3000;_EXTRUDE_SET_SPEED
G1 X107.973 Y110.778 E.01405
G1 X107.974 Y111 E.00677
G2 X111.983 Y115.013 I856.406 J-851.54 E.17302
G1 X112.098 Y114.989 E.00358
G1 X112.179 Y114.878 E.00421
G1 X112.098 Y115.123 E.00786
G1 X112.256 Y115.289 E.007
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.441229
;_EXTRUDE_SET_SPEED
G1 X112.287 Y115.422 E.00444
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.483707
;_EXTRUDE_SET_SPEED
G1 X112.317 Y115.556 E.00492
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.526184
;_EXTRUDE_SET_SPEED
G1 X112.348 Y115.689 E.00539
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.568662
;_EXTRUDE_SET_SPEED
G1 X112.378 Y115.823 E.00586
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.42224
;_EXTRUDE_SET_SPEED
G1 X112.385 Y115.841 E.00061
; Slow Down End
; LINE_WIDTH: 0.448829
G1 F12000
G1 X112.471 Y116.067 E.00798
; LINE_WIDTH: 0.497505
G1 X112.557 Y116.292 E.00893
; LINE_WIDTH: 0.546182
G1 X112.643 Y116.517 E.00989
; LINE_WIDTH: 0.568662
G1 F11983.082
G1 X112.702 Y116.586 E.00387
; LINE_WIDTH: 0.526184
G1 F12000
G1 X112.76 Y116.655 E.00356
; LINE_WIDTH: 0.483707
G1 X112.819 Y116.724 E.00324
; LINE_WIDTH: 0.485812
G1 X112.877 Y116.792 E.00326
G1 X113.247 Y117.003 E.01538
; LINE_WIDTH: 0.41999
G1 X113.495 Y117.204 E.00979
G1 X113.888 Y117.406 E.01357
G1 X113.972 Y117.429 E.0027
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X114.551 Y117.583 E.0184
G1 X133.47 Y136.502 E.8221
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.441229
;_EXTRUDE_SET_SPEED
G1 X133.5 Y136.636 E.00444
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.483707
;_EXTRUDE_SET_SPEED
G1 X133.53 Y136.769 E.00492
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.526184
;_EXTRUDE_SET_SPEED
G1 X133.561 Y136.903 E.00539
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.568662
;_EXTRUDE_SET_SPEED
G1 X133.591 Y137.036 E.00587
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.422222
;_EXTRUDE_SET_SPEED
G1 X133.598 Y137.054 E.0006
; Slow Down End
; LINE_WIDTH: 0.448799
G1 F12000
G1 X133.684 Y137.28 E.00798
; LINE_WIDTH: 0.497487
G1 X133.77 Y137.505 E.00893
; LINE_WIDTH: 0.546176
G1 X133.856 Y137.73 E.00989
; LINE_WIDTH: 0.568662
G1 F11983.082
G1 X133.915 Y137.799 E.00387
; LINE_WIDTH: 0.526184
G1 F12000
G1 X133.973 Y137.868 E.00356
; LINE_WIDTH: 0.483707
G1 X134.032 Y137.937 E.00324
; LINE_WIDTH: 0.485817
G1 X134.09 Y138.005 E.00326
G1 X134.461 Y138.217 E.01539
; LINE_WIDTH: 0.41999
G1 X134.708 Y138.417 E.00978
G1 X135.101 Y138.619 E.01357
G1 X135.186 Y138.642 E.0027
; Slow Down Start
; LINE_WIDTH: 0.415693
G1 F3000;_EXTRUDE_SET_SPEED
G1 X135.732 Y138.788 E.01717
G1 X135.895 Y138.926 E.0065
G1 X136.173 Y138.869 E.00864
G1 X136.056 Y138.954 E.0044
G1 X136.025 Y139.049 E.00302
G1 X136.054 Y139.087 E.00147
G2 X140.042 Y143.07 I300.052 J-296.407 E.17119
; Slow Down End
; LINE_WIDTH: 0.400263
G1 F12000
G1 X140.285 Y143.051 E.00712
G1 X139.742 Y143.556 E.0216
G1 X139.565 Y143.164 F36000
; LINE_WIDTH: 0.464969
G1 F12000
G1 X135.541 Y139.151 E.19543
G1 X134.997 Y139.005 E.01937
G1 X134.502 Y138.734 E.01944
G3 X135.471 Y139.67 I-18.113 J19.724 E.04636
G1 X139.265 Y143.464 E.18451
G1 X139.522 Y143.206 E.01253
G1 X136.758 Y138.706 F36000
; LINE_WIDTH: 0.38292
G1 F12000
G1 X136.517 Y138.844 E.0077
G1 X136.233 Y138.865 E.00788
G1 X134.235 Y138.495 F36000
; LINE_WIDTH: 0.40108
G1 F12000
G1 X134.457 Y138.694 E.0087
G1 X133.458 Y137.657 F36000
; LINE_WIDTH: 0.466683
G1 F12000
G1 X133.183 Y137.075 E.02223
G1 X133.103 Y136.702 E.01317
G1 X114.343 Y117.943 E.91611
G1 X113.784 Y117.793 E.01999
G1 X113.289 Y117.521 E.01952
G1 X113.715 Y117.914 E.02001
G1 X133.416 Y137.615 E.96209
; WIPE_START
G1 X132.001 Y136.2 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X138.869 Y136.175 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
; LINE_WIDTH: 0.38292
G1 F12000
G1 X138.844 Y136.516 E.00949
G1 X138.736 Y136.706 E.00604
; WIPE_START
G1 X138.844 Y136.516 E-.2957
G1 X138.869 Y136.175 E-.4643
; WIPE_END
G1 E-.04 F1800
G1 X132.707 Y131.671 Z7.2 F36000
G1 X113.022 Y117.281 Z7.2
G1 Z6.8
G1 E.8 F1800
; LINE_WIDTH: 0.40114
G1 F12000
G1 X113.244 Y117.481 E.00871
G1 X112.245 Y116.444 F36000
; LINE_WIDTH: 0.467146
G1 F12000
G1 X111.97 Y115.862 E.02226
G1 X111.89 Y115.489 E.01318
G1 X107.879 Y111.478 E.19608
G1 X107.579 Y111.778 E.01466
G1 X112.202 Y116.402 E.22603
G1 X112.179 Y114.878 F36000
; LINE_WIDTH: 0.38292
G1 F12000
G1 X112.203 Y114.51 E.0102
G1 X112.302 Y114.336 E.00554
; WIPE_START
G1 X112.203 Y114.51 E-.26752
G1 X112.179 Y114.878 E-.49248
; WIPE_END
G1 E-.04 F1800
G1 X114.278 Y112.338 Z7.2 F36000
G1 Z6.8
G1 E.8 F1800
G1 F12000
G1 X114.511 Y112.201 E.00748
G1 X114.817 Y112.182 E.00851
G1 X107.973 Y110.778 F36000
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X110.715 Y108.034 E.10748
; Slow Down End
G1 X111.345 Y107.446 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X111.778 Y107.012 E.01883
; LINE_WIDTH: 0.440087
G1 X113.502 Y108.737 E.07892
; LINE_WIDTH: 0.48028
G1 X115.227 Y110.461 E.08691
; LINE_WIDTH: 0.520474
G1 X116.951 Y112.185 E.0949
; LINE_WIDTH: 0.440419
G1 X116.996 Y112.251 E.00259
; LINE_WIDTH: 0.481277
G1 X117.041 Y112.318 E.00286
; LINE_WIDTH: 0.522134
G1 X117.086 Y112.384 E.00312
; LINE_WIDTH: 0.562992
G1 X117.13 Y112.45 E.00339
; LINE_WIDTH: 0.520474
G1 X117.26 Y112.59 E.00742
; LINE_WIDTH: 0.48028
G1 X117.39 Y112.73 E.0068
; LINE_WIDTH: 0.488531
G1 X117.52 Y112.87 E.00693
G1 X118.07 Y113.304 E.02547
; LINE_WIDTH: 0.440087
G1 X124.768 Y120.002 E.30657
; LINE_WIDTH: 0.48028
G1 X131.466 Y126.7 E.33759
; LINE_WIDTH: 0.520474
G1 X138.164 Y133.398 E.36861
; LINE_WIDTH: 0.440418
G1 X138.209 Y133.465 E.00259
; LINE_WIDTH: 0.481273
G1 X138.254 Y133.531 E.00286
; LINE_WIDTH: 0.522128
G1 X138.299 Y133.597 E.00312
; LINE_WIDTH: 0.562983
G1 X138.344 Y133.663 E.00339
; LINE_WIDTH: 0.520474
G1 X138.473 Y133.803 E.00743
; LINE_WIDTH: 0.48028
G1 X138.603 Y133.943 E.0068
; LINE_WIDTH: 0.488524
G1 X138.733 Y134.083 E.00693
G1 X139.283 Y134.518 E.02547
; LINE_WIDTH: 0.418196
G1 X144.03 Y139.265 E.2053
G2 X143.384 Y139.927 I8.791 J9.225 E.02832
; Slow Down Start
; LINE_WIDTH: 0.417473
G1 F3000;_EXTRUDE_SET_SPEED
G1 X143.07 Y140.265 E.01406
G1 X143.068 Y140.043 E.00678
G2 X139.065 Y136.036 I-833.954 J829.154 E.17287
G1 X138.954 Y136.056 E.00344
G1 X138.869 Y136.175 E.00448
G1 X138.945 Y135.922 E.00807
G1 X138.788 Y135.732 E.00753
G2 X138.634 Y135.178 I-21.495 J5.674 E.01755
; Slow Down End
; LINE_WIDTH: 0.440418
G1 F12000
G1 X138.625 Y135.146 E.00105
; LINE_WIDTH: 0.481273
G1 X138.616 Y135.115 E.00116
; LINE_WIDTH: 0.522128
G1 X138.607 Y135.084 E.00127
; LINE_WIDTH: 0.497623
G1 X138.31 Y134.413 E.02718
; LINE_WIDTH: 0.562983
G1 X138.241 Y134.339 E.0043
; LINE_WIDTH: 0.522128
G1 X138.171 Y134.265 E.00396
; LINE_WIDTH: 0.481273
G1 X138.102 Y134.191 E.00362
; LINE_WIDTH: 0.483057
G1 X138.033 Y134.117 E.00364
G1 X137.691 Y133.961 E.01345
; LINE_WIDTH: 0.41999
G2 X137.056 Y133.6 I-1.221 J1.408 E.02261
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X136.502 Y133.47 E.01747
G1 X117.58 Y114.548 E.82224
G2 X117.426 Y113.969 I-2.5 J.358 E.01843
; Slow Down End
; LINE_WIDTH: 0.440419
G1 F12000
G1 X117.416 Y113.937 E.0011
; LINE_WIDTH: 0.481277
G1 X117.406 Y113.904 E.00122
; LINE_WIDTH: 0.522134
G1 X117.395 Y113.872 E.00133
; LINE_WIDTH: 0.497759
G1 X117.097 Y113.2 E.02725
; LINE_WIDTH: 0.562992
G1 X117.028 Y113.126 E.0043
; LINE_WIDTH: 0.522134
G1 X116.958 Y113.052 E.00396
; LINE_WIDTH: 0.481277
G1 X116.889 Y112.978 E.00362
; LINE_WIDTH: 0.483061
G1 X116.82 Y112.903 E.00364
G1 X116.478 Y112.748 E.01346
; LINE_WIDTH: 0.41999
G2 X115.843 Y112.386 I-1.221 J1.407 E.02261
; Slow Down Start
; LINE_WIDTH: 0.415699
G1 F3000;_EXTRUDE_SET_SPEED
G1 X115.289 Y112.256 E.01728
G1 X115.139 Y112.11 E.00637
G1 X114.877 Y112.178 E.00823
G1 X114.989 Y112.097 E.0042
G1 X115.023 Y111.999 E.00315
G1 X114.994 Y111.962 E.00144
G2 X111.001 Y107.973 I-301.349 J297.7 E.17145
; Slow Down End
; LINE_WIDTH: 0.400263
G1 F12000
G1 X110.757 Y107.991 E.00712
G1 X111.301 Y107.486 E.0216
G1 X111.478 Y107.879 F36000
; LINE_WIDTH: 0.467238
G1 F12000
G1 X115.489 Y111.89 E.19612
G1 X115.969 Y112.004 E.01707
G1 X116.397 Y112.2 E.01628
G2 X111.778 Y107.579 I-1174.322 J1169.268 E.22592
G1 X111.52 Y107.836 E.01259
G1 X116.69 Y112.446 F36000
; LINE_WIDTH: 0.419965
G1 F12000
G1 X116.567 Y112.342 E.00495
; LINE_WIDTH: 0.453015
G1 X116.443 Y112.239 E.00538
G1 X117.574 Y113.375 F36000
; LINE_WIDTH: 0.467173
G1 F12000
G1 X117.782 Y113.748 E.01476
G1 X117.94 Y114.288 E.01943
G1 X117.999 Y114.4 E.00437
G1 X136.702 Y133.103 E.91443
G1 X137.182 Y133.218 E.01708
G1 X137.611 Y133.413 E.01627
G1 X117.617 Y113.418 E.97757
G1 X137.903 Y133.659 F36000
; LINE_WIDTH: 0.419945
G1 F12000
M73 P90 R1
G1 X137.78 Y133.556 E.00495
; LINE_WIDTH: 0.452995
G1 X137.657 Y133.452 E.00538
G1 X138.783 Y134.583 F36000
; LINE_WIDTH: 0.466886
G1 F12000
G1 X139.005 Y134.997 E.01626
G1 X139.151 Y135.541 E.01946
G1 X143.164 Y139.565 E.19632
G1 X143.464 Y139.265 E.01466
G1 X139.67 Y135.471 E.18535
G2 X138.825 Y134.625 I-363.034 J361.658 E.04131
; CHANGE_LAYER
; Z_HEIGHT: 7
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X139.67 Y135.471 E-.45435
G1 X140.239 Y136.04 E-.30565
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
G1 X154.616 Y152.639
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X148.939 Y158.316 E.17359
G1 X147.669 Y157.046 E.05957
G1 X157.046 Y147.669 E.43992
G1 X158.026 Y148.648 E.04595
G1 X158.316 Y148.939 E.01362
G1 X154.658 Y152.596 E.1716
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X148.939 Y158.871 E.1608
G1 X147.114 Y157.046 E.07928
G1 X157.046 Y147.114 E.4316
G1 X158.303 Y148.371 E.05461
G1 X158.871 Y148.939 E.02466
G1 X155.213 Y152.596 E.15895
M204 S10000
G1 X154.453 Y152.968 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X155.604 Y154.12 E.05401
G1 X154.12 Y155.604 E.06964
G1 X154.76 Y156.245 E.03004
G1 X155.502 Y155.502 E.03482
G1 X152.604 Y152.604 E.13598
G1 X156.442 Y148.766 E.18005
G1 X157.219 Y149.543 E.03647
G1 X156.068 Y150.695 E.05401
G1 X150.695 Y156.068 F36000
G1 F15476.087
G1 X149.543 Y157.219 E.05401
G1 X148.766 Y156.442 E.03647
G1 X149.917 Y155.29 E.05401
; WIPE_START
G1 X148.766 Y156.442 E-.61876
G1 X149.029 Y156.705 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X144.452 Y150.596 Z7.4 F36000
G1 X111.551 Y106.685 Z7.4
G1 Z7
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X144.358 Y139.492 E1.53904
G1 X139.492 Y144.358 E.22826
G1 X106.685 Y111.551 E1.53904
G1 X111.508 Y106.727 E.22627
G1 X111.551 Y106.131 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X144.912 Y139.492 E1.44971
G1 X139.492 Y144.912 E.23553
G1 X106.131 Y111.551 E1.44971
G1 X111.508 Y106.173 E.23369
; WIPE_START
M204 S10000
G1 X112.924 Y107.585 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X111.227 Y107.538 Z7.4 F36000
G1 Z7
G1 E.8 F1800
; FEATURE: Bridge
; LINE_WIDTH: 0.4077
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X107.681 Y111.083 E.26673
G1 X108.004 Y111.407 E.02435
G1 X111.407 Y108.004 E.25596
G1 X111.731 Y108.328 E.02435
G1 X108.328 Y111.731 E.25596
G1 X108.652 Y112.054 E.02435
G1 X112.054 Y108.652 E.25596
G1 X112.378 Y108.975 E.02434
G1 X108.975 Y112.378 E.25596
G1 X109.299 Y112.702 E.02435
G1 X112.702 Y109.299 E.25596
G1 X113.025 Y109.623 E.02435
G1 X109.623 Y113.025 E.25596
G1 X109.946 Y113.349 E.02435
G1 X113.349 Y109.946 E.25596
G1 X113.673 Y110.27 E.02435
G1 X110.27 Y113.673 E.25596
G1 X110.594 Y113.996 E.02434
G1 X113.996 Y110.594 E.25596
G1 X114.32 Y110.917 E.02434
G1 X110.917 Y114.32 E.25596
G1 X111.241 Y114.644 E.02435
G1 X111.656 Y114.228 E.03125
G1 X111.598 Y114.609 E.02047
G1 X111.587 Y114.945 E.0179
G1 X111.421 Y115.11 E.01245
G1 X112.005 Y113.888 F36000
; LINE_WIDTH: 0.43099
; LAYER_HEIGHT: 0.2
G1 F3000
G1 X112.005 Y115.115 E.0388
G1 X112.044 Y115.43 E.01006
G1 X112.167 Y115.894 E.01516
G1 X112.303 Y116.214 E.01102
G1 X112.393 Y116.375 E.00582
G1 X112.393 Y114.224 E.06801
G1 X112.685 Y114.174 E.00936
G1 X112.781 Y113.968 E.00718
G1 X112.781 Y116.905 E.09286
G1 X113.169 Y117.249 E.01641
G1 X113.169 Y112.866 E.13862
G1 X113.3 Y112.996 E.00585
G1 X113.557 Y113.014 E.00815
G1 X113.557 Y117.492 E.14162
G1 X113.765 Y117.596 E.00736
G1 X113.946 Y117.662 E.00606
G1 X113.946 Y112.792 E.15399
G1 X114.174 Y112.685 E.00797
G1 X114.235 Y112.33 E.01139
G1 X114.041 Y112.135 E.00869
G1 X114.334 Y112.058 E.00957
G1 X114.334 Y117.77 E.18063
G1 X114.722 Y117.822 E.01238
G1 X114.722 Y112.005 E.18395
G1 X115.11 Y112.005 E.01227
G1 X115.11 Y117.822 E.18395
G1 X115.498 Y117.77 E.01238
G1 X115.498 Y112.057 E.18067
G1 X115.886 Y112.164 E.01273
G1 X115.886 Y117.042 E.15426
G1 X115.899 Y117.037 E.00045
G3 X116.174 Y116.886 I17.792 J32.091 E.00991
G1 X116.274 Y116.821 E.00378
G1 X116.274 Y112.334 E.1419
G1 X116.662 Y112.582 E.01457
G1 X116.662 Y116.966 E.13863
G1 X116.82 Y117.124 E.00706
G1 X117.05 Y116.899 E.01018
G1 X117.05 Y116.746 E.00482
G1 X116.837 Y116.533 E.00954
G1 X116.811 Y116.288 E.00778
G2 X117.05 Y115.865 I-2.433 J-1.653 E.01539
G1 X117.05 Y112.933 E.09272
G1 X117.217 Y113.124 E.00803
G1 X117.438 Y113.454 E.01255
G1 X117.438 Y115.6 E.06787
G1 X117.494 Y115.588 E.0018
G1 X117.697 Y115.791 E.00908
G1 X117.79 Y115.405 E.01258
G1 X117.826 Y115.06 E.01095
G1 X117.826 Y113.903 E.0366
G1 X114.739 Y111.793 F36000
; LINE_WIDTH: 0.4077
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X114.967 Y111.564 E.01718
G1 X114.643 Y111.241 E.02435
G1 X114.228 Y111.656 E.03126
G1 X113.732 Y111.8 E.02746
G1 X113.369 Y112.048 E.02338
G1 X113.603 Y112.282 E.01755
G1 X113.243 Y112.641 E.02704
G1 X112.781 Y112.687 F36000
; LINE_WIDTH: 0.43099
; LAYER_HEIGHT: 0.2
G1 F3000
G1 X112.781 Y113.325 E.02019
G1 X112.641 Y113.243 F36000
; LINE_WIDTH: 0.4077
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X112.139 Y113.746 E.0378
; WIPE_START
G1 X112.641 Y113.243 E-.76
; WIPE_END
G1 E-.04 F1800
G17
G3 Z7.4 I-1.055 J.607 P1  F36000
G1 X115.635 Y118.45 Z7.4
G1 Z7
G1 E.8 F1800
; LINE_WIDTH: 0.40283
G1 F3000
G1 X116.598 Y117.487 E.07075
G1 X116.783 Y117.672 E.01358
G1 X117.19 Y117.345 E.02711
G1 X117.437 Y117.09 E.0184
G1 X117.672 Y116.784 E.02008
G1 X117.487 Y116.598 E.01362
G1 X118.406 Y115.68 E.06746
G1 X118.726 Y116 E.02351
G1 X116.025 Y118.7 E.19833
G1 X116.095 Y118.815 E.00699
G1 X115.929 Y119.331 E.02816
G1 X115.982 Y119.384 E.00388
G1 X119.046 Y116.32 E.22503
G1 X119.366 Y116.64 E.02351
G1 X116.302 Y119.704 E.22503
G1 X116.622 Y120.025 E.02351
G1 X119.686 Y116.96 E.22503
G1 X120.007 Y117.281 E.02351
G1 X116.942 Y120.345 E.22503
G1 X117.262 Y120.665 E.02351
G1 X120.327 Y117.601 E.22503
G1 X120.647 Y117.921 E.02351
G1 X117.583 Y120.985 E.22503
G1 X117.903 Y121.305 E.02351
G1 X120.967 Y118.241 E.22503
G1 X121.287 Y118.561 E.02351
G1 X118.223 Y121.626 E.22503
G1 X118.543 Y121.946 E.02351
G1 X121.608 Y118.882 E.22503
G1 X121.684 Y118.958 E.00559
G1 X122.195 Y118.793 E.02792
G1 X122.266 Y118.863 E.0052
G1 X119.202 Y121.928 E.22503
G1 X119.522 Y122.248 E.02351
G1 X122.586 Y119.184 E.22503
G1 X122.906 Y119.504 E.02351
G1 X119.842 Y122.568 E.22503
G1 X120.162 Y122.888 E.02351
G1 X123.227 Y119.824 E.22503
G1 X123.547 Y120.144 E.02351
G1 X120.483 Y123.209 E.22503
G1 X120.803 Y123.529 E.02351
G1 X123.867 Y120.464 E.22503
G1 X124.187 Y120.785 E.02351
G1 X121.123 Y123.849 E.22503
G1 X121.443 Y124.169 E.02351
G1 X124.507 Y121.105 E.22503
G1 X124.828 Y121.425 E.02351
G1 X121.763 Y124.489 E.22503
G1 X122.084 Y124.81 E.02351
G1 X125.148 Y121.745 E.22503
G1 X125.468 Y122.065 E.02351
G1 X122.404 Y125.13 E.22503
G1 X122.724 Y125.45 E.02351
G1 X125.788 Y122.386 E.22503
G1 X125.626 Y122.9 E.028
G1 X125.77 Y123.044 E.0106
G1 X122.706 Y126.108 E.22503
G1 X123.026 Y126.429 E.02351
G1 X126.09 Y123.364 E.22503
G1 X126.411 Y123.685 E.02351
G1 X123.346 Y126.749 E.22503
G1 X123.666 Y127.069 E.02351
G1 X126.731 Y124.005 E.22503
G1 X127.051 Y124.325 E.02351
G1 X123.987 Y127.389 E.22503
G1 X124.307 Y127.709 E.02351
G1 X127.371 Y124.645 E.22503
G1 X127.691 Y124.965 E.02351
G1 X124.627 Y128.03 E.22503
G1 X124.947 Y128.35 E.02351
G1 X128.011 Y125.286 E.22503
G1 X128.332 Y125.606 E.02351
G1 X125.267 Y128.67 E.22503
G1 X125.588 Y128.99 E.02351
G1 X128.652 Y125.926 E.22503
G1 X128.972 Y126.246 E.02351
G1 X125.908 Y129.31 E.22503
G1 X126.206 Y129.609 E.02193
G1 X126.27 Y129.589 E.00346
G1 X129.292 Y126.566 E.22195
G1 X129.32 Y126.594 E.00206
G1 X129.832 Y126.429 E.02792
G1 X129.951 Y126.548 E.00873
G1 X126.887 Y129.613 E.22503
G1 X127.207 Y129.933 E.02351
G1 X130.271 Y126.868 E.22503
G1 X130.591 Y127.189 E.02351
G1 X127.527 Y130.253 E.22503
G1 X127.847 Y130.573 E.02351
G1 X130.911 Y127.509 E.22503
G1 X131.232 Y127.829 E.02351
G1 X128.167 Y130.893 E.22503
G1 X128.488 Y131.213 E.02351
G1 X131.552 Y128.149 E.22503
G1 X131.872 Y128.469 E.02351
G1 X128.808 Y131.534 E.22503
G1 X129.128 Y131.854 E.02351
G1 X132.192 Y128.79 E.22503
G1 X132.512 Y129.11 E.02351
G1 X129.448 Y132.174 E.22503
G1 X129.768 Y132.494 E.02351
M73 P91 R1
G1 X132.833 Y129.43 E.22503
G1 X133.153 Y129.75 E.02351
G1 X130.089 Y132.814 E.22503
G1 X130.409 Y133.135 E.02351
G1 X133.384 Y130.159 E.21851
G1 X133.262 Y130.537 E.02059
G1 X133.455 Y130.729 E.01413
G1 X130.391 Y133.793 E.22503
G1 X130.711 Y134.113 E.02351
G1 X133.775 Y131.049 E.22503
G1 X134.095 Y131.369 E.02351
G1 X131.031 Y134.434 E.22503
G1 X131.351 Y134.754 E.02351
G1 X134.423 Y131.682 E.2256
G1 X134.923 Y131.52 E.02728
G1 X135.074 Y131.671 E.01108
G1 X131.671 Y135.074 E.24988
G1 X131.992 Y135.394 E.02351
G1 X135.394 Y131.992 E.24988
G1 X135.576 Y132.173 E.01335
G1 X135.262 Y132.764 E.03476
G1 X134.457 Y133.569 E.05909
G1 X134.252 Y133.365 E.01502
G1 X133.714 Y133.835 E.0371
G1 X133.365 Y134.254 E.02833
G1 X133.569 Y134.457 E.01495
G1 X132.275 Y135.752 E.09504
G1 X133.218 Y135.101 F36000
; LINE_WIDTH: 0.43099
; LAYER_HEIGHT: 0.2
G1 F3000
G1 X133.218 Y136.328 E.0388
G1 X133.257 Y136.642 E.01001
G1 X133.379 Y137.105 E.01513
G1 X133.518 Y137.43 E.01118
G1 X133.606 Y137.588 E.00573
G1 X133.606 Y135.438 E.06801
G1 X133.898 Y135.387 E.00936
G1 X133.995 Y135.181 E.00717
G1 X133.995 Y138.118 E.09286
G1 X134.383 Y138.462 E.01641
G1 X134.383 Y134.079 E.13862
G1 X134.514 Y134.21 E.00585
G1 X134.771 Y134.227 E.00815
G1 X134.771 Y138.705 E.14162
G1 X134.982 Y138.811 E.00747
G1 X135.159 Y138.875 E.00595
G1 X135.159 Y134.005 E.15399
G1 X135.387 Y133.898 E.00797
G1 X135.449 Y133.543 E.0114
G1 X135.254 Y133.349 E.00869
G1 X135.547 Y133.271 E.00957
G1 X135.547 Y138.983 E.18063
G1 X135.935 Y139.035 E.01238
G1 X135.935 Y133.218 E.18395
G1 X136.323 Y133.218 E.01227
G1 X136.323 Y139.035 E.18395
G1 X136.711 Y138.983 E.01238
G1 X136.711 Y133.27 E.18067
G1 X137.099 Y133.377 E.01273
G1 X137.105 Y138.253 E.15419
G2 X137.487 Y138.034 I-3.275 J-6.163 E.01392
G1 X137.487 Y133.547 E.1419
G1 X137.875 Y133.795 E.01457
G1 X137.875 Y138.179 E.13863
G1 X138.033 Y138.337 E.00706
G1 X138.263 Y138.112 E.01018
G1 X138.263 Y137.959 E.00482
G1 X138.05 Y137.746 E.00955
G1 X138.024 Y137.501 E.00779
G1 X138.09 Y137.401 E.00376
G2 X138.263 Y137.078 I-1.177 J-.841 E.01163
G1 X138.263 Y134.146 E.09272
G1 X138.428 Y134.334 E.00789
G1 X138.651 Y134.667 E.01269
G1 X138.651 Y136.813 E.06787
G1 X138.707 Y136.801 E.0018
G1 X138.91 Y137.004 E.00908
G1 X139.005 Y136.609 E.01285
G1 X139.039 Y136.273 E.01067
G1 X139.039 Y135.116 E.0366
G1 X139.622 Y135.933 F36000
; LINE_WIDTH: 0.40764
; LAYER_HEIGHT: 0.4
G1 F3000
G1 X139.457 Y136.097 E.01236
G1 X139.429 Y136.559 E.02458
G1 X139.383 Y136.819 E.01407
G1 X139.802 Y136.4 E.03155
G1 X140.126 Y136.723 E.02433
G1 X136.723 Y140.126 E.25588
G1 X137.047 Y140.45 E.02433
G1 X140.45 Y137.047 E.25588
G1 X140.773 Y137.37 E.02433
G1 X137.37 Y140.773 E.25588
G1 X137.694 Y141.097 E.02433
G1 X141.097 Y137.694 E.25588
G1 X141.42 Y138.018 E.02433
G1 X138.018 Y141.42 E.25588
G1 X138.341 Y141.744 E.02434
G1 X141.744 Y138.341 E.25588
G1 X142.068 Y138.665 E.02433
G1 X138.665 Y142.068 E.25588
G1 X138.988 Y142.391 E.02433
G1 X142.391 Y138.988 E.25588
G1 X142.715 Y139.312 E.02433
G1 X139.312 Y142.715 E.25588
G1 X139.636 Y143.038 E.02433
G1 X143.038 Y139.636 E.25588
G1 X143.362 Y139.959 E.02433
G1 X139.816 Y143.505 E.26665
G1 X136.256 Y139.946 F36000
G1 F3000
G1 X136.819 Y139.383 E.04231
G1 X136.566 Y139.428 E.01366
G1 X136.097 Y139.457 E.02498
G1 X135.933 Y139.622 E.01237
G1 X137.297 Y138.905 F36000
G1 F3000
G1 X137.8 Y138.402 E.03779
G1 X138.402 Y137.8 F36000
G1 F3000
G1 X138.905 Y137.297 E.03779
G1 X138.025 Y133.566 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.388866
; LAYER_HEIGHT: 0.2
G1 F12000
G3 X139.168 Y134.858 I-4.643 J5.259 E.04874
; LINE_WIDTH: 0.444284
G1 X139.217 Y134.939 E.00311
; LINE_WIDTH: 0.488932
G1 X139.267 Y135.02 E.00346
; LINE_WIDTH: 0.53358
G1 X139.317 Y135.102 E.00381
; LINE_WIDTH: 0.578228
G1 F11768.925
G1 X139.366 Y135.183 E.00415
; LINE_WIDTH: 0.646569
G1 F10436.533
G1 X139.416 Y135.264 E.00468
G1 X143.599 Y139.449 E.29107
G1 X137.42 Y133.109 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X136.465 Y132.154 E.04151
; LINE_WIDTH: 0.442879
G1 X136.386 Y132.107 E.00302
; LINE_WIDTH: 0.488657
G1 X136.306 Y132.059 E.00336
; LINE_WIDTH: 0.534435
G1 X136.226 Y132.012 E.00371
; LINE_WIDTH: 0.580213
G1 F11725.446
G1 X136.147 Y131.965 E.00405
; LINE_WIDTH: 0.625991
G1 F10804.859
G1 X136.067 Y131.918 E.0044
G1 X136.058 Y131.978 E.00291
; LINE_WIDTH: 0.580213
G1 F11725.446
G1 X136.048 Y132.039 E.00268
; LINE_WIDTH: 0.534435
G1 F12000
G1 X136.038 Y132.099 E.00246
; LINE_WIDTH: 0.488657
G1 X136.029 Y132.16 E.00223
; LINE_WIDTH: 0.420544
G1 X136.019 Y132.221 E.00189
G1 X135.67 Y132.877 E.02287
G1 X135.972 Y132.84 E.00934
G1 X136.626 Y132.874 E.02016
G1 X137.131 Y132.992 E.01595
G1 X137.365 Y133.087 E.00777
G1 X136.31 Y132.454 F36000
; LINE_WIDTH: 0.3946
G1 F12000
G1 X136.244 Y132.492 E.00218
G1 X136.296 Y132.522 E.00172
G1 X135.16 Y131.014 F36000
; LINE_WIDTH: 0.64898
G1 F10395.019
G1 X136.025 Y131.875 E.06026
G1 X135.16 Y131.014 F36000
; LINE_WIDTH: 0.628927
G1 F10750.739
G1 X135.122 Y130.941 E.00397
; LINE_WIDTH: 0.579819
G1 F11734.057
G1 X135.083 Y130.867 E.00364
; LINE_WIDTH: 0.530712
G1 F12000
G1 X135.044 Y130.794 E.0033
; LINE_WIDTH: 0.481604
G1 X135.005 Y130.72 E.00297
; LINE_WIDTH: 0.435723
G2 X134.238 Y129.932 I-10.682 J9.629 E.0352
; LINE_WIDTH: 0.449386
G1 X134.17 Y129.896 E.00256
; LINE_WIDTH: 0.493718
G1 X134.102 Y129.859 E.00284
; LINE_WIDTH: 0.53805
G1 X134.034 Y129.822 E.00312
; LINE_WIDTH: 0.582382
G1 F11678.302
G1 X133.966 Y129.785 E.0034
; LINE_WIDTH: 0.626714
G1 F10791.478
G1 X133.898 Y129.749 E.00368
G1 X133.892 Y129.803 E.00262
; LINE_WIDTH: 0.582382
G1 F11678.302
G1 X133.886 Y129.858 E.00242
; LINE_WIDTH: 0.53805
G1 F12000
G1 X133.879 Y129.913 E.00222
; LINE_WIDTH: 0.493718
G1 X133.873 Y129.967 E.00202
; LINE_WIDTH: 0.449386
G1 X133.867 Y130.022 E.00182
; LINE_WIDTH: 0.420981
G1 X133.734 Y130.423 E.01301
G1 X134.525 Y131.214 E.03448
; LINE_WIDTH: 0.443339
G1 X134.641 Y131.178 E.00395
; LINE_WIDTH: 0.490037
G1 X134.756 Y131.142 E.00442
; LINE_WIDTH: 0.536735
G1 X134.872 Y131.105 E.00488
; LINE_WIDTH: 0.583433
G1 F11655.594
G1 X134.988 Y131.069 E.00534
; LINE_WIDTH: 0.630131
G1 F10728.682
G1 X135.103 Y131.032 E.0058
G1 X134.137 Y130.326 F36000
; LINE_WIDTH: 0.37326
G1 F12000
G1 X134.58 Y130.769 E.01687
G1 X130.069 Y125.923 F36000
; LINE_WIDTH: 0.648903
G1 F10396.339
G1 X133.856 Y129.706 E.26431
G1 X130.069 Y125.923 F36000
; LINE_WIDTH: 0.628907
G1 F10751.105
G1 X130.03 Y125.85 E.00397
; LINE_WIDTH: 0.579799
G1 F11734.493
G1 X129.992 Y125.776 E.00364
; LINE_WIDTH: 0.530692
G1 F12000
G1 X129.953 Y125.702 E.0033
; LINE_WIDTH: 0.481584
G1 X129.914 Y125.629 E.00297
; LINE_WIDTH: 0.420965
G1 X129.781 Y125.47 E.00638
G1 X126.602 Y122.296 E.13841
; LINE_WIDTH: 0.449386
G1 X126.534 Y122.259 E.00256
; LINE_WIDTH: 0.493718
G1 X126.466 Y122.222 E.00284
; LINE_WIDTH: 0.53805
G1 X126.398 Y122.185 E.00312
; LINE_WIDTH: 0.582382
G1 F11678.302
G1 X126.329 Y122.149 E.0034
; LINE_WIDTH: 0.626714
G1 F10791.478
G1 X126.261 Y122.112 E.00368
G1 X126.255 Y122.167 E.00262
; LINE_WIDTH: 0.582382
G1 F11678.302
G1 X126.249 Y122.221 E.00242
; LINE_WIDTH: 0.53805
G1 F12000
G1 X126.243 Y122.276 E.00222
; LINE_WIDTH: 0.493718
G1 X126.236 Y122.331 E.00202
; LINE_WIDTH: 0.449386
G1 X126.23 Y122.385 E.00182
; LINE_WIDTH: 0.420287
G1 X126.097 Y122.786 E.01299
G1 X129.434 Y126.123 E.14512
; LINE_WIDTH: 0.443337
G1 X129.55 Y126.087 E.00395
; LINE_WIDTH: 0.490031
G1 X129.665 Y126.05 E.00442
; LINE_WIDTH: 0.536725
G1 X129.781 Y126.014 E.00488
; LINE_WIDTH: 0.583419
G1 F11655.896
G1 X129.896 Y125.978 E.00534
; LINE_WIDTH: 0.630113
G1 F10729.011
G1 X130.012 Y125.941 E.0058
G1 X126.5 Y122.689 F36000
; LINE_WIDTH: 0.37327
G1 F12000
G1 X129.489 Y125.678 E.11378
G1 X122.432 Y118.286 F36000
; LINE_WIDTH: 0.648903
G1 F10396.335
G1 X126.219 Y122.07 E.26431
G1 X122.432 Y118.286 F36000
; LINE_WIDTH: 0.628944
G1 F10750.418
G1 X122.394 Y118.213 E.00397
; LINE_WIDTH: 0.579832
G1 F11733.783
G1 X122.355 Y118.139 E.00364
; LINE_WIDTH: 0.530719
G1 F12000
G1 X122.316 Y118.066 E.0033
; LINE_WIDTH: 0.481607
G1 X122.277 Y117.992 E.00297
; LINE_WIDTH: 0.420289
G1 X122.145 Y117.833 E.00637
G1 X117.959 Y113.652 E.18192
G1 X118.119 Y114.16 E.01638
G1 X118.206 Y114.861 E.02172
G1 X118.177 Y115.32 E.01414
G1 X118.271 Y115.227 E.00407
G1 X118.465 Y115.182 E.00611
G1 X118.538 Y115.227 E.00264
G1 X121.797 Y118.486 E.14175
; LINE_WIDTH: 0.443341
G1 X121.913 Y118.45 E.00395
; LINE_WIDTH: 0.490043
G1 X122.028 Y118.414 E.00442
; LINE_WIDTH: 0.536745
G1 X122.144 Y118.377 E.00488
; LINE_WIDTH: 0.583447
G1 F11655.292
G1 X122.26 Y118.341 E.00534
; LINE_WIDTH: 0.630149
G1 F10728.354
G1 X122.375 Y118.304 E.0058
G1 X118.587 Y114.818 F36000
; LINE_WIDTH: 0.417845
G1 F12000
G1 X118.687 Y114.897 E.0039
; LINE_WIDTH: 0.373696
G1 X118.788 Y114.977 E.00344
G1 X121.852 Y118.041 E.11681
G1 X111.551 Y107.401 F36000
; LINE_WIDTH: 0.64889
G1 F10396.555
G1 X115.769 Y111.62 E.29457
; LINE_WIDTH: 0.626735
G1 F10791.09
G1 X115.874 Y111.687 E.00591
; LINE_WIDTH: 0.582405
G1 F11677.805
G1 X115.978 Y111.754 E.00546
; LINE_WIDTH: 0.538075
G1 F12000
G1 X116.083 Y111.821 E.00501
; LINE_WIDTH: 0.493745
G1 X116.187 Y111.888 E.00457
; LINE_WIDTH: 0.449415
G1 X116.292 Y111.956 E.00412
; LINE_WIDTH: 0.384445
G3 X117.611 Y113.181 I-3.427 J5.01 E.0503
G1 X133.995 Y133.9 F36000
; FEATURE: Bridge
; LINE_WIDTH: 0.43099
G1 F3000
G1 X133.995 Y134.538 E.02019
G1 X133.503 Y137.952 F36000
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.384688
G1 F12000
G2 X134.798 Y139.127 I5.803 J-5.093 E.04881
; LINE_WIDTH: 0.418914
G1 X134.89 Y139.185 E.00333
; LINE_WIDTH: 0.467422
G1 X134.982 Y139.243 E.00377
; LINE_WIDTH: 0.51593
G1 X135.074 Y139.301 E.0042
; LINE_WIDTH: 0.564438
G1 X135.166 Y139.358 E.00463
; LINE_WIDTH: 0.612946
G1 F11052.128
G1 X135.259 Y139.416 E.00506
; LINE_WIDTH: 0.648857
G1 F10397.131
G1 X139.449 Y143.599 E.29235
G1 X133.112 Y137.423 F36000
; LINE_WIDTH: 0.41999
G1 F12000
G1 X132.922 Y136.871 E.01797
G3 X132.873 Y135.672 I3.613 J-.746 E.03702
G1 X132.221 Y136.019 E.02272
; LINE_WIDTH: 0.443337
G1 X132.168 Y136.036 E.00181
; LINE_WIDTH: 0.490031
G1 X132.115 Y136.053 E.00202
; LINE_WIDTH: 0.536725
G1 X132.062 Y136.069 E.00223
; LINE_WIDTH: 0.583419
G1 F11655.896
G1 X132.009 Y136.086 E.00244
; LINE_WIDTH: 0.630113
G1 F10729.011
G1 X131.957 Y136.103 E.00265
G1 X132.011 Y136.19 E.00492
; LINE_WIDTH: 0.583419
G1 F11655.896
G1 X132.065 Y136.278 E.00453
; LINE_WIDTH: 0.536725
G1 F12000
G1 X132.12 Y136.365 E.00414
; LINE_WIDTH: 0.490031
G1 X132.174 Y136.452 E.00375
; LINE_WIDTH: 0.421849
G1 X132.228 Y136.54 E.00318
G1 X133.07 Y137.381 E.03674
G1 X132.503 Y136.25 F36000
; LINE_WIDTH: 0.38256
G1 F12000
G1 X132.439 Y136.286 E.00203
G1 X132.488 Y136.314 E.00155
G1 X129.777 Y133.926 F36000
; LINE_WIDTH: 0.64888
G1 F10396.726
G1 X131.913 Y136.062 E.14913
G1 X129.777 Y133.926 F36000
; LINE_WIDTH: 0.626714
G1 F10791.478
G1 X129.783 Y133.872 E.00262
; LINE_WIDTH: 0.582382
G1 F11678.302
G1 X129.79 Y133.817 E.00242
; LINE_WIDTH: 0.53805
G1 F12000
G1 X129.796 Y133.763 E.00222
; LINE_WIDTH: 0.493718
G1 X129.802 Y133.708 E.00202
; LINE_WIDTH: 0.449386
G1 X129.808 Y133.653 E.00182
; LINE_WIDTH: 0.420287
G1 X129.942 Y133.252 E.01299
G1 X126.604 Y129.915 E.14512
; LINE_WIDTH: 0.443341
G1 X126.477 Y129.955 E.00435
; LINE_WIDTH: 0.490043
G1 X126.35 Y129.995 E.00485
; LINE_WIDTH: 0.536745
G1 X126.223 Y130.035 E.00536
; LINE_WIDTH: 0.583447
G1 F11655.292
G1 X126.096 Y130.075 E.00587
; LINE_WIDTH: 0.630149
G1 F10728.354
G1 X125.969 Y130.115 E.00637
; LINE_WIDTH: 0.628943
G1 F10750.441
G1 X126.008 Y130.189 E.00397
; LINE_WIDTH: 0.579828
G1 F11733.865
G1 X126.047 Y130.262 E.00364
; LINE_WIDTH: 0.530713
G1 F12000
G1 X126.086 Y130.336 E.0033
; LINE_WIDTH: 0.481598
G1 X126.125 Y130.41 E.00297
; LINE_WIDTH: 0.420965
G1 X126.257 Y130.568 E.00638
G1 X129.437 Y133.743 E.13841
; LINE_WIDTH: 0.449386
G1 X129.494 Y133.774 E.00216
; LINE_WIDTH: 0.493718
G1 X129.552 Y133.805 E.0024
; LINE_WIDTH: 0.53805
G1 X129.609 Y133.836 E.00264
; LINE_WIDTH: 0.582382
G1 F11678.302
G1 X129.667 Y133.867 E.00287
; LINE_WIDTH: 0.626714
G1 F10791.478
G1 X129.724 Y133.898 E.00311
G1 X126.507 Y130.318 F36000
; LINE_WIDTH: 0.37326
G1 F12000
G1 X129.496 Y133.307 E.11378
G1 X122.14 Y126.29 F36000
; LINE_WIDTH: 0.64889
G1 F10396.555
G1 X125.925 Y130.075 E.26431
G1 X122.14 Y126.29 F36000
; LINE_WIDTH: 0.626714
G1 F10791.478
G1 X122.147 Y126.235 E.00262
; LINE_WIDTH: 0.582382
G1 F11678.302
G1 X122.153 Y126.18 E.00242
; LINE_WIDTH: 0.53805
G1 F12000
G1 X122.159 Y126.126 E.00222
; LINE_WIDTH: 0.493718
G1 X122.165 Y126.071 E.00202
; LINE_WIDTH: 0.449386
G1 X122.172 Y126.017 E.00182
; LINE_WIDTH: 0.420287
G1 X122.305 Y125.616 E.01299
G1 X118.968 Y122.279 E.14512
; LINE_WIDTH: 0.443339
G1 X118.841 Y122.319 E.00435
; LINE_WIDTH: 0.490037
G1 X118.714 Y122.359 E.00485
; LINE_WIDTH: 0.536735
G1 X118.587 Y122.399 E.00536
; LINE_WIDTH: 0.583433
G1 F11655.594
G1 X118.46 Y122.439 E.00587
; LINE_WIDTH: 0.630131
G1 F10728.682
G1 X118.333 Y122.479 E.00637
; LINE_WIDTH: 0.628927
G1 F10750.739
G1 X118.371 Y122.552 E.00397
; LINE_WIDTH: 0.579819
G1 F11734.057
G1 X118.41 Y122.626 E.00364
; LINE_WIDTH: 0.530712
G1 F12000
G1 X118.449 Y122.699 E.0033
; LINE_WIDTH: 0.481604
G1 X118.488 Y122.773 E.00297
; LINE_WIDTH: 0.420965
G1 X118.62 Y122.932 E.00638
G1 X121.8 Y126.106 E.13841
; LINE_WIDTH: 0.449386
G1 X121.858 Y126.137 E.00216
; LINE_WIDTH: 0.493718
G1 X121.915 Y126.168 E.0024
; LINE_WIDTH: 0.53805
G1 X121.973 Y126.199 E.00264
; LINE_WIDTH: 0.582382
G1 F11678.302
G1 X122.03 Y126.23 E.00287
; LINE_WIDTH: 0.626714
G1 F10791.478
G1 X122.088 Y126.261 E.00311
G1 X118.871 Y122.682 F36000
; LINE_WIDTH: 0.37327
G1 F12000
G1 X121.859 Y125.67 E.11379
G1 X115.458 Y119.608 F36000
; LINE_WIDTH: 0.64889
G1 F10396.555
G1 X118.289 Y122.438 E.19765
G1 X115.458 Y119.608 F36000
; LINE_WIDTH: 0.626732
G1 F10791.145
G1 X115.464 Y119.553 E.00262
; LINE_WIDTH: 0.582396
G1 F11677.999
G1 X115.471 Y119.498 E.00242
; LINE_WIDTH: 0.53806
G1 F12000
G1 X115.477 Y119.444 E.00222
; LINE_WIDTH: 0.493724
G1 X115.483 Y119.389 E.00202
; LINE_WIDTH: 0.449388
G1 X115.49 Y119.334 E.00182
; LINE_WIDTH: 0.420554
G1 X115.643 Y118.869 E.01508
G1 X115.336 Y118.366 E.01814
G1 X115.324 Y118.184 E.00563
G1 X114.635 Y118.194 E.02122
G3 X113.636 Y117.947 I.248 J-3.143 E.0318
G2 X115.118 Y119.424 I62.639 J-61.373 E.06439
; LINE_WIDTH: 0.449388
G1 X115.175 Y119.455 E.00216
; LINE_WIDTH: 0.493724
G1 X115.233 Y119.486 E.0024
; LINE_WIDTH: 0.53806
G1 X115.29 Y119.517 E.00264
; LINE_WIDTH: 0.582396
G1 F11677.999
G1 X115.348 Y119.548 E.00287
; LINE_WIDTH: 0.626732
G1 F10791.145
G1 X115.405 Y119.579 E.00311
G1 X115.005 Y118.584 F36000
; LINE_WIDTH: 0.57374
G1 F11868.43
G2 X115.008 Y118.693 I-.028 J.056 E.0112
G1 X107.401 Y111.551 F36000
; LINE_WIDTH: 0.64889
G1 F10396.555
G1 X111.628 Y115.777 E.29512
; LINE_WIDTH: 0.626735
G1 F10791.09
G1 X111.682 Y115.864 E.00489
; LINE_WIDTH: 0.582405
G1 F11677.805
G1 X111.737 Y115.951 E.00451
; LINE_WIDTH: 0.538075
G1 F12000
G1 X111.791 Y116.038 E.00414
; LINE_WIDTH: 0.493745
G1 X111.846 Y116.125 E.00377
; LINE_WIDTH: 0.449415
G1 X111.9 Y116.212 E.0034
; LINE_WIDTH: 0.384165
G2 X113.123 Y117.562 I4.984 J-3.287 E.05085
; CHANGE_LAYER
; Z_HEIGHT: 7.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X112.636 Y117.12 E-.27334
G1 X112.279 Y116.725 E-.22143
G1 X111.9 Y116.212 E-.26523
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
G1 X154.616 Y152.639
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X149.076 Y158.179 E.16714
G1 X147.806 Y156.909 E.05957
G1 X156.909 Y147.806 E.42703
G1 X158.179 Y149.076 E.05957
G1 X154.658 Y152.596 E.16515
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X149.076 Y158.733 E.15482
G1 X147.252 Y156.909 E.07928
G1 X156.909 Y147.252 E.41965
G1 X157.13 Y147.473 E.0096
G1 X158.733 Y149.076 E.06968
G1 X155.213 Y152.596 E.15298
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.123 Y152.495 Z7.6 F36000
G1 Z7.2
G1 E.8 F1800
; Slow Down Start
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.539279
G1 F3000;_EXTRUDE_SET_SPEED
G1 X155.595 Y151.021 E.08424
; Slow Down End
G1 X154.123 Y152.495 F36000
; Slow Down Start
; LINE_WIDTH: 0.522482
G1 F3000;_EXTRUDE_SET_SPEED
G1 X154.147 Y152.588 E.00372
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.481485
;_EXTRUDE_SET_SPEED
G1 X154.171 Y152.68 E.00341
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.420388
;_EXTRUDE_SET_SPEED
G1 X154.195 Y152.772 E.00293
G1 X156.183 Y154.76 E.08648
G1 X154.76 Y156.183 E.06188
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.439862
;_EXTRUDE_SET_SPEED
G1 X154.098 Y155.52 E.03031
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.479605
;_EXTRUDE_SET_SPEED
G1 X153.435 Y154.857 E.03335
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.519349
;_EXTRUDE_SET_SPEED
G1 X152.772 Y154.195 E.03638
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.456712
;_EXTRUDE_SET_SPEED
G1 X152.463 Y154.153 E.01051
G1 X152.772 Y153.759 E.01686
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.440489
;_EXTRUDE_SET_SPEED
G1 X153.101 Y153.43 E.01508
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.481485
;_EXTRUDE_SET_SPEED
G1 X153.43 Y153.101 E.01663
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.503603
;_EXTRUDE_SET_SPEED
G3 X154.076 Y152.532 I2.422 J2.093 E.03241
; Slow Down End
G1 X153.977 Y153.088 F36000
; Slow Down Start
; LINE_WIDTH: 0.41999
G1 F3000;_EXTRUDE_SET_SPEED
G1 X155.649 Y154.76 E.07267
G1 X154.76 Y155.649 E.03864
G1 X153.088 Y153.977 E.07267
G1 X153.935 Y153.13 E.0368
; Slow Down End
G1 X153.977 Y153.666 F36000
; Slow Down Start
; LINE_WIDTH: 0.48318
G1 F3000;_EXTRUDE_SET_SPEED
G1 X155.072 Y154.76 E.05553
G1 X154.76 Y155.072 E.0158
G1 X153.666 Y153.977 E.05553
G1 X153.935 Y153.708 E.01364
; Slow Down End
G1 X150.979 Y155.637 F36000
; Slow Down Start
; LINE_WIDTH: 0.53918
G1 F3000;_EXTRUDE_SET_SPEED
G1 X152.421 Y154.195 E.08247
; Slow Down End
G1 X149.917 Y155.29 F36000
; FEATURE: Sparse infill
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X148.766 Y156.442 E.05401
G1 X149.543 Y157.219 E.03647
G1 X150.733 Y156.03 E.0558
G3 X150.511 Y155.467 I.17 J-.392 E.02229
G1 X152.989 Y152.989 E.11625
G1 X152.604 Y152.604 E.01806
G1 X156.442 Y148.766 E.18005
G1 X157.219 Y149.543 E.03647
G1 X156.068 Y150.695 E.05401
; WIPE_START
G1 X157.219 Y149.543 E-.61876
G1 X156.956 Y149.28 E-.14124
; WIPE_END
G1 E-.04 F1800
G1 X151.36 Y144.09 Z7.6 F36000
G1 X111.298 Y106.938 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Inner wall
G1 F15476.087
G1 X144.105 Y139.745 E1.53904
G1 X139.745 Y144.105 E.20456
G1 X106.938 Y111.298 E1.53904
G1 X111.256 Y106.98 E.20257
G1 X111.298 Y106.383 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X117.663 Y112.748 E.2766
G1 X144.659 Y139.745 E1.17311
G1 X139.745 Y144.659 E.21358
G1 X106.383 Y111.298 E1.44971
G1 X111.256 Y106.426 E.21173
; WIPE_START
M204 S10000
G1 X112.679 Y107.83 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X117.645 Y113.627 Z7.6 F36000
G1 X141.648 Y141.648 Z7.6
G1 Z7.2
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X143.55 Y139.745 E.08269
G1 X111.298 Y107.492 E1.40149
G1 X107.492 Y111.298 E.16538
G1 X139.745 Y143.551 E1.40149
G1 X141.605 Y141.69 E.08085
G1 X141.381 Y141.381 F36000
G1 F12000
M73 P92 R1
G1 X143.017 Y139.745 E.07111
G1 X111.298 Y108.025 E1.37831
G1 X108.025 Y111.298 E.14221
G1 X139.745 Y143.017 E1.37831
G1 X141.338 Y141.423 E.06926
G1 X141.114 Y141.114 F36000
G1 F12000
G1 X142.484 Y139.745 E.05952
G1 X111.298 Y108.559 E1.35514
G1 X108.559 Y111.298 E.11904
G1 X139.745 Y142.484 E1.35514
G1 X141.072 Y141.157 E.05768
G1 X140.848 Y140.848 F36000
G1 F12000
G1 X141.951 Y139.745 E.04793
G1 X111.298 Y109.092 E1.33197
G1 X109.092 Y111.298 E.09587
G1 X139.745 Y141.951 E1.33197
G1 X140.805 Y140.89 E.04609
G1 X140.581 Y140.581 F36000
G1 F12000
G1 X141.417 Y139.745 E.03635
G1 X111.298 Y109.625 E1.3088
G1 X109.625 Y111.298 E.07269
G1 X139.745 Y141.417 E1.3088
G1 X140.539 Y140.623 E.0345
G1 X140.884 Y139.745 F36000
G1 F12000
G1 X139.745 Y140.884 E.04952
G1 X110.158 Y111.298 E1.28563
G1 X111.298 Y110.158 E.04952
G1 X140.842 Y139.702 E1.28378
G1 X140.351 Y139.745 F36000
G1 F12000
G1 X139.745 Y140.351 E.02635
G1 X110.692 Y111.298 E1.26245
G1 X111.298 Y110.692 E.02635
G1 X140.308 Y139.702 E1.26061
G1 X111.298 Y111.298 F36000
; LINE_WIDTH: 0.52342
G1 F12000
G1 X139.702 Y139.702 E1.57282
; CHANGE_LAYER
; Z_HEIGHT: 7.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F12000
G1 X138.288 Y138.288 E-.76
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
G1 X154.616 Y152.639
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X149.224 Y158.031 E.16019
G1 X147.954 Y156.761 E.05957
G1 X156.761 Y147.954 E.41313
G1 X157.749 Y148.943 E.04638
G1 X158.031 Y149.224 E.01319
G1 X154.658 Y152.596 E.1582
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X149.224 Y158.585 E.14839
G1 X147.4 Y156.761 E.07928
G1 X156.761 Y147.4 E.40678
G1 X158.027 Y148.666 E.05501
G1 X158.585 Y149.224 E.02426
G1 X155.213 Y152.596 E.14654
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.195 Y152.506 Z7.8 F36000
G1 Z7.4
G1 E.8 F1800
; FEATURE: Floating vertical shell
; LINE_WIDTH: 0.41999
G1 F12000
G1 X154.174 Y152.531 E.001
G1 X154.195 Y152.772 E.00745
G1 X156.183 Y154.76 E.08639
G1 X154.76 Y156.183 E.06181
G1 X152.772 Y154.195 E.08639
G1 X152.506 Y154.195 E.00819
G1 X150.846 Y155.855 E.07213
; Slow Down Start
G1 F3000;_EXTRUDE_SET_SPEED
G1 X149.224 Y157.476 E.07046
G1 X148.509 Y156.761 E.03109
G1 X156.761 Y148.509 E.35858
G1 X157.476 Y149.224 E.03109
G1 X155.855 Y150.846 E.07046
; Slow Down End
G1 F12000
G1 X154.237 Y152.463 E.07029
G1 X153.886 Y152.379 F36000
; LINE_WIDTH: 0.382263
G1 F12000
G1 X153.879 Y152.677 E.00823
; LINE_WIDTH: 0.419415
G1 X153.873 Y152.974 E.00914
G1 X155.649 Y154.76 E.07728
G1 X154.76 Y155.649 E.03858
G1 X153.039 Y153.928 E.07469
; LINE_WIDTH: 0.405055
G1 X153.007 Y153.9 E.00125
; Slow Down Start
; LINE_WIDTH: 0.391672
G1 F3000;_EXTRUDE_SET_SPEED
G1 X152.974 Y153.873 E.00121
G1 X152.323 Y153.942 E.01863
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.360281
;_EXTRUDE_SET_SPEED
G1 X152.26 Y153.949 E.00163
G1 X149.224 Y156.985 E.11103
G1 X149 Y156.761 E.00821
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.375178
;_EXTRUDE_SET_SPEED
G1 X150.518 Y155.243 E.05812
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.390011
;_EXTRUDE_SET_SPEED
G3 X152.901 Y152.901 I48.018 J46.5 E.09451
G1 X153.641 Y152.123 E.03037
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.361539
;_EXTRUDE_SET_SPEED
G1 X156.761 Y149 E.11461
G1 X156.985 Y149.224 E.00824
G1 X153.949 Y152.26 E.11147
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.375185
;_EXTRUDE_SET_SPEED
G1 X153.922 Y152.291 E.00112
; Slow Down End
; Slow Down Start
; LINE_WIDTH: 0.405055
;_EXTRUDE_SET_SPEED
G1 X153.894 Y152.322 E.00122
; Slow Down End
G1 X153.534 Y152.856 F36000
; LINE_WIDTH: 0.487068
G1 F12000
G1 X152.822 Y153.568 E.03645
G1 X153.221 Y153.538 E.01448
G1 X154.76 Y155.072 E.07863
G1 X155.072 Y154.76 E.01593
G1 X153.538 Y153.221 E.07863
G1 X153.535 Y152.916 E.01103
; WIPE_START
G1 X153.538 Y153.221 E-.1158
G1 X154.735 Y154.422 E-.6442
; WIPE_END
G1 E-.04 F1800
G1 X149.547 Y148.824 Z7.8 F36000
G1 X111.004 Y107.231 Z7.8
G1 Z7.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F15476.087
G1 X117.31 Y113.537 E.29582
G1 X143.811 Y140.038 E1.24321
G1 X140.038 Y143.811 E.177
G1 X107.231 Y111.004 E1.53904
G1 X110.962 Y107.274 E.17501
G1 X111.004 Y106.677 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X117.588 Y113.26 E.28607
G1 X144.366 Y140.038 E1.16364
G1 X140.038 Y144.366 E.18805
G1 X106.677 Y111.004 E1.44971
G1 X110.962 Y106.719 E.18621
; WIPE_START
M204 S10000
G1 X112.385 Y108.124 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X111.004 Y111.004 Z7.8 F36000
G1 Z7.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.44692
G1 F15000
G1 X139.996 Y139.996 E1.34975
G1 X140.314 Y140.314 F36000
; LINE_WIDTH: 0.41999
G1 F15000
G1 X140.591 Y140.038 E.012
G1 X111.004 Y110.452 E1.28563
G1 X110.452 Y111.004 E.024
G1 X140.038 Y140.591 E1.28563
G1 X140.272 Y140.357 E.01016
G1 X140.581 Y140.581 F36000
G1 F15000
G1 X141.124 Y140.038 E.02359
G1 X111.004 Y109.919 E1.3088
G1 X109.919 Y111.004 E.04717
G1 X140.038 Y141.124 E1.3088
G1 X140.539 Y140.623 E.02174
G1 X140.848 Y140.848 F36000
G1 F15000
G1 X141.657 Y140.038 E.03517
G1 X111.004 Y109.386 E1.33197
G1 X109.386 Y111.004 E.07034
G1 X140.038 Y141.657 E1.33197
G1 X140.805 Y140.89 E.03333
G1 X141.114 Y141.114 F36000
G1 F15000
G1 X142.19 Y140.038 E.04676
G1 X111.004 Y108.852 E1.35514
G1 X108.852 Y111.004 E.09352
G1 X140.038 Y142.19 E1.35514
G1 X141.072 Y141.157 E.04491
G1 X141.381 Y141.381 F36000
G1 F15000
G1 X142.724 Y140.038 E.05834
G1 X111.004 Y108.319 E1.37831
G1 X108.319 Y111.004 E.11669
G1 X140.038 Y142.724 E1.37831
G1 X141.338 Y141.423 E.0565
G1 X141.648 Y141.648 F36000
G1 F15000
G1 X143.257 Y140.038 E.06993
G1 X111.004 Y107.786 E1.40149
G1 X107.786 Y111.004 E.13986
G1 X140.038 Y143.257 E1.40149
G1 X141.605 Y141.69 E.06809
; CHANGE_LAYER
; Z_HEIGHT: 7.6
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X140.191 Y143.104 E-.76
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
M73 P93 R1
G1 X154.616 Y152.639
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F13765
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X149.378 Y157.877 E.15296
G1 X148.108 Y156.607 E.05957
G1 X156.607 Y148.108 E.39867
G1 X157.876 Y149.378 E.05957
G1 X154.658 Y152.596 E.15097
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X149.378 Y158.431 E.14169
G1 X147.554 Y156.607 E.07928
G1 X156.607 Y147.554 E.39339
G1 X156.774 Y147.721 E.00727
G1 X158.431 Y149.378 E.072
G1 X155.213 Y152.596 E.13985
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.607 Y148.663 Z8 F36000
G1 Z7.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F13765
G1 X148.663 Y156.607 E.34519
G1 X149.378 Y157.322 E.03109
G1 X152.506 Y154.195 E.13589
G1 X152.772 Y154.195 E.00819
G1 X154.76 Y156.183 E.08639
G1 X156.183 Y154.76 E.06181
G1 X154.195 Y152.772 E.08639
G1 X154.174 Y152.531 E.00745
G1 X157.322 Y149.378 E.1369
G1 X156.649 Y148.705 E.02924
G1 X153.641 Y152.123 F36000
; LINE_WIDTH: 0.379138
G1 F13765
G1 X153.271 Y152.512 E.01471
; LINE_WIDTH: 0.39516
G3 X152.036 Y153.725 I-12.637 J-11.641 E.04971
; LINE_WIDTH: 0.360245
G1 X149.154 Y156.607 E.10538
G1 X149.378 Y156.831 E.00821
G1 X152.26 Y153.949 E.10538
; LINE_WIDTH: 0.375185
G1 X152.617 Y153.911 E.00973
; LINE_WIDTH: 0.419184
G1 X152.974 Y153.873 E.01101
G1 X154.76 Y155.649 E.07724
G1 X155.649 Y154.76 E.03856
G1 X153.873 Y152.974 E.07724
; LINE_WIDTH: 0.406373
G1 X153.88 Y152.652 E.00955
; LINE_WIDTH: 0.360977
G1 X153.887 Y152.33 E.00836
G1 X153.949 Y152.26 E.00242
G1 X156.831 Y149.378 E.10563
G1 X156.607 Y149.154 E.00822
G1 X153.683 Y152.08 E.10721
G1 X153.534 Y152.856 F36000
; LINE_WIDTH: 0.487068
G1 F13765
G1 X152.822 Y153.568 E.03645
G1 X153.221 Y153.538 E.01448
G1 X154.76 Y155.072 E.07863
G1 X155.072 Y154.76 E.01593
G1 X153.538 Y153.221 E.07863
G1 X153.535 Y152.916 E.01103
; WIPE_START
G1 F14184.483
G1 X153.538 Y153.221 E-.11581
G1 X154.735 Y154.422 E-.64419
; WIPE_END
G1 E-.04 F1800
G1 X149.505 Y148.863 Z8 F36000
G1 X110.659 Y107.576 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F13765
G1 X143.466 Y140.383 E1.53904
G1 X140.383 Y143.466 E.14463
G1 X107.576 Y110.659 E1.53904
G1 X110.617 Y107.619 E.14264
G1 X110.659 Y107.022 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X110.782 Y107.144 E.00532
G1 X144.021 Y140.383 E1.44439
G1 X140.383 Y144.021 E.15806
G1 X107.022 Y110.659 E1.44971
G1 X110.617 Y107.064 E.15622
; WIPE_START
M204 S10000
G1 X110.782 Y107.144 E-.06967
G1 X112.066 Y108.429 E-.69033
; WIPE_END
G1 E-.04 F1800
G1 X117.13 Y114.14 Z8 F36000
G1 X140.549 Y140.549 Z8
G1 Z7.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.5111
G1 F13456.363
G1 X140.714 Y140.383 E.00893
G1 X110.659 Y110.328 E1.62156
G1 X110.328 Y110.659 E.01786
G1 X140.383 Y140.714 E1.62156
G1 X140.506 Y140.591 E.00664
G1 X140.848 Y140.848 F36000
; LINE_WIDTH: 0.41999
G1 F13765
G1 X141.312 Y140.383 E.02018
G1 X110.659 Y109.731 E1.33197
G1 X109.731 Y110.659 E.04036
G1 X140.383 Y141.312 E1.33197
G1 X140.805 Y140.89 E.01834
G1 X141.114 Y141.114 F36000
G1 F13765
G1 X141.845 Y140.383 E.03176
G1 X110.659 Y109.197 E1.35514
G1 X109.197 Y110.659 E.06353
G1 X140.383 Y141.845 E1.35514
G1 X141.072 Y141.157 E.02992
G1 X141.381 Y141.381 F36000
G1 F13765
G1 X142.379 Y140.383 E.04335
G1 X110.659 Y108.664 E1.37831
G1 X108.664 Y110.659 E.0867
G1 X140.383 Y142.379 E1.37831
G1 X141.338 Y141.423 E.04151
G1 X141.647 Y141.648 F36000
G1 F13765
G1 X142.912 Y140.383 E.05494
G1 X110.659 Y108.131 E1.40149
G1 X108.131 Y110.659 E.10987
G1 X140.383 Y142.912 E1.40149
G1 X141.605 Y141.69 E.05309
; CHANGE_LAYER
; Z_HEIGHT: 7.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X140.383 Y142.912 E-.65662
G1 X140.191 Y142.719 E-.10339
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
G1 X154.616 Y152.639
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F14905
G1 X156.737 Y154.76 E.09952
G1 X154.76 Y156.737 E.09274
G1 X152.639 Y154.616 E.09952
G1 X149.546 Y157.709 E.1451
G1 X148.276 Y156.439 E.05957
G1 X156.439 Y148.276 E.38295
G1 X157.299 Y149.135 E.04032
G1 X157.709 Y149.546 E.01925
G1 X154.658 Y152.596 E.14311
G1 X155.17 Y152.639 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X149.546 Y158.263 E.13441
G1 X147.721 Y156.439 E.07928
G1 X156.439 Y147.721 E.37883
G1 X157.576 Y148.858 E.04939
G1 X158.263 Y149.546 E.02988
G1 X155.213 Y152.596 E.13257
; WIPE_START
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.439 Y148.83 Z8.2 F36000
G1 Z7.8
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F14905
G1 X148.83 Y156.439 E.33063
G1 X149.546 Y157.155 E.03109
G1 X152.506 Y154.195 E.12862
G1 X152.772 Y154.195 E.00819
G1 X154.76 Y156.183 E.08639
G1 X156.183 Y154.76 E.06181
G1 X154.195 Y152.772 E.08639
G1 X154.174 Y152.531 E.00745
G1 X157.155 Y149.546 E.12962
G1 X156.482 Y148.873 E.02924
G1 X153.641 Y152.123 F36000
; LINE_WIDTH: 0.379138
G1 F14905
G1 X153.271 Y152.512 E.01471
; LINE_WIDTH: 0.39516
G3 X152.036 Y153.725 I-12.646 J-11.65 E.04971
; LINE_WIDTH: 0.360245
G1 X149.321 Y156.439 E.09926
G1 X149.546 Y156.663 E.00821
G1 X152.26 Y153.949 E.09926
; LINE_WIDTH: 0.375185
G1 X152.617 Y153.911 E.00973
; LINE_WIDTH: 0.419184
G1 X152.974 Y153.873 E.01101
G1 X154.76 Y155.649 E.07724
G1 X155.649 Y154.76 E.03856
G1 X153.873 Y152.974 E.07724
; LINE_WIDTH: 0.406373
G1 X153.88 Y152.652 E.00955
; LINE_WIDTH: 0.361022
G1 X153.887 Y152.33 E.00836
G1 X153.949 Y152.26 E.00242
G1 X156.663 Y149.546 E.0995
G1 X156.439 Y149.321 E.00823
G1 X153.683 Y152.08 E.10108
G1 X153.534 Y152.856 F36000
; LINE_WIDTH: 0.48707
G1 F14184.406
G1 X152.822 Y153.568 E.03645
G1 X153.221 Y153.538 E.01448
G1 X154.76 Y155.072 E.07863
G1 X155.072 Y154.76 E.01593
G1 X153.538 Y153.221 E.07863
G1 X153.535 Y152.916 E.01103
; WIPE_START
G1 X153.538 Y153.221 E-.1158
G1 X154.735 Y154.422 E-.6442
; WIPE_END
G1 E-.04 F1800
G1 X149.334 Y149.029 Z8.2 F36000
G1 X109.245 Y108.991 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F14905
G1 X142.052 Y141.798 E1.53904
G1 X141.798 Y142.052 E.01189
G1 X108.991 Y109.245 E1.53904
G1 X109.202 Y109.034 E.0099
; WIPE_START
G1 F15476.087
G1 X110.618 Y110.446 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X110.219 Y107.462 Z8.2 F36000
G1 Z7.8
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F12000
M204 S6000
G1 X143.58 Y140.824 E1.44971
G1 X140.824 Y143.58 E.11979
G1 X107.462 Y110.219 E1.44971
G1 X110.177 Y107.505 E.11795
M204 S10000
G1 X109.92 Y108.054 F36000
; FEATURE: Top surface
G1 F12000
M204 S2000
G1 X142.988 Y141.122 E1.43697
G1 X142.722 Y141.389
G1 X109.654 Y108.321 E1.43697
M204 S10000
G1 X142.471 Y141.667 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.413989
G1 F14905
G1 X109.376 Y108.572 E1.4152
; WIPE_START
G1 F15000
G1 X110.79 Y109.986 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X116.314 Y115.253 Z8.2 F36000
G1 X143.224 Y140.913 Z8.2
G1 Z7.8
G1 E.8 F1800
; LINE_WIDTH: 0.295357
G1 F14905
G1 X110.13 Y107.818 E.96276
; WIPE_START
G1 F15000
G1 X111.544 Y109.232 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X108.321 Y109.654 Z8.2 F36000
G1 Z7.8
M73 P94 R1
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F12000
M204 S2000
G1 X141.389 Y142.722 E1.43697
G1 X141.122 Y142.989
G1 X108.054 Y109.921 E1.43697
; WIPE_START
M204 S10000
G1 X109.468 Y111.335 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X114.827 Y116.77 Z8.2 F36000
G1 X140.913 Y143.225 Z8.2
G1 Z7.8
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.295258
G1 F14905
G1 X107.818 Y110.13 E.96238
; WIPE_START
G1 F15000
G1 X109.232 Y111.544 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X114.756 Y116.811 Z8.2 F36000
G1 X141.667 Y142.471 Z8.2
G1 Z7.8
G1 E.8 F1800
; LINE_WIDTH: 0.414081
G1 F14905
G1 X108.572 Y109.376 E1.41555
; CHANGE_LAYER
; Z_HEIGHT: 8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X109.986 Y110.79 E-.76
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
G1 X153.943 Y152.639
G1 Z8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F9814
G1 X150.945 Y155.637 E.14065
G1 X151.281 Y155.973 E.01578
G1 X149.719 Y157.536 E.0733
G1 X148.449 Y156.266 E.05957
G1 X156.266 Y148.449 E.36673
G1 X157.536 Y149.719 E.05957
G1 X155.973 Y151.281 E.0733
G1 X155.637 Y150.945 E.01578
G1 X153.986 Y152.596 E.07748
; WIPE_START
G1 F15476.087
G1 X152.571 Y154.011 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.17 Y152.639 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F9814
M204 S6000
G1 X157.292 Y154.76 E.09218
G1 X154.76 Y157.292 E.11
G1 X152.639 Y155.17 E.09218
G1 X149.719 Y158.091 E.1269
G1 X147.894 Y156.266 E.07928
G1 X156.266 Y147.894 E.36379
G1 X158.09 Y149.719 E.07928
G1 X155.213 Y152.596 E.12505
; WIPE_START
G1 F12000
M204 S10000
G1 X156.598 Y154.039 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.525 Y150.235 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.360245
G1 F9814
G1 X155.877 Y150.178 E.00922
G1 X155.967 Y150.243 E.00285
G1 X156.491 Y149.719 E.01916
G1 X156.266 Y149.494 E.00821
G1 X155.568 Y150.193 E.02554
G1 X150.173 Y155.153 F36000
; LINE_WIDTH: 0.479593
G1 F9814
G1 X149.926 Y155.372 E.01175
; LINE_WIDTH: 0.421602
G2 X149.003 Y156.266 I6.959 J8.1 E.03967
G1 X149.719 Y156.982 E.03122
G1 X150.727 Y155.973 E.04399
G1 X150.489 Y155.722 E.0107
; LINE_WIDTH: 0.440725
G1 X150.479 Y155.613 E.00353
; LINE_WIDTH: 0.499204
G1 X150.469 Y155.505 E.00404
G1 X150.496 Y155.476 E.00148
G1 X155.476 Y150.496 E.26186
; LINE_WIDTH: 0.479585
G1 X155.599 Y150.492 E.00438
; LINE_WIDTH: 0.420623
G1 X155.722 Y150.489 E.00379
G1 X155.973 Y150.727 E.01067
G1 X156.982 Y149.719 E.04388
G1 X156.266 Y149.003 E.03114
G1 X155.591 Y149.679 E.0294
; LINE_WIDTH: 0.439855
G1 X155.372 Y149.926 E.01068
; LINE_WIDTH: 0.498558
G1 X155.153 Y150.173 E.01226
G1 X150.215 Y155.11 E.25926
G1 X150.202 Y155.559 F36000
; LINE_WIDTH: 0.36025
G1 F9814
G1 X149.494 Y156.266 E.02587
G1 X149.719 Y156.491 E.00821
G1 X150.243 Y155.967 E.01916
G1 X150.178 Y155.877 E.00285
G1 X150.197 Y155.619 E.00671
; WIPE_START
G1 F15000
G1 X150.178 Y155.877 E-.09856
G1 X150.243 Y155.967 E-.04184
G1 X149.719 Y156.491 E-.28157
G1 X149.494 Y156.266 E-.12059
G1 X149.899 Y155.862 E-.21745
; WIPE_END
G1 E-.04 F1800
G1 X151.591 Y155.587 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.50812
G1 F9814
G2 X151.589 Y155.687 I-.029 J.05 E.0091
; WIPE_START
G1 F13542.563
G1 X151.533 Y155.687 E-.18544
G1 X151.504 Y155.637 E-.19152
G1 X151.533 Y155.587 E-.19154
G1 X151.591 Y155.587 E-.1915
; WIPE_END
G1 E-.04 F1800
G1 X154.473 Y156.711 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F9814
M204 S2000
G1 X156.711 Y154.473 E.09726
G1 X156.445 Y154.207
G1 X154.207 Y156.445 E.09726
G1 X153.94 Y156.178
G1 X156.178 Y153.94 E.09726
G1 X155.911 Y153.673
G1 X153.673 Y155.911 E.09726
G1 X153.407 Y155.645
G1 X155.645 Y153.407 E.09726
G1 X155.378 Y153.14
G1 X153.14 Y155.378 E.09726
G1 X152.873 Y155.112
G1 X155.112 Y152.873 E.09726
G1 X155.588 Y151.864
G1 X151.847 Y155.604 E.16255
; WIPE_START
G1 F12000
M204 S10000
G1 X153.261 Y154.19 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X156.942 Y154.677 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.279059
G1 F9814
G1 X154.677 Y156.942 E.06163
; WIPE_START
G1 F15000
G1 X156.091 Y155.527 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.223 Y151.657 Z8.4 F36000
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.215075
G1 F9814
G1 X155.236 Y151.718 E.00087
; LINE_WIDTH: 0.265398
G1 X155.249 Y151.779 E.00113
G1 X151.681 Y155.346 E.09147
; WIPE_START
G1 F15000
G1 X153.096 Y153.932 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X147.84 Y148.397 Z8.4 F36000
G1 X109.581 Y108.1 Z8.4
G1 Z8
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F9814
M204 S6000
G1 X142.942 Y141.462 E1.44971
G1 X141.462 Y142.942 E.06435
G1 X108.1 Y109.581 E1.44971
G1 X109.539 Y108.143 E.0625
; WIPE_START
G1 F12000
M204 S10000
G1 X110.955 Y109.555 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X116.333 Y114.97 Z8.4 F36000
G1 X142.321 Y141.134 Z8.4
G1 Z8
G1 E.8 F1800
; FEATURE: Top surface
G1 F9814
M204 S2000
G1 X141.134 Y142.321 E.0516
G1 X140.867 Y142.055
G1 X142.055 Y140.867 E.0516
G1 X141.788 Y140.601
G1 X140.601 Y141.788 E.0516
G1 X140.334 Y141.521
G1 X141.521 Y140.334 E.0516
G1 X141.255 Y140.067
G1 X140.067 Y141.255 E.0516
G1 X139.801 Y140.988
G1 X140.988 Y139.801 E.0516
G1 X140.722 Y139.534
G1 X139.534 Y140.722 E.0516
G1 X139.267 Y140.455
G1 X140.455 Y139.267 E.0516
G1 X140.188 Y139.001
G1 X139.001 Y140.188 E.0516
G1 X138.734 Y139.922
M73 P94 R0
G1 X139.922 Y138.734 E.0516
G1 X139.655 Y138.468
G1 X138.468 Y139.655 E.0516
G1 X138.201 Y139.388
G1 X139.388 Y138.201 E.0516
G1 X139.122 Y137.934
G1 X137.934 Y139.122 E.0516
G1 X137.668 Y138.855
G1 X138.855 Y137.668 E.0516
G1 X138.588 Y137.401
G1 X137.401 Y138.588 E.0516
G1 X137.134 Y138.322
G1 X138.322 Y137.134 E.0516
G1 X138.055 Y136.868
G1 X136.868 Y138.055 E.0516
G1 X136.601 Y137.789
G1 X137.789 Y136.601 E.0516
G1 X137.522 Y136.335
G1 X136.334 Y137.522 E.0516
G1 X136.068 Y137.255
G1 X137.255 Y136.068 E.0516
G1 X136.989 Y135.801
G1 X135.801 Y136.989 E.0516
G1 X135.535 Y136.722
G1 X136.722 Y135.535 E.0516
G1 X136.455 Y135.268
G1 X135.268 Y136.455 E.0516
G1 X135.001 Y136.189
G1 X136.189 Y135.001 E.0516
G1 X135.922 Y134.735
G1 X134.735 Y135.922 E.0516
G1 X134.468 Y135.656
G1 X135.656 Y134.468 E.0516
G1 X135.389 Y134.201
G1 X134.201 Y135.389 E.0516
G1 X133.935 Y135.122
G1 X135.122 Y133.935 E.0516
G1 X134.856 Y133.668
G1 X133.668 Y134.856 E.0516
G1 X133.402 Y134.589
G1 X134.589 Y133.402 E.0516
G1 X134.322 Y133.135
G1 X133.135 Y134.322 E.0516
G1 X132.868 Y134.056
G1 X134.056 Y132.868 E.0516
G1 X133.789 Y132.602
G1 X132.602 Y133.789 E.0516
G1 X132.335 Y133.523
G1 X133.523 Y132.335 E.0516
G1 X133.256 Y132.068
G1 X132.068 Y133.256 E.0516
G1 X131.802 Y132.989
G1 X132.989 Y131.802 E.0516
G1 X132.723 Y131.535
G1 X131.535 Y132.723 E.0516
G1 X131.269 Y132.456
G1 X132.456 Y131.269 E.0516
G1 X132.189 Y131.002
G1 X131.002 Y132.189 E.0516
G1 X130.735 Y131.923
G1 X131.923 Y130.735 E.0516
G1 X131.656 Y130.469
G1 X130.469 Y131.656 E.0516
G1 X130.202 Y131.39
G1 X131.39 Y130.202 E.0516
G1 X131.123 Y129.935
G1 X129.935 Y131.123 E.0516
G1 X129.669 Y130.856
G1 X130.856 Y129.669 E.0516
G1 X130.59 Y129.402
G1 X129.402 Y130.59 E.0516
G1 X129.136 Y130.323
G1 X130.323 Y129.136 E.0516
G1 X130.056 Y128.869
G1 X128.869 Y130.056 E.0516
G1 X128.602 Y129.79
G1 X129.79 Y128.602 E.0516
G1 X129.523 Y128.336
G1 X128.336 Y129.523 E.0516
G1 X128.069 Y129.256
G1 X129.256 Y128.069 E.0516
G1 X128.99 Y127.802
G1 X127.802 Y128.99 E.0516
G1 X127.536 Y128.723
G1 X128.723 Y127.536 E.0516
G1 X128.457 Y127.269
G1 X127.269 Y128.457 E.0516
G1 X127.002 Y128.19
G1 X128.19 Y127.002 E.0516
G1 X127.923 Y126.736
G1 X126.736 Y127.923 E.0516
G1 X126.469 Y127.657
G1 X127.657 Y126.469 E.0516
G1 X127.39 Y126.203
G1 X126.203 Y127.39 E.0516
G1 X125.936 Y127.123
G1 X127.123 Y125.936 E.0516
G1 X126.857 Y125.669
G1 X125.669 Y126.857 E.0516
G1 X125.403 Y126.59
G1 X126.59 Y125.403 E.0516
G1 X126.324 Y125.136
G1 X125.136 Y126.324 E.0516
G1 X124.869 Y126.057
G1 X126.057 Y124.869 E.0516
G1 X125.79 Y124.603
G1 X124.603 Y125.79 E.0516
G1 X124.336 Y125.524
G1 X125.524 Y124.336 E.0516
G1 X125.257 Y124.07
G1 X124.07 Y125.257 E.0516
M73 P95 R0
G1 X123.803 Y124.99
G1 X124.99 Y123.803 E.0516
G1 X124.724 Y123.536
G1 X123.536 Y124.724 E.0516
G1 X123.27 Y124.457
G1 X124.457 Y123.27 E.0516
G1 X124.191 Y123.003
G1 X123.003 Y124.191 E.0516
G1 X122.736 Y123.924
G1 X123.924 Y122.736 E.0516
G1 X123.657 Y122.47
G1 X122.47 Y123.657 E.0516
G1 X122.203 Y123.391
G1 X123.391 Y122.203 E.0516
G1 X123.124 Y121.937
G1 X121.937 Y123.124 E.0516
G1 X121.67 Y122.857
G1 X122.857 Y121.67 E.0516
G1 X122.591 Y121.403
G1 X121.403 Y122.591 E.0516
G1 X121.137 Y122.324
G1 X122.324 Y121.137 E.0516
G1 X122.057 Y120.87
G1 X120.87 Y122.058 E.0516
G1 X120.603 Y121.791
G1 X121.791 Y120.603 E.0516
G1 X121.524 Y120.337
G1 X120.337 Y121.524 E.0516
G1 X120.07 Y121.258
G1 X121.258 Y120.07 E.0516
G1 X120.991 Y119.804
G1 X119.804 Y120.991 E.0516
G1 X119.537 Y120.724
G1 X120.724 Y119.537 E.0516
G1 X120.458 Y119.27
G1 X119.27 Y120.458 E.0516
G1 X119.004 Y120.191
G1 X120.191 Y119.004 E.0516
G1 X119.924 Y118.737
G1 X118.737 Y119.924 E.0516
G1 X118.47 Y119.658
G1 X119.658 Y118.47 E.0516
G1 X119.391 Y118.204
G1 X118.204 Y119.391 E.0516
G1 X117.937 Y119.125
G1 X119.125 Y117.937 E.0516
G1 X118.858 Y117.67
G1 X117.67 Y118.858 E.0516
G1 X117.404 Y118.591
G1 X118.591 Y117.404 E.0516
G1 X118.325 Y117.137
G1 X117.137 Y118.325 E.0516
G1 X116.871 Y118.058
G1 X118.058 Y116.871 E.0516
G1 X117.791 Y116.604
G1 X116.604 Y117.791 E.0516
G1 X116.337 Y117.525
G1 X117.525 Y116.337 E.0516
G1 X117.258 Y116.071
G1 X116.071 Y117.258 E.0516
G1 X115.804 Y116.992
G1 X116.992 Y115.804 E.0516
G1 X116.725 Y115.537
G1 X115.537 Y116.725 E.0516
G1 X115.271 Y116.458
G1 X116.458 Y115.271 E.0516
G1 X116.192 Y115.004
G1 X115.004 Y116.192 E.0516
G1 X114.738 Y115.925
G1 X115.925 Y114.738 E.0516
G1 X115.658 Y114.471
G1 X114.471 Y115.658 E.0516
G1 X114.204 Y115.392
G1 X115.392 Y114.204 E.0516
G1 X115.125 Y113.938
G1 X113.938 Y115.125 E.0516
G1 X113.671 Y114.859
G1 X114.859 Y113.671 E.0516
G1 X114.592 Y113.404
G1 X113.404 Y114.592 E.0516
G1 X113.138 Y114.325
G1 X114.325 Y113.138 E.0516
G1 X114.059 Y112.871
G1 X112.871 Y114.059 E.0516
G1 X112.605 Y113.792
G1 X113.792 Y112.605 E.0516
G1 X113.525 Y112.338
G1 X112.338 Y113.525 E.0516
G1 X112.071 Y113.259
G1 X113.259 Y112.071 E.0516
G1 X112.992 Y111.805
G1 X111.805 Y112.992 E.0516
G1 X111.538 Y112.725
G1 X112.725 Y111.538 E.0516
G1 X112.459 Y111.271
G1 X111.271 Y112.459 E.0516
G1 X111.005 Y112.192
G1 X112.192 Y111.005 E.0516
G1 X111.926 Y110.738
G1 X110.738 Y111.926 E.0516
G1 X110.472 Y111.659
G1 X111.659 Y110.472 E.0516
G1 X111.392 Y110.205
G1 X110.205 Y111.392 E.0516
G1 X109.938 Y111.126
G1 X111.126 Y109.938 E.0516
G1 X110.859 Y109.672
G1 X109.672 Y110.859 E.0516
G1 X109.405 Y110.592
G1 X110.592 Y109.405 E.0516
G1 X110.326 Y109.138
G1 X109.138 Y110.326 E.0516
G1 X108.872 Y110.059
G1 X110.059 Y108.872 E.0516
G1 X109.793 Y108.605
G1 X108.605 Y109.793 E.0516
; WIPE_START
G1 F12000
M204 S10000
G1 X109.793 Y108.605 E-.63814
G1 X110.019 Y108.832 E-.12186
; WIPE_END
G1 E-.04 F1800
G1 X115.418 Y114.227 Z8.4 F36000
G1 X142.572 Y141.358 Z8.4
G1 Z8
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.336681
G1 F9814
G1 X141.358 Y142.572 E.0411
; WIPE_START
G1 F15000
G1 X142.572 Y141.358 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X137.175 Y135.961 Z8.4 F36000
G1 X109.627 Y108.413 Z8.4
G1 Z8
G1 E.8 F1800
; LINE_WIDTH: 0.17225
G1 F9814
G1 X108.413 Y109.627 E.0181
; CHANGE_LAYER
; Z_HEIGHT: 8.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X109.627 Y108.413 E-.76
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
G1 X148.641 Y156.074
G1 Z8.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1484
G1 X156.074 Y148.641 E.34866
G1 X156.626 Y149.193 E.02589
G1 X157.343 Y149.911 E.03368
G1 X149.911 Y157.343 E.34866
G1 X148.684 Y156.116 E.05758
G1 X148.087 Y156.074 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1484
M204 S6000
G1 X156.074 Y148.087 E.34706
G1 X156.903 Y148.916 E.03603
G1 X157.898 Y149.911 E.04324
G1 X149.911 Y157.898 E.34706
G1 X148.129 Y156.116 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X149.536 Y154.694 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X149.196 Y156.074 Z8.6 F36000
G1 Z8.2
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1484
G1 X149.911 Y156.789 E.03109
G1 X156.789 Y149.911 E.29886
G1 X156.074 Y149.196 E.03109
G1 X149.238 Y156.031 E.29702
G1 X149.687 Y156.074 F36000
; LINE_WIDTH: 0.36025
G1 F1484
G1 X149.911 Y156.298 E.00821
G1 X156.298 Y149.911 E.23356
G1 X156.074 Y149.687 E.00821
G1 X149.729 Y156.031 E.232
; CHANGE_LAYER
; Z_HEIGHT: 8.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X151.144 Y154.617 E-.76
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
G1 X148.842 Y155.873
G1 Z8.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1378
G1 X155.873 Y148.842 E.32985
G1 X157.143 Y150.112 E.05957
G1 X150.112 Y157.143 E.32985
G1 X148.884 Y155.916 E.05758
G1 X148.287 Y155.873 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1378
M204 S6000
G1 X155.873 Y148.287 E.32964
G1 X157.535 Y149.949 E.07221
G1 X157.697 Y150.112 E.00707
G1 X150.112 Y157.698 E.32964
G1 X148.33 Y155.916 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X149.736 Y154.493 E-.76
; WIPE_END
M73 P96 R0
G1 E-.04 F1800
G1 X155.607 Y149.617 Z8.8 F36000
G1 X155.873 Y149.396 Z8.8
G1 Z8.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1378
G1 X149.396 Y155.873 E.28144
G1 X150.112 Y156.589 E.03109
G1 X156.589 Y150.112 E.28144
G1 X155.916 Y149.439 E.02924
G1 X155.873 Y149.887 F36000
; LINE_WIDTH: 0.360245
G1 F1378
G1 X149.887 Y155.873 E.2189
G1 X150.112 Y156.098 E.00821
G1 X156.098 Y150.112 E.2189
G1 X155.916 Y149.93 E.00665
; CHANGE_LAYER
; Z_HEIGHT: 8.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X156.098 Y150.112 E-.09779
G1 X154.865 Y151.344 E-.66221
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
G1 X149.062 Y155.653
G1 Z8.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1303
G1 X155.653 Y149.062 E.30921
G1 X156.923 Y150.332 E.05957
G1 X150.332 Y156.923 E.30921
G1 X149.104 Y155.696 E.05758
G1 X148.507 Y155.653 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1303
M204 S6000
G1 X155.653 Y148.507 E.31051
G1 X155.941 Y148.795 E.0125
G1 X157.477 Y150.332 E.06677
G1 X150.332 Y157.477 E.31052
G1 X148.55 Y155.696 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X149.956 Y154.273 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X149.616 Y155.653 Z9 F36000
G1 Z8.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1303
G1 X150.332 Y156.369 E.03109
G1 X156.369 Y150.332 E.26232
G1 X155.653 Y149.616 E.03109
G1 X149.659 Y155.611 E.26048
G1 X150.107 Y155.653 F36000
; LINE_WIDTH: 0.36025
G1 F1303
G1 X150.332 Y155.878 E.00821
G1 X155.877 Y150.332 E.2028
G1 X155.653 Y150.107 E.00821
G1 X150.15 Y155.611 E.20125
; CHANGE_LAYER
; Z_HEIGHT: 8.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X151.564 Y154.196 E-.76
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
G1 X149.303 Y155.412
G1 Z8.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1217
G1 X155.412 Y149.303 E.28662
G1 X156.077 Y149.967 E.03117
G1 X156.682 Y150.573 E.0284
G1 X150.573 Y156.682 E.28662
G1 X149.345 Y155.455 E.05758
G1 X148.748 Y155.412 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1217
M204 S6000
G1 X155.412 Y148.748 E.28959
G1 X156.354 Y149.69 E.04092
G1 X157.237 Y150.573 E.03835
G1 X150.573 Y157.237 E.28959
G1 X148.791 Y155.455 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X150.196 Y154.032 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X149.857 Y155.412 Z9.2 F36000
G1 Z8.8
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1217
G1 X150.573 Y156.128 E.03109
G1 X156.128 Y150.573 E.24139
G1 X155.412 Y149.857 E.03109
G1 X149.9 Y155.37 E.23955
G1 X150.348 Y155.412 F36000
; LINE_WIDTH: 0.36025
G1 F1217
G1 X150.573 Y155.637 E.00821
G1 X155.637 Y150.573 E.18519
G1 X155.412 Y150.348 E.00821
G1 X150.391 Y155.37 E.18364
; CHANGE_LAYER
; Z_HEIGHT: 9
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X151.805 Y153.956 E-.76
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
G1 X149.563 Y155.152
G1 Z9
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1200
G1 X155.152 Y149.563 E.26215
M73 P97 R0
G1 X156.421 Y150.833 E.05957
G1 X150.833 Y156.421 E.26215
G1 X149.606 Y155.194 E.05758
G1 X149.009 Y155.152 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1200
M204 S6000
G1 X155.152 Y149.009 E.26692
G1 X156.976 Y150.833 E.07928
G1 X150.833 Y156.976 E.26692
G1 X149.051 Y155.194 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X150.456 Y153.77 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.152 Y150.118 Z9.4 F36000
G1 Z9
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1200
G1 X150.118 Y155.152 E.21873
G1 X150.833 Y155.867 E.03109
G1 X155.867 Y150.833 E.21873
G1 X155.194 Y150.16 E.02924
G1 X155.152 Y150.609 F36000
; LINE_WIDTH: 0.360245
G1 F1200
G1 X150.609 Y155.152 E.16612
G1 X150.833 Y155.376 E.00821
G1 X155.376 Y150.833 E.16612
G1 X155.194 Y150.651 E.00665
; CHANGE_LAYER
; Z_HEIGHT: 9.2
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X155.376 Y150.833 E-.09779
G1 X154.144 Y152.066 E-.66221
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
G1 X149.852 Y154.863
G1 Z9.2
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1200
G1 X154.863 Y149.852 E.23508
G1 X156.133 Y151.122 E.05957
G1 X151.122 Y156.133 E.23508
G1 X149.894 Y154.905 E.05758
G1 X149.297 Y154.863 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1200
M204 S6000
G1 X154.863 Y149.297 E.24185
G1 X156.687 Y151.122 E.07928
G1 X151.122 Y156.687 E.24185
G1 X149.34 Y154.905 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X150.743 Y153.481 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X150.406 Y154.863 Z9.6 F36000
G1 Z9.2
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1200
G1 X151.122 Y155.578 E.03109
G1 X155.578 Y151.122 E.19366
G1 X154.863 Y150.406 E.03109
G1 X150.449 Y154.821 E.19181
G1 X154.863 Y150.897 F36000
; LINE_WIDTH: 0.360245
G1 F1200
G1 X150.897 Y154.863 E.14502
G1 X151.122 Y155.087 E.00821
G1 X155.087 Y151.122 E.14502
G1 X154.905 Y150.94 E.00665
; CHANGE_LAYER
; Z_HEIGHT: 9.4
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X155.087 Y151.122 E-.09779
G1 X153.855 Y152.354 E-.66221
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
G1 X150.187 Y154.528
G1 Z9.4
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1200
G1 X154.528 Y150.187 E.20368
G1 X155.798 Y151.456 E.05957
G1 X151.456 Y155.798 E.20368
G1 X150.229 Y154.571 E.05758
G1 X149.632 Y154.528 F36000
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1200
M204 S6000
G1 X154.528 Y149.632 E.21277
G1 X156.353 Y151.456 E.07928
G1 X151.456 Y156.353 E.21277
G1 X149.675 Y154.571 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X151.076 Y153.144 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X150.741 Y154.528 Z9.8 F36000
G1 Z9.4
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1200
G1 X151.456 Y155.244 E.03109
G1 X155.244 Y151.456 E.16457
G1 X154.528 Y150.741 E.03109
G1 X150.783 Y154.486 E.16273
G1 X151.232 Y154.528 F36000
; LINE_WIDTH: 0.36025
G1 F1200
G1 X151.456 Y154.753 E.00821
G1 X154.753 Y151.456 E.12054
G1 X154.528 Y151.232 E.00821
G1 X151.274 Y154.486 E.11899
; CHANGE_LAYER
; Z_HEIGHT: 9.6
; LAYER_HEIGHT: 0.200001
; WIPE_START
G1 F15000
G1 X152.689 Y153.072 E-.76
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
G1 X151.409 Y153.306
M73 P98 R0
G1 Z9.6
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1200
G1 X153.306 Y151.409 E.08901
G1 X154.576 Y152.679 E.05957
G1 X152.679 Y154.576 E.08901
G1 X151.451 Y153.349 E.05758
; WIPE_START
G1 F15476.087
G1 X152.833 Y151.903 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X150.023 Y154.138 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1200
M204 S6000
G1 X154.138 Y150.023 E.17882
G1 X155.962 Y151.847 E.07928
G1 X151.847 Y155.962 E.17882
G1 X150.065 Y154.18 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X151.465 Y152.752 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X151.963 Y153.306 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; FEATURE: Internal solid infill
; LINE_WIDTH: 0.41999
G1 F1200
G1 X152.679 Y154.022 E.03109
G1 X154.022 Y152.679 E.05836
G1 X153.306 Y151.963 E.03109
G1 X152.006 Y153.264 E.05652
G1 X152.454 Y153.306 F36000
; LINE_WIDTH: 0.36025
G1 F1200
G1 X152.679 Y153.531 E.00821
G1 X153.531 Y152.679 E.03116
G1 X153.306 Y152.454 E.00821
G1 X152.497 Y153.264 E.02961
; WIPE_START
G1 F15000
G1 X153.306 Y152.454 E-.43506
G1 X153.531 Y152.679 E-.12059
G1 X153.15 Y153.059 E-.20435
; WIPE_END
G1 E-.04 F1800
G1 X152.353 Y154.565 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F1200
M204 S2000
G1 X151.548 Y155.37 E.03497
G1 X151.282 Y155.103
G1 X152.087 Y154.299 E.03497
G1 X151.82 Y154.032
G1 X151.015 Y154.837 E.03497
G1 X150.748 Y154.57
G1 X151.553 Y153.765 E.03497
G1 X151.287 Y153.499
G1 X150.482 Y154.304 E.03497
; WIPE_START
G1 F12000
M204 S10000
G1 X151.287 Y153.499 E-.43252
G1 X151.553 Y153.765 E-.14329
G1 X151.211 Y154.108 E-.1842
; WIPE_END
G1 E-.04 F1800
G1 X152.589 Y154.775 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.295619
G1 F1200
G1 X151.758 Y155.606 E.02421
; WIPE_START
G1 F15000
G1 X152.589 Y154.775 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X151.144 Y153.329 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; LINE_WIDTH: 0.107593
G1 F1200
G1 X150.312 Y154.161 E.0062
; WIPE_START
G1 F15000
G1 X151.144 Y153.329 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.37 Y151.548 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F1200
M204 S2000
G1 X154.565 Y152.353 E.03497
G1 X154.299 Y152.087
G1 X155.103 Y151.282 E.03497
G1 X154.837 Y151.015
G1 X154.032 Y151.82 E.03497
G1 X153.765 Y151.553
G1 X154.57 Y150.748 E.03497
G1 X154.304 Y150.482
G1 X153.499 Y151.287 E.03497
; WIPE_START
G1 F12000
M204 S10000
G1 X154.304 Y150.482 E-.43251
G1 X154.57 Y150.748 E-.14329
G1 X154.227 Y151.091 E-.1842
; WIPE_END
G1 E-.04 F1800
G1 X155.606 Y151.758 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.295598
G1 F1200
G1 X154.775 Y152.589 E.02421
; WIPE_START
G1 F15000
G1 X155.606 Y151.758 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.161 Y150.312 Z10 F36000
G1 Z9.6
G1 E.8 F1800
; LINE_WIDTH: 0.107592
G1 F1200
G1 X153.329 Y151.144 E.0062
; CHANGE_LAYER
; Z_HEIGHT: 9.8
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X154.161 Y150.312 E-.76
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
G1 X152.124 Y152.591
G1 Z9.8
G1 E.8 F1800
; FEATURE: Inner wall
; LINE_WIDTH: 0.45
G1 F1200
G1 X152.591 Y152.124 E.02188
G1 X153.861 Y153.394 E.05957
G1 X153.394 Y153.861 E.02188
G1 X152.167 Y152.633 E.05758
; WIPE_START
G1 F15476.087
G1 X152.591 Y152.124 E-.2517
G1 X153.537 Y153.07 E-.5083
; WIPE_END
G1 E-.04 F1800
G1 X150.518 Y153.643 Z10.2 F36000
G1 Z9.8
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1200
M204 S6000
G1 X153.643 Y150.518 E.13578
G1 X155.467 Y152.342 E.07928
G1 X152.342 Y155.467 E.13578
G1 X150.56 Y153.685 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X151.955 Y152.252 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X151.56 Y152.894 Z10.2 F36000
G1 Z9.8
G1 E.8 F1800
; FEATURE: Top surface
G1 F1200
M204 S2000
G1 X153.091 Y154.425 E.06653
G1 X152.825 Y154.691
G1 X151.294 Y153.16 E.06653
G1 X151.027 Y153.427
G1 X152.558 Y154.958 E.06653
M204 S10000
G1 X152.39 Y155.152 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.178346
G1 F1200
G1 X150.832 Y153.595 E.02431
; WIPE_START
G1 F15000
G1 X152.247 Y155.009 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.316 Y154.227 Z10.2 F36000
G1 Z9.8
G1 E.8 F1800
; LINE_WIDTH: 0.263538
G1 F1200
G1 X151.758 Y152.669 E.0396
G1 X152.501 Y152.501 F36000
; LINE_WIDTH: 0.295499
M73 P99 R0
G1 F1200
G1 X153.483 Y153.483 E.02858
; WIPE_START
G1 F15000
G1 X152.501 Y152.501 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X153.427 Y151.027 Z10.2 F36000
G1 Z9.8
G1 E.8 F1800
; FEATURE: Top surface
; LINE_WIDTH: 0.42
G1 F1200
M204 S2000
G1 X154.958 Y152.558 E.06653
G1 X154.691 Y152.825
G1 X153.16 Y151.294 E.06653
G1 X152.893 Y151.56
G1 X154.424 Y153.091 E.06653
M204 S10000
G1 X154.226 Y153.316 F36000
; FEATURE: Gap infill
; LINE_WIDTH: 0.263453
G1 F1200
G1 X152.669 Y151.758 E.03959
; WIPE_START
G1 F15000
G1 X154.083 Y153.173 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X155.152 Y152.39 Z10.2 F36000
G1 Z9.8
G1 E.8 F1800
; LINE_WIDTH: 0.178472
G1 F1200
G1 X153.595 Y150.832 E.02433
; CHANGE_LAYER
; Z_HEIGHT: 10
; LAYER_HEIGHT: 0.2
; WIPE_START
G1 F15000
G1 X155.009 Y152.247 E-.76
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
G1 X151.233 Y152.927
G1 Z10
G1 E.8 F1800
; FEATURE: Outer wall
; LINE_WIDTH: 0.42
G1 F1200
M204 S6000
G1 X152.927 Y151.233 E.0736
G1 X154.751 Y153.058 E.07928
G1 X153.058 Y154.751 E.0736
G1 X151.276 Y152.97 E.07743
; WIPE_START
G1 F12000
M204 S10000
G1 X152.654 Y151.52 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X154.159 Y152.759 Z10.4 F36000
G1 Z10
G1 E.8 F1800
; FEATURE: Top surface
G1 F1200
M204 S2000
G1 X152.759 Y154.159 E.06085
G1 X152.492 Y153.893
G1 X153.893 Y152.492 E.06085
G1 X153.626 Y152.226
G1 X152.226 Y153.626 E.06085
G1 X151.959 Y153.36
G1 X153.36 Y151.959 E.06085
G1 X153.093 Y151.693
G1 X151.692 Y153.093 E.06085
; WIPE_START
G1 F12000
M204 S10000
G1 X153.093 Y151.693 E-.75257
G1 X153.107 Y151.706 E-.00743
; WIPE_END
G1 E-.04 F1800
G1 X154.395 Y152.968 Z10.4 F36000
G1 Z10
G1 E.8 F1800
; FEATURE: Gap infill
; LINE_WIDTH: 0.295618
G1 F1200
G1 X152.968 Y154.395 E.04156
; WIPE_START
G1 F15000
G1 X154.383 Y152.981 E-.76
; WIPE_END
G1 E-.04 F1800
G1 X152.95 Y151.523 Z10.4 F36000
G1 Z10
G1 E.8 F1800
; LINE_WIDTH: 0.107613
G1 F1200
G1 X151.523 Y152.95 E.01064
; close powerlost recovery
M1003 S0
; WIPE_START
G1 F15000
G1 X152.937 Y151.536 E-.76
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

