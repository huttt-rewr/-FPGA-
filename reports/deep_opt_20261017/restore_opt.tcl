cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
set_param flow qor_monitor off
update_timing -mode final
phys_opt -post_route -effort ultra
update_timing -mode final
source scripts/adaptive_clocks.tcl
fix_hold
update_timing -mode final
report_timing_status -file reports/deep_opt_20261017/restore_opt_status.txt
report_timing_summary -file reports/deep_opt_20261017/restore_opt_paths.txt -ep_num 20 -path_num 1
export_db reports/deep_opt_20261017/restore_opt.db
puts "RESTORE_OPT_COMPLETED"
exit
