# WAV 读取自动恢复与错误诊断

本次只修复已有 HDMI 内嵌音频链路，不放宽 WAV 格式，也不新增外设或控制方式。仍要求小端 RIFF/WAVE、PCM format=1、48000Hz、16bit、单声道，byte_rate=96000、block_align=2。图片区、官方 IP、引脚和时钟约束不变。

## 为什么此前会一直静音

`audio_wav` 遇到格式错误、SD 错误或不完整扇区后进入 FAILED，但没有正常出口。上层 `audio_error` 只清空 FIFO，不复位解析器；因此换成正确数据后仍不能继续。旧错误位也无法说明失败原因。

现在 FAILED 等待 `RETRY_CYCLES` 个时钟，默认 100000000，在 100MHz 下是一秒；期间 ready=0、sample_valid=0、不申请 SD。到期清除当前错误并回到 IDLE。只有音频启用且 SD 初始化完成后才从 WAV 首字节重新读取，重新建立缓存、fmt 状态和样本低字节状态。SD 超时触发底层重新初始化也不会提前清掉 FAILED 的等待。永久坏文件会按“失败后等待一秒，再读头”的节奏重试，不是准确每秒一次请求；读头和解析本身也耗时。

静音时到期停在 IDLE，不读 WAV；解除静音后再尝试。SD 未就绪时同样等待。仍需完整 512 字节及成功结束才释放扇区内容，坏扇区不会输出新 PCM。

## 屏幕怎么读、怎么处理

退出 KEY3 菜单后，左上面板最后一行右侧显示例如 `A:E2 V:08 U0`。菜单打开时这一区域暂时显示菜单提示。

| 显示 | 含义 | 处理 |
|---|---|---|
| A:E1 | RIFF/WAVE 标识、文件头长度或 PCM 格式不合要求 | 用 `prepare_audio.py check` 检查，转换成严格的 48kHz/16bit/mono，再重建镜像 |
| A:E2 | SD 读错、CRC/传输失败或仲裁超时 | 检查卡及连接；瞬时故障恢复后会自动重新读头；超时可能还需等待 SD 初始化 |
| A:E3 | 实际返回扇区长度不是 512 字节 | 检查完整镜像、卡读写质量及 SD 传输；不要把不完整扇区当成功 |
| A:E4 | chunk 越界、fmt 重复/过短、data 缺 fmt、奇数 PCM 长度或块结构错误 | 检查 WAV 结构、镜像完整性与固定地址，重新生成合法数据 |
| A:R- | WAV 头已接受、无保留的失败记录 | 仍不证明显示器出声或没有欠载 |
| A:M- | 静音、无失败记录 | KEY3 长按进菜单，选择 AUDIO MUTE，KEY3 短按释放切 OFF |
| A:-- | 尚未准备、无失败记录 | 等初始化/读头；持续时检查卡和 WAV 起始 LBA131072 |
| V:00..31 | 当前逻辑音量 | 菜单 VOLUME DOWN/UP，KEY3 每确认一次减/加一级；00 输出静音 |
| U0 / U1 | 本次复位以来是否发生过音频 FIFO 读空 | U1 表示曾经欠载，播放器会送零并重新预填；恢复播放也保留 U1，整机复位才清除 |

错误历史与驱动 FIFO 清空的当前错误分开：当前 `audio_error_code` 到重试时清零，OSD 仍保持上次 E1～E4。只有真实 PCM 样本经预填、音量流水到达 HDMI 输入时才清除历史。静音、音量零、头解析成功、合成的零输出都不能提前清除；合法 PCM 文件中的零值样本可以清除。这个检测证明数字链路送出了样本，不检测显示器扬声器。

KEY/SW 操作没有新增步骤：复位默认静音、音量08；KEY3 长按约1.1秒进菜单，KEY1向上、KEY2向下，KEY3短按释放确认；再长按退出。SW0字幕、SW1滚动、SW2/3转场保持原功能。无需串口。永久格式错误不会被重试“修好”，必须修正源数据；制卡/换卡按原流程，内容不同的卡仍应整机复位重建图片索引。

## 文件与技术

| 文件 | 本次修改 |
|---|---|
| `src/modules/audio/audio_wav.v` | 可配置重试计数；提前寄存到期译码；四类错误；SD初始化不绕过等待；空间许可寄存、样本保持、块分类/终值判断流水和显式独热状态缩短100MHz路径 |
| `src/modules/bmp/sd_card_bmp.v` | 仅音频端口及可选音频分支透传4位错误码，`audio_error=\|audio_error_code`；图片逻辑逐字保留 |
| `src/modules/audio/audio_playback.v` | 新增与输出样本对齐的 pcm_valid；音频错误历史模块；原采样节奏/增益/欠载恢复不变 |
| `src/top.v` | 独立4位 cdc_snapshot 传错误码；视频域保留失败历史、逐帧锁存 OSD；原70位 status_source及全部取位不变 |
| `src/modules/osd/status_osd.v` | 可选音频诊断字符显示；其他 OSD 和菜单保持原有行为 |
| `scripts/run_tests.ps1` | 新增三个测试，完整回归从54项增至57项 |

跨域用握手快照传整个错误码，避免直接把多位异步总线送到视频域。欠载本来就在视频域，只需帧边界锁存；不需要再次跨域。失败历史也在视频域，避免添加 PCM 成功反馈到 SD 域的跨域线路。

音频 FIFO 的复位继续来自含 rst_sd 的 audio_queue_reset，加上模式未就绪条件；移除了重复的 rst_all 分支。rst_sd 仍由同一个整机复位异步断言并同步释放，FIFO 内部仍分别同步释放写/读域。这只改变音频 FIFO 的冗余复位释放路径，原视频和 SD 复位实例不变。

空间许可延迟一拍：顶层原本保留至少260个空位，一个扇区最多256个样本，且输出相邻样本需要多拍；延迟许可不超过这段保护空间。新增 WAIT_SAMPLE 状态保存已组装的 PCM，直到 enable 和 sample_ready 同时有效才输出，期间不解析下一个字节；即时检查继续保留，未放宽 FIFO 满保护。

## 验证与限制

新增 `sim/tb_audio_retry.v` 注入格式、SD读错、短/长扇区、chunk越界和真实仲裁超时，验证恢复正常数据无需复位、错误原因、静音/未初始化不申请SD、永久坏文件延时重试及等待期间图片请求推进。`sim/tb_audio_retry_edges.v` 覆盖1、2、13拍边界；主测试用37拍加速等待，默认硬件参数保持一秒。`sim/tb_audio_diagnostics.v` 使用独立时钟、真实 cdc_snapshot 和播放器验证粘滞历史、有效PCM对齐、静音/预填及欠载。原 OSD 测试新增两种视口的四个错误码与 U 标志；原 WAV 测试只更新“重新初始化不能立即清错”的旧预期。

在 E:\fpga 执行：

```powershell
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
python reports/audio_retry_20261014/audit.py
```

最终测试、候选及实际 STA 见 [构建状态](BUILD_STATUS.md)。首轮负时序与旧断言失败日志单独保存在 `reports/audio_retry_20261014/initial_failed`，不能作为通过证据。未使用新 false path 或修改官方 IP。

未写物理卡、未下载 FPGA、未完成实板出声验证。自动恢复不代表任意热插拔可用；原底层 SD 超时复位可能影响并发图片传输。Speed=NA、已有 PHY 警告和外部 SD/DDC/TMDS 签核问题仍需处理。内部复位 removal 不能当 HDMI 管脚 hold，也不能宣称整体达到 +0.5ns。
