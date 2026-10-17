from pathlib import Path
R=Path(__file__).resolve().parents[2]
pixel=r'''`timescale 1ns/1ps
module tb_pixel_effects;
 reg clk=0,rst=1,vs=0,de=0;always #5 clk=~clk;
 reg [9:0] x=0;reg [23:0] rgb=0;reg [1:0] mode=0;
 wire ov,od;wire [23:0] color;
 pixel_effects dut(clk,rst,vs,de,x,rgb,mode,ov,od,color);
 integer errors=0,checks=0,i,j,k,xx,yy,f,w,seed=0,m;
 reg [23:0] q[0:2];reg [2:0] vq=0,dq=0;
 function [23:0] pix;input integer a,b,s;begin pix={((a*31+b*19+s*47)&255),((a*7+b*29+s*53)&255),((a*13+b*3+s*71)&255)};end endfunction
 function integer luma;input integer a,b,s;reg [23:0] p;begin p=pix(a,b,s);luma=(77*p[23:16]+150*p[15:8]+29*p[7:0])>>8;end endfunction
 function [23:0] golden;input integer a,b,s,md;reg [23:0] p;integer g,gx,gy,z,rr,gg,bb;
 begin p=pix(a,b,s);g=luma(a,b,s);
 case(md)
  0:golden=p;1:golden=~p;
  2:begin
   gx=luma(a,b-2,s)+2*luma(a,b-1,s)+g-luma(a-2,b-2,s)-2*luma(a-2,b-1,s)-luma(a-2,b,s);
   gy=luma(a-2,b,s)+2*luma(a-1,b,s)+g-luma(a-2,b-2,s)-2*luma(a-1,b-2,s)-luma(a,b-2,s);
   if(gx<0)gx=-gx;if(gy<0)gy=-gy;
   golden=(a>=2 && b>=2 && gx+gy>80)?24'hffffff:24'd0;
  end
  3:begin
   rr=0;gg=0;bb=0;
   if(g<64)begin gg=g*4;bb=255;end
   else if(g<128)begin gg=255;bb=255-(g-64)*4;end
   else if(g<192)begin rr=(g-128)*4;gg=255;end
   else begin rr=255;gg=255-(g-192)*4;end
   golden={rr[7:0],gg[7:0],bb[7:0]};
  end
 endcase end endfunction
 task step;input vv,dd;input integer a,b,s,md;
 begin
  @(negedge clk);vs=vv;de=dd;x=a;rgb=pix(a,b,s);
  for(j=2;j>0;j=j-1)q[j]=q[j-1];q[0]=dd?golden(a,b,s,md):24'd0;
  vq={vq[1:0],vv};dq={dq[1:0],dd};
  @(posedge clk);#1;checks=checks+1;
  if(ov!==vq[2] || od!==dq[2] || color!==q[2])begin
   if(errors<8)$display("FAIL pixel a=%0d b=%0d mode=%0d got=%h expected=%h vs/de=%b%b",a,b,md,color,q[2],ov,od);errors=errors+1;
  end
 end endtask
 initial begin
  for(i=0;i<3;i=i+1)q[i]=0;
  repeat(3)@(negedge clk);rst=0;
  for(f=0;f<8;f=f+1)begin
   m=f%4;mode=m;w=(f<4)?640:800;
   for(k=0;k<6;k=k+1)step(0,0,0,0,f,m);
   for(yy=0;yy<8;yy=yy+1)begin
    for(xx=0;xx<w;xx=xx+1)step(1,1,xx,yy,f,m);
    // one blank cycle is sufficient; poison blank RGB must not affect window.
    step(1,0,0,yy,99,m);
   end
  end
  for(k=0;k<6;k=k+1)step(1,0,0,0,0,0);
  if(errors==0)$display("ALL PASS tb_pixel_effects: %0d cycles, exact four modes, VGA/SVGA widths, poisoned blanking, repeated-frame boundaries and three-stage alignment",checks);
  else $display("FAILED pixel errors=%0d",errors);$finish;
 end
 initial begin #10000000;$display("FAILED pixel watchdog");$finish;end
endmodule
'''
# Explicit width avoids Verilog's indefinite-width concatenation of integers.
pixel=pixel.replace('pix={((a*31+b*19+s*47)&255),((a*7+b*29+s*53)&255),((a*13+b*3+s*71)&255)};', 'pix=(((a*31+b*19+s*47)&255)<<16)|(((a*7+b*29+s*53)&255)<<8)|((a*13+b*3+s*71)&255);')
(R/'sim/tb_pixel_effects.v').write_text(pixel,encoding='utf-8')
glass=r'''`timescale 1ns/1ps
module tb_glass_osd;
 reg clk=0,rst=1,vs=0,de=0,en=0;always #5 clk=~clk;
 reg [9:0] x=0,y=0;reg [23:0] rgb=0;reg [7:0] letter="A";
 wire ov,od;wire [23:0] color;
 glass_osd dut(clk,rst,vs,de,x,y,rgb,letter,en,ov,od,color);
 integer errors=0,checks=0,i,j,k,xx,yy,f,w,h,active=0;
 reg [23:0] q[0:5];reg [5:0] vq=0,dq=0;
 function [23:0] pix;input integer a,b,s;begin pix=(((a*17+b*3+s*39)&255)<<16)|(((a*7+b*29+s*13)&255)<<8)|((a*31+b*11+s*71)&255);end endfunction
 function integer luma;input integer a,b,s;reg [23:0] p;begin p=pix(a,b,s);luma=(77*p[23:16]+150*p[15:8]+29*p[7:0])>>8;end endfunction
 function integer glyph;input integer row,col;
 integer bits;begin
  case(row)0:bits=14;1,2,4,5,6:bits=17;3:bits=31;default:bits=0;endcase
  glyph=(col>=0 && col<5)?((bits>>(4-col))&1):0;
 end endfunction
 function integer channel;input integer c,g,a;integer v,d;begin v=c+a-g;if(v<0)v=0;if(v>255)v=255;d=v*153/256;channel=(d*153+c*103)/256;end endfunction
 function [23:0] golden;
 input integer a,b,s,exp,enb;reg [23:0] p,z;integer lx,ly,sum,u,v,avg,g,rr,gg,bb,lit,shade;
 begin
  lx=exp?(a*4/5):a;ly=exp?(b*4/5):b;p=pix(a,b,s);z=p;
  if(enb && lx>=120 && lx<520 && ly>=80 && ly<400)begin
   if(a>=2 && b>=2)begin
    sum=0;for(u=-2;u<=0;u=u+1)for(v=-2;v<=0;v=v+1)sum=sum+luma(a+u,b+v,s);
    avg=sum/9;g=luma(a,b,s);rr=channel(p[23:16],g,avg);gg=channel(p[15:8],g,avg);bb=channel(p[7:0],g,avg);z={rr[7:0],gg[7:0],bb[7:0]};
   end
   lit=(lx>=136 && lx<504 && ly>=96 && ly<110)?glyph((ly-96)/2,(lx-136)%8):0;
   shade=(lx>=138 && lx<506 && ly>=98 && ly<112)?glyph((ly-98)/2,(lx-138)%8):0;
   if(lit)z=24'hffffff;
   else if(shade)z={1'b0,z[23:17],1'b0,z[15:9],1'b0,z[7:1]};
  end
  golden=z;
 end endfunction
 task step;input vv,dd;input integer a,b,s,expanded,enabled;
 begin
  @(negedge clk);vs=vv;de=dd;x=expanded?(a*4/5):a;y=expanded?(b*4/5):b;rgb=pix(a,b,s);
  for(j=5;j>0;j=j-1)q[j]=q[j-1];q[0]=dd?golden(a,b,s,expanded,enabled):24'd0;
  vq={vq[4:0],vv};dq={dq[4:0],dd};
  @(posedge clk);#1;checks=checks+1;if(od)active=active+1;
  if(ov!==vq[5] || od!==dq[5] || color!==q[5])begin
   if(errors<8)$display("FAIL glass a=%0d b=%0d f=%0d got=%h expected=%h",a,b,s,color,q[5]);errors=errors+1;
  end
 end endtask
 initial begin
  for(i=0;i<6;i=i+1)q[i]=0;
  // Confirm reciprocal has no rounding errors anywhere in the nine-pixel sum.
  for(i=0;i<=2295;i=i+1)if(((i*7282)>>16)!=i/9)errors=errors+1;
  repeat(3)@(negedge clk);rst=0;
  for(f=0;f<3;f=f+1)begin
   en=(f!=2);w=(f==1)?800:640;h=(f==1)?600:480;
   for(k=0;k<8;k=k+1)step(0,0,0,0,f,f==1,en);
   for(yy=0;yy<h;yy=yy+1)begin
    for(xx=0;xx<w;xx=xx+1)step(1,1,xx,yy,f,f==1,en);
    // Once latched, enable changes must not split this frame.
    if(yy==200)en=!en;
    step(1,0,0,yy,99,f==1,f!=2);
   end
  end
  for(k=0;k<8;k=k+1)step(1,0,0,0,0,0,0);
  if(errors==0)$display("ALL PASS tb_glass_osd: %0d active pixels, exact nine-tap luma/chroma/saturation/alpha, A glyph/shadow, VGA/SVGA, fixed six stages, disabled/frame-locked control",active);
  else $display("FAILED glass errors=%0d",errors);$finish;
 end
 initial begin #30000000;$display("FAILED glass watchdog");$finish;end
endmodule
'''
(R/'sim/tb_glass_osd.v').write_text(glass,encoding='utf-8')
audio=r'''`timescale 1ns/1ps
module tb_audio_visualizer;
 reg clk=0,rst=1,vs=1,de=0,en=1,av=0;always #5 clk=~clk;
 reg [9:0] x=0,y=0;reg [23:0] rgb=24'h204060;reg signed [23:0] pcm=0;
 wire ov,od;wire [23:0] color;
 audio_visualizer #(.WIN_X(4),.WIN_Y(4),.WIN_W(16),.WIN_H(20),.N(8)) dut(clk,rst,vs,de,x,y,rgb,av,pcm,en,ov,od,color);
 integer errors=0,checks=0,i,j,xx,yy,n,shot=0;
 reg [23:0] q[0:1];reg [1:0] vq=3,dq=0;
 integer samples[0:7];integer visible=0;
 function [23:0] golden;input integer a,b;integer col,v,amp,sy;reg [23:0] p;begin
  p=rgb;
  if(visible && a>=4 && a<20 && b>=4 && b<24)begin
   col=(a-4)/2;v=samples[col];amp=(v<0)?-v:v;sy=(v<0)?14+(amp*8/128):14-(amp*8/128);
   if(b==sy || b==sy+1)p=24'h10a078;
   else if(b==14)p=24'h084048;
   else p=24'h102030;
  end
  golden=p;
 end endfunction
 task step;input vv,dd;input integer a,b;
 begin
  @(negedge clk);vs=vv;de=dd;x=a;y=b;
  q[1]=q[0];q[0]=dd?golden(a,b):24'd0;vq={vq[0],vv};dq={dq[0],dd};
  @(posedge clk);#1;checks=checks+1;
  if(ov!==vq[1] || od!==dq[1] || color!==q[1])begin
   if(errors<8)$display("FAIL waveform a=%0d b=%0d got=%h want=%h",a,b,color,q[1]);errors=errors+1;
  end
 end endtask
 task send;input integer s;begin av=1;pcm=s*65536;step(1,0,0,0);av=0;step(1,0,0,0);end endtask
 task frame;begin
  for(j=0;j<5;j=j+1)step(0,0,0,0);
  for(yy=0;yy<28;yy=yy+1)begin
   for(xx=0;xx<24;xx=xx+1)step(1,1,xx,yy);
   step(1,0,0,yy);
  end
 end endtask
 initial begin
  q[0]=0;q[1]=0;vq=0;
  repeat(3)@(negedge clk);rst=0;
  // Fill beyond N, including -128 (which must not overflow abs()) and signs.
  for(i=0;i<16;i=i+1)send((i-12)*16);
  for(i=0;i<8;i=i+1)samples[i]=(i-4)*16;
  visible=1;
  for(j=0;j<5;j=j+1)step(0,0,0,0);
  for(yy=0;yy<28;yy=yy+1)begin
   // Update the other bank during raster: frozen display must be unchanged.
   av=1;pcm=-24'sd8388608;
   for(xx=0;xx<24;xx=xx+1)step(1,1,xx,yy);
   av=0;step(1,0,0,yy);
  end
  for(i=0;i<8;i=i+1)samples[i]=-128;
  frame;
  en=0;visible=0;frame;
  repeat(4)step(1,0,0,0);
  if(errors==0)$display("ALL PASS tb_audio_visualizer: signed extremes, circular order, two pixels/sample, frozen frame despite live audio, enabled/disabled pass and two-stage alignment");
  else $display("FAILED waveform errors=%0d",errors);$finish;
 end
 initial begin #2000000;$display("FAILED waveform watchdog");$finish;end
endmodule
'''
(R/'sim/tb_audio_visualizer.v').write_text(audio,encoding='utf-8')
pipeline=r'''`timescale 1ns/1ps
module tb_visual_pipeline;
 reg clk=0,rst=1,vs=0,de=0,expanded=0,en=0;always #5 clk=~clk;
 reg [23:0] rgb=0;wire [9:0] rx,ry,gx,gy,ax,ay;
 wire fv,fd,gv,gd,av,ad;wire [23:0] fr,gr,ar;
 video_coordinates c0(clk,rst,vs,de,rx,ry);
 pixel_effects p(clk,rst,vs,de,rx,rgb,2'd0,fv,fd,fr);
 viewport_coordinates c1(clk,rst,fv,fd,expanded,gx,gy,,);
 glass_osd g(clk,rst,fv,fd,gx,gy,fr,8'd0,en,gv,gd,gr);
 viewport_coordinates c2(clk,rst,gv,gd,expanded,ax,ay,,);
 audio_visualizer a(clk,rst,gv,gd,ax,ay,gr,1'b0,24'sd0,en,av,ad,ar);
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
'''
(R/'sim/tb_visual_pipeline.v').write_text(pipeline,encoding='utf-8')
print('Wrote four independent golden/streaming regressions')
