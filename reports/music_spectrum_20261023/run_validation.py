from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
mode=sys.argv[1]
started=datetime.datetime.now(datetime.timezone.utc)
log=OUT/(mode+'_console.log')
commands={
 'main':['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File','scripts/run_tests.ps1'],
 'build':[sys.executable,'scripts/run_build.py'],
 'video':[sys.executable,'scripts/run_video_tests.py']}
with log.open('wb') as handle:
 result=subprocess.run(commands[mode],cwd=ROOT,stdout=handle,stderr=subprocess.STDOUT)
record={'started_utc':started.isoformat(),'exit_code':result.returncode,'console':str(log)}
if mode=='main':
 text=log.read_text(errors='replace')
 # Validate independently as well as checking the actual process exit code.
 names=sorted(set(re.findall(r"['\"](tb_[A-Za-z0-9_]+)['\"]",(ROOT/'scripts/run_tests.ps1').read_text())))
 record['tests']=names;record['count']=len(names)
 record['pass']=result.returncode==0 and 'ALL TESTS PASSED' in text and not re.search(r'FAILED|\*\* Fatal',text)
 for name in names:
  path=ROOT/'reports'/(name+'.log')
  data=path.read_bytes()
  if path.stat().st_mtime<started.timestamp() or re.search(rb'FAILED|\*\* Fatal',data) or b'ALL PASS' not in data:
   raise RuntimeError(f'Invalid/stale regression log {name}')
  target=OUT/'main'/(name+'.log');target.parent.mkdir(exist_ok=True)
  target.write_bytes(data)
 record['source_hashes']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                         for folder in ('src','sim','scripts') for p in (ROOT/folder).rglob('*')
                         if p.is_file() and p.suffix in ('.v','.vh','.mem','.py','.ps1','.txt','.tcl','.sdc','.adc')}
else:
 record['pass']=result.returncode==0
(OUT/(mode+'_validation.json')).write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in record.items() if k not in ('tests','source_hashes')},indent=2),flush=True)
if not record['pass']:
 print('\n'.join(log.read_text(errors='replace').splitlines()[-50:]));raise SystemExit(1)
