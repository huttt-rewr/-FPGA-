"""Publish only source-bound, frozen final STA and regression results."""
from pathlib import Path
import json
import runpy

here=Path(__file__).resolve().parent
root=here.parents[1]
tag='wav_ingress_final'
frozen=here/tag
result=json.loads((frozen/'paths.json').read_text())
manifest=json.loads((frozen/'build_manifest.json').read_text())
assert result['status']=='completed'
assert manifest['sources']==runpy.run_path(str(root/'scripts/run_build.py'))['snapshot']()
assert result['regression_count']==98 and result['tests_all_pass']
t=result['timing_ns']
assert all(t[k]>=0 for k in ('SWNS','STNS','HWNS','HTNS'))
metrics=f"SWNS {t['SWNS']:+.3f}ns、STNS {t['STNS']:.3f}ns、HWNS {t['HWNS']:+.3f}ns、HTNS {t['HTNS']:.3f}ns"
area=result['resources']['physical_area.txt']

text=f'''# 时序优化最终结果（2026-10-19）

本轮从源码重新综合、布局布线、独立会话增量布线/hold修复和最终Slow/Fast STA完成，四项指标均满足内部STA判据：**{metrics}**。98项ModelSim回归全部通过，77源/40 IO静态检查通过。输入源码、脚本和测试哈希绑定至 [{tag}/build_manifest.json]({tag}/build_manifest.json)，原始STA、完整逐项回归、资源与哈希见 [{tag}/paths.json]({tag}/paths.json)。这不是实板验收，也没有达到整体+0.5ns。

## 实际保留的修改

1. `scripts/adaptive_mode_clocks.sdc`持久加载原有VGA/SVGA模式时钟。TD内部重建时序引擎仍保留定义；保持25/125MHz和40/200MHz关系、100MHz主控、原互斥关系，无新增false path或时钟屏蔽。
2. `audio_wav.v`将数据/valid/end/error整体寄存一拍。FAT32 owner的高扇出组合路径终止于WAV入口，不再直接串入解析状态和字节计数器。增加10ns接收延迟，每拍仍可接收一个字节；格式限制、CRC后整扇区缓存、错误码、延时重试保持。
3. `run_build.py`增加独立`finalize_hold.tcl`阶段：重新载入本轮routed检查点，增量布线再fix_hold，刷新并检查完整STA。保留全部约束和逻辑；每个阶段的旧报告先归档，最终结果只取新会话产物。移位命令实际移动0个实例，已撤回；不依赖硬编码物理坐标或寄存器名。
4. 登记四个新增回归：FPS数学等价、FAT32真实调度等价、8192组图片索引及WAV接收边界。前三个候选RTL未保留；它们作为生产基线检查仍运行。新增接收测试覆盖最后字节/end同拍、分拍、CRC错误优先、511/513字节、PCM跨三扇区、背压、重试和复位排空。

## 结果对照

| 检查点 | SWNS ns | STNS ns | HWNS ns | HTNS ns | 结论 |
|---|---:|---:|---:|---:|---|
| build10，约束持久化后 | -1.518 | -8.273 | +0.021 | 0 | setup失败 |
| wav_ingress1，WAV接收寄存级 | +0.131 | 0 | -0.234 | -0.369 | setup通过，CDC总线hold失败 |
| wav_ingress2，另一布局策略 | +0.131 | 0 | -0.234 | -0.369 | 无改善 |
| wav_ingress3，同会话移动/重复fix_hold | +0.131 | 0 | -0.234 | -0.369 | 移动0实例，未采用 |
| {tag}，独立重载/增量布线后 | {t['SWNS']:+.3f} | {t['STNS']:.3f} | {t['HWNS']:+.3f} | {t['HTNS']:.3f} | 内部STA通过 |

setup相对build10改善{t['SWNS']+1.518:.3f}ns。最初owner到WAV路径11.238ns，75%来自布线；现在该负路径消除。接收寄存级后剩余hold来自status_cdc的held[36]，快角数据延迟0.420ns，小于所需时钟偏斜与hold预算；独立重载后的物理修复使全局最小检查非负。同会话重复fix_hold未改善，重载加增量布线已单独隔离验证；不能把结果归因于未实际移动的slice。

物理资源：LUT {area['lut']}、REG {area['reg']}、BRAM {area['bram']}、DSP {area['dsp']}。相对build10物理LUT17337，主要代价来自接收边界与重映射。器件利用率仍较高；内部裕量较小，不能把一次收敛写成充分余量。

## 实际路径分类

'''
for kind,p in result['worst_by_check'].items():
    text+=f"- **{kind} {p['slack_ns']:+.3f}ns**：`{p['start']}` → `{p['end']}`。\n"
text+='''
hold与removal分别按报告Check Type解释；内部复位removal不是HDMI管脚hold。外部SD/DDC/TMDS延迟仍未签核，Speed=NA。PHY-7002官方合封SDRAM位置警告、PHY-5079局部时钟资源警告仍在；未删除官方IP或调整时钟相位来隐藏它们。未下载、未写实体卡，未实测出图/出声/吞吐；本轮没有生成新bit。

## 验证与复现

```powershell
cd E:\\fpga
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
python reports/timing_close_20261018/evidence.py scope
```

完整回归进程退出0，98份新鲜日志均含ALL PASS且无FAILED/Error/Fatal。图像/FAT32/四位SD25/50MHz/音效/OSD/游戏未退化。源码审计相对d34c488只有audio_wav.v生产RTL变化；top、引脚、FAT32、BMP、SD栈及官方IP不变，KEY/SW操作不变。构建期间输入未变化，数据库与报告绑定当前哈希。局部修复前报告单独保留在prior_opt文件，最终结论使用routed报告。

bit生成条件与实板接口验收分开：内部STA通过仅满足生成候选的一部分条件；现存物理警告和外部接口边界仍需复核。旧native50 bit不包含当前全部功能。
'''
(here/'RESULT.md').write_text(text,encoding='utf-8')

banner=f'> **2026-10-19 当前时序优化：98项ModelSim全通过，综合/布局布线及内部STA通过。** {metrics}。WAV接收寄存级与独立会话增量布线/hold修复已落地；100MHz、全部功能、KEY/SW、官方IP和70位状态布局保留。未生成本轮新bit、未上板；外部IO与既有物理警告仍待核对，未达到整体+0.5ns。'
for name,link in [('README.md','reports/timing_close_20261018/RESULT.md'),('docs/BUILD_STATUS.md','../reports/timing_close_20261018/RESULT.md'),('docs/USER_GUIDE.md','../reports/timing_close_20261018/RESULT.md')]:
    p=root/name;s=p.read_text(encoding='utf-8-sig')
    if banner in s:continue
    first,body=s.split('\n',1)
    body=body.replace('> **2026-10-18 FAT32 比较器验证：','> **历史：2026-10-18 FAT32 比较器验证：')
    body=body.replace('> **2026-10-18 构建修复：','> **历史：2026-10-18 构建修复：')
    body=body.replace('> **2026-10-18 深度优化：','> **历史：2026-10-18 深度优化：')
    body=body.replace('## 当前交付：键盘、多文件、R/F与四位SD 25/50MHz','## 历史：键盘、多文件、R/F与四位SD 25/50MHz检查点')
    body=body.replace('80项逻辑回归及内部STA通过；','该历史检查点80项逻辑回归及内部STA通过；当前98项与STA见页首；')
    body=body.replace('80项ModelSim和内部STA结果见','80项是历史检查点；当前98项ModelSim和内部STA结果见')
    p.write_text(first+'\n\n'+banner+f'[本轮原始结果]({link})。此前各段数值只属于各自冻结历史版本。\n'+body,encoding='utf-8')

p=root/'docs/TIMING_CLOSE_20261018.md';s=p.read_text(encoding='utf-8')
s+='''
## 独立会话hold修复与最终复现（2026-10-19）

省略z的两个move_cells试验被PHY-5024拒绝；完整三维位置虽然命令执行结束，但实际移动0个实例。同会话整合后仍负hold，不能认定移动有效。随后去掉移动命令，独立验证“重载routed库→route -incremental→fix_hold”，得到四项非负。因此正式流程采用独立TD会话进行增量布线/hold清理，不依赖任何slice坐标。

implement.tcl导出本轮不可变hold检查点；run_build在新进程调用finalize_hold.tcl，旧报告先归档，再接收新routed数据库及全部STA报告。全部网表逻辑和时序检查保留，无新false path。物理结果必须重新检查全局setup/hold、模式时钟、布局DRC与源码哈希，不只检查held[36]。未来换TD版本或修改源文件仍需完整重跑；目前依据是受控试验结果，不宣称已定位TD内部算法根因。
'''
p.write_text(s,encoding='utf-8')
p=here/'TRIALS.md';s=p.read_text(encoding='utf-8')
s+='\n## 2026-10-19接续结果\n\n'+text.split('## 结果对照\n\n',1)[1].split('## 实际路径分类',1)[0]
p.write_text(s,encoding='utf-8')
print('Updated final result, README, BUILD_STATUS, USER_GUIDE and timing method/trial records')
