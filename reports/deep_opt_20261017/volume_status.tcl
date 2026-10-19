cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {reports/deep_opt_20261017/volume_status.v src/modules/video/video_coordinates.v src/modules/osd/osd_char_rom.v} -top status_osd
set_param gate map_mode area_prior
optimize_rtl
optimize_gate
report_area -file reports/deep_opt_20261017/volume_status.txt
exit
