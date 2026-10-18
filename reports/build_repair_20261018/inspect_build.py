"""Freeze exact TD products and classify check types without reinterpreting WNS."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import sys

root = Path(__file__).resolve().parents[2]
dest = Path(__file__).resolve().parent / sys.argv[1]
dest.mkdir(exist_ok=True)
names = ['build_manifest.json', 'synthesis.log', 'implementation.log',
         'gate_area.txt', 'physical_area.txt', 'timing_status.txt',
         'timing_summary.txt', 'routed_timing_paths20.txt',
         'prior_opt_timing_status.txt', 'prior_opt_timing_paths20.txt', 'io.txt',
         'video_improve_gate.db', 'video_improve_routed.db', 'video_improve_prior_opt.db']
for name in names:
    p = root / 'reports' / name
    if p.exists():
        shutil.copy2(p, dest / name)
manifest = json.loads((dest/'build_manifest.json').read_text())
if manifest['status']=='failed' or not (dest / 'routed_timing_paths20.txt').exists():
    for name in ['routed_timing_paths20.txt','prior_opt_timing_status.txt','prior_opt_timing_paths20.txt', 'video_improve_prior_opt.db']:
        p=dest/name
        if p.exists():
            p.rename(dest/('untrusted_preexisting_'+name))
    result = {'status': 'no_fresh_routed_report',
              'manifest': manifest,
              'warning': 'No routed STA exists for this build; do not reuse another build timing.'}
    (dest/'paths.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(result['warning'])
    sys.exit(0)
text = (dest / 'routed_timing_paths20.txt').read_text(errors='replace')
paths = []
for slack, start, end, kind in re.findall(
        r'Slack\s*:\s*(-?[\d.]+)ns\s+Begin Point\s*:\s*([^\n]+)\s+End Point\s*:\s*([^\n]+)\s+Check Type\s*:\s*(\w+)', text):
    entry = {'slack_ns': float(slack), 'check': kind,
             'start': start.split(' (')[0].strip(), 'end': end.split(' (')[0].strip()}
    paths.append(entry)
worst = {}
for p in paths:
    if p['check'] not in worst or p['slack_ns'] < worst[p['check']]['slack_ns']:
        worst[p['check']] = p
resources = {}
for name in ['gate_area.txt', 'physical_area.txt']:
    resources[name] = {k: int(v) for k,v in re.findall(r'^#(lut|reg|bram|dsp)\s+(\d+)',
                         (dest / name).read_text(), re.M)}
result = dict(confidence=re.search(r'Confidence\s*:\s*(\w+)', text).group(1),
              worst_by_check=worst, negative_reported_paths=[p for p in paths if p['slack_ns']<0],
              resources=resources,
              row_address_paths=[p for p in paths if 'byte_address' in p['end']],
              warnings=[line for line in (dest/'implementation.log').read_text(errors='replace').splitlines()
                        if any(k in line for k in ['PHY-7002','PHY-5079','coredump','PHY-8023'])],
              files_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in dest.iterdir() if p.is_file()})
(dest / 'paths.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ['files_sha256', 'negative_reported_paths']}, indent=2))
