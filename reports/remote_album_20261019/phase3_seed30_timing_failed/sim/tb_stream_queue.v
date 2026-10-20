`timescale 1ns/1ps
module tb_stream_queue;
 reg clk=0,rst=1,vs=1,de=0,ready=1;reg [23:0] rgb=0;
 always #5 clk=~clk;
 wire valid,sof,eol,overflow;wire [23:0] data;
 video_rgb_to_axis_640x480 dut(clk,rst,vs,de,rgb,sof,valid,eol,data,ready,overflow);
 integer received=0,errors=0,i,row;
 reg scoreboard=1,stalled=0;reg [25:0] held;
 always @(posedge clk) if(!rst) begin
  if(stalled && (!valid || {sof,eol,data}!==held)) errors=errors+1;
  stalled=valid && !ready;held={sof,eol,data};
  if(valid && ready && scoreboard) begin
   if(data!==received || sof!==(received==0) || eol!==(received%640==639)) errors=errors+1;
   received=received+1;
  end
 end else stalled=0;
 initial begin
  repeat(4) @(negedge clk);rst=0;
  for(row=0;row<2;row=row+1) begin
   for(i=0;i<640;i=i+1) begin
    @(negedge clk);de=1;rgb=row*640+i;ready=!(i>=30 && i<50);
   end
   @(negedge clk);de=0;ready=1;repeat(85) @(negedge clk);
  end
  if(received!=1280 || overflow) errors=errors+1;
  scoreboard=0;rst=1;repeat(3) @(negedge clk);rst=0;ready=0;
  for(i=0;i<90;i=i+1) begin @(negedge clk);de=1;rgb=i;end
  @(negedge clk);de=0;
  if(!overflow || !valid) errors=errors+1;
  ready=1;repeat(80) @(negedge clk);
  vs=0;repeat(3) @(negedge clk);vs=1;repeat(3) @(negedge clk);
  de=1;rgb=24'h123456;@(negedge clk);de=0;
  if(!valid || !sof || data!=24'h123456) errors=errors+1;
  if(errors==0)$display("ALL PASS tb_stream_queue: stalls, order, SOF/EOL, overflow recovery");
  else $display("FAILED tb_stream_queue %0d",errors);
  $finish;
 end
endmodule
