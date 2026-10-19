import re
from pathlib import Path
p=Path('reports/routed_timing_paths20.txt');s=p.read_text()
for m in re.finditer(r'Slack\s*:\s*(-?[\d.]+)ns\s+Begin Point\s*:\s*([^\n]+)\s+End Point\s*:\s*([^\n]+)\s+Check Type\s*:\s*(\w+)',s):
 if float(m[1])<0:print(m[1],m[4],m[2].split(' (')[0],'=>',m[3].split(' (')[0])
