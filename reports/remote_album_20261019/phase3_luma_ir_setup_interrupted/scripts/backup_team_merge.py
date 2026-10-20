"""Create and verify a non-overwriting backup before the 2026-10-08 merge."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
import json

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'backups/before_team_merge_20261008'

if OUT.exists():
    raise SystemExit('Backup already exists; refusing to overwrite')
paths = [p for p in ROOT.rglob('*') if p.is_file()
         and not any(x in p.relative_to(ROOT).parts for x in
                     ('.git', 'backups', 'msim_work', 'pll_work', '__pycache__'))
         and p.suffix.lower() in ('.v', '.sv', '.vhd', '.al', '.adc', '.sdc', '.ipc',
                                  '.tcl', '.py', '.ps1', '.md', '.json', '.txt', '.log', '.qor')]
OUT.mkdir(parents=True)
manifest = {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in paths}
with ZipFile(OUT/'workspace.zip', 'x', ZIP_DEFLATED) as archive:
    for p in paths:
        archive.write(p, p.relative_to(ROOT).as_posix())
with ZipFile(OUT/'workspace.zip') as archive:
    assert all(hashlib.sha256(archive.read(n)).hexdigest() == h for n, h in manifest.items())
(OUT/'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(f'BACKUP VERIFIED: {len(manifest)} files; {OUT}')
