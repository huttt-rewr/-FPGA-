"""Generate a gradient-menu bit only from matching, tested and timed inputs."""
from pathlib import Path
import datetime
import hashlib
import json
import re
import runpy
import shutil
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BIT = OUT/'video_improve_menu_gradient_20261023.bit'
DATABASE = ROOT/'reports/video_improve_routed.db'
MANIFEST = ROOT/'reports/build_manifest.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def metrics(path):
    values = {k:float(v) for k,v in re.findall(
        r'(SWNS|STNS|HWNS|HTNS):\s*(-?\d+\.\d+)ns',path.read_text())}
    assert len(values)==4 and all(v>=0 for v in values.values()), values
    return values


def main():
    assert not BIT.exists(), 'Refusing to overwrite an existing candidate'
    build = json.loads(MANIFEST.read_text(encoding='utf-8'))
    snapshot = runpy.run_path(str(ROOT/'scripts/run_build.py'))['snapshot']
    assert build['status']=='completed' and snapshot()==build['sources']
    database_sha,manifest_sha = sha(DATABASE),sha(MANIFEST)
    assert database_sha==build['products'][DATABASE.name]
    area = (ROOT/'reports/physical_area.txt').read_text()
    resources = {k:int(re.search(r'^#'+k+r'\s+(\d+)',area,re.M).group(1))
                 for k in ('lut','reg','bram','dsp')}
    assert resources['lut']<=18620 and resources['bram']<=64 and resources['dsp']<=29,resources
    script = (ROOT/'scripts/run_tests.ps1').read_text()
    tests = sorted(set(re.findall(r"['\"](tb_[A-Za-z0-9_]+)['\"]",script)))
    started = datetime.datetime.fromisoformat(build['started_utc']).timestamp()
    main_logs = OUT.parent/'main'
    main_logs.mkdir(exist_ok=True)
    regression = []
    for test in tests:
        log = ROOT/'reports'/f'{test}.log'
        text = log.read_text(errors='replace')
        assert log.stat().st_mtime>=started-30, f'Stale test log: {test}'
        assert 'ALL PASS' in text and not re.search(r'FAILED|\*\* Fatal',text),test
        shutil.copy2(log,main_logs/log.name)
        regression.append({'test':test,'status':'ALL PASS','sha256':sha(log)})
    (OUT.parent/'regression.json').write_text(json.dumps(
        {'rtl_count':len(tests),'tests':regression},indent=2)+'\n',encoding='utf-8')
    expected = ' '.join(f'{key} {float(build["timing_ns"][key]):.3f}'
                        for key in ('SWNS','STNS','HWNS','HTNS'))
    (OUT/'expected_timing.tcl').write_text('set expected_timing {'+expected+'}\n',encoding='ascii')
    record = {'status':'running','started_utc':now(),'device':'EG4S20BG256',
              'source_build_finished_utc':build['finished_utc'],
              'source_build_manifest_sha256':manifest_sha,
              'routed_database_sha256':database_sha,'board_signoff':False,
              'hardware_download_performed':False,'bit_file':str(BIT),
              'resources':resources,'rtl_tests':len(tests)}
    target = OUT/'manifest.json'
    shutil.copy2(MANIFEST,OUT/'source_build_manifest.json')
    final = OUT.parent/'final_build'
    final.mkdir(exist_ok=True)
    for name in ('build_manifest.json','physical_area.txt','gate_area.txt','rtl_area.txt',
                 'timing_status.txt','timing_summary.txt','synthesis.log',
                 'implementation.log','hold_finalization.log'):
        shutil.copy2(ROOT/'reports'/name,final/name)
    target.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    try:
        print(f'Source/database hashes and {len(tests)} RTL tests verified; running TD bitgen',flush=True)
        with (OUT/'bitgen.log').open('wb') as log:
            result = subprocess.run([build['td'],(OUT/'generate_candidate.tcl').as_posix()],
                                    cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=600)
        text = (OUT/'bitgen.log').read_text(encoding='utf-8',errors='replace')
        errors = re.findall(r'^.*(?:\bERROR\s*:|\bFATAL\b|Oops!\s*coredump|invalid command name|couldn.t read file|can.t read .*no such variable).*$',text,re.M|re.I)
        assert result.returncode==0 and 'BITGEN_COMPLETED' in text and not errors,(result.returncode,errors[:3])
        assert BIT.is_file() and BIT.stat().st_size>0
        before,after = metrics(OUT/'before_bit_timing_status.txt'),metrics(OUT/'after_bit_timing_status.txt')
        assert before==after==build['timing_ns'],(before,after,build['timing_ns'])
        for name in ('before_bit_timing_summary.txt','after_bit_timing_summary.txt'):
            section = (OUT/name).read_text(errors='replace').split('Clock Summary',1)[1].split('Notes',1)[0]
            assert all(re.search(r'\b'+clock+r'\b',section)
                       for clock in ('vga_pixel','svga_pixel','vga_serial','svga_serial'))
        assert snapshot()==build['sources'] and sha(DATABASE)==database_sha and sha(MANIFEST)==manifest_sha
        record.update(status='candidate_generated',bit_bytes=BIT.stat().st_size,
                      bit_sha256=sha(BIT),before_timing_ns=before,after_timing_ns=after,
                      hold_margin_0_5ns_met=after['HWNS']>=0.5,
                      artifacts_sha256={p.name:sha(p) for p in sorted(OUT.iterdir())
                                        if p.is_file() and p.name!='manifest.json'})
        print(json.dumps({k:record[k] for k in ('status','bit_file','bit_bytes','bit_sha256','after_timing_ns')},ensure_ascii=False),flush=True)
    except Exception as exc:
        record.update(status='failed',error=repr(exc))
        raise
    finally:
        record['finished_utc']=now()
        target.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':
    main()
