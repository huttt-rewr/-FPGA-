cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {reports/deep_opt_20261017/baseline_glass.v src/modules/video/pixel_effects.v src/modules/osd/osd_char_rom.v} -top glass_osd
set_param gate map_mode area_prior
optimize_rtl
optimize_gate
report_area -file reports/deep_opt_20261017/glass_before.txt
exit
