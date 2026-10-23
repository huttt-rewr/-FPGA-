# 菜单外快捷模式高亮提示（2026-10-23）

## 操作

菜单关闭时短按KEY3（B1）并松开，模式按“播放→亮度→对比度→播放”循环。
左上角以黄色32×32字模显示“播放”“亮度”或“对比度”，约两秒后消失。
连续切换显示最新模式并重新计时。上电默认播放模式，不主动弹出。

提示期间实际调整亮度/对比度，改显示原有参数数值浮窗，从调整时重新计时。
打开菜单取消提示；菜单进入/返回及长按开关菜单不会误切快捷模式。
界面变化只在帧边界提交，640/800模式沿用既有坐标适配与实际像素时钟。
KEY1/KEY2快捷动作、长按KEY3、全部媒体菜单不变；A2仍是整机复位。

实际RTL仿真输出（为便于查看放大三倍）：

![播放](play.png)

![亮度](brightness.png)

![对比度](contrast.png)

## 改动与验证

- 修改src/modules/osd/menu_overlay.v、src/top.v、scripts/run_tests.ps1；新增sim/tb_menu_mode_popup.v。
- 用现有70位状态快照的[35:34]接入模式，原总线位宽/位序不变；复用原定时器、字库与两拍RGB/VS/DE流水线。
- SD/BMP/WAV/FAT32/SDRAM、官方IP、引脚、时序约束和字库数据均未修改。旧版兼容实例默认关闭MODE_POPUP；正式顶层明确开启。
- static_check：ALL PASS，94源、40 IO bits。
- tb_menu_mode_popup：ALL PASS，真实KEY消抖及CDC、三个模式、68544像素独立字模参考、黄色2倍字号、两种时钟精确计时、连续切换刷新、帧内稳定、数值浮窗/菜单/复位优先级。
- 六项菜单专项全部ALL PASS；117项独立RTL主回归及10项Python工具测试全部通过。原始日志在main/、regression.log；清单及哈希见regression.json。主脚本打印ALL TESTS PASSED；本次外层PowerShell重定向将unittest标准错误中的“... ok”包装成NativeCommandError，外层退出码为1。逐项检查117份新鲜RTL日志均有ALL PASS、无FAILED/Fatal，两组Python为Ran 9/1 tests、OK；这是日志包装异常，不是声称该外层退出码为0。
- 综合/P&R/最终STA通过：SWNS +0.126ns、HWNS +0.021ns，STNS/HTNS 0.000/0.000ns；LUT 16673/19600、REG 11163、BRAM 57/64、DSP 23/29。资源在门限内，BRAM/DSP仍为57/23。
- 生成bit前后STA一致，源码快照、路由数据库及测试日志一致性检查通过。见bitstream/manifest.json与final_build/。
- 逐文件差异见changes.diff，范围检查见scope_audit.json；修改前文件和构建记录在baseline/。

## 新候选bit

[video_improve_mode_popup_20261023.bit](bitstream/video_improve_mode_popup_20261023.bit)，648248字节。

SHA256：`d3a9b61232baa61c5c6a6859b52328ba4b7e04909f2c71f1dc6ff4d203f5a941`。

下载这个版本才能看到新增提示，旧媒体菜单bit没有这项功能。未下载板卡、未实板验收，board_signoff=false，未达到整体+0.5ns；全局HWNS不是HDMI管脚hold签核。既有工具警告以实际报告为准，未宣称零警告。
