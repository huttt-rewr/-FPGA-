# PS/2 贪吃蛇小游戏：操作、设计与验证

> 2026-10-17 增量实验功能。当前源码已接入游戏；是否可生成上板文件必须查看本文末尾的实际构建结果。上一版 OSD/波形源码本身尚未通过物理验收，旧 native50 bit 不包含本次游戏。

## 1. 如何操作

继续使用工程现有 PS/2 键盘接口与 HDMI 输出，不增加 GPIO、串口命令或外接控制器。键盘接法见 [键盘手册](KEYBOARD_USAGE_20261016.md)，显示连接见 [用户手册](USER_GUIDE.md)。

| 操作 | 效果 |
| --- | --- |
| 按一下 G 并松开 | 进入游戏；在下一次视频帧边界生效，蛇从中央朝右开始移动 |
| 上/下/左/右方向键 | 请求对应方向；松开后继续沿最后方向移动 |
| 游戏中再按 G | 退出，恢复原来的完整媒体画面 |
| 结束后按 G 退出，再按 G 进入 | 清空棋盘、分数归零，重新开始 |
| O | 控制原媒体 OSD、玻璃面板和波形；游戏有自己的 G 开关 |
| R | 保留原分辨率切换功能；如果实际输出模式改变、视频链复位，当前游戏会重开 |
| KEY1/KEY2/KEY3、SW1～SW4 | 保留既有媒体/画面功能；没有改成游戏控制键 |

长按 G 的键盘自动重复不会来回切换：一次按下只切换一次，松开后才能再次切换。Esc 仍只取消 A+数字的音频选择前缀。

游戏期间，方向键不再触发下一张/上一张图片、增减音量；退出后这些原功能恢复。其他媒体按键保持原功能，图片轮播和 WAV 音频继续运行，游戏叠加在它们上面。按空格仍可暂停/恢复背景轮播。

方向请求按“上、下、左、右”排列优先级；不建议同时按多个方向。系统用实际已执行方向拦截 180° 掉头，例如向右运动时按左键仍继续向右。转向须在下一次移动节拍前被接收；每六个显示帧移动一格，约每秒十格。

## 2. 画面与规则

默认棋盘为 32 列 × 24 行，每格在逻辑视口中为 16×16 像素，初始蛇长三格。

- VGA 640×480：棋盘左上角 (64,48)，尺寸 512×384。
- SVGA 800×600：复用既有 640×480 逻辑视口映射，棋盘左上角 (80,60)，尺寸 640×480，每格实际为 20×20 像素。
- 蛇身绿色，食物红色，棋盘内背景逐通道减半；白色两像素逻辑边框。
- 棋盘外 RGB 原样通过。游戏关闭时整幅有效图像原样通过；无效像素输出黑色。
- 左上方显示 `SCORE: 000`，每吃一个食物得一分，显示分数在 255 饱和，蛇身仍可继续增长。
- 撞墙或撞到身体后冻结本局，中央显示 `GAME OVER`。允许进入同一步正在移走的尾巴格。
- 填满棋盘后也冻结本局，避免在没有空格时无限搜索食物；当前复用 GAME OVER 文案，没有单独的胜利画面。

游戏使用固定一拍 RGB/VS/DE 输出延迟，开启和关闭都保留这拍延迟。不能在旁路时直接短接视频信号，否则会造成开关游戏时的时序突变。

## 3. 为什么这样实现

### 时钟、复位、跨域

PS/2 解码与既有控制处于 `sd_card_clk` 域，游戏处于 `video_clk` 域。新增独立 5 位 `cdc_snapshot` 传输 `{游戏开关, 上, 下, 左, 右}`，没有修改历史 70 位 `status_source` 的位宽和排列。

游戏开关在低有效 VS 的下降沿锁存。移动节拍也是这个帧边界产生，每六帧一次，初始化、移尾、写头和食物搜索发生在垂直消隐内，避免一幅有效画面中途修改棋盘。所有复位均高有效；LUT RAM 不做数组复位，由状态机在进入新游戏时逐格清零。

`status_osd.pixel_x/y` 描述的是其输入坐标，不能直接当作注册输出的坐标。本工程在 status_osd 输出处重新调用 `viewport_coordinates`，使游戏坐标与其看到的 RGB/VS/DE 同拍。

### 棋盘与蛇身队列

`snake_lut_ram` 显式使用 TD 的 `(* ram_style="dram" *)`，这里的 dram 指 LUT 分布式 RAM，与板载 SDRAM 和片内 BRAM 不同。

棋盘保存每格一个占用位；渲染、碰撞检查与食物搜索在同一视频时钟域按时间共用一个物理读口。顶层保证 tick 在垂直消隐出现，食物搜索也在消隐完成，因此不需要为了游戏更新复制棋盘读口。复用该模块时同样应在垂直消隐提供 tick。写口每拍只更新一个格子：普通移动先清旧尾，下一拍写新头；吃食时只写头而不移尾。

首版每节保存 10 位坐标。优化后环形 FIFO 每节只保存 2 位移动方向，另用寄存器保存尾巴坐标。移尾时读出最早的一步方向并更新尾巴坐标，效果与坐标队列相同，队列存储位数减少 80%。指针在第 768 项后显式回到零，不能依赖 10 位自然溢出，否则会访问不存在的 768～1023 项。

两类 RAM 均拆为三个 256 深度的小块，避免 TD 自动将 768 深度补齐为 1024。渲染用移位把像素坐标换成格子坐标；没有运行时除法、浮点或随机查表。

### 食物与分数

16 位 LFSR 提供伪随机起始格，随后逐格检查空闲位置，遇到尾端显式回绕。这样避免只抽随机数却一直抽到蛇身的无界重试；只要还有空格，最多扫描一圈即可找到。新头提交以后才开始检查食物，防止把食物放在新头上。

分数使用饱和的 8 位计数器，另用三个十进制位增量进位显示，避免在像素链里计算 `/10` 或 `%10`。字模复用 `osd_char_rom.v`。

## 4. 文件与视频链

| 文件 | 作用 |
| --- | --- |
| `src/modules/game/snake_game.v` | 游戏状态机、占用棋盘、方向 FIFO、食物、字体叠加，以及同文件内的帧节拍与分块 LUT RAM |
| `src/modules/input/ps2_controls.v` | 暴露四方向按住状态，增加 G 的一次按下切换，游戏中隔离方向键媒体事件 |
| `src/top.v` | 新增独立控制 CDC、输出端坐标、游戏实例，并把游戏输出送 RGB-to-AXIS |
| `scripts/design_files.txt` | 命令行 TD 设计源清单 |
| `video_improve.al`、`src/td_project/video_improve.al` | 两份 TD 工程均登记游戏源 |
| `sim/tb_snake_game.v` | 游戏规则、颜色、旁路、碰撞、增长、队列回绕、复位 |
| `sim/tb_snake_controls.v` | G/方向键、跨域、媒体事件隔离、每六帧移动 |
| `sim/tb_snake_pipeline.v` | VGA/SVGA 完整视口及固定一拍视频对齐 |

视频末端变为：`audio_visualizer → caption_overlay → status_osd → snake_game → RGB-to-AXIS → HDMI`。

本次不修改 SD/FAT32/BMP/WAV/音效算法、官方 IP、引脚约束和时钟约束。分数已作为内部 `game_score` 连接，并在游戏画面显示；没有占用现有数码管诊断显示。

## 5. ModelSim 怎么验证

在 E:\fpga 打开 PowerShell，运行：

```powershell
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
```

全量脚本已登记三个新激励文件与游戏源码。只有日志含 `ALL PASS` 且不含失败标记才算通过，不能仅凭 ModelSim 进程退出码判断。

三个游戏测试也可以在独立库中运行，避免占用正在执行全量回归的 msim_work：

```powershell
& J:\win64\vlib.exe reports/snake_20261017/snake_work
& J:\win64\vlog.exe -work reports/snake_20261017/snake_work src/modules/common/cdc_snapshot.v src/modules/video/video_coordinates.v src/modules/osd/osd_char_rom.v src/modules/input/ps2_controls.v src/modules/game/snake_game.v sim/tb_snake_game.v sim/tb_snake_controls.v sim/tb_snake_pipeline.v
& J:\win64\vsim.exe -lib reports/snake_20261017/snake_work tb_snake_game
```

ModelSim 窗口中执行 `add wave -r sim:/tb_snake_game/dut/*`、`run -all`，可观察 `state/dir/head_x/head_y/tail_x/tail_y/len/score/game_over`。把 tb_snake_game 换成 tb_snake_controls 或 tb_snake_pipeline 可运行其他两项。

规则测试对“吃食”使用空闲格定向食物夹具，以可重复触发增长和自撞；同时检查硬件自身生成的食物在范围内且不在蛇身上。流水测试检查 VGA/SVGA 开启与关闭共 1,574,400 个有效像素。

## 6. 实际验收

独立综合：1,386 LUT、137 寄存器、0 BRAM、0 DSP。这里采用 TD 的 Utilization Statistics `#lut` 口径；同报告 `#Total_luts=752` 是另一统计项，不能替代占用数。

独立综合仅验证逻辑/资源，不是游戏时序签核。整机结果、源文件哈希、原功能回归和物理失败原因见 [本次结果](../reports/snake_20261017/RESULT.md) 与 [构建状态](BUILD_STATUS.md)。

最终完整回归 88 项 ALL PASS。整机综合 19,483 LUT / 61 BRAM；布局报 PHY-9009：5,252 MSlice 超过 4,900。布线和 STA 未完成，没有当前时序值，没有生成新 bit，尚不能据此版本上板演示。
