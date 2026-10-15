# Isolated physical-only experiment. Never overwrite the qualified reports/DB.
cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
update_timing -mode final
source scripts/adaptive_clocks.tcl
report_timing_status -file reports/fat32_20261015/reroute_before.txt
phys_opt -post_route -effort high -mode reroute
update_timing -mode final
source scripts/adaptive_clocks.tcl
fix_hold
update_timing -mode final
report_timing_status -file reports/fat32_20261015/reroute_timing_status.txt
report_timing_summary -file reports/fat32_20261015/reroute_timing_summary.txt
report_area -io_info -file reports/fat32_20261015/reroute_area.txt
export_db reports/fat32_20261015/reroute_trial.db
puts "FAT32_REROUTE_TRIAL_COMPLETED"
exit
