// Passive until a command arrives. Uses existing UART pins, no duplicate board state.
module remote_controls #(parameter CLK_HZ=100000000,parameter BAUD=115200,
                         parameter TIMEOUT_CYCLES=50000000)(
 input clk,input rst,input rx,output tx,output overflow,
 output next_pulse,output prev_pulse,output toggle_pulse,
 output [23:0] time_bcd,output [7:0] time_seq,output time_set);
 wire [7:0] data;
 wire valid,time_busy,time_reply,time_ok;
 wire pc_reply_valid;wire [7:0] pc_reply;
 wire command_valid=valid && !time_busy && data!="T";
 wire [7:0] command=(data=="n" || data=="p" || data=="b")?data:8'd0;
 uart_rx #(.CLK_FREQ(CLK_HZ),.BAUD(BAUD)) receiver(clk,rst,rx,data,valid);
 time_cmd #(.TIMEOUT_CYCLES(TIMEOUT_CYCLES)) clock_command(
  .clk(clk),.rst(rst),.uart_data(data),.uart_valid(valid),.time_bcd(time_bcd),
  .time_seq(time_seq),.time_set(time_set),.busy(time_busy),.reply_valid(time_reply),.reply_ok(time_ok));
 player_control #(.PC_COMMANDS(1)) commands(.clk(clk),.rst(rst),.uart_data(command),.uart_valid(command_valid),
  .ir_command(8'd0),.ir_valid(1'b0),.next_pulse(next_pulse),.prev_pulse(prev_pulse),.toggle_pulse(toggle_pulse),
  .reply_valid(pc_reply_valid),.reply(pc_reply));
 uart_tx_queue #(.CLK_FREQ(CLK_HZ),.BAUD(BAUD)) replies(.clk(clk),.rst(rst),
  .i_data(time_reply?(time_ok?8'h4b:8'h3f):pc_reply),.i_send(time_reply || pc_reply_valid),
  .o_tx(tx),.o_busy(),.overflow(overflow));
endmodule
