# 构建修复验收记录（2026-10-18）

**当前保留 build3 的源码与报告；93 项仿真通过，内部 STA 未通过，未生成本轮 bit。**

## 已完成

- 顶层共享时钟/复位、`res_mode`、模式连线和 `vs` 声明前移。逐语句审计确认顶层除此之外没有逻辑变化，TD 的 HDL-7225/5373 前向声明警告消失。
- 缩放器完整乘积位宽和低16/高16行地址进位拆拍；新增 bit32 状态。1920×1080全部源行及进位/回绕/跨扇区/复位检查 5,437 项通过。
- 本地挂载完成寄存器隔离进入图片调度的长路径；源列控制和FAT比较候选因物理冲突均已撤回，FAT32解析器保持原版。
- 构建归档覆盖全部辅助路径报告，失败时拒绝旧产物；故障测试通过。
- 两位模式 CDC 测试和地址测试正式加入 ModelSim 回归。KEY/SW操作和连接不变。

## 验证结果

| 检查 | 结果 |
|---|---|
| 静态检查 | 77 源、40 IO，ALL PASS |
| ModelSim | 93 个不同测试，全部通过 |
| VGA/SVGA缩放 | 各9帧逐像素黄金比较，含1920×1080源图与1×1源图 |
| 末端视频流水 | 787,200像素、VS/DE和坐标对齐通过 |
| 综合 | 16,585 LUT / 11,564 REG / 58 BRAM / 23 DSP |
| 物理 | 17,357 LUT / 11,668 REG / 58 BRAM / 23 DSP |
| 最终SWNS / STNS | -0.592ns / -1.362ns |
| 最终HWNS / HTNS | +0.024ns / +0.000ns |
| 最差普通setup | -0.592ns |
| 报告中最差recovery | +0.161ns |
| 报告中最差removal | +0.027ns |
| 新bit / 下载 / 实板 | 均未执行 |

物理 LUT 为 88.56%，仍未达到85%目标。58/64 BRAM为90.625%，不能表述成≤90%。两个加密HDMI核及实例参数、全部官方IP、70位状态总线及取位、IO与时钟约束均未改变；没有降频或新增false path。

## 尚未解决

普通 setup 最差起点为 `sd_card_bmp_m0/filesystem$fat/request_rel_reg[22]_syn_4.clk`，终点为 `sd_card_bmp_m0/filesystem$fat/stream_bad_reg_syn_207.a[0]`。负值是真实失败，不能用布局阶段的正值或某一条已改善路径代替整机签核。

两处 PHY-7002、一处 PHY-5079 仍在，且仍为 CRITICAL-WARNING。工程没有对应可删除的非法用户位置约束，PLL到SDRAM无用户门控；不能删官方硬宏或擅自取消所需移相。EG4S20不支持本次尝试的 `report_clock_utilization -dramhardcon` 命令。这些警告未被证明无害，需要安路确认合封SDRAM模型、位置与时钟资源支持。

本轮沿用已能完成的避崩实现流程，没有重启已知会在 Abnormal Timing Path check 崩溃的 post-route phys_opt。本轮选定路由没有 coredump；这并不等于 STA 已通过。

HDMI内部复位removal不是HDMI管脚hold；没有外部IO或实板签核，没有整体+0.5ns声明。未调用bitgen，不能用历史bit验收当前源码。

## 试验与取舍

| 轮次 | 真实结果 | SWNS(ns) | STNS(ns) | HWNS(ns) |
|---|---|---:|---:|---:|
| build1 | timing_failed | -1.576 | -12.265 | +0.021 |
| build2 | failed | 无有效 STA | — | — |
| build3 | timing_failed | -0.592 | -1.362 | +0.024 |
| build4 | failed | 无有效 STA | — | — |

源列控制候选在两种布局策略下都发生PHY-8023冲突，已经撤回。第四轮FAT比较候选虽然93项仿真通过，但 `x11y55_w2beg4` 上两个FAT mux网发生PHY-8023冲突，因此也已撤回，`sd_fat32.v` 恢复为基线原文件。原候选保存在 `fat_compare_candidate.v` / `.patch` 供后续检查。

正式保留第三轮。恢复后逐文件输入哈希与该轮构建清单完全一致，根reports已恢复为该轮真实产物，并重新运行全部93项回归。没有把第四轮失败实现冒充成功；故障轮目录里的 `untrusted_preexisting_*` 是旧辅助产物，明确不参与该轮STA验收。

基线为 `f8272d50c10cb216dd286d70fcd8959b2bb6e065`，其SWNS −0.402ns含复位recovery，普通setup −0.401ns、HWNS +0.021ns。不能用附件的旧−9.243ns当作本轮修改前基线夸大改善。

行地址定向对比为基线+0.895ns/9.034ns、第一轮拆拍后+1.189ns/8.740ns；实际约改善0.294ns，未达到“约3ns路径”的预期。每个源行增加10ns准备时间，显示刷新率和逐像素插值不变。

## 证据

- [源码/报告哈希与测试绑定](validation.json)、[保护范围审计](scope.json)
- [选定布线后STA](build3/routed_timing_paths20.txt)、[构建清单](build3/build_manifest.json)
- [完整回归](regression_final.log)、`final_test_logs/` 中的逐项日志
- [详细技术与使用边界](../../docs/BUILD_REPAIR_20261018.md)
- 修改前备份：`E:/fpga/backups/build_repair_20261018/before.zip`

未修改SD三层栈、音频解析和音效；完整保留双分辨率、EDID、FAT32/MBR、1920×1080源图、双线性、字幕、OSD、玻璃、特效、波形和游戏。功能仿真通过不代替实板画面、声音或SD吞吐验收。
