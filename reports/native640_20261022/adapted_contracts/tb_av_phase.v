`timescale 1ns/1ps
// Sweep every HDMI tick phase and 128 frames of 50 ms / 16.8 ms phase drift.
// Time is accelerated by the clock-rate parameter; all interval ratios are exact.
// A bounded producer publishes 25 ms after each buffer-return acknowledgement.
module tb_av_phase;
 reg clk=0,rst=1,we=0,request=0,bank=0,ended=0,vblank=0;
 always #5 clk=~clk;
 reg [10:0] address=0;reg [15:0] data=0;
 wire ack,visible,buffering,audio_valid;
 wire [1:0] active;wire [23:0] left,right;
 integer phase_case,i,cycle=0,blank_counter=0,load_left=0,commits=0,ticks=0;
 integer expected,swap_cycle=0,max_video_wait=0,wait_cycles;
 reg previous_ack=0,previous_switch=0,initial_commit=0;
 av_sync_player #(.VGA_HZ(240000),.SAMPLES(800)) dut(
  .clk(clk),.rst(rst),.mode_800(1'b0),.vblank(vblank),
  .request_toggle(request),.requested_bank(bank),.play(1'b1),.failed(1'b0),.ended(ended),
  .ack_toggle(ack),.active_buffer(active),.visible(visible),.buffering(buffering),
  .write_clk(clk),.audio_we(we),.audio_address(address),.audio_data(data),
  .audio_valid(audio_valid),.left_pcm(left),.right_pcm(right));
 always @(posedge clk)begin
  if(rst)begin blank_counter<=phase_case;vblank<=0;end
  else begin
   blank_counter<=blank_counter==4031?0:blank_counter+1;
   vblank<=blank_counter==4031;
  end
 end
 always @(negedge clk)begin
  if(rst)begin
   cycle=0;load_left=0;commits=0;ticks=0;
   previous_ack=0;previous_switch=0;swap_cycle=0;
  end else begin
   cycle=cycle+1;initial_commit=0;
   if(buffering)$fatal(1,"FAILED phase=%0d frame=%0d underrun",phase_case,ticks/2400);
   if(load_left>0)begin
    load_left=load_left-1;
    if(load_left==0)begin bank=commits[0];request=!request;end
   end
   if(dut.switching && !previous_switch)swap_cycle=cycle;
   previous_switch=dut.switching;
   if(ack!=previous_ack)begin
    initial_commit=commits==0;
    if(active!=={1'b0,commits[0]})$fatal(1,"FAILED phase=%0d wrong video bank",phase_case);
    if(commits>0)begin
     wait_cycles=cycle-swap_cycle;
     if(wait_cycles>4032)$fatal(1,"FAILED video delay exceeds a refresh");
     if(wait_cycles>max_video_wait)max_video_wait=wait_cycles;
    end
    previous_ack=ack;commits=commits+1;
    if(commits==128)ended=1;
    else load_left=6000;
   end
   // When first vblank and tick coincide, that tick was still startup silence.
   if(audio_valid && visible && !initial_commit && ticks<307200)begin
    expected=((ticks/2400)%2)*1000+(ticks%2400)/3+1;
    if(left!=={expected[15:0],8'd0} || right!==left)
     $fatal(1,"FAILED phase=%0d PCM tick=%0d got=%h expected=%0d",phase_case,ticks,left,expected);
    ticks=ticks+1;
   end
  end
 end
 initial begin
  for(phase_case=0;phase_case<5;phase_case=phase_case+1)begin
   rst=1;request=0;bank=0;ended=0;
   repeat(5)@(negedge clk);
   for(i=0;i<800;i=i+1)begin we=1;address=i;data=i+1;@(negedge clk);end
   for(i=0;i<800;i=i+1)begin address=1024+i;data=i+1001;@(negedge clk);end
   we=0;rst=0;request=1;
   wait(ticks==307200);repeat(8)@(negedge clk);
   if(commits!=128 || buffering || left!==0 || !dut.exhausted)
    $fatal(1,"FAILED phase=%0d final state",phase_case);
   $display("phase %0d: 128 frames, exact PCM, no underrun",phase_case);
  end
  $display("max_video_wait_cycles=%0d refresh_cycles=4032",max_video_wait);
  $display("ALL PASS tb_av_phase: 5 HDMI tick phases, 640 frames, bounded 25 ms producer, 50/16.8 ms phase drift, PCM order, bank reuse, EOF silence");
  $finish;
 end
 initial begin #90000000;$fatal(1,"FAILED tb_av_phase timeout");end
endmodule
