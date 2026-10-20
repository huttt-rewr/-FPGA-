"""Include default-off extensions in the established pixel/HDMI chain oracle."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[2]
phase=sys.argv[1]
p=root/'sim/tb_board_pipeline.v'
s=p.read_text(encoding='utf-8-sig')
if phase=='phase3':
 assert 'auto_enhance levels' not in s
 s=s.replace('wire [9:0] px,py,ax,ay,gx,gy;',
             'wire [9:0] px,py,ax,ay,gx,gy,aex,aey;wire aev,aed;wire [23:0] aer;')
 old=' transition_pixels fx(clk,rst,gv,gd,gx,gc,'
 assert old in s
 s=s.replace(old,''' auto_enhance levels(clk,rst,gv,gd,gx,gy,gc,1'b0,aev,aed,aex,aey,aer);
 transition_pixels fx(clk,rst,aev,aed,aex,aer,''')
 s=s.replace('ec,gy,mode);','ec,aey,mode);')
 s=s.replace('six full frames, both modes, gamma/bypass,',
             'six full frames, both modes, automatic-level bypass, gamma/bypass,')
elif phase=='phase4':
 assert 'zh_overlay chinese' not in s
 old=' status_osd #(.ENHANCED_UI(1),'
 assert old in s
 s=s.replace(old,''' wire zvs,zde;wire [23:0]zrgb;wire [9:0]zx,zy;
 viewport_coordinates zcoords(clk,rst,cv,cd,mode,zx,zy,,);
 zh_overlay chinese(clk,rst,cv,cd,zx,zy,cc,1'b0,zvs,zde,,,zrgb);
 status_osd #(.ENHANCED_UI(1),''')
 s=s.replace('.vs(cv),.de(cd),.rgb(cc),','.vs(zvs),.de(zde),.rgb(zrgb),')
 s=s.replace('automatic-level bypass,','automatic-level/Chinese bypass,')
else:raise ValueError(phase)
p.write_text(s,encoding='utf-8')
print('Extended actual video chain oracle for',phase)
