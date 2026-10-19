"""Freeze a WAV timing trial with fresh regression logs and protected-file audit."""
from pathlib import Path
import datetime
import hashlib
import json
import re
import runpy
import shutil
import subprocess
import sys

here=Path(__file__).resolve().parent
root=here.parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
snapshot=runpy.run_path(str(root/'scripts/run_build.py'))['snapshot']

def scope():
    changed=[]
    for name in subprocess.check_output(['git','ls-files','src'],cwd=root).decode().splitlines():
        old=subprocess.check_output(['git','show',f'd34c488:{name}'],cwd=root)
        if old.replace(b'\r\n',b'\n')!=(root/name).read_bytes().replace(b'\r\n',b'\n'):
            changed.append(name)
    assert changed==['src/modules/audio/audio_wav.v'],changed
    for name in ('video_improve.al','scripts/adaptive_clocks.tcl'):
        assert subprocess.check_output(['git','show',f'd34c488:{name}'],cwd=root).replace(b'\r\n',b'\n')==(root/name).read_bytes().replace(b'\r\n',b'\n'),name
    result=dict(base='d34c488',changed_production_rtl=changed,
        official_ip_top_pin_constraints_fat32_bmp_sd_stack_unchanged=True,
        main_clock_100MHz_unchanged=True,status_source_70bit_unchanged=True)
    (here/'scope_wav_ingress.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print('ALL PASS scope: WAV receive boundary only; official IP/top/FAT32/BMP/SD/constraints unchanged')
    return result

if sys.argv[1]=='scope':
    scope()
elif sys.argv[1]=='freeze':
    tag=sys.argv[2]
    manifest=json.loads((root/'reports/build_manifest.json').read_text())
    assert manifest['status'] in ('failed','timing_failed','completed')
    assert manifest['sources']==snapshot(),'Build inputs changed'
    dest=here/tag
    assert not dest.exists(),f'Frozen trial exists: {dest}'
    dest.mkdir()
    names=['build_manifest.json','synthesis.log','implementation.log','gate_area.txt','rtl_area.txt']
    if manifest['status']!='failed':
        names+=['physical_area.txt','timing_status.txt','timing_summary.txt','routed_timing_paths20.txt',
                'prior_opt_timing_status.txt','prior_opt_timing_paths20.txt','io.txt',
                'video_improve_gate.db','video_improve_routed.db','video_improve_prior_opt.db',
                'rebound_placed_timing_status.txt','rebound_placed_timing_paths20.txt']
    if (root/'reports/hold_finalization.log').exists():
        names+=['hold_finalization.log','video_improve_hold_input.db']
    for name in names:
        shutil.copy2(root/'reports'/name,dest/name)
    for name in ('src/modules/audio/audio_wav.v','scripts/implement.tcl','scripts/finalize_hold.tcl','scripts/run_build.py','scripts/adaptive_mode_clocks.sdc','scripts/run_tests.ps1','sim/tb_audio_rx_boundary.v'):
        shutil.copy2(root/name,dest/Path(name).name)
    ps=(root/'scripts/run_tests.ps1').read_text(encoding='utf-8-sig')
    tests=[]
    for line in ps.splitlines():
        if '$mergeTests' in line and '@(' in line:
            tests+=re.findall(r"'(tb_\w+)'",line)
    assert len(tests)==len(set(tests))
    assert len(tests)==98,len(tests)
    earliest=(root/'reports/tb_uart_rx.log').stat().st_mtime
    # Every log must belong to the same fresh serial regression, not an old PASS.
    assert earliest>(here/'before_wav_ingress/audio_wav.v').stat().st_mtime
    logs=dest/'test_logs';logs.mkdir()
    for tb in tests:
        p=root/'reports'/f'{tb}.log'
        text=p.read_text(errors='replace')
        assert p.stat().st_mtime>=earliest,tb+' stale'
        assert 'ALL PASS' in text and not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)',text),tb
        shutil.copy2(p,logs/p.name)
    paths=[]
    if manifest['status']!='failed':
        text=(dest/'routed_timing_paths20.txt').read_text()
        for slack,start,end,kind in re.findall(r'Slack\s*:\s*(-?[\d.]+)ns\s+Begin Point\s*:\s*([^\n]+)\s+End Point\s*:\s*([^\n]+)\s+Check Type\s*:\s*(\w+)',text):
            paths.append(dict(slack_ns=float(slack),check=kind,start=start.split(' (')[0].strip(),end=end.split(' (')[0].strip()))
    worst={}
    for p in paths:
        if p['check'] not in worst or p['slack_ns']<worst[p['check']]['slack_ns']:worst[p['check']]=p
    result=dict(status=manifest['status'],timing_ns=manifest.get('timing_ns'),error=manifest.get('error'),
        worst_by_check=worst,negative_reported_paths=[p for p in paths if p['slack_ns']<0],
        regression_count=len(tests),tests_all_pass=True,tests=tests,scope=scope(),
        regression_evidence='Fresh per-test ModelSim logs; runner exit confirmed separately by exec session',
        captured_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        resources={n:{k:int(v) for k,v in re.findall(r'^#(lut|reg|bram|dsp)\s+(\d+)',(dest/n).read_text(),re.M)} for n in ('gate_area.txt','physical_area.txt') if (dest/n).exists()},
        critical_warnings=list(dict.fromkeys(s for log in ('implementation.log','hold_finalization.log')
            if (dest/log).exists() for s in (dest/log).read_text(errors='replace').splitlines() if 'CRITICAL-WARNING' in s)))
    result['files_sha256']={p.relative_to(dest).as_posix():sha(p) for p in dest.rglob('*') if p.is_file()}
    (dest/'paths.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ('tests','files_sha256')},indent=2))
