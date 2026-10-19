cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/build_repair_20261018/build1/video_improve_routed.db
update_timing -mode final
source scripts/adaptive_clocks.tcl
update_timing -mode final
report_clock_utilization -dramhardcon -file reports/build_repair_20261018/sdram_hard_clock.txt
help report_timing_path
help get_pins
exit
