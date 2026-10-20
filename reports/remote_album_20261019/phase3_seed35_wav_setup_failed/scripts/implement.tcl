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
set_param place seed 35
place
# The registered SDC survives timer rebuilds. Refresh before reporting and
# optimizing, without adding duplicate generated-clock definitions.
update_timing
report_timing_status -file reports/rebound_placed_timing_status.txt
report_timing_summary -file reports/rebound_placed_timing_paths20.txt -ep_num 20 -path_num 1
# Use the last legal flow. The directed replication experiment caused
# routing conflicts; the WAV receive register now cuts that path in RTL.
# Documented router effort for congested local connections.
set_param route effort routability
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

report_area -io_info -file reports/physical_area.txt
report_timing_status -file reports/timing_status.txt
report_timing_summary -file reports/timing_summary.txt
report_timing_summary -file reports/routed_timing_paths20.txt -ep_num 20 -path_num 1
report_io -file reports/io.txt -verbose
check_design
check_timing
export_db reports/video_improve_routed.db
# A separate TD session reloads this immutable checkpoint for incremental
# routing/hold cleanup. Repeating fix_hold in this session leaves one short net.
export_db reports/video_improve_hold_input.db
# Bitstream is intentionally generated separately after board/timing review.
puts "IMPLEMENTATION_COMPLETED"
exit


