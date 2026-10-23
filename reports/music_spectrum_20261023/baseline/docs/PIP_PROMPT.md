# 画中画 PiP · 提示词（SDRAM 双读通道 + 小窗叠加）

> 用途：把本文件整段交给 GPT/协作者执行。目标：主画面显示一张图/视频的同时，
> 在角落叠一个**小窗**显示另一路内容，外套毛玻璃边框 + OSD 标注，做成"专业播放器"观感。
> **必须适配本工程**：安路 EG4S20、TD 6.2.1、复位高有效、`vs/de/x/rgb` 流式接口。

---

## 0. 硬约束（这是本项目目前风险最高的一个）

- **BRAM 新增必须为 0**（全工程只剩 3 块）。小窗像素必须走 **SDRAM（外部）** 或 **LUT 行缓存**，
  **不得**用 BRAM 开帧缓存。
- 复位 `rst` **高有效**；`vs/de` 与像素**同拍打齐**。
- 主画面链路（`pixel_effects → glass_osd → audio_visualizer → caption_overlay → status_osd`）
  **不得被破坏**；PiP 作为其中/其后的一级叠加，关掉时**逐像素透传**。

---

## 1. 先读这些文件（搞清楚现有 SDRAM 读通道）

1. [src/top.v](src/top.v)：视频链 724-770 行 + **SDRAM 帧读**部分（搜 `frame` / `sdr` / `App_rd`，
   找到主画面是怎么从 SDRAM 读到 `vs/de/rgb` 的）。
2. [src/modules/memory/frame_read_write.v](src/modules/memory/frame_read_write.v)、
   [src/modules/memory/frame_fifo_read.v](src/modules/memory/frame_fifo_read.v)：帧读 FIFO 与仲裁。
3. [src/ip/sdram/sdr_wrrd.enc.v](src/ip/sdram/sdr_wrrd.enc.v)：SDRAM 控制器 IP 封装（读命令、突发）。
4. [src/modules/video/glass_osd.v](src/modules/video/glass_osd.v)：**毛玻璃边框可直接复用**，
   小窗套一层半透明框就很有质感（`darken/blend` 函数照抄）。

---

## 2. 分两个里程碑（先易后难，别一步到位）

### 里程碑 A：静态小窗（先跑通叠加 + 时序，不碰 SDRAM）

- 新增 `src/modules/video/pip_overlay.v`：在画面右下角（如 `x∈[400,620]`、`y∈[300,460]`）画一个
  **固定内容的小窗**（先放纯色 + 边框 + "PIP" 文字），其余区域透传。
- 目的：把 **小窗的矩形判定、边框、文字、vs/de 打拍对齐** 全部跑通，这一步不涉及任何 SDRAM。
- 插在 `status_osd` 之后、HDMI 之前（同 `snake_game` 的插点）。

### 里程碑 B：小窗读 SDRAM 第二路（真正的 PiP）

- 让 SDRAM 控制器**多开一个读通道**给小窗：小窗像素地址 = `小窗基址 + (py*小窗宽 + px)`，
  在主扫描到达小窗区域前**预取**到一个小 FIFO（用现有 `frame_fifo_read` 或新开一个）。
- 关键难点（写清思路）：
  1. **读仲裁**：主画面读 + 小窗读 两路对 SDRAM 的请求不能打架，用现有仲裁器或加一个简单优先级仲裁。
  2. **扫描时序对齐**：小窗只在 `(x,y)` 落在小窗矩形内才消耗 FIFO 数据，其余时刻 FIFO 只填不取，
     靠 `afull` 背压停读（复用 `frame_read_write` 里 FIFO 满/空保护思路）。
  3. **换图**：小窗内容切换 = 改 SDRAM 基址，跟主画面的"换图节拍"解耦，可独立切换。

---

## 3. 顶层接线（改 src/top.v）

```verilog
pip_overlay pip(.clk(video_clk),.rst(rst_video),.vs(osd_vs),.de(osd_de),
    .x(...),.y(...),.rgb(osd_rgb),           // 主画面（status_osd 之后）
    .pip_en(pip_on),                          // 小窗开关
    .pip_rgb(pip_fifo_data),.pip_valid(pip_fifo_valid),   // 里程碑 B 才接 SDRAM
    .out_vs(hdmi_vs),.out_de(hdmi_de),.out_rgb(hdmi_rgb));
```

- 里程碑 A：`.pip_rgb` 接常量、`.pip_valid` 接 1。
- 里程碑 B：`pip_fifo_*` 来自新开的 SDRAM 第二读通道。

---

## 4. 验证（必须全绿）

1. 新增 `sim/tb_pip_overlay.v`：
   - 关小窗时逐像素等于输入；开小窗时小窗矩形内 = 小窗内容、矩形外 = 输入、边框/文字正确。
   - `vs/de` 与像素同拍（断言）。
2. 里程碑 B 再加 `sim/tb_pip_sdram.v`：模拟 SDRAM 两路读，断言小窗像素在正确位置、无错位/无下溢。
3. `python scripts/static_check.py` **ALL PASS**；新源文件登记进 `video_improve.al`（两份）和
   `scripts/design_files.txt`。
4. ModelSim 回归新增 tb **PASS**；TD 综合走 `scripts/run_build.py` 全绿。
5. 核对 [reports/physical_area.txt](reports/physical_area.txt)：**BRAM 不涨**；小窗预取 FIFO 若落 BRAM 就改用现有资源。

---

## 5. 资源预期（验收线）

- 里程碑 A：叠加 + 边框 + 文字 ≈ **300 LUT**，BRAM 0。
- 里程碑 B：第二读通道仲裁 + 预取 FIFO ≈ **500~800 LUT**（FIFO 用 LUT 或复用 SDRAM 侧已有 FIFO），BRAM 0。
- 关键成功标准：**整个 PiP 不新增任何 BRAM**。
