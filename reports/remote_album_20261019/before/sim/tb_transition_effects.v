`timescale 1ns/1ps
// Independent geometric oracle through the REAL six-register adjust/gamma/effect chain.
module tb_transition_effects;
 reg clk=0,rst=1,vs=1,de=0,svga=0;
 always #5 clk=~clk;
 reg [9:0] x=0,y=0,offset=0;
 reg [23:0] rgb=0;
 reg [2:0] effect=0;
 reg [5:0] level=32;
 wire av,ad,gv,gd,ov,od;
 wire [9:0] ax,ay,gx,gy;
 wire [23:0] ar,gr,result;
 picture_adjust adjust(clk,rst,vs,de,x,rgb,8'sd0,4'd4,av,ad,ax,ar,y,ay);
 picture_gamma gamma(clk,rst,av,ad,ax,ar,1'b0,gv,gd,gx,gr,ay,gy);
 transition_pixels dut(clk,rst,gv,gd,gx,gr,effect,level,offset,ov,od,result,gy,svga);
 reg [25:0] expected[0:5];
 reg [19:0] coord[0:3];
 reg [23:0] want;
 integer errors=0,seen=0,i,m,k,p,a,b,w,h,cx,cy,r,dd,progress,local_x;
 reg covered;
 always @(posedge clk)begin
  if(rst)begin
   for(i=0;i<6;i=i+1)expected[i]=0;
   for(i=0;i<4;i=i+1)coord[i]=0;
  end else begin
   cx=svga?400:320;cy=svga?300:240;
   r=((svga?500:400)*level)/32;
   dd=(x-cx)*(x-cx)+(y-cy)*(y-cy);
   progress=32-level;local_x=x%32;
   covered=0;
   case(effect)
    3:covered=x<offset;
    4:covered=(level==0)||((level!=32)&&(dd>r*r));
    5:begin
     // Even tiles fill first; then odd tiles. Thresholds use plain integer math.
     if(((x/32+y/32)%2)==0)covered=local_x<2*progress;
     else covered=local_x<2*(progress-16);
    end
   endcase
   want=(de && !covered)?rgb:24'd0;
   for(i=5;i>0;i=i-1)expected[i]=expected[i-1];
   expected[0]={vs,de,want};
   for(i=3;i>0;i=i-1)coord[i]=coord[i-1];
   coord[0]={x,y};
   #1;
   if({ov,od,result}!==expected[5] || {ax,ay}!==coord[1] || {gx,gy}!==coord[3])begin
    if(errors<10)$display("FAILED mask/pipeline mode=%d level=%d xy=%d,%d got=%h want=%h",effect,level,x,y,{ov,od,result},expected[5]);
    errors=errors+1;
   end
   if(od)seen=seen+1;
  end
 end
 task drain;begin de=0;repeat(9)@(negedge clk);end endtask
 task pixel;input integer xx,yy;begin
  x=xx;y=yy;rgb={xx[7:0]^8'h81,yy[7:0]^8'h42,(xx[7:0]+yy[7:0])|8'h01};de=1;
  @(negedge clk);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(m=0;m<2;m=m+1)begin
   svga=m;w=m?800:640;h=m?600:480;
   for(k=3;k<=5;k=k+1)begin
    drain;effect=k;
    for(p=0;p<=32;p=p+1)begin
     drain;level=32-p;offset=p*(m?25:20);
     // Corners, center, tile edges, both sides of wipe and circular boundaries.
     pixel(0,0);pixel(w-1,0);pixel(0,h-1);pixel(w-1,h-1);
     pixel(w/2,h/2);pixel(31,31);pixel(32,31);pixel(31,32);pixel(32,32);
     if(offset>0 && offset<w)begin pixel(offset-1,h/2);pixel(offset,h/2);end
     b=((m?500:400)*(32-p))/32;
     if(w/2+b<w)begin pixel(w/2+b,h/2);if(w/2+b+1<w)pixel(w/2+b+1,h/2);end
     if(h/2+b<h)begin pixel(w/2,h/2+b);if(h/2+b+1<h)pixel(w/2,h/2+b+1);end
     for(a=0;a<w;a=a+17)for(b=0;b<h;b=b+29)pixel(a,b);
     // Blanking and VS edges through the same pipeline at each coverage level.
     de=0;vs=0;@(negedge clk);vs=1;drain;
    end
    // Exhaustive full frame at both endpoints: catches the center-pixel leak.
    for(p=0;p<2;p=p+1)begin
     drain;level=p?0:32;offset=p?w:0;
     for(b=0;b<h;b=b+1)begin
      for(a=0;a<w;a=a+1)pixel(a,b);
      de=0;@(negedge clk);
     end
    end
   end
  end
  drain;rst=1;repeat(3)@(negedge clk);
  if({ov,od,result,ax,ay,gx,gy}!==0)errors=errors+1;
  rst=0;drain;
  if(errors==0 && seen>4500000)$display("ALL PASS tb_transition_effects: VGA/SVGA all 33 levels, mask boundaries, exact endpoint frames, RGB/VS/DE/XY alignment, reset");
  else $display("FAILED tb_transition_effects errors=%d seen=%d",errors,seen);
  $finish;
 end
 initial begin #70000000;$display("FAILED watchdog tb_transition_effects");$finish;end
endmodule
