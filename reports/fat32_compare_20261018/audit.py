"""Freeze current build evidence and verify the one-line RTL scope."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE = 'a5d76ca'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

if len(sys.argv) > 1 and sys.argv[1] == 'freeze':
    dest = HERE / sys.argv[2]
    dest.mkdir(exist_ok=True)
    names = ['build_manifest.json', 'synthesis.log', 'implementation.log',
             'gate_area.txt', 'physical_area.txt', 'timing_status.txt', 'timing_summary.txt',
             'routed_timing_paths20.txt', 'prior_opt_timing_status.txt',
             'prior_opt_timing_paths20.txt', 'io.txt', 'video_improve_gate.db',
             'video_improve_routed.db', 'video_improve_prior_opt.db']
    manifest = json.loads((ROOT/'reports/build_manifest.json').read_text())
    if manifest['status']=='failed':
        for name in ['build_manifest.json','synthesis.log','implementation.log','gate_area.txt']:
            source=ROOT/'reports'/name
            if source.exists():shutil.copy2(source,dest/name)
        result=dict(status='no_fresh_routed_report',error=manifest.get('error'),
            resources={'gate_area.txt':{k:int(v) for k,v in re.findall(r'^#(lut|reg|bram|dsp)\s+(\d+)',
                (dest/'gate_area.txt').read_text(),re.M)}},
            warning='Failed implementation has no final routed STA. Never reuse earlier timing.',
            files_sha256={p.name:sha(p) for p in dest.iterdir() if p.is_file()})
        (dest/'paths.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
        print(json.dumps(result,indent=2))
        sys.exit(0)
    if manifest['status'] not in ('completed', 'timing_failed'):
        raise RuntimeError('No completed fresh routed build to freeze')
    for name in names:
        shutil.copy2(ROOT/'reports'/name, dest/name)
    paths = []
    text = (dest/'routed_timing_paths20.txt').read_text(errors='replace')
    for slack, start, end, kind in re.findall(
        r'Slack\s*:\s*(-?[\d.]+)ns\s+Begin Point\s*:\s*([^\n]+)\s+End Point\s*:\s*([^\n]+)\s+Check Type\s*:\s*(\w+)', text):
        paths.append(dict(slack_ns=float(slack), check=kind,
                          start=start.split(' (')[0].strip(), end=end.split(' (')[0].strip()))
    worst = {}
    for p in paths:
        if p['check'] not in worst or p['slack_ns'] < worst[p['check']]['slack_ns']:
            worst[p['check']] = p
    result = dict(status=manifest['status'], timing_ns=manifest['timing_ns'],
        confidence=re.search(r'Confidence\s*:\s*(\w+)',text).group(1),
        worst_by_check=worst, negative_reported_paths=[p for p in paths if p['slack_ns']<0],
        resources={name:{k:int(v) for k,v in re.findall(r'^#(lut|reg|bram|dsp)\s+(\d+)',
            (dest/name).read_text(), re.M)} for name in ('gate_area.txt','physical_area.txt')},
        critical_warnings=[l for l in (dest/'implementation.log').read_text(errors='replace').splitlines()
                           if 'CRITICAL-WARNING' in l],
        files_sha256={p.name:sha(p) for p in dest.iterdir() if p.is_file()})
    (dest/'paths.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='files_sha256'},indent=2))
else:
    rtl = 'src/modules/sd/sd_fat32.v'
    before = git('show',f'{BASE}:{rtl}').decode('utf-8').replace('\r\n','\n')
    after = (ROOT/rtl).read_text(encoding='utf-8')
    expected = before.replace("{1'b0,request_rel}>=request_sectors",
        '(|request_rel[31:24]) || (request_rel[23:0]>=request_sectors[23:0])')
    expected2 = expected.replace(' || target_index>=data_clusters ||',
        ' ||\n        (!(|data_clusters[31:24]) && target_index>=data_clusters[23:0]) ||')
    expected3 = expected2.replace('cluster_ok<=next_cluster>=2 && next_cluster<=max_cluster && next_cluster<32\'h0ffffff0;',
        'cluster_ok<=next_cluster>=2 &&\n'
        '      (next_cluster[31:16]<max_cluster[31:16] ||\n'
        '       (next_cluster[31:16]==max_cluster[31:16] && next_cluster[15:0]<=max_cluster[15:0])) &&\n'
        '      next_cluster<32\'h0ffffff0;')
    assert after in (before, expected, expected2, expected3), 'Unexpected FAT32 RTL changes'
    tracked_src = git('ls-files','src').decode().splitlines()
    unchanged = []
    for name in tracked_src:
        if name == rtl:
            continue
        assert git('show',f'{BASE}:{name}').replace(b'\r\n',b'\n') == (ROOT/name).read_bytes().replace(b'\r\n',b'\n'),name
        unchanged.append(name)
    for name in ['video_improve.al','scripts/implement.tcl','scripts/adaptive_clocks.tcl']:
        assert git('show',f'{BASE}:{name}').replace(b'\r\n',b'\n') == (ROOT/name).read_bytes().replace(b'\r\n',b'\n'),name
    # TD emits whitespace in its verbatim generated logs; do not rewrite evidence.
    subprocess.run(['git','diff','--check','--','src','scripts','sim','docs','README.md'],cwd=ROOT,check=True)
    result=dict(base=BASE, rtl_expression_count=0 if after==before else 1 if after==expected else 2 if after==expected2 else 3,
        other_tracked_source_files_unchanged=unchanged,
        top_70bit_status_and_indices_unchanged=True, official_ip_unchanged=True,
        constraints_and_clocks_unchanged=True,
        source_sha256={n:sha(ROOT/n) for n in [rtl,'src/top.v','sim/tb_fat32_compare.v','scripts/run_tests.ps1']})
    (HERE/'scope.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print('ALL PASS scope: planned FAT32 expressions; other RTL, IP, constraints and clocks unchanged')
