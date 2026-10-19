cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {reports/deep_opt_20261017/baseline_scaler.v} -top bmp_scale_loader
set_param gate map_mode area_prior
set_param gate pack_effort high
optimize_rtl
optimize_gate
legalize_phy_inst
report_area -file reports/deep_opt_20261017/baseline_area.txt
puts "AREA_COMPLETED"
exit
