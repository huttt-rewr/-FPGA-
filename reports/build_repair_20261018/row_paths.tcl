cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
foreach {tag database} {
 baseline reports/deep_opt_20261017/final_build/video_improve_routed.db
 split reports/build_repair_20261018/build1/video_improve_routed.db
 final reports/build_repair_20261018/build3/video_improve_routed.db
} {
 import_db $database
 update_timing -mode final
 source scripts/adaptive_clocks.tcl
 update_timing -mode final
 set row_regs [get_pins -hier {*byte_address*}]
 puts "ROW_PIN_COUNT_${tag}: [llength $row_regs]"
 if {$row_regs eq ""} {error "No row address pins matched; refusing empty target report"}
 report_timing_path -to $row_regs -ep_num 40 -path_num 1 -file reports/build_repair_20261018/row_${tag}_paths.txt
}
exit
