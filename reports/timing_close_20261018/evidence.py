"""Freeze each trial and bind only legal fresh STA to exact build inputs."""
from pathlib import Path
import hashlib
import json
import re
import runpy
import shutil
import subprocess
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def snapshot():
    return runpy.run_path(str(ROOT/'scripts/run_build.py'))['snapshot']()

def freeze(tag,regression=None):
    dest=HERE/tag;dest.mkdir(exist_ok=True)
    manifest=json.loads((ROOT/'reports/build_manifest.json').read_text())
    assert manifest['status'] in ('completed','timing_failed','failed'),manifest['status']
    assert manifest['sources']==snapshot(),'Build inputs changed since trial'
    legal=manifest['status']!='failed'
    names=['build_manifest.json','synthesis.log','implementation.log','gate_area.txt','rtl_area.txt']
    if legal:names+=['physical_area.txt','timing_status.txt','timing_summary.txt','routed_timing_paths20.txt',
        'prior_opt_timing_status.txt','prior_opt_timing_paths20.txt','io.txt',
        'video_improve_gate.db','video_improve_routed.db','video_improve_prior_opt.db',
        'rebound_placed_timing_status.txt','rebound_placed_timing_paths20.txt']
    for name in names:
        p=ROOT/'reports'/name
        if p.exists():shutil.copy2(p,dest/name)
    for name in ('fps_control.v','sd_fat32.v','bmp_scale_loader.v','sd_card_bmp.v'):
        p=next((ROOT/'src').rglob(name));shutil.copy2(p,dest/name)
    paths=[]
    if legal:
        text=(dest/'routed_timing_paths20.txt').read_text(errors='replace')
        for slack,start,end,kind in re.findall(r'Slack\s*:\s*(-?[\d.]+)ns\s+Begin Point\s*:\s*([^\n]+)\s+End Point\s*:\s*([^\n]+)\s+Check Type\s*:\s*(\w+)',text):
            paths.append(dict(slack_ns=float(slack),check=kind,start=start.split(' (')[0].strip(),end=end.split(' (')[0].strip()))
    worst={}
    for p in paths:
        if p['check'] not in worst or p['slack_ns']<worst[p['check']]['slack_ns']:worst[p['check']]=p
    result=dict(status=manifest['status'],timing_ns=manifest.get('timing_ns'),error=manifest.get('error'),
        resources={name:{k:int(v) for k,v in re.findall(r'^#(lut|reg|bram|dsp)\s+(\d+)',
            (dest/name).read_text(),re.M)} for name in ['gate_area.txt']+(['physical_area.txt'] if legal else [])},
        worst_by_check=worst,negative_reported_paths=[p for p in paths if p['slack_ns']<0],
        critical_warnings=[s for s in (dest/'implementation.log').read_text(errors='replace').splitlines() if 'CRITICAL-WARNING' in s],
        coredump='coredump' in (dest/'implementation.log').read_text(errors='replace').lower())
    if regression:
        raw=(HERE/regression).read_bytes()
        console=raw.decode('utf-16') if raw.startswith(b'\xff\xfe') else raw.decode('utf-8-sig')
        assert 'ALL TESTS PASSED' in console
        assert not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)',console)
        tests=re.findall(r'-l ../reports/(tb_\w+)\.log',console)
        assert len(tests)==len(set(tests))
        logs=dest/'test_logs';logs.mkdir(exist_ok=True)
        for tb in tests:
            p=ROOT/'reports'/f'{tb}.log';text=p.read_text(errors='replace')
            assert 'ALL PASS' in text and not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)',text),tb
            shutil.copy2(p,logs/p.name)
        shutil.copy2(HERE/regression,dest/'regression.log')
        result.update(tests_all_pass=True,regression_count=len(tests),tests=tests)
    result['files_sha256']={p.relative_to(dest).as_posix():sha(p) for p in dest.rglob('*') if p.is_file() and p.name!='paths.json'}
    (dest/'paths.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ('files_sha256','tests')},indent=2))

if sys.argv[1]=='freeze':freeze(*sys.argv[2:])
elif sys.argv[1]=='scope':
    # The selected next trial adds a WAV receive register, while preserving
    # FAT32/BMP/SD/top/IP. Use its explicit protected-file audit.
    subprocess.run([sys.executable,str(HERE/'audit_wav_ingress.py'),'scope'],cwd=ROOT,check=True)
