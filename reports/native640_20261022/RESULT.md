# AVF 640×480 原生档实现与验证（2026-10-22）

AVF 在保留 legacy 与 quality 的基础上新增 native 640×480 RGB565LE。三档均输出640×480像素流，native不再放大源图像。顶层AVF仍默认开启，官方IP、物理引脚和时序约束未因本轮修改而改变。

## 容器与缩放规格

| 档位 | 源尺寸 | 像素格式 | 视频扇区/帧 | record扇区/帧 | geometry | encoding | 放大倍率 |
|---|---|---|---:|---:|---|---:|---:|
| legacy | 160×120 | BGR24 | 113 | 117 | 0x007800a0 | 0 | 4× |
| quality | 320×240 | RGB565LE | 300 | 304 | 0x00f00140 | 1 | 2× |
| native | 640×480 | RGB565LE | 1200 | 1204 | 0x01e00280 | 2 | 1× |

三档format恒为0x3e800014，即20fps视频、16kHz单声道PCM。每帧前4扇区保存音频及填充，随后保存本帧视频；文件头占1扇区。legacy的160×120×3是57600字节，113扇区含尾部填充。

## 改动文件与前后差异

原文件快照见[baseline](baseline/)，五个任务要求的核心文件及视频回归Shell入口的完整逐文件统一差异见[changes.diff](changes.diff)。本报告只列关键前后变化，不将原工作区其他未提交内容算成本轮新增。

| 文件 | 改前 | 改后 |
|---|---|---|
| scripts/prepare_video.py | high_quality布尔参数；legacy/quality两档 | fmt字符串与PROFILES三档字典；native=640×480/1204/encoding2；CLI新增native |
| scripts/test_prepare_video.py | quality调用用True；8项测试 | 改为quality字符串；新增native头、PCM填充、长度和最大帧数检查；三档FFmpeg参数覆盖，共9项 |
| src/modules/sd/sd_av_reader.v | high_quality一位；头只接受encoding0/1 | video_format两位；geometry/record/encoding精确匹配三档；native每帧推进1204扇区 |
| src/modules/video/av_fast_scaler.v | FORMAT_SELECT/high_quality；320像素行缓存 | video_format两位；640像素行缓存；native一次输出一行，无重复放大 |
| src/top.v | av_high_quality与160/320尺寸选择 | av_video_format[1:0]；三档reader与尺寸状态接线；外部端口不变 |
| scripts/run_video_tests.sh | 旧接口编译与仿真入口 | 调用统一Python runner，可运行全部视频用例 |
| scripts/run_av_fast_scaler_test.ps1 | 旧scaler接口测试入口 | 调用统一runner覆盖原scaler和三档新测试 |
| scripts/run_video_tests.py（新增） | 无统一三档测试适配入口 | 冻结旧测试保持原件，生成等价接口适配副本；增加native集成场景并核查ALL PASS |
| sim/tb_av_native.v（新增） | 无native精确像素验证 | 三档两帧逐像素、PCM、扇区顺序、背压、错误头、短/长扇区验证 |
| README.md、docs/BUILD_STATUS.md、docs/F_DRIVE_VIDEO_MERGE_20261021.md | 旧未接入说明及前一版构建值 | 当前三档状态、真实最终指标、旧bit区分；10月21日记录保留历史语境 |

缩放器关键位宽：row_y为9位，loaded_sectors为11位，row_x/out_x为10位；可覆盖第479行、第639列和1200扇区，避免计数回绕。native的last_repeat=0，RGB565扩展与quality一致。

旧legacy测试原文件没有改断言。因本任务明确更换了high_quality接口，runner在adapted_contracts目录生成接口适配副本，将旧布尔选择等价转换为video_format。冻结夹具中的旧布尔header调用仅在执行时等价转换为quality字符串。

## 验证结果

| 检查 | 实际结果 | 证据 |
|---|---|---|
| Python转换与打包 | 9项OK | [test_prepare_video.log](test_prepare_video.log) |
| static_check.py | ALL PASS，93 sources，40 IO bits | 静态检查已在最终代码上重跑 |
| 主RTL回归 | 111项ALL PASS | [main/main/](main/main/)下tb日志 |
| AVF专项 | 29场景ALL PASS | [video_regression_summary.json](video_regression_summary.json)及本目录逐测试日志 |
| TD综合/P&R/最终STA | completed | [build_manifest.json](../build_manifest.json)，finished_utc=2026-10-22T15:20:00.288499+00:00 |

AVF专项包括原10个契约测试、quality变体、三档两帧精确数据校验、native错误头/非法encoding/短长扇区拒绝、native实际FIFO与帧控制器联动、碎片FAT32与四位50MHz卡模型集成及EOF静音。三档行为未用降低断言门槛换取通过。

native内存集成模型的一帧装载时间为26577µs，通过该用例原有20fps期限断言。这是行为仿真结果，不代表真实TF卡吞吐、实板稳定播放或外部IO签核。

## 最终真实时序与资源

| 指标 | 实际结果 |
|---|---:|
| SWNS | +0.038ns |
| HWNS | +0.024ns |
| STNS / HTNS | 0 / 0ns |
| 主控制时钟 | 100MHz（保持原频率） |
| 主控clk0报告Fmax / 最小周期 | 100.381MHz / 9.962ns |
| svga_pixel报告Fmax | 49.505MHz（约束40MHz） |
| vga_pixel报告Fmax | 29.370MHz（约束25MHz） |
| LUT | 17018/19600，86.83% |
| REG | 11470/19600，58.52% |
| BRAM | 55/64，85.94% |
| DSP | 23/29，79.31% |
| PLL / GCLK | 2/4、4/16 |

报告来自[physical_area.txt](../physical_area.txt)、[timing_status.txt](../timing_status.txt)和[timing_summary.txt](../timing_summary.txt)。LUT低于18620，BRAM不超过64，DSP不超过29。

相较本轮修改前的+0.188ns/+0.022ns、LUT17036、BRAM54、DSP23，当前SWNS减少0.150ns，BRAM增加1块，LUT减少18；布线结果不能简单归因为某一模块的资源节省。最终SWNS/HWNS均为正，未触发用户规定的负时序停手条件，但裕量很薄，不能宣称达到+0.5ns。

本次最差setup路径从FAT32的cache_hit寄存器到movie_reader状态寄存器，报告数据路径9.610ns，其中布线6.064ns。此处是对实际路径的描述，不额外修改FAT32逻辑或时序约束。

board_signoff=false、hold_margin_0_5ns_met=false。全局HWNS不能当作HDMI管脚hold验收；内部复位removal也不是TMDS输出管脚hold。PHY-7002两条及PHY-5079一条实现警告仍存在，未声称警告清零或外部接口已签核。

## 转换与使用

已安装FFmpeg/FFprobe并加入PATH时，在工程根目录执行：

```powershell
python scripts/prepare_video.py input.mp4 VIDEO.AVF --profile native
```

也可明确指定工具路径：

```powershell
python scripts/prepare_video.py input.mp4 VIDEO.AVF --profile native --ffmpeg C:/tools/ffmpeg.exe --ffprobe C:/tools/ffprobe.exe
```

切换旧档只需把--profile改为quality或legacy；CLI默认仍为quality。脚本不覆盖已有输出，换文件名或在确认后自行处理旧输出。把生成的普通.AVF文件复制到FAT32卡根目录，沿用既有媒体选择与播放控制；无需把文件作为裸卡镜像写入。

native指源图像分辨率，未改变显示器输出模式协商或HDMI音频核能力。640明文TMDS路径仍是纯视频；需要HDMI声音时沿用实际800×600输出及其原有图声路径。本次没有新增音频编码格式或外设控制方式。

## bit与硬件边界

已有旧候选[video_improve_20261022.bit](../bitstream_20261022/video_improve_20261022.bit)为644756字节，对应本轮之前的+0.188ns/+0.022ns版本，SHA-256为ac2a2a28c22dd54aed36fafde90e2018716f46bb8c27ae9a1196c0f6ce84663b。它不含此次native640修改，不能用来验收本次新增功能。

2026-10-22北京时间23:39，按用户后续要求，已从匹配本轮源码的最终布线数据库生成[新native候选bit](bitstream/video_improve_native640_20261022.bit)，645920字节；生成前后SWNS +0.038ns、HWNS +0.024ns，STNS/HTNS均0，源码和数据库摘要均保持一致。SHA-256为73bac6987f22f9104f9ee73b180c18f4e3ec2ad43b2a5c729e6c373ccdaf8942；详细证据见[生成记录](bitstream/RESULT.md)和[清单](bitstream/manifest.json)。此前旧bit保留不变。

当前交付是已通过转换工具、RTL回归、综合/P&R/内部STA的三档源码、报告及新候选bit，尚未下载或上板。真实SD卡连续播放、外部接口电气时序和实板长期稳定性仍待硬件验收。
