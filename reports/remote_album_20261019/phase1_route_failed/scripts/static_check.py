"""Portable project/IO consistency audit; no vendor dependencies."""
from pathlib import Path
import re, xml.etree.ElementTree as ET
r=Path(__file__).resolve().parent.parent
def project(path):
    tree=ET.fromstring(path.read_text(encoding='utf-8-sig').replace('UsedInP&R','UsedInP&amp;R'))
    files=[(path.parent/e.attrib['Path']).resolve() for e in tree.findall('.//Verilog/File')]
    assert len(files)==len(set(files)), 'Duplicate source entry'
    assert all(p.is_file() for p in files), 'Missing source'
    assert sum(bool(re.search(r'\bmodule\s+top\s*\(',p.read_text(encoding='utf-8-sig'))) for p in files)==1, 'Duplicate top'
    constraints={(path.parent/e.attrib['Path']).resolve() for e in tree.findall('.//File')
                 if e.attrib.get('Path','').endswith(('.adc','.sdc'))}
    assert constraints=={r/'src/constraints/pin.adc',r/'src/constraints/timing.sdc'}, 'Stale constraints'
    assert all(p.is_relative_to(r/'src') and 'user_source' not in p.parts for p in files), 'Legacy source in project'
    return set(files)
root_files=project(r/'video_improve.al')
nested_files=project(r/'src/td_project/video_improve.al')
assert root_files==nested_files, (
    f'TD entries differ: root-only={sorted(str(p) for p in root_files-nested_files)}, '
    f'nested-only={sorted(str(p) for p in nested_files-root_files)}')
listed=[(r/line.strip()).resolve() for line in (r/'scripts/design_files.txt').read_text().splitlines() if line.strip()]
assert len(listed)==len(set(listed)), 'Duplicate design manifest entry'
assert set(listed)==project(r/'video_improve.al'), 'Manifest differs from TD project'
assert r/'src/modules/sd/sd_fat32.v' in listed, 'FAT32 remapper is not registered'
assert '.FAT32_ENABLE(1)' in (r/'src/top.v').read_text(encoding='utf-8-sig'), 'Official top must use FAT32 files'
# Width-sensitive/control nets must be declared before any use in the top.
# Ignore comments when finding the first occurrence; this catches the actual
# top connection as well as a future accidental one-bit implicit declaration.
top_source=(r/'src/top.v').read_text(encoding='utf-8-sig')
top_code=re.sub(r'/\*.*?\*/|//[^\n]*', '', top_source, flags=re.S)
for signal,kind,width in [('res_mode','reg','1:0'),('mode_sd','wire',None),
                          ('mode_mem','wire',None),('sd_card_clk','wire',None),
                          ('rst_sd','wire',None),('rst_controls','wire',None),
                          ('vs','wire',None)]:
    first=re.search(r'\b'+signal+r'\b',top_code).start()
    declaration=top_code[top_code.rfind(';',0,first)+1:top_code.index(';',first)]
    assert re.search(r'\b'+kind+r'\b',declaration), f'{signal} used before declaration'
    if width:
        assert re.search(r'\[\s*1\s*:\s*0\s*\]',declaration), f'{signal} lost two-bit width'

modules={}
for p in listed:
    source=p.read_text(encoding='utf-8-sig')
    for name in re.findall(r'^\s*module\s+(\w+)',source,re.M):
        # Vendor FIFO wrappers intentionally contain guarded common primitives.
        if p.is_relative_to(r/'src/ip'): continue
        assert name not in modules, f'Duplicate module {name}'
        modules[name]=p
    for header in re.findall(r'`include\s+"([^"]+)"',source):
        assert (p.parent/header).is_file() or (r/header).is_file(), f'Missing include {header} in {p}'
for base in ('scripts','sim'):
    for p in (r/base).iterdir():
        if p.suffix in ('.ps1','.tcl','.v'):
            assert not re.search(r'(?:\.\./)?(?:rtl/|src/user_source/)',p.read_text(encoding='utf-8-sig')), f'Stale path in {p}'
ports=[]
top=(r/'src/top.v').read_text(encoding='utf-8-sig').split(');',1)[0]
for direction,hi,lo,name in re.findall(r'\b(input|output|inout)\s+(?:\[(\d+):(\d+)\]\s*)?(\w+)',top):
    ports.extend([f'{name}[{i}]' for i in range(int(lo),int(hi)+1)] if hi else [name])
pins=re.findall(r'set_pin_assignment\s*\{\s*(.*?)\s*\}\s*\{\s*LOCATION\s*=\s*(\w+)',(r/'src/constraints/pin.adc').read_text())
assert len(pins)==len(dict(pins)), 'Duplicate port assignment'
assert len(pins)==len(set(p for _,p in pins)), 'Pin conflict'
assert set(ports)==set(dict(pins)), 'Missing/stale IO constraint'
defs=[p.read_bytes() for p in r.rglob('global_def.v') if not any(x in p.parts for x in ('reports','backups'))]
assert all(x==defs[0] for x in defs), 'Refresh headers differ'
assert '1000000000/40000000' in defs[0].decode(), 'SDRAM refresh frequency mismatch'
assert '((64000000/`SDR_CLK_PERIOD/(2**(`ROW_WIDTH)))-1)' in defs[0].decode(), 'Refresh period lost integer-expression parentheses'
print(f'ALL PASS static_check: {len(project(r/"video_improve.al"))} sources, {len(ports)} IO bits, unique pins, matching TD entries/refresh headers')
