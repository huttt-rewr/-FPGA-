set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
file mkdir reports
open_project video_improve.al
import_device eagle_s20.db -package EG4S20BG256
elaborate -top top
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
