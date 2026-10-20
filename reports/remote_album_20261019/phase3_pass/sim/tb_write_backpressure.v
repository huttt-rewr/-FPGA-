`timescale 1ns/1ps
// Stall the real writer until the FIFO approaches capacity, then verify every
// accepted word after draining. Repeat with a new frame and FIFO clear.
module tb_write_backpressure;
 reg wc=0,mc=0,rst=1,request=0,feed=0;
 always #5 wc=~wc;
 always #12.5 mc=~mc;
 wire ready,ack,finish,wen,overflow,underflow;
 wire [20:0] addr;
 wire [31:0] data;
 integer sent=0,received=0,errors=0,round=0,stalls=0;
 wire we=feed && ready && sent<700;
 wire [31:0] source_word=round*10000+sent;
 frame_read_write #(.WRITE_V_FLIP(0),.BURST_SIZE(64)) dut(
  .write_rst(rst),.rst(rst),.mem_clk(mc),.Sdr_init_done(!rst),
  .Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
  .App_rd_en(),.App_rd_addr(),.Sdr_rd_en(1'b0),.Sdr_rd_dout(32'd0),
  .read_clk(mc),.read_req(1'b0),.read_req_ack(),.read_finish(),
  .read_addr_0(21'd0),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),
  .read_addr_index(2'd0),.read_len(21'd0),.read_en(1'b0),.read_data(),
  .App_wr_en(wen),.App_wr_addr(addr),.App_wr_din(data),.App_wr_dm(),
  .write_clk(wc),.write_req(request),.write_req_ack(ack),.write_finish(finish),
  .write_addr_0(21'd123),.write_addr_1(21'd0),.write_addr_2(21'd0),.write_addr_3(21'd0),
  .write_addr_index(2'd0),.write_len(21'd700),.write_en(we),.write_data(source_word),
  .wr_overflow_sticky(overflow),.rd_underflow_sticky(underflow),.write_ready(ready),.mode_800(1'b0));
 always @(posedge wc)begin
  if(!rst)begin
   if(we)sent<=sent+1;
   if(feed && !ready)stalls<=stalls+1;
   if((dut.writer_clear[2] || request) && ready)begin
    $display("FAILED ready during FIFO clear/request");errors=errors+1;
   end
  end
 end
 always @(posedge mc)if(!rst && wen)begin
  if(data!==round*10000+received || addr!==123+received)begin
   if(errors<5)$display("FAILED word %d: addr=%d data=%d",received,addr,data);
   errors=errors+1;
  end
  received=received+1;
 end
 initial begin
  repeat(6)@(negedge wc);rst=0;
  for(round=0;round<2;round=round+1)begin
   sent=0;received=0;stalls=0;
   // Hold read ownership at the arbitration boundary so no writes can drain.
   force dut.App_rd_busy=1'b1;
   @(negedge wc);request=1;feed=1;
   wait(ack);@(negedge wc);request=0;
   repeat(800)@(negedge wc);
   if(sent==0 || sent>=511 || ready || overflow || stalls==0)begin
    $display("FAILED backpressure sent=%d ready=%b overflow=%b stalls=%d",sent,ready,overflow,stalls);
    errors=errors+1;
   end
   release dut.App_rd_busy;
   wait(finish);@(negedge wc);feed=0;
   if(sent!=700 || received!=700 || overflow)begin
    $display("FAILED count sent=%d received=%d",sent,received);errors=errors+1;
   end
   repeat(10)@(negedge wc);
  end
  if(errors==0)$display("ALL PASS tb_write_backpressure: full-rate producer, near-full stall, 1400 exact words, frame clear/restart");
  else $display("FAILED tb_write_backpressure %d",errors);
  $finish;
 end
 initial begin #200000;$display("FAILED watchdog tb_write_backpressure");$finish;end
endmodule
