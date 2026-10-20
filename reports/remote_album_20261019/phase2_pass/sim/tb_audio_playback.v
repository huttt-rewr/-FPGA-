`timescale 1ns/1ps
module audio_playback_case #(parameter HZ=25000000,parameter MODE=0)(output reg finished=0,output reg [31:0] errors=0);
 reg clk=0,rst=1,mute=0,ok=1,empty=0;always #5 clk=~clk;
 reg [4:0] volume=31;reg [23:0] fd=0;wire re,valid,uf;wire [23:0] l,r;reg [10:0] used=1024;
 integer cycle=0,last=0,count=0,reads=0,i,g,amp;reg signed [63:0] calc;reg [23:0] queue[0:5000];integer qi=0,qo=0;
 audio_playback #(.CLK_HZ(HZ),.ADAPTIVE(1),.PREFILL(4)) dut(.clk(clk),.rst(rst),.volume(volume),.mute(mute),.mode_800(MODE!=0),.stream_ok(ok),.fifo_empty(empty),.fifo_used(used),.fifo_data(fd),.fifo_rd_en(re),.valid(valid),.left_pcm(l),.right_pcm(r),.underflow(uf));
 task check;input condition;input [511:0] msg;begin if(condition!==1)begin errors=errors+1;$display("FAILED playback %0d %0s",HZ,msg);end end endtask
 function integer gain_ref;input integer k;real v;begin v=32768.0*(2.0**(k/32.0));gain_ref=$rtoi(v+0.5);end endfunction
 // 同步读RAM模型；独立整数参考以每次实际读出的样本计分。
 always @(posedge clk)begin
  if(rst)begin cycle=0;last=0;count=0;reads=0;qi=0;qo=0;end
  else begin
   cycle=cycle+1;
   if(dut.tick)begin
    calc=0;
    if(re)begin
     case(reads%4)0:amp=32767;1:amp=-32768;2:amp=-1;3:amp=12345;endcase
     fd<=amp;reads=reads+1;
     if(!mute && volume!=0)begin calc=amp;calc=calc*256*gain_ref(volume);calc=calc>>>16;end
    end
    queue[qi]=calc[23:0];qi=qi+1;
   end
   #1;
   if(valid)begin
    if(last!=0)check(cycle-last==HZ/48000 || cycle-last==(HZ+47999)/48000,"uniform floor/ceil interval");
    last=cycle;count=count+1;
    check(l===r && l===queue[qo],"sample/pipeline/gain");qo=qo+1;
   end
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=0;
  repeat(HZ/100)@(negedge clk);check(count==479 || count==480,"10ms = 480 samples within pipeline latency");
  for(i=0;i<32;i=i+1)begin volume=i;repeat(2500)@(negedge clk);end
  mute=1;repeat(2500)@(negedge clk);check(l==0,"mute");mute=0;volume=31;
  empty=1;used=0;repeat(2500)@(negedge clk);check(l==0 && uf,"empty outputs zero and sticky underflow");
  empty=0;used=3;repeat(2500)@(negedge clk);check(l==0,"prefill waits");used=4;repeat(2500)@(negedge clk);check(reads>0,"refill resumes");
  ok=0;repeat(2500)@(negedge clk);check(l==0,"invalid stream silence");finished=1;
 end
endmodule
module tb_audio_playback;
 wire a,b;wire [31:0] ea,eb;
 audio_playback_case #(.HZ(25000000)) vga(a,ea);
 audio_playback_case #(.HZ(40000000),.MODE(1)) svga(b,eb);
 initial begin wait(a && b);if(ea+eb==0)$display("ALL PASS tb_audio_playback");else $display("FAILED playback %0d",ea+eb);$finish;end
 initial begin #10000000;$display("FAILED playback watchdog");$finish;end
endmodule
