`timescale 1ns/1ps
`ifdef AUDIO_EFFECTS_SYNTHESIS_PROBE
// Verification-only top, excluded from the production TD source manifest.
// Uses the SAME effects RTL with nonzero fixed parameters, for BRAM/STA proof.
module audio_effects_probe(input clk,rst,src_valid,input signed [23:0] sample,
 output out_valid,output signed [23:0] out_left,out_right);
 audio_effects #(.BASS_GAIN(16'sd3276),.TREBLE_GAIN(16'sd3276),
  .ECHO_FEEDBACK(16'sd22938)) fx(.clk(clk),.rst(rst),.src_valid(src_valid),
  .src_left(sample),.src_right(sample),.out_valid(out_valid),
  .out_left(out_left),.out_right(out_right));
endmodule
`else
// Independent 64-bit integer reference; never reads DUT arithmetic/state.
module audio_effects_case #(
 parameter integer BASS=0,TREBLE=0,FEEDBACK=0,DELAY=2400
)(input clk,rst,valid,input signed [23:0] sample,input integer phase,
 output reg [31:0] errors=0);
 wire ov;wire signed [23:0] ol,orr;
 audio_effects #(.BASS_GAIN(BASS),.TREBLE_GAIN(TREBLE),
  .ECHO_FEEDBACK(FEEDBACK),.ECHO_DELAY(DELAY)) dut(
  .clk(clk),.rst(rst),.src_valid(valid),.src_left(sample),.src_right(sample),
  .out_valid(ov),.out_left(ol),.out_right(orr));
 integer hist[0:13],mem[0:DELAY-1],pos=0,filled=0,i,coef;
 reg prev_valid=0,expected_valid;
 integer prev_sample=0,prev_phase=0,expected,tag,input_peak=0,output_peak=0;
 reg signed [63:0] sum,low,high,eq,echo_value,part;
 function integer clip;
  input signed [63:0] v;
  begin if(v>8388607)clip=8388607;else if(v< -8388608)clip=-8388608;else clip=v;end
 endfunction
 function integer coeff;
  input integer k;
  begin case(k)
   0,14:coeff=304;1,13:coeff=496;2,12:coeff=1034;3,11:coeff=1835;
   4,10:coeff=2749;5,9:coeff=3590;6,8:coeff=4180;7:coeff=4392;
   default:coeff=0;
  endcase end
 endfunction
 task check;
  input condition;input [511:0] message;
  begin if(condition!==1)begin
   errors=errors+1;
   if(errors<12)$display("FAILED effects B=%0d T=%0d E=%0d D=%0d %0s",BASS,TREBLE,FEEDBACK,DELAY,message);
  end end
 endtask
 // Deliberately poison the reference memory: priming must hide stale contents.
 initial for(i=0;i<DELAY;i=i+1)mem[i]=7000000;
 always @(posedge clk)begin
  expected_valid=prev_valid;expected=prev_sample;tag=prev_phase;
  if(rst)begin
   prev_valid=0;expected_valid=0;prev_sample=0;pos=0;filled=0;
   for(i=0;i<14;i=i+1)hist[i]=0;
   input_peak=0;output_peak=0;
  end else begin
   prev_valid=valid;
   if(valid)begin
    sum=sample;sum=sum*coeff(0);
    for(i=1;i<15;i=i+1)begin part=hist[i-1];sum=sum+part*coeff(i);end
    low=sum>>>15;high=sample;high=high-low;
    part=BASS;eq=sample+((part*low)>>>15);
    part=TREBLE;eq=clip(eq+((part*high)>>>15));
    echo_value=eq;
    if(FEEDBACK!=0 && filled>=DELAY)begin
     part=mem[pos];echo_value=echo_value+((part*FEEDBACK)>>>15);
    end
    prev_sample=clip(echo_value);prev_phase=phase;
    mem[pos]=eq;if(pos==DELAY-1)pos=0;else pos=pos+1;
    if(filled<DELAY)filled=filled+1;
    for(i=13;i>0;i=i-1)hist[i]=hist[i-1];hist[0]=sample;
    if((phase==2 || phase==3) && sample>input_peak)input_peak=sample;
   end
  end
  #1;
  check(ov===expected_valid,"valid has fixed two register stages, bubbles preserved");
  if(expected_valid)begin
   check(ol===orr,"mono channels equal");
   check($signed(ol)===expected,"bit-exact independent FIR/EQ/echo reference");
   if((tag==2 || tag==3) && ol>output_peak)output_peak=ol;
  end
  if(rst)check(ol==0 && orr==0 && !ov,"reset clears visible output");
 end
endmodule

module tb_audio_effects;
 reg clk=0,rst=1,valid=0;
 real half_period=20.0;
 always #(half_period)clk=~clk;
 reg signed [23:0] sample=0;integer phase=0;
 wire [31:0] e0,e1,e2,e3,e4,e5,e6,e7;
 audio_effects_case flat(clk,rst,valid,sample,phase,e0);
 audio_effects_case #(.BASS(3276)) bass(clk,rst,valid,sample,phase,e1);
 audio_effects_case #(.TREBLE(3276)) treble(clk,rst,valid,sample,phase,e2);
 audio_effects_case #(.BASS(-3276),.TREBLE(-3276)) cut(clk,rst,valid,sample,phase,e3);
 audio_effects_case #(.BASS(32767),.TREBLE(32767)) saturation(clk,rst,valid,sample,phase,e4);
 audio_effects_case #(.FEEDBACK(22938)) echo50ms(clk,rst,valid,sample,phase,e5);
 audio_effects_case #(.FEEDBACK(32767),.DELAY(1)) echo1(clk,rst,valid,sample,phase,e6);
 audio_effects_case #(.FEEDBACK(22938),.DELAY(13)) echo13(clk,rst,valid,sample,phase,e7);
 integer errors=0,n,period,clock_hz=25000000;
 integer impulse=1048576,echo_peak;
 real pi=3.141592653589793;
 task check;
  input condition;input [511:0] msg;
  begin if(condition!==1)begin errors=errors+1;$display("FAILED effects %0s",msg);end end
 endtask
 task reset_all;
  begin
   @(negedge clk);valid=0;rst=1;
   repeat(3)@(negedge clk);rst=0;
  end
 endtask
 task send;
  input integer x;input integer gap;
  begin
   @(negedge clk);sample=x;valid=1;
   @(negedge clk);valid=0;
   repeat(gap-2)@(negedge clk);
  end
 endtask
 task tone;
  input integer frequency,count;
  begin for(n=0;n<count;n=n+1)begin
   period=((n%48+1)*clock_hz/48000)-((n%48)*clock_hz/48000);
   send($rtoi(1000000.0*$sin(2*pi*frequency*n/48000.0)),period);
  end end
 endtask
 initial begin
  reset_all();phase=1;tone(1000,192);
  reset_all();phase=2;tone(100,2400);
  check(bass.output_peak>1060000,"100Hz bass gain raises amplitude by over 6 percent");
  reset_all();phase=3;tone(5000,480);
  check(treble.output_peak>1060000,"5kHz treble gain raises amplitude by over 6 percent");
  reset_all();phase=4;
  // Full-scale positive/negative DC, transitions and signed one-LSB values.
  for(n=0;n<40;n=n+1)send(8388607,3);
  check(saturation.ol==24'h7fffff,"positive saturation clamps, never wraps negative");
  for(n=0;n<40;n=n+1)send(-8388608,3);
  check(saturation.ol==24'h800000,"negative saturation clamps, never wraps positive");
  for(n=0;n<64;n=n+1)send((n%2)?-1:1,3);
  reset_all();phase=5;
  // Delay is in VALID SAMPLES, not video clocks. Two complete wraps also
  // prove there is no second recursive echo in the specified feed-forward eq.
  for(n=0;n<4802;n=n+1)begin
   period=((n%48+1)*clock_hz/48000)-((n%48)*clock_hz/48000);
   send((n==0)?impulse:0,period);
   if(n==2399)check(echo50ms.ol==0,"no premature echo");
   if(n==2400)check(echo50ms.ol==734016,"exact 0.7 Q15 echo at 2400 samples = 50ms");
   if(n==4800)check(echo50ms.ol==0,"feed-forward stores eq: no recursive second echo");
  end
  // Reset with nonzero old RAM contents; every sample before priming is zero.
  reset_all();for(n=0;n<20;n=n+1)send(0,4);
  check(echo1.ol==0 && echo13.ol==0 && echo50ms.ol==0,"old RAM hidden after reset");
  // Consecutive valid samples and invalid-bus noise test read-first alignment.
  phase=6;
  @(negedge clk);valid=1;
  for(n=0;n<96;n=n+1)begin sample=(n%2)?-3000000:2000000;@(negedge clk);end
  valid=0;sample=24'h7fffff;repeat(50)@(negedge clk);
  // SVGA selects a 40MHz video clock in the existing project.
  reset_all();half_period=12.5;clock_hz=40000000;phase=7;tone(1000,96);
  repeat(5)@(negedge clk);
  if(errors+e0+e1+e2+e3+e4+e5+e6+e7==0)
   $display("ALL PASS tb_audio_effects: flat/EQ/signed saturation/50ms echo/reset/continuous valid/25 and 40MHz");
  else $display("FAILED effects total=%0d",errors+e0+e1+e2+e3+e4+e5+e6+e7);
  $finish;
 end
 initial begin #300000000;$display("FAILED effects watchdog");$finish;end
endmodule
`endif
