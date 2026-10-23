from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
target = OUT/'bitstream'
target.mkdir(exist_ok=True)
reference = ROOT/'reports/menu_media_20261023/bitstream'
for name in ['generate_candidate.py', 'generate_candidate.tcl']:
    text = (reference/name).read_text(encoding='utf-8')
    text = text.replace('video_improve_menu_media_20261023.bit', 'video_improve_mode_popup_20261023.bit')
    text = text.replace('media-menu', 'shortcut-mode-popup')
    (target/name).write_text(text, encoding='utf-8')
print('Prepared verified candidate generation scripts')
