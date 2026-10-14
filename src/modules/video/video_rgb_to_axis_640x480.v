// Raster cannot pause. Buffer 64 pixels of sink backpressure.
// On overflow, drop input until a drained frame boundary and flag the error.
module video_rgb_to_axis_640x480 #(parameter ADAPTIVE=0)(input I_clk,input I_rst,input I_vs,input I_de,
 input [23:0] I_rgb,output O_video_user,output O_video_valid,
 output O_video_last,output [23:0] O_video_data,
 input I_ready,output reg O_overflow,input mode_800);
 wire [9:0] last_x=(ADAPTIVE && mode_800)?799:639;
 reg vs_d,frame_arm,dropping;
 reg [9:0] x;
 reg [25:0] queue [0:63];
 reg [5:0] wr_ptr,rd_ptr;
 reg [6:0] count;
 wire pop=O_video_valid && I_ready;
 wire push=I_de && !dropping && ((count<64) || pop);
 assign O_video_valid=(count!=0);
 assign {O_video_user,O_video_last,O_video_data}=queue[rd_ptr];
 always @(posedge I_clk or posedge I_rst) begin
  if(I_rst) begin
   vs_d<=1;frame_arm<=1;x<=0;wr_ptr<=0;rd_ptr<=0;count<=0;
   dropping<=0;O_overflow<=0;
  end else begin
   vs_d<=I_vs;
   if(vs_d!=I_vs) begin
    frame_arm<=1;
    if(count==0) begin dropping<=0; O_overflow<=0; end  // per-frame error: clear once queue drains
   end
   if(I_de) begin
    frame_arm<=0;
    x<=(x==last_x)?10'd0:x+1'b1;
    if(!dropping && !push) begin dropping<=1;O_overflow<=1;end
   end else x<=0;
   if(push) begin queue[wr_ptr]<={frame_arm,(x==last_x),I_rgb};wr_ptr<=wr_ptr+1'b1;end
   if(pop) rd_ptr<=rd_ptr+1'b1;
   case({push,pop})
    2'b10:count<=count+1'b1;
    2'b01:count<=count-1'b1;
    default:;
   endcase
  end
 end
endmodule
