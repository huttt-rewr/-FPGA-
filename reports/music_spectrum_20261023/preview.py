from pathlib import Path
import subprocess
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
WORK=OUT/'spectrum_work'
TOOLS=Path('J:/win64')
subprocess.run([str(TOOLS/'vlog.exe'),'-work',str(WORK),str(OUT/'tb_music_preview.v')],cwd=ROOT/'sim',check=True)
log=OUT/'tb_music_preview.log'
result=subprocess.run([str(TOOLS/'vsim.exe'),'-c','-lib',WORK.as_posix(),'tb_music_preview',
                       '-do','run -all; quit -f','-l',log.as_posix()],cwd=ROOT/'sim',stdout=subprocess.PIPE)
assert result.returncode==0 and 'ALL PASS tb_music_preview' in log.read_text(errors='replace')
with Image.open(OUT/'rtl_preview.ppm') as image:
 assert image.size==(640,480)
 image.save(OUT/'rtl_preview.png')
print('ALL PASS actual RTL preview:',OUT/'rtl_preview.png')
