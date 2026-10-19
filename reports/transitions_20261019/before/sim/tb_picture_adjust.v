`timescale 1ns/1ps
module tb_picture_adjust;
 reg clk=0,rst=1,vs=1,de=1;always #5 clk=~clk;
 reg [23:0] rgb=0;reg signed [7:0] b=0;reg [3:0] c=4;reg [9:0] x=0;
 wire ov,od;wire [9:0] ox;wire [23:0] result;
 integer i,j,k,v,errors=0,seen=0;
 reg [23:0] want0=0,want1=0;reg vd0=0,vd1=0,vv0=0,vv1=0;
 reg [9:0] xx0=0,xx1=0;
 picture_adjust dut(clk,rst,vs,de,x,rgb,b,c,ov,od,ox,result);
 function [7:0] refchannel;input integer n,bright,contrast;integer z;begin
  z=((n-128)*contrast+2)>>>2;z=z+128+bright;refchannel=z<0?0:(z>255?255:z);
 end endfunction
 always @(posedge clk)begin
  if(!rst)begin
   want1=want0;vd1=vd0;vv1=vv0;xx1=xx0;
   want0=de?{refchannel(rgb[23:16],b,c),refchannel(rgb[15:8],b,c),refchannel(rgb[7:0],b,c)}:24'd0;
   vd0=de;vv0=vs;xx0=x;
   #1;
   if(seen>0 && {result,ov,od,ox}!=={want1,vv1,vd1,xx1})begin
    if(errors<5)$display("FAILED adjust actual=%h expected=%h",result,want1);errors=errors+1;
   end
   seen=seen+1;
  end
 end
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(j=2;j<=8;j=j+1)for(k=-64;k<=64;k=k+8)for(i=0;i<256;i=i+1)begin
   c=j;b=k;rgb={i[7:0],8'd255-i[7:0],i[7:0]};x=i;de=i%9!=0;vs=i%11!=0;@(negedge clk);
  end
  repeat(4)@(negedge clk);
  if(errors==0)$display("ALL PASS tb_picture_adjust: all 256 intensities x17 brightness x7 contrast, clipping and RGB/VS/DE/X alignment");
  else $display("FAILED tb_picture_adjust %0d",errors);
  $finish;
 end
endmodule
