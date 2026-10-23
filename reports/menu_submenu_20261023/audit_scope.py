"""Audit the menu changes against the frozen starting build, without rebuilding."""
from pathlib import Path
import json
import re
import runpy

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
before = json.loads((OUT/'baseline/reports/build_manifest.json').read_text(encoding='utf-8'))['sources']
after = runpy.run_path(str(ROOT/'scripts/run_build.py'))['snapshot']()
changed = sorted(p for p in before if after.get(p) != before[p])
added = sorted(p for p in after if p not in before)
expected = sorted(['scripts/run_tests.ps1', 'sim/tb_chinese_menu.v',
                   'sim/tb_menu_overlay.v', 'src/modules/control/picture_controls.v',
                   'src/modules/osd/menu_overlay.v', 'src/top.v'])
assert changed == expected, changed
assert added == ['sim/tb_menu_popup.v'], added
old_top = (OUT/'baseline/src/top.v').read_text(encoding='utf-8')
new_top = (ROOT/'src/top.v').read_text(encoding='utf-8')
def status(top):
    return re.search(r'wire \[69:0\] status_source=\{.*?;', top, re.S).group(0)
assert status(old_top) == status(new_top)
assert new_top.replace(' .mode_800(mode_video),\n', '', 1) == old_top, 'Unexpected top-level wiring changes'
result = {'status':'ALL PASS', 'changed':changed, 'added':added,
          'status_source_70_bits_unchanged':True,
          'top_only_change':'menu_overlay.mode_800(mode_video)',
          'unchanged_files':len(set(before) & set(after))-len(changed),
          'baseline':'baseline/reports/build_manifest.json'}
(OUT/'scope_audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
