# F 盘工程合并结果（2026-10-21）

基线为 `581f55bb6ea54e6eb3d57277f60e6fddd0a0de98`。比较源为 `F:\-FPGA--main`，目标为 `E:\fpga`；F 盘未修改。目录对比及缺失清单见 inventory.json；修改前用户 TD 工程及相关文件在 before/，原始用户差异在 before_dirty.patch。

## 实际交付

1. 合入 `scripts/prepare_video.py` 和 `scripts/test_prepare_video.py`，原样保留 F 盘 AVF 打包格式。主机侧支持 quality（320×240 RGB565LE）与 legacy（160×120 BGR24），20 fps/16 kHz 单声道 PCM；主回归新增 8 项转换/格式测试。
2. 将视频顶层、11 个 AVF/模式切换激励、辅助脚本和历史说明放入 `legacy/f_drive_video_reference/`，不参与正式编译。未复制 work、qdb、崩溃转储、旧 bit 或大容量素材。
3. 备份后补回根 TD 工程丢失的 7 个现有源引用，恢复 87 个正式源与嵌套工程、manifest 一致；保留现有 E 盘功能与官方 IP。TD 自动整理 AutoExcluded 属性与 XML 拼写，未修改 RTL。
4. 修复构建快照对 TD XML 重写的误报：`.al` 使用规范化 XML 摘要，其他输入继续按原始字节摘要比较。第二次构建因自动重写检测失败，保留失败历史；最终一次完整构建通过，未放宽时钟或时序约束。

## 验证

- `python scripts/static_check.py`：ALL PASS，87 源、40 IO，根/嵌套工程与源清单一致。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1`：108 项现有 RTL 回归通过，新增 8 项 AVF Python 测试通过。
- `python scripts/run_build.py`：综合、布局布线、独立最终 STA 完成，build_manifest.json 为 completed。
- 最终报告：SWNS +0.142 ns、STNS 0 ns；HWNS +0.024 ns、HTNS 0 ns。LUT 17,283/19,600（88.18%）、REG 11,014/19,600、BRAM 45/64、DSP 26/29。
- 没有新增 bit、没有下载板卡、没有写实体 TF 卡或连接串口。内部时序非负不能替代外部接口/实板验收；未达到整体 +0.5 ns。

## 未能合入的视频路径

F 盘清单列出 87 个 HDL 源，其中 80 个不存在，缺失 `src/modules`、`src/ip`，也无 Git 历史。递归搜索未找到 `sd_av_reader`、`av_sync_player`、`av_fast_scaler`、`boot_media_select` 等实现。因此当前 E 盘仍只走 BMP/WAV，尚不能读取 AVF 视频；不能用 F 盘旧日志/bit 冒充新功能已验证。需要补齐原工程正式源码后，再适配 FAT32、帧缓存、音画提交、控制与 OSD，并重新通过资源/时序门禁。

本轮没有修改 `src/top.v`、SD/FAT32/BMP/WAV RTL、70 位状态布局、引脚、PLL、时序约束或必要官方 IP。用户开始时删除的 `.lock.f` 不纳入交付变更。
