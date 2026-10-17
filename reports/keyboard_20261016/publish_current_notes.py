"""Publish accepted phase-four evidence and mark older usage as historical."""
from pathlib import Path
import json,re,sys
R=Path(__file__).resolve().parents[2]; O=Path(__file__).resolve().parent
stage=sys.argv[1]
v=json.loads((O/(stage+'_validation.json')).read_text())
assert v['build_status']=='completed'
t=v['timing_ns']
p=R/'docs/BUILD_STATUS.md';s=p.read_text(encoding='utf-8')
s=s.replace('## 当前阶段三：','## 历史阶段三：')
p.write_text(s,encoding='utf-8')
def prepend(name,note):
 p=R/name;s=p.read_text(encoding='utf-8');head,sep,body=s.partition('\n')
 p.write_text(head+'\n\n'+note+'\n\n'+body.lstrip(),encoding='utf-8')
prepend('docs/BUILD_STATUS.md',f'''## 当前：键盘、多文件、R安全切换与F目标换图频率

本轮正式源码完成阶段1～4。静态检查69源/38IO、{v['regression_passed']}项ModelSim回归、综合、布局布线及STA通过，精确输入哈希见[冻结清单](../reports/keyboard_20261016/{stage}_validation.json)。SWNS **{t['SWNS']:+.3f}ns**、STNS {t['STNS']:.3f}ns、HWNS **{t['HWNS']:+.3f}ns**、HTNS {t['HTNS']:.3f}ns。[本轮报告](../reports/keyboard_20261016/RESULT_{stage}.md)、[操作手册](KEYBOARD_USAGE_20261016.md)。没有降低100MHz控制时钟，没有新增功能路径false path，70位状态布局及全部下标保持；内部复位recovery/removal没有当作HDMI管脚hold。没有整体+0.5ns声明。

正式SD仍SPI25MHz；四位25MHz候选未接入板级，50MHz未实现CMD6协商和实板验证。未下载、未写实体卡，显示、出声、吞吐、显示器运行切换重新锁相均待实板验收。新候选bit是否生成见交付清单，不得使用历史bit验收本轮新增功能。

以下均为各自冻结源码的历史结果。旧文中的“当前”“仅存R/F请求”不代表本轮源码。''')
prepend('docs/CONNECTION_AND_USAGE.md','> 2026-10-16当前接线与操作：HDMI_B、原TF卡槽、可选PS/2 Set2键盘（CLK=M16、DATA=K16）。KEY/SW原操作保留；默认不静音、音量08，FAT32根目录BMP+WAV合计最多64份。复位默认VGA，R请求SVGA受EDID支持限制；F仅调目标换图频率。完整新操作见[键盘手册](KEYBOARD_USAGE_20261016.md)，新bit和精确验收见[构建状态](BUILD_STATUS.md)。下文原有裸扇区/串口/默认静音/启动自动选SVGA说明属于旧版，先按当前手册使用。')
prepend('docs/SCREEN_ADAPTATION_20261010.md','> 2026-10-16当前模式：复位默认640×480，R依次请求1→2→0→1；2仅在EDID支持时输出800×600，否则VGA。0和1都输出VGA；0不自动减少大图读取量。切档先停消费者、复位、切全局时钟、等待稳定再重挂载重载；自动轮播暂停，恢复后再按空格。图片与OSD跟随实际输出适配。详见[当前操作](KEYBOARD_USAGE_20261016.md)与[本轮验收](BUILD_STATUS.md)。下文启动即自动选择与10月11/13日结果是历史记录，不能认证新源码。')
prepend('docs/WAV_AUDIO_20261014.md','> 2026-10-16当前音频：支持多WAV，BMP/WAV合计索引最多64份；A后2秒内数字选前十份，↑/↓音量、M静音，KEY菜单仍可用。默认不静音、音量08，格式仍严格48kHz/16bit/单声道PCM。切WAV取消并排空旧事务、清FIFO和FIR/回声历史；可选回声profile在静音/音量0时也清历史。没有实板出声完成声明。详见[当前操作](KEYBOARD_USAGE_20261016.md)和[构建状态](BUILD_STATUS.md)。下文前4图/首WAV/默认静音为历史版本。')
prepend('docs/README.md','> 当前入口（2026-10-16）：[完整用户手册](USER_GUIDE.md)、[键盘/R/F教程](KEYBOARD_USAGE_20261016.md)、[KEY/SW教程](KEY_SW_OPERATION.md)、[逐源文件职责](SOURCE_MAP.md)、[实际构建与候选状态](BUILD_STATUS.md)。正式实现阶段1～4，SD仍SPI25MHz，四位50MHz和实板验收未完成。下列旧日期更新仅作历史对照。')
p=R/'docs/ROADMAP_KEYBOARD_MEDIA.md';s=p.read_text(encoding='utf-8')
s=s.replace('阶段一67项回归与STA通过，后续候选实验不代表正式工程接入。',f'阶段1～4已正式接入，{v["regression_passed"]}项回归及STA通过，精确数值与源码哈希见构建状态。阶段5仍未接入板级四位/50MHz。')
p.write_text(s,encoding='utf-8')
print('Published current evidence and versioned operation notes')
