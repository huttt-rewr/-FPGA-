set root E:/fpga
cd $root
import_device eagle_s20.db -package EG4S20BG256
import_db reports/build_repair_20261018/pr1_trial/video_improve_gate.db
set_param flow qor_monitor off
update_timing
source scripts/adaptive_clocks.tcl

# Prefer LUT pairs: avoid wasting slice sites beside distributed line RAM.
set_param place pack_mode more_lut_pair
set_param place pr_strategy 1
place
# Physical mapping rebuilds mux clock pins. Rebind the same existing mode
# clocks before timing-driven routing as well as before final STA.
update_timing
source scripts/adaptive_clocks.tcl
# Native 4-bit/CMD6 increases routing pressure beside the unchanged scaler.
# Use the documented higher-effort placement optimization; no timing exception.
phys_opt -post_place -effort ultra
# post_place保留上述时钟；重复绑定会产生USR-8170重复定义告警。
# route之后仍按原流程绑定最终映射引脚，不改变任何时钟约束。
route
update_timing -mode final
# TD rebuilds clock objects during physical mapping; bind to the final mux pins.
source scripts/adaptive_clocks.tcl
# Optimize the actual routed paths after rebinding mode clocks.
# Preserve routed diagnostics before an optional optimizer can fail internally.
update_timing -mode final
report_timing_status -file reports/build_repair_20261018/pr1_trial/prior_opt_timing_status.txt
report_timing_summary -file reports/build_repair_20261018/pr1_trial/prior_opt_timing_paths20.txt -ep_num 20 -path_num 1
export_db reports/build_repair_20261018/pr1_trial/video_improve_prior_opt.db
# TD6.2.1 post-route phys_opt crashes in its timing-path checker on this design.
# The standalone documented hold fixer preserves routing and completes normally.
fix_hold
update_timing -mode final

report_area -io_info -file reports/build_repair_20261018/pr1_trial/physical_area.txt
report_timing_status -file reports/build_repair_20261018/pr1_trial/timing_status.txt
report_timing_summary -file reports/build_repair_20261018/pr1_trial/timing_summary.txt
report_timing_summary -file reports/build_repair_20261018/pr1_trial/routed_timing_paths20.txt -ep_num 20 -path_num 1
report_io -file reports/build_repair_20261018/pr1_trial/io.txt -verbose
check_design
check_timing
export_db reports/build_repair_20261018/pr1_trial/video_improve_routed.db
# Bitstream is intentionally generated separately after board/timing review.
puts "IMPLEMENTATION_COMPLETED"
exit


