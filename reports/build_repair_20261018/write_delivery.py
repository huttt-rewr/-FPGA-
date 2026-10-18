from pathlib import Path
import json
import re

root=Path(__file__).resolve().parents[2]
folder=Path(__file__).resolve().parent
v=json.loads((folder/'validation.json').read_text())
m=v['timing_ns'];w=v['worst_by_check'];r=v['resources']
gate=r['gate_area.txt'];physical=r['physical_area.txt']
rows=[]
for tag in ['build1','build2','build3','build4']:
    p=folder/tag/'build_manifest.json'
    if not p.exists():continue
    b=json.loads(p.read_text());t=b.get('timing_ns')
    rows.append(f"| {tag} | {b['status']} | "+
                (f"{t['SWNS']:+.3f} | {t['STNS']:+.3f} | {t['HWNS']:+.3f} |" if t else '无有效 STA | — | — |'))
result=f'''# 构建修复验收记录（2026-10-18）

**当前保留 {v['selected_build']} 的源码与报告；93 项仿真通过，内部 STA 未通过，未生成本轮 bit。**

## 已完成

- 顶层共享时钟/复位、`res_mode`、模式连线和 `vs` 声明前移。逐语句审计确认顶层除此之外没有逻辑变化，TD 的 HDL-7225/5373 前向声明警告消失。
- 缩放器完整乘积位宽和低16/高16行地址进位拆拍；新增 bit32 状态。1920×1080全部源行及进位/回绕/跨扇区/复位检查 5,437 项通过。
- 本地挂载完成寄存器隔离进入图片调度的长路径；源列控制和FAT比较候选因物理冲突均已撤回，FAT32解析器保持原版。
- 构建归档覆盖全部辅助路径报告，失败时拒绝旧产物；故障测试通过。
- 两位模式 CDC 测试和地址测试正式加入 ModelSim 回归。KEY/SW操作和连接不变。

## 验证结果

| 检查 | 结果 |
|---|---|
| 静态检查 | 77 源、40 IO，ALL PASS |
| ModelSim | 93 个不同测试，全部通过 |
| VGA/SVGA缩放 | 各9帧逐像素黄金比较，含1920×1080源图与1×1源图 |
| 末端视频流水 | 787,200像素、VS/DE和坐标对齐通过 |
| 综合 | {gate['lut']:,} LUT / {gate['reg']:,} REG / {gate['bram']} BRAM / {gate['dsp']} DSP |
| 物理 | {physical['lut']:,} LUT / {physical['reg']:,} REG / {physical['bram']} BRAM / {physical['dsp']} DSP |
| 最终SWNS / STNS | {m['SWNS']:+.3f}ns / {m['STNS']:+.3f}ns |
| 最终HWNS / HTNS | {m['HWNS']:+.3f}ns / {m['HTNS']:+.3f}ns |
| 最差普通setup | {w['setup']['slack_ns']:+.3f}ns |
| 报告中最差recovery | {w['recovery']['slack_ns']:+.3f}ns |
| 报告中最差removal | {w['removal']['slack_ns']:+.3f}ns |
| 新bit / 下载 / 实板 | 均未执行 |

物理 LUT 为 {physical['lut']/19600*100:.2f}%，仍未达到85%目标。58/64 BRAM为90.625%，不能表述成≤90%。两个加密HDMI核及实例参数、全部官方IP、70位状态总线及取位、IO与时钟约束均未改变；没有降频或新增false path。

## 尚未解决

普通 setup 最差起点为 `{w['setup']['start']}`，终点为 `{w['setup']['end']}`。负值是真实失败，不能用布局阶段的正值或某一条已改善路径代替整机签核。

两处 PHY-7002、一处 PHY-5079 仍在，且仍为 CRITICAL-WARNING。工程没有对应可删除的非法用户位置约束，PLL到SDRAM无用户门控；不能删官方硬宏或擅自取消所需移相。EG4S20不支持本次尝试的 `report_clock_utilization -dramhardcon` 命令。这些警告未被证明无害，需要安路确认合封SDRAM模型、位置与时钟资源支持。

本轮沿用已能完成的避崩实现流程，没有重启已知会在 Abnormal Timing Path check 崩溃的 post-route phys_opt。本轮选定路由没有 coredump；这并不等于 STA 已通过。

HDMI内部复位removal不是HDMI管脚hold；没有外部IO或实板签核，没有整体+0.5ns声明。未调用bitgen，不能用历史bit验收当前源码。

## 试验与取舍

| 轮次 | 真实结果 | SWNS(ns) | STNS(ns) | HWNS(ns) |
|---|---|---:|---:|---:|
{chr(10).join(rows)}

源列控制候选在两种布局策略下都发生PHY-8023冲突，已经撤回。第四轮FAT比较候选虽然93项仿真通过，但 `x11y55_w2beg4` 上两个FAT mux网发生PHY-8023冲突，因此也已撤回，`sd_fat32.v` 恢复为基线原文件。原候选保存在 `fat_compare_candidate.v` / `.patch` 供后续检查。

正式保留第三轮。恢复后逐文件输入哈希与该轮构建清单完全一致，根reports已恢复为该轮真实产物，并重新运行全部93项回归。没有把第四轮失败实现冒充成功；故障轮目录里的 `untrusted_preexisting_*` 是旧辅助产物，明确不参与该轮STA验收。

基线为 `f8272d50c10cb216dd286d70fcd8959b2bb6e065`，其SWNS −0.402ns含复位recovery，普通setup −0.401ns、HWNS +0.021ns。不能用附件的旧−9.243ns当作本轮修改前基线夸大改善。

行地址定向对比为基线+0.895ns/9.034ns、第一轮拆拍后+1.189ns/8.740ns；实际约改善0.294ns，未达到“约3ns路径”的预期。每个源行增加10ns准备时间，显示刷新率和逐像素插值不变。

## 证据

- [源码/报告哈希与测试绑定](validation.json)、[保护范围审计](scope.json)
- [选定布线后STA]({v['selected_build']}/routed_timing_paths20.txt)、[构建清单]({v['selected_build']}/build_manifest.json)
- [完整回归]({v['regression']})、`final_test_logs/` 中的逐项日志
- [详细技术与使用边界](../../docs/BUILD_REPAIR_20261018.md)
- 修改前备份：`E:/fpga/backups/build_repair_20261018/before.zip`

未修改SD三层栈、音频解析和音效；完整保留双分辨率、EDID、FAT32/MBR、1920×1080源图、双线性、字幕、OSD、玻璃、特效、波形和游戏。功能仿真通过不代替实板画面、声音或SD吞吐验收。
'''
(folder/'RESULT.md').write_text(result,encoding='utf-8')
for name in ['README.md','docs/BUILD_STATUS.md','docs/USER_GUIDE.md']:
    p=root/name;text=p.read_text(encoding='utf-8-sig')
    text=re.sub(r'\n> \*\*2026-10-18 构建修复：[^\n]*\n\n?', '\n', text)
    report='reports/build_repair_20261018/RESULT.md' if name=='README.md' else '../reports/build_repair_20261018/RESULT.md'
    detail='docs/BUILD_REPAIR_20261018.md' if name=='README.md' else 'BUILD_REPAIR_20261018.md'
    notice=(f'\n> **2026-10-18 构建修复：93项回归通过，STA仍未通过，无本轮新bit。** '
            f'前向声明修复、行地址拆拍和报告归档保护已落实。当前SWNS {m["SWNS"]:+.3f}ns、'
            f'HWNS {m["HWNS"]:+.3f}ns；SDRAM物理警告仍待解决。全部功能和KEY/SW操作保留，未达到整体+0.5ns。'
            f'见[实际报告]({report})和[技术说明]({detail})；下文较早数值只适用于各自冻结的历史版本。\n')
    pos=text.index('\n')+1;text=text[:pos]+notice+text[pos:]
    if name=='docs/BUILD_STATUS.md':
        text=text.replace('## 本轮候选bit（尚未下载）','## 历史：native50候选bit（尚未下载）')
    p.write_text(text,encoding='utf-8')
print('Wrote RESULT.md and current status notices in README/BUILD_STATUS/USER_GUIDE')
