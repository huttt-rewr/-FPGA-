from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[2]
here=Path(__file__).resolve().parent
original=subprocess.check_output(['git','show','d34c488:src/modules/sd/sd_fat32.v'],cwd=root).decode('utf-8')
text=(here/'tb_fat32_schedule_candidate.v').read_text(encoding='utf-8')
(root/'sim/tb_fat32_schedule.v').write_text(text+'\n'+original.replace('module sd_fat32 #(','module sd_fat32_reference #('),encoding='utf-8')
print('Installed schedule test with exact baseline FAT32 reference')
