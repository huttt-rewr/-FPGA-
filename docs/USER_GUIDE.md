# HDMI 图片与 WAV 播放器用户手册

> **2026-10-19 转场扩充：仅第一阶段已通过软件/内部时序门禁，尚未实板验收。** 80源/40IO静态检查、102项ModelSim通过；SWNS +0.116ns、HWNS +0.030ns，STNS/HTNS均0。SW第3、4路同时ON后，每次换图依次轮播淡入淡出、滑动、擦除、圆形、棋盘。二维Ken-Burns受两行缓存与禁止修改SDRAM的约束冲突而未实现，FFT按指定顺序尚未启动；本轮无新bit，旧bit不含这些修改。见[操作、原理与未完成项](TRANSITIONS_ZOOM_FFT_20261019.md)。

> **历史：2026-10-19 旧上板验收包（不匹配当前源码）：已生成当时版本的候选 bit，尚未下载或完成实板验收。** 635,444字节；生成前后SWNS +0.044ns、HWNS +0.024ns、STNS/HTNS均0，原80源/101项回归基线不变。已准备7份BMP、1份WAV和四项实板记录；**该前置规则属于旧任务；本轮按新版统一附件执行转场，实板仍待验。** 见 [逐步验收教程](BOARD_ACCEPTANCE_640_20261019.md)、[本次准备结果](../reports/board_accept_20261019/RESULT.md)、[候选bit](../reports/board_accept_20261019/candidate/hdmi_640_plain_800_audio.bit)。默认640无HDMI音频，实际800保留图声。

> **历史：2026-10-19 640 加密实例替换记录：640 加密实例已替换为明文 TMDS 纯视频核，800 保留原 HDMI 图声；独立 EDID 协商保留。** 静态检查80源/40IO、101项ModelSim及综合/布局布线/内部STA通过。物理LUT 15,785、BRAM 41；SWNS +0.044ns、HWNS +0.024ns，STNS/HTNS均0。资源降低但setup裕量较上一版减少；未达到整体+0.5ns。**默认640不发送HDMI音频，听WAV需R切到实际800×600；EDID回退640也无声。** 未生成本轮bit、未上板，外部IO和既有物理警告仍待核对。详见 [本轮说明](HDMI_SELFWRITE_640_20261019.md) 与 [实际报告](../reports/hdmi_selfwrite_20261019/RESULT.md)。

> **历史：2026-10-19 替换640核前的时序优化：98项ModelSim全通过，综合/布局布线及内部STA通过。** SWNS +0.131ns、STNS 0.000ns、HWNS +0.022ns、HTNS 0.000ns。WAV接收寄存级与独立会话增量布线/hold修复已落地；100MHz、全部功能、KEY/SW、官方IP和70位状态布局保留。未生成本轮新bit、未上板；外部IO与既有物理警告仍待核对，未达到整体+0.5ns。[本轮原始结果](../reports/timing_close_20261018/RESULT.md)。此前各段数值只属于各自冻结历史版本。

> **历史：2026-10-18 FAT32 比较器验证：94 项回归通过，内部 STA 仍失败，未生成本轮 bit。** 最终 SWNS -0.592ns、STNS -1.362ns、HWNS +0.024ns、HTNS +0.000ns。全部功能及操作保留；内部 removal 不是 HDMI 管脚 hold，未达到整体 +0.5ns。[本轮报告](../reports/fat32_compare_20261018/RESULT.md)；以下数值属于各冻结历史版本。

> **历史：2026-10-18 构建修复：93项回归通过，STA仍未通过，无本轮新bit。** 前向声明修复、行地址拆拍和报告归档保护已落实。当前SWNS -0.592ns、HWNS +0.024ns；SDRAM物理警告仍待解决。全部功能和KEY/SW操作保留，未达到整体+0.5ns。见[实际报告](../reports/build_repair_20261018/RESULT.md)和[技术说明](BUILD_REPAIR_20261018.md)；下文较早数值只适用于各自冻结的历史版本。

> **历史：2026-10-18 深度优化：91项回归通过，整机验收未完成，无本轮新bit。** 综合16,572 LUT，物理17,347 LUT（88.51%，仍超85%目标）；58 BRAM（90.625%）。SWNS −0.402ns（复位recovery），普通setup −0.401ns，HWNS +0.021ns。77源/40 IO静态检查通过。全部功能和原操作保留；旧bit不能验收当前源码。详见[本轮验收](../reports/deep_opt_20261017/RESULT.md)与[技术说明](DEEP_OPTIMIZATION_20261018.md)。


> 2026-10-17 贪吃蛇增量：G 进入/退出，方向键移动，退出后再进入重开。游戏期间方向键暂停翻图/调音量功能；KEY/SW 保留原功能。操作与资源/验收限制见 [贪吃蛇手册](SNAKE_GAME_20261017.md)。当前仍为物理验收未完成的实验源码，旧 bit 不包含游戏。

> **2026-10-17 当前源码为OSD/波形实验版：75源/40IO静态检查、85项ModelSim通过；物理实现与时序未通过，未生成本轮新bit。** SW3/4增加原图/反色/Sobel/热成像，O统一开关状态OSD/玻璃/波形。操作、算法和失败路径见[本轮手册](OSD_AUDIO_VISUALIZER_20261017.md)。下文旧native50候选及其正时序只代表修改前版本，不能验收当前源码。

> 当前正式源码：六线原生四位 SD，CMD6 成功确认后自动从25MHz升至50MHz，不支持/忙时保持四位25MHz；主控制100MHz。80项是历史检查点；当前98项ModelSim和内部STA结果见[构建状态](BUILD_STATUS.md)。尚未实板验证；下文明确标注的旧版本说明只作历史参考。

当前完整操作见[键盘、分辨率和换图频率教程](KEYBOARD_USAGE_20261016.md)，[KEY/SW详细教程](KEY_SW_OPERATION.md)解释不接键盘时的全部板载操作。显示器接HDMI_B；新顶层默认不静音、音量08。是否有匹配的新bit及STA/回归通过状态，请先看[构建状态](BUILD_STATUS.md)。旧bit不能验证新功能。

## 第一次运行

1. 用FAT32、512字节扇区的TF卡，复制合计不超过64份BMP/WAV到根目录；按目录项顺序枚举，不按文件名数字排序。BMP限正高度24bit BI_RGB、1～1920×1～1080；WAV限48kHz/16bit/单声道PCM、最大16MiB。
2. 断电连接TF卡、HDMI_B和支持Set2的PS/2键盘；显示器选择相应HDMI输入。官方PS/2 CLK=M16、DATA=K16是封装坐标，不是插头针号。
3. 上电/配置当前工程，等待挂载和首图完整装载。复位默认输出VGA640×480，菜单关闭、亮度0、对比度1、音量08、不静音。
4. 左右换图，数字0选第一张；A松开后2秒内数字选WAV。空格开启自动播放，F调目标换图档，R在VGA/SVGA/小素材VGA之间循环。SVGA受EDID支持限制，切档暂黑后重新装载。
5. 上下调音量、M静音；O开关状态OSD。KEY3短按释放切PLAY/BRIG/CONT，KEY1/2执行对应操作；KEY3长按约1.1秒进入菜单。SW保持控制字幕/滚动/转场。

R的0档和1档都输出VGA；小素材需要事先转换为320×240，R不会自动减少大图的卡读取量。F的TARGET不是显示器刷新率，也不保证实际FPS；L表示曾受加载/提交忙限制。切模式会重挂载并暂停自动轮播，恢复后可再按空格。

## 转换普通文件

在E:/fpga执行，只生成电脑普通文件；随后在资源管理器复制到TF根目录，不需烧裸镜像：

```powershell
python scripts/prepare_media.py convert photo.jpg media/PIC01.bmp --width 320 --height 240 --fit contain
python scripts/prepare_media.py check media/PIC01.bmp
python scripts/prepare_audio.py convert input.wav media/SOUND01.wav
python scripts/prepare_audio.py check media/SOUND01.wav
```

输出已存在时工具会拒绝覆盖，请换名。[完整制卡说明](FAT32_USAGE_20261015.md)包含文件系统、碎片与格式错误处理；[接线说明](CONNECTION_AND_USAGE.md)包含管脚与TD配置步骤。

## 快速排障

| 现象 | 检查与处理 |
|---|---|
| 无画面 | HDMI_B、显示器输入、是否当前bit；先复位回VGA；不支持1080p输出 |
| 按键不换图 | 先退出菜单并选MODE:PLAY；等待LOAD:B结束；KEY1长按不会连发 |
| 数字选错图 | 从0计数、按目录项顺序；没有两位数输入；越界回第一份 |
| 无声 | 先确认实际800×600；640不发送HDMI音频，再检查合规WAV、音量不为0、M静音状态、显示器HDMI音频能力与自身音量 |
| A:E1..E4 | 1格式/头、2SD/超时、3扇区长度、4chunk/边界；失败一秒重试，见音频诊断教程 |
| U1 | 音频曾欠载，切WAV不清；切模式或整机复位清除，若重现检查读卡服务速度 |
| TARGET旁L | 实际加载/提交超过目标周期；降档或使用更小的图片，不等于显示器刷新失败 |
| LOAD:E | 图片读取/提交或视频缓存诊断，保留旧帧；挂载问题修正卡后复位 |
| 改卡内容没生效 | 安全断电换卡后复位重新枚举；不支持运行中热插拔重扫 |

音频错误历史到真实PCM恢复才清，不能把静音包当恢复；挂载失败和图片提交确认超时不属于自动WAV重试范围。卡与显示器的实板验收仍未完成，不能由仿真推断白条或出声已解决。

## 验证与设计资料

```powershell
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
```

不要在构建过程中改src/scripts/sim输入。两TD入口引用同一源清单，官方HDMI/SDRAM/PLL/FIFO IP是必要依赖。[源文件职责](SOURCE_MAP.md)、[多文件实现](MEDIA_INDEX_20261016.md)、[SD四位实现与50MHz验收边界](SD_NATIVE_4BIT_20261016.md)、[构建状态](BUILD_STATUS.md)。正式SD为原生四位CMD6自动协商25/50MHz；内部复位removal不能当作HDMI管脚hold，没有整体+0.5ns签核声明。
