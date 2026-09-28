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
module ir_nec_rx #(
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
reg [2:0] ir_sh;
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
reg [31:0] us_cnt;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        tick_cnt <= 16'd0;
        us_cnt   <= 32'd0;
    end
    else if (tick_cnt == US_TICK - 1) begin
        tick_cnt <= 16'd0;
        us_cnt   <= us_cnt + 1'b1;
    end
    else begin
        tick_cnt <= tick_cnt + 1'b1;
    end
end

// ---- 记录 mark 起点 / space 起点 ----
reg [31:0] t_fall, t_rise;

// 当前 mark/space 时长（组合计算，仅在边沿时刻有意义）
wire [31:0] m_len = t_rise - t_fall;   // 刚结束的 mark 时长
wire [31:0] s_len = us_cnt - t_rise;   // 刚结束的 space 时长

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
                    t_fall <= us_cnt;
                    state  <= S_MARK;
                end
            end

            S_MARK: begin
                if (ir_rise) begin
                    t_rise <= us_cnt;
                    state  <= S_SPACE;
                end
            end

            S_SPACE: begin
                if (ir_fall) begin
                    t_fall <= us_cnt;          // 下一个 mark 起点
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
                    else if (is_bit_mark && in_data) begin
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
