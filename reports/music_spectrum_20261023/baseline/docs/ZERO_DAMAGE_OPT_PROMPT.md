# 零损害优化 · 可落地提示词（不碰算法、不改画质、不丢功能）

> 用途：把本文件整段交给 GPT/协作者执行。目标：**在不改变任何功能、画质、音频、双分辨率、
> EDID 的前提下**，把构建失败状态（WNS −16ns、MSLICE legalize 报错）修到**能出比特流**。
> **铁律**：任何会损害原功能的改动（最近邻、砍功能、源宽收窄、卡格式约束）**都不属于本文件**，
> 需要时由用户单独勾选（见文末附录，仅供选择，不默认执行）。
> **必须适配本工程**：安路 EG4S20、TD 6.2.1、复位高有效、`vs/de` 同拍。

---

## 0. 关键判断（先看懂再动手）

- 构建**真正失败的原因**是 `WNS −16ns` + `PHY-9031/9042 MSLICE legalize` + `RUN-8101 place 超资源`。
- LUT 92.08% / BRAM 95.31% 是**高水位警告，不是失败主因**（18048/19600 和 61/64 都能放得下）。
- 修 WNS 和 MSLICE 溢出**都是零损害可修的**：加寄存器只让画面整体晚 1 拍、拆进位链结果位级相同。
- 所以零损害路径的产出是**「构建能过」**，不是「把百分比压到 85/90」——后者必须动取舍项。

---

## 1. 先做：精确定位（别盲改）

1. TD 里 `report_timing -n 20`，抄出**最差 20 条路径的起点/终点**，确认 21 级关键路径在哪个模块
   （预期在 `sd_fat32` 或 `bmp_scale_loader` 的 32 位几何/除法/大 MUX）。
2. `report_area` 定位 **MSLICE/ripple 最集中区域**（预期在 FAT32 和缩放模块附近）。
3. 打开 [src/constraints/pin.adc](src/constraints/pin.adc) 核对 `PHY-7002 sdram location` 警告，
   看 `U3/sdram` 是否被手动约束到非法位置（log 说 `(164,288)` 不被接受），有就删掉该条 location 约束。
4. **把这三条结果记下来再往下做**，每改一处重跑一次 `report_timing`，一次只改一处。

---

## 2. 零损害改动 A：打断 21 级关键路径（修 WNS）

**原理**：在组合路径中间插一级寄存器，把 21 级拆成 ≤12 级 × 2 段。视频链是 `vs/de/x/rgb` 同步流水，
**只要把 `vs/de/x` 和 `rgb` 一起延迟同样拍数，画面逐像素不变，只是整体晚 1 拍**。

**方法**：

1. 用第 1 步的 `report_timing` 结果找到那条路径的**中点寄存器**。
2. 在路径中间加一级寄存器；同时**把同模块的 `vs/de/x` 也延迟相同拍数**，保持同拍。
   - 参照 [picture_gamma.v](src/modules/video/picture_gamma.v) L284-293 的写法：`r/g/b/bypass/enabled/v/d/px`
     全都同拍寄存，`out_vs<=v; out_de<=d; out_x<=px;` 与 `out_rgb` 一起输出。
3. 若路径跨模块，优先在**模块边界**加寄存器（FAT32 输出、缩放地址计算输出）。
4. 每加一级，重跑 `report_timing` 看 WNS 是否回升。

> 关键：**只加寄存器，不改任何算术、不改任何状态机跳转**。加完跑 `tb_bmp_scale`/`tb_sd_address`/
> `tb_visual_pipeline`，断言输出和改前**逐拍一致（仅整体移位）**。

---

## 3. 零损害改动 B：拆 32 位进位链（修 MSLICE 溢出）

**原理**：`RUN-8101 place 超资源` 常因同区域进位链（ripple）太密。把 32 位加法拆成
"低 16 位 + 进位" 与 "高 16 位 + 进位" **两拍**，结果**位级相同**，只是晚 1 拍。

**已知嫌疑点**（[src/modules/sd/sd_fat32.v](src/modules/sd/sd_fat32.v)，先只拆 `report_area` 指向的那个）：

- L364：`map_base<=first_data+map_shifted;`（DIR 簇→扇区）
- L454：`map_base<=first_data+map_shifted;`（STREAM 簇→扇区）
- L325：`first_fat<=partition_lba+reserved_count;`
- L329-330：`overhead<=fat_area+reserved_count; first_data<=first_fat+fat_area; volume_last<=partition_lba+total_minus_one;`
- L336：`data_sectors<=total_sectors-overhead;`

**拆分模板**（以 L364 为例，把一次 32 位加变成两拍 16 位加）：

```verilog
// 改前（一拍 32 位加）
state[32]:begin map_base<=first_data+map_shifted;state<=DIR_FINISH;end

// 改后（拆两拍；进位用 1 位寄存器穿过）
reg [15:0] map_base_lo;reg [15:0] map_base_hi;reg map_base_c;
// 第 1 拍：低 16 位求和 + 进位
state[32]:begin
 {map_base_c,map_base_lo}<=first_data[15:0]+map_shifted[15:0];
 state<=DIR_BASE_HI;   // 新增一个独热态
end
// 第 2 拍：高 16 位 + 进位
state[xx]:begin
 map_base_hi<=first_data[31:16]+map_shifted[31:16]+{15'd0,map_base_c};
 map_base<={map_base_hi,map_base_lo};state<=DIR_FINISH;
end
```

> 注意：要在 49 态独热里**新增一个 state 位**（`localparam` 里加一个 `40'h...` 值），
> 并同步改 `state` 位宽。**只拆 `report_area`/`legalize` 指向的那 1~2 个**，别全拆，
> 否则状态翻倍反而更糟。拆完跑 `tb_sd_address`/`tb_fat32` 断言地址逐位一致。

---

## 4. 零损害改动 C：删死代码（省少量 LUT）

> 以下是之前审计确认过的死信号/冗余判断，删了**零逻辑影响**。删前各 `grep` 一遍确认无其它引用。

1. [src/top.v](src/top.v)：删 L88 `wire display_valid;` 和 L194 `.display_valid(display_valid),`。
2. [src/modules/bmp/bmp_read.v](src/modules/bmp/bmp_read.v)：删 L95 的
   `(bmp_width == 640) && (bmp_height == 480)` 这一冗余判断（上方 `width==bmp_width && height==bmp_height`
   已等价地强制 640×480）。

> 收益：各几十 LUT，聊胜于无；主要价值是**干净、零风险**。

---

## 5. 零损害改动 D（可选）：Gamma 3 块 → 2 块（位级相同，只省 1 块）

**现状** [src/modules/video/picture_gamma.v](src/modules/video/picture_gamma.v) L289：
`r<=curve(rgb[23:16]); g<=curve(rgb[15:8]); b<=curve(rgb[7:0]);`，`curve` 是 256×10 的 case 查表，
内联 3 次 → 3 块 BRAM。因为 40MHz 每拍要同时读 R/G/B 三个地址，**不能合成 1 块**。

**位级相同的做法（3→2 块）**：把 `curve` 从 `function` 改成一个**双口 BRAM ROM**
（`(* ram_style="bram" *) reg [9:0] gamma_rom[0:255];` 初始化为该表），用双口同时读 R、G 两个地址，
B 用另一块单口 ROM（或复用双口的第二个口再做一拍）。**省 1 块 BRAM，输出位级相同**。

> 坦白：这条**省得少（1 块）、要手动调 TD 的 ROM 推断、还得保证初始化正确**，性价比不高。
> 如果 BRAM 不是构建失败的硬阻塞（现在 61/64 能放下），**建议跳过这条**，别为此引入风险。

---

## 6. 验证（必须全绿）

1. `python scripts/static_check.py` ALL PASS（删了端口/信号就同步改 `video_improve.al` 两份 +
   `scripts/design_files.txt`）。
2. ModelSim `scripts/run_tests.ps1` 全 PASS，重点：`tb_bmp_scale`、`tb_scaled_bmp`、`tb_sd_address`、
   `tb_fat32`、`tb_visual_pipeline`、`tb_glass_osd`。
3. TD `scripts/run_build.py`：
   - `report_timing`：**Setup WNS ≥ 0、Hold WNS ≥ 0**。
   - **`PHY-9031/9042`、`RUN-8101` 全部消失**；成功出 `.bit`。
   - `report_area` 记录 LUT/BRAM（允许仍偏高，只要**能出比特流**即为零损害路径达标）。
4. 上板点测：双分辨率、图片、特效、玻璃、OSD、**音频**与改前**逐项一致**，无花屏、无声断。

---

## 7. 执行顺序与验收线

1. **第 1 步诊断**（`report_timing`/`report_area`/`pin.adc`）——不跳。
2. **改动 A（打断关键路径）** + **改动 B（拆进位链）**——修掉真正的失败点，零损害。
3. **改动 C（删死代码）**——顺手清理。
4. 综合看：若已出 `.bit` 且 WNS≥0、无 PHY/RUN 错误 → **零损害路径完成，不要继续动别的**。
5. 验收硬线：**能出 `.bit` + WNS≥0 + 无 PHY-9xxx/8xxx/RUN-8101 + 全部 tb PASS + 功能逐项一致**。

---

## 附录：取舍项（**仅供用户勾选，本文件默认不执行**）

- **行缓存 2048→1024**（[bmp_scale_loader.v:39](src/modules/video/bmp_scale_loader.v#L39)）：省 6 BRAM；
  代价 = 不能加载 >1024 宽图。见 [ALGO_OPT_PROMPT.md 改动 1](docs/ALGO_OPT_PROMPT.md)。
- **双线性 → 最近邻**：省 500-800 LUT + 6 BRAM；代价 = 画质颗粒。见 [ALGO_LEVEL_OPT_PROMPT.md 算法 1](docs/ALGO_LEVEL_OPT_PROMPT.md)。
- **Gamma 分段线性 → 0 BRAM**：省 3 BRAM；代价 = ±1 LSB 极小误差。
- **删 MBR 分区表**：省 ~200 LUT；代价 = 卡必须无分区表 FAT32。
- **关 OSD 调试列**：省 ~200 LUT；代价 = 少几列调试字符。

> 这些每一项都要**用户明确点头**才做，绝不在零损害路径里默认带上。
