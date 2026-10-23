# 保留功能的资源与代码优化（2026-10-18）

本轮基线为提交 `2e31b55`：包含双分辨率 HDMI 内嵌音频、PS/2、KEY/SW、图片缩放、字幕、转场、四种像素特效、毛玻璃、波形和贪吃蛇。基线综合 19,483 LUT、61 BRAM；布局因 5,252 MSlice 超过 4,900 失败。附件里的 18,048 LUT 属于更早版本。

本轮按“保留全部功能”实施等价优化，未采用限制源图到1024、最近邻替换、删除MBR、取消FAT16拒绝检查或关闭界面的建议。按键、拨码、WAV格式、源图范围和连接方式保持原手册定义。最新整机验收数值以本轮 RESULT 与源码哈希清单为准；下面独立综合数字不能相加冒充整机结果。

## 图片缓存：先水平插值，再存输出列

文件：`src/modules/video/bmp_scale_loader.v`。

原先每个源图行缓存2048个24位像素，两行容纳1920宽源图；输出每个像素时分别做两次水平混合，再做垂直混合。现在顺序读取源行，用相邻两个源像素为每个输出列做水平混合，把结果存入两行1024深度缓存。最大实际输出宽度800，因此仍能读取1920×1080源图。双线性Q8逐级舍入顺序相同，没有把源图宽度限制到1024。

旧缓存 `2×2048×24`，新缓存 `2×1024×24`；独立综合 BRAM 13→7。水平乘法流水复用为一套，垂直流水保留。输出仍居中、等比补黑，底朝上交给既有写帧器；valid/ready背压、错误和中止重载路径保留。代价是横向采样改为在源行装载阶段执行，装载周期分布有变化，不能据资源结果宣称实际换图更快。

恢复余数除法器仍每拍推进一位。最大分子 `(1919<<16)`，可用28位商；合法分母不超过1920，使用12位分母、13位余数。配置计算32轮变为28轮，未改Q16坐标和端点对齐。

## 像素窗口：连续光栅预取与BRAM

文件：`src/modules/video/pixel_effects.v`、`video_luma_window_bram.v`。

保留原LUT窗口实现，新增 `BRAM_WINDOW` 配置；顶层启用BRAM版本。同步RAM在当前列预读下一列，行消隐预读第0列，使处理当前像素时前两行同列数据已就绪。两块BRAM取代大量LUT RAM；不清空RAM，以每帧前两行/前两列的valid屏蔽未定义历史。

仅适用于连续递增的物理光栅x，本工程由 `video_coordinates` 提供。不能直接接跳列或任意坐标请求。四种特效仍三拍，灰度和3×3和与RGB/VS/DE对齐。完整VGA/SVGA四模式新旧比较覆盖3,148,800有效像素。

灰度仍为 `floor((77R+150G+29B)/256)`，显式乘法与 `dsp_style="yes"` 引导TD用DSP替代移位加法；反色小数借位和热成像颜色不变。独立窗口对比为2368→612 LUT、增加2 BRAM；进一步灰度DSP版本为481 LUT、增加3 DSP。整机需单独测量。

## 波形缓存：存绘制坐标，保持两拍

文件：`src/modules/video/audio_visualizer.v`。

保留 `BRAM_HISTORY=0` 的原PCM历史实现；顶层启用1。接收PCM时，按原有绝对值/幅度公式计算局部纵坐标并存入同步BRAM。读取的RAM寄存输出直接替代原 `trace1` 寄存器，因而保持两拍像素延迟；不增加预读假设、不改音频采样节奏。默认80像素高只需7位坐标。

填充/显示仍用两个bank，场边界交换，确保当前显示帧不被实时音频更新破坏。未改变PCM、音量、静音、48kHz均匀出样或HDMI核。单独综合470→178 LUT、0→1 BRAM；比较覆盖正负极值、全部8位PCM值、VGA/SVGA整帧、切bank、开关和复位。

## FAT32与BMP检查：保留安全边界

文件：`src/modules/sd/sd_fat32.v`。

BPB中的root_entries、fat16_size和fs_version只用于判零，各16位变成两个“该字节非零”标志，48位变6位。每次接收字节覆盖对应标志，不做永久粘滞OR，支持坏卡后重新挂载好卡。FAT12/16拒绝、MBR分区、superfloppy、簇链、碎片文件和双流保留。

目录/媒体请求不会同时处于地址提交状态，共用一套簇内地址加法器；数据簇数量与文件相对扇区错开计算，共用右移器。`ceil(size/512)` 改成高23位加低9位是否非零，保留最大32位文件大小的进位。独立综合2313→2197 LUT。没有修改原生SD PHY、SD命令栈或仲裁器。

文件：`src/modules/bmp/bmp_read.v`。

DIB只接受40/108/124，像素偏移校验用54/122/138三个常量边界取代32位 `dib_size+14` 加法再比较。接受集合相同，仍校验54～4096。新增121/137拒绝、4096通过/4097拒绝边界用例。

## OSD、字幕与游戏

`status_osd.v`：宽高转十进制改为shift/add-3（double dabble），保留一拍寄存延迟，穷举0～4095的宽高。

`status_osd.v`、`caption_overlay.v`：编译期反转40字节字符串的连接顺序，运行时用列号直接选字符，移除 `39-col` 减法；显示内容、菜单、字体和延迟不变。反转是固定连线，不是新增运行时缓存。

`glass_osd.v`：153/103权重混合显式乘法帮助DSP映射；除9原移位表达式、六拍流水和视觉效果保留。

`picture_gamma.v`：把原10位曲线的加2、右移2位、饱和到255预先算成256个8位常量，再寄存。所有输入输出和两拍RGB/VS/DE/X延迟相同，独立实数幂参考覆盖全部256灰阶；独立综合48→24 LUT。

`snake_game.v`：LUT RAM分块从256深改为64深，规则、32×24棋盘、方向环队列、食物/碰撞/分数和一拍叠加保持。游戏仍0 BRAM/0 DSP。测试的层级内存观察同步对应12个64深bank。

## 验证与复现

```powershell
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
```

新增 `sim/tb_bram_window.v`、`tb_osd_bcd.v`、`tb_bram_waveform.v`，已登记run_tests。另扩充BMP头与FAT32重挂载边界用例。TD两份工程入口和design_files同步登记新窗口源。

附件的“BRAM≤90%（58块）”存在舍入不一致：58/64=90.625%，严格90%对应最多57块。本轮按明确块数上限58记录，不能写成占用低于90%。

所有物理结论必须对应同一源码哈希。布局预估正值不是布线STA；内部reset removal不是HDMI管脚hold；不能宣称整体+0.5ns或实体板出图/出声已经通过。物理失败或工具崩溃时保留日志，不生成可用于本版验收的bit。

## 修改位置与before→after速查

行号对应本轮最终源码；后续编辑可能变化，以符号名为准。

| 源码位置 | 等价变化 |
|---|---|
| [src/modules/video/bmp_scale_loader.v:46](../src/modules/video/bmp_scale_loader.v#L46) | 两行2048个源像素 → 两行1024个水平插值结果 |
| [src/modules/video/video_luma_window_bram.v:5](../src/modules/video/video_luma_window_bram.v#L5) | 异步LUT读行 → 下一列同步预取 |
| [src/modules/video/pixel_effects.v:10](../src/modules/video/pixel_effects.v#L10) | 77/150/29移位累加 → 同值DSP乘法 |
| [src/modules/video/audio_visualizer.v:2](../src/modules/video/audio_visualizer.v#L2) | 8位PCM异步历史 → 7位精确绘制坐标同步历史 |
| [src/modules/osd/status_osd.v:35](../src/modules/osd/status_osd.v#L35) | 重复除法取模 → shift/add-3 |
| [src/modules/osd/caption_overlay.v:9](../src/modules/osd/caption_overlay.v#L9) | 39-col后移位选字 → 固定反接后直接选字 |
| [src/modules/sd/sd_fat32.v:69](../src/modules/sd/sd_fat32.v#L69) | 保存48位检查字段 → 保存6个字节判零结果 |
| [src/modules/bmp/bmp_read.v:189](../src/modules/bmp/bmp_read.v#L189) | 可变DIB加法阈值 → 已接受DIB类型的常量边界 |
| [src/modules/video/picture_gamma.v:9](../src/modules/video/picture_gamma.v#L9) | 10位曲线后运行时量化 → 8位预量化曲线 |
| [src/modules/game/snake_game.v:205](../src/modules/game/snake_game.v#L205) | 每bank256格 → 每bank64格 |

例如，字段判零的变化是：

```verilog
// before: root_entries[15:0] 保存完整数，再判断 root_entries!=0
// after: 每个字节来时直接压缩，校验结果完全相同
17: root_entries_nonzero[0] <= |meta_data;
18: root_entries_nonzero[1] <= |meta_data;
// 最后检查 |root_entries_nonzero，坏卡仍被拒绝
```

字符选择的变化是：

```verilog
// before: 每个像素计算 (39-col)*8，再对320位字符串移位
ascii = (line_text >> ((39-col)*8));
// after: elaboration时反接字节线，像素路径不再算39-col
for(k=0;k<40;k=k+1) reversed[k*8+:8]=text[(39-k)*8+:8];
char40 = reversed[index*8+:8];
```

这些优化减少的是储存冗余和重复运算，不增加新的用户操作。KEY/SW、PS/2的用法见原操作说明，HDMI仍接HDMI_B。


## 当前资源测量

当前综合16,572 LUT（84.55%）、11,561 REG、58 BRAM（90.625%）、23 DSP；相对基线减少2,911 LUT和3 BRAM。布局布线修复后物理占用17,347 LUT（88.51%），仍超16660目标687个，不能宣称整机资源已达标。

最终91项ModelSim和77源/40 IO静态检查通过。全局SWNS −0.402ns（recovery）、普通setup −0.401ns、HWNS +0.021ns。没有本轮新bit，上板未执行。具体端点和全部证据见[验收报告](../reports/deep_opt_20261017/RESULT.md)。


## 真实布线报告驱动的控制路径拆分

新增`PIXEL_PROBE`状态：原先`oy/ox`范围比较与`pixel_valid/pixel`使能串联；现在先寄存`pixel_inside`，下一拍输出黑边或开始读行缓存。每个输出像素增加一拍加载延迟，像素值、帧尺寸和SDRAM翻转不变；显示扫描时钟和HDMI链路延迟不变。不能将这个加载延迟说成显示帧率下降或提升。新增状态保持高有效复位。

`sample_last/sample_endpoint`复用已有`SAMPLE_WAIT1`插值等待拍，提前计算`load_sample==dw-1/dw-2`；`SAMPLE_STORE`只读取布尔结果，使`dw`减法和比较不再串到高扇出`x_acc`时钟使能。缓存写入及RGB插值采样时序不变。

FAT32的`dir_has_sector/dir_hop_limit`在目录计数器稳定期间提前寄存，`DIR_CHECK`直接读取；计数器更新后经过地址生成与完整扇区接收才消费结果。保留目录循环上限、碎片根目录、MBR、superfloppy及FAT16拒绝。SD PHY、命令栈和仲裁器没有修改。

在第八轮实现中，原`oy → pixel_valid`已不再是最差路径，但其他路径成为瓶颈，整体SWNS为−1.972ns，不能只凭拆拍就宣称时序改善或收敛。后续数据以本轮验收报告为准。

TD6.2.1的`phys_opt -post_route`在high、ultra、low及独立relocation/reroute试验中均发生内部“Abnormal Timing Path check”崩溃。正式脚本保留route后数据库与STA检查点，使用独立`fix_hold`，仍运行完整最终STA、check_design/check_timing；没有新增false path、没有降100MHz、没有更改模式时钟约束。保持修复能完成不代表每轮一定修到非负。


### 宽比较与插值输入的补充拆分

FAT32 `partition_size < total_sectors`拆成高16位“小于/相等”和低16位“小于”三个预判，再合并；`total_sectors <= overhead`也在GEOM3预判、GEOM4合并，GEOM6才使用。保留完整32位无符号范围，没有截断容量或删除分区检查。

水平插值前新增`horizontal_a/b/fraction`寄存器，将11位采样位置选择与9位有符号差分输入隔开。现有插值等待拍有一拍余量，缓存仍在原`SAMPLE_STORE`写入，无须再延长等待。VGA/SVGA各9组源图逐像素参考均通过。

验证过程中发现过一次ModelSim10.1c对模块内“先使用、后声明”不兼容，已将新增FAT逻辑移到相关信号声明之后。该次编译失败之后、专项未检查编译返回码而运行的旧模型结果已作废；后续专项严格检查编译退出码，完整回归由run_tests统一拒绝编译失败。最终只以`regression_split_geometry.log`和源码哈希审计为准。
