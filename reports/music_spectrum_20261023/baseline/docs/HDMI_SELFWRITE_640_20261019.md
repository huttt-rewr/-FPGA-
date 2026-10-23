# 640 明文 TMDS 与独立 EDID 读取

本轮用明文 RTL 替换了 **640×480 加密 HDMI 实例**。800×600 继续使用原官方加密核，负责图像与 HDMI 内嵌音频。官方加密源文件仍是 800 核的必要依赖，不能删除。

当前验证与资源、时序数值见 [本轮结果](../reports/hdmi_selfwrite_20261019/RESULT.md)。源码修改后的本轮结果必须单独验收，不能沿用上一轮 SWNS +0.131ns / HWNS +0.022ns。未进行实板图像、声音和电气验收。

## 使用方式

显示器仍接 **HDMI_B**，TF 卡、KEY、SW、键盘和文件格式保持原用法。

| 实际输出 | 图像 | 声音 |
|---|---|---|
| 640×480，25MHz 像素、125MHz 串行 | 明文 TMDS；图片及所有现有叠加层 | **不发送 HDMI 音频**，这是本轮明确选择的 video-only 模式 |
| 800×600，40MHz 像素、200MHz 串行 | 原官方 HDMI 核 | 保留 48kHz / 16bit / 单声道 PCM WAV 的 HDMI 左右同声输出 |

上电默认仍是 640。需要听声音时，在已有 PS/2 键盘上按一次 **R** 请求 800，必须看 OSD 箭头后的**实际输出是 800×600**。只有 `R:2` 不够：EDID 不支持或检测失败会回退到 640，此时仍无声。已有 KEY/SW 没有新增分辨率切换功能；不能把音量或静音操作当成切换分辨率。

到 800 后，用 A 松开后两秒内按 0 选择第一份 WAV，或沿用默认音频；检查音量非零、M/KEY 菜单未静音、显示器有扬声器且支持 HDMI 音频。切模式会重挂载、重载和预填音频，短暂黑屏/静音正常。KEY/SW 的亮度、对比度、字幕、特效、转场、菜单和音量操作均保留。

640 的 OSD `A:R` 表示 WAV 解析/PCM 链状态，**不表示本模式正在向 HDMI 发送音频包**。波形仍可观察内部 PCM。640 侧未增加 ACR、音频采样包或数据岛，不能靠修改音量恢复 HDMI 声音。

## 信号链与文件职责

```text
SD / FAT32 / BMP / 缩放 / SDRAM 双缓冲
  → 亮度/对比度/伽马/转场/字幕/像素特效/玻璃OSD/波形/游戏
  → game_vs / game_de / game_rgb
      ├─ 640：hdmi_tmds_vga → 三个 tmds_encoder
      └─ 800：原 RGB→AXIS 队列 → 官方 HDMI 核（含原音频输入）
  → 原有模式选择 mux → hdmi_phy_wrapper → lane_lvds_10_1 → HDMI_B

boot_clk → edid_i2c → 原 edid_valid_boot/data_boot
  → edid_display_mode → 原模式切换控制器与时钟链
```

- `src/modules/hdmi/tmds_encoder.v`：按公开 DVI 1.0 §3.2 的 TMDS 算法，先 XOR/XNOR 减少位翻转，再用有符号运行差分平衡直流分量。每控制期差分归零；一个像素时钟输出一个 10bit 符号。TMDS 不等同于 IBM 的通用 8b/10b 查表编码。
- `src/modules/hdmi/hdmi_tmds_vga.v`：每个输入 VS 下降沿恢复 800×525 计数相位，产生低有效 HS；RGB 与输入 DE 一起进入编码器，防止丢掉叠加链的延迟。锁定前只发控制码。场同步边沿这拍消费的是 (0,0)，计数器加载的是下一拍的 (1,0)，避免水平同步晚一拍。
- `src/modules/hdmi/edid_i2c.v`：永久 25MHz 启动域下约 99.206kHz DDC；发送 A0、偏移 00、重复 START、A1，读连续 128 字节，前 127 字节 ACK、末字节 NACK、STOP。每字节提供一拍 valid，无 BRAM。
- `src/top.v`：640 接最终像素流，640 模式 AXIS ready 恒为 1；800 的 AXIS/音频连接与原实例逐字保留。EDID 接到原来的采样寄存器与解析器。

本轮不改 SD、FAT32、BMP、WAV、缩放器、原 OSD/特效/游戏模块，不改 PHY、PLL、SDRAM、引脚约束、复位连接和 70 位状态总线布局。两个 TD 工程入口与正式源清单均登记新模块。

## 两处规格纠正

1. 时钟通道 `10'b0000011111` 是 **0x01F**，不是 0x03F。0x03F 有六个 1，不能代表五个 1 / 五个 0 的时钟图案。
2. 标准 TMDS 差分累计在控制期清零，不初始化为 -1。差分更新按实际输出的十位码计算，仿真独立统计输出中 1/0 数量检查这一点。

VS/HS 采用原 VGA 的低有效电平。位序保持标准 10bit 符号，原 PHY 负责 LSB-first；没有增加第二次反排。640 输出是 DVI 兼容 TMDS 纯视频，不发送 HDMI 音视频数据岛。

## EDID 行为与边界

EDID 保留原 128 字节头、校验和、数字显示器和 800×600@60 白名单判断。损坏或不支持的 EDID 不会强行选择 800。DDC 地址/偏移/读地址任一 NACK 会 STOP 并释放总线；原解析器超时后安全回退 VGA。复位释放两根线，模块允许后续 start 再读；现有顶层仍按原设计只在启动时触发一次。

SDA、SCL 都只拉低或释放，继续使用原引脚上拉约束。为遵守本轮顶层端口不变约束，**SCL 仍为 output**，读取器无法检测从机时钟拉伸，也未增加 HPD、热插拔或自动总线恢复功能。物理 DDC 电平、上拉与外部 IO 时序需要实板核对；逻辑级从机仿真不替代这些检查。

## 仿真与验收

```powershell
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
python reports/hdmi_selfwrite_20261019/audit.py
```

新增测试均登记在全量 ModelSim 入口：

| 激励文件 | 验证内容 |
|---|---|
| `sim/tb_tmds_encoder.v` | 全部 65,536 相邻字节组合、256 种恒值连续流、四个控制码、独立差分统计与复位 |
| `sim/tb_hdmi_tmds_vga.v` | 原 adaptive_raster 延迟 23 拍模拟叠加链，多个完整帧、三个颜色通道、HS/VS/DE 相位、帧中复位后重新锁定、时钟图案 0x01F |
| `sim/tb_edid_i2c.v` | 真正按总线边沿应答的 EDID 从机，检查 A0/00/重复START/A1、128 字节、主机 ACK/NACK、校验与头损坏、不支持800、三处NACK、无显示器、复位后再读 |

上板需分别确认 640 静态图与红绿蓝、OSD/字幕/游戏不偏移且无噪点；再切 800 检查图像和声音；再用不支持 800 或缺失的 EDID 检查回退。只有实板测试能确认显示器锁定、PHY 电气、图像质量与扬声器出声。内部 reset removal 仍不能解释成 HDMI 管脚 hold，也没有整体 +0.5ns 声明。

修改前备份位于 `reports/hdmi_selfwrite_20261019/before/`，原始哈希见同目录上级的 `baseline.json`。README 在开始时已有的用户修改另行保留在备份中。
