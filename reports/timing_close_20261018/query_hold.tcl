cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
import_db reports/timing_close_20261018/wav_ingress1/video_improve_routed.db
update_timing -mode final
help fix_hold
help route
report_cells [get_cells {status_cdc/held_reg[36]_syn_4}] -connection -pin_loc
report_cells [get_cells {status_cdc/dst_data_reg[22]_syn_4}] -connection -pin_loc
puts "QUERY_HOLD_COMPLETED"
exit
