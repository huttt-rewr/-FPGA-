# 丰富功能包（转场/Ken-Burns + 频谱 + 视频播放）· 合成可落地提示词（2026-10-18）

> 用途：把本文件整段交给 GPT/协作者执行。这是一个**三合一**提示词，合并并取代
> [FFT_SPECTRUM_PROMPT.md](FFT_SPECTRUM_PROMPT.md) / [KENBURNS_TRANSITION_PROMPT.md](KENBURNS_TRANSITION_PROMPT.md) /
> [VIDEO_PLAYBACK_PROMPT.md](VIDEO_PLAYBACK_PROMPT.md)。
> 目标：在**不牺牲任何现有功能**的前提下，给这套 HDMI 多媒体展示系统加三样"更丰富"的能力——
> ① 更多转场 + Ken-Burns 变焦，② 音乐频谱（FFT），③ 真·视频播放（raw 帧序列）。

---

# 第一部分：总纲（三样共用的前提，先读懂再动手）

## 1. 一句话总目标

```
现有系统已是一条完整的"SD 读卡 → 解码 → 缩放 → 写 SDRAM → 双缓冲切帧 → 像素叠加 → HDMI 输出"流水线。
本包要做的是：在像素叠加链上增「转场/变焦」「频谱」两个慢速域效果模块，
并在读卡侧加一个「连续帧源」，把图片轮播升级成视频。不重造通路，只加叶子模块与新源模式。
```

## 2. 时序安全总纲（三样共用的硬事实）

**当前所有负 setup 路径都在 100MHz 的 sd_card_clk 域**，分三簇：
- FAT32：`request_rel_reg[22]→stream_bad_reg` −0.592、`target_index_reg[13]→cursor_reusable_reg` −0.327
- fps_control：`last_cycle_reg[7]→limited/elapsed*.ce` 合计 −0.372
- 缩放器：`y_acc_reg[16]→pixel_reg[4]` −0.071

而**视频像素链在 video_clk（25MHz/40MHz）**，每拍 40ns/25ns，余量是 100MHz 的 2.5~4 倍。

**由此推出三条硬规矩，三样都遵守：**

1. **纯像素域的效果**（转场、Ken-Burns 变焦、频谱显示）只放 video_clk，**禁止**把它们的组合逻辑放进 sd_card_clk / ext_mem_clk。
2. **碰 100MHz 域的只有"视频源"**，且它必须**复用现有 SD→SDRAM 通路**，禁止新增第二条独立的 SD 读/FAT32 查找关键路径。
3. **禁止碰三条负路径的源表达式**：FAT32 的 33 位比较器、fps_control 的 `elapsed>=last_cycle`、缩放器 `y_acc→pixel`。

> 再说一次不能省的话：**没有任何提示词能"保证"时序**（协作者已证明"逻辑更浅≠时序更好"）。
> 本包给的是**结构上的时序安全** + 每步强制"重跑 STA、只准不劣化、劣化即回退"。谁跳过 STA 门禁，谁就没资格谈"没问题"。

## 3. 铁律（零损害，三样共用）

- 保留双分辨率、800 音频、EDID、全部 OSD/字幕/玻璃/波形/特效/游戏、画质。
- 不改 70 位 status_source、不改 800 加密核、不改 hdmi_phy_wrapper/lane_lvds_10_1、不改 PLL/SDRAM 相位、不改引脚约束。
- 音频采样节奏与 HDMI 音频不受影响（现有 audio_visualizer 注释已写明 `never changes the source PCM/HDMI cadence`，本包所有新模块同样遵守）。
- 单点改动、独立验证、**逐阶段过门禁**；一个功能做完、重跑 STA 通过，才做下一个。

## 4. 执行顺序与依赖（务必按此顺序）

| 步骤 | 内容 | 风险 | 前置 |
|---|---|---|---|
| 0（前提） | fps_control `>=`→`==` 已改、640 自写已腾资源、时序收敛 | — | 本包之外，但强烈建议先完成 |
| 1 | Part A 转场 + Ken-Burns | 🟢 低 | 无 |
| 2 | Part B 频谱（FFT） | 🟢 低 | 无 |
| 3 | Part C 视频播放 | 🟡 中 | 时序已收敛更稳妥 |

> 步骤 3（视频）会加大 100MHz SD/FAT32 域吞吐，**建议在步骤 0 时序收敛之后再上高帧率**；否则只能低帧率跑。

## 5. 全包统一验证门禁（每完成一个 Part 都跑一遍）

1. `python scripts/static_check.py` → **ALL PASS**（新增源文件须登记，端口/引脚/源数一致）。
2. 对应新增的 ModelSim 单测（各 Part 内列明）→ **ALL PASS**。
3. `python scripts/run_build.py` → 综合/布线通过；**记录 SWNS/STNS，必须不劣于改前**；无新增 CRITICAL、无 coredump。
4. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1` 全量回归 → **ALL PASS**。

**统一验收硬线**：static_check + 全量回归 ALL PASS + SWNS/STNS 不劣化 + 无新增 CRITICAL + 无 coredump；
三个功能各自肉眼正确（见各 Part），原有画质/音频/双分辨率/OSD/游戏不变。

**统一回退原则**：若某 Part 让 SWNS 更负，先用 TD 时钟域/路径报告确认"新逻辑是否被综合进了 100MHz 域"——
若违反本总纲 §2 的时钟域规矩，属于实现错误，回退并修正；若确认未违规但仍劣化，如实记录并回退该 Part，不在这条线上继续加复杂度。

---

# 第二部分：Part A —— 更多转场 + Ken-Burns 变焦（🟢 低风险）

## A0. 时序安全理由

全部在 video_clk（25/40MHz）。转场是"每像素一个组合判定"，变焦是"两行缓存 + 双线性插值"，余量充足。

## A1. 结构约束（必读）

转场类型经 `transition_mode[1:0]` 走 **70 位 status_source 总线**（[top.v:181](src/top.v#L181) `video_effect=status_video[29:28]`），
该总线被历史文档锁为"70 位未动"。**禁止加宽它**。新转场只能在既有 2 位 4 槽内复用/内部扩展；Ken-Burns 用独立模块 + 使能位，完全绕开总线。

## A2. 已核对现状

- 转场引擎 [transition_pixels.v](src/modules/video/transition_pixels.v)：`effect_mode[1:0]`（0 无/1 淡入淡出/2 滑动/3 交替），
  已含 1024×24 行缓存、两拍流水。
- 调度 [frame_swap.v](src/modules/video/frame_swap.v)：据 `transition_mode[1:0]` 生成 `effect_mode/fade_level/slide_offset`，
  状态机 IDLE→OUT→SWITCH→IN，只在 `vblank` 推进。
- 顶层：frame_swap [top.v:729-733](src/top.v#L729)、transition_pixels [top.v:742-745](src/top.v#L742)。

## A3. Phase A-a —— 三种新转场（擦除/圆开/棋盘）

在 [transition_pixels.v](src/modules/video/transition_pixels.v) 内部把 `effect_mode` 扩到 `[2:0]`（仅模块内部 + frame_swap 之间，**不出 status 总线**），
对外 2 位槽位映射不变；槽 3（原"交替"）改为三者按帧轮换（复用 [frame_swap.v](src/modules/video/frame_swap.v) 的 `alternate_slide` 翻转，改成 2 位轮换计数）。

三种新转场都是纯组合判定（`covered` 信号），慢速域零压力：

1. **水平擦除 wipe**：`covered = (x < 擦除边界)`；边界复用 `slide_offset`（当作"已擦除宽度"）。
2. **圆形 iris 开**：`covered = ((x-cx)^2 + (y-cy)^2 > r^2)`；r 由 fade/slide 计数器映射，乘法用慢速域组合逻辑或 1 个 DSP。
3. **棋盘 checkerboard**：`covered = ((x>>k) ^ (y>>k))[0]`；k 随进度递减，纯 LUT 零成本。

> 三者都只依赖"当前图 + 遮罩"，与滑动一样只读本行已写像素或直接黑场遮罩，**不引入 SDRAM 随机读**。

改动点：
- [transition_pixels.v](src/modules/video/transition_pixels.v)：`effect_mode[2:0]`、新增三种 `covered`、扩展 `shift_q/covered_q`；行缓存 `line_mem` 保留给滑动。
- [frame_swap.v](src/modules/video/frame_swap.v)：`effect_mode[2:0]`、`transition_mode==3` 分支改成轮换编码。
- 不改 top.v 的 status 连线。

## A4. Phase A-b —— Ken-Burns 数字变焦

### 结构事实

显示帧从 SDRAM **顺序读出**（video_timing_data 顺序地址 → frame_read_write），**不支持随机缩放读**。
故 Ken-Burns 用**像素域行缓存变焦**：对已读出的流做"数字放大"，不碰 SDRAM 读架构。

### 新模块 `src/modules/video/video_zoom.v`

```verilog
module video_zoom #(parameter ZOOM_FRAC=4)(
    input clk,rst,vs,de,input [9:0] x,y,input [23:0] rgb,
    input [9:0] zoom_n,   // 缩放分子 16(1.0x)..24(1.5x)，实际 z=zoom_n/16
    input [9:0] pan_x,    // 缓慢平移量
    output reg out_vs,out_de,output reg [23:0] out_rgb);
```

- **两行缓存**（`(* ram_style="bram" *) [23:0] linebuf[1:0][0:1023]`）：存当前行 + 上一行。
- 输出像素 (x,y) 取输入 `( (x<<ZOOM_FRAC)/zoom_n + pan_x , (y<<ZOOM_FRAC)/zoom_n )`，对两行做双线性插值。
- **约束 z∈[1,1.5]**（只放大不缩小），两行缓存足够；pan 缓慢变化，由慢速帧计数器驱动的 LUT 生成（如 8 秒推近 + 平移一个来回）。
- 双线性插值（4 个乘加）在 25/40MHz 余量充足；必要时拆 2 拍流水，输出延迟 2 拍、功能不变。
- 资源约 400-600 LUT + 1~2 DSP + 2 BRAM。

### 集成（绕开 status 总线）

在 transition_pixels（`effects`，[top.v:742-745](src/top.v#L742)）与 pixel_filter（[top.v:752](src/top.v#L752)）之间插入 `video_zoom`，
`zoom_n/pan_x` 由本地慢速计数器生成，输出接 pixel_filter 输入。使能来源二选一并写清：
(a) 复用 `transition_mode`（转场进行中放大），或 (b) 新增一个与 `video_osd` 无关的本地开关。

## A5. Part A 验证

- 新增 `sim/tb_transition_effects.v`：断言每种 `covered` 在边界像素正确、非遮罩区逐位透传、vs/de 对齐。
- 新增 `sim/tb_video_zoom.v`：断言 z=1.0 输出=输入（恒等）、z=1.5 坐标映射正确、插值无越界。
- 其余按总纲 §5。

---

# 第三部分：Part B —— 音乐频谱（FFT）（🟢 低风险）

## B0. 时序安全理由

FFT **全部离屏算**（分时复用蝶形 + BRAM 存结果），显示只读 BRAM、走慢速像素域。
音频 48kHz，25MHz 下每两个有效样本间隔约 520 拍；128 点 FFT 每帧（2.67ms）有约 6.6 万拍可用，**时间极其充裕**。

## B1. 已核对现状

- 现有波形可视化 [audio_visualizer.v](src/modules/video/audio_visualizer.v)：N=128 环形 LUT RAM，
  面板 `WIN_X=24,WIN_Y=344,WIN_W=256,WIN_H=80`，吃 `audio_valid/audio_left(有符号24bit)/enable`，pass-through 输出。
- 顶层实例 [top.v:761-763](src/top.v#L761)：`waveform` 输出 `wave_vs/wave_de/wave_rgb` 接 [top.v:764](src/top.v#L764) `captions`。
- 音频 PCM 在 video_clk 域现成：`audio_valid/audio_left/audio_right`（[top.v:162](src/top.v#L162)）。
- 空闲 DSP 6 个，正好给蝶形乘法。

## B2. 新模块 `src/modules/video/audio_spectrum.v`

```verilog
module audio_spectrum #(
    parameter [9:0] WIN_X=24, WIN_Y=240, WIN_W=256, WIN_H=96,  // 面板放波形上方，避免叠字
    parameter N=128, parameter NB=12
)(
    input clk,rst,vs,de,input [9:0] x,y,input [23:0] rgb,
    input audio_valid,input signed [23:0] audio_left,input enable,
    output reg out_vs,out_de,output reg [23:0] out_rgb);
```

### 采集与 FFT（离屏，关键）

1. **采集缓冲**：`(* ram_style="bram" *) reg signed [23:0] samples[0:N-1];`，`audio_valid` 时写入 128 样本（可选 Hann 窗）。
2. **分时 FFT**：128 点 radix-2（7 级 × 64 蝶形）。单蝶形单元（复乘用 1~2 DSP），按"级/蝶形"计数器在样本间隔或帧边界空闲推进；
   每攒够 128 样本触发一次 FFT。`twiddle` 用 BRAM 存 64 个旋转因子（或 CORDIC/查表）。幅度近似 `|re|+|im|`，存 `mag[0:N-1]`（NB=12）到 BRAM。
3. **双缓冲**：算完一帧 `mag` 翻到显示库，下一帧写另一库——显示永不读正在写的库（同 audio_visualizer 的 bank 思路）。
4. **时序安全关键**：1-3 步只在 video_clk 慢速域、且与像素扫描无关地推进；单拍组合深度 ≤ 一个蝶形，远小于 40ns。

### 显示（屏上，只读 BRAM）

- 面板判定照抄 audio_visualizer 的 `panel` 表达式。
- 柱宽 `WIN_W/N`（256/128=2px/柱）；`bin=(x-WIN_X)/柱宽`；柱高=`mag[bin]` 缩放后。
- 非面板区 `out_rgb=rgb` 透传；面板区画柱 + 基线，背景暗化（风格与波形一致）。
- `out_vs/out_de` 与 vs/de 做 1~2 拍寄存对齐。

### 集成

在 [top.v:763](src/top.v#L763)（waveform 结束）与 [top.v:764](src/top.v#L764)（captions）之间插入一级：

```verilog
wire spec_vs,spec_de;wire [23:0] spec_rgb;
audio_spectrum spectrum(.clk(video_clk),.rst(rst_video),.vs(wave_vs),.de(wave_de),
 .x(wave_x),.y(wave_y),.rgb(wave_rgb),
 .audio_valid(audio_valid),.audio_left(audio_left),.enable(video_osd),
 .out_vs(spec_vs),.out_de(spec_de),.out_rgb(spec_rgb));
```

并把 captions 输入从 `wave_vs/wave_de/wave_rgb` 改成 `spec_vs/spec_de/spec_rgb`。
（`wave_x/wave_y` 由 [top.v:760](src/top.v#L760) 的 viewport_coordinates 生成，可复用；或传 `pixel_x/pixel_y`，二选一并仿真核对。）

## B3. Part B 验证

- 新增 `sim/tb_audio_spectrum.v`：喂合成正弦（如 1kHz@48kHz），断言峰值 bin 落在预期频率附近；非面板区逐位透传、vs/de 对齐；双缓冲读写不冲突。
- 其余按总纲 §5。

---

# 第四部分：Part C —— 真·视频播放（raw 帧序列）（🟡 中风险）

## C0. 现状与"视频"的真实含义

现有链路（[sd_card_bmp.v](src/modules/bmp/sd_card_bmp.v)）**已经是一条完整连续帧播放器**：

```
SD(FAT32) → bmp_read 解帧 → 缩放 → 写 SDRAM 非显示缓冲 → commit_req → frame_swap 切帧 → 循环
```

- `auto_play_en`（[sd_card_bmp.v:230](src/modules/bmp/sd_card_bmp.v#L230)）开自动播放。
- `fps_control`（[sd_card_bmp.v:263-266](src/modules/bmp/sd_card_bmp.v#L263)）按 `fps_mode`（0..5 = 1/2/5/10/15/**30** fps）发 `rate_tick`。
- 自动播放分支 [sd_card_bmp.v:559](src/modules/bmp/sd_card_bmp.v#L559)：`auto_play_en && auto_tick` → 载入下一帧 → 提交切帧。
- `rate_limited`（fps_control 的 busy 支路）是**现成的"跟不上就限速"信号**。

所以"视频"= **(a) 一个连续帧源（raw 容器），(b) auto-play 锁定视频模式，(c) 帧率受 SD 带宽约束。** 不是新架构。

## C1. 本 Part 更硬的铁律

- **禁止碰** FAT32 的 33 位比较器（`{1'b0,request_rel}>=request_sectors`）、fps_control 的 `elapsed>=last_cycle`、缩放器 `y_acc→pixel`。
- 视频新逻辑**只能**以"新源模式"插进现有 `bmp_read`/`sd_card_bmp` 流程，**禁止并行加一路独立 SD 读/FAT32 查找**。
- 帧率上限由实测 SD 带宽决定；`rate_limited` 拉起时必须接受降帧，不得硬塞。

## C2. Phase C-a —— 连帧 BMP 轮播（零新逻辑，先测带宽，必做）

1. 在 TF 卡根目录放 N 张同尺寸、连续编号 BMP（帧序列 000.bmp..127.bmp）。
2. `fps_mode=5`、`auto_play_en` 常开，观察 `rate_limited` 与七段码：
   - `rate_limited` 持续 0 → 30fps 可持续，进 C-b。
   - 频繁为 1 → 降 fps_mode 直到不再 limited，**该值即 C-b 的封顶帧率**。
3. **不改 RTL**，只测；把"可持续帧率"如实记入报告作为 C-b 输入。

## C3. Phase C-b —— raw 帧容器

### 格式（.rvf：Raw Video Frames）

```
[4B magic "RVF1"][2B width][2B height][2B frame_count][2B bytes_per_pixel]
[每帧：width*height*bytes_per_pixel 字节，连续存储，无行间填充]
```

- `bytes_per_pixel` 支持 **3(RGB888)** 与 **2(RGB565)**；RGB565 每帧 0.6MB（640×480），
  原生 4-bit 50MHz 理论 ~25MB/s → RGB565 可持续 ~20fps、RGB888 ~13fps（理论，以 C-a 实测为准）。
- 帧可先在上位机预缩放到 640×480/800×600，**下位机不缩放**（省开销、不碰负路径）。

### 集成：raw 当"新源模式"插进现有读卡流程

1. 在 [bmp_read.v](src/modules/bmp/bmp_read.v) 增 `VIDEO_RAW` 源模式：识别 `RVF1` magic 后跳过 BMP 头解析，
   逐帧把像素喂进**同一** `write_en/write_data` 通道（[sd_card_bmp.v:274-275](src/modules/bmp/sd_card_bmp.v#L274)），
   帧内连续、帧间由 `commit_req` 触发切帧（复用 [sd_card_bmp.v:446-460](src/modules/bmp/sd_card_bmp.v#L446) 的提交逻辑）。
2. 文件仍走 FAT32 定位一次（拿起始簇），之后**簇链顺序读**（已有 FAT 链逻辑），**不改** FAT32 越界/合法比较器。
3. 在 [sd_card_bmp.v](src/modules/bmp/sd_card_bmp.v) 加 `video_mode`：进入后锁 `auto_play_en=1`、`fps_mode` 取用户设定、
   帧到末尾回绕（复用 `next_index_limited` 回绕语义，[sd_card_bmp.v:304-313](src/modules/bmp/sd_card_bmp.v#L304)）。
4. `rate_limited` 拉高时**丢弃本帧、等下一 tick**，不堆积请求。

### 明确的"不碰"清单（违反即回退）

- 不碰 [sd_fat32.v](src/modules/sd/sd_fat32.v) 任何比较器。
- 不碰 [fps_control.v](src/modules/control/fps_control.v) 比较器。
- 不碰 [bmp_scale_loader.v](src/modules/video/bmp_scale_loader.v) 的 `y_acc→pixel`（下位机不缩放，旁路在 bmp_read 层做，不改缩放器内部）。

## C4. Part C 验证

- 新增 `sim/tb_video_raw.v`：喂一个 RVF1 容器，断言 magic 识别、帧序号递增且到末尾回绕、每帧提交恰一次不丢帧、`rate_limited` 拉高时丢帧且不堆积。
- `python scripts/run_build.py` → 记录 SWNS/STNS，**重点看 FAT32 那 −0.592 是否因吞吐增大而劣化**。
- **上板**：写含 RVF1 的卡，实测 (a) 视频连续播放不花屏；(b) 记录实际帧率与 `rate_limited` 频率；(c) 800 音频同时正常。

---

# 第五部分：统一诚实兜底

1. **无法"保证"时序**——三样里 C（视频）会加大 100MHz SD/FAT32 域吞吐，可能让 −0.592 更负。安全顺序：先收敛时序（fps_control `==` + 640 自写腾资源），再做 C；否则 C 只能低帧率。
2. 若某 Part 让 SWNS 更负：先用 TD 时钟域/路径报告确认是否违反总纲 §2 的时钟域规矩；违规则是实现错误，回退修正；未违规仍劣化则如实回退该 Part。
3. A/B 两样在慢速域，理论上几乎不可能成为新瓶颈，但**仍要过 §5 门禁**，不能省。
4. 真·编解码（MJPEG/JPEG 解码）超出本包范围，是另一个量级，竞赛期不建议；raw 容器已足够"动起来"。
5. 帧存储上限受 TF 卡容量与 SDRAM 双缓冲约束（SDRAM 8MB，RGB565 一帧 0.6MB，双缓冲 ~1.2MB，余量充足；帧数取决于卡容量）。
