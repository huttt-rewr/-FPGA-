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
 // One bit per supported semantic key (including the A/Esc prefix controls).
 reg [21:0] held;
 reg recognized;
 reg [4:0] key_id;
 reg digit_key;
 reg [3:0] digit;
 always @*begin
  recognized=1;key_id=0;digit_key=0;digit=0;
  if(key_extended)case(scan_code)
   8'h74:key_id=0;8'h6b:key_id=1;8'h75:key_id=3;8'h72:key_id=4;
   default:recognized=0;
  endcase
  else case(scan_code)
   8'h29:key_id=2;8'h3a:key_id=5;8'h44:key_id=6;
   8'h2d:key_id=7;8'h2b:key_id=8;8'h1c:key_id=9;8'h76:key_id=10;
   8'h45:begin key_id=11;digit_key=1;digit=0;end
   8'h16:begin key_id=12;digit_key=1;digit=1;end
   8'h1e:begin key_id=13;digit_key=1;digit=2;end
   8'h26:begin key_id=14;digit_key=1;digit=3;end
   8'h25:begin key_id=15;digit_key=1;digit=4;end
   8'h2e:begin key_id=16;digit_key=1;digit=5;end
   8'h36:begin key_id=17;digit_key=1;digit=6;end
   8'h3d:begin key_id=18;digit_key=1;digit=7;end
   8'h3e:begin key_id=19;digit_key=1;digit=8;end
   8'h46:begin key_id=20;digit_key=1;digit=9;end
   default:recognized=0;
  endcase
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   held<=0;audio_pending<=0;pending_count<=0;ev_digit<=0;
   ev_next<=0;ev_prev<=0;ev_toggle_auto<=0;ev_vol_up<=0;ev_vol_dn<=0;
   ev_mute<=0;ev_osd<=0;ev_res<=0;ev_fps<=0;ev_image_select<=0;ev_audio_select<=0;
  end else begin
   ev_next<=0;ev_prev<=0;ev_toggle_auto<=0;ev_vol_up<=0;ev_vol_dn<=0;
   ev_mute<=0;ev_osd<=0;ev_res<=0;ev_fps<=0;ev_image_select<=0;ev_audio_select<=0;
   if(!audio_pending)pending_count<=0;
   else if(pending_count==PENDING_TIMEOUT_CYCLES-1)begin audio_pending<=0;pending_count<=0;end
   else pending_count<=pending_count+1'b1;
   if(receive_error)begin held<=0;audio_pending<=0;pending_count<=0;end
   else if(key_valid && recognized)begin
    if(key_release)held[key_id]<=0;
    else begin
     held[key_id]<=1;
     // Volume alone accepts typematic repeats; toggles fire once per press.
     if(!held[key_id] || key_id==3 || key_id==4)begin
      if(digit_key)begin
       ev_digit<=digit;
       if(audio_pending && pending_count!=PENDING_TIMEOUT_CYCLES-1)begin
        ev_audio_select<=1;audio_pending<=0;pending_count<=0;
       end else ev_image_select<=1;
      end else case(key_id)
       0:ev_next<=1;1:ev_prev<=1;2:ev_toggle_auto<=1;
       3:ev_vol_up<=1;4:ev_vol_dn<=1;5:ev_mute<=1;6:ev_osd<=1;
       7:ev_res<=1;8:ev_fps<=1;
       9:begin audio_pending<=1;pending_count<=0;end
       10:begin audio_pending<=0;pending_count<=0;end
      endcase
     end
    end
   end
  end
 end
endmodule
