`timescale 1ns/1ps
// Physical mapping from the current pin.adc: A2 reset, B2 user1, C1 user2, B1 user3.
// Exercise real controls/router/selector/supervisor together, with short counters.
module tb_key1_reset;
 reg sd=0,boot=0;always #5 sd=~sd;always #20 boot=~boot;
 reg a2_n=0,b2_n=1,c1_n=1,b1_n=1,heartbeat=0;
 always #160 heartbeat=~heartbeat;
 wire rst_all,rst_controls,rst_video,movie,restart,sv,sm,bv,bm,bt;
 wire ni,nv,nw,rd,ru,np,nm,na,opened,editing,page,next_p,toggle_p;
 wire [2:0] item;wire signed [7:0] brightness;
 integer errors=0,restarts=0,global_resets=0,nexts=0;
 board_supervisor #(.POWER_CYCLES(4),.TIMEOUT_CYCLES(100)) supervisor(
  .clk(boot),.arst(!a2_n || restart),.enable(1'b1),.heartbeat_toggle(heartbeat),.reset_request(rst_all),.watchdog_resets());
 reset_sync controls_reset(sd,rst_all,rst_controls);
 reset_sync video_reset(boot,rst_all,rst_video);
 picture_controls #(.DEBOUNCE_CYCLES(3),.LONG_PRESS_CYCLES(30),.BOARD_MENU(1),.AUDIO_MENU(1),.CHINESE_MENU(1),.MEDIA_MENU(1)) controls(
  .clk(sd),.rst(rst_controls),.key1_n(b2_n),.key2_n(c1_n),.key3_n(b1_n),
  .next_pulse(next_p),.toggle_pulse(toggle_p),.brightness(brightness),.contrast(),.edit_mode(),
  .menu_open(opened),.menu_item(item),.menu_edit(editing),.menu_page(page),
  .image_next(ni),.movie_next(nv),.wav_next(nw),.res_down(rd),.res_up(ru),
  .kb_vol_up(1'b0),.kb_vol_dn(1'b0),.kb_mute(1'b0),
  .ir_vol_up(1'b0),.ir_vol_dn(1'b0),.ir_mute(1'b0),.ir_bri_up(1'b0),.ir_bri_dn(1'b0),.ir_con_up(1'b0),.ir_con_dn(1'b0));
 media_button_request #(.DEBOUNCE_CYCLES(3),.HOLD_CYCLES(16)) chord(
  .clk(boot),.rst_n(a2_n),.key1_n(b2_n),.key2_n(c1_n),.movie_mode(movie),
  .select_valid(bv),.select_movie(bm),.select_toggle(bt));
 menu_media_request router(sd,a2_n,rst_controls,movie,1'b0,1'b0,bv,bm,bt,ni,nv,nw,sv,sm,np,nm,na);
 boot_media_select #(.SETTLE_CYCLES(4),.DEFAULT_MOVIE(1),.RUNTIME_SELECT(1)) selector(
  .clk(boot),.rst_n(a2_n),.key1_n(b2_n),.movie_mode(movie),.select_valid(sv),.select_movie(sm),.restart_request(restart));
 always @(posedge restart)restarts=restarts+1;
 always @(posedge rst_all)global_resets=global_resets+1;
 always @(posedge sd)if(next_p)nexts=nexts+1;
 task wait_sd;input integer n;begin repeat(n)@(negedge sd);end endtask
 task check;input yes;input [511:0] text;begin
  if(yes!==1)begin errors=errors+1;$display("FAILED key/reset %0s",text);end
 end endtask
 task press_b2;begin b2_n=0;wait_sd(150);b2_n=1;wait_sd(150);end endtask
 initial begin
  wait_sd(8);a2_n=1;wait_sd(150);global_resets=0;
  repeat(8)press_b2;
  check(nexts==8 && !rst_all && !rst_video && restarts==0 && global_resets==0,"B2 single/held presses are next-file events, not whole-system resets");
  b1_n=0;wait_sd(80);b1_n=1;wait_sd(30);check(opened,"open menu using B1");
  press_b2;check(page && item==3 && !editing && !rd,"B2 menu LIST navigates, no resolution request");
  repeat(4)press_b2;
  check(!rst_all && !rst_video && restarts==0 && global_resets==0,"B2 menu navigation never resets HDMI");
  a2_n=0;#1;check(rst_all && rst_video,"A2 asserts asynchronous global/video reset immediately");
  wait_sd(80);check(rst_controls && !opened,"A2 held clears menu and controls");
  a2_n=1;wait_sd(150);check(!rst_all && !rst_video && !rst_controls,"A2 release restarts system");
  b2_n=0;c1_n=0;wait_sd(200);b2_n=1;c1_n=1;wait_sd(150);
  check(restarts==1 && global_resets==2 && !movie,"intentional long B2+C1 mode switch does restart");
  if(errors==0)$display("ALL PASS tb_key1_reset: B2 repeated/long/menu presses no global or HDMI reset; A2 direct reset; deliberate B2+C1 mode change restarts once");
  else $display("FAILED tb_key1_reset %0d",errors);$finish;
 end
 initial begin #200000;$display("FAILED key/reset watchdog");$finish;end
endmodule
