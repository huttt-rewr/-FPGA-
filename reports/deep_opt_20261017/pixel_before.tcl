cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {reports/deep_opt_20261017/baseline_pixel.v} -top pixel_effects
set_param gate map_mode area_prior
optimize_rtl
optimize_gate
report_area -file reports/deep_opt_20261017/pixel_before.txt
exit
