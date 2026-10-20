`timescale 1ns/1ps
module tb_bmp_stall;
 reg clk=0,rst=1,scan=0,abort_read=0,valid=0,ended=0;
 wire ready,request,stall;integer errors=0,i;
 always #5 clk=~clk;
 bmp_read #(.READ_STALL_CYCLES(16)) dut(
  .clk(clk),.rst(rst),.ready(ready),.scan_start(scan),.scan_start_sector(32'd0),
  .scan_max_sector(32'd0),.scan_target_count(3'd1),.load_start(1'b0),
  .load_abort(abort_read),.load_sector(32'd0),.sd_init_done(1'b1),
  .bmp_width(16'd640),.bmp_height(16'd480),.write_req_ack(1'b0),
  .sd_sec_read(request),.sd_sec_read_data(8'd0),.sd_sec_read_data_valid(valid),
  .sd_sec_read_end(ended),.read_stall(stall));
 task begin_scan;begin scan=1;@(negedge clk);scan=0;wait(request);@(negedge clk);end endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;begin_scan;
  // A long sector with regular progress must not time out.
  for(i=0;i<20;i=i+1)begin
   valid=1;@(negedge clk);valid=0;
   repeat(5)begin @(negedge clk);if(stall)errors=errors+1;end
  end
  wait(stall);@(negedge clk);abort_read=1;
  @(negedge clk);abort_read=0;@(negedge clk);
  if(!ready || request)errors=errors+1;
  begin_scan;ended=1;@(negedge clk);ended=0;
  repeat(25)begin @(negedge clk);if(stall)errors=errors+1;end
  if(!ready)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_bmp_stall: progress, missing data, abort and restart");
  else $display("FAILED tb_bmp_stall %0d",errors);
  $finish;
 end
 initial begin #10000;$display("FAILED watchdog tb_bmp_stall");$finish;end
endmodule
