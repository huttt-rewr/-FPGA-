"""One documented route strategy trial, invoked only after the prior build exits."""
from pathlib import Path
import json,subprocess,sys
root=Path(__file__).resolve().parents[2]
task=Path(__file__).resolve().parent
current=json.loads((root/'reports/build_manifest.json').read_text())
assert current['status']!='running','Never change inputs while TD is running'
label=sys.argv[1]
seed=int(sys.argv[2])
subprocess.run([sys.executable,str(task/'manage.py'),'archive',label+'_before'],cwd=root,check=True)
syn=(task/'before/scripts/synth.tcl').read_text()
(root/'scripts/synth.tcl').write_text(syn,encoding='utf-8')
impl=(task/'before/scripts/implement.tcl').read_text()
impl=impl.replace('set_param place pr_strategy 1',
                  'set_param place pr_strategy 1\nset_param place seed '+str(seed))
impl=impl.replace('\nroute\n','\n# Documented router effort for congested local connections.\nset_param route effort routability\nroute\n')
(root/'scripts/implement.tcl').write_text(impl,encoding='utf-8')
with (task/(label+'_build.log')).open('wb') as log:
 result=subprocess.run([sys.executable,'scripts/run_build.py'],cwd=root,stdout=log,stderr=subprocess.STDOUT)
state=json.loads((root/'reports/build_manifest.json').read_text())
print(label,result.returncode,state['status'],state.get('timing_ns',state.get('error')))
sys.exit(result.returncode)
