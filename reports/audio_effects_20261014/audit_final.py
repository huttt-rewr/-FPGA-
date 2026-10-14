"""Read-only source scope/registration audit plus frozen evidence snapshots."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    backup = ROOT/'backups/audio_effects_20261014_211158/workspace.zip'
    with zipfile.ZipFile(backup) as z:
        names = z.namelist()
        changed = [n for n in names if (ROOT/n).is_file() and z.read(n) != (ROOT/n).read_bytes()]
        before = z.read('src/top.v').decode('utf-8-sig')
    allowed = {'src/top.v', 'scripts/design_files.txt', 'scripts/run_tests.ps1',
               'src/td_project/video_improve.al', 'video_improve.al'}
    assert set(changed) <= allowed, changed
    now = (ROOT/'src/top.v').read_text(encoding='utf-8-sig')
    def protected(text):
        return [line.strip() for line in text.splitlines() if any(x in line for x in
                ('status_source', 'status_video[', 'frame_ui', 'cdc_snapshot #',
                 'wire audio_valid', 'wire [23:0] audio_left', '.pcm_valid(audio_pcm_valid)',
                 'I_audio_', 'AUDIO_SAMPLE_RATE')) and '.valid(' not in line]
    assert protected(before) == protected(now), 'Protected top-level declarations changed'
    # Compare top before/after after removing only authorized local audio segment.
    def without_audio(text):
        return re.sub(r'(?:wire audio_src_valid;\s*wire \[23:0\] audio_src_left,audio_src_right;\s*)?'
                      r'audio_playback #\(\.ADAPTIVE\(1\)\).*?(?=edid_display_mode edid_check)',
                      '<AUTHORIZED_AUDIO_SEGMENT>\n', text, flags=re.S).strip()
    assert without_audio(before) == without_audio(now), 'Top changes outside audio wiring'
    sources = [p.strip() for p in (ROOT/'scripts/design_files.txt').read_text().splitlines() if p.strip()]
    assert sources.count('src/modules/audio/audio_effects.v') == 1
    assert len(sources) == 62
    for project in ('video_improve.al', 'src/td_project/video_improve.al'):
        assert (ROOT/project).read_text().count('audio_effects.v') == 1
    formal = OUT/'formal_final'
    formal.mkdir(exist_ok=True)
    manifest = json.loads((ROOT/'reports/build_manifest.json').read_text())
    assert manifest['status'] == 'completed', manifest['status']
    for path, digest in manifest['sources'].items():
        assert sha(ROOT/path) == digest, path
    for name in ('build_manifest.json', 'timing_status.txt', 'timing_summary.txt', 'physical_area.txt',
                 'gate_area.txt', 'rtl_area.txt', 'synthesis.log', 'implementation.log'):
        shutil.copy2(ROOT/'reports'/name, formal/name)
    logs = {}
    script = (ROOT/'scripts/run_tests.ps1').read_text()
    tests = sorted(set(re.findall(r"'(tb_[a-z0-9_]+)'", script)))
    assert len(tests) == 58, len(tests)
    console = OUT/'regression_final.log'
    if console.exists() and 'ALL TESTS PASSED' in console.read_text(errors='replace'):
        for tb in tests:
            p = ROOT/'reports'/f'{tb}.log'
            text = p.read_text(errors='replace')
            assert 'ALL PASS' in text and not re.search(r'FAILED|\*\* (Error|Fatal)', text), tb
            logs[tb] = sha(p)
        (OUT/'regression_completion.json').write_text(json.dumps({'count': len(logs), 'logs': logs,
                  'rtl_sha256': sha(ROOT/'src/modules/audio/audio_effects.v'),
                  'top_sha256': sha(ROOT/'src/top.v')}, indent=2), encoding='utf-8')
    record = {'backup': str(backup), 'changed_existing': changed, 'scope_passed': True,
              'source_count': len(sources), 'protected_top_passed': True,
              'new_rtl': 'src/modules/audio/audio_effects.v', 'new_tb': 'sim/tb_audio_effects.v',
              'regression_count': len(logs), 'formal_timing': manifest['timing_ns'],
              'source_hashes': {p: sha(ROOT/p) for p in sources},
              'frozen_reports': {p.name: sha(p) for p in formal.iterdir() if p.is_file()}}
    (OUT/'scope_audit.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    print('ALL PASS protected scope, 62 sources, frozen formal STA', manifest['timing_ns'])
    print('Fresh complete regression logs:', len(logs))


if __name__ == '__main__':
    main()
