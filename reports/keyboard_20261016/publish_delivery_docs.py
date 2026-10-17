"""Publish current, source-bound usage; retain frozen reports as history."""
from pathlib import Path
import json,sys
R=Path(__file__).resolve().parents[2]; O=Path(__file__).resolve().parent
stage=sys.argv[1]
v=json.loads((O/(stage+'_validation.json')).read_text())
assert v['build_status']=='completed' and v['regression_passed']==80
t=v['timing_ns']
def read(n): return (R/n).read_text(encoding='utf-8')
def write(n,s): (R/n).write_text(s,encoding='utf-8')
def prepend(n,s):
 text=read(n);head,_,body=text.partition('\n');write(n,head+'\n\n'+s+'\n\n'+body.lstrip())
short='> 当前正式源码：六线原生四位 SD，CMD6 成功确认后自动从25MHz升至50MHz，不支持/忙时保持四位25MHz；主控制100MHz。80项ModelSim和内部STA结果见[构建状态](BUILD_STATUS.md)。尚未实板验证；下文明确标注的旧版本说明只作历史参考。'
for n in ('docs/USER_GUIDE.md','docs/BOARD_TIMING.md','docs/ROADMAP_KEYBOARD_MEDIA.md'):
 prepend(n,short)
text=read('docs/USER_GUIDE.md').replace('正式SD仍SPI25MHz；','正式SD为原生四位CMD6自动协商25/50MHz；').replace('SD四位候选与50MHz限制','SD四位实现与50MHz验收边界')
write('docs/USER_GUIDE.md',text)
text=read('docs/KEYBOARD_USAGE_20261016.md')
start=text.index('> 2026-10-17当前：');end=text.index('\n',start)
text=text[:start]+short+text[end:]
start=text.index('SD正式接口仍是SPI25MHz')
text=text[:start]+'''SD正式接口为原生四位，CMD6确认切换成功后使用50MHz；卡不支持或忙则保持25MHz。具体接线、协商、CRC、ModelSim激励与板级验收边界见[SD实现说明](SD_NATIVE_4BIT_20261016.md)。这不会改变KEY/SW/键盘的操作方式。\n'''
write('docs/KEYBOARD_USAGE_20261016.md',text)
text=read('README.md');start=text.index('SD正式接口为');end=text.index('\n',start)
text=text[:start]+'''SD正式接口为 **原生四位SD，CMD6自动协商25/50MHz**，主控制100MHz。支持并确认切换成功才升50MHz；不支持/busy留在四位25MHz。80项逻辑回归及内部STA通过；卡模型吞吐22.34MB/s不是实体卡实测。仍用原TF卡槽，六线映射和10kΩ上拉已核对。'''+text[end:]
text=text.replace('原生四位SD25MHz协议、PHY和封装','原生四位SD25/50MHz、CMD6协议、PHY和封装')
write('README.md',text)
note=f'''## 当前交付：键盘、多文件、R/F与四位SD 25/50MHz

正式源码完成键盘控制、64文件索引、R安全重启切模式、F目标换图频率，以及六线原生四位SD。CMD6查询/切换的64字节状态通过四路CRC、功能选择和busy检查后，等待八个SD时钟，再在完整周期边界启用50MHz；不支持/忙时保持25MHz，状态损坏或协商超时则重新初始化并禁用本轮高速尝试。普通CMD6选择High Speed，与ACMD6设置四位宽度不同。

静态检查72源/40IO，**80项ModelSim全部通过**；综合、布局布线、内部STA通过：SWNS **{t['SWNS']:+.3f}ns**、STNS {t['STNS']:.3f}ns、HWNS **{t['HWNS']:+.3f}ns**、HTNS {t['HTNS']:.3f}ns。[冻结报告](../reports/keyboard_20261016/RESULT_{stage}.md)、[源码与报告哈希](../reports/keyboard_20261016/{stage}_validation.json)。原70位状态布局和取位保持。FAT32/仲裁/BMP解析/WAV解析/缩放器相对阶段四零改动；总调度器的下一图索引作等价时序优化，消除加法后再比较的串联。

逻辑卡模型50MHz连续16扇区约22.34MB/s，覆盖0/6/14ns输出延迟；正式profile播放器激励逐像素、逐PCM验证。**这是逻辑仿真，不是实体卡吞吐，也不是SD外部IO签核。** 未下载、未写实体卡，实板出图/出声/显示器重锁及SD采样窗口仍待验收。没有降低100MHz或新增功能路径时序屏蔽；内部复位removal不是HDMI管脚hold，未宣称达到整体+0.5ns。

候选bit导出状态另附交付清单；旧bit不能验证新增功能。以下均为各冻结检查点的历史记录。
'''
text=read('docs/BUILD_STATUS.md').replace('## 当前：原生四位SD 25MHz已接入','## 历史：原生四位SD 25MHz检查点').replace('## 当前：键盘、多文件、R安全切换与F目标换图频率','## 历史：键盘、多文件、R/F检查点')
write('docs/BUILD_STATUS.md',text);prepend('docs/BUILD_STATUS.md',note)
write('docs/SD_NATIVE_4BIT_20261016.md',f'''# 原生四位SD与CMD6高速实现

正式顶层已启用四位原生SD，并按卡能力自动协商25/50MHz。详细验证数字以[构建状态](BUILD_STATUS.md)及[本次冻结报告](../reports/keyboard_20261016/RESULT_{stage}.md)为准。旧SPI保留作兼容仿真profile，正式top不走SPI，也没有运行时回退SPI。

## 接线与电气依据

仍插板上原TF/microSD卡座，不增加外设。以下是FPGA焊球坐标，不是外接排针序号。

| 信号 | microSD接点 | FPGA焊球 | 方向 |
|---|---:|---|---|
| SD_CLK | 5 | A14 | FPGA输出 |
| SD_CMD | 3 | A13 | 双向，主机发送与卡响应分时 |
| SD_DAT0 | 7 | B14 | 双向端口，本只读实现始终释放DAT |
| SD_DAT1 | 8 | B15 | 同上 |
| SD_DAT2 | 1 | A11 | 同上 |
| SD_DAT3 | 2 | A12 | 同上，原SPI片选脚 |

依据J:/HX4S20开发板手册-HDL版2410.pdf第20页图2-22，RN18/RN19为10kΩ上拉到3.3V，连接CMD与DAT0～3。[图面证据](../reports/keyboard_20261016/board_tf_page20.png)、[引脚文字](../reports/keyboard_20261016/board_pin_evidence.txt)。实物版本和装配仍需确认。CMD初始化阶段开漏，退出识别后推挽发送，收响应时关闭OE；读实现从不驱动DAT。

## 传输过程

1. 默认100MHz主控分频，200kHz识别阶段提供80个启动时钟。
2. CMD0 → CMD8 → CMD55/ACMD41循环 → CMD2 → CMD3取得RCA → CMD7并等待DAT0解除busy → CMD55/ACMD6(2) → CMD16(512)。OCR的CCS决定地址单位。
3. 进入四位25MHz。正式profile发CMD6(0x00FFFFF1)查询High Speed支持与busy；确认支持且空闲才发CMD6(0x80FFFFF1)切换。
4. 两次CMD6都接收64字节状态和四路CRC16。字节13的bit1表示支持，字节16低4位为选中功能，字节29的bit1为busy。只有切换后选中1、非busy且CRC/结束位正确才等待八个SD时钟后升50MHz。未知结果重新初始化，不能直接假定卡仍处于旧模式。
5. CMD17读单扇区；SDHC参数为LBA，SDSC参数为LBA左移9位，溢出报错。512字节由1024个四位数据拍接收，四条线分别计算CRC16。未实现CMD18/CMD12多块优化。

这里是3.3V **High Speed、50MHz、单沿SDR**，不执行CMD11/1.8V切换，不是UHS-I SDR50或DDR50。理论数据阶段25MHz为12.5MB/s，50MHz为25MB/s；实际还包括命令、响应、CRC和卡等待。

命令CRC7多项式0x09；数据CRC16为0x1021。48位R1/R6/R7校验头、结束位和CRC，136位R2对CID/CSD内容120位校验，R3保留CRC不作有效判断。错响应、起止标志、CRC或超时均走错误恢复。

## 上层接口保持

sd_card_top保留原扇区请求、地址、逐字节valid、成功end及init/error握手；物理侧为六线原生接口。数据字节在CRC最终判定前输出，只有CRC与结束位全部正确才产生sd_sec_read_end；失败产生sd_transfer_error，不能把已收到的字节当作成功扇区。响应损坏时排空仍在发送的数据或等待超时，再处理下一请求。只读不写卡，写请求报错而不假报写成功。

FAT32、仲裁、BMP解析、WAV解析、缩放五个模块相对阶段四保持零差异。sd_card_bmp仅透传物理接口/构建参数和等价优化索引计算。两个TD入口与design_files使用同一正式源清单，必要官方IP保留。

## 源文件与激励

| 文件 | 作用 |
|---|---|
| [sd_bus_phy.v](../src/modules/sd/native/sd_bus_phy.v) | 100MHz单域分频、CMD OE、命令/响应、64/512字节接收、CRC及超时；25MHz在名义上升沿采样，50MHz采样许可延后一拍100MHz |
| [sd_native_controller.v](../src/modules/sd/native/sd_native_controller.v) | 初始化、RCA/CCS、CMD6查询切换、CMD17、错误重试与去重 |
| [sd_card_top_native.v](../src/modules/sd/native/sd_card_top_native.v) | PHY与控制器封装；ENABLE_HIGH_SPEED为构建参数 |
| [sd_native_card_model.v](../sim/sd_native_card_model.v) | 引脚级逻辑卡模型、独立CRC、FAT32镜像、可配置输出延迟 |
| [tb_sd_native.v](../sim/tb_sd_native.v) | SDHC/SDSC、四线CRC、错响应/起止、超时恢复、吞吐和请求去重 |
| [tb_sd_native_clock.v](../sim/tb_sd_native_clock.v) | 真实200kHz初始化、80启动时钟与25MHz完整周期切换 |
| [tb_sd_native_fat32.v](../sim/tb_sd_native_fat32.v) | 真实FAT32/仲裁、碎片BMP/WAV逐字节校验 |
| [tb_sd_native_integrated.v](../sim/tb_sd_native_integrated.v) | 正式原生25MHzprofile，经物理引脚到FAT/BMP/缩放/WAV，无force替换 |
| [tb_sd_highspeed.v](../sim/tb_sd_highspeed.v) | CMD6支持/不支持/busy/拒绝、查询和切换CRC/响应/无数据超时、恢复25、50MHz周期及吞吐 |
| [tb_sd_highspeed_player.v](../sim/tb_sd_highspeed_player.v) | 14ns输出延迟卡模型，经正式50MHzprofile校验两帧图片像素与PCM循环 |

完整ModelSim回归含以上测试：

```powershell
cd E:\\fpga
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
```

不要同时运行共享sim/msim_work的仿真。旧25MHz专项可运行scripts/run_sd_native_tests.ps1，其独立库为sim/sd_native_work。逻辑模型测得25MHz约11.20MB/s、50MHz约22.34MB/s；这些不是实体卡或整机图片FPS。

## 实板仍要验证什么

本次80项回归、综合/P&R/内部STA通过，SWNS {t['SWNS']:+.3f}ns、HWNS {t['HWNS']:+.3f}ns，TNS0。时序报告不含已签核的SD卡输出延迟/PCB往返预算，0/6/14ns模型测试也不能代替板级STA。50MHz采样许可使用100MHz域的一拍延迟，没有照搬SDRAM移相或增加PLL。

实板应先用NATIVE_HIGH_SPEED=0单独构建确认四位25MHz，再测默认自动协商50MHz；更换参数后必须重新回归/构建，不能沿用本页冻结哈希。测CMD/DAT波形、连续扇区总字节/总时间，检查CRC错误和长时间图像/音频播放；本轮没有执行物理下载或卡写入。内部removal不是HDMI管脚hold，也没有整体+0.5ns声明。
''')
text=read('docs/KEYBOARD_REMAINING_20261016.md')
start=text.index('> 2026-10-17当前：');end=text.index('\n',start);text=text[:start]+short+text[end:]
start=text.index('## SD四位与50MHz')
text=text[:start]+'''## SD四位与50MHz：源码已接入，实板未验收

正式top已选择六线原生四位，并打开CMD6高速协商。源码、回归及内部STA已完成；详见[SD实现](SD_NATIVE_4BIT_20261016.md)。实体卡输出延迟、板级采样窗口、电气、真实吞吐、长期播放和显示器切模式后的锁相仍待测量。逻辑模型22.34MB/s不等于实体卡速度。

## 明确的功能边界

- R的0/1档都输出VGA；0档不会自动把大图读取量降到320×240。准备小素材才能节省SD流量。
- F是目标换图频率，L提示曾错过期限；不保证30FPS，也不改变HDMI刷新率。
- BMP+WAV合计64份；数字只有0～9，音频第11份以后暂无直达输入。
- 设置不持久化，不支持热插拔重扫、1080p输出、MP3或立体声/44.1kHz WAV。
- PS/2为Set 2接收，不驱动键盘LED；KEY/SW映射保持。
- CMD17单块读取；CMD18多块、UHS/DDR、电压切换未实现。

以上是当前实现限制，不能用历史bit或原始总线带宽作为完成证明。\n'''
write('docs/KEYBOARD_REMAINING_20261016.md',text)
text=read('docs/SOURCE_MAP.md')
text+='''
## CMD6高速增量

sd_native_controller在25MHz查询/切换High Speed，锁存64字节状态中的支持、选中与busy，CRC成功后才采用；sd_bus_phy接收64/512字节并检查四路CRC16。50MHz采样许可延后一拍100MHz，不照搬SDRAM相位。正式top启用NATIVE_HIGH_SPEED，旧25MHz测试默认关闭。新激励tb_sd_highspeed和tb_sd_highspeed_player见[SD实现](SD_NATIVE_4BIT_20261016.md)。这属于3.3V High Speed SDR，不是1.8V UHS-I SDR50。\n'''
write('docs/SOURCE_MAP.md',text)
write('docs/CONNECTION_AND_USAGE.md','''# 接线、配置与逐步使用

本页对应当前PS/2、64文件索引、R/F、原生四位SD 25/50MHz源码。候选bit及匹配的验证记录见[构建状态](BUILD_STATUS.md)。本轮没有执行实板下载，以下是按源码与官方资料整理的操作步骤。

## 一、准备和连接

准备HX4S20C/EG4S20BG256板、匹配电源、兼容下载器、HDMI显示器、HDMI线、TF卡和读卡器。键盘可选，KEY/SW仍可完成原有操作。

1. 断电，显示器HDMI输入接开发板 **HDMI_B（HDMIB）**。HDMI_A不用；普通笔记本HDMI通常为输出，不能作显示输入。
2. 在电脑上准备FAT32、512字节扇区的TF卡，将支持的BMP/WAV复制到根目录，再弹出并插入板载TF卡座。不要求写裸扇区镜像，也不要照旧版固定地址烧卡教程操作。
3. 如需键盘，连接支持PS/2 Set 2的键盘及板上匹配接口。CLK=M16、DATA=K16是FPGA封装坐标，不是插头针序；接口供电/电平按实物原理图核对。普通USB键盘不能直接接两根数据线。
4. 下载器接板卡规定的下载/JTAG接口，电源按板卡手册确认电压和极性。普通USB-UART不能代替下载器；本工程不通过串口控制或接收bit文件。
5. 显示器先开机并选中对应HDMI输入，再给板上电、配置匹配的候选bit或复位。

声音也走同一根HDMI_B线，不接外置I2S/DAC。显示器需支持HDMI音频并有扬声器或音频输出，HDMI转DVI通常不传音频。

封装坐标B1/A14等不等于排针编号。专用JTAG的TDI=C12、TCK=C14、TDO=E14、TMS=A15来自BG256资料；仍需按板卡连接器和下载器针序接线。用户复位rst_n=A2与PROGRAM_B等配置脚不同。

## 二、TF卡六线接法

使用原板载卡座即可，不需要另拉DAT1/DAT2。官方开发板手册第20页已确认以下连接及CMD/DAT的10kΩ上拉到3.3V：

| 顶层信号 | FPGA焊球 | microSD接点 |
|---|---|---:|
| SD_CLK | A14 | 5 |
| SD_CMD | A13 | 3 |
| SD_DAT0 | B14 | 7 |
| SD_DAT1 | B15 | 8 |
| SD_DAT2 | A11 | 1 |
| SD_DAT3 | A12 | 2 |

CMD双向，DAT在本只读实现始终释放为输入。正式工程已选择原生四位，旧四线SPI模块不能替代以上连接。开机200kHz识别，进入25MHz，CMD6确认成功再升50MHz；不支持或busy留25MHz，用户不需要按键选择SD速率。电气依据、CRC、协商和板级验收见[SD说明](SD_NATIVE_4BIT_20261016.md)。

## 三、文件怎样准备

| 类型 | 当前支持 |
|---|---|
| BMP | 正高度、24bit、无压缩BI_RGB；DIB40/108/124；宽1～1920、高1～1080 |
| WAV | PCM、48kHz、16bit、单声道，最大16MiB |
| 文件系统 | FAT32根目录，BMP+WAV合计64份，支持碎片簇链 |

不支持JPEG/PNG/MP3、44.1kHz或立体声WAV、exFAT/子目录。枚举按目录项顺序，不按文件名排序；重命名不保证改变序号。建议8.3英文文件名并事先转换媒体，工具见[FAT32文件教程](FAT32_USAGE_20261015.md)。为测试缩放，可准备320×240、640×480、800×600及一张竖图；至少两张图才能观察切换。更换卡内容后接好再复位，本版不自动热插拔重扫。

## 四、KEY怎么按

| 按键 | 焊球 | 菜单关闭时 |
|---|---|---|
| KEY1 | B2 | PLAY下一张；BRIG亮度减8；CONT对比度减0.25 |
| KEY2 | C1 | PLAY轮播开关；BRIG亮度加8；CONT对比度加0.25 |
| KEY3 | B1 | 短按并松开：PLAY→BRIG→CONT；长按约1.1秒：开/关菜单 |
| 用户复位 | A2 | 重新启动、挂载和扫描，设置回默认 |

每次按约0.1秒再松开，等待消抖，不必快速连点；KEY1/2长按不连发。先看MODE再按KEY1/2，BRIG下按KEY2不会暂停轮播。亮度范围−64～+64、默认0；对比度0.50～2.00、默认1.00。

长按KEY3打开菜单后，KEY1向上、KEY2向下、KEY3短按确认；再长按退出。菜单包含PLAY/PAUSE、GAMMA、DIAG、DIAG PAGE、AUDIO MUTE、VOLUME DOWN、VOLUME UP。默认轮播OFF、伽马OFF、诊断OFF、静音OFF、音量08；到音量条目后反复短按KEY3每次调1，范围0～31。详细例子见[KEY/SW教程](KEY_SW_OPERATION.md)。

## 五、SW怎么拨

下面编号对应代码sw[0]～sw[3]，实物左右顺序及ON方向需对照板卡；代码默认闭合到GND为ON。不要操作启动配置/电源开关代替用户拨码。

| 路 | 焊球 | 功能 |
|---|---|---|
| 1 / sw[0] | C8 | ON显示底部字幕和右上运行时间；OFF隐藏 |
| 2 / sw[1] | C7 | ON文字滚动；OFF停止滚动 |
| 3 / sw[2] | C6 | 转场选择低位 |
| 4 / sw[3] | C5 | 转场选择高位 |

| 第3路 | 第4路 | 效果 |
|---|---|---|
| OFF | OFF | 直接切换 |
| ON | OFF | 旧图淡出、黑场换图、新图淡入 |
| OFF | ON | 滑出、黑场换图、滑入 |
| ON | ON | 淡出淡入与滑动交替 |

拨好后等待约20ms稳定，再换图观察；选择效果本身不换图。首图直接显示，动画中拨SW对下一次转场生效；O只关状态OSD，字幕独立受SW1控制。

## 六、键盘怎么用

左右切图；数字0～9选第一至第十张；A松开后2秒内按数字选前十WAV，Esc取消；空格轮播；上下调音量；M静音；O开关状态OSD。不是两位数输入，第11张以后用左右遍历，第11份以后的WAV暂无直达。

R默认VGA→SVGA请求→小素材/VGA→VGA。SVGA仅在EDID支持时输出800×600，否则回VGA；0/1档都为640×480，小素材档不会把大图SD读取量自动降成320×240。切档先复位消费者、切专用全局时钟、等待稳定，再挂载重载，屏幕暂黑正常，轮播需再开。1080p显示器可接收它支持的较低模式，本工程不输出1080p。

F循环目标1/2/5/10/15/30次换图每秒，默认5；TARGET显示目标，L表示曾因加载/提交忙错过期限。它不改变约60Hz的HDMI刷新，也不保证实际30FPS。遇L可降低目标、缩小源图或关闭转场。完整原理与键位见[键盘手册](KEYBOARD_USAGE_20261016.md)。

## 七、第一次演示

1. 准备两张BMP和一份合规WAV，按第一节连接。
2. 配置与本轮源码匹配的候选，等待首图、IMG计数和LOAD忙状态结束。
3. MODE:PLAY下按KEY1观察下一张；KEY2开轮播，再按暂停。
4. KEY3切BRIG，用KEY2加两次至+16，再用KEY1减回0；切CONT比较1.25与1.00。
5. SW1/2开字幕与滚动，SW3开、SW4关，换图观察淡出淡入。
6. 有键盘时按O观察状态层开关、A再0选第一份WAV、上下调音量、M切静音。听不到时先看错误/音量与显示器音量。
7. 按R测试SVGA与VGA往返，画面恢复后再开轮播，用F选目标并观察TARGET/L。

## 八、排障和验证

| 现象 | 首先检查 |
|---|---|
| 黑屏 | HDMI_B、显示器输入、匹配bit；接好显示器后复位回VGA |
| 找不到文件 | FAT32/512字节扇区、根目录、支持格式、64总上限；复制后复位 |
| 无声 | 默认音量08可被设置改为0；M/菜单静音、显示器支持/扬声器、WAV格式与OSD音频错误 |
| A:E1 | RIFF/fmt格式错误，改成48k/16bit/mono PCM |
| A:E2 / E3 / E4 | SD读错/超时、扇区长度、chunk边界；详见音频恢复说明 |
| U1 | 发生过音频欠载；检查卡和访问负载，复位视频域后记录重置 |
| LOAD:E、白条或撕裂 | 保存现象及诊断，检查错误/欠载/SDRAM和实板时序，仿真通过不等于硬件已修复 |
| R:2但仍640×480 | EDID能力不支持SVGA或未通过检测，属于回退 |
| TARGET右侧L | 链路忙超期，目标不等于可达FPS |

WAV失败延时约1秒重试，错误历史到真实PCM恢复才清，不必每次整机复位；图片挂载失败和提交超时不属于音频重试。详情见[音频恢复](AUDIO_RETRY_20261014.md)。

ModelSim激励在sim/，完整入口scripts/run_tests.ps1；编译、回归和综合/P&R步骤见[README](../README.md)。不要并发使用同一仿真库，也不要在构建期间修改src/scripts/sim。内部STA与实体卡速率、SD外部IO、HDMI电气是不同验收项目；内部复位removal不等于HDMI管脚hold，当前没有整体+0.5ns完成声明。
''')
print('Published current native25/50 implementation, manuals and precise limits')
