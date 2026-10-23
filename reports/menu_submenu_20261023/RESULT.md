# 纯色单列窄菜单与两秒浮窗（2026-10-23）

按最新要求取消渐变，主菜单从288缩为128个逻辑像素，贴屏幕左边，只显示功能名称一列。800×600沿原坐标适配为160像素宽。选中项仍是两倍黄字。进入子菜单后，名称与当前值纵向排列。

长按KEY3约一秒打开/关闭；主菜单KEY1/KEY2上移/下移，KEY3短按进入；子菜单KEY1/KEY2减/增或切换，KEY3短按返回。进入子菜单本身不修改参数；“退出”直接关闭。

菜单外亮度或对比度实际变化后，左上角显示两者最新值，最后一次变化起两秒后消失。期间再次变化立即重新计时，显示在下一帧更新。菜单内调节、关闭边界不触发提示；到达上下限但值不变时不重计时。为避免同帧撕裂，出现、更新、隐藏都在帧边界提交，到期后最多延后一帧隐藏。

## 验证

- `python scripts/static_check.py`：ALL PASS，94 sources、40 IO bits。
- `scripts/run_tests.ps1`：退出码0，ALL TESTS PASSED；114项独立RTL测试、9项AVF工具Python测试、1项字库Python测试通过。114项日志及哈希保存在`main/`和`regression.json`。
- `tb_chinese_menu`：ALL PASS；八项导航、七项子菜单、进入不动作、调值/切换、限幅、长短按与共享寄存器。
- `tb_menu_popup`：ALL PASS；VGA/SVGA计时比例、重触发与最新数值、同时变化、菜单抑制、到期、零不回绕、复位。专项缩短时钟参数逐拍验证，正式顶层使用25/40MHz及两秒，即50000000/80000000周期。
- `tb_menu_overlay`：ALL PASS，18完整VGA帧、5529600像素。
- `tb_menu_overlay_svga`：ALL PASS，接入实际viewport_coordinates，18完整SVGA帧、8640000像素。两者共14169600像素，覆盖LIST/SUBMENU/浮窗、两倍字形、RGB/VS/DE两拍对齐与关闭透传。
- `python scripts/run_build.py`：退出码0，综合、布局布线与最终STA通过；SWNS **+0.110ns**、HWNS **+0.021ns**，STNS/HTNS均0，LUT **16480/19600**、BRAM **57/64**、DSP **23/29**。原始seed25即通过，没有修改RTL之外的时序约束或追加物理seed试验。
- `scope_audit.json`：ALL PASS，原70位status_source字序不变；除6项计划内修改与1份新增测试外，250份构建输入保持哈希一致。顶层唯一变化为菜单接入已有`mode_video`，SD/FAT32/BMP/WAV/SDRAM、官方IP、引脚及约束保持原样。

## 新候选bit

[video_improve_menu_submenu_20261023.bit](bitstream/video_improve_menu_submenu_20261023.bit)，648248字节。

SHA256：`264aafdfaa9078b686cdd5cbe5d03044585ab3264a39089ba51d1731d15a508b`。

生成前后STA完全一致，并核验当前源码、布线数据库和构建清单。详见[bit生成记录](bitstream/RESULT.md)、`bitstream/manifest.json`、`final_build/`。此前bit保留。

`board_signoff=false`，未下载到板卡、未上板验收，未达到整体+0.5ns；全局HWNS不能当作HDMI管脚hold签核。现存PHY-7002位置和PHY-5079局部时钟布线警告仍保留。

完整操作与仿真截图见[新版菜单手册](../../docs/MENU_SUBMENU_20261023.md)。原始文件和此前报告备份在`baseline/`。
