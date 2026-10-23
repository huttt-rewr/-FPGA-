# 板载操作、上板验证与演示步骤

> 此页记录早先57源板载优化版本。当前WAV增量新增三项音频菜单，制卡与操作见[音频手册](WAV_AUDIO_20261014.md)，最新候选与STA见[构建状态](BUILD_STATUS.md)。

本轮只升级现有工程，不新增外设。用户控制仅KEY/SW，UART/红外禁用，音频默认静音。无需PCM5102、I²S、喇叭或新接口；不按任务书中的外接音频方案接线。本轮验证状态与候选见[构建状态](BUILD_STATUS.md)，基本连接见[接线教程](CONNECTION_AND_USAGE.md)。

## 下载之前

1. 保留10月13日候选bit和现有SD镜像，准备记录板卡版本、显示器型号、供电和文件SHA-256。
2. 用现有`scripts/prepare_media.py`准备正高度24位BMP和原始连续扇区镜像，按既有教程写测试卡；本轮没有自动写入任何物理磁盘。不能只将BMP复制到FAT目录。
3. 显示器接HDMI_B并选正确输入；插入已准备卡，连接原下载器和板卡规定电源。使用独立的10月14日候选，不用旧bit验证新菜单。
4. 优先临时配置FPGA；本轮不写配置Flash，不更改启动拨码。下载完成后整机复位，等待EDID选择模式及读图完成。

## 按顺序验收

| 实验 | 操作 | 观察与记录 |
|---|---|---|
| 冷启动 | 先接显示器/卡，再配置、复位 | 640×480或800×600，首图前安全底色/状态OSD，首图完成后出图；没有新增LOGO或音频 |
| 无卡启动 | 关电后取卡，重新启动 | 状态/错误提示与自动重试，不应反复被视频看门狗复位；帧时序存在即可喂狗 |
| 单图稳定 | PLAY下KEY2设OFF，SW3/4关转场 | 静止至少30min；记录白条/撕裂、LOAD:E及诊断页 |
| 普通KEY | KEY3短按松开循环PLAY/BRIG/CONT，KEY1/2调节 | 老功能与边界一致，KEY3短按现在释放后生效 |
| 板载菜单 | KEY3长按约1.1秒并松开 | 第三行MENU，第4行K1/K2/K3提示，MODE不被顺带改变 |
| 伽马对照 | 菜单选GAMMA，KEY3短按确认 | ON暗部更亮，OFF回原数值；OSD/字幕不随之提亮；没有把它当显示器校准 |
| 诊断 | DIAG确认ON，DIAG PAGE逐页确认 | 数码管页号及快照更新，OFF恢复旧状态码；编码见观测清单 |
| SW | 字幕、滚动、淡入淡出/滑动/交替 | 四路映射不变，菜单打开也生效，转场不在半程改类型 |
| 轮播 | 菜单PLAY/PAUSE或普通PLAY下KEY2 | 每次仅切换一次，不因长按重复换图；新帧完整写入后才提交 |
| 复位默认 | 整机复位 | 伽马OFF、诊断OFF、菜单关闭、亮度0/对比度1.00，SW按物理位置恢复 |

本工程启动检测EDID一次，不支持热插拔自动协商。无卡测试后关电插卡再启动，或按已有恢复教程整机复位；本文不承诺带电插卡一定支持。用户原反馈静止图有白条，因此单图稳定必须先于特效演示。仿真通过不能跳过这项实测。

## 模块验证复现

在E:/fpga，ModelSim默认J:/win64，TD默认J:/Anlogic/td.6.2.1。按顺序运行，避免多个ModelSim进程同时写同一个库：

```powershell
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_refresh_test.ps1
& 'J:/win64/vlog.exe' -work sim/msim_work reports/display_fix_20261013/tb_underflow_recovery.v
& 'J:/win64/vsim.exe' -c -lib sim/msim_work tb_underflow_recovery -do 'run -all; quit -f' -l reports/board_opt_20261014/underflow_recovery.log
python reports/board_opt_20261014/record_regression.py
python scripts/run_build.py
```

检查每项日志有ALL PASS、没有FAILED/Error/Fatal，完整47项进程返回0且输出ALL TESTS PASSED；再用本轮交付脚本。刷新专项默认把日志写到10月13日目录，需将本次完成后的`refresh_after.log`复制到本轮报告目录归档。专项不是完整SDRAM受保护PHY仿真。

当前候选生成后使用`python reports/board_opt_20261014/verify_delivery.py`只读核对；首次生成需要`--generate`，它核对源码、报告、回归、官方IP和约束哈希，再输出独立bit，拒绝覆盖。源码/脚本/激励变化后旧候选不能代表当前工程，必须重新完整验证并使用新的归档输出目录。

## 常见故障

| 现象 | 排查 |
|---|---|
| KEY3按下时没有立即切MODE | 短按需松开并完成释放消抖；长按属于菜单操作 |
| KEY1/2不再换图/调参 | 是否在MENU，先长按KEY3退出；再检查MODE |
| 开伽马后照片发灰 | 这是可选暗部提亮，sRGB照片不一定适合，关闭对照 |
| 数码管一直只显示一个状态 | DIAG是否ON、bit是否新版本、DEBUG_ENABLED是否裁剪为0 |
| 诊断页快速变化难读 | 本页10Hz快照不是高速轨迹，先记录粘性错误；需要抓波形时参照观测清单 |
| 周期重新启动 | 页3看门狗计数是否增加；记录失锁、视频VS与供电，不能假定都由卡错误引起 |
| 静止仍白条/LOAD:E | 记录页1/2、出现时刻、是否更换线材/模式；需要验证SDRAM硬核契约和TMDS电气 |
| HDMI没有声音 | 本轮按用户范围保持静音，这是预期；菜单没有音量或音频条目 |

PHY-7002×2、PHY-5079×1、Speed=NA及外部IO仍需厂商/原理图/实测。任何内部时序正值都不证明HDMI管脚hold已签核。
