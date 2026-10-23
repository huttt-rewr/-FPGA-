from pathlib import Path
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
TOOLS=Path('J:/win64')
WORK=OUT/'spectrum_work'
subprocess.run([sys.executable,str(ROOT/'scripts/make_spectrum_vectors.py')],check=True)
if not WORK.exists():
 subprocess.run([str(TOOLS/'vlib.exe'),str(WORK)],check=True)
tests=sys.argv[1:] or ['tb_spectrum_fft']
files=list((ROOT/'src/modules/audio').glob('spectrum_*.v'))
files+=list((ROOT/'src/modules/video').glob('music_*.v'))
files+=[ROOT/'src/modules/video/audio_visualizer.v']
files += [ROOT/'sim'/(tb+'.v') for tb in tests]
result=subprocess.run([str(TOOLS/'vlog.exe'),'-work',str(WORK),*[str(p) for p in files]],
                      cwd=ROOT/'sim',stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(OUT/'focused_compile.log').write_bytes(result.stdout)
if result.returncode:
 print(result.stdout.decode(errors='replace'));raise SystemExit(result.returncode)
for tb in tests:
 log=OUT/(tb+'.log')
 result=subprocess.run([str(TOOLS/'vsim.exe'),'-c','-lib',WORK.as_posix(),tb,
                        '-do','run -all; quit -f','-l',log.as_posix()],cwd=ROOT/'sim',
                       stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 text=log.read_text(errors='replace') if log.exists() else result.stdout.decode(errors='replace')
 if result.returncode or re.search(r'FAILED|\*\* Fatal',text) or 'ALL PASS '+tb not in text:
  print(text);raise SystemExit(f'FAILED {tb}')
 print('\n'.join(line for line in text.splitlines() if 'ALL PASS' in line),flush=True)
