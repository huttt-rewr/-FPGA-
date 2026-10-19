cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/timing_close_20261018/build10/video_improve_routed.db
update_timing -mode final
puts "OWNER_NETS [get_nets -hier *owner*]"
puts "OWNER_EXACT [get_nets {sd_card_bmp_m0/filesystem$fat/owner}]"
puts "OWNER_CELLS [get_cells -hier *owner*]"
puts "OWNER_PINS [get_pins -hier *owner*]"
puts "QUERY_COMPLETED"
exit
