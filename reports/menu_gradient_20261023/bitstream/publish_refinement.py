"""Bind the completed physical trial to unchanged direct HDL inputs.

The root GUI project XML is not read by synth.tcl. Retain its original
snapshot and explicitly audit any metadata change instead of hiding it.
"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import runpy
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
REPORTS = ROOT/'reports'
OUT = Path(__file__).resolve().parent
TRIAL = OUT/'physical_refinement/seed26'
ORIGINAL = OUT/'physical_refinement/seed25_failed/build_manifest.json'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def project(path):
    return ET.fromstring(path.read_text(encoding='utf-8-sig').replace('UsedInP&R','UsedInP&amp;R'))

manifest = REPORTS/'build_manifest.json'
build = json.loads(manifest.read_text())
assert build==json.loads(ORIGINAL.read_text()) and build['status']=='timing_failed'
snapshot = runpy.run_path(str(ROOT/'scripts/run_build.py'))['snapshot']
current = snapshot()
changed = sorted(k for k in set(current)|set(build['sources'])
                 if current.get(k)!=build['sources'].get(k))
assert changed==['video_improve.al'], changed
assert sha(REPORTS/'video_improve_gate.db')==build['products']['video_improve_gate.db']

synth = (ROOT/'scripts/synth.tcl').read_text()
assert 'source reports/design_sources.tcl' in synth
assert 'read_adc src/constraints/pin.adc' in synth
assert 'read_sdc src/constraints/timing.sdc' in synth
assert not re.search(r'^\s*(?:open_project|import_project)\b',synth,re.M)
files = [(ROOT/line.strip()).resolve() for line in
         (ROOT/'scripts/design_files.txt').read_text().splitlines() if line.strip()]
literal = 'read_verilog -file {'+' '.join(p.as_posix() for p in files)+'} -top top\n'
assert (REPORTS/'design_sources.tcl').read_text()==literal
for path in (ROOT/'video_improve.al',ROOT/'src/td_project/video_improve.al'):
    tree = project(path)
    assert tree.findtext('HardWare/Device')=='EG4S20BG256'
    assert tree.findtext('TOP_MODULE/MODULE')=='top'
    assert {(path.parent/n.attrib['Path']).resolve() for n in tree.findall('.//Verilog/File')}==set(files)
subprocess.run([sys.executable,'scripts/static_check.py'],cwd=ROOT,check=True)

warnings = {}
for name,marker in (('implementation','IMPLEMENTATION_COMPLETED'),
                    ('hold_finalization','HOLD_FINALIZATION_COMPLETED')):
    text = (TRIAL/(name+'.log')).read_text(errors='replace')
    assert marker in text
    assert not re.search(r'^.*(?:\bERROR\s*:|\bFATAL\b|Oops!\s*coredump|invalid command name|couldn.t read file).*$',text,re.M|re.I)
    warnings[name] = re.findall(r'^.*\b(?:CRITICAL-WARNING|WARNING)\s*:.*$',text,re.M)
    source = (ROOT/'scripts'/('implement.tcl' if name=='implementation' else 'finalize_hold.tcl')).read_text()
    source = source.replace('set root [file normalize [file join [file dirname [info script]] ..]]',
                            'set root {'+ROOT.as_posix()+'}')
    if name=='implementation':
        source = source.replace('set_param place seed 25','set_param place seed 26')
    source = source.replace('reports/',TRIAL.as_posix()+'/')
    source = source.replace(TRIAL.as_posix()+'/video_improve_gate.db',
                            (REPORTS/'video_improve_gate.db').as_posix())
    assert source==(TRIAL/(name+'.tcl')).read_text(), 'Physical script differs from audited transformation'

metrics = {k:float(v) for k,v in re.findall(r'(SWNS|STNS|HWNS|HTNS):\s*(-?\d+\.\d+)ns',
                                          (TRIAL/'timing_status.txt').read_text())}
assert len(metrics)==4 and all(v>=0 for v in metrics.values()),metrics
for name in ('rebound_placed_timing_paths20.txt','routed_timing_paths20.txt'):
    clocks = (TRIAL/name).read_text().split('Clock Summary',1)[1].split('Notes',1)[0]
    assert all(re.search(r'\b'+n+r'\b',clocks) for n in
               ('vga_pixel','svga_pixel','vga_serial','svga_serial'))
area = (TRIAL/'physical_area.txt').read_text()
resources = {k:int(re.search(r'^#'+k+r'\s+(\d+)',area,re.M).group(1)) for k in ('lut','bram','dsp')}
assert resources['lut']<=18620 and resources['bram']<=64 and resources['dsp']<=29,resources

audit = OUT/'project_reconciliation'
audit.mkdir(exist_ok=True)
shutil.copy2(ROOT/'video_improve.al',audit/'current_video_improve.al')
reconciliation = {
    'changed_snapshot_entry':'video_improve.al',
    'original_normalized_sha256':build['sources']['video_improve.al'],
    'current_normalized_sha256':current['video_improve.al'],
    'original_project_bytes_not_available':True,
    'exact_xml_difference_not_reconstructed':True,
    'project_xml_consumed_by_synthesis':False,
    'direct_hdl_manifest_matches_current_root_and_nested_projects':True,
    'actual_src_scripts_sim_hashes_unchanged':True,
    'gate_database_sha256':sha(REPORTS/'video_improve_gate.db'),
    'original_build_manifest_sha256':sha(ORIGINAL),
    'explanation':'Only the GUI project snapshot differs. Direct synthesis reads design_sources.tcl and unchanged ADC/SDC, not the GUI project. All src/scripts/sim snapshot entries and the original synthesized gate database match exactly. The current GUI source list, device and top were revalidated. The original manifest is retained; the current manifest binds the reviewed project state explicitly.'
}
(audit/'audit.json').write_text(json.dumps(reconciliation,indent=2)+'\n',encoding='utf-8')
assert current==snapshot()
for path in TRIAL.iterdir():
    if path.suffix in ('.db','.txt','.log'):
        shutil.copy2(path,REPORTS/path.name)
build.update(status='completed',sources=current,timing_ns=metrics,finished_utc=now(),
             implementation_warnings=warnings['implementation'],
             hold_finalization_warnings=warnings['hold_finalization'],
             board_signoff=False,hold_margin_0_5ns_met=False,
             physical_refinement={
                 'original_status':'timing_failed',
                 'original_timing_ns':json.loads(ORIGINAL.read_text())['timing_ns'],
                 'selected_seed':26,'resources':resources,
                 'evidence_directory':str(TRIAL),
                 'physical_scripts_sha256':{n:sha(TRIAL/n) for n in ('implementation.tcl','hold_finalization.tcl')},
                 'rtl_and_constraints_unchanged':True},
             project_metadata_reconciliation=reconciliation)
build['products'] = {p.name:sha(p) for p in REPORTS.iterdir() if p.suffix in ('.db','.txt')}
manifest.write_text(json.dumps(build,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':build['status'],'timing_ns':metrics,'resources':resources,
                  'actual_hdl_inputs_unchanged':True,'project_metadata_audited':True}))
