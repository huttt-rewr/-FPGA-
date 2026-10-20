`timescale 1ns/1ps
// APUG092 contract model, not a model of the encrypted HDMI core.
module tb_hdmi_line_contract;
reg clk=0,rst=1,vs=1,de=0,ready=1;
reg [23:0] rgb=0;
wire user,valid,last,overflow;
wire [23:0] data;
integer x,y,f,received=0,line_pixels=0,pause_cycles=0,errors=0;
always #5 clk=~clk;
video_rgb_to_axis_640x480 dut(clk,rst,vs,de,rgb,user,valid,last,data,ready,overflow);
always @(posedge clk)begin
 if(rst)begin ready<=1;pause_cycles<=0;end
 else begin
  // Legal sink behavior: pause only after the accepted end-of-line.
  if(pause_cycles>0)begin pause_cycles<=pause_cycles-1;if(pause_cycles==1)ready<=1;end
  if(line_pixels!=0 && (!valid || !ready))errors=errors+1;
  if(valid && ready)begin
   if(data!==received || user!==(received%307200==0) || last!==(line_pixels==639))errors=errors+1;
   received=received+1;
   if(last)begin line_pixels=0;ready<=0;pause_cycles<=120;end
   else line_pixels=line_pixels+1;
  end
 end
end
initial begin
 repeat(4)@(negedge clk);rst=0;
 for(f=0;f<2;f=f+1)begin
  vs=0;repeat(1600)@(negedge clk);vs=1;repeat(800)@(negedge clk);
  for(y=0;y<480;y=y+1)begin
   for(x=0;x<640;x=x+1)begin de=1;rgb=f*307200+y*640+x;@(negedge clk);end
   de=0;repeat(160)@(negedge clk);
  end
  repeat(33600)@(negedge clk);
 end
 if(received!=614400 || overflow || line_pixels!=0)errors=errors+1;
 if(errors==0)$display("ALL PASS tb_hdmi_line_contract: two frames, continuous 640-pixel lines, legal line-end stalls");
 else $display("FAILED tb_hdmi_line_contract errors=%0d received=%0d",errors,received);
 $finish;
end
initial begin #10000000;$display("FAILED watchdog tb_hdmi_line_contract");$finish;end
endmodule
