# Generate from the verified shortcut-mode-popup routed database; keep routing intact.
set root [file normalize [file join [file dirname [info script]] ../../..]]
set out [file normalize [file dirname [info script]]]
cd $root
source [file join $out expected_timing.tcl]

proc verify_timing {path} {
    set fh [open $path r]
    set timing [read $fh]
    close $fh
    foreach {metric expected} $::expected_timing {
        set pattern [format {%s:\s*(-?[0-9]+\.[0-9]+)ns} $metric]
        if {![regexp $pattern $timing ignored value]} {
            error "Cannot parse $metric; refusing candidate bitstream"
        }
        if {$value < 0 || abs($value-$expected)>0.0005} {
            error "$metric differs from verified STA ($value ns); candidate rejected"
        }
    }
}

import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
update_timing -mode final
source scripts/adaptive_clocks.tcl
update_timing -mode final
report_timing_status -file $out/before_bit_timing_status.txt
report_timing_summary -file $out/before_bit_timing_summary.txt
verify_timing $out/before_bit_timing_status.txt

bitgen -bit $out/video_improve_mode_popup_20261023.bit

update_timing -mode final
report_timing_status -file $out/after_bit_timing_status.txt
report_timing_summary -file $out/after_bit_timing_summary.txt
verify_timing $out/after_bit_timing_status.txt
puts "BITGEN_COMPLETED"
exit
