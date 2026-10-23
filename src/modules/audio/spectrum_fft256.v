// Portable 256-point real-input FFT. No vendor FFT/float IP is required.
// One shared signed 16x16 multiplier, Q1.15 Hann/twiddles, /2 at each stage.
// PCM is only observed: busy FFT cycles never stall the actual audio player.
// A block is captured, transformed, then published in NATURAL bin order.
module spectrum_fft256(
 input clk, input rst, input sample_valid, input signed [15:0] sample,
 output reg bin_valid, output reg [7:0] bin_index,
 output reg signed [15:0] bin_real, bin_imag,
 output reg block_done, output wire busy);
 localparam CAP=0,C_WINDOW=1,C_PIPE=2,C_STORE=3,FETCH=4,READ=5,
            M0=6,M1=7,M2=8,M3=9,M4=10,BUTTERFLY=11,WRITE=12,
            SCAN_FETCH=13,SCAN_OUT=14,READ_B=15,WRITE_B=16;
 reg [4:0] state;
 reg [7:0] capture_index,a_index,b_index,scan_index;
 reg [7:0] half_size,j,tw_step;
 reg [8:0] span,group_base;
 reg [6:0] tw_index;
 reg [2:0] stage;
 reg signed [15:0] held_sample,ar,ai,br,bi,mul_x,mul_y;
 reg signed [31:0] product,p0,p1,p2;
 reg signed [16:0] tr,ti;
 reg [31:0] write_a,write_b;
 wire signed [15:0] tw_real,tw_imag,window;
 spectrum_coefficients coefficients(clk,tw_index,capture_index,tw_real,tw_imag,window);
 function [7:0] reverse8;
  input [7:0] v;
  begin reverse8={v[0],v[1],v[2],v[3],v[4],v[5],v[6],v[7]};end
 endfunction
 // Time-share one synchronous RAM port: read A, read B, write A, write B.
 // EG4 true-dual-port width splitting wastes BRAM for a 32-bit complex word.
 // This schedule keeps the same arithmetic while using the wide single port.
 (* ram_style="bram" *) reg [31:0] memory[0:255];
 reg [31:0] qa;
 wire [7:0] addr_a=(state==C_STORE)?reverse8(capture_index):
                        ((state==SCAN_FETCH || state==SCAN_OUT)?scan_index:
                        ((state==READ || state==WRITE_B)?b_index:a_index));
 wire we_a=!rst && (state==C_STORE || state==WRITE || state==WRITE_B);
 wire [31:0] data_a=(state==C_STORE)?{product[30:15],16'b0}:
                                  (state==WRITE?write_a:write_b);
 always @(posedge clk)begin
  if(we_a)memory[addr_a]<=data_a;
  qa<=memory[addr_a];
 end
 // Deliberately only one multiplication expression in the entire FFT.
 always @(posedge clk)product<=mul_x*mul_y;
 wire signed [32:0] real_product=$signed({p0[31],p0})-$signed({p1[31],p1});
 wire signed [32:0] imag_product=$signed({p2[31],p2})+$signed({product[31],product});
 wire signed [17:0] sum_r=$signed({{2{ar[15]}},ar})+$signed({tr[16],tr});
 wire signed [17:0] sum_i=$signed({{2{ai[15]}},ai})+$signed({ti[16],ti});
 wire signed [17:0] dif_r=$signed({{2{ar[15]}},ar})-$signed({tr[16],tr});
 wire signed [17:0] dif_i=$signed({{2{ai[15]}},ai})-$signed({ti[16],ti});
 assign busy=state!=CAP;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=CAP;capture_index<=0;a_index<=0;b_index<=1;scan_index<=0;
   half_size<=1;j<=0;tw_step<=128;span<=2;group_base<=0;tw_index<=0;stage<=0;
   held_sample<=0;ar<=0;ai<=0;br<=0;bi<=0;mul_x<=0;mul_y<=0;
   p0<=0;p1<=0;p2<=0;tr<=0;ti<=0;write_a<=0;write_b<=0;
   bin_valid<=0;bin_index<=0;bin_real<=0;bin_imag<=0;block_done<=0;
  end else begin
   bin_valid<=0;block_done<=0;
   case(state)
    CAP:if(sample_valid)begin held_sample<=sample;state<=C_WINDOW;end
    C_WINDOW:begin mul_x<=held_sample;mul_y<=window;state<=C_PIPE;end
    C_PIPE:state<=C_STORE;
    C_STORE:begin
     if(capture_index==255)begin
      capture_index<=0;a_index<=0;b_index<=1;half_size<=1;j<=0;
      tw_step<=128;span<=2;group_base<=0;tw_index<=0;stage<=0;state<=FETCH;
     end else begin capture_index<=capture_index+1'b1;state<=CAP;end
    end
    FETCH:state<=READ;
    READ:begin ar<=qa[31:16];ai<=qa[15:0];state<=READ_B;end
    READ_B:begin
     br<=qa[31:16];bi<=qa[15:0];
     mul_x<=qa[31:16];mul_y<=tw_real;state<=M0;
    end
    M0:begin mul_x<=bi;mul_y<=tw_imag;state<=M1;end
    M1:begin p0<=product;mul_x<=br;mul_y<=tw_imag;state<=M2;end
    M2:begin p1<=product;mul_x<=bi;mul_y<=tw_real;state<=M3;end
    M3:begin p2<=product;state<=M4;end
    M4:begin tr<=real_product>>>15;ti<=imag_product>>>15;state<=BUTTERFLY;end
    BUTTERFLY:begin
     write_a<={sum_r[16:1],sum_i[16:1]};
     write_b<={dif_r[16:1],dif_i[16:1]};state<=WRITE;
    end
    WRITE:state<=WRITE_B;
    WRITE_B:begin
     if(j==half_size-1'b1)begin
      j<=0;tw_index<=0;
      if(group_base+span>=256)begin
       if(stage==7)begin scan_index<=0;state<=SCAN_FETCH;end
       else begin
        stage<=stage+1'b1;half_size<=half_size<<1;span<=span<<1;tw_step<=tw_step>>1;
        group_base<=0;a_index<=0;b_index<=half_size<<1;state<=FETCH;
       end
      end else begin
       group_base<=group_base+span;
       a_index<=group_base+span;b_index<=group_base+span+half_size;state<=FETCH;
      end
     end else begin
      j<=j+1'b1;tw_index<=tw_index+tw_step;
      a_index<=a_index+1'b1;b_index<=b_index+1'b1;state<=FETCH;
     end
    end
    SCAN_FETCH:state<=SCAN_OUT;
    SCAN_OUT:begin
     bin_valid<=1;bin_index<=scan_index;bin_real<=qa[31:16];bin_imag<=qa[15:0];
     if(scan_index==255)begin block_done<=1;state<=CAP;end
     else begin scan_index<=scan_index+1'b1;state<=SCAN_FETCH;end
    end
    default:state<=CAP;
   endcase
  end
 end
endmodule
