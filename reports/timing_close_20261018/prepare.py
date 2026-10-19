from pathlib import Path
import subprocess

root=Path(__file__).resolve().parents[2]
tb=root/'sim/tb_fps_equivalence.v'
original=subprocess.check_output(['git','show','d34c488:src/modules/control/fps_control.v'],cwd=root).decode('utf-8')
text=tb.read_text(encoding='utf-8')
assert 'module fps_control_reference' not in text
tb.write_text(text+'\n'+original.replace('module fps_control #(','module fps_control_reference #('),encoding='utf-8')
print('Appended exact baseline FPS reference; only module name changed')
