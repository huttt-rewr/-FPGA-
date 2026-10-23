"""Retry physical placement only, preserving RTL, clocks and failed evidence."""
from pathlib import Path
import datetime
import hashlib
import json
import re
import runpy
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
REPORTS = ROOT/'reports'
OUT = Path(__file__).resolve().parent/'physical_refinement'
OUT.mkdir(exist_ok=True)
snapshot = runpy.run_path(str(ROOT/'scripts/run_build.py'))['snapshot']
manifest = REPORTS/'build_manifest.json'
build = json.loads(manifest.read_text())
assert build['status']=='timing_failed' and snapshot()==build['sources']

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

initial = OUT/'seed25_failed'
assert not initial.exists(), 'Preserve existing refinement evidence'
initial.mkdir()
for name in ('build_manifest.json','physical_area.txt','timing_status.txt',
             'timing_summary.txt','routed_timing_paths20.txt','implementation.log',
             'hold_finalization.log'):
    shutil.copy2(REPORTS/name, initial/name)

history = []
for seed in (26,27,28):
    trial = OUT/f'seed{seed}'
    trial.mkdir()
    implement = (ROOT/'scripts/implement.tcl').read_text()
    implement = implement.replace('set root [file normalize [file join [file dirname [info script]] ..]]',
                                  'set root {'+ROOT.as_posix()+'}')
    implement = implement.replace('set_param place seed 25',f'set_param place seed {seed}')
    implement = implement.replace('reports/',trial.as_posix()+'/')
    implement = implement.replace(trial.as_posix()+'/video_improve_gate.db',
                                  (REPORTS/'video_improve_gate.db').as_posix())
    finalize = (ROOT/'scripts/finalize_hold.tcl').read_text()
    finalize = finalize.replace('set root [file normalize [file join [file dirname [info script]] ..]]',
                                'set root {'+ROOT.as_posix()+'}')
    finalize = finalize.replace('reports/',trial.as_posix()+'/')
    warnings = {}
    for name,source,marker in (
        ('implementation',implement,'IMPLEMENTATION_COMPLETED'),
        ('hold_finalization',finalize,'HOLD_FINALIZATION_COMPLETED')):
        script = trial/(name+'.tcl')
        script.write_text(source,encoding='utf-8')
        print(f'Physical seed {seed}: {name}; RTL and constraints unchanged',flush=True)
        with (trial/(name+'.log')).open('wb') as log:
            result = subprocess.run([build['td'],script.as_posix()],cwd=ROOT,
                                    stdout=log,stderr=subprocess.STDOUT,timeout=1800)
        text = (trial/(name+'.log')).read_text(errors='replace')
        errors = re.findall(r'^.*(?:\bERROR\s*:|\bFATAL\b|Oops!\s*coredump|invalid command name|couldn.t read file).*$',text,re.M|re.I)
        assert result.returncode==0 and marker in text and not errors,(seed,name,errors[:3])
        warnings[name] = re.findall(r'^.*\b(?:CRITICAL-WARNING|WARNING)\s*:.*$',text,re.M)
    assert snapshot()==build['sources'], 'Build inputs changed'
    metrics = {key:float(value) for key,value in re.findall(
        r'(SWNS|STNS|HWNS|HTNS):\s*(-?\d+\.\d+)ns',
        (trial/'timing_status.txt').read_text())}
    assert len(metrics)==4
    for name in ('rebound_placed_timing_paths20.txt','routed_timing_paths20.txt'):
        clocks = (trial/name).read_text().split('Clock Summary',1)[1].split('Notes',1)[0]
        assert all(re.search(r'\b'+n+r'\b',clocks) for n in
                   ('vga_pixel','svga_pixel','vga_serial','svga_serial'))
    area = (trial/'physical_area.txt').read_text()
    resources = {k:int(re.search(r'^#'+k+r'\s+(\d+)',area,re.M).group(1))
                 for k in ('lut','bram','dsp')}
    assert resources['lut']<=18620 and resources['bram']<=64 and resources['dsp']<=29
    history.append({'seed':seed,'timing_ns':metrics,'resources':resources})
    (OUT/'attempts.json').write_text(json.dumps(history,indent=2)+'\n')
    print(json.dumps(history[-1]),flush=True)
    if any(v<0 for v in metrics.values()):
        continue
    for path in trial.iterdir():
        if path.suffix in ('.db','.txt','.log'):
            shutil.copy2(path,REPORTS/path.name)
    build.update(status='completed',timing_ns=metrics,finished_utc=now(),
                 implementation_warnings=warnings['implementation'],
                 hold_finalization_warnings=warnings['hold_finalization'],
                 board_signoff=False,hold_margin_0_5ns_met=metrics['HWNS']>=0.5,
                 physical_refinement={'original_status':'timing_failed',
                     'original_timing_ns':{'SWNS':-0.016,'STNS':-0.016,'HWNS':0.013,'HTNS':0.0},
                     'original_manifest_sha256':sha(initial/'build_manifest.json'),
                     'selected_seed':seed,'attempts':history,
                     'evidence_directory':str(OUT),
                     'rtl_and_constraints_unchanged':True})
    build['products'] = {p.name:sha(p) for p in REPORTS.iterdir() if p.suffix in ('.db','.txt')}
    manifest.write_text(json.dumps(build,indent=2)+'\n',encoding='utf-8')
    print('PHYSICAL_REFINEMENT_COMPLETED',flush=True)
    break
else:
    raise RuntimeError('No physically timed candidate; all failed evidence preserved')
