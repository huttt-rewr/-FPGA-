# Run only against the final source-bound routed database. This exports a
# candidate file; it neither programs the board nor establishes I/O signoff.
cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
update_timing -mode final
report_timing_status -file reports/keyboard_20261016/native25_bitgen_timing_status.txt
set fh [open reports/keyboard_20261016/native25_bitgen_timing_status.txt r]
set timing [read $fh]
close $fh
foreach metric {SWNS HWNS STNS HTNS} {
 if {![regexp "$metric: *(-?\[0-9\]+\\.\[0-9\]+)ns" $timing ignored value]} {
  error "Cannot parse $metric; refusing bitgen"
 }
 if {$value < 0} {error "$metric is negative ($value ns); refusing bitgen"}
}
bitgen -bit reports/keyboard_20261016/video_improve_native25.bit
puts "BITGEN_COMPLETED_KEYBOARD"
exit
