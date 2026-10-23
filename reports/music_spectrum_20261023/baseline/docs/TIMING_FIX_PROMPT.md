# FAT32 关键路径 + 剩余问题 · 可落地提示词（2026-10-18 真实现状版）

> 用途：把本文件整段交给 GPT/协作者执行。目标：把当前**布线后内部 STA 仍失败**的状态
> （SWNS **−0.592ns**、STNS **−1.362ns**），继续修到 **Setup WNS ≥ 0、Hold ≥ 0、出 .bit**，
> 且**功能/画质/音频/双分辨率/EDID 零下降**。
> **铁律**：零损害——只做纯组合表达式等价改写（位级相同）、加寄存器（画面整体晚 N 拍）、
> 拆进位链（位级相同）、删死代码。任何功能取舍必须用户显式点头，绝不默认做。

---

## 0. 真实现状（已从 reports/build_repair_20261018/RESULT.md + 当前源码核对，勿重复排查）

| 项 | 值 |
|---|---|
| 源码状态 | 改动0（声明前移）、改动2（行地址进位拆拍）**已完成并提交**（HEAD `a5d76ca`），`HDL-7225/5373` 已消失 |
| 综合资源 | 16,585 LUT / 11,564 REG / 58 BRAM / 23 DSP |
| 物理资源 | 17,357 LUT / 11,668 REG / 58 BRAM / 23 DSP（**LUT 88.56%**、BRAM 90.625%） |
| 最终 SWNS / STNS | **−0.592ns / −1.362ns（仍失败）** |
| 最终 HWNS / HTNS | +0.024ns / +0.000ns（保持通过） |
| 最差普通 setup | −0.592ns |
| 最差路径 | `sd_card_bmp_m0/filesystem$fat/request_rel_reg[22]` → `stream_bad_reg`（33 位比较器） |
| PHY-7002 ×2 / PHY-5079 ×1 | ❌ 仍在，仍为 CRITICAL-WARNING |
| coredump | ✅ 已消失（本轮沿用避崩实现流程，没跑已知会崩的 post-route phys_opt） |
| 出 bit / 上板 | ❌ 均未执行 |

**关键定位**：最差路径在 [src/modules/sd/sd_fat32.v:477](src/modules/sd/sd_fat32.v#L477) 的
`{1'b0,request_rel}>=request_sectors` —— 一个 **33 位比较器**，其结果 OR 进 `stream_bad`。

---

## 1. 铁律

- **两个 HDMI 加密核 `u_hdmi_1_4b_transmitter_core_wrapper` + `u_hdmi_svga` 不碰**（音频只在里面，
  加密 IP 裁不掉也动不得，合计 2332 LUT + 31 BRAM 是固定成本）。
- 复位高有效；`vs/de` 与像素同拍。
- 只做零损害改动：纯组合等价改写 / 加寄存器（整体晚 N 拍）/ 拆进位链（位级相同）/ 删死代码。
- 每个改动**单独跑仿真 + 单独综合**，别批量改。
- **任何画质/功能/音频/双分辨率/EDID 取舍必须用户显式点头**，绝不在本文件默认路径里带上。

---

## 2. 主修复：33 位比较器窄化成「8 位或归约 + 24 位比较器」（零损害、纯组合、不加寄存器）

### 2.1 为什么能窄化（数学证明，不依赖 request_rel 的范围）

`request_sectors` 声明为 `reg [32:0]`（[sd_fat32.v:50](src/modules/sd/sd_fat32.v#L50)），
由 [sd_fat32.v:464](src/modules/sd/sd_fat32.v#L464) 计算：

```verilog
request_sectors <= {10'd0,request_size[31:9]} + (|request_size[8:0]);
```

- `request_size` 是 32 位（文件字节数 ≤ 4 GiB），所以 `request_size[31:9]` 是 23 位。
- `{10'd0, request_size[31:9]}` 的位 `[32:23]` 恒为 0，位 `[22:0]` 等于 `request_size[31:9]`。
- 加上 `(|request_size[8:0])`（0 或 1），最大 = `0x7FFFFF + 1 = 0x800000 = 2^23`。
- **结论：`request_sectors ≤ 2^23`，其位 `[32:24]` 恒为 0，只有 `[23:0]` 有意义。**

因此 33 位比较 `{1'b0,request_rel}>=request_sectors` 与下式**逐位等价**：

```verilog
(|request_rel[31:24]) || (request_rel[23:0] >= request_sectors[23:0])
```

- 若 `request_rel[31:24]` 任一位为 1 → `request_rel ≥ 2^24 > 2^23 ≥ request_sectors` → 比较必真。
- 若 `request_rel[31:24]` 全 0 → 两操作数高位相等 → 只需比低 24 位。

> 注意：这一步**不假设 request_rel 一定 ≤ 24 位**。`(|request_rel[31:24])` 显式兜住了
> request_rel 高位非 0 的情况，所以是**纯位级代数等价**，不是"缩小范围赌它不会越界"。

### 2.2 改法（只改 [sd_fat32.v:477](src/modules/sd/sd_fat32.v#L477) 一处）

```verilog
// 改前
       {1'b0,request_rel}>=request_sectors || target_index>=data_clusters ||

// 改后
       (|request_rel[31:24]) || (request_rel[23:0]>=request_sectors[23:0]) || target_index>=data_clusters ||
```

`request_sectors` 声明（L50 `[32:0]`）和赋值（L464）**先不动**——`request_sectors[23:0]`
取值正确（`{10'd0,request_size[31:9]}` 的低 24 位 + 进位正好落在 bit23），改声明反而可能
引入位宽/进位坑，没必要。

### 2.3 为什么这比上次的 FAT 候选更可能过布线

上次 `fat_compare_candidate.patch` 是「17/16 位拆两拍、加 5 个寄存器」的流水线方案，
93 项仿真通过，但**新增寄存器**在 FAT mux 区域 `x11y55_w2beg4` 触发 **PHY-8023** 冲突，已撤回。

本方案是**纯组合表达式等价改写**：不加寄存器、不加状态、不改流水，只把 33 位比较器换成
「8 位或归约 + 24 位比较器」。不新增触发器，规避上次那种物理冲突类型。**但不能保证一定过布线**，
只有重跑 build 能证明。

---

## 3. 次要路径：先跑 report_timing，找全所有失败路径

STNS −1.362ns（多路径之和）说明**不止最差一条**。做完 2.2 后：

1. 跑 `report_timing -n 20`，列出全部负 slack 路径的 start/end/cell/slack。
2. 若仍有 `sd_fat32` 的 `stream_bad` 相关路径，按「操作数语义位宽」同样窄化，候选：
   - `target_index>=data_clusters`：`target_index` 是 24 位、`data_clusters` 声明 32 位但实际 ≤ 2^24
     （[sd_fat32.v:88](src/modules/sd/sd_fat32.v#L88) 注释「文件内扇区/簇序号最多24位」）。
   - `working_cluster>max_cluster`：FAT32 簇号上限 28 位（`0x0FFFFFFF`），`max_cluster≤2^24`。
   - `working_cluster<2`：本质是「是否等于 0 或 1」，可等价改写成 2 位判定。
   > 这些窄化**依赖文档位宽上限，改前必须逐条用 ModelSim 断言与改前逐位等价**，不能凭感觉窄。
3. 若非 `sd_fat32` 路径，如实记录，不要为凑数乱改。

---

## 4. PHY-7002 / PHY-5079（代码修不了，走安路确认）

- 工程**没有**可删除的非法用户位置约束；SDRAM 是官方硬宏，不能删；PLL 到 SDRAM 无用户门控。
- EG4S20 不支持 `report_clock_utilization -dramhardcon`。
- 这三条警告未被证明无害，需要**安路官方确认合封 SDRAM 模型、位置与时钟资源支持**。
- 把这些写进 [docs/BOARD_PENDING.md](docs/BOARD_PENDING.md)（若无则新建）的上板待办清单，不在此处改代码。

---

## 5. 验证（全绿才算过，缺一不可）

1. `python scripts/static_check.py` → **ALL PASS**（只改表达式，未增删端口/源文件，应无变化）。
2. ModelSim **全 93 项回归 PASS**（重点 sd 相关 tb）。
3. 给 `sd_fat32` 单测喂边界 case，断言 `stream_bad` 与改前**逐位一致**：
   `request_rel` = 0 / 2^23−1 / 2^23 / 2^24 / 2^31−1 / 全 1（32'hFFFF_FFFF）。
4. TD 完整 build（`python scripts/run_build.py`）：
   - **Setup WNS ≥ 0、Hold WNS ≥ 0**；
   - **无 coredump**，成功出 `.bit`；
   - PHY-7002/5079 若仍为 CRITICAL-WARNING，按第 4 节记录，不算代码侧失败。
5. 上板点测（若出 bit）：两种分辨率、**第三档分辨率切换**、图片切换、特效、玻璃、OSD、**音频**
   均与改前逐项一致，无花屏、无声断。

---

## 6. 验收硬线

**出 `.bit` + Setup WNS ≥ 0 + Hold ≥ 0 + 无 coredump + 无新增 CRITICAL + 全 tb PASS +
功能/画质/帧率/音频/双分辨率/EDID 零下降。**

---

## 7. 若 2.2 仍不过（诚实兜底）

零损害的代码手段已接近上限：进位拆拍已做（实测仅 +0.294ns，未达「约3ns」预期），
FAT 流水线候选已撞物理墙（PHY-8023）。剩下的要么：

- 等安路确认 PHY-7002/5079（第 4 节）；
- 走**用户显式勾选**的资源取舍（最近邻缩放、行缓存收缩、删 MBR 分区表等），
  代价分别见 [ALGO_OPT_PROMPT.md](ALGO_OPT_PROMPT.md) / [ALGO_LEVEL_OPT_PROMPT.md](ALGO_LEVEL_OPT_PROMPT.md)。

**这些取舍每一项都要用户明确点头才做，绝不在本文件的零损害路径里默认带上。**
