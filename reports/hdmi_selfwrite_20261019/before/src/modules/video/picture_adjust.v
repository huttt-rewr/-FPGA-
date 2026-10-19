// Two-cycle RGB pipeline. C' = clamp(((C-128)*contrast/4)+128+brightness).
// contrast=2..8 means 0.50..2.00. Signed round-to-nearest, ties toward +infinity.
module picture_adjust(input clk,input rst,input vs,input de,input [9:0] x,
 input [23:0] rgb,input signed [7:0] brightness,input [3:0] contrast,
 output reg out_vs,output reg out_de,output reg [9:0] out_x,output reg [23:0] out_rgb);
 reg signed [13:0] pr,pg,pb;
 reg signed [7:0] b;
 reg v,d;reg [9:0] px;
 function [7:0] clamp;
  input signed [13:0] product;input signed [7:0] bright;
  reg signed [15:0] sum;
  begin
   sum=(($signed(product)+16'sd2)>>>2)+16'sd128+$signed(bright);
   clamp=(sum<0)?0:((sum>255)?255:sum[7:0]);
  end
 endfunction
 always @(posedge clk or posedge rst)begin
  if(rst)begin pr<=0;pg<=0;pb<=0;b<=0;v<=0;d<=0;px<=0;out_vs<=0;out_de<=0;out_x<=0;out_rgb<=0;end
  else begin
   pr<=($signed({1'b0,rgb[23:16]})-9'sd128)*$signed({1'b0,contrast});
   pg<=($signed({1'b0,rgb[15:8]})-9'sd128)*$signed({1'b0,contrast});
   pb<=($signed({1'b0,rgb[7:0]})-9'sd128)*$signed({1'b0,contrast});
   b<=brightness;v<=vs;d<=de;px<=x;
   out_vs<=v;out_de<=d;out_x<=px;
   out_rgb<=d?{clamp(pr,b),clamp(pg,b),clamp(pb,b)}:24'd0;
  end
 end
endmodule
