# F 盘视频工程对比与合并记录

> **状态更新（2026-10-22）：** AVF 播放链路已接入并默认开启，legacy 160×120、quality 320×240及新增 native 640×480 三档均已实现。最新综合/P&R/内部 STA 通过：SWNS +0.038ns、HWNS +0.024ns，LUT 17018、BRAM 55、DSP 23；111项主回归、29场景AVF专项和9项转换工具测试通过。已生成[含 native 功能的新候选 bit](../reports/native640_20261022/bitstream/video_improve_native640_20261022.bit)，645920字节，生成前后STA一致；此前旧候选 bit 不含此次修改。未上板，未达整体 +0.5ns。详见[当前结果](../reports/native640_20261022/RESULT.md)及[bit生成记录](../reports/native640_20261022/bitstream/RESULT.md)。**以下是2026-10-21当时的历史记录，原资源与时序数据不代表当前版本。**

当时检查对象为 `F:\-FPGA--main`，目标工程为 `E:\fpga`。本次先做文件级和依赖级检查，再选择能独立使用的内容；没有用 F 盘顶层、引脚、时序约束或官方 IP 覆盖 E 盘版本。

## 合入内容

- `scripts/prepare_video.py`：把 MP4 转为播放器设计的 AV16K20/AVF 容器，支持旧版 160×120 BGR24 和较高画质的 320×240 RGB565LE。视频按 20 fps、音频按 16 kHz 单声道 PCM 组织，并在每帧记录中为音频和图像分别补齐扇区。
- `scripts/test_prepare_video.py`：8 项容器头、帧数据、PCM 填充、尺寸上限、输出不覆盖和 FFmpeg 参数测试；已加入全量 `scripts/run_tests.ps1`。
- `legacy/f_drive_video_reference/`：保留 F 盘视频顶层、激励、转换辅助脚本及操作文档，供后续找回缺失 RTL 时对照。这里的文件不会被 TD 或 ModelSim 编译。

转换需要本机 Python、FFmpeg 和 FFprobe，例如：

```powershell
python scripts/prepare_video.py input.mp4 VIDEO.AVF --profile quality --ffmpeg C:/tools/ffmpeg.exe --ffprobe C:/tools/ffprobe.exe
```

脚本只生成普通文件，不会写 TF 卡。转换输出需要独立存储空间，已有输出文件不会被覆盖。

## 当时尚未合入的播放功能（2026-10-21历史）

F 盘的 `scripts/design_files.txt` 列出了 87 个 HDL 源，但其中 **80 个源文件在 F 盘目录中不存在**；`src/modules` 和 `src/ip` 目录也不存在。特别缺少 `sd_av_reader`、`av_sync_player`、`av_fast_scaler`、`boot_media_select` 等 AVF 读流、缓冲、音画同步和模式控制模块。递归搜索未能在 F 盘其余源码、脚本或补丁中找到这些模块实现。

因此 F 盘文档中的视频播放行为、吞吐与资源数字不能证明这些 RTL 可从该目录重建，也不能作为 E 盘工程的验收结果。E 盘当时播放器仍是 BMP/WAV 路径；**当时 AVF 转换成功不代表 FPGA 能读取或播放 AVF**。当时没有把 AVF 接入 FAT32 目录扫描、SD 仲裁、SDRAM 帧缓存、OSD 或音频路径；该情况已于次日改变，见顶部状态更新。

按当时评估，后续要完整接入视频，需要找回与该顶层和激励匹配的缺失 HDL/IP 源码及其版本绑定的工程/报告，再逐项适配 E 盘 FAT32/原生 SD、双缓冲写入确认、视频时钟和音频队列接口。当时工程物理 LUT 已接近容量上限，完整移植还必须重新验证资源及时序。

## 工程清单修复和验证

检查开始时，E 盘根 TD 工程 `video_improve.al` 相对 `scripts/design_files.txt` 和源码，缺少 7 个仍在当前设计中的引用：`time_cmd.v`、`remote_controls.v`、`auto_enhance.v`、`auto_enhance_scale.v`、`slideshow_timer.v`、`zh_overlay.v`、`zh_font_rom.v`。已备份用户当前修改版 TD 工程，再按正式源清单补回引用；嵌套 TD 工程无需改动。修改前状态和 SHA-256 记录在 `reports/f_drive_merge_20261021/`。

当时验证结果：AVF 转换器 8 项测试通过；108 项现有 ModelSim 回归全部通过；`scripts/static_check.py` 通过，检查 87 个 HDL 源、40 个 IO，并确认根/嵌套 TD 工程及正式源清单一致。TD 综合、布局布线和独立最终 STA 通过，SWNS +0.142 ns、STNS 0 ns、HWNS +0.024 ns、HTNS 0 ns；物理资源 LUT 17,283/19,600、REG 11,014/19,600、BRAM 45/64、DSP 26/29。没有达到整体 +0.5 ns；内部复位 removal 不等于 HDMI 管脚 hold。当时没有生成新 bit 或上板，AVF 播放尚未接入（已于次日10月22日接入；后续新增 native 档，见顶部状态更新）。

构建期间 TD 会重新序列化 `.al` 的 XML 属性转义与格式，曾触发输入变化保护。`scripts/run_build.py` 已改为对 `.al` XML 规范化后做摘要；HDL、引脚约束、时序约束仍按原始字节摘要检查。最终构建清单状态为 completed。详细证据见 `reports/f_drive_merge_20261021/RESULT.md` 和 `reports/build_manifest.json`。

E 盘原有未提交删除 `.lock.f` 保留不动。F 盘的 `.qdb`、仿真 work、dump、minidump、旧 bit、日志和 QoR 报告未复制进正式工程；官方 IP 保持原样。
