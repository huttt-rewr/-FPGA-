# 官方参考适配与修复（2026-10-07）

> 2026-10-09 资料核对补充：下文“未完成看门狗”等是10月7日状态；10月8日已补初始化重试、等待超时、EDID/BMP停滞与迟到确认保护，见 [合并记录](TEAM_MERGE_20261008.md)。最新STA为+0.193/+0.003ns，最差min在HDMI EDID/IIC内部removal，未达+0.5ns。64MiB镜像是SD扫描布局，与芯片8MiB SDRAM及配置Flash不同；见 [官方资料对照](VENDOR_REFERENCE_20261009.md)。

本次将官方 BMP 转换方法和 HDMI 接口手册用于当前工程，修复了两个可复现的 RTL 缺口，并提供离线图片准备工具。未把旧例程整体覆盖回来，未修改必要官方 IP、PLL、ADC/SDC，未执行写卡或生成新 bit。

## 修复与实际效果

| 问题 | 修改 | 边界 |
|---|---|---|
| BMP 字段巧合匹配就可能被扫描器接受 | 校验 DIB 为40/108/124、planes=1、像素偏移不落入头内部 | 仍只支持正高度640×480、24位BI_RGB |
| 截断头可能继承上一张图片字段 | 扫描/加载头扇区必须收到完整512字节 | 像素阶段读卡故障仍依赖已有加载超时 |
| CMD8 只看R1，未检查R7 | 收齐4字节后检查电压值1和回显AA，失败重启初始化 | 不新增SD v1/MMC支持；无限重试问题尚未解决 |
| 官方转换脚本默认路径、失败码、比例处理不可靠 | 新工具显式路径、严格校验、非零失败、等比留边/裁剪/拉伸、防覆盖 | 工具是适配实现，不声称官方原脚本已修复 |
| 普通文件复制无法保证物理连续 | 生成固定扇区布局的普通镜像文件及哈希清单 | 不直接写存储卡，不实现FAT |
| 通用ready/valid测试不等于HDMI官方协议测试 | 按手册增加连续640像素和行末背压的两帧测试 | 行为契约模型，非加密核或实板验收 |

RTL改动位于 `src/modules/bmp/bmp_read.v`、`src/modules/sd/sd_card_sec_read_write.v`。没有增加设计模块，两个TD入口仍使用相同44个源；新仿真源已加入 `scripts/run_tests.ps1`。

CMD8最后字节可与命令完成同拍到达，新增检查状态延后一拍读取R7；响应按事务清空和计数，避免残留数据被当作合法响应。检查低12位的电压/回显字段，不对保留高位附加无依据限制。

## 对照测试与回归

- 旧源码提取到独立报告目录，新负例复现错误：[BMP旧版](../reports/lab_fix/before_bmp_headers.log)、[CMD8旧版](../reports/lab_fix/before_sd_address.log)。BMP旧版接受错误头，之后在截断加载用例中停滞；这些FAILED为预期对照证据。
- 新版16项模块回归通过，含合法整帧307200像素、坏BMP头、SDHC/SDSC、错误R7、HDMI两帧连续行等。[总日志](../reports/regression.log)。
- 官方PLL模型通过，100/40/40MHz、25/125MHz以及两路锁定。[日志](../reports/pll_regression.log)。
- 主机工具8项测试通过，覆盖方向/颜色、透明合成、缩放策略、坏头、扩展头、布局和损坏检测、拒绝无效输入、防覆盖及失败退出码。[日志](../reports/lab_fix/media_tests.log)。

上述测试不等于全部故障场景已经解决。HDMI视频溢出后的截断行恢复、SDRAM刷新/延迟/竞争、SD初始化/扫描/token/换帧提交超时仍须继续处理。

## 最终综合、布局布线和时序

TD 6.2完成综合、布局布线及final STA，最终交付输入与产物哈希匹配；[核验记录](../reports/lab_fix/verification.json)确认91个构建输入、19个官方IP/约束文件保持其应有状态，后者与修改前完全一致。

| 指标 | 本次实际报告 |
|---|---|
| SWNS / STNS | +0.834ns / 0 |
| HWNS / HTNS | +0.004ns / 0 |
| 资源 | LUT 5914、REG 4148、BRAM9K 20、PLL 2、PAD 35 |
| bitstream / 上板 | 未生成 / 未执行 |

`reports/timing_summary.txt:1379` 最差min路径为：

```text
Begin: u_video_rgb_to_axis_640x480/I_rgb[21]_syn_962.clk
End:   u_video_rgb_to_axis_640x480/I_rgb[21]_syn_956.sr
Check Type: removal
Process: fast
Slack: +0.004ns
```

本次最差路径已变成视频RGB→AXIS模块内部复位网络，不能沿用旧版“最差在HDMI加密核”的定位，更不能称为HDMI管脚hold。内部指标非负只表示当前约束下没有负slack，**未达到+0.5ns**，外部IO/板级仍未签核。两条PHY-7002和一条PHY-5079仍存在，局部时钟网络仍为系统PLL C2到SDRAM_CLK。

本轮先前一次构建因主机镜像工具补充完整64MiB清零后重跑，最终以上述新manifest为准；未通过放宽约束、增加false path或更换PLL相位提升数字。

## 图片准备工具

`scripts/prepare_media.py`沿用官方RGB转换、LANCZOS缩放、BMP输出方法，重新实现显式路径、错误处理和格式校验。需要Pillow，本机已具备。默认黑色等比留边，不预先上下翻转；透明像素合成到黑色背景。

工具四个子命令：

```powershell
python E:/fpga/scripts/prepare_media.py convert E:/pictures/photo.jpg E:/fpga/media/photo.bmp
python E:/fpga/scripts/prepare_media.py check E:/fpga/media/photo.bmp
python E:/fpga/scripts/prepare_media.py pack E:/fpga/media/card.img E:/fpga/media/photo.bmp
python E:/fpga/scripts/prepare_media.py verify E:/fpga/media/card.img
```

上述输入图片是使用示例，需换成真实存在的路径。输出文件已存在时拒绝覆盖，选择新文件名即可。`convert --fit crop`等比裁剪、`--fit stretch`拉伸。`pack`支持1～4张合法BMP，顺序就是扇区顺序，默认从扇区0开始；`--start-sector`可指定起点，但整个准备区域不得超过前64MiB。

`card.img.json`记录每张图片的起始扇区、占用扇区、长度和SHA-256；`verify`重新检查镜像、头部、分配和哈希。921654字节的常规BMP占1801个512字节扇区，连续四张的起始扇区为0、1801、3602、5403。

已生成的最终示例：[demo_full.img](../reports/lab_fix/prepared/demo_full.img)、[扇区/哈希清单](../reports/lab_fix/prepared/demo_full.img.json)。同目录早期`demo.img`为开发阶段的紧凑前缀证据，不覆盖整个扫描窗口，不用于写卡；应使用`demo_full.img`或最终工具新生成的64MiB镜像。

镜像固定64MiB，覆盖完整扫描窗口，未分配区域填零，避免仅写紧凑图片前缀后扫到卡上残留旧图片。`verify`也拒绝尾部非零数据。图片不足4张时，现有RTL仍可能扫描完整窗口，生成工具没有缩短该扫描时间。

**镜像是原始扇区布局，不含FAT分区/文件系统。不能把IMG作为普通文件复制进卡根目录并期待生效。** 工具只生成普通文件，不包含写物理设备的操作。上卡时需使用能从设备LBA0原样写入镜像的流程，事先备份并核对目标卡；本次未执行该操作。

## 仍不能靠官方旧文件解决的事项

1. 内部复位removal余量：本次最差在视频RGB→AXIS模块，旧版最差在HDMI核；需按当前路径逐项处理，不能搬旧exclusive约束屏蔽。
2. SDRAM控制器契约及PHY-7002/PHY-5079：例程同样使用固定读排空时间，没有找到可直接替换的修复实现。
3. 初始化/扫描/token永久无响应：本次校验R7防止误接受，但没有完成分阶段看门狗与错误上报。
4. 换帧提交超时：需要可确认的取消/重新同步协议，不能随意翻转toggle释放忙状态。
5. 实板兼容性：板级IO参数、速度等级和电气仍需真实资料/测量。

## 备份

10月7日适配前的历史归档已缺失，不能声称仍可从当时路径恢复。此情况不代表当前整个`backups/`目录不存在：10月8日合并备份及10月9日文档备份已另行建立；恢复时按各自manifest确认对应日期与内容。
