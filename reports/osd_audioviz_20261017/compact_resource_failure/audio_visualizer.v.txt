// Signed waveform, circular LUT RAM. Default avoids the bottom caption.
module audio_visualizer #(parameter [9:0] WIN_X=24,WIN_Y=344,WIN_W=256,WIN_H=80,parameter N=128)(
 input clk,rst,vs,de,input [9:0] x,y,input [23:0] rgb,input audio_valid,input signed [23:0] audio_left,input enable,
 output reg out_vs,out_de,output reg [23:0] out_rgb);
 localparam AW=$clog2(N),XS=$clog2(WIN_W)-$clog2(N);
 // Fill one bank while displaying a frozen other bank, preventing a waveform
 // changing under the raster. This never changes the source PCM/HDMI cadence.
 (* ram_style="dram" *) reg signed [7:0] hist[0:2*N-1];
 reg bank,frame_bank;
 reg [AW-1:0] head,frame_head;reg [AW:0] count,frame_count;reg enabled,vs_last;
 wire [9:0] dx=x-WIN_X;wire [AW-1:0] column=dx>>XS,read_index=frame_head+column;
 wire available={1'b0,column}>=(N-frame_count);
 wire panel=(x>=WIN_X && {1'b0,x}<{1'b0,WIN_X}+WIN_W && y>=WIN_Y && {1'b0,y}<{1'b0,WIN_Y}+WIN_H);
 wire signed [7:0] value=hist[{frame_bank,read_index}];wire [7:0] magnitude=value[7]?(8'd0-value):value;
 function [15:0] scale_amplitude;
  input [7:0] m;integer k;reg [15:0] v;
  begin v=0;for(k=0;k<10;k=k+1)if((((WIN_H>>1)-2)>>k)&1)v=v+({8'd0,m}<<k);scale_amplitude=v;end
 endfunction
 wire [15:0] scale=scale_amplitude(magnitude);
 wire [9:0] offset=scale>>7,centre=WIN_Y+(WIN_H>>1),sample_y=value[7]?centre+offset:centre-offset;
 reg [9:0] yy1,trace1;reg [23:0] rgb1;reg vs1,de1,panel1,known1;
 wire trace=known1 && (yy1==trace1 || yy1==trace1+1'b1),axis=yy1==centre;
 wire frame_start=vs_last && !vs;
 always @(posedge clk)if(!rst && audio_valid && !frame_start)hist[{bank,head}]<=audio_left[23:16];
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   bank<=0;frame_bank<=1;head<=0;frame_head<=0;count<=0;frame_count<=0;enabled<=0;vs_last<=1;yy1<=0;trace1<=0;rgb1<=0;
   vs1<=0;de1<=0;panel1<=0;known1<=0;out_vs<=0;out_de<=0;out_rgb<=0;
  end else begin
   if(audio_valid)begin head<=head+1'b1;if(count<N)count<=count+1'b1;end
   vs_last<=vs;if(frame_start)begin frame_bank<=bank;bank<=!bank;frame_head<=head;frame_count<=count;head<=0;count<=0;enabled<=enable;end
   yy1<=y;trace1<=sample_y;rgb1<=rgb;vs1<=vs;de1<=de;panel1<=enabled && panel;known1<=available;
   out_vs<=vs1;out_de<=de1;
   if(!de1)out_rgb<=0;else if(!panel1)out_rgb<=rgb1;
   else if(trace)out_rgb<={1'b0,rgb1[23:17],(8'd128+{1'b0,rgb1[15:9]}),(8'd96+{2'b0,rgb1[7:2]})};
   else if(axis)out_rgb<={2'b0,rgb1[23:18],8'd64,8'd72};
   else out_rgb<={1'b0,rgb1[23:17],1'b0,rgb1[15:9],1'b0,rgb1[7:1]};
  end
 end
endmodule
