"""Publish only a verified candidate and its real regression/timing results."""
from pathlib import Path
import hashlib
import json
import runpy

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
bm = json.loads((OUT/'bitstream/manifest.json').read_text(encoding='utf-8'))
build = json.loads((ROOT/'reports/build_manifest.json').read_text(encoding='utf-8'))
assert bm['status'] == 'candidate_generated'
assert build['status'] == 'completed'
assert bm['after_timing_ns'] == bm['before_timing_ns'] == build['timing_ns']
assert bm['rtl_tests'] == 114
assert hashlib.sha256(Path(bm['bit_file']).read_bytes()).hexdigest() == bm['bit_sha256']
assert runpy.run_path(str(ROOT/'scripts/run_build.py'))['snapshot']() == build['sources']
runpy.run_path(str(OUT/'audit_scope.py'))
t = bm['after_timing_ns']
r = bm['resources']
timing = f"SWNS **+{t['SWNS']:.3f}ns**、HWNS **+{t['HWNS']:.3f}ns**，STNS/HTNS均0"
area = f"LUT **{r['lut']}/19600**、BRAM **{r['bram']}/64**、DSP **{r['dsp']}/29**"
bitname = Path(bm['bit_file']).name
bit = 'bitstream/'+bitname
evidence = f"""# 纯色单列窄菜单与两秒浮窗（2026-10-23）

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
- `python scripts/run_build.py`：退出码0，综合、布局布线与最终STA通过；{timing}，{area}。原始seed25即通过，没有修改RTL之外的时序约束或追加物理seed试验。
- `scope_audit.json`：ALL PASS，原70位status_source字序不变；除6项计划内修改与1份新增测试外，250份构建输入保持哈希一致。顶层唯一变化为菜单接入已有`mode_video`，SD/FAT32/BMP/WAV/SDRAM、官方IP、引脚及约束保持原样。

## 新候选bit

[{bitname}]({bit})，{bm['bit_bytes']}字节。

SHA256：`{bm['bit_sha256']}`。

生成前后STA完全一致，并核验当前源码、布线数据库和构建清单。详见[bit生成记录](bitstream/RESULT.md)、`bitstream/manifest.json`、`final_build/`。此前bit保留。

`board_signoff=false`，未下载到板卡、未上板验收，未达到整体+0.5ns；全局HWNS不能当作HDMI管脚hold签核。现存PHY-7002位置和PHY-5079局部时钟布线警告仍保留。

完整操作与仿真截图见[新版菜单手册](../../docs/MENU_SUBMENU_20261023.md)。原始文件和此前报告备份在`baseline/`。
"""
(OUT/'RESULT.md').write_text(evidence,encoding='utf-8')
(OUT/'bitstream/RESULT.md').write_text(f"""# 纯色窄菜单、子菜单、两秒提示候选bit

文件：[{bitname}]({bitname})

- 大小：{bm['bit_bytes']}字节。
- SHA256：`{bm['bit_sha256']}`。
- 生成前后最终STA一致：{timing}。
- 资源：{area}。
- 114项独立RTL回归通过，当前源码与综合快照、routed数据库哈希匹配。
- 四个视频/串行模式时钟均存在，旧bit未覆盖；未下载到板卡。

详细来源与哈希见`manifest.json`、`source_build_manifest.json`、`before_bit_timing_status.txt`及`after_bit_timing_status.txt`。board_signoff=false，未达到整体+0.5ns；内部HWNS不等于HDMI管脚hold签核，现存PHY警告保留。
""",encoding='utf-8')

def replace_notice(path, notice):
    text = path.read_text(encoding='utf-8')
    lines = text.splitlines()
    index = next(i for i,line in enumerate(lines) if line.startswith('> '))
    lines[index] = notice
    path.write_text('\n'.join(lines)+'\n',encoding='utf-8')

short = f"取消渐变，主菜单贴左、宽128个逻辑像素、只显示功能名称；KEY3进入子菜单，KEY1/KEY2调节，KEY3返回，长按关闭。菜单外调节亮度/对比度后，左上角显示最新值，最后一次实际变化后两秒消失，连续调节重新计时。94源/40 IO静态检查、114项RTL主回归、10项Python及VGA/SVGA共14169600像素专项通过；{timing}，{area}。"
replace_notice(ROOT/'README.md',f"> **2026-10-23 最新：纯色单列子菜单与两秒参数提示，新候选bit已生成。** {short} **[本轮新bit](reports/menu_submenu_20261023/{bit})** 为{bm['bit_bytes']}字节；见[本轮结果](reports/menu_submenu_20261023/RESULT.md)和[操作说明](docs/MENU_SUBMENU_20261023.md)。生成前后STA及源码/数据库校验一致，未上板、未达到整体+0.5ns；后文渐变及更早bit均为历史版本。")
replace_notice(ROOT/'docs/BUILD_STATUS.md',f"> **2026-10-23 最新：纯色128像素单列菜单、子菜单及两秒提示，候选bit已生成。** {short} [本轮新bit](../reports/menu_submenu_20261023/{bit})为{bm['bit_bytes']}字节，生成前后STA及源码/数据库哈希一致；见[结果](../reports/menu_submenu_20261023/RESULT.md)和[操作](MENU_SUBMENU_20261023.md)。board_signoff=false，未上板、未达到整体+0.5ns；全局HWNS不代表HDMI管脚hold。以下数据与bit为历史版本。")

readme = ROOT/'README.md'
text = readme.read_text(encoding='utf-8').replace('2026-10-23 最新候选 bit：中文菜单彩色渐变版已生成。','2026-10-23 历史候选 bit：中文菜单彩色渐变版。')
text = text.replace('以下按日期保留历史构建记录；其中纯色菜单与更早bit均不包含本次渐变，最新入口以上述渐变版为准。','以下按日期保留历史构建记录；最新入口以本文顶部的纯色子菜单版为准。')
readme.write_text(text,encoding='utf-8')
status = ROOT/'docs/BUILD_STATUS.md'
status.write_text(status.read_text(encoding='utf-8').replace('2026-10-23 最新：彩色渐变菜单候选bit已生成。','2026-10-23 历史记录：彩色渐变菜单候选bit。'),encoding='utf-8')
manual = ROOT/'docs/MENU_SUBMENU_20261023.md'
text = manual.read_text(encoding='utf-8')
old = '菜单按键专项、浮窗计时专项、VGA/SVGA完整像素专项均已通过，详见[本轮结果](../reports/menu_submenu_20261023/RESULT.md)。当前源码与此前渐变版bit不同；新bit与最终构建状态以该结果页为准。'
assert old in text
text = text.replace(old,f"菜单与浮窗专项、114项RTL主回归、10项Python测试、静态检查及综合/P&R/最终STA全部通过。{timing}，{area}。[本轮新bit](../reports/menu_submenu_20261023/{bit})已生成，{bm['bit_bytes']}字节；生成前后STA及源码/数据库一致，详见[本轮结果](../reports/menu_submenu_20261023/RESULT.md)。未上板验收，旧渐变bit不包含这次改造。")
manual.write_text(text,encoding='utf-8')
print('ALL PASS result publication; source snapshots unchanged')
