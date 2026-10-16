"""Freeze this task's evidence without treating SPI STA as native-SD signoff."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

root = Path(__file__).resolve().parents[2]
out = root / 'reports/sd_native_20261016'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')

baseline = json.loads((out / 'baseline_sha256.json').read_text())
protected_names = {'sd_read_arbiter.v', 'sd_fat32.v', 'bmp_read.v', 'audio_wav.v', 'bmp_scale_loader.v'}
protected = [p for p in root.joinpath('src').rglob('*.v') if p.name in protected_names]
unchanged = {p.relative_to(root).as_posix(): sha(p) == baseline[p.relative_to(root).as_posix()] for p in protected}
assert len(unchanged) == 5 and all(unchanged.values()), unchanged
board_files = ['src/top.v', 'src/modules/bmp/sd_card_bmp.v', 'src/modules/sd/sd_card_top.v',
               'src/modules/sd/sd_card_cmd.v', 'src/modules/sd/sd_card_sec_read_write.v',
               'src/modules/sd/spi_master.v', 'src/constraints/pin.adc', 'src/constraints/timing.sdc',
               'scripts/design_files.txt', 'video_improve.al', 'src/td_project/video_improve.al']
board_unchanged = {name: sha(root / name) == baseline[name] for name in board_files}
assert all(board_unchanged.values()), board_unchanged
assert all(sha(root / name) == value for name, value in baseline.items() if name.startswith('src/ip/'))
static = subprocess.run(['python', 'scripts/static_check.py'], cwd=root, check=True, capture_output=True, text=True).stdout
(out / 'static_check.log').write_text(static, encoding='utf-8')
script = root.joinpath('scripts/run_tests.ps1').read_text(encoding='utf-8-sig')
tests = sorted(set(re.findall(r"'(tb_[A-Za-z0-9_]+)(?:\.v)?'", script)))
assert len(tests) == 65, tests
console = read(out / 'regression.log')
assert 'ALL TESTS PASSED' in console, 'Full regression has not completed'
frozen = out / 'regression'
frozen.mkdir(exist_ok=True)
test_results = {}
for name in tests:
    p = root / f'reports/{name}.log'
    log = read(p)
    assert 'ALL PASS' in log and not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)', log), name
    shutil.copy2(p, frozen / p.name)
    test_results[name] = {'result': 'PASS', 'sha256': sha(p)}
synthesis = read(out / 'native_synthesis.log')
assert 'NATIVE_SYNTHESIS_COMPLETED' in synthesis
assert not re.search(r'\bERROR\s*:|\bFATAL\b|invalid command name|couldn.t read file', synthesis, re.I)
build = json.loads(root.joinpath('reports/build_manifest.json').read_text())
assert build['status'] in ('completed', 'timing_failed'), build['status']
for name, value in build['sources'].items():
    assert sha(root / name) == value, f'Build input changed: {name}'
build_dir = out / 'spi_board_build'
build_dir.mkdir(exist_ok=True)
for name in ['build_manifest.json', 'timing_status.txt', 'timing_summary.txt', 'physical_area.txt',
             'synthesis.log', 'implementation.log', 'io.txt']:
    shutil.copy2(root / 'reports' / name, build_dir / name)
native_log = read(root / 'reports/tb_sd_native.log')
match = re.search(r'NATIVE sustained: 8192 bytes / (\d+) host cycles = ([\d.]+) MB/s', native_log)
assert match and float(match[2]) >= 10
sources = [p for base in ['src/modules/sd/native', 'sim'] for p in root.joinpath(base).glob('*.v')
           if base.endswith('native') or p.name.startswith('tb_sd_native') or p.name == 'sd_native_card_model.v']
sources += [root / p for p in ['scripts/run_sd_native_tests.ps1', 'scripts/synth_sd_native.tcl', 'scripts/run_tests.ps1']]
result = {
    'scope': 'native SD candidate; official board still SPI pending verified DAT1/DAT2 and pull-ups',
    'protected_files_unchanged': unchanged, 'official_board_files_unchanged': board_unchanged,
    'vendor_ip_unchanged': True, 'static_check': static.strip(),
    'regression_passed': len(test_results), 'tests': test_results,
    'native_candidate_synthesis': {'completed': True, 'lut': 1074, 'reg': 577, 'bram': 0, 'dsp': 0,
                                   'warning': 'SYN-5025: Using 0 for all undriven pins and nets'},
    'logical_model_throughput': {'bytes': 8192, 'host_cycles': int(match[1]),
                                 'host_hz': 100000000, 'MB_per_s': float(match[2]), 'hardware_measured': False},
    'official_SPI_build': {'status': build['status'], 'timing_ns': build['timing_ns']},
    'native_board_integrated': False, 'native_board_PnR_STA_completed': False,
    'native_hardware_validated': False,
    'sources_sha256': {p.relative_to(root).as_posix(): sha(p) for p in sources}
}
(out / 'validation.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k: v for k, v in result.items() if k not in ('tests', 'sources_sha256')}, ensure_ascii=False, indent=2))
