# Optional experiment. Does not replace production database or prove HDMI pad timing.
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
set rstpins [get_pins -hier {u_hdmi_1_4b_transmitter_core_wrapper/u0_reset_sync/O_sync_reset_reg_syn_70.q[0]}]
if {[llength $rstpins] != 1} { error "HDMI reset startpoint changed; inspect routed report before retrying" }
set_path_margin -group hdmi_reset_guard -hold -from $rstpins 0.55
report_path_margin
fix_hold
update_timing -mode final
report_timing_summary -file reports/hdmi_reset_guard.txt
reset_path_margin -all
update_timing -mode final
report_timing_summary -file reports/hdmi_reset_nominal.txt
export_db reports/hdmi_reset_trial.db
exit
