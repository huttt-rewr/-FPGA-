// 32 low-dense/high-sparse bands, max aggregation (not isolated FFT sampling).
// Completed spectra are committed only at vertical blank. Envelopes and peak
// markers share a synchronous dual-port BRAM with the two result snapshots.
module spectrum_analyzer(
 input clk,input rst,input frame_start,input audio_valid,
 input signed [23:0] audio_left,input [4:0] display_band,
 output reg [6:0] display_height,display_peak);
 wire bin_valid,block_done,fft_busy;
 wire [7:0] bin;wire signed [15:0] re,im;
 reg pending,write_bank,frame_bank,have_spectrum;
 reg [3:0] age;
 reg [2:0] update_state;
 reg [4:0] update_index,previous_band;
 reg [6:0] target_height;
 reg [13:0] updated_envelope;
 reg update_bank,update_available;
 reg [1:0] decay_phase;
 reg [15:0] accumulator;
 localparam INIT=0,IDLE=1,TARGET=2,OLD=3,MATH=4,STORE=5;
 spectrum_fft256 fft(clk,rst,audio_valid && !pending && update_state!=INIT,
                    audio_left[23:8],bin_valid,bin,re,im,block_done,fft_busy);
 function [4:0] band_for;
  input [7:0] k;
  begin
   if(k<=16)band_for=k-1'b1;
   else if(k<18)band_for=16;else if(k<20)band_for=17;
   else if(k<23)band_for=18;else if(k<26)band_for=19;
   else if(k<30)band_for=20;else if(k<35)band_for=21;
   else if(k<41)band_for=22;else if(k<48)band_for=23;
   else if(k<56)band_for=24;else if(k<65)band_for=25;
   else if(k<75)band_for=26;else if(k<86)band_for=27;
   else if(k<98)band_for=28;else if(k<111)band_for=29;
   else if(k<120)band_for=30;else band_for=31;
  end
 endfunction
 function [6:0] compress;
  input [15:0] amplitude;
  integer bit_index;reg [4:0] exponent;reg [15:0] fraction;
  reg [7:0] result;
  begin
   exponent=0;
   for(bit_index=0;bit_index<16;bit_index=bit_index+1)
    if(amplitude[bit_index])exponent=bit_index;
   fraction=amplitude>>(exponent>=2?exponent-2:0);
   // Approximate log2 with four substeps. Values <8 are a noise floor.
   result=exponent>=3?((exponent-3)<<3)+{fraction[1:0],1'b0}:0;
   compress=result>96?96:result[6:0];
  end
 endfunction
 wire [4:0] current_band=band_for(bin);
 wire [15:0] abs_re=re[15]?(16'd0-re):re;
 wire [15:0] abs_im=im[15]?(16'd0-im):im;
 wire [16:0] magnitude={1'b0,abs_re}+{1'b0,abs_im};
 wire [15:0] amplitude=magnitude[16]?16'hffff:magnitude[15:0];
 wire flush_band=bin_valid && !pending && bin>1 && bin<=128 &&
                       (bin==128 || current_band!=previous_band);
 (* ram_style="bram" *) reg [13:0] levels[0:127];
 reg [13:0] qa,qdisplay;
 wire [6:0] address_a=flush_band?{1'b1,write_bank,previous_band}:
                       (update_state==TARGET?{1'b1,update_bank,update_index}:{2'b0,update_index});
 wire write_a=!rst && (flush_band || update_state==INIT || update_state==STORE);
 wire [13:0] data_a=flush_band?{7'b0,compress(accumulator)}:
                        (update_state==INIT?14'b0:updated_envelope);
 always @(posedge clk)begin
  qa<=levels[address_a];
  if(write_a)levels[address_a]<=data_a;
 end
 always @(posedge clk)qdisplay<=levels[{2'b0,display_band}];
 always @*begin display_height=qdisplay[6:0];display_peak=qdisplay[13:7];end
 wire [6:0] next_height=target_height>=qa[6:0]?target_height:
                                  (qa[6:0]>2?qa[6:0]-7'd2:7'd0);
 wire [6:0] decayed_peak=(decay_phase==0 && qa[13:7]!=0)?qa[13:7]-1'b1:qa[13:7];
 wire [6:0] next_peak=next_height>=decayed_peak?next_height:decayed_peak;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   pending<=0;write_bank<=0;frame_bank<=1;have_spectrum<=0;age<=15;
   update_state<=INIT;update_index<=0;previous_band<=0;target_height<=0;
   updated_envelope<=0;update_bank<=0;update_available<=0;decay_phase<=0;accumulator<=0;
  end else begin
   if(bin_valid && !pending && bin>=1 && bin<128)begin
    previous_band<=current_band;
    if(bin==1 || current_band!=previous_band)accumulator<=amplitude;
    else if(amplitude>accumulator)accumulator<=amplitude;
   end
   if(bin_valid && bin==128 && !pending)pending<=1;
   case(update_state)
    INIT:if(update_index==31)begin update_index<=0;update_state<=IDLE;end
         else update_index<=update_index+1'b1;
    IDLE:if(frame_start)begin
     update_index<=0;update_state<=TARGET;
     update_bank<=pending?write_bank:frame_bank;
     update_available<=pending || (have_spectrum && age<8);
     decay_phase<=decay_phase+1'b1;
     if(pending)begin
      frame_bank<=write_bank;write_bank<=!write_bank;pending<=0;have_spectrum<=1;age<=0;
     end else if(age!=15)age<=age+1'b1;
    end
    TARGET:update_state<=OLD;
    OLD:begin target_height<=update_available?qa[6:0]:7'd0;update_state<=MATH;end
    MATH:begin updated_envelope<={next_peak,next_height};update_state<=STORE;end
    STORE:if(update_index==31)begin update_index<=0;update_state<=IDLE;end
          else begin update_index<=update_index+1'b1;update_state<=TARGET;end
    default:update_state<=INIT;
   endcase
  end
 end
endmodule
