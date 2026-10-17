"""Freeze successful candidate evidence without editing project documentation."""
from datetime import datetime, timezone, timedelta
import hashlib
import json
from pathlib import Path
import re
import shutil

root=Path(__file__).resolve().parents[2]
out=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def read_log(path):
 data=path.read_bytes()
 return data.decode('utf-16' if data.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8',errors='replace')

manifest=json.loads((root/'reports/build_manifest.json').read_text())
assert manifest['status']=='completed',manifest['status']
assert manifest['timing_ns']=={'SWNS':0.034,'STNS':0.0,'HWNS':0.021,'HTNS':0.0}
for name,digest in manifest['sources'].items():
 assert sha(root/name)==digest,f'Build/source mismatch: {name}'
console=out/'opt4_regression.log'
text=read_log(console)
assert 'ALL TESTS PASSED' in text
tests=re.findall(r'^# Loading work\.(tb_\w+)\(fast\)',text,re.M)
assert len(tests)==len(set(tests))==61,len(tests)
frozen=out/'opt4/regression'
frozen.mkdir(exist_ok=True)
logs={}
for test in tests:
 p=root/f'reports/{test}.log'
 s=read_log(p)
 assert 'ALL PASS' in s and not re.search(r'FAILED|\*\* (Error|Fatal)',s),test
 shutil.copy2(p,frozen/p.name)
 logs[test]=sha(p)
baseline=json.loads((out/'baseline_sources.json').read_text())
changed=[name for name,digest in baseline.items() if sha(root/name)!=digest]
assert changed==['src/modules/sd/sd_fat32.v'],changed
for name in ('opt4_focused.log','opt4_active.log','geometry_differential.log'):
 assert 'ALL PASS' in read_log(out/name),name
record={'build_manifest_sha256':sha(root/'reports/build_manifest.json'),
 'changed_inputs':changed,'timing_ns':manifest['timing_ns'],'test_count':61,
 'regression_console_sha256':sha(console),'regression_log_sha256':logs,
 'target_margin_0_2ns_met':False,'board_verified':False,
 'inputs':manifest['sources']}
(out/'validation.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
time=datetime.fromisoformat(manifest['finished_utc']).astimezone(timezone(timedelta(hours=8))).isoformat()
report=f'''# FAT32 setup 时序试验与交付（2026-10-16）

当前保留优化4：四个几何比较提前寄存。构建完成时间：{time}（北京时间）。

## 最终判定

静态检查ALL PASS（63 sources、36 IO）；FAT32专项三项PASS；完整ModelSim **61/61 PASS**；综合、布局布线、原约束下最终STA通过：SWNS **+0.034ns**、STNS 0，HWNS **+0.021ns**、HTNS 0。达到本任务“非负/变正停止”的验收项，**尚未达到期望的+0.2ns裕量，更未达到+0.5ns**。

实际最差setup：`sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/byte_cnt_reg[11]_syn_4.clk` → `sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/state_reg[4]_syn_4.a[1]`，100MHz，数据路径9.686ns（逻辑3.486ns、连线6.200ns），余量+0.034ns。报告中setup负端点为0，不能因此声称全部板级接口已经签核。

最终HWNS最差报告包含`gamma/out_x`→`effects` BRAM地址端的内部hold；它不是HDMI管脚hold。优化1的HWNS负值则明确是内部复位removal，两者不混淆。

资源：LUT15019、REG10052、BRAM9K59/64、DSP17、PLL2。未生成新bit、未下载、未写实体卡或验收真实显示/出声。

## 逐项真实结果

每个候选独立从相同基线修改，未达标即保存并回退，未将失败改动叠加。

| 候选 | SWNS/ns | HWNS/ns | 验证和处置 |
|---|---:|---:|---|
| 基线 | -0.695 | +0.021 | 附件所称fat_sectors→first_fat.ce不是本轮基线最差路径；实际为原SD命令逻辑 |
| 1：常数移位case | -0.637 | -0.327 | 专项、61项回归通过；66112次移位等价比较通过；时序未达标，回退 |
| 2：容量比较改写 | -1.014 | +0.024 | 专项和活动FAT2通过；时序退化，回退 |
| 3：活动FAT偏移延后一拍 | -0.296 | +0.021 | 专项、活动FAT2和61项回归通过；未转正，回退 |
| 4：几何比较预寄存 | **+0.034** | **+0.021** | 专项、活动FAT2、20种BPB差分和61项回归通过；保留 |

容量比较的数学等价依赖现有`fat_sectors[31:24]==0`上界校验。32位任意输入时，左移可能溢出，不能无条件宣称等价；100072组边界/随机比较验证了合法范围。常数移位本身是连线，原spc_shift仅3位，case形式不能保证比原映射更快，故只接受真实P&R结果。

优化5未启用：本机TD6.2.1的官方JSON/Tcl/文本帮助未找到明确的retiming/register balancing开关。`phys_opt -register_opt`描述为BRAM寄存器优化，不能冒充通用retiming；没有加入猜测选项，也没有再尝试已知会崩溃的post_route流程。

## 最终唯一代码改动

仅修改[sd_fat32.v](../../src/modules/sd/sd_fat32.v)：新增并异步复位`cmp_to/cmp_vol/cmp_lo/cmp_hi`。GEOM3读取已在GEOM2寄存的overhead/volume_last完成两项比较；GEOM5读取已在GEOM4寄存的data_clusters完成上下界比较；GEOM6使用四个布尔结果合并。非阻塞赋值的依赖至少间隔一拍。

未改变44位状态编码、状态转移、输出端口、SD/SPI栈、仲裁器、BMP/WAV算法、top、KEY/SW、PLL、时钟和约束；综合脚本未改。主README和历史冻结报告按本次“只改目标文件”的要求保留，本报告与当前根reports才是本轮证据。

## 功能与证据

- [最终构建清单](opt4/build_manifest.json)、[完整STA](opt4/timing_summary.txt)、[实际时序汇总](opt4/timing_status.txt)、[实现日志](opt4/implementation.log)、[源码哈希与61项回归审核](validation.json)。
- [完整回归控制台](opt4_regression.log)、[FAT32专项](opt4_focused.log)、[活动FAT2专项](opt4_active.log)、[20种BPB差分](geometry_differential.log)。活动FAT测试禁止读取FAT1，沿FAT2枚举碎片根目录和五个文件并逐字节比较Python参考；BPB差分逐拍比较原模块与候选的读请求、物理地址、错误码和目录描述符。
- `opt1/opt2/opt3/opt4`各目录保存对应源码与实际报告，不能将不同候选的最好数值拼成结果。最终报告覆盖原Slow/Fast角；器件Speed仍为NA，STA覆盖率及外部IO边界以工具报告为准。

已有PHY-7002 SDRAM位置、PHY-5079局部时钟布线、部分物理优化阶段OPT-6001和官方IP未驱动/初值等提示仍需复核，不声明无害；既有数据库重载/时钟对象一致性问题未在本任务内解决。+0.034ns仅为当前构建实际余量，后续布局或源码改变必须重新运行STA。

## 复现

在`E:/fpga`依次运行（两套仿真不能同时重建镜像）：

```powershell
python scripts/static_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_fat32_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_tests.ps1
python scripts/run_build.py
```

任务前备份：`backups/fat32_setup_20261016/before.zip`。所有既有非本轮报告改动保留。
'''
(out/'RESULT.md').write_text(report,encoding='utf-8')
print('ALL PASS delivery: exact build inputs, 61 unique passing tests, only target source changed')
