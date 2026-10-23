# 中文菜单版候选bit生成记录（2026-10-23）

已使用当前综合、布局布线、STA通过的路由数据库生成候选bit；包含中文分级菜单及此前已接入的AVF三档功能。没有重新综合或修改源码、引脚、时钟及约束，未下载到板卡。

- 文件：[video_improve_chinese_menu_20261023.bit](video_improve_chinese_menu_20261023.bit)
- 大小：648248字节。
- SHA-256：`8adca4fa174de0a120c3eb22d8d5537edf300a31453e267250accdd71f4abcad`。
- 路由数据库SHA-256：`a4d2b665e7b996b9c50ba673a8b84a46f8a4c865defdf572f1f59b138537e175`。
- 生成前后源码快照、路由数据库及原构建manifest哈希一致；113项主回归对应当前源码。
- 生成前后STA均为SWNS +0.156ns、HWNS +0.024ns、STNS/HTNS均0，四个VGA/SVGA像素及串行模式时钟均存在。
- TD返回码0，日志含BITGEN_COMPLETED；证据为本目录manifest.json、bitgen.log、生成前后时序报告和冻结的source_build_manifest.json。

旧候选bit保留不覆盖。board_signoff=false，尚未上板；现有PHY警告与外部IO验收仍待处理，内部HWNS不代表HDMI管脚hold签核，未达到整体+0.5ns。
