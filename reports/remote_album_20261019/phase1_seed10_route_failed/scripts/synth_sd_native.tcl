# Standalone synthesis only: deliberately no invented board pin assignments.
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
file mkdir reports/sd_native_20261016
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {src/modules/sd/native/sd_bus_phy.v src/modules/sd/native/sd_native_controller.v src/modules/sd/native/sd_card_top_native.v} -top sd_card_top_native
optimize_rtl
report_area -file reports/sd_native_20261016/native_rtl_area.txt
optimize_gate
legalize_phy_inst
report_area -file reports/sd_native_20261016/native_gate_area.txt
export_db reports/sd_native_20261016/native_gate.db
puts "NATIVE_SYNTHESIS_COMPLETED"
exit
