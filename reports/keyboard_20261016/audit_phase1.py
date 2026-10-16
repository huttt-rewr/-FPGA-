"""Bind phase-one evidence to source hashes and audit protected status layout."""
from pathlib import Path
import hashlib,json,re,subprocess,shutil,argparse
ROOT=Path(__file__).resolve().parents[2]
out=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--profile',default='phase1_onehot')
args=parser.parse_args()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
old=subprocess.check_output(['git','show','HEAD:src/top.v'],cwd=ROOT).decode('utf-8')
new=(ROOT/'src/top.v').read_text(encoding='utf-8')
pattern=r'wire \[69:0\] status_source=.*?;'
assert re.search(pattern,old,re.S).group()==re.search(pattern,new,re.S).group(),'70-bit layout changed'
selects=r'wire .*?=status_video\[.*?;'
assert re.findall(selects,old)==re.findall(selects,new),'status selectors changed'
protected=['src/modules/sd/sd_fat32.v','src/modules/sd/sd_read_arbiter.v',
 'src/modules/bmp/sd_card_bmp.v','src/modules/bmp/bmp_read.v','src/modules/video/bmp_scale_loader.v']
for p in protected:
 assert subprocess.check_output(['git','show','HEAD:'+p],cwd=ROOT).decode('utf-8').replace('\r\n','\n')==(ROOT/p).read_text(encoding='utf-8'),p
raw=(out/(args.profile+'_regression.log')).read_bytes()
log=raw.decode('utf-16') if raw.startswith(b'\xff\xfe') else raw.decode('utf-8',errors='replace')
passed=re.findall(r'# vsim [^\r\n]* -c (tb_\w+)',log)
assert 'ALL TESTS PASSED' in log and len(set(passed))==67,len(set(passed))
for tb in passed:
 test_log=(ROOT/'reports'/(tb+'.log')).read_text(errors='replace')
 assert 'ALL PASS' in test_log and not re.search(r'FAILED|# FAIL |\*\* (Error|Fatal)',test_log),tb
manifest=json.loads((ROOT/'reports/build_manifest.json').read_text())
assert manifest['status'] in ('completed','timing_failed'),manifest['status']
for p,h in manifest['sources'].items():assert sha(ROOT/p)==h,p
dest=out/args.profile;dest.mkdir(exist_ok=True)
for name in ('build_manifest.json','timing_status.txt','timing_summary.txt','physical_area.txt','synthesis.log','implementation.log','io.txt'):
 shutil.copy2(ROOT/'reports'/name,dest/name)
for p in ('src/top.v','src/modules/audio/audio_wav.v'):
 shutil.copy2(ROOT/p,dest/Path(p).name)
record={'regression_passed':len(set(passed)),'tests':sorted(set(passed)),
 'layout_70bit_unchanged':True,'protected_sources_unchanged':protected,
 'build_status':manifest['status'],'timing_ns':manifest.get('timing_ns'),
 'board_signoff':False,'files':{p.relative_to(ROOT).as_posix():sha(p) for p in dest.iterdir() if p.is_file()}}
(out/'validation_phase1.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in record.items() if k not in ('files','tests')},ensure_ascii=False,indent=2))
