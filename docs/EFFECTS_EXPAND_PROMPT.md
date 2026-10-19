# 像素特效扩充 · 提示词（浮雕/马赛克/复古/锐化/素描）

> 用途：把本文件整段交给 GPT/协作者执行。目标是把现有 4 种像素特效（直通/反色/Sobel/热成像）
> 扩到 8 种，新增 **浮雕、马赛克、复古 sepia、锐化、素描**。
> **必须适配本工程**：安路 EG4S20、TD 6.2.1、复位高有效、`vs/de/x/rgb` 流式接口、整数运算。

---

## 0. 硬约束

- 复位 `rst` **高有效**。
- `vs/de` 与像素**同拍打齐**；所有模式统一**固定拍数**输出（现有 pixel_effects 是 3 拍）。
- 行缓存只存 **8bit 灰度**，用 `(* ram_style="dram" *)` 强制落 **LUT 分布式 RAM**，**BRAM 新增 0**。
- 纯整数运算：乘系数用**移位加法**逼近（参考 `pixel_effects.v` 里 `weighted_luma` 的 `77R+150G+29B` 写法），
  除号只用 `>>2/>>8` 这种 2 的幂。

---

## 1. 先读这些文件

1. [src/modules/video/pixel_effects.v](src/modules/video/pixel_effects.v)：**要改的核心**。
   - `mode_sel[1:0]` 选模式（0直通/1反色/2Sobel/3热成像），`frame_mode` 在 vs 翻转沿锁存。
   - `video_luma_window` 已提供 3×3 灰度窗口（`t0..b2`）和 `sum2`（9 格和），新特效直接复用。
2. [src/top.v](src/top.v) 164 行：`video_effect = status_video[29:28]`（[1:0]），
   同时驱动 `transition_mode` 和 `pixel_effects.mode_sel`（744 行）。**扩位时要小心这条共用线**。
3. [src/modules/video/transition_pixels.v](src/modules/video/transition_pixels.v)：行缓存 + 流水打拍范本。

---

## 2. 改 pixel_effects.v：mode 位宽 + 5 个新模式

### 2.1 位宽

- `mode_sel` 从 `[1:0]` 扩成 `[2:0]`，`frame_mode`、`mode1/mode2` 同步扩成 `[2:0]`。
- 模式表：`0` 直通、`1` 反色、`2` Sobel、`3` 热成像、`4` 浮雕、`5` 马赛克、`6` 复古、`7` 锐化（素描并入 7 或留空）。

### 2.2 各新模式公式（整数）

**浮雕 emboss（模式 4）** —— 只需 1 行 8bit 行缓存 + 1 个寄存器：

```verilog
// 左上邻灰度 gray_ul = 上一行同列、左一列 的灰度（用 1 行行缓存 + 1 寄存器取）
wire [8:0] emb = {1'b0,gray} - {1'b0,gray_ul} + 9'd128;   // clamp 到 0..255
// 输出灰度图：out = {emb,emb,emb}（浮雕一般输出灰度）
```

**马赛克 pixelate（模式 5）** —— 用坐标取整，无需行缓存：

```verilog
// 块大小 BLK=16（2 的幂）。每块只输出"块左上角"那个像素，其余像素复制它。
// 实现：x%BLK==0 && y%BLK==0 时锁存当前 rgb 到 reg block_pix，块内其余像素一直输出 block_pix。
// 若 y%BLK!=0，需要"上一行同列块"的 block_pix —— 用 1 行 24bit 行缓存（或只存 8bit 灰度做灰度马赛克省资源）。
```

**复古 sepia（模式 6）** —— 3×3 常数矩阵，纯组合，零缓存：

```verilog
// 标准 sepia 矩阵，整数近似（移位加法，参考 weighted_luma 写法）：
// R' = (393*R + 769*G + 189*B) / 1000
// G' = (349*R + 686*G + 168*B) / 1000
// B' = (272*R + 534*G + 131*B) / 1000
// 用 >>10 逼近 /1024，系数按 393/1024≈0.384、769/1024≈0.751… 写成移位加法。
```

**锐化 sharpen（模式 7）** —— 复用已有 3×3 窗口 + `sum2`：

```verilog
// 反锐化掩膜：out = 2*gray - blur，其中 blur = sum2/9（sum2 已由窗口给出）。
// 用"亮度差"方式回填颜色（和 glass_osd 的 luma_delta 同一招，省 3 倍缓存）：
//   out_ch = clamp(ch + (gray - blur), 0, 255)
// 这样锐化的同时保留颜色。
```

**素描 sketch（可选，并入模式 7 的进阶版）** —— 最复杂，作为加分项：

```verilog
// 1. gray = 灰度；2. inv = 255 - gray；3. blur_inv = 对 inv 做 3×3 盒式模糊（1 行缓存）；
// 4. 颜色减淡：out = min(255, gray*255 / (255 - blur_inv))，用流水除法或查表近似。
// 若时间不够，素描可先不做，只做锐化。
```

### 2.3 输出与对齐

- 每个新模式统一走现有 3 拍流水（`rgb1/rgb2` + case 输出），`out_vs/out_de/out_rgb` 同拍。
- `out_luma/out_luma_sum/out_window_valid/out_sobel` 这些共享给 glass_osd 的信号，**新模式下也要给出一致值**
  （建议新模式下仍输出真实灰度/真实 3×3 和，别让毛玻璃在新模式下拿到错误亮度）。

---

## 3. 改模式选择位宽（top.v + 控制寄存器）

- 现状 `video_effect = status_video[29:28]` 是 [1:0]，**同时**驱动 `transition_mode`、`mode_sel`、`slogan_select`。
- 方案 A（推荐）：新增独立 `wire [2:0] effect_sel`，在 `status_video` 位域里**另腾 1 bit**（找 [29:28] 附近空位），
  只给 `pixel_effects.mode_sel` 用；`transition_mode` 继续用原来的 `video_effect[1:0]`，互不干扰。
- 方案 B：把 `video_effect` 整体扩成 [2:0]，但要**逐处检查** transition/slogan 只用低 2 位，避免行为变。
- 无论哪种，都要改到：`picture_controls`（或生成 `status_video` 的模块）里增加"切换特效"的按键通路。

---

## 4. 验证（必须全绿）

1. 扩展 `sim/tb_pixel_effects.v`：对每个新模式喂已知图案，逐像素断言：
   - 浮雕：平坦区输出 128，边缘处出现高低差。
   - 马赛克：同一块内像素相等，块边界跳变。
   - sepia：喂纯白/纯黑/纯红，比对 Python 参考（照工程 `tb_scaled_bmp` 与 Python 参考比对的做法）。
   - 锐化：平坦区≈原图，边缘过冲。
2. `python scripts/static_check.py` **ALL PASS**。
3. ModelSim 回归 `tb_pixel_effects`、`tb_shared_luma`、`tb_visual_pipeline` **PASS**（毛玻璃共享亮度路径不能破）。
4. 核对 [reports/physical_area.txt](reports/physical_area.txt)：**BRAM 不涨**。

---

## 5. 资源预期（验收线）

- 浮雕 ~100 LUT、马赛克 ~100（灰度版）/~300（彩色版）、sepia ~300（3 组移位加）、锐化 ~100（复用窗口）、素描 ~400。
- 合计新增约 **800~1200 LUT**（现余 ~3900，够）。**BRAM 新增 0**。
