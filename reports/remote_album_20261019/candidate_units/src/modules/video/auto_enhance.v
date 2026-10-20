// Previous-frame per-channel automatic levels. Four fully registered stages.
// Empty frames retain coefficients. Constant channels and the first frame bypass.
module auto_enhance(
 input clk,input rst,input vs,input de,input [9:0] x,y,input [23:0] rgb,input enable,
 output reg out_vs,output reg out_de,output reg [9:0] out_x,out_y,output reg [23:0] out_rgb);
 reg vs_d,seen,coeff_valid,frame_enable;
 wire frame_start=vs_d && !vs;
 reg [7:0] rmin,rmax,gmin,gmax,bmin,bmax;
 wire [7:0] rr=rmax-rmin,gr=gmax-gmin,br=bmax-bmin;
 wire [15:0] rs,gs,bs;
 auto_enhance_scale rscale(rr,rs),gscale(gr,gs),bscale(br,bs);
 reg [15:0] sR,sG,sB;
 reg [7:0] oR,oG,oB;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   vs_d<=1;seen<=0;coeff_valid<=0;frame_enable<=0;
   rmin<=255;rmax<=0;gmin<=255;gmax<=0;bmin<=255;bmax<=0;
   sR<=0;sG<=0;sB<=0;oR<=0;oG<=0;oB<=0;
  end else begin
   vs_d<=vs;
   if(frame_start)begin
    frame_enable<=enable;
    if(seen)begin sR<=rs;sG<=gs;sB<=bs;oR<=rmin;oG<=gmin;oB<=bmin;coeff_valid<=1;end
    // A legal coincident first pixel must belong to the new frame.
    seen<=de;
    rmin<=de?rgb[23:16]:8'd255;rmax<=de?rgb[23:16]:8'd0;
    gmin<=de?rgb[15:8]:8'd255;gmax<=de?rgb[15:8]:8'd0;
    bmin<=de?rgb[7:0]:8'd255;bmax<=de?rgb[7:0]:8'd0;
   end else if(de && vs)begin
    seen<=1;
    if(rgb[23:16]<rmin)rmin<=rgb[23:16];if(rgb[23:16]>rmax)rmax<=rgb[23:16];
    if(rgb[15:8]<gmin)gmin<=rgb[15:8];if(rgb[15:8]>gmax)gmax<=rgb[15:8];
    if(rgb[7:0]<bmin)bmin<=rgb[7:0];if(rgb[7:0]>bmax)bmax<=rgb[7:0];
   end
  end
 end
 reg v1,d1,v2,d2,v3,d3,en1,en2,en3;
 reg [9:0] x1,y1,x2,y2,x3,y3;
 reg [23:0] rgb1,rgb2,rgb3;
 reg [7:0] deltaR,deltaG,deltaB;
 reg [15:0] scaleR1,scaleG1,scaleB1;
 reg [23:0] productR,productG,productB;
 reg [2:0] bypass1,bypass2,bypass3;
 function [7:0] saturate;
  input [23:0] value;reg [24:0] rounded;
  begin rounded={1'b0,value}+25'd128;saturate=(rounded[24:8]>255)?8'd255:rounded[15:8];end
 endfunction
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   v1<=0;d1<=0;v2<=0;d2<=0;v3<=0;d3<=0;en1<=0;en2<=0;en3<=0;
   x1<=0;y1<=0;x2<=0;y2<=0;x3<=0;y3<=0;rgb1<=0;rgb2<=0;rgb3<=0;
   deltaR<=0;deltaG<=0;deltaB<=0;scaleR1<=0;scaleG1<=0;scaleB1<=0;
   productR<=0;productG<=0;productB<=0;bypass1<=0;bypass2<=0;bypass3<=0;
   out_vs<=0;out_de<=0;out_x<=0;out_y<=0;out_rgb<=0;
  end else begin
   v1<=vs;d1<=de;x1<=x;y1<=y;rgb1<=rgb;en1<=frame_enable && coeff_valid;
   deltaR<=(rgb[23:16]>=oR)?rgb[23:16]-oR:8'd0;
   deltaG<=(rgb[15:8]>=oG)?rgb[15:8]-oG:8'd0;
   deltaB<=(rgb[7:0]>=oB)?rgb[7:0]-oB:8'd0;
   scaleR1<=sR;scaleG1<=sG;scaleB1<=sB;
   bypass1<={sR==0,sG==0,sB==0};
   v2<=v1;d2<=d1;x2<=x1;y2<=y1;rgb2<=rgb1;en2<=en1;bypass2<=bypass1;
   productR<=deltaR*scaleR1;productG<=deltaG*scaleG1;productB<=deltaB*scaleB1;
   v3<=v2;d3<=d2;x3<=x2;y3<=y2;en3<=en2;bypass3<=bypass2;
   rgb3<=!en2?rgb2:{bypass2[2]?rgb2[23:16]:saturate(productR),
           bypass2[1]?rgb2[15:8]:saturate(productG),bypass2[0]?rgb2[7:0]:saturate(productB)};
   out_vs<=v3;out_de<=d3;out_x<=x3;out_y<=y3;out_rgb<=d3?rgb3:24'd0;
  end
 end
endmodule
