// Latch the boot choice before the supervisor releases the media pipeline.
// A held KEY1 selects the alternative; later presses remain player controls.
module boot_media_select #(parameter SETTLE_CYCLES=1024,parameter DEFAULT_MOVIE=0,
 parameter RUNTIME_SELECT=0)(
 input clk,rst_n,key1_n,output reg movie_mode,
 input select_valid,select_movie,output reg restart_request);
 (* async_reg="true" *) reg [1:0] key_ff;
 (* async_reg="true" *) reg [1:0] select_valid_ff,select_movie_ff;
 reg [15:0] count;
 reg selected;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   key_ff<=2'b11;count<=0;selected<=0;movie_mode<=DEFAULT_MOVIE;
   select_valid_ff<=0;select_movie_ff<=2'b11;restart_request<=0;
  end else begin
   key_ff<={key_ff[0],key1_n};select_valid_ff<={select_valid_ff[0],select_valid};
   select_movie_ff<={select_movie_ff[0],select_movie};restart_request<=0;
   if(!selected)begin
    if(count==SETTLE_CYCLES-1)begin movie_mode<=key_ff[1]?DEFAULT_MOVIE:!DEFAULT_MOVIE;selected<=1;end
    else count<=count+1'b1;
   end else if(RUNTIME_SELECT && select_valid_ff[1] && movie_mode!=select_movie_ff[1])begin
    movie_mode<=select_movie_ff[1];restart_request<=1;
   end
  end
 end
endmodule

// Persistent level request. A media restart resets the receiver but cannot
// undo the choice. Repeated make codes select the same mode.
module media_keyboard_request(
 input clk,rst_n,controls_reset,
 input [7:0] scan_code,input key_valid,key_release,key_extended,receive_error,
 output reg select_valid,select_movie);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin select_valid<=0;select_movie<=1;end
  else if(!controls_reset && key_valid && !key_release && !key_extended && !receive_error)begin
   case(scan_code)
    8'h4d:begin select_valid<=1;select_movie<=0;end
    8'h2a:begin select_valid<=1;select_movie<=1;end
   endcase
  end
 end
endmodule

// Holding KEY1+KEY2 selects the opposite media mode. Debounced stable states
// prevent a brief or bouncing chord from switching the filesystem.
module media_button_request #(parameter DEBOUNCE_CYCLES=500000,parameter HOLD_CYCLES=25000000)(
 input clk,rst_n,key1_n,key2_n,movie_mode,
 output reg select_valid,select_movie);
 (* async_reg="true" *) reg [1:0] key1_ff,key2_ff,mode_ff;
 reg [1:0] stable_keys;
 localparam DW=(DEBOUNCE_CYCLES<2)?1:$clog2(DEBOUNCE_CYCLES);
 localparam HW=(HOLD_CYCLES<2)?1:$clog2(HOLD_CYCLES);
 reg [DW-1:0] debounce_count;
 reg [HW-1:0] hold_count;
 reg chord_fired;
 wire [1:0] sampled_keys={key2_ff[1],key1_ff[1]};
 wire chord_down=(stable_keys==2'b00);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   key1_ff<=2'b11;key2_ff<=2'b11;mode_ff<=0;stable_keys<=2'b11;
   debounce_count<=0;hold_count<=0;chord_fired<=0;select_valid<=0;select_movie<=1;
  end else begin
   key1_ff<={key1_ff[0],key1_n};key2_ff<={key2_ff[0],key2_n};mode_ff<={mode_ff[0],movie_mode};
   if(sampled_keys==stable_keys)debounce_count<=0;
   else if(DEBOUNCE_CYCLES<=1 || debounce_count==DEBOUNCE_CYCLES-1)begin
    stable_keys<=sampled_keys;debounce_count<=0;
    if(sampled_keys!=2'b00)begin hold_count<=0;chord_fired<=0;end
   end else debounce_count<=debounce_count+1'b1;
   if(!chord_down)hold_count<=0;
   else if(!chord_fired)begin
    if(HOLD_CYCLES<=1 || hold_count==HOLD_CYCLES-1)begin
     select_valid<=1;select_movie<=!mode_ff[1];chord_fired<=1;hold_count<=0;
    end else hold_count<=hold_count+1'b1;
   end
  end
 end
endmodule
