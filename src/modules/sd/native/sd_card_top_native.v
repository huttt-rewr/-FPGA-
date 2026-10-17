// Native read-only sector wrapper, used by the formal six-wire profile.
// CMD6 optionally negotiates SDR50; unsupported/error fallback remains native25.
// Logical tests and internal STA do not establish physical card I/O signoff.
module sd_card_top_native #(
 parameter ENABLE_HIGH_SPEED=0,
 parameter SPI_LOW_SPEED_DIV=248,
 parameter SPI_HIGH_SPEED_DIV=0,
 parameter INIT_TIMEOUT_CYCLES=800000000,
 parameter INIT_PAUSE_CYCLES=100000000,
 parameter WAIT_TIMEOUT_CYCLES=67108864,
 parameter INIT_ATTEMPT_LIMIT=4096
)(
 input clk,rst,
 output SD_CLK,inout SD_CMD,SD_DAT0,SD_DAT1,SD_DAT2,SD_DAT3,
 output sd_init_done,sd_init_error,sd_transfer_error,
 input sd_sec_read,input [31:0] sd_sec_read_addr,
 output [7:0] sd_sec_read_data,output sd_sec_read_data_valid,sd_sec_read_end,
 input sd_sec_write,input [31:0] sd_sec_write_addr,input [7:0] sd_sec_write_data,
 output sd_sec_write_data_req,sd_sec_write_end
);
 wire high_speed_50;wire [9:0] read_length;
 wire high_speed,open_drain,phy_reset,rise_tick,fall_tick;
 wire cmd_start,cmd_ready,cmd_done,cmd_error;
 wire [5:0] cmd_index;
 wire [31:0] cmd_argument;
 wire [2:0] response_type;
 wire [135:0] response;
 wire read_arm,read_cancel,read_valid,read_done,read_error;
 wire [7:0] read_data;
 // Legacy parameter names retained: identification divider remains configurable.
 // 100MHz host produces native25, or native50 only after CMD6 confirmation.
 // SPI_HIGH_SPEED_DIV does not control the native bus.
 sd_bus_phy #(.LOW_HALF_CYCLES(SPI_LOW_SPEED_DIV+2),
  .WAIT_TIMEOUT_CYCLES(WAIT_TIMEOUT_CYCLES)) phy(
  .clk(clk),.rst(rst|phy_reset),.high_speed(high_speed),.open_drain(open_drain),.high_speed_50(high_speed_50),.read_length(read_length),.SD_CLK(SD_CLK),
  .SD_CMD(SD_CMD),.SD_DAT({SD_DAT3,SD_DAT2,SD_DAT1,SD_DAT0}),
  .rise_tick(rise_tick),.fall_tick(fall_tick),
  .cmd_start(cmd_start),.cmd_index(cmd_index),.cmd_argument(cmd_argument),
  .response_type(response_type),.cmd_ready(cmd_ready),.cmd_done(cmd_done),
  .cmd_error(cmd_error),.response(response),.read_arm(read_arm),.read_cancel(read_cancel),
  .read_data(read_data),.read_valid(read_valid),.read_done(read_done),.read_error(read_error));
 sd_native_controller #(.ENABLE_HIGH_SPEED(ENABLE_HIGH_SPEED),.INIT_TIMEOUT_CYCLES(INIT_TIMEOUT_CYCLES),
  .INIT_PAUSE_CYCLES(INIT_PAUSE_CYCLES),.INIT_ATTEMPT_LIMIT(INIT_ATTEMPT_LIMIT)) controller(
  .clk(clk),.rst(rst),.rise_tick(rise_tick),.high_speed(high_speed),.open_drain(open_drain),.high_speed_50(high_speed_50),.read_length(read_length),.phy_reset(phy_reset),
  .sd_init_done(sd_init_done),.sd_init_error(sd_init_error),.sd_transfer_error(sd_transfer_error),
  .sd_sec_read(sd_sec_read),.sd_sec_read_addr(sd_sec_read_addr),
  .sd_sec_read_data(sd_sec_read_data),.sd_sec_read_data_valid(sd_sec_read_data_valid),
  .sd_sec_read_end(sd_sec_read_end),.sd_sec_write(sd_sec_write),
  .sd_sec_write_addr(sd_sec_write_addr),.sd_sec_write_data(sd_sec_write_data),
  .sd_sec_write_data_req(sd_sec_write_data_req),.sd_sec_write_end(sd_sec_write_end),
  .cmd_start(cmd_start),.cmd_index(cmd_index),.cmd_argument(cmd_argument),
  .response_type(response_type),.cmd_ready(cmd_ready),.cmd_done(cmd_done),
  .cmd_error(cmd_error),.response(response),.read_arm(read_arm),.read_cancel(read_cancel),
  .read_data(read_data),.read_valid(read_valid),.read_done(read_done),.read_error(read_error));
endmodule
