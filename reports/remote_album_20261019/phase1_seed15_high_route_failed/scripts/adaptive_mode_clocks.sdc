# Exact static expansion of scripts/adaptive_clocks.tcl; no new exceptions.
create_generated_clock -name vga_pixel -add -master_clock {video_pll_m0/pll_inst.clkc[0]} -source [get_pins -hier {video_pll_m0/pll_inst.clkc[0]}] -divide_by 1 [get_pins -hier *pixel_switch*clko*]
create_generated_clock -name svga_pixel -add -master_clock {video_pll_m0/pll_inst.clkc[2]} -source [get_pins -hier {video_pll_m0/pll_inst.clkc[2]}] -divide_by 1 [get_pins -hier *pixel_switch*clko*]
create_generated_clock -name vga_serial -add -master_clock {video_pll_m0/pll_inst.clkc[1]} -source [get_pins -hier {video_pll_m0/pll_inst.clkc[1]}] -divide_by 1 [get_pins -hier *serial_switch*clko*]
create_generated_clock -name svga_serial -add -master_clock {video_pll_m0/pll_inst.clkc[3]} -source [get_pins -hier {video_pll_m0/pll_inst.clkc[3]}] -divide_by 1 [get_pins -hier *serial_switch*clko*]
set_clock_sense -stop_propagation -clocks [get_clocks {video_pll_m0/pll_inst.clkc[0]}] [get_pins -hier *pixel_switch*clko*]
set_clock_sense -stop_propagation -clocks [get_clocks {video_pll_m0/pll_inst.clkc[2]}] [get_pins -hier *pixel_switch*clko*]
set_clock_sense -stop_propagation -clocks [get_clocks {video_pll_m0/pll_inst.clkc[1]}] [get_pins -hier *serial_switch*clko*]
set_clock_sense -stop_propagation -clocks [get_clocks {video_pll_m0/pll_inst.clkc[3]}] [get_pins -hier *serial_switch*clko*]
set_clock_groups -exclusive -group {vga_pixel vga_serial} -group {svga_pixel svga_serial}
