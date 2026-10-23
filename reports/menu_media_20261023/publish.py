from pathlib import Path
import json,hashlib,runpy
O=Path(__file__).resolve().parent;R=O.parents[1]
d=json.loads((O/'bitstream/manifest.json').read_text(encoding='utf-8'))
b=json.loads((R/'reports/build_manifest.json').read_text(encoding='utf-8'))
assert d['status']=='candidate_generated' and d['rtl_tests']==116
assert d['after_timing_ns']==d['before_timing_ns']==b['timing_ns']
assert runpy.run_path(str(R/'scripts/run_build.py'))['snapshot']()==b['sources']
assert hashlib.sha256(Path(d['bit_file']).read_bytes()).hexdigest()==d['bit_sha256']
runpy.run_path(str(O/'audit_scope.py'))
bit=Path(d['bit_file']).name;t=d['after_timing_ns'];a=d['resources']
metrics=f"SWNS +{t['SWNS']:.3f}ns、HWNS +{t['HWNS']:.3f}ns，STNS/HTNS均0；LUT {a['lut']}/19600、BRAM {a['bram']}/64、DSP {a['dsp']}/29"
result=f'''# 媒体与分辨率菜单：完成记录（2026-10-23）

已新增第二页图片、视频、音乐、分辨率；保留第一页面八项、纯色128像素窄面板、两秒亮度/对比度提示。KEY3进入子菜单不会立即执行；媒体子菜单KEY1或KEY2执行下一文件。相册模式分辨率KEY1请求640×480，KEY2请求800×600，显示实际输出尺寸；EDID不支持时回退。AVF输出仍固定640×480。

同模式选择下一文件，跨模式选择该类型首个文件；切换会按原逻辑重启媒体链路、菜单关闭。相册WAV沿已有音轨选择输入递增，最后一首回到第一首。文件列表空/加载忙时不排队追加同类型请求。没有修改媒体文件格式或数据通路。

## 验证

- static_check：ALL PASS，94 sources、40 IO bits；端口/引脚/TD源清单一致。
- 主回归：退出码0，ALL TESTS PASSED；116项独立RTL及10项Python（9项AVF工具、1项字库）。日志归档main/，哈希见regression.json。
- tb_menu_media：ALL PASS，实际按键、12项/两页循环、进入无动作、互斥脉冲、跨类型首文件/同类型下一文件、模式请求跨控制复位保持、键盘/组合键/菜单最后请求优先、重复同目标组合键。
- tb_menu_media_pixels：ALL PASS，10完整VGA帧3072000像素，独立字模与数值oracle，图片/视频/音乐/分辨率标签、实际640/800输出、回退、RGB/VS/DE两拍对齐。
- tb_chinese_menu、tb_menu_overlay、tb_menu_popup：ALL PASS，原菜单按键、18完整VGA帧5529600像素及两秒提示无退化。
- tb_menu_popup_page2：ALL PASS，最后停在第二页后关闭，外部亮度/对比度提示仍显示原参数，不误用媒体名称；两种像素时钟、重新计时、到期/复位通过。
- 字库：追加13字，90字/1440word，原77字/1232word完整保留；原32字也保持哈希一致。
- run_build：退出码0，综合/P&R/最终STA通过，{metrics}。原seed25通过，无额外物理试验，时序约束未修改。
- scope_audit.json：ALL PASS，原70位status_source位宽/位序不变；248份构建输入哈希不变。SD/FAT32/BMP/WAV/SDRAM、官方IP、引脚、时序约束未修改。

本轮相对上版LUT增加138、REG增加22，BRAM/DSP保持57/23。新增控制状态和字库未超过资源门限。

## 新候选bit

[{bit}](bitstream/{bit})，{d['bit_bytes']}字节。

SHA256：`{d['bit_sha256']}`。

116项新鲜回归日志、源码快照与routed数据库哈希核对通过，生成前后STA完全一致，四个视频/串行模式时钟均存在。见[生成记录](bitstream/RESULT.md)、bitstream/manifest.json与final_build/。此前bit不是本轮功能版本，未覆盖。

board_signoff=false，未下载板卡、未实板验证、未达到整体+0.5ns；全局HWNS不等于HDMI管脚hold签核。原PHY-7002/PHY-5079及字库未选中分支等既有综合警告保留，未声称零警告。

详细用法与截图见[媒体菜单手册](../../docs/MENU_MEDIA_20261023.md)。原始文件及此前构建记录见baseline/。
'''
(O/'RESULT.md').write_text(result,encoding='utf-8')
(O/'bitstream/RESULT.md').write_text(f'''# 媒体与分辨率菜单候选bit

[{bit}]({bit})，{d['bit_bytes']}字节。

SHA256：`{d['bit_sha256']}`。

{metrics}。生成前后STA完全相同；116项RTL回归与源码、routed数据库哈希核对一致。四个视频/串行时钟模式均存在，原bit未覆盖。原PHY告警保留。

完整来源见manifest.json、source_build_manifest.json与前后STA报告；尚未下载硬件、未上板验收，board_signoff=false，未达整体+0.5ns，内部HWNS不能当作HDMI管脚hold签核。
''',encoding='utf-8')
def notice(path,line):
 p=R/path;ls=p.read_text(encoding='utf-8').splitlines();i=next(i for i,l in enumerate(ls) if l.startswith('> '));ls[i]=line;p.write_text('\n'.join(ls)+'\n',encoding='utf-8')
notice('README.md',f'> **2026-10-23 最新：媒体/分辨率菜单完成，新候选bit已生成。** 新增第二页图片、视频、音乐、分辨率；KEY3进入，KEY1/KEY2执行。同模式下一文件，跨模式从首文件开始；相册模式支持请求640×480/800×600，AVF仍固定640×480，未支持EDID时回退。116项RTL、10项Python、94源/40 IO静态检查和综合/P&R/最终STA通过，{metrics}。[本轮新bit](reports/menu_media_20261023/bitstream/{bit})为{d["bit_bytes"]}字节，生成前后STA及源码/数据库一致；见[操作手册](docs/MENU_MEDIA_20261023.md)、[本轮结果](reports/menu_media_20261023/RESULT.md)。未上板、未达整体+0.5ns，后文bit与数据为历史版本。')
notice('docs/BUILD_STATUS.md',f'> **2026-10-23 最新：媒体菜单版bit已生成。** 116项RTL、10项Python、94源/40 IO静态检查及综合/P&R/最终STA通过；{metrics}。[新bit](../reports/menu_media_20261023/bitstream/{bit})为{d["bit_bytes"]}字节，前后STA与源码/数据库匹配。操作见[媒体菜单](MENU_MEDIA_20261023.md)，证据见[结果](../reports/menu_media_20261023/RESULT.md)。board_signoff=false，未上板、未达整体+0.5ns；全局HWNS不是HDMI管脚hold签核。下文为历史记录。')
p=R/'docs/MENU_MEDIA_20261023.md';s=p.read_text(encoding='utf-8');s=s.replace('源码已经接入；是否已生成包含这些功能的新bit，请看[本轮验证记录](../reports/menu_media_20261023/RESULT.md)。',f'源码已接入且全量验证通过，[包含新功能的bit](../reports/menu_media_20261023/bitstream/{bit})已生成（{d["bit_bytes"]}字节）；见[本轮验证记录](../reports/menu_media_20261023/RESULT.md)。');p.write_text(s,encoding='utf-8')
assert runpy.run_path(str(R/'scripts/run_build.py'))['snapshot']()==b['sources']
print('ALL PASS publication; current source snapshot still matches verified bit')
