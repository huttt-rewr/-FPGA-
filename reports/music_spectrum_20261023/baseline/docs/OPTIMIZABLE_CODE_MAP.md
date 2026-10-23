# 可优化代码清单 · 提示词（逐点审计 + 逐点优化）

> 用途：把本文件整段交给 GPT/协作者执行。目标：**系统性地把所有可优化代码点列成清单**，
> 每点给出"当前位置 / 当前成本 / 怎么改 / 预期省多少 / 风险"，然后按优先级逐点落地。
> **铁律与 [docs/ALGO_OPT_PROMPT.md](docs/ALGO_OPT_PROMPT.md) 一致**：不碰两个 HDMI 加密核、
> 复位高有效、vs/de 同拍、只优化不改功能。

---

## 0. 现状基线（勿重复排查）

- LUT **18048/19600 (92.08%)**、BRAM **61/64 (95.31%)**、DSP 17/29。
- 目标：LUT ≤16660（省 1388）、BRAM ≤58（省 3）、WNS ≥0。
- 固定成本：两个 HDMI 核 2332 LUT + 31 BRAM（**不可动**，音频在里面）。

---

## 1. 优化点总表（按「省得多/风险低」排序）

| # | 模块 · 位置 | 当前成本 | 改法 | 预期省 | 风险/取舍 |
|---|---|---|---|---|---|
| 1 | `bmp_scale_loader.v` L39 `row0/row1[0:2047]` | 12 BRAM | 深度 2048→1024 | **6 BRAM** + ~30 LUT | 不能加载 >1024 宽图（轻） |
| 2 | `sd_fat32.v` MBR 分区表（L42-45/177-178/255-266/301/307-309/325/330/350） | ~200 LUT | 删分区表支持，`partition_lba`→0 | ~200 LUT | 卡必须无分区表（中） |
| 3 | `status_osd.v` L2 参数 `BOARD_UI/AUDIO_DIAGNOSTICS/FILE_UI/RATE_UI` | ~250 LUT | 顶层实例化把未用 UI 参数置 0 | ~200 LUT | 少几列调试字符（轻） |
| 4 | `bmp_scale_loader.v` L29/35/118 地址位宽 [10:0] | ~30 LUT | 收成 [9:0] | ~30 LUT | 无（配合 #1） |
| 5 | `sd_fat32.v` L53/243-244/314 FAT16 字段 | ~50 LUT | 删 `root_entries/fat16_size` | ~50 LUT | 失去 FAT16 卡误判保护（轻） |
| 6 | `bmp_scale_loader.v` L61-63+L275 双线性 `rgb_lerp_pipeline` | ~500-800 LUT + 3 BRAM | 换最近邻插值 | **500-800 LUT + 3 BRAM** | 画质变颗粒（重，取舍） |
| 7 | `glass_osd.v` 毛玻璃整套（blend/darken/窗口） | ~895 LUT | 换纯色半透明框 | ~500 LUT | 失去磨砂质感（重） |
| 8 | `transition_pixels.v` 转场行缓存 | ~300 LUT | 关转场 | ~300 LUT | 失去换图淡入淡出（中） |
| 9 | `audio_visualizer` 波形叠加 | ~200-400 LUT | 关波形绘制 | ~300 LUT | 音频还在，只是不画波形（中） |
| 10 | 各特效模式（浮雕/马赛克等） | ~100 LUT/个 | 关单模式 | ~100 LUT/个 | 少一种特效（轻） |

---

## 2. 逐点详细（供执行时对照）

### 点 1 — 缩放器行缓存（**最优先，必做**）

- 文件 [src/modules/video/bmp_scale_loader.v](src/modules/video/bmp_scale_loader.v)。
- L38 `sector_mem[0:511]`（1 BRAM 扇区缓存）**保留**；L39 `row0[0:2047],row1[0:2047]` 改 `[0:1023]`。
- L126 `w>1920` 改 `w>1024`。
- 详见 `ALGO_OPT_PROMPT.md` 改动 1。

### 点 2 — sd_fat32 删 MBR 分区表

- 文件 [src/modules/sd/sd_fat32.v](src/modules/sd/sd_fat32.v)。
- 删寄存器 `partition_lba/partition_size/selected_lba/partition_found/partition_type/partition_candidate/partition_length`
  （L42-45）；删 `meta_partition/meta_partition_offset`（L140、L177-178）；删 `if(meta_partition)` 块
  （L255-266）；删 `boot_partition_ok`（L301）与 `else if(boot_partition_ok)` 分支（L307-309）；
  `partition_lba` 用 `0` 替（L325/330）；删 `bpb_at_partition` 项（L350）。
- 详见 `ALGO_OPT_PROMPT.md` 改动 3.2。**每步跑 `tb_sd_address`/`tb_fat32`。**

### 点 3 — 关 OSD 未用 UI

- 文件 [src/modules/osd/status_osd.v](src/modules/osd/status_osd.v) L2 已有 8 个参数。
- 改 [src/top.v](src/top.v) 里 `status_osd` 实例：把不用的 `BOARD_UI/AUDIO_DIAGNOSTICS/FILE_UI/RATE_UI` 置 0。
- 保留 `ENHANCED_UI` 和 `AUDIO_UI`（分辨率信息 + 音频状态是演示亮点）。
- 影响：面板少显示调试列，核心功能不变。

### 点 4 — 缩放器地址位宽 11→10

- 文件 [src/modules/video/bmp_scale_loader.v](src/modules/video/bmp_scale_loader.v) L29 `last_source_x[10:0]`、
  L35 `load_x,read_x[10:0]`、L118 `source_width[10:0]-1'b1` → 全部 `[9:0]`。
- 配合点 1 做（因为源宽已 ≤1024）。

### 点 5 — sd_fat32 删 FAT16 字段

- 文件 [src/modules/sd/sd_fat32.v](src/modules/sd/sd_fat32.v) L53 删 `root_entries,fat16_size`；
  L243-244 删对应 BPB 解析；L206 复位删两行；L314 删 `root_entries!=0 || fat16_size!=0`。
- **收益小、丢安全网**，可选。

### 点 6 — 双线性 → 最近邻（**最省但最伤画质，最后才用**）

- 文件 [src/modules/video/bmp_scale_loader.v](src/modules/video/bmp_scale_loader.v)。
- 删 `rgb_lerp_pipeline` 三实例（L61-63）与子模块（L275-294）；`pixel` 直接取最近行最近列；
  行缓存可退化为单行。
- 详见 `ALGO_OPT_PROMPT.md` 改动 3。

### 点 7-10 — 功能砍（见 `ALGO_OPT_PROMPT.md` 第 7 节）

- 按"损失最小"排序：`audio_visualizer` 波形 → `transition_pixels` 转场 → `glass_osd` 磨砂 → 单特效模式。

---

## 3. 已确认"没油水"的点（别浪费时间重查）

- `glass_osd` 除 9：**已经是移位加法**（[glass_osd.v:55](src/modules/video/glass_osd.v#L55)
  `(s<<13)-(s<<10)+(s<<7)-(s<<4)+(s<<1)`，注释 "exact for 0..2295"）。
- `video_luma_window` 行缓存：**已是 dram + 4×256 bank**（[pixel_effects.v:74-89](src/modules/video/pixel_effects.v#L74-L89)），
  且显式 split 防 TD 把 800 凑 1024。
- `sd_fat32` 状态机：**已是 49 态独热**，`spc` 除法已是 `>>spc_shift`，`fat_cache/entries` 已是最小（双流各一扇区）。
- `rgb_lerp_pipeline`：已是 3 级流水（差/乘/舍入分开）。
- 这些是上一轮优化过的产物，**除非换算法，否则无进一步空间**。

---

## 4. 执行纪律

1. 按总表顺序做：**点 1 → 点 3 → 点 4 → 点 2/5 →（不够）点 6/7-10**。
2. 每做一点：`git diff` 核对 → 跑对应 tb → 记录综合面积变化，再下一点。
3. 每点改完更新本清单的"当前成本"栏，保持清单是活的。
4. 任何时候发现 LUT 已 ≤85% 且 BRAM ≤90%，**停止砍功能**，进入 `ALGO_OPT_PROMPT.md` 改动 5 修时序。

---

## 5. 验证（必须全绿）

1. `python scripts/static_check.py` ALL PASS。
2. ModelSim 17+ tb 全 PASS（重点 `tb_bmp_scale`/`tb_scaled_bmp`/`tb_sd_address`/`tb_fat32`/`tb_effects_pipeline`/`tb_glass_osd`）。
3. TD `run_build.py`：LUT ≤85%、BRAM ≤90%、WNS≥0、无 PHY-9xxx/8xxx、出 `.bit`。
4. 上板点测：双分辨率、图片、特效、玻璃、OSD、**音频**全正常。
