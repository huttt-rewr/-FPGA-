cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {reports/deep_opt_20261017/fat_shared.v} -top sd_fat32
set_param gate map_mode area_prior
optimize_rtl
optimize_gate
report_area -file reports/deep_opt_20261017/fat_shared.txt
exit
