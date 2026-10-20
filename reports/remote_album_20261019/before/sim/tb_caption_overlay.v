`timescale 1ns/1ps
module tb_caption_overlay;
 reg clk=0,rst=1,vs=1,de=0,en=1,scroll=0;always #5 clk=~clk;
 reg [23:0] rgb=24'h804020;reg [1:0] slogan=0,mode=1;
 wire ov,od;wire [23:0] color;
 integer errors=0,x,y,i,n,fd;
 reg [23:0] snap;reg [9:0] position;
 caption_overlay #(.CLK_HZ(1000)) dut(clk,rst,vs,de,rgb,en,scroll,slogan,mode,ov,od,color);
 task check;input ok;input [511:0] msg;begin
  if(!ok)begin errors=errors+1;$display("FAIL %0s",msg);end
 end endtask
 task frame_start;begin vs=0;repeat(3)@(negedge clk);vs=1;repeat(3)@(negedge clk);end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  repeat(1000)@(negedge clk);
  check(dut.sec_units==1 && dut.sec_tens==0,"timer counts clock cycles");
  frame_start;snap=dut.displayed_time;
  check(snap==24'h000001,"time published at frame boundary");
  // Record the actual raster produced by the RTL for visual inspection.
  fd=$fopen("../reports/effects_20261009/caption.ppm","w");
  $fdisplay(fd,"P3\n640 480\n255");
  for(y=0;y<480;y=y+1)begin
   for(x=0;x<640;x=x+1)begin
    de=1;@(posedge clk);#1;
    check(od && ov,"caption sync latency");
    if(y==100 && x==100)check(color==rgb,"uncovered image exact");
    if(y==470 && x==100)check(color==24'h402820,"banner alpha arithmetic");
    if(y==20 && x==448)check(color==24'hffffff,"UP glyph foreground");
    if(y==432 && x==100)check(color==24'hffb040,"fade indicator color");
    $fdisplay(fd,"%0d %0d %0d",color[23:16],color[15:8],color[7:0]);
    @(negedge clk);
   end
   de=0;repeat(160)@(negedge clk);
   if(y==100)begin en=0;scroll=1;slogan=1;mode=2;end
   check(dut.displayed_time==snap && dut.enabled && dut.scroll_x==0 && dut.selected==0,
    "time, slogan and controls do not tear midframe");
  end
  $fclose(fd);
  frame_start;
  check(!dut.enabled && dut.selected==1 && dut.selected_mode==2 && dut.scroll_x==0,"boundary applies controls and restarts new slogan");
  de=1;@(posedge clk);#1;check(color==rgb,"disabled captions bypass");@(negedge clk);de=0;
  en=1;frame_start;position=dut.scroll_x;
  repeat(640)frame_start;
  check(dut.scroll_x==position,"pixel scrolling wraps exactly at 640");
  scroll=0;frame_start;position=dut.scroll_x;
  repeat(5)frame_start;check(dut.scroll_x==position,"pause holds scroll position");
  // Clock has run for several minutes; BCD remains valid, displayed time stays frame coherent.
  check(dut.sec_tens<6 && dut.sec_units<10 && dut.min_tens<6 && dut.min_units<10,"BCD carry validity");
  @(negedge clk);rst=1;@(negedge clk);
  check(!od && dut.displayed_time==0 && dut.scroll_x==0,"reset clears timestamp and position");
  if(errors==0)$display("ALL PASS tb_caption_overlay: alpha, font, elapsed timer, frame snapshots, pause/wrap, reset");
  else $display("FAILED tb_caption_overlay %0d",errors);
  $finish;
 end
 initial begin #5000000;$display("FAILED watchdog tb_caption_overlay");$finish;end
endmodule
