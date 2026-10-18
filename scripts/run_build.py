"""Run a fresh TD synthesis/route and bind reports to exact source hashes.

Tool completion markers alone do not establish timing or board signoff.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / 'reports'


def snapshot():
    paths = [p for base in ('src', 'scripts', 'sim') for p in (ROOT / base).rglob('*')
             if p.is_file() and p.suffix in ('.v', '.vhd', '.adc', '.sdc', '.al', '.ipc', '.tcl', '.ps1', '.py', '.txt')
             and not any(part in ('msim_work', 'pll_work', 'indexed_work', 'keyboard_work', 'sd_native_work') for part in p.parts)]
    paths.append(ROOT / 'video_improve.al')
    return {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths)}


def run(td, script, log, marker, products):
    # Remove no evidence: archive previous named products so a failed TD command
    # cannot accidentally qualify yesterday's database/report as today's result.
    archive = REPORTS / 'previous_build' / datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    for name in [log, *products]:
        p = REPORTS / name
        if p.exists():
            archive.mkdir(parents=True, exist_ok=True)
            p.rename(archive / name)
    print(f'Running {script}', flush=True)
    with (REPORTS / log).open('wb') as output:
        result = subprocess.run([td, (ROOT / 'scripts' / script).as_posix()], cwd=ROOT,
                                stdout=output, stderr=subprocess.STDOUT, timeout=1800)
    text = (REPORTS / log).read_text(encoding='utf-8', errors='replace')
    errors = re.findall(r'^.*(?:\bERROR\s*:|\bFATAL\b|Oops!\s*coredump|invalid command name|couldn.t read file|can.t read .*no such variable).*$', text, re.M | re.I)
    if result.returncode or marker not in text or errors:
        raise RuntimeError(f'{script} failed; see {log}: {errors[:3]}')
    if any(not (REPORTS / p).is_file() or not (REPORTS / p).stat().st_size for p in products):
        raise RuntimeError(f'Missing fresh products from {script}')
    return re.findall(r'^.*\b(?:CRITICAL-WARNING|WARNING)\s*:.*$', text, re.M)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--td', default='J:/Anlogic/td.6.2.1/bin/td_commands_prompt.exe')
    args = parser.parse_args()
    REPORTS.mkdir(exist_ok=True)
    subprocess.run([sys.executable, str(ROOT / 'scripts/static_check.py')], cwd=ROOT, check=True)
    design_files = [(ROOT / p.strip()).resolve() for p in
                    (ROOT / 'scripts/design_files.txt').read_text().splitlines() if p.strip()]
    if any(any(c.isspace() or c in '{};[$]' for c in p.as_posix()) for p in design_files):
        raise RuntimeError('TD direct HDL loader requires source paths without spaces/Tcl metacharacters')
    literal_files = ' '.join(p.as_posix() for p in design_files)
    (REPORTS / 'design_sources.tcl').write_text(
        'read_verilog -file {' + literal_files + '} -top top\n', encoding='utf-8')
    sources = snapshot()
    record = {'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'status': 'running', 'td': args.td, 'sources': sources}
    manifest = REPORTS / 'build_manifest.json'
    manifest.write_text(json.dumps(record, indent=2), encoding='utf-8')
    try:
        record['synthesis_warnings'] = run(args.td, 'synth.tcl', 'synthesis.log', 'SYNTHESIS_COMPLETED',
                                           ['video_improve_gate.db', 'rtl_area.txt', 'gate_area.txt'])
        record['implementation_warnings'] = run(args.td, 'implement.tcl', 'implementation.log', 'IMPLEMENTATION_COMPLETED',
            ['video_improve_routed.db', 'physical_area.txt', 'timing_status.txt', 'timing_summary.txt', 'io.txt',
             'video_improve_prior_opt.db', 'prior_opt_timing_status.txt',
             'prior_opt_timing_paths20.txt', 'routed_timing_paths20.txt',
             'rebound_placed_timing_status.txt', 'rebound_placed_timing_paths20.txt'])
        # A physically remapped mux can silently lose its alternative clocks.
        # Check refreshed placement and final routing, before trusting metrics.
        for report_name in ('rebound_placed_timing_paths20.txt', 'routed_timing_paths20.txt'):
            clock_section = (REPORTS / report_name).read_text().split('Clock Summary', 1)[1].split('Notes', 1)[0]
            if not all(re.search(r'\b' + name + r'\b', clock_section)
                       for name in ('vga_pixel', 'svga_pixel', 'vga_serial', 'svga_serial')):
                raise RuntimeError(f'Mode clock missing in {report_name}')
        if sources != snapshot():
            raise RuntimeError('Build inputs changed while TD was running')
        text = (REPORTS / 'timing_status.txt').read_text()
        metrics = {key: float(value) for key, value in re.findall(r'(SWNS|STNS|HWNS|HTNS):\s*(-?\d+\.\d+)ns', text)}
        if len(metrics) != 4:
            raise RuntimeError('Cannot parse all four timing metrics')
        record['timing_ns'] = metrics
        record['status'] = 'completed' if all(v >= 0 for v in metrics.values()) else 'timing_failed'
        record['board_signoff'] = False
        record['hold_margin_0_5ns_met'] = metrics['HWNS'] >= 0.5
        record['products'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in REPORTS.iterdir() if p.suffix in ('.db', '.txt')}
        print(json.dumps(metrics), flush=True)
        return 0 if record['status'] == 'completed' else 1
    except Exception as exc:
        record['status'] = 'failed'
        record['error'] = str(exc)
        raise
    finally:
        record['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        manifest.write_text(json.dumps(record, indent=2), encoding='utf-8')


if __name__ == '__main__':
    sys.exit(main())
