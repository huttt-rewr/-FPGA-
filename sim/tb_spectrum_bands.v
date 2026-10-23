`timescale 1ns/1ps
module tb_spectrum_bands;
 reg clk=0,rst=1,frame=0,valid=0;reg signed [23:0] sample=0;reg [4:0] address=0;
 always #20 clk=~clk;
 wire [6:0] height,peak;
 spectrum_analyzer dut(clk,rst,frame,valid,sample,address,height,peak);
 integer i,k,max_height,max_band,before_height;real angle;
 task check;input ok;input [511:0] message;begin if(ok!==1)begin $display("FAILED %s",message);$finish;end end endtask
 task vblank;begin
  @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(140)@(negedge clk);
 end endtask
 task tone;input integer bin_number;input integer amplitude;begin
  wait(!dut.fft_busy && !dut.pending && dut.update_state==1);
  for(i=0;i<256;i=i+1)begin
   angle=6.283185307179586*bin_number*i/256;
   @(negedge clk);sample=$rtoi(amplitude*$sin(angle))*256;valid=1;
   @(negedge clk);valid=0;repeat(519)@(negedge clk);
  end
  wait(dut.pending);@(negedge clk);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;repeat(40)@(negedge clk);
  tone(8,24000);
  check(dut.levels[7]==0,"uncommitted FFT changed displayed envelope");
  vblank;
  max_height=0;max_band=0;
  for(k=0;k<32;k=k+1)begin
   address=k;repeat(2)@(negedge clk);
   if(height>max_height)begin max_height=height;max_band=k;end
  end
  check(max_band==7 && max_height>=72 && max_height<=96,"tone did not select its real frequency band");
  before_height=dut.levels[7]&127;
  tone(41,20000);
  check((dut.levels[7]&127)==before_height,"spectrum changed before vertical blank");
  vblank;
  check((dut.levels[23]&127)>=72,"upper bands did not aggregate bin 41");
  check((dut.levels[7]&127)==before_height-2,"bars must fall by two pixels/frame");
  // Stop PCM: stale targets must disappear rather than stick forever.
  repeat(65)vblank;
  for(k=0;k<32;k=k+1)check((dut.levels[k]&127)==0,"silence/no-samples did not decay to zero");
  $display("ALL PASS tb_spectrum_bands: real tones, grouped bands, vblank publish, decay, no-audio timeout");$finish;
 end
 initial begin #25000000;$display("FAILED tb_spectrum_bands timeout");$finish;end
endmodule
