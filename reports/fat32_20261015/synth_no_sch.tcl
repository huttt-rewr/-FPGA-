cd E:/fpga
open_project video_improve.al
import_device eagle_s20.db -package EG4S20BG256
elaborate -no_sch -top top
read_adc src/constraints/pin.adc
read_sdc src/constraints/timing.sdc
optimize_rtl
report_area -file reports/fat32_20261015/nosch_rtl_area.txt
optimize_gate
legalize_phy_inst
report_area -file reports/fat32_20261015/nosch_gate_area.txt
export_db reports/fat32_20261015/nosch_gate.db
puts "FAT32_NOSCH_SYNTH_COMPLETED"
exit
