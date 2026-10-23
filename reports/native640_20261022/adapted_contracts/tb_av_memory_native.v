`timescale 1ns/1ps
// Full VGA frame load through the fast scaler, real asynchronous FIFOs and
// frame controllers while an old frame is displayed. SDRAM is a six-cycle
// behavioural request/return peer; this does not validate vendor refresh/IP.
module tb_av_memory_native #(parameter HQ=1);
 reg wc=0,mc=0,pc=0,rst=1,wr=0,start=0;
 always #5 wc=~wc;
 always #12.5 mc=~mc;
 initial begin #3;forever #20 pc=~pc;end
 wire hs,vs,de,rr,ra,wa,wfinish,re,wen,ready,overflow,underflow,read_enable,display_de;
 wire [31:0] displayed,rdata,wdata,sector;
 wire [20:0] raddr,waddr;
 wire [23:0] pixel;
 wire fetch,pv,done,error;
 reg [7:0] data=0;reg dv=0,se=0;
 reg [5:0] valid_pipe=0;reg [31:0] data_pipe[0:5];
 integer i,cycle=0,transport=0,position=0,delay_count=0,reads=0,byte_index;
 integer written=0,display_count=0,stalls=0,expected_addr,red,green,blue,start_cycle;
 reg finished=0,scaled=0;
 integer sx,sy;reg [15:0] packed_pixel;
 video_timing_data #(.ADAPTIVE(1)) timing(.video_clk(pc),.rst(rst),.read_req(rr),
  .read_req_ack(ra),.hs(hs),.vs(vs),.de(de),.vblank(),.mode_800(1'b0));
 av_fast_scaler scaler(.clk(wc),.rst(rst),.start(start),.base_sector(32'd5),.video_format(2'd2),
  .sector_read(fetch),.sector_address(sector),.sector_data(data),.sector_valid(dv),
  .sector_end(se),.pixel(pixel),.pixel_valid(pv),.pixel_ready(ready),.done(done),.error(error),.busy());
 frame_read_write #(.ADAPTIVE(1),.BURST_SIZE(64)) memory(
  .write_rst(rst),.rst(rst),.mem_clk(mc),.Sdr_init_done(!rst),
  .Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),.App_rd_en(re),.App_rd_addr(raddr),
  .Sdr_rd_en(valid_pipe[5]),.Sdr_rd_dout(data_pipe[5]),
  .read_clk(pc),.read_req(rr),.read_req_ack(ra),.read_finish(),
  .read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd0),.read_addr_3(21'd0),
  .read_addr_index(2'd0),.read_len(21'd307200),.read_en(read_enable),.read_data(rdata),
  .App_wr_en(wen),.App_wr_addr(waddr),.App_wr_din(wdata),.App_wr_dm(),
  .write_clk(wc),.write_req(wr),.write_req_ack(wa),.write_finish(wfinish),
  .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd0),.write_addr_3(21'd0),
  .write_addr_index(2'd1),.write_len(21'd307200),.write_en(pv && ready),.write_data({pixel,8'd0}),
  .wr_overflow_sticky(overflow),.rd_underflow_sticky(underflow),.write_ready(ready),.mode_800(1'b0));
 video_delay #(.DATA_WIDTH(32)) delay(.video_clk(pc),.rst(rst),.hs(hs),.vs(vs),.de(de),
  .read_data(rdata),.read_en(read_enable),.hs_r(),.vs_r(),.de_r(display_de),.vout_data(displayed));
 always @(negedge wc)begin
  cycle=cycle+1;dv=0;se=0;
  if(rst)transport=0;
  else begin
   if(pv && !ready)stalls=stalls+1;
   if(done)scaled=1;
   if(error)$fatal(1,"FAILED scaler error");
   case(transport)
    0:if(fetch)begin
     if(sector!==reads+5)$fatal(1,"FAILED repeated/out-of-order sector");
     reads=reads+1;position=0;delay_count=100;transport=1;
    end
    1:if(delay_count>0)delay_count=delay_count-1;
      else begin
       byte_index=(sector-5)*512+position;
       if(HQ)begin
        sx=(byte_index/2)%640;sy=(byte_index/2)/640;
        packed_pixel=(((sx+sy)%32)<<11)|((sy%64)<<5)|(sx%32);
        data=byte_index%2?packed_pixel[15:8]:packed_pixel[7:0];
       end else case(byte_index%3)
        0:data=(byte_index/3)%160;
        1:data=(byte_index/3)/160;
        2:data=(byte_index/3)%160+(byte_index/3)/160;
       endcase
       dv=1;position=position+1;delay_count=HQ?3:39;
       if(position==512)transport=2;
      end
    2:begin se=1;transport=3;end
    3:if(!fetch)transport=0;
   endcase
  end
 end
 always @(posedge mc)begin
  if(rst)valid_pipe<=0;
  else begin
   valid_pipe<={valid_pipe[4:0],re};data_pipe[0]<=raddr;
   for(i=1;i<6;i=i+1)data_pipe[i]<=data_pipe[i-1];
   if(wen)begin
    expected_addr=307200+(479-written/640)*640+written%640;
    blue=(written%640)/4;green=(written/640)/4;red=blue+green;
    if(HQ)begin
     sx=(written%640);sy=(written/640);
     red=(((sx+sy)%32)<<3)|(((sx+sy)%32)>>2);
     green=((sy%64)<<2)|((sy%64)>>4);blue=((sx%32)<<3)|((sx%32)>>2);
    end
    if(waddr!==expected_addr || wdata!=={red[7:0],green[7:0],blue[7:0],8'd0})
     $fatal(1,"FAILED SDRAM write n=%d addr=%d data=%h",written,waddr,wdata);
    written=written+1;
   end
   if(wfinish)finished=1;
  end
 end
 always @(posedge pc)if(!rst && display_de)begin
  if(displayed!==display_count%307200)
   $fatal(1,"FAILED display starved n=%d got=%d",display_count,displayed);
  display_count=display_count+1;
 end
 initial begin
  repeat(8)@(negedge wc);rst=0;wr=1;
  wait(wa);@(negedge wc);wr=0;start=1;start_cycle=cycle;
  @(negedge wc);start=0;
  wait(finished);@(negedge mc);
  if(!scaled || written!=307200 || reads!=(HQ?1200:113) || overflow || underflow || display_count<307200)
   $fatal(1,"FAILED completion written=%d reads=%d display=%d flags=%b%b",written,reads,display_count,overflow,underflow);
  // 20 fps: reserve an entire 16.8 ms display refresh plus four audio sectors.
  if(cycle-start_cycle>3230000)$fatal(1,"FAILED VGA contention exceeds 20 fps load budget");
  $display("load_us=%0d stalled_cycles=%0d display_pixels=%0d",(cycle-start_cycle)/100,stalls,display_count);
  $display("ALL PASS tb_av_memory_native: 307200 exact flipped writes, simultaneous VGA display, 100/40/25 MHz clocks, actual FIFOs, bounded six-cycle SDRAM peer");
  $finish;
 end
 initial begin #50000000;$fatal(1,"FAILED tb_av_memory timeout");end
endmodule
