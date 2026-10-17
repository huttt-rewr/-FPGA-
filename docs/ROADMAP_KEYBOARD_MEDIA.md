# 键盘交互 + 分辨率/帧率 + SD 高速：完整落地路线

> 实施注记（2026-10-16）：下文保留用户原路线，**它是需求，不是完成报告**。实际进度见 [键盘操作说明](KEYBOARD_USAGE_20261016.md) 和 [构建状态](BUILD_STATUS.md)。已纠正的实现依据：FAT32簇号有效28位，不能截为16位；文件数有硬件上限，不是无限；R运行切换必须经过安全复位和重新加载，不能用EDID结果直接OR阻止切回VGA；F是换图频率，不是HDMI刷新率。50MHz需CMD6高速协商和板级输入时序预算，不能照搬SDRAM的90度相位就宣称通过。正式板级SD仍SPI25MHz。阶段1～4已正式接入，77项回归及STA通过，精确数值与源码哈希见构建状态。阶段5仍未接入板级四位/50MHz。

> 目标：用 PS/2 键盘在屏幕上自由选分辨率、调帧率、选第几张图/第几个音频、开关 OSD，
> 并把 SD 传输速率提上来支撑高帧率。本文按"每个阶段都能独立落地、阶段间靠同一套控制信号串接"组织。
>
> 执行顺序必须按阶段走：**阶段 1 是地基**，后面的阶段都只往同一个"控制寄存器"里加位、加消费者，
> 不改键盘和事件层。

---

## 0. 最终效果（验收标准）

- 键盘方向键 ←/→ 切上一张/下一张图；空格 自动播放开/关。
- 数字键 0~9 选第 N 张图；`A`+数字 选第 N 个音频。
- `R` 循环切分辨率（320×240 缩放 / 640×480 / 800×600）；`F` 循环切帧率档。
- 上/下 调音量；`M` 静音；`O` 开关 OSD 显示。
- SD 用 4-bit 总线（25MHz→50MHz 高速），高分辨率也够帧率。

---

## 1. 总体架构（串接的骨架）

所有控制走一个"控制平面"，键盘只产生**事件脉冲**，事件写进**控制寄存器**，各功能模块只读寄存器：

```
PS/2 键盘 ──ps2_clk/ps2_data──▶ ps2_keyboard.v（接收器，出 scan_code）
                                   │
                                   ▼
        ps2_controls.v（键码 → 语义事件脉冲 + 数字序号锁存）
                                   │  事件：ev_next/ev_prev/ev_toggle_auto/ev_vol_up/ev_vol_dn/
                                   │        ev_mute/ev_osd/ev_res/ev_fps/ev_digit[3:0]+ev_digit_valid
                                   ▼
         控制寄存器（本路线唯一状态源，阶段 2~4 只加位）：
           image_index[7:0]  选第几张图        （阶段 2 生效）
           audio_index[7:0]  选第几个音频       （阶段 2 生效）
           res_mode[1:0]     分辨率档           （阶段 3 生效）
           fps_mode[3:0]     帧率档             （阶段 4 生效）
           osd_on            OSD 开关
           volume[4:0], mute, auto_play
                                   │
     ┌──────────┬──────────┬──────────┬──────────┬──────────┐
     ▼          ▼          ▼          ▼          ▼          ▼
 sd_card_bmp  sd_card_bmp  video_timing 自动播放定时器  status_osd
 (读 image_index) (读 audio_index) (读 res_mode) (读 fps_mode) (读 osd_on)
```

**为什么这样能串接**：键盘、事件层、控制寄存器一旦在阶段 1 建好并稳定，阶段 2/3/4 只是
"往寄存器加位 + 把寄存器接到新消费者"，键盘代码一行都不用改。这就是"串接"的关键。

---

## 2. 控制寄存器与键位总表（先定死，后续不许改）

| 寄存器 | 宽度 | 复位 | 键盘来源 | 阶段 |
|---|---|---|---|---|
| `image_index` | 8 | 0 | 数字 0~9 | 2 |
| `audio_index` | 8 | 0 | `A`+数字 0~9 | 2 |
| `res_mode` | 2 | 01(640×480) | `R` | 3 |
| `fps_mode` | 4 | 档 2 | `F` | 4 |
| `osd_on` | 1 | 1 | `O` 翻转 | 1 |
| `volume` | 5 | 默认 | 上/下 ±1 | 1 |
| `mute` | 1 | 0 | `M` 翻转 | 1 |
| `auto_play` | 1 | 0 | 空格 翻转 | 1 |

Set 2 扫描码（make code，松开时先发 `0xF0`，扩展键先发 `0xE0`）：

| 键 | 码 | 键 | 码 | 键 | 码 |
|---|---|---|---|---|---|
| 0~9 | 45,16,1E,26,25,2E,36,3D,3E,46 | A | 1C | P | 4D |
| R | 2D | F | 2B | M | 3A |
| O | 44 | 空格 | 29 | Esc | 76 |
| ↑/↓/←/→ | E0 75 / E0 72 / E0 6B / E0 74 | | | | |

---

## 3. 阶段 1：PS/2 键盘 + 控制寄存器框架（地基，先做）

### 【提示词：阶段 1】

**任务**：给 `E:/fpga` 加 PS/2 键盘接收与"控制寄存器"框架。本阶段只实现 OSD 开关、切图、自动播放、音量/静音；数字序号与 `res_mode`/`fps_mode` 只存值、暂不接消费者。

**先读**：[src/top.v](src/top.v)（按键接线在 635-642 行、`osd_enable` 写死在 631 行、`cmd_prev` 写死在 630 行）、[src/modules/bmp/sd_card_bmp.v](src/modules/bmp/sd_card_bmp.v)（`MAX_BMP=4`）。

**新增文件 1：`src/modules/input/ps2_keyboard.v`**

PS/2 协议规则（实现必须遵守）：
- `ps2_clk` 由键盘产生（约 10~16 kHz）；数据在 **`ps2_clk` 下降沿采样**。
- 一帧 11 bit：`起始0 + 8数据(LSB先) + 奇校验 + 停止1`。
- 先对 `ps2_clk`/`ps2_data` 做 2 级同步（`(* async_reg="true" *)`）再检测下降沿。
- 松开键 = `0xF0` 后跟键码；扩展键（方向键）= `0xE0` 前缀后跟键码。

```verilog
module ps2_keyboard (
    input  clk, rst, ps2_clk, ps2_data,
    output reg [7:0] scan_code,
    output reg       key_valid,     // 完整键码单拍脉冲
    output reg       key_release    // 1=松开(break) 0=按下(make)
);
    // 1) ps2_clk/ps2_data 各做 2 级同步
    // 2) 检测 ps2_clk 同步后的下降沿
    // 3) 每个下降沿把 ps2_data 同步值移入 11 bit 移位寄存器，计数到 11
    // 4) 集满：校验 start==0、stop==1、奇校验正确，则 data[8:1] 是键码
    // 5) 状态机：收到 0xF0 → 置 key_release；收到 0xE0 → 等下一字节；
    //    普通字节 → 输出 scan_code + key_valid
endmodule
```

**新增文件 2：`src/modules/input/ps2_controls.v`**

把 `scan_code/key_valid/key_release` 译成语义事件（全部**单拍脉冲**），并按第 2 节总表处理：
- 方向键、空格、上/下、M、O、R、F 各出对应脉冲（只响应 make，忽略 break 或同时用 make 触发）。
- 数字 0~9：锁存到 `image_index` 并出 `ev_image_select`。
- `A` 键进入"等待下一个数字"的 pending 状态，下一个数字锁存到 `audio_index` 并出 `ev_audio_select`，超时或按 Esc 取消 pending。
- `R`/`F`：把 `res_mode`/`fps_mode` 递增取模（R 模 3，F 模档数），本阶段只存值。

**控制寄存器放在 top.v**（与本工程现有风格一致，用 `sd_card_clk` 域）：

```verilog
reg [7:0] image_index, audio_index;
reg [1:0] res_mode;
reg [3:0] fps_mode;
reg       osd_on;
// volume/mute 复用现有 picture_controls 的 volume/mute，键盘脉冲与按键并联
```

**顶层接线（改 `src/top.v`）**：
1. 端口表加 `input ps2_clk, ps2_data;`。
2. 实例化 `ps2_keyboard` + `ps2_controls`。
3. 与现有按键并联（OR），不破坏原 `key1/key2/key3`：
   - `cmd_next` = 原 `next_pulse` **或** `ev_next`；`cmd_toggle` = 原 `toggle_pulse` **或** `ev_toggle_auto`。
   - `osd_enable` 从 `assign osd_enable=1'b1` 改成 `always` 寄存器，`ev_osd` 时翻转，复位为 1。
   - 上/下 脉冲给 `volume` ±1（夹 0~31）；`M` 翻转 `mute`。
4. `res_mode/fps_mode/image_index/audio_index` 引出但本阶段暂不接消费者（留悬空或注释说明阶段 2/3/4 接）。

**验证**：
- 新增 `sim/tb_ps2_keyboard.v`：模拟 11 bit 帧（下降沿逐 bit 送 start+data+parity+stop），
  断言 scan_code 正确、`0xF0`→key_release、`0xE0` 前缀合并、非法校验被丢弃。
- `python scripts/static_check.py` 必须 ALL PASS（新源文件登记进 TD 工程清单和 static_check 源列表）。
- ModelSim 回归含 `tb_ps2_keyboard` 必须 PASS。
- 不碰 SD 接口、音频解析、SDRAM 时序；PS/2 用哪个空闲 IO 由你在约束里选，并同步 top 端口表。

---

## 4. 阶段 2：文件索引表（多图片/多音频 + 数字键选序）

### 【提示词：阶段 2】

**任务**：把 [src/modules/bmp/sd_card_bmp.v](src/modules/bmp/sd_card_bmp.v) 里"固定 4 个 BMP 槽 + 1 个 WAV 槽"改成**文件索引表**，支持任意数量文件，并让 `image_index`/`audio_index` 真正选中第 N 个。

**先读**：`sd_card_bmp.v`（找 `MAX_BMP`、BMP/WAV 槽位、FAT32 枚举逻辑）、[src/modules/sd/sd_fat32.v](src/modules/sd/sd_fat32.v)（枚举与簇链）。

**设计**：
- 索引表每一项存：`类型(1bit: 图片/音频) + 起始簇号(16bit) + 大小字节数(32bit)`，再加文件数量计数。
- 存储二选一（按资源定）：
  - **BRAM**：现 BRAM 已 59/64，只能存少量（如 64~128 项），够用但紧。
  - **SDRAM**：空间充足，但要新加一段"启动时把索引表写进 SDRAM、运行时读回"的路径。
  建议先 BRAM（简单、够比赛），项数上限做成参数 `MAX_FILES=64`。
- FAT32 枚举时，把所有 BMP/WAV 按目录顺序写入索引表，**不再只取前 4 个**；删除项/LFN/卷标/子目录照旧跳过。
- 播放时：图片播放器读 `image_index` 指向的表项（簇号→沿 FAT 链读）；音频播放器读 `audio_index` 指向的表项。
- `status_index/status_count` 改成"当前序号 / 总文件数"，让 OSD 显示"第 3 张 / 共 20 张"。
- 越界保护：`image_index >= 文件数` 时回卷到 0 或显示"无文件"。

**验证**：
- 扩展现有 `tb_fat32_mount`/`tb_fat32_stream`：镜像里放 10+ 张 BMP、3+ 个 WAV，断言枚举数量正确、按 `image_index`/`audio_index` 能取到正确的文件、越界回卷。
- 回归全绿；`static_check` ALL PASS。

---

## 5. 阶段 3：分辨率选择

### 【提示词：阶段 3】

**任务**：键盘 `R` 循环切分辨率，`res_mode` 生效，支持 320×240(缩放)/640×480/800×600。

**先读**：[src/top.v](src/top.v) 的 `mode_800`/`output_width`/`output_height`（65-67 行）、[src/modules/video/video_timing_data.v](src/modules/video/video_timing_data.v) 与缩放链路（`picture_adjust`/`ENABLE_SCALING`，top.v 中 `ENABLE_SCALING=1`）。

**设计**：
- `res_mode` 三档：
  - `00` = 源 320×240，靠现有双线性缩放放大到 640×480 输出（最省 SD 带宽，帧率最高）。
  - `01` = 640×480（默认）。
  - `02` = 800×600（走 `mode_800` 的 SVGA 时序）。
- 输出分辨率：`00/01` 用 VGA 时序，`02` 用 SVGA 时序；把 `mode_800` 从"EDID 自动协商"改成"EDID 结果 或 res_mode==02"（保留 EDID 兜底）。
- 源读取尺寸：BMP 头校验的宽高要跟着 `res_mode` 变（320×240 档接受 320×240 的 BMP，交给缩放器放大）。
- **注意**：切分辨率要重新触发一次"重新挂载/重新读当前图"，避免新旧尺寸帧缓冲混用；建议切档时先回到"正在装载"状态再加载。

**验证**：
- 现有 `tb_scaled_bmp`/`tb_scaled_svga` 已覆盖缩放，扩展断言 320→640 双线性结果；新增"切 res_mode 后重载"用例。
- 回归全绿。

---

## 6. 阶段 4：帧率调整

### 【提示词：阶段 4】

**任务**：键盘 `F` 循环切帧率档，`fps_mode` 控制自动播放的换图间隔。

**先读**：`sd_card_bmp.v` 里自动播放逻辑（`key_auto`/`status_auto` 及换图定时器）。

**设计**：
- `fps_mode` 档位（按分辨率×SD 速度的物理上限定，超出就按能达到的最大值）：
  - SPI 25MHz：320×240 约 11 fps、640×480 约 2.7 fps。
  - 4-bit 50MHz：320×240 约 100+ fps、640×480 约 28 fps。
  - 建议档位 `{1, 2, 5, 10, 15, 30}` fps，选档时按当前 `res_mode` 夹到可达上限。
- 自动播放定时器：`间隔 = sd_card_clk / fps`，到点触发 `cmd_next`。
- **帧率与读取的配合**：换图间隔必须 ≥ "读完一帧所需时间"，否则下一帧没读出来就空转；用 `status_busy` 挡住定时器，等当前帧提交完成再计时。

**验证**：
- 新增 `tb_fps_control.v`：断言各档间隔正确、`status_busy` 时定时器等待、切档立即生效。

---

## 7. 阶段 5：SD 4-bit 高速（可选 DDR50）

### 【提示词：阶段 5】

**任务**：把 SD 从 SPI 单线改成 **4-bit 总线**，先 25MHz 后 50MHz 高速；只有阶段 1~4 都绿了再做。

**先读**：[src/modules/sd/spi_master.v](src/modules/sd/spi_master.v)、[src/modules/sd/sd_card_sec_read_write.v](src/modules/sd/sd_card_sec_read_write.v)、[src/modules/sd/sd_card_top.v](src/modules/sd/sd_card_top.v)。

**4-bit 核心（与之前 C 路线一致）**：
- 6 线：`CLK/CMD/DAT0~3`（替换 `nCS/DCLK/MOSI/MISO`）。
- 初始化序列：CMD0→CMD8→CMD55+ACMD41→CMD2→CMD3→CMD7→CMD55+ACMD6(arg=2)→CMD16。
- CRC7（多项式 0x09）用于命令、CRC16（0x1021）用于数据；数据线 4 bit 并行、每条线各自移位。
- 读扇区：CMD17（单块）起步，稳定后换 CMD18（多块连续读）。
- **50MHz 高速档**：复用本工程 SDRAM 的相位偏移思路（`ext_mem_clk_sft`），给 DAT 采样配一路 90° 移相时钟，采样点对准数据窗口中央（源同步时序，往返延迟 ~10-20ns）。

**DDR50（双沿）——先不做的说明**：DDR50 = 50MHz 双沿 = 50 MB/s，但需要额外三关：
① 4-bit 总线；② **1.8V 电压切换**（CMD11 序列 + 板子 IO 必须能 1.8V，多数便宜板不行）；③ 双沿采样 + 上电训练。
对本项目的 BMP 视频，4-bit SDR 50MHz（25 MB/s）已够 640×480@28fps，DDR50 收益过剩、风险大，**比赛不建议做**。

**验证**：
- 新增 `tb_sd_4bit_init`：模拟卡响应命令序列，断言 ACK/CRC/CMD17 数据回读正确。
- 实板：先 25MHz 跑通读卡，再上 50MHz + 移相采样；示波器量 DAT 采样窗口。

---

## 8. 阶段依赖与验证汇总

| 阶段 | 依赖 | 落地标志 |
|---|---|---|
| 1 键盘+寄存器 | 无 | 键盘切图/OSD/音量可用，`res_mode` 等寄存器可读 |
| 2 文件索引表 | 1 | 数字键选第 N 张图 / `A`+数字选第 N 个音频 |
| 3 分辨率 | 1（2 可选） | `R` 切 320/640/800，画面正确 |
| 4 帧率 | 1（2 可选） | `F` 切档，自动播放按档换图 |
| 5 SD 4-bit | 1~4 绿后 | 25→50MHz，640×480@~28fps |

每阶段收尾统一跑：`python scripts/static_check.py`、`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1`，
并核对 `git diff` 只有计划内改动、top 端口表与 `static_check` 一致。
