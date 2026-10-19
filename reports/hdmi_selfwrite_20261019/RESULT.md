# 640 明文 TMDS / 独立 EDID 交付结果（2026-10-19）

本轮软件验证通过：80源/40逻辑IO静态检查、101项ModelSim、完整综合/布局布线/独立hold修复与内部STA。640 video-only、800保留原HDMI图声，EDID协商与全部原图像叠加层保留。**没有本轮新bit，没有实板出图/出声完成声明。**

## 实际资源与时序

| 指标 | 修改前（5eb97fa） | 本轮 |
|---|---:|---:|
| 物理 LUT | 17340 | 15785（80.54%，减少 1555） |
| 物理 REG | 11695 | 10158 |
| BRAM9K | 58 | 41（64.06%，减少 17） |
| DSP | 23 | 23 |
| SWNS | +0.131ns | +0.044ns |
| STNS | 0 | 0 |
| HWNS | +0.022ns | +0.024ns |
| HTNS | 0 | 0 |

LUT减少约8.97%，BRAM减少约29.31%。**资源明显下降；setup裕量比原版减少0.087ns，不能声称时序全面改善。** 两档像素/串行时钟25/125、40/200MHz均仍受约束；100MHz主控不变。没有新增false-path或放宽约束，没有达到整体+0.5ns。

新核综合层次占用：VGA 247 LUT、54 REG、0 BRAM；EDID 123 LUT、67 REG、0 BRAM。物理层次的`lut`列分别为218、91，与另列ripple统计口径不同，不直接与整机合计相加。资源净节省以整机表为准。

## 最差路径（本轮实际报告）

- **setup +0.044ns**：`sd_card_bmp_m0/wav_enabled$wav/state_reg[14]_syn_4.clk` → `sd_card_bmp_m0/wav_enabled$wav/state_reg[1]_syn_7.ce`。
- **hold +0.024ns**：`frame_read_write_m0/read_buf/wr_to_rd_cross_inst/primary_addr_gray_reg_reg[2]_syn_4.clk` → `pixel_filter/add1_syn_123.mi[1]`。
- **removal +0.035ns**：`frame_read_write_m0/write_buf/asy_w_rst1_reg_syn_5.clk` → `frame_read_write_m0/write_buf/rd_to_wr_cross_inst/primary_addr_gray_sync_reg[8]_syn_4.sr`。
- **recovery +0.722ns**：`mode_control/state_reg[4]_syn_4.clk` → `osd/board_ascii[0]_syn_237.sr`。

全局HWNS是工具对保持类检查的汇总，不是HDMI管脚hold。上面单独列出普通hold与内部复位removal；外部SD/DDC/TMDS IO时序仍未签核。Speed仍为NA，STA覆盖99.90%，不能用内部正裕量替代板级电气验收。

## 验证与范围

- 原98项测试与新增3项全部通过，101份逐项日志见 [test_logs](build1/test_logs/)，完整执行记录见 [regression.log](build1/regression.log)。
- 新测试：编码全字节组合/差分界限；延迟23拍的原raster整帧HS/VS/DE、RGB与帧中复位重新锁定；线级EDID从机、ACK/NACK、坏校验/头、不支持800、缺失设备与复位再读。
- `audit.py`验证所有原RTL（除计划内top局部接线）、800参数/实例、PHY、PLL、SDRAM、约束、原98项激励均未改；70位status_source位宽与顺序一致。
- TD两个工程入口、design_files与ModelSim入口已同步登记新增模块，static_check ALL PASS。
- 沿用原构建脚本的独立TD会话reload→incremental route→fix_hold，未修改时钟、引脚或物理策略。
- 没有新增CRITICAL种类、没有coredump。既有PHY-7002 SDRAM宏位置两条、PHY-5079一条local-routed clock仍存在；没有将其归为已解决。

## 用户应注意

640模式不发送HDMI音频；默认上电640无声属于本轮选择。听WAV请用已有键盘R切到**实际800×600**，音量非零并解除静音。EDID回退640时也无声。KEY/SW未新增分辨率功能；OSD的A:R仅表示WAV/PCM状态，不表示640正在发送音频包。详细使用、文件原理与上板验收见 [说明书](../../docs/HDMI_SELFWRITE_640_20261019.md)。

更正附件：`0000011111`=0x01F，非0x03F；TMDS控制期差分清零。保留低有效VGA同步、原PHY位序与最终RGB/DE流；不能凭仿真断言实体显示器已锁定。

DDC继续只在上电触发一次、读取base block。SCL保持原output端口，低/高阻开漏输出，不能采样显示器clock stretching；不新增HPD/热插拔。缺失/NACK后释放总线，由原解析器超时回退。该边界已写入说明书。

## 证据与备份

- [冻结build_manifest](build1/build_manifest.json)：完整输入SHA256、工具警告与四项时序。
- [timing_status](build1/timing_status.txt)、[详细路径](build1/routed_timing_paths20.txt)、[物理资源](build1/physical_area.txt)。
- [summary.json](build1/summary.json)、[sha256.json](build1/sha256.json)：路径、101测试清单及全部冻结文件哈希。
- [baseline.json](baseline.json)与`before/`：包含开始时README用户改动的完整备份；未删除必要官方IP。

不自动下载板卡、不写实体SD卡、不生成新bit。实板仍需验证640图像/颜色/位置、全部叠加层与800图声、异常EDID回退。
