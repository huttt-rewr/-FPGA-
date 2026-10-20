`timescale 1ns/1ps
module tb_transition_pixels;
 reg clk=0,rst=1,vs=1,de=0;always #5 clk=~clk;
 reg [9:0] x=0;reg [23:0] rgb=0;
 reg [1:0] mode=0;reg [5:0] level=32;reg [9:0] offset=0;
 wire ov,od;wire [23:0] color;
 integer errors=0,received=0,xx,yy,step,kind,row=0;
 reg pv=0,pd=0;reg [23:0] expected_prev=0,current;
 integer c,src_x,value;
 transition_pixels dut(clk,rst,vs,de,x,rgb,{1'b0,mode},level,offset,ov,od,color,10'd0,1'b0);
 function [23:0] sample;input integer px,py;reg [7:0] r,g,b;begin
  r=px*7+py*31;g=px*3+py*59;b=px+py*97;sample={r,g,b};
 end endfunction
 always @(posedge clk)begin
  if(rst)begin pv=0;pd=0;expected_prev=0;end
  else begin
   current=0;
   if(de)begin
    src_x=x;
    if(mode==2)src_x=x-offset;
    if(src_x>=0)begin
     current=sample(src_x,row);
     if(mode==1)for(c=0;c<3;c=c+1)begin
      value=current[c*8+:8];current[c*8+:8]=(value*level)/32;
     end
    end
   end
   #1;
   if(ov!==pv || od!==pd || color!==expected_prev)begin
    if(errors<8)$display("FAIL pixel mode=%0d offset=%0d x=%0d got=%h want=%h",mode,offset,x,color,expected_prev);
    errors=errors+1;
   end
   if(od)received=received+1;
   pv=vs;pd=de;expected_prev=current;
  end
 end
 initial begin
  repeat(4)@(negedge clk);rst=0;
  // All 33 fade levels and all 33 slide positions; distinct successive rows catch stale RAM.
  for(kind=0;kind<3;kind=kind+1)begin
   mode=kind;
   for(step=0;step<=32;step=step+1)begin
    level=step;offset=step*20;
    for(yy=0;yy<2;yy=yy+1)begin
     row=row+1;
     for(xx=0;xx<640;xx=xx+1)begin
      de=1;x=xx;rgb=sample(xx,row);@(negedge clk);
     end
     de=0;repeat(5)@(negedge clk);
    end
   end
  end
  // VS is also delayed, independent of mode or covered image.
  vs=0;repeat(3)@(negedge clk);vs=1;repeat(4)@(negedge clk);
  if(received!=3*33*2*640)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_transition_pixels: exact RGB, 33 fade/slide steps, 640 pixels per line, stale-row exclusion");
  else $display("FAILED tb_transition_pixels %0d",errors);
  $finish;
 end
 initial begin #2000000;$display("FAILED watchdog tb_transition_pixels");$finish;end
endmodule
