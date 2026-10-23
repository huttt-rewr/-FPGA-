# 转场扩充 + Ken-Burns 变焦 + FFT 频谱 · 统一可落地提示词（2026-10-19）

> 用途：把本文件整段交给 GPT/协作者执行。本文件**合并并更正**了 `KENBURNS_TRANSITION_PROMPT.md` /
> `FFT_SPECTRUM_PROMPT.md` / `STAGE2_BOARD_ENRICH_PROMPT.md` 里的**过时数字**（时序基线、BRAM 估算），
> 并补上旧文档漏掉的**关键实现事实**（转场无 y 输入、slot3 语义、iris 圆心）。
> 执行顺序硬性：**① 转场 → ② 变焦 → ③ FFT**，每步独立过 §6 门禁再下一步。

---

## 0. 当前基线（已核实，以此为准，勿信旧文档里的旧数字）

| 项 | 值 |
|---|---|
| 当前 HEAD | `d2b13e3`（收窄 SD 初始化 attempts 计数器至 12 位，消除 100MHz 关键路径时序违例） |
| 资源 | **LUT 15794/19600 (80.58%)、BRAM 41/64 (64.06%)、DSP 23/29（剩 6）、REG 10158** |
| 时序 | **SWNS +0.105ns、STNS 0、HWNS +0.020、HTNS 0**；0 违例 |
| 回归 | 101 项 ModelSim 全过 |

关键结论：BRAM 剩 23、LUT 剩 ~3800，都不是问题；**DSP 剩 6 是新的紧约束**——② 变焦插值、③ FFT 蝶形都必须
**分时复用 DSP**，禁止为 128 点/双线性开并行乘法器。

---

## 1. 铁律（三者共用）

1. **零损害**：双分辨率、800 图声、EDID 协商、全部 OSD/字幕/玻璃/波形/特效/游戏/画质，一字不改。
2. **纯像素域逻辑只放 video_clk（25/40MHz）**，禁止进 `sd_card_clk`/`ext_mem_clk`；不新增 100MHz 关键路径。
3. **不改 70 位 status_source**（`video_effect = status_video[29:28]` 仍只有 2 位）：新转场在既有 2 位槽内扩展；
   Ken-Burns / 频谱用独立使能位绕开总线。
4. 单点改动、独立验证、逐门禁。

---

## 2. 已核对的现状事实（代码位置准确，勿重复排查）

- 转场引擎 [transition_pixels.v](src/modules/video/transition_pixels.v)（[top.v:707-710](src/top.v#L707)）：
  `effect_mode[1:0]`，**只有 `x` 输入、没有 `y`**。编码：0=无 / 1=淡入淡出（level=fade_level）/ 2=滑动（shift+cover，slide_offset）/ 3=空转（frame_swap 从不把 3 下发给它）。
- 调度 [frame_swap.v](src/modules/video/frame_swap.v)（[top.v:694-698](src/top.v#L694)）：
  `transition_mode[1:0]`：0=无 / 1=淡入 / 2=滑动 / **3=交替（`alternate_slide` 在淡入↔滑动间翻转）**；
  输出 `effect_mode[1:0] / fade_level[5:0] / slide_offset[9:0]`。
- 上游坐标链：`source_coordinates`([699] 出 pixel_x/pixel_y) → `picture_adjust`([701] 2 拍，出 adjusted_x) →
  `picture_gamma`([704] 2 拍，出 gamma_x) → transition_pixels。**y 从未穿过 adjust/gamma**，所以给 transition_pixels 补
  y 需要一条与 x 对齐的 4 拍延迟链路。
- 下游：transition_pixels([710] 出 transition_vs/de/rgb) → `fx_coordinates`([716] 重生成 fx_x/fx_y) → `pixel_effects`([717])。
- 波形可视化 `audio_visualizer`([726])、字幕 `caption_overlay`([729])、状态 OSD([733])。
- **③ 频谱插入点**：waveform([726]) 之后、captions([729]) 之前。
- **② 变焦插入点**：transition_pixels([710]) 之后、fx_coordinates([716]) 之前。

---

## 3. ① 转场（擦除 / 圆开 / 棋盘）—— 0 BRAM，先做

### 3.1 两个必须先定的决策（默认零损害）

**决策 A（slot 3 语义）**：当前 slot 3 = "交替（淡入↔滑动）"。零损害做法 = 把 slot 3 升级为 **5 效果轮播**：
淡入→滑动→擦除→圆开→棋盘→淡入…（`alternate_slide` 1 位翻转 → 3 位轮播计数）。这样**淡入、滑动两个原有效果
都还在**，只是轮播里多了 3 种，没有任何既有行为被删除（超集）。
> 备选（非零损害，必须用户显式点头才做）：slot 3 只轮播 3 种新转场、删掉淡入/滑动。默认不做。

**决策 B（补 y 坐标）**：iris/棋盘需要 y，但 transition_pixels 现在只有 x。补一条 y 链路，让 y 与 gamma_x
对齐（都是 4 拍延迟）：
1. [picture_adjust.v](src/modules/video/picture_adjust.v)：加 `input [9:0] y` 与 `output reg [9:0] out_y`，y 与 x 走**同样 2 拍**（`py<=y; out_y<=py;`）。
2. [picture_gamma.v](src/modules/video/picture_gamma.v)：同样加 `y/out_y`，同样 2 拍。
3. [top.v](src/top.v)：`picture_adjust .y(pixel_y) .out_y(adjusted_y)`；`picture_gamma .y(adjusted_y) .out_y(gamma_y)`；`transition_pixels .y(gamma_y)`。
4. [transition_pixels.v](src/modules/video/transition_pixels.v)：加 `input [9:0] y`。

> 这条 4 拍 y 链路**同时供 ② 变焦复用**（变焦也要 y），一次铺好，别各铺一条。

### 3.2 改动点（逐文件）

- [transition_pixels.v](src/modules/video/transition_pixels.v)：`effect_mode` `[1:0]`→`[2:0]`；加 `input [9:0] y`、`input mode_800`；
  新增三种 covered（见 3.3）；**0/1/2 三态现有行为一字不改**。
- [frame_swap.v](src/modules/video/frame_swap.v)：`effect_mode` 扩到 `[2:0]`；`transition_mode==3` 分支改 5 效果轮播（决策 A）。
- [top.v](src/top.v)：不改 status 连线；只加 y 链路（决策 B）+ `.mode_800(mode_video)` + `effect_mode` 位宽接线。

### 3.3 三种 covered 精确表达式（慢速域组合逻辑）

进度信号复用 frame_swap 现成的 `slide_offset`（OUT 增 / IN 减，天然"先展开再收起"）与 `fade_level`（0..31）：
1. **水平擦除 wipe**（纯 LUT）：`covered = (x < slide_offset)`，**不位移**（区别于滑动的 shift+cover）。
2. **圆形 iris 开**：`covered = ((x-cx)^2 + (y-cy)^2 > r^2)`；`cx = mode_800?400:320`，`cy = mode_800?300:240`；
   `r = max_r * progress`（progress 由 fade_level/slide_offset 映射 0..1，max_r≈对角线半长）。两个 10×10 平方用慢速域组合或 1 个 DSP。
3. **棋盘 checkerboard**（纯 LUT）：`covered = ((x>>k) ^ (y>>k))[0]`；`k` 随进度从大→小（格子由细变粗，控制覆盖比例）。

> 注意：这三种只做"黑场遮罩式"揭示，与滑动一样只读本行已写像素，**不新增 SDRAM 随机读**。

---

## 4. ② Ken-Burns 数字变焦 —— +6 BRAM（旧文档写 "2 BRAM" 是错的）

- 显示帧从 SDRAM **顺序读**，不支持随机缩放读 → 用**像素域行缓存变焦**（对已读出流做数字放大），不碰 SDRAM。
- 新建 [src/modules/video/video_zoom.v](src/modules/video/video_zoom.v)，接口（复用 ① 的 gamma_x/gamma_y 作输入坐标）：

```verilog
module video_zoom #(parameter ZOOM_FRAC=4)(
    input clk,rst,vs,de,input [9:0] x,y,input [23:0] rgb,
    input [9:0] zoom_n,   // 缩放分子 16(1.0x)..24(1.5x)，z=zoom_n/16
    input [9:0] pan_x,    // 缓慢平移量
    output reg out_vs,out_de,output reg [23:0] out_rgb);
```

- 两行缓存：`(* ram_style="bram" *) reg [23:0] linebuf[0:1][0:1023]`。**资源更正**：1024 深度 BRAM9K 一行只能存 8-9bit，
  故 **1024×24 一行 = 3 个 BRAM9K，两行 = 6 个**（旧提示词写 "2 BRAM" 是低估）。
- 输出 (x,y) 取输入 `((x<<ZOOM_FRAC)/zoom_n + pan_x , (y<<ZOOM_FRAC)/zoom_n)`，对两行缓存做双线性插值。
- 约束 z∈[1,1.5] 只放大不缩小；pan/zoom 由慢速帧计数器驱动的参数 LUT 生成（如 8 秒推近 + 平移一个来回）。
- 双线性 4 乘加在 25/40MHz 余量足，可拆 2 拍流水（输出延迟 2 拍、功能不变）。
- 集成：插在 transition_pixels([710]) 之后、fx_coordinates([716]) 之前；zoom 的 out_vs/out_de 喂给 fx_coordinates 与
  pixel_effects。使能位独立（不由 status 总线选），建议复用 `transition_mode`（转场进行中放大）或本地开关，二选一写清。
- 资源：~400-600 LUT + 1-2 DSP（分时）+ 6 BRAM。

---

## 5. ③ FFT 音乐频谱 —— +3-6 BRAM（旧文档"几乎不占"是错的）

- 新建 [src/modules/video/audio_spectrum.v](src/modules/video/audio_spectrum.v)，128 点 radix-2 **分时 FFT**（7 级×64 蝶形），
  单蝶形复乘用 **1 个 DSP 分时**（别开并行乘法器，DSP 只剩 6）。
- 音频 48kHz，25MHz 下两样本间 ~520 拍，每帧(2.67ms)~6.6 万拍 → 蝶形慢慢算、离屏；结果进 BRAM，屏上只画柱。
- **资源更正**：采样缓冲 + 64 旋转因子 + 幅度谱双缓冲 + 蝶形工作区 ≈ **3-6 BRAM9K**。
- 幅度近似 `|re|+|im|` 省 sqrt；双缓冲，显示永不读正在写的库。
- 面板照抄 audio_visualizer 的 pass-through 风格（非面板透传），柱宽 WIN_W/N=2px/柱，坐标与波形错开，`enable` 接 `video_osd`。
- 集成：插在 waveform([726]) 之后、captions([729]) 之前；captions 输入从 `wave_*` 改 `spec_*`。
- 资源：~500-800 LUT + 1-2 DSP + 3-6 BRAM。

---

## 6. 统一验证门禁（每步全绿才算过）

1. `python scripts/static_check.py` → ALL PASS（新增源文件登记、端口/引脚一致）。
2. 新增单测：① `tb_transition_effects`（断言三种 covered 边界像素、非遮罩区逐位透传、vs/de/x/y 对齐）；
   ② `tb_video_zoom`（z=1.0 恒等、z=1.5 映射、插值无越界）；③ `tb_audio_spectrum`（合成正弦峰值 bin、透传、双缓冲）。
3. `python scripts/run_build.py` → 布线通过；**SWNS/STNS 不劣于 +0.105 基线**；无新增 CRITICAL、无 coredump。
4. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1` 全量回归 ALL PASS。

**统一验收硬线**：static_check + 全量回归 ALL PASS + SWNS/STNS 不劣化 + 无新增 CRITICAL；
新转场/变焦/频谱肉眼正确、不撕裂不花屏、原有画质/音频/双分辨率/OSD/游戏不变。

---

## 7. 诚实兜底

1. "保证时序没问题"只靠"慢速域 + 重跑 STA"证明，不靠断言。若 SWNS 劣化，先查新逻辑是否被错误放进 100MHz 域（TD 时钟域报告），违规则回退。
2. ① 的 slot 3 若改成"只轮播 3 新转场"（删淡入/滑动）是**非零损害取舍**，必须用户显式点头，默认不做。
3. ② 的 zoom 插值若在 25MHz 吃紧，拆 2 拍流水即可。
4. 真·缩小（z<1）要更深行缓存，超出本文件，默认不做。
