`timescale 1ns/1ps
module tb_caption_pipeline;
 reg clk=0,rst=1,vs=1,de=0,enable=1,scroll=1,mode800=0;
 reg [23:0] rgb=0;reg [1:0] slogan=0,mode=0;
 always #5 clk=~clk;
 wire av,ad,bv,bd;wire [23:0] a,b;
 caption_overlay #(.ADAPTIVE(1),.CLK_HZ(1000)) reference(
 clk,rst,vs,de,rgb,enable,scroll,slogan,mode,av,ad,a,mode800);
 caption_overlay #(.ADAPTIVE(1),.PIPELINED(1),.CLK_HZ(1000)) piped(
 clk,rst,vs,de,rgb,enable,scroll,slogan,mode,bv,bd,b,mode800);
 reg [25:0] d0=0,d1=0;integer errors=0,checked=0,f,x,y,w,h;
 always @(posedge clk)begin
  if(rst)begin d0<=0;d1<=0;end
  else begin d0<={av,ad,a};d1<=d0;end
  #1;
  if(!rst)begin
   if({bv,bd,b}!==d1)begin
    if(errors<5)$display("FAIL caption pipeline got=%h want=%h",{bv,bd,b},d1);
    errors=errors+1;
   end
   if(bd)checked=checked+1;
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=0;
  for(f=0;f<4;f=f+1)begin
   mode800=f[0];w=mode800?800:640;h=mode800?600:480;
   slogan=f%3;mode=f;enable=(f!=2);scroll=(f!=3);
   vs=0;repeat(16)@(negedge clk);vs=1;repeat(16)@(negedge clk);
   for(y=0;y<h;y=y+1)begin
    for(x=0;x<w;x=x+1)begin
     de=1;rgb={x[7:0],y[7:0],(x[7:0]^y[7:0])};@(negedge clk);
    end
    de=0;repeat(20)@(negedge clk);
   end
   repeat(30)@(negedge clk);
  end
  if(checked!=1574400)begin errors=errors+1;$display("FAIL caption active count %d",checked);end
  if(errors==0)$display("ALL PASS tb_caption_pipeline: four VGA/SVGA frames, exact font/tint/RGB and VS DE latency, slogans/disable/scroll");
  else $display("FAILED caption pipeline %d",errors);
  $finish;
 end
 initial begin #30000000;$display("FAILED caption pipeline watchdog");$finish;end
endmodule
