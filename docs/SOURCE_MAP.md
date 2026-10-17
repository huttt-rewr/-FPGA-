# 正式源文件职责与工程入口

下面逐一列出design_files.txt登记的源。登记不等于每个模块都被正式top实例化，旧参考在表中明确标注。实际功能和验证见[README](../README.md)与[构建状态](BUILD_STATUS.md)。

| 正式源文件 | 职责/使用范围 |
|---|---|
| [src/modules/hdmi/hdmi_phy_wrapper.v](../src/modules/hdmi/hdmi_phy_wrapper.v) | 把HDMI核10bit并行通道送入串行器与差分输出包装。 |
| [src/modules/hdmi/lane_lvds_10_1.v](../src/modules/hdmi/lane_lvds_10_1.v) | 使用器件ODDR将10bit通道按像素/5倍时钟序列化。 |
| [src/ip/hdmi/hdmi_1_4b_transmitter_core_wrapper.enc.v](../src/ip/hdmi/hdmi_1_4b_transmitter_core_wrapper.enc.v) | 必要官方加密HDMI编码、控制包、EDID和内嵌音频IP。 |
| [src/modules/bmp/bmp_read.v](../src/modules/bmp/bmp_read.v) | BMP头/尺寸/行填充校验及相对扇区、缩放调度；不把坏图提交显示。 |
| [src/modules/video/color_bar.v](../src/modules/video/color_bar.v) | 旧固定VGA彩条/时序参考，正式自适应光栅替代其活动时序。 |
| [src/modules/memory/frame_fifo_read.v](../src/modules/memory/frame_fifo_read.v) | SDRAM读突发、实际返回计数、显示FIFO库存与欠载帧恢复。 |
| [src/modules/memory/frame_fifo_write.v](../src/modules/memory/frame_fifo_write.v) | 逐像素写队列、背压、整帧长度/帧尾与溢出诊断。 |
| [src/modules/memory/frame_read_write.v](../src/modules/memory/frame_read_write.v) | 读写仲裁、显示优先和双缓冲地址调度。 |
| [src/modules/bmp/sd_card_bmp.v](../src/modules/bmp/sd_card_bmp.v) | 图片/音频总调度、索引选择、取消排空、自动换图与真实提交确认。 |
| [src/modules/video/video_timing_data.v](../src/modules/video/video_timing_data.v) | 两档光栅包装、场消隐脉冲和帧读请求握手。 |
| [src/modules/video/video_delay.v](../src/modules/video/video_delay.v) | 既有视频控制/数据延迟参考模块，按实际实例决定综合保留。 |
| [src/modules/sd/sd_card_cmd.v](../src/modules/sd/sd_card_cmd.v) | SPI命令/响应、数据token、CRC16、等待超时；计数预译码不增加线时钟等待。 |
| [src/modules/sd/sd_card_sec_read_write.v](../src/modules/sd/sd_card_sec_read_write.v) | SD初始化、OCR寻址判定、扇区命令和失败重试。 |
| [src/modules/sd/sd_card_top.v](../src/modules/sd/sd_card_top.v) | 正式原生/旧SPI兼容profile封装，对上保留扇区字节流握手。 |
| [src/modules/sd/spi_master.v](../src/modules/sd/spi_master.v) | SPI字节收发，100MHz域产生默认25MHz SCK。 |
| [src/modules/memory/sdram.v](../src/modules/memory/sdram.v) | 合封SDRAM官方控制核包装及应用读写接口。 |
| [src/modules/display/seg_decoder.v](../src/modules/display/seg_decoder.v) | 十六进制/状态值到数码管段码。 |
| [src/modules/display/seg_scan.v](../src/modules/display/seg_scan.v) | 六位数码管位扫描。 |
| [src/ip/sdram/sdr_as_ram.enc.v](../src/ip/sdram/sdr_as_ram.enc.v) | 必要官方合封SDRAM应用接口IP。 |
| [src/ip/sdram/sdr_init_ref.enc.v](../src/ip/sdram/sdr_init_ref.enc.v) | 必要官方SDRAM初始化与刷新IP。 |
| [src/ip/sdram/sdr_wrrd.enc.v](../src/ip/sdram/sdr_wrrd.enc.v) | 必要官方SDRAM读写时序IP。 |
| [src/ip/pll/sys_pll.v](../src/ip/pll/sys_pll.v) | 50MHz参考到100MHz控制/40MHz内存与内存相移时钟。 |
| [src/ip/pll/video_pll.v](../src/ip/pll/video_pll.v) | 旧VGA PLL包装保留；正式使用adaptive_video_clock中的固定多输出PLL。 |
| [src/ip/fifo/afifo_16_32_256.v](../src/ip/fifo/afifo_16_32_256.v) | 官方异步FIFO宽度转换包装，内存/像素链依赖。 |
| [src/ip/fifo/afifo_32_16_256.v](../src/ip/fifo/afifo_32_16_256.v) | 官方异步FIFO宽度转换包装，内存/像素链依赖。 |
| [src/modules/common/startup_pulse.v](../src/modules/common/startup_pulse.v) | 上电延时/单拍启动辅助。 |
| [src/modules/video/video_rgb_to_axis_640x480.v](../src/modules/video/video_rgb_to_axis_640x480.v) | 视频像素到官方HDMI AXIS握手，按有效行连续发送。 |
| [src/modules/audio/audio_test_source.v](../src/modules/audio/audio_test_source.v) | 旧测试音参考；正式音源为WAV，不应误认为其代表TF音频。 |
| [src/modules/common/cdc_snapshot.v](../src/modules/common/cdc_snapshot.v) | 握手保持多位一致快照；状态、媒体和请求使用独立实例。 |
| [src/modules/common/reset_sync.v](../src/modules/common/reset_sync.v) | 异步置位、各时钟域多拍同步释放。 |
| [src/modules/control/ir_nec_rx.v](../src/modules/control/ir_nec_rx.v) | NEC接收参考，正式顶层禁用IR控制。 |
| [src/modules/control/player_control.v](../src/modules/control/player_control.v) | 旧UART/IR播放命令参考，正式KEY/SW/键盘路径不实例化。 |
| [src/modules/control/uart_rx.v](../src/modules/control/uart_rx.v) | UART字节接收参考，正式控制禁用。 |
| [src/modules/control/uart_tx.v](../src/modules/control/uart_tx.v) | UART字节发送参考，正式控制禁用。 |
| [src/modules/optional/ycbcr_to_rgb.v](../src/modules/optional/ycbcr_to_rgb.v) | 未接入的YCbCr转RGB参考。 |
| [src/modules/osd/osd_char_rom.v](../src/modules/osd/osd_char_rom.v) | ASCII字模查表。 |
| [src/modules/osd/status_osd.v](../src/modules/osd/status_osd.v) | 状态字符、完整文件计数、错误和TARGET/L叠加与像素流水。 |
| [src/top.v](../src/top.v) | 唯一活动顶层，连接时钟/复位、控制、媒体、帧缓存、视频/音频与物理管脚。 |
| [src/modules/video/edid_base_check.v](../src/modules/video/edid_base_check.v) | EDID基础块校验辅助。 |
| [src/modules/video/frame_swap.v](../src/modules/video/frame_swap.v) | 场消隐接收提交toggle、返回真实确认、逐帧推进转场参数。 |
| [src/modules/video/video_enhance.v](../src/modules/video/video_enhance.v) | 旧视频调节参考，正式使用picture_adjust/picture_gamma。 |
| [src/modules/optional/video_mode_table.v](../src/modules/optional/video_mode_table.v) | 未接入的模式参数表参考。 |
| [src/modules/optional/video_scaler.v](../src/modules/optional/video_scaler.v) | 旧固定参数缩放参考，正式动态缩放由bmp_scale_loader承担。 |
| [src/modules/control/uart_tx_queue.v](../src/modules/control/uart_tx_queue.v) | 旧串口应答排队，正式控制禁用。 |
| [src/modules/video/video_coordinates.v](../src/modules/video/video_coordinates.v) | 有效区坐标与视口映射，OSD/字幕布局基础。 |
| [src/modules/video/transition_pixels.v](../src/modules/video/transition_pixels.v) | 按逐帧权重/偏移实现淡出淡入和滑动像素处理。 |
| [src/modules/osd/caption_overlay.v](../src/modules/osd/caption_overlay.v) | 内置ASCII字幕、滚动、运行时间与视口适配；正式三段流水同步延迟RGB/VS/DE。 |
| [src/modules/control/switch_controls.v](../src/modules/control/switch_controls.v) | SW同步消抖及字幕/滚动/转场映射。 |
| [src/modules/video/bmp_scale_loader.v](../src/modules/video/bmp_scale_loader.v) | 双行缓存、保比例双线性插值、补黑边、像素背压。 |
| [src/modules/control/picture_controls.v](../src/modules/control/picture_controls.v) | KEY模式/长按菜单及唯一音量静音寄存器，接收键盘并联事件。 |
| [src/modules/video/picture_adjust.v](../src/modules/video/picture_adjust.v) | 亮度偏移/对比度定点缩放与饱和；帧参数统一更新。 |
| [src/modules/video/edid_display_mode.v](../src/modules/video/edid_display_mode.v) | 启动解析显示器是否支持800×600，结果作为能力而不是强制模式。 |
| [src/modules/video/adaptive_video_clock.v](../src/modules/video/adaptive_video_clock.v) | 固定25/125及40/200MHz输出、永久25MHz启动时钟与全局时钟复用。 |
| [src/modules/video/adaptive_raster.v](../src/modules/video/adaptive_raster.v) | 640×480和800×600内部有效区、同步与消隐计数。 |
| [src/modules/common/board_supervisor.v](../src/modules/common/board_supervisor.v) | 上电保持、PLL和视频心跳看门狗、复位记录。 |
| [src/modules/common/board_debug.v](../src/modules/common/board_debug.v) | 多域状态快照和数码管诊断页。 |
| [src/modules/video/picture_gamma.v](../src/modules/video/picture_gamma.v) | 可选暗部提亮LUT；不是显示器色彩校准。 |
| [src/modules/sd/sd_read_arbiter.v](../src/modules/sd/sd_read_arbiter.v) | 图片/音频共享物理扇区、授权/等待超时和传输恢复。 |
| [src/modules/audio/audio_wav.v](../src/modules/audio/audio_wav.v) | RIFF/fmt/data解析、48k/16bit/mono约束、扇区缓存、错误分类和一秒重试。 |
| [src/modules/audio/audio_async_fifo.v](../src/modules/audio/audio_async_fifo.v) | PCM双时钟FIFO、格雷指针与分域复位释放。 |
| [src/modules/audio/audio_playback.v](../src/modules/audio/audio_playback.v) | 48k均匀采样、预填/欠载、音量乘法/饱和、真实PCM和粘滞错误历史。 |
| [src/modules/audio/audio_effects.v](../src/modules/audio/audio_effects.v) | 固定参数15抽头FIR低/高频调节和单次延迟回声，默认等延迟旁路。 |
| [src/modules/sd/sd_fat32.v](../src/modules/sd/sd_fat32.v) | FAT32只读挂载、目录、总64文件BRAM索引、双流簇链/FAT缓存和取消排空。 |
| [src/modules/input/ps2_keyboard.v](../src/modules/input/ps2_keyboard.v) | PS/2双同步/滤波、11bit帧奇校验、Set2前缀和超时恢复。 |
| [src/modules/input/ps2_controls.v](../src/modules/input/ps2_controls.v) | 扫描码译事件、按住防重复、A+数字等待与事件流水。 |
| [src/modules/audio/audio_effects_stream.v](../src/modules/audio/audio_effects_stream.v) | 切音频清FIR/回声历史，同时保留48k样本valid调度和静音包。 |
| [src/modules/audio/audio_fifo_room.v](../src/modules/audio/audio_fifo_room.v) | 寄存PCM接收许可并预留四槽，截断FIFO满反馈长组合路径。 |
| [src/modules/video/video_mode_control.v](../src/modules/video/video_mode_control.v) | 启动域先复位后切模式、稳定等待、EDID不支持时回退VGA。 |
| [src/modules/control/fps_control.v](../src/modules/control/fps_control.v) | 目标换图周期，忙时只等一个请求、受限记录；不改变HDMI刷新率。 |

`src/constraints/pin.adc`与`timing.sdc`分别约束管脚与时序；`memory/global_def.v`通过include提供刷新等宏。两个TD入口是根video_improve.al与src/td_project/video_improve.al，必须与scripts/design_files.txt保持同一源集合。

`src/modules/sd/native/`已接正式板级工程，使用原生四位25MHz，见[协议/硬件限制](SD_NATIVE_4BIT_20261016.md)。未登记的pixel_effects/玻璃OSD来自其他实验，不能据文件存在就宣称已启用。测试放sim，主机/仿真素材工具放scripts，报告和试验放reports，备份放backups，历史参考放legacy；这些目录不能通配加进TD。官方加密核、FIFO包装、PLL/SDRAM依赖不能当成重复垃圾删除。

## 新增正式原生SD源

| 文件 | 功能 |
|---|---|
| src/modules/sd/native/sd_bus_phy.v | 100MHz域产生识别/25MHz线时钟，CMD三态、命令/响应CRC7、四路数据CRC16与字节拼接。 |
| src/modules/sd/native/sd_native_controller.v | CMD0/8/55/41/2/3/7/ACMD6/16初始化、SDHC/SDSC寻址、CMD17和超时恢复。 |
| src/modules/sd/native/sd_card_top_native.v | 原生扇区封装，保留请求和数据握手；只读，写请求报错。 |

正式源数为72；sd_card_top按常量NATIVE_4BIT选择，正式top为1，旧SPI分支在正式综合中剪除。sim/tb_sd_native_integrated.v直接验证正式通路，原有SPI激励仍运行兼容profile。没有改官方IP或上层解析算法。

## CMD6高速增量

sd_native_controller在25MHz查询/切换High Speed，锁存64字节状态中的支持、选中与busy，CRC成功后才采用；sd_bus_phy接收64/512字节并检查四路CRC16。50MHz采样许可延后一拍100MHz，不照搬SDRAM相位。正式top启用NATIVE_HIGH_SPEED，旧25MHz测试默认关闭。新激励tb_sd_highspeed和tb_sd_highspeed_player见[SD实现](SD_NATIVE_4BIT_20261016.md)。这属于3.3V High Speed SDR，不是1.8V UHS-I SDR50。

## 实验：像素特效、玻璃与波形

新增三份video模块和五项激励，清单75源。模块职责、操作、ModelSim入口和未解决的物理/时序问题见[本轮手册](OSD_AUDIO_VISUALIZER_20261017.md)。85项功能通过不代表可上板，本轮没有新bit。
