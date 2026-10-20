// Active-low internal HS/VS in BOTH modes: consumers use falling VS as vblank.
// The official HDMI core independently generates the mode's link timing.
module adaptive_raster(input clk,input rst,input mode_800,
 output hs,output vs,output de);
 reg [10:0] h;
 reg [9:0] v;
 wire [10:0] ht=mode_800?1056:800,hsw=mode_800?128:96,hbegin=mode_800?216:144;
 wire [9:0] vt=mode_800?628:525,vsw=mode_800?4:2,vbegin=mode_800?27:35;
 wire [10:0] width=mode_800?800:640;
 wire [9:0] height=mode_800?600:480;
 always @(posedge clk or posedge rst)begin
  if(rst)begin h<=0;v<=0;end
  else if(h==ht-1)begin h<=0;v<=(v==vt-1)?0:v+1'b1;end
  else h<=h+1'b1;
 end
 assign hs=(h>=hsw);assign vs=(v>=vsw);
 assign de=h>=hbegin && h<hbegin+width && v>=vbegin && v<vbegin+height;
endmodule
