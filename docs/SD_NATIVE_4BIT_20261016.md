# 原生四位SD与CMD6高速实现

正式顶层已启用四位原生SD，并按卡能力自动协商25/50MHz。详细验证数字以[构建状态](BUILD_STATUS.md)及[本次冻结报告](../reports/keyboard_20261016/RESULT_native50_ultra.md)为准。旧SPI保留作兼容仿真profile，正式top不走SPI，也没有运行时回退SPI。

## 接线与电气依据

仍插板上原TF/microSD卡座，不增加外设。以下是FPGA焊球坐标，不是外接排针序号。

| 信号 | microSD接点 | FPGA焊球 | 方向 |
|---|---:|---|---|
| SD_CLK | 5 | A14 | FPGA输出 |
| SD_CMD | 3 | A13 | 双向，主机发送与卡响应分时 |
| SD_DAT0 | 7 | B14 | 双向端口，本只读实现始终释放DAT |
| SD_DAT1 | 8 | B15 | 同上 |
| SD_DAT2 | 1 | A11 | 同上 |
| SD_DAT3 | 2 | A12 | 同上，原SPI片选脚 |

依据J:/HX4S20开发板手册-HDL版2410.pdf第20页图2-22，RN18/RN19为10kΩ上拉到3.3V，连接CMD与DAT0～3。[图面证据](../reports/keyboard_20261016/board_tf_page20.png)、[引脚文字](../reports/keyboard_20261016/board_pin_evidence.txt)。实物版本和装配仍需确认。CMD初始化阶段开漏，退出识别后推挽发送，收响应时关闭OE；读实现从不驱动DAT。

## 传输过程

1. 默认100MHz主控分频，200kHz识别阶段提供80个启动时钟。
2. CMD0 → CMD8 → CMD55/ACMD41循环 → CMD2 → CMD3取得RCA → CMD7并等待DAT0解除busy → CMD55/ACMD6(2) → CMD16(512)。OCR的CCS决定地址单位。
3. 进入四位25MHz。正式profile发CMD6(0x00FFFFF1)查询High Speed支持与busy；确认支持且空闲才发CMD6(0x80FFFFF1)切换。
4. 两次CMD6都接收64字节状态和四路CRC16。字节13的bit1表示支持，字节16低4位为选中功能，字节29的bit1为busy。只有切换后选中1、非busy且CRC/结束位正确才等待八个SD时钟后升50MHz。未知结果重新初始化，不能直接假定卡仍处于旧模式。
5. CMD17读单扇区；SDHC参数为LBA，SDSC参数为LBA左移9位，溢出报错。512字节由1024个四位数据拍接收，四条线分别计算CRC16。未实现CMD18/CMD12多块优化。

这里是3.3V **High Speed、50MHz、单沿SDR**，不执行CMD11/1.8V切换，不是UHS-I SDR50或DDR50。理论数据阶段25MHz为12.5MB/s，50MHz为25MB/s；实际还包括命令、响应、CRC和卡等待。

命令CRC7多项式0x09；数据CRC16为0x1021。48位R1/R6/R7校验头、结束位和CRC，136位R2对CID/CSD内容120位校验，R3保留CRC不作有效判断。错响应、起止标志、CRC或超时均走错误恢复。

## 上层接口保持

sd_card_top保留原扇区请求、地址、逐字节valid、成功end及init/error握手；物理侧为六线原生接口。数据字节在CRC最终判定前输出，只有CRC与结束位全部正确才产生sd_sec_read_end；失败产生sd_transfer_error，不能把已收到的字节当作成功扇区。响应损坏时排空仍在发送的数据或等待超时，再处理下一请求。只读不写卡，写请求报错而不假报写成功。

FAT32、仲裁、BMP解析、WAV解析、缩放五个模块相对阶段四保持零差异。sd_card_bmp仅透传物理接口/构建参数和等价优化索引计算。两个TD入口与design_files使用同一正式源清单，必要官方IP保留。

## 源文件与激励

| 文件 | 作用 |
|---|---|
| [sd_bus_phy.v](../src/modules/sd/native/sd_bus_phy.v) | 100MHz单域分频、CMD OE、命令/响应、64/512字节接收、CRC及超时；25MHz在名义上升沿采样，50MHz采样许可延后一拍100MHz |
| [sd_native_controller.v](../src/modules/sd/native/sd_native_controller.v) | 初始化、RCA/CCS、CMD6查询切换、CMD17、错误重试与去重 |
| [sd_card_top_native.v](../src/modules/sd/native/sd_card_top_native.v) | PHY与控制器封装；ENABLE_HIGH_SPEED为构建参数 |
| [sd_native_card_model.v](../sim/sd_native_card_model.v) | 引脚级逻辑卡模型、独立CRC、FAT32镜像、可配置输出延迟 |
| [tb_sd_native.v](../sim/tb_sd_native.v) | SDHC/SDSC、四线CRC、错响应/起止、超时恢复、吞吐和请求去重 |
| [tb_sd_native_clock.v](../sim/tb_sd_native_clock.v) | 真实200kHz初始化、80启动时钟与25MHz完整周期切换 |
| [tb_sd_native_fat32.v](../sim/tb_sd_native_fat32.v) | 真实FAT32/仲裁、碎片BMP/WAV逐字节校验 |
| [tb_sd_native_integrated.v](../sim/tb_sd_native_integrated.v) | 正式原生25MHzprofile，经物理引脚到FAT/BMP/缩放/WAV，无force替换 |
| [tb_sd_highspeed.v](../sim/tb_sd_highspeed.v) | CMD6支持/不支持/busy/拒绝、查询和切换CRC/响应/无数据超时、恢复25、50MHz周期及吞吐 |
| [tb_sd_highspeed_player.v](../sim/tb_sd_highspeed_player.v) | 14ns输出延迟卡模型，经正式50MHzprofile校验两帧图片像素与PCM循环 |

完整ModelSim回归含以上测试：

```powershell
cd E:\fpga
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
```

不要同时运行共享sim/msim_work的仿真。旧25MHz专项可运行scripts/run_sd_native_tests.ps1，其独立库为sim/sd_native_work。逻辑模型测得25MHz约11.20MB/s、50MHz约22.34MB/s；这些不是实体卡或整机图片FPS。

## 实板仍要验证什么

本次80项回归、综合/P&R/内部STA通过，SWNS +0.026ns、HWNS +0.022ns，TNS0。时序报告不含已签核的SD卡输出延迟/PCB往返预算，0/6/14ns模型测试也不能代替板级STA。50MHz采样许可使用100MHz域的一拍延迟，没有照搬SDRAM移相或增加PLL。

实板应先用NATIVE_HIGH_SPEED=0单独构建确认四位25MHz，再测默认自动协商50MHz；更换参数后必须重新回归/构建，不能沿用本页冻结哈希。测CMD/DAT波形、连续扇区总字节/总时间，检查CRC错误和长时间图像/音频播放；本轮没有执行物理下载或卡写入。内部removal不是HDMI管脚hold，也没有整体+0.5ns声明。
