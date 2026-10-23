# 纯色窄菜单、子菜单、两秒提示候选bit

文件：[video_improve_menu_submenu_20261023.bit](video_improve_menu_submenu_20261023.bit)

- 大小：648248字节。
- SHA256：`264aafdfaa9078b686cdd5cbe5d03044585ab3264a39089ba51d1731d15a508b`。
- 生成前后最终STA一致：SWNS **+0.110ns**、HWNS **+0.021ns**，STNS/HTNS均0。
- 资源：LUT **16480/19600**、BRAM **57/64**、DSP **23/29**。
- 114项独立RTL回归通过，当前源码与综合快照、routed数据库哈希匹配。
- 四个视频/串行模式时钟均存在，旧bit未覆盖；未下载到板卡。

详细来源与哈希见`manifest.json`、`source_build_manifest.json`、`before_bit_timing_status.txt`及`after_bit_timing_status.txt`。board_signoff=false，未达到整体+0.5ns；内部HWNS不等于HDMI管脚hold签核，现存PHY警告保留。
