`timescale 1ns/1ps
module tb_audio_stream_flush;
 reg clk=0,rst=1,flush=1,valid=0;reg signed [23:0] sample=0;
 always #20 clk=~clk;
 wire stream_rst,ov;wire signed [23:0] ol,orr;
 reset_sync sync_flush(clk,rst | flush,stream_rst);
 audio_effects_stream #(.BASS_GAIN(3276),.TREBLE_GAIN(3276),
  .ECHO_FEEDBACK(22938),.ECHO_DELAY(7)) dut(
  clk,rst,stream_rst,valid,sample,sample,ov,ol,orr);
 reg previous=0,expected;integer errors=0,n,seen_nonzero=0;
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAILED stream flush %0s",msg);end
 end endtask
 always @(posedge clk)begin
  expected=rst?0:previous;previous=rst?0:valid;
  #1;check(ov===expected,"scheduled valid survives stream resets");
  if(ov && ol!=0)seen_nonzero=seen_nonzero+1;
  check(ol===orr,"mono channels remain equal");
 end
 task send_sample;input signed [23:0] value;begin
  @(negedge clk);valid=1;sample=value;
  @(negedge clk);valid=0;
  repeat(4)@(negedge clk);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;flush=0;
  repeat(6)@(negedge clk);
  // Fill both FIR and delay RAM with the old track.
  for(n=0;n<22;n=n+1)send_sample(24'sd1000000);
  check(seen_nonzero>12,"old track exercised nonzero EQ and echo");
  // Flush at an arbitrary phase. Scheduled zero samples continue throughout.
  #7;flush=1;
  for(n=0;n<4;n=n+1)begin send_sample(0);check(ol==0,"silence during stream flush");end
  flush=0;repeat(6)@(negedge clk);
  for(n=0;n<22;n=n+1)begin
   send_sample(0);check(ol==0,"new silent track has no stale FIR/echo history");
  end
  if(errors==0)$display("ALL PASS tb_audio_stream_flush: nonzero EQ/echo clear on source switch, scheduled silence and valid preserved");
  else $display("FAILED stream flush errors=%0d",errors);
  $finish;
 end
 initial begin #100000;$display("FAILED stream flush watchdog");$finish;end
endmodule
