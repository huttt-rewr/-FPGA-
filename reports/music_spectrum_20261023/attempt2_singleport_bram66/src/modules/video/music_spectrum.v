// Music-Spectrum-inspired rendering, implemented independently for Anlogic.
// No codec, DDR framebuffer, Vivado IP, floating-point core or new IO is used.
// Logical 640x480 coordinates also follow the existing SVGA viewport mapping.
module music_spectrum_overlay(
 input clk,input rst,input vs,input de,input [9:0] x,y,input [23:0] rgb,
 input audio_valid,input signed [23:0] audio_left,input enable,
 output reg out_vs,output reg out_de,output reg [23:0] out_rgb);
 reg vs_last,enabled;
 wire frame_start=vs_last && !vs;
 wire [9:0] dx=x-10'd64;
 wire [4:0] band_index=dx[8:4];
 wire [6:0] height,peak;
 spectrum_analyzer analyzer(clk,rst,frame_start,audio_valid,audio_left,band_index,height,peak);
 wire [5:0] wave_a,wave_b;wire wave_known;
 music_wave_capture waveform(clk,rst,frame_start,audio_valid,audio_left,dx[8:1],wave_a,wave_b,wave_known);
 reg [4:0] color_phase;reg [2:0] color_timer;
 reg v1,d1,panel1,columns1,wave1;
 reg [23:0] rgb1;
 reg [9:0] y1;
 reg [4:0] band1;
 reg [3:0] gap1;
 wire panel=x>=48 && x<592 && y>=256 && y<448;
 wire columns=x>=64 && x<576;
 wire [9:0] bar_distance=10'd376-y1;
 wire bar=columns1 && gap1<14 && y1>=280 && y1<376 && bar_distance<=height && height!=0;
 wire cap=columns1 && gap1<14 && peak!=0 && y1>=278 && y1<376 &&
                         bar_distance>=peak && bar_distance<=peak+1'b1;
 wire [9:0] wy=y1-10'd384;
 wire [5:0] lo=wave_a<wave_b?wave_a:wave_b;
 wire [5:0] hi=wave_a>wave_b?wave_a:wave_b;
 wire trace=wave1 && wave_known && wy>=lo && wy<=({4'b0,hi}+1'b1);
 function [23:0] rainbow;
  input [4:0] index;
  begin
   case(index)
    0:rainbow=24'hf04242;1:rainbow=24'hf06242;2:rainbow=24'hf08342;3:rainbow=24'hf0a442;
    4:rainbow=24'hf0c442;5:rainbow=24'hf0e542;6:rainbow=24'hdaf042;7:rainbow=24'hb9f042;
    8:rainbow=24'h99f042;9:rainbow=24'h78f042;10:rainbow=24'h57f042;11:rainbow=24'h42f04d;
    12:rainbow=24'h42f06e;13:rainbow=24'h42f08e;14:rainbow=24'h42f0af;15:rainbow=24'h42f0d0;
    16:rainbow=24'h42f0f0;17:rainbow=24'h42d0f0;18:rainbow=24'h42aff0;19:rainbow=24'h428ef0;
    20:rainbow=24'h426ef0;21:rainbow=24'h424df0;22:rainbow=24'h5742f0;23:rainbow=24'h7842f0;
    24:rainbow=24'h9942f0;25:rainbow=24'hb942f0;26:rainbow=24'hda42f0;27:rainbow=24'hf042e5;
    28:rainbow=24'hf042c4;29:rainbow=24'hf042a4;30:rainbow=24'hf04283;31:rainbow=24'hf04262;
   endcase
  end
 endfunction
 wire [23:0] color=rainbow(band1+color_phase);
 // Synchronous RAM read and metadata stage, followed by RGB composition:
 // exactly TWO pixel clocks, matching the replaced audio_visualizer instance.
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   vs_last<=1;enabled<=0;color_phase<=0;color_timer<=0;
   v1<=0;d1<=0;panel1<=0;columns1<=0;wave1<=0;rgb1<=0;y1<=0;band1<=0;gap1<=0;
   out_vs<=0;out_de<=0;out_rgb<=0;
  end else begin
   vs_last<=vs;
   if(frame_start)begin
    enabled<=enable;
    if(color_timer==4)begin color_timer<=0;color_phase<=color_phase+1'b1;end
    else color_timer<=color_timer+1'b1;
   end
   v1<=vs;d1<=de;panel1<=enabled && panel;columns1<=columns;
   wave1<=columns && y>=384 && y<448;rgb1<=rgb;y1<=y;band1<=band_index;gap1<=dx[3:0];
   out_vs<=v1;out_de<=d1;
   if(!d1)out_rgb<=0;
   else if(!panel1)out_rgb<=rgb1;
   else if(cap)out_rgb<=24'hfff4dc;
   else if(bar)out_rgb<=color;
   else if(trace)out_rgb<=24'hbfffee;
   else if(y1==376 || y1==416)out_rgb<=24'h284858;
   else out_rgb<={2'b0,rgb1[23:18],2'b0,rgb1[15:10],2'b0,rgb1[7:2]};
  end
 end
endmodule

// Four-sample moving-average waveform, positive zero-cross trigger with
// hysteresis and 1024-sample timeout (DC/silence still refresh). Frozen banks
// prevent the raster reading a capture being overwritten underneath it.
module music_wave_capture(
 input clk,input rst,input frame_start,input audio_valid,input signed [23:0] audio_left,
 input [7:0] display_index,output wire [5:0] wave_a,wave_b,output wire known);
 reg signed [7:0] h0,h1,h2;
 wire signed [9:0] sum=$signed({{2{audio_left[23]}},audio_left[23:16]})+
                         $signed({{2{h0[7]}},h0})+$signed({{2{h1[7]}},h1})+$signed({{2{h2[7]}},h2});
 wire signed [7:0] filtered=sum>>>2;
 wire [7:0] magnitude=filtered[7]?(8'd0-filtered):filtered;
 wire [12:0] scale=({5'd0,magnitude}<<4)+({5'd0,magnitude}<<3);
 wire [5:0] ordinate=filtered[7]?6'd32+scale[12:7]:6'd32-scale[12:7];
 reg armed,capturing,pending,write_bank,frame_bank,have_wave;
 reg [9:0] timeout;
 reg [7:0] capture_index;
 reg [5:0] previous;
 reg [3:0] age;
 wire trigger=(armed && !filtered[7]) || timeout==1023;
 wire store=audio_valid && !pending && (capturing || trigger);
 (* ram_style="bram" *) reg [11:0] history[0:511];
 reg [11:0] q;
 always @(posedge clk)begin
  if(!rst && store)history[{write_bank,capture_index}]<={capturing?previous:ordinate,ordinate};
  q<=history[{frame_bank,display_index}];
 end
 assign wave_a=q[11:6];assign wave_b=q[5:0];assign known=have_wave && age<8;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   h0<=0;h1<=0;h2<=0;armed<=0;capturing<=0;pending<=0;
   write_bank<=0;frame_bank<=1;have_wave<=0;timeout<=0;capture_index<=0;previous<=32;age<=15;
  end else begin
   if(audio_valid)begin
    h0<=audio_left[23:16];h1<=h0;h2<=h1;
    if(!pending)begin
     if(!capturing)begin
      if(filtered < -2)armed<=1;
      if(timeout!=1023)timeout<=timeout+1'b1;
     end
     if(store)begin
      previous<=ordinate;armed<=0;timeout<=0;
      if(capture_index==255)begin capture_index<=0;capturing<=0;pending<=1;end
      else begin capture_index<=capture_index+1'b1;capturing<=1;end
     end
    end
   end
   if(frame_start)begin
    if(pending)begin
     frame_bank<=write_bank;write_bank<=!write_bank;pending<=0;have_wave<=1;age<=0;
    end else if(age!=15)age<=age+1'b1;
   end
  end
 end
endmodule
