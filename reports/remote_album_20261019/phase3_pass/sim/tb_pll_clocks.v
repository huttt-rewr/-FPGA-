`timescale 1ns/1ps
module tb_pll_clocks;
 reg refclk=0, reset=1;
 always #10 refclk=~refclk;
 wire s0,s1,s2,v0,v1,sl,vl;
 sys_pll dut_s(refclk,reset,sl,s0,s1,s2);
 video_pll dut_v(refclk,reset,vl,v0,v1);
 integer a=0,b=0,c=0,d=0,e=0;
 realtime ta,tb,tc,td,te;
 always @(posedge s0) begin if(a>4 && ($realtime-ta<9.99 || $realtime-ta>10.01)) $fatal(1,"sys C0 period"); ta=$realtime; a=a+1; end
 always @(posedge s1) begin if(b>4 && ($realtime-tb<24.99 || $realtime-tb>25.01)) $fatal(1,"sys C1 period"); tb=$realtime; b=b+1; end
 always @(posedge s2) begin if(c>4 && ($realtime-tc<24.99 || $realtime-tc>25.01)) $fatal(1,"sys C2 period"); tc=$realtime; c=c+1; end
 always @(posedge v0) begin if(d>4 && ($realtime-td<39.99 || $realtime-td>40.01)) $fatal(1,"video C0 period"); td=$realtime; d=d+1; end
 always @(posedge v1) begin if(e>4 && ($realtime-te<7.99 || $realtime-te>8.01)) $fatal(1,"video C1 period"); te=$realtime; e=e+1; end
 initial begin #100 reset=0; #20000;
 if(a<100 || b<100 || c<100 || d<100 || e<100 || sl!==1 || vl!==1) $fatal(1,"PLL missing edges or lock");
 $display("ALL PASS tb_pll_clocks: 100/40/40 MHz and 25/125 MHz, both locked"); $finish; end
endmodule
