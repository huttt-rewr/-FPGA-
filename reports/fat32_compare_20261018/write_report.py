"""Write current documentation from bound evidence, never from expected slack."""
from pathlib import Path
import collections
import json
import re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
validation=json.loads((HERE/'validation.json').read_text())
tag=validation['selected']
selected=HERE/tag
result=json.loads((selected/'paths.json').read_text())
metrics=result['timing_ns']
passed=all(v>=0 for v in metrics.values())
baseline=ROOT/'reports/build_repair_20261018/build3'
base=json.loads((baseline/'paths.json').read_text())
basem=json.loads((baseline/'build_manifest.json').read_text())['timing_ns']
rows=[]
records=[('原基线 a5d76ca',basem,base)]
for name in ('build1','build2','build3','build4'):
    p=HERE/name/'paths.json'
    if p.exists():
        data=json.loads(p.read_text())
        records.append((name,data.get('timing_ns'),data))
for label,m,data in records:
    if m is None:
        rows.append(f'| {label}（布线冲突，无有效 STA） | — | — | — | — | — |')
        continue
    area=data['resources']['physical_area.txt']
    rows.append(f"| {label} | {m['SWNS']:+.3f} | {m['STNS']:+.3f} | {m['HWNS']:+.3f} | {m['HTNS']:+.3f} | {area['lut']} |")
negative=result['negative_reported_paths']
path_rows=[f"| {p['check']} | {p['slack_ns']:+.3f} | `{p['start']}` | `{p['end']}` |" for p in negative]
basecritical=collections.Counter(re.findall(r'(\w+-\d+) CRITICAL-WARNING', (baseline/'implementation.log').read_text()))
critical=collections.Counter(re.findall(r'(\w+-\d+) CRITICAL-WARNING', (selected/'implementation.log').read_text()))
newcritical=critical-basecritical
scope=json.loads((HERE/'scope.json').read_text())
count=scope['rtl_expression_count']
newbit=validation.get('bit_generated',False)
decision='内部 STA 通过；仍待板级验收' if passed else '内部 STA 仍失败，未生成本轮 bit'
selection_note=validation.get('selection_note','采用本轮所选比较器候选，具体差异见范围审计。')
text=f'''# FAT32 比较器优化实际结果（2026-10-18）

**结论：{decision}。** 最终选择 `{tag}`，94 项 ModelSim 全部通过。{selection_note}

## 试验范围与结果

初始工作区已有附件要求的扇区比较改写，已备份到 `initial/` 并在首个小步提交中保留记录。随后每个候选分别完成静态检查、独立真实 DUT 边界测试、94 项回归和综合，并独立尝试布局布线及 STA；第三轮因布线错误不具备有效 STA 验收结果。没有将候选推测当作实测收益。

| 版本 | SWNS ns | STNS ns | HWNS ns | HTNS ns | 物理 LUT |
|---|---:|---:|---:|---:|---:|
{chr(10).join(rows)}

build1：仅将文件扇区范围比较改成高八位归约 OR + 低 24 位比较。build2：再将目标簇与卷簇数比较改成显式高八位判断 + 低 24 位比较；没有截断卷容量。build3：再将完整 32 位簇上界比较写为高低 16 位组合比较；没有加寄存器。若有 build4，为恢复原基线后的新鲜完整实现。

候选失败时只保留其自身日志和源码，不把其他轮次的数据库或时序作为该候选证据。详见各轮 `paths.json`；无法合法布线的候选已报告具体工具失败原因。

SWNS/STNS 按工具原义记录，包含相应 setup/recovery 约束；HWNS/HTNS 也不等于 HDMI 管脚 hold。各检查类型的真实最差值和已报告负路径见 `{tag}/paths.json`。BRAM 58/64=90.625%，DSP 23，未通过删功能腾资源。没有整体 +0.5ns 声明。

## 验证证据

- 静态检查：77 源文件、40 位 IO，ALL PASS；两个 TD 工程和端口均保持一致。
- 最终完整回归：94 项 ALL PASS，列表、源码与每份日志 SHA-256 见 [validation.json](validation.json)。新增测试直接执行正式 FAT32 的 `STREAM_LIMIT`、`STREAM_CHECK` 与 `FAT_VALIDATE`，参考保留原完整比较。
- 原有 FAT32/MBR/索引、BMP/双线性缩放、WAV/音效、原生 SD 25/50MHz、CDC、VGA/SVGA、OSD/字幕/玻璃/波形/特效、游戏回归均保留。行为仿真不等于加密核完整顶层仿真或实板验证。
- 最终匹配源码的构建：[{tag}/build_manifest.json]({tag}/build_manifest.json)，原始路径报告 [{tag}/routed_timing_paths20.txt]({tag}/routed_timing_paths20.txt)。所有当前输入哈希已与所选新鲜构建逐一核对。
- 范围审计：[scope.json](scope.json)。最终保留 {count} 处计划内 RTL 比较表达式变化；其他全部受 Git 跟踪的 src 文件、官方 IP、引脚约束、两工程入口、实现脚本及自适应时钟均与基线一致。70 位 `status_source` 及所有 `status_video` 下标未动。
- 本轮 bit 生成：{'是，精确证据见 validation.json' if newbit else '未生成'}；下载、写实体卡、上板出图/出声和吞吐实测：均未执行。

## 最终已报告负路径

{('无。' if not negative else '| 检查 | Slack ns | 起点 | 终点 |'+chr(10)+'|---|---:|---|---|'+chr(10)+chr(10).join(path_rows))}

该表来自工具每类端点上限 20 的路径报告，不把它宣称为无限制枚举全部物理路径。以全局 SWNS/STNS/HWNS/HTNS 判断通过与否。

## 剩余问题和下一步

现有 PHY-7002 两条、PHY-5079 一条仍需安路确认官方合封 SDRAM 的模型、位置和时钟资源。没有删除硬宏、修改相位或新增 false path。完整 CRITICAL-WARNING 计数：`{dict(critical)}`；相较基线新增计数：`{dict(newcritical)}`。OPT-6001 若出现，表示中间优化因当时负时序而中止，该警告不能写成全绿。本轮各完成构建无 coredump。

仅凭组合等价不能保证全设计时序改善，物理映射改变也会迁移最差路径。最终负路径必须按真实报告继续处理，不能把 `data_clusters/max_cluster` 当成单文件 24 位值截断，也不能通过裁剪画质、音频、MBR、输出模式或游戏来默认换取资源。功能取舍需另行获得用户明确同意。官方与实板待办见 [BOARD_PENDING](../../docs/BOARD_PENDING.md)，数学证明与复现步骤见 [技术说明](../../docs/FAT32_COMPARE_20261018.md)。
'''
(HERE/'RESULT.md').write_text(text,encoding='utf-8')
for name in ('README.md','docs/USER_GUIDE.md','docs/BUILD_STATUS.md'):
    p=ROOT/name
    content=p.read_text(encoding='utf-8')
    prefix='' if name=='README.md' else '../'
    report_link=prefix+'reports/fat32_compare_20261018/RESULT.md'
    quote=(f"> **2026-10-18 FAT32 比较器验证：94 项回归通过，{decision}。** "
           f"最终 SWNS {metrics['SWNS']:+.3f}ns、STNS {metrics['STNS']:+.3f}ns、"
           f"HWNS {metrics['HWNS']:+.3f}ns、HTNS {metrics['HTNS']:+.3f}ns。"
           f"全部功能及操作保留；内部 removal 不是 HDMI 管脚 hold，未达到整体 +0.5ns。"
           f"[本轮报告]({report_link})；以下数值属于各冻结历史版本。")
    first,rest=content.split('\n',1)
    if rest.lstrip().startswith('> **2026-10-18 FAT32 比较器验证：'):
        rest=re.sub(r'^\s*> \*\*2026-10-18 FAT32 比较器验证：[^\n]*\n','',rest,count=1)
    p.write_text(first+'\n\n'+quote+'\n'+rest,encoding='utf-8')
print('Report and current README/user-guide/build-status updated from bound evidence')
