`timescale 1ns/1ps
module tb_bram_waveform;
 reg clk=0,rst=1,vs=0,de=0,en=1,av=0;
 reg [9:0] x=0,y=0;reg [23:0] rgb=0;reg signed [23:0] pcm=0;
 wire va,da,vb,db;wire [23:0] a,b;
 integer errors=0,checks=0,f,row,col,i,width,height;
 always #5 clk=~clk;
 audio_visualizer reference(clk,rst,vs,de,x,y,rgb,av,pcm,en,va,da,a);
 audio_visualizer #(.BRAM_HISTORY(1)) candidate(clk,rst,vs,de,x,y,rgb,av,pcm,en,vb,db,b);
 always @(posedge clk)begin
  #1;
  if(!rst)begin
   checks=checks+1;
   if({va,da,a}!=={vb,db,b})begin
    errors=errors+1;if(errors<8)$display("FAILED waveform equivalence frame=%0d x=%0d y=%0d old=%h new=%h",f,x,y,a,b);
   end
  end
 end
 initial begin
  repeat(4)@(negedge clk);rst=0;
  // Visit every signed 8-bit PCM value, including -128 and both polarities.
  for(i=0;i<512;i=i+1)begin av=1;pcm=(i%256-128)*65536;@(negedge clk);end
  av=0;
  for(f=0;f<6;f=f+1)begin
   width=(f%2)?800:640;height=(f%2)?600:480;
   en=(f!=3);vs=0;de=0;repeat(8)@(negedge clk);vs=1;
   for(row=0;row<height;row=row+1)begin
    for(col=0;col<width;col=col+1)begin
     x=col;y=row;de=1;rgb={$random};
     av=(col%71==0);pcm={$random};@(negedge clk);
    end
    de=0;av=0;repeat(3)@(negedge clk);
   end
   if(f==4)begin rst=1;repeat(4)@(negedge clk);rst=0;end
  end
  de=0;repeat(5)@(negedge clk);
  if(errors==0)$display("ALL PASS tb_bram_waveform: %0d cycles, exact VGA/SVGA frames, signed PCM, frame bank swap, enable/reset and two-stage alignment",checks);
  else $display("FAILED waveform equivalence errors=%0d",errors);
  $finish;
 end
 initial begin #30000000;$display("FAILED waveform equivalence watchdog");$finish;end
endmodule
