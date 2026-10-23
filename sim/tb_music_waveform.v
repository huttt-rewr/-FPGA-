`timescale 1ns/1ps
module tb_music_waveform;
 reg clk=0,rst=1,frame=0,valid=0;reg signed [23:0] sample=0;reg [7:0] address=0;
 always #20 clk=~clk;
 wire [5:0] a,b;wire known;
 music_wave_capture dut(clk,rst,frame,valid,sample,address,a,b,known);
 integer n,k,have_positive=0,have_negative=0;reg bank_before;real angle;
 task check;input ok;input [511:0] message;begin if(ok!==1)begin $display("FAILED %s",message);$finish;end end endtask
 task feed;input integer value;begin
  @(negedge clk);sample=value*65536;valid=1;
  @(negedge clk);valid=0;repeat(7)@(negedge clk);
 end endtask
 task vblank;begin @(negedge clk);frame=1;@(negedge clk);frame=0;end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  for(n=0;n<400;n=n+1)begin
   angle=6.283185307179586*(n-12)/64;feed($rtoi(120*$sin(angle)));
  end
  check(dut.pending && !known,"triggered capture must wait for vertical blank");
  bank_before=dut.frame_bank;
  repeat(30)feed(127);
  check(dut.frame_bank==bank_before,"displayed waveform bank changed inside frame");
  vblank;repeat(3)@(negedge clk);
  check(known,"completed waveform not published");
  for(k=0;k<256;k=k+1)begin
   address=k;repeat(2)@(negedge clk);
   check(a>=8 && a<=56 && b>=8 && b<=56,"signed waveform escaped its panel");
   if(b>38)have_negative=1;if(b<26)have_positive=1;
  end
  check(have_positive && have_negative,"waveform lost bipolar amplitude");
  repeat(9)vblank;repeat(2)@(negedge clk);check(!known,"stale waveform did not expire");
  // Reset and feed DC: timeout capture must work without a zero crossing.
  rst=1;@(negedge clk);rst=0;
  repeat(1290)feed(32);
  check(dut.pending,"DC waveform timeout did not complete capture");
  vblank;repeat(2)@(negedge clk);check(known,"DC waveform not published");
  $display("ALL PASS tb_music_waveform: trigger, filtering, polarity, bank freeze, timeout/DC");$finish;
 end
 initial begin #5000000;$display("FAILED tb_music_waveform timeout");$finish;end
endmodule
