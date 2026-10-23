# 2026-10-08 队友工程择优合并

> 2026-10-09 资料核对补充：本次仅完善文档，本文记录10月8日综合/P&R和回归；后续10月9日 [字幕转场版](EFFECTS_20261009.md)已有新构建。官方资料补充了SDRAM10拍读返回、持续写入频率条件、busy说明矛盾及BG256供电限制，未证明这些待办已解决；必要官方IP保留。根.al被TD保存后的CompileOrder差异不由本轮覆盖，见 [构建状态](BUILD_STATUS.md)和 [官方资料对照](VENDOR_REFERENCE_20261009.md)。

输入：本地 `E:/fpga` 与队友 `E:/2/fpga`。没有直接覆盖整个工程。两份工程的15个源文件有差异；官方IP、管脚/时序约束、两个TD入口均相同。当前根目录和扫描到的子目录没有AGENTS.md；已阅读历史修订文件。

## 合并与保留

| 文件 | 决策与原因 |
|---|---|
| bmp/bmp_read.v | 采用扇区停滞检测，改为可配置阈值并接入上层恢复；采用640×480格式约束，与固定921600像素字节长度一致 |
| bmp/sd_card_bmp.v | 采用确认/写完成同步器标记；接入停滞与传输错误；拒绝队友“commit超时视为成功”的做法，改为报错、保留忙与缓冲所有权，等待真实确认或整机复位 |
| sd/sd_card_cmd.v | 采用S_INIT缺else修正和等待超时思想；修正阈值说明，独立计算token/写响应/写busy等待预算，错误经上层传播 |
| sd/sd_card_sec_read_write.v | 采用8秒初始化、1秒暂停重试；保留本地init_error端口兼容性；使用32位计数防止固定切片截断参数；增加扇区传输错误输出 |
| sd/sd_card_top.v | 暂停期间同时复位命令层和SPI层，避免上层重试但底层仍执行旧命令；传递参数和错误端口 |
| control/ir_nec_rx.v、uart_rx.v | 采用已有单比特同步链async_reg标记；属性本身不证明CDC或物理实现签核 |
| video/edid_base_check.v | 采用停滞超时；补充started门控，忽略开始之前的杂散字节；参数化便于验证 |
| memory/frame_read_write.v | 保留本地FIFO边界诊断，拒绝队友删除这些端口/监测的版本；诊断目前未接入顶层可观测输出，不宣称已可在板上直接读取 |
| memory/frame_fifo_read.v、frame_fifo_write.v | 保留本地版本；只加async_reg不能证明多位元数据一致性，也不解决固定10周期读完成假设 |
| hdmi/lane_lvds_10_1.v | 保留本地串行器；相关PLL时钟间的采样关系需按其时序契约分析，不当作普通异步状态链随意更改 |
| video/video_delay.v | 保留本地延迟说明，队友仅删注释 |
| video/video_rgb_to_axis_640x480.v | 保留本地；本地已具备排空/场边界清除溢出的行为，队友仅改注释 |
| top.v | 保留本地；视频显示有效来自frame_swap，队友增加的sd域display_valid线未被消费，不引入无用途连接 |
| README.md | 不复制队友关于未提供文档、历史备份及自动恢复的未验证声明，更新为本次真实行为与证据 |

## 修复边界

初始化失败会周期重试；扫描失败会重新初始化后重扫。已有索引的图片加载失败保留显示帧和索引，用户可n/b重试。更换内容不同的卡须整机复位重扫。切帧确认超时保持忙是有意保护，不是已实现取消/撤回事务。真实迟到ack仍被接受；永久丢失ack需整机复位。

SDRAM固定等待、板级IO约束、PHY警告、官方加密核全链路验证仍是待解决项；必要官方IP全部保留。没有修改PLL、ADC、SDC，没有新增false path或声称HDMI管脚hold已达+0.5ns。

## TD与验证

两个工程入口 `video_improve.al`、`src/td_project/video_improve.al` 原本已引用全部被合并的模块，仍为44个设计源。文件在原路径更新即可被TD重新分析；无需重复添加同名模块。`scripts/design_files.txt` 与两个入口通过静态一致性检查。测试台只进入ModelSim，不进入综合源集。

新增四项故障测试：SD token/写响应/写busy超时及真实包装重试；EDID停滞/恢复；BMP扇区停滞；换帧确认超时/迟到确认/缓冲保护。扩展初始化看门狗和扇区错误传播测试。完整回归共21项。最终构建数据见 `reports/build_manifest.json`；结果核验见 `reports/team_merge_20261008/verification.json`。

已完成21项模块回归、官方PLL模型回归、8项图片工具测试及TD综合/布局布线。TD实际打开两个工程入口成功，日志为 `reports/team_merge_20261008/td_open.log`。

最终内部STA：SWNS +0.193 ns、HWNS +0.003 ns、STNS/HTNS 0。最差setup从BMP的rd_cnt[7]到sd_sec_read_addr[4]的CE；最差min从HDMI核EDID/IIC bit transmitter的O_bit_tx_ready寄存器时钟端到内部sr端，类型removal。相较10月7日setup余量变小，本次合并改善异常处理但未证明时序改善。未达+0.5 ns，未生成bitstream或上板。

仍有两条PHY-7002和一条PHY-5079；check_timing包含7个无input delay、24个无output delay、32个abnormal input delay检查项。报告Speed=NA，不能据此宣称I7/板级签核。新增sd_card_cmd参数列表引出工具将模块内状态parameter视为localparam的说明性警告；状态编码未开放给外部覆盖，功能回归通过。已有官方加密IP内部未驱动/位宽及PLL悬空反馈端等警告仍保留，未擅改加密IP。

## 备份与对比

修改前205个文件保存于 `backups/before_team_merge_20261008/workspace.zip`，逐文件SHA-256验证通过；同目录manifest记录校验值。备份包含源码、工程、脚本、文档与选定报告，不包含仿真库/数据库等可重建产物。历史备份缺失不以本次备份替代说明。

`reports/team_merge_20261008/comparison.json`、`team.diff` 是合并前比较证据。队友目录未修改。最终改动清单和IP保留核验由verification.json记录。
