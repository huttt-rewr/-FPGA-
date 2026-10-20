from pathlib import Path
import json,shutil
root=Path(__file__).resolve().parents[2]
task=Path(__file__).resolve().parent
assert json.loads((root/'reports/build_manifest.json').read_text())['status']!='running'
# Candidate proof is its ModelSim log.
log=(task/'bram_levels_candidate/test.log').read_text(errors='replace')
assert 'ALL PASS tb_auto_enhance' in log and 'FAILED' not in log
for name in ('auto_enhance.v','auto_enhance_scale.v'):
 shutil.copy2(task/'bram_levels_candidate'/name,root/'src/modules/video'/name)
p=root/'scripts/implement.tcl'
s=p.read_text();assert 'set_param place seed 35' in s
p.write_text(s.replace('set_param place seed 35','set_param place seed 25'),encoding='utf-8')
p=task/'PHYSICAL_ATTEMPTS.md'
with p.open('a',encoding='utf-8') as f:
 f.write('\n\n阶段三seed35最终SWNS −0.181ns、STNS −0.181ns、HWNS +0.020ns、HTNS 0，105项通过；WAV position→position_ok setup未通过。冻结phase3_seed35_wav_setup_failed/。随后将新增自动色阶的三路倒数表改同步ROM，四拍延迟和逐值结果通过独立原参考验证，再执行完整门禁。未修改WAV或约束。\n')
print('Installed independently verified synchronous ROM levels; seed25')
