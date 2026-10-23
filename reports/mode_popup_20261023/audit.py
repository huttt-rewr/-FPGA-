from pathlib import Path
import difflib
import json
import re
import runpy

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
before = json.loads((OUT/'baseline_sources.json').read_text())
after = runpy.run_path(str(ROOT/'scripts/run_build.py'))['snapshot']()
changed = sorted(p for p in before if before[p] != after.get(p))
added = sorted(set(after)-set(before))
assert changed == ['scripts/run_tests.ps1', 'src/modules/osd/menu_overlay.v', 'src/top.v'], changed
assert added == ['sim/tb_menu_mode_popup.v'], added
old = (OUT/'baseline/src/top.v').read_text(encoding='utf-8-sig')
new = (ROOT/'src/top.v').read_text(encoding='utf-8-sig')
pattern = r'wire \[69:0\] status_source=\{.*?;'
assert re.search(pattern, old, re.S).group() == re.search(pattern, new, re.S).group()
diffs = []
for name in changed + ['docs/MENU_SUBMENU_20261023.md', 'docs/MENU_MEDIA_20261023.md']:
    old_path = OUT/'baseline'/name
    diffs.extend(difflib.unified_diff(old_path.read_text(encoding='utf-8-sig').splitlines(True),
                                    (ROOT/name).read_text(encoding='utf-8-sig').splitlines(True),
                                    fromfile='before/'+name, tofile='after/'+name))
(OUT/'changes.diff').write_text(''.join(diffs), encoding='utf-8')
record = dict(status='ALL PASS', changed=changed, added=added,
              status_source_70_bits_unchanged=True,
              media_data_paths_ip_pins_constraints_fonts_unchanged=True)
(OUT/'scope_audit.json').write_text(json.dumps(record, indent=2))
print(json.dumps(record, indent=2))
