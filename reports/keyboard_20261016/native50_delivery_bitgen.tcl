set root E:/fpga
cd $root
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_gate.db
update_timing
source scripts/adaptive_clocks.tcl

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
fix_hold
update_timing -mode final

report_area -io_info -file reports/keyboard_20261016/native50_delivery_bit_physical_area.txt
report_timing_status -file reports/keyboard_20261016/native50_delivery_bit_timing_status.txt
report_timing_summary -file reports/keyboard_20261016/native50_delivery_bit_timing_summary.txt
report_io -file reports/keyboard_20261016/native50_delivery_bit_io.txt -verbose
check_design
check_timing
export_db reports/keyboard_20261016/native50_delivery_bit_routed.db
# Bitstream is intentionally generated separately after board/timing review.
puts "IMPLEMENTATION_COMPLETED"
set fh [open reports/keyboard_20261016/native50_delivery_bit_timing_status.txt r]
set metrics [read $fh]
close $fh
foreach name {SWNS STNS HWNS HTNS} {
 if {![regexp [format {%s: *(-?[0-9]+\.[0-9]+)ns} $name] $metrics ignored value]} {error "Cannot parse timing"}
 if {$value < 0} {error "$name is negative; refusing bitgen"}
}
bitgen -bit reports/keyboard_20261016/video_improve_native50_delivery.bit
puts "BITGEN_COMPLETED_KEYBOARD"

exit


