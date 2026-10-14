"""Extract only the public refresh counter for ModelSim 10.1c.

The encrypted tail fails that compiler with 'unsized constant concatenation'.
Do not change/replace production IP. This generated test module is NOT a PHY model.
"""
from pathlib import Path
import hashlib

root = Path(__file__).resolve().parent.parent
source = root / 'src/ip/sdram/sdr_init_ref.enc.v'
text = source.read_text(encoding='utf-8').split('`pragma protect begin_protected', 1)[0]
assert 'assign Sdr_ref_req=ref_req | App_ref_req;' in text
text = text.replace('module sdr_init_ref #', 'module sdr_init_ref_public_test #')
out = root / 'reports/display_fix_20261013'
out.mkdir(exist_ok=True)
(out / 'sdr_init_ref_public_test.v').write_text(text + '\nendmodule\n', encoding='utf-8')
print('Public counter extracted; original IP SHA256:', hashlib.sha256(source.read_bytes()).hexdigest())
