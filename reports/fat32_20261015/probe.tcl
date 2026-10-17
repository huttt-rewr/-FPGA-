cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file E:/fpga/src/modules/sd/sd_fat32.v -top sd_fat32
optimize_rtl
report_area -file reports/fat32_20261015/probe_rtl_area.txt
optimize_gate
report_area -file reports/fat32_20261015/probe_gate_area.txt
puts "FAT32_SYNTH_PROBE_COMPLETED"
exit
