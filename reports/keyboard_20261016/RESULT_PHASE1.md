# PS/2阶段一冻结交付

新增PS/2接收与事件层，键盘切图、自动播放、音量、静音、整帧OSD开关接入正式顶层。KEY/SW功能保留；默认静音改为OFF、音量8。数字、R/F只存请求，尚无文件/模式/频率消费者。官方CLK=M16、DATA=K16。操作见[使用文档](../../docs/KEYBOARD_USAGE_20261016.md)。

67项ModelSim完整回归、专项真实10kHz PS/2协议及键位测试通过。静态检查65源、38 IO、两个TD入口一致。冻结[验证清单](validation_phase1.json)审计70bit布局与下标不变、原SD栈、FAT32/BMP播放器/缩放器未改。

最终STA：SWNS **+0.001ns**、STNS 0、HWNS **+0.021ns**、HTNS 0。资源LUT15223、REG10132、BRAM9K59/64、DSP17、PLL2。[最终报告](phase1_onehot/timing_summary.txt)、[构建输入哈希](phase1_onehot/build_manifest.json)、[回归](phase1_onehot_regression.log)。余量很小，**不代表达到+0.5ns或板级签核**。Speed=NA，已有物理/IP警告与外部IO预算仍需实板核对。

真实失败记录：初轮setup−0.516ns、min−0.319ns，后者是看门狗到模式同步器复位脚的内部removal；第二轮为setup−1.200ns、min+0.021ns。分别保存在 `phase1_initial/`、`phase1_fixed/`，没有将内部removal说成HDMI管脚hold。最终将模式复位释放按域同步、重试计数移出解析器状态case、WAV独热状态直接按位译码，保持解析、重试间隔与错误码语义。旧正时序基线未用于认证新源码。

未生成新bit、未下载、未写实体卡、未验证键盘电气或显示器出声。SD正式仍SPI25MHz，四位候选及50MHz不包含在阶段一交付内。

备份：`backups/keyboard_20261016/before.zip`。独立 `stage2/` 中的多文件候选是后续实验，非本阶段正式源。范围内diff检查通过；工具原生报告的尾随空白保留原样，未为消除Git格式提示篡改证据。
