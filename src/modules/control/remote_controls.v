// Passive until a command arrives. Uses existing UART pins, no duplicate board state.
module remote_controls #(parameter CLK_HZ=100000000,parameter BAUD=115200,
                         parameter TIMEOUT_CYCLES=50000000,parameter IR_ENABLED=0)(
 input clk,input rst,input rx,output tx,output overflow,
 output next_pulse,output prev_pulse,output toggle_pulse,
 output [23:0] time_bcd,output [7:0] time_seq,output time_set,input ir_rx,
 output auto_enh_en,output slide_enable,zh_enable,large_clock,
 output vol_up,output vol_dn,output mute_toggle,output bri_up,output bri_dn,
 output con_up,output con_dn,output osd_toggle,output test_toggle,output transition_toggle,
 output [1:0] transition_mode,output captions_enable,output scroll_enable,output [1:0] slogan_select);
 // NEC 唯一码表（21键遥控，按实际键位）；命令值不得重复。
 localparam [7:0] IR_NEXT=8'h09;       // → 右方向 = 下一张
 localparam [7:0] IR_PREV=8'h07;       // ← 左方向 = 上一张
 localparam [7:0] IR_AUTOPLAY=8'h15;   // 齿轮 = 切换自动播放
 localparam [7:0] IR_VOL_UP=8'h40;     // ↑ = 音量+
 localparam [7:0] IR_VOL_DN=8'h19;     // ↓ = 音量−
 localparam [7:0] IR_MUTE=8'h43;       // E = 静音
 localparam [7:0] IR_BRI_UP=8'h45;     // A = 亮度+
 localparam [7:0] IR_BRI_DN=8'h46;     // B = 亮度−
 localparam [7:0] IR_CON_UP=8'h47;     // C = 对比度+
 localparam [7:0] IR_CON_DN=8'h44;     // D = 对比度−
 localparam [7:0] IR_AUTO_LEVEL=8'h0D; // F = 自动色阶
 localparam [7:0] IR_ALBUM_5S=8'h16;   // 0 = 5秒相册
 localparam [7:0] IR_CHINESE=8'h0C;    // 1 = 中文字幕
 localparam [7:0] IR_CLOCK=8'h18;      // 2 = 大/小字时钟
 localparam [7:0] IR_OSD=8'h5E;        // 3 = OSD
 localparam [7:0] IR_TRANSITION=8'h08; // 4 = 转场
 localparam [7:0] IR_TEST_PATTERN=8'h1C;// 5 = 测试图案
 // 6/7/8/9（0x5A/0x42/0x52/0x4A）预留
 // Local release leaf keeps the new receiver/parser/reply cluster off
 // the shared control-reset fanout. Assertion remains asynchronous.
 (* preserve="true" *) reg remote_rst;
 always @(posedge clk or posedge rst)begin
  if(rst)remote_rst<=1;else remote_rst<=0;
 end
 wire [7:0] ir_command;
 wire ir_valid,ir_repeat;
 reg [7:0] ir_action;
 always @* begin
  ir_action=0;
  case(ir_command)
   IR_NEXT:ir_action="n"; IR_PREV:ir_action="p"; IR_AUTOPLAY:ir_action="b";
   IR_VOL_UP:ir_action="+"; IR_VOL_DN:ir_action="-"; IR_MUTE:ir_action="m";
   IR_OSD:ir_action="o"; IR_BRI_UP:ir_action="]"; IR_BRI_DN:ir_action="[";
   IR_CON_UP:ir_action="}"; IR_CON_DN:ir_action="{";
   IR_AUTO_LEVEL:ir_action="a"; IR_ALBUM_5S:ir_action="s";
   IR_CHINESE:ir_action="h"; IR_CLOCK:ir_action="l";
   IR_TEST_PATTERN:ir_action="t"; IR_TRANSITION:ir_action="e";
   default:;
  endcase
 end
 wire supported_ir=ir_valid && !ir_repeat && ir_action!=0;
 generate if(IR_ENABLED)begin:infrared
  ir_nec_rx #(.CLK_FREQ(CLK_HZ)) decoder(.clk(clk),.rst(remote_rst),.ir_in(ir_rx),
   .o_command(ir_command),.o_command_valid(ir_valid),.o_repeat(ir_repeat));
 end else begin:no_infrared
  assign ir_command=0;assign ir_valid=0;assign ir_repeat=0;
 end endgenerate
 wire [7:0] data;
 wire valid,time_busy,time_reply,time_ok;
 uart_rx #(.CLK_FREQ(CLK_HZ),.BAUD(BAUD)) receiver(clk,remote_rst,rx,data,valid);
 time_cmd #(.TIMEOUT_CYCLES(TIMEOUT_CYCLES)) clock_command(
  .clk(clk),.rst(remote_rst),.uart_data(data),.uart_valid(valid),.time_bcd(time_bcd),
  .time_seq(time_seq),.time_set(time_set),.busy(time_busy),.reply_valid(time_reply),.reply_ok(time_ok));
 player_control commands(.clk(clk),.rst(remote_rst),.ir_command(ir_action),.ir_valid(supported_ir),
  .next_pulse(next_pulse),.prev_pulse(prev_pulse),.toggle_pulse(toggle_pulse),
  .vol_up(vol_up),.vol_dn(vol_dn),.mute_toggle(mute_toggle),.bri_up(bri_up),.bri_dn(bri_dn),
  .con_up(con_up),.con_dn(con_dn),.osd_toggle(osd_toggle),.test_toggle(test_toggle),
  .transition_toggle(transition_toggle),.transition_mode(transition_mode),.captions_enable(captions_enable),
  .scroll_enable(scroll_enable),.slogan_select(slogan_select),.auto_enh_en(auto_enh_en),
  .slide_enable(slide_enable),.zh_enable(zh_enable),.large_clock(large_clock));
 uart_tx_queue #(.CLK_FREQ(CLK_HZ),.BAUD(BAUD)) replies(.clk(clk),.rst(remote_rst),
  .i_data(time_ok?8'h4b:8'h3f),
  .i_send(time_reply),
  .o_tx(tx),.o_busy(),.overflow(overflow));
endmodule
