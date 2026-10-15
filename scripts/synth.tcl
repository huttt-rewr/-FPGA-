set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
file mkdir reports
import_device eagle_s20.db -package EG4S20BG256
# TD 6.2.1 project elaboration can crash before optimization. Read the same
# audited manifest directly; pin/clock constraints remain the project originals.
# run_build.py emits literal paths: TD's command parser does not expand a
# variable list reliably in read_verilog -file.
source reports/design_sources.tcl
read_adc src/constraints/pin.adc
read_sdc src/constraints/timing.sdc
optimize_rtl
report_area -file reports/rtl_area.txt
optimize_gate
legalize_phy_inst
report_area -file reports/gate_area.txt
export_db reports/video_improve_gate.db
puts "SYNTHESIS_COMPLETED"
exit
