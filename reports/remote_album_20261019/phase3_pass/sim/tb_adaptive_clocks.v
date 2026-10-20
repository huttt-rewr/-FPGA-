`timescale 1ns/1ps
module tb_adaptive_clocks;
 reg refclk=0,reset=1,mode=0,checking=0;
 always #10 refclk=~refclk;
 wire locked,boot,pixel,serial;
 adaptive_video_clock dut(refclk,reset,mode,locked,boot,pixel,serial);
 realtime tp,ts,tb,period;integer np=0,ns=0,nb=0,errors=0;
 always @(posedge pixel)begin
  if(checking)begin
   period=mode?25.0:40.0;
   if(np>0 && (($realtime-tp)<period-0.02 || ($realtime-tp)>period+0.02))errors=errors+1;
   np=np+1;
  end
  tp=$realtime;
 end
 always @(posedge serial)begin
  if(checking)begin
   period=mode?5.0:8.0;
   if(ns>0 && (($realtime-ts)<period-0.02 || ($realtime-ts)>period+0.02))errors=errors+1;
   ns=ns+1;
  end
  ts=$realtime;
 end
 always @(posedge boot)begin
  if(nb>5 && (($realtime-tb)<39.98 || ($realtime-tb)>40.02))errors=errors+1;
  nb=nb+1;tb=$realtime;
 end
 initial begin
  #100;reset=0;#20000;
  if(locked!==1)errors=errors+1;
  checking=1;#20000;checking=0;
  if(np<400 || ns<2000)errors=errors+1;
  // Board controller holds consumers reset during the entire settling interval.
  mode=1;np=0;ns=0;#164000;checking=1;#20000;checking=0;
  if(np<700 || ns<3900 || locked!==1)errors=errors+1;
  mode=0;np=0;ns=0;#164000;checking=1;#20000;
  if(np<400 || ns<2000)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_adaptive_clocks: official PLL/mux models, VGA 25/125, SVGA 40/200, fixed boot clock, switch/reset settle");
  else $display("FAILED tb_adaptive_clocks %0d",errors);
  $finish;
 end
endmodule
