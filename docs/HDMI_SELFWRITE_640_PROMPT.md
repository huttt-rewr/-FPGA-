# 删除 640 加密核 + 自写 640 TMDS 视频核 · 可落地提示词（2026-10-18）

> 用途：把本文件整段交给 GPT/协作者执行。目标：**删除 640 加密 HDMI 核，自写一个纯视频（video-only）
> 640 TMDS 核显示静态图片；800 加密核保留，独家负责视频播放与音频；640 音频为可选后续。**
> 铁律：零损害——保留双分辨率、画质、音频（800 上）、OSD/特效/游戏/字幕/玻璃/波形；任何功能取舍须用户显式点头。

---

## 0. 一句话目标

```
删掉 640 加密核（释放 ~1768 LUT + 17 BRAM），
自写一个 8b/10b TMDS 视频编码核（~300 LUT，0 BRAM）接现成 hdmi_phy_wrapper，
800 加密核照旧播视频+出声，640 只显示静态图片（无声），EDID 用自写 I2C 读保留。
```

---

## 1. 真实现状（已核对，勿重复排查）

| 项 | 值 |
|---|---|
| 当前 HEAD | `d34c488`，两 HDMI 核都在 [src/top.v](src/top.v) L568-676 |
| 640 加密核 | `u_hdmi_1_4b_transmitter_core_wrapper` = **1768 LUT + 17 BRAM**（含 EDID 读 387LUT+3BRAM、音频岛 11BRAM） |
| 800 加密核 | `u_hdmi_svga` = 1319 LUT + 14 BRAM（无 EDID，含自己的音频岛） |
| 串行 PHY | `u_hdmi2phy_wrapper` + `lane_lvds_10_1` = **明文 RTL**，可复用，无需重写 |
| 最终像素流 | `game_vs / game_de / game_rgb`（[top.v:528-539](src/top.v#L528) 前，经 `snake_game` 输出，含 OSD/游戏/特效全部叠加） |
| 像素/串行时钟 | `adaptive_video_clock`：640=25MHz/125MHz，800=40MHz/200MHz（BUFGMUX 按 `mode_800` 切） |
| 模式语义 | `res_mode==2` → 800（EDID 支持时），`res_mode 0/1` → 640；`mode_video==1` 表示 800 |

**加密核内部结构（`reports/physical_area.txt` L240-283 已核实）：**
- 视频 TMDS 编码 = `u0/u1/u2_hdmi_tmds_encode` 三份共 **551 LUT**（这就是要自写的部分，自写约 200-300 LUT）。
- 音频岛 = `u_hdmi_island_data_gen`（**11 BRAM**）+ `u_hdmi_island_data_assemble`（430 LUT）——视频-only 核**完全不需要**。
- EDID 读 = `u_hdmi_edid_wrapper`（387 LUT + 3 BRAM，含 `u_hdmi_edid_read_controller` 32 LUT）——加密在内，须自写 I2C 替代。

---

## 2. 铁律

- **零损害**：保留双分辨率、800 的音频、EDID、全部 OSD/字幕/玻璃/波形/特效/游戏。
- 800 加密核、`hdmi_phy_wrapper`、`lane_lvds_10_1`、PLL/SDRAM 相位、引脚约束、70 位状态总线**不碰**。
- 640 的"无声"是用户显式选择的（音频只用 800），不是本文件默认砍掉。
- 音频在加密核里是**按核复制**的（每核各一套 11 BRAM 音频岛），800 核的音频与 640 无关，删 640 不影响 800 出声。
- 单点改动、独立验证、不批量改；每阶段过门禁才进下一阶段。

---

## 3. 架构事实（决定"能删什么、要写什么"）

1. **加密的只有** `hdmi_1_4b_transmitter_core_wrapper`（EDID 读 + AXIS 视频 + 音频打包 + DDC + TMDS 编码，全在 `pragma protect` 里）。
2. **明文可复用**：`hdmi_phy_wrapper.v` / `lane_lvds_10_1.v` 是普通 RTL——它收 10bit TMDS 符号，用 `EG_LOGIC_ODDR` 做 10:1 串行化。**自写核只要吐出 10bit 符号即可。**
3. `adaptive_raster.v`（[adaptive_raster.v:3-18](src/modules/video/adaptive_raster.v#L3)）就是**现成的 640 时序模板**，`mode_800=0` 时：
   `ht=800, hsw=96, hbegin=144, width=640`；`vt=525, vsw=2, vbegin=35, height=480`。与加密 640 核的 HTOTAL/HSA/HFP/HBP/VTOTAL/VSA/VFP/VBP **逐项一致**。
4. `vs`/`de` 是**电平信号**（非单拍脉冲），一路经 `picture_adjust→…→snake_game` 以寄存器延迟透传，`game_vs` 低电平=场同步期、`game_de` 高电平=有效区。`hs` 在 `video_delay` 之后被丢弃（overlay 流水线只传 vs/de），故**须自写核自行恢复 HS**。
5. 模式切选已在 [top.v:563-567](src/top.v#L563)：`tmds_* = mode_video ? svga_* : vga_*`。自写核只要驱动 `vga_*` 四个 10bit 通道即可复用这套 mux。

---

## 4. Phase A —— 自写 640 TMDS 视频核（video-only，必做）

### A1. 新模块接口（新建 `src/modules/hdmi/hdmi_tmds_vga.v`）

```verilog
module hdmi_tmds_vga(
    input            clk,      // video_clk = 25MHz（640 模式像素时钟）
    input            rst,      // rst_vga（高有效）
    input            vs,       // game_vs（低有效场同步电平）
    input            de,       // game_de（有效区电平）
    input  [23:0]    rgb,      // game_rgb（最终合成像素）
    output [9:0]     ch0,      // TMDS 通道0：蓝 + VSYNC/HSYNC
    output [9:0]     ch1,      // TMDS 通道1：绿 + CTL0/1
    output [9:0]     ch2,      // TMDS 通道2：红 + CTL2/3
    output [9:0]     clk_ch    // 时钟通道固定图案
);
```

不要消费 AXIS（`axis_s_*` 留给 800 核），直接吃 `game_vs/game_de/game_rgb`，理由见 §3.4。

### A2. 时序（复用 adaptive_raster 的 640 参数，mode_800 恒 0）

```
HTOTAL=800  HSA=96  HFP=16  HBP=48  HACTIVE=640
VTOTAL=525  VSA=2   VFP=10  VBP=33  VACTIVE=480
```
内部 H(0..799)/V(0..524) 计数器，产生：
```verilog
hs = (h >= 96);            // 低有效（h<96 时低）
vs = (v >= 2);             // 低有效（v<2 时低）
de_int = (h>=144 && h<784) && (v>=35 && v<515);
```

### A3. 与 game_vs/game_de 的对齐（关键，错一点整屏偏移）

`game_vs/game_de/game_rgb` 三者是**同步延迟**的同源信号，但相对 `rst` 释放点有流水线级数偏移。
因此**不能用 rst 后的自由计数器直接对齐**，必须每帧锁定：

```
reg game_vs_d; always @(posedge clk) game_vs_d <= game_vs;
wire frame_start = game_vs_d && !game_vs;   // 进入场同步（v 归 0 的瞬间）
// 在 frame_start 拍：h<=0; v<=0;（其余时刻按 A2 正常递增/回绕）
```

因 `adaptive_raster` 里 h、v 在同一拍回绕（h==799 时 v 才 +1/回绕），故 `frame_start` 对齐 h=0、v=0 是精确的。
**像素选通**：优先用内部 `de_int` 闸 `rgb`；仿真核对若发现 1~2 拍相位差，退回直接使用输入 `de` 作为数据/控制开关（同步脉冲仍用内部 hs/vs）。二者在锁定后应逐位一致。

### A4. TMDS 8b/10b 编码规格（DVI 1.0 §3.2，公开标准）

**控制期（de=0）控制码表**（HSYNC/VSYNC 只出现在通道0）：

| 通道 | {C1,C0} | 10bit 码 |
|---|---|---|
| ch0 | {VSYNC,HSYNC}=00 | `10'b1101010100` (0x354) |
| ch0 | =01 | `10'b0010101011` (0x0AB) |
| ch0 | =10 | `10'b0101010100` (0x154) |
| ch0 | =11 | `10'b1010101011` (0x2AB) |
| ch1 | 00 | 0x354 |
| ch2 | 00 | 0x354 |

**数据期（de=1）8b→10b**：用公认参考实现（Xilinx/AMD `dvi_encoder` / fpga4fun `encode` / 通用 `rgb2tmds`），
带运行极性 `cnt`（初值 -1），按 D[7:0] 先 XOR/XNOR 得 9 位中间码、再按 cnt 与 N1 决定第 10 位与是否取反。
**不要自己发明编码**，照抄已知正确实现并适配成"输出 10bit 符号、不串行"。

**时钟通道**：`clk_ch = 10'b0000011111`（0x03F，5 个 0 + 5 个 1，恒定）。接收端靠它锁相。

**位序**：`hdmi_phy_wrapper` 内部先把 `ch[9:0]` 反排成 `{ch[0],ch[1],…,ch[9]}`，`lane_lvds_10_1` 再每串行时钟左移 2 拍、取 `[9:8]`，即 **bit0（LSB）先出**。因此自写核按标准 TMDS 的 **LSB-first** 直接输出 10bit 码（`q_out[0]`=LSB），与加密核 `O_ch0_tmds_data` 约定一致，无需再反排。

**HS/VS 极性**：`adaptive_raster` 的 `hs/vs` 是**低有效内部电平**（0=同步期）。TMDS 控制码里的 HSYNC/VSYNC 位取标准极性。上板前无法 100% 确定极性，**首次上板若无图像/不锁，先试翻转同步位**（`C1=!vs, C0=!hs`），二选一必中其一。

### A5. 集成进 top.v（精确改动清单）

1. **删** [top.v:568-613](src/top.v#L568) 整个 `u_hdmi_1_4b_transmitter_core_wrapper` 实例（640 核）。
2. **删** [top.v:552](src/top.v#L552) 的 `wire vga_ready;`（自写核无背压）。
3. **改** [top.v:563](src/top.v#L563)：
   `assign axis_s_ready=mode_video?svga_ready:1'b1;`
4. **保留** `vga_ch0/vga_ch1/vga_ch2/vga_clk` 四个 wire（[top.v:552](src/top.v#L552)），改由新核驱动；mux（L564-567）不动。
5. **加** 新实例（放在原 640 核位置）：

```verilog
hdmi_tmds_vga u_hdmi_640(
    .clk   (video_clk),
    .rst   (rst_vga),
    .vs    (game_vs),
    .de    (game_de),
    .rgb   (game_rgb),
    .ch0   (vga_ch0),
    .ch1   (vga_ch1),
    .ch2   (vga_ch2),
    .clk_ch(vga_clk)
);
```

6. **不动**：`rst_vga` 复位链（[top.v:561](src/top.v#L561)）、`video_rgb_to_axis_640x480`（[top.v:528-540](src/top.v#L528)）、`axis_s_*`、800 核、`u_hdmi2phy_wrapper`。
   640 模式下 `axis_s_ready=1`，AXIS 转换器自由跑、输出被忽略，无副作用。

---

## 5. Phase B —— EDID（删 640 核会连带丢掉加密 EDID 读，须自写替代）

加密 640 核负责读显示器 EDID（`O_edid_read_valid/data` + `HDMI_DDC_SCL/SDA`）。删掉后这些信号悬空。
**推荐做法（零损害，保 EDID 功能）**：自写一个 I2C/DDC EDID 读取模块，替代加密 EDID 读。

- 接口对齐现有解析器：`edid_display_mode`（[edid_display_mode.v:4-8](src/modules/video/edid_display_mode.v#L4)）已存在且是明文，
  它只要 `start / valid / data[7:0]` 的 128 字节流。**只缺 I2C 读那一环。**
- 自写 I2C master：从 0xA0 地址读 128 字节 EDID，产生与加密核同形的 `edid_valid/edid_data` 字节流，
  接到 [top.v:257-267](src/top.v#L257) 的 `edid_valid/edid_data`（下面采样逻辑不动）。
- 驱动 [top.v:25-26](src/top.v#L25) 的 `HDMI_DDC_SCL / HDMI_DDC_SDA`（SDA 为 inout，须三态）。
- 消耗约 100-200 LUT、0 BRAM（对比加密 EDID 的 387 LUT + 3 BRAM，仍净省）。
- `startup_pulse` → `edid_trig`（[top.v:543-549](src/top.v#L543)）照旧触发，`edid_display_mode`（[top.v:831-833](src/top.v#L831)）照旧解析。

**备选（须用户显式点头才做）**：砍 EDID，硬编码 `edid_done=1`、`supports_800=1`，`HDMI_DDC_SCL=1'b1`、`HDMI_DDC_SDA=1'bz`。
代价是失去"显示器不支持 800 时自动回退 640"的协商。**默认不做。**

---

## 6. Phase C —— 640 播放音频（可选，最难，默认不做）

音频 PCM 已在 `audio_valid/audio_left/audio_right`（video_clk 域，[top.v:162](src/top.v#L162)）就绪，只差 640 侧打包。
要在自写核里补：ACR 时钟再生（N=6144、CTS≈25175）、IEC60958 子帧 + BCH(4) 校验、音频采样包、每场一次的时钟再生包、
以及数据岛在消隐期与视频控制码的时分复用 + 保护带。这是 HDMI 音频最磨人的部分（约 +500~1000 LUT，需真实显示器/逻辑分析仪调）。
**640 只放静态图不需要音频，本文件默认不进入此阶段；用户明确要求才单独立项。**

---

## 7. 验证（分阶段门禁，缺一不可）

**Phase A 后：**
1. `python scripts/static_check.py` → ALL PASS（新增 `hdmi_tmds_vga.v` 计入源文件，端口/引脚一致）。
2. 新增 `sim/tb_hdmi_tmds_vga.v`：喂 640 时序的 vs/de/rgb，断言——
   (a) 控制期输出恰为 A4 四码之一；(b) 数据期 8b→10b 与参考编码器逐位一致；(c) `frame_start` 锁定后 hs/vs/de 与输入帧对齐；(d) 时钟通道恒 0x03F。
3. TD 完整 build（`python scripts/run_build.py`）语法/综合/布线通过，记录新 SWNS 与 LUT/BRAM 总量。
   **期望**：LUT 从 17357 降到 ~16000 档，BRAM 从 58 降到 ~41，SWNS 可能因布线拥堵缓解而收窄（不承诺，见 §8）。

**Phase B 后：** 新增 `sim/tb_edid_i2c.v`，模拟 0xA0 从机回 128 字节，断言 `edid_display_mode` 能给出 `done/good/mode_800` 与加密核同形行为；`static_check` 再跑一遍。

**全阶段后：** `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1` 全量回归 ALL PASS（重点 sd/bmp/audio，因 EDID/模式链在 boot 域）。

**上板（唯一能证明画质/极性/位序的环节）：**
- 640 模式：显示器出**静态图片 + OSD**，无噪点/无偏移/颜色正确（红绿蓝独立验证）。
- 800 模式：出图 + 出声，与改前一致。
- 若 640 不锁/偏色：先试 A4 的同步极性翻转，再查 8b→10b 位序，再查 `frame_start` 对齐。

---

## 8. 验收硬线

**static_check + 全量回归 ALL PASS + 无新增 CRITICAL + 无 coredump；
640 静态图正确、800 图声与改前一致、EDID 协商保留；LUT/BRAM 显著下降。
音频（640）未做不算缺陷——它是用户可选 Phase C，不是默认承诺。**

---

## 9. 诚实兜底

1. **本方案唯一硬风险是 TMDS 的位序/极性/对齐**，它只能在真实显示器上闭环验证；仿真只能证 8b→10b 编码与参考一致，不能证明显示器锁相。这是所有自写 HDMI 的共性，不是本工程的坑。
2. 删 640 核释放 17 BRAM + ~1768 LUT，**预期**缓解布线拥堵、可能改善 FAT32 那 −0.592ns（路由占 7.249ns），但**不承诺**（FAT32 窄化已证明"逻辑更浅≠时序更好"），须重跑 STA 才作数。
3. 若自写 640 的 `frame_start` 对齐在真实硬件上有残留相位差，退回"直接用 `game_de` 选通 + 只自恢复 HS/VS"的降级方案（§A3），仍是零损害。
4. 零损害代码手段用尽后，其余取舍（砍 EDID、最近邻缩放等）一律回交用户显式选择。
