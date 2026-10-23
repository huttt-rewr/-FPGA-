set root [file normalize [file join [file dirname [info script]] .. ..]]
cd $root
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
update_timing -mode final
set target {sd_card_bmp_m0/filesystem$fat/fat_word[6]}
set matching [get_nets -hier -quiet $target]
puts "FAT_HOLD_TARGET=$matching"
if {[llength $matching] != 1} {error "FAT hold target must resolve to one net"}
set_param route hold_fix_iteration 15
fix_hold -net $target
update_timing -mode final
report_timing_status -file reports/timing_fix_20261022/trial_status.txt
report_timing_summary -file reports/timing_fix_20261022/trial_paths.txt -ep_num 20 -path_num 1
report_area -file reports/timing_fix_20261022/trial_area.txt
export_db reports/timing_fix_20261022/trial_routed.db
puts "FAT_HOLD_REPAIR_COMPLETED"
exit
