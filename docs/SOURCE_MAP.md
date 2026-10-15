# 源文件与资料导航

2026-10-15 FAT32 v1：正式顶层读取普通FAT32卡根目录，直接复制最多4个BMP和第一个WAV，支持碎片簇链。无需裸镜像烧卡；KEY/SW与媒体格式要求保持。操作见[FAT32拷贝文件教程](FAT32_USAGE_20261015.md)，实际回归/STA见[本轮结果](../reports/fat32_20261015/RESULT.md)。旧裸扇区版的制卡方法与bit不适用于此版本。


音频恢复补充：audio_wav.v 增加一秒重试、四类错误码和100MHz流水优化；audio_playback.v 内新增 audio_error_history 模块，用真实PCM输出确认清除OSD失败历史。错误码在 top.v 用独立4位 cdc_snapshot 跨域，原70位状态总线保持不变。详见[音频恢复设计与操作](AUDIO_RETRY_20261014.md)。

更新：2026-10-15。活动设计清单为 [design_files.txt](../scripts/design_files.txt)，共63个源、36位IO；两个TD入口一致，唯一顶层为 [top.v](../src/top.v)。每一个设计源的具体功能、上下游和修改注意事项都在 [README模块说明](../README.md#每个设计源文件负责什么)。

2026-10-14 WAV增量：TF卡48kHz/16bit/单声道PCM经现有HDMI_B音频口输出，默认静音；KEY3长按菜单新增AUDIO MUTE、VOLUME DOWN、VOLUME UP，KEY/SW原功能保留。 [WAV解析](../src/modules/audio/audio_wav.v)、[读卡仲裁](../src/modules/sd/sd_read_arbiter.v)、[异步FIFO](../src/modules/audio/audio_async_fifo.v)、[采样/音量](../src/modules/audio/audio_playback.v)是四个新增设计源；[媒体工具](../scripts/prepare_audio.py)不加入TD。顶层保留HDMI/ACR，测试音源码留作回退。

早先板载版本新增[board_supervisor.v](../src/modules/common/board_supervisor.v)负责锁定后10ms保持及视频心跳监督；[board_debug.v](../src/modules/common/board_debug.v)把视频/内存状态整体快照到数码管；[picture_gamma.v](../src/modules/video/picture_gamma.v)用ROM实现可选暗部提亮并对齐两拍流水。KEY3菜单复用picture_controls/status_osd；观测总线复用现有模块接口，没有新增顶层管脚。[本轮优化说明](BOARD_OPTIMIZATION_20261014.md)解释数据流与验证边界。下面各日期数量为历史记录。

| 想研究的内容 | 入口 | 配套官方资料 |
|---|---|---|
| 系统接线、参数与双缓冲 | [top.v](../src/top.v) | EG4S20手册BG256引脚及资源 |
| 复位与跨时钟状态 | [reset_sync.v](../src/modules/common/reset_sync.v)、[cdc_snapshot.v](../src/modules/common/cdc_snapshot.v) | PLL锁定、FIFO复位；同步标记不替代握手 |
| 实体调节 | [picture_controls.v](../src/modules/control/picture_controls.v) | B1选项，B2/C1减加；UART/NEC历史模块未接入 |
| SD初始化与扇区协议 | [sd_card_top.v](../src/modules/sd/sd_card_top.v)、[sd_card_cmd.v](../src/modules/sd/sd_card_cmd.v) | CMD17末尾CRC16已校验；lab4参考不能替代SD协议规范 |
| FAT32文件枚举与簇链映射 | [sd_fat32.v](../src/modules/sd/sd_fat32.v) | [文件复制教程](FAT32_USAGE_20261015.md)；两流游标与FAT扇区缓存 |
| BMP解析与图片调度 | [bmp_read.v](../src/modules/bmp/bmp_read.v)、[sd_card_bmp.v](../src/modules/bmp/sd_card_bmp.v) | [媒体准备工具](../scripts/prepare_media.py)；文件索引与相对扇区 |
| SDRAM帧读写和FIFO | [frame_read_write.v](../src/modules/memory/frame_read_write.v)、[frame_fifo_read.v](../src/modules/memory/frame_fifo_read.v)、[sdram.v](../src/modules/memory/sdram.v) | 刷新宏在`global_def.v`；排空在读控制器；官方加密IP未改 |
| 换帧、视频光栅与像素队列 | [frame_swap.v](../src/modules/video/frame_swap.v)、[video_rgb_to_axis_640x480.v](../src/modules/video/video_rgb_to_axis_640x480.v) | APUG092连续行时序 |
| TMDS串行输出 | [hdmi_phy_wrapper.v](../src/modules/hdmi/hdmi_phy_wrapper.v)、[lane_lvds_10_1.v](../src/modules/hdmi/lane_lvds_10_1.v) | HDMI时钟架构、ODDR库、IO手册 |
| 声音、文字和数码管 | [audio_wav.v](../src/modules/audio/audio_wav.v)、[audio_playback.v](../src/modules/audio/audio_playback.v)、[status_osd.v](../src/modules/osd/status_osd.v)、[seg_scan.v](../src/modules/display/seg_scan.v) | APUG092 Audio/ACR；FAT32根目录PCM WAV |
| 旧固定参数缩放/颜色/模式参考（未接入） | `src/modules/optional` | DSP可作后续学习；有源码不代表顶层已支持 |
| 管脚与时序约束 | [pin.adc](../src/constraints/pin.adc)、[timing.sdc](../src/constraints/timing.sdc) | BG256引脚、IO/PLL、[时序边界](BOARD_TIMING.md) |

新增字幕/转场入口：[transition_pixels.v](../src/modules/video/transition_pixels.v)、[caption_overlay.v](../src/modules/osd/caption_overlay.v)、[video_coordinates.v](../src/modules/video/video_coordinates.v)。frame_swap在顶层开启动画握手；详见 [效果手册](EFFECTS_20261009.md)。

## 工程入口和生成文件

[根工程](../video_improve.al)与 [第二入口](../src/td_project/video_improve.al)应引用相同源集合。`src/ip`中的官方加密HDMI/SDRAM、FIFO和PLL是必要依赖，不能因不可读或看起来重复就删除。宏头文件通过include生效，工具入口副本有用途；`.ipc/.vhd/.tcl`是否参与当前编译须看工程和脚本，不能一概删除。

`sim`是测试台，`scripts`是构建/检查/媒体工具，`reports`是证据，`backups`是归档；这些目录不能通配加入TD。`legacy/user_source`保留独有历史参考，不参与活动构建。路径迁移记录见 [path_migration.json](path_migration.json)。

新扫描的PDF/DOCX、Altium库和参考工程没有加入TD源清单。PDF帮助解释接口，SchLib/PcbLib用于画板，均不是本工程RTL。官方包与当前IP的关联及不匹配项见 [资料对照](VENDOR_REFERENCE_20261009.md)。当前合并进度见 [10月8日记录](TEAM_MERGE_20261008.md)，全部文档见 [索引](README.md)。

## 2026-10-09 SW控制接入

[switch_controls.v](../src/modules/control/switch_controls.v) 对C8/C7/C6/C5四路进行同步、20ms整体消抖和功能映射；两个TD入口与源清单共48个源。UART/IR/player_control保留但当前顶层未实例化。操作见 [SW手册](SW_CONTROLS_20261009.md)。

## 2026-10-10 当前缩放与调参

新增 [bmp_scale_loader.v](../src/modules/video/bmp_scale_loader.v)、[picture_controls.v](../src/modules/control/picture_controls.v)、[picture_adjust.v](../src/modules/video/picture_adjust.v)。当前两个TD入口均51个源、36位IO；bmp_read启用动态尺寸路径，原optional/video_scaler仍仅参考。完整数据流见 [缩放与亮度/对比度详细手册](SCALING_AND_PICTURE_CONTROLS_20261010.md)。

## 2026-10-11 屏幕适配

当前两个TD入口及清单均54个源、36位IO。新增 `edid_display_mode.v`、`adaptive_video_clock.v`、`adaptive_raster.v`；分别负责EDID两档选择、PLL/全局时钟切换和模式时序。顶层已替换旧固定video_pll实例；旧包装与官方IP保留。OSD增加一拍流水并同步延迟VS/DE；写FIFO ready在生产者时钟域寄存并在清空期间保持关闭。功能、模式限制、测试与产物见 [屏幕适配](SCREEN_ADAPTATION_20261010.md) 和 [构建状态](BUILD_STATUS.md)。

## 2026-10-13 静态画面与读卡修复

仍是同一套54个活动源。`global_def.v`的刷新宏恢复非零间隔；`frame_fifo_read.v`按实际SDRAM返回数排空；`frame_read_write.v`提高显示优先级并将欠载接入OSD；`sd_card_cmd.v`验证扇区CRC16；`bmp_scale_loader.v`和`bmp_read.v`用寄存流水缩短100MHz长路径。完整测试覆盖范围和未解决的板级问题见[画面修复报告](DISPLAY_REPAIR_20261013.md)。

## 2026-10-15 FAT32文件读取

[sd_fat32.v](../src/modules/sd/sd_fat32.v)夹在BMP/WAV解析器与原扇区仲裁器之间，挂载MBR或superfloppy、枚举根目录、按双流簇链映射和缓存FAT扇区；原SD三层栈、仲裁、BMP头/缩放/帧提交、WAV RIFF状态机保持。测试见tb_fat32_mount/stream/player，仿真媒体工具为[make_fat32_image.py](../scripts/make_fat32_image.py)。
