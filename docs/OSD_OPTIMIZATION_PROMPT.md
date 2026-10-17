# OSD 优化工作 · 提示词（毛玻璃 OSD + 像素特效）

> 用途：把本文件整段交给 GPT/协作者执行。目标是给现有 HDMI 视频链加
> 逐像素特效 + 半透明毛玻璃 OSD，**必须适配本工程**（安路 EG4S20、TD 6.2.1、
> 复位高有效、`vs/de/x/rgb` 流式接口、整数运算）。
>
> 现状：特效模块 `pixel_effects.v` 已经写好（见下），毛玻璃 `glass_osd.v` 待写，
> 顶层接线待做（等"A：分辨率/帧率切换"落地后一起进 top.v，避免冲突）。

---

## 第一步：先读这些文件（对齐项目，不许另起炉灶）

1. [src/top.v](src/top.v) 视频链 **707-735 行**：
   `video_coordinates → picture_adjust → picture_gamma → transition_pixels → caption_overlay → status_osd`。
2. [src/modules/video/transition_pixels.v](src/modules/video/transition_pixels.v)：**本工程行缓存 + vs/de 流水打拍对齐的风格范本**，新模块照这个写。
3. [src/modules/video/pixel_effects.v](src/modules/video/pixel_effects.v)：特效模块 A，**已实现**（直通/反色/Sobel/热成像）。
4. [src/modules/osd/caption_overlay.v](src/modules/osd/caption_overlay.v)：OSD 叠加/文字/alpha 的风格范本，重点看它怎么用 `viewport_coordinates` 重建 `x,y`。
5. [src/modules/osd/osd_char_rom.v](src/modules/osd/osd_char_rom.v)：5×7 点阵字库，接口 `i_ascii[7:0], i_row[3:0] → o_row_data[7:0]`（5 列点阵在 `bit[4:0]`，行 0~6，行 7~15 空白）。
6. [docs/PIXEL_EFFECTS_GLASS_OSD.md](PIXEL_EFFECTS_GLASS_OSD.md)：完整设计文档（含公式）。

---

## 第二步：必须遵守的项目约定（写错就是白写）

- 复位 `rst` **高有效**（全工程一致）。
- 视频流统一接口：`clk, rst, vs, de, x[9:0], rgb[23:0] → out_vs, out_de, out_rgb`；
  **`vs/de` 必须与像素同拍打齐**，不能和像素错拍。
- 时钟 `video_clk`，复位 `rst_video`。
- 纯整数运算：灰度 `(77*R + 150*G + 29*B) >> 8`；**不用浮点、不用除号**（只允许 `>>2`/`>>8` 这种 2 的幂）。
- 行缓存只存 **8bit 灰度**，不存 24bit RGB；必须让 TD 推断成**分布式 RAM（LUT）而不是 BRAM**，
  用 RAM style 综合属性（查 TD 的 `syn_ramstyle = "distributed"`）。**BRAM 现余量只剩 5 块**，行缓存若落 BRAM 就超。
- 所有模式统一**固定拍数**输出；特效和毛玻璃各保持自己的固定延迟，别让不同模式延迟不一致。

---

## 第三步：模块 B —— `src/modules/video/glass_osd.v`（毛玻璃 OSD）

### 接口

```verilog
module glass_osd #(
    parameter DEPTH = 1024,             // 有效行宽上限（640/800 都覆盖）
    parameter [9:0] WIN_X = 10'd120,    // 毛玻璃面板左上角
    parameter [9:0] WIN_Y = 10'd80,
    parameter [9:0] WIN_W = 10'd400,
    parameter [9:0] WIN_H = 10'd320
)(
    input clk, rst,                     // rst 高有效
    input vs, de,
    input [9:0] x, y,                   // y 由 viewport_coordinates 或顶层传入
    input [23:0] rgb,                   // RGB888
    input [7:0] ascii_char,             // 面板文字（或内部实例化 osd_char_rom 按需取字）
    input       osd_enable,             // 毛玻璃面板开关
    output reg out_vs, output reg out_de,
    output reg [23:0] out_rgb
);
```

### 视觉分层（从底到顶）

1. 原始画面。
2. 毛玻璃背景：对画面做 3×3 盒式模糊 + 压暗，以 alpha≈60% 半透明叠在画面上（**只在面板矩形内**）。
3. 文字阴影：文字区偏移 (x-2, y+2) 的半透明黑（alpha≈50%）。
4. 文字：白色，alpha=255 不透明。

### 毛玻璃省 BRAM 技巧（YCbCr：只糊亮度、保留颜色）

```verilog
wire [7:0] y_center = (77*rgb[23:16] + 150*rgb[15:8] + 29*rgb[7:0]) >> 8;
// 对 Y 做 3×3 盒式模糊得 y_blur（只缓存 8bit 灰度，2 行行缓存，异步读+同步写，
// 优先推断分布式 RAM）
// 重建：亮度用模糊值，色差保留中心像素
//   out_R = clamp(R_center + (y_blur - y_center), 0, 255)，G、B 同理
```

这样"亮度糊了、颜色不糊"，人眼看就是正常模糊，但行缓存只需 8bit（省 3 倍 BRAM）。

### alpha 混合统一公式

```verilog
// result = (fg * alpha + bg * (255 - alpha)) >> 8
// 压暗约 40%：bg_dark = (bg * 153) >> 8
```

### 文字与字库

- 面板矩形/文字区用纯组合逻辑判定（比较 `x`/`y` 是否落在矩形内）。
- 字符点阵复用 [osd_char_rom.v](src/modules/osd/osd_char_rom.v)：`i_row = 字符内行号(0~6)`，
  `o_row_data[4:0]` 为该行 5 列点阵，`bit[4:0]` 对应从左到右第 0~4 列。
- 字符格 8×16（5×7 字模 + 留白），写法参照 `caption_overlay` 的 `moving_char/moving_glyph/moving_lit`。

---

## 第四步：顶层接线（改 src/top.v，等 A 落地后做）

在 [src/top.v](src/top.v) 的 `transition_pixels`（715-718 行）之后、
`caption_overlay`（719-722 行）之前插入：

```verilog
pixel_effects effects2(.clk(video_clk),.rst(rst_video),.vs(transition_vs),.de(transition_de),
    .x(/* 见下方关键坑 */),.rgb(transition_rgb),.mode_sel(/* 见下 */),
    .out_vs(fx_vs),.out_de(fx_de),.out_rgb(fx_rgb));
glass_osd glass(.clk(video_clk),.rst(rst_video),.vs(fx_vs),.de(fx_de),
    .x(...),.y(...),.rgb(fx_rgb),.ascii_char(...),.osd_enable(...),
    .out_vs(caption_in_vs),.out_de(caption_in_de),.out_rgb(caption_in_rgb));
```

### 关键坑 1：x 坐标在插入点不存在

`transition_pixels` 只输出 `transition_vs/transition_de/transition_rgb`，**不输出 x**。
而特效/毛玻璃都要 x（行缓存索引），毛玻璃还要 y（面板/文字矩形）。二选一：

- (a) 给 `transition_pixels` 增加 `out_x`（与 `out_vs/out_de` 同拍打齐），顶层把 `out_x` 传给特效；
  毛玻璃再内部用 `viewport_coordinates` 重建 `y`；或
- (b) 特效和毛玻璃都像 `caption_overlay` 那样，内部用 `viewport_coordinates coords(clk,rst,vs,de,..)` 重建 `x,y`。

推荐 (b)，改动最小、和现有 `caption_overlay` 风格一致。

### 关键坑 2：mode_sel / osd_enable 来源

- `mode_sel[1:0]`（特效四选一）：初期接**空闲拨码 `sw` 的 2 个 bit**（注意别和现有 `transition_mode`
  / `running_effect` 冲突）；后续接键盘新增的控制寄存器。
- `osd_enable`：同理，初期接 `sw` 或常 1，后续接键盘 `osd_on`。

### 关键坑 3：所有延迟同拍

特效模块固定 3 拍、毛玻璃模块固定自己的 N 拍；两者内部都必须让 `out_vs/out_de/out_rgb`
**同拍输出**再交给下一级，否则画面错位。

---

## 第五步：验证（必须全绿）

1. 新增 `sim/tb_glass_osd.v`：
   - 直通区逐像素等于输入；面板内模糊/压暗符合预期；文字区白/阴影区黑符合预期。
   - 与 Python 逐像素参考比对（照本工程 `tb_scaled_bmp` 与 Python 参考比对的做法）。
   - 断言 `vs/de` 与像素同拍对齐。
2. `python scripts/static_check.py` **ALL PASS**：新源文件要登记进 `video_improve.al`
   （根目录和 `src/td_project/` **两份**都要）和 `scripts/design_files.txt`。
3. ModelSim 回归：`scripts/run_tests.ps1` 的 `$files` 与 foreach 列表加新 tb，**必须 PASS**。
4. 核对 [reports/physical_area.txt](reports/physical_area.txt)：新增行缓存必须是**分布式 RAM 而非 BRAM**，
   **BRAM 总数不能从 59 涨到 60+**；若涨了说明行缓存没推断成 LUT，改 RAM style 属性再试。

---

## 资源预期（验收线）

- LUT：反色 ~0、灰度 ~200、Sobel ~500、热成像 ~300、毛玻璃 ~400，合计约 **1500 LUT**（现余 ~4400，够）。
- BRAM：行缓存推断成分布式 RAM 时**新增 0**；若误推断成 BRAM，Sobel 2 块 + 模糊 2 块 = 4 块（余量 5，勉强，但**不允许**，必须落 LUT）。
- 关键成功标准：**行缓存必须落在 LUT，不能落在 BRAM**。
