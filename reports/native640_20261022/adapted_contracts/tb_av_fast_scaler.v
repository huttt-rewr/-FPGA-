`timescale 1ns/1ps
module tb_av_fast_scaler #(parameter HQ=0);
 reg clk=0,rst=1,start=0,valid=0,sector_end=0,ready=1,short_sector=0,long_sector=0;
 always #5 clk=~clk;
 wire read,pixel_valid,done,error,busy;
 wire [31:0] address;
 wire [23:0] pixel;
 reg [7:0] data=0;
 localparam BYTES=HQ?153600:57856;
 reg [7:0] disk[0:BYTES-1];
 integer i,x,y,cycle=0,transport=0,sector_pos=0,sector_base=0;
 integer pixels=0,reads=0,errors=0;
 reg [7:0] red,green,blue;reg [15:0] packed_pixel;
 reg held_valid=0;reg [23:0] held_pixel;
 av_fast_scaler dut(.clk(clk),.rst(rst),.start(start),.base_sector(32'd23),.video_format({1'b0,(HQ!=0)}),
  .sector_read(read),.sector_address(address),.sector_data(data),
  .sector_valid(valid),.sector_end(sector_end),.pixel(pixel),
  .pixel_valid(pixel_valid),.pixel_ready(ready),.done(done),.error(error),.busy(busy));

 always @(negedge clk)begin
  cycle=cycle+1;valid=0;sector_end=0;ready=(cycle%17<12 && cycle%5909<3909);
  if(rst)begin transport=0;sector_pos=0;end
  else case(transport)
   0:if(read)begin
    if(address!==23+reads)begin errors=errors+1;$display("FAILED sector address %d",address);end
    sector_base=(address-23)*512;sector_pos=0;reads=reads+1;transport=1;
   end
   1:if(cycle%5!=0)begin
    valid=1;data=disk[sector_base+sector_pos];sector_pos=sector_pos+1;
    if(sector_pos==(short_sector?100:(long_sector?513:512)))begin
     // Include the final byte on the same cycle as end-of-sector.
     sector_end=1;transport=3;
    end
   end
   2:begin sector_end=1;transport=3;end
   3:if(!read)transport=0;
  endcase
 end
 always @(posedge clk)begin
  if(!rst && held_valid && (!pixel_valid || pixel!==held_pixel))
   $fatal(1,"FAILED stalled pixel changed");
  held_valid<=!rst && pixel_valid && !ready;held_pixel<=pixel;
 end
 always @(posedge clk)if(pixel_valid && ready)begin
  y=(pixels/640)/(HQ?2:4);x=(pixels%640)/(HQ?2:4);
  red=x+y;green=y;blue=x;
  if(HQ)begin
   red=(((x+y)%32)<<3)|(((x+y)%32)>>2);
   green=((y%64)<<2)|((y%64)>>4);blue=((x%32)<<3)|((x%32)>>2);
  end
  if(pixels>=307200 || pixel!=={red,green,blue})begin
   if(errors<8)$display("FAILED pixel %0d got %h expected %h",pixels,pixel,{red,green,blue});
   errors=errors+1;
  end
  pixels=pixels+1;
 end
 initial begin
  for(i=0;i<BYTES;i=i+1)disk[i]=0;
  for(i=0;i<(HQ?76800:19200);i=i+1)begin
   x=i%(HQ?320:160);y=i/(HQ?320:160);
   if(HQ)begin
    packed_pixel=(((x+y)%32)<<11)|((y%64)<<5)|(x%32);
    disk[i*2]=packed_pixel[7:0];disk[i*2+1]=packed_pixel[15:8];
   end else begin disk[i*3]=x;disk[i*3+1]=y;disk[i*3+2]=x+y;end
  end
  repeat(5)@(negedge clk);rst=0;start=1;
  @(negedge clk);start=0;
  wait(done);#1;
  if(pixels!=307200 || reads!=(HQ?300:113) || busy || error)begin
   errors=errors+1;$display("FAILED complete pixels=%0d reads=%0d busy=%b error=%b",pixels,reads,busy,error);
  end
  repeat(5)@(negedge clk);rst=1;short_sector=1;
  repeat(5)@(negedge clk);rst=0;pixels=0;reads=0;start=1;
  @(negedge clk);start=0;
  wait(error);#1;
  if(done || pixels || reads!=1)begin
   errors=errors+1;$display("FAILED short sector published output");
  end
  repeat(5)@(negedge clk);rst=1;short_sector=0;long_sector=1;
  repeat(5)@(negedge clk);rst=0;pixels=0;reads=0;start=1;
  @(negedge clk);start=0;wait(error);#1;
  if(done || pixels || reads!=1)$fatal(1,"FAILED oversized sector published output");
  if(errors) $fatal(1,"FAILED tb_av_fast_scaler errors=%0d",errors);
  $display("ALL PASS tb_av_fast_scaler HQ=%d: 307200 pixels, sequential sectors, long backpressure, simultaneous final byte/end, short/oversized rejection",HQ);
  $finish;
 end
 initial begin #30000000;$fatal(1,"FAILED tb_av_fast_scaler timeout");end
endmodule
