set root [file normalize [file join [file dirname [info script]] .. ..]]
cd $root
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
update_timing -mode final
multi_try_route -sink {audio_fifo/wgs0_reg[0]_syn_4.mi[0]}
update_timing -mode final
report_timing_status -file reports/timing_fix_20261022/fifo_route_status.txt
report_timing_summary -file reports/timing_fix_20261022/fifo_route_paths.txt -ep_num 20 -path_num 1
export_db reports/timing_fix_20261022/fifo_route_trial.db
puts "FIFO_ROUTE_TRIAL_COMPLETED"
exit
