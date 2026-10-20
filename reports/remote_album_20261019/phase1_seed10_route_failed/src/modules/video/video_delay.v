module video_delay
#(
	parameter DATA_WIDTH = 24,
    parameter SYNC_STAGES = 21,                              // Raster pipeline delay, NOT SDRAM latency.
                                                             // SDRAM prefetch occurs independently in vblank.
    parameter FIFO_CAPTURE_LATENCY = 2                       // Video data one clock data width
)
(
	input                       video_clk,          // Video pixel clock
	input                       rst,
	output                      read_en,            // Read data enable
	input[DATA_WIDTH - 1:0]     read_data,          // Read data
	input                      hs,                 // horizontal synchronization
	input                      vs,                 // vertical synchronization
	input                      de,                 // video valid

	output                      hs_r,                 // horizontal synchronization
	output                      vs_r,                 // vertical synchronization
	output                      de_r,                 // video valid
	output[DATA_WIDTH - 1:0]    vout_data           // video data

);
reg [SYNC_STAGES-1:0] hs_d;
reg [SYNC_STAGES-1:0] vs_d;
reg [SYNC_STAGES-1:0] de_d;
reg[DATA_WIDTH - 1:0]  vout_data_r;

assign read_en = de_d[SYNC_STAGES-1-FIFO_CAPTURE_LATENCY];
assign hs_r = hs_d[SYNC_STAGES-1];
assign vs_r = vs_d[SYNC_STAGES-1];
assign de_r = de_d[SYNC_STAGES-1];
assign vout_data = vout_data_r;
always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
		vout_data_r <= {DATA_WIDTH{1'b0}};
	else if(de_d[SYNC_STAGES-2])
		vout_data_r <= read_data;
	else
		vout_data_r <= {DATA_WIDTH{1'b0}};
end
always @(posedge video_clk or posedge rst)begin
	if(rst)begin
    	hs_d <= {SYNC_STAGES{1'b0}};
        vs_d <= {SYNC_STAGES{1'b0}};
        de_d <= {SYNC_STAGES{1'b0}};
    end
	else begin
    	
    	hs_d <= {hs_d[SYNC_STAGES-2:0],hs};
        vs_d <= {vs_d[SYNC_STAGES-2:0],vs};
        de_d <= {de_d[SYNC_STAGES-2:0],de};
    end
end
endmodule
