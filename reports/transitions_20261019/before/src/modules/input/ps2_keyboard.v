// Receive-only PS/2 Set 2. External clock is data, never a fabric clock.
// Eight stable system-clock samples reject short clock glitches. A broken
// frame/prefix expires instead of consuming the next unrelated key forever.
module ps2_keyboard #(
 parameter integer FILTER_CYCLES=8,
 parameter integer TIMEOUT_CYCLES=200000
)(
 input clk,rst,ps2_clk,ps2_data,
 output reg [7:0] scan_code,
 output reg key_valid,key_release,key_extended,
 output reg receive_error
);
 (* async_reg="true" *) reg [1:0] clock_sync,data_sync;
 reg filtered_clock;
 localparam FW=(FILTER_CYCLES<2)?1:$clog2(FILTER_CYCLES);
 localparam TW=(TIMEOUT_CYCLES<2)?1:$clog2(TIMEOUT_CYCLES);
 reg [FW-1:0] filter_count;
 reg [TW-1:0] timeout_count;
 wire edge_due=(clock_sync[1]!=filtered_clock) &&
               ((FILTER_CYCLES<=1) || filter_count==FILTER_CYCLES-1);
 wire falling=edge_due && filtered_clock;
 reg [9:0] frame;
 reg [3:0] bit_count;
 reg extended_pending,break_pending;
 reg [2:0] pause_left;
 wire pending=(bit_count!=0) || extended_pending || break_pending || (pause_left!=0);
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   clock_sync<=3;data_sync<=3;filtered_clock<=1;filter_count<=0;
  end else begin
   clock_sync<={clock_sync[0],ps2_clk};data_sync<={data_sync[0],ps2_data};
   if(clock_sync[1]==filtered_clock)filter_count<=0;
   else if(edge_due)begin filtered_clock<=clock_sync[1];filter_count<=0;end
   else filter_count<=filter_count+1'b1;
  end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   frame<=0;bit_count<=0;extended_pending<=0;break_pending<=0;pause_left<=0;
   timeout_count<=0;scan_code<=0;key_valid<=0;key_release<=0;
   key_extended<=0;receive_error<=0;
  end else begin
   key_valid<=0;receive_error<=0;
   if(!pending || falling)timeout_count<=0;
   else timeout_count<=timeout_count+1'b1;
   if(pending && !falling && timeout_count==TIMEOUT_CYCLES-1)begin
    bit_count<=0;extended_pending<=0;break_pending<=0;pause_left<=0;
    timeout_count<=0;receive_error<=1;
   end else if(falling)begin
    if(bit_count==0)begin
     if(!data_sync[1])begin frame[0]<=0;bit_count<=1;end
     else begin extended_pending<=0;break_pending<=0;pause_left<=0;receive_error<=1;end
    end else if(bit_count<10)begin
     frame[bit_count]<=data_sync[1];bit_count<=bit_count+1'b1;
    end else begin
     bit_count<=0;
     if(!frame[0] && data_sync[1] && (^frame[9:1]))begin
      // Pause is an eight-byte sequence, not ordinary E0/F0 key events.
      if(pause_left!=0)pause_left<=pause_left-1'b1;
      else case(frame[8:1])
       8'he1:begin pause_left<=7;extended_pending<=0;break_pending<=0;end
       8'he0:extended_pending<=1;
       8'hf0:break_pending<=1;
       // BAT success, BAT failures and keyboard overrun clear stale prefixes
       // and held-key tracking in the consumer. They are not user keys.
       8'haa,8'hfc,8'hfd,8'h00,8'hff:begin
        extended_pending<=0;break_pending<=0;receive_error<=1;
       end
       default:begin
        scan_code<=frame[8:1];key_valid<=1;
        key_release<=break_pending;key_extended<=extended_pending;
        extended_pending<=0;break_pending<=0;
       end
      endcase
     end else begin
      extended_pending<=0;break_pending<=0;pause_left<=0;receive_error<=1;
     end
    end
   end
  end
 end
endmodule
