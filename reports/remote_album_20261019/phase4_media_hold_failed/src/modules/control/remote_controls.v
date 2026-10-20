// Passive until a command arrives. Uses existing UART pins, no duplicate board state.
module remote_controls #(parameter CLK_HZ=100000000,parameter BAUD=115200,
                         parameter TIMEOUT_CYCLES=50000000,parameter IR_ENABLED=0)(
 input clk,input rst,input rx,output tx,output overflow,
 output next_pulse,output prev_pulse,output toggle_pulse,
 output [23:0] time_bcd,output [7:0] time_seq,output time_set,input ir_rx,output auto_enh_en,output slide_enable,zh_enable,large_clock);
 // Local release leaf keeps the new receiver/parser/reply cluster off
 // the shared control-reset fanout. Assertion remains asynchronous.
 (* preserve="true" *) reg remote_rst;
 always @(posedge clk or posedge rst)begin
  if(rst)remote_rst<=1;else remote_rst<=0;
 end
 wire [7:0] ir_command;
 wire ir_valid,ir_repeat;
 wire supported_ir=ir_valid && (ir_command==8'h40 || ir_command==8'h15 || ir_command==8'h44);
 generate if(IR_ENABLED)begin:infrared
  ir_nec_rx #(.CLK_FREQ(CLK_HZ)) decoder(.clk(clk),.rst(remote_rst),.ir_in(ir_rx),
   .o_command(ir_command),.o_command_valid(ir_valid),.o_repeat(ir_repeat));
 end else begin:no_infrared
  assign ir_command=0;assign ir_valid=0;assign ir_repeat=0;
 end endgenerate
 wire [7:0] data;
 wire valid,time_busy,time_reply,time_ok;
 wire pc_reply_valid;wire [7:0] pc_reply;
 wire command_valid=valid && !time_busy && data!="T";
 wire [7:0] command=(data=="n" || data=="p" || data=="b" || data=="a" || data=="s" || data=="h" || data=="l")?data:8'd0;
 uart_rx #(.CLK_FREQ(CLK_HZ),.BAUD(BAUD)) receiver(clk,remote_rst,rx,data,valid);
 time_cmd #(.TIMEOUT_CYCLES(TIMEOUT_CYCLES)) clock_command(
  .clk(clk),.rst(remote_rst),.uart_data(data),.uart_valid(valid),.time_bcd(time_bcd),
  .time_seq(time_seq),.time_set(time_set),.busy(time_busy),.reply_valid(time_reply),.reply_ok(time_ok));
 player_control #(.PC_COMMANDS(1)) commands(.clk(clk),.rst(remote_rst),.uart_data(command),.uart_valid(command_valid),
  .ir_command(ir_command),.ir_valid(supported_ir),.next_pulse(next_pulse),.prev_pulse(prev_pulse),.toggle_pulse(toggle_pulse),
  .reply_valid(pc_reply_valid),.reply(pc_reply),.volume(),.mute(),.osd_enable(),
  .brightness(),.test_pattern(),.transition_mode(),.captions_enable(),.scroll_enable(),.slogan_select(),.auto_enh_en(auto_enh_en),.slide_enable(slide_enable),.zh_enable(zh_enable),.large_clock(large_clock));
 uart_tx_queue #(.CLK_FREQ(CLK_HZ),.BAUD(BAUD)) replies(.clk(clk),.rst(remote_rst),
  .i_data(time_reply?(time_ok?8'h4b:8'h3f):pc_reply),.i_send(time_reply || pc_reply_valid),
  .o_tx(tx),.o_busy(),.overflow(overflow));
endmodule
