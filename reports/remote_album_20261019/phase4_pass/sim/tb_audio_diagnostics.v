`timescale 1ns/1ps
module tb_audio_diagnostics;
 reg sc=0,vc=0,rst=1,mute=1,stream=0,empty=1;
 reg [10:0] used=0;reg [3:0] code=0;
 always #5 sc=~sc;always #20 vc=~vc;
 wire [3:0] video_code,last;wire rd,valid,pcm_valid,uf;wire [23:0] l,r;
 integer errors=0,pcm_count=0;
 cdc_snapshot #(.WIDTH(4)) cdc(.src_clk(sc),.src_rst(rst),.src_data(code),
 .dst_clk(vc),.dst_rst(rst),.dst_data(video_code));
 audio_error_history history(.clk(vc),.rst(rst),.current_code(video_code),
 .pcm_valid(pcm_valid),.last_code(last));
 audio_playback player(.clk(vc),.rst(rst),.volume(5'd8),.mute(mute),.mode_800(1'b0),
 .stream_ok(stream && !mute),.fifo_empty(empty),.fifo_used(used),.fifo_data(24'd0),
 .fifo_rd_en(rd),.valid(valid),.left_pcm(l),.right_pcm(r),.underflow(uf),.pcm_valid(pcm_valid));
 task check;input ok;input [511:0] msg;begin
  if(ok!==1)begin errors=errors+1;$display("FAILED diagnostics %0s",msg);end
 end endtask
 always @(posedge vc)begin #1;
  if(!rst && pcm_valid)begin pcm_count=pcm_count+1;check(valid && l==0 && r==0,"zero PCM marked valid and aligned");end
 end
 initial begin
  repeat(4)@(negedge vc);rst=0;code=2;wait(last==2);
  code=0;wait(video_code==0);repeat(1200)@(negedge vc);
  check(last==2 && pcm_count==0,"scheduled silence/mute must not clear failure");
  mute=0;stream=1;used=0;repeat(1200)@(negedge vc);
  check(last==2 && pcm_count==0,"prefill must retain failure");
  used=256;empty=0;wait(pcm_valid);@(negedge vc);empty=1;used=0;
  repeat(8)@(negedge vc);check(last==0,"actual zero PCM clears failure");
  wait(uf);repeat(600)@(negedge vc);check(uf && pcm_count==1,"underflow sticks and synthetic silence is not PCM");
  code=4;wait(last==4);code=0;wait(video_code==0);
  mute=1;used=256;empty=0;repeat(700)@(negedge vc);
  check(last==4,"repeated failure remains visible while muted");
  rst=1;repeat(3)@(negedge vc);check(last==0 && !uf,"system reset clears diagnostics");
  if(errors==0)$display("ALL PASS tb_audio_diagnostics");else $display("FAILED diagnostics %0d",errors);
  $finish;
 end
 initial begin #1000000;$display("FAILED diagnostics watchdog");$finish;end
endmodule
