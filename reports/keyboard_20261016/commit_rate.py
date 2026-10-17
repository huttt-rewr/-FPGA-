"""Publish and commit phase four only with exact all-green evidence."""
from pathlib import Path
import hashlib,json,subprocess,sys
R=Path(__file__).resolve().parents[2]; O=Path(__file__).resolve().parent
stage=sys.argv[1];v=json.loads((O/(stage+'_validation.json')).read_text())
assert v['build_status']=='completed' and v['regression_passed']==77
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=R).strip()
for name,digest in v['sources'].items():
 assert hashlib.sha256((R/name).read_bytes()).hexdigest()==digest,name
subprocess.run(['python',str(O/'finalize_docs.py')],cwd=R,check=True)
subprocess.run(['python',str(O/'publish_current_notes.py'),stage],cwd=R,check=True)
subprocess.run(['python',str(O/'check_delivery_docs.py')],cwd=R,check=True)
paths=['src/top.v','src/modules/bmp/sd_card_bmp.v','src/modules/control/fps_control.v',
 'src/modules/osd/status_osd.v','sim/tb_file_osd.v','sim/tb_audio_stream_flush.v',
 'sim/tb_fps_control.v','sim/tb_rate_player.v','scripts/design_files.txt','scripts/run_tests.ps1',
 'video_improve.al','src/td_project/video_improve.al','README.md',
 'src/modules/input/ps2_controls.v','src/modules/sd/sd_card_cmd.v',
 'docs/USER_GUIDE.md','docs/SOURCE_MAP.md','docs/KEYBOARD_USAGE_20261016.md',
 'docs/BUILD_STATUS.md','docs/CONNECTION_AND_USAGE.md','docs/SCREEN_ADAPTATION_20261010.md',
 'docs/WAV_AUDIO_20261014.md','docs/README.md','docs/ROADMAP_KEYBOARD_MEDIA.md',
 'docs/KEY_SW_OPERATION.md','docs/FAT32_USAGE_20261015.md','docs/KEYBOARD_REMAINING_20261016.md']
paths += [str((O/n).relative_to(R)).replace('\\','/') for n in
 [stage+'_validation.json','RESULT_'+stage+'.md',stage+'_regression.log',
 stage+'/build_manifest.json',stage+'/timing_status.txt',stage+'/timing_summary.txt',
 stage+'/physical_area.txt','commit_rate.py','finalize_docs.py','publish_current_notes.py',
 'check_delivery_docs.py','docs_validation.json']]
subprocess.run(['git','diff','--check','--',*paths],cwd=R,check=True)
subprocess.run(['git','add','--',*paths],cwd=R,check=True)
t=v['timing_ns']; msg=f'''接入F目标换图节拍及受限OSD，补齐使用文档

1/2/5/10/15/30档包含加载时间，忙时只等待一次、不积压追赶；TARGET与L区分目标和受限。独立7位CDC保留原70位状态布局。静音/音量0清可选回声历史。
验证：69源/38IO静态通过，77项ModelSim全通过，综合布局布线STA通过，SWNS {t['SWNS']:+.3f}ns / HWNS {t['HWNS']:+.3f}ns，TNS均0。SD仍SPI25MHz；尚未实板，未宣称+0.5ns。

Co-Authored-By: Claude Code <noreply@anthropic.com>
'''
(O/'rate_commit_message.txt').write_text(msg,encoding='utf-8')
subprocess.run(['git','diff','--cached','--stat'],cwd=R,check=True)
subprocess.run(['git','commit','-F',str(O/'rate_commit_message.txt')],cwd=R,check=True)
