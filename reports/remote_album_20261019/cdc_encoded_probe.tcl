cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {E:/fpga/src/modules/common/cdc_snapshot.v E:/fpga/reports/remote_album_20261019/cdc_encoded_probe.v} -top cdc_encoded_probe
optimize_rtl
optimize_gate
report_area -file reports/remote_album_20261019/cdc_encoded_area.txt
export_db reports/remote_album_20261019/cdc_encoded_gate.db
puts "CDC_ENCODED_PROBE_COMPLETED"
exit
