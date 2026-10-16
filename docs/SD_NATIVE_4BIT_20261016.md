# 原生四位 SD 候选与板级接入缺口（2026-10-16）

**当前还没有把正式板级工程切换为四位 SD。** 原生控制器已完成逻辑仿真和独立综合；正式 `top.v`、`sd_card_top.v`、管脚约束和两个 TD 工程入口仍保留 SPI。原因是现有资料没有给出板载 TF 卡 DAT1、DAT2 的 FPGA 管脚和上拉电路，不能猜测或任由 TD 自动分配管脚后当作可下载工程。

## 硬件资料核对

本轮检查了 `J:/lab_ex4_tf`、`J:/lab_ex5_i2s`、`J:/DEMO` 中的源与约束，并检查 `J:/6_EG4S20数据手册` 的文件清单和此前资料审查记录。官方 `J:/DEMO/18_sd_card_audio/sd_card_audido.adc`、lab4/lab5 与正式工程一致，只能确认下表四条 SPI 信号对应的原生 SD 用途。

| 原生信号 | microSD 接点 | 原有信号 | 有依据的 FPGA 焊球 |
|---|---:|---|---|
| SD_CLK | 5 | sd_dclk | A14 |
| SD_CMD | 3 | sd_mosi | A13 |
| SD_DAT0 | 7 | sd_miso | B14 |
| SD_DAT3 | 2 | sd_ncs | A12 |
| SD_DAT1 | 8 | 无 | **未知，不能分配** |
| SD_DAT2 | 1 | 无 | **未知，不能分配** |

未找到 DAT1/DAT2 映射不等于证明板子没有接线。芯片的封装引脚表也不能证明 TF 卡座的 PCB 走线。需要本板整板原理图对应页，或断电通断测量得到 DAT1/DAT2 的实际 FPGA 焊球；同时核对 CMD、DAT0～3 的外部 10～100kΩ 上拉和供电。内部 `PULLUP` 约束不能证明板上已经装了规定阻值的电阻。不要仅因 FPGA 有空闲 PAD 就任选两个 PAD。

## 本轮新增源码

| 文件 | 职责 |
|---|---|
| [sd_bus_phy.v](../src/modules/sd/native/sd_bus_phy.v) | 100MHz 单时钟 PHY，SD 时钟分频，CMD OE/开漏识别阶段，48位命令发送、48/136位响应接收、CRC7、四条 DAT 的 CRC16、逐字节输出及超时 |
| [sd_native_controller.v](../src/modules/sd/native/sd_native_controller.v) | 原生初始化、RCA/CCS、CMD17 单扇区读取、初始化超时/次数限制/暂停重试、读错恢复、请求去重 |
| [sd_card_top_native.v](../src/modules/sd/native/sd_card_top_native.v) | 独立候选封装，扇区侧保留原端口名称和位宽，物理侧为六根 SD 信号 |

这些文件位于独立 `native/` 子目录，**没有登记到正式 `design_files.txt` 和两个 `video_improve.al` 中**，当前正式工程仍为63设计源、36位逻辑IO。可用独立 TD 综合脚本检查候选：`scripts/synth_sd_native.tcl`。独立候选综合中的扇区请求/数据端口是测试顶层 IO，报告里的57个 IO不是最终板级 IO 数量。

指定不可修改的 `sd_read_arbiter.v`、`sd_fat32.v`、`bmp_read.v`、`audio_wav.v`、`bmp_scale_loader.v` 均未修改；本轮也未修改 `sd_card_bmp.v`、PLL、正式 SDC、官方 IP 和 KEY/SW 控制。

## 协议和性能

正式默认输入为100MHz。初始化默认 `SPI_LOW_SPEED_DIV=248`，半周期250拍，SD_CLK 为200kHz；先提供80个时钟，再发送命令。这是 SD 上电识别所需的低速阶段，不能把25MHz运行目标直接用于上电初始化。

初始化序列为：CMD0 → CMD8 → CMD55/ACMD41 循环 → CMD2 → CMD3 → CMD7 → CMD55/ACMD6(2) → CMD16(512)。CMD3 获得 RCA 后退出主机 CMD 开漏发送阶段；CMD7 使用 R1b，并等待 DAT0 busy 解除。ACMD41 返回 R3/OCR，不能按 R1 状态解释。OCR bit31 表示就绪、bit30 表示 CCS。

初始化成功后，PHY 在完整时钟周期边界切到100MHz/4=25MHz，数据四线并行接收，无 SPI 回退。相邻命令保留 SD 规范要求的至少8个时钟 Ncc 间隔；正常读卡没有软件等待计数或人为暂停。

SDHC 使用扇区 LBA；SDSC 使用 LBA 左移9位的字节地址，超出32位可表示范围时直接报错。单扇区采用 CMD17；本轮未实现 CMD18/CMD12 多块优化。

CRC7 多项式为0x09，主机发送完整命令 CRC；R1/R6/R7 校验响应头、结束位和 CRC，R2 校验 CID 的120位内容 CRC，R3 的 CRC 字段为保留值，不作有效 CRC 判定。每个数据块由全零起始、1024个四位数据拍、四路独立16位 CRC、全一结束组成；任何一条数据线 CRC 不匹配、起止标志错误或超时均报读错。

与原 SPI 版相同，字节输出在 CRC 最终判定之前产生，属于待提交数据；只有 CRC/结束位全部正确才发出 `sd_sec_read_end`。失败发出 `sd_transfer_error`，不会报成功。原有上层已按该事务约定处理错误，本轮不改图像/音频逻辑。

响应损坏时，卡仍可能继续发送512字节。候选不会立即启动下一条命令，而是让接收机排空或到期，再接收后续请求；这段错误恢复时间不能算作正常无故障吞吐。扇区请求保持为高时只处理一次，撤销后下一笔请求可继续。写侧端口仅保留兼容位置：候选只读，不支持写卡，写请求报 `sd_transfer_error`，不发写成功握手。

逻辑卡模型的连续16扇区测试：8192字节/73113个100MHz周期，**11.204574 MB/s**，计入 CMD17 命令、响应、数据、CRC、结束及请求握手。理论数据线原始带宽12.5MB/s。这是理想模型的接口级仿真结果，**不是实体卡实测**，也不能保证任意卡、任意随机读取和上层文件访问均达到10MB/s。

## 如何运行 ModelSim 验证

在 `E:/fpga` 的 PowerShell 中运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_sd_native_tests.ps1
```

脚本自动生成 FAT32 夹具，使用独立 `sim/sd_native_work`，日志保存到 `reports/sd_native_20261016`。激励已经登记到全量 `scripts/run_tests.ps1` 的编译文件和测试循环，原有测试没有删除或放宽。

| 激励文件 | 验证内容 |
|---|---|
| [sd_native_card_model.v](../sim/sd_native_card_model.v) | 仅经 CMD/DAT 引脚交互的逻辑卡；独立多项式除法生成 CRC；可从真实 FAT32 夹具镜像按 LBA 读数据 |
| [tb_sd_native.v](../sim/tb_sd_native.v) | SDHC/SDSC、R7错、响应CRC错、四条数据CRC逐条错、起止标志、无响应/数据、R1错误、R1b busy超时、ACMD41次数限制、R2/R6错误及恢复；连续吞吐、请求保持去重 |
| [tb_sd_native_clock.v](../sim/tb_sd_native_clock.v) | 真实默认分频：200kHz初始化、至少80个启动时钟、CMD识别阶段释放高电平、切换后25MHz |
| [tb_sd_native_fat32.v](../sim/tb_sd_native_fat32.v) | 原生物理引脚→真实仲裁器→原有 FAT32；MBR/无分区、碎片 BMP/WAV 文件逐字节核对 |
| [tb_sd_native_player.v](../sim/tb_sd_native_player.v) | 保留真实播放器、缩放、FAT32、WAV模块，只把测试中的物理扇区源替换成原生控制器；两帧像素、PCM循环和提交确认核对 |

最后一项在测试中用 `force` 替换原 SPI 输出与播放器的连接；它验证上层在四位传输的节奏下工作，不等于正式顶层已经接入原生控制器。逻辑卡模型不覆盖实体卡输出延迟、PCB信号完整性、上拉电阻、IO电压或热插拔。

## 验证结论与下一步

本轮日志与冻结哈希见 [交付记录](../reports/sd_native_20261016/RESULT.md)。正式整机 `run_build.py` 的结果属于当前仍用 SPI 的板级工程；独立原生综合成功也不能替代原生接入后的布局布线/STA。

最终全量回归65/65通过，静态63源/36IO通过；正式SPI工程重建SWNS +0.034ns、HWNS +0.021ns、TNS均0。当前状态仍是“候选已验证、板级切换待接线依据”，不是本任务全部硬件验收完成。

接线确认后，剩余实施顺序为：

1. 将 `sd_card_top_native` 的原生实现替换进正式 `sd_card_top`，原物理层保存在备份中；只改 `sd_card_bmp` 的物理端口透传和 `top.v` 六根 SD 接线。
2. 按真实焊球更新 `pin.adc`，CMD/DAT 设为双向并核对三态/OE；同步两个 TD 工程和源清单，不新增无依据的延迟数值。
3. 为正式接入后的物理链路完成25MHz SD输出/输入的板级时序预算和约束，依据卡时序与PCB走线核实采样相位；100MHz内部STA通过不代表SD外部时序已签核。
4. 重新运行全部回归、整机综合/布局布线/STA。现有初始化/错误看门狗、FAT32/BMP/WAV保持原逻辑。
5. 用真实卡上板计数多扇区总字节和总周期，核对实际≥10MB/s，再验证静态图、换图和WAV播放。当前没有执行烧录、实体卡读写或实板测量。

未解决硬件依据前，本轮不会生成号称“四位SD可上板”的bit，也不会将内部复位 removal 当作HDMI管脚hold或宣称达到+0.5ns。
