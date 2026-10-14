// Mono 48kHz effects, fixed parameters; no new control or clock domain.
// Two register stages: EQ + synchronous old-data RAM read, then echo + output.
// The specified delay stores EQ (feed-forward), so an impulse has ONE echo.
// Zero gains are bit-exact bypass, with the same two-stage valid latency.
module audio_effects #(
 parameter integer N_TAP=15,
 parameter signed [15:0] BASS_GAIN=16'sd0,
 parameter signed [15:0] TREBLE_GAIN=16'sd0,
 parameter integer ECHO_DELAY=2400,
 parameter signed [15:0] ECHO_FEEDBACK=16'sd0
)(
 input clk,rst,src_valid,
 input signed [23:0] src_left,src_right,
 output reg out_valid,
 output reg signed [23:0] out_left,out_right
);
 // 15-point Hamming-window sinc, fc=1kHz, fs=48kHz, normalized Q1.15.
 // Symmetric and exact unity DC sum: 32768. N_TAP=15 is the only table.
 localparam signed [15:0] H0=304,H1=496,H2=1034,H3=1835,
  H4=2749,H5=3590,H6=4180,H7=4392;
 function signed [15:0] coefficient;
  input integer k;
  begin case(k)
   0,14:coefficient=H0;1,13:coefficient=H1;2,12:coefficient=H2;
   3,11:coefficient=H3;4,10:coefficient=H4;5,9:coefficient=H5;
   6,8:coefficient=H6;7:coefficient=H7;default:coefficient=0;
  endcase end
 endfunction
 function [23:0] sat24;
  input signed [48:0] v;
  begin
   if(v>49'sd8388607)sat24=24'h7fffff;
   else if(v< -49'sd8388608)sat24=24'h800000;
   else sat24=v[23:0];
  end
 endfunction
 // synthesis translate_off
 initial begin
  if(N_TAP!=15 || ECHO_DELAY<1 || ECHO_FEEDBACK<0)begin
   $display("FAILED audio_effects: N_TAP must be 15, ECHO_DELAY >= 1, feedback 0..32767");
   $finish;
  end
 end
 // synthesis translate_on
 reg signed [23:0] history[0:13];
 wire signed [39:0] product[0:14];
 wire signed [43:0] leaf[0:15];
 wire signed [43:0] pair[0:7],quad[0:3],octet[0:1];
 genvar k;
 generate for(k=0;k<15;k=k+1)begin: fir
  if(k==0)assign product[k]=src_left*coefficient(k);
  else assign product[k]=history[k-1]*coefficient(k);
  assign leaf[k]={{4{product[k][39]}},product[k]};
 end
 for(k=0;k<8;k=k+1)begin: sum2
  assign pair[k]=leaf[2*k]+leaf[2*k+1];
 end
 for(k=0;k<4;k=k+1)begin: sum4
  assign quad[k]=pair[2*k]+pair[2*k+1];
 end
 for(k=0;k<2;k=k+1)begin: sum8
  assign octet[k]=quad[2*k]+quad[2*k+1];
 end endgenerate
 assign leaf[15]=44'sd0;
 wire signed [43:0] fir_sum=octet[0]+octet[1];
 wire signed [28:0] low=fir_sum>>>15;
 wire signed [29:0] high=$signed({{6{src_left[23]}},src_left})-
                             $signed({low[28],low});
 wire signed [44:0] bass_product=low*BASS_GAIN;
 wire signed [45:0] treble_product=high*TREBLE_GAIN;
 wire signed [48:0] bass_term=$signed({{4{bass_product[44]}},bass_product})>>>15;
 wire signed [48:0] treble_term=$signed({{3{treble_product[45]}},treble_product})>>>15;
 wire signed [48:0] eq_sum=$signed({{25{src_left[23]}},src_left})+bass_term+treble_term;
 wire signed [23:0] eq=sat24(eq_sum);
 reg valid_d;
 reg signed [23:0] eq_d;
 integer i;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   valid_d<=0;eq_d<=0;
   for(i=0;i<14;i=i+1)history[i]<=0;
  end else begin
   valid_d<=src_valid;
   if(src_valid)begin
    eq_d<=eq;
    history[0]<=src_left;
    for(i=1;i<14;i=i+1)history[i]<=history[i-1];
   end
  end
 end
 wire signed [48:0] echoed;
 generate if(ECHO_FEEDBACK!=0)begin: echo_delay
  localparam PTR_BITS=(ECHO_DELAY<=1)?1:$clog2(ECHO_DELAY);
  reg signed [23:0] echo_mem[0:ECHO_DELAY-1];
  reg [PTR_BITS-1:0] wptr;
  reg echo_primed,use_echo_d;
  reg signed [23:0] delayed;
  // Read-first synchronous RAM; memory is never reset or initialized.
  // Only the read register has synchronous reset, so BRAM can be inferred.
  always @(posedge clk)begin
   if(rst)delayed<=0;
   else if(src_valid)delayed<=echo_mem[wptr];
   if(!rst && src_valid)echo_mem[wptr]<=eq;
  end
  always @(posedge clk or posedge rst)begin
   if(rst)begin wptr<=0;echo_primed<=0;use_echo_d<=0;end
   else if(src_valid)begin
    use_echo_d<=echo_primed;
    if(wptr==ECHO_DELAY-1)begin wptr<=0;echo_primed<=1;end
    else wptr<=wptr+1'b1;
   end
  end
  wire signed [39:0] echo_product=delayed*ECHO_FEEDBACK;
  wire signed [48:0] echo_term=$signed({{9{echo_product[39]}},echo_product})>>>15;
  assign echoed=$signed({{25{eq_d[23]}},eq_d})+(use_echo_d?echo_term:49'sd0);
 end else begin: no_echo
  // No delay BRAM is allocated when echo is disabled.
  assign echoed=$signed({{25{eq_d[23]}},eq_d});
 end endgenerate
 always @(posedge clk or posedge rst)begin
  if(rst)begin out_valid<=0;out_left<=0;out_right<=0;end
  else begin
   out_valid<=valid_d;
   if(valid_d)begin out_left<=sat24(echoed);out_right<=sat24(echoed);end
  end
 end
 // src_right intentionally unused: playback supplies identical mono channels.
endmodule
