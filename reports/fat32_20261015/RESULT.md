# FAT32 只读文件播放改造与验证

对应工程 `E:/fpga`，修改前基线 `e1425ee`，备份 `backups/fat32_20261015/before.zip`。操作说明见 [FAT32 使用教程](../../docs/FAT32_USAGE_20261015.md)。

## 实现范围

- 正式顶层启用 FAT32：512 字节扇区、MBR 首个 0B/0C 主分区或无 MBR 的 FAT32 卷；支持每簇 1/2/4/8/16/32/64/128 扇区。
- 枚举根目录短名，按目录条目顺序选择前四个 BMP 和第一个 WAV；扩展名大小写不敏感，跳过删除项、LFN、卷标和子目录。
- 根目录及媒体文件沿 FAT 簇链读取，支持碎片化。每流独立保留簇游标和 512 字节 FAT 缓存，共两块 BRAM9K；顺序读取避免每次从首簇重新查链。
- 保留 BMP 头校验、双线性缩放、写帧/双缓冲提交及 WAV RIFF/PCM 解析。音频仍限 48kHz、16bit、单声道，最大 16MiB；错误重试和诊断保持。
- 图片取消会排空当前物理事务。重新初始化清除旧分区基址，支持在仿真中从 MBR 卡切换至无分区表卷重新挂载。
- 读错、短扇区、越界索引/扇区、坏簇和提前链尾均有错误返回。根目录最多遍历 4096 簇；挂载错误使用原状态数码管显示 9/A/b/C，不新增管脚或状态总线字段。
- 仅现有 KEY/SW 控制，不增加 UART 控制、音频外设、文件菜单或写卡功能。

## 最终验证结果

最终冻结源码：静态检查 **ALL PASS（63 源、36 IO）**；完整 ModelSim **61/61 PASS**（包含三个 FAT32 专项）；综合与布局布线完成。实际 Routed STA：**未通过 setup 时序验收**。

| 项目 | 最终实际值 |
|---|---|
| SWNS / STNS | -0.695 / -3.539 ns |
| HWNS / HTNS | +0.021 / 0.000 ns |
| 资源 | LUT 15044、REG 10033、BRAM9K 59/64、DSP 17、PLL 2 |
| 回归 | 61/61；日志已冻结并记录 SHA |
| 构建完成时间 | 2026-10-16T01:07:58.426965+08:00（北京时间） |
| 实板 | 未写卡、未下载、未验收显示/出声 |

最差 setup 起点 `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/spi_wr_req_reg_syn_161.clk (rising edge triggered by clock sys_pll_m0/pll_inst.clkc[0]  { rise@0.000000ns  fall@5.000000ns  period=10.000000 })`；终点 `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/send_data_reg[2]_syn_4.ce (rising edge triggered by clock sys_pll_m0/pll_inst.clkc[0]  { rise@0.000000ns  fall@5.000000ns  period=10.000000 })`。负值表示尚未满足原100MHz约束；不能宣称已完成全部验收。 没有降低频率、添加 false path 或改变 PLL。旧 bit 不具备 FAT32 功能，候选生成情况见下文。未达到 +0.5ns。

证据：[构建清单](build_manifest.json)、[冻结 STA](timing_summary.txt)、[时序汇总](timing_status.txt)、[资源](physical_area.txt)、[保护范围与回归 SHA](scope_audit.json)、[完整回归控制台](regression_delivery.log)。冻结报告与当前源文件哈希一致，`audit_delivery.py --freeze` 会拒绝任何不一致。

后续工作：先复核TD时钟对象跨物理阶段/数据库重载的一致性，再对实际违例路径做不改变逻辑行为的物理优化；原SD栈与RIFF解析仍属本次保护范围。禁止用历史正余量替代本版STA。


报告列出的负setup路径如下（只列实际报告，不推测未报告路径）：

| Slack/ns | 起点 | 终点 |
|---|---|---|
| -0.695 | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/spi_wr_req_reg_syn_161.clk` | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/send_data_reg[2]_syn_4.ce` |
| -0.660 | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/spi_wr_req_reg_syn_161.clk` | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/spi_wr_req_reg_syn_147.ce` |
| -0.604 | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/spi_wr_req_reg_syn_161.clk` | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/spi_wr_req_reg_syn_133.a[1]` |
| -0.497 | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/spi_wr_req_reg_syn_161.clk` | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/send_data_reg[1]_syn_4.ce` |
| -0.383 | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/spi_wr_req_reg_syn_161.clk` | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/mux55_syn_78.ce` |
| -0.383 | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/spi_wr_req_reg_syn_161.clk` | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/spi_wr_req_reg_syn_145.ce` |
| -0.227 | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/spi_wr_req_reg_syn_161.clk` | `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/spi_wr_req_reg_syn_141.ce` |
| -0.090 | `sd_card_bmp_m0/wav_enabled$wav/is_fmt_reg_syn_10.clk` | `sd_card_bmp_m0/wav_enabled$wav/chunk_size_reg[1]_syn_3.ce` |


此前多轮真实负时序归档于 `trial_*`，均不能认证当前源码；流水/布局变更也出现过退化。最终源码包含几何运算拆拍、簇游标/边界比较寄存、独热并行译码、客户端反馈寄存、BPB/目录元数据流水、文件描述符独立写使能及FAT扇区校验/标签提交拆拍。

独立 `phys_opt -post_route` 的 relocation 与 reroute 试验均发生 TD coredump，没有可用结果，未采用其数据库。最新 reroute 在 Abnormal Timing Path check 崩溃，见 `reroute_trial.log`（minidump-20261016-002909.dmp）。重载已布线数据库并重新建立既有模式时钟的试验报告为SWNS -15.539ns，明显不同于正式构建进程内的STA；这属于尚未解决的时钟/数据库重载一致性问题，不能用它替换正式报告，也不能据正式报告声称数据库可独立重现签核。正式流程已去掉post_place后的冗余时钟绑定，避免已观察到的四条USR-8170重复定义告警。

剩余工具告警必须复核：PHY-7002合封SDRAM位置未被接受；PHY-5079指出 `U3/u2_ram/SDRAM_CLK` 使用局部布线；官方IP仍有未驱动端口/初值等综合提示；OPT-6001显示部分物理阶段因过大的负SWNS中止路径优化。不能把这些统称为无害警告。BRAM9K已用59/64，后续增加缓存或音效需先核算剩余容量。

两套仿真共用镜像目录，请串行运行；曾因同时重新生成镜像出现读取失败。最终交付重新完整运行61项回归，包含三个FAT32专项，覆盖清理空行后的最终RTL及现有仿真源。

## 测试内容

`tb_fat32_mount`：真实 FAT32 镜像挂载，MBR/superfloppy、spc=1/2、碎片根目录、过滤/数量/大小、坏签名、非法簇大小、短扇区、坏根目录链、合法目录 EOC、循环根目录上限，以及重新初始化后切换卷布局。

`tb_fat32_stream`：全部五个文件逐字节比对，碎片/连续文件、末扇区填充、回读文件头、WAV 循环、缓存命中、双客户端请求优先顺序、取消重读、错误文件索引、越界、坏簇、提前 EOC、SD 读错和短扇区、无 WAV 情况。

`tb_fat32_player`：实际 `sd_card_bmp` 调度器和原 BMP/WAV 解析器，仅替换物理 SD 卡。两张碎片 BMP 缩放至 640×480，每帧 307200 像素与独立 Python 双线性参考比较；并发 WAV 循环逐 PCM 样本比较，检查整帧提交、换图和缓冲索引。

Python 镜像生成器使用标准库生成 BPB、两个 FAT、FSInfo、备份引导、跨簇目录和碎片数据。`verify` 独立重读目录/FAT 链并核验原文件 SHA。`.img` 仅用于仿真，用户使用普通 FAT32 卡并拷贝文件。

## 构建入口与保护范围

两个 TD `.al` 工程入口和 `design_files.txt` 均登记 63 个源。TD 6.2.1 在本机通过 `open_project` 后 `elaborate` 发生 HDL 展平崩溃；命令行构建改为从同一清单生成绝对路径 `read_verilog` 文件列表，并读取原 ADC/SDC。后续综合、布局布线、STA 和产物哈希检查保持。布局后的物理映射会重建时钟对象，因此在布线前补调原 `adaptive_clocks.tcl`，与最终 STA 使用同一组既有模式时钟；没有改动该脚本、PLL、引脚、SDC 或时钟频率/例外。不能宣称 GUI 入口的综合流程已验证通过。

[范围审计](scope_audit.json) 对修改前 Git archive 逐源比较：允许更改仅 `top` 参数、BMP 文件索引封装、WAV 相对扇区地址、播放器中间层接入和 TD 工程登记；73 个原有源文件内容一致。归档和 Windows 工作区的 LF/CRLF 差异按规范化内容核对，同时保存工作区字节 SHA。原 SD 栈、仲裁器、官方 IP/PHY/PLL、约束、顶层接口及 70 位状态总线/CDC/OSD 均保持。

## 尚未验证与边界

未操作实体卡、下载 FPGA、验证真实显示器出声或签核板级电气时序。当前改造不支持 GPT、FAT12/16、exFAT、子目录、长名显示、文件排序/任意选择、写文件或热插拔自动重扫。FAT 缓存/目录元数据读取期间串行服务，音频优先发生在新虚拟事务选择时；极端碎片与真实慢卡的持续吞吐仍需实板验证。

损坏链会拒绝非法簇、直接自循环和提前 EOC；根目录有遍历上限。未实现文件链的完整多节点环检测，不宣称可识别所有损坏文件。仿真不包含官方加密 SDRAM/HDMI 核的完整板级行为。

任何内部 recovery/removal 均不能表述为 HDMI 管脚 hold；全局最小余量不代表外部 SD/DDC/TMDS 签核，也不宣称已达到 +0.5ns。旧版 bit 不包含 FAT32 功能。

## 复现命令

在 `E:/fpga` 中依次执行，避免同时运行两套仿真脚本：

```powershell
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_fat32_tests.ps1
python scripts/run_build.py
python reports/fat32_20261015/audit_delivery.py
```
