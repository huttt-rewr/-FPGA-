`timescale 1ns/1ps
module tb_pixel_effects;
 reg clk=0,rst=1,vs=0,de=0;always #5 clk=~clk;
 reg [9:0] x=0;reg [23:0] rgb=0;reg [1:0] mode=0;
 wire ov,od;wire [23:0] color;
 pixel_effects dut(clk,rst,vs,de,x,rgb,mode,ov,od,color);
 integer errors=0,checks=0,i,j,k,xx,yy,f,w,seed=0,m;
 reg [23:0] q[0:2];reg [2:0] vq=0,dq=0;
 function [23:0] pix;input integer a,b,s;begin pix=(((a*31+b*19+s*47)&255)<<16)|(((a*7+b*29+s*53)&255)<<8)|((a*13+b*3+s*71)&255);end endfunction
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
