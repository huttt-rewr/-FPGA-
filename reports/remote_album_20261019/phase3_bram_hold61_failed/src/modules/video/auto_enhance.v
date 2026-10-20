// Previous-frame per-channel automatic levels. Four fully registered stages.
// 1 delta/range, 2 synchronous reciprocal ROM, 3 product, 4 rounding/output.
// The three ROMs trade spare BRAM for less LUT and local routing pressure.
// Empty frames retain coefficients. Constant channels and the first frame bypass.
module auto_enhance(
 input clk,input rst,input vs,input de,input [9:0] x,y,input [23:0] rgb,input enable,
 output reg out_vs,output reg out_de,output reg [9:0] out_x,out_y,output reg [23:0] out_rgb);
 reg vs_d,seen,coeff_valid,frame_enable;
 wire frame_start=vs_d && !vs;
 reg [7:0] rmin,rmax,gmin,gmax,bmin,bmax;
 wire [7:0] rr=rmax-rmin,gr=gmax-gmin,br=bmax-bmin;
 reg [7:0] rangeR,rangeG,rangeB;
 reg [7:0] oR,oG,oB;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   vs_d<=1;seen<=0;coeff_valid<=0;frame_enable<=0;
   rmin<=255;rmax<=0;gmin<=255;gmax<=0;bmin<=255;bmax<=0;
   rangeR<=0;rangeG<=0;rangeB<=0;oR<=0;oG<=0;oB<=0;
  end else begin
   vs_d<=vs;
   if(frame_start)begin
    frame_enable<=enable;
    if(seen)begin rangeR<=rr;rangeG<=gr;rangeB<=br;oR<=rmin;oG<=gmin;oB<=bmin;coeff_valid<=1;end
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
 reg [7:0] rangeR1,rangeG1,rangeB1;
 reg [7:0] deltaR2,deltaG2,deltaB2;
 wire [15:0] scaleR2,scaleG2,scaleB2;
 auto_enhance_scale rscale(clk,rangeR1,scaleR2),gscale(clk,rangeG1,scaleG2),bscale(clk,rangeB1,scaleB2);
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
   deltaR<=0;deltaG<=0;deltaB<=0;rangeR1<=0;rangeG1<=0;rangeB1<=0;deltaR2<=0;deltaG2<=0;deltaB2<=0;
   productR<=0;productG<=0;productB<=0;bypass1<=0;bypass2<=0;bypass3<=0;
   out_vs<=0;out_de<=0;out_x<=0;out_y<=0;out_rgb<=0;
  end else begin
   v1<=vs;d1<=de;x1<=x;y1<=y;rgb1<=rgb;en1<=frame_enable && coeff_valid;
   deltaR<=(rgb[23:16]>=oR)?rgb[23:16]-oR:8'd0;
   deltaG<=(rgb[15:8]>=oG)?rgb[15:8]-oG:8'd0;
   deltaB<=(rgb[7:0]>=oB)?rgb[7:0]-oB:8'd0;
   rangeR1<=rangeR;rangeG1<=rangeG;rangeB1<=rangeB;
   bypass1<={rangeR==0,rangeG==0,rangeB==0};
   v2<=v1;d2<=d1;x2<=x1;y2<=y1;rgb2<=rgb1;en2<=en1;bypass2<=bypass1;
   deltaR2<=deltaR;deltaG2<=deltaG;deltaB2<=deltaB;
   productR<=deltaR2*scaleR2;productG<=deltaG2*scaleG2;productB<=deltaB2*scaleB2;
   v3<=v2;d3<=d2;x3<=x2;y3<=y2;en3<=en2;bypass3<=bypass2;
   rgb3<=rgb2;
   out_vs<=v3;out_de<=d3;out_x<=x3;out_y<=y3;
   out_rgb<=!d3?24'd0:!en3?rgb3:{bypass3[2]?rgb3[23:16]:saturate(productR),
           bypass3[1]?rgb3[15:8]:saturate(productG),bypass3[0]?rgb3[7:0]:saturate(productB)};
  end
 end
endmodule
