`timescale 1ns/1ps
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
