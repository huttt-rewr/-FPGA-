`timescale 1ns/1ps
module tb_image_index_equivalence;
 reg clk=0,rst=1;
 always #5 clk=~clk;
 integer cur,count,errors=0,checks=0;
 reg [5:0] expected;
 sd_card_bmp dut(.clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),
  .cmd_next(1'b0),.cmd_prev(1'b0),.cmd_toggle(1'b0),
  .image_select_index(8'd0),.image_select_valid(1'b0),
  .audio_select_index(8'd0),.audio_select_valid(1'b0),
  .commit_ack_toggle(1'b0),.write_finish_toggle(1'b0),.write_req_ack(1'b0),
  .bmp_width(16'd640),.bmp_height(16'd480),.pixel_ready(1'b1),
  .audio_enable(1'b0),.audio_sample_ready(1'b0),.audio_sector_room(1'b0),
  .fps_mode(4'd0),.SD_MISO(1'b1));
 initial begin
  // Call the real production function. Cover all declared bit patterns,
  // including empty tables, the 63->64 carry and counts above the file limit.
  for(count=0;count<128;count=count+1)begin
   for(cur=0;cur<64;cur=cur+1)begin
    expected=(count==0 || cur>=count-1)?6'd0:cur+1;
    #1;
    if(dut.next_index_limited(cur[5:0],count[6:0])!==expected)begin
     errors=errors+1;
     $display("FAILED image index cur=%0d count=%0d",cur,count);
    end
    checks=checks+1;
   end
  end
  if(errors==0)$display("ALL PASS tb_image_index_equivalence: %0d exhaustive production-function cases, zero count, max index, carry and out-of-range counts",checks);
  else $display("FAILED image index errors=%0d",errors);
  $finish;
 end
endmodule
