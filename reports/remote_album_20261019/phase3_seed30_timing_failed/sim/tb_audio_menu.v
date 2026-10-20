`timescale 1ns/1ps
module tb_audio_menu;
 reg clk=0,rst=1;reg [2:0] keys=7;always #5 clk=~clk;
 wire opened,mute,n,p;wire [2:0] item;wire [4:0] volume;integer errors=0,k;
 picture_controls #(.DEBOUNCE_CYCLES(3),.BOARD_MENU(1),.AUDIO_MENU(1),.LONG_PRESS_CYCLES(30)) dut(.clk(clk),.rst(rst),.key1_n(keys[0]),.key2_n(keys[1]),.key3_n(keys[2]),.next_pulse(n),.toggle_pulse(p),.menu_open(opened),.menu_item(item),.audio_volume(volume),.audio_mute(mute));
 task settle;begin repeat(12)@(negedge clk);end endtask
 task press;input integer k;begin keys[k]=0;settle;keys[k]=1;settle;end endtask
 task check;input ok;input [511:0] msg;begin if(ok!==1)begin errors=errors+1;$display("FAILED audio menu %0s",msg);end end endtask
 initial begin
  settle;rst=0;settle;check(mute && volume==8,"safe reset");keys[2]=0;repeat(90)@(negedge clk);keys[2]=1;settle;check(opened && item==0,"open");
  repeat(4)press(1);check(item==4,"mute menu");press(2);check(!mute,"unmute");press(2);check(mute,"mute");
  press(1);repeat(40)press(2);check(volume==0,"down saturates");press(1);repeat(40)press(2);check(volume==31,"up saturates");
  press(1);check(item==0,"wrap 7 entries");press(0);check(item==6,"reverse wrap");
  rst=1;settle;check(mute && volume==8 && !opened,"reset");
  if(errors==0)$display("ALL PASS tb_audio_menu");else $display("FAILED audio menu %0d",errors);$finish;
 end
endmodule
