# 可读代码深度优化 · 可落地提示词（带行号 + before→after）

> 用途：把本文件整段交给 GPT/协作者执行。目标：**保留全部功能**（音频、双分辨率、EDID、
> 图片/特效/OSD）的前提下，把构建失败状态（LUT 92.08%、BRAM 95.31%、WNS −16ns、
> MSLICE legalize 报错）修到**能出比特流 + 时序收敛 + 资源安全区**。
> **必须适配本工程**：安路 EG4S20、TD 6.2.1、复位高有效；只优化，**不得改变功能**。

---

## 0. 铁律（违反即作废）

- **两个 HDMI 加密核 `u_hdmi_1_4b_transmitter_core_wrapper`（1316 LUT + 17 BRAM）与
  `u_hdmi_svga`（1016 LUT + 14 BRAM）一个字都不碰**：它们是加密 IP，参数只编译期生效，
  且**音频只由这两个核输出**，替换成无音频的 DVI 核 = 失去全部声音。这是本任务的第一约束。
- 复位 `rst` **高有效**；`vs/de` 与像素同拍。
- 省 BRAM 优先**改小缓冲区**，**不得** BRAM→LUT（LUT 也 92%）。
- 每改一处，跑一次对应 ModelSim tb，**不要批量改完再跑**。

## 0.5 现实账（重要，先看清再动手）

- 安全线：LUT ≤85%（16660）、BRAM ≤90%（58）。缺口 = **−1388 LUT、−3 BRAM**。
- **BRAM 一刀就够**（改动 1 直接省 6 块）。
- **LUT −1388 无法靠"零影响"凑够**。诚实预算：
  - 删 FAT16 字段 ≈ 50、删 MBR 分区表 ≈ 200、关 OSD 未用 UI ≈ 200、地址位宽 11→10 ≈ 30。
  - 合计"安全/轻取舍"约 **500~700 LUT**，仍差约 700。
  - 剩下的 700 必须二选一：**最近邻缩放**（改 3，省 ~500-800 LUT + 全部 13 BRAM，画质变颗粒）
    或**砍一个功能模块**（见第 7 节菜单）。
- 所以本文件按**「改动 1+2 先做（稳过 BRAM、修 LUT/时序）→ 改动 3 或砍功能二选一补足」**排序。

---

## 1. 先读这些文件（精确位置已给）

1. [src/modules/video/bmp_scale_loader.v](src/modules/video/bmp_scale_loader.v)：L38-39 数组是 13 BRAM 全部来源；L126 是源宽校验。
2. [src/modules/sd/sd_fat32.v](src/modules/sd/sd_fat32.v)：L53/243-244/314 是 FAT16；L42-45/177-178/255-266/301/307-309/325/330/350 是 MBR 分区表。
3. [src/modules/osd/status_osd.v](src/modules/osd/status_osd.v)：L2 已有一排 UI 开关参数。
4. [src/modules/video/glass_osd.v](src/modules/video/glass_osd.v)：L55 除 9 已是移位加法，勿再动。
5. [src/modules/video/pixel_effects.v](src/modules/video/pixel_effects.v) L68-103：窗口已 dram + 4 bank，勿重写。

---

## 2. 改动 1：缩放器行缓存 2048→1024（省 6 BRAM，最优先、可一键回退）

**文件** [src/modules/video/bmp_scale_loader.v](src/modules/video/bmp_scale_loader.v)。

**改动 1a — 行缓存深度（L39）**：

```verilog
// 改前
reg [23:0] row0[0:2047],row1[0:2047];
// 改后
reg [23:0] row0[0:1023],row1[0:1023];
```

**改动 1b — 源宽校验（L126）**：

```verilog
// 改前
if(w==0 || w>1920 || h==0 || h>1080)begin error<=1;busy<=0;state<=IDLE;end
// 改后
if(w==0 || w>1024 || h==0 || h>1080)begin error<=1;busy<=0;state<=IDLE;end
```

**就这两行。** `load_x/read_x/last_source_x` 是 [10:0]（11 位），不用改——它们索引时只用到低 10 位，
`source_width≤1024` 保证高一位恒为 0。

**可选微优化（1c）**：把 L29 `last_source_x`、L35 `load_x,read_x`、L118 里的位宽从 `[10:0]` 收成
`[9:0]`（三处），再省 ~30 LUT。**建议第一版先跳过，跑通 1a+1b 再说。**

**效果**：BRAM 13→7（**61→55，越过 90% 线**）；LUT 略降。
**取舍**：不能加载 >1024 宽的 BMP。640/800 显示下画质零影响。

---

## 3. 改动 2：sd_fat32 减 LUT（删 FAT16 + 删 MBR 分区表）

**文件** [src/modules/sd/sd_fat32.v](src/modules/sd/sd_fat32.v)。**每小步单独跑 `tb_sd_address` + `tb_fat32`。**

### 3.1 删 FAT16 字段（≈50 LUT，失去 FAT16 卡误判保护）

- **L53** 从寄存器表删 `root_entries,fat16_size`：

```verilog
// 改前
reg [15:0] bytes_per_sector,reserved_count,root_entries,fat16_size,ext_flags,fs_version,signature;
// 改后
reg [15:0] bytes_per_sector,reserved_count,ext_flags,fs_version,signature;
```

- **L243-244** 删两行 BPB 解析（`17:root_entries...` `18:root_entries...` `22:fat16_size...` `23:fat16_size...`）。
- **L206** 复位块里删 `root_entries<=0;fat16_size<=0;`。
- **L314** 删 `root_entries!=0 || fat16_size!=0 ||` 两个判断项：

```verilog
// 改后
geom_fields_bad<=!spc_ok || reserved_count==0 || (num_fats!=1 && num_fats!=2) || fat_sectors==0 || fat_sectors[31:24]!=0 ||
   fs_version!=0 ||
   (ext_flags[7] && ext_flags[3:0]>=num_fats);
```

> 影响：FAT16/FAT12 卡不再被干净拒绝（会被当 FAT32 误解析）。比赛卡是 FAT32，可接受；
> 但这条**收益小、丢的是安全网**，如果后面不差这 50 LUT，可以不做。

### 3.2 删 MBR 分区表，只留 superfloppy（≈200 LUT，强制卡无分区表）

> 影响面较大，务必**逐条 `git diff` 核对**。改完的卡必须是"整个卡直接格成 FAT32、无分区表"。
> 若担心卡的格式化方式不受控，**跳过本小步**，用第 7 节的功能砍代替。

删/改这几处（`partition_lba` 直接用 `0` 替代，`bpb_at_partition` 恒 `0`）：

1. **L42-45**：删 `partition_lba,partition_size,selected_lba,partition_found,partition_type,partition_candidate,partition_length` 这些寄存器；`bpb_at_partition` 也删（见下）。
2. **L140**：删 `meta_partition,meta_partition_offset` 寄存器声明。
3. **L177-178**：删这两行（`meta_partition<=...`、`meta_partition_offset<=...`）。
4. **L255-266**：删整个 `if(meta_partition)begin ... end` 块。
5. **L301**：`boot_partition_ok<=!bpb_at_partition && partition_found && selected_lba!=0;` → 整行删（或恒 0）。
6. **L307-309**：删 `else if(boot_partition_ok)begin ... end` 分支，L306 的 `else if(boot_super_ok)`
   后面直接接 L309 原本的 `else begin state<=FAULT;...`。
7. **L325**：`first_fat<=partition_lba+reserved_count;` → `first_fat<=reserved_count;`。
8. **L330**：`volume_last<=partition_lba+total_minus_one;` → `volume_last<=total_minus_one;`。
9. **L350**：`(bpb_at_partition && (partition_size<total_sectors || partition_size==0))` 这一项整删。

**效果**：≈200 LUT；`fat_cache`/`entries` 两个 BRAM 不动，音频双流不动。

---

## 4. 改动 3（二选一补足 LUT 缺口）：最近邻缩放（取舍型，省最多）

> 只有当你必须把 LUT 压到 85% 以下、又不愿砍功能时才做。**画质损失：放大时明显颗粒/锯齿**，
> 缩小影响小。这是"深度优化算法"里最大的一刀，也是最伤画质的一刀。

**文件** [src/modules/video/bmp_scale_loader.v](src/modules/video/bmp_scale_loader.v)。

- 把**双线性插值换成最近邻**：删 `rgb_lerp_pipeline` 三个实例（L61-63）及子模块（L275-294），
  输出 `pixel` 直接取 `q0`（或 `row0[read_x]` 取整坐标），`fx/fy/x_acc/y_acc` 的权重采样可以简化为
  只取 `x_acc[26:16]`/`y_acc[27:16]` 整数部分。
- 最近邻**不再需要两个行缓存**：只需一行 `row[0:1023]`（当前行的下一行预取可退化为单行）。
  → 行缓存 6→3 BRAM（改动 1 基础上再省 3），`rgb_lerp_pipeline` 的 3 组 8×18 乘法器全部消失。
- **预期**：再省 **500~800 LUT + 3 BRAM**（含改动 1 的 6 块，缩放器 BRAM 从 13 降到 4~5）。
- **保留**：contain fit、黑边、居中、错误校验、扇区缓存逻辑全部不动。

> 这是"深度优化算法"最彻底的走法，代价是画质。建议：**先做改动 1+2，综合看 LUT 还差多少，
> 再决定做不做最近邻**，不要一上来就牺牲画质。

---

## 5. 改动 4：关 OSD 未用 UI（≈200 LUT，轻取舍）

**文件** [src/modules/osd/status_osd.v](src/modules/osd/status_osd.v) L2 的参数已经在，
只是顶层实例化时可能全开了。改 [src/top.v](src/top.v) 里 `status_osd` 的实例参数：

- 演示不需要调试信息时：`BOARD_UI=0`、`AUDIO_DIAGNOSTICS=0`（关掉 L152-222 那一大块 case）。
- 不需要文件计数时：`FILE_UI=0`、`RATE_UI=0`。
- **保留**：`ENHANCED_UI`（分辨率/亮度信息是演示亮点）、`AUDIO_UI`（音频状态）。

> 影响：面板少显示几列调试字符，核心播放/特效/音频**功能不受影响**。这是最"干净"的 LUT 省法之一。

---

## 6. 改动 5：修 WNS + MSLICE（真正的构建失败点）

LUT 92% 是**警告**，真正的 ERROR 是 `PHY-9031/9042`（MSLICE legalize）+ `RUN-8101`（place 超资源）
+ WNS −16ns。这三者根因是**进位链（ripple）太深**，不是 LUT 总数：

1. 在 TD 里 `report_timing -n 20`，抄出最差 20 条路径的起止点（预期在 `sd_fat32` 或
   `bmp_scale_loader` 的 32 位几何/除法）。
2. 在路径中间插一级寄存器，把 21 级拆成 ≤12×2（FAT32/缩放的吞吐允许 +1 拍）。
3. 减少 carry 深度：`sd_fat32` 的 32 位加法（L325/329/330/336/343/364/454）已分拍，
   若 `report_timing` 仍指向它们，把 `first_data+map_shifted`、`physical_addr` 再拆成"高 16 + 低 16"
   两拍；`bmp_scale_loader` 的除法（L67-73）确认没被综合成并行大组合。
4. 检查 [src/constraints/pin.adc](src/constraints/pin.adc) 有没有把 `U3/sdram` 手动约束到非法
   location（`PHY-7002` 警告），有就删掉该条。

> 这一步和 [docs/TIMING_FIX_PROMPT.md](docs/TIMING_FIX_PROMPT.md) 的阶段 2/3 是同一件事，
> 那份文档有更细的诊断步骤，按它走。

---

## 7. 功能砍菜单（实在不够 LUT 时，按"损失最小"排序）

- 关 `audio_visualizer` 波形叠加：≈200-400 LUT（音频本身还在，只是不画波形）。
- 关 `transition_pixels` 转场：≈300 LUT（失去换图淡入淡出）。
- 关 `glass_osd` 毛玻璃：≈500 LUT（失去磨砂质感，可换成纯色半透明框）。
- 关一种特效模式：每个 ≈100 LUT。
- **最后手段**才动这些；先做 2~6，综合看缺口再选。

---

## 8. 验证（必须全绿）

1. `python scripts/static_check.py` **ALL PASS**（改了端口/参数就同步改 `video_improve.al` 两份 +
   `scripts/design_files.txt`）。
2. ModelSim `scripts/run_tests.ps1` **全 PASS**，重点：`tb_bmp_scale`、`tb_scaled_bmp`、
   `tb_sd_address`、`tb_fat32`、`tb_effects_pipeline`、`tb_glass_osd`、`tb_visual_pipeline`。
3. TD `scripts/run_build.py`：LUT ≤85%、BRAM ≤90%、WNS≥0、无 PHY-9xxx/8xxx、出 `.bit`。
4. 上板点测：双分辨率、图片（含 1024 内源图）、特效、玻璃、OSD、**音频**全正常。

---

## 9. 执行顺序与验收线

1. **改动 1（行缓存 2048→1024）**：2 行，稳过 BRAM，可一键回退。
2. **改动 5（打断关键路径 + 修 MSLICE）**：修掉真正的 ERROR 和 WNS。
3. **改动 4（关未用 UI）** + **改动 3.1（删 FAT16，可选）**：补 LUT。
4. 综合看 LUT：不够再 **3.2（删 MBR）** 或 **改动 3（最近邻）** 或 **第 7 节砍功能** 二选一。
5. 验收硬线：**LUT ≤85%、BRAM ≤90%、WNS ≥0、无 PHY-9xxx/8xxx、出 .bit、音频+双分辨率+画质不回归**。
