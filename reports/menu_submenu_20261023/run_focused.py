from pathlib import Path
import re
import subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
M=Path('J:/win64')
source=(ROOT/'sim/tb_menu_overlay.v').read_text()
svga=source.replace('module tb_menu_overlay;','module tb_menu_overlay_svga;')
svga=svga.replace(' menu_overlay dut(',
 ' wire [9:0] draw_x,draw_y; viewport_coordinates coordinates(clk,rst,vs,de,1\'b1,draw_x,draw_y,,);\n menu_overlay dut(')
svga=svga.replace('.x(x),.y(y)','.x(draw_x),.y(draw_y)').replace('.mode_800(1\'b0)','.mode_800(1\'b1)')
svga=svga.replace('640 480','800 600').replace('yy<480','yy<600').replace('xx<640','xx<800')
svga=svga.replace('x=xx;y=yy;','x=xx*4/5;y=yy*4/5;').replace('ticks=50000000','ticks=80000000')
svga=svga.replace('.ppm','_svga.ppm').replace('pixels==5529600','pixels==8640000').replace('bypass==614400','bypass==960000')
svga=svga.replace('ALL PASS tb_menu_overlay:', 'ALL PASS tb_menu_overlay_svga:').replace('#70000000;','#100000000;')
(OUT/'tb_menu_overlay_svga.v').write_text(svga,encoding='utf-8')
work=OUT/'menu_work'
if not work.exists():subprocess.run([str(M/'vlib.exe'),work.as_posix()],cwd=ROOT/'sim',check=True)
files=['src/modules/osd/zh_font_rom.v','src/modules/osd/menu_overlay.v',
       'src/modules/video/video_coordinates.v','src/modules/control/picture_controls.v',
       'sim/tb_chinese_menu.v','sim/tb_menu_overlay.v','sim/tb_menu_popup.v']
subprocess.run([str(M/'vlog.exe'),'-work',work.as_posix(),
               *[(ROOT/p).as_posix() for p in files],(OUT/'tb_menu_overlay_svga.v').as_posix()],cwd=ROOT/'sim',check=True)
for tb in ('tb_chinese_menu','tb_menu_popup','tb_menu_overlay','tb_menu_overlay_svga'):
 log=OUT/(tb+'.log')
 result=subprocess.run([str(M/'vsim.exe'),'-c','-lib',work.as_posix(),tb,
                        '-do','run -all; quit -f','-l',log.as_posix()],cwd=ROOT/'sim')
 text=log.read_text(errors='replace')
 assert result.returncode==0 and 'ALL PASS '+tb in text and not re.search(r'FAILED|\*\* Fatal',text),tb
 print('VERIFIED '+tb,flush=True)
print('ALL PASS menu_submenu focused',flush=True)
