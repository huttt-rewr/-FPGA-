"""Freeze this optimization's exact sources, simulation and TD evidence."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def text(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')


def main():
    before = json.loads((OUT / 'before_hashes.json').read_text())
    changed = [p for p, h in before.items() if (ROOT / p).exists() and sha(ROOT / p) != h]
    protected = [p for p in before if p.startswith(('src/ip/', 'src/constraints/', 'src/modules/audio/'))
                 or '/sd/native/' in p or p.endswith(('sd_read_arbiter.v', 'sd_card_top.v',
                 'sd_card_cmd.v', 'sd_card_sec_read_write.v', 'spi_master.v'))]
    assert not set(changed).intersection(protected), 'Protected source changed'
    old = subprocess.check_output(['git', 'show', '2e31b55:src/top.v'], cwd=ROOT).decode('utf-8-sig')
    new = (ROOT / 'src/top.v').read_text(encoding='utf-8-sig')
    for name in ('u_hdmi_1_4b_transmitter_core_wrapper', 'u_hdmi_svga'):
        def instance(s):
            start = s.rfind('hdmi_1_4b_transmitter_core_wrapper', 0, s.index(name) + 1)
            end = s.index(');', s.index(name)) + 2
            return s[start:end]
        assert instance(old) == instance(new), name
    patterns = [r'wire\s*\[69:0\]\s*status_source.*?;',
                r'status_video\[[^\]]+\]']
    for pattern in patterns:
        a, b = re.findall(pattern, old, re.S), re.findall(pattern, new, re.S)
        assert a and a == b, pattern
    pixel_path = 'src/modules/video/pixel_effects.v'
    old_pixel = subprocess.check_output(['git', 'show', '2e31b55:' + pixel_path], cwd=ROOT).decode('utf-8-sig')
    new_pixel = (ROOT / pixel_path).read_text()
    assert old_pixel[old_pixel.index('module video_luma_window'):].strip() == new_pixel[new_pixel.index('module video_luma_window'):].strip()
    manifest = json.loads((ROOT / 'reports/build_manifest.json').read_text())
    for name, h in manifest['sources'].items():
        assert sha(ROOT / name) == h, 'Stale build input: ' + name
    simulation_log = OUT / 'regression_split_geometry.log'
    assert 'ALL TESTS PASSED' in text(simulation_log)
    assert not re.search(r'\*\* (Error|Fatal)|Verilog compilation failed|Simulation failed:', text(simulation_log))
    logs = OUT / 'verified_simulation'
    logs.mkdir(exist_ok=True)
    tests = re.findall(r'\bvsim\s+-do.*?\s+-c\s+(tb_\w+)', text(simulation_log))
    assert len(tests) == len(set(tests)) == 91, len(tests)
    for name in tests:
        p = ROOT / 'reports' / (name + '.log')
        s = text(p)
        assert 'ALL PASS' in s and not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)', s), name
        shutil.copy2(p, logs / p.name)
    frozen = OUT / 'final_build'
    frozen.mkdir(exist_ok=True)
    for name in ('build_manifest.json', 'gate_area.txt', 'rtl_area.txt', 'synthesis.log',
                 'implementation.log', 'video_improve_gate.db', 'video_improve_routed.db',
                 'physical_area.txt', 'timing_status.txt', 'timing_summary.txt',
                 'routed_timing_paths20.txt', 'io.txt', 'video_improve_prior_opt.db',
                 'prior_opt_timing_status.txt', 'prior_opt_timing_paths20.txt'):
        p = ROOT / 'reports' / name
        expected = manifest.get('products', {}).get(name)
        if p.exists() and (not expected or sha(p) == expected):
            shutil.copy2(p, frozen / name)
        elif name in ('physical_area.txt', 'timing_status.txt', 'timing_summary.txt', 'video_improve_routed.db'):
            raise AssertionError('Missing or mismatched final build product: ' + name)
    shutil.copy2(simulation_log, logs / simulation_log.name)
    area = text(frozen / 'gate_area.txt')
    resources = {k: int(re.search(r'^#' + k + r'\s+(\d+)', area, re.M)[1])
                 for k in ('lut', 'reg', 'bram', 'dsp')}
    physical = {k: int(re.search(r'^#' + k + r'\s+(\d+)', text(frozen / 'physical_area.txt'), re.M)[1]) for k in ('lut', 'reg', 'bram', 'dsp')}
    record = {
        'baseline_commit': '2e31b55', 'changed_baseline_inputs': changed,
        'protected_files_unchanged': protected,
        'hdmi_instances_identical': True, 'status70_and_indices_identical': True,
        'static_check': subprocess.check_output(['python', 'scripts/static_check.py'], cwd=ROOT).decode().strip(),
        'simulation_count': len(tests), 'simulation_all_pass': True,
        'physical_resources': physical,
        'physical_lut_16660_met': physical['lut'] <= 16660,
        'regression_log': simulation_log.name,
        'resources': resources, 'lut_16660_met': resources['lut'] <= 16660,
        'bram_58_met': resources['bram'] <= 58,
        'bram_strict_90_percent_met': resources['bram'] / 64 <= .9,
        'build_status': manifest['status'], 'timing_ns': manifest.get('timing_ns'),
        'board_tested': False, 'new_bit_generated': False,
        'bit_release_allowed': manifest['status'] == 'completed' and resources['lut'] <= 16660 and physical['lut'] <= 16660 and resources['bram'] <= 58,
        'regression_sha256': sha(simulation_log),
        'sources': manifest['sources'],
        'evidence': {p.relative_to(OUT).as_posix(): sha(p)
                     for d in (frozen, logs) for p in d.iterdir() if p.is_file()},
    }
    (OUT / 'validation.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in record.items() if k not in ('sources', 'evidence',
          'changed_baseline_inputs', 'protected_files_unchanged')}, indent=2))


if __name__ == '__main__':
    main()
