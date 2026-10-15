# HX4S20C HDMI 图片与 WAV 播放工程

2026-10-15 FAT32 v1：正式顶层读取普通FAT32卡根目录，直接复制最多4个BMP和第一个WAV，支持碎片簇链。无需裸镜像烧卡；KEY/SW与媒体格式要求保持。操作见[FAT32拷贝文件教程](docs/FAT32_USAGE_20261015.md)，实际回归/STA见[本轮结果](reports/fat32_20261015/RESULT.md)。旧裸扇区版的制卡方法与bit不适用于此版本。

当前验证：静态与61项回归通过，综合/布局布线完成；STA**未通过 setup 时序验收**（SWNS -0.695ns，HWNS +0.021ns）。详见本轮报告，不能使用旧bit验证普通文件拷贝。


以下10月14日及更早的构建数值、裸镜像操作和候选链接是历史记录；当前状态以本轮报告为准。


2026-10-14 音频恢复修复：WAV失败后等待一秒自动重试，OSD保留具体错误原因并显示欠载记录，仍只用KEY/SW。57项ModelSim回归、静态检查及综合/布局布线通过；SWNS **+0.118ns**、HWNS **+0.021ns**，STNS/HTNS均0；LUT12976、REG8547、BRAM9K57/64、DSP17、PLL2。未达到整体+0.5ns，内部复位removal不是HDMI管脚hold，未上板出声验证。详见[音频恢复操作与设计](docs/AUDIO_RETRY_20261014.md)和[构建状态](docs/BUILD_STATUS.md)。本轮候选为[video_improve_audio_retry.bit](reports/audio_retry_20261014/video_improve_audio_retry.bit)，下文旧候选仅为历史对照。

2026-10-14 WAV增量：TF卡48kHz/16bit/单声道PCM经现有HDMI_B音频口输出，默认静音；KEY3长按菜单新增AUDIO MUTE、VOLUME DOWN、VOLUME UP，KEY/SW原功能保留。 使用步骤见[WAV音频手册](docs/WAV_AUDIO_20261014.md)，当前61个设计源、36位IO。最新候选、回归和时序见[构建状态](docs/BUILD_STATUS.md)。下面早先板载版本的数值与bit属于历史对照。

2026-10-14早先板载增量升级：仅用现有板载KEY/SW控制。KEY3短按释放保留PLAY/BRIG/CONT，长按约1.1秒开关菜单，KEY1上/KEY2下/KEY3短按确认播放、伽马、诊断及诊断页。增加视频心跳看门狗和上电保持，优化缩放/BMP验证及写FIFO启动边界。操作见[KEY/SW教程](docs/KEY_SW_OPERATION.md)，原理与范围见[本轮优化](docs/BOARD_OPTIMIZATION_20261014.md)，当前候选、47项回归和实际STA统一见[构建状态](docs/BUILD_STATUS.md)。下文10月13日及更早候选是历史对照。

早先WAV候选（不含自动恢复）：[video_improve_wav_audio.bit](reports/wav_audio_20261014/video_improve_wav_audio.bit)，54项完整回归及刷新/欠载专项通过，综合与布局布线完成；SWNS **+0.175ns**、HWNS **+0.022ns**，TNS均0。LUT13063、REG8490、BRAM9K57/64、DSP17、PLL2。未达到整体+0.5ns，内部复位检查不能当HDMI管脚hold；未上板出声验证。详见[构建状态](docs/BUILD_STATUS.md)。使用[图片＋WAV示例镜像](assets/audio_20261014/pictures_and_audio.img)，先KEY3长按菜单，KEY2到AUDIO MUTE，KEY3短按切OFF。

**板上操作入门：[KEY与SW详细操作教程](docs/KEY_SW_OPERATION.md)**，可直接照着完成换图、自动播放、亮度/对比度、字幕和转场演示。

文档更新：2026-10-13。**第一次接线和运行请先看 [详细接线与使用教程](docs/CONNECTION_AND_USAGE.md)**，其中有接口连接图、完整管脚表、制卡命令、TD下载步骤、拨码/按键操作和逐项排障。需要快速查命令时看 [用户手册](docs/USER_GUIDE.md)。本README侧重解释设计和各模块职责。

**显示器连接开发板的 HDMI_B（HDMIB）口，HDMI_A 本工程不用。** 已核对官方lab_ex4_tf/lab_ex5_i2s说明及相同的HDMI管脚位置；视频与WAV音频均经B口输出。

面向安路 EG4S20BG256，从普通 FAT32 TF/SD 根目录读取 BMP/WAV（支持碎片簇链），通过合封 SDRAM 双缓冲和 HDMI 核显示。当前为待实板验证候选。当前源码支持启动时选择640×480/800×600；最新验证及候选bit见 [构建状态](docs/BUILD_STATUS.md)。旧缩放bit只支持640×480，不能代表屏幕自适应版。

2026-10-08 历史更新：择优合并 `E:/2/fpga` 的 SD 超时/初始化重试、BMP 扇区停滞检测、EDID 超时及单比特同步器标记；保留本地 FIFO 诊断。拒绝把切帧超时当成功，改成保护缓冲区并等待真实确认。21项模块回归、1项官方PLL模型、8项主机工具测试通过，已完成新综合、布局布线。两个 TD 工程入口均实际打开验证；仍引用同一套44个设计源。

10月14日早先板载版本（历史）final STA：SWNS **+0.110ns**、HWNS **+0.022ns**，STNS/HTNS均为0。47项ModelSim回归及刷新、欠载恢复两个专项通过。[该历史候选bit](reports/board_opt_20261014/video_improve_board_opt.bit)已生成并核验，尚未上板。最差max/min分别是内部recovery/removal，不是HDMI管脚hold；未达+0.5ns，整体余量未优于基线。资源LUT11452、REG7486、BRAM9K46/64、DSP16、PLL2。详见[构建状态](docs/BUILD_STATUS.md)。[10月13日候选](reports/display_fix_20261013/video_improve_display_fix.bit)保留为历史对照。

10月8日取舍见 [合并记录](docs/TEAM_MERGE_20261008.md)、[构建记录](reports/build_manifest.json) 和 [核验结果](reports/team_merge_20261008/verification.json)。10月7日 +0.834/+0.004 ns 及更早结果都是历史证据。图片工具见 [适配报告](docs/OFFICIAL_ADAPTATION_20261007.md)，操作见 [用户手册](docs/USER_GUIDE.md)，PLL/IO 核查见 [修订记录](docs/REVISION_20261004.md)。

## 2026-10-13：静止画面与读卡修复

修正刷新间隔宏的整数运算和计数边界；按实际返回字数排空读突发，显示 FIFO 低于384字时延后后台写入。欠载当帧使用安全底色并在下一帧重新对齐，粘性欠载/溢出汇总进 `LOAD:E`。SD 读取新增 CRC16 校验，坏扇区不提交新帧。100MHz BMP/缩放控制路径增加寄存级和独热状态编码，以实际 P&R 结果验收。官方加密 IP 保留；音频硬件暂缓。

## 2026-10-11：图片、OSD与显示模式一起适配

先接好HDMI_B、打开显示器，再启动或复位。FPGA校验EDID基础块，明确声明支持800×600@60时选择800×600，否则回退640×480。图片保比例居中；左上OSD、右上时间和底部字幕一起按视口适配。OSD箭头右侧显示实际输出尺寸，SRC显示原图尺寸。详细范围与验收步骤见 [屏幕适配手册](docs/SCREEN_ADAPTATION_20261010.md)。

这是启动时的两档选择，不是1080p输出，也不支持热插拔自动重协商。EDID无效时的640×480回退不保证所有显示器接受；25MHz VGA并非标准25.175MHz。1920×1080显示器可能把4:3信号拉伸，建议在显示器菜单选择保持比例。

## 可变尺寸缩放与实体参数调节

读取宽1～1920、高1～1080的正高度24位BMP，在FPGA内保比例双线性缩放到所选640×480或800×600视口、居中补黑边；支持行尾填充、非整数比例、放大和缩小。不同尺寸BMP可直接复制到同一FAT32根目录，最多4张。缩放使用扇区/双行缓存及带背压写FIFO，不增加原始大图整帧BRAM。

保留四路SW的字幕、滚动、转场控制；B1对应key3选择PLAY/BRIG/CONT，PLAY状态B2下一张、C1自动播放；BRIG/CONT状态B2减、C1加。亮度−64～+64，步长8；对比度0.50～2.00，步长0.25。OSD显示原图尺寸、亮度、对比度和操作项，参数在帧边界统一生效。UART/NEC仍禁用；当前WAV默认静音，可通过板载菜单解除。

使用 [详细手册](docs/SCALING_AND_PICTURE_CONTROLS_20261010.md)、[测试BMP/转换脚本](assets/multires_20261010/README.md)、[历史640×480缩放候选bit](reports/scaling_20261010/video_improve_scaling.bit)。旧SW/effects.bit保留，不能代表本次功能。

10月10日历史验证：30项模块回归、10项主机工具测试通过；九种尺寸每帧307200个像素核对独立参考；调参测试穷举256通道值×17亮度×7对比度。综合/P&R完成，LUT8849、REG5344、BRAM9K33、DSP13、PLL2。两工程51个源、36位逻辑IO一致，[源码/产物核验](reports/scaling_20261010/verification.json)。未写卡、未烧录、未上板验证。

字幕仍是三条内置ASCII标语和运行时间，转场仍是经过黑场的淡出淡入/滑动及交替模式。双线性不是大比例缩小的抗混叠滤波；本轮在缩放后的图片层增加可选伽马提亮，插值本身仍在RGB码值空间进行。时间不是实时时钟。

## 功能

输出两档：640×480使用25/125MHz、800×525总时序、约59.524Hz；800×600使用40/200MHz、1056×628总时序、约60.317Hz。VGA并非标准25.175MHz。最多索引4张正高度、24位BI_RGB BMP；DIB长度40/108/124，planes=1，像素偏移54～4096且位于完整头之后，文件长度为偏移加对齐行步长×高度。支持FAT32根目录短名和碎片簇链；不支持子目录、exFAT、JPEG、压缩音频或视频文件。WAV限PCM/48kHz/16bit/单声道。

支持双缓冲场消隐提交、按键/SW、OSD、字幕和转场。亮度/对比度已开放实体调节，测试图保持关闭。音频读取根目录第一个WAV，沿FAT簇链访问，左右相同、24bit HDMI接口，默认静音，菜单可解除并调音量。N=6144、CTS=25000/40000保持原样。可变尺寸加载预算15秒，提交确认预算5秒；历史UART应答队列16项未接入；当前视频缓冲64像素，不能承受无限背压。

SD初始化每次尝试约8秒，失败暂停约1秒并复位底层后重试。FAT32挂载失败显示错误，修正卡后整机复位；不支持运行中热插拔。已有索引的图片加载失败保留旧显示帧，可按KEY1换图重试。切帧确认超时会报错并保持忙，不允许覆盖可能仍在显示的缓冲区；真实迟到确认可完成，否则需整机复位。

## 先认识这个系统

这是一套用FPGA实现的两档输出模式图片播放器。Verilog描述同时工作的电路，不是由处理器按源文件顺序逐行执行的程序。SD读卡、SDRAM读写、像素输出和控制命令能够同时推进，模块之间用时钟、握手和FIFO协调。

```text
50 MHz晶振 ── sys_pll ── 100 MHz控制/SD、40 MHz内存、40 MHz内存相移时钟
           └─ adaptive_video_clock ── 25MHz启动时钟；全局切换25/125或40/200MHz

SD卡 ─ SPI字节 ─ 扇区协议/仲裁 ─ FAT32目录/簇链 ─ BMP解析/缩放 ─ 写FIFO ─ SDRAM备用帧
                                                        │ 写完、提交请求
                                                        ↓
                                            frame_swap在场消隐换帧并确认
                                                        │
SDRAM显示帧 ─ 读FIFO ─ 像素/同步对齐 ─ 亮度/对比度/转场/OSD ─ RGB视频队列
                                                        │
FAT32 WAV ─ RIFF解析/扇区缓存/异步FIFO/48kHz音量 ─ PCM/ACR ─────────────────────── 官方HDMI核
                                                        │ 10位TMDS符号
                                                   串行器 ─ HDMI

按键/SW ─ 同步与消抖 ─ 加载/自动播放、字幕、滚动、转场、亮度/对比度
控制与状态 ─ cdc_snapshot ─ 视频时钟域中的画面与声音设置
```

新增三个设计源：

| 文件 | 职责 |
|---|---|
| [edid_display_mode.v](src/modules/video/edid_display_mode.v) | 校验EDID并识别800×600@60，超时或无匹配模式回退VGA |
| [adaptive_video_clock.v](src/modules/video/adaptive_video_clock.v) | 专用PLL提供四路频率，CSB全局资源成对切换；启动时钟保持25MHz |
| [adaptive_raster.v](src/modules/video/adaptive_raster.v) | 产生所选模式的同步、消隐及有效区 |

### 时钟、复位和数据格式

| 时钟/信号 | 当前频率或格式 | 使用位置 |
|---|---|---|
| 顶层 `clk` | 50 MHz，20 ns周期 | 两个PLL的参考 |
| `sd_card_clk` | 100 MHz | SD协议、BMP、SW、按键、播放控制、数码管 |
| `ext_mem_clk` | 40 MHz | 帧读写调度与SDRAM控制器 |
| `ext_mem_clk_sft` | 40 MHz相移输出 | 官方内存接口；相位需结合模型/板卡验证 |
| `video_clk` | 25或40 MHz | 光栅、OSD、视频流、音频采样事件、HDMI核 |
| `hdmi_5x_clk` | 125或200 MHz | TMDS串行器，DDR发送形成10倍像素比特率 |
| SD扇区 | 512字节 | 卡的读写单位，不是文件系统目录 |
| BMP像素 | B、G、R各8位 | 解析器按字节装配为24位RGB |
| SDRAM像素字 | `{R,G,B,8'b0}` | 每像素占32位；显示取 `[31:8]` |

100 MHz是SD控制逻辑时钟，不是卡管脚SPI时钟。当前SPI分频公式为 `100 MHz / ((DIV+2)×2)`；初始化DIV=248约200 kHz，正常DIV=0约25 MHz。

`rst_all`由低有效复位输入、两路PLL锁定状态和`board_supervisor`产生：锁定后保持10ms，运行后2秒无视频心跳则软复位。各域通过`reset_sync`同步释放。写入侧还有独立错误复位，中止失败写入而保留显示读取；FIFO包装层等待内部写复位释放后才给ready，它不替代双缓冲所有权协议。

640×480一帧为307,200像素。BMP像素负载921,600字节，常见54字节头版本共921,654字节，占1,801个扇区。SDRAM按32位像素保存，每帧1,228,800字节，两帧2,457,600字节。800×600一帧480000个32位字，两帧3.66MiB。当前两个缓冲区固定从0和480000字地址开始，按最大模式预留；字地址不是字节偏移。旧BUF1_ADDR参数已不控制当前连接。

### 图片从卡到屏幕的过程

1. SD初始化，根据CMD8、OCR/CCS确认支持的卡与寻址方式。
2. `sd_fat32`挂载FAT32、遍历根目录短名条目，记录前4个BMP和第一个WAV的首簇与大小。碎片文件沿FAT簇链读取。
3. 枚举结束，控制器按文件索引选备用缓冲区，BMP解析器从文件内第0扇区校验头，新加载器按需读行并缩放成所选视口的输出像素。
4. 写FIFO把100 MHz输入与40 MHz内存接口隔开。写调度器按行翻转地址，纠正正高度BMP从底行开始存储的顺序。
5. 必须同时知道“BMP已送完”和“SDRAM整帧已写完”，才提交换帧请求。
6. 视频域在场消隐更新显示缓冲并返回确认。确认以前，控制端不能随意再次使用该缓冲。
7. 每帧读取显示缓冲，经像素对齐、亮度调整、OSD、HDMI核编码和串行器输出。

根目录遇到00结束项或簇链尾即结束枚举；没有“为寻找第4张而扫描整个64MiB图片区”的步骤。根目录遍历最多4096簇，损坏链会失败退出。

### 功能边界

| 已接入顶层 | 尚未接入或未支持 |
|---|---|
| 不同尺寸BMP缩放为640×480或800×600 RGB输出 | 自动切换到720p/1080p |
| FAT32根目录前4张BMP，支持碎片簇链 | 子目录、长名显示、按字母排序与任意文件选择 |
| 双缓冲、场消隐提交 | 任意取消/撤回已提交的换帧事务 |
| 按键、SW、状态OSD、字幕、转场、板载音量菜单 | 当前未接入UART/NEC控制 |
| 固定原图像素来源 | 坐标渐变模块保留，本版不开放测试图开关 |
| 根目录首个PCM WAV循环、HDMI双声道复制与ACR | 多曲目菜单、MP3/视频解码、外部I2S采集 |
| EDID基础块检查 | EDID模式协商和动态PLL配置 |

当前双线性缩放已接入实际顶层，支持上述范围内的图片尺寸。optional目录中的旧固定参数最近邻缩放、YCbCr转换和多模式表仍未接入；启动时的输出选择由edid_display_mode和adaptive_video_clock完成。

## 模块目录

| 路径 | 内容 |
|---|---|
| src/top.v | 唯一活动顶层 top |
| src/modules/common | 复位、CDC、启动 |
| src/modules/control | SW同步消抖；保留历史UART/红外/应答模块 |
| src/modules/sd、bmp | SD SPI、FAT32文件映射和BMP解析 |
| src/modules/memory | 帧读写调度、SDRAM 包装 |
| src/modules/video、hdmi | 光栅、视频缓冲、串行物理包装 |
| src/modules/audio、osd、display | WAV解析、跨域PCM缓存/播放、字符、数码管 |
| src/modules/optional | 未接入顶层的缩放、模式表、YCbCr |
| src/ip | 官方 HDMI/SDRAM 加密核、FIFO、PLL 和配置 |
| src/constraints | pin.adc、timing.sdc |
| src/td_project | 第二个 TD 工程入口及工具所需头文件 |
| sim、scripts | 测试台、构建和检查 |
| legacy/user_source | 独有历史参考/IP 模板，不参与构建 |
| reports | 验证证据 |

## 每个设计源文件负责什么

下列清单覆盖 `scripts/design_files.txt` 的57个设计源；同一源文件可能定义辅助模块。宏头文件、配置模板及测试台在后文单独说明。

### 1. 顶层和公共基础

| 文件 | 具体职责与连接 | 修改时注意 |
|---|---|---|
| [top.v](src/top.v) | 连接所有外设、PLL、复位、SD/BMP、帧缓存、控制、视频与HDMI；组织EDID选择、两档输出和双帧地址 | 端口改变须同步pin.adc；改时钟/分辨率要同时更新多个模块 |
| [reset_sync.v](src/modules/common/reset_sync.v) | 三段寄存器实现异步断言、目标时钟同步释放复位 | 每个时钟域各用自己的实例；不能共享一个域的释放时序 |
| [cdc_snapshot.v](src/modules/common/cdc_snapshot.v) | 请求/确认握手传送保持稳定的多位状态快照；顶层为67位状态包，含尺寸、调参、字幕/转场、菜单/伽马/诊断 | 不是逐时钟采样、不是任意脉冲队列；两端应协调复位 |
| [startup_pulse.v](src/modules/common/startup_pulse.v) | 复位后延时发一次脉冲；当前100000个固定25MHz启动周期，约4 ms后触发EDID读取 | 不是周期定时器；热插拔不会自动重发 |
| [board_supervisor.v](src/modules/common/board_supervisor.v) | 既有固定25MHz启动域，锁定后保持10ms，每帧VS toggle喂狗，2秒无心跳软复位 | 静止图仍喂狗；不检测VS正常的加载卡死；软复位不复位监督器自身 |
| [board_debug.v](src/modules/common/board_debug.v) | 视频35位/内存20位整体快照，10Hz更新六位数码管，四页编码 | 慢速诊断不是ILA；top.DEBUG_ENABLED=0可裁剪，但须重新构建 |

### 新增缩放与调参源

| 文件 | 功能 | 注意点 |
|---|---|---|
| [bmp_scale_loader.v](src/modules/video/bmp_scale_loader.v) | 动态尺寸、顺序除法、512字节扇区缓存、两行缓存、双线性与补边 | 100MHz插值分差值/乘法/累加流水；输出服从FIFO ready |
| [picture_controls.v](src/modules/control/picture_controls.v) | 三键同步消抖、PLAY/BRIG/CONT、范围限制、长按菜单与伽马/诊断寄存器 | B1短按释放选项，长按开关菜单；B2/C1菜单外执行、菜单内导航；上电按住须先释放 |
| [picture_adjust.v](src/modules/video/picture_adjust.v) | 以128为中心的对比度、亮度、0～255饱和 | RGB/VS/DE/X同延迟两拍；上层帧边界锁存设置 |
| [picture_gamma.v](src/modules/video/picture_gamma.v) | 256×10 LUT实现可选1/2.2指数暗部提亮，再舍入饱和为8位 | 默认OFF；两拍旁路/使能延迟相同，OSD后叠加；不代表显示器校准 |

### 2. 控制与用户输入

当前接入SW和B2/C1/B1三个按键。下表UART/NEC/player_control为保留的历史模块，继续独立回归，不在当前top实例化。

| 新文件 | 职责 | 接入情况 |
|---|---|---|
| [switch_controls.v](src/modules/control/switch_controls.v) | 四路两级同步、20ms整体消抖、保持电平映射 | 当前控制入口，官方C8/C7/C6/C5 |

| 文件 | 具体职责与连接 | 修改时注意 |
|---|---|---|
| [uart_rx.v](src/modules/control/uart_rx.v) | 同步串口RX，过采样解析串行字节，输出数据与有效脉冲 | 历史配置100 MHz/115200，本版未实例化 |
| [uart_tx.v](src/modules/control/uart_tx.v) | 将单字节编码为UART串行帧，报告发送忙 | 历史应答队列底层，本版未实例化 |
| [uart_tx_queue.v](src/modules/control/uart_tx_queue.v) | 缓冲16项回复，驱动uart_tx，记录溢出 | K是命令识别回复，不是图片完成确认；不能承受无限发送速率 |
| [ir_nec_rx.v](src/modules/control/ir_nec_rx.v) | 输入同步与NEC脉宽解码，输出命令、有效及重复码 | 顶层未使用重复码；实际遥控器命令要匹配映射 |
| [player_control.v](src/modules/control/player_control.v) | 把ASCII/NEC映射成上下张、播放、音量、静音、OSD、亮度、测试图控制 | UART有效时优先；默认静音；UART未知字符回? |

按键消抖辅助模块 `key_press_debounce` 定义在 `sd_card_bmp.v` 中，输入先同步再等待稳定约50 ms，只在确认按下时发一个脉冲。它没有单独的源文件，不要为同名模块再添加一个副本。

### 3. SD 卡：从引脚到扇区

| 文件 | 具体职责与上下游 | 当前边界 |
|---|---|---|
| [spi_master.v](src/modules/sd/spi_master.v) | 接收一字节发送请求，分频产生SCLK/MOSI，从MISO采样并报告字节完成 | 顶层包装使用CPOL=1、CPHA=1；不是文件读取器 |
| [sd_card_cmd.v](src/modules/sd/sd_card_cmd.v) | 发送SD命令、处理响应、读token和512字节块、写块及busy等待；连接SPI字节接口 | token/写响应/写busy有等待预算；读CRC16匹配才发扇区成功；错误向上层中止加载 |
| [sd_card_sec_read_write.v](src/modules/sd/sd_card_sec_read_write.v) | 组织CMD0/8/55/41/58/16初始化及CMD17/24扇区访问；区分SDHC块地址与SDSC字节地址 | 初始化约8秒限时、1秒暂停再试；不支持完整SD v1/MMC初始化 |
| [sd_card_top.v](src/modules/sd/sd_card_top.v) | 包装上述两个协议层和SPI，向BMP层提供扇区数据、结束与错误，向外接卡引脚 | 初始化暂停期间复位底层，避免重试与旧传输混杂；写端存在但顶层未启用写卡 |

协议层级是“SPI字节 → SD命令/数据块 → 扇区服务”。出现无卡或缺token时要看错误在哪一层退出、是否传到上层，而不能只给某个底层状态加计数器。

### 4. FAT32文件读取与BMP播放调度

| 文件 | 具体职责 | 重要行为 |
|---|---|---|
| [sd_fat32.v](src/modules/sd/sd_fat32.v) | MBR/BPB挂载、根目录8.3枚举、文件大小检查、碎片簇链映射、双流FAT缓存 | 根目录前4个BMP与首个WAV；只读FAT32，缓存占2个BRAM9K；没有新控制接口 |
| [bmp_read.v](src/modules/bmp/bmp_read.v) | 接收文件枚举数量，按文件索引校验BMP头，申请帧写入；顶层启用运行时尺寸和双线性加载器 | 支持宽1～1920、高1～1080正高度24位格式；有扇区无进度检测；ready不等于SDRAM写完 |
| [sd_card_bmp.v](src/modules/bmp/sd_card_bmp.v) | 管理最多4图索引、上下张、自动播放、写缓冲选择、加载超时、SD错误恢复和跨域提交确认 | BMP送完且写端完成后才提交；确认超时保持忙保护帧，迟到真实ack仍可完成 |

SD故障已中止不代表可以马上重写任意帧。已有索引加载失败保留旧帧；新卡内容变化时应整机复位重扫。OSD错误汇总不提供完整分类错误码。

### 5. SDRAM 与异步 FIFO

| 文件 | 具体职责 | 注意事项 |
|---|---|---|
| [frame_read_write.v](src/modules/memory/frame_read_write.v) | 连接读写调度器和两个异步FIFO，形成100 MHz写端、40 MHz内存域、25/40 MHz视频读端之间的数据桥 | 显示FIFO水位优先、写背压、欠载按帧恢复；粘性诊断接入LOAD:E |
| [frame_fifo_write.v](src/modules/memory/frame_fifo_write.v) | 接受帧写请求、清FIFO、按水位发写入序列、计算地址并输出帧完成 | 当前开启逐行纵向翻转；调整分辨率需核对行尾、帧尾和地址 |
| [frame_fifo_read.v](src/modules/memory/frame_fifo_read.v) | 接受显示帧请求、按读FIFO容量和读写调度取数，结束整帧读取 | 数实际Sdr_rd_en返回，全部完成才释放读端和处理新帧；刷新/忙时延后新突发，硬核契约仍待实测 |
| [sdram.v](src/modules/memory/sdram.v) | 封装厂商内存控制器和合封内存资源，提供App读写接口及初始化/忙信号 | 不应按普通外接SDRAM例子任意改内部绑定 |
| [afifo_16_32_256.v](src/ip/fifo/afifo_16_32_256.v) | 实际顶层模块为 `wfifo_32_32_512`，用于写像素跨时钟缓冲 | 历史文件名不代表当前端口宽度/深度；以模块参数和实例为准 |
| [afifo_32_16_256.v](src/ip/fifo/afifo_32_16_256.v) | 实际顶层模块为 `rfifo_32_32_512`，用于内存返回到视频域的读缓冲 | 不要仅凭文件名以为每次输出16位像素 |
| [sdr_as_ram.enc.v](src/ip/sdram/sdr_as_ram.enc.v) | 官方加密SDRAM控制封装，组织其内部模块 | 必要IP；不能删掉或用空模块替代 |
| [sdr_init_ref.enc.v](src/ip/sdram/sdr_init_ref.enc.v) | 官方初始化/刷新相关逻辑 | 刷新参数依赖global_def.v及时钟 |
| [sdr_wrrd.enc.v](src/ip/sdram/sdr_wrrd.enc.v) | 官方实际读写命令与数据通路 | 对端请求接受和返回时序须以官方契约验证 |

FIFO解决两个时钟域的流量差异，SDRAM保存完整帧，两者用途不同。多位数据不能仅把每一位各加两个触发器就当作安全跨域。元数据也必须在请求/确认期间保持稳定；`async_reg`属性本身不是一致性证明。

### 6. 视频时序、像素与帧交换

| 文件 | 具体职责 | 当前连接情况 |
|---|---|---|
| [color_bar.v](src/modules/video/color_bar.v) | 产生行/场计数、HS/VS/DE，并包含彩条RGB生成 | 实际由video_timing_data使用其时序，彩条RGB端未接；UART的t图不是它的彩条 |
| [video_timing_data.v](src/modules/video/video_timing_data.v) | 基于光栅产生场消隐事件，延后提出新帧读取请求并等待同步确认 | 为换帧更新地址预留时序；不是BMP解析器 |
| [video_delay.v](src/modules/video/video_delay.v) | 延迟HS/VS/DE并提前发读FIFO使能，对齐返回像素 | 当前SYNC_STAGES=21、FIFO_CAPTURE_LATENCY=2；不能理解为官方控制器任意条件都固定21拍 |
| [frame_swap.v](src/modules/video/frame_swap.v) | 同步请求及缓冲号；顶层开启转场状态机，遮黑时切地址、入场完成才返回ack | 首图直接提交；转场模式在事务开始锁定，期间保护两帧所有权 |
| [video_enhance.v](src/modules/video/video_enhance.v) | 保留的旧亮度处理模块，对RGB三通道加有符号偏移并夹到0～255 | 当前顶层使用picture_adjust，同时处理亮度和对比度 |
| [video_rgb_to_axis_640x480.v](src/modules/video/video_rgb_to_axis_640x480.v) | 把固定光栅像素转为valid/ready视频流，生成帧首user和行末last，缓冲64像素 | 光栅不能暂停；溢出后丢输入至安全恢复边界；需满足官方核连续行契约 |
| [edid_base_check.v](src/modules/video/edid_base_check.v) | 检查EDID前128字节头与校验和；约0.671秒无新字节判失败 | 只作诊断；不解析所有显示模式，不修改PLL |

VGA每帧包含800×525个时钟位置、有效640×480；SVGA为1056×628、有效800×600。其余是同步和消隐区。帧率 `25,000,000/(800×525)≈59.524 Hz`。不能只改分辨率宏就把整个系统变成1080p。

AXIS风格握手只有valid与ready同时为1才算传输。下游不ready时要保持输出数据和标记；当前64像素队列只能吸收有限背压，不能代替整帧缓存，也不允许把无限停顿说成已支持。

### 新增：转场与字幕模块

| 文件 | 职责 | 实现边界 |
|---|---|---|
| [video_coordinates.v](src/modules/video/video_coordinates.v) | 跟踪当前输入像素x/y，供测试图和字幕使用 | 像素接受前的坐标，各流水级分别对齐 |
| [transition_pixels.v](src/modules/video/transition_pixels.v) | 淡出系数、行缓存平移与黑场裁剪 | 固定2拍，VS/DE同延迟；不同时读两幅整图 |
| [caption_overlay.v](src/modules/osd/caption_overlay.v) | 运行计时、帧边界快照、逐像素滚动、透明底条/文字叠加 | 固定1拍；ASCII标语，非RTC时间 |

新像素链为：亮度 → 转场（2拍）→ 字幕/时间（1拍）→ 原状态OSD → 视频队列。字幕位于转场之后，换图时仍可阅读。滑动缓存占3块BRAM9K，比例计算占2个DSP；这是本次实际综合结果。

### 7. HDMI 编码与物理发送

| 文件 | 具体职责 | 注意事项 |
|---|---|---|
| [hdmi_1_4b_transmitter_core_wrapper.enc.v](src/ip/hdmi/hdmi_1_4b_transmitter_core_wrapper.enc.v) | 官方加密HDMI核：接收视频流、PCM音频与ACR参数，提供DDC/EDID接口、输出10位TMDS符号 | 两份不同编译参数实例提供640×480/800×600，启动后选一路；WAV默认静音可菜单解除；内部视频锁定输出未接入诊断 |
| [hdmi_phy_wrapper.v](src/modules/hdmi/hdmi_phy_wrapper.v) | 包装三数据通道和时钟通道的串行发送 | 接收核输出的10位符号，不直接接原始RGB |
| [lane_lvds_10_1.v](src/modules/hdmi/lane_lvds_10_1.v) | 单通道10:1串行化，用像素时钟、5倍时钟和DDR原语输出比特流 | PLL相关时钟相位有意义，不能随意当普通异步总线处理 |

P/N配对由管脚约束和工具实现。HDMI核做数字编码，不会替PCB补出正确电阻网络或保证眼图。内部timing通过和显示器接收成功必须分别验证。

### 8. 音频、OSD 与数码管

当前WAV链路和菜单操作见[详细音频手册](docs/WAV_AUDIO_20261014.md)，文件准备见[FAT32教程](docs/FAT32_USAGE_20261015.md)。保留audio_test_source源码用于回退，当前顶层实例为audio_playback。

| 文件 | 具体职责 | 当前效果 |
|---|---|---|
| [sd_read_arbiter.v](src/modules/sd/sd_read_arbiter.v) | 图片/音频共享SD，按扇区锁定授权与返回，音频按FIFO余量优先，超时复位 | 不新增SPI管脚，不把等待授权当图片停滞 |
| [audio_wav.v](src/modules/audio/audio_wav.v) | RIFF块解析、CRC成功扇区缓存、16bit小端组包、循环与背压 | 正式顶层使用文件内相对扇区，48k/16bit/mono，≤16MiB；失败静音并延时重试 |
| [audio_async_fifo.v](src/modules/audio/audio_async_fifo.v) | 1024×24双时钟RAM、格雷码指针及满空保护 | 100MHz写、25/40MHz读；约21.33ms样本 |
| [audio_playback.v](src/modules/audio/audio_playback.v) | 48kHz分数累加、同步读流水、指数增益及24bit饱和 | 欠载送0并预填；0级静音，1..31幅度约51.1%..97.9% |
| [audio_test_source.v](src/modules/audio/audio_test_source.v) | 用相位/采样累加生成平均48 kHz、24位、左右相同的约440 Hz方波 | mute和volume控制幅度；无SD音频读取 |
| [status_osd.v](src/modules/osd/status_osd.v) | 跟踪可见像素坐标，生成40×4文本面板并叠加到RGB | 展示PLAY/IMG/LOAD/EDID/VOL/MUTE；也给顶层测试图提供坐标 |
| [osd_char_rom.v](src/modules/osd/osd_char_rom.v) | 将ASCII字符与字形行号映射为点阵 | 固定字库，不是操作系统字体；新增字符要补字形 |
| [seg_decoder.v](src/modules/display/seg_decoder.v) | 将4位状态码转换为七段段码 | 段顺序和有效电平要匹配板上电路 |
| [seg_scan.v](src/modules/display/seg_scan.v) | 循环选通六位数码管，输出对应段码 | 顶层仅最后逻辑位给出状态，其他留空 |

音频PCM与ACR确实已接入官方HDMI核。顶层N=6144、CTS=25000/40000，按 `Fs=F_TMDS×N/(128×CTS)` 和25/40 MHz TMDS时钟分别对应48 kHz。这里F_TMDS指时钟通道频率，不是250 Mbit/s单通道串行速率。硬件音频输出仍需上板验证，当前WAV行为链路已新增，但不能把模块仿真当作实板音频出声验收。

### 9. PLL 和未启用扩展

| 文件 | 职责 | 当前状态 |
|---|---|---|
| [sys_pll.v](src/ip/pll/sys_pll.v) | 50 MHz参考生成100/40/40 MHz系统时钟 | 已接入；NOCOMP/VCO手工核查配置，需复核硬件环路 |
| [video_pll.v](src/ip/pll/video_pll.v) | 生成25/125 MHz视频及串行时钟 | 历史包装仍保留；顶层现用adaptive_video_clock，不能误改此文件期待输出变化 |
| [video_scaler.v](src/modules/optional/video_scaler.v) | 单行缓存、编译时固定参数的最近邻缩放参考 | 未接入顶层；当前实际缩放由bmp_scale_loader完成 |
| [video_mode_table.v](src/modules/optional/video_mode_table.v) | 640×480、720p、1080p、800×600参数查表 | 未接入；不能发一条命令就自动切视频模式 |
| [ycbcr_to_rgb.v](src/modules/optional/ycbcr_to_rgb.v) | YCbCr到RGB定点色彩变换 | 未接入；当前BMP已经输出RGB |

启用扩展至少要同时设计像素速率、内存容量/带宽、握手、分辨率参数和PLL策略，并补充仿真。文件已在工程列表中不等于有硬件实例正在运行。

## 头文件、约束、工程和脚本的区别

| 文件/目录 | 作用 | 使用建议 |
|---|---|---|
| [pin.adc](src/constraints/pin.adc) | 管脚、IO电平、上下拉、驱动强度 | 换板先核对原理图，不凭软件猜排针编号 |
| [timing.sdc](src/constraints/timing.sdc) | 时钟及路径时序约束 | 不是ADC；不能加假delay/false path抬高余量 |
| [video_define.v](src/modules/video/video_define.v) | 编译期选择当前视频模式 | 有工具入口副本；不能仅改此宏而不改顶层HDMI参数 |
| [global_def.v](src/modules/memory/global_def.v) | SDRAM数据/地址位宽、40 MHz刷新时序宏 | 根目录、内存/IP、TD入口等副本须一致 |
| [video_improve.al](video_improve.al) | 根TD工程，保存目标器件、源与约束列表 | 推荐日常打开此入口 |
| [第二TD入口](src/td_project/video_improve.al) | 同一设计的另一入口，使用相对路径 | 不需要同时添加两个顶层 |
| [design_files.txt](scripts/design_files.txt) | 57个设计源的统一核对清单 | 添加设计源时与两个.al同步 |
| [static_check.py](scripts/static_check.py) | 核对源列表、模块唯一性、头文件、36位IO与约束 | 不等于HDL仿真或时序分析 |
| [run_tests.ps1](scripts/run_tests.ps1) | 编译ModelSim测试并检查47项通过标志，含六项板载升级测试 | 测试台不能加入综合源集 |
| [run_pll_test.ps1](scripts/run_pll_test.ps1) | 使用官方PLL模型测试频率与锁定 | 不验证实物抖动/环路 |
| [synth.tcl](scripts/synth.tcl) | 打开工程、展开顶层、综合、输出gate数据库和面积 | 综合不是布局布线 |
| [implement.tcl](scripts/implement.tcl) | 布局、布线、final STA和设计/时序检查 | 看报告和警告，不只看结束标志 |
| [run_build.py](scripts/run_build.py) | 串起检查、综合、实现，归档旧结果并绑定SHA-256 | 正式构建推荐入口 |
| [open_check.tcl](scripts/open_check.tcl) | TD工程打开检查 | 只打开成功不代表编译成功 |
| [bitgen_after_sta.tcl](scripts/bitgen_after_sta.tcl) | 导入routed DB，检查内部STA后生成候选bit | 不自动证明数据库与源码一致，不代替板级审核 |
| [prepare_media.py](scripts/prepare_media.py) | 图片转换、BMP检查、连续扇区IMG打包和核验 | 只操作普通文件，不直接写卡 |
| [test_prepare_media.py](scripts/test_prepare_media.py) | 10项主机工具测试 | 验证格式、颜色/方向、不同尺寸混合打包与拒绝错误输入等 |
| [experiment_hdmi_reset_margin.tcl](scripts/experiment_hdmi_reset_margin.tcl) | 历史复位裕量试验 | 不属于正式默认构建，不把trial结果冒充正式结果 |
| [review_team_merge.py](scripts/review_team_merge.py) | 对比本地与E:/2/fpga，输出差异 | 再运行会更新比较证据，不是日常启动步骤 |
| [backup_team_merge.py](scripts/backup_team_merge.py) | 为10月8日合并创建特定备份并校验 | 非通用定期备份工具；已存在目录时拒绝覆盖 |
| [legacy_files.txt](scripts/legacy_files.txt) | 历史文件子集记录 | 不是当前综合源清单 |
| `src/ip`内的IPC/VHDL/Tcl模板 | IP参数、其他语言模板和生成配置 | 非全部参与当前编译；手工补丁不等于重新生成验证 |
| `sim` / `reports` / `backups` | 测试台 / 结果与证据 / 可恢复副本 | 不通配加入TD；报告必须对上源码版本 |
| `legacy/user_source` | 独有历史例程与模板 | 参考用途，不参与当前构建 |

宏头文件不是独立硬件模块；它通过include影响编译。`.al`是工程组织文件，`.v`是设计，`.adc/.sdc`是约束，`.db`是工具中间数据库，`.bit`才是候选配置产物，`.img`则是SD卡图片数据，两者不能互换。

## 如何验证、怎么学习这些模块

建议阅读顺序：先 [接线教程](docs/CONNECTION_AND_USAGE.md) 建立输入输出概念，再看top接线、switch_controls电平控制、bmp_read状态机、帧缓存与frame_swap，最后研究HDMI串行和时序报告。

| 测试组 | 测试台 | 证明范围 |
|---|---|---|
| 缩放与调参 | tb_scaled_bmp、tb_picture_controls、tb_picture_adjust、tb_picture_osd | 九尺寸全帧、异常恢复、按键模式、穷举像素调节与40列OSD |
| SW集成 | tb_switch_controls | 16种状态、抖动、保持、复位、CDC、交替模式及动画中切换 |
| 历史输入模块 | tb_uart_rx、tb_ir_nec_rx、tb_uart_queue | 接收、命令事件、回复队列 |
| 基础集成 | tb_upgrade、tb_cdc、tb_video_scaler | 控制/OSD/音频/EDID基础行为，状态跨域及独立缩放器 |
| SD与恢复 | tb_sd_address、tb_sd_watchdog、tb_sd_waits、tb_load_recovery | 寻址/R7、初始化重试、等待超时、加载中止重试 |
| BMP | tb_bmp_stream、tb_bmp_headers、tb_bmp_stall | 整帧像素、坏头拒绝、无进度和恢复 |
| 内存调度 | tb_fifo_boundary、tb_frame_writer、tb_frame_tail | FIFO边界、写地址翻转、帧尾控制；不是完整实物SDRAM签核 |
| 视频 | tb_stream_queue、tb_hdmi_line_contract、tb_osd_text、tb_commit_timeout | 背压、合法连续行、文字、迟到确认与帧保护 |
| 字幕与转场 | tb_transition、tb_transition_pixels、tb_caption_overlay、tb_effects_pipeline | 帧边界和缓冲保护、33档像素计算、透明混色/滚动/计时及连续三帧HDMI接口时序 |
| PLL | tb_pll_clocks | 官方模型中的100/40/40、25/125 MHz及锁定 |

模块仿真常用行为对端或故障注入替代外设；测试通过不能自动推导“真实SD卡与加密HDMI核整链路已经通过”。硬件应按测试图→单图→多图→异常恢复→音频→长时间运行分层验证并记录。

两个 video_improve.al 入口引用同一套57个源，清单为scripts/design_files.txt。scripts/legacy_files.txt是历史源子集；[迁移表](docs/path_migration.json)记录路径关系。不要通配编译legacy/备份。必要官方IP已保留；global_def.v和video_define.v的工具入口副本保留。

PLL 沿用 10 月 4 日 NOCOMP/VCO 手工核查版本，非本轮向导生成，VHDL/IPC 再生成和硬件环路仍需复核。

## 验证命令

Windows PowerShell、Python 3、TD 6.2.168116、ModelSim SE 10.1c；默认安装位置 J:/Anlogic/td.6.2.1 和 J:/win64。

```powershell
cd E:/fpga
python scripts/static_check.py
python scripts/test_prepare_media.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_refresh_test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_pll_test.ps1
python scripts/run_build.py
```

-ModelSim、PLL 测试的 -TD、构建入口的 --td 可覆盖工具位置。GUI 打开根目录 video_improve.al，目标 EG4S20BG256。

run_build.py 顺序执行新综合、布局、布线、final STA，同时检查错误、完成标志及新产物；旧同名结果归档到 reports/previous_build。build_manifest.json 绑定源/产物 SHA-256、警告和时序，避免误用旧报告。

本轮另有独立欠载恢复故障注入测试；激励、命令和验证边界见 [显示修复说明](docs/DISPLAY_REPAIR_20261013.md)。生成新候选前还需运行该专项并记录回归日志，完整顺序见 [接线教程8.2–8.3](docs/CONNECTION_AND_USAGE.md)。当前已生成的候选直接核对哈希即可。

47项模块回归包含原41项UART、NEC、CDC、缩放、寻址、恢复、整帧BMP、FIFO、翻转地址、背压与OSD、坏BMP头拒绝、HDMI连续行契约及SD/EDID/提交超时，并增加菜单、监督器、伽马、诊断、菜单OSD与双模式视频集成六项。主机工具历史有10项测试；官方PLL/CSB历史模型测试覆盖25/125、40/200MHz及切换等待，不验证硬件环路。本轮未改PLL及主机媒体工具，未把历史测试冒充新跑。HDMI契约测试是行为对端，加密核参与的完整top仿真仍未完成。

## 时序与 bitstream

以 [当前状态](reports/timing_status.txt)、[详细路径](reports/timing_summary.txt) 及源哈希为准。旧 +1.090/+0.011 ns 仅是历史。本轮ADC在已确认SW基础上新增B1按键；SDC异步输入首级例外为key1/key2/key3/sw[*]。自适应PLL新增40/200MHz输出；scripts/adaptive_clocks.tcl仅将两档输出设为互斥，同档像素/串行及其余实际路径仍分析，没有虚构PAD延迟或屏蔽内部复位路径。

SDRAM 位置、局部时钟布线、外部 IO delay 等问题仍待解决。Speed=NA 不证明按 I7 速度角签核。HDMI LVDS33_E / 8 mA 为候选配置，四个负端由工具生成，需核对 HX4S20C 原理图、电阻、接收负载与板级信号。

自适应版必须用含双模式时钟约束的专用生成流程，并核对源码、routed数据库和bit的SHA-256。最终文件和余量见 [构建状态](docs/BUILD_STATUS.md)。旧bit不能用于验收新源码；内部时序通过也不等于+0.5ns或板级验收。

## 官方器件资料带来的补充

已扫描 `J:/6_EG4S20数据手册` 的芯片、IO、PLL、RAM、HDMI和SDRAM资料及压缩包。按手册页码整理的依据、基础知识和待验证项目见 **[官方资料与工程对照](docs/VENDOR_REFERENCE_20261009.md)**；全部文档从 [文档索引](docs/README.md) 进入。

| 新核对的内容 | 对当前工程的实际意义 |
|---|---|
| 合封SDRAM为64Mb，即8MiB | 两帧使用2,457,600字节，容量足够；SD卡64MiB扫描区是另一概念 |
| APUG011给出10拍读返回示例 | 已改为按真实返回计数排空；官方示例不等于可固定假设延迟，真实硬核仍需验证；`Sdr_busy`说明前后矛盾 |
| APUG011持续写入要求64MHz以上 | 当前40MHz有限突发不能直接套用此保证，须验证刷新间隔、有效带宽和仲裁 |
| IO手册列出150/150/140Ω及483mV | 条件为8mA、100Ω差分LVDS负载；不是HDMI电气合规证明或本板改电阻指令 |
| BG256的Bank1/3供电限制 | VCCIO1/VCCIO3/VCCAUX内部相连，VCCO1/3为3.3V；不代表整板电源口输入3.3V |
| HDMI核与APUG092文件哈希一致 | 可直接对照连续行、EDID、音频/ACR接口；其参考板AP106的接口编号不能用于HX4S20C |
| Soft FIFO手册实际为文档3.1 | 新版读模式、复位及CDC约束需与当前旧生成FIFO分别核对，不能自动套用 |

理论带宽也应分清：当前40MHz×32bit=160MB/s原始总线带宽，VGA显示平均读约73.14MB/s、可见区瞬时100MB/s；SVGA平均约115.81MB/s、可见区瞬时160MB/s；加载写入、刷新和切换另占带宽。FIFO只能吸收短期差异。已补刷新/请求返回/读写切换行为模型和OSD诊断；下一步用实板验证硬核契约并完成板级签核，详见 [待办](docs/BOARD_PENDING.md)。

## 官方参考资料

J 盘的 `lab_ex4_tf`、`lab_ex5_i2s` 含可用的 BMP 转换器、样例图、HDMI 接口手册和音频素材。[复用审查](docs/OFFICIAL_LABS_REVIEW_20261007.md) 记录了实际转换/分频验证、文件对应关系及适配要求。不要直接运行其中会清空目标盘的 `sync_to_sd.py`，也不要覆盖回旧时序约束。

已提供适配工具 `scripts/prepare_media.py`：`convert`、`check`、`pack`、`verify`。其中convert/check仍用于生成普通BMP；pack/verify仅保留给历史裸扇区测试。当前制卡是普通FAT32根目录文件复制，见[FAT32教程](docs/FAT32_USAGE_20261015.md)。旧工具生成的镜像固定64MiB，它是无FAT的原始镜像，不是复制到卡根目录的图片文件，也不直接写存储卡；[使用方法](docs/OFFICIAL_ADAPTATION_20261007.md)。

## 备份

10月13日修复前216个文件已保存于 [显示修复前备份](backups/display_fix_20261013_185401/workspace.zip)，逐文件SHA-256核验；16个官方IP文件未改变，刷新配置头按实际40MHz修正。

10月10日修改前177个文件已保存于 [缩放修改前备份](backups/before_scaling_20261010/workspace.zip)，官方IP保持不变。

SW修改前173个文件保存于 [SW备份包](backups/before_sw_controls_20261009/workspace.zip)，官方IP保持不变。

字幕转场修改前161个文件保存于 [备份包](backups/before_effects_20261009/workspace.zip)，[哈希清单](backups/before_effects_20261009/manifest.json)逐项核验。官方IP、PLL、ADC/SDC没有修改。

2026-10-09官方资料文档修订前，全部13份活动Markdown备份在 [markdown.zip](backups/before_vendor_docs_20261009/markdown.zip)，逐文件哈希见 [manifest](backups/before_vendor_docs_20261009/manifest.json)。本轮只改文档和核验材料，必要官方IP保留。

本次合并前205个文件已备份至 `backups/before_team_merge_20261008/workspace.zip`，逐项SHA-256验证通过；旁边的manifest记录校验值。它包含本轮修改前源码、工程、脚本、文档及选定报告，不含可重建仿真库/数据库。队友目录保持原样。

更早的历史归档在本次开始时已不在本地；不能将队友README中提到的旧备份当作实际存在。旧清理记录见 [清理映射](reports/cleanup_plan.json) 与 [删除记录](reports/deleted_files.json)。

## FAT32读取层（2026-10-15）

[sd_fat32.v](src/modules/sd/sd_fat32.v)负责分区/BPB几何、根目录8.3枚举、碎片簇链和双流FAT扇区缓存。[bmp_read.v](src/modules/bmp/bmp_read.v)在正式模式仅用文件索引加载，原头解析/缩放不变；[audio_wav.v](src/modules/audio/audio_wav.v)输出相对文件扇区，原格式和延时重试不变。[sd_card_bmp.v](src/modules/bmp/sd_card_bmp.v)连接此中间层与原仲裁器。仅用现有KEY/SW，未修改官方IP、引脚或时钟约束。验证媒体由[make_fat32_image.py](scripts/make_fat32_image.py)纯Python生成/自检，不写实体卡。
