`timescale 1ns/1ps
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
    for(xx=0;xx<w;xx=xx+1)step(1,1,xx,yy,f,f==1,f!=2);
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
