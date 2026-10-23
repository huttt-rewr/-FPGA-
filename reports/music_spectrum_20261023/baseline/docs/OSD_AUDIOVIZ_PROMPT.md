# OSD 优化 + 音频可视化 · 合一提示词（毛玻璃 OSD + 像素特效 + 波形叠加）

> 用途：把本文件整段交给 GPT/协作者执行。目标是在**已上电验证通过**的正式工程上，
> 新增三个叠加模块：①像素特效 `pixel_effects`（已写好未接入）、②毛玻璃面板 `glass_osd`（待写）、
> ③音频波形叠加 `audio_visualizer`（待写），并接入 HDMI 视频链。
>
> 必须适配本工程：安路 EG4S20（HX4S20 开发板）、TD 6.2.1、复位**高有效**、
> `vs/de/x/rgb` 流式接口、整数运算、行缓存落 LUT。
>
> 现状：`pixel_effects.v` 已在磁盘写好但**未登记、未接入**；`glass_osd.v`、音频波形模块**未写**。
> 本提示词行号基于当前源码（top.v 视频链 719-752 行、音频链 776-790 行）。

---

## 第 0 步：先读这些文件（对齐现状，不许另起炉灶）

1. [src/top.v](src/top.v) **视频链 719-752 行**：
   `frame_swap → video_coordinates → picture_adjust → picture_gamma → transition_pixels → caption_overlay → status_osd`；
   **音频链 776-790 行**（音频 PCM 已进 video_clk 域）。
2. [src/modules/video/video_coordinates.v](src/modules/video/video_coordinates.v)：**`viewport_coordinates` 用法**（下游无 x 时内部重建 x,y）。
3. [src/modules/video/pixel_effects.v](src/modules/video/pixel_effects.v)：特效模块（**已写好**，直通/反色/Sobel/热成像，固定 3 拍）。
4. [src/modules/osd/caption_overlay.v](src/modules/osd/caption_overlay.v)：OSD 叠加/文字/alpha/滚动风格范本；重点看它第 10 行怎么用 `viewport_coordinates` 重建 x,y。
5. [src/modules/osd/osd_char_rom.v](src/modules/osd/osd_char_rom.v)：5×7 字库，接口 `i_ascii[7:0], i_row[3:0] → o_row_data[7:0]`（5 列在 `bit[4:0]`，行 0~6，7~15 空白）。
6. [src/modules/audio/audio_playback.v](src/modules/audio/audio_playback.v)、[audio_effects_stream.v](src/modules/audio/audio_effects_stream.v)：音频样本接口（见下）。
7. [scripts/static_check.py](scripts/static_check.py)、[scripts/run_tests.ps1](scripts/run_tests.ps1)：登记与验证规则。

---

## 第 1 步：必须遵守的项目约定（写错就是白写）

- 复位 `rst` **高有效**；视频域时钟 `video_clk`、复位 `rst_video`。
- 视频流统一接口：`clk, rst, vs, de, x[9:0], rgb[23:0] → out_vs, out_de, out_rgb`；
  **`vs/de` 必须与像素同拍打齐**，不能错拍。
- 纯整数运算：灰度 `(77*R + 150*G + 29*B) >> 8`；**不用浮点、不用除号**（只允许 `>>2`/`>>8` 这种 2 的幂）。
- **行缓存只存 8bit 灰度**，必须让 TD 推断成**分布式 RAM（LUT）而不是 BRAM**。
  **当前 BRAM 已 61/64，只剩 3 块**，行缓存若落 BRAM 直接超。
- 所有模式统一**固定拍数**输出，不同模式延迟一致。
- **模块名全局唯一**（`static_check.py` 会查重，报错即失败）。
- 新增文件必须登记进 **3 处**：`scripts/design_files.txt`、根目录 `video_improve.al`、`src/td_project/video_improve.al`。

---

## 第 2 步：命名陷阱（最重要，先看清楚）

- top.v **732 行** `transition_pixels effects(...)`：实例名叫 `effects`，但**模块是 `transition_pixels`**
  （转场：淡入淡出/滑动），**不是** `pixel_effects`。两者是不同模块，别混。
- `transition_pixels` 只输出 `transition_vs/transition_de/transition_rgb`，**不输出 x**；
  下游任何需要 x/y 的模块，都要像 `caption_overlay` 那样内部用 `viewport_coordinates` 重建：
  ```verilog
  viewport_coordinates coords(clk, rst, vs, de, (ADAPTIVE && mode_800), x, y, ,);
  ```

---

## 第 3 步：任务一 —— 接入 `pixel_effects`（文件已写好）

### 3.1 登记（3 处）
把 `src/modules/video/pixel_effects.v` 加入：
1. `scripts/design_files.txt`
2. 根目录 `video_improve.al` 的 `<Verilog><File ...>` 列表
3. `src/td_project/video_improve.al` 的同一列表（两份 .al 必须一致，`static_check` 会比对）

### 3.2 实例化
在 top.v 的 `transition_pixels`（732-735 行）之后、`caption_overlay`（736 行）之前插入：

```verilog
// 逐像素特效：直通/反色/Sobel/热成像，固定 3 拍，内部重建 x。
wire [9:0] fx_x;
wire fx_vs, fx_de; wire [23:0] fx_rgb;
viewport_coordinates fx_coords(video_clk, rst_video, transition_vs, transition_de, mode_video, fx_x, , ,);
pixel_effects #(.DEPTH(1024), .EDGE_TH(8'd80)) fx(
    .clk(video_clk), .rst(rst_video),
    .vs(transition_vs), .de(transition_de), .x(fx_x), .rgb(transition_rgb),
    .mode_sel(video_effect),          // 见 3.3
    .out_vs(fx_vs), .out_de(fx_de), .out_rgb(fx_rgb));
```

### 3.3 `mode_sel` 来源
- 初期直接复用 `video_effect[1:0]`（`status_video[29:28]`，来自拨码 `sw[3:2]`），拨同一个开关即可
  在 直通/反色/Sobel/热成像 间切换，零新增控制逻辑，立即可演示。
- 可选扩展：后续在 `ps2_controls` 加一个"循环特效"按键，独立于转场拨码。
- 注意：Sobel 模式有 +1 列 / +1 行的固有偏移（因果 3×3 窗口），属正常，不影响验收。

---

## 第 4 步：任务二 —— 写 `src/modules/video/glass_osd.v`（毛玻璃面板）

### 接口
```verilog
module glass_osd #(
    parameter DEPTH = 1024,             // 有效行宽上限（640/800 都覆盖）
    parameter [9:0] WIN_X = 10'd120,    // 面板左上角
    parameter [9:0] WIN_Y = 10'd80,
    parameter [9:0] WIN_W = 10'd400,
    parameter [9:0] WIN_H = 10'd320
)(
    input clk, rst,                     // rst 高有效
    input vs, de,
    input [9:0] x, y,
    input [23:0] rgb,
    input [7:0] ascii_char,             // 面板文字（或内部实例化 osd_char_rom 按需取字）
    input       osd_enable,
    output reg out_vs, output reg out_de,
    output reg [23:0] out_rgb
);
```

### 视觉分层（从底到顶）
1. 原始画面。
2. 毛玻璃背景：面板矩形内对画面做 3×3 盒式模糊 + 压暗，alpha≈60% 半透明叠加。
3. 文字阴影：文字区偏移 (x-2, y+2) 的半透明黑（alpha≈50%）。
4. 文字：白色 alpha=255 不透明。

### 毛玻璃省 BRAM 技巧（YCbCr：只糊亮度、保留颜色）
```verilog
wire [7:0] y_center = (77*rgb[23:16] + 150*rgb[15:8] + 29*rgb[7:0]) >> 8;
// 对 Y 做 3×3 盒式模糊得 y_blur：只缓存 8bit 灰度，2 行行缓存，异步读+同步写，推断分布式 RAM
// 重建：亮度用模糊值、色差保留中心像素
//   out_R = clamp(R_center + (y_blur - y_center), 0, 255)，G、B 同理
```
这样"亮度糊了、颜色不糊"，人眼就是正常模糊，但行缓存只需 8bit（省 3 倍）。

### alpha 混合统一公式
```verilog
// result = (fg * alpha + bg * (255 - alpha)) >> 8
// 压暗约 40%：bg_dark = (bg * 153) >> 8
```

### 文字与字库
- 面板/文字矩形用纯组合逻辑判定（比较 `x`/`y` 是否落在矩形内）。
- 字符点阵复用 `osd_char_rom`：`i_row = 字符内行号(0~6)`，`o_row_data[4:0]` 为该行 5 列点阵。
- 字符格 8×16（5×7 字模 + 留白），写法参照 `caption_overlay` 的 `moving_char/moving_glyph/moving_lit`。

---

## 第 5 步：任务三 —— 写 `src/modules/video/audio_visualizer.v`（音频波形叠加，新增）

> 这就是扩展要求第 5 条"音频可视化"。选**时域波形**（最简单、0 额外 BRAM/DSP），
> 不建议先做 FFT 频谱（要 DSP 和更多 LUT，资源紧）。

### 5.1 音频样本来源（现成，别另造）
在 top.v **video_clk 域**里已有最终 PCM（48kHz、有符号 24bit）：
- `audio_valid`、`audio_left[23:0]`、`audio_right[23:0]`（top.v 145-146 行声明、790 行输出）。
- 48kHz 样本在 video_clk 域里每若干拍才来一个：`audio_valid` 是**单拍脉冲**，
  一次一个样本。波形模块只需在 `audio_valid` 时抓样本，不用自己算时钟频率。

### 5.2 接口
```verilog
module audio_visualizer #(
    parameter [9:0] WIN_X = 10'd24,     // 波形面板（默认左下，避开 status_osd 主区）
    parameter [9:0] WIN_Y = 10'd400,
    parameter [9:0] WIN_W = 10'd256,
    parameter [9:0] WIN_H = 10'd80,
    parameter       N     = 128         // 波形历史拍数
)(
    input clk, rst, vs, de,
    input [9:0] x, y,
    input [23:0] rgb,
    input       audio_valid,
    input signed [23:0] audio_left,     // 有符号 24bit PCM，48kHz
    input       enable,                 // 波形开关
    output reg out_vs, output reg out_de,
    output reg [23:0] out_rgb
);
```

### 5.3 实现要点
1. **抓样本**：`always @(posedge clk)` 里 `if (audio_valid) sample <= audio_left[23] ? -audio_left[23:16] : audio_left[23:16];`
   （取幅度高 8 位，存 8bit；连同符号一起移位）。
2. **历史缓存**：128 拍 × 8bit 移位寄存器（`reg [7:0] hist[0:N-1]` 右移即可，推断 LUT/寄存器，不落 BRAM）。
3. **画波形**：面板矩形内，每一列 `x` 对应一个历史样本；在垂直中心线上下按样本幅度画竖线或点。
   - 列→样本映射：`idx = N-1 - (x - WIN_X)`（最右列是最新样本）。
   - 幅度→像素：`half = (|hist[idx]| * (WIN_H/2 - 2)) >> 8`，点亮 `[center-half, center+half]`。
   - 波形用醒目单色（如绿色/青色 `24'h00FF00`），alpha 混合到原画面。
4. **延迟固定**：建议 1~2 拍，`out_vs/out_de/out_rgb` 同拍输出，与链上其它模块错拍会花屏。
5. **enable 关闭时**：直通 `out_rgb = rgb`（同样同拍）。

### 5.4 资源预期
约 **300~500 LUT，0 BRAM，0 DSP**。若行缓存/历史缓存被推断成 BRAM 就错了，改综合属性强制 distributed。

---

## 第 6 步：顶层接线与分层（改 top.v）

最终视频链（数据流从左到右，右侧叠在最上）：

```
transition_pixels → pixel_effects → glass_osd → audio_visualizer → caption_overlay → status_osd
```

- 在 `transition_pixels`（732-735）后插入 `pixel_effects`（第 3.2 节）。
- 其后接 `glass_osd`，再接 `audio_visualizer`；三者各自内部用 `viewport_coordinates` 重建 x,y。
- 把 `caption_overlay`（736-739 行）的输入 `.vs/.de/.rgb` 从 `transition_*` 改成 `audio_visualizer` 的输出。
- **控制来源**（初期，零新增基础设施）：
  - `pixel_effects.mode_sel` = `video_effect[1:0]`（sw[3:2]）。
  - `glass_osd.osd_enable`、`audio_visualizer.enable` = `video_osd`（`status_video[6]`，键盘 OSD 开关）。
- **不要**改动现有 70 位 `status_source` 布局（148 行），不要动 `frame_swap`/`picture_*`/音频链/HDMI TX。

---

## 第 7 步：验证（必须全绿，缺一不可）

1. **登记**：3 个新文件进 `design_files.txt` + 两份 `video_improve.al`（第 3.1 节）。
2. **static_check**：`python scripts/static_check.py` → `ALL PASS`（模块名唯一、清单一致、IO 仍是 40 位）。
3. **仿真**：新增 `sim/tb_glass_osd.v`、`sim/tb_audio_visualizer.v`（直通区逐像素相等、面板内模糊/波形符合预期、
   `vs/de` 与像素同拍对齐）；连同已有 `sim/tb_pixel_effects.v` 一起加进 `scripts/run_tests.ps1` 的
   `$files` 与 `foreach($tb ...)` 列表，跑 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1` 全 PASS。
4. **资源核对**：看 [reports/physical_area.txt](reports/physical_area.txt)：
   - **BRAM 必须仍 61，不能 62+**（行缓存落 BRAM 就超）；
   - LUT 不能接近 19600 上限（当前 15709，新增三模块后应 < ~18500）。
5. **综合/P&R/STA**：`python scripts/run_build.py` 全绿，SWNS/HWNS 仍非负。

---

## 资源预算（验收线）

| 项 | 现余量 | 三模块预算 | 红线 |
|---|---:|---:|---|
| LUT | ~3900（80.15% 已用） | 特效 ~500 + 毛玻璃 ~400 + 波形 ~500 ≈ 1400 | 合计后 < ~18500 |
| BRAM | **仅 3 块** | **0**（行缓存必须落 LUT） | 仍 61，不能 62 |
| DSP | 12 | 0 | 0 新增 |

关键成功标准：**三个模块的行缓存/历史缓存全部落在 LUT，BRAM 总数保持 61 不变。**

---

## 明确不要做

- 不要做 FFT 频谱（资源紧，且扩展项只要求"频谱**或**波形"，波形已满足）。
- 不要改 `frame_swap`、`picture_adjust/gamma`、音频 FIFO/播放、HDMI TX、70 位 status_source 布局。
- 不要动 `pin.adc` / 时钟 / PLL / SDRAM。
- 不要把行缓存写成 BRAM（只剩 3 块）。
