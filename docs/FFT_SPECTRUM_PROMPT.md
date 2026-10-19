# 音频频谱分析（FFT）· 可落地提示词（2026-10-18）

> 用途：把本文件整段交给 GPT/协作者执行。目标：在现有音频可视化基础上，新增一个**音乐频谱柱状图**
> （128 点 FFT），与现有波形可视化（时域）配对，做成"时域+频域"双视图。
> 时序安全铁律：**FFT 全部算在离屏路径 + BRAM 缓存，显示只走 25/40MHz 慢速像素域**，不新增任何 100MHz 关键路径。

---

## 0. 为什么这条天然时序安全（务必先懂，别自作聪明挪到 100MHz）

当前所有负 setup 路径的根因（FAT32 33 位比较器 / fps_control `elapsed>=last_cycle` / 缩放器 `y_acc→pixel`）已在 HEAD 修净，
现 **SWNS +0.105ns 全绿**。本功能全部放在 **video_clk（25MHz/40MHz）**：每拍 40ns/25ns，余量是 100MHz 的 2.5~4 倍，**根本不是时序瓶颈**。
只要 FFT 蝶形运算**不放进 100MHz 域**，本功能对整体时序的影响趋近于零。

音频采样率 48kHz，25MHz 下每两个有效样本间隔约 520 拍；128 点 FFT 每帧（2.67ms）有约 6.6 万拍可用。
所以 FFT 用**分时复用的小蝶形单元**慢慢算，结果进 BRAM，显示时只读 BRAM——离屏计算、屏上只画柱。

---

## 1. 已核对的现状

- 现有波形可视化 [audio_visualizer.v](src/modules/video/audio_visualizer.v)：N=128 环形 LUT RAM，面板
  `WIN_X=24, WIN_Y=344, WIN_W=256, WIN_H=80`，吃 `audio_valid / audio_left(有符号24bit) / enable`，
  输出 `out_vs/out_de/out_rgb`（pass-through 风格，非面板区透传）。
- 顶层实例在 [top.v:761-763](src/top.v#L761)：`waveform` 输出 `wave_vs/wave_de/wave_rgb` 接 [top.v:764](src/top.v#L764) 的 `captions`。
- 音频 PCM 在 video_clk 域现成：`audio_valid / audio_left / audio_right`（[top.v:162](src/top.v#L162)）。
- 空闲 DSP：23/29，**剩 6 个**，正好给蝶形乘法用。

---

## 2. 铁律

- **零损害**：不动现有波形可视化、不动音频流/HDMI 采样节奏（注释明确：`This never changes the source PCM/HDMI cadence`，本条同样必须遵守）。
- 新增逻辑只在 video_clk 域；**禁止**把 FFT 或柱状图计算放进 sd_card_clk/ext_mem_clk。
- 不改 70 位 status_source、不改音频链、不改 FAT32/fps_control/缩放器。
- 单点改动、独立验证；过门禁再进下一步。

---

## 3. 实现：新建 `src/modules/video/audio_spectrum.v`

### 3.1 接口（照抄 audio_visualizer 的 pass-through 风格）

```verilog
module audio_spectrum #(
    parameter [9:0] WIN_X=24, WIN_Y=240, WIN_W=256, WIN_H=96,  // 面板放在波形上方，避免叠字
    parameter N=128, parameter NB=12                             // NB=幅度位宽
)(
    input clk,rst,vs,de,input [9:0] x,y,input [23:0] rgb,
    input audio_valid,input signed [23:0] audio_left,input enable,
    output reg out_vs,out_de,output reg [23:0] out_rgb);
```

### 3.2 采集与 FFT（离屏，关键）

1. **采集缓冲**：`(* ram_style="bram" *) reg signed [23:0] samples[0:N-1];`，在 `audio_valid` 时写入 128 个样本（可选加 Hann 窗乘）。
2. **分时 FFT**：128 点 radix-2（7 级 × 64 蝶形）。做一个单蝶形单元（复乘用 1~2 个 DSP），按"级/蝶形"计数器在音频样本到达间隔内（或每帧边界）空闲推进；每次攒够 128 样本触发一次 FFT。
   - 蝶形：`twiddle` 用 BRAM 存 64 个旋转因子（或实时 CORDIC/查表）。
   - 幅度近似 `|re|+|im|`（省一个 sqrt），存 `mag[0:N-1]`（NB=12 位）到 BRAM。
3. **双缓冲**：算完一帧，`mag` 翻转到"显示库"，下一帧 FFT 写另一库——**显示永不读正在写的库**（同 audio_visualizer 的 bank 思路）。
4. **时序安全的关键**：上面 1-3 步**只在 video_clk 慢速域**、且与像素扫描无关地推进；FFT 单元被分时复用，单拍组合深度 ≤ 一个蝶形，远小于 40ns。

### 3.3 显示（屏上，只读 BRAM）

- 面板判定照抄 audio_visualizer 的 `panel` 表达式（x/y 落在 WIN_X..WIN_X+WIN_W、WIN_Y..WIN_Y+WIN_H）。
- 柱宽 `WIN_W/N`（256/128=2px/柱）；`bin = (x-WIN_X)/柱宽`；柱高 = `mag[bin]` 缩放后。
- 非面板区：`out_rgb = rgb`（透传）；面板区：画柱 + 顶边基线，其余背景（暗化或保留原色，风格与波形一致）。
- `out_vs/out_de` 与 vs/de 做 1~2 拍寄存对齐（同 audio_visualizer 的 `vs1/de1` 方式）。

### 3.4 集成进 top.v

在 [top.v:763](src/top.v#L763)（waveform 实例结束）与 [top.v:764](src/top.v#L764)（captions）之间插入一级：

```verilog
wire spec_vs,spec_de;wire [23:0] spec_rgb;
audio_spectrum spectrum(.clk(video_clk),.rst(rst_video),.vs(wave_vs),.de(wave_de),
 .x(wave_x),.y(wave_y),.rgb(wave_rgb),
 .audio_valid(audio_valid),.audio_left(audio_left),.enable(video_osd),
 .out_vs(spec_vs),.out_de(spec_de),.out_rgb(spec_rgb));
```
并把 captions 的输入从 `wave_vs/wave_de/wave_rgb`（[top.v:764](src/top.v#L764)）改成 `spec_vs/spec_de/spec_rgb`。
（`wave_x/wave_y` 已由 [top.v:760](src/top.v#L760) 的 viewport_coordinates 生成，可直接复用；若面板不需要坐标重映射，可传 `pixel_x/pixel_y` 或 `wave_x/wave_y` 任选，二选一并在仿真核对。）

---

## 4. 验证（全绿才算过）

1. `python scripts/static_check.py` → ALL PASS（新增 `audio_spectrum.v` 计入源文件，端口一致）。
2. 新增 `sim/tb_audio_spectrum.v`：
   - 喂合成正弦（如 1kHz、48kHz 采样），断言峰值 bin 落在预期频率附近；
   - 断言非面板区像素逐位透传、vs/de 对齐；
   - 断言显示读库与写入库不冲突（双缓冲）。
3. `python scripts/run_build.py` → 综合/布线通过；**记录 SWNS/STNS，必须不劣于改前**（见 §6）。
4. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1` 全量回归 ALL PASS。

---

## 5. 验收硬线

**static_check + 回归 ALL PASS + SWNS/STNS 不劣化（或改善）+ 无新增 CRITICAL + 无 coredump；
柱状图随音乐跳动、非面板区画面不变、音频/画质不变。**

---

## 6. 诚实兜底

1. **"保证时序没问题"只能靠本设计 + 重跑 STA 证明**，不能靠断言。本功能的保险在于：FFT 离屏 + BRAM 缓存 + 慢速像素域。若协作者把蝶形挪进 100MHz 域，即违反本文件，必须回退。
2. 若 SWNS 变差：先查是否新增逻辑被综合进了 100MHz 域（用 TD 的时钟域/路径报告）；确认违反即回退到"FFT 只在 video_clk"。
3. 幅度近似 `|re|+|im|` 与真幅值有 1~1.414 倍偏差，频谱柱**比例正确**即可，不必追求精确 sqrt；若要更准再加流水 sqrt，仍是离屏路径。
4. 若面板坐标与现有波形/字幕重叠，调 WIN_X/WIN_Y/WIN_H 参数即可，零逻辑改动。
