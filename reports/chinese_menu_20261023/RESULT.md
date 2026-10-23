# 中文分级菜单改造验收

本轮范围：中文八项菜单、按键LIST/EDIT状态机、可复现字体、顶层显示连接及配套测试。工作区原有其他修改不属于本轮，未还原或打包提交。

## 功能与使用

- 默认关闭旧四行英文常显面板。长按KEY3约1秒开关中文菜单。
- LIST中KEY1上移、KEY2下移，八项循环；选中行32×32黄色，其他行16×16灰色。
- 播放、伽马、静音、诊断在KEY3短按时直接切换；亮度、对比度、音量进入EDIT，KEY1减、KEY2加，KEY3短按返回。
- 亮度-64～+63，步进8、端点饱和；对比度2～8；音量0～16。
- 退出项短按关闭，任何项及EDIT中均可长按KEY3关闭；长按不会额外触发短按。
- 默认CHINESE_MENU=0保留已有模块契约；正式top选择1。键盘与红外仍修改同一组参数寄存器。

操作手册：[CHINESE_MENU_20261023.md](../../docs/CHINESE_MENU_20261023.md)。

## 字库与视频流水

完整77字、1232个16bit word，原0～31字的512word逐字节保留；SHA-256为`fdb922b8775a74f73ebc471632e15ac5f8bb2d8c96658a2b908b8a6ed026a736`。新增31个中文、14个数字和符号。字库全部为内嵌initial，无readmemh。

`gen_zh_font.py`读取旧512word并生成新增SimHei16字形，同时输出mem和RTL。字体来源及摘要见`font_verification.json`。默认BANK=0保留完整表；标语BANK=1、菜单BANK=2只实例化各自使用部分，测试逐word验证与完整表一致。

menu_overlay为两拍RGB/VS/DE同步流水，VS下降沿锁存参数；640逻辑视口的选中字严格按2×2复制。800×600复用已有坐标适配。原70位status_source布局不变，菜单EDIT状态独立CDC。

## 验证状态

最终验收通过，源码哈希与本轮build_manifest一致。最终完整构建于北京时间2026-10-23 09:15完成，主回归随后完成并返回ALL TESTS PASSED。

| 检查 | 真实结果 |
|---|---|
| 静态检查 | ALL PASS：94 sources、40 IO bits，端口/引脚/TD清单一致 |
| 主ModelSim回归 | 113项全部ALL PASS，退出码0；逐项日志在main/，索引与摘要在main_regression.json |
| Python测试 | 9项AVF转换工具测试、1项字体完整性测试全部OK |
| 中文按键新测试 | ALL PASS tb_chinese_menu：八项LIST/EDIT、长短按、限幅、原快捷操作和唯一参数寄存器 |
| VGA菜单新测试 | ALL PASS tb_menu_overlay：10个完整帧，3072000像素，2倍文字/状态、帧锁存、旁路、RGB/VS/DE对齐 |
| SVGA补充测试 | ALL PASS tb_menu_overlay_svga：经实际viewport_coordinates，10个800×600帧、4800000像素；见tb_menu_overlay_svga.bank.log |
| AVF补充测试 | tb_av_native的VIDEO_FORMAT=0/1/2各两帧全部ALL PASS；见tb_av_format0/1/2.log |
| 综合/P&R/最终STA | python scripts/run_build.py返回0，manifest.status=completed |
| 时序 | SWNS +0.156ns，HWNS +0.024ns，STNS/HTNS均0；100MHz主控，Fmax 101.585MHz |
| 物理资源 | LUT16281/19600（83.07%），REG11097/19600，BRAM57/64，DSP23/29，PLL2/4，GCLK4/16，PAD44/188 |
| 与native640基线比较 | SWNS从+0.038ns增加到+0.156ns，HWNS保持+0.024ns；LUT减少737，BRAM增加2，DSP不变 |

最终报告在final_build/，机器可读结果见verification.json。主回归已原样包含用户列出的tb_osd_text、tb_picture_controls、tb_board_osd、tb_board_pipeline、tb_caption_overlay、tb_zh_overlay和tb_album_clock等测试。

首轮未裁剪字体的构建：LUT16301、BRAM59、DSP23，SWNS=-0.204ns、HWNS=+0.022ns；仅一条setup违例，FAT32的meta_index到ext0，四级LUT、数据布线延迟占87%。原始报告保存在`attempt1/`，没有改FAT32或放松约束来掩盖该结果。

最终字库裁剪后重新进行完整综合/P&R/STA，并重新运行全部主回归，结果全部通过。字库裁剪使本轮最终BRAM由首轮59降至57；这次布局也消除了首轮FAT32布线setup违例，没有改变FAT32逻辑、SD时钟或约束。以最终`verification.json`和`final_build/`为验收依据。

## 不变性与边界

`protected_sources.json`记录44份SD/BMP/WAV/SDRAM/官方IP/约束的基线比较，`original_tests_unchanged.json`记录115份原测试台摘要，均无变化。原70位status_source的声明与拼接逐字符相同。测试没有通过修改旧断言获得通过。完整本轮差异见`changes.diff`，基线副本在`baseline/`。

后续已于2026-10-23生成[包含中文菜单的新候选bit](bitstream/video_improve_chinese_menu_20261023.bit)，648248字节，生成前后STA及源码/数据库校验一致；详见[bit生成记录](bitstream/RESULT.md)。主验收verification.json中的new_bitstream=false记录的是生成bit之前的验收时点，最新生成状态以bitstream/manifest.json为准。上一轮native640候选bit保留且不含菜单。尚未上板；内部HWNS不是HDMI管脚hold签核，不声明整体+0.5ns。既有PHY-7002（SDRAM位置约束）及PHY-5079（SDRAM时钟使用局部布线）仍在，外部IO及实板验收仍需单独处理。

若后续提交本轮改动，提交信息需保留：

```text
Co-Authored-By: Claude Code <noreply@anthropic.com>
```
