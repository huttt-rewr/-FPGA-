
module sd_card_sec_read_write
#(
	parameter  SPI_LOW_SPEED_DIV = 248,         // spi clk speed = clk speed /((SPI_LOW_SPEED_DIV + 2) * 2 )
	parameter  SPI_HIGH_SPEED_DIV = 0,           // spi clk speed = clk speed /((SPI_HIGH_SPEED_DIV + 2) * 2 )
	parameter  INIT_TIMEOUT_CYCLES = 800_000_000, // 8 s at 100 MHz
	parameter  INIT_PAUSE_CYCLES = 100_000_000    // 1 s quiet pause before retry
)
(
	input            clk,
	input            rst,
	output reg       sd_init_done,
	output reg       init_error,
	output reg       transfer_error,
	input            sd_sec_read,
	input[31:0]      sd_sec_read_addr,
	output[7:0]      sd_sec_read_data,
	output           sd_sec_read_data_valid,
	output           sd_sec_read_end,
	input            sd_sec_write,
	input[31:0]      sd_sec_write_addr,
	input[7:0]       sd_sec_write_data,
	output           sd_sec_write_data_req,
	output           sd_sec_write_end,

	output reg[15:0] spi_clk_div,
	output reg       cmd_req,
	input            cmd_req_ack,
	input            cmd_req_error,
    input response_valid,
    input [7:0] response_data,
	output reg[47:0] cmd,
	output reg[7:0]  cmd_r1,
	output reg[15:0] cmd_data_len,
	output reg       block_read_req,
	input            block_read_valid,
	input[7:0]       block_read_data,
	input            block_read_req_ack,
	output reg       block_write_req,
	output[7:0]      block_write_data,
	input            block_write_data_rd,
	input            block_write_req_ack
);
reg [31:0] init_timer;
reg [31:0] pause_cnt;

localparam S_IDLE               = 0;
localparam S_CMD0               = 1;
localparam S_CMD8               = 2;
localparam S_CMD55              = 3;
localparam S_CMD41              = 4;
localparam S_CMD17              = 5;
localparam S_READ               = 6;
localparam S_CMD24              = 7;
localparam S_WRITE              = 8;
localparam S_ERR                = 14;
localparam S_WRITE_END          = 15;
localparam S_READ_END           = 16;
localparam S_WAIT_READ_WRITE    = 17;
localparam S_CMD16              = 18;
localparam S_CMD58              = 19;
localparam S_CHECK_OCR          = 20;
localparam S_CHECK_R7           = 21;
localparam S_INIT_PAUSE         = 22;
reg [31:0] response_shift;
reg [2:0] response_count;
reg block_addressed;
reg[31:0] sec_addr;
wire [31:0] command_address = block_addressed ? sec_addr : (sec_addr << 9);
always @(posedge clk or posedge rst) begin
    if (rst) begin response_shift <= 0; response_count <= 0; end
    else if (!cmd_req) begin response_shift <= 0; response_count <= 0; end
    else if (response_valid) begin
        response_shift <= {response_shift[23:0],response_data};
        if (response_count != 7) response_count <= response_count + 1'b1;
    end
end

reg[4:0]                       state;
assign sd_sec_read_data_valid = (state == S_READ) && block_read_valid;
assign sd_sec_read_data = block_read_data;
assign sd_sec_read_end = (state == S_READ_END);
assign sd_sec_write_data_req = (state == S_WRITE) && block_write_data_rd;
assign block_write_data = sd_sec_write_data;
assign sd_sec_write_end = (state == S_WRITE_END);

always@(posedge clk or posedge rst)
begin
	if(rst == 1'b1)
	begin
		state <= S_IDLE;
        block_addressed <= 0;
		cmd_req <= 1'b0;
		cmd_data_len <= 16'd0;
		cmd_r1 <= 8'd0;
		cmd <= 48'd0;
		spi_clk_div <= SPI_LOW_SPEED_DIV[15:0];
		block_write_req <= 1'b0;
		block_read_req <= 1'b0;
		sec_addr <= 32'd0;
		sd_init_done <= 1'b0;
		init_error <= 1'b0;
		transfer_error <= 1'b0;
		pause_cnt <= 0;
	end
	else if (!sd_init_done && state != S_INIT_PAUSE && init_timer >= INIT_TIMEOUT_CYCLES - 1)
	begin
		// The wrapper holds command/SPI engines in reset during this pause.
		state <= S_INIT_PAUSE;
		init_error <= 1'b1;
		pause_cnt <= 0;
		cmd_req <= 1'b0;
		block_read_req <= 1'b0;
		block_write_req <= 1'b0;
	end
	else begin
		transfer_error <= 1'b0;
		case(state)
			S_INIT_PAUSE: begin
				if (pause_cnt >= INIT_PAUSE_CYCLES - 1) begin
					pause_cnt <= 0;
					init_error <= 0;
					state <= S_IDLE;
				end else pause_cnt <= pause_cnt + 1'b1;
			end
			S_IDLE:
			begin
				state <= S_CMD0;
				sd_init_done <= 1'b0;
				spi_clk_div <= SPI_LOW_SPEED_DIV[15:0];
			end
			S_CMD0:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD8;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h01;
					cmd <= {8'd0,8'h00,8'h00,8'h00,8'h00,8'h95};
				end
			end
			S_CMD8:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					// The fourth R7 byte can arrive together with ack.
					state <= S_CHECK_R7;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd4;
					cmd_r1 <= 8'h01;
					cmd <= {8'd8,8'h00,8'h00,8'h01,8'haa,8'h87};
				end
			end
            S_CHECK_R7: begin
                // SD v2 only: accepted voltage 2.7-3.6 V and echoed 0xAA.
                // Do not accept stale/truncated response data from another command.
                if (response_count == 4 && response_shift[11:0] == 12'h1aa)
                    state <= S_CMD55;
                else
                    state <= S_IDLE;
            end
			S_CMD55:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD41;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h01;
					cmd <= {8'd55,8'h00,8'h00,8'h00,8'h00,8'hff};
				end
			end
			S_CMD41:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_CMD58;
					cmd_req <= 1'b0;
				end
				else if(cmd_req_ack)
				begin
					state <= S_CMD55;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd41,8'h40,8'h00,8'h00,8'h00,8'hff};
				end
			end
            S_CMD58: begin
                if (cmd_req_ack && !cmd_req_error) begin
                    cmd_req <= 0;
                    // Last response_valid can coincide with cmd_req_ack.
                    // Decode one cycle later, after the fourth OCR byte lands.
                    state <= S_CHECK_OCR;
                end else begin
                    cmd_req <= 1;
                    cmd_data_len <= 16'd4;
                    cmd_r1 <= 8'h00;
                    cmd <= {8'd58,32'd0,8'hff};
                end
            end
            S_CHECK_OCR: begin
                block_addressed <= response_shift[30]; // CCS: 1 = sector address
                if (response_shift[31] && response_shift[30]) begin
                    state <= S_WAIT_READ_WRITE;
                    sd_init_done <= 1;
                    spi_clk_div <= SPI_HIGH_SPEED_DIV[15:0];
                end else if (response_shift[31]) state <= S_CMD16;
                else state <= S_CMD55;
            end
			S_CMD16:
			begin
				if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_WAIT_READ_WRITE;
					cmd_req <= 1'b0;
					sd_init_done <= 1'b1;
					spi_clk_div <= SPI_HIGH_SPEED_DIV[15:0];
				end
				else if(cmd_req_ack)
				begin
					state <= S_CMD55;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd16,32'd512,8'hff};
				end
			end			
			S_WAIT_READ_WRITE:
			begin
				if(sd_sec_write ==  1'b1)
				begin
					state <= S_CMD24;
					sec_addr <= sd_sec_write_addr;
				end
				else if(sd_sec_read == 1'b1)
				begin
					state <= S_CMD17;
					sec_addr <= sd_sec_read_addr;
				end

				spi_clk_div <= SPI_HIGH_SPEED_DIV[15:0];
			end
			S_CMD24:
			begin
				if(cmd_req_ack && cmd_req_error) begin
					transfer_error <= 1'b1;
					cmd_req <= 0;
					state <= S_WAIT_READ_WRITE;
				end
				else if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_WRITE;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd24,command_address,8'hff};

				end
			end
			S_WRITE:
			begin
				if(cmd_req_ack && cmd_req_error) begin
					transfer_error <= 1'b1;
					block_write_req <= 0;
					state <= S_WAIT_READ_WRITE;
				end
				else if(block_write_req_ack == 1'b1)
				begin
					block_write_req <= 1'b0;
					state <= S_WRITE_END;
				end
				else
					block_write_req <= 1'b1;
			end
			S_CMD17:
			begin
				if(cmd_req_ack && cmd_req_error) begin
					transfer_error <= 1'b1;
					cmd_req <= 0;
					state <= S_WAIT_READ_WRITE;
				end
				else if(cmd_req_ack & ~cmd_req_error)
				begin
					state <= S_READ;
					cmd_req <= 1'b0;
				end
				else
				begin
					cmd_req <= 1'b1;
					cmd_data_len <= 16'd0;
					cmd_r1 <= 8'h00;
					cmd <= {8'd17,command_address,8'hff};
				end
			end
			S_READ:
			begin
				if(cmd_req_ack && cmd_req_error) begin
					transfer_error <= 1'b1;
					block_read_req <= 0;
					state <= S_WAIT_READ_WRITE;
				end
				else if(block_read_req_ack)
				begin
					state <= S_READ_END;
					block_read_req <= 1'b0;
				end
				else
				begin
					block_read_req <= 1'b1;
				end
			end
			S_WRITE_END:
			begin
				state <= S_WAIT_READ_WRITE;
			end
			S_READ_END:
			begin
				state <= S_WAIT_READ_WRITE;
			end
			default:
				state <= S_IDLE;
		endcase
	end
end

// A whole initialization attempt is bounded even if no command ack arrives.
always @(posedge clk or posedge rst) begin
	if (rst) init_timer <= 0;
	else if (sd_init_done || state == S_INIT_PAUSE) init_timer <= 0;
	else if (init_timer < INIT_TIMEOUT_CYCLES) init_timer <= init_timer + 1'b1;
end

endmodule
