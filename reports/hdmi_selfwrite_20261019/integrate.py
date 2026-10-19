"""Apply only the approved top wiring and source registration changes."""
from pathlib import Path
import re

r=Path(__file__).resolve().parents[2]
p=r/'src/top.v'
t=p.read_text(encoding='utf-8-sig')
assert t.count(') u_hdmi_1_4b_transmitter_core_wrapper(')==1
t=t.replace('wire vga_ready,svga_ready;', 'wire svga_ready;')
t=t.replace('assign axis_s_ready=mode_video?svga_ready:vga_ready;',
            "assign axis_s_ready=mode_video?svga_ready:1'b1;")
begin=t.index('hdmi_1_4b_transmitter_core_wrapper #(')
end=t.index('\nhdmi_1_4b_transmitter_core_wrapper #(',begin+1)
t=t[:begin]+'''// Video-only VGA consumes the final composited pixel stream directly.
hdmi_tmds_vga u_hdmi_640(
    .clk(video_clk),.rst(rst_vga),.vs(game_vs),.de(game_de),.rgb(game_rgb),
    .ch0(vga_ch0),.ch1(vga_ch1),.ch2(vga_ch2),.clk_ch(vga_clk)
);
// EDID runs on the permanent boot clock and survives runtime mode changes.
edid_i2c u_edid_i2c(
    .clk(boot_clk),.rst(rst_boot),.start(edid_trig),
    .scl(HDMI_DDC_SCL),.sda(HDMI_DDC_SDA),
    .valid(edid_valid),.data(edid_data),.busy(),.done(),.error()
);
''' + t[end:]
# Preserve all other resets, muxes, sampling, status, and the SVGA/PHY blocks.
p.write_text(t,encoding='utf-8',newline='\n')
new=['src/modules/hdmi/tmds_encoder.v','src/modules/hdmi/hdmi_tmds_vga.v',
     'src/modules/hdmi/edid_i2c.v']
p=r/'scripts/design_files.txt'
t=p.read_text();p.write_text(t.rstrip()+'\n'+'\n'.join(new)+'\n',newline='\n')
for name,prefix in [('video_improve.al',''),('src/td_project/video_improve.al','../../')]:
    p=r/name;t=p.read_text(encoding='utf-8-sig')
    orders=[int(x) for x in re.findall('Name="CompileOrder" Val="(\\d+)"',t)]
    extra=''
    for i,path in enumerate(new,max(orders)+1):
        extra+=f'''            <File Path="{prefix}{path}">
                <FileInfo>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="{i}"/>
                </FileInfo>
            </File>
'''
    assert t.count('        </Verilog>')==1
    p.write_text(t.replace('        </Verilog>',extra+'        </Verilog>'),encoding='utf-8',newline='\n')
p=r/'scripts/run_tests.ps1';t=p.read_text()
t=t.replace(" $files += @($mergeTests |", " $files += @('../src/modules/hdmi/tmds_encoder.v','../src/modules/hdmi/hdmi_tmds_vga.v','../src/modules/hdmi/edid_i2c.v')\n $mergeTests += @('tb_tmds_encoder','tb_hdmi_tmds_vga','tb_edid_i2c')\n $files += @($mergeTests |")
p.write_text(t,newline='\n')
print('Integrated VGA+DDC; retained encrypted SVGA and shared PHY/IP source')
