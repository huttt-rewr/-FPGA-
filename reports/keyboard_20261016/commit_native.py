from pathlib import Path
import hashlib,json,subprocess,sys
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent;stage=sys.argv[1]
v=json.loads((O/(stage+'_validation.json')).read_text());assert v['build_status']=='completed' and v['regression_passed']==78
for name,digest in v['sources'].items():assert hashlib.sha256((R/name).read_bytes()).hexdigest()==digest,name
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=R).strip()
protected=['src/modules/sd/sd_fat32.v','src/modules/sd/sd_read_arbiter.v','src/modules/bmp/bmp_read.v','src/modules/audio/audio_wav.v','src/modules/video/bmp_scale_loader.v']
subprocess.run(['git','diff','--exit-code','7ea1d19','--',*protected],cwd=R,check=True)
subprocess.run(['python',str(O/'publish_native_docs.py'),stage],cwd=R,check=True)
paths=['src/top.v','src/modules/bmp/sd_card_bmp.v','src/modules/sd/sd_card_top.v','src/constraints/pin.adc',
 'scripts/design_files.txt','scripts/run_tests.ps1','scripts/run_indexed_tests.ps1',
 'src/td_project/video_improve.al','video_improve.al','sim/tb_sd_native_integrated.v','sim/tb_sd_waits.v',
 'README.md','docs/BUILD_STATUS.md','docs/SD_NATIVE_4BIT_20261016.md','docs/USER_GUIDE.md',
 'docs/KEYBOARD_USAGE_20261016.md','docs/KEYBOARD_REMAINING_20261016.md',
 'docs/CONNECTION_AND_USAGE.md','docs/ROADMAP_KEYBOARD_MEDIA.md','docs/BOARD_TIMING.md','docs/SOURCE_MAP.md']
paths += [str((O/n).relative_to(R)).replace('\\','/') for n in [stage+'_validation.json',
 'RESULT_'+stage+'.md',stage+'_regression.log',stage+'/build_manifest.json',stage+'/timing_status.txt',
 stage+'/timing_summary.txt',stage+'/physical_area.txt','publish_native_docs.py','commit_native.py','record_stage.py',
 'prepare_native_integration.py','prepare_native_player_test.py','install_native.py']]
subprocess.run(['git','diff','--check','--',*paths],cwd=R,check=True)
subprocess.run(['git','add','--',*paths],cwd=R,check=True)
t=v['timing_ns'];msg=f'''接入原生四位SD25MHz并保留上层扇区握手

六线引脚与两TD入口同步；正式profile剪除SPI，旧SPI保留兼容测试。FAT32/仲裁/BMP/WAV/缩放相对阶段四零改动。新增无force替换的真实引脚端到端集成激励。
验证：72源40IO静态通过，78项ModelSim全通过，综合P&R/STA通过，SWNS {t['SWNS']:+.3f}ns / HWNS {t['HWNS']:+.3f}ns，TNS0。模型吞吐不是实卡；未下载、未实板，50MHz仍隔离候选。

Co-Authored-By: Claude Code <noreply@anthropic.com>
''';(O/'native_commit_message.txt').write_text(msg,encoding='utf-8')
subprocess.run(['git','commit','-F',str(O/'native_commit_message.txt')],cwd=R,check=True)
