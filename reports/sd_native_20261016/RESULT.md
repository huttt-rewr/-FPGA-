# 四位 SD 候选交付状态

2026-10-16：原生四位SD逻辑候选已完成，**正式板级工程尚未切换**，DAT1/DAT2焊球和CMD/DAT上拉依据缺失。详见 [设计和接入说明](../../docs/SD_NATIVE_4BIT_20261016.md)。

- 已备份：`backups/sd_native_20261016/before.zip`，源哈希：`baseline_sha256.json`。
- 四项新增 ModelSim 协议、时钟、FAT32、播放器测试全部通过：`native_final.log`。
- 连续16扇区模型吞吐11.204574 MB/s；仅逻辑仿真，尚无实板吞吐数据。
- 最终独立 TD 综合通过：`native_synthesis.log`，1074 LUT、577 REG，BRAM/DSP均0；未进行原生板级P&R/STA。
- 正式工程静态检查通过：63设计源、36位IO，仍为原SPI管脚。
- SPI正式工程重建已完成：SWNS **+0.034ns**、STNS 0，HWNS **+0.021ns**、HTNS 0。仍为原SPI设计，不能用作原生四位SD时序证明；未达到+0.5ns，内部removal不能当HDMI管脚hold。
- 全量 **65/65 ModelSim 回归通过**（原61项加四项原生SD测试），包含原 `tb_fat32_mount/stream/player`；控制台 `regression.log`，逐项冻结日志 `regression/`。
- 保护的五个上层文件保持不变；未动官方IP、PLL/SDC、正式TD清单/管脚或KEY/SW。

四位接入后的布局布线、板级时序、实体卡出图出声及≥10MB/s实测均未完成，不能用本轮SPI重建或候选独立综合冒充。

提交：`6e65ead`（原生候选与测试）。独立综合仍报告 `SYN-5025: Using 0 for all undriven pins and nets`，日志未给出对象名；本轮没有将其称为零告警综合，也没有据此声称IO电气签核。

最终核验见 [validation.json](validation.json)；[audit_delivery.py](audit_delivery.py) 已成功执行：五个保护文件、正式顶层/SD栈/约束/两个TD工程/清单和全部官方IP的SHA-256与任务开始前一致，构建输入哈希与当前源逐项相符。

SPI整机证据冻结在 `spi_board_build/`，资源LUT15019、REG10052、BRAM9K59/64、DSP17、PLL2。本次未生成bit。原生候选日志及资源独立保存，不能混同这两个设计。

尚未完成的硬性验收：Phase 1正式六线接线与约束、Phase 2～4候选替换进正式SD栈、Phase 6原生整机综合/P&R/STA和实体卡吞吐/出图/出声。缺口是TF卡DAT1/DAT2实际焊球与CMD/DAT上拉证据；现有资料只能确认CLK=A14、CMD=A13、DAT0=B14、DAT3=A12，原文及哈希见 [pin_evidence.json](pin_evidence.json)。确认接线后才能完成这些步骤。
