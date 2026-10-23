`timescale 1ns/1ps
module tb_chinese_menu;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg [2:0] keys=0;reg vu=0,vd=0,mt=0;
 wire opened,editing,gamma,debug,mute,n,p;wire [2:0] item;
 wire signed [7:0] brightness;wire [3:0] contrast;wire [4:0] volume;
 integer errors=0,nexts=0,toggles=0,i;
 picture_controls #(.DEBOUNCE_CYCLES(3),.LONG_PRESS_CYCLES(30),
  .BOARD_MENU(1),.AUDIO_MENU(1),.CHINESE_MENU(1),.KEYBOARD_CONTROLS(1),.AUDIO_MUTE_DEFAULT(0)) dut(
  .clk(clk),.rst(rst),.key1_n(keys[0]),.key2_n(keys[1]),.key3_n(keys[2]),
  .next_pulse(n),.toggle_pulse(p),.brightness(brightness),.contrast(contrast),
  .menu_open(opened),.menu_item(item),.menu_edit(editing),.gamma_enable(gamma),
  .debug_enable(debug),.audio_volume(volume),.audio_mute(mute),
  .kb_vol_up(vu),.kb_vol_dn(vd),.kb_mute(mt),
  .ir_vol_up(1'b0),.ir_vol_dn(1'b0),.ir_mute(1'b0),.ir_bri_up(1'b0),.ir_bri_dn(1'b0),.ir_con_up(1'b0),.ir_con_dn(1'b0));
 always @(posedge clk)begin if(n)nexts=nexts+1;if(p)toggles=toggles+1;end
 task settle;begin repeat(12)@(negedge clk);end endtask
 task press;input integer k;begin keys[k]=0;settle;keys[k]=1;settle;end endtask
 task hold3;begin keys[2]=0;repeat(90)@(negedge clk);keys[2]=1;settle;end endtask
 task check;input ok;input [511:0] message;begin
  if(ok!==1)begin errors=errors+1;$display("FAILED Chinese menu %0s item=%d edit=%b",message,item,editing);end
 end endtask
 initial begin
  settle;rst=0;repeat(100)@(negedge clk);check(!opened && !editing,"reset held keys suppressed");
  keys=7;settle;press(0);press(1);check(nexts==1 && toggles==1,"closed legacy playback");
  hold3;check(opened && item==0 && !editing,"long open LIST once");
  press(0);check(item==7,"up wraps eight entries");press(2);check(!opened,"exit item");
  hold3;press(2);check(toggles==1 && editing,"play submenu entry without action");
  press(1);check(toggles==2 && editing,"play submenu toggle");press(2);
  press(1);press(2);check(item==1 && editing,"brightness EDIT");
  repeat(20)press(1);check(brightness==63 && item==1,"brightness upper saturation");
  repeat(30)press(0);check(brightness== -64,"brightness lower saturation after nonmultiple upper limit");
  press(1);check(brightness== -56,"brightness step eight");
  press(2);check(!editing && item==1,"short returns LIST without moving");
  press(1);press(2);repeat(12)press(1);check(contrast==8 && item==2,"contrast upper");
  repeat(12)press(0);check(contrast==2,"contrast lower");press(2);
  press(1);press(2);check(!gamma && editing,"gamma submenu entry without action");
  press(1);check(gamma && editing,"gamma submenu on");press(0);check(!gamma,"gamma off");press(2);
  press(1);press(2);repeat(25)press(1);check(volume==16 && item==4,"volume upper sixteen");
  repeat(25)press(0);check(volume==0,"volume lower");
  vu=1;@(negedge clk);vu=0;settle;check(volume==1,"keyboard shares owner in EDIT");
  keys[0]=0;keys[1]=0;settle;keys=7;settle;check(volume==1 && item==4,"opposing keys ignored");
  hold3;check(!opened && !editing && volume==1,"long exit EDIT retains value");
  hold3;repeat(5)press(1);press(2);check(!mute && editing,"mute submenu entry without action");
  press(1);check(mute && editing,"mute submenu toggle");press(2);
  press(1);press(2);check(!debug && item==6 && editing,"diagnostics submenu entry");
  press(0);check(debug && item==6,"diagnostics submenu toggle");press(2);
  hold3;check(!opened && debug && mute,"long close LIST retains settings");
  rst=1;settle;check(!opened && !editing && brightness==0 && volume==8 && !mute,"reset defaults");
  if(errors==0)$display("ALL PASS tb_chinese_menu: eight-item LIST/SUBMENU, no action on entry, debounce, long/short, saturation, shared controls");
  else $display("FAILED tb_chinese_menu %0d",errors);$finish;
 end
 initial begin #300000;$display("FAILED Chinese menu watchdog");$finish;end
endmodule
