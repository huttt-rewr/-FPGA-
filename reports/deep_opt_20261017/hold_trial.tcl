cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_prior_opt.db
set_param flow qor_monitor off
update_timing -mode final
source scripts/adaptive_clocks.tcl
fix_hold
update_timing -mode final
report_timing_status -file reports/deep_opt_20261017/hold_trial_status.txt
report_timing_summary -file reports/deep_opt_20261017/hold_trial_paths.txt -ep_num 20 -path_num 1
export_db reports/deep_opt_20261017/hold_trial.db
puts "HOLD_TRIAL_COMPLETED"
exit
