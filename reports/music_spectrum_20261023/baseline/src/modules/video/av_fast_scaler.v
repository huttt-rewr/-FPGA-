// Bottom-up BGR24 160x120 (4x), RGB565LE 320x240 (2x) or 640x480 (1x).
// Two sector banks let SD prefetch overlap row expansion and SDRAM stalls.
// A sector is fetched once. The SDRAM writer performs the vertical flip.
module av_fast_scaler(
 input clk,input rst,input start,input [31:0] base_sector,input [1:0] video_format,
 output reg sector_read,output reg [31:0] sector_address,
 input [7:0] sector_data,input sector_valid,input sector_end,
 output [23:0] pixel,output pixel_valid,input pixel_ready,
 output reg done,output reg error,output busy
);
 localparam IDLE=0,WAIT_SECTOR=1,BYTE_REQ=2,BYTE_USE=3,OUT_REQ=4,OUT_SEND=5;
 reg [2:0] state;
 reg [7:0] sector_ram[0:1023];
 reg [23:0] line_ram[0:639];
 reg [7:0] byte_q,blue,green;
 reg [23:0] line_q;
 reg [9:0] fetched,position;
 reg [8:0] row_y;
 reg [10:0] loaded_sectors;
 reg [9:0] row_x,out_x;
 reg [1:0] channel,rep_x,rep_y,filled;
 reg fetch_bank,read_bank;
 reg [1:0] fmt;
 wire [9:0] last_x=fmt==2'd2 ? 10'd639:(fmt==2'd1 ? 10'd319:10'd159);
 wire [8:0] last_y=fmt==2'd2 ? 9'd479:(fmt==2'd1 ? 9'd239:9'd119);
 wire [10:0] sector_count=fmt==2'd2 ? 11'd1200:(fmt==2'd1 ? 11'd300:11'd113);
 wire [1:0] last_repeat=fmt==2'd2 ? 2'd0:(fmt==2'd1 ? 2'd1:2'd3);
 wire last_channel=(fmt!=2'd0)?(channel==1):(channel==2);
 // LE565: high byte RRRRRGGG, low byte GGGBBBBB; replicate top bits.
 wire [23:0] expanded565={byte_q[7:3],byte_q[7:5],byte_q[2:0],blue[7:5],byte_q[2:1],blue[4:0],blue[4:2]};
 assign pixel=line_q;
 assign pixel_valid=state==OUT_SEND;
 assign busy=state!=IDLE;

 // Synchronous RAM ports; bank ownership prevents writing unread bytes.
 always @(posedge clk)begin
  if(sector_read && sector_valid && fetched<512)
   sector_ram[{fetch_bank,fetched[8:0]}]<=sector_data;
  if(state==BYTE_REQ && position<512)
   byte_q<=sector_ram[{read_bank,position[8:0]}];
  if(state==BYTE_USE && last_channel)
   line_ram[row_x]<=(fmt!=2'd0)?expanded565:{byte_q,green,blue};
  if(state==OUT_REQ)line_q<=line_ram[out_x];
 end

 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=IDLE;sector_read<=0;sector_address<=0;fmt<=0;
   fetched<=0;position<=0;row_y<=0;row_x<=0;out_x<=0;
   rep_x<=0;rep_y<=0;channel<=0;blue<=0;green<=0;
   loaded_sectors<=0;fetch_bank<=0;read_bank<=0;filled<=0;
   done<=0;error<=0;
  end else begin
   done<=0;error<=0;
   if(state==IDLE)begin
    if(start)begin
     fmt<=video_format;
     sector_address<=base_sector;sector_read<=1;
     fetched<=0;position<=0;row_y<=0;row_x<=0;out_x<=0;
     rep_x<=0;rep_y<=0;channel<=0;state<=WAIT_SECTOR;
     loaded_sectors<=0;fetch_bank<=0;read_bank<=0;filled<=0;
    end
   end else begin
    // Producer: don't issue the next command until its cache bank is free.
    if(sector_read)begin
     if(sector_valid && fetched<513)fetched<=fetched+1'b1;
     if(sector_end)begin
      sector_read<=0;filled[fetch_bank]<=1;
      fetch_bank<=!fetch_bank;loaded_sectors<=loaded_sectors+1'b1;
      sector_address<=sector_address+1'b1;
     end
    end else if(loaded_sectors<sector_count && !filled[fetch_bank])begin
     sector_read<=1;fetched<=0;
    end

    // Consumer: stalls never change the presented pixel or consume a byte.
    case(state)
     WAIT_SECTOR:if(filled[read_bank])state<=BYTE_REQ;
     BYTE_REQ:begin
      if(position==512)begin
       filled[read_bank]<=0;read_bank<=!read_bank;position<=0;state<=WAIT_SECTOR;
      end else state<=BYTE_USE;
     end
     BYTE_USE:begin
      position<=position+1'b1;
      if(last_channel)begin
       channel<=0;
       if(row_x==last_x)begin
        row_x<=0;out_x<=0;rep_x<=0;rep_y<=0;state<=OUT_REQ;
       end else begin row_x<=row_x+1'b1;state<=BYTE_REQ;end
      end else case(channel)
       0:begin blue<=byte_q;channel<=1;state<=BYTE_REQ;end
       1:begin green<=byte_q;channel<=2;state<=BYTE_REQ;end
       default:begin error<=1;sector_read<=0;state<=IDLE;end
      endcase
     end
     OUT_REQ:state<=OUT_SEND;
     OUT_SEND:if(pixel_ready)begin
      if(rep_x!=last_repeat)rep_x<=rep_x+1'b1;
      else begin
       rep_x<=0;
       if(out_x!=last_x)begin out_x<=out_x+1'b1;state<=OUT_REQ;end
       else if(rep_y!=last_repeat)begin rep_y<=rep_y+1'b1;out_x<=0;state<=OUT_REQ;end
       else if(row_y!=last_y)begin
        row_y<=row_y+1'b1;out_x<=0;state<=BYTE_REQ;
       end else begin done<=1;sector_read<=0;state<=IDLE;end
      end
     end
     default:begin error<=1;sector_read<=0;state<=IDLE;end
    endcase
    // Malformed transport overrides normal progress and never completes a frame.
    if(sector_read && sector_end && fetched+sector_valid!=512)begin
     error<=1;done<=0;sector_read<=0;state<=IDLE;filled<=0;
    end
   end
  end
 end
endmodule
