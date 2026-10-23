from pathlib import Path
import xml.etree.ElementTree as ET
import hashlib
import json
import difflib

ROOT = Path(__file__).resolve().parents[3]
expected = json.loads((ROOT/'reports/build_manifest.json').read_text())['sources']['video_improve.al']

def canonical(path):
    root = ET.fromstring(path.read_text(encoding='utf-8-sig').replace('UsedInP&R','UsedInP&amp;R'))
    for node in root.iter():
        node.attrib.pop('AutoExcluded',None)
    return ET.canonicalize(ET.tostring(root,encoding='unicode'),strip_text=True)

current = canonical(ROOT/'video_improve.al')
import itertools
import re
segments = re.split(r'(<Attr Name="AutoExcluded" Val="true"></Attr>)',current)
flags = (len(segments)-1)//2
for keep in itertools.product((False,True),repeat=flags):
    candidate = ''.join(part for i,part in enumerate(segments)
                        if i%2==0 or keep[i//2])
    if hashlib.sha256(candidate.encode()).hexdigest()==expected:
        out = Path(__file__).resolve().parent/'project_reconciliation'
        out.mkdir(exist_ok=True)
        (out/'original_canonical.xml').write_text(candidate,encoding='utf-8')
        (out/'current_canonical.xml').write_text(current,encoding='utf-8')
        difference = '\n'.join(difflib.unified_diff(candidate.replace('><','>\n<').splitlines(),
                         current.replace('><','>\n<').splitlines(),fromfile='original',tofile='current'))
        (out/'difference.patch').write_text(difference+'\n',encoding='utf-8')
        print('EXACT ORIGINAL RECOVERED: only added AutoExcluded UI markers')
        print(difference)
        break
else:
    print('Original not reproduced by removing AutoExcluded markers')
for path in (ROOT/'reports').rglob('*.al'):
    try:
        text = canonical(path)
    except Exception:
        continue
    if hashlib.sha256(text.encode()).hexdigest()==expected:
        print('EXACT ORIGINAL:',path)
        print('\n'.join(difflib.unified_diff(text.replace('><','>\n<').splitlines(),
                 current.replace('><','>\n<').splitlines(),fromfile=str(path),tofile='current')))
