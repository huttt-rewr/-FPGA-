# 键盘、多媒体与SD高速交付

源码功能与操作见[README](../../README.md)、[接线步骤](../../docs/CONNECTION_AND_USAGE.md)、[键盘教程](../../docs/KEYBOARD_USAGE_20261016.md)。候选bit及校验见[构建状态](../../docs/BUILD_STATUS.md)。

静态72源/40IO通过，80项完整ModelSim通过；0/6/14ns逻辑卡输出延迟覆盖；8192字节/36672个100MHz周期为22.338569MB/s模型吞吐。五个上层文件相对阶段四无差异，70位状态布局保持。

正式综合/P&R：SWNS +0.026ns，HWNS +0.022ns，TNS0。同一会话导出候选：SWNS +0.026ns，HWNS +0.022ns，TNS0。没有降100MHz、屏蔽功能路径或改必要官方IP，没有整体+0.5ns或HDMI管脚hold达标声明。

bit文件633116字节，SHA-256 `82f125e85700aaed1f270d7b9ca3e3229aa1e66b3a9d2d5be505425099d6dfa6`，源码提交 `5952318772ac12511f93c39d579cbdfe9ab2f188`。实板与外部IO均未验收；没有下载或写卡。精确哈希、文件边界及文档链接审计见[FINAL_DELIVERY.json](FINAL_DELIVERY.json)。

两轮失败时序仍保留：native50_initial（−0.245ns）和native50_indexcmp（−0.136ns）。修复为索引等价计算和文档支持的ultra布局优化，没有改受保护缩放器。较早路由DB重新导入导致时钟关联丢失的导出失败日志也保留；本次从绑定源码的gate DB在同一会话完整实现后导出，不沿用该失败STA。
