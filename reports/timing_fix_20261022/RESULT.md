# 2026-10-22 内部 hold 修复结果

## 最终状态

完整构建完成于 2026-10-22 22:25:08（北京时间，manifest finished_utc 为 2026-10-22T14:25:08.410193+00:00）。综合、布局布线、独立 hold 收尾及内部 STA 通过。构建输入 708 项与当前快照完全匹配，工程 .al 按 run_build.py 的 XML 归一化规则比较。

| 指标 | 本轮修改前 | 最终 |
| --- | ---: | ---: |
| SWNS | +0.136 ns | +0.188 ns |
| STNS | 0.000 ns | 0.000 ns |
| HWNS | -0.020 ns | +0.022 ns |
| HTNS | -0.020 ns | 0.000 ns |

STA coverage 为 99.89%，Slow/Fast 两角均检查。以上是已分析约束下的内部 STA 结果，不是整板签核，也没有达到 +0.5 ns。

## 原因与修复

1. FAT32 的 fat_word 寄存器到 fat_cache BRAM 数据口原有 -0.020 ns 短路径 hold 违例。在 sd_fat32.v 中将缓存低 24 位按固定掩码编码，写入前取反、同步 RAM 输出后解码。保留 BRAM 推断、读写周期与握手，通过 preserve/keep 保留实际组合延迟。
2. FAT32 修复后的下一处限制为 audio_async_fifo 写 Gray 指针到第一级同步器，hold 为 -0.012 ns。在 audio_async_fifo.v 中将发送 Gray 指针寄存为取反编码，跨域前还原；保留 Gray 单比特转换、双级同步结构、满空判断与指针周期。最终完整构建与路由消除了剩余负 slack。

本轮有效 RTL 改动仅上述两个文件，其它先前修改保留。没有删除功能或新增 BRAM/DSP，没有降低主控 100 MHz，没有放宽约束，没有修改官方 IP。

## 最差路径的真实类型

- 最差 setup +0.188 ns：frame_read_write_m0/read_buf/wr_to_rd_cross_inst 的 Gray 地址指针到 sync_r1，40 MHz 到 vga_pixel 25 MHz；见 timing_summary.txt 约 21036 行。
- 全局 HWNS +0.022 ns 的限制路径为 rst_fat 到 filesystem$fat/fat_capacity_bad 的内部复位 removal；见 timing_summary.txt 约 853 行。HWNS 在这里是报告汇总 min-check 指标，不能称为 HDMI 输出管脚 hold。
- 主控仍为 100 MHz；VGA/SVGA pixel 25/40 MHz 与 serial 125/200 MHz 都在最终 STA 报告出现。

## 资源与验证

| 资源 | 用量/容量 | 使用率 | 项目门限 |
| --- | ---: | ---: | ---: |
| LUT | 17036/19600 | 86.92% | 18620，通过，余 1584 |
| REG | 11449/19600 | 58.41% | 无额外门限 |
| BRAM | 54/64 | 84.38% | 64，通过 |
| DSP | 23/29 | 79.31% | 29，通过 |
| PLL | 2/4 | 50.00% | 无额外门限 |
| GCLK | 4/16 | 25.00% | 无额外门限 |

- static_check：ALL PASS，93 sources、40 IO bits。
- 最终 ModelSim 主回归 111 项 ALL PASS，AVF 专项 17 场景 ALL PASS，包括 HQ 与故障参数场景。
- 主回归含 tb_audio_fifo、FAT32 mount/stream/player/compare/schedule、tb_sd_highspeed_player 和 HDMI 等现有行为检查。
- 回归脚本与日志位于 ../timing_opt_20261022/：run_regression.py、main/*.log、avf/*.log、regression_summary.json。
- 构建证据为 ../build_manifest.json、../physical_area.txt、../timing_summary.txt、../routed_timing_paths20.txt。
- 本轮没有生成新 bit，没有实板下载、实体卡吞吐测试或外部 HDMI/SD IO 签核。逻辑仿真不能代替实板验收。

## 剩余事项

implementation_warnings 仍有 PHY-7002 两条（SDRAM 固定位置未被采纳）及 PHY-5079 一条（1 根时钟使用局部布线）；独立 hold 收尾再次报告同类 PHY-5079，没有宣称警告已清除。

board_signoff=false，hold_margin_0_5ns_met=false。最小裕量仅 22 ps，重新修改或实现后必须重新验证。内部复位 removal 不是 HDMI 管脚 hold，整体 +0.5 ns 未达标。

## 备份与弃用试验

baseline/ 保存修改前的两份 RTL 与报告。fat_only_candidate/ 是仅修改 FAT32 后仍有 FIFO -0.012 ns 的中间结果。rejected_inline_decode/ 是把解码 XOR 放进同步 RAM 读赋值导致 RAM 推断失败的弃用试验，该写法未保留。独立物理 fix_hold/multi_try_route 试验没有单独消除违例，其报告不可用于验收当前源码。

约束 SHA-256 与本轮前一致：

- src/constraints/timing.sdc: 8e3480d0a0c1792ace9e3ed817ea21123f652e739e3c09402966ec6f247e2b1b
- src/constraints/pin.adc: 1400e36147a2aeba2d8def00320d5d6ff0f6bbb72f1aa28636e885065bdcb109
- scripts/adaptive_mode_clocks.sdc: 44690bb8b2d61e18eb271ca47d42f3c26a360f3dc78d983c1f2eb95f60b5fd64
