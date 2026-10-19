cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/deep_opt_20261017/second_build/video_improve_gate.db
update_timing
source scripts/adaptive_clocks.tcl
set_param place pack_mode more_lut_pair
place
update_timing
source scripts/adaptive_clocks.tcl
phys_opt -post_place -effort ultra
report_timing_path -file reports/deep_opt_20261017/placed_paths20.txt -ep_num 20 -path_num 1
report_timing_summary -file reports/deep_opt_20261017/placed_timing.txt
export_db reports/deep_opt_20261017/placed_diagnosis.db
exit
