`timescale 1ns/1ps
module tb_switch_controls;
 reg clk=0,pclk=0,rst=1;
 always #5 clk=~clk;
 always #7 pclk=~pclk;
 reg [3:0] sw=15;
 wire captions,scrolling;wire [1:0] mode;
 wire [3:0] video;
 reg blank=0,req=0;reg [1:0] requested=0;
 wire ack,visible,busy;wire [1:0] active,effect;
 wire [5:0] level;wire [9:0] offset;
 integer errors=0,i,j;
 switch_controls #(.DEBOUNCE_CYCLES(5)) dut(clk,rst,sw,captions,scrolling,mode);
 cdc_snapshot #(.WIDTH(4)) cdc(clk,rst,{mode,scrolling,captions},pclk,rst,video);
 frame_swap #(.ENABLE_EFFECTS(1)) swap(.clk(pclk),.rst(rst),.vblank(blank),
  .request_toggle(req),.requested_buffer(requested),.ack_toggle(ack),
  .active_buffer(active),.display_valid(visible),.transition_mode(video[3:2]),
  .effect_mode(effect),.fade_level(level),.slide_offset(offset),.transition_busy(busy));
 task check;input ok;input [511:0] msg;begin
  if(ok!==1'b1) begin errors=errors+1;$display("FAILED %0s",msg);end
 end endtask
 task settle;begin repeat(70) @(negedge clk);end endtask
 task frame;begin
  @(negedge pclk);blank=1;@(negedge pclk);blank=0;
  repeat(6) @(negedge pclk);
 end endtask
 task change;begin
  @(negedge pclk);requested=active==0?1:0;req=~req;
  repeat(7) @(negedge pclk);frame;
 end endtask
 task finish_animation;input [1:0] kind;begin
  check(busy && effect==kind,"captured effect");
  for(j=0;j<64;j=j+1)begin
   if(j<63)check(busy && ack!=req && effect==kind,"transaction owns buffers and mode");
   frame;
  end
  check(!busy && ack==req && active==requested,"complete animation and acknowledge");
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;settle;
  check({mode,scrolling,captions}==0 && video==0,"all OFF: no captions, cut");
  // Raw contacts change asynchronously, then bounce back before debounce expires.
  #2;sw=0;repeat(2)@(negedge clk);sw=15;settle;
  check({mode,scrolling,captions}==0,"contact glitch ignored");
  for(i=0;i<16;i=i+1)begin
   @(negedge clk);sw=~i;settle;
   check({mode,scrolling,captions}==i && video==i,"all sixteen switch combinations and CDC");
   settle;check({mode,scrolling,captions}==i,"held switch does not toggle repeatedly");
  end
  // Holding switches through reset must restore their physical state, not a toggle default.
  rst=1;repeat(4)@(negedge clk);rst=0;settle;
  check(video==15,"held ON through reset");
  change;check(visible && !busy && ack==req,"first image bypasses any transition");
  change;finish_animation(1);
  change;finish_animation(2);
  // Changing switches halfway through an animation cannot change the captured mode.
  change;sw=15;settle;
  check(video==0 && busy && effect==1,"mode changed for next transaction only");
  finish_animation(1);
  change;check(!busy && ack==req,"subsequent image uses new cut mode");
  sw=4'b1000;settle;change;finish_animation(1);
  sw=4'b0100;settle;change;finish_animation(2);
  if(errors==0)$display("ALL PASS tb_switch_controls: contact bounce, 16 states, stable holds, reset, CDC, alternating transitions, busy mode capture");
  else $display("FAILED tb_switch_controls %0d",errors);
  $finish;
 end
 initial begin #1000000;$display("FAILED watchdog tb_switch_controls");$finish;end
endmodule
