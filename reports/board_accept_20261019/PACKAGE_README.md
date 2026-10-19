# 640明文核 / 800图声 · 实板待验包

候选bit：candidate/hdmi_640_plain_800_audio.bit
635444字节，SHA-256：c4981724248155ccba2226994ec3d1a9d7a6a118175ec2f7c48d6bf89c22646d
源码提交f32e7c9，EG4S20BG256；内部SWNS +0.044ns / HWNS +0.024ns / STNS0 / HTNS0。

## 怎么用

1. 解压到普通电脑目录；用TD配套下载工具识别已有EG4S20BG256下载链，选择candidate里的bit做JTAG临时配置。本包没有执行下载或写Flash。
2. 只将sd_files内7份BMP和1份WAV复制到FAT32卡根目录，安全弹出后插回板卡。不是烧写裸镜像；文件序号按FAT目录项顺序，不按文件名。
3. 显示器接HDMI_B，默认640。用KEY1（MODE:PLAY）或键盘左右选图。RGB纯色检查颜色，GRID640检查边框，SMALL/PORTRAIT检查缩放；开启OSD/字幕/特效/游戏检查原功能。
4. 用已有PS/2键盘R请求800，看实际尺寸是800x600后检查GRID800和TONE.wav。A松开后两秒内按0选第一份音频，音量非零、解除静音。640无HDMI音频；A:R不表示640发声。
5. TONE是440Hz两秒、静音一秒、880Hz两秒、静音一秒；先调低显示器音量。
6. 换显示器后全局复位再测EDID：支持800的设备R后实际800，仅640设备R后回退640。没有第二类设备就记未测，不能用仿真替代。
7. 支持800的设备上R循环640→800→640→640，记录10轮及全局复位结果。每次等屏幕重新锁定，切模式暂停轮播需再开。
8. 填BOARD_RESULTS.md。所有四项真实通过后才继续新转场/变焦、FFT、raw视频；当前都未开始。

## 当前边界

尚未实板出图出声；低有效{vs,hs}、frame_start之后h=1是代码基线，待实物确认。不要同时改极性、位序、相位。既有SDRAM物理警告、Speed=NA与外部IO仍未签核，未达到整体+0.5ns。

详细步骤在工程E:/fpga/docs/BOARD_ACCEPTANCE_640_20261019.md。manifest.json记录bit/数据库/源构建关联；media_manifest.json记录素材哈希。STATUS.json各项pending，不能视为通过。
