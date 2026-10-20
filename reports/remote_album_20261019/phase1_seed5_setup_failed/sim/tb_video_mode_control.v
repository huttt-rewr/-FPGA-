`timescale 1ns/1ps
module tb_video_mode_control;
 reg boot=0,sd=0,c25=0,c40=0,rst=1,done=0,supports=1;
 always #20 boot=~boot;always #5 sd=~sd;always #20 c25=~c25;always #12.5 c40=~c40;
 reg [1:0] request=1;wire ready,mode,fallback;wire [1:0] active;
 wire pixel=mode?c40:c25;wire video_reset,sd_reset,hdmi_vga_reset;
 video_mode_control #(.QUIET_CYCLES(8),.SETTLE_CYCLES(32)) dut(.clk(boot),.rst(rst),.edid_done(done),
 .supports_800(supports),.requested_mode(request),.ready(ready),.mode_800(mode),.active_mode(active),.fallback(fallback));
 reset_sync vr(pixel,rst | !ready,video_reset);
 reset_sync sr(sd,rst | !ready,sd_reset);
 reset_sync vg(pixel,rst | mode | (done && video_reset),hdmi_vga_reset);
 integer errors=0,ticks=0;reg last_mode=0;integer quiet_ticks=0,changes=0;
 always @(posedge boot)begin
  if(!ready)quiet_ticks=quiet_ticks+1;else quiet_ticks=0;
 end
 always @(mode)if(!rst && mode!=last_mode)begin
  if(!video_reset || !sd_reset || !hdmi_vga_reset || ready || quiet_ticks<8)begin errors=errors+1;$display("FAIL mode switch before local reset assertion");end
  last_mode=mode;changes=changes+1;
 end
 always @(posedge pixel)if(!video_reset)ticks=ticks+1;
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAIL mode controller %0s",msg);end
 end endtask
 task select_mode;input [1:0] value;input expected_clock;begin
  @(negedge boot);request=value;wait(!ready);wait(ready);repeat(6)@(negedge boot);
  check(active==value && mode==expected_clock && !video_reset && !sd_reset,"request applied after reset+settle");
 end endtask
 initial begin
  repeat(5)@(negedge boot);rst=0;repeat(10)@(negedge boot);check(!ready,"EDID gate");check(!hdmi_vga_reset,"VGA EDID core can run before acquisition completes");done=1;
  // Video reset and core reset each synchronize release through three stages.
  wait(ready);repeat(8)@(negedge boot);check(active==1 && !mode && !hdmi_vga_reset,"default VGA and core release");
  select_mode(2,1);select_mode(0,0);select_mode(1,0);select_mode(2,1);select_mode(1,0);
  supports=0;select_mode(2,0);check(fallback,"SVGA unsupported falls back to VGA");
  select_mode(1,0);supports=1;
  @(negedge boot);request=2;wait(!ready);repeat(3)@(negedge boot);request=0;
  wait(active==0 && ready);repeat(6)@(negedge boot);check(!mode,"new request during transition eventually wins");
  rst=1;repeat(4)@(negedge boot);request=1;done=0;rst=0;repeat(5)@(negedge boot);
  check(!ready && active==1 && !mode,"watchdog restart resets negotiation");
  check(changes>=4 && ticks>0,"both clocks exercised");
  if(errors==0)$display("ALL PASS tb_video_mode_control: quiesce/reset-before-mux, VGA/SVGA/back, EDID fallback, pending requests, restart, EDID boot exception and runtime HDMI reset");
  else $display("FAILED mode controller errors=%0d",errors);
  $finish;
 end
 initial begin #100000;$display("FAILED mode watchdog");$finish;end
endmodule
