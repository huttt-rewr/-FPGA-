`timescale 1ns/1ps
module tb_music_preview;
 reg clk=0,rst=1,vs=1,de=0,enable=1;reg [9:0] x=0,y=0;reg [23:0] rgb=0;
 reg valid=0;reg signed [23:0] sample=0;wire ovs,ode;wire [23:0] orgb;
 music_spectrum_overlay dut(clk,rst,vs,de,x,y,rgb,valid,sample,enable,ovs,ode,orgb);
 always #20 clk=~clk;
 integer f=0,written=0,n=0,k,p,q;real value,phase;
 initial begin
  repeat(5)@(negedge clk);rst=0;
  forever begin
   value=0;
   // Synthetic harmonics, explicitly a simulated illustration, not board capture.
   for(k=1;k<=18;k=k+1)begin
    phase=6.283185307179586*(k*k/3+1)*n/256;
    value=value+8000.0/(k+1)*$sin(phase+k*0.37);
   end
   @(negedge clk);sample=$rtoi(value)*256;valid=1;n=n+1;
   @(negedge clk);valid=0;repeat(519)@(negedge clk);
  end
 end
 always @(posedge clk)begin
  #1;if(f && ode)begin
   $fwrite(f,"%c%c%c",orgb[23:16],orgb[15:8],orgb[7:0]);written=written+1;
  end
 end
 initial begin
  wait(!rst);wait(dut.analyzer.pending && dut.waveform.pending);
  @(negedge clk);vs=0;repeat(180)@(negedge clk);
  f=$fopen("../reports/music_spectrum_20261023/rtl_preview.ppm","wb");
  $fwrite(f,"P6\n640 480\n255\n");
  for(q=0;q<480;q=q+1)for(p=0;p<640;p=p+1)begin
   @(negedge clk);x=p;y=q;de=1;rgb={8'd12+p[9:3],8'd20+q[9:3],8'd48+p[9:4]};
  end
  @(negedge clk);de=0;repeat(3)@(negedge clk);
  $fclose(f);f=0;
  if(written!=307200)begin $display("FAILED preview pixel count %d",written);$finish;end
  $display("ALL PASS tb_music_preview: actual RTL spectrum/waveform, 307200 pixels");$finish;
 end
 initial begin #40000000;$display("FAILED preview timeout");$finish;end
endmodule
