from pathlib import Path
import hashlib,json,re,sys
ROOT=Path(__file__).resolve().parents[2]
TASK=Path(__file__).resolve().parent
phase=sys.argv[1]
build=json.loads((ROOT/'reports/build_manifest.json').read_text())
assert build['status']=='completed',build.get('error',build['status'])
for rel,digest in build['sources'].items():
    assert hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()==digest,('stale input',rel)
metrics=build['timing_ns'];assert all(v>=0 for v in metrics.values()),metrics
old=(TASK/'before/src/top.v').read_text(encoding='utf-8-sig')
new=(ROOT/'src/top.v').read_text(encoding='utf-8-sig')
extract=lambda s:re.search(r'wire \[69:0\] status_source=.*?;',s,re.S).group()
assert extract(old)==extract(new),'status70 layout changed'
baseline=json.loads((TASK/'baseline.json').read_text())
protected=[]
for rel,digest in baseline['files'].items():
    if rel.startswith(('src/modules/sd/','src/modules/bmp/','src/modules/audio/',
                       'src/modules/memory/','src/modules/hdmi/','src/ip/','src/constraints/')):
        assert hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()==digest,('protected input',rel)
        protected.append(rel)
def critical(folder):
    return {line.strip() for name in ('synthesis.log','implementation.log','hold_finalization.log')
            for line in (folder/name).read_text(encoding='utf-8',errors='replace').splitlines()
            if 'CRITICAL-WARNING:' in line}
added=critical(ROOT/'reports')-critical(TASK/'before/reports')
assert not added,sorted(added)
runner=(ROOT/'scripts/run_tests.ps1').read_text()
tests=sorted(set(re.findall(r"'(tb_\w+)'",runner)))
for tb in tests:
    s=(ROOT/'reports'/(tb+'.log')).read_text(encoding='utf-8',errors='replace')
    assert 'ALL PASS' in s and not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)',s),tb
console=TASK/(phase+'_regression.log')
data=console.read_bytes();text=data.decode('utf-16' if data[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8',errors='replace')
assert 'ALL TESTS PASSED' in text
for name in ('synthesis.log','implementation.log','hold_finalization.log'):
    s=(ROOT/'reports'/name).read_text(errors='replace')
    assert not re.search(r'\bERROR\s*:|\bFATAL\b|Oops!\s*coredump',s,re.I),name
record={'phase':phase,'baseline_head':baseline['head'],'tests':len(tests),'timing_ns':metrics,
        'protected_files_identical':protected,'status70_identical':True,
        'new_critical_warnings':[],'board_verified':False,'new_bitstream':False}
(TASK/(phase+'_validation.json')).write_text(json.dumps(record,indent=2),encoding='utf-8')
print('ALL PASS',phase,len(tests),'regressions, timing',metrics,'status70/protected files identical')
