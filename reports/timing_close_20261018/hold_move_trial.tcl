cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/timing_close_20261018/wav_ingress1/video_improve_routed.db
update_timing -mode final
# Move the short-path launching slice away from the capture slice.
# Source slice was x18y26, capture x18y27. Keep all timing checks active.
move_cells -inst {status_cdc/held_reg[36]_syn_4} -location {x124y212} -mode enforce -step route
route -incremental
update_timing -mode final
fix_hold
update_timing -mode final
report_timing_status -file reports/timing_close_20261018/hold_move_status.txt
report_timing_summary -file reports/timing_close_20261018/hold_move_paths.txt -ep_num 20 -path_num 1
report_cells [get_cells {status_cdc/held_reg[36]_syn_4}] -connection -pin_loc
check_design
check_timing
export_db reports/timing_close_20261018/hold_move.db
puts "HOLD_MOVE_TRIAL_COMPLETED"
exit
