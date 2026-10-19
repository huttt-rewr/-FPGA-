"""Preserve the exact working state before the VGA/EDID replacement."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent / 'before'
out.mkdir(parents=True, exist_ok=True)
paths = [p for base in ('src', 'scripts', 'sim') for p in (root / base).rglob('*')
         if p.is_file() and p.suffix in ('.v', '.vhd', '.adc', '.sdc', '.al', '.tcl', '.ps1', '.py', '.txt')
         and not any(x.endswith('_work') for x in p.parts)]
paths += [root / p for p in ('video_improve.al', 'README.md', 'docs/USER_GUIDE.md',
          'docs/BUILD_STATUS.md', 'docs/SOURCE_MAP.md', 'docs/KEY_SW_OPERATION.md',
          'docs/KEYBOARD_USAGE_20261016.md', 'docs/CONNECTION_AND_USAGE.md')]
manifest = {}
for p in paths:
    if not p.exists():
        continue
    rel = p.relative_to(root).as_posix()
    manifest[rel] = hashlib.sha256(p.read_bytes()).hexdigest()
    dest = out / rel
    if dest.exists():
        assert dest.read_bytes() == p.read_bytes(), f'Backup already differs: {rel}'
    else:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, dest)
(out.parent / 'baseline.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
(out.parent / 'baseline_head.txt').write_text(subprocess.check_output(
    ['git', 'rev-parse', 'HEAD'], cwd=root, text=True), encoding='utf-8')
for name in ('build_manifest.json', 'timing_status.txt', 'physical_area.txt', 'gate_area.txt',
             'timing_summary.txt', 'routed_timing_paths20.txt'):
    p = root / 'reports' / name
    if p.exists():
        shutil.copy2(p, out / name)
print(f'Backed up {len(manifest)} files; existing README edits preserved')
