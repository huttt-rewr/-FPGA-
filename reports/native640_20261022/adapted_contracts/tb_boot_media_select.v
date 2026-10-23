`timescale 1ns/1ps
// Real boot/SD/pixel frequencies and the actual 10 ms startup supervisor.
// Check the mode seen when consumers leave reset, then exercise user reset
// with and without KEY1. Late presses must not remount a live filesystem.
module tb_boot_media_select;
 reg boot_clk=0,sd_clk=0,video_clk=0;
 always #20 boot_clk=~boot_clk;
 always #5 sd_clk=~sd_clk;
 always #20 video_clk=~video_clk;
 reg rst_n=0,pll_lock=0,key1_n=1;
 wire select_rst_n=rst_n && pll_lock;
 wire movie_mode,legacy_mode,rst_all,rst_sd,rst_video;
 reg [1:0] mode_sd=0,mode_video=0;
 boot_media_select #(.DEFAULT_MOVIE(1)) dut(
  .clk(boot_clk),.rst_n(select_rst_n),.key1_n(key1_n),.movie_mode(movie_mode),
  .select_valid(1'b0),.select_movie(1'b1),.restart_request());
 boot_media_select legacy(
  .clk(boot_clk),.rst_n(select_rst_n),.key1_n(key1_n),.movie_mode(legacy_mode),
  .select_valid(1'b0),.select_movie(1'b1),.restart_request());
 board_supervisor supervisor(.clk(boot_clk),.arst(!select_rst_n),
  .enable(1'b0),.heartbeat_toggle(1'b0),.reset_request(rst_all),.watchdog_resets());
 reset_sync sd_reset(.clk(sd_clk),.arst(rst_all),.rst(rst_sd));
 reset_sync video_reset(.clk(video_clk),.arst(rst_all),.rst(rst_video));
 always @(posedge sd_clk or negedge rst_n)
  if(!rst_n)mode_sd<=0;else mode_sd<={mode_sd[0],movie_mode};
 always @(posedge video_clk or negedge rst_n)
  if(!rst_n)mode_video<=0;else mode_video<={mode_video[0],movie_mode};
 task check_boot;
  input expected;
  begin
   wait(!rst_sd && !rst_video);
   @(negedge boot_clk);
   if(movie_mode!==expected || mode_sd[1]!==expected || mode_video[1]!==expected || legacy_mode!==!expected)
    $fatal(1,"FAILED mode at consumer reset release: expected=%b boot=%b sd=%b video=%b legacy=%b",expected,movie_mode,mode_sd[1],mode_video[1],legacy_mode);
  end
 endtask
 task user_reset;
  begin
   @(negedge boot_clk);rst_n=0;
   repeat(8)@(negedge boot_clk);
   rst_n=1;
  end
 endtask
 initial begin
  // Power-up: PLL locks after external reset is released. No key required.
  #103;rst_n=1;
  #207;pll_lock=1;
  check_boot(1);
  // Normal playback presses are not mode switches.
  key1_n=0;repeat(2048)@(negedge boot_clk);
  if(movie_mode!==1 || legacy_mode!==0)$fatal(1,"FAILED late press changed mode");
  key1_n=1;repeat(2048)@(negedge boot_clk);
  // Held KEY1 during user reset explicitly selects photos.
  key1_n=0;user_reset;check_boot(0);
  key1_n=1;repeat(2048)@(negedge boot_clk);
  if(movie_mode!==0 || legacy_mode!==1)$fatal(1,"FAILED key release changed latched mode");
  // A normal reset returns to automatic video even with PLL continuously locked.
  user_reset;check_boot(1);
  // PLL restart is also a fresh boot selection.
  @(negedge boot_clk);pll_lock=0;
  repeat(8)@(negedge boot_clk);pll_lock=1;
  check_boot(1);
  $display("ALL PASS tb_boot_media_select: default video at consumer release, held-key photo override, normal reset, late keys, PLL restart, legacy polarity");
  $finish;
 end
 initial begin #50000000;$fatal(1,"FAILED boot selection timeout");end
endmodule
