// Coordinates describe the pixel present BEFORE its accepting clock edge.
// VS is active-low. No extra data latency; blank cycles reset horizontal position.
module video_coordinates(input clk,input rst,input vs,input de,
    output reg [9:0] x,output reg [9:0] y);
    reg de_d;
    always @(posedge clk or posedge rst) begin
        if(rst) begin x<=0;y<=0;de_d<=0;end
        else begin
            de_d<=de;
            if(!vs) begin x<=0;y<=0;end
            else begin
                if(de) x<=x+1'b1;
                else x<=0;
                if(de_d && !de) y<=y+1'b1;
            end
        end
    end
endmodule

// Exact floor(raw*4/5) coordinates without a divider on the pixel path.
// Both output modes are 4:3; UI uses a 640x480 logical viewport.
module viewport_coordinates(input clk,input rst,input vs,input de,input expanded,
 output reg [9:0] x,output reg [9:0] y,
 output reg [9:0] raw_x,output reg [9:0] raw_y);
 reg de_d;
 reg [2:0] xp,yp;
 always @(posedge clk or posedge rst)begin
  if(rst)begin x<=0;y<=0;raw_x<=0;raw_y<=0;xp<=0;yp<=0;de_d<=0;end
  else begin
   de_d<=de;
   if(!vs)begin x<=0;y<=0;raw_x<=0;raw_y<=0;xp<=0;yp<=0;end
   else begin
    if(de)begin
     raw_x<=raw_x+1'b1;
     xp<=(xp==4)?0:xp+1'b1;
     if(!expanded || xp!=0)x<=x+1'b1;
    end else begin x<=0;raw_x<=0;xp<=0;end
    if(de_d && !de)begin
     raw_y<=raw_y+1'b1;
     yp<=(yp==4)?0:yp+1'b1;
     if(!expanded || yp!=0)y<=y+1'b1;
    end
   end
  end
 end
endmodule
