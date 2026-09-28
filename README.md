# 安路 EG4S20 HDMI 多媒体播放系统升级工程

## 1. 工程简介

本工程面向安路 EG4S20 系列 FPGA，基于现有 HDMI、TF 卡、外部 SDRAM 和 HDMI 音频参考设计整理而成。工程目标是把固定图像演示程序升级为具备脱机图片播放、双缓存显示、屏幕状态菜单、串口控制、红外控制和测试音频的多媒体播放基础平台。

当前验证基线：

- FPGA：`EG4S20BG256`
- 输入时钟：`50 MHz`
- HDMI：FPGA 直连 TMDS，带 DDC/EDID 读回
- 图片存储：SPI 模式 TF 卡
- 帧缓存：外部 SDRAM，使用 `EG_PHY_SDRAM_2M_32`
- 当前稳定显示模式：`640x480`
- TD 版本：`6.2.168116`
- 仿真工具：ModelSim SE 10.1c

打开工程：

```text
E:\fpga\video_improve.al
```

顶层模块为 `top`，源文件位于 `E:\fpga\rtl\top.v`。

## 2. 已实现功能

### 2.1 HDMI 视频输出

当前主链路使用 640x480 时序和 HDMI 1.4b 发送核：

- 640 个有效像素/行、480 个有效行/帧
- HDMI VIC 设为 1
- RGB 视频流通过 AXI-Stream 风格接口进入 HDMI 发送核
- 首个有效像素产生 `SOF`
- 每行第 640 个有效像素产生 `LAST`
- 场同步变化后重新等待下一帧首像素

### 2.2 TF 卡 BMP 播放

当前读取路径支持：

- Windows BMP
- 24 bit RGB
- 未压缩 `BI_RGB`
- 当前验证尺寸为 `640x480`
- BMP 底部向上的像素排列由帧写入模块完成垂直翻转

启动后系统扫描 TF 卡扇区，最多记录 4 张符合条件的图片。第一张图片写入缓冲区 0，后续通过按键、串口或红外命令切换。

当前实现不是 FAT32 文件系统，也不支持目录解析、长文件名、簇链解析或 JPEG 文件。素材应使用符合上述格式的 BMP 文件。

### 2.3 SDRAM 双缓存和换帧保护

- 显示读取和图片写入通过异步 FIFO 隔离
- 新图片写满后才提出换帧请求
- 换帧请求通过跨时钟域同步
- 只在视频消隐边界更新显示缓冲区
- 换帧完成后返回确认信号
- 换帧期间继续显示旧缓冲区

该机制用于避免正在显示的帧被写入过程覆盖，减少撕裂和半帧显示。

### 2.4 OSD 状态菜单

`rtl/osd/status_osd.v` 提供固定 40 列、4 行的硬件字符叠加，显示区域位于有效画面左上角，内容包括播放状态、图片编号、图片数量、加载状态、EDID 状态、音量、静音状态和操作提示。字符字模由 `rtl/osd/osd_char_rom.v` 提供。

### 2.5 UART 控制

UART 参数为 115200、8N1：

| 参数   | 设置     |
| ---- | ------ |
| 波特率  | 115200 |
| 数据位  | 8      |
| 校验位  | 无      |
| 停止位  | 1      |
| 接收引脚 | `F12`  |
| 发送引脚 | `D12`  |

命令为单个 ASCII 字节：

| 字符  | 功能           |
| --- | ------------ |
| `n` | 下一张图片        |
| `b` | 上一张图片        |
| `p` | 播放/暂停或自动播放切换 |
| `+` | 音量增加，最大 16   |
| `-` | 音量减少，最小 0    |
| `m` | 静音开关         |
| `o` | OSD 开关       |
| `]` | 亮度增加，最大 +64  |
| `[` | 亮度降低，最小 -64  |
| `t` | 测试图开关        |

有效 UART 命令返回 `K`，未知命令返回 `?`。

### 2.6 NEC 红外控制

红外输入引脚为 `D14`，当前映射为：

| NEC 命令码 | 功能     |
| ------- | ------ |
| `0x15`  | 播放/暂停  |
| `0x40`  | 下一张    |
| `0x44`  | 上一张    |
| `0x46`  | 音量增加   |
| `0x16`  | 音量减少   |
| `0x45`  | 静音     |
| `0x47`  | OSD 开关 |

### 2.7 HDMI 测试音频

工程已接入 HDMI 音频数据岛，音频源为硬件 DDS 测试音，不是文件音频解码器：

- 48 kHz 双声道
- 24 bit PCM
- 音量缩放和静音
- HDMI 音频参数 `N=6144`、`CTS=25000`

MP3、AAC、WAV 文件解析以及 TF 卡音频播放目前没有实现。

### 2.8 图像处理和 EDID 扩展

- `video_enhance.v`：逐通道亮度加减和饱和裁剪
- `ycbcr_to_rgb.v`：BT.601 limited-range YCbCr 转 RGB
- `edid_base_check.v`：EDID 头部和 128 字节校验和检查
- `video_mode_table.v`：480p、720p、1080p、800x600 参数表
- `video_scaler.v`：最近邻缩放器

其中模式表、缩放器和 YCbCr 模块是后续扩展接口；当前顶层实际输出仍是 640x480，不会依据 EDID 自动切换 720p/1080p。

## 3. 工程目录

```text
E:\fpga
├── video_improve.al                 TD 主工程
├── README.md                        本说明文件
├── rtl
│   ├── top.v                        当前顶层
│   ├── common                       复位同步和 CDC
│   ├── control                      UART、NEC 和播放控制
│   ├── osd                          字库和状态菜单
│   ├── video                        换帧、亮度、EDID、时序扩展
│   ├── audio                        HDMI 测试音源
│   └── optional                     可选 YCbCr 转换
├── src/user_source                  HDMI、TF、SDRAM、PLL 参考 RTL
├── sim                               ModelSim 测试台
├── scripts                           仿真、综合、布局布线和 bitgen 脚本
├── reports                           综合、时序、资源和 TD 数据库
└── docs                              构建状态说明
```

核心文件：

| 文件                                                       | 作用                                 |
| -------------------------------------------------------- | ---------------------------------- |
| `rtl/top.v`                                              | 顶层时钟、SD、SDRAM、HDMI、UART、红外和 OSD 连接 |
| `rtl/control/player_control.v`                           | 命令解析、音量、静音、OSD、亮度寄存器               |
| `rtl/video/frame_swap.v`                                 | 消隐期双缓存提交                           |
| `rtl/osd/status_osd.v`                                   | 状态菜单叠加                             |
| `src/user_source/hdl_source/SD/sd_card_bmp.v`            | 图片扫描、图片索引和播放控制                     |
| `src/user_source/hdl_source/SD/frame_read_write.v`       | SDRAM 帧读写和 FIFO 隔离                 |
| `src/user_source/hdl_source/hdmi1.4b_transmitter_core/*` | HDMI 1.4b 发送核                      |

## 4. 主要引脚

引脚来自 `src/user_source/constraints_source/pin.adc`。如果开发板版本或接口连接不同，应先修改 ADC 文件，再重新综合和布局布线。

| 信号             | 引脚    | 说明          |
| -------------- | ----- | ----------- |
| `clk`          | `R7`  | 50 MHz 系统时钟 |
| `rst_n`        | `A2`  | 低有效复位       |
| `HDMI_CLK_P`   | `C3`  | TMDS 时钟     |
| `HDMI_D0_P`    | `G5`  | TMDS 数据 0   |
| `HDMI_D1_P`    | `F1`  | TMDS 数据 1   |
| `HDMI_D2_P`    | `E1`  | TMDS 数据 2   |
| `HDMI_DDC_SCL` | `P2`  | HDMI DDC 时钟 |
| `HDMI_DDC_SDA` | `R2`  | HDMI DDC 数据 |
| `sd_dclk`      | `A14` | TF SPI 时钟   |
| `sd_miso`      | `B14` | TF SPI 输入   |
| `sd_mosi`      | `A13` | TF SPI 输出   |
| `sd_ncs`       | `A12` | TF 片选       |
| `uart_rx_pin`  | `F12` | UART 接收     |
| `uart_tx_pin`  | `D12` | UART 发送     |
| `ir_rx_pin`    | `D14` | NEC 红外输入    |

## 5. ModelSim 仿真

默认脚本使用 `J:\win64\vlib.exe`、`vlog.exe` 和 `vsim.exe`。如果安装位置不同，可修改 `scripts\run_tests.ps1` 的 `ModelSim` 参数。

运行全部测试：

```powershell
cd E:\fpga
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\run_tests.ps1
```

成功时最后输出：

```text
ALL TESTS PASSED
```

| 测试台               | 验证内容                           |
| ----------------- | ------------------------------ |
| `tb_uart_rx`      | UART 接收和位序                     |
| `tb_ir_nec_rx`    | NEC 命令、重复码和反码错误                |
| `tb_video_scaler` | 最近邻缩放逐像素比较                     |
| `tb_upgrade`      | 换帧、命令、音量、静音、亮度、OSD、EDID、音频和视频流 |
| `tb_cdc`          | CDC 数据一致性和复位                   |

独立日志保存在 `reports\tb_*.log`。

## 6. TD 综合

图形界面打开：

```text
E:\fpga\video_improve.al
```

命令行综合：

```powershell
cd E:\fpga
J:\Anlogic\td.6.2.1\bin\td_commands_prompt.exe scripts\synth.tcl
```

综合脚本会解析顶层、读取 ADC/SDC、执行 RTL 和 gate 优化，并生成：

- `reports\rtl_area.txt`
- `reports\gate_area.txt`
- `reports\video_improve_gate.db`

## 7. 布局布线和时序

综合成功后执行：

```powershell
cd E:\fpga
J:\Anlogic\td.6.2.1\bin\td_commands_prompt.exe scripts\implement.tcl
```

输出包括 `physical_area.txt`、`timing_status.txt`、`timing_summary.txt` 和 `video_improve_routed.db`。

当前 routed STA 结果为：

```text
SWNS: -6.565 ns
STNS: -295.697 ns
HWNS:  0.019 ns
HTNS:  0.000 ns
```

因此当前布局布线结果用于分析资源、布线和时序风险，不应直接视为满足生产时序要求。

## 8. Bitstream 生成

当前工程不会在负 setup slack 状态下自动生成 bitstream。确认以下条件后再执行：

1. 开发板型号和 HDMI/SDRAM 连接与 ADC 文件一致。
2. SDRAM 时钟、相位和数据回读时序已验证。
3. HDMI 串行时钟和 TMDS 输出约束符合实际接口。
4. `timing_status.txt` 中 setup 和 hold slack 均为正值。
5. 复位极性、TF 卡电平、DDC 上拉和 IO 标准已经确认。

确认后执行：

```powershell
cd E:\fpga
J:\Anlogic\td.6.2.1\bin\td_commands_prompt.exe scripts\bitgen_after_sta.tcl
```

输出文件为 `E:\fpga\reports\video_improve.bit`。

## 9. 上板操作

1. 准备 24 bit、640x480、未压缩 BMP 文件。
2. 将图片写入 TF 卡并插入开发板。
3. 连接 HDMI 显示器和必要的 DDC/上拉电路。
4. 上电，等待 PLL、SD 卡初始化和 BMP 扫描完成。
5. 首次调试建议保持 OSD 打开，观察图片编号、加载状态、EDID 和音量状态。
6. 串口工具选择 115200 8N1，发送单字节命令控制播放。
7. 如果黑屏，先检查 50 MHz 时钟、HDMI TMDS 引脚、DDC 上拉、复位极性和 `video_pll.v`。
8. 如果图片不显示，检查 BMP 格式、TF SPI 连接和外部 SDRAM 初始化。

## 10. 资源使用

资源数据来自 `reports\gate_area.txt`：

| 资源      | 使用量  | 总资源   | 使用率    |
| ------- | ----:| -----:| ------:|
| LUT     | 5287 | 19600 | 26.97% |
| 寄存器     | 3928 | 19600 | 20.04% |
| BRAM9K  | 20   | 64    | 31.25% |
| BRAM32K | 0    | 16    | 0%     |
| DSP     | 0    | 29    | 0%     |
| PLL     | 2    | 4     | 50%    |
| IO      | 35   | 188   | 18.62% |

加入 JPEG 解码、1080p 高带宽链路或文件音频解码前，应重新评估 LUT、BRAM、PLL 和外部存储带宽。

## 11. 当前未完成项

以下方案功能目前没有接入主播放链路：

- 运行时 480p/720p/1080p 自动切换
- 完整 EDID 解析和最佳分辨率选择
- FAT32 根目录和簇链解析
- JPEG 基线硬件解码
- YUV420/YUV422 色度上采样链路
- MP3、AAC、WAV 文件音频解码
- 真实媒体音视频时间戳同步
- 画中画、多窗口和动态裁剪
- 7x24 小时板级热稳定性验证

## 12. 修改和调试顺序

1. 修改 `pin.adc` 或 `rtl/top.v`。
2. 运行 ModelSim 模块测试。
3. 运行 `scripts\synth.tcl`，检查资源和未连接端口警告。
4. 运行 `scripts\implement.tcl`，检查最终时序报告。
5. 确认开发板连接和时序通过后，再运行 `bitgen_after_sta.tcl`。

本 README 描述的是当前 E 盘工程实际状态。工程已经通过模块级仿真、TD 综合和布局布线，但没有替代真实开发板上的 HDMI 显示器兼容性、TF 卡兼容性、SDRAM 长时间运行、红外接收距离和音频播放测试。特别是当前 routed STA 仍有负 setup slack，现有 `.db` 文件不能视为已经完成时序签核的生产 bitstream。
