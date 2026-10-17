from pathlib import Path
import sys,json,re
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
stage=sys.argv[1];v=json.loads((O/(stage+'_validation.json')).read_text())
assert v['build_status']=='completed'
t=v['timing_ns']
p=R/'docs/BUILD_STATUS.md';s=p.read_text(encoding='utf-8')
s=re.sub(r'^> 工作中[^\n]*\n\n','',s,flags=re.M)
s=s.replace('## 当前阶段二：','## 历史阶段二：')
note=f'''## 当前阶段三：R安全切模式和重新加载

R已正式接入VGA/SVGA/小素材VGA请求，SVGA受EDID支持限制。独立控制复位保留用户设置，媒体/视频及EDID完成后的HDMI核先复位再切时钟，稳定等待后重新挂载和重载当前图片；自动轮播暂停。0和1均为VGA，0不自动降低大图读取量。

静态68源/38IO、{v['regression_passed']}项回归、综合/P&R/STA通过：SWNS **{t['SWNS']:+.3f}ns**、STNS {t['STNS']:.3f}ns、HWNS **{t['HWNS']:+.3f}ns**、HTNS {t['HTNS']:.3f}ns。[精确输入清单](../reports/keyboard_20261016/{stage}_validation.json)、[本轮报告](../reports/keyboard_20261016/RESULT_{stage}.md)。70位状态布局和取位保留，100MHz未降低，没有新增功能路径false path。内部recovery/removal没有当成HDMI管脚hold，没有整体+0.5ns声明。

F尚待正式接入；SD仍SPI25MHz，未生成本阶段bit，未实板。以下为各自冻结源码的历史结果。

'''
s=s.replace('# 构建状态\n\n','# 构建状态\n\n'+note,1);p.write_text(s,encoding='utf-8')
p=R/'docs/KEYBOARD_USAGE_20261016.md';s=p.read_text(encoding='utf-8')
s=s.replace('## 数字选文件与待接入R/F','## 数字选文件与R/F状态')
s=s.replace('只锁存 `res_mode`，不切 HDMI 时钟','阶段三已接入：先复位、切25/40MHz像素及配对串行时钟、稳定后重挂载重载；SVGA受EDID限制')
s=s.replace('原生四位 SD 是独立候选，缺 DAT1/2 板级映射与上拉依据','原生四位 SD 是独立候选；官方手册已确认 DAT1=B15、DAT2=A11 及10kΩ上拉，待正式集成与实板验证')
s+='''
## 阶段三的R注意事项

R顺序默认1(VGA)→2(SVGA请求)→0(小素材VGA)→1。2不受支持时回退VGA；0和1都输出640×480。0档不会自动把大图变成320×240文件；要节省读卡带宽，需要事先转换小素材。

切档会暂黑并重载所选图片，键盘与音量/静音设置保留；自动轮播暂停，加载完成后再按空格。F仍待下一阶段。新源码的75项回归和STA见构建状态；本阶段没有新bit或实板验收。
''';p.write_text(s,encoding='utf-8')
print('Published accepted mode stage, with F and physical validation still pending')
