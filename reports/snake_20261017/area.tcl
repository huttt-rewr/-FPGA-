cd E:/fpga
import_device eagle_s20.db -package EG4S20BG256
read_verilog -file {src/modules/game/snake_game.v src/modules/osd/osd_char_rom.v} -top snake_game
set_param gate map_mode area_prior
set_param gate pack_effort high
optimize_rtl
report_area -file reports/snake_20261017/game_rtl_area.txt
optimize_gate
legalize_phy_inst
report_area -file reports/snake_20261017/game_gate_area.txt
export_db reports/snake_20261017/game_gate.db
puts "GAME_SYNTHESIS_COMPLETED"
exit
