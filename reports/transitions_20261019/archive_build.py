from pathlib import Path
import shutil, sys
root=Path(__file__).resolve().parents[2]
out=Path(__file__).resolve().parent/sys.argv[1]
assert not out.exists(), 'Do not overwrite an existing build archive'
for folder,pattern in (('reports','*.txt'),('reports','*.log'),('reports','build_manifest.json'),
                       ('src/modules/video','*.v'),('src','top.v')):
    for p in (root/folder).glob(pattern):
        if folder=='reports' and p.name.startswith('tb_'):
            continue
        dest=out/p.relative_to(root)
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(p,dest)
print('Archived',out)
