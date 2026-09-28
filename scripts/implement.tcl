set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_gate.db
place
route
update_timing -mode final
report_area -io_info -file reports/physical_area.txt
report_timing_status -file reports/timing_status.txt
report_timing_summary -file reports/timing_summary.txt
report_clock_utilization -file reports/clocks.txt
export_db reports/video_improve_routed.db
# Bitstream is intentionally generated separately after board/timing review.
puts "IMPLEMENTATION_COMPLETED"
exit
