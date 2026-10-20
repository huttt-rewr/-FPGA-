cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {E:/fpga/src/modules/video/auto_enhance.v E:/fpga/src/modules/video/auto_enhance_scale.v} -top auto_enhance
optimize_rtl
optimize_gate
report_area -file reports/remote_album_20261019/bram_levels_area.txt
puts "BRAM_LEVELS_PROBE_COMPLETED"
exit
