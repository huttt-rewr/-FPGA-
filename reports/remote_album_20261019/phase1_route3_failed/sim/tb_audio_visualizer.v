`timescale 1ns/1ps
module tb_audio_visualizer;
 reg clk=0,rst=1,vs=0,de=0,en=1,av=0;always #5 clk=~clk;
 reg [9:0] x=0,y=0;reg [23:0] rgb=24'h204060;reg signed [23:0] pcm=0;
 wire ov,od;wire [23:0] color;
 audio_visualizer #(.WIN_X(4),.WIN_Y(4),.WIN_W(16),.WIN_H(20),.N(8)) dut(clk,rst,vs,de,x,y,rgb,av,pcm,en,ov,od,color);
 integer errors=0,checks=0,i,j,xx,yy,n,shot=0;
 reg [23:0] q[0:1];reg [1:0] vq=3,dq=0;
 integer samples[0:7];integer visible=0;
 function [23:0] golden;input integer a,b;integer col,v,amp,sy;reg [23:0] p;begin
  p=rgb;
  if(visible && a>=4 && a<20 && b>=4 && b<24)begin
   col=(a-4)/2;v=samples[col];amp=(v<0)?-v:v;sy=(v<0)?14+(amp*8/128):14-(amp*8/128);
   if(b==sy || b==sy+1)p=24'h10a078;
   else if(b==14)p=24'h084048;
   else p=24'h102030;
  end
  golden=p;
 end endfunction
 task step;input vv,dd;input integer a,b;
 begin
  @(negedge clk);vs=vv;de=dd;x=a;y=b;
  q[1]=q[0];q[0]=dd?golden(a,b):24'd0;vq={vq[0],vv};dq={dq[0],dd};
  @(posedge clk);#1;checks=checks+1;
  if(ov!==vq[1] || od!==dq[1] || color!==q[1])begin
   if(errors<8)$display("FAIL waveform a=%0d b=%0d got=%h want=%h",a,b,color,q[1]);errors=errors+1;
  end
 end endtask
 task send;input integer s;begin av=1;pcm=s*65536;step(1,0,0,0);av=0;step(1,0,0,0);end endtask
 task frame;begin
  for(j=0;j<5;j=j+1)step(0,0,0,0);
  for(yy=0;yy<28;yy=yy+1)begin
   for(xx=0;xx<24;xx=xx+1)step(1,1,xx,yy);
   step(1,0,0,yy);
  end
 end endtask
 initial begin
  q[0]=0;q[1]=0;vq=0;
  repeat(3)@(negedge clk);rst=0;
  // Fill beyond N, including -128 (which must not overflow abs()) and signs.
  for(i=0;i<16;i=i+1)send((i-12)*16);
  for(i=0;i<8;i=i+1)samples[i]=(i-4)*16;
  visible=1;
  for(j=0;j<5;j=j+1)step(0,0,0,0);
  for(yy=0;yy<28;yy=yy+1)begin
   // Update the other bank during raster: frozen display must be unchanged.
   av=1;pcm=-24'sd8388608;
   for(xx=0;xx<24;xx=xx+1)step(1,1,xx,yy);
   av=0;step(1,0,0,yy);
  end
  for(i=0;i<8;i=i+1)samples[i]=-128;
  frame;
  en=0;visible=0;frame;
  repeat(4)step(1,0,0,0);
  if(errors==0)$display("ALL PASS tb_audio_visualizer: signed extremes, circular order, two pixels/sample, frozen frame despite live audio, enabled/disabled pass and two-stage alignment");
  else $display("FAILED waveform errors=%0d",errors);$finish;
 end
 initial begin #2000000;$display("FAILED waveform watchdog");$finish;end
endmodule
