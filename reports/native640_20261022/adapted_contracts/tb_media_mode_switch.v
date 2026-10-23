`timescale 1ns/1ps
// Real PS/2 receiver, persistent request, CDC and supervisor reset wiring.
// Media consumers must see the new choice only after the full startup hold.
module tb_media_mode_switch;
 reg sd_clk=0,boot_clk=0,video_clk=0;
 always #5 sd_clk=~sd_clk;
 always #20 boot_clk=~boot_clk;
 initial begin #7;forever #20 video_clk=~video_clk;end
 reg rst_n=0,pll_lock=0,key1_n=1,key2_n=1,pclk=1,pdata=1,watchdog_enable=0,heartbeat=0,heartbeat_enable=1;
 wire selector_rst_n=rst_n && pll_lock;
 wire rst_all,rst_controls,rst_video,restart,movie,valid_choice,movie_choice,button_valid,button_movie;
 wire [7:0] code;
 wire valid,released,extended,receive_error;
 reg [1:0] movie_sd=0,movie_video=0;
 integer restart_count=0;
 always #100 if(heartbeat_enable)heartbeat=~heartbeat;
 board_supervisor #(.POWER_CYCLES(50000),.TIMEOUT_CYCLES(10000)) supervisor(
  .clk(boot_clk),.arst(!selector_rst_n || restart),.enable(watchdog_enable),
  .heartbeat_toggle(heartbeat),.reset_request(rst_all),.watchdog_resets());
 reset_sync control_reset(.clk(sd_clk),.arst(rst_all),.rst(rst_controls));
 reset_sync video_reset(.clk(video_clk),.arst(rst_all),.rst(rst_video));
 ps2_keyboard keyboard(.clk(sd_clk),.rst(rst_controls),.ps2_clk(pclk),.ps2_data(pdata),
  .scan_code(code),.key_valid(valid),.key_release(released),
  .key_extended(extended),.receive_error(receive_error));
 media_keyboard_request request(.clk(sd_clk),.rst_n(selector_rst_n),.controls_reset(rst_controls),
  .scan_code(code),.key_valid(valid),.key_release(released),
  .key_extended(extended),.receive_error(receive_error),
  .select_valid(valid_choice),.select_movie(movie_choice));
 media_button_request #(.DEBOUNCE_CYCLES(4),.HOLD_CYCLES(30)) buttons(
  .clk(boot_clk),.rst_n(selector_rst_n),.key1_n(key1_n),.key2_n(key2_n),
  .movie_mode(movie),.select_valid(button_valid),.select_movie(button_movie));
 boot_media_select #(.DEFAULT_MOVIE(1),.RUNTIME_SELECT(1)) selector(
  .clk(boot_clk),.rst_n(selector_rst_n),.key1_n(key1_n),.movie_mode(movie),
  .select_valid(valid_choice || button_valid),
  .select_movie(button_valid?button_movie:movie_choice),.restart_request(restart));
 always @(posedge sd_clk or negedge rst_n)
  if(!rst_n)movie_sd<=0;else movie_sd<={movie_sd[0],movie};
 always @(posedge video_clk or negedge rst_n)
  if(!rst_n)movie_video<=0;else movie_video<={movie_video[0],movie};
 always @(posedge restart)restart_count=restart_count+1;
 task send_bit;input b;begin
  pdata=b;#20000;pclk=0;#50000;pclk=1;#30000;
 end endtask
 task send_byte;input [7:0] value;input bad_parity;integer j;begin
  send_bit(0);for(j=0;j<8;j=j+1)send_bit(value[j]);
  send_bit((~^value)^bad_parity);send_bit(1);pdata=1;#20000;
 end endtask
 task check_ready;input expected;begin
  wait(!rst_controls && !rst_video);@(negedge boot_clk);
  if(movie!==expected || movie_sd[1]!==expected || movie_video[1]!==expected)
   $fatal(1,"FAILED media mode at consumer release");
 end endtask
 task check_switch;input expected;input integer count;begin
  // A mode switch must initiate an actual reset, not just change a video mux.
  if(!rst_all || restart_count!=count)$fatal(1,"FAILED missing/surplus switch reset mode=%b rst=%b req=%b count=%0d expected=%0d choice=%b/%b",movie,rst_all,restart,restart_count,count,valid_choice,movie_choice);
  check_ready(expected);
  repeat(100)@(negedge boot_clk);
  if(rst_all || restart_count!=count)$fatal(1,"FAILED reset loop after switch");
 end endtask
 task check_unchanged;input expected;input integer count;begin
  repeat(100)@(negedge boot_clk);
  if(rst_all || movie!==expected || restart_count!=count)$fatal(1,"FAILED unwanted mode switch rst_all=%b movie=%b expected=%b restart=%0d expected_restart=%0d valid=%b choice=%b",rst_all,movie,expected,restart_count,count,valid_choice,movie_choice);
 end endtask
 task board_chord;input expected;input integer count;begin
  key1_n=0;key2_n=0;repeat(45)@(negedge boot_clk);
  if(!rst_all || restart_count!=count || movie!==expected)
   $fatal(1,"FAILED physical button chord mode=%b expected=%b reset=%b restarts=%0d expected_count=%0d",movie,expected,rst_all,restart_count,count);
  key1_n=1;key2_n=1;check_ready(expected);repeat(100)@(negedge boot_clk);
  if(rst_all || restart_count!=count)$fatal(1,"FAILED physical chord release restart loop");
 end endtask
 initial begin
  #103;rst_n=1;#207;pll_lock=1;check_ready(1);
  send_byte(8'h4d,0);check_switch(0,1); // P from default video
  send_byte(8'h4d,0);check_unchanged(0,1); // typematic P does not restart
  send_byte(8'hf0,0);send_byte(8'h2a,0);check_unchanged(0,1); // break V ignored
  send_byte(8'he0,0);send_byte(8'h2a,0);check_unchanged(0,1); // E0 V ignored
  send_byte(8'h2a,1);check_unchanged(0,1); // bad parity ignored
  send_byte(8'h74,0);check_unchanged(0,1); // unrelated key ignored
  send_byte(8'h2a,0);check_switch(1,2); // V returns to video
  send_byte(8'h2a,0);check_unchanged(1,2);
  send_byte(8'h4d,0);check_switch(0,3); // second P still works
  // A watchdog reset must preserve the requested photo mode.
  heartbeat_enable=0;watchdog_enable=1;wait(rst_all);
  wait(!rst_all);heartbeat_enable=1;watchdog_enable=0;check_ready(0);
  check_unchanged(0,3);
  // Physical user reset clears the override and restores default video.
  @(negedge boot_clk);rst_n=0;repeat(8)@(negedge boot_clk);rst_n=1;
  check_ready(1);
  if(valid_choice)$fatal(1,"FAILED override survives physical reset");
  key1_n=0;rst_n=0;repeat(8)@(negedge boot_clk);rst_n=1;check_ready(0);
  key1_n=1;send_byte(8'h2a,0);check_switch(1,4); // V also works after boot override
  // PLL loss starts a fresh selection and clears runtime commands.
  send_byte(8'h4d,0);check_switch(0,5);
  board_chord(1,6);board_chord(0,7);
  pll_lock=0;repeat(8)@(negedge boot_clk);pll_lock=1;check_ready(1);
  if(valid_choice)$fatal(1,"FAILED override survives PLL restart");
  $display("ALL PASS tb_media_mode_switch: real PS2 P/V, repeated keys, break/E0/parity rejection, CDC, reset hold, watchdog retention, user/PLL reset, KEY1 compatibility");
  $finish;
 end
 initial begin #200000000;$fatal(1,"FAILED mode switch timeout");end
endmodule
