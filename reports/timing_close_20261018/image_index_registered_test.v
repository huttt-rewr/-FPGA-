`timescale 1ns/1ps
module tb_image_index_equivalence;
 reg clk=0,rst=1;
 always #5 clk=~clk;
 integer cur,count,back,errors=0,checks=0;
 reg [5:0] probe_index=0;reg [6:0] probe_count=0;reg probe_back=0;
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
  force dut.img_found_count=probe_count;force dut.img_idx=probe_index;
  force dut.prev_requested=probe_back;
  force dut.sd_init_done=1'b0;
  repeat(3)@(negedge clk);rst=0;
  // Count settling uses the same cycle as the existing images_present guard.
  // Exercise both directions through the production output, including count
  // transitions each iteration, zero and all declared out-of-range patterns.
  for(count=0;count<128;count=count+1)begin
   for(cur=0;cur<64;cur=cur+1)begin
    for(back=0;back<2;back=back+1)begin
     @(negedge clk);probe_count=count;probe_index=cur;probe_back=back;
     @(posedge clk);#1;
     if(back)expected=(cur==0)?((count-1)&63):cur-1;
     else expected=(count==0 || cur>=count-1)?6'd0:cur+1;
     if(dut.next_from_current!==expected)begin
      errors=errors+1;
      if(errors<10)$display("FAILED cached image index cur=%0d count=%0d back=%0d got=%0d want=%0d",cur,count,back,dut.next_from_current,expected);
     end
     if(dut.images_present!==(count!=0) || dut.last_image_index!==((count-1)&127))begin
      errors=errors+1;$display("FAILED cached count/guard alignment");
     end
     checks=checks+1;
    end
   end
  end
  @(negedge clk);rst=1;#1;
  if(dut.images_present!==0 || dut.last_image_index!==7'h7f)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_image_index_equivalence: %0d exhaustive production next/previous cases, cached count/guard alignment, zero/max/out-of-range and reset",checks);
  else $display("FAILED image index errors=%0d",errors);
  $finish;
 end
endmodule
