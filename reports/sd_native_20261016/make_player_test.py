"""Derive an extra integration fixture without editing the existing regression."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
text = (root / 'sim/tb_fat32_player.v').read_text(encoding='utf-8-sig')
text = text.replace('tb_fat32_player', 'tb_sd_native_player')
start = text.index(' integer fd,seek_result')
end = text.index(' always @(posedge clk)', start)
text = text[:start] + ''' integer fd,errors=0,pixels=0,frames=0,samples=0,j;
 reg [7:0] wav_bytes[0:4095];
 reg [23:0] expected[0:307199];
 wire native_init,native_init_error,native_error,native_valid,native_done;
 wire [7:0] native_data;
 wire native_clock;
 wire [31:0] model_errors;
 tri1 native_cmd,native_d0,native_d1,native_d2,native_d3;
 sd_card_top_native #(.SPI_LOW_SPEED_DIV(0),.WAIT_TIMEOUT_CYCLES(12000),
  .INIT_TIMEOUT_CYCLES(100000),.INIT_PAUSE_CYCLES(200)) transport(
  .clk(clk),.rst(rst | dut.transport_reset),.SD_CLK(native_clock),.SD_CMD(native_cmd),
  .SD_DAT0(native_d0),.SD_DAT1(native_d1),.SD_DAT2(native_d2),.SD_DAT3(native_d3),
  .sd_init_done(native_init),.sd_init_error(native_init_error),.sd_transfer_error(native_error),
  .sd_sec_read(dut.card_read),.sd_sec_read_addr(dut.card_addr),.sd_sec_read_data(native_data),
  .sd_sec_read_data_valid(native_valid),.sd_sec_read_end(native_done),.sd_sec_write(1'b0),
  .sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end());
 sd_native_card_model #(.IMAGE_MODE(1)) card(.rst(rst),.SD_CLK(native_clock),.SD_CMD(native_cmd),
  .SD_DAT({native_d3,native_d2,native_d1,native_d0}),.ccs(1'b1),.fault(4'd0),
  .last_read_argument(),.commands(),.reads(),.errors(model_errors));
 initial begin
  // Substitute only the physical transport; all player/FAT32/BMP/WAV RTL is real.
  force dut.sd_init_done=native_init;force dut.sd_init_error=native_init_error;
  force dut.raw_transfer_error=native_error;
  force dut.card_data=native_data;force dut.card_valid=native_valid;force dut.card_end=native_done;
 end
''' + text[end:]
text = text.replace('if(errors==0)$display(', 'if(model_errors!=0)errors=errors+1;\n  if(errors==0)$display(')
text = text.replace('real scheduler/two scaled fragmented BMP frames/exact PCM concurrent loops/commit',
                    '4-bit physical transport/real scheduler/two scaled fragmented BMP frames/exact PCM loops/commit')
(root / 'sim/tb_sd_native_player.v').write_text(text, encoding='utf-8')
