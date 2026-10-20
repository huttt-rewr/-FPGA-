// Preserve the HDMI sample schedule while a stream flush clears FIR/echo state.
// stream_rst must assert asynchronously and release synchronously to clk.
module audio_effects_stream #(
 parameter signed [15:0] BASS_GAIN=0,TREBLE_GAIN=0,ECHO_FEEDBACK=0,
 parameter integer ECHO_DELAY=2400
)(input clk,rst,stream_rst,src_valid,
 input signed [23:0] src_left,src_right,
 output out_valid,output signed [23:0] out_left,out_right);
 wire fx_valid;wire signed [23:0] fx_left,fx_right;
 reg valid_d,scheduled_valid;
 always @(posedge clk)begin
  if(rst)begin valid_d<=0;scheduled_valid<=0;end
  else begin valid_d<=src_valid;scheduled_valid<=valid_d;end
 end
 audio_effects #(.BASS_GAIN(BASS_GAIN),.TREBLE_GAIN(TREBLE_GAIN),
  .ECHO_FEEDBACK(ECHO_FEEDBACK),.ECHO_DELAY(ECHO_DELAY)) fx(
  .clk(clk),.rst(rst | stream_rst),.src_valid(src_valid),
  .src_left(src_left),.src_right(src_right),
  .out_valid(fx_valid),.out_left(fx_left),.out_right(fx_right));
 assign out_valid=scheduled_valid;
 assign out_left=(stream_rst || !fx_valid)?24'sd0:fx_left;
 assign out_right=(stream_rst || !fx_valid)?24'sd0:fx_right;
endmodule
