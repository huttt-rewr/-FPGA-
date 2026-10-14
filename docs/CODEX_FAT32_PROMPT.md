# 提示词：FPGA SD 卡 FAT32 文件系统直读 BMP 与 WAV

> 直接整段复制粘贴给 Codex（或其他 AI 编码助手）即可。

---

## 0. 项目背景与目标

你在维护一个 Anlogic FPGA 的 HDMI 图片/音频播放器工程，路径 `E:\fpga`。

- 板卡：Anlogic EG4S20BG256
- 工具链：TD 6.2.1（`J:/Anlogic/td.6.2.1`），仿真用 ModelSim（`J:/win64`）
- 时钟：主时钟 100MHz；SD SPI 高速分频 `SPI_HIGH_SPEED_DIV=0` → SCK≈25MHz

**当前实现**（要改造的对象）：FPGA 以"原始扇区"方式读 SD 卡——
- 图片：`bmp_read.v` 从扇区 0 顺序扫到 131071，在每个 512 字节边界找 `BM` 魔数，最多找 4 张。
- 音频：`audio_wav.v` 固定从扇区 131072（字节偏移 64MB）开始解析一个 WAV。
- 因此卡必须烧成"裸镜像"（`.img`），不能是普通 Windows 格式化的卡。

**目标**：让 FPGA 自己解析 **FAT32 文件系统**，从而支持"把普通 FAT32 卡插入电脑，直接拷贝 `.bmp` 和 `.wav` 文件进去，FPGA 按文件名/扩展名找到并播放"。**彻底去掉 `.img` 裸镜像和烧卡步骤。**

**本次范围（v1，明确边界）**：
- 只读 FAT32（不做 FAT12/FAT16/exFAT）。
- 只支持 8.3 短文件名（跳过 LFN 长文件名条目，匹配短名）。
- 只读根目录（不进入子目录）。
- 图片：在根目录找 **扩展名为 `.BMP`** 的文件，按目录顺序取最多 4 张。
- 音频：在根目录找 **扩展名为 `.WAV`** 的文件，取第一个。
- 只做顺序读，不做写、不做随机定位（音频已按顺序流式播放，符合）。
- **必须支持碎片化**：文件数据可能不连续，必须沿 FAT 簇链读取（不能假设连续）。

## 1. 现有架构与关键接口（必须遵守，不要改信号名）

### 1.1 扇区读接口（SD 底层，已存在，勿改）
`src/modules/sd/sd_card_sec_read_write.v`（及封装它的 `src/modules/sd/sd_card_top.v`）提供"读一个 512 字节扇区"的接口：
```
input            sd_sec_read            // 请求读一个扇区（拉高一拍）
input  [31:0]    sd_sec_read_addr       // 目标扇区号（LBA）
output [7:0]     sd_sec_read_data       // 该扇区第 N 字节（N 由 data_valid 脉冲计数）
output           sd_sec_read_data_valid // 每个字节有效一拍
output           sd_sec_read_end        // 扇区 512 字节读完
output           sd_init_done           // SD 初始化完成
output           sd_init_error          // 初始化看门狗失败
output           sd_transfer_error
```
读一个扇区的时序约定：拉高 `sd_sec_read` 并给出 `addr`，随后 512 个 `data_valid` 脉冲逐个给出 `data`，最后 `sd_sec_read_end` 拉高一拍结束。**FAT32 模块要复用这套时序。**

### 1.2 扇区仲裁器（已存在，勿改）
`src/modules/sd/sd_read_arbiter.v`，两个客户端：图片（bmp）与音频（aud），音频优先。
```
input  bmp_req, [31:0] bmp_addr;  output [7:0] bmp_data, bmp_valid, bmp_end, bmp_error, bmp_grant
input  aud_req, [31:0] aud_addr;  output [7:0] aud_data, aud_valid, aud_end, aud_error
output sd_req, [31:0] sd_addr;    input [7:0] sd_data, sd_valid, sd_end, sd_error
output transport_reset            // 超时后复位传输
```
它把"图片请求"或"音频请求"转发成对底层 `sd_card_top` 的单次扇区读。

### 1.3 BMP 解析器（改，但只改"找文件"部分，保留头部解析与写帧）
`src/modules/bmp/bmp_read.v`。关键状态机：`ST_IDLE / ST_SCAN / ST_LOAD_HDR / ST_LOAD_WAIT / ST_LOAD_DATA / ST_SCALE`。
- 现状：`ST_SCAN` 顺序扫描 `scan_start_sector`→`scan_max_sector`，输出 `scan_found_valid / scan_found_sector / scan_found_total / scan_done`。
- `ST_LOAD_*` 通过 `load_start / load_abort / load_sector` 加载一张图，做 BMP 头校验（24 位 BI_RGB，DIB 40/108/124）、按行写入 SDRAM、可选 `bmp_scale_loader` 缩放。
- **改造目标**：去掉 `ST_SCAN` 的"扫物理扇区找 BM"逻辑；改为"从 sd_fat32 拿到文件描述符后，直接从该文件第 0 扇区开始做头部解析"。头部解析、写帧、缩放逻辑**全部保留**。

### 1.4 WAV 解析器（改，只改"从哪取字节"）
`src/modules/audio/audio_wav.v`。现状：`START_SECTOR=131072`，`addr = START_SECTOR + cache_tag`（`cache_tag` 是文件内扇区序号）。它已经完整实现 RIFF/FMT/data chunk 解析、PCM/48kHz/16bit/单声道校验、逐样本输出。
- **改造目标**：把 `addr = START_SECTOR + cache_tag` 改为"WAV 文件第 `cache_tag` 个扇区对应的物理扇区（由 sd_fat32 簇链换算）"。RIFF 解析 FSM 全部保留。

### 1.5 顶层集成点
`src/modules/bmp/sd_card_bmp.v` 是 SD/图片/音频的顶层，实例化 `sd_read_arbiter` 和 `audio_wav`，参数 `SCAN_START_SECTOR / SCAN_MAX_SECTOR / SCAN_TARGET_COUNT / ENABLE_AUDIO / AUDIO_START_SECTOR / ENABLE_SCALING / ADAPTIVE`。
`src/top.v` L295-302 实例化 `sd_card_bmp`，参数 `.SCAN_START_SECTOR(0).SCAN_MAX_SECTOR(131071).SCAN_TARGET_COUNT(4).ENABLE_AUDIO(1).AUDIO_START_SECTOR(131072).ENABLE_SCALING(1).ADAPTIVE(1)`。

## 2. FAT32 规范速查（实现者可直接照抄，勿再查资料）

### 2.1 分区定位（支持两种卡布局）
1. 读扇区 0。若字节 `0x1FE..0x1FF == 0x55AA`，且 `0x0B..0x0C == 512` 且 `0x0D`（每簇扇区数）是 2 的幂 → 这是"无 MBR 的 superfloppy"，分区 LBA = 0，直接当 BPB。
2. 否则把它当 MBR：分区表从 `0x1BE` 开始，4 项、每项 16 字节。取第一个"分区类型"为 `0x0B` 或 `0x0C`（FAT32）的项，其偏移 `0x08` 的 4 字节 LE 是**分区起始 LBA**。
3. 读分区起始 LBA 的那个扇区，就是 BPB。

### 2.2 BPB 关键字段（偏移为该字段首字节，均小端）
| 偏移 | 长度 | 含义 |
|---|---|---|
| 0x0B | 2 | 每扇区字节数（必须 512） |
| 0x0D | 1 | 每簇扇区数（spc） |
| 0x0E | 2 | 保留扇区数 |
| 0x10 | 1 | FAT 个数（通常 2） |
| 0x20 | 4 | 总扇区数（FAT32 用这个） |
| 0x24 | 4 | 每个 FAT 的扇区数（FAT_size_32） |
| 0x2C | 4 | 根目录起始簇号（通常 2） |
| 0x1FE | 2 | 签名 0x55AA |

### 2.3 换算公式
```
first_FAT_sector = partition_LBA + reserved_sector_count
first_data_sector = first_FAT_sector + num_FATs * FAT_size_32
cluster_to_sector(c) = first_data_sector + (c - 2) * spc
```

### 2.4 FAT 表项（找下一簇）
簇号 `c` 的 FAT 项位于字节偏移 `first_FAT_sector*512 + c*4`，读 4 字节 LE 后 `& 0x0FFFFFFF`：
- `>= 0x0FFFFFF8`：链尾（EOF）
- `== 0x0FFFFFF7`：坏簇
- 其他：下一个簇号

### 2.5 目录项（32 字节/项，位于根目录簇链内）
| 偏移 | 长度 | 含义 |
|---|---|---|
| 0x00 | 8 | 短文件名（空格补齐）；首字节 `0xE5`=已删除、`0x00`=表结束 |
| 0x08 | 3 | 扩展名 |
| 0x0B | 1 | 属性（`0x0F`=LFN 项，跳过；`0x10`=目录；`0x08`=卷标） |
| 0x14 | 2 | 首簇高 16 位 |
| 0x1A | 2 | 首簇低 16 位 |
| 0x1C | 4 | 文件大小（字节） |

首簇号 = `(高16 << 16) | 低16`。**匹配规则**：跳过属性含 `0x0F` 的 LFN 项和卷标/目录项；对普通文件，比较 `ext[0..2]` 是否等于 `BMP` 或 `WAV`（`BMP`=0x42 0x4D 0x50，`WAV`=0x57 0x41 0x56），大小写不敏感（Windows 生成的短名通常大写，比较时把字节与 0xDF 相与即可忽略大小写）。遍历根目录簇链直到遇到首字节 `0x00` 的表结束项。

## 3. 新增模块 `sd_fat32.v`（核心）

位置：`src/modules/sd/sd_fat32.v`。定位为**"扇区重映射 + 文件枚举"中间层**，夹在"解析器"与"`sd_read_arbiter`"之间。建议端口如下（内部实现可自行细化，但对外行为必须一致）：

```verilog
module sd_fat32 #(
    parameter MAX_BMP = 4
)(
    input clk, rst, sd_init_done,
    // ---- 枚举结果（给 sd_card_bmp 调度用）----
    output reg        mount_done,
    output reg        mount_error,
    output reg [2:0]  bmp_count,          // 找到的 .BMP 数量（<=MAX_BMP）
    output reg        wav_found,
    output reg [31:0] bmp_size   [0:MAX_BMP-1],  // 每张图字节数
    output reg [31:0] wav_size,
    // ---- 图片虚拟扇区读口（面向 bmp_read.v）----
    input             bmp_req,            // 读请求
    input  [2:0]      bmp_file_idx,       // 第几张图（0..bmp_count-1）
    input  [31:0]     bmp_rel_sector,     // 该文件内第几扇区
    output [7:0]      bmp_data,
    output            bmp_valid, bmp_end, bmp_error, bmp_grant,
    // ---- 音频虚拟扇区读口（面向 audio_wav.v）----
    input             aud_req,
    input  [31:0]     aud_rel_sector,
    output [7:0]      aud_data,
    output            aud_valid, aud_end, aud_error,
    // ---- 物理扇区读口（连到 sd_read_arbiter 的 bmp/aud 两个口）----
    output            arb_bmp_req, [31:0] arb_bmp_addr,
    input [7:0]       arb_bmp_data, arb_bmp_valid, arb_bmp_end, arb_bmp_error, arb_bmp_grant,
    output            arb_aud_req, [31:0] arb_aud_addr,
    input [7:0]       arb_aud_data, arb_aud_valid, arb_aud_end, arb_aud_error
);
```

**职责与工作流**：
1. **挂载/枚举阶段**（`sd_init_done` 后自动开始）：借道仲裁器的 bmp 通道，依次读扇区 0 → 定位 BPB → 读 BPB → 遍历根目录簇链 → 填 `bmp_size[]`/`wav_size`、记录每个文件的首簇号、置 `mount_done`。任何一步校验失败（签名错、spc 非法、找不到 FAT32）→ `mount_error`。
2. **流式读阶段**（`mount_done` 后）：当 `bmp_req` 拉高，把 `bmp_rel_sector` 沿对应文件的簇链换算成物理扇区，向仲裁器发起物理读，把 `arb_bmp_data/valid/end/error` 透传给 `bmp_data/valid/end/error`。音频同理。
3. **簇链状态机**：为每个流维护 `(当前簇号, 簇内剩余扇区数, 已读字节)`。当跨簇时读 FAT 项找下一簇；为省 SPI 带宽，缓存当前 FAT 扇区（512B=128 项），顺序读时不重复读 FAT。

**风格要求**：与工程现有代码一致——状态机用**独热编码**，比较/边界运算**提前一拍寄存**，避免 100MHz 长组合路径；注释用中文；所有参数化常量放在 `#(parameter ...)`。

## 4. 逐文件集成改动

1. **新增** `src/modules/sd/sd_fat32.v`（见上）。
2. **改** `src/modules/bmp/bmp_read.v`：
   - 删除 `ST_SCAN` 的物理扇区扫描与 `scan_found_sector` 语义；`scan_done` 改由 `sd_fat32.mount_done` 驱动，`scan_found_total` 改为 `bmp_count`。
   - 加载一张图时不再用 `load_sector`（物理扇区），改为"文件内扇区 0 起"，通过 `bmp_file_idx` + `bmp_rel_sector` 走 `sd_fat32` 虚拟口。
   - 头部解析（`ST_LOAD_HDR`）与写帧/缩放（`ST_LOAD_DATA`/`ST_SCALE`）**保持原逻辑不动**。
3. **改** `src/modules/audio/audio_wav.v`：
   - 去掉 `START_SECTOR` 依赖；`addr` 由 `sd_fat32` 的 `aud_rel_sector` 重映射得到（即把 `cache_tag` 作为 `aud_rel_sector` 喂给 sd_fat32）。
   - RIFF/FMT/data 解析与样本输出 FSM 不动。
4. **改** `src/modules/bmp/sd_card_bmp.v`：
   - 实例化 `sd_fat32`，把它夹在 `bmp_read`/`audio_wav` 与 `sd_read_arbiter` 之间。
   - 原 `SCAN_START_SECTOR/SCAN_MAX_SECTOR/AUDIO_START_SECTOR` 参数保留但不再参与地址计算（可保留为默认值以免动 top 端口），新增 `MAX_BMP` 等参数透传。
5. **改** `src/top.v` L295-302：移除/注释 `.AUDIO_START_SECTOR(32'd131072)` 等裸扇区参数的实际语义（保留端口避免 `static_check` 报错），其余不变。
6. **登记新文件**：把 `sd_fat32.v` 加进 `scripts/design_files.txt` 和 `scripts/static_check.py` 的源文件清单，保证静态检查与综合能发现它。

## 5. 文件命名约定（写进文档，用户照做即可）
- 图片：任意文件名 + `.bmp`（如 `1.bmp`、`pic2.bmp`），根目录最多 4 张，按目录顺序显示。
- 音频：任意文件名 + `.wav`，根目录取第一个。
- 格式要求不变：BMP 必须 24 位 BI_RGB（DIB 40/108/124）；WAV 必须 PCM/48kHz/16bit/单声道。

## 6. 验证（每一阶段都要可独立验证）

1. **新增** `scripts/make_fat32_image.py`：纯 Python 生成一个**最小合法 FAT32 镜像文件**（手写 BPB + 2 个 FAT + 根目录簇链，含 2~4 个 `.BMP` 目录项和一个 `.WAV` 目录项，数据簇可故意**打乱顺序制造碎片**），输出 `.img` 供 testbench 当"卡内容"加载。附 `verify` 子命令自检（重新解析并打印每个文件的首簇/大小/簇链）。**这是仿真能否跑通的关键，必须与 Verilog 的解析逻辑互相对照。**
2. **新增** `sim/tb_fat32_mount.v`：用一个行为级 SD 模型把 `make_fat32_image.py` 生成的镜像按扇区喂给 `sd_fat32`，断言 `mount_done` 拉高、`bmp_count`/`wav_found`/文件大小正确、碎片化镜像也能正确枚举。
3. **新增** `sim/tb_fat32_stream.v`：对"故意碎片化"的文件做流式读，断言读出的字节序列 == Python 侧记录的原始文件字节。
4. **回归**：把新 testbench 加进 `scripts/run_tests.ps1` 的 `$files` 列表与 `foreach($tb ...)` 循环；跑全量回归必须全 PASS（重点确认 `tb_bmp_stream`、`tb_audio_fifo`、`tb_audio_playback`、`tb_board_pipeline` 这些原有 BMP/音频测试在改动后仍通过）。
5. **静态与综合**：`python scripts/static_check.py` 必须 `ALL PASS`；有 TD 则 `python scripts/run_build.py` 综合/布局布线/STA 全绿。

## 7. 明确禁止与硬约束
- **不要**实现 FAT12/FAT16/exFAT、长文件名、子目录、文件写、随机定位。
- **不要**改 `sd_card_sec_read_write.v` / `sd_card_top.v` / `sd_read_arbiter.v` 的接口与行为（SD 初始化、SPI、仲裁、看门狗都已是稳定模块）。
- **不要**删除或重写 BMP 头解析、缩放、写帧、WAV RIFF 解析这些已验证逻辑，只替换"从哪找到文件、从哪读字节"这一层。
- 保持工程风格：独热状态机、中文注释、参数化、`static_check` 端口一致性。
- 所有新增代码都要能通过 ModelSim 仿真验证，不允许只写不验。
