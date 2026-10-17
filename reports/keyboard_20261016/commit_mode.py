"""Commit only the accepted mode-stage files; leave unrelated work alone."""
from pathlib import Path
import hashlib,json,subprocess,sys
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
stage=sys.argv[1]
v=json.loads((O/(stage+'_validation.json')).read_text())
assert v['build_status']=='completed' and v['regression_passed']==75
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=R).strip(), 'Existing staged work'
for name,digest in v['sources'].items():
 assert hashlib.sha256((R/name).read_bytes()).hexdigest()==digest,name
subprocess.run(['python',str(O/'accept_mode_docs.py'),stage],cwd=R,check=True)
paths=['src/top.v','src/modules/bmp/bmp_read.v','src/modules/bmp/sd_card_bmp.v',
 'src/modules/audio/audio_wav.v',
 'src/modules/control/picture_controls.v','src/modules/osd/caption_overlay.v',
 'src/modules/sd/sd_card_cmd.v','src/modules/sd/sd_fat32.v',
 'src/modules/video/adaptive_video_clock.v','src/modules/video/bmp_scale_loader.v',
 'src/modules/video/video_mode_control.v','sim/tb_video_mode_control.v',
 'sim/tb_mode_reload.v','sim/tb_caption_pipeline.v','sim/tb_audio_sd_integration.v','scripts/design_files.txt',
 'scripts/run_tests.ps1','video_improve.al','src/td_project/video_improve.al',
 'docs/BUILD_STATUS.md','docs/KEYBOARD_USAGE_20261016.md',
 'reports/keyboard_20261016/REVIEW_NOTES.md']
paths += [str((O/n).relative_to(R)).replace('\\','/') for n in
 [stage+'_validation.json','RESULT_'+stage+'.md',stage+'_regression.log',
 stage+'/build_manifest.json',stage+'/timing_status.txt',stage+'/timing_summary.txt',
 stage+'/physical_area.txt','audit_stage.py','accept_mode_docs.py','commit_mode.py']]
subprocess.run(['git','diff','--check','--','src','scripts','sim','video_improve.al'],cwd=R,check=True)
subprocess.run(['git','add','--',*paths],cwd=R,check=True)
t=v['timing_ns']
body=f'''实现R安全分辨率切换并拆解控制与缩放长路径

先复位消费者再切已有全局时钟，保留键盘设置并重载选图；修复空闲到加载之间旧显示序号覆盖新请求及VGA核运行复位问题。
拆分字幕像素流水、KEY独立计数、BMP头选通、MBR位置译码、缩放尺寸与WAV缓存判断；WAV头按固定字节选通以消除局部布线冲突。分离SPI片选使能、局部复位释放，修正集成激励的单拍事件采样。保留100MHz、原70位状态布局和官方IP。
验证：静态68源/38IO、75项ModelSim全通过；综合布局布线STA通过，SWNS {t['SWNS']:+.3f}ns / HWNS {t['HWNS']:+.3f}ns，TNS均0。未实板、未生成新bit，SD仍SPI25MHz，F下一阶段接入。

Co-Authored-By: Claude Code <noreply@anthropic.com>
'''
(O/'mode_commit_message.txt').write_text(body,encoding='utf-8')
subprocess.run(['git','diff','--cached','--stat'],cwd=R,check=True)
subprocess.run(['git','commit','-F',str(O/'mode_commit_message.txt')],cwd=R,check=True)
