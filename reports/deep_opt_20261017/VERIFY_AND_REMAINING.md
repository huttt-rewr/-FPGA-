# 验证与未完成事项（2026-10-18）

当前选定第11轮合法路由候选；完整说明和具体端点见[RESULT.md](RESULT.md)。所有输入SHA与该轮manifest一致，第12/13轮分别路由冲突和STA更差，已归档。

已通过：77源/40 IO静态检查、91项ModelSim、保护文件/HDMI实例/70位状态总线与20处取位审计、合法布局布线及对应数据库导出。

尚未通过：物理17,347 LUT超过16,660目标687个；SWNS −0.402ns（音频FIFO复位recovery），普通setup −0.401ns；58 BRAM是90.625%，不等于严格≤90%。全局min +0.021ns、HTNS0，不能宣称整体+0.5ns或HDMI管脚hold通过。

TD后布线phys_opt重复coredump；当前流程用先保存route证据、独立fix_hold、最终完整STA。没有削减功能或修改保护范围以凑时序。原始100MHz控制、双模式视频时钟与时序例外保持。

无本轮bit、下载或实体卡/显示器/声音/吞吐验收。README、BUILD_STATUS、USER_GUIDE均已标明此限制。
