from pathlib import Path
import subprocess,re
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
M=Path('J:/win64');W=O/'menu_work'
if not W.exists():subprocess.run([str(M/'vlib.exe'),str(W)],check=True)
files=['src/modules/osd/zh_font_rom.v','src/modules/osd/menu_overlay.v',
       'src/modules/control/picture_controls.v','src/modules/control/boot_media_select.v',
       'sim/tb_menu_media.v','sim/tb_menu_media_pixels.v','sim/tb_chinese_menu.v',
       'sim/tb_menu_overlay.v','sim/tb_menu_popup.v']
popup=(R/'sim/tb_menu_popup.v').read_text().replace('module tb_menu_popup;', 'module tb_menu_popup_page2;')
popup=popup.replace('.VGA_CLOCK_HZ(16)', '.MEDIA_MENU(1),.VGA_CLOCK_HZ(16)')
popup=popup.replace('.mode_800(mode)', ".mode_800(mode),.menu_page(1'b1)")
popup=popup.replace('ALL PASS tb_menu_popup:', 'ALL PASS tb_menu_popup_page2:')
(O/'tb_menu_popup_page2.v').write_text(popup)
subprocess.run([str(M/'vlog.exe'),'-work',str(W),*[str(R/p) for p in files],str(O/'tb_menu_popup_page2.v')],cwd=R/'sim',check=True)
for tb in ['tb_menu_media','tb_menu_media_pixels','tb_chinese_menu','tb_menu_overlay','tb_menu_popup','tb_menu_popup_page2']:
 log=O/(tb+'.log')
 p=subprocess.run([str(M/'vsim.exe'),'-c','-lib',W.as_posix(),tb,'-do','run -all; quit -f','-l',log.as_posix()],cwd=R/'sim')
 s=log.read_text(errors='replace')
 assert p.returncode==0 and 'ALL PASS '+tb in s and not re.search(r'FAILED|\*\* Fatal',s),tb
 print('VERIFIED '+tb,flush=True)
print('ALL PASS menu media focused',flush=True)
