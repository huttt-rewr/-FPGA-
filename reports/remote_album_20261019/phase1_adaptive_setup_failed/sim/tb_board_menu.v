`timescale 1ns/1ps
module tb_board_menu;
 reg clk=0,rst=1;reg [2:0] keys=0;always #5 clk=~clk;
 wire n,p,opened,gamma,debug;wire [1:0] mode,page;wire [2:0] item;
 wire signed [7:0] bright;wire [3:0] contrast;
 integer errors=0,nexts=0,toggles=0;
 picture_controls #(.DEBOUNCE_CYCLES(3),.BOARD_MENU(1),.LONG_PRESS_CYCLES(30)) dut(
  .clk(clk),.rst(rst),.key1_n(keys[0]),.key2_n(keys[1]),.key3_n(keys[2]),
  .next_pulse(n),.toggle_pulse(p),.brightness(bright),.contrast(contrast),.edit_mode(mode),
  .menu_open(opened),.menu_item(item),.gamma_enable(gamma),.debug_enable(debug),.debug_page(page));
 always @(posedge clk)begin if(n)nexts=nexts+1;if(p)toggles=toggles+1;end
 task settle;begin repeat(12)@(negedge clk);end endtask
 task press;input integer k;begin keys[k]=0;settle;keys[k]=1;settle;end endtask
 task hold3;begin keys[2]=0;repeat(90)@(negedge clk);keys[2]=1;settle;end endtask
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAILED menu %0s",msg);end
 end endtask
 initial begin
  settle;rst=0;repeat(100)@(negedge clk);
  check(!opened && mode==0,"held through reset does not activate");
  keys=7;settle;press(0);press(1);
  check(nexts==1 && toggles==1,"legacy playback");
  press(2);press(1);check(mode==1 && bright==8,"short mode, brightness");
  hold3;check(opened && mode==1 && item==0,"long opens once without changing edit mode");
  press(2);check(toggles==2,"confirm play/pause");
  press(1);press(2);check(item==1 && gamma && nexts==1,"gamma via menu");
  press(1);press(2);check(debug && item==2,"debug via menu");
  press(1);press(2);check(page==1 && item==3,"page via menu");
  press(1);check(item==0,"selection wraps down");
  press(0);check(item==3,"selection wraps up");
  keys[0]=0;keys[1]=0;settle;keys=7;settle;check(item==3,"simultaneous keys ignored");
  hold3;check(!opened && mode==1 && gamma && debug,"exit retains options");
  press(0);check(bright==0 && nexts==1,"normal adjustment restored");
  press(2);check(mode==2,"normal mode cycle retained");
  rst=1;settle;check(!opened && !gamma && !debug && page==0,"reset defaults");
  if(errors==0)$display("ALL PASS tb_board_menu: short/long disjoint, menu navigation/actions, legacy modes, reset-held and simultaneous suppression");
  else $display("FAILED tb_board_menu %0d",errors);
  $finish;
 end
 initial begin #100000;$display("FAILED watchdog menu");$finish;end
endmodule
