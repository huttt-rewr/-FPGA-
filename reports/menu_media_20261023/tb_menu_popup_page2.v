`timescale 1ns/1ps
module tb_menu_popup_page2;
 reg clk=0,rst=1,vs=1,de=1,opened=0,mode=0;
 reg signed [7:0] brightness=0;reg [3:0] contrast=4;
 wire ov,od;wire [23:0] rgb;
 integer errors=0,i,mode_index;
 always #5 clk=~clk;
 // Scale seconds down for deterministic cycle-by-cycle timeout testing.
 menu_overlay #(.MEDIA_MENU(1),.VGA_CLOCK_HZ(16),.SVGA_CLOCK_HZ(24),.POPUP_SECONDS(2)) dut(
  .clk(clk),.rst(rst),.vs(vs),.de(de),.x(10'd8),.y(10'd8),.rgb(24'h305070),
  .menu_open(opened),.menu_item(3'd1),.edit_mode(1'b1),.auto_play(1'b0),
  .brightness(brightness),.contrast(contrast),.volume(5'd8),.mute(1'b0),
  .gamma_enable(1'b0),.debug_enable(1'b0),.out_vs(ov),.out_de(od),.out_rgb(rgb),.mode_800(mode),.menu_page(1'b1));
 task check;input condition;input [511:0] text;begin
  if(condition!==1'b1)begin errors=errors+1;$display("FAILED popup %0s mode=%b ticks=%d",text,mode,dut.popup_ticks);end
 end endtask
 task step;begin @(negedge clk);end endtask
 task frame;begin vs=0;step;vs=1;repeat(3)step;end endtask
 initial begin
  repeat(4)step;rst=0;frame;check(rgb==24'h305070,"reset produces no notification");
  for(mode_index=0;mode_index<2;mode_index=mode_index+1)begin
   mode=mode_index;brightness=8;step;
   check(dut.popup_ticks==(mode?48:32),"new external value reloads exact two-second duration");
   frame;check(rgb==24'h101820 && dut.bright_units==8,"external brightness notification");
   repeat(5)step;brightness=-16;step;
   check(dut.popup_ticks==(mode?48:32),"repeated brightness refreshes timeout");
   frame;check(dut.negative && dut.bright_tens==1 && dut.bright_units==6,"latest signed value captured");
   contrast=7;step;check(dut.popup_ticks==(mode?48:32),"contrast also refreshes timeout");
   frame;check(dut.contrast_q==7,"contrast display updates");
   opened=1;step;check(dut.popup_ticks==0,"opening menu cancels pending popup");
   brightness=24;contrast=8;step;frame;
   check(dut.popup_ticks==0 && !dut.popup_visible,"menu edit suppressed");
   opened=0;brightness=32;step;frame;
   check(dut.popup_ticks==0 && rgb==24'h305070,"close edge cannot leak menu value");
   brightness=40;contrast=6;step;
   check(dut.popup_ticks==(mode?48:32),"simultaneous external changes supported");
   for(i=1;i<=(mode?48:32);i=i+1)begin
    step;check(dut.popup_ticks==(mode?48:32)-i,"timeout decrements once each video clock");
   end
   // Timer expiry changes visibility at next blanking edge, never mid-frame.
   frame;check(!dut.popup_visible && rgb==24'h305070,"expires and restores background");
   repeat(4)step;check(dut.popup_ticks==0,"zero timer cannot wrap");
   brightness=-64;step;frame;check(dut.popup_visible,"new adjustment after expiry");
   rst=1;repeat(3)step;check(dut.popup_ticks==0 && !dut.popup_visible,"reset clears popup");
   brightness=0;contrast=4;vs=1;rst=0;repeat(3)step;
  end
  if(errors==0)$display("ALL PASS tb_menu_popup_page2: VGA/SVGA exact two-second clocks, retrigger/latest value, simultaneous edits, menu suppression, expiry/reset");
  else $display("FAILED tb_menu_popup errors=%d",errors);
  $finish;
 end
 initial begin #100000;$display("FAILED popup watchdog");$finish;end
endmodule
