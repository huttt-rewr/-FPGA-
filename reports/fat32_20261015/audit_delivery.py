"""Read-only scope check; --freeze saves reproducible test/build evidence."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'reports/fat32_20261015'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_log(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8', errors='replace')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--freeze', action='store_true')
    parser.add_argument('--regression', default='regression_delivery.log')
    args = parser.parse_args()
    changed_allowed = {'src/top.v', 'src/modules/bmp/bmp_read.v',
                       'src/modules/bmp/sd_card_bmp.v', 'src/modules/audio/audio_wav.v',
                       'src/td_project/video_improve.al'}
    protected = {}
    protected_scripts = {}
    changed = []
    with zipfile.ZipFile(ROOT / 'backups/fat32_20261015/before.zip') as baseline:
        for name in baseline.namelist():
            if not name.startswith('src/') or name.endswith('/'):
                continue
            old = baseline.read(name)
            current = ROOT / name
            assert current.is_file(), f'Missing existing source: {name}'
            new = current.read_bytes()
            # git archive stores LF blobs; Windows checkout may contain CRLF.
            if old.replace(b'\r\n', b'\n') != new.replace(b'\r\n', b'\n'):
                assert name in changed_allowed, f'Protected source modified: {name}'
                changed.append(name)
            else:
                protected[name] = {'checkout_sha256': sha(new),
                                   'lf_normalized_sha256': sha(new.replace(b'\r\n', b'\n')),
                                   'matches_archive_bytes': old == new}
        old_top = baseline.read('src/top.v').decode('utf-8-sig').replace('\r\n', '\n')
        old_wav = baseline.read('src/modules/audio/audio_wav.v').decode('utf-8-sig').replace('\r\n', '\n')
        old_bmp = baseline.read('src/modules/bmp/bmp_read.v').decode('utf-8-sig').replace('\r\n', '\n')
        for name in ('scripts/adaptive_clocks.tcl',):
            old = baseline.read(name).replace(b'\r\n', b'\n')
            new = (ROOT/name).read_bytes().replace(b'\r\n', b'\n')
            assert old == new, f'Existing clock constraints modified: {name}'
            protected_scripts[name] = sha(new)
    new_top = (ROOT / 'src/top.v').read_text(encoding='utf-8-sig')
    # Every line outside the single sd_card_bmp parameter block is identical.
    trim = lambda s: re.sub(r'sd_card_bmp #\(.*?\) sd_card_bmp_m0',
                            'SD_CARD_BMP_PARAMETERS', s, flags=re.S)
    assert trim(old_top) == trim(new_top), 'Top changed outside permitted parameters'
    assert 'wire [69:0] status_source' in new_top or '[69:0] status_source' in new_top
    new_wav = (ROOT/'src/modules/audio/audio_wav.v').read_text(encoding='utf-8-sig')
    new_bmp = (ROOT/'src/modules/bmp/bmp_read.v').read_text(encoding='utf-8-sig')
    assert old_wav.split('// 同步RAM端口', 1)[1] == new_wav.split('// 同步RAM端口', 1)[1], 'WAV parser/RAM/FSM changed'
    assert old_bmp.split('            ST_LOAD_HDR: begin', 1)[1] == new_bmp.split('            ST_LOAD_HDR: begin', 1)[1], 'BMP header/scaler/write FSM changed'
    record = {'changed_existing_src': changed, 'unchanged_src_sha256': protected,
              'status_bus_cdc_osd_and_top_outside_sd_parameters_unchanged': True,
              'wav_parser_and_bmp_header_scaler_write_fsm_unchanged': True,
              'unchanged_clock_scripts_lf_sha256': protected_scripts,
              'backup_sha256': sha((ROOT / 'backups/fat32_20261015/before.zip').read_bytes())}
    if args.freeze:
        manifest = json.loads((ROOT / 'reports/build_manifest.json').read_text())
        assert manifest['status'] in ('completed', 'timing_failed'), manifest['status']
        for name, expected in manifest['sources'].items():
            assert sha((ROOT/name).read_bytes()) == expected, f'Build mismatch {name}'
        regression = OUT / args.regression
        text = read_log(regression)
        assert 'ALL TESTS PASSED' in text
        tests = re.findall(r'^# Loading work\.(tb_\w+)\(fast\)', text, re.M)
        assert len(tests) == len(set(tests)) == 61, (len(tests), len(set(tests)))
        test_hashes = {}
        frozen = OUT / 'regression'
        frozen.mkdir(exist_ok=True)
        for tb in tests:
            path = ROOT / f'reports/{tb}.log'
            log = read_log(path)
            assert 'ALL PASS' in log and not re.search(r'FAILED|\*\* (Error|Fatal)', log), tb
            shutil.copy2(path, frozen/path.name)
            test_hashes[tb] = sha(path.read_bytes())
        for name in ('build_manifest.json', 'design_sources.tcl', 'timing_status.txt',
                     'timing_summary.txt', 'physical_area.txt', 'gate_area.txt',
                     'rtl_area.txt', 'synthesis.log', 'implementation.log', 'io.txt'):
            shutil.copy2(ROOT/'reports'/name, OUT/name)
        record.update(tests=test_hashes, test_count=61,
                      regression_log=regression.name,
                      regression_sha256=sha(regression.read_bytes()),
                      timing_ns=manifest['timing_ns'], build_status=manifest['status'],
                      build_sources_sha256=manifest['sources'], board_verified=False,
                      frozen_reports_sha256={p.name: sha(p.read_bytes()) for p in OUT.iterdir()
                                             if p.name in ('build_manifest.json', 'timing_status.txt',
                                                           'timing_summary.txt', 'physical_area.txt')})
    # 普通范围复查不覆盖已冻结的回归/构建证据。
    if args.freeze:
        (OUT/'scope_audit.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    print(f'ALL PASS scope: {len(protected)} unchanged existing source files; '
          f'only {len(changed)} planned existing source changes; '
          '70-bit bus/CDC/OSD/pins/IP/SD stack unchanged')
    if args.freeze:
        print('Frozen 61 regression logs, source hashes and actual routed timing reports')


if __name__ == '__main__':
    main()
