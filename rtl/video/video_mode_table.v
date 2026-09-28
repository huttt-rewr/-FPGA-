//======================================================================
// video_mode_table.v
// 标准视频时序参数表（分辨率自适应底层）
//
// 解决痛点：现有工程分辨率写死（color_bar 里 ifdef 640x480），接别的显示器
//          要么黑屏要么拉伸。本模块把各标准模式的时序参数做成查表，
//          由 EDID 解析 / 拨码 / 串口选出一个模式索引，输出全部参数。
//
// 配合：
//   - color_bar 改造为“运行时参数”（把 ifdef 换成输入参数）
//   - video_pll 增加 25.175/74.25/148.5/40 MHz 档位，用 o_clk_sel 选时钟
//   - HDMI 核心的 HTOTAL/HACTIVE/VIDEO_VIC 等参数按本表重配
//
// 复用说明：新增模块，纯粹的组合查表，与现有代码零耦合。
//======================================================================
module video_mode_table (
    input  wire [2:0]  i_mode,       // 模式索引（0~3）
    output reg  [15:0] o_htotal, o_hactive, o_hfp, o_hsa, o_hbp,
    output reg  [15:0] o_vtotal, o_vactive, o_vfp, o_vsa, o_vbp,
    output reg  [1:0]  o_clk_sel,    // 像素时钟档位：0=25.175M 1=74.25M 2=148.5M 3=40M
    output reg         o_hs_pol,     // 1=正极性 0=负极性
    output reg         o_vs_pol,
    output reg  [31:0] o_pixel_clk   // 期望像素时钟 Hz（供校验/日志）
);

always @(*) begin
    case (i_mode)
        // 640x480@60 (VIC=1)，像素时钟 25.175 MHz
        3'd0: begin
            o_htotal = 16'd800;  o_hactive = 16'd640;
            o_hfp    = 16'd16;   o_hsa     = 16'd96;  o_hbp = 16'd48;
            o_vtotal = 16'd525;  o_vactive = 16'd480;
            o_vfp    = 16'd10;   o_vsa     = 16'd2;   o_vbp = 16'd33;
            o_clk_sel = 2'd0;    o_hs_pol = 1'b0;     o_vs_pol = 1'b0;
            o_pixel_clk = 32'd25_175_000;
        end
        // 1280x720@60 (VIC=4)，像素时钟 74.25 MHz
        3'd1: begin
            o_htotal = 16'd1650; o_hactive = 16'd1280;
            o_hfp    = 16'd110;  o_hsa     = 16'd40;  o_hbp = 16'd220;
            o_vtotal = 16'd750;  o_vactive = 16'd720;
            o_vfp    = 16'd5;    o_vsa     = 16'd5;   o_vbp = 16'd20;
            o_clk_sel = 2'd1;    o_hs_pol = 1'b1;     o_vs_pol = 1'b1;
            o_pixel_clk = 32'd74_250_000;
        end
        // 1920x1080@60 (VIC=16)，像素时钟 148.5 MHz
        3'd2: begin
            o_htotal = 16'd2200; o_hactive = 16'd1920;
            o_hfp    = 16'd88;   o_hsa     = 16'd44;  o_hbp = 16'd148;
            o_vtotal = 16'd1125; o_vactive = 16'd1080;
            o_vfp    = 16'd4;    o_vsa     = 16'd5;   o_vbp = 16'd36;
            o_clk_sel = 2'd2;    o_hs_pol = 1'b1;     o_vs_pol = 1'b1;
            o_pixel_clk = 32'd148_500_000;
        end
        // 800x600@60，像素时钟 40 MHz
        3'd3: begin
            o_htotal = 16'd1056; o_hactive = 16'd800;
            o_hfp    = 16'd40;   o_hsa     = 16'd128; o_hbp = 16'd88;
            o_vtotal = 16'd628;  o_vactive = 16'd600;
            o_vfp    = 16'd1;    o_vsa     = 16'd4;   o_vbp = 16'd23;
            o_clk_sel = 2'd3;    o_hs_pol = 1'b1;     o_vs_pol = 1'b1;
            o_pixel_clk = 32'd40_000_000;
        end
        default: begin
            o_htotal = 16'd800;  o_hactive = 16'd640;
            o_hfp    = 16'd16;   o_hsa     = 16'd96;  o_hbp = 16'd48;
            o_vtotal = 16'd525;  o_vactive = 16'd480;
            o_vfp    = 16'd10;   o_vsa     = 16'd2;   o_vbp = 16'd33;
            o_clk_sel = 2'd0;    o_hs_pol = 1'b0;     o_vs_pol = 1'b0;
            o_pixel_clk = 32'd25_175_000;
        end
    endcase
end

endmodule
