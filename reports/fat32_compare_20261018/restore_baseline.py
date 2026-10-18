"""Restore only the tested RTL candidate; preserve initial user edit in history."""
from pathlib import Path
import hashlib
import json
import subprocess

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
rtl=ROOT/'src/modules/sd/sd_fat32.v'
assert rtl.read_bytes()==(HERE/'build3/sd_fat32.v').read_bytes(), 'RTL changed since candidate backup'
original=subprocess.check_output(['git','show','a5d76ca:src/modules/sd/sd_fat32.v'],cwd=ROOT)
rtl.write_bytes(original)
(HERE/'selection.json').write_text(json.dumps(dict(
    selected='restored_a5d76ca_rtl',
    reason='Both legal candidates worsened setup; candidate3 has PHY-8023. Preserve the better legal baseline and all new boundary tests.',
    initial_user_edit_preserved='initial/sd_fat32.v and commit a772d06',
    rtl_sha256=hashlib.sha256(original).hexdigest()),indent=2),encoding='utf-8')
print('Restored exact a5d76ca FAT32 RTL; other RTL and expanded regression retained')
