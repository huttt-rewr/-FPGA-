`timescale 1ns/1ps
module tb_visual_pipeline;
 reg clk=0,rst=1,vs=0,de=0,expanded=0,en=0;always #5 clk=~clk;
 reg [23:0] rgb=0;wire [9:0] rx,ry,gx,gy,ax,ay;
 wire fv,fd,gv,gd,av,ad;wire [23:0] fr,gr,ar;
 video_coordinates c0(clk,rst,vs,de,rx,ry);
 wire [11:0] lsum;wire [7:0] lum;wire good,sobel;
 pixel_effects #(.BRAM_WINDOW(1)) p(clk,rst,vs,de,rx,rgb,2'd0,fv,fd,fr,lsum,lum,good,sobel);
 viewport_coordinates c1(clk,rst,fv,fd,expanded,gx,gy,,);
 glass_osd #(.SHARED_LUMA(1)) g(clk,rst,fv,fd,gx,gy,fr,8'd0,en,gv,gd,gr,lsum,lum,good,sobel);
 viewport_coordinates c2(clk,rst,gv,gd,expanded,ax,ay,,);
 audio_visualizer #(.BRAM_HISTORY(1)) a(clk,rst,gv,gd,ax,ay,gr,1'b0,24'sd0,en,av,ad,ar);
 integer errors=0,i,j,k,f,xx,yy,w,h,active=0;
 reg [23:0] q[0:10];reg [10:0] vq=0,dq=0;
 task step;input vv,dd;input integer x,y;
 begin
  @(negedge clk);vs=vv;de=dd;rgb=((x&255)<<16)|((y&255)<<8)|((x+y)&255);
  for(j=10;j>0;j=j-1)q[j]=q[j-1];q[0]=dd?rgb:0;vq={vq[9:0],vv};dq={dq[9:0],dd};
  @(posedge clk);#1;
  if(ad)active=active+1;
  if(av!==vq[10] || ad!==dq[10] || ar!==q[10])begin
   if(errors<8)$display("FAIL visual chain x%0d y%0d got%h expected%h",x,y,ar,q[10]);errors=errors+1;
  end
 end endtask
 initial begin
  for(i=0;i<11;i=i+1)q[i]=0;
  repeat(3)@(negedge clk);rst=0;
  for(f=0;f<2;f=f+1)begin
   expanded=f;w=f?800:640;h=f?600:480;
   for(k=0;k<16;k=k+1)step(0,0,0,0);
   for(yy=0;yy<h;yy=yy+1)begin
    for(xx=0;xx<w;xx=xx+1)step(1,1,xx,yy);
    for(k=0;k<4;k=k+1)step(1,0,0,yy);
   end
  end
  repeat(16)step(1,0,0,0);
  if(active!=787200)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_visual_pipeline: full VGA+SVGA 787200 exact pixels, reconstructed per-stage coordinates, fixed 11 stages no missing/extra pixels");
  else $display("FAILED visual chain errors%0d active%0d",errors,active);$finish;
 end
 initial begin #30000000;$display("FAILED chain watchdog");$finish;end
endmodule
