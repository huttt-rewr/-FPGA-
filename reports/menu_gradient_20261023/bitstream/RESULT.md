# 彩色渐变中文菜单 bit 生成记录（2026-10-23）

已从本轮渐变菜单源码对应的最终路由数据库生成新的候选bit，未下载到板卡。

- 文件：[video_improve_menu_gradient_20261023.bit](video_improve_menu_gradient_20261023.bit)
- 大小：648248字节。
- SHA-256：`de79a3fdcec39c34782e2a006797fd2efc58f7adce2c2ce226f957ecb5fd431a`。
- 器件：Anlogic EG4S20BG256；工具：TD 6.2.1。
- 本次可见变化：中文菜单非选中区域增加27级蓝→青→紫→品红→粉垂直渐变；选中行暗底、文字颜色、KEY操作和原有流水延迟保持不变。
- 验证：静态检查94源/40 IO通过，113项RTL主回归全部通过，9项AVF Python与1项字体Python测试通过；VGA/SVGA菜单专项逐像素测试通过。
- 最终物理资源：LUT 16370/19600、BRAM 57/64、DSP 23/29。

生成前后均使用完整模式时钟定义进行STA，四个模式时钟vga_pixel、svga_pixel、vga_serial、svga_serial均存在。实测结果如下：

| 项目 | 生成前 | 生成后 |
|---|---:|---:|
| SWNS | +0.185ns | +0.185ns |
| STNS | 0.000ns | 0.000ns |
| HWNS | +0.021ns | +0.021ns |
| HTNS | 0.000ns | 0.000ns |

首次seed25布局出现SWNS -0.016ns，未用于生成bit。随后保留全部RTL、官方IP、引脚、时钟与约束，以seed26重新进行物理布局布线及独立hold修复，最终setup/hold均通过。最初失败报告保留在[seed25目录](physical_refinement/seed25_failed/)，最终报告保留在[本轮final_build](../final_build/)；重布线脚本及日志保留在[seed26目录](physical_refinement/seed26/)。

生成前确认113份回归日志新鲜且均ALL PASS，原综合网表匹配初次构建哈希，最终路由数据库和当前源码快照匹配构建清单；生成后再次验证源码、数据库和构建清单未变化。完整记录见[manifest.json](manifest.json)、[bitgen.log](bitgen.log)、[生成前STA](before_bit_timing_status.txt)及[生成后STA](after_bit_timing_status.txt)。

流程中仅根GUI工程video_improve.al的快照发生变化；全部src/scripts/sim实际构建输入哈希一致。综合脚本直接读取design_sources.tcl、ADC和SDC，不以GUI工程XML决定综合网表；当前GUI工程的器件、顶层、94源及引脚另经静态检查一致。保留最初清单并显式记录此差异，未把未知XML字节差异声称为已逐项复原，见[项目核验记录](project_reconciliation/audit.json)。

旧纯色菜单bit保留，SHA-256仍为`8adca4fa174de0a120c3eb22d8d5537edf300a31453e267250accdd71f4abcad`，未被新文件覆盖。

`board_signoff=false`，`hardware_download_performed=false`。本轮未下载到板卡或做硬件验证；未达到整体+0.5ns。内部全局HWNS不能当作HDMI管脚hold签核；既有PHY-7002/PHY-5079警告仍保留。
