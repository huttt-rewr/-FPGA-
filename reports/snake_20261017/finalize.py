from pathlib import Path
import hashlib
import json
import re
import runpy
import shutil

ROOT = Path(__file__).resolve().parents[2]
D = Path(__file__).resolve().parent
runpy.run_path(str(D / 'audit.py'))
build = json.loads((ROOT / 'reports/build_manifest.json').read_text())
current = runpy.run_path(str(ROOT / 'scripts/run_build.py'))['snapshot']()
assert current == build['sources'], 'Build inputs changed; do not publish results'
assert build['status'] != 'running'
raw_regression = (D / 'regression.log').read_bytes()
regression = raw_regression.decode('utf-16' if raw_regression.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8', errors='replace')
assert 'ALL TESTS PASSED' in regression
assert not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)', regression)
tests = re.findall(r'^# vsim .* -c (tb_\w+)\s*$', regression, re.M)
assert len(tests) == len(set(tests)) == 88, (len(tests), len(set(tests)))
logs = D / 'verified_simulation'
logs.mkdir(exist_ok=True)
for tb in tests:
    src = ROOT / 'reports' / (tb + '.log')
    content = src.read_text(encoding='utf-8', errors='replace')
    assert 'ALL PASS' in content and not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)', content), tb
    shutil.copy2(src, logs / src.name)

def area(path):
    text = path.read_text(encoding='utf-8', errors='replace')
    return {key: int(value) for key, value in re.findall(r'^#(lut|reg|bram|dsp)\s+(\d+)\s+out of', text, re.M)}

game = area(D / 'game_gate_area.txt')
system = area(ROOT / 'reports/gate_area.txt')
assert game['bram'] == 0 and game['dsp'] == 0 and system['bram'] == 61
evidence = D / 'final_build'
evidence.mkdir(exist_ok=True)
for name in ['gate_area.txt', 'rtl_area.txt', 'build_manifest.json', 'synthesis.log', 'implementation.log',
             'physical_area.txt', 'timing_status.txt', 'timing_summary.txt', 'io.txt']:
    src = ROOT / 'reports' / name
    if src.exists():
        shutil.copy2(src, evidence / name)
impl = (evidence / 'implementation.log').read_text(encoding='utf-8', errors='replace')
errors = re.findall(r'^.*ERROR:.*$', impl, re.M)
record = {
    'status': 'experimental_physical_blocked' if build['status'] != 'completed' else 'implemented',
    'static': {'sources': 76, 'top_io_bits': 40, 'result': 'ALL PASS'},
    'modelsim_tests': tests, 'modelsim_count': len(tests), 'modelsim_result': 'ALL PASS',
    'game_gate_area': game, 'system_gate_area': system,
    'build_status': build['status'], 'build_inputs_match': True, 'physical_errors': errors,
    'timing_ns': build.get('timing_ns'), 'board_verified': False,
    'new_bit_generated': False,
    'sources': build['sources'],
    'evidence_sha256': {p.relative_to(D).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                        for base in [evidence, logs] for p in base.iterdir() if p.is_file()},
}
(D / 'validation.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
print(json.dumps({k: v for k, v in record.items() if k not in ('sources', 'modelsim_tests', 'evidence_sha256')}, ensure_ascii=False, indent=2))
