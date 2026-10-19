cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {reports/deep_opt_20261017/bram_pixel.v src/modules/video/video_luma_window_bram.v} -top pixel_effects
set_param gate map_mode area_prior
optimize_rtl
optimize_gate
report_area -file reports/deep_opt_20261017/bram_pixel.txt
exit
