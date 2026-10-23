# 2026-10-22 候选 bit 生成结果

已从通过内部 STA 的 reports/video_improve_routed.db 生成候选 bit，没有重新综合或布局布线，没有下载到板卡。

- 文件：[video_improve_20261022.bit](video_improve_20261022.bit)
- 大小：644756 字节。
- SHA-256：ac2a2a28c22dd54aed36fafde90e2018716f46bb8c27ae9a1196c0f6ce84663b
- 布线数据库 SHA-256：c57ad8004f48cd3c8582a7104d6a428102028e08fc129d9720b34bab0cfb6caf
- 构建输入 708 项与已完成构建一致，生成前后源码与数据库未变化。
- 生成前后 SWNS 均为 +0.188ns、HWNS 均为 +0.022ns，STNS/HTNS 均为0。
- 生成前后 VGA/SVGA 的 pixel/serial 四种模式时钟均存在。
- 验证范围沿用该构建的111项主回归、17项AVF场景和93源/40 IO静态检查；本次没有修改RTL，不重复编译回归。

候选生成不代表整板签核。最小裕量限制路径为内部复位 removal，并非 HDMI 管脚 hold；未达到整体 +0.5ns。PHY-7002/PHY-5079警告保留，HDMI/SD外部IO和实板出图、出声、读卡仍待测试。没有连接下载器或执行烧录。

详细证据：[候选清单](manifest.json)、[冻结的构建清单](source_build_manifest.json)、[TD日志](bitgen.log)、[生成前STA](before_bit_timing_status.txt)、[生成后STA](after_bit_timing_status.txt)。

README与构建状态已更新为“候选bit已生成，实板待验”；此前修复报告中的“未生成本轮bit”记录的是生成前阶段。

生成入口为 generate_candidate.py；已有候选时会拒绝覆盖。2026-10-19 的 reports/video_improve.bit 未被本次生成覆盖。
