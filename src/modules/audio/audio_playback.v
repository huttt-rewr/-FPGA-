// 48kHz分数累加器：VGA为25MHz、SVGA为40MHz；valid保持单拍均匀节奏。
// FIFO同步读一拍，乘法/饱和再流水两拍；欠载/静音仍发送零样本。
module audio_playback #(parameter CLK_HZ=25000000,parameter ADAPTIVE=0,
 parameter PREFILL=256)(
 input clk,rst,input [4:0] volume,input mute,input mode_800,input stream_ok,
 input fifo_empty,input [10:0] fifo_used,input [23:0] fifo_data,output fifo_rd_en,
 output reg valid,output reg [23:0] left_pcm,right_pcm,output reg underflow);
 reg [31:0] acc;
 wire [31:0] clock_hz=(ADAPTIVE && mode_800)?32'd40000000:CLK_HZ;
 wire [32:0] sum={1'b0,acc}+33'd48000;
 wire tick=sum>={1'b0,clock_hz};
 reg primed;
 reg tick_d,tick_dd,read_d,muted_d;
 reg [15:0] gain_d;
 reg signed [40:0] product;
 wire signed [40:0] scaled=product>>>16;
 function [15:0] gain;
  input [4:0] level;
  begin case(level)
   5'd0:gain=16'd32768;
   5'd1:gain=16'd33486;
   5'd2:gain=16'd34219;
   5'd3:gain=16'd34968;
   5'd4:gain=16'd35734;
   5'd5:gain=16'd36516;
   5'd6:gain=16'd37316;
   5'd7:gain=16'd38133;
   5'd8:gain=16'd38968;
   5'd9:gain=16'd39821;
   5'd10:gain=16'd40693;
   5'd11:gain=16'd41584;
   5'd12:gain=16'd42495;
   5'd13:gain=16'd43425;
   5'd14:gain=16'd44376;
   5'd15:gain=16'd45348;
   5'd16:gain=16'd46341;
   5'd17:gain=16'd47356;
   5'd18:gain=16'd48393;
   5'd19:gain=16'd49452;
   5'd20:gain=16'd50535;
   5'd21:gain=16'd51642;
   5'd22:gain=16'd52773;
   5'd23:gain=16'd53928;
   5'd24:gain=16'd55109;
   5'd25:gain=16'd56316;
   5'd26:gain=16'd57549;
   5'd27:gain=16'd58809;
   5'd28:gain=16'd60097;
   5'd29:gain=16'd61413;
   5'd30:gain=16'd62757;
   5'd31:gain=16'd64132;
   default:gain=0;
  endcase end
 endfunction
 // 源端为符号扩展16bit；左移8位适配HDMI的24bit满量程。
 // 指定指数表为1..1.957，除65536使最大增益小于1，保留削波裕量；
 // volume=0专门静音，1..31约为-5.83..-0.19dB。
 assign fifo_rd_en=tick && primed && stream_ok && !fifo_empty && !rst;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   acc<=0;primed<=0;tick_d<=0;tick_dd<=0;read_d<=0;muted_d<=1;gain_d<=0;
   product<=0;valid<=0;left_pcm<=0;right_pcm<=0;underflow<=0;
  end else begin
   if(tick)acc<=sum-clock_hz;else acc<=sum[31:0];
   if(!stream_ok)primed<=0;
   else if(!primed && fifo_used>=PREFILL)primed<=1;
   else if(tick && fifo_empty)begin
    if(primed)underflow<=1;
    primed<=0;
   end
   tick_d<=tick;tick_dd<=tick_d;valid<=tick_dd;
   read_d<=fifo_rd_en;
   muted_d<=mute || volume==0 || !stream_ok;
   gain_d<=gain(volume);
   if(tick_d)begin
    if(read_d && !muted_d)product<=$signed({fifo_data[15:0],8'b0})*$signed({1'b0,gain_d});
    else product<=0;
   end
   if(tick_dd)begin
    if(scaled>41'sd8388607)begin left_pcm<=24'h7fffff;right_pcm<=24'h7fffff;end
    else if(scaled< -41'sd8388608)begin left_pcm<=24'h800000;right_pcm<=24'h800000;end
    else begin left_pcm<=scaled[23:0];right_pcm<=scaled[23:0];end
   end
  end
 end
endmodule
