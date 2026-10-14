# 时序约束与验证边界

> 当前10月14日板载优化版：SWNS **+0.110ns**、HWNS **+0.022ns**，STNS/HTNS均为0。最差max为上电监督器到写复位同步链的recovery，最差min为HDMI同步复位到OSD字符寄存器的removal；最差纯setup为+0.303ns。内部复位检查不是HDMI管脚hold。整体余量未优于10月13日基线，也未达+0.5ns；尚未上板及外部IO签核。来源、资源及独立bit见[构建状态](BUILD_STATUS.md)，下面10月11日及更早数值是历史证据。

更新：2026-10-11，依据屏幕自适应版的新构建；功能和使用见 [屏幕适配手册](SCREEN_ADAPTATION_20261010.md)。

## 1. 当前实测结论

10月11日屏幕自适应版：SWNS +0.113ns、HWNS +0.022ns，STNS/HTNS为0。

最差setup：`sd_card_bmp_m0/bmp_read_m0/scaling$loader/state_reg[3]_syn_4.clk` → `sd_card_bmp_m0/bmp_read_m0/scaling$loader/y_step_reg[8]_syn_4.d[1]`，+0.113ns。

最差min：`video_clk_syn_2447.clk` → `u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_assemble/S_CH0_D2_shift_reg[19]_syn_4.sr`，检查类型 **removal**，+0.022ns。内部复位removal不是HDMI管脚hold。

整体未达到+0.5ns；外部IO未签核、未上板。EG4S20BG256、Speed=NA。冻结证据：[报告](../reports/screen_adapt_20261010/timing_summary.txt)、[核验](../reports/screen_adapt_20261010/verification.json)。

## 2. 从基础区分时序检查

setup检查数据在采样沿之前是否足够早稳定；hold检查之后是否继续保持。recovery/removal针对异步控制（例如复位释放）与时钟沿的关系。报告汇总中的min余量可能来自removal，必须继续看检查类型和寄存器端点。

给HDMI PAD增加延时不会自动修复加密核内部复位网络。不能通过把相关时钟声明异步、全部reset设false path，或把推测的延时直接加在余量上宣称完成优化。物理延时属性是否可用，还要看TD版本、IO原语和标准组合；旧试验曾被TD拒绝，见 [10月4日记录](REVISION_20261004.md)。

## 3. 时钟与PLL

50MHz参考；控制/SD逻辑100MHz；SDRAM控制及相移输出40MHz；视频PLL提供25/125及40/200MHz，经专用CSB全局资源选择。当前PLL采用NOCOMP/VCO内部反馈，VCO为1GHz。PLL手册PDF2–5支持频率范围、无补偿模式及125ps细相位步长的解释，但不是对本工程模拟环路的验收。

`scripts/adaptive_clocks.tcl` 将切换器输出分别关联实际PLL C0/C2及C1/C3，保留不同输入的插入延时；两档输出互斥，同档像素/串行仍相关，25MHz启动时钟始终参与分析。只从50MHz参考定义倍率会丢失输入路径选择，复核曾发现隐藏的−0.068ns min违例，因此本版重新布线并执行fix_hold。不能使用旧约束结果替代最终报告。

准确相位应联合当前PLL参数、官方模型和最终时钟报告核对；历史约187°的报告值不能孤立写成板上实测187.2°。NOCOMP不补偿时钟网络，不能将其理解为到达各负载的延时为零。当前手工补丁的向导再生成和硬件掉锁恢复仍待复核。

HDMI像素/串行、SDRAM控制/相移时钟需保留相关分析。当前SD SPI管脚时钟约200kHz初始化、25MHz正常读写，不是100MHz控制逻辑时钟。

## 4. IO约束需要真实板级依据

| 接口 | 缺少/需核对的依据 | 正确处理 |
|---|---|---|
| SD SPI | 卡tCO、输入setup/hold、走线与电平转换延迟 | 建立与SD时钟相关的min/max输入输出约束，覆盖低速/高速 |
| HDMI DDC | 上拉供电、电容、转换电路、接收端I²C时序 | 核对SDA采样、SCL/SDA电气和上升时间 |
| HDMI TMDS | 板上网络、终端、共模、输出特性、布线 | 结合ODDR/串行时序和板级测量，不能照搬普通CMOS output delay |
| 合封SDRAM | EM638325时序、硬宏模型、相移和局部时钟资源 | 核对EG_PHY_SDRAM_2M_32的生成时序及物理映射，不当作顶层外接SDRAM总线随意加delay |

BG256的Bank1/3供电限制、伪LVDS的150/150/140Ω表格以及5V钳位限制已取得官方依据，见 [资料对照](VENDOR_REFERENCE_20261009.md)。这不补齐HX4S20C整板原理图，也不证明HDMI电气通过。

## 5. 当前工具提示与CDC

本次仍有两条PHY-7002（SDRAM位置未遵从）和一条PHY-5079（系统PLL C2到SDRAM_CLK局部布线）。这些是实现警告，不是板上已测得的初始化或训练错误；需厂商模型/工具说明并配合实际读写验证。历史USR-6135/PHY-5014不能继续列成当前仍存在的同一警告。

check_timing有12个无input delay、24个无output delay、32个abnormal input delay检查项。合封硬宏生成的部分IO需要单独解释；不能用任意0ns/1ns填满来消除提示。

异步SW和按键仅首级同步边界有例外，后续同步级和跨域数据一致性仍要验证。新版Soft FIFO手册PDF17–18强调不能用全域异步/false path覆盖其Gray指针max-delay约束。当前旧生成FIFO须独立核对约束是否实际加载，不能仅凭有IPC文件就宣称完成CDC签核。

## 6. 历史数值与下一步

| 构建记录日期 | SWNS / HWNS（ns） | 说明 |
|---|---|---|
| 10月2日/4日记录 | +1.090 / +0.011 | 当时版本及历史候选bit |
| 10月5日 | +0.996 / +0.003 | 整理与帧尾修复版 |
| 10月7日 | +0.834 / +0.004 | 官方例程适配版，最差min当时在RGB→AXIS内部复位 |
| 10月8日 | +0.193 / +0.003 | 历史合并版，最差min为HDMI EDID/IIC内部removal |
| 10月9日 | +0.414 / +0.003 | 字幕转场版，最差min为视频域内部removal |

历史比较须结合不同源码与布局，不能把最大数字选作当前结果。下一步先确定SDRAM的40MHz突发/刷新/返回契约，再处理PLL与物理警告、补真实外部约束、重跑综合/P&R和回归，最后按 [待办验收条件](BOARD_PENDING.md) 上板验证。

历史10月9日SW版：+0.588/+0.011ns；最差min为HDMI内部EDID/I²C复位removal。ADC新增4路官方SW；SDC仅调整异步用户输入首级例外。

10月10日最终：+0.118/+0.004ns。插值初版−2.774ns经真实流水分级消除；最终仍未达+0.5ns。
