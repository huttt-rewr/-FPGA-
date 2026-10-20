// Boot-clock controller. Reset all media/video consumers before changing either
// member of the 1x/5x global clock mux pair. Controls use a separate reset domain.
module video_mode_control #(
 parameter integer QUIET_CYCLES=16,parameter integer SETTLE_CYCLES=4096
)(input clk,rst,input edid_done,input supports_800,input [1:0] requested_mode,
 output reg ready,output reg mode_800,output reg [1:0] active_mode,
 output fallback);
 localparam WAIT_EDID=0,QUIET=1,SELECT=2,SETTLE=3,RUN=4;
 localparam CW=$clog2(SETTLE_CYCLES+QUIET_CYCLES+1);
 reg [2:0] state;reg [CW-1:0] count;
 reg [1:0] target;
 wire [1:0] normalized=(requested_mode>2)?2'd1:requested_mode;
 assign fallback=(active_mode==2) && !mode_800;
 always @(posedge clk or posedge rst)begin
  if(rst)begin ready<=0;mode_800<=0;active_mode<=1;target<=1;count<=0;state<=WAIT_EDID;end
  else case(state)
   WAIT_EDID:if(edid_done)begin target<=normalized;count<=0;state<=QUIET;end
   QUIET:begin
    ready<=0;
    if(count==QUIET_CYCLES-1)begin count<=0;state<=SELECT;end
    else count<=count+1'b1;
   end
   SELECT:begin
    active_mode<=target;mode_800<=(target==2 && supports_800);
    count<=0;state<=SETTLE;
   end
   SETTLE:if(count==SETTLE_CYCLES-1)begin ready<=1;count<=0;state<=RUN;end
    else count<=count+1'b1;
   RUN:if(normalized!=active_mode)begin ready<=0;target<=normalized;count<=0;state<=QUIET;end
   default:begin ready<=0;state<=WAIT_EDID;end
  endcase
 end
endmodule
