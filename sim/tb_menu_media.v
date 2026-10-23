`timescale 1ns/1ps
module tb_menu_media;
 reg clk=0,rst=1,global_n=0;always #5 clk=~clk;
 reg [2:0] keys=7;wire opened,editing,page;wire [2:0] item;
 wire ni,nv,nw,rd,ru,np,nm,na,sv,sm,movie,restart;
 reg ke=0,km=0,bv=0,bm=0,bt=0;
 wire signed [7:0] brightness;wire [3:0] contrast;wire [4:0] volume;
 wire gamma,debug,mute,next_p,toggle_p;
 integer errors=0,pictures=0,movies=0,wavs=0,downs=0,ups=0,restarts=0,i;
 picture_controls #(.DEBOUNCE_CYCLES(3),.LONG_PRESS_CYCLES(30),.BOARD_MENU(1),
  .AUDIO_MENU(1),.CHINESE_MENU(1),.MEDIA_MENU(1)) keys_dut(
  .clk(clk),.rst(rst),.key1_n(keys[0]),.key2_n(keys[1]),.key3_n(keys[2]),
  .next_pulse(next_p),.toggle_pulse(toggle_p),.brightness(brightness),.contrast(contrast),
  .menu_open(opened),.menu_item(item),.menu_edit(editing),.menu_page(page),
  .gamma_enable(gamma),.debug_enable(debug),.audio_volume(volume),.audio_mute(mute),
  .image_next(ni),.movie_next(nv),.wav_next(nw),.res_down(rd),.res_up(ru),
  .kb_vol_up(1'b0),.kb_vol_dn(1'b0),.kb_mute(1'b0),
  .ir_vol_up(1'b0),.ir_vol_dn(1'b0),.ir_mute(1'b0),.ir_bri_up(1'b0),.ir_bri_dn(1'b0),.ir_con_up(1'b0),.ir_con_dn(1'b0));
 menu_media_request router(clk,global_n,rst,movie,ke,km,bv,bm,bt,ni,nv,nw,sv,sm,np,nm,na);
 boot_media_select #(.SETTLE_CYCLES(4),.DEFAULT_MOVIE(0),.RUNTIME_SELECT(1)) select_dut(
  .clk(clk),.rst_n(global_n),.key1_n(1'b1),.movie_mode(movie),
  .select_valid(sv),.select_movie(sm),.restart_request(restart));
 always @(posedge clk)begin
  if(np)pictures=pictures+1;if(nm)movies=movies+1;if(na)wavs=wavs+1;
  if(rd)downs=downs+1;if(ru)ups=ups+1;if(restart)restarts=restarts+1;
 end
 task settle;begin repeat(14)@(negedge clk);end endtask
 task press;input integer k;begin keys[k]=0;settle;keys[k]=1;settle;end endtask
 task hold3;begin keys[2]=0;repeat(80)@(negedge clk);keys[2]=1;settle;end endtask
 task check;input good;input [511:0] msg;begin
  if(good!==1)begin errors=errors+1;$display("FAILED media %0s page=%b item=%d edit=%b",msg,page,item,editing);end
 end endtask
 task second_page;begin hold3;repeat(8)press(1);check(page && item==0 && !editing,"second page navigation");end endtask
 initial begin
  settle;global_n=1;rst=0;settle;
  hold3;check(!page && item==0 && opened,"open page one");
  press(0);check(page && item==3,"backward wraps all twelve items");
  press(1);check(!page && item==0,"forward wraps all twelve");
  repeat(8)press(1);press(2);check(editing && pictures==0,"picture entry is inert");
  press(1);check(pictures==1 && !movie,"next picture via existing photo mode");
  press(0);check(pictures==2,"both keys execute media action");
  keys[0]=0;keys[1]=0;settle;keys=7;settle;check(pictures==2,"opposite keys ignored");
  press(2);press(1);press(2);check(editing && movies==0,"movie entry inert");
  press(1);check(movie && movies==0 && restarts==1,"cross to first movie without extra skip");
  // Emulate the real supervisor restart: the selection must survive it.
  rst=1;settle;rst=0;settle;check(movie && sm,"movie choice survives controls reset");
  second_page;press(1);press(2);press(1);check(movies==1 && restarts==1,"same-mode next movie");
  press(2);press(1);press(2);press(1);check(!movie && wavs==0 && restarts==2,"WAV selects first photo/WAV mode");
  press(1);check(wavs==1,"next WAV pulse");
  check(brightness==0 && contrast==4 && volume==8 && !gamma && !debug,"page two does not change page one registers");
  press(2);press(1);press(2);press(0);press(1);
  check(downs==1 && ups==1 && brightness==0 && contrast==4,"resolution action events isolated");
  press(2);press(1);check(!page && item==0,"page two wraps to page one");
  hold3;check(!opened,"long close");
  // Keyboard and old button levels cannot lock out later explicit menu choices.
  bv=1;bm=1;bt=~bt;settle;check(movie,"button chooses movie");
  ke=1;km=0;@(negedge clk);ke=0;settle;check(!movie,"keyboard overrides stale button level");
  second_page;press(1);press(2);press(1);check(movie,"menu overrides both old sources");
  ke=1;km=0;@(negedge clk);ke=0;settle;check(!movie,"repeated explicit same keyboard choice still works");
  bt=~bt;settle;check(movie,"same button target fires again after menu or keyboard changed mode");
  global_n=0;rst=1;settle;check(!sv && !opened,"global reset clears persistent request");
  if(errors==0)$display("ALL PASS tb_menu_media: twelve entries/two pages, physical keys, inert entry, isolated pulses, first/next media, persistent restart and last-request priority");
  else $display("FAILED tb_menu_media %0d",errors);$finish;
 end
 initial begin #1000000;$display("FAILED menu media watchdog");$finish;end
endmodule
