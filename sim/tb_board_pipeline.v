`timescale 1ns/1ps
// Real adjust/gamma/transition/caption/menu/AXIS chain, both output sizes.
// HDMI is a behavioral line-contract peer; protected transmitter PHY not modeled.
module tb_board_pipeline;
 reg clk=0,rst=1,vs=1,de=0,ready=1,mode=0,en=0,overlay=0;
 always #5 clk=~clk;
 reg [23:0] rgb=0;reg [1:0] effect=0;reg [9:0] offset=0;
 wire [9:0] px,py,ax,ay,gx,gy,aex,aey;wire aev,aed;wire [23:0] aer;
 wire av,ad,gv,gd,ev,ed,cv,cd,ov,od,user,valid,last,overflow;
 wire [23:0] ac,gc,ec,cc,oc,data;
 integer m,f,x,y,i,k,v,width,height,frame_pixels,received=0,line_pixels=0,pauses=0,errors=0;
 integer rx,ry,rf,sx;reg [23:0] expected;
 reg [7:0] reference_gamma[0:255];real normalized;integer ten;
 video_coordinates coords(clk,rst,vs,de,px,py);
 picture_adjust adjust(clk,rst,vs,de,px,rgb,8'sd8,4'd5,av,ad,ax,ac,py,ay);
 picture_gamma gamma(clk,rst,av,ad,ax,ac,en,gv,gd,gx,gc,ay,gy);
 auto_enhance levels(clk,rst,gv,gd,gx,gy,gc,1'b0,aev,aed,aex,aey,aer);
 transition_pixels fx(clk,rst,aev,aed,aex,aer,{1'b0,effect},6'd16,offset,ev,ed,ec,aey,mode);
 caption_overlay #(.ADAPTIVE(1)) captions(clk,rst,ev,ed,ec,overlay,1'b1,2'd0,effect,cv,cd,cc,mode,8'd0,24'd0,1'b0);
 status_osd #(.ENHANCED_UI(1),.ADAPTIVE(1),.PIPELINED(1),.BOARD_UI(1)) panel(
  .clk(clk),.rst(rst),.vs(cv),.de(cd),.rgb(cc),.enable(overlay),
  .auto_play(1'b0),.image_index(2'd0),.image_count(3'd4),.volume(5'd8),.mute(1'b1),
  .busy(1'b0),.error(1'b0),.edid_ok(1'b1),.result(oc),.pixel_x(),.pixel_y(),
  .brightness(8'sd8),.contrast(4'd5),.edit_mode(2'd0),.source_width(12'd640),.source_height(12'd480),
  .mode_800(mode),.out_vs(ov),.out_de(od),.menu_open(overlay),.menu_item(3'd1),
  .gamma_enable(en),.debug_enable(1'b0),.debug_page(2'd0));
 video_rgb_to_axis_640x480 #(.ADAPTIVE(1)) axis(clk,rst,ov,od,oc,user,valid,last,data,ready,overflow,mode);
 function [23:0] sample;input integer xx,yy;reg [7:0] r,g,b;begin
  r=xx;g=yy;b=xx+yy;sample={r,g,b};
 end endfunction
 always @(posedge clk)begin
  if(rst)begin ready<=1;pauses<=0;end
  else begin
   if(pauses>0)begin pauses<=pauses-1;if(pauses==1)ready<=1;end
   if(line_pixels!=0 && (!valid || !ready))begin errors=errors+1;$display("FAILED board discontinuous line");end
   if(valid && ready)begin
    rx=received%width;ry=(received/width)%height;rf=received/frame_pixels;
    if(user!==(rx==0 && ry==0) || last!==(rx==width-1))errors=errors+1;
    sx=(rf==2)?rx-width/2:rx;expected=(sx<0)?0:sample(sx,ry);
    if(sx>=0)for(k=0;k<3;k=k+1)begin
     v=expected[k*8+:8];v=(((v-128)*5+2)>>>2)+136;
     v=(v<0)?0:((v>255)?255:v);
     if(rf>0)v=reference_gamma[v];
     if(rf==1)v=v/2;
     expected[k*8+:8]=v;
    end
    if(rf<2 || (ry>=130 && ry<height-130))begin
     if(data!==expected)begin
      if(errors<5)$display("FAILED board pipeline mode=%d f=%d x=%d y=%d actual=%h expected=%h",mode,rf,rx,ry,data,expected);
      errors=errors+1;
     end
    end
    received=received+1;
    if(last)begin line_pixels=0;ready<=0;pauses<=120;end
    else line_pixels=line_pixels+1;
   end
  end
 end
 initial begin
  for(i=0;i<256;i=i+1)begin
   normalized=i/255.0;ten=$rtoi(1023.0*(normalized**(1.0/2.2))+0.5);
   v=(ten+2)/4;reference_gamma[i]=(v>255)?255:v;
  end
  for(m=0;m<2;m=m+1)begin
   rst=1;mode=m;received=0;line_pixels=0;width=mode?800:640;height=mode?600:480;frame_pixels=width*height;
   repeat(4)@(negedge clk);rst=0;
   for(f=0;f<3;f=f+1)begin
    en=(f>0);overlay=(f==2);effect=f;offset=(f==2)?width/2:0;
    vs=0;repeat(1600)@(negedge clk);vs=1;repeat(800)@(negedge clk);
    for(y=0;y<height;y=y+1)begin
     for(x=0;x<width;x=x+1)begin de=1;rgb=sample(x,y);@(negedge clk);end
     de=0;repeat(256)@(negedge clk);
    end
    repeat(33600)@(negedge clk);
   end
   if(received!=3*frame_pixels || overflow || line_pixels!=0)errors=errors+1;
  end
  if(errors==0)$display("ALL PASS tb_board_pipeline: six full frames, both modes, automatic-level bypass, gamma/bypass, fade/slide, menu/captions, exact continuous HDMI lines");
  else $display("FAILED tb_board_pipeline %d",errors);
  $finish;
 end
 initial begin #50000000;$display("FAILED watchdog board pipeline");$finish;end
endmodule
