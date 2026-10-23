cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {src/modules/audio/spectrum_coefficients.v src/modules/audio/spectrum_fft256.v} -top spectrum_fft256
set_param gate map_mode area_prior
set_param gate pack_effort high
optimize_rtl
optimize_gate
legalize_phy_inst
report_area -file reports/music_spectrum_20261023/fft_probe_area.txt
puts "PROBE_COMPLETED"
exit
