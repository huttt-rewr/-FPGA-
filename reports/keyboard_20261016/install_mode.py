"""Install only after phase-two regression/STA are frozen and accepted."""
from pathlib import Path
import shutil,re
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
shutil.copy2(OUT/'video_mode_control.v',ROOT/'src/modules/video/video_mode_control.v')
shutil.copy2(OUT/'tb_video_mode_control.v',ROOT/'sim/tb_video_mode_control.v')
shutil.copy2(OUT/'tb_mode_reload.v',ROOT/'sim/tb_mode_reload.v')
shutil.copy2(OUT/'top_mode_candidate.v',ROOT/'src/top.v')
source='src/modules/video/video_mode_control.v'
p=ROOT/'scripts/design_files.txt';s=p.read_text(encoding='utf-8')
if source not in s:s+=source+'\n'
p.write_text(s,encoding='utf-8')
for name,prefix in [('video_improve.al',''),('src/td_project/video_improve.al','../../')]:
 p=ROOT/name;s=p.read_text(encoding='utf-8')
 # Reuse the exact TD XML file record for an existing same-directory module.
 if 'video_mode_control.v' not in s:
  match=re.search(r'(?m)^\s*<File Path="[^"\n]*edid_display_mode\.v">[\s\S]*?</File>',s)
  assert match,name
  end=match.end()
  block=match.group().replace('edid_display_mode.v','video_mode_control.v')
  block=re.sub(r'CompileOrder" Val="\d+"','CompileOrder" Val="68"',block)
  assert '<File ' in block and 'video_mode_control' in block
  s=s[:end]+'\n'+block+s[end:]
 p.write_text(s,encoding='utf-8')
p=ROOT/'scripts/run_tests.ps1';s=p.read_text(encoding='utf-8')
needle=" $mergeTests += @('tb_fat32_indexed','tb_indexed_player','tb_file_osd')"
assert needle in s;s=s.replace(needle,needle+"\n $mergeTests += @('tb_video_mode_control','tb_mode_reload')")
p.write_text(s,encoding='utf-8')
print('Installed runtime mode controller and two new regressions')
