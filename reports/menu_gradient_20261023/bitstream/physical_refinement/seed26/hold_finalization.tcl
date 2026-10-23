# Reload the completed routed design in a fresh TD session. Keep every clock
# definition and timing check, reroute incrementally, then apply physical hold
# repair. No logical changes, placement coordinates or new timing exceptions.
set root {E:/fpga}
cd $root
import_device eagle_s20.db -package EG4S20BG256
import_db E:/fpga/reports/menu_gradient_20261023/bitstream/physical_refinement/seed26/video_improve_hold_input.db
update_timing -mode final
route -incremental
update_timing -mode final
fix_hold
update_timing -mode final
report_area -io_info -file E:/fpga/reports/menu_gradient_20261023/bitstream/physical_refinement/seed26/physical_area.txt
report_timing_status -file E:/fpga/reports/menu_gradient_20261023/bitstream/physical_refinement/seed26/timing_status.txt
report_timing_summary -file E:/fpga/reports/menu_gradient_20261023/bitstream/physical_refinement/seed26/timing_summary.txt
report_timing_summary -file E:/fpga/reports/menu_gradient_20261023/bitstream/physical_refinement/seed26/routed_timing_paths20.txt -ep_num 20 -path_num 1
report_io -file E:/fpga/reports/menu_gradient_20261023/bitstream/physical_refinement/seed26/io.txt -verbose
check_design
check_timing
export_db E:/fpga/reports/menu_gradient_20261023/bitstream/physical_refinement/seed26/video_improve_routed.db
puts "HOLD_FINALIZATION_COMPLETED"
exit
