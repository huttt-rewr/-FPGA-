# 完整优化 + 修复 · 可落地总提示词（零性能下降）

> 用途：把本文件整段交给 GPT/协作者执行。目标：在**不改画质、不降帧率、不丢功能、不动音频/
> 双分辨率/EDID** 的前提下，把构建失败状态修到**能出比特流 + 时序收敛**，并顺手删掉 FAT32
> 之外不再需要的分支。
> **必须适配本工程**：安路 EG4S20、TD 6.2.1、复位高有效、`vs/de` 同拍。

---

## 0. 已确认的现状（2026-10-17，勿重复排查、勿回改）

- 构建失败点：Setup WNS **−16.115ns**、`PHY-9031/9042 ERROR: Legalize MSLICE failed`、
  `RUN-8101 ERROR: Eco place failed ... resources exceed`、关键路径 21 级 @40MHz。
- 资源：LUT 18048/19600 (92.08%)、BRAM 61/64 (95.31%)、DSP 17/29。**这两项是警告，不是失败主因**。
- **用户约束（本次已明确）**：
  1. 不要 1080p 以上的图 → 当前已是（[bmp_read.v:182](src/modules/bmp/bmp_read.v#L182)
     `width<=1920 && height<=1080`），**保持不变**，不缩行缓存。
  2. 资源只从 FAT32 读 → 可安全删 FAT16/FAT12 支持（见阶段 3）。
  3. 零性能下降 → 只做"位级相同 / 仅整体晚 N 拍"的改动。
- **已经修好、勿再动**（前一轮已完成）：
  - 溢出标志恢复（[video_rgb_to_axis_640x480.v:25](src/modules/video/video_rgb_to_axis_640x480.v#L25)）。
  - FIFO 满空保护 + 粘滞标志（[frame_read_write.v:75-77/263-270](src/modules/memory/frame_read_write.v#L263-L270)）。
  - SD 初始化看门狗（`sd_card_sec_read_write.v` 的 `init_error`/`S_ERR`）。
  - `display_valid` 已改名 `player_display_valid` 且仍在用（[top.v:112/118/357/699](src/top.v#L112)），**不是死代码**。

---

## 1. 铁律

- **两个 HDMI 加密核 `u_hdmi_1_4b_transmitter_core_wrapper` + `u_hdmi_svga` 不碰**（音频只在里面）。
- 复位高有效；`vs/de` 与像素同拍。
- 纯整数；除号只允许 2 的幂。
- 每个改动单独跑对应 tb，不批量改。

---

## 2. 阶段 0：精确定位（必做，别跳）

1. TD `report_timing -n 20`：抄最差 20 条路径起止点，确认 21 级路径在哪个模块
   （预期 `sd_fat32` 或 `bmp_scale_loader` 的 32 位几何/除法/大 MUX）。
2. `report_area`：定位 MSLICE/ripple 最集中区域。
3. 打开 [src/constraints/pin.adc](src/constraints/pin.adc)，核对 `PHY-7002 sdram location` 警告，
   看 `U3/sdram` 是否被约束到非法位置（log 说 `(164,288)` 不被接受），有就删该条 location 约束。

> 把三条结果记下来再往下做。

---

## 3. 阶段 1：修 WNS —— 打断 21 级关键路径（零性能下降）

**原理**：在组合路径中间插一级寄存器，21 级拆成 ≤12×2。视频链是 `vs/de/x/rgb` 同步流水，
**把 `vs/de/x` 与 `rgb` 一起延迟同样拍数，画面逐像素不变，只是整体晚 N 拍**（帧率不变）。

**做法**：

1. 用阶段 0 的结果找到路径中点。
2. 在路径中间加寄存器，**同时把同模块的 `vs/de/x` 也延迟同样拍数**保持同拍。
   - 参照 [picture_gamma.v:284-293](src/modules/video/picture_gamma.v#L284-L293)：`r/g/b/bypass/enabled/v/d/px`
     同拍寄存，`out_vs<=v; out_de<=d; out_x<=px;` 与 `out_rgb` 一起输出。
3. 跨模块路径优先在**模块边界**加寄存器。
4. 每加一级重跑 `report_timing`，一次只改一处。

> 只加寄存器，不改算术/状态机跳转。加完跑 `tb_bmp_scale`/`tb_sd_address`/`tb_visual_pipeline`，
> 断言输出与改前逐拍一致（仅整体移位）。

---

## 4. 阶段 2：修 MSLICE 溢出 —— 拆 32 位进位链（零性能下降）

**原理**：`RUN-8101 place 超资源` 常因同区域进位链（ripple）太密。把 32 位加法拆成
"低 16 + 进位" 与 "高 16 + 进位" **两拍**，结果位级相同，仅晚 1 拍。

**只拆 `report_area`/`legalize` 指向的那 1~2 个**，别全拆（状态翻倍更糟）。

**嫌疑点**（[src/modules/sd/sd_fat32.v](src/modules/sd/sd_fat32.v)）：
L364 `map_base<=first_data+map_shifted;`、L454 同、L325 `first_fat<=partition_lba+reserved_count;`、
L329-330 `overhead/first_data/volume_last`、L336 `data_sectors<=total_sectors-overhead;`。

**拆分模板**（以 L364 为例）：

```verilog
// 改前
state[32]:begin map_base<=first_data+map_shifted;state<=DIR_FINISH;end

// 改后：拆两拍，进位用 1 位寄存器穿过；需在 49 态独热里新增一个 state 位
reg [15:0] map_base_lo;reg [15:0] map_base_hi;reg map_base_c;
state[32]:begin {map_base_c,map_base_lo}<=first_data[15:0]+map_shifted[15:0];state<=DIR_BASE_HI;end
state[XX]:begin map_base_hi<=first_data[31:16]+map_shifted[31:16]+{15'd0,map_base_c};
              map_base<={map_base_hi,map_base_lo};state<=DIR_FINISH;end
```

> 注意同步改 `state` 位宽与 `localparam` 新增独热位。拆完跑 `tb_sd_address`/`tb_fat32` 断言地址逐位一致。

---

## 5. 阶段 3：删 FAT16/FAT12 支持（零影响，因为资源只在 FAT32 读）

**文件** [src/modules/sd/sd_fat32.v](src/modules/sd/sd_fat32.v)。**每步跑 `tb_sd_address`/`tb_fat32`。**

1. **L53** 寄存器表删 `root_entries,fat16_size`：

```verilog
// 改前
reg [15:0] bytes_per_sector,reserved_count,root_entries,fat16_size,ext_flags,fs_version,signature;
// 改后
reg [15:0] bytes_per_sector,reserved_count,ext_flags,fs_version,signature;
```

2. **L243-244** 删 4 行 BPB 解析（`17:root_entries...`、`18:root_entries...`、`22:fat16_size...`、`23:fat16_size...`）。
3. **L206** 复位块删 `root_entries<=0;fat16_size<=0;`。
4. **L314** 删 `root_entries!=0 || fat16_size!=0 ||` 两个判断项：

```verilog
// 改后
geom_fields_bad<=!spc_ok || reserved_count==0 || (num_fats!=1 && num_fats!=2) || fat_sectors==0 || fat_sectors[31:24]!=0 ||
   fs_version!=0 ||
   (ext_flags[7] && ext_flags[3:0]>=num_fats);
```

**效果**：≈50 LUT。**音频双流、`fat_cache/entries`、簇链遍历全部不动**。
**影响**：FAT16/FAT12 卡不再被干净拒绝——但你的卡是 FAT32（已确认），零影响。

> 不要删 MBR 分区表（那会强制卡"无分区表"格式化，你只说了"只在 FAT32 读"，没确认卡的
> 分区表格式）。若后续确认卡是 superfloppy，再单独做（见 [ALGO_OPT_PROMPT.md 改动 3.2](docs/ALGO_OPT_PROMPT.md)）。

---

## 6. 阶段 4：修 PHY-7002 约束（如存在）

- 若阶段 0 确认 `pin.adc`/`.sdc` 里 `U3/sdram` 有非法 location 约束，删掉该条或改成合法位置，
  消除 `PHY-7002` 与连锁的 placement 冲突。

---

## 7. 验证（必须全绿）

1. `python scripts/static_check.py` ALL PASS（删端口/信号同步改 `video_improve.al` 两份 +
   `scripts/design_files.txt`）。
2. ModelSim `scripts/run_tests.ps1` 全 PASS，重点：`tb_sd_address`、`tb_fat32`、`tb_bmp_scale`、
   `tb_scaled_bmp`、`tb_visual_pipeline`、`tb_glass_osd`。
3. TD `scripts/run_build.py`：
   - `report_timing`：Setup WNS ≥0、Hold WNS ≥0。
   - `PHY-9031/9042`、`RUN-8101`、`PHY-7002` 全部消失；成功出 `.bit`。
   - `report_area` 记录 LUT/BRAM（允许仍偏高，只要能出比特流即达标）。
4. 上板点测：双分辨率、图片、特效、玻璃、OSD、**音频** 与改前逐项一致，无花屏、无声断、帧率不降。

---

## 8. 执行顺序与验收线

1. **阶段 0 诊断** → 2. **阶段 1 修 WNS** → 3. **阶段 2 修 MSLICE** → 4. **阶段 3 删 FAT16** → 5. **阶段 4 修约束**。
6. 验收硬线：**出 `.bit` + WNS≥0 + 无 PHY-9xxx/8xxx/RUN-8101 + 全部 tb PASS + 功能/画质/帧率/音频零下降**。

---

## 附：本文件之外，需要时再单独勾选（默认不做，都有性能/画质/格式代价）

- 行缓存 2048→1024（省 6 BRAM，代价 = 不能加载 >1024 宽图）——见 [ALGO_OPT_PROMPT.md](docs/ALGO_OPT_PROMPT.md) 改动 1。
- 双线性→最近邻（省 500-800 LUT + 6 BRAM，代价 = 画质颗粒）——见 [ALGO_LEVEL_OPT_PROMPT.md](docs/ALGO_LEVEL_OPT_PROMPT.md) 算法 1。
- 删 MBR 分区表（省 ~200 LUT，代价 = 卡必须无分区表）——见 [ALGO_OPT_PROMPT.md](docs/ALGO_OPT_PROMPT.md) 改动 3.2。
- 关 OSD 调试列（省 ~200 LUT，代价 = 少几列调试字符）。
