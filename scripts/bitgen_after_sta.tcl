# Produce a candidate bitstream only if STA on the imported database passes.
# Board electrical/compatibility validation remains separate.
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
update_timing -mode final
source scripts/adaptive_clocks.tcl
update_timing -mode final
report_timing_status -file reports/bitgen_timing_status.txt
set fh [open reports/bitgen_timing_status.txt r]
set timing [read $fh]
close $fh
foreach metric {SWNS HWNS STNS HTNS} {
    if {![regexp "$metric: *(-?\[0-9\]+\\.\[0-9\]+)ns" $timing ignored value]} {
        error "Cannot parse $metric; refusing bitgen"
    }
    if {$value < 0} { error "$metric is negative ($value ns); refusing bitgen" }
}
bitgen -bit reports/video_improve.bit
puts "BITGEN_COMPLETED"
exit
