from pathlib import Path
import json
import runpy
import shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
for name in ['src/modules/osd/menu_overlay.v', 'src/top.v', 'scripts/run_tests.ps1',
             'docs/MENU_SUBMENU_20261023.md', 'docs/MENU_MEDIA_20261023.md',
             'reports/build_manifest.json']:
    target = OUT/'baseline'/name
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        raise RuntimeError(f'Backup already exists: {target}')
    shutil.copy2(ROOT/name, target)
snapshot = runpy.run_path(str(ROOT/'scripts/run_build.py'))['snapshot']()
(OUT/'baseline_sources.json').write_text(json.dumps(snapshot, indent=2))
print('Backup complete')
