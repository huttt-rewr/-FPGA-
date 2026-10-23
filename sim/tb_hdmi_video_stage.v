`timescale 1ns/1ps
module tb_hdmi_video_stage;
 reg clk=0,rst=0,vs=1,de=0;
 reg [23:0] rgb=0;
 wire out_vs,out_de;
 wire [23:0] out_rgb;
 reg [25:0] expected;
 integer errors=0,checks=0,n;
 always #5 clk=~clk;
 hdmi_video_stage dut(clk,rst,vs,de,rgb,out_vs,out_de,out_rgb);
 always @(posedge clk or posedge rst)begin
  expected=rst?{1'b1,1'b0,24'd0}:{vs,de,rgb};
  #1;
  if({out_vs,out_de,out_rgb}!==expected)begin
   errors=errors+1;
   if(errors<5)$display("FAILED HDMI bundle actual=%h expected=%h",{out_vs,out_de,out_rgb},expected);
  end
  checks=checks+1;
 end
 initial begin
  #2;rst=1;repeat(3)@(negedge clk);rst=0;
  for(n=0;n<50000;n=n+1)begin
   @(negedge clk);
   {vs,de,rgb}={$random};
   if(n==123 || n==24001)begin #2;rst=1;end
   if(n==126 || n==24004)rst=0;
  end
  @(negedge clk);
  if(errors==0 && checks>50000)
   $display("ALL PASS tb_hdmi_video_stage: RGB/VS/DE one-cycle alignment, back-to-back pixels, blanking and async reset");
  else $display("FAILED tb_hdmi_video_stage errors=%0d checks=%0d",errors,checks);
  $finish;
 end
endmodule
