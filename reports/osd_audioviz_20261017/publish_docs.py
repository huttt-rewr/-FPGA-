from pathlib import Path
import json,sys
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
v=json.loads((O/'validation.json').read_text(encoding='utf-8'))
assert v['build_status']=='completed' and v['tests_passed']==85
t=v['timing_ns'];a=v['resources']
note=f'''## 当前：像素特效、毛玻璃与音频波形

已接入 `transition_pixels → pixel_effects → glass_osd → audio_visualizer → caption_overlay → status_osd`。SW3/4同时选择转场与像素特效；键盘O统一开关状态OSD、毛玻璃和波形，SW1仍独立控制字幕。具体操作、算法和资源见[本轮功能手册](OSD_AUDIO_VISUALIZER_20261017.md)。

75源/40IO静态检查、85项ModelSim、综合/P&R/内部STA通过：SWNS **{t['SWNS']:+.3f}ns**、HWNS **{t['HWNS']:+.3f}ns**、TNS0；LUT{a['lut']}、BRAM9K **{a['bram']}**、DSP **{a['dsp']}**。原70位状态布局、音频输出链、引脚/时钟/PLL/SDRAM与官方IP保持。[精确验证](../reports/osd_audioviz_20261017/validation.json)。未实板验收，未宣称+0.5ns或HDMI管脚hold达标；之前的native50 bit不含这三个新层。
'''
for n in ('docs/BUILD_STATUS.md','docs/USER_GUIDE.md','docs/KEYBOARD_USAGE_20261016.md','docs/KEY_SW_OPERATION.md'):
 p=R/n;s=p.read_text(encoding='utf-8');h,_,b=s.partition('\n');p.write_text(h+'\n\n'+note+'\n'+b.lstrip(),encoding='utf-8')
doc=f'''# 像素特效、毛玻璃OSD和音频波形

本轮是在键盘/四位SD25/50MHz播放器上增加视频叠加层，保持HDMI_B、原TF卡、KEY/SW和PS/2接口。没有新增外部音频硬件，没有FFT。是否生成匹配的新bit见[构建状态](BUILD_STATUS.md)；旧native50 bit不包含本页效果。本轮未实板验证。

## 如何操作

| SW第3路 | SW第4路 | 像素特效 | 同时选择的转场 |
|---|---|---|---|
| OFF | OFF | 原图直通 | 直接换图 |
| ON | OFF | RGB反色 | 淡出淡入 |
| OFF | ON | Sobel黑底白边 | 滑动 |
| ON | ON | 热成像伪彩 | 淡入淡出/滑动交替 |

第3/4路指sw[2]/sw[3]，对应C6/C5；ON极性和实物方向仍按[KEY/SW教程](KEY_SW_OPERATION.md)。像素特效在帧边界锁存，拨码稳定后下一帧生效；转场选择用于下次换图。两者共用拨码，本轮没有增加独立特效键。例如反色会同时反转转场产生的暗像素，淡出过程的观感也会改变，这是当前顺序的结果。

键盘 **O** 同时开/关左上状态OSD、毛玻璃面板和波形，帧边界生效；字幕/右上计时仍由SW1控制。KEY原播放、调亮度/对比度和菜单功能保持。没有键盘时三个叠加层按默认OSD开启状态运行，KEY/SW未增加独立玻璃/波形开关。

毛玻璃位于逻辑640×480视口的(120,80)，宽400高320，标题FPGA MEDIA；波形位于(24,344)，宽256高80，避开y432开始的字幕。SVGA按既有视口映射等比放大；实际输出仍VGA或SVGA，未增加1080p。

播放合规48kHz/16bit/单声道WAV时可见青绿色波形。上下调音量、M静音，或通过KEY3菜单调音量/静音。波形取自音量/音效处理后、送入HDMI的最终24bit PCM；静音/无文件/欠载时最终样本为零，波形会逐帧回到中心线。波形运动不证明显示器有扬声器或实体音频已出声。

## 三个模块怎样工作

`pixel_effects.v`：三拍固定延迟，四种模式的VS/DE/RGB严格同步。灰度为(77R+150G+29B)>>8，用移位加法实现；Sobel采用因果3×3，计算|Gx|+|Gy|并以80为阈值。前两行/列置黑，避免上电未知RAM或上一帧残留；因果窗口中心比输出位置早一行一列。热成像是灰度伪彩，不是温度测量。

`glass_osd.v`：六拍固定延迟。九点灰度求和，用7282/65536的整数倒数得到精确floor(sum/9)，在合法0～2295范围与除9一致；保留当前像素色差，按R/G/B+blurY-currentY重建并饱和。先用153/256压暗，再以153:103比例混合玻璃与原图，最后画半透明阴影和不透明5×7字体。因果亮度模糊不缓存整行RGB；色差来自当前像素，彩色边缘不会像完整RGB模糊一样扩散。

`audio_visualizer.v`：两拍固定延迟，捕获audio_valid时的有符号高8位PCM；保留正负方向，-128幅度不会abs溢出。128个样本约2.667ms，默认每两个逻辑像素对应一个样本，最右侧最新。两份256字节合计的LUT缓存轮换，一份接收一份显示，帧边界固定读指针和有效数，避免画到一半历史改变；只影响可视化副本，完全不阻塞/改动音频输出采样。未填满的旧RAM位置不绘制。边界切换同拍样本可不写入可视化缓存，但HDMI音频照常输出。

## 为什么共享亮度窗口

第一次各自缓存两整行的实现综合超限，裁剪玻璃到面板列后仍超限，失败记录保留在reports/osd_audioviz_20261017。本版共享特效阶段已保存的变换后亮度：直通、反色、热成像的玻璃九点和直接复用，不重复存两行8bit数据；Sobel结果只有黑白两值，玻璃只需两行1bit历史。另有独立8bit后级滤波仿真作参考，四模式VGA/SVGA共3148800像素逐个等价。

RAM属性使用TD官方支持的 `ram_style="dram"`，这里dram指LUT分布式RAM，不是板上SDRAM。缓存读为组合、写为同步，不对整块RAM复位；有效行/列计数屏蔽未初始化数据。实际综合/物理报告确认BRAM保持61、DSP保持17，不能只根据属性文字判断。

原始像素坐标用于滤波行地址，逻辑视口坐标只用于面板/文字布局；SVGA某些逻辑列重复，不能拿它们覆盖物理行缓存。新增三层总延迟11拍，后续字幕和状态层自行重建坐标，整条链的有效像素数量和VS/DE同拍关系保持。

## 文件和仿真入口

| 文件 | 作用 |
|---|---|
| src/modules/video/pixel_effects.v | 四种像素效果、共享亮度窗口和与RGB同拍的旁带九点和 |
| src/modules/video/glass_osd.v | 独立参考/正式共享窗口两种profile、玻璃混合与字模 |
| src/modules/video/audio_visualizer.v | 最终PCM抓取、双历史缓存、波形/中心线/面板叠加 |
| sim/tb_pixel_effects.v | 四模式精确黄金模型、边界、消隐干扰和三拍对齐 |
| sim/tb_glass_osd.v | 九点平均/色差/饱和/alpha/文字阴影、VGA/SVGA和六拍对齐 |
| sim/tb_audio_visualizer.v | 正负极值、环形顺序、帧内冻结、开关和两拍对齐 |
| sim/tb_visual_pipeline.v | VGA/SVGA整帧直通787200像素，无丢失/重复，总11拍 |
| sim/tb_shared_luma.v | 共享方案对独立后级滤波3148800像素等价 |

新源登记在design_files和两份TD工程；新激励登记到完整回归。执行：

```powershell
cd E:\\fpga
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
```

不要并发使用同一sim/msim_work，也不要在构建过程中改src/scripts/sim。结果：85项完整回归通过，LUT{a['lut']}、REG{a['reg']}、BRAM9K61、DSP17；SWNS {t['SWNS']:+.3f}ns，HWNS {t['HWNS']:+.3f}ns，TNS0，详见[冻结验收](../reports/osd_audioviz_20261017/validation.json)。内部STA不替代外部SD/HDMI或实板观测，未宣称整体+0.5ns。
'''
(R/'docs/OSD_AUDIO_VISUALIZER_20261017.md').write_text(doc,encoding='utf-8')
p=R/'README.md';s=p.read_text(encoding='utf-8');h,_,b=s.partition('\n')
s=h+'\n\n本轮新增四模式像素特效、毛玻璃与最终PCM波形，SW3/4选择特效，O统一开关叠加；[详细操作和原理](docs/OSD_AUDIO_VISUALIZER_20261017.md)。原KEY/SW与音频输出保持，匹配bit及验证以[构建状态](docs/BUILD_STATUS.md)为准。\n\n'+b.lstrip()
p.write_text(s,encoding='utf-8')
p=R/'docs/SOURCE_MAP.md';s=p.read_text(encoding='utf-8');s+='\n## 像素特效、毛玻璃与音频波形\n\n新增pixel_effects.v（含video_luma_window）、glass_osd.v、audio_visualizer.v三份正式源，总清单75份。模块职责、共享LUT缓存和激励见[本轮手册](OSD_AUDIO_VISUALIZER_20261017.md)。正式音频链、官方IP/引脚/时钟和70位状态位序保持。\n';p.write_text(s,encoding='utf-8')
print('Published source-bound feature/control/algorithm manual')
