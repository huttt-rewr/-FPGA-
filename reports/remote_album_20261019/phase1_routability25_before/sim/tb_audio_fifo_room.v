`timescale 1ns/1ps
module tb_audio_fifo_room;
 reg wc=0,rc=0,rst=1,re=0;always #5 wc=~wc;always #13 rc=~rc;
 wire ready,full,empty;wire [10:0] used,rd_used;wire [23:0] rd;
 reg valid=0;reg [23:0] data=0;integer writes=0,reads=0,errors=0,n;
 audio_async_fifo fifo(wc,rc,rst,valid,data,full,re,rd,empty,used,rd_used);
 audio_fifo_room admission(wc,rst,full,used,ready);
 // A producer with registered valid models WAV -> FIFO's in-flight sample.
 always @(posedge wc)begin
  if(rst)begin valid<=0;data<=0;end
  else begin valid<=ready;if(valid)data<=data+1'b1;end
  if(!rst && valid)begin
   if(full)begin errors=errors+1;$display("FAILED admission overflow drops an accepted sample");end
   else writes=writes+1;
  end
 end
 always @(posedge rc)if(!rst && re && !empty)begin
  #1;if(rd!==reads)begin errors=errors+1;$display("FAILED admission byte order %0d vs %0d",rd,reads);end
  reads=reads+1;
 end
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAILED admission %0s",msg);end
 end endtask
 initial begin
  repeat(8)@(negedge wc);rst=0;repeat(1200)@(negedge wc);
  check(!ready && !full && used>=1020 && writes<=1024,"backpressure before physical full with reserve");
  re=1;repeat(4000)@(negedge wc);re=0;repeat(1200)@(negedge wc);
  check(!ready && used>=1020,"refill and pointer wrap remain bounded");
  for(n=0;n<6000;n=n+1)begin @(negedge rc);re=($random & 3)!=0;end
  check(reads>2000 && errors==0,"sustained asynchronous reads retain every accepted sample");
  if(errors==0)$display("ALL PASS tb_audio_fifo_room: pipeline admission reserve, stalled full, async refill/wrap/random order, no dropped PCM");
  else $display("FAILED admission errors=%0d",errors);
  $finish;
 end
 initial begin #2000000;$display("FAILED admission watchdog");$finish;end
endmodule
