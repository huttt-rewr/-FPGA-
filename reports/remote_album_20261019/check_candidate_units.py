"""Exercise isolated candidate algorithms without changing production gate inputs."""
from pathlib import Path
import subprocess,shutil
task=Path(__file__).resolve().parent
root=task.parents[1]
unit=task/'candidate_units'
for sub in ('src/modules/video','src/modules/osd','src/modules/control','sim','reports/remote_album_20261019'):
 (unit/sub).mkdir(parents=True,exist_ok=True)
def run_fragment(name,stop):
 source=(task/name).read_text(encoding='utf-8')
 source=source.split(stop,1)[0]
 source=source.replace('root=Path(__file__).resolve().parents[2]', 'root=Path('+repr(str(unit))+')')
 exec(compile(source,str(task/name),'exec'),{'__file__':str(task/name)})
run_fragment('phase3_prepare.py',"edit('src/modules/control/player_control.v'")
run_fragment('phase3_test_prepare.py',"p=root/'sim/tb_remote_uart.v'")
run_fragment('phase4_prepare.py',"edit('src/modules/control/player_control.v'")
run_fragment('phase4_tests_prepare.py',"p=root/'sim/tb_remote_uart.v'")
# Apply only the larger-clock edit to an isolated copy for pipeline/oracle tests.
caption=unit/'src/modules/osd/caption_overlay.v'
shutil.copy2(root/'src/modules/osd/caption_overlay.v',caption)
source=(task/'phase4_prepare.py').read_text(encoding='utf-8')
start=source.index("edit('src/modules/osd/caption_overlay.v'")
end=source.index('# Positional compatibility',start)
def edit(path,pairs):
 p=unit/path;s=p.read_text(encoding='utf-8-sig')
 for old,new in pairs:
  assert old in s,(path,old);s=s.replace(old,new)
 p.write_text(s,encoding='utf-8')
exec(compile(source[start:end],str(task/'phase4_prepare.py'),'exec'),{'edit':edit})
for rel in ('src/modules/video/video_coordinates.v','src/modules/osd/osd_char_rom.v'):
 shutil.copy2(root/rel,unit/rel)
modelsim=Path('J:/win64')
work=unit/'work'
subprocess.run([str(modelsim/'vlib.exe'),str(work)],check=True)
files=[str(p) for sub in ('src/modules/video','src/modules/osd','src/modules/control','sim') for p in (unit/sub).glob('*.v')]
with (unit/'compile.log').open('wb') as log:
 subprocess.run([str(modelsim/'vlog.exe'),'-work',str(work),*files],stdout=log,stderr=subprocess.STDOUT,check=True)
for tb in ('tb_auto_enhance','tb_album_timer','tb_zh_overlay','tb_album_clock'):
 with (unit/(tb+'_console.log')).open('wb') as console:
  result=subprocess.run([str(modelsim/'vsim.exe'),'-c','-lib','../work',tb,'-do','run -all; quit -f','-l',str(unit/(tb+'.log'))],
                        cwd=unit/'sim',stdout=console,stderr=subprocess.STDOUT)
 log=(unit/(tb+'.log')).read_text(errors='replace')
 assert result.returncode==0 and 'ALL PASS' in log and 'FAILED' not in log,tb
 print('ISOLATED CANDIDATE PASS',tb,flush=True)
