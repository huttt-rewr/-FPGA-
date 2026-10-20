`timescale 1ns/1ps
module tb_file_osd;
 reg clk=0,rst=1,truncated=0,busy=0,error=0;always #5 clk=~clk;
 reg [6:0] ii=9,ic=12,ai=2,ac=3;reg [9:0] x=16,y=32;
 integer errors=0;reg [3:0] rate=2;reg limited=0;reg [1:0] res=1;
 status_osd #(.FILE_UI(1),.RATE_UI(1),.BOARD_UI(1),.ENHANCED_UI(1)) dut(.clk(clk),.rst(rst),.vs(1'b1),.de(1'b1),.rgb(24'h123456),
  .enable(1'b1),.auto_play(1'b0),.image_index(2'd0),.image_count(3'd0),.volume(5'd8),.mute(1'b0),.busy(busy),.error(error),.edid_ok(1'b1),
  .result(),.pixel_x(),.pixel_y(),.brightness(8'd0),.contrast(4'd4),.edit_mode(2'd0),.source_width(12'd320),.source_height(12'd240),
  .mode_800(1'b0),.out_vs(),.out_de(),.menu_open(1'b0),.menu_item(3'd0),.gamma_enable(1'b0),.debug_enable(1'b0),.debug_page(2'd0),
  .audio_ready(1'b1),.audio_error(1'b0),.audio_error_code(4'd0),.audio_underflow(1'b0),
  .file_image_index(ii),.file_image_count(ic),.file_audio_index(ai),.file_audio_count(ac),.file_table_truncated(truncated),.slide_rate_mode(rate),.slide_rate_limited(limited),.requested_res_mode(res));
 initial begin force dut.x=x;force dut.y=y;end
 task char_at;input integer col;input [7:0] want;begin
  x=16+col*8;#1;
  if(dut.board_ascii!==want)begin errors=errors+1;$display("FAIL file OSD col=%0d got=%h want=%h",col,dut.board_ascii,want);end
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;repeat(4)@(negedge clk);
  char_at(13,"1");char_at(14,"0");char_at(16,"1");char_at(17,"2");
  char_at(23,"0");char_at(24,"3");char_at(26,"0");char_at(27,"3");
  ii=63;ic=64;ai=0;ac=0;truncated=1;busy=1;repeat(4)@(negedge clk);
  char_at(13,"6");char_at(14,"4");char_at(16,"6");char_at(17,"4");
  char_at(23,"0");char_at(24,"0");char_at(27,"0");char_at(34,"B");char_at(39,"T");
  error=1;char_at(34,"E");ic=0;repeat(4)@(negedge clk);char_at(13,"0");char_at(14,"0");
  y=16;char_at(24,"T");char_at(25,"A");char_at(26,"R");char_at(27,"G");
  char_at(28,"E");char_at(29,"T");char_at(30,":");char_at(31,"0");char_at(32,"5");char_at(33," ");
  rate=5;limited=1;char_at(31,"3");char_at(32,"0");char_at(33,"L");
  rate=0;limited=0;char_at(31,"0");char_at(32,"1");char_at(33," ");
  char_at(35,"R");char_at(36,":");char_at(37,"1");res=0;char_at(37,"0");res=2;char_at(37,"2");
  if(errors==0)$display("ALL PASS tb_file_osd: 10/12,64/64,03/03,00/00,truncation,busy/error,TARGET05/30/01 and limited flag");
  else $display("FAILED file OSD errors=%0d",errors);
  $finish;
 end
endmodule
