set root E:/fpga
cd $root
file mkdir reports
import_device eagle_s20.db -package EG4S20BG256
# TD 6.2.1 project elaboration can crash before optimization. Read the same
# audited manifest directly; pin/clock constraints remain the project originals.
# run_build.py emits literal paths: TD's command parser does not expand a
# variable list reliably in read_verilog -file.
source reports/osd_audioviz_20261017/linear_sources.tcl
read_adc src/constraints/pin.adc
read_sdc src/constraints/timing.sdc
# Exact video effects use LUT line RAM; prefer compact mapping and packing.
set_param gate map_mode area_prior
set_param gate pack_effort high
optimize_rtl
report_area -file reports/osd_audioviz_20261017/linear_rtl_area.txt
optimize_gate
legalize_phy_inst
report_area -file reports/osd_audioviz_20261017/linear_gate_area.txt
export_db reports/osd_audioviz_20261017/linear_gate.db
puts "SYNTHESIS_COMPLETED"
exit
