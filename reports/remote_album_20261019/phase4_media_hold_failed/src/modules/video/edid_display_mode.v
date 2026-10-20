// Boot-time whitelist negotiation from the official core's 128-byte base block.
// Mode 1 = 800x600@60; mode 0 = VGA fallback (25MHz in this project).
// Never promote an unchecked block or assume the preferred size is supported.
module edid_display_mode #(parameter TIMEOUT=16777216)(
 input clk,input rst,input start,input valid,input [7:0] data,
 output reg done,output reg good,output reg mode_800,output reg fallback);
 reg active,header_ok,digital,version_ok,revision_ok,has_800;
 reg [7:0] count,sum,standard_x;
 reg [31:0] idle_count;
 reg [4:0] di;
 reg [7:0] dtd[0:17];
 wire [7:0] expected=(count==0 || count==7)?8'h00:8'hff;
 wire [7:0] checksum=sum+data;
 wire [11:0] dw={dtd[4][7:4],dtd[2]},dh={dtd[7][7:4],dtd[5]};
 wire [11:0] hb={dtd[4][3:0],dtd[3]},vb={dtd[7][3:0],dtd[6]};
 wire [9:0] hfp={dtd[11][7:6],dtd[8]},hsw={dtd[11][5:4],dtd[9]};
 wire [5:0] vfp={dtd[11][3:2],dtd[10][7:4]},vsw={dtd[11][1:0],dtd[10][3:0]};
 integer i;
 always @(posedge clk or posedge rst) begin
  if(rst)begin
   active<=0;done<=0;good<=0;mode_800<=0;fallback<=1;
   header_ok<=1;digital<=0;version_ok<=0;revision_ok<=0;has_800<=0;
   count<=0;sum<=0;standard_x<=0;idle_count<=0;di<=0;
   for(i=0;i<18;i=i+1)dtd[i]<=0;
  end else if(start)begin
   active<=1;done<=0;good<=0;mode_800<=0;fallback<=1;
   header_ok<=1;digital<=0;version_ok<=0;revision_ok<=0;has_800<=0;
   count<=0;sum<=0;standard_x<=0;idle_count<=0;di<=0;
  end else if(active)begin
   if(valid)begin
    idle_count<=0;sum<=checksum;count<=count+1'b1;
    if(count<8 && data!=expected)header_ok<=0;
    if(count==18)version_ok<=data==1;
    if(count==19)revision_ok<=(data==3 || data==4);
    if(count==20)digital<=data[7];
    // Established Timing I bit 0 is exactly 800x600@60 (not bit 1: 56Hz).
    if(count==35 && data[0])has_800<=1;
    if(count>=38 && count<54)begin
     if(!count[0])standard_x<=data;
     else if(standard_x==8'd69 && data==8'h40)has_800<=1;
    end
    if(count>=54 && count<126)begin
     dtd[di]<=data;
     if(di==17)begin
      di<=0;
      if({dtd[1],dtd[0]}==16'd4000 && dw==800 && dh==600 && hb==256 && vb==28 &&
         hfp==40 && hsw==128 && vfp==1 && vsw==4 && data[7]==0 && data[4:1]==4'b1111)
       has_800<=1;
     end else di<=di+1'b1;
    end
    if(count==127)begin
     active<=0;done<=1;good<=header_ok && checksum==0 && version_ok && revision_ok;
     mode_800<=header_ok && checksum==0 && version_ok && revision_ok && digital && has_800;
     fallback<=!(header_ok && checksum==0 && version_ok && revision_ok && digital && has_800);
    end
   end else if(idle_count>=TIMEOUT-1)begin
    active<=0;done<=1;good<=0;mode_800<=0;fallback<=1;
   end else idle_count<=idle_count+1'b1;
  end
 end
endmodule
