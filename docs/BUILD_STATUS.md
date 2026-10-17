# 构建状态

> **2026-10-17 当前源码为OSD/波形实验版：75源/40IO静态检查、85项ModelSim通过；物理实现与时序未通过，未生成本轮新bit。** SW3/4增加原图/反色/Sobel/热成像，O统一开关状态OSD/玻璃/波形。操作、算法和失败路径见[本轮手册](OSD_AUDIO_VISUALIZER_20261017.md)。下文旧native50候选及其正时序只代表修改前版本，不能验收当前源码。

## 本轮候选bit（尚未下载）

[video_improve_native50_delivery.bit](../reports/keyboard_20261016/video_improve_native50_delivery.bit)，633116字节；SHA-256：`82f125e85700aaed1f270d7b9ca3e3229aa1e66b3a9d2d5be505425099d6dfa6`。

源码提交`5952318772ac12511f93c39d579cbdfe9ab2f188`，输入与80项回归绑定至[native50_ultra_validation.json](../reports/keyboard_20261016/native50_ultra_validation.json)。候选在同一TD实现会话内重新布局布线、核查非负时序后导出；该会话SWNS **+0.026ns**、HWNS **+0.022ns**、TNS0。[候选清单](../reports/keyboard_20261016/native50_delivery_bit_manifest.json)、[该会话STA](../reports/keyboard_20261016/native50_delivery_bit_timing_summary.txt)。

仅为内部STA通过的实板待验候选，未物理下载、未写卡、未实测出图/出声/吞吐、未签核SD/HDMI外部IO。历史bit不含本轮功能。内部removal不是HDMI管脚hold，未达到整体+0.5ns。

## 当前交付：键盘、多文件、R/F与四位SD 25/50MHz

正式源码完成键盘控制、64文件索引、R安全重启切模式、F目标换图频率，以及六线原生四位SD。CMD6查询/切换的64字节状态通过四路CRC、功能选择和busy检查后，等待八个SD时钟，再在完整周期边界启用50MHz；不支持/忙时保持25MHz，状态损坏或协商超时则重新初始化并禁用本轮高速尝试。普通CMD6选择High Speed，与ACMD6设置四位宽度不同。

静态检查72源/40IO，**80项ModelSim全部通过**；综合、布局布线、内部STA通过：SWNS **+0.026ns**、STNS 0.000ns、HWNS **+0.022ns**、HTNS 0.000ns。[冻结报告](../reports/keyboard_20261016/RESULT_native50_ultra.md)、[源码与报告哈希](../reports/keyboard_20261016/native50_ultra_validation.json)。原70位状态布局和取位保持。FAT32/仲裁/BMP解析/WAV解析/缩放器相对阶段四零改动；总调度器的下一图索引作等价时序优化，消除加法后再比较的串联。

逻辑卡模型50MHz连续16扇区约22.34MB/s，覆盖0/6/14ns输出延迟；正式profile播放器激励逐像素、逐PCM验证。**这是逻辑仿真，不是实体卡吞吐，也不是SD外部IO签核。** 未下载、未写实体卡，实板出图/出声/显示器重锁及SD采样窗口仍待验收。没有降低100MHz或新增功能路径时序屏蔽；内部复位removal不是HDMI管脚hold，未宣称达到整体+0.5ns。

候选bit导出状态另附交付清单；旧bit不能验证新增功能。以下均为各冻结检查点的历史记录。


## 历史：原生四位SD 25MHz检查点

阶段1～4完成以后，正式TF通路切换为六线原生SDR四位25MHz，主控制时钟100MHz。没有SPI运行时回退。扇区侧请求/地址/字节valid/成功end/错误语义保留，FAT32、仲裁、BMP、WAV及缩放器相对阶段四零改动。旧SPI仅保留作兼容测试profile。

静态72源/40IO、78项ModelSim回归、综合/P&R/STA通过：SWNS **+0.260ns**、HWNS **+0.022ns**，TNS均0。新激励直接使用正式原生profile和物理引脚，不force替换扇区通道。[冻结验收](../reports/keyboard_20261016/native25_delivery_validation.json)、[报告](../reports/keyboard_20261016/RESULT_native25_delivery.md)。70位状态布局保留；没有降频、屏蔽功能路径或整体+0.5ns声明。

CMD6高速代码已在隔离候选完成逻辑仿真，尚未接入本阶段正式profile；当前仍25MHz。四位25MHz理想模型11.20MB/s不是实体卡实测。没有下载、写实体卡或实板出图/出声/吞吐验收。以下较早“当前SPI”记录属于历史阶段。


## 历史：键盘、多文件、R/F检查点

本轮正式源码完成阶段1～4。静态检查69源/38IO、77项ModelSim回归、综合、布局布线及STA通过，精确输入哈希见[冻结清单](../reports/keyboard_20261016/phase4_keylanes_validation.json)。SWNS **+0.213ns**、STNS 0.000ns、HWNS **+0.021ns**、HTNS 0.000ns。[本轮报告](../reports/keyboard_20261016/RESULT_phase4_keylanes.md)、[操作手册](KEYBOARD_USAGE_20261016.md)。没有降低100MHz控制时钟，没有新增功能路径false path，70位状态布局及全部下标保持；内部复位recovery/removal没有当作HDMI管脚hold。没有整体+0.5ns声明。

正式SD仍SPI25MHz；四位25MHz候选未接入板级，50MHz未实现CMD6协商和实板验证。未下载、未写实体卡，显示、出声、吞吐、显示器运行切换重新锁相均待实板验收。新候选bit是否生成见交付清单，不得使用历史bit验收本轮新增功能。

以下均为各自冻结源码的历史结果。旧文中的“当前”“仅存R/F请求”不代表本轮源码。

## 历史阶段三：R安全切模式和重新加载

R已正式接入VGA/SVGA/小素材VGA请求，SVGA受EDID支持限制。独立控制复位保留用户设置，媒体/视频及EDID完成后的HDMI核先复位再切时钟，稳定等待后重新挂载和重载当前图片；自动轮播暂停。0和1均为VGA，0不自动降低大图读取量。

静态68源/38IO、75项回归、综合/P&R/STA通过：SWNS **+0.451ns**、STNS 0.000ns、HWNS **+0.021ns**、HTNS 0.000ns。[精确输入清单](../reports/keyboard_20261016/phase3_wavlanes_validation.json)、[本轮报告](../reports/keyboard_20261016/RESULT_phase3_wavlanes.md)。70位状态布局和取位保留，100MHz未降低，没有新增功能路径false path。内部recovery/removal没有当成HDMI管脚hold，没有整体+0.5ns声明。

F尚待正式接入；SD仍SPI25MHz，未生成本阶段bit，未实板。以下为各自冻结源码的历史结果。

## 历史阶段二：64文件索引（72项回归与STA通过）

正式源码启用BMP/WAV合计64文件、数字选图片、A+数字选音频、完整OSD计数与取消排空。切WAV清PCM队列及FIR/回声历史而保留48k样本调度，FIFO许可寄存并预留四槽。静态检查67源/38IO、72项ModelSim回归、综合/P&R/STA通过：**SWNS +0.131ns、STNS 0、HWNS +0.024ns、HTNS 0**。资源LUT15401、REG10239、BRAM9K61/64、DSP17、PLL2。[冻结清单](../reports/keyboard_20261016/phase2_room_validation.json)、[阶段报告](../reports/keyboard_20261016/RESULT_phase2_room.md)。70bit状态布局及下标保持。

R/F尚未正式消费请求。正式SD仍SPI25MHz，未生成本轮新bit、未实板，未达到整体+0.5ns。初轮及各时序失败版本均在本轮reports保留；内部recovery/removal没有当成HDMI管脚hold。没有降低100MHz或新增功能路径时序屏蔽。当前阶段二通过值只认证该阶段冻结源码。[多文件使用](MEDIA_INDEX_20261016.md)。

## 2026-10-16 PS/2键盘阶段一（仿真与STA通过）

键盘专项及67项全量ModelSim回归通过，静态检查65源/38 IO通过。新增官方PS/2 CLK=M16、DATA=K16；KEY/SW保留，键盘用法与默认不静音的版本变化见[操作说明](KEYBOARD_USAGE_20261016.md)。数字、R/F尚仅存请求。最终综合/P&R/STA通过：**SWNS +0.001ns、STNS 0、HWNS +0.021ns、HTNS 0**，余量很小、未达到+0.5ns，未生成新bit、未实板。LUT15223、REG10132、BRAM9K59/64、DSP17、PLL2。[冻结源码绑定和范围审计](../reports/keyboard_20261016/validation_phase1.json)、[本轮报告](../reports/keyboard_20261016/RESULT_PHASE1.md)。

初轮P&R：SWNS −0.516ns、STNS −3.289ns，HWNS −0.319ns、HTNS −0.539ns；负min实际是内部模式同步器复位removal，不是HDMI管脚hold。隔离WAV重试计数、同步各域模式复位释放后，第二轮：SWNS −1.200ns、STNS −6.617ns，HWNS +0.021ns、HTNS 0；setup仍失败。已继续检查WAV状态译码，后续结果以匹配输入哈希的冻结报告为准。两轮日志见 `reports/keyboard_20261016/phase1_initial/`、`phase1_fixed/`。不将旧SPI基线的正时序当成新键盘源码结果，也不宣称达到+0.5ns。

历史阶段一期间独立多文件实验（现已由阶段二正式接入）：12BMP/3WAV、高簇号、碎片、64文件总限额、越界回卷、切音频排空，以及真实播放器缩放帧/PCM/提交仿真通过。它不属于已落地正式功能，须待阶段一过关及后续正式回归与P&R。

## 2026-10-16 四位SD独立候选

原生四位SD已完成协议、默认分频、真实FAT32及播放器四项仿真与独立TD综合。模型16扇区吞吐11.204574MB/s，非实板测量。当时DAT1/DAT2焊球和上拉依据尚缺；现已由官方手册PDF第20页确认B15/A11及10kΩ上拉，**仍未接入正式板级工程**，正式仍为SPI；四位模式整机P&R/STA和实板验收均未完成。[候选设计/仿真命令](SD_NATIVE_4BIT_20261016.md)、[本轮冻结结果](../reports/sd_native_20261016/RESULT.md)。

本轮正式SPI工程重建通过：SWNS +0.034ns、HWNS +0.021ns，TNS均0；完整65项回归通过。LUT15019、REG10052、BRAM9K59/64、DSP17、PLL2，未生成bit，未实板。冻结报告及源码哈希见上述本轮记录。先前FAT32修复见[10月16日时序证据](../reports/fat32_setup_20261016/RESULT.md)。以下10月15日负时序为修复前历史结果，不代表该修复后的源码。

## 历史：2026-10-15 FAT32 根目录文件播放

正式顶层读取普通 FAT32 卡根目录前四个 BMP 和第一个 WAV，支持碎片；63 源、36 IO。静态检查、61 项完整 ModelSim 回归通过，综合/布局布线完成；最终STA：**未通过 setup 时序验收**。SWNS -0.695ns、STNS -3.539ns；HWNS +0.021ns、HTNS 0.000ns。LUT 15044、REG 10033、BRAM9K 59/64、DSP 17、PLL 2。

操作见[FAT32 文件复制教程](FAT32_USAGE_20261015.md)，精确路径/范围/冻结日志见[最终验证报告](../reports/fat32_20261015/RESULT.md)。当前未生成 FAT32 新 bit，旧裸扇区 bit 不适用。尚未实板验收，未达到 +0.5ns；内部 removal 不属于 HDMI 管脚 hold。CLI 使用同一源清单直接加载，GUI elaborate 在本机出现工具崩溃，不能宣称 GUI 综合已通过。

下文均为历史证据，不能认证当前源码。

## 早先：WAV音频失败自动恢复与错误诊断

本轮57项完整ModelSim回归通过（此前54项加三个新测试），61设计源、36逻辑IO，两个TD入口一致。格式仍为48kHz/16bit/mono PCM；KEY/SW、原图片区、SD栈、仲裁、官方IP/PHY/引脚和时钟约束不变。70位status_source及全部status_video取位逐项审计通过。操作见[音频恢复说明](AUDIO_RETRY_20261014.md)。

| 项目 | 本轮最终结果 |
|---|---|
| SWNS / STNS | +0.118ns / 0.000ns |
| HWNS / HTNS | +0.021ns / 0.000ns |
| 资源 | LUT12976、REG8547、BRAM9K57/64、DSP17、PLL2 |
| 候选 | video_improve_audio_retry.bit（历史路径 `../reports/audio_retry_20261014/video_improve_audio_retry.bit`，当前目录未保留），633116字节 |
| bit SHA-256 | 565bfb3430ba7d11e7186a44307b1aa4e17066ace721f571e7138f4d9e15e196 |
| max最差 | setup，+0.118ns |
| min最差 | hold，+0.021ns |
| 实板状态 | 未写卡、未下载、未做显示/出声验收 |

最差max起点 `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/rst_syn_67.clk (rising edge triggered by clock sys_pll_m0/pll_inst.clkc[0]  { rise@0.000000ns  fall@5.000000ns  period=10.000000 })`，终点 `sd_card_bmp_m0/write_done_seen_reg_syn_19.a[0] (rising edge triggered by clock sys_pll_m0/pll_inst.clkc[0]  { rise@0.000000ns  fall@5.000000ns  period=10.000000 })`。最差min起点 `sd_card_bmp_m0/bmp_read_m0/scaling$loader/load_x_reg[1]_syn_4.clk (rising edge triggered by clock sys_pll_m0/pll_inst.clkc[0]  { rise@0.000000ns  fall@5.000000ns  period=10.000000 })`，终点 `sd_card_bmp_m0/bmp_read_m0/scaling$loader/ramread1_syn_31.addra[8] (rising edge triggered by clock sys_pll_m0/pll_inst.clkc[0]  { rise@0.000000ns  fall@5.000000ns  period=10.000000 })`。内部复位removal不能当HDMI管脚hold；整体未达到+0.5ns，外部SD/DDC/TMDS时序及Speed=NA、已有PHY警告仍未签核。

源码、bit和报告绑定见候选清单（历史路径 `../reports/audio_retry_20261014/candidate_manifest.json`，当前目录未保留），回归见57项记录（历史路径 `../reports/audio_retry_20261014/regression_completion.json`，当前目录未保留），范围审计见scope_audit.json（历史路径 `../reports/audio_retry_20261014/scope_audit.json`，当前目录未保留），最终时序见冻结STA（历史路径 `../reports/audio_retry_20261014/timing_summary.txt`，当前目录未保留）。修改前188文件已ZIP备份及SHA核验。调试阶段负时序分别归档在本轮报告目录，最终通过值只以本节及候选清单为准。

只读交付核验：

```powershell
python reports/audio_retry_20261014/delivery.py
```

此命令验证当前源码、保护范围、57项日志、冻结报告及候选SHA；再次修改源码会使候选验证失败，需要重新回归和构建。旧候选和媒体镜像保留，新bit仍使用原合成图片＋WAV镜像。


## 早先：TF卡 WAV / HDMI 音频初版候选

已完成54项ModelSim完整回归、公开刷新与欠载恢复专项、主机音频工具测试、TD综合/布局布线、独立bit生成及重载STA核验。当前61设计源、36IO。仍只用板载KEY/SW，WAV默认静音；菜单开声和制卡见[音频手册](WAV_AUDIO_20261014.md)。**未写卡、未下载、未做实板出声或白条消失验收。**

| 项目 | 本次最终报告 |
|---|---|
| SWNS / STNS | **+0.175ns / 0.000ns** |
| HWNS / HTNS | **+0.022ns / 0.000ns** |
| 资源 | LUT13063、REG8490、BRAM9K57/64（89.06%）、DSP17、PLL2 |
| 对早先板载版增量 | LUT+1611、REG+1004、BRAM9K+11、DSP+1、PLL不增加 |
| 测试 | 54项；新增7项音频；SD共享扫描/缩放/PCM循环及CRC失败隔离通过 |
| 候选 | video_improve_wav_audio.bit（历史路径 `../reports/wav_audio_20261014/video_improve_wav_audio.bit`，当前目录未保留），633116字节 |
| 保护审计 | 21个官方IP/PHY/管脚/SDC/模式时钟保护文件SHA与备份一致，两份HDMI/ACR实例逐字一致 |
| 媒体 | [四张图片＋测试音](../assets/audio_20261014/pictures_and_audio.img)，WAV起始LBA131072 |
| 外部与硬件 | Speed=NA、PHY-7002×2/PHY-5079×1及外部IO签核仍未解决；无实板完成声明 |

候选SHA-256：f4bb57e5998b0e0081c361f95cc0a44a5c40543352dc4f80f097d8454055a8ca。证据：候选清单（历史路径 `../reports/wav_audio_20261014/candidate_manifest.json`，当前目录未保留）、54项回归（历史路径 `../reports/wav_audio_20261014/regression_completion.json`，当前目录未保留）、冻结时序（历史路径 `../reports/wav_audio_20261014/timing_summary.txt`，当前目录未保留）、资源（历史路径 `../reports/wav_audio_20261014/physical_area.txt`，当前目录未保留）、备份记录（历史路径 `../reports/wav_audio_20261014/backup_record.json`，当前目录未保留）。修改前174文件已ZIP备份并逐文件SHA核验，早先候选保留。

全局max最差为 **setup**，+0.175ns；min最差为 **removal**，+0.022ns。起止点见候选清单。**内部复位recovery/removal不是HDMI管脚hold；没有达到整体+0.5ns，也没有完成SD/DDC/TMDS外部IO签核。**

首轮−3.554ns/−130.708ns、第二轮−0.663ns/−5.875ns、第三轮−0.479ns/−1.459ns负时序均归档。修复为WAV块边界与RIFF判断流水拆分、监督器复位直接寄存输出，以及仲裁器超时译码提前寄存（超时拍数保持不变）；没有添加false path、虚构IO delay或修改官方核/PHY/PLL。资源增加除音频FIFO两块、扇区缓存一块外，两份官方HDMI音频包FIFO各由七块增至十一块，故不能宣称音频只占一两块整机增量。

旧版只读核验脚本要求源码仍与旧候选一致；本次修复后该条件不成立，不能用它认证当前源码。旧bit及冻结证据仍保留。再次运行完整构建会归档当前reports公共产物；交付证据在本次专属目录冻结。

## 早先：57源板载优化历史候选

2026-10-14：**板载增量优化已完成47项ModelSim回归、公开刷新及欠载恢复两个专项、综合/布局布线和独立候选生成；尚未上板。** 控制仅现有KEY/SW，新增KEY3长按菜单、可选伽马提亮、数码管诊断、10ms上电保持及2秒视频心跳看门狗。原双模式、双缓冲、读卡和SW映射保留，音频静音、新外设暂缓。操作见[KEY/SW教程](KEY_SW_OPERATION.md)，改动见[优化说明](BOARD_OPTIMIZATION_20261014.md)。

| 项目 | 10月14日最终结果 |
|---|---|
| 工程 | 57设计源、36位逻辑IO；两个TD入口一致 |
| ModelSim | 47项完整回归全部通过；含六项新增测试，双模式集成六帧逐像素检查 |
| 专项 | 公开刷新计数器、欠载故障注入恢复通过；不含加密SDRAM/HDMI完整top |
| 综合/实现 | 新鲜Routed、Slow/Fast；候选重载STA一致 |
| SWNS / STNS | **+0.110ns / 0.000ns** |
| HWNS / HTNS | **+0.022ns / 0.000ns** |
| 资源 | LUT11452（58.43%）、REG7486（38.19%）、BRAM9K46/64（71.88%）、DSP16、PLL2 |
| 相对10月13日 | LUT+571、REG+420、BRAM9K+3、DSP/PLL不增加；整体时序余量小幅下降 |
| 候选 | video_improve_board_opt.bit（历史路径 `../reports/board_opt_20261014/video_improve_board_opt.bit`，当前目录未保留），633116字节 |
| 保护文件 | 官方IP、HDMI PHY、管脚、SDC及模式时钟约束与本轮修改前备份SHA一致 |
| 实板/外部IO | 未下载、未签核；不能以模块仿真断言实物白条已消失 |

bit SHA-256：`b7b401a2c4c5f9ad9b24ecb2a0b1060a2e7f662f7da79173145e3a2d6b979781`。来源：候选清单（历史路径 `../reports/board_opt_20261014/candidate_manifest.json`，当前目录未保留）、47项回归证据（历史路径 `../reports/board_opt_20261014/regression_completion.json`，当前目录未保留）、冻结时序（历史路径 `../reports/board_opt_20261014/timing_summary.txt`，当前目录未保留）、资源报告（历史路径 `../reports/board_opt_20261014/physical_area.txt`，当前目录未保留）。修改前174文件的[备份](../backups/board_opt_20261014_130455/workspace.zip)已逐文件SHA核验。10月13日候选保留。

SWNS最差是`supervisor/ready_reg`→`reset_writer/sync_ff_reg[1].sr`的 **recovery**，+0.110ns；最差纯setup为BMP宽度→`mult1`，+0.303ns。HWNS最差是HDMI同步复位→`osd/board_ascii[4].sr`的 **removal**，+0.022ns。内部复位recovery/removal不是HDMI管脚hold。**整体未达到+0.5ns，整体余量也没有优于基线+0.126/+0.027ns**；不能将局部路径优化或中间版较大数值当最终提升。

收尾中捕获并修复两项：写FIFO复位同步释放后ready过早导致首字丢失，包装层增加启动等待；布局发现输出高度比较进入缩放器纵向累加CE导致−0.223ns，提前寄存行末/帧末/纵向推进条件后重新47项回归及实现通过。历史失败日志/实现保留，候选对应最终源码。

警告仍在：PHY-7002×2、PHY-5079×1、Speed=NA和外部SD/DDC/TMDS缺少签核参数；官方SDRAM undriven提示未解决。新增伽马ROM的未用B端口addrb提示另列为未用端口，不等同于用户数据输入悬空；没有宣称全部warnings清零。其余限制见[待办](BOARD_PENDING.md)。

只读核验：`python reports/board_opt_20261014/verify_delivery.py`，检查当前源码、保护文件、冻结证据及bit哈希。完整复现步骤见[演示与验证](BOARD_DEMO_20261014.md)。修改源码后需重新完整验证并另建交付归档，不能覆盖本候选或套用旧报告。

## 2026-10-13 显示修复版历史记录

下述数值、41项回归及bit均对应10月13日版本。

2026-10-13：**静止画面白条/撕裂修复版已完成 41 项 ModelSim 回归、公开刷新计数器测试、综合和布局布线，并生成独立候选 bit；尚未上板验证。** 保留启动 EDID 双模式、图片/OSD适配和 KEY/SW 操作。本轮优先画面与读卡，外接音频暂缓。

| 项目 | 本轮实际结果 |
|---|---|
| 源与工程 | 54 个设计源、36 位逻辑 IO；两个 TD 入口一致 |
| 模块回归 | 41 项通过；新增 CRC 损坏/恢复、读响应排空、三帧 144 万像素带刷新和后台写入 |
| 刷新专项 | 官方公开计数器测试通过；40MHz 下每 1250 拍请求一次，31.25µs；不含加密 SDRAM PHY |
| 欠载恢复专项 | 独立故障注入通过：本帧停读、下一帧从新地址恢复、粘性错误仅复位清除；不计入41项 |
| 综合 / 布局布线 | 新鲜完整构建，Routed，Slow/Fast；未放宽实际时钟或添加隐藏违例的例外 |
| SWNS / STNS | **+0.126ns / 0.000ns** |
| HWNS / HTNS | **+0.027ns / 0.000ns** |
| 资源 | LUT 10881, REG 7066, BRAM9K 43, DSP 16, PLL 2 |
| 候选配置 | video_improve_display_fix.bit（历史路径 `../reports/display_fix_20261013/video_improve_display_fix.bit`，当前目录未保留），629624 字节 |
| 官方 IP | 16 个官方 IP 文件与修改前备份哈希一致；仅配置头 global_def.v 修正刷新周期 |
| 实板 / 外部 IO | 尚未下载验证；SDRAM PHY、SD/DDC/TMDS、电气和 Speed=NA 仍未签核 |

bit SHA-256：`d439b776df6c002d786781c6ac2ccefa211d3444d1092b719266e178f52cde6b`。来源见 候选清单（历史路径 `../reports/display_fix_20261013/candidate_manifest.json`，当前目录未保留）、完整回归清单（历史路径 `../reports/display_fix_20261013/regression_completion.json`，当前目录未保留）、冻结时序（历史路径 `../reports/display_fix_20261013/timing_summary.txt`，当前目录未保留）、官方 IP/备份核查（历史路径 `../reports/display_fix_20261013/source_audit.json`，当前目录未保留）。旧 adaptive/SW/scaling bit 不含本轮修复。

最差 setup：`sd_card_bmp_m0/bmp_read_m0/scaling$loader/w_reg[5]_syn_3.clk` → `sd_card_bmp_m0/bmp_read_m0/scaling$loader/state_reg[21]_syn_4.a[0]`，0.126ns。最差 min：`u_hdmi_svga/u0_reset_sync/O_sync_reset_reg_syn_52.clk` → `u_hdmi_svga/u_hdmi_tx_controller_wrapper/u_hdmi_video_source/S_col_cnt_reg[2]_syn_4.sr`，类型 **removal**，0.027ns。**内部复位 removal 不能当作 HDMI 管脚 hold，整体未达到 +0.5ns。**

复现：先运行 `scripts/run_tests.ps1` 与 `scripts/run_refresh_test.ps1`，再按 [修复说明](DISPLAY_REPAIR_20261013.md) 运行独立欠载恢复测试；成功后 `python reports/display_fix_20261013/record_regression.py` 记录新日志，再运行 `python scripts/run_build.py`。`verify_delivery.py` 检查当前源码/数据库/时序/回归哈希后才生成候选，并拒绝覆盖已有文件。已有候选直接核对本页哈希。历史失败构建保留在 `reports/previous_build/`。

修复原因、验证边界及上板步骤见 [显示修复说明](DISPLAY_REPAIR_20261013.md)。PHY-7002 两条、PHY-5079 一条仍待核查；这些问题不能靠内部 STA 正值宣称解决。

本轮 `check_timing` 仍列出：12项无输入延时、24项无输出延时、32项异常输入延时、4个悬空节点，以及2258个由多时钟驱动的时钟叶节点。双模式会在共享时钟网络上建立多个模式时钟，但该数量本身不能证明所有约束正确；应结合 `scripts/adaptive_clocks.tcl` 和报告逐项解释。无时钟网络、无效约束、组合环路均为0。没有用任意IO延时或额外false path消除这些提示。

## 2026-10-11 屏幕自适应版历史记录

以下段落和数值属于当时版本，不代表 10 月 13 日修复版。

2026-10-11：**屏幕自适应版已完成本机回归、综合、布局布线并生成独立候选bit；尚未上板验证。** 启动时按EDID选择640×480或800×600，图片、OSD、字幕一起适配。使用方法见 [屏幕适配手册](SCREEN_ADAPTATION_20261010.md)、[接线教程](CONNECTION_AND_USAGE.md)。

| 项目 | 本轮最终结果 |
|---|---|
| 源与工程一致性 | 54个设计源，36位逻辑IO，两个TD入口及清单一致 |
| 模块回归 | 38项全部通过，包含最终OSD/缩放流水、双模式、背压与帧清空 |
| 官方PLL/CSB模型 | 25/125及40/200MHz、固定启动时钟、切换等待通过；最后改动未更改时钟RTL |
| 综合 / 布局布线 | 完成；最终报告为Routed、Slow/Fast，来自修正时钟来源后的数据库 |
| SWNS / STNS | **+0.113ns / 0** |
| HWNS / HTNS | **+0.022ns / 0** |
| 资源 | LUT10765、REG6916、BRAM9K43、DSP16、PLL2 |
| 候选配置文件 | video_improve_adaptive.bit（历史路径 `../reports/screen_adapt_20261010/video_improve_adaptive.bit`，当前目录未保留），629624字节 |
| 官方IP | 与适配前备份逐文件SHA-256一致，没有删除或修改必要官方IP |
| 实板与外部IO | 未烧录、未验证、未签核 |

bit SHA-256：`b9fc006f2d3419fe16e1bd69bf5adc397234fa7d89c1afaf5a10e8f945361f80`。源码、数据库、回归日志和bit来源已绑定，见 完整核验（历史路径 `../reports/screen_adapt_20261010/verification.json`，当前目录未保留）、候选清单（历史路径 `../reports/screen_adapt_20261010/candidate_manifest.json`，当前目录未保留）、冻结时序报告（历史路径 `../reports/screen_adapt_20261010/timing_summary.txt`，当前目录未保留）。

最差setup为100MHz缩放加载器的 `state_reg[3]` → `y_step_reg[8]`，+0.113ns。最差min为HDMI核内部 `S_CH0_D2_shift_reg[19].sr` 的 **removal** 检查，+0.022ns；它不是HDMI管脚hold。**整体未达到+0.5ns目标。**

本轮修复了根TD入口遗漏六个模块、写FIFO ready跨域组合反馈、HDMI复位使用未同步模式信号，以及时钟约束未分别绑定实际PLL输出的问题。物理来源复核曾发现−0.068ns min违例，已用正确来源约束重新实现并由TD修复实际延时；没有屏蔽内部复位或像素/串行数据路径。详细报告中SVGA时钟经过PLL C2和像素切换器输入1。

第一次并行运行时ModelSim在tb_scaled_bmp内核崩溃，失败日志保留；随后独立重跑完整38项全部通过。写FIFO压力测试验证近满暂停、1400个数据字精确顺序和新帧清空；内存并发测试为真实FIFO/帧控制器配有界六周期模型，未代替加密SDRAM核完整刷新契约验证。

仍有PHY-7002两条、PHY-5079一条；check_timing报告无input delay 12项、无output delay 24项、abnormal input delay 32项、dummy node 4项、invalid constraint 0项，STA覆盖率99.97%，Speed=NA。SDRAM硬宏映射、外部SD/DDC/TMDS约束、板卡速度等级及显示器兼容性仍见 [待办](BOARD_PENDING.md)。这些限制不因内部余量变正而消失。

复现需运行 `python scripts/run_build.py`，它包含双模式物理时钟约束和最终fix_hold。TD图形界面可打开两个工程入口查看源文件，但默认GUI构建流程不能直接替代本轮脚本流程。生成入口为 `python reports/screen_adapt_20261010/verify_delivery.py`；它验证源/库/回归一致性并拒绝覆盖已有候选，已有文件可直接按本页哈希核验。旧根目录、SW和scaling bit均不能代表本轮自适应功能。

## 2026-10-10 固定VGA缩放版历史记录

以下数值和产物只属于历史可变尺寸双线性缩放与实体调参版，不属于当前屏幕自适应版。

| 项目 | 最终实测结果 |
|---|---|
| 源与工程一致性 | 51个设计源，36位逻辑IO，两个TD入口一致 |
| 模块回归 | 30项通过；最终插值流水另重跑九种尺寸全帧、背压、异常恢复 |
| Python工具 | 10项测试通过；七个固定尺寸转换快捷脚本均实际运行检查 |
| 素材 | 七种BMP、四图混合64MiB镜像及哈希校验完成；没有写物理卡 |
| 综合 / 布局布线 | 完成，最终final STA来自本轮新routed数据库 |
| SWNS / STNS | +0.118ns / 0 |
| HWNS / HTNS | +0.004ns / 0 |
| 资源 | LUT8849、REG5344、BRAM9K33、DSP13、PLL2 |
| bit | video_improve_scaling.bit（历史路径 `../reports/scaling_20261010/video_improve_scaling.bit`，当前目录未保留） |
| PLL模型 | 本轮PLL未改；沿用历史频率/锁定验证，未重跑，不验证实物模拟环路 |
| 实板 | 未烧录、未验证 |

最差setup：`sd_card_bmp_m0/bmp_read_m0/scaling$loader/mux102_syn_2095.clk` → `sd_card_bmp_m0/bmp_read_m0/scaling$loader/x_step_reg[23]_syn_4.d[0]`，+0.118ns。

最差min：`reset_sd/sync_ff_reg[1]_syn_4.clk` → `sd_card_bmp_m0/bmp_read_m0/rounded_file_len_reg[19]_syn_3.sr`，检查类型 **removal**，+0.004ns。内部复位removal不是HDMI管脚hold。

**整体未达到+0.5ns目标**。外部IO及板级电气未签核，Speed=NA。PHY-7002两条、PHY-5079一条仍在；check_timing为无input delay 12项、无output delay 24项、abnormal input delay 32项、dummy node 3项。官方加密SDRAM的综合undriven提示仍须结合硬宏模型核对，不能当作本次消除的缺陷。

初次缩放实现setup −2.774ns，路径经过源行BRAM、差值、乘法与加法；已拆成差值/乘法/累加流水级，重新逐像素核对和P&R，最终得到上述结果。没有放宽100MHz时钟，也没有屏蔽这条数据路径。旧失败报告由run_build归档保留。

官方HDMI/SDRAM/FIFO/PLL文件均未修改；ADC新增官方例程证实的B1按键，SDC只把key3纳入异步用户输入到首级同步器例外。RAM初值忽略提示对应缓存；新扇区/行缓存只有完整加载且tag有效才使用，复位/加载中断会使tag失效。

本次源哈希、数据库及bit来源：核验记录（历史路径 `../reports/scaling_20261010/verification.json`，当前目录未保留）。冻结报告：timing_summary（历史路径 `../reports/scaling_20261010/timing_summary.txt`，当前目录未保留）、build_manifest（历史路径 `../reports/scaling_20261010/build_manifest.json`，当前目录未保留）。原SW/effects/根目录候选保留，均不能代表当前缩放与调参功能。

## 历史结果

| 日期 | 验证与STA | 产物限制 |
|---|---|---|
| 2026-10-02/04 | 12项模块回归；+1.090/+0.011ns | 当时生成过候选bit，不能用于证明当前源码 |
| 2026-10-05 | 14项模块及PLL回归；+0.996/+0.003ns | 未生成新bit；当时报告路径后续可能被新构建更新 |
| 2026-10-07 | 官方参考适配；+0.834/+0.004ns | 最差min当时在RGB→AXIS内部复位，未生成新bit |
| 2026-10-08 | 21项模块回归；+0.193/+0.003ns | 合并版；不含本次字幕与转场 |

历史报告中的“当前”“本次”均指当时版本，不是本次缩放调参版测量。复现命令见 [README](../README.md#验证命令)，不要用旧bit或孤立的一项正余量作为上板验收结论。

10月9日较早的串口字幕转场版：25项回归、SWNS +0.414ns/HWNS +0.003ns、LUT7141/REG4525/BRAM9K23；该候选不支持SW。

10月9日SW版为26项回归、+0.588/+0.011ns；不含本次缩放和亮度/对比度实体调节。
