# 上板验收准备结果（2026-10-19）

**完成了电脑端候选与素材准备；Part 1四项实板检查待测，Part 2未开始。** 本次没有改RTL、工程清单、时钟、复位、引脚约束或70位status_source。

任务书明确规定先上板；当前会话没有连接板卡、显示器/下载器的可用硬件操作接口或人工实板观察，因此没有将任何一项记为通过，也没有进入转场/变焦、FFT和raw视频实现。

## 已完成

- 校验当前源码与上一轮冻结输入哈希一致：80源/40IO静态ALL PASS，原101项回归及冻结报告完整。无RTL变更，不重跑同样的101项。
- 原布线数据库SHA-256=`7a29118ed4f6ef99f466b83c1764736b7ec278716f0103f0190524a7be93b0ef`，与已通过构建绑定。
- 独立TD会话导入同一个DB，不重新布局/布线、不改时钟；bit生成前后分别报告内部STA，均为SWNS +0.044ns / STNS0 / HWNS +0.024ns / HTNS0，四种模式时钟均存在。
- 生成 [hdmi_640_plain_800_audio.bit](candidate/hdmi_640_plain_800_audio.bit)，635444字节，SHA-256=`c4981724248155ccba2226994ec3d1a9d7a6a118175ec2f7c48d6bf89c22646d`。
- 生成并用既有严格校验器检查7份BMP和1份48kHz/16bit/单声道WAV；只生成工程内普通文件，未写卡。
- 生成 [验收教程](../../docs/BOARD_ACCEPTANCE_640_20261019.md)、[实板记录表](BOARD_RESULTS.md)、[状态表](STATUS.json)与便携文件包。

## 当前基线与待测项

源码提交`f32e7c9`（RTL提交`ffc8584`）；LUT15785 / BRAM41 / DSP23 / REG10158。blue通道同步`{vs,hs}`低有效，复位h=0，VS下降沿之后的下一拍h=1，时钟图案0x01F；这些是代码设置，最终实板采用值仍待确认。

| 实板项目 | 状态 |
|---|---|
| 640静态图/OSD/原叠加，RGB颜色/无噪点/无偏移 | 待测 |
| 800图像与WAV出声、无爆音 | 待测 |
| 支持800设备协商 + 仅640设备回退 | 两类设备均待测 |
| R切换与复位，重新锁定、不卡死 | 待测 |

按照本次附件Part 1“上板未通过前，禁止进入Part 2”，等这四项的真实结果齐全后再进入新转场→变焦→FFT→raw视频。未对物理观测作推断。只有1920×1080面板型号，不能推断其EDID是否仅支持640；没有第二类设备时应保留未测。

640仍无HDMI音频；800图声与原连接保持。KEY/SW未加新功能，R仍由现有PS/2键盘控制。默认640，听WAV必须确认实际800，R:2但回退640仍无声。

既有PHY-7002/PHY-5079仍未解决，Speed=NA及外部IO未签核；内部removal不是HDMI管脚hold，未达到整体+0.5ns。降目标FPS不等于修复固定100MHz的setup违例。

## 文件与核验

- [候选清单](candidate/manifest.json)、[生成日志](candidate/bitgen.log)。
- [生成前STA](candidate/before_bit_timing_status.txt)、[生成后STA](candidate/after_bit_timing_status.txt)。
- [素材清单](media_manifest.json)、[预览](media_preview.png)、[素材目录](sd_files/)。
- [便携验收包](board_acceptance_640.zip)及[文件包哈希](package_manifest.json)。

```powershell
python reports/board_accept_20261019/prepare.py verify
```

修改前的README/用户手册/构建状态已备份到本目录`before/`。没有改写上一轮冻结报告中的历史“未生成bit”记录；当前候选状态在主文档顶部单独说明。
