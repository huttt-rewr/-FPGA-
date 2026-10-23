from pathlib import Path
import subprocess,re
O=Path(__file__).resolve().parent;R=O.parents[1];M=Path('J:/win64');W=O/'reset_work'
if not W.exists():subprocess.run([(M/'vlib.exe').as_posix(),W.as_posix()],check=True)
files=['src/modules/common/board_supervisor.v','src/modules/common/reset_sync.v',
 'src/modules/control/picture_controls.v','src/modules/control/boot_media_select.v']
subprocess.run([(M/'vlog.exe').as_posix(),'-work',W.as_posix(),*[str(R/p) for p in files],str(O/'tb_key1_reset.v')],cwd=R,check=True)
log=O/'tb_key1_reset.log'
p=subprocess.run([(M/'vsim.exe').as_posix(),'-c','-lib',W.as_posix(),'tb_key1_reset',
 '-do','run -all; quit -f','-l',log.as_posix()],cwd=R/'sim')
s=log.read_text(errors='replace')
assert p.returncode==0 and 'ALL PASS tb_key1_reset' in s and not re.search(r'FAILED|\*\* Fatal',s)
print('ALL PASS physical key/reset focused')
