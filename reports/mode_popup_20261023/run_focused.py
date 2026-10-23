from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
TOOLS = Path('J:/win64')
WORK = OUT/'mode_work'
if not WORK.exists():
    subprocess.run([str(TOOLS/'vlib.exe'), str(WORK)], check=True)
files = ['src/modules/common/cdc_snapshot.v', 'src/modules/osd/zh_font_rom.v',
         'src/modules/osd/menu_overlay.v', 'src/modules/control/picture_controls.v',
         'src/modules/control/boot_media_select.v', 'sim/tb_menu_mode_popup.v',
         'sim/tb_menu_popup.v', 'sim/tb_menu_overlay.v', 'sim/tb_menu_media_pixels.v',
         'sim/tb_chinese_menu.v', 'sim/tb_menu_media.v']
subprocess.run([str(TOOLS/'vlog.exe'), '-work', str(WORK),
                *[str(ROOT/p) for p in files]], cwd=ROOT/'sim', check=True)
for tb in ['tb_menu_mode_popup', 'tb_menu_popup', 'tb_menu_overlay',
           'tb_menu_media_pixels', 'tb_chinese_menu', 'tb_menu_media']:
    log = OUT/(tb+'.log')
    result = subprocess.run([str(TOOLS/'vsim.exe'), '-c', '-lib', WORK.as_posix(), tb,
                             '-do', 'run -all; quit -f', '-l', log.as_posix()], cwd=ROOT/'sim')
    text = log.read_text(errors='replace')
    if result.returncode or re.search(r'FAILED|\*\* Fatal', text) or 'ALL PASS '+tb not in text:
        raise RuntimeError(f'{tb} failed: {log}')
    print('VERIFIED '+tb, flush=True)
print('ALL PASS mode popup focused')
