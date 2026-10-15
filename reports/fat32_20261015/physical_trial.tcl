set root [file normalize [file join [file dirname [info script]] ../..]]
cd $root
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
update_timing -mode final
source scripts/adaptive_clocks.tcl
phys_opt -post_route -effort high -mode relocation
update_timing -mode final
source scripts/adaptive_clocks.tcl
fix_hold
update_timing -mode final
source scripts/adaptive_clocks.tcl
report_timing_status -file reports/fat32_20261015/physical_trial_timing.txt
report_timing_summary -file reports/fat32_20261015/physical_trial_summary.txt
export_db reports/fat32_20261015/physical_trial.db
puts "PHYSICAL_TRIAL_COMPLETED"
exit
