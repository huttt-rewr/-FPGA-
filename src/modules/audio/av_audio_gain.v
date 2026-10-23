// Same gain table as WAV playback; mute never stops the AV media timeline.
module av_audio_gain(input clk,rst,valid,input signed [23:0] pcm,
 input [4:0] volume,input mute,output reg out_valid,output reg [23:0] out_pcm);
 reg pending;
 reg signed [40:0] product;
 function [15:0] gain;
  input [4:0] level;
  begin case(level)
   5'd0:gain=16'd32768; 5'd1:gain=16'd33486; 5'd2:gain=16'd34219; 5'd3:gain=16'd34968;
   5'd4:gain=16'd35734; 5'd5:gain=16'd36516; 5'd6:gain=16'd37316; 5'd7:gain=16'd38133;
   5'd8:gain=16'd38968; 5'd9:gain=16'd39821; 5'd10:gain=16'd40693; 5'd11:gain=16'd41584;
   5'd12:gain=16'd42495; 5'd13:gain=16'd43425; 5'd14:gain=16'd44376; 5'd15:gain=16'd45348;
   5'd16:gain=16'd46341; 5'd17:gain=16'd47356; 5'd18:gain=16'd48393; 5'd19:gain=16'd49452;
   5'd20:gain=16'd50535; 5'd21:gain=16'd51642; 5'd22:gain=16'd52773; 5'd23:gain=16'd53928;
   5'd24:gain=16'd55109; 5'd25:gain=16'd56316; 5'd26:gain=16'd57549; 5'd27:gain=16'd58809;
   5'd28:gain=16'd60097; 5'd29:gain=16'd61413; 5'd30:gain=16'd62757; 5'd31:gain=16'd64132;
   default:gain=0;
  endcase end
 endfunction
 always @(posedge clk or posedge rst)begin
  if(rst)begin pending<=0;out_valid<=0;product<=0;out_pcm<=0;end
  else begin
   pending<=valid;out_valid<=pending;
   if(valid)product<=(mute || volume==0)?41'sd0:pcm*$signed({1'b0,gain(volume)});
   if(pending)out_pcm<=product>>>16;
  end
 end
endmodule
