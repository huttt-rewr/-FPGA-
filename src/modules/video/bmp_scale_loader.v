// Stream source rows through horizontal interpolation; cache OUTPUT columns.
// Source images up to 1920x1080 retain the exact Q8 bilinear rounding order.
// Output is bottom-up 640x480 (the existing SDRAM writer flips rows).
// Contain fit, black borders, endpoint-aligned Q16 coordinates, Q8 bilinear weights.
// All large divisions run once per image using a 28-cycle restoring divider.
module bmp_scale_loader #(parameter ADAPTIVE=0)(
 input clk,input rst,input start,
 input [11:0] source_width,input [11:0] source_height,
 input [31:0] pixel_offset,input [31:0] base_sector,
 output reg sector_read,output reg [31:0] sector_address,
 input [7:0] sector_data,input sector_valid,input sector_end,
 output reg [23:0] pixel,output reg pixel_valid,input pixel_ready,
 output reg done,output reg error,output reg busy, input mode_800);
 reg [9:0] ow,oh;
 // Explicit one-hot encoding avoids cascaded binary-state decoders in the
 // 100 MHz divider and pixel register enables. State transitions are unchanged.
 localparam [31:0] IDLE=24'h000001,CONFIG=24'h000002,DIVIDE=24'h000004,
  DIV_DONE=24'h000008,ROW=24'h000010,CHECK_ROWS=24'h000020,
  LINE_START=24'h000040,CACHE=24'h000080,FETCH=24'h000100,BYTE=24'h000200,
  PIXEL=24'h000400,LEFT_WAIT=24'h000800,LEFT_GET=24'h001000,
  RIGHT_WAIT=24'h002000,RIGHT_GET=24'h004000,VERTICAL=24'h008000,
  SEND=24'h010000,HWAIT1=24'h020000,HWAIT2=24'h040000,HCAPTURE=24'h080000,
  VWAIT1=24'h100000,VWAIT2=24'h200000,VWAIT3=24'h400000,CONFIG_CHECK=24'h800000,ROW_PROBE=25'h1000000,
  SIZE_APPLY=26'h2000000,
  SAMPLE_CHECK=31'h04000000,SAMPLE_WAIT1=31'h08000000,
  SAMPLE_WAIT2=31'h10000000,SAMPLE_WAIT3=31'h20000000,SAMPLE_STORE=31'h40000000,
  PIXEL_PROBE=32'h80000000;
 reg [31:0] state;
 reg pixel_inside;
 reg sample_last,sample_endpoint;
 reg row0_hit,row1_hit;
 reg [11:0] w,h,load_y,tag0,tag1;
 // Compute the invariant row end once, instead of w -> subtract -> compare
 // on every BYTE-state transition (the baseline worst setup path).
 reg [10:0] last_source_x;
 reg [1:0] tags_valid;
 reg [12:0] stride;
 reg [31:0] offset,base,byte_address,cache_sector;
 reg cache_valid;
 reg [9:0] cache_count;
 reg [10:0] load_x;reg [9:0] read_x,load_sample;
 reg [23:0] current_source,previous_source;
 reg [1:0] channel;
 reg [7:0] blue,green;
 reg [7:0] sector_mem[0:511];
 reg [23:0] row0[0:1023],row1[0:1023];
 reg [7:0] byte_q;
 reg [23:0] q0,q1,left0,left1,horizontal0,horizontal1;
 reg [9:0] dw,dh,pad_x,pad_y,ox,oy;
 reg [9:0] right_edge,bottom_edge,right_penult,bottom_penult;
 reg [27:0] x_acc,y_acc,x_step,y_step;
 reg [11:0] row_y0,row_y1;
 always @(posedge clk or posedge rst)begin
  if(rst)begin row0_hit<=0;row1_hit<=0;end
  else begin
   row0_hit<=row_y0[0]?(tags_valid[1] && tag1==row_y0):(tags_valid[0] && tag0==row_y0);
   row1_hit<=row_y1[0]?(tags_valid[1] && tag1==row_y1):(tags_valid[0] && tag0==row_y1);
  end
 end
 // Prepare terminal/vertical-enable decisions before SEND, rather than routing
 // output-height arithmetic and range comparisons into accumulator enables.
 reg row_last_pixel,frame_last_row,advance_source_y,source_y_endpoint;
 reg [7:0] fy;
 wire [11:0] y0=y_acc[27:16];
 wire [23:0] upper_row=y0[0]?horizontal1:horizontal0;
 wire [23:0] lower_row=y0[0]?horizontal0:horizontal1;
 wire [23:0] horizontal_result0,vertical_result;
 wire [10:0] sample_left=x_acc[26:16];
 wire [10:0] sample_right=(sample_left<last_source_x)?sample_left+1'b1:sample_left;
 wire [23:0] sample_a=(sample_left==load_x)?current_source:previous_source;
 reg [23:0] horizontal_a,horizontal_b;
 reg [7:0] horizontal_fraction;
 // Use the spare settling clock before SAMPLE_STORE to separate the tap mux
 // from the signed subtract/DSP input. Existing horizontal wait count suffices.
 always @(posedge clk or posedge rst)begin
  if(rst)begin horizontal_a<=0;horizontal_b<=0;horizontal_fraction<=0;end
  else begin horizontal_a<=sample_a;horizontal_b<=current_source;horizontal_fraction<=x_acc[15:8];end
 end
 rgb_lerp_pipeline row_mix(clk,rst,horizontal_a,horizontal_b,horizontal_fraction,horizontal_result0);
 rgb_lerp_pipeline vmix(clk,rst,upper_row,lower_row,fy,vertical_result);
 wire [11:0] y1=(y0+1<h)?y0+1'b1:y0;

 wire inside_image=ox>=pad_x && ox<=right_edge && oy>=pad_y && oy<=bottom_edge;
 // Numerators are at most (1920-1)<<16; divisors at most 1920.
 reg [27:0] quotient;reg [11:0] denominator;
 reg [12:0] remainder;
 reg [5:0] div_count;
 reg [1:0] div_phase;
 reg wide;
 wire [12:0] shifted_remainder={remainder[11:0],quotient[27]};
 wire subtract_ok=shifted_remainder>={1'b0,denominator};
 // Keep the row-address load/increment separate from the pixel FSM.
 // This prevents sparse state enables being shared into its address DSP CE.
 always @(posedge clk or posedge rst)begin
  if(rst)byte_address<=0;
  else if(state[6])byte_address<=offset+load_y*stride;
  else if(state[9])byte_address<=byte_address+1'b1;
 end
 // Synchronous RAM reads; memories deliberately have no reset.
 always @(posedge clk) begin
  if(state[8] && sector_valid && cache_count<512) sector_mem[cache_count[8:0]]<=sector_data;
  byte_q<=sector_mem[byte_address[8:0]];
  if(state[30])begin
   if(load_y[0])row1[load_sample]<=horizontal_result0;
   else row0[load_sample]<=horizontal_result0;
  end
  q0<=row0[read_x];q1<=row1[read_x];
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   right_edge<=0;bottom_edge<=0;right_penult<=0;bottom_penult<=0;
   ow<=640;oh<=480;state<=IDLE;sector_read<=0;sector_address<=0;pixel<=0;pixel_valid<=0;
   done<=0;error<=0;busy<=0;w<=0;h<=0;stride<=0;offset<=0;base<=0;
   cache_sector<=0;cache_valid<=0;cache_count<=0;
   tags_valid<=0;tag0<=0;tag1<=0;load_y<=0;load_x<=0;read_x<=0;load_sample<=0;current_source<=0;previous_source<=0;
   channel<=0;blue<=0;green<=0;dw<=0;dh<=0;pad_x<=0;pad_y<=0;
   ox<=0;oy<=0;x_acc<=0;y_acc<=0;x_step<=0;y_step<=0;
   fy<=0;left0<=0;left1<=0;horizontal0<=0;horizontal1<=0;
   quotient<=0;denominator<=1;remainder<=0;div_count<=0;div_phase<=0;wide<=0;
   row_y0<=0;row_y1<=0;last_source_x<=0;
   row_last_pixel<=0;frame_last_row<=0;advance_source_y<=0;source_y_endpoint<=0;pixel_inside<=0;sample_last<=0;sample_endpoint<=0;
  end else begin
   done<=0;error<=0;
   // Drive a next state on every clock. DIVIDE, FETCH and SEND may wait;
   // spell out those self-loops below instead of sharing a large implicit
   // hold-enable tree across all 25 state flip-flops.
   state<=IDLE;
   // Coordinates do not advance until SEND accepts this pixel. Weight
   // samples therefore settle before either lerp consumes them; no large
   // inside-image/state clock-enable tree is needed for these eight-bit data.
   fy<=y_acc[15:8];
   case(1'b1) // synthesis parallel_case
    state[0]: if(start) begin
     ow<=(ADAPTIVE && mode_800)?800:640;oh<=(ADAPTIVE && mode_800)?600:480;
     w<=source_width;h<=source_height;offset<=pixel_offset;base<=base_sector;
     last_source_x<=source_width[10:0]-1'b1;
     stride<=((source_width*13'd3+13'd3)>>2)<<2;
     cache_valid<=0;tags_valid<=0;pixel_valid<=0;sector_read<=0;
     busy<=1;state<=CONFIG_CHECK;ox<=0;oy<=0;x_acc<=0;y_acc<=0;
    end
    // Validate and latch aspect ratio before enabling the divider registers.
    // This keeps height/range comparisons out of their high-fanout CE path.
    state[23]: begin
     if(w==0 || w>1920 || h==0 || h>1080)begin error<=1;busy<=0;state<=IDLE;end
     else begin
      wide<=(w*14'd3 >= h*14'd4);
      state<=CONFIG;
     end
    end
    state[1]: begin
     quotient<=wide?((ow==800)?h*32'd800:h*32'd640):((ow==800)?w*32'd600:w*32'd480);
     denominator<=wide?w:h;
     remainder<=0;div_count<=28;div_phase<=0;state<=DIVIDE;
    end
    state[2]: begin
     state<=DIVIDE;
     remainder<=subtract_ok?shifted_remainder-{1'b0,denominator}:shifted_remainder;
     quotient<={quotient[26:0],subtract_ok};div_count<=div_count-1'b1;
     if(div_count==1)state<=DIV_DONE;
    end
    state[3]: begin
     remainder<=0;div_count<=28;
     case(div_phase)
      0: begin
       dw<=wide?ow:((quotient==0)?1:quotient[9:0]);
       dh<=wide?((quotient==0)?1:quotient[9:0]):oh;
       quotient<=(w-32'd1)<<16;
       div_phase<=1;state<=SIZE_APPLY;
      end
      1: begin
       right_edge<=pad_x+dw-1'b1;bottom_edge<=pad_y+dh-1'b1;
       right_penult<=pad_x+dw-2'd2;bottom_penult<=pad_y+dh-2'd2;
       x_step<=(dw==1)?0:quotient[27:0];quotient<=(h-32'd1)<<16;
       denominator<=(dh<=1)?1:dh-1'b1;div_phase<=2;state<=DIVIDE;
      end
      2: begin y_step<=(dh==1)?0:quotient[27:0];state<=ROW;end
      default:state<=DIV_DONE;
     endcase
    end
    state[25]:begin
     // Clamp dimensions first, then subtract them from the output size.
     // Avoid quotient zero-decode/mux/subtract on the centering path.
     pad_x<=(ow-dw)>>1;pad_y<=(oh-dh)>>1;
     denominator<=(dw<=1)?1:dw-1'b1;
     state<=DIVIDE;
    end
    state[4]: begin
     ox<=0;x_acc<=0;
     advance_source_y<=oy>=pad_y && oy<bottom_edge;
     source_y_endpoint<=oy==bottom_penult;
     // Register the row addresses before the cache decision.  The previous
     // combinational y_acc -> y1 comparator -> load_y CE path was the final
     // 100 MHz setup critical path after configuration was pipelined.
     row_y0<=y0;row_y1<=y1;
     if(oy>=pad_y && oy<=bottom_edge)state<=ROW_PROBE;
     else state<=PIXEL_PROBE;
    end
    state[24]:state<=CHECK_ROWS;
    state[5]: begin
     if(!row0_hit)begin
      load_y<=row_y0;state<=LINE_START;
     end else if(!row1_hit)begin
      load_y<=row_y1;state<=LINE_START;
     end else state<=PIXEL_PROBE;
    end
    state[6]: begin
     load_x<=0;load_sample<=0;x_acc<=0;channel<=0;state<=CACHE;
    end
    state[7]: begin
     if(cache_valid && cache_sector==byte_address[31:9])state<=BYTE;
     else begin
      cache_sector<=byte_address[31:9];cache_valid<=0;cache_count<=0;
      sector_address<=base+byte_address[31:9];sector_read<=1;state<=FETCH;
     end
    end
    state[8]: begin
     state<=FETCH;
     if(sector_valid && cache_count<513)cache_count<=cache_count+1'b1;
     if(sector_end) begin
      sector_read<=0;
      if(!(sector_valid ? (cache_count==511) : (cache_count==512)))begin error<=1;busy<=0;state<=IDLE;end
      else begin cache_valid<=1;state<=CACHE;end
     end
    end
    state[9]: begin
     state<=CACHE;
     case(channel)
      0:begin blue<=byte_q;channel<=1;end
      1:begin green<=byte_q;channel<=2;end
      2:begin
       channel<=0;
       previous_source<=current_source;current_source<={byte_q,green,blue};
       state<=SAMPLE_CHECK;
      end
     endcase
    end
    // Separate coordinate range tests from output-data/valid enables.
    // Coordinates stay stable through this probe and the following PIXEL state.
    state[31]:begin
     pixel_inside<=inside_image;
     row_last_pixel<=ox==ow-1;frame_last_row<=oy==oh-1;
     state<=PIXEL;
    end
    state[10]: begin
     if(!pixel_inside)begin pixel<=0;pixel_valid<=1;state<=SEND;end
     else begin read_x<=ox-pad_x;state<=LEFT_WAIT;end
    end
    state[11]:state<=LEFT_GET;
    state[12]:begin
     horizontal0<=q0;horizontal1<=q1;state<=VWAIT1;
    end
    state[13]:state<=RIGHT_GET;
    state[14]:state<=HWAIT1;
    state[17]:state<=HWAIT2;
    state[18]:state<=HCAPTURE;
    state[19]:begin
     state<=VWAIT1;
    end
    state[20]:state<=VWAIT2;
    state[21]:state<=VWAIT3;
    state[22]:state<=VERTICAL;
    state[15]:begin
     if(y0==y1)pixel<=y0[0]?horizontal1:horizontal0;
     else pixel<=vertical_result;
     pixel_valid<=1;state<=SEND;
    end
    state[16]:begin
     state<=SEND;
     if(pixel_ready)begin
     pixel_valid<=0;
     if(row_last_pixel)begin
      if(frame_last_row)begin busy<=0;done<=1;state<=IDLE;end
      else begin
       oy<=oy+1'b1;state<=ROW;
       if(advance_source_y)begin
        if(source_y_endpoint)y_acc<=(h-28'd1)<<16;
        else y_acc<=y_acc+y_step;
       end
      end
     end else begin
      ox<=ox+1'b1;state<=PIXEL_PROBE;

     end
    end
    end
    // Load source pixels only until both taps for the next output column exist.
    // Upscaling can emit several samples from the same source-pixel pair.
    state[26]:begin
     if(load_x>=sample_right)state<=SAMPLE_WAIT1;
     else begin load_x<=load_x+1'b1;state<=CACHE;end
    end
    state[27]:begin
     // Source-column count is stable throughout the horizontal lerp waits.
     // Register terminal tests before they fan out to x_acc and cache enables.
     sample_last<=load_sample==dw-1'b1;
     sample_endpoint<=load_sample==dw-2'd2;
     state<=SAMPLE_WAIT2;
    end
    state[28]:state<=SAMPLE_WAIT3;
    state[29]:state<=SAMPLE_STORE;
    state[30]:begin
     if(sample_last)begin
      if(load_y[0])begin tag1<=load_y;tags_valid[1]<=1;end
      else begin tag0<=load_y;tags_valid[0]<=1;end
      state<=ROW_PROBE;
     end else begin
      load_sample<=load_sample+1'b1;
      if(sample_endpoint)x_acc<=(w-28'd1)<<16;
      else x_acc<=x_acc+x_step;
      state<=SAMPLE_CHECK;
     end
    end
    default:begin state<=IDLE;busy<=0;pixel_valid<=0;sector_read<=0;error<=1;end
   endcase
  end
 end
endmodule

// Difference, multiply and rounded accumulation are separate 100MHz stages.
module rgb_lerp_pipeline(input clk,input rst,input [23:0] a,input [23:0] b,
 input [7:0] fraction,output [23:0] result);
 genvar c;
 generate for(c=0;c<3;c=c+1)begin: channel
  reg signed [8:0] delta;
  reg signed [17:0] product;
  reg [7:0] base1,base2,f1,pixel;
  wire signed [17:0] total=$signed({2'b00,base2,8'b0})+product+18'sd128;
  assign result[c*8+:8]=pixel;
  always @(posedge clk or posedge rst)begin
   if(rst)begin delta<=0;product<=0;base1<=0;base2<=0;f1<=0;pixel<=0;end
   else begin
    delta<=$signed({1'b0,b[c*8+:8]})-$signed({1'b0,a[c*8+:8]});
    base1<=a[c*8+:8];f1<=fraction;
    product<=delta*$signed({1'b0,f1});base2<=base1;
    pixel<=total[15:8];
   end
  end
 end endgenerate
endmodule
