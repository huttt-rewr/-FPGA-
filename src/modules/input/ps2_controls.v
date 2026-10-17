// Set 2 events only. Persistent playback/volume/OSD state has one owner in
// the existing consumers/top. R/F/digit events keep the same interface for
// subsequent stages. Extended status prevents keypad digits acting as arrows.
module ps2_controls #(
 parameter integer PENDING_TIMEOUT_CYCLES=200000000
)(
 input clk,rst,input [7:0] scan_code,
 input key_valid,key_release,key_extended,receive_error,
 output reg ev_next,ev_prev,ev_toggle_auto,ev_vol_up,ev_vol_dn,
 output reg ev_mute,ev_osd,ev_res,ev_fps,
 output reg [3:0] ev_digit,
 output reg ev_image_select,ev_audio_select,
 output reg audio_pending
);
 localparam PW=(PENDING_TIMEOUT_CYCLES<2)?1:$clog2(PENDING_TIMEOUT_CYCLES);
 reg [PW-1:0] pending_count;
 reg restart_pending;
 // Timer consumes registered state/events. Do not route the key decoder and
 // held-key mux through the reset/enable of every bit of the 2-second counter.
 always @(posedge clk or posedge rst)begin
  if(rst)pending_count<=0;
  else if(!audio_pending || restart_pending || receive_error)pending_count<=0;
  else if(pending_count!=PENDING_TIMEOUT_CYCLES-1)pending_count<=pending_count+1'b1;
 end
 // One bit per supported semantic key (including the A/Esc prefix controls).
 reg [21:0] held;
 reg recognized;
 reg [4:0] key_id;
 reg digit_key;
 reg [3:0] digit;
 reg raw_recognized,raw_digit_key;
 reg [4:0] raw_key_id;reg [3:0] raw_digit;
 reg valid_q,release_q;
 reg [21:0] key_mask;
 wire already_held=|(held & key_mask);
 always @(posedge clk or posedge rst)begin
  if(rst)begin recognized<=0;key_id<=0;digit_key<=0;digit<=0;valid_q<=0;release_q<=0;end
  else begin
   recognized<=raw_recognized;key_id<=raw_key_id;digit_key<=raw_digit_key;digit<=raw_digit;
   valid_q<=key_valid && !receive_error;release_q<=key_release;
  end
 end
 // Decode each held-key lane directly. Encoding a key ID and then shifting
 // a 22-bit mask needlessly cascades two large selection networks.
 function [7:0] lane_code;
  input integer lane;
  begin case(lane)
   0:lane_code=8'h74;1:lane_code=8'h6b;2:lane_code=8'h29;
   3:lane_code=8'h75;4:lane_code=8'h72;5:lane_code=8'h3a;
   6:lane_code=8'h44;7:lane_code=8'h2d;8:lane_code=8'h2b;
   9:lane_code=8'h1c;10:lane_code=8'h76;11:lane_code=8'h45;
   12:lane_code=8'h16;13:lane_code=8'h1e;14:lane_code=8'h26;
   15:lane_code=8'h25;16:lane_code=8'h2e;17:lane_code=8'h36;
   18:lane_code=8'h3d;19:lane_code=8'h3e;20:lane_code=8'h46;
   default:lane_code=0;
  endcase end
 endfunction
 genvar km;
 generate for(km=0;km<22;km=km+1)begin:key_lanes
  localparam [7:0] CODE=lane_code(km);
  localparam EXTENDED=(km==0 || km==1 || km==3 || km==4);
  always @(posedge clk or posedge rst)begin
   if(rst)key_mask[km]<=0;
   else key_mask[km]<=(km<21) && (key_extended==EXTENDED) && scan_code==CODE;
  end
 end endgenerate
 genvar h;
 generate for(h=0;h<22;h=h+1)begin:held_bits
  always @(posedge clk or posedge rst)begin
   if(rst)held[h]<=0;
   else if(receive_error)held[h]<=0;
   else if(valid_q && recognized && key_mask[h])held[h]<=!release_q;
  end
 end endgenerate
 always @*begin
  raw_recognized=1;raw_key_id=0;raw_digit_key=0;raw_digit=0;
  if(key_extended)case(scan_code)
   8'h74:raw_key_id=0;8'h6b:raw_key_id=1;8'h75:raw_key_id=3;8'h72:raw_key_id=4;
   default:raw_recognized=0;
  endcase
  else case(scan_code)
   8'h29:raw_key_id=2;8'h3a:raw_key_id=5;8'h44:raw_key_id=6;
   8'h2d:raw_key_id=7;8'h2b:raw_key_id=8;8'h1c:raw_key_id=9;8'h76:raw_key_id=10;
   8'h45:begin raw_key_id=11;raw_digit_key=1;raw_digit=0;end
   8'h16:begin raw_key_id=12;raw_digit_key=1;raw_digit=1;end
   8'h1e:begin raw_key_id=13;raw_digit_key=1;raw_digit=2;end
   8'h26:begin raw_key_id=14;raw_digit_key=1;raw_digit=3;end
   8'h25:begin raw_key_id=15;raw_digit_key=1;raw_digit=4;end
   8'h2e:begin raw_key_id=16;raw_digit_key=1;raw_digit=5;end
   8'h36:begin raw_key_id=17;raw_digit_key=1;raw_digit=6;end
   8'h3d:begin raw_key_id=18;raw_digit_key=1;raw_digit=7;end
   8'h3e:begin raw_key_id=19;raw_digit_key=1;raw_digit=8;end
   8'h46:begin raw_key_id=20;raw_digit_key=1;raw_digit=9;end
   default:raw_recognized=0;
  endcase
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   audio_pending<=0;restart_pending<=0;ev_digit<=0;
   ev_next<=0;ev_prev<=0;ev_toggle_auto<=0;ev_vol_up<=0;ev_vol_dn<=0;
   ev_mute<=0;ev_osd<=0;ev_res<=0;ev_fps<=0;ev_image_select<=0;ev_audio_select<=0;
  end else begin
   ev_next<=0;ev_prev<=0;ev_toggle_auto<=0;ev_vol_up<=0;ev_vol_dn<=0;
   ev_mute<=0;ev_osd<=0;ev_res<=0;ev_fps<=0;ev_image_select<=0;ev_audio_select<=0;
   restart_pending<=0;
   if(audio_pending && !restart_pending && pending_count==PENDING_TIMEOUT_CYCLES-1)audio_pending<=0;
   if(receive_error)begin audio_pending<=0;end
   else if(valid_q && recognized)begin
    if(!release_q)begin
     // Volume alone accepts typematic repeats; toggles fire once per press.
     if(!already_held || key_id==3 || key_id==4)begin
      if(digit_key)begin
       ev_digit<=digit;
       if(audio_pending && pending_count!=PENDING_TIMEOUT_CYCLES-1)begin
        ev_audio_select<=1;audio_pending<=0;
       end else ev_image_select<=1;
      end else case(key_id)
       0:ev_next<=1;1:ev_prev<=1;2:ev_toggle_auto<=1;
       3:ev_vol_up<=1;4:ev_vol_dn<=1;5:ev_mute<=1;6:ev_osd<=1;
       7:ev_res<=1;8:ev_fps<=1;
       9:begin audio_pending<=1;restart_pending<=1;end
       10:begin audio_pending<=0;end
      endcase
     end
    end
   end
  end
 end
endmodule
