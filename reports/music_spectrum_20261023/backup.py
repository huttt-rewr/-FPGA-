from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
paths = [p for folder in ('src', 'scripts', 'docs') for p in (ROOT/folder).rglob('*')
         if p.is_file() and p.suffix.lower() in ('.v','.vh','.mem','.py','.ps1','.txt','.tcl','.sdc','.adc','.md','.al')]
paths += [ROOT/'README.md', ROOT/'video_improve.al']
hashes = {}
for path in paths:
    relative = path.relative_to(ROOT).as_posix()
    hashes[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    target = OUT/'baseline'/relative
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        shutil.copy2(path, target)
for name in ('build_manifest.json','physical_area.txt','rtl_area.txt','timing_summary.txt'):
    target = OUT/'baseline'/'reports'/name
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        shutil.copy2(ROOT/'reports'/name, target)
(OUT/'baseline_sources.json').write_text(json.dumps(hashes, indent=2), encoding='utf-8')
(OUT/'baseline_status.txt').write_bytes(subprocess.check_output(['git','status','--porcelain'], cwd=ROOT))
print('Backed up', len(hashes), 'source/script/document files; existing work preserved.')
