`timescale 1ns/1ps
// Compare the resource-saving formal profile against independent 8bit-line
// post-effect filtering. Neither path forces data or peeks at RAM contents.
module tb_shared_luma;
 reg clk=0,rst=1,vs=0,de=0,expanded=0;always #5 clk=~clk;
 reg [23:0] rgb=0;reg [1:0] mode=0;
 wire [9:0] rx,ry,x,y;wire fv,fd,rv,rd,sv,sd;wire [23:0] fr,ref_rgb,shared_rgb;
 wire [11:0] sum;wire [7:0] lum;wire good,sobel;
 video_coordinates raw(clk,rst,vs,de,rx,ry);
 pixel_effects #(.DEPTH(800)) p(clk,rst,vs,de,rx,rgb,mode,fv,fd,fr,sum,lum,good,sobel);
 viewport_coordinates logical(clk,rst,fv,fd,expanded,x,y,,);
 glass_osd reference_path(clk,rst,fv,fd,x,y,fr,8'd0,1'b1,rv,rd,ref_rgb,12'd0,8'd0,1'b0,1'b0);
 glass_osd #(.SHARED_LUMA(1)) shared_path(clk,rst,fv,fd,x,y,fr,8'd0,1'b1,sv,sd,shared_rgb,sum,lum,good,sobel);
 integer errors=0,active=0,f,xx,yy,k,w,h;
 always @(negedge clk)if(!rst)begin
  if(rd)active=active+1;
  if(rv!==sv || rd!==sd || ref_rgb!==shared_rgb)begin
   if(errors<8)$display("FAIL shared mode%0d raw%0d/%0d logical%0d/%0d independent%h shared%h",mode,rx,ry,x,y,ref_rgb,shared_rgb);
   errors=errors+1;
  end
 end
 task step;input vv,dd;input integer a,b,s;
 begin @(negedge clk);vs=vv;de=dd;rgb=(((a*17+b*3+s*39)&255)<<16)|(((a*7+b*29+s*13)&255)<<8)|((a*31+b*11+s*71)&255);end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(f=0;f<8;f=f+1)begin
   mode=f%4;expanded=f>=4;w=expanded?800:640;h=expanded?600:480;
   for(k=0;k<16;k=k+1)step(0,0,0,0,f);
   for(yy=0;yy<h;yy=yy+1)begin
    for(xx=0;xx<w;xx=xx+1)step(1,1,xx,yy,f);
    step(1,0,0,yy,f);
   end
  end
  repeat(20)step(1,0,0,0,0);
  if(active!=3148800)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_shared_luma: four modes VGA/SVGA 3148800 exact pixels, shared transformed-luma sums equal independent post-effect blur, binary Sobel history exact");
  else $display("FAILED shared errors%0d active%0d",errors,active);$finish;
 end
 initial begin #60000000;$display("FAILED shared watchdog");$finish;end
endmodule
