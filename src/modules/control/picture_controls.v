// Three active-low board buttons: B2/C1 retain playback functions in mode 0.
// B1 cycles PLAY -> BRIGHTNESS -> CONTRAST -> PLAY. No UART dependency.
module picture_controls #(parameter DEBOUNCE_CYCLES=2000000,
 parameter BOARD_MENU=0,parameter AUDIO_MENU=0,parameter LONG_PRESS_CYCLES=100000000,
 parameter KEYBOARD_CONTROLS=0,parameter AUDIO_MUTE_DEFAULT=1)(
 input clk,input rst,input key1_n,input key2_n,input key3_n,
 output reg next_pulse,output reg toggle_pulse,
 output reg signed [7:0] brightness,output reg [3:0] contrast,
 output reg [1:0] edit_mode,
 output reg menu_open,output reg [2:0] menu_item,
 output reg gamma_enable,output reg debug_enable,output reg [1:0] debug_page,
 output reg [4:0] audio_volume,output reg audio_mute,
 input kb_vol_up,kb_vol_dn,kb_mute);
 (* async_reg="true" *) reg [2:0] sync0,sync1;
 reg [2:0] stable,armed,pulse;
 localparam CW=(DEBOUNCE_CYCLES<2)?1:$clog2(DEBOUNCE_CYCLES);
 reg [CW-1:0] count[0:2];
 integer k;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   sync0<=0;sync1<=0;stable<=0;armed<=0;pulse<=0;
   for(k=0;k<3;k=k+1)count[k]<=0;
  end else begin
   sync0<={key3_n,key2_n,key1_n};sync1<=sync0;pulse<=0;
   for(k=0;k<3;k=k+1)begin
    if(sync1[k]==stable[k])count[k]<=0;
    else if(count[k]==DEBOUNCE_CYCLES-1)begin
     stable[k]<=sync1[k];count[k]<=0;
     if(sync1[k])armed[k]<=1;
     else if(armed[k])begin pulse[k]<=1;armed[k]<=0;end
    end else count[k]<=count[k]+1'b1;
   end
  end
 end
 // Optional board menu. A short KEY3 action is deferred until release so a
 // one-second hold cannot also change the normal edit mode or confirm an item.
 localparam LW=(LONG_PRESS_CYCLES<2)?1:$clog2(LONG_PRESS_CYCLES);
 reg [LW-1:0] hold_count;
 reg tracking,long_seen,short3,long3;
 always @(posedge clk or posedge rst)begin
  if(rst)begin hold_count<=0;tracking<=0;long_seen<=0;short3<=0;long3<=0;end
  else begin
   short3<=0;long3<=0;
   if(pulse[2])begin tracking<=1;long_seen<=0;hold_count<=0;end
   else if(tracking)begin
    if(stable[2])begin
     if(!long_seen)short3<=1;
     tracking<=0;hold_count<=0;
    end else if(!long_seen)begin
     if(hold_count==LONG_PRESS_CYCLES-1)begin long_seen<=1;long3<=1;end
     else hold_count<=hold_count+1'b1;
    end
   end
  end
 end
 wire key3_action=BOARD_MENU?short3:pulse[2];
 wire menu_audio_action=BOARD_MENU && menu_open && key3_action && !long3 && AUDIO_MENU;
 wire volume_up=(menu_audio_action && menu_item==6) || (KEYBOARD_CONTROLS && kb_vol_up);
 wire volume_down=(menu_audio_action && menu_item==5) || (KEYBOARD_CONTROLS && kb_vol_dn);
 wire mute_toggle=(menu_audio_action && menu_item==4) || (KEYBOARD_CONTROLS && kb_mute);
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   next_pulse<=0;toggle_pulse<=0;brightness<=0;contrast<=4;edit_mode<=0;
   menu_open<=0;menu_item<=0;gamma_enable<=0;debug_enable<=0;debug_page<=0;
   audio_volume<=8;audio_mute<=AUDIO_MUTE_DEFAULT;
  end
  else begin
   next_pulse<=0;toggle_pulse<=0;
   if(BOARD_MENU && long3)menu_open<=~menu_open;
   else if(BOARD_MENU && menu_open)begin
    if(key3_action)begin
     case(menu_item)
      0:toggle_pulse<=1;
      1:gamma_enable<=~gamma_enable;
      2:debug_enable<=~debug_enable;
      3:debug_page<=debug_page+1'b1;
      // Audio events below share one register owner with the keyboard.
     endcase
    end else if(pulse[1:0]==1)menu_item<=(menu_item==0)?(AUDIO_MENU?6:3):menu_item-1'b1;
    else if(pulse[1:0]==2)menu_item<=(menu_item==(AUDIO_MENU?6:3))?0:menu_item+1'b1;
   end
   else if(key3_action)edit_mode<=(edit_mode==2)?0:edit_mode+1'b1;
   else if(pulse[1:0]==1)begin
    if(edit_mode==0)next_pulse<=1;
    else if(edit_mode==1 && brightness> -64)brightness<=brightness-8'sd8;
    else if(edit_mode==2 && contrast>2)contrast<=contrast-1'b1;
   end else if(pulse[1:0]==2)begin
    if(edit_mode==0)toggle_pulse<=1;
    else if(edit_mode==1 && brightness<64)brightness<=brightness+8'sd8;
    else if(edit_mode==2 && contrast<8)contrast<=contrast+1'b1;
   end
   if(mute_toggle)audio_mute<=~audio_mute;
   // Opposite requests in the same cycle cancel; same-direction requests
   // produce one step. KEY/menu and keyboard never keep divergent volumes.
   if(volume_up && !volume_down && audio_volume!=31)audio_volume<=audio_volume+1'b1;
   else if(volume_down && !volume_up && audio_volume!=0)audio_volume<=audio_volume-1'b1;
  end
 end
endmodule
