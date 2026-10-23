// Commands in SD clock domain. Internal action bytes, not a UART input.
// UART is intentionally absent: this block converts decoded IR actions into
// one-cycle events. Persistent picture/audio state belongs to picture_controls/top.
module player_control(input clk,input rst,input [7:0] ir_command,input ir_valid,
 output reg next_pulse,output reg prev_pulse,output reg toggle_pulse,
 output reg vol_up,output reg vol_dn,output reg mute_toggle,
 output reg bri_up,output reg bri_dn,output reg con_up,output reg con_dn,
 output reg osd_toggle,output reg test_toggle,output reg transition_toggle,
 output reg [1:0] transition_mode,output reg captions_enable,
 output reg scroll_enable,output reg [1:0] slogan_select,
 output reg auto_enh_en,output reg slide_enable,output reg zh_enable,output reg large_clock);
 // Internal action IDs are decoded from the sole NEC map in remote_controls.
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   next_pulse<=0;prev_pulse<=0;toggle_pulse<=0;
   vol_up<=0;vol_dn<=0;mute_toggle<=0;bri_up<=0;bri_dn<=0;con_up<=0;con_dn<=0;
   osd_toggle<=0;test_toggle<=0;transition_toggle<=0;
   transition_mode<=1;captions_enable<=1;scroll_enable<=1;slogan_select<=0;
   auto_enh_en<=0;slide_enable<=0;zh_enable<=0;large_clock<=0;
  end else begin
   next_pulse<=0;prev_pulse<=0;toggle_pulse<=0;
   vol_up<=0;vol_dn<=0;mute_toggle<=0;bri_up<=0;bri_dn<=0;con_up<=0;con_dn<=0;
   osd_toggle<=0;test_toggle<=0;transition_toggle<=0;
   if(ir_valid) case(ir_command)
    "n":next_pulse<=1; "p":prev_pulse<=1; "b":toggle_pulse<=1;
    "+":vol_up<=1; "-":vol_dn<=1; "m":mute_toggle<=1;
    "o":osd_toggle<=1; "]":bri_up<=1; "[":bri_dn<=1;
    "}":con_up<=1; "{":con_dn<=1;
    "a":auto_enh_en<=~auto_enh_en; "s":slide_enable<=~slide_enable;
    "h":zh_enable<=~zh_enable; "l":large_clock<=~large_clock;
    "t":test_toggle<=1; "e":transition_toggle<=1;
    "c":captions_enable<=~captions_enable; "r":scroll_enable<=~scroll_enable;
    "g":slogan_select<=(slogan_select==2)?0:slogan_select+1'b1;
    default:;
   endcase
   // transition_mode 输出未接；实际由 top.v 的 sw_transition_mode+ir_transition_offset 生效。
   if(ir_valid && ir_command=="e")transition_mode<=transition_mode+1'b1;
  end
 end
endmodule
