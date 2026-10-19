`timescale 1ns/1ps
// Actual frame controllers + actual async FIFO RTL. The encrypted SDRAM is
// represented by a bounded six-cycle request/return model, not vendor signoff.
module tb_svga_memory;
 reg mc=0,pc=0,wc=0,rst=1,rr=0,wr=0,we=0;
 always #12.5 mc=~mc;
 initial begin #3;forever #12.5 pc=~pc;end
 always #5 wc=~wc;
 wire hs,vs,de,ra,wa,wfinish,rfinish,re,wen,ready,wo,ru,read_enable,display_de;
 wire [31:0] displayed;
 wire [20:0] raddr,waddr;wire [31:0] rdata,wdata;wire [3:0] dm;
 reg [31:0] wd=0;
 reg [5:0] valid_pipe=0;
 reg [31:0] data_pipe[0:5];
 integer sent=0,read_count=0,written=0,errors=0,i,expected_addr;
 adaptive_raster raster(pc,rst,1'b1,hs,vs,de);
 frame_read_write #(.ADAPTIVE(1),.BURST_SIZE(64)) dut(
  .write_rst(rst),.rst(rst),.mem_clk(mc),.Sdr_init_done(!rst),
  .Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),.App_rd_en(re),.App_rd_addr(raddr),
  .Sdr_rd_en(valid_pipe[5]),.Sdr_rd_dout(data_pipe[5]),
  .read_clk(pc),.read_req(rr),.read_req_ack(ra),.read_finish(rfinish),
  .read_addr_0(21'd0),.read_addr_1(21'd480000),.read_addr_2(21'd0),.read_addr_3(21'd0),
  .read_addr_index(2'd0),.read_len(21'd480000),.read_en(read_enable),.read_data(rdata),
  .App_wr_en(wen),.App_wr_addr(waddr),.App_wr_din(wdata),.App_wr_dm(dm),
  .write_clk(wc),.write_req(wr),.write_req_ack(wa),.write_finish(wfinish),
  .write_addr_0(21'd0),.write_addr_1(21'd480000),.write_addr_2(21'd0),.write_addr_3(21'd0),
  .write_addr_index(2'd1),.write_len(21'd64000),.write_en(we),.write_data(wd),
  .wr_overflow_sticky(wo),.rd_underflow_sticky(ru),.write_ready(ready),.mode_800(1'b1));
 video_delay #(.DATA_WIDTH(32)) delay(.video_clk(pc),.rst(rst),.hs(hs),.vs(vs),.de(de),
  .read_data(rdata),.read_en(read_enable),.hs_r(),.vs_r(),.de_r(display_de),.vout_data(displayed));
 always @(posedge mc)begin
  if(rst)valid_pipe<=0;
  else begin
   valid_pipe<={valid_pipe[4:0],re};data_pipe[0]<=raddr;
   for(i=1;i<6;i=i+1)data_pipe[i]<=data_pipe[i-1];
   if(wen)begin
    expected_addr=480000+(599-written/800)*800+written%800;
    if(waddr!==expected_addr || wdata!==written)begin
     if(errors<5)$display("FAILED write address/data n=%d addr=%d data=%d",written,waddr,wdata);
     errors=errors+1;
    end
    written=written+1;
   end
  end
 end
 always @(posedge pc)if(!rst && display_de)begin
  if(displayed!==read_count)begin
   if(errors<5)$display("FAILED SVGA starvation/data at %d actual=%d empty=%b",read_count,displayed,dut.read_fifo_empty);
   errors=errors+1;
  end
  read_count=read_count+1;
 end
 always @(negedge wc)begin
  we=0;
  if(!rst && ready && sent<64000)begin we=1;wd=sent;sent=sent+1;end
 end
 initial begin
  repeat(8)@(negedge mc);rst=0;rr=1;wr=1;
  wait(ra && wa);@(negedge mc);rr=0;wr=0;
  wait(read_count==480000);@(negedge pc);
  if(written!=64000 || wo || ru)begin errors=errors+1;$display("FAILED FIFO flags or incomplete background write %d %b %b",written,wo,ru);end
  if(errors==0)$display("ALL PASS tb_svga_memory: 480000 continuous display reads plus 64000 background writes, flipped addresses, bounded six-cycle SDRAM model");
  else $display("FAILED tb_svga_memory %d",errors);
  $finish;
 end
 initial begin #20000000;$display("FAILED watchdog tb_svga_memory read=%d write=%d",read_count,written);$finish;end
endmodule
