//======================================================================
// video_scaler.v
// 最近邻缩放器（任意比例），带单行缓冲
//
// 解决痛点：SD/TF 里的 BMP 尺寸五花八门，而显示端是固定分辨率。本模块把
//           任意 SRC_WxSRC_H 的源图最近邻缩放到 DST_WxDST_H。
//
// 原理（最近邻，定点累加）：
//   目标像素(ox,oy) 对应源像素 src_x = floor(ox*SRC_W/DST_W)，
//                              src_y = floor(oy*SRC_H/DST_H)
//   水平用 h_acc 累加 H_STEP，垂直用 v_acc 累加 V_STEP。
//
// 工作方式：
//   - 内部维护一行源数据 line_buf（BRAM/分布式 RAM）
//   - 需要新源行时拉高 o_src_req，外部按 i_src_vld 送满 SRC_W 个像素
//   - 目标行若复用同一源行（垂直放大）则不发 o_src_req
//   - 目标行若跳过多行（垂直缩小）则连续加载直到命中目标行
//
// 复用说明：新增模块，插在 bmp_read（任意尺寸）与帧缓存之间，
//           把任意尺寸统一缩放到显示分辨率后再写 SDRAM。
//
// 注意：line_buf 用组合读（分布式 RAM）。SRC_W 很大（如 1920）时建议
//       改为寄存器读以综合成 BRAM，并加大参数位宽。
//======================================================================
module video_scaler #(
    parameter SRC_W  = 320,
    parameter SRC_H  = 240,
    parameter DST_W  = 640,
    parameter DST_H  = 480,
    parameter DATA_W = 24,
    parameter FP     = 16               // 定点小数位宽
)(
    input  wire                 clk,
    input  wire                 rst,        // 高有效复位
    input  wire                 i_start,    // 帧开始脉冲
    output reg                  o_src_req,  // 源行请求（高电平=正在请求一行）
    input  wire [DATA_W-1:0]    i_src_pix,  // 源像素
    input  wire                 i_src_vld,  // 源像素有效
    output reg  [DATA_W-1:0]    o_pix,      // 缩放后像素
    output reg                  o_pix_vld,  // 输出有效
    output reg                  o_sof,      // 目标帧首像素（单拍）
    output reg                  o_eol       // 目标行末（单拍）
);

localparam H_STEP = (SRC_W << FP) / DST_W;
localparam V_STEP = (SRC_H << FP) / DST_H;

// 单行缓冲
reg [DATA_W-1:0] line_buf [0:SRC_W-1];

localparam S_IDLE = 2'd0, S_LOAD = 2'd1, S_EMIT = 2'd2;
reg [1:0]  state;
reg [15:0] src_cnt;      // 加载行时的像素计数
reg [15:0] cur_sy;       // 当前缓冲中的源行号（0xFFFF 表示尚未加载）
reg [15:0] sy_target;    // 目标行号
reg [31:0] v_acc, h_acc; // 垂直/水平定点累加器
reg [15:0] ox, oy;       // 目标像素坐标

// 组合读：当前源像素（带边界钳位）
wire [15:0] src_x   = ((h_acc >> FP) < SRC_W) ? (h_acc >> FP) : (SRC_W - 1);
wire [DATA_W-1:0] buf_out = line_buf[src_x];

// 行缓冲写
always @(posedge clk) begin
    if (state == S_LOAD && i_src_vld)
        line_buf[src_cnt] <= i_src_pix;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state     <= S_IDLE;
        o_src_req <= 1'b0;
        o_pix_vld <= 1'b0;
        o_sof     <= 1'b0;
        o_eol     <= 1'b0;
        o_pix     <= {DATA_W{1'b0}};
        src_cnt   <= 16'd0;
        cur_sy    <= 16'd0;
        sy_target <= 16'd0;
        v_acc     <= 32'd0;
        h_acc     <= 32'd0;
        ox        <= 16'd0;
        oy        <= 16'd0;
    end
    else begin
        o_sof     <= 1'b0;
        o_eol     <= 1'b0;
        o_pix_vld <= 1'b0;
        o_src_req <= 1'b0;

        case (state)
            S_IDLE: begin
                if (i_start) begin
                    cur_sy    <= 16'hFFFF;   // 表示尚未加载任何行
                    sy_target <= 16'd0;
                    v_acc     <= 32'd0;
                    oy        <= 16'd0;
                    state     <= S_LOAD;
                end
            end

            S_LOAD: begin
                o_src_req <= 1'b1;
                if (i_src_vld) begin
                    if (src_cnt == SRC_W - 1) begin
                        // 一行源数据加载完成
                        src_cnt <= 16'd0;
                        cur_sy  <= cur_sy + 1'b1;
                        if (cur_sy + 1'b1 == sy_target) begin
                            // 命中目标行，开始输出这一行
                            ox    <= 16'd0;
                            h_acc <= 32'd0;
                            state <= S_EMIT;
                        end
                        // 否则继续留在 LOAD，加载下一行（垂直缩小跳行）
                    end
                    else begin
                        src_cnt <= src_cnt + 1'b1;
                    end
                end
            end

            S_EMIT: begin
                o_pix_vld <= 1'b1;
                o_pix     <= buf_out;
                if (ox == 16'd0 && oy == 16'd0)
                    o_sof <= 1'b1;

                h_acc <= h_acc + H_STEP;
                if (ox == DST_W - 1) begin
                    // 行末
                    o_eol <= 1'b1;
                    ox    <= 16'd0;
                    h_acc <= 32'd0;
                    if (oy == DST_H - 1) begin
                        // 帧末
                        oy    <= 16'd0;
                        state <= S_IDLE;
                    end
                    else begin
                        oy        <= oy + 1'b1;
                        v_acc     <= v_acc + V_STEP;
                        sy_target <= (v_acc + V_STEP) >> FP;
                        // 目标源行 != 当前缓冲行 -> 需要加载新行
                        if (((v_acc + V_STEP) >> FP) != cur_sy)
                            state <= S_LOAD;
                        // 否则留 EMIT，垂直方向复用同一源行
                    end
                end
                else begin
                    ox <= ox + 1'b1;
                end
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
