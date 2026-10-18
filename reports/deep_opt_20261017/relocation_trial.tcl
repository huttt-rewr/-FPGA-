cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/deep_opt_20261017/hold_trial.db
set_param flow qor_monitor off
update_timing -mode final
source scripts/adaptive_clocks.tcl
phys_opt -post_route -mode relocation -effort low
update_timing -mode final
source scripts/adaptive_clocks.tcl
fix_hold
update_timing -mode final
report_timing_status -file reports/deep_opt_20261017/relocation_trial_status.txt
export_db reports/deep_opt_20261017/relocation_trial.db
puts "RELOCATION_TRIAL_COMPLETED"
exit
