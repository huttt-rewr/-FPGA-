cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
update_timing -mode final
fix_hold -net {status_cdc/held[61]} -buffer_opt -eco
update_timing -mode final
report_timing_status -file reports/remote_album_20261019/hold61_status.txt
report_timing_summary -file reports/remote_album_20261019/hold61_paths.txt -ep_num 20 -path_num 1
check_design
check_timing
export_db reports/remote_album_20261019/hold61.db
puts "HOLD61_COMPLETED"
exit
