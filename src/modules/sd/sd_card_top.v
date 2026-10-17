
module sd_card_top
#(
	parameter NATIVE_4BIT=0,parameter NATIVE_HIGH_SPEED=0,
	parameter  SPI_LOW_SPEED_DIV = 248,         // SD card low speed mode frequency division parameter,spi clk speed = clk speed /((SPI_LOW_SPEED_DIV + 2) * 2 )
	parameter  SPI_HIGH_SPEED_DIV = 0,
	parameter  INIT_TIMEOUT_CYCLES = 800_000_000,
	parameter  INIT_PAUSE_CYCLES = 100_000_000,
	parameter  WAIT_TIMEOUT_CYCLES = 67_108_864
)
(
	input            clk,
	input            rst,
	output           SD_nCS,                    //SD card chip select (SPI mode)
	output           SD_DCLK,                   //SD card clock
	output           SD_MOSI,                   //SD card controller data output
	input            SD_MISO,                   //SD card controller data input
	output           sd_init_done,              //SD card initialization is complete
	output           sd_init_error,             //SD card initialization failed (watchdog tripped)
	output           sd_transfer_error,
	input            sd_sec_read,               //SD card sector read
	input[31:0]      sd_sec_read_addr,          //SD card sector read address
	output[7:0]      sd_sec_read_data,          //SD card sector read data
	output           sd_sec_read_data_valid,    //SD card sector read data valid
	output           sd_sec_read_end,           //SD card sector read end
	input            sd_sec_write,              //SD card sector write
	input[31:0]      sd_sec_write_addr,         //SD card sector write address
	input[7:0]       sd_sec_write_data,         //SD card sector write data
	output           sd_sec_write_data_req,     //SD card sector write data next clock is valid
	output           sd_sec_write_end,          //SD card sector write end
    output SD_CLK,inout SD_CMD,SD_DAT0,SD_DAT1,SD_DAT2,SD_DAT3
);
generate if(NATIVE_4BIT)begin:native_bus
 assign SD_nCS=1'b1;assign SD_DCLK=1'b0;assign SD_MOSI=1'b1;
 sd_card_top_native #(.ENABLE_HIGH_SPEED(NATIVE_HIGH_SPEED),.SPI_LOW_SPEED_DIV(SPI_LOW_SPEED_DIV),
  .INIT_TIMEOUT_CYCLES(INIT_TIMEOUT_CYCLES),.INIT_PAUSE_CYCLES(INIT_PAUSE_CYCLES),
  .WAIT_TIMEOUT_CYCLES(WAIT_TIMEOUT_CYCLES)) transport(
  .clk(clk),
  .rst(rst),
  .sd_init_done(sd_init_done),
  .sd_init_error(sd_init_error),
  .sd_transfer_error(sd_transfer_error),
  .sd_sec_read(sd_sec_read),
  .sd_sec_read_addr(sd_sec_read_addr),
  .sd_sec_read_data(sd_sec_read_data),
  .sd_sec_read_data_valid(sd_sec_read_data_valid),
  .sd_sec_read_end(sd_sec_read_end),
  .sd_sec_write(sd_sec_write),
  .sd_sec_write_addr(sd_sec_write_addr),
  .sd_sec_write_data(sd_sec_write_data),
  .sd_sec_write_data_req(sd_sec_write_data_req),
  .sd_sec_write_end(sd_sec_write_end),
  .SD_CLK(SD_CLK),
  .SD_CMD(SD_CMD),
  .SD_DAT0(SD_DAT0),
  .SD_DAT1(SD_DAT1),
  .SD_DAT2(SD_DAT2),
  .SD_DAT3(SD_DAT3));
end else begin:legacy_spi
 assign SD_CLK=1'b0;
 assign SD_CMD=1'bz;assign SD_DAT0=1'bz;assign SD_DAT1=1'bz;assign SD_DAT2=1'bz;assign SD_DAT3=1'bz;
wire response_valid;
wire [7:0] response_data;
wire[15:0]           spi_clk_div;               //SPI module clock division parameter
wire                 cmd_req;                   //SD card command request
wire                 cmd_req_ack;               //SD card command request response
wire                 cmd_req_error;             //SD card command request error
wire[47:0]           cmd;                       //SD card command
wire[7:0]            cmd_r1;                    //SD card expect response
wire[15:0]           cmd_data_len;              //SD card command read data length
wire                 block_read_req;            //SD card sector data read request
wire                 block_read_valid;          //SD card sector data read data valid
wire[7:0]            block_read_data;           //SD card sector data read data
wire                 block_read_req_ack;        //SD card sector data read response
wire                 block_write_req;           //SD card sector data write request
wire[7:0]            block_write_data;          //SD card sector data write data next clock is valid
wire                 block_write_data_rd;       //SD card sector data write data
wire                 block_write_req_ack;       //SD card sector data write response

wire                 nCS_ctrl;                  //SPI module chip select control
wire                 spi_wr_req;                //SPI module data sending request
wire                 spi_wr_ack;                //SPI module data request response
wire[7:0]            spi_data_in;               //SPI module send data
wire[7:0]            spi_data_out;              //SPI module data returned
wire[15:0]           clk_div;
sd_card_sec_read_write
#(
	.SPI_LOW_SPEED_DIV(SPI_LOW_SPEED_DIV),
	.SPI_HIGH_SPEED_DIV(SPI_HIGH_SPEED_DIV),
	.INIT_TIMEOUT_CYCLES(INIT_TIMEOUT_CYCLES),
	.INIT_PAUSE_CYCLES(INIT_PAUSE_CYCLES)
)
sd_card_sec_read_write_m0(
	.clk                            (clk                    ),
	.rst                            (rst                    ),
	.sd_init_done                   (sd_init_done           ),
	.init_error                     (sd_init_error          ),
	.transfer_error                 (sd_transfer_error      ),
	.sd_sec_read                    (sd_sec_read            ),
	.sd_sec_read_addr               (sd_sec_read_addr       ),
	.sd_sec_read_data               (sd_sec_read_data       ),
	.sd_sec_read_data_valid         (sd_sec_read_data_valid ),
	.sd_sec_read_end                (sd_sec_read_end        ),
	.sd_sec_write                   (sd_sec_write           ),
	.sd_sec_write_addr              (sd_sec_write_addr      ),
	.sd_sec_write_data              (sd_sec_write_data      ),
	.sd_sec_write_data_req          (sd_sec_write_data_req  ),
	.sd_sec_write_end               (sd_sec_write_end       ),
	.spi_clk_div                    (spi_clk_div            ),
	.cmd_req                        (cmd_req                ),
	.cmd_req_ack                    (cmd_req_ack            ),
	.cmd_req_error                  (cmd_req_error          ),
	.cmd                            (cmd                    ),
	.cmd_r1                         (cmd_r1                 ),
	.cmd_data_len                   (cmd_data_len           ),
    .response_valid(response_valid),.response_data(response_data),
	.block_read_req                 (block_read_req         ),
	.block_read_valid               (block_read_valid       ),
	.block_read_data                (block_read_data        ),
	.block_read_req_ack             (block_read_req_ack     ),
	.block_write_req                (block_write_req        ),
	.block_write_data               (block_write_data       ),
	.block_write_data_rd            (block_write_data_rd    ),
	.block_write_req_ack            (block_write_req_ack    )
);

sd_card_cmd #(.WAIT_TIMEOUT_CYCLES(WAIT_TIMEOUT_CYCLES)) sd_card_cmd_m0(
	.sys_clk                        (clk                    ),
	.rst                            (rst | sd_init_error    ),
	.spi_clk_div                    (spi_clk_div            ),
	.cmd_req                        (cmd_req                ),
	.cmd_req_ack                    (cmd_req_ack            ),
	.cmd_req_error                  (cmd_req_error          ),
	.cmd                            (cmd                    ),
	.cmd_r1                         (cmd_r1                 ),
	.cmd_data_len                   (cmd_data_len           ),
    .response_valid(response_valid),.response_data(response_data),
	.block_read_req                 (block_read_req         ),
	.block_read_req_ack             (block_read_req_ack     ),
	.block_read_data                (block_read_data        ),
	.block_read_valid               (block_read_valid       ),
	.block_write_req                (block_write_req        ),
	.block_write_data               (block_write_data       ),
	.block_write_data_rd            (block_write_data_rd    ),
	.block_write_req_ack            (block_write_req_ack    ),
	.nCS_ctrl                       (nCS_ctrl               ),
	.clk_div                        (clk_div                ),
	.spi_wr_req                     (spi_wr_req             ),
	.spi_wr_ack                     (spi_wr_ack             ),
	.spi_data_in                    (spi_data_in            ),
	.spi_data_out                   (spi_data_out           )

);

spi_master spi_master_m0(
	.sys_clk                        (clk                    ),
	.rst                            (rst | sd_init_error    ),
	.nCS                            (SD_nCS                 ),
	.DCLK                           (SD_DCLK                ),
	.MOSI                           (SD_MOSI                ),
	.MISO                           (SD_MISO                ),
	.clk_div                        (clk_div                ),
	.CPOL                           (1'b1                   ),
	.CPHA                           (1'b1                   ),
	.nCS_ctrl                       (nCS_ctrl               ),
	.wr_req                         (spi_wr_req             ),
	.wr_ack                         (spi_wr_ack             ),
	.data_in                        (spi_data_in            ),
	.data_out                       (spi_data_out           )
);
end endgenerate
endmodule
