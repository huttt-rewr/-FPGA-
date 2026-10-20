`timescale 1ns/1ps
module tb_upgrade;
reg clk=0,rst=1;always #5 clk=~clk;
integer errors=0;
task check;input cond;input [511:0] msg;begin
 if(cond) $display("PASS %0s",msg);else begin $display("FAIL %0s",msg);errors=errors+1;end
end endtask
task tick;begin @(posedge clk);#1;end endtask
reg vb=0,req=0;reg [1:0] bufsel=0;
wire ack,visible;wire [1:0] active;
frame_swap swap(.clk(clk),.rst(rst),.vblank(vb),.request_toggle(req),
 .requested_buffer(bufsel),.ack_toggle(ack),.active_buffer(active),
 .display_valid(visible),.transition_mode(2'd0));
reg [7:0] command=0;reg command_valid=0;
wire nextp,prevp,togglep;wire [4:0] volume;wire mute,osden,pattern;
wire signed [7:0] bright;wire replyv;wire [7:0] reply;
wire [1:0] effect,slogan;wire captions,scroll,auto_enh;
player_control ctrl(clk,rst,command,command_valid,8'd0,1'b0,
 nextp,prevp,togglep,volume,mute,osden,bright,pattern,replyv,reply,
 effect,captions,scroll,slogan,auto_enh);
task send;input [7:0] c;begin @(negedge clk);command=c;command_valid=1;tick;
 @(negedge clk);command_valid=0;end endtask
reg de=0,vs=1;reg [23:0] rgb=0;
wire user,valid,last;wire [23:0] data;
wire axis_overflow;
video_rgb_to_axis_640x480 axis(clk,rst,vs,de,rgb,user,valid,last,data,1'b1,axis_overflow);
reg edstart=0,edvalid=0;reg [7:0] eddata=0;
wire eddone,edgood;
edid_base_check ed(clk,rst,edstart,edvalid,eddata,eddone,edgood);
reg amute=1;wire av;wire [23:0] al,ar;
audio_test_source #(.CLK_HZ(25000),.SAMPLE_HZ(48)) audio(clk,rst,5'd16,amute,av,al,ar);
reg [23:0] color=0;reg signed [7:0] brightness=0;wire [23:0] adjusted;
video_enhance enh(color,brightness,adjusted);
reg [7:0] yy=0,cb=128,cr=128;wire cv;wire [23:0] converted;
ycbcr_to_rgb yuv(clk,rst,1'b1,yy,cb,cr,cv,converted);
reg osd_enable=1,osd_auto=1,osd_mute=0,osd_busy=0,osd_error=0,osd_edid=0;
reg [1:0] osd_index=0;reg [2:0] osd_count=2;reg [4:0] osd_volume=8;
reg osd_de=0,osd_vs=0;reg [23:0] osd_in=24'hffffff;
wire [23:0] osd_out;wire [9:0] osd_x,osd_y;
status_osd status_panel(clk,rst,osd_vs,osd_de,osd_in,osd_enable,osd_auto,
 osd_index,osd_count,osd_volume,osd_mute,osd_busy,osd_error,osd_edid,
 osd_out,osd_x,osd_y,8'sd0,4'd4,2'd0,12'd0,12'd0);
integer i,j,n,sof_count,last_count;
reg [7:0] checksum;
initial begin
 repeat(5) tick;@(negedge clk);rst=0;repeat(5) tick;
 check(!visible && active==0,"display blank after reset");
 @(negedge clk);bufsel=1;req=1;repeat(8) tick;
 check(!ack && !visible,"no commit outside vblank");
 @(negedge clk);vb=1;tick;
 check(ack && visible && active==1,"commit exactly at vblank");
 @(negedge clk);vb=0;bufsel=0;req=0;repeat(8) tick;
 check(active==1 && ack,"second buffer retained until next blank");
 @(negedge clk);vb=1;tick;check(!ack && active==0,"second commit acknowledged");
 @(negedge clk);vb=0;
 check(mute && volume==8 && osden,"safe control reset defaults");
 check(effect==1 && captions && scroll && slogan==0,"effect defaults");
 send("e");check(effect==2 && reply=="K","slide mode command");
 send("e");check(effect==0,"cut mode command");send("e");check(effect==1,"fade mode cycle");
 send("c");check(!captions,"captions toggle");send("r");check(!scroll,"scroll pause");
 send("g");send("g");send("g");check(slogan==0,"slogan cycle");
 send("n");check(nextp && !prevp,"next command");tick;check(!nextp,"command is one cycle");
 send("b");check(prevp,"previous command");send("p");check(togglep,"pause resume toggle");
 repeat(25) send("+");check(volume==16,"volume clamps high");
 repeat(25) send("-");check(volume==0,"volume clamps low");
 send("m");check(!mute,"mute toggle");send("o");check(!osden,"OSD toggle");
 send("z");check(reply=="?","unknown command rejected");
 repeat(25) send("]");check(bright==64,"brightness clamps high");
 repeat(25) send("[");check(bright==-64,"brightness clamps low");
 osd_vs=1;
 for(j=0;j<17;j=j+1) begin
  for(i=0;i<640;i=i+1) begin @(negedge clk);osd_de=1;tick;end
  @(negedge clk);osd_de=0;tick;tick;
 end
 for(i=0;i<24;i=i+1) begin @(negedge clk);osd_de=1;tick;end
 check(osd_x>=16 && osd_x<40 && osd_y>=16 && osd_y<32 && osd_out!=osd_in,
   "40-column OSD covers its first status row");
 osd_enable=0;#1;check(osd_out==osd_in,"OSD bypass");
 @(negedge clk);osd_de=0;osd_vs=0;osd_enable=1;
 color=24'h00f080;brightness=32;#1;check(adjusted==24'h20ffa0,"RGB positive saturation");
 color=24'h001080;brightness=-32;#1;check(adjusted==24'h000060,"RGB negative saturation");
 yy=16;tick;check(converted==0,"YCbCr black");
 yy=235;tick;check(converted==24'hffffff,"YCbCr white");
 yy=81;cb=90;cr=240;tick;check(converted==24'hff0000,"YCbCr red");
 // Two complete active rows: compare every pixel, SOF and EOL markers.
 sof_count=0;last_count=0;
 for(j=0;j<2;j=j+1) begin
  for(i=0;i<640;i=i+1) begin
   @(negedge clk);de=1;rgb=i+j*640;tick;
   if(!valid || data!==rgb || last!==(i==639)) errors=errors+1;
   if(user) sof_count=sof_count+1;if(last) last_count=last_count+1;
  end
  @(negedge clk);de=0;repeat(5) tick;
 end
 check(sof_count==1 && last_count==2,"1280 pixels with exact SOF and EOL");
 @(negedge clk);vs=0;tick;@(negedge clk);vs=1;tick;
 @(negedge clk);de=1;tick;check(user,"SOF rearms on next frame");
 @(negedge clk);de=0;
 // Generate valid base EDID, then corrupt checksum.
 for(j=0;j<2;j=j+1) begin
  @(negedge clk);edstart=1;tick;@(negedge clk);edstart=0;checksum=0;
  for(i=0;i<128;i=i+1) begin
   edvalid=1;
   if(i<8) eddata=(i==0 || i==7)?0:255;
   else if(i==127) eddata=-checksum+j;
   else eddata=0;
   checksum=checksum+eddata;tick;@(negedge clk);
  end
  edvalid=0;check(eddone && edgood==(j==0),"EDID checksum accepted/rejected");
 end
 // Sample accumulator produces exactly 48 events in 25000 clocks.
 n=0;
 repeat(25000) begin tick;if(av) begin n=n+1;if(al!=0 || ar!=0) errors=errors+1;end end
 check(n==48,"48kHz rational sample rate and mute");
 amute=0;repeat(530) tick;check(al!=0 && al==ar,"stereo test tone enabled");
 if(errors==0) $display("ALL PASS tb_upgrade");else $display("FAILED tb_upgrade errors=%0d",errors);
 $finish;
end
initial begin #10000000;$display("FAILED watchdog tb_upgrade");$finish;end
endmodule
