from pathlib import Path
import hashlib
import json
import re
import subprocess

r=Path(__file__).resolve().parents[2]
here=Path(__file__).resolve().parent
out=here/'build1'
manifest=json.loads((out/'build_manifest.json').read_text())
for name,digest in manifest['sources'].items():
    assert hashlib.sha256((r/name).read_bytes()).hexdigest()==digest,name
hashes=json.loads((out/'sha256.json').read_text())
for name,digest in hashes.items():
    assert hashlib.sha256((out/name).read_bytes()).hexdigest()==digest,name
summary=json.loads((out/'summary.json').read_text())
assert summary['regression_count']==101
assert summary['timing_ns']=={'SWNS':.044,'STNS':0.,'HWNS':.024,'HTNS':0.}
assert summary['physical_after']['bram']==41
for name in ('README.md','docs/USER_GUIDE.md','docs/BUILD_STATUS.md','docs/HDMI_SELFWRITE_640_20261019.md',
             'docs/CONNECTION_AND_USAGE.md','docs/KEY_SW_OPERATION.md','docs/KEYBOARD_USAGE_20261016.md',
             'docs/WAV_AUDIO_20261014.md','reports/hdmi_selfwrite_20261019/RESULT.md'):
    p=r/name;text=p.read_text(encoding='utf-8-sig')
    assert '640' in text and '800' in text and ('无声' in text or '不发送' in text)
    original=here/'before'/name
    old_links=set(re.findall(r'\]\(([^)]+)\)',original.read_text(encoding='utf-8-sig'))) if original.exists() else set()
    for link in set(re.findall(r'\]\(([^)]+)\)',text))-old_links:
        if ':' not in link and not link.startswith('#'):
            assert (p.parent/link.split('#')[0]).exists(),(name,link)
subprocess.run(['python',str(here/'audit.py')],cwd=r,check=True)
print('ALL PASS delivery: exact 80-source build inputs, 101 frozen logs, source/report hashes, new documentation links')
