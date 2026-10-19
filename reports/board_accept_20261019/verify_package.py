"""Verify published PC artifacts and the intentionally pending hardware gate."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
import zipfile

r=Path(__file__).resolve().parents[2]
here=Path(__file__).resolve().parent
subprocess.run([sys.executable,str(here/'prepare.py'),'verify'],cwd=r,check=True)
package=json.loads((here/'package_manifest.json').read_text())
zpath=here/package['archive']
assert zpath.stat().st_size==package['bytes']
assert hashlib.sha256(zpath.read_bytes()).hexdigest()==package['sha256']
with zipfile.ZipFile(zpath) as z:
    assert z.testzip() is None
    for name,digest in package['files'].items():
        p=here/name
        assert hashlib.sha256(p.read_bytes()).hexdigest()==digest,name
        arcname='README.md' if p.name=='PACKAGE_README.md' else name
        assert z.read(arcname)==p.read_bytes(),name
status=json.loads((here/'STATUS.json').read_text())
assert not status['part2_started'] and not status['board_signoff']
assert all(value=='pending' for value in status['checks'].values())
for name in ('docs/BOARD_ACCEPTANCE_640_20261019.md','reports/board_accept_20261019/RESULT.md'):
    p=r/name
    for link in re.findall(r'\]\(([^)]+)\)',p.read_text(encoding='utf-8-sig')):
        if ':' not in link and not link.startswith('#'):
            assert (p.parent/link.split('#')[0]).exists(),(name,link)
for name in ('README.md','docs/BUILD_STATUS.md','docs/USER_GUIDE.md'):
    text=(r/name).read_text(encoding='utf-8-sig')
    assert '2026-10-19 上板验收准备：' in text
assert not subprocess.check_output(['git','diff','--name-only','--','src','scripts','sim','video_improve.al'],cwd=r,text=True)
print('ALL PASS package: ZIP entry/hash equality, current document links, unchanged project inputs, all hardware checks pending')
