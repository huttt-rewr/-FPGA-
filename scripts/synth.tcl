set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
file mkdir reports
open_project video_improve.al
elaborate -top top
read_adc src/user_source/constraints_source/pin.adc
read_sdc src/user_source/constraints_source/timing.sdc
optimize_rtl
report_area -file reports/rtl_area.txt
optimize_gate
legalize_phy_inst
report_area -file reports/gate_area.txt
export_db reports/video_improve_gate.db
puts "SYNTHESIS_COMPLETED"
exit
