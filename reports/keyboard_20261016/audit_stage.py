"""Freeze a completed stage, require exact current inputs and all regression logs."""
from pathlib import Path
import argparse,hashlib,json,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[2];OUT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('stage');parser.add_argument('tests',type=int);args=parser.parse_args()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):
 raw=p.read_bytes()
 return raw.decode('utf-16') if raw.startswith(b'\xff\xfe') else raw.decode('utf-8',errors='replace')
log=read(OUT/(args.stage+'_regression.log'))
tests=sorted(set(re.findall(r'# vsim [^\r\n]* -c (tb_\w+)',log)))
assert len(tests)==args.tests and 'ALL TESTS PASSED' in log,(len(tests),args.tests)
for tb in tests:
 s=read(ROOT/'reports'/(tb+'.log'))
 assert 'ALL PASS' in s and not re.search(r'FAILED|# FAIL |\*\* (Error|Fatal)',s),tb
manifest=json.loads((ROOT/'reports/build_manifest.json').read_text())
assert manifest['status'] in ('completed','timing_failed'),manifest['status']
for p,h in manifest['sources'].items():assert sha(ROOT/p)==h,p
old=subprocess.check_output(['git','show','f504141:src/top.v'],cwd=ROOT).decode('utf-8')
new=(ROOT/'src/top.v').read_text(encoding='utf-8')
for pattern in (r'wire \[69:0\] status_source=.*?;',r'wire .*?=status_video\[.*?;'):
 assert re.findall(pattern,old,re.S if pattern.startswith('wire \\[') else 0)==re.findall(pattern,new,re.S if pattern.startswith('wire \\[') else 0),pattern
dest=OUT/args.stage;dest.mkdir(exist_ok=True)
for name in ('build_manifest.json','timing_status.txt','timing_summary.txt','physical_area.txt','synthesis.log','implementation.log','io.txt'):
 shutil.copy2(ROOT/'reports'/name,dest/name)
record={'tests':tests,'regression_passed':len(tests),'build_status':manifest['status'],
 'timing_ns':manifest.get('timing_ns'),'board_signoff':False,'status70_unchanged':True,
 'sources':manifest['sources'],'reports':{p.name:sha(p) for p in dest.iterdir() if p.is_file()}}
(OUT/(args.stage+'_validation.json')).write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in record.items() if k not in ('tests','sources','reports')},ensure_ascii=False))
