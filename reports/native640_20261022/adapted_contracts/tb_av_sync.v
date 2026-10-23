`timescale 1ns/1ps
module tb_av_sync;
 reg clk=0,rst=1,we=0,req=0,bank=0,play=1,failed=0,ended=0,vblank=0;
 reg [10:0] addr=0;reg [15:0] data=0;
 always #5 clk=~clk;
 wire ack,visible,buffering,valid;wire [1:0] active;wire [23:0] left,right;
 integer i,n=0,errors=0;
 // Small signal-only trace for reviewing audio/video handoff without dumping RAM.
 initial begin
  $dumpfile("../reports/av_20261013/av_sync.vcd");
  $dumpvars(1,tb_av_sync);
 end
 av_sync_player #(.VGA_HZ(480000),.SAMPLES(4)) dut(
  .clk(clk),.rst(rst),.mode_800(1'b0),.vblank(vblank),
  .request_toggle(req),.requested_bank(bank),.play(play),.failed(failed),.ended(ended),
  .ack_toggle(ack),.active_buffer(active),.visible(visible),.buffering(buffering),
  .write_clk(clk),.audio_we(we),.audio_address(addr),.audio_data(data),
  .audio_valid(valid),.left_pcm(left),.right_pcm(right));
 task blank;begin @(negedge clk);vblank=1;@(negedge clk);vblank=0;end endtask
 initial begin
  repeat(4)@(negedge clk);
  for(i=0;i<4;i=i+1)begin
   we=1;addr=i;data=i+1;@(negedge clk);
  end
  for(i=0;i<4;i=i+1)begin
   addr=1024+i;data=i+11;@(negedge clk);
  end
  we=0;rst=0;req=1;
  repeat(6)@(negedge clk);blank;
  if(!visible || !ack || active!=0)$fatal(1,"FAILED first commit");
  bank=1;req=0;
  while(n<12)begin
   @(negedge clk);
   if(valid)begin
    if(left!==((n/3+1)<<8) || right!==left)$fatal(1,"FAILED PCM sample %d got %h",n,left);
    n=n+1;
   end
  end
  if(!ack)$fatal(1,"FAILED released buffer before vblank");
  blank;
  if(ack || active!=1)$fatal(1,"FAILED second commit");
  ended=1;n=0;
  while(n<12)begin
   @(negedge clk);
   if(valid)begin
    if(left!==((n/3+11)<<8))$fatal(1,"FAILED second PCM %d got %h",n,left);
    n=n+1;
   end
  end
  repeat(25)@(negedge clk);
  if(left!==0 || buffering)$fatal(1,"FAILED end silence");
  $display("ALL PASS tb_av_sync: PCM order, triple repeat, commit ownership, EOF silence");$finish;
 end
 initial begin #100000;$fatal(1,"FAILED tb_av_sync timeout");end
endmodule
