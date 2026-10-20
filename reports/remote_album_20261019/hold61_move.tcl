cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
update_timing -mode final
move_cells -inst {osd/board_ascii[4]_syn_123} -location {x9y22z1} -mode enforce -step route
route -incremental
update_timing -mode final
fix_hold
update_timing -mode final
report_timing_status -file reports/remote_album_20261019/hold61_move_status.txt
report_timing_summary -file reports/remote_album_20261019/hold61_move_paths.txt -ep_num 20 -path_num 1
check_design
check_timing
export_db reports/remote_album_20261019/hold61_move.db
puts "HOLD61_MOVE_COMPLETED"
exit
