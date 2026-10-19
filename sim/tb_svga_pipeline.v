`timescale 1ns/1ps
// Real effect/overlay/OSD/AXIS chain with legal HDMI line-end backpressure.
module tb_svga_pipeline;
 reg clk=0,rst=1,vs=1,de=0,ready=1;always #5 clk=~clk;
 reg [23:0] rgb=0;reg [1:0] mode=1;reg [5:0] level=16;reg [9:0] offset=0;
 reg captions_on=0;
 wire [9:0] px,py;wire ev,ed,cv,cd,user,valid,last,overflow;
 wire [23:0] ec,cc,oc,data,adjusted;
 wire ov,od;wire av,ad;wire [9:0] ax,ay;
 integer x,y,f,received=0,line_pixels=0,pause_cycles=0,errors=0;
 integer rx,ry,rf,sx,k,v;
 reg [23:0] expected;
 video_coordinates coords(clk,rst,vs,de,px,py);
 picture_adjust adjust(clk,rst,vs,de,px,rgb,8'sd8,4'd5,av,ad,ax,adjusted,py,ay);
 transition_pixels fx(clk,rst,av,ad,ax,adjusted,{1'b0,mode},level,offset,ev,ed,ec,ay,1'b1);
 caption_overlay #(.ADAPTIVE(1)) captions(clk,rst,ev,ed,ec,captions_on,1'b1,2'd0,mode,cv,cd,cc,1'b1);
 status_osd #(.ADAPTIVE(1),.ENHANCED_UI(1),.PIPELINED(1)) panel(.out_vs(ov),.out_de(od),.mode_800(1'b1),.clk(clk),.rst(rst),.vs(cv),.de(cd),.rgb(cc),.enable(captions_on),
  .auto_play(1'b1),.image_index(2'd1),.image_count(3'd4),.volume(5'd8),
  .mute(1'b1),.busy(1'b0),.error(1'b0),.edid_ok(1'b1),.result(oc),.pixel_x(),.pixel_y());
 video_rgb_to_axis_640x480 #(.ADAPTIVE(1)) axis(clk,rst,ov,od,oc,user,valid,last,data,ready,overflow,1'b1);
 function [23:0] sample;input integer xx,yy;reg [7:0] r,g,b;begin
  r=xx;g=yy;b=xx+yy;sample={r,g,b};
 end endfunction
 always @(posedge clk)begin
  if(rst)begin ready<=1;pause_cycles<=0;end
  else begin
   if(pause_cycles>0)begin pause_cycles<=pause_cycles-1;if(pause_cycles==1)ready<=1;end
   if(line_pixels!=0 && (!valid || !ready))begin errors=errors+1;$display("FAIL discontinuous HDMI line");end
   if(valid && ready)begin
    rx=received%800;ry=(received/800)%600;rf=received/480000;
    if(user!==(rx==0 && ry==0) || last!==(rx==799))errors=errors+1;
    sx=(rf==1)?rx-400:rx;
    expected=(sx<0)?0:sample(sx,ry);
    if(sx>=0)for(k=0;k<3;k=k+1)begin
     v=expected[k*8+:8];v=(((v-128)*5+2)>>>2)+136;
     expected[k*8+:8]=(v<0)?0:((v>255)?255:v);
    end
    if(rf==0)for(k=0;k<3;k=k+1)begin v=expected[k*8+:8];expected[k*8+:8]=v/2;end
    if(rf<2 || (ry>=100 && ry<400))begin
     if(data!==expected)begin
      if(errors<5)$display("FAIL integration f=%0d x=%0d y=%0d actual=%h expect=%h",rf,rx,ry,data,expected);
      errors=errors+1;
     end
    end
    received=received+1;
    if(last)begin line_pixels=0;ready<=0;pause_cycles<=120;end
    else line_pixels=line_pixels+1;
   end
  end
 end
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(f=0;f<3;f=f+1)begin
   mode=(f==0)?1:((f==1)?2:0);offset=(f==1)?400:0;captions_on=(f==2);
   vs=0;repeat(1600)@(negedge clk);vs=1;repeat(800)@(negedge clk);
   for(y=0;y<600;y=y+1)begin
    for(x=0;x<800;x=x+1)begin de=1;rgb=sample(x,y);@(negedge clk);end
    de=0;repeat(256)@(negedge clk);
   end
   repeat(33600)@(negedge clk);
  end
  if(received!=1440000 || overflow || line_pixels!=0)errors=errors+1;
  if(errors==0)$display("ALL PASS tb_svga_pipeline: 3 complete frames, RGB alignment, 800 continuous pixels, legal HDMI stalls, layered overlay");
  else $display("FAILED tb_svga_pipeline errors=%0d pixels=%0d",errors,received);
  $finish;
 end
 initial begin #25000000;$display("FAILED watchdog tb_svga_pipeline");$finish;end
endmodule
