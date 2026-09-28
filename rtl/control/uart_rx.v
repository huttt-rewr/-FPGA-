//======================================================================
// uart_rx.v
// UART 接收器：8N1 格式，16 倍过采样
//
// 格式：空闲高、起始位(1bit低) + 8bit数据(LSB先) + 停止位(1bit高)
// 设计：16x 过采样，在每个 bit 中点采样，抗干扰、对波特率误差不敏感
//
// 复用说明：新增模块，收字节后交 cmd_decode 统一解析；配 uart_tx 可做
//           上位机 / 蓝牙串口模块的双向通信（调音量、切图、设分辨率）。
//======================================================================
module uart_rx #(
    parameter CLK_FREQ = 100_000_000,   // 时钟频率 Hz
    parameter BAUD     = 115200         // 波特率
)(
    input  wire       clk,
    input  wire       rst,          // 高有效复位
    input  wire       rx,           // 串行输入
    output reg [7:0]  o_data,       // 收到的字节
    output reg        o_valid       // 单拍有效脉冲
);

localparam OVS = 16;                          // 过采样倍率
localparam DIV = CLK_FREQ / (BAUD * OVS);     // 每个过采样节拍的 clk 数
localparam MID = OVS / 2;                     // 中点采样位置（8）

// ---- 同步 + 起始位下降沿检测 ----
reg [2:0] rx_sh;
always @(posedge clk or posedge rst) begin
    if (rst) rx_sh <= 3'b111;
    else     rx_sh <= {rx_sh[1:0], rx};
end
// rx_sh <= {rx_sh[1:0], rx}：rx_sh[0] 最新、rx_sh[2] 最旧。
// 下降沿(1->0) = 旧一拍(rx_sh[2])为 1 且新一拍(rx_sh[1])为 0。
wire rx_now     = rx_sh[2];            // 采样用同步值（3 级延迟）
wire start_edge = rx_sh[2] & ~rx_sh[1]; // 1->0 起始位

reg        busy;
reg [15:0] div_cnt;    // 产生 ovs 节拍的分频计数
reg [3:0]  ovs_cnt;    // 每个 bit 内的过采样计数 0~15
reg [3:0]  bit_cnt;    // 0=起始位 1~8=数据 9=停止位
reg [7:0]  shift;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        busy    <= 1'b0;
        div_cnt <= 16'd0;
        ovs_cnt <= 4'd0;
        bit_cnt <= 4'd0;
        shift   <= 8'd0;
        o_data  <= 8'd0;
        o_valid <= 1'b0;
    end
    else begin
        o_valid <= 1'b0;

        if (!busy) begin
            if (start_edge) begin
                busy    <= 1'b1;
                div_cnt <= 16'd0;
                ovs_cnt <= 4'd0;
                bit_cnt <= 4'd0;
            end
        end
        else begin
            // 产生过采样节拍
            if (div_cnt == DIV - 1) begin
                div_cnt <= 16'd0;
                if (ovs_cnt == OVS - 1) begin
                    ovs_cnt <= 4'd0;
                    if (bit_cnt == 4'd9)
                        busy <= 1'b0;          // 停止位收完
                    else
                        bit_cnt <= bit_cnt + 1'b1;
                end
                else begin
                    ovs_cnt <= ovs_cnt + 1'b1;
                end
            end
            else begin
                div_cnt <= div_cnt + 1'b1;
            end

            // 每个 bit 中点采样一次
            if (div_cnt == DIV - 1 && ovs_cnt == MID) begin
                case (bit_cnt)
                    4'd0: begin
                        // 起始位中点：确认仍是低电平，否则判定为毛刺
                        if (rx_now) busy <= 1'b0;
                    end
                    4'd1,4'd2,4'd3,4'd4,4'd5,4'd6,4'd7,4'd8: begin
                        shift[bit_cnt - 1] <= rx_now;   // 采样数据位
                    end
                    4'd9: begin
                        // 停止位中点：高电平则收齐一个字节
                        if (rx_now) begin
                            o_data  <= shift;
                            o_valid <= 1'b1;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end
end

endmodule
