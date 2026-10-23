`timescale 1ns/1ps
module tb_menu_mode_popup;
 reg clk=0,control_clk=0,rst=1,vs=1,de=0,opened=0,svga=0;
 reg [9:0] x=0,y=0;
 reg [1:0] requested_mode=0;
 reg signed [7:0] brightness=0;
 reg [3:0] contrast=4;
 reg use_keys=0,key1=1,key2=1,key3=1;
 wire [1:0] key_mode;
 wire key_menu;
 wire [2:0] key_video;
 wire menu_open=use_keys?key_video[2]:opened;
 wire [1:0] shortcut_mode=use_keys?key_video[1:0]:requested_mode;
 wire ov,od;
 wire [23:0] rgb;
 integer errors=0,i,m,s,xx,yy,pixels=0;
 reg pixel_check=0;
 reg [1:0] expected_mode=0;
 reg [25:0] expected[0:1];
 reg [15:0] words[0:1439];
 always #5 clk=~clk;
 always #3 control_clk=~control_clk;
 picture_controls #(.BOARD_MENU(1),.CHINESE_MENU(1),.MEDIA_MENU(1),
  .DEBOUNCE_CYCLES(2),.LONG_PRESS_CYCLES(40)) controls(
  .clk(control_clk),.rst(rst),.key1_n(key1),.key2_n(key2),.key3_n(key3),
  .edit_mode(key_mode),.menu_open(key_menu));
 cdc_snapshot #(.WIDTH(3)) keys_cdc(.src_clk(control_clk),.src_rst(rst),
  .src_data({key_menu,key_mode}),.dst_clk(clk),.dst_rst(rst),.dst_data(key_video));
 menu_overlay #(.MODE_POPUP(1),.MEDIA_MENU(1),.VGA_CLOCK_HZ(32),
  .SVGA_CLOCK_HZ(48),.POPUP_SECONDS(2)) dut(
  .clk(clk),.rst(rst),.vs(vs),.de(de),.x(x),.y(y),.rgb(24'h305070),
  .menu_open(menu_open),.menu_item(3'd0),.edit_mode(1'b0),.auto_play(1'b0),
  .brightness(brightness),.contrast(contrast),.volume(5'd8),.mute(1'b0),
  .gamma_enable(1'b0),.debug_enable(1'b0),.mode_800(svga),.menu_page(1'b1),
  .requested_resolution(2'd1),.movie_mode(1'b0),.shortcut_mode(shortcut_mode),
  .out_vs(ov),.out_de(od),.out_rgb(rgb));
 task check;input condition;input [639:0] text;begin
  if(condition!==1'b1)begin errors=errors+1;$display("FAILED mode popup %0s",text);end
 end endtask
 task step;begin @(negedge clk);end endtask
 task frame;begin vs=0;step;vs=1;repeat(3)step;end endtask
 task press3;input integer hold_cycles;begin
  @(negedge control_clk);key3=0;
  repeat(hold_cycles)@(negedge control_clk);key3=1;
  repeat(25)step;
 end endtask
 function [23:0] reference;
  input integer px,py;integer c,gx,gy,code;
  begin
   reference=24'h305070;
   if(px>=8 && px<152 && py>=8 && py<56)begin
    reference=24'h243040;
    if(px>=16 && px<112 && py>=16 && py<48)begin
     c=(px-16)/32;gx=((px-16)/2)%16;gy=(py-16)/2;code=73;
     case(expected_mode)
      0:if(c<2)code=34+c;
      1:if(c<2)code=38+c;
      2:case(c)0:code=40;1:code=41;2:code=39;endcase
     endcase
     if(words[code*16+gy][15-gx])reference=24'hffff00;
    end
   end
  end
 endfunction
 always @(posedge clk)begin
  if(rst)begin expected[0]=0;expected[1]=0;end
  else begin expected[1]=expected[0];expected[0]={vs,de,de?reference(x,y):24'd0};end
  #1;
  if(pixel_check && !rst && {ov,od,rgb}!==expected[1])begin
   if(errors<8)$display("FAILED mode pixel mode=%d x=%d y=%d actual=%h expected=%h",expected_mode,x,y,{ov,od,rgb},expected[1]);
   errors=errors+1;
  end
  if(pixel_check && od)pixels=pixels+1;
 end
 initial begin
  $readmemh("../src/modules/osd/zh_font.mem",words);
  repeat(5)step;rst=0;frame;
  check(dut.popup_ticks==0 && !dut.popup_visible,"boot stays clean");
  for(s=0;s<2;s=s+1)begin
   svga=s;
   for(m=1;m<=3;m=m+1)begin
    requested_mode=m%3;expected_mode=m%3;step;
    check(dut.popup_ticks==(svga?96:64),"each transition including PLAY reloads exact two seconds");
    frame;check(dut.popup_visible && dut.mode_notice && dut.shortcut_q==m%3,"latest mode captured on frame edge");
    // Whole popup plus all four boundaries; independent ROM oracle, 2x pixels,
    // yellow text, dark highlight, outside passthrough and RGB/VS/DE latency.
    pixel_check=1;
    for(yy=0;yy<68;yy=yy+1)begin
     for(xx=0;xx<168;xx=xx+1)begin x=xx;y=yy;de=1;step;end
     de=0;repeat(3)step;
    end
    repeat(3)step;pixel_check=0;
    check(dut.popup_visible,"timeout does not tear an active frame");
    frame;check(!dut.popup_visible,"timeout hides on next frame");
   end
   requested_mode=1;step;repeat(5)step;requested_mode=2;step;
   check(dut.popup_ticks==(svga?96:64),"rapid second switch restarts timer");
   for(i=1;i<=(svga?96:64);i=i+1)begin
    step;check(dut.popup_ticks==(svga?96:64)-i,"exact VGA/SVGA countdown");
   end
   frame;check(!dut.popup_visible,"timer never wraps");
   requested_mode=0;step;frame;
   brightness=8;step;frame;
   check(dut.popup_visible && !dut.mode_notice && dut.bright_units==8,"value edit replaces mode with original parameter popup");
   requested_mode=1;step;frame;
   check(dut.mode_notice && dut.shortcut_q==1,"new mode takes priority over existing parameter popup");
   opened=1;step;frame;check(dut.popup_ticks==0 && !dut.popup_visible,"menu cancels mode notice");
   requested_mode=2;step;opened=0;requested_mode=0;step;frame;
   check(dut.popup_ticks==0 && !dut.popup_visible,"menu and closing edge cannot trigger shortcut notice");
   brightness=0;contrast=4;step;opened=1;step;opened=0;step;frame;
  end
  // Real KEY3 short/long actions and bundled CDC, not a fabricated mode pulse.
  use_keys=1;repeat(25)step;
  for(m=1;m<=3;m=m+1)begin
   press3(12);frame;
   check(shortcut_mode==m%3 && dut.popup_visible && dut.mode_notice && dut.shortcut_q==m%3,
         "real short KEY3 cycles PLAY/BRIGHTNESS/CONTRAST across CDC");
  end
  press3(65);frame;
  check(menu_open && key_mode==0 && dut.popup_ticks==0,"long KEY3 opens menu without changing shortcut mode");
  press3(12);frame;
  check(key_mode==0 && !dut.popup_visible,"menu enter does not become shortcut switch");
  press3(65);frame;
  check(!menu_open && key_mode==0 && !dut.popup_visible,"long close produces no spurious mode popup");
  rst=1;repeat(3)step;
  check(dut.popup_ticks==0 && !dut.popup_visible,"reset cancels all notices");
  if(errors==0 && pixels==68544)$display("ALL PASS tb_menu_mode_popup: real keys/CDC, 3 modes, yellow 2x glyphs, 68544 pixels, exact VGA/SVGA timeout, retrigger, frame atomicity, value/menu/reset priority");
  else $display("FAILED tb_menu_mode_popup errors=%d pixels=%d",errors,pixels);
  $finish;
 end
 initial begin #20000000;$display("FAILED mode popup watchdog");$finish;end
endmodule
