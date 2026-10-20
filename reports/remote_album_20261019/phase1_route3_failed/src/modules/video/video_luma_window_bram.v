// Same causal 3x3 window as video_luma_window, for a CONTINUOUS raster line.
// Synchronous BRAM is read one column ahead: its registered output therefore
// describes x before the next accepting edge, with no added pixel latency.
// Blanking prefetches column zero. Neither RAM has reset or initialization.
module video_luma_window_bram #(parameter DEPTH=800)(
 input clk,rst,vs,de,input [9:0] x,input [7:0] external_luma,
 output [7:0] gray,t0,t1,t2,m0,m1,m2,b0,b1,b2,output valid
);
 (* ram_style="bram" *) reg [7:0] row1[0:DEPTH-1];
 (* ram_style="bram" *) reg [7:0] row2[0:DEPTH-1];
 reg [7:0] p1,p2;
 wire ok=x<DEPTH;
 wire [9:0] prefetch=(!rst && vs && de && x<DEPTH-1)?x+1'b1:10'd0;
 always @(posedge clk)begin
  p1<=row1[prefetch];p2<=row2[prefetch];
  if(!rst && vs && de && ok)begin row1[x]<=external_luma;row2[x]<=p1;end
 end
 reg [7:0] ta,tb,ma,mb,ba,bb;reg de_last;reg [1:0] rows;
 assign gray=external_luma;
 assign t0=tb;assign t1=ta;assign t2=ok?p2:8'd0;
 assign m0=mb;assign m1=ma;assign m2=ok?p1:8'd0;
 assign b0=bb;assign b1=ba;assign b2=external_luma;
 assign valid=de && vs && ok && rows==2 && x>=2;
 always @(posedge clk or posedge rst)begin
  if(rst)begin ta<=0;tb<=0;ma<=0;mb<=0;ba<=0;bb<=0;rows<=0;de_last<=0;end
  else begin
   de_last<=de;if(!vs)rows<=0;else if(de_last && !de && rows!=2)rows<=rows+1'b1;
   if(!de || !vs)begin ta<=0;tb<=0;ma<=0;mb<=0;ba<=0;bb<=0;end
   else begin ta<=ok?p2:8'd0;tb<=(x==0)?8'd0:ta;ma<=ok?p1:8'd0;mb<=(x==0)?8'd0:ma;ba<=external_luma;bb<=(x==0)?8'd0:ba;end
  end
 end
endmodule
