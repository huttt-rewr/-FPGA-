`timescale 1ns/1ps
module tb_edid_timeout;
 reg clk=0,rst=1,start=0,valid=0;reg [7:0] data=0;
 wire done,good;integer errors=0,i;reg [7:0] checksum;
 always #5 clk=~clk;
 edid_base_check #(.STALL_TIMEOUT_CYCLES(16)) dut(clk,rst,start,valid,data,done,good);
 task restart;begin
  @(negedge clk);start=1;valid=0;@(negedge clk);start=0;
 end endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  valid=1;repeat(140)@(negedge clk);valid=0;
  if(done || good)errors=errors+1; // unsolicited bytes must not form a block
  restart;repeat(20)@(negedge clk);
  if(!done || good)errors=errors+1;
  restart;checksum=0;
  for(i=0;i<128;i=i+1)begin
   valid=1;
   if(i<8)data=(i==0 || i==7)?0:255;
   else if(i==127)data=-checksum;
   else data=0;
   checksum=checksum+data;
   @(negedge clk);valid=0;repeat(3)@(negedge clk);
  end
  if(!done || !good)errors=errors+1; // total duration > timeout, but progress is healthy
  restart;valid=1;data=0;@(negedge clk);valid=0;
  repeat(20)@(negedge clk);
  if(!done || good)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_edid_timeout: stray bytes, stall, progress and restart");
  else $display("FAILED tb_edid_timeout %0d",errors);
  $finish;
 end
 initial begin #20000;$display("FAILED watchdog tb_edid_timeout");$finish;end
endmodule
