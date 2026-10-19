//======================================================================
// osd_char_rom.v
// 5x7 ASCII 点阵字库（OSD 屏幕菜单用）
//
// 设计说明：
//   - 每个字符 5 列 x 7 行，打包成 56bit（7 字节，行0在最高字节）
//   - 每行 8bit，5 列点阵放在 bit[4:0]（左对齐），bit[7:5] 恒为 0
//   - 纯组合逻辑生成，综合成分布式 ROM（LUT），约 300 LUT
//   - 字符集：空格、0-9、A-Z、常用符号（: / . - % > < = [ ] | _ , + ! ?）
//
// 复用说明：这是新增模块（原有工程无 OSD），与 color_bar 等完全解耦，
//           可在 video_clk 域被任意显示逻辑调用。
//======================================================================
module osd_char_rom (
    input  wire [7:0] i_ascii,    // ASCII 码（0x20 ~ 0x7F）
    input  wire [3:0] i_row,      // 字符内行号 0~15（5x7 字模占 0~6，7~15 空白）
    output reg  [7:0] o_row_data  // 该行 8bit 点阵（5 列在 bit[4:0]）
);

// 56bit = 7 字节：{row0, row1, row2, row3, row4, row5, row6}
reg [34:0] glyph;

always @(*) begin
    case (i_ascii)
        // ---------- 符号 ----------
        8'h20: glyph = 35'h000000000; // 空格
        8'h21: glyph = 35'h108421004; // !
        8'h25: glyph = 35'h672222273; // %
        8'h2B: glyph = 35'h0084f9080; // +
        8'h2C: glyph = 35'h000000184; // ,
        8'h2D: glyph = 35'h000007c00; // -
        8'h2E: glyph = 35'h00000018c; // .
        8'h2F: glyph = 35'h044222110; // /
        // ---------- 数字 0-9 ----------
        8'h30: glyph = 35'h3a33ae62e; // 0
        8'h31: glyph = 35'h11842108e; // 1
        8'h32: glyph = 35'h3a211111f; // 2
        8'h33: glyph = 35'h7c441062e; // 3
        8'h34: glyph = 35'h08ca97c42; // 4
        8'h35: glyph = 35'h7e1e0862e; // 5
        8'h36: glyph = 35'h1910f462e; // 6
        8'h37: glyph = 35'h7c2222108; // 7
        8'h38: glyph = 35'h3a317462e; // 8
        8'h39: glyph = 35'h3a317844c; // 9
        // ---------- 符号 ----------
        8'h3A: glyph = 35'h018c03180; // :
        8'h3C: glyph = 35'h088882082; // <
        8'h3D: glyph = 35'h001f07c00; // =
        8'h3E: glyph = 35'h208208888; // >
        8'h3F: glyph = 35'h3a2111004; // ?
        // ---------- 大写 A-Z ----------
        8'h41: glyph = 35'h3a31fc631; // A
        8'h42: glyph = 35'h7a31f463e; // B
        8'h43: glyph = 35'h3a308422e; // C
        8'h44: glyph = 35'h72518c65c; // D
        8'h45: glyph = 35'h7e10f421f; // E
        8'h46: glyph = 35'h7e10f4210; // F
        8'h47: glyph = 35'h3a30bc62f; // G
        8'h48: glyph = 35'h4631fc631; // H
        8'h49: glyph = 35'h38842108e; // I
        8'h4A: glyph = 35'h1c4210a4c; // J
        8'h4B: glyph = 35'h4654c5251; // K
        8'h4C: glyph = 35'h42108421f; // L
        8'h4D: glyph = 35'h4775ac631; // M
        8'h4E: glyph = 35'h47359c631; // N
        8'h4F: glyph = 35'h3a318c62e; // O
        8'h50: glyph = 35'h7a31f4210; // P
        8'h51: glyph = 35'h3a318d64d; // Q
        8'h52: glyph = 35'h7a31f5251; // R
        8'h53: glyph = 35'h3e107043e; // S
        8'h54: glyph = 35'h7c8421084; // T
        8'h55: glyph = 35'h46318c62e; // U
        8'h56: glyph = 35'h46318c544; // V
        8'h57: glyph = 35'h4631ad6aa; // W
        8'h58: glyph = 35'h462a22a31; // X
        8'h59: glyph = 35'h462a21084; // Y
        8'h5A: glyph = 35'h7c222221f; // Z
        // ---------- 符号 ----------
        8'h5B: glyph = 35'h39084210e; // [
        8'h5D: glyph = 35'h38421084e; // ]
        8'h5F: glyph = 35'h00000001f; // _
        8'h7C: glyph = 35'h108421084; // |
        default: glyph = 35'h000000000; // 未知字符 → 空白
    endcase
end

// 行号 0~6 取字模，7~15 空白（用于 8x16 字符格纵向留白）
always @(*) begin
    if (i_row >= 4'd7)
        o_row_data = 8'h00;
    else
        o_row_data = {3'b000,glyph[((4'd6 - i_row) * 5) +: 5]};
end

endmodule
