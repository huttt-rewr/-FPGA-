# 交给 Codex 的优化提示词（最终版）

> 本文件是可直接复制给 Codex 的自包含提示词。已按用户决策锁定：
> - 音频第一步 = **ROM/BRAM 内置旋律**（TF 卡读 WAV 作为后置 P2）。
> - Day18 亮点 = **图形化 OSD 菜单**（其余亮点仅作可选项保留）。

---

你是一名资深 FPGA 工程师，接手一个已开发到"上板前收尾 + 优化打磨"阶段的 Anlogic FPGA 参赛作品。你的任务不是从零开发，而是**在现有已跑通的系统上做优化与增量功能**。请先通读工程建立完整认知，再按文末"任务清单"逐项完成；凡标注【已实现】的绝不重做。

## 1. 项目背景

- 工程目录：`E:\fpga`
- 芯片：Anlogic EG4S20BG256（HX4S20C 开发板），50MHz 有源晶振
- 功能：TF 卡 SPI 模式读 640×480 24位 BMP → 片内合封 SDRAM 双缓冲 → HDMI 1.4b 输出到显示器（含内置扬声器），支持多图切换、淡入淡出/滑动转场、亮度/对比度、OSD 状态、字幕、UART/红外/按键控制、HDMI 内嵌音频。
- 工具链：TD 6.2.1（`J:\Anlogic\td.6.2.1\bin\td_commands_prompt.exe`）；仿真 ModelSim 10.1c（`J:\win64`）
- 平台：Windows 11，Git Bash

## 2. 当前状态（精确基线，防止你误判或重做）

- 源码 54 个设计源、36 位逻辑 IO；两个 TD 工程入口一致。
- 已通过：`static_check.py` 全过；41 项 ModelSim 回归全过；综合/布局布线/STA 完成（**SWNS +0.126ns / HWNS +0.027ns**，未达 +0.5ns 目标）。
- 资源：LUT 10881、REG 7066、BRAM9K 43、DSP 16、PLL 2。
- 当前候选 bit：`reports/display_fix_20261013/video_improve_display_fix.bit`。
- **从未上板验证**；PHY-7002×2、PHY-5079×1 仍未签核。

### 已实现清单（不要重做、不要改动其已通过的行为）
- SD 卡 SPI 三层栈（spi_master→sd_card_cmd→sd_card_sec_read_write）、多图读取 `sd_card_bmp`、CRC 校验。
- SDRAM 控制器 + 双缓冲（ping-pong）+ 异步 FIFO + 突发读写 + 欠载恢复。
- HDMI 输出（加密核 + phy wrapper）、EDID 读取、**EDID 自适应 640×480/800×600**（`edid_display_mode`/`adaptive_raster`/`adaptive_video_clock`）。
- 转场：淡入淡出/滑动/交替（`frame_swap`/`transition_pixels`）；亮度/对比度（`video_enhance`/`picture_adjust`）。
- **OSD 字库**（`osd_char_rom.v` 5×7 ASCII）、状态 OSD（`status_osd`）、字幕（`caption_overlay`）。
- 按键消抖/长短按、UART 收发队列、红外 NEC 解码、7 段数码管状态码。
- **HDMI 音频通道已打通**：`audio_test_source.v` 以 48kHz/24bit 输出 440Hz 方波，经 `I_audio_valid/I_audio_left_data/I_audio_right_data` 送入 HDMI 核，显示器可发声；音量（5bit 线性移位）与静音已接。

## 3. 关键架构事实（务必据此设计，不要臆造）

1. **5 个时钟域**：`sd_card_clk`(100MHz)、`ext_mem_clk`(40MHz)、`ext_mem_clk_sft`(40MHz@187.2°)、`video_clk`(25MHz)、`hdmi_5x_clk`(125MHz)。跨域一律 `reset_sync` + 2 级同步器 + toggle 握手，不要引入新时钟域。
2. **HDMI 音频接口**（`hdmi_1_4b_transmitter_core_wrapper`）：`I_audio_valid`、`I_audio_left_data[23:0]`、`I_audio_right_data[23:0]`、`I_acr_valid`、`I_acr_cts[19:0]`、`I_acr_n[19:0]`，参数 `AUDIO_SAMPLE_RATE="48K"`。ACR 关系：`CTS = pixel_clk × N / (128 × 48000)`。当前 640×480（25MHz）CTS=25000/N=6144，800×600（40MHz）CTS=40000/N=6144，均正确。**新增音频模式时必须在两种分辨率下都给出正确的 CTS/N，且与采样时钟发生器保持一致**。
3. **视频是 RGB 直通**（`VIDEO_FORMAT="RGB"`），没有也不需要 YCbCr 转换链路（`src/modules/optional/ycbcr_to_rgb.v` 是反向参考，未启用）。
4. **复位结构**：`reset_sync`（异步置位+同步释放），各时钟域一个实例；**目前无看门狗、无独立上电延时计数器**。
5. **最差 setup 路径**：`bmp_scale_loader`（100MHz 缩放加载器）的 `w_reg`→`state_reg`，+0.126ns；最差 min 是 HDMI 核内部复位 removal +0.027ns（不是管脚 hold）。

## 4. 硬性约束（必须遵守）

1. **严禁修改官方/加密 IP 源码**：`src/ip/hdmi/hdmi_1_4b_transmitter_core_wrapper.enc.v`、`src/ip/sdram/sdr_*.enc.v`、`src/ip/pll/*`、`src/ip/fifo/afifo_*.v`、`src/modules/hdmi/lane_lvds_10_1.v`、`src/modules/hdmi/hdmi_phy_wrapper.v`。只能例化。
2. **保持 640×480 为默认主显示格式**，800×600 自适应路径保留。新增高分辨率只能是可切换模式，不得破坏现有双模式。
3. **不破坏 41 项回归**。每次改动后必须跑完整验证（见第 6 节）。
4. **不得用假 I/O delay 或额外 false path 掩盖时序告警**（`timing.sdc` 注释已明令禁止）。
5. **新增端口必须同时改 `src/top.v` 与 `src/constraints/pin.adc`**，否则 `static_check.py` 失败。
6. **小步提交**：每改一个模块单独验证；提交信息用中文，说明改动原因与验证结果。
7. **你只能保证"综合/仿真/STA 通过"，上板结论留给用户**；PHY 告警与 HDMI 电气只能靠上板/原理图，不要在代码里"修"它们。

## 5. 任务清单（按计划的第 13–20 天重组，只列可编码项）

> 优先级：P0 必须先做，P1 主体，P2 可选亮点。

### 阶段四 · 系统集成调试与优化（对应 Day 13–16）

#### 任务 P0-1：信号观测与调试基础设施（Day 13 前置，必做）
TD 的 SignalTap 等价物是在线逻辑分析仪（ILA/DEBUG_CORE）。为便于上板抓信号，在 top 中增加一个**可裁剪的调试观测模块**：
- 复用现有 `cdc_snapshot`，把关键状态打包成若干组慢速快照（HDMI `vs/de/hsync/vsync`、`sd_init_done/sd_init_error`、FIFO `wrusedw/rdusedw/empty/full`、转场状态、音频 `valid/volume/mute`）。
- 通过一个未用的拨码开关或 UART 命令切换"正常/调试"模式，调试模式下把快照送到 7 段码或 UART 打印，不占用稀缺 IO。
- 写一份《SignalTap/在线逻辑分析仪抓取清单》文档：列出每个可疑信号的期望波形（HDMI 行场、SDRAM 写使能、FIFO 水位、音频 valid 脉宽 1/(48kHz)）。
- **验收**：综合/布线通过；文档完整；不改变正常模式行为。

#### 任务 P1-1：HDMI 内嵌真音频（Day 15 主体，替换测试方波）
当前只有 440Hz 方波。按"先 ROM 内置旋律、后 TF 卡 WAV"两步，第一步必须先完成：
- **第一步（必做）ROM/BRAM 内置旋律**：新增 `audio_pcm_source`（或改造现有 `audio_test_source`），支持**从 ROM/BRAM 播放一段 PCM 旋律或提示音**：写 `scripts/wav2mif.py` 把一段 WAV 转成 16bit PCM `.mif`（注明采样率适配、位宽截断到 24bit），例化 BRAM 读地址自增，采样率 48kHz，循环或播放一次后静音。
- **第二步（必做）音频 FIFO 防爆音**：在 PCM 源与 HDMI 核之间加一个**同步 FIFO**，写入侧按数据节拍、读出侧严格 48kHz 均匀出样，解决数据断流导致的"咔哒/爆音"。读侧用 DDS 累加器（`CLK_HZ=25MHz`、`SAMPLE_HZ=48000`）产生均匀 `valid`。
- **音量（必做）**：把线性移位音量改成**指数型音量**（用查找表近似 `2^(k/32)`，避免乘法器），保留 mute。
- **ACR 精度（必做）**：核对并修正 `I_acr_cts/I_acr_n` 与采样时钟发生器，使 640×480 与 800×600 两种模式下 48kHz 一致；若真实像素时钟是 25.175MHz（非 25MHz 取整），在注释中给出精确 CTS=25175 的计算依据与取舍说明。
- **静音底噪（建议）**：静音/无数据时输出 0，避免 HDMI 数据岛残留导致底噪。
- **可选（P2）**：从 TF 卡读 WAV 文件播放（需要 SD 读通道在图片与音频间分时复用，复杂度高，仅当 P0/P1 全部绿后再做）。
- **验收**：新增/更新 testbench，验证 48kHz 均匀出样、FIFO 不空不溢、音量与静音正确、ACR 值在两种模式正确；综合布线通过；文档写明"显示器内置扬声器经 HDMI 出声"的接线与测试步骤。
- ⚠️ **明确告知用户**：原计划 Day15 的 I2S/PCM5102 外接方案**不需要**，因显示器走 HDMI 内嵌音频。

#### 任务 P1-2：显示质量（Day 14 主体）
- **伽马校正（必做）**：在 `video_enhance`/`picture_adjust` 链路加一个**简易伽马**（LUT 实现 `y=x^γ`，γ≈2.2，8bit 输入→10bit 输出→再量化），提升暗部层次，用开关或 OSD 使能。
- **色彩/亮度微调（建议）**：核对 `video_enhance` 的亮度加法/对比度乘法是否有溢出饱和保护（clamp），确保不会过曝/偏暗。
- **兼容性（文档）**：整理一份《显示器兼容参数表》，列出 640×480 与 800×600 的 HTOTAL/HSA/HFP/HBP/HSYNC 极性/VTOTAL 等，说明若某台显示器不识别应如何微调行场同步极性与前沿后沿（改参数即可，不改结构）。
- **开机画面（建议）**：复用 `color_bar` 或 OSD，在 SD 卡未就绪/加载完成前显示一个启动画面（LOGO/版本号），提升完成度。
- **验收**：回归不退化；伽马开关可见效果（testbench 比对 LUT 输出）；文档齐全。

#### 任务 P1-3：资源与时序最终优化（Day 16 主体）
- **时序收敛到 +0.5ns**：重点优化 `bmp_scale_loader`（100MHz）关键路径——拆分 `w_reg`→`state_reg` 组合逻辑、插入流水线寄存器、检查有无大扇出 mux（该路径含 `mux102`/大位宽乘法）；每步用 `run_build.py` 看 SWNS 变化，目标 SWNS≥+0.5ns 且 0 违例。
- **资源优化（建议）**：BRAM9K 43 块已较高，核对是否有可复用的行缓冲/字库；确认 EG4S20 总 BRAM 数并判断是否 <80%。清理无用寄存器（如 `display_valid` 死信号、冗余判断）。
- **降频/超频冗余测试（文档+报告）**：在文档给出"把像素时钟/内存时钟小幅降频或超频各 5% 重新综合，记录余量变化"的步骤与结论，验证稳定性冗余。
- **验收**：`run_build.py` 输出 SWNS/HWNS 比基线（+0.126/+0.027）可观测提升；无新增违例；生成最终资源/时序报告写入 `docs/`。

### 阶段五 · 稳定性与亮点（对应 Day 17–18）

#### 任务 P1-4：看门狗 + 上电复位（Day 17 主体）
- **看门狗（必做）**：新增 `watchdog` 模块（如 `src/modules/common/watchdog.v`）：喂狗信号来自主状态机心跳（如 `sd_card_bmp` 的帧推进或 `vs` 计数），超时未喂狗则拉高全局复位 `rst_all`；超时阈值参数化，默认设得足够宽松（如几秒）以免误触发。
- **上电延时复位（必做）**：新增/改造复位模块，`rst_all` 释放前加可配置延时（如 10ms），避免 PLL 锁定前各模块误启动；核实 `sys_pll` 的 `lock` 信号是否已作为复位释放条件（若未用则接入）。
- **验收**：testbench 注入"停止喂狗"断言看门狗在阈值内复位、喂狗正常不复位；综合布线通过；文档说明看门狗阈值与喂狗来源。

#### 任务 P2-1：图形化 OSD 菜单（Day 18 亮点，默认选此项）
在现有 5×7 字库基础上实现**上下选择 + 确认**的菜单，可操作项至少包含：播放/暂停、音量 +/−、切换播放模式、伽马开关。复用现有按键/红外/串口输入；菜单状态机与 `status_osd` 解耦，独立叠加在屏幕角落或中央。
- 设计要点：菜单层级用状态机（顶层条目 → 子项）；选择光标用反显或 `>` 前缀；确认/返回键复用现有 `key_press_debounce` 与 `switch_controls`；UART 命令映射到同组动作。
- **其他可选亮点**（仅当主功能稳定后，任选 1 个叠加，不强制）：动态时钟管理（空闲降频）；音频频谱柱（对 PCM 做带通能量估计或分频伪柱，注明"伪频谱"）；多种播放模式（单张循环/全部循环/随机，扩展 `player_control` 或 `sd_card_bmp` 索引逻辑）。
- **验收**：菜单可开可关（默认不影响演示）；回归不退化；文档说明操作方式与创新点。

### 阶段六 · 参赛材料与最终交付（对应 Day 19–20）

#### 任务 P2-2：文档与交付脚本（Day 19 主体）
- 更新 `docs/USER_GUIDE.md`、`docs/BOARD_PENDING.md`、`docs/BUILD_STATUS.md`，反映本轮全部改动、新资源/时序数字、新增功能用法。
- 新增《上板验证与演示步骤》文档：下载 bit、TF 卡镜像准备（`scripts/prepare_media.py`）、无卡启动画面、插卡出图、HDMI 出声、按键/串口操作、常见故障排障表。
- 新增《硬件设计说明》骨架：芯片资源、外设使用、引脚分配、时钟树、时序指标、创新点，留待用户填答辩细节。
- **验收**：文档与代码一致；交付校验脚本 `verify_delivery.py` 通过。

## 6. 验证命令（每完成一个任务必须跑）

在 `E:\fpga` 下依次执行，记录基线并对比：
1. `python scripts/static_check.py` → 必须 ALL PASS
2. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1` → 41 项必须全 PASS（新增 testbench 后应 ≥41）
3. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_refresh_test.ps1` → PASS
4. `python scripts/run_build.py` → 综合/布局布线/STA 全绿，记录 SWNS/HWNS 与资源
5. （交付时）`python reports/display_fix_20261013/verify_delivery.py`

## 7. 验收总则

- 每个任务独立可验收，完成后列出"改动文件 + 验证结果 + 残余风险"。
- 所有新增模块必须有 testbench 或在回归脚本登记。
- 明确区分"代码已验证"与"待上板签核"，不得声称上板通过。
- 最终提交信息附：
  `Co-Authored-By: Claude Code <noreply@anthropic.com>`
