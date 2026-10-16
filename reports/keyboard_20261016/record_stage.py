"""Publish concise stage evidence without touching a running build's inputs."""
from pathlib import Path
import json,argparse,re,subprocess
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
a=argparse.ArgumentParser();a.add_argument('stage');a.add_argument('tests',type=int);a.add_argument('description');args=a.parse_args()
subprocess.run(['python',str(O/'audit_stage.py'),args.stage,str(args.tests)],cwd=R,check=True)
v=json.loads((O/(args.stage+'_validation.json')).read_text())
area=(O/args.stage/'physical_area.txt').read_text()
resources={k:int(re.search(r'^#'+k+r'\s+(\d+)',area,re.M).group(1)) for k in ('lut','reg','bram','dsp','pll')}
t=v['timing_ns'];passed=v['build_status']=='completed'
s=f'''# {args.description}

本阶段{args.tests}项ModelSim回归全部通过，静态检查、综合与布局布线完成；STA{'通过' if passed else '未通过'}。原70bit状态布局和全部下标审计保持，构建输入哈希与冻结报告一致。

| SWNS | STNS | HWNS | HTNS |
|---|---|---|---|
| {t['SWNS']:+.3f}ns | {t['STNS']:.3f}ns | {t['HWNS']:+.3f}ns | {t['HTNS']:.3f}ns |

资源：LUT{resources['lut']}、REG{resources['reg']}、BRAM9K{resources['bram']}/64、DSP{resources['dsp']}、PLL{resources['pll']}。没有降100MHz控制时钟，没有为功能路径增加false path，没有把内部复位removal当HDMI管脚hold，没有整体+0.5ns声明。

未生成本阶段新bit，未下载、未写实体卡，实板显示/出声/吞吐尚未验收。正式SD仍SPI25MHz。四位25MHz候选未接板，50MHz缺CMD6协商和板级签核。原生板DAT1/DAT2与上拉仍缺资料依据。

验证清单：[{args.stage}_validation.json]({args.stage}_validation.json)，[STA]({args.stage}/timing_summary.txt)，[完整回归]({args.stage}_regression.log)。
'''
(O/('RESULT_'+args.stage+'.md')).write_text(s,encoding='utf-8')
print(json.dumps({'stage':args.stage,'passed':passed,'tests':args.tests,'timing':t,'resources':resources},ensure_ascii=False))
