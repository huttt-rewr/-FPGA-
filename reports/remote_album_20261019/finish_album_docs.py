from pathlib import Path
root=Path(__file__).resolve().parents[2]
p=root/'docs/UART_IR_ALBUM_20261020.md'
s=p.read_text(encoding='utf-8')
i=s.index('| ~Q~T123456~Q~ |'.replace('~Q~',chr(96)))
extra='''| s | 开关独立五秒相册轮播；复位默认关 | K |
| h | 开关固定中文点阵字幕；复位默认关 | K |
| l | 大字/原小字时钟切换；复位默认小字 | K |
'''
s=s[:i]+extra+s[i:]
s+='''
## 五秒相册：一步一步使用

1. TF卡至少准备两张合规BMP，等待首图显示且LOAD不再为B。显示器接HDMI_B。
2. 先看PLAY:OFF。若原自动播放为ON，用KEY2（MODE:PLAY）、空格或串口b切到OFF。
3. 串口发送s，收到K后开启独立五秒计时。它从启用且首图就绪开始计时，每五秒产生一次下一张请求。
4. 读卡/加载忙或错误期间不积压连续请求；定时到期只保留一次待处理请求。加载、帧边界、转场还要时间，不能承诺照片严格每五秒完成一次切换。
5. 再发送s关闭。若同时开启原有自动播放，五秒调度暂停并清计数，原目标换图频率F继续有效；关闭原轮播后，五秒计时从头开始。

s状态独立于原PLAY标志。PLAY:OFF不能单独证明五秒相册关闭；当前OSD没有新增s状态灯。演示前复位把所有新增选项恢复为关闭。b和s都是切换命令，回显丢失时盲目重发可能反向切换。原KEY/SW仍控制原功能，未增加隐藏组合按键。

## 时钟、中文和画质：推荐演示步骤

先将SW第1路拨到字幕开启，再发送T123456，可见BJ 12:34:56并继续走秒；没有对时则显示UP开机时长。发送l把右上小钟移为画面上部的大字钟，再发l恢复小钟。l只选择样式，SW第1路仍是时钟和原英文字幕的总开关。

发送h出现“欢迎光临电子相册参赛作品多媒体展示”，再发h关闭。中文是固定17字、16×16同步点阵ROM，未用字模清零，不支持通过UART输入任意中文。中文层独立于SW英文字幕开关和键盘O状态OSD开关。逻辑640×480视口中，中文区域为x32～303、y384～399；在800×600时随已有视口映射放大为20×20字格。

大钟背景窗口为逻辑x144～495、y96～159；原小钟为x448～623、y16～47。字符采用5×7字模，大钟像素放大4倍，小钟2倍，在800×600再随视口适配。尺寸/开关和时钟数字在帧边界锁存。中文层增加两拍，自动色阶增加四拍，RGB/VS/DE/XY一起延迟。

固定一张灰暗、低对比度图片，发送a比较自动色阶。它作用于图片层，不处理之后叠加的文字；暗部伽马仍由原KEY菜单独立控制。全部叠加最后可能被G游戏画面覆盖，检查相册效果时先退出游戏。

PC端例子（COM3必须换成实际端口）：

~Q~~Q~~Q~powershell
python scripts/album_remote.py --port COM3 --command a
python scripts/album_remote.py --port COM3 --command h
python scripts/album_remote.py --port COM3 --command l
python scripts/album_remote.py --port COM3 --command s
python scripts/album_remote.py --port COM3 --sync
~Q~~Q~~Q~

## ModelSim如何验证

完整命令：powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1。所有激励在sim目录，结果在reports/tb_*.log；不需要实体显示器、TF卡、串口或遥控器。

| 激励 | 验证内容 |
|---|---|
| tb_remote_uart | 真实8N1字符、n/p/b/a/s/h/l、K/?、半包超时、时间范围、CDC与午夜 |
| tb_remote_ir | 真NEC引脚波形、命令反码、重复码忽略、复位和无UART回显 |
| tb_auto_enhance | 每种非零范围与256输入参考映射、溢出/恒色/空帧、两档完整光栅直通及流水 |
| tb_album_timer | 周期1/2/7的精确节奏、忙饱和、一次待处理、禁用/复位、随机参考 |
| tb_zh_overlay | VGA/SVGA四完整帧、字模/半透明背景、逐像素旁路、帧锁存、未用字模 |
| tb_album_clock | 独立字体参考、大/小钟两档适配、帧锁存、BJ数字和关闭旁路 |
| tb_board_pipeline | 视频链加入关闭的自动色阶和中文级，两档六帧与HDMI连续行契约 |

Python主机辅助检查：python reports/remote_album_20261019/test_host.py，不导入pyserial、不打开COM。只检查包字节、UTC+8和回显错误，不能替代实体通信。逻辑仿真和内部STA不能替代上板出图、遥控器码表、UART电平、HDMI音频或外部IO签核。
'''.replace('~Q~',chr(96))
p.write_text(s,encoding='utf-8')
p=root/'docs/KEY_SW_OPERATION.md';s=p.read_text(encoding='utf-8')
s=s.replace('右上 ~Q~UP HH:MM:SS~Q~ 是播放器启动后的运行时长，不是北京时间。'.replace('~Q~',chr(96)),'未对时时右上UP HH:MM:SS是启动时长；UART接受有效THHMMSS后显示BJ HH:MM:SS，l选择大字样式，SW第1路仍控制显示。')
s+='\n## 2026-10-20新增控制与原KEY/SW的关系\n\n原KEY1/2/3和四路SW映射保持。自动色阶a、五秒相册s、固定中文h、大钟l使用本轮UART。SW第1路仍控制英文字幕和时间；中文h独立。原PLAY与s独立，s优先级低于原自动播放。详细步骤见[本轮操作手册](UART_IR_ALBUM_20261020.md)。所有新增选项复位默认关。\n'
p.write_text(s,encoding='utf-8')
p=root/'docs/SOURCE_MAP.md';s=p.read_text(encoding='utf-8')
s=s.replace('2026-10-20 增量源码（物理门禁尚未通过）','2026-10-20 UART/IR/画质/相册增量源码')
s=s.replace('使用原生四位25MHz，见','使用原生四位CMD6协商25/50MHz，见')
s=s.replace('未登记的pixel_effects/玻璃OSD来自其他实验，不能据文件存在就宣称已启用。','pixel_effects、glass_osd与音频波形已接入正式视频链；是否启用以top实例和正式清单为准。')
s+='''
| 新增源 | 具体职责 |
|---|---|
| [auto_enhance.v](../src/modules/video/auto_enhance.v) | 上一帧RGB范围统计，四级定点拉伸、舍入和饱和；默认旁路。 |
| [auto_enhance_scale.v](../src/modules/video/auto_enhance_scale.v) | Q8倒数同步ROM，RGB三份BRAM，范围0输出0，内嵌常量避免工作目录依赖。 |
| [slideshow_timer.v](../src/modules/control/slideshow_timer.v) | 默认五秒、忙时饱和、单次待处理的可选翻图脉冲。 |
| [zh_font_rom.v](../src/modules/osd/zh_font_rom.v) | 17个16×16汉字，512行同步ROM，未用地址置0。 |
| [zh_overlay.v](../src/modules/osd/zh_overlay.v) | 两级中文取字/叠加，半透明背景和RGB/VS/DE/XY同步寄存。 |

auto_enhance_scale.mem、zh_font.mem用于审计和激励参考；生产RTL内嵌同值常量，不依赖启动目录readmemh。主机脚本scripts/album_remote.py不能加入TD综合。状态与冻结证据见[本轮手册](UART_IR_ALBUM_20261020.md)。
'''
p.write_text(s,encoding='utf-8')
print('Expanded album operations, controls, tests and source map')
