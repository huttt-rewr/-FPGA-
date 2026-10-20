`timescale 1ns/1ps
module tb_board_supervisor;
 reg clk=0,arst=1,en=0,hb=0;always #5 clk=~clk;
 wire reset;wire [7:0] count;
 integer i,errors=0;
 board_supervisor #(.POWER_CYCLES(10),.TIMEOUT_CYCLES(30)) dut(clk,arst,en,hb,reset,count);
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAILED supervisor %0s",msg);end
 end endtask
 initial begin
  repeat(3)@(negedge clk);check(reset && count==0,"raw reset");arst=0;
  repeat(9)@(negedge clk);check(reset,"full power delay");
  @(negedge clk);check(!reset,"release after delay");
  repeat(60)@(negedge clk);check(!reset && count==0,"not armed while EDID pending");
  en=1;
  for(i=0;i<12;i=i+1)begin hb=~hb;repeat(10)@(negedge clk);check(!reset,"healthy video heartbeat");end
  // A static picture still produces VS heartbeats; actual stall stops them.
  wait(reset);@(negedge clk);check(count==1,"timeout counted");en=0;
  repeat(10)@(negedge clk);check(!reset,"watchdog hold releases, no self-reset latch");
  repeat(35)@(negedge clk);check(count==1 && !reset,"not repeatedly resetting before re-enable");
  en=1;wait(reset);@(negedge clk);check(count==2,"second stall counted");
  arst=1;#1;check(reset && count==0,"PLL loss/user reset asserts immediately");
  @(negedge clk);en=0;arst=0;repeat(10)@(negedge clk);check(!reset,"relock starts fresh delay");
  if(errors==0)$display("ALL PASS tb_board_supervisor: power delay, arming, healthy feed, stalled video reset, no feedback deadlock, relock");
  else $display("FAILED tb_board_supervisor %0d",errors);
  $finish;
 end
 initial begin #100000;$display("FAILED watchdog supervisor test");$finish;end
endmodule
