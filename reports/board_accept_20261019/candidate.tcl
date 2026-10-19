# Generate a PC file only. No programmer/JTAG/Flash commands are used.
# Import the exact routed DB already bound to 101 passing regressions.
set root [file normalize [file join [file dirname [info script]] ../..]]
cd $root
set dest reports/board_accept_20261019/candidate
file mkdir $dest
if {[file exists $dest/hdmi_640_plain_800_audio.bit]} {
    error "Candidate exists; never overwrite a reviewed bitstream"
}
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
update_timing -mode final
# The DB retains the registered adaptive_mode_clocks.sdc. Do not add a second
# set of generated clocks or route/modify the accepted placement here.
report_timing_status -file $dest/before_bit_timing_status.txt
report_timing_summary -file $dest/before_bit_timing_paths.txt -ep_num 1 -path_num 1
set f [open $dest/before_bit_timing_status.txt r]
set timing [read $f]
close $f
foreach metric {SWNS STNS HWNS HTNS} {
    if {![regexp "$metric: *(-?\[0-9\]+\\.\[0-9\]+)ns" $timing ignored value]} {
        error "Missing $metric; refusing bit generation"
    }
    if {$value < 0} {error "Negative $metric ($value); refusing bit generation"}
}
set f [open $dest/before_bit_timing_paths.txt r]
set paths [read $f]
close $f
set header [lindex [split $paths "\n"] 0]
foreach name {vga_pixel svga_pixel vga_serial svga_serial} {
    if {[string first $name $paths] < 0} {error "Missing mode clock $name"}
}
bitgen -bit $dest/hdmi_640_plain_800_audio.bit
update_timing -mode final
report_timing_status -file $dest/after_bit_timing_status.txt
report_timing_summary -file $dest/after_bit_timing_paths.txt -ep_num 1 -path_num 1
puts "BOARD_CANDIDATE_COMPLETED"
exit
