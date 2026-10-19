# 算法级优化 · 落地执行提示词（算法替换，带 before→after）

> 用途：把本文件整段交给 GPT/协作者执行。目标：**把可读代码里的"重算法"换成等价的"轻算法"**，
> 省 LUT/BRAM/时序，同时**保留音频、双分辨率、EDID、功能**（画质允许在明确标注的取舍点下降）。
> 与结构级提示词的区别：这里只动"算法本身"，不改缓冲区大小、不删未用分支。
> **必须适配本工程**：安路 EG4S20、TD 6.2.1、复位高有效、纯整数运算、`vs/de` 同拍。

---

## 0. 铁律

- **两个 HDMI 加密核不碰**（音频只在里面，替换 = 失去全部声音）。
- 复位高有效；`vs/de` 与像素同拍。
- 纯整数；除号只允许 2 的幂 `>>`；乘系数用移位加法。
- 每个算法替换完**单独跑对应 tb**，不批量改。

---

## 1. 算法清单总览（按"省得多/风险低"排序）

| # | 算法 · 位置 | 当前实现 | 替换算法 | 预期省 | 画质/功能影响 |
|---|---|---|---|---|---|
| 1 | 缩放插值 [bmp_scale_loader.v](src/modules/video/bmp_scale_loader.v) L61-63/275 | 双线性（2×2 tap + 3 级 lerp） | **最近邻** | **500-800 LUT + 3 BRAM** | 放大颗粒/锯齿（重） |
| 2 | 缩放插值 同上 | 双线性（全 2D） | **1D 横向双线性 + 纵向最近邻** | ~300 LUT + 3 BRAM | 只纵向略糙（中） |
| 3 | Gamma 曲线（`picture_gamma` 模块，3 BRAM 查表） | 3 张 256×8 查表 | **1 张共享表** 或 **分段线性** | 2~3 BRAM | 无（同一曲线） |
| 4 | FAT32 解析 [sd_fat32.v](src/modules/sd/sd_fat32.v) | 完整解析（MBR+分区表+FAT16） | **最小 superfloppy 解析** | ~250 LUT | 卡必须无分区表 FAT32（中） |
| 5 | 簇链遍历 同上 | 每扇区重走 FAT | **连续簇顺序读**（视频用） | 省 SD 读（非 LUT） | 无 |

---

## 2. 算法 1（旗舰）：双线性缩放 → 最近邻

**文件** [src/modules/video/bmp_scale_loader.v](src/modules/video/bmp_scale_loader.v)。

### 现状（2×2 双线性 = 读 2 行 × 2 列 + 3 次线性插值）

- L61-63：三个 `rgb_lerp_pipeline` 实例（`hmix0/hmix1/vmix`，每个是 3 级流水乘法器）。
- L275-294：`rgb_lerp_pipeline` 子模块（`delta` 相减 → `product` 8×18 乘法 → 舍入）。
- L113：`fx=x_acc[15:8]`、`fy=y_acc[15:8]`（Q8 小数权重）。
- L227-244：12 个状态的 2×2 取数流水（`LEFT_WAIT/LEFT_GET/RIGHT_WAIT/RIGHT_GET/HWAIT1/2/HCAPTURE/VWAIT1/2/3/VERTICAL`）。

### 替换（最近邻 = 读 1 个源像素直接输出）

1. **删** L61-63 三个 lerp 实例，**删** L275-294 整个 `rgb_lerp_pipeline` 子模块。
2. **删** `fx/fy`（L56、L113）及 `left0/left1/horizontal0/horizontal1`（L41、L60、L229、L236）相关寄存器。
3. **输出改为直接取最近像素**。L89 已有 `q0<=row0[read_x];q1<=row1[read_x];`，最近邻取 `read_x=x0`、
   行取 `y0[0]` 选 row0/row1，于是 L241-244 的 `VERTICAL` 状态改成：

```verilog
// 改后（替代原 L241-244 的 state[15] VERTICAL）
state[15]:begin
 pixel<=y0[0]?q1:q0;      // q0/q1 已是 row0/row1 在 read_x 处的像素
 pixel_valid<=1;state<=SEND;
end
```

4. **FSM 状态折叠**：L227-240 里 `state[11]..state[14]`（LEFT/RIGHT 两列取数）、`state[17]..state[22]`
   （HWAIT/VWAIT 共 6 拍流水）整段删除，只保留"设 read_x → 等 1 拍 RAM 读 → 输出"最短路径：
   - `PIXEL`（L222-226）里 `read_x<=x0; state<=LEFT_WAIT;` 改成 `state<=VERTICAL;`（复用 `state[15]` 那格，
     保留一拍的 RAM 读延迟，把 `q0/q1` 采样挪进 `state[15]` 里）。

> 注意：RAM 是同步读（L89），`read_x` 在 PIXEL 拍更新后，`q0/q1` 要到下一拍才反映新地址，
> 所以"设 read_x → 下一拍在 VERTICAL 采样 q0/q1"正好对齐，无需额外气泡。
> **改完必须跑 `tb_bmp_scale` + `tb_scaled_bmp`**（逐像素比对，看边缘是否还对齐）。

### 行缓存可随之降为单行（省 3 BRAM）

- 最近邻每输出行只依赖一个源行，`row0/row1` 双行 ping-pong 可退化成一个 `row[0:1023]`。
- 省：在 [改动 1 的行缓存 1024](docs/ALGO_OPT_PROMPT.md) 基础上再省 3 BRAM（缩放器 BRAM 13→4）。

### 效果与代价

- **省 500-800 LUT + 6 BRAM**（含行缓存单行化）。**代价：放大时明显颗粒/锯齿**，缩小影响较小。
- 这是"深度优化算法"最大的一刀，也是最伤画质的一刀。

---

## 3. 算法 2（折中）：1D 横向双线性 + 纵向最近邻

> 想要"省一部分、又别太颗粒"时选这个。

- **保留** `hmix0/hmix1` 里的一组横向 lerp（每行内两个相邻像素做水平插值），**删**纵向 `vmix`。
- `vertical_result`（L60、L63）删掉，`VERTICAL` 状态输出直接取
  `y0[0]?horizontal1:horizontal0`（横向已插值，纵向取最近行）。
- 行缓存仍需双行（横向插值要读同行相邻两列），**不省 BRAM**，只省 1 个 lerp ≈ **~300 LUT**。
- **画质**：纵向最近邻会有一点点横向拉丝，比全最近邻好很多。

---

## 4. 算法 3：Gamma 查表 → 共享表 / 分段线性（省 BRAM，画质不变）

**文件** 找 `picture_gamma` 模块（视频链里 `picture_adjust → picture_gamma`，top.v 约 L730 附近实例化）。

1. **先读**该模块，确认它是 3 张独立 `256×8` 查表（R/G/B 各一张，占 3 BRAM）。
2. **替换 A（共享表，省 2 BRAM）**：R/G/B 用同一张 gamma 表，因为曲线对三通道相同。
   三个通道分时读同一张表（`ram_style="bram"`，`1 read port` 分 3 拍读三通道），
   或直接组合读同一地址（同一 `index` 下 R/G/B 都用 `table[gray]`）。
3. **替换 B（分段线性，省 3 BRAM）**：gamma 曲线用 8~16 段折线逼近，
   `y = lut[k] + (x - x_k)*(lut[k+1]-lut[k])/(x_{k+1}-x_k)`，全部整数，落 LUT，0 BRAM。
   （若 `picture_gamma` 只做暗部提升，折线 8 段即可，误差目测不可见。）
4. **验证**：跑 `tb_visual_pipeline` / 该模块的 tb，喂灰度渐变，断言与查表版误差 ≤2。

> 这是最"干净"的 BRAM 省法之一：**画质几乎无损**，且不动缩放/音频。

---

## 5. 算法 4：FAT32 完整解析 → 最小 superfloppy 解析

**文件** [src/modules/sd/sd_fat32.v](src/modules/sd/sd_fat32.v)。

> 完整算法：读 LBA0 判断"有没有 MBR 分区表"→ 有则跳 `partition_lba` 再读 BPB → 解析 BPB
> （含 FAT16/FAT12 字段）→ 拒绝 FAT16。**最小算法**：LBA0 直接就是 BPB（superfloppy），
> 跳过分区表解析，去掉 FAT16 字段。

精确改法（与 [ALGO_OPT_PROMPT.md 改动 3.1/3.2](docs/ALGO_OPT_PROMPT.md) 相同，这里按"算法"重述）：

1. 删分区表状态机分支：寄存器 `partition_lba/partition_size/selected_lba/partition_found/partition_type/partition_candidate/partition_length`（L42-45）、`meta_partition/meta_partition_offset`（L140、L177-178）、`if(meta_partition)` 块（L255-266）、`boot_partition_ok`（L301）及 `else if(boot_partition_ok)` 分支（L307-309）。
2. `partition_lba` 全部以 `0` 代入：L325 `first_fat<=reserved_count;`、L330 `volume_last<=total_minus_one;`；L350 删 `bpb_at_partition` 项。
3. 删 FAT16 字段：L53 删 `root_entries,fat16_size`；L243-244、L206、L314 对应删。

**省 ~250 LUT**；`fat_cache/entries` 两个 BRAM 与音频双流**不动**。
**代价**：TF 卡必须"无分区表、直接 FAT32"格式化。

---

## 6. 已是最优、别浪费时间重查的算法

- **恢复余数除法器**（[bmp_scale_loader.v:67-73](src/modules/video/bmp_scale_loader.v#L67-L73)）：
  32 拍串行、每张图只跑一次，已是资源最小的除法方案；换成倒数乘法反而更大，**不要动**。
- **除 9**（[glass_osd.v:55](src/modules/video/glass_osd.v#L55)）：已是移位加法近似
  `(s<<13)-(s<<10)+(s<<7)-(s<<4)+(s<<1)`，精确到 0..2295，**不要动**。
- **灰度加权**（[pixel_effects.v:72](src/modules/video/pixel_effects.v#L72)）：已是移位加法的
  77R+150G+29B，**不要动**。
- **3 级 lerp 流水**（`rgb_lerp_pipeline`）：差/乘/舍入已分拍，除非换最近邻整个删，否则无优化空间。

---

## 7. 验证（必须全绿）

1. `python scripts/static_check.py` ALL PASS（删了 `rgb_lerp_pipeline` 等子模块就同步改
   `video_improve.al` 两份 + `scripts/design_files.txt`）。
2. ModelSim 全 PASS，重点：`tb_bmp_scale`、`tb_scaled_bmp`（缩放）、`tb_sd_address`、`tb_fat32`
   （FAT）、`tb_visual_pipeline`、`tb_glass_osd`（gamma/玻璃）。
3. TD `run_build.py`：LUT ≤85%、BRAM ≤90%、WNS≥0、无 PHY-9xxx/8xxx、出 `.bit`。
4. 上板点测：双分辨率、图片、特效、玻璃、OSD、**音频**全正常。

---

## 8. 执行顺序与验收线

1. **先做算法 3（Gamma 共享表）**：省 2 BRAM、画质无损、风险最低。
2. **再做算法 4（FAT32 最小化）**：省 ~250 LUT，每步跑 tb。
3. 综合看 LUT：**仍不够**再在算法 1（最近邻）和算法 2（1D 折中）里二选一。
4. 验收硬线：**LUT ≤85%、BRAM ≤90%、WNS ≥0、无 PHY-9xxx/8xxx、出 .bit、音频+双分辨率不回归**。
