`timescale 1ns/1ps
module tb_adaptive_raster;
 reg clk=0,rst=1,mode=0;always #5 clk=~clk;
 wire hs,vs,de;wire [9:0] x,y;
 integer m,t,width,height,total,hc,vc,pixels,lines,errors=0;
 adaptive_raster dut(clk,rst,mode,hs,vs,de);
 video_coordinates pos(clk,rst,vs,de,x,y);
 initial begin
  for(m=0;m<2;m=m+1)begin
   @(negedge clk);rst=1;mode=m;repeat(3)@(negedge clk);rst=0;
   width=m?800:640;height=m?600:480;total=(m?1056:800)*(m?628:525);pixels=0;lines=0;
   for(t=0;t<total;t=t+1)begin
    #1;
    hc=t%(m?1056:800);vc=t/(m?1056:800);
    if(hs!==(hc>=(m?128:96)) || vs!==(vc>=(m?4:2)))errors=errors+1;
    if(de)begin
     if(x!==pixels%width || y!==pixels/width)begin
      if(errors<5)$display("FAILED coords mode%d %d,%d expected%d,%d",m,x,y,pixels%width,pixels/width);
      errors=errors+1;
     end
     pixels=pixels+1;
    end
    @(negedge clk);
   end
   if(pixels!=width*height)begin errors=errors+1;$display("FAILED frame length %d",pixels);end
  end
  if(errors==0)$display("ALL PASS tb_adaptive_raster: complete VGA/SVGA frame periods, sync widths, coordinates and active pixel counts");
  else $display("FAILED tb_adaptive_raster %d",errors);
  $finish;
 end
endmodule
