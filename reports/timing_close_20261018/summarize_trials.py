from pathlib import Path
import json,re
h=Path('reports/timing_close_20261018')
lines=['# 本轮独立试验结果（工作记录）','','每轮都保存了自己的输入、原始报告和日志，以下为已冻结结果。最终所选版本以RESULT.md为准。','','| 轮次 | SWNS | STNS | HWNS | HTNS | 回归 | 物理LUT |','|---|---:|---:|---:|---:|---:|---:|']
for n in range(1,8):
 p=h/f'build{n}'/'paths.json'
 if not p.exists():continue
 d=json.loads(p.read_text());t=d.get('timing_ns',{});res=d.get('resources',{}).get('physical_area.txt',{})
 lines.append(f"| build{n} | {t.get('SWNS','—')} | {t.get('STNS','—')} | {t.get('HWNS','—')} | {t.get('HTNS','—')} | {d.get('regression_count','未冻结')} | {res.get('lut','—')} |")
(h/'TRIALS.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('\n'.join(lines))
