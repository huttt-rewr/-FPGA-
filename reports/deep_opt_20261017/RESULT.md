# 保留全部功能的深度优化验收（2026-10-18）

**优化已落地，91项回归通过；整机验收仍未完成。** 当前物理LUT超过85%目标，SWNS为负，未生成本轮bit，未上板。不能把综合通过或布线命令完成当作最终验收。

## 准确资源

基线`2e31b55`综合19,483 LUT、11,676 REG、61 BRAM、17 DSP，当时MSlice超限无法完成布局。

| 项目 | 基线综合 | 当前综合 | 当前物理实现 |
|---|---:|---:|---:|
| LUT | 19483 | 16572（84.55%） | 17347（88.51%） |
| REG | 11676 | 11561 | 11665 |
| BRAM | 61 | 58（90.625%） | 58（90.625%） |
| DSP | 17 | 23 | 23 |

综合减少2,911 LUT和3 BRAM，达到明确的16660 LUT/58块上限；物理优化/保持修复后LUT为17,347，仍超上限687个。**不能宣称最终资源已全面达标。** 58/64=90.625%，严格≤90%应最多57块，附件的“90%（58块）”存在舍入不一致。

## 已落地的优化

- 缩放器缓存水平插值后的输出列：两行2048×24变为两行1024×24，独立13→7 BRAM；保留1920×1080源图、Q16/Q8双线性舍入、等比黑边、端点、背压及恢复。没有降为最近邻或限制源图宽度。
- 3×3灰度窗口同步BRAM预取，波形历史保存精确纵坐标并同步读BRAM。窗口用2块、波形用1块，合计全机净省3块；RGB/VS/DE延迟保持原合约。
- OSD十进制double dabble，字符串在编译期反接字节后直接索引；gamma采用8位预量化常量。菜单、字幕、玻璃、转场、像素效果与游戏全部保留。
- FAT32字段只存判零结果，共享互斥地址/移位硬件，容量比较拆成高低16位预判。保留MBR、superfloppy、FAT12/16拒绝、碎片簇链、容量/循环检查、双流及重挂载。
- 像素范围、缓存末列、目录扇区/遍历上限提前寄存；水平插值tap选择与DSP差分隔离。图片加载每个输出像素增加一拍范围判断；HDMI扫描时钟与显示流水对齐不变。KEY/SW、PS/2的使用方式不变。
- 游戏RAM由256深bank改为64深bank，规则和控制不变。保留官方HDMI、SDRAM、FIFO、PLL IP及音频。

详细技术、before→after及行号见[技术说明](../../docs/DEEP_OPTIMIZATION_20261018.md)。

## 验证和保护范围

静态检查77源/40 IO ALL PASS。最终[ModelSim日志](regression_split_geometry.log)91项ALL PASS，逐项冻结在verified_simulation。VGA/SVGA各9组黄金源图（含1×1、1920×1080）；新旧窗口3,148,800有效像素一致，波形2,371,885拍一致；BCD穷举0～4095，gamma256值独立实数参考通过。

官方IP、两个HDMI实例/参数、音频源码、SD原生栈/仲裁、pin.adc/timing.sdc与备份一致；70位status_source及20处status_video取位完全相同。所有输入哈希、选定数据库与报告均已核对，见[validation.json](validation.json)。没有删除官方IP，没有使用旧native50 bit验收当前源码。

曾有一次FAT新增逻辑先使用后声明导致ModelSim编译失败；相关旧库专项结果已作废，修正后重新编译并运行完整91项回归。最终日志中不存在编译失败或Error/Fatal。

## 实际时序与未完成项

选定第11轮：完整Routed、Slow/Fast、Speed=NA。后续第12轮PHY-8023、第13轮更差STA均冻结并排除，恢复第11轮实现脚本后逐一验证所有输入哈希相同。选择记录见[selection.json](selection.json)。

| 全局指标 | 结果 |
|---|---:|
| SWNS（setup/recovery最大延时） | -0.402 ns |
| STNS | -3.906 ns |
| HWNS（hold/removal最小延时） | +0.021 ns |
| HTNS | 0.000 ns |

| 具体检查 | 最差裕量 | 起点 → 终点 |
|---|---:|---|
| hold | +0.021 ns | `u_hdmi_svga/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo[2]__2_syn_4.clk` → `u_hdmi_svga/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_614.addrb[5]` |
| recovery | -0.402 ns | `sd_card_bmp_m0/audio_stream_reset_reg_syn_5.clk` → `audio_fifo/rreset/sync_ff_reg[1]_syn_4.sr` |
| removal | +0.022 ns | `u_hdmi_1_4b_transmitter_core_wrapper/u0_reset_sync/O_sync_reset_reg_syn_72.clk` → `u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/S_wr_cnt_reg[1]_syn_4.sr` |
| setup | -0.401 ns | `audio_index_reg[0]_syn_3.clk` → `sd_card_bmp_m0/audio_target_reg[2]_syn_7.a[0]` |

全局SWNS最差是音频FIFO复位recovery −0.402ns；普通数据setup最差−0.401ns，位于音频索引到目标文件寄存器。另有缩放器数据/范围路径、WAV队列余量判断及SD初始化路径。完整端点见[final_paths.json](final_paths.json)，不能将20端点摘要当成所有负路径数量。

内部HDMI reset removal不是HDMI管脚hold；没有整体+0.5ns声明。100MHz SD控制、25/40MHz像素、125/200MHz串行时钟保留，未加入false path或放宽周期。外部SD/DDC/TMDS IO时序、板卡速度等级、SDRAM硬宏告警及实板兼容性仍须验证。

TD6.2.168116后布线phys_opt在多种effort/mode重复触发“Abnormal Timing Path check”coredump。正式脚本先保存route数据库/STA，再独立fix_hold，最后运行完整检查。错误或负STA使run_build返回失败；退出码0或日志局部正值不能代替验收。

下一步仍需减少物理修复开销并修复上述尾差；音频/原生SD属于本轮保护范围，未为过时序改动其源码。可继续针对缩放路径拆分或由TD/IP供应方定位后布线优化器问题，不能以禁用音频、删除官方IP或屏蔽真实检查解决。

尚未生成本轮bit、下载或执行实体卡读图/WAV出声、KEY/SW/键盘、显示器锁相及吞吐测试。显示器仍接HDMI_B。

## 复现与证据

```powershell
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
python reports/deep_opt_20261017/audit_delivery.py
```

源码与报告审计：[validation.json](validation.json)；冻结[STA](final_build/timing_summary.txt)、[资源](final_build/physical_area.txt)、[实现日志](final_build/implementation.log)。修改前备份：backups/deep_opt_20261017/before.zip。历史失败记录保留。最终未达到时序/物理资源验收，run_build返回失败是预期的准确结果。
