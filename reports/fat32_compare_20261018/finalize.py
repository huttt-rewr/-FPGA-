"""Bind a selected fresh routed build, the full regression, and current sources."""
from pathlib import Path
import hashlib
import json
import re
import runpy
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
tag, regression = sys.argv[1:3]
build = HERE/tag
manifest = json.loads((build/'build_manifest.json').read_text())
paths = json.loads((build/'paths.json').read_text())
assert manifest['sources'] == runpy.run_path(str(ROOT/'scripts/run_build.py'))['snapshot'](), 'Selected build does not match current inputs'
raw = (HERE/regression).read_bytes()
console = raw.decode('utf-16') if raw.startswith(b'\xff\xfe') else raw.decode('utf-8-sig')
assert 'ALL TESTS PASSED' in console
assert not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)',console)
tests = re.findall(r'-l ../reports/(tb_\w+)\.log',console)
assert len(tests)==94 and len(set(tests))==94, (len(tests),len(set(tests)))
dest = build/'test_logs'
dest.mkdir(exist_ok=True)
for tb in tests:
    logfile=ROOT/'reports'/f'{tb}.log'
    text=logfile.read_text(errors='replace')
    assert 'ALL PASS' in text and not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)',text),tb
    shutil.copy2(logfile,dest/logfile.name)
shutil.copy2(ROOT/'src/modules/sd/sd_fat32.v',build/'sd_fat32.v')
shutil.copy2(ROOT/'sim/tb_fat32_compare.v',build/'tb_fat32_compare.v')
shutil.copy2(HERE/regression,build/'regression.log')
validation=dict(selected=tag, status=manifest['status'], timing_ns=manifest.get('timing_ns'),
    tests=tests, regression_count=len(tests), tests_all_pass=True,
    source_sha256=manifest['sources'], bit_generated=False, hardware_tested=False,
    evidence_sha256={p.relative_to(HERE).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
        for p in build.rglob('*') if p.is_file()})
if tag=='build4':
    validation['selection_note']='三项等价改写均未改善整体实现，已撤回。最终 FAT32 与 a5d76ca 完全一致，保留新增 4074 用例测试和全部候选证据；当前结果来自恢复后的新鲜完整构建。'
(HERE/'validation.json').write_text(json.dumps(validation,indent=2),encoding='utf-8')
print(f'ALL PASS evidence binding: {tag}, 94 regressions, current inputs match fresh build')
