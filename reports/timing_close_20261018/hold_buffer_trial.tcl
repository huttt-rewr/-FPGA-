cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/timing_close_20261018/wav_ingress1/video_improve_routed.db
update_timing -mode final
fix_hold -net {status_cdc/held[36]} -buffer_opt -eco
update_timing -mode final
report_timing_status -file reports/timing_close_20261018/hold_buffer_status.txt
report_timing_summary -file reports/timing_close_20261018/hold_buffer_paths.txt -ep_num 20 -path_num 1
check_design
check_timing
export_db reports/timing_close_20261018/hold_buffer.db
puts "HOLD_BUFFER_TRIAL_COMPLETED"
exit
