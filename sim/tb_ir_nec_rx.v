//======================================================================
// tb_ir_nec_rx.v —— NEC 红外解码自测
//
// 验证：发一帧 NEC（地址 0x00 + 反码 0xFF + 命令 0x1A + 反码 0xE5），
//       期望解出 command=0x1A 并给出一拍 command_valid；再发一个重复码，
//       期望给出 o_repeat。
//
// 运行（iverilog）：
//   cd myproject
//   iverilog -o tb_ir.vvp src/modules/control/ir_nec_rx.v sim/tb_ir_nec_rx.v
//   vvp tb_ir.vvp
//======================================================================
`timescale 1ns/1ps
module tb_ir_nec_rx;

localparam CLK_FREQ = 100_000_000;

reg        clk, rst, ir_in;
wire [7:0] command;
wire       command_valid, repeat_flag;

ir_nec_rx #(.CLK_FREQ(CLK_FREQ)) dut (
    .clk            (clk),
    .rst            (rst),
    .ir_in          (ir_in),
    .o_command      (command),
    .o_command_valid(command_valid),
    .o_repeat       (repeat_flag)
);

always #5 clk = ~clk;   // 100MHz

// 驱动 mark（低）/ space（高），t 单位 us
task mark_us(input integer t); begin ir_in = 1'b0; #(t*1000); end endtask
task space_us(input integer t); begin ir_in = 1'b1; #(t*1000); end endtask

// 发一个字节（LSB 先）：位0=560us低+560us高，位1=560us低+1690us高
task send_byte(input [7:0] b);
    integer j;
    begin
        for (j = 0; j < 8; j = j + 1) begin
            mark_us(560);
            if (b[j]) space_us(1690);
            else      space_us(560);
        end
    end
endtask

// 采样命令输出
reg        got_valid, got_repeat;
reg [7:0]  got_cmd;
always @(posedge clk) begin
    if (command_valid) begin
        got_valid <= 1'b1;
        got_cmd   <= command;
    end
    if (repeat_flag) got_repeat <= 1'b1;
end

integer errors = 0;
wire [7:0] reference_command;
wire reference_valid,reference_repeat;
ir_nec_rx_reference #(.CLK_FREQ(CLK_FREQ)) reference_decoder(
 clk,rst,ir_in,reference_command,reference_valid,reference_repeat);
reg [9:0] reference_q;
always @(posedge clk)begin
 if(rst)reference_q<=0;
 else reference_q<={reference_valid,reference_repeat,reference_command};
 #1;
 if(!rst && {command_valid,repeat_flag,command}!==reference_q)begin
  if(errors<5)$display("FAILED NEC pipeline differs from frozen reference");
  errors=errors+1;
 end
end

task check(input [255:0] name, input cond);
begin
    if (cond) $display("[PASS] %0s", name);
    else begin $display("[FAIL] %0s", name); errors = errors + 1; end
end
endtask

initial begin
    clk = 0; rst = 1; ir_in = 1'b1;
    got_valid = 0; got_cmd = 0; got_repeat = 0;

    #20 rst = 0;
    #1000;

    // ---- 第一帧：地址 0x00，命令 0x1A ----
    mark_us(9000); space_us(4500);       // 引导码
    send_byte(8'h00);                    // 地址
    send_byte(8'hFF);                    // 地址反码
    send_byte(8'h1A);                    // 命令
    send_byte(8'hE5);                    // 命令反码
    mark_us(560); ir_in = 1'b1;          // 结束 mark

    #20000;  // 等待解码完成
    check("命令码 == 0x1A", got_valid && got_cmd == 8'h1A);
    $display("   got_valid=%0b got_cmd=%h", got_valid, got_cmd);

    // ---- 第二帧：重复码 ----
    got_valid = 0; got_repeat = 0;
    mark_us(9000); space_us(2250);       // 重复码：9ms低 + 2.25ms高
    mark_us(560); ir_in = 1'b1;          // 结束 mark：用下降沿关闭重复 space，触发检测
    #100000;                             // 等待 o_repeat 单拍脉冲被采样到
    check("重复码 o_repeat 触发", got_repeat == 1'b1);

    // ---- 第三帧：错误地址反码应被拒（命令反码故意发错）----
    got_valid = 0;
    mark_us(9000); space_us(4500);
    send_byte(8'h00);
    send_byte(8'h00);                    // 反码错误（应为 0xFF）
    send_byte(8'h1A);
    send_byte(8'hE5);
    mark_us(560); ir_in = 1'b1;
    #20000;
    check("反码不匹配 -> 不输出 command_valid", got_valid == 1'b0);

    // Timing-window boundaries, compared cycle-by-cycle with original.
    mark_us(6999);space_us(3500);mark_us(300);space_us(900);
    mark_us(7000);space_us(3499);mark_us(900);space_us(1200);
    mark_us(12000);space_us(6000);mark_us(901);space_us(2500);
    mark_us(12001);space_us(6001);mark_us(560);space_us(2501);
    #10000;
    if (errors == 0)
        $display("\n=== tb_ir_nec_rx ALL PASS ===");
    else
        $display("\n=== tb_ir_nec_rx FAILED: %0d 项 ===", errors);
    $finish;
end

endmodule

// Frozen pre-pipeline protocol reference, simulation only.
//======================================================================
// ir_nec_rx.v
// NEC 红外遥控解码器（38kHz 载波解调后的基带信号输入）
//
// 协议（NEC）：9ms 引导低电平 + 4.5ms 高电平
//             地址(8bit,LSB先) + 地址反码 + 命令(8bit) + 命令反码 = 32bit
//             位0 = 560us低 + 560us高；位1 = 560us低 + 1690us高
//             重复码 = 9ms低 + 2.25ms高
//
// 输入约定：ir_in 空闲为高，收到载波为低（即“低=mark，高=space”）
// 输出：o_command_valid 单拍脉冲 + o_command 命令码；o_repeat 单拍脉冲
//
// 复用说明：新增模块，输出命令码可直接接入 cmd_decode 统一命令解析，
//           与按键/串口通道并列。
//======================================================================
module ir_nec_rx_reference #(
    parameter CLK_FREQ = 100_000_000   // 时钟频率 Hz
)(
    input  wire        clk,
    input  wire        rst,            // 高有效复位
    input  wire        ir_in,          // 红外解调输出（空闲高）
    output reg  [7:0]  o_command,      // 解出的命令码
    output reg         o_command_valid,// 命令有效（单拍）
    output reg         o_repeat        // 重复码（单拍）
);

localparam US_TICK = CLK_FREQ / 1_000_000;  // 1us 对应的 clk 数

// ---- 时长阈值（单位 us）----
localparam LEADER_MARK_MIN  = 7000;
localparam LEADER_MARK_MAX  = 12000;
localparam LEADER_SPACE_MIN = 3500;
localparam LEADER_SPACE_MAX = 6000;
localparam REPEAT_SPACE_MIN = 1500;
localparam REPEAT_SPACE_MAX = 3000;
localparam BIT_MARK_MIN     = 300;
localparam BIT_MARK_MAX     = 900;
localparam BIT0_SPACE_MAX   = 900;    // 位0 高电平 <= 900us
localparam BIT1_SPACE_MIN   = 1200;   // 位1 高电平 >= 1200us
localparam BIT1_SPACE_MAX   = 2500;

// ---- 3 级同步 + 边沿检测 ----
(* async_reg="true" *) reg [2:0] ir_sh;
always @(posedge clk or posedge rst) begin
    if (rst) ir_sh <= 3'b111;
    else     ir_sh <= {ir_sh[1:0], ir_in};
end
// 注意：ir_sh <= {ir_sh[1:0], ir_in}，ir_sh[0] 最新、ir_sh[2] 最旧。
// 因此“新一拍”是 ir_sh[1]，“旧一拍”是 ir_sh[2]。
wire ir_prev = ir_sh[2];            // 较旧的一拍（3 级延迟）
wire ir_now  = ir_sh[1];            // 较新的一拍（2 级延迟）
wire ir_fall = ir_prev & ~ir_now;   // 1->0：mark 开始
wire ir_rise = ~ir_prev & ir_now;   // 0->1：space 开始

// ---- us 计数器 ----
reg [15:0] tick_cnt;
reg [15:0] duration_us, m_len;
wire [15:0] s_len=duration_us;
// Saturating edge-relative durations avoid a 32-bit subtract/comparator chain.
always @(posedge clk or posedge rst) begin
    if(rst) begin tick_cnt<=0;duration_us<=0;m_len<=0;end
    else begin
        if(tick_cnt==US_TICK-1) tick_cnt<=0;
        else tick_cnt<=tick_cnt+1'b1;
        if(ir_fall || ir_rise) duration_us<=0;
        else if(tick_cnt==US_TICK-1 && duration_us!=16'hffff)
            duration_us<=duration_us+1'b1;
        if(ir_rise) m_len<=duration_us;
    end
end

// ---- 时长分类 ----
wire is_leader_mark  = (m_len >= LEADER_MARK_MIN)  && (m_len <= LEADER_MARK_MAX);
wire is_bit_mark     = (m_len >= BIT_MARK_MIN)     && (m_len <= BIT_MARK_MAX);
wire is_leader_space = (s_len >= LEADER_SPACE_MIN) && (s_len <= LEADER_SPACE_MAX);
wire is_repeat_space = (s_len >= REPEAT_SPACE_MIN) && (s_len <= REPEAT_SPACE_MAX);
wire is_bit0_space   = (s_len >= BIT_MARK_MIN)     && (s_len <= BIT0_SPACE_MAX);
wire is_bit1_space   = (s_len >= BIT1_SPACE_MIN)   && (s_len <= BIT1_SPACE_MAX);

// ---- 状态机 ----
localparam S_IDLE  = 2'd0;
localparam S_MARK  = 2'd1;   // 低电平中，等上升沿
localparam S_SPACE = 2'd2;   // 高电平中，等下降沿

reg [1:0]  state;
reg        in_data;          // 是否已收到引导码、正在收数据
reg [31:0] data;             // 32bit 数据（LSB 先移入）
reg [5:0]  bit_cnt;

// 移入当前位后的完整 32bit（用于第 32 位收齐后立即校验）
// 新 bit 进最高位、旧 bit 右移：使最先收到的 bit 落在 data[0]，
// 从而 data[7:0]=地址、[15:8]=地址反码、[23:16]=命令、[31:24]=命令反码。
wire [31:0] new_data = {is_bit1_space, data[31:1]};

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state   <= S_IDLE;
        in_data <= 1'b0;
        data    <= 32'd0;
        bit_cnt <= 6'd0;
        o_command       <= 8'd0;
        o_command_valid <= 1'b0;
        o_repeat        <= 1'b0;
    end
    else begin
        o_command_valid <= 1'b0;
        o_repeat        <= 1'b0;

        case (state)
            S_IDLE: begin
                in_data <= 1'b0;
                data    <= 32'd0;
                bit_cnt <= 6'd0;
                if (ir_fall) begin
                    state  <= S_MARK;
                end
            end

            S_MARK: begin
                if (ir_rise) begin
                    state  <= S_SPACE;
                end
            end

            S_SPACE: begin
                if (ir_fall) begin
                    state  <= S_MARK;          // 默认继续收下一个 mark

                    if (is_leader_mark) begin
                        // 引导码的低电平已结束，看高电平是“引导”还是“重复”
                        if (is_leader_space) begin
                            in_data <= 1'b1;   // 进入数据接收
                            data    <= 32'd0;
                            bit_cnt <= 6'd0;
                        end
                        else if (is_repeat_space) begin
                            o_repeat <= 1'b1;
                            state    <= S_IDLE; // 重复码结束，回 IDLE
                        end
                        else begin
                            state <= S_IDLE;    // 非法，回 IDLE
                        end
                    end
                    else if (is_bit_mark && in_data && (is_bit0_space || is_bit1_space)) begin
                        // 数据位：按高电平宽度判 0/1（LSB 先）
                        data <= new_data;
                        if (bit_cnt == 6'd31) begin
                            // 第 32 位移入后（new_data 已是完整 32bit），做反码校验
                            if ((new_data[31:24] == ~new_data[23:16]) &&
                                (new_data[15:8]  == ~new_data[7:0]))
                                o_command_valid <= 1'b1;
                            o_command <= new_data[23:16];
                            in_data   <= 1'b0;
                            state     <= S_IDLE;
                        end
                        else begin
                            bit_cnt <= bit_cnt + 1'b1;
                        end
                    end
                    else begin
                        // 其它异常：回 IDLE
                        in_data <= 1'b0;
                        state   <= S_IDLE;
                    end
                end
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
