`timescale 1ns/1ps
// Two complete records through the actual reader/scaler, including x>511/y>255.
module tb_av_native #(parameter VIDEO_FORMAT=2, parameter FAULT=0);
 localparam WIDTH=VIDEO_FORMAT==2?640:(VIDEO_FORMAT==1?320:160);
 localparam HEIGHT=VIDEO_FORMAT==2?480:(VIDEO_FORMAT==1?240:120);
 localparam RECORD=VIDEO_FORMAT==2?1204:(VIDEO_FORMAT==1?304:117);
 localparam SCALE=VIDEO_FORMAT==2?1:(VIDEO_FORMAT==1?2:4);
 reg clk=0,rst=1,valid=0,se=0,finish=0,ack=0;
 always #5 clk=~clk;
 reg [7:0] data=0;
 wire req,wr,we,publish,bank,awe,playing,error,ended,busy;
 wire [31:0] sector,wd;
 wire [1:0] wb,format;
 wire [10:0] aa;
 wire [15:0] ad;
 integer cycles=0,transport=0,pos=0,reads=0,pixels=0,samples=0,commits=0;
 integer frame,x,y,r,g,b,expected,commit_delay=0,stalls=0;
 reg last_publish=0,held=0;
 reg [23:0] held_pixel=0;
 wire ready=(cycles%17<12) && (cycles%8003<5000);
 sd_av_reader dut(.clk(clk),.rst(rst),.mode_800(1'b0),.toggle_play(1'b0),
  .sd_ready(1'b1),.sd_error(1'b0),.sector_read(req),.sector_address(sector),
  .sector_data(data),.sector_valid(valid),.sector_end(se),
  .write_req(wr),.write_req_ack(wr),.write_finish_toggle(finish),
  .write_en(we),.write_data(wd),.pixel_ready(ready),.write_bank(wb),
  .request_toggle(publish),.requested_bank(bank),.ack_toggle(ack),
  .audio_we(awe),.audio_address(aa),.audio_data(ad),.playing(playing),
  .error(error),.ended(ended),.busy(busy),.state_code(),.video_format(format));

 function [7:0] source_byte;
  input integer lba,index;
  integer offset,n,f,sx,sy,value;
  reg [15:0] packed_pixel;
  reg [63:0] magic;
  begin
   source_byte=0;
   if(lba==0)begin
    magic=64'h0030324b36315641;
    if(index<8)source_byte=magic>>(index*8);
    else if(index<12)source_byte=32'd2>>((index-8)*8);
    else if(index<16)begin
     value=((FAULT==3?HEIGHT-1:HEIGHT)<<16)|WIDTH;
     source_byte=value>>((index-12)*8);
    end else if(index<20)source_byte=32'h3e800014>>((index-16)*8);
    else if(index<24)begin
     value=FAULT==2?RECORD-1:RECORD;
     source_byte=value>>((index-20)*8);
    end else if(index<28)begin
     value=FAULT==1?3:VIDEO_FORMAT;
     source_byte=value>>((index-24)*8);
    end
   end else begin
    f=(lba-1)/RECORD;offset=(lba-1)%RECORD;
    if(offset<4)begin
     n=offset*512+index;
     if(n<1600)begin
      value=f*1000+n/2+1;
      source_byte=n%2?value>>8:value;
     end
    end else begin
     n=(offset-4)*512+index;
     if(VIDEO_FORMAT==0)begin
      sx=(n/3)%WIDTH;sy=(n/3)/WIDTH;
      if(n<WIDTH*HEIGHT*3)case(n%3)
       0:source_byte=sx;
       1:source_byte=sy;
       2:source_byte=sx+sy+f;
      endcase
     end else begin
      sx=(n/2)%WIDTH;sy=(n/2)/WIDTH;
      packed_pixel=(((sx+sy+f)%32)<<11)|(((sy+f)%64)<<5)|((sx+2*f)%32);
      source_byte=n%2?packed_pixel[15:8]:packed_pixel[7:0];
     end
    end
   end
  end
 endfunction

 always @(negedge clk)begin
  cycles=cycles+1;valid=0;se=0;
  if(rst)begin transport=0;pos=0;end
  else case(transport)
   0:if(req)begin
    if(sector!==reads)$fatal(1,"FAILED native sequential sector %d expected %d",sector,reads);
    reads=reads+1;pos=0;transport=1;
   end
   1:if(cycles%5!=0)begin
    valid=1;data=source_byte(sector,pos);pos=pos+1;
    if(pos==((sector==5 && FAULT==4)?100:((sector==5 && FAULT==5)?513:512)))begin
     se=1;transport=2;
    end
   end
   2:if(!req)transport=0;
  endcase
 end

 always @(posedge clk)if(!rst)begin
  if(held && (!dut.scaler.pixel_valid || dut.scaler.pixel!==held_pixel))
   $fatal(1,"FAILED native stalled output changed");
  held<=dut.scaler.pixel_valid && !ready;
  held_pixel<=dut.scaler.pixel;
  if(dut.scaler.pixel_valid && !ready)stalls=stalls+1;
  if(we)begin
   frame=pixels/307200;x=(pixels%640)/SCALE;y=((pixels%307200)/640)/SCALE;
   if(VIDEO_FORMAT==0)expected=(((x+y+frame)%256)<<16)|(y<<8)|x;
   else begin
    r=(x+y+frame)%32;g=(y+frame)%64;b=(x+2*frame)%32;
    expected=((r*8+r/4)<<16)|((g*4+g/16)<<8)|(b*8+b/4);
   end
   if(wd!=={expected[23:0],8'd0})
    $fatal(1,"FAILED native RGB pixel=%d x=%d y=%d got=%h expected=%h",pixels,x,y,wd,expected);
   if(wb!=={1'b0,frame[0]})$fatal(1,"FAILED native write bank");
   pixels=pixels+1;
   if(pixels%307200==0)finish<=~finish;
  end
  if(awe)begin
   expected=(samples/800)*1000+samples%800+1;
   if(ad!==expected[15:0] || aa!==((samples/800)%2)*1024+samples%800)
    $fatal(1,"FAILED native PCM/address sample=%d",samples);
   samples=samples+1;
  end
  if(publish!=last_publish)begin
   commits=commits+1;
   if(pixels!=commits*307200 || samples!=commits*800 || bank!==((commits-1)%2))
    $fatal(1,"FAILED native premature frame publication");
   last_publish=publish;commit_delay=31;
  end
  if(commit_delay>0)begin
   commit_delay=commit_delay-1;
   if(commit_delay==0)ack<=publish;
  end
 end

 initial begin
  repeat(8)@(negedge clk);rst=0;
  if(FAULT!=0)begin
   wait(error);repeat(8)@(negedge clk);
   if(pixels || commits || playing || publish)$fatal(1,"FAILED native bad record published pixels");
  end else begin
   wait(ended);repeat(8)@(negedge clk);
   if(error || busy || format!==VIDEO_FORMAT[1:0] || pixels!=614400 || samples!=1600 ||
      reads!=1+2*RECORD || commits!=2 || stalls==0)
    $fatal(1,"FAILED native final counts pixels=%d samples=%d reads=%d commits=%d",pixels,samples,reads,commits);
  end
  $display("ALL PASS tb_av_native format=%d fault=%d: exact RGB/PCM, sequential sectors, two banks, backpressure",VIDEO_FORMAT,FAULT);
  $finish;
 end
 initial begin #200000000;$fatal(1,"FAILED tb_av_native timeout");end
endmodule
