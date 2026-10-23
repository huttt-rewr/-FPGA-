`timescale 1ns/1ps
// Independent write clock, pause at a repeated PCM sample, underrun/restart,
// publication ownership and exact 48 kHz fractional tick spacing.
module tb_av_controls;
 reg clk=0,wclk=0,rst=1,we=0,req=0,bank=0,play=1,failed=0,vblank=0;
 reg [10:0] addr=0;reg [15:0] data=0;
 always #5 clk=~clk;
 always #7 wclk=~wclk;
 wire ack,visible,buffering,valid;wire [1:0] active;wire [23:0] left,right;
 reg rate_rst=1,rate_mode=0;wire rate_valid;wire [23:0] rate_left;
 integer i,n,saved_index,saved_repeat,expected,count,last_tick,spacing;
 av_sync_player #(.VGA_HZ(480000),.SAMPLES(4)) dut(
  .clk(clk),.rst(rst),.mode_800(1'b0),.vblank(vblank),
  .request_toggle(req),.requested_bank(bank),.play(play),.failed(failed),.ended(1'b0),
  .ack_toggle(ack),.active_buffer(active),.visible(visible),.buffering(buffering),
  .write_clk(wclk),.audio_we(we),.audio_address(addr),.audio_data(data),
  .audio_valid(valid),.left_pcm(left),.right_pcm(right));
 av_sync_player rate_dut(.clk(clk),.rst(rate_rst),.mode_800(rate_mode),.vblank(1'b0),
  .request_toggle(1'b0),.requested_bank(1'b0),.play(1'b0),.failed(1'b0),.ended(1'b0),
  .ack_toggle(),.active_buffer(),.visible(),.buffering(),.write_clk(wclk),
  .audio_we(1'b0),.audio_address(11'd0),.audio_data(16'd0),
  .audio_valid(rate_valid),.left_pcm(rate_left),.right_pcm());
 task blank;begin @(negedge clk);vblank=1;@(negedge clk);vblank=0;end endtask
 task next_sample;begin @(negedge clk);while(!valid)@(negedge clk);end endtask
 task check_sample;input integer value;begin
  next_sample;
  if(left!==((value&65535)<<8) || right!==left)
   $fatal(1,"FAILED PCM value=%d got=%h",value,left);
 end endtask
 initial begin
  // Signed values also check preservation of the PCM sign bit.
  for(i=0;i<4;i=i+1)begin
   @(negedge wclk);we=1;addr=i;data=i-2;
  end
  for(i=0;i<4;i=i+1)begin
   @(negedge wclk);addr=1024+i;data=i+11;
  end
  @(negedge wclk);we=0;
  @(negedge clk);rst=0;req=1;
  repeat(6)@(negedge clk);blank;
  if(!ack || !visible || active!=0)$fatal(1,"FAILED first frame");
  for(n=0;n<4;n=n+1)check_sample(n/3-2);
  // Stop well before the next HDMI tick, allowing the control synchronizer.
  play=0;repeat(3)@(negedge clk);
  saved_index=dut.sample_index;saved_repeat=dut.repeat_index;
  for(n=0;n<5;n=n+1)check_sample(0);
  if(dut.sample_index!=saved_index || dut.repeat_index!=saved_repeat)
   $fatal(1,"FAILED pause moved media position");
  play=1;
  for(n=4;n<12;n=n+1)check_sample(n/3-2);
  if(!buffering || !dut.exhausted || active!=0 || !ack)
   $fatal(1,"FAILED underrun failed to retain frame ownership");
  for(n=0;n<4;n=n+1)check_sample(0);
  // A completed replacement must wait for vblank, even when already buffering.
  bank=1;req=0;repeat(6)@(negedge clk);
  if(!ack || active!=0)$fatal(1,"FAILED early rebuffer commit");
  blank;
  if(ack || active!=1 || buffering)$fatal(1,"FAILED rebuffer restart");
  for(n=0;n<4;n=n+1)check_sample(n/3+11);
  failed=1;bank=0;req=1;repeat(6)@(negedge clk);
  saved_index=dut.sample_index;saved_repeat=dut.repeat_index;
  blank;
  for(n=0;n<4;n=n+1)check_sample(0);
  if(ack || active!=1 || dut.sample_index!=saved_index || dut.repeat_index!=saved_repeat)
   $fatal(1,"FAILED failure released bank or advanced PCM");
  // Real divider constants: exactly 48 ticks per 1 ms, bounded one-cycle jitter.
  for(rate_mode=0;rate_mode<2;rate_mode=rate_mode+1'b1)begin
   rate_rst=1;repeat(3)@(negedge clk);rate_rst=0;count=0;last_tick=0;
   for(i=1;i<=(rate_mode?40000:25000);i=i+1)begin
    @(negedge clk);
    if(rate_valid)begin
     spacing=i-last_tick;last_tick=i;count=count+1;
     if(rate_left!==0 || (rate_mode?(spacing<833 || spacing>834):(spacing<520 || spacing>521)))
      $fatal(1,"FAILED fractional tick spacing=%d mode=%b",spacing,rate_mode);
    end
   end
   if(count!=48)$fatal(1,"FAILED expected 48 samples per ms got=%d",count);
   if(rate_mode)begin
    $display("ALL PASS tb_av_controls: asynchronous PCM writes, pause/resume, signed PCM, underrun/rebuffer, failure silence, 25/40 MHz sample rates");
    $finish;
   end
  end
 end
 initial begin #1000000;$fatal(1,"FAILED tb_av_controls timeout");end
endmodule
