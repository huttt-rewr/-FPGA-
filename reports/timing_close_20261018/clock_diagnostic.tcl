set root E:/fpga
cd $root
set dest reports/timing_close_20261018/clock_diagnostic
file mkdir $dest
import_device eagle_s20.db -package EG4S20BG256
import_db reports/timing_close_20261018/build3/video_improve_gate.db
set_param flow qor_monitor off
update_timing
source scripts/adaptive_clocks.tcl
set_param place pack_mode more_lut_pair
set_param place pr_strategy 2
place
update_timing
report_timing_status -file $dest/after_place_raw_status.txt
report_timing_summary -file $dest/after_place_raw_paths.txt -ep_num 3 -path_num 1
source scripts/adaptive_clocks.tcl
report_timing_status -file $dest/after_place_rebound_status.txt
report_timing_summary -file $dest/after_place_rebound_paths.txt -ep_num 3 -path_num 1
phys_opt -post_place -effort ultra
update_timing
report_timing_status -file $dest/after_opt_status.txt
report_timing_summary -file $dest/after_opt_paths.txt -ep_num 3 -path_num 1
export_db $dest/placed.db
puts DIAGNOSTIC_COMPLETED
exit
