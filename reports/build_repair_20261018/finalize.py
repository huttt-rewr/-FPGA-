"""Bind delivery notes to the selected fresh build and complete regression."""
from pathlib import Path
import hashlib
import importlib.util
import json
import re
import shutil
import subprocess
import sys

root=Path(__file__).resolve().parents[2]
folder=Path(__file__).resolve().parent
tag,regression=sys.argv[1:3]
selected=folder/tag
manifest=json.loads((selected/'build_manifest.json').read_text())
spec=importlib.util.spec_from_file_location('build',root/'scripts/run_build.py')
build=importlib.util.module_from_spec(spec);spec.loader.exec_module(build)
assert manifest['sources']==build.snapshot(),'Current inputs differ from selected build'
def read(path):
    b=path.read_bytes()
    return b.decode('utf-16') if b[:2] in (b'\xff\xfe',b'\xfe\xff') else b.decode('utf-8',errors='replace')
log=folder/regression
text=read(log)
tests=re.findall(r'# vsim .*? -c (tb_\w+)',text)
assert len(tests)==93 and len(set(tests))==93 and 'ALL TESTS PASSED' in text
assert not re.search(r'FAILED|\*\* (Error|Fatal)',text)
test_dir=folder/'final_test_logs'
test_dir.mkdir(exist_ok=True)
for name in tests:
    p=root/'reports'/f'{name}.log'
    t=read(p)
    assert 'ALL PASS' in t and not re.search(r'FAILED|\*\* (Error|Fatal)',t),name
    shutil.copy2(p,test_dir/p.name)
subprocess.run([sys.executable,str(folder/'audit_scope.py')],cwd=root,check=True)
static=subprocess.check_output([sys.executable,'scripts/static_check.py'],cwd=root).decode().strip()
paths=json.loads((selected/'paths.json').read_text())
metrics=manifest.get('timing_ns',{})
resources=paths.get('resources',{})
scope=json.loads((folder/'scope.json').read_text())
result={'baseline':(folder/'baseline.txt').read_text().strip(),'selected_build':tag,
 'build_status':manifest['status'],'timing_ns':metrics,'resources':resources,
 'worst_by_check':paths.get('worst_by_check',{}),'static':static,
 'regression':regression,'simulation_count':len(tests),'simulation_all_pass':True,
 'regression_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),
 'scope':scope,'board_tested':False,'new_bit_generated':False,'bit_release_allowed':False,
 'sources':manifest['sources'],
 'products_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in selected.iterdir() if p.is_file()}}
(folder/'validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ['sources','products_sha256','scope']},indent=2))
