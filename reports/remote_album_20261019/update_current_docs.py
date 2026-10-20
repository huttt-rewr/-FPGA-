from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[2]
task=Path(__file__).resolve().parent
records={p:json.loads((task/(p+'_validation.json')).read_text()) for p in ('phase1','phase2','phase3','phase4') if (task/(p+'_validation.json')).exists()}
latest=list(records)[-1]
r=records[latest];m=r['timing_ns']
complete=latest=='phase4'
state='四阶段已通过静态、全量仿真与内部物理门禁' if complete else latest+'已通过内部门禁，后续阶段未完成'
metrics=f"SWNS {m['SWNS']:+.3f}ns、HWNS {m['HWNS']:+.3f}ns，STNS/HTNS均0"
note=f"> **2026-10-21 UART/红外/画质/相册：{state}；没有本轮新bit，未上板。** {r['tests']}项ModelSim通过；{metrics}。默认保留KEY/SW/PS/2；新增选项默认关闭。当前用法与限制见 [本轮操作手册](UART_IR_ALBUM_20261020.md)。历史数值只代表各自冻结版本，不能验收当前源码；没有整体+0.5ns签核。"
for name in ('README.md','docs/USER_GUIDE.md','docs/KEY_SW_OPERATION.md','docs/BUILD_STATUS.md','docs/README.md'):
 p=root/name;s=p.read_text(encoding='utf-8-sig')
 s=re.sub(r'^> \*\*2026-10-(?:20|21)(?: UART/|进度：).*?(?:\n|$)', '',s,flags=re.M)
 first,rest=s.split('\n',1)
 n=note.replace('(UART_IR_ALBUM_20261020.md)','(docs/UART_IR_ALBUM_20261020.md)') if name=='README.md' else note
 p.write_text(first+'\n\n'+n+'\n'+rest.lstrip('\n'),encoding='utf-8')
p=root/'docs/UART_IR_ALBUM_20261020.md';s=p.read_text(encoding='utf-8')
s=re.sub(r'^(?:当前为分阶段开发记录，|截至2026-10-(?:20|21)：).*$',f'截至2026-10-21：{state}；{r["tests"]}项回归，{metrics}。没有本轮新bit、没有实板验收；冻结记录见下方。',s,flags=re.M)
for phase,title in (('phase3','上一帧统计的自动色阶'),('phase4','独立五秒相册、大字时钟与中文点阵')):
 if phase in records:
  rec=records[phase];mm=rec['timing_ns'];index=phase[-1]
  line=f"{index}. {title}：已接入、默认关闭；{rec['tests']}项回归、综合布局布线和最终内部STA通过，SWNS {mm['SWNS']:+.3f}ns、HWNS {mm['HWNS']:+.3f}ns，TNS均0。"
  s=re.sub(r'^'+index+r'\. .*$',lambda _:line,s,count=1,flags=re.M)
s=s.replace('（当前源码已接入，阶段三物理验收中）','')
if complete:
 s=s.split('\n## 四阶段冻结验收记录',1)[0].rstrip()+'\n'
 s+='\n## 四阶段冻结验收记录\n\n| 阶段 | 回归数 | SWNS(ns) | HWNS(ns) | 证据 |\n|---|---:|---:|---:|---|\n'
 for phase,rec in records.items():
  mm=rec['timing_ns'];s+=f"| {phase} | {rec['tests']} | {mm['SWNS']:+.3f} | {mm['HWNS']:+.3f} | reports/remote_album_20261019/{phase}_pass/ |\n"
p.write_text(s,encoding='utf-8')
print('Updated current document headers from',latest,metrics)
