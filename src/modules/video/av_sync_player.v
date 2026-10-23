// AVF PCM is mono 16 kHz, held for three uniformly spaced HDMI 48 kHz ticks.
// Audio advances at the record boundary; video ownership returns only at vblank.
module av_sync_player #(parameter VGA_HZ=25000000, parameter SAMPLES=800)(
 input clk, input rst, input mode_800, input vblank,
 input request_toggle, input requested_bank, input play, input failed, input ended,
 output reg ack_toggle, output reg [1:0] active_buffer,
 output reg visible, output buffering,
 input write_clk, input audio_we, input [10:0] audio_address,
 input [15:0] audio_data,
 output reg audio_valid, output reg [23:0] left_pcm, output reg [23:0] right_pcm
);
 (* ram_style="block" *) reg [15:0] pcm_mem [0:2047];
 reg [15:0] pcm_q;
 reg audio_bank;
 reg [9:0] sample_index;
 reg [1:0] repeat_index;
 reg exhausted, switching;
 reg switch_bank, switch_request;
 reg req_meta, req_sync, bank_meta, bank_sync;
 reg play_meta, play_sync, fail_meta, fail_sync, end_meta, end_sync;
 reg [31:0] phase;
 wire [31:0] clock_hz=mode_800 ? 32'd40000000 : VGA_HZ;
 wire [32:0] phase_next={1'b0,phase}+33'd48000;
 wire tick=phase_next>={1'b0,clock_hz};
 wire pending=req_sync!=ack_toggle;
 assign buffering=visible && exhausted && !end_sync && !fail_sync;

 // No RAM reset: the producer fills a complete bank before publishing it.
 always @(posedge write_clk)
  if(audio_we)pcm_mem[audio_address]<=audio_data;
 always @(posedge clk)pcm_q<=pcm_mem[{audio_bank,sample_index}];

 always @(posedge clk or posedge rst)begin
  if(rst)begin
   req_meta<=0;req_sync<=0;bank_meta<=0;bank_sync<=0;
   play_meta<=0;play_sync<=0;fail_meta<=0;fail_sync<=0;end_meta<=0;end_sync<=0;
   phase<=0;ack_toggle<=0;active_buffer<=0;visible<=0;
   audio_bank<=0;sample_index<=0;repeat_index<=0;exhausted<=1;
   switching<=0;switch_bank<=0;switch_request<=0;
   audio_valid<=0;left_pcm<=0;right_pcm<=0;
  end else begin
   req_meta<=request_toggle;req_sync<=req_meta;
   bank_meta<=requested_bank;bank_sync<=bank_meta;
   play_meta<=play;play_sync<=play_meta;
   fail_meta<=failed;fail_sync<=fail_meta;
   end_meta<=ended;end_sync<=end_meta;
   phase<=tick ? phase_next-clock_hz : phase_next[31:0];
   audio_valid<=tick;

   if(!fail_sync && play_sync)begin
    if(switching && vblank)begin
     active_buffer<={1'b0,switch_bank};ack_toggle<=switch_request;
     switching<=0;
    end else if(exhausted && pending && vblank)begin
     // Startup and underrun recovery share the same frame-safe commit.
     active_buffer<={1'b0,bank_sync};ack_toggle<=req_sync;visible<=1;
     audio_bank<=bank_sync;sample_index<=0;repeat_index<=0;exhausted<=0;
    end
   end

   if(tick)begin
    left_pcm<=0;right_pcm<=0;
    if(visible && !exhausted && play_sync && !fail_sync)begin
     left_pcm<={pcm_q,8'd0};right_pcm<={pcm_q,8'd0};
     if(repeat_index!=2)repeat_index<=repeat_index+1'b1;
     else begin
      repeat_index<=0;
      if(sample_index!=SAMPLES-1)sample_index<=sample_index+1'b1;
      else if(pending && !switching)begin
       // The next audio bank is ready; commit video only at vblank.
       // Always raise switching (never commit here): an immediate commit
       // skips the switching pulse, so the consumer's swap-to-ack window
       // spans a whole extra frame and breaks the refresh deadline.
       audio_bank<=bank_sync;sample_index<=0;
       switch_bank<=bank_sync;switch_request<=req_sync;
       switching<=1;
      end else exhausted<=1;
     end
    end
   end
  end
 end
endmodule
