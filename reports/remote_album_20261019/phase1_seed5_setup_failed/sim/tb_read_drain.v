`timescale 1ns/1ps
// Long return latency, refresh pauses, and a NEW frame request during drain.
// There must be no FIFO clear / write ownership release while responses remain.
module tb_read_drain;
 reg clk=0,rst=1,req=0,refresh=0,busy=0;
 reg [1:0] buffer_index=0;
 wire ack,finish,re,owned,clear;
 wire [20:0] addr;
 reg [39:0] returns=0;
 integer issued=0,received=0,errors=0,base=100,frames=0;
 always #5 clk=~clk;
 frame_fifo_read #(.BURST_SIZE(64)) dut(.rst(rst),.mem_clk(clk),
  .Sdr_init_done(!rst),.Sdr_init_ref_vld(refresh),.Sdr_busy(busy),
  .Sdr_rd_en(returns[39]),.App_wr_busy(1'b0),.O_rd_busy(owned),
  .App_rd_en(re),.App_rd_addr(addr),.read_req(req),.read_req_ack(ack),
  .read_finish(finish),.read_addr_0(21'd100),.read_addr_1(21'd1000),
  .read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(buffer_index),
  .read_len(21'd64),.fifo_aclr(clear),.wrusedw(9'd0));
 always @(posedge clk)begin
  if(rst)returns<=0;
  else begin
   returns<={returns[38:0],re};
   if(re)begin
    if(refresh || addr!==base+issued)errors=errors+1;
    issued=issued+1;
   end
   if(returns[39])received=received+1;
   if((clear || !owned) && issued>received)begin
    if(errors<3)$display("FAILED released/cleared with %0d outstanding",issued-received);
    errors=errors+1;
   end
   if(finish && issued!=received)errors=errors+1;
  end
 end
 initial begin
  repeat(4)@(negedge clk);rst=0;busy=1;req=1;
  wait(ack);@(negedge clk);req=0;repeat(10)@(negedge clk);
  if(issued!=0)errors=errors+1;
  busy=0;wait(issued==15);@(negedge clk);refresh=1;
  repeat(23)@(negedge clk);refresh=0;
  wait(issued==64);@(negedge clk);buffer_index=1;req=1;
  wait(ack);@(negedge clk);
  if(received!=64)errors=errors+1;
  issued=0;received=0;base=1000;req=0;
  wait(finish);@(negedge clk);
  if(issued!=64 || received!=64)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_read_drain: 40-cycle returns, 23-cycle refresh, pending frame waits for all responses");
  else $display("FAILED tb_read_drain %0d",errors);
  $finish;
 end
 initial begin #100000;$display("FAILED watchdog tb_read_drain");$finish;end
endmodule
