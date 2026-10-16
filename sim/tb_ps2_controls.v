`timescale 1ns/1ps
module tb_ps2_controls;
 reg clk=0,rst=1,valid=0,released=0,extended=0,rx_error=0;
 reg [7:0] code=0;
 wire n,p,t,up,dn,m,o,r,f,is,as,pending;
 wire [3:0] digit;
 wire [4:0] volume;wire mute;
 reg [2:0] keys=7;
 wire opened;wire [2:0] item;
 integer errors=0,nexts=0,prevs=0,toggles=0,osds=0,mutes=0,ress=0,fpss=0,images=0,audios=0;
 reg [7:0] selected_image=0,selected_audio=0;
 integer i;
 always #5 clk=~clk;
 ps2_controls #(.PENDING_TIMEOUT_CYCLES(100)) dut(.clk(clk),.rst(rst),.scan_code(code),
  .key_valid(valid),.key_release(released),.key_extended(extended),.receive_error(rx_error),
  .ev_next(n),.ev_prev(p),.ev_toggle_auto(t),.ev_vol_up(up),.ev_vol_dn(dn),
  .ev_mute(m),.ev_osd(o),.ev_res(r),.ev_fps(f),.ev_digit(digit),
  .ev_image_select(is),.ev_audio_select(as),.audio_pending(pending));
 picture_controls #(.DEBOUNCE_CYCLES(2),.BOARD_MENU(1),.AUDIO_MENU(1),
  .LONG_PRESS_CYCLES(30),.KEYBOARD_CONTROLS(1),.AUDIO_MUTE_DEFAULT(0)) buttons(
  .clk(clk),.rst(rst),.key1_n(keys[0]),.key2_n(keys[1]),.key3_n(keys[2]),
  .next_pulse(),.toggle_pulse(),.brightness(),.contrast(),.edit_mode(),
  .menu_open(opened),.menu_item(item),.gamma_enable(),.debug_enable(),.debug_page(),
  .audio_volume(volume),.audio_mute(mute),.kb_vol_up(up),.kb_vol_dn(dn),.kb_mute(m));
 always @(posedge clk)begin
  if(n)nexts=nexts+1;if(p)prevs=prevs+1;if(t)toggles=toggles+1;
  if(o)osds=osds+1;if(m)mutes=mutes+1;if(r)ress=ress+1;if(f)fpss=fpss+1;
  if(is)begin images=images+1;selected_image={4'd0,digit};end
  if(as)begin audios=audios+1;selected_audio={4'd0,digit};end
 end
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAIL ps2 controls %0s",msg);end
 end endtask
 task key_event;input [7:0] value;input ex,br;begin
  @(negedge clk);code=value;extended=ex;released=br;valid=1;
  @(negedge clk);valid=0;repeat(3)@(negedge clk);
 end endtask
 task tap;input [7:0] value;input ex;begin key_event(value,ex,0);key_event(value,ex,1);end endtask
 task board_press;input integer which;begin
  keys[which]=0;repeat(10)@(negedge clk);keys[which]=1;repeat(10)@(negedge clk);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;repeat(12)@(negedge clk);
  check(volume==8 && !mute,"keyboard profile reset defaults");
  tap(8'h74,0);tap(8'h6b,0);check(nexts==0 && prevs==0,"unextended keypad codes are not arrows");
  tap(8'h74,1);tap(8'h6b,1);check(nexts==1 && prevs==1,"extended arrows");
  repeat(4)key_event(8'h29,0,0);check(toggles==1,"held space toggles once");
  key_event(8'h29,0,1);tap(8'h29,0);check(toggles==2,"release rearms toggle");
  repeat(4)key_event(8'h44,0,0);key_event(8'h44,0,1);check(osds==1,"held O toggles once");
  repeat(3)key_event(8'h3a,0,0);key_event(8'h3a,0,1);check(mutes==1 && mute,"one mute register");
  tap(8'h2d,0);tap(8'h2b,0);check(ress==1 && fpss==1,"stable R/F event interface");
  // Volume accepts keyboard typematic, clips to the existing 0..31 range.
  repeat(40)key_event(8'h75,1,0);key_event(8'h75,1,1);check(volume==31,"up saturation");
  repeat(40)key_event(8'h72,1,0);key_event(8'h72,1,1);check(volume==0,"down saturation");
  tap(8'h25,0);check(images==1 && selected_image==4,"image digit");
  tap(8'h1c,0);check(pending,"A arms audio prefix");
  tap(8'h26,0);check(audios==1 && selected_audio==3 && !pending,"A+3 is audio only");
  tap(8'h1c,0);tap(8'h76,0);tap(8'h16,0);
  check(images==2 && selected_image==1 && audios==1,"Esc cancels A prefix");
  tap(8'h1c,0);repeat(110)@(negedge clk);tap(8'h1e,0);
  check(!pending && images==3 && selected_image==2 && audios==1,"audio prefix timeout");
  // A dropped break/BAT must not leave a toggle key stuck until global reset.
  key_event(8'h44,0,0);@(negedge clk);rx_error=1;@(negedge clk);rx_error=0;
  tap(8'h44,0);check(osds==3,"receive error clears held-key table");
  // Existing KEY3 long/menu confirmations still update the same audio state.
  keys[2]=0;repeat(60)@(negedge clk);keys[2]=1;repeat(15)@(negedge clk);
  check(opened && item==0,"KEY menu opens");
  repeat(4)board_press(1);board_press(2);check(!mute,"board and keyboard share mute");
  board_press(1);board_press(1);board_press(2);check(volume==1,"board volume uses shared register");
  tap(8'h75,1);check(volume==2,"keyboard observes board-updated volume");
  if(errors==0)$display("ALL PASS tb_ps2_controls: Set2 mapping, break/typematic policy, A+digit/Esc/timeout, shared KEY/keyboard audio registers");
  else $display("FAILED tb_ps2_controls errors=%0d",errors);
  $finish;
 end
 initial begin #1000000;$display("FAILED watchdog tb_ps2_controls");$finish;end
endmodule
