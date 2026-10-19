set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_gate.db
set_param flow qor_monitor off
update_timing
# Register the exact existing mode-clock definitions as an SDC input.
# TD replays SDC inputs when pack/route rebuilds the timing engine; Tcl-only
# definitions disappear inside those commands even if final STA rebinds them.
read_sdc scripts/adaptive_mode_clocks.sdc
update_timing

# Prefer LUT pairs: avoid wasting slice sites beside distributed line RAM.
set_param place pack_mode more_lut_pair
set_param place pr_strategy 1
place
# The registered SDC survives timer rebuilds. Refresh before reporting and
# optimizing, without adding duplicate generated-clock definitions.
update_timing
report_timing_status -file reports/rebound_placed_timing_status.txt
report_timing_summary -file reports/rebound_placed_timing_paths20.txt -ep_num 20 -path_num 1
# Use the last legal flow. The directed replication experiment caused
# routing conflicts; the WAV receive register now cuts that path in RTL.
route
update_timing -mode final
# Preserve routed diagnostics before hold repair.
report_timing_status -file reports/prior_opt_timing_status.txt
report_timing_summary -file reports/prior_opt_timing_paths20.txt -ep_num 20 -path_num 1
export_db reports/video_improve_prior_opt.db
# TD6.2.1 post-route phys_opt crashes in its timing-path checker on this design.
# The standalone documented hold fixer preserves routing and completes normally.
fix_hold
update_timing -mode final

# This packed status slice has a short 100MHz -> pixel-clock path that the
# automatic hold fixer leaves at -0.234ns. Relocate only that launching slice,
# then reroute affected nets. This adds real physical delay; no timing exception.
# Names/coordinates apply to the frozen EG4S20 netlist, so reject a missing cell.
set short_path_cell [get_cells {status_cdc/held_reg[36]_syn_4}]
if {[llength $short_path_cell] != 1} {
    error "Expected status snapshot hold-repair slice not found; review mapped timing"
}
move_cells -inst {status_cdc/held_reg[36]_syn_4} -location {x15y26z0} -mode enforce -step route
route -incremental
update_timing -mode final
fix_hold
update_timing -mode final

report_area -io_info -file reports/physical_area.txt
report_timing_status -file reports/timing_status.txt
report_timing_summary -file reports/timing_summary.txt
report_timing_summary -file reports/routed_timing_paths20.txt -ep_num 20 -path_num 1
report_io -file reports/io.txt -verbose
check_design
check_timing
export_db reports/video_improve_routed.db
# Bitstream is intentionally generated separately after board/timing review.
puts "IMPLEMENTATION_COMPLETED"
exit


