`timescale 1ns/1ps
module tb_spectrum_fft;
 reg clk=0,rst=1,valid=0;reg signed [15:0] sample=0;
 always #20 clk=~clk;
 wire bin_valid,done,busy;wire [7:0] bin_index;wire signed [15:0] re,im;
 spectrum_fft256 dut(clk,rst,valid,sample,bin_valid,bin_index,re,im,done,busy);
 reg [15:0] samples[0:2303];reg [31:0] expected[0:2303];
 integer block,n,seen=0,errors=0,difference,reference_re,reference_im,max_difference=0;
 always @(posedge clk)begin
  #1;
  if(!rst && bin_valid)begin
   if(bin_index!==seen[7:0])begin $display("FAILED bin ordering %d %d",bin_index,seen);$finish;end
   reference_re=$signed(expected[seen][31:16]);reference_im=$signed(expected[seen][15:0]);
   difference=$signed(re)-reference_re;if(difference<0)difference=-difference;
   if(difference>max_difference)max_difference=difference;
   if(difference>12)begin $display("FAILED real bin=%d rtl=%d DFT=%d",seen,re,reference_re);$finish;end
   difference=$signed(im)-reference_im;if(difference<0)difference=-difference;
   if(difference>max_difference)max_difference=difference;
   if(difference>12)begin $display("FAILED imag bin=%d rtl=%d DFT=%d",seen,im,reference_im);$finish;end
   seen=seen+1;
  end
 end
 initial begin
  $readmemh("../reports/music_spectrum_20261023/fft_samples.mem",samples);
  $readmemh("../reports/music_spectrum_20261023/fft_dft.mem",expected);
  repeat(5)@(negedge clk);rst=0;
  for(block=0;block<9;block=block+1)begin
   for(n=0;n<256;n=n+1)begin
    @(negedge clk);sample=samples[block*256+n];valid=1;
    @(negedge clk);valid=0;
    // Both realistic 48kHz/25MHz and accelerated cadence are exercised.
    if(block==4)repeat(519)@(negedge clk);else repeat(7)@(negedge clk);
   end
   wait(done);@(negedge clk);
   if(seen!=(block+1)*256)begin $display("FAILED incomplete spectrum %d",seen);$finish;end
  end
  $display("ALL PASS tb_spectrum_fft: 9 DFT cases, %0d bins, max error=%0d LSB",seen,max_difference);$finish;
 end
 initial begin #30000000;$display("FAILED tb_spectrum_fft timeout");$finish;end
endmodule
