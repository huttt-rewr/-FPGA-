# 媒体与分辨率菜单候选bit

[video_improve_menu_media_20261023.bit](video_improve_menu_media_20261023.bit)，648248字节。

SHA256：`790dd8d4035cd2262ee4dd2654058f0a9dae439f8a14b79f69ed2bf3016d322d`。

SWNS +0.160ns、HWNS +0.022ns，STNS/HTNS均0；LUT 16618/19600、BRAM 57/64、DSP 23/29。生成前后STA完全相同；116项RTL回归与源码、routed数据库哈希核对一致。四个视频/串行时钟模式均存在，原bit未覆盖。原PHY告警保留。

完整来源见manifest.json、source_build_manifest.json与前后STA报告；尚未下载硬件、未上板验收，board_signoff=false，未达整体+0.5ns，内部HWNS不能当作HDMI管脚hold签核。
