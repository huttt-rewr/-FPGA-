// Slow status snapshots for the existing six-digit display. NOT an ILA trace.
// Page 0: frame and line progress; page 1: memory-side FIFO occupancy;
// page 2: pixel-side occupancy and sticky errors; page 3: reset/SD state.
module board_debug #(parameter UPDATE_CYCLES=10000000)(
 input clk,input rst,input video_clk,input video_rst,input mem_clk,input mem_rst,
 input vs,input hs,input de,input [7:0] video_flags,
 input [19:0] memory_status,input [10:0] read_status,
 input [7:0] reset_count,input [3:0] sd_status,input [3:0] player_state,
 input [1:0] page,output reg [23:0] display_word);
 reg vs_d,hs_d;
 reg [7:0] frames,lines;
 always @(posedge video_clk or posedge video_rst)begin
  if(video_rst)begin vs_d<=1;hs_d<=1;frames<=0;lines<=0;end
  else begin
   vs_d<=vs;hs_d<=hs;
   if(vs_d && !vs)begin frames<=frames+1'b1;lines<=0;end
   else if(hs_d && !hs)lines<=lines+1'b1;
  end
 end
 wire [34:0] video_snapshot;
 wire [19:0] memory_snapshot;
 cdc_snapshot #(.WIDTH(35)) video_cdc(.src_clk(video_clk),.src_rst(video_rst),
  .src_data({frames,lines,video_flags,read_status}),
  .dst_clk(clk),.dst_rst(rst),.dst_data(video_snapshot));
 cdc_snapshot #(.WIDTH(20)) memory_cdc(.src_clk(mem_clk),.src_rst(mem_rst),
  .src_data(memory_status),.dst_clk(clk),.dst_rst(rst),.dst_data(memory_snapshot));
 localparam UW=(UPDATE_CYCLES<2)?1:$clog2(UPDATE_CYCLES);
 reg [UW-1:0] update_count;
 reg [1:0] previous_page;
 always @(posedge clk or posedge rst)begin
  if(rst)begin display_word<=0;update_count<=0;previous_page<=0;end
  else begin
   previous_page<=page;
   if(update_count==UPDATE_CYCLES-1 || page!=previous_page)begin
    update_count<=0;
    case(page)
     0:display_word<={4'h0,video_snapshot[34:19],video_snapshot[14:11]};
     1:display_word<={4'h1,memory_snapshot};
     2:display_word<={4'h2,1'b0,video_snapshot[18:11],video_snapshot[10:0]};
     3:display_word<={4'h3,reset_count,sd_status,player_state,4'b0};
    endcase
   end else update_count<=update_count+1'b1;
  end
 end
endmodule
