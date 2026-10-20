//======================================================================
// tb_video_scaler.v —— 最近邻缩放器自测（2 倍放大）
//
// 配置：SRC 8x6 -> DST 16x12（2 倍最近邻放大）
// 源像素值 = src_y*SRC_W + src_x，便于验证目标像素来自哪个源像素。
// 期望：目标像素(ox,oy) == (oy/2)*8 + (ox/2)
//
// 运行（iverilog）：
//   cd myproject
//   iverilog -o tb_scaler.vvp src/modules/optional/video_scaler.v sim/tb_video_scaler.v
//   vvp tb_video_scaler.vvp
//======================================================================
`timescale 1ns/1ps
module tb_video_scaler;

localparam SRC_W = 8,  SRC_H = 6;
localparam DST_W = 16, DST_H = 12;
localparam DATA_W = 8;

reg                clk, rst, i_start;
wire               o_src_req;
reg  [DATA_W-1:0]  i_src_pix;
reg                i_src_vld;
wire [DATA_W-1:0]  o_pix;
wire               o_pix_vld, o_sof, o_eol;

video_scaler #(
    .SRC_W(SRC_W), .SRC_H(SRC_H),
    .DST_W(DST_W), .DST_H(DST_H),
    .DATA_W(DATA_W)
) dut (
    .clk(clk), .rst(rst), .i_start(i_start),
    .o_src_req(o_src_req), .i_src_pix(i_src_pix), .i_src_vld(i_src_vld),
    .o_pix(o_pix), .o_pix_vld(o_pix_vld), .o_sof(o_sof), .o_eol(o_eol)
);

always #5 clk = ~clk;   // 100MHz

// ---- 源行模型：o_src_req 高时逐拍给出一行像素 ----
reg [15:0] src_line = 0;
reg [15:0] pix_idx  = 0;
reg        src_req_d;
always @(posedge clk) src_req_d <= o_src_req;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        src_line <= 0;
        pix_idx  <= 0;
        i_src_pix <= 0;
        i_src_vld <= 0;
    end
    else begin
        if (o_src_req) begin
            i_src_pix <= src_line * SRC_W + pix_idx;   // 可标识源坐标
            i_src_vld <= 1'b1;
            if (pix_idx == SRC_W - 1)
                pix_idx <= 0;
            else
                pix_idx <= pix_idx + 1'b1;
        end
        else begin
            i_src_vld <= 1'b0;
            if (src_req_d && !o_src_req) begin
                // 一行加载完成，指向下一行
                src_line <= src_line + 1'b1;
                pix_idx  <= 0;
            end
        end
    end
end

// ---- 目标端逐像素校验 ----
reg [15:0] out_x = 0, out_y = 0;
reg [15:0] out_cnt = 0;
integer    errors = 0;
always @(posedge clk) begin
    if (o_pix_vld) begin
        if (o_pix != ((out_y >> 1) * SRC_W + (out_x >> 1))) begin
            $display("[FAIL] (%0d,%0d) 期望 %0d 实际 %0d",
                     out_x, out_y, (out_y >> 1)*SRC_W + (out_x >> 1), o_pix);
            errors = errors + 1;
        end
        out_cnt = out_cnt + 1;
        if (out_x == DST_W - 1) begin
            out_x <= 0;
            out_y <= out_y + 1;
        end
        else
            out_x <= out_x + 1;
    end
end

integer done = 0;
always @(posedge clk) begin
    if (out_cnt == DST_W * DST_H && out_cnt != 0)
        done <= 1;
end

initial begin
    clk = 0; rst = 1; i_start = 0; i_src_vld = 0; i_src_pix = 0;
    #20 rst = 0;
    #100;

    // 触发一帧缩放
    @(posedge clk);
    i_start <= 1'b1;
    @(posedge clk);
    i_start <= 1'b0;

    // 等待完成
    wait(done == 1);
    #100;

    if (errors == 0)
        $display("=== tb_video_scaler ALL PASS（共 %0d 像素）===", out_cnt);
    else
        $display("=== tb_video_scaler FAILED: %0d 项 ===", errors);
    $finish;
end

endmodule
