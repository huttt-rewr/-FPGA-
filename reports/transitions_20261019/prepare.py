from pathlib import Path
import hashlib, json, shutil, subprocess

root = Path(__file__).resolve().parents[2]
dest = Path(__file__).resolve().parent / 'before'
assert not dest.exists(), 'Refuse to overwrite baseline'
paths = [p for base in ('src', 'scripts', 'sim') for p in (root/base).rglob('*')
         if p.is_file() and p.suffix in ('.v', '.vhd', '.adc', '.sdc', '.al', '.ipc', '.tcl', '.ps1', '.py', '.txt')
         and not any(x.endswith('_work') for x in p.parts)]
paths += [root/p for p in ('README.md','docs/USER_GUIDE.md','docs/KEY_SW_OPERATION.md','video_improve.al')]
paths += [root/'reports'/p for p in ('timing_status.txt','physical_area.txt','build_manifest.json',
          'routed_timing_paths20.txt','synthesis.log','implementation.log','hold_finalization.log')]
record = {'head': subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(), 'files': {}}
for p in paths:
    rel = p.relative_to(root)
    target = dest/rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(p,target)
    record['files'][rel.as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
(dest.parent/'baseline.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
(dest.parent/'baseline_status.txt').write_text(subprocess.check_output(['git','status','--short'],cwd=root,text=True),encoding='utf-8')
print('Saved baseline', record['head'], len(paths), 'files')
