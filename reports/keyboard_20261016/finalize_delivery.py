"""Audit final candidate and publish its exact bit/report/source identities."""
from pathlib import Path
import hashlib,json,re,subprocess,sys
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
stage,label=sys.argv[1:3]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
v=json.loads((O/(stage+'_validation.json')).read_text())
b=json.loads((O/(label+'_bit_manifest.json')).read_text())
assert v['regression_passed']==80 and v['build_status']=='completed'
assert b['stage']==stage and not b['programmed'] and not b['board_signoff']
assert b['sha256']==sha(R/b['bit'])
for n,h in v['sources'].items():assert sha(R/n)==h,n
assert len(b['timing_ns'])==4 and all(x>=0 for x in b['timing_ns'].values())
for delay in (0,14):
 text=(O/f'highspeed_final_delay{delay}.log').read_text(encoding='utf-8')
 assert 'ALL PASS tb_sd_highspeed' in text and not re.search(r'FAILED|FAIL highspeed|\*\* (Error|Fatal)',text)
 assert '8192B/36672 host cycles = 22.338569 MB/s' in text
protected=['src/modules/sd/sd_fat32.v','src/modules/sd/sd_read_arbiter.v','src/modules/bmp/bmp_read.v','src/modules/audio/audio_wav.v','src/modules/video/bmp_scale_loader.v']
subprocess.run(['git','diff','--exit-code','7ea1d19','--',*protected],cwd=R,check=True)
assert v['status70_unchanged']
names=['README.md','docs/USER_GUIDE.md','docs/SOURCE_MAP.md','docs/KEYBOARD_USAGE_20261016.md',
 'docs/KEYBOARD_REMAINING_20261016.md','docs/MEDIA_INDEX_20261016.md',
 'docs/CONNECTION_AND_USAGE.md','docs/SD_NATIVE_4BIT_20261016.md','docs/BUILD_STATUS.md']
# Remove superseded current-status banners from otherwise current manuals.
for n in ('docs/USER_GUIDE.md','docs/BOARD_TIMING.md','docs/ROADMAP_KEYBOARD_MEDIA.md'):
 p=R/n;text=p.read_text(encoding='utf-8')
 text=re.sub(r'^> 2026-10-17当前：[^\n]*\n\n','',text,flags=re.M)
 p.write_text(text,encoding='utf-8')
timing=b['timing_ns']
note=f'''## 本轮候选bit（尚未下载）

[video_improve_{label}.bit](../{Path(b['bit']).as_posix()})，{b['bytes']}字节；SHA-256：`{b['sha256']}`。

源码提交`{b['source_commit']}`，输入与80项回归绑定至[{stage}_validation.json](../reports/keyboard_20261016/{stage}_validation.json)。候选在同一TD实现会话内重新布局布线、核查非负时序后导出；该会话SWNS **{timing['SWNS']:+.3f}ns**、HWNS **{timing['HWNS']:+.3f}ns**、TNS0。[候选清单](../reports/keyboard_20261016/{label}_bit_manifest.json)、[该会话STA](../reports/keyboard_20261016/{label}_bit_timing_summary.txt)。

仅为内部STA通过的实板待验候选，未物理下载、未写卡、未实测出图/出声/吞吐、未签核SD/HDMI外部IO。历史bit不含本轮功能。内部removal不是HDMI管脚hold，未达到整体+0.5ns。\n'''
p=R/'docs/BUILD_STATUS.md';text=p.read_text(encoding='utf-8')
text=re.sub(r'\n## 本轮候选bit（尚未下载）\n.*?(?=\n## |\Z)','\n',text,flags=re.S)
h,_,body=text.partition('\n')
p.write_text(h+'\n\n'+note+'\n'+body.lstrip(),encoding='utf-8')
p=R/'README.md';text=p.read_text(encoding='utf-8').split('\n## 本轮候选文件\n',1)[0]
text+='\n## 本轮候选文件\n\n内部STA通过的[候选bit]('+Path(b['bit']).as_posix()+')已导出，尚未下载或实板验收。校验值、对应源码及实际时序见[构建状态](docs/BUILD_STATUS.md)。\n'
p.write_text(text,encoding='utf-8')
errors=[];links=0;historical_missing=[]
history=R/'docs/BUILD_STATUS.md';text=history.read_text(encoding='utf-8')
def historical_link(match):
 label,target=match.groups()
 old=re.match(r'\.\./reports/(audio_retry_20261014|wav_audio_20261014|board_opt_20261014|display_fix_20261013|screen_adapt_20261010|scaling_20261010)/',target)
 if old and not (history.parent/target.split('#')[0]).exists():
  historical_missing.append(target)
  return label+'（历史路径 `'+target+'`，当前目录未保留）'
 return match.group(0)
text=re.sub(r'\[([^\]]+)\]\(([^)]+)\)',historical_link,text)
history.write_text(text,encoding='utf-8')
for n in names:
 p=R/n;text=p.read_text(encoding='utf-8');assert '\ufffd' not in text,n
 for target in re.findall(r'\]\(([^)]+)\)',text):
  if '://' in target or target.startswith('#'):continue
  target=target.split('#')[0];links+=1
  if not(p.parent/target).exists():errors.append([n,target])
assert not errors,errors
evidence=[O/(label+'_bitgen.log'),O/(label+'_bitgen.tcl'),O/(label+'_bit_timing_summary.txt'),
 O/(label+'_bit_timing_status.txt'),O/'highspeed_final_delay0.log',O/'highspeed_final_delay14.log']
record={'stage':stage,'source_commit':b['source_commit'],'bit':b,'tests':80,'static_sources':72,'io_bits':40,
 'status70_unchanged':True,'protected_upper_files_unchanged_from':'7ea1d19','documents':names,'links_checked':links,
 'evidence_sha256':{p.relative_to(R).as_posix():sha(p) for p in evidence},
 'historical_missing_artifacts_marked_as_unavailable':historical_missing,
 'physical_programming_performed':False,'card_write_performed':False,'external_io_signoff':False,
 'known_limits':['R0/R1 both VGA; small source must be prepared offline','F is target, not achieved FPS',
 '64 total BMP/WAV; digits select first ten per type','WAV remains 48kHz 16bit mono PCM',
 'SD CMD17 single-block; no UHS/DDR/1.8V','board display/audio/throughput unverified']}
(O/'FINAL_DELIVERY.json').write_text(json.dumps(record,indent=2,ensure_ascii=False),encoding='utf-8')
report=f'''# 键盘、多媒体与SD高速交付

源码功能与操作见[README](../../README.md)、[接线步骤](../../docs/CONNECTION_AND_USAGE.md)、[键盘教程](../../docs/KEYBOARD_USAGE_20261016.md)。候选bit及校验见[构建状态](../../docs/BUILD_STATUS.md)。

静态72源/40IO通过，80项完整ModelSim通过；0/6/14ns逻辑卡输出延迟覆盖；8192字节/36672个100MHz周期为22.338569MB/s模型吞吐。五个上层文件相对阶段四无差异，70位状态布局保持。

正式综合/P&R：SWNS {v['timing_ns']['SWNS']:+.3f}ns，HWNS {v['timing_ns']['HWNS']:+.3f}ns，TNS0。同一会话导出候选：SWNS {timing['SWNS']:+.3f}ns，HWNS {timing['HWNS']:+.3f}ns，TNS0。没有降100MHz、屏蔽功能路径或改必要官方IP，没有整体+0.5ns或HDMI管脚hold达标声明。

bit文件{b['bytes']}字节，SHA-256 `{b['sha256']}`，源码提交 `{b['source_commit']}`。实板与外部IO均未验收；没有下载或写卡。精确哈希、文件边界及文档链接审计见[FINAL_DELIVERY.json](FINAL_DELIVERY.json)。

两轮失败时序仍保留：native50_initial（−0.245ns）和native50_indexcmp（−0.136ns）。修复为索引等价计算和文档支持的ultra布局优化，没有改受保护缩放器。较早路由DB重新导入导致时钟关联丢失的导出失败日志也保留；本次从绑定源码的gate DB在同一会话完整实现后导出，不沿用该失败STA。\n'''
(O/'FINAL_DELIVERY.md').write_text(report,encoding='utf-8')
print(json.dumps({'bit':b['bit'],'sha256':b['sha256'],'timing_ns':timing,'tests':80,'links_checked':links},ensure_ascii=False))
