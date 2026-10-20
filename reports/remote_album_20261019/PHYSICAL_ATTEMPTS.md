# UART 阶段物理实现尝试

## 2026-10-20 22:20 后续核验

- 第四轮阶段三（热成像等价表、NEC分类寄存、本域复位叶、seed25）105项回归通过；最终SWNS +0.028ns、STNS 0、HWNS −0.234ns、HTNS −0.369ns，未通过。完整输入与报告冻结在`phase3_hold61_failed/`。
- 最差路径是`status_cdc/held[61]`到`status_cdc/dst_data[61]`，100MHz控制域到40/25MHz视频域的普通hold；不是HDMI管脚或复位removal。
- 独立`hold61_trial.tcl`尝试定向缓冲修复，四项指标不变，未采用。
- 独立`hold61_move.tcl`尝试移动发射寄存器，TD明确报告`Cannot find available slot`，未采用，不能称为位置修复成功。
- 下一轮保持RTL、时钟与约束不变，仅将正式布局seed改为35，重新执行完整门禁。最终结果以新的验证JSON为准。

## 2026-10-20 同步ROM及状态快照短路径

- 2026-10-21第四阶段为media_cdc启用编码后最终通过：108项，SWNS +0.142ns、STNS0、HWNS +0.024ns、HTNS0，冻结`phase4_pass/`。最终物理LUT17283、REG11014、BRAM45、DSP26；不是综合LUT16626。保护文件及status70核验通过，无新增critical warning，没有新bit或上板结论。

- 第三阶段编码状态快照版最终通过：105项，SWNS +0.061ns、STNS0、HWNS +0.021ns、HTNS0，冻结`phase3_pass/`，提交e1c0e10。
- 第四阶段首次108项回归全通过，最终SWNS +0.038ns、STNS0、HWNS −0.234ns、HTNS −0.369ns，未通过。剩余为`media_cdc/held[7]`→`dst_data[7]`普通hold。冻结`phase4_media_hold_failed/`，仅为该29位快照启用同一可选编码，再执行全部门禁。媒体读取文件未修改。

- 同步ROM版105项通过；综合LUT 16299/19600、BRAM44/64、DSP26/29。最终SWNS +0.084ns、STNS0、HWNS −0.234ns、HTNS −0.369ns，仍未通过，冻结`phase3_bram_hold61_failed/`。
- 状态快照的`held[61]`→`dst_data[61]`短路径经TD全局/定向hold fixer均无法修复，未放宽约束。
- 增加`cdc_snapshot.ENCODE_HOLD`可选编码，默认0，仅status_cdc设1。源侧保存取反数据，目的侧还原，显式保留解码组合逻辑；不改变70位status_source表达式、位序、发布值或握手延迟。
- `tb_cdc`新增编码/原版逐拍对照并通过；独立TD综合接受条件保留属性，确认70条keep逻辑。随后重新执行105项完整门禁，最终结论仍以验证JSON为准。

## 后续检查点

- 阶段一seed25+routability：103项通过；最终SWNS +0.243ns、HWNS +0.021ns，TNS均0。
- 阶段二同策略：104项通过；最终SWNS +0.142ns、HWNS +0.024ns，TNS均0。
- 阶段三首次同策略：105项通过；最终SWNS −0.397ns、STNS −2.052ns、HWNS +0.024ns、HTNS 0，门禁失败。
- 失败冻结phase3_seed25_setup_failed/。最差effects/out_rgb[6]→pixel_filter/xp1[8]，svga_pixel普通setup，15级算术（含两级MULT18），不是HDMI管脚hold。
- 阶段三补主机a命令与整链默认旁路覆盖，重新跑105项和seed30完整物理构建；不放宽时钟、不改约束或受保护源。最终以验证JSON为准。

## 阶段一历史尝试

阶段三热成像查表+seed25：105项回归全部通过，综合LUT16,532、DSP26、BRAM41。路由后setup仍−2.542ns，最差变为红外duration_us→bit_cnt，8级逻辑，网线占76%。保持修复运行20分钟仍无setup改善，人工结束本轮自己的implement进程，记录为interrupted/failed而不是最终通过，冻结phase3_luma_ir_setup_interrupted/。没有将旧hold_finalization.log当作本次最终证据。

随后把NEC时长分类与匹配边沿一起寄存，FSM消费延迟一拍的分类；阈值不变。独立库以原版作为逐拍参考，覆盖原标准包、重复码、错误反码和阈值边界，tb_ir_nec_rx/tb_remote_ir通过。remote控制簇新增本域复位释放叶，减少原高扇出复位网负担；随后重新启动105项全量门禁。

阶段三seed30最终失败：SWNS −0.018ns、STNS −0.020ns、HWNS −0.234ns、HTNS −0.738ns。两条setup在SD PHY和原缩放器，短路径为status_cdc/held→dst_data的真实hold；没有屏蔽。冻结phase3_seed30_timing_failed/。

随后仅对pixel_effects的heat→weighted_luma复合函数建立256项精确常量表。保持热成像RGB、亮度量化、共享模糊结果和三拍延迟；tb_pixel_effects增加全部256个灰度的独立整数参考。回到阶段一、二已成功的seed25，重跑全量门禁。这项修改释放第二级亮度乘法并截短原15级setup链，没有修改媒体、存储、官方IP或70位状态。

所有尝试采用相同阶段一 RTL、原 100MHz 控制时钟与 25/40MHz 显示时钟；没有增加 false path、放宽周期或修改受保护媒体模块。

| 尝试 | 布线 | 最终内部 STA | 证据目录 |
|---|---|---|---|
| more_lut_pair / pr_strategy 1 | PHY-8023：FAT32 target_index/mux、加载器/FAT 复位共享资源冲突 | 未完成，不能引用中间值 | phase1_route_failed |
| pr_strategy 0 | 同两处冲突 | 未完成 | phase1_route2_failed |
| pr_strategy 2 | 同两处冲突 | 未完成 | phase1_route3_failed |
| pr_strategy 1 / seed 5 | 完成布线与独立 hold 收尾 | SWNS −0.257ns、STNS −0.257ns、HWNS +0.021ns、HTNS 0 | phase1_seed5_setup_failed |
| pr_strategy 1 / seed 10 | PHY-8023：osd/file_image_count[5] 与 reset_video/sync_ff[2] 冲突 | 未完成 | phase1_seed10_route_failed |
| seed 5 / route timing greedy | 完成布线与独立 hold 收尾 | SWNS −0.257ns、STNS −0.257ns、HWNS +0.021ns、HTNS 0；与普通路由相同 | phase1_seed5_greedy_setup_failed |
| seed 15 / place opt_timing high | PHY-8023：SDRAM 读写网络与帧写入网络局部连接冲突 | 未完成，路由中间时序也恶化 | phase1_seed15_high_route_failed |
| seed 5 / adaptive_pin_density | 完成布线与独立 hold 收尾 | 与 seed5 相同，SWNS −0.257ns / HWNS +0.021ns | phase1_adaptive_setup_failed |
| balance_explore 映射 / seed5 | 完成布线与独立 hold 收尾 | SWNS −1.516ns、STNS −59.630ns、HWNS +0.020ns、HTNS 0 | phase1_routability20_before |
| 面积映射 / seed20 / routability | 完成布线与独立 hold 收尾 | SWNS +0.104ns、STNS 0、HWNS −0.417ns、HTNS −0.728ns | phase1_routability25_before |

seed 5 的最差 setup 为 SD PHY half_cycles → crc1 寄存器 CE，6 层逻辑，网线约占数据延迟 74%；这反映整机重新布局后的布线变化，不代表 UART 命令功能仿真失败。它也不是 HDMI 管脚 hold。

TD 本地官方 `doc/scripts/MultiSeed.tcl` 使用 `set_param place seed $seed`；`doc/SWUG/SWUG105_TCL_Command_User_Guide.pdf` 中 route timing 允许 normal/off/greedy。当前继续尝试官方 adaptive_pin_density 打包选项，以降低局部连线密度；只有最终构建清单 status=completed 且四个时序指标非负，才算通过。

103 项 ModelSim 回归仍是阶段一 RTL 的有效软件证据，不能替代失败的物理门禁。阶段二至四候选脚本尚未运行。

seed20 剩余最差 hold 是 `reset_mem/sync_ff_reg[2]` → `frame_read_write_m0/rd_underflow_sticky.sr`，类型 **removal**。内存域同步释放的复位直接用于像素域 sticky 诊断，是原有连接；本任务中内存模块未修改。当前继续种子25物理实现。没有把 removal 称为 HDMI 管脚 hold，也没有屏蔽这条路径。


阶段三seed35最终SWNS −0.181ns、STNS −0.181ns、HWNS +0.020ns、HTNS 0，105项通过；WAV position→position_ok setup未通过。冻结phase3_seed35_wav_setup_failed/。随后将新增自动色阶的三路倒数表改同步ROM，四拍延迟和逐值结果通过独立原参考验证，再执行完整门禁。未修改WAV或约束。
