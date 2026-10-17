# 贪吃蛇增量交付结果（2026-10-17）

## 结论

游戏功能已接入正式源码并完成仿真；**整机物理验收未通过，本轮没有新 bit**。

| 检查 | 实际结果 |
| --- | --- |
| 静态检查 | ALL PASS，76 设计源，40 顶层 IO 位，两份 TD 源登记一致 |
| ModelSim 10.1c | 最终源码完整 88 项 ALL PASS，原 85 项及新增 3 项均通过 |
| 游戏独立综合 | 1,386 LUT、137 寄存器、0 BRAM、0 DSP |
| 整机综合 | 成功；19,483/19,600 LUT、11,676 寄存器、61/64 BRAM、17 DSP |
| 布局 | 失败，PHY-9009：5,252 MSlice 超过 4,900，超出 352，约 7.18% |
| 布线与当前 STA | 因布局失败未执行完成，无有效当前 SWNS/HWNS |
| 当前 physical_area.txt | 未生成，不能拿旧文件代替；上述整机计数来自当前 gate_area.txt |
| 新 bit / 上板 | 未生成、未下载、未进行实板游戏验收 |

完整工程的基础版本此前也未通过物理验收。本次保留现有效果和官方 IP，没有为了让计数变小而关闭已有功能。附件所谓“还有约 3900 LUT”的余量与现有工程不符。

## 做了什么、怎么使用

G 进入或退出，方向键控制，禁止掉头；碰撞后 GAME OVER，退出再进入重开。每六帧一步，约每秒十步。游戏内方向键不翻图、不调音量；其他 KEY/SW 和媒体功能继续使用原接口。游戏区外画面原样通过；支持当前 VGA/SVGA 两种输出。

棋盘使用 LUT RAM；蛇身用 2 位方向步进环形 FIFO，尾巴保存独立坐标；三块 256 深度 RAM 避免填充到 1024。游戏更新在垂直消隐完成，渲染和规则查询共用棋盘读口。分数十进制进位不在像素路径做除法，LFSR 食物搜索遇占用后顺序扫描，满盘时结束本局。

新增 [详细使用与设计手册](../../docs/SNAKE_GAME_20261017.md)，两份 TD 工程、命令行设计清单和 ModelSim 回归清单均已登记。顶层在 status_osd 后重新生成同拍坐标，再插入固定一拍游戏输出。

## 测试覆盖

- tb_snake_game：区域内外颜色、边框、蛇与食物、GAME OVER 字形、固定一拍 RGB/VS/DE、高有效复位、禁止掉头、增长、合法新食物、撞墙/撞身冻结、进入正在移走的尾格、768 项队列回绕。
- tb_snake_controls：G 的 make/break 和自动重复隔离、四方向按住/松开/优先级、独立 5 位控制 CDC、每六帧节拍、游戏内外方向键媒体功能切换、接收错误清除按住状态。
- tb_snake_pipeline：VGA/SVGA 开启与旁路，共 1,574,400 个有效像素，检查逻辑视口坐标、居中区域边界、像素和同步信号。
- 原图像、音频、SD、FAT32、视频模式等 85 项全部保留并通过。日志有既有缺省端口等警告，不将“PASS”解释为零警告或硬件验收。

## 资源优化与证据

游戏独立综合先后为 3,406 LUT（10 位坐标队列）、1,968 LUT（2 位方向队列）、1,688 LUT（256 深度分块）、1,386 LUT（棋盘单读口分时）。第一版到最终版减少 2,020 LUT，约 59.3%。各阶段 BRAM/DSP 均为零。中间阶段计数为开发测量；最终计数由本目录当前独立综合报告绑定最终源哈希。

第一次完整构建为 19,768 LUT、5,342 MSlice；最后为 19,483 LUT、5,252 MSlice。单读口优化节省 285 个整机 LUT、90 个 MSlice，但仍不能装入芯片。

LUT 计数不是 MSlice 可放置计数：分布式 RAM、寄存器及共享控制的装箱条件限制会造成 MSlice 超限。继续落地需要对既有 OSD/滤波等链路做保持效果一致的面积压缩，至少减少当前超出的 352 个 MSlice，并重新完成布局、布线和 STA；不能靠复用旧 bit 或旧正时序报告解决。

本轮没有新的有效时序值，不宣称 +0.5 ns，也不把内部复位 removal 检查当作 HDMI 管脚 hold。

## 可复核文件

- [validation.json](validation.json)：88 项测试、当前构建结论、全部构建输入哈希、证据哈希。
- [scope_audit.json](scope_audit.json)：84 个受保护源哈希一致；70 位 status_source、status_video 下标一致；移除游戏插入后 top 完全等于备份。
- [final_build/gate_area.txt](final_build/gate_area.txt)：最终整机综合面积。
- [final_build/implementation.log](final_build/implementation.log)：最终 PHY-9009 布局失败。
- [game_gate_area.txt](game_gate_area.txt)：独立游戏资源统计，BRAM/DSP 为零；不是物理或时序签核报告。
- [verified_simulation](verified_simulation)：最终 88 项通过日志；[regression.log](regression.log) 为全量执行记录。
- [two_read_port_failure](two_read_port_failure)：第一轮整机失败的源版本、面积与日志。
- 改前备份：`backups/snake_20261017/before.zip`，保留 388 个工程/测试/文档文件，没有删除旧源或官方 IP。
