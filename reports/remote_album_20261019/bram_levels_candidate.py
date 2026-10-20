"""Prepare/test an equivalent four-cycle synchronous-ROM levels pipeline."""
from pathlib import Path
import subprocess

root=Path(__file__).resolve().parents[2]
out=Path(__file__).resolve().parent/'bram_levels_candidate'
out.mkdir(exist_ok=True)
s=(root/'src/modules/video/auto_enhance.v').read_text()
def change(old,new):
 global s
 assert old in s,old
 s=s.replace(old,new)
change(' wire [15:0] rs,gs,bs;\n auto_enhance_scale rscale(rr,rs),gscale(gr,gs),bscale(br,bs);\n reg [15:0] sR,sG,sB;',
       ' reg [7:0] rangeR,rangeG,rangeB;')
change('sR<=0;sG<=0;sB<=0;', 'rangeR<=0;rangeG<=0;rangeB<=0;')
change('sR<=rs;sG<=gs;sB<=bs;', 'rangeR<=rr;rangeG<=gr;rangeB<=br;')
change(' reg [15:0] scaleR1,scaleG1,scaleB1;', ''' reg [7:0] rangeR1,rangeG1,rangeB1;
 reg [7:0] deltaR2,deltaG2,deltaB2;
 wire [15:0] scaleR2,scaleG2,scaleB2;
 auto_enhance_scale rscale(clk,rangeR1,scaleR2),gscale(clk,rangeG1,scaleG2),bscale(clk,rangeB1,scaleB2);''')
change('scaleR1<=0;scaleG1<=0;scaleB1<=0;',
       'rangeR1<=0;rangeG1<=0;rangeB1<=0;deltaR2<=0;deltaG2<=0;deltaB2<=0;')
change('scaleR1<=sR;scaleG1<=sG;scaleB1<=sB;', 'rangeR1<=rangeR;rangeG1<=rangeG;rangeB1<=rangeB;')
change('bypass1<={sR==0,sG==0,sB==0};', 'bypass1<={rangeR==0,rangeG==0,rangeB==0};')
change('productR<=deltaR*scaleR1;productG<=deltaG*scaleG1;productB<=deltaB*scaleB1;',
       'deltaR2<=deltaR;deltaG2<=deltaG;deltaB2<=deltaB;\n   productR<=deltaR2*scaleR2;productG<=deltaG2*scaleG2;productB<=deltaB2*scaleB2;')
change('''   rgb3<=!en2?rgb2:{bypass2[2]?rgb2[23:16]:saturate(productR),
           bypass2[1]?rgb2[15:8]:saturate(productG),bypass2[0]?rgb2[7:0]:saturate(productB)};
   out_vs<=v3;out_de<=d3;out_x<=x3;out_y<=y3;out_rgb<=d3?rgb3:24'd0;''',
'''   rgb3<=rgb2;
   out_vs<=v3;out_de<=d3;out_x<=x3;out_y<=y3;
   out_rgb<=!d3?24'd0:!en3?rgb3:{bypass3[2]?rgb3[23:16]:saturate(productR),
           bypass3[1]?rgb3[15:8]:saturate(productG),bypass3[0]?rgb3[7:0]:saturate(productB)};''')
s=s.replace('// Previous-frame per-channel automatic levels. Four fully registered stages.',
'''// Previous-frame per-channel automatic levels. Four fully registered stages.
// 1 delta/range, 2 synchronous reciprocal ROM, 3 product, 4 rounding/output.
// The three ROMs trade spare BRAM for less LUT and local routing pressure.''')
(out/'auto_enhance.v').write_text(s,encoding='utf-8')
rom='''// Q8 round(255*256/r), r=0 is bypass. Embedded synchronous ROM.
module auto_enhance_scale(input clk,input [7:0] range_value,output reg [15:0] scale);
 (* ram_style="bram" *) reg [15:0] mem[0:255];
 initial begin
'''
for i in range(256):
 v=0 if i==0 else (65280+i//2)//i
 rom+=f"  mem[{i}]=16'h{v:04x};\n"
rom+=' end\n always @(posedge clk)scale<=mem[range_value];\nendmodule\n'
(out/'auto_enhance_scale.v').write_text(rom,encoding='utf-8')
with (out/'test.log').open('wb') as log:
 def run(args):subprocess.run(args,cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
 run(['J:/win64/vlib.exe','rom_work'])
 run(['J:/win64/vlog.exe','-work','rom_work','auto_enhance.v','auto_enhance_scale.v',str(root/'sim/tb_auto_enhance.v')])
 run(['J:/win64/vsim.exe','-c','-lib','rom_work','tb_auto_enhance','-do','run -all; quit -f'])
text=(out/'test.log').read_text(errors='replace')
assert 'ALL PASS' in text and 'FAILED' not in text,text[-2000:]
print('ALL PASS independent synchronous-ROM levels candidate; exact four-cycle reference')
