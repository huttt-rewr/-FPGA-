set fx_task_root [file normalize [file join [file dirname [info script]] ../..]]
set fx_probe_out [file join $fx_task_root reports/audio_effects_20261014/final_probe]
file mkdir $fx_probe_out
cd $fx_probe_out
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {E:/fpga/src/modules/audio/audio_effects.v E:/fpga/sim/tb_audio_effects.v} -define AUDIO_EFFECTS_SYNTHESIS_PROBE -top audio_effects_probe
read_sdc E:/fpga/reports/audio_effects_20261014/probe.sdc
optimize_rtl
report_area -file rtl_area.txt
optimize_gate
legalize_phy_inst
report_area -file gate_area.txt
export_db gate.db
update_timing
place
route
update_timing -mode final
fix_hold
update_timing -mode final
report_area -file physical_area.txt
report_timing_status -file timing_status.txt
report_timing_summary -file timing_summary.txt
export_db routed.db
puts "AUDIO_EFFECTS_ENABLED_PROBE_COMPLETED"
exit
