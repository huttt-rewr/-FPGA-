# FAT32 比较器优化实际结果（2026-10-18）

**结论：内部 STA 仍失败，未生成本轮 bit。** 最终选择 `build4`，94 项 ModelSim 全部通过。三项等价改写均未改善整体实现，已撤回。最终 FAT32 与 a5d76ca 完全一致，保留新增 4074 用例测试和全部候选证据；当前结果来自恢复后的新鲜完整构建。

## 试验范围与结果

初始工作区已有附件要求的扇区比较改写，已备份到 `initial/` 并在首个小步提交中保留记录。随后每个候选分别完成静态检查、独立真实 DUT 边界测试、94 项回归和综合，并独立尝试布局布线及 STA；第三轮因布线错误不具备有效 STA 验收结果。没有将候选推测当作实测收益。

| 版本 | SWNS ns | STNS ns | HWNS ns | HTNS ns | 物理 LUT |
|---|---:|---:|---:|---:|---:|
| 原基线 a5d76ca | -0.592 | -1.362 | +0.024 | +0.000 | 17357 |
| build1 | -0.743 | -5.002 | -0.128 | -0.157 | 17426 |
| build2 | -0.936 | -2.005 | +0.021 | +0.000 | 17314 |
| build3（布线冲突，无有效 STA） | — | — | — | — | — |
| build4 | -0.592 | -1.362 | +0.024 | +0.000 | 17357 |

build1：仅将文件扇区范围比较改成高八位归约 OR + 低 24 位比较。build2：再将目标簇与卷簇数比较改成显式高八位判断 + 低 24 位比较；没有截断卷容量。build3：再将完整 32 位簇上界比较写为高低 16 位组合比较；没有加寄存器。若有 build4，为恢复原基线后的新鲜完整实现。

候选失败时只保留其自身日志和源码，不把其他轮次的数据库或时序作为该候选证据。详见各轮 `paths.json`；无法合法布线的候选已报告具体工具失败原因。

SWNS/STNS 按工具原义记录，包含相应 setup/recovery 约束；HWNS/HTNS 也不等于 HDMI 管脚 hold。各检查类型的真实最差值和已报告负路径见 `build4/paths.json`。BRAM 58/64=90.625%，DSP 23，未通过删功能腾资源。没有整体 +0.5ns 声明。

## 验证证据

- 静态检查：77 源文件、40 位 IO，ALL PASS；两个 TD 工程和端口均保持一致。
- 最终完整回归：94 项 ALL PASS，列表、源码与每份日志 SHA-256 见 [validation.json](validation.json)。新增测试直接执行正式 FAT32 的 `STREAM_LIMIT`、`STREAM_CHECK` 与 `FAT_VALIDATE`，参考保留原完整比较。
- 原有 FAT32/MBR/索引、BMP/双线性缩放、WAV/音效、原生 SD 25/50MHz、CDC、VGA/SVGA、OSD/字幕/玻璃/波形/特效、游戏回归均保留。行为仿真不等于加密核完整顶层仿真或实板验证。
- 最终匹配源码的构建：[build4/build_manifest.json](build4/build_manifest.json)，原始路径报告 [build4/routed_timing_paths20.txt](build4/routed_timing_paths20.txt)。所有当前输入哈希已与所选新鲜构建逐一核对。
- 范围审计：[scope.json](scope.json)。最终保留 0 处计划内 RTL 比较表达式变化；其他全部受 Git 跟踪的 src 文件、官方 IP、引脚约束、两工程入口、实现脚本及自适应时钟均与基线一致。70 位 `status_source` 及所有 `status_video` 下标未动。
- 本轮 bit 生成：未生成；下载、写实体卡、上板出图/出声和吞吐实测：均未执行。

## 最终已报告负路径

| 检查 | Slack ns | 起点 | 终点 |
|---|---:|---|---|
| setup | -0.592 | `sd_card_bmp_m0/filesystem$fat/request_rel_reg[22]_syn_4.clk` | `sd_card_bmp_m0/filesystem$fat/stream_bad_reg_syn_207.a[0]` |
| setup | -0.327 | `sd_card_bmp_m0/filesystem$fat/target_index_reg[13]_syn_4.clk` | `sd_card_bmp_m0/filesystem$fat/cursor_reusable_reg_syn_5.b[1]` |
| setup | -0.185 | `sd_card_bmp_m0/rate_control$timer/last_cycle_reg[7]_syn_4.clk` | `sd_card_bmp_m0/rate_control$timer/limited_reg_syn_8.d[1]` |
| setup | -0.075 | `sd_card_bmp_m0/rate_control$timer/last_cycle_reg[7]_syn_4.clk` | `sd_card_bmp_m0/rate_control$timer/elapsed_reg[1]_syn_4.ce` |
| setup | -0.071 | `sd_card_bmp_m0/bmp_read_m0/scaling$loader/y_acc_reg[16]_syn_4.clk` | `sd_card_bmp_m0/bmp_read_m0/scaling$loader/pixel_reg[4]_syn_4.a[1]` |
| setup | -0.056 | `sd_card_bmp_m0/rate_control$timer/last_cycle_reg[7]_syn_4.clk` | `sd_card_bmp_m0/rate_control$timer/elapsed_reg[2]_syn_4.ce` |
| setup | -0.056 | `sd_card_bmp_m0/rate_control$timer/last_cycle_reg[7]_syn_4.clk` | `sd_card_bmp_m0/rate_control$timer/elapsed_reg[10]_syn_4.ce` |

该表来自工具每类端点上限 20 的路径报告，不把它宣称为无限制枚举全部物理路径。以全局 SWNS/STNS/HWNS/HTNS 判断通过与否。

## 剩余问题和下一步

现有 PHY-7002 两条、PHY-5079 一条仍需安路确认官方合封 SDRAM 的模型、位置和时钟资源。没有删除硬宏、修改相位或新增 false path。完整 CRITICAL-WARNING 计数：`{'OPT-6001': 3, 'PHY-7002': 2, 'PHY-5079': 1}`；相较基线新增计数：`{}`。OPT-6001 若出现，表示中间优化因当时负时序而中止，该警告不能写成全绿。本轮各完成构建无 coredump。

仅凭组合等价不能保证全设计时序改善，物理映射改变也会迁移最差路径。最终负路径必须按真实报告继续处理，不能把 `data_clusters/max_cluster` 当成单文件 24 位值截断，也不能通过裁剪画质、音频、MBR、输出模式或游戏来默认换取资源。功能取舍需另行获得用户明确同意。官方与实板待办见 [BOARD_PENDING](../../docs/BOARD_PENDING.md)，数学证明与复现步骤见 [技术说明](../../docs/FAT32_COMPARE_20261018.md)。
