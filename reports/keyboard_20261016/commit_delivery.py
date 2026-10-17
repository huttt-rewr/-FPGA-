"""Commit the final bit identities and reviewable evidence, not generated DB/bit."""
from pathlib import Path
import hashlib,json,subprocess
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
v=json.loads((O/'FINAL_DELIVERY.json').read_text(encoding='utf-8'))
for n,h in json.loads((O/'native50_ultra_validation.json').read_text())['sources'].items():
 assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h,n
assert hashlib.sha256((R/v['bit']['bit']).read_bytes()).hexdigest()==v['bit']['sha256']
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=R).strip()
paths=['README.md','docs/BOARD_TIMING.md','docs/BUILD_STATUS.md','docs/ROADMAP_KEYBOARD_MEDIA.md','docs/USER_GUIDE.md']
subprocess.run(['git','diff','--check','--',*paths],cwd=R,check=True)
names=['finalize_delivery.py','commit_delivery.py','FINAL_DELIVERY.json','FINAL_DELIVERY.md',
 'native50_delivery_bit_manifest.json','native50_delivery_bitgen.tcl','native50_delivery_bitgen.log',
 'native50_delivery_bit_timing_status.txt','native50_delivery_bit_timing_summary.txt','native50_delivery_bit_physical_area.txt',
 'native50_delivery_bit_io.txt','highspeed_final_delay0.log','highspeed_final_delay14.log',
 'RESULT_native50_initial.md','native50_initial_validation.json','native50_initial/timing_status.txt',
 'RESULT_native50_indexcmp.md','native50_indexcmp_validation.json','native50_indexcmp/timing_status.txt']
paths +=[(O/n).relative_to(R).as_posix() for n in names]
assert all((R/n).is_file() for n in paths)
subprocess.run(['git','add','--',*paths],cwd=R,check=True)
msg='''冻结键盘媒体高速候选bit与操作验收记录

同会话实现后导出633116字节候选，绑定源码5952318、80项回归和SHA-256；内部STA +0.026/+0.022ns，TNS0。补核0/14ns卡模型，保留失败时序记录；165条当前文档链接通过，缺失的旧附件标明历史不可用。未下载实板、未写卡，外部IO和实体卡吞吐仍待验证，未声明+0.5ns或HDMI管脚hold。

Co-Authored-By: Claude Code <noreply@anthropic.com>
'''
(O/'delivery_commit_message.txt').write_text(msg,encoding='utf-8')
subprocess.run(['git','commit','-F',str(O/'delivery_commit_message.txt')],cwd=R,check=True)
