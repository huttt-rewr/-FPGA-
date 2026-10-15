"""Refresh current documentation from frozen actual evidence, never invent STA."""
from pathlib import Path
from datetime import datetime, timezone, timedelta
import json
import re

root = Path(__file__).resolve().parents[2]
out = root/'reports/fat32_20261015'
audit = json.loads((out/'scope_audit.json').read_text())
assert audit['test_count'] == 61
manifest = json.loads((out/'build_manifest.json').read_text())
m = manifest['timing_ns']
area = (out/'physical_area.txt').read_text()
resources = {key: int(re.search(r'^#'+key+r'\s+(\d+)', area, re.M)[1])
             for key in ('lut', 'reg', 'bram', 'dsp', 'pll')}
summary = (out/'timing_summary.txt').read_text()
setup = re.search(r'Slack\s+: ([+-]?[\d.]+)ns\s+Begin Point\s+: ([^\n]+)\nEnd Point\s+: ([^\n]+)\nCheck Type\s+: setup', summary)
assert setup
status = '通过' if manifest['status'] == 'completed' else '**未通过 setup 时序验收**'
passed = manifest['status'] == 'completed'
regression_log = audit.get('regression_log', 'regression_boot.log')
build_time = datetime.fromisoformat(manifest['finished_utc']).astimezone(timezone(timedelta(hours=8))).isoformat()
limitation = ('原约束下内部STA通过，仍需实体卡/显示器与板级外部时序验收。'
              if passed else '负值表示尚未满足原100MHz约束；不能宣称已完成全部验收。')
next_work = ('后续工作：验证实体FAT32卡、连续轮播与HDMI出声；核对SD/DDC/TMDS外部时序与已有PHY警告。'
             if passed else '后续工作：先复核TD时钟对象跨物理阶段/数据库重载的一致性，再对实际违例路径做不改变逻辑行为的物理优化；原SD栈与RIFF解析仍属本次保护范围。禁止用历史正余量替代本版STA。')
paths = re.findall(r'Slack\s+: ([+-]?[\d.]+)ns\s+Begin Point\s+: ([^\n]+)\nEnd Point\s+: ([^\n]+)\nCheck Type\s+: setup', summary)
negative_paths = [p for p in paths if float(p[0]) < 0]
path_rows = '\n'.join(f'| {float(slack):+.3f} | `{begin.split(" (", 1)[0]}` | `{end.split(" (", 1)[0]}` |'
                      for slack, begin, end in negative_paths)
path_details = ('\n报告列出的负setup路径如下（只列实际报告，不推测未报告路径）：\n\n'
                '| Slack/ns | 起点 | 终点 |\n|---|---|---|\n'+path_rows+'\n'
                if negative_paths else '')
report = f'''最终冻结源码：静态检查 **ALL PASS（63 源、36 IO）**；完整 ModelSim **61/61 PASS**（包含三个 FAT32 专项）；综合与布局布线完成。实际 Routed STA：{status}。

| 项目 | 最终实际值 |
|---|---|
| SWNS / STNS | {m['SWNS']:+.3f} / {m['STNS']:.3f} ns |
| HWNS / HTNS | {m['HWNS']:+.3f} / {m['HTNS']:.3f} ns |
| 资源 | LUT {resources['lut']}、REG {resources['reg']}、BRAM9K {resources['bram']}/64、DSP {resources['dsp']}、PLL {resources['pll']} |
| 回归 | 61/61；日志已冻结并记录 SHA |
| 构建完成时间 | {build_time}（北京时间） |
| 实板 | 未写卡、未下载、未验收显示/出声 |

最差 setup 起点 `{setup[2]}`；终点 `{setup[3]}`。{limitation} 没有降低频率、添加 false path 或改变 PLL。旧 bit 不具备 FAT32 功能，候选生成情况见下文。未达到 +0.5ns。

证据：[构建清单](build_manifest.json)、[冻结 STA](timing_summary.txt)、[时序汇总](timing_status.txt)、[资源](physical_area.txt)、[保护范围与回归 SHA](scope_audit.json)、[完整回归控制台]({regression_log})。冻结报告与当前源文件哈希一致，`audit_delivery.py --freeze` 会拒绝任何不一致。

{next_work}

{path_details}
'''
p = out/'RESULT.md'
s = p.read_text(encoding='utf-8')
a = s.index('## 最终验证结果') if '## 最终验证结果' in s else s.index('## 验证进度')
b = s.index('## 测试内容', a)
history = '''
此前多轮真实负时序归档于 `trial_*`，均不能认证当前源码；流水/布局变更也出现过退化。最终源码包含几何运算拆拍、簇游标/边界比较寄存、独热并行译码、客户端反馈寄存、BPB/目录元数据流水、文件描述符独立写使能及FAT扇区校验/标签提交拆拍。

独立 `phys_opt -post_route` 的 relocation 与 reroute 试验均发生 TD coredump，没有可用结果，未采用其数据库。最新 reroute 在 Abnormal Timing Path check 崩溃，见 `reroute_trial.log`（minidump-20261016-002909.dmp）。重载已布线数据库并重新建立既有模式时钟的试验报告为SWNS -15.539ns，明显不同于正式构建进程内的STA；这属于尚未解决的时钟/数据库重载一致性问题，不能用它替换正式报告，也不能据正式报告声称数据库可独立重现签核。正式流程已去掉post_place后的冗余时钟绑定，避免已观察到的四条USR-8170重复定义告警。

剩余工具告警必须复核：PHY-7002合封SDRAM位置未被接受；PHY-5079指出 `U3/u2_ram/SDRAM_CLK` 使用局部布线；官方IP仍有未驱动端口/初值等综合提示；OPT-6001显示部分物理阶段因过大的负SWNS中止路径优化。不能把这些统称为无害警告。BRAM9K已用59/64，后续增加缓存或音效需先核算剩余容量。

两套仿真共用镜像目录，请串行运行；曾因同时重新生成镜像出现读取失败。最终交付重新完整运行61项回归，包含三个FAT32专项，覆盖清理空行后的最终RTL及现有仿真源。

'''
s = s[:a]+'## 最终验证结果\n\n'+report+history+s[b:]
p.write_text(s, encoding='utf-8')
p = root/'docs/BUILD_STATUS.md'
s = p.read_text(encoding='utf-8')
a = s.index('## 当前：2026-10-15')
b = s.index('## 早先：WAV音频失败自动恢复', a)
brief = f'''## 当前：2026-10-15 FAT32 根目录文件播放

正式顶层读取普通 FAT32 卡根目录前四个 BMP 和第一个 WAV，支持碎片；63 源、36 IO。静态检查、61 项完整 ModelSim 回归通过，综合/布局布线完成；最终STA：{status}。SWNS {m['SWNS']:+.3f}ns、STNS {m['STNS']:.3f}ns；HWNS {m['HWNS']:+.3f}ns、HTNS {m['HTNS']:.3f}ns。LUT {resources['lut']}、REG {resources['reg']}、BRAM9K {resources['bram']}/64、DSP {resources['dsp']}、PLL {resources['pll']}。

操作见[FAT32 文件复制教程](FAT32_USAGE_20261015.md)，精确路径/范围/冻结日志见[最终验证报告](../reports/fat32_20261015/RESULT.md)。当前未生成 FAT32 新 bit，旧裸扇区 bit 不适用。尚未实板验收，未达到 +0.5ns；内部 removal 不属于 HDMI 管脚 hold。CLI 使用同一源清单直接加载，GUI elaborate 在本机出现工具崩溃，不能宣称 GUI 综合已通过。

下文均为历史证据，不能认证当前源码。

'''
p.write_text(s[:a]+brief+s[b:], encoding='utf-8')
p = root/'README.md'
s = p.read_text(encoding='utf-8')
line = f"\n当前验证：静态与61项回归通过，综合/布局布线完成；STA{status}（SWNS {m['SWNS']:+.3f}ns，HWNS {m['HWNS']:+.3f}ns）。详见本轮报告，不能使用旧bit验证普通文件拷贝。\n"
if '当前验证：静态与61项回归通过' in s:
    s = re.sub(r'当前验证：静态与61项回归通过[^\n]*', line.strip(), s)
else:
    pos = s.index('\n\n', s.index('2026-10-15 FAT32'))
    s = s[:pos]+'\n'+line+s[pos:]
p.write_text(s, encoding='utf-8')
print('Updated final docs from frozen actual STA and 61 passing tests')
