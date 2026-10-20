`timescale 1ns/1ps
module tb_frame_writer;
 reg clk=0,rst=1,req=0;always #5 clk=~clk;
 wire en,ack,finished;wire [20:0] addr;
 integer n=0,errors=0,expected;
 frame_fifo_write #(.BURST_SIZE(256),.FRAME_WIDTH(640),.FRAME_HEIGHT(480)) dut(
  .rst(rst),.mem_clk(clk),.Sdr_init_done(1'b1),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
  .App_rd_busy(1'b0),.App_wr_en(en),.App_wr_addr(addr),.write_req(req),.write_req_ack(ack),
  .write_finish(finished),.write_addr_0(21'd0),.write_addr_1(21'd307200),
  .write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd1),
  .write_len(21'd307200),.rdusedw(9'd511));
 always @(posedge clk)if(!rst && en)begin
  expected=307200+(479-n/640)*640+n%640;
  if(addr!==expected)errors=errors+1;
  n=n+1;
 end
 initial begin
  repeat(4)@(negedge clk);rst=0;req=1;wait(ack);@(negedge clk);req=0;
  wait(finished);@(negedge clk);
  if(n!=307200)errors=errors+1;
  // Reset a partially started transfer; a new request must be accepted.
  req=1;wait(ack);@(negedge clk);req=0;wait(en);@(negedge clk);rst=1;
  repeat(4)@(negedge clk);rst=0;n=0;req=1;wait(ack);@(negedge clk);req=0;
  repeat(30)@(negedge clk);
  if(n==0)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_frame_writer: 307200 flipped addresses and writer abort/restart");
  else $display("FAILED tb_frame_writer %0d count=%0d",errors,n);
  $finish;
 end
 initial begin #10000000;$display("FAILED watchdog tb_frame_writer");$finish;end
endmodule
