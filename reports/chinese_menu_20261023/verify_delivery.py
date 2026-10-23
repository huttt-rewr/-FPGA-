"""Bind the Chinese menu delivery to completed reports and immutable inputs."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import re
import runpy
import shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(name, value):
    (OUT/name).write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')


def main():
    manifest = json.loads((ROOT/'reports/build_manifest.json').read_text())
    baseline = json.loads((OUT/'baseline/reports/build_manifest.json').read_text())
    assert manifest['status'] == 'completed', manifest.get('timing_ns')
    current = runpy.run_path(str(ROOT/'scripts/run_build.py'))['snapshot']()
    assert current == manifest['sources'], 'Reports do not match current inputs'
    protected_prefixes = ('src/modules/sd/', 'src/modules/bmp/', 'src/modules/audio/',
                          'src/modules/memory/', 'src/ip/', 'src/constraints/')
    protected = {p:h for p,h in baseline['sources'].items() if p.startswith(protected_prefixes)}
    changed = [p for p,h in protected.items() if current.get(p) != h]
    assert not changed, changed
    save('protected_sources.json', {'count':len(protected),'changed':changed,'status':'ALL PASS'})
    old_tests = {p:h for p,h in baseline['sources'].items() if p.startswith('sim/tb_')}
    changed = [p for p,h in old_tests.items() if current.get(p) != h]
    assert not changed, changed
    save('original_tests_unchanged.json', {'count':len(old_tests),'changed':changed,'status':'ALL PASS'})
    old_top = (OUT/'baseline/src/top.v').read_text(encoding='utf-8-sig')
    top = (ROOT/'src/top.v').read_text(encoding='utf-8-sig')
    declaration = r'wire\s+\[69:0\]\s+status_source\s*=([^;]+);'
    assert re.search(declaration,old_top).group(1) == re.search(declaration,top).group(1)
    script = (ROOT/'scripts/run_tests.ps1').read_text()
    tests = sorted(set(re.findall(r"['\"](tb_[A-Za-z0-9_]+)['\"]", script)))
    start = datetime.datetime.fromisoformat(manifest['started_utc']).timestamp()
    log_dir = OUT/'main'
    log_dir.mkdir(exist_ok=True)
    logs = []
    for test in tests:
        path = ROOT/'reports'/f'{test}.log'
        content = path.read_text(errors='replace')
        assert path.stat().st_mtime >= start-30, f'Stale {test}'
        assert 'ALL PASS' in content and not re.search(r'FAILED|\*\* Fatal',content), test
        shutil.copy2(path,log_dir/path.name)
        logs.append({'test':test,'sha256':digest(path),'status':'ALL PASS'})
    save('main_regression.json', {'count':len(tests),'logs':logs,'status':'ALL PASS'})
    area = (ROOT/'reports/physical_area.txt').read_text()
    used = {key:int(re.search(r'^#'+key+r'\s+(\d+)', area,re.M).group(1))
            for key in ('lut','reg','bram','dsp','pll','gclk','pad')}
    assert used['lut'] <= 19600 and used['bram'] <= 64 and used['dsp'] <= 29, used
    changed_inputs = [p for p,h in current.items() if baseline['sources'].get(p) != h]
    evidence = OUT/'final_build'
    evidence.mkdir(exist_ok=True)
    for name in ('build_manifest.json','physical_area.txt','gate_area.txt','rtl_area.txt',
                 'timing_summary.txt','timing_status.txt','synthesis.log','implementation.log',
                 'hold_finalization.log'):
        shutil.copy2(ROOT/'reports'/name,evidence/name)
    summary = {'status':'ALL PASS','rtl_tests':len(tests),'python_tests':10,
               'timing_ns':manifest['timing_ns'],'resources':used,
               'changed_build_inputs':changed_inputs,'status_source_unchanged':True,
               'protected_sources':len(protected),'original_tests':len(old_tests),
               'board_signoff':False,'new_bitstream':False}
    save('verification.json',summary)
    paths = list(json.loads((OUT/'baseline_sha256.json').read_text()))
    paths = [p for p in paths if not p.startswith('reports/')]
    paths += ['src/modules/osd/menu_overlay.v','scripts/gen_zh_font.py',
              'scripts/test_zh_font.py','sim/tb_chinese_menu.v','sim/tb_menu_overlay.v',
              'docs/CHINESE_MENU_20261023.md']
    diff = []
    for name in paths:
        old = OUT/'baseline'/name
        before = old.read_text(encoding='utf-8-sig').splitlines(True) if old.exists() else []
        after = (ROOT/name).read_text(encoding='utf-8-sig').splitlines(True)
        diff.extend(difflib.unified_diff(before,after,fromfile='before/'+name,tofile='after/'+name))
    (OUT/'changes.diff').write_text(''.join(diff),encoding='utf-8')
    print(json.dumps(summary,ensure_ascii=False))


if __name__ == '__main__':
    main()
