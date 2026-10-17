# 实时像素特效 + 毛玻璃 OSD（对齐 EG4S20 / TD / HDMI）

> 目标：在现有 HDMI 视频链上加一个逐像素特效模块（直通/反色/Sobel 边缘/热成像）和一个
> 半透明毛玻璃 OSD。**必须适配本工程**：安路 EG4S20、TD 工具链、HDMI 输出、内部复位高有效、
> 坐标用 `pixel_x/pixel_y` 体系。全程整数运算、行缓存用 8bit 灰度省 BRAM（优先推断成分布式 RAM/LUT）。

---

## 1. 先读这些文件

- [src/top.v](src/top.v)：视频链在 651-666 行。特效模块建议插在 `transition_pixels`（658-661 行）
  之后、`caption_overlay`（662-665 行）之前。
- [src/modules/video/transition_pixels.v](src/modules/video/transition_pixels.v)：**本项目现有行缓存 + 流水线风格**，
  新模块照这个风格写（行缓存、控制信号 `vs/de` 一起打拍对齐）。

---

## 2. 新增模块 A：`src/modules/video/pixel_effects.v`（核心）

### 接口

```verilog
module pixel_effects #(
    parameter W = 640,                    // 有效行宽
    parameter [7:0] EDGE_TH = 8'd80       // Sobel 边缘阈值，可调
)(
    input clk, rst,                       // rst 高有效（与本工程一致）
    input vs, de,
    input [9:0] x,
    input [23:0] rgb,                     // RGB888
    input [1:0] mode_sel,                 // 00直通 01反色 10Sobel 11热成像
    output reg out_vs, output reg out_de,
    output reg [23:0] out_rgb
);
```

### 四种模式

1. **00 直通**：`out_rgb = rgb`，原样输出。
2. **01 反色**：`out_rgb = {8'hFF - rgb[23:16], 8'hFF - rgb[15:8], 8'hFF - rgb[7:0]}`，逐通道取反。
3. **10 Sobel**：灰度 → 3×3 窗口 → 梯度 → 阈值，输出黑底白边。
4. **11 热成像**：灰度 → 分段线性映射成彩虹色。

### 灰度（所有模式共用，整数近似）

```verilog
wire [7:0] gray = (77*rgb[23:16] + 150*rgb[15:8] + 29*rgb[7:0]) >> 8;
```

### Sobel 的 3×3 窗口（省 BRAM 的关键）

- **只用两个 8bit 灰度行缓存**（存前两行），不用 24bit：
  `reg [7:0] row1[0:W-1]; reg [7:0] row2[0:W-1];`
- 当前行用 2 个寄存器滑动：`cur_r`（当前）、`cur_l1`（左 1）、`cur_l2`（左 2）。
- 前两行的同列灰度从行缓存读，同样各延 2 拍凑齐三列。
- 拼出 3×3 九宫格（灰度值命名 `p11..p33`，p22 为当前像素）。
- **行缓存优先推断成分布式 RAM（LUT）而非 BRAM**：查 TD 的 RAM style 综合属性
  （类似 `/* synthesis syn_ramstyle = "distributed" */`），确认写法后加在行缓存声明上。
  若被推断成 BRAM，2 行 × 640×8bit = 10240bit 也才约 2 块 BRAM9K，可接受。

### Sobel 梯度与输出

```verilog
wire signed [10:0] gx = (p13 + 2*p23 + p33) - (p11 + 2*p21 + p31);
wire signed [10:0] gy = (p31 + 2*p32 + p33) - (p11 + 2*p12 + p13);
wire [10:0] mag = (gx<0 ? -gx : gx) + (gy<0 ? -gy : gy);   // |Gx|+|Gy|，不用开根号
wire edge = (mag > EDGE_TH);                                // 超过阈值即边缘
// 输出：边缘白(255,255,255)，非边缘黑(0,0,0)
```

### 热成像分段映射（无 LUT、无 BRAM，纯比较+移位）

把 0~255 灰度分四段线性映射到 蓝→青→绿→黄→红：

```verilog
reg [7:0] r_t, g_t, b_t;
always @(*) begin
    if      (gray < 8'd64)  begin r_t = 8'd0;                    g_t = gray<<2;          b_t = 8'hFF; end // 蓝→青
    else if (gray < 8'd128) begin r_t = 8'd0;                    g_t = 8'hFF;            b_t = 8'hFF - ((gray-8'd64)<<2); end // 青→绿
    else if (gray < 8'd192) begin r_t = (gray-8'd128)<<2;        g_t = 8'hFF;            b_t = 8'd0; end // 绿→黄
    else                    begin r_t = 8'hFF;                   g_t = 8'hFF - ((gray-8'd192)<<2); b_t = 8'd0; end // 黄→红
end
```

### 流水对齐（必须）

- 所有模式统一**固定拍数**输出（例如 Sobel 需要 2 拍行缓存读取 + 1 拍组合，其他模式也补齐到同样拍数）。
- `out_vs/out_de` 与 `out_rgb` **一起延迟相同拍数**（照 transition_pixels 里 `vs_q/de_q` 的做法），
  保证控制信号和像素严格对齐。

---

## 3. 新增模块 B：`src/modules/video/glass_osd.v`（毛玻璃 OSD）

### 视觉分层（从底到顶）

1. 原始画面。
2. 毛玻璃背景：对画面做邻域模糊 + 压暗，半透明叠在画面上。
3. 文字阴影：文字区右下偏移 2 像素的半透明黑。
4. 文字：白色实心，不透明。

### 毛玻璃的省 BRAM 技巧：只模糊亮度、保留颜色（YCbCr 思路）

**关键**：不缓存 24bit RGB，只缓存 8bit 灰度做模糊，颜色用"亮度差"方式重建。

```verilog
// 亮度 Y = 灰度
wire [7:0] y_center = (77*rgb[23:16] + 150*rgb[15:8] + 29*rgb[7:0]) >> 8;
// 对 Y 做 3×3 盒式模糊（平均），得到 y_blur（同样只用 8bit 灰度行缓存，2 行）
// 重建：亮度用模糊值，颜色（色差）保留中心像素不变
//   out_R = R_center + (y_blur - y_center)，G、B 同理
```

即每个通道：`out_ch = ch_center + (y_blur - y_center)`，结果夹到 0~255。
这样"亮度糊了、颜色不糊"，人眼看起来就是正常模糊，但行缓存只需 8bit（省 3 倍 BRAM）。

### Alpha 混合（统一公式）

```verilog
// 结果 = (前景*alpha + 背景*(255-alpha)) >> 8
```

- 毛玻璃层：`glass = blur后的像素`，压暗约 40%（乘 3/5 ≈ `(x*153)>>8`），以 alpha≈60% 叠在画面上。
- 阴影层：文字区偏移 (x-2, y+2) 处叠半透明黑（alpha≈50%）。
- 文字层：白色 alpha=255 完全不透明。

### 文字区与字库

- 文字区域用纯组合逻辑判定（比较 `x`/行号是否落在某矩形内）。
- 字符点阵接口：预留 `input [7:0] char_bitmap` 之类的字库接口；本工程已有
  [src/modules/osd/osd_char_rom.v](src/modules/osd/osd_char_rom.v)，可直接复用其点阵数据格式。

---

## 4. 顶层接线（改 [src/top.v](src/top.v)）

1. 在 `transition_pixels` 之后、`caption_overlay` 之前插入两个模块：
   `pixel_effects` 在前，`glass_osd` 在后（或按需求只接一个）。
2. `mode_sel[1:0]` 初期接到拨码（可复用 `sw` 的两个 bit，注意与现有 `transition_mode` 别冲突），
   后续按 [ROADMAP_KEYBOARD_MEDIA.md](ROADMAP_KEYBOARD_MEDIA.md) 阶段 1 接到键盘控制寄存器。
3. `x` 坐标：用与输入像素**同一拍**的 x（如 `gamma_x` 经与像素相同延迟后的值），
   若插点处 x 与像素不同拍，在特效模块内部把 x 与像素一起延迟补齐。
4. 确保输出 `vs/de/rgb` 三者在模块内同拍对齐，再交给下一级。

---

## 5. 验证

1. **新增 `sim/tb_pixel_effects.v`**：
   - 直通：逐像素等于输入。
   - 反色：`255-输入`。
   - Sobel：喂一个"中间黑白边界"图案（左半白右半黑），断言边界处出现白边、平坦处黑。
   - 热成像：输入灰度 0/64/128/192/255，断言输出为 蓝/青/绿/黄/红（与 Python 参考比对）。
2. **参考比对**：用 Python 写一份逐像素参考（双线性/Sobel/热映射），跟仿真输出逐像素比对
   （照本工程现有 `tb_scaled_bmp` 与 Python 参考比对的做法）。
3. `python scripts/static_check.py` 必须 ALL PASS（新源文件登记进 TD 工程清单和 static_check 源列表）。
4. ModelSim 回归含新 testbench 必须 PASS。
5. 检查 [reports/physical_area.txt](reports/physical_area.txt)：确认新增行缓存是**分布式 RAM 而非 BRAM**，
   若 BRAM 从 59 涨到 60 以上，说明行缓存没推断成 LUT，改 RAM style 属性再试。

---

## 6. 资源预期

- LUT：反色 ~0、灰度 ~200、Sobel ~500、热成像 ~300、毛玻璃 ~400，合计约 1500 LUT（你剩 ~5000，够）。
- BRAM：若行缓存推断成分布式 RAM，**新增 BRAM 为 0**；若推断成 BRAM，Sobel 2 块 + 模糊 2 块 = 4 块（你剩 5，勉强够）。
- 关键成功标准：**行缓存必须落在 LUT，不能落在 BRAM**。
