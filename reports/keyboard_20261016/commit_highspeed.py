"""Commit only the reviewed CMD6 increment and source-bound delivery evidence."""
from pathlib import Path
import hashlib,json,subprocess,sys
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent;stage=sys.argv[1]
v=json.loads((O/(stage+'_validation.json')).read_text())
assert v['build_status']=='completed' and v['regression_passed']==80
for n,h in v['sources'].items():assert hashlib.sha256((R/n).read_bytes()).hexdigest()==h,n
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=R).strip()
protected=['src/modules/sd/sd_fat32.v','src/modules/sd/sd_read_arbiter.v','src/modules/bmp/bmp_read.v','src/modules/audio/audio_wav.v','src/modules/video/bmp_scale_loader.v']
subprocess.run(['git','diff','--exit-code','7ea1d19','--',*protected],cwd=R,check=True)
for cur in range(64):
 for count in range(128):
  old=0 if cur+1>=count else (cur+1)&63
  new=0 if count==0 or cur>=count-1 else (cur+1)&63
  assert old==new
paths=['src/top.v','src/modules/bmp/sd_card_bmp.v','src/modules/sd/sd_card_top.v',
 'src/modules/sd/native/sd_bus_phy.v','src/modules/sd/native/sd_native_controller.v',
 'src/modules/sd/native/sd_card_top_native.v','scripts/run_tests.ps1','scripts/implement.tcl',
 'sim/sd_native_card_model.v','sim/tb_sd_highspeed.v','sim/tb_sd_highspeed_player.v',
 'README.md','docs/BUILD_STATUS.md','docs/SD_NATIVE_4BIT_20261016.md','docs/USER_GUIDE.md',
 'docs/KEYBOARD_USAGE_20261016.md','docs/KEYBOARD_REMAINING_20261016.md',
 'docs/CONNECTION_AND_USAGE.md','docs/ROADMAP_KEYBOARD_MEDIA.md','docs/BOARD_TIMING.md','docs/SOURCE_MAP.md']
subprocess.run(['git','diff','--check','--',*paths],cwd=R,check=True)
names=[stage+'_validation.json','RESULT_'+stage+'.md',stage+'_regression.log',
 stage+'/build_manifest.json',stage+'/timing_status.txt',stage+'/timing_summary.txt',stage+'/physical_area.txt',
 'commit_highspeed.py','record_stage.py','make_candidate_bit.py','publish_delivery_docs.py',
 'prepare_highspeed.py','prepare_highspeed_test.py','probe_highspeed_player.py','install_highspeed.py',
 'board_tf_page20.png','board_pin_evidence.txt','docs_validation.json']
paths += [(O/n).relative_to(R).as_posix() for n in names]
assert all((R/n).is_file() for n in paths)
subprocess.run(['git','add','--',*paths],cwd=R,check=True)
t=v['timing_ns'];msg=f'''接入CMD6协商四位50MHz并收敛内部时序

确认64字节切换状态、四线CRC、支持/选择/busy后才升50MHz；异常重初始化保持原生25MHz。增加延迟卡模型、高速异常恢复及真实FAT/BMP/WAV播放器回归。索引比较等价变换（8192组穷举一致），TD使用文档支持的ultra布局优化，保持五个受保护上层模块和原70位状态布局。
验证：72源40IO静态通过，80项ModelSim全通过，综合/布局布线/内部STA通过：SWNS {t['SWNS']:+.3f}ns，HWNS {t['HWNS']:+.3f}ns，TNS0。未降100MHz、未增功能路径屏蔽；外部IO、实体卡吞吐和实板出声未验收，未宣称+0.5ns。同步当前操作/接线手册并保留冻结证据。

Co-Authored-By: Claude Code <noreply@anthropic.com>
'''
(O/'highspeed_commit_message.txt').write_text(msg,encoding='utf-8')
subprocess.run(['git','commit','-F',str(O/'highspeed_commit_message.txt')],cwd=R,check=True)
