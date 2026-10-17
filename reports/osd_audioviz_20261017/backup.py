from pathlib import Path
import hashlib,json,subprocess,zipfile
R=Path(__file__).resolve().parents[2];O=Path(__file__).resolve().parent
p=R/'backups/osd_audioviz_20261017/before.zip'
assert not p.exists(),'Preserve existing backup'
p.parent.mkdir(parents=True,exist_ok=True)
paths=[q for base in ('src','scripts','sim','docs') for q in (R/base).rglob('*') if q.is_file() and q.suffix in ('.v','.vhd','.py','.ps1','.tcl','.adc','.sdc','.al','.md','.txt','.ipc') and not any(x in ('msim_work','indexed_work','sd_native_work','keyboard_work','pll_work') for x in q.parts)]
paths +=[R/'README.md',R/'video_improve.al']
with zipfile.ZipFile(p,'w',zipfile.ZIP_DEFLATED) as z:
 for q in paths:z.write(q,q.relative_to(R).as_posix())
record={'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip(),'backup':p.relative_to(R).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'inputs':{q.relative_to(R).as_posix():hashlib.sha256(q.read_bytes()).hexdigest() for q in paths}}
(O/'baseline.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print('Backed up',len(paths),'files, including unregistered pixel experiments')
