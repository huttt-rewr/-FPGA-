// Read-only SD v2 initialization and CMD17 controller. No FAT32/media logic.
module sd_native_controller #(
 parameter integer INIT_TIMEOUT_CYCLES=800000000,
 parameter integer INIT_PAUSE_CYCLES=100000000,
 parameter integer INIT_ATTEMPT_LIMIT=4096
)(
 input clk,rst,rise_tick,
 output reg high_speed,open_drain,output reg phy_reset,
 output reg sd_init_done,sd_init_error,sd_transfer_error,
 input sd_sec_read,input [31:0] sd_sec_read_addr,
 output [7:0] sd_sec_read_data,output sd_sec_read_data_valid,
 output reg sd_sec_read_end,
 input sd_sec_write,input [31:0] sd_sec_write_addr,input [7:0] sd_sec_write_data,
 output sd_sec_write_data_req,sd_sec_write_end,
 output reg cmd_start,output reg [5:0] cmd_index,
 output reg [31:0] cmd_argument,output reg [2:0] response_type,
 input cmd_ready,cmd_done,cmd_error,input [135:0] response,
 output reg read_arm,read_cancel,
 input [7:0] read_data,input read_valid,read_done,read_error
);
 localparam S_CLOCKS=0,S_ISSUE=1,S_RESPONSE=2,S_READY=3,S_READ=4,S_GAP=5,S_ERR=6,S_RECOVER=7;
 reg [2:0] state;
 reg [3:0] step;
 reg [6:0] boot_clocks;
 reg [15:0] rca;
 reg block_addressed;
 reg [31:0] init_timer,pause_timer,attempts;
 reg init_expired;
 reg data_finished,request_released;
 always @(posedge clk or posedge rst)begin
  if(rst)request_released<=0;
  else if(state==S_READY && (sd_sec_read || sd_sec_write))request_released<=0;
  else if(!sd_sec_read && !sd_sec_write)request_released<=1;
 end
 always @(posedge clk or posedge rst)begin
  if(rst)data_finished<=0;
  else if(read_arm)data_finished<=0;
  else if(read_done || read_error)data_finished<=1;
 end
 // R1/R1b status error bits, excluding current_state/ready/app_cmd flags.
 wire r1_bad=|(response[39:8] & 32'hfff9a008);
 wire r6_bad=|(response[23:8] & 16'he000);
 assign sd_sec_read_data=read_data;
 // Like the SPI implementation, bytes are speculative until sector_end;
 // CRC errors terminate with transfer_error and never assert sector_end.
 assign sd_sec_read_data_valid=(state==S_READ) && read_valid;
 assign sd_sec_write_data_req=1'b0;
 assign sd_sec_write_end=1'b0;
 always @(posedge clk or posedge rst)begin
  if(rst)begin init_timer<=0;init_expired<=0;end
  else if(sd_init_done || state==S_ERR)begin init_timer<=0;init_expired<=0;end
  else begin
   init_timer<=init_timer+1'b1;
   init_expired<=(INIT_TIMEOUT_CYCLES<=1 || init_timer>=INIT_TIMEOUT_CYCLES-2);
  end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=S_CLOCKS;step<=0;boot_clocks<=0;rca<=0;block_addressed<=0;
   high_speed<=0;open_drain<=1;phy_reset<=0;sd_init_done<=0;sd_init_error<=0;
   sd_transfer_error<=0;sd_sec_read_end<=0;pause_timer<=0;attempts<=0;
   cmd_start<=0;cmd_index<=0;cmd_argument<=0;response_type<=0;
   read_arm<=0;read_cancel<=0;
  end else begin
   cmd_start<=0;read_arm<=0;read_cancel<=0;sd_transfer_error<=0;sd_sec_read_end<=0;
   if(!sd_init_done && state!=S_ERR && init_expired)begin
    state<=S_ERR;sd_init_error<=1;phy_reset<=1;pause_timer<=0;read_cancel<=1;
   end else case(state)
    S_CLOCKS:if(rise_tick)begin
     if(boot_clocks==79)begin state<=S_ISSUE;step<=0;end
     else boot_clocks<=boot_clocks+1'b1;
    end
    S_ISSUE:if(cmd_ready)begin
     cmd_start<=1;state<=S_RESPONSE;
     case(step)
      0:begin cmd_index<=0;cmd_argument<=0;response_type<=0;end
      1:begin cmd_index<=8;cmd_argument<=32'h1aa;response_type<=5;end
      2:begin cmd_index<=55;cmd_argument<=0;response_type<=1;end
      3:begin cmd_index<=41;cmd_argument<=32'h40ff8000;response_type<=3;end
      4:begin cmd_index<=2;cmd_argument<=0;response_type<=2;end
      5:begin cmd_index<=3;cmd_argument<=0;response_type<=4;end
      6:begin cmd_index<=7;cmd_argument<={rca,16'd0};response_type<=6;end
      7:begin cmd_index<=55;cmd_argument<={rca,16'd0};response_type<=1;end
      8:begin cmd_index<=6;cmd_argument<=2;response_type<=1;end
      9:begin cmd_index<=16;cmd_argument<=512;response_type<=1;end
      default:begin // CMD17 arguments were latched when the request was accepted.
       cmd_index<=17;response_type<=1;read_arm<=1;
      end
     endcase
    end
    S_RESPONSE:if(cmd_done)begin
     if(cmd_error || ((step==2 || step==6 || step==7 || step==8 || step==9 || step==10) && r1_bad) ||
        (step==1 && response[19:8]!=12'h1aa) ||
        (step==5 && (r6_bad || response[39:24]==0)) ||
        ((step==2 || step==7) && !response[13]))begin
      if(sd_init_done)begin sd_transfer_error<=1;state<=S_RECOVER;end
      else begin read_cancel<=1;state<=S_ERR;sd_init_error<=1;phy_reset<=1;pause_timer<=0;end
     end else if(step==3)begin
      if(response[39])begin block_addressed<=response[38];step<=4;state<=S_ISSUE;end
      else if(attempts>=INIT_ATTEMPT_LIMIT-1)begin
       state<=S_ERR;sd_init_error<=1;phy_reset<=1;pause_timer<=0;
      end else begin attempts<=attempts+1'b1;step<=2;state<=S_ISSUE;end
     end else if(step==9)begin sd_init_done<=1;high_speed<=1;state<=S_READY;end
     else if(step==10)state<=S_READ;
     else begin
      if(step==5)begin rca<=response[39:24];open_drain<=0;end
      step<=step+1'b1;state<=S_ISSUE;
     end
    end
    S_READY:if(sd_sec_write)begin
     // Write inputs retained for interface compatibility; writes unsupported.
     sd_transfer_error<=1;state<=S_GAP;
    end else if(sd_sec_read)begin
     if(!block_addressed && |sd_sec_read_addr[31:23])begin
      // Reject overflow of SDSC byte addressing instead of silently wrapping.
      sd_transfer_error<=1;state<=S_GAP;
     end else begin
      cmd_argument<=block_addressed?sd_sec_read_addr:(sd_sec_read_addr<<9);
      step<=10;state<=S_ISSUE;
     end
    end
    S_READ:begin
     if(read_error)begin sd_transfer_error<=1;state<=S_GAP;end
     else if(read_done)begin sd_sec_read_end<=1;state<=S_GAP;end
    end
    S_GAP:if(request_released || (!sd_sec_read && !sd_sec_write))state<=S_READY;
    // A corrupt response does not mean the card stopped transmitting data.
    // Let the armed receiver finish/drain/timeout before the next command.
    S_RECOVER:if(data_finished && cmd_ready)state<=S_GAP;
    S_ERR:begin
     if(pause_timer>=INIT_PAUSE_CYCLES-1)begin
      pause_timer<=0;phy_reset<=0;sd_init_error<=0;high_speed<=0;open_drain<=1;
      sd_init_done<=0;state<=S_CLOCKS;boot_clocks<=0;step<=0;attempts<=0;
      rca<=0;block_addressed<=0;
     end else pause_timer<=pause_timer+1'b1;
    end
    default:begin state<=S_ERR;sd_init_error<=1;phy_reset<=1;pause_timer<=0;end
   endcase
   // Capture a bad/missing token even if it arrives with the CMD17 response.
   if(step==10 && state==S_RESPONSE && read_error)begin
    sd_transfer_error<=1;state<=S_RECOVER;
   end
  end
 end
endmodule
