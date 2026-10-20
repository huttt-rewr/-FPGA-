`timescale 1ns/1ps
// Three full frames using real FIFOs, variable-latency in-order SDRAM peer,
// periodic refresh and background writes. This is NOT a vendor PHY simulation.
module tb_memory_refresh;
 reg mc=0,pc=0,wc=0,rst=1,rr=0,wr=0,we=0;
 always #12.5 mc=~mc;
 initial begin #3;forever #12.5 pc=~pc;end
 always #5 wc=~wc;
 wire hs,vs,de,ra,wa,wfinish,rfinish,re,wen,ready,wo,ru,read_enable,display_de;
 wire [31:0] displayed;
 wire [20:0] raddr,waddr;wire [31:0] rdata,wdata;wire [3:0] dm;
 reg [31:0] wd=0;
 reg return_valid=0;
 reg [31:0] return_data=0;
 reg [31:0] queued_data[0:2047];
 integer due[0:2047];
 integer head=0,tail=0,cycle=0,period=0,refresh_count=0;
 reg refresh=0;
 integer read_count=0;
 wire [1:0] buffer_index=(read_count/480000)%2;
 wire request_frame,request_blank;
 video_timing_data #(.ADAPTIVE(1)) timing(.video_clk(pc),.rst(rst),
  .read_req(request_frame),.read_req_ack(ra),.hs(hs),.vs(vs),.de(de),
  .vblank(request_blank),.mode_800(1'b1));
 integer sent=0,written=0,errors=0,i,expected_addr;

 frame_read_write #(.ADAPTIVE(1),.BURST_SIZE(64)) dut(
  .write_rst(rst),.rst(rst),.mem_clk(mc),.Sdr_init_done(!rst),
  .Sdr_init_ref_vld(refresh),.Sdr_busy(refresh),.App_rd_en(re),.App_rd_addr(raddr),
  .Sdr_rd_en(return_valid),.Sdr_rd_dout(return_data),
  .read_clk(pc),.read_req(request_frame),.read_req_ack(ra),.read_finish(rfinish),
  .read_addr_0(21'd0),.read_addr_1(21'd480000),.read_addr_2(21'd0),.read_addr_3(21'd0),
  .read_addr_index(buffer_index),.read_len(21'd480000),.read_en(read_enable),.read_data(rdata),
  .App_wr_en(wen),.App_wr_addr(waddr),.App_wr_din(wdata),.App_wr_dm(dm),
  .write_clk(wc),.write_req(wr),.write_req_ack(wa),.write_finish(wfinish),
  .write_addr_0(21'd0),.write_addr_1(21'd480000),.write_addr_2(21'd0),.write_addr_3(21'd0),
  .write_addr_index(2'd1),.write_len(21'd64000),.write_en(we),.write_data(wd),
  .wr_overflow_sticky(wo),.rd_underflow_sticky(ru),.write_ready(ready),.mode_800(1'b1));
 video_delay #(.DATA_WIDTH(32)) delay(.video_clk(pc),.rst(rst),.hs(hs),.vs(vs),.de(de),
  .read_data(rdata),.read_en(read_enable),.hs_r(),.vs_r(),.de_r(display_de),.vout_data(displayed));
 always @(negedge mc) if(!rst)begin
  period=(period==1249)?0:period+1;
  refresh=(period>=500 && period<522);
  if(period==500)refresh_count=refresh_count+1;
 end
 always @(posedge mc)begin
  if(rst)begin return_valid<=0;head=0;tail=0;cycle=0;end
  else begin
   cycle=cycle+1;return_valid<=0;
   if(re)begin
    if(refresh || wen)begin $display("FAILED command during refresh/write");errors=errors+1;end
    queued_data[tail%2048]=raddr;due[tail%2048]=cycle+10+((raddr/64)%2)*7;tail=tail+1;
   end
   if(head<tail && cycle>=due[head%2048] && !refresh)begin
    return_valid<=1;return_data<=queued_data[head%2048];head=head+1;
   end
   if(wen)begin
    if(refresh || head<tail || return_valid)begin
     $display("FAILED write overlaps refresh or outstanding reads");errors=errors+1;
    end
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
  if(displayed!==((read_count%480000)+((read_count/480000)%2)*480000))begin
   if(errors<5)$display("FAILED SVGA starvation/data at %d actual=%d empty=%b used=%d outstanding=%d state=%d",read_count,displayed,dut.read_fifo_empty,dut.wrusedw,tail-head,dut.frame_fifo_read_m0.state);
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
  wait(wa);@(negedge mc);wr=0;
  wait(read_count==1440000);@(negedge pc);
  if(written!=64000 || wo || ru || refresh_count<100)begin errors=errors+1;$display("FAILED FIFO flags or incomplete background write %d %b %b",written,wo,ru);end
  if(errors==0)$display("ALL PASS tb_memory_refresh: 1440000 pixels, alternating frame addresses, 64000 background writes, periodic 22-cycle refresh and 10..17-cycle minimum return latency");
  else $display("FAILED tb_memory_refresh %d",errors);
  $finish;
 end
 initial begin #60000000;$display("FAILED watchdog tb_memory_refresh read=%d write=%d",read_count,written);$finish;end
endmodule
