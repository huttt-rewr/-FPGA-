`timescale 1ns/1ps
module tb_music_spectrum;
 reg clk=0,rst=1,vs=1,de=0,enable=0;reg [9:0] x=0,y=0;reg [23:0] rgb=0;
 reg audio_valid=0;reg signed [23:0] audio_left=0;
 wire out_vs,out_de;wire [23:0] out_rgb;
 always #20 clk=~clk;
 music_spectrum_overlay dut(clk,rst,vs,de,x,y,rgb,audio_valid,audio_left,enable,out_vs,out_de,out_rgb);
 reg pv,pd;reg [23:0] pr;reg checking=0;integer n,k;
 task check;input ok;input [511:0] message;begin if(ok!==1)begin $display("FAILED %s",message);$finish;end end endtask
 always @(posedge clk)begin
  #1;
  if(!rst && checking)begin
   check(out_vs===pv && out_de===pd,"two-cycle VS/DE alignment changed");
   check(out_rgb===(pd?pr:24'b0),"disabled overlay damaged pixels");
  end
  pv=vs;pd=de;pr=rgb;
 end
 task point;input [9:0] xx,yy;input [23:0] expected;begin
  @(negedge clk);x=xx;y=yy;de=1;rgb=24'h8090a0;
  repeat(2)@(negedge clk);
  if(out_rgb!==expected)$display("pixel (%0d,%0d) expected=%06x got=%06x height=%0d peak=%0d phase=%0d",xx,yy,expected,out_rgb,dut.height,dut.peak,dut.color_phase);
  check(out_rgb===expected,"pixel composition or RAM alignment wrong");
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;repeat(4)@(negedge clk);checking=1;
  // Full logical VGA and SVGA coordinate extents: no DE loss/extra latency.
  for(n=0;n<640*480+800;n=n+1)begin
   @(negedge clk);x=n%800;y=(n/800)%600;rgb=n*17821;de=(n%19)!=0;vs=n[10];
  end
  checking=0;rst=1;enable=1;de=0;vs=1;
  repeat(5)@(negedge clk);rst=0;repeat(40)@(negedge clk);vs=0;
  repeat(150)@(negedge clk);
  // Pixel renderer tested independently from numerics: known display RAM.
  for(k=0;k<32;k=k+1)dut.analyzer.levels[k]={7'd78,7'd80};
  point(64,320,24'hf04242);
  point(64,298,24'hfff4dc);
  point(78,320,24'h202428); // two-pixel gaps between adjacent bars
  point(64,376,24'h284858);
  point(20,320,24'h8090a0);
  point(64,270,24'h202428);
  // Freeze/enable changes only at frame boundaries.
  enable=0;point(64,320,24'hf04242);
  de=0;vs=1;repeat(2)@(negedge clk);vs=0;repeat(150)@(negedge clk);
  point(64,320,24'h8090a0);
  $display("ALL PASS tb_music_spectrum: two-cycle pipeline, disabled passthrough, colors/gaps/peaks, frame enable");$finish;
 end
 initial begin #20000000;$display("FAILED tb_music_spectrum timeout");$finish;end
endmodule
