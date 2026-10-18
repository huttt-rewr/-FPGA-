`timescale 1ns/1ps
module tb_osd_bcd;
 reg clk=0,rst=1;reg [11:0] width=0,height=0;
 integer value,errors=0;reg [15:0] expected_w,expected_h;
 always #5 clk=~clk;
 status_osd #(.ENHANCED_UI(1)) dut(.clk(clk),.rst(rst),.vs(1'b0),.de(1'b0),
  .rgb(24'd0),.source_width(width),.source_height(height),
  .enable(1'b0),.auto_play(1'b0),.image_index(2'd0),.image_count(3'd0),
  .volume(5'd0),.mute(1'b0),.busy(1'b0),.error(1'b0),.edid_ok(1'b0),
  .brightness(8'sd0),.contrast(4'd4),.edit_mode(2'd0),.mode_800(1'b0),
  .menu_open(1'b0),.menu_item(3'd0),.gamma_enable(1'b0),.debug_enable(1'b0),.debug_page(2'd0),
  .audio_ready(1'b0),.audio_error(1'b0),.audio_error_code(4'd0),.audio_underflow(1'b0),
  .file_image_index(7'd0),.file_image_count(7'd0),.file_audio_index(7'd0),.file_audio_count(7'd0),
  .file_table_truncated(1'b0),.slide_rate_mode(4'd0),.slide_rate_limited(1'b0),.requested_res_mode(2'd0));
 function [15:0] decimal_digits;
  input integer n;
  begin
   decimal_digits[15:12]=n/1000;
   decimal_digits[11:8]=(n/100)%10;
   decimal_digits[7:4]=(n/10)%10;
   decimal_digits[3:0]=n%10;
  end
 endfunction
 initial begin
  repeat(3)@(negedge clk);rst=0;
  for(value=0;value<4096;value=value+1)begin
   width=value;height=4095-value;
   expected_w=decimal_digits(value);expected_h=decimal_digits(4095-value);
   @(posedge clk);#1;
   if({dut.w0,dut.w1,dut.w2,dut.w3}!==expected_w ||
      {dut.h0,dut.h1,dut.h2,dut.h3}!==expected_h)begin
    errors=errors+1;if(errors<8)$display("FAILED BCD value=%0d",value);
   end
   @(negedge clk);
  end
  rst=1;#1;
  if({dut.w0,dut.w1,dut.w2,dut.w3,dut.h0,dut.h1,dut.h2,dut.h3}!==32'd0)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_osd_bcd: all 4096 widths/heights, one register latency and asynchronous reset");
  else $display("FAILED tb_osd_bcd errors=%0d",errors);
  $finish;
 end
 initial begin #100000;$display("FAILED BCD watchdog");$finish;end
endmodule
