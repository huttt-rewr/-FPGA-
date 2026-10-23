"""Verify the real menu pipeline at both output sizes; preserve screenshots."""
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
MODELSIM=Path('J:/win64')
source=(ROOT/'sim/tb_menu_overlay.v').read_text()
svga=source.replace('module tb_menu_overlay;','module tb_menu_overlay_svga;')
svga=svga.replace(' menu_overlay dut(clk,rst,vs,de,x,y,',
    ' wire [9:0] draw_x,draw_y; viewport_coordinates coordinates(clk,rst,vs,de,1\'b1,draw_x,draw_y,,);\n menu_overlay dut(clk,rst,vs,de,draw_x,draw_y,')
svga=svga.replace('640 480','800 600').replace('yy<480','yy<600').replace('xx<640','xx<800')
svga=svga.replace('x=xx;y=yy;','x=xx*4/5;y=yy*4/5;')
svga=svga.replace('menu_edit.ppm','menu_edit_svga.ppm').replace('menu_contrast.ppm','menu_contrast_svga.ppm')
svga=svga.replace('pixels==3072000','pixels==4800000').replace('bypass==614400','bypass==960000')
svga=svga.replace('ALL PASS tb_menu_overlay:', 'ALL PASS tb_menu_overlay_svga:')
svga=svga.replace('FAILED tb_menu_overlay errors=','FAILED tb_menu_overlay_svga errors=')
svga=svga.replace('#40000000;','#60000000;')
(OUT/'tb_menu_overlay_svga.v').write_text(svga,encoding='utf-8')
work=OUT/'menu_work'
if not work.exists():
    subprocess.run([str(MODELSIM/'vlib.exe'),work.as_posix()],cwd=ROOT/'sim',check=True)
files=[ROOT/'src/modules/osd/zh_font_rom.v',ROOT/'src/modules/osd/menu_overlay.v',
       ROOT/'src/modules/video/video_coordinates.v',ROOT/'sim/tb_menu_overlay.v',
       OUT/'tb_menu_overlay_svga.v']
subprocess.run([str(MODELSIM/'vlog.exe'),'-work',work.as_posix(),
                *[p.as_posix() for p in files]],cwd=ROOT/'sim',check=True)
for tb in ('tb_menu_overlay','tb_menu_overlay_svga'):
    log=OUT/(tb+'.log')
    result=subprocess.run([str(MODELSIM/'vsim.exe'),'-c','-lib',work.as_posix(),tb,
                           '-do','run -all; quit -f','-l',log.as_posix()],cwd=ROOT/'sim')
    text=log.read_text(errors='replace')
    assert result.returncode==0 and 'ALL PASS '+tb in text and not re.search(r'FAILED|\*\* Fatal',text),tb
    print('VERIFIED '+tb,flush=True)
print('ALL PASS menu_smooth_left VGA/SVGA',flush=True)
