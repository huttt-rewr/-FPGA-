from pathlib import Path
root=Path(__file__).resolve().parents[2]
(root/'sim/tb_album_timer.v').write_text(r'''`timescale 1ns/1ps
module tb_album_timer;
 reg clk=0,rst=1,en=0,busy=0;always #5 clk=~clk;
 wire p1,p2,p7;integer errors=0,cycles=0,c1=0,c2=0,c7=0,k;
 integer r1=0,r2=0,r7=0;reg e1,e2,e7;reg [31:0] random_state=32'h12345678;
 slideshow_timer #(.PERIOD(1)) a(clk,rst,en,busy,p1);
 slideshow_timer #(.PERIOD(2)) b(clk,rst,en,busy,p2);
 slideshow_timer #(.PERIOD(7)) c(clk,rst,en,busy,p7);
 task model;input integer period;inout integer count;output pulse;begin
  pulse=0;
  if(!en)count=0;
  else if(count>=period-1)begin if(!busy)begin count=0;pulse=1;end end
  else count=count+1;
 end endtask
 always @(posedge clk)begin
  if(rst)begin r1=0;r2=0;r7=0;e1=0;e2=0;e7=0;end
  else begin model(1,r1,e1);model(2,r2,e2);model(7,r7,e7);end
  #1;
  if({p1,p2,p7}!=={e1,e2,e7})begin
   if(errors<5)$display("FAILED timer cycle=%d got=%b want=%b",cycles,{p1,p2,p7},{e1,e2,e7});errors=errors+1;
  end
  if(p1)c1=c1+1;if(p2)c2=c2+1;if(p7)c7=c7+1;cycles=cycles+1;
 end
 initial begin
  repeat(4)@(negedge clk);rst=0;en=1;repeat(70)@(negedge clk);
  if(c1!=70 || c2!=35 || c7!=10)begin errors=errors+1;$display("FAILED exact cadence %d %d %d",c1,c2,c7);end
  busy=1;repeat(40)@(negedge clk);busy=0;repeat(20)@(negedge clk);
  for(k=0;k<2000;k=k+1)begin
   random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
   en=(random_state[5:0]!=0);busy=random_state[6];@(negedge clk);
  end
  rst=1;repeat(4)@(negedge clk);rst=0;en=1;busy=0;repeat(30)@(negedge clk);
  if(errors==0)$display("ALL PASS tb_album_timer: exact periods 1/2/7, busy saturation, one pending event, disable/reset, randomized reference");
  else $display("FAILED tb_album_timer %d",errors);$finish;
 end
 initial begin #100000;$display("FAILED watchdog tb_album_timer");$finish;end
endmodule
'''.replace('\"','"'),encoding='utf-8')
(root/'sim/tb_zh_overlay.v').write_text(r'''`timescale 1ns/1ps
module tb_zh_overlay;
 reg clk=0,rst=1,vs=1,de=0,en=0,mode=0;always #5 clk=~clk;
 reg [23:0]rgb=0;wire [9:0]x,y,ox,oy;wire ov,od;wire [23:0]out_rgb;
 viewport_coordinates coords(clk,rst,vs,de,mode,x,y,,);
 zh_overlay dut(clk,rst,vs,de,x,y,rgb,en,ov,od,ox,oy,out_rgb);
 reg [15:0]gold[0:511];reg enabled=0,last_vs=1;reg [45:0]expected[0:1];
 reg [23:0]want;integer errors=0,pixels=0,lit=0,dimmed=0,bypassed=0,i,k,f,xx,yy,w,h,ci,ri,co;
 always @(posedge clk)begin
  if(rst)begin expected[0]=0;expected[1]=0;enabled=0;last_vs=1;end
  else begin
   want=rgb;
   if(enabled && x>=32 && x<32+dut.CHARS*16 && y>=384 && y<400)begin
    ci=(x-32)/16;ri=y-384;co=(x-32)%16;
    if(gold[ci*16+ri][15-co])begin want=24'hffe090;if(de)lit=lit+1;end
    else begin want={1'b0,rgb[23:17],1'b0,rgb[15:9],1'b0,rgb[7:1]};if(de)dimmed=dimmed+1;end
   end else if(de)bypassed=bypassed+1;
   expected[1]=expected[0];expected[0]={vs,de,x,y,de?want:24'd0};
   if(last_vs && !vs)enabled=en;last_vs=vs;
  end
  #1;
  if(!rst && {ov,od,ox,oy,out_rgb}!==expected[1])begin
   if(errors<6)$display("FAILED Chinese overlay x=%d y=%d got=%h want=%h",x,y,{ov,od,ox,oy,out_rgb},expected[1]);errors=errors+1;
  end
  if(od)pixels=pixels+1;
 end
 initial begin
  $readmemh("../src/modules/osd/zh_font.mem",gold);
  for(i=0;i<512;i=i+1)if((^gold[i])===1'bx)begin errors=errors+1;$display("FAILED uninitialized font %d",i);end
  for(i=dut.CHARS*16;i<512;i=i+1)if(gold[i]!==0)errors=errors+1;
  repeat(5)@(negedge clk);rst=0;
  for(f=0;f<4;f=f+1)begin
   mode=f[0];w=mode?800:640;h=mode?600:480;en=(f!=0);
   vs=0;repeat(16)@(negedge clk);vs=1;repeat(16)@(negedge clk);
   for(yy=0;yy<h;yy=yy+1)begin
    if(f==2 && yy==200)en=0;
    for(xx=0;xx<w;xx=xx+1)begin de=1;rgb={xx[7:0],yy[7:0],(xx[7:0]^yy[7:0])};@(negedge clk);end
    de=0;repeat(9)@(negedge clk);
   end
  end
  repeat(8)@(negedge clk);rst=1;repeat(4)@(negedge clk);
  if({ov,od,ox,oy,out_rgb}!==0)errors=errors+1;
  if(errors==0 && pixels==1574400 && lit>0 && dimmed>0 && bypassed>1000000)
   $display("ALL PASS tb_zh_overlay: four complete VGA/SVGA frames, font pixels/background, exact bypass, VS DE XY RGB latency, frame enable, unused glyphs, reset");
  else $display("FAILED tb_zh_overlay errors=%d pixels=%d lit=%d dimmed=%d",errors,pixels,lit,dimmed);$finish;
 end
 initial begin #30000000;$display("FAILED watchdog tb_zh_overlay");$finish;end
endmodule
'''.replace('\"','"'),encoding='utf-8')
print('Prepared timer and full-frame Chinese overlay tests')
clock_test=r'''`timescale 1ns/1ps
module tb_album_clock;
 reg clk=0,rst=1,vs=1,de=0,en=1,clock_big=1,mode=0;always #5 clk=~clk;
 reg [23:0]rgb=0;reg [7:0]seq=1;wire ov,od;wire [23:0]out_rgb;
 caption_overlay #(.CLK_HZ(100000000),.ADAPTIVE(1),.PIPELINED(1)) dut(
 .clk(clk),.rst(rst),.vs(vs),.de(de),.rgb(rgb),.enable(en),.scroll_enable(1'b0),
 .slogan_select(2'd0),.transition_mode(2'd0),.out_vs(ov),.out_de(od),.out_rgb(out_rgb),
 .mode_800(mode),.time_seq(seq),.time_bcd(24'h123456),.time_set(1'b1),.large_clock(clock_big));
 integer errors=0,pixels=0,white=0,tinted=0,f,xx,yy,w,h,k,lx,ly,cx,cy,ci,co,ri;
 reg [25:0]exp[0:2];reg [23:0]want;reg [7:0]ch;reg [55:0]bits;reg [7:0]row;
 reg frame_large=0,frame_en=0;reg [2:0]check_area=0;
 function [55:0]glyph;input [7:0]ch;begin
  case(ch)
   "B":glyph=56'h1e11111e11111e;"J":glyph=56'h0702020202120c;
   "1":glyph=56'h040c040404040e;"2":glyph=56'h0e11010204081f;
   "3":glyph=56'h1f02040201110e;"4":glyph=56'h02060a121f0202;
   "5":glyph=56'h1f101e0101110e;"6":glyph=56'h0608101e11110e;
   ":":glyph=56'h000c0c000c0c00;default:glyph=0;
  endcase
 end endfunction
 task check;input ok;input [511:0]msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAILED %s",msg);end
 end endtask
 task blank;begin
  de=0;vs=0;repeat(16)@(negedge clk);vs=1;repeat(16)@(negedge clk);
  check(dut.displayed_time==24'h123456 && dut.displayed_wall,"time and BJ label coherent at frame boundary");
 end endtask
 task send_pixel;input integer px,py;begin
  de=1;rgb={px[7:0],py[7:0],(px[7:0]^py[7:0])};want=rgb;
  lx=mode?(px*4/5):px;ly=mode?(py*4/5):py;
  if(frame_en)begin
   if(ly>=432 && ly<472)begin
    want={1'b0,rgb[23:17],({1'b0,rgb[15:9]}+8'd8),({1'b0,rgb[7:1]}+8'd16)};
    if(ly<434)want=24'hffffff;
    if(lx>=632 && ly>=436 && ly<440)want=24'hff6060;
   end
   if((frame_large && lx>=144 && lx<496 && ly>=96 && ly<160) ||
      (!frame_large && lx>=448 && lx<624 && ly>=16 && ly<48))begin
    want={1'b0,rgb[23:17],({1'b0,rgb[15:9]}+8'd8),({1'b0,rgb[7:1]}+8'd16)};
    if(frame_large)begin cx=lx-144;cy=ly-104;ci=cx/32;co=(cx%32)/4;ri=cy/4;end
    else begin cx=lx-448;cy=ly-20;ci=cx/16;co=(cx%16)/2;ri=cy/2;end
    case(ci)
     0:ch="B";1:ch="J";3:ch="1";4:ch="2";5:ch=":";6:ch="3";7:ch="4";8:ch=":";9:ch="5";10:ch="6";default:ch=" ";
    endcase
    bits=glyph(ch);row=(ri>=0 && ri<7)?(bits>>((6-ri)*8)):0;
    if(cy>=0 && ri<7 && co<5 && row[4-co])begin want=24'hffffff;white=white+1;end
    else tinted=tinted+1;
   end
  end
  @(negedge clk);
 end endtask
 reg [23:0] expected_input;
 always @(posedge clk)begin
  if(rst)begin exp[0]=0;exp[1]=0;exp[2]=0;check_area=0;end
  else begin
   exp[2]=exp[1];exp[1]=exp[0];exp[0]={vs,de,de?want:24'd0};
   check_area={check_area[1:0],(!de || yy<432)};
  end
  #1;
  // Existing scrolling banner has separate full-frame reference tests.
  // This oracle checks every pixel above its window plus all blank cycles.
  if(!rst && check_area[2] && {ov,od,out_rgb}!==exp[2])begin
   if(errors<5)$display("FAILED clock f=%d x=%d y=%d got=%h want=%h",f,xx,yy,{ov,od,out_rgb},exp[2]);errors=errors+1;
  end
  if(od)pixels=pixels+1;
 end
 initial begin
  want=0;repeat(5)@(negedge clk);rst=0;repeat(8)@(negedge clk);
  for(f=0;f<4;f=f+1)begin
   mode=f[0];w=mode?800:640;h=mode?600:480;clock_big=(f!=2);en=(f!=3);
   frame_large=clock_big;frame_en=en;blank;
   for(yy=0;yy<h;yy=yy+1)begin
    if(f==0 && yy==200)clock_big=0;
    for(xx=0;xx<w;xx=xx+1)send_pixel(xx,yy);
    de=0;repeat(9)@(negedge clk);
   end
  end
  repeat(8)@(negedge clk);check(pixels==1574400 && white>0 && tinted>0,"four complete adaptive frames and visible larger/small glyphs");
  if(errors==0)$display("ALL PASS tb_album_clock: independent 5x7 font oracle, clock_big/small windows, VGA/SVGA scaling, frame-only switches, BJ digits, disabled bypass, 3cycle pipeline");
  else $display("FAILED tb_album_clock %d",errors);$finish;
 end
 initial begin #30000000;$display("FAILED watchdog tb_album_clock");$finish;end
endmodule
'''
(root/'sim/tb_album_clock.v').write_text(clock_test.replace('\"','"'),encoding='utf-8')
p=root/'sim/tb_remote_uart.v'
s=p.read_text(encoding='utf-8')
old='  check(!overflow,"bounded response queue no overflow");'
assert old in s
s=s.replace(old,'''  byte("s");byte("h");byte("l");repeat(220)@(negedge clk);
  check(slide && zh && clock_big && !auto_enh && count==14,"optional album controls persist independently");
  check({replies[11],replies[12],replies[13]}=={"K","K","K"},"one K for each s h l option");
  byte("s");byte("h");byte("l");repeat(220)@(negedge clk);
  check(!slide && !zh && !clock_big && count==17,"optional album controls can all be disabled");
'''+old)
s=s.replace('  if(errors==0)$display(', '  check(!slide && !zh && !clock_big && !auto_enh,"reset restores all new features to disabled");\n  if(errors==0)$display(')
p.write_text(s,encoding='utf-8')
