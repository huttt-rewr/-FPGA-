from pathlib import Path
R=Path(__file__).resolve().parents[2]
p=R/'docs/BUILD_STATUS.md';s=p.read_text(encoding='utf-8')
a=s.index('## 当前阶段二：');b=s.index('## 2026-10-16 PS/2',a)
s=s[:a]+'''## 当前阶段二：64文件索引（72项回归与STA通过）

正式源码启用BMP/WAV合计64文件、数字选图片、A+数字选音频、完整OSD计数与取消排空。切WAV清PCM队列及FIR/回声历史而保留48k样本调度，FIFO许可寄存并预留四槽。静态检查67源/38IO、72项ModelSim回归、综合/P&R/STA通过：**SWNS +0.131ns、STNS 0、HWNS +0.024ns、HTNS 0**。资源LUT15401、REG10239、BRAM9K61/64、DSP17、PLL2。[冻结清单](../reports/keyboard_20261016/phase2_room_validation.json)、[阶段报告](../reports/keyboard_20261016/RESULT_phase2_room.md)。70bit状态布局及下标保持。

R/F尚未正式消费请求。正式SD仍SPI25MHz，未生成本轮新bit、未实板，未达到整体+0.5ns。初轮及各时序失败版本均在本轮reports保留；内部recovery/removal没有当成HDMI管脚hold。没有降低100MHz或新增功能路径时序屏蔽。当前阶段二通过值只认证该阶段冻结源码。[多文件使用](MEDIA_INDEX_20261016.md)。

'''+s[b:]
s=s.replace('独立多文件实验（尚未登记正式TD）：','历史阶段一期间独立多文件实验（现已由阶段二正式接入）：')
p.write_text(s,encoding='utf-8')
p=R/'README.md';s=p.read_text(encoding='utf-8');a=s.index('阶段二正在验证：');b=s.index('\n\n',a)
s=s[:a]+'''阶段二已通过：BMP/WAV合计64文件索引、数字选图片、A+数字选音频、完整OSD计数、安全切音频及清音效历史。72项回归与综合/P&R/STA通过，SWNS +0.131ns、HWNS +0.024ns、TNS均0；新bit和实板尚未完成。R/F仍待下一阶段接入。[多文件操作与设计](docs/MEDIA_INDEX_20261016.md)，[精确验证状态](docs/BUILD_STATUS.md)。'''+s[b:]
s=s.replace('数字选文件与R/F暂时只锁存请求，尚未生效。','数字选文件已由阶段二接入；R/F暂时只锁存请求。')
p.write_text(s,encoding='utf-8')
p=R/'docs/USER_GUIDE.md';s=p.read_text(encoding='utf-8');a=s.index('阶段二多文件源码');b=s.index('\n\n',a)
s=s[:a]+'''阶段二多文件源码已完成72项回归及STA：BMP/WAV总上限64、数字选图片、A+数字选音频，原“四BMP、首WAV”仅属历史profile。[多文件操作](MEDIA_INDEX_20261016.md)解释选择、目录顺序与切音频；[构建状态](BUILD_STATUS.md)记录SWNS +0.131ns、HWNS +0.024ns及未实板限制。R/F尚未正式生效。'''+s[b:]
s=s.replace('数字和R/F尚只保存请求。','数字已接入；R/F尚只保存请求。')
p.write_text(s,encoding='utf-8')
p=R/'docs/KEYBOARD_USAGE_20261016.md';s=p.read_text(encoding='utf-8')
s=s.replace('只锁存 `image_index`，尚未选文件','阶段二已接入，0是第一张，9是第十张')
s=s.replace('只锁存 `audio_index`；2秒内输入数字，Esc取消','阶段二已接入；A后2秒内数字选前十WAV，Esc取消')
s=s.replace('当前正式 FAT32 枚举仍最多四张 BMP、第一份 WAV；文件索引扩展未完成前，不能说支持64文件或任选音频。','当前正式FAT32为BMP/WAV合计64份索引，左右遍历全部图片，数字直达前十图/A+数字直达前十WAV；不支持两位数字输入。')
s=s.replace('## 后续键位：现在不要当成已完成','## 数字选文件与待接入R/F')
s=s.replace('| 阶段一现状 |','| 当前现状 |')
p.write_text(s,encoding='utf-8')
print('Published exact accepted stage-two state; R/F remain explicitly pending')
