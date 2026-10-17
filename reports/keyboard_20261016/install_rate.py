"""Install stage-four consumers only after mode-stage reports are frozen."""
from pathlib import Path
import re,shutil
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
for source,target in (
 ('fps_control.v','src/modules/control/fps_control.v'),
 ('tb_fps_control.v','sim/tb_fps_control.v'),
 ('tb_rate_player.v','sim/tb_rate_player.v'),
 ('sd_card_bmp_rate.v','src/modules/bmp/sd_card_bmp.v'),
 ('top_rate_candidate.v','src/top.v'),
 ('status_osd_rate.v','src/modules/osd/status_osd.v'),
 ('tb_file_osd_rate.v','sim/tb_file_osd.v'),
 ('tb_audio_stream_flush_mute.v','sim/tb_audio_stream_flush.v')):
 shutil.copy2(O/source,R/target)
source='src/modules/control/fps_control.v'
p=R/'scripts/design_files.txt';s=p.read_text(encoding='utf-8')
assert source not in s;p.write_text(s+source+'\n',encoding='utf-8')
for name in ('video_improve.al','src/td_project/video_improve.al'):
 p=R/name;s=p.read_text(encoding='utf-8')
 m=re.search(r'(?m)^\s*<File Path="[^"\n]*switch_controls\.v">[\s\S]*?</File>',s);assert m,name
 block=m.group().replace('switch_controls.v','fps_control.v')
 block=re.sub(r'CompileOrder" Val="\d+"','CompileOrder" Val="69"',block)
 p.write_text(s[:m.end()]+'\n'+block+s[m.end():],encoding='utf-8')
p=R/'scripts/run_tests.ps1';s=p.read_text(encoding='utf-8')
needle=" $mergeTests += @('tb_video_mode_control','tb_mode_reload')"
assert needle in s;s=s.replace(needle,needle+"\n $mergeTests += @('tb_fps_control','tb_rate_player')")
p.write_text(s,encoding='utf-8')
print('Installed target cadence consumer, independent rate CDC and TARGET/L OSD, with two regressions')
