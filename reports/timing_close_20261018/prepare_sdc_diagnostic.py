from pathlib import Path
h=Path('reports/timing_close_20261018')
lines=['# Exact static expansion of scripts/adaptive_clocks.tcl; no new exceptions.']
for name,idx,target in [('vga_pixel',0,'pixel_switch'),('svga_pixel',2,'pixel_switch'),('vga_serial',1,'serial_switch'),('svga_serial',3,'serial_switch')]:
 master=f'video_pll_m0/pll_inst.clkc[{idx}]'
 lines.append(f'create_generated_clock -name {name} -add -master_clock {{{master}}} -source [get_pins -hier {{{master}}}] -divide_by 1 [get_pins -hier *{target}*clko*]')
for idx,target in [(0,'pixel_switch'),(2,'pixel_switch'),(1,'serial_switch'),(3,'serial_switch')]:
 master=f'video_pll_m0/pll_inst.clkc[{idx}]'
 lines.append(f'set_clock_sense -stop_propagation -clocks [get_clocks {{{master}}}] [get_pins -hier *{target}*clko*]')
lines.append('set_clock_groups -exclusive -group {vga_pixel vga_serial} -group {svga_pixel svga_serial}')
(h/'mode_clocks.sdc').write_text('\n'.join(lines)+'\n',encoding='ascii')
