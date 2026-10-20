// Two-stage synchronous font fetch and registered alpha/text composition.
// Coordinates are the logical 640x480 viewport in either output mode.
module zh_overlay #(parameter WIN_X=32,WIN_Y=384,CHARS=17)(
 input clk,rst,vs,de,input [9:0] x,y,input [23:0] rgb,input enable,
 output reg out_vs,out_de,output reg [9:0] out_x,out_y,output reg [23:0] out_rgb);
 reg vs_last,enabled;
 wire [9:0] local_x=x-WIN_X,local_y=y-WIN_Y;
 wire in_window=(x>=WIN_X && x<WIN_X+CHARS*16 && y>=WIN_Y && y<WIN_Y+16);
 wire [15:0] glyph;
 zh_font_rom font(clk,local_x[8:4],local_y[3:0],glyph);
 reg v1,d1,draw1;reg [9:0]x1,y1;reg [23:0]rgb1;reg [3:0]column1;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   vs_last<=1;enabled<=0;v1<=0;d1<=0;draw1<=0;x1<=0;y1<=0;rgb1<=0;column1<=0;
   out_vs<=0;out_de<=0;out_x<=0;out_y<=0;out_rgb<=0;
  end else begin
   vs_last<=vs;if(vs_last && !vs)enabled<=enable;
   v1<=vs;d1<=de;x1<=x;y1<=y;rgb1<=rgb;column1<=local_x[3:0];draw1<=enabled && in_window;
   out_vs<=v1;out_de<=d1;out_x<=x1;out_y<=y1;
   if(!d1)out_rgb<=0;
   else if(draw1 && glyph[15-column1])out_rgb<=24'hffe090;
   else if(draw1)out_rgb<={1'b0,rgb1[23:17],1'b0,rgb1[15:9],1'b0,rgb1[7:1]};
   else out_rgb<=rgb1;
  end
 end
endmodule
