# native640候选bit生成记录

已按用户要求从当前native640最终布线数据库导出新候选bit，未重新布局布线，未修改RTL/IP/引脚/时序约束，未执行硬件下载。

- 文件：[video_improve_native640_20261022.bit](video_improve_native640_20261022.bit)
- 大小：645920字节。
- SHA-256：`73bac6987f22f9104f9ee73b180c18f4e3ec2ad43b2a5c729e6c373ccdaf8942`。
- 器件：Anlogic EG4S20BG256。
- 生成完成：2026-10-22T15:39:04.346191+00:00，北京时间2026-10-22 23:39。
- 来源构建：2026-10-22T15:20:00.288499+00:00，status=completed。
- 内容：legacy 160×120、quality 320×240、native 640×480三档AVF；AVF_ENABLED=1。

## 验证

| 项目 | 结果 |
|---|---|
| 当前输入与构建快照 | 一致；生成后再次核对 |
| 最终布线数据库与构建产品SHA-256 | 一致；生成后再次核对 |
| 生成前SWNS/HWNS | +0.038ns / +0.024ns |
| 生成后SWNS/HWNS | +0.038ns / +0.024ns |
| 生成前后STNS/HTNS | 0ns / 0ns |
| 前后STA与来源构建数值 | 一致 |
| VGA/SVGA像素与串行时钟 | 四个模式时钟在前后报告均存在 |
| TD bitgen | BITGEN_COMPLETED，无检测到的ERROR/FATAL |
| 旧候选文件 | SHA-256保持原样，未覆盖 |

生成前既有验证为转换工具9项、主RTL111项及AVF29场景通过；本次未改变构建输入，因此未重复跑RTL回归。

证据：[清单](manifest.json)、[来源构建清单](source_build_manifest.json)、[TD日志](bitgen.log)、[生成前STA](before_bit_timing_status.txt)、[生成后STA](after_bit_timing_status.txt)、[完整生成后时序](after_bit_timing_summary.txt)。导出Tcl见[generate_candidate.tcl](generate_candidate.tcl)；主机端沿用reports/bitstream_20261022/generate_candidate.py的检查流程，仅把OUT及BIT绑定到本目录和新文件名。

## 尚未完成的硬件验收

这是上板待验候选，board_signoff=false、hardware_download_performed=false、hold_margin_0_5ns_met=false。未达到整体+0.5ns，未将全局HWNS或内部removal当作HDMI管脚hold。来源构建的PHY-7002/PHY-5079警告仍待核对；真实卡播放、出图/出声及长期稳定性尚未实板验证。640输出模式仍为纯视频，800模式保留原有HDMI音频能力。
