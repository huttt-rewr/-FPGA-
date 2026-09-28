# Run only after timing_status.txt has positive setup and hold slack on the exact board.
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
import_device eagle_s20.db -package EG4S20BG256
import_db reports/video_improve_routed.db
bitgen -bit reports/video_improve.bit
puts "BITGEN_COMPLETED"
exit
