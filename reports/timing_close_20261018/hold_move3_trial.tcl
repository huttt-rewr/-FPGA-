cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/timing_close_20261018/wav_ingress1/video_improve_routed.db
update_timing -mode final
move_cells -inst {status_cdc/held_reg[36]_syn_4} -location {x15y26z0} -mode enforce -step route
route -incremental
update_timing -mode final
fix_hold
update_timing -mode final
report_timing_status -file reports/timing_close_20261018/hold_move3_status.txt
report_timing_summary -file reports/timing_close_20261018/hold_move3_paths.txt -ep_num 20 -path_num 1
check_design
check_timing
export_db reports/timing_close_20261018/hold_move3.db
puts "HOLD_MOVE3_TRIAL_COMPLETED"
exit
