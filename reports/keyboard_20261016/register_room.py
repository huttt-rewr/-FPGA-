from pathlib import Path
import re
R=Path(__file__).resolve().parents[2]
source='src/modules/audio/audio_fifo_room.v'
p=R/'scripts/design_files.txt';s=p.read_text(encoding='utf-8');assert source not in s
p.write_text(s+source+'\n',encoding='utf-8')
for name in ('video_improve.al','src/td_project/video_improve.al'):
 p=R/name;s=p.read_text(encoding='utf-8')
 m=re.search(r'(?m)^\s*<File Path="[^"\n]*audio_effects_stream\.v">[\s\S]*?</File>',s);assert m,name
 block=m.group().replace('audio_effects_stream.v','audio_fifo_room.v')
 block=re.sub(r'CompileOrder" Val="\d+"','CompileOrder" Val="67"',block)
 p.write_text(s[:m.end()]+'\n'+block+s[m.end():],encoding='utf-8')
p=R/'scripts/run_tests.ps1';s=p.read_text(encoding='utf-8')
s=s.replace("'tb_audio_stream_flush')", "'tb_audio_stream_flush','tb_audio_fifo_room')")
p.write_text(s,encoding='utf-8')
print('Registered PCM admission and overflow/order regression')
