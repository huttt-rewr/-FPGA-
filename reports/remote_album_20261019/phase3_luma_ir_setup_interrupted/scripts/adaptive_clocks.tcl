# Called after starting the timing engine. Only mux OUTPUT alternatives are
# exclusive; the 25MHz EDID boot clock remains live and fully timed.
# Both selected 1x/5x clocks remain RELATED inside each mode.
set px [get_pins -hier *pixel_switch*clko*]
set ser [get_pins -hier *serial_switch*clko*]
if {[llength $px]!=1 || [llength $ser]!=1} {error "Adaptive clock muxes missing"}
# Bind to the selected physical input, not the common 50MHz reference. This
# preserves the distinct insertion delays on C0/C2 and C1/C3 through the mux.
foreach {name index target} [list vga_pixel 0 $px svga_pixel 2 $px vga_serial 1 $ser svga_serial 3 $ser] {
    set pll_name [format {video_pll_m0/pll_inst.clkc[%d]} $index]
    set pll_pin [get_pins -hier $pll_name]
    if {[llength $pll_pin]!=1} {error "Adaptive PLL source missing: $pll_name"}
    create_generated_clock -name $name -add -master_clock $pll_name -source $pll_pin -divide_by 1 $target
}
set_clock_sense -stop_propagation -clocks [get_clocks {video_pll_m0/pll_inst.clkc[0]}] $px
set_clock_sense -stop_propagation -clocks [get_clocks {video_pll_m0/pll_inst.clkc[2]}] $px
set_clock_sense -stop_propagation -clocks [get_clocks {video_pll_m0/pll_inst.clkc[1]}] $ser
set_clock_sense -stop_propagation -clocks [get_clocks {video_pll_m0/pll_inst.clkc[3]}] $ser
set_clock_groups -exclusive -group {vga_pixel vga_serial} -group {svga_pixel svga_serial}
