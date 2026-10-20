from pathlib import Path
import shutil,subprocess
task=Path(__file__).resolve().parent
production=task.parents[1]
candidate=task/'ir_candidate'
names=['ir_nec_rx','remote_controls','player_control','time_cmd','uart_rx','uart_tx','uart_tx_queue']
for sub in ('src/modules/control','sim','reports/remote_album_20261019/before/src/modules/control'):
 (candidate/sub).mkdir(parents=True,exist_ok=True)
for name in names:
 shutil.copy2(production/f'src/modules/control/{name}.v',candidate/f'src/modules/control/{name}.v')
for name in ('tb_ir_nec_rx','tb_remote_ir'):
 shutil.copy2(production/f'sim/{name}.v',candidate/f'sim/{name}.v')
shutil.copy2(task/'before/src/modules/control/ir_nec_rx.v',candidate/'reports/remote_album_20261019/before/src/modules/control/ir_nec_rx.v')
source=(task/'pipeline_ir_classification.py').read_text(encoding='utf-8')
source=source[source.index("p=root/'src/modules/control/ir_nec_rx.v'"):]
exec(compile(source,'isolated_ir_pipeline','exec'),{'root':candidate})
modelsim=Path('J:/win64')
work=candidate/'work'
subprocess.run([str(modelsim/'vlib.exe'),str(work)],check=True)
files=[str(p) for sub in ('src/modules/control','sim') for p in (candidate/sub).glob('*.v')]
with (candidate/'compile.log').open('wb') as log:
 subprocess.run([str(modelsim/'vlog.exe'),'-work',str(work),*files],stdout=log,stderr=subprocess.STDOUT,check=True)
for name in ('tb_ir_nec_rx','tb_remote_ir'):
 with (candidate/(name+'_console.log')).open('wb') as log:
  result=subprocess.run([str(modelsim/'vsim.exe'),'-c','-lib','../work',name,'-do','run -all; quit -f','-l',str(candidate/(name+'.log'))],
   cwd=candidate/'sim',stdout=log,stderr=subprocess.STDOUT)
 data=(candidate/(name+'.log')).read_text(encoding='utf-8',errors='replace')
 assert result.returncode==0 and 'ALL PASS' in data and 'FAILED' not in data and '[FAIL]' not in data,name
 print('ISOLATED IR PIPELINE PASS',name,flush=True)
