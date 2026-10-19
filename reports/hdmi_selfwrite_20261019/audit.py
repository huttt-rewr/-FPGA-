"""Scope audit and immutable report capture for the VGA-only replacement."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import sys

r=Path(__file__).resolve().parents[2]
here=Path(__file__).resolve().parent
baseline=json.loads((here/'baseline.json').read_text())
allowed={'src/top.v','scripts/design_files.txt','scripts/run_tests.ps1',
         'video_improve.al','src/td_project/video_improve.al'}
for name,digest in baseline.items():
    if name.startswith(('src/','scripts/','sim/')) and name not in allowed:
        assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest, name
old=(here/'before/src/top.v').read_text(encoding='utf-8-sig')
new=(r/'src/top.v').read_text(encoding='utf-8-sig')
for block in (') u_hdmi_svga(', ') u_hdmi2phy_wrapper('):
    def extract(t):
        start=t.index(block)
        return t[start:t.index('\n);',start)+3]
    assert extract(old)==extract(new), block
assert old[old.index('hdmi_1_4b_transmitter_core_wrapper #(\n    .DEVICE',old.index(') u_hdmi_1_4b_transmitter_core_wrapper(')):old.index(') u_hdmi_svga(')]==new[new.index('hdmi_1_4b_transmitter_core_wrapper #('):new.index(') u_hdmi_svga(')]
for pattern in (r'wire\s+\[69:0\]\s+status_source.*?;',):
    assert re.search(pattern,old,re.S).group()==re.search(pattern,new,re.S).group(), pattern
# Reconstruct the EXACT expected top edit; catch any unrelated control/reset edit.
expected=old.replace('wire vga_ready,svga_ready;','wire svga_ready;').replace(
    'assign axis_s_ready=mode_video?svga_ready:vga_ready;',"assign axis_s_ready=mode_video?svga_ready:1'b1;")
def omit_vga(t):
    begin=t.index('hdmi_1_4b_transmitter_core_wrapper #(')
    end=t.index('\nhdmi_1_4b_transmitter_core_wrapper #(',begin+1)
    return t[:begin]+'REPLACED\n'+t[end:]
expected=omit_vga(expected)
begin=new.index('// Video-only VGA consumes')
end=new.index('\nhdmi_1_4b_transmitter_core_wrapper #(',begin)
actual=new[:begin]+'REPLACED\n'+new[end:]
assert expected==actual,'Unexpected top edit'
assert new.count('hdmi_1_4b_transmitter_core_wrapper #(')==1
assert 'tmds_encoder.v' in (r/'scripts/design_files.txt').read_text()
print('ALL PASS scope: 800 core/PHY/PLL/SDRAM/pins/70-bit status and all prior RTL/tests unchanged')

if len(sys.argv)>1 and sys.argv[1]=='freeze':
    tag=sys.argv[2]
    out=here/tag
    assert not out.exists(), 'Do not overwrite frozen evidence'
    out.mkdir()
    manifest=json.loads((r/'reports/build_manifest.json').read_text())
    assert manifest['status'] in ('completed','timing_failed')
    for name,digest in manifest['sources'].items():
        assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest,name
    names=['build_manifest.json','synthesis.log','implementation.log','hold_finalization.log',
           'rtl_area.txt','gate_area.txt','physical_area.txt','timing_status.txt','timing_summary.txt',
           'routed_timing_paths20.txt','io.txt']
    for name in names:shutil.copy2(r/'reports'/name,out/name)
    hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir()}
    (out/'sha256.json').write_text(json.dumps(hashes,indent=2))
    print(f'Frozen {tag}: {manifest["timing_ns"]}')
