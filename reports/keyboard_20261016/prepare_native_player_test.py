from pathlib import Path
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
s=(R/'sim/tb_sd_native_player.v').read_text(encoding='utf-8')
s=s.replace('tb_sd_native_player','tb_sd_native_integrated')
s=s.replace('sd_card_bmp #(.FAT32_ENABLE(1)', 'sd_card_bmp #(.NATIVE_4BIT(1),.FAT32_ENABLE(1)')
s=s.replace(' wire native_clock;\n','').replace(' tri1 native_cmd,native_d0,native_d1,native_d2,native_d3;\n','')
s=s.replace(' wire [3:0] acode;', ' wire native_clock;tri1 native_cmd,native_d0,native_d1,native_d2,native_d3;\n wire [3:0] acode;')
s=s.replace(".SD_MISO(1'b1),", ".SD_MISO(1'b1),.SD_CLK(native_clock),.SD_CMD(native_cmd),\n .SD_DAT0(native_d0),.SD_DAT1(native_d1),.SD_DAT2(native_d2),.SD_DAT3(native_d3),")
a=s.index(' sd_card_top_native #(');b=s.index(' sd_native_card_model #',a);s=s[:a]+s[b:]
a=s.index(' initial begin\n  // Substitute');b=s.index(' always @(posedge clk)',a);s=s[:a]+s[b:]
s=s.replace('4-bit physical transport/real scheduler', 'formal native profile without force/real SD pins/real scheduler')
(O/'native_integration/tb_sd_native_integrated.v').write_text(s,encoding='utf-8')
print('Prepared real native profile player test; no physical transport force/substitution')
