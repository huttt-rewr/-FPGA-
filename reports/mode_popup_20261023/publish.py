from pathlib import Path
import json
import runpy

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
manifest = json.loads((OUT/'bitstream/manifest.json').read_text(encoding='utf-8'))
assert manifest['status'] == 'candidate_generated'
build = json.loads((ROOT/'reports/build_manifest.json').read_text(encoding='utf-8'))
assert runpy.run_path(str(ROOT/'scripts/run_build.py'))['snapshot']() == build['sources']
t = build['timing_ns']
r = manifest['resources']
metrics = (f'SWNS {t["SWNS"]:+.3f}ns、HWNS {t["HWNS"]:+.3f}ns，'
           f'STNS/HTNS {t["STNS"]:.3f}/{t["HTNS"]:.3f}ns；'
           f'LUT {r["lut"]}/19600、REG {r["reg"]}、BRAM {r["bram"]}/64、DSP {r["dsp"]}/29')
bit_name = Path(manifest['bit_file']).name
result = f'''# 菜单外快捷模式高亮提示（2026-10-23）

## 操作

菜单关闭时短按KEY3（B1）并松开，模式按“播放→亮度→对比度→播放”循环。
左上角以黄色32×32字模显示“播放”“亮度”或“对比度”，约两秒后消失。
连续切换显示最新模式并重新计时。上电默认播放模式，不主动弹出。

提示期间实际调整亮度/对比度，改显示原有参数数值浮窗，从调整时重新计时。
打开菜单取消提示；菜单进入/返回及长按开关菜单不会误切快捷模式。
界面变化只在帧边界提交，640/800模式沿用既有坐标适配与实际像素时钟。
KEY1/KEY2快捷动作、长按KEY3、全部媒体菜单不变；A2仍是整机复位。

实际RTL仿真输出（为便于查看放大三倍）：

![播放](play.png)

![亮度](brightness.png)

![对比度](contrast.png)

## 改动与验证

- 修改src/modules/osd/menu_overlay.v、src/top.v、scripts/run_tests.ps1；新增sim/tb_menu_mode_popup.v。
- 用现有70位状态快照的[35:34]接入模式，原总线位宽/位序不变；复用原定时器、字库与两拍RGB/VS/DE流水线。
- SD/BMP/WAV/FAT32/SDRAM、官方IP、引脚、时序约束和字库数据均未修改。旧版兼容实例默认关闭MODE_POPUP；正式顶层明确开启。
- static_check：ALL PASS，94源、40 IO bits。
- tb_menu_mode_popup：ALL PASS，真实KEY消抖及CDC、三个模式、68544像素独立字模参考、黄色2倍字号、两种时钟精确计时、连续切换刷新、帧内稳定、数值浮窗/菜单/复位优先级。
- 六项菜单专项全部ALL PASS；117项独立RTL主回归及10项Python工具测试全部通过。原始日志在main/、regression.log；清单及哈希见regression.json。主脚本打印ALL TESTS PASSED；本次外层PowerShell重定向将unittest标准错误中的“... ok”包装成NativeCommandError，外层退出码为1。逐项检查117份新鲜RTL日志均有ALL PASS、无FAILED/Fatal，两组Python为Ran 9/1 tests、OK；这是日志包装异常，不是声称该外层退出码为0。
- 综合/P&R/最终STA通过：{metrics}。资源在门限内，BRAM/DSP仍为57/23。
- 生成bit前后STA一致，源码快照、路由数据库及测试日志一致性检查通过。见bitstream/manifest.json与final_build/。
- 逐文件差异见changes.diff，范围检查见scope_audit.json；修改前文件和构建记录在baseline/。

## 新候选bit

[{bit_name}](bitstream/{bit_name})，{manifest['bit_bytes']}字节。

SHA256：`{manifest['bit_sha256']}`。

下载这个版本才能看到新增提示，旧媒体菜单bit没有这项功能。未下载板卡、未实板验收，board_signoff=false，未达到整体+0.5ns；全局HWNS不是HDMI管脚hold签核。既有工具警告以实际报告为准，未宣称零警告。
'''
(OUT/'RESULT.md').write_text(result, encoding='utf-8')
for name in ['docs/MENU_SUBMENU_20261023.md', 'docs/MENU_MEDIA_20261023.md']:
    path = ROOT/name
    text = path.read_text(encoding='utf-8')
    label = f'[快捷模式提示新bit](../reports/mode_popup_20261023/bitstream/{bit_name})'
    if name.endswith('MENU_SUBMENU_20261023.md'):
        text = text.replace('旧bit不含此新增提示。', f'{label}已生成，旧bit不含此新增提示。')
    else:
        text = text.replace('上文媒体菜单旧bit不包含这次提示。', f'{label}已生成，上文媒体菜单旧bit不包含这次提示。')
    path.write_text(text, encoding='utf-8')
assert runpy.run_path(str(ROOT/'scripts/run_build.py'))['snapshot']() == build['sources']
print('ALL PASS publication; '+metrics)
