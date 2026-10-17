cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
update_timing -mode final
source scripts/adaptive_clocks.tcl
# SWUG105 section 4.6.1: optimize physical implementation after routing.
phys_opt -post_route -effort high
update_timing -mode final
source scripts/adaptive_clocks.tcl
fix_hold
update_timing -mode final
report_timing_status -file reports/keyboard_20261016/postroute_timing_status.txt
report_timing_summary -file reports/keyboard_20261016/postroute_timing_summary.txt
export_db reports/keyboard_20261016/postroute_probe.db
puts "POSTROUTE_PROBE_COMPLETED"
exit
