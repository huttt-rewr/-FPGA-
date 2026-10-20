`timescale 1ns/1ps
// Playback controller with transport/writer peers. Never fake a video-domain ack.
module tb_commit_timeout;
 reg clk=0,rst=1,ack=0,next_cmd=0,peer_ready=1,found=0,scanned=0,wrfin=0;
 wire busy,error,valid,commit;wire [1:0] active;
 integer errors=0;
 always #5 clk=~clk;
 sd_card_bmp #(.CLK_FREQ_HZ(20)) dut(
  .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(1'b1),.cmd_next(next_cmd),
  .cmd_prev(1'b0),.cmd_toggle(1'b0),.commit_ack_toggle(ack),.commit_req_toggle(commit),
  .status_busy(busy),.status_error(error),.display_valid(valid),.disp_buf_idx(active),
  .bmp_width(16'd640),.bmp_height(16'd480),.write_finish_toggle(wrfin),
  .write_req_ack(1'b0),.SD_MISO(1'b1));
 initial begin
  force dut.sd_init_done=1'b1;force dut.sd_init_error=1'b0;
  force dut.sd_transfer_error=1'b0;force dut.read_stall=1'b0;
  force dut.bmp_ready=peer_ready;force dut.scan_found_valid=found;
  force dut.scan_found_sector=32'd0;force dut.scan_done=scanned;
  repeat(4)@(negedge clk);rst=0;
  wait(dut.scan_start_pulse);@(negedge clk);found=1;
  @(negedge clk);found=0;scanned=1;
  wait(busy);@(negedge clk);peer_ready=0;
  repeat(3)@(negedge clk);peer_ready=1;wrfin=1;
  wait(commit);wait(error);@(negedge clk);
  if(!busy || valid || !dut.commit_wait || dut.load_abort)errors=errors+1;
  next_cmd=1;@(negedge clk);next_cmd=0;
  repeat(30)begin
   @(negedge clk);
   if(!busy || valid || !commit || dut.load_start_pulse)errors=errors+1;
  end
  ack=1;wait(!busy);@(negedge clk);
  if(!valid || error || active!=0 || dut.commit_wait)errors=errors+1;
  // The queued command may start only after the true acknowledgement.
  wait(busy);@(negedge clk);
  if(dut.write_buf_idx!=1)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_commit_timeout: no fabricated commit, buffers protected, late ack accepted");
  else $display("FAILED tb_commit_timeout %0d",errors);
  $finish;
 end
 initial begin #20000;$display("FAILED watchdog tb_commit_timeout");$finish;end
endmodule
