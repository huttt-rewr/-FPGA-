`timescale 1ns/1ps
module tb_zh_overlay;
 reg clk=0,rst=1,vs=1,de=0,en=0,mode=0;always #5 clk=~clk;
 reg [23:0]rgb=0;wire [9:0]x,y,ox,oy;wire ov,od;wire [23:0]out_rgb;
 viewport_coordinates coords(clk,rst,vs,de,mode,x,y,,);
 zh_overlay dut(clk,rst,vs,de,x,y,rgb,en,ov,od,ox,oy,out_rgb);
 reg [15:0]gold[0:511];reg enabled=0,last_vs=1;reg [45:0]expected[0:1];
 reg [23:0]want;integer errors=0,pixels=0,lit=0,dimmed=0,bypassed=0,i,k,f,xx,yy,w,h,ci,ri,co;
 always @(posedge clk)begin
  if(rst)begin expected[0]=0;expected[1]=0;enabled=0;last_vs=1;end
  else begin
   want=rgb;
   if(enabled && x>=32 && x<32+dut.CHARS*16 && y>=384 && y<400)begin
    ci=(x-32)/16;ri=y-384;co=(x-32)%16;
    if(gold[ci*16+ri][15-co])begin want=24'hffe090;if(de)lit=lit+1;end
    else begin want={1'b0,rgb[23:17],1'b0,rgb[15:9],1'b0,rgb[7:1]};if(de)dimmed=dimmed+1;end
   end else if(de)bypassed=bypassed+1;
   expected[1]=expected[0];expected[0]={vs,de,x,y,de?want:24'd0};
   if(last_vs && !vs)enabled=en;last_vs=vs;
  end
  #1;
  if(!rst && {ov,od,ox,oy,out_rgb}!==expected[1])begin
   if(errors<6)$display("FAILED Chinese overlay x=%d y=%d got=%h want=%h",x,y,{ov,od,ox,oy,out_rgb},expected[1]);errors=errors+1;
  end
  if(od)pixels=pixels+1;
 end
 initial begin
  $readmemh("../src/modules/osd/zh_font.mem",gold);
  for(i=0;i<512;i=i+1)if((^gold[i])===1'bx)begin errors=errors+1;$display("FAILED uninitialized font %d",i);end
  for(i=dut.CHARS*16;i<512;i=i+1)if(gold[i]!==0)errors=errors+1;
  repeat(5)@(negedge clk);rst=0;
  for(f=0;f<4;f=f+1)begin
   mode=f[0];w=mode?800:640;h=mode?600:480;en=(f!=0);
   vs=0;repeat(16)@(negedge clk);vs=1;repeat(16)@(negedge clk);
   for(yy=0;yy<h;yy=yy+1)begin
    if(f==2 && yy==200)en=0;
    for(xx=0;xx<w;xx=xx+1)begin de=1;rgb={xx[7:0],yy[7:0],(xx[7:0]^yy[7:0])};@(negedge clk);end
    de=0;repeat(9)@(negedge clk);
   end
  end
  repeat(8)@(negedge clk);rst=1;repeat(4)@(negedge clk);
  if({ov,od,ox,oy,out_rgb}!==0)errors=errors+1;
  if(errors==0 && pixels==1574400 && lit>0 && dimmed>0 && bypassed>1000000)
   $display("ALL PASS tb_zh_overlay: four complete VGA/SVGA frames, font pixels/background, exact bypass, VS DE XY RGB latency, frame enable, unused glyphs, reset");
  else $display("FAILED tb_zh_overlay errors=%d pixels=%d lit=%d dimmed=%d",errors,pixels,lit,dimmed);$finish;
 end
 initial begin #30000000;$display("FAILED watchdog tb_zh_overlay");$finish;end
endmodule
