# EG4S20 HDMI 图片与 WAV 播放器

> **2026-10-22 当前构建：内部时序已通过，已生成上板待验候选 bit。** SWNS +0.188ns、HWNS +0.022ns、STNS/HTNS 均为0；111项主回归与17项AVF专项全通过，93源/40 IO静态检查通过。物理资源 LUT 17036、BRAM 54、DSP 23；AVF 默认开启。[本轮候选 bit](reports/bitstream_20261022/video_improve_20261022.bit)为644756字节，生成前后STA一致。HWNS 限制路径为内部复位 removal，不能当作 HDMI 管脚 hold；未达整体 +0.5ns，未上板，PHY-7002/PHY-5079警告仍保留。以下较早记录只适用其历史版本；当前以[修复结果](reports/timing_fix_20261022/RESULT.md)及最新 build_manifest 为准。

> **2026-10-21 UART/红外/画质/相册：四阶段已通过静态、全量仿真与内部物理门禁；没有本轮新bit，未上板。** 108项ModelSim通过；SWNS +0.142ns、HWNS +0.024ns，STNS/HTNS均0。默认保留KEY/SW/PS/2；新增选项默认关闭。当前用法与限制见 [本轮操作手册](docs/UART_IR_ALBUM_20261020.md)。历史数值只代表各自冻结版本，不能验收当前源码；没有整体+0.5ns签核。
> **2026-10-19 转场扩充：仅第一阶段已通过软件/内部时序门禁，尚未实板验收。** 80源/40IO静态检查、102项ModelSim通过；SWNS +0.116ns、HWNS +0.030ns，STNS/HTNS均0。SW第3、4路同时ON后，每次换图依次轮播淡入淡出、滑动、擦除、圆形、棋盘。二维Ken-Burns受两行缓存与禁止修改SDRAM的约束冲突而未实现，FFT按指定顺序尚未启动；本轮无新bit，旧bit不含这些修改。见[操作、原理与未完成项](docs/TRANSITIONS_ZOOM_FFT_20261019.md)。

> **历史：2026-10-19 旧上板验收包（不匹配当前源码）：已生成当时版本的候选 bit，尚未下载或完成实板验收。** 635,444字节；生成前后SWNS +0.044ns、HWNS +0.024ns、STNS/HTNS均0，原80源/101项回归基线不变。已准备7份BMP、1份WAV和四项实板记录；**该前置规则属于旧任务；本轮按新版统一附件执行转场，实板仍待验。** 见 [逐步验收教程](docs/BOARD_ACCEPTANCE_640_20261019.md)、[本次准备结果](reports/board_accept_20261019/RESULT.md)、[候选bit](reports/board_accept_20261019/candidate/hdmi_640_plain_800_audio.bit)。默认640无HDMI音频，实际800保留图声。

> **历史：2026-10-19 640 加密实例替换记录：640 加密实例已替换为明文 TMDS 纯视频核，800 保留原 HDMI 图声；独立 EDID 协商保留。** 静态检查80源/40IO、101项ModelSim及综合/布局布线/内部STA通过。物理LUT 15,785、BRAM 41；SWNS +0.044ns、HWNS +0.024ns，STNS/HTNS均0。资源降低但setup裕量较上一版减少；未达到整体+0.5ns。**默认640不发送HDMI音频，听WAV需R切到实际800×600；EDID回退640也无声。** 未生成本轮bit、未上板，外部IO和既有物理警告仍待核对。详见 [本轮说明](docs/HDMI_SELFWRITE_640_20261019.md) 与 [实际报告](reports/hdmi_selfwrite_20261019/RESULT.md)。

> **历史：2026-10-19 替换640核前的时序优化：98项ModelSim全通过，综合/布局布线及内部STA通过。** SWNS +0.131ns、STNS 0.000ns、HWNS +0.022ns、HTNS 0.000ns。WAV接收寄存级与独立会话增量布线/hold修复已落地；100MHz、全部功能、KEY/SW、官方IP和70位状态布局保留。未生成本轮新bit、未上板；外部IO与既有物理警告仍待核对，未达到整体+0.5ns。[本轮原始结果](reports/timing_close_20261018/RESULT.md)。此前各段数值只属于各自冻结历史版本。

> **历史：2026-10-18 FAT32 比较器验证：94 项回归通过，内部 STA 仍失败，未生成本轮 bit。** 最终 SWNS -0.592ns、STNS -1.362ns、HWNS +0.024ns、HTNS +0.000ns。全部功能及操作保留；内部 removal 不是 HDMI 管脚 hold，未达到整体 +0.5ns。[本轮报告](reports/fat32_compare_20261018/RESULT.md)；以下数值属于各冻结历史版本。

> **历史：2026-10-18 构建修复：93项回归通过，STA仍未通过，无本轮新bit。** 前向声明修复、行地址拆拍和报告归档保护已落实。当前SWNS -0.592ns、HWNS +0.024ns；SDRAM物理警告仍待解决。全部功能和KEY/SW操作保留，未达到整体+0.5ns。见[实际报告](reports/build_repair_20261018/RESULT.md)和[技术说明](docs/BUILD_REPAIR_20261018.md)；下文较早数值只适用于各自冻结的历史版本。

> **历史：2026-10-18 深度优化：91项回归通过，整机验收未完成，无本轮新bit。** 综合16,572 LUT，物理17,347 LUT（88.51%，仍超85%目标）；58 BRAM（90.625%）。SWNS −0.402ns（复位recovery），普通setup −0.401ns，HWNS +0.021ns。77源/40 IO静态检查通过。全部功能和原操作保留；旧bit不能验收当前源码。详见[本轮验收](reports/deep_opt_20261017/RESULT.md)与[技术说明](docs/DEEP_OPTIMIZATION_20261018.md)。


> 2026-10-17 贪吃蛇增量：G 进入/退出，方向键移动，退出后再进入重开。游戏期间方向键暂停翻图/调音量功能；KEY/SW 保留原功能。操作与资源/验收限制见 [贪吃蛇手册](docs/SNAKE_GAME_20261017.md)。当前仍为物理验收未完成的实验源码，旧 bit 不包含游戏。

> **2026-10-17 当前源码为OSD/波形实验版：75源/40IO静态检查、85项ModelSim通过；物理实现与时序未通过，未生成本轮新bit。** SW3/4增加原图/反色/Sobel/热成像，O统一开关状态OSD/玻璃/波形。操作、算法和失败路径见[本轮手册](docs/OSD_AUDIO_VISUALIZER_20261017.md)。下文旧native50候选及其正时序只代表修改前版本，不能验收当前源码。

面向HX4S20C板卡、Anlogic EG4S20BG256，使用TD 6.2.1构建、ModelSim 10.1c回归。TF卡根目录BMP/WAV → FAT32只读映射 → 图片缩放/SDRAM双缓冲与PCM异步队列 → OSD/字幕/转场与HDMI_B音频视频输出。

本轮源码增加PS/2控制、多媒体索引、R运行切输出模式、F目标换图频率。**当前是否通过整机STA、对应哪些测试、是否有新bit，以[构建状态](docs/BUILD_STATUS.md)及匹配源码哈希的报告为准。没有实板出图、出声或吞吐完成声明。** 历史bit不包含本轮全部功能。

## 从哪里开始

- [键盘与新功能逐步使用](docs/KEYBOARD_USAGE_20261016.md)：接线、每个键、R/F、目标频率与实际速度的区别。
- [KEY与SW详细操作](docs/KEY_SW_OPERATION.md)：不接键盘也能换图、调亮度/对比度、静音/音量、字幕和转场。
- [完整接线教程](docs/CONNECTION_AND_USAGE.md)、[用户手册](docs/USER_GUIDE.md)、[FAT32复制文件](docs/FAT32_USAGE_20261015.md)。
- [多文件索引原理](docs/MEDIA_INDEX_20261016.md)、[本轮限制与后续工作](docs/KEYBOARD_REMAINING_20261016.md)。
- [F盘视频格式转换器与合并检查](docs/F_DRIVE_VIDEO_MERGE_20261021.md)：AVF 文件准备工具已纳入；F 盘视频播放 RTL 源码缺失，尚未接入播放链路。

显示器接 **HDMI_B（HDMIB）**；HDMI_A不用。PS/2 CLK=M16、DATA=K16是官方例程的FPGA封装映射；普通USB键盘不能直接接这两个信号。SD正式接口为 **原生四位SD，CMD6自动协商25/50MHz**，主控制100MHz。支持并确认切换成功才升50MHz；不支持/busy留在四位25MHz。该历史检查点80项逻辑回归及内部STA通过；当前98项与STA见页首；卡模型吞吐22.34MB/s不是实体卡实测。仍用原TF卡槽，六线映射和10kΩ上拉已核对。

## 现在能做什么

| 功能 | 实现和边界 |
|---|---|
| 图片 | 正高度24bit BI_RGB BMP，DIB40/108/124，宽1～1920、高1～1080；保比例双线性缩放并居中补黑 |
| 显示 | VGA640×480，25MHz/约59.524Hz；EDID支持时SVGA800×600，40MHz/约60.317Hz；R安全切档、重新加载 |
| 小素材 | 320×240图片可缩放到VGA；R的0档仍为VGA，不增加320×240 HDMI时序、不自动降低大图源读取量 |
| 多文件 | FAT32根目录BMP+WAV合计最多64份，按目录项顺序；支持碎片和有效28bit簇号，不按名称排序 |
| 选择 | 左右遍历全部图片；数字0～9选前十图；A后2秒内数字选前十WAV，Esc取消 |
| 自动换图 | 空格/KEY开关；F循环目标1/2/5/10/15/30次每秒，默认5；忙时等一次，不积压连跳；TARGET/L显示目标及受限记录 |
| 画面调节 | KEY亮度−64～+64、步长8；对比度0.50～2.00、步长0.25；菜单可选暗部伽马提亮 |
| OSD与字幕 | 文件计数、装载与音频错误、欠载；O整帧开关状态OSD；SW独立控制内置字幕、滚动、运行时间和转场 |
| WAV（仅实际800输出声音） | 48kHz/16bit/单声道PCM，≤16MiB；HDMI左右同声；默认不静音、音量08；上下/M或KEY菜单控制 |
| 音频恢复 | 格式/SD/长度/chunk错误可区分；失败等待1秒再解析，错误历史到真实PCM恢复才清；切WAV排空旧事务、清FIFO和音效历史 |
| 可选音效 | FIR低频/高频增益与单次延迟回声固定参数profile；默认增益0，保持等延迟旁路，不新增运行调参或硬件音频口 |

数字输入从0开始，OSD从1开始。没有两位数输入；第11份以后的音频暂无键盘直达。设置复位/断电不保存。卡内容改变后应复位；不支持热插拔自动重扫、子目录、exFAT、JPEG、MP3、44.1kHz/立体声WAV或1080p输出。

## 数据为什么不会写到正在显示的那一帧

图片解析/缩放器先写非显示缓冲；写完全部像素后发提交toggle，视频域只在场消隐接收，返回真实确认后才能复用旧缓冲。缓冲槽按最大800×600固定分配。读取出错不提交半帧，切帧确认超时保持保护，不能把超时当成功。

SDRAM读调度优先保持显示FIFO库存，后台写入有背压；显示欠载时以安全底色完成该帧并在下帧重新对齐。SD扇区CRC16失败按错误处理。此策略和仿真能验证错误保护行为，不能代替实体板白条/撕裂排查、SDRAM刷新和HDMI接收端测量。

R由永久启动时钟域控制：停消费者→各域复位→专用全局时钟复用器选25/125或40/200MHz→等待稳定→同步释放→重新挂载/重载。控制寄存器单独复位，R不会清掉自己的请求。EDID能力与用户请求分离，能够从SVGA切回VGA；不支持800×600时回退VGA。模式重启后自动轮播暂停，需再按空格。

## 文件与模块职责

| 文件/目录 | 作用 |
|---|---|
| `src/top.v` | 唯一活动顶层，时钟/复位、KEY/SW/PS2控制、CDC、媒体/显示/音频链连接 |
| `input/ps2_keyboard.v` | PS/2同步滤波、11bit帧、奇校验、E0/F0/Pause和超时恢复 |
| `input/ps2_controls.v` | 扫描码到事件、按住防重复、A+数字等待，事件和数据同拍流水 |
| `control/picture_controls.v` | KEY短长按、播放/亮度/对比度/菜单与唯一音量静音状态；接键盘音量事件 |
| `control/switch_controls.v` | SW同步消抖，字幕、滚动与转场模式 |
| `sd/spi_master.v` | 旧兼容profile的SPI字节收发；正式native profile不使用 |
| `sd/sd_card_cmd.v` | 命令、token、扇区CRC、等待超时；独热按位译码缩短100MHz控制路径 |
| `sd/sd_card_sec_read_write.v`、`sd_card_top.v` | 扇区封装选择原生/旧SPI兼容profile；正式选择原生四位 |
| `sd/sd_read_arbiter.v` | 图片/音频共享扇区通道、等待授权、超时与事务恢复 |
| `sd/sd_fat32.v` | MBR/BPB几何校验、根目录、BRAM索引、两流FAT缓存/簇链与取消排空 |
| `bmp/sd_card_bmp.v` | 总播放器调度：选文件、忙时请求、WAV切源、加载/提交和自动换图消费者 |
| `bmp/bmp_read.v` | BMP头和行步长校验、文件扇区请求、缩放路径调度 |
| `video/bmp_scale_loader.v` | 双行缓存、保比例坐标、双线性插值、补边、逐像素背压 |
| `video/video_mode_control.v` | 启动域模式控制，先复位后切时钟、EDID回退 |
| `control/fps_control.v` | 目标换图周期、忙时等待与受限标志；不改变HDMI刷新时序 |
| `video/adaptive_video_clock.v`、`adaptive_raster.v` | 两组固定PLL输出选择、两档有效区/消隐时序 |
| `video/picture_adjust.v`、`picture_gamma.v` | 亮度/对比度饱和与可选伽马LUT |
| `video/frame_swap.v`、`transition_pixels.v` | 消隐切帧、逐帧效果参数、淡出淡入/滑动；不声称两张全帧同时alpha融合 |
| `osd/caption_overlay.v`、`status_osd.v`、`osd_char_rom.v` | 字幕、计时与状态字符像素流水，视口适配 |
| `memory/` | SDRAM突发调度、FIFO读写、帧尾对齐、背压与诊断 |
| `audio/audio_wav.v` | RIFF/chunk解析、格式约束、扇区缓存、错误分类和延时重试 |
| `audio/audio_async_fifo.v` | PCM跨100MHz到像素域，格雷指针、各域复位释放 |
| `audio/audio_playback.v` | 48kHz均匀调度、预填、欠载静音、音量/饱和、真实PCM标记 |
| `audio/audio_effects.v`、`audio_effects_stream.v` | FIR/回声与切源清历史，保持HDMI采样valid节奏 |
| `common/reset_sync.v`、`cdc_snapshot.v` | 各域复位与多位一致性快照；旧70bit状态布局保持，新增状态走独立快照 |
| `hdmi/`、`src/ip/` | HDMI物理包装与必要官方HDMI/PLL/FIFO/SDRAM IP，禁止当重复源删除 |
| `sd/native/` | 已接正式顶层与TD源清单的原生四位SD25/50MHz、CMD6协议、PHY和封装 |
| `src/constraints/` | 唯一pin.adc与timing.sdc；外部IO预算仍需板级资料 |
| `scripts/design_files.txt` | 正式源清单，两TD入口/CLI构建保持一致 |
| `sim/`、`scripts/run_tests.ps1` | ModelSim激励和全量执行；镜像脚本只写电脑普通文件 |
| `reports/`、`legacy/` | 构建/实验冻结证据、未启用历史参考源 |

表中模块相对`src/modules/`；更完整逐源索引见[源文件地图](docs/SOURCE_MAP.md)。外部尚未登记的像素特效/玻璃OSD实验不属于本轮正式管线。

## 构建和验证

```powershell
cd E:\fpga
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
```

TD打开根目录`video_improve.al`，或`src/td_project/video_improve.al`；两者引用相同源码。CLI自动冻结输入哈希、归档旧报告、检查新综合/布线/STA，构建过程中不要改src/scripts/sim输入，也不要并发运行共享仿真库的专项。

不能只看工具进程退出或COMPLETED文字：必须核对SWNS/STNS/HWNS/HTNS及源码哈希。内部复位recovery/removal不是HDMI管脚hold；当前没有整体+0.5ns完成声明。Speed=NA、外部SD/DDC/TMDS时序与已有PHY位置/局部时钟警告仍需核对。未满足板级条件前不自动下载、不写实体卡、不替换必要官方IP。

## 本轮候选文件

**历史版本**内部STA通过的[候选bit](reports/keyboard_20261016/video_improve_native50_delivery.bit)已导出，尚未下载或实板验收。校验值、对应源码及实际时序见[构建状态](docs/BUILD_STATUS.md)。
