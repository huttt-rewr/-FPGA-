from pathlib import Path
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
text = (ROOT/'sim/tb_menu_mode_popup.v').read_text()
text = text.replace('tb_menu_mode_popup', 'tb_mode_preview')
text = text.replace('reg pixel_check=0;', 'integer fd=0; reg pixel_check=0;')
text = text.replace('if(pixel_check && od)pixels=pixels+1;', '''if(pixel_check && od)begin
   pixels=pixels+1;
   if(fd!=0)$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
  end''')
text = text.replace('pixel_check=1;', '''if(s==0)begin
     case(m)
      1:fd=$fopen("../reports/mode_popup_20261023/brightness.ppm","wb");
      2:fd=$fopen("../reports/mode_popup_20261023/contrast.ppm","wb");
      3:fd=$fopen("../reports/mode_popup_20261023/play.ppm","wb");
     endcase
     if(fd==0)begin $display("FAILED screenshot");$finish;end
     $fwrite(fd,"P6\\n168 68\\n255\\n");
    end
    pixel_check=1;''')
text = text.replace('pixel_check=0;\n    check', 'pixel_check=0; if(fd!=0)begin $fclose(fd);fd=0;end\n    check')
source = OUT/'tb_mode_preview.v'
source.write_text(text)
work = (OUT/'mode_work').as_posix()
subprocess.run(['J:/win64/vlog.exe', '-work', work, str(source)], cwd=ROOT/'sim', check=True)
log = OUT/'tb_mode_preview.log'
subprocess.run(['J:/win64/vsim.exe', '-c', '-lib', work, 'tb_mode_preview',
                '-do', 'run -all; quit -f', '-l', log.as_posix()], cwd=ROOT/'sim', check=True)
assert 'ALL PASS tb_mode_preview' in log.read_text(errors='replace')
for name in ['brightness', 'contrast', 'play']:
    with Image.open(OUT/(name+'.ppm')) as img:
        assert img.size == (168, 68)
        img.resize((504, 204), Image.Resampling.NEAREST).save(OUT/(name+'.png'))
print('ALL PASS actual RTL preview')
