# 彩虹音频频谱替换结果（2026-10-23）

**2026-10-23 当前：彩虹频谱与稳定波形已接入，新候选 bit 已生成。** 用真实 256 点定点 FFT、32 频段柱条、缓降峰值和过零触发波形替换顶层原波形显示；原 SD/媒体读取、音频播放、HDMI、菜单、KEY/SW、游戏和官方 IP 保持原通路。98 源/40 IO 静态检查、121 项 RTL 主回归、10 项原 Python 测试、29 场景 AVF 专项通过；综合/P&R/最终 STA 通过，SWNS +0.036ns、HWNS +0.020ns，STNS/HTNS 均为 0；LUT 17965/19600、BRAM 63/64、DSP 24/29。尚未上板、board_signoff=false，未达到整体 +0.5ns；全局 HWNS 不代表 HDMI 管脚 hold。

## 实现与使用

- 顶层仅把 `audio_visualizer #(.BRAM_HISTORY(1)) waveform` 替换为 `music_spectrum_overlay waveform`，端口和两拍延迟保持一致；老模块保留历史契约兼容。
- 256 点 Q1.15 FFT、Hann 窗、32 个频段、全部覆盖频点取最大值；近似对数显示，彩虹颜色轮转，柱条每帧缓降 2 像素，峰值每 4 帧下降 1 像素。
- 左声道四点移动平均、带滞回的正向过零触发、超时捕获；双银行快照只在垂直空白期交接。音频分析旁路不驱动播放控制、不更改采样有效节拍。
- 沿原菜单选择音乐/视频并调音量/静音，无新增硬件；默认显示开启，随既有 OSD 开关。菜单、字幕和游戏继续在其后叠加。
- 参考工程的 1024 点浮点 FFT/80 柱、外部 codec、DDR/PS 和强光混合没有原样复制；当前是适配安路资源的独立定点实现，频率间隔 187.5Hz。背景为移位混合，波形为四点平滑。
- 640 模式的明文 TMDS 核仍不生成 HDMI 音频包。本任务完善可视化，不宣称补齐该已有的声音输出限制。

## 资源

| 项目 | 修改前物理用量 | 本次物理用量 | 增量 |
|---|---|---|---|
| LUT | 16673 | 17965 | +1292 |
| REG | 11163 | 11711 | +548 |
| BRAM | 57 | 63 | +6 |
| DSP | 23 | 24 | +1 |

时序：修改前 SWNS +0.126ns / HWNS +0.021ns；本次 SWNS +0.036ns / HWNS +0.020ns，STNS/HTNS 均 0。见 `final_build/` 原始报告。
没有放宽任何约束，没有增加 false path/multicycle，没有把内部 hold/removal 当作外部 HDMI 管脚签核。

## 验证与证据

- static_check：98 源、40 IO，全 PASS。
- 主回归：121 个唯一 RTL 测试 + 原有 9 个 AVF Python 测试与 1 个中文字库测试，通过；进程退出码 0，逐个新鲜日志核验，见 `main_validation.json`、`main/`。
- FFT：9 组独立双精度 DFT 参考，2304 个复数频点，最大误差 7 LSB；见 `tb_spectrum_fft.log`。
- 新增频段、波形、像素流水测试均 ALL PASS，并已登记主回归。
- AVF：读取保存的 `reports/native640_20261022/adapted_contracts/` 契约，29 场景通过。原 `scripts/run_video_tests.py` 与旧 legacy 路径已不存在；用 `run_avf.py` 编译当前源码，重建并独立校验所需 FAT32 镜像，没有改测试断言。见 `avf/validation.json`。
- 51 份现有受保护源/IP/引脚约束未改，所有旧源修改均经基线核验；顶层 70 位 status_source 完全不变。见 `scope_audit.json`、`changes.diff`。
- `rtl_preview.png` 为实际 RTL 输出 307200 像素的仿真预览，输入是合成谐波，不是实板照片。

## 构建过程中的真实失败

前 3 次整机尝试为 BRAM 66/64，均未生成位流；失败记录在 `attempt1_bram66/`、`attempt2_singleport_bram66/`、`attempt3_rom_attribute/`。
仅更改通用 RAM/ROM 属性没有解决 TD 的常量表自动 BRAM 映射；最终将 Hann 利用对称性折半，并将系数拆成 16 项逻辑查表，独立 FFT 实测 4 BRAM/1 DSP。没有删除游戏或官方 IP 来腾资源。
资源收敛后的 seed25 出现一条键盘数字解码到媒体菜单选择的 setup -0.057ns（78% 为布线延迟）；记录保存在 `attempt4_seed25_setup/`。只把 `scripts/implement.tcl` 的布局种子 25 改为 26 重新综合/P&R/STA；RTL、接口与全部时序约束未改变。
位流验收将回归日志与该次回归的准确 RTL/测试/生成器哈希绑定；布局种子重跑后不把未变化的 RTL 测试误判为过期。物理脚本和约束由新构建独立绑定。

## 候选 bit

- 文件：[video_improve_music_spectrum_20261023.bit](bitstream/video_improve_music_spectrum_20261023.bit)
- 字节：648248
- SHA256：`ae15ce151377b625344b6ef63f5ea5997f6fad5a0952aeec6adf7bc70ce6094b`
- 生成前后四项 STA 一致，源码与数据库哈希均匹配；见 `bitstream/manifest.json`。
- 尚未下载、尚未实板验证；board_signoff=false。

操作说明：[频谱手册](../../docs/MUSIC_SPECTRUM_20261023.md)。
