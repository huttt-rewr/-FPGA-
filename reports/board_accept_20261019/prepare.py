"""Prepare reviewable board-test files; never access a hardware device."""
from pathlib import Path
import argparse
import datetime
import hashlib
import importlib.util
import json
import math
import re
import shutil
import struct
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
FROZEN = ROOT / 'reports/hdmi_selfwrite_20261019/build1'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_checker(name):
    # Reuse the existing strict BMP/WAV validators without editing build inputs.
    sys.path.insert(0, str(ROOT / 'scripts'))
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def preflight():
    subprocess.run([sys.executable, str(ROOT / 'reports/hdmi_selfwrite_20261019/verify_delivery.py')],
                   cwd=ROOT, check=True)
    subprocess.run([sys.executable, str(ROOT / 'scripts/static_check.py')], cwd=ROOT, check=True)
    baseline = json.loads((FROZEN / 'build_manifest.json').read_text())
    assert baseline['status'] == 'completed'
    assert digest(ROOT / 'reports/video_improve_routed.db') == baseline['products']['video_improve_routed.db']
    # Keep the original working README edit and accepted sources recoverable.
    backup = HERE / 'before'
    if not backup.exists():
        backup.mkdir()
        for name in ('README.md', 'docs/BUILD_STATUS.md', 'docs/USER_GUIDE.md'):
            target = backup / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
    return baseline


def metrics(path):
    found = {key: float(value) for key, value in re.findall(
        r'(SWNS|STNS|HWNS|HTNS):\s*(-?\d+\.\d+)ns', path.read_text())}
    assert len(found) == 4 and min(found.values()) >= 0, found
    return found


def candidate():
    baseline = preflight()
    out = HERE / 'candidate'
    out.mkdir(exist_ok=True)
    assert not (out / 'manifest.json').exists(), 'Candidate is already frozen'
    td = 'J:/Anlogic/td.6.2.1/bin/td_commands_prompt.exe'
    with (out / 'bitgen.log').open('xb') as log:
        result = subprocess.run([td, (HERE / 'candidate.tcl').as_posix()], cwd=ROOT,
                                stdout=log, stderr=subprocess.STDOUT, timeout=600)
    text = (out / 'bitgen.log').read_text(encoding='utf-8', errors='replace')
    assert result.returncode == 0 and 'BOARD_CANDIDATE_COMPLETED' in text, 'Inspect bitgen.log'
    assert not re.search(r'\bERROR\s*:|\bFATAL\b|Oops!\s*coredump|invalid command name', text, re.I), 'TD error'
    for prefix in ('before', 'after'):
        assert metrics(out / (prefix + '_bit_timing_status.txt')) == baseline['timing_ns']
        paths = (out / (prefix + '_bit_timing_paths.txt')).read_text()
        section = paths.split('Clock Summary', 1)[1].split('Notes', 1)[0]
        assert all(re.search(r'\b' + name + r'\b', section) for name in (
            'vga_pixel', 'svga_pixel', 'vga_serial', 'svga_serial'))
    baseline_crit = {re.search(r'([A-Z]+-\d+) CRITICAL-WARNING', w)[1]
                     for key, values in baseline.items() if key.endswith('_warnings')
                     for w in values if 'CRITICAL-WARNING' in w}
    assert set(re.findall(r'([A-Z]+-\d+) CRITICAL-WARNING', text)) <= baseline_crit
    bit = out / 'hdmi_640_plain_800_audio.bit'
    assert bit.stat().st_size > 0
    assert digest(ROOT / 'reports/video_improve_routed.db') == baseline['products']['video_improve_routed.db']
    for name, sha in baseline['sources'].items():
        assert digest(ROOT / name) == sha, name
    record = {
        'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'device': 'EG4S20BG256', 'speed_reported': 'NA',
        'source_build_manifest_sha256': digest(FROZEN / 'build_manifest.json'),
        'database_sha256': digest(ROOT / 'reports/video_improve_routed.db'),
        'script_sha256': digest(HERE / 'candidate.tcl'),
        'bitstream': bit.name, 'bytes': bit.stat().st_size, 'sha256': digest(bit),
        'timing_ns': baseline['timing_ns'], 'regression_count': 101,
        'vga_sync_control': '{vs,hs}; negative HS/VS', 'vga_next_h_on_frame_start': 1,
        'board_test': 'pending', 'board_signoff': False,
        'programmed_board': False, 'programmed_flash': False, 'wrote_sd_card': False,
        'part2_allowed': False,
        'evidence': {p.name: digest(p) for p in out.iterdir() if p.is_file()},
    }
    (out / 'manifest.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    print(json.dumps(record, indent=2))


def media():
    from PIL import Image, ImageDraw, ImageFont
    bmp = load_checker('prepare_media')
    audio = load_checker('prepare_audio')
    out = HERE / 'sd_files'
    assert not out.exists(), 'Do not overwrite an existing reviewable media set'
    out.mkdir()
    entries = []
    for label, color in (('RED', (255, 0, 0)), ('GREEN', (0, 255, 0)), ('BLUE', (0, 0, 255))):
        image = Image.new('RGB', (640, 480), color)
        path = out / (label + '.bmp')
        image.save(path, 'BMP')
        entries.append({'name': path.name, 'role': 'pure_' + label.lower(), **bmp.check_bytes(path.read_bytes())})
    # Matching-resolution grids diagnose edges/geometry; scaled grids verify
    # the scaler but cannot prove a one-pixel alignment error at the output.
    for name, size in (('GRID640', (640, 480)), ('GRID800', (800, 600)),
                       ('SMALL', (320, 240)), ('PORTRAIT', (360, 640))):
        width, height = size
        image = Image.new('RGB', size, (24, 24, 24))
        draw = ImageDraw.Draw(image)
        font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', max(12, width // 40))
        for x in range(0, width, 40): draw.line((x, 0, x, height - 1), fill=(80, 80, 80))
        for y in range(0, height, 40): draw.line((0, y, width - 1, y), fill=(80, 80, 80))
        draw.rectangle((0, 0, width - 1, height - 1), outline='white')
        draw.rectangle((4, 4, width - 5, height - 5), outline='yellow')
        draw.line((width // 2, 0, width // 2, height - 1), fill='white')
        draw.line((0, height // 2, width - 1, height // 2), fill='white')
        for text, x, y in (('TL', 10, 8), ('TR', width - 45, 8),
                           ('BL', 10, height - 30), ('BR', width - 45, height - 30)):
            draw.text((x, y), text, fill='white', font=font)
        top = height // 4
        for i, color in enumerate(('red', 'lime', 'blue', 'white', 'yellow', 'cyan', 'magenta', 'black')):
            x1 = 8 + i * (width - 16) // 8
            x2 = 8 + (i + 1) * (width - 16) // 8 - 1
            draw.rectangle((x1, top, x2, top + height // 8), fill=color)
        for x in range(8, width - 8):
            value = round(255 * (x - 8) / (width - 17))
            draw.line((x, height * 3 // 4, x, height * 7 // 8), fill=(value,) * 3)
        draw.text((12, height // 2 + 12), f'{name} {width}x{height}', fill='white', font=font)
        path = out / (name + '.bmp')
        image.save(path, 'BMP')
        entries.append({'name': path.name, 'role': 'geometry_scale', **bmp.check_bytes(path.read_bytes())})
    # Six-second quiet diagnostic tone with smooth start/stop, not music.
    rate = 48000
    samples = []
    for index in range(6 * rate):
        seconds = index / rate
        segment_start = 0 if seconds < 2 else 3
        active = seconds < 2 or 3 <= seconds < 5
        local = seconds - segment_start
        envelope = max(0., min(1., local / .01, (2 - local) / .01)) if active else 0.
        hz = 440 if seconds < 2 else 880
        samples.append(round(4096 * envelope * math.sin(2 * math.pi * hz * seconds)))
    path = out / 'TONE.wav'
    with wave.open(str(path), 'wb') as stream:
        stream.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        stream.writeframes(struct.pack('<' + str(len(samples)) + 'h', *samples))
    entries.append({'name': path.name, 'role': '440Hz 2s / silence 1s / 880Hz 2s / silence 1s',
                    **audio.check(path)})
    record = {'format': 'ordinary_files_for_FAT32_root', 'device_writes': False,
              'image_order': 'FAT directory entry order; never infer index from filename',
              'files': entries}
    (HERE / 'media_manifest.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    # A PC-only preview: never copied to the SD card as playable content.
    sheet = Image.new('RGB', (4 * 320, 2 * 265), 'white')
    draw = ImageDraw.Draw(sheet)
    for index, entry in enumerate(entries[:-1]):
        with Image.open(out / entry['name']) as image:
            image.thumbnail((320, 240))
            x, y = (index % 4) * 320, (index // 4) * 265
            sheet.paste(image, (x + (320 - image.width) // 2, y))
            draw.text((x + 8, y + 244), entry['name'], fill='black')
    sheet.save(HERE / 'media_preview.png')
    print('Generated 7 validated BMPs + 1 mono/48k/16bit WAV, no card accessed')


def verify():
    baseline = preflight()
    record = json.loads((HERE / 'candidate/manifest.json').read_text())
    out = HERE / 'candidate'
    assert digest(out / record['bitstream']) == record['sha256']
    assert (out / record['bitstream']).stat().st_size == record['bytes']
    assert record['timing_ns'] == baseline['timing_ns']
    assert not record['part2_allowed'] and record['board_test'] == 'pending'
    assert record['script_sha256'] == digest(HERE / 'candidate.tcl')
    for name, sha in record['evidence'].items(): assert digest(out / name) == sha, name
    bmp, audio = load_checker('prepare_media'), load_checker('prepare_audio')
    entries = json.loads((HERE / 'media_manifest.json').read_text())['files']
    assert len(entries) == 8
    for entry in entries:
        path = HERE / 'sd_files' / entry['name']
        checker = bmp.check_bytes(path.read_bytes()) if path.suffix == '.bmp' else audio.check(path)
        assert all(entry[k] == v for k, v in checker.items()), path.name
    print('ALL PASS: source/DB/bit/timing binding, 7 BMP + 1 WAV hashes and format; physical acceptance remains pending')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('candidate', 'media', 'verify'))
    args = parser.parse_args()
    {'candidate': candidate, 'media': media, 'verify': verify}[args.action]()
