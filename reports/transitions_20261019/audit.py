from pathlib import Path
import hashlib, json, re, sys

root=Path(__file__).resolve().parents[2]
task=Path(__file__).resolve().parent
baseline=json.loads((task/'baseline.json').read_text())
allowed={
 'src/top.v','src/modules/video/frame_swap.v','src/modules/video/transition_pixels.v',
 'src/modules/video/picture_adjust.v','src/modules/video/picture_gamma.v',
 'scripts/run_tests.ps1','sim/tb_board_pipeline.v','sim/tb_effects_pipeline.v',
 'sim/tb_picture_adjust.v','sim/tb_picture_gamma.v','sim/tb_svga_pipeline.v',
 'sim/tb_switch_controls.v','sim/tb_transition.v','sim/tb_transition_pixels.v',
}
changes=[]
for rel,old_hash in baseline['files'].items():
    if rel.startswith(('src/','scripts/','sim/')) or rel=='video_improve.al':
        new_hash=hashlib.sha256((root/rel).read_bytes()).hexdigest()
        if new_hash!=old_hash:
            assert rel in allowed, ('Unplanned input change',rel)
            changes.append(rel)
old=(task/'before/src/top.v').read_text(encoding='utf-8-sig')
new=(root/'src/top.v').read_text(encoding='utf-8-sig')
status=lambda s: re.search(r'wire \[69:0\] status_source=.*?;',s,re.S).group()
assert status(old)==status(new), '70-bit status packing changed'
assert 'wire [1:0] video_effect=status_video[29:28];' in new
manifest=json.loads((root/'reports/build_manifest.json').read_text())
assert manifest['status']=='completed', manifest.get('error',manifest['status'])
metrics=manifest['timing_ns']
assert metrics['SWNS']>=0.105 and metrics['STNS']==0,metrics
assert metrics['HWNS']>=0 and metrics['HTNS']==0,metrics
for rel,hash_value in manifest['sources'].items():
    assert hashlib.sha256((root/rel).read_bytes()).hexdigest()==hash_value, ('stale build',rel)
def critical(folder):
    return {line.strip() for name in ('synthesis.log','implementation.log','hold_finalization.log')
            for line in (folder/name).read_text(encoding='utf-8',errors='replace').splitlines()
            if 'CRITICAL-WARNING:' in line}
before_critical=critical(task/'before/reports')
after_critical=critical(root/'reports')
assert not (after_critical-before_critical), sorted(after_critical-before_critical)
for name in ('synthesis.log','implementation.log','hold_finalization.log'):
    s=(root/'reports'/name).read_text(encoding='utf-8',errors='replace')
    assert not re.search(r'\bERROR\s*:|\bFATAL\b|Oops!\s*coredump',s,re.I),name
regression=(task/(sys.argv[1] if len(sys.argv)>1 else 'regression3.log')).read_text(encoding='utf-8',errors='replace')
# Powershell redirects the console transcript to UTF16 on older Windows.
if '\x00' in regression:
    regression=(task/(sys.argv[1] if len(sys.argv)>1 else 'regression3.log')).read_text(encoding='utf-16')
assert 'ALL TESTS PASSED' in regression
assert not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)',regression)
runner=(root/'scripts/run_tests.ps1').read_text()
tests=sorted(set(re.findall(r"'(tb_\w+)'",runner)))
for tb in tests:
    log=(root/'reports'/(tb+'.log')).read_text(encoding='utf-8',errors='replace')
    assert 'ALL PASS' in log and not re.search(r'FAILED|\[FAIL\]|# FAIL |\*\* (Error|Fatal)',log),tb
result={'baseline_head':baseline['head'],'changed_inputs':sorted(changes),
        'new_test':'sim/tb_transition_effects.v','unique_tests':len(tests),
        'status70_identical':True,'unplanned_input_changes':[],
        'timing_ns':metrics,'new_critical_warnings':sorted(after_critical-before_critical),
        'existing_critical_warnings':sorted(after_critical),'board_verified':False,
        'zoom_implemented':False,'fft_implemented':False}
(task/'validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('ALL PASS delivery audit:',len(tests),'tests; status70 identical; SWNS >= +0.105ns; no new CRITICAL')
