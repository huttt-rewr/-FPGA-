# 文档阅读入口

音频最新修复：一秒延时重试、E1～E4错误码及U欠载历史；KEY/SW映射不变。见[恢复操作说明](AUDIO_RETRY_20261014.md)和[当前候选](BUILD_STATUS.md)。

2026-10-14 WAV增量：TF卡48kHz/16bit/单声道PCM经现有HDMI_B音频口输出，默认静音；KEY3长按菜单新增AUDIO MUTE、VOLUME DOWN、VOLUME UP，KEY/SW原功能保留。 首先看[WAV音频手册](WAV_AUDIO_20261014.md)。当前61设计源、36IO；候选、回归与STA见[构建状态](BUILD_STATUS.md)。下面早先板载日期记录对应历史版本。

**2026-10-14板载优化：** [菜单、伽马、诊断、看门狗与时序优化](BOARD_OPTIMIZATION_20261014.md)；[KEY/SW逐步操作](KEY_SW_OPERATION.md)；[在线观测清单](ONLINE_DEBUG_20261014.md)；[显示器参数表](MONITOR_COMPATIBILITY.md)；[上板演示步骤](BOARD_DEMO_20261014.md)；[硬件设计说明骨架](HARDWARE_DESIGN_OUTLINE.md)。仅使用现有KEY/SW控制，音频与新外设暂缓。该历史版57个设计源、36位IO；真实回归、STA及候选以[构建状态](BUILD_STATUS.md)为准。下述旧日期为历史记录。

**2026-10-13 静止图片白条与撕裂排查：** [修复原因、ModelSim验证、上板判别](DISPLAY_REPAIR_20261013.md)。当前回归、布局布线与候选文件生成状态以[构建状态](BUILD_STATUS.md)为准；下述10月11日结果属于历史版本。

**按键/拨码逐步操作：[KEY与SW详细操作教程](KEY_SW_OPERATION.md)**。不懂PLAY、BRIG、CONT或不知道该按哪一个键，先看这份。

**当前新增功能：[缩放与亮度/对比度详细手册](SCALING_AND_PICTURE_CONTROLS_20261010.md)；[不同分辨率测试素材与脚本](../assets/multires_20261010/README.md)。**

**屏幕分辨率自适应已生成候选：** [640×480/800×600自动选择、图片与OSD适配](SCREEN_ADAPTATION_20261010.md)。38项回归及内部STA通过，尚未上板；文件见 [构建状态](BUILD_STATUS.md)。旧缩放版bit固定输出640×480，不能用于验收本次功能，也不能理解为自动输出1080p。

**10月9日操作入口：[SW拨码与按键使用手册](SW_CONTROLS_20261009.md)。本版无需串口。**

更新：2026-10-11。入门按“怎么接 → 怎么用 → 为什么这样设计 → 如何验证”阅读。

| 想解决的问题 | 文档 |
|---|---|
| 插哪个HDMI口、电源/下载/UART怎么接、怎样制卡 | [详细接线与使用教程](CONNECTION_AND_USAGE.md)；显示器接HDMI_B |
| 使用滚动字幕、运行时间和淡出/滑动转场 | [效果使用说明](EFFECTS_20261009.md) |
| 快速查构建命令、操作和状态码 | [用户手册](USER_GUIDE.md) |
| 理解数据流及57个源文件各做什么 | [工程README](../README.md)、[源文件导航](SOURCE_MAP.md) |
| 阅读J盘芯片/IP资料，并知道哪些可以借鉴 | [官方资料与工程对照](VENDOR_REFERENCE_20261009.md) |
| 确认最近是否构建成功、时序是多少 | [构建状态](BUILD_STATUS.md)、[10月8日合并记录](TEAM_MERGE_20261008.md) |
| 理解时序检查和未完成的验证 | [时序边界](BOARD_TIMING.md)、[待办与验收条件](BOARD_PENDING.md) |

历史记录按日期保存，文中的“本次”“当前”和测试数量指当时版本。阅读旧结果时必须同时核对最近构建记录：

| 日期 | 记录 |
|---|---|
| 10月2日 | [初始审查](AUDIT_20261002.md) |
| 10月4日 | [PLL、IO与目录修订](REVISION_20261004.md) |
| 10月5日 | [工程整理、尾部处理与回归](AUDIT_20261005.md) |
| 10月7日 | [官方lab4/lab5审查](OFFICIAL_LABS_REVIEW_20261007.md)、[参考适配与修复](OFFICIAL_ADAPTATION_20261007.md) |
| 10月8日 | [队友工程合并](TEAM_MERGE_20261008.md) |
| 10月9日 | [官方器件/IP资料核对](VENDOR_REFERENCE_20261009.md)；后续又实现 [字幕转场](EFFECTS_20261009.md)并完成新构建 |

最近实际STA、回归与候选文件统一见 [构建状态](BUILD_STATUS.md)。旧+0.118/+0.004ns属于10月10日固定VGA版，不能用于新双模式源码。内部复位removal不能当HDMI管脚hold，未达到整体+0.5ns，尚未上板验证。
