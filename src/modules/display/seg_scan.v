module seg_scan(
	input           clk,
	input           rst_n,
	output reg[5:0] seg_sel,
	output reg[7:0] seg_data,
	input[7:0]      seg_data_0,
	input[7:0]      seg_data_1,
	input[7:0]      seg_data_2,
	input[7:0]      seg_data_3,
	input[7:0]      seg_data_4,
	input[7:0]      seg_data_5
);
parameter SCAN_FREQ = 200;
parameter CLK_FREQ = 50000000;

parameter SCAN_COUNT = CLK_FREQ /(SCAN_FREQ * 6) - 1;

localparam TIMER_WIDTH=(SCAN_COUNT<1)?1:$clog2(SCAN_COUNT+1);
reg[TIMER_WIDTH-1:0] scan_timer;
reg[5:0] scan_sel;
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
	begin
		scan_timer <= 0;
		scan_sel <= 6'b000001;
	end
	else if(scan_timer >= SCAN_COUNT)
	begin
		scan_timer <= 0;
		scan_sel <= {scan_sel[4:0],scan_sel[5]};
	end
	else
		begin
			scan_timer <= scan_timer + 1'b1;
		end
end
always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
	begin
		seg_sel <= 6'b111111;
		seg_data <= 8'hff;
	end
	else
	begin
        // One-hot masks form a parallel mux instead of a decoded priority chain.
        seg_sel <= ~scan_sel;
        seg_data <= (seg_data_0 & {8{scan_sel[0]}}) |
                    (seg_data_1 & {8{scan_sel[1]}}) |
                    (seg_data_2 & {8{scan_sel[2]}}) |
                    (seg_data_3 & {8{scan_sel[3]}}) |
                    (seg_data_4 & {8{scan_sel[4]}}) |
                    (seg_data_5 & {8{scan_sel[5]}});
	end
end

endmodule
