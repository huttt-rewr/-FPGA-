from pathlib import Path
import shutil,re
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
for name in ('README.md','docs/USER_GUIDE.md','docs/SOURCE_MAP.md','docs/KEYBOARD_USAGE_20261016.md'):
 shutil.copy2(R/name,O/('before_final_'+Path(name).name))
shutil.copy2(O/'README_final.md',R/'README.md')
shutil.copy2(O/'KEYBOARD_USAGE_final.md',R/'docs/KEYBOARD_USAGE_20261016.md')
(R/'docs/USER_GUIDE.md').write_text('''# HDMI 图片与 WAV 播放器用户手册

当前完整操作见[键盘、分辨率和换图频率教程](KEYBOARD_USAGE_20261016.md)，[KEY/SW详细教程](KEY_SW_OPERATION.md)解释不接键盘时的全部板载操作。显示器接HDMI_B；新顶层默认不静音、音量08。是否有匹配的新bit及STA/回归通过状态，请先看[构建状态](BUILD_STATUS.md)。旧bit不能验证新功能。

## 第一次运行

1. 用FAT32、512字节扇区的TF卡，复制合计不超过64份BMP/WAV到根目录；按目录项顺序枚举，不按文件名数字排序。BMP限正高度24bit BI_RGB、1～1920×1～1080；WAV限48kHz/16bit/单声道PCM、最大16MiB。
2. 断电连接TF卡、HDMI_B和支持Set2的PS/2键盘；显示器选择相应HDMI输入。官方PS/2 CLK=M16、DATA=K16是封装坐标，不是插头针号。
3. 上电/配置当前工程，等待挂载和首图完整装载。复位默认输出VGA640×480，菜单关闭、亮度0、对比度1、音量08、不静音。
4. 左右换图，数字0选第一张；A松开后2秒内数字选WAV。空格开启自动播放，F调目标换图档，R在VGA/SVGA/小素材VGA之间循环。SVGA受EDID支持限制，切档暂黑后重新装载。
5. 上下调音量、M静音；O开关状态OSD。KEY3短按释放切PLAY/BRIG/CONT，KEY1/2执行对应操作；KEY3长按约1.1秒进入菜单。SW保持控制字幕/滚动/转场。

R的0档和1档都输出VGA；小素材需要事先转换为320×240，R不会自动减少大图的卡读取量。F的TARGET不是显示器刷新率，也不保证实际FPS；L表示曾受加载/提交忙限制。切模式会重挂载并暂停自动轮播，恢复后可再按空格。

## 转换普通文件

在E:/fpga执行，只生成电脑普通文件；随后在资源管理器复制到TF根目录，不需烧裸镜像：

```powershell
python scripts/prepare_media.py convert photo.jpg media/PIC01.bmp --width 320 --height 240 --fit contain
python scripts/prepare_media.py check media/PIC01.bmp
python scripts/prepare_audio.py convert input.wav media/SOUND01.wav
python scripts/prepare_audio.py check media/SOUND01.wav
```

输出已存在时工具会拒绝覆盖，请换名。[完整制卡说明](FAT32_USAGE_20261015.md)包含文件系统、碎片与格式错误处理；[接线说明](CONNECTION_AND_USAGE.md)包含管脚与TD配置步骤。

## 快速排障

| 现象 | 检查与处理 |
|---|---|
| 无画面 | HDMI_B、显示器输入、是否当前bit；先复位回VGA；不支持1080p输出 |
| 按键不换图 | 先退出菜单并选MODE:PLAY；等待LOAD:B结束；KEY1长按不会连发 |
| 数字选错图 | 从0计数、按目录项顺序；没有两位数输入；越界回第一份 |
| 无声 | 合规WAV、音量不为0、M静音状态、显示器HDMI音频能力与自身音量 |
| A:E1..E4 | 1格式/头、2SD/超时、3扇区长度、4chunk/边界；失败一秒重试，见音频诊断教程 |
| U1 | 音频曾欠载，切WAV不清；切模式或整机复位清除，若重现检查读卡服务速度 |
| TARGET旁L | 实际加载/提交超过目标周期；降档或使用更小的图片，不等于显示器刷新失败 |
| LOAD:E | 图片读取/提交或视频缓存诊断，保留旧帧；挂载问题修正卡后复位 |
| 改卡内容没生效 | 安全断电换卡后复位重新枚举；不支持运行中热插拔重扫 |

音频错误历史到真实PCM恢复才清，不能把静音包当恢复；挂载失败和图片提交确认超时不属于自动WAV重试范围。卡与显示器的实板验收仍未完成，不能由仿真推断白条或出声已解决。

## 验证与设计资料

```powershell
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
```

不要在构建过程中改src/scripts/sim输入。两TD入口引用同一源清单，官方HDMI/SDRAM/PLL/FIFO IP是必要依赖。[源文件职责](SOURCE_MAP.md)、[多文件实现](MEDIA_INDEX_20261016.md)、[SD四位候选与50MHz限制](SD_NATIVE_4BIT_20261016.md)、[构建状态](BUILD_STATUS.md)。正式SD仍SPI25MHz；内部复位removal不能当作HDMI管脚hold，没有整体+0.5ns签核声明。
''',encoding='utf-8')
descriptions={
'hdmi_phy_wrapper.v':'把HDMI核10bit并行通道送入串行器与差分输出包装。',
'lane_lvds_10_1.v':'使用器件ODDR将10bit通道按像素/5倍时钟序列化。',
'hdmi_1_4b_transmitter_core_wrapper.enc.v':'必要官方加密HDMI编码、控制包、EDID和内嵌音频IP。',
'bmp_read.v':'BMP头/尺寸/行填充校验及相对扇区、缩放调度；不把坏图提交显示。',
'color_bar.v':'旧固定VGA彩条/时序参考，正式自适应光栅替代其活动时序。',
'frame_fifo_read.v':'SDRAM读突发、实际返回计数、显示FIFO库存与欠载帧恢复。',
'frame_fifo_write.v':'逐像素写队列、背压、整帧长度/帧尾与溢出诊断。',
'frame_read_write.v':'读写仲裁、显示优先和双缓冲地址调度。',
'sd_card_bmp.v':'图片/音频总调度、索引选择、取消排空、自动换图与真实提交确认。',
'video_timing_data.v':'两档光栅包装、场消隐脉冲和帧读请求握手。',
'video_delay.v':'既有视频控制/数据延迟参考模块，按实际实例决定综合保留。',
'sd_card_cmd.v':'SPI命令/响应、数据token、CRC16、等待超时；计数预译码不增加线时钟等待。',
'sd_card_sec_read_write.v':'SD初始化、OCR寻址判定、扇区命令和失败重试。',
'sd_card_top.v':'正式SPI控制层与PHY连接，对上提供扇区字节流。',
'spi_master.v':'SPI字节收发，100MHz域产生默认25MHz SCK。',
'sdram.v':'合封SDRAM官方控制核包装及应用读写接口。',
'seg_decoder.v':'十六进制/状态值到数码管段码。',
'seg_scan.v':'六位数码管位扫描。',
'sdr_as_ram.enc.v':'必要官方合封SDRAM应用接口IP。',
'sdr_init_ref.enc.v':'必要官方SDRAM初始化与刷新IP。',
'sdr_wrrd.enc.v':'必要官方SDRAM读写时序IP。',
'sys_pll.v':'50MHz参考到100MHz控制/40MHz内存与内存相移时钟。',
'video_pll.v':'旧VGA PLL包装保留；正式使用adaptive_video_clock中的固定多输出PLL。',
'afifo_16_32_256.v':'官方异步FIFO宽度转换包装，内存/像素链依赖。',
'afifo_32_16_256.v':'官方异步FIFO宽度转换包装，内存/像素链依赖。',
'startup_pulse.v':'上电延时/单拍启动辅助。',
'video_rgb_to_axis_640x480.v':'视频像素到官方HDMI AXIS握手，按有效行连续发送。',
'audio_test_source.v':'旧测试音参考；正式音源为WAV，不应误认为其代表TF音频。',
'cdc_snapshot.v':'握手保持多位一致快照；状态、媒体和请求使用独立实例。',
'reset_sync.v':'异步置位、各时钟域多拍同步释放。',
'ir_nec_rx.v':'NEC接收参考，正式顶层禁用IR控制。',
'player_control.v':'旧UART/IR播放命令参考，正式KEY/SW/键盘路径不实例化。',
'uart_rx.v':'UART字节接收参考，正式控制禁用。',
'uart_tx.v':'UART字节发送参考，正式控制禁用。',
'uart_tx_queue.v':'旧串口应答排队，正式控制禁用。',
'ycbcr_to_rgb.v':'未接入的YCbCr转RGB参考。',
'osd_char_rom.v':'ASCII字模查表。',
'status_osd.v':'状态字符、完整文件计数、错误和TARGET/L叠加与像素流水。',
'top.v':'唯一活动顶层，连接时钟/复位、控制、媒体、帧缓存、视频/音频与物理管脚。',
'edid_base_check.v':'EDID基础块校验辅助。',
'frame_swap.v':'场消隐接收提交toggle、返回真实确认、逐帧推进转场参数。',
'video_enhance.v':'旧视频调节参考，正式使用picture_adjust/picture_gamma。',
'video_mode_table.v':'未接入的模式参数表参考。',
'video_scaler.v':'旧固定参数缩放参考，正式动态缩放由bmp_scale_loader承担。',
'video_coordinates.v':'有效区坐标与视口映射，OSD/字幕布局基础。',
'transition_pixels.v':'按逐帧权重/偏移实现淡出淡入和滑动像素处理。',
'caption_overlay.v':'内置ASCII字幕、滚动、运行时间与视口适配；正式三段流水同步延迟RGB/VS/DE。',
'switch_controls.v':'SW同步消抖及字幕/滚动/转场映射。',
'bmp_scale_loader.v':'双行缓存、保比例双线性插值、补黑边、像素背压。',
'picture_controls.v':'KEY模式/长按菜单及唯一音量静音寄存器，接收键盘并联事件。',
'picture_adjust.v':'亮度偏移/对比度定点缩放与饱和；帧参数统一更新。',
'edid_display_mode.v':'启动解析显示器是否支持800×600，结果作为能力而不是强制模式。',
'adaptive_video_clock.v':'固定25/125及40/200MHz输出、永久25MHz启动时钟与全局时钟复用。',
'adaptive_raster.v':'640×480和800×600内部有效区、同步与消隐计数。',
'board_supervisor.v':'上电保持、PLL和视频心跳看门狗、复位记录。',
'board_debug.v':'多域状态快照和数码管诊断页。',
'picture_gamma.v':'可选暗部提亮LUT；不是显示器色彩校准。',
'sd_read_arbiter.v':'图片/音频共享物理扇区、授权/等待超时和传输恢复。',
'audio_wav.v':'RIFF/fmt/data解析、48k/16bit/mono约束、扇区缓存、错误分类和一秒重试。',
'audio_async_fifo.v':'PCM双时钟FIFO、格雷指针与分域复位释放。',
'audio_playback.v':'48k均匀采样、预填/欠载、音量乘法/饱和、真实PCM和粘滞错误历史。',
'audio_effects.v':'固定参数15抽头FIR低/高频调节和单次延迟回声，默认等延迟旁路。',
'sd_fat32.v':'FAT32只读挂载、目录、总64文件BRAM索引、双流簇链/FAT缓存和取消排空。',
'ps2_keyboard.v':'PS/2双同步/滤波、11bit帧奇校验、Set2前缀和超时恢复。',
'ps2_controls.v':'扫描码译事件、按住防重复、A+数字等待与事件流水。',
'audio_effects_stream.v':'切音频清FIR/回声历史，同时保留48k样本valid调度和静音包。',
'audio_fifo_room.v':'寄存PCM接收许可并预留四槽，截断FIFO满反馈长组合路径。',
'video_mode_control.v':'启动域先复位后切模式、稳定等待、EDID不支持时回退VGA。',
'fps_control.v':'目标换图周期，忙时只等一个请求、受限记录；不改变HDMI刷新率。',
}
paths=(R/'scripts/design_files.txt').read_text().splitlines()
assert all(Path(p).name in descriptions for p in paths)
text='''# 正式源文件职责与工程入口

下面逐一列出design_files.txt登记的源。登记不等于每个模块都被正式top实例化，旧参考在表中明确标注。实际功能和验证见[README](../README.md)与[构建状态](BUILD_STATUS.md)。

| 正式源文件 | 职责/使用范围 |
|---|---|
'''
text+='\n'.join('| ['+p+'](../'+p+') | '+descriptions[Path(p).name]+' |' for p in paths)
text+='''

`src/constraints/pin.adc`与`timing.sdc`分别约束管脚与时序；`memory/global_def.v`通过include提供刷新等宏。两个TD入口是根video_improve.al与src/td_project/video_improve.al，必须与scripts/design_files.txt保持同一源集合。

`src/modules/sd/native/`是未接入正式板级工程的四位SD候选，见[协议/硬件限制](SD_NATIVE_4BIT_20261016.md)。未登记的pixel_effects/玻璃OSD来自其他实验，不能据文件存在就宣称已启用。测试放sim，主机/仿真素材工具放scripts，报告和试验放reports，备份放backups，历史参考放legacy；这些目录不能通配加进TD。官方加密核、FIFO包装、PLL/SDRAM依赖不能当成重复垃圾删除。
'''
(R/'docs/SOURCE_MAP.md').write_text(text,encoding='utf-8')
p=R/'docs/KEYBOARD_REMAINING_20261016.md'
s=p.read_text(encoding='utf-8').replace('本页为后续设计记录，**不是已接入功能清单**。','本页说明本轮R/F实现机制与尚未完成的板级验收；正式接入和验证状态以构建状态为准。')
s=s.replace('候选在永久','在永久').replace('独立 `video_mode_control` 候选','`video_mode_control`').replace('独立 `fps_control` 候选','`fps_control`')
s=s.replace('正式接入仍须完成工程清单、跨域、整机STA与实板显示器重新锁相验收。','工程清单、跨域和整机STA的本轮结果见构建状态；实板显示器重新锁相验收仍未完成。')
p.write_text(s,encoding='utf-8')
p=R/'docs/FAT32_USAGE_20261015.md';s=p.read_text(encoding='utf-8')
s=s.replace('把 **1～4个 BMP 直接复制到卡根目录**','把 BMP直接复制到卡根目录（BMP与WAV合计最多64份）')
s=s.replace('把 **一个 PCM、48000Hz、16bit、单声道 WAV**','把一份或多份 **PCM、48000Hz、16bit、单声道 WAV**')
s=s.replace('选择前4张BMP和第一个WAV','为BMP和WAV分别建立索引，合计最多64份')
s=s.replace('多于4张图的其余文件不参与播放。','总数超过64的后续媒体不参与播放，OSD显示T。')
s=s.replace('声音默认静音。菜单选择AUDIO MUTE并切为OFF，使用VOLUME DOWN/UP调音量','新顶层默认不静音、音量08；菜单或键盘M切静音，上下或VOLUME DOWN/UP调音量')
s=s.replace('底层 `sd_card_top`、`sd_card_sec_read_write` 和 `sd_read_arbiter` 的接口与行为未更改。','底层扇区接口与握手语义保留；本轮对sd_card_cmd内部控制译码做等价时序优化。')
s=s.replace('非法文件索引/扇区','非法文件扇区')
s=s.replace('越界文件索引/扇区','越界文件扇区')
s=s.replace('2026-10-15。本页对应','2026-10-16多文件增量：数字与A+数字操作见[键盘手册](KEYBOARD_USAGE_20261016.md)，实际回归/STA见[构建状态](BUILD_STATUS.md)。以下旧日期报告为历史证据。本页对应')
p.write_text(s,encoding='utf-8')
p=R/'docs/KEY_SW_OPERATION.md';s=p.read_text(encoding='utf-8')
s=s.replace('下表及旧版本段落的MUTE=ON是历史默认值。','下表已更新为本轮默认值；旧日期段落仅作历史对照。')
s=s.replace('| AUDIO MUTE | ON/OFF切换声音暂停；OFF开始WAV读取与预填 | ON |','| AUDIO MUTE | ON/OFF切换声音暂停；OFF开始WAV读取与预填 | OFF |')
s=s.replace('开声：复位后长按KEY3开菜单','若已静音需开声：长按KEY3开菜单')
s=s.replace('复位恢复静音和08级。','本轮复位恢复不静音和08级。')
s=s.replace('分辨率上电时自动选择，KEY和SW都不用于手动选择分辨率。','本轮复位默认VGA；R可请求SVGA并受EDID限制，KEY和SW仍不用于手动选择分辨率。')
s=s.replace('左上状态OSD保持显示；','左上状态OSD由键盘O开关；')
s=s.replace('2026-10-15 FAT32 v1：','历史2026-10-15 FAT32 v1：')
p.write_text(s,encoding='utf-8')
print('Rewrote current README, complete keyboard/user manuals and per-source map; reconciled FAT32/KEY defaults')
